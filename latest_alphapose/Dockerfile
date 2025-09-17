FROM pytorch/pytorch:2.3.1-cuda12.1-cudnn8-runtime

# System deps (git for clone, tzdata to avoid prompts)
RUN apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    git ca-certificates tzdata \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Clone AlphaPose (shallow)
RUN git clone --depth=1 https://github.com/MVIG-SJTU/AlphaPose.git /app

# Python deps
# - Use headless OpenCV (includes FFmpeg in the wheel) for HTTP/RTSP input
# - Install common AlphaPose deps explicitly to avoid surprises across commits
RUN pip install --no-cache-dir \
    opencv-python-headless==4.9.0.80 \
    cython \
    numpy \
    scipy \
    yacs \
    pyyaml \
    tqdm \
    pillow \
    matplotlib \
    json_tricks \
    pycocotools \
    requests \
    onnx \
    onnxruntime-gpu==1.17.0

# Some AlphaPose versions include a setup.py; if present, install in dev mode
RUN if [ -f setup.py ]; then pip install --no-cache-dir -e .; fi

# Create standard mount points for weights and outputs
RUN mkdir -p /weights /out

# Default to bash; pass the Python command at `docker run` time
ENTRYPOINT ["/bin/bash","-lc"]

