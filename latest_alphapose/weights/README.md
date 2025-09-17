AlphaPose Weights
=================

This folder is where you place pose and (optionally) detector checkpoints.
It also contains a checksum template and a script to verify file integrity.

What to download
- Pose (examples):
  - fast_res50_256x192.pth (COCO, 256x192)
  - res50_384x288.pth (COCO, 384x288)
- Detector (optional, examples):
  - yolox_x.pth (COCO pretrained)

Official sources
- AlphaPose repo: https://github.com/MVIG-SJTU/AlphaPose
- Model Zoo overview: https://github.com/MVIG-SJTU/AlphaPose/blob/master/docs/MODEL_ZOO.md
- YOLOX releases: https://github.com/Megvii-BaseDetection/YOLOX/releases

Download examples (adjust to the specific links published upstream)
- mkdir -p latest_alphapose/weights
- cd latest_alphapose/weights
- curl -L -o fast_res50_256x192.pth "<PASTE_OFFICIAL_LINK_HERE>"
- curl -L -o yolox_x.pth "https://github.com/Megvii-BaseDetection/YOLOX/releases/download/0.3.0rc1/yolox_x.pth"

Record checksums
- After downloading, compute and append checksums:
  - sha256sum fast_res50_256x192.pth >> checksums.sha256
  - sha256sum yolox_x.pth >> checksums.sha256
- You can also edit `checksums.sha256` manually; it follows standard `sha256sum` format: `<hash>  <filename>`

Verify
- From repository root or this directory:
  - latest_alphapose/verify_weights.sh
  - Or: (cd latest_alphapose/weights && sha256sum -c checksums.sha256)

Use in runner
- Point `CKPT` to your pose file, e.g.:
  - CKPT="$PWD/latest_alphapose/weights/fast_res50_256x192.pth"

