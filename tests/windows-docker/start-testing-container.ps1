#Requires -Version 5.1

<#
.SYNOPSIS
    Container startup script for MCP-Ghidra5 Windows testing environment

.DESCRIPTION
    This script is executed when the Windows testing container starts.
    It provides information about the testing environment and available commands.

.NOTES
    This script runs automatically in the Windows Server Core testing container.
#>

$ErrorActionPreference = "Continue"

# Display welcome banner
Write-Host ""
Write-Host "🪟 MCP-Ghidra5 Windows Testing Container" -ForegroundColor Blue
Write-Host "=========================================" -ForegroundColor Gray
Write-Host "Container: Windows Server Core ltsc2022" -ForegroundColor Cyan
Write-Host "Started:   $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Cyan
Write-Host "Hostname:  $env:COMPUTERNAME" -ForegroundColor Cyan
Write-Host ""

# System information
Write-Host "📋 System Information:" -ForegroundColor Yellow
Write-Host "  OS Version:    $(Get-ComputerInfo | Select-Object -ExpandProperty WindowsProductName -ErrorAction SilentlyContinue)" -ForegroundColor Gray
Write-Host "  PowerShell:    $($PSVersionTable.PSVersion)" -ForegroundColor Gray
Write-Host "  Python:        $(python --version 2>&1)" -ForegroundColor Gray
Write-Host "  Java:          $(java -version 2>&1 | Select-Object -First 1)" -ForegroundColor Gray
Write-Host ""

# Directory structure
Write-Host "📁 Project Structure:" -ForegroundColor Yellow
try {
    if (Test-Path "C:\mcp-ghidra5") {
        Write-Host "  ✅ Project directory: C:\mcp-ghidra5" -ForegroundColor Green
        $projectFiles = Get-ChildItem "C:\mcp-ghidra5" -Recurse -File | Measure-Object
        Write-Host "  📄 Total files: $($projectFiles.Count)" -ForegroundColor Gray
    } else {
        Write-Host "  ❌ Project directory not found" -ForegroundColor Red
    }
} catch {
    Write-Host "  ⚠️  Unable to check project structure" -ForegroundColor Yellow
}
Write-Host ""

# Environment variables
Write-Host "🔧 Environment Variables:" -ForegroundColor Yellow
$envVars = @('GHIDRA_INSTALL_DIR', 'GHIDRA_HEADLESS_PATH', 'MCP_SERVER_HOST', 'MCP_SERVER_PORT')
foreach ($var in $envVars) {
    $value = [Environment]::GetEnvironmentVariable($var)
    if ($value) {
        Write-Host "  ✅ $var = $value" -ForegroundColor Green
    } else {
        Write-Host "  ❌ $var = <not set>" -ForegroundColor Red
    }
}
Write-Host ""

# Available test commands
Write-Host "🧪 Available Test Commands:" -ForegroundColor Yellow
Write-Host "  Run full test suite:" -ForegroundColor Gray
Write-Host "    PS> .\tests\windows-docker\run-windows-tests.ps1" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Run tests with options:" -ForegroundColor Gray
Write-Host "    PS> .\tests\windows-docker\run-windows-tests.ps1 -SkipInstaller" -ForegroundColor Cyan
Write-Host "    PS> .\tests\windows-docker\run-windows-tests.ps1 -SkipService" -ForegroundColor Cyan
Write-Host "    PS> .\tests\windows-docker\run-windows-tests.ps1 -Detailed" -ForegroundColor Cyan
Write-Host ""

