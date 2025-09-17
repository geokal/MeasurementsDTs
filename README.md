# 2D Human Pose Estimation

This project provides baseline implementations for a few 2D Human Pose Estimation methods: **AlphaPose**, **OpenPose**, **HigherHRNet**, **EfficientHRNet** and **MoveNet**.

## Dependencies

- Ubuntu 20.04
- Python 3.8.10
- OpenVINO 2024.2.0

### GPU & Drivers
- GPU: NVIDIA
- CUDA Toolkit: 12.6 (release 12.6, V12.6.77)
- PyTorch CUDA: 12.1 (torch.version.cuda)
- PyTorch version: 2.4.1+cu121

##  Getting Started

Clone the repository and make sure to download the required pre-trained models below.

### Required Pretrained Models

Download these required model files and place them in the specified locations:

1. **AlphaPose Models**:
   - fast_res50_256x192.pth (ResNet50 weights):
     ```bash
     wget "https://drive.google.com/uc?export=download&id=1p6bi10UybpUIcq5D2XDsgQRLPJIr2RyI" -O models/AlphaPose/pretrained_models/fast_res50_256x192.pth
     ```
   - yolov3-spp.weights (YOLOv3 detector):
     ```bash
     wget "https://drive.google.com/uc?export=download&id=1k-9cUGcdH5ZFN1NcMvZrO0ApW241tboD" -O models/AlphaPose/detector/yolo/data/yolov3-spp.weights
     ```

2. **MoveNet Model**:
   - movenet_multipose_lightning_256x256_FP32.bin (OpenVINO binaries):
     ```bash
     wget "https://drive.google.com/uc?export=download&id=15SZwY2jAh1KqHwT-YO6_UByOsQD70RSr" -O models/MoveNet/movenet_multipose_lightning_256x256_FP32.bin
     ```

3. **OpenPose Model**:
   - human-pose-estimation-0001.bin (OpenVINO binaries):
     ```bash
     wget "https://drive.google.com/uc?export=download&id=1VNucIyIsdaiw1cYt-JGqBWloVu2TVdsm" -O models/OpenVINO/pretrained_models/intel/human-pose-estimation-0001/human-pose-estimation-0001.bin
     ```

4. **Higher HRNet Model**:
   - higher-hrnet-w32-human-pose-estimation.bin (OpenVINO binaries):
     ```bash
     wget "https://drive.google.com/uc?export=download&id=1fko47eVczJZQb9wWA2X7eQ0TuF4PDXzs" -O models/OpenVINO/pretrained_models/public/FP32/higher-hrnet-w32-human-pose-estimation.bin
     ```

5. **Efficient HRNet1**:
   - human-pose-estimation-0005.bin.bin (OpenVINO binaries):
     ```bash
     wget "https://drive.google.com/uc?export=download&id=1lEUFqQnWHVymQoZvaXuDFcnOyEEKsexP" -O models/OpenVINO/pretrained_models/public/human-pose-estimation-0005/FP32/human-pose-estimation-0005.bin
     ```

6. **Efficient HRNet2**:
   - human-pose-estimation-0006.bin.bin (OpenVINO binaries):
     ```bash
     wget "https://drive.google.com/uc?export=download&id=1d8pGQrM9vEfz_oAIey0qRr7Gxp6dS2UE" -O models/OpenVINO/pretrained_models/public/human-pose-estimation-0006/FP32/human-pose-estimation-0006.bin
     ```

7. **Efficient HRNet3**:
   - human-pose-estimation-0007.bin.bin (OpenVINO binaries):
     ```bash
     wget "https://drive.google.com/uc?export=download&id=1ZSdsqgD4zUO4gyHMYBfxq3m4UMyQ187j" -O models/OpenVINO/pretrained_models/public/human-pose-estimation-0007/FP32/human-pose-estimation-0007.bin
     ```

## Installation

1. Clone the repository

2. Add the downloaded pretrained models in the correct locations

3. Uninstall previous AlphaPose installations (if any)
```bash
pip uninstall alphapose
```

4. Install
```bash
conda create -n hpe python=3.8.10 -y
conda activate hpe
conda install pytorch==2.4.1 torchvision==0.19.1 -c pytorch
conda install --file requirements.txt
```

5. Install AlphaPose
```bash
bash models/AlphaPose/build_extensions.sh
```

### Executing program

Example usage
```
# For MoveNet single image
python3 main.py --method movenet --input unit_tests/images/testImage.jpg --save_image

# For AlphaPose whole directory
python3 main.py --method alphapose --input unit_tests/images/ --json

# For EfficientHRNet1 video
python3 main.py --method ae1 --input unit_tests/video/giphy.gif --save_video

# For detailed options
python3 main.py --help
```

### Developer Utilities

For development or testing purposes, you can use helper tools found in the `dev_tools/` directory.

Example usage
```bash
# Replace <your-ip> with the output of hostname -I:
python3 main.py --method movenet --input http://<your-ip>:8080/video_feed --save_video
 
# In another terminal window, start the video stream server:
python3 dev_tools/stream_video_server.py
```

This will start a local Flask server streaming video from `unit_tests/video/giphy.gif` at `http://<your-ip>:8080/video_feed`

## Post‑Reboot Kernel Check

- Script: run `scripts/check_hwe_gpu.sh` after upgrading to HWE on Ubuntu 20.04. It reports kernel (expect 5.15.x), HWE meta packages, DKMS, NVIDIA, v4l2loopback, firmware, and Secure Boot state.
- Expected: `uname -r` shows a 5.15.x kernel; `dkms status` lists modules built for that kernel; `nvidia-smi` works if an NVIDIA GPU is present.
- If NVIDIA modules aren’t loading:
  - Check Secure Boot: `mokutil --sb-state` (EFI only). Either disable Secure Boot in firmware or sign modules.
  - Rebuild DKMS for current kernel: `sudo dkms autoinstall -k $(uname -r)`
  - Load modules: `sudo modprobe nvidia` (and optionally `sudo modprobe v4l2loopback`)
- Quick module signing (if Secure Boot is enabled):
  - Create a MOK keypair: `openssl req -new -x509 -newkey rsa:2048 -keyout MOK.key -out MOK.crt -nodes -days 36500 -subj "/CN=Local DKMS MOK/"`
  - Enroll key: `sudo mokutil --import MOK.crt` then reboot and enroll in the MOK manager.
  - Sign NVIDIA module: `sudo /usr/src/linux-headers-$(uname -r)/scripts/sign-file sha256 MOK.key MOK.crt $(modinfo -n nvidia)`
  - Reboot and verify with `nvidia-smi`.
