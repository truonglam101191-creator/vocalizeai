#!/bin/bash
# ============================================================
#  VocalizeAI — Quick Setup Script
#  Chạy 1 lần để cài đặt toàn bộ backend
# ============================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo ""
echo "╔══════════════════════════════════════════╗"
echo "║     VocalizeAI Backend Setup v1.0       ║"
echo "╚══════════════════════════════════════════╝"
echo ""

# ── Check Homebrew ──
if ! command -v brew &>/dev/null; then
  echo "→ Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

# ── Check ffmpeg ──
if ! command -v ffmpeg &>/dev/null; then
  echo "→ Installing ffmpeg..."
  brew install ffmpeg
else
  echo "✓ ffmpeg found: $(ffmpeg -version 2>&1 | head -1)"
fi

# ── Python venv ──
PYTHON=$(command -v python3.11 || command -v python3.10 || command -v python3)
echo "→ Using Python: $PYTHON ($($PYTHON --version))"

if [ ! -d "venv" ]; then
  echo "→ Creating virtualenv..."
  $PYTHON -m venv venv
fi

source venv/bin/activate
echo "→ venv active: $(which python)"

# ── Upgrade pip ──
pip install --upgrade pip -q

# ── Install requirements ──
echo "→ Installing Python packages (this may take 5-10 minutes)..."
pip install -r requirements.txt

echo ""
echo "✅ Setup complete!"
echo ""
echo "To start the backend:"
echo "  source venv/bin/activate"
echo "  python server.py"
echo ""
echo "Models will be downloaded on first run (~3.5GB total)"
echo "Subsequent runs are fully offline."
echo ""
