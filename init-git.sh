#!/bin/bash
# Initialize Git repository for Jetson Orin Debian project

echo "Initializing Git repository for chainnew/jetson-orin-debian..."

# Initialize git if not already initialized
if [ ! -d .git ]; then
    git init
    echo "✓ Git repository initialized"
else
    echo "✓ Git repository already exists"
fi

# Add all files
git add .
echo "✓ Files added to staging"

# Create initial commit
git commit -m "Initial commit: Debian ARM installation framework for NVIDIA Jetson AGX Orin 64GB

- Complete bootloader modification scripts
- Custom kernel build with Tegra234 support
- Device tree customization for Orin hardware
- Debian rootfs creation with NVIDIA driver integration
- Automated flashing process
- Comprehensive documentation and troubleshooting guides"

echo "✓ Initial commit created"

# Add remote
git remote remove origin 2>/dev/null
git remote add origin https://github.com/chainnew/jetson-orin-debian.git
echo "✓ Remote 'origin' set to https://github.com/chainnew/jetson-orin-debian.git"

echo ""
echo "Repository initialized! Next steps:"
echo "1. Create repository on GitHub: https://github.com/new"
echo "   - Name: jetson-orin-debian"
echo "   - Description: Debian ARM installation on NVIDIA Jetson AGX Orin 64GB"
echo "2. Push to GitHub:"
echo "   git push -u origin main"
echo ""
echo "Or if you prefer SSH:"
echo "   git remote set-url origin git@github.com:chainnew/jetson-orin-debian.git"
