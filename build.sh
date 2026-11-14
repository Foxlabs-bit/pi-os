#!/bin/bash
# PiOS Build Script
# Builds the complete operating system image for Raspberry Pi Zero 2 W

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILDROOT_VERSION="2024.02"
BUILDROOT_DIR="${SCRIPT_DIR}/buildroot-${BUILDROOT_VERSION}"
OUTPUT_DIR="${SCRIPT_DIR}/output"
BOARD_DIR="${SCRIPT_DIR}/board/pi-zero-2w"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Check dependencies
check_deps() {
    log_info "Checking dependencies..."
    local deps="make gcc g++ python3 bc bison flex libssl-dev wget unzip"
    local missing=""
    for dep in $deps; do
        if ! dpkg -s $dep &>/dev/null 2>/dev/null; then
            missing="$missing $dep"
        fi
    done
    if [ -n "$missing" ]; then
        log_warn "Missing dependencies:$missing"
        log_info "Install with: sudo apt-get install -y$missing"
        exit 1
    fi
}

# Download Buildroot
download_buildroot() {
    if [ -d "$BUILDROOT_DIR" ]; then
        log_info "Buildroot already downloaded"
        return
    fi
    log_info "Downloading Buildroot ${BUILDROOT_VERSION}..."
    cd "$SCRIPT_DIR"
    wget "https://buildroot.org/downloads/buildroot-${BUILDROOT_VERSION}.tar.gz"
    tar -xzf "buildroot-${BUILDROOT_VERSION}.tar.gz"
    rm "buildroot-${BUILDROOT_VERSION}.tar.gz"
}

# Setup Buildroot configuration
setup_config() {
    log_info "Setting up Buildroot configuration..."
    
    # Copy board files
    mkdir -p "${BUILDROOT_DIR}/board/pi-zero-2w"
    cp -r "${BOARD_DIR}"/* "${BUILDROOT_DIR}/board/pi-zero-2w/"
    
    # Copy defconfig
    cp "${SCRIPT_DIR}/buildroot-configs/pi_zero_2w_defconfig" \
       "${BUILDROOT_DIR}/configs/pi_zero_2w_defconfig"
    
    # Apply defconfig
    cd "$BUILDROOT_DIR"
    make pi_zero_2w_defconfig
}

# Build custom apps
build_apps() {
    log_info "Building PiOS applications..."
    cd "${SCRIPT_DIR}/apps"
    
    # Check if cross-compiler exists from buildroot
    local cross="${BUILDROOT_DIR}/output/host/bin/aarch64-buildroot-linux-musl-gcc"
    if [ ! -f "$cross" ]; then
        log_warn "Cross-compiler not found yet. Will need to build apps manually after first buildroot build."
        log_info "For native build on Pi, run: cd apps && make"
        return
    fi
    
    make clean 2>/dev/null || true
    make CC="$cross" PREFIX=/usr/bin
    
    # Copy to overlay
    mkdir -p "${BOARD_DIR}/overlay/usr/bin"
    cp pios-* "${BOARD_DIR}/overlay/usr/bin/"
    chmod +x "${BOARD_DIR}/overlay/usr/bin/"pios-*
    
    # Copy install script
    cp "${SCRIPT_DIR}/scripts/pios-install" "${BOARD_DIR}/overlay/usr/bin/"
    chmod +x "${BOARD_DIR}/overlay/usr/bin/pios-install"
}

# Build OS image
build_os() {
    log_info "Building OS image (this will take 30-60 minutes)..."
    cd "$BUILDROOT_DIR"
    make -j$(nproc)
}

# Copy output
copy_output() {
    log_info "Copying output files..."
    mkdir -p "$OUTPUT_DIR"
    
    if [ -f "${BUILDROOT_DIR}/output/images/sdcard.img" ]; then
        cp "${BUILDROOT_DIR}/output/images/sdcard.img" "${OUTPUT_DIR}/pios-sdcard.img"
        log_info "SD card image: ${OUTPUT_DIR}/pios-sdcard.img"
    fi
    
    if [ -f "${BUILDROOT_DIR}/output/images/rootfs.tar.gz" ]; then
        cp "${BUILDROOT_DIR}/output/images/rootfs.tar.gz" "${OUTPUT_DIR}/pios-rootfs.tar.gz"
    fi
    
    ls -lh "${OUTPUT_DIR}/"
}

# Flash helper
flash_sd() {
    local device="$1"
    if [ -z "$device" ]; then
        log_error "Usage: $0 flash /dev/sdX"
        exit 1
    fi
    
    if [ ! -f "${OUTPUT_DIR}/pios-sdcard.img" ]; then
        log_error "No image found. Build first with: $0 build"
        exit 1
    fi
    
    log_warn "About to flash ${device}. All data will be lost!"
    read -p "Continue? (yes/no): " confirm
    if [ "$confirm" != "yes" ]; then
        log_info "Aborted"
        exit 0
    fi
    
    sudo dd if="${OUTPUT_DIR}/pios-sdcard.img" of="$device" bs=4M status=progress conv=fsync
    sync
    log_info "Flash complete!"
}

# Main
case "${1:-build}" in
    deps)
        check_deps
        ;;
    download)
        download_buildroot
        ;;
    config)
        download_buildroot
        setup_config
        ;;
    apps)
        build_apps
        ;;
    build)
        check_deps
        download_buildroot
        setup_config
        build_apps
        build_os
        copy_output
        log_info "Build complete!"
        ;;
    flash)
        flash_sd "$2"
        ;;
    clean)
        log_info "Cleaning build directory..."
        cd "$BUILDROOT_DIR" && make clean 2>/dev/null || true
        rm -rf "$OUTPUT_DIR"
        ;;
    distclean)
        log_info "Removing buildroot..."
        rm -rf "$BUILDROOT_DIR"
        rm -rf "$OUTPUT_DIR"
        ;;
    *)
        echo "Usage: $0 {deps|download|config|apps|build|flash|clean|distclean}"
        echo ""
        echo "  deps      - Check build dependencies"
        echo "  download  - Download Buildroot sources"
        echo "  config    - Setup Buildroot configuration"
        echo "  apps      - Build PiOS applications only"
        echo "  build     - Full build (default)"
        echo "  flash     - Flash SD card (requires /dev/sdX)"
        echo "  clean     - Clean build artifacts"
        echo "  distclean - Remove everything"
        exit 1
        ;;
esac
