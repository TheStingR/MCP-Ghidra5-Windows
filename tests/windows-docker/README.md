# MCP-Ghidra5 Windows Docker Testing Environment

This directory contains a comprehensive Windows testing environment for the MCP-Ghidra5 Windows installer and service functionality. The testing environment runs in a Windows Server Core container with all dependencies pre-installed.

## 🎯 Purpose

The Windows Docker testing environment provides:

- **Comprehensive Validation**: Full testing of the Windows installer, service installation, and functionality
- **Isolated Environment**: Clean Windows Server Core container for repeatable testing
- **Automated Testing**: PowerShell-based test suite with detailed reporting
- **CI/CD Integration**: Ready for automated testing pipelines
- **Development Testing**: Quick validation of changes without full Windows VM setup

## 📋 Requirements

### System Requirements
- **Docker Desktop** with Windows containers enabled
- **Windows 10/11 Pro/Enterprise** or **Windows Server 2019/2022**
- **Minimum 8GB RAM** and **20GB free disk space**
- **Hyper-V** enabled (for Windows containers)

### Docker Desktop Configuration
```powershell
# Switch to Windows containers
& "C:\Program Files\Docker\Docker\DockerCli.exe" -SwitchDaemon

# Verify Windows container support
docker version --format "{{.Server.Os}}"  # Should return "windows"
```

## 🚀 Quick Start

### 1. Build and Run Container

```powershell
# Navigate to the testing directory
Set-Location tests\windows-docker

# Build and start the testing container
docker-compose up --build

# Alternative: Run interactively
docker-compose run --rm mcp-ghidra5-test-windows powershell
```

### 2. Run Test Suite

Once inside the container:

```powershell
# Run the complete test suite
.\tests\windows-docker\run-windows-tests.ps1

# Run with options
.\tests\windows-docker\run-windows-tests.ps1 -Detailed
.\tests\windows-docker\run-windows-tests.ps1 -SkipInstaller
.\tests\windows-docker\run-windows-tests.ps1 -SkipService
```

### 3. Manual Testing

```powershell
# Test individual components
python -c "import pywin32, psutil, configparser, httpx; print('Dependencies OK')"

# Validate PowerShell scripts
.\MCP-Ghidra5-Windows\scripts\service\Install-MCPGhidra5Service.ps1 -WhatIf

# Test Ghidra installation  
& $env:GHIDRA_HEADLESS_PATH -help
```

## 📁 File Structure

```
tests/windows-docker/
├── Dockerfile                      # Windows Server Core container definition
├── docker-compose.yml             # Container orchestration configuration
├── run-windows-tests.ps1          # Comprehensive test suite
├── start-testing-container.ps1    # Container startup script
└── README.md                       # This documentation
```

## 🧪 Test Coverage

The test suite validates the following components:

### System Prerequisites
- ✅ PowerShell 5.1+ availability
- ✅ Python 3.x installation and configuration
- ✅ Java 11+ runtime environment
- ✅ Ghidra headless analysis tools
- ✅ Administrator privileges

### Python Dependencies
- ✅ `pywin32` - Windows service management
- ✅ `psutil` - System process monitoring
- ✅ `configparser` - Configuration file parsing
- ✅ `httpx` - HTTP client for MCP communication

### Project Structure Validation
- ✅ Core source files presence
- ✅ Configuration file validity
- ✅ Service management scripts
- ✅ PowerShell script syntax validation

### Windows Service Testing
- ✅ Service installation script validation
- ✅ Service management functionality
- ✅ Registry operations and permissions
- ✅ Windows Service Control Manager integration

### Installer Validation
- ✅ Mock installer build process
- ✅ MSI package generation
- ✅ WiX toolset integration (when available)
- ✅ Installation dependency checking

### Configuration Management
- ✅ INI file parsing and validation
- ✅ Environment variable handling
- ✅ Log directory creation and permissions
- ✅ Registry key management

## 🔧 Container Configuration

### Base Image
- **Windows Server Core ltsc2022** - Lightweight Windows container
- **PowerShell 7** as default shell
- **Chocolatey** package manager for dependency installation

### Pre-installed Dependencies
- **Python 3.11.5** with pip package manager
- **OpenJDK 11** for Ghidra compatibility
- **Ghidra 11.0** with headless analysis tools
- **Git** for version control operations
- **7-Zip** for archive extraction
- **PowerShell Core** with enhanced scripting capabilities

### Environment Variables
```powershell
GHIDRA_INSTALL_DIR=C:\ghidra_11.0_PUBLIC
GHIDRA_HEADLESS_PATH=C:\ghidra_11.0_PUBLIC\support\analyzeHeadless.bat
MCP_SERVER_HOST=0.0.0.0
MCP_SERVER_PORT=8765
PYTHONUNBUFFERED=1
```

### Volume Mounts
- **Logs**: `C:\ProgramData\MCP-Ghidra5\Logs` - Persistent test and service logs
- **Projects**: `C:\ProgramData\MCP-Ghidra5\Projects` - Ghidra project storage
- **Build Output**: `C:\mcp-ghidra5\build` - Installer build artifacts

