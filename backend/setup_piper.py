#!/usr/bin/env python3
"""
VocalizeAI — Piper TTS Setup Script
Downloads Piper CLI binary + Vietnamese voice model.
Cross-platform: macOS, Windows, Linux.

Usage:
    python setup_piper.py
    python setup_piper.py --voice en_US-lessac-medium
"""

import os
import sys
import platform
import urllib.request
import tarfile
import zipfile
import shutil
from pathlib import Path


def get_cache_dir():
    env = os.environ.get("VOCALIZEAI_CACHE_DIR")
    if env:
        return Path(env)
    if platform.system() == "Windows":
        return Path(os.environ.get("LOCALAPPDATA", os.path.expanduser("~"))) / "vocalizeai"
    return Path.home() / ".cache" / "vocalizeai"


def download_piper_binary(cache_dir: Path):
    """Download Piper CLI binary for current platform."""
    piper_dir = cache_dir / "piper"
    piper_dir.mkdir(parents=True, exist_ok=True)

    is_windows = platform.system() == "Windows"
    binary_name = "piper.exe" if is_windows else "piper"

    if (piper_dir / binary_name).is_file():
        print(f"✓ Piper binary already exists: {piper_dir / binary_name}")
        return str(piper_dir / binary_name)

    system = platform.system().lower()
    machine = platform.machine().lower()

    if machine in ("x86_64", "amd64"):
        arch = "amd64"
    elif machine in ("aarch64", "arm64"):
        arch = "arm64"
    else:
        print(f"❌ Unsupported architecture: {machine}")
        sys.exit(1)

    base_url = "https://github.com/rhasspy/piper/releases/download/2023.11.14-2"

    if system == "darwin":
        filename = "piper_macos_aarch64.tar.gz" if arch == "arm64" else "piper_macos_x64.tar.gz"
    elif system == "windows":
        filename = "piper_windows_amd64.zip"
    elif system == "linux":
        filename = "piper_linux_aarch64.tar.gz" if arch == "arm64" else "piper_linux_x86_64.tar.gz"
    else:
        print(f"❌ Unsupported platform: {system}")
        sys.exit(1)

    url = f"{base_url}/{filename}"
    download_path = piper_dir / filename

    print(f"⬇️  Downloading Piper CLI binary...")
    print(f"   URL: {url}")
    urllib.request.urlretrieve(url, str(download_path))

    # Extract
    print("📦 Extracting...")
    if filename.endswith(".tar.gz"):
        with tarfile.open(str(download_path), "r:gz") as tar:
            tar.extractall(path=str(piper_dir))
    elif filename.endswith(".zip"):
        with zipfile.ZipFile(str(download_path), "r") as zf:
            zf.extractall(path=str(piper_dir))

    extracted_binary = piper_dir / "piper" / binary_name

    if not is_windows and extracted_binary.is_file():
        os.chmod(str(extracted_binary), 0o755)

    if system == "darwin":
        print("⬇️  Downloading macOS dependencies...")
        try:
            phonemize_url = f"https://github.com/rhasspy/piper-phonemize/releases/download/2023.11.14-4/piper-phonemize_macos_{arch}.tar.gz"
            phonemize_tar = piper_dir / f"piper-phonemize_macos_{arch}.tar.gz"
            urllib.request.urlretrieve(phonemize_url, str(phonemize_tar))
            with tarfile.open(str(phonemize_tar), "r:gz") as tar:
                tar.extractall(path=str(piper_dir / "piper"))
            phonemize_tar.unlink(missing_ok=True)
            
            phonemize_lib = piper_dir / "piper" / "piper-phonemize" / "lib"
            if phonemize_lib.is_dir():
                for item in phonemize_lib.iterdir():
                    if item.is_file() and (item.name.endswith(".dylib") or ".dylib." in item.name):
                        shutil.copy(str(item), str(piper_dir / "piper" / item.name))
                        
            import subprocess
            subprocess.run(["xattr", "-rc", str(piper_dir)], check=False)
            
        except Exception as e:
            print(f"⚠️ Failed to download macOS dependencies: {e}")

    download_path.unlink(missing_ok=True)
    
    if extracted_binary.is_file():
        print(f"✅ Piper binary: {extracted_binary}")
        return str(extracted_binary)
        
    return str(piper_dir / binary_name)


