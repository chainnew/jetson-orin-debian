#!/bin/bash
# Flash Debian to Jetson AGX Orin

set -e

echo "=== Flashing Debian to Jetson AGX Orin ==="

# Configuration
FLASH_DIR="/tmp/orin_flash"
L4T_DIR="$FLASH_DIR/Linux_for_Tegra"
BOARD="jetson-agx-orin-devkit"
ROOTFS_TARBALL="/tmp/debian-orin-rootfs.tar.gz"
KERNEL_IMAGE="/tmp/orin_kernel_build/output/Image"
DTB_FILE="/tmp/orin_dtb_custom/tegra234-orin-debian.dtb"
CUSTOM_UEFI="/tmp/uefi_build/output/uefi_Jetson_RELEASE.bin"

# Create flash directory
mkdir -p $FLASH_DIR
cd $FLASH_DIR

# Function to prepare flash environment
prepare_flash_env() {
    echo "Preparing flash environment..."
    
    # Download L4T BSP if not present
    if [ ! -d "$L4T_DIR" ]; then
        echo "Downloading L4T BSP..."
        wget -O l4t_bsp.tar.bz2 \
            "https://developer.nvidia.com/downloads/embedded/l4t/r35_release_v4.1/release/jetson_linux_r35.4.1_aarch64.tbz2"
        tar -xjf l4t_bsp.tar.bz2
    fi
}
# Function to prepare rootfs for flashing
prepare_rootfs_for_flash() {
    echo "Preparing Debian rootfs for flashing..."
    
    # Extract rootfs to L4T directory
    sudo rm -rf $L4T_DIR/rootfs/*
    sudo tar -xzf $ROOTFS_TARBALL -C $L4T_DIR/rootfs/
    
    # Copy custom kernel
    if [ -f "$KERNEL_IMAGE" ]; then
        echo "Installing custom kernel..."
        sudo cp $KERNEL_IMAGE $L4T_DIR/rootfs/boot/Image
    fi
    
    # Copy custom DTB
    if [ -f "$DTB_FILE" ]; then
        echo "Installing custom device tree..."
        sudo cp $DTB_FILE $L4T_DIR/kernel/dtb/
    fi
    
    # Copy custom UEFI if available
    if [ -f "$CUSTOM_UEFI" ]; then
        echo "Installing custom UEFI firmware with Debian support..."
        sudo cp $CUSTOM_UEFI $L4T_DIR/bootloader/uefi_jetson.bin
        echo "Custom UEFI installed - Debian boot support enabled"
    fi
    
    # Apply NVIDIA binaries to rootfs
    cd $L4T_DIR
    sudo ./apply_binaries.sh
}

# Function to configure boot parameters
configure_boot() {
    echo "Configuring boot parameters..."
    
    # Modify flash configuration    cat > $L4T_DIR/bootloader/extlinux.conf << EOF
LABEL primary
    MENU LABEL Debian ARM64 on Jetson Orin
    LINUX /boot/Image
    INITRD /boot/initrd.img
    FDT /boot/dtb/tegra234-orin-debian.dtb
    APPEND root=/dev/mmcblk0p1 rw rootwait console=ttyTCU0,115200n8 fbcon=map:0 net.ifnames=0 systemd.unified_cgroup_hierarchy=0

LABEL recovery
    MENU LABEL Recovery Mode
    LINUX /boot/Image
    INITRD /boot/initrd.img
    FDT /boot/dtb/tegra234-orin-debian.dtb
    APPEND root=/dev/mmcblk0p1 rw rootwait console=ttyTCU0,115200n8 single
EOF
    
    # Update flash configuration XML
    sed -i 's|<rootfs_device>.*</rootfs_device>|<rootfs_device>/dev/mmcblk0p1</rootfs_device>|' \
        $L4T_DIR/bootloader/t186ref/cfg/flash_t234_qspi_sdmmc.xml
}

# Function to create partition layout
create_partition_layout() {
    echo "Creating partition layout for Debian..."
    
    # Create custom partition configuration
    cat > $L4T_DIR/bootloader/t186ref/cfg/debian_partition.xml << 'EOF'
<?xml version="1.0"?><partition_layout version="01.00.0000">
    <device type="sdmmc" instance="0">
        <partition name="APP" type="data">
            <allocation_policy> sequential </allocation_policy>
            <filesystem_type> ext4 </filesystem_type>
            <size> 0 </size> <!-- Use all remaining space -->
            <file_system_attribute> 0 </file_system_attribute>
            <allocation_attribute> 0x8 </allocation_attribute>
            <percent_reserved> 0 </percent_reserved>
            <description> Debian root filesystem </description>
        </partition>
    </device>
</partition_layout>
EOF
}

# Function to flash the device
flash_device() {
    echo "Flashing Debian to Jetson AGX Orin..."
    echo "Please ensure the device is in recovery mode:"
    echo "1. Power off the device"
    echo "2. Connect USB-C cable to host PC"
    echo "3. Press and hold the Force Recovery button"
    echo "4. Press and release the Power button"
    echo "5. Release the Force Recovery button after 2 seconds"
    echo ""
    read -p "Press Enter when device is in recovery mode..."
    
    # Check if device is in recovery mode    if lsusb | grep -q "0955:7023"; then
        echo "Device detected in recovery mode!"
    else
        echo "Error: Device not detected in recovery mode"
        echo "Please check USB connection and retry"
        exit 1
    fi
    
    # Execute flash command
    cd $L4T_DIR
    sudo ./flash.sh -c bootloader/t186ref/cfg/debian_partition.xml \
        -d kernel/dtb/tegra234-orin-debian.dtb \
        -K $KERNEL_IMAGE \
        ${BOARD} mmcblk0p1
}

# Function for post-flash setup
post_flash_setup() {
    echo ""
    echo "=== Flash Complete! ==="
    echo ""
    echo "Post-flash steps:"
    echo "1. The device will reboot automatically"
    echo "2. Default login: jetson / jetson"
    echo "3. SSH is enabled by default"
    echo "4. Run 'sudo apt update && sudo apt upgrade' after first boot"
    echo ""
    echo "Troubleshooting:"
    echo "- If boot fails, connect serial console to debug"
    echo "- Check /var/log/syslog for hardware initialization issues"    echo "- Use 'sudo journalctl -b' to view boot logs"
    echo ""
}

# Main execution
echo "Starting Debian flash process for Jetson AGX Orin..."

# Check for required files
if [ ! -f "$ROOTFS_TARBALL" ]; then
    echo "Error: Rootfs tarball not found at $ROOTFS_TARBALL"
    echo "Please run 04_create_rootfs.sh first"
    exit 1
fi

# Execute flash steps
prepare_flash_env
prepare_rootfs_for_flash
configure_boot
create_partition_layout
flash_device
post_flash_setup

echo "Flash process completed successfully!"