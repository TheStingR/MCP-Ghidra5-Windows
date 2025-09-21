# MCP-Ghidra5 Windows v1.0.0

**AI-Powered Reverse Engineering with Ghidra Integration for Windows**

## 🚀 What's New

This is the initial stable release of MCP-Ghidra5 Windows - a professional Windows service that integrates NSA's Ghidra reverse engineering framework with GPT-5 AI capabilities through the Model Context Protocol (MCP).

## ✨ Key Features

- **🏗️ Enterprise Windows Service** - Native Windows background service with proper lifecycle management
- **🔍 Ghidra Integration** - Automated headless analysis of binaries and malware
- **🤖 AI-Powered Analysis** - GPT-5 integration for intelligent reverse engineering assistance  
- **💼 Professional Installation** - MSI installer with dependency management and code signing
- **⚙️ PowerShell Management** - Complete administrative control suite
- **🐳 Docker Testing** - Comprehensive Windows container testing environment
- **📚 Enterprise Documentation** - Complete deployment guides and troubleshooting

## 📦 Download Options

| Package | Description | Use Case |
|---------|-------------|----------|
| **Source Code** | Complete source with build scripts | Development, customization |
| **Installer Components** | MSI build tools and PowerShell scripts | IT deployment |  
| **Documentation** | Complete guides and references | Learning, support |
| **Deploy Ready** | Core files ready for deployment | Quick installation |

## 🔧 System Requirements

- **OS:** Windows 10 Version 1909+ or Windows Server 2019+
- **Architecture:** x64
- **Memory:** 4GB RAM (8GB recommended)
- **Storage:** 2GB free space
- **Dependencies:** Python 3.11+, Java 11+, Ghidra 11.0+, PowerShell 5.1+

## 🚀 Quick Start

1. **Download** the Deploy Ready package
2. **Extract** to your desired location  
3. **Run** installation script:
   ```powershell
   .\scripts\service\Install-MCPGhidra5Service.ps1
   ```
4. **Manage** the service:
   ```powershell
   .\scripts\service\Manage-MCPGhidra5Service.ps1 -Action Start
   ```

## 📋 Installation Methods

### Option 1: MSI Installer (Recommended)
- Professional Windows installer with dependency detection
- Automatic service registration and configuration
- Clean uninstall support

### Option 2: Manual Deployment  
- PowerShell installation scripts
- Flexible configuration options
- Perfect for enterprise deployment

### Option 3: Docker Testing
- Complete Windows container environment
- 40+ automated validation tests
- CI/CD pipeline ready

## 🏗️ For Developers

### Building the MSI Installer
```powershell
# Development build
.\scripts\packaging\Build-MCPGhidra5Installer.ps1 -BuildType Development

# Production build with code signing
.\scripts\packaging\Build-MCPGhidra5Installer.ps1 -BuildType Release -SignCode
```

### Running Tests
```powershell
# Run complete validation suite
.\tests\windows-docker\run-windows-tests.ps1

# Docker container testing
cd tests\windows-docker
docker-compose up --build
```

## 📖 Documentation

- **[Deployment Guide](docs/DEPLOYMENT_GUIDE.md)** - Step-by-step installation
- **[Configuration Reference](docs/CONFIGURATION_REFERENCE.md)** - All settings explained
- **[API Documentation](docs/API_REFERENCE.md)** - MCP protocol integration
- **[Troubleshooting](docs/TROUBLESHOOTING.md)** - Common issues and solutions

## 🔐 Security Features

- **Windows Service** - Runs with appropriate privileges
- **Registry Integration** - Secure configuration storage
- **Event Log** - Security event monitoring
- **Firewall Integration** - Network security configuration
- **Code Signing** - Verified installer authenticity

## 🎯 Production Ready

This release includes:
- ✅ **Complete Windows Service Implementation**
- ✅ **Professional MSI Installer with WiX**  
- ✅ **Comprehensive Testing Environment**
- ✅ **Enterprise Documentation**
- ✅ **PowerShell Management Tools**
- ✅ **Docker Testing Infrastructure**

## 🤝 Contributing

We welcome contributions! Please see our documentation for:
- Development setup guides
- Code style guidelines  
- Testing procedures
- Issue reporting

## 📄 License

This project is licensed under the Apache License 2.0. See LICENSE file for details.

## 🏷️ Release Assets

All release packages are digitally signed and validated. Choose the appropriate package for your use case:

- **Source Code:** For developers and customization
- **Installer Components:** For IT administrators 
- **Documentation:** For learning and support
- **Deploy Ready:** For quick production deployment

---

**Note:** This software integrates with NSA's Ghidra framework. Please ensure compliance with your organization's security policies before deployment.
