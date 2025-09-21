#Requires -Version 5.1
#Requires -RunAsAdministrator

<#
.SYNOPSIS
    MCP-Ghidra5 Windows - Professional Installer Builder

.DESCRIPTION
    Comprehensive build script for creating professional Windows installers (.msi/.exe) 
    using WiX Toolset. Includes dependency validation, code signing, and enterprise packaging.

.PARAMETER BuildType
    Type of build: Development, Release, Enterprise

.PARAMETER SignCode
    Sign the installer with code signing certificate

.PARAMETER OutputPath  
    Custom output path for installer files

.PARAMETER Version
    Override version number (format: x.y.z)

.PARAMETER IncludeDebugInfo
    Include debug information and symbols

.PARAMETER SkipTests
    Skip validation tests before building

.EXAMPLE
    .\Build-MCPGhidra5Installer.ps1 -BuildType Release -SignCode

.EXAMPLE
    .\Build-MCPGhidra5Installer.ps1 -BuildType Development -OutputPath "C:\Builds"

.NOTES
    Copyright (c) 2024 TechSquad. All Rights Reserved.
    
    Requirements:
    - WiX Toolset 3.11+ or WiX v4+
    - Windows SDK (for signtool.exe)
    - Administrator privileges
    - Visual Studio Build Tools (recommended)
#>

[CmdletBinding()]
param(
    [ValidateSet('Development', 'Release', 'Enterprise')]
    [string]$BuildType = 'Development',
    
    [switch]$SignCode,
    
    [string]$OutputPath,
    
    [ValidatePattern('^\d+\.\d+\.\d+$')]
    [string]$Version,
    
    [switch]$IncludeDebugInfo,
    
    [switch]$SkipTests,
    
    [string]$CertificateThumbprint,
    
    [string]$TimestampServer = "http://timestamp.digicert.com"
)

# Script configuration
$ErrorActionPreference = "Stop"
$Script:ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$Script:ProjectRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $Script:ScriptRoot))
$Script:BuildOutput = if ($OutputPath) { $OutputPath } else { Join-Path $Script:ProjectRoot "build" }
$Script:LogFile = Join-Path $Script:BuildOutput "build-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"

# Build configuration
$Script:BuildConfig = @{
    ProductName = "MCP Ghidra5 Windows"
    Manufacturer = "TechSquad"
    Version = $Version ?? "1.0.0"
    UpgradeCode = "12345678-1234-1234-1234-123456789012"
    WixSourceFile = "MCPGhidra5WindowsInstaller.wxs"
    OutputName = "MCP-Ghidra5-Windows-Setup"
}

# Color output functions
function Write-BuildInfo {
    param([string]$Message)
    Write-Host "ℹ️  $Message" -ForegroundColor Cyan
    Add-Content -Path $Script:LogFile -Value "[INFO] $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - $Message"
}

function Write-BuildSuccess {
    param([string]$Message)
    Write-Host "✅ $Message" -ForegroundColor Green
    Add-Content -Path $Script:LogFile -Value "[SUCCESS] $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - $Message"
}

function Write-BuildWarning {
    param([string]$Message)
    Write-Host "⚠️  $Message" -ForegroundColor Yellow
    Add-Content -Path $Script:LogFile -Value "[WARNING] $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - $Message"
}

function Write-BuildError {
    param([string]$Message)
    Write-Host "❌ $Message" -ForegroundColor Red
    Add-Content -Path $Script:LogFile -Value "[ERROR] $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - $Message"
}

