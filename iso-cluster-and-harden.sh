#!/bin/bash

# Create the post-installation script
cat > /usr/local/bin/px-post-install.sh << 'EOL'
#!/bin/bash
#
# Project LONE NOMAD - Post-Installation Setup Script
# Configures SSH keys, security settings, and system optimization

# Configure logging
LOG_FILE="/var/log/px-post-install.log"
exec > >(tee -a "$LOG_FILE") 2>&1
echo "===== PX Post-Install Script Started: $(date) ====="

# Function to check success of commands
check_status() {
  if [ $? -eq 0 ]; then
    echo "[SUCCESS] $1"
  else
    echo "[ERROR] $1 failed!"
    return 1
  fi
}

# Function to generate SSH key
generate_ssh_key() {
  local SSH_DIR="$1"
  local KEY_TYPE="$2"
  local KEY_BITS="$3"
  local KEY_FILE="$4"
  local KEY_COMMENT="$5"

  if [ -f "${SSH_DIR}/${KEY_FILE}" ]; then
    echo "SSH key ${SSH_DIR}/${KEY_FILE} already exists. Skipping generation."
    return 0
  fi

  echo "Generating new SSH ${KEY_TYPE} key..."
  mkdir -p "$SSH_DIR"
  chmod 700 "$SSH_DIR"
  
  ssh-keygen -t "$KEY_TYPE" -b "$KEY_BITS" -f "${SSH_DIR}/${KEY_FILE}" -N "" -C "$KEY_COMMENT"
  check_status "SSH key generation"
  
  # Secure permissions
  chmod 600 ${SSH_DIR}/${KEY_FILE}
  chmod 644 ${SSH_DIR}/${KEY_FILE}.pub
}

# 1. Generate SSH Keys
echo "=== Setting up SSH keys ==="
USER_HOME=$(eval echo ~${SUDO_USER:-$USER})
SSH_DIR="${USER_HOME}/.ssh"

# Create main ED25519 key
generate_ssh_key "$SSH_DIR" "ed25519" "256" "id_ed25519" "lone-nomad-$(hostname)-$(date +%Y%m%d)"

# Create RSA key as backup for older systems
generate_ssh_key "$SSH_DIR" "rsa" "4096" "id_rsa" "lone-nomad-legacy-$(hostname)-$(date +%Y%m%d)"

# Update SSH config
if [ ! -f "${SSH_DIR}/config" ]; then
  cat > "${SSH_DIR}/config" << 'EOF'
# Project LONE NOMAD - SSH Client Configuration

# Default settings for all hosts
Host *
    # Security settings
    Protocol 2
    HashKnownHosts yes
    StrictHostKeyChecking ask
    VerifyHostKeyDNS yes
    
    # Connection settings
    ServerAliveInterval 60
    ServerAliveCountMax 3
    ConnectTimeout 10
    
    # Authentication
    IdentitiesOnly yes
    IdentityFile ~/.ssh/id_ed25519
    IdentityFile ~/.ssh/id_rsa

# Proxmox cluster nodes
Host pve*
    User root
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
    LogLevel ERROR
EOF
  
  chmod 600 "${SSH_DIR}/config"
  check_status "SSH client configuration"
fi

# Create authorized_keys if it doesn't exist
touch "${SSH_DIR}/authorized_keys"
chmod 600 "${SSH_DIR}/authorized_keys"

# Check if our key is in authorized_keys, add if not
if ! grep -q "$(cat ${SSH_DIR}/id_ed25519.pub)" "${SSH_DIR}/authorized_keys"; then
  cat "${SSH_DIR}/id_ed25519.pub" >> "${SSH_DIR}/authorized_keys"
  check_status "Adding key to authorized_keys"
fi

# 2. Configure SSH server for security
echo "=== Configuring SSH server ==="
SSHD_CONFIG="/etc/ssh/sshd_config"

# Backup original config if this is the first run
if [ ! -f "${SSHD_CONFIG}.original" ]; then
  cp "${SSHD_CONFIG}" "${SSHD_CONFIG}.original"
  check_status "Backup of original SSH config"
fi

# Create hardened SSH config
cat > "${SSHD_CONFIG}" << 'EOF'
# Project LONE NOMAD - Hardened SSH Server Configuration

# Basic settings
Port 22
Protocol 2
AddressFamily inet

