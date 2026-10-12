# Testing

Purpose: how tests are written and run, and how to check visuals.

## Running them

`flutter test -x art` runs the suite on the placeholder art ("Placeholder art" below), and `flutter analyze` the
analyzer. Baseline: every test passes, and `flutter analyze` reports 8 `info`s, all
`avoid_renaming_method_parameters` on `Board`'s overrides in `lib/main.dart` (`s`, `e`, `c`), and exits 1 because of
them. Anything beyond those is new.

Throwaway probes (screenshots, balance runs) stay out of `test/`, where the suite and git would pick them up: name
them `test/probe_*.dart` in a copy of the repo of your own. Seed every die in them, and a loaded game's `heroes` in
`fromJson` itself: `Game(Random(s), Random(s + 100))` or `Game.fromJson(save, Random(s), Random(s + 100),
Random(s + 300))`, then `..loot` and `..slots` (and a new game's `..heroes`) by cascade. With a fixed dt
(`tick(1 / 30)`) nothing else in `lib/` feeds play (determinism_test.dart).

## The test windows

The game is landscape only (decisions-log 289). Widget tests run at 1600×947 (the owner's window), 1266×713 (the desk),
1164×777 (the owner's tablet) and 915×412 (a phone held sideways), and 320 px tall (568×320) where a window too narrow
is the point. A suite test that pumps `GameWidget` directly never uses a size taller than wide: the letterbox's
412×860, 390×844 and 700×900 go through `gameRoot`, laid out at 915×610 (915 px wide at the least; letterbox_test.dart).

## Conventions in test/game_test.dart

| Helper | What it does |
|---|---|
| `wide()` | A `Game` with capacity 6 × rows, so the 6-column deploy zone that most fixtures place into. |
| `bare()` | A `wide()` game without the free healer. |
| `placeNow(g, type, c, r)` | `place()`, then the troop stands on its cell at once (`pos = post`, `entered = true`, `arriving = false`), for tests that don't test marching in. |
| `winWave`, `run`, `hold` | Drive waves and time. `hold` = a `busyUntil` that keeps a unit still. |
| `_Dice` | A `Random` stub for `g.loot` (fixed roll; `nextInt` wraps its pick). As `g.slots` (`_Dice(0, 0)`) it makes the boss the necromancer, for tests that need its summoning (#58: the boss slot is any type otherwise), on a boss wave from `necroBossFrom` (`necroBossWave`, wave 10: before it the roll gives the pool's first type, decisions-log 176). |
| `tempDir()` | A new temp folder for one test's files, deleted after it. |
| `_FakeServer` | A `ScoreRepository` that records what it takes, can be `down` or `refuse` one entry. |
| `_SpyPolicy` | A `RetreatPolicy` that always answers one `RetreatAction` and keeps every `RetreatFeatures` it was asked about (`Game.retreatPolicy`). |

- A game's dice: `rng` (the waves), `names`, `loot`, `heroes`, `slots` (the boss's and mini boss's types, #58).
  The constructor takes `rng` and `names`, `fromJson` `heroes` too (what it rolls for an older save's Heroes);
  the rest are set by a cascade. A test that compares waves or needs a slot's type seeds `slots` too (the
  `queues` helper does).
- Every game plays the rules players play, a plain `Game()` too: the Towns, the forge and the Tavern (decisions-log
  321; `boardRules()` adds the board's limits, chest and wind-ups). test/real_rules.dart holds what such tests share:
  `awakenItems(type, level)`, the items that make a type that Awaken level (its grade sets, `Game.awakenNeeds`), and
  `noTowns`, Town rules whose every roll misses, for a test that must never meet a Town (a long run whose waves must
  start by themselves).
- Test names are plain sentences describing the behaviour.
- #48's parallel branches each keep their tests in a file of their own, so they don't collide:
  `test/hero_shots_test.dart` (branch 2b: the special shots and ground objects, and the eight skills built
  from them), with the shared helpers below and a few of its own (`field()`, `troopAt`, `ticks`, `after`).
- `Welcome` (lib/save.dart) tests always pass `discard:` (a counter); the default is the real
  `clearSave`, which deletes the owner's save file.
- Scoreboard tests (lib/scores.dart) keep every file in a `tempDir()`, never the default `dataFile`
  paths, and talk HTTP only to a local `HttpServer` bound to 127.0.0.1 on a free port.

## The Hero skill tests (#48)

Each Hero skill branch writes its own tests in its own file, so parallel branches never collide in one:
`test/hero_skills_test.dart` (the core: roll, save, casting, the effect store's hooks, the simple skills),
`test/hero_guard_test.dart` (branch 2c: the ten that change the damage rules or what units do),
`test/hero_rare_test.dart` (branch 3: Resurrection and Slime Hex),
`test/hero_moves_test.dart`, `test/hero_shots_test.dart`, and so on. The monster skills (#59) do the same:
`test/monster_skills_test.dart`, with helpers of its own (`casterAt`: a wave on and a monster that walks and
casts but never strikes; `troopAt`: a troop that stands still; `landCast`: ticks through a wind-up to the
cast); branch 2a's are in `test/monster_skill_moves_test.dart`, with copies of those helpers (and `windUp`,
which stops at the wind-up), and 2b's in `test/monster_skill_signatures_test.dart`; the mini-boss skills
and the moments (#59 branch 3) are in `test/boss_skills_test.dart`
(`bossAt`: a wave on and a monster that casts but never strikes, summons nor walks;
`standing`; `lands`: ticks until a given skill has landed; `begun`: the skills the log saw begun). They share
`test/hero_skill_helpers.dart`:

| Helper | What it does |
|---|---|
| `bareGame()` | A game without the free healer, a 6-column zone and gold to spare. |
| `placeNow(g, type, c, r)` | Buys the troop and stands it on its cell at once; returns it. |
| `foeAt(g, type, at, [tier])` | A monster of the game's wave on the field at `at` that never moves or fights on its own (`hold`). |
| `heroCaster(skill)` | A wave begun with nothing to spawn and a Hero of the skill's type at cell (2, 3) holding it with full MP; it never strikes on its own and the #10 skills are off, so what happens is its Hero skill's doing. |
| `runFor(g, s)` | Ticks by 0.05 s until `s` seconds have passed. Never where the game can end: a game over (or a pause) stops `tick`'s clock. It used to spin then until the queue's 15-min timeout (#60's first events test; a Shadow test's troop bled to death, decisions-log 208); now it fails at once ("runFor: the clock stopped"). Step a bounded number of ticks until what you wait for instead (`tickUntil` in events_test.dart). |
| `hold` | A `busyUntil` that keeps a unit still. |

`test/troop_skill_fx_test.dart` (#81) pins each troop skill's own look: `skillScene(type)` stands a troop of
the type at cell (2, 3) with full MP, never striking, in the scene its skill casts in by its own rule on the next
tick (foes that outlive its blows, `sturdyFoe`; hurt or fighting allies for the priest and the templar), and
each test checks the ring, beam or zone its cast leaves and that it goes when its time is up. Its last test boots
one `TdGame` and draws every scene for 1.1 s with no exception. The offscreen sheet of the nine looks came from a
probe that imports `skillScene` (the #81 report). Its very last test draws every monster skill's wind-up tell
(decisions-log 171) at all three ranks, the skill set winding by hand.

`test/wind_tell_test.dart` pins the tell's rules: `casting(skill, type, tier)` stands a monster that never strikes,
summons nor walks, its skill's clock ready and its other one waiting (a moment's boss at 40% HP); `troop(g, u, type,
dx, [dy])` a troop that far to its left; `markedThenLanded` ticks to the wind-up, reads `Game.windTargetsOf`, then
ticks to the landing. Each single-target skill has a decoy it must pass over. The last test plays the w86 fixture's
next wave twice from the same seeds, one asking every tick, and compares the two. The shots are
`test/probe_wind_tell_shots.dart` (not part of the suite).

`test/landing_look_test.dart` pins the champions' landing looks (decisions-log 175) with the same kind of `casting` and
`troop`, and `land` (ticks to the wind-up, then to the landing): the ring each of the five leaves (`ringsOf`), the
bursts queued at a spot (`burstsAt`: `Game.impacts`, which nothing drains without a board), Blade Dance's spins counted
cut by cut, and Ground Slam's whole landing compared with what it was. Its last test plays the w86 fixture's next wave
twice from the same seeds, once alone and once on a booted board that draws the field after every tick (the game
paused between ticks, so the board's own clock never moves it; the view's width and the Pusaka note as the board
leaves them), and compares the two. The shots are `test/probe_landing_shots.dart` (not part of the suite): the five
at 1266×713 and 412×860 at all three ranks, each beside a troop skill's look from the same kind of sheet (Arrow Rain,
Hold Fast, Circle Slash, Crushing Blow), with 3× crops, then the fixture's first three landings of the five.

`test/zone_look_test.dart` pins the looks kept at the units' pixel size (decisions-log 177): `reachDashes` (the ring
round a reach wider than twice the ground circle) gives 20 dashes the size of their squares in the frame, on its
pixels and on its ring, laid where the frame draws them at the circle's own size, pushed out to the reach all round
and evenly spaced wider, and back in place after a whole turn. A booted board draws Singularity's wells at every
Bangkit, their collapses, the wide rings and zones and Skyfall's landing shadow over their lives with no exception.
The last two tests play the w86 and the w89 fixtures' next waves (the w89's Bangkit-5 wizards open wells) twice from
the same seeds, headless and drawn every tick as landing_look_test.dart does, and compare the two. The shots are
`test/probe_zone_shots.dart` (not part of the suite; `SECTION=gallery`: each look alone in the field's middle with a
knight and an orc standing in it, at 20/50/80% of its time; `SECTION=fight`: the w89 fixture's next wave, its first
well 1 s and 2 s in and its collapse), at 1266×713 and 412×860, each printing a `CROP` line for its zoomed crop.

`test/awaken_skills_test.dart` (#88) pins the awakening skills: `awakenScene(type, level)` gives a bare game the
type's recipe `level` times over (`recipe`), stands one at cell (2, 3) with full MP, its #10 skill on hold and the
Hero and monster skills off, and begins a wave with nothing to spawn; `bigFoe` puts a sturdy monster by it. The
shared tests pin the table of costs, the one cast a tick, the MP rule (the awakening skill first when the MP pays
only one, the #10 skill first when it pays both), the think interval, a Hero saving up, the stagger at a wave's
start and at the moment mid-wave, the level's cache under the book's try-ons, the book's lines, the log and the
telemetry; then each built skill's rule and numbers per level (Disarm's 30 s window, decisions-log 156: a foe
Disarmed isn't Disarmed again inside it, by a second soldier either, while that one strikes a second foe, and the
first is again once its 30 s are over). The movers (branch 2) are timed on small ticks
(`cutsOver`: which foe lost HP on which tick): Phantom Rush's cut order round its round, 0.2 s apart, back home, the
cut Rampage adds (Rampage casting first) and the one kill bonus; Skyfall's spot held back to the troop fighting
there, its blow and guard as it lands, two axemen on two crowds, and Crushing Blow's half stun on a mini boss;
Lifeline's dying-and-engaged rule, the lift beside the priest and its heal, `waitFrom`, two lifts at Bangkit 3 held
at the back line, and no heal once its priest has fallen; and the book's lines with two decimals. Its last test
boots one `TdGame` and draws each built skill cast at Bangkit 3 for 70 frames, with no exception (Skyfall with its
foes ahead round a fighting soldier, Lifeline with a dying soldier).

Branch 3's skills there (#88) act on the monsters' own rules. Impale's tests set a monster's wind-up by hand
(`winder`: a high-elite elite orc winding up Brutal Swing past the lancer's reach): the break ends it and leaves its
cooldown, the 0.3 s stagger (a mini boss half), the 25 s window, never the boss rank, a necromancer (the escort's
high elite too) or a once-only skill (pinned instead), the pin's pick and its 0.1× / 0.55× walk (two walkers side by
side, and at their own pace in a march), the 3 s hold for a break and the march. Spellbreaker's strip what monsters
gave a foe and keep what troops gave it, halve a mini boss's, the boss's and the boss's gift once (each landing timed
by its rune ring's `since`), leave a real Frenzy to come below half HP, spread at Bangkit 2 and 3, and wait while
an arrow flies. Singularity's measure the drift tick by tick (never toward the base, the boss not at all, a mini
boss half, only sideways for a monster with a troop at exactly its reach), two wells sharing a monster, and the
burst with the wave marching so nothing moves. The field test gives Spellbreaker a War Shout to strip and
Singularity a fourth foe (`castable`).

`test/monster_moves_test.dart` (#59's groundwork) pins #48's pieces working monster on troop: weaken and
vulnerable on a troop, a troop knocked back, dragged, leapt on and charged through, `stunTroop`'s limits,
`Beam.between` and the rings. Its own `troop()` stands a troop that never walks or strikes unless let
(`strikeOnce`), so only what carries it moves it.

## Where the tests' files go: a temp dir per test file (decisions-log 144)

A `Board` writes into the game's folder (`dataFile`, lib/save.dart): the game when it sees a wave won (`saveGame` in
`Board.update`) or goes to the background between waves (`lifecycleStateChange`), settings.json when a setting
changes (the volumes, Auto, the minimap), and at a game over the player's name and the score; and the telemetry (#64)
its install id in settings.json once a game is played, and telemetry.jsonl at each wave's end.

- **Each test file has a folder of its own.** `test/flutter_test_config.dart` (Flutter runs its `testExecutable`
  around every test file's `main()`) points `testDataDir` (lib/save.dart, `@visibleForTesting`, null in the app) at a
  fresh temp dir, `$TMPDIR/td_data_XXXXXX`, and deletes it after the file's last test. `dataFile` uses it before
  `dataDirFor`, so save.json, settings.json, the scores, player.json and telemetry.jsonl all go there, and no test
  ever reaches HOME's `~/.local/share/tower_defense` (or the macOS app's sandboxed save, dev-workflow.md). It applies
  to every test file and probe under `test/` by itself; nothing in a test sets it up.
- **Why:** `flutter test` runs test files at once, each in a process of its own, and they used to share the job's one
  HOME. Eleven files boot a `TdGame`, which saves settings.json (the install id, and any toggle a test presses), so
  one file's load-then-save could overwrite another's: hud_test's start-button test pressed Auto and read it back off
  (`(true, false)`, necro-pair's suites of 2026-10-02).
- **Within one file** the files stay from test to test (hud_test's `boot` folds the minimap because an earlier test
  may have saved it open). A test that needs a file of its own passes one (`tempDir()`, `saveGame(g, file)`,
  `loadSettings(file)`), as the settings and scoreboard tests do.
- A test that reads the app's real paths (save_test's `initDataDir`) sets `testDataDir = null` for itself and puts it
  back in a tear-down; it only computes paths there and writes nothing.
- data_dir_test.dart pins it: the folder is a `td_data_` temp dir, not under `~/.local/share`, and the game, the
  settings and the scores go there; a second folder (what the next file gets) starts empty, and settings saved in one
  aren't seen in the other.
- **The queue's own HOME stays** as a second fence (its PROTOCOL.md, #53: one per project dir, emptied before and
  after every job): the log's `[test-runner] files the job wrote in its own HOME` line now lists none of the game's
  files. Found in #49, when probes still ran with the owner's HOME and had left a save there.

## test/sprites_test.dart: the images built at load

The rules are tested in `test/game_test.dart` on a plain `Game`. What `TdGame.onLoad` builds in memory
needs the asset bundle and image decoding, so it has its own file, a widget test that boots one
`TdGame` in a `GameWidget` (the offscreen probes' loop below: `runAsync` a 20 ms wait, pump, until
loaded) and reads the images back from `game.images`.

- Every troop's strips (`tiny_<type>_{idle,walk,attack,hurt,death}.png`, what the field and the drag
  ghost draw) have no pixel of the pack's shadow colour (83,69,69) in the shadow rows 55-59, and every
  shadow file does: one shadow per troop (issue #11, assets.md). It first checks that the Soldier's
  file still has its baked shadow, so the test keeps meaning something. Without the Soldier's clearing
  in `onLoad` it fails on 276 pixels of `tiny_soldier_idle.png`.
- One `TdGame` per widget test, as for the probes (a second one's `onLoad` re-adds the in-memory images).

## Placeholder art: `flutter test -x art` (decisions-log 157)

A clone of the public repo has placeholders in place of the licensed art (assets.md "Placeholder art"), and runs
`python3 tool/gen_placeholders.py && flutter test -x art`.

- **The `art` tag** (dart_test.yaml) marks a test that needs the real art under `assets/`: asset_manifest_test.dart's
  "the manifest and assets.sha256 hold every licensed file's bytes", and draft_hud_test.dart's "a card's frame is the
  page card recoloured by its rarity…", which reads the frame's colours off the screen (the export's check 9 found it
  failing on placeholders, decisions-log 160); forge_data_test.dart's "icons: one file each, 32x32, all different"
  (two placeholders may be one drawing) and wizard_fx_test.dart's "the attack 2 strip (Arcane Blast's cast) glows in
  the star's blues" (the pack's own colours), which a placeholder run of the public tree found on 2026-10-11
  (decisions-log 315). Tag a new test that reads the art's own pixels or bytes (a colour, a
  bound, a hash) `tags: 'art'`, or a whole file with `@Tags(['art'])` above `library;`.
- **Measured on 2026-10-02**, the whole suite (939 tests) on a placeholder mirror failed only that test (queue job
  `public-placeholders-1790904831-ph-full`). sprites_test.dart and the layout tests (hud_test, drop_popup_test,
  relic_slots_ui_test and the rest) pass: they need the images' sizes, frame grids and the shadow rule, which the
  placeholders keep, and the font, which is not a placeholder (the mirror kept the real one, as a public repo keeps
  the open Poh Sans and its source, decisions-log 158 and 179).
- **The proof, on a mirror** (made with `git archive`, never a plain copy): `git archive HEAD | tar -x -C <mirror>`,
  delete the manifest's images there (every file it lists), `python3 tool/gen_placeholders.py --out <mirror>`,
  then queue `["test", "-x", "art"]` with the mirror as `dir`. The export's build check does the same on the
  public tree before each version (scripts/export-public.sh, itch-page.md "The public repo").
- **test/asset_manifest_test.dart:** every file under `assets/` licensed and listed at its image size and grid, or our
  own; the bytes and sha256s (`art`; SHA-256 is written out in the test, so no package); tool/placeholders.gitignore
  against the manifest's patterns. A change under `assets/` needs `python3 tool/asset_manifest.py`.
- **`python3 tool/test_gen_placeholders.py`** (stdlib, ~2 min, no flutter, so not through the queue; git for the
  refusals) tests the generator in temp dirs: the platform icons' placeholder drawn too and every file it drew listed
  with its sha256 in `assets/.placeholders`; it runs again over its own placeholders and refuses (writing nothing) a
  file there that isn't one, the real art; every image from the manifest alone (a copy of `tool/` without
  `assets/`), every character frame's lowest row the feet row, the shadow colour only in the shadow files
  and the Soldier's strips' rows 55-59, the loot icons tool/draw_icons.py's drawings and none of them the real file
  (its sha256 in tool/assets.sha256), the Town scene's pieces never the real file either and something drawn in every
  frame of a grid and every prop cell, and the refusals: a private repo of its own, the same through a symlink, and
  this checkout (a dry run) when it tracks the real art.

## The telemetry summary: `python3 tool/test_telemetry_summary.py` (decisions-log 253)

Stdlib, ~2 s, no flutter, so not through the queue. It writes a made-up `telemetry.jsonl` in a temp dir, with only the
fields the game writes (telemetry.md "The records"): a run with the Towns on (a roll blocked and one hit, a Town entered
and left by Auto, buys and sells in its Shop of an item, a small relic and a material, a relic and an item crafted,
two Enhance stones made and two Enhance steps, materials dropped and used) and a run with them off (a store buy), and checks `tool/telemetry_summary.py`'s Town lines
word for word and the per-wave table's store and Town columns; the Towns-off run's buy is never a Town Shop's, and a
file without the Towns prints no Town line (telemetry.md "Reading it").

## The asset vault's git side: `python3 tool/test_asset_vault_hooks.py` (decisions-log 315)

Stdlib, git and openssl, ~2 min, no flutter. Scratch clones of a tiny public-layout repo (the art git-ignored, two game
vaults tracked, the `.githooks`, throwaway keys named by `git config poh.vaultKeyFile`, a HOME of its own):
- a clone with the key gets the art from the vaults (`sync`), byte for byte; so do a second checkout of the clone
  (post-checkout) and a `git archive` copy (`unpack --only game --key-file`); without the key,
  nothing is unpacked, a note, no failure;
- an edit re-packs only its vault (`commit` for the art alone: the commit holds its part and the JSON); a touch
  re-packs nothing and `commit` refuses; the other clone's pull unpacks it (post-merge);
- art edited while its vault moves in git: the pull leaves it, the next commit is refused, `sync --keep-mine` puts it
  over the vault;
- two clones editing different files of one vault: the merge stops, `resolve` merges both, `check` passes and the
  other clone's pull gets the same; the same file both ways is named and `--take theirs` settles it;
- placeholders (`assets/.placeholders`) are never packed and `sync` replaces them; a licensed file forced past
  `.gitignore` is refused;
- a file that left its vault: deleted in a second checkout of the clone, kept in the main one (and never packed
  back) until `prune`;
- pre-push: only `main` and `v*` tags of the public history reach the remote `public`, another history is refused
  there, the public history goes to `origin` only with `POH_PUSH_PUBLIC_HISTORY=1`, and the privacy check refuses a
  planted IP address, in a file and in a commit message (the commit-msg hook; and a commit made past it, with
  `--no-verify`, is refused on the way out until it is reworded);
- a branch without `tool/asset_vault.py` (like the private notes; decisions-log 316), here carrying the hooks so each
  one runs in it: its `git worktree add` from the clone, a commit, a checkout and a merge all exit 0 and print
  nothing, and no state file or art appears there; its push is refused with pre-push's one line and moves nothing,
  and the same branch pushed from the clone goes.

## The privacy check: `python3 tool/test_privacy_check.py` (decisions-log 315)

Stdlib and git, ~5 s. `tool/privacy_check.py` on scratch repos: each kind planted (an IP address, a private-notes
marker, an e-mail address, a home folder, a GitHub token, a PEM key, a private term) fails `--staged` with its file and
line and shows only the match's first 4 characters; key files by name (`*.jks`, `key.properties`, `.envrc`, a service
account's JSON) fail; loopback and documentation addresses, version numbers, noreply and example.com addresses, the
made-up home folders and a line marked `privacy-check: allow` pass; `--rev` and `--dir` read what they say;
`--message` checks a commit message without git's `#` lines and what is below the scissors line, `--messages` the
messages of a range of commits; the private terms come from `POH_PRIVACY_TERMS` or the private notes' branch (`privacy-terms.txt`), never this repository.

## CI: `.github/workflows/ci.yml` (decisions-log 315)

In the public repository only (github.repository), on every pull request and push to main: the privacy check (the
shapes alone), the art (the vaults with the secret `POH_VAULT_KEY`, else placeholders and `-x art`), the tools' tests,
`flutter analyze --no-fatal-infos lib test` and a fast set (asset_manifest, licence_page, english_text, save,
app_identity, game); on a push to main or by hand, the whole suite too.

## The store tests (#63)

`test/store_test.dart`: the store, a Town's Shop since the Towns-off rules went (decisions-log 321): the five Pusaka
it alone sells (each one's price, ×1.5 each time it is bought again; a copy of an owned one "Owned"), selling only
from the bag at its price's share (a Pusaka from the Gudang, a bound one refused), a Pusaka bought waiting in the
Gudang and never going on one troop, the save, plus the book's words (each Pusaka's lines at ★1, ★2 and ★3, and where
it is). What the Pusaka do is pusaka_test.dart's (below); the Shop's materials and its opening are forge_shop_test.dart's
and town_shop_open_test.dart's. It uses
`test/hero_skill_helpers.dart` (`bareGame`, `placeNow`, `foeAt`, `runFor`).

## The Pusaka (decisions-log 138)

`test/pusaka_test.dart` (plain tests, `bareGame` / `placeNow` / `foeAt`, every skill off): the five as epik
type-wide relics; each effect at ★1, ★2 and ★3 on the type's troops and on no other type (Dragon Heart and Dawn Star
in `statsOf`, God's Thunder's leaps and beams, the Grail once a wave per troop at its share of HP and 2 s untouchable,
ready again at the next wave, Void Eye's own mark and the boss's); Void Eye stacking with Hunter's Mark and a
troop's Curse of Frailty untouched; God's Thunder's 12 beams a second; a troop bought later and a Hero of the type
getting it, and a fall losing nothing (asleep, back with the next one); `useRelic` refusing one; the four small
relics' numbers; binding (the first free, unbinding free, a Pindah at `rerollPrice`, the events), onto a type that
holds one, mid-wave and after game over; the store (one of each, the Gudang sold at half, a bound one not); the
counters (Dragon Heart's blow lived through, Dawn Star's healing past its base, no overheal) and the telemetry
(`WaveStarted.pusaka`, the wave record's `pusaka` and `gold.pusakaSpent`); `TroopFell.relics`; the save round trip
and unknown names; the migration of `test/fixtures/save-20261001-2005-pre-awaken.json` (the owner's wave-86 save from
before the Pusaka, a copy of the owner's 2026-10-01 snapshot: read-only, never the real save) to the default binding at ★1
with the templars' HP, Batal and OK, Lepas jenis sending the released type's Pusaka to the Gudang, a wave-68-shaped save (the five worn on templars, taken off and bound one per
type), copies (★ per copy, past ★3 paid back) and a save with none.
`test/pusaka_at_test.dart`: the one read of a Pusaka's numbers by stars (`pusakaAt`, `pusakaCountAt`, lib/pusaka.dart)
gives every table's number at ★1, ★2 and ★3 exactly (Void Eye's on the boss with `boss: true`), clamps the stars, and
throws for a relic with none; and a static check reads lib/: no line but the accessor's bodies, the catalog's rows
(`pusakaCatalog`, which name the tables the accessor reads), a table's definition or a comment names a number by stars
(`dragonHeartK.hp`, `ironBannerK`, ..., God's Thunder's `share`, `crownCap`) or indexes a `*K` table of pusaka.dart,
draft.dart or pusaka_catalog.dart, so a new direct read fails with its file and line.
`test/pusaka_langka1_test.dart` (decisions-log 205): batch L-1P's ten Langka. Their rows (appended after the oaths;
names, Carve roles, epithets, the atlas's cells, catalog-bayangan-v2's counters, chest-only, sold back at
`langkaPrice`), their words at ★1 (the card and tooltip lines, the Bag's gist) and at ★3 and carved; each effect at
★1-★3 and at two Carve levels (the number `pusakaAt` gives, and the table's at no Carve) in a scripted duel of a knight
and an orc next to it (`duel`: the blow's damage against `hitTaken`, the tally, the status's strength and time on a
normal monster and the boss, Dulling Mail's 1 s cooldown, Challenge Letter on an archer doing nothing); the counters'
hooks on them (Sunder on Steady Stance, Unshaken on Snare Cord, Defiant on Challenge Letter's taunt); the chest dealing
each of the fourteen Langka and binding each by its `pusakaPrefs`, none at ★3; the save keeping one's type, stars and
Carve steps (the w89 save holds none); `omenMet` (Twin Fury no every-Nth source, Challenge Letter's taunt only on a
melee type, Dulling Mail the first cooldown Fx); the log's "slowed 2 times"; the Bag detail's sentence
(`firstSentence`: a card line that goes on joins the first, Mourning Bell's and God's Thunder's too); and their Boss
Chest cards, three a chest, on the screen and apart at 915×412 and 1266×713. The shots: `test/probe_l1p_shots.dart` (a
probe; queue `["test", "test/probe_l1p_shots.dart"]` with the worktree as `dir`; `OUT` the folder) writes the ten on
four Boss Chests at 412×860 and 1266×713, and at 1266×713 the Bag's detail of Twin Fury ★2 and Challenge Letter ★2 and
the Army page's templars wearing Challenge Letter ★2, from the w89 save at wave 90.
`test/pusaka_langka2_test.dart` (decisions-log 207): batch L-2P's ten Langka, in the same shape (`duel`, each effect
at ★1-★3 and at two Carve levels, the knight attacking and the orc striking only when told): Momentum's charge spent by
the next attack and dropped at a wave's start, Bleeding Edge's bleed (its tick, its three ticks through the defence, a
stronger bleed kept), Shatter Shard's burst on the monster next to the target (not one past a tile) and its 1 s
cooldown, Pain Crystal's MP and cooldown, Watch Shield's shield at a wave's start (its type only) and what it soaked,
Bone Buckler's shield up to 3 kills' worth, Riposte's hit back on every 3rd up-close blow (a skeleton archer's arrows
none), Mana Leech's MP, Looter's Pouch's gold in whole coins, Spell Cutter's strip (the longest-left buff, the boss
half, its cooldown starting only when it took one); the Bayangan Off Beat's reach on each every-Nth gate (the attacks',
the hits landed, the hits taken); Thrift, Fade, Shieldbreak and Brace answering them; the band's measures (a bleed and a
burst as power, a ward's most, Momentum a proc); the chest dealing each of the 24 Langka; the save (a charge, a shield
and a cooldown not saved); `omenMet` (every few hits, a cooldown, a troop shield, an extra hit, a hit back); the log's
"stripped 3 times", "+12 MP", "+1.2k gold" and MP and gold never on "VICTORY!"; the cards at 915×412 and 1266×713. The
shots: `test/probe_l2p_shots.dart` (a probe, `OUT` the folder) writes the ten on four Boss Chests at 412×860 and
1266×713, and at 1266×713 the Bag's detail of Spell Cutter ★2 on the archers, the Army page's templars wearing Watch
Shield ★2, and the field at wave 91's start with the templars' Watch Shield ★3 (each wears the guard's mark), from the
w89 save.
`test/pusaka_langka3_test.dart` (decisions-log 209): batch L-3's six Langka, in the same shape (`duel` for the knight's,
`healScene` for the two a priest's heals carry: a priest and a hurt knight that never fights, mid-wave, each heal heard
through `Game.onTroopHeal`), each at ★1-★3 and at two Carve levels: Salt Charm ending the bad effect with the most time
left on a blow, its own good effect kept, its cooldown starting only when it ended one; Wolf Feast's heal on a kill,
never past full; Full Cup's shield of the heal past full, at most 12% of the max HP, none for a heal under full, and
what it soaked counted for it; Hidden Flask's heal once a wave on a blow that leaves it under 35%, none on a felling blow,
again in the next wave; Living Moss's regen through the funnel (its counter the HP healed) and its ×0.9 attack; Pure
Water ending a bad effect with a heal, its cooldown, and a heal with none to end starting none; Drag stretching both
cooldowns ×1.5, Wound cutting the three heals, Scar keeping a troop at 95% from a heal so from Full Cup's shield; Salt
Charm ending Sap's weaken on the next blow (never on the 4th itself) and Pure Water with the next heal; the band
(the heals by max HP, Full Cup's most, the regen and the cleanses exempt); the chest dealing each of the 30 Langka and
binding Full Cup and Pure Water to the priests; the save (a shield and its giver not saved); `omenMet` (a cooldown, a
troop shield, a heal source; a type holds one); the log's "cleared 3 bad effects", "+340 HP from kills", "drunk once,
+240 HP"; the cards at 915×412 and 1266×713. The shots: `test/probe_l3_shots.dart` (a probe, `OUT` the folder) writes
the six on two Boss Chests at 412×860 and 1266×713 and at 1266×713 the Bag's detail of Full Cup ★2 on the priests, from
the w89 save; then with omens forced on at both sizes a Boss Chest's reveal and take message (Sap taken with Spikes and
Haste dodged) and Sap held with five other Langka kinds as chips and their tooltip.
`test/pusaka_epik1_test.dart` (decisions-log 211): batch E-1P's ten Epik in the same shape (`duel` a troop of the
bound type and a monster that strike only when told; `blow` and `strikeBy` one blow each way, a shot flown to its
end), each at ★1-★3 and at two Carve levels: Healer Bane ×k on a monster healer only; Bully's Club ×k on a slowed,
pinned, stunned or hexed monster, never a free one; Unity Ring ×k with 4 troop types alive, as before with 3, counted
again when a type dies out; Rune Gauntlet's might of k for 4 s on its own skill's cast and a Hero's, a stronger might kept;
Hawk Feather's range ×k (a melee type's to the most a melee reach goes) and attack ×0.9, a shot past the old range
counted; Witherroot's weaken on a monster it takes HP off (the boss by its own boss table), a fresh one counted, a
refresh not; Arrow Catcher's cut on a monster's shot, after its defence, never up close; Stone Coat's defence +k (never
under a blow's least) and walk ×0.9, what it kept off counted; Hero's Cloak's cut on the type's Hero only; Moonwell's
MP regen ×k and max HP ×0.9, the MP the quicker regen gave counted. Hunker cutting Bully's Club's blow on a held
monster, Bone Arrows' shots through Arrow Catcher, Envy off Rune Gauntlet's might; the rows (appended after L-3 in
the save's order, Epik, Carve roles, epithets, icons, counters naming the ten Epik Bayangan, chest-only, the Shop
buying one back at half a Langka's price, never selling it); the keys and the band (a might's k − 1, the trades none);
the words (card, tooltip, gist, the Bag detail's first sentence); the chest dealing each of the Epik pool's fifteen
and the run's first chest of three; the save (and the owner's w89 save holding none); `omenMet` (a might from Rune
Gauntlet, a weaken from Witherroot, no every-few-hits or cooldown gate, so Off Beat reaches none of them); the log's
"powered up 4 times", "34 hits past its old range", "weakened 12 times", "+450 damage blocked", "+42 MP" and Stone
Coat as VICTORY!'s best; the cards at 915×412 and 1266×713. The shots: `test/probe_e1p_shots.dart` (a probe, `OUT` the
folder) writes the ten on four Boss Chests at 412×860 and 1266×713 from the w89 save, and at 1266×713 the Bag's detail of
Witherroot ★2 on the templars and the Army page's archers wearing Hawk Feather ★2.
`test/pusaka_epik2_test.dart` (decisions-log 214): batch E-2P's seven Epik in the same shape, each at ★1-★3 and at two
Carve levels: Ember Brand's mark on every 3rd blow (a plain blow itself, for its time), spent ×k by another type's blow (the
archer behind), never by its own type, nothing after it ran out; Funeral Pyre's burst of k of the killing blow on the
monsters near the dead one, through their defence, none farther, its 1.5 s cooldown started only by a burst; Null
Stone stripping a monster that took HP off it (a might, a haste, a guard; a troop's slow kept; the boss and a mini boss
halved), the rune ring, its k-second cooldown started only when it took something; Fallen Flag's might of k for 4 s
from the fallen one on the troops within 2 tiles (another type too), none farther, a stronger might kept, none from
another type's fall; Aegis Seal's shield of k of max HP on Hold Fast's cast and a Hero's Shield Bash, its soak
counted; Warden's Horn's taunt on the 6th up-close blow on every monster within 2 tiles but the boss (a mini boss
too), on its 6 s cooldown, never on an archer; Anchor's walk ×k and whole-wave stand from the wave's start (a shove
and a drag held and counted, another type moved, a troop bought mid-wave without it, two anchored troops still
parting), and Bastion's shorter stand never cutting it short. Mark Ward shortening the mark, Close Ranks guarding the
monsters next to a kill before Funeral Pyre burns them, Off Beat's extra hits before Ember Brand and Warden's Horn;
the rows (appended after E-1P, Epik, Carve roles, epithets, icons, the counters that now name them, chest-only, the
Shop buying one back at half of `epikPrice`); the keys and the band (the mark as an every-Nth power, the fall's might
k − 1, the shield its k; the kill's burst, the strip, the taunt and the stand unmeasured); the words (card, tooltip,
gist, the Bag detail's first sentence, Carve's next step); the chest dealing each of the Epik pool's twenty-two; the
save (and the owner's w89 save holding none); `omenMet` (Ember Brand an every-few-hits gate and a mark, the cooldowns,
a might, a troop shield, a taunt; Anchor none); the log's lines and families; the cards at 915×412 and 1266×713. The
shots: `test/probe_e2p_shots.dart` (a probe, `OUT` the folder) writes the seven on three Boss Chests at 412×860 and
1266×713 from the w89 save, and at 1266×713 the Bag's detail of Ember Brand ★2 on the archers and the Army page's
templars wearing Anchor ★2.
`test/pusaka_epik3_test.dart` (decisions-log 223; E-2P's helpers, plus `healScene` for a priest 40 px from a knight at a
share of its HP mid-wave, every troop heal heard, `untilHeals`, and `castScene` for a soldier about to cast Hold Fast
with a knight a tile below it and an archer 2.5 tiles off): batch E-3P's eight Epik in the same shape, each at ★1-★3 and
at two Carve levels: Mana Hymn's k of max MP to the troop a priest heals (none once full); Saint's Tear's cleanse of
every bad effect a monster put on the caster and the troops within 2 tiles (a good effect kept, none farther), its
cooldown started only when one had one; Brave Song's might of k for 3 s from the priest on the troop healed (a stronger
kept); Halo Lantern's k of the heal to the two nearest hurt troops within a tile of the one healed (the third, a full
one and a far one none, no chain); Hearth's heal up to k of max HP at a won wave's end, a heal between waves, none
mid-wave, none over it, none on another type; Heartbeat's heal of k of each one's max HP on every 4th blow on itself and
the hurt troops within 1.5 tiles (a full one and a far one none, the sparkle on each); Mercy Lily's ×k on a heal its
type gets under 40% HP (the heal asked heard, the × counted, Wound's cut after it; none over 40% nor on the healer's
type); Bright Spring's heal of k of max HP on the caster and the troops within 1.5 tiles. Wound at its most never
cutting Hearth's heal. The rows (appended after E-2P, Epik, all life, epithets, icons each its own, the counters that
now name them, chest-only, the Shop buying one back at half of `epikPrice`); the keys and the band (Brave Song a
might, Halo Lantern's share × its two and Mercy Lily's k − 1 heal output, Heartbeat's and Bright Spring's heal of max
HP; Mana Hymn's MP, the cleanse and Hearth's wave-end heal unmeasured); the words (card, tooltip, gist, the Bag
detail's first sentence, Carve past ★3); the chest dealing each of the Epik pool's thirty and the default binding; the
save (and the owner's w89 save holding none); `omenMet` (a heal for Halo Lantern, Hearth, Heartbeat and Bright Spring,
not Mercy Lily; Saint's Tear's cooldown, Heartbeat's every few hits, Brave Song's might); the log's lines and families;
the cards at 915×412 and 1266×713. The shots: `test/probe_e3_shots.dart` (a probe, `OUT` the folder) writes the eight
on three Boss Chests at 412×860 and 1266×713 from the w89 save, the Bag's detail of Saint's Tear ★2 on the templars at
1266×713 and 412×860, and, with omens forced on, Bat Venom's reveal, take message, chip and tooltip at both sizes.
`test/pusaka_legenda1_test.dart` (decisions-log 231; E-1P's `duel`, `blow`, `taken` and `strikeBy`, with `wave:` for a
wave begun first, plus `castScene` for a soldier about to cast Hold Fast, `bigFoe` and `topOmen`): batch G-1P's ten
Legenda in the same shape, each at ★1-★3 (a Legenda's ★2 and ★3 read ★1) and at two Carve levels: Lone Wolf Pelt's ×k
with 3 of its type alive (none at 4, again once one goes); Martyr's Flame's k of the fallen one's max HP on each monster
within 2 tiles (none farther) and the type's max HP ×0.9; Wide Blows' splash 16 px more (a knight's from none, an
axeman's 16 to 32: only the hits past the old splash counted) and its attack ×k; Champion's Mantle's Heroes ×k, the
others ×0.9 (no count); Vengeance Mark's mark on the monster that hit (k, the boss's own k, a mini boss k; 4 s; every
troop blow ×k, counted; none once run out) and the troop's ×1.15; Mirror Shield's wave-long reflect from itself (as a
reflect of k from no one; none on a shot, none for one bought mid-wave, none after the wave); Ghost Step's every 3rd
monster blow missing (a bleed's tick counting none); Ice Grip's every 4th hit holding the monster for k s (the boss and
a mini boss slowed instead; a lancer's longer pin kept); Relic Altar's guard, fang, fury and thorns ×k; Vow of Silence's
HP and attack ×k, no Hold Fast and no Shield Bash cast, the MP kept. The Shadows that answer them: Off Beat stretching
neither every-Nth; Blunt on Lone Wolf's big blow, Spite on a monster Vengeance Mark marked, Executioner baring Ghost
Step's miss (the count goes on), Unbowed shrugging off Ice Grip's first hold, Rust under Relic Altar, Scatter on Wide
Blows' extra hits, Thornproof on Mirror Shield's hit back; Iron Skin's stronger reflect taking Mirror Shield's slot and
handing it back. The rows (appended after the Smithy's small relics, Legenda, ★1 only, roles, epithets, icons each its
own, the G-1B counters that now name them, chest-only, the Shop buying one back at half of `legendaPrice`); the keys,
the costs and Carve's named numbers; the words (card, tooltip, gist, the Bag detail's first sentence with its "but …",
Carve +5); the chest dealing each of the Legenda pool's thirteen from wave `legendFrom`, binding it by `pusakaPrefs`
and never again once found; the save (and the owner's w89 save holding none); `omenMet` (an extra hit, a hit back, a
mark and Spite's mark, a hold; Vow of Silence taking its type's MP skill off); the log's lines and families; the gold
cards at 915×412 and 1266×713. The shots: `test/probe_g1p_shots.dart` (a probe, `OUT` the folder) writes the ten on four
Boss Chests at 412×860 and 1266×713 from the w89 save, the Bag's detail of Vengeance Mark on the templars at 1266×713
and 412×860, and the Army page's axemen under Vow of Silence at 1266×713.
`test/pusaka_legenda2_test.dart` (decisions-log 238; G-1P's `duel`, `blow`, `taken`, `strikeBy`, `bigFoe` and
`topOmen`, plus `stand` holding a unit where it stands and `fontScene`, a soldier about to cast Hold Fast with an
archer near and a wizard farther off, both with no MP): batch G-2's eight Legenda in the same shape, each at ★1-★3 (★2 and ★3 read ★1) and at two Carve levels:
Rage Totem's ×k under half the max HP (none at half or over) and every heal it gets ×0.7 (counting nothing); Guardian Chain's
every 4th hit linking each troop of another type within 2 tiles for 4 s (none of its own type, none farther; k of each
blow on them taken through its own defence, counted; a link back to it passing nothing back); Phalanx's cut with 3 others within 1.5 tiles
(none with 2) and its attack ×0.85; Phoenix Plume's first fallen rising 3 s later where it fell at k of its max HP,
no MP, once a wave (the next to fall stays down; a Hero falling first stays down and leaves the once) and its max HP
×0.85; Soul Shelter's k s of no
damage on the troops within 2 tiles of the fallen one, on one 6 s clock for the type (counted, with what it kept off);
Mana Font's k of each other troop's max MP within 3 tiles after a skill (not itself, none farther) and its MP regen
×0.7; Hex Blade's every 8th hit turning the monster into a slime for k s (never the
boss nor a mini boss; once every 6 s); Glory Seeker's might ×k for 5 s on every troop of its type after a high elite,
a mini boss or the boss's kill (none after a normal or an elite one; none on another type). The Shadows that answer them: Off Beat stretching
neither every-Nth; Unbowed shrugging off Hex Blade's first hex (its cooldown spent); Deathless holding Glory Seeker's
might until the real death; Spree counting Phoenix Plume's fall; Side Swing's extra hit meeting Soul Shelter's window;
Backlash answering Mana Font's skill. The rows, keys, costs, Carve's named numbers, words, the G-2B counters that now
name them; the chest dealing each of the Legenda pool's twenty-one; the save; `omenMet` (a hex, a might on troops); the
log's lines and families; the gold cards at 915×412 and 1266×713. The shots: `test/probe_g2_shots.dart` (a probe, `OUT`
the folder) writes the atlas's Legenda rows numbered at 4× (`map-02-atlas-numbered`), the eight on three Boss Chests at
412×860 and 1266×713 from the w89 save, the Bag's detail of Soul Shelter on the templars at 1266×713 and 412×860, and
the Army page's axemen under Glory Seeker at 1266×713.
`test/pusaka_legenda3_test.dart` (decisions-log 243; G-2's helpers, plus `hurt` a standing troop at a share of 100000
HP and `psalmScene` a priest healing a knight at half HP with orcs a tile from the knight and one farther): batch G-3's
three Legenda in the same shape, each at ★1-★3 (★2 and ★3 read ★1) and at two Carve levels: Vampire Kiss's k of a
blow's HP to the most hurt other troop within 2 tiles (never itself nor one farther; the next most hurt once that one
is full; none hurt near: nothing) and every heal it gets ×0.6 (counting nothing); Wrath Psalm's smite of k of a
priest's heal on each monster within a tile of the troop healed, through its defence, at most once every 2 s (none on
the one farther; no Psalm, no smite) and the priests' heal ×0.75; Grave Seal's noHeal for k s on the monster it hits
(from the troop, counted fresh once and with the heal it stopped; a new blow runs it from then; once it ends the heals
land) and its attack ×0.9. The Shadows that answer them, omens on: a troop a boss's blow blighted gets nothing from
Vampire Kiss (the next most hurt does); Holy Ward cuts Wrath Psalm's smite on a skeleton, not on an orc; a sealed
boss's Last Gasp heals nothing. The rows, keys, costs, Carve's named numbers, words, the counters that now name them
(Blight, Holy Ward, Hardy); the chest dealing each of the Legenda pool's (thirty since G-4); the save; `omenMet` (Vampire
Kiss's heal; Wrath Psalm's smite no extra hit); the log's lines and families; the gold cards at 915×412 and 1266×713.
The shots: `test/probe_g3_shots.dart` (a probe, `OUT` the folder) writes the atlas's Legenda rows numbered at 4×, the
three on two Boss Chests at 412×860 and 1266×713 from the w89 save, and, with omens forced on, Blight's reveal, message,
chips and tooltip at both sizes and a troop under Blight beside the same troop without it, cut out at 6×.
`test/pusaka_legenda4_test.dart` (decisions-log 247; `plain` a game, `reload` through the save, `stand` a troop
placed, `blow` one normal attack on `bigFoe`, `trio` a knight, an archer and a priest, `fill` an army of n, `_Dice`
draft dice of one roll, `chestGame` a board game with a chest due): batch G-4's six oaths. The rows: appended after
G-3's three, the army's, chest-only, never sold, ★1 only, no Carve, their icons (the atlas's cells 63 to 68, each its
own), the counters they name and the Shadows' answers (Guard: Oath of One, Alliance, the Few; Dusk the Wall; Oathbane
Blood; Rider Rush the Vanguard; Hero Hunt Kings; Spell Ward Spells); the catalog whole, 90 Artifacts and 30 a rarity;
their words from the constants. The rules: the Wall's HP ×1.4 and attack ×0.8; Blood's attack ×1.3 (a healer's heal
not) and a heal in a wave ×0.5, the after-wave heal whole; the Vanguard's ×1.4 up close and ×0.75 for a shooter and a
healer; Kings' aura ×1.25 and Hero ×2, its aura line; Spells' normal hit ×0.8 (against `hitTaken`), `skillCd`'s
values (8 of 10, 20 of 25, `cdFloor`, a 4 s one, infinity) and the awakening tooltip's cooldown. The two engine pieces:
the Few at 25 troops waits and at 24 works; under the board's army cap a 25th is refused (`fewOathBar`), the cap, the
Bayangan's over-count and the Auto hold's 24 (held at 17, not at 18); none without the cap; on the field Circle
Slash's gap stays 4 s, Rampage's 6 s → `cdFloor` and Cleave's 12.5 s → 10 s. The chest: each of the six dealt from
wave `legendFrom`, the pool 30, one oath keeping the others off; every Legenda found (the 22 that are no oath and one
oath) steps a Legenda roll down to an Epik, one missing comes, with no oath found the oaths come; the save keeps an oath and it works on load; the
Shadows' needs; the Boss Chest card of each at 915×412 and 1266×713, its words inside it.
The shots: `test/probe_g4_shots.dart` (a probe, `OUT` the folder) writes the atlas's Legenda rows numbered at 4× with
the six framed, the six on Boss Chests at 412×860 and 1266×713 from the w89 save (its Alliance taken off), the Few taken
with 48 alive (its message, the Bag's wait row), a chest with every Legenda found (three Epik cards) and a board army of
24 under the Few, Buy refused with "Oath of the Few: up to 24 troops".
`test/omen_cutover_test.dart` (decisions-log 209; `duel` a knight and a huge orc striking only when told, `blowOn` and
`shotOn` a blow or a skeleton archer's arrow): the Bayangan Sap's row (Langka alone after Healer Hunt, not troop-side,
no needs, `debuff`: one a pool, never a counter, its icon unique) and HUD line at L1 and E8; on, at three levels, its
weaken on the 4th blow (bad, by the orc, omen, 2 s), the knight's blow ×(1 − k) under it and as before after it, the
count shared with Pummel, the boss's and a mini boss's blows, a skeleton archer's 4th arrow, never Brutal Swing's blow,
a stronger weaken kept, a blocked blow none; off, no count and no weaken. The Langka cut-over: the Langka pool is the
design's 30, Epik's starting with Armor and Mend (its own cut-over since: omen_epik_cutover_test.dart) and Legenda's
starting with today's seven; Armor and Mend sit in those two, Barrier and Escort in Legenda's alone; a Langka card's face
never one of them whatever the draw, the tilt kept; a Langka card's overflow only into the Langka kinds, none when
they are full; a save holding their levels loads and they act (Armor's cut, Barrier's shield, Mend's regen, Escort's
guards).
`test/pusaka_catalog_test.dart` (decisions-log 178): the rules every row of `pusakaCatalog` keeps, so a data batch adds
rows and no test that lists them: a row per Pusaka in `Relic` order (an oath's with no Fx, another's one or two, its
rarity the row's); every Fx built (`fxBuilt`, its condition in `fxIfsBuilt`) and its templates rendering at every star;
the band (`fxBand` by `fxGain`, a condition or a trade `condBonus` / `tradeBonus` more, an every-Nth power at most
`perProcMax`; a new Legenda pays with a trade or a condition); the key (no two rows lead with the same Fx); the icons
(each row its own untinted cell of the Artifacts' atlas by its `Relic` name; the atlas 90 kinds, each once, its size
10 cells a row, in the order `ARTIFACTS` in tool/import_fx.py writes it; an unknown kind throws); the counters (in the row's own pool; today's as enemy-buff-design.md pairs them); the
families; the books rebuilt by every kind of change (a bind, a star, the map, a direct field); no dice named in the
engine or the catalog; the owner's defaults. They replace the tests that listed today's Pusaka exactly
(pusaka_test's, legenda_test's, pusaka_bukti_test's and draft_test's now check today's among the rest).
`test/heal_funnel_test.dart` (decisions-log 181): the troop heal funnel (lib/heal.dart). A table over every heal site,
one scene per `HealSrc` (a healer's heal, Healing Prayer, Blessing, Bloodlust, Last Stand, Sacrifice, Unbroken,
Lifeline, regen, a worn fang, Mourning Bell, the after-wave heal, the Grail's save, the Iron Will relic's heal
(decisions-log 227); the table must cover every tag):
each heals its troop through the funnel with its tag (`Game.onTroopHeal`) and the kind Wound reads (`healKind`). The
after-wave heal carried into a wave stays `between`; regen after the win is `between`, in the wave `inWave`; a
healing necromancer's heal on a monster isn't heard. A static guard reads lib/: every HP write but the two funnels'
(the troops' and, since decisions-log 184, the monsters' `_healMonster`) is in its list of what is no heal (`_refit`,
the load, Resurrection, a hex, Grave Call's raised monster, Reassemble's heap, the Grail's save from 0, the Bayangan
Deathless's 1 HP), so a new heal
of either side outside its funnel fails with its file and line. Wound's factor
(`Game.woundForce`) halves a healer's heal, regen and a fang in a wave, and never the Grail's save, the after-wave
heal or regen between waves; with none set a heal is exactly what it was. The heal past full HP. The ward: at most
`wardMax` of max HP whatever the gifts (a smaller `most` stops lower, never cuts one over it), a werebear's blow
breaks it before the HP, and it is 0 once the wave is won.
`test/fx_hooks_test.dart` (decisions-log 182): the catalog's shared hooks. The duration scaler at 1 leaves every time as
it is, to the bit (`scaledEffectTime`, and `addEffect` with every status on a troop and a monster), and shortened never
goes under `effectTimeFloor`; `alliesNearOf` / `foesNearOf` equal a brute count over a random field (the dead, the gone
and those not yet on left out) and stand within a tick; `belowOnce`; `firstStrikeAt`; and each condition in
`fxIfsBuilt` through a real trigger, on Iron Banner's or War Drum's row swapped for one with the condition (put back
after the test). `test/hit_source_test.dart` (decisions-log 182) scans lib/ itself: every `_hurt(...)` call names a `Hit`
as its third argument (or passes its blow's own `src` on), every `Shot(...)` and `_holyHurt(...)` too, and the calls that
aren't `Hit.skill` are exactly the table in the test: a new blow that is no skill's is added there on purpose.
`test/cleanse_test.dart` (decisions-log 184): a troop's cleanse and the monsters' noHeal (lib/cleanse.dart,
lib/heal.dart). A table over every kind a monster puts on a troop, one monster skill's scene each (Screech, Barbed
Arrow, Pounce, Sticky Glob, Slime Tide, Roar, Curse of Frailty, Bulwark, Headbutt's stun, Soul Drain): its marks are
`bad`, a cleanse ends them all and leaves the troop's own, a stun's immunity stays, a bleed or a drain hurts no more.
Every status put on a troop not marked (by a troop, a monster named in it, or none) is never ended; all marked, all end
(a stat one refits); mixed, exactly the marked. A cleanse of a few takes the most time left first. A static guard: only
the monster skills' files and the Bayangan's (omen.dart: Sap's weaken) say `bad: true`, and each of their effects without it is listed (`monstersOwn`: a monster's
own or its allies'). A table over every monster heal site, one scene per `MonsterHeal` (it must cover every tag): each
heals through `_healMonster` (`Game.onMonsterHeal`) and, under `Status.noHeal`, lands as 0; a skeleton under it falls
for good, one sealed on its heap stands at the heap's HP. The engine's `cleanse` (struck) and `noHeal` (dealt) Fx on
a row swapped in, with their words.
`test/probe_pusaka_w89_identity.dart` (a probe, not in the suite) checks that a Pusaka refactor changes nothing, on
`test/fixtures/save-20261002-2222-w89-sellbug.json`: it dumps every type's `statsOf` / `fieldStats` and HP tooltip, every
relic's tooltip and effect lines at ★1-★3, every Pusaka's gist at ★0-★4, totals and preview on each of the save's
five types (its saved roster's order, fixed in the probe), and 45 s
of wave 90 fought with seeded dice (the state and the tallies every 15 s), as saved and with every Pusaka bound at each
star (the five epik; the four Langka and Dragon Crown); then waves 90 and 91 played with the telemetry listening (a fixed
clock; the boss chest's first card taken between them), as saved and with each set at ★2: every record and their hash
(FNV-1a 64). It prints the hash lines and how long the 45 s fights take (best of 3; the hot path's cost, never
compared). The records' version labels (`"tv"`, `"ev"`, an event's `"v"`) are masked to `_`: it compares what the game
did, and a version bump changes only the label (the suite's tests pin the versions). Run it on the base (a `git archive`
mirror) with `--dart-define=OUT=<file>`, then on the branch with `--dart-define=GOLDEN=<that file>`: it fails at the
first line that differs. It plays the game players play, the one every game is since decisions-log 321: the Towns, the
forge and the Tavern, and the troops' skill wind-ups (`..skillWinds`, decisions-log 299; `--dart-define=WINDS=false`
gives the dump of a base from before them), on a save from before the forge (the w89 save's Awaken levels kept,
loot-items-relics.md "The forge: items crafted, Awaken by grade"), every die seeded by `Game.seedDice` (the Town's and
the materials' at seed + 600 and + 700, the Shadows' at + 900, decisions-log 319). That one dump is the guard: every
merge compares it against main's, and a merge that changes the game on purpose records a new one in its own entry (the
latest: decisions-log 319's, 9,863 lines). Its Towns-off twin (the probe's `TOWNS` define, a plain `Game()`'s rules
before 321) went with those rules in decisions-log 321; on a base from before 321 the same dump is the probe's default
run. Measured for `pusakaAt` on the base c3fdf18:
1631 lines, the same on the branch; for the catalog's engine on the base 40d101e: 1754 lines, the same on the branch;
for the shared hooks (the hit-source tag, the scaler, the near counts) on the bases c87889c, b289601 and defd22b: 1754
lines, the same.
The Toko's and the Bag's Sell tests (`test/bag_sell_ui_test.dart`, decisions-log 169; `test/store_hud_test.dart`, #63)
and their probe (`test/probe_bag_sell_shots.dart`) went with the Towns-off book in decisions-log 296: the Bag sells
nothing and the field's book has no Shop tab (test/town_shop_ui_test.dart, test/shop_tabs_ui_test.dart and
test/town_shop_open_test.dart test the Town's Shop and the tabs).

`test/pusaka_bukti_test.dart` (decisions-log 149, the Pusaka seen): plain tests for every Grail save logged
(`GrailSaved`) with only the wave's first waiting for the cut-in (`Game.grailFirst`), wave after wave; a fall's relics
on its second log row and in `relicsBack`; a won wave's `PusakaReport` (each bound Pusaka, the relics back, right
before `WaveEnded`; none with nothing to tell) and `lastPusaka`; the best counter's rule; a build name for each
Pusaka; the "VICTORY!" line's words (`pusakaWinLine`: "Artifact: Grail 6 saved · Back to Bag: Fury ×2") and the log's
(`logLines`; a count of one singular: "1 hit lived", "rang once"); and every one of those strings
checked against the game font's own cmap (`fontChars` in test/hud_font.dart parses it), so no glyph the HUD font lacks
("★", "→") slips in. One `TdGame`: the "VICTORY!" line fits `winLineMaxW` 361 px at 915×412 and 1266×713
(`Board.winPusakaLine`), the Grail's cut-in shows on the first save only (`grailCutIn`), and the build name sits on the
Army page's right page (the picked type's heading, `rowBuildName`), none for a type without a Pusaka. The rings and the
HP-bar icon are checked by eye (reports/pusaka-bukti.md).

## Peti Bos, the boss's chest: the "Boss Chest" (decisions-log 152, 197)

`test/draft_test.dart` (plain tests, `bareGame` / `placeNow` / `foeAt`, every skill off; dice that roll one rarity,
`_Dice`, and dice that count their draws, `_Counted`): the chest off in a plain `Game()` and on with `boardRules()`;
one only on a won boss wave, its three different cards rolled at once; the run's first chest three Epik; no Legenda
before wave `legendFrom` (a Legenda roll an Epik; with no Epik left a Langka; from it: legenda_test.dart); the pity on the 6th dry chest (a reroll no new chest); Serpihan
gaps when the pool runs dry and the free reroll they pay; a duplicate's star where it is bound, a new card bound by the
default rule with its first move free (`PusakaBound` cost 0) or into the Gudang; no ★3 card, and a card that reached ★3
since turned Serpihan when opened; Kocok ulang at 700 / 2.5k / 38k doubling and back for the next chest, refused
short; Lewati's gold, and nothing dealt with mid-wave; with the chest on a Town's Shop sells no Pusaka (a Langka never,
sold back from the Gudang at half); the boss's fall drawing the `loot` dice the same with the chest on or off, no relic
reaching the bag; catch-up chests (0 / 1 / 2 / 3 / 3 for waves 14 / 15 / 44 / 45 / 90, the w86
fixture's 3, rolled when opened); the save round trip (an unknown card or a small relic loads as a Serpihan; `chests`
always written); `draftPolicy` ('rarity', 'first', a typo throws; the boss chest taken at the win, catch-up ones by
`pickChests`); two runs with the chest on and a policy the same wave by wave; each Langka at ★1-★3 (Iron Banner's
cut against the same strike without it, Blood Fang's heal against the same blow, War Drum's 3rd blow and with a worn
fury, Mourning Bell's heal within 2 tiles and none from another type's fall) with their counters, lines and Tas
words (`pusakaGist`, `pusakaTotals`); the telemetry (the offer events in order, the wave record's `chestSpent` / `chestEarned`). Records compare with `==`:
a matcher or a collection is checked on its own, never inside one.
`test/chest_odds_test.dart` (decisions-log 185; plain tests on the same set-up): `chestOddsAt` is `chestOdds` at
waves 1, 5 and 9, the cap at 345, 400 and 1000, and the steps in between (w10 and w14 one step, w20
three, w100 nineteen, w344 sixty-seven); at every wave 1-400 the odds add up to 1 and Legenda is 0.08 + 0.0025 per boss
wave after the first; three chests and a reroll draw 24 values on the same seed at every wave (one draw a card); the
head's (7bb3a8e) rarities of three chests on `Random(1..8)` at waves 1, 5 and 9 (no step yet), kept as a table
(rarities, not names: the catalog adds Pusaka); a chest's own wave's odds, a reroll's too (a w20 chest rerolled at w25
still rolls 0.911 an Epik, a w25 chest a Legenda), a Legenda roll with every Legenda found an Epik, and one before wave 20.
`test/probe_chest_odds.dart` (a probe, not in the suite: queue `["test", "test/probe_chest_odds.dart"]`, `SEED` sets
the dice) prints the rarity shares of 1000 chests (3000 cards) at waves 25, 100 and 345 beside `chestOddsAt`.
`test/draft_hud_test.dart` boots its own `TdGame` (one per widget test; the board saves after a win and a pick, in the
queue's temp HOME): the popup waits for the win's cheering, holds Auto, and has no Later (decisions-log 281): its row is
Reroll, Skip and Take (`Board.chestOpen`, `chestCards`, `chestPicked`, `chestButtons` 'reroll' / 'skip' / 'take',
`chestChip`); Take greyed takes nothing, a tap picks a card, a tap on it again takes nothing, Take takes it, saved;
Reroll and Skip's two taps (Skip's first letting the pick go and greying Take); a tap off the cards and a near miss of
Take keeping the pick, a tap on another card moving it; the open chest holding Auto and the toggle however long it
waits, until a take; Start pressed in a boss win's cheer (the chip showing) opening the chest within the cheer and
starting no wave, Auto waiting until it is taken and then starting the wave, and no chip mid-wave even for a chest put
there by hand; with a new Hero's splash due, Start in the cheer opening nothing and starting no wave, the splash and then
the chest; the w86 save's three
catch-up chests ("Missed Chest 1/3") one after another, saved once rolled, the next opening with nothing picked; a save
holding two chests put off with Later before 281 opening the first at once and the second after it; the cards and the
buttons on the screen and apart at 915×412 and 1266×713, a card picked too; each card's frame
recoloured by its rarity (Epic, Rare, Legendary and a Shard, plain and lifted: the top rim's middle pixel is the
rarity's rim, or the lit frame's dark rim), no pixel of the rarity's ink within 8 px of the card's edge (the ink box drawn
over the frame until 2026-10-02) and some inside it (its rarity's name), read from the screen's pixels (`screenPixels`:
`boot`'s RepaintBoundary drawn into an image); and every line it shows against the HUD font's cmap (a "★" left out:
`_text` draws it as the star icon), with the log's lines for a take, a Shard and a skip ("Boss Chest: Iron Banner ★1
(Rare) to Templar", "Missed Chest skipped: +38k gold"). A widget test that loads the w86 fixture with `boardRules()` for something else clears its
catch-up chests (`..chests.clear()`: army_cap_ui_test, pusaka_tas_ui_test), whose popup would take its taps.
The shots come from `test/probe_chest_shots.dart` (a probe, not in the suite: queue `["test",
"test/probe_chest_shots.dart"]` with a mirror as `dir`; `OUT` sets the folder): the popup with nothing picked (Take
greyed), a card picked (Take green), the next chest, a boss win's cheer with its chest waiting (a fresh army at wave
5: the chip under Start) and Start pressed in it (the chest open, no wave) at 1266×713, 1164×777, 915×412, 412×860 and
1600×947; at 1600 and 412 the w86 save's wave-90 win, which makes a new Hero: Start in the cheer opening nothing, the
Hero's splash after it and the chest once the splash is closed; at 1266 the pick moved, the Toko's closed shelf, a boss chest of three Langka and the Tas page with a
Langka picked. `test/probe_chest_frame_shots.dart` (the same way; default folder `shots/chest-frame/`) shoots
the cards' rarity frames: two boss chests (God's Thunder, Iron Banner, Dragon Crown; a Serpihan, War Drum, Oath of One),
each plain and with each card lifted, at 1266×713 and 412×860.

## The Bayangan (decisions-log 180)

`test/omen_test.dart` (plain tests, `bareGame` / `placeNow`, every skill off; dice that give set draws and count them,
`_Seq`; the owner's wave-86 and wave-89 saves of test/fixtures, read-only). `omensOn` is on by default since
decisions-log 319 (the first test pins it); the `off` group switches it off in `setUp`, and off: a
chest, a reroll, a take, a Lewati and a wave start draw no Bayangan die, write no key (the game's nor a chest's) and send
no Bayangan event or field; the owner's saves load with none and no catch-up, and a save written while on loads with its
Bayangan ignored. The `on` group switches it on in `setUp` (off again in `tearDown`): the seven kinds' pools, numbers,
icons (a sheet in `assets/images/`) and counters (`answers`, Dawn Star's Wound on a priest); a face's tilt (under 2/9 the
card's counter, the rest of the pool evenly: 1/3 and 1/9 over 90 000 draws); one die draw a card, always 3 a roll (a
Serpihan, a chest before wave 20), the cards the same on or off; the take's 1/2/3 levels by rarity of the taken face only;
a reroll's new faces; the overflow past `omenCap` along the pool and round to its start, `omenKindsMax`, and "Monsters: full" at
28; a card that turns into a Serpihan losing its face, and an old faceless chest giving none; Lewati's gold as before, no
level, and the skip buff owed from wave 20, once, saved; the save round trip by name (an unknown kind skipped); b86's
catch-up exactly Wear Down 2 / Heal Siphon 2 / Mend 2 / Prey 2 / Armor 2, round-robin, 2 a wave, once, also across a save; w89's 19 owed,
12 dealt; the Beban factor (48 over 32: ×1.5, at most ×2, 1 at or under the cap or with no cap) and E; the ease (each
full eighth of the starting troops fallen takes the newest level, at most 2 a wave); telemetry 8's fields; and
`policyPick` taking the same cards on or off. With the Bayangan off (`--dart-define=OMENS=false`),
`test/probe_pusaka_w89_identity.dart` (The Pusaka, above) is the same as on a base from before them; on, the default since
decisions-log 319, its dump moves: the w89 save owes its catch-up (12, 2 a wave), so waves 90 and 91 meet those Shadows
(a new golden then).

`test/omen_hooks_test.dart` (decisions-log 188; plain tests, every skill off, the monsters' too) checks the hooks
(units-and-combat.md "Bayangan on the field"). A blow is one strike from a held pair (`blowOn`: a knight and an orc 12
px apart); a wave is spawned whole with each monster held where it came (`spawnAll`, its spawns heard through
`MonsterSpawned`: the unit, its row, the time). Off, with every kind at 4 and Lewati owed: a wave's spawns, rows and
times as without them, each monster's stats exactly `enemyStats`'s, no shield, skip buff or guard, `rng` and `slots`
where they were, `spawnStats` equal to `enemyStats` for every tier, raised or not, and a blow both ways unchanged. On,
one test a kind: Armor cuts a troop's blow by 0.05 E (L1, L4, E 8 at its 0.4 cap and beyond; a slot's too) and never a
monster's; Haste's pause ÷(1 + 0.05 E) for every tier and its 0.4 cap, with `attackEvery`'s floors (0.3 s, the boss
0.2 s) under a strong haste; Mend's regen by tier, raised or not (no slot's), at its cap, and its heal on a tick;
Thorns' 0.03 E back with no bounce off a worn thorns, its 5% cap, and none on an archer; Wound's factor through the
funnel (L2, its 0.5 cap, `woundForce` in its place); Shield on the slots only (none on a necromancer's minions), its
soak before HP and what passes it; Guard's 1, 1, 2, 2, its monsters right behind each slot's escort on the slot's row
(waves 30 and 60), tided, the rest of the wave and its rows as without them and the dice still paired; and Lewati's
buff on exactly the first 30% by spawn order, the spawn times and rows unchanged, and gone the next wave.

`test/omen_rules_test.dart` (decisions-log 192; the same `blowOn` pair, every skill off) checks the v2 rules
(units-and-combat.md "Bayangan on the field", loot-items-relics.md "Bayangan"). The taken floor: Armor at E8 (×0.6) above
it, an omen guard taking the product to 0.54 and then to the floor's 0.5 (at the edge exactly and past it), a monster
skill's guard cutting after it (×0.42). The dealt cap: an omen might under the cap is any might, at 1.6 the edge, at
2.5 a blow equal to a plain 1.6 might; a plain might is never capped. Unholy Ward's pick ignores an omen absorb and not
a skill's. The troop-side cap through `omenPlace`'s `troopMax` (no room, held, then `omenCap`, the wrap, with the kinds
cap). The acting faces: today's seven need nothing and every live kind's needs are built; the filter with every kind
acting gives `omenFace`'s faces for every Pusaka and type, a filtered kind is drawn only by the tilt and the acting
ones evenly, none acting spreads over the whole pool; a roll draws one die a card; `omenMet` on a growing army (the
living only, each skill switch read, a Pusaka bound to a type with none alive ignored). The HUD numbers at E8 for every
kind equal `omenK` (L4 at factor 2), Escort's count by L, Vultures' rank word the only `{who}`, each `{cap}` the share ×
its steps (Horde's, Adapt's, Spree's). Off, an omen might and an omen
guard act as any, and no face is drawn. Thick Hide's and Bulwark's tests check that a skill's guard clears
`Unit.guardOmen`. Since batch L-1B the pool tests read the pools (`omenPool`) rather than pin today's seven: the Langka
pool holds 30 kinds (since L-3), the Legenda pool today's seven, and the Epik pool 30 (since E-3's cut-over), so the
overflow and troop-side tests here and in omen_test.dart place along the Legenda pool, today's seven.

`test/omen_langka_test.dart` (decisions-log 204; the same `blowOn` pair, every skill off, `troopBlow` / `foeBlow` on a
fresh pair each) checks Shadow batch L-1B, the first ten Langka kinds (units-and-combat.md "Bayangan on the field"). The
rows: the Langka pool alone, after today's seven in order; their `k`, titles, `omenBraceAbove` / `omenStubbornBelow` /
`omenDefiantBoss`, Deflect's 12/8/6/5, troop-side Wound and Sunder only, Unshaken's and Defiant's needs (all built) and
`omenCanAct` on a real army; every icon an existing sheet's cell inside it (its PNG header read), each (sheet, cell,
tint) unique among all the kinds. The HUD at E8 (L4 at factor 2, a wave on): each share at its max, equal to `omenK`,
`omenShownK` and the number in its line; Deflect's count by L whatever the factor; every line at most 80 characters,
ASCII. On, one test a kind: Brace over 90% (not at it), Stubborn under 30% (not at it), Bear Hide on a werebear only,
Hard Shell with an absorb, a shot ward, a Barrier or a guard (not one that ended), each at L1/L4/E8 and never on a
monster's blow; the taken floor with Armor (0.6 × 0.7 stops at 0.5) and Brace with Hard Shell (0.49 → 0.5); Sunder on
the small relic Guard, a skill's guard and Iron Banner's cut, never a monster's guard; Unshaken on a slow, pin, taunt,
weaken and hex (×0.5, the 0.3 s floor, a shorter own time), never a monster's buff or a troop's debuff, Shield Bash's
stun (a mini boss's half first) and Slime Hex; Quick Spells' first cast unmoved (2 to 5 s) and War Shout ready at 70%
of its cooldown (L2 at ×2: 80%), never a mini boss's; Thrift's rounded gold at three levels, the plunderer's extra of
it, the `loot` dice drawing the same; Deflect cancelling every 5th blow with the orc's own burst and no God's Thunder
leap, a leap never counting, and a shot's 5th the same; Defiant against a plain might of the same factor (the boss and
mini boss half), not untaunted nor under a monster's taunt, and an omen might of 1.5 with it capped at 1.6. Off, with
all ten at their most: blows both ways, the troops' cuts, an effect's time, every attack and the kill gold as with
none.

`test/omen_langka2_test.dart` (decisions-log 206; the same helpers, `foeBlow` with the troop of a fresh pair a knight or a
priest) checks Shadow batch L-2B, the next ten Langka kinds (units-and-combat.md "Bayangan on the field"). The rows:
the Langka pool alone, in its order among L-1B's after today's seven; their `k`, titles, `omenAvengeTime` /
`omenAvengeReach` / `omenEagerTime` / `omenStragglerTiles`, Off Beat's 1/1/2/2, troop-side Wound, Sunder, Spell Tax, Off
Beat and Fade only, the five needs (all built) and `omenCanAct` on a real army (Twin Fury alone no every-few-hits
source, War Drum one; a priest; Veil of Light); each icon pinned, every icon inside its sheet and each (sheet, cell,
tint) unique. The HUD at E8: each share at its max, equal to `omenK`, `omenShownK` and its line's number; Off Beat's
count by L; each line pinned, at most 80 characters, ASCII. On, one test a kind: Shieldbreak on a ward, an absorb and
Mana Shield at L1/L4/E8 (the shield takes the blow × 1 + share; a 1 HP shield breaks and the rest lands as it was;
a bleed's tick and a troop's blow on a monster's absorb one for one); Lingering on a War Shout, a self buff and an
absorb, never a troop's, a Shadow's own, a heal or a buff on a troop; Avenge's might on the monster within a tile (not
the one past it; a stronger War Shout stays; Lingering held, 3 s still); Feed's heal at three levels, never a slot's;
Eager on every rank from the queue, never a necromancer's minion; Healer Hunt on a priest, not a knight; Straggler alone
or with one 40 px off, not with one 20 px off, never the boss or a mini boss; the dealt cap with Healer Hunt,
Straggler and an omen might (product under it, 1.6 over it); Spell Tax's `skillCost` (×1.3, the knight's max MP, a
price already past it), Shield Bash waiting at 15 MP and paying 19.5, `mpInfo` and `awakenLines` showing the taxed
price between waves; Off Beat on War Drum (3rd → 4th at L1 and L2 ×2, 5th at L3 and L4) and Twin Fury's fury beat
unmoved; Fade on a stunned knight's ward and absorb over 1 s (× (1 − share × 0.05)^20), never a monster's absorb or
Mana Shield's MP. Off, with all ten at their most: a priest's blow, a ward over a blow and 1 s, a monster buff's time,
a spawn, an MP price, War Drum's beat and a death next to a monster as with none.
`test/cleanse_test.dart`'s monster heal table has Feed's scene (omens on in it, off after). The shots:
`test/probe_l2b_shots.dart` (a probe; queue `["test", "test/probe_l2b_shots.dart"]` with the worktree as `dir`; `OUT` the
folder) writes, with omens forced on at 412×860 and 1266×713, two Boss Chests' reveals and take messages (Off Beat taken
with Spell Tax and Straggler dodged; Avenge taken with Lingering and Fade dodged), and eight of the batch's kinds as
chips and their tooltip. `test/omen_ui_test.dart` holds the message window inside a window 320 px tall and a pixel too
narrow for Off Beat's take line (the line broken at its spaces), and its tooltip test at 1164×777 holds the most kinds a
game can (8: Armor, Mend, Escort and the five longest lines).

`test/omen_langka3_test.dart` (decisions-log 208; L-2B's helpers, plus `shotOn` for a monster's arrow, `withFx` for a
row swapped in as cleanse_test.dart's, `killThenWin` for a wave whose kills each troop makes and that is won, and
`swinger` for a high elite elite orc winding up Brutal Swing with two knights in reach) checks Shadow batch L-3B, six
more Langka kinds (units-and-combat.md "Bayangan on the field"). The rows: their order in the Langka pool among
L-1B's and L-2B's (the whole pool's own pin, 30 since the cut-over, is omen_cutover_test.dart's), Epik's starting
with Armor and Mend and Legendary's today's seven; their `k`, titles, `omenPummelEvery`, troop-side Wound, Sunder, Spell Tax, Off Beat,
Drag, Scar and Fade only, Drag's and Scar's needs (built) and `omenCanAct` on a real army (War Drum no cooldown source,
Pain Crystal one; a priest a heal source); the three new tints; each icon pinned, inside its sheet, each (sheet, cell,
tint) unique. The HUD at E8: each share at its max, equal to `omenK`, `omenShownK` and its line's number; each line
pinned, Grudge's with each troop type's plural and "none", at most 80 characters, ASCII. On, one test a kind: Grudge on
the top killer's type at L1/L4/E8 (a Hero of it too), never another type nor with none; its bookkeeping (3 swordsman
kills over 2 and 1, a 2–2 tie to the knight, the target held through a wave whose kills change it only at the win, a
wave no troop killed in, the save's `grudgeType` and an unknown type; off, no tally and no key); Drag on Pain Crystal's
cooldown at three levels, on an Epic row swapped in, never a Legendary one, and on Spell Cutter's strip (6 s → 9 s);
Scar on a huge regen in a wave (to the ceiling, the past-full against the real max HP, never lowering a troop over it,
to full between waves), a priest passing over a troop at the ceiling and healing one under it up to it and no further,
and a `heals` Fx (unbuilt: it throws when it runs) running on a heal that gave HP and never on one a listener took back;
Gloat at three levels, never the boss or a mini boss, nothing for a bleed's fall; Rekindle's share of max HP at three
levels, never a stunned wind-up or a mini boss's swing; Pummel's every 3rd blow and a skeleton archer's 3rd arrow,
never the boss's or a mini boss's, with Grudge and an omen might under and at the 1.6 cap, and Brutal Swing leaving
`Unit.blows` alone. Off, with all six at their most: blows, Pain Crystal's cooldown, the heal ceiling and a kill as
with none, and no blow counted. `test/cleanse_test.dart`'s monster heal table has Gloat's and Rekindle's scenes. The
shots: `test/probe_l3b_shots.dart` (built on the L-2B probe; queue `["test", "test/probe_l3b_shots.dart"]`, `OUT` the
folder) writes, with omens forced on at 412×860 and 1266×713, two Boss Chests' reveals and take messages (Grudge taken
with Drag and Scar dodged, its line naming the templars; Pummel taken with Gloat and Rekindle dodged), and the six with
two of L-2B's as chips and their tooltip.

`test/omen_epik1_test.dart` (decisions-log 210; L-3B's helpers, plus `troopBlow` for a troop's blow on a monster with HP
to spare, `arrowOn` for a skeleton archer's arrow, and cleanse_test.dart's `casterAt`, `lands`, `tickUntil` and `hear`)
checks Shadow batch E-1B, the first ten Epik kinds (units-and-combat.md "Bayangan on the field"). The rows: the Epik
pool Armor and Mend then the ten in order, Langka's 30 and Legendary's seven as they were, an Epik take 2 levels; their
`k`, titles and constants, no troop-side kind among them, Hunker's, Counterspell's and Envy's needs (built) and
`omenCanAct` on a real army (a knight: an MP skill only; the axemen's stun; a Hero's War Cry); each icon pinned, inside
its sheet, each (sheet, cell, tint) unique; the overflow along the Epik pool (Muster wraps to Armor) and the faces past
the tilt spread over all seventeen. The HUD at E8: each share at its max, equal to `omenK`, `omenShownK` and its line's
number; each line pinned, at most 80 characters, ASCII; Wear Down's L1-L4 in two decimals (0.15%, 0.3%, 0.45%, 0.6%).
On, one test a kind: Dark Hymn on a healer's stats at every rank and a real heal ×1.4, never an orc's; Bone Arrows on a
skeleton archer's stats and arrow, its range kept, never a skeleton's, outside the dealt cap (with Grudge and an omen
might: 1.4 × 1.5 uncapped); Arrow Ward on every rank and a necromancer's minions, an archer's arrow halved, none after
6 s or up close, outside the taken floor (Armor and Hard Shell at the floor, the ward on top); Enrage never on the first
blow nor at 9 s, at 10 s at three levels, never the boss's or a mini boss's; Hunker under a slow, a pin and a stun at
three levels, never free or weakened, at the floor with Armor; Counterspell at the #10 skill (Hold Fast), the awakening
skill (Disarm) and a Hero's (Shield Bash), on high elites within 2.5 tiles only, its share of their max HP for 3 s, once
per 6 s, a bigger absorb kept; Wear Down at three levels on a 140 HP knight, the Risk-1 guard on a 100000 HP tank (half
the blow), after a War Shout's might, with an omen might at the 1.6 cap, a skeleton archer's arrow, never Brutal
Swing's blows; Envy on a might and a haste at three levels, never a slowing haste or a might under 1; Zeal from a
healer's heal at three levels and from Mass Mend, never a heal under noHeal, Feed's or Mend's; Muster on the boss and a
mini boss at three levels, 5 s, never 60 px off nor on itself, once, never a killing blow or another rank. The dealt cap:
Enrage, Envy, Wear Down and a Muster-sized omen might at 1.6, the product under it, Wear Down added on top. Off, with all
ten at their most: stats, a spawn, blows both ways, a Hero's cast, a healer's heal and a boss's 60% as with none, and
Muster's bit unused. The shots: `test/probe_e1b_shots.dart` (built on the L-3B probe; queue
`["test", "test/probe_e1b_shots.dart"]`, `OUT` the folder) writes, with omens forced on at 412×860 and 1266×713, two
Boss Chests of Epic cards' reveals and take messages (Dark Hymn taken with Counterspell and Muster dodged; Envy taken
with Wear Down and Zeal dodged), and eight of the ten as chips and their tooltip. Since batch E-2B its pool test reads
its ten among the pool (E-2B's sit between them) and the faces over the whole pool.

`test/omen_epik2_test.dart` (decisions-log 212; E-1B's helpers, plus `strikeAt` for a knight's blow on a given monster
after a step next to it, `burst` for a monster of a type killed among standing troops, `under` for a blow that takes a
monster under an HP line, and `steps` for L1 ×1, L4 ×1 and L4 ×2 of a kind) checks Shadow batch E-2B, ten more Epik
kinds (units-and-combat.md "Bayangan on the field"). The rows: the Epik pool the design's 30 titles in its order (in
the test), Langka's 30 and Legendary's seven as they were; each kind's tiers,
`k`, titles and constants (each `belowOnce` bit its own), no troop-side kind, Mark Ward's need (built) on a real army (a
knight none; a Hero's Hunter's Mark; Void Eye bound), no answers until batch E-2P; each icon pinned, inside its sheet,
each (sheet, cell, tint) unique and no ui cell that means something else; the overflow along the pool (Second Skin into
Bile Sacs, Captain into Enrage, Close Ranks into Wear Down, Triumph into Muster) and the faces past the tilt over all 27.
The HUD at E8: each share at its max, equal to `omenK`, `omenShownK` and its line's number; each line pinned, at most 80
characters, ASCII; Captain's L1-L4. On, one test a kind: Second Skin's absorb at three levels, 6 s, the next blow
soaked, once, never the boss's or a mini boss's (bit unused) nor on a killing blow; Last Rage's might at three levels,
its blow ×(1 + share), not over 35%, once, never the boss or a mini boss, and with Second Skin both bits from one blow;
Bile Sacs at three levels on the killer and a knight 8 px off, never 20 px off, once per 0.5 s, the small relic Guard's
cut, never an orc's death; Blood Moon on werewolves and werebears of every rank, never another type, its heal tagged
`bloodMoon` at its share of the blow, none after 8 s, Bloodrage's own lifesteal still `lifesteal`; Mark Ward on Hunter's
Mark and Void Eye's mark at three levels (and Void Eye bound: 5 s to 2.5 s), the 0.3 s floor, never a slow or Curse of
Frailty on a troop; Parting Gift at three levels on a hurt orc 20 px off, never 30 px off, a mini boss or a full one,
once a second, its tag under noHeal gaining 0; Captain at three levels, at 1.5 tiles and not past, never an elite or a
dead high elite, a high elite itself only with another near, a boss guarded too, a monster's blow untouched; Close Ranks
at three levels (the guard flagged, the pale ring), its cut on the next blow and gone after 1.5 s, a stronger skill
guard kept and a weaker one replaced, landed before Wolf Feast's kill heal, none when God's Thunder's leap kills;
Blindside at three levels, at 1.4 s and not 1.5 s, never on a troop fighting its attacker or idle, `_strike` marking
`Unit.lastFoe`; Triumph on the killer and an orc 20 px off at three levels with `attackEvery` × 1 / (1 + share), never
40 px off or a mini boss, a stronger haste kept. The crowd stack (Captain, Close Ranks, Hunker) at 0.51, with Armor at
the floor; the dealt stack (Last Rage, Blindside, Envy) at the 1.6 cap and their product under it. Off, with all ten at
their most: no absorb, might or bit, no lifesteal, a mark's time kept, blows both ways as with none, no burst, gift or
guard on a slime's death, no `lastFoe`, no haste on a fall. `test/cleanse_test.dart`'s monster heal table has Parting
Gift's and Blood Moon's scenes, and `test/hit_source_test.dart`'s table Bile Sacs' burst (`Hit.extra`). The shots:
`test/probe_e2b_shots.dart` (built on the E-1B probe; queue `["test", "test/probe_e2b_shots.dart"]`, `OUT` the folder)
writes, with omens forced on at 412×860 and 1266×713, two Boss Chests of Epic cards' reveals and take messages (Captain
taken with Close Ranks and Triumph dodged; Second Skin taken with Blood Moon and Blindside dodged), then four of the ten
and the other six as chips and their tooltips.