# Service management commands
Write-Host "⚙️  Service Management Commands:" -ForegroundColor Yellow
Write-Host "  Install service:" -ForegroundColor Gray
Write-Host "    PS> .\MCP-Ghidra5-Windows\scripts\service\Install-MCPGhidra5Service.ps1" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Manage service:" -ForegroundColor Gray
Write-Host "    PS> .\MCP-Ghidra5-Windows\scripts\service\Manage-MCPGhidra5Service.ps1 -Status" -ForegroundColor Cyan
Write-Host "    PS> .\MCP-Ghidra5-Windows\scripts\service\Manage-MCPGhidra5Service.ps1 -Start" -ForegroundColor Cyan
Write-Host "    PS> .\MCP-Ghidra5-Windows\scripts\service\Manage-MCPGhidra5Service.ps1 -Stop" -ForegroundColor Cyan
Write-Host ""

# Build and installer commands
Write-Host "📦 Build and Installer Commands:" -ForegroundColor Yellow
Write-Host "  Quick build installer:" -ForegroundColor Gray
Write-Host "    PS> .\MCP-Ghidra5-Windows\scripts\packaging\Quick-BuildInstaller.ps1" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Build with WiX (if available):" -ForegroundColor Gray
Write-Host "    PS> .\MCP-Ghidra5-Windows\scripts\packaging\Build-MSIInstaller.ps1" -ForegroundColor Cyan
Write-Host ""

# Validation commands
Write-Host "✅ Manual Validation Commands:" -ForegroundColor Yellow
Write-Host "  Check dependencies:" -ForegroundColor Gray
Write-Host "    PS> python -c \"import pywin32, psutil, configparser, httpx; print('All dependencies OK')\"" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Test Ghidra headless:" -ForegroundColor Gray
Write-Host "    PS> & \$env:GHIDRA_HEADLESS_PATH -help" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Validate Python server syntax:" -ForegroundColor Gray
Write-Host "    PS> python -m py_compile .\MCP-Ghidra5-Windows\src\mcp_ghidra_server_windows.py" -ForegroundColor Cyan
Write-Host ""

# Log locations
Write-Host "📄 Log Locations:" -ForegroundColor Yellow
Write-Host "  Test logs:     C:\ProgramData\MCP-Ghidra5\Logs\windows-tests.log" -ForegroundColor Gray
Write-Host "  Service logs:  C:\ProgramData\MCP-Ghidra5\Logs\mcp_ghidra5_service.log" -ForegroundColor Gray
Write-Host "  Build logs:    C:\mcp-ghidra5\build\logs\" -ForegroundColor Gray
Write-Host ""

# Directory shortcuts
Write-Host "📂 Quick Directory Navigation:" -ForegroundColor Yellow
Write-Host "  Project root:  Set-Location C:\mcp-ghidra5" -ForegroundColor Gray
Write-Host "  Test scripts:  Set-Location C:\mcp-ghidra5\tests\windows-docker" -ForegroundColor Gray
Write-Host "  Source code:   Set-Location C:\mcp-ghidra5\MCP-Ghidra5-Windows\src" -ForegroundColor Gray
Write-Host "  Service scripts: Set-Location C:\mcp-ghidra5\MCP-Ghidra5-Windows\scripts\service" -ForegroundColor Gray
Write-Host ""

# Container management
Write-Host "🐳 Container Management:" -ForegroundColor Yellow
Write-Host "  Exit container: exit" -ForegroundColor Gray
Write-Host "  View running processes: Get-Process" -ForegroundColor Gray
Write-Host "  System information: Get-ComputerInfo" -ForegroundColor Gray
Write-Host ""

Write-Host "🚀 Ready for MCP-Ghidra5 Windows testing!" -ForegroundColor Green
Write-Host "   Start with: .\tests\windows-docker\run-windows-tests.ps1" -ForegroundColor White
Write-Host ""

# Change to project directory for convenience
try {
    Set-Location "C:\mcp-ghidra5" -ErrorAction SilentlyContinue
    Write-Host "📍 Current directory: $(Get-Location)" -ForegroundColor Cyan
} catch {
    Write-Host "⚠️  Could not change to project directory" -ForegroundColor Yellow
}

Write-Host "================================================================================================" -ForegroundColor Gray