#Requires -Version 5.1
#Requires -RunAsAdministrator

<#
.SYNOPSIS
    MCP-Ghidra5 - Guided Windows Service Installation

.DESCRIPTION
    Interactive installation wizard for MCP Ghidra5 Windows Service.
    Provides guided setup with validation, configuration, and deployment.

.PARAMETER Silent
    Run installation in silent mode with default settings

.PARAMETER ConfigFile
    Path to custom configuration file

.EXAMPLE
    .\Install-MCPGhidra5Service.ps1

.EXAMPLE
    .\Install-MCPGhidra5Service.ps1 -Silent

.EXAMPLE
    .\Install-MCPGhidra5Service.ps1 -ConfigFile "C:\Config\custom.conf"

.NOTES
    Copyright (c) 2024 - All Rights Reserved
#>

[CmdletBinding()]
param(
    [switch]$Silent,
    [string]$ConfigFile
)

$ErrorActionPreference = "Stop"

# Import the main management functions
$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$ManagementScript = Join-Path $ScriptRoot "Manage-MCPGhidra5Service.ps1"

if (-not (Test-Path $ManagementScript)) {
    Write-Error "Management script not found: $ManagementScript"
    exit 1
}

# Configuration
$Script:Config = @{
    ServiceName = "MCPGhidra5Service"
    DisplayName = "MCP Ghidra5 Server"
    InstallPath = Split-Path -Parent $ScriptRoot
    DefaultPort = 8765
    DefaultGhidraPath = "C:\ghidra_11.1.2_PUBLIC"
}

function Write-Banner {
    Clear-Host
    Write-Host @"
    ╔══════════════════════════════════════════════════════════════════╗
    ║                                                                  ║
    ║    🔧 MCP-Ghidra5 - Windows Service Installation         ║
    ║                                                                  ║
    ║    Transform your server into an enterprise Windows service     ║
    ║    with automatic startup, monitoring, and management tools     ║
    ║                                                                  ║
    ╚══════════════════════════════════════════════════════════════════╝

"@ -ForegroundColor Cyan
}

function Write-Step {
    param([string]$Title, [string]$Description)
    Write-Host "`n📋 $Title" -ForegroundColor Yellow
    Write-Host "   $Description" -ForegroundColor White
    Write-Host ("   " + "─" * 60) -ForegroundColor Gray
}

function Write-Success {
    param([string]$Message)
    Write-Host "✅ $Message" -ForegroundColor Green
}

function Write-Warning {
    param([string]$Message)
    Write-Host "⚠️  $Message" -ForegroundColor Yellow
}

function Write-Error {
    param([string]$Message)
    Write-Host "❌ $Message" -ForegroundColor Red
}

