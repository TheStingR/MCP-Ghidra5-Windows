#!/usr/bin/env python3
"""
Ghidra GPT-5 MCP Server for Advanced Reverse Engineering
Specialized for binary analysis, exploitation research, and malware reverse engineering

Copyright (c) 2024 TechSquad Inc. - All Rights Reserved
Proprietary Software - NOT FOR RESALE
Coded by: TheStingR

This software is the property of TechSquad Inc. and is protected by copyright law.
Unauthorized reproduction, distribution, or sale is strictly prohibited.
For licensing inquiries, contact TechSquad Inc.
"""

import asyncio
import logging
import os
import sys
import json
import tempfile
import subprocess
from typing import Any, Dict, List, Optional
from pathlib import Path

import aiohttp
from mcp.server.stdio import stdio_server
from mcp.server import Server
from mcp.types import Tool, TextContent

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# OpenAI API Configuration
OPENAI_BASE_URL = "https://api.openai.com/v1"
OPENAI_CHAT_ENDPOINT = f"{OPENAI_BASE_URL}/chat/completions"
GPT_MODEL = "gpt-4o"  # Will use GPT-5 when available

# Performance settings optimized for binary analysis
MAX_RETRIES = 3
RETRY_DELAY = 2
MAX_TOKENS_DEFAULT = 2000
MAX_TOKENS_ANALYSIS = 4000
MAX_TOKENS_EXPLOIT = 3000
REQUEST_TIMEOUT = 120  # Longer timeout for complex analysis

# Ghidra configuration
GHIDRA_HEADLESS_PATH = os.environ.get('GHIDRA_HEADLESS_PATH', '/opt/ghidra/support/analyzeHeadless')
GHIDRA_PROJECT_DIR = os.environ.get('GHIDRA_PROJECT_DIR', '/tmp/ghidra_projects')

# Create server instance
app = Server("ghidra-gpt5-mcp-server")

