#!/bin/bash
# ─────────────────────────────────────────────────────────────
#  LONE NOMAD • Intel/NPU/Wi‑Fi/Audio/Power stack for REDACTED
#  Version: 2025‑05‑03  •  Author: ChatGPT for REDACTED
# ─────────────────────────────────────────────────────────────
set -euo pipefail
log() { printf '\e[1;32m[✓] %s\e[0m\n' "$*"; }
warn(){ printf '\e[1;33m[!] %s\e[0m\n' "$*"; }

# --- Smart Proxmox header pull ---------------------------------------------
apt update && apt upgrade -y
HDR_PKG="pve-headers-$(uname -r)"
if ! apt-cache show "$HDR_PKG" >/dev/null 2>&1; then
    HDR_PKG="pve-headers-$(uname -r | cut -d. -f1,2)"   # e.g. pve-headers-6.8
fi
apt install -y build-essential "$HDR_PKG" \
               git wget curl pciutils hwdata mokutil \
               intel-gpu-tools vulkan-tools vainfo clinfo \
               hwinfo lshw dmidecode i2c-tools
log "System update & essential build chain"
# ------------------------------------------------------------ #
log "GPU / VAAPI / Vulkan / OpenCL stack"
apt install -y intel-media-va-driver-non-free intel-opencl-icd \
               libva-drm2 libva-x11-2 \
               mesa-va-drivers mesa-vulkan-drivers \
               libgl1-mesa-dri libglx-mesa0

# ------------------------------------------------------------ #
log "Wi‑Fi, Bluetooth & Firmware blobs"
apt install -y firmware-linux firmware-linux-free firmware-linux-nonfree \
               firmware-intel-sound firmware-iwlwifi firmware-realtek \
               bluez blueman
echo 'options iwlwifi 11n_disable=1 swcrypto=1' >/etc/modprobe.d/iwlwifi.conf
modprobe -r iwlwifi || true && modprobe iwlwifi

# ------------------------------------------------------------ #
log "Audio stack (Realtek / Intel SOF)"
apt install -y alsa-utils pulseaudio pavucontrol sof-firmware
cat >/etc/modules-load.d/audio.conf <<'EOF'
snd-hda-intel
snd-sof-pci
EOF

# ------------------------------------------------------------ #
log "Intel Meteor‑Lake NPU enablement"
cat >/etc/modprobe.d/intel-npu.conf <<'EOF'
# Intel Meteor Lake NPU Support
options intel_vsec intel_vsec.force_mmio=1
EOF

# ------------------------------------------------------------ #
log "Advanced input & touchpad tweaks"
apt install -y xserver-xorg-input-libinput xserver-xorg-input-synaptics
install -Dm0644 /dev/null /etc/X11/xorg.conf.d/40-libinput.conf
cat >/etc/X11/xorg.conf.d/40-libinput.conf <<'EOF'
Section "InputClass"
    Identifier "libinput touchpad catchall"
    MatchIsTouchpad  "on"
    MatchDevicePath  "/dev/input/event*"
    Driver           "libinput"
    Option           "Tapping"          "on"
    Option           "NaturalScrolling" "true"
    Option           "ScrollMethod"     "twofinger"
EndSection
EOF

# ------------------------------------------------------------ #
log "Thunderbolt security via bolt"
apt install -y bolt
systemctl enable --now bolt.service

# ------------------------------------------------------------ #
log "TLP power‑management tuning"
apt install -y tlp powertop linux-cpupower
cat >/etc/tlp.conf <<'EOF'
CPU_SCALING_GOVERNOR_ON_AC=performance
CPU_SCALING_GOVERNOR_ON_BAT=powersave
PLATFORM_PROFILE_ON_AC=performance
PLATFORM_PROFILE_ON_BAT=balanced
EOF
systemctl enable --now tlp.service

# ------------------------------------------------------------ #
log "Firmware update support"
apt install -y fwupd udisks2
fwupdmgr refresh || true
fwupdmgr get-updates || true

# ------------------------------------------------------------ #
log "Updating initramfs and GRUB"
update-initramfs -u
update-grub

# ------------------------------------------------------------ #
log "Bringing up any downed Ethernet links"
systemctl restart networking || true
for IF in $(ip -o link | awk -F': ' '/enp|eth/{print $2}'); do
    ip link set "$IF" up || true
done

# ------------------------------------------------------------ #
log "POST‑INSTALL VERIFICATION"

echo -e "\n--- GPU ---"
lspci | grep -i vga || warn "GPU not found via lspci"
lshw -C display | grep -E 'product|driver' || true

echo -e "\n--- NPU (8086:7d1d) ---"
lspci | grep -i "8086:7d1d" || warn "NPU PCI device not detected"

echo -e "\n--- Wi‑Fi / Bluetooth ---"
rfkill list || true
hcitool dev || warn "No Bluetooth adapter found"

echo -e "\n--- Audio devices ---"
aplay -l || warn "No ALSA playback devices detected"

echo -e "\n--- Vulkan / VAAPI quick check ---"
vainfo | grep -i 'driver' || warn "vainfo failed (may require X11)"
vulkaninfo 2>/dev/null | grep deviceName || warn "vulkaninfo failed (headless?)"

log "SCRIPT COMPLETE – please reboot and test in KDE/X11 for full GPU & VAAPI."