## 📊 Test Results

### Success Criteria
- **90%+ Pass Rate**: Indicates environment ready for deployment
- **75-89% Pass Rate**: Minor issues detected, review failures
- **<75% Pass Rate**: Critical issues, environment not ready

### Output Formats
- **Console Output**: Real-time colored progress indication
- **Log File**: Detailed test execution log at `C:\ProgramData\MCP-Ghidra5\Logs\windows-tests.log`
- **Exit Codes**: 
  - `0` - All tests passed
  - `1` - Minor issues detected
  - `2` - Critical issues detected
  - `3` - Test suite execution failed

## 🐳 Docker Commands Reference

### Container Management
```powershell
# Build the container
docker-compose build

# Run interactive session
docker-compose run --rm mcp-ghidra5-test-windows powershell

# View container logs
docker-compose logs mcp-ghidra5-test-windows

# Stop and cleanup
docker-compose down --volumes
```

### Volume Management
```powershell
# List project volumes
docker volume ls --filter label=project=mcp-ghidra5

# Inspect volume contents
docker volume inspect mcp-test-logs

# Cleanup volumes
docker-compose down --volumes --remove-orphans
```

### Image Management
```powershell
# List Windows images
docker images --filter "reference=*mcp-ghidra5*"

# Remove test images
docker rmi $(docker images -q "*mcp-ghidra5*")

# Prune unused Windows images
docker image prune --filter "label=project=mcp-ghidra5"
```

## 🔍 Troubleshooting

### Common Issues

#### Docker Desktop Not Using Windows Containers
```powershell
# Switch to Windows containers
& "C:\Program Files\Docker\Docker\DockerCli.exe" -SwitchDaemon

# Verify switch was successful
docker version
```

#### Insufficient Memory/Disk Space
```powershell
# Check Docker Desktop settings
# Minimum: 8GB RAM, 20GB disk

# Clean up unused containers and images
docker system prune --all --volumes
```

#### Container Build Failures
```powershell
# Check Windows base image availability
docker pull mcr.microsoft.com/windows/servercore:ltsc2022

# Build with verbose output
docker-compose build --progress=plain --no-cache
```

#### Test Execution Issues
```powershell
# Run tests with detailed logging
.\run-windows-tests.ps1 -Detailed

# Check individual component functionality
python --version
java -version
& $env:GHIDRA_HEADLESS_PATH -help
```

### Log Analysis
```powershell
# View test logs
Get-Content C:\ProgramData\MCP-Ghidra5\Logs\windows-tests.log -Tail 50

# Search for specific errors
Select-String -Path C:\ProgramData\MCP-Ghidra5\Logs\windows-tests.log -Pattern "ERROR"

# Monitor logs in real-time
Get-Content C:\ProgramData\MCP-Ghidra5\Logs\windows-tests.log -Wait
```

## 🚀 Integration with CI/CD

### GitHub Actions Example
```yaml
name: Windows Integration Tests

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]

jobs:
  windows-tests:
    runs-on: windows-2022
    steps:
      - uses: actions/checkout@v3
      
      - name: Switch to Windows Containers
        run: |
          & "C:\Program Files\Docker\Docker\DockerCli.exe" -SwitchDaemon
          
      - name: Build and Test
        run: |
          cd tests\windows-docker
          docker-compose run --rm mcp-ghidra5-test-windows powershell -Command ".\tests\windows-docker\run-windows-tests.ps1"
```

### Azure DevOps Pipeline
```yaml
trigger:
  branches:
    include:
      - main
      - develop

pool:
  vmImage: 'windows-2022'

steps:
- task: PowerShell@2
  displayName: 'Run Windows Integration Tests'
  inputs:
    targetType: 'inline'
    script: |
      cd tests\windows-docker
      docker-compose run --rm mcp-ghidra5-test-windows powershell -Command ".\tests\windows-docker\run-windows-tests.ps1; exit $LASTEXITCODE"
```

## 📚 Additional Resources

- [Docker Windows Containers Documentation](https://docs.microsoft.com/en-us/virtualization/windowscontainers/)
- [PowerShell in Docker](https://docs.microsoft.com/en-us/powershell/scripting/install/installing-powershell-core-on-windows)
- [Ghidra Documentation](https://ghidra-sre.org/CheatSheet.html)
- [Windows Service Development](https://docs.microsoft.com/en-us/dotnet/framework/windows-services/)

## 🤝 Contributing

When adding new tests or modifying the testing environment:

1. **Test Locally**: Always validate changes in the Docker container
2. **Update Documentation**: Keep README.md current with new functionality
3. **Maintain Compatibility**: Ensure tests work on different Windows versions
4. **Log Appropriately**: Add proper logging for debugging failed tests
5. **Follow PowerShell Best Practices**: Use approved verbs and proper error handling

## 📄 License

This testing environment is part of the MCP-Ghidra5 project and follows the same licensing terms as the main project.