# MCP Ghidra5 Windows - Deployment Guide

This guide covers enterprise deployment scenarios for MCP Ghidra5 Windows Edition.

## Quick Deployment

### Option 1: MSI Installer (Recommended)
```powershell
# Download and run installer as Administrator
.\MCP-Ghidra5-Windows-Setup.msi
```

### Option 2: PowerShell Script Installation
```powershell
# Run as Administrator
Set-ExecutionPolicy Bypass -Scope Process -Force
.\MCP-Ghidra5-Windows\scripts\installation\Install-TechSquadMCPGhidra5.ps1
```

## Enterprise Deployment

### Group Policy Deployment
1. Copy MSI to network share
2. Create GPO for software installation
3. Target computer groups for automatic deployment

### SCCM/MECM Deployment
```xml
<!-- Application definition for SCCM -->
<Application Name="MCP Ghidra5 Windows" Version="1.0.0">
  <InstallCommand>msiexec /i "MCP-Ghidra5-Windows-Setup.msi" /quiet</InstallCommand>
  <UninstallCommand>msiexec /x {GUID} /quiet</UninstallCommand>
</Application>
```

### Silent Installation
```cmd
msiexec /i "MCP-Ghidra5-Windows-Setup.msi" /quiet /l*v install.log GHIDRA_PATH="C:\Tools\ghidra" AUTOSTART=1
```

## Configuration

### Environment Variables
- `GHIDRA_HEADLESS_PATH`: Path to Ghidra analyzeHeadless executable
- `GHIDRA_PROJECT_DIR`: Directory for Ghidra projects
- `OPENAI_API_KEY`: OpenAI API key for AI features

### Registry Settings
Registry keys stored under `HKLM\SOFTWARE\TechSquad\MCP-Ghidra5`

### Service Configuration
Service configuration file: `C:\ProgramData\MCP-Ghidra5\service.conf`

## Verification

### Service Status
```powershell
Get-Service MCPGhidra5Service
```

### Health Check
```powershell
.\MCP-Ghidra5-Windows\scripts\service\Manage-MCPGhidra5Service.ps1 -Action Health
```

## Troubleshooting

### Common Issues
1. **Service won't start**: Check Ghidra path and permissions
2. **Port conflicts**: Modify port in service.conf
3. **Permission errors**: Ensure service runs as appropriate account

### Log Files
- Service logs: `C:\ProgramData\MCP-Ghidra5\Logs\`
- Installation logs: `%TEMP%\MCP-Ghidra5-Install.log`

## Security Considerations

### Firewall Configuration
The service uses port 8765 by default. Configure Windows Firewall as needed.

### Service Account
By default runs as LocalSystem. For enhanced security, use a dedicated service account.

### Windows Defender
Add exclusions for:
- `C:\Program Files\MCP-Ghidra5\`
- `C:\ProgramData\MCP-Ghidra5\`
- Ghidra installation directory

## Uninstallation

### Via Control Panel
1. Open "Programs and Features"
2. Select "MCP Ghidra5 Windows"
3. Click Uninstall

### Via PowerShell
```powershell
.\MCP-Ghidra5-Windows\scripts\service\Manage-MCPGhidra5Service.ps1 -Action Uninstall -RemoveData
```