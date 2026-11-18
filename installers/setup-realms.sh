#!/bin/bash
# StormRaven OS - Ethereal Void Setup Script
# Configures the Nine Realms VFS and installs the Void Shell.

echo "Initializing the Ethereal Void..."

# 1. Create the VFS Structure (The Nine Realms)
REALMS=("asgard" "vanaheim" "muspelheim" "jotunheim" "svartalfheim" "midgard" "alfheim" "niflheim" "helheim")

echo "Manifesting the Nine Realms..."
for realm in "${REALMS[@]}"; do
    mkdir -p "/void/$realm"
    echo "Realm $realm established."
done

# 2. Install Void Shell
echo "Installing Void Shell..."
cp void-shell.py /usr/local/bin/void-shell
chmod +x /usr/local/bin/void-shell

# Create a symbolic link for easier access
ln -sf /usr/local/bin/void-shell /usr/bin/void-shell

echo "--------------------------------------------------"
echo "StormRaven OS Setup Complete."
echo "The Nine Realms are now mapped to /void/."
echo "You can access the kernel via: void-shell"
echo "--------------------------------------------------"
