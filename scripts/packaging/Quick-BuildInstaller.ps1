#Requires -Version 5.1

<#
.SYNOPSIS
    Quick MCP-Ghidra5 Installer Build and Test Script

.DESCRIPTION
    Simplified build script for development and testing of the MSI installer.
    This script simulates the installer build process without requiring WiX Toolset
    and creates a mock installer structure for validation.

.EXAMPLE
    .\Quick-BuildInstaller.ps1

.NOTES
    This is a development/testing script. For production builds, use Build-MCPGhidra5Installer.ps1
    with proper WiX Toolset installation.
#>

[CmdletBinding()]
param(
    [string]$OutputPath = "build",
    [switch]$DetailedOutput
)

$ErrorActionPreference = "Stop"
$Script:ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$Script:ProjectRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $Script:ScriptRoot))

function Write-TestInfo {
    param([string]$Message)
    Write-Host "ℹ️  $Message" -ForegroundColor Cyan
}

function Write-TestSuccess {
    param([string]$Message)  
    Write-Host "✅ $Message" -ForegroundColor Green
}

function Write-TestWarning {
    param([string]$Message)
    Write-Host "⚠️  $Message" -ForegroundColor Yellow
}

function Test-ProjectStructure {
    Write-TestInfo "Validating project structure for installer build..."
    
    $requiredFiles = @(
        "$Script:ProjectRoot\src\mcp_ghidra_server_windows.py",
        "$Script:ProjectRoot\src\ghidra_gpt5_mcp.py",
        "$Script:ProjectRoot\src\config\service.conf",
        "$Script:ProjectRoot\scripts\service\mcp_ghidra5_service.py",
        "$Script:ProjectRoot\scripts\service\Install-MCPGhidra5Service.ps1",
        "$Script:ProjectRoot\scripts\service\Manage-MCPGhidra5Service.ps1",
        "$Script:ProjectRoot\README.md",
        "$Script:ProjectRoot\docs\DEPLOYMENT_GUIDE.md"
    )
    
    $missingFiles = @()
    $foundFiles = @()
    
    foreach ($file in $requiredFiles) {
        if (Test-Path $file) {
            $foundFiles += $file
        } else {
            $missingFiles += $file
        }
    }
    
    Write-TestSuccess "Found $($foundFiles.Count) required files"
    
    if ($missingFiles.Count -gt 0) {
        Write-TestWarning "Missing files:"
        foreach ($missing in $missingFiles) {
            Write-Host "  - $missing" -ForegroundColor Red
        }
    }
    
    return $missingFiles.Count -eq 0
}

function Test-WixConfiguration {
    Write-TestInfo "Validating WiX installer configuration..."
    
    $wixFile = Join-Path $Script:ScriptRoot "MCPGhidra5WindowsInstaller.wxs"
    $customUIFile = Join-Path $Script:ScriptRoot "MCPGhidraCustomUI.wxs"
    
    if (-not (Test-Path $wixFile)) {
        Write-TestWarning "Main WiX file not found: $wixFile"
        return $false
    }
    
    if (-not (Test-Path $customUIFile)) {
        Write-TestWarning "Custom UI file not found: $customUIFile"
        return $false
    }
    
    # Basic XML validation
    try {
        [xml]$wixXml = Get-Content $wixFile
        [xml]$uiXml = Get-Content $customUIFile
        
        Write-TestSuccess "WiX configuration files are valid XML"
        
        # Check for required elements  
        $ns = New-Object System.Xml.XmlNamespaceManager($wixXml.NameTable)
        $ns.AddNamespace("wix", "http://schemas.microsoft.com/wix/2006/wi")
        $productNode = $wixXml.SelectSingleNode("//wix:Product", $ns)
        if ($productNode) {
            $productName = $productNode.GetAttribute("Name")
            $version = $productNode.GetAttribute("Version")
            Write-TestInfo "Product: $productName, Version: $version"
        }
        
        return $true
    } catch {
        Write-TestWarning "WiX configuration validation failed: $($_.Exception.Message)"
        return $false
    }
}

