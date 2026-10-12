# Telemetry

Purpose: the balancing log (#64): what is recorded, where it goes (the local file, the HTTP stub), what is
never in it, and how to read it.

The owner: "kita perlu buat fitur log yang dapat dikirim ke server di mana lognya itu mencatat semua kejadian
yang terjadi dalam game supaya kita punya data untuk balancing gamenya ke depan", every monster spawned
included, so we know what the player fought: too easy or not. The code is lib/telemetry.dart (pure Dart); the
events it listens to are #60's stream (lib/game_events.dart, architecture.md).

## How it listens

- `TelemetryAdapter(sinks, installId:)` listens to one `Game` at a time on `Game.listeners`: `attach(g)`
  (again for the same game does nothing; another game detaches the one before), `detach()`.
- main.dart makes one (`_telemetry`, with `_httpSink`) and attaches it in `Board.update` whenever another
  game comes in (a new one, a save), where the auto start's countdown is cancelled too. Nothing is listened
  to behind the welcome screen.
- It gets every `GameEvent` plus the `TraceEvent`s, the events only the telemetry needs, which never go
  into `Game.log` (so the battle log never shows them):

| Trace event | Emitted where (lib/game.dart) |
|---|---|
| `WaveStarted` | end of `startWave`: the army (`troopCounts`), awakening levels above 0, each living Hero's type and own skill, gold, capacity, lives, the item and relic bags, the tide on the wave's crowd (#92: `tide` `{hp, dmg, gap}`, 4 places, and `over`, decisions-log 162), and `pusaka`: each Pusaka owned, name → its `type` (left out in the Gudang), `stars` and `ukir` (its Ukir steps, only when above 0) (`Game.pusakaState`, decisions-log 138) |
| `MonsterSpawned` | a monster off the wave's queue in `tick` (before `StrongFoe`), and each minion a necromancer raises in `_summon` (`raised: true`) |
| `Bought` | `place` (a troop, after paying) and `buyCapacity` (`type` null) with the price |
| `ItemUsed`, `RelicUsed` | `useItem`, `useRelic`, only when taken |
| `RelicTakenOff` | `takeOff` (#91), only when it came off: the relic and the troop's type |
| `TypeReleased` | `releaseType` (Lepas jenis, decisions-log 141), only when done: the type, how many troops went home and the gold paid back (`refund`) |
| `Marched` | `_watchStall`, when the wave stalls and its monsters march; `why` (`MarchCause`: `stalled`, `drifting`, `overtime`, `overtimeMax`; units-and-combat.md "Stalled waves") is the listeners' only: the wave record keeps the time alone |
| `StoreBought`, `StoreSold` | the store's `buy` (the loot and the price paid) and `sell` (the loot, how many, the gold paid for them) (#63, lib/store.dart); a material sold to the Town's Shop is `material` by name, `item` and `relic` null (decisions-log 230; the key only then), and a material bought from it too (decisions-log 248) |
| `PusakaBound`, `PusakaMoved` | `bindPusaka` (lib/pusaka.dart, decisions-log 138): from the Gudang, `PusakaBound` (`relic`, `type`, `stars`, `cost`: 0 the first time, else the Pindah's price); from another type, `PusakaMoved` (`relic`, `from`, `to`, `cost`). `unbindPusaka`, and a Pusaka put out by another bound onto its type, are `PusakaMoved` with `to` null and `cost` 0 |
| `OfferShown`, `OfferRerolled` | the boss chest (lib/draft.dart, decisions-log 152): `OfferShown` at every roll of a chest's cards (`cards`, names or `serpihan`; `rarities`; `reroll` 0 for its first roll; `chest` `boss` or `catchUp`; `chestWave`), `OfferRerolled` at a Kocok ulang (`price`, 0 with a Serpihan; `serpihan`) |
| `UkirFed`, `UkirStep` | Ukir (lib/pusaka.dart's `feedUkir`, decisions-log 183; loot-items-relics.md "Ukir"): `UkirFed` at each tap (`relic`, `items` kind → count taken from the bag, `points`, `type` where it is, null in the Gudang), `UkirStep` when a tap fills the bar (`relic`, `step` 1 to 5, `stars`, `type`, and `starUps`, only when it set off star-ups for the enemy buffs) |
| `TownRolled` | the Town roll after a won wave (lib/town.dart's `_rollTown`, decisions-log 216; loot-items-relics.md "Towns"), once every won wave: `town`, what it did (below). It only completes that wave's record: never passed on |

## The records

Every record is one JSON object with `tv` (`telemetryVersion` 16: raise it when a field changes; 2 added the wave's
`pusaka` and `gold.pusakaSpent`, decisions-log 138; 3 the boss chest's events and `gold.chestSpent` /
`gold.chestEarned`, decisions-log 152; 4 Asah's `pusakaAsah` and `gold.asahSpent`, decisions-log 154; 5 the wave
start's `tide.over`, decisions-log 162; 6 Tempa's `tempa` and `gold.tempaSpent`, decisions-log 163; 7 Lebur's
`pusakaLebur` and `gold.leburSpent`, decisions-log 164; 8 the Bayangan's `omenGained` and `omenEased`, the chest's faces
and a take's levels, and the wave start's `omens`, decisions-log 180, written only while `omensOn` is on; and Ukir's
`ukirFed` / `ukirStep`, the wave's `ukirItems` / `ukirPoints` / `ukirSteps` and each Pusaka's `ukir`, decisions-log
183; 9 the Towns' `townMarked`, `townEntered`, `townLeft` and a won wave's `town`, decisions-log 216, a wave's
`materials` and its start's, decisions-log 221, and the Smithy's `crafted`, a `townLeft`'s `crafts` / `craftSpent` and a
wave's `crafted`, `materialsUsed` and `gold.craftSpent`, decisions-log 233, written only while `Game.towns` was on (every
game since decisions-log 321); the
Tavern's, decisions-log 266, came without a raise: only a game with the Tavern's switch on and the Towns wrote them, which no
player's game had yet; 10 the forge in every board game since its cut-over, decisions-log 272: a wave's `relics` and
`relicPairs`, the items, stones and Enhance steps in its `crafted`, `materialsUsed` and `gold.craftSpent`, the events
`itemCrafted`, `stoneCrafted` and `itemEnhanced` (`eventVersion` 10), and two meanings: `dropped` holds no item, since
none drops, and `materials` about three times as many (the forge-off build, whose records were as at 9, is gone,
decisions-log 296); 11 the Tavern switched on, decisions-log 268: its `boostBought`, `tavernRerolled`, a `townLeft`'s
`tavern`, a wave's `gold.tavernSpent` and `boostSaved` and its start's `boosts` in every board game (`eventVersion`
11), written only while `Game.towns` was on; the Tavern's own switch is gone, decisions-log 296); 12 the Bayangan
switched on, decisions-log 319: 8's Bayangan fields and the Dusk's `omenDusk` in every player's records (`eventVersion`
12; none with `--dart-define=OMENS=false`); decisions-log 321 raised neither: the `towns` switch and the field drops'
event `drop` went, but every player's game had the Towns, so none of its records changes (`dropped` and
`relicsDropped` stay in the wave record, always `{}`); 13 an army wiped mid-wave costs a heart and the wave is played
again, decisions-log 322: the event `wipe` and a wave record's `end` `wiped` (`eventVersion` 13); 14 the Towns'
market and identities, decisions-log 326: a `storeSold` of an item or a small relic carries `margin` and `pressure`, a
`townEntered` `n` and `identity`, and an item's and a small relic's `gain` is the market's price (`eventVersion` 14); 15
a Tavern boost's length rolled with its offer, decisions-log 331: a `boostBought`'s `waves` 2 to 4, or 0 with
`untilTown`, and a wave start's `boosts` 0 for one until the next Town (`eventVersion` 15); 16 the back line costs
nothing, decisions-log 329: no monster crosses it, so a wave's `livesLost` is 0 or a lost wave's heart; a `wipe` has its
`cause` (`fell`, `empty`: a monster at the line with no troop standing, `slow`: a march not won within 60 s, its
record's `marched` set), each a record's `end` `wiped`; Watchman's Brew and the wave's `boostSaved` are gone
(`eventVersion` 16), `rec`,
`install`, `session`, `game` (the number of the game within the session, 0 before the first) and `at` (UTC,
ISO 8601).

| `rec` | When | Its fields |
|---|---|---|
| `session` | once, when the adapter is made (the first game played after launch) | `app` (`APP_VERSION` define, `dev`), `platform` (`Platform.operatingSystem`), `ev` (`eventVersion`) |
| `game` | each `attach` | `wave` (0 new, more for a loaded save), `gold`, `lives`, `score` |
| `event` | as it happens, for `passedOn`: fell, heroMade, awakened, bought, itemUsed, relicUsed, storeBought, storeSold, relicTakenOff, typeReleased, pusakaBound, pusakaMoved, ascended, heroRecalled, offerShown, offerPicked, offerRerolled, pusakaAsah, tempa, pusakaLebur, omenGained, omenEased, omenDusk, ukirFed, ukirStep, townMarked, townEntered, townLeft, crafted, itemCrafted, stoneCrafted, itemEnhanced, boostBought, tavernRerolled, wipe | `event`: the event's `toJson()` (`v`: `eventVersion` 16 (3: the chest's events; 4: Asah's; 5: heroRecalled's `refund`; 6: Tempa's; 7: Lebur's; 8: the Bayangan's, Ukir's, an Asah's `items`; 9: the Towns'; 10: the forge's, decisions-log 272; 11: the Tavern's, decisions-log 268; 12: the Bayangan's switched on, decisions-log 319; 13: the wipe's, decisions-log 322; 14: the market's and the Towns' identities, decisions-log 326; 15: the Tavern's lengths, decisions-log 331; 16: the wipe's `cause`, Watchman's Brew gone, decisions-log 329), `kind`, `wave`, `t`, its fields) without `name`; `wipe` (a wave lost, lib/wipe.dart; its `wave` the one lost): `lives` (left), `livesLost` (2, a heart; fewer when fewer were left), `foes` (the monsters alive and queued as it fell, swept off unless the game is over), `over` (it took the last heart: the game is over; else the wave is played again, a new `wave` record with the same number) and `cause` (`fell`: the army fell; `empty`: a monster reached the back line with no troop standing; `slow`: a march not won within `marchMax` 60 s; decisions-log 329); a `fell` carries the troop's `relics` (names, back in the bag; `eventVersion` 2); `ascended` (#92 part 2, Bangkit 4-5 bought in the Toko, `Ascend.ascend`): `type`, `level` (4 or 5), `cost`; `heroRecalled` (#92 part 3, a fallen Hero called back in the Toko's Hero Gugur, `Recall.recallHero`; no `bought` for it): `type`, `stats` (its 2 attributes), `skill`, `fell` (the wave it fell in), `cost`, `refund` (`eventVersion` 5, decisions-log 167: what the troop a full army's recall sent home paid back, 0 without a swap; the troop's name stays in the battle log; `gold.recallSpent` is the `cost`, the refund not taken off); `offerPicked` (a boss chest closed, lib/draft.dart): `pick` (a Pusaka's name,
`serpihan`, or null when passed over), `rarity`, `stars` (after the take), `type` (where it went; null: the Gudang),
`skipped`, `gain` (Lewati's gold), `rerolls`, `chest`, `chestWave`, and while the Bayangan are on (loot-items-relics.md
"Bayangan", decisions-log 180) `omen` (the face the taken card hid; null: none), `levels` (the kinds its levels went to,
one a level, oldest first: `[]` with no face, on a Lewati or when every kind is full) and `skipBuff` (a Lewati from wave
20: the next wave owes the skip buff); `offerShown` carries `omens` then (each card's face, null for none);
`omenGained` (the enemy gained a Bayangan): `omen`, `level` (after it), `gained`, `from` (`chest`, `catchUp` for an old
save's catch-up, `ukir` for a Pusaka's Ukir star) and `chestWave`; `omenEased` (a won wave's falls took the newest level
away): `omen`, `level` (after it); `omenDusk` (the Bayangan Dusk fell in the wave, once a wave, only while its kind
has a level; it came without a version raise, as no older record changes): `omen` (`dusk`), `level`, `share` (what each
blow gains from then); `pusakaAsah` (a Pusaka's star bought on the Tas page,
`Asah.asah` in lib/pusaka.dart, decisions-log 154): `relic`, `stars` (after it), `type` (where it is; null: the Gudang),
`cost`, `relics` (the small relics taken from the bag, name → count), `items` (the items it took, name → count; only
when any: `asahItems`, none by default); `tempa` (a Tempa level bought on the Army detail,
`Tempa.temper` in lib/tempa.dart, decisions-log 163): `type`, `level` (after it, 1 to 30), `cost`; `pusakaLebur` (a Gudang Pusaka melted into
another on the Tas page, `Lebur.lebur` in lib/pusaka.dart, decisions-log 164): `fodder` (the one melted, gone now),
`fodderStars` (its stars, lost), `relic` (the target), `stars` (after it), `type` (the target's; null: the Gudang),
`cost`, `relics` (`{}` while `leburRelics` is 0); the Towns' (lib/town.dart, decisions-log 216): `townMarked` (a roll hit): `slot` (the Town comes before that wave), `chance` (the roll's), `rolls` (the how-many-th
roll since the last Town, or the run's start); `townEntered`: `slot`, `gold`, `auto` (Auto was on), `n` (the how-many-th
Town of the run) and `identity` (its key, `millbrook` .. `highspire`; decisions-log 326); `townLeft`: `slot`,
`secs` (game seconds in the Town, two decimals), `auto` (Auto left it), `crafts` (the relics crafted there, name → count,
`{}` for none) and `craftSpent` (their gold; decisions-log 233); `crafted` (a relic made at a Town's Smithy, lib/town.dart's
`Craft.craft`, decisions-log 233; loot-items-relics.md "Town and Smithy: Craft"): `relic` (its save key), `materials`
(key → how many it took), `items` (item → how many, `{}` for a Basic relic), `gold`; `itemCrafted` (an item made there,
`Craft.craftItem`, decisions-log 249; loot-items-relics.md "The forge: items crafted, Awaken by
grade"): `item` (its save key), `materials`, `items` (the grade below a Cap or a Ring takes, else `{}`), `gold`;
`stoneCrafted` (a forge stone made there, `Enhance.craftStone`, decisions-log 255; loot-items-relics.md "The forge:
Enhance"): `stone` (`mithril` or `starmetal`), `materials`, `gold`; `itemEnhanced` (an item in the Bag taken a step up
there, `Enhance.enhance`): `item`, `plus` (the step reached, 1 to 5), `stone`, `gold`. An `itemUsed` or a `storeSold` of
an enhanced item carries its `plus` too (none for +0, so every other record is as before). A `storeSold` of an item
or a small relic carries `margin` (the market's for its first piece, two decimals) and `pressure` (the product's
before the sale; loot-items-relics.md "Towns: the market", decisions-log 326). The Tavern's (lib/tavern.dart,
decisions-log 266; loot-items-relics.md "Towns: the Tavern"): `boostBought` (a
boost bought, `Tavern.buyBoost`): `boost` (its kind), `rarity` (`common`, `rare`, `epic`, `legendary`), `price`,
`waves` (2 to 4, the offer's length; 0 for one until the next Town, decisions-log 331, `telemetryVersion` 15), `untilTown`
(true, only then), `type` (only a Champion's Plate's troop type), `slot` (the offer's, from 0), `effects` (what it multiplies,
by its town.json names: `{"dmg": 1.2, "taken": 0.85}`); `tavernRerolled` (the unbought offers rolled again): `price`,
`n` (the visit's how-many-th), `offers` (the kinds after it, by slot); and a `townLeft` gains `tavern`: `offered` (the
kinds of the visit's last roll), `bought` (the kinds bought), `rerolls`, `spent` (boosts and rerolls). Not passed on: the battle log's `grailSaved` and `pusakaReport` (decisions-log 149), whose counts are the wave record's `pusaka` |
| `wave` | a wave's end: `WaveEnded`, or `detach` mid-wave | below |

A `wave` record sums everything since the last wave ended (so the shop before a wave counts in it):

| Field | What |
|---|---|
| `wave`, `end` | its number; `won`, `lost` (the game is over), `wiped` (the wave was lost and is played again: the next record has the same number; decisions-log 322, 329; its `wipe` event says why) or `left` (another game came in mid-wave) |
| `secs`, `marched` | game seconds from its start to its end (time to clear); seconds in when it stalled and marched, or null |
| `start` | `WaveStarted`'s fields: `army`, `levels` (1 to 5: Bangkit 4-5 bought count, #92 part 2), `heroes`, `gold`, `capacity`, `lives`, `bag`, `relics`, `tide` (#92: the crowd's HP and damage multipliers and the spawn gap in seconds, `{hp: 1.3478, dmg: 1.1614, gap: 0.7743, over: 0}` on wave 65; 1, 1, 0.9 before the tide; `over`: how many waves earlier the tide counts from for an army over the cap, Beban, decisions-log 162: 32 for the owner's 16 over 32 once ramped in, 0 at the cap or under it, `hp`, `dmg` and (with `overPace` on) `gap` already including it; units-and-combat.md "The tide"), `pusaka`, and while the Bayangan are on `omens`: `levels` (kind → level), `factor` (the Beban factor frozen for the wave, four decimals), `owed` (an old save's catch-up levels still to land) and `skipBuff` (this wave owes Lewati's skip buff); while the Towns are on `materials` (the Towns' materials held, key → count, decisions-log 221); while a Tavern boost runs
`boosts` (kind → the waves it has left, counting this one, 0 for one until the next Town; decisions-log 266, 331) |
| `livesLost`, `kills` | lives at the start minus at the end; monsters killed in it (raised minions too) |
| `spawns`, `raised` | type → rank → how many: off the queue; the necromancers' minions |
| `fallen`, `heroesFallen`, `killers` | troop type → how many fell; Heroes among them; monster type → rank → troops it felled |
| `bought` | troop type (or `capacity`) → how many |
| `storeBought`, `storeSold` | item or relic → how many bought in the store, sold to it; `storeSold` also counts the materials sold (key → how many, decisions-log 230), and `storeBought` the materials bought (decisions-log 248) |
| `gold` | `start`, `end` (before the win's bonus), `earned` in battle (kills and Plunder: end − start + what was spent after the start − what the store paid after it), `spent` on troops and capacity, `storeSpent` and `storeEarned` (the store), `pusakaSpent` (on Pindah: a Pusaka bound again), `ascendSpent` (Bangkit 4-5, #92 part 2), `recallSpent` (fallen Heroes called back, #92 part 3), `chestSpent` (the boss chest's Kocok ulang) and `chestEarned` (its Lewati), `asahSpent` (Asah, a Pusaka's star; between waves only, so it lands in the next wave's record), `tempaSpent` (Tempa past
Bangkit 5, decisions-log 163; between waves only, like Asah), `leburSpent` (Lebur, a Gudang Pusaka melted into another
for a star, decisions-log 164; between waves only, like Asah's), `craftSpent` (relics
crafted at a Town's Smithy, decisions-log 233, and items, 249; between waves, so in the next wave's record),
`tavernSpent` (its boosts and rerolls, decisions-log 266; in a Town, so in the next wave's
record), `bonus` (`Game.waveBonus`,
0 unless won) |
| `ukirItems`, `ukirPoints`, `ukirSteps` | Ukir since the last wave ended (between waves only, so in the next wave's record; decisions-log 183): the items fed, kind → count; their points; each Pusaka's steps taken, name → count. Only when some was fed: a record without Ukir has none of the three |
| `pusaka` | each Pusaka owned at the wave's end, name → `type` (null in the Gudang, and always for an oath, decisions-log 155), `stars`, `ukir` (its Ukir steps, only when above 0), `uses` (the Grail's saves) and `worth`, its effective counter for the wave (two decimals; `PusakaTally`, loot-items-relics.md "Pusaka"): the Grail's saves kept, Dragon Heart's blows lived through that would have killed at base HP, Dawn Star's extra damage and healing that landed, God's Thunder's leap damage, Void Eye's bonus damage, Dragon Crown's cut blows (`uses`) and the HP they kept; the oaths none (0) |
| `used`, `relicsUsed`, `relicsTakenOff` | item or relic → how many (`relicsTakenOff`: taken off troops back into the bag, #91) |
| `dropped`, `relicsDropped` | always `{}`: no item or relic drops (decisions-log 246, 321; a record before the Towns had them, item or relic → how many); kept so the record's shape stays |
| `materials` | the Towns' materials the wave dropped, key → how many (summed, never an event each: a late wave drops about 30; loot-items-relics.md "Town and Smithy: materials", decisions-log 221) |
| `crafted`, `materialsUsed` | the relics crafted at a Town's Smithy since the last wave ended (a Town comes between waves, so its crafts land in the next wave's record), relic → how many, and the materials they took, key → how many (decisions-log 233); the items crafted there too, item → how many (an item's key is never a relic's; decisions-log 249), their materials and gold counted the same, and Enhance's stones made, `mithril` / `starmetal` → how many, with an Enhance step's stone in `materialsUsed` and its gold in `gold.craftSpent` (decisions-log 255); `{}` when none |
| `relics`, `relicPairs` | the forge's (decisions-log 250; since `telemetryVersion` 10, the forge's cut-over, decisions-log 272): `relics`, each of the forge's nine small relics that did something in the wave, key → `uses` (Chill's slows, Weak Spot's marks, Reaper's ends and boss hits, the others' hits powered) and `worth` (the damage it added, two decimals; loot-items-relics.md "The forge's nine"); `relicPairs`, each pair a troop wielded (its relics' keys in `Relic` order joined by `+`, then `@` and its type's bound Artifact: `fury+giantSlayer`, `grit@warDrum`; only a troop with two of those, `Relics.comboKeyOf`) → `troops` (how many of them dealt damage) and `dealt` (the damage they dealt, two decimals) |
| `casts`, `heroCasts`, `monsterCasts`, `awakenCasts` | troop skill name → casts; Hero skill → casts; monster skill (#59, `MonsterSkill.name`) → rank → casts; awakening skill (#88, `AwakenSkill.name`: `disarm`, …) → casts (`AwakenSkillCast`) |
| `score` | the game's score at the end (the lives left scored nothing since 322 and went in decisions-log 329) |
| `town` | only on a won wave: what the Town roll after it did (`TownRolled`): `{chance, hit, slot?}` when it rolled (the roll's chance, whether it hit, the slot it marked), `{blocked: true}` within `minGap` of the last Town (no roll), `{marked: slot}` while a Town is marked (no roll). The roll comes after the wave's end in the same tick (after the Hero and the Boss Chest), so the adapter holds a won wave's record until it, and `heroMade` or `townMarked` passed on then come before it in the file |

The per-cast and per-spawn events are only summed, never passed on one by one: a late wave spawns and casts
hundreds, and the file must stay small. The sinks are flushed at every wave's end and on `detach`.

## The sinks

- `TelemetrySink`: `add(record)`, `flush()` (never throws). `NoSink` keeps nothing.
- `FileSink(file, maxBytes: 256 KiB, keep: 2)`: JSON lines, buffered until `flush`, then appended. A flush
  that would take the file past `maxBytes` first moves it to `.1` (`.1` to `.2`, the oldest deleted), so the
  files stay under (keep + 1) × maxBytes = 768 KiB. A file that can't be written loses those records.
  main.dart's is `dataFile('telemetry.jsonl')`, beside the save: on macOS
  `~/Library/Containers/cloud.brata.poh/Data/.local/share/tower_defense/telemetry.jsonl` (under
  `com.example.towerDefense` before decisions-log 133), on Android in the app's files dir (dev-workflow.md "App
  identity"). It is always written, whatever the toggle. A write that fails logs (`debugPrint`) and the game goes on.
  Besides each wave's end, main.dart flushes when the app goes to the background.
- `HttpSink(url, enabled:)`: a STUB until a server exists. On only when enabled and `url` is set; off it takes
  nothing. It POSTs `{"tv": 1, "records": [...]}` to `url` in batches of 100, oldest first (`postJson`,
  dart:io, 10 s timeout; tests pass their own `post`). At most 1000 wait (the oldest dropped). A batch that
  fails or throws goes back and nothing is tried for 5 s, doubling each failure up to 5 min; a success resets
  it. Turning it off drops what waits. What waits is in memory only: it is lost when the app closes.
- The server: `--dart-define=TELEMETRY_SERVER=https://...` (`telemetryServer`). No build sets one yet, so
  nothing is ever sent; tests never have it either.

## The player's say, and privacy

- Settings' "Send game data" (ui-hud.md) sets `Settings.sendTelemetry` (settings.json), off by
  default, and turns `_httpSink` on or off. It gates only the server copy. (The issue said "default ON in
  dev builds"; the orchestrator's brief said off by default, which is what shipped: decisions-log 101.)
- Nothing personal: the install id is 16 random bytes in hex (`Random.secure`), made on first use and kept
  in settings.json (`installIdOf`); the session id is 8 random bytes a launch. The scoreboard name is never
  in a record, and the troops' names (generated) are dropped from the events. No device data but
  `Platform.operatingSystem`.

## Reading it

```sh
python3 tool/telemetry_summary.py                   # the macOS app's files (and ~/.local/share's)
python3 tool/telemetry_summary.py a.jsonl b.jsonl   # given files, e.g. what a server collected
python3 tool/telemetry_summary.py --app 1.2.0       # one build's records
```

Per wave number, over every run in the files: runs that reached it and won it, the army at its start, troops
fallen and `loss%` (fallen / army: the "too easy or not" number), Heroes and lives lost, time to clear, how
many stalled and marched, gold earned, and the spawn mix per run (type, ranks n/e/h/m/b; raised minions
apart), and gold spent in the store. With the Towns on (any wave record with a `town` or `materials`; the board since
decisions-log 237) four columns more: `town` (runs whose Town came just before this wave, from the won waves' `town`
slots), `mats` (materials the wave dropped, per run), `craft` and `craft$` (relics, and with the forge items, crafted at
a Smithy before it, per run, and their gold), then the Towns in all (decisions-log 253), each line from what is
recorded:

- "towns: N entered, M left by Auto, S s inside, G gold brought in (each on average); first at wave 7 x3, 8 x1":
  `townEntered` (its `gold`; each run's first Town by its slot) and `townLeft` (`auto`, `secs`).
- "town rolls after won waves: R rolled, H hit; none B times (too soon after a Town), none M times (a Town already
  marked)": the won waves' `town`.
- "bought in a Town Shop: N for G gold: items …; relics …; materials …" and "sold to a Town Shop: … relics bought back
  … (fang 2) …": the `storeBought` / `storeSold` events of the runs with the Towns on (a run counts so with any Town
  event or wave field; outside a Town the Shop refuses every buy and sell), each kind with its count, its gold and its
  keys; a relic sold is the Shop's buy-back.
- "crafted: N relics for G gold: fang 4, …" (`crafted`) and, with the forge, "crafted items: N for G gold: sword 2, …"
  (`itemCrafted`), "stones made: N for G gold: mithril 2, …" (`stoneCrafted`) and "items enhanced: N steps for G gold
  and mithril 3, starmetal 1; the step reached: +1 2, +2 1, …" (`itemEnhanced`'s `plus`, `stone`, `gold`; decisions-log
  255).
- "materials: D dropped, U used in crafts, S sold to a Shop, B bought from one; most dropped: …": the waves'
  `materials` and `materialsUsed`, and the Shops' material events.
- The Tavern (decisions-log 268), when a Town left carried its `tavern`: "tavern: V visits, B boosts bought (x a visit),
  R rerolls for G gold, T gold in all; L leaks forgiven" (the `townLeft`s' `tavern`, the `tavernRerolled` events, the
  waves' `boostSaved`, in records before `telemetryVersion` 16: Watchman's Brew went in decisions-log 329); "tavern by Town (wave won before it: visits, bought, gold): 7: 3, 2, 300, …" (by the
  `townLeft`'s `wave`: what each Town's Tavern sold as the run goes on); "tavern kinds (bought / offered): feast 4/9,
  ale 1/6, …" (each kind bought against offered, the visits' last rolls, most offered first).

Then how the games ended. `python3 tool/test_telemetry_summary.py` (stdlib) checks those lines on a made-up file: a
run with the Towns on (the Tavern's buy, reroll and forgiven leak too) and one with them off, whose store buy stays out
of the Town Shop's.
