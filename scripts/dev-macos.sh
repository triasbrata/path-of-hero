#!/usr/bin/env bash
# Run the game as a macOS desktop app (debug) with hot reload.
# Saving a file under lib/ or assets/ hot-reloads; a change to lib/game.dart hot-restarts
# (a new field there would be null on the live objects after a plain reload).
# In this terminal: r = hot reload, R = hot restart, q = quit. Ctrl+C stops it too.
set -euo pipefail
cd "$(dirname "$0")/.."
command -v flutter >/dev/null || export PATH="$HOME/development/flutter/bin:$PATH"

# One copy of the game at a time (decisions-log 159): any other copy (another build, the release) writes the same
# save. The game quits a later copy itself (macos/Runner/AppDelegate.swift); this also stops for a copy of a build
# from before that guard, and says why before the build instead of after it.
if running=$(pgrep -x tower_defense); then
  echo "Path of Hero already runs. Quit it first (Cmd+Q in its window, or kill <pid>), then start this again:" >&2
  ps -o pid,ppid,command -p "$(paste -sd, - <<<"$running")" >&2
  exit 1
fi

pidfile=$(mktemp)
stamp=$(mktemp)
rm -f "$pidfile" # flutter creates it once the app is running

# ponytail: polls every second (no fswatch needed); swap for fswatch if it lags.
(
  while sleep 1; do
    if [[ -s $pidfile ]] && changed=$(find lib assets -type f -newer "$stamp") && [[ -n $changed ]]; then
      touch "$stamp"
      if grep -q 'lib/game.dart' <<<"$changed"; then
        kill -USR2 "$(cat "$pidfile")" 2>/dev/null && echo "⟳ hot restart (game.dart changed)"
      else
        kill -USR1 "$(cat "$pidfile")" 2>/dev/null && echo "↻ hot reload"
      fi
    fi
  done
) &
# Stops every child, so `pkill -f "[d]ev-macos"` also ends flutter run (which then quits the app
# and deletes its own pid file).
trap 'pkill -P $$ 2>/dev/null; rm -f "$stamp"' EXIT

# Offline first (the pub cache), so a start without the network still runs the game; online only when the
# cache lacks something. A plain `pub get` stopped the start under set -e with "Failed to update packages".
flutter pub get --offline || flutter pub get
flutter run -d macos --pid-file "$pidfile" "$@"
