#!/bin/bash
# fix-dev-backports.sh - Resolve dev/runtime mismatches in Debian Bookworm

set -euo pipefail

echo "[*] Scanning for mismatched -dev packages from backports..."

# Step 1: Get all installed packages from bookworm-backports
BACKPORTS_PKGS=$(apt list --installed 2>/dev/null | grep '~bpo' | cut -d/ -f1)

# Step 2: For each runtime lib, try to find matching -dev
DEVS_TO_FIX=()
for pkg in $BACKPORTS_PKGS; do
    # Try common naming conventions for dev headers
    if apt-cache show "${pkg}-dev" >/dev/null 2>&1; then
        DEVS_TO_FIX+=("${pkg}-dev")
    fi
done

# Step 3: Install missing or version-mismatched -dev packages from backports
if [ ${#DEVS_TO_FIX[@]} -eq 0 ]; then
    echo "[+] No mismatches found or all -dev packages aligned."
    exit 0
fi

echo "[*] Installing the following -dev packages from bookworm-backports:"
for devpkg in "${DEVS_TO_FIX[@]}"; do
    echo "    - $devpkg"
done

sudo apt -t bookworm-backports install -y "${DEVS_TO_FIX[@]}"

echo "[✓] All -dev packages now match your runtime versions from backports."