# Authentication
PermitRootLogin prohibit-password
PubkeyAuthentication yes
PasswordAuthentication no
PermitEmptyPasswords no
ChallengeResponseAuthentication no
UsePAM yes
AuthenticationMethods publickey

# Security
X11Forwarding no
AllowAgentForwarding no
PermitTTY yes
PrintMotd no
PrintLastLog yes
TCPKeepAlive yes
UseDNS no
MaxAuthTries 3
MaxSessions 5
LoginGraceTime 30
ClientAliveInterval 300
ClientAliveCountMax 2

# Features
AllowTcpForwarding yes
Compression delayed
AcceptEnv LANG LC_*
Subsystem sftp /usr/lib/openssh/sftp-server
EOF

check_status "Hardened SSH configuration"

# 3. System optimizations for Proxmox
echo "=== Optimizing system for Proxmox ==="

# Create script to monitor and optimize cluster performance
cat > /usr/local/bin/px-optimize-cluster << 'EOF'
#!/bin/bash
# Proxmox cluster performance optimization script
# Run this periodically to keep systems in optimal condition

echo "Checking for problematic VM/CT snapshots..."
find /var/lib/vz -name "*.lck" -type f

echo "Checking storage space..."
df -h | grep -E '(/var/lib/vz|/var/lib/pve)'

echo "Optimizing local storage pools..."
# ZFS scrub if ZFS is in use
if command -v zpool &> /dev/null; then
  zpool status | grep -v "scan: none"
  zfs list
fi

# LVM check if in use
if command -v pvs &> /dev/null; then
  pvs
  vgs
  lvs
fi

echo "Checking memory usage..."
free -h

echo "Checking for stuck tasks..."
pvesh get /nodes/$(hostname)/tasks --running 1 --limit 5

echo "Optimizing completed!"
EOF

chmod +x /usr/local/bin/px-optimize-cluster
check_status "Cluster optimization script"

# 4. Create edge tunnel script concept
echo "=== Creating edge tunnel script ==="

cat > /usr/local/bin/px-edge-tunnel << 'EOF'
#!/bin/bash
# Edge Tunnel Script - WireGuard + autossh for secure remote access
# Project LONE NOMAD

LOG_FILE="/var/log/px-edge-tunnel.log"

# Network detection function
function detect_network_type() {
  # Check if we're on a public/untrusted network
  local gateway_ip=$(ip route | grep default | awk '{print $3}')
  
  # If no gateway, we're probably not connected
  if [ -z "$gateway_ip" ]; then
    echo "No network detected"
    return 1
  fi
  
  # Check if we're on a known trusted network
  nmcli -g NAME connection show --active | grep -q "Trusted" && {
    echo "Trusted network detected"
    return 0
  }
  
  # Otherwise assume untrusted
  echo "Untrusted network detected"
  return 2
}

# Setup tunnel function
function setup_tunnel() {
  echo "Setting up secure tunnel..."
  
  # Enable WireGuard
  wg-quick up wg0
  
  # Start reverse SSH tunnel
  autossh -M 0 -o "ServerAliveInterval 30" -o "ServerAliveCountMax 3" \
    -N -R 2222:localhost:22 tunnel@home-server
    
  echo "Tunnel established"
}

# Main logic
network_type=$(detect_network_type)
echo "[$(date)] Network detected: $network_type" >> "$LOG_FILE"

case $? in
  0)
    echo "On trusted network, no tunnel needed"
    # Disconnect any existing tunnels
    wg-quick down wg0 2>/dev/null
    ;;
  1)
    echo "No network connection"
    # Wait for network and try again
    ;;
  2)
    echo "On untrusted network, establishing secure tunnel"
    setup_tunnel
    ;;
esac
EOF

chmod +x /usr/local/bin/px-edge-tunnel
check_status "Edge tunnel script"

# 5. Create health report script concept
echo "=== Creating health report script ==="

cat > /usr/local/bin/px-health-report << 'EOF'
#!/bin/bash
# Proxmox Health Reporter
# Generates Markdown report of cluster status

REPORT_FILE="/tmp/proxmox-health-$(date +%Y%m%d-%H%M).md"
EMAIL_TO="admin@example.com"

# Generate report header
cat > $REPORT_FILE << HEADER
# Proxmox Health Report
Generated: $(date)
Cluster: $(pvecm status | grep -oP 'Cluster name: \K.*')

## System Status
HEADER

