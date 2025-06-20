#!/bin/bash
# Jetson Orin Bootloader Preparation Script

set -e

echo "=== Jetson AGX Orin Debian Bootloader Preparation ==="

# Variables
JETSON_BSP_VERSION="35.4.1"
L4T_BASE_URL="https://developer.nvidia.com/downloads/embedded/l4t/r35_release_v4.1"
WORK_DIR="/tmp/jetson_bsp"

# Create working directory
mkdir -p $WORK_DIR
cd $WORK_DIR

# Function to extract boot components
extract_boot_components() {
    echo "Extracting boot components from L4T BSP..."
    
    # Download L4T Driver Package
    wget -O driver_package.tar.bz2 "${L4T_BASE_URL}/sources/public_sources.tbz2"
    
    # Extract required files
    tar -xjf driver_package.tar.bz2
    
    # Copy bootloader binaries
    mkdir -p bootloader_backup
    cp -r Linux_for_Tegra/bootloader/* bootloader_backup/
}
# Function to prepare UEFI components
prepare_uefi() {
    echo "Preparing UEFI components..."
    
    # Check if custom UEFI was built
    CUSTOM_UEFI="/tmp/uefi_build/output/uefi_Jetson_RELEASE.bin"
    if [ -f "$CUSTOM_UEFI" ]; then
        echo "Using custom-built UEFI firmware with Debian support"
        cp $CUSTOM_UEFI bootloader_backup/uefi_jetson_debian.bin
    else
        echo "Custom UEFI not found, extracting from L4T..."
        # Extract UEFI firmware from L4T
        if [ -f "bootloader/uefi_jetson.bin" ]; then
            cp bootloader/uefi_jetson.bin bootloader_backup/
        fi
    fi
    
    # Extract UEFI firmware
    cd bootloader_backup
    
    # Create UEFI configuration
    cat > uefi_config.txt << 'EOF'
[Global]
DefaultBootMode=Direct
BootTimeOut=3
BootOrder=0,1,2,3

[Boot0]
DevicePath=PciRoot(0x0)/Pci(0x0,0x0)/NVMe(0x1,00-00-00-00-00-00-00-00)/HD(1,GPT)
Description=Debian ARM Boot
LoaderPath=\EFI\debian\grubaa64.efi

[Boot1]
DevicePath=PciRoot(0x0)/Pci(0x0,0x0)/USB
Description=USB Boot
LoaderPath=\EFI\BOOT\BOOTAA64.EFI
EOF
}

# Function to patch CBoot for Debian
patch_cboot() {
    echo "Patching CBoot for Debian compatibility..."
    
    # Create CBoot patches
    cat > cboot_debian.patch << 'EOF'
--- a/bootloader/cboot_src/boot.c+++ b/bootloader/cboot_src/boot.c
@@ -145,7 +145,7 @@
-    "root=/dev/mmcblk0p1 rw rootwait"
+    "root=/dev/mmcblk0p1 rw rootwait init=/sbin/init"
 
@@ -234,6 +234,8 @@
+    /* Enable Debian-specific boot parameters */
+    cmdline_append("systemd.unified_cgroup_hierarchy=0");
+    cmdline_append("cgroup_enable=memory");
EOF
    
    # Apply patches if CBoot source is available
    if [ -d "cboot_src" ]; then
        patch -p1 < cboot_debian.patch
    fi
}

# Main execution
echo "Starting bootloader preparation..."
extract_boot_components
prepare_uefi
patch_cboot

echo "Bootloader preparation complete!"
echo "Backup created in: $WORK_DIR/bootloader_backup"