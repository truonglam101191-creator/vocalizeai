#!/usr/bin/env python3
"""
VocalizeAI Backend - MP3 → Speech-to-Text → SRT → Text-to-Speech → WAV
Full offline pipeline using faster-whisper + Coqui TTS + pydub
"""

import os
import sys
import time
import logging
import tempfile
import re
import gc
from pathlib import Path
from typing import Optional

import uvicorn
from fastapi import FastAPI, File, UploadFile, HTTPException, BackgroundTasks, Form
from fastapi.responses import FileResponse
from fastapi.middleware.cors import CORSMiddleware

# ────────────────────────────────────────────────────────────
# Logging
# ────────────────────────────────────────────────────────────
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    handlers=[logging.StreamHandler(sys.stdout)],
)
log = logging.getLogger("vocalizeai")

# ────────────────────────────────────────────────────────────
# Paths
# ────────────────────────────────────────────────────────────
# Tất cả model & cache lưu tại ~/.cache/vocalizeai/
# Dễ dọn dẹp: chỉ cần xóa thư mục này là giải phóng toàn bộ (~4GB)
# Có thể override bằng env var VOCALIZEAI_CACHE_DIR
BASE_DIR = Path(os.path.dirname(os.path.abspath(__file__)))
CACHE_DIR = Path(
    os.environ.get("VOCALIZEAI_CACHE_DIR", os.path.expanduser("~/.cache/vocalizeai"))
)
MODELS_DIR = CACHE_DIR / "models"
WHISPER_DIR = MODELS_DIR / "whisper"
TTS_DIR = MODELS_DIR / "tts"
TEMP_DIR = CACHE_DIR / "temp"

for d in [MODELS_DIR, WHISPER_DIR, TTS_DIR, TEMP_DIR]:
    d.mkdir(parents=True, exist_ok=True)

# Force Coqui TTS to use our managed cache dir (not ~/.local/share/tts/)
os.environ["COQUI_TOS_AGREED"] = "1"
os.environ["TTS_HOME"] = str(TTS_DIR)

# ── HuggingFace Token (xác thực để tải model) ──
HF_TOKEN = os.environ.get("HF_TOKEN", "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")
os.environ["HF_TOKEN"] = HF_TOKEN
os.environ["HUGGING_FACE_HUB_TOKEN"] = HF_TOKEN  # legacy env var
try:
    from huggingface_hub import login
    login(token=HF_TOKEN, add_to_git_credential=False)
    log.info("🔑 HuggingFace token authenticated")
except Exception as e:
    log.warning("⚠️  HF login failed (non-critical): %s", e)

WHISPER_MODEL_NAME = "large-v3"  # from: Systran/faster-whisper-large-v3
TTS_MODEL_NAME = "vi_VN-vais1000-medium"  # Default Piper Tiếng Việt

# Danh sách các model Piper hỗ trợ mặc định
SUPPORTED_PIPER_VOICES = {
    "vi_VN-vais1000-medium": "https://huggingface.co/rhasspy/piper-voices/resolve/main/vi/vi_VN/vais1000/medium/vi_VN-vais1000-medium",
    "vi_VN-vivos-x_low": "https://huggingface.co/rhasspy/piper-voices/resolve/main/vi/vi_VN/vivos/x_low/vi_VN-vivos-x_low",
    "vi_VN-25hours_single-low": "https://huggingface.co/rhasspy/piper-voices/resolve/main/vi/vi_VN/25hours_single/low/vi_VN-25hours_single-low",
    "en_US-lessac-medium": "https://huggingface.co/rhasspy/piper-voices/resolve/main/en/en_US/lessac/medium/en_US-lessac-medium"
}

# ── Custom model path override (env var) ──
# Dùng để trỏ tới thư mục chứa model faster-whisper CTranslate2 có sẵn
# Ví dụ: WHISPER_MODEL_PATH=/path/to/faster-whisper-medium python server.py
WHISPER_MODEL_PATH = os.environ.get("WHISPER_MODEL_PATH", None)

# ────────────────────────────────────────────────────────────
# Global Model Cache + Status Tracking
# ────────────────────────────────────────────────────────────
_whisper_model = None
_tts_model = None

