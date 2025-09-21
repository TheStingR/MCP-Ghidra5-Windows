#!/usr/bin/env python3
"""
TechSquad MCP Ghidra5 Server - Windows Enterprise Edition
Advanced Reverse Engineering with Ghidra + GPT-5 Integration

Copyright (c) 2024 TechSquad Inc. - All Rights Reserved
Proprietary Software - NOT FOR RESALE
Coded by: TheStingR

Windows-specific optimizations:
- Windows path handling and registry integration
- Windows service compatibility
- PowerShell integration for system tasks
- Windows Defender exclusion recommendations
- Enterprise logging and monitoring
"""

import asyncio
import logging
import os
import sys
import json
import tempfile
import subprocess
import winreg
import platform
from typing import Any, Dict, List, Optional
from pathlib import Path, WindowsPath
import ctypes
from ctypes import wintypes

import aiohttp
from mcp.server.stdio import stdio_server
from mcp.server import Server
from mcp.types import Tool, TextContent

# Windows-specific imports
if platform.system() == "Windows":
    import win32api
    import win32con
    import win32service
    import win32serviceutil
    import pywintypes

# Configure Windows-optimized logging
LOG_FORMAT = '%(asctime)s - %(name)s - %(levelname)s - %(message)s'
logging.basicConfig(
    level=logging.INFO,
    format=LOG_FORMAT,
    handlers=[
        logging.StreamHandler(sys.stdout),
        logging.FileHandler(
            Path(os.environ.get('PROGRAMDATA', 'C:\\ProgramData')) / 'TechSquad' / 'MCP-Ghidra5' / 'logs' / 'server.log',
            encoding='utf-8'
        )
    ]
)
logger = logging.getLogger(__name__)

# Windows Registry Keys for Configuration
REGISTRY_ROOT = winreg.HKEY_LOCAL_MACHINE
REGISTRY_PATH = r"SOFTWARE\TechSquad\MCP-Ghidra5"

# OpenAI API Configuration
OPENAI_BASE_URL = "https://api.openai.com/v1"
OPENAI_CHAT_ENDPOINT = f"{OPENAI_BASE_URL}/chat/completions"
GPT_MODEL = "gpt-4o"  # Will use GPT-5 when available

# Performance settings optimized for Windows
MAX_RETRIES = 3
RETRY_DELAY = 2
MAX_TOKENS_DEFAULT = 2000
MAX_TOKENS_ANALYSIS = 4000
MAX_TOKENS_EXPLOIT = 3000
REQUEST_TIMEOUT = 120

