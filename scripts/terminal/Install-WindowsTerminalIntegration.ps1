#Requires -Version 5.1

<#
.SYNOPSIS
    TechSquad MCP Ghidra5 - Windows Terminal Integration Installer

.DESCRIPTION
    This script configures Windows Terminal with TechSquad MCP Ghidra5 integration,
    including custom profile, theme, fonts, and PowerShell enhancements.

.PARAMETER Force
    Force installation even if existing configuration is found

.PARAMETER SetAsDefault
    Set TechSquad profile as the default Windows Terminal profile

.PARAMETER InstallPowerShell7
    Download and install PowerShell 7 if not found

.PARAMETER InstallFonts
    Download and install Cascadia Code fonts

.PARAMETER ConfigOnly
    Only configure Windows Terminal, skip external installations

.EXAMPLE
    .\Install-WindowsTerminalIntegration.ps1

.EXAMPLE
    .\Install-WindowsTerminalIntegration.ps1 -Force -SetAsDefault -InstallPowerShell7 -InstallFonts

.NOTES
    Copyright (c) 2024 TechSquad Inc. - All Rights Reserved
    
    This script requires:
    - Windows 10 version 1903 or later
    - Windows Terminal installed from Microsoft Store
    - PowerShell 5.1 or later
#>

[CmdletBinding()]
param(
    [switch]$Force,
    [switch]$SetAsDefault,
    [switch]$InstallPowerShell7,
    [switch]$InstallFonts,
    [switch]$ConfigOnly
)

# Script configuration
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

