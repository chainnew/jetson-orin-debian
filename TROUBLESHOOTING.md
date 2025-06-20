# Debian on Jetson AGX Orin - Troubleshooting Guide

## Common Issues and Solutions

### 1. Boot Issues

#### Black Screen / No Display Output
- **Cause**: Wrong display configuration or missing GPU drivers
- **Solution**:
  ```bash
  # Connect via serial console (115200 baud)
  # Check kernel logs
  dmesg | grep -E "tegra|gpu|display"
  
  # Verify GPU module loaded
  lsmod | grep nvgpu
  
  # Check display manager status
  systemctl status gdm3
  ```

#### Kernel Panic on Boot
- **Cause**: Incompatible kernel or missing drivers
- **Solution**:
  - Boot with recovery kernel option
  - Check initramfs contains necessary modules:
    ```bash
    lsinitramfs /boot/initrd.img | grep -E "nvme|mmc|tegra"
    ```
  - Rebuild initramfs with required modules:
    ```bash
    echo "nvgpu" >> /etc/initramfs-tools/modules
    echo "tegra-udrm" >> /etc/initramfs-tools/modules
    update-initramfs -u
    ```

### 2. Hardware Detection Issues

#### NVMe SSD Not Detected
- **Cause**: PCIe configuration or power management
- **Solution**:
  ```bash
  # Check PCIe devices
  lspci -vvv | grep -A 20 "Non-Volatile memory"
  
  # Force PCIe rescan
  echo 1 > /sys/bus/pci/rescan
  
  # Check NVMe kernel module
  modprobe nvme_core
  modprobe nvme
  ```

#### USB Devices Not Working
- **Cause**: Missing USB controller initialization
- **Solution**:
  ```bash
  # Check USB controllers
  lsusb -t
  
  # Load XHCI modules
  modprobe xhci_tegra
  modprobe xhci_hcd
  
  # Check device tree USB nodes
  ls /proc/device-tree/xusb*
  ```

### 3. Performance Issues

#### CPU Cores Not All Active- **Cause**: CPU hotplug or power management
- **Solution**:
  ```bash
  # Check CPU status
  cat /sys/devices/system/cpu/online
  
  # Enable all CPUs
  for i in {0..11}; do
    echo 1 > /sys/devices/system/cpu/cpu$i/online
  done
  
  # Set performance governor
  cpupower frequency-set -g performance
  ```

#### Low Memory Bandwidth
- **Solution**:
  ```bash
  # Check memory controller frequency
  cat /sys/class/devfreq/*/cur_freq
  
  # Set to maximum performance
  echo performance > /sys/class/devfreq/13e40000.memory-controller/governor
  ```

### 4. Thermal Issues

#### Overheating / Thermal Throttling
- **Solution**:
  ```bash
  # Monitor temperatures
  watch -n 1 'cat /sys/class/thermal/thermal_zone*/temp'  
  # Check fan status
  cat /sys/devices/pwm-fan/cur_pwm
  
  # Set fan to maximum
  echo 255 > /sys/devices/pwm-fan/target_pwm
  
  # Install and configure fancontrol
  apt-get install lm-sensors fancontrol
  sensors-detect
  pwmconfig
  ```

### 5. GPU/CUDA Issues

#### CUDA Not Available
- **Solution**:
  ```bash
  # Check GPU device
  ls -la /dev/nvhost*
  ls -la /dev/nvmap
  
  # Verify CUDA installation
  /usr/local/cuda/bin/nvcc --version
  
  # Test GPU access
  /usr/local/cuda/samples/bin/aarch64/linux/release/deviceQuery
  ```

#### OpenGL/EGL Errors
- **Solution**:
  ```bash
  # Check EGL libraries  ldconfig -p | grep -E "EGL|GLESv2"
  
  # Set correct library paths
  export LD_LIBRARY_PATH=/usr/lib/aarch64-linux-gnu/tegra:$LD_LIBRARY_PATH
  
  # Test OpenGL
  glxinfo | grep "OpenGL renderer"
  ```

### 6. Network Issues

#### Ethernet Not Working
- **Solution**:
  ```bash
  # Check network interfaces
  ip link show
  
  # Load ethernet driver
  modprobe eqos
  modprobe phy_tegra194_p2u
  
  # Restart networking
  systemctl restart networking
  ```

## Recovery Procedures

### Serial Console Access
```bash
# Connect to Jetson via serial (J12 connector)
# Settings: 115200 8N1
screen /dev/ttyUSB0 115200
# or
minicom -D /dev/ttyUSB0 -b 115200```

### Emergency Boot Options
Add these to kernel command line in extlinux.conf:
- `single` - Boot to single user mode
- `init=/bin/bash` - Boot directly to bash
- `systemd.unit=rescue.target` - Boot to rescue mode
- `rd.break` - Break into initramfs shell

### Reflashing to JetPack
If Debian installation fails completely:
1. Download JetPack SDK Manager
2. Put device in recovery mode
3. Flash original JetPack to restore functionality

## Useful Commands for Debugging

```bash
# System information
tegrastats  # Real-time system stats
jetson_clocks --show  # Clock frequencies

# Hardware status
cat /proc/device-tree/model  # Device model
cat /sys/module/tegra*/version  # Module versions

# Boot diagnostics
dmesg | grep -i error  # Boot errors
journalctl -b -p err  # Systemd boot errors
```

## Getting Help
- NVIDIA Developer Forums: https://forums.developer.nvidia.com/
- Debian ARM Mailing List: debian-arm@lists.debian.org