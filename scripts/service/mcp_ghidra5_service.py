#!/usr/bin/env python3
"""
MCP-Ghidra5 - Windows Service Implementation

This module provides a Windows service wrapper for the MCP Ghidra5 server,
enabling background operation, automatic startup, and enterprise deployment capabilities.

Copyright (c) 2024 - All Rights Reserved

Requirements:
    - Python 3.8+
    - pywin32 (Windows Service API)
    - psutil (Process monitoring)
    - configparser (Configuration management)
"""

import sys
import os
import time
import signal
import logging
import subprocess
import threading
import json
from pathlib import Path
from datetime import datetime
from typing import Optional, Dict, Any

try:
    import win32serviceutil
    import win32service
    import win32event
    import win32api
    import win32con
    import win32evtlogutil
    import servicemanager
    import psutil
    import configparser
except ImportError as e:
    print(f"Missing required Windows service dependencies: {e}")
    print("Please install: pip install pywin32 psutil configparser")
    sys.exit(1)


class MCPGhidra5Service(win32serviceutil.ServiceFramework):
    """
    MCP Ghidra5 Windows Service
    
    Provides enterprise-grade background operation with:
    - Automatic startup and recovery
    - Health monitoring and restart
    - Configuration management
    - Logging and event reporting
    - Resource monitoring
    - Graceful shutdown handling
    """
    
    # Service configuration
    _svc_name_ = "MCPGhidra5Service"
    _svc_display_name_ = "MCP Ghidra5 Server"
    _svc_description_ = ("AI-powered reverse engineering server with enterprise features. "
                        "Provides MCP (Model Context Protocol) interface for Ghidra integration "
                        "with OpenAI and other AI services.")
    
    # Service behavior
    _exe_name_ = sys.executable
    _exe_args_ = f'"{os.path.abspath(__file__)}"'
    
    # Service dependencies (optional)
    _svc_deps_ = ["EventLog", "Tcpip"]
    
    def __init__(self, args):
        """Initialize the service."""
        win32serviceutil.ServiceFramework.__init__(self, args)
        
        # Service control event
        self.hWaitStop = win32event.CreateEvent(None, 0, 0, None)
        
        # Service state
        self.is_alive = True
        self.server_process = None
        self.monitor_thread = None
        self.restart_count = 0
        self.last_restart = None
        
        # Configuration
        self.config = self._load_configuration()
        
        # Logging setup
        self._setup_logging()
        
        # Paths - updated for new project structure
        self.install_path = self.config.get('paths', 'install_path', 
                                           fallback=r'C:\Program Files\MCP-Ghidra5')
        
        # Try multiple locations for the server script
        possible_server_paths = [
            os.path.join(self.install_path, 'MCP-Ghidra5-Windows', 'src', 'mcp_ghidra_server_windows.py'),
            os.path.join(self.install_path, 'src', 'mcp_ghidra_server_windows.py'),  # Legacy path
            os.path.join(os.path.dirname(os.path.dirname(__file__)), '..', 'src', 'mcp_ghidra_server_windows.py')
        ]
        
        self.server_script = None
        for script_path in possible_server_paths:
            if os.path.exists(script_path):
                self.server_script = script_path
                break
        
        if not self.server_script:
            self.server_script = possible_server_paths[0]  # Default to first path
        self.log_path = self.config.get('paths', 'log_path',
                                       fallback=os.path.join(os.environ.get('PROGRAMDATA', 'C:\\ProgramData'),
                                                           'MCP-Ghidra5', 'Logs'))
        
        # Ensure log directory exists
        os.makedirs(self.log_path, exist_ok=True)
        
    def _load_configuration(self) -> configparser.ConfigParser:
        """Load service configuration from file."""
        config = configparser.ConfigParser()
        
        # Default configuration
        config.read_dict({
            'server': {
                'host': 'localhost',
                'port': '8765',
                'log_level': 'INFO',
                'ghidra_path': '',
                'api_key': '',
                'max_memory_mb': '2048',
                'enable_telemetry': 'true'
            },
            'service': {
                'auto_restart': 'true',
                'restart_delay': '30',
                'max_restarts': '5',
                'restart_window': '3600',
                'health_check_interval': '60',
                'enable_monitoring': 'true'
            },
            'paths': {
                'install_path': r'C:\Program Files\MCP-Ghidra5',
                'log_path': r'C:\ProgramData\MCP-Ghidra5\Logs',
                'config_path': r'C:\ProgramData\MCP-Ghidra5\Config',
                'project_dir': r'C:\ProgramData\MCP-Ghidra5\projects'
            },
            'security': {
                'run_as_system': 'true',
                'enable_firewall': 'true',
                'restrict_network': 'false',
                'log_security_events': 'true'
            }
        })
        
        # Load user configuration if it exists
        config_paths = [
            os.path.join(os.environ.get('PROGRAMDATA', 'C:\\ProgramData'), 
                        'MCP-Ghidra5', 'service.conf'),
            os.path.join(os.path.dirname(__file__), 'service.conf'),
            r'C:\Program Files\MCP-Ghidra5\config\service.conf'
        ]
        
        for config_path in config_paths:
            if os.path.exists(config_path):
                try:
                    config.read(config_path)
                    self._log_info(f"Loaded configuration from: {config_path}")
                    break
                except Exception as e:
                    self._log_error(f"Failed to load config from {config_path}: {e}")
        
        return config
    
    def _setup_logging(self):
        """Setup comprehensive logging for the service."""
        try:
            # Create log directory if it doesn't exist
            log_dir = self.config.get('paths', 'log_path',
                                     fallback=r'C:\ProgramData\MCP-Ghidra5\Logs')
            os.makedirs(log_dir, exist_ok=True)
            
            # Configure logging
            log_file = os.path.join(log_dir, 'service.log')
            log_level = getattr(logging, self.config.get('server', 'log_level', fallback='INFO'))
            
            logging.basicConfig(
                level=log_level,
                format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
                handlers=[
                    logging.FileHandler(log_file, encoding='utf-8'),
                    logging.StreamHandler()
                ]
            )
            
            self.logger = logging.getLogger('MCPGhidra5Service')
            self.logger.info("Service logging initialized")
            
        except Exception as e:
            # Fallback to basic logging
            logging.basicConfig(level=logging.INFO)
            self.logger = logging.getLogger('MCPGhidra5Service')
            self.logger.error(f"Failed to setup advanced logging: {e}")
    
    def _log_info(self, message: str):
        """Log info message to both service log and Windows Event Log."""
        self.logger.info(message)
        try:
            servicemanager.LogInfoMsg(f"{self._svc_display_name_}: {message}")
        except:
            pass
    
    def _log_error(self, message: str):
        """Log error message to both service log and Windows Event Log."""
        self.logger.error(message)
        try:
            servicemanager.LogErrorMsg(f"{self._svc_display_name_}: {message}")
        except:
            pass
    
    def _log_warning(self, message: str):
        """Log warning message to both service log and Windows Event Log."""
        self.logger.warning(message)
        try:
            servicemanager.LogWarningMsg(f"{self._svc_display_name_}: {message}")
        except:
            pass

    def SvcStop(self):
        """Stop the service."""
        self._log_info("Service stop requested")
        
        # Signal the service to stop
        self.ReportServiceStatus(win32service.SERVICE_STOP_PENDING)
        win32event.SetEvent(self.hWaitStop)
        
        # Stop the server process
        self.is_alive = False
        
        if self.server_process:
            try:
                # Attempt graceful shutdown first
                self._log_info("Attempting graceful server shutdown")
                
                # Send SIGTERM for graceful shutdown
                if hasattr(self.server_process, 'terminate'):
                    self.server_process.terminate()
                    
                    # Wait for graceful shutdown
                    shutdown_timeout = self.config.getint('service', 'shutdown_timeout', fallback=15)
                    try:
                        self.server_process.wait(timeout=shutdown_timeout)
                        self._log_info("Server shut down gracefully")
                    except subprocess.TimeoutExpired:
                        self._log_warning("Server did not shut down gracefully, forcing termination")
                        self.server_process.kill()
                        
            except Exception as e:
                self._log_error(f"Error during server shutdown: {e}")
        
        # Wait for monitor thread to finish
        if self.monitor_thread and self.monitor_thread.is_alive():
            self.monitor_thread.join(timeout=5)
            
        self._log_info("Service stopped")

    def SvcDoRun(self):
        """Main service execution."""
        self._log_info("MCP Ghidra5 Service starting...")
        
        try:
            # Report running status
            self.ReportServiceStatus(win32service.SERVICE_RUNNING)
            
            # Start the server
            self._start_server()
            
            # Start monitoring thread if enabled
            if self.config.getboolean('service', 'enable_monitoring', fallback=True):
                self.monitor_thread = threading.Thread(target=self._monitor_server, daemon=True)
                self.monitor_thread.start()
                self._log_info("Server monitoring started")
            
            # Main service loop
            while self.is_alive:
                # Wait for stop event or timeout for periodic tasks
                wait_result = win32event.WaitForSingleObject(
                    self.hWaitStop, 
                    30000  # 30 seconds
                )
                
                if wait_result == win32event.WAIT_OBJECT_0:
                    # Stop event was signaled
                    break
                    
                # Perform periodic health checks
                self._periodic_health_check()
            
        except Exception as e:
            self._log_error(f"Service execution error: {e}")
            raise
        finally:
            self._log_info("Service execution completed")

    def _start_server(self):
        """Start the MCP Ghidra5 server process."""
        try:
            # Build command
            python_exe = sys.executable
            server_script = self.server_script
            
            if not os.path.exists(server_script):
                # Try alternative paths
                alternative_paths = [
                    os.path.join(self.install_path, 'mcp_ghidra_server_windows.py'),
                    os.path.join(os.path.dirname(__file__), '..', 'src', 'mcp_ghidra_server_windows.py'),
                    os.path.join(os.path.dirname(__file__), '..', 'mcp_ghidra_server_windows.py'),
                    # Fallback to alternative server
                    os.path.join(self.install_path, 'src', 'ghidra_gpt5_mcp.py'),
                    os.path.join(os.path.dirname(__file__), '..', 'src', 'ghidra_gpt5_mcp.py')
                ]
                
                for alt_path in alternative_paths:
                    if os.path.exists(alt_path):
                        server_script = alt_path
                        break
                else:
                    raise FileNotFoundError(f"Server script not found: {server_script}")
            
            # Environment variables - align with server expectations
            env = os.environ.copy()
            env.update({
                # Server expects these environment variables
                'GHIDRA_HEADLESS_PATH': self.config.get('server', 'ghidra_path', fallback=''),
                'GHIDRA_PROJECT_DIR': self.config.get('paths', 'project_dir', 
                                                    fallback=os.path.join(os.environ.get('PROGRAMDATA', 'C:\\ProgramData'), 
                                                                         'MCP-Ghidra5', 'projects')),
                # Keep MCP ones for compatibility
                'MCP_GHIDRA5_HOST': self.config.get('server', 'host', fallback='localhost'),
                'MCP_GHIDRA5_PORT': self.config.get('server', 'port', fallback='8765'),
                'MCP_GHIDRA5_LOG_LEVEL': self.config.get('server', 'log_level', fallback='INFO'),
                # Legacy compatibility
                'GHIDRA_INSTALL_DIR': self.config.get('server', 'ghidra_path', fallback=''),
            })
            
            # Add API key if configured
            api_key = self.config.get('server', 'api_key', fallback='')
            if api_key:
                env['OPENAI_API_KEY'] = api_key
            
            # Start the server process
            cmd = [python_exe, server_script]
            self._log_info(f"Starting server: {' '.join(cmd)}")
            
            self.server_process = subprocess.Popen(
                cmd,
                env=env,
                cwd=os.path.dirname(server_script),
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                creationflags=win32con.CREATE_NO_WINDOW
            )
            
            self._log_info(f"Server started with PID: {self.server_process.pid}")
            
        except Exception as e:
            self._log_error(f"Failed to start server: {e}")
            raise

    def _monitor_server(self):
        """Monitor server process and restart if necessary."""
        self._log_info("Server monitoring thread started")
        
        while self.is_alive:
            try:
                if self.server_process and self.server_process.poll() is not None:
                    # Process has terminated
                    exit_code = self.server_process.returncode
                    self._log_error(f"Server process terminated with exit code: {exit_code}")
                    
                    if self.config.getboolean('service', 'auto_restart', fallback=True):
                        self._handle_server_restart()
                    else:
                        self._log_info("Auto-restart disabled, stopping service")
                        self.SvcStop()
                        break
                
                # Health check interval
                interval = self.config.getint('service', 'health_check_interval', fallback=60)
                time.sleep(interval)
                
            except Exception as e:
                self._log_error(f"Error in server monitoring: {e}")
                time.sleep(30)  # Wait before retrying
        
        self._log_info("Server monitoring thread stopped")

    def _handle_server_restart(self):
        """Handle server process restart with backoff logic."""
        current_time = datetime.now()
        
        # Check restart window
        restart_window = self.config.getint('service', 'restart_window', fallback=3600)  # 1 hour
        if (self.last_restart and 
            (current_time - self.last_restart).seconds < restart_window):
            self.restart_count += 1
        else:
            # Reset restart count if outside window
            self.restart_count = 1
        
        max_restarts = self.config.getint('service', 'max_restarts', fallback=5)
        
        if self.restart_count > max_restarts:
            self._log_error(f"Maximum restarts ({max_restarts}) exceeded in {restart_window}s window. Stopping service.")
            self.SvcStop()
            return
        
        # Calculate restart delay with exponential backoff
        base_delay = self.config.getint('service', 'restart_delay', fallback=30)
        restart_delay = min(base_delay * (2 ** (self.restart_count - 1)), 300)  # Max 5 minutes
        
        self._log_info(f"Restarting server in {restart_delay} seconds (attempt {self.restart_count})")
        time.sleep(restart_delay)
        
        try:
            # Clean up old process
            if self.server_process:
                try:
                    self.server_process.kill()
                except:
                    pass
            
            # Start new process
            self._start_server()
            self.last_restart = current_time
            
            self._log_info(f"Server restarted successfully (attempt {self.restart_count})")
            
        except Exception as e:
            self._log_error(f"Failed to restart server: {e}")

    def _periodic_health_check(self):
        """Perform periodic health checks."""
        try:
            if self.server_process:
                # Check if process is still running
                if self.server_process.poll() is None:
                    # Get process info using psutil for detailed monitoring
                    try:
                        proc = psutil.Process(self.server_process.pid)
                        
                        # Check memory usage
                        memory_mb = proc.memory_info().rss / (1024 * 1024)
                        max_memory = self.config.getint('server', 'max_memory_mb', fallback=2048)
                        
                        if memory_mb > max_memory:
                            self._log_warning(f"Server memory usage ({memory_mb:.1f}MB) exceeds limit ({max_memory}MB)")
                        
                        # Check CPU usage (averaged over last minute)
                        cpu_percent = proc.cpu_percent()
                        if cpu_percent > 80:  # High CPU threshold
                            self._log_warning(f"High server CPU usage: {cpu_percent:.1f}%")
                            
                    except psutil.NoSuchProcess:
                        self._log_error("Server process no longer exists")
                    except Exception as e:
                        self._log_warning(f"Error getting process info: {e}")
            
        except Exception as e:
            self._log_error(f"Error in health check: {e}")

    def _get_service_status(self) -> Dict[str, Any]:
        """Get comprehensive service status information."""
        status = {
            'service_name': self._svc_name_,
            'display_name': self._svc_display_name_,
            'status': 'Running' if self.is_alive else 'Stopped',
            'restart_count': self.restart_count,
            'last_restart': self.last_restart.isoformat() if self.last_restart else None,
            'server_process': None
        }
        
        if self.server_process:
            try:
                proc = psutil.Process(self.server_process.pid)
                status['server_process'] = {
                    'pid': self.server_process.pid,
                    'status': proc.status(),
                    'memory_mb': round(proc.memory_info().rss / (1024 * 1024), 2),
                    'cpu_percent': proc.cpu_percent(),
                    'create_time': datetime.fromtimestamp(proc.create_time()).isoformat(),
                    'num_threads': proc.num_threads()
                }
            except (psutil.NoSuchProcess, Exception) as e:
                status['server_process'] = {'error': str(e)}
        
        return status


def main():
    """Main entry point for service installation and management."""
    if len(sys.argv) == 1:
        # Run as service
        servicemanager.Initialize()
        servicemanager.PrepareToHostSingle(MCPGhidra5Service)
        servicemanager.StartServiceCtrlDispatcher()
    else:
        # Handle command line arguments
        win32serviceutil.HandleCommandLine(MCPGhidra5Service)


if __name__ == '__main__':
    main()