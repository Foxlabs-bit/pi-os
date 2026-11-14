#!/bin/bash
# Post-build script for Pi Zero 2 W

set -e

BOARD_DIR="$(dirname "$0")"
TARGET_DIR="$1"

# Remove unnecessary stuff to save space
rm -rf "${TARGET_DIR}/usr/share/locale"/*
rm -rf "${TARGET_DIR}/usr/share/man"/*
rm -rf "${TARGET_DIR}/usr/share/doc"/*
rm -rf "${TARGET_DIR}/usr/share/info"/*

# Keep only essential terminfo
mkdir -p "${TARGET_DIR}/usr/share/terminfo_backup"
cp -r "${TARGET_DIR}/usr/share/terminfo/l"/linux* "${TARGET_DIR}/usr/share/terminfo_backup/" 2>/dev/null || true
rm -rf "${TARGET_DIR}/usr/share/terminfo"/*
mkdir -p "${TARGET_DIR}/usr/share/terminfo/l"
cp "${TARGET_DIR}/usr/share/terminfo_backup"/* "${TARGET_DIR}/usr/share/terminfo/l/" 2>/dev/null || true
rm -rf "${TARGET_DIR}/usr/share/terminfo_backup"

# Create required dirs
mkdir -p "${TARGET_DIR}/boot/overlays"
mkdir -p "${TARGET_DIR}/data"
mkdir -p "${TARGET_DIR}/apps"
mkdir -p "${TARGET_DIR}/tmp"
mkdir -p "${TARGET_DIR}/var/cache"
mkdir -p "${TARGET_DIR}/var/log"
mkdir -p "${TARGET_DIR}/var/tmp"
mkdir -p "${TARGET_DIR}/run"
mkdir -p "${TARGET_DIR}/home/pi"
mkdir -p "${TARGET_DIR}/home/pi/Downloads"
mkdir -p "${TARGET_DIR}/home/pi/Documents"

# Set permissions
chmod 755 "${TARGET_DIR}/home/pi"
chmod 755 "${TARGET_DIR}/usr/bin/pios-*" 2>/dev/null || true

# Create fstab
mkdir -p "${TARGET_DIR}/etc"
cat > "${TARGET_DIR}/etc/fstab" << 'EOF'
/dev/mmcblk0p1  /boot           vfat    ro,defaults                             0 2
/dev/mmcblk0p2  /               ext4    ro,defaults,noatime                     0 1
tmpfs           /tmp            tmpfs   defaults,nosuid,nodev,size=64M          0 0
tmpfs           /var/log        tmpfs   defaults,nosuid,nodev,size=16M          0 0
tmpfs           /var/tmp        tmpfs   defaults,nosuid,nodev,size=16M          0 0
tmpfs           /run            tmpfs   defaults,nosuid,nodev,size=32M          0 0
tmpfs           /home/pi/.cache tmpfs   defaults,nosuid,nodev,size=32M          0 0
EOF

# Setup wpa_supplicant for WiFi
mkdir -p "${TARGET_DIR}/etc/wpa_supplicant"
cat > "${TARGET_DIR}/etc/wpa_supplicant/wpa_supplicant.conf" << 'EOF'
ctrl_interface=/run/wpa_supplicant
ctrl_interface_group=0
update_config=1

network={
    ssid="YourNetwork"
    psk="YourPassword"
    key_mgmt=WPA-PSK
}
EOF

# Optimize sysctl for 512MB
mkdir -p "${TARGET_DIR}/etc"
cat > "${TARGET_DIR}/etc/sysctl.conf" << 'EOF'
# PiOS - Optimized for 512MB RAM

# VM settings
vm.swappiness=10
vm.vfs_cache_pressure=50
vm.dirty_ratio=10
vm.dirty_background_ratio=5
vm.page-cluster=3

# Kernel
kernel.panic=10
kernel.panic_on_oops=1
kernel.printk=1 4 1 7
kernel.threads-max=1024

# Network
net.core.rmem_max=262144
net.core.wmem_max=262144
net.ipv4.tcp_rmem=4096 87380 262144
net.ipv4.tcp_wmem=4096 16384 262144
net.ipv4.tcp_congestion_control=bbr
net.ipv4.tcp_notsent_lowat=16384

# fs
fs.file-max=8192
fs.nr_open=8192
EOF

echo "Post-build complete."
