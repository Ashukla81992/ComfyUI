#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

CUSTOM_NODES_DIR="${SCRIPT_DIR}/custom_nodes"
mkdir -p "${CUSTOM_NODES_DIR}"

clone_or_update() {
  local url="$1"
  local name="$2"
  local dest="${CUSTOM_NODES_DIR}/${name}"

  if [[ -d "${dest}/.git" ]]; then
    git -C "${dest}" pull --ff-only
  else
    git clone "${url}" "${dest}"
  fi
}

clone_or_update "https://github.com/Kosinkadink/ComfyUI-AnimateDiff-Evolved" "ComfyUI-AnimateDiff-Evolved"
clone_or_update "https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite" "ComfyUI-VideoHelperSuite"
clone_or_update "https://github.com/Kosinkadink/ComfyUI-Advanced-ControlNet" "ComfyUI-Advanced-ControlNet"

PYTHON_BIN="${SCRIPT_DIR}/venv/bin/python"
if [[ ! -x "${PYTHON_BIN}" ]]; then
  PYTHON_BIN="python3"
fi

"${PYTHON_BIN}" -m pip install -U pip
"${PYTHON_BIN}" -m pip install --pre comfyui_manager
