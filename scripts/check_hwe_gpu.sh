#!/usr/bin/env bash

# Post-reboot health check for HWE kernel + DKMS + NVIDIA
# Safe to run on Ubuntu 20.04 hosts after installing linux-generic-hwe-20.04

set -u

print_section() {
  echo
  echo "==== $1 ===="
}

have() { command -v "$1" >/dev/null 2>&1; }

os_pretty() {
  if [ -r /etc/os-release ]; then
    . /etc/os-release
    echo "${PRETTY_NAME:-Unknown}"
  else
    echo "Unknown"
  fi
}

KREL=$(uname -r)
KMAJ=${KREL%%-*}    # e.g., 5.15.0

print_section "System"
echo "OS:       $(os_pretty)"
echo "Kernel:   ${KREL}"
echo "Hostname: $(hostname)"
if [ -f /var/run/reboot-required ]; then
  echo "Reboot required flag present: /var/run/reboot-required"
fi

print_section "HWE Packages"
for pkg in linux-generic-hwe-20.04 linux-image-generic-hwe-20.04 linux-headers-generic-hwe-20.04; do
  if dpkg -s "$pkg" >/dev/null 2>&1; then
    ver=$(dpkg -s "$pkg" 2>/dev/null | awk -F': ' '/^Version:/{print $2}')
    echo "$pkg: installed ($ver)"
  else
    echo "$pkg: NOT installed"
  fi
done

print_section "Installed Kernel Images (latest 5 shown)"
dpkg -l 'linux-image-*' 2>/dev/null | awk '/^ii/ {print $2"\t"$3}' | sort -V | tail -n 5

print_section "linux-firmware"
if have apt-cache; then
  apt-cache policy linux-firmware 2>/dev/null | sed 's/^/  /'
else
  dpkg -s linux-firmware 2>/dev/null | awk -F': ' 'BEGIN{ok=0} /^Package:|^Status:|^Version:/ {print; ok=1} END{if(!ok) print "linux-firmware: not installed"}'
fi

print_section "DKMS Status"
if have dkms; then
  dkms status || true
else
  echo "dkms not installed"
fi

print_section "NVIDIA"
if have nvidia-smi; then
  echo "nvidia-smi present"
  nvidia-smi -L || true
  echo
  nvidia-smi || true
else
  echo "nvidia-smi not found"
fi

if have modinfo; then
  if modinfo nvidia >/dev/null 2>&1; then
    echo "nvidia module version: $(modinfo -F version nvidia 2>/dev/null)"
  else
    echo "nvidia kernel module not found (modinfo nvidia)"
  fi
fi

echo
echo "Loaded NVIDIA modules (if any):"
lsmod | awk '/^nvidia/ {print $0}' || true

print_section "v4l2loopback"
if have modinfo && modinfo v4l2loopback >/dev/null 2>&1; then
  echo "v4l2loopback module version: $(modinfo -F version v4l2loopback 2>/dev/null)"
else
  echo "v4l2loopback module not found"
fi
echo
echo "Loaded v4l2loopback (if any):"
lsmod | awk '/^v4l2loopback/ {print $0}' || true

print_section "Boot Mode / Secure Boot"
if [ -d /sys/firmware/efi ]; then
  echo "EFI detected"
  if have mokutil; then
    mokutil --sb-state || true
  else
    echo "mokutil not installed; Secure Boot state unknown"
  fi
else
  echo "Legacy BIOS (no EFI directory)"
fi

print_section "Quick Summary"

status_ok=1

# Expect HWE kernel to be 5.15 on focal
case "$KMAJ" in
  5.15.*) echo "[OK] Running HWE 5.15 kernel ($KREL)" ;;
  *) echo "[WARN] Kernel is $KREL; expected 5.15.x for HWE on 20.04"; status_ok=0 ;;
esac

# NVIDIA loaded check (optional if system has NVIDIA)
if lspci -nn | grep -qi 'NVIDIA'; then
  if lsmod | grep -q '^nvidia\b'; then
    echo "[OK] NVIDIA kernel modules loaded"
  else
    echo "[WARN] NVIDIA GPU detected but kernel modules not loaded"
    status_ok=0
  fi
else
  echo "[INFO] No NVIDIA GPU detected by lspci"
fi

# v4l2loopback optional
if lsmod | grep -q '^v4l2loopback\b'; then
  echo "[OK] v4l2loopback loaded"
else
  echo "[INFO] v4l2loopback not loaded"
fi

if [ "$status_ok" -eq 1 ]; then
  echo "Overall: OK"
else
  echo "Overall: Issues detected (see warnings above)"
fi

echo
echo "Tip: If NVIDIA modules fail to load under Secure Boot, sign modules or disable Secure Boot."