# Color functions
function Write-Info {
    param([string]$Message)
    Write-Host "ℹ️  $Message" -ForegroundColor Cyan
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

# Banner
$banner = @"
🖥️  TechSquad MCP Ghidra5 - Windows Terminal Integration
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
"@

Write-Host $banner -ForegroundColor Magenta
Write-Host "Setting up professional terminal environment..." -ForegroundColor Gray
Write-Host ""

# System requirements check
Write-Info "Checking system requirements..."

# Check Windows version
$windowsVersion = [System.Environment]::OSVersion.Version
$minRequiredVersion = [Version]"10.0.18362.0"  # Windows 10 1903

if ($windowsVersion -lt $minRequiredVersion) {
    Write-Error "Windows 10 version 1903 or later is required for Windows Terminal"
    exit 1
}
Write-Success "Windows version: $($windowsVersion.ToString())"

# Check Windows Terminal installation
$wtPackage = Get-AppxPackage -Name "Microsoft.WindowsTerminal" -ErrorAction SilentlyContinue
if (-not $wtPackage) {
    Write-Error "Windows Terminal not found. Please install from Microsoft Store:"
    Write-Host "https://aka.ms/terminal" -ForegroundColor Blue
    exit 1
}
Write-Success "Windows Terminal found: $($wtPackage.Version)"

# Check PowerShell
$powershellVersions = @()
if (Get-Command powershell.exe -ErrorAction SilentlyContinue) {
    $powershellVersions += "Windows PowerShell $($PSVersionTable.PSVersion)"
}
if (Get-Command pwsh.exe -ErrorAction SilentlyContinue) {
    $ps7Version = & pwsh.exe -Command '$PSVersionTable.PSVersion.ToString()' 2>$null
    if ($ps7Version) {
        $powershellVersions += "PowerShell 7 $ps7Version"
    }
}
Write-Success "PowerShell versions: $($powershellVersions -join ', ')"

# Prerequisites installation
if (-not $ConfigOnly) {
    # Install PowerShell 7 if requested
    if ($InstallPowerShell7 -and -not (Get-Command pwsh.exe -ErrorAction SilentlyContinue)) {
        Write-Info "Installing PowerShell 7..."
        
        try {
            $downloadUrl = "https://github.com/PowerShell/PowerShell/releases/latest/download/PowerShell-7.4.0-win-x64.msi"
            $tempMsi = "$env:TEMP\PowerShell-7-x64.msi"
            
            Write-Info "Downloading PowerShell 7..."
            Invoke-WebRequest -Uri $downloadUrl -OutFile $tempMsi -UseBasicParsing
            
            Write-Info "Installing PowerShell 7 (requires administrator)..."
            $installArgs = @("/i", $tempMsi, "/quiet", "/norestart")
            $process = Start-Process -FilePath "msiexec.exe" -ArgumentList $installArgs -Wait -PassThru
            
            if ($process.ExitCode -eq 0) {
                Write-Success "PowerShell 7 installed successfully"
            } else {
                Write-Warning "PowerShell 7 installation returned exit code: $($process.ExitCode)"
            }
            
            Remove-Item $tempMsi -Force -ErrorAction SilentlyContinue
            
        } catch {
            Write-Error "Failed to install PowerShell 7: $($_.Exception.Message)"
        }
    }
    
    # Install Cascadia Code fonts if requested
    if ($InstallFonts) {
        Write-Info "Installing Cascadia Code fonts..."
        
        # Check if already installed
        $fontsKey = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts"
        $cascadiaInstalled = Get-ItemProperty -Path $fontsKey -ErrorAction SilentlyContinue | 
            Get-Member -MemberType NoteProperty | 
            Where-Object { $_.Name -like "*Cascadia*" }
        
        if ($cascadiaInstalled -and -not $Force) {
            Write-Success "Cascadia Code fonts already installed"
        } else {
            try {
                $fontUrl = "https://github.com/microsoft/cascadia-code/releases/latest/download/CascadiaCode.zip"
                $tempZip = "$env:TEMP\CascadiaCode.zip"
                $tempDir = "$env:TEMP\CascadiaCode"
                
                Write-Info "Downloading Cascadia Code fonts..."
                Invoke-WebRequest -Uri $fontUrl -OutFile $tempZip -UseBasicParsing
                
                Write-Info "Extracting fonts..."
                Expand-Archive -Path $tempZip -DestinationPath $tempDir -Force
                
                Write-Info "Installing fonts..."
                $shell = New-Object -ComObject Shell.Application
                $fontsFolder = $shell.Namespace(0x14)
                
                $ttfFonts = Get-ChildItem "$tempDir\ttf\*.ttf" -ErrorAction SilentlyContinue
                foreach ($font in $ttfFonts) {
                    try {
                        $fontsFolder.CopyHere($font.FullName, 0x10)
                        Write-Verbose "Installed font: $($font.Name)"
                    } catch {
                        Write-Verbose "Font may already be installed: $($font.Name)"
                    }
                }
                
                # Cleanup
                Remove-Item $tempZip, $tempDir -Recurse -Force -ErrorAction SilentlyContinue
                Write-Success "Cascadia Code fonts installed"
                
            } catch {
                Write-Warning "Failed to install Cascadia Code fonts: $($_.Exception.Message)"
            }
        }
    }
}

# Windows Terminal configuration
Write-Info "Configuring Windows Terminal..."

$wtSettingsPath = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"

if (-not (Test-Path $wtSettingsPath)) {
    Write-Error "Windows Terminal settings file not found at: $wtSettingsPath"
    exit 1
}

try {
    # Backup existing settings
    $backupPath = "$wtSettingsPath.backup.$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    Copy-Item $wtSettingsPath $backupPath
    Write-Info "Settings backed up to: $backupPath"
    
    # Load existing settings
    $settings = Get-Content $wtSettingsPath -Raw | ConvertFrom-Json
    Write-Info "Loaded existing Windows Terminal settings"
    
    # TechSquad profile configuration
    $techSquadGuid = "{f4a1b2c3-d4e5-f6a7-b8c9-d0e1f2a3b4c5}"
    $installPath = "${env:ProgramFiles}\TechSquad\MCP-Ghidra5"
    
    $techSquadProfile = @{
        guid = $techSquadGuid
        name = "TechSquad MCP Ghidra5"
        commandline = "powershell.exe -NoExit -ExecutionPolicy Bypass -Command `"Import-Module '$installPath\modules\TechSquadMCP.psd1' -Force; Write-Host '🚀 TechSquad MCP Ghidra5 Ready!' -ForegroundColor Green`""
        startingDirectory = $installPath
        icon = "$installPath\assets\techsquad-icon.ico"
        tabTitle = "MCP Ghidra5"
        colorScheme = "TechSquad Dark"
        fontSize = 11
        fontFace = "Cascadia Code PL"
        cursorShape = "vintage"
        cursorColor = "#00D4AA"
        backgroundImage = "$installPath\assets\background-subtle.png"
        backgroundImageOpacity = 0.05
        backgroundImageStretchMode = "uniformToFill"
        backgroundImageAlignment = "center"
        useAcrylic = $true
        acrylicOpacity = 0.85
        scrollbarState = "visible"
        snapOnInput = $true
        historySize = 10000
        closeOnExit = "graceful"
        padding = "8, 8, 8, 8"
        antialiasingMode = "cleartype"
        bellStyle = "taskbar"
        copyOnSelect = $false
        largePasteWarning = $true
        multiLinePasteWarning = $true
        tabColor = "#1E1E2E"
        unfocusedAppearance = @{
            backgroundImageOpacity = 0.02
            useAcrylic = $true
            acrylicOpacity = 0.7
        }
    }
    
    # PowerShell 7 profile (if available)
    $ps7Path = Get-Command pwsh.exe -ErrorAction SilentlyContinue
    if ($ps7Path) {
        $techSquadPS7Profile = $techSquadProfile.Clone()
        $techSquadPS7Profile.guid = "{f4a1b2c3-d4e5-f6a7-b8c9-d0e1f2a3b4c6}"
        $techSquadPS7Profile.name = "TechSquad MCP Ghidra5 (PowerShell 7)"
        $techSquadPS7Profile.commandline = "pwsh.exe -NoExit -ExecutionPolicy Bypass -Command `"Import-Module '$installPath\modules\TechSquadMCP.psd1' -Force; Write-Host '🚀 TechSquad MCP Ghidra5 Ready! (PowerShell 7)' -ForegroundColor Green`""
        $techSquadPS7Profile.tabTitle = "MCP Ghidra5 (PS7)"
    }
    
    # TechSquad color scheme
    $techSquadScheme = @{
        name = "TechSquad Dark"
        background = "#0C0C0C"
        foreground = "#CCCCCC"
        selectionBackground = "#264F78"
        cursorColor = "#00D4AA"
        black = "#0C0C0C"
        red = "#C50F1F"
        green = "#00D4AA"
        yellow = "#C19C00"
        blue = "#0078D4"
        purple = "#881798"
        cyan = "#3A96DD"
        white = "#CCCCCC"
        brightBlack = "#767676"
        brightRed = "#E74856"
        brightGreen = "#16C60C"
        brightYellow = "#F9F1A5"
        brightBlue = "#3B78FF"
        brightPurple = "#B4009E"
        brightCyan = "#61D6D6"
        brightWhite = "#F2F2F2"
    }
    
    # Update profiles
    if (-not $settings.profiles) {
        $settings | Add-Member -NotePropertyName "profiles" -NotePropertyValue @{ list = @() }
    }
    if (-not $settings.profiles.list) {
        $settings.profiles | Add-Member -NotePropertyName "list" -NotePropertyValue @()
    }
    
    # Remove existing TechSquad profiles
    $settings.profiles.list = @($settings.profiles.list | Where-Object { 
        $_.guid -ne $techSquadGuid -and $_.name -notlike "*TechSquad MCP Ghidra5*" 
    })
    
    # Add TechSquad profiles
    $settings.profiles.list += $techSquadProfile
    if ($ps7Path) {
        $settings.profiles.list += $techSquadPS7Profile
        Write-Success "Added PowerShell 7 profile"
    }
    Write-Success "Added TechSquad MCP Ghidra5 profile"
    
    # Update color schemes
    if (-not $settings.schemes) {
        $settings | Add-Member -NotePropertyName "schemes" -NotePropertyValue @()
    }
    
    # Remove existing TechSquad scheme
    $settings.schemes = @($settings.schemes | Where-Object { $_.name -ne "TechSquad Dark" })
    
    # Add TechSquad scheme
    $settings.schemes += $techSquadScheme
    Write-Success "Added TechSquad Dark color scheme"
    
    # Set as default if requested
    if ($SetAsDefault) {
        $settings.defaultProfile = $techSquadGuid
        Write-Success "Set TechSquad profile as default"
    }
    
    # Additional Windows Terminal optimizations
    if (-not $settings.copyOnSelect) {
        $settings | Add-Member -NotePropertyName "copyOnSelect" -NotePropertyValue $false -Force
    }
    if (-not $settings.copyFormatting) {
        $settings | Add-Member -NotePropertyName "copyFormatting" -NotePropertyValue @("none", "html", "rtf") -Force
    }
    if (-not $settings.wordDelimiters) {
        $settings | Add-Member -NotePropertyName "wordDelimiters" -NotePropertyValue " ./\\()\""-:,.;<>~!@#$%^&*|+=[]{}~?│" -Force
    }
    
    # Save updated settings
    $settings | ConvertTo-Json -Depth 10 | Set-Content $wtSettingsPath -Encoding UTF8
    Write-Success "Windows Terminal configuration updated"
    
} catch {
    Write-Error "Failed to configure Windows Terminal: $($_.Exception.Message)"
    exit 1
}

# PowerShell profile configuration
Write-Info "Configuring PowerShell profiles..."

$profilePaths = @()
if (Get-Command powershell.exe -ErrorAction SilentlyContinue) {
    $profilePaths += $PROFILE.CurrentUserAllHosts
}
if (Get-Command pwsh.exe -ErrorAction SilentlyContinue) {
    $ps7ProfilePath = & pwsh.exe -Command '$PROFILE.CurrentUserAllHosts' 2>$null
    if ($ps7ProfilePath) {
        $profilePaths += $ps7ProfilePath
    }
}

$profileContent = @"
# TechSquad MCP Ghidra5 - PowerShell Profile Integration
# Auto-generated on $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')

# Check if TechSquad MCP module is available
if (Test-Path '$installPath\modules\TechSquadMCP.psd1') {
    # Only auto-import if not already loaded
    if (-not (Get-Module -Name TechSquadMCP -ErrorAction SilentlyContinue)) {
        try {
            Import-Module '$installPath\modules\TechSquadMCP.psd1' -Force -Global
            Write-Host "🚀 TechSquad MCP Ghidra5 Module Loaded" -ForegroundColor Green
        } catch {
            Write-Warning "Failed to load TechSquad MCP module: `$(`$_.Exception.Message)"
        }
    }
}

# Custom prompt for TechSquad MCP
function prompt {
    `$location = Get-Location
    `$mcpStatus = "🔴"  # Default to stopped
    
    # Check if MCP status is available
    if (`$Global:MCPGhidra5Status -and `$Global:MCPGhidra5Status.ServerRunning) {
        `$mcpStatus = "🟢"
    }
    
    # Build prompt
    Write-Host "TechSquad" -NoNewline -ForegroundColor Magenta
    Write-Host " MCP " -NoNewline -ForegroundColor White
    Write-Host "`$mcpStatus " -NoNewline
    Write-Host "`$(`$location.Path)" -ForegroundColor Cyan
    return "PS> "
}

# Tab completion for MCP commands
Register-ArgumentCompleter -CommandName 'mcp-*' -ScriptBlock {
    param(`$commandName, `$parameterName, `$wordToComplete, `$commandAst, `$fakeBoundParameters)
    
    `$commands = @('start', 'stop', 'status', 'config', 'test', 'service', 'project', 'analyze', 'logs', 'update', 'backup', 'dashboard')
    `$commands | Where-Object { `$_ -like "`$wordToComplete*" } | ForEach-Object { "mcp-`$_" }
}

# Convenient aliases
Set-Alias -Name 'ghidra' -Value 'mcp-analyze' -Force -ErrorAction SilentlyContinue
Set-Alias -Name 'analyze' -Value 'mcp-analyze' -Force -ErrorAction SilentlyContinue
Set-Alias -Name 'status' -Value 'mcp-status' -Force -ErrorAction SilentlyContinue

# Welcome message (only show once per session)
if (-not `$global:TechSquadWelcomeShown) {
    Write-Host ""
    Write-Host "🎯 TechSquad MCP Ghidra5 Terminal Environment" -ForegroundColor Magenta
    Write-Host "   Type 'mcp-help' for available commands" -ForegroundColor Cyan
    Write-Host "   Type 'mcp-start' to launch the server" -ForegroundColor Green
    Write-Host ""
    `$global:TechSquadWelcomeShown = `$true
}

"@

foreach ($profilePath in $profilePaths) {
    if ($profilePath) {
        $profileDir = Split-Path $profilePath -Parent
        if (-not (Test-Path $profileDir)) {
            New-Item -ItemType Directory -Path $profileDir -Force | Out-Null
        }
        
        # Check if TechSquad content already exists
        $existingContent = ""
        if (Test-Path $profilePath) {
            $existingContent = Get-Content $profilePath -Raw -ErrorAction SilentlyContinue
        }
        
        if (-not $existingContent -or -not ($existingContent -like "*TechSquad MCP Ghidra5*") -or $Force) {
            # Add or replace TechSquad content
            if ($existingContent -and ($existingContent -like "*TechSquad MCP Ghidra5*")) {
                # Replace existing TechSquad section
                $lines = $existingContent -split "`r?`n"
                $newLines = @()
                $inTechSquadSection = $false
                
                foreach ($line in $lines) {
                    if ($line -like "*TechSquad MCP Ghidra5*") {
                        $inTechSquadSection = $true
                        continue
                    }
                    if ($inTechSquadSection -and $line.Trim() -eq "") {
                        $inTechSquadSection = $false
                        continue
                    }
                    if (-not $inTechSquadSection) {
                        $newLines += $line
                    }
                }
                
                $updatedContent = ($newLines -join "`n") + "`n`n" + $profileContent
                $updatedContent | Set-Content $profilePath -Encoding UTF8
            } else {
                # Append to existing content
                Add-Content -Path $profilePath -Value "`n$profileContent" -Encoding UTF8
            }
            
            Write-Success "Updated PowerShell profile: $profilePath"
        } else {
            Write-Info "PowerShell profile already configured: $profilePath"
        }
    }
}