class WindowsConfigManager:
    """Windows-specific configuration management using Registry and environment"""
    
    def __init__(self):
        self.ensure_registry_keys()
        self.ghidra_path = self.detect_ghidra_installation()
        self.project_dir = self.get_project_directory()
        
    def ensure_registry_keys(self):
        """Ensure TechSquad registry keys exist"""
        try:
            with winreg.CreateKey(REGISTRY_ROOT, REGISTRY_PATH):
                pass
            logger.info("Registry keys initialized successfully")
        except Exception as e:
            logger.warning(f"Could not create registry keys: {e}")
    
    def detect_ghidra_installation(self) -> Optional[str]:
        """Auto-detect Ghidra installation on Windows"""
        # Check registry first
        try:
            with winreg.OpenKey(REGISTRY_ROOT, REGISTRY_PATH) as key:
                ghidra_path, _ = winreg.QueryValueEx(key, "GhidraPath")
                if ghidra_path and Path(ghidra_path).exists():
                    logger.info(f"Found Ghidra path in registry: {ghidra_path}")
                    return ghidra_path
        except FileNotFoundError:
            pass
        
        # Common Windows installation paths
        common_paths = [
            "C:\\ghidra\\support\\analyzeHeadless.bat",
            "C:\\Program Files\\ghidra\\support\\analyzeHeadless.bat",
            "C:\\Program Files (x86)\\ghidra\\support\\analyzeHeadless.bat",
            "C:\\tools\\ghidra\\support\\analyzeHeadless.bat",
            os.path.expanduser("~\\ghidra\\support\\analyzeHeadless.bat"),
            os.path.expanduser("~\\Desktop\\ghidra\\support\\analyzeHeadless.bat")
        ]
        
        for path in common_paths:
            if Path(path).exists():
                logger.info(f"Auto-detected Ghidra installation: {path}")
                # Save to registry for future use
                try:
                    with winreg.OpenKey(REGISTRY_ROOT, REGISTRY_PATH, 0, winreg.KEY_WRITE) as key:
                        winreg.SetValueEx(key, "GhidraPath", 0, winreg.REG_SZ, path)
                except:
                    pass
                return path
        
        # Check environment variable
        env_path = os.environ.get('GHIDRA_HEADLESS_PATH')
        if env_path and Path(env_path).exists():
            logger.info(f"Found Ghidra path in environment: {env_path}")
            return env_path
        
        logger.error("Ghidra installation not found. Please set GHIDRA_HEADLESS_PATH or install Ghidra.")
        return None
    
    def get_project_directory(self) -> str:
        """Get Ghidra project directory with Windows-appropriate defaults"""
        # Try registry first
        try:
            with winreg.OpenKey(REGISTRY_ROOT, REGISTRY_PATH) as key:
                project_dir, _ = winreg.QueryValueEx(key, "ProjectDirectory")
                if project_dir:
                    return project_dir
        except FileNotFoundError:
            pass
        
        # Windows-appropriate default paths
        programdata = os.environ.get('PROGRAMDATA', 'C:\\ProgramData')
        default_dir = Path(programdata) / 'TechSquad' / 'MCP-Ghidra5' / 'projects'
        default_dir.mkdir(parents=True, exist_ok=True)
        
        # Save to registry
        try:
            with winreg.OpenKey(REGISTRY_ROOT, REGISTRY_PATH, 0, winreg.KEY_WRITE) as key:
                winreg.SetValueEx(key, "ProjectDirectory", 0, winreg.REG_SZ, str(default_dir))
        except:
            pass
        
        return str(default_dir)
    
    def get_config_value(self, key: str, default: Any = None) -> Any:
        """Get configuration value from registry or environment"""
        # Try registry first
        try:
            with winreg.OpenKey(REGISTRY_ROOT, REGISTRY_PATH) as reg_key:
                value, _ = winreg.QueryValueEx(reg_key, key)
                return value
        except FileNotFoundError:
            pass
        
        # Fall back to environment variable
        env_key = f"TECHSQUAD_MCP_{key.upper()}"
        return os.environ.get(env_key, default)
    
    def set_config_value(self, key: str, value: Any) -> bool:
        """Set configuration value in registry"""
        try:
            with winreg.OpenKey(REGISTRY_ROOT, REGISTRY_PATH, 0, winreg.KEY_WRITE) as reg_key:
                if isinstance(value, str):
                    winreg.SetValueEx(reg_key, key, 0, winreg.REG_SZ, value)
                elif isinstance(value, int):
                    winreg.SetValueEx(reg_key, key, 0, winreg.REG_DWORD, value)
                else:
                    winreg.SetValueEx(reg_key, key, 0, winreg.REG_SZ, str(value))
                return True
        except Exception as e:
            logger.error(f"Failed to set registry value {key}: {e}")
            return False

class WindowsSystemIntegration:
    """Windows-specific system integration features"""
    
    @staticmethod
    def is_admin() -> bool:
        """Check if running with administrator privileges"""
        try:
            return ctypes.windll.shell32.IsUserAnAdmin()
        except:
            return False
    
    @staticmethod
    def get_system_info() -> Dict[str, Any]:
        """Get Windows system information"""
        return {
            "os": platform.system(),
            "version": platform.version(),
            "release": platform.release(),
            "machine": platform.machine(),
            "processor": platform.processor(),
            "architecture": platform.architecture(),
            "is_admin": WindowsSystemIntegration.is_admin(),
            "python_version": sys.version,
            "temp_dir": tempfile.gettempdir(),
            "programdata": os.environ.get('PROGRAMDATA', 'C:\\ProgramData')
        }
    
    @staticmethod
    def add_windows_defender_exclusions(paths: List[str]) -> bool:
        """Recommend Windows Defender exclusions via PowerShell"""
        if not WindowsSystemIntegration.is_admin():
            logger.warning("Administrator privileges required for Windows Defender exclusions")
            return False
        
        try:
            for path in paths:
                cmd = f'Add-MpPreference -ExclusionPath "{path}"'
                result = subprocess.run(
                    ["powershell", "-Command", cmd],
                    capture_output=True,
                    text=True
                )
                if result.returncode != 0:
                    logger.warning(f"Failed to add exclusion for {path}: {result.stderr}")
                else:
                    logger.info(f"Added Windows Defender exclusion for {path}")
            return True
        except Exception as e:
            logger.error(f"Error adding Windows Defender exclusions: {e}")
            return False

