#!/bin/bash
# Jetson Orin Kernel Compilation for Debian

set -e

echo "=== Building Custom Kernel for Jetson AGX Orin Debian ==="

# Configuration
KERNEL_VERSION="5.10.120"
KERNEL_SRC_URL="https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git"
NVIDIA_KERNEL_URL="https://developer.nvidia.com/downloads/embedded/l4t/kernel_src.tbz2"
CROSS_COMPILE="aarch64-linux-gnu-"
JOBS=$(nproc)

# Setup directories
WORK_DIR="/tmp/orin_kernel_build"
OUTPUT_DIR="$WORK_DIR/output"
MODULES_DIR="$OUTPUT_DIR/modules"

mkdir -p $WORK_DIR $OUTPUT_DIR $MODULES_DIR
cd $WORK_DIR

# Function to setup cross-compilation environment
setup_cross_compile() {
    echo "Setting up cross-compilation environment..."
    
    # Install required packages (assuming Debian/Ubuntu host)
    sudo apt-get update
    sudo apt-get install -y \
        gcc-aarch64-linux-gnu \
        g++-aarch64-linux-gnu \
        build-essential \
        bc \
        bison \
        flex \
        libssl-dev        libncurses5-dev \
        git \
        wget \
        rsync \
        kmod \
        cpio
}

# Function to download and prepare kernel sources
prepare_kernel_sources() {
    echo "Downloading kernel sources..."
    
    # Clone mainline kernel
    git clone --depth=1 --branch v$KERNEL_VERSION $KERNEL_SRC_URL linux-$KERNEL_VERSION
    
    # Download NVIDIA kernel sources and patches
    wget -O nvidia_kernel_src.tbz2 $NVIDIA_KERNEL_URL
    tar -xjf nvidia_kernel_src.tbz2
    
    # Apply NVIDIA patches
    cd linux-$KERNEL_VERSION
    for patch in ../nvidia-kernel/kernel-patches/*.patch; do
        echo "Applying patch: $(basename $patch)"
        patch -p1 < "$patch"
    done
}

# Function to configure kernel for Orin
configure_kernel() {
    echo "Configuring kernel for Jetson AGX Orin..."
    
    # Create custom config based on tegra_defconfig    make ARCH=arm64 tegra_defconfig
    
    # Enable Debian-specific options
    cat >> .config << 'EOF'
# Debian Requirements
CONFIG_CGROUPS=y
CONFIG_CGROUP_FREEZER=y
CONFIG_CGROUP_DEVICE=y
CONFIG_CGROUP_CPUACCT=y
CONFIG_MEMCG=y
CONFIG_BLK_CGROUP=y
CONFIG_NAMESPACES=y
CONFIG_NET_NS=y
CONFIG_PID_NS=y
CONFIG_IPC_NS=y
CONFIG_UTS_NS=y
CONFIG_USER_NS=y
CONFIG_DEVPTS_MULTIPLE_INSTANCES=y

# Orin-specific Hardware Support
CONFIG_ARCH_TEGRA_23x_SOC=y
CONFIG_TEGRA_BPMP=y
CONFIG_TEGRA_HOST1X=y
CONFIG_DRM_TEGRA=y
CONFIG_TEGRA_VIC=y
CONFIG_TEGRA_NVDEC=y
CONFIG_TEGRA_NVENC=y
CONFIG_TEGRA_NVJPG=y

# Thermal Management
CONFIG_THERMAL=yCONFIG_TEGRA_SOCTHERM=y
CONFIG_TEGRA_BPMP_THERMAL=y

# Power Management
CONFIG_PM=y
CONFIG_PM_RUNTIME=y
CONFIG_PM_DEBUG=y
CONFIG_TEGRA_PM_DOMAINS=y

# Storage Support
CONFIG_NVME_CORE=y
CONFIG_BLK_DEV_NVME=y
CONFIG_MMC_SDHCI_TEGRA=y
EOF
    
    # Update config
    make ARCH=arm64 olddefconfig
}

# Function to build kernel and modules
build_kernel() {
    echo "Building kernel..."
    
    # Build kernel image
    make -j$JOBS ARCH=arm64 CROSS_COMPILE=$CROSS_COMPILE Image
    
    # Build device tree blobs
    make -j$JOBS ARCH=arm64 CROSS_COMPILE=$CROSS_COMPILE dtbs
    
    # Build and install modules
    make -j$JOBS ARCH=arm64 CROSS_COMPILE=$CROSS_COMPILE modules
    make -j$JOBS ARCH=arm64 CROSS_COMPILE=$CROSS_COMPILE \
        INSTALL_MOD_PATH=$MODULES_DIR modules_install
    # Copy output files
    cp arch/arm64/boot/Image $OUTPUT_DIR/
    cp arch/arm64/boot/dts/nvidia/*.dtb $OUTPUT_DIR/
    
    echo "Kernel build complete!"
    echo "Output files in: $OUTPUT_DIR"
}

# Main execution
setup_cross_compile
prepare_kernel_sources
configure_kernel
build_kernel

echo "Kernel compilation finished successfully!"