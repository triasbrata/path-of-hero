#!/usr/bin/env bash
# Run the game on Windows (debug) from WSL, with hot reload, straight from D:\tower-defense.
# Saving a file under lib/ or assets/ hot-reloads; a change to lib/game.dart hot-restarts
# (a new field there would be null on the live objects after a plain reload).
# Stop with Ctrl+C (the app window closes too).
set -euo pipefail
cd "$(dirname "$0")/.."

keys=$(mktemp -u)
mkfifo "$keys"
stamp=$(mktemp)

# ponytail: polls every second (no inotify on drvfs); fine for one dev.
(
  exec 3>"$keys" # flutter reads its keystrokes from here: r = hot reload, R = hot restart
  while sleep 1; do
    if changed=$(find lib assets -type f -newer "$stamp") && [[ -n $changed ]]; then
      touch "$stamp"
      if grep -q 'lib/game.dart' <<<"$changed"; then
        printf R >&3 && echo "⟳ hot restart (game.dart changed)"
      else
        printf r >&3 && echo "↻ hot reload"
      fi
    fi
  done
) &
watcher=$!
trap 'kill $watcher 2>/dev/null; rm -f "$keys" "$stamp"; powershell.exe -NoProfile -Command "Get-Process tower_defense -ErrorAction SilentlyContinue | Stop-Process -Force"' EXIT

# A release copy left running would lock the build.
powershell.exe -NoProfile -Command "Get-Process tower_defense -ErrorAction SilentlyContinue | Stop-Process -Force"
cd /mnt/c # cmd.exe refuses a WSL (UNC) working directory
# pub get first: Linux and Windows Flutter each rewrite .dart_tool with their own paths.
cmd.exe /c "cd /d D:\tower-defense && C:\src\flutter\bin\flutter.bat pub get && C:\src\flutter\bin\flutter.bat run -d windows" <"$keys" | sed -u 's/\r$//' # sed -u: tr would hold the log back in its buffer
