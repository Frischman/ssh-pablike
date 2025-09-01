#!/bin/bash

# Usage: ./ssh_init.sh <port> <public_key>
# Example: ./ssh_init.sh 2222 "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI..."

# Check if script is run as root
if [ "$EUID" -ne 0 ]; then
    echo "This script must be run as root"
    exit 1
fi

# Check if required arguments are provided
if [ $# -ne 2 ]; then
    echo "Usage: $0 <port> <public_key>"
    exit 1
fi

PORT=$1
PUBKEY=$2

# Validate port number
if ! [[ "$PORT" =~ ^[0-9]+$ ]] || [ "$PORT" -lt 1 ] || [ "$PORT" -gt 65535 ]; then
    echo "Invalid port number. Must be between 1 and 65535"
    exit 1
fi

# Detect OS and set variables
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
else
    echo "Cannot detect OS. /etc/os-release not found"
    exit 1
fi

# Set SSH service name and package based on OS
case $OS in
    "debian"|"ubuntu")
        SSH_SERVICE="ssh"
        SSH_PACKAGE="openssh-server"
        SSHD_CONFIG="/etc/ssh/sshd_config"
        ;;
    "centos"|"rhel")
        SSH_SERVICE="sshd"
        SSH_PACKAGE="openssh-server"
        SSHD_CONFIG="/etc/ssh/sshd_config"
        ;;
    "alpine")
        SSH_SERVICE="sshd"
        SSH_PACKAGE="openssh"
        SSHD_CONFIG="/etc/ssh/sshd_config"
        ;;
    *)
        echo "Unsupported OS: $OS"
        exit 1
        ;;
esac

# Install SSH server if not installed
if ! command -v sshd &> /dev/null; then
    echo "Installing SSH server..."
    case $OS in
        "debian"|"ubuntu")
            apt-get update && apt-get install -y $SSH_PACKAGE
            ;;
        "centos"|"rhel")
            yum install -y $SSH_PACKAGE
            ;;
        "alpine")
            apk add $SSH_PACKAGE
            ;;
    esac
fi

# Create SSH directory for root
mkdir -p /root/.ssh
chmod 700 /root/.ssh

# Add public key to authorized_keys
echo "$PUBKEY" > /root/.ssh/authorized_keys
chmod 600 /root/.ssh/authorized_keys
chown root:root /root/.ssh/authorized_keys

# Backup existing SSH config
cp $SSHD_CONFIG ${SSHD_CONFIG}.bak

# Configure SSH
cat > $SSHD_CONFIG << EOF
Port $PORT
Protocol 2
PermitRootLogin yes
PubkeyAuthentication yes
AuthorizedKeysFile .ssh/authorized_keys
PasswordAuthentication no
ChallengeResponseAuthentication no
UsePAM no
X11Forwarding no
PermitEmptyPasswords no
Subsystem sftp /usr/lib/ssh/sftp-server
EOF

# Set correct permissions for config file
chmod 644 $SSHD_CONFIG

# Restart SSH service
echo "Restarting SSH service..."
case $OS in
    "debian"|"ubuntu"|"centos"|"rhel")
        systemctl restart $SSH_SERVICE
        systemctl enable $SSH_SERVICE
        ;;
    "alpine")
        rc-service $SSH_SERVICE restart
        rc-update add $SSH_SERVICE
        ;;
esac

# Check if SSH service is running
if systemctl is-active --quiet $SSH_SERVICE 2>/dev/null || rc-service $SSH_SERVICE status 2>/dev/null; then
    echo "SSH server configured successfully on port $PORT"
else
    echo "Failed to start SSH service. Please check logs."
    exit 1
fi

# Print configuration details
echo "SSH Configuration Complete!"
echo "Port: $PORT"
echo "Root public key authentication: Enabled"
echo "Password authentication: Disabled"
