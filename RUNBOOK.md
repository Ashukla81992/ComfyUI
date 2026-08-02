# ComfyUI Runbook - Apple M4 Pro (macOS, MPS)

**ComfyUI version:** 0.13.0
**Python:** 3.13.5 (Homebrew)
**Backend:** Apple MPS (Metal Performance Shaders)
**Machine:** MacBook Pro M4 Pro, 48 GB unified memory

All commands below were VERIFIED on this machine on 2026-07-28.

---

## Table of contents

1. [Prerequisites](#1-prerequisites)
2. [First-time setup](#2-first-time-setup)
3. [Starting ComfyUI](#3-starting-comfyui)
4. [Stopping ComfyUI](#4-stopping-comfyui)
5. [Safe / diagnostic mode](#5-safe--diagnostic-mode)
6. [Running tests](#6-running-tests)
7. [Model placement](#7-model-placement)
8. [Custom-node status](#8-custom-node-status)
9. [Troubleshooting decision tree](#9-troubleshooting-decision-tree)
10. [Extra model paths](#10-extra-model-paths)

---

## 1. Prerequisites

| Requirement | Version | How to install |
|-------------|---------|----------------|
| macOS | Sonoma+ | System |
| Homebrew | any | https://brew.sh |
| Python 3.13 | 3.13.5 | `brew install python@3.13` |
| Git | any | `brew install git` |

PyTorch must be pre-installed in the system Python 3.13 (it is large and shared across venvs):

```bash
pip3.13 install torch torchvision torchaudio
```

On Apple Silicon these come from standard PyPI and include MPS support automatically.

---

## 2. First-time setup

Run this once after cloning or after venv/ is removed (it is gitignored by design).

```bash
cd "$(git rev-parse --show-toplevel)"

# Create the virtual environment, inheriting system torch
python3.13 -m venv --system-site-packages venv

# Core ComfyUI dependencies
venv/bin/pip install \
  "comfyui-frontend-package==1.38.13" \
  "comfyui-workflow-templates==0.8.38" \
  "comfyui-embedded-docs==0.4.1" \
  torchsde einops sentencepiece \
  "aiohttp>=3.11.8" "yarl>=1.18.0" \
  scipy alembic SQLAlchemy \
  "av>=14.2.0" "comfy-kitchen>=0.2.7" "comfy-aimdo>=0.1.8" \
  "kornia>=0.7.1" spandrel \
  "pydantic~=2.0" "pydantic-settings~=2.0" \
  blake3

# Custom-node dependencies
venv/bin/pip install \
  "gguf>=0.17.1" \
  opencv-contrib-python-headless \
  "rotary_embedding_torch>=0.5.3" \
  imageio-ffmpeg \
  "omegaconf>=2.3.0" "peft>=0.17.0" \
  ftfy pyloudnorm protobuf \
  matplotlib "scikit-image" "scikit-learn" \
  pymatting timm colour-science blend_modes loguru \
  lark "clip_interrogator>=0.6.0" onnxruntime onnx

# Test dependencies (only needed to run the test suite)
venv/bin/pip install \
  pytest pytest-asyncio pytest-aiohttp websocket-client blake3
```

Verify the environment:

```bash
venv/bin/python -c "import torch; print('torch:', torch.__version__, '| MPS:', torch.backends.mps.is_available())"
# Expected: torch: 2.9.0 | MPS: True

venv/bin/pip check
# Expected: No broken requirements found.
```

---

## 3. Starting ComfyUI

### Normal start (MPS, all custom nodes)

```bash
cd "$(git rev-parse --show-toplevel)"
bash start_m4.sh
```

Or directly:

```bash
venv/bin/python main.py \
  --listen 127.0.0.1 \
  --port 8188 \
  --force-fp16 \
  --highvram
```

Then open your browser at: http://127.0.0.1:8188

--force-fp16 and --highvram are optimised for the M4 Pro unified-memory architecture.

### Background start with log tailing

```bash
venv/bin/python main.py \
  --listen 127.0.0.1 \
  --port 8188 \
  --force-fp16 \
  --highvram \
  > ~/comfyui.log 2>&1 &
echo "PID=$!"
tail -f ~/comfyui.log
```

---

## 4. Stopping ComfyUI

Press Ctrl+C in the terminal where ComfyUI is running, or:

```bash
pkill -f "venv/bin/python main.py"
```

---

## 5. Safe / diagnostic mode

Start with all custom nodes disabled (useful for diagnosing crashes):

```bash
venv/bin/python main.py \
  --disable-all-custom-nodes \
  --listen 127.0.0.1 \
  --port 8188 \
  --force-fp16 \
  --highvram
```

CPU-only mode (no GPU, slow but platform-independent):

```bash
venv/bin/python main.py \
  --disable-all-custom-nodes \
  --cpu \
  --listen 127.0.0.1 \
  --port 8188
```

CI smoke test (starts, validates, then exits cleanly):

```bash
venv/bin/python main.py \
  --disable-all-custom-nodes \
  --listen 127.0.0.1 \
  --port 8188 \
  --force-fp16 \
  --highvram \
  --quick-test-for-ci
```

---

## 6. Running tests

```bash
# Unit tests (365 pass, 10 skipped on a clean install)
venv/bin/python -m pytest tests-unit/ -v

# Inference comparison tests require pre-generated baseline images
# See tests/compare/conftest.py for the --baseline-dir option
```

Expected result: 365 passed, 10 skipped, 0 failures.

---

## 7. Model placement

Place model files in the directories under models/:

| Type | Directory | Notes |
|------|-----------|-------|
| Checkpoints (SDXL etc.) | models/checkpoints/ | .safetensors or .ckpt |
| Diffusion models | models/diffusion_models/ | standalone UNet files |
| VAE | models/vae/ | |
| CLIP / text encoders | models/clip/, models/text_encoders/ | |
| LoRA | models/loras/ | also external via extra_model_paths.yaml |
| ControlNet | models/controlnet/ | |
| Upscale models | models/upscale_models/ | |
| AnimateDiff | models/animatediff_models/ | |
| Wan video models | models/wan/ | |

### External model paths

extra_model_paths.yaml (untracked, machine-specific) maps additional search paths:

```yaml
m4_models:
  is_default: true
  loras: /Users/a0s10ik/ExternalSoftware/GenrativeModels/models/Loras
```

Edit this file to add more directories. The format follows extra_model_paths.yaml.example.

### Verified models on this machine

| Model file | Type | Location |
|-----------|------|----------|
| sd_xl_base_1.0.safetensors | SDXL checkpoint | models/checkpoints/ |
| umt5_xxl_fp8_e4m3fn_scaled.safetensors | Text encoder | models/text_encoders/ |
| clip_vision_h.safetensors | CLIP vision | models/clip_vision/ |
| mm_sdxl_v10_beta.safetensors | AnimateDiff motion | models/animatediff_models/ |
| wan_2.1_vae.safetensors | Wan VAE | models/vae/ |
| External LoRAs (multiple) | LoRA | /Users/a0s10ik/ExternalSoftware/.../Loras/ |

---

## 8. Custom-node status

| Node | Status | Notes |
|------|--------|-------|
| ComfyUI-AnimateDiff-Evolved | WORKING | AnimateDiff video generation |
| ComfyUI-Easy-Use | WORKING | UI helper nodes |
| ComfyUI-SeedVR2_VideoUpscaler | WORKING | SeedVR2 upscaler; no SageAttention on Apple |
| ComfyUI-VideoHelperSuite | WORKING | Video load/save utilities |
| ComfyUI-WanVideoWrapper | WORKING | Wan video; FantasyPortrait needs onnx (installed) |
| ComfyUI_GGUF | WORKING | GGUF quantised model support |
| ComfyUI_LayerStyle | WORKING | Layer effects |
| ComfyUI_SimpleMath | WORKING | Math expression nodes |
| ComfyUI_essentials | WORKING | Essential helper nodes |
| websocket_image_save.py | WORKING | Single-file WS image saver |

Non-fatal warnings (safe to ignore on Apple Silicon):
- triton / sageattention / flash-attn: NVIDIA-only optional optimisations.
- comfy_kitchen CUDA / Triton backends: disabled; eager backend is active.
- objc AVF class duplication: harmless macOS dynamic library warning from av package.
- comfyui_manager: not installed; nodes still load normally.

---

## 9. Troubleshooting decision tree

If torch import fails (ModuleNotFoundError: No module named 'torch'):
  -> You are using the wrong Python. Use venv/bin/python, not system python3.
  -> Re-run setup from section 2.

If sqlalchemy import fails:
  -> venv/bin/pip install SQLAlchemy alembic

If MPS is not detected (mps: False):
  -> macOS 12.3+ and torch 1.12+ required.
  -> Run: venv/bin/python -c "import torch; print(torch.backends.mps.is_available())"
  -> torch 2.9.0 installed -- should always show True on Apple Silicon.

If safe mode starts but normal mode fails:
  -> A custom node has a missing dependency.
  -> Check startup log for lines ending in (IMPORT FAILED).
  -> Install the required package for that node.

If the UI opens but generation fails:
  -> Check that the model file exists in models/checkpoints/.
  -> Model names are case-sensitive on macOS.
  -> Check logs for FileNotFoundError or RuntimeError.

If no models appear in the UI:
  -> Add .safetensors or .ckpt files to models/checkpoints/.
  -> Check extra_model_paths.yaml for correct absolute paths.
  -> Restart ComfyUI after adding models.

If port 8188 is already in use:
  -> lsof -i :8188
  -> Use a different port: --port 8189

If frontend JS/CSS fails to load (404):
  -> venv/bin/pip install "comfyui-frontend-package==1.38.13"

If asset upload tests return HTTP 500:
  -> venv/bin/pip install blake3

If tests error with "fixture aiohttp_client not found":
  -> venv/bin/pip install pytest-aiohttp

---

## 10. Extra model paths

extra_model_paths.yaml is machine-specific and not committed to Git.
Copy the example and edit:

```bash
cp extra_model_paths.yaml.example extra_model_paths.yaml
# Then edit extra_model_paths.yaml with your local directory paths
```
