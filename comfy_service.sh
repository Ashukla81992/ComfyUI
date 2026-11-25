#!/usr/bin/env bash
# Shared ComfyUI service for every video pipeline on this machine.
#
# ComfyUI is installed once (this repo). Projects such as AmaraVideo, LocalComfyStudio and
# AutoChildrenStoryVideo live in their own folders and talk to this one server over HTTP.
# They call this script instead of starting or killing ComfyUI themselves. See PIPELINES.md.
#
#   ./comfy_service.sh status                 is it up, which flags, what is queued
#   ./comfy_service.sh ensure [--profile P]   start it if it is not running, else reuse it
#   ./comfy_service.sh start  [--profile P]   start it (fails if it is already running)
#   ./comfy_service.sh stop   [--force]       stop it; refuses while any pipeline has work queued
#   ./comfy_service.sh idle                   exit 0 when nothing is running or pending
#   ./comfy_service.sh wait-idle [SECONDS]    wait until idle (default 1800 s), exit 1 on timeout
#   ./comfy_service.sh link-nodes             link shared_nodes/*.py into custom_nodes/
#
# Profiles (--profile or COMFY_PROFILE):
#   default  --force-fp16 --highvram --enable-manager           (Amara, children stories, UI work)
#   lowmem   --preview-method none --disable-smart-memory --cache-none --novram
#            (LocalComfyStudio on 16 GB machines / alongside the LTX MLX step)
#
# Env (all optional): COMFY_URL (default http://127.0.0.1:8188), COMFY_PYTHON, COMFY_PROFILE,
#   COMFY_EXTRA_ARGS (appended to the profile flags).
set -euo pipefail

COMFY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMFY_URL="${COMFY_URL:-http://127.0.0.1:8188}"
COMFY_URL="${COMFY_URL%/}"
PORT="$(echo "$COMFY_URL" | sed -E 's#^[a-z]+://[^:/]+:?([0-9]*).*#\1#')"
PORT="${PORT:-8188}"
PROFILE="${COMFY_PROFILE:-default}"
RUN_DIR="$COMFY_DIR/user/service"
PID_FILE="$RUN_DIR/comfyui_${PORT}.pid"
LOG_FILE="$RUN_DIR/comfyui_${PORT}.log"

die() { echo "ERROR: $*" >&2; exit 1; }

cmd="${1:-status}"; shift || true
ARGS=()
while [ $# -gt 0 ]; do
  case "$1" in
    --profile) PROFILE="${2:?--profile needs a value}"; shift 2 ;;
    --profile=*) PROFILE="${1#*=}"; shift ;;
    *) ARGS+=("$1"); shift ;;
  esac
done

profile_flags() {
  case "$PROFILE" in
    default) echo "--force-fp16 --highvram --enable-manager" ;;
    lowmem)  echo "--preview-method none --disable-smart-memory --cache-none --novram" ;;
    *) die "unknown profile '$PROFILE' (use default or lowmem)" ;;
  esac
}

find_python() {
  if [ -n "${COMFY_PYTHON:-}" ]; then echo "$COMFY_PYTHON"; return; fi
  for c in "$COMFY_DIR/.venv/bin/python" "$COMFY_DIR/venv/bin/python" "$HOME/SHARED_VENV/bin/python"; do
    if [ -x "$c" ] && "$c" -c "import torch" 2>/dev/null; then echo "$c"; return; fi
  done
  die "no Python with torch found (.venv, venv or ~/SHARED_VENV). Set COMFY_PYTHON. See WORKING.md."
}

healthy() { curl -sf -m 3 "$COMFY_URL/system_stats" >/dev/null 2>&1; }

# Prints "<running> <pending>" from /queue.
queue_counts() {
  curl -sf -m 5 "$COMFY_URL/queue" 2>/dev/null | python3 -c \
    'import json,sys; d=json.load(sys.stdin); print(len(d.get("queue_running",[])), len(d.get("queue_pending",[])))' \
    2>/dev/null || echo "? ?"
}

is_idle() {
  healthy || return 0
  read -r running pending <<<"$(queue_counts)"
  [ "$running" = 0 ] && [ "$pending" = 0 ]
}

server_pid() {
  if [ -f "$PID_FILE" ]; then
    local p; p="$(cat "$PID_FILE")"
    if kill -0 "$p" 2>/dev/null; then echo "$p"; return; fi
  fi
  # started some other way (start_m4.sh, a terminal): find main.py listening on our port
  command -v lsof >/dev/null || return 0
  for p in $(lsof -nP -t -iTCP:"$PORT" -sTCP:LISTEN 2>/dev/null); do
    if ps -o command= -p "$p" | grep -q "main.py"; then echo "$p"; return; fi
  done
}

