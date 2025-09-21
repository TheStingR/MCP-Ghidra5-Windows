#!/usr/bin/env python3
"""
Test script for Ghidra GPT-5 MCP Server
Validates functionality without requiring actual binaries

Copyright (c) 2024 TechSquad Inc. - All Rights Reserved
Proprietary Software - NOT FOR RESALE
Coded by: TheStingR

This software is the property of TechSquad Inc. and is protected by copyright law.
Unauthorized reproduction, distribution, or sale is strictly prohibited.
"""

import asyncio
import logging
import os
import sys
from pathlib import Path

# Add the MCP server to path - Dynamic location
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
sys.path.append(SCRIPT_DIR)

async def test_basic_functionality():
    """Test basic MCP server functionality"""
    print("🧪 Testing Ghidra GPT-5 MCP Server")
    print("=" * 50)
    
    try:
        # Import the MCP server
        from ghidra_gpt5_mcp import app, get_openai_api_key, query_gpt5_with_retry
        
        print("✅ MCP server import successful")
        
        # Test API key detection
        try:
            api_key = get_openai_api_key()
            if api_key:
                print(f"✅ OpenAI API key found: {api_key[:10]}...")
            else:
                print("❌ No OpenAI API key found")
                return False
        except Exception as e:
            print(f"❌ API key error: {e}")
            return False
        
        # Test GPT-5 query function
        print("\n🧠 Testing GPT-5 query functionality...")
        try:
            messages = [
                {"role": "system", "content": "You are a helpful assistant."},
                {"role": "user", "content": "What is reverse engineering? Respond in one sentence."}
            ]
            
            response = await query_gpt5_with_retry(messages, "query")
            if response and len(response) > 10:
                print("✅ GPT-5 query successful")
                print(f"📝 Response preview: {response[:100]}...")
            else:
                print("❌ GPT-5 query failed or empty response")
                return False
                
        except Exception as e:
            print(f"❌ GPT-5 query error: {e}")
            return False
        
        # Test tool listing
        print("\n🛠️  Testing MCP tool listing...")
        try:
            from ghidra_gpt5_mcp import handle_list_tools
            tools = await handle_list_tools()
            tool_names = [tool.name for tool in tools]
            
            expected_tools = [
                'ghidra_binary_analysis',
                'ghidra_function_analysis', 
                'ghidra_exploit_development',
                'ghidra_malware_analysis',
                'ghidra_firmware_analysis',
                'ghidra_code_pattern_search',
                'gpt5_reverse_engineering_query'
            ]
            
            missing_tools = [tool for tool in expected_tools if tool not in tool_names]
            if missing_tools:
                print(f"❌ Missing tools: {missing_tools}")
                return False
            else:
                print(f"✅ All {len(expected_tools)} tools available")
                print(f"📋 Tools: {', '.join(tool_names)}")
                
        except Exception as e:
            print(f"❌ Tool listing error: {e}")
            return False
            
        # Test direct query tool
        print("\n💬 Testing direct GPT-5 query tool...")
        try:
            from ghidra_gpt5_mcp import handle_gpt5_query
            
            arguments = {
                "query": "What are the main steps in binary analysis?",
                "specialization": "reverse_engineering"
            }
            
            result = await handle_gpt5_query(arguments)
            if result and len(result) > 0 and result[0].text:
                print("✅ Direct query tool working")
                print(f"📝 Response preview: {result[0].text[:150]}...")
            else:
                print("❌ Direct query tool failed")
                return False
                
        except Exception as e:
            print(f"❌ Direct query tool error: {e}")
            return False
        
        print("\n🎉 All tests passed! Ghidra GPT-5 MCP Server is ready.")
        return True
        
    except ImportError as e:
        print(f"❌ Import error: {e}")
        print("💡 Make sure all dependencies are installed: pip install mcp aiohttp")
        return False
    except Exception as e:
        print(f"❌ Unexpected error: {e}")
        return False

def check_environment():
    """Check environment setup"""
    print("🔍 Environment Check")
    print("-" * 20)
    
    # Check Python version
    python_version = sys.version_info
    if python_version >= (3, 8):
        print(f"✅ Python {python_version.major}.{python_version.minor}.{python_version.micro}")
    else:
        print(f"❌ Python {python_version.major}.{python_version.minor}.{python_version.micro} (need 3.8+)")
        return False
    
    # Check required packages
    required_packages = ['mcp', 'aiohttp']
    missing_packages = []
    
    for package in required_packages:
        try:
            __import__(package)
            print(f"✅ {package} available")
        except ImportError:
            print(f"❌ {package} missing")
            missing_packages.append(package)
    
    if missing_packages:
        print(f"💡 Install missing packages: pip install {' '.join(missing_packages)}")
        return False
    
    # Check API key
    api_key = os.environ.get('OPENAI_API_KEY') or os.environ.get('CHATGPT_COOKIE')
    if api_key and api_key.startswith('sk-'):
        print("✅ OpenAI API key configured")
    else:
        print("❌ OpenAI API key not found")
        print("💡 Set OPENAI_API_KEY environment variable")
        return False
    
    # Check Ghidra (optional)
    ghidra_paths = [
        os.environ.get('GHIDRA_HEADLESS_PATH'),
        '/opt/ghidra/support/analyzeHeadless',
        '/usr/local/ghidra/support/analyzeHeadless'
    ]
    
    ghidra_found = False
    for path in ghidra_paths:
        if path and os.path.exists(path):
            print(f"✅ Ghidra found: {path}")
            ghidra_found = True
            break
    
    if not ghidra_found:
        print("⚠️  Ghidra not found (optional for some features)")
        print("💡 Install Ghidra or set GHIDRA_HEADLESS_PATH")
    
    print()
    return True

async def main():
    """Main test function"""
    print("🚀 Ghidra GPT-5 MCP Server Test Suite")
    print("=" * 60)
    print()
    
    # Environment check
    if not check_environment():
        print("❌ Environment check failed. Please fix issues and retry.")
        sys.exit(1)
    
    # Functionality test
    if await test_basic_functionality():
        print("\n" + "=" * 60)
        print("🎯 SUCCESS: Ghidra GPT-5 MCP Server is ready for deployment!")
        print("\nNext steps:")
        print("1. Add server to Warp Terminal MCP configuration")
        print("2. Restart Warp Terminal")  
        print("3. Test with: call_mcp_tool('gpt5_reverse_engineering_query', {'query': 'test'})")
        sys.exit(0)
    else:
        print("\n" + "=" * 60)
        print("❌ FAILED: Please fix the issues above and retry.")
        sys.exit(1)

if __name__ == "__main__":
    asyncio.run(main())