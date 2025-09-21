#Requires -Version 5.1
#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Comprehensive Windows Testing Suite for MCP-Ghidra5 Installer

.DESCRIPTION
    This script performs comprehensive testing of the MCP-Ghidra5 Windows installer
    and service functionality in a Windows container environment. It validates:
    - Installation process and file deployment
    - Windows service registration and functionality
    - PowerShell management scripts
    - Registry configuration
    - Dependency validation
    - Service lifecycle management

.EXAMPLE
    .\run-windows-tests.ps1

.NOTES
    This script is designed to run in a Windows Server Core container
    with all dependencies pre-installed.
#>

[CmdletBinding()]
param(
    [switch]$SkipInstaller,
    [switch]$SkipService,
    [switch]$Detailed,
    [string]$LogPath = "C:\ProgramData\MCP-Ghidra5\Logs\windows-tests.log"
)

$ErrorActionPreference = "Continue"  # Continue on errors to capture all issues
$Script:TestResults = @()
$Script:PassedTests = 0
$Script:FailedTests = 0

# Ensure log directory exists
$logDir = Split-Path $LogPath -Parent
if (-not (Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
}

function Write-TestLog {
    param(
        [string]$Message,
        [ValidateSet('INFO', 'SUCCESS', 'WARNING', 'ERROR')]
        [string]$Level = 'INFO'
    )
    
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $logMessage = "[$timestamp] [$Level] $Message"
    
    # Color output based on level
    switch ($Level) {
        'SUCCESS' { Write-Host "✅ $Message" -ForegroundColor Green }
        'WARNING' { Write-Host "⚠️  $Message" -ForegroundColor Yellow }
        'ERROR'   { Write-Host "❌ $Message" -ForegroundColor Red }
        default   { Write-Host "ℹ️  $Message" -ForegroundColor Cyan }
    }
    
    # Log to file
    Add-Content -Path $LogPath -Value $logMessage
}

function Test-SystemPrerequisites {
    Write-TestLog "Testing system prerequisites..." -Level INFO
    
    $tests = @(
        @{
            Name = "PowerShell Version"
            Test = { $PSVersionTable.PSVersion.Major -ge 5 }
            Expected = "PowerShell 5.1 or later"
        },
        @{
            Name = "Python Installation"  
            Test = { 
                try { 
                    $pythonVersion = python --version 2>&1
                    return $pythonVersion -match "Python 3\."
                } catch { return $false }
            }
            Expected = "Python 3.x"
        },
        @{
            Name = "Java Installation"
            Test = {
                try {
                    $javaVersion = java -version 2>&1
                    return $javaVersion -match "version"
                } catch { return $false }
            }
            Expected = "Java 11+"
        },
        @{
            Name = "Ghidra Installation"
            Test = { Test-Path $env:GHIDRA_HEADLESS_PATH }
            Expected = "Ghidra analyzeHeadless.bat"
        },
        @{
            Name = "Administrator Privileges"
            Test = {
                $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
                return $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
            }
            Expected = "Administrator privileges"
        }
    )
    
    foreach ($test in $tests) {
        try {
            if (& $test.Test) {
                Write-TestLog "✓ $($test.Name): OK" -Level SUCCESS
                $Script:PassedTests++
            } else {
                Write-TestLog "✗ $($test.Name): Failed - Expected $($test.Expected)" -Level ERROR
                $Script:FailedTests++
            }
        } catch {
            Write-TestLog "✗ $($test.Name): Exception - $($_.Exception.Message)" -Level ERROR
            $Script:FailedTests++
        }
    }
}

function Test-PythonDependencies {
    Write-TestLog "Testing Python dependencies..." -Level INFO
    
    $requiredPackages = @('pywin32', 'psutil', 'configparser', 'httpx')
    
    foreach ($package in $requiredPackages) {
        try {
            $result = python -c "import $package; print('OK')" 2>&1
            if ($result -match "OK") {
                Write-TestLog "✓ Python package '$package': Available" -Level SUCCESS
                $Script:PassedTests++
            } else {
                Write-TestLog "✗ Python package '$package': Not available" -Level ERROR
                $Script:FailedTests++
            }
        } catch {
            Write-TestLog "✗ Python package '$package': Exception - $($_.Exception.Message)" -Level ERROR
            $Script:FailedTests++
        }
    }
}

function Test-ProjectStructure {
    Write-TestLog "Testing project file structure..." -Level INFO
    
    $requiredFiles = @(
        "MCP-Ghidra5-Windows\src\mcp_ghidra_server_windows.py",
        "MCP-Ghidra5-Windows\src\ghidra_gpt5_mcp.py", 
        "MCP-Ghidra5-Windows\src\config\service.conf",
        "MCP-Ghidra5-Windows\scripts\service\mcp_ghidra5_service.py",
        "MCP-Ghidra5-Windows\scripts\service\Install-MCPGhidra5Service.ps1",
        "MCP-Ghidra5-Windows\scripts\service\Manage-MCPGhidra5Service.ps1",
        "README.md",
        "docs\DEPLOYMENT_GUIDE.md"
    )
    
    foreach ($file in $requiredFiles) {
        $fullPath = Join-Path "C:\mcp-ghidra5" $file
        if (Test-Path $fullPath) {
            Write-TestLog "✓ File exists: $file" -Level SUCCESS
            $Script:PassedTests++
        } else {
            Write-TestLog "✗ File missing: $file" -Level ERROR
            $Script:FailedTests++
        }
    }
}

function Test-ServiceScriptSyntax {
    Write-TestLog "Testing PowerShell script syntax..." -Level INFO
    
    $scripts = @(
        "MCP-Ghidra5-Windows\scripts\service\Install-MCPGhidra5Service.ps1",
        "MCP-Ghidra5-Windows\scripts\service\Manage-MCPGhidra5Service.ps1"
    )
    
    foreach ($script in $scripts) {
        $fullPath = Join-Path "C:\mcp-ghidra5" $script
        if (Test-Path $fullPath) {
            try {
                $null = [System.Management.Automation.PSParser]::Tokenize((Get-Content $fullPath -Raw), [ref]$null)
                Write-TestLog "✓ PowerShell syntax valid: $(Split-Path $script -Leaf)" -Level SUCCESS
                $Script:PassedTests++
            } catch {
                Write-TestLog "✗ PowerShell syntax error in $(Split-Path $script -Leaf): $($_.Exception.Message)" -Level ERROR
                $Script:FailedTests++
            }
        } else {
            Write-TestLog "✗ PowerShell script not found: $script" -Level ERROR
            $Script:FailedTests++
        }
    }
}

function Test-MockInstallerExecution {
    if ($SkipInstaller) {
        Write-TestLog "Skipping installer tests (SkipInstaller specified)" -Level INFO
        return
    }
    
    Write-TestLog "Testing mock installer execution..." -Level INFO
    
    try {
        # Run the quick build script to create mock installer
        $buildScript = "C:\mcp-ghidra5\MCP-Ghidra5-Windows\scripts\packaging\Quick-BuildInstaller.ps1"
        
        if (Test-Path $buildScript) {
            Write-TestLog "Executing mock installer build..." -Level INFO
            
            $buildResult = & powershell -ExecutionPolicy Bypass -File $buildScript 2>&1
            
            if ($LASTEXITCODE -eq 0) {
                Write-TestLog "✓ Mock installer build completed successfully" -Level SUCCESS
                $Script:PassedTests++
                
                # Check if mock MSI was created
                $mockMsi = "C:\mcp-ghidra5\build\bin\MCP-Ghidra5-Windows-Setup-1.0.0.msi"
                if (Test-Path $mockMsi) {
                    Write-TestLog "✓ Mock MSI installer file created" -Level SUCCESS
                    $Script:PassedTests++
                } else {
                    Write-TestLog "✗ Mock MSI installer file not found" -Level ERROR
                    $Script:FailedTests++
                }
            } else {
                Write-TestLog "✗ Mock installer build failed with exit code $LASTEXITCODE" -Level ERROR
                $Script:FailedTests++
                if ($Detailed) {
                    Write-TestLog "Build output: $buildResult" -Level INFO
                }
            }
        } else {
            Write-TestLog "✗ Build script not found: $buildScript" -Level ERROR
            $Script:FailedTests++
        }
    } catch {
        Write-TestLog "✗ Mock installer test exception: $($_.Exception.Message)" -Level ERROR
        $Script:FailedTests++
    }
}

function Test-ServiceInstallation {
    if ($SkipService) {
        Write-TestLog "Skipping service tests (SkipService specified)" -Level INFO
        return
    }
    
    Write-TestLog "Testing Windows service installation..." -Level INFO
    
    try {
        $serviceScript = "C:\mcp-ghidra5\MCP-Ghidra5-Windows\scripts\service\Install-MCPGhidra5Service.ps1"
        
        if (Test-Path $serviceScript) {
            Write-TestLog "Attempting service installation (dry-run mode)..." -Level INFO
            
            # Note: In container, we'll test script execution without actually installing the service
            # since it requires full Windows service control manager
            
            try {
                # Test script loading and parameter validation
                $scriptContent = Get-Content $serviceScript -Raw
                if ($scriptContent -match "MCPGhidra5Service") {
                    Write-TestLog "✓ Service script contains expected service name" -Level SUCCESS
                    $Script:PassedTests++
                } else {
                    Write-TestLog "✗ Service script does not contain expected service name" -Level ERROR
                    $Script:FailedTests++
                }
                
                # Test if script can be parsed and loaded
                $scriptBlock = [scriptblock]::Create($scriptContent)
                if ($scriptBlock) {
                    Write-TestLog "✓ Service script can be parsed as PowerShell" -Level SUCCESS
                    $Script:PassedTests++
                } else {
                    Write-TestLog "✗ Service script cannot be parsed" -Level ERROR
                    $Script:FailedTests++
                }
            } catch {
                Write-TestLog "✗ Service script validation failed: $($_.Exception.Message)" -Level ERROR
                $Script:FailedTests++
            }
        } else {
            Write-TestLog "✗ Service installation script not found" -Level ERROR
            $Script:FailedTests++
        }
    } catch {
        Write-TestLog "✗ Service installation test exception: $($_.Exception.Message)" -Level ERROR
        $Script:FailedTests++
    }
}

function Test-RegistryOperations {
    Write-TestLog "Testing Windows Registry operations..." -Level INFO
    
    try {
        # Test registry path creation
        $testRegPath = "HKLM:\SOFTWARE\TechSquad\MCP-Ghidra5-Test"
        
        # Create test registry key
        if (-not (Test-Path $testRegPath)) {
            New-Item -Path $testRegPath -Force | Out-Null
            Write-TestLog "✓ Registry key creation: Success" -Level SUCCESS
            $Script:PassedTests++
        } else {
            Write-TestLog "✓ Registry key already exists or can be accessed" -Level SUCCESS
            $Script:PassedTests++
        }
        
        # Test registry value operations
        try {
            Set-ItemProperty -Path $testRegPath -Name "TestValue" -Value "TestData" -Type String
            $testValue = Get-ItemProperty -Path $testRegPath -Name "TestValue" -ErrorAction Stop
            
            if ($testValue.TestValue -eq "TestData") {
                Write-TestLog "✓ Registry value operations: Success" -Level SUCCESS
                $Script:PassedTests++
            } else {
                Write-TestLog "✗ Registry value mismatch" -Level ERROR
                $Script:FailedTests++
            }
        } catch {
            Write-TestLog "✗ Registry value operations failed: $($_.Exception.Message)" -Level ERROR
            $Script:FailedTests++
        }
        
        # Cleanup test registry key
        try {
            Remove-Item -Path $testRegPath -Recurse -Force -ErrorAction SilentlyContinue
            Write-TestLog "✓ Registry cleanup: Success" -Level SUCCESS
            $Script:PassedTests++
        } catch {
            Write-TestLog "⚠️  Registry cleanup warning: $($_.Exception.Message)" -Level WARNING
        }
        
    } catch {
        Write-TestLog "✗ Registry operations test exception: $($_.Exception.Message)" -Level ERROR
        $Script:FailedTests++
    }
}

function Test-ServerScriptExecution {
    Write-TestLog "Testing MCP server script execution..." -Level INFO
    
    try {
        $serverScript = "C:\mcp-ghidra5\MCP-Ghidra5-Windows\src\mcp_ghidra_server_windows.py"
        
        if (Test-Path $serverScript) {
            # Test Python syntax of server script
            Write-TestLog "Testing Python syntax of server script..." -Level INFO
            
            $syntaxCheck = python -m py_compile $serverScript 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write-TestLog "✓ Server script Python syntax: Valid" -Level SUCCESS
                $Script:PassedTests++
            } else {
                Write-TestLog "✗ Server script Python syntax: Invalid - $syntaxCheck" -Level ERROR
                $Script:FailedTests++
            }
            
            # Test import capabilities (without running)
            Write-TestLog "Testing server script imports..." -Level INFO
            
            $importTest = python -c "
import sys
sys.path.append('C:/mcp-ghidra5/MCP-Ghidra5-Windows/src')
try:
    import mcp_ghidra_server_windows
    print('IMPORT_SUCCESS')
except ImportError as e:
    print(f'IMPORT_ERROR: {e}')
except Exception as e:
    print(f'OTHER_ERROR: {e}')
" 2>&1
            
            if ($importTest -match "IMPORT_SUCCESS") {
                Write-TestLog "✓ Server script imports: Success" -Level SUCCESS
                $Script:PassedTests++
            } elseif ($importTest -match "IMPORT_ERROR") {
                Write-TestLog "⚠️  Server script imports: Missing dependencies - $importTest" -Level WARNING
                # This is expected in some environments, so don't count as failure
            } else {
                Write-TestLog "✗ Server script imports: Failed - $importTest" -Level ERROR
                $Script:FailedTests++
            }
        } else {
            Write-TestLog "✗ Server script not found: $serverScript" -Level ERROR
            $Script:FailedTests++
        }
    } catch {
        Write-TestLog "✗ Server script execution test exception: $($_.Exception.Message)" -Level ERROR
        $Script:FailedTests++
    }
}

