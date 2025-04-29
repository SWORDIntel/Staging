#!/usr/bin/env bash
# docker_mx_install.sh – MX Linux 23 / Debian 12 “bookworm”
#   VERBOSE=1 → full trace + curl -v + APT debug
#   (sudo ./docker_mx_install.sh) → concise progress
set -euo pipefail

: "${VERBOSE:=0}"
[ "$VERBOSE" -eq 1 ] && set -x

LOG="/var/log/docker_install_$(date +%F).log"
exec > >(tee -a "$LOG") 2>&1

info(){ printf '\e[1;34m[INFO]\e[0m  %s\n' "$*"; }
ok(){   printf '\e[1;32m[ OK ]\e[0m  %s\n' "$*"; }
die(){  printf '\e[1;31m[ERR]\e[0m  %s\n' "$*"; exit 1; }
trap 'die "Aborted on line $LINENO"' ERR

# APT debug flags if VERBOSE
APT_FLAGS=()
if [ "$VERBOSE" -eq 1 ]; then
  APT_FLAGS+=( -o Debug::pkgProblemResolver=1 \
               -o Debug::Acquire::http=true \
               -o Dpkg::Progress-Fancy=1 )
fi

# curl with optional verbose
CURL="curl -fsSL"
[ "$VERBOSE" -eq 1 ] && CURL="$CURL -v"

########################################
info "1. Clean legacy Docker & ShiftKey entries"
sudo rm -f /etc/apt/sources.list.d/{docker,shiftkey}*.list
sudo rm -f /etc/apt/keyrings/docker.*
sudo apt-key del 7EA0A9C3F273FCD8 2>/dev/null || true
ok "Legacy entries removed"

########################################
info "2. Fetch & verify Docker GPG key"
sudo install -m0755 -d /etc/apt/keyrings
$CURL https://download.docker.com/linux/debian/gpg -o /tmp/docker.asc
sudo mv /tmp/docker.asc /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

FPR=$(gpg --batch --quiet \
      --with-colons --import-options show-only --dry-run \
      --import /etc/apt/keyrings/docker.asc \
      | awk -F: '/^fpr:/ {print $10; exit}')
case "$FPR" in
  9DC858229FC7DD38854AE2D88D81803C0EBFCD88) ok "DEB key OK";;
  060A61C51B558A7F742B77AAC52FEB6B621E9F35) ok "RPM key OK";;
  *) die "Unknown Docker key fingerprint: $FPR";;
esac

########################################
info "3. Add Docker APT repository"
echo "deb [arch=$(dpkg --print-architecture) \
signed-by=/etc/apt/keyrings/docker.asc] \
https://download.docker.com/linux/debian $(lsb_release -cs) stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
ok "Repository added"

########################################
info "4. Install prerequisite helpers"
# cgroupfs-mount for SysV cgroup v1 mounts :contentReference[oaicite:2]{index=2}
sudo apt update "${APT_FLAGS[@]}"
sudo apt install -y "${APT_FLAGS[@]}" \
     cgroupfs-mount iptables uidmap

########################################
info "5. Mount cgroups & load kernel modules"
sudo service cgroupfs-mount start
sudo modprobe overlay br_netfilter || true
echo -e "overlay\nbr_netfilter" | sudo tee /etc/modules-load.d/docker.conf >/dev/null
# iptables-legacy fallback :contentReference[oaicite:3]{index=3}
sudo update-alternatives --set iptables /usr/sbin/iptables-legacy || true
ok "Cgroups mounted, modules loaded, iptables set to legacy"

########################################
info "6. Install Docker Engine, CLI, Buildx & Compose"
sudo apt update "${APT_FLAGS[@]}"
sudo apt install -y "${APT_FLAGS[@]}" \
     docker-ce docker-ce-cli containerd.io \
     docker-buildx-plugin docker-compose-plugin
ok "Docker packages installed"

########################################
info "7. Enable & start Docker service (SysV or systemd)"
if [ -d /run/systemd/system ]; then
  info "systemd detected"
  sudo systemctl enable --now docker
else
  info "SysV init detected"
  sudo update-rc.d docker defaults
  sudo update-rc.d docker enable
  sudo service docker start
fi

########################################
info "8. Wait for Docker socket up to 20s"
for i in {1..20}; do
  [ -S /var/run/docker.sock ] && { ok "Docker socket ready"; break; }
  sleep 1
done
if ! [ -S /var/run/docker.sock ]; then
  die "dockerd failed to create socket; last 40 lines of /var/log/docker.log:" \
      && sudo tail -n40 /var/log/docker.log
fi

########################################
info "9. Configure user permissions"
sudo usermod -aG docker "$USER"
ok "Added $USER to docker group (log out/in to refresh)"

########################################
info "10. Smoke-test with hello-world"
docker run --rm hello-world >/dev/null && ok "Docker is working!"

ok "All done – see $LOG for full details"
