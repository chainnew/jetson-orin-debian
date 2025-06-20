# Debian ARM Installation on NVIDIA Jetson AGX Orin 64GB

## Project Overview
This project documents the complex process of installing vanilla Debian ARM on the NVIDIA Jetson AGX Orin 64GB, replacing the default JetPack SDK.

## Warning
This process involves low-level system modifications and can potentially brick your device. Ensure you have:
- Backup of all important data
- Recovery mechanism (ability to reflash JetPack if needed)
- Serial console access for debugging

## Architecture Details
- SoC: NVIDIA Tegra234 (Orin)
- CPU: 12-core ARM Cortex-A78AE
- GPU: NVIDIA Ampere architecture with 2048 CUDA cores
- RAM: 64GB LPDDR5
- Storage: 64GB eMMC (internal)

## Challenges
1. Custom bootloader (UEFI/CBoot)
2. Proprietary NVIDIA drivers
3. Device Tree Binary (DTB) requirements
4. Thermal management
5. Power management features

## Installation

See [PROJECT_SUMMARY.md](PROJECT_SUMMARY.md) for detailed installation instructions.

## Repository

This project is maintained at: https://github.com/chainnew/jetson-orin-debian

### Contributing

Contributions are welcome! Please:
1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Disclaimer

This is an unofficial project and is not affiliated with or endorsed by NVIDIA Corporation. Use at your own risk.
