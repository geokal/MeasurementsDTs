# Based on https://github.com/geaxgx/openvino_movenet_multipose/tree/main

from openvino.runtime import Core, Type
from openvino.preprocess import PrePostProcessor, ColorFormat, ResizeAlgorithm
import numpy as np
import cv2
from pathlib import Path
from base_hpe import BaseHPE, Body

SCRIPT_DIR = Path(__file__).resolve().parent
DEFAULT_MODEL = SCRIPT_DIR / "models/MoveNet/movenet_multipose_lightning_256x256_FP32.xml"

class MoveNetHPE(BaseHPE):
    LINES_BODY = [
        [4,2], [2,0], [0,1], [1,3],
        [10,8], [8,6], [6,5], [5,7], [7,9],
        [6,12], [12,11], [11,5],
        [12,14], [14,16], [11,13], [13,15]
    ]

    def __init__(self, xml_path=DEFAULT_MODEL, device="CPU", **kwargs):
        kwargs['pd_w'] = 256
        kwargs['pd_h'] = 256
        super().__init__(**kwargs)
        self.xml_path = xml_path
        self.device = device
        self.model_type = "movenet"

        if self.device == "GPU":
            print(f"[INFO] Model '{self.model_type}' is not supported on GPU. Falling back to CPU.")
            self.device = "CPU"

    def load_model(self):
        print("Loading MoveNetHPE model...")
        self.ie = Core()
        print("Device info:")
        versions = self.ie.get_versions(self.device)
        print("{}{}".format(" "*8, self.device))
        for key, version in versions.items():
            print(f"{key}: version {version.major}.{version.minor}, build {version.build_number}")

        print("Reading network")
        model = self.ie.read_model(model=self.xml_path)
        # Force the model's input shape to NCHW [1, 3, H, W]
        model.reshape({model.inputs[0].get_any_name(): [1, 3, self.pd_h, self.pd_w]})

        # Configure PrePostProcessor
        ppp = PrePostProcessor(model)
        ppp.input().tensor() \
            .set_element_type(Type.u8) \
            .set_color_format(ColorFormat.BGR) \
            .set_layout("HWC") # Assuming input to preprocessor is HWC (height, width, channels)

        ppp.input().preprocess() \
            .convert_color(ColorFormat.RGB) \
            .resize(ResizeAlgorithm.RESIZE_LINEAR, self.pd_h, self.pd_w) \
            .convert_element_type(Type.f32) \
            .scale([255.0, 255.0, 255.0]) # Normalize to [0,1] if model expects it, otherwise remove or adjust

        ppp.input().model().set_layout("NCHW") # Model expects NCHW (batch, channels, height, width)

        ppp.output().tensor().set_element_type(Type.f32)

        self.pd_net = ppp.build()

        input_tensor = self.pd_net.inputs[0]
        print(f"Input info: {self.pd_net.inputs}")
        print(f"Output info: {self.pd_net.outputs}")

        self.pd_input_blob = input_tensor.get_any_name()
        print(f"Input blob: {self.pd_input_blob} - shape: {input_tensor.shape}")
        # self.pd_h and self.pd_w are already set in __init__
        for output in self.pd_net.outputs:
            print(f"Output blob: {output.get_any_name()} - shape: {output.shape}")

        self.pd_kps = "Identity"
        print("Loading pose detection model into the plugin")
        
        # Configure OpenVINO performance hints for CPU
        config = {
            "NUM_STREAMS": "AUTO",
            "PERFORMANCE_HINT": "LATENCY",
            "INFERENCE_PRECISION_HINT": "f32" # Explicitly set for CPU
        }
        self.pd_exec_net = self.ie.compile_model(model=self.pd_net, device_name=self.device, config=config)

    def run_model(self, padded):
        # Preprocessing is now handled by PrePostProcessor
        return self.pd_exec_net.infer_new_request({self.pd_input_blob: padded})
    
    def postprocess(self, predictions):
        result = np.squeeze(predictions[self.pd_kps]) # 6x56
        bodies = []
        
        for i in range(6):
            kps = result[i][:51].reshape(17,-1)
            bbox = result[i][51:55].reshape(2,2)          
            score = result[i][55]
            if score > self.score_thresh:   # TODO - use seperate keypoint scores
                ymin, xmin, ymax, xmax = (bbox * [self.padding.padded_h, self.padding.padded_w]).flatten().astype(int)

                kp_xy =kps[:,[1,0]]
                keypoints = kp_xy * np.array([self.padding.padded_w, self.padding.padded_h])
                keypoints = np.array(keypoints)

                body = Body(score=score, xmin=xmin, ymin=ymin, xmax=xmax, ymax=ymax, 
                            keypoints_score = kps[:,2], 
                            keypoints = keypoints.astype(float),
                            keypoints_norm = keypoints / np.array([self.img_w, self.img_h]))
                
                bodies.append(body)
                
        return bodies