`test/omen_epik3_test.dart` (decisions-log 219; E-2B's helpers, plus `healScene` for a wave with a priest, a knight that
never fights and a hurt orc in Heal Siphon's reach, `castOnce` for one heal of the priest, `regenScene` for a knight
healed every tick beside hurt monsters of given ranks, `hear` for every monster heal and `tickUntil`) checks Shadow batch
E-3B, seven more Epik kinds (units-and-combat.md "Bayangan on the field"). The rows: the seven in the Epik pool alone,
each in its place in the design's pool order (its 30 titles in the test, the pool itself), Langka's 30 and Legendary's
seven as they were; the answers E-3's cut-over gave them; each kind's tiers, `k`, titles, constants, icons (an existing sheet's cell, each unique), Trickle and Toll
troop-side; needs: Heal Siphon and Trickle act only on an army with a heal source (a healer type, a regen, a heal Fx),
the other five always; the pool's order through a take's overflow, the troop-side cap's overflow and the faces from the
thirty. The HUD numbers at E8: each its capped share, Trickle's in seconds, each line short and English. With
omens on, at L1 ×1, L4 ×1 and L4 ×2: Prey on a troop under 30% (read before the blow), none at 30% or at full HP; Herd
Hunt at 10 alive, none at 9 or with one of 10 fallen, in the dealt cap; Old Bones on each skeleton kind at every rank and
raised, rounded, with the skip buff, a spawned monster's max HP the same, the other stats and kinds untouched; Grave
Pact on a raised monster, none once the raiser fell or on one not raised, with Armor at the taken floor; Heal Siphon's
debt after a heal, paid within a second to the nearest monster (its tag, what it asked and gained, the sparkle), past a
boss and a mini boss, dropped with none in reach, none between waves, measured after Scar's ceiling; Trickle's heal
spread over its time (nothing at the call, half way, whole), two heals keeping their own ends, a rescue, regen and a
heal status at once, past full against the HP and what is to come, never past full, Full Cup's ward at the call; a
fallen troop losing the rest and the wave's end dropping it; Toll's share through the troop's defence, the skull, down
to 25% and no further, nothing at 25% with its clock unspent, again only 2 s later. The heal stack: Wound 0.48 cuts
first, Trickle spreads the rest over 2 s, Scar stops it at 85% as it lands, Heal Siphon owes 0.3 of the whole heal at
the call (without Trickle, of what landed under the ceiling). Off, with all seven at their most: heals land at once and
owe nothing, a kill costs nothing, blows and stats as they were. `test/cleanse_test.dart`'s monster heal table has Heal
Siphon's scene (`MonsterHeal.siphon` under noHeal gains 0), `test/hit_source_test.dart`'s table Toll's blow
(`Hit.hitBack`), and `test/heal_funnel_test.dart`'s static guard lists Trickle's payout (the funnel's one HP write
outside it, `_omenTrickle`). The shots: `test/probe_e3b_shots.dart` (built on the E-2B probe; queue `["test",
"test/probe_e3b_shots.dart"]`, `OUT` the folder) writes, with omens forced on at 412×860 and 1266×713, two Boss Chests
of Epic cards' reveals and take messages (Prey taken with Heal Siphon and Toll dodged; Trickle taken with Herd Hunt and
Grave Pact dodged), then four of the seven and the other three as chips and their tooltips.

