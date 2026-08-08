# ComfyUI Quick Run (Any System)

This guide gives the shortest path to run ComfyUI on Windows, macOS, or Linux.

## 1) Prerequisites

- Python 3.10+ installed (`python --version`)
- `pip` available
- Terminal opened in the `ComfyUI` project folder

## 2) Create and activate a virtual environment

### Windows (PowerShell)
```powershell
python -m venv .venv
.\.venv\Scripts\Activate.ps1
```

### macOS / Linux
```bash
python3 -m venv .venv
source .venv/bin/activate
```

## 3) Install dependencies

```bash
pip install -r requirements.txt
```

## 4) Install a PyTorch build for your hardware (recommended)

If you are not sure, skip this and use `--cpu` in step 5.

### NVIDIA GPU
```bash
pip install torch torchvision torchaudio --extra-index-url https://download.pytorch.org/whl/cu130
```

### AMD ROCm (Linux)
```bash
pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/rocm6.4
```

### Intel GPU
```bash
pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/xpu
```

### Apple Silicon (M1/M2/M3)
Use Apple/PyTorch latest mac instructions, then continue with step 5.

## 5) Run ComfyUI

### Standard run
```bash
python main.py
```

### Universal fallback (works on any system, slower)
```bash
python main.py --cpu
```

When it starts, open `http://127.0.0.1:8188` in your browser.

## 6) Optional model folder

Put model files (`.ckpt` / `.safetensors`) in:

`models/checkpoints`
