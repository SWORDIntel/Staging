#!/usr/bin/env bash
# docker_mx_install.sh – MX Linux 23 / Debian 12 “bookworm”
# VERBOSE=1 sudo ./docker_mx_install.sh   →  full trace + APT & curl debug
# sudo ./docker_mx_install.sh            →  concise progress messages
##############################################################################

: "${VERBOSE:=0}"                 # export VERBOSE=1 for noise
[ "$VERBOSE" -eq 1 ] && set -x    # shell-level tracing  :contentReference[oaicite:5]{index=5}

set -euo pipefail
LOG="/var/log/docker_install_$(date +%F).log"
exec > >(tee -a "$LOG") 2>&1      # everything to file + console

info() { printf '\e[1;34m[INFO]\e[0m  %s\n' "$*"; }
ok()   { printf '\e[1;32m[ OK ]\e[0m  %s\n' "$*"; }
die()  { printf '\e[1;31m[ERR]\e[0m  %s\n' "$*"; exit 1; }
trap 'die "Aborted on line $LINENO"' ERR

APT_FLAGS=()
if [ "$VERBOSE" -eq 1 ]; then     # APT HTTP + resolver debug :contentReference[oaicite:6]{index=6}
  APT_FLAGS+=(
    "-o" "Debug::pkgProblemResolver=1"
    "-o" "Debug::Acquire::http=true"
    "-o" "Dpkg::Progress-Fancy=1"
  )
fi

CURL="curl -fsSL"
[ "$VERBOSE" -eq 1 ] && CURL="$CURL -v"    # curl verbose header dump :contentReference[oaicite:7]{index=7}

##############################################################################
info "Cleaning old Docker & ShiftKey entries"
sudo rm -f /etc/apt/sources.list.d/{docker,shiftkey}*.list
sudo rm -f /etc/apt/keyrings/docker.*
sudo apt-key del 7EA0A9C3F273FCD8 2>/dev/null || true
ok  "Legacy entries removed"

##############################################################################
info "Fetching Docker GPG key"
sudo install -m0755 -d /etc/apt/keyrings
$CURL https://download.docker.com/linux/debian/gpg -o /tmp/docker.asc
sudo mv /tmp/docker.asc /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc
ok  "Key stored in /etc/apt/keyrings/docker.asc"

##############################################################################
info "Verifying key fingerprint"
FPR=$(gpg --batch --quiet --with-colons \
          --import-options show-only --dry-run \
          --import /etc/apt/keyrings/docker.asc | awk -F: '/^fpr:/ {print $10; exit}')
case "$FPR" in
  9DC858229FC7DD38854AE2D88D81803C0EBFCD88) ok "DEB key OK";;
  060A61C51B558A7F742B77AAC52FEB6B621E9F35) ok "RPM key OK";;
  *) die "Unknown Docker key fingerprint: $FPR";;
esac

##############################################################################
info "Adding Docker repository"
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] \
https://download.docker.com/linux/debian $(lsb_release -cs) stable" | \
sudo tee /etc/apt/sources.list.d/docker.list >/dev/null

##############################################################################
info "Updating APT and installing Docker packages"
sudo apt update "${APT_FLAGS[@]}"
sudo apt install -y "${APT_FLAGS[@]}" \
  docker-ce docker-ce-cli containerd.io \
  docker-buildx-plugin docker-compose-plugin

##############################################################################
info "Configuring Docker service autostart"
if [ -d /run/systemd/system ]; then
    info "systemd detected – using systemctl"
    sudo systemctl enable --now docker
else
    info "SysV init detected – using update-rc.d and service"
    sudo update-rc.d docker defaults   # create run-level links :contentReference[oaicite:8]{index=8}
    sudo update-rc.d docker enable
    sudo service docker start          # immediate start under SysV :contentReference[oaicite:9]{index=9}
fi
sudo usermod -aG docker "$USER"
ok  "Added $USER to docker group (log out/in or 'newgrp docker')"

##############################################################################
info "Running hello-world test"
docker run --rm hello-world >/dev/null && ok "Docker is working!"

ok "Install complete – see $LOG for details"
##############################################################################