link_nodes() {
  mkdir -p "$COMFY_DIR/custom_nodes"
  for f in "$COMFY_DIR"/shared_nodes/*.py; do
    [ -e "$f" ] || continue
    ln -sfn "$f" "$COMFY_DIR/custom_nodes/$(basename "$f")"
  done
}

start() {
  if healthy; then die "ComfyUI is already running at $COMFY_URL (use 'ensure' to reuse it)"; fi
  if command -v lsof >/dev/null && lsof -nP -iTCP:"$PORT" -sTCP:LISTEN >/dev/null 2>&1; then
    die "port $PORT is in use but $COMFY_URL/system_stats does not answer. Check: lsof -nP -iTCP:$PORT -sTCP:LISTEN"
  fi
  local py flags; py="$(find_python)"; flags="$(profile_flags)"
  link_nodes
  mkdir -p "$RUN_DIR"
  echo "Starting ComfyUI ($PROFILE profile) on 127.0.0.1:$PORT ... log: $LOG_FILE"
  # shellcheck disable=SC2086
  ( cd "$COMFY_DIR" && exec "$py" main.py --listen 127.0.0.1 --port "$PORT" $flags ${COMFY_EXTRA_ARGS:-} ) \
    >>"$LOG_FILE" 2>&1 &
  local pid=$!
  echo "$pid" >"$PID_FILE"
  for _ in $(seq 1 90); do
    healthy && { echo "ComfyUI is up (pid $pid)."; return 0; }
    kill -0 "$pid" 2>/dev/null || { tail -30 "$LOG_FILE"; rm -f "$PID_FILE"; die "ComfyUI exited during startup (log above)"; }
    sleep 2
  done
  tail -30 "$LOG_FILE"; die "ComfyUI did not become healthy within 180 s"
}

ensure() {
  if healthy; then
    echo "ComfyUI already running at $COMFY_URL - reusing it."
    if [ "$PROFILE" = lowmem ] && ! curl -sf "$COMFY_URL/system_stats" | grep -q -- '--novram'; then
      echo "NOTE: the running ComfyUI was not started with the lowmem profile. Other pipelines may be"
      echo "      using it, so it is left as is. Restart it with the lowmem profile when nothing is queued:"
      echo "      $COMFY_DIR/comfy_service.sh stop && $COMFY_DIR/comfy_service.sh start --profile lowmem"
    fi
    return 0
  fi
  start
}

stop() {
  local force=0
  for a in "${ARGS[@]:-}"; do [ "$a" = "--force" ] && force=1; done
  local pid; pid="$(server_pid || true)"
  if [ -z "$pid" ]; then echo "ComfyUI is not running on port $PORT."; rm -f "$PID_FILE"; return 0; fi
  if [ "$force" = 0 ] && ! is_idle; then
    read -r running pending <<<"$(queue_counts)"
    echo "ComfyUI is busy ($running running, $pending pending) - another pipeline may be rendering." >&2
    echo "Not stopping it. Wait (./comfy_service.sh wait-idle) or use --force." >&2
    return 3
  fi
  echo "Stopping ComfyUI (pid $pid) ..."
  kill "$pid" 2>/dev/null || true
  for _ in $(seq 1 30); do kill -0 "$pid" 2>/dev/null || { rm -f "$PID_FILE"; echo "Stopped."; return 0; }; sleep 1; done
  kill -9 "$pid" 2>/dev/null || true
  rm -f "$PID_FILE"
  echo "Stopped (killed)."
}

status() {
  if ! healthy; then echo "ComfyUI: DOWN ($COMFY_URL)"; return 1; fi
  read -r running pending <<<"$(queue_counts)"
  echo "ComfyUI: UP at $COMFY_URL (pid $(server_pid || echo '?'))"
  echo "Queue:   $running running, $pending pending"
  curl -sf "$COMFY_URL/system_stats" | python3 -c \
    'import json,sys; d=json.load(sys.stdin)["system"]; print("Flags:  ", " ".join(d.get("argv", [])[1:]))' 2>/dev/null || true
}

case "$cmd" in
  status) status ;;
  ensure) ensure ;;
  start) start ;;
  stop) stop ;;
  idle) is_idle ;;
  wait-idle)
    limit="${ARGS[0]:-1800}"; t=0
    until is_idle; do [ "$t" -ge "$limit" ] && exit 1; sleep 5; t=$((t + 5)); done ;;
  link-nodes) link_nodes ;;
  -h|--help|help) sed -n 2,22p "$0" ;;
  *) die "unknown command '$cmd' (status|ensure|start|stop|idle|wait-idle|link-nodes)" ;;
esac