def download_piper_model(cache_dir: Path, voice_id: str = "vi_VN-vais1000-medium"):
    """Download Piper ONNX model."""
    tts_dir = cache_dir / "models" / "tts"
    tts_dir.mkdir(parents=True, exist_ok=True)

    onnx_path = tts_dir / f"{voice_id}.onnx"
    json_path = tts_dir / f"{voice_id}.onnx.json"

    if onnx_path.exists() and json_path.exists():
        print(f"✓ Model already exists: {voice_id}")
        return str(onnx_path)

    # Known voice URLs
    voices = {
        "vi_VN-vais1000-medium": "https://huggingface.co/rhasspy/piper-voices/resolve/main/vi/vi_VN/vais1000/medium/vi_VN-vais1000-medium",
        "vi_VN-vivos-x_low": "https://huggingface.co/rhasspy/piper-voices/resolve/main/vi/vi_VN/vivos/x_low/vi_VN-vivos-x_low",
        "vi_VN-25hours_single-low": "https://huggingface.co/rhasspy/piper-voices/resolve/main/vi/vi_VN/25hours_single/low/vi_VN-25hours_single-low",
        "en_US-lessac-medium": "https://huggingface.co/rhasspy/piper-voices/resolve/main/en/en_US/lessac/medium/en_US-lessac-medium",
    }

    if voice_id not in voices:
        print(f"⚠️  Voice '{voice_id}' not in known list. Trying voices.json...")
        try:
            import json
            voices_json = cache_dir / "voices.json"
            if not voices_json.exists():
                urllib.request.urlretrieve(
                    "https://huggingface.co/rhasspy/piper-voices/resolve/main/voices.json",
                    str(voices_json)
                )
            with open(voices_json, "r") as f:
                data = json.load(f)
            if voice_id in data:
                files = data[voice_id].get("files", {})
                onnx_rel = next((p for p in files if p.endswith(".onnx")), None)
                json_rel = next((p for p in files if p.endswith(".onnx.json")), None)
                if onnx_rel and json_rel:
                    base = "https://huggingface.co/rhasspy/piper-voices/resolve/main/"
                    voices[voice_id] = base + onnx_rel.replace(".onnx", "")
        except Exception as e:
            print(f"❌ Cannot resolve voice: {e}")
            sys.exit(1)

    base = voices.get(voice_id)
    if not base:
        print(f"❌ Voice '{voice_id}' not found")
        sys.exit(1)

    print(f"⬇️  Downloading model: {voice_id}...")
    urllib.request.urlretrieve(base + ".onnx", str(onnx_path))
    urllib.request.urlretrieve(base + ".onnx.json", str(json_path))
    print(f"✅ Model downloaded: {onnx_path}")
    return str(onnx_path)


def main():
    import argparse
    parser = argparse.ArgumentParser(description="Setup Piper TTS for VocalizeAI")
    parser.add_argument("--voice", default="vi_VN-vais1000-medium",
                        help="Piper voice ID to download (default: vi_VN-vais1000-medium)")
    args = parser.parse_args()

    cache_dir = get_cache_dir()
    print(f"📁 Cache directory: {cache_dir}")
    print(f"🖥️  Platform: {platform.system()} {platform.machine()}")
    print()

    binary = download_piper_binary(cache_dir)
    print()
    model = download_piper_model(cache_dir, args.voice)

    print()
    print("=" * 50)
    print("✅ Piper TTS setup complete!")
    print(f"   Binary: {binary}")
    print(f"   Model:  {model}")
    print()
    print("Test with:")
    print(f'  echo "Xin chào" | "{binary}" --model "{model}" --output_file test.wav')
    print("=" * 50)


if __name__ == "__main__":
    main()
