from __future__ import annotations

import argparse
import hashlib
import sys
import urllib.request
from pathlib import Path


ANIMATEDIFF_MM_URL = "https://huggingface.co/conrevo/AnimateDiff-A1111/resolve/main/motion_module/mm_sd15_v2.safetensors?download=true"
SVD_URL = "https://huggingface.co/stabilityai/stable-video-diffusion-img2vid/resolve/main/svd.safetensors?download=true"
SVD_XT_URL = "https://huggingface.co/stabilityai/stable-video-diffusion-img2vid-xt/resolve/main/svd_xt.safetensors?download=true"


def _sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def _download(url: str, dest: Path) -> None:
    dest.parent.mkdir(parents=True, exist_ok=True)

    tmp = dest.with_suffix(dest.suffix + ".part")
    if tmp.exists():
        tmp.unlink()

    def report(block_count: int, block_size: int, total_size: int):
        if total_size <= 0:
            return
        downloaded = block_count * block_size
        pct = min(downloaded / total_size * 100.0, 100.0)
        sys.stdout.write(f"\rDownloading {dest.name}: {pct:5.1f}%")
        sys.stdout.flush()

    urllib.request.urlretrieve(url, tmp, reporthook=report)
    sys.stdout.write("\n")
    sys.stdout.flush()

    tmp.replace(dest)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--comfyui-root", default=str(Path(__file__).resolve().parent))
    parser.add_argument("--animatediff", action="store_true", help="Download AnimateDiff motion module")
    parser.add_argument("--svd", action="store_true", help="Download SVD checkpoint")
    parser.add_argument("--svd-xt", action="store_true", help="Download SVD-XT checkpoint")
    parser.add_argument("--force", action="store_true", help="Re-download even if files exist")
    args = parser.parse_args()

    root = Path(args.comfyui_root).resolve()
    models = root / "models"

    wanted = []
    if args.animatediff:
        wanted.append((ANIMATEDIFF_MM_URL, models / "animatediff_models" / "mm_sd15_v2.safetensors"))
    if args.svd:
        wanted.append((SVD_URL, models / "checkpoints" / "svd.safetensors"))
    if args.svd_xt:
        wanted.append((SVD_XT_URL, models / "checkpoints" / "svd_xt.safetensors"))

    if not wanted:
        args.animatediff = True
        args.svd = True
        wanted = [
            (ANIMATEDIFF_MM_URL, models / "animatediff_models" / "mm_sd15_v2.safetensors"),
            (SVD_URL, models / "checkpoints" / "svd.safetensors"),
        ]

    for url, dest in wanted:
        if dest.exists() and not args.force:
            print(f"Exists: {dest}")  # noqa: T201 - CLI output
            continue
        print(f"Fetching: {url}")  # noqa: T201 - CLI output
        print(f"To:      {dest}")  # noqa: T201 - CLI output
        _download(url, dest)
        print(f"Saved:   {dest} (sha256={_sha256(dest)})")  # noqa: T201 - CLI output

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
