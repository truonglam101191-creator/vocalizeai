#!/bin/bash
# ============================================================
#  VocalizeAI — PyInstaller Build Script for macOS
# ============================================================
# Usage: bash build.sh
# Output: dist/vocalizeai_backend (single executable)
# ============================================================

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "=================================================="
echo "  VocalizeAI Backend Builder"
echo "=================================================="

# ── 1. Check venv ──
if [ ! -d "venv" ]; then
  echo "→ Creating Python venv..."
  python3 -m venv venv
fi

echo "→ Activating venv..."
source venv/bin/activate

# ── 2. Install deps ──
echo "→ Installing requirements..."
pip install --upgrade pip -q
pip install -r requirements.txt -q
pip install pyinstaller -q

# ── 3. Collect package paths (needed for PyInstaller data) ──
echo "→ Locating package data..."
FASTER_WHISPER_PKG=$(python3 -c "import faster_whisper; import os; print(os.path.dirname(faster_whisper.__file__))")

echo "   faster-whisper: $FASTER_WHISPER_PKG"

# ── 4. PyInstaller spec ──
cat > vocalizeai_backend.spec << SPECEOF
# -*- mode: python ; coding: utf-8 -*-
import sys
from pathlib import Path

block_cipher = None

a = Analysis(
    ['server.py'],
    pathex=['.'],
    binaries=[],
    datas=[
        ('$FASTER_WHISPER_PKG', 'faster_whisper'),
    ],
    hiddenimports=[
        'faster_whisper',
        'ctranslate2',
        'tokenizers',
        'huggingface_hub',
        'uvicorn',
        'uvicorn.logging',
        'uvicorn.loops',
        'uvicorn.loops.auto',
        'uvicorn.protocols',
        'uvicorn.protocols.http',
        'uvicorn.protocols.http.auto',
        'fastapi',
        'pydub',
        'numpy',
    ],
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=['matplotlib', 'tkinter', 'PyQt5', 'wx', 'torch', 'torchaudio'],
    win_no_prefer_redirects=False,
    win_private_assemblies=False,
    cipher=block_cipher,
    noarchive=False,
)

pyz = PYZ(a.pure, a.zipped_data, cipher=block_cipher)

exe = EXE(
    pyz,
    a.scripts,
    a.binaries,
    a.zipfiles,
    a.datas,
    [],
    name='vocalizeai_backend',
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=False,
    upx_exclude=[],
    runtime_tmpdir=None,
    console=True,
    disable_windowed_traceback=False,
    argv_emulation=True,
    target_arch=None,
    codesign_identity=None,
    entitlements_file=None,
)
SPECEOF

echo "→ Building with PyInstaller..."
pyinstaller vocalizeai_backend.spec --clean --noconfirm

echo "=================================================="
echo "  ✅ Build complete!"
echo "  Executable: dist/vocalizeai_backend"
echo "  Size: $(du -sh dist/vocalizeai_backend 2>/dev/null | cut -f1)"
echo "=================================================="

# ── 5. Test run ──
echo "→ Quick smoke test (Ctrl+C after 3 seconds)..."
timeout 3 ./dist/vocalizeai_backend || true
echo "  (timeout expected — build is good if no crash)"
