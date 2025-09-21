#Requires -Version 5.1
#Requires -RunAsAdministrator

<#
.SYNOPSIS
    MCP-Ghidra5 - Enterprise Service Management Script

.DESCRIPTION
    Comprehensive Windows service management for MCP Ghidra5 Server.
    Provides enterprise deployment, monitoring, and maintenance capabilities.

.PARAMETER Action
    Action to perform: Install, Uninstall, Start, Stop, Restart, Status, Monitor, Configure

.PARAMETER ServiceAccount
    Service account to run under (for Install action)

.PARAMETER ServicePassword
    Password for custom service account

.PARAMETER StartupType
    Service startup type: Automatic, Manual, Disabled

.PARAMETER AutoStart
    Start service immediately after installation

.PARAMETER RemoveData
    Remove all data when uninstalling

.PARAMETER ConfigFile
    Custom configuration file path

.PARAMETER WatchInterval
    Monitoring interval in seconds (for Monitor action)

.EXAMPLE
    .\Manage-MCPGhidra5Service.ps1 -Action Install -AutoStart

.EXAMPLE
    .\Manage-MCPGhidra5Service.ps1 -Action Install -ServiceAccount "DOMAIN\ServiceUser" -ServicePassword (ConvertTo-SecureString "Password" -AsPlainText -Force)

.EXAMPLE
    .\Manage-MCPGhidra5Service.ps1 -Action Monitor -WatchInterval 30

.EXAMPLE
    .\Manage-MCPGhidra5Service.ps1 -Action Configure -ConfigFile "C:\Config\custom.conf"

.NOTES
    Copyright (c) 2024 - All Rights Reserved
    
    This script requires:
    - Administrator privileges
    - PowerShell 5.1 or later
    - Python 3.8+ with pywin32, psutil
    - MCP Ghidra5 installation
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('Install', 'Uninstall', 'Start', 'Stop', 'Restart', 'Status', 'Monitor', 'Configure', 'Health', 'Backup', 'Restore')]
    [string]$Action,
    
    [string]$ServiceAccount = 'LocalSystem',
    
    [SecureString]$ServicePassword,
    
    [ValidateSet('Automatic', 'Manual', 'Disabled')]
    [string]$StartupType = 'Automatic',
    
    [switch]$AutoStart,
    
    [switch]$RemoveData,
    
    [string]$ConfigFile,
    
    [int]$WatchInterval = 60,
    
    [string]$BackupPath,
    
    [switch]$Detailed,
    
    [switch]$JSON
)

# Script configuration
$ErrorActionPreference = "Stop"
$Script:ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$Script:InstallPath = Split-Path -Parent $Script:ScriptRoot
$Script:LogFile = Join-Path $env:TEMP "MCPGhidra5Service-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"

# Service configuration
$Script:ServiceConfig = @{
    Name = "MCPGhidra5Service"
    DisplayName = "MCP Ghidra5 Server"
    Description = "AI-powered reverse engineering server with enterprise features"
    BinaryPath = Join-Path $Script:InstallPath "service\mcp_ghidra5_service.py"
    ConfigPath = Join-Path $env:ProgramData "MCP-Ghidra5\service.conf"
    LogPath = Join-Path $env:ProgramData "MCP-Ghidra5\Logs"
}

# Color functions
function Write-Info {
    param([string]$Message)
    Write-Host "ℹ️  $Message" -ForegroundColor Cyan
    Add-Content -Path $Script:LogFile -Value "[INFO] $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - $Message"
}

function Write-Success {
    param([string]$Message)
    Write-Host "✅ $Message" -ForegroundColor Green
    Add-Content -Path $Script:LogFile -Value "[SUCCESS] $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - $Message"
}

function Write-Warning {
    param([string]$Message)
    Write-Host "⚠️  $Message" -ForegroundColor Yellow
    Add-Content -Path $Script:LogFile -Value "[WARNING] $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - $Message"
}

function Write-Error {
    param([string]$Message)
    Write-Host "❌ $Message" -ForegroundColor Red
    Add-Content -Path $Script:LogFile -Value "[ERROR] $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - $Message"
}