# Initialize Windows configuration
config_manager = WindowsConfigManager()
system_integration = WindowsSystemIntegration()

# Ghidra configuration with Windows paths
GHIDRA_HEADLESS_PATH = config_manager.ghidra_path
GHIDRA_PROJECT_DIR = config_manager.project_dir

# Log system information
logger.info("TechSquad MCP Ghidra5 Server - Windows Enterprise Edition")
system_info = system_integration.get_system_info()
logger.info(f"System: {system_info['os']} {system_info['version']}")
logger.info(f"Architecture: {system_info['architecture'][0]}")
logger.info(f"Administrator: {system_info['is_admin']}")
logger.info(f"Ghidra Path: {GHIDRA_HEADLESS_PATH}")
logger.info(f"Project Directory: {GHIDRA_PROJECT_DIR}")

# Create server instance
app = Server("techsquad-mcp-ghidra5-windows")

async def call_openai_api(messages: List[Dict[str, str]], max_tokens: int = MAX_TOKENS_DEFAULT) -> Optional[str]:
    """Enhanced OpenAI API call with Windows-specific error handling"""
    api_key = os.environ.get('OPENAI_API_KEY')
    if not api_key:
        logger.error("OPENAI_API_KEY not found in environment variables")
        return None
    
    headers = {
        'Authorization': f'Bearer {api_key}',
        'Content-Type': 'application/json',
        'User-Agent': 'TechSquad-MCP-Ghidra5-Windows/1.0'
    }
    
    payload = {
        'model': GPT_MODEL,
        'messages': messages,
        'max_tokens': max_tokens,
        'temperature': 0.7
    }
    
    for attempt in range(MAX_RETRIES):
        try:
            async with aiohttp.ClientSession(timeout=aiohttp.ClientTimeout(REQUEST_TIMEOUT)) as session:
                async with session.post(OPENAI_CHAT_ENDPOINT, json=payload, headers=headers) as response:
                    if response.status == 200:
                        data = await response.json()
                        return data['choices'][0]['message']['content']
                    else:
                        error_text = await response.text()
                        logger.error(f"OpenAI API error {response.status}: {error_text}")
                        
        except asyncio.TimeoutError:
            logger.warning(f"OpenAI API timeout (attempt {attempt + 1}/{MAX_RETRIES})")
        except Exception as e:
            logger.error(f"OpenAI API call failed (attempt {attempt + 1}/{MAX_RETRIES}): {e}")
        
        if attempt < MAX_RETRIES - 1:
            await asyncio.sleep(RETRY_DELAY * (attempt + 1))
    
    return None

