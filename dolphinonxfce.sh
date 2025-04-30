#!/usr/bin/env bash
set -euo pipefail

echo "Updating package lists…"
sudo apt update

echo "Installing Dolphin and all key plugins (no KDE desktop)..."
sudo apt install -y --no-install-recommends \
    dolphin \
    dolphin-plugins \
    kio-extras \
    ffmpegthumbs \
    kdegraphics-thumbnailers \
    kio-audiocd \
    kio-mtp \
    kio-gdrive \
    kimageformats \
    exfat-fuse \
    exfat-utils \
    gstreamer1.0-plugins-base \
    gstreamer1.0-plugins-good \
    gstreamer1.0-plugins-bad \
    gstreamer1.0-plugins-ugly \
    gstreamer1.0-libav \
    qt5-gtk-platformtheme \
    open-vm-tools-desktop \
    fuse3

echo "Integrating into XFCE menu…"
mkdir -p ~/.local/share/applications
cp /usr/share/applications/org.kde.dolphin.desktop ~/.local/share/applications/
sed -i 's/^OnlyShowIn=.*/OnlyShowIn=XFCE;KDE;/' ~/.local/share/applications/org.kde.dolphin.desktop

echo "Setting Dolphin as the default file manager in XFCE…"
xfconf-query -c xfce4-mime-settings -p /default/filemanager -s dolphin || true

echo "Restarting XFCE panel to pick up menu changes…"
xfce4-panel --restart &>/dev/null || true

echo "✔ Dolphin installation and integration complete!"