function Test-Prerequisites {
    Write-Info "Checking prerequisites..."
    
    # Check if running as administrator
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw "This script requires administrator privileges."
    }
    Write-Success "Administrator privileges confirmed"
    
    # Check Python
    $pythonPath = Get-Command python -ErrorAction SilentlyContinue
    if (-not $pythonPath) {
        $pythonPath = Get-Command python3 -ErrorAction SilentlyContinue
    }
    if (-not $pythonPath) {
        throw "Python not found in PATH. Please install Python 3.8+ and ensure it's in PATH."
    }
    Write-Success "Python found: $($pythonPath.Source)"
    
    # Check service script
    if (-not (Test-Path $Script:ServiceConfig.BinaryPath)) {
        throw "Service script not found: $($Script:ServiceConfig.BinaryPath)"
    }
    Write-Success "Service script found"
    
    # Check Python packages
    $requiredPackages = @('pywin32', 'psutil', 'configparser')
    foreach ($package in $requiredPackages) {
        try {
            $result = & python -c "import $package; print('OK')" 2>$null
            if ($result -eq 'OK') {
                Write-Success "Python package '$package' available"
            } else {
                throw "Package $package not available"
            }
        } catch {
            Write-Warning "Installing Python package '$package'..."
            & python -m pip install $package --quiet
            Write-Success "Installed Python package '$package'"
        }
    }
    
    return $true
}