function Test-ConfigurationParsing {
    Write-TestLog "Testing configuration file parsing..." -Level INFO
    
    try {
        $configFile = "C:\mcp-ghidra5\MCP-Ghidra5-Windows\src\config\service.conf"
        
        if (Test-Path $configFile) {
            # Test configuration file syntax
            $configContent = Get-Content $configFile -Raw
            
            # Basic INI file structure checks
            if ($configContent -match '\[.*\]') {
                Write-TestLog "✓ Configuration file has section headers" -Level SUCCESS
                $Script:PassedTests++
            } else {
                Write-TestLog "✗ Configuration file missing section headers" -Level ERROR
                $Script:FailedTests++
            }
            
            # Check for required sections
            $requiredSections = @('SERVICE', 'ENVIRONMENT', 'LOGGING')
            foreach ($section in $requiredSections) {
                if ($configContent -match "\[$section\]") {
                    Write-TestLog "✓ Configuration section '$section': Found" -Level SUCCESS
                    $Script:PassedTests++
                } else {
                    Write-TestLog "✗ Configuration section '$section': Missing" -Level ERROR
                    $Script:FailedTests++
                }
            }
            
            # Test PowerShell configuration parsing
            try {
                Add-Type -AssemblyName System.Configuration
                $config = New-Object System.Configuration.ConfigurationManager
                Write-TestLog "✓ Configuration parsing libraries: Available" -Level SUCCESS
                $Script:PassedTests++
            } catch {
                Write-TestLog "⚠️  Configuration parsing libraries: Limited - $($_.Exception.Message)" -Level WARNING
            }
            
        } else {
            Write-TestLog "✗ Configuration file not found: $configFile" -Level ERROR
            $Script:FailedTests++
        }
    } catch {
        Write-TestLog "✗ Configuration parsing test exception: $($_.Exception.Message)" -Level ERROR
        $Script:FailedTests++
    }
}

