#!/bin/bash
set -e
set -x

#Become root
sudo -i

# Ensure we are running as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root"
    exit 1
fi

# Perform the installation inside a transactional update session
transactional-update pkg install -y curl
transactional-update shell <<EOF
    curl -sfL https://get.rke2.io | sh -
    systemctl enable --now rke2-server.service

# Persist PATH and KUBECONFIG settings
    RKE2_PATH="/var/lib/rancher/rke2/bin"
    KUBECONFIG_PATH="/etc/rancher/rke2/rke2.yaml"
    PROFILE_FILE="/etc/profile.d/rke2.sh"

    echo "Exporting RKE2 environment variables..."
    cat <<EOL > $PROFILE_FILE
    export PATH=\$PATH:$RKE2_PATH
    export KUBECONFIG=$KUBECONFIG_PATH
    EOL
EOF

echo "RKE2 installation complete. You may need to reboot for changes to fully apply."
