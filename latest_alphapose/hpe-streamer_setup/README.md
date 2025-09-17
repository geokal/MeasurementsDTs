H.264 Webcam Simulation (RTSP) with AlphaPose
=============================================

This setup publishes a local H.264 MP4 in realtime to an RTSP server (MediaMTX),
then points AlphaPose at that RTSP URL, simulating a webcam feed in Docker.

Services
- streamer: RTSP/HLS server via MediaMTX (ports 8554, 8888)
- publisher: FFmpeg loops your file and publishes to `rtsp://streamer:8554/cam`,
  with optional transcode controlled by env vars
- alphapose: runs AlphaPose on the RTSP stream using your GPU
- autoheal: restarts unhealthy containers (e.g., publisher) based on healthchecks

Quick Start
1) Place your test file in `media/` (or copy the one you mentioned):
   - cp "/home/user/MeasurementsDTs/videos/rangeOfMotion/hd_00_00_8M.mp4" media/input.mp4
     (or keep the original name and set `FILE=/media/hd_00_00_8M.mp4` when running)
2) Ensure AlphaPose image can be built and weights are available on host
   - This Compose builds from `docker/alphapose/Dockerfile` automatically on `up --build`
   - Place pose weights under `latest_alphapose/weights` (or set WEIGHTS_DIR)
3) Run Compose from this folder:
   - cd latest_alphapose/hpe-streamer_setup
   - CKPT must point to your host weight file, e.g. `../weights/fast_res50_256x192.pth`
   - docker compose up --build
   - AlphaPose waits for the publisher healthcheck before starting

Environment Variables (override via `VAR=value docker compose up`)
- FILE: path of the video in the publisher container (default: `/media/input.mp4`)
- STREAM_PATH: RTSP path name (default: `cam`)
- TRANSCODE: `auto|on|copy` (default: `auto`). When `auto`, transcodes if input video codec ≠ h264.
- VCODEC: codec when transcoding (default: `libx264`)
- PRESET: x264 preset (default: `veryfast`)
- CRF: x264 CRF quality (default: `23`)
- FRAMERATE: optional target fps (e.g., `30`)
- GOP: optional GOP length (e.g., `60`). If unset and FRAMERATE is set, GOP defaults to `FRAMERATE*2`.
- LOOP: unset by default (no loop, plays once). Set to `-1` to loop forever, or to `N` to loop `N` times.
- CKPT: host path to your AlphaPose pose checkpoint (required), e.g. `../weights/fast_res50_256x192.pth`
- CFG: AlphaPose config inside the repo (default: `configs/coco/resnet/256x192_res50_lr1e-3_1x.yaml`)
- OUT_DIR: host output folder (default: `../alphapose_out`)
- WEIGHTS_DIR: host weights folder bind (default: `../weights`)
- GPU_INDEX: which GPU AlphaPose uses (default: `0`)
- OPENCV_FFMPEG_CAPTURE_OPTIONS: defaults to forcing TCP + reconnects
- EXTRA_ARGS_STR: extra AlphaPose CLI args, e.g. `--vis_fast`

Notes
- Transcoding is now handled automatically (default `TRANSCODE=auto`). Force behavior with `TRANSCODE=on` or `TRANSCODE=copy`.
- For local testing, you can also play the stream with VLC: `rtsp://localhost:8554/cam`
- Compose GPU handling varies with Docker versions. If the GPU isn’t detected in alphapose:
  - Use the provided `latest_alphapose/alphapose_url.sh` script instead (uses `--gpus`).
  - Or run Compose with `--compatibility` and set `NVIDIA_VISIBLE_DEVICES=all`.

HTTP/HLS Alternative
- MediaMTX also serves HLS at `http://localhost:8888/cam/index.m3u8` once the publisher is running.
- Latency is higher vs RTSP; prefer RTSP for webcam-like behavior.

Tuning/Robustness
- The alphapose service forces RTSP over TCP and adds reconnect/timeouts via `OPENCV_FFMPEG_CAPTURE_OPTIONS`.
- Adjust GOP (`-g`) and frame rate (`-r`) in publisher if your consumer prefers specific cadence.
- Healthcheck: the publisher has an `ffprobe`-based healthcheck against `rtsp://streamer:8554/${STREAM_PATH}`.
- Autoheal: the `autoheal` sidecar restarts the publisher if it becomes unhealthy. It requires access to the Docker socket.

Using your specific file path
- If you prefer not to copy the file, you can symlink it into `media/` instead:
  - ln -s "/home/user/MeasurementsDTs/videos/rangeOfMotion/hd_00_00_8M.mp4" media/hd_00_00_8M.mp4
  - Then run with: `FILE=/media/hd_00_00_8M.mp4 docker compose up --build`
