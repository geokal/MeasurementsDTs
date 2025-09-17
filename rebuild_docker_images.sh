#!/bin/bash
set -e

echo "Starting Docker images rebuild..."

# Root Dockerfiles
docker build -f Dockerfile_base -t nvcr.io/nvidia/k8s/dcgm-exporter:4.2.3-4.1.1-ubuntu22.04 .
docker build -f Dockerfile_base_slim -t dash-caching:proxy .
docker build -f Dockerfile_optimized -t bluenviron/mediamtx:latest .
docker build -f Dockerfile.hpe -t dash-caching:client .

# dev_tools
docker build -f dev_tools/Dockerfile -t perf_monitor:latest .

# ffmpeg_hpe
docker build -f ffmpeg_hpe/Dockerfile.gpu_metrics -t gakis41/ffmpeg_hpe-gpu-metrics:latest ffmpeg_hpe

# Measure_gpu_dcgm
docker build -f Measure_gpu_dcgm/Dockerfile.gpu_metrics -t gakis41/ffmpeg_hpe-bcc-tracer:latest Measure_gpu_dcgm

# Measure_plot_cpu_perf
docker build -f Measure_plot_cpu_perf/Dockerfile -t quay.io/iovisor/bpftrace:latest Measure_plot_cpu_perf

# monitor_hpe
docker build -f monitor_hpe/Dockerfile_base -t ffmpeg_hpe-monitor-hpe:latest monitor_hpe
docker build -f monitor_hpe/Dockerfile.perf -t dash-caching:http monitor_hpe

# rtsp-ipcam
docker build -f rtsp-ipcam/Dockerfile -t hpe_movenet_openpose_hrnet:latest rtsp-ipcam

# recent-dash
docker build -f recent-dash/HTTP-Server.Dockerfile -t jrottenberg/ffmpeg:4.4-ubuntu recent-dash
docker build -f recent-dash/HTTP-Proxy.Dockerfile -t gakis41/ffmpeg_hpe-h264-streaming-server:latest recent-dash
docker build -f recent-dash/HTTP-Client.Dockerfile -t gakis41/ffmpeg_hpe-h264-streaming-server:latest recent-dash
docker build -f recent-dash/perf_monitor/Dockerfile -t roshumble-desktop:latest recent-dash/perf_monitor

echo "Docker images rebuild completed."
