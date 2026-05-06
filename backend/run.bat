@echo off
REM ============================================================
REM  VocalizeAI — Windows Auto Setup & Run
REM  Usage: run.bat
REM ============================================================

cd /d "%~dp0"

echo.
echo ======================================================
echo   VocalizeAI Backend - Auto Setup ^& Run (Windows)
echo ======================================================
echo.

REM ── 1. Check ffmpeg ──
where ffmpeg >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo [WARNING] ffmpeg not found in PATH.
    echo   Please install ffmpeg: https://www.gyan.dev/ffmpeg/builds/
    echo   Or: winget install Gyan.FFmpeg
    echo.
)

REM ── 2. Find Python ──
set PYTHON=
where python >nul 2>&1
if %ERRORLEVEL% EQU 0 (
    set PYTHON=python
) else (
    where python3 >nul 2>&1
    if %ERRORLEVEL% EQU 0 (
        set PYTHON=python3
    ) else (
        echo [ERROR] Python not found. Please install Python 3.10+
        exit /b 1
    )
)

echo [OK] Python: 
%PYTHON% --version

REM ── 3. Create venv ──
if not exist "venv" (
    echo [SETUP] Creating virtualenv...
    %PYTHON% -m venv venv
)

call venv\Scripts\activate.bat

REM ── 4. Install deps ──
if not exist "venv\.deps_installed" (
    echo.
    echo [SETUP] Installing Python packages...
    pip install --upgrade pip -q
    pip install -r requirements.txt
    echo done > "venv\.deps_installed"
    echo [OK] Packages installed
) else (
    echo [OK] Packages already installed (skip)
)

REM ── 5. Pre-download models ──
set CACHE_DIR=%LOCALAPPDATA%\vocalizeai
if not exist "%CACHE_DIR%\models\tts\vi_VN-vais1000-medium.onnx" (
    echo.
    echo [SETUP] Downloading Piper TTS model...
    python -c "import urllib.request, os; os.makedirs(r'%CACHE_DIR%\models\tts', exist_ok=True); urllib.request.urlretrieve('https://huggingface.co/rhasspy/piper-voices/resolve/main/vi/vi_VN/vais1000/medium/vi_VN-vais1000-medium.onnx', r'%CACHE_DIR%\models\tts\vi_VN-vais1000-medium.onnx'); urllib.request.urlretrieve('https://huggingface.co/rhasspy/piper-voices/resolve/main/vi/vi_VN/vais1000/medium/vi_VN-vais1000-medium.onnx.json', r'%CACHE_DIR%\models\tts\vi_VN-vais1000-medium.onnx.json'); print('[OK] Piper TTS model downloaded')"
)

echo.
echo ======================================================
echo   [READY] Starting server...
echo   API: http://127.0.0.1:5000
echo   Health: http://127.0.0.1:5000/health
echo   Cache: %CACHE_DIR%
echo   Press Ctrl+C to stop
echo ======================================================
echo.

python server.py