# Real-time status visible via /status endpoint
_model_status = {
    "phase": "idle",        # idle | downloading_whisper | loading_whisper |
                            # downloading_tts | loading_tts | ready | error
    "progress": 0.0,       # 0.0 → 1.0 (tổng thể cả 2 model)
    "detail": "Waiting to start",
    "whisper_ready": False,
    "tts_ready": False,
}


def _update_status(phase: str, progress: float, detail: str):
    """Update global model status (thread-safe for simple dict writes)."""
    _model_status["phase"] = phase
    _model_status["progress"] = round(min(max(progress, 0.0), 1.0), 3)
    _model_status["detail"] = detail
    log.info("📊 [%s] %.0f%% — %s", phase, progress * 100, detail)


# ── Monkey-patch HuggingFace download to track progress ──
def _install_download_hook():
    """Intercept huggingface_hub downloads to report progress."""
    try:
        import huggingface_hub.file_download as hf_dl
        _original_download = hf_dl.hf_hub_download

        def _hooked_download(*args, **kwargs):
            filename = kwargs.get("filename") or (args[1] if len(args) > 1 else "")
            phase = _model_status.get("phase", "")
            _update_status(phase, _model_status["progress"],
                           f"Downloading: {filename}")
            return _original_download(*args, **kwargs)

        hf_dl.hf_hub_download = _hooked_download
    except Exception:
        pass  # Non-critical, just won't have per-file tracking

_install_download_hook()


def _find_existing_whisper_model(model_name: str) -> Optional[str]:
    """
    Tìm model faster-whisper (CTranslate2 format) đã có sẵn trên máy.
    
    ⚠️  LƯU Ý: WhisperKit (CoreML .mlmodelc) KHÔNG tương thích.
       faster-whisper cần format CTranslate2 (model.bin + config.json).
    
    Scan order:
    1. WHISPER_MODEL_PATH env var (chỉ định thủ công)
    2. WHISPER_DIR (cache riêng của VocalizeAI)
    3. ~/.cache/huggingface/ (HuggingFace cache chung)
    """
    # 1. Env var override
    if WHISPER_MODEL_PATH:
        p = Path(WHISPER_MODEL_PATH)
        if p.exists() and (p / "model.bin").exists():
            log.info("🔗 Found pre-existing Whisper model (WHISPER_MODEL_PATH): %s", p)
            return str(p)
        elif p.exists():
            log.warning(
                "⚠️  WHISPER_MODEL_PATH=%s exists but missing model.bin. "
                "Make sure this is a CTranslate2 format model, NOT WhisperKit/CoreML.",
                p,
            )

    # 2. Our own cache directory
    search_dirs = [
        WHISPER_DIR,
        Path.home() / ".cache" / "huggingface" / "hub",
    ]
    target_names = [
        f"faster-whisper-{model_name}",
        f"models--Systran--faster-whisper-{model_name}",
    ]

    for base in search_dirs:
        if not base.exists():
            continue
        for name in target_names:
            candidate = base / name
            if candidate.exists():
                model_bin = list(candidate.rglob("model.bin"))
                if model_bin:
                    model_dir = model_bin[0].parent
                    log.info("🔗 Found cached Whisper model: %s", model_dir)
                    return str(model_dir)

    return None


def get_whisper_model():
    """Load or return cached Whisper model."""
    global _whisper_model
    if _whisper_model is None:
        from faster_whisper import WhisperModel

        existing = _find_existing_whisper_model(WHISPER_MODEL_NAME)
        if existing:
            _update_status("loading_whisper", 0.05, "Loading Whisper from local cache...")
            _whisper_model = WhisperModel(
                existing,
                device="cpu",
                compute_type="int8",
            )
        else:
            _update_status("downloading_whisper", 0.02, f"Downloading Whisper '{WHISPER_MODEL_NAME}' (~3GB from Systran/faster-whisper-large-v3)...")
            _whisper_model = WhisperModel(
                WHISPER_MODEL_NAME,
                device="cpu",
                compute_type="int8",
                download_root=str(WHISPER_DIR),
            )
        _model_status["whisper_ready"] = True
        _update_status("loading_whisper", 0.45, "✅ Whisper model ready")
    return _whisper_model


