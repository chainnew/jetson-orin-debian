# Debian ARM Installation on NVIDIA Jetson AGX Orin - Complete Guide

## Project Overview

This project provides a comprehensive, complex approach to installing vanilla Debian ARM on the NVIDIA Jetson AGX Orin 64GB, replacing the default Ubuntu-based JetPack SDK.

## Why This Complex Approach?

The Jetson AGX Orin uses several proprietary NVIDIA components that are tightly integrated with their JetPack SDK:

1. **Custom Bootloader Chain**: UEFI → CBoot → U-Boot
2. **Proprietary Drivers**: GPU, DLA, PVA, and other accelerators
3. **Unique Device Tree**: Hardware-specific configurations
4. **Thermal/Power Management**: Critical for stable operation
5. **Memory Controller**: Requires specific initialization

## Installation Process Flow

```
┌─────────────────────┐
│ 1. Bootloader Prep  │ ← Extract NVIDIA boot components
└──────────┬──────────┘
           │
┌──────────▼──────────┐
│ 2. Kernel Build     │ ← Custom kernel with Tegra support
└──────────┬──────────┘
           │
┌──────────▼──────────┐
│ 3. Device Tree      │ ← Hardware initialization config
└──────────┬──────────┘
           │┌──────────▼──────────┐
│ 4. Rootfs Creation  │ ← Debian base + NVIDIA integration
└──────────┬──────────┘
           │
┌──────────▼──────────┐
│ 5. Flash to Device  │ ← Write everything to Orin
└─────────────────────┘
```

## Quick Start

```bash
# Clone the project
git clone https://github.com/chainnew/jetson-orin-debian
cd jetson-orin-debian

# Make scripts executable
chmod +x install_debian_orin.sh
chmod +x scripts/*.sh

# Run the installer
./install_debian_orin.sh
```

## Project Structure

```
jetson-debian-project/
├── README.md                    # Basic project information
├── PROJECT_SUMMARY.md          # This file
├── TROUBLESHOOTING.md          # Common issues and solutions
├── ADVANCED_CONFIG.md          # Performance tuning options
├── install_debian_orin.sh      # Master installation script
└── scripts/    ├── 01_bootloader_prep.sh   # Bootloader preparation
    ├── 02_kernel_build.sh      # Kernel compilation
    ├── 03_device_tree.sh       # Device tree customization
    ├── 04_create_rootfs.sh     # Debian rootfs creation
    └── 05_flash_orin.sh        # Flash to device
```

## Key Features

- **Full Hardware Support**: All 12 CPU cores, GPU, DLA, PVA
- **Debian Bookworm**: Latest stable Debian release
- **CUDA Support**: Compatible with NVIDIA CUDA toolkit
- **Optimized Performance**: Custom kernel with Tegra optimizations
- **Recovery Options**: Built-in recovery mode and serial console
- **Power Management**: Multiple power profiles (Max/Balanced/Save)

## Requirements

### Host System
- Linux-based OS (Ubuntu 20.04/22.04 recommended)
- 50GB+ free disk space
- 8GB+ RAM
- USB-C cable for flashing

### Software Dependencies
```bash
sudo apt-get install -y \
    build-essential bc kmod cpio flex bison libssl-dev \
    libncurses5-dev git wget rsync device-tree-compiler \
    gcc-aarch64-linux-gnu g++-aarch64-linux-gnu \
    debootstrap qemu-user-static u-boot-tools```

## Important Notes

### What Works
- ✅ All CPU cores (12x Cortex-A78AE)
- ✅ GPU acceleration (2048 CUDA cores)
- ✅ NVMe/SD card storage
- ✅ Ethernet networking
- ✅ USB 3.2 ports
- ✅ DisplayPort/HDMI output
- ✅ Serial console
- ✅ I2C, SPI, GPIO interfaces

### Known Limitations
- ⚠️ Some NVIDIA tools (DeepStream, Isaac) require adaptation
- ⚠️ Power consumption may be higher than JetPack
- ⚠️ First boot takes longer (5-10 minutes)
- ⚠️ Video encode/decode needs additional configuration

### Warnings
- **BACKUP YOUR DATA**: This process will erase the entire eMMC
- **POWER SUPPLY**: Ensure stable power during flashing
- **RECOVERY MODE**: Know how to enter recovery mode before starting
- **SERIAL CONSOLE**: Highly recommended for debugging

## Support

This is an advanced project. For help:
1. Check TROUBLESHOOTING.md first
2. Review boot logs via serial console
3. NVIDIA Developer Forums (for hardware-specific issues)
4. Debian ARM mailing lists (for Debian-specific issues)

## License
This project is provided as-is for educational purposes.