@app.list_tools()
async def handle_list_tools() -> List[Tool]:
    """List available Ghidra + GPT-5 tools"""
    return [
        Tool(
            name="ghidra_binary_analysis",
            description="Comprehensive binary analysis using Ghidra + GPT-5 for reverse engineering",
            inputSchema={
                "type": "object",
                "properties": {
                    "binary_path": {
                        "type": "string",
                        "description": "Path to binary file for analysis"
                    },
                    "analysis_depth": {
                        "type": "string",
                        "description": "Analysis depth level",
                        "enum": ["quick", "standard", "deep", "exploit_focused"]
                    },
                    "focus_areas": {
                        "type": "array",
                        "items": {"type": "string"},
                        "description": "Specific areas to focus on (e.g., 'vulnerabilities', 'crypto', 'network', 'obfuscation')"
                    }
                },
                "required": ["binary_path"]
            }
        ),
        Tool(
            name="ghidra_function_analysis",
            description="Analyze specific functions in a binary using Ghidra decompilation + GPT-5",
            inputSchema={
                "type": "object",
                "properties": {
                    "binary_path": {
                        "type": "string",
                        "description": "Path to binary file"
                    },
                    "function_address": {
                        "type": "string",
                        "description": "Function address (e.g., '0x401000') or function name"
                    },
                    "analysis_type": {
                        "type": "string",
                        "description": "Type of function analysis",
                        "enum": ["vulnerability_scan", "algorithm_identification", "crypto_analysis", "exploit_potential", "behavioral_analysis"]
                    }
                },
                "required": ["binary_path", "function_address"]
            }
        ),
        Tool(
            name="ghidra_exploit_development",
            description="Analyze binary for exploitation opportunities and generate exploit strategies",
            inputSchema={
                "type": "object",
                "properties": {
                    "binary_path": {
                        "type": "string",
                        "description": "Path to target binary"
                    },
                    "target_platform": {
                        "type": "string",
                        "description": "Target platform (e.g., 'linux_x64', 'windows_x86', 'arm64')"
                    },
                    "exploit_type": {
                        "type": "string",
                        "description": "Exploitation approach to focus on",
                        "enum": ["buffer_overflow", "format_string", "use_after_free", "rop_chain", "heap_exploitation", "race_condition"]
                    },
                    "generate_poc": {
                        "type": "boolean",
                        "description": "Whether to generate proof-of-concept exploit code",
                        "default": False
                    }
                },
                "required": ["binary_path", "target_platform"]
            }
        ),
        Tool(
            name="ghidra_malware_analysis",
            description="Specialized malware analysis using Ghidra + GPT-5 for behavioral and structural analysis",
            inputSchema={
                "type": "object",
                "properties": {
                    "malware_path": {
                        "type": "string",
                        "description": "Path to malware sample (CAUTION: Ensure safe environment)"
                    },
                    "analysis_scope": {
                        "type": "string",
                        "description": "Scope of malware analysis",
                        "enum": ["static_only", "behavioral", "network_analysis", "persistence_mechanisms", "evasion_techniques"]
                    },
                    "sandbox_mode": {
                        "type": "boolean",
                        "description": "Whether to assume sandbox/VM environment",
                        "default": True
                    }
                },
                "required": ["malware_path"]
            }
        ),
        Tool(
            name="ghidra_firmware_analysis",
            description="Firmware and embedded system analysis using Ghidra + GPT-5",
            inputSchema={
                "type": "object",
                "properties": {
                    "firmware_path": {
                        "type": "string",
                        "description": "Path to firmware image or extracted binary"
                    },
                    "architecture": {
                        "type": "string",
                        "description": "Target architecture if known",
                        "enum": ["arm", "mips", "x86", "x64", "riscv", "auto_detect"]
                    },
                    "device_type": {
                        "type": "string",
                        "description": "Type of device/firmware",
                        "enum": ["router", "iot_device", "bootloader", "rtos", "embedded_linux", "unknown"]
                    }
                },
                "required": ["firmware_path"]
            }
        ),
        Tool(
            name="ghidra_code_pattern_search",
            description="Search for specific code patterns, vulnerabilities, or algorithms in binaries",
            inputSchema={
                "type": "object",
                "properties": {
                    "binary_path": {
                        "type": "string",
                        "description": "Path to binary file"
                    },
                    "search_pattern": {
                        "type": "string",
                        "description": "Pattern to search for (e.g., 'strcpy calls', 'crypto constants', 'shellcode patterns')"
                    },
                    "pattern_type": {
                        "type": "string",
                        "description": "Type of pattern search",
                        "enum": ["vulnerability_patterns", "crypto_algorithms", "packer_signatures", "anti_debug", "api_calls", "string_patterns"]
                    }
                },
                "required": ["binary_path", "search_pattern"]
            }
        ),
        Tool(
            name="gpt5_reverse_engineering_query",
            description="Direct GPT-5 query for reverse engineering, exploitation, or malware analysis questions",
            inputSchema={
                "type": "object",
                "properties": {
                    "query": {
                        "type": "string",
                        "description": "Reverse engineering or exploitation question"
                    },
                    "context": {
                        "type": "string",
                        "description": "Additional context (assembly code, decompiled code, hex dumps, etc.)",
                        "default": ""
                    },
                    "specialization": {
                        "type": "string",
                        "description": "Area of specialization to focus on",
                        "enum": ["binary_exploitation", "malware_analysis", "firmware_hacking", "crypto_analysis", "reverse_engineering", "vulnerability_research"]
                    }
                },
                "required": ["query"]
            }
        )
    ]

@app.call_tool()
async def handle_call_tool(name: str, arguments: Dict[str, Any]) -> List[TextContent]:
    """Handle tool calls"""
    try:
        if name == "ghidra_binary_analysis":
            return await handle_binary_analysis(arguments)
        elif name == "ghidra_function_analysis":
            return await handle_function_analysis(arguments)
        elif name == "ghidra_exploit_development":
            return await handle_exploit_development(arguments)
        elif name == "ghidra_malware_analysis":
            return await handle_malware_analysis(arguments)
        elif name == "ghidra_firmware_analysis":
            return await handle_firmware_analysis(arguments)
        elif name == "ghidra_code_pattern_search":
            return await handle_pattern_search(arguments)
        elif name == "gpt5_reverse_engineering_query":
            return await handle_gpt5_query(arguments)
        else:
            return [TextContent(type="text", text=f"Unknown tool: {name}")]
    except Exception as e:
        logger.error(f"Error handling tool call {name}: {str(e)}")
        return [TextContent(type="text", text=f"Error: {str(e)}")]