_tts_models = {}

def get_piper_voices_data():
    """Fetch or load voices.json from rhasspy."""
    voices_path = CACHE_DIR / "voices.json"
    if not voices_path.exists():
        import urllib.request
        url = "https://huggingface.co/rhasspy/piper-voices/resolve/main/voices.json"
        urllib.request.urlretrieve(url, str(voices_path))
    import json
    with open(voices_path, "r", encoding="utf-8") as f:
        return json.load(f)


def get_tts_model(voice_id: str = None):
    """Load or return cached TTS model."""
    global _tts_models
    if not voice_id:
        voice_id = TTS_MODEL_NAME

    if voice_id not in _tts_models:
        try:
            voices_data = get_piper_voices_data()
        except Exception:
            voices_data = {}
            
        if voice_id not in voices_data and voice_id not in SUPPORTED_PIPER_VOICES:
            log.warning(f"Voice {voice_id} unknown, falling back to {TTS_MODEL_NAME}")
            voice_id = TTS_MODEL_NAME

        _update_status("downloading_tts", 0.50, f"Loading Piper TTS ({voice_id})...")
        from piper.voice import PiperVoice
        
        model_path = TTS_DIR / f"{voice_id}.onnx"
        if not model_path.exists():
            _update_status("downloading_tts", 0.50, f"Downloading Piper TTS {voice_id} (~30MB)...")
            import urllib.request
            
            # Resolve URLs
            if voice_id in voices_data:
                files = voices_data[voice_id].get('files', {})
                onnx_rel = next((p for p in files if p.endswith('.onnx')), None)
                json_rel = next((p for p in files if p.endswith('.onnx.json')), None)
                if not onnx_rel or not json_rel:
                    raise Exception(f"Missing model files for {voice_id}")
                base_repo = "https://huggingface.co/rhasspy/piper-voices/resolve/main/"
                url_onnx = base_repo + onnx_rel
                url_json = base_repo + json_rel
            else:
                base_url = SUPPORTED_PIPER_VOICES[voice_id]
                url_onnx = base_url + ".onnx"
                url_json = base_url + ".onnx.json"
                
            urllib.request.urlretrieve(url_onnx, str(model_path))
            urllib.request.urlretrieve(url_json, str(model_path.with_suffix(".onnx.json")))
            
        _tts_models[voice_id] = PiperVoice.load(str(model_path), str(model_path.with_suffix(".onnx.json")))
        _model_status["tts_ready"] = True
        _update_status("ready", 1.0, "✅ All models ready")
    return _tts_models[voice_id]


# ────────────────────────────────────────────────────────────
# SRT Helpers
# ────────────────────────────────────────────────────────────

