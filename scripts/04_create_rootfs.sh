#!/bin/bash
# Debian ARM64 Rootfs Creation for Jetson AGX Orin

set -e

echo "=== Creating Debian ARM64 Rootfs for Orin ==="

# Configuration
DEBIAN_VERSION="bookworm"
DEBIAN_MIRROR="http://deb.debian.org/debian"
ROOTFS_DIR="/tmp/debian-rootfs"
ROOTFS_TARBALL="/tmp/debian-orin-rootfs.tar.gz"
NVIDIA_L4T_DIR="/tmp/nvidia_l4t_overlay"

# Required packages for Orin
EXTRA_PACKAGES="linux-base,initramfs-tools,u-boot-tools,device-tree-compiler,\
network-manager,openssh-server,sudo,vim,htop,build-essential,git,wget,curl,\
python3,python3-pip,i2c-tools,can-utils,pciutils,usbutils,nvme-cli,\
alsa-utils,v4l-utils,gstreamer1.0-tools,gstreamer1.0-plugins-base,\
gstreamer1.0-plugins-good,libgstreamer1.0-dev,libgstreamer-plugins-base1.0-dev"

# Function to create base rootfs using debootstrap
create_base_rootfs() {
    echo "Creating base Debian rootfs..."
    
    # Install debootstrap if not present
    if ! command -v debootstrap &> /dev/null; then
        sudo apt-get update && sudo apt-get install -y debootstrap qemu-user-static
    fi
    
    # Create rootfs    sudo debootstrap --arch=arm64 --foreign --include=$EXTRA_PACKAGES \
        $DEBIAN_VERSION $ROOTFS_DIR $DEBIAN_MIRROR
    
    # Copy qemu for second stage
    sudo cp /usr/bin/qemu-aarch64-static $ROOTFS_DIR/usr/bin/
    
    # Second stage debootstrap
    sudo chroot $ROOTFS_DIR /debootstrap/debootstrap --second-stage
}

# Function to configure the rootfs
configure_rootfs() {
    echo "Configuring Debian rootfs..."
    
    # Create configuration script
    cat > $ROOTFS_DIR/tmp/configure.sh << 'CHROOT_SCRIPT'
#!/bin/bash
set -e

# Set hostname
echo "jetson-orin-debian" > /etc/hostname

# Configure hosts file
cat > /etc/hosts << EOF
127.0.0.1       localhost
127.0.1.1       jetson-orin-debian

# IPv6
::1     localhost ip6-localhost ip6-loopback
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters
EOF
# Configure networking
cat > /etc/network/interfaces << EOF
auto lo
iface lo inet loopback

auto eth0
iface eth0 inet dhcp
EOF

# Configure apt sources
cat > /etc/apt/sources.list << EOF
deb http://deb.debian.org/debian bookworm main contrib non-free non-free-firmware
deb http://deb.debian.org/debian-security bookworm-security main contrib non-free non-free-firmware
deb http://deb.debian.org/debian bookworm-updates main contrib non-free non-free-firmware
EOF

# Update package database
apt-get update

# Set timezone
ln -sf /usr/share/zoneinfo/UTC /etc/localtime

# Create default user
useradd -m -s /bin/bash -G sudo,video,audio,plugdev jetson
echo "jetson:jetson" | chpasswd

# Enable sudo without password for jetson user
echo "jetson ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/jetson

# Configure SSHsed -i 's/#PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
systemctl enable ssh

# Configure systemd for Orin hardware
mkdir -p /etc/systemd/system

# Create custom startup service for Orin hardware init
cat > /etc/systemd/system/orin-hardware-init.service << 'EOF'
[Unit]
Description=NVIDIA Jetson Orin Hardware Initialization
After=multi-user.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/orin-hw-init.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

systemctl enable orin-hardware-init.service

# Configure fstab
cat > /etc/fstab << EOF
# /etc/fstab: static file system information
/dev/mmcblk0p1  /               ext4    defaults        0       1
/dev/mmcblk0p2  none            swap    sw              0       0
tmpfs           /tmp            tmpfs   defaults        0       0
EOF

CHROOT_SCRIPT
    # Make script executable and run it
    sudo chmod +x $ROOTFS_DIR/tmp/configure.sh
    sudo chroot $ROOTFS_DIR /tmp/configure.sh
}

