#!/usr/bin/env bash
set -euo pipefail

# Publisher: loops a file and publishes to RTSP, with optional transcode.
#
# Env vars (with defaults):
#   FILE=/media/input.mp4
#   STREAM_PATH=cam
#   RTSP_HOST=streamer
#   RTSP_PORT=8554
#   RTSP_TRANSPORT=tcp           # tcp|udp
#   LOOP=                        # unset/empty: no loop; -1 loop forever; N loop N times
#   TRANSCODE=auto               # auto|on|copy
#   VCODEC=libx264               # used when TRANSCODE=on/auto and input not h264
#   PRESET=veryfast              # x264 preset
#   CRF=23                       # x264 CRF (quality)
#   FRAMERATE=                   # e.g. 30 (optional)
#   GOP=                         # e.g. 60 (optional). If empty and FRAMERATE set, we set GOP=FRAMERATE*2

FILE="${FILE:-/media/input.mp4}"
STREAM_PATH="${STREAM_PATH:-cam}"
RTSP_HOST="${RTSP_HOST:-streamer}"
RTSP_PORT="${RTSP_PORT:-8554}"
RTSP_TRANSPORT="${RTSP_TRANSPORT:-tcp}"
LOOP="${LOOP:-}"
TRANSCODE="${TRANSCODE:-auto}"
VCODEC="${VCODEC:-libx264}"
PRESET="${PRESET:-veryfast}"
CRF="${CRF:-23}"
FRAMERATE="${FRAMERATE:-}"
GOP="${GOP:-}"

if [[ ! -f "$FILE" ]]; then
  echo "ERROR: input file not found: $FILE" >&2
  exit 1
fi

RTSP_URL="rtsp://${RTSP_HOST}:${RTSP_PORT}/${STREAM_PATH}"

# Detect input video codec (best-effort)
IN_CODEC="unknown"
if command -v ffprobe >/dev/null 2>&1; then
  IN_CODEC=$(ffprobe -v error -select_streams v:0 -show_entries stream=codec_name \
             -of default=nk=1:nw=1 "$FILE" || echo unknown)
fi

DO_TRANSCODE=0
case "$TRANSCODE" in
  on) DO_TRANSCODE=1 ;;
  copy) DO_TRANSCODE=0 ;;
  auto)
    if [[ "$IN_CODEC" != "h264" ]]; then DO_TRANSCODE=1; fi ;;
  *) echo "WARN: unknown TRANSCODE='$TRANSCODE', defaulting to auto"; \
     if [[ "$IN_CODEC" != "h264" ]]; then DO_TRANSCODE=1; fi ;;
esac

FFMPEG_BASE=( ffmpeg -hide_banner -loglevel info -re )
if [[ -n "$LOOP" ]]; then
  FFMPEG_BASE+=( -stream_loop "$LOOP" )
fi
FFMPEG_BASE+=( -i "$FILE" -rtsp_transport "$RTSP_TRANSPORT" -muxdelay 0.1 )

if [[ "$DO_TRANSCODE" -eq 1 ]]; then
  # Optional cadence params
  XTRA=( )
  if [[ -n "$FRAMERATE" ]]; then
    XTRA+=( -r "$FRAMERATE" )
    if [[ -z "$GOP" && "$FRAMERATE" =~ ^[0-9]+$ ]]; then
      GOP=$(( FRAMERATE * 2 ))
    fi
  fi
  if [[ -n "$GOP" ]]; then
    XTRA+=( -g "$GOP" )
  fi

  echo "Publishing (transcode: $VCODEC, preset=$PRESET, crf=$CRF, fps=${FRAMERATE:-keep}, gop=${GOP:-auto}) -> $RTSP_URL"
  exec "${FFMPEG_BASE[@]}" -an -c:v "$VCODEC" -pix_fmt yuv420p -preset "$PRESET" -crf "$CRF" \
       "${XTRA[@]}" -f rtsp "$RTSP_URL"
else
  echo "Publishing (copy vcodec: $IN_CODEC) -> $RTSP_URL"
  exec "${FFMPEG_BASE[@]}" -an -c:v copy -f rtsp "$RTSP_URL"
fi
