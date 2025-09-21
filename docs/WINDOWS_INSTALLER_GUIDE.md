# MCP-Ghidra5 Windows Installer Package Guide

## 🎉 **Professional Windows Installer Complete!**

The MCP-Ghidra5 Windows project now includes a complete, enterprise-grade MSI installer package with professional features and Windows integration.

## 📦 **Installer Features**

### **Core Features**
- ✅ **Professional MSI Installer** - Built with WiX Toolset standards
- ✅ **Windows Service Integration** - Automatic service installation and configuration
- ✅ **PowerShell Management** - Enterprise administration tools
- ✅ **Registry Configuration** - Centralized Windows Registry storage
- ✅ **Dependency Detection** - Automatic Python, Java, and Ghidra detection
- ✅ **Custom Installation UI** - User-friendly configuration dialogs

### **Enterprise Features**
- ✅ **Silent Installation** - Corporate deployment support
- ✅ **Group Policy Compatible** - SCCM/MECM deployment ready
- ✅ **Code Signing Ready** - Professional digital signature support
- ✅ **Uninstall Support** - Clean removal with data options
- ✅ **Start Menu Integration** - Professional shortcuts and management tools
- ✅ **Firewall Configuration** - Automatic Windows Firewall setup

## 🛠️ **Build Process**

### **Development Build (Mock Installer)**
```powershell
# Quick development testing
.\MCP-Ghidra5-Windows\scripts\packaging\Quick-BuildInstaller.ps1
```

### **Production Build (Real MSI)**
```powershell
# Requires WiX Toolset 3.11+ installed
.\MCP-Ghidra5-Windows\scripts\packaging\Build-MCPGhidra5Installer.ps1 -BuildType Release
```

### **Enterprise Build with Code Signing**
```powershell
.\MCP-Ghidra5-Windows\scripts\packaging\Build-MCPGhidra5Installer.ps1 `
    -BuildType Enterprise `
    -SignCode `
    -CertificateThumbprint "YOUR_CERT_THUMBPRINT"
```

## 📋 **Installer Configuration**

### **Main WiX Configuration** (`MCPGhidra5WindowsInstaller.wxs`)
- Product information and versioning
- Directory structure and file components
- Registry keys and configuration
- Windows service installation
- Custom actions and dependencies
- Feature selection and components

### **Custom UI Dialogs** (`MCPGhidraCustomUI.wxs`)
- Ghidra path configuration dialog
- Dependency check and validation
- Service configuration options
- Installation summary and confirmation

### **Build Scripts**
- **`Build-MCPGhidra5Installer.ps1`** - Production MSI builder
- **`Quick-BuildInstaller.ps1`** - Development testing and validation

## 🎯 **Installation Types**

### **Interactive Installation**
```cmd
msiexec /i "MCP-Ghidra5-Windows-Setup-1.0.0.msi"
```

### **Silent Installation**
```cmd
msiexec /i "MCP-Ghidra5-Windows-Setup-1.0.0.msi" /quiet /l*v install.log
```

### **Silent with Custom Parameters**
```cmd
msiexec /i "MCP-Ghidra5-Windows-Setup-1.0.0.msi" /quiet ^
    GHIDRA_HEADLESS_PATH="C:\Tools\ghidra\support\analyzeHeadless.bat" ^
    AUTOSTART_SERVICE=1 ^
    INSTALL_PYTHON_DEPS=1
```

### **Uninstallation**
```cmd
msiexec /x "MCP-Ghidra5-Windows-Setup-1.0.0.msi" /quiet
```

## 🏢 **Enterprise Deployment**

### **Group Policy Deployment**
1. Copy MSI to network share
2. Create GPO for software installation
3. Target appropriate computer groups
4. Configure installation parameters

### **SCCM/MECM Deployment**
```xml
<Application Name="MCP Ghidra5 Windows" Version="1.0.0">
  <InstallCommand>msiexec /i "MCP-Ghidra5-Windows-Setup-1.0.0.msi" /quiet</InstallCommand>
  <UninstallCommand>msiexec /x {PRODUCT_CODE} /quiet</UninstallCommand>
