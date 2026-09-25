# WORKING — ComfyUI

## Env
- Python UI; prefer `.venv` → $HOME/.shared-venvs/py311-macos-arm64
- shared LoRAs → $HOME/.shared-assets/loras-macos-arm64
- models/ under repo

## Run
```bash
cd ComfyUI
source .venv/bin/activate || true
pip install -r requirements.txt
# Mac Apple Silicon starter
./start_m4.sh
# or
python main.py --listen 127.0.0.1 --port 8188 --force-fp16
# optional video nodes
./install_video_suite.sh
```

## Scripts
| script | purpose | command |
|---|---|---|
| `main.py` | ComfyUI server | `python main.py --listen 127.0.0.1 --port 8188` |
| `start_m4.sh` | M-series optimized start | `./start_m4.sh` |
| `install_video_suite.sh` | AnimateDiff/VHS/ControlNet nodes | `./install_video_suite.sh` |
| `fetch_video_models.py` | fetch video models | `python fetch_video_models.py` |
| `extra_model_paths.yaml` | extra model/LoRA paths | `edit + restart` |
| `RUNBOOK.md / README_RUN_ANY_SYSTEM.md` | ops docs | `open RUNBOOK.md` |

## Notes
- UI: http://127.0.0.1:8188
- Point LoRA folder at shared assets via extra_model_paths or symlink.
- verified: scaffolded 2026-09-18 (commands taken from repo scripts/README; run once to confirm)