# Function to integrate NVIDIA drivers and libraries
integrate_nvidia_components() {
    echo "Integrating NVIDIA components..."
    
    # Create NVIDIA integration script
    cat > $ROOTFS_DIR/usr/local/bin/orin-hw-init.sh << 'NVIDIA_SCRIPT'
#!/bin/bash
# NVIDIA Jetson Orin Hardware Initialization

# Load Tegra-specific modules
modprobe nvgpu
modprobe tegra-udrm
modprobe snd_soc_tegra_machine_driver
modprobe tegra_vnet

# Configure GPU device permissions
if [ -e /dev/nvhost-gpu ]; then
    chmod 666 /dev/nvhost-*
    chmod 666 /dev/nvmap
fi

# Initialize BPMP communication
if [ -e /dev/bpmp ]; then
    echo "Initializing BPMP interface..."
    echo 1 > /sys/devices/platform/bpmp/enabled
fi
# Configure thermal management
echo "Setting up thermal zones..."
for zone in /sys/class/thermal/thermal_zone*; do
    if [ -e "$zone/mode" ]; then
        echo "enabled" > "$zone/mode"
    fi
done

# Configure memory controller
echo "Configuring memory controller..."
echo "performance" > /sys/class/devfreq/13e40000.memory-controller/governor

# Set GPU clocks to max (optional, remove for power saving)
if [ -e /sys/devices/gpu.0/devfreq/17000000.gpu/max_freq ]; then
    cat /sys/devices/gpu.0/devfreq/17000000.gpu/max_freq > \
        /sys/devices/gpu.0/devfreq/17000000.gpu/min_freq
fi

echo "Orin hardware initialization complete"
NVIDIA_SCRIPT

    sudo chmod +x $ROOTFS_DIR/usr/local/bin/orin-hw-init.sh
    
    # Copy NVIDIA libraries if available
    if [ -d "$NVIDIA_L4T_DIR" ]; then
        echo "Copying NVIDIA libraries..."
        sudo cp -r $NVIDIA_L4T_DIR/usr/* $ROOTFS_DIR/usr/
        sudo cp -r $NVIDIA_L4T_DIR/lib/* $ROOTFS_DIR/lib/
        sudo cp -r $NVIDIA_L4T_DIR/etc/* $ROOTFS_DIR/etc/    fi
}

# Function to create LD configuration for NVIDIA libraries
create_nvidia_ld_config() {
    echo "Creating NVIDIA library configuration..."
    
    sudo tee $ROOTFS_DIR/etc/ld.so.conf.d/nvidia-tegra.conf << EOF
/usr/lib/aarch64-linux-gnu/tegra
/usr/lib/aarch64-linux-gnu/tegra-egl
/usr/local/cuda/lib64
EOF
    
    # Update library cache in chroot
    sudo chroot $ROOTFS_DIR ldconfig
}

# Function to package the rootfs
package_rootfs() {
    echo "Packaging rootfs..."
    
    # Clean up
    sudo rm -f $ROOTFS_DIR/usr/bin/qemu-aarch64-static
    sudo rm -f $ROOTFS_DIR/tmp/configure.sh
    
    # Create tarball
    sudo tar -czf $ROOTFS_TARBALL -C $ROOTFS_DIR .
    
    echo "Rootfs tarball created: $ROOTFS_TARBALL"
}

# Main executionecho "Starting Debian rootfs creation..."

# Create rootfs directory
sudo mkdir -p $ROOTFS_DIR

# Execute steps
create_base_rootfs
configure_rootfs
integrate_nvidia_components
create_nvidia_ld_config
package_rootfs

echo "Debian ARM64 rootfs creation complete!"
echo "Rootfs location: $ROOTFS_TARBALL"
echo "Size: $(du -h $ROOTFS_TARBALL | cut -f1)"