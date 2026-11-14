setenv bootargs "console=tty1 root=/dev/mmcblk0p2 rootwait ro fsck.repair=yes consoleblank=0 quiet loglevel=1 logo.nologo vt.global_cursor_default=0"

fatload mmc 0:1 ${kernel_addr_r} Image
fatload mmc 0:1 ${fdt_addr} bcm2710-rpi-zero-2-w.dtb

fdt addr ${fdt_addr}
fdt resize

# Apply overlays if present
if fatload mmc 0:1 ${ramdisk_addr_r} overlays/vc4-fkms-v3d.dtbo; then
    fdt apply ${ramdisk_addr_r}
fi

booti ${kernel_addr_r} - ${fdt_addr}
