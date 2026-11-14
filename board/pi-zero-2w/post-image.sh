#!/bin/bash
# Post-image script - generate SD card image

set -e

BOARD_DIR="$(dirname "$0")"
GENIMAGE_CFG="${BOARD_DIR}/genimage.cfg"
GENIMAGE_TMP="${BUILD_DIR}/genimage.tmp"

cp "${BOARD_DIR}/config.txt" "${BINARIES_DIR}/config.txt"
cp "${BOARD_DIR}/cmdline.txt" "${BINARIES_DIR}/cmdline.txt"

# Copy overlays
mkdir -p "${BINARIES_DIR}/overlays"
cp "${BINARIES_DIR}"/*.dtbo "${BINARIES_DIR}/overlays/" 2>/dev/null || true

# Ensure boot script is compiled
if [ -f "${BOARD_DIR}/boot.scr" ]; then
    cp "${BOARD_DIR}/boot.scr" "${BINARIES_DIR}/boot.scr"
fi

genimage \
    --rootpath "${TARGET_DIR}" \
    --tmppath "${GENIMAGE_TMP}" \
    --inputpath "${BINARIES_DIR}" \
    --outputpath "${BINARIES_DIR}" \
    --config "${GENIMAGE_CFG}"

echo "SD card image generated: ${BINARIES_DIR}/sdcard.img"
