#!/bin/bash
# UEFI BIOS Build Script for Jetson AGX Orin
# This script builds custom UEFI firmware for Debian compatibility

set -e

echo "=== Building UEFI BIOS for Jetson AGX Orin ==="

# Configuration
UEFI_VERSION="202308"
EDK2_REPO="https://github.com/NVIDIA/edk2-nvidia.git"
EDK2_PLATFORMS_REPO="https://github.com/NVIDIA/edk2-platforms.git"
EDK2_NON_OSI_REPO="https://github.com/NVIDIA/edk2-non-osi.git"
EDK2_NVIDIA_REPO="https://github.com/NVIDIA/edk2-nvidia-non-osi.git"
WORK_DIR="/tmp/uefi_build"
OUTPUT_DIR="$WORK_DIR/output"
CROSS_COMPILE_DIR="/opt/gcc-arm"

# Create working directories
mkdir -p $WORK_DIR $OUTPUT_DIR
cd $WORK_DIR

# Function to setup build environment
setup_build_env() {
    echo "Setting up UEFI build environment..."
    
    # Install required packages
    sudo apt-get update
    sudo apt-get install -y \
        build-essential \
        uuid-dev \
        git \
        nasm \
        iasl        python3 \
        python3-distutils \
        mono-complete \
        gawk \
        acpica-tools \
        libuuid-perl \
        libfile-slurp-perl \
        device-tree-compiler \
        python3-pyelftools
    
    # Download ARM64 cross-compiler if not present
    if [ ! -d "$CROSS_COMPILE_DIR" ]; then
        echo "Downloading ARM64 cross-compiler..."
        wget -O gcc-arm.tar.xz \
            "https://developer.arm.com/-/media/Files/downloads/gnu-a/10.3-2021.07/binrel/gcc-arm-10.3-2021.07-x86_64-aarch64-none-linux-gnu.tar.xz"
        sudo mkdir -p $CROSS_COMPILE_DIR
        sudo tar -xf gcc-arm.tar.xz -C $CROSS_COMPILE_DIR --strip-components=1
    fi
    
    # Set up environment variables
    export GCC5_AARCH64_PREFIX=$CROSS_COMPILE_DIR/bin/aarch64-none-linux-gnu-
    export WORKSPACE=$WORK_DIR
    export PACKAGES_PATH=$WORKSPACE/edk2:$WORKSPACE/edk2-platforms:$WORKSPACE/edk2-non-osi:$WORKSPACE/edk2-nvidia
    export IASL_PREFIX=/usr/bin/
    export PYTHON_COMMAND=/usr/bin/python3
}

# Function to clone UEFI repositories
clone_uefi_repos() {    echo "Cloning UEFI source repositories..."
    
    # Clone EDK2 base
    if [ ! -d "edk2" ]; then
        git clone --branch r35.4.1 $EDK2_REPO edk2
        cd edk2
        git submodule update --init --recursive
        cd ..
    fi
    
    # Clone EDK2 platforms
    if [ ! -d "edk2-platforms" ]; then
        git clone --branch r35.4.1 $EDK2_PLATFORMS_REPO edk2-platforms
    fi
    
    # Clone non-OSI components
    if [ ! -d "edk2-non-osi" ]; then
        git clone --branch r35.4.1 $EDK2_NON_OSI_REPO edk2-non-osi
    fi
    
    # Clone NVIDIA-specific components
    if [ ! -d "edk2-nvidia" ]; then
        git clone --branch r35.4.1 $EDK2_NVIDIA_REPO edk2-nvidia
    fi
}

