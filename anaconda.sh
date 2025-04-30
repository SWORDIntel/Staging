#!/usr/bin/env bash
# install_anaconda_mx.sh – Interactive, verbose Anaconda installer for MX Linux 23 / Debian 12
set -euo pipefail
set -x

LOG="/var/log/anaconda_install_$(date +%F).log"
exec > >(tee -a "$LOG") 2>&1

info(){ printf '\e[1;34m[INFO]\e[0m  %s\n' "$*"; }
ok()  { printf '\e[1;32m[ OK ]\e[0m  %s\n' "$*"; }
die() { printf '\e[1;31m[ERR]\e[0m  %s\n' "$*"; exit 1; }

ANACONDA_VER="2024.10-1"
INSTALLER="Anaconda3-${ANACONDA_VER}-Linux-x86_64.sh"
URL="https://repo.anaconda.com/archive/${INSTALLER}"
PREFIX="$HOME/anaconda3"

info "1. Installing required packages"
sudo apt update
sudo apt install -y bzip2 libgl1-mesa-glx || die "Failed to install prerequisites"
ok "Prerequisites installed"

info "2. Downloading Anaconda installer via curl -O"
cd /tmp
curl -O "$URL" || die "Download failed"
ok "Downloaded $INSTALLER to /tmp"

info "3. Running installer (interactive)"

echo
echo ">>> The Anaconda installer will now run."
echo ">>> Review and accept the license, set installation path, etc."
echo
bash "/tmp/$INSTALLER" || die "Installer exited with error"

ok "Installer completed"

info "4. Cleaning up installer script"
rm -f "/tmp/$INSTALLER"
ok "Removed installer script"

info "5. Initializing conda in your shell"
# This may modify your ~/.bashrc or ~/.zshrc; review its output.
"$HOME/anaconda3/bin/conda" init --all || die "conda init failed"
ok "conda initialized"

info "6. Restart your shell or source your rc file to pick up conda"
echo
echo "    Run: exec \"\$SHELL\""
echo

info "7. (Optional) Smoke-test"
read -rp "Run a quick smoke-test of a new env? [y/N]: " resp
if [[ "$resp" =~ ^[Yy]$ ]]; then
  "$HOME/anaconda3/bin/conda" create -y -n smoke pycos --yes python=3.11 pip || die "Failed to create env"
  "$HOME/anaconda3/bin/conda" run -n smoke pip install pendulum || die "pip install pendulum failed"
  "$HOME/anaconda3/bin/conda" run -n smoke python - <<'EOF'
import pendulum
print("Smoke-test →", pendulum.now().to_datetime_string())
EOF
  "$HOME/anaconda3/bin/conda" env remove -y -n smoke
  ok "Smoke-test succeeded"
fi

ok "All done! Full log in $LOG"
echo "Open a new terminal or run 'exec \$SHELL' to start using Anaconda."