function Test-Prerequisites {
    Write-Step "Prerequisites Check" "Validating system requirements and dependencies"
    
    $checks = @()
    
    # Administrator check
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    if ($currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        $checks += @{ Name = "Administrator Privileges"; Status = $true; Message = "Running as administrator" }
    } else {
        $checks += @{ Name = "Administrator Privileges"; Status = $false; Message = "Not running as administrator" }
    }
    
    # PowerShell version check
    if ($PSVersionTable.PSVersion.Major -ge 5) {
        $checks += @{ Name = "PowerShell Version"; Status = $true; Message = "PowerShell $($PSVersionTable.PSVersion)" }
    } else {
        $checks += @{ Name = "PowerShell Version"; Status = $false; Message = "PowerShell 5.1+ required" }
    }
    
    # Python check
    $pythonPath = Get-Command python -ErrorAction SilentlyContinue
    if (-not $pythonPath) {
        $pythonPath = Get-Command python3 -ErrorAction SilentlyContinue
    }
    if ($pythonPath) {
        try {
            $pythonVersion = & python --version 2>&1
            $checks += @{ Name = "Python Installation"; Status = $true; Message = "$pythonVersion at $($pythonPath.Source)" }
        } catch {
            $checks += @{ Name = "Python Installation"; Status = $false; Message = "Python found but version check failed" }
        }
    } else {
        $checks += @{ Name = "Python Installation"; Status = $false; Message = "Python not found in PATH" }
    }
    
    # Service script check
    $serviceScript = Join-Path $ScriptRoot "techsquad_mcp_service.py"
    if (Test-Path $serviceScript) {
        $checks += @{ Name = "Service Script"; Status = $true; Message = "Service script found" }
    } else {
        $checks += @{ Name = "Service Script"; Status = $false; Message = "Service script not found" }
    }
    
    # Check if service already exists
    $existingService = Get-Service -Name $Script:Config.ServiceName -ErrorAction SilentlyContinue
    if ($existingService) {
        $checks += @{ Name = "Service Status"; Status = $false; Message = "Service already exists" }
    } else {
        $checks += @{ Name = "Service Status"; Status = $true; Message = "Service name available" }
    }
    
    # Display results
    foreach ($check in $checks) {
        if ($check.Status) {
            Write-Host "   ✅ $($check.Name): $($check.Message)" -ForegroundColor Green
        } else {
            Write-Host "   ❌ $($check.Name): $($check.Message)" -ForegroundColor Red
        }
    }
    
    $failedChecks = $checks | Where-Object { -not $_.Status }
    if ($failedChecks) {
        Write-Host "`n⚠️  Issues detected. Some prerequisites are not met." -ForegroundColor Yellow
        
        if (-not $Silent) {
            $continue = Read-Host "`nDo you want to continue anyway? (y/N)"
            if ($continue -ne 'y' -and $continue -ne 'Y') {
                Write-Host "Installation cancelled by user." -ForegroundColor Yellow
                exit 0
            }
        }
        return $false
    }
    
    Write-Success "All prerequisites met!"
    return $true
}

function Get-InstallationSettings {
    if ($Silent) {
        return @{
            StartupType = 'Automatic'
            ServiceAccount = 'LocalSystem'
            AutoStart = $true
            Port = $Script:Config.DefaultPort
            GhidraPath = $Script:Config.DefaultGhidraPath
        }
    }
    
    Write-Step "Installation Configuration" "Configure service settings and options"
    
    # Startup type
    Write-Host "`n🔧 Service Startup Configuration"
    Write-Host "   1. Automatic (Recommended) - Start with Windows"
    Write-Host "   2. Manual - Start only when requested"
    Write-Host "   3. Disabled - Do not start automatically"
    
    do {
        $startupChoice = Read-Host "`nSelect startup type (1-3, default: 1)"
        if ([string]::IsNullOrEmpty($startupChoice)) { $startupChoice = "1" }
    } while ($startupChoice -notin @("1", "2", "3"))
    
    $startupTypes = @{ "1" = "Automatic"; "2" = "Manual"; "3" = "Disabled" }
    $startupType = $startupTypes[$startupChoice]
    
    # Service account
    Write-Host "`n👤 Service Account Configuration"
    Write-Host "   1. LocalSystem (Recommended) - Built-in system account"
    Write-Host "   2. NetworkService - Limited privileges with network access"
    Write-Host "   3. Custom Account - Specify domain or local account"
    
    do {
        $accountChoice = Read-Host "`nSelect service account (1-3, default: 1)"
        if ([string]::IsNullOrEmpty($accountChoice)) { $accountChoice = "1" }
    } while ($accountChoice -notin @("1", "2", "3"))
    
    $serviceAccount = switch ($accountChoice) {
        "1" { "LocalSystem" }
        "2" { "NT AUTHORITY\NetworkService" }
        "3" {
            $customAccount = Read-Host "Enter service account (e.g., DOMAIN\Username)"
            if ([string]::IsNullOrEmpty($customAccount)) {
                Write-Warning "Using LocalSystem account"
                "LocalSystem"
            } else {
                $customAccount
            }
        }
    }
    
    # Auto start
    $autoStart = $true
    if ($startupType -ne "Disabled") {
        $startChoice = Read-Host "`n🚀 Start service immediately after installation? (Y/n, default: Y)"
        $autoStart = ($startChoice -ne 'n' -and $startChoice -ne 'N')
    } else {
        $autoStart = $false
    }
    
    # Port configuration
    $port = Read-Host "`n🌐 Server port (default: $($Script:Config.DefaultPort))"
    if ([string]::IsNullOrEmpty($port)) {
        $port = $Script:Config.DefaultPort
    } else {
        try {
            $port = [int]$port
            if ($port -lt 1 -or $port -gt 65535) {
                Write-Warning "Invalid port number. Using default: $($Script:Config.DefaultPort)"
                $port = $Script:Config.DefaultPort
            }
        } catch {
            Write-Warning "Invalid port format. Using default: $($Script:Config.DefaultPort)"
            $port = $Script:Config.DefaultPort
        }
    }
    
    # Ghidra path
    $ghidraPath = Read-Host "`n📁 Ghidra installation path (default: $($Script:Config.DefaultGhidraPath))"
    if ([string]::IsNullOrEmpty($ghidraPath)) {
        $ghidraPath = $Script:Config.DefaultGhidraPath
    }
    
    return @{
        StartupType = $startupType
        ServiceAccount = $serviceAccount
        AutoStart = $autoStart
        Port = $port
        GhidraPath = $ghidraPath
    }
}