def get_openai_api_key() -> str:
    """Get OpenAI API key from environment or config"""
    # Try multiple environment variable names
    key_vars = ['OPENAI_API_KEY', 'CHATGPT_COOKIE']  # CHATGPT_COOKIE from your env
    
    for var in key_vars:
        key = os.environ.get(var)
        if key and key.strip():
            # Extract API key if it's in the format of your CHATGPT_COOKIE
            if key.startswith('sk-'):
                return key.strip()
    
    raise RuntimeError("OpenAI API key not found. Please set OPENAI_API_KEY environment variable")

async def query_gpt5_with_retry(messages: List[Dict[str, str]], operation_type: str = "analysis") -> str:
    """Query GPT-5 (or GPT-4o) with retry logic and optimized settings"""
    
    api_key = get_openai_api_key()
    
    # Determine max tokens based on operation type
    max_tokens = {
        "analysis": MAX_TOKENS_ANALYSIS,
        "exploit": MAX_TOKENS_EXPLOIT,
        "query": MAX_TOKENS_DEFAULT
    }.get(operation_type, MAX_TOKENS_DEFAULT)
    
    headers = {
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json"
    }
    
    data = {
        "model": GPT_MODEL,
        "messages": messages,
        "max_tokens": max_tokens,
        "temperature": 0.1,  # Lower temperature for more focused technical analysis
        "top_p": 0.9,
        "frequency_penalty": 0.0,
        "presence_penalty": 0.0
    }
    
    for attempt in range(MAX_RETRIES):
        try:
            timeout = aiohttp.ClientTimeout(total=REQUEST_TIMEOUT)
            async with aiohttp.ClientSession(timeout=timeout) as session:
                async with session.post(OPENAI_CHAT_ENDPOINT, headers=headers, json=data) as response:
                    if response.status == 200:
                        result = await response.json()
                        if 'choices' in result and len(result['choices']) > 0:
                            content = result['choices'][0]['message']['content']
                            logger.info(f"GPT-5 response received for {operation_type} (attempt {attempt + 1})")
                            return content
                        else:
                            raise Exception("Empty response from GPT-5")
                    elif response.status == 429:
                        # Rate limit - wait longer
                        wait_time = RETRY_DELAY * (2 ** attempt)
                        logger.warning(f"Rate limited, waiting {wait_time}s before retry {attempt + 1}")
                        await asyncio.sleep(wait_time)
                        continue
                    else:
                        error_text = await response.text()
                        raise Exception(f"HTTP {response.status}: {error_text}")
                        
        except asyncio.TimeoutError:
            logger.warning(f"Request timeout on attempt {attempt + 1}")
            if attempt == MAX_RETRIES - 1:
                raise Exception("Request timed out after all retries")
            await asyncio.sleep(RETRY_DELAY)
        except Exception as e:
            logger.error(f"Attempt {attempt + 1} failed: {str(e)}")
            if attempt == MAX_RETRIES - 1:
                raise Exception(f"All retry attempts failed. Last error: {str(e)}")
            await asyncio.sleep(RETRY_DELAY)
    
    raise Exception("Unexpected error in retry logic")