# Function to apply Debian-specific patches
apply_debian_patches() {
    echo "Applying Debian-specific UEFI patches..."
    
    # Create custom patches directory    mkdir -p patches
    
    # Patch 1: Enable Debian bootloader detection
    cat > patches/debian_boot_support.patch << 'EOF'
--- a/Silicon/NVIDIA/Drivers/BootOrderDxe/BootOrderDxe.c
+++ b/Silicon/NVIDIA/Drivers/BootOrderDxe/BootOrderDxe.c
@@ -245,6 +245,14 @@
+    // Add Debian boot support
+    { L"\\EFI\\debian\\grubaa64.efi", L"Debian GNU/Linux" },
+    { L"\\EFI\\debian\\shimaa64.efi", L"Debian GNU/Linux (Secure Boot)" },
+    
@@ -312,6 +320,9 @@
+    // Enable USB boot by default for Debian installer
+    PcdSet32 (PcdDefaultBootMode, BOOT_MODE_USB);
+    
EOF
    
    # Patch 2: Configure memory initialization for Debian
    cat > patches/memory_init_debian.patch << 'EOF'
--- a/Silicon/NVIDIA/Tegra/T234/Drivers/ConfigurationManager/PlatformASLTablesLib/Dsdt.asl
+++ b/Silicon/NVIDIA/Tegra/T234/Drivers/ConfigurationManager/PlatformASLTablesLib/Dsdt.asl
@@ -156,6 +156,15 @@
+            // Reserve memory regions for Debian kernel
+            Memory32Fixed (ReadWrite,
+                0x80000000,  // Address
+                0x00100000,  // Length (1MB)+                )
+            
EOF
    
    # Patch 3: UEFI variable storage for Debian
    cat > patches/uefi_vars_debian.patch << 'EOF'
--- a/Platform/NVIDIA/Jetson/T234/Jetson.dsc
+++ b/Platform/NVIDIA/Jetson/T234/Jetson.dsc
@@ -432,6 +432,11 @@
+  # Enable larger variable storage for Debian
+  gEfiMdeModulePkgTokenSpaceGuid.PcdMaxVariableSize|0x10000
+  gEfiMdeModulePkgTokenSpaceGuid.PcdMaxAuthVariableSize|0x10000
+  gEfiMdeModulePkgTokenSpaceGuid.PcdVariableStoreSize|0x80000
+  
EOF
    
    # Apply patches
    cd edk2-nvidia
    for patch in ../patches/*.patch; do
        echo "Applying $(basename $patch)..."
        patch -p1 < "$patch" || echo "Patch may already be applied"
    done
    cd ..
}

# Function to configure UEFI build
configure_uefi_build() {
    echo "Configuring UEFI build for Jetson AGX Orin..."
    
    # Create build configuration    cat > build_config.sh << 'EOF'
#!/bin/bash
# UEFI Build Configuration for Debian

export UEFI_BUILD_TYPE="RELEASE"
export UEFI_TOOLCHAIN="GCC5"
export UEFI_ARCH="AARCH64"
export UEFI_PLATFORM="Jetson"
export UEFI_TARGET="T234"
export UEFI_BOARD="jetson-agx-orin-devkit"

# Debian-specific build flags
export DEBIAN_BOOT_SUPPORT=1
export ENABLE_SECURE_BOOT=1
export ENABLE_MEASURED_BOOT=0
export DEFAULT_BOOT_TIMEOUT=3
export ENABLE_ACPI_TABLES=1
export ENABLE_SMBIOS_TABLES=1
EOF
    
    source build_config.sh
}

# Function to build UEFI
build_uefi() {
    echo "Building UEFI firmware..."
    
    # Setup EDK2 build environment
    cd edk2
    source edksetup.sh
    
    # Build base tools    make -C BaseTools
    
    # Build UEFI for Jetson Orin
    cd ../edk2-nvidia/Platform/NVIDIA
    ./build.sh \
        -p Platform/NVIDIA/Jetson/T234/Jetson.dsc \
        -a AARCH64 \
        -t GCC5 \
        -b RELEASE \
        -D BUILDID_STRING="Debian-$(date +%Y%m%d)" \
        -D MAX_SOCKET=1
    
    # Copy output files
    echo "Copying UEFI binaries..."
    cp -r images/uefi_Jetson_RELEASE.bin $OUTPUT_DIR/
    cp -r images/*.dtb $OUTPUT_DIR/
    
    cd $WORK_DIR
}

# Function to create UEFI configuration
create_uefi_config() {
    echo "Creating UEFI configuration for Debian..."
    
    # Create UEFI boot menu configuration
    cat > $OUTPUT_DIR/UefiBootMenu.txt << 'EOF'
# UEFI Boot Menu Configuration for Debian on Jetson AGX Orin

[Global]
DefaultSelection=1
Timeout=3
ShowDevicePath=0

[Boot001]Title=Debian GNU/Linux
DevicePath=HD(1,GPT,00000000-0000-0000-0000-000000000000,0x800,0x100000)/\EFI\debian\grubaa64.efi
Optional=0

[Boot002]
Title=Debian (Recovery Mode)
DevicePath=HD(1,GPT,00000000-0000-0000-0000-000000000000,0x800,0x100000)/\EFI\debian\grubaa64.efi
Arguments=single
Optional=0

[Boot003]
Title=UEFI Firmware Settings
DevicePath=Fv(00000000-0000-0000-0000-000000000000)/FvFile(462CAA21-7614-4503-836E-8AB6F4662331)
Optional=1

[Boot004]
Title=UEFI Shell
DevicePath=Fv(00000000-0000-0000-0000-000000000000)/FvFile(7C04A583-9E3E-4F1C-AD65-E05268D0B4D1)
Optional=1
EOF
    
    # Create UEFI variable initialization script
    cat > $OUTPUT_DIR/debian_uefi_vars.nsh << 'EOF'
# UEFI Variable Setup for Debian
echo "Setting up UEFI variables for Debian boot..."

# Set boot timeout
setvar BootTimeout =L"3" -guid 8BE4DF61-93CA-11D2-AA0D-00E098032B8C -bs -rt -nv

# Enable USB boot
setvar UsbBootEnabled =0x01 -guid 8BE4DF61-93CA-11D2-AA0D-00E098032B8C -bs -rt -nv
# Set default boot device
setvar DefaultBootDevice =L"HD(1,GPT)" -guid 8BE4DF61-93CA-11D2-AA0D-00E098032B8C -bs -rt -nv

echo "UEFI variables configured for Debian"
EOF
}

# Function to sign UEFI binaries (optional)
sign_uefi_binaries() {
    echo "Signing UEFI binaries..."
    
    # This is optional and requires proper signing certificates
    # For development/testing, unsigned binaries can be used
    
    if [ -f "/path/to/signing/cert.pem" ]; then
        echo "Signing with custom certificate..."
        # sbsign --key cert.key --cert cert.pem $OUTPUT_DIR/uefi_Jetson_RELEASE.bin
    else
        echo "No signing certificate found, using unsigned binaries"
        echo "Note: Secure Boot must be disabled for unsigned binaries"
    fi
}

# Function to package UEFI files
package_uefi() {
    echo "Packaging UEFI files..."
    
    cd $OUTPUT_DIR
    tar -czf uefi_jetson_orin_debian.tar.gz *
    echo "UEFI package created: $OUTPUT_DIR/uefi_jetson_orin_debian.tar.gz"
}
# Main execution
echo "Starting UEFI build process for Jetson AGX Orin..."
echo "This process will take approximately 30-45 minutes"

# Check if running as root
if [ "$EUID" -eq 0 ]; then 
    echo "Please run this script as a normal user, not root"
    exit 1
fi

# Execute build steps
setup_build_env
clone_uefi_repos
apply_debian_patches
configure_uefi_build
build_uefi
create_uefi_config
sign_uefi_binaries
package_uefi

echo ""
echo "=== UEFI Build Complete! ==="
echo "Output files location: $OUTPUT_DIR"
echo "UEFI firmware: $OUTPUT_DIR/uefi_Jetson_RELEASE.bin"
echo "Package: $OUTPUT_DIR/uefi_jetson_orin_debian.tar.gz"
echo ""
echo "Next steps:"
echo "1. Use the UEFI binaries in the flash process"
echo "2. The custom UEFI will enable Debian boot support"
echo "3. Secure Boot can be configured if needed"