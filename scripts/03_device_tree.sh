#!/bin/bash
# Device Tree Customization for Jetson AGX Orin Debian

set -e

echo "=== Customizing Device Tree for Debian on Orin ==="

# Variables
DTS_DIR="/tmp/orin_dts"
DTB_OUTPUT="/tmp/orin_dtb_custom"

mkdir -p $DTS_DIR $DTB_OUTPUT

# Function to decompile existing DTB
decompile_dtb() {
    echo "Decompiling existing DTB files..."
    
    # Assuming we have the original DTBs from JetPack
    local DTB_SOURCE="/boot/tegra234-p3737-0000+p3701-0005.dtb"
    
    if [ -f "$DTB_SOURCE" ]; then
        dtc -I dtb -O dts -o $DTS_DIR/orin-agx.dts $DTB_SOURCE
    else
        echo "Warning: Original DTB not found. Using template..."
        create_template_dts
    fi
}

# Function to create template DTS if original not available
create_template_dts() {
    cat > $DTS_DIR/orin-agx.dts << 'EOF'
/dts-v1/;

#include <dt-bindings/clock/tegra234-clock.h>#include <dt-bindings/gpio/tegra234-gpio.h>
#include <dt-bindings/interrupt-controller/arm-gic.h>
#include <dt-bindings/memory/tegra234-mc.h>
#include <dt-bindings/power/tegra234-powergate.h>
#include <dt-bindings/reset/tegra234-reset.h>

/ {
    compatible = "nvidia,p3737-0000+p3701-0005", "nvidia,tegra234";
    interrupt-parent = <&gic>;
    #address-cells = <2>;
    #size-cells = <2>;

    chosen {
        bootargs = "console=ttyTCU0,115200n8 root=/dev/mmcblk0p1 rw rootwait";
        stdout-path = "serial0:115200n8";
    };

    memory@80000000 {
        device_type = "memory";
        reg = <0x0 0x80000000 0x0 0xf80000000>; /* 64GB */
    };

    /* BPMP (Boot and Power Management Processor) */
    bpmp {
        compatible = "nvidia,tegra234-bpmp";
        mboxes = <&hsp_top0 TEGRA_HSP_MBOX_TYPE_DB>;
        shmem = <&cpu_bpmp_tx &cpu_bpmp_rx>;
        #clock-cells = <1>;
        #reset-cells = <1>;
        #power-domain-cells = <1>;
        /* Thermal zones for Debian */
        thermal-zones {
            cpu-thermal {
                polling-delay = <1000>;
                polling-delay-passive = <100>;
                thermal-sensors = <&soctherm TEGRA234_SOCTHERM_SENSOR_CPU>;
            };
            
            gpu-thermal {
                polling-delay = <1000>;
                polling-delay-passive = <100>;
                thermal-sensors = <&soctherm TEGRA234_SOCTHERM_SENSOR_GPU>;
            };
        };
    };

    /* PCIe Controllers for NVMe support */
    pcie@14100000 {
        compatible = "nvidia,tegra234-pcie";
        device_type = "pci";
        reg = <0x0 0x14100000 0x0 0x20000>;
        reg-names = "apb";
        status = "okay";
        
        nvidia,max-link-speed = <4>; /* Gen4 */
        nvidia,disable-aspm-states = <0xf>;
    };
};
EOF
}
# Function to modify DTS for Debian
modify_dts_for_debian() {
    echo "Modifying device tree for Debian compatibility..."
    
    # Create modifications file
    cat > $DTS_DIR/debian_mods.dtsi << 'EOF'
/* Debian-specific modifications */
&chosen {
    /* Update bootargs for systemd */
    bootargs = "console=ttyTCU0,115200n8 root=/dev/mmcblk0p1 rw rootwait systemd.unified_cgroup_hierarchy=0 cgroup_enable=memory init=/lib/systemd/systemd";
};

/* Enable all CPU cores */
&cpu0 { status = "okay"; };
&cpu1 { status = "okay"; };
&cpu2 { status = "okay"; };
&cpu3 { status = "okay"; };
&cpu4 { status = "okay"; };
&cpu5 { status = "okay"; };
&cpu6 { status = "okay"; };
&cpu7 { status = "okay"; };
&cpu8 { status = "okay"; };
&cpu9 { status = "okay"; };
&cpu10 { status = "okay"; };
&cpu11 { status = "okay"; };

/* USB configuration for Debian */
&xusb_padctl {    status = "okay";
    
    usb2-0 {
        status = "okay";
        mode = "host";
    };
    
    usb3-0 {
        status = "okay";
    };
};

/* Ethernet for network boot support */
&ethernet {
    status = "okay";
    phy-mode = "rgmii-id";
    nvidia,phy-reset-gpio = <&tegra_main_gpio TEGRA234_MAIN_GPIO(G, 5) GPIO_ACTIVE_LOW>;
};
EOF
}

# Function to compile modified DTB
compile_dtb() {
    echo "Compiling modified device tree..."
    
    # Include modifications
    echo '#include "debian_mods.dtsi"' >> $DTS_DIR/orin-agx.dts
    
    # Compile
    dtc -I dts -O dtb -o $DTB_OUTPUT/tegra234-orin-debian.dtb $DTS_DIR/orin-agx.dts
    
    echo "Custom DTB created: $DTB_OUTPUT/tegra234-orin-debian.dtb"}

# Main execution
decompile_dtb
modify_dts_for_debian
compile_dtb

echo "Device tree customization complete!"