# Advanced Configuration for Debian on Jetson AGX Orin

## Kernel Configuration Options

### Performance Tuning
```bash
# CPU Governor Settings
CONFIG_CPU_FREQ_DEFAULT_GOV_PERFORMANCE=y
CONFIG_CPU_FREQ_GOV_PERFORMANCE=y
CONFIG_CPU_FREQ_GOV_POWERSAVE=m
CONFIG_CPU_FREQ_GOV_USERSPACE=m
CONFIG_CPU_FREQ_GOV_ONDEMAND=m
CONFIG_CPU_FREQ_GOV_CONSERVATIVE=m
CONFIG_CPU_FREQ_GOV_SCHEDUTIL=y

# Memory Management
CONFIG_TRANSPARENT_HUGEPAGE=y
CONFIG_TRANSPARENT_HUGEPAGE_ALWAYS=y
CONFIG_ZSWAP=y
CONFIG_Z3FOLD=y
CONFIG_ZSMALLOC=y
```

### GPU/Graphics Configuration
```bash
# DRM and GPU Options
CONFIG_DRM_TEGRA=y
CONFIG_DRM_TEGRA_STAGING=y
CONFIG_TEGRA_HOST1X=y
CONFIG_TEGRA_HOST1X_CONTEXT_BUS=y
CONFIG_TEGRA_GRHOST_NVDLA=y
CONFIG_TEGRA_GRHOST_PVA=y```

### Networking Optimizations
```bash
# Network Performance
CONFIG_NET_RX_BUSY_POLL=y
CONFIG_BQL=y
CONFIG_BPF_JIT=y
CONFIG_NET_FLOW_LIMIT=y
CONFIG_RFS_ACCEL=y
CONFIG_XPS=y
CONFIG_NET_IPIP=m
CONFIG_NET_IPGRE_DEMUX=m
CONFIG_NET_IPGRE=m
CONFIG_NET_IPVTI=m
CONFIG_NET_FOU=m
CONFIG_NET_FOU_IP_TUNNELS=y
CONFIG_INET_ESP_OFFLOAD=m
CONFIG_INET6_ESP_OFFLOAD=m
```

## Boot Optimization

### Systemd Boot Speed Improvements
```bash
# /etc/systemd/system.conf
DefaultTimeoutStartSec=15s
DefaultTimeoutStopSec=15s

# Disable unnecessary services
systemctl disable apt-daily.service
systemctl disable apt-daily-upgrade.service
systemctl disable ModemManager.servicesystemctl mask plymouth-quit-wait.service
```

### Kernel Command Line Optimizations
```bash
# Add to /boot/extlinux/extlinux.conf
quiet splash plymouth.enable=0 
nvme_core.default_ps_max_latency_us=0 
pcie_aspm=off 
processor.max_cstate=1 
```

## CUDA and GPU Compute Setup

### CUDA Installation
```bash
# Download CUDA Toolkit for ARM64
wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2004/sbsa/cuda-keyring_1.0-1_all.deb
dpkg -i cuda-keyring_1.0-1_all.deb
apt-get update
apt-get install cuda-toolkit-11-8

# Environment setup
echo 'export PATH=/usr/local/cuda/bin:$PATH' >> ~/.bashrc
echo 'export LD_LIBRARY_PATH=/usr/local/cuda/lib64:$LD_LIBRARY_PATH' >> ~/.bashrc

# Verify installation
nvcc --version
nvidia-smi
```

### TensorRT Setup
```bash# Install TensorRT dependencies
apt-get install libnvinfer8 libnvinfer-dev libnvinfer-plugin8

# Python bindings
pip3 install pycuda tensorrt
```

## Power Management Profiles

### Maximum Performance Mode
```bash
#!/bin/bash
# /usr/local/bin/jetson-performance-max.sh

# Set CPU governor to performance
for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
    echo performance > $cpu
done

# Set GPU to maximum frequency
cat /sys/devices/gpu.0/devfreq/17000000.gpu/max_freq > \
    /sys/devices/gpu.0/devfreq/17000000.gpu/min_freq

# Set memory controller to performance
echo performance > /sys/class/devfreq/13e40000.memory-controller/governor

# Disable CPU idle states
for cpu in /sys/devices/system/cpu/cpu*/cpuidle/state*/disable; do
    echo 1 > $cpu
done

# Set fan to maximum
echo 255 > /sys/devices/pwm-fan/target_pwm
```
### Power Saving Mode
```bash
#!/bin/bash
# /usr/local/bin/jetson-performance-save.sh

# Set CPU governor to powersave
for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
    echo powersave > $cpu
done

# Limit GPU frequency
echo 510000000 > /sys/devices/gpu.0/devfreq/17000000.gpu/max_freq

# Enable CPU idle states
for cpu in /sys/devices/system/cpu/cpu*/cpuidle/state*/disable; do
    echo 0 > $cpu
done
```

## Overclocking (Use with Caution)

### GPU Overclocking
```bash
# Check current frequencies
cat /sys/devices/gpu.0/devfreq/17000000.gpu/available_frequencies

# Set custom frequency (example: 1.5GHz)
echo 1500000000 > /sys/devices/gpu.0/devfreq/17000000.gpu/max_freq
echo 1500000000 > /sys/devices/gpu.0/devfreq/17000000.gpu/min_freq
```

### Memory Overclocking
```bash# Check available memory frequencies
cat /sys/class/devfreq/13e40000.memory-controller/available_frequencies

# Set to maximum available
cat /sys/class/devfreq/13e40000.memory-controller/max_freq > \
    /sys/class/devfreq/13e40000.memory-controller/min_freq
```

## Monitoring and Benchmarking

### System Monitoring Tools
```bash
# Install monitoring tools
apt-get install htop iotop powertop nvtop

# Jetson-specific monitoring
git clone https://github.com/rbonghi/jetson_stats.git
cd jetson_stats
pip3 install -e .

# Run jtop for comprehensive monitoring
jtop
```

### Benchmarking
```bash
# GPU Benchmark
cd /usr/local/cuda/samples/1_Utilities/bandwidthTest
make
./bandwidthTest

# CPU Benchmark
apt-get install sysbench
sysbench cpu --threads=12 run

# Memory Benchmark
sysbench memory --memory-total-size=10G run
```