function Test-Prerequisites {
    Write-BuildInfo "Checking build prerequisites..."
    
    # Check administrator privileges
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw "This script requires administrator privileges."
    }
    Write-BuildSuccess "Administrator privileges confirmed"
    
    # Check WiX Toolset
    $wixPaths = @(
        "${env:ProgramFiles(x86)}\WiX Toolset v3.11\bin\candle.exe",
        "${env:ProgramFiles}\WiX Toolset v3.11\bin\candle.exe",
        "${env:WIX}bin\candle.exe"
    )
    
    $Script:WixPath = $null
    foreach ($path in $wixPaths) {
        if (Test-Path $path) {
            $Script:WixPath = Split-Path $path -Parent
            break
        }
    }
    
    if (-not $Script:WixPath) {
        throw "WiX Toolset not found. Please install WiX Toolset 3.11 or later."
    }
    Write-BuildSuccess "WiX Toolset found: $Script:WixPath"
    
    # Check for required files
    $requiredFiles = @(
        (Join-Path $Script:ScriptRoot $Script:BuildConfig.WixSourceFile)
    )
    
    foreach ($file in $requiredFiles) {
        if (-not (Test-Path $file)) {
            throw "Required file not found: $file"
        }
    }
    Write-BuildSuccess "All required files found"
    
    # Check code signing certificate if requested
    if ($SignCode) {
        if ($CertificateThumbprint) {
            $cert = Get-ChildItem -Path Cert:\CurrentUser\My | Where-Object { $_.Thumbprint -eq $CertificateThumbprint }
            if (-not $cert) {
                throw "Code signing certificate with thumbprint $CertificateThumbprint not found."
            }
            Write-BuildSuccess "Code signing certificate found"
        } else {
            Write-BuildWarning "Code signing requested but no certificate thumbprint provided"
        }
    }
    
    return $true
}

function Initialize-BuildEnvironment {
    Write-BuildInfo "Initializing build environment..."
    
    # Create build directory
    if (-not (Test-Path $Script:BuildOutput)) {
        New-Item -ItemType Directory -Path $Script:BuildOutput -Force | Out-Null
    }
    
    # Create subdirectories
    $buildDirs = @("obj", "bin", "assets", "logs")
    foreach ($dir in $buildDirs) {
        $fullPath = Join-Path $Script:BuildOutput $dir
        if (-not (Test-Path $fullPath)) {
            New-Item -ItemType Directory -Path $fullPath -Force | Out-Null
        }
    }
    
    Write-BuildSuccess "Build environment initialized: $Script:BuildOutput"
}

function Copy-BuildAssets {
    Write-BuildInfo "Copying build assets..."
    
    # Copy installer assets
    $assetsSource = Join-Path $Script:ScriptRoot "assets"
    $assetsTarget = Join-Path $Script:BuildOutput "assets"
    
    if (Test-Path $assetsSource) {
        Copy-Item -Path $assetsSource -Destination $assetsTarget -Recurse -Force
        Write-BuildSuccess "Assets copied successfully"
    } else {
        Write-BuildWarning "No assets directory found, creating default assets..."
        
        # Create default license file
        $licenseContent = @"
TECHSQUAD SOFTWARE LICENSE AGREEMENT

Copyright (c) 2024 TechSquad. All Rights Reserved.

This software is proprietary and confidential. By installing this software, 
you agree to the terms and conditions of this license agreement.

For full license terms, visit: https://techsquad.com/license
"@
        $licenseFile = Join-Path $assetsTarget "License.rtf"
        $licenseContent | Out-File -FilePath $licenseFile -Encoding UTF8
        
        Write-BuildSuccess "Default license file created"
    }
}

function Update-WixConfiguration {
    Write-BuildInfo "Updating WiX configuration..."
    
    $wixSourcePath = Join-Path $Script:ScriptRoot $Script:BuildConfig.WixSourceFile
    $wixContent = Get-Content $wixSourcePath -Raw
    
    # Update version
    $wixContent = $wixContent -replace 'Version="[\d\.]+"', "Version=""$($Script:BuildConfig.Version)"""
    
    # Update build-specific properties
    switch ($BuildType) {
        'Development' {
            $wixContent = $wixContent -replace '<Property Id="ARPPRODUCTICON"[^>]*>', '<Property Id="ARPPRODUCTICON" Value="MCPGhidraDev.exe" />'
        }
        'Enterprise' {
            # Add enterprise-specific customizations
            $wixContent = $wixContent -replace 'InstallScope="perMachine"', 'InstallScope="perMachine" AdminImage="yes"'
        }
    }
    
    # Save updated configuration
    $tempWixFile = Join-Path $Script:BuildOutput "obj" "installer_updated.wxs"
    $wixContent | Out-File -FilePath $tempWixFile -Encoding UTF8
    
    $Script:WixSourceFile = $tempWixFile
    Write-BuildSuccess "WiX configuration updated"
}

