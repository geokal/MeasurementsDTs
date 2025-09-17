#!/usr/bin/env bash

set -euo pipefail

echo "== v4l2loopback autoload setup =="

if ! command -v modprobe >/dev/null 2>&1; then
  echo "modprobe not found; are you on a minimal container?" >&2
  exit 1
fi

if ! modinfo v4l2loopback >/dev/null 2>&1; then
  echo "v4l2loopback module not found. On Ubuntu: sudo apt-get install -y v4l2loopback-dkms" >&2
fi

conf_dir="/etc/modules-load.d"
modprobe_dir="/etc/modprobe.d"

if [ "${EUID}" -ne 0 ]; then
  echo "This script needs root to write to ${conf_dir} and ${modprobe_dir}." >&2
  echo "Re-run: sudo bash $0 [video_nr=10 exclusive_caps=1 card_label=VirtualCam]" >&2
  exit 1
fi

mkdir -p "${conf_dir}" "${modprobe_dir}"

# 1) Ensure module loads at boot
echo "v4l2loopback" > "${conf_dir}/v4l2loopback.conf"
echo "Wrote ${conf_dir}/v4l2loopback.conf"

# 2) Optional module options (pass as args: key=value pairs)
if [ "$#" -gt 0 ]; then
  opts="options v4l2loopback $*"
  echo "${opts}" > "${modprobe_dir}/v4l2loopback.conf"
  echo "Wrote ${modprobe_dir}/v4l2loopback.conf with options: $*"
else
  echo "No options provided. You can re-run with e.g.:"
  echo "  sudo bash $0 video_nr=10 exclusive_caps=1 card_label=VirtualCam devices=1"
fi

# 3) Load module immediately
if lsmod | grep -q '^v4l2loopback\b'; then
  echo "v4l2loopback already loaded"
else
  echo "Loading v4l2loopback..."
  if [ "$#" -gt 0 ]; then
    modprobe v4l2loopback "$@"
  else
    modprobe v4l2loopback
  fi
fi

echo "Loaded modules:"
lsmod | awk '/^v4l2loopback/ {print $0}' || true

echo "Done. v4l2loopback will autoload on next boot."