function Show-InstallationSummary {
    param($Settings)
    
    Write-Step "Installation Summary" "Review configuration before installation"
    
    Write-Host "`n📋 Service Configuration:"
    Write-Host "   Service Name: $($Script:Config.ServiceName)" -ForegroundColor White
    Write-Host "   Display Name: $($Script:Config.DisplayName)" -ForegroundColor White
    Write-Host "   Startup Type: $($Settings.StartupType)" -ForegroundColor White
    Write-Host "   Service Account: $($Settings.ServiceAccount)" -ForegroundColor White
    Write-Host "   Auto Start: $($Settings.AutoStart)" -ForegroundColor White
    Write-Host "   Server Port: $($Settings.Port)" -ForegroundColor White
    Write-Host "   Ghidra Path: $($Settings.GhidraPath)" -ForegroundColor White
    
    Write-Host "`n📂 File Locations:" -ForegroundColor Cyan
    Write-Host "   Installation: $($Script:Config.InstallPath)" -ForegroundColor White
    Write-Host "   Configuration: %ProgramData%\MCP-Ghidra5\service.conf" -ForegroundColor White
    Write-Host "   Log Files: %ProgramData%\MCP-Ghidra5\Logs" -ForegroundColor White
    
    if (-not $Silent) {
        Write-Host "`n" -NoNewline
        $confirm = Read-Host "Proceed with installation? (Y/n, default: Y)"
        if ($confirm -eq 'n' -or $confirm -eq 'N') {
            Write-Host "Installation cancelled by user." -ForegroundColor Yellow
            exit 0
        }
    }
}

function Install-ServiceWithSettings {
    param($Settings)
    
    Write-Step "Service Installation" "Installing and configuring Windows service"
    
    # Build installation parameters
    $installParams = @{
        Action = 'Install'
        StartupType = $Settings.StartupType
        ServiceAccount = $Settings.ServiceAccount
    }
    
    if ($Settings.AutoStart) {
        $installParams.AutoStart = $true
    }
    
    # Execute installation
    try {
        Write-Host "   Installing service..." -ForegroundColor Yellow
        & $ManagementScript @installParams
        Write-Success "Service installation completed!"
        
        # Update configuration file with custom settings
        $configPath = Join-Path $env:ProgramData "MCP-Ghidra5\service.conf"
        if (Test-Path $configPath) {
            Write-Host "   Updating configuration..." -ForegroundColor Yellow
            
            $configContent = Get-Content $configPath
            $configContent = $configContent -replace "port = \d+", "port = $($Settings.Port)"
            $configContent = $configContent -replace "ghidra_path = .*", "ghidra_path = $($Settings.GhidraPath)"
            
            $configContent | Set-Content $configPath
            Write-Success "Configuration updated"
        }
        
        return $true
        
    } catch {
        Write-Error "Installation failed: $($_.Exception.Message)"
        return $false
    }
}