def run_ghidra_headless(binary_path: str, script_path: str = None, additional_args: List[str] = None) -> str:
    """Run Ghidra in headless mode for binary analysis"""
    
    if not os.path.exists(binary_path):
        raise Exception(f"Binary file not found: {binary_path}")
    
    # Ensure project directory exists
    os.makedirs(GHIDRA_PROJECT_DIR, exist_ok=True)
    
    # Create temporary project name
    import uuid
    project_name = f"ghidra_analysis_{uuid.uuid4().hex[:8]}"
    project_path = os.path.join(GHIDRA_PROJECT_DIR, project_name)
    
    # Basic Ghidra headless command
    cmd = [
        GHIDRA_HEADLESS_PATH,
        project_path,
        project_name,
        "-import", binary_path,
        "-analyzeAll",
        "-scriptPath", "/opt/ghidra/Ghidra/Features/Python/ghidra_scripts",
        "-deleteProject"  # Clean up after analysis
    ]
    
    # Add custom script if provided
    if script_path and os.path.exists(script_path):
        cmd.extend(["-postScript", script_path])
    
    # Add additional arguments
    if additional_args:
        cmd.extend(additional_args)
    
    try:
        logger.info(f"Running Ghidra analysis on {binary_path}")
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=300)
        
        if result.returncode == 0:
            return result.stdout
        else:
            error_msg = f"Ghidra analysis failed (return code {result.returncode}):\n{result.stderr}"
            logger.error(error_msg)
            return error_msg
            
    except subprocess.TimeoutExpired:
        return "Ghidra analysis timed out after 5 minutes"
    except Exception as e:
        return f"Error running Ghidra: {str(e)}"

async def handle_binary_analysis(arguments: Dict[str, Any]) -> List[TextContent]:
    """Handle comprehensive binary analysis using Ghidra + GPT-5"""
    binary_path = arguments["binary_path"]
    analysis_depth = arguments.get("analysis_depth", "standard")
    focus_areas = arguments.get("focus_areas", [])
    
    # Run Ghidra analysis
    ghidra_output = run_ghidra_headless(binary_path)
    
    # Build specialized prompt based on analysis depth
    depth_prompts = {
        "quick": "Provide a rapid assessment focusing on high-level structure and obvious security issues.",
        "standard": "Perform comprehensive analysis including function analysis, security assessment, and architectural overview.",
        "deep": "Conduct exhaustive analysis including advanced vulnerability research, algorithm identification, and exploitation assessment.",
        "exploit_focused": "Focus specifically on exploitation opportunities, vulnerability chains, and attack surface analysis."
    }
    
    focus_context = ""
    if focus_areas:
        focus_context = f"\nPay special attention to these areas: {', '.join(focus_areas)}"
    
    system_prompt = f"""You are an expert reverse engineer and binary analyst using GPT-5 for advanced binary analysis. 
    
Analyze the following Ghidra output for a binary analysis with {analysis_depth} depth.
{depth_prompts.get(analysis_depth, "Perform standard analysis.")}
{focus_context}

Provide your analysis in the following structure:
1. **Binary Overview** - Architecture, packing, compilation details
2. **Security Assessment** - Identified vulnerabilities and security features
3. **Function Analysis** - Key functions and their purposes  
4. **Exploitation Opportunities** - Potential attack vectors and exploitability
5. **Recommendations** - Next steps for further analysis or exploitation
6. **Technical Details** - Important addresses, offsets, and technical notes

Be specific, actionable, and focus on information useful for penetration testing and security research."""

    messages = [
        {"role": "system", "content": system_prompt},
        {"role": "user", "content": f"Binary: {binary_path}\n\nGhidra Analysis Output:\n{ghidra_output}"}
    ]
    
    response = await query_gpt5_with_retry(messages, "analysis")
    return [TextContent(type="text", text=response)]

