from abc import ABC, abstractmethod
import cv2
import os
from collections import namedtuple
import glob
import time
import torch
import numpy as np
import av # Import PyAV

try:
    import PyNvCodec as nvc
except ImportError:
    nvc = None
    print("[WARNING] PyNvCodec not found. Hardware accelerated video decoding will not be available.")

from utils.visualizer import render
from utils.evaluator import append_COCO_format_json, append_COCO_format_csv, save_COCO_format_json, save_COCO_format_csv, save_Tx_csv_data

class Body:
    def __init__(self, score, xmin, ymin, xmax, ymax, keypoints_score, keypoints, keypoints_norm):
        self.score = score # global/mean score 
        self.xmin = xmin
        self.ymin = ymin
        self.xmax = xmax
        self.ymax = ymax
        self.keypoints_score = keypoints_score # individual scores of the keypoints
        self.keypoints_norm = keypoints_norm # keypoints normalized ([0,1]) coordinates (x,y) in the input image
        self.keypoints = keypoints # keypoints coordinates (x,y) in pixels in the input image

# Padding (all values are in pixel) :
# w (resp. h): horizontal (resp. vertical) padding on the source image to make its ratio same as Movenet model input. 
#               The padding is done on one side (bottom or right) of the image.
# padded_w (resp. padded_h): width (resp. height) of the image after padding
Padding = namedtuple('Padding', ['w', 'h', 'padded_w',  'padded_h'])

