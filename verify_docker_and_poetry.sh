#!/usr/bin/env bash
# verify_docker_poetry.sh – Post-reboot diagnostic for Docker and Poetry
# Provides a basic TUI menu for selective checks

set -euo pipefail

info() { printf '\e[1;34m[INFO]\e[0m  %s\n' "$*"; }
ok()   { printf '\e[1;32m[ OK ]\e[0m  %s\n' "$*"; }
die()  { printf '\e[1;31m[FAIL]\e[0m  %s\n' "$*"; exit 1; }

check_docker() {
  info "1. Checking Docker socket and hello-world"
  if ! [ -S /var/run/docker.sock ]; then
    die "Docker socket missing – is the daemon running?"
  fi
  if docker run --rm hello-world >/dev/null 2>&1; then
    ok "Docker: daemon is running and container execution works"
  else
    die "Docker is running but failed to execute hello-world"
  fi
}

check_poetry() {
  info "2. Checking Poetry binary in PATH"
  if ! command -v poetry >/dev/null 2>&1; then
    die "Poetry binary not found in PATH – run: exec \$SHELL or log out/in"
  fi

  info "3. Verifying Poetry virtualenv & install"
  TMP=$(mktemp -d)
  cd "$TMP"
  poetry new checktest >/dev/null 2>&1 || die "Poetry failed to create project"
  cd checktest
  poetry add pendulum@latest >/dev/null 2>&1 || die "Failed to add pendulum package"
  poetry run python3 -c 'import pendulum; print(pendulum.now())' >/dev/null 2>&1 || die "Failed to run pendulum inside Poetry virtualenv"
  cd /
  rm -rf "$TMP"
  ok "Poetry: virtualenv and package install OK"
}

# ─────────────────────────────────────────────────────────────────────
# TUI Menu
# ─────────────────────────────────────────────────────────────────────
clear
echo "Docker & Poetry Diagnostic Menu"
echo "────────────────────────────────"
echo "1. Verify Docker"
echo "2. Verify Poetry"
echo "3. Verify Both"
echo "0. Exit"
read -rp $'\nChoose an option [0-3]: ' choice

case "$choice" in
  1) check_docker ;;
  2) check_poetry ;;
  3) check_docker; echo; check_poetry ;;
  0) echo "Exiting."; exit 0 ;;
  *) die "Invalid selection" ;;
esac

echo
ok "Diagnostics complete"
