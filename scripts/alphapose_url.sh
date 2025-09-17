#!/usr/bin/env bash
set -euo pipefail

# Simple wrapper to run AlphaPose on an HTTP/RTSP URL using GPU.
#
# Required env/args:
#   URL=<http/rtsp url>          # e.g. http://host/path/video.mp4 or rtsp://...
#   OUT_DIR=</abs/path/out>      # host path for results (default: $PWD/alphapose_out)
#   GPU_INDEX=<int>              # which GPU to use (default: 0)
#   CFG=</path/to/cfg.yaml>      # AlphaPose pose config (host path, required)
#   CKPT=</path/to/model.pth>    # AlphaPose pose checkpoint (host path, required)
# Optional detector config/weights if you use a custom detector in your fork:
#   DET="yolox-x"               # example detector name
#   DET_CKPT=</path/to/det.pth>  # detector checkpoint (host path)
#
# Example:
#   URL='http://example.com/video.mp4' \
#   CFG='configs/coco/resnet/256x192_res50_lr1e-3_1x.yaml' \
#   CKPT='/abs/path/fast_res50_256x192.pth' \
#   scripts/alphapose_url.sh

URL="${URL:-}"
OUT_DIR="${OUT_DIR:-$PWD/alphapose_out}"
GPU_INDEX="${GPU_INDEX:-0}"
CFG="${CFG:-}"
CKPT="${CKPT:-}"
DET="${DET:-}"
DET_CKPT="${DET_CKPT:-}"

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

# Build image if missing
if ! docker image inspect "$IMG_NAME" >/dev/null 2>&1; then
  echo "Building $IMG_NAME ..."
  docker build -t "$IMG_NAME" -f docker/alphapose/Dockerfile docker/alphapose
fi

RUN_CMD=(
  "python" "demo.py"
  "--video" "$URL"
  "--outdir" "/out"
  "--save_video" "--vis"
  "--device" "$GPU_INDEX"
  "--cfg" "/app/${CFG}"
  "--checkpoint" "/weights/$(basename "$CKPT")"
)

if [[ -n "$DET" ]]; then
  RUN_CMD+=("--detector" "$DET")
fi
if [[ -n "$DET_CKPT" ]]; then
  RUN_CMD+=("--detector-weights" "/weights/$(basename "$DET_CKPT")")
fi

docker run --rm \
  --gpus 'all,capabilities=compute,utility,video' \
  -e NVIDIA_DRIVER_CAPABILITIES=compute,utility,video \
  -v "$PWD:/work" \
  -v "${OUT_DIR}:/out" \
  -v "$(dirname "$CKPT"):/weights:ro" \
  -w /app \
  "$IMG_NAME" \
  "${RUN_CMD[@]}"

