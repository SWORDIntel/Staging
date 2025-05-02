# Create the script directory if it doesn't exist
mkdir -p /usr/local/bin/

# Create the post-installation script
cat > /usr/local/bin/install-custom-tools.sh << 'EOF'
#!/bin/bash

# Post-installation script for Project LONE NOMAD
# Installs Kismet, Snort, and ctop which aren't available in standard repos

LOG_FILE="/var/log/px-post-install.log"

# Setup logging
exec > >(tee -a "$LOG_FILE") 2>&1
echo "===== Starting post-installation script $(date) ====="

# Function to check command success
check_success() {
    if [ $? -eq 0 ]; then
        echo "[SUCCESS] $1"
    else
        echo "[ERROR] $1 failed!"
        echo "See $LOG_FILE for detailed error messages."
        # Continue with script despite errors
    fi
}

# Ensure we have base dependencies
echo "Installing base dependencies..."
apt update
apt install -y build-essential git curl wget libpcap-dev cmake pkg-config \
    zlib1g-dev libnl-3-dev libnl-genl-3-dev libcap-dev libnm-dev libdw-dev \
    libsqlite3-dev libprotobuf-dev libprotobuf-c-dev protobuf-compiler \
    protobuf-c-compiler libsensors4-dev libusb-1.0-0-dev python3-setuptools \
    python3-protobuf python3-requests python3-numpy python3-serial python3-usb \
    python3-dev libpcre3-dev libnet1-dev hwloc libdumbnet-dev bison flex \
    liblzma-dev openssl libssl-dev libhwloc-dev

check_success "Base dependencies installation"

# Create temporary directory
TEMP_DIR=$(mktemp -d)
cd "$TEMP_DIR"
check_success "Created temporary directory $TEMP_DIR"