# Create desktop shortcut
Write-Info "Creating desktop shortcut..."

try {
    $desktopPath = [Environment]::GetFolderPath("Desktop")
    $shortcutPath = Join-Path $desktopPath "TechSquad MCP Ghidra5.lnk"
    
    $shell = New-Object -ComObject WScript.Shell
    $shortcut = $shell.CreateShortcut($shortcutPath)
    $shortcut.TargetPath = "wt.exe"
    $shortcut.Arguments = "-p `"TechSquad MCP Ghidra5`""
    $shortcut.WorkingDirectory = $installPath
    $shortcut.IconLocation = "$installPath\assets\techsquad-icon.ico"
    $shortcut.Description = "TechSquad MCP Ghidra5 - AI-Powered Reverse Engineering"
    $shortcut.Save()
    
    Write-Success "Desktop shortcut created"
} catch {
    Write-Warning "Could not create desktop shortcut: $($_.Exception.Message)"
}

# Final verification
Write-Info "Verifying installation..."

$verification = @{
    WindowsTerminal = Test-Path $wtSettingsPath
    Profiles = $profilePaths | Where-Object { $_ -and (Test-Path $_) }
    PowerShell7 = Get-Command pwsh.exe -ErrorAction SilentlyContinue -ne $null
    Fonts = $null
}

# Check fonts
try {
    $fontsKey = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts"
    $verification.Fonts = (Get-ItemProperty -Path $fontsKey -ErrorAction SilentlyContinue | 
        Get-Member -MemberType NoteProperty | 
        Where-Object { $_.Name -like "*Cascadia*" }).Count -gt 0
} catch {
    $verification.Fonts = $false
}

# Installation summary
Write-Host "`n🎉 TechSquad MCP Ghidra5 Windows Terminal Integration Complete!" -ForegroundColor Green
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Gray

Write-Host "`n📊 Installation Summary:" -ForegroundColor Cyan
Write-Host "  ✅ Windows Terminal Profile: Configured" -ForegroundColor Green
Write-Host "  ✅ TechSquad Dark Theme: Applied" -ForegroundColor Green
Write-Host "  ✅ PowerShell Profiles: $($verification.Profiles.Count) updated" -ForegroundColor Green
Write-Host "  $(if ($verification.PowerShell7) { '✅' } else { '❌' }) PowerShell 7: $(if ($verification.PowerShell7) { 'Available' } else { 'Not Installed' })" -ForegroundColor $(if ($verification.PowerShell7) { 'Green' } else { 'Yellow' })
Write-Host "  $(if ($verification.Fonts) { '✅' } else { '❌' }) Cascadia Code Fonts: $(if ($verification.Fonts) { 'Installed' } else { 'Not Installed' })" -ForegroundColor $(if ($verification.Fonts) { 'Green' } else { 'Yellow' })

Write-Host "`n🚀 Next Steps:" -ForegroundColor Cyan
Write-Host "  1. Restart Windows Terminal to apply changes" -ForegroundColor White
Write-Host "  2. Select 'TechSquad MCP Ghidra5' profile from the dropdown" -ForegroundColor White
Write-Host "  3. Configure your OpenAI API key and Ghidra path" -ForegroundColor White
Write-Host "  4. Run 'mcp-start' to launch the server" -ForegroundColor White

Write-Host "`n💡 Quick Commands:" -ForegroundColor Yellow
Write-Host "  • Open new TechSquad tab: Ctrl+Shift+T" -ForegroundColor Gray
Write-Host "  • Check status: mcp-status" -ForegroundColor Gray
Write-Host "  • Start server: mcp-start" -ForegroundColor Gray
Write-Host "  • View help: Get-Help *MCPGhidra5*" -ForegroundColor Gray

Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Gray
Write-Host "🎯 Installation completed successfully!" -ForegroundColor Green
Write-Host ""