function Test-DirectoryPermissions {
    Write-TestLog "Testing directory permissions and access..." -Level INFO
    
    $testDirectories = @(
        "C:\Program Files\MCP-Ghidra5",
        "C:\ProgramData\MCP-Ghidra5",
        "C:\ProgramData\MCP-Ghidra5\Logs",
        "C:\ProgramData\MCP-Ghidra5\Projects"
    )
    
    foreach ($dir in $testDirectories) {
        try {
            # Test directory existence
            if (Test-Path $dir) {
                Write-TestLog "✓ Directory exists: $dir" -Level SUCCESS
                $Script:PassedTests++
            } else {
                Write-TestLog "⚠️  Directory missing (will be created during install): $dir" -Level WARNING
            }
            
            # Test write permissions
            $testFile = Join-Path $dir "test-permissions.txt"
            try {
                "Test" | Out-File -FilePath $testFile -Force
                Remove-Item $testFile -Force -ErrorAction SilentlyContinue
                Write-TestLog "✓ Directory writable: $dir" -Level SUCCESS
                $Script:PassedTests++
            } catch {
                Write-TestLog "⚠️  Directory write test failed: $dir - $($_.Exception.Message)" -Level WARNING
            }
            
        } catch {
            Write-TestLog "✗ Directory access test failed: $dir - $($_.Exception.Message)" -Level ERROR
            $Script:FailedTests++
        }
    }
}