# Install ctop (container top)
echo "Installing ctop..."
CTOP_VERSION=$(curl -s https://api.github.com/repos/bcicen/ctop/releases/latest | grep -oP '"tag_name": "\K(.*)(?=")')
wget -q "https://github.com/bcicen/ctop/releases/download/${CTOP_VERSION}/ctop-${CTOP_VERSION}-linux-amd64" -O /usr/local/bin/ctop
chmod +x /usr/local/bin/ctop
check_success "ctop installation"

# Verify ctop is working
if /usr/local/bin/ctop -v > /dev/null 2>&1; then
    CTOP_VERSION_INSTALLED=$(/usr/local/bin/ctop -v)
    echo "ctop installed successfully: $CTOP_VERSION_INSTALLED"
else
    echo "[WARNING] ctop installed but verification failed"
fi

# Install Kismet from source
echo "Installing Kismet from source... (this may take a while)"
git clone --depth=1 https://www.kismetwireless.net/git/kismet.git
cd kismet
./configure
make -j$(nproc)
make suidinstall
cd ..
check_success "Kismet installation"

# Verify Kismet installation
if command -v kismet > /dev/null 2>&1; then
    KISMET_VERSION=$(kismet --version | head -n 1)
    echo "Kismet installed successfully: $KISMET_VERSION"
else
    echo "[WARNING] Kismet installed but verification failed"
fi

# Install Snort3 from source
echo "Installing Snort3 from source... (this may take a while)"

# First install DAQ (Data Acquisition library)
echo "Installing DAQ library for Snort3..."
git clone --depth=1 https://github.com/snort3/libdaq.git
cd libdaq
./bootstrap
./configure
make -j$(nproc)
make install
check_success "DAQ library installation"
cd ..

# Now install Snort3
echo "Installing Snort3..."
git clone --depth=1 https://github.com/snort3/snort3.git
cd snort3
./configure_cmake.sh --prefix=/usr/local --enable-tcmalloc
cd build
make -j$(nproc)
make install
ldconfig
cd ../..
check_success "Snort3 installation"

# Verify Snort3 installation
if command -v snort > /dev/null 2>&1; then
    SNORT_VERSION=$(snort -V 2>&1 | head -n 1)
    echo "Snort installed successfully: $SNORT_VERSION"
else
    echo "[WARNING] Snort installed but verification failed"
fi

# Create initial Snort3 configuration
if command -v snort > /dev/null 2>&1; then
    mkdir -p /etc/snort/rules
    mkdir -p /var/log/snort
    
    # Download community rules if possible
    if curl -s "https://www.snort.org/downloads/community/snort3-community-rules.tar.gz" -o /tmp/snort3-community-rules.tar.gz; then
        tar -xzf /tmp/snort3-community-rules.tar.gz -C /etc/snort/
        check_success "Downloaded and extracted Snort community rules"
    else
        echo "[WARNING] Could not download Snort community rules. Manual setup required."
    fi
    
    # Create basic configuration
    cat > /etc/snort/snort.lua << EOF2
---------------------------------------------------------------------------
-- Snort++ configuration
---------------------------------------------------------------------------

-- Home network definition
HOME_NET = [[ 192.168.0.0/16 10.0.0.0/8 172.16.0.0/12 ]]

-- External network definition (everything but HOME_NET)
EXTERNAL_NET = [[ !$HOME_NET ]]

-- Path to rules
dofile('/etc/snort/snort3-rules.lua')
EOF2
    check_success "Created basic Snort configuration"
fi

# Clean up
cd /
rm -rf "$TEMP_DIR"
check_success "Cleanup"

# Create service files for Snort
cat > /etc/systemd/system/snort.service << EOF2
[Unit]
Description=Snort Intrusion Detection System
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/snort -c /etc/snort/snort.lua -i eth0 -l /var/log/snort -D
Restart=on-failure
RestartSec=10s

[Install]
WantedBy=multi-user.target
EOF2

# Create a simple script to update all custom tools
cat > /usr/local/bin/update-custom-tools << EOF2
#!/bin/bash
# Script to update custom-installed tools

LOG_FILE="/var/log/px-tools-update.log"
exec > >(tee -a "\$LOG_FILE") 2>&1
echo "===== Starting tools update $(date) ====="

# Update ctop
echo "Updating ctop..."
CTOP_VERSION=\$(curl -s https://api.github.com/repos/bcicen/ctop/releases/latest | grep -oP '"tag_name": "\K(.*)(?=")')
wget -q "https://github.com/bcicen/ctop/releases/download/\${CTOP_VERSION}/ctop-\${CTOP_VERSION}-linux-amd64" -O /usr/local/bin/ctop
chmod +x /usr/local/bin/ctop

# Update Kismet
echo "Updating Kismet..."
TEMP_DIR=\$(mktemp -d)
cd "\$TEMP_DIR"
git clone --depth=1 https://www.kismetwireless.net/git/kismet.git
cd kismet
./configure
make -j\$(nproc)
make suidinstall

# Update Snort if needed
# This is commented out as Snort updates should be carefully managed
# Uncomment if you want to include auto-updates
# echo "Updating Snort3..."
# cd "\$TEMP_DIR"
# git clone --depth=1 https://github.com/snort3/snort3.git
# cd snort3
# ./configure_cmake.sh --prefix=/usr/local --enable-tcmalloc
# cd build
# make -j\$(nproc)
# make install
# ldconfig

# Clean up
cd /
rm -rf "\$TEMP_DIR"
echo "Update completed on \$(date)"
EOF2

chmod +x /usr/local/bin/update-custom-tools
check_success "Created update script"

echo "===== Post-installation complete! ====="
echo "Installed tools:"
echo "1. ctop - Container monitoring tool"
echo "2. Kismet - Wireless network detector and sniffer"
echo "3. Snort3 - Intrusion detection system"
echo ""
echo "To update these tools in the future, run: update-custom-tools"
echo "For logs, see: $LOG_FILE"
EOF

# Make the script executable
chmod +x /usr/local/bin/install-custom-tools.sh

# Create systemd service for first-boot execution
cat > /etc/systemd/system/custom-tools-install.service << EOF
[Unit]
Description=Install Custom Tools (one-time)
After=network-online.target
Wants=network-online.target
ConditionFileNotExists=/var/lib/custom-tools-installed

[Service]
Type=oneshot
ExecStart=/usr/local/bin/install-custom-tools.sh
ExecStartPost=/bin/touch /var/lib/custom-tools-installed
TimeoutStartSec=0
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

# Enable the service so it runs at first boot
systemctl enable custom-tools-install.service

# Create readme file to inform user about the post-install process
mkdir -p /etc/skel/Desktop
cat > /etc/skel/Desktop/CUSTOM-TOOLS-README.txt << EOF
================================================================
PROJECT LONE NOMAD - CUSTOM TOOLS INSTALLATION
================================================================

Your system is configured to automatically install these tools 
after the first boot:

1. Kismet - Wireless network detector and sniffer
2. Snort3 - Intrusion detection system 
3. ctop - Container monitoring utility

The installation will begin automatically after network connection
is established. This process might take 15-30 minutes depending 
on your system's performance and internet connection.

To check installation progress:
  sudo journalctl -fu custom-tools-install

Installation log is also saved to:
  /var/log/px-post-install.log

If you need to manually trigger installation:
  sudo /usr/local/bin/install-custom-tools.sh

================================================================
EOF

# Create a desktop entry for checking installation status
cat > /etc/skel/Desktop/check-custom-tools.desktop << EOF
[Desktop Entry]
Type=Application
Name=Check Custom Tools Installation
Comment=Check status of custom security tools installation
Exec=konsole -e bash -c 'journalctl -fu custom-tools-install; read -p "Press Enter to close..."'
Icon=utilities-terminal
Terminal=false
Categories=System;
EOF

chmod +x /etc/skel/Desktop/check-custom-tools.desktop

echo "Post-installation script and service have been set up."
echo "These tools will be installed automatically after the first boot."
