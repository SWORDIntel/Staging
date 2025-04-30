#!/usr/bin/env bash
# anaconda_mx_install.sh – TUI, verbose, with download progress bar
# MX Linux 23 / Debian 12 “bookworm”

set -euo pipefail
set -x  # Always verbose

LOG="/var/log/anaconda_install_$(date +%F).log"
exec > >(tee -a "$LOG") 2>&1

info(){ printf '\e[1;34m[INFO]\e[0m  %s\n' "$*"; }
ok()  { printf '\e[1;32m[ OK ]\e[0m  %s\n' "$*"; }
err() { printf '\e[1;31m[ERR]\e[0m  %s\n' "$*"; exit 1; }

ANACONDA_VER="2024.10-1"
INSTALLER="Anaconda3-${ANACONDA_VER}-Linux-x86_64.sh"
URL="https://repo.anaconda.com/archive/${INSTALLER}"
PREFIX="$HOME/anaconda3"

clear
echo "┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓"
echo "┃    Anaconda Installer for MX 23   ┃"
echo "┣━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┫"
echo "┃ 1) Install Anaconda               ┃"
echo "┃ 2) Smoke-test existing install    ┃"
echo "┃ 0) Exit                           ┃"
echo "┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛"
read -rp "Select an option [0-2]: " choice
case "$choice" in
  1) MODE="install" ;;
  2) MODE="test"    ;;
  0) echo "Goodbye!"; exit 0 ;;
  *) err "Invalid choice" ;;
esac

install_anaconda() {
  info "1. Installing prerequisites"
  apt update
  apt install -y bzip2 libgl1-mesa-glx
  ok "Prerequisites installed"

  info "2. Downloading Anaconda installer"
  # progress bar with curl -#
  curl -# -L "$URL" -o "/tmp/$INSTALLER" \
    || err "Download failed"
  ok "Downloaded /tmp/$INSTALLER"

  info "3. Running silent installer"
  bash "/tmp/$INSTALLER" -b -p "$PREFIX" \
    || err "Installer failed"
  ok "Anaconda installed to $PREFIX"

  info "4. Cleaning up installer"
  rm -f "/tmp/$INSTALLER"
  ok "Installer removed"

  info "5. Initializing conda in shell"
  eval "$("$PREFIX/bin/conda" shell.bash hook)"
  "$PREFIX/bin/conda" init --all >/dev/null
  ok "Conda initialized"

  ok "Installation complete"
}

smoke_test() {
  info "1. Verifying conda CLI"
  "$PREFIX/bin/conda" --version || err "conda not found"
  ok "Found $("$PREFIX/bin/conda" --version)"

  info "2. Creating test env"
  "$PREFIX/bin/conda" create -y -n smoke_py python=3.11 pip
  ok "Environment smoke_py created"

  info "3. Installing pendulum"
  "$PREFIX/bin/conda" run -n smoke_py pip install pendulum
  ok "pendulum installed"

  info "4. Running pendulum script"
  "$PREFIX/bin/conda" run -n smoke_py python - <<'EOF'
import pendulum
print("Smoke-test →", pendulum.now().to_datetime_string())
EOF
  ok "Pendulum ran successfully"

  info "5. Removing test env"
  "$PREFIX/bin/conda" env remove -y -n smoke_py
  ok "Test environment removed"

  ok "Smoke-test passed"
}

case "$MODE" in
  install)
    install_anaconda
    smoke_test
    ;;
  test)
    smoke_test
    ;;
esac

echo
ok "All done! Log: $LOG"
echo "Open a new terminal or run 'exec \$SHELL' to start using conda."