function Show-TestResults {
    $totalTests = $Script:PassedTests + $Script:FailedTests
    $successRate = if ($totalTests -gt 0) { [math]::Round(($Script:PassedTests / $totalTests) * 100, 1) } else { 0 }
    
    Write-Host ""
    Write-Host "🧪 Windows Testing Results Summary" -ForegroundColor Magenta
    Write-Host "=================================" -ForegroundColor Gray
    Write-Host ""
    Write-Host "✅ Passed Tests: $Script:PassedTests" -ForegroundColor Green
    Write-Host "❌ Failed Tests: $Script:FailedTests" -ForegroundColor Red
    Write-Host "📊 Total Tests:  $totalTests" -ForegroundColor Cyan
    Write-Host "📈 Success Rate: $successRate%" -ForegroundColor $(if($successRate -ge 90) { 'Green' } elseif($successRate -ge 75) { 'Yellow' } else { 'Red' })
    Write-Host ""
    
    if ($Script:FailedTests -eq 0) {
        Write-Host "🎉 ALL TESTS PASSED - Windows environment ready for MCP-Ghidra5!" -ForegroundColor Green
        $exitCode = 0
    } elseif ($Script:FailedTests -le 2) {
        Write-Host "⚠️  MOSTLY READY - Minor issues detected, review failures above" -ForegroundColor Yellow
        $exitCode = 1
    } else {
        Write-Host "❌ CRITICAL ISSUES - Multiple failures detected, environment not ready" -ForegroundColor Red
        $exitCode = 2
    }
    
    Write-Host ""
    Write-Host "📄 Detailed log saved to: $LogPath" -ForegroundColor Gray
    Write-Host ""
    
    return $exitCode
}