function Show-PostInstallation {
    Write-Step "Installation Complete" "Service successfully installed and configured"
    
    Write-Host @"
    
    🎉 MCP Ghidra5 Windows Service Installation Complete!
    
    ✅ Service '$($Script:Config.ServiceName)' has been installed
    ✅ Configuration files created
    ✅ Log directories prepared
    
    🔧 Management Commands:
    
    Using batch file (Recommended):
       mcp-ghidra5-service.bat status      # Check service status
       mcp-ghidra5-service.bat start       # Start service
       mcp-ghidra5-service.bat stop        # Stop service
       mcp-ghidra5-service.bat monitor     # Real-time monitoring
       mcp-ghidra5-service.bat health      # Health check
    
    Using Windows commands:
       net start $($Script:Config.ServiceName)        # Start service
       net stop $($Script:Config.ServiceName)         # Stop service
       sc query $($Script:Config.ServiceName)         # Query status
    
    Using PowerShell:
       Get-Service -Name "$($Script:Config.ServiceName)"
       Start-Service -Name "$($Script:Config.ServiceName)"
       Stop-Service -Name "$($Script:Config.ServiceName)"
    
    📁 Important Locations:
       Configuration: %ProgramData%\MCP-Ghidra5\service.conf
       Logs: %ProgramData%\MCP-Ghidra5\Logs
       Management Scripts: $ScriptRoot
    
    📚 Documentation:
       See README-Service.md for detailed usage instructions
    
"@ -ForegroundColor Green
    
    if (-not $Silent) {
        Write-Host "Press any key to continue..." -ForegroundColor Gray
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    }
}

# Main execution
try {
    if (-not $Silent) {
        Write-Banner
        Start-Sleep -Seconds 1
    }
    
    # Step 1: Prerequisites
    $prereqsPassed = Test-Prerequisites
    
    # Step 2: Configuration
    $settings = Get-InstallationSettings
    
    # Step 3: Summary
    if (-not $Silent) {
        Show-InstallationSummary -Settings $settings
    }
    
    # Step 4: Installation
    $installSuccess = Install-ServiceWithSettings -Settings $settings
    
    if ($installSuccess) {
        # Step 5: Post-installation
        Show-PostInstallation
        
        # Optional: Open service manager
        if (-not $Silent) {
            $openServices = Read-Host "`nWould you like to open the Windows Services manager? (y/N)"
            if ($openServices -eq 'y' -or $openServices -eq 'Y') {
                Start-Process "services.msc"
            }
        }
        
        Write-Host "`n✅ Installation completed successfully!" -ForegroundColor Green
        exit 0
    } else {
        Write-Host "`n❌ Installation failed. Please check the error messages above." -ForegroundColor Red
        exit 1
    }
    
} catch {
    Write-Host "`n💥 Unexpected error during installation:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host "`nFor support, please provide this error information along with:" -ForegroundColor Yellow
    Write-Host "- Windows version: $([System.Environment]::OSVersion.VersionString)" -ForegroundColor Gray
    Write-Host "- PowerShell version: $($PSVersionTable.PSVersion)" -ForegroundColor Gray
    Write-Host "- Installation directory: $ScriptRoot" -ForegroundColor Gray
    
    if (-not $Silent) {
        Write-Host "`nPress any key to exit..." -ForegroundColor Gray
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    }
    
    exit 1
}