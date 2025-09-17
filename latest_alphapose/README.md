AlphaPose (CUDA) URL Runner
===========================

This folder provides a CUDA-enabled AlphaPose Docker image and a small
wrapper script to run pose estimation on HTTP/HTTPS/RTSP video sources.

Contents
- Dockerfile: Builds a PyTorch CUDA runtime and clones AlphaPose.
- alphapose_url.sh: Runs AlphaPose on a URL with GPU acceleration.
- nvdec_prefetch.sh: Prefetch via NVDEC (FFmpeg) to a local MP4, then run AlphaPose.
- fetch_weights.sh: Creates a weights folder and prints weight pointers.

Prerequisites
- NVIDIA driver + Docker + nvidia-container-toolkit working (`docker run --gpus all nvidia/cuda:12.3.2-base-ubuntu20.04 nvidia-smi`).
- Pose checkpoint (.pth) and AlphaPose config YAML (inside the repo path).

Build
- docker build -t alphapose:cuda -f latest_alphapose/Dockerfile latest_alphapose

Run
Set required variables and run the script (or pass them inline):

- URL='http://example.com/video.mp4' \
  CFG='configs/coco/resnet/256x192_res50_lr1e-3_1x.yaml' \
  CKPT='/abs/path/fast_res50_256x192.pth' \
  latest_alphapose/alphapose_url.sh

Defaults
- OUT_DIR: $PWD/alphapose_out (override with OUT_DIR=/path)
- GPU_INDEX: 0 (override with GPU_INDEX=1, etc.)

Pass‑through options
- OpenCV capture options env: set `OPENCV_FFMPEG_CAPTURE_OPTIONS` to tweak network ingest. Examples:
  - RTSP over TCP with timeout: `OPENCV_FFMPEG_CAPTURE_OPTIONS='rtsp_transport;tcp|stimeout;5000000'`
  - Reconnect policy: `...|reconnect;1|reconnect_streamed;1|reconnect_delay_max;2`
- Extra AlphaPose CLI args: set `EXTRA_ARGS_STR` as a space‑delimited string, e.g. `EXTRA_ARGS_STR='--vis_fast --pose_track'`.

Notes
- The config path `CFG` is relative to the AlphaPose repo in the container (mounted at `/app`).
- You can also pass a host file for `CFG` (absolute or relative). The script will mount its directory at `/cfg` and use it automatically.
- The checkpoint path `CKPT` is a host path; its directory is mounted read-only to `/weights`.
- OpenCV handles HTTP/RTSP ingestion; decoding is CPU by default. If you want NVDEC-based decode, consider a GStreamer/NVDEC pipeline or prefetch via FFmpeg and feed a local file.

Model Zoo links (pointers)
- AlphaPose repository: https://github.com/MVIG-SJTU/AlphaPose
- AlphaPose Model Zoo/docs:
  - Model Zoo overview: https://github.com/MVIG-SJTU/AlphaPose/blob/master/docs/MODEL_ZOO.md
  - COCO configs: check `configs/coco` in the repo
  - Example COCO pretrained checkpoints:
  - fast_res50_256x192.pth (COCO, 256x192)
  - res50_384x288.pth (COCO, 384x288)
- YOLOX detector weights (optional): https://github.com/Megvii-BaseDetection/YOLOX/releases

Suggested layout for weights
- latest_alphapose/weights/
  - fast_res50_256x192.pth
  - yolox_x.pth (if using YOLOX-X)

Examples
- HTTP MP4:
  - URL='http://example.com/video.mp4' \
    CFG='configs/coco/resnet/256x192_res50_lr1e-3_1x.yaml' \
    CKPT='latest_alphapose/weights/fast_res50_256x192.pth' \
    latest_alphapose/alphapose_url.sh
- Host config file example:
  - URL='http://example.com/video.mp4' \
    CFG='$PWD/custom_cfgs/my_pose_cfg.yaml' \
    CKPT='$PWD/latest_alphapose/weights/fast_res50_256x192.pth' \
    latest_alphapose/alphapose_url.sh
- RTSP with TCP, reconnect, and extra AlphaPose args:
  - OPENCV_FFMPEG_CAPTURE_OPTIONS='rtsp_transport;tcp|reconnect;1|reconnect_streamed;1|reconnect_delay_max;2' \
    EXTRA_ARGS_STR='--vis_fast' \
    URL='rtsp://user:pass@cam/stream1' \
    CFG='configs/coco/resnet/256x192_res50_lr1e-3_1x.yaml' \
    CKPT='latest_alphapose/weights/fast_res50_256x192.pth' \
    latest_alphapose/alphapose_url.sh
- NVDEC prefetch then AlphaPose (reduces network jitter impact):
  - URL='http://example.com/video.mp4' DURATION=10 WIDTH=1280 HEIGHT=720 OUT_FILE=./prefetched.mp4 \
    CFG='configs/coco/resnet/256x192_res50_lr1e-3_1x.yaml' \
    CKPT='latest_alphapose/weights/fast_res50_256x192.pth' \
    latest_alphapose/nvdec_prefetch.sh

Quick verification
- After a run, inspect the output video and JSONs in `OUT_DIR`.
- Check GPU usage during inference with `nvidia-smi dmon -s u` on the host.

Compose usage
- One-command run with Compose v2 (it will build if needed):
  - URL='http://example.com/video.mp4' \
    CFG='configs/coco/resnet/256x192_res50_lr1e-3_1x.yaml' \
    CKPT='$PWD/latest_alphapose/weights/fast_res50_256x192.pth' \
    OUT_DIR='$PWD/alphapose_out' \
    WEIGHTS_DIR='$PWD/latest_alphapose/weights' \
    docker compose -f latest_alphapose/docker-compose.yml up --build
- If `deploy.resources.reservations.devices` isn’t honored on your Compose version, prefer the shell script (which uses `--gpus`), or set `NVIDIA_VISIBLE_DEVICES=all` in your environment.

RTSP webcam simulation setup
- See `latest_alphapose/hpe-streamer_setup/`. It builds AlphaPose from `docker/alphapose/Dockerfile` and runs an RTSP server with a publisher.
- To use your file:
  - cp "/home/user/MeasurementsDTs/videos/rangeOfMotion/hd_00_00_8M.mp4" latest_alphapose/hpe-streamer_setup/media/input.mp4
  - Or symlink and set FILE env as documented in that README.