def seconds_to_srt_time(seconds: float) -> str:
    """Convert float seconds → SRT timestamp 00:00:00,000"""
    hours = int(seconds // 3600)
    minutes = int((seconds % 3600) // 60)
    secs = int(seconds % 60)
    millis = int((seconds % 1) * 1000)
    return f"{hours:02d}:{minutes:02d}:{secs:02d},{millis:03d}"


def srt_time_to_seconds(t: str) -> float:
    """Convert SRT timestamp → float seconds"""
    t = t.replace(",", ".")
    parts = t.split(":")
    h, m, rest = parts
    return int(h) * 3600 + int(m) * 60 + float(rest)


def write_srt(segments, path: Path) -> str:
    """Write faster-whisper segments → SRT file, return plain text."""
    lines = []
    plain_texts = []
    idx = 1
    for seg in segments:
        start = seconds_to_srt_time(seg.start)
        end = seconds_to_srt_time(seg.end)
        text = seg.text.strip()
        if not text:
            continue
        lines.append(f"{idx}")
        lines.append(f"{start} --> {end}")
        lines.append(text)
        lines.append("")
        plain_texts.append(text)
        idx += 1
    srt_content = "\n".join(lines)
    path.write_text(srt_content, encoding="utf-8")
    log.info("📝 SRT written to %s (%d segments)", path, idx - 1)
    return srt_content


def parse_srt(srt_content: str):
    """Parse SRT → list of (start_sec, end_sec, text)"""
    pattern = re.compile(
        r"(\d+)\n(\d{2}:\d{2}:\d{2}[,\.]\d{3})\s+-->\s+(\d{2}:\d{2}:\d{2}[,\.]\d{3})\n([\s\S]*?)(?=\n\n|\Z)",
        re.MULTILINE,
    )
    entries = []
    for m in pattern.finditer(srt_content):
        start = srt_time_to_seconds(m.group(2))
        end = srt_time_to_seconds(m.group(3))
        text = m.group(4).strip().replace("\n", " ")
        if text:
            entries.append((start, end, text))
    return entries


# ────────────────────────────────────────────────────────────
# Text chunking for TTS (avoid XTTS limit ~250 chars)
# ────────────────────────────────────────────────────────────

def chunk_text(text: str, max_chars: int = 200):
    """Split text at sentence boundaries within max_chars limit."""
    if len(text) <= max_chars:
        return [text]
    # Try splitting by Vietnamese/English sentence ends
    parts = re.split(r"(?<=[.!?…।])\s+", text)
    chunks = []
    current = ""
    for part in parts:
        if len(current) + len(part) + 1 <= max_chars:
            current = (current + " " + part).strip()
        else:
            if current:
                chunks.append(current)
            current = part[:max_chars]  # hard clip if single sentence too long
    if current:
        chunks.append(current)
    return chunks if chunks else [text[:max_chars]]


# ────────────────────────────────────────────────────────────
# Pipeline Steps
# ────────────────────────────────────────────────────────────

def step_stt(mp3_path: Path, srt_path: Path) -> str:
    """Step 1: MP3 → SRT via faster-whisper"""
    log.info("🎙️  Step 1: Speech-to-Text (Whisper)...")
    model = get_whisper_model()
    segments, info = model.transcribe(
        str(mp3_path),
        language=None,          # auto-detect (works for Vietnamese too)
        beam_size=5,
        vad_filter=True,
        vad_parameters={"min_silence_duration_ms": 500},
    )
    log.info(
        "   Detected language: %s (prob=%.2f)",
        info.language,
        info.language_probability,
    )
    # Materialise generator
    segments_list = list(segments)
    srt_content = write_srt(segments_list, srt_path)
    return srt_content


def step_tts(srt_content: str, output_dir: Path, tts_voice: str = None) -> list:
    """Step 2: SRT text segments → individual WAV clips"""
    log.info("🗣️  Step 2: Text-to-Speech (Piper)...")
    tts = get_tts_model(tts_voice)
    entries = parse_srt(srt_content)
    clips = []  # list of (start_sec, end_sec, wav_path)
    import wave

    for i, (start, end, text) in enumerate(entries):
        text_chunks = chunk_text(text)
        combined_audio = None

        for j, chunk in enumerate(text_chunks):
            clip_path = output_dir / f"clip_{i:04d}_{j:02d}.wav"
            log.info("   TTS [%d/%d] %.1fs→%.1fs: %s", i + 1, len(entries), start, end, chunk[:60])
            try:
                # Piper synthesizes directly to a wav file
                with wave.open(str(clip_path), "wb") as wav_file:
                    tts.synthesize(chunk, wav_file)

                # Merge chunk clips if multiple
                from pydub import AudioSegment
                chunk_audio = AudioSegment.from_wav(str(clip_path))
                combined_audio = chunk_audio if combined_audio is None else combined_audio + chunk_audio

            except Exception as e:
                log.error("   ❌ TTS failed for chunk: %s | error: %s", chunk[:40], e)
                continue

        if combined_audio is not None:
            merged_path = output_dir / f"clip_{i:04d}.wav"
            combined_audio.export(str(merged_path), format="wav")
            clips.append((start, end, merged_path))

    log.info("✅ Generated %d audio clips", len(clips))
    return clips


def step_assemble(clips: list, total_duration: float, output_path: Path):
    """Step 3: Assemble clips onto a timeline → final WAV"""
    log.info("🎛️  Step 3: Assembling audio timeline...")
    from pydub import AudioSegment

    if not clips:
        raise ValueError("No audio clips to assemble")

    # Build silent base (total duration in ms)
    timeline_ms = int((total_duration + 2.0) * 1000)
    timeline = AudioSegment.silent(duration=timeline_ms, frame_rate=24000)

    for start_sec, end_sec, wav_path in clips:
        if not wav_path.exists():
            continue
        clip = AudioSegment.from_wav(str(wav_path))
        position_ms = int(start_sec * 1000)
        # Fit clip into available window (stretch/truncate if needed)
        available_ms = int((end_sec - start_sec) * 1000)
        if len(clip) > available_ms:
            # Speed up slightly using sample rate trick
            speedup = len(clip) / available_ms
            if speedup <= 2.0:
                clip = clip._spawn(clip.raw_data, overrides={
                    "frame_rate": int(clip.frame_rate * speedup)
                }).set_frame_rate(clip.frame_rate)
            else:
                clip = clip[:available_ms]

        timeline = timeline.overlay(clip, position=position_ms)

    # Normalize to 16-bit 44100Hz mono for compatibility
    timeline = timeline.set_frame_rate(44100).set_channels(1).set_sample_width(2)
    timeline.export(str(output_path), format="wav")
    log.info("✅ Final WAV written to %s (%.1fs)", output_path, len(timeline) / 1000)


from contextlib import asynccontextmanager

@asynccontextmanager
async def lifespan(app: FastAPI):
    log.info("🚀 VocalizeAI backend starting...")
    log.info("   Cache dir: %s", CACHE_DIR)
    log.info("   Pre-loading models in background...")
    import threading
    def preload():
        try:
            get_whisper_model()
            get_tts_model()
            log.info("🟢 All models loaded. Backend READY at http://127.0.0.1:5000")
        except Exception as e:
            log.error("❌ Model preload failed: %s", e)
            _update_status("error", 0.0, f"Error loading models: {e}")
    threading.Thread(target=preload, daemon=True).start()
    yield

app = FastAPI(title="VocalizeAI Backend", version="1.0.0", lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)


def _get_dir_size_mb(path: Path) -> float:
    """Calculate total size of directory in MB."""
    total = 0
    try:
        for f in path.rglob("*"):
            if f.is_file():
                total += f.stat().st_size
    except Exception:
        pass
    return round(total / (1024 * 1024), 1)


@app.get("/health")
async def health():
    return {
        "status": "ok",
        "whisper_loaded": _whisper_model is not None,
        "tts_loaded": _tts_model is not None,
    }


@app.get("/status")
async def model_status():
    """Real-time model loading status — polled by Flutter for download progress."""
    return _model_status


@app.get("/cache-info")
async def cache_info():
    """Return cache directory info for storage management."""
    return {
        "cache_dir": str(CACHE_DIR),
        "total_size_mb": _get_dir_size_mb(CACHE_DIR),
        "whisper_size_mb": _get_dir_size_mb(WHISPER_DIR),
        "tts_size_mb": _get_dir_size_mb(TTS_DIR),
        "temp_size_mb": _get_dir_size_mb(TEMP_DIR),
        "hint": "To free all storage, delete: " + str(CACHE_DIR),
    }


@app.get("/voices")
def get_voices():
    """Return available Piper voices grouped by language."""
    try:
        data = get_piper_voices_data()
        categories = {}
        for vid, info in data.items():
            lang = info.get("language", {}).get("name_english", "Unknown")
            if lang not in categories:
                categories[lang] = []
            categories[lang].append({
                "id": vid,
                "name": info.get("name", vid) + f" ({info.get('quality', 'medium')})"
            })
            
        # Sort languages alphabetically
        categories = dict(sorted(categories.items()))
        
        return {
            "default": TTS_MODEL_NAME,
            "categories": categories
        }
    except Exception as e:
        log.warning(f"Could not load voices.json: {e}")
        return {
            "default": TTS_MODEL_NAME,
            "categories": {
                "Vietnamese (Offline Fallback)": [
                    {"id": vid, "name": vid.replace("-", " ").title()}
                    for vid in SUPPORTED_PIPER_VOICES.keys()
                ]
            }
        }

@app.post("/clear-cache")
async def clear_cache(clear_models: bool = False, clear_temp: bool = True):
    """Clear cache to free storage.
    - clear_temp=true (default): delete temp processing files only
    - clear_models=true: delete ALL models (will re-download on next run)
    """
    import shutil
    freed_mb = 0.0
    if clear_temp:
        freed_mb += _get_dir_size_mb(TEMP_DIR)
        shutil.rmtree(TEMP_DIR, ignore_errors=True)
        TEMP_DIR.mkdir(parents=True, exist_ok=True)
        log.info("🗑️  Cleared temp cache")
    if clear_models:
        freed_mb += _get_dir_size_mb(MODELS_DIR)
        shutil.rmtree(MODELS_DIR, ignore_errors=True)
        for d in [MODELS_DIR, WHISPER_DIR, TTS_DIR]:
            d.mkdir(parents=True, exist_ok=True)
        log.info("🗑️  Cleared model cache — models will re-download on next use")
    return {
        "status": "cleared",
        "freed_mb": freed_mb,
        "remaining_mb": _get_dir_size_mb(CACHE_DIR),
    }


@app.post("/shutdown")
def shutdown_server():
    import os
    import signal
    log.info("Shutdown requested via API")
    os.kill(os.getpid(), signal.SIGINT)
    return {"status": "shutting down"}


@app.post("/stt")
async def run_stt(file: UploadFile = File(...)):
    """Convert audio file to text using Whisper."""
    if not file.filename.lower().endswith((".mp3", ".wav", ".m4a", ".flac", ".ogg")):
        raise HTTPException(400, "Only audio files are supported (mp3, wav, m4a, flac, ogg)")
        
    job_id = f"job_{int(time.time() * 1000)}"
    job_dir = TEMP_DIR / job_id
    job_dir.mkdir(parents=True, exist_ok=True)
    
    mp3_path = job_dir / f"input{Path(file.filename).suffix}"
    srt_path = job_dir / "output.srt"
    
    content = await file.read()
    mp3_path.write_bytes(content)
    
    srt_content = step_stt(mp3_path, srt_path)
    
    # Extract plain text from SRT for easier use in Translate tab
    entries = parse_srt(srt_content)
    plain_text = " ".join([e[2] for e in entries])
    
    return {"text": plain_text, "srt": srt_content}


@app.post("/translate")
async def run_translate(
    text: str = Form(...),
    token: str = Form(""),
    model: str = Form("gpt-3.5-turbo"),
    base_url: str = Form("https://api.openai.com/v1")
):
    """Translate text using user-provided OpenAI compatible token and model."""
    if not token.strip():
        # Fallback dummy translation
        return {"translated_text": f"[Needs Token] {text}"}
        
    import urllib.request
    import json
    
    req_data = {
        "model": model,
        "messages": [
            {"role": "system", "content": "You are a highly accurate translation assistant. Translate the user's text into their requested language (or if not specified, default to English/Vietnamese appropriately). Keep the formatting intact."},
            {"role": "user", "content": f"Please translate this text:\n\n{text}"}
        ],
        "temperature": 0.3
    }
    
    url = f"{base_url.rstrip('/')}/chat/completions"
    req = urllib.request.Request(
        url,
        data=json.dumps(req_data).encode("utf-8"),
        headers={
            "Content-Type": "application/json",
            "Authorization": f"Bearer {token.strip()}"
        }
    )
    
    try:
        with urllib.request.urlopen(req) as response:
            res_data = json.loads(response.read().decode("utf-8"))
            translated = res_data["choices"][0]["message"]["content"]
            return {"translated_text": translated}
    except Exception as e:
        raise HTTPException(500, f"Translation API Error: {str(e)}")


@app.post("/tts")
async def run_tts(
    text: str = Form(...),
    tts_voice: str = Form(None)
):
    """Convert plain text to WAV using Piper."""
    if not text.strip():
        raise HTTPException(400, "Text is empty")
        
    job_id = f"job_{int(time.time() * 1000)}"
    job_dir = TEMP_DIR / job_id
    job_dir.mkdir(parents=True, exist_ok=True)
    out_wav = job_dir / "tts_output.wav"
    
    # Check if input is SRT
    if "-->" in text:
        log.info("SRT format detected in TTS input.")
        entries = parse_srt(text)
        if not entries:
            raise HTTPException(400, "Invalid SRT format")
        total_duration = max(e[1] for e in entries) + 1.0
        clips_dir = job_dir / "clips"
        clips_dir.mkdir(parents=True, exist_ok=True)
        clips = step_tts(text, clips_dir, tts_voice)
        step_assemble(clips, total_duration, out_wav)
    else:
        log.info("Plain text detected in TTS input.")
        tts = get_tts_model(tts_voice)
        import wave
        with wave.open(str(out_wav), "wb") as wav_file:
            tts.synthesize(text, wav_file)
        
    return FileResponse(out_wav, media_type="audio/wav", filename="tts_output.wav")


@app.post("/pipeline")
async def run_pipeline(
    file: UploadFile = File(...),
    tts_voice: str = Form(None),
    speaker_wav: Optional[UploadFile] = File(default=None),
    background_tasks: BackgroundTasks = None,
):
    """
    Main pipeline: MP3 → SRT → WAV
    - file: input MP3
    - speaker_wav: (optional) WAV sample for voice cloning
    """
    if not file.filename.lower().endswith((".mp3", ".wav", ".m4a", ".flac", ".ogg")):
        raise HTTPException(400, "Only audio files are supported (mp3, wav, m4a, flac, ogg)")

    # Create a unique temp workspace for this request
    job_id = f"job_{int(time.time() * 1000)}"
    job_dir = TEMP_DIR / job_id
    job_dir.mkdir(parents=True, exist_ok=True)

    mp3_path = job_dir / f"input{Path(file.filename).suffix}"
    srt_path = job_dir / "output.srt"
    final_wav = job_dir / "final.wav"
    speaker_path = None

    try:
        # Save uploaded MP3
        log.info("📥 Received: %s (%s)", file.filename, job_id)
        content = await file.read()
        mp3_path.write_bytes(content)

        # Save optional speaker WAV
        if speaker_wav:
            speaker_path = job_dir / "speaker.wav"
            speaker_content = await speaker_wav.read()
            speaker_path.write_bytes(speaker_content)
            log.info("🎤 Speaker sample saved for voice cloning")

        # ── Step 1: STT ──
        srt_content = step_stt(mp3_path, srt_path)

        # ── Step 2: TTS ──
        clips_dir = job_dir / "clips"
        clips_dir.mkdir(exist_ok=True)
        clips = step_tts(
            srt_content,
            clips_dir,
            tts_voice=tts_voice,
        )

        if not clips:
            raise HTTPException(500, "TTS produced no clips — check if input has speech")

        # ── Step 3: Assemble ──
        last_end = max(end for _, end, _ in clips)
        step_assemble(clips, last_end, final_wav)

        # Schedule cleanup after response
        if background_tasks:
            background_tasks.add_task(_cleanup_job, job_dir, final_wav)

        log.info("🎉 Pipeline complete! Sending final.wav")
        return FileResponse(
            str(final_wav),
            media_type="audio/wav",
            filename="vocalized_output.wav",
        )

    except HTTPException:
        raise
    except Exception as e:
        log.error("💥 Pipeline error: %s", e, exc_info=True)
        # Cleanup on error
        import shutil
        shutil.rmtree(job_dir, ignore_errors=True)
        raise HTTPException(500, f"Pipeline failed: {str(e)}")


def _cleanup_job(job_dir: Path, keep_file: Path):
    """Remove temp job directory but keep the final output for download."""
    import shutil
    import time as t
    t.sleep(60)  # wait 60s after response sent before cleaning
    shutil.rmtree(job_dir, ignore_errors=True)
    log.info("🗑️  Cleaned up job dir: %s", job_dir)


# ────────────────────────────────────────────────────────────
# Entry Point
# ────────────────────────────────────────────────────────────
if __name__ == "__main__":
    log.info("=" * 60)
    log.info("  VocalizeAI Backend  v1.0")
    log.info("  Port: 5000")
    log.info("  Cache: %s", CACHE_DIR)
    log.info("  Tip: Delete %s to free all storage", CACHE_DIR)
    log.info("=" * 60)
    uvicorn.run(
        "server:app",
        host="127.0.0.1",
        port=5000,
        log_level="info",
        reload=False,
    )