async def handle_function_analysis(arguments: Dict[str, Any]) -> List[TextContent]:
    """Handle specific function analysis using Ghidra decompilation + GPT-5"""
    binary_path = arguments["binary_path"]
    function_address = arguments["function_address"]
    analysis_type = arguments.get("analysis_type", "vulnerability_scan")
    
    # Create custom Ghidra script for function-specific analysis
    script_content = f"""
# Ghidra script for function analysis
from ghidra.program.model.address import *
from ghidra.program.model.listing import *

def analyze_function():
    fm = currentProgram.getFunctionManager()
    addr = toAddr("{function_address}")
    func = fm.getFunctionAt(addr)
    
    if func is None:
        print(f"No function found at address {function_address}")
        return
    
    print(f"Function: {{func.getName()}} at {{func.getEntryPoint()}}")
    print(f"Parameters: {{func.getParameterCount()}}")
    
    # Get decompiled code
    from ghidra.app.decompiler import DecompInterface
    decomp_ifc = DecompInterface()
    decomp_ifc.openProgram(currentProgram)
    
    result = decomp_ifc.decompileFunction(func, 30, None)
    if result.decompileCompleted():
        print("DECOMPILED_CODE:")
        print(result.getDecompiledFunction().getC())
    else:
        print("Decompilation failed")

analyze_function()
"""
    
    # Write temporary script
    with tempfile.NamedTemporaryFile(mode='w', suffix='.py', delete=False) as f:
        f.write(script_content)
        script_path = f.name
    
    try:
        # Run Ghidra with custom script
        ghidra_output = run_ghidra_headless(binary_path, script_path)
        
        analysis_prompts = {
            "vulnerability_scan": "Focus on identifying security vulnerabilities, buffer overflows, format string bugs, and other exploitable conditions.",
            "algorithm_identification": "Identify the algorithm or cryptographic function being implemented.",
            "crypto_analysis": "Analyze cryptographic implementations for weaknesses, hardcoded keys, or implementation flaws.",
            "exploit_potential": "Assess the exploitability of this function and potential attack vectors.",
            "behavioral_analysis": "Analyze the behavior and purpose of this function in the overall program flow."
        }
        
        system_prompt = f"""You are an expert reverse engineer analyzing a specific function using GPT-5.
        
Function Analysis Type: {analysis_type}
{analysis_prompts.get(analysis_type, "Perform general function analysis.")}

Provide detailed analysis including:
1. **Function Purpose** - What does this function do?
2. **Security Analysis** - Vulnerabilities, weaknesses, security implications
3. **Parameters & Return Values** - Analysis of input/output
4. **Control Flow** - Important branches, loops, conditions  
5. **Exploitation Assessment** - How this function could be exploited
6. **Recommendations** - Specific advice for penetration testing or exploitation

Be technical, specific, and actionable."""

        messages = [
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": f"Function at {function_address} in {binary_path}:\n\nGhidra Analysis:\n{ghidra_output}"}
        ]
        
        response = await query_gpt5_with_retry(messages, "analysis")
        return [TextContent(type="text", text=response)]
        
    finally:
        # Clean up temporary script
        try:
            os.unlink(script_path)
        except:
            pass

async def handle_exploit_development(arguments: Dict[str, Any]) -> List[TextContent]:
    """Handle exploit development analysis"""
    binary_path = arguments["binary_path"]
    target_platform = arguments["target_platform"]
    exploit_type = arguments.get("exploit_type", "buffer_overflow")
    generate_poc = arguments.get("generate_poc", False)
    
    # Run targeted Ghidra analysis for exploitation
    ghidra_output = run_ghidra_headless(binary_path)
    
    system_prompt = f"""You are an expert exploit developer using GPT-5 for advanced exploitation research.

Target Platform: {target_platform}
Exploitation Focus: {exploit_type}
Generate PoC: {generate_poc}

Analyze the binary for exploitation opportunities focusing on {exploit_type} vulnerabilities.

Provide comprehensive exploitation analysis:
1. **Vulnerability Assessment** - Identify exploitable conditions
2. **Attack Vector Analysis** - How to trigger and exploit vulnerabilities  
3. **Exploitation Strategy** - Step-by-step exploitation approach
4. **Payload Development** - Shellcode and ROP chain considerations
5. **ASLR/DEP Bypass** - Techniques to bypass modern protections
6. **Exploitation Timeline** - Difficulty and time estimation
{'7. **Proof of Concept** - Complete working exploit code' if generate_poc else '7. **PoC Outline** - Detailed steps to create working exploit'}

Focus on practical, working exploitation techniques for {target_platform}."""

    messages = [
        {"role": "system", "content": system_prompt},
        {"role": "user", "content": f"Target Binary: {binary_path}\nPlatform: {target_platform}\n\nGhidra Analysis:\n{ghidra_output}"}
    ]
    
    response = await query_gpt5_with_retry(messages, "exploit")
    return [TextContent(type="text", text=response)]

