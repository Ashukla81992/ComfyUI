# ComfyUI Baseline Diagnosis Report

**Date:** 2026-07-28  
**Machine:** Apple MacBook Pro M4 Pro, 48 GB RAM  
**Disk free:** ~58 GB / 460 GB  
**OS:** macOS (Apple Silicon / arm64)

---

## Repository identity

| Field | Value |
|-------|-------|
| Type | Official ComfyUI (not a fork, wrapper, or Docker deployment) |
| Version | `pyproject.toml` → 0.13.0 |
| Branch | `master` |
| HEAD commit | `ae79e333` — llama: use a more efficient rope implementation |
| Local modifications (staged/unstaged) | `.gitignore` (negated `extra_model_paths.yaml`), `comfy/utils.py` (try/except for `Float64DType` import) |
| Untracked files | `extra_model_paths.yaml`, `fetch_video_models.py`, `install_video_suite.sh`, `start_m4.sh`, `viral_analyzer.py` |

---

## Detected startup method

Primary: `bash start_m4.sh`  

```bash
# start_m4.sh (untracked, machine-specific)
PYTHON_BIN="${SCRIPT_DIR}/venv/bin/python"   # preferred
# falls back to python3 if venv absent
exec "${PYTHON_BIN}" main.py \
  --listen 127.0.0.1 --port 8188 \
  --force-fp16 --highvram --enable-manager
```

Fallback CLI: `python main.py [flags]`

---

## Failure reproduction

**Command executed:**
```bash
python3 main.py --disable-all-custom-nodes --cpu --port 8188 --listen 127.0.0.1
```

**Exit code:** 0 (process exits immediately due to unhandled import error)

**Captured error (stderr/stdout):**
```
Traceback (most recent call last):
  File "main.py", line 10, in <module>
    from app.assets.scanner import seed_assets
  File "app/assets/scanner.py", line 5, in <module>
    import sqlalchemy
ModuleNotFoundError: No module named 'sqlalchemy'
```

**Observed result:** Process exits immediately; no server starts; no port bound.

---

## Root cause

| # | Hypothesis | Evidence | Confidence |
|---|-----------|----------|------------|
| 1 | **No virtual environment** — `venv/` is gitignored and was never created on this machine. `start_m4.sh` falls back to system `python3` (3.14.6) which has zero ComfyUI packages installed. | `ls venv/` → not found; `python3 --version` → 3.14.6; `python3 -c "import sqlalchemy"` → ModuleNotFoundError | HIGH |
| 2 | Python 3.14 is the wrong interpreter — PyTorch 2.9 does not officially support Python 3.14. `python3.13` (brew) already has `torch 2.9.0` + `mps=True`. | `python3.13 -c "import torch; ..."` → `2.9.0 True` | HIGH |
| 3 | Several ComfyUI-specific packages are absent from the Python 3.13 system install | `pip list` in 3.13 shows no `aiohttp`, `sqlalchemy`, `alembic`, `einops`, `comfyui-frontend-package`, etc. | HIGH |

---

## Python environment snapshot

| Field | Value |
|-------|-------|
| System `python3` | 3.14.6 (Homebrew) — **wrong** |
| `python3.13` | 3.13.5 (Homebrew) — **correct** |
| `python3.10` | 3.10.18 (Homebrew) — available fallback |
| Virtual environment | **ABSENT** (gitignored by design) |
| torch in 3.13 | 2.9.0 |
| MPS in 3.13 | True |
| torch in 3.14 | NOT INSTALLED |

---

## Packages installed in Python 3.13 vs requirements.txt

| Package | Required | Installed (3.13) | Status |
|---------|----------|-------------------|--------|
| torch | any | 2.9.0 |  |
| torchvision | any | 0.24.0 |  |
| torchaudio | any | 2.9.0 |  |
| numpy | >=1.25.0 | 2.3.4 |  |
| transformers | >=4.50.3 | 4.57.1 |  |
| tokenizers | >=0.13.3 | 0.22.1 |  |
| safetensors | >=0.4.2 | 0.6.2 |  |
| Pillow | any | 12.0.0 |  |
| tqdm | any | 4.67.1 |  |
| psutil | any | 7.1.3 |  |
| requests | any | 2.32.5 |  |
| pyyaml | any | 6.0.3 |  |
| torchsde | any |  | MISSING |
| einops | any |  | MISSING |
| sentencepiece | any |  | MISSING |
| aiohttp | >=3.11.8 |  | MISSING |
| yarl | >=1.18.0 |  | MISSING |
| scipy | any |  | MISSING |
| alembic | any |  | MISSING |
| SQLAlchemy | any |  | MISSING |
| av | >=14.2.0 |  | MISSING |
| comfy-kitchen | >=0.2.7 |  | MISSING |
| comfy-aimdo | >=0.1.8 |  | MISSING |
| kornia | >=0.7.1 |  | MISSING |
| spandrel | any |  | MISSING |
| pydantic | ~=2.0 |  | MISSING |
| pydantic-settings | ~=2.0 |  | MISSING |
| comfyui-frontend-package | ==1.38.13 |  | MISSING |
| comfyui-workflow-templates | ==0.8.38 |  | MISSING |
| comfyui-embedded-docs | ==0.4.1 |  | MISSING |

---

## Custom nodes present

| Node | Path | Notes |
|------|------|-------|
| ComfyUI-AnimateDiff-Evolved | custom_nodes/ | Video generation node |
| ComfyUI-Easy-Use | custom_nodes/ | UI helpers |
| ComfyUI-SeedVR2_VideoUpscaler | custom_nodes/ | Video upscaler |
| ComfyUI-VideoHelperSuite | custom_nodes/ | Video utilities |
| ComfyUI-WanVideoWrapper | custom_nodes/ | WanVideo model wrapper |
| ComfyUI_GGUF | custom_nodes/ | GGUF model support |
| ComfyUI_LayerStyle | custom_nodes/ | Layer effects |
| ComfyUI_SimpleMath | custom_nodes/ | Math operations |
| ComfyUI_essentials | custom_nodes/ | Essential helpers |
| websocket_image_save.py | custom_nodes/ | Single-file WebSocket saver |

---

## Extra model paths

`extra_model_paths.yaml` (untracked, machine-specific):
```yaml
m4_models:
  is_default: true
  loras: /Users/a0s10ik/ExternalSoftware/GenrativeModels/models/Loras
```

---

## Recommended repair plan

1. Create `venv/` using `python3.13` with `--system-site-packages` (inherits torch 2.9.0)
2. `pip install` missing packages into venv
3. Test safe-mode startup (`--disable-all-custom-nodes`)
4. Test normal startup
5. Verify custom nodes one by one
6. Update `start_m4.sh` and add `RUNBOOK.md`
