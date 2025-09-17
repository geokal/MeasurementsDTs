#!/usr/bin/env bash
set -euo pipefail

# Helper to create a weights directory and print pointers to official checkpoints.
# This does NOT auto-download (since links/hosting can change). It creates
# a folder structure and echoes commonly used sources so you can paste the
# confirmed links you prefer.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WEIGHTS_DIR="${1:-$ROOT_DIR/weights}"
mkdir -p "$WEIGHTS_DIR"

cat <<'INFO'
AlphaPose Checkpoints (pointers)
--------------------------------

Pose models (examples):
- fast_res50_256x192.pth (COCO, 256x192)
- res50_384x288.pth (COCO, 384x288)
- darknet53_256x192.pth (COCO, 256x192)

Detectors (examples):
- YOLOX-X COCO pretrained (yolox_x.pth)
- YOLOX-L COCO pretrained (yolox_l.pth)

Where to find them:
- AlphaPose repository and its Model Zoo documentation (search: "AlphaPose Model Zoo").
- YOLOX official releases: https://github.com/Megvii-BaseDetection/YOLOX/releases

Suggested layout (place files here):
  latest_alphapose/weights/
    fast_res50_256x192.pth
    yolox_x.pth

Then run, for example:
  URL='http://example.com/video.mp4' \
  CFG='configs/coco/resnet/256x192_res50_lr1e-3_1x.yaml' \
  CKPT='latest_alphapose/weights/fast_res50_256x192.pth' \
  latest_alphapose/alphapose_url.sh

INFO

echo "Created weights directory at: $WEIGHTS_DIR"
