#!/usr/bin/env bash
#
# bootstrap-node-dev.sh — Idempotent Node.js dev environment setup
# Checks for and installs missing APT & global npm packages,
# hardens npm config, logs to ~/node_dev_setup.log
#

set -euo pipefail
trap 'log_error "Script failed at line $LINENO"; exit 1' ERR

LOG_FILE="$HOME/node_dev_setup.log"
exec > >(tee -a "$LOG_FILE") 2>&1

log_info()  { echo "[INFO]  $(date '+%Y-%m-%d %H:%M:%S') $*"; }
log_error() { echo "[ERROR] $(date '+%Y-%m-%d %H:%M:%S') $*"; }

# 1️⃣ Define required packages
APT_PKGS=(
  nodejs npm yarn eslint rollup gulp grunt webpack
  node-typescript node-babel7 node-express node-react node-vue
  jq curl build-essential libssl-dev
)

NPM_PKGS=(
  prettier sass stylelint svgo marked @angular/cli
  nodemon livereload pm2
)

# 2️⃣ Check & install APT packages
MISSING_APT=()
log_info "Checking APT packages..."
for pkg in "${APT_PKGS[@]}"; do
  if ! dpkg -s "$pkg" &>/dev/null; then
    MISSING_APT+=("$pkg")
    log_info "⏳ Will install: $pkg"
  else
    log_info "✅ Already installed: $pkg"
  fi
done

if [ "${#MISSING_APT[@]}" -gt 0 ]; then
  log_info "Updating APT repository..."
  sudo apt update
  log_info "Installing missing APT packages: ${MISSING_APT[*]}"
  sudo apt install -y "${MISSING_APT[@]}"
else
  log_info "All APT packages are present."
fi

# 3️⃣ Harden npm configuration
log_info "Hardening npm configuration..."
npm set strict-ssl true
npm set audit true

# 4️⃣ Check & install global npm packages
MISSING_NPM=()
log_info "Checking global npm packages..."
for pkg in "${NPM_PKGS[@]}"; do
  if ! npm list -g --depth=0 "$pkg" &>/dev/null; then
    MISSING_NPM+=("$pkg")
    log_info "⏳ Will install: $pkg"
  else
    log_info "✅ Already installed: $pkg"
  fi
done

if [ "${#MISSING_NPM[@]}" -gt 0 ]; then
  log_info "Installing missing global npm packages: ${MISSING_NPM[*]}"
  sudo npm install -g "${MISSING_NPM[@]}"
else
  log_info "All global npm packages are present."
fi

log_info "✅ Node.js development environment bootstrap complete."