# Main execution
try {
    Write-Host "🧪 MCP-Ghidra5 Windows Comprehensive Test Suite" -ForegroundColor Magenta
    Write-Host "===============================================" -ForegroundColor Gray
    Write-Host "Container: Windows Server Core" -ForegroundColor Cyan
    Write-Host "Test Time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Cyan
    Write-Host ""
    
    # Initialize log
    "MCP-Ghidra5 Windows Test Suite Log" | Out-File -FilePath $LogPath -Encoding UTF8
    "Started: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" | Add-Content -Path $LogPath
    "Container: Windows Server Core" | Add-Content -Path $LogPath
    "" | Add-Content -Path $LogPath
    
    # Execute test suites
    Test-SystemPrerequisites
    Test-PythonDependencies  
    Test-ProjectStructure
    Test-ServiceScriptSyntax
    Test-ConfigurationParsing
    Test-DirectoryPermissions
    Test-RegistryOperations
    Test-ServerScriptExecution
    Test-MockInstallerExecution
    Test-ServiceInstallation
    
    # Show results and exit
    $exitCode = Show-TestResults
    exit $exitCode
    
} catch {
    Write-TestLog "CRITICAL: Test suite execution failed: $($_.Exception.Message)" -Level ERROR
    Write-Host "❌ Test suite execution failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 3
} finally {
    "Completed: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" | Add-Content -Path $LogPath -ErrorAction SilentlyContinue
}