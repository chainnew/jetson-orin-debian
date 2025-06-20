# UEFI BIOS Building for Jetson AGX Orin

## Overview

The Jetson AGX Orin uses UEFI (Unified Extensible Firmware Interface) as its primary bootloader. Building a custom UEFI is essential for proper Debian support as it:

1. Enables Debian bootloader detection
2. Configures proper memory initialization
3. Sets up USB boot for Debian installers
4. Manages secure boot policies
5. Provides proper ACPI tables for hardware detection

## Prerequisites

### Build Host Requirements
- Ubuntu 20.04 or 22.04 (x86_64)
- At least 16GB RAM
- 50GB free disk space
- Internet connection for downloading sources

### Required Packages
```bash
sudo apt-get install -y \
    build-essential uuid-dev git nasm iasl \
    python3 python3-distutils mono-complete gawk \
    acpica-tools libuuid-perl libfile-slurp-perl \
    device-tree-compiler python3-pyelftools
```

## UEFI Components

### 1. EDK2 Base
The core UEFI implementation from TianoCore project

### 2. NVIDIA EDK2 Fork
NVIDIA-specific modifications for Tegra platforms
### 3. Platform-Specific Code
- Jetson T234 (Orin) board support
- Memory controller initialization
- PCIe configuration
- Thermal management

### 4. Debian Patches
Custom patches applied for Debian compatibility:
- Boot option detection for GRUB
- Memory region reservations
- USB boot priority
- Variable storage expansion

## Build Process

### Step 1: Environment Setup
```bash
export GCC5_AARCH64_PREFIX=/opt/gcc-arm/bin/aarch64-none-linux-gnu-
export WORKSPACE=/tmp/uefi_build
export PACKAGES_PATH=$WORKSPACE/edk2:$WORKSPACE/edk2-platforms
export PYTHON_COMMAND=/usr/bin/python3
```

### Step 2: Clone Repositories
The script clones:
- `edk2-nvidia` - NVIDIA's EDK2 fork
- `edk2-platforms` - Platform-specific code
- `edk2-non-osi` - Binary firmware components
- `edk2-nvidia-non-osi` - NVIDIA binary components

### Step 3: Apply Patches
Three main patches are applied:1. **debian_boot_support.patch** - Adds Debian bootloader paths
2. **memory_init_debian.patch** - Reserves memory for Debian kernel
3. **uefi_vars_debian.patch** - Expands variable storage

### Step 4: Build UEFI
```bash
cd edk2-nvidia/Platform/NVIDIA
./build.sh \
    -p Platform/NVIDIA/Jetson/T234/Jetson.dsc \
    -a AARCH64 \
    -t GCC5 \
    -b RELEASE \
    -D BUILDID_STRING="Debian-$(date +%Y%m%d)"
```

### Step 5: Output Files
- `uefi_Jetson_RELEASE.bin` - Main UEFI firmware
- `*.dtb` - Device tree binaries
- `UefiBootMenu.txt` - Boot configuration

## Customization Options

### Boot Timeout
Edit `DEFAULT_BOOT_TIMEOUT` in build_config.sh (default: 3 seconds)

### Secure Boot
Set `ENABLE_SECURE_BOOT=1` to enable (requires signing keys)

### Debug Build
Change `-b RELEASE` to `-b DEBUG` for verbose output

### Custom Boot Options
Edit `UefiBootMenu.txt` to add/modify boot entries
## Integration with Flash Process

The custom UEFI is automatically used by the flash script if found at:
`/tmp/uefi_build/output/uefi_Jetson_RELEASE.bin`

If not present, the default NVIDIA UEFI is used (limited Debian support).

## Troubleshooting

### Build Failures
- **BaseTools error**: Run `make -C BaseTools clean` and rebuild
- **Missing dependencies**: Check all packages from prerequisites
- **Out of memory**: Build with `-n 4` to limit parallel jobs

### Boot Issues
- **No Debian option**: UEFI patches may not be applied correctly
- **Boot loops**: Check serial console for UEFI errors
- **USB not detected**: Verify USB controller initialization in DTB

### Debug Output
Connect serial console (115200 8N1) to see UEFI boot messages

## Security Considerations

### Secure Boot
- Custom UEFI supports but doesn't enforce Secure Boot
- To enable: Generate signing keys and sign GRUB/kernel
- Debian's `shim` can be used for Microsoft-signed boot chain

### Measured Boot
- Disabled by default (`ENABLE_MEASURED_BOOT=0`)
- Enable only if TPM 2.0 module is present

## Advanced Features

### Network Boot (PXE)
Add to UefiBootMenu.txt:
```
[BootPXE]
Title=Network Boot
DevicePath=MAC(001122334455,0x1)/IPv4(0.0.0.0)
```

### Custom ACPI Tables
Place .asl files in `Silicon/NVIDIA/Tegra/T234/AcpiTables/`

### GPIO Configuration
Edit `GpioInit.c` for custom GPIO initialization

## References
- [NVIDIA L4T UEFI Documentation](https://docs.nvidia.com/jetson/)
- [EDK2 Build Specifications](https://github.com/tianocore/tianocore.github.io/wiki)
- [UEFI Specification](https://uefi.org/specifications)