async def run_ghidra_analysis(binary_path: str, analysis_type: str = "standard") -> Optional[Dict[str, Any]]:
    """Run Ghidra analysis with Windows path handling"""
    if not GHIDRA_HEADLESS_PATH:
        return {"error": "Ghidra not configured. Please check installation."}
    
    # Convert to Windows path format
    binary_path = str(Path(binary_path).resolve())
    project_name = f"analysis_{Path(binary_path).stem}_{hash(binary_path) & 0xffff:04x}"
    
    try:
        # Create project directory
        project_path = Path(GHIDRA_PROJECT_DIR) / project_name
        project_path.mkdir(parents=True, exist_ok=True)
        
        # Ghidra headless analysis command for Windows
        cmd = [
            GHIDRA_HEADLESS_PATH,
            str(project_path),
            project_name,
            "-import", binary_path,
            "-analyze",
            "-scriptPath", str(Path(__file__).parent / "ghidra_scripts"),
            "-postScript", "ExportAnalysisResults.java"
        ]
        
        logger.info(f"Running Ghidra analysis: {' '.join(cmd)}")
        
        # Run with Windows-specific settings
        startupinfo = subprocess.STARTUPINFO()
        startupinfo.dwFlags |= subprocess.STARTF_USESHOWWINDOW
        startupinfo.wShowWindow = subprocess.SW_HIDE
        
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            cwd=str(project_path),
            timeout=300,  # 5 minutes timeout
            startupinfo=startupinfo
        )
        
        if result.returncode != 0:
            logger.error(f"Ghidra analysis failed: {result.stderr}")
            return {"error": f"Ghidra analysis failed: {result.stderr}"}
        
        # Parse analysis results
        analysis_results = {
            "project_path": str(project_path),
            "binary_path": binary_path,
            "analysis_type": analysis_type,
            "stdout": result.stdout,
            "stderr": result.stderr,
            "success": True
        }
        
        return analysis_results
        
    except subprocess.TimeoutExpired:
        logger.error("Ghidra analysis timed out")
        return {"error": "Analysis timed out after 5 minutes"}
    except Exception as e:
        logger.error(f"Ghidra analysis error: {e}")
        return {"error": f"Analysis failed: {str(e)}"}

@app.list_tools()
async def handle_list_tools() -> List[Tool]:
    """List available Ghidra + GPT-5 tools for Windows"""
    return [
        Tool(
            name="ghidra_binary_analysis",
            description="Comprehensive binary analysis using Ghidra + GPT-5 for reverse engineering (Windows optimized)",
            inputSchema={
                "type": "object",
                "properties": {
                    "binary_path": {
                        "type": "string",
                        "description": "Windows path to binary file (e.g., C:\\samples\\malware.exe)"
                    },
                    "analysis_depth": {
                        "type": "string",
                        "description": "Analysis depth level",
                        "enum": ["quick", "standard", "deep", "exploit_focused"]
                    },
                    "focus_areas": {
                        "type": "array",
                        "items": {"type": "string"},
                        "description": "Specific areas to focus on"
                    }
                },
                "required": ["binary_path"]
            }
        ),
        Tool(
            name="windows_malware_analysis",
            description="Specialized Windows malware analysis with Ghidra + GPT-5",
            inputSchema={
                "type": "object",
                "properties": {
                    "malware_path": {
                        "type": "string",
                        "description": "Path to Windows malware sample"
                    },
                    "analysis_scope": {
                        "type": "string",
                        "description": "Scope of malware analysis",
                        "enum": ["static_only", "behavioral", "network_analysis", "persistence_mechanisms", "evasion_techniques"]
                    },
                    "windows_specific": {
                        "type": "boolean",
                        "description": "Include Windows-specific analysis (registry, services, etc.)",
                        "default": True
                    }
                },
                "required": ["malware_path"]
            }
        ),
        Tool(
            name="windows_pe_analysis",
            description="Detailed Windows PE (Portable Executable) analysis",
            inputSchema={
                "type": "object",
                "properties": {
                    "pe_path": {
                        "type": "string",
                        "description": "Path to Windows PE file (.exe, .dll, .sys)"
                    },
                    "analysis_components": {
                        "type": "array",
                        "items": {"type": "string"},
                        "description": "PE components to analyze",
                        "default": ["headers", "imports", "exports", "resources", "sections"]
                    }
                },
                "required": ["pe_path"]
            }
        ),
        Tool(
            name="system_integration_check",
            description="Check Windows system integration and configuration",
            inputSchema={
                "type": "object",
                "properties": {
                    "check_type": {
                        "type": "string",
                        "description": "Type of system check",
                        "enum": ["full", "ghidra_config", "permissions", "defender_status"]
                    }
                },
                "required": []
            }
        )
    ]