class BaseHPE(ABC):
    input_type = None
    output_dir = ""

    def __init__(self, input_src=None,
                output_dir=None,
                enable_json=False,
                enable_csv=False,
                measurement_interval_ms=100,
                save_image=False,
                save_video=False,
                score_thresh=0.2,
                show_scores = True,
                show_bounding_box = True,
                pd_w = 256,
                pd_h = 256,
                gpu_id = 0): # Added gpu_id parameter
        super().__init__()

        self.gpu_id = gpu_id
        self.demuxer = None
        self.decoder = None
        self.to_rgb_converter = None
        self.to_tensor_converter = None
        self.cap = None # Keep for non-PyNvCodec/PyAV paths or fallback
        self.is_pynvcodec_enabled = False
        self.is_pyav_enabled = False # New flag for PyAV
        self.container = None
        self.stream = None

        self.json = enable_json
        self.csv = enable_csv
        self.measurement_interval_ms = measurement_interval_ms
        self.save_image = save_image
        self.save_video = save_video
        self.score_thresh = score_thresh
        self.show_scores = show_scores
        self.show_bounding_box = show_bounding_box
        
        self.img_w = 0
        self.img_h = 0
        self.pd_w = pd_w
        self.pd_h = pd_h
        self.current_image_file = ""

        self.start_time_of_experiment = time.time()
        self.input_file = os.path.basename(os.path.normpath(input_src))

        if self.json or self.csv or self.save_image or self.save_video:
            if output_dir is not None:
                self.output_dir = output_dir
            else:
                self.output_dir = "out/"

            if not os.path.exists(self.output_dir):
                os.makedirs(self.output_dir)

        if os.path.isdir(input_src):
            self.input_type = "directory"
            self.img_dir = input_src
            self.video_fps = 25
        elif input_src:
            if input_src.endswith('.jpg') or input_src.endswith('.png'):
                self.input_type = "image"
                self.img = cv2.imread(input_src)
                self.img_h, self.img_w = self.img.shape[:2]
                self.current_image_file = os.path.basename(input_src)
            elif input_src.startswith("http") or (not input_src.isdigit() and (input_src.endswith('.mp4') or input_src.endswith('.avi') or input_src.endswith('.mov'))):
                # Use PyNvCodec for video streams and files
                if nvc is None:
                    print("[ERROR] PyNvCodec not available. Attempting to use PyAV for video decoding.")
                    try:
                        self._init_pyav_video_capture(input_src)
                        self.input_type = "video"
                    except Exception as e:
                        print(f"[ERROR] Failed to initialize PyAV: {e}. Falling back to OpenCV for video decoding.")
                        self.input_type = "video" # Treat as generic video for OpenCV
                        self._init_opencv_video_capture(input_src)
                else:
                    self.input_type = "video" # Treat all PyNvCodec inputs as video
                    self._init_pynvcodec_video_capture(input_src)
            elif input_src.isdigit():
                # Webcam input (OpenCV only for now, PyNvCodec/PyAV for webcam is more complex)
                self.input_type = "webcam"
                self._init_opencv_video_capture(int(input_src))
            else:
                raise ValueError("No valid input source provided or unsupported file type.")
                
            self.set_padding()
        else:
            raise ValueError("No valid input source provided")
            
        self.input_src = input_src

        if (self.input_type == "directory" or self.input_type == "image") and self.save_video:
            raise ValueError("Image input - video output not supported!")

        if self.save_video:
            fourcc = cv2.VideoWriter_fourcc(*"MJPG")
            filename = os.path.join(self.output_dir, "video.avi")
            self.output = cv2.VideoWriter(filename, fourcc, self.video_fps, (self.img_w, self.img_h))

    def _init_opencv_video_capture(self, input_src):
        if isinstance(input_src, str) and input_src.startswith("http"):
            print(f"Attempting to connect to IP stream at {input_src} using OpenCV...")
            max_retries = 60
            for attempt in range(max_retries):
                self.cap = cv2.VideoCapture()
                try:
                    self.cap.set(cv2.CAP_PROP_OPEN_TIMEOUT_MSEC, 60000)
                    self.cap.set(cv2.CAP_PROP_READ_TIMEOUT_MSEC, 60000)
                except AttributeError:
                    pass
                opened = self.cap.open(input_src, apiPreference=cv2.CAP_FFMPEG)
                if opened and self.cap.isOpened():
                    break
                print(f"[{attempt+1}/{max_retries}] Stream not available, retrying in 1s...")
                time.sleep(1)
            if not self.cap.isOpened():
                raise ValueError(f"Failed to connect to video stream after {max_retries} attempts: {input_src}")
            time.sleep(0.5) # Give OpenCV a small buffer time to fetch metadata
        else:
                self.cap = cv2.VideoCapture(input_src)
                self.cap.set(cv2.CAP_PROP_AUTOFOCUS, 0)
                self.cap.set(cv2.CAP_PROP_FOCUS, 0)
        
        self.video_fps = int(self.cap.get(cv2.CAP_PROP_FPS)) or 25
        self.img_w = int(self.cap.get(cv2.CAP_PROP_FRAME_WIDTH))
        self.img_h = int(self.cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
        self.is_pynvcodec_enabled = False

    def _init_pynvcodec_video_capture(self, input_src):
        if nvc is None:
            raise RuntimeError("PyNvCodec is not installed, cannot use hardware acceleration.")
        
        print(f"[INFO] Attempting to connect to video stream/file at {input_src} using PyNvCodec on GPU {self.gpu_id}...")
        
        try:
            self.demuxer = nvc.FFmpegDemuxer(input_src)
            self.decoder = nvc.PyNvDecoder(self.demuxer.Width(), self.demuxer.Height(), self.demuxer.Format(), self.demuxer.Codec(), self.gpu_id)
            self.to_rgb_converter = nvc.PyNvConverter(self.demuxer.Width(), self.demuxer.Height(), nvc.PixelFormat.NV12, nvc.PixelFormat.RGB, self.gpu_id)
            self.to_tensor_converter = nvc.PyTorchConverter(self.demuxer.Width(), self.demuxer.Height(), nvc.PixelFormat.RGB, self.gpu_id)

            self.img_w = self.demuxer.Width()
            self.img_h = self.demuxer.Height()
            self.video_fps = self.demuxer.AvgFramerateNum() / self.demuxer.AvgFramerateDen() if self.demuxer.AvgFramerateDen() > 0 else 25
            self.is_pynvcodec_enabled = True
            print(f"[INFO] PyNvCodec initialized successfully. Resolution: {self.img_w}x{self.img_h}, FPS: {self.video_fps:.2f}")

        except Exception as e:
            print(f"[ERROR] Failed to initialize PyNvCodec: {e}. Falling back to PyAV for video decoding.")
            self.is_pynvcodec_enabled = False
            try:
                self._init_pyav_video_capture(input_src) # Fallback to PyAV
            except Exception as e_av:
                print(f"[ERROR] Failed to initialize PyAV: {e_av}. Falling back to OpenCV for video decoding.")
                self._init_opencv_video_capture(input_src) # Fallback to OpenCV

    def _init_pyav_video_capture(self, input_src):
        print(f"[INFO] Attempting to connect to video stream/file at {input_src} using PyAV...")
        try:
            self.container = av.open(input_src)
            self.stream = self.container.streams.video[0]
            self.stream.thread_type = "AUTO" # Enable multi-threading for decoding if available

            self.img_w = self.stream.width
            self.img_h = self.stream.height
            self.video_fps = float(self.stream.average_rate) if self.stream.average_rate else 25
            self.is_pyav_enabled = True
            print(f"[INFO] PyAV initialized successfully. Resolution: {self.img_w}x{self.img_h}, FPS: {self.video_fps:.2f}")

        except Exception as e:
            self.is_pyav_enabled = False
            raise e # Re-raise to be caught by the caller for fallback

    @abstractmethod
    def load_model(self):
        pass
    
    def main_loop(self):
        frame_number = 0

        if self.input_type == "image":
            self.process_frame(self.img, frame_number)

        elif self.input_type == "directory":
            # Get all image files from the directory
            image_files = glob.glob(os.path.join(self.img_dir, '*.[pjg][np][ge]*'))
            print(f"Found {len(image_files)} images in {self.img_dir}")

            # Sort files to ensure they are in alphanumeric order
            image_files = sorted(image_files)
            
            total_frames = len(image_files)
            for image_file in image_files:
                print(f"Processing {frame_number+1}/{total_frames}")
                self.img = cv2.imread(image_file)
                if self.img is None:
                    print(f"Failed to load image: {image_file}")
                    continue

                self.img_h, self.img_w = self.img.shape[:2]
                self.set_padding()
                self.process_frame(self.img, frame_number)

                frame_number += 1
        
        elif self.is_pynvcodec_enabled: # PyNvCodec path
            print(f"Starting processing video/stream data with PyNvCodec on GPU {self.gpu_id}. Press CTR+C to exit")
            while True:
                try:
                    # Decode a frame
                    surface = self.decoder.DecodeSingleFrame(self.demuxer)
                    if not surface:
                        break # End of video

                    # Convert NV12 surface to RGB surface
                    rgb_surface = self.to_rgb_converter.Execute(surface)
                    
                    # Convert RGB surface to PyTorch tensor on GPU
                    frame_tensor = self.to_tensor_converter.Execute(rgb_surface)
                    
                    self.process_frame(frame_tensor, frame_number)

                    frame_number += 1
                except Exception as e:
                    print(f"[ERROR] PyNvCodec decoding error: {e}")
                    break # Exit loop on error

        elif self.is_pyav_enabled: # PyAV path
            print("Starting processing video/stream data with PyAV. Press CTR+C to exit")
            for frame_av in self.container.decode(self.stream):
                try:
                    # Convert PyAV frame to NumPy array (BGR for OpenCV)
                    frame_np = frame_av.to_ndarray(format="bgr24")
                    self.process_frame(frame_np, frame_number)
                    frame_number += 1
                except Exception as e:
                    print(f"[ERROR] PyAV processing error: {e}")
                    break # Exit loop on error
            
        else:   # OpenCV video/webcam/stream fallback
            print("Starting processing video/webcam data with OpenCV. Press CTR+C to exit")
            while True:
                ok, frame = self.cap.read()
                if not ok:
                    break

                self.process_frame(frame, frame_number)

                frame_number += 1

        if self.json:
            save_COCO_format_json(os.path.join(self.output_dir, "COCOformat.json"))
        if self.csv:
            save_COCO_format_csv(os.path.join(self.output_dir, f"{self.start_time_of_experiment}_{self.model_type}_{self.input_file}_JSON.csv"))
            save_Tx_csv_data(os.path.join(self.output_dir, f"{self.start_time_of_experiment}_{self.model_type}_{self.input_file}_Tx.csv"))

    def process_frame(self, frame, frame_number):
        timestamp = time.time()

        # If frame is a PyTorch tensor, it's on GPU. Convert to CPU NumPy for OpenCV operations.
        if isinstance(frame, torch.Tensor):
            # Ensure it's RGB (PyNvCodec outputs RGB) and convert to BGR for OpenCV
            frame_np = frame.cpu().numpy()
            frame_np = cv2.cvtColor(frame_np, cv2.COLOR_RGB2BGR)
        else:
            frame_np = frame # Already a NumPy array from OpenCV

        padded = self.pad_and_resize(frame_np) # pad_and_resize expects numpy array
        predictions = self.run_model(padded) # run_model will handle converting padded to tensor if needed
        bodies = self.postprocess(predictions)

        if self.json:
            append_COCO_format_json(bodies, self.score_thresh, frame_number)
        if self.csv:
            append_COCO_format_csv(bodies, self.score_thresh, frame_number, timestamp, self.measurement_interval_ms)

        if self.save_image or self.save_video:
            # Ensure that LINES_BODY is defined in the child class
            if not hasattr(self, 'LINES_BODY'):
                raise ValueError("LINES_BODY is not defined in the child class.")
            
            render(frame_np, bodies, self.LINES_BODY, self.score_thresh, self.show_scores, self.show_bounding_box)

            if self.save_video:
                if not self.output.isOpened():
                    raise ValueError("Failed to open the video writer")
                self.output.write(frame_np)

            elif self.save_image:
                filename = os.path.join(self.output_dir, f"frame_{frame_number:04d}.jpg")
                cv2.imwrite(filename, frame_np)
    
    @abstractmethod
    def run_model(self, padded):
        pass

    @abstractmethod
    def postprocess(self, predictions):
        pass

    # Define the padding
    # Note we don't center the source image. The padding is applied
    # on the bottom or right side. That simplifies a bit the calculation
    # when depadding
    def set_padding(self):
        if self.img_w / self.img_h > self.pd_w / self.pd_h:
            pad_h = int(self.img_w * self.pd_h / self.pd_w - self.img_h)
            self.padding = Padding(0, pad_h, self.img_w, self.img_h + pad_h)
        else:
            pad_w = int(self.img_h * self.pd_w / self.pd_h - self.img_w)
            self.padding = Padding(pad_w, 0, self.img_w + pad_w, self.img_h)

    # Pad and resize the image to prepare for the model input.
    def pad_and_resize(self, frame):
        padded = cv2.copyMakeBorder(frame, 0, self.padding.h, 0, self.padding.w, cv2.BORDER_CONSTANT)
        padded = cv2.resize(padded, (self.pd_w, self.pd_h), interpolation=cv2.INTER_AREA)

        return padded