`test/omen_epik_cutover_test.dart` (decisions-log 223; `duel` a knight of 100000 HP and a bat 12 px off, `blowOn`,
`bleedOn`) checks Bat Venom and the Epik cut-over. Bat Venom's row: the Epik pool alone right after Old Bones, its `k`,
title, constants (3 s, the bat), icon (a bat cell of an existing sheet, green, its own), no needs, not troop-side, the
troop debuff (Sap's and its, one a pool), never a counter. The HUD at E8 its max, the line short and English. With omens
on, at L1 ×1, L2 ×1 and L4 ×2: a bat's landed blow puts a bleed of the share × max HP for 3 ticks (bad and omen, from
the bat), the ticks through the knight's defence, Feed never fed by them, over after 3; a second bite renewing the same
bleed with its next tick kept; a stronger bleed kept; a blocked bite and an orc's blow none; a cleanse ending it, and
Saint's Tear on a bitten soldier's Hold Fast. Off: no bleed, the HUD at 0%. The cut-over: the Epik pool exactly the
design's 30 titles, none of Haste, Spikes, Wound, Barrier and Escort, Langka's 30 and Legenda's first seven unchanged, the
tiers (Haste, Spikes and Wound Langka and Legenda, Barrier and Escort Legenda, Armor and Mend Epik and Legenda), no kind
in all three, every Epik Pusaka's counter in the pool; an Epik card never showing the five (on a healer too), the tilt
kept, a Langka card still Haste, Spikes and Wound, a Legenda card all five; the overflow along the Epik pool (Old Bones
into Bat Venom, Bat Venom into Grave Pact, Muster round to Armor), never into the five, their held levels counting toward
the eight kinds; a save's levels of them loading and acting. The counters: the Grail Prey, Dragon Heart Wear Down, Dawn
Star on a priest Heal Siphon; b86's catch-up Wear Down / Heal Siphon / Mend / Prey / Armor twice, w89's twelve.

`test/omen_legenda1_test.dart` (decisions-log 226; `duel` a knight of 100000 HP and an orc of a given rank 12 px off,
`foeBlow` / `troopBlow` one blow either way, `crowd` monsters far off for Horde's count, `queueOf` a wave's queue and
the rng's next draw) checks Shadow batch G-1B, the first ten Legenda kinds (units-and-combat.md "Bayangan on the
field"). The rows: the Legenda pool is today's seven then the ten in the design's order (later batches' kinds among
them), Langka's and Epik's 30 as they were; each kind's tiers, `k`, titles, constants, `byL` (Unbowed's), `steps` (Horde's), icons (an existing sheet's cell,
each unique, none of ui_icons' cells that mean something else), Rust and Executioner troop-side, no answers yet; needs
on a real army (an axeman's splash, Crushing Blow with the skills on, a worn guard or thorns, Ember Brand bound, a
Hero's Slime Hex); the overflow along the pool (Escort into Scatter, Horde round to Armor), the troop-side cap's and the
faces of a Dragon Crown card. The HUD numbers at E8: each its capped share, Unbowed's count by L, Horde's total, each
line short and English. With omens on, at L1 ×1, L4 ×1 and L4 ×2: Scatter on an axeman's splash (its target
untouched; with Armor at the floor); Thornproof on worn thorns' hit back (at its most held by the floor); Rust on the
guard's cut, the fang's heal, the thorns' hit back and the fury's third blow; Veterans' queue (the same types and the
same next draw, only normal ones turned elite, never more high elites, about 12% moved over 30 waves at E4); Hardy on
elites and high elites at every route, with the skip buff and with Old Bones; Unbowed shrugging a troop's pin (the
brace ring on it), Shield Bash's stun on a high elite and a mini boss and Slime Hex, then each landing, a slow and a pin
from no troop never shrugged, a landed hex refilling nothing; Executioner baring a troop under the line of its worn
guard, skill guard, Turtle Shell, a duel's cut, a block, an absorb, Mana Shield, its ward and a cap over 0, each still
holding over the line and without it, a cap-0 window and Pain Crystal's MP kept, the line exact at each level; Spite
on a monster with Ember Brand's mark (none run out, under Hunter's Mark or unmarked; with Prey at the dealt cap);
Blunt (Risk 2's guard) cutting only the part past 20% on each rank above normal, none under the line or on a normal
one, with Armor at the floor; Horde (Risk 5's guard) by the living monsters on the field (9, 10, 19, 20, 30, 45; the
dead and those not on yet never counted), the boss too, a monster's blow never, and the crowd stack (Horde, Close
Ranks, Captain, Hunker at their most) held at the floor. Off, with every level held: none of it. The shots:
`test/probe_g1b_shots.dart` (built on the E-3B probe; queue `["test", "test/probe_g1b_shots.dart"]`, `OUT` the folder)
writes, with omens forced on at 412×860 and 1266×713, two Boss Chests of Legendary cards' reveals and take messages
(Scatter taken with Executioner and Horde dodged; Unbowed taken with Rust and Blunt dodged), then the ten as three sets
of chips and their tooltips.

`test/omen_legenda2_test.dart` (decisions-log 236; `duel` a knight of 100000 HP and a monster of a given type and rank
12 px off, `foeBlow` / `troopBlow` one blow either way, `caster` a soldier casting Hold Fast among monsters, `scene` and
`look` a monster's pick among troops at set HP) checks Shadow batch G-2B, ten more Legenda kinds (units-and-combat.md
"Bayangan on the field"). The rows: the ten sit in the Legenda pool alone, each in its place among G-1B's after
today's seven, Langka's and Epik's 30 as they were; each kind's tiers, `k`, titles, constants, `who` (Vultures'),
`steps` (Adapt's and Spree's), icons (an existing sheet's mapped cell, each unique), Mana Burn troop-side, no answers
yet; needs: Mana Burn and Backlash act on an army with a troop skill that costs MP (none under Vow of Silence), the
other eight always; the overflow along the pool (Scatter into Cover, Spite into Deathless, Backlash into Horde, ...),
Mana Burn past the troop-side cap; `test/heal_funnel_test.dart`'s static guard lists Deathless's 1 HP (a blow stopped,
no heal). The HUD numbers at E8: each its capped share (Deathless in seconds, Adapt's and
Spree's totals, Vultures' rank word by L), each line short and English. With omens on, at L1 ×1 and L4 ×2: Cover on
the boss and a mini boss with a living neighbour within 1.5 tiles (alone, a farther or dead one and a normal monster as
before); Renewal's shield after Spell Cutter's and Null Stone's strip, once a life, none from a strip that takes
nothing; Side Swing's second blow on the nearest troop within 1 tile (none farther, from a shooter or on a monster, and
no swing on); Deathless keeping an elite and a high elite at 1 HP under a cap at 0 for its seconds with no gold, kill
or killHeal, once a life, a normal monster, a mini boss and the boss dying; Adapt's run (Risk 3's guard: at most 3,
another type starting it again, an extra hit neither counting nor cut, the boss stack held at the floor); Warlord
while the boss or a mini boss lives (not its own blow, none from a dead or raised one, at the dealt cap); Spree's count
(Risk 4's guard: at most 3, only silver and gold, the snowball with Gloat, Triumph, Warlord and Backlash held at the
dealt cap); Vultures' pick by level (the most hurt troop in reach, kept until it falls, leaves the reach or the next
attack; a shooter's within 1.5 tiles of its target; another rank, the boss or no troop in reach as before); Mana Burn's
MP (never below 0, once every 0.5 s, with no effects on either unit, none with no MP); Backlash's might on each
monster within 2 tiles (the boss too, once a second, none farther, in the dealt cap). Off, with every level held: none
of it. The shots: `test/probe_g2b_shots.dart` (built on the G-1B probe; queue `["test", "test/probe_g2b_shots.dart"]`,
`OUT` the folder) writes, with omens forced on at 412×860 and 1266×713, two Boss Chests of Legendary cards' reveals
and take messages (Cover taken with Deathless and Spree dodged; Warlord taken with Vultures and Backlash dodged), then
the ten as three sets of chips and their tooltips.

`test/omen_legenda3_test.dart` (decisions-log 239; `duel` a knight of 100000 HP and a monster of a given type and rank
12 px off, `foeBlow` / `troopBlow` one blow either way, `skillShot` an archer's skill arrow on a monster, `smite` a
Priest's holy light on a dark monster) checks Shadow batch G-3B, seven more Legenda kinds (units-and-combat.md
"Bayangan on the field"). The rows: the seven sit in the Legenda pool alone, each in its place among G-1B's and G-2B's
after Barrier and Escort (30 since the Legenda cut-over), Langka's and Epik's 30 as they were; each kind's tiers, `k`,
titles, constants (Last Gasp's 40% and its own `belowOnce` bit, Rider Rush's orc rider, Dusk's 30 s), icons (an
existing sheet's mapped cell, each unique), none troop-side, Holy Ward answered by Wrath Psalm (batch G-3), the others
none yet; needs: Spell Ward acts on an army with a troop skill that costs MP, Holy Ward
with a healer type, Hero Hunt with a Hero, Oathbane with an oath held, the other three always; the overflow along the
pool (Escort into Spell Ward, Scatter into Holy Ward, Mana Burn into Dusk, Dusk into Backlash, ...). The HUD numbers at
E8: each its capped share, each line short and English, and Dusk's log line. With omens on, at L1 ×1 and L4 ×2: Spell
Ward on a troop's skill blow (a normal blow as before); Holy Ward on a Priest's smite on a skeleton and an armored
skeleton (the necromancer and a knight's blow as before); Hero Hunt on a Hero (another troop as before); Oathbane's HP on
the boss and a mini boss, a raised one too, with Alliance or Oath of One held (none without an oath, nor on a silver or
gold one); Last Gasp's heal at 40%, once (a killing blow, a silver or gold one and a second time none); Rider Rush on an
orc rider's first blow only (another type as before, nothing spent with no level); Dusk in the dealt cap once it has
fallen (never the boss's or a mini boss's own blow); Dusk's clock on a plain wave, a boss wave and a boss wave with a
Guard's monsters: it falls 30 s after the last crowd monster comes on, once, with one line in the battle log, the
spawns' pace the same as without it, and the next wave waits again; with no level it never falls. Off, with every level
held: none of it. `test/cleanse_test.dart`'s monster heal table has Last Gasp's scene (`MonsterHeal.lastGasp` under
noHeal gains 0). The shots: `test/probe_g3b_shots.dart` (built on the G-2B probe; queue `["test",
"test/probe_g3b_shots.dart"]`, `OUT` the folder) writes, with omens forced on at 412×860 and 1266×713, two Boss
Chests of Legendary cards' reveals and take messages (Spell Ward taken with Hero Hunt and Dusk dodged; Last Gasp taken
with Oathbane and Rider Rush dodged), then the seven as two sets of chips and their tooltips, and the battle log with
Dusk's line.

`test/omen_legenda_cutover_test.dart` (decisions-log 243; `duel` a knight at half of 100000 HP and a monster of a
given rank 12 px off, `blowOn` one blow, `healedBy` what a heal over time gave) checks Blight, the Legenda pool's troop debuff, and the Legenda cut-over.
The row: Blight in the Legenda pool alone after Thornproof, its numbers in seconds, its icon (the slime hit sheet's
frame 6 splat, mapped, olive, its own), no needs, `debuff` (the three debuffs Sap, Bat Venom and Blight, one a pool),
Vampire Kiss's counter. The cut-over: the Legenda pool is the design's thirty in its order (Barrier and Escort first);
Armor and Mend sit in Epik's alone, Haste, Spikes and Wound in Langka's alone, every kind in one tier
(`omenOneTier`); every Legenda counter in the pool; a Legenda card never shows the five; the overflow along the new
order (Thornproof into Blight, Blight into Renewal, Horde round to Barrier); a save's levels of the five load and act;
the old saves' catch-up as it was. The HUD numbers at L1 and E8 (seconds, short, English). With omens on: a boss's and
a mini boss's blow blights the troop (a bad omen noHeal from the monster, its time), a normal, elite or high elite
one's never, a blocked one never; no heal lands while it lasts, a new blow renews it, after it heals land; a priest
passes over a blighted troop for the next most hurt; a cleanse ends it. Off: none of it. The pins the cut-over moved
(the Legenda pool's head in omen_test and the Langka, Epik and Legenda batches' tests, the debuff lists, the
overflows, `omenOneTier` in omen_cutover_test and omen_epik_cutover_test) read the new table.

`test/omen_ui_test.dart` (decisions-log 191; booted boards, `omensOn` on in `setUp`; ui-hud.md "Shadows") checks what
the player sees: at 915×412 and 1266×713 the popup of a Legendary, an Epic and a Rare card ("?!!!", "?!!",
"?!") on the screen with its cards and buttons apart, and a row of 9 chips (8 kinds, the most held, and Skip's "!") right-aligned
under the wave meter, apart from the HUD, on the field; two boss bars under those chips and on the field; a card with
marks a row taller than one without, at both sizes; the hint (the first chest's, Take's, Skip's) and Skip's
message, chip and tooltip line ("next wave", then "this wave"); a take's reveal (the ribbon's line, the flips to "Armor
3" and "Dodged", no buttons, Auto's countdown and the "Chest!" chip waiting), a tap ending it, a second ending by itself
after `omenRevealFor`, then the message with what the monsters got; the chips' tooltip at 915×412 and 1164×777 (every
line; wrapped into more rows at 1164×777, none wrapped at 915×412, where the 360-px box won't fit under the chips and it
wraps at 600, decisions-log 291; under the chips and inside the screen, kept up after a tap, hidden by another tap or any
press); a wave-90 boss with Barrier 4 (its shield 20% of its HP) and Escort 2: teal on its bar and round its feet, gone once
broken (pixel counts); a reload after a reroll and a take keeping the faces and the levels; the owner's w89 save's note
once and 2 levels in the chips at its next wave; every Shadow line in the HUD's font; and with omens off nothing
shown, a take's message as before. The shots: `test/probe_omen_shots.dart` (omens on, every screen above at 412×860,
915×412 and 1266×713, into
`<agents>/shots/omens/`) and `test/probe_omen_off_shots.dart` (omens off: queue it with `--dart-define=OMENS=false`
since decisions-log 319; it uses only what main had before the UI step, so the same file runs in a mirror of a base
from before them and the PNGs compare byte for byte, `cmp`).
- **Seeded dice for a replay** (decisions-log 319, code-audit R1): a probe or test that must play the same twice seeds
  every die with `Game.seedDice(seed)` after `Game(Random(seed), Random(seed + 100))` or `Game.fromJson(save,
  Random(seed), Random(seed + 100))`: loot +200, heroes +300, slots +400, draft +500, townDice +600, matDice +700,
  tavernDice +800 and the Shadows' `omenDice` +900 (none seeded it before, so a run with the Shadows on was never the
  same twice). `Game.dice` lists every die; `test/dice_test.dart` holds both to game.dart's `Random` fields. The omen
  shot probes and the w89 identity probe use it.
- **The ease's knob** (`test/omen_ease_test.dart`, decisions-log 319): `omenEaseCount` ships `falls`; `omenFalls` with
  each `OmenEaseCount` on a wave with a troop bought mid-wave and fallen twice, two fodder starters and an awakened
  knight: 5, 3 and 1.

## The Legenda (decisions-log 155)

`test/legenda_test.dart` (plain tests like draft_test's, every skill off; `_Dice` rolling Legenda): the three's
rarity, scope, ★1 only (`maxStars`), numbers, icons on disk, gist and build name; Dragon Crown's cap against a
mini boss's blow at wave 60 (60% of the max HP, the next blow still kills, a lighter blow whole, another type's blow
whole, its counter); its coexistence (critique M3) with a Grail save's cap 0 and Bastion's 8% (an `addEffect` each),
with a real Bastion that still fires on a crowned templar Hero, and with a real Grail save on another type; Oath of
One (decisions-log 201) waiting at 3 types alive (the caps on, no new type, no limit note) and working at 2 (x1.5 HP
and damage, the troops refit, a third type refused with "Oath of One: only 2 types", the caps off so 12 knights, one
bought later with it, a dead-out type's place free again, nothing barred with no board caps); Alliance's +5% per type
alive, refit as types come, a seventh type counting no more than six (+30%), a fallen type's 5% gone at the next tick;
the chest's Legenda from wave 20, an oath taken keeping the other off (a chest rolled before shows a
Serpihan), a found one never again even once sold, every Legenda found stepping down to Epik, the other way round
with Alliance first; an oath's refusals (bind, unbind, sell) and Dragon Crown's Pindah; an oath's Tas preview
(without ▸ with); the save round trip (`legendsFound`, the oath on no type, the oath working on load, an
old save finding what it owns, unknown names, a Legenda's stars clamped to ★1).
`test/legenda_ui_test.dart` boots its own `TdGame` at 915×412 and 1266×713: the Bag's cells for the Pusaka owned only
(none for the rest), the Legenda after the bag's items and relics in `Relic` order, Dragon Crown marked by its type and
Oath of One by its swords, apart and in the book; an oath picked lists every type, a tap says it waits and binds
nothing; a chest of the three Legenda fits apart, and taking Oath of One says "Oath of One: Oath for all troops!" with the
wait (`oathWaitingNote`, "Oath waits: keep only 2 types"); and every new line against the HUD font's cmap.
`test/item_text_test.dart` (decisions-log 168, ui-hud.md "In-game text"): every tooltip an item, a small relic or a Pusaka
can show (each Pusaka at each star, bound, asleep, in the Vault and not owned; an item over every type's row; the oaths
taken and waiting) has its lines in the HUD font, no line twice and an oath's "Oath" once (no Indonesian word: the
guard below, since decisions-log 200 its own list gone); the screenshot's Alliance tooltip line by line; and, in the
game's font, every one's frame 412 px wide at the most (a phone held upright until decisions-log 289, kept as the
tooltips' most).
`test/poh_sans_test.dart` (decisions-log 179, ui-hud.md "The font"): the game's font has the sha256 it pins, and so
has its source (`tool/fonts/PixelifySans.ttf`), it is what `python3 tool/make_poh_sans.py --check` would write
(skipped without python3), it maps what Pixelify Sans maps, and its licence says it is a Modified Version of it, with
the source's sha256; a text in it is exactly as wide as in Pixelify Sans (every kern kept: pairs like "Bos", "co", "ct"
are kerned and measured), as tall and on the same baseline, at 14, 18 and 30 and wght 400, 500 and 700, its pixels the
same where it has none of the 13 redrawn glyphs and different where it has one; and `hudStyle` is that font at 500
and 700. (Pixelify Sans itself is loaded from `tool/fonts/` under its own family, `loadSourceFont` in
test/hud_font.dart.)
`test/letter_shapes_test.dart` (decisions-log 168 and 179): each of A-Z, a-z and 0-9 drawn alone at the HUD sizes
12, 14, 18, 22 and 30 and wght 400, 500 and 700; every two differ by 2 font pixels of ink or more (the sum of their
alpha differences over a font pixel's area; a letter and its own capital, and O and 0, aside). In Poh Sans the closest
is c and o, 2.4. The same check on Pixelify Sans finds 21 pairs under 2 (C/O and i/l down to 0.2, in bold), each with
a glyph Poh Sans redraws. And in "Cara Main", "Curse of Frailty", "Kocok ulang", "Circle Slash", "Pindah", "Pilih
ini", "Pasukan Ksatria", "Peti Bos" and "Gelombang" each C, c, i, a, B and G cell differs so from its look-alike's (O,
o, l, o, G, B) in the same line with it swapped in.
The redrawn glyphs seen: `test/probe_glyph_shots.dart` (a probe; queue `["test", "test/probe_glyph_shots.dart"]`
with a mirror as `dir`, `OUT` the folder): the "How to Play" page and the Curse of Frailty splash at 1266x713 and
412x860 with 2x crops, and test lines at body and title sizes 3x (the capitals, the lower case, "fi" words, numbers).
The item text and the 5 seen: `test/probe_item_text_shots.dart` (a probe; queue `["test",
"test/probe_item_text_shots.dart"]` with the worktree as `dir`, `--plain-name "item text 412"` for one size, `OUT` the
folder): every item, relic and Pusaka tooltip, the Tas page with a Gudang Pusaka and its Lebur picker, the Toko's
cards, the three chests and the gold panel, at 1266×713 and 412×860.
The shots come from `test/probe_legenda_shots.dart` (a probe, not in the suite: queue `["test",
"test/probe_legenda_shots.dart"]` with the worktree as `dir`; `OUT` sets the folder), on the w86 fixture (five types,
so Oath of One waits): a chest of the three Legenda, the Tas page with Oath of One picked and the Army page's "5/2
types" at 1280×720 and 412×860; and at 1280 the wave-90 boss fight with Dragon Crown on the Templar (its jade rings,
3x round a Templar), with the crown's counter printed (blows cut, HP kept).