function Install-Service {
    Write-Info "Installing MCP Ghidra5 Windows Service..."
    
    # Check if service already exists
    $existingService = Get-Service -Name $Script:ServiceConfig.Name -ErrorAction SilentlyContinue
    if ($existingService) {
        throw "Service '$($Script:ServiceConfig.Name)' already exists. Use -Action Uninstall first."
    }
    
    # Create directories
    $directories = @(
        (Split-Path $Script:ServiceConfig.ConfigPath -Parent),
        $Script:ServiceConfig.LogPath,
        (Join-Path $env:ProgramData "MCP-Ghidra5\Config")
    )
    
    foreach ($dir in $directories) {
        if (-not (Test-Path $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
            Write-Info "Created directory: $dir"
        }
    }
    
    # Copy default configuration if not exists
    if (-not (Test-Path $Script:ServiceConfig.ConfigPath)) {
        $defaultConfig = Join-Path $Script:ScriptRoot "service.conf"
        if (Test-Path $defaultConfig) {
            Copy-Item $defaultConfig $Script:ServiceConfig.ConfigPath
            Write-Info "Copied default configuration"
        }
    }
    
    # Install service using Python script
    Write-Info "Installing Windows service..."
    
    $installArgs = @(
        $Script:ServiceConfig.BinaryPath,
        'install'
    )
    
    $result = & python @installArgs 2>&1
    
    if ($LASTEXITCODE -ne 0) {
        throw "Service installation failed: $result"
    }
    
    Write-Success "Service installed successfully"
    
    # Configure service startup type
    if ($StartupType -ne 'Automatic') {
        Set-Service -Name $Script:ServiceConfig.Name -StartupType $StartupType
        Write-Info "Startup type set to: $StartupType"
    }
    
    # Configure service account
    if ($ServiceAccount -ne 'LocalSystem') {
        Write-Info "Configuring service account: $ServiceAccount"
        
        try {
            if ($ServicePassword) {
                $credential = New-Object System.Management.Automation.PSCredential($ServiceAccount, $ServicePassword)
                Set-Service -Name $Script:ServiceConfig.Name -Credential $credential
            } else {
                # For built-in accounts
                $serviceWmi = Get-WmiObject -Class Win32_Service -Filter "Name='$($Script:ServiceConfig.Name)'"
                $serviceWmi.Change($null, $null, $null, $null, $null, $null, $ServiceAccount, $null) | Out-Null
            }
            Write-Success "Service account configured"
        } catch {
            Write-Warning "Could not configure service account: $($_.Exception.Message)"
        }
    }
    
    # Start service if requested
    if ($AutoStart) {
        Write-Info "Starting service..."
        Start-Service -Name $Script:ServiceConfig.Name
        
        # Wait for service to start
        $timeout = 30
        $elapsed = 0
        do {
            Start-Sleep -Seconds 2
            $elapsed += 2
            $service = Get-Service -Name $Script:ServiceConfig.Name
        } while ($service.Status -ne 'Running' -and $elapsed -lt $timeout)
        
        if ($service.Status -eq 'Running') {
            Write-Success "Service started successfully"
        } else {
            Write-Warning "Service did not start within $timeout seconds"
        }
    }
    
    # Display installation summary
    Write-Host "`n🎉 Service Installation Summary:" -ForegroundColor Green
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Gray
    Write-Host "Service Name: $($Script:ServiceConfig.Name)" -ForegroundColor White
    Write-Host "Display Name: $($Script:ServiceConfig.DisplayName)" -ForegroundColor White
    Write-Host "Startup Type: $StartupType" -ForegroundColor White
    Write-Host "Service Account: $ServiceAccount" -ForegroundColor White
    Write-Host "Configuration: $($Script:ServiceConfig.ConfigPath)" -ForegroundColor White
    Write-Host "Log Directory: $($Script:ServiceConfig.LogPath)" -ForegroundColor White
    Write-Host "`n💡 Management Commands:" -ForegroundColor Cyan
    Write-Host "  Start Service:    net start $($Script:ServiceConfig.Name)" -ForegroundColor White
    Write-Host "  Stop Service:     net stop $($Script:ServiceConfig.Name)" -ForegroundColor White
    Write-Host "  Service Status:   sc query $($Script:ServiceConfig.Name)" -ForegroundColor White
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Gray
}

function Uninstall-Service {
    Write-Info "Uninstalling MCP Ghidra5 Windows Service..."
    
    # Check if service exists
    $service = Get-Service -Name $Script:ServiceConfig.Name -ErrorAction SilentlyContinue
    if (-not $service) {
        Write-Warning "Service '$($Script:ServiceConfig.Name)' not found"
        return
    }
    
    # Stop service if running
    if ($service.Status -eq 'Running') {
        Write-Info "Stopping service..."
        Stop-Service -Name $Script:ServiceConfig.Name -Force
        
        # Wait for service to stop
        $timeout = 30
        $elapsed = 0
        do {
            Start-Sleep -Seconds 2
            $elapsed += 2
            $service = Get-Service -Name $Script:ServiceConfig.Name
        } while ($service.Status -eq 'Running' -and $elapsed -lt $timeout)
        
        if ($service.Status -eq 'Stopped') {
            Write-Success "Service stopped"
        } else {
            Write-Warning "Service did not stop within $timeout seconds"
        }
    }
    
    # Remove service using Python script
    Write-Info "Removing Windows service..."
    
    $result = & python $Script:ServiceConfig.BinaryPath uninstall 2>&1
    
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "Service removal may have failed: $result"
        
        # Fallback: try sc.exe
        Write-Info "Attempting removal with sc.exe..."
        $result = & sc.exe delete $Script:ServiceConfig.Name
        
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to remove service: $result"
        }
    }
    
    Write-Success "Service removed successfully"
    
    # Remove data if requested
    if ($RemoveData) {
        Write-Info "Removing service data..."
        
        $dataDirectories = @(
            (Split-Path $Script:ServiceConfig.ConfigPath -Parent),
            $Script:ServiceConfig.LogPath
        )
        
        foreach ($dir in $dataDirectories) {
            if (Test-Path $dir) {
                Remove-Item $dir -Recurse -Force -ErrorAction SilentlyContinue
                Write-Info "Removed directory: $dir"
            }
        }
        
        Write-Success "Service data removed"
    }
}

