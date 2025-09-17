import os
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import argparse
from movenet_hpe import MoveNetHPE
from openvino_base_hpe import OpenVINOBaseHPE
from alphapose_hpe import AlphaPoseHPE

def main():
    parser = parse_arguments()
    args = parser.parse_args()

    hpe = get_hpe_method(args)
    hpe.load_model()
    hpe.main_loop()

def parse_arguments():
        parser = argparse.ArgumentParser()
        parser.add_argument('--method', type=str, required=True, choices=['openpose', 'alphapose', 'movenet', 'hrnet', 'ae1', 'ae2', 'ae3'])
        parser.add_argument('--input', type=str, default='0', help="Path to video or image file to use as input (default=%(default)s)")
        parser.add_argument("--output_dir", type=str, help="Path to directory where output files will be saved")          
        parser.add_argument("--json", action="store_true", help="Enable export keypoints to a single json file")
        parser.add_argument("--csv", action="store_true", help="Enable export keypoints to a single csv file")
        parser.add_argument("--measurement_interval_ms", type=int, default=100, help="Interval in ms for measuring transmitted data volume per interval")
        parser.add_argument("--save_video", action="store_true", help="Save resutls into a video file")
        parser.add_argument("--save_image", action="store_true", help="Save image with keypoints")
        parser.add_argument('--device', type=str, default="GPU", choices=['GPU', 'CPU'], help="Device to run inference on. Options: CPU, GPU")
        parser.add_argument('--detbatch', type=int, default=5, help="Detection batch size (default=%(default)s)")
        
        return parser

def get_hpe_method(args):
    method_map = {
        'movenet': lambda args: MoveNetHPE(device=args.device, **base_args(args)),
        'alphapose': lambda args: AlphaPoseHPE(device=args.device, detbatch=args.detbatch, **base_args(args)),
        'openpose': lambda args: OpenVINOBaseHPE(model_type='openpose', device=args.device, detbatch=args.detbatch, **base_args(args)),
        'hrnet': lambda args: OpenVINOBaseHPE(model_type='higherhrnet', device=args.device, **base_args(args)),
        'ae1': lambda args: OpenVINOBaseHPE(model_type='efficienthrnet1', device=args.device, **base_args(args)),
        'ae2': lambda args: OpenVINOBaseHPE(model_type='efficienthrnet2', device=args.device, **base_args(args)),
        'ae3': lambda args: OpenVINOBaseHPE(model_type='efficienthrnet3', device=args.device, **base_args(args)),
    }

    name = args.method.lower()

    if name not in method_map:
        raise ValueError(f"Unknown method: {name}")

    if callable(method_map[name]):
        return method_map[name](args)
    else:
        return method_map[name](**base_args(args))

def base_args(args):
    return {
        "input_src": args.input,
        "output_dir": args.output_dir,
        "enable_json": args.json,
        "enable_csv": args.csv,
        "measurement_interval_ms": args.measurement_interval_ms,
        "save_image": args.save_image,
        "save_video": args.save_video
    }


if __name__ == "__main__":
    main()
