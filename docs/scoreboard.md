# Scoreboard

Purpose: how the score is counted, where finished games' scores are kept (the storage adapters), and the
score server's HTTP contract.

The owner: "tambahkan score dan score board, untuk backendnya nanti pakai server tapi dibuat ada adapternya
untuk bisa pakai local dan server http call, jadi walaupun servernya belum siap bisa pakai adapter localnya
dulu untuk tulis score player ke board". The screens are in [ui-hud.md](ui-hud.md#scoreboard-libscoreboarddart).

## The score (`Game.score`, lib/game.dart)

| Points | When |
|---|---|
| `killScore[tier]`: normal 10, elite 25, highElite 50, miniBoss 150, boss 500 | Every monster killed (`_hurt`), by its rank. The boss's raised skeletons (`cost` 0) score 0, like their gold. |
| `waveScore` × n (100·n) | Winning wave n (beside the gold bonus). |

- The lives left no longer score (decisions-log 329). Until then `lifeScore` paid 50 a life in the tick the game ended;
  since decisions-log 322 a game ends only at 0 lives (an army wiped costs a heart and the wave is played again), so it
  paid nothing. The guide's Goal topic says "Score: kills and waves won."
- `Game.kills` counts every monster killed, raised skeletons included. It goes on the board beside the score.
- Both are in the save (`score`, `kills`); a save from before them loads with 0.
- The score only shows at game over and on the board (no live counter; the owner can ask for one).

## Entries and adapters (lib/scores.dart, pure Dart)

- `ScoreEntry {name, score, wave, kills, at}`. `at` is when the game ended, UTC, cut to whole
  milliseconds so an entry that went through JSON compares equal (`==` covers every field; the board
  lights the player's own entry that way).
  - `cleanName`: control characters out, trimmed, cut to `maxName` 12 characters; empty → `defaultName`
    "Player" ("Pemain" until decisions-log 193; an entry saved under it keeps it).
  - Board order `byRank`: the higher score first; on a tie, the earlier game.
- `ScoreRepository`: `submit(entry)`, `top(limit: 10)` (best first), and `offline` (the last call was
  answered from this device instead of the server).

| Adapter | What it does |
|---|---|
| `LocalScoreRepository` | `scores.json` in the game's folder (`dataFile`, beside save.json): a JSON list, the best `keep` 100. Calls run one at a time; a write goes through `scores.json.tmp` + rename; a missing or broken file reads as an empty board (and is replaced on the next submit). |
| `HttpScoreRepository(baseUrl)` | The server (contract below), dart:io `HttpClient`. Any failure throws `ScoreServerException`. |
| `ServerScoreRepository(server, local, outbox)` | What the game uses when a server is set. Every entry goes to `local` too. An entry the server didn't take waits in `scores_outbox.json` and `offline` turns true (no throw); every later call first sends the outbox, oldest first, stopping at the first failure. A failing `top` answers `local.top` with `offline` true. |

- `scoreRepository()` picks the adapter from `SCORE_SERVER`, a build-time define: empty (the default) →
  `LocalScoreRepository`; a URL → `ServerScoreRepository(HttpScoreRepository(url), LocalScoreRepository(),
  scores_outbox.json)`. Example: `flutter run -d macos --dart-define=SCORE_SERVER=https://example.com/td`
  (`scripts/dev-macos.sh` passes extra arguments to `flutter run`).
- The player's name: `player.json` beside save.json, `{"name": "Budi"}` (`loadPlayerName` /
  `savePlayerName`; a broken file means it is asked again). "Play again" and "New Game" don't touch it,
  scores.json or the outbox.
- **macOS:** the App Sandbox blocks outgoing connections until `com.apple.security.network.client` is
  `true` in `macos/Runner/DebugProfile.entitlements` and `Release.entitlements`. It isn't there yet (no
  server yet); without it a server build falls back to this device with "Server not available".

## Server contract

Base URL = `SCORE_SERVER` without trailing slashes. JSON in UTF-8. Every call has 5 s in all
(connecting, sending, reading the answer).

- **Submit:** `POST {base}/scores`, `Content-Type: application/json`, `Accept: application/json`, body
  one entry:

  ```json
  {"name": "Budi", "score": 1234, "wave": 7, "kills": 52, "at": "2026-09-27T10:11:12.345Z"}
  ```

  Any 2xx means taken (the body is ignored). Anything else, or no answer in time, and the entry stays in
  the outbox to be sent again.
- **Top:** `GET {base}/scores?limit=10`, `Accept: application/json` → `200` with a JSON array of such
  entries, best first. The game sorts and cuts it again. Items that aren't an entry are skipped; a
  non-array or another status counts as the server being down.
- The server should treat (`name`, `at`, `score`) as an entry's identity and answer a repeat with 2xx
  without adding it again: a POST that was taken but whose answer timed out is sent again.
