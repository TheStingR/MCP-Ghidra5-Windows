# MCP-Ghidra5 Windows - Windows Server Core Testing Container
# ============================================================
# This Dockerfile creates a Windows Server Core container for testing
# the MCP-Ghidra5 Windows installer and service functionality.
#
# Usage:
#   docker build -f Dockerfile.windows -t mcp-ghidra5-windows-test .
#   docker run -it mcp-ghidra5-windows-test

# Use Windows Server Core as base image
FROM mcr.microsoft.com/windows/servercore:ltsc2022

# Set PowerShell as default shell
SHELL ["powershell", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue';"]

# Set working directory
WORKDIR /mcp-ghidra5

# Install Chocolatey package manager
RUN Set-ExecutionPolicy Bypass -Scope Process -Force; \
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; \
    iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

# Install dependencies via Chocolatey
RUN choco install -y python --version=3.11.5 --force
RUN choco install -y openjdk11 --force  
RUN choco install -y git --force
RUN choco install -y 7zip --force

# Install PowerShell 7 (latest)
RUN choco install -y powershell-core --force

# Update PATH environment variable
RUN $env:PATH = $env:PATH + ';C:\Python311;C:\Python311\Scripts'; \
    [Environment]::SetEnvironmentVariable('PATH', $env:PATH, [EnvironmentVariableTarget]::Machine)

# Install required Python packages
RUN python -m pip install --upgrade pip
RUN python -m pip install pywin32 psutil configparser httpx asyncio pathlib

# Create directories for MCP Ghidra5
RUN New-Item -ItemType Directory -Path 'C:\Program Files\MCP-Ghidra5' -Force
RUN New-Item -ItemType Directory -Path 'C:\ProgramData\MCP-Ghidra5\Logs' -Force
RUN New-Item -ItemType Directory -Path 'C:\ProgramData\MCP-Ghidra5\Projects' -Force
RUN New-Item -ItemType Directory -Path 'C:\ProgramData\MCP-Ghidra5\Config' -Force

# Download and install Ghidra
RUN $ghidraUrl = 'https://github.com/NationalSecurityAgency/ghidra/releases/download/Ghidra_11.0_build/ghidra_11.0_PUBLIC_20231222.zip'; \
    $ghidraZip = 'C:\temp\ghidra.zip'; \
    New-Item -ItemType Directory -Path 'C:\temp' -Force; \
    Invoke-WebRequest -Uri $ghidraUrl -OutFile $ghidraZip; \
    Expand-Archive -Path $ghidraZip -DestinationPath 'C:\'; \
    Rename-Item -Path 'C:\ghidra_11.0_PUBLIC' -NewName 'C:\ghidra'; \
    Remove-Item $ghidraZip

# Set environment variables
ENV GHIDRA_HEADLESS_PATH="C:\ghidra\support\analyzeHeadless.bat"
ENV GHIDRA_PROJECT_DIR="C:\ProgramData\MCP-Ghidra5\Projects"
ENV MCP_SERVER_HOST="localhost"
ENV MCP_SERVER_PORT="8765"
ENV JAVA_HOME="C:\Program Files\Eclipse Adoptium\jdk-11.0.20.8-hotspot"

# Copy MCP-Ghidra5 project files
COPY . /mcp-ghidra5/

# Copy test scripts
COPY tests/windows-docker/test-installer.ps1 /mcp-ghidra5/test-installer.ps1
COPY tests/windows-docker/run-windows-tests.ps1 /mcp-ghidra5/run-windows-tests.ps1

# Set execution policy for PowerShell scripts
RUN Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope LocalMachine -Force

# Create test user (non-admin for testing)
RUN $password = ConvertTo-SecureString 'TestPass123!' -AsPlainText -Force; \
    New-LocalUser -Name 'testuser' -Password $password -Description 'Test user for MCP Ghidra5' -PasswordNeverExpires

# Install Windows features needed for services
RUN Enable-WindowsOptionalFeature -Online -FeatureName IIS-WebServerRole, IIS-WebServer, IIS-CommonHttpFeatures -All

# Create startup script
RUN @' \
Write-Host \"MCP-Ghidra5 Windows Testing Container\" -ForegroundColor Green \
Write-Host \"====================================\" -ForegroundColor Green \
Write-Host \"\" \
Write-Host \"Available test commands:\" -ForegroundColor Cyan \
Write-Host \"  .\\run-windows-tests.ps1    - Run full test suite\" -ForegroundColor White \
Write-Host \"  .\\test-installer.ps1       - Test installer only\" -ForegroundColor White \
Write-Host \"  Get-Service                 - Check Windows services\" -ForegroundColor White \
Write-Host \"  python --version            - Verify Python\" -ForegroundColor White \
Write-Host \"  java -version               - Verify Java\" -ForegroundColor White \
Write-Host \"\" \
Write-Host \"Project files mounted at: C:\\mcp-ghidra5\" -ForegroundColor Yellow \
Write-Host \"Ghidra installed at: C:\\ghidra\" -ForegroundColor Yellow \
Write-Host \"\" \
'@ | Out-File -FilePath C:\startup.ps1 -Encoding UTF8

# Expose port for MCP server
EXPOSE 8765

# Set default command
CMD ["powershell", "-NoExit", "-File", "C:\\startup.ps1"]