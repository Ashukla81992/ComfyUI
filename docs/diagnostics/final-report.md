# ComfyUI Final Repair Report

**Date:** 2026-07-28
**Verdict:** VERIFIED

---

## 1. Original problem

- Symptom: ComfyUI fails immediately on startup with ModuleNotFoundError
- Reproduction command: `python3 main.py --disable-all-custom-nodes --cpu --port 8188`
- Error: `ModuleNotFoundError: No module named 'sqlalchemy'`
- Affected subsystem: Python import resolution at startup

---

## 2. Root cause

- Primary: No virtual environment existed at `venv/` (gitignored by design; never created on this machine)
- Contributing factor 1: `start_m4.sh` falls back to system `python3` (version 3.14.6) which has zero packages installed
- Contributing factor 2: Python 3.14 is not officially supported by PyTorch; the working interpreter was Python 3.13
- Contributing factor 3: `blake3` was required by the assets API but absent from the top-level `requirements.txt` (only in `tests-unit/requirements.txt`)
- Contributing factor 4: All custom-node dependencies were absent from the venv

---

## 3. Changes made

| File | Change | Reason | Agent |
|------|--------|--------|-------|
| venv/ (new dir, gitignored) | Created `python3.13 -m venv --system-site-packages venv` | Primary fix: provides isolated Python 3.13 env that inherits system torch 2.9.0 | Environment_Agent |
| venv/lib/... | Installed 30+ packages from requirements.txt and custom-node requirements | All missing ComfyUI and node deps | Environment_Agent |
| docs/diagnostics/baseline-report.md | Created | Phase 0 baseline documentation | Manager |
| docs/diagnostics/final-report.md | Created (this file) | Phase 6 final documentation | Manager |
| RUNBOOK.md | Created | Reproducible setup and run instructions | Manager |
| No source code files were modified | -- | All failures were environment issues; no code bugs | -- |

Note: `comfy/utils.py` and `.gitignore` had pre-existing local diffs that were preserved intact.

---

## 4. Environment used

- Operating system: macOS (darwin) 26.5.2
- Architecture: Apple Silicon arm64 (M4 Pro)
- RAM: 48 GB unified memory
- Python: 3.13.5 (Homebrew python@3.13)
- Virtual environment: venv/ with --system-site-packages (inherits system torch)
- PyTorch: 2.9.0
- GPU/backend: Apple MPS (Metal Performance Shaders) - SHARED vram mode (unified memory)
- ComfyUI version: 0.13.0 (commit ae79e333)
- Custom-node mode: ALL 10 nodes loaded successfully

---

## 5. Verification results

| Check | Result | Evidence |
|-------|--------|---------|
| venv created with Python 3.13 | PASS | venv/bin/python --version = 3.13.5 |
| torch 2.9.0 accessible | PASS | import torch; torch.__version__ == '2.9.0' |
| MPS available | PASS | torch.backends.mps.is_available() == True |
| pip check clean | PASS | "No broken requirements found." |
| Core imports (aiohttp, sqlalchemy, einops...) | PASS | All 11 spot-checked imports succeed |
| Safe-mode startup (--disable-all-custom-nodes) | PASS | Exit 0, --quick-test-for-ci completes |
| MPS safe-mode startup | PASS | Device: mps, vram: SHARED, 49152 MB |
| Normal startup (all custom nodes) | PASS | 10/10 nodes load, exit 0 |
| HTTP root / | PASS | HTTP 200 |
| /system_stats JSON | PASS | Returns full system info JSON |
| /object_info (node registry) | PASS | 613 node types loaded |
| /queue endpoint | PASS | {"queue_running":[],"queue_pending":[]} |
| WebSocket /ws | PASS | ws.connected == True |
| Workflow queue submission | PASS | HTTP 200, valid prompt_id returned |
| SDXL generation (4 steps, MPS) | PASS | smoke_test_00002_.png - 1024x1024 PNG produced in ~25s |
| Unit tests (tests-unit/) | PASS | 365 passed, 10 skipped, 0 failed |
| pip check after all installs | PASS | No broken requirements found |
| Existing local diffs preserved | PASS | comfy/utils.py and .gitignore unchanged |
| No secrets committed | PASS | Only docs, RUNBOOK.md added; no keys/tokens |
| No large model files committed | PASS | .gitignore covers models/, output/ |

---

## 6. Custom-node matrix (final state)

| Node | Status | Root problem (before fix) | Resolution |
|------|--------|--------------------------|------------|
| websocket_image_save.py | WORKING | None | N/A |
| ComfyUI_SimpleMath | WORKING | None | N/A |
| ComfyUI_essentials | WORKING | None | N/A (SyntaxWarning is non-fatal) |
| ComfyUI-AnimateDiff-Evolved | WORKING | None | N/A |
| ComfyUI_GGUF | WORKING | No module named 'gguf' | pip install "gguf>=0.17.1" |
| ComfyUI-Easy-Use | WORKING | No module named 'cv2' | pip install opencv-contrib-python-headless |
| ComfyUI_LayerStyle | WORKING | No module named 'cv2' | pip install opencv-contrib-python-headless |
| ComfyUI-VideoHelperSuite | WORKING | No module named 'cv2', no imageio_ffmpeg | pip install opencv-contrib-python-headless imageio-ffmpeg |
| ComfyUI-SeedVR2_VideoUpscaler | WORKING | No module named 'rotary_embedding_torch' | pip install "rotary_embedding_torch>=0.5.3" |
| ComfyUI-WanVideoWrapper | WORKING | No module named 'gguf' | pip install "gguf>=0.17.1" + onnx for FantasyPortrait |

---

## 7. Remaining limitations

1. sageattention, flash-attn, triton: Not available on Apple Silicon. These are NVIDIA-specific optimisations. SeedVR2 and WanVideoWrapper show warnings; performance is unaffected for MPS.

2. comfyui_manager: Not installed (requires comfyui_manager==4.1b1 pre-release). The --enable-manager flag in start_m4.sh disables gracefully when the package is absent. Custom nodes load without it.

3. comfy_kitchen CUDA backend: The CUDA extension (.abi3.so) is absent - expected on Apple Silicon. The eager backend is active and fully functional.

4. tests/compare (inference comparison tests): Require pre-generated baseline images under tests/inference/baseline/. These tests are designed to validate generation quality over time and need a reference generation run. Marked NOT_APPLICABLE on first install.

5. System Python 3.14 (brew default python3): Has no packages. Do not use it for ComfyUI. Always use venv/bin/python.

6. blake3 omission from requirements.txt: The blake3 package is required by app/assets/hashing.py (used at runtime for asset upload hashing) but is only declared in tests-unit/requirements.txt. The upstream project has a code comment acknowledging this. It was installed as part of setup here.

---

## 8. Security and scope checks

- No secrets, API keys, or credentials were committed
- No model binary files were committed
- No venv/ contents were committed (gitignored)
- No generated output images were committed (gitignored)
- Server bound to 127.0.0.1 only (not 0.0.0.0)
- No external services contacted beyond standard pip installs
- No existing tests were disabled or suppressed
- No security checks were removed
- No git history was rewritten