function Get-ServiceStatus {
    Write-Info "Checking service status..."
    
    $service = Get-Service -Name $Script:ServiceConfig.Name -ErrorAction SilentlyContinue
    
    if (-not $service) {
        $status = @{
            ServiceInstalled = $false
            ServiceRunning = $false
            Status = "Not Installed"
        }
    } else {
        $status = @{
            ServiceInstalled = $true
            ServiceRunning = $service.Status -eq 'Running'
            Status = $service.Status
            Name = $service.Name
            DisplayName = $service.DisplayName
            StartType = $service.StartType
            ServiceType = $service.ServiceType
        }
        
        # Get process information if running
        if ($service.Status -eq 'Running') {
            try {
                $serviceProcess = Get-WmiObject -Class Win32_Service -Filter "Name='$($service.Name)'"
                if ($serviceProcess -and $serviceProcess.ProcessId) {
                    $process = Get-Process -Id $serviceProcess.ProcessId -ErrorAction SilentlyContinue
                    if ($process) {
                        $status.ProcessId = $process.Id
                        $status.StartTime = $process.StartTime
                        $status.WorkingSet = [math]::Round($process.WorkingSet64 / 1MB, 2)
                        $status.CPUTime = $process.TotalProcessorTime
                    }
                }
            } catch {
                Write-Verbose "Could not get process information"
            }
        }
    }
    
    if ($JSON) {
        return $status | ConvertTo-Json -Depth 3
    } else {
        # Display formatted output
        $statusIcon = if ($status.ServiceRunning) { "🟢" } else { "🔴" }
        
        Write-Host "`n$statusIcon MCP Ghidra5 Service Status" -ForegroundColor $(if ($status.ServiceRunning) { 'Green' } else { 'Red' })
        Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Gray
        
        if ($status.ServiceInstalled) {
            Write-Host "🔧 Service Information:" -ForegroundColor Cyan
            Write-Host "  Name: $($status.Name)" -ForegroundColor White
            Write-Host "  Display Name: $($status.DisplayName)" -ForegroundColor White
            Write-Host "  Status: $($status.Status)" -ForegroundColor $(if ($status.ServiceRunning) { 'Green' } else { 'Red' })
            Write-Host "  Start Type: $($status.StartType)" -ForegroundColor White
            
            if ($status.ServiceRunning -and $status.ProcessId) {
                Write-Host "`n💾 Process Information:" -ForegroundColor Cyan
                Write-Host "  Process ID: $($status.ProcessId)" -ForegroundColor White
                Write-Host "  Start Time: $($status.StartTime)" -ForegroundColor White
                Write-Host "  Memory Usage: $($status.WorkingSet) MB" -ForegroundColor White
                Write-Host "  CPU Time: $($status.CPUTime)" -ForegroundColor White
            }
        } else {
            Write-Host "❌ Service is not installed" -ForegroundColor Red
        }
        
        Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Gray
        
        return $status
    }
}

function Start-ServiceMonitoring {
    Write-Info "Starting service monitoring (Press Ctrl+C to stop)..."
    
    $monitoringActive = $true
    $lastCheck = Get-Date
    
    # Set up Ctrl+C handler
    [Console]::TreatControlCAsInput = $false
    [Console]::CancelKeyPress += {
        param($sender, $e)
        $e.Cancel = $true
        $script:monitoringActive = $false
        Write-Host "`nMonitoring stopped by user" -ForegroundColor Yellow
    }
    
    try {
        while ($monitoringActive) {
            $currentTime = Get-Date
            
            # Clear previous output
            if ($Host.Name -eq 'ConsoleHost') {
                Clear-Host
            }
            
            Write-Host "🔍 MCP Ghidra5 Service Monitor" -ForegroundColor Magenta
            Write-Host "Last Update: $($currentTime.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor Gray
            Write-Host "Press Ctrl+C to stop monitoring`n" -ForegroundColor Gray
            
            # Get service status
            $status = Get-ServiceStatus
            
            if ($status.ServiceInstalled -and $status.ServiceRunning) {
                # Additional monitoring for running service - Process-based health check
                $serverHealthy = $false
                if ($status.ProcessId) {
                    try {
                        $process = Get-Process -Id $status.ProcessId -ErrorAction SilentlyContinue
                        if ($process -and !$process.HasExited) {
                            $serverHealthy = $true
                            $uptimeHours = [math]::Round(((Get-Date) - $process.StartTime).TotalHours, 2)
                            Write-Host "🌐 Server Process: ✅ Running (PID: $($process.Id), Uptime: $uptimeHours hrs)" -ForegroundColor Green
                        } else {
                            Write-Host "🌐 Server Process: ❌ Process not found or exited" -ForegroundColor Red
                        }
                    } catch {
                        Write-Host "🌐 Server Process: ❌ Not accessible or terminated" -ForegroundColor Red
                    }
                } else {
                    Write-Host "🌐 Server Process: ❌ No process ID available" -ForegroundColor Red
                }
                
                # Check log file
                $logFile = Join-Path $Script:ServiceConfig.LogPath "service.log"
                if (Test-Path $logFile) {
                    $logInfo = Get-Item $logFile
                    Write-Host "📝 Log File: $($logInfo.Length) bytes (Modified: $($logInfo.LastWriteTime.ToString('HH:mm:ss')))" -ForegroundColor Cyan
                }
            }
            
            Write-Host "`nNext check in $WatchInterval seconds..." -ForegroundColor Gray
            
            # Wait for the specified interval
            $elapsed = 0
            while ($elapsed -lt $WatchInterval -and $monitoringActive) {
                Start-Sleep -Seconds 1
                $elapsed++
            }
        }
    } finally {
        [Console]::TreatControlCAsInput = $false
    }
}