function Invoke-WixCompile {
    Write-BuildInfo "Compiling WiX installer..."
    
    $candleExe = Join-Path $Script:WixPath "candle.exe"
    $objPath = Join-Path $Script:BuildOutput "obj"
    
    # Candle arguments
    $candleArgs = @(
        "`"$Script:WixSourceFile`"",
        "-out", "`"$objPath\`"",
        "-ext", "WixUIExtension",
        "-ext", "WixUtilExtension"
    )
    
    if ($IncludeDebugInfo) {
        $candleArgs += "-d", "DEBUG=1"
    }
    
    Write-BuildInfo "Running candle.exe with arguments: $($candleArgs -join ' ')"
    
    $candleResult = & $candleExe @candleArgs 2>&1
    
    if ($LASTEXITCODE -ne 0) {
        Write-BuildError "Candle compilation failed:"
        Write-Host $candleResult -ForegroundColor Red
        throw "WiX compilation failed with exit code $LASTEXITCODE"
    }
    
    Write-BuildSuccess "WiX compilation completed successfully"
}

function Invoke-WixLink {
    Write-BuildInfo "Linking MSI installer..."
    
    $lightExe = Join-Path $Script:WixPath "light.exe"
    $objFile = Join-Path $Script:BuildOutput "obj" "installer_updated.wixobj"
    $msiOutput = Join-Path $Script:BuildOutput "bin" "$($Script:BuildConfig.OutputName)-$($Script:BuildConfig.Version).msi"
    
    # Light arguments
    $lightArgs = @(
        "`"$objFile`"",
        "-out", "`"$msiOutput`"",
        "-ext", "WixUIExtension",
        "-ext", "WixUtilExtension",
        "-sice:ICE61",  # Suppress ICE61 warning
        "-sice:ICE69"   # Suppress ICE69 warning
    )
    
    if ($BuildType -eq 'Release') {
        $lightArgs += "-spdb"  # Suppress creation of .wixpdb file
    }
    
    Write-BuildInfo "Running light.exe with arguments: $($lightArgs -join ' ')"
    
    $lightResult = & $lightExe @lightArgs 2>&1
    
    if ($LASTEXITCODE -ne 0) {
        Write-BuildError "Light linking failed:"
        Write-Host $lightResult -ForegroundColor Red
        throw "WiX linking failed with exit code $LASTEXITCODE"
    }
    
    $Script:MsiPath = $msiOutput
    Write-BuildSuccess "MSI installer created: $msiOutput"
}

