#!/usr/bin/env bash
# Build the Windows release from WSL, using the Flutter installed on Windows.
# The project lives on D:, so Windows builds it in place.
# Output: D:\tower-defense\build\windows\x64\runner\Release\tower_defense.exe
set -euo pipefail
cd "$(dirname "$0")/.."

# A running copy locks tower_defense.exe
powershell.exe -NoProfile -Command "Get-Process tower_defense -ErrorAction SilentlyContinue | Stop-Process -Force; Start-Sleep 1"
cd /mnt/c # cmd.exe refuses a WSL (UNC) working directory
# pub get first: Linux and Windows Flutter each rewrite .dart_tool with their own paths.
cmd.exe /c "cd /d D:\tower-defense && C:\src\flutter\bin\flutter.bat pub get && C:\src\flutter\bin\flutter.bat build windows --release" | tr -d '\r'
echo "App: D:\\tower-defense\\build\\windows\\x64\\runner\\Release\\tower_defense.exe"
