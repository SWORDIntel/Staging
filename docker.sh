#!/usr/bin/env bash
# Hardened Docker CE install for MX Linux 23 / Debian 12 (Bookworm)
# Accepts both official Docker fingerprints.
set -euo pipefail

LOG="/var/log/docker_install_$(date +%F).log"
exec > >(tee -a "$LOG") 2>&1

info() { printf '\e[1;34m[INFO]\e[0m  %s\n' "$*"; }
ok()   { printf '\e[1;32m[ OK ]\e[0m  %s\n' "$*"; }
die()  { printf '\e[1;31m[ERR]\e[0m  %s\n' "$*"; exit 1; }
trap 'die "Script aborted on line $LINENO"' ERR

###############################################################################
# 1. Purge conflicting sources/keys (old Docker, ShiftKey GitHub-Desktop)
###############################################################################
info "Removing legacy Docker & ShiftKey sources"
sudo rm -f /etc/apt/sources.list.d/{docker,shiftkey}*.list
sudo rm -f /etc/apt/keyrings/docker.*
sudo apt-key del 7EA0A9C3F273FCD8 2>/dev/null || true
ok  "Old entries removed"

###############################################################################
# 2. Fetch Docker’s ASCII key to /etc/apt/keyrings
###############################################################################
info "Fetching Docker GPG key"
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg -o /tmp/docker.asc
sudo mv /tmp/docker.asc /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc
ok  "Key stored"

###############################################################################
# 3. Verify fingerprint (accept DEB or RPM key)
###############################################################################
info "Verifying key fingerprint"
FPR=$(gpg --batch --quiet --with-colons \
          --import-options show-only --dry-run \
          --import /etc/apt/keyrings/docker.asc | \
      awk -F: '/^fpr:/ {print $10; exit}')

echo "    Found fingerprint: $FPR"
case "$FPR" in
  9DC858229FC7DD38854AE2D88D81803C0EBFCD88) ok "DEB key OK";;
  060A61C51B558A7F742B77AAC52FEB6B621E9F35) ok "RPM key OK";;
  *) die "Unknown fingerprint – aborting!";;
esac

###############################################################################
# 4. Register repository (signed-by path required by Debian 12)
###############################################################################
info "Adding Docker repository"
echo "deb [arch=$(dpkg --print-architecture) \
signed-by=/etc/apt/keyrings/docker.asc] \
https://download.docker.com/linux/debian $(lsb_release -cs) stable" | \
sudo tee /etc/apt/sources.list.d/docker.list >/dev/null

###############################################################################
# 5. Install Docker CE + extras
###############################################################################
info "Updating package index"
sudo apt update
info "Installing Docker Engine, CLI, Buildx & Compose plugin"
sudo apt install -y docker-ce docker-ce-cli containerd.io \
                    docker-buildx-plugin docker-compose-plugin

###############################################################################
# 6. Enable service and configure non-root usage
###############################################################################
info "Enabling docker.service"
sudo systemctl enable --now docker
sudo usermod -aG docker "$USER"
ok  "User '$USER' added to docker group (log out/in or run 'newgrp docker')"

###############################################################################
# 7. Smoke-test
###############################################################################
info "Running hello-world test container"
docker run --rm hello-world >/dev/null && ok "Docker works!"

ok "Complete – see $LOG for full transcript"