# Main execution logic
try {
    Write-Host "🔧 MCP-Ghidra5 - Enterprise Service Management" -ForegroundColor Magenta
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Gray
    Write-Host "Action: $Action" -ForegroundColor White
    Write-Host "Log File: $Script:LogFile" -ForegroundColor Gray
    Write-Host ""
    
    # Initialize log file
    "MCP Ghidra5 Service Management Log" | Out-File -FilePath $Script:LogFile -Encoding UTF8
    "Started: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" | Add-Content -Path $Script:LogFile
    "Action: $Action" | Add-Content -Path $Script:LogFile
    
    switch ($Action) {
        'Install' {
            Test-Prerequisites
            Install-Service
        }
        'Uninstall' {
            Test-Prerequisites
            Uninstall-Service
        }
        'Start' {
            Write-Info "Starting service..."
            Start-Service -Name $Script:ServiceConfig.Name
            Write-Success "Service start command issued"
        }
        'Stop' {
            Write-Info "Stopping service..."
            Stop-Service -Name $Script:ServiceConfig.Name -Force
            Write-Success "Service stop command issued"
        }
        'Restart' {
            Write-Info "Restarting service..."
            Restart-Service -Name $Script:ServiceConfig.Name -Force
            Write-Success "Service restart command issued"
        }
        'Status' {
            Get-ServiceStatus | Out-Null
        }
        'Monitor' {
            Start-ServiceMonitoring
        }
        'Health' {
            Write-Info "Performing health check..."
            $status = Get-ServiceStatus
            
            if ($status.ServiceRunning) {
                Write-Success "Service is running"
                
                # Process-based health check (MCP server uses stdio, not HTTP)
                if ($status.ProcessId) {
                    try {
                        $process = Get-Process -Id $status.ProcessId -ErrorAction SilentlyContinue
                        if ($process -and !$process.HasExited) {
                            $uptimeHours = [math]::Round(((Get-Date) - $process.StartTime).TotalHours, 2)
                            Write-Success "Server process healthy (PID: $($process.Id), Uptime: $uptimeHours hours)"
                        } else {
                            Write-Warning "Server process not found or has exited"
                        }
                    } catch {
                        Write-Warning "Could not access server process: $($_.Exception.Message)"
                    }
                } else {
                    Write-Warning "No server process ID available"
                }
            } else {
                Write-Warning "Service is not running"
            }
        }
        default {
            throw "Unknown action: $Action"
        }
    }
    
    Write-Host "`n✅ Operation completed successfully" -ForegroundColor Green
    
} catch {
    Write-Error "Operation failed: $($_.Exception.Message)"
    Write-Host "`nFor more details, check the log file: $Script:LogFile" -ForegroundColor Gray
    exit 1
} finally {
    "Completed: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" | Add-Content -Path $Script:LogFile -ErrorAction SilentlyContinue
}