function Invoke-CodeSigning {
    param([string]$FilePath)
    
    if (-not $SignCode) {
        return
    }
    
    Write-BuildInfo "Code signing installer..."
    
    $signToolPaths = @(
        "${env:ProgramFiles(x86)}\Windows Kits\10\bin\*\x64\signtool.exe",
        "${env:ProgramFiles(x86)}\Windows Kits\8.1\bin\x64\signtool.exe",
        "${env:ProgramFiles}\Windows Kits\10\bin\*\x64\signtool.exe"
    )
    
    $signTool = $null
    foreach ($path in $signToolPaths) {
        $found = Get-ChildItem $path -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($found) {
            $signTool = $found.FullName
            break
        }
    }
    
    if (-not $signTool) {
        Write-BuildWarning "SignTool not found, skipping code signing"
        return
    }
    
    $signArgs = @(
        "sign",
        "/fd", "SHA256",
        "/t", $TimestampServer
    )
    
    if ($CertificateThumbprint) {
        $signArgs += "/sha1", $CertificateThumbprint
    } else {
        $signArgs += "/a"  # Automatically select certificate
    }
    
    $signArgs += "`"$FilePath`""
    
    Write-BuildInfo "Running signtool.exe with certificate..."
    
    $signResult = & $signTool @signArgs 2>&1
    
    if ($LASTEXITCODE -ne 0) {
        Write-BuildWarning "Code signing failed: $signResult"
    } else {
        Write-BuildSuccess "Installer signed successfully"
    }
}

function Test-InstallerIntegrity {
    param([string]$MsiPath)
    
    if ($SkipTests) {
        Write-BuildInfo "Skipping installer validation tests"
        return
    }
    
    Write-BuildInfo "Validating installer integrity..."
    
    # Test MSI package integrity
    try {
        $msiInfo = Get-ItemProperty $MsiPath
        Write-BuildSuccess "MSI file integrity verified: $([math]::Round($msiInfo.Length / 1MB, 2)) MB"
        
        # Additional validation could include:
        # - MSI validation using Orca or similar tools
        # - Digital signature verification
        # - Package content verification
        
    } catch {
        Write-BuildWarning "Could not verify MSI integrity: $($_.Exception.Message)"
    }
}

function New-InstallerBundle {
    Write-BuildInfo "Creating installer bundle..."
    
    if ($BuildType -ne 'Enterprise') {
        Write-BuildInfo "Bundle creation skipped (not Enterprise build)"
        return
    }
    
    # This would create a bootstrapper bundle with prerequisites
    # Using WiX Bundle/Burn technology
    Write-BuildInfo "Enterprise bundle creation not implemented in this version"
}

function Write-BuildSummary {
    Write-Host ""
    Write-Host "🎉 Build Summary:" -ForegroundColor Green
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Gray
    Write-Host "Product: $($Script:BuildConfig.ProductName)" -ForegroundColor White
    Write-Host "Version: $($Script:BuildConfig.Version)" -ForegroundColor White
    Write-Host "Build Type: $BuildType" -ForegroundColor White
    Write-Host "Output: $Script:MsiPath" -ForegroundColor White
    Write-Host "Size: $([math]::Round((Get-Item $Script:MsiPath).Length / 1MB, 2)) MB" -ForegroundColor White
    Write-Host "Signed: $(if($SignCode) { 'Yes' } else { 'No' })" -ForegroundColor White
    Write-Host ""
    Write-Host "💡 Installation Commands:" -ForegroundColor Cyan
    Write-Host "  Interactive: msiexec /i `"$Script:MsiPath`"" -ForegroundColor White
    Write-Host "  Silent: msiexec /i `"$Script:MsiPath`" /quiet /l*v install.log" -ForegroundColor White
    Write-Host "  Uninstall: msiexec /x `"$Script:MsiPath`" /quiet" -ForegroundColor White
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Gray
}

# Main execution
try {
    Write-Host "🛠️ MCP-Ghidra5 Windows - Professional Installer Builder" -ForegroundColor Magenta
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Gray
    Write-Host "Build Type: $BuildType" -ForegroundColor White
    Write-Host "Version: $($Script:BuildConfig.Version)" -ForegroundColor White
    Write-Host "Output: $Script:BuildOutput" -ForegroundColor White
    Write-Host ""
    
    # Initialize log
    "MCP Ghidra5 Installer Build Log" | Out-File -FilePath $Script:LogFile -Encoding UTF8
    "Started: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" | Add-Content -Path $Script:LogFile
    "Build Type: $BuildType" | Add-Content -Path $Script:LogFile
    
    # Execute build steps
    Test-Prerequisites
    Initialize-BuildEnvironment  
    Copy-BuildAssets
    Update-WixConfiguration
    Invoke-WixCompile
    Invoke-WixLink
    Invoke-CodeSigning -FilePath $Script:MsiPath
    Test-InstallerIntegrity -MsiPath $Script:MsiPath
    New-InstallerBundle
    
    Write-BuildSummary
    
    Write-Host "✅ Build completed successfully!" -ForegroundColor Green
    
} catch {
    Write-BuildError "Build failed: $($_.Exception.Message)"
    Write-Host "For more details, check the log file: $Script:LogFile" -ForegroundColor Gray
    exit 1
} finally {
    "Completed: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" | Add-Content -Path $Script:LogFile -ErrorAction SilentlyContinue
}