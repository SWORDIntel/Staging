#!/bin/bash
# LONE NOMAD • OpenVINO Python Wheel Builder + Secure Boot Signer
# Author: ChatGPT | Date: 2025‑05‑04

set -euo pipefail

# ─────────────────────────────────────────────────────────────
log()  { printf "\e[1;32m[✓] %s\e[0m\n" "$*"; }
warn() { printf "\e[1;33m[!] %s\e[0m\n" "$*"; }
die()  { printf "\e[1;31m[✗] %s\e[0m\n" "$*"; exit 1; }

# ─────────────────────────────────────────────────────────────
# Detect source root
OVSRC="${1:-$PWD}"
[[ -f "$OVSRC/CMakeLists.txt" ]] || die "No CMakeLists.txt in $OVSRC"

# ─────────────────────────────────────────────────────────────
# Prepare clean Python-only build
BUILDDIR="$OVSRC/build-python"
rm -rf "$BUILDDIR"
mkdir -p "$BUILDDIR"
cd "$BUILDDIR"

log "Configuring OpenVINO with Python packaging"
cmake "$OVSRC" \
  -DCMAKE_BUILD_TYPE=Release \
  -DENABLE_PYTHON=ON \
  -DENABLE_PYTHON_PACKAGING=ON \
  -DENABLE_INTEL_CPU=ON \
  -DENABLE_INTEL_GPU=ON \
  -DENABLE_INTEL_NPU=ON \
  -DENABLE_SAMPLES=OFF \
  -DENABLE_TESTS=OFF

log "Building Python wheel"
cmake --build . --target wheel --parallel $(( $(nproc) / 2 ))

# ─────────────────────────────────────────────────────────────
# Install the wheel
WHEEL=$(find ./bin/wheel/dist -name 'openvino*.whl' | head -n1)
[[ -n "$WHEEL" ]] || die "No wheel built"

log "Installing wheel: $WHEEL"
pip install --upgrade "$WHEEL"

# ─────────────────────────────────────────────────────────────
# Ask about signing
read -rp "Sign runtime .so files for Secure Boot? (y/N) " choice
if [[ "$choice" =~ ^[Yy]$ ]]; then
  [[ -f /root/MOK.priv && -f /root/MOK.pem ]] || die "MOK keys not found in /root"

  mapfile -t sos < <(find /opt/openvino -name '*.so')
  for so in "${sos[@]}"; do
    signed="$so.signed"
    sbsign --key /root/MOK.priv --cert /root/MOK.pem --output "$signed" "$so" && mv "$signed" "$so"
  done
  log "All .so files signed for Secure Boot"
fi

# ─────────────────────────────────────────────────────────────
log "Python OpenVINO build complete"
python3 -c 'from openvino.runtime import Core; print("Devices:", Core().available_devices)'
