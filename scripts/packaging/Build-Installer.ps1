#Requires -Version 5.1
#Requires -RunAsAdministrator

<#
.SYNOPSIS
    TechSquad MCP Ghidra5 - Installer Build Script
    Automated compilation and packaging system

.DESCRIPTION
    Complete build automation for TechSquad MCP Ghidra5 Windows installer
    - MSI package compilation
    - Bundle bootstrapper creation
    - Code signing and validation
    - Distribution package generation

.PARAMETER Configuration
    Build configuration (Debug or Release)

.PARAMETER Platform
    Target platform (x64, x86, or Both)

.PARAMETER SkipSigning
    Skip code signing process

.PARAMETER CreatePortable
    Create portable ZIP package

.PARAMETER OutputPath
    Custom output directory for distribution files

.PARAMETER Clean
    Clean build artifacts before compilation

.EXAMPLE
    .\Build-Installer.ps1 -Configuration Release -Platform x64

.EXAMPLE
    .\Build-Installer.ps1 -Configuration Debug -Clean -CreatePortable

.NOTES
    Copyright (c) 2024 TechSquad Inc. - All Rights Reserved
    
    Prerequisites:
    - WiX Toolset v3.11 or later
    - Visual Studio Build Tools or MSBuild
    - Code signing certificate (for Release builds)
    - Administrator privileges
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [ValidateSet("Debug", "Release")]
    [string]$Configuration = "Debug",
    
    [Parameter(Mandatory = $false)]
    [ValidateSet("x64", "x86", "Both")]
    [string]$Platform = "x64",
    
    [Parameter(Mandatory = $false)]
    [switch]$SkipSigning,
    
    [Parameter(Mandatory = $false)]
    [switch]$CreatePortable,
    
    [Parameter(Mandatory = $false)]
    [string]$OutputPath,
    
    [Parameter(Mandatory = $false)]
    [switch]$Clean
)

# Script configuration
$ErrorActionPreference = "Stop"
$Script:ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$Script:ProjectRoot = Split-Path -Parent $Script:ScriptRoot
$Script:LogFile = Join-Path $Script:ScriptRoot "build-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"

# Color functions for output
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

# Build environment validation
function Test-BuildEnvironment {
    Write-Info "Validating build environment..."
    
    # Check WiX Toolset
    $wixPath = Get-ItemProperty -Path "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*" |
        Where-Object { $_.DisplayName -like "*WiX Toolset*" } | 
        Select-Object -First 1
    
    if (-not $wixPath) {
        throw "WiX Toolset not found. Please install WiX Toolset v3.11 or later from https://wixtoolset.org/"
    }
    
    $env:WIX = (Get-ItemProperty -Path "HKLM:\SOFTWARE\WOW6432Node\WiX Toolset v3.11" -Name InstallRoot -ErrorAction SilentlyContinue).InstallRoot
    if (-not $env:WIX) {
        $env:WIX = "${env:ProgramFiles(x86)}\WiX Toolset v3.11\"
    }
    
    Write-Success "WiX Toolset found at: $env:WIX"
    
    # Check MSBuild
    $msbuildPath = @(
        "${env:ProgramFiles}\Microsoft Visual Studio\2022\Enterprise\MSBuild\Current\Bin\MSBuild.exe",
        "${env:ProgramFiles}\Microsoft Visual Studio\2022\Professional\MSBuild\Current\Bin\MSBuild.exe",
        "${env:ProgramFiles}\Microsoft Visual Studio\2022\Community\MSBuild\Current\Bin\MSBuild.exe",
        "${env:ProgramFiles(x86)}\Microsoft Visual Studio\2019\Enterprise\MSBuild\Current\Bin\MSBuild.exe",
        "${env:ProgramFiles(x86)}\Microsoft Visual Studio\2019\Professional\MSBuild\Current\Bin\MSBuild.exe",
        "${env:ProgramFiles(x86)}\Microsoft Visual Studio\2019\Community\MSBuild\Current\Bin\MSBuild.exe",
        "${env:ProgramFiles(x86)}\Microsoft Visual Studio\2017\BuildTools\MSBuild\15.0\Bin\MSBuild.exe"
    ) | Where-Object { Test-Path $_ } | Select-Object -First 1
    
    if (-not $msbuildPath) {
        throw "MSBuild not found. Please install Visual Studio Build Tools or Visual Studio."
    }
    
    Write-Success "MSBuild found at: $msbuildPath"
    $Script:MSBuildPath = $msbuildPath
    
    # Check source files
    $sourceFiles = @(
        "TechSquadMCPGhidra5.wxs",
        "TechSquadWixUI.wxs",
        "Bundle.wxs"
    )
    
    foreach ($file in $sourceFiles) {
        $filePath = Join-Path $Script:ScriptRoot $file
        if (-not (Test-Path $filePath)) {
            throw "Required source file not found: $file"
        }
    }
    
    Write-Success "All required source files validated"
    
    # Setup output directory
    if ($OutputPath) {
        $Script:OutputPath = $OutputPath
    } else {
        $Script:OutputPath = Join-Path $Script:ProjectRoot "dist"
    }
    
    if (-not (Test-Path $Script:OutputPath)) {
        New-Item -ItemType Directory -Path $Script:OutputPath -Force | Out-Null
    }
    
    Write-Success "Output directory ready: $Script:OutputPath"
}