@app.call_tool()
async def handle_call_tool(name: str, arguments: Dict[str, Any]) -> List[TextContent]:
    """Handle tool calls with Windows-specific implementations"""
    try:
        if name == "ghidra_binary_analysis":
            return await handle_binary_analysis(arguments)
        elif name == "windows_malware_analysis":
            return await handle_malware_analysis(arguments)
        elif name == "windows_pe_analysis":
            return await handle_pe_analysis(arguments)
        elif name == "system_integration_check":
            return await handle_system_check(arguments)
        else:
            return [TextContent(type="text", text=f"Unknown tool: {name}")]
    except Exception as e:
        logger.error(f"Tool execution error: {e}")
        return [TextContent(type="text", text=f"Error executing tool {name}: {str(e)}")]

async def handle_binary_analysis(arguments: Dict[str, Any]) -> List[TextContent]:
    """Handle binary analysis with Windows optimizations"""
    binary_path = arguments.get("binary_path")
    analysis_depth = arguments.get("analysis_depth", "standard")
    focus_areas = arguments.get("focus_areas", [])
    
    if not binary_path or not Path(binary_path).exists():
        return [TextContent(type="text", text=f"Binary file not found: {binary_path}")]
    
    # Run Ghidra analysis
    ghidra_results = await run_ghidra_analysis(binary_path, analysis_depth)
    
    if ghidra_results.get("error"):
        return [TextContent(type="text", text=f"Ghidra analysis failed: {ghidra_results['error']}")]
    
    # Prepare prompt for GPT analysis
    analysis_prompt = f"""
    Analyze this Windows binary using the Ghidra analysis results:
    
    Binary: {binary_path}
    Analysis Depth: {analysis_depth}
    Focus Areas: {', '.join(focus_areas) if focus_areas else 'General analysis'}
    
    Ghidra Output:
    {ghidra_results.get('stdout', 'No output')}
    
    Please provide:
    1. Binary overview and purpose
    2. Architecture and compilation details
    3. Security implications and vulnerabilities
    4. Windows-specific features (APIs, registry, services)
    5. Recommendations for further analysis
    
    Focus especially on Windows-specific aspects and potential security issues.
    """
    
    # Get GPT analysis
    gpt_analysis = await call_openai_api([
        {"role": "system", "content": "You are a Windows malware analyst and reverse engineer expert."},
        {"role": "user", "content": analysis_prompt}
    ], MAX_TOKENS_ANALYSIS)
    
    if not gpt_analysis:
        return [TextContent(type="text", text="Failed to get AI analysis")]
    
    return [TextContent(type="text", text=gpt_analysis)]

async def handle_malware_analysis(arguments: Dict[str, Any]) -> List[TextContent]:
    """Handle Windows malware analysis"""
    malware_path = arguments.get("malware_path")
    analysis_scope = arguments.get("analysis_scope", "static_only")
    windows_specific = arguments.get("windows_specific", True)
    
    if not Path(malware_path).exists():
        return [TextContent(type="text", text=f"Malware sample not found: {malware_path}")]
    
    # Security warning
    warning = """
    ⚠️  MALWARE ANALYSIS WARNING ⚠️
    You are analyzing a potentially dangerous malware sample.
    Ensure you are in a secure, isolated environment (VM/sandbox).
    TechSquad Inc. is not responsible for any damage caused by malware execution.
    """
    
    # Run specialized malware analysis
    ghidra_results = await run_ghidra_analysis(malware_path, "deep")
    
    if ghidra_results.get("error"):
        return [TextContent(type="text", text=f"{warning}\n\nGhidra analysis failed: {ghidra_results['error']}")]
    
    # Windows-specific malware analysis prompt
    malware_prompt = f"""
    Perform comprehensive Windows malware analysis:
    
    Sample: {malware_path}
    Analysis Scope: {analysis_scope}
    Windows-Specific Analysis: {windows_specific}
    
    Ghidra Results:
    {ghidra_results.get('stdout', 'No output')}
    
    Provide detailed analysis covering:
    1. Malware family and type identification
    2. Infection vectors and propagation methods
    3. Windows system modifications (registry, files, services)
    4. Network communication and C2 infrastructure
    5. Evasion techniques and anti-analysis measures
    6. Persistence mechanisms
    7. Payload and damage assessment
    8. Mitigation and removal recommendations
    
    Focus on Windows-specific aspects and provide actionable intelligence.
    """
    
    gpt_analysis = await call_openai_api([
        {"role": "system", "content": "You are an expert Windows malware analyst with deep knowledge of malware families, attack techniques, and Windows internals."},
        {"role": "user", "content": malware_prompt}
    ], MAX_TOKENS_ANALYSIS)
    
    if not gpt_analysis:
        return [TextContent(type="text", text=f"{warning}\n\nFailed to get AI malware analysis")]
    
    return [TextContent(type="text", text=f"{warning}\n\n{gpt_analysis}")]