# Add node status
echo "### Node Status" >> $REPORT_FILE
pvesh get /nodes --output-format json | jq -r '.[] | "- **" + .node + "**: " + .status + " (CPU: " + (.cpu|tostring) + "%, RAM: " + (.mem|tostring) + "%)"' >> $REPORT_FILE

# Add storage status
echo -e "\n## Storage Status" >> $REPORT_FILE
pvesh get /storage --output-format json | jq -r '.[] | "- **" + .storage + "** (" + .type + "): " + (.used|tostring) + " used of " + (.total|tostring)' >> $REPORT_FILE

# Add VM status
echo -e "\n## Virtual Machine Status" >> $REPORT_FILE
pvesh get /cluster/resources --type vm --output-format json | jq -r '.[] | "- **" + .name + "** (ID: " + (.vmid|tostring) + "): " + .status + " on " + .node' >> $REPORT_FILE

# Add warning/error messages
echo -e "\n## Warnings & Errors" >> $REPORT_FILE
if ! grep -q ERROR /var/log/pve-manager/status.log; then
  echo "No errors found in status log" >> $REPORT_FILE
else
  echo '```' >> $REPORT_FILE
  grep ERROR /var/log/pve-manager/status.log | tail -5 >> $REPORT_FILE
  echo '```' >> $REPORT_FILE
fi

# Send report by email if mail command exists
if command -v mail &> /dev/null; then
  mail -s "Proxmox Health Report $(date +%Y-%m-%d)" "$EMAIL_TO" < $REPORT_FILE
fi

# Print report path
echo "Health report generated: $REPORT_FILE"
EOF

chmod +x /usr/local/bin/px-health-report
check_status "Health report script"

# 6. Create launcher menu items
echo "=== Creating application shortcuts ==="

# Create desktop directory if it doesn't exist
mkdir -p /usr/share/applications/lone-nomad

# Create launcher for post-install tools
cat > /usr/share/applications/lone-nomad/px-tools.desktop << EOF
[Desktop Entry]
Name=LONE NOMAD Tools
Comment=Launch Project LONE NOMAD management tools
Exec=konsole
Icon=utilities-terminal
Terminal=false
Type=Application
Categories=System;
EOF

# Add UID to make plasma work on boot
if id -u proxuser &>/dev/null; then
  # Update home directory ownership if user exists
  chown -R proxuser:proxuser /home/proxuser/
fi

# 7. Setup periodic tasks
echo "=== Setting up scheduled tasks ==="

# Create cron job for hourly health check
cat > /etc/cron.d/px-health << EOF
# Run health report hourly
0 * * * * root /usr/local/bin/px-health-report >/dev/null 2>&1
EOF

# Create cron job to check for network changes
cat > /etc/cron.d/px-edge << EOF
# Check network status every 5 minutes
*/5 * * * * root /usr/local/bin/px-edge-tunnel >/dev/null 2>&1
EOF

chmod 644 /etc/cron.d/px-health
chmod 644 /etc/cron.d/px-edge

# Install required packages if not already installed
echo "=== Checking for required packages ==="

# Check for autossh (needed for edge tunnel)
if ! dpkg -l | grep -q autossh; then
  apt-get update
  apt-get install -y autossh jq
  check_status "Installing required packages"
fi

# Final message
echo "===== Post-installation setup complete ====="
echo "SSH keys have been generated:"
echo "  - ED25519 Key: ${SSH_DIR}/id_ed25519"
echo "  - RSA Key: ${SSH_DIR}/id_rsa"
echo ""
echo "Security configuration completed:"
echo "  - SSH server hardened"
echo "  - Maintenance scripts installed"
echo ""
echo "Log file: $LOG_FILE"
echo "===== PX Post-Install Script Completed: $(date) ====="
EOL

# Make the script executable
chmod +x /usr/local/bin/px-post-install.sh

# Create a desktop shortcut for easy access
mkdir -p /etc/skel/Desktop
cat > /etc/skel/Desktop/run-post-install.desktop << EOF
[Desktop Entry]
Type=Application
Name=Run Post-Installation Setup
Comment=Configure SSH keys and security settings
Exec=sudo /usr/local/bin/px-post-install.sh
Icon=system-software-update
Terminal=true
Categories=System;
EOF

chmod +x /etc/skel/Desktop/run-post-install.desktop

echo "Post-installation script created at /usr/local/bin/px-post-install.sh"
echo "Desktop shortcut created for running the script after installation"
