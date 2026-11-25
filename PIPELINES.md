# One ComfyUI, many pipelines

This repo is the **shared ComfyUI install** for every video pipeline on this machine. It holds the
server, the models, the custom nodes and the venv, and nothing project-specific. Each pipeline is
its own project in its own folder (and its own git repo) and uses this ComfyUI the way it would use
any external service: over HTTP at `COMFY_URL`.

```
~/PersonalRepos/
├── ComfyUI/                  shared service (this repo): server, models/, custom_nodes/, shared_nodes/
├── AmaraVideo/               Amara stills + clips          namespace: amara
├── LocalComfyStudio/         Abhishek static story (The Last Color) + studio UI   namespace: localstudio
└── AutoChildrenStoryVideo/   children's story videos       namespace: children_story
```

## The contract

Every pipeline that talks to this ComfyUI follows these rules, so pipelines can run side by side
without overwriting or stopping each other.

| Rule | How |
|---|---|
| **Own folder** | Scripts, workflows, references, templates and settings live in the project, never in `ComfyUI/`. |
| **Own outputs** | The project downloads results from `/view` into its *own* `outputs/` (or `runs/`) folder. `ComfyUI/output/` is only ComfyUI's scratch copy. |
| **Own namespace** | Every `SaveImage` / `SaveVideo` `filename_prefix` starts with `<namespace>/`, so ComfyUI writes to `output/<namespace>/...`. |
| **Own inputs** | Images are uploaded with `subfolder=<namespace>` (ComfyUI stores them in `input/<namespace>/`) and with run-unique names, so `overwrite=true` never replaces another pipeline's reference. `LoadImage` gets the returned `"<namespace>/<name>"`. |
| **Configurable server** | `COMFY_URL` (default `http://127.0.0.1:8188`) and `COMFYUI_DIR` (default `../ComfyUI`) come from the environment; no hardcoded user paths. |
| **Shared lifecycle** | Start with `$COMFYUI_DIR/comfy_service.sh ensure` (reuses a running server). Never kill ComfyUI directly: `comfy_service.sh stop` refuses while any job is queued, so one pipeline cannot stop another one's render. |
| **Shared nodes, not symlinks into projects** | Custom nodes that more than one pipeline needs live in `shared_nodes/` here and are linked into `custom_nodes/` by `comfy_service.sh`. |

Namespaces in use:

| Namespace | Project | What it renders | Profile |
|---|---|---|---|
| `amara` | `AmaraVideo` | Qwen-Image-Edit stills → Wan 2.2 I2V clips (uses `studio_mps_fp8`) | `default` |
| `localstudio` | `LocalComfyStudio` | Studio UI jobs and the Abhishek series (Qwen keyframes, SDXL, Wan 2.2) | `lowmem` |
| `children_story` | `AutoChildrenStoryVideo` | SD/SDXL keyframes + IPAdapter → Wan I2V shots | `default` |

To add a pipeline: pick a new namespace, add a row above, and follow the contract.

## Running the service

```bash
cd ~/PersonalRepos/ComfyUI
./comfy_service.sh ensure                  # start (default profile) or reuse
./comfy_service.sh ensure --profile lowmem # LocalComfyStudio's memory flags
./comfy_service.sh status                  # up/down, flags, queue
./comfy_service.sh stop                    # refuses while work is queued; --force to override
```

Logs and the pid file are in `user/service/` (git-ignored). `start_m4.sh` still starts a
foreground server with the `default` flags.

One server runs at a time on a port, so all pipelines share one queue: jobs from different
projects wait for each other instead of fighting over memory. If a pipeline needs different
flags (for example `lowmem`), restart the server with that profile when the queue is empty, or
run a second server on another port with `COMFY_URL=http://127.0.0.1:8189` (it shares models and
nodes, but doubles memory use).

## Shared nodes

| File | Why it is shared |
|---|---|
| `shared_nodes/studio_mps_fp8.py` | fp8 dequantize kernels for Apple MPS. Needed by the Wan 2.2 fp8 workflows of both AmaraVideo and LocalComfyStudio. |

Other custom nodes (`ComfyUI-GGUF`, `ComfyUI-WanVideoWrapper`, IPAdapter, …) are installed into
`custom_nodes/` as usual and are available to every pipeline. Models and LoRAs are shared through
`models/` and `extra_model_paths.yaml`.

## Other projects

`VideoGenerator` also calls this ComfyUI (`comfy_client.py`) but does not follow the namespace
rules yet; give it its own namespace before running it next to the pipelines above.