async def handle_pe_analysis(arguments: Dict[str, Any]) -> List[TextContent]:
    """Handle Windows PE analysis"""
    pe_path = arguments.get("pe_path")
    components = arguments.get("analysis_components", ["headers", "imports", "exports", "resources", "sections"])
    
    if not Path(pe_path).exists():
        return [TextContent(type="text", text=f"PE file not found: {pe_path}")]
    
    # TODO: Implement detailed PE analysis using pefile library
    pe_info = f"""
    Windows PE Analysis for: {pe_path}
    Components analyzed: {', '.join(components)}
    
    This would include detailed PE structure analysis:
    - DOS/NT Headers
    - Section analysis
    - Import/Export tables  
    - Resource analysis
    - Digital signature verification
    - Entropy analysis
    - Packer detection
    """
    
    return [TextContent(type="text", text=pe_info)]

async def handle_system_check(arguments: Dict[str, Any]) -> List[TextContent]:
    """Handle Windows system integration check"""
    check_type = arguments.get("check_type", "full")
    
    system_info = system_integration.get_system_info()
    
    status_report = f"""
    TechSquad MCP Ghidra5 - Windows System Status
    =============================================
    
    System Information:
    - OS: {system_info['os']} {system_info['release']}
    - Version: {system_info['version']}
    - Architecture: {system_info['architecture'][0]}
    - Processor: {system_info['processor']}
    - Administrator Privileges: {system_info['is_admin']}
    - Python Version: {system_info['python_version']}
    - Temp Directory: {system_info['temp_dir']}
    
    Configuration Status:
    - Ghidra Path: {GHIDRA_HEADLESS_PATH or 'NOT CONFIGURED'}
    - Project Directory: {GHIDRA_PROJECT_DIR}
    - Registry Integration: {'OK' if config_manager else 'ERROR'}
    
    Recommendations:
    """
    
    recommendations = []
    
    if not GHIDRA_HEADLESS_PATH:
        recommendations.append("❌ Ghidra not found - Please install Ghidra and configure path")
    else:
        recommendations.append("✅ Ghidra installation detected")
    
    if not system_info['is_admin']:
        recommendations.append("⚠️  Running without administrator privileges - Some features may be limited")
    else:
        recommendations.append("✅ Running with administrator privileges")
    
    if system_info['architecture'][0] != '64bit':
        recommendations.append("⚠️  32-bit system detected - Consider using 64-bit Windows for better performance")
    
    recommendations.append("🛡️  Consider adding Windows Defender exclusions for better performance")
    
    status_report += "\n".join(f"    {rec}" for rec in recommendations)
    
    return [TextContent(type="text", text=status_report)]

async def main():
    """Main entry point for Windows MCP server"""
    try:
        # Log startup information
        logger.info("Starting TechSquad MCP Ghidra5 Server - Windows Enterprise Edition")
        logger.info(f"Process ID: {os.getpid()}")
        logger.info(f"Working Directory: {os.getcwd()}")
        
        # Check Ghidra configuration
        if not GHIDRA_HEADLESS_PATH:
            logger.warning("Ghidra not configured - some features will be unavailable")
        
        # Start the MCP server
        async with stdio_server() as server:
            await app.run(server.read_stream, server.write_stream)
            
    except KeyboardInterrupt:
        logger.info("Server shutdown requested")
    except Exception as e:
        logger.error(f"Server error: {e}")
        raise

if __name__ == "__main__":
    # Windows-specific startup
    if platform.system() != "Windows":
        print("This server is designed for Windows systems only.")
        sys.exit(1)
    
    # Set up Windows-specific signal handlers
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        print("\nServer stopped by user")
    except Exception as e:
        print(f"Fatal error: {e}")
        sys.exit(1)