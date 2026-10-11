#!/usr/bin/env bash
# Run the game as a Linux desktop app (WSLg) with hot reload.
# Saving any .dart file under lib/ hot-reloads automatically.
# In this terminal: r = hot reload, R = hot restart, q = quit.
set -euo pipefail
cd "$(dirname "$0")/.."

# WSLg display + sound defaults, for shells that don't set them.
export DISPLAY="${DISPLAY:-:0}"
export WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-0}"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/mnt/wslg/runtime-dir}"
export PULSE_SERVER="${PULSE_SERVER:-unix:/mnt/wslg/PulseServer}"

pidfile=$(mktemp)
stamp=$(mktemp)
rm -f "$pidfile" # flutter creates it once the app is running

# ponytail: polls lib/ every second (no inotify-tools needed); swap for inotifywait if it lags.
(
  while sleep 1; do
    if [[ -s $pidfile ]] && changed=$(find lib -name '*.dart' -newer "$stamp") && [[ -n $changed ]]; then
      touch "$stamp"
      # game.dart holds the live Game/Unit objects: a new field there is null on old objects
      # after a hot reload, so restart instead.
      if grep -q 'lib/game.dart' <<<"$changed"; then
        kill -USR2 "$(cat "$pidfile")" 2>/dev/null && echo "⟳ hot restart (game.dart changed)"
      else
        kill -USR1 "$(cat "$pidfile")" 2>/dev/null && echo "↻ hot reload"
      fi
    fi
  done
) &
watcher=$!
trap 'kill $watcher 2>/dev/null; rm -f "$pidfile" "$stamp"' EXIT

# pub get first: a Windows build rewrites .dart_tool with Windows paths.
flutter pub get
flutter run -d linux --pid-file "$pidfile" "$@"