async def handle_malware_analysis(arguments: Dict[str, Any]) -> List[TextContent]:
    """Handle malware analysis using Ghidra + GPT-5"""
    malware_path = arguments["malware_path"]
    analysis_scope = arguments.get("analysis_scope", "static_only")
    sandbox_mode = arguments.get("sandbox_mode", True)
    
    # Safety warning
    safety_warning = "⚠️  MALWARE ANALYSIS MODE - Ensure you are in a secure, isolated environment!"
    
    # Run Ghidra analysis
    ghidra_output = run_ghidra_headless(malware_path)
    
    scope_prompts = {
        "static_only": "Focus on static analysis without executing the malware.",
        "behavioral": "Analyze expected runtime behavior, network connections, and system modifications.",
        "network_analysis": "Focus on network communication, C2 infrastructure, and data exfiltration.",
        "persistence_mechanisms": "Identify how the malware maintains persistence and avoids detection.",
        "evasion_techniques": "Analyze anti-analysis, anti-debug, and evasion techniques."
    }
    
    system_prompt = f"""You are an expert malware analyst using GPT-5 for advanced malware reverse engineering.

Analysis Scope: {analysis_scope}
Sandbox Environment: {sandbox_mode}
{scope_prompts.get(analysis_scope, "Perform comprehensive malware analysis.")}

Provide detailed malware analysis:
1. **Malware Classification** - Type, family, variant identification
2. **Behavioral Analysis** - Expected runtime behavior and capabilities
3. **Network Analysis** - C2 communication, data exfiltration methods
4. **Persistence Mechanisms** - How malware maintains presence
5. **Evasion Techniques** - Anti-analysis and stealth capabilities  
6. **IOCs (Indicators of Compromise)** - Network signatures, file artifacts
7. **Mitigation Strategies** - Detection and removal recommendations
8. **Attribution Assessment** - Possible threat actor indicators

Focus on actionable intelligence for incident response and threat hunting."""

    messages = [
        {"role": "system", "content": system_prompt},
        {"role": "user", "content": f"Malware Sample: {malware_path}\n\n{safety_warning}\n\nGhidra Analysis:\n{ghidra_output}"}
    ]
    
    response = await query_gpt5_with_retry(messages, "analysis")
    return [TextContent(type="text", text=f"{safety_warning}\n\n{response}")]

async def handle_firmware_analysis(arguments: Dict[str, Any]) -> List[TextContent]:
    """Handle firmware analysis using Ghidra + GPT-5"""
    firmware_path = arguments["firmware_path"]
    architecture = arguments.get("architecture", "auto_detect")
    device_type = arguments.get("device_type", "unknown")
    
    # Run Ghidra analysis
    ghidra_output = run_ghidra_headless(firmware_path)
    
    system_prompt = f"""You are an expert firmware security researcher using GPT-5 for IoT and embedded system analysis.

Architecture: {architecture}
Device Type: {device_type}

Analyze the firmware for security vulnerabilities and exploitation opportunities:

1. **Firmware Overview** - Architecture, OS, compilation details
2. **Security Assessment** - Hardcoded credentials, crypto keys, vulnerabilities  
3. **Attack Surface** - Network services, web interfaces, update mechanisms
4. **Exploitation Opportunities** - Buffer overflows, authentication bypasses
5. **Backdoors & Debug Features** - Hidden functionality, debug interfaces
6. **Crypto Analysis** - Key storage, encryption implementations
7. **Hardware Security** - Boot security, secure boot bypass
8. **Post-Exploitation** - Persistence, lateral movement opportunities

Focus on practical attack vectors for IoT penetration testing and hardware hacking."""

    messages = [
        {"role": "system", "content": system_prompt},
        {"role": "user", "content": f"Firmware: {firmware_path}\nArch: {architecture}\nDevice: {device_type}\n\nGhidra Analysis:\n{ghidra_output}"}
    ]
    
    response = await query_gpt5_with_retry(messages, "analysis")
    return [TextContent(type="text", text=response)]