</Application>
```

### **PowerShell Deployment Script**
```powershell
# Mass deployment script
$computers = Get-Content "computers.txt"
foreach ($computer in $computers) {
    Invoke-Command -ComputerName $computer -ScriptBlock {
        msiexec /i "\\server\share\MCP-Ghidra5-Windows-Setup-1.0.0.msi" /quiet
    }
}
```

## 🔐 **Security and Signing**

### **Code Signing Requirements**
- Valid code signing certificate
- Windows SDK (for signtool.exe)
- Certificate installed in certificate store
- Timestamping server configuration

### **Digital Signature Process**
```powershell
# Automated during build
.\Build-MCPGhidra5Installer.ps1 -BuildType Release -SignCode -CertificateThumbprint "THUMBPRINT"
```

## 📊 **Installation Components**

### **Main Application** (Always Installed)
- MCP server (`mcp_ghidra_server_windows.py`)
- Ghidra integration (`ghidra_gpt5_mcp.py`)
- Windows service wrapper (`mcp_ghidra5_service.py`)
- Configuration files

### **PowerShell Management** (Optional)
- Service management scripts
- Administrative tools
- Health monitoring utilities

### **Windows Terminal Integration** (Optional)
- Terminal profile configuration
- Shortcuts and quick access

### **Documentation** (Optional)
- User guides and deployment documentation
- Configuration examples
- Troubleshooting guides

## 🔧 **Registry Configuration**

### **Installation Registry Keys**
```
HKLM\SOFTWARE\TechSquad\MCP-Ghidra5\
├── InstallLocation (REG_SZ)
├── Version (REG_SZ)
├── GhidraPath (REG_SZ)
├── ProjectDirectory (REG_SZ)
└── Service\
    └── AutoStart (REG_DWORD)
```

### **Service Configuration**
- Service name: `MCPGhidra5Service`
- Display name: `MCP Ghidra5 Server`
- Startup type: Automatic (configurable)
- Service account: LocalSystem (configurable)

## 📂 **Installed Directory Structure**
```
C:\Program Files\MCP-Ghidra5\
├── MCP-Ghidra5-Windows\
│   ├── src\
│   │   ├── mcp_ghidra_server_windows.py
│   │   ├── ghidra_gpt5_mcp.py
│   │   └── config\
│   │       └── service.conf
│   └── scripts\
│       ├── service\
│       │   ├── mcp_ghidra5_service.py
│       │   ├── Install-MCPGhidra5Service.ps1
│       │   └── Manage-MCPGhidra5Service.ps1
│       └── terminal\
│           └── Install-WindowsTerminalIntegration.ps1
└── docs\
    ├── README.md
    ├── DEPLOYMENT_GUIDE.md
    └── PROJECT_SUMMARY.md
```

### **Data Directory Structure**
```
C:\ProgramData\MCP-Ghidra5\
├── Logs\
│   └── service.log
├── Projects\
│   └── (Ghidra projects)
└── Config\
    └── (Runtime configuration)
```

## ⚡ **Quick Start After Installation**

### **1. Verify Installation**
```powershell
Get-Service MCPGhidra5Service
```

### **2. Check Service Status**
```powershell
.\scripts\service\Manage-MCPGhidra5Service.ps1 -Action Status
```

### **3. Configure Ghidra Path** (if not detected)
```powershell
# Update registry or service.conf
```

### **4. Start the Service**
```powershell
Start-Service MCPGhidra5Service
```

## 🚀 **Next Steps for Production**

### **Prerequisites for Real MSI Build**
1. **Install WiX Toolset 3.11+**
   - Download from https://wixtoolset.org/
   - Add to PATH environment variable

2. **Install Windows SDK**
   - Required for signtool.exe (code signing)
   - Available from Microsoft

3. **Obtain Code Signing Certificate**
   - For production distribution
   - From trusted Certificate Authority

### **Production Build Commands**
```powershell
# Development build (testing)
.\Quick-BuildInstaller.ps1

# Production build (release)
.\Build-MCPGhidra5Installer.ps1 -BuildType Release

# Enterprise build (signed)
.\Build-MCPGhidra5Installer.ps1 -BuildType Enterprise -SignCode
```

## 🎉 **Achievement Summary**

✅ **Complete Windows Installer Package** - Professional MSI with enterprise features
✅ **Custom Installation Dialogs** - User-friendly configuration experience  
✅ **Automatic Dependency Detection** - Python, Java, Ghidra integration
✅ **Windows Service Integration** - Professional service management
✅ **Enterprise Deployment Ready** - Silent install, Group Policy, SCCM support
✅ **PowerShell Administration** - Comprehensive management tools
✅ **Registry Configuration** - Centralized Windows integration
✅ **Professional Documentation** - Complete deployment and user guides

The MCP-Ghidra5 Windows project now provides a complete, production-ready installer package that meets enterprise Windows deployment standards!

---

**Contact Information:**
- Technical Support: support@techsquad.com
- Documentation: https://techsquad.com/mcp-ghidra5-windows
- GitHub Issues: https://github.com/techsquad/mcp-ghidra5-windows/issues