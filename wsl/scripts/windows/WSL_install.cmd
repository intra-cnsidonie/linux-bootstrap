@echo off
cd /d "%~dp0"
Powershell -ExecutionPolicy UnRestricted -File "%~dp0install_and_configure_WSL.ps1" -distroName Ubuntu-24.04