#!/usr/bin/env python3
"""
VocalizeAI Backend - MP3 → Speech-to-Text → SRT → Text-to-Speech → WAV
Full offline pipeline using faster-whisper + Piper TTS CLI + pydub
Cross-platform: macOS + Windows
"""

import os
import sys
import time
import logging
import tempfile
import re
import gc
import platform
import subprocess
import shutil
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
IS_WINDOWS = platform.system() == "Windows"
IS_MACOS = platform.system() == "Darwin"

if IS_WINDOWS:
    _default_cache = os.path.join(os.environ.get("LOCALAPPDATA", os.path.expanduser("~")), "vocalizeai")
else:
    _default_cache = os.path.expanduser("~/.cache/vocalizeai")

CACHE_DIR = Path(os.environ.get("VOCALIZEAI_CACHE_DIR", _default_cache))
MODELS_DIR = CACHE_DIR / "models"
WHISPER_DIR = MODELS_DIR / "whisper"
TTS_DIR = MODELS_DIR / "tts"
PIPER_DIR = CACHE_DIR / "piper"  # Piper CLI binary location
TEMP_DIR = CACHE_DIR / "temp"

for d in [MODELS_DIR, WHISPER_DIR, TTS_DIR, PIPER_DIR, TEMP_DIR]:
    d.mkdir(parents=True, exist_ok=True)


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
_piper_binary = None  # Path to piper CLI binary

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

        import multiprocessing
        # Use up to 4 workers for parallel VAD segment transcription
        cpu_count = multiprocessing.cpu_count()
        workers = min(4, max(1, cpu_count // 2))
        threads_per_worker = max(1, cpu_count // workers)

        existing = _find_existing_whisper_model(WHISPER_MODEL_NAME)
        if existing:
            _update_status("loading_whisper", 0.05, "Loading Whisper from local cache...")
            _whisper_model = WhisperModel(
                existing,
                device="cpu",
                compute_type="int8",
                num_workers=workers,
                cpu_threads=threads_per_worker,
            )
        else:
            _update_status("downloading_whisper", 0.02, f"Downloading Whisper '{WHISPER_MODEL_NAME}' (~3GB from Systran/faster-whisper-large-v3)...")
            _whisper_model = WhisperModel(
                WHISPER_MODEL_NAME,
                device="cpu",
                compute_type="int8",
                download_root=str(WHISPER_DIR),
                num_workers=workers,
                cpu_threads=threads_per_worker,
            )
        _model_status["whisper_ready"] = True
        _update_status("loading_whisper", 0.45, "✅ Whisper model ready")
    return _whisper_model


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


def _find_piper_binary() -> Optional[str]:
    """
    Tìm Piper CLI binary theo thứ tự ưu tiên:
    1. PIPER_PATH env var
    2. PIPER_DIR (cache riêng của VocalizeAI)
    3. Bundled trong thư mục backend/piper/
    4. System PATH (đã cài global)
    """
    binary_name = "piper.exe" if IS_WINDOWS else "piper"

    # 1. Env var override
    env_path = os.environ.get("PIPER_PATH")
    if env_path and os.path.isfile(env_path):
        log.info("🔗 Piper binary from PIPER_PATH: %s", env_path)
        return env_path

    # 2. VocalizeAI cache dir
    cached = PIPER_DIR / binary_name
    if cached.is_file():
        if not IS_WINDOWS:
            os.chmod(str(cached), 0o755)
        log.info("🔗 Piper binary from cache: %s", cached)
        return str(cached)

    # 3. Bundled with backend
    bundled = BASE_DIR / "piper" / binary_name
    if bundled.is_file():
        if not IS_WINDOWS:
            os.chmod(str(bundled), 0o755)
        log.info("🔗 Piper binary bundled: %s", bundled)
        return str(bundled)

    # 4. System PATH
    found = shutil.which(binary_name)
    if found:
        log.info("🔗 Piper binary from PATH: %s", found)
        return found

    return None


def _download_piper_binary():
    """
    Tự động download Piper CLI binary cho platform hiện tại.
    Hỗ trợ: macOS (arm64/x86_64), Windows (x86_64), Linux (x86_64/arm64)
    """
    import urllib.request
    import tarfile
    import zipfile

    system = platform.system().lower()
    machine = platform.machine().lower()

    # Map architecture names
    if machine in ("x86_64", "amd64"):
        arch = "amd64"
    elif machine in ("aarch64", "arm64"):
        arch = "arm64"
    else:
        raise RuntimeError(f"Unsupported architecture: {machine}")

    # Piper release URL patterns (GitHub releases)
    base_url = "https://github.com/rhasspy/piper/releases/download/2023.11.14-2"

    if system == "darwin":
        if arch == "arm64":
            filename = "piper_macos_aarch64.tar.gz"
        else:
            filename = "piper_macos_x64.tar.gz"
    elif system == "windows":
        filename = "piper_windows_amd64.zip"
    elif system == "linux":
        if arch == "arm64":
            filename = "piper_linux_aarch64.tar.gz"
        else:
            filename = "piper_linux_x86_64.tar.gz"
    else:
        raise RuntimeError(f"Unsupported platform: {system}")

    url = f"{base_url}/{filename}"
    download_path = PIPER_DIR / filename

    log.info("⬇️  Downloading Piper CLI from %s ...", url)
    _update_status("downloading_tts", 0.50, f"Downloading Piper CLI binary...")
    urllib.request.urlretrieve(url, str(download_path))

    # Extract
    log.info("📦 Extracting Piper binary...")
    if filename.endswith(".tar.gz"):
        with tarfile.open(str(download_path), "r:gz") as tar:
            tar.extractall(path=str(PIPER_DIR))
    elif filename.endswith(".zip"):
        with zipfile.ZipFile(str(download_path), "r") as zf:
            zf.extractall(path=str(PIPER_DIR))

    # After extraction, piper binary is inside PIPER_DIR/piper/
    binary_name = "piper.exe" if IS_WINDOWS else "piper"
    extracted_binary = PIPER_DIR / "piper" / binary_name

    # Set executable permission on Unix
    if not IS_WINDOWS and extracted_binary.is_file():
        os.chmod(str(extracted_binary), 0o755)

    if IS_MACOS:
        # Download missing macOS dylibs from piper-phonemize
        try:
            log.info("⬇️  Downloading macOS dependencies...")
            arch = "aarch64" if platform.machine() in ("aarch64", "arm64") else "x86_64"
            phonemize_url = f"https://github.com/rhasspy/piper-phonemize/releases/download/2023.11.14-4/piper-phonemize_macos_{arch}.tar.gz"
            phonemize_tar = PIPER_DIR / f"piper-phonemize_macos_{arch}.tar.gz"
            import urllib.request
            urllib.request.urlretrieve(phonemize_url, str(phonemize_tar))
            with tarfile.open(str(phonemize_tar), "r:gz") as tar:
                tar.extractall(path=str(PIPER_DIR / "piper"))
            phonemize_tar.unlink(missing_ok=True)
            
            # Move dylibs out of piper-phonemize/lib folder
            phonemize_lib = PIPER_DIR / "piper" / "piper-phonemize" / "lib"
            if phonemize_lib.is_dir():
                for item in phonemize_lib.iterdir():
                    if item.is_file() and (item.name.endswith(".dylib") or ".dylib." in item.name):
                        import shutil
                        shutil.copy(str(item), str(PIPER_DIR / "piper" / item.name))
                        
            # Remove quarantine attribute to prevent Gatekeeper from blocking the binaries silently
            import subprocess
            subprocess.run(["xattr", "-rc", str(PIPER_DIR)], check=False)
            
        except Exception as e:
            log.warning("⚠️ Failed to download macOS dependencies: %s", e)

    # Cleanup downloaded archive
    download_path.unlink(missing_ok=True)

    found = _find_piper_binary()
    if found:
        log.info("✅ Piper binary installed at: %s", found)
        return found
        
    return str(extracted_binary)


def get_piper_binary() -> str:
    """Get path to Piper CLI binary, download if needed."""
    global _piper_binary
    if _piper_binary and os.path.isfile(_piper_binary):
        return _piper_binary

    _piper_binary = _find_piper_binary()
    if not _piper_binary:
        _piper_binary = _download_piper_binary()

    if not _piper_binary or not os.path.isfile(_piper_binary):
        raise RuntimeError(
            "Piper CLI binary not found. Please download from "
            "https://github.com/rhasspy/piper/releases and place in: "
            f"{PIPER_DIR}"
        )
    return _piper_binary


def ensure_piper_model(voice_id: str = None) -> Path:
    """Ensure Piper ONNX model is downloaded, return path to .onnx file."""
    if not voice_id:
        voice_id = TTS_MODEL_NAME

    model_path = TTS_DIR / f"{voice_id}.onnx"
    config_path = TTS_DIR / f"{voice_id}.onnx.json"

    if model_path.exists() and config_path.exists():
        return model_path

    _update_status("downloading_tts", 0.55, f"Downloading Piper model {voice_id} (~30MB)...")
    import urllib.request

    try:
        voices_data = get_piper_voices_data()
    except Exception:
        voices_data = {}

    if voice_id in voices_data:
        files = voices_data[voice_id].get('files', {})
        onnx_rel = next((p for p in files if p.endswith('.onnx')), None)
        json_rel = next((p for p in files if p.endswith('.onnx.json')), None)
        if not onnx_rel or not json_rel:
            raise Exception(f"Missing model files in voices.json for {voice_id}")
        base_repo = "https://huggingface.co/rhasspy/piper-voices/resolve/main/"
        url_onnx = base_repo + onnx_rel
        url_json = base_repo + json_rel
    elif voice_id in SUPPORTED_PIPER_VOICES:
        base_url = SUPPORTED_PIPER_VOICES[voice_id]
        url_onnx = base_url + ".onnx"
        url_json = base_url + ".onnx.json"
    else:
        log.warning(f"Voice {voice_id} unknown, falling back to {TTS_MODEL_NAME}")
        return ensure_piper_model(TTS_MODEL_NAME)

    log.info("⬇️  Downloading model: %s", voice_id)
    urllib.request.urlretrieve(url_onnx, str(model_path))
    urllib.request.urlretrieve(url_json, str(config_path))
    log.info("✅ Model downloaded: %s", model_path)

    _model_status["tts_ready"] = True
    _update_status("ready", 1.0, "✅ All models ready")
    return model_path


def run_piper_tts(text: str, output_wav: str, voice_id: str = None):
    """
    Chạy Piper CLI subprocess để synthesize text → WAV.
    Cross-platform: macOS + Windows + Linux.
    """
    piper_bin = get_piper_binary()
    model_path = ensure_piper_model(voice_id)

    cmd = [
        piper_bin,
        "--model", str(model_path),
        "--output_file", output_wav,
    ]

    log.info("🗣️  Piper CLI: %s", " ".join(cmd[:4]) + "...")

    env = os.environ.copy()
    if IS_MACOS:
        # Giúp macOS tìm thấy các file .dylib bị thiếu trong bản release
        bin_dir = str(Path(piper_bin).parent)
        env["DYLD_FALLBACK_LIBRARY_PATH"] = bin_dir
        env["DYLD_LIBRARY_PATH"] = bin_dir

    try:
        # Piper CLI đọc theo từng dòng, cần thêm \n ở cuối để báo hiệu kết thúc dòng
        input_bytes = (text.strip() + "\n").encode("utf-8")
        
        result = subprocess.run(
            cmd,
            input=input_bytes,
            capture_output=True,
            timeout=120,
            env=env
        )
        if result.returncode != 0:
            stderr = result.stderr.decode("utf-8", errors="replace")
            log.error("Piper CLI error (rc=%d): %s", result.returncode, stderr)
            raise RuntimeError(f"Piper CLI failed (rc={result.returncode}): {stderr}")

    except FileNotFoundError:
        raise RuntimeError(
            f"Piper binary not found at: {piper_bin}. "
            "Please download from https://github.com/rhasspy/piper/releases"
        )
    except subprocess.TimeoutExpired:
        raise RuntimeError("Piper TTS timed out (>120s). Text may be too long.")


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
    import re
    entries = []
    lines = [line.strip() for line in srt_content.strip().replace('\r\n', '\n').split('\n')]
    
    current_start = None
    current_end = None
    current_text = []
    
    for line in lines:
        match = re.match(r"(\d{2}:\d{2}:\d{2}[,\.]\d{3})\s*-->\s*(\d{2}:\d{2}:\d{2}[,\.]\d{3})", line)
        if match:
            if current_text and current_text[-1].isdigit():
                current_text.pop()
                
            if current_start is not None:
                text = " ".join(current_text).strip()
                if text:
                    entries.append((current_start, current_end, text))
            
            current_start = srt_time_to_seconds(match.group(1))
            current_end = srt_time_to_seconds(match.group(2))
            current_text = []
        elif line:
            # Ignore the very first index before any timestamp
            if current_start is None and line.isdigit():
                continue
            current_text.append(line)
            
    if current_start is not None:
        text = " ".join(current_text).strip()
        if text:
            entries.append((current_start, current_end, text))
            
    return entries

def format_srt_time(seconds: float) -> str:
    h = int(seconds // 3600)
    m = int((seconds % 3600) // 60)
    s = int(seconds % 60)
    ms = int(round((seconds - int(seconds)) * 1000))
    return f"{h:02d}:{m:02d}:{s:02d},{ms:03d}"


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


def _fallback_macos_say(text: str, clip_path: Path):
    """macOS-only fallback: use Apple's built-in 'say' command for TTS."""
    if not IS_MACOS:
        return None

    aiff_path = str(clip_path).replace('.wav', '.aiff')
    txt_path = str(clip_path).replace('.wav', '.txt')

    with open(txt_path, "w", encoding="utf-8") as f:
        f.write(text)

    try:
        subprocess.run(["say", "-v", "Linh", "-o", aiff_path, "-f", txt_path],
                       check=True, stderr=subprocess.DEVNULL)
    except Exception:
        subprocess.run(["say", "-o", aiff_path, "-f", txt_path], check=True)

    from pydub import AudioSegment
    chunk_audio = AudioSegment.from_file(aiff_path, format="aiff")
    chunk_audio.export(str(clip_path), format="wav")
    return chunk_audio


def step_tts(srt_content: str, output_dir: Path, tts_voice: str = None) -> list:
    """Step 2: SRT text segments → individual WAV clips via Piper CLI"""
    log.info("🗣️  Step 2: Text-to-Speech (Piper CLI)...")
    entries = parse_srt(srt_content)
    clips = []  # list of (start_sec, end_sec, wav_path)

    for i, (start, end, text) in enumerate(entries):
        text_chunks = chunk_text(text)
        combined_audio = None

        for j, chunk in enumerate(text_chunks):
            clip_path = output_dir / f"clip_{i:04d}_{j:02d}.wav"
            log.info("   TTS [%d/%d] %.1fs→%.1fs: %s", i + 1, len(entries), start, end, chunk[:60])
            try:
                # Remove digits before TTS to prevent Piper from crashing,
                # especially for languages like Vietnamese that lack digit support.
                safe_chunk = re.sub(r'\d+', '', chunk).strip()
                if not safe_chunk:
                    continue

                # Use Piper CLI subprocess
                run_piper_tts(safe_chunk, str(clip_path), tts_voice)

                from pydub import AudioSegment
                if not clip_path.exists() or os.path.getsize(clip_path) <= 44:
                    log.warning("   Piper produced empty output, trying fallback...")
                    chunk_audio = _fallback_macos_say(chunk, clip_path)
                    if chunk_audio is None:
                        log.warning("   No fallback available on this platform, skipping chunk")
                        continue
                else:
                    chunk_audio = AudioSegment.from_wav(str(clip_path))

                if len(chunk_audio) == 0:
                    # Try macOS 'say' fallback
                    chunk_audio = _fallback_macos_say(chunk, clip_path)
                    if chunk_audio is None or len(chunk_audio) == 0:
                        log.warning("   Fallback also produced empty audio, skipping")
                        continue

                log.info(f"   --> Chunk audio length: {len(chunk_audio)} ms")
                combined_audio = chunk_audio if combined_audio is None else combined_audio + chunk_audio

            except Exception as e:
                err_msg = str(e)
                log.error("   ❌ TTS failed for chunk: %s | error: %s", chunk[:40], err_msg)
                raise Exception(f"TTS failed: {err_msg}")

        if combined_audio is not None:
            merged_path = output_dir / f"clip_{i:04d}.wav"
            combined_audio.export(str(merged_path), format="wav")
            log.info(f"✅ Entry {i} combined audio length: {len(combined_audio)} ms")
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
            get_piper_binary()
            ensure_piper_model()
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
        "tts_loaded": _piper_binary is not None,
        "platform": platform.system(),
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
    from_lang: str = Form("en"),
    to_lang: str = Form("vi")
):
    """Translate text using 100% offline argostranslate."""
    if not text.strip() or from_lang == to_lang:
        return {"translated_text": text}
        
    try:
        import argostranslate.package
        import argostranslate.translate
    except ImportError:
        raise HTTPException(500, "argostranslate is not installed. Please run: pip install argostranslate")

    def ensure_model(fc, tc):
        installed = argostranslate.translate.get_installed_languages()
        if next((l for l in installed if l.code == fc), None) and \
           next((l for l in installed if l.code == tc), None) and \
           next((l for l in installed if l.code == fc)).get_translation(next((l for l in installed if l.code == tc))):
            return True
            
        argostranslate.package.update_package_index()
        available = argostranslate.package.get_available_packages()
        pkg = next((p for p in available if p.from_code == fc and p.to_code == tc), None)
        if pkg:
            argostranslate.package.install_from_path(pkg.download())
            return True
        return False

    def do_translate(t, f_lang, t_lang):
        import argostranslate.translate
        
        # 1. Try direct translation
        direct = argostranslate.translate.get_translation_from_codes(f_lang, t_lang)
        if direct:
            return direct.translate(t)
            
        # 2. Try manual pivot through English
        if f_lang != "en" and t_lang != "en":
            t1 = argostranslate.translate.get_translation_from_codes(f_lang, "en")
            t2 = argostranslate.translate.get_translation_from_codes("en", t_lang)
            if t1 and t2:
                intermediate = t1.translate(t)
                return t2.translate(intermediate)
                
        raise ValueError(f"No translation path found from {f_lang} to {t_lang}")

    try:
        if not ensure_model(from_lang, to_lang):
            # Try pivot translation through English
            if from_lang != "en" and to_lang != "en":
                log.info(f"Direct {from_lang}->{to_lang} not found. Attempting pivot via English...")
                success1 = ensure_model(from_lang, "en")
                success2 = ensure_model("en", to_lang)
                if not (success1 and success2):
                    raise ValueError(f"Pivot models ({from_lang}->en and en->{to_lang}) unavailable.")
            else:
                raise ValueError(f"Direct model {from_lang}->{to_lang} unavailable.")
                
        # Force reload installed languages list just in case new models were downloaded
        import argostranslate.translate
        if hasattr(argostranslate.translate, 'clear_cache'):
            argostranslate.translate.clear_cache()
            
    except Exception as e:
        raise HTTPException(500, f"Error ensuring translation model: {e}")

    # Check if input is SRT
    if "-->" in text:
        entries = parse_srt(text)
        if not entries:
            raise HTTPException(400, "Invalid SRT format")
            
        translated_entries = []
        for idx, (start, end, sub_text) in enumerate(entries, 1):
            try:
                translated_sub = do_translate(sub_text, from_lang, to_lang)
                start_str = format_srt_time(start)
                end_str = format_srt_time(end)
                translated_entries.append(f"{idx}\n{start_str} --> {end_str}\n{translated_sub}\n")
            except Exception as e:
                log.error(f"Translation failed for segment {idx}: {e}")
                start_str = format_srt_time(start)
                end_str = format_srt_time(end)
                translated_entries.append(f"{idx}\n{start_str} --> {end_str}\n{sub_text}\n")
            
        final_text = "\n".join(translated_entries)
    else:
        final_text = do_translate(text, from_lang, to_lang)

    return {"translated_text": final_text}


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
        safe_text = re.sub(r'\d+', '', text).strip()
        if safe_text:
            run_piper_tts(safe_text, str(out_wav), tts_voice)

        # Check if Piper produced empty/silent output
        if not out_wav.exists() or os.path.getsize(out_wav) <= 44:
            log.info("Piper produced empty output for plain text, trying fallback...")
            fallback = _fallback_macos_say(text, out_wav)
            if fallback is None:
                raise HTTPException(500, "TTS produced empty output and no fallback available")
        
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
