#!/usr/bin/env bash
set -euo pipefail

# Simple wrapper to run AlphaPose on an HTTP/RTSP URL using GPU.
#
# Required env/args:
#   URL=<http/rtsp url>          # e.g. http://host/path/video.mp4 or rtsp://...
#   OUT_DIR=</abs/path/out>      # host path for results (default: $PWD/alphapose_out)
#   GPU_INDEX=<int>              # which GPU to use (default: 0)
#   CFG=</path/to/cfg.yaml>      # AlphaPose pose config (path inside repo, e.g. configs/...yaml)
#   CKPT=</path/to/model.pth>    # AlphaPose pose checkpoint (host path, required)
# Optional detector config/weights if you use a custom detector in your fork:
#   DET="yolox-x"               # example detector name
#   DET_CKPT=</path/to/det.pth>  # detector checkpoint (host path)
#
# Example:
#   URL='http://example.com/video.mp4' \
#   CFG='configs/coco/resnet/256x192_res50_lr1e-3_1x.yaml' \
#   CKPT='/abs/path/fast_res50_256x192.pth' \
#   latest_alphapose/alphapose_url.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

URL="${URL:-}"
OUT_DIR="${OUT_DIR:-$PWD/alphapose_out}"
GPU_INDEX="${GPU_INDEX:-0}"
CFG="${CFG:-}"
CKPT="${CKPT:-}"
DET="${DET:-}"
DET_CKPT="${DET_CKPT:-}"
EXTRA_ARGS=( )
if [[ -n "${EXTRA_ARGS_STR:-}" ]]; then
  # Allow space-delimited extra args via env var
  # Example: EXTRA_ARGS_STR="--vis_fast --pose_track"
  # shellcheck disable=SC2206
  EXTRA_ARGS=( ${EXTRA_ARGS_STR} )
fi

if [[ -z "${URL}" ]]; then
  echo "ERROR: URL is required (set URL=...)" >&2
  exit 1
fi
if [[ -z "${CFG}" || -z "${CKPT}" ]]; then
  echo "ERROR: CFG and CKPT are required (set CFG=... CKPT=...)" >&2
  exit 1
fi

mkdir -p "${OUT_DIR}"

IMG_NAME="alphapose:cuda"
DOCKER_EXTRA_MOUNTS=( )

# Resolve CFG: allow either an in-repo path or a host file path
if [[ -f "$CFG" ]]; then
  # Host file provided; mount its directory at /cfg and use it
  CFG_IN_CTN="/cfg/$(basename "$CFG")"
  DOCKER_EXTRA_MOUNTS+=( -v "$(dirname "$CFG"):/cfg:ro" )
else
  # Treat as path inside the cloned AlphaPose repo
  CFG_IN_CTN="/app/${CFG}"
fi

# Build image if missing
if ! docker image inspect "$IMG_NAME" >/dev/null 2>&1; then
  echo "Building $IMG_NAME ..."
  docker build -t "$IMG_NAME" -f "$SCRIPT_DIR/Dockerfile" "$SCRIPT_DIR"
fi

RUN_CMD=(
  "python" "demo.py"
  "--video" "$URL"
  "--outdir" "/out"
  "--save_video" "--vis"
  "--device" "$GPU_INDEX"
  "--cfg" "$CFG_IN_CTN"
  "--checkpoint" "/weights/$(basename "$CKPT")"
)

if [[ -n "$DET" ]]; then
  RUN_CMD+=("--detector" "$DET")
fi
if [[ -n "$DET_CKPT" ]]; then
  RUN_CMD+=("--detector-weights" "/weights/$(basename "$DET_CKPT")")
fi

# Append any extra passthrough args
if [[ ${#EXTRA_ARGS[@]} -gt 0 ]]; then
  RUN_CMD+=("${EXTRA_ARGS[@]}")
fi

docker run --rm \
  --gpus 'all,capabilities=compute,utility,video' \
  -e NVIDIA_DRIVER_CAPABILITIES=compute,utility,video \
  ${OPENCV_FFMPEG_CAPTURE_OPTIONS:+-e OPENCV_FFMPEG_CAPTURE_OPTIONS="$OPENCV_FFMPEG_CAPTURE_OPTIONS"} \
  -v "${OUT_DIR}:/out" \
  -v "$(dirname "$CKPT"):/weights:ro" \
  ${DOCKER_EXTRA_MOUNTS[@]:-} \
  -w /app \
  "$IMG_NAME" \
  "${RUN_CMD[@]}"
