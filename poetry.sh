#!/usr/bin/env bash
# poetry_mx_install.sh – install Poetry 2.1.0 on MX Linux 23 (Bookworm)
# Handles sudo vs user, uses POETRY_HOME to set install dir correctly.
set -euo pipefail

# ──────────────────────────────────────────────────────────────────────────────
# 0. If run under sudo, switch HOME/USER to original caller
# ──────────────────────────────────────────────────────────────────────────────
if [ -n "${SUDO_USER:-}" ] && [ "$SUDO_USER" != "root" ]; then
  export USER="$SUDO_USER"
  export HOME=$(eval echo "~$SUDO_USER")
fi

: "${VERBOSE:=0}"
[ "$VERBOSE" -eq 1 ] && set -x

LOG="/var/log/poetry_install_$(date +%F).log"
exec > >(tee -a "$LOG") 2>&1

info(){ printf '\e[1;34m[INFO]\e[0m  %s\n' "$*"; }
ok(){   printf '\e[1;32m[ OK ]\e[0m  %s\n' "$*"; }
die(){  printf '\e[1;31m[ERR]\e[0m  %s\n' "$*"; exit 1; }
trap 'die "Aborted on line $LINENO"' ERR

# Where Poetry will live
POE_HOME="${XDG_DATA_HOME:-$HOME/.local/share}/pypoetry"
POE_BIN="$HOME/.local/bin"

APT_FLAGS=()
[ "$VERBOSE" -eq 1 ] && APT_FLAGS=( -o Debug::Acquire::http=true -o Debug::pkgProblemResolver=1 )
CURL="curl -fsSL"
[ "$VERBOSE" -eq 1 ] && CURL="$CURL -v"

# ──────────────────────────────────────────────────────────────────────────────
info "1. Ensure prerequisites"
sudo apt update "${APT_FLAGS[@]}"
sudo apt install -y "${APT_FLAGS[@]}" curl python3 python3-venv bash-completion

# ──────────────────────────────────────────────────────────────────────────────
info "2. Run official Poetry installer (2.1.0) into $POE_HOME"
# Use POETRY_HOME env var instead of unsupported --install-dir
export POETRY_HOME="$POE_HOME"
$CURL https://install.python-poetry.org | python3 - --version 2.1.0 --yes
ok "Poetry installed to $POE_HOME"

# ──────────────────────────────────────────────────────────────────────────────
info "3. Symlink 'poetry' into $POE_BIN and ensure in PATH"
mkdir -p "$POE_BIN"
ln -sf "$POE_HOME/bin/poetry" "$POE_BIN/poetry"
if ! grep -qxF 'export PATH="$HOME/.local/bin:$PATH"' "$HOME/.bashrc"; then
  echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"
  info "Added ~/.local/bin to PATH in ~/.bashrc"
fi
ok "Symlink created"

# ──────────────────────────────────────────────────────────────────────────────
info "4. Install shell completions"
# Bash
sudo mkdir -p /etc/bash_completion.d
"$POE_BIN/poetry" completions bash | sudo tee /etc/bash_completion.d/poetry >/dev/null
# Zsh
sudo mkdir -p /usr/share/zsh/vendor-completions
"$POE_BIN/poetry" completions zsh | sudo tee /usr/share/zsh/vendor-completions/_poetry >/dev/null
# Fish
sudo mkdir -p /usr/share/fish/vendor_completions.d
"$POE_BIN/poetry" completions fish | sudo tee /usr/share/fish/vendor_completions.d/poetry.fish >/dev/null
ok "Completions for bash, zsh, fish installed"

# ──────────────────────────────────────────────────────────────────────────────
info "5. Verify installation"
export PATH="$POE_BIN:$PATH"
"$POE_BIN/poetry" --version || die "Poetry not found in PATH!"
ok "Poetry is working: $("$POE_BIN/poetry" --version)"

# ──────────────────────────────────────────────────────────────────────────────
info "6. End-to-end smoke test"
TMPDIR=$(mktemp -d)
pushd "$TMPDIR" >/dev/null
"$POE_BIN/poetry" new demo-smoke >/dev/null
cd demo-smoke
"$POE_BIN/poetry" add pendulum@latest >/dev/null
"$POE_BIN/poetry" run python3 - <<'PYCODE'
import pendulum
print("Pendulum OK:", pendulum.now().isoformat())
PYCODE
popd >/dev/null
rm -rf "$TMPDIR"
ok "Smoke test passed"

ok "All done! Log saved to $LOG"
echo "→ Open a new shell or run: exec \"\$SHELL\""