## The army cap, the type caps and the Auto hold (decisions-log 141, 201)

`test/army_cap_test.dart` (plain tests, `bareGame` / `heroCaster`): a plain `Game()` has neither limit (12 priests,
no cap) and `boardRules()` turns both on (`typeCapBoard`: 5, 8 and 10 by role, every type; no type or three fill
36, four without the healer do, any five; decisions-log 260); capacity stops at 36 and a full army says "Army full
36/36" ("No room" under the cap); the owner's w86 save keeps 48 and buys again at 35; Resurrection stops at the army's cap; the type caps (decisions-log 201): a type stops at
its cap mid-wave too ("Priests full 5/5", "Archers full 8/8") while the others buy and no type is locked, its Heroes
count, one fallen and it buys again, nine types fill the army each refused by name, the w86 save keeps its 17 priests,
13 templars and 9 wizards and buys a priest again at 4, the save writes no roster and ignores an old one, `place` and
`autoPlace` share the gate, Resurrection raises a soldier at 9 and not at 10; "Replace fallen" stops at the army's cap
and then the type's; Lepas jenis' refund, relics, event and refusals (none alive, a Hero, mid-wave, over); `autoHeld`
at 75%; the one-time notes (the army, Beban's, the caps' three a line) show once and are saved.
The save is `test/fixtures/save-20261001-2005-pre-awaken.json`, a copy of the owner's w86 snapshot (5,506 bytes; the
artefact redesign's parts all load it). `test/army_cap_ui_test.dart` (one `TdGame` per widget test): the board's first
game and a "New Game" game have the limits; the save's counter "48/36", its list's counts against the caps ("17/5")
and its notes (`troopCountText`, `troopListTypes`, `troopListCounts`, `message`; since decisions-log 151 the Pusaka's
one-time note follows the limit notes in the same message); a full type's cell "x5/5" in red (`troopRowCount`), its
detail's "x5/5", no Buy in the book and its spawn bar card refused with why (decisions-log 283), and the picked type's
Release in two taps
(`releaseChip`, `releaseArmed`, the confirm on the right page); the Auto hold's line at 1266×713 and 915×412
(`autoHeldLine`), refilled or Start.

## The Tas page's Pusaka (decisions-log 151)

`test/pusaka_tas_ui_test.dart`, on the owner's w86 save (`test/fixtures/save-20261001-2005-pre-awaken.json`). Two
plain tests: what a Templar row previews for Dragon Heart (`pusakaPreview` after `undoDefaultBinding`: Pasang free,
13 alive, HP 580 → 927 in the field's stats against the book's 504, the wave-90 boss's blows 0 → 1; God's Thunder's
gist with no stats; To Vault on its own type; Move 38,000; "Not enough gold" and mid-wave), `thousands`, `bossBlowsLived`;
and the tooltip's type-wide totals (`pusakaTotals`, `relicInfo`: "Now: 13 Templar, +4,511 HP, +121 HP/s", Dawn Star,
the Grail, God's Thunder, Void Eye asleep on the soldier "Asleep: no Soldier alive") and the one-time note
shown once (`pusakaNotes`). Four widget tests, one `TdGame` each: binding in two taps (the note's message, Undo, the
Dragon Heart cell, a Templar row free, the troops' HP 927, To Vault, a Move's 38k, the Gudang's Grail sold in two taps
for 12,000 and its cell gone, the rows greyed mid-wave with the reason); the Army cell's badge (in the cell's top left corner since
decisions-log 218, faded for an asleep type, its hover tooltip, the note's OK); and the page with a Pusaka picked fitting
1266×713 and 1164×777 (every strip and button inside its page and apart, the rows inside the list; at 915×412 the action
rows take the list's scroll, so they are never all in view at once). A fourth: the
Army page (the Templar picked) and the Tas preview say the same HP for the Templar, the field's (`fieldStats`, ui-hud.md "Field stats"):
927 with Dragon Heart (the preview 927 ▸ 580), 580 after Batal (580 ▸ 927; the book's 504), as the troops' max HP,
and its HP tooltip's base and "Hero aura x1.15" (`troopRowStats`, `tasRowStat`). Besides `bagSlot` (a Pusaka's cell), the getters
are `Board.bagMarks`/`pusakaNoteButton`/`pusakaBadge`/
`pusakaBadgeAsleep`/`messageBox`/`tooltipShown` (ui-hud.md "Tas").

## Asah (decisions-log 154)

`test/asah_test.dart`, on the owner's w86 save (the fixture): the prices (60k, 150k, none at ★3 or for one not owned, a
Legenda refused once P5 brings one); the relics taken (`asahTake`: the owner's bag gives Thorns 8, Fury 2, an even bag
round and round from Fang, a short bag all of it); an Asah (the star, the gold, the bag, the Templar refit with the
HP gained, a gold burst on each, `Sfx.clear`, the `PusakaAsah` JSON and its two log rows); once per boss interval
through real wins of waves 87-90 (plain `Game`, no board, so nothing saves), ★3 at 90, one in the Gudang at 95; every
refusal and their order; the save round trip (`asahAt`); the telemetry's `gold.asahSpent` in the next wave's record;
every line it shows against the HUD font's cmap (`fontChars`, test/hud_font.dart; '★' is drawn as an icon). Two
widget tests, one `TdGame` each: the button's two taps, the message, a refusal's message and mid-wave; the Sharpen row
at 1266×713 and 915×412 (decisions-log 202), an action row on the facing page under its heading, its tag inside it,
clear of the other rows. Getters: `Board.asahButton`,
`asahArmed`. The shots come from `test/probe_asah_shots.dart` (a probe; queue `["test", "test/probe_asah_shots.dart"]`
with the worktree as `dir`; `OUT` sets the folder, default `<agents>/shots/asah/`): ready, armed, done and
refused at 1266×713 and 412×860, and the gold short on the desktop.

## Lebur (decisions-log 164)

`test/lebur_test.dart`, on the owner's w86 save (the fixture): the constants and prices (Asah's 60k / 150k by the
target's stars, none at ★3, for a Legenda or for one not owned; no small relics; `leburTargets` without the fodder and
the oath); a Lebur (the fodder gone with its stars, the target's star and the gold, the bag and `asahAt` untouched,
the Templar refit with the HP gained, a gold burst on each, `Sfx.clear`, the `PusakaLebur` JSON and its log line),
an Asah and a second Lebur (150k) in the same boss interval, one into the Gudang; the fodder dealt again (a ★3 one
in the Gudang is on no chest card, melted it is, and taken back at ★1); every refusal and their order; the save
(no new key); the telemetry's `gold.leburSpent` in the next wave's record; every line it shows against the HUD
font's cmap. One widget test, one `TdGame`: the button on a Gudang one only, the picker's rows, Batal, the two taps,
the message and the pick moving to the target, a ★3 row's refusal, mid-wave. The picker fitting 1266×713 and 1164×777
(its row over the Vault Artifact's Sell row, then its head and Back over the list, every row in it and apart, the
list scrolled by the wheel to its last row) is in `test/pusaka_tas_ui_test.dart`. Getters: `Board.leburButton`,
`leburOpen`, `leburArmed`, `leburBack`; the picker's rows are `assignRows`, each by its Pusaka. The shots come from
`test/probe_lebur_shots.dart` (a probe; queue `["test", "test/probe_lebur_shots.dart"]` with the worktree as `dir`;
`OUT` sets the folder, default `<agents>/shots/lebur/`): ready, picker, armed and done at 1266×713 and
412×860, and the gold short on the desktop.

## Ukir (decisions-log 183)