# Clean build artifacts
function Clear-BuildArtifacts {
    Write-Info "Cleaning build artifacts..."
    
    $cleanPaths = @(
        "bin",
        "obj",
        "*.log",
        "*.wixpdb"
    )
    
    foreach ($pattern in $cleanPaths) {
        $items = Get-ChildItem -Path $Script:ScriptRoot -Filter $pattern -Recurse -Force -ErrorAction SilentlyContinue
        foreach ($item in $items) {
            if ($item.PSIsContainer) {
                Remove-Item -Path $item.FullName -Recurse -Force -ErrorAction SilentlyContinue
            } else {
                Remove-Item -Path $item.FullName -Force -ErrorAction SilentlyContinue
            }
        }
    }
    
    Write-Success "Build artifacts cleaned"
}

# Prepare source files
function Copy-SourceFiles {
    Write-Info "Preparing source files for packaging..."
    
    $sourceDir = Join-Path $Script:ProjectRoot "src"
    $filesDir = Join-Path $Script:ScriptRoot "files"
    
    if (-not (Test-Path $filesDir)) {
        New-Item -ItemType Directory -Path $filesDir -Force | Out-Null
    }
    
    # Copy main application files
    $sourceFiles = @{
        "ghidra_mcp_windows.py" = "ghidra_mcp_windows.py"
        "service-wrapper.py" = "service-wrapper.py"
        "requirements.txt" = "requirements.txt"
    }
    
    foreach ($file in $sourceFiles.Keys) {
        $sourcePath = Join-Path $sourceDir $file
        $destPath = Join-Path $filesDir $sourceFiles[$file]
        
        if (Test-Path $sourcePath) {
            Copy-Item -Path $sourcePath -Destination $destPath -Force
            Write-Info "Copied: $file"
        } else {
            Write-Warning "Source file not found: $file"
        }
    }
    
    # Copy scripts
    $scriptsDir = Join-Path $Script:ProjectRoot "scripts"
    $scriptFiles = @(
        "install.ps1",
        "uninstall.ps1",
        "configure.ps1"
    )
    
    foreach ($script in $scriptFiles) {
        $sourcePath = Join-Path $scriptsDir $script
        $destPath = Join-Path $filesDir $script
        
        if (Test-Path $sourcePath) {
            Copy-Item -Path $sourcePath -Destination $destPath -Force
            Write-Info "Copied script: $script"
        }
    }
    
    Write-Success "Source files prepared"
}