function New-MockInstaller {
    param([string]$BuildPath)
    
    Write-TestInfo "Creating mock installer structure..."
    
    # Create build directories
    $dirs = @("bin", "obj", "assets", "logs")
    foreach ($dir in $dirs) {
        $fullPath = Join-Path $BuildPath $dir
        if (-not (Test-Path $fullPath)) {
            New-Item -ItemType Directory -Path $fullPath -Force | Out-Null
        }
    }
    
    # Copy assets
    $assetsSource = Join-Path $Script:ScriptRoot "assets"
    $assetsTarget = Join-Path $BuildPath "assets"
    
    if (Test-Path $assetsSource) {
        Copy-Item -Path $assetsSource -Destination $assetsTarget -Recurse -Force
        Write-TestSuccess "Assets copied to build directory"
    }
    
    # Create mock MSI file
    $mockMsiPath = Join-Path $BuildPath "bin" "MCP-Ghidra5-Windows-Setup-1.0.0.msi"
    
    # Create a simple mock MSI (just a placeholder file)
    $mockMsiContent = @"
Mock MSI Installer for MCP Ghidra5 Windows
==========================================

This is a mock installer created for development and testing purposes.

Product: MCP Ghidra5 Windows Enterprise Edition
Version: 1.0.0
Build Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')

Features:
- Windows Service Integration
- PowerShell Management Tools  
- Enterprise Registry Configuration
- Professional Installation UI
- Dependency Detection and Installation

For a real installer, use the Build-MCPGhidra5Installer.ps1 script
with WiX Toolset installed.

Installation Commands (for real MSI):
  Interactive: msiexec /i "MCP-Ghidra5-Windows-Setup-1.0.0.msi"
  Silent: msiexec /i "MCP-Ghidra5-Windows-Setup-1.0.0.msi" /quiet /l*v install.log
  Uninstall: msiexec /x "MCP-Ghidra5-Windows-Setup-1.0.0.msi" /quiet

Contact: support@techsquad.com
Website: https://techsquad.com
"@
    
    $mockMsiContent | Out-File -FilePath $mockMsiPath -Encoding UTF8
    
    Write-TestSuccess "Mock MSI installer created: $mockMsiPath"
    
    return $mockMsiPath
}

function Test-ServiceScripts {
    Write-TestInfo "Validating PowerShell service scripts..."
    
    $serviceScripts = @(
        "$Script:ProjectRoot\scripts\service\Install-MCPGhidra5Service.ps1",
        "$Script:ProjectRoot\scripts\service\Manage-MCPGhidra5Service.ps1"
    )
    
    $allValid = $true
    
    foreach ($script in $serviceScripts) {
        if (Test-Path $script) {
            try {
                # Basic syntax check
                $null = [System.Management.Automation.PSParser]::Tokenize((Get-Content $script -Raw), [ref]$null)
                Write-TestSuccess "Script syntax valid: $(Split-Path $script -Leaf)"
            } catch {
                Write-TestWarning "Script syntax issue in $(Split-Path $script -Leaf): $($_.Exception.Message)"
                $allValid = $false
            }
        } else {
            Write-TestWarning "Service script not found: $script"
            $allValid = $false
        }
    }
    
    return $allValid
}

function Show-InstallationSummary {
    param([string]$InstallerPath)
    
    Write-Host ""
    Write-Host "🎉 Mock Installer Build Summary:" -ForegroundColor Green
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Gray
    Write-Host "Product: MCP Ghidra5 Windows Enterprise Edition" -ForegroundColor White  
    Write-Host "Version: 1.0.0" -ForegroundColor White
    Write-Host "Output: $InstallerPath" -ForegroundColor White
    Write-Host "Size: $([math]::Round((Get-Item $InstallerPath).Length / 1KB, 2)) KB (Mock)" -ForegroundColor White
    Write-Host "Type: Development Mock Installer" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "📋 Installer Features Configured:" -ForegroundColor Cyan
    Write-Host "  ✅ Windows Service Integration" -ForegroundColor White
    Write-Host "  ✅ PowerShell Management Tools" -ForegroundColor White
    Write-Host "  ✅ Registry Configuration" -ForegroundColor White
    Write-Host "  ✅ Custom Installation Dialogs" -ForegroundColor White
    Write-Host "  ✅ Dependency Detection" -ForegroundColor White
    Write-Host "  ✅ Enterprise Deployment Support" -ForegroundColor White
    Write-Host ""
    Write-Host "💡 Next Steps:" -ForegroundColor Cyan
    Write-Host "  1. Install WiX Toolset for production builds" -ForegroundColor White
    Write-Host "  2. Run Build-MCPGhidra5Installer.ps1 -BuildType Release" -ForegroundColor White
    Write-Host "  3. Test installer on clean Windows system" -ForegroundColor White
    Write-Host "  4. Configure code signing for distribution" -ForegroundColor White
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Gray
}

# Main execution
try {
    Write-Host "🛠️ MCP-Ghidra5 Windows - Quick Installer Build & Test" -ForegroundColor Magenta
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Gray
    Write-Host "Mode: Development Testing" -ForegroundColor Yellow
    Write-Host "Output: $OutputPath" -ForegroundColor White
    Write-Host ""
    
    $buildPath = Join-Path $Script:ProjectRoot $OutputPath
    
    # Run validation tests
    $structureValid = Test-ProjectStructure
    $wixValid = Test-WixConfiguration
    $scriptsValid = Test-ServiceScripts
    
    if ($structureValid -and $wixValid -and $scriptsValid) {
        Write-TestSuccess "All validation tests passed!"
        
        # Create mock installer
        $installerPath = New-MockInstaller -BuildPath $buildPath
        
        Show-InstallationSummary -InstallerPath $installerPath
        
        Write-Host "✅ Mock installer build completed successfully!" -ForegroundColor Green
    } else {
        Write-TestWarning "Some validation tests failed. Review the issues above."
        Write-Host "❌ Build cannot proceed with validation errors." -ForegroundColor Red
        exit 1
    }
    
} catch {
    Write-Host "❌ Build failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}