async def handle_pattern_search(arguments: Dict[str, Any]) -> List[TextContent]:
    """Handle code pattern search using Ghidra + GPT-5"""
    binary_path = arguments["binary_path"]
    search_pattern = arguments["search_pattern"]
    pattern_type = arguments["pattern_type"]
    
    # Run Ghidra analysis
    ghidra_output = run_ghidra_headless(binary_path)
    
    pattern_prompts = {
        "vulnerability_patterns": "Search for common vulnerability patterns like buffer overflows, format strings, race conditions.",
        "crypto_algorithms": "Identify cryptographic algorithms, constants, and implementations.",
        "packer_signatures": "Look for packing, obfuscation, or anti-analysis techniques.",
        "anti_debug": "Find anti-debugging and evasion mechanisms.",
        "api_calls": "Analyze Windows/Linux API calls and system interactions.",
        "string_patterns": "Search for specific string patterns, URLs, file paths, or configurations."
    }
    
    system_prompt = f"""You are an expert code pattern analyst using GPT-5 for binary analysis.

Search Pattern: {search_pattern}
Pattern Type: {pattern_type}
{pattern_prompts.get(pattern_type, "Search for the specified pattern.")}

Analyze the binary and provide:
1. **Pattern Matches** - Specific locations where patterns were found
2. **Context Analysis** - What these patterns mean in the overall program
3. **Security Implications** - Security impact of identified patterns
4. **Exploitation Potential** - How patterns could be exploited
5. **Related Patterns** - Additional patterns to investigate
6. **Recommendations** - Next steps for investigation or exploitation

Be specific about addresses, function names, and exploitation potential."""

    messages = [
        {"role": "system", "content": system_prompt},
        {"role": "user", "content": f"Binary: {binary_path}\nSearch for: {search_pattern}\n\nGhidra Analysis:\n{ghidra_output}"}
    ]
    
    response = await query_gpt5_with_retry(messages, "analysis")
    return [TextContent(type="text", text=response)]

async def handle_gpt5_query(arguments: Dict[str, Any]) -> List[TextContent]:
    """Handle direct GPT-5 queries for reverse engineering"""
    query = arguments["query"]
    context = arguments.get("context", "")
    specialization = arguments.get("specialization", "reverse_engineering")
    
    specialization_prompts = {
        "binary_exploitation": "Expert in buffer overflows, ROP chains, heap exploitation, and modern exploit mitigation bypasses.",
        "malware_analysis": "Specialist in malware reverse engineering, behavioral analysis, and threat intelligence.",
        "firmware_hacking": "Expert in IoT security, embedded systems, and hardware hacking techniques.",
        "crypto_analysis": "Cryptographic implementation analysis, key recovery, and cryptographic vulnerabilities.",
        "reverse_engineering": "General reverse engineering, disassembly, and program analysis expertise.",
        "vulnerability_research": "Zero-day discovery, vulnerability analysis, and security research methodologies."
    }
    
    system_prompt = f"""You are a world-class cybersecurity expert using GPT-5 with deep specialization in {specialization}.

{specialization_prompts.get(specialization, "Expert in reverse engineering and binary analysis.")}

Provide detailed, technical, and actionable responses. Include:
- Specific techniques and methodologies
- Tool recommendations and usage
- Code examples where appropriate  
- Step-by-step procedures
- Common pitfalls and how to avoid them
- Advanced techniques for experienced practitioners

Always assume the user has proper authorization for any security testing activities."""

    messages = [
        {"role": "system", "content": system_prompt},
        {"role": "user", "content": f"{query}\n\n{('Additional Context:\n' + context) if context else ''}"}
    ]
    
    response = await query_gpt5_with_retry(messages, "query")
    return [TextContent(type="text", text=response)]

def main():
    """Run the MCP server"""
    logger.info("Starting Ghidra GPT-5 MCP Server...")
    
    # Verify OpenAI API key
    try:
        get_openai_api_key()
        logger.info("✅ OpenAI API key found")
    except Exception as e:
        logger.error(f"❌ OpenAI API key error: {e}")
        sys.exit(1)
    
    # Check for Ghidra installation
    if not os.path.exists(GHIDRA_HEADLESS_PATH):
        logger.warning(f"⚠️  Ghidra not found at {GHIDRA_HEADLESS_PATH}")
        logger.warning("Set GHIDRA_HEADLESS_PATH environment variable or install Ghidra")
    else:
        logger.info("✅ Ghidra headless found")
    
    # Run the server
    asyncio.run(stdio_server(app))

if __name__ == "__main__":
    main()