`test/ukir_test.dart`, pure Dart, on `test/fixtures/save-20261002-2222-w89-sellbug.json` (the owner's w89 save, a copy)
and plain games: the constants (the five steps and their worth, the budget, the tap, the points, every item kind in one
role, the rows' roles, the owner's defaults); `pusakaAt` at Ukir 0 exactly the table for every Pusaka, star and the
boss, between the stars and past ★3 (the design's numbers), ★n+5 short of ★(n+1), God's Thunder's share and Dragon
Crown's cap by their named rules, the texts reading it; a tap's items in their order (the role's kinds first, the most
spare each pick) and the `UkirFed` / `UkirStep` JSON (never in the battle log); no point spilled past a step or the
budget, a role's item never split; the shared 180 a boss interval and its reset at the boss wave; the Bangkit items
kept; the refusals in order; a step refitting the type (Dragon Heart's HP, the gold burst, the HP tooltip), Dragon
Crown's and Dawn Star's texts; Ukir kept by a star-up (Asah), moved by a Pindah and the Gudang, lost by a sale (the
run's worth fed kept), a Lebur keeping the higher; the star-ups for the enemy buffs on exactly the steps that pass a full
star, the same on a second run; with the Bayangan on, the Grail's star-up giving its counter its levels (omen.dart's hook), none while off; the save (the w89 save writes the same JSON, no Ukir key; Ukir, the bar and the budget
come back; a bad save clamped); the telemetry (tv 8, the events, the next wave's `ukirItems` / `ukirPoints` /
`ukirSteps` and each Pusaka's `ukir`, none in a wave without Ukir); Asah taking no items by default. No widget test: no
UI yet.

## Bangkit 4-5 (#92 part 2)

`test/ascend_test.dart`, pure Dart on `bareGame`: the constants and level names; `awakenLevel` counts `ascended` only
at `itemLevel` 3; Bangkit 4 and 5's HP and MP (×2.0, ×2.25 of the base, the heavy types' +20% after), damage (a heal)
×1.25 and ×1.5625 of Bangkit 3's, the other stats, price and caps unchanged; the refusals in order; a buy (100k then
250k, the troops refit with the HP gained, the burst, the sounds, the `Ascended` event and its log line); the nine
awakening skills' cooldown ×0.85 a level, MP, numeral and lines at Bangkit 3's, and a Bangkit 5 soldier's Disarm with
Bangkit 3's numbers; the book's words (`awakenInfo`, `ascendInfo`); the save (round trip, the troops' HP at load, an
old save, odd entries); the bag's hint (`bagLevel`, `bagAwakens` for fielded types only).
`test/ascend_hud_test.dart` boots its own `TdGame`: the Tas tab's dot while a fielded type's next Awaken is in the
bag, gone without it, and no Toko tab (`storeAt('bagDot')`); the Toko's Bangkit section it tested went in
decisions-log 296 (the Army detail's button: troops_detail_test.dart).

## The first-time guide's words and triggers (ui-hud.md "Guide")

`test/guide_text_test.dart`, no game: every page at most 4 lines of at most 6 words (a quoted name one), the titles and
the topics' own lines too, in the guide (`guideFor`) as the checks after it; 7 intro
pages, P1-P5, K0-K24 as the rules (K4 and K5 two pages), I7's mouse line; the topics repeat
every intro page and card once; every quoted name a string in lib/ (its `_literals` reads lib/'s string literals,
interpolations and comments left out) or one of the guide's labels; no digit written in lib/guide_text.dart outside a
quoted name, and every number shown one of the constants (pinned lines for the intro's I3, I4, I6 and the cards with
numbers); the Awaken words by the forge: by grade K8's and K9's grade line and the topic's last-level share from
town.json (two thirds; a patched 0.75 reads "75%"), the shipped guide (`guideEn`) the one by grade word for word (its
forge-off words went with that build, decisions-log 296); the forge's K4 ("Win it: rare materials"), K11 (the
materials that dropped), K23 and K24 (the Smithy makes items too); no aiming words; every character
in the HUD's font. `test/guide_rules_test.dart`, plain games: the gates;
nothing due at wave 0; each card's trigger, true and false (K16 by a real march: the free priest alone against a bat,
as game_test.dart's, then `stalled` cleared by the next wave and never saved; K18, K20, K21 on the owner's w86 fixture; K22 from wave 40, between waves, with spare items, never an oath);
`guideNext` (mid-wave none, the intro first, a passing card before K1, K0 after the dropped pointers; with the chest's
popup open only K5 then K12, without it never them); `seenFrom` with
no save, at waves 0 and 4, and on the w86 fixture (K14, K15, K18, K20, K21, K22 left; K15, K18, K20, K22 due in that order); the
seen set in settings.json (round trip, missing, broken, odd entries) surviving "New Game"; `savedWave`.

## The first-time guide on the screen (ui-hud.md "Guide", lib/coach.dart)

`test/coach_hud_test.dart`, one TdGame each: New Game opens the intro while unseen (Back greyed on page 1, Next,
Back, a tap off the card, Space, ←, Enter, →; Skip closes it, seen and in settings.json; the next New Game opens
none); "Play!" closes it on a phone (915×412); Esc closes a card without pausing and P under it does nothing; nothing
under a card reacts (a spawn bar card, Start, Auto, x2, the Tas tab: each tap only turns the page; a drag of the Priest;
no tooltip, the field covered; the HUD works again after Esc); a right click and the wheel under a card leave the loot
in hand and the Tas list as they are, and Esc keeps the loot; Auto's countdown waits while a card shows; "How to Play"
on the welcome screen plays the intro over it (New Game and Scoreboard under it only turn the page); no seen set: no
intro, no pointers, How to Play still plays and nothing is saved; P1 (at the first price it buys, right of it) → P2 →
(an item) P3 → P4 → P5 by their actions, P3-P5 and K0 seen and saved once the item is given; P1-P2 and P3-P5 dropped
after two breaks (K0 not seen).
`test/coach_fit_test.dart`, at 1266×713 and 915×412: every page of the intro and of each card K0-K22 8 px
inside the screen (its ribbon in), its buttons inside it and apart; P1-P5 8 px inside, their box and tail clear of the
target over 20 frames of their bob; the welcome screen with a save: its four buttons on the screen and apart, "Scoreboard | How to Play" one row under New Game, alike and centred. The shots: test/probe_coach_shots.dart (a probe, in a
mirror).
`test/guide_page_test.dart` (the How to Play page, ui-hud.md "How to Play page"), one TdGame per widget test: at 1266×713
and 915×412 Settings' "How to Play" under both volume rows and clear of them and of the right page's
buttons, in the book; it opens the page (the Settings tab stays the open one); the two columns, "Back" and "Replay
guide" in the book, the buttons under their columns; every topic in the list (the wheel scrolls it) and each opened
by a tap with its first page's title and lines on top; "Items & Awaken" scrolled to its last line by the wheel and
back to its top by drags, a drag on the list opening nothing; Back, and the page opening again on the topic open
last. At 1266×713 every topic holds its pages' titles and joined lines, its own lines, and its live texts (every
item's and small relic's name and lines, a line they all have once; the Epik and Langka Pusaka at one star with their
rarity, no Legenda); K5's shared title once. At 915×412 "Replay guide" plays the intro over the page, a tap on a topic
under it only turns the intro's page, Skip and "Play!" bring the page back on its topic, and the seen set stays as it
was; with no seen set it plays and nothing is saved. Shots: test/probe_guide_page_shots.dart (Settings, Items and
Pusaka at their top and end, the intro over the page; a probe, in a mirror).
`test/coach_cards_test.dart`, one TdGame each, the one-time cards at real breaks (a wave started and won at once): a
card due opens once "VICTORY!" is over (none during it, none before this game's first win), holds Auto until tapped, is
seen and saved, and never opens again while still due; one a break, the next at the next break; none before the intro
is seen, while paused, while a message shows (then after it), or mid-wave; a new Hero's splash first; a boss chest holds
the cards, K5 opens over its popup (a tap there only turns K5's page; closed, the chest takes presses again; the other
card waits for the next break), and with K5 seen the card waits for the chest until it is taken; K12 over a chest with a
Legendary; the seen cards survive New Game while the new game's breaks get their own; the owner's w86 fixture with
`seenFrom(86)`: no card before its first win here, then K15, K18, K20, K22 one a break, K14 and K21 once due, nothing else;
K5 over its chest 8 px inside 1266×713, 1164×777 and 915×412, both pages. The shots: test/probe_coach_cards_shots.dart.

## Tempa (decisions-log 163)

`test/tempa_test.dart`, pure Dart on `bareGame`: the constants; the purse (wave 86 156k, 87 166k, 100 358k, 105 479k)
and the prices pinned (wave 87 33k-69k, wave 100 72k-124k, never under 1k); the refusals in order; a buy (the troops
refit with the HP gained, the burst, the sounds, the `Tempered` event and its log line) and the next level compounding;
HP and damage ×1.05 a level on six types (the heavy ones' +20% after), the other stats, the price and the awakening
skill unchanged; levels waiting below Bangkit 5; a Hero's ×3 on top; Lepas jenis keeping the levels with no refund of
them; the save (round trip, the troops' HP at load, an old save, odd entries); finite stats for a Bangkit 5 Hero at
Tempa +30 with Dawn Star ★3 and Oath of One, fighting a boss; the Army tab's dot (`tokoNudge`); the cards (`tempaInfo`,
`awakenInfo`); the telemetry (`tempa`, `gold.tempaSpent`); every line in the HUD's font. `test/tempa_hud_test.dart`
boots its own `TdGame` at 1266×713 and 1164×777: the Army tab's dot (the Toko's until decisions-log 296), "+3"
after the stars in the knight's Army detail header (never on its cell, decisions-log 218), the dot gone under 3
purses, and the Tas rows' "+4" (`Board.tempaMarks`, `storeAt('tokoDot')`). The shots come from
`test/probe_tempa_shots.dart` (a probe; queue `["test", "test/probe_tempa_shots.dart"]`; `OUT` sets the folder, default
`<agents>/shots/tempa/`): the owner's w86 fixture with its three Bangkit 3 types at Bangkit 5 and Tempa +6, +2,
+14, on the Pasukan, Toko (before and after a buy) and Tas pages at 1266×713 and 412×860, and a Tempa row's card
(the Toko's shots went with it in decisions-log 296).

## Hero Gugur (#92 part 3)

`test/recall_test.dart`, pure Dart on `bareGame`: the price (57k / 80k / 118k / 313k at waves 65 / 72 / 80 / 100); a
Hero's fall keeps it (name, type, attributes, skill, the wave; its relics in the bag), a troop's doesn't; Resurrection
never raises it; a recall brings the same Hero back (its type's stats now with Bangkit and Pusaka ×3 on its two, full
HP, empty slots, the aura, autoPlace's cell, no Hero or name dice drawn, `HeroRecalled` and no `Bought`); `heroMax`
(refused at 5, a 10th wave crowns none past it); every refusal in order through `buyRefusal` (the store locked, mid-wave,
over; "Army full 32/32", "No room", "Already 5 Heroes", "Not enough gold" against the recall price, not the troop's); a
Hero whose type is at its cap swaps too (decisions-log 201: "Knights full: … goes home", the type's count kept; all
Heroes: "Knights full 10/10"; no swap without the caps); the save (round trip, old saves and the w86 fixture
with none, odd entries); the log line and the event's JSON. A full army's swap (decisions-log 167): one plain troop of
the type goes home (the lowest HP share, one waiting for the heal as whole, of equals the lowest id; a Hero never),
refunded `releaseRefund` × its price, its relic in the bag, not fallen, the count and the type unchanged, the event's
`swapped`/`refund` and the log's second row; no plain troop of the type ("Pasukan penuh: tidak ada Knight untuk
ditukar", then "Hero sudah 5", then "Not enough gold" against the whole price); room (nobody swapped, as before); over the
cap (48 stays 48, with the zone's every cell taken). Its fall helper turns the skills off and uses melee troops: an
archer at 1 HP steps back out of an orc's reach. The Toko's Fallen Heroes side and its `test/recall_hud_test.dart` went in decisions-log 296: the Army detail recalls
(test/town_shop_ui_test.dart, test/troops_detail_test.dart).

## Relics taken off and a Hero's two (#91)

`test/relic_slots_test.dart` (plain tests, `bareGame` / `placeNow`, skills off): `takeOff` between waves puts the
relic back in the bag, from where it is given again or sold; mid-wave it is refused and so are a relic not held, a
fallen troop and game over; a Pusaka isn't held, and unbound its Dragon Heart's HP goes with it. A Hero takes two
different kinds and refuses the same kind and a third ("Relic slots full"), any other troop one; guard with fang
and fury beside another work on one Hero, and its type's Pusaka comes on top without a slot; a fallen Hero gives
both back; the save keeps both, and a save with the old `relic` key still loads. `test/relic_slots_ui_test.dart` (one `TdGame` per widget test, as
drop_popup_test.dart): with nothing picked the Tas page lists the troops holding relics, a Hero with two slots
(`Board.assignSlots`); a tap on a held slot picks it out (`takeOffArmed`), Lepas (`takeOffButton`) takes it off; a
picked relic lists a Hero with one relic as able to take another; the drop popup over a Hero counts its slots;
mid-wave Lepas says "Only between waves" and takes nothing off. The pinned plate has a Lepas per relic
(`Board.plateTakeOff`): one comes off and the pin stays, and mid-wave it says why.

## The Tas page's list (#87)

`test/assign_test.dart` (plain tests, `bareGame` / `placeNow`): `Game.assignPreview` for an item on a type (the stat,
price, taken/cap and recipe progress now and after, and that `useItem` then gives exactly that; the item that
completes an awakening; the refusals, each exactly when `useItem` refuses) and for a relic on a troop (a plain relic
changes no stat, a Pusaka is refused with `pusakaOnType`; "Already holds <relic>", a fallen troop, an empty bag), and the rate's floor and
the stat names. `test/book_assign_test.dart` boots one `TdGame` and plays the list through the page
(`Board.picked`, `bagSlot`, `assignRows`, `assignList`, `assignChip`, `assignFilter`):
- a picked relic lists the living troops in the book's order, the one holding a relic greyed; a tap on it says why;
- a row gives one, the pick stays and the row greys, and the last copy ends the pick (the page is then blank,
  decisions-log 241);
- a picked item lists the types, the wrong ones greyed; a drag on the list scrolls it and gives nothing, and the wheel
  scrolls it to the end;
- the filter shows the chosen types, several at once, and stays through another pick, a turned page and the book
  shutting for a wave and opening from its button; "All" clears it;
- at 915×412 the chips take two rows and the list stays on the right page.

The desktop, phone and 915×412 shots for the owner come from a probe in the mirror (`probe_shot.dart`, the #87
report).

## The Bag's grid (decisions-log 187)

`test/bag_grid_test.dart` (ui-hud.md "Tas, the Bag"; one `TdGame` per widget test, a board game at wave 30 with a long
run's bag: five items, three small relics, Pusaka bound, asleep, in the Gudang and an oath's):
- at 1266×713 and 915×412: a cell per kind owned, all 44×44 (desk) or 36×36, inside the left page and apart,
  in reading order and the All order (`bagKinds`); none for a kind used up or a Pusaka not owned; the count from 2;
  the stars, the bound type's mark (asleep: faded), the oath's swords, none in the Gudang; no NEW in a game that came in;
- binding, moving, unbinding and Asah leave every cell where it was; the last gift, Jual semua, Lebur's fodder and a
  Gudang sale take theirs away, the next close up into its place, and nothing is picked in its place (Lebur's target
  is);
- the press-kind guard: a cell that slid under a held finger (the kind before it ran out) is not picked on tap up;
- the board (`bagSlots`), at both sizes: a slot at every place a page holds, each a cell's size, 2 sprite px
  apart across and down (4 on the desk, 2 at 915×412), in whole rows, centred under the chips; the cells in the first
  slots in order, the rest empty; at 915×412 the last page's board whole too; with nothing owned, the board less the
  rows the empty text's card covers;
- a page holds 36 / 30 (above the pager) on the desk and 12 / 12 at 915×412, and with the note's
  strip 30 / 24 and 12 / 8 (`bagPageSizes`; inside the book's padding, decisions-log 198, on the shorter
  landscape book, 283), the same all through the book's bob, the strip under the cells;
- at 915×412, where everything owned (every Pusaka with every item and small relic) takes more than one page, as
  many as the catalog fills: the pager (faded at the ends) walked to the last page and the wheel (a notch a page; a
  second event within 0.25 s does nothing), the Artifacts chip's own pages, a page turn hiding the pick putting it
  back, and Lebur's target turning the grid to its page;
- the chips at 915×412 and 1164×777 (each category, in one row over the grid, at least 20 px tall, on whole pixels as
  drawn, decisions-log 291), a chip hiding the pick putting it back, Artifacts only once the Shop opens or one is owned;
- NEW (a kind gained, until picked or the page left; a relic back from a troop) and the ▲ (the items a fielded type
  can awaken further with, gone when one kind runs short);
- the empty texts (All's bag, Items, Relics with those worn, Artifacts and where they come from), at 1266×713 and 1164×777;
- the taps each Bag action takes (the design's table and decisions-log 202), at both sizes: an item 3 then 1 a copy,
  a relic 3, Take off 2, Sell 2, Sell all 3, bind / move 3, To Vault 2, Lebur 4, a Gudang sale 3, Asah 3, a chip 1,
  the note's OK 1; at 915×412 the grid turned and the action rows wheeled to what is tapped (no tap).

The shots come from `test/probe_bag_grid_shots.dart` (a probe; queue `["test", "test/probe_bag_grid_shots.dart"]` with
the worktree as `dir`; `OUT` sets the folder, default `<agents>/shots/bag-grid/`): the Bag at 1266×713, 412×860
and 915×412 with the long run's bag, an item,
a Gudang Pusaka and a bound one picked, a cell gone after Jual semua, the empty bag, and with the grid's own getters
(lines marked `grid only`: a copy without them runs on a checkout from before the grid) the empty Relics chip, NEW and
▲, the note, Lebur's picker, every Pusaka on the first and last page (two pages only at 915×412) and under the
Artifacts chip, a pressed Legenda cell beside the pick, the Items chip and the mouse on a cell.

## The Bag's light controls (decisions-log 198 "Bag chips")

`test/bag_chips_test.dart` (ui-hud.md "Tas, the Bag"; one `TdGame` per widget test inside a `RepaintBoundary`, read off
the drawn screen with `screenPixels`, the rects read in the frame the pixels come from, since the book bobs):
- at 1266×713 and 915×412, the category chips: one strip across the left page's writing (`bookPages`), the
  segments next to each other, one top and height (≥ 20); the one on (All, then Items) is the pick's cream FFE9C2 and
  orange F77622, every other one none of either and mostly the page's paper F6CA9F (no bevel); under the mouse a
  segment lights (less of it paper, no cream);
- at both sizes, a relic's Equip chooser's type filter: All on is the pick's cream, a type off none and its top
  row the plain card's rim E69C69; a type turned on cream and All not; a type under the mouse the lit card (its top
  row the outline BF6F4A), not cream;
- at 915×412 with everything owned: the pager's two places ≥ 32×20 and mostly paper; on the first page ◂'s capsule
  faded (no pixel of the outline 181425) and a tap on it no turn, ▸'s outline drawn; on the last page the other way.

The shots come from `test/probe_bag_chips_shots.dart` (a probe; queue `["test", "test/probe_bag_chips_shots.dart"]` with
the worktree as `dir`; `OUT` sets the folder, default `<agents>/shots/bag-chips/after/`). It uses only
getters from before the restyle, so the same file shoots the before shots on a checkout of main: at 1266×713, 412×860
and 915×412 All, Items, the mouse on Relics, everything owned on its first page (and the mouse on its ▸) and its last
(two pages only at 915×412 with today's catalog), a relic's chooser with All on, two types on and the mouse on a third,
and an item's Give to troops.

## The Bag's facing page (decisions-log 187 and 202)

`test/bag_detail_test.dart` (ui-hud.md "Tas, the Bag", "The facing page"; one `TdGame` per widget test, a board game at
wave 30 with the grid test's long run's bag and the soldier wearing a Fang), through `Board.bagDetail(key)`,
`bagDetailText(key)`, `bagActions` and `bagAction(act)`:
- at 1266×713 and 915×412, for nothing picked, an item, a small relic (and one worn), a Pusaka in the Vault
  (two), bound, asleep and an oath: the heading's icon 32 px on the desk and 16 elsewhere (none for nothing picked),
  the name (or that name cut to fit), the count ("x86", "★2", "x1" relics worn), the where line ("Rare · in Vault",
  "Epic · on Knight (1)", "… (asleep)", the oath's), the description (`_detailDesc`: whole, never cut, in at most 3
  lines on the desk and 4 at 915×412), and the action rows in their order (`_actionsFor`), every part inside the page,
  the heading's apart, the lines one under another, the list under them, its rows apart and inside it, the first two
  whole and, wheeled to its end, the last; nothing picked has no line and no action; only a Vault Pusaka sells;
- at the same two sizes, every Langka and Epik Artifact (52) at ★1 and at ★3 carved +5, one after another in the
  Vault: its description whole in at most 3 lines on the desk and 4 at 915×412, or what it does whole without "For a
  whole type, never lost." (decisions-log 214), no line cut, inside the page with the action list under it; it prints
  the longest and the ones that dropped the closing sentence;
- both sizes: the Sell row's words ("Sell +1000", "Sell all +86k" or shorter, "1,000 gold each"), its tags inside
  it, armed "Sure? +86k"; the Vault's "Sell +15k", "Gone for good" and armed "Sure? +15k"; mid-wave "Sell" / "All"
  greyed with why, the row greyed, a tap says `storeRefusalNames`' mid-wave and sells nothing, the Vault's Sell and
  Melt greyed and refused with their words;
- both sizes: Melt's picker from its row, under the heading with its Back (`bagBack`) and "Melt Grail ★1 into:"
  (or a shorter form), no line and no action row, Back closing it to the action list's top, a target's row melting
  in two taps, the pick moved to it with its action list, and the message;
- nothing picked: the facing page blank (no text, chips, rows, slots or actions) at 1266×713, 1164×777 and 915×412,
  with relics worn, none worn and no army; a pick and its second tap, and another tab, as before;
- every new word (the labels, the where lines, the action rows' titles and lines, the descriptions' tails, the
  messages, the refusal tables) in the game's font.

`test/bag_actions_test.dart` (decisions-log 202; the same kind of board at wave 45, Carve open, the Grail with 40
points on its bar), through `bagActions`, `bagAction(act)`, `bagChooser`, `bagBack` and the rows' 'title:<action>' and
'hint:<action>' words:
- the desk: each pick's rows, titles and lines (an item's "n types can take it", "Carve: n can take it", "1,000 gold
  each"; a small relic's "n troops can wear it", a worn one's "1 troop wears it"; a Vault Pusaka's "Free: a whole
  type gets it"; a bound one's "Costs …" and "Templar loses it, free"; an oath's "What it gives each type"),
  greyed exactly where its rule says no (`whyNotAsah`, `whyNotUkir`, `whyNotLebur`); before wave 40 Give to an
  Artifact greyed, and its tap says `ukirRefusals.from` and opens nothing; mid-wave a bound Pusaka's rows greyed and
  their taps saying why;
- at 1266×713 and 915×412, each chooser (Give to troops, Give to an Artifact, Equip on a troop, Remove from a troop, the
  type rows, an oath's Each type): Back under the heading inside the page, its title, the chips only where it lists
  types or troops, the rows inside the list, what they list (types, Pusaka without the oath, troops, the wearer); a
  row acts (a copy given and the chooser kept, a Pusaka fed, a relic put on, taken off and the chooser closed with
  none worn, a Pusaka bound and the chooser kept as "Move to a type", the oath's message), an armed Sell all let go
  on opening, Back to the list's top, another pick never showing the last one's chooser;
- the taps the action list adds: Remove from the pick 3, Give to an Artifact 3, To Vault 2, Back 1;
- the action rows' words in the game's font.

The shots come from `test/probe_bag_actions_shots.dart` (a probe; queue `["test", "test/probe_bag_actions_shots.dart"]`
with the worktree as `dir`; `OUT` sets the folder, default `<agents>/shots/bag-actions/`): at 1266×713,
412×860 and 915×412, at wave 45, nothing picked, the Sword and its Give to troops and Give to an Artifact choosers, Fury
and its Equip on a troop, a Vault Pusaka and a bound one and its type rows; with the action list's getters (lines
marked `actions only`: a copy without them runs on a checkout from before it) a worn Fang and its Remove from a troop,
the Vault's Sell armed, an oath and Melt's picker.

The shots come from `test/probe_bag_detail_shots.dart` (a probe; queue `["test", "test/probe_bag_detail_shots.dart"]`
with the worktree as `dir`; `OUT` sets the folder, default `<agents>/shots/bag-detail/`): at 1266×713,
412×860 and 915×412 nothing picked (with and without relics worn), an item (and its Sell all armed), a small relic, a
Gudang Pusaka (and its Sell armed), a bound one, an asleep one, an oath, Melt's picker, an item and a Gudang Pusaka
mid-wave; and with the detail's own room (lines marked `detail only`: a copy without them runs on a checkout from
before it) a Gudang Pusaka and an item's list end with Ukir's room kept.

## The book's sprite kit and its words (decisions-log 187)

`test/book_kit_test.dart` (ui-hud.md "The book's sprite kit"):
- plain tests: `slotSrc` (each colour 48 px down, the looks 192 apart, pressed 3 rows shorter) and `slotRect`
  (pressed 3·k lower, ending on the normal one's bottom row); `recolourMatrix` takes the slot's four colours to each
  rarity's exactly (summed the way `ColorFilter.matrix` sums, its offset in 0-255), keeps alpha, and throws on four
  colours on one line; `capsuleSize` holds the font's glyphs inside its outline with a pixel to spare, at least 2 px
  each side, on whole pixels, the icon a square; `shortCount` ("1.2k" cut, not rounded);
- `art`: boots one `TdGame` and reads `ui_all.png` back from `game.images`: every look of every colour has its corner
  cut and its outline on top and bottom, and `slotInsets` are exact (each row of the stretched middle one colour
  across, each column one colour down) and the least that are; then `Board.drawSlot` on a fresh canvas: each look of a
  Pusaka cell, at its own size, is the tan slot pixel for pixel with rim and lip in the rarity's colours (within 3),
  the tan one with no rarity the slot itself, and at k = 2 the corners are the sprite's pixels doubled;
- a booted board at 1266×713 and 1164×777 on the w89 fixture (at 915×412 "x9.9k" is its slot's width and pokes a pixel
  out of it, decisions-log 289), the shelf open and 9999 potions ("x9.9k", the widest count): every Shop badge (`storeAt('badge:<kind>')`) in its slot's top right, 13 px tall at least (10-px text);
  with God's Thunder picked on the Tas page the list's scroll bar (`scrollBars`) is 6 px wide, as tall as the list,
  down its right, and every row ends left of it; each bound type's Pusaka mark (`pusakaBadge`) inside its Army
  row, 13 px tall at least on a wide (desk) row's capsule, 12 on a narrow row's sprite icon; the Licenses page's columns
  have the same bar.

`test/words_test.dart`: every constant of `Words` (lib/words.dart) is non-empty, without stray or double spaces, and
no two are alike (one word for one thing); it reaches `Words` through game.dart. The Army detail's attribute helps
(`Words.hpHelp` …, decisions-log 218) are each a list, the longest first, none empty or with stray spaces.

`Board.bagOpen` (the book drew the Tas page this frame) replaced `bagSlot(Item.sword) != Rect.zero` as "the Tas page
shows" in asah_test, ascend_hud_test, coach_hud_test, drop_popup_test, lebur_test, pause_test, pusaka_tas_ui_test
and relic_slots_ui_test (and bag_sell_ui_test and probe_bag_sell_shots, gone in decisions-log 296): the Bag grid will give a kind with none left no slot.

The shots: `test/probe_book_kit_shots.dart` (not in the suite), the Shop (shelf shut and open), the Tas page (an item,
a Pusaka, nothing picked), the Army rows and the Licenses page at 1266×713 and 412×860, then `kit.png` (each slot
colour's three looks at k = 2; each Pusaka rarity's cell at k = 3 beside the rim-only recolour; the tan and orange
slots; a phone and a desk cell). Queue it in a mirror of main (its kit part cut, which main lacks) and of the branch,
`OUT` set to two folders.

## The book's padding (decisions-log 198)

`test/book_padding_test.dart` (ui-hud.md "Layouts"): `bookPadY` 10 and `bookPadX` 5 (the owner's), `bookWriting`; at
1266×713 and 915×412 each page's writing (`Board.bookPages`) sits its printed line plus the padding inside the
book (`bookArea`) at the book's pixel scale, both pages as wide; every tab's parts inside it: the Army grid's cells and
pager and the header's +Room on the left (decisions-log 260), the detail's sections and buttons and the foot's Release and its press area on the right (decisions-log 218, 288); the Bag's chips and board and the picked sword's page and
list; the Shop's goods, its tabs and Awaken rows; Settings' volumes, How to Play, the toggles and Main Menu.

## The book's shadow (decisions-log 275 and 304)

`test/book_shadow_test.dart` (ui-hud.md "Layouts"; `Board.bookShadow`, its rows and paint): on the field at 1266×713
(`ps` 2) and 915×412 (`ps` 1), and in a Town (town_scene_test's `intoTown`) at 1600×947, 1266×713, 1164×777 and 915×412,
booted `TdGame`s.

- Pixel art: 18 screen px of rows to whole book px (9, 18), each `ps` tall on whole screen px, as wide as a whole number
  of book px, its ends on the book's grid; a stepped ellipse (each row as wide as its mirror row, none narrower toward the
  middle, the first narrower than the widest); 0.75-0.85 of the book's width; under the book's middle; no anti-alias.
- Over a whole bob (250 frames): its rows stay on the ground, and with the book higher it is never wider; its width
  changes.
- At both sizes the alpha follows the slide in, frame by frame 0.25 of the ease read off the book's left (a wave shuts
  the book, its button opens it mid-fight); no rows while it is shut.
- In a Town none (decisions-log 304): through the fade in, rows under the open book on every frame the field still shows
  and none on every frame the Town does; none over a whole bob, nor on any frame of the slide back in after a tap on the
  bare scene shut the book and the Smithy's sign opened it; after leaving, the field's book has its pixel shadow again.
- Probe: `test/probe_book_shadow_shots.dart` (`--dart-define=TAG=`, `OUT=`, `SIZES=` some sizes only; it reads only the
  book's box and its rows' count, so it also runs on a base without 304): the field and a Town at 1600×947, 1266×713
  and 915×412, at the bob's top and bottom; the field's shots are byte for byte the same with and without 304.

## The book's marks: tabs only (decisions-log 285)

`test/book_marks_test.dart` (ui-hud.md "Bookmarks"): at 1266×713 and 915×412, booted `TdGame`s with no guide,
the board rendered into flutter_test's `TestRecordingCanvas` on every page of the field's book (at wave 20: Army, Bag,
Settings) and of a Town's (town_scene_test's `intoTown`: Smithy,
Tavern, Shop, Army, Bag, Settings): what it takes from `ui_book_marks.png` is the page tabs only (sheet x < 60), never a ribbon flag
(x 162 on): no gold or wave ribbon at either size; the gold panel (`heartsGoldPanel`) and the wave meter
show. Probe: `test/probe_book_ribbons_shots.dart` (`OUT=`): at 1266×713, 1164×777, 915×412, 412×860 and 1600×947 the
w89 fixture's book on Army and Bag, and a Town's on the Smithy and the Shop.

## The Army page (decisions-log 187 and 218)

`test/troops_detail_test.dart` (ui-hud.md "Army"), one `TdGame` per widget test, on the board's rules. Three windows:
1266×713, 915×412 and the owner's tablet 1164×777. Its helpers: `pick` (a type's cell,
the grid turned to its page with the pager first, each turn a tap), `sweep` (one pass over every scroll of the detail's
body, 6 px a step: where each key starts in the sections and the scroll that shows the most of it) and `reveal` (scrolls
the body there, for a tag to tap).
- a cell tap (`Board.troopRow(type)`) picks (`troopPicked`) and spends nothing, again nothing; no Buy on the detail
  (`troopDetail('buy')` Rect.zero, no words: buying is the spawn bar's, decisions-log 283, test/spawn_bar_test.dart);
  the pick lasts across page turns and another game picks again (the first type alive);
- Release at 1266×713 and 915×412: no Release for a type not picked (`releaseChip`), the detail's arms
  (`releaseArmed`), the confirm (`releaseConfirm`) on the right page, a cell tap lets it go (and picks that cell);
  from another type 3 taps (cell, Release, confirm);
- Replace fallen (`replaceButton`) at all three windows: on the right page at the foot's bottom-left on Release's line
  ("Replace fallen (1)  <price>"), under the body, neither it nor its press area (`troopDetail('replaceTap')`) on
  Release's (`'releaseTap'`), Release keeping its rect while Replace shows and hides; no separator
  (`troopDetail('separator')` Rect.zero, decisions-log 288); +Room (`capacityButton`) not in the book (the spawn bar's,
  decisions-log 283);
- the fit at all three: on the shorter landscape book (decisions-log 283) two grid pages at 1266×713 and 1164×777, three
  at 915×412 (the pager's arrows `armyPager` at each); every type on one
  page, in `troopTypes` order, two to a row (beside the one before, under its column's), cells of one size, 48 px tall
  at least, inside the screen and the left page (`bookPages`), over the pager; no Buy anywhere, no Release but the
  pick's; the header (`troopDetail('heading')`) under half the right page; header, body (`troopDetailBody`) and
  Release's press area one under another, right of the grid and inside the right page; Release 24 px tall at least at
  the page's bottom-right, narrower than half the page; no separator; the pick's eight stats (`troopRowStats`) and item
  cells (`itemCells`) right of the grid;
- the pager at 915×412 (three pages): ◂ on the first page does nothing, ▸ turns to the middle page and the last, the
  pick stays; a cell on the last page picks; the wheel over the grid turns back and on (one notch, then its 0.25 s gap);
- the page's rows of the tap budget at 1266×713 and 915×412: +Room 1 (on the spawn bar), Replace fallen 1,
  Release of the pick 2, of another type 3 (a buy is the spawn bar's one tap: test/spawn_bar_test.dart).

The right page's detail (troop_detail.dart), read through `Board.troopDetail(key)` (a section's or a button's rect,
cut to the body's view; Rect.zero when not shown or scrolled out) and `troopDetailWords(key)` (the words drawn there,
in view or not):
- the heading, stats and next step always; the Artifact ("No Artifact" + Bag while one is owned elsewhere; its name,
  `pusakaGist` and Change once bound), the Heroes (a living one; "Fallen Heroes: 1" + Shop once the Shop is open) and
  the relics ("Relics: none", "x1"; nothing with none alive) only when they have something to say; no section's
  words hold an Indonesian word (a stop list);
- the attributes equal `fieldStats`; each short name of `Words` (HP, MP, Def, Dmg, Range, Speed, Rate, Regen; a
  healer's Heal) and a help line ("Damage it can take") among the words, each recipe item's "taken/cap"; two to a row
  (the first two item cells side by side, the third under them);
- the Awaken needs: "Awaken 1 needs:", each recipe item's "name | 0/n", "In Bag: 1" for the one the Bag holds,
  "Drops from monsters" for the rest; from wave 15 "Shop <price>" (`buyPrice`);
- the next step's button and the Shop's Awaken row, each on the same game: Awaken 4 bought (the same gold, level and
  "Knight: Awaken 4!"), too poor (the same refusal), Forge +1 at Awaken 5; before wave 15 greyed with "Awaken 4: Opens
  after wave 15" and a tap says why; mid-wave at 915×412, the book opened by its button (paused), "Only between
  waves";
- the shortcuts at 1266×713 and 915×412: Change opens the Bag with the Artifact picked and its cell shown; Bag opens
  the Artifacts chip (`bagCategory`); Shop opens Fallen Heroes (`storeAt('recall:0')`); "Awaken 3 from the Bag" picks
  the first item the archer needs, and a tap on its Bag row gives it (2 taps);
- the foot at 1266×713 and 915×412: Release arms, the confirm (`troopDetail('confirm')`) at the page's
  bottom-right, +Room (the spawn bar's) stays, 2 taps; mid-wave (at 915×412, the book opened by its button, paused)
  Release says why; a type with none alive has no Release, its body reaching down to the page's bottom (10 px at most);
- the foot (decisions-log 288) at 1600×947, 1266×713, 1164×777 and 915×412, the knight picked on four types:
  no separator; Release at the page's bottom-right, as wide as its words' box (`troopDetail('releaseWords')`) with the
  button's margins (2·(4k + 6), k = ⌊height / 16⌋ from 1 to 3), its words inside it; its press area 44 px each way at
  least (`detailTapMin`) around it, the body over it; armed, the confirm from the same right edge and bottom leftwards,
  over Release's spot, inside the row, as wide as its words (`'confirmWords'`) with the margins, its press area
  (`releaseConfirm`) 44 each way, its words "Send Knight home? ..."; a second tap on the same spot sends the knight
  home with its refund; then on the archer, one fallen and seven (a longer price), each unarmed and armed: Replace
  fallen at the page's left, as wide as its words (`'replaceWords'`), its press area 44 each way, beside Release or
  its confirm (the same bottom) or over it, never on it, nor its press area on theirs, its label with the count, the
  body over both; a press on Replace fallen buys the soldier back;
- the fit at all three with every section on: the body between the header and the foot, under the header at every size
  with the foot one line, 60 px tall at least (`detailBodyMin`); at 915×412 Replace fallen over the knight's armed
  confirm (the foot two lines) puts the header inside the body, and letting it go takes it back out; each
  section reached by the scroll (`sweep`), in order, inside the body, right of the grid; the tags 18 px tall at least
  inside the body; the scroll stops at the sections' end (`troopDetailContent`, `troopDetailScroll`), which is past
  the body at 915×412; a new pick shows the top; every type's item icons inside the body;
- the body scrolls by the wheel and by a drag (at 915×412, the shortest page), and a drag picks nothing;
- the detail's rows of the tap budget: Awaken 4 from another type 2 taps (cell + button), Awaken 5 and Forge 1 when
  picked, Recall 2 (Shop + the row's button), Release 2 (button + confirm). Scrolling the body to a tag is a drag or
  the wheel, not a tap.

Other files pin the page too: `test/army_cap_ui_test.dart` (a full type: its cell's red "x5/5", its spawn bar card
refused with why, Release on the pick's detail in 2 taps, a Hero's type refused), `test/book_padding_test.dart` (the
grid and its pager inside the left page's writing; the detail and the foot's Release and its press area inside the
right page's),
`test/pusaka_tas_ui_test.dart` (a cell's Artifact badge in its top left corner), `test/tempa_hud_test.dart` (the
Forge "+3" in the detail's header, never on a cell), `test/tide_hud_test.dart` (Replace fallen at the foot's
bottom-left, narrower than the page, under the body, no separator),
`test/carve_ui_test.dart` (the detail's Artifact capsule "★2+3", scrolled into view), `test/coach_hud_test.dart` and
`test/foe_splash_test.dart` (a spawn bar card), `test/pause_test.dart` (a cell picked, then a spawn bar card),
`test/army_header_ui_test.dart` (decisions-log 256, 260, 283: the header at 1266×713 and 915×412, the title at the
left edge, the counter at the right one on the title's line, no +Room (the spawn bar's), nothing to buy in the foot;
a tap on +Room buys what the foot's did, its price, 2 more room, the zone a column wider, telemetry's `bought` with no type, the
next 10 dearer; its tooltip; greyed short of gold and at the most, a tap says why and nothing moves; an army over its
cap goes red and a +Room takes it in; `roomTip`'s zone and gold lines; 256's removed ladder: a save that still holds
its key loads as if it had none, and town.json has none of it, while a file that does loads the rest as before).

No test reads the drawn text's size: the shots are where the 10-px floor is looked at.

The shots: `test/probe_troops_shots.dart` (not in the suite), at 1266×713, 412×860 and 915×412 on the w89 fixture:
the rows, the Templar (its Pusaka asleep), the priest (a Hero), the soldier (none alive), the axeman's Release armed,
no gold; the priests at their cap (5/5) picked and Replace fallen showing; the guide's pictures I2 and I3.
`test/probe_troops_detail_shots.dart` (not in the suite) shoots the detail at the same three windows on the w89
fixture with a fallen Hero added: the priest (a Hero, Forge, Fallen Heroes), the wizard (an Artifact, Awaken 5), the
axeman (Forge +6), the Templar (its Void Eye, its bag button), the archer (what Awaken 3 needs), the axeman's Release armed,
mid-wave (the book opened by hand on the desk); the priests at their cap, the soldier fresh. It taps
through the list's getters only, so the same file shoots main and the branch (`OUT`). Both predate the grid (decisions-log
218): there they reach the detail's Buy and Release only for the pick, and at 915×412 only the grid's first page.
`test/probe_army_rework2_shots.dart` (not in the suite) shoots the grid and the detail at 412×860, 915×412, 1164×777,
1266×713 and 777×1164 on the w89 fixture (the Templar with its Void Eye and relics, the axeman's Release armed,
mid-wave; in landscape the book opened by hand), the priests at their cap, and a soldier before Awaken 1 (six needs,
the Shop open, the Bag holding some); it turns the grid's pages (`armyPager`).
`test/probe_release_foot_shots.dart` (not in the suite; decisions-log 288) shoots the detail's foot at 1600×947,
1266×713, 1164×777 and 915×412: on four types, the knight's Release, armed,
with one soldier to replace, and that armed; on the w89 fixture the Templars' Release, armed, with seven Templars to
replace (a longer price), and that armed. Each line it prints gives the right page, the body and its content, Release,
the confirm and its words, Replace fallen and its label, for a crop. It reads only getters the foot had before 288, so
the same file shoots the page before and after (`OUT`).

## The spawn bar and Auto (decisions-log 283, 287)

`test/spawn_bar_test.dart` (ui-hud.md "Spawn bar"), one `TdGame` per widget test, its helpers from
troops_detail_test.dart; the owner's 1600×947 with that file's three windows (1266×713, 1164×777, 915×412), and `small`, 568×320 (an iPhone
SE's), a landscape window too narrow for the nine slots, where the hotbar pages.
`allCards` turns the strip's pages from the first to the last (`spawnBarFirst`, `spawnBarPerPage`) and gives every slot
where it was drawn; `into` turns to one type's slot; `clearOfArrows` checks no slot overlaps an arrow button
(`spawnBarArrows`); `block` is the hotbar (`spawnBarPanel`), +Room's and Auto Buy's press areas.
- at 1600×947, 1266×713, 1164×777 and 915×412, between waves (the book open) and in a wave: every type, in
  `troopTypes` order, all nine at once and no arrows, square, one size, one row, a gap (`5 · hotbarPx`) apart; the
  hotbar centred on the screen, the gap round its slots, its bottom on the log button's line; +Room (`capacityButton`)
  left of it and Auto Buy (`autoReplaceButton`) right of it, as far off it each side, level with the slots, a slot's
  height and 44 px at least; all three on the step (`spawnBarArea`), whose top is over the hotbar's, its bottom the
  screen's, symmetric about the middle, its slopes inside the screen; the slots 56 px at 1600×947 and 44 at least, the
  price and the count 11 px at least (13 and 12 at 1600×947); the open book's bottom two slots' height over the hotbar's bottom (283's), over the step's top
  at the most; none in a Town or on the welcome screen;
- a tap on a slot buys one (the gold, the count, the troop on the field), the Army page's pick kept, nothing said; mid-wave
  too, unpaused (1266×713, 915×412, 568×320);
- too poor ('poor', `spawnCardLook`): a tap does nothing and says nothing; refused ('refused': the type at its cap, the
  army full): a tap says why;
- paging at 568×320: the arrows show (slots hide), two slots a page at least, each arrow level with the slots and
  44 px wide at least, a gap off the hotbar's ends, at the strip's (`spawnBarList`) ends, +Room and Auto Buy outside
  them, the hotbar centred, no slot over them; each page whole slots of one size in order on the hotbar; the arrow on
  to the last page (the last slots), greyed there, back, greyed at the start; the wheel over the strip a page a notch
  (one more within the Bag's gap does nothing), none over +Room; a swipe left a page on, right a page back (before any
  mouse: a drag carries the mouse's spot, and a tooltip there would make the next tap no tap); through all of it the
  hotbar, its buttons, the strip, the arrows and the army stay as they were (no arrow tap buys); every slot that buys,
  on every page, buys;
- +Room's words on one line ("+Room  <price>", "Room: max" at the most, `spawnBarRoomWords`) inside its button
  (`spawnBarRoomFace`); its button and press area and Auto Buy's 44 px each way at least, at the four windows and
  568×320 (two lines on an upright phone until decisions-log 289);
- +Room on the step, not in the book, buys 2 more room for its price and greyed says why; Auto Buy off at first, a tap
  on and a tap off, mid-wave too (unpaused); their tooltips (`tooltipShown`: "Auto Buy" with its two lines, `roomTip`);
- +Room greyed says why on a tap for each reason (decisions-log 292), at 1600×947 and 915×412: while it buys, two taps
  buy (no message, the next 10 dearer) and its tooltip under the mouse starts "+Room: more army room (40 gold)."; too
  poor (a gold short of 60) a tap says "Not enough gold (need 60)." and nothing moves, its tooltip ending on that line;
  at the most (36) "Room: max" on it, a tap says "Army room is at its most (36)." and nothing moves, its tooltip those
  two lines; a long press (touch) says why on its tap down and shows the same tooltip.
- the slots, the hotbar, its arrows, +Room and Auto Buy clear of the top band's pieces, the log button, the open book and
  the log's open panel, at the four windows in both states; the step clear of them all but the log button
  (its slope's foot runs under it); the field covered (`coveredAt`) under a slot, the hotbar's rim, the step's top and
  its slope; a tap on a slot pins no plate, a drag from it moves no troop;
- a slot's tooltip (`spawnTip`): its name, "Buy one: 50 gold.", "On the field: 1/10."; at its cap the why; poor
  "Not enough gold.";
- the guide's P1 at 1266×713, 568×320, 915×412, 1164×777 and 1600×947: none buyable, the first slot; only the first
  type buyable with the strip on its last page, the back arrow at 568×320 (all nine on one page elsewhere: the first
  slot); the gold for some, the first slot on the page that buys, its box clear of it on screen; a tap there buys and
  P2 follows.

`test/bar_clear_test.dart` (decisions-log 287; the owner: "supaya battle jangan sampai di belakang dari action bar"):
nothing of the battle behind the bar. A long wave of the w89 save (`lowestDrawn`: wave 90 fought headless 60 s, the view
341 wide) gives the lowest field y anything is drawn at: a unit's shadow 6 under its y, a shot 8 (the wizard's magic, lib/wizard_fx.dart), a loot icon 5, a
relic's glint 8, a material's pile 5; it is `stepLip` (134) at the most, and the lowest lane (y `fieldH − 2`) is
reached. At the test windows (1600×947, 1266×713, 1164×777, 915×412, 1280×720, 1920×1080) and every landscape window
from 900×400 to 2600×1500 (step 100), between waves and in a wave: the bar (`spawnBarArea`) to the screen's bottom,
centred, its slopes whole at the test windows; the lowest drawn over its top, `toScreen(stepLip)` on its top; the first
lane's bars (`barReach` 24 over a unit at y 8) under the top band (`waveMeter`); every slot on the step. A knight in the
lowest lane, pinned with a tap, has its plate (`pinnedPlate`) over the bar at the four windows. The field's scale (from
`toScreen`) is the screen's height over the scene's at 1600×947, 1266×713, 1164×777 and 1280×720, a little less at
915×412 (1.916 px a world unit; the view 477.6 wide, 426.4 before), `viewW` the screen's width over it, the HUD's scale
(`hudScale`) 3 or 2 by the screen as before (never the zoom's); a Town (no bar) keeps the scale and the framing.

The probes (not in the suite; a mirror as `dir`, never the real save): `test/probe_bar_clear.dart` (`SIZES`, `FRAMES`,
default the four windows and 1500 frames, about a minute) fights the w89 save's waves on the Board at x2 with 3 more
game steps a frame (about 200 s of the game a size: wave 90 with its boss and mini boss and wave 91), pins the lowest
unit every 2 s, and checks each step every unit (a dying one too), shot, loot pile and the pinned plate against the
bar's top where they overlap it across: a `CLEAR` line a size (the lowest of each, the boss, the most loot and foes),
failing on any overlap. `test/probe_hotbar_shots.dart` (`SIZES`, `OUT`) shoots at each size the w89 save mid-wave with
two troops and a foe pushed to the lowest lane, a fresh game between waves with the book open, the same with Auto Buy
on and the pointer on a slot, and with the battle log open: a `HOT` line a shot (the bar's pieces, the step's top, the
lowest shadow, the book, the log's panel, the scale, the view's width). `test/probe_step_seam_shots.dart` (`SIZES`, `OUT`) shoots at
each size the w89 save two seconds into its wave, the book shut: a `SEAM` line a shot (the step's box and top, the
floor's lip, the floor's pixels on the screen, the hotbar, +Room's and Auto Buy's press areas, the log's button); crop
both slopes at 3x (nearest) to look at the joins.

`test/auto_replace_test.dart` (pure Dart, lib/auto_replace.dart; the falls by `recall_test.dart`'s `idle` and
`strike`, an orc at the field's far end keeping the wave on): off by default, nothing bought back and no save key; on, a
knight then a soldier fall with no gold: the soldier's price buys neither (the head waits, holding the rest), the
knight's buys the knight onto a cell of the zone, then the soldier's the soldier, mid-wave; refused for no room the
fallen is skipped with no error sound, and room again buys nothing; a Hero is never bought back; at the win the knight
Auto bought back is not on `toReplace`, the soldier is; between waves the soldier waits for the gold, then comes back to
its old spot; an entry left on the list goes into the queue at the next wave's start and is bought mid-wave once the
gold covers it; the save's key only while on, read back, off without it; `autoTip` ("Auto Buy").

`test/auto_names_test.dart` (decisions-log 290): the two Autos named apart, "Auto Wave" (`Words.autoWave`, the top band's)
and "Auto Buy" (`Words.autoBuy`, the spawn bar's); no string literal in lib/ (`lib_literals.dart`) names "Auto" alone.
One booted TdGame per window, 1600×947, 1266×713, 1164×777 and 915×412: Auto Wave on with its countdown running (a full
army), the top band's Auto button as wide as "Auto Wave" with the button's margins at its font, x2, it and the meter
apart, nothing of the top band (`pieces` and the hold line) over another; held (one troop of six), the hold line
"Army 1/6 · Auto Wave waits" (its width that text's), on the screen and under the toggle; the spawn bar's Auto Buy face
(its press area less k each way, on the step right of the hotbar since decisions-log 287) as wide as "Auto Buy", all
nine slots beside it; a tap on Auto Buy turns
`autoReplace` on and off, one on Auto Wave turns it off (settings.json too) and on; a wave and a Town's "Leave town 5"
with no overlap, nothing moved. The shots: `test/probe_auto_names_shots.dart` (not in the suite; `SIZES`, `OUT`): at each
window the countdown, the hold line, Auto Buy on, a wave and a Town, a line of the top band's and the bar's rects per
shot with any overlap, then the landscape band's width at k 2, 3 and 4 (as test/probe_hud_merge_width.dart).

The shots: `test/probe_spawn_bar_shots.dart` (not in the suite; `SIZES`, default 1600×947 and 412×860), into the folder
`OUT` names (its default outside the repo): between waves, between waves scrolled to the end with Auto Buy on, and in a
wave, each with a `BAR` line of the bar's rects (the step, slots, strip, hotbar, +Room, Auto Buy, arrows, the log
button, the book) and the lowest feet and shadows of the last lane.

## The in-game text (decisions-log 190, ui-hud.md "In-game text")

`test/english_text_test.dart` (no game) guards the rule that every string a player reads is English. It reads every
string literal of lib/'s Dart files (`dartLiterals` in `test/lib_literals.dart`, the finder guide_text_test uses too:
comments skipped, interpolations left out) and marks one Indonesian when it holds a word of its list, matched whole
(no letter, digit or underscore either side): the words of the strings not yet English (dan, tidak, gelombang,
pasukan, emas, …) and the old names (Prajurit, Pedang, Tengkorak, Raksasa, …), in any case; Tas, Bos, Pasang, Pusaka,
Elit, Langka, Epik, Legenda and Main only as written (in lower case they are code: the save key "pusaka",
"main.dart"). Left out: the ids that are never shown (the save and telemetry values "pusaka", "tempa", "serpihan", the
store's 'tab:bangkit' and 'bangkit:<type>' keys, the strip's 'batal' key, the welcome screen's `_welcomeAt[...]`
keys), `part`/`import` paths, the legal texts (lib/licences.dart and the Licenses page's credit line) and
lib/names.dart (personal names). It is a ratchet: `pending` maps each file to the Indonesian literals it still holds;
a file over its count fails ("a new Indonesian string", listing them), one under it fails too ("lower its pending
count to that"), and a file with none must leave the map. A change that turns a file's strings English lowers its
count in the same commit; two branches that both touch a file: whoever merges second sets the count the test reports.
Since decisions-log 200 the map is empty: every lib/ string is English but the ids and the legal texts, and any
Indonesian word in a new string fails. A second test checks the finder on samples.

The shots: `test/probe_english_shots.dart` (not in the suite; queue it with `--dart-define=OUT=<folder>`, one size with
`--plain-name "english shots 412"`). From the w86 fixture at 1266×713 (ratio 2) and 412×860 (ratio 3): welcome, the
save's catch-up chest, the HUD, the Army page with every type's build name (each picked in turn), a Pusaka badge's and
an item cell's tooltips, a Release chip armed, the Tas page, a Gudang Pusaka picked and its Lebur picker,
Settings, the Licenses page, How to Play, the drop popup over a troop (an item, a relic), the victory popup with its
fallen by name and by type, a high elite's skill (its splash, then its banner) and a mini boss's banner, wave 90's
fight with both boss bars, the boss's and a high elite's pinned plates, the open log, game over; at 915×412 the
guide's intro, two cards and How to Play. Then at all three sizes (`b2`, the menus, the HUD and the wave meter): the
welcome screen (at 915×412; the other two have it above), the game over's name panel, its OK with no name typed, the
game-over screen and its scoreboard (ten entries written to the test's own scores.json: a 12-character name, a
seven-digit score, three-digit waves; "Loading..." first), a new game's start button counting down with Auto held
and the minimap open, the army full at the cap (the cap's warning, then the wave meter's tooltip with its last line),
the fixture's notes unseen (the limits' notes in one window, then the meter's tooltip over the cap), a stalled
wave's message, the win that opens the Shop as the tide comes, a Hero's splash and a recalled one's, Settings with
both spotlights on and off, a package's licences, the intro's seven pages, the pointer P2 and the cards K1 and K4.
Then at all three sizes (`b3`, the Shop; `--dart-define=ONLY=b3` shoots it alone): the Awaken 4-5 rows with a type at
Awaken 5 and Forge +6 and one at Awaken 4, the Forge type's stars tooltip, its row's Forge card, the Awaken 4 row's
card, the Lancer's stars (Impale's lines, the longest skill text), an item's card with Buy and Sell, a worn small
relic's greyed Sell said, the rows' greyed reasons mid-wave, the Fallen Heroes tab (a recall, a swap with the army
full, a type with none alive, a type with only Heroes) and a row's card, none fallen, and How to Play's
"Items & Awaken" and "Shop" topics.
Every text the shots read (tooltips, messages, the drop popup's lines, build
names, plates, boss bars, banners) goes to `OUT/text-<size>.txt`, so two runs diff line by line. The probe marks
every guide card and pointer as seen and closes the save's notes before each shot, so no message covers one. Run it
before a text change and after, and look at the pairs one by one.

The fit dump goes with it, in a `git archive` mirror only (never on a branch): add `final debugDrawn = <String>[];` at
the end of lib/main.dart and, as the first line of `Board._text`, `debugDrawn.add('$t|${size.toStringAsFixed(2)}|$bold|
${at.dx.toStringAsFixed(1)},${at.dy.toStringAsFixed(1)}|${anchor.x},${anchor.y}|w${_textWidth(t, size, bold:
bold).toStringAsFixed(2)}');` (one line), and swap the probe's no-op `fitHook` for one that clears `debugDrawn`, pumps
a frame and appends its lines, led by the size and the shot's name, to `OUT/fit-<size>.txt`. Every text drawn, its
size, place and width, per shot: pair two dumps by shot and place (the same anchor point within 3 px), not by text
(the text is what changed) and not by order (a fight shot draws a different number of texts on each run), and list
each slot whose size fell (a shrink to fit, `_fit`/`_fitFirst` taking a shorter fallback) and each box off the screen.
The victory popup draws in a moved canvas (its points are from the popup's centre), so its boxes only look off.

## test/hud_test.dart: the HUD as drawn

Boots one `TdGame` the same way (`boot(tester)`: 1266×713, past the welcome screen) per widget test, and
presses what the board draws (`tester.tapAt`). Plain `test()`s there check the HUD's layout math.

- A button's look (#54, `buttonLook`): lit under the mouse, pushed in while a press on it is held (over
  the hover; touch has only the press), a press held elsewhere leaves it lit, disabled shows neither.
- A press over time (#54, `pressLook`): pushed in while held and `pressMin` at least (a quick click too),
  then the hover look for `pressBack`, then nothing; touch goes pressed, hover, normal.
- The pointer's press (#72, `cursorFrame`): the arrow, press frame 1, then 2 while held (both at least),
  back through 1 when it comes up; a quick click shows 1, 2, 1, then the arrow.
- The auto start (#68, `AutoStart`): no countdown before a win; after one it counts 5 s down, stands still
  while held, starts the wave once at 0, and stops when cancelled or turned off; turning it on starts
  none. Settings.json keeps it (a temp file), off when missing or broken.
- The hearts (#65, `hearts`, `heartsLost`): `startLives` 6 are 3 full hearts, an odd count's last heart is a
  half, lost lives are empty hearts, more than `startLives` adds hearts; which hearts pop as lives go.
- A unit's bar (#52, `unitBar`): without MP the pack's 12×6 capsule, all its inside HP; with MP one box
  as wide and ending as low, taller than a lone bar but shorter than the old two capsules, its inside
  65% HP on top and 35% MP right under it.

- The Start/Pause toggle (#49, decisions-log 220, ui-hud.md): Start at the top centre before the first wave
  (`Board.startButton` = `toggleButton`, `pauseButton` `Rect.zero`), and a press on it starts the wave on the way
  down, before the pointer comes up (#54); in the wave it is Pause (`pauseButton` = `toggleButton`, 44×44 at
  1266×713, its middle where Start's was): a press within the guard after the wave began pauses nothing, a later one
  pauses; paused it resumes, in the same place; between waves paused (a fresh `Game`) it resumes, then is Start
  again. A press meant for Start that comes as the wave starts (Auto's countdown ending under a finger, a press on
  what was drawn as Start) pauses nothing. draft_hud_test.dart: with the Boss Chest's popup open, a tap on the
  toggle under it starts no wave. town_hud_test.dart: in a Town it is "Leave town".
- Auto (#68): left of the wave meter, x2 left of it, 2·k apart; a press turns it on and settings.json keeps it; no
  countdown before the first win; it stays during a wave; a win (the queue emptied, the monsters gone)
  starts the countdown on the button (Start wider for it, its middle where it was), pausing holds it, and at 0 the
  wave starts; Start pressed early ends
  it, and turning Auto off stops one. Its
  rule after a win and at game over, `Game.canStartWave`, is in game_test.dart.
  - It counts real seconds (x2 doesn't hurry it), and another game coming in (a new one, a loaded save)
    ends it.
  - It waits while a new Hero's splash is due or shows, from the win until the splash closes, then counts
    down. (A game over on a Board opens the name overlay, which the test's bare `GameWidget` doesn't
    register, so Auto at game over is tested on `Game.canStartWave` only.)
- "Send game data" (#64): on the Settings page (`showSettings`, `sendButton`), off at first; a
  press turns it on and settings.json keeps it, another off; the install id was made once a game was played.
- The HUD together (#74; `bossScene`: a wave with the mini boss in the top row and the boss, both bars up):
  at 1266×713 and 915×412 a pinned plate on the mini boss (or, where the bars hang over it, the boss;
  `pinnedPlate`) stays under the boss bars (`bossBars`) and off the log's button and Auto;
  the off-view marker keeps clear of an open panel: beside the long troop list (still level
  with the troops); a new game drops the last one's bursts, cast names and gold
  pops (`fieldFx`); a book opened mid-wave (`bookButton`, `bookArea`) puts the boss bars
  compact at the left, clear of it and under the open troop list (the minimap stays under the meter),
  and they come back when it shuts. The busy scenes' shots are the probes' (`probe_hudqa.dart`,
  `probe_minimap.dart` in the mirror).
- The top band (#80, decisions-log 220) at both sizes: the troop counter, then the hearts and the gold on one
  panel (`heartsGoldPanel`, its parts `livesBar` and `goldPanel` as tall as it) and in a wave the book
  button (`bookButton`) at the left; x2 (`speedButton`), Auto and the wave meter (`waveMeter`) at the right, 2·k apart;
  the toggle in the middle, in the band; nothing of these overlaps, and none of it moves, between waves, in a wave
  and paused; x2 works from there. The battle log's
  button at the bottom right, its panel opening upward, right-aligned, its top under the meter, the map and
  the boss bars. A press on the meter drops the minimap
  (`miniMap`, `miniMapOpen`) under it, as wide (also while the book is open between waves, and it
  stays there as the wave starts and the book shuts), the boss bars under it; a press on the map does nothing else; another folds it; settings.json
  keeps which. `boot` loads the game's font (the rows are laid out by its widths) and folds the map.
- `miniMapSpan` and `battleLine` (pure): the back line to the view's right edge, a tile more each side,
  widened to every living unit (the dead left out); the battle line halfway between the foremost troop
  and the nearest monster, none without either.
- The off-view marker (#56): none with every troop in sight; with the free healer out of sight left of
  the view (the game paused, so the view stays put), on the field's left edge, level with it; gone once
  the view is back. Who counts, `Game.leftOfView`, is in game_test.dart.

## test/letterbox_test.dart: landscape only (decisions-log 289)

The game is landscape only (ui-hud.md "Layouts"; lib/letterbox.dart, main.dart's `landscapeOnly` and `gameRoot`).

- The lock: AndroidManifest.xml's one activity (`.MainActivity`) has `android:screenOrientation="sensorLandscape"`,
  the file's only `screenOrientation`, and web/manifest.json's `orientation` is `landscape`. `landscapeOnly` asks
  `SystemChrome.setPreferredOrientations` for the two landscape orientations on Android and iOS and asks nothing on
  the other platforms (a mock `SystemChannels.platform` handler). lib/main.dart's `main()` awaits it before
  `runApp(gameRoot(TdGame()))` and before the system bars hide (`_fullScreenOnPhone`).
- The fit (`letterboxFit`, pure): a view as wide as tall or wider (1266×713, 1600×947, 1164×777, 915×412, 800×800,
  568×320) is the game's own, unscaled. A taller one gets a rect as wide as the view, 1.5 as wide as tall
  (`letterboxAspect`), centred, its edges on whole physical px; the game is laid out 915 px wide at the least
  (`letterboxMinWidth`) and scaled down into it: 412×860 a 412×275 rect at y 293, laid out about 915×610 at 412/915;
  390×844 and 700×900 alike; 1000×1400 at its own width, unscaled. The insets as the game sees them
  (`letterboxInsets`): as they are without a letterbox; in one, only where they reach into its rect, in its laid-out px.
- At 412×860, 390×844 and 700×900, one `TdGame` per widget test booted the way the app does (`bootRoot`: through
  `gameRoot`): the `GameWidget` in the letterbox's rect, the board laid out at 915 px wide; the bars black and crisp
  (every pixel of their rows at every 3rd column, the game's own first and last rows drawn) on the welcome screen,
  with the book open, with the mouse in a bar, and in a wave with the battle log open; the HUD's pieces inside the
  laid-out size and none over another, between waves and in a wave; a tap on x2, a hover over Auto Buy (its tooltip)
  and a tap on the log button mapped through the letterbox; taps on the bars above and below change nothing, and the
  mouse in a bar shows no tooltip.
- At 700×900, a Town in the letterbox, its bars black: a finger's 60-px drag and the wheel's 40 px on its street pan it
  by what they moved in the game's px (over the scale, less the Town's 8 px slop for the drag).
- A window resized across the line and back (1266×713 to 700×900, 800×800, 800×801, 412×860, 915×412 and 1266×713
  again): the letterbox comes and goes, the board laid out at each size as `letterboxFit` says, the HUD fitting it,
  the same board and game going on (not started again); back at the desk every piece where it was.

## test/town_test.dart, test/town_hud_test.dart: the Towns (decisions-log 216)

The Towns' schedule and state (loot-items-relics.md "Towns"), on seeded games (every game has the Towns since
decisions-log 321; test/real_rules.dart's `noTowns`, rules whose every roll misses, is a game no Town comes to); a wave
is won at once (`winWave`: one slime, gone; a due Town gone through first); `_Dice` gives the Town dice's draws in
turn.

- town_test.dart: the shipped `assets/config/town.json` equals the defaults, every number written out, and a `Game()`
  reads them; `TownRules.parse` keeps a default for another version, not JSON, a number out of range or of the wrong
  kind, a cap under the start; `patch`. The roll: blocked until wave 5 (no draw, the chance stays 0.20), then +0.05 a
  miss; with a 0.5 step the chance stops at the cap, and a hit marks slot n+2 and goes back to 0.20 (`townMarked`'s
  fields, `rolls` 4). Every roll hitting: the first Town before wave 7, then 12, 17, 22, 27, 32. 60 seeds of random
  dice: never before wave 7, never two within 5 waves. In and out (only a due Town, once; no wave while due or in it;
  the last Town and the cleared mark; the events and the battle log's lines). `townPolicy` 'leave'. The save (`town`
  with `in`; a passed mark and a stray `in` dropped; no key: a Town counted before its own wave). The dice (the same
  seeds the same Towns; only the Town dice move them). The boss schedule untouched: 30 waves' queues with a Town every
  5 waves and with none (`noTowns`) the same (a mini boss every 3rd, the boss every 5th), and the same Boss Chests. A
  seeded 8-wave run fought for real the same through a Town (a probe going through it before wave 7) and with none,
  wave by wave; in both no relic or item drops and materials do (decisions-log 221, 246). Telemetry: the three events
  passed on, each won wave's `town` (blocked, the hit, marked), `telemetryVersion` 9 or later. The chip's tooltip
  words (the Smithy, the Tavern, the Shop once open).
- town_hud_test.dart (booted `TdGame`s): the chip at 1266×713 and 915×412 (right-aligned under the meter, clear of the
  open book and its tabs, its words, its tooltip under the mouse, kept mid-wave, gone in the Town); a due Town gone into
  after the cheer and saved, "Leave town" leaving it (saved) and starting no wave, then Start; Auto's countdown in the
  Town ("Leave town 2", "1") leaving it and the wave starting once the fade back is over; a save made in the Town
  reopening in it.
- Probes: `test/probe_town_shots.dart` (the chip between waves and mid-wave, its tooltip, the Town's "Leave town" and
  with Auto "Leave town 5", the battle log's lines, at 1266×713, 915×412 and 412×860) and `test/probe_town_slots.dart`
  (the board's Towns, on with no define, over waves 1-30 for 10 seeds, the gaps, seed 7's waves in the design's
  notation, the mini boss / boss marks checked).

## test/town_materials_test.dart, test/town_materials_ui_test.dart: the Towns' materials (decisions-log 221)

The materials (loot-items-relics.md "Town and Smithy: materials"; ui-hud.md "The Bag's Materials"). `_Dice` gives the
material dice's draws in turn and counts them; `kill` fights a list of (type, rank, raised) monsters to death with a
knight in a wave kept on by a slime far off, `winNow` wins it.

- town_materials_test.dart: the shipped town.json is the defaults (`toJson` equals the file's JSON both ways), nothing
  in it `skipped`, the design's numbers spot-checked; the 30 (names in `Words.materialNames`, Common / Rare / Trophy in
  the enum's order, each type two distinct parts, the Necromancer no Common, every non-Trophy one type's part, the three
  Trophies the always-drops, every one in some recipe, the 11 recipes' names). The file's odd input: unknown names left
  out where they stand and listed in `skipped` in order, numbers out of range or of the wrong kind at their defaults,
  version 1 all defaults, a nested `patch`. `dropOf` for every type and rank on a fake die: one draw (none for an
  always-drop or a type without that part), a roll just under the chance drops, at it none; the boss ranks' counts and
  Trophies, the Necromancer's Lich Orb. 3,000 seeded kills a type and rank (normal, elite, high elite) within 0.035 of
  the chance. Kills fought for real: the tally and the pops, the material draws (none for an always-drop or a raised
  monster), the win into `materials` and `lastMaterials` (no item or relic into the bag), the next win adding; no
  relic or item on dice that always drop. The save (by name, only when any, an unknown name or a 0 skipped).
  Telemetry: a won wave's `materials` and its start's.
- town_materials_ui_test.dart (booted `TdGame`s): at 1266×713 the 30 on one page, at 915×412 on three (the
  pager; 12 a page on the shorter landscape book, decisions-log 283), in the game's order, a cell reached on its page
  (`bagTo`, test/bag_pages.dart); the counts' capsules; a pick's facing page (its name and count, what drops it, the grey
  use line, the one Smithy row with its relics and "Only in a Town", no Sell); `matSource` for a Rare part and the
  Trophies. A game holding none still has the Materials chip. The "VICTORY!" line (`Board.victoryLoot`: the wave's
  materials in the enum's order; no item or relic drops, decisions-log 321). A dropped material's hop onto the field
  (`Board.fieldFx`) and its pile (`Board.matLoot`).
- Probe: `test/probe_town_materials_shots.dart` (the Bag's Materials page with Wolf Fang picked, 915×412's second page,
  a material's tooltip, a high elite's and a mini boss's materials hopping onto the field, the "VICTORY!" line; at
  1266×713, 915×412 and 412×860, into `OUT`).

## test/mat_loot_test.dart: the materials lying on the field (decisions-log 262)

ui-hud.md "The Bag's Materials". Booted `TdGame`s; `towns()` is a game with the Towns on, a knight and dice that always
drop (`_Zero`), `killAll` fights monsters to death in a wave kept on by a slime far off (the game ticked by itself, the
board draining the drops on its next frames), `lying` sums the piles lying by kind.

- At 1266×713 and 915×412: two orc mini bosses on one spot and a slime away from them; the drops hop (`fieldFx`), then
  lie with the wave's tally exactly, the two Trophies in one pile of 2, one pile a kind; nothing in the bag before the
  win, still lying a second on. At the win the bag gets the tally at once (`materials`, `lastMaterials`, the tally
  emptied), every pile flies, and 1.4 s on none is left.
- A lost game's piles lie on under the game-over screen; another game (Play again, a save loaded) has none, its own
  drops lie and only they; a tally dropped without a win takes its piles off.
- Stacking: drops 11 units apart in one pile, 60 apart in two, another kind never joins; 120 more over the field
  leave at most 40 piles, their counts the tally.
- Probe: `test/probe_mat_loot_shots.dart`: the owner's w89 save with the Towns and the forge on fights wave 90 for `MID`
  (40) s with no frame drawn; at 1266×713 and 412×860 the materials lying, the win 0.45 s and 0.75 s on (flying to the
  Bag) and 1.6 s on (the "VICTORY!" line), into `OUT`; then at 1266×713 the frame's recorded render cost with the piles
  and without them (the median of 40 each) and how many piles it drew.

## test/forge_drops_test.dart: the forge's drops (decisions-log 246)

The forge's drops (loot-items-relics.md "The forge: drops"), on `forgeGame`s (the forge's rules, every game's since
decisions-log 321). `_Dice` and `kill`/`winNow` as in
town_materials_test.dart; `_Counted` records every `loot` draw in order; `saveText` is a save's text without the troops'
names (a `bareGame`'s name dice aren't seeded).

- The shipped `forgeDrops` are the design's table, `shop.matMarkup` 2.5 and `matRise` 0; `toJson`'s `drops` holds
  `necromancerSlot` and `forge` alone (the pre-forge `drops.normal..boss` are gone, decisions-log 296), and an old file's
  `drops.normal` is noted in `skipped` and changes nothing. The file's odd input:
  an entry's bad number keeps the shipped entry's, one past them drops nothing (`chance` 0), a non-list rank keeps its
  default, an unknown rank or material noted in `skipped`; a patch puts a list in.
- `dropOf` for every type and rank on a fake die, just under and at each chance: one draw per part with
  a chance, the counts, the Trophies, the Necromancer's Lich Orb and no Common; 4,000 seeded kills a type and rank
  within 0.03 of each part's rate.
- Kills fought for real on dice that always drop: no item or relic reaches the bag, the `loot` draws pinned call by
  call in the order the monsters fell (each kill's item roll and kind and its relic roll and kind, drawn as before the
  forge and thrown away; a raised one's item only), and the materials are the forge's.
- `matsSeen`: first-drop order, each kind once, none from a raised monster; a material put in the bag another way, or
  sold, never changes it. The save: written in order once any was seen, loaded in order (an unknown name skipped),
  seeded from the materials held in `Mat` order when missing.
  `shopMatPrice` for the 30 (the design's list), unchanged by buys at `matRise` 0, a patched rise and markup rounded up
  to 5 without float creep. `matSource` and `matFrom`.
- Probe: `test/probe_forge_drops.dart` (`SEEDS` 4, `WAVES` 20): a board game a seed going
  through each Town, every queue's monster killed at 1 HP by four knights so every wave is won; it checks that no item
  drops and every kind held was seen, and prints the materials held by wave beside the rules' expectation for those
  queues (the forge's table) and the design model's numbers.

## test/forge_relics_test.dart: the forge's nine relics and the combos (decisions-log 250)

Pure Dart (loot-items-relics.md "The forge's nine"). `plain()` is a `bareGame` with no skills of any kind; `holder` places a troop (a Hero) holding relics, standing until told; `dummy` is a
monster without defence (its HP lost is the blow); `strikeOnce` / `land` / `blow` / `x` measure one strike, as a
multiple of the attacker's damage.
- The nine are `forgeRelics`, their numbers town.json's, the cap 3.0.
- Each alone: Chill every 3rd hit landing (0.7, a mini boss or the boss 0.85), its own count, 1.5 s, a shot where it
  lands, never a smite, a patch; Shark Tooth ×1.25 on a bleeding monster (through defence too); Grit under 50% HP, not
  at it; Ambush on slowed, pinned, stunned; Weak Spot's mark (another troop's shot ×1.12, 3 s, a boss 1.06, Hunter's
  Mark stronger stays); Hot Streak's stacks (1, 3, a fourth kill still 3, gone after 4 s); Avalanche 0, 4, 5, 7 near and
  past 2 tiles; Afterglow after a Hero's Cleave (3 hits ×1.5, the 4th plain); Reaper ends a monster left under 15% (not
  at it; its counter), never a mini boss or the boss (×1.5 under the line).
- The hidden pairings on and off: with the partner, without it, cleared (`TownRules(combos: Combos(secrets: {}))`:
  a patch merges into the defaults).
- The cap: Giant Slayer with the beat on a boss 1.5, 1.5, 3.0; under Relic Altar (3.75) cut to 3.0; Afterglow
  with the beat 3.0, with Grit too cut to 3.0; Titan Bane outside it; a patched cap.
- The combos C1-C9 per hit (the design's figures where they are per hit; C2's, C6's and C7's design figures are
  averages, so the per-hit factors and C7's hits to kill are pinned instead).
- The cards: none names another relic or an Artifact, nor "combo", "pair" or "secret"; the report's rows (a real won
  wave: Chill and Shark Tooth) and `relicCounter`'s words; the telemetry's `relics` and `relicPairs` (a Hero with two
  of the nine and an Artifact bound: its pair key, 300 dealt).
- The save writes none of their state: a Hero holding two of the nine round-trips as before.

test/probe_forge_f4_shots.dart (a probe, queued on a mirror) writes the nine cards in the Bag, the Army detail's relic
line and its tooltip, and the battle log open on a report's rows, at 1266×713 and 412×860.

## test/forge_data_test.dart: the forge's data (decisions-log 245)

The forge's data (loot-items-relics.md "The forge: data"), on the shipped town.json and the version-2 fixtures
(test/fixtures/town-v2.json, the last version-2 file; test/fixtures/save-20261004-1919-w8-v2.json, a real version-2
save at wave 8 with a Town due). `edited(change)` reads the shipped file with a change made to its JSON; `board()`
is a board game (the forge's, with the Towns).

- `Item`: each kind (`ItemSlot`) once at each grade, counted from the enum; the first `droppedItemKinds` are the seven
  monsters drop, grade I, the Awaken recipes' kinds. The nine relics appended, never dropped, never Artifacts, out of
  `smallRelics`. Names one each and English; each new relic's card one line, naming no other relic and no combo; every
  new item's card and its line on every type; the new kinds' and the Cap's and Ring's texts.
- Icons: every item, small relic and material (the two stones too) a 32×32 file of its own bytes, in `LOOT`. The
  stones: after the 30, named, `crafted` in the enum and the file, in no drop rule, "Made at the Smithy.".
- town.json: the shipped file version 3, read whole (every item, the 20 relics, the combos, Awaken and Enhance; no
  `recipes` block), nothing skipped; the version-2 file reads to the same rules but the Shop's opening (its 15; 1 since
  decisions-log 253), its pre-forge `drops.normal..boss` noted in `skipped` (decisions-log 296); today's recipes, numbers and the 30 materials unchanged. Every recipe's materials and items exist: the Awaken kinds Commons only and no item, gold 20 / 60
  / 250 by grade, only the Cap and the Ring taking their grade below, the Mighty relics a grade-II item with the forge;
  every dropped material in some recipe; the stones' recipes; the forge's relic gold 70% rounded to 50. The combos'
  secrets valid, a bad one left out and noted; Awaken's share and Enhance's step lists, a bad one kept at its default
  and noted, a whole new set of steps read; an edited item, forge change and cap; another version all defaults.
- Every game the forge's (decisions-log 321): a board game and a plain `Game()` alike, every item, the 20 relics and the
  stones in the Bag, the forge's recipes and gold, the relics' tiers.
- The save: the version-2 fixture loads forward with nothing discarded and writes back as version 3; the launch keeps
  and offers it; an unknown item or relic name skipped, the forge's names loaded; a stone never in `matsSeen`.

## test/forge_awaken_test.dart, test/forge_army_detail_test.dart: items crafted, Awaken by grade (decisions-log 249)

The forge's items and Awaken by grade (loot-items-relics.md "The forge: items crafted, Awaken by grade"; ui-hud.md
"Army"), on `forge()` and `forgeInTown()` games (every game has the forge since decisions-log 321).

- `gradeCount` (0.667 as two thirds, at least 1); each type's `kindRecipe` and grade sets against the design's table (9
  types, items I / II / III), and a patched `share`.
- Levels: for every type, sets 1 to L give Awaken L; one item of the grade-L set short, the level below; a grade-L set
  without the one below, or another grade in its place, counts for nothing; a Cap and a Ring never count.
- Giving (the knight, Awaken 0 to 3): which grades are open, `awakenFirst` / `maxed` / `notInRecipe`, the grade-III
  caps at two thirds, 31 items at the top, `typesFor`'s row. The Cap and the Ring: cap 1 to 4 on every type, the swap
  of the lowest grade back to the Bag (`swapOut`, `useItem`, `priceWith`), a lower or equal grade refused.
- Crafting every item from exactly its recipe (gold by grade, the Cap's and Ring's grade below), the refusals' order,
  no limit, `canMake` / `whyNotMake` outside a Town, `smithyItems` / `craftableItems`, no craft in `matsSeen`; `craftItemNeed`, `awakenShort` and `bagLevel` by grade sets.
- Stats per grade: the knight's 3 + 3 + 2 swords ×7.137, shields, potions, heals, boots, gloves, the Cap's `taken`, the
  Ring's MP regen, a tuned file number used. A Cap's cut on a werebear's blow. The
  `ItemCrafted` event: its log line, the telemetry event, the wave record.
- `awakenRecipe`, the old item recipe the grade sets build on (`forgeAwakenKinds` adds each type's own kind; an old
  save's level, `oldItemLevel`, reads it); the Awaken by it went with the Towns-off rules (decisions-log 321).
- The Army detail (booted `TdGame`s at 1266×713 and 915×412): "Awaken 2 needs (grade II):", each grade-II row's
  have/need and where from ("In Bag: 1", "Smithy: can make 3", "Smithy: needs Wolf Claw", "Done"), "Next" with "Awaken 3
  needs grade III.", a stat cell's "4/6"; Awaken 0 and 2; a save's knight at Awaken 1 by the old rule loaded by grade:
  "Awaken 1 (kept from old items)" first ("(kept)" where it doesn't fit), then the grade-II needs alone.
- Probes: `test/probe_forge_f3_shots.dart` (the Army detail by grade at Awaken 0, 1 and 2, three scrolls each, at
  1266×713 and 412×860, into `OUT`), `test/probe_forge_f3_awaken.dart` (`SEED_FROM`,
  `SEEDS` 3, `MAX_WAVE` 40, `SHARE` 0.6: an auto-player with the design model's army that crafts and gives the next
  Awaken's items at each Town within a craft budget, printing the Awaken levels by wave beside the model's).

## test/forge_cutover_test.dart: the forge on by default, and the saves from before it (decisions-log 272)

Pure Dart, on the old fixtures and a copy of the owner's last save before the cut-over
(test/fixtures/save-20261008-0438-w13-preforge.json: wave 13, in a Town, no items, 236 materials, two Artifacts).
`load(j)` loads a save as the app does (a board game: the Towns, so the forge). What the rules from before the forge
read for the w89 and w8 saves (each type's level, Bangkit and Tempa that count, and its stats) is pinned in `_before`,
recorded on the Towns-off rules before they went (decisions-log 321).

- The forge in every game, a plain `Game()` too (decisions-log 321): the Smithy's 14 a grade, its first Town's save
  `town` and `awakenKept`. `telemetryVersion` and `eventVersion` 10 or later (11 the Tavern's).
- The w89 save (items by the old rule, Bangkit 5 and Tempa): each type's level, Bangkit, Tempa and stats `_before`'s;
  `awakenKept` each type's old-rule level (`oldItemLevel`); without it every type would read Awaken 0; the game always
  writes `awakenKept`.
- A kept level counts on: the archer at 2 needs the grade-III set alone (`awakenShort`, `awakenProgress`), its old
  bows past the grade-I cap stay and count (`maxed`), grade III open; the set given, Awaken 3; saved and loaded, the
  saved `awakenKept` stands.
- A new forge game writes `awakenKept: {}` and never fills it: a knight holding the old recipe in grade I without its
  Amulet is Awaken 1 by the old rule, 0 by grade, and 0 again after a save and a load; the same items in a save
  without the key keep Awaken 1.
- The owner's save: wave, gold, lives, score, troops, the Town, the materials, `matsSeen` seeded from them, the
  Artifacts; a grade-I item crafted at the Smithy for its gold. The version-2 save at wave 8: `_before`'s levels and
  stats, its gold and items, no relic.

The tests that pinned the Towns' game from before the forge (its own drop table, Shop, Smithy relics page and Craft)
play the forge since its off switch went (decisions-log 296): town_materials_test.dart and town_materials_ui_test.dart
the forge's table, town_shop_test.dart and town_shop_ui_test.dart the forge's shelf (their Buy forge_shop_test.dart's),
town_smithy_ui_test.dart the Smithy's Relics tab, town_craft_test.dart the forge's relic gold. The tests that built an Awaken level from the old recipe on a board game build it
by the game's own rule (`awakenNeeds`): tide_test.dart, town_shadow_test.dart, town_switch_test.dart.

- Probe: `test/probe_forge_cutover.dart` (no define; `SEED` 5, `MID` 12, `OUT`): a fresh board game (the forge with
  the Towns) wins waves 1 to 6 (the real queues killed at 1 HP by four knights): no item ever drops, materials do; the Town
  before wave 7 crafts a grade-I item the knights take; then at 1266×713 and 412×860 the Smithy's Items tab in that
  Town (smithy-<size>) and wave 7 fought `MID` s by a small army, the materials lying (battle-<size>).

## test/forge_kinds_test.dart: the forge's five new item kinds (decisions-log 251)

The Amulet, Prayer Beads, Torch, Spear and Prism (loot-items-relics.md "The forge: the new kinds' effects"). `board()` is
a board game, `field()` a bare game with no skills;
`holding(g, type, items)` sets `upgrades[type]` directly (the caps are the Smithy's) and reads `statsOf`, and `whole(s)`
compares every number of two stats.

- The numbers by grade from town.json `items`, the spear's `reachMost` and the prism's `splashMost` (1.5 each; patched,
  and refused under 1), `itemK` the file's (the first seven's numbers the constants from before the forge).
- Each kind alone at each grade changes only its own stat; stacking by count (the amulets rounded at each one); the
  Amulet at Awaken 1 (the awakening's HP times the amulet's, MP regen the awakening's) and on a troop in the field (its
  refit keeps the wound); the beads only on a healer, whatever the order with a potion and a staff, and a priest's heal
  and holy smite on a skeleton bigger; the torch's blow on a skeleton and an armored skeleton times its factor, on an orc
  not, and a skeleton's blow on a torch holder as before; the spear on the lancer, never a shooter or a healer, the bow's
  clamp and the aura reading the raised cap, the full set stopping at 33 and 1.5 × `meleeMaxRange` (with Hawk Feather ★3
  and a Hero's aura too); the prism only on the Axeman and the Wizard, stopping at 1.5 × their splash (patched: 2).
- `Stats.upgraded` without a number leaves the five alone (their fields at their defaults).

## test/tavern_test.dart: the Tavern's boosts (decisions-log 266)

The rules of the Tavern (loot-items-relics.md "Towns: the Tavern"). `tavern()` is a seeded game with the Towns (and
so the Tavern) on (its dice seed + 800) and gold to spare, `inTown(g, wave)` puts it in the Town after
that wave, `only(rarity)` patches the odds so every roll is of one rarity (no first Feast, no pity unless given),
`fight(g, foes)` plays the next wave out (through a due Town; by default one slime that leaks at once).

- town.json's `tavern` block is the defaults, read whole (11 kinds, their rarities, the Feast's numbers, `most`); a number
  out of range keeps its default and an unknown name is noted in `skipped`; a version-2 file reads the defaults.
- The price table at waves 6, 7, 12, 20, 30, 50, 70 and 86 (the Feast 100 at the first Towns), a kind's own `k`, and the
  rerolls doubling in a visit (150, 300, 600, 1,250 at wave 20).
- The roll: three different kinds, the same for the same seed; the first Tavern's Feast; a kind running never offered;
  a Legendary only from wave 30 (before it two Epics, then a Rare); the Champion's Plate's type the one alive, none with no
  troop; the pity's fourth visit and its reset; the odds of 10,000 first slots at wave 40.
- Buying every offer while the gold lasts, the refusals in order (Sold, the gold, no such offer, outside a Town, the game
  over), "Sold out" for a reroll; a reroll keeps the bought slot and the kinds different.
- The stats: the Feast on every type (a priest's heal too), on troops in the field at once and on one bought later; over
  the Wall oath and under the Hero aura, HP gained at the buy; `most` (the Plate, Banquet and Feast on a knight's damage
  1.8, the taken floor 0.6), the Plate only on its type, attack speed dividing the pause, Mage's Brew's MP regen; a
  werebear's blow on a soldier ×0.85.
- The countdown (two waves, then gone, the troops refit and HP capped, `BoostEnded` and its log line), Lucky Toast's
  kill gold ×1.3, Watchman's Brew's one leak a wave (`BoostSaved`).
- The save in a Town and out of it, and a load dropping an unknown kind, a typeless Plate and a spent boost; the
  telemetry (`boostBought`, `tavernRerolled`, `townLeft.tavern`, the wave's `gold.tavernSpent`, `boostSaved`,
  `start.boosts`); the log lines and the effect words; the probe policies 'top' and 'all'.

## test/tavern_ui_test.dart: the Tavern's pages (decisions-log 267)

The Town book's Tavern (ui-hud.md "The Tavern"), booted TdGames at 1266x713, 1164x777 and 915x412, each game
with the Towns (and so the Tavern) on gone into the Town after wave 20 (`tavernGame`, `enterTown`: the
offers rolled, the first Town's Feast first). `fits` holds every row, Effect row and part inside its page, the rows
apart and Reroll under them, each reached by its page's scroll where the page scrolls (the shorter landscape book,
decisions-log 283; `scrolledTo`, test/page_scroll.dart); `seen` scrolls a part into view before a tap.

- The tabs (Smithy, Tavern, Shop, Army, Bag, Settings), the Tavern tab's dot until its page shows; the rows in their slots
  with their kinds and prices, the first not bought picked; "New offers every Town", Reroll's price, "None yet.".
- The Feast's page: its name and rarity, "Every troop: +20% damage, 15% less damage taken.", the grey line, its Effect
  rows (Damage +20%, Damage taken -15%, Troops All troops, Waves 2) and "Buy (800 gold)"; a Buy by a tap ("Feast! 2
  waves", the gold, the boost running 2 waves, "Sold", the Active slot), the white Buy's "Sold" again.
- Another row picked; the gold short: the prices red, "Not enough gold" on Buy and on Reroll by a tap; a Reroll with gold
  (the Feast stays, the rows follow the offers, the next price higher, no dot); leaving the Town shuts the page.
- After wave 30 with every roll a Legendary: the King's Banquet's six rows fit with Buy (scrolled to where it must); the Champion's Plate's page
  ("Knights: +40% damage, +15% attack speed." with its type's plural) and the Watchman's Brew's (no Troops row).
- At 1266x713 the Tavern's sign opens its page after the bare scene shut the book (the wheel bringing the Tavern into
  view, decisions-log 271).

The shots: `test/probe_tavern_shots.dart` (not part of the suite; queue `["test", "test/probe_tavern_shots.dart"]`, `OUT`
the folder) maps the ui_icons.png cells the page uses and fx_upgrade.png's frames, then at those three and 412x860
shoots the rows coming in, the first look, a buy, the gold short, a reroll, and after wave 30 the bursts, the Banquet
and the Plate.

## test/tavern_hud_test.dart: the Tavern in battle (decisions-log 268)

The boosts on the HUD (ui-hud.md "The Tavern in battle"), booted TdGames at 1266x713, 1164x777 and 915x412;
`fieldGame` is a board game after wave 20 with the Towns on (the Tavern as shipped), between waves, a Town marked
after wave 22 or none.

- The Feast and a Knights' Champion's Plate running: two chips under the Town chip, on the screen, under the meter,
  right-aligned with it, in the order bought; their tooltips ("Feast: 2 waves left", "+20% damage", "15% less damage
  taken", "All troops"; "Champion's Plate: 1 wave left", …, "Knights"); the battle log's panel under them where they
  share its side.
- Without a Town marked one chip right under the meter; none without a boost; six in rows the meter's width, apart, the
  last right-aligned.
- Back from a Town (1266x713): no burst without a buy; with the Feast bought every living troop bursts once with the
  upgrade burst, where it stands.

The shots: `test/probe_tavern_hud_shots.dart` (not part of the suite) at those three and 412x860: the first Town's
card K23, the Tavern tab's dot, the bursts, the battle log's Tavern line, the chips under the Town chip, a chip's
tooltip, six chips.

## test/town_scene_test.dart: the Town scene (decisions-log 224)

The scene drawn in a Town (ui-hud.md "Town"; lib/town_scene.dart), on booted `TdGame`s with the Towns on per game (dark
on the board), at 1266×713, 915×412 and the owner's tablet's 1164×777.

- `houseCells`, `houseProps` and `houseSize` equal the design's house.py output for its three houses
  (`test/fixtures/town_house_cells.json`: n 0 one storey, n 0 two storeys, n 1 two storeys); every house the scene can
  draw (n −1/0/1, one or two storeys) uses only town_house.png's cells, none twice on one place, all inside its grid,
  its props none past its right end (n −1 two storeys: the table, the stacked crates, the cauldron).
- At each size: the Town gone into after the cheer with the fade (the field dimming for 0.35 s, then the Town coming up,
  then no dim); the whole screen covered for the field's units; the book on the Smithy with the Town's tabs (Smithy, Tavern,
  Shop, Army, Bag, Settings); k (2; 1 at 915×412, where 582 world px don't fit across at 2); the scene's room (the whole
  screen); the three buildings (the Smithy and the Shop n −1 one storey; the Tavern n 1, two storeys, decisions-log
  271), each drawn cell by cell in houseCells' order on the 16·k grid, its porch's bottom on the lane, the street
  strip's top edge (`townScene['street']`, decisions-log 279); every piece present at every size (the Town 1010 world px
  wide), the campfire's art ending at the tent's right, 4 world px before the stump; the Smithy (decisions-log 253,
  271): no piece's art on its ground floor between its walls (the smith's spot); on its left the stump, the log pile and
  the sawmill, each one's art after the last's, the logs 3 world px before the sawmill, the sawmill's art 2 clear of the
  house; on its right the furnace's art against its right wall and the ore's 2 past it, the yard's pine 2 past the ore;
  none under its sign; its place the stump to the ore with the house; the yard's two side by side, the line right of the
  pine, so the pine's first tier shows whole (decisions-log 253); the anchors on the lane (the street's line, 10 world
  px under the grass strip's top), left to right, each at its thing (the tent, the furnace, the Tavern's door, the fruit
  table). A tap on the bare scene shuts the book, the room 0 to 1010 − the screen's width / k, the Smithy in the middle
  of the screen when the view isn't at an end (the places side by side, the rest 2 world px from the Town's left end,
  the Shop at its right end, the signs under the wave meter over their roofs, the Smithy's on the screen); its sawmill,
  furnace and ore each open its page; the wheel to the right end and the Shop's sign opens the Shop, the Shop's place
  left of the book; shut again it stays at the right end, and the Tavern there opens its page (decisions-log 268), its
  place left of the book; shut, the wheel back to the left end, and the Smithy's sign opens the Smithy (its house and
  furnace together centred left of the book). The Shop's sign at wave 5 opens its page and a tap on the bare scene shuts
  the book; with town.json's `shop.from` patched to 15 the tab says when it opens, and with the shipped file again it
  opens its page, the Shop's place in view. Leave: the Town dims first, then the field, its book on the Army without the
  Shop tab.
- Auto: "Leave town 5"; a press on a tab stops it (the Town stays; left by hand, no wave by itself); with no press it
  leaves at 0 and the wave starts once the fade back is over.
- No guide card or pointer in a Town but its own; a save made in it reopens in it at once (no fade) on the Smithy; a
  game out of a Town shows none, and the field's book has no Shop tab.
- Probe: `test/probe_town_scene_shots.dart` (queue `["test", "test/probe_town_scene_shots.dart"]`): shots at those
  three and 412×860 into the folder `OUT` names: the fade in at ~0.2 s and ~0.5 s, the book on the Smithy, the
  Bag, Settings and the Shop, the book shut (landscape), the fade out and the field after it.

## test/town_scroll_test.dart: the Town's sideways pan (decisions-log 264)

The player's pan of the Town (ui-hud.md "Town", "The player's pan"; lib/town_scene.dart), on booted `TdGame`s with the
Towns on per game, at the three sizes of town_scene_test.dart (its `intoTown`, `settle`, `bare`, `bounds` and `sizes`).
Drags go through `tester.startGesture` with a 30-px first move (past Flutter's slop and the Town's 8 px) and carry no
time, so they never fling.

- At each size, the book open on the Smithy where a Town opens: the room (`Board.townRoom`) from min(0, the page's own
  pan) to past it; dragged all the way right the view's left edge at the room's least (at 0 the tent 2·k from the
  screen's left), all the way left at its most with the Shop's cells' right at what shows' right (the book's left);
  a 208-px drag moving it 200 screen px and holding, the Smithy's smith moving with its house; a
  drag from another building opening nothing;
  a tap on a building after the pan opening that building's page, its place then centred. The bare scene shuts
  the book, the room 0 to 1010 − the screen's width / k (decisions-log 271), dragged to its right end the Shop's cells'
  right at the screen's (no tap: the book stays shut) and back to its left end the tent 2·k in; the Smithy's sign back to
  where it opened. Panned to
  the right end, Leave, the next Town in the same game: the Smithy where a Town opens.
- At the desk: no pan from the book's page, the wave meter (the HUD's band), the troop counter, the log's button, the
  log's open panel or a message; a tab acts on the press, a building's tap on the release; a mouse's drag of 108 px
  moving 100, a mouse press on the Smithy (its house panned in from the Town's left end, past its wood corner) moving
  12 px panning (no tap) and 5 px tapping; the wheel's down 60 px (+30
  world px, on its way at 2 frames) and sideways −80 px (−40), nothing over the book; a trackpad's pan/zoom of −60 px
  (+30); a fling (`flingFrom`, 1500 px/s) gliding on past the drag; the Bag's staff dragged out over the scene (in hand,
  nothing given, no pan) and its Give-to-troops list scrolled by a drag (no pan).
- The field between waves: a finger's and a mouse's drag, the wheel both ways and a trackpad's swipe on its ground leave
  `camX` where it was.
- Probe: `test/probe_town_scroll_shots.dart` (queue `["test", "test/probe_town_scroll_shots.dart"]`; `OUT` sets the
  folder, `SIZES` some sizes): at 1266×713, 1164×777, 915×412 and 412×860 the Town as it opens (open-<size>) and with
  the book on the Smithy panned to the room's least, middle and most (pan-left/-mid/-right-<size>); in landscape the
  book shut (shut-<size>, the Smithy in the middle) and, the street emptied so the pieces show, panned to the Town's
  left end, middle and right end (shut-left/-mid/-right). It prints the room and where the places were drawn.

## test/town_army_test.dart: the Army in a Town (decisions-log 301)

The Town book's Army tab and the tent's tap (ui-hud.md "Town", "Bookmarks"; lib/town_scene.dart), on booted `TdGame`s
with the Towns and the forge on (wishlist_ui_test's `forgeGame`: in the Town after wave 20, a soldier, a knight, an archer
and a priest), at 1600×947, 1266×713, 1164×777 and 915×412; town_scene_test's `bare`, `wheel`, `intoTown` and `settle`.

- At each size: a game that comes in in a Town opens on the Smithy, its tabs Smithy, Tavern, Shop, Army, Bag, Settings.
  `tabsFit`, on the Smithy, on the Army and on the field after Leave, sampled 8 times across the book's bob: a press
  area (`Board.bookTabTaps`) for every shut tab and none for the open one, each `bookTabTapMin` (44 px) each way at
  least, round its tab, on the screen, none over another, none over the pages' writing; the tabs and their press areas
  clear of every piece of the HUD (`hud`: the counter, the hearts, the gold, the book button, the toggle, x2, Auto, the
  wave meter, the log, the Town chip, the map, the chest chip, the boost chips; each 4 px round).
- The Army's tab: the four types' cells on the grid, the tent's middle in the middle of the strip left of the book; the
  archer's detail (its stats) and its Release in two taps (the troops home, the refund paid); with someone to replace,
  no "Replace fallen" in a Town; the knight's wish tapped turns to the Smithy on the Steel Sword.
- The tent: the book shut, the wheel to the Town's left end, a tap on the tent opens the book on the Army, the tent in
  view; from the Bag, shut, its campfire does too. The other places as before: the bare scene shuts the book (the tent
  in view), the Smithy's sign opens the Smithy, the Tavern's building the Tavern, the Shop's sign the Shop. Left on the
  Army, the field's book stays on it (Army, Bag, Settings) and shows Replace fallen.
- A Town gone into from the field's Army (`intoTown`) opens on the Smithy as before; its Army tab then stays open.
- Probe: `test/probe_town_army_shots.dart` (queue `["test", "test/probe_town_army_shots.dart"]`; `OUT` sets the folder,
  `SIZES` some sizes): at the four sizes the Town's book on the Smithy (army-smithy), the Army tab with the archer
  (army-tab), the book shut at the Town's left end (army-shut), the tent tapped (army-tent), the field after Leave on the
  Army (army-field), and the Town's tab strip zoomed 3x with each press area outlined (army-tabs). It prints the tabs,
  their press areas, the pages and the HUD's pieces.

## test/relics_test.dart: the Smithy's seven small relics (decisions-log 227)

Pure Dart (loot-items-relics.md "The Smithy's seven"). `plain()` is a `bareGame` with no skills of any kind and no
monster skills; `holder` places a troop holding relics; `strikeOnce` lets a troop strike once (`land` waits for its
shot); `lost` measures a blow.
- The enum appended after the last Artifact (the save keys), `smallRelics`, `droppedRelics` the four, none in
  `storeGoods`; the owner's names (none a Hero skill's title); the tiers from the recipes (a patch moves one);
  `relicsInPlay` all eleven and the forge's nine.
- Sweep: the nearest other monster within its reach (exactly at it: hit; just past: not) takes its share through its
  defence; only the nearest, no chain; a patched share and reach; a shot sweeps where it lands, a smite doesn't.
- Venom: the bleed's tick, count and source, all of it landing over its secs; a stronger bleed stays, a weaker one is
  replaced; a patch; a shot poisons when it lands, a smite never.
- Mana Siphon: +2 MP over the same scene without it for a blow, a shot, a smite and a heal; never past its max.
- Spirit Ward: the shield at a wave's start, none on a troop without it, gone at the wave's end, capped at `wardMax`.
- Iron Will: the heal under its line through the funnel (`HealSrc.lastStand`, in a wave), once a wave, again the next;
  nothing at the line exactly; never on a killing blow; with Holy Charm on a Hero ×1.4.
- Giant Slayer: ×1.5 on every rank's blow but normal / elite / high elite (×1), a patch; a smite on a mini boss more;
  a Hero's Cleave (a skill) the same with it or without.
- Holy Charm: a healer's heal ×1.4 (the funnel hears the heal asked); its own regen and the Grail's save as they are.
- A Hero holding Sweep and Venom: one blow does both; a second of a kind and a third refused; a troop holds one.
- The save: the bag's and the troops' relics by their keys, a Hero's two.
- The words: each effect line from the rules (a patch shows), the tooltip's tier and "Best on".
- Elsewhere: hit_source_test's list has Sweep's `Hit.relic`; heal_funnel_test's table has `HealSrc.lastStand`;
  item_text_test checks each small relic's tooltip (font, 412-px width); guide_page_test the guide's relic page (all
  eleven and the forge's nine); town_materials_test the recipes' names.
- Probe: `test/probe_relics_shots.dart` (the seven picked in the Bag with their tier and "Best on", the troops' relic
  rows with a Hero holding two, the Army detail of the soldiers, a relic cell's and an Army relic's tooltip; at
  1266×713 and 412×860, into `OUT`, the relics put in the bag by hand).

## test/town_shop_test.dart, test/town_shop_ui_test.dart: the Town's Shop (decisions-log 230 and 269)

The Shop only in a Town, on the Bag's code (loot-items-relics.md "The store"; ui-hud.md "The Town's Shop"), the Towns
turned on per game (dark on the board).

- town_shop_test.dart (rules, `bareGame`): outside a Town every kind's buy and sell (an item, a small relic, a material,
  a Vault Artifact) refused `StoreRefusal.town` first, nothing changing and the error sound each time, mid-wave too; in
  a Town today's refusals and prices, the shelf the materials seen alone (an item and a small relic `notSold`), a
  material bought, a sale, the Vault Artifact sold; open in a Town from wave 1 won (shipped `shop.from` 1), `locked` at
  wave 0 and, with `shop.from` patched to 15, at wave 14. A Recall outside a Town. The materials at town.json's price
  (Wolf Claw 25, Skull 60), one and all, the last leaving no entry, `StoreSold`'s `material` (an item's record without
  it). Sell's grid (`shopSellLoot`), bound Artifacts and oaths left out (Buy's sections: forge_shop_test.dart).
- town_shop_ui_test.dart (one booted `TdGame` per widget test): the Shop page at 1266×713, 1164×777 and 915×412
  (the strip Buy | Sell opening on Buy, no Bag chips; Buy forge_shop_ui_test.dart's; Sell's grid in the Bag's order; a
  material through the
  Sell Basket, All and Sell all, its cell gone; a Vault Artifact through the basket; every part on the right page and
  the screen); the field's Bag (no Sell row for each kind, the grey line under the rows; no Shop tab) at 1266×713 and
  915×412; the Army detail's Recall at the three sizes (newest first, two and "+1 more"), a recall and its splash, a
  refusal said on a tap, a full army's swap with its refund; the gold's dot on the Army tab (the w89 save).
- test/shop_tabs_ui_test.dart (decisions-log 269; booted `TdGame`s in a Town, the forge on): at the three sizes the
  strip, Buy's Materials alone (the shelf at its prices; Items and Relics, none on the forge's shelf, not drawn:
  decisions-log 280), every heading's words
  at the board's leftmost slot (`shopSections` against `bagSlots`), a material bought; Sell's grid equal to
  `shopSellLoot` (each enhanced stack its own cell; a bound Artifact, an oath and a worn relic absent); the Sell Basket:
  a tap adds a cell at 1 and selects its line ("1/2", "1 x 1500 = 1500"), +, All and - (never past what is held; at 1
  the line leaves), a line tap selecting it, a basket of an item stack, an enhanced stack, a relic, an Artifact and a
  material ("9 pieces", the total equal to each piece's price summed) sold in one press with its message; every part on
  the right page and the screen; no divider and the lines as far under the price row as over Sell (decisions-log 305);
  Sell across the page with "Sell" and the total on it, the coin between, and no total beside it, greyed "Sell" alone
  with the basket empty (306). The basket's math without a page (`shopBasketGold` equal to selling one by one, every
  kind in the Bag priced, `shopBasketFit`). The basket's life at 1266×713 (the selected cell let go, a tab switch keeps
  it, a stack that shrinks clamps it, leaving the Shop or another game empties it; the Town's Bag keeps its five chips).
  The Smithy's "Wishlist" heading's words at its first line's head at 1266×713 and 915×412 (`smithyAt('wishHead')`; its
  "Materials" heading went with its materials, decisions-log 302).
- Probe: `test/probe_shop_tabs_shots.dart` (queue `["test", "test/probe_shop_tabs_shots.dart"]`; `OUT` sets the folder,
  `SIZES` some sizes only): at 1266×713, 1164×777, 915×412, 412×860 and 1600×947, the forge on, Buy, a Buy pick,
  Sell empty, a five-stack basket with a line selected, a longer basket scrolled to its selected line, the empty shelf's
  Buy ("Nothing to buy here yet.") and the Artifact shelf open (Artifacts then Materials); at 1266×713 and 412×860
  the Smithy's Items tab. It prints each heading's left edge and the leftmost
  slot. It replaces `probe_forge_shop_shots.dart` (the forge's Shop before decisions-log 269).
- `test/probe_town_shop_shots.dart` (the forge-off Shop's shots) went with the forge-off build (decisions-log 296).
- town_shop_open_test.dart (the owner's "shop juga harusnya di buka ketika masuk kota, dan di battle ground tabnya di
  hilangkan", decisions-log 253): the shipped town.json's `shop.from` 1 and nothing skipped; a first Town at wave 1
  won deals (the Shop open, a sale) while Recall still says "Opens after wave 15" (`armyBuysOpen` false);
  `shopJustOpened` never with the shipped file, at wave 10 alone with `shop.from` patched to 10. At 1266×713 and
  915×412 (booted `TdGame`): the field's tabs Army, Bag, Settings at waves 0, 1, 14, 15 and 40; the first Town's
  Smithy, Tavern, Shop, Army, Bag, Settings, its Shop tab opening the page.

## test/town_life_test.dart: the Town's troops (decisions-log 229)

The troops' life in a Town (ui-hud.md "Town", "The troops' life"; lib/town_life.dart). `ScriptDice` is a visual dice of
the test's own (its queued draws, then a fallback); the life only asks it `nextDouble`.

- `TownLife` alone on a desk-like street (633 world px, the anchors fixed): `pick` gives each errand its `townWeights`
  share and `drawFor` the draw in its middle; each errand (guard, Shop, Smithy, Tavern, rest, stroll) from a scripted
  roll: on its way facing its goal, walking at 0.6 of the type's speed ×2, there at its place facing its way, staying the
  dice's span (a Tavern guest's two doorway spells on top); up on a floor on arriving at the Tavern or the rest
  (decisions-log 274), not inside yet; the Tavern: `townDoorway` s in its doorway, then inside (`inTavern`, the window's
  bubble the first 1.8 s of every 5), its last `townDoorway` s back in the doorway (still up, no bubble), then out at
  its door; the next roll (a stroll, down on the street). The caps and slots: two guards (the left end facing left, the right end facing right), four browsers either
  side of the stall facing it, four resting round the fire; one more strolls. A talk: the roller takes the nearest one
  strolling (one guarding is never taken), they meet halfway or before the Tavern and face each other, the lines' bubbles
  over the roller, then the other, then the roller, never both, each line's icon on the dice; then both roll again; a
  talk with no one strolling is a stroll. A browser's grey thought (the coins, the hammer) from 0.6 to 2.4 s. The troops
  are the living army: a Hero in; the fallen, the gone and a monster out; one falling mid-talk leaves and its mate rolls
  again; one joining is placed at the next step; an unchanged army redoes nothing. Twin games play the same wave after
  one's troops lived 120 s in a Town (the game's dice untouched).
- On booted TdGames with the Towns on at 1266×713, 1164×777 and 915×412: the troops drawn are the living army (a
  Hero in, a fallen troop out), on the lane (0 to 4k under it, on whole px; one on a floor, `TownFolk.up`, its
  `TownFolk.floor`·k over it), walking within the street; still while
  paused; a tap on a troop standing over a building opens that building's page (from the shut book, the wheel
  bringing the building into view, decisions-log 271: the Tavern its page, the Smithy the Smithy); after Leave no life
  runs. At 1266×713 on a scripted dice: a talk's bubbles (ui_all.png's 20×24 at k, over the speaker's head, its tail at
  the head; the roller's, then the other's) and the Tavern window's while one is inside (not drawn), its tail on the
  window.
- Probe: `test/probe_town_life_shots.dart` (queue `["test", "test/probe_town_life_shots.dart"]`, `--dart-define=SIZES=`
  for some sizes): shots into `OUT` at those three and 412×860 with 6 and 30 troops after 8 s, someone at each anchor (a
  phone: on the Smithy, the Tavern and the Shop), at 1266×713 the talk 3× close up (each one's line) and 8 frames 0.5 s
  apart; and the Town's cost a frame (update and render into a picture, 600 frames) at 1164×777 with 30 troops and with
  none.

## test/town_shadow_test.dart: no ground shadow in the Town (decisions-log 270)

The Town's troops draw no shadow (ui-hud.md "The troops' life"; lib/town_life.dart); the field's keep theirs. A canvas
that notes only the images drawn and their paints (`_Drawn`, as in backdrop_test) takes the booted Board's `render`.

- In a Town at 1266×713 with a Soldier and a Lancer plain, a Knight awakened 1, a Priest 2 and an Archer 3: 2 s of their
  errands, then one walking, one resting at the tent, two talking (a bubble up) and one inside the Tavern; their idle and
  walk strips are drawn, no `tiny_<type>_shadow.png` ever. Every troop type's idle and walk strip (the ones `TownFolk`
  names) has no shadow pixel (sprites_test.dart's `shadowPixels`).
- On the field (no Town, no guide card): the Soldier's shadow strip drawn once, plain at `unitShadowAlpha`; the Knight's
  and the Archer's in their level's colour (`awakenShadowPaint`'s filter, `awakenShadowAlpha` with its pulse).
- Probe: `test/probe_town_shadow_shots.dart` (`--dart-define=TAG=`, `SIZES=`, `OUT=`): nine troops at awakening 0 to 5
  resting in a row before the tent, the whole shot and their feet at 3×, at 1266×713, 1164×777, 915×412 and 412×860.

## test/town_switch_test.dart: the Towns switched on (decisions-log 237)

The board plays with the Towns, the save's format 2, the guide's Town cards and the switch-on's polish; booted `TdGame`s
(`launch` keeps the welcome screen, `boot` passes it) and pure Dart. It reuses town_hud_test's `townGame`,
town_scene_test's `intoTown` / `settle`, town_life_test's `ScriptDice` / `troop` and town_smithy_ui_test's
`smithyGame`.

- Every game plays with the Towns: the board's (no define since decisions-log 296) and a plain `Game()` (321) save
  their `town` from the start (`chanceStart`, `firstTownAfter`). A board game rolls Towns:
  seeds 1-3 over 30 waves won at once (`townPolicy` 'leave'), each with Towns, the first at slot 7 or later, 5 apart at
  least, the boss every 5th wave as without them.
- The save: `v` first, `Game.saveVersion` (3; `Game.saveLoadsFrom` 2); a file with no `v`, `v` 1 or `v` '2' is no
  save for `loadGame` and `savedWave`, and `launchSave` deletes it while settings.json, scores.json and telemetry.jsonl
  stay; a `v` 2 save loads and stays; a broken file is no save and stays. At the launch: the owner's pre-Towns w89 save as save.json gives
  a welcome with no "Continue" (`welcomeButtons`) and the file gone; a `v` 2 save in a due Town shows "Continue" at its
  wave and reopens in the Town.
- The guide: K23 due only in a Town and the only card there, no card while a Town is due; K24 once a material is held;
  K11, K14, K18, K23, K24 and the "Towns" topic's words; K23 opens over the first Town and,
  seen, never in the next; K24 after the first wave that drops a material.
- town.json's `shop.from`: 1 as shipped; patched to 10 it opens the Shop after wave 10 ("Opens after wave <from>"),
  and Awaken 4-5, Forge and Recall stay at wave 15 ("Opens after wave 15") whatever it is (`armyBuysOpen`, waves 0-20
  against `storeOpen`). The cap warning and the awakening tooltip send to the Army page.
- The Recall tag at 1266×713 and 915×412: every word starts with "Recall"; the swap's refund in `recallInfo`.
- A lancer's talk bubble (scripted dice): its bottom between the lance's tip (37 sprite px over its soles' line,
  decisions-log 292; 39 over the old row-59 anchor) and the helmet's top (29).
- (The Smithy's small material cells' 2-digit counts went with its materials, decisions-log 302; the Wishlist tab's
  22-px cells that kept the check went in decisions-log 303: its rows write their counts as words.)
- The Army detail's relic tooltip has the relic's name and no `tapLine`.
- Probe: `test/probe_town_t7_shots.dart` (queue `["test", "test/probe_town_t7_shots.dart"]`; `OUT`, default
  `<agents>/shots/town-T7/`): at 1266×713, 1164×777, 915×412 and 412×860 the welcome over a pre-Towns save,
  K23, K24, the Recall tag (and 3× close up), the Smithy's grid with 2-digit counts (4× close up), a lancer talking (3×
  close up) and 30 troops in a Town after 10 s.

The Towns-off pages (the field's Shop tab and its store, ascend and recall pages, the Bag's Sell) and the TOWNS define
went in decisions-log 296 (the deleted tests: "The Pusaka" above), and the Towns-off rules, `Game.towns` with them, in
321: no test plays a game without the Towns; one that must see no Town uses test/real_rules.dart's `noTowns`.

## test/town_art_test.dart: the Town scene's art (decisions-log 222)

The files `tool/import_town.py` writes and `lib/town_art.dart`'s names for them (assets.md "Packs → files"). Sizes,
grids and rects only, so it passes on the placeholders too (no `art` tag); that each cell holds the pack's own pixels
is `python3 tool/import_town.py --check` (it needs the pack, in the main checkout).

- Every file of `townImages` loads from the asset bundle (decoded); the layers and the castle are 1024×346, the smithy
  6×2 frames of 64, the campfire 5×8 of 32; every house cell and every prop lies inside its atlas.
- Every `assets/images/town_*` file `tool/asset_manifest.json` lists is one the game names: `townImages`, the smith's
  `townSmith` and the Towns' two icons (`town_mark.png`, `town_mug.png`), so no Town file stays in the build unused
  (decisions-log 294). It reads the manifest, not the folder, so a public checkout's stale placeholder can't fail it.
- The 64 house cells each on a 16 px slot of their own, 16×16 but the porch row's five 16×8; no two props overlap.
- `test/fixtures/town_house_cells.json`, the design's houses (n 0 one storey, n 0 and n 1 two storeys) cell by cell
  with their props: their width (14 + 2n) × 16, every cell and prop named in the atlases and inside the house, and the
  64 cells all used. The Town scene's own house rule is held to the same fixture.
- Probe: `test/probe_town_art_shots.dart` (a probe; queue `["test", "test/probe_town_art_shots.dart"]` with the
  worktree as `dir`; `OUT` sets the folder, default `<agents>/shots/town-T5/`) draws the fixture's three
  houses cell by cell from the atlas with their props, the smithy's 12 frames and the campfire's first loop, every prop
  by name with the tent, the ore and the pine, and a rough desk composite placed by eye, not the scene's layout.

## test/town_smith_art_test.dart: the Town's smith's strip (decisions-log 265)

The file `tool/import_smith.py` writes and `lib/town_smith_art.dart`'s names for it (assets.md "Packs → files"). Sizes,
frames and the loop only, so it passes on the placeholders too (no `art` tag); that every frame holds the packs' own
pixels is `python3 tool/import_smith.py --check` (it needs both packs, in the main checkout).

- `town_smith.png` loads from the bundle at `townSmithFrames` × `townSmithW` by `townSmithH`, every frame drawn; his
  feet (`townSmithFeet`) inside the frame, on its bottom row.
- The loop: every beat a frame of the strip with ms > 0, every frame played, the ms adding up to `townSmithLoopMs`,
  three strikes between the backswing (first) and the 800-ms pause (last).

## test/town_smith_test.dart: the Town's smith in the scene (decisions-log 265)

- `townSmithFrameAt` plays each beat for its ms and loops every `townSmithLoopMs`.
- At 1266×713, 915×412 and 1164×777 (town_scene_test.dart's `sizes`, its `intoTown`, `settle` and `bare`), in
  a Town: `townScene['smith']` is the frame at 1 world px a sprite px on whole screen px, his feet under the Smithy's
  sign (the house's middle) on its floor, `townStep`·k over `townLane` (the porch's top, decisions-log 274, 279), inside
  the house's walls (`wallL8a` to `blockBR`) and below its window; a tap on him (the book shut, after the Tavern opened
  its page; the wheel bringing each into view, the Town wider than the screen: decisions-log 271) opens the Smithy's
  page: no tap of his own.
- Out of a Town no Town shows, so no smith. town_scene_test.dart's "nothing on the Smithy's ground floor" loop skips
  'smith'.
- Probe: `test/probe_smith_shots.dart` (queue `["test", "test/probe_smith_shots.dart"]` with the worktree as `dir`;
  `OUT` sets the folder, by default one under `<agents>/shots/`; `SIZES` some sizes only) shoots the Town at
  1266×713, 1164×777, 915×412 and 412×860 with nobody on the street (`smith-town-<size>`), the Smithy's house and
  furnace 3x (`smith-house-<size>`) and every look of the smith seen over 3.2 s of his loop side by side
  (`smith-anim-<size>`).

## test/town_ground_test.dart: the Town's sky and ground (decisions-log 274, the ground since 279)

The clouds, the ground and the floors a step up (ui-hud.md "Town", "Inside is higher"; lib/town_scene.dart
`_townStreet`, `_townClouds`; lib/town_life.dart `TownFolk.up`), on booted `TdGame`s (town_hud_test.dart's `boot`,
town_scene_test.dart's `intoTown` and `settle`, town_life_test.dart's `ScriptDice`). A canvas that notes the images
drawn, from where and to where (`_Drawn`), takes the Board's `render` for the tiles and the order.

- `town_ground.png` (read from assets/, so the public repo's placeholder too): `townGroundW`×`townGroundH`, every pixel
  opaque, its last row one colour (stretched, it goes on as the earth).
- The ground at 1266×713, 1164×777, 915×412 and 1600×947 (`Board.townGround`), 'strip' and 'earth' across the
  view on whole px: the strip (`townScene['street']`) from the lane, `townGroundH`·k tall, on the screen; the earth
  from it to the view's bottom. The tiles:
  `town_ground.png` whole at k, side by side (each where the last ends) from left of the view to past its right, on the
  street's grid (`(left − ox) % 32k == 0`), and so again after a drag pans the street; its last row once, stretched over
  the earth. The buildings' bottoms and every piece's on the lane; the smith's `townStep`·k over it. The order: the
  strip before the houses and the tent, the street's troops after it; town_bg_1's last row (274's full green) never
  drawn (274's Tall Grass and Floor Tiles1 files are deleted, decisions-log 294). Every troop's feet: one on a floor
  its `floor`·k over the lane, the rest on the strip, 0 to 4k under its top edge.
- `TownLife` alone: the rest's slots 0-2 (in the tent's opening) step up on arriving, slot 3 (by the fire) stays down;
  each steps down as it sets out.
- The clouds at 1266×713 and 915×412 (`Board.townClouds`): copies side by side covering the view, 3072k × 130k, row 0
  (262 + 4)k over the lane; drawn after town_bg_5 and before town_bg_4; 60 frames (0.96 s) drift them left 0.96·6·k
  (±1.5); a drag on the street moves them 0.07 of it.
- Inside is higher, at 1266×713 on a scripted dice (two troops): one resting in the tent's opening stands
  `townTentStep`·k over the lane (its `floor`), higher than one on the street (0 to 4k under it), and is drawn before it; at the Tavern's door the
  guest stands up in the doorway, on the door's sill (`doorLow`'s bottom: `townStep` is the porch's 8), then is inside
  (not drawn), back in the doorway coming out, then down on the street.
- Every troop's soles on its line (decisions-log 292): `townFeet` is each troop type's feet's last row in its idle strip
  (read from assets/, `art` tag: the placeholders' bodies differ), in every frame, in the body's columns 44-55 (pixels of
  its shadow file's colours left out, the Soldier's baked-in one); and at 1600×947 and 1266×713, for every type, four of
  it on a scripted dice (their depths 0, 0, 0 and 4): one resting in the tent's opening, one a guest in the Tavern's
  doorway, two on the street; a canvas that notes each image with the translation and scale it was drawn under
  (`_Placed`) takes the Board's `render`, and each one's idle frame has its `townFeet` row's bottom edge on its line to the
  px: the tent's hem (`townTentStep`·k over the lane, inside the tent's rect), the sill (`doorLow`'s bottom, `townStep`·k
  over it), the lane, the lane + 4k; `Board.townFolk`'s `feet` that line too.
- Probe: `test/probe_room_tent_shots.dart` (queue `["test", "test/probe_room_tent_shots.dart"]`; `TAG`, `OUT`, `PART`
  room or tent): at 1600×947 and 1266×713 every troop type resting in the tent's opening with one of its own on the
  street at depth 0 beside the fire, 4× round the tent's foot and all nine on one sheet 2×, and a priest in the Tavern's
  doorway and the smith on his porch zoomed (the screen pans to the door where it is off it); at 1600×947 and 915×412
  the spawn bar's +Room greyed too poor and at the most with the message its tap says, and its tooltip while it buys,
  too poor and at the most. It prints the lane, the hem and each one's line.
- Probe: `test/probe_town_ground_shots.dart` (queue `["test", "test/probe_town_ground_shots.dart"]` with the worktree or
  a `git archive` mirror as `dir`; `TAG`, `OUT`, `SIZES`): at 1266×713, 1164×777, 915×412, 412×860 and 1600×947, the
  Town on the Smithy with two of each
  troop type (`town`), the book shut (`shut`, landscape), panned to the tent with one resting in its opening and one by
  the fire (`tent`), and to the Tavern with a guest at its door (`door`), just come out again (`out`) and set out on
  its next errand (`down`); it prints the
  lane, the street's rect, the buildings' bottoms and the two troops' feet. It reads only hooks a base before
  decisions-log 274 has too, so it makes the before shots as well.

## test/backdrop_test.dart: the battle's backdrop, the band, the clouds, the props line and the floor (decisions-log 228, 244, 263, 287)

Pure Dart on `backdropLayers(cam, viewW)`, `cloudCopies(cam, viewW, clock)`, `propsCopies(cam, viewW)` and
`floorCopies(cam, viewW)` (camera-and-field.md "Backdrop"), the view's width as the board's scale gives it (`viewOf`:
the band and the field take the screen's height); one widget test records a frame's drawing order,
one measures the front edge on a board's screen; the last test needs the real art (`art` tag).
- The layers go far to near: `town_bg_5` (the sky) .. `town_bg_1` (the near pines), `townLayers` reversed.
- At 1266×713, 1164×777, 915×610 (the letterbox's), 2560×1440, 3440×1440 and 915×412, with the camera at 0, −37.3,
  123.4, 242,976 (the w89 save's back line) and 1,000,000.7 (and the clouds at the clock 0, 93.25, 4 h and
  10,000,000.3 s): every layer's,
  the clouds', the props line's and the floor's first copy starts at or left of the view's left edge, its last ends
  past the right one (no gap at the far right), each overlaps the one before (no seam), they repeat at the picture's
  width on one row, and none is stretched.
- Top to bottom: every picture's pixels are the layers' size; the layers keep their rows together, the opaque sky's
  top within 16 of the band's top and its bottom past the field's top; layer 1's pines' skirts (rows 230-263) span the
  horizon (the field's top); `fieldFoot` over 0 (the welcome screen's lift; the field's is the step's, 287); the
  clouds from the screen's top (band y `fieldFoot`), in the top half of the band the screen shows; the props line from
  the band's top to under the horizon, less than 4 under it (above the first lane's feet); the floor from over the
  horizon to `fieldFoot` under the field's bottom, `frontLip` between the two, `stepLip` between the field's bottom
  and it.
- The front edge and the spawn bar's step (decisions-log 263, 287): a board with a knight shoved far under the field and
  one tick (the game keeps it at y `fieldH − 2`, the lowest a unit stands; `stepLip` 2 under its shadow's last row, its
  feet 5 under its y, the shadow 1 more); at 1266×713, 1164×777, 915×412, 915×610, 1600×947 and every size above, the
  step's top (`toScreen(0, stepLip)`) on the bar's (`spawnBarArea`), 2 world units at the scale under that shadow; the
  grass lip (`frontLip`) under the step and the floor's last row on the screen (the earth under it to the bottom); the
  scale the screen's height over the scene's, a little less (0.85 to 1 of it) on a screen under 582 px tall (915×412),
  and the view as wide as the screen at it.
- The parallax factors rise far to near and stay below 1; the props line's lies between layer 1's and 1, the clouds'
  between the sky's and the mountains'; the floor moves with the field (1), at every camera. On the clock alone the
  clouds drift left 0.3-3 world units a second, their first copy wrapped into one repeat left of the view's edge.
- `battle_floor.png`, `battle_props.png` and `battle_clouds.png` are their sizes (the placeholders too).
- Under everything: a board at 1266×713 with a knight and an archer in the first lane, rendered on a canvas that notes
  each image drawn: the backdrop's pictures come first, far to near (the sky, the clouds, layers 4-1, the props line,
  the floor), none of them after the first other image, and the knight's strip among those after.
- `art`: the map the layout rests on. `town_bg_1.png` is opaque from row 229 down in every column and only its flat
  ground (54,66,42) from row 264 down; `battle_floor.png` is opaque from the horizon (its row 40) down, its row 0 clear,
  over the horizon over a third clear (the props line shows) and over a tenth opaque (the ground line), the meadow
  under the horizon (rows 70-119) at least 0.9 of its brightness further down (no shaded band), its last 16 rows the
  front edge (its lip's row at field y `frontLip`): no earth (34,31,25) from the horizon down to the lip's fifth row,
  the earth in over 90% of the columns from its 12th row and in all of the last; every troop's, monster's and the
  necromancer's `tiny_<type>_shadow.png` ends on row 59 or above (the strips' feet row); `battle_props.png` has opaque pixels in its row 0 (the trunks
  run off the top) and over a third of its row at band y 54 clear (the pines show between the props);
  `battle_clouds.png` is between a fiftieth and a quarter opaque.
- Probe: `test/probe_battle_bg_shots.dart` (a probe; queue `["test", "test/probe_battle_bg_shots.dart",
  "--dart-define=TAG=after"]` with a mirror as `dir`; `OUT` sets the folder) shoots, at 1266×713, 1164×777, 412×860 and
  2560×1440, the welcome screen, a new game between waves and mid-wave (the camera at 0) and the w89 save between waves
  and mid-wave (the camera at its back line, ~243,000); then at 1266×713 troops in the first lane mid-wave, right in
  front of the props line, and eight shots of a still field 3 s apart (the clouds drifting): `<TAG>-<w>x<h>-<scene>.png`.
  It uses only public names, so it runs on a base from before too.
- Probe: `test/probe_field_pad_shots.dart` (decisions-log 263; queue `["test", "test/probe_field_pad_shots.dart",
  "--dart-define=TAG=after", "--dart-define=LIP=138"]`; `LIP` is the front edge's top in field y, 121.6 before 263)
  shoots, at 1266×713, 1164×777, 915×412 and 412×860, a new game whose army stands in the last lanes and the w89 save,
  each 300 frames into a wave: `<TAG>-<w>x<h>-<near|far>.png`. It prints a `PAD {json}` line a shot (the scale, the
  field's bottom and the lip on the screen, each unit's feet) and `LOWEST <size>-<scene> <y>`, the lowest unit's y over
  the wave. Public names only.

## test/touch_hud_test.dart: the HUD on a touch device (decisions-log 215)

One `TdGame` per widget test (`boot`, as hud_test.dart's); `on(platform, body)` runs a part as macOS, Android or iOS
(`debugDefaultTargetPlatformOverride`, set back after; the HUD asks every frame).

- The scale (`Board.hudScale`): the same on macOS and Android, and so are the HUD's pieces and the book, between waves
  and in a wave: 3 at 1266×713, 1280×720, the owner's tablet 1164×777 and 1366×1024 (the desktop's window as a touch
  device's since decisions-log 217), 2 at 915×412, 4 at 1920×1080; a touch device's top band never takes more of the
  height than 44 / 713.
- The owner's tablet on Android: nothing of the HUD overlaps between waves or in a wave, every button (the counter, x2,
  the book button, the Start/Pause toggle, Auto, the meter, the log) is 40 px or more each way, the meter in the first
  row.
- Safe insets (`tester.view.viewPadding`, a `FakeViewPadding` at 2.75 device px per px, `Board.safeInsets`): on Android
  the top band under the top inset, the counter right of the left one, the meter and the log left of the right one,
  the log above the bottom one, every piece and the book inside all four. macOS takes none: its HUD the same as
  without them.
- Full screen: `lifecycleStateChange(resumed)` sends `SystemChrome.setEnabledSystemUIMode` with
  `SystemUiMode.immersiveSticky` on Android and iOS (a mock `SystemChannels.platform` handler), nothing on macOS.
- Shots (a probe, `test/probe_android_hud_shots.dart`): "before" (the desktop's rule) and "after" (Android) at the
  tablet in both orientations, 915×412, 412×860 and 1266×713, the book open and in a wave, and the tablet with the
  status and gesture bars still showing.

## test/pause_test.dart: the pause (#93)

One `TdGame` per widget test (`boot`, like hud_test.dart's, also handing back the `TdGame`); `waveOn(g)` starts a wave
that is never won (its queue emptied, one orc standing still far out), `troopAt` stands a troop still.
- At 1266×713 and 915×412, between waves and mid-wave: paused (by P between waves, by the toggle in a wave) it shows
  "Pause" (`Board.pauseTitle`) at the top centre (the middle third), on the field, clear of every HUD rect (the top
  rows, the toggle, the book button, x2, Auto, the meter, the map, the log's button, the book's tabs and the book);
  x2 still works, and between waves the book's tabs; a tap on bare field keeps it paused; Esc and P resume and pause.
- Paused mid-wave by the player, with the book opened: an item from a Tas row and dragged onto a knight on the field
  (the drop popup over it), a relic from a row and dragged onto the other knight, a soldier bought from its spawn bar
  card (`Board.spawnCard`); the clock and every unit stood still, the book shut leaves it paused, Esc resumes and the
  soldier marches in. Between waves, paused, a troop dragged to the next cell takes it.
- The book (1266×713 and 915×412): opened mid-wave by its button it pauses, any page, and shut it resumes; resumed by
  the toggle or Esc with the book open, it runs and shutting changes nothing; paused first, open and shut leave
  it paused; Main Menu (`Board.menuButton`) then "Continue" (tapped where the welcome screen draws it) comes back
  paused, and shutting the book then leaves it paused.
- Between waves the auto start's countdown waits on Tas and Settings and runs on Pasukan (the Toko's page and its
  mid-wave Beli went in decisions-log 296).
- The window on the desktop (run as macOS, `TargetPlatformVariant.only`: `flutter test` says android otherwise),
  through the engine's own message (`flutter/lifecycle` on the binary messenger: the binding steps through the
  states between and turns frames off while hidden or paused): inactive keeps frames and runs; hidden and paused
  start the timer (`TdGame.runsHidden`), 2 s of fake time run 2 s of game time, a frame's `update` meanwhile is
  dropped, x2 runs twice as fast, the pause stops it; shown again, the timer is gone and 30 frames run 30×16 ms (the
  hidden time not counted twice); the auto start counts down while hidden.
- A phone in the background (decisions-log 146; a `TargetPlatformVariant` of Android and iOS: `.mobile()` has
  Fuchsia too, which isn't a phone here), by the same message: inactive pauses nothing; hidden and paused pause the
  game and Flame's loop (`game.paused`), no timer, and 2 s of fake time move nothing; back, the loop runs, "Pause"
  shows and the game waits for the toggle (Resume); a wave the book paused stays paused when the book shuts after the
  background; between waves Auto's countdown stays at 5 s in the background and back, and counts down once the game
  is resumed.
- The sound in the background (decisions-log 147). Tests can't load SoLoud's native library, so `listen()` puts a
  `FakeOutput` in `Sounds.output` (lib/sounds.dart's `SoundOutput`) and runs `Sounds.init()`; the fake keeps what
  would be heard (the loop playing, each loop's volume, whether everything is held, the effects, how often a loop was
  started). Its teardown brings the sound back to the foreground at full volumes and the game's own output again.
  - A phone (Android and iOS): inactive holds nothing; hidden and paused hold everything (no music heard) and an
    effect played meanwhile doesn't start; back, the same loop goes on (never started over), at 40% under the
    pause, effects play again, and full once resumed; on the welcome screen the same; the player's volumes at 0 stay
    silent after the background.
  - The desktop (`TargetPlatformVariant.desktop()`: macOS, Linux, Windows): hidden and paused hold nothing; the
    music and the effects go on.

## test/events_test.dart: the game's events

Pure Dart on `bareGame()` (the Hero skill helpers): every kind lands in `Game.log` exactly once where it
happens (a troop falling with its killer and rank, a #10 cast, a Hero cast, each drop of a slain mini boss,
a high elite / mini boss / boss coming in but not a normal or elite one, a Hero made after its win, an
awakening, a lost wave however long it is ticked after), stepping with a bounded `tickUntil` (at most
100–200 ticks, then it fails with a reason); the log's cap (`logSize`, `total`); the
listeners get each event in order, the telemetry's `TraceEvent`s too (a wave's start with its army, each
spawn and raised minion, buys, items and relics given, the stall march, the store's deals), which the log never keeps; an event's JSON (`eventVersion`, kind, wave, time, fields); the log is
not saved. The log's lines (`logLine`, from main.dart) name a monster and its rank as its plate does, the rank first
(`tierNames`, `monsterTypeNames`: "Budi (Soldier) fell to Mini Boss Orc Rider"), a normal one without its rank. The panel's look is the probes'.

## test/telemetry_test.dart: the balancing log (#64)

Pure Dart. An adapter over a `_Kept` sink (records through JSON, flushes counted) on a `bareGame()`: the
session record once and a game record per attach; a wave's summary from events handed to the listeners
(`send`), every field checked (spawns by type and rank, raised apart, falls and killers, gold earned and
spent, the store's gold and deals, the Pindah's gold, loot, casts, lives, time, the march; a fall's relics) and a lost wave after it starting from nothing; a wave left
mid-way; a real wave 1 played out (every spawn counted, the kills, the gold, no troop's name in any record).
The file sink's lines and its rotation (`maxBytes` 100) in a temp dir, and a file it can't write. The HTTP
stub with a fake `post` only: off by default and without a server (`telemetryServer` is empty in tests),
batches in order, off drops what waits, the backoff doubling to its cap, `keepMax`. The install id and
`sendTelemetry` in a temp settings.json. The trace events themselves are in events_test.dart (each where it
happens, never in the log); the Settings toggle is in hud_test.dart.

## test/boss_bar_test.dart, test/plates_test.dart, test/drop_popup_test.dart, test/hero_rate_test.dart

- boss_bar_test.dart (#67, pure Dart, lib/boss_bar.dart): the layers (one per `bossBarLayer` 1000 HP, "×N"
  rounded up, the top layer holding what is over the whole thousands, none when dead, big numbers whole);
  a boss's name ("<name> the <title>", its type's name without one; every type has a title); the wave's mini
  boss and boss get names as they come and bars once on the field, the boss first. The drawing is the probes'.
- plates_test.dart (#55): a monster's plate (its type's name, its rank, what kind it is, HP now / max), and
  a widget test that boots one `TdGame` like hud_test.dart: a tap pins a unit's plate, a tap anywhere else or
  its death unpins it, and a drag or hover leaves it.
- drop_popup_test.dart (#86, one `TdGame` per widget test like hud_test.dart): over a troop, the popup's lines
  (`dropLines`) for an item that fits (before → after, taken/cap, the awakening step), one outside the recipe
  and one capped (the reason, the count, how far the awakening is), a relic on a free troop and on one holding a
  relic, none off every troop; no stroked circle in the old rings' colours is painted (`paints` on the
  GameWidget). Picked once, loot stays in hand: a tap on a troop gives one each time (no pin, no message), a
  refusal keeps it, the bag running out ends it; Esc (no pause), a right click, bare ground and its slot put it
  back untouched; a drop keeps it too; relics one troop each. A Pusaka in hand shows its stars by the pointer
  (`heldCount` "★2", not the bag's "x0" for a bound one; still "★2" in the Gudang, where the bag counts it 1; an item
  "x3"; shown on bare ground by a mouse, since over the book it isn't drawn), and carried onto a troop it is refused
  (`pusakaOnType`) and stays in hand. Only held over the open book (ghost-book), on the owner's w86 save (the fixture):
  nothing at the pointer (`heldGhost` Rect.zero, `heldCount` null) and its lit slot as the cue (`heldCue` =
  `bagSlot`), on the Dragon Heart's slot, on Asah, on a tab and on the Grail's Jual; Asah's two taps arm it and raise it
  and Jual's arm it and sell it as before; on the field it is at the mouse with "★2" and no cue; a sword dragged with a
  finger over the facing page is drawn above the finger with "x3", and let go there is put back. On a phone (915×412)
  a finger's tap on the slot draws nothing at it, the knight showing left of the book: a tap on it gives one and draws
  it 28 px above the finger, "x2". The popup at 1266×713 and 915×412, dragged with a
  finger and hovered with the mouse over troops at the field's corners and by the book: on the screen, off the
  pointer, above the finger when over it, clear of every HUD rect; a pinned plate hides while loot is held and
  comes back after. Mid-wave at both sizes (a boss and a mini boss standing still, the minimap, the book and the
  battle log open): the same, for every troop not under the HUD, two at least. The looks are the probe's shots
  (`probe_shot.dart` in `~/.cache/td-shot-drag-popup`).
- hero_rate_test.dart (#69): no Hero pool holds attack rate, and a Hero saved with it rolls just that pick
  again on load (from its pool, never its other pick, which stays in place).

## test/save_test.dart, test/app_identity_test.dart (decisions-log 133)

- save_test.dart: `dataDirFor` per platform (macOS and Linux under `$HOME/.local/share`, Windows under `%APPDATA%`,
  as before; Android and iOS in the app's files dir; Android without it under `/`); `initDataDir` asks a fake
  lookup on Android only, and a failing lookup leaves the old paths (with this file's `testDataDir` off for that test,
  "Where the tests' files go"); `saveGame`/`saveSettings` into a path under a
  file, and over a read-only save.json, return false without throwing, and the save before stays.
- app_identity_test.dart reads the platform files: Android's `applicationId`/`namespace` `cloud.brata.poh`,
  MainActivity in `kotlin/cloud/brata/poh/` (none left under `com/`), the release signing (132) intact, the label,
  pubspec's `version:` shape; macOS's bundle id, `PRODUCT_NAME = tower_defense` (the process name the agents check), the
  tests' id, `CFBundleName`/`CFBundleDisplayName`; Linux's `APPLICATION_ID`; Windows's company and names; and no
  `com.example` in any text file under android/, linux/, macos/, windows/ or web/ (build output skipped).
- hud_test.dart's background test, as macOS and as Android (`TargetPlatformVariant`): hidden between waves saves,
  and pauses nothing on macOS (#93) but pauses on Android (decisions-log 146); mid-wave (paused) the last save
  stands; on the welcome screen over a fresh game nothing is saved. It calls `lifecycleStateChange` on the game
  itself, so frames stay on and #93's hidden timer (pause_test.dart) doesn't start.

## test/determinism_test.dart: the same seeds, the same run (#76)

Pure Dart. A save from before the skills and before attack rate left the Heroes' pool (#69; three Heroes with attack rate and no skill) loaded twice
with the same dice passed to `fromJson` gives the same picks. Then two runs from the same seeds, compared
wave by wave as one `digest` (the numbers, every unit's rank, HP, MP, place and picks, the bag, who fell):
a new game through its first Hero (`heroEvery` + 1 waves), and that old save from wave 11 through the mini
boss and boss of wave 15. A player that only buys and gives items (`play`) drives both, with a fixed dt.

The camera's invariant sweep (#85) plays the same fixture on seeds 1–3 for 10 waves and checks after every tick:
`viewMid` moves no more than `focusSpeed`·dt (mid-wave, the cheer and the glide; between waves the rest view
doesn't move), without a fight `meetX` keeps the troop front `frontIn` inside the view, and no monster spawns
less than `spawnClear` ahead of the foremost troop. The digest carries `cam` and `viewMid`.

## The battle point (#85): test/game_test.dart, group "the battle point"

The camera's rule, pure: rule tests place held units (a troop's `busyUntil` = `hold`; troops before monsters,
so none is `joining`) and call `g.aim()`, moving time with `g.t +=`; view tests call `g.tick`. `bare()` has
viewW 320, baseX 0, cam 0 and `viewMid` NaN. It covers the contact points and weights, `fightsOf` (a shooter
joins its target's fight), the sticky pick and its 0.75 s switch, runners, ranks, hops, the grace hold, the
chase, the troop front, `joining`, the glide cap and dead zone (x2 speed too), the lull and the win, the wave
start's approach, the spawn guard, a resize and a load. hud_test has the minimap's `battleLine`.
Elsewhere in game_test, for what the battle point (#85) changed around the camera: the spawn point `spawnLead` past the view's
edge; the kiting archer's and the healer's keep-up floor and the catch-up trigger, at the view's edge before
the wave has shown a fight and `keepUpInset` inside it after (`keepUpShift`); and a healing necromancer that
never backs off right of `rightLimit`, nor further right while it hasn't come on.

## test/path_cross_test.dart: paths that cross (#82)

Pure Dart on `bareGame()` (the Hero skill helpers), with `troopAt` (a troop standing at a point, its spot for now)
and `walkHome` (ticks until two troops stand on their spots; when each got there, the closest they came and how far
off its straight way each went). Two troops whose ways home cross (the owner's sketch, soldiers, archers, priests, a
wizard and a priest, a melee and a back-rank one, two swapping up and down) both get home within 1.5 s of walking
straight, the one going first with no detour, the other round it. The one giving way passes behind
one crossing its way. Head-on, the one whose goal is lower passes below. In battle a hurt soldier falling back meets
an archer walking up to get its foe in range: the archer (coming through from behind) goes first: the soldier bends
round it, twice as far off its way as the archer at least, and arrives as fast as walking straight. After a win, two of a rank whose ways home
cross trade spots and walk straight home, while other ranks keep theirs. Idle healers and healing necromancers take
their lanes top to bottom. A troop stuck against a wall of casting priests walks through them after
`_stuckAfter`, and none of them moves. A troop walking home that is shoved back each time it gets to one point,
walking on in between, walks through too (the probe's jam: a wizard and an archer that kept stepping back onto its
spot on the wizard's way). A kiting archer pinned at the view's left edge backs straight up to it
and holds.

## test/boss_escort_test.dart: the wave-50 escort (#90)

Pure Dart, on its own `bare` (a seeded `Game` with its slots' dice, no free healer, no monster skills, at a given
wave) and `queueOf(wave, seed)`:
- The queue: none up to wave 49, the boss's escort at 50 and the mini boss's at 51 (three healers, then the
  high-elite necromancer, right behind it), two at 60, with the wave's last healer still last on a boss wave.
- The escort's healers roll the usual ranks, and other slot dice leave the rest of the wave as it was.
- Spawned from a real queue, the four behind each slot carry `escortOf`, the wave's last healer doesn't, and the
  high elite has no name or bar.
- The high-elite necromancer's stats, MP and ceiling (it raises two elites), and its log line.
- The healers: their boss first, the no-stack window among three, their boss healed under archer fire (a plain
  healer doesn't go there), never a heal spot in a melee troop's reach, and resting a tile behind their boss (a
  lane apart, an archer ignored, out of a knight's reach within `escortReach`), then behind the rearmost once it
  is gone.

## test/necro_pair_test.dart: two necromancers in one wave, and the switch that stops it (decisions-log 165, 140)

Pure Dart, on its own `bare` (as boss_escort_test's, plus `necroPairAllowed`: null keeps the default, on, which
plays main's waves before 140; false is 140's rule) and `queueOf(wave, seed)`, which seeds each game from the seed
and the wave so every wave's boss roll is its own:
- By default, over 300 seeds × the waves with both up to 90: the queue is the switch on's, a third of the bosses
  are the necromancer and a third of their mini bosses are too.
- Switched off, the same waves: never the pair; a necromancer boss's mini boss is a type of the pool; the pair
  comes by default on ~1/9 of them, and the moved mini bosses are many types.
- Switched off, at wave 90 the moved mini bosses lean to the strong types like any mini boss (#58).
- Either way a necromancer mini boss comes at 1/3 on mini-boss-only waves and on waves with both whose boss is
  another type.
- Switched off against the default, 95 waves in a row for 40 seeds: every queue entry but the moved mini boss is
  the same, and both dice give the same next draws.
- On waves 60, 75 and 90 a pair's mini boss, the necromancer by default and a moved one switched off, has its
  escort (#90), then the necromancer boss and its own.

## test/necro_boss_from_test.dart: no necromancer boss before wave 10 (decisions-log 176)

Pure Dart. `diced(k)` is the app's game of die k (`Random(k)`, `Random(k + 100)`, loot +200, heroes +300, slots +400,
`boardRules`); `fnv` a queue's FNV-1a fingerprint (each monster "type/tier"); `headQueues` and `headWave5` the head's
(0db06e3, before the change) queues of waves 1-20 for 8 seeds, dumped from a mirror of it.
- `necroBossFrom` is 10, a boss wave.
- Dice 0-39 at wave 5: the boss is a type of the pool; the 13 dice whose roll is under 1/3 (the necromancer on the
  head) get `slotType(pool, roll / necroBossChance)`.
- Waves 1-20 for the 8 seeds: every queue as on the head, and wave 5's apart from its boss; its boss the head's, or
  a type of the pool where the head had the necromancer (seeds 4 and 7).
- 300 games to wave 30: no necromancer boss on wave 5, about a third on waves 10-30.

## test/spawn_floor_test.dart: the spawn floor (decisions-log 225)

Pure Dart, on `withTroops(n, wave:)`: a seeded `Game` with no free healer and no monster skills, `n` knights standing
still (they neither walk nor fight) and lives to spare; `kill` lays a monster down dying where it stands.
- `spawnFloorOf` and `Game.spawnFloor` with 0/1/8/9/16/33 troops: 0, 1, 1, 2, 2, 5; a Hero counts, a fallen troop
  doesn't.
- `belowSpawnFloor`: a raised minion counts as a monster on the field, a dying one doesn't, and an empty queue is never
  below it.
- With 0/1/8/9/16/33 troops a wave's first monsters come one a tick up to the floor (at least the one the timer brings
  at once), then the next exactly one gap after the last (`spawnGapOf(wave, wavePaceFrom)`, ±0.004 s).
- A field emptied 0.35 s after its first monster: with 8 troops the next comes on the next tick, then the full gap
  again; with none, after the gap as before.
- Above the floor the tide's gap holds: wave 65 with 8 troops, 0.7744 s.
- Waves 10, 50 and 60 with 33 troops, every monster killed as it comes: one a tick, never two, in the queue's order;
  the slots named, and from wave 50 each slot's escort right behind it (`escortOf`).

`test/probe_spawn_floor.dart` (a probe, not in the suite) plays the w89 fixture's waves 90-92 with two seeds and prints
per wave the floor, the fewest monsters alive while the queue held more, how long the field stood empty and below the
floor meanwhile, the first spawn times and the last, the wave's length, falls, lives and kills. It counts the floor
itself, so it runs on a base from before the floor too (a `git archive` mirror): run it on both to see what moved.

## test/engage_test.dart: spots round monsters, monsters that meet troops (#84)

Pure Dart, on `bareGame` with a wave on, nothing left to spawn and no skills (`engageGame`): monsters that
stand and never fight with HP to outlast the test (`tough`, from `foeAt`), soldiers down the zone's first columns.
- The spots: eight, `spotFill` covering each once front first and back last, their size by the troop's reach;
  a lone troop takes the front and fights from it; six take the first five spots and one back one, which the
  sixth walks round to and hits from; nine on one monster: eight hold a spot each and hit it, the ninth goes to
  the next monster, or with none waits within 3 tiles behind the fighters and takes the first spot that frees;
  a troop already in reach holds the spot on its side; spots off the field or inside another monster aren't
  taken; two walkers swap spots rather than cross; long range and healers take none; falling back, or between
  waves, a troop holds none.
- Monsters (`walker`s that walk and fight; troops that `post` still): a monster whose way to its nearest troop
  runs into another fights that one; through a real gap it walks on; a monster walking up behind one that
  fights doesn't shove it (nor the troop) on and slides round to fight too (main drove the troop ~20 px back);
  Trample still gallops through a line of troops.

## test/cut_in_test.dart: a Hero's cast cut-in queue, and the foe banners'

Pure Dart (lib/cut_ins.dart) on a `CutIns<(String, int)>` of (Hero, cast): a cut-in shows at once for
`cutInTime` and the next waiting one follows; at most `cutInWaiting` wait, a fourth dropping the oldest,
never the one showing; the same Hero casting again takes its waiting one's place; `progress` runs 0..1;
`clear`. And settings.json keeps `heroCutIns` (on when missing or broken). How it looks is the probes'.
The foe banners' (decisions-log 170): a queue with its own time and line, whose `front` ones (a mini boss's) go before
the plain ones waiting and drop the oldest plain one past the line; `FoeCutGate`'s once per key a wave, a high elite's
cap of 4 and 4 s gap (a turned-away one stays unseen), the big ones always and outside the cap, a new wave and
`clear` starting afresh; and settings.json's `foeCutIns` (on when missing or broken, apart from `heroCutIns`).
The Hero cut-ins' limit (decisions-log 298): `HeroCutGate` lets a Hero's cut-in through at most once every
`heroCutEvery` 20 s and `heroCutGap` 3 s after any other (a turned-away one stays unseen), `clear` starting afresh;
`FirstCasts` says a key's first cast of a wave once, again on the next wave.

## test/heal_mp_test.dart: a troop healer's heal costs MP, and the troops cast as often as they can (decisions-log 297, 298)

A priest beside hurt knights that never strike, in a wave kept on by a far slime: each heal costs `healMp`; short of
it no heal, `Unit.dry` and one "No MP" in `Game.noMp` until its regen brings the MP back, then again on a new dry
spell; short of MP it smites the undead in its reach for free; the after-wave heal needs no MP; with Healing Prayer
ready and two hurt side by side it holds its heals for the prayer's MP (not dry), prays as soon as it has it, and on
the prayer's cooldown heals from what is left. The words (`healerMpHelp`, `healHelp`, `noMp`, the MP tooltip's heal
line for a healer only). The awakening skills' `awakenCdK` and loosened thresholds (Consecration with a lone foe), the
Hero skills' `heroCdK` (Resurrection still once a wave; Judgement again after half its cooldown), their crowds 1 and
"hurt at all" gates, and the targets and safety gates kept. The #10 skills' table and rules are game_test's.

## test/foe_cut_in_test.dart: a foe champion's skill banner (decisions-log 170)

One `TdGame` per widget test, casts put straight into `Game.monsterCasts` (`casts`): a high elite's skill shows its
title and "`<type> <rank>`" for `foeCutTime`, an elite's or a normal one's none; Split shows its mini boss's rank
(`foeCutRank` through `raisedBy`); a mini boss's banner goes before a high elite's waiting; the same skill and rank
shows once a wave and again the next, at another rank again; a desk's banner rests at the right under the Hero band
and at the left when its caster stands under it; Settings' "Monster spotlight" turns it off (dropping the one showing,
settings.json kept, "Hero spotlight" untouched) and on, its four bottom rows apart and under "Send game data"'s
line (`Board.sendNote`), at 1266×713 and 915×412; every one of the 42 skills at every rank it is cast at fits both
screens (its title whole and 11 px at least, inside its ribbon and the screen), and
every type's line at every champion rank, with the longest title. And the fight unchanged: the owner's w86 fixture
plays 30 s of wave 87 through the Board (0.2 s a frame) the same with the banners on and off, unit by unit, with
banners shown in the first run. The shots come from `test/probe_foe_cut_shots.dart` (a probe, not in the suite: queue
`["test", "test/probe_foe_cut_shots.dart"]` with the worktree as `dir`; `OUT` sets the folder, default
`shots/foe-banner/`): the w86 fixture on wave 60, its first champion banner with a Hero's cut-in band and the Grail's
plate at once, a mini boss's banner, the boss's moment band, each with a 2× crop, at 1266×713 and 412×860, and the Hero
splash at 1266 to set beside them.

## test/foe_splash_test.dart: a monster skill's first-sighting splash (decisions-log 174)

The words first, no game: every skill's line ends in a full stop and holds exactly the numbers of its constants
(`expectedNumbers`, in order; none that differ by rank), the file writes no digit in a string, the hints (the
necromancer only shoved, Reassemble's holy damage, none for a boss or a skill with no wind-up), every glyph in the game's
font. Then one `TdGame` per widget test with a seen set given (`guideSeen = {}`; a test's board has none, so the splash
is off elsewhere), casts put straight into `Game.monsterCasts`: the first cast freezes the field (the game's clock
still for the splash's 4 s, `Game.paused` false, no "Pause", the banner it replaces not queued, a banner already showing
outliving its 1.4 s), seen in settings.json, and after its time the game goes on; a tap closes it and the Army row's price
under it buys nothing (the next tap does), Esc closes it, P closes it without pausing; a skill seen never splashes
again, in a new game too; one a wave (the second a banner instead), a boss's moment always; none with no seen set or
with "Monster spotlight" off; none while a guide card shows, the game is paused or the book is on Settings, and the
skill's next cast tries again. Every one of the 42 skills at every rank it is cast at fits 1266×713 and 915×412: its
title whole and 11 px at least, its text in two lines at most (measured in the font against the room it had), its hint
whole, the panel inside the screen, across from the caster. And the fight
unchanged: the owner's w86 fixture plays 40 s of game time of its next wave through the Board (0.2 s a tick) with
splashes on and off, to the same digest, the splashes shown and the field standing still under them in the first run.
The shots come from `test/probe_foe_splash_shots.dart` (a probe, not in the suite: queue
`["test", "test/probe_foe_splash_shots.dart"]` with the worktree as `dir`; `OUT` sets the folder, default
`shots/foe-splash/`): the w86 fixture on wave 60, 20 s played, then an armored orc high elite's Bulwark, a necromancer
high elite's Curse of Frailty and an armored orc boss's Earthshaker (a moment) wind up among the monsters, each with a
2× crop of the panel, at 1266×713 and 412×860.

## test/wipe_test.dart: an army wiped costs a heart and the wave is played again (decisions-log 322)

Pure Dart (lib/wipe.dart). A soldier at 1 HP beside a werebear makes the wipe (`wipe`); `winNow` wins the wave on.
- The wipe: 2 lives gone, not over, the wave back one with `lostWave` the lost one, no monster, queue, shot or zone
  left (the soldier fires none; a shot in the air at a wipe is test/shots_test.dart's), the swept ones hopping then gone in summon circles after `wipeCheer`, "Replace fallen" holding the army, the
  lose sound, the `Wiped` event (and its `wipe` kind) and one `WaveEnded(won: false)`, `wipeNote`; the next start plays
  the same wave with as many monsters.
- What the lost wave paid stays (gold, score, kills) and no bonus or wave score comes; its lying materials are lost; the
  replay's win pays its bonus and score once and clears `lostWave`.
- The last heart (2 lives, and 1): game over, the monsters stay, no lives score, the clock stands still; leaks taking
  the last life in the tick the last troop falls are a game lost on lives (no `Wiped`); a wave begun with no troop only
  leaks.
- A boss wave (wave 10, a Hero's too) lost: no chest nor Hero; won on the replay: one of each.
- Towns: one left before the lost wave isn't due again; one marked for after it is due only once the replay is won.
- The Shadows: the catch-up lands once for the wave number (not on the replay), and Lewati's skip buff owed meets the
  replay.
- The save between a wipe and its replay (`lostWave`, the lives, "Replace fallen"), a `lostWave` that isn't the next
  wave dropped.
- A Phoenix Plume rise due holds the wipe off; the risen one falling again with none due is a wipe.
- The auto-player loop with Auto Buy: the army bought back after each wipe, wave 1 three times, lives 4, 2, 0, over.

The shots come from `test/probe_wipe_shots.dart` (a probe, not in the suite; `OUT` sets the folder, default
`shots/wipe/`): the w89 fixture's wave 90, 12 s played, then the army held at 1 HP beside werebears that don't fall until
it is down; at 1600×947 and 915×412 the heart's pop with the message and the monsters hopping (`pop`, with 2× crops
of the hearts and the message), a second on (`hop`) and after the hop (`after`: the summon circles, the meter's next
wave). The pop shot's field is crowded with the bursts of the ticks played before it.

## test/shots_test.dart: a shot whose target went flies on (decisions-log 327)

Pure Dart (units-and-combat.md "A shot whose target went flies on"). Every shot is fired by hand (`fire`, a plain
`Shot`) by a shooter held still, at monsters held still (`still`), so only the shot does anything; the units put on the
spot come after its target fell, since two living ones closer than 12 shove each other apart.
- A wizard's shot whose target falls mid-flight: `to` is that place (null while it homes), it flies on at its own
  speed, its `fireball` burst lands there and its splash takes one blow off each orc round the spot (none past it); a
  slime there at 1 HP dies for its kill gold and a kill.
- Arcane Blast whose target leaked (`gone`): the `shards` burst, the arcane ring and the splash at the spot.
- An archer's shot (no splash) whose target fell: the orc nearest the spot within `landReach` (half a tile) takes it,
  the next one and one further off nothing; with nobody there, its burst alone.
- A skeleton archer's shot at a knight that fell: a soldier on the spot takes it; one 30 off doesn't.
- The wave's last monster gone with shots in the air: both are `spent`, the monster's arrow lands on the knight and
  hurts nothing, the archer's lands where its target went.
- A wipe with an archer's shot in the air at a monster: spent, frozen where the swept monster stood, its burst alone.

The shots come from `test/probe_shot_through_shots.dart` (a probe, not in the suite; `OUT`, default
`shots/shot-through/`): at 1600×947 a wizard's fireball and its Arcane Blast at an orc that falls when the shot is 32
from it, with two orcs 14 above and below it, a frame every 48 ms; it prints the screen box round them and the HP the
splash took.

## The field's rings in the sprites' pixels (decisions-log 325)

`test/pixel_rings_test.dart` (ui-hud.md "The field's rings in pixels"):
- **The cells:** `pixelRingCells` at 20 × 8 is the stepped oval drawn out row by row, and at five sizes fills its box,
  mirrors both ways, is one closed line with no 2×2 block. `pixelDashCells` at the effects' four sizes stays on its
  ring and shows every cell at some step; from 14 × 6 up about half of it at each step, turning from the last.
  `pixelHaloCells` at radii 13-16 holds exactly the four band alphas, each cell its band's, inside the circle,
  mirrored, the area of a disc. `pixelDiscCells` at seven ranges is one centred run a row, mirrored, a disc's area.
- **Drawn, read back pixel by pixel** on a booted board, at zooms that are no whole number and off the screen's
  pixels (a pixel whose middle is within a hair of a cell's edge is skipped), through the field's own draws (for
  tests: `Board.paintPusakaRing`, `paintHeroHalo`, `paintReachDisc`): the Pusaka's ring is nothing or its colour at 90%
  (no anti-alias), on its cells one world unit each, its box 20 × 8 centred 1 above the feet to a screen pixel, every
  Pusaka's colour as before and Moonwell's cream for one without its own; the halo is white at one of its band alphas
  or nothing, each cell its own band's; the reach at ranges 12, 64 and 96 is white at 12% or nothing, on the disc's
  cells.
- **On the field:** at 1600×947 and 915×412 an archer drawn before and after its type takes God's Thunder differs
  round its feet only on the ring's cells, at least half of them showing round the body. At 1600×947, drawn with no
  step between: a knight under Holy Shield's guard differs only on the guard ring's 16 × 7 cells; a werebear with a slow
  and a Barrier only on the effects' 18 × 8 and 14 × 6 cells; a braced knight (a monster on the field, so the wave is
  on) only on the brace ring's cells in its rows under the feet (its body takes the thrust), 80% of them showing.

The shots and the frame time are `test/probe_pixel_rings.dart` (not part of the suite): the owner's wave-30 save
(`SAVE`), 8 s into its wave at 1600×947 and 915×412, the whole frame and 6× close-ups round a plain troop, a Hero and an
awakened troop of bound types (at their drawn bodies, `Board.drawnAt`); a guard, Spear Wall's brace, a monster's slow
and Barrier, a Hero's halo and a dragged troop's reach put on for one frame (`others-<size>`), with their close-ups;
then 40 s of the wave at 1600×947, each frame's `Board.render` timed and every 10th rasterised. Queue it on the branch
(`TAG=after`) and on a mirror of main (`TAG=before`, the file copied in if main lacks it).

## The packs' looks: the shot probes (decisions-log 173)

The field's effects and the screen's pieces are cut from the packs' sheets (ui-hud.md); no test pins a pixel of them,
so two probes (not in the suite) shoot them, to look at beside main's: queue the same probe in a mirror of main and in
the branch, with `OUT` set to two folders.

- `test/probe_fx_shots.dart` (`--dart-define=GROUP=1..4` or `all`): a gallery of eight looks on a bare game's field,
  each at 20%, 50% and 80% of its time, beside a pack hit burst: 1 the orbs, plain rings, the glob and the special
  arrows; 2 the troops' skills (#81); 3 the awakening skills (#88); 4 the zones and Skyfall's landing shadow.
- `test/probe_fx_ui_shots.dart`: the w89 fixture (`save-20261002-2222-w89-sellbug.json`), its dice seeded, so main and a
  branch show the same moments: the Tas page's "now ▸ after" rows; then, a wave on, the "VICTORY!" popup with a dropped
  relic and item, a Hero's cut-in band 0.2 s in and after its slide with the Grail's plate, and the Hero splash 0.25 s in
  and later with its Hero moved into view (its ring on the field).

## Checking visuals

**The live window** (real fonts), on macOS with the game running:

```sh
id=$(swift -e 'import CoreGraphics; for w in CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as! [[String: Any]] where w["kCGWindowName"] as? String == "Path of Hero" { print(w["kCGWindowNumber"]!) }')
screencapture -x -o -l "$id" shot.png
```

- `-l` captures only the game window, `-o` drops its shadow. The terminal needs Screen Recording access; the
  window-name lookup depends on it.
- The PNG is Retina, 2× the window: 2532×1482 for the 1266×713 window plus its title bar.

**Offscreen** (any exact size, no window). A probe widget test (`~/.cache/td-shot-<name>/test/probe_shot.dart`,
see above) sets `tester.view.physicalSize` (with `devicePixelRatio = 1`), pumps
`GameWidget(game: game)` inside a `RepaintBoundary`, waits for the images, then calls `toImage()` →
PNG inside `tester.runAsync`. `onLoad` decodes images in real time, so a single `runAsync` wait
followed by pumps renders black; alternate them until the game has loaded:

```dart
for (var i = 0; i < 100 && !game.isLoaded; i++) {
  await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 100)));
  await tester.pump();
}
```

- Check the desk (1266×713) and a phone (915×412); a view taller than wide only through `gameRoot`, in its letterbox
  (test/letterbox_test.dart's `bootRoot`).
- Use ONE `TdGame` per widget test (a probe file usually has one test): a second one's `onLoad` re-adds the in-memory images
  (`book_<type>_idle`, `tiny_necro_healer_*`) to the shared cache and fails `Image.dispose`'s assertion,
  and the field's sprites then fail `drawImageRect` (the HUD never draws). For several sizes, change
  `tester.view.physicalSize` between shots and give the board a fresh `Game` each time.
- The game opens on the welcome screen. To shoot the field, set `game.board.welcome = null` once
  loaded. To shoot the welcome screen as a player with a save sees it, set
  `game.board.welcome = Welcome(Game()..wave = 3, discard: () {})` (never the real `clearSave`).
- Text renders as boxes in tests (Ahem font). For the real look, load the game's font before pumping:
  `await loadHudFont(tester);` (test/hud_font.dart; `loadHudFontNow()` inside a `runAsync`). It loads
  `hudFontAsset` under the family `hudFont` and both `digitFontAssets` under `digitFont` (lib/hud_font.dart), so a
  test lays text out with the app's widths and draws the app's 5.
  The font maps a space (until decisions-log 158 the old one didn't, and the probes patched one in), so a
  shot's spaces are the app's. A test has no fallback font: a glyph the font lacks ("★", "→") is a box there,
  which is why the HUD draws those and the cmap tests (`fontChars`) keep them out of every string.
- The open book bobs (a 3.93-s cycle, a fraction of a pixel a frame), so the same page drawn twice is not the same
  pixels on the screen. To check that nothing on a page moves or comes and goes while nothing changes in the game, step
  the clock over a whole bob and compare its layout measured from one of its own cells (rows, slots, pagers, headings),
  never from the screen: test/forge_smithy_ui_test.dart's `leftLayout`, bag_grid_test's page sizes. A room counted from
  a rounded top flickers where a row fits to within a pixel, at some window sizes only: test/probe_smithy_blink.dart
  (decisions-log 277) samples a bob at 64 ms a frame at 1266×713, 1164×777, 915×412, 412×860 and the owner's 1600×947
  (and 1600×975), and sweeps window
  heights 400 to 1000 at 1266 and 1600 wide (`SWEEP_W`, `SWEEP_STEP`), printing every size whose layout changes.
- A page part reached through its page or its scroll (decisions-log 283: the landscape book is shorter, so more pages
  and scrolls): test/page_scroll.dart (not a test file) scrolls a book page's part ('smithy', 'tavernList',
  'tavernFacing') until a rect shows (`scrolledTo`), says whether it scrolls (`scrolls`) and walks it down, giving
  where a part was in content terms (`scrolledDown`); test/bag_pages.dart turns the Bag's grid to a kind's page
  (`bagTo`), walks the Smithy's Relics or Enhance board's pages (`smithyBoardPages`) and turns it to a relic
  (`smithyBoardTo`). Check a part as the player reaches it: pin it on the page or at the scroll that shows it, never
  loosen a check to fit a short page.