# Build MSI package
function Build-MSI {
    param([string]$TargetPlatform)
    
    Write-Info "Building MSI package for $TargetPlatform..."
    
    $msiProjectPath = Join-Path $Script:ScriptRoot "TechSquadMCPGhidra5.wixproj"
    
    $buildArgs = @(
        "`"$msiProjectPath`"",
        "/p:Configuration=$Configuration",
        "/p:Platform=$TargetPlatform",
        "/p:OutputPath=`"$(Join-Path $Script:ScriptRoot "bin\$Configuration\")`"",
        "/m",
        "/v:normal"
    )
    
    if ($SkipSigning) {
        $buildArgs += "/p:CODESIGN_PASSWORD="
    }
    
    $buildCmd = "& `"$Script:MSBuildPath`" " + ($buildArgs -join " ")
    
    try {
        Invoke-Expression $buildCmd
        
        $msiPath = Join-Path $Script:ScriptRoot "bin\$Configuration\TechSquadMCPGhidra5.msi"
        if (Test-Path $msiPath) {
            Write-Success "MSI package built successfully: $msiPath"
            return $msiPath
        } else {
            throw "MSI package was not created"
        }
    } catch {
        Write-Error "MSI build failed: $($_.Exception.Message)"
        throw
    }
}

# Build Bundle bootstrapper
function Build-Bundle {
    param([string]$TargetPlatform)
    
    Write-Info "Building Bundle bootstrapper for $TargetPlatform..."
    
    $bundleProjectPath = Join-Path $Script:ScriptRoot "TechSquadMCPGhidra5Bundle.wixproj"
    
    $buildArgs = @(
        "`"$bundleProjectPath`"",
        "/p:Configuration=$Configuration",
        "/p:Platform=$TargetPlatform",
        "/p:OutputPath=`"$(Join-Path $Script:ScriptRoot "bin\$Configuration\")`"",
        "/m",
        "/v:normal"
    )
    
    if ($SkipSigning) {
        $buildArgs += "/p:CODESIGN_PASSWORD="
    }
    
    $buildCmd = "& `"$Script:MSBuildPath`" " + ($buildArgs -join " ")
    
    try {
        Invoke-Expression $buildCmd
        
        $bundlePath = Join-Path $Script:ScriptRoot "bin\$Configuration\TechSquadMCPGhidra5Setup.exe"
        if (Test-Path $bundlePath) {
            Write-Success "Bundle bootstrapper built successfully: $bundlePath"
            return $bundlePath
        } else {
            throw "Bundle bootstrapper was not created"
        }
    } catch {
        Write-Error "Bundle build failed: $($_.Exception.Message)"
        throw
    }
}

# Create portable package
function New-PortablePackage {
    param([string]$SetupPath)
    
    Write-Info "Creating portable package..."
    
    $portableDir = Join-Path $Script:ScriptRoot "bin\$Configuration\Portable"
    if (Test-Path $portableDir) {
        Remove-Item -Path $portableDir -Recurse -Force
    }
    New-Item -ItemType Directory -Path $portableDir -Force | Out-Null
    
    # Copy setup executable
    Copy-Item -Path $SetupPath -Destination $portableDir -Force
    
    # Copy documentation
    $docs = @("README.md", "CHANGELOG.md", "LICENSE")
    foreach ($doc in $docs) {
        $docPath = Join-Path $Script:ProjectRoot $doc
        if (Test-Path $docPath) {
            Copy-Item -Path $docPath -Destination $portableDir -Force
        }
    }
    
    # Create ZIP archive
    $zipPath = Join-Path $Script:OutputPath "TechSquadMCPGhidra5-$Configuration-Portable.zip"
    if (Test-Path $zipPath) {
        Remove-Item -Path $zipPath -Force
    }
    
    Compress-Archive -Path "$portableDir\*" -DestinationPath $zipPath -CompressionLevel Optimal
    
    Write-Success "Portable package created: $zipPath"
    return $zipPath
}

# Validate installer packages
function Test-InstallerPackages {
    param([array]$Packages)
    
    Write-Info "Validating installer packages..."
    
    foreach ($package in $Packages) {
        if (-not (Test-Path $package)) {
            throw "Package not found: $package"
        }
        
        # Check file size
        $fileInfo = Get-Item $package
        if ($fileInfo.Length -lt 1MB) {
            Write-Warning "Package seems too small: $($fileInfo.Name) ($($fileInfo.Length) bytes)"
        }
        
        # Check digital signature (if not skipped)
        if (-not $SkipSigning -and $Configuration -eq "Release") {
            try {
                $signature = Get-AuthenticodeSignature -FilePath $package
                if ($signature.Status -ne "Valid") {
                    Write-Warning "Package signature status: $($signature.Status) for $($fileInfo.Name)"
                } else {
                    Write-Success "Package signature valid: $($fileInfo.Name)"
                }
            } catch {
                Write-Warning "Could not verify signature for: $($fileInfo.Name)"
            }
        }
        
        Write-Success "Package validated: $($fileInfo.Name) ($([math]::Round($fileInfo.Length / 1MB, 2)) MB)"
    }
}

# Copy to distribution directory
function Copy-ToDistribution {
    param([array]$Packages)
    
    Write-Info "Copying packages to distribution directory..."
    
    foreach ($package in $Packages) {
        $fileName = Split-Path -Leaf $package
        $destPath = Join-Path $Script:OutputPath $fileName
        
        Copy-Item -Path $package -Destination $destPath -Force
        Write-Success "Copied to distribution: $fileName"
        
        # Create checksum file
        $hash = Get-FileHash -Path $destPath -Algorithm SHA256
        $checksumFile = "$destPath.sha256"
        "$($hash.Hash.ToLower())  $fileName" | Out-File -FilePath $checksumFile -Encoding ASCII
        Write-Info "Created checksum: $(Split-Path -Leaf $checksumFile)"
    }
}

# Generate build report
function New-BuildReport {
    param([array]$Packages)
    
    Write-Info "Generating build report..."
    
    $reportPath = Join-Path $Script:OutputPath "BuildReport-$(Get-Date -Format 'yyyyMMdd-HHmmss').txt"
    
    $report = @"
TechSquad MCP Ghidra5 Windows Installer - Build Report
======================================================

Build Information:
- Configuration: $Configuration
- Platform: $Platform
- Build Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
- Build Host: $env:COMPUTERNAME
- Build User: $env:USERNAME

Packages Generated:
"@
    
    foreach ($package in $Packages) {
        $fileInfo = Get-Item $package
        $hash = Get-FileHash -Path $package -Algorithm SHA256
        
        $report += @"

- File: $($fileInfo.Name)
  Size: $([math]::Round($fileInfo.Length / 1MB, 2)) MB
  SHA256: $($hash.Hash)
  Created: $($fileInfo.CreationTime)
"@
    }
    
    $report += @"

Build Environment:
- WiX Toolset: $env:WIX
- MSBuild: $Script:MSBuildPath
- PowerShell: $($PSVersionTable.PSVersion)
- .NET Framework: $([System.Runtime.InteropServices.RuntimeInformation]::FrameworkDescription)

Build Log Location: $Script:LogFile
"@
    
    $report | Out-File -FilePath $reportPath -Encoding UTF8
    Write-Success "Build report generated: $reportPath"
}

# Main build process
function Start-Build {
    try {
        Write-Info "Starting TechSquad MCP Ghidra5 installer build..."
        Write-Info "Configuration: $Configuration, Platform: $Platform"
        
        # Initialize build log
        "TechSquad MCP Ghidra5 Installer Build Log" | Out-File -FilePath $Script:LogFile -Encoding UTF8
        "Started: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" | Add-Content -Path $Script:LogFile
        "Configuration: $Configuration" | Add-Content -Path $Script:LogFile
        "Platform: $Platform" | Add-Content -Path $Script:LogFile
        
        # Validate environment
        Test-BuildEnvironment
        
        # Clean if requested
        if ($Clean) {
            Clear-BuildArtifacts
        }
        
        # Prepare source files
        Copy-SourceFiles
        
        # Determine platforms to build
        $platforms = if ($Platform -eq "Both") { @("x64", "x86") } else { @($Platform) }
        
        $allPackages = @()
        
        foreach ($targetPlatform in $platforms) {
            Write-Info "Building for platform: $targetPlatform"
            
            # Build MSI
            $msiPath = Build-MSI -TargetPlatform $targetPlatform
            $allPackages += $msiPath
            
            # Build Bundle
            $bundlePath = Build-Bundle -TargetPlatform $targetPlatform
            $allPackages += $bundlePath
            
            # Create portable package if requested
            if ($CreatePortable) {
                $portablePath = New-PortablePackage -SetupPath $bundlePath
                $allPackages += $portablePath
            }
        }
        
        # Validate packages
        Test-InstallerPackages -Packages $allPackages
        
        # Copy to distribution
        Copy-ToDistribution -Packages $allPackages
        
        # Generate build report
        New-BuildReport -Packages $allPackages
        
        Write-Success "Build completed successfully!"
        Write-Info "Distribution packages available in: $Script:OutputPath"
        Write-Info "Build log saved to: $Script:LogFile"
        
    } catch {
        Write-Error "Build failed: $($_.Exception.Message)"
        Write-Error "Stack trace: $($_.ScriptStackTrace)"
        exit 1
    }
}

# Script entry point
if ($MyInvocation.InvocationName -ne '.') {
    Start-Build
}