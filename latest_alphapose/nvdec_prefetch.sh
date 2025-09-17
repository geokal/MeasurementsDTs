#!/usr/bin/env bash
set -euo pipefail

# Prefetch an HTTP/RTSP stream using GPU decode (NVDEC) via an FFmpeg CUDA image,
# save to a local MP4, then run AlphaPose on the local file.
#
# Required env/args for prefetch:
#   URL=<http/rtsp url>
# Optional (prefetch):
#   DURATION=5           # seconds to capture (default: 10)
#   WIDTH=1280 HEIGHT=720 # scale on-GPU via scale_npp (defaults: passthrough)
#   OUT_FILE=./prefetched.mp4
#
# AlphaPose args (required):
#   CFG=...   CKPT=...   # passed through to alphapose_url.sh
# Optional pass-through:
#   OUT_DIR=... GPU_INDEX=... DET=... DET_CKPT=...

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

URL="${URL:-}"
if [[ -z "$URL" ]]; then
  echo "ERROR: URL is required (set URL=...)" >&2
  exit 1
fi

DURATION="${DURATION:-10}"
WIDTH="${WIDTH:-}"
HEIGHT="${HEIGHT:-}"
OUT_FILE="${OUT_FILE:-$PWD/prefetched.mp4}"

# Check AlphaPose required env are provided (we will pass them through)
CFG="${CFG:-}"
CKPT="${CKPT:-}"
if [[ -z "$CFG" || -z "$CKPT" ]]; then
  echo "ERROR: CFG and CKPT are required to run AlphaPose after prefetch." >&2
  exit 1
fi

FILTER="format=nv12" # keep on GPU, ensure a defined format
if [[ -n "$WIDTH" && -n "$HEIGHT" ]]; then
  FILTER="scale_npp=${WIDTH}:${HEIGHT}:interp_algo=lanczos:format=nv12"
fi

FFIMG="ffmpeg-cuda:8.0-focal"

echo "[1/2] Prefetching with NVDEC -> $OUT_FILE ..."
docker run --rm \
  --gpus 'all,capabilities=compute,utility,video' \
  -e NVIDIA_DRIVER_CAPABILITIES=compute,utility,video \
  -v "$PWD:/work" \
  "$FFIMG" \
  ffmpeg -y -hide_banner -loglevel info \
    -hwaccel cuda -hwaccel_output_format cuda \
    -i "$URL" -t "$DURATION" \
    -vf "$FILTER,hwdownload,format=yuv420p" \
    -c:v h264_nvenc -preset p5 -rc vbr -tune hq -multipass qres -cq 23 -b:v 0 -maxrate 12M -bufsize 24M \
    -movflags +faststart \
    "/work/$(realpath --relative-to="$PWD" "$OUT_FILE")"

echo "[2/2] Running AlphaPose on local file ..."
URL="$OUT_FILE" \
CFG="$CFG" \
CKPT="$CKPT" \
OUT_DIR="${OUT_DIR:-$PWD/alphapose_out}" \
GPU_INDEX="${GPU_INDEX:-0}" \
DET="${DET:-}" \
DET_CKPT="${DET_CKPT:-}" \
"$SCRIPT_DIR/alphapose_url.sh"

