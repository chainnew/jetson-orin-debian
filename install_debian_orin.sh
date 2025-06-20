#!/bin/bash
# Master Installation Script for Debian on Jetson AGX Orin
# This script orchestrates the entire installation process

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}  Debian ARM Installation on Jetson AGX Orin${NC}"
echo -e "${BLUE}============================================${NC}"
echo ""

# Function to print colored messages
print_status() {
    echo -e "${GREEN}[*]${NC} $1"
}

print_error() {
    echo -e "${RED}[!]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}
# Function to check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    # Check if running on Linux
    if [[ "$OSTYPE" != "linux-gnu"* ]]; then
        print_error "This script must be run on a Linux host system"
        exit 1
    fi
    
    # Check for required tools
    local tools=("wget" "tar" "git" "make" "gcc" "dtc")
    local missing_tools=()
    
    for tool in "${tools[@]}"; do
        if ! command -v $tool &> /dev/null; then
            missing_tools+=($tool)
        fi
    done
    
    if [ ${#missing_tools[@]} -ne 0 ]; then
        print_error "Missing required tools: ${missing_tools[*]}"
        print_status "Install with: sudo apt-get install ${missing_tools[*]}"
        exit 1
    fi
    
    # Check for sudo privileges
    if ! sudo -n true 2>/dev/null; then
        print_warning "This script requires sudo privileges"
        sudo true
    fi    
    # Check available disk space (need at least 50GB)
    local available_space=$(df -BG . | awk 'NR==2 {print $4}' | sed 's/G//')
    if [ "$available_space" -lt 50 ]; then
        print_error "Insufficient disk space. Need at least 50GB, have ${available_space}GB"
        exit 1
    fi
    
    print_status "All prerequisites satisfied!"
}

# Function to display menu
show_menu() {
    echo ""
    echo "Installation Steps:"
    echo "1) Prepare Bootloader Components"
    echo "2) Build Custom Kernel"
    echo "3) Customize Device Tree"
    echo "4) Create Debian Rootfs"
    echo "5) Flash to Device"
    echo "6) Run All Steps"
    echo "7) Exit"
    echo ""
}

# Function to run individual steps
run_step() {
    local step=$1
    local script=""
    
    case $step in        1)
            script="01_bootloader_prep.sh"
            print_status "Preparing bootloader components..."
            ;;
        2)
            script="02_kernel_build.sh"
            print_status "Building custom kernel (this will take 30-60 minutes)..."
            ;;
        3)
            script="03_device_tree.sh"
            print_status "Customizing device tree..."
            ;;
        4)
            script="04_create_rootfs.sh"
            print_status "Creating Debian rootfs (this will take 20-30 minutes)..."
            ;;
        5)
            script="05_flash_orin.sh"
            print_status "Flashing Debian to device..."
            ;;
        *)
            print_error "Invalid step number"
            return 1
            ;;
    esac
    
    # Make script executable and run it
    chmod +x "$SCRIPT_DIR/scripts/$script"
    if ! "$SCRIPT_DIR/scripts/$script"; then
        print_error "Step $step failed! Check the error messages above."
        return 1
    fi    
    print_status "Step $step completed successfully!"
    return 0
}

# Function to run all steps
run_all_steps() {
    print_status "Running complete installation process..."
    print_warning "This will take 2-3 hours to complete"
    echo ""
    read -p "Continue? (y/N) " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        return
    fi
    
    for step in {1..5}; do
        if ! run_step $step; then
            print_error "Installation failed at step $step"
            exit 1
        fi
        echo ""
    done
    
    print_status "Installation completed successfully!"
}

# Main execution
main() {
    # Check prerequisites first
    check_prerequisites
    
    # Interactive menu loop    while true; do
        show_menu
        read -p "Select an option (1-7): " choice
        
        case $choice in
            1|2|3|4|5)
                run_step $choice
                ;;
            6)
                run_all_steps
                ;;
            7)
                print_status "Exiting..."
                exit 0
                ;;
            *)
                print_error "Invalid option"
                ;;
        esac
        
        echo ""
        read -p "Press Enter to continue..."
    done
}

# Create log directory
mkdir -p "$SCRIPT_DIR/logs"

# Start logging
LOG_FILE="$SCRIPT_DIR/logs/install_$(date +%Y%m%d_%H%M%S).log"
exec > >(tee -a "$LOG_FILE")
exec 2>&1

print_status "Installation log: $LOG_FILE"

# Run main function
main "$@"