<div align="center">
  <img src="mcp-ghidra5.png" alt="MCP-Ghidra5-Windows Logo" width="200"/>
</div>

# MCP-Ghidra5-Windows

[![Python](https://img.shields.io/badge/Python-3.11+-blue.svg)](https://www.python.org/)
[![Platform](https://img.shields.io/badge/Platform-Windows-green.svg)](https://www.microsoft.com/windows)
[![License](https://img.shields.io/badge/License-TechSquad_Inc-yellow.svg)](LICENSE)
[![Status](https://img.shields.io/badge/Status-Production-brightgreen.svg)](https://github.com/TheStingR/MCP-Ghidra5-Windows)
[![Version](https://img.shields.io/badge/Version-1.0.0-orange.svg)](VERSION)
[![MCP](https://img.shields.io/badge/MCP-Compatible-blueviolet.svg)](https://github.com/modelcontextprotocol/protocol)
[![Ghidra](https://img.shields.io/badge/Ghidra-11.0+-red.svg)](https://ghidra-sre.org/)
[![GPT](https://img.shields.io/badge/GPT-5-black.svg)](https://openai.com/gpt-5)

## 🏢 Enterprise Windows Service for GPT-5 Powered Ghidra Reverse Engineering

**MCP-Ghidra5-Windows** is a **professional-grade Windows service** that seamlessly integrates **Ghidra's powerful reverse engineering capabilities** with **GPT-5 AI technology** through the **Model Context Protocol (MCP)**. Designed specifically for **Windows enterprise environments**, this solution transforms binary analysis from manual processes into **automated, intelligent workflows** with **native Windows integration**, **professional MSI installation**, and **enterprise-grade management tools**.

---

## 🚀 Key Features

### 🏗️ Enterprise Windows Service

• **🖥️ Native Windows Service** - Background service with proper lifecycle management  
• **🔧 Professional MSI Installer** - Enterprise deployment with dependency management  
• **⚙️ PowerShell Management** - Complete administrative control suite  
• **📊 Registry Integration** - Secure Windows configuration storage  
• **📝 Event Log Integration** - Native Windows monitoring and alerting  
• **🔐 Windows Security** - UAC, service accounts, and firewall integration  
• **🔄 Auto-Start Support** - Automatic startup with Windows boot  

### 🤖 AI-Powered Analysis Engine

• **🧠 GPT-5 Integration** - Advanced AI-powered reverse engineering assistance  
• **🔍 Intelligent Binary Analysis** - Automated executable examination with AI insights  
• **💡 Context-Aware Decompilation** - Function analysis with natural language explanations  
• **🛡️ Malware Detection** - AI-enhanced behavioral and structural analysis  
• **⚡ Exploit Development** - Automated vulnerability analysis and PoC generation  
• **🎯 Pattern Recognition** - Cross-architecture vulnerability detection  
• **📡 Firmware Analysis** - IoT and embedded systems reverse engineering  

### 🏭 Professional Integration

• **🔗 MCP Protocol Server** - Standards-compliant Model Context Protocol implementation  
• **📋 Multi-Architecture Support** - x86, x64, ARM analysis capabilities  
• **🐳 Docker Testing Environment** - Complete Windows container validation suite  
• **🔑 Secure API Management** - Protected OpenAI API key configuration  
• **📁 Project Management** - Organized analysis workspace with comprehensive logging  
• **⚙️ Configuration Management** - INI-based settings with environment variable support  

---

## 📦 Installation

### Prerequisites

• **Windows 10/11** or **Windows Server 2019/2022**  
• **Administrator Privileges** for service installation  
• **Python 3.11+** with pip package manager  
• **Java 11+** runtime environment  
• **Ghidra 11.0+** (REQUIRED - core functionality depends on this)  
• **OpenAI API Key** for GPT-5 access  

### Option 1: MSI Installer (Recommended)

```powershell
# 1. Download the Installer Components package
# From: https://github.com/TheStingR/MCP-Ghidra5-Windows/releases

# 2. Extract and run the installer builder
cd MCP-Ghidra5-Windows-Installer-Components
.\scripts\packaging\Build-MCPGhidra5Installer.ps1 -BuildType Release

# 3. Run the generated MSI installer
.\build\bin\MCP-Ghidra5-Windows-Setup.msi
# Follow the installation wizard prompts
```

### Option 2: PowerShell Installation

```powershell
# 1. Download the Deploy Ready package
# From: https://github.com/TheStingR/MCP-Ghidra5-Windows/releases

# 2. Extract the package
Expand-Archive MCP-Ghidra5-Windows-Deploy-Ready-v1.0.0.tar.gz -DestinationPath C:\MCP-Ghidra5

# 3. Install the service
cd C:\MCP-Ghidra5\MCP-Ghidra5-Windows-v1.0.0
.\scripts\service\Install-MCPGhidra5Service.ps1

# 4. Start the service
.\scripts\service\Manage-MCPGhidra5Service.ps1 -Action Start
```

### Option 3: Docker Testing Environment

```powershell
# 1. Ensure Docker Desktop with Windows containers
docker version  # Should show Windows containers

# 2. Download source code and navigate to testing
cd tests\windows-docker

# 3. Build and run the testing environment
docker-compose up --build

# 4. Run comprehensive validation tests
.\run-windows-tests.ps1
```

---

## 🛠️ Usage Examples

### Binary Analysis

```python
call_mcp_tool("ghidra_binary_analysis", {
  "binary_path": "C:\\Windows\\System32\\notepad.exe",
  "analysis_depth": "deep"})
```

### Function Analysis

```python
call_mcp_tool("ghidra_function_analysis", {
  "binary_path": "C:\\samples\\malware.exe",
  "function_name": "main",
  "include_decompilation": true})
```

### Malware Analysis

```python
call_mcp_tool("ghidra_malware_analysis", {
  "binary_path": "C:\\samples\\suspicious.exe",
  "analysis_type": "comprehensive"})
```

### Exploit Development

```python
call_mcp_tool("ghidra_exploit_development", {
  "binary_path": "C:\\vulnerable\\app.exe",
  "vulnerability_type": "buffer_overflow"})
```

### Service Management

```powershell
# Start the service
.\scripts\service\Manage-MCPGhidra5Service.ps1 -Action Start

# Check service status
.\scripts\service\Manage-MCPGhidra5Service.ps1 -Action Status

# View service logs
.\scripts\service\Manage-MCPGhidra5Service.ps1 -Action ViewLogs
```

---

## 🎯 Advanced Analysis Tools

| Tool | Description | Windows Integration |
| ---- | ----------- | ------------------- |
| **🔬 Binary Analysis** | Comprehensive executable analysis | Registry + Event Log |
| **🎯 Function Analysis** | Targeted decompilation with AI | PowerShell integration |
| **💥 Exploit Development** | PoC generation with Windows context | UAC + Security analysis |
| **🦠 Malware Analysis** | Windows-specific behavioral analysis | Defender integration |
| **📡 Firmware Analysis** | Embedded systems with Windows tools | Hardware abstraction |
| **🔍 Pattern Search** | Windows vulnerability detection | Security policy analysis |
| **🤖 GPT-5 Queries** | Expert assistance with Windows context | Enterprise compliance |

---

## 🏆 Performance Specifications

• **⚡ Quick Analysis**: 45-90 seconds on Windows  
• **🔍 Deep Analysis**: 180-300 seconds comprehensive  
• **💰 Cost Efficient**: $0.08-1.20 per analysis (Windows optimized)  
• **🎯 Multi-Platform**: Windows 10/11, Server 2019/2022  
• **🔒 Enterprise Secure**: Windows security integration  
• **📊 Resource Optimized**: Efficient Windows service architecture  

---

## 🏭 Enterprise Features

### Windows Service Architecture
• **🖥️ Background Service** - Runs without user login  
• **🔄 Automatic Recovery** - Service restart on failure  
• **📊 Performance Counters** - Windows monitoring integration  
• **🔐 Service Accounts** - Secure execution context  
• **⚙️ Dependency Management** - Proper service dependencies  

### Professional Installation
• **📦 MSI Package** - Enterprise deployment ready  
• **🔧 Dependency Detection** - Auto-installs Python, Java, Ghidra  
• **📝 Registry Configuration** - Proper Windows integration  
• **🗑️ Clean Uninstall** - Complete removal support  
• **🔒 Code Signing** - Verified installer authenticity  

### Management & Monitoring
• **⚙️ PowerShell Tools** - Complete administrative suite  
• **📊 Logging & Monitoring** - Event Log + file logging  
• **🔧 Configuration Management** - INI + registry settings  
• **🛡️ Security Integration** - Firewall + Windows Defender  
• **📈 Health Monitoring** - Automated status reporting  

---

## 📚 Documentation

• **📖 [Deployment Guide](docs/DEPLOYMENT_GUIDE.md)** - Complete Windows installation  
• **🔧 [Configuration Reference](docs/CONFIGURATION_REFERENCE.md)** - All settings explained  
• **🛠️ [Management Guide](docs/MANAGEMENT_GUIDE.md)** - Service administration  
• **🐳 [Docker Testing Guide](tests/windows-docker/README.md)** - Container validation  
• **🔍 [Troubleshooting Guide](docs/TROUBLESHOOTING.md)** - Problem resolution  
• **🏢 [Copyright Information](LICENSE)** - Legal terms and licensing  

---

## 🎯 Target Audience

• **🏢 Enterprise IT Teams** - Windows service deployment and management  
• **🔐 Corporate Security** - Windows environment threat analysis  
• **🏭 System Administrators** - Professional service integration  
• **🛡️ Windows Penetration Testers** - Specialized Windows exploit development  
• **🦠 Windows Malware Analysts** - OS-specific behavioral analysis  
• **🎓 Enterprise Training** - Professional reverse engineering education  

---

## 🔧 System Requirements

| Component | Requirement |
| --------- | ----------- |
| **OS** | Windows 10 Version 1909+ / Windows Server 2019+ |
| **Architecture** | x64 (64-bit) |
| **Python** | 3.11+ with pip |
| **Java** | OpenJDK 11+ or Oracle JRE 11+ |
| **Memory** | 4GB+ RAM (8GB recommended) |
| **Storage** | 2GB+ free space |
| **Network** | Internet access for GPT-5 API calls |
| **Privileges** | Administrator rights for service installation |
| **Dependencies** | **Ghidra 11.0+** (MANDATORY) |

---

## 🐳 Docker Testing Environment

### Windows Container Support
```powershell
# Switch Docker Desktop to Windows containers
& "C:\Program Files\Docker\Docker\DockerCli.exe" -SwitchDaemon

# Verify Windows container support
docker version --format "{{.Server.Os}}"  # Should return "windows"

# Navigate to testing directory
cd tests\windows-docker

# Build and run comprehensive test suite
docker-compose up --build
.\run-windows-tests.ps1

# Available test options
.\run-windows-tests.ps1 -Detailed       # Verbose output
.\run-windows-tests.ps1 -SkipInstaller  # Skip installer tests
.\run-windows-tests.ps1 -SkipService    # Skip service tests
```

### Test Coverage (40+ Tests)
• **✅ System Prerequisites** - Windows version, PowerShell, admin rights  
• **✅ Python Dependencies** - All required packages validation  
• **✅ Project Structure** - File integrity and syntax validation  
• **✅ Windows Service** - Installation and lifecycle testing  
• **✅ Registry Operations** - Configuration storage testing  
• **✅ Installer Validation** - MSI package generation testing  

---

## 🛡️ Security & Legal

### ⚖️ Legal Notice

• **🏢 Property**: TechSquad Inc. proprietary software  
• **❌ Not For Resale**: Commercial distribution prohibited  
• **✅ Legal Use Only**: Authorized for legitimate security research  
• **🔒 Disclaimer**: Neither TechSquad Inc. nor TheStingR is responsible for improper use  

### 🔐 Windows Security Features

• **🔑 API Key Protection** - Secure Windows credential storage  
• **🗑️ No Data Retention** - Analysis results not stored remotely  
• **🔒 Local Processing** - Ghidra analysis performed locally  
• **📝 Audit Logging** - Windows Event Log integration  
• **🛡️ UAC Integration** - User Account Control compliance  
• **🔥 Firewall Integration** - Windows Defender Firewall configuration  

---

## 🤝 Contributing

This is **TechSquad Inc. proprietary software**. For feature requests, bug reports, or collaboration inquiries:

1. **📧 Contact**: Via GitHub issues  
2. **🐛 Bug Reports**: Include Windows version, logs, and system details  
3. **💡 Feature Requests**: Describe Windows-specific use cases  
4. **📋 Pull Requests**: Contact maintainers first  

---

## 🏷️ Version History

### v1.0.0 (September 2025) - Initial Windows Release 🚀

• **🏢 Enterprise Windows Service** - Complete background service implementation  
• **📦 Professional MSI Installer** - WiX-based enterprise deployment  
• **⚙️ PowerShell Management Suite** - Complete administrative tools  
• **🐳 Docker Testing Environment** - Windows container validation with 40+ tests  
• **🔐 Windows Security Integration** - Registry, Event Log, Firewall, UAC  
• **📊 Enterprise Monitoring** - Performance counters and health monitoring  
• **🔧 Configuration Management** - INI-based settings with registry storage  
• **🛡️ Production Ready** - Complete deployment and management solution  

---

## 📞 Support

• **📚 Documentation**: See included guides and README files  
• **🐛 Issues**: GitHub Issues tab  
• **💬 Community**: Windows security forums and Discord  
• **⚡ Enterprise**: Professional Windows deployment support available  

---

## 🔗 Related Projects

• **🐧 [MCP-Ghidra5](https://github.com/TheStingR/MCP-Ghidra5)** - Linux version with multi-AI support  
• **🔧 [Ghidra](https://github.com/NationalSecurityAgency/ghidra)** - NSA's reverse engineering framework  
• **🤖 [Model Context Protocol](https://github.com/modelcontextprotocol/protocol)** - MCP specification  

---

## ⭐ Star This Repository

If **MCP-Ghidra5-Windows** helps your Windows security research, please **⭐ star this repository** to support continued development!

---

**🏢 Copyright © 2024 TechSquad Inc. - All Rights Reserved**  
**👨‍💻 Coded by: [TheStingR](https://github.com/TheStingR)**  
**🔒 Proprietary Software - NOT FOR RESALE**

*Licensed for legal cybersecurity research and education*

---

[![GitHub stars](https://img.shields.io/github/stars/TheStingR/MCP-Ghidra5-Windows?style=social)](https://github.com/TheStingR/MCP-Ghidra5-Windows/stargazers)
[![GitHub forks](https://img.shields.io/github/forks/TheStingR/MCP-Ghidra5-Windows?style=social)](https://github.com/TheStingR/MCP-Ghidra5-Windows/network/members)
[![GitHub issues](https://img.shields.io/github/issues/TheStingR/MCP-Ghidra5-Windows?style=social)](https://github.com/TheStingR/MCP-Ghidra5-Windows/issues)
<!-- Contributors update trigger: Sun Sep 21 03:18:58 PM EDT 2025 -->
