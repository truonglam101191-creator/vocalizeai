#!/bin/bash
# ============================================================
#  VocalizeAI — ONE COMMAND TO RULE THEM ALL
#  Chạy 1 lần duy nhất: cài đặt + tải model + start server
#  Usage: bash run.sh
# ============================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo ""
echo "╔══════════════════════════════════════════════╗"
echo "║   VocalizeAI Backend — Auto Setup & Run     ║"
echo "╚══════════════════════════════════════════════╝"
echo ""

# ── 1. Check ffmpeg ──
if ! command -v ffmpeg &>/dev/null; then
  echo "⚠️  ffmpeg chưa cài. Đang cài..."
  if command -v brew &>/dev/null; then
    brew install ffmpeg
  else
    echo "❌ Cần cài ffmpeg: brew install ffmpeg"
    exit 1
  fi
else
  echo "✓ ffmpeg OK"
fi

# ── 2. Python venv ──
PYTHON=$(command -v python3.11 || command -v python3.10 || command -v python3)
echo "✓ Python: $($PYTHON --version)"

if [ ! -d "venv" ]; then
  echo "→ Tạo virtualenv..."
  $PYTHON -m venv venv
fi
source venv/bin/activate

# ── 3. Install deps (skip if already done) ──
MARKER="venv/.deps_installed"
if [ ! -f "$MARKER" ]; then
  echo ""
  echo "📦 Cài đặt Python packages (lần đầu ~5-10 phút)..."
  echo "   Bao gồm: FastAPI, faster-whisper, pydub"
  echo "   Piper TTS sử dụng CLI binary (auto-download)"
  echo ""
  pip install --upgrade pip -q
  pip install -r requirements.txt
  touch "$MARKER"
  echo ""
  echo "✅ Packages đã cài xong"
else
  echo "✓ Packages đã cài trước đó (skip)"
fi

# ── 4. Pre-download models (skip if already done) ──
CACHE_DIR="${VOCALIZEAI_CACHE_DIR:-$HOME/.cache/vocalizeai}"
WHISPER_MARKER="$CACHE_DIR/models/whisper/.downloaded"
TTS_MARKER="$CACHE_DIR/models/tts/.downloaded"

echo ""
echo "🧠 Kiểm tra AI models..."
echo "   Cache dir: $CACHE_DIR"
echo ""

if [ ! -f "$WHISPER_MARKER" ]; then
  echo "⬇️  Tải Whisper large-v3 (~3GB from Systran/faster-whisper-large-v3)..."
  python3 -c "
import os
os.makedirs('$CACHE_DIR/models/whisper', exist_ok=True)
from faster_whisper import WhisperModel
m = WhisperModel('large-v3', device='cpu', compute_type='int8',
                 download_root='$CACHE_DIR/models/whisper')
print('✅ Whisper large-v3 model OK')
# Create marker
open('$WHISPER_MARKER', 'w').write('done')
"
else
  echo "✓ Whisper model đã có (skip download)"
fi

if [ ! -f "$TTS_MARKER" ]; then
  echo "⬇️  Tải Piper TTS model tiếng Việt (~30MB)..."
  python3 -c "
import urllib.request
import os
os.makedirs('$CACHE_DIR/models/tts', exist_ok=True)
print('   Downloading vi_VN-vais1000-medium.onnx...')
base_url = 'https://huggingface.co/rhasspy/piper-voices/resolve/main/vi/vi_VN/vais1000/medium/'
urllib.request.urlretrieve(base_url + 'vi_VN-vais1000-medium.onnx', '$CACHE_DIR/models/tts/vi_VN-vais1000-medium.onnx')
urllib.request.urlretrieve(base_url + 'vi_VN-vais1000-medium.onnx.json', '$CACHE_DIR/models/tts/vi_VN-vais1000-medium.onnx.json')
print('✅ Piper TTS model OK')
open('$TTS_MARKER', 'w').write('done')
"
else
  echo "✓ TTS model đã có (skip download)"
fi

echo ""
echo "╔══════════════════════════════════════════════╗"
echo "║   ✅ Mọi thứ sẵn sàng! Starting server...  ║"
echo "║   API: http://127.0.0.1:5000                ║"
echo "║   Health: http://127.0.0.1:5000/health      ║"
echo "║   Cache: $CACHE_DIR"
echo "║   Ctrl+C để dừng                            ║"
echo "╚══════════════════════════════════════════════╝"
echo ""

# ── 5. Start server ──
python server.py
