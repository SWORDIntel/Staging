#!/usr/bin/env bash
set -euo pipefail

echo "=== Installing Dolphin + full plugin suite on MX Linux (XFCE) ==="

# 1) Update
apt update

# 2) Install Dolphin core + plugins, no recommends
echo "--> Installing Dolphin and core plugins"
apt install -y --no-install-recommends \
    dolphin                 \ # main file-manager
    dolphin-plugins         \ # archive, terminal, browsing shortcuts
    kio-extras              \ # HTTP/FTP/SMB/WebDAV/recent:// support
    ffmpegthumbs            \ # video & audio thumbnails
    kdegraphics-thumbnailers\ # image (PNG, SVG, PDF) thumbnails
    kio-audiocd             \ # Audio CD browsing
    kio-mtp                 \ # MTP (phones, cameras)
    kio-gdrive              \ # Google Drive support
    kimageformats           \ # extra image formats (HEIF, RAW, etc.)
    exfat-fuse exfat-utils   \ # exFAT filesystem support
    gstreamer1.0-plugins-base   \
    gstreamer1.0-plugins-good   \
    gstreamer1.0-plugins-bad    \
    gstreamer1.0-plugins-ugly   \
    gstreamer1.0-libav           \
    qt5-gtk-platformtheme        # GTK theme for Qt apps

# 3) Ensure VMware desktop integration (clipboard & DnD) if needed
echo "--> Installing open-vm-tools desktop integration"
apt install -y --no-install-recommends open-vm-tools-desktop fuse3

# 4) Add to XFCE menu
echo "--> Integrating Dolphin into XFCE menu"
DESKTOP_SRC=/usr/share/applications/org.kde.dolphin.desktop
DESKTOP_DST=$HOME/.local/share/applications/org.kde.dolphin.desktop
mkdir -p "$(dirname "$DESKTOP_DST")"
cp "$DESKTOP_SRC" "$DESKTOP_DST"
# allow XFCE to show it
sed -i 's/^OnlyShowIn=.*/OnlyShowIn=XFCE;KDE;/' "$DESKTOP_DST"

# 5) (Optional) Set Dolphin as default
if command -v xfconf-query >/dev/null 2>&1; then
  echo "--> Setting Dolphin as default file manager"
  xfconf-query -c xfce4-mime-settings -p /default/filemanager -s "dolphin"
fi

# 6) (Optional) Mount VMware Shared Folders if used
if mountpoint -q /mnt/hgfs; then
  echo "--> /mnt/hgfs already mounted"
elif grep -qs '/mnt/hgfs' /proc/mounts; then
  echo "--> /mnt/hgfs already in fstab"
else
  echo "--> Mounting VMware Shared Folders (if any)"
  mkdir -p /mnt/hgfs
  if command -v vmhgfs-fuse >/dev/null 2>&1; then
    vmhgfs-fuse .host:/ /mnt/hgfs -o allow_other
  fi
fi

# 7) Refresh XFCE panel/menu
echo "--> Refreshing XFCE panel (menu may update automatically)"
xfce4-panel --restart || true

echo "✔ Dolphin + plugins installed without touching your XFCE/KDE DE"
