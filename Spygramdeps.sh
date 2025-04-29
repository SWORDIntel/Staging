#!/usr/bin/env bash
# install_dev_deps.sh – Install Qt6, CMake, Python, compilers & dev libs on MX Linux 23 (Bookworm)
# Usage:
#   sudo ./install_dev_deps.sh
#   VERBOSE=1 sudo ./install_dev_deps.sh  (for -x, APT debug)

set -euo pipefail
: "${VERBOSE:=0}"
[ "$VERBOSE" -eq 1 ] && set -x

LOG="/var/log/dev_deps_install_$(date +%F).log"
exec > >(tee -a "$LOG") 2>&1

info(){ printf '\e[1;34m[INFO]\e[0m  %s\n' "$*"; }
ok()  { printf '\e[1;32m[ OK ]\e[0m  %s\n' "$*"; }
die() { printf '\e[1;31m[ERR]\e[0m  %s\n' "$*"; exit 1; }
trap 'die "Aborted on line $LINENO"' ERR

# APT debug flags if VERBOSE
APT_FLAGS=()
if [ "$VERBOSE" -eq 1 ]; then
  APT_FLAGS+=( -o Debug::pkgProblemResolver=1 \
               -o Debug::Acquire::http=true \
               -o Dpkg::Progress-Fancy=1 )
fi

# -----------------------------------------------------------------------------
info "1. Updating package index"
sudo apt update "${APT_FLAGS[@]}"

info "2. Installing core build tools & languages"
sudo apt install -y "${APT_FLAGS[@]}" \
  build-essential gcc-12 g++-12 \
  cmake python3 python3-pip

info "3. Installing Qt 6 development libraries"
sudo apt install -y "${APT_FLAGS[@]}" \
  qt6-base-dev qt6-base-private-dev qt6-base-dev-tools \
  qt6-declarative-dev qt6-charts-dev

info "4. X11 & windowing libraries"
sudo apt install -y "${APT_FLAGS[@]}" \
  libx11-dev libx11-xcb-dev libxcb1-dev libxcb-glx0-dev \
  libxcb-keysyms1-dev libxcb-image0-dev libxcb-shm0-dev

info "5. OpenGL / EGL / DRM"
sudo apt install -y "${APT_FLAGS[@]}" \
  libgl1-mesa-dev libegl1-mesa-dev libdrm-dev

info "6. Boost C++ libraries"
sudo apt install -y "${APT_FLAGS[@]}" \
  libboost-all-dev

info "7. Multimedia & audio libraries"
sudo apt install -y "${APT_FLAGS[@]}" \
  ffmpeg libavcodec-dev libavformat-dev libavutil-dev \
  libswscale-dev libavfilter-dev libopenal-dev \
  libpulse-dev libasound2-dev

info "8. GTK 3 development libraries"
sudo apt install -y "${APT_FLAGS[@]}" \
  libgtk-3-dev

ok "All requested development dependencies have been installed."
