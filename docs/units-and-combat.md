# Units and combat

Purpose: troop and monster stats, attacks, waves and the boss.

## Stats (`Stats` in lib/game.dart)

| Field | Meaning |
|---|---|
| `hp`, `cost` | Health, and base price (a troop costs `Game.priceOf(type)`, which its type's items and awakening raise: loot-items-relics.md; for monsters: the gold their kill pays, the type's base × its tier's gold grown with the wave, `killGold`, set by `enemyStats`). A troop's HP rises only through awakening (`awakenHp`), never through items. |
| `def` | Defence: taken off every blow the unit takes (`hitTaken`, below). Troops get it from shields; monsters have none of their own and gain it with the wave (`waveDef`, below). |
| `mp`, `mpRegen` | The most MP it holds and the MP back per second (0: it has none); what a unit has now is `Unit.mp`. The necromancers spend theirs on summons and heals (below), the troops on their skills (below), and a troop healer on its heals too (`healMp` 6 a heal, "Healers" below; decisions-log 297). Every troop type has MP, full at the start of a wave: soldier, knight, lancer, armored_axeman 20 (+1/s); swordsman, archer 30 (+1.5); knight_templar 40 (+2); priest 60 (+3); wizard 80 (+4). Awakening raises a troop's (`awakenMp`), and so do a Hero and its aura (Heroes, below); the other monsters have none. |
| `speed` | Units per second. A troop walks at most `walkMost` 6 × its type's base `speed`, whatever raises the stat (`walkCap`, `Unit.walkSpeed`: "The walk cap", below). |
| `dmg` | Damage per attack; for healers, the HP restored (a healer's potions add `potionHeal` each, its staffs `staffHeal`; the wizard's staffs multiply its damage by `staffDmg`). |
| `range` | Reach. A melee troop's never goes past `meleeMaxRange` 27.2 (1.7 tiles), whatever bows its type takes; with the forge on, spears raise its type's own cap (`reachCap`, at most 1.5 × that: loot-items-relics.md "The forge: the new kinds' effects"). |
| `rate` | Seconds between attacks. Whatever shortens it, no unit attacks faster than once every `minAttackInterval` 0.3 s (the wave's boss `bossMinAttackInterval` 0.2 s; Fighting rules, below). |
| `shotSpeed` | More than 0 means it fires projectiles (long range). |
| `splash` | Area radius. |
| `heals` | It's a healer. |
| `dark` | An undead monster: a troop healer's heal hurts it (holy damage, below). |
| `regen` | HP per second (only from potions). |
| `melee` (getter) | Neither shoots nor heals: the front and heavy melee. |

Troops, cheapest first (the order of the troop cards), from `troopTypes`:

| Key | Role | Notes |
|---|---|---|
| soldier | front melee | cheapest |
| knight | front melee | |
| swordsman | front melee | the owner calls it the "berserk"; 140 HP (110 until decisions-log 318: it fell ten times as often as a knight) |
| archer | long range | arrows |
| lancer | heavy melee | the owner calls it the "cavalry" |
| priest | healer | range 96 reaches past the long range; the free healer every game starts with |
| armored_axeman | heavy melee | splash cleave; buffed (below) |
| wizard | long range | splash shot, a fireball ("The wizard's magic") |
| knight_templar | heavy melee | the owner calls it the "spear knight"; tankiest; buffed (below) |

**The heavies' buff** (#57; the owner: they lag behind the light melee and die first, "jadi mereka seperti
last hope"): the `heavyTypes` (the axeman and the templar) fight with `heavyBuff` 20% more HP, attack and
defence than their table (`Game.statsOf`, after items and awakening, so their shields' defence rises too;
their base defence is 0). Speed, reach, rate, splash, price and MP stay. The book shows the raised numbers. The probe behind the 20% is in decision 113.

Their names on screen (`troopTypeNames`, e.g. the troop counter's list): Soldier, Knight, Swordsman,
Archer, Lancer, Priest, Axeman, Wizard, Templar (in the table's order; ui-hud.md "In-game text").

**Army size:** at most `Game.capacity` troops alive at once (6 at the start, the free healer counted;
"+Room" adds 2). A troop bought over it is refused (camera-and-field.md).

**The owner's limits** (decisions-log 141, 201, 260): the board turns on two switches (`Game.boardRules`); a plain `Game()`
has neither, so tests and probes play as before (`armyMax`, `typeCap` null).
- **At most 36 alive** (`armyMax` = `armyMaxBoard` 36; 32 until decisions-log 260, the owner on 2026-10-07: "yang mana
  batas atasnya harusnya memang 36"): `armyCap` = min(`capacity`, `armyMax`), `full` = alive ≥ `armyCap`, and
  capacity can't be bought past 36 (`maxCapacity`), at every screen size (camera-and-field.md: a narrow view's zone
  grows to hold it). Nobody is cut: a save with 48 alive keeps all 48 and its capacity 48, and buys wait until 35 or
  fewer are alive; but since decisions-log 162 its tide counts from
  earlier for each troop over the cap ("Beban", in "The tide" below). Resurrection's "the army is under its cap" is
  the same `full`.
- **At most a cap of each type alive** (`typeCap` = `typeCapBoard`; decisions-log 201, the owner on 2026-10-03: "user
  tidak bisa beli lebih dari 5 priest, tidak bisa beli 20 archer supaya game tetap balance"). It replaced the roster of
  4 types a run (decisions-log 141), which had read the owner's words as a limit on the types in the army.

  | Type | Cap | Why |
  |---|---|---|
  | priest | 5 | the healer: heals stack (17 priests made the owner's w86 army almost unkillable); 5 was one in six of 32, one in seven of 36 |
  | archer, wizard | 8 each | the long range: they hit from behind the line; both together are half the army |
  | soldier, knight, swordsman, lancer, armored_axeman, knight_templar | 10 each | the melee: the line itself |

  - No type fills the army alone, nor do three types; four do unless only one of them is melee (10 + 5 + 8 + 8 = 31).
    All nine caps add up to 81.
  - **What counts** (`aliveOf`): the type's troops alive now, its Heroes too (a Hero is a troop of its type; `heroMax`
    is its own limit). The fallen don't count, so a type a boss thinned is bought back up to its cap.
  - **Read in one place** (`Game.typeCapOf(type)`): the board's cap, or none while Oath of One works (its two types may
    fill the army: loot-items-relics.md "Legenda"). `typeFull(type)` = alive ≥ its cap; the rules, the Army page, the
    troop counter and the guide all read them.
  - **Nobody is cut:** a type over its cap (a save from before it: the owner's w86 save has priest 17, templar 13 and
    wizard 9 over theirs; axeman 6 and archer 3 under) keeps every troop until it falls; its buys wait until fewer than
    its cap are alive ("Priests full 17/5").
  - **No type is locked any more:** any type can join while the army has room. The roster `runTypes` is gone: no rule
    reads it, a save no longer writes it, and an older save's is ignored.
- **The one gate:** every buy goes through `place` (the Army page's price buttons, `autoPlace`, the rebuys), which asks
  `buyRefusal(type)`: first its type (`typeRefusal`: Oath of One's bar `oathOneBar` "Oath of One: only 2 types", or a
  full type "<Plural> full n/cap" from `troopTypePlurals`, the count as it is: "Priests full 5/5", "Axemen full
  10/10", "Priests full 17/5"), then a full army "Army full 36/36" at the cap (alive/cap: "48/36") or
  `buyRefusals.full` "No room" under it (under Oath of the Few with the board's cap, 24 alive under the cap:
  `fewOathBar` "Oath of the Few: up to 24 troops", its `armyLocked` part of `full`), then too poor `buyRefusals.gold`
  "Not enough gold".
- **Resurrection and the rebuys keep to it:** Resurrection's troop (`_revivable`) is the last fallen of a type that may
  take one more (`typeRefusal` null), so a priest at 5 stays down and an earlier fallen of another type rises instead
  (Phoenix Plume's rise asks the same, `_fxRise`: at a full type its troop stays down);
  "Replace fallen" goes through `place` (its refusal "Priests full 5/5"). Hero Gugur's recall swaps at a full type
  as at a full army ("Hero Gugur" below).
- **Lepas jenis** (`releaseType(type)`): sends a type's living troops home between waves (off the field, not fallen),
  each paying back `releaseRefund` 0.5 × `priceOf(type)` (`releaseRefundOf`), and their relics go back to the bag. It
  stays a tool under the caps: room for other types under 36, a type over its cap traded in whole, Oath of One's way
  down to two types. `whyNotRelease(type)` refuses (null, `Sfx.error`, nothing changes): `assignRefusals.over`,
  `takeOffRefusals.midWave` "Only between waves", `releaseRefusals.none` "Not a type in your army" (none of it alive),
  `releaseRefusals.hero` "A Hero can't be sent home" (a Hero of the type lives: Heroes are too rare to lose to a tap).
  It emits `TypeReleased` (telemetry.md). The type's bound Pusaka goes to the Gudang there, free (`PusakaMoved` to
  none; loot-items-relics.md "Pusaka", decisions-log 138).
- **The Auto hold** (`autoHeld`; qa-1: Auto began w86 5 s after a wave that left 20 of 48): with `armyMax` on,
  Auto's countdown waits while fewer than `autoHoldShare` 0.75 × `armyCap` are alive (ui-hud.md, "Start/Pause toggle"). Under
  the caps, at the cap 36 (27 to hold), an army of three types stays under 27 unless two of them are melee and none is
  the healer (10 + 10 + 8 = 28; 10 + 8 + 8 = 26 and 10 + 10 + 5 = 25 don't), and is held every wave until a fourth
  type joins or the player presses Start (decisions-log 201 leaves the hold as it was; at 32, 24 to hold, only the
  three with one melee were, 5 + 8 + 10 = 23).
- **One-time notes** (`limitNotes()`, the saved `notes` set): a save over the cap (capacity or alive) is told
  "The army cap is now 36. You keep your troops; buy more when under 36." (key `army`), one with more alive than the cap
  "Army cap 36. Each troop over it: Tide +2 waves" (`over`, `overNote`, decisions-log 162), one with types alive over
  their caps (`overCaps`) "Each troop type has a cap now. You keep yours; over it: Priest 17/5, Wizard 9/8, Templar
  13/10. Buy more of a type when under its cap." (`caps`, `capsNote`, three types a line), each once, in one message
  window, which fits a phone (`test/cap_warning_hud_test.dart`). An older save's `types` key (the roster's note) stays
  in `notes`, unread.

**Every troop has its own name** (`Unit.name`, decisions-log 41): a first and a last name, e.g. "Kira
Thorn". It is shown on the field's nameplate and in messages about that troop (ui-hud.md).
- The names come from `firstNames` × `lastNames` in lib/names.dart: 48 × 48, short, plain ASCII (the
  old pixel font had no accents; the game's font has them, decisions-log 158, but the names stay as they are).
- `troopName(dice, taken)` draws one no living troop has, so two living troops never share a name. A
  fallen troop's name is free again.
- It is given in `_newTroop`, so every placed troop gets one, the free healer too. `Game.names` is its
  own dice (`Game([rng, names])`, `Game.fromJson(j, [rng, names])`), like `loot`, so names never shift
  the spawn sequence or the drops.
- It is saved per troop (`'name'` in `toJson`). A troop loaded from an older save without one gets a
  new one.
- Monsters have no name (`''`).

Monsters, from `enemyTypes`, weakest first:
slime, bat, skeleton, orc, skeleton_archer (shoots), werewolf, armored_skeleton, orc_rider, elite_orc,
armored_orc, greatsword_skeleton, werebear.

The undead are **dark** (`Stats.dark`, decisions-log 59): skeleton, skeleton_archer, armored_skeleton,
greatsword_skeleton and both necromancers, so every skeleton a necromancer raises too. The bat, werewolf and
werebear are living beasts, not dark; neither are the slime and the orcs.

Two necromancers, outside `enemyTypes` (never rolled into a wave's pool):

| Key | Stats | Role |
|---|---|---|
| `necromancer` (`boss`) | `bossStats`, MP by its tier (`necroMp`) | The summoner: the boss, and sometimes the mini boss; from wave 50 a high elite one in every escort (#90, "Waves"). It spends MP raising skeletons (below). |
| `necro_healer` (`necroHealer`, "Necro Healer") | `necroHealerStats`: hp 70, gold 12, speed 16, heals `dmg` 8 every `rate` 1.2 s within `range` 64, `mp` 40 (full on arrival), `mpRegen` 3.2/s | The support: stays at the very back and heals monsters for `necroHealCost` 8 MP a heal. It swings its scythe only when it can't heal (below). Drawn as the necromancer with a teal robe and gold hood (assets.md). |

For comparison, the priest heals 12 every 1.2 s (10 HP/s) within 96, with hp 60, for `healMp` 6 of its MP (60,
+3/s) a heal (decisions-log 297), the healing necromancer's way; its MP also pays its skills (Healing Prayer, below).

A monster's stats come from `enemyStats(type, tier, wave, raised:, tideStart:)`:

- **Wave** (w = wave−1; every attribute grows on the type's base, decisions-log 32):
  - HP and damage (`waveGrowth`, no cap): through wave `waveLateFrom` 15 every wave adds `waveHp` 0.17 of
    the base HP (0.15 until decisions-log 318) and `waveDmg` 0.06 of the base damage; from wave 16 on every wave adds
    `waveHpLate` 0.30 and `waveDmgLate` 0.10 instead (decisions-log 72, the owner's pick in #36). So HP is ×3.38 at
    wave 15, ×3.68 at 16, ×7.88 at 30 and ×10.88 at 40 (×3.1, 3.4, 7.6 and 10.6 at 0.15; before #36 ×5.35 and
    ×6.85); damage ×1.84, ×1.94, ×3.34, ×4.34 (it was ×2.74 and ×3.34). A healer's heal is its damage, so it grows the same way (and with its tier's
    Dmg).
  - Why: on main 91ac392 (Heroes, skills) an auto-player cleared every wave to 40 losing 0.6 troops a
    wave. With this curve, 16 of 18 runs clear wave 40, 2 fall at waves 27 and 30, and troops fall every
    late wave (1.4 a wave in waves 10–30).
  - Walking speed ×(1 + `waveSpeed` 0.02·w), +50% by wave 26 (`waveSpeedMax`).
  - Attacks per second ×(1 + `waveRate` 0.01·w), +25% by wave 26 (`waveRateMax`). `rate` is the pause,
    so it is divided by that. At 0.02 (cap +50%) a probe found waves 15–25 needed ~25–30% more troops.
  - Long range reach (`shotSpeed` > 0) ×(1 + `waveRange` 0.01·w), +25% by wave 26 (`waveRangeMax`).
    Melee reach never grows, nor a healer's (`necro_healer` doesn't shoot); its heals come faster though.
  - After wave `waveTempoTo` 26 all three keep growing (#71, decisions-log 90; `tempoGrowth`): `waveSpeedLate`,
    `waveRateLate` and `waveRangeLate` 0.005 more a wave, walking up to +75% in all (`waveSpeedMost`, wave
    76) and reach up to +50% (`waveRangeMost`, wave 76). Attacks have no cap of their own: the attack floor
    (Fighting rules) is the only limit. At wave 40 an orc walks +57% and attacks 32% more often.
  - Defence (#71): from wave 16 (after `waveLateFrom`) every monster gains `waveDef` 0.05 a wave
    (`waveDefence`), taken off every blow like a shield's: 0.5 at wave 25, 1.25 at 40, 3.25 at 80. It
    matters most to troops that deal many small blows (an archer's 9, a soldier's 10); `hitTaken`'s floor
    still lets every blow do at least 10% of itself.
  - Regen, splash, shot speed and MP don't grow. The necromancers' MP stays too, because the minions they buy
    already grow with the wave at the same MP price. The kill gold grows by its own rule (`killGold`, Tier below).
  - From wave 35 the tide multiplies HP and damage again, for every monster but the wave's boss and mini boss
    ("Waves", "The tide").
  - What it does to the troops: from wave 8 a skeleton archer outreaches an archer without a bow (64),
    and from wave 22 a wizard without one (72). A slime or orc (18) outwalks an archer without boots (22) from
    wave 13 and a skeleton (20) from wave 7, so the archers' kite no longer gets away from them.
- **Tier** (`Tier`): any type can hold any rank (#58). The same sprite, recoloured part way toward the
  rank's colour and outlined in it (ui-hud.md), and the HP bar in that colour. Gold is `Tier.reward` on the
  type's base `cost`, grown with the wave (below), paid in `_hurt`:

| Tier | HP | Dmg | Speed | Gold | HP bar |
|---|---|---|---|---|---|
| normal | ×1 | ×1 | ×1 | ×1 | red |
| elite | ×1.8 | ×1.3 | ×1.05 | ×1.5 | silver (blue before #62: blue means MP) |
| highElite | ×3 | ×1.7 | ×1.1 | ×2 | gold |
| miniBoss | ×6 | ×2.2 | ×1 | ×3 | purple |
| boss | see below | | ×1 | ×4 (the necromancer 160 before growth: 190 in wave 5) | orange |

- **Kill gold** (#83, decisions-log 119): `killGold(cost, tier, wave)` = the type's base `cost` × `Tier.reward`
  × (1 + `killGoldGrowth`)^(wave − 1), **floored once** at the end (not wave by wave: a slime's 3 would
  otherwise stay 3 forever; floored once it is 4 from wave 8 and 6 at wave 20). Wave 0 pays like wave 1.
  - `killGoldGrowth` 0.045 (decisions-log 318; the owner's start was 0.05, meant to be tuned: they asked for 30%,
    which is ×146 at wave 20). At 4.5% the growth is ×1.19 at wave 5, ×1.49 at 10, ×1.85 at 15, ×2.31 at 20, ×3.58
    at 30, ×5.57 at 40, ×8.64 at 50 and ×32 at 80 (×47 at 5%: with the troops' prices flat, every rebuy was free past
    wave 80): a werebear pays 20, 29 at wave 10, 46 at 20, 172 at 50.
  - `enemyStats` sets it as `Stats.cost` when the monster is made, with the wave it comes in. Everything that
    pays or shows kill gold reads that one number: the kill in `_hurt`, Plunder's bonus and its "+N" (Heroes),
    a hexed slime's own gold (Slime Hex), the telemetry's `gold.earned`.
  - The necromancers follow the ranks like any type (boss ×4, mini boss ×3, an escort's high elite ×2 on their
    40; the healer's 12 by its rank). Raised minions (skeletons, Swarm's bats, Split's slimes, Grave Call's
    risen) still pay 0.
  - Unchanged: the win's `waveBonus` and the score (`killScore` by rank); neither reads `Tier.reward`.

A boss or mini boss of a monster type starts from its slot's reference (`slotBase`), not its own stats:
its HP and its damage are raised to at least the reference's, the damage so it hits as hard a second at
its own pace (`rate`). Its speed, reach and shots stay its own, so a bat boss is quick and a skeleton
archer boss shoots from afar. Then:

- **Mini boss:** the reference is the wave's strongest type (the last of its pool, `poolOf`), then the
  tier's ×6 HP / ×2.2 damage. So the strongest type in its own slot is what the mini boss always was, and
  a weaker one comes up to it (never down: a type stronger than the reference keeps its own).
- **Boss:** the reference is the necromancer boss (`bossStats`: 600 HP, 30 damage every 1.5 s), times
  `bossTypeHp` 1 HP and `bossTypeDmg` 0.65 damage: 600 HP and 13 damage a second before the wave's growth.
  It raises no skeletons (only the necromancer does) and has no MP. Why 0.65: at the necromancer's full
  damage a second such a boss killed twice the troops of a necromancer boss, which spends much of the fight
  casting; at 0.65 about as many (decisions-log 91).
- **The necromancer** keeps its own stats as the boss (×1: it is already a boss). In the mini boss slot it has
  the HP of any mini boss (#89, decisions-log 126): the slot's reference (the wave's strongest type, not its
  own 600) × the tier's 6, what a mini boss of the wave's strongest type has. That is 240 on waves 8–9 (the
  skeleton archer's 40), 900 on wave 12, 1,320 on 21 and 1,920 from 22 (the werebear's), before the boss buff
  and the wave. Its damage stays its own × `necroMiniDmg` 0.6 (instead of the tier's ×2.2), and it pays the
  mini boss gold, ×3 (120). Until #89 its HP was 0.4 of its own (240 on every wave): on wave 48 its bar
  showed ×19 against a werebear mini boss's ×145. With that HP it and a necromancer boss on one wave were
  too much at first (decisions-log 140 turned the pair off); on today's game the pair is the milder wave, so it comes
  again (decisions-log 165, "Waves").
- **The high-elite necromancer** (an escort's summoner from wave 50, #90, decisions-log 127; "Waves") isn't a
  slot. It starts from the same reference as the mini boss, the wave's strongest type's HP (not its own 600),
  times the tier's ×3, and has `necroMiniDmg` × 1.7 / 2.2 (≈ 0.46) of its own damage: the mini boss's damage
  share, scaled by the two tiers' damage. Its speed is ×1.1 like any high elite's, and it gets no boss buff
  (high elites get none). So it has a high-elite werebear's HP: wave 50 13,325 HP and 74 damage every 1.5 s;
  wave 60 16,205 and 88. Its gold, score and relic chance are a high elite's: 40 × 2, grown with the wave (691
  at wave 50), 50 points and 5% (a roll that drops nothing since the Towns, decisions-log 237, 321: its Dark Gem at
  35% instead, loot-items-relics.md "Town and Smithy: materials"). Like any high elite it casts its type's signature, Curse of Frailty (1.15×, not
  a mini boss's 1.2×; "Monster skills"), and neither Soul Drain nor Death Nova.
- A necromancer's raised minions are never raised to a slot (`enemyStats(…, raised: true)`): a raised mini
  boss skeleton is a skeleton ×6 / ×2.2.

**The boss buff** (#66, `bossBuff(tier, wave)`, decisions-log 97) comes on top of all that (the slot's start,
the tier) and of the wave growth:
- In full, a wave's boss, of any type (#58), has `bossHpK` 10 × its HP, `bossMpK` 5 × its MP pool and
  `bossDmgK` 3 × its damage.
- Its mini boss, of any type, has `miniHpK` 6 × its HP, `miniMpK` 3 × its MP pool and `miniDmgK` 1.5 × its
  damage (×2 until the owner softened it, #75). So a full-buff mini boss has ×36 its type's HP and ×3.3 its
  damage.
- It ramps in with the wave: none up to `bossBuffFrom` (wave 5), in full from `bossBuffFull` (wave 60; 50 until
  decisions-log 318), in a straight line between (each multiplier is 1 + (full − 1) × the share of the way). The boss's
  HP is ×1.82 on wave 10, ×3.45 on 20, ×5.09 on 30, ×6.73 on 40, ×8.36 on 50. The MP pool is rounded.
- The necromancer in full, before wave growth: as the boss 6000 HP, 90 damage and 1200 MP; as the mini boss
  (from wave 22) 11,520 HP like any mini boss (1,440 before #89), 27 damage and 360 MP. Another type's boss
  in full: 6000 HP and 39 damage a second (13 × 3), no MP.
- MP comes back as fast as before, so a summoner opens every wave with up to 5× (3×) the MP but earns it no
  faster.
- A necromancer's raised minions don't get the buff (`enemyStats(..., raised: true)`): their MP price
  (`summonCost`) stays balanced against their strength.
- Gold and score are unchanged.

## Waves (`startWave`)

- A wave starts only while `canStartWave`: no wave on and not `over` (the Start/Pause toggle's Start, ui-hud.md).
- Wave n spawns `4 + 2n` monsters, drawn from the first `1 + n/2` types.
- One monster every `spawnGap` 0.9s, shorter from the tide's first wave (`spawnGapOf`, "The tide" below), while the
  field holds the spawn floor's monsters (below).
- **The spawn floor** (decisions-log 225; the owner, 2026-10-04: "minimal jumlah enemy di field adalah jumlah
  troops/8"): while the wave's `queue` still holds monsters, at least `spawnFloor` monsters are alive on the field.
  - `spawnFloor` = `spawnFloorOf(living troops)` = living troops / `spawnFloorPer` 8, rounded up: 0 with no troop, 1
    with 1-8, 2 with 9-16, 5 with 33, 6 with 48. Heroes count, the fallen don't.
  - Every living monster counts toward it, a raised minion too (it keeps the wave on, like every monster); a dying one
    doesn't.
  - Below it (`belowSpawnFloor`), `tick` skips the timer and brings the queue's next monster on at once, one a tick
    at most, at the usual spawn point in a random lane. Every spawn starts the gap afresh, so once the floor is met
    the timer runs again from the spawn that met it (`spawnGapOf(wave, wavePaceFrom)`, the tide's pace included).
  - So a wave's first monsters come one a tick up to the floor (48 troops: six in 0.2 s at 30 ticks a second, not
    over 4.5 s), and a field emptied early gets its next monster on the next tick, not after the gap.
  - Only when they come on moves: the queue's order, the mini boss and boss slots and their escorts, the Guard
    Bayangan's places, Lewati's skip buff (the first share by spawn order) and the Town are as before.
- They spawn at `spawnX` in a random lane: `spawnLead` 2 tiles past the view's right edge (+8), never less than
  `spawnClear` 4 tiles ahead of the foremost troop (camera-and-field.md).
- `queue` holds `(type, Tier)`. Each monster rolls its tier: high elite at
  `highEliteChance` = 0.03·(wave−6) (max 0.2), elite at `eliteChance` = 0.05·(wave−2) (max 0.35).
- Every `miniBossEvery` 3rd wave (3, 6, 9, 12…) adds a mini boss: from `necroMiniFrom` (wave 8, so from
  wave 9 in practice) at `necroMiniChance` 1/3 the necromancer (an `rng` roll, as before), else any type
  of the wave's pool (`slotType`: the n-th weakest n times as likely as the weakest, so the stronger come
  more often; #58, it was always the strongest). The wave's mini boss always drops 1 item.
- Every `bossEvery` 5th wave adds the boss: from `necroBossFrom` (wave 10) the necromancer at `necroBossChance` 1/3,
  else any type of the pool the same way (#58; it was always the necromancer). Waves 15, 30… bring both, the mini
  boss first, then the boss (and on a boss wave the last healer behind it).
- **No necromancer boss before wave 10** (decisions-log 176): wave 5's boss is always a type of the pool. With the
  necromancer at 1/3 from wave 5, 13 of 40 new games met it at wave 5, and a 5-troop opening (a soldier, 3 knights,
  the free Priest, cap 6) lost all 13 while winning the other 27. The die is the same: the boss's roll is still
  drawn, and under 1/3 before `necroBossFrom` its type is `slotType(pool, roll / necroBossChance)`, the roll scaled
  back to 0–1 (the pair rule's way, below), at any boss's odds; at or over 1/3 the second draw picks the type as
  before. No die draws more, so the rest of wave 5, every later wave's queue and every saved wave's replay from wave 5
  on are built as before; only that boss's type differs.
- **The necromancer as both mini boss and boss** (decisions-log 165, amending 140; `Game.necroPairAllowed` true): a
  wave whose boss is the necromancer has a necromancer mini boss too when the mini boss drew it, ~1/9 of the waves
  with both, rolled as on main before 140. 140 had turned that pair off (qa-2 on 9ae979c: from wave 61, 24 troops fell
  a wave instead of 12). Measured again on today's game (escorts, the tide, Pusaka, 57be560), the moved mini
  boss made those waves harder, not easier (w30 +12.9 and w60 +10.7 troops fell, game overs only without the pair),
  because it is any type at the stronger-likelier odds (a werebear, a greatsword skeleton, an armored orc), while a
  pair's necromancer mini boss dies in ~52 s. **The switch stays** for a probe or a later change: off, 140's rule
  holds. The mini boss rolls first, so when the boss then draws the necromancer, a mini boss that drew it too takes a
  type of the pool instead: `slotType(pool, roll / necroMiniChance)`, its own necromancer roll (under 1/3) scaled back
  to 0–1, any mini boss's odds. No die draws more either way: the boss, the escorts' ranks, the rest of the wave,
  later waves and saved-wave replays are the same with the switch on or off (only that mini boss's type differs). A
  necromancer mini boss comes on every other wave at its 1/3 either way, and on a wave with both whose boss is another
  type.
- The slots' types come from their own dice (`Game.slots`), so the rest of a wave (every rolled monster
  and healer) is the same whatever they draw.
- On top of those, `necroHealersIn(n)` healing necromancers (#70, decisions-log 98): none before
  `necroHealerFrom` (wave 4), one until `twoNecroHealersFrom` (wave 6), then two, and one more every
  `necroHealerEvery` 5 waves up to `necroHealersMax` 5 (wave 11: 3, 16: 4, 21 on: 5). Each rolls its tier
  like the rest. They are put in the queue after the first third (and the second third) of the rolled
  monsters, so there is a front to stand behind; more than two are spread evenly (after each quarter,
  fifth…). On a boss wave the last one comes right after the boss (from wave 50 after the boss's escort), and
  the rest spread. The mini boss stays last (from wave 50 followed by its escort).
- **The escort** (the owner's #90, decisions-log 127: "wave 50+ miniboss dan bossnya di backup 3 necromencer
  penyembuh biar ada perlawanan dan 1 necromencer pemanggil level high elite"):
  - From `escortFrom` (wave 50), every mini boss and boss comes with `escortHealers` 3 healing necromancers and
    `escortSummoners` 1 necromancer of rank `escortSummonerTier` (high elite, above). They are queued right behind
    it in that order, on top of the wave's own healers. The constants are the orchestrator's defaults; the owner
    may change them.
  - A wave with both slots (60, 75, 90…) has two escorts: the mini boss, its escort, the boss, its escort, then
    the wave's last healer.
  - The escort's healers roll the usual ranks, from the slots' dice (`Game.slots`) and after the slots' own
    rolls, so the rest of the wave is the same as without them.
  - As they come on (`tick`), the escort-shaped monsters (a healing necromancer, or a high-elite necromancer) that
    come right after a mini boss or boss, up to four, are its escort (`Unit.escortOf`). The escort is the same
    whatever the slot is, the necromancer too.
  - What its healers do: "The healer" below. The high-elite necromancer fights and raises minions like any
    summoner; it has no name and no boss bar (ui-hud.md).
- The wave's mini boss and boss get a name as they come (`bossName`: one of `bossNames` with the names'
  dice, never one already on the field), shown with a title from their type on their boss bars
  (`bossBarName`, "Morgath the Summoner"; `bossTitles`; ui-hud.md "Boss bars"). Other monsters, and a
  mini boss a necromancer raises, have none.
- `waveSpawned` counts the queue's monsters that have come on this wave; `waveTotal` = that + what is
  left in `queue`. The healers (and the escorts) are in the queue, so they count; the boss's raised
  skeletons are not, so they don't. The wave meter shows them (ui-hud.md).
- Winning pays `waveBonus(n) = 20 + 10n` gold. Start: 150 gold, 6 lives (3 hearts, #79; it was 10).
- Kills and won waves also score points (`killScore` by tier, `waveScore`): scoreboard.md.

### The tide (on screen "Tide"; #92 part 1, decisions-log 142)

The owner (2026-09-30): "late game too easy", and the gold has no use, "tanpa artefak shop juga lawan masi bisa di
atasi dengan mudah". After wave ~26 the crowd stopped mattering; only the boss and mini boss slots bit, from ~66
(reports/late-game-design.md). So from wave `tideStart` the crowd grows on top of `waveGrowth`, compounding:

- **The numbers** (lib/game.dart beside `waveGrowth`; the design's defaults, the owner's decisions 1b, 2b, 3b, 4a;
  `tideHp` cut to 0.01 by decisions-log 161):
  - `tideFrom` 35: a new game's tide starts there (the issue: "too easy after wave ~35").
  - `tideHp` 0.01: HP × `tide(wave, tideHp, tideStart)` = 1.01^(wave − tideStart), 1 up to `tideStart`. It was
    0.015 until decisions-log 161 ("With the army cap" below).
  - `tideDmg` 0.005: damage (a healer's heal too) × 1.005^(wave − tideStart).
  - `tidePace` 0.005 and `tideGapMin` 0.5: the gap between two monsters coming on is `spawnGapOf(wave, tideStart)` =
    `spawnGap` × 0.995^(wave − tideStart), never under 0.5 s (the spawn timer in `tick`; below the spawn floor, "Waves"
    above, the next comes on at once).

  | Wave | HP × | Damage × | Spawn gap |
  |---|---|---|---|
  | 35 | 1.00 | 1.00 | 0.90 s |
  | 50 | 1.16 | 1.08 | 0.83 s |
  | 65 | 1.35 | 1.16 | 0.77 s |
  | 72 | 1.45 | 1.20 | 0.75 s |
  | 80 | 1.56 | 1.25 | 0.72 s |
  | 100 | 1.91 | 1.38 | 0.65 s |

  Wave 65's orc: HP 80 × 18.1 × 1.3478 = 1,952, damage 10 × 6.84 × 1.1614.
- **Who** (`tided(tier, raised:)`): every monster but the wave's own boss and mini boss (any type, the necromancer
  too: their slots already kill 3-11 troops at waves 69-70). So the normal, elite and high elite monsters, the
  healing necromancers (their heal), an escort's healers and high-elite summoner (#90), and every raised minion (a
  necromancer's, a skill's, a raised mini boss too) and a hexed monster's slime (Slime Hex). The wave-65 werebear
  mini boss keeps its 208,512 HP.
- **What stays:** kill gold, score, drops, speed, attack rate, reach, defence and MP.
- **`Game.tideStart`** is saved. A new game has `tideFrom`. A save from before the tide (no `tideStart`) catches up
  halfway: `tideStart` = max(`tideFrom`, its wave − `tideCatchUp` 20). The owner's wave-72 save counts from 52, so
  wave 73 meets HP ×1.23 (what a new game meets at 56), not ×1.46 at once. `tideCatchUp` 999 would be the full tide
  at once, 0 a start from the load. Such a save whose next wave already has the tide sets `Game.tideCaughtUp`, and
  the UI says so once (ui-hud.md).
- `enemyStats(…, tideStart:)` defaults to `tideFrom`; the game passes its own `waveTideFrom` (`tideStart`, earlier
  for an army over the cap: "Beban" below) wherever it makes a monster (`monster`, `_summon`, `_summonChoice`,
  `_bringIn`, Slime Hex), and the spawn timer reads `spawnGapOf(wave, wavePaceFrom)` (`waveTideFrom` while
  `overPace` is on, else `tideStart`).
- The HUD shows it on the wave meter, the "VICTORY!" popup announces it (ui-hud.md), and the telemetry records it
  (`start.tide`, telemetry.md).
- **With the army cap** (decisions-log 161, qa-4's finding). An army at the cap (36 since decisions-log 260; 32 when
  the measurements below were taken; "The owner's limits" above) can't
  answer the tide with more troops, only with stronger ones (Bangkit 4-5, the Pusaka), so the late game's rule is: the
  tide's pressure on an army that doesn't spend rises over ~10-15 waves, and the game says so before it bites.
  - The cliff it replaced: on the owner's w63 save (48 troops from before the cap, tide from 43) at `tideHp` 0.015 the
    army lost nobody until ~w73; the falls above the cap can't be bought back, so it shrank to 32 by w78-84, where the
    tide was already past what 32 can hold, and 3 of 6 runs ended in 2-3 waves. At 0.01 it shrinks later and slower,
    and no run ended by w90; the w86 save cut to 32 (a new game's army size) rises from 2.4 to 16.8 falls a wave over
    w87-105 with no game over.
  - Not met yet (the owner decides, decisions-log 161): with Bangkit 4-5 bought for every type, the same w63 army
    loses ~0.1 a wave, not the owner's 1-3: Bangkit 5 makes it ~3 times as strong as the army that doesn't spend.
  - The warning: `Game.capPressed` / `capWarning` (the message window every `capWarnEvery` 5 waves) and the wave
    meter tooltip's last line (`capTip`); ui-hud.md "Message window".
- **Beban, the over-cap tide** (decisions-log 162, amending 141's 3a; reports/late-economy-design.md §2.1, J1). An
  army alive over the cap (a save from before it: the owner's 48 over 32) used to keep its extra troops for free, and
  the tide never caught it until it had shrunk to 32. Now each troop over the cap brings a later wave's tide. The
  numbers below were measured at the cap of 32; over the board's 36 (decisions-log 260) the same 48 are 12 over, wave
  87's tide from 24 waves earlier (42: +56%):
  - **The count** (`Game.overBy`): s = max(0, living troops − `armyCap`) while `armyMax` is on (the board's
    `boardRules`); a plain `Game()` never counts.
  - **The rule** (`overTideWaves(s, wave, overFrom)`): the wave's tide counts from `waveTideFrom` = `tideStart` −
    round(min(`overTideMax` 60, `overTide` 2 × s) × min(1, (wave − `overFrom` + 1) / `overRamp` 5)). The owner's 16
    over: wave 87 meets the tide of 32 waves later at full strength, HP ×1.69 from 34 (+69%) instead of ×1.23 from 66
    (+23%).
  - **The ramp:** `Game.overFrom` is the first wave started over the cap, set then when missing and never cleared
    (saved as `overFrom`, only when set; null in a new game). It brings a fifth of the waves on that wave, all of them
    5 waves on: 16 over adds 6, 13, 19, 26, then 32.
  - **The pace too** (`overPace` true, as `overTide` 2 was measured): the spawn gap counts from the earlier wave as
    well (`Game.wavePaceFrom`). The switch stays for a later tune: off, the gap keeps counting from `tideStart`.
  - **Why 2, soft** (decisions-log 162; the owner's w86 save, buy-back only, 12 seeds): 2 is the only probed arm with
    no game over from 0 falls the wave before. With 3 or 4 the crowd piled up: at a tide from 42 on wave 95 it brought
    1.43× the base's crowd HP a second (HP ×1.69, a monster every 0.69 s instead of 0.78 s), 1 to 61 monsters on the
    field in 120 s with nobody falling, then the line broke in one wave (1 run in 6 at either). Moving HP and damage
    only (pace off) saved those runs but not a third. 2 loses 0.65 a wave over w87-96 against the design's 1-3: soft,
    by the owner's rule "too soft rather than a cliff".
  - **Not met on the w63 save** (decisions-log 162): there 2 loses 3 runs in 6 by w90 (the base loses none). Beban is
    off in each collapse: it brings the army down to 32 sooner (all 6 by w89), and the plain 32-troop army breaks
    over w80-90 (falls, rebuys, an empty bank). That is the 32-troop regime, not the over-cap tide. No player will
    reach that save again, but it is a known risk for new runs: an army at 32 that doesn't spend can't hold w80-90
    on the w63 economy (J2 and J3 are for that).
  - **Frozen for the wave** (`Game.waveOver`: `by` = s at its start, `waves`; not saved): counted at each `startWave`,
    after `wave++` and before the queue. Troops that fall in the wave change nothing until the next. Every reader in
    a wave uses `waveTideFrom`: `monster`, `_summon`, `_summonChoice`, `_bringIn` (boss_skills.dart), Slime Hex
    (hero_skills.dart) and `WaveStarted`'s `tide` (its `gap` from `wavePaceFrom`).
  - **The HUD reads the coming wave between waves** (`Game.shownOver` / `shownTideFrom`: in a wave the frozen one;
    between waves s as the army stands now, so a rebuy, a fall or a Lepas jenis shows at once): the wave meter's badge,
    its tooltip (`tideTip`: its lines from the earlier wave, "A monster every" from `tideStart` with `overPace` off, then
    "12 over the cap: Tide +24 waves", `overTip`), `capPressed` (the tide on)
    and `capWarning`'s percent. ui-hud.md "Wave meter".
  - **It limits itself:** each troop that falls over the cap gives 2 waves back, and Lepas jenis takes a type's
    troops home (the owner's templar 13 + archer 3 are the 16 over).
  - **An army at the cap or under it, so every new run, meets the tide exactly as before** (s = 0; no dice drawn;
    `test/tide_test.dart` plays a wave at the board's cap with it on and off). `tideRising` and `tideCaughtUp` (the tide's
    news) still read `tideStart`.
  - The one-time note `over` ("The owner's limits" above); the telemetry's `start.tide.over` (telemetry.md).

### Ganti yang gugur (buying the fallen back, #92 part 1)

The tide makes troops fall again, and gold goes on replacing them in one press instead of one drag each (11 at the
owner's wave 70).

- **What is offered** (`Game.toReplace`): when a wave is won, its fallen troops (`fallen`, so not those Resurrection
  or Phoenix Plume brought back), not the Heroes, each with its old spot moved up with the back line like the living troops'
  (`post`). It lasts until the next wave starts (`startWave` clears it). Saved (`toReplace`: type, x, y); none in
  older saves.
- **`replaceCost`**: what all of them cost now (`priceOf`).
- **`replaceFallen()`**: between waves only. It buys them back the cheapest first (ties in the order they fell),
  each through `place()`, so every buy rule applies (`buyRefusal`: a full type's "Priests full 5/5", "Army
  full 36/36", "No room", "Not enough gold"; "The owner's limits" above). Each goes to its old cell, or, when that is taken or out of the zone,
  wherever `autoPlace` puts it (which lines the army up again). Those it couldn't buy stay offered. It returns how
  many came back, of how many, and the first refusal met.
- **`whyNotReplace`**: "Game over", "Only between waves", or, when not one of them can be bought, the
  first one's refusal; null when at least one can.
- **`buyRefusal(type, {price, hero, swap})`** is the one buy gate (`place` refuses on it; Hero Gugur's recall too,
  below): its type (`typeRefusal`: at its cap, or barred by Oath of One), the army at its cap (`full`; both skipped
  with `swap`, a recall into a full army or type that sends a troop of its type home for the Hero), for a Hero 5
  Heroes alive, then the gold against `price` (a troop's `priceOf` unless given) (decisions-log 141, 201, "The owner's
  limits" above). Lepas jenis takes the released
  type's fallen out of `toReplace`, so the button never brings a released type back.
- The button is in the book's Army page's footer (ui-hud.md "Army").

### Bayangan on the field (catalog step 0d, decisions-log 188)

What the enemy's Bayangan levels (loot-items-relics.md "Bayangan") do to a wave, in `lib/omen.dart`. Each kind's
strength is `omenK(kind)` = its per-E share × E, at most its most (`OmenKind.k`), where E = its level × the Beban
factor (`omenE`); the kinds' data is `lib/omen_catalog.dart`. Everything here acts while `omensOn` is on, as in every
build since decisions-log 319; off (`--dart-define=OMENS=false`, tests), a monster's stats are exactly `enemyStats`'s,
no guard joins a queue, no skip buff lands and a blow is what it was. A **slot** is the wave's boss or mini boss, not one
a necromancer or a skill raised.

- **Every monster's stats** come from one wrapper, `spawnStats(type, tier, {raised, skipBuff})`: `enemyStats` with the
  wave's tide (`waveTideFrom`), then `_omenStats` (Haste, Mend, the skip buff, Dark Hymn, Bone Arrows, Old Bones and Hardy). Its six callers: the queue's spawn (`monster`), the necromancer's
  raised minions (`_summon`) and `decideSummon`'s count of them (the two match), a skill's bring-in (`_bringIn`: Split,
  Swarm, Grave Call), Slime Hex's form (it keeps a skip buff the monster had), and the boss's blow the Dragon Crown
  tooltip counts (`bossBlowsLived`, another wave's, `at` and `tideStart`).
- **Armor** (`_hurt`, after the target's defence and its `struck` Fx, inside the taken floor below): a troop's blow on
  a monster, any blow with a troop as `by` (a smite, a skill, a leap, a bleed with a living source, Parry's answer), is
  ×(1 − 0.05 E), at most 0.4 off; a slot's E is × `omenSlotShare` 1. A monster's blow on a troop is never cut, nor a hit
  with no `by` (worn thorns, reflect).
- **Haste** (`_omenStats`): a monster's attack pause `rate` ÷ (1 + 0.05 E), at most ÷1.4; a slot's E × `omenSlotShare`.
  `attackEvery`'s floors stay (0.3 s, the boss 0.2 s). A healing necromancer's heals come faster too.
- **Mend** (`_omenStats`): `regen` of 0.003 E of its max HP a second, at most 0.024; never a slot's (a raised mini boss
  is no slot). It heals through `_healUnit` like any regen (the monsters' funnel, `MonsterHeal.regen`: none under
  `noHeal`), so not while stunned, casting, summoning, a heap, carried or marching.
- **Thorns** (`_hurt`, after the HP change, beside worn thorns): a melee troop (`stats.melee`) that hit a monster takes
  0.03 E of the blow back (at most 0.24), at most `omenThornsCap` 5% of its max HP a blow, with no attacker
  (`_omenThorns`, a `Hit.hitBack`): nothing answers it, so it never bounces. It goes through the troop's own defence,
  guard, Iron Banner, Dragon Crown and ward. A ranged troop or a healer takes none.
- **Wound** (the heal funnel, `_healTroop`, "Fighting rules" below): a troop's heal in a wave × (1 − 0.06 E), at most half off.
- **Shield** (`_omenSpawn`, as a slot comes on): `Unit.shield`, 0.05 E of its max HP (at most 0.4). In `_hurt` it soaks
  a blow after every cut, next to a troop's ward (`_shieldSoak`), before the HP. It is its own field, not
  `Status.absorb`, so Unholy Ward still lands on it and Spellbreaker can't strip it. Cleared at the wave's end
  (`_endEffects`). Raised monsters and the hex's form get none. Seen (ui-hud.md "Shadows"): Unholy Ward's teal ring at
  its feet and a teal segment on its boss bar while it holds.
- **Guard** (`_omenQueue`, once `startWave` made the queue): each slot brings `omenGuards` high elites of the pool's
  strongest type (`poolOf(wave).last`), ⌈0.5 L⌉ by its level L (1, 1, 2, 2), right behind its escort (from wave 50;
  before it right behind the slot), so the #90 escort's link holds. They are queue entries like any: tided, counted in
  `waveTotal`, casting their signature, paying gold, dropping loot, watched by the stall watch. Their places in the wave
  are marked (`_guardsAt`, by `waveSpawned`): one comes on its slot's row (`_guarded`) with no row drawn, and nothing
  here draws a die, so `rng` and `slots` stay paired with the wave without them. `Unit.guardOf` is its slot. On a boss
  wave the wave's last healer comes after the boss's guards.
- **Lewati's skip buff** (the owner's rule, catalog-design §4.4): a wave that owes it (`waveSkipBuff`) gives its first
  `skipBuffShare` 0.3 of the queue by spawn order, rounded and guards included (`Game.skipBuffN`, counted at its
  start), +`skipBuffK` 0.10 to HP, damage, attack speed (the pause ÷1.1, the floors kept) and walk speed
  (`Unit.skipBuffed`). That wave only, with no die; the spawn gap is untouched, so the faster first ones pull ahead.

**The first ten Langka kinds** (batch L-1B, decisions-log 204; in the Langka pool alone). Each share is `omenK` =
min(max, per E × E), as above:

- **Brace, Stubborn, Bear Hide, Hard Shell** (`_omenTaken`, at Armor's site, inside the taken floor below): a troop's
  blow on a monster (any blow with a troop as `by`, as Armor's) is ×(1 − share) when the monster, as the blow finds it,
  is over `omenBraceAbove` 90% of its max HP (Brace: 0.05 E, at most 0.3), under `omenStubbornBelow` 30% (Stubborn:
  0.06 E, at most 0.3), a werebear (Bear Hide: 0.06 E, at most 0.4), or holds a shield (Hard Shell: 0.05 E, at most
  0.3). A shield is `shielded(u)` (pusaka_engine.dart, the test the Pusaka condition `foeShielded` reads too: Shell Cracker): an
  absorb (a skill's or a Bayangan's), a shot ward, a Barrier (`Unit.shield`) or any live guard. A monster's blow on a
  troop is never cut.
- **Sunder** (troop-side; `_omenSunder`): every cut a troop takes less by keeps 1 − 0.08 E of its strength (at most
  half off): the small relic Guard's (`guardCut` × it), a skill's guard on a troop (Hold Fast, Holy Shield, Iron Skin,
  Holy Taunt's, Skyfall's: `Unit.guardCut` × it) and a Pusaka's `struck` cut (Iron Banner, Steady Stance, Turtle Shell, in `_fxStruck`; its counter
  counts the smaller cut). A monster's guard, defence, a cap, a block, an absorb and a duel's cut are untouched.
- **Unshaken** (`_omenUnshaken`): what a troop puts on a monster ends sooner, × (1 − 0.1 E), at most half: a slow, a
  pin (`Status.impaled`), a taunt and a weaken through the duration scaler (`_effectTime`, `addEffect`), a stun in
  `_stunFor` (after a mini boss's half) and Slime Hex's form. Each lasts at least `effectTimeFloor` 0.3 s, or its own
  time when that is shorter (a frost field's linger). A monster's buff and what a monster puts on a troop are untouched.
- **Quick Spells** (`_skillCooldown`): a high elite's skill cooldown × (1 − 0.05 E), at most 0.3 off. `_firstCast`
  and `_skillReady` both read it, so its first cast comes when it would have, 2 to 5 s after it comes on, and every
  later one sooner. The boss's and the mini boss's skills are untouched; `bossSkillGap` still holds.
- **Thrift** (`_omenGold`): a kill pays its gold × (1 − 0.04 E), at most 0.3 off, rounded; a plundering troop's extra is
  its share of that. Drops, relics and the `loot` dice are untouched (the same draws a kill), and so is the score.
- **Deflect** (`_omenDeflect`, in `_hurt` right after the heap check): each troop's normal attack on a monster
  (`Hit.normal`: a blow, a shot, never a smite, a skill, an extra hit, a bleed or a hit-back) counts one on the
  monster's `Unit.fxN`, and every nth does nothing: n by the level L (`OmenKind.byL` 12, 8, 6, 5; a count, so the Beban
  factor doesn't scale it). The boss and the mini boss count too. A cancelled one shows the monster's own hit burst
  (`hit_<its type>`, the necro healer's the necromancer's) and raises `Game._deflected`, which `_strike` and a shot's
  landing read, so it runs no `pierce`, `landed` (God's Thunder's leap), `dealt` or `kill` Fx; a splash past it still
  lands. It is a count, out of the taken floor.
- **Defiant** (`_omenDefiant`, inside the dealt cap below): a monster under a troop's taunt (`Status.taunt` whose `by`
  is that troop: a Hero's Duel of Honour or Holy Taunt, a taunt Fx) deals that troop × (1 + 0.06 E), at most 0.25; the
  boss and the mini boss (by rank) `omenDefiantBoss` half of it. A monster's taunt (Bulwark's, on the troop) is never
  read.

**The next ten Langka kinds** (batch L-2B, decisions-log 206; in the Langka pool alone, in its order among the first
ten). Each share is `omenK`, as above:

- **Shieldbreak** (`_omenSoak`, at each troop shield: the ward in `_wardSoak`, an absorb and Mana Shield's MP in
  `_afterDefence`): a monster's blow on a troop does × (1 + 0.12 E) to the shield, at most 0.6 more, so the shield
  breaks sooner; what is left of the blow past it lands as it was (the left part ÷ the same factor). A blow with no
  monster behind it (a bleed's tick, a reflect) and a troop's blow on a monster's shield soak one for one.
- **Lingering** (`_omenLinger`, the duration scaler's second factor beside Unshaken's): a buff a monster gives a
  monster, of a kind Spellbreaker strips (`spellbreakerStrips`: might, haste, swift, steadfast, shot ward, absorb,
  reflect, lifesteal, Soul Rend) and not given by a troop, lasts × (1 + 0.1 E), at most half again. A Shadow's own
  (`Effect.omen`: Avenge's and Eager's mights) keeps its time, so their lines' seconds hold.
- **Avenge** (`_omenAvenge`, in `_hurt` as a monster dies, after the killer's `kill` Fx): each living monster within
  `omenAvengeReach` (a tile) of it gets an omen might of 1 + 0.04 E (at most +0.2) for `omenAvengeTime` 3 s. One might
  at a time (`addEffect`): a stronger one it holds (a War Shout's) stays. Spellbreaker strips it; it counts in the dealt
  cap.
- **Feed** (`_omenFeed`, in `_hurt` beside a worn fang): a monster whose blow took HP off a troop heals 0.02 E of that HP
  (at most 0.15) through the monster funnel (`MonsterHeal.feed`: none under `noHeal`); never a slot (as Mend).
- **Eager** (`_omenSpawn`): a monster the wave brings (the queue's, not one a necromancer or a skill raised) comes on
  with an omen might of 1 + 0.05 E (at most +0.3) for `omenEagerTime` 5 s; the boss and the mini boss too.
  Spellbreaker strips it; it counts in the dealt cap.
- **Healer Hunt** (inside the dealt cap): a monster's blow on a troop that heals (`Stats.heals`: a priest, a priest
  Hero) × (1 + 0.04 E), at most 0.25.
- **Spell Tax** (troop-side; `skillCost`): every MP price of a troop's skill × (1 + 0.05 E), at most 0.3 more, never past
  the troop's max MP (a price already past it stays): its #10 skill's, its awakening skill's and a Hero's, at each
  read: whether it can cast, what it pays, what it saves for (`_savingUp`, `_savingForAwaken`), what Gift of Mana tops it
  up to (`mpWanted`) and Cleave's refund (half of what it paid). The book's MP tooltips show the same price
  (`skillPrice`, at the shown factor: in a wave the one paid, between waves the next wave's). Mana Shield's drain and the
  monsters' MP are untouched.
- **Off Beat** (troop-side; `_everyOf`, pusaka_engine.dart): a Rare or Epic Artifact's Fx that works every few hits
  (`Fx.every` > 1: War Drum, Snare Cord, Challenge Letter, Bleeding Edge, Mana Leech, Spell Cutter, Shatter Shard,
  Riposte, Ember Brand, Warden's Horn) needs n more hits, n by the level L (`OmenKind.byL` 1, 1, 2, 2: a count, so the Beban factor doesn't scale
  it); War Drum's every 3rd becomes every 4th, then every 5th. Every hit-count gate reads it: `_blowK`'s (the attacks)
  and `_fxNth`'s (Shatter Shard's hits landed, Riposte's hits taken). A Legendary one's never moves, nor Twin Fury's (`Fx.furyBeat`: its beat
  is the worn fury's, which stays every 3rd).
- **Fade** (troop-side; `_omenFade`, every tick after the effects, a stunned or busy troop too): each living troop's
  ward and absorb lose 0.02 E of what is left each second (× 1 − 0.02 E × dt a tick; at most 0.08). Mana Shield's MP
  and a monster's absorb never.
- **Straggler** (`_omenStraggler`, inside the dealt cap): a monster's blow on a troop × (1 + 0.06 E), at most 0.3, while
  no other monster stands within `omenStragglerTiles` 2 tiles of it (`alliesNearOf`, the same-side count, once a tick);
  never the boss's or a mini boss's (by rank).

**Six more Langka kinds** (batch L-3B, decisions-log 208; in the Langka pool alone, in its order among the first
twenty). Each share is `omenK`, as above:

- **Grudge** (inside the dealt cap): a monster's blow on a troop of last wave's top killer (`Game.grudgeType`) × (1 +
  0.04 E), at most 0.25; a Hero of that type too. The bookkeeping: while the Bayangan are on, each monster a troop kills
  counts one for its type (`_omenKill`, in `_hurt`, a kill whose `by` is a troop; a hit-back or a bleed with no source
  counts for nobody); at a won wave's end (`_omenTopKiller`, beside the ease) the type with the most becomes the target,
  a tie to the first in `troopTypes`' order, none after a wave no troop killed in. So it is fixed for the whole next
  wave, and between waves the HUD names the coming one. The tally starts afresh at each wave's start and isn't saved;
  the target is (`grudgeType`, between waves; an unknown type is skipped).
- **Drag** (troop-side; `omenDrag`, at the engine's cooldown gate `_fxGate`): a Rare or Epic Artifact's Fx on its own
  cooldown (`FxBound.cd`: Dulling Mail, Shatter Shard, Pain Crystal; a strip's or a cleanse's k, Spell Cutter's, Salt
  Charm's, Pure Water's) waits × (1 + 0.1 E)
  before its next, at most half again. A Legendary one's never, nor a once-a-wave Fx (`fxOnce`) or a skill's cooldown.
- **Scar** (troop-side; `healCeil`, in the heal funnel after Wound): in a wave (`HealKind.inWave`) a troop's heal stops
  at 1 − 0.05 E of its max HP (at most 0.15 short), and never lowers the HP it has (a troop already over the ceiling
  keeps it). What a heal gives past full is still measured against the real max HP (the catalog's `healPastFull`). The
  Grail's save and the heals between waves are untouched. Every troop-heal target check reads the ceiling instead of
  the max HP (the priest's heal and Healing Prayer's, Unbroken's allies, Mourning Bell), so a healer passes over a troop
  at its ceiling; the lowest ceiling, 85%, stays above the fall-back brain's `returnAt` 0.8, so a troop falling back
  still goes back in. A heal that gave neither HP nor HP past full runs no `heals` Fx (`_fxHealed`).
- **Gloat** (`_omenGloat`, in `_hurt`'s troop fall beside its `fell` Fx): the monster whose blow felled a troop heals
  0.05 E of its max HP (at most 0.15) through the monster funnel (`MonsterHeal.gloat`: none under `noHeal`); never the
  boss or a mini boss (by rank), and nothing for a troop that falls to no one (a bleed with no source).
- **Rekindle** (`_omenRekindle`, at the top of `_castMonsterSkill`): a high elite heals 0.03 E of its max HP (at most
  0.15) each time its skill lands, its wind-up over (`MonsterHeal.rekindle`); a wind-up a stun, a shove or a hex broke
  off heals nothing, and the boss's and the mini boss's skills never.
- **Pummel** (`_omenPummel` in `_strike`, inside the dealt cap): while the Bayangan are on, a monster's normal attacks
  count on its `Unit.blows`, and every `omenPummelEvery` 3rd does × (1 + 0.1 E) to the troop it hits, at most 0.3; never
  the boss's or a mini boss's (by rank). A blow carries it through `Game._pummeled`, a shot through `Shot.pummel` to its
  landing; only the target's `Hit.normal` blow, never a splash past it. A skill's blow (`_skillBlow`) is no attack and
  never counts.

**Sap**, the Langka pool's troop debuff (batch L-3, decisions-log 209; `OmenKind.debuff`: one a pool, never a Pusaka's
counter, lasting at most `omenDebuffMax` 3 s):

- **Sap** (`_omenSapBlow` in `_strike`, `_omenSap` in `_hurt`): every `omenSapEvery` 4th normal attack of a monster, on
  the count Pummel reads (`Unit.blows`; so the 12th is both kinds' beat), makes the troop it hits deal × (1 − 0.03 E),
  at most 0.2 less, for `omenSapTime` 2 s: a `Status.weaken` the monster put on it (`bad: true`, so a cleanse ends it;
  `omen: true`), the stronger weaken kept as always. The boss's and a mini boss's blows count too (no rank rule: it
  doesn't add damage). A blow carries it through `Game._sapped`, a shot through `Shot.sap` to its landing; only the
  target's `Hit.normal` blow that lands (a blocked one gives none; one a ward soaks still does), never a skill's blow. It
  goes on after the blow's `struck` Fx, so Salt Charm ends a Sap from an earlier blow, never the one just landed.

**The first ten Epik kinds** (batch E-1B, decisions-log 210; in the Epik pool alone, in its order: after today's seven
until the Epik cut-over, batch E-3, after Armor and Mend since; an Epik take gives 2 levels). Each share is `omenK`, as above:

- **Dark Hymn** (`_omenStats`, a stat kind): a monster healer's (`Stats.heals`: the healing necromancer, any rank)
  `dmg`, which is its heal and what Mass Mend reads, × (1 + 0.08 E), at most 0.4 more. Outside the dealt cap: it is in
  its stats. Last Rites and Second Wind (shares of max HP) are untouched.
- **Bone Arrows** (`_omenStats`, a stat kind): a skeleton archer's damage, any rank, × (1 + 0.08 E), at most 0.4 more;
  its range is unchanged. Outside the dealt cap.
- **Arrow Ward** (`_omenSpawn`): every monster that comes on (the queue's, a raised one, a bring-in) gets an omen shot
  ward (`Status.shotWard`, k 1 − 0.08 E, at most half off) for `omenArrowWardTime` 6 s: a blow from a troop that shoots
  (archers and wizards, their skills too) is × k after its defence (`_afterDefence`). One shot ward at a time: Shield
  Up's stronger one stays. Spellbreaker strips it, Lingering leaves its time, and Hard Shell counts it as a shield. It
  is out of the taken floor; Shield Up's steel grey ring shows it.
- **Enrage** (`omenEnraged`, inside the dealt cap): a monster's blow on a troop × (1 + 0.06 E), at most 0.3, once
  `omenEnrageAfter` 10 s have passed since its first blow (`Unit.firstStrikeAt`, set the first time it strikes through
  `_hurt`); never the boss's or a mini boss's (by rank). An enraged monster shows War Shout's amber might ring at its
  feet (`_statusRings`, skills.dart).
- **Hunker** (`_omenTaken`, inside the taken floor): a troop's blow on a monster that a slow, a hold (Impale's pin) or a
  stun holds (`held(u)`, pusaka_engine.dart: the test Bully's Club's `foeHeld` will read, which adds a hex) × (1 − 0.05
  E), at most 0.2 off. A weaken or a hex is no hold.
- **Counterspell** (`_omenCounterspell`, beside `_fxCast` at the three cast sites: `_tryTroopSkill`, `_tryAwakenSkill`,
  `_tryHeroSkill`): each living high elite within `omenCounterspellReach` 2.5 tiles of the troop that cast gets an omen
  absorb of 0.03 E of its own max HP (at most 0.12) for `omenCounterspellTime` 3 s, each at most once every
  `omenCounterspellEvery` 6 s (`Unit.counterAt`, not saved). One absorb at a time: a bigger one it holds stays, and
  Unholy Ward's bigger ward still lands on it (`_wardable`). Spellbreaker strips it; Unholy Ward's teal ring shows it.
- **Wear Down** (`_omenWearDown`, inside the dealt cap): a monster's normal attack (`Hit.normal`: a blow or a shot,
  never a skill's blow nor a splash past its target) on a troop adds 0.0015 E of the troop's max HP (at most 0.01), but
  never more than `omenWearDownBlow` half of the blow after the monster's might. That is the guard against a big max HP
  turning a weak hit into a big one (a Dragon Heart tank, a Hero). It is added before the troop's defence, so defence,
  Iron Banner, the ward and Dragon Crown still take it, and the dealt cap holds it with the rest. If the front falls too
  much under it, the fallback is half 0.35 and max 0.006.
- **Envy** (`_omenEnvy`, inside the dealt cap): a monster's blow on a troop with a damage or speed boost, a
  `Status.might` over 1 or a `Status.haste` under 1 from anything (War Cry, Last Stand, War Banner, Eagle Eye, an
  Artifact's might or haste), × (1 + 0.04 E), at most 0.25. A monster's slowing haste (Sticky Glob) is no boost, nor are
  a duel, a cap, a block, a link or Blessing.
- **Zeal** (`_omenZeal`, in the monster funnel `_healMonster`): a monster that a healing necromancer's heal
  (`MonsterHeal.heal`) or Mass Mend (`massMend`) gave HP gets an omen might of 1 + 0.05 E (at most +0.3) for
  `omenZealTime` 3 s; the other monster heals (Feed, Gloat, Rekindle, regen, Last Rites, ...) and a heal under `noHeal`
  never. One might at a time; Spellbreaker strips it; it counts in the dealt cap.
- **Muster** (`_omenMuster`, through `_omenBelow` in `_hurt` once a blow left the monster alive): a boss or mini boss
  (by rank) at or under `omenMusterAt` 60% of its HP for the first time (`belowOnce`, its bit `omenMusterBit` 0 on
  `Unit.belowHp`) gives every other living monster within `omenMusterReach` 3 tiles an omen might of 1 + 0.05 E (at most +0.3) for
  `omenMusterTime` 5 s, once per boss or mini boss; a killing blow gives none. Its 60% is off the boss's big move at 50%,
  so the two don't land together. One might at a time; Spellbreaker strips it; it counts in the dealt cap.

**Ten more Epik kinds** (batch E-2B, decisions-log 212; in the Epik pool alone, each in its place in the pool's order
among E-1B's ten). Each share is `omenK`, as above:

- **Second Skin** (`_omenBelow`, in `_hurt` once a blow left the monster alive): a monster below a mini boss (by rank)
  at or under `omenSecondSkinAt` 50% of its HP for the first time (`belowOnce`, its bit `omenSecondSkinBit` 2) gets an
  omen absorb of 0.03 E of its own max HP (at most 0.2) for `omenSecondSkinTime` 6 s. One absorb at a time: a bigger one
  it holds stays. Spellbreaker strips it; Unholy Ward's teal ring shows it, and Hard Shell counts it as a shield.
- **Bile Sacs** (`_omenBile`, in the kill path): a slime (its type) that dies hurts each living troop within
  `omenBileReach` 1 tile of it for 0.02 E of the troop's max HP (at most 0.12), a troop at most once every
  `omenBileEvery` 0.5 s (`Unit.bileAt`, not saved). The blow is from no one (`Hit.extra`, no attacker: nothing answers
  it, the dealt cap and Feed never see it) and goes through the troop's defence and cuts (the small relic Guard's, a
  skill's guard, Iron Banner, the ward). The slime's own hit burst shows on each troop it hurts.
- **Blood Moon** (`_omenSpawn`): a werewolf or a werebear that comes on (`omenBloodMoonTypes`, any rank, a raised or
  brought-in one too) gets an omen lifesteal (`Status.lifesteal`, k 0.05 E, at most 0.3) for `omenBloodMoonTime` 8 s:
  it heals that share of the HP its blows take off troops, through the monster funnel with its own tag
  (`MonsterHeal.bloodMoon`, `_answer`; a skill's lifesteal, the elite orc's Bloodrage, keeps `lifesteal`). One lifesteal
  at a time: a stronger one stays. Spellbreaker strips it; Bloodrage's dark crimson ring shows it.
- **Mark Ward** (`_omenMarkWard`, the duration scaler `_effectTime`, beside Unshaken and Lingering): a mark put on a
  monster, Hunter's Mark's `Status.vulnerable`, Void Eye's `Status.voidMark` or Vengeance Mark's `Status.pusakaMark`, lasts × (1 − 0.1 E), at most half as
  long, and at least `effectTimeFloor` 0.3 s. A monster's Curse of Frailty on a troop and every other status keep their
  time. Ember Brand's one-hit mark (`Unit.emberMark`, the Pusaka's) asks the same factor as it is put on.
- **Last Rage** (`_omenBelow`): a monster below a mini boss (by rank) at or under `omenLastRageAt` 35% of its HP for the
  first time (its bit `omenLastRageBit` 1) gets an omen might of 1 + 0.1 E (at most +0.4) for `omenLastRageTime` 4 s.
  One might at a time; Spellbreaker strips it; it counts in the dealt cap. A blow that takes a monster under both lines
  gives both Second Skin's shield and Last Rage's might.
- **Parting Gift** (`_omenPartingGift`, in the kill path): a monster that dies (any rank) heals each living monster
  below a mini boss (by rank) within `omenPartingGiftReach` 1.5 tiles that lacks HP 0.03 E of its own max HP (at most
  0.15), through the monster funnel (`MonsterHeal.partingGift`, so `noHeal` stops it), a monster at most once every
  `omenPartingGiftEvery` 1 s (`Unit.giftAt`, not saved).
- **Captain** (`_captained`, inside the taken floor): a troop's blow on a monster with a living high elite other than
  itself within `omenCaptainReach` 1.5 tiles × (1 − 0.04 E), at most 0.25 off. Any rank is guarded, the boss and a high
  elite near another high elite too; a high elite alone isn't. The high elites on the field are found once a tick
  (`Game._captains`), each one's place read at the blow. A monster's blow on a troop is untouched.
- **Close Ranks** (`_omenCloseRanks`, in the kill path, before the killer's `kill` Fx, so a burst that Fx sets off meets
  the guard): a monster that dies guards each living monster within `omenCloseRanksReach` 1 tile of it, 0.04 E less
  taken (at most 0.15) for `omenCloseRanksTime` 1.5 s, through `_guard` with `Unit.guardOmen` set, so its cut is in the
  taken floor. The stronger guard stays (a monster skill's Bulwark, Bone Shield or Thick Hide is never replaced by a
  weaker one, so the two never stack), and the guard's pale ring shows it. A kill inside a burst or a leap
  (`_fxDepth` > 0: God's Thunder's leap, Shatter Shard's burst) gives no guard. Funeral Pyre's burst is the
  killer's `kill` Fx, so it meets the guard on the monsters next to the dead one.
- **Blindside** (`_omenBlindside`, inside the dealt cap): a monster's blow on a troop that struck another monster less
  than `omenBlindsideBusy` 1.5 s ago × (1 + 0.03 E), at most 0.15. `_strike` keeps whom a troop fought and when
  (`Unit.lastFoe`, not saved, set only while the Bayangan are on); a healer never strikes, so it is never busy.
- **Triumph** (`_omenTriumph`, in the troop-fall branch, to anyone or no one): each living monster below a mini boss (by
  rank) within `omenTriumphReach` 2 tiles of the troop that fell gets an omen haste of 1 / (1 + 0.05 E) (at most 20%
  faster) for `omenTriumphTime` 3 s. One haste at a time: a stronger one it holds (Frenzy's, Rally's, Howl's, Second
  Wind's) stays; `attackEvery`'s floors hold. Spellbreaker strips it. The field rings an omen haste mint, as a speed-up
  is; a monster skill's haste stays ringless.

**Seven more Epik kinds** (batch E-3B, decisions-log 219; in the Epik pool alone, each in its place in the pool's order
among E-1B's and E-2B's). Each share is `omenK`, as above:

- **Prey** (inside the dealt cap): a monster's blow on a troop under `omenPreyBelow` 30% of its max HP, read before the
  blow, × (1 + 0.06 E), at most 0.4. At 30% exactly it adds nothing.
- **Herd Hunt** (`_omenHerdHunt`, inside the dealt cap): a monster's blow on a troop whose type has `omenHerdHuntAt` 10
  or more troops alive (`aliveOf`, the troop itself among them) × (1 + 0.04 E), at most 0.3.
- **Old Bones** (`_omenStats`, a stat kind): a skeleton kind's (`skeletonKinds`: the skeleton, the archer, the armored
  and the greatsword skeleton) max HP × (1 + 0.08 E), at most 0.4 more, rounded, any rank, a raised or brought-in one
  too; with the skip buff the two multiply. Outside the taken floor: it is in its stats.
- **Grave Pact** (`_omenTaken`, inside the taken floor): a troop's blow on a raised monster (`Unit.raisedBy`: a
  necromancer's minion, Split's, Swarm's, Grave Call's) while the one that raised it lives × (1 − 0.05 E), at most 0.3
  off. Once its raiser falls the cut is gone.
- **Heal Siphon** (the heal funnel, `_healTroop`; `_omenSiphon`): a troop's heal in a wave (`HealKind.inWave`) owes 0.05
  E (at most 0.3) of the HP it gave, after Wound's cut and Scar's ceiling; a heal Trickle spreads owes on the whole of it
  at the call (less what goes past full). The debt waits on the troop (`Unit.siphonDue`, not saved) and is paid once
  every `omenHealSiphonEvery` 1 s (`Game._siphonAt`) to the nearest living monster below a mini boss (by rank) within
  `omenHealSiphonReach` 3 tiles of the troop, through the monster funnel (`MonsterHeal.siphon`: none under `noHeal`); the
  heal's sparkle shows on it when it gained HP. With none in reach, or for a fallen troop, the debt is dropped; the
  wave's end drops it too (`_endEffects`). It never touches the troop's heal.
- **Trickle** (troop-side; the heal funnel, `_omenTrickle`): a troop's heal in a wave of the kinds `omenTrickled` names
  (a healer's `heal`, Healing Prayer's `prayer`, `sacrifice`, a Pusaka's `pusaka`) comes in over 0.4 E s, at most 2 s
  (seconds, not a share: its HUD line's `{sec}`), after Wound's cut. Each heal is its own entry (`TrickleHeal`: a rate
  and its own end, on `Unit.trickle`, not saved), so a newer heal never moves an older one's end; every tick after the
  effects (`_omenHeals`) each pays its rate for the time since it last paid, so the HP bar fills over the heal's time.
  What lands stops at Scar's ceiling as it lands and never goes past the max HP. The rescues (Unbroken, Lifeline),
  regen, the heal statuses, lifesteal, Last Stand's kill heal, a fang's, the after-wave heal and the Grail's save land
  at once. A heal's past full is counted at the call against the HP and what is still to come (`trickleLeft`); the sites
  that count a heal (the `heals` Fx, Dawn Star's counter, the Pusaka's tallies) read the whole heal at the call
  (`Game._healGained`), so Full Cup's ward comes at once. A troop that falls loses the rest, and the wave's end drops it.
- **Toll** (troop-side; `_omenToll`, in the kill path after `_monsterFell`): a living troop that kills a monster loses
  0.01 E of its max HP (at most 0.04), never below `omenTollAbove` 25% of it, at most once every `omenTollEvery` 2 s
  (`Unit.tollAt`, not saved). It is a blow from no one (`Hit.hitBack`: nothing answers it, no Pusaka's Fx runs on it)
  through the troop's defence, its cuts and its ward, with the necromancer's skull burst on it. A troop at or under the
  line pays nothing and its clock stays unspent.

**Bat Venom**, the Epik pool's troop debuff (batch E-3, decisions-log 223; in the Epik pool alone, after Old Bones;
`OmenKind.debuff`: one a pool, never a Pusaka's counter, lasting at most `omenDebuffMax` 3 s):

- **Bat Venom** (`_omenVenom` in `_hurt`): a bat's (`omenBatVenomType`, any rank) normal attack that lands on a living
  troop (a blocked one gives none; one a ward soaks still does) makes it bleed 0.01 E of its max HP (at most 0.04) a
  second for `omenBatVenomTime` 3 s: a `Status.bleed` of 3 ticks the bat put on it (`bad: true`, so a cleanse ends it,
  Saint's Tear's too; `omen: true`). Each tick is a blow from no one (`Hit.bleed` with no attacker: nothing answers it,
  no Pusaka's Fx runs on it, Feed and the dealt cap never see it) through the troop's defence and cuts, with the bat's
  hit burst on it. A bite on a troop the venom holds runs it 3 s from now and keeps its next tick (a bat bites more
  often than once a second); a stronger bleed it has (Pounce's, Barbed Arrow's) stays. A skill's blow (Swoop) never
  bleeds it.

**Batch G-1B's ten Legenda kinds** (decisions-log 226; in the Legenda pool alone, after today's seven, which sit in it
until the Legenda cut-over):

- **Scatter** (`_omenTaken`, inside the taken floor): a troop's extra hit on a monster (`Hit.extra`: an axeman's or a
  wizard's splash past its target, Wide Blows' wider one too, a Pusaka's leap or burst, Martyr's Flame's) × (1 − 0.08 E), at most 0.4 off. The blow on the target
  itself is untouched.
- **Thornproof** (`_omenTaken`, inside the taken floor): a hit back on a monster (`Hit.hitBack`: worn thorns, a reflect (Mirror Shield's too),
  Parry's answer, Riposte's burst; none of them names an attacker but Parry's) × (1 − 0.12 E), at most 0.6 off, so at
  its most the floor (0.5) holds it.
- **Rust** (troop-side; `_omenRust` at the four worn-relic sites): what a troop's worn small relics do × (1 − 0.1 E), at
  most 0.6 less: fang's heal (`fangShare` of the damage dealt), thorns' hit back (`thornsShare`), guard's cut
  (`guardCut`, after Sunder's) and fury's extra on its beat (its ×2 becomes 1 + 1 × that share). Relic Altar's × works
  at the same four sites, times Rust's share (`_relicK`). The Bag's and the guide's relic lines keep the full numbers.
- **Veterans** (`startWave`'s `rank`): on the same draw, the elite threshold is raised by 0.03 E (at most 0.15): a
  monster whose draw lands between the old threshold and the new one comes silver instead of normal. Never a high elite
  more, no die more (the queue's, the escort's and the healers' ranks all read it).
- **Hardy** (`_omenStats`, a stat kind): an elite's and a high elite's max HP × (1 + 0.05 E), at most 0.3 more, rounded,
  a raised or brought-in one too; with the skip buff and Old Bones they multiply. Outside the taken floor.
- **Unbowed** (`_omenShrug`): each monster comes on (the queue's, a raised one, a brought-in one: `_omenSpawn`) with
  `Unit.shrugs` (not saved) of 1, 1, 2, 2 by the level L (a count, never scaled by the Beban factor). Each pin a troop
  puts on it (`addEffect`'s `Status.impaled` from a troop: Impale's, Ice Grip's hold), stun (`_stunFor`: Crushing Blow, Shield Bash, Impale's
  stagger, the leaps and charges) and hex (Slime Hex's, Hex Blade's: its cooldown is spent all the same) spends one
  and does nothing, with Hold Fast's steel shield flashing on
  it (`RingLook.brace`). The skill that brought it still happens (its damage, Impale's break of a wind-up); the stun or
  hold itself never lands, so it cancels nothing on its own. A slow, a taunt, a weaken or a pin from no troop are never
  shrugged. The Slime Hex swap sets no charges, so a hex that landed refills nothing. The boss rank takes no stun anyway
  and spends none on one.
- **Executioner** (troop-side; `_omenBare`, read in `_hurt` before the blow): a monster's blow on a troop under 0.05 E of
  its max HP (at most 0.2; compared against the share less 1e-9) is **bare**: it skips the troop's worn guard, a skill's
  guard, its `struck` cut Fx (Iron Banner, Turtle Shell; not Vengeance Mark's cut under 0, more taken), Ghost Step's
  miss (its count still goes on), a duel's cut, a cap over 0
  (Bastion's), a block (Parry's), its absorb (Veil of Light), Mana Shield, its `capped` Fx (Dragon Crown) and its ward.
  Its defence, a mark, a cap-0 window (the Grail's save) and the `struck` Fx's other rows (Pain Crystal's MP, Salt
  Charm's cleanse; Hidden Flask's heal after the blow) still act. A blow from no monster is never bare.
- **Spite** (`_omenSpite`, inside the dealt cap): a monster's blow on a troop while a troop's Pusaka mark is on it
  (Ember Brand's one-hit mark, `Unit.emberMark`, not run out; Vengeance Mark's `Status.pusakaMark`) × (1 + 0.06 E),
  at most 0.3. Hunter's Mark's vulnerable and Void Eye's mark aren't read.
- **Blunt** (`_omenBlunt`, inside the taken floor, as the blow's new ÷ its old): on a silver, gold or boss monster (an
  elite, a high elite, a mini boss or the boss, by rank), the part of a troop's blow past `omenBluntOver` 20% of its max
  HP (after its defence) × (1 − 0.06 E), at most 0.3 off. A normal monster, and a blow at or under the line, are
  untouched, so a crowd never meets it (the design's Risk 2 guard; its fallback is a 30% line and at most 0.2).
- **Horde** (`_omenHorde`, inside the taken floor): a troop's blow on any monster (the boss and the mini boss too) ×
  (1 − 0.015 E × steps), at most 0.06 a step: a step every `omenHordePer` 10 living monsters on the field (entered,
  counted once a tick: `Game._hordeN`), at most `omenHordeSteps` 3 (0.18 off with 30 alive). Its HUD line shows the
  most (`{cap}`). With Close Ranks, Captain and Hunker at their most on one blow the product is 0.82 × 0.85 × 0.75 × 0.8
  = 0.42, held at the floor (the design's Risk 5 guard; its fallback is 0.04 a step).

**Batch G-2B's ten Legenda kinds** (decisions-log 236; in the Legenda pool alone, each in its place in the pool's order
among G-1B's ten). Each share is `omenK`, as above:

- **Cover** (`_omenCover`, inside the taken floor): a troop's blow on the boss or a mini boss (by rank, a raised one
  too) while another living monster stands on the field within `omenCoverReach` 1.5 tiles of it (`alliesNearOf`, the
  same-side count, counted once a tick for that reach) × (1 − 0.05 E), at most 0.3 off. Alone it takes the blow whole:
  the answer is to clear its neighbours first. A monster's blow on a troop is untouched.
- **Renewal** (`_omenRenewal`, after a troop's strip: Spellbreaker's arrow and Null Stone's in `_strip`, Spell Cutter's
  in `_fxStrip`): a monster that a strip took a good effect or its guard off (or halved one, on the boss and a mini
  boss) gets a shield of 0.04 E of its max HP (at most 0.25), once a life (`Unit.renewed`, not saved). The shield is the
  Barrier's soak (`Unit.shield`): a blow breaks it before the HP, no strip takes it, the wave's end clears it, Hard
  Shell counts it and Unholy Ward's teal ring shows it. A strip that takes nothing gives none. Spell Cutter strips as
  its every-th attack is made, so that blow already lands on the shield.
- **Side Swing** (`_omenSideSwing`, in `_hurt` once a melee monster's normal attack landed on a troop, not blocked): the
  nearest other living troop on the field within `omenSideSwingReach` 1 tile of the troop hit takes 0.06 E (at most
  0.3) of the blow (after the monster's might and the dealt cap, before the first troop's defence), from no one
  (`Hit.extra` with no attacker: nothing answers it, no Shadow raises it, and it never swings on) through its own
  defence, cuts and ward; the monster's hit burst shows on it. A shooter's blow, a skill's blow and a troop's blow
  never swing.
- **Deathless** (`_omenDeathless`, in `_hurt` right after the HP change, before the Pusaka's counters and the attacker's
  answers): a silver or gold monster (an elite or a high elite by rank, a raised one too; not a heap of bones) that a
  blow takes to 0 HP for the first time in its life (`Unit.omenSaved`, not saved) is left at 1 HP (or what it had,
  under 1) and takes no blow for 0.2 E s, at most 1.2 s (seconds: its HUD line's `{sec}`): an omen `Status.cap` at 0,
  as the Grail's save gives a troop (no strip takes it). The blow counts as what it
  took off, so killHeal, the Pusaka's counters and the `dealt` Fx see a blow that didn't kill, and nothing of a death
  happens: no gold, kill, score, drop or `loot` die until its real death (nor a `kill` Fx: Glory Seeker's might waits
  for it too). The holy flash shows on it.
- **Adapt** (`_omenAdapt`, inside the taken floor): a troop's normal or skill blow on a monster from the same troop type
  as the last such blow on it raises its run (`Unit.adaptRun`, not saved, from 0) by 1, at most `omenAdaptSteps` 3;
  another type's sets it to 0 and is remembered (`Unit.adaptType`). The blow is × (1 − 0.02 E × the run), at most 0.1 a
  step (0.3 at a run of 3, the HUD's `{cap}`). An extra hit (a splash past the target, a leap, a burst), a bleed's
  tick and a hit back neither count nor are cut. The design's Risk 3 guard: the run stops at 3, and the boss stack
  (Cover, Adapt at a run of 3, Hard Shell and Armor at their most: 0.7 × 0.7 × 0.7 × 0.6 = 0.21) is held at the taken
  floor from the first blow. Its fallback is 0.075 a step, then the run counted per attacking troop, not per type.
- **Warlord** (`_omenWarlord`, inside the dealt cap): a monster's blow on a troop × (1 + 0.04 E), at most 0.25, while
  the wave's boss or a mini boss lives: a living, entered one not raised, as `bossBarUnits` lists them, found once a
  tick (`Game._slotAlive`). The boss's and a mini boss's own blows (by rank) never gain it; a raised minion's do.
- **Spree** (`_omenSpreeKill` in the troop-fall branch, `_omenSpree` inside the dealt cap): a silver or gold monster (by
  rank: never a normal one, a mini boss or the boss) that kills a troop counts it (`Unit.troopKills`, not saved, at
  most `omenSpreeKills` 3; a troop Phoenix Plume brings back still counted, as it fell), and its blows on troops are
  × (1 + 0.03 E × its kills), at most 0.1 a kill (0.3 with 3, the
  HUD's `{cap}`), for its life. A red ring (the monsters' pop red) under it shows it. The design's Risk 4 guard (the
  kill snowball with Gloat and Triumph): the count stops at 3, only silver and gold count, and with Gloat's heal,
  Triumph's haste and Warlord's and Backlash's might on the killer the dealt cap holds its blow at 1.6 × (3 kills
  1.3 × 1.25 × 1.25 = 2.03). Its fallback is 0.06 a kill (Triumph 0.15, Gloat 0.1).
- **Vultures** (`_omenVultures`, in `_monsterFoe` after the taunt check): a monster of the ranks its level L names
  (`omenVulturesRanks`: L1-2 the high elites, L3-4 the elites too; never the boss or a mini boss; by L, never scaled by
  the Beban factor) with a troop in its reach goes for the living troop it reaches with the lowest HP share (a tie: the
  nearest); one that shoots picks only among those within `omenVulturesNear` 1.5 tiles of its current target. It keeps
  that troop (`Unit.vultureFoe`, not saved) until it falls or leaves its reach, or until its next attack (`Unit.blows`
  against `Unit.vultureBlows`), so a heal on it never makes it switch between two attacks. With no troop in its reach,
  or a taunt on it, it goes as before. No number and no die; its HUD line's `{who}` is its rank word ("Strong", "Silver
  and gold").
- **Mana Burn** (troop-side; `_omenManaBurn` in `_hurt`, outside the effects gate): a monster's normal or skill blow
  that lands on a troop with MP takes 0.005 E of its max MP (at most 0.03), never below 0, at most once every
  `omenManaBurnEvery` 0.5 s a troop (`Unit.burnAt`, not saved): an instant loss, as Soul Rend's. A blocked blow takes
  none.
- **Backlash** (`_omenBacklash`, beside Counterspell at the three troop cast sites, `_omenCast`): a troop's skill (its
  #10 skill, its awakening skill, a Hero's) gives each living monster within `omenBacklashTiles` 2 tiles of it (the
  boss and a mini boss too) an omen might of 1 + 0.04 E (at most +0.25) for `omenBacklashTime` 3 s, a monster at most
  once every `omenBacklashEvery` 1 s (`Unit.backlashAt`, not saved; a cast that gives Mana Font's MP sets it off as any
  does). One might at a time; Spellbreaker strips it; War
  Shout's amber ring shows it; it counts in the dealt cap.

**Batch G-3B's seven Legenda kinds** (decisions-log 239; in the Legenda pool alone, each in its place in the pool's
order among G-1B's and G-2B's). Each share is `omenK`, as above:

- **Spell Ward** (inside the taken floor): a skill's blow on a monster (`Hit.skill`: a troop's #10 skill, its awakening
  skill, a Hero's, Holy Nova's and Judgement's), not a monster's own, × (1 − 0.06 E), at most 0.36 off. A blow whose
  caster fell since names no attacker and is cut too. A normal attack, an extra hit, a smite and a hit back are not.
- **Holy Ward** (inside the taken floor): a troop healer's smite (`Hit.smite`: a Priest's holy light on the undead) on a
  skeleton kind (`skeletonKinds`, any rank) × (1 − 0.06 E), at most 0.4 off. A necromancer's smite is untouched; Holy
  Nova's and Judgement's blows are skills (Spell Ward's).
- **Hero Hunt** (inside the dealt cap): a monster's blow on a Hero (`Unit.hero`) × (1 + 0.08 E), at most +0.5.
- **Oathbane** (a stat kind, in `spawnStats`, so outside the taken floor): while an oath is held (any of the eight,
  `Relic.oath`, in `Game.pusaka`), the boss's and a mini boss's max HP (by rank, a raised one too) × (1 + 0.06 E), at most
  +0.3, read as each comes on. An elite's is untouched (Hardy's).
- **Last Gasp** (`_omenLastGasp`, through `_omenBelow` in `_hurt` once a blow left the monster alive, after Muster): the
  boss or a mini boss (by rank, a raised one too) at or under `omenLastGaspAt` 40% of its HP for the first time
  (`belowOnce`, its bit `omenLastGaspBit` 3) heals 0.03 E of its max HP (at most 0.15) through the monster funnel
  (`MonsterHeal.lastGasp`: none under `noHeal`), once; the heal's sparkle shows on it. A killing blow gives none; with
  no level its bit stays unspent.
- **Rider Rush** (`_omenRiderRush`, inside the dealt cap): an orc rider's (`omenRiderRushType`) first normal or skill
  blow on a troop × (1 + 0.12 E), at most +0.5, once a monster (`Unit.rushed`, not saved). That blow spends it whatever
  becomes of it (a block, the cap); with no level nothing is spent.
- **Dusk** (`_omenDuskTick` in the tick after the spawns, `_omenDusk` inside the dealt cap): when the queue is made
  (`_omenQueue`, after a Guard's monsters went in) the place of the wave's last crowd monster is kept (`_omenCrowd`:
  the last that is not the boss or a mini boss, one of their escorts nor a Guard's; a boss wave's healer behind the
  boss counts as crowd); the tick it comes on, the crowd is all in, and from `omenDuskAfter` 30 s later, the wave still
  on, Dusk has fallen (`Game.duskOn`, cleared at the next wave's start). From then a monster's blow on a troop × (1 +
  0.04 E), at most +0.3; never the boss's or a mini boss's own (by rank). It reads the queue and never moves the
  spawns; the battle log says once when it falls (`OmenDusk`), and between waves it waits for the next.

**Blight**, the Legenda pool's troop debuff (batch G-3, decisions-log 243; in the Legenda pool alone, after
Thornproof; `OmenKind.debuff`, lasting at most `omenDebuffMax` 3 s; unlike Sap and Bat Venom a counter, Vampire Kiss's):

- **Blight** (`_omenBlight` in `_hurt`, beside Bat Venom): the boss's or a mini boss's (by tier) normal or skill blow
  that lands on a living troop (a blocked one gives none) stops its heals for 0.75 E s (seconds, at most 3; the HUD's
  `{sec}`): a `Status.noHeal` the monster put on it (`bad: true`, so a cleanse ends it: Salt Charm, Pure Water, Saint's
  Tear; `omen: true`). A new blow runs it from then. While it lasts in a wave (`blighted`) the troop's heal ceiling is
  its HP (`healCeil`: no healer picks it, Vampire Kiss passes over it, a Trickle payment gives nothing) and the heal
  funnel gives it nothing (`_healTroop`: no heal lands, none goes past full, no `heals` Fx runs on it); the Grail's
  save and the heals between waves still land. Its body is drawn olive (the troop's sprite under `tintOlive`, ui-hud.md
  "Shadows").

**The combined caps** (the v2 rules, catalog step 0j, decisions-log 192). With many kinds held, their cuts and adds on
one blow are capped together. Each cap is read once a blow, at one site in `_hurt`:

- **The taken floor** (`_omenTaken`, at Armor's site): a blow on a monster is × the product of every Bayangan
  damage-taken factor on it, never below `omenTakenFloor` 0.5. Today that is Armor's factor (at most 0.4 off, so ×0.6,
  above the floor alone), Brace's, Stubborn's, Bear Hide's, Hard Shell's, Hunker's, Captain's, Grave Pact's, Blunt's,
  Horde's, Cover's, Adapt's and Holy Ward's on a troop's blow (so Armor with one of them at its most stops at the
  floor), Spell Ward's on a skill's blow (not a monster's), Scatter's on an extra hit and Thornproof's on a hit back
  (any blow: a hit back names no attacker), and a Bayangan's guard (Close Ranks') while it
  holds the monster's guard slot (`Unit.guardOmen`). Captain, Close Ranks and Hunker at their most on one blow are 0.75 × 0.85 × 0.8 = 0.51. A monster skill's
  guard (Bulwark, Bone Shield, Thick Hide, Iron March) isn't counted: it cuts after the floor, as before. The kinds that
  join the floor later multiply in at the same site.
- **The dealt cap** (`_omenDealt`, a monster's blow on a troop, after the monster's might and before the troop's
  defence): the blow with every Bayangan add on it is never more than `omenDealtMost` 1.6 × the blow without them. The
  add counts an omen might (`Effect.omen` on the monster's `Status.might`, Avenge's, Eager's, Zeal's, Muster's, Last
  Rage's or Backlash's: the blow without it is the blow ÷ its k), Defiant's, Healer Hunt's, Straggler's, Grudge's,
  Pummel's, Enrage's, Envy's, Blindside's, Prey's, Herd Hunt's, Spite's, Warlord's, Spree's, Hero Hunt's, Rider Rush's
  and Dusk's factors and Wear Down's share (added after the factors), and later the other dealt kinds' factors. A
  monster skill's might (War Shout, Rally) and the stat kinds (Dark Hymn, Bone Arrows, Old Bones, Hardy, Oathbane),
  already in its stats, aren't counted.
- **The omen flag:** what a Bayangan gives is flagged, so the rules can tell it from a skill's. `Effect.omen` is set by
  `addEffect(..., omen: true)`. `Unit.guardOmen` is set after a Bayangan's guard lands through `_guard`, and every other
  guard clears it (`_guard`, Bulwark). Unholy Ward ignores an omen absorb when it picks its monster (`_wardable`), so
  its ward still lands where it is the stronger (`addEffect` keeps the stronger). Spellbreaker strips an omen buff like
  any monster's. Avenge and Eager give omen mights (batch L-2B), Zeal and Muster too, Counterspell an omen absorb and
  Arrow Ward an omen shot ward (batch E-1B); Last Rage an omen might, Second Skin an omen absorb, Blood Moon an omen
  lifesteal, Triumph an omen haste and Close Ranks a Bayangan's guard (batch E-2B); Backlash an omen might and
  Deathless an omen cap at 0 (batch G-2B).

## The necromancers

### The summoner (`necromancer`)

Melee (scythe), `bossStats`. It is sometimes the boss of every 5th wave from wave 10 (`necroBossChance`,
`necroBossFrom`) and sometimes the mini boss of every 3rd from wave 9 (`necroMiniChance`), sometimes both on one wave (decisions-log 165, "Waves"); another
type in either slot raises nothing (#58). From wave 50 a
high elite one comes in every escort ("Waves"; its stats above).

- **MP** (`necroMp` by its tier, into `Stats.mp` / `mpRegen`, times the boss buff's MP multiplier): the boss
  holds 240 (up to 240 × 5 = 1200 from wave 50) and gets 7/s back; the mini boss holds 120 (up to 120 × 3 =
  360) and gets 4/s back; an escort's high elite holds 60 and gets 2/s back (no buff). It comes on with
  `mpStart` 0.25 of it (60 to 300, 30 to 90, 15). MP regenerates even while it casts.
- **Cost per raised minion** (`summonCost`): normal 10, elite 22, high elite 45, mini boss 110. A cast
  raises `minions` 2, so it costs twice that. The cost grows faster than what a tier's minion is worth
  (HP × damage per second ×1, 2.34, 5.1, 13.2), so a higher tier gives more for its MP (0.100, 0.106,
  0.113, 0.120 per MP).
- **Ceiling** (`summonCeiling(own, wave)`): one tier below its own (the boss up to mini boss, the mini
  boss up to high elite, an escort's high elite up to elite), and no higher than the wave allows. The wave allows elites from
  `eliteSummonFrom` 10, high elites from `highEliteSummonFrom` 15 and mini bosses from
  `miniBossSummonFrom` 20. So each boss after the first raises one tier higher: skeletons at wave 5,
  elites at 10, high elites at 15, mini bosses from 20. The mini boss necromancer raises skeletons at
  wave 9, elites at 12, and high elites from 15.
- **Casting** (`_summon(u, tier)`): it stands still for `summonTime` 1 s and raises up to 2 skeletons of
  that tier just in front of it, never more than `maxMinions` 6 of its own at once (`minionsOf`). They
  rise over `riseTime` 0.5 s (`busyFrom` / `busyUntil`) and carry `raisedBy`. The next cast is at least
  `summonEvery` 6 s later.
  - Raised minions pay no gold (`cost` 0), score nothing (scoreboard.md), drop no relic and no material
    (loot-items-relics.md), and a raised mini boss drops an item only by the usual roll, so a necromancer
    can't be farmed.
  - They never enter the `queue`, so they don't count in `waveTotal`.
  - The UI shows a non-normal tier's summon circle in that tier's colour (`summon_<tier>`, ui-hud.md).
- **Deciding** (`decideSummon(u)`, pure and deterministic, the result kept in `Unit.plan`): it thinks
  when its cooldown runs out. After deciding to wait it thinks again `summonThink` 0.5 s later, so it
  can WAIT.
  - `reach` = the least time any troop fighter needs to get in range of it:
    max(0, distance − its range) / (its walk, `walkSpeed`, + the necromancer's speed).
  - `shield` = its standing minions' HP / all troop fighters' damage per second (0 with no minions).
  - `life` = its HP / the damage per second of the troops already in reach of it (+1 tile).
  - Horizon H = min(`calmHorizon` 30 × its HP share, reach + shield, life).
  - For each tier up to the ceiling:
    - wait = the time to regenerate what a cast costs;
    - if wait > H, the score is 0;
    - otherwise casts = 1 + (H − wait) / max(`summonEvery`, cast cost / regen), and
      score = min(free slots, casts × 2) × the minion's HP × damage / rate.
  - The best score wins (ties go to the lower tier). It casts now if it can pay, else it waits saving
    for that tier. With every score 0 it waits for the cheapest tier; with its minions full it waits.
  - In effect: safe (nobody near, full health), it saves for its ceiling tier; with troops closing
    in, hurt, or being hit, only what it can pay for now scores, so it spends on the strongest tier it
    can afford.
- **Drops:** the boss (any type, `Tier.boss`) and the wave's mini boss (any type) drop materials: a boss 3 of its
  type's Rare part and a Soul Orb, a mini boss 2 and an Evil Eye (loot-items-relics.md "Town and Smithy: materials").
  No item or relic drops (the Smithy makes them, decisions-log 221, 246); the `loot` dice still roll the boss's
  `bossDrops` 2 items and its relic at `relicChance` 30%, the mini boss's item and relic at 10%, and throw them away
  (decisions-log 321), so a seeded game plays the same.

### The healer (`necro_healer`)

A support that stays at the very back (`_mend`; where it stands is in formation-and-navigation.md).

- **Heals** the most hurt monster it can safely reach (the boss and other healers included) by its `dmg`,
  every `rate`, for `necroHealCost` 8 MP. Safely: from a spot outside the reach (+ `necroSafety`) of every troop it can
  get away from; a troop whose reach covers the whole right edge it may back off to (a late army's archer) doesn't
  count, so it heals under its fire rather than standing pinned at the edge (decisions-log 314,
  formation-and-navigation.md). It comes on with full MP (40) and gets 3.2/s back: a burst of
  5 heals, then about one every 2.5 s.
- **Heals don't stack** (#78; the owner: "Keep 4, heals don't stack"): a monster a healer heals takes no
  other healer's heal for `healWindow` 1× that healer's heal interval (`attackEvery`, 1.2 s at its plain
  rate; `Unit.healedUntil`, `healedBy`). The others skip it for the next most hurt they can safely reach, so
  up to 5 healers spread over the hurt rather than all mending the same front monster. The one that healed
  it may heal it again (its next heal comes as the window ends). Mass Mend keeps the rule too: a monster in
  another healer's window neither counts towards its 2 nor gets its heal, and each one it heals opens a
  window of its own. Troop healers (heals, Healing Prayer, Holy Shield) are not affected, nor is a monster's
  own regen, lifesteal or a boss moment's heal.
- **Swings** its scythe only when it can't heal (short of MP, or nobody it can safely reach is hurt). The
  target is a troop within `necroSwing.reach` 18, or one a short `necroSwing.step` 8 further (it takes that
  step). It hits for `necroSwing.share` 0.6 of its heal every `necroSwing.gap` 1.4 s (at wave 1:
  4.8 per 1.4 s). The UI plays the scythe strip for a swing and the cast strip for a heal (`Unit.swung`).
- **An escort's healer** (#90, `Unit.escortOf`) heals its own mini boss or boss first whenever it may: the boss
  is hurt, isn't in another healer's window, and its heal spot is safe. Otherwise it heals as above. The healers'
  windows (#78) still hold, so of the three one heals the boss and the others the next most hurt.
  - It is brave for its own boss (`escortMeleeOnly`, the orchestrator's option B for the owner's "di backup ...
    biar ada perlawanan"). For the boss's heal spot, its rest spot behind it and backing off, only the melee
    troops' reach + `necroSafety` counts, so it stands in arrows and spells. The heal spot must also be behind the
    boss, never past it. For any other monster's heal spot the whole rule holds.
  - Why: under the whole rule a late army's long-range troops cover the field. In a probe of the owner's army the
    escort's healers sat 150–240 px behind their boss and healed it 0–1 times a slot.
  - With nobody to heal it rests a tile behind its boss (not behind the rearmost monster), a lane apart with the
    rest of that escort around the boss's lane, pushed back out of the melee troops' reach but at most
    `escortReach` 64 (its heal range) behind the boss (formation-and-navigation.md).
  - Once its boss falls it is like any other healer.
- It never walks while a heal or swing is in progress (`healCast`, below). Troops can hit and kill it
  like any monster, and its kill pays its tier's gold.

## Heroes (`Unit.hero`)

The owner: "setiap 10 wave ada 1 troops yang secara random jadi Hero dengan efek attributenya x3, dan troops
biasa selagi dia ada attributenya naik jadi 0.3". Then (#41) "hero terlalu op, yang dinaikkan cuma 2 attribute
saja bukan semua dikali 3x", 2 random attributes and the aura at +15%, "tetapi harus kontekstual, kalau troop
melee maka range jangan dinaikkan".

- **Who:** when every `heroEvery` 10th wave (10, 20, 30…) is won (the owner: "setelah wave 10 baru muncul
  hero baru, bukan di awal wave 10"), in `tick`'s win path, before the between-wave auto-save and never
  with a lost game, one living troop that isn't a Hero yet becomes one (`_crownHero`), picked with
  `Game.heroes`, dice of its own like `loot` and `names`, so it doesn't shift the spawns. Any type, healers
  included. With no candidate, nobody. It stays a Hero until it dies, so a long run can have several.
  Wave 0 is no 10th wave: a monster leaking in before the first wave (only tests do that) wins "wave 0",
  and that crowns nobody (`wave > 0`).
- **At most `heroMax` 5 alive** (the owner: "hero yang sudah mati maka slotnya bisa di pakai lagi untuk
  hero baru muncul di setiap 10 wave"): with 5 living Heroes a 10th wave's win crowns nobody (and shows
  no splash); a fallen Hero frees its place for the next 10th wave. Nothing extra is saved: the count is
  the living Heroes.
- **Hero:** when it is made it rolls `heroStatCount` 2 different attributes (`Unit.heroStats`,
  `_rollHeroStats`) from its role's pool with the same `heroes` dice, and only those are its type's
  (`statsOf`) times `heroBoost` 3 (`Stats.heroic`). The attributes (`HeroStat`):
  - `hp`: the most HP (its regen stays);
  - `power`: damage, or a healer's heal;
  - `defence`;
  - `rate` (attack rate, 3 times as often) is in no pool since #69 ("keluarkan attack speed dari pool
    attribute hero yang di enhance"). It stays in `HeroStat` because old saves name it: on load such a
    Hero rolls just that pick again (`_rerollOutOfPool`, with the `heroes` dice, from its pool without its
    other pick, which stays in its place);
  - `speed`: walking (its walk stops at its type's walk cap, "The walk cap" above: a booted Hero knight's 144);
  - `range`: reach;
  - `mp`: MP and its regen.
- **Pools** (`heroPools` by role, `heroPoolOf(type)`), only what that role uses:

  | Role | Pool |
  |---|---|
  | melee | hp, power, defence, speed, mp (never range: its reach stops at `meleeMaxRange` anyway) |
  | long range | hp, power, defence, speed, range, mp |
  | healer | hp, power (its heal), defence, speed, range, mp |

  - Defence only for a type whose recipe has shields (the only source of defence): the swordsman, the
    archer and the wizard never roll it.
  - MP is in every pool (`heroMp` true) since troop skills spend it (#10): a Hero that rolls it holds 3×
    the MP and gets it back 3× as fast, so it casts its skill much more often.
  - Splash, shot speed and price never change.
- **Its own skill:** right after its attributes it rolls one Hero skill of its type with the same dice
  (`Unit.heroSkill`), on top of its #10 skill (Hero skills, below).
- **Aura:** while at least one Hero lives (`heroAlive`), every other troop's stats are times `auraBoost`
  1.15 (+15%), all of them (`Stats.boosted`). A Hero's own other attributes get it too while another
  Hero lives. More Heroes don't add more. New troops bought meanwhile come with it. Under Oath of Kings
  (loot-items-relics.md "Legenda", decisions-log 247) the aura is `kingsOathK.aura` 1.25 and a Hero's two attributes
  ×`kingsOathK.heroBoost` 2 (not 3): `auraNow` and `heroBoostNow`, read wherever these two are.
- **Applying it:** `_statsFor(u)` is
  `statsOf(type).heroic(heroStats, heroBoostNow, aura)` for a Hero and `statsOf(type).boosted(aura)` for the others,
  with aura = `auraNow` (1.15) while another Hero lives, else 1. `_refit` sets it. Every living troop is refit when a
  Hero is made and when a Hero dies (`_refitTroops`), and on load.
  HP and MP a troop gains come with it (a new Hero at full health stays full); what it loses when the
  aura ends only caps its HP and MP, so that never kills.
- **Saved** per troop (`"hero": true`, `"heroStats": ["hp", "power"]`, `"heroSkill": "warCry"`). Saves from
  before Heroes load without any. A Hero saved before #41 (all ×3, no `heroStats`) rolls its 2 on load,
  like a new one, and a Hero saved before #48 (no `heroSkill`, or one no longer known) rolls its skill on
  load the same way. On load the flags are read first, then every troop is refit, then its saved HP
  (capped) is put back.
- **Announced:** `_crownHero` adds the new Hero to `Game.heroMade`, which the UI drains (like `casts`):
  exactly one entry per troop crowned. Loading a game adds none, not even for an old Hero that rolls
  its attributes on load, and the list isn't saved. The UI shows it on a splash screen (ui-hud.md) once the
  win's cheering is over.
- The book's stats are the type's (`statsOf`), without the Hero or the aura.
- The UI: ui-hud.md (the crown, the halo, "Hero", its 2 attributes and its skill in the nameplate, the book
  row's crown, the splash screen).

### Hero Gugur (calling a fallen Hero back, on screen "Fallen Heroes" and "Recall", #92 part 3, decisions-log 150)

Heroes falling at wave 66 was a loss the owner cared about, and late gold had nothing to buy (#92). The rules are
lib/recall.dart. Where a fallen Hero is recalled: on its type's Army detail, a "Recall" tag per fallen Hero in its
Heroes section (lib/troop_detail.dart `_recallLines`, decisions-log 230; ui-hud.md "Army"), between waves from wave 15
won (`storeFrom`, the army's buy gate `whyNotRecall` checks first). The Fallen Heroes side of the field's Shop of a
game without the Towns (lib/recall_page.dart) went in decisions-log 296.

- **Kept when it falls** (`Game.fallenHeroes`, a `FallenHero` each): a Hero that falls (`_hurt`) is kept with its
  `name`, `type`, rolled attributes (`stats`), own `skill` and the wave it fell in (`fell`), in the order they fell.
  Its relics went back to the bag as it fell, as every troop's do. A troop that isn't a Hero isn't kept ("Ganti yang
  gugur" is theirs). Only a recall takes an entry out: Resurrection never raises a Hero (`_revivable`), nor does
  Phoenix Plume, so nothing else brings one back.
- **The price** (`recallPrice`, `heroRecallPrice(wave)`): `heroRecallK` 2500 × (1 + `killGoldGrowth`)^(wave − 1) of
  the last wave played, rounded to `heroRecallRound` 1,000: 42k at wave 65, 57k at 72, 81k at 80, 195k at 100,
  about one wave's income since it grows with the kill gold.
- **Refusals** (`whyNotRecall(f)`), one gate in this order: the store's (`_armyClosed`: "Opens after wave 15", wave 15 whatever town.json's `shop.from`,
  "Game over", "Only between waves"), then `buyRefusal(type, price: recallPrice, hero: true, swap:)`: a full army
  or a type at its cap needs a troop of its type to swap (below; none: "Army full: no Templar to swap", or "No
  room: …" without the board's limits, or "Oath of the Few: up to 24 troops: …" at the oath's 24 under the cap,
  `recallNoSwap`; a full type with none but Heroes: "Templars full 10/10"); Oath
  of One may bar its type ("Oath of One: only 2 types"); fewer than `heroMax` 5 Heroes alive (`recallRefusals.heroes`
  "Already 5 Heroes"); then the gold ("Not enough gold", against the recall's whole price, not the
  troop's, and before the swap's refund).
- **A full army swaps** (decisions-log 167; qa-4: under the cap "Pasukan penuh" refused every recall, since buying
  the fallen back fills the Hero's place first). With the army `full` (at its cap, or over it: a save's 48), the
  recall sends one troop of the Hero's type that isn't a Hero home (`recallSwapOf(f)`: the lowest HP share, one still
  waiting for the after-wave heal counting as whole, of equals the first placed, the lowest `Unit.id`), and the Hero
  takes its cell. It goes as Lepas jenis sends troops (`_sendHome`): off the field, not fallen (not in `toReplace`),
  its relics back to the bag. It pays back `recallSwapRefund` (= `releaseRefund` 0.5) × `priceOf(type)`
  (`recallSwapRefundOf`). The army's count doesn't change, so the cap, the tide's counts and the Auto hold see the
  same army. A type at its cap swaps the same way (decisions-log 201), so the type's count stays too; the tooltip says
  "Templars full: Kira Thorn goes home (+12k gold)" there, "Army full: …" for a full army. With room in the army and
  its type under its cap nobody is swapped.
- **`recallHero(f)`** (the button "Recall"): it pays `recallPrice`, and the Hero
  comes back as it fell: its name (no name dice drawn), its attributes and skill (no Hero dice drawn; one this build
  no longer knows is rolled as a loaded Hero's is). Its stats are its type's as they are now (`statsOf`: the items,
  Bangkit 4-5 and the type's Pusaka, which live on the type), ×3 on its two attributes, and its 2 relic slots are
  empty. It goes to the cell `autoPlace` gives a troop and marches in from the left while the army lines up again;
  every troop is refit (the aura). With the army or its type full it swaps first (above) and takes the swapped troop's cell. It is
  not a troop bought (no `Bought`): it emits `HeroRecalled` (telemetry.md; `swapped`, the troop sent home, and its
  `refund`) and adds the Hero to `Game.heroRecalled`, which the UI drains for its splash ("<name> is back!"). Refused,
  nothing changes but the error sound.
- **`heroMax` holds**: a recalled Hero counts among the 5 (`heroCount`), so a 10th wave's win crowns nobody while 5
  live.
- **Saved** (`fallenHeroes`: `[{"name", "type", "stats": ["hp", "power"], "skill", "fell"}]`, only when any). Saves
  from before it load with none; an entry of a type this build doesn't know is dropped, an unknown attribute left
  out, an unknown skill rolled on the recall.
- **Balance:** decisions-log 56 (a probe of waves 10 / 20 / 30 with and without Heroes) and 64 (the nerf).

## Fighting rules (`tick`)

- Each unit targets its nearest foe. In range (`reaches`: its reach plus `spotSlack` 0.01, a rounding error)
  it attacks every `rate` (`Game.attackEvery`: shorter while Rampage or a haste lasts); out of range it walks at
  its `speed` (a troop at most its walk cap, below): a melee troop to its spot round a monster, or where it waits for one (formation-and-navigation.md
  "Where melee stand to fight"), long range toward the foe, to its hold ("Long range hold", below).
- **Monsters meet troops and fight them** (#84, lib/engage.dart, decisions-log 120; the owner: "ai enemy aku liat
  milih menerobos troops dari pada hit ini tidak expected sih. harusnya para enemy memukul mundur troops"):
  - A monster out of reach of the troop it goes for fights the first troop its way there runs into instead: one
    less than a body (`_personalSpace` 12) off the line to it, before it (`_monsterFoe`). It no longer squeezes
    past a troop that fights beside it to get at one behind (the heavies walking up, most often). A troop further
    off its way leaves a real gap, and it walks on through.
  - It walks only to the edge of its reach (`_reachPoint`: its reach less `spotSlack`; a shooter to its hold,
    "Long range hold" below), never at the troop's centre. Its steps went into the troop's body, the separation pushed the troop back, and a hair out of reach it
    stepped in again: it drove troops back without a blow.
  - Two monsters too close, one walking and one standing (fighting, stunned, casting): the walker takes the whole
    push and slides round the other (`_slideRound`), as a troop that gives way does. A crowd no longer shoves its
    front ones on into the troops and past them; the ones behind go round to troops they can reach, or wait.
  - So monsters drive troops back only by fighting: a hurt troop falls back (`_fallBackTo`), a fallen one leaves
    a gap. Skills still move troops and monsters through each other: Trample's charge, Swoop's and Pounce's leaps,
    the knockbacks (below), and the stall march (#39).
- **The attack floor** (#71, decisions-log 90): whatever speeds a unit up (gloves, awakening, a Hero's ×,
  War Cry, Rampage, the wave's growth), it never attacks or heals more often than once every
  `minAttackInterval` 0.3 s; the wave's boss (`Tier.boss`) may go down to `bossMinAttackInterval` 0.2 s.
  `attackEvery` applies it after every multiplier, and the book's troop row shows the rate floored the same
  way (ui-hud.md). Long range and healers that fell behind the melee walk as fast as the fastest
  melee, at most twice their own walk and never past their walk cap, until they're back (`speedTo`,
  formation-and-navigation.md).
- **The walk cap** (decisions-log 311; the owner, shown the Hero knight sliding its feet, picked "Batasi kecepatan
  jalan", a slower Hero knight, over a quicker stride): no troop walks faster than `walkMost` 6 × its type's base `speed`
  (`walkCap(type)`: soldier and archer 132, knight 144, swordsman 168, lancer 156, priest 120, armored_axeman, wizard and
  knight_templar 108), whatever raises its speed stat: boots, a Hero's ×3, the aura, an Artifact. 6× is the quickest
  the walk strip strides with its feet planted on a 60 fps screen (ui-hud.md "Troops drawn moving").
  - The stat stays as it is (`Stats.speed`); what walks reads `Unit.walkSpeed`, min(the stat, the cap): the walk to a
    spot or a foe, kiting, falling back, the catch-up pace (`speedTo`: at most 2× its walk and never past its cap), the
    steps aside (`_makeWay`), the stall detector's quarter step (`_watchStuck`), a necromancer's reach horizon
    (`decideSummon`), Crippling Shot's "faster than the archer" and the camera's meeting point (camera-and-field.md
    "Approach"). A slow or a pin slows it from there (`_pace` after the cap).
  - A charge (Cavalry Charge's 3× its speed stat), a leap, Skyfall, Phantom Rush's dashes and every carry keep their
    own speeds. Monsters have no cap.
  - On the owner's wave-30 save one troop of 34 is over it: the Hero knight, 274.7 (11.4× its 24), now walks 144. The
    knights with boots (105.3, 4.4×) walk as before, but their catch-up pace, 2× their walk (210), stops at 144.
  - The book's numbers (`Game.fieldStats`: the Army page's eight, the Bag's and the Artifacts' previews, an item's
    line) show the walk a troop gets (`Stats.walking`), and the Army page's Speed is red at the cap (ui-hud.md "Field
    stats").
- A monster with no foe walks left. Crossing `baseX` costs a life.
- **Stalled waves** (`stallTime` 30 s, `_watchStall`, `Game.marching`; #39): every wave ends.
  - Progress: the wave's own monsters (raised minions don't count) get nearer the base, fall to a new
    low of HP, die or leak, or one spawns. `_watchStall` keeps a running low of "what is left": their
    HP plus their way to the base, max(0, x − `baseX`). A spawn or a new low counts as progress.
  - Two more ways a wave stalls, for fights whose falling HP alone read as progress (decisions-log 153; qa-3: a mini
    boss led 2,000+ px off by a lone kiting wizard lost ~10% of its HP every 2 min, every blow a new low, and the
    wave went on for good):
    - **Drifting off:** `_watchStall` also keeps the front, the least way to the base of any of the wave's own
      monsters, and its low since the last spawn, death or leak (each starts it afresh). While the front stands more
      than `stallDrift` 10 tiles past that low, a new low of "what is left" is no progress. The stall clock runs, and
      the monsters march `stallTime` after the last progress. 10 tiles is twice Death Leap's reach (a monster
      turning on a troop that leapt behind it) and ten knockbacks.
    - **Overtime:** `stallOvertime` 180 s after the wave's last spawn, the last life lost or the slots' last
      progress (below), the monsters march whatever else. A plain monster falling, or its HP, doesn't count. None of
      the owner's 149 waves of telemetry (w1–86, none marched) went on much over 110 s after its last spawn, by its
      spawn count times its gap (the longest, w78, 230 s in all); only a near-wiped army fights on longer.
      - **The slots' progress** (`stallProgress` 0.05, decisions-log 166): the wave's slot monsters (its mini boss
        and boss, alive) having lost 5% of their summed max HP since the overtime clock last started starts it
        afresh, so a slow slot fight the army is still winning goes on. `_watchStall` keeps the slots' HP and max HP
        from that start (only a spawn brings a slot monster, so the same ones count until the next start, a dead one
        at 0 HP); HP healed back has to be lost again. With no slot monster alive the clock is the spawn's and the
        life's alone, as before. At 14437d0's strength the overtime marched late slot fights that 6–10 troops
        were winning (one won at 515 s without it), and the mini boss leaked a life each time.
      - **The longest:** `stallOvertimeMax` 300 s after the wave's last spawn or the last life lost, the monsters
        march whatever the slots' progress (`MarchCause.overtimeMax`), so a slot monster ground down a little at a
        time, or healed back between blows, can't hold the wave for good. On the progress alone, qa-4's one stalled
        wave (w90, its last troop whittling a greatsword skeleton boss led off right) still ran at the 600 s cap.
      - What it leaves (decisions-log 166): in the late slot fights where the overtime marched with 6–10 troops alive,
        the fight now goes on, and the drift rule marches it 30–60 s later with 2–5 left, once the last ranged troops
        kite the slot monster off; those lives stay lost.
    - Why a march began is `Marched.why` (`MarchCause`: `stalled`, `drifting`, `overtime`, `overtimeMax`), for the
      listeners.
  - With no progress for `stallTime`, the wave has stalled and its monsters **march**. Every monster
    (minions too) walks straight to `baseX` and passes through the troops: no shoves between the two
    sides while marching. They don't attack, summon or heal any more (a necromancer finishes a cast
    already started). Troops still hit them, and each one that gets through costs a life as usual.
  - A march needs the monsters to be able to walk: the right-edge clamp lets a monster's own steps left
    stand (#42, camera-and-field.md), so one the view glided past marches too.
  - The UI says "Monsters broke through!" once (`Game.newMarch`, ui-hud.md). The march ends with the wave and
    isn't saved (saves come only after a won wave).
  - Why: a necromancer boss raises skeletons forever, because its MP regen pays for a cast every
    `summonEvery`. With the army down to 1–2 archers, a skeleton is always the nearest foe, so the boss
    was never shot while the necro healer mended it. The monsters chased the kiting archers instead of
    walking to the base, so nothing died or leaked: wave 5 went on for good in 9 of 30 auto-player runs.
    A priests-only army out-healing a weak monster that isn't dark (it can't smite it) would stall too.
  - A normal wave always makes progress well inside 30 s, so the rule never fires there: the same
    auto-player plays those seeds identically (decisions-log 61).
- **Melee** hurts on the swing and shows `hit_<type>` at the foe. **Shots** fly, and hurt and show
  their hit on landing. A troop whose type has awakened shows it as `awakeFx(hit_<type>, level)`
  (`hit_<type>_awake<level>`; healers' `heal` the same way, but not a smite's `holy`), drawn in the
  level's colour (ui-hud.md).
- **A shot whose target went flies on** (decisions-log 327; the owner: "particle yang sudah terkirim jangan hilang di
  tengah jalan"). Until then a shot whose target fell or left mid-flight was dropped where it was. Now, the first tick
  its target isn't alive (fallen, or gone: a monster that leaked past the line), the shot keeps that target's place
  as `Shot.to`, frozen, and flies on to it at its own speed (`Shot.aim`: `to`, else its target's place). There it lands
  as on its target: its hit burst (a wizard's `fireball` or `shards`) and its ring (Arcane Blast's) at that spot, then
  - the unit of the target's side standing nearest the spot, within `landReach` (half a tile, a line shot's width,
    `lineWidth`), is hit as its target would have been (`_standingOn`): the shot's damage and source (a normal shot's
    `Hit.normal`), its `onHit`, the type's `landed` Fx (God's Thunder, Shatter Shard) and the relics' landing (Sweep,
    Venom, Mana Siphon, Chill, Weak Spot), kill gold and every Fx `_hurt` runs. The owner, asked whether a single shot
    should hit a monster standing there: "mau". The same for the monsters' shots at troops: a troop on the spot takes it;
  - a splash shot (a wizard's plain shot, Arcane Blast; a shooter whose type holds Wide Blows) hurts every unit of the target's side within
    its splash of the spot, as round a living target: the unit on the spot with the shot's own source, the rest
    `Hit.extra` (a skill's all its `Hit.skill`), with Wide Blows' counter and `onHit` on each;
  - with nobody on the spot, a single shot hits nothing: its look alone (and a splash shot only its splash).

  Every shot flies so: the archers' and the wizards' plain shots and Arrow Rain's, Arcane Blast, the Hero skills'
  special shots (Snipe, Crippling Shot, Javelin), Spellbreaker's silver arrow, and the monsters' (a skeleton archer's
  arrow, Volley and a mini boss's Barbed Arrow, an orc rider mini boss's Spear Throw, a slime's Sticky Glob). The instant blows aren't shots and are as before:
  melee and its splash, Circle Slash, Piercing Thrust, Crushing Blow, a healer's smite, Chain Lightning's and God's
  Thunder's beams, the zones' pulses (Bone Rain's arrows); nor are the line shots (`LineShot`: Piercing Shot, Axe
  Throw, Grave Wave), which fly their line whoever falls.
  - **In the air when the wave ends** (its last monster gone) or the army is wiped: every shot still flying is `spent`:
    it flies on (a wipe freezes its `to` too, the swept monsters having left the field) and lands its look and ring, and
    hurts nobody. Until then a monster's shot in the air at a living troop as the wave ended still hurt it between
    waves, and a wipe cleared every shot.
  - The dice are the shot's own as before (`_hurt`'s rolls in the order the shots land); landing on the spot rolls them
    where a dropped shot rolled none, so a seeded fight plays differently from that landing on. Nothing new is made a
    tick: `to` keeps the target's place as it was.
- **Awakening** (per troop type, from its items; loot-items-relics.md) raises its HP, MP and MP regen
  (`awakenHp`, `awakenMp`), its item caps and its price, changes its looks, and gives its troops an awakening
  skill (Awakening skills, below). A Hero and its aura change stats too (Heroes, above).
- Splash hurts everyone of the target's side within `splash`.
- **Where a blow comes from** (`Hit`, decisions-log 182): every `_hurt` call names one, its third argument: `normal`
  (a fighter's blow or shot on its target, the necromancer's scythe), `smite` (a troop healer's holy light, `_smite`),
  `skill` (a troop's, an awakening's, a Hero's or a monster's skill, everyone its area hits), `extra` (a normal attack's
  splash past its target, God's Thunder's leap, Shatter Shard's burst), `hitBack` (worn thorns, a reflect, Parry's
  answer, a Bayangan's Thorns, Riposte's), `bleed` (a bleed's tick, Bleeding Edge's and the Venom relic's too) or
  `relic` (a small relic's own blow: the Sweep relic's on the monster next to the target, decisions-log 227; never a
  normal hit, so nothing that answers one runs on it). A shot carries its own
  (`Shot.src`; a `Shot.special` is a skill's), the holy blow `_holyHurt` passes its caller's on, and a linked ally's
  share keeps the blow's; Wrath Psalm's holy light on the monsters next to the troop healed is a `smite` too (batch
  G-3). The Bayangan read it (Scatter, Spell Ward, Thornproof, Holy Ward); the Oath of Spells needs none, its cost
  being in `_blowK` (a troop's normal attack and a healer's holy light, "Oaths in a fight" below). test/hit_source_test.dart checks every call.
- `_hurt(u, dmg, src, [by, cap])` is where damage lands. The target's defence comes off first: `hitTaken(dmg, def)`
  = max(dmg − def, max(`minHit` 1, `minHitShare` 0.1 × dmg)), so every blow does at least 10% of itself
  (and 1). Then the guard relic's cut, then a skill's guard (Hold Fast, Holy Shield; below). The relics
  and the Pusaka hook in here (loot-items-relics.md; the Smithy's seven, dark: Giant Slayer's × on a normal blow or a
  smite on a mini boss or the boss before defence, Iron Will's heal once the blow has landed); after every cut a troop's ward ("The ward", below) soaks what it
  can before the HP. `_hurt` returns the HP the blow took (God's Thunder's counter
  sums it), the Pusaka's counters read the blow before Void Eye marks its target (so the blow that marks it adds
  nothing), and a troop at 0 HP whose type holds the Grail is saved before it falls. **Dragon Crown** (a Legenda,
  decisions-log 155) is the last cut, after the defence, the guards, a mark or a curse, every `Status.cap` (a Grail
  save's 0, Bastion's 8%), what a veil or the MP soak up and a monster skill's cap: no blow then takes a troop of its
  type more than `crownCap` 60% of its max HP (its `capped` Fx, `_fxCapped`, lib/pusaka_engine.dart). It is its own check, not a `Status.cap` (critique M3),
  so the caps under it still hold and Bastion still fires. The stat Pusaka (Dragon
  Heart's HP and regen, Dawn Star's power) are in `statsOf(type)` itself, after the items, the awakening and the
  Hero, so the book's rows and every troop of the type agree (decisions-log 138).
- **Long range hold** (lib/engage.dart, decisions-log 199; the owner: "ai long range troops/enemy untuk jangan terlalu
  jauh juga dari center battle field tapi tetap maintain jaraknya agar particle/anak panah travel timenya tidak jadi
  lama"): a shooter (`shotSpeed` > 0, troop or monster) stands no further from the foe it shoots than its hold,
  `holdAt` = min(its reach, max(`rangedGap` 4 tiles, `shotSpeed` × `rangedFlight` 0.5 s)): the distance its shot
  flies in half a second, but never nearer than 4 tiles, nor past its reach.

  | Shooter | Shot | Hold |
  |---|---|---|
  | archer | 200/s | its reach up to 100 (6.25 tiles): a base archer's 64 and one with one or two bows stand as before; from three bows, 100 |
  | wizard | 140/s | 70 (its base reach is 72), whatever its bows |
  | skeleton archer (any rank) | 150/s | its reach up to 75: as before until about wave 26, then 75 instead of the edge of its reach (90 from wave 76) |

  - In reach but further off than its hold, it steps up to it while it shoots (a troop at the catch-up pace,
    `speedTo`, formation-and-navigation.md); out of reach it walks there (`_reachPoint`). Inside its hold it stands
    and shoots; only a troop backs off (the kite, below), a monster never.
  - Its reach still decides what it may shoot: bows, a Hero, Eagle Eye and the wave's range growth still let it hit
    a foe further off (one walking away, one coming in) and the skills that look "in range" see as far. They no
    longer set where it stands.
  - Why: a shooter used to stop wherever its reach first touched its nearest foe. Late reaches outgrew the view (the
    owner's archers carry 12 bows, 570 px, and the Mac's view is 341 px wide): measured on the w89 save, wave 90, the
    wizards never left their posts, 26 tiles behind the fight and off the screen, their orbs flying 3 s (three of
    every four never landed: their foe fell first), and the archers backed off every foe to the view's left edge,
    their arrows flying 0.77 s (1.0 s for one in ten). With the hold a shot fired standing flies about half a second,
    and the wizards and archers stand 4 to 6 tiles from the fight's centre.
  - Healers keep their own rules: their heals don't fly (a heal lands at once), a troop healer rests behind the
    fighters (formation-and-navigation.md, "Healers mid-battle"), and the healing necromancer keeps out of the troops'
    reach (`_mend`).
- **Long range kite:** a troop shooter backs off while shooting from a foe nearer than `kiteAt` = min(`_kiteAt`
  0.75 × its hold, `rangedGap` 4 tiles): a base archer at 48 as before, a long-reach archer at 64, a wizard at 52.5
  (it was 0.75 × its reach: 428 and more for the owner's archers, so they backed off anything on the screen). Never from a foe 4 tiles or further: a ranged monster stands at least that far once its reach allows (its
  hold), so an archer doesn't back away from one that keeps stepping up after it, the drift below. Never
  behind max(baseX, cam + keepUpShift) + tile/2: the back line, or the keep-up floor when that is further on:
  the view's left edge, `keepUpInset` 2 tiles inside it once the wave has shown a fight (#61, #85,
  camera-and-field.md). Pinned there, an archer backs straight up to it and holds: sliding along it only ran
  it into the archers beside it (#82, formation-and-navigation.md). Holding there it is 1 tile inside the
  catch-up trigger, so it isn't sped back up to it.
  - Its back-off has no limit on the right: a troop past its foe (the foe between it and the base) backs off away
    from the base. qa-3's stall: after a near-wipe a lone wizard 90–104 px right of a skeleton archer mini boss
    backed off right, the boss walked after it to its own shorter reach, and both went right at the wizard's
    18 px/s, 2,000+ px in 4 min with the view in tow, the wave still on at 600 s. `rightLimit` can't stop it, as it
    moves with the view (camera-and-field.md). The stall watch ends such a wave ("Stalled waves" above: the drift is
    no progress, and the overtime).
  - `Game.holdPastFoe` (off; decisions-log 153), the switch for the QA cycle: on, a troop past its foe keeps its x
    and only steps aside, the y part of its step back (straight in line, it holds), and still shoots. In a fight as
    the monsters come (they from the right, the troops backing off left) it never binds: 0 troop-ticks in 17
    replayed waves (w12–99). After a near-wipe it binds often, and it took the last troops' way out: on 14437d0 two
    of qa-3's three stalled waves ended with the army wiped (game over) instead of won, so it is off.
- **The front stops at the view's right edge** (decisions-log 324; 312's leash before it): mid-wave no troop walks
  past a tile inside the view's right edge (`frontCap`); one there stands facing its foe and fights what it reaches,
  never stepping back for it; the view centres the fight and the healers rest at most 2.5 tiles behind the melee in it
  (formation-and-navigation.md "The front stops at the view's right edge", "Healers mid-battle").
- **Hurt troops fall back:** at or below `retreatAt` 50% HP a troop falls back to the nearest troop
  healer and fights on at `returnAt` 80%, only while a troop healer lives; it doesn't chase meanwhile,
  but still hits a foe in reach. When heals don't come (`healWait` 3 s at the healer without one) the one
  with the most HP there goes back in from `earlyReturnAt` 60%. The decision is a `RetreatPolicy` with its
  numbers in `assets/ai/retreat.json` (formation-and-navigation.md, lib/retreat.dart).
- **Healers:** see formation-and-navigation.md for where they stand.
  - Mid-battle a troop healer heals the ally it can reach that falls back to be healed, else the most
    hurt (`_heal`). The healing necromancer has its own rules (`_mend`, above).
  - Out of sight left of the view it walks into it before it heals, and more than a tile behind the army it walks up
    between heals (decisions-log 312), healing on the way only an ally falling back or at half its HP or less
    (decisions-log 324; formation-and-navigation.md "Healers mid-battle").
  - **A heal costs MP** (decisions-log 297; the owner: "army/enemy healer harusnya ketika melakukan heal itu akan
    menggunakan mp-nya"): `healMp` 6 MP a heal (`_castHeal`), the healing necromancer's way (it pays
    `necroHealCost` 8 of its 40). It is 10% of a priest's base pool; awakening, a Hero and the aura raise the pool
    and its regen, never the cost. MP comes back only at its regen (and what refills MP: Mana Siphon, Gift of Mana,
    the Artifacts'). Measured on the fixtures' saves before the change, 6 MP a heal would have left a lone priest
    short on about a third of its heals at wave 9, five priests on 0-12% at wave 14, and 17 priests at wave 90
    never.
    - **Short of it** (`Unit.mp` < `healMp`) a heal it would give doesn't happen: it smites the weakest undead in
      its range instead (free, below) or waits where it stands, facing the one it would heal. The first such heal
      sets `Unit.dry` and queues it in `Game.noMp` for the UI ("No MP" pops over it once, ui-hud.md); `dry` clears
      once it has `healMp` again.
    - **Skill first** (`_healWaits`): while a skill of its is ready (its cooldown over) and has a target, and the
      MP a heal would leave doesn't pay for it, it holds its heals the same way: its Hero skill (`_savingUp`), its
      awakening skill (`_savingForAwaken`) or its #10 skill (Healing Prayer). Its heals use what the skills
      leave.
    - Its smites (holy damage, below) and the after-wave heals (`_healFromQueue`, carried into a wave or not) cost
      nothing.
  - **Holy damage** (`_smite`, decisions-log 59): when no ally it could reach needs healing, a troop
    healer "heals" a dark monster already in its heal range. That monster loses `holyShare` 0.8 of the
    heal (`_healOf`, the healer's `dmg`, its potions' `potionHeal` and staffs' `staffHeal` included): a
    priest's 12 is 9.6, with one potion 15 is 12. Among several, it picks the one with the least HP left.
    - It is a cast like a heal: `rate` apart, standing still for `healCast`, the healer's attack strip.
    - It is a blow like any other, through `_hurt` with the healer as `by`: the target's defence, kill
      gold, score, loot, and the relics (fang heals the healer, fury doubles every 3rd smite).
    - The healer never steps up to reach a dark monster: only those already in range from where it
      stands, and between smites it keeps falling back to its rest line.
    - It shows a `holy` burst (the heal fx in white and silver, at every awakening level) and plays the hit
      sound.
    - Monster healers are not affected: the healing necromancer heals dark monsters as before.
  - **No walking while healing:** once a healer starts a heal (or the healing necromancer a swing) it
    stands still for `healCast` 0.6 s (`_casting`). It doesn't walk to the hurt, fall back, step aside
    (`_makeWay`) or get shoved by separation: whoever bumps into it takes the whole push. The same holds
    for the priest's after-win heals and smites. The UI squeezes the cast animation into those 0.6 s.
    The one exception would be the back line moving up past it (`baseX`): it is carried to the line like
    any troop left behind. While the line followed the view a probe saw this 29 times in 100 battles of
    waves 10–20; since #79 the line moves only on a win (earlier it followed the rearmost troop, #61), so mid-wave it doesn't.
  - After a win: if any healer lives, every healer works through `healQueue` (itself first, then
    melee, then long range, only the hurt), each at its own `healGap` 0.4s. A new wave drops the heals
    still to come, unless the fall-back brain's `carryHealQueue` (off; decisions-log 96) keeps them: then
    mid-wave a healer ready to heal gives the next one before its own heals (`_healFromQueue`).
  - With no healer alive, HP is NOT restored after a win.
- **The heal funnel** (`_healTroop`, lib/heal.dart; catalog step 0e, decisions-log 181): every heal a troop gets lands
  in this one function, tagged by where it came from (`HealSrc`): a healer's heal (`heal`), Healing Prayer (`prayer`),
  Blessing's `Status.heal` (`overTime`), Bloodlust's `lifesteal`, Last Stand's `killHeal`, `sacrifice`, `unbroken`,
  `lifeline`, its `regen` (every tick, between waves too; Dragon Heart's and Living Moss's share of it too), a worn
  `fang`, a Pusaka's heal (`pusaka`: Blood Fang, Mourning Bell, Wolf Feast, Hidden Flask, Halo Lantern, Hearth,
  Heartbeat, Bright Spring, Vampire Kiss), the after-wave heal (`queue`: all its HP back), the Grail's save (`grail`: from nothing
  to its share) and the Iron Will relic's once-a-wave heal (`lastStand`, decisions-log 227: in a wave). It adds the
  heal, never past full HP, and returns the heal past full (the catalog's `healPastFull`).
  First a Mercy Lily on the troop's type (`_fxLily`, batch E-3P) makes a heal it gets while under 40% of its max HP
  (before the heal) × its k, but the Grail's save and the after-wave heal; then a worn Holy Charm (`charmK`,
  decisions-log 227) × its k, but its own regen, the Grail's save and the after-wave heal; `onTroopHeal` hears the heal
  asked, and the Pusaka's tally gets what the Lily's × added.
  - What a heal is to the Bayangan **Wound** (`HealKind`, `healKind`): the Grail's save is `grail`, the after-wave heal
    always `between` (carried into a wave too), any other `inWave` while a wave is fought (`waveActive`), else
    `between`. Only an `inWave` heal is multiplied by Wound's factor (`_woundK`: 1 − 0.06 a level E, at most 0.5 off,
    `omenK`), which is 1 with no Wound or while the Bayangan are off (`omensOn`). `Game.woundForce` sets the factor in
    its place for a test or a probe. Then the Bayangan **Scar** stops an `inWave` heal at its ceiling (`healCeil`: 1 −
    0.05 E of the max HP, at most 0.15 short; "Bayangan on the field"), never lowering the HP; the heal past full is
    still against the real max HP. In the funnel's order: Wound cuts, then the Bayangan **Trickle** puts a heal of
    `omenTrickled`'s kinds on the troop as its own entry, paid over its time with Scar's ceiling at each payment; under
    the Bayangan **Blight** (`blighted`, batch G-3) an `inWave` heal lands nothing (none past full, no `heals` Fx);
    then the Bayangan **Heal Siphon** adds its share of the HP the heal gave (a spread heal's whole, at the call) to the
    troop's debt (`Unit.siphonDue`), paid once a second to the nearest monster ("Bayangan on the field"). What the heal
    gave is `Game._healGained`, read after `onTroopHeal`: the heal sites that count it (the `heals` Fx, the Pusaka's
    tallies) read it instead of the HP before and after, the same number with the Bayangan off. Blood Oath's cost
    comes before Wound ("Oaths in a fight" below).
  - A site both sides share (a healer's heal, regen, the heal statuses, lifesteal) goes through `_healUnit`: a troop's
    heal through the funnel, a monster's through the monsters' own funnel, `_healMonster` (catalog step 0g, decisions-log
    184), tagged `MonsterHeal`: a healing necromancer's `heal`, `massMend`, `lastRites`, `secondWind`, Soul Drain's
    `drain`, Swoop's `bite`, Bloodrage's `lifesteal`, `regen` (the Bayangan's Mend, while they are on), `overTime` (no
    monster has it yet), Reassemble's stand (`reassemble`) and the Bayangan Feed's (`feed`), Gloat's (`gloat`),
    Rekindle's (`rekindle`), Parting Gift's (`partingGift`), Blood Moon's lifesteal (`bloodMoon`), Heal Siphon's
    (`siphon`) and Last Gasp's (`lastGasp`). A `heal` or `massMend` that gave HP brings the Bayangan Zeal's might ("Bayangan on the
    field"). The HP that comes with a higher max HP (`_refit`), a
    save's HP, Resurrection's and Phoenix Plume's new troop, a hexed monster's swapped stats, Grave Call's raised monster, Reassemble's
    heap and the Bayangan Deathless's 1 HP (a deadly blow stopped, so no `Status.noHeal` stops it) are no heals.
    test/heal_funnel_test.dart's static guard lists every other HP write in lib/, so a heal of either side written
    outside its funnel fails it.
- **The ward** (`Unit.ward`, lib/heal.dart): a troop's shield, granted by `giveWard` up to `wardMax` 0.20 of its max HP
  (one value; a gift's own `most` may stop lower, and never cuts a ward already over it). In `_hurt` it soaks a blow
  after every cut, before the HP (`_wardSoak`); what it soaks is no HP taken (a monster's blow breaks it sooner under the
  Bayangan Shieldbreak, and Fade shrinks it each second: "Bayangan on the field"). It ends with the wave (`_endEffects`) and
  isn't saved. The catalog's ward Fx grant it: Watch Shield (each wave's start) and Bone Buckler (each kill), batch L-2P;
  Full Cup (a healer's heal past full, on the troop healed), batch L-3; Aegis Seal (a skill cast, on the caster), batch
  E-2P. The Pusaka that last added
  to it is its giver (`Unit.wardFrom`, not saved): what it soaks counts for that Pusaka (`_fxWardSoaked`), whichever
  type wears it, and a troop with one shows the guard's mark over it (ui-hud.md).
- **Cleanse and noHeal** (lib/cleanse.dart, lib/heal.dart; catalog step 0g, decisions-log 184). The catalog's `cleanse`
  Fx grant the cleanse: Salt Charm (a blow on its troop) and Pure Water (a healer's heal, on the troop healed), batch
  L-3, each ending 1 at most and then waiting its cooldown (its k, `Fx.cdByStars`; it starts only when one ended);
  Saint's Tear (a skill cast, on the caster and each troop within 2 tiles), batch E-3P, ending every bad effect a
  monster put on them, its cooldown the same way. Grave Seal (batch G-3) grants noHeal on the monsters its type hits.
  The Bayangan's troop debuffs come with the cleanses: Sap with batch L-3, Bat Venom with batch E-3 and Blight with
  batch G-3 ("Bayangan on the field").
  - **A bad effect** (`Effect.bad`): a monster put it on this troop. Its skill says so (`addEffect(..., bad: true)`):
    Screech's daze, Barbed Arrow's and Pounce's bleed, Sticky Glob's slow and slower attacks, Slime Tide's slow, Roar's
    weaken, Curse of Frailty's vulnerable, Bulwark's taunt; and the Bayangan Sap's weaken, Bat Venom's bleed and Blight's noHeal (`omen: true` too). Any other effect on a troop (a troop's, a Hero's, a Pusaka's,
    its own) is never bad, whoever it names (a knight's duel names the monster).
  - **`cleanse(u, {most})`**: what monsters put on troop `u` ends at once: every bad effect, a monster's stun (it still
    can't be stunned again until `stunImmuneUntil`) and a Soul Drain on it (its beam goes, so the drains stop). `most`
    ends only that many, the most time left first (alike: in the order found). A stat effect ending refits it. What a
    troop or the troop itself put on it stays, and so does Slime Tide's puddle: it slows the troop again while it stands
    in it. A shove is over at once, so there is nothing to end. `badOn(u)` counts what a cleanse would end. Returns how
    many ended.
  - **`Status.noHeal`** on a monster: every heal it gets lands as 0 (`_healMonster`, `noHealOn`; under Grave Seal's
    seal the HP each heal would have given counts for it, `_fxSealed`), and a skeleton under it doesn't reassemble: its
    killing blow is its last (Grave Seal's blow puts it on before Reassemble asks, so the seal stops the rising). Laid
    on a heap, the skeleton stands again at the heap's HP. A healer still aims at a sealed monster and spends its heal
    on it (the player's payoff for sealing; batch G-3 kept it). It ends with the wave like any status, and Spellbreaker
    never strips it (it is a troop's).
  - **`Status.noHeal`** on a troop: the Bayangan Blight's (a monster's, bad, so a cleanse ends it): in a wave its heal
    ceiling is its HP and the heal funnel gives it nothing ("Bayangan on the field").
- **Game over** is `lives <= 0`. Then `tick` stops.
- **An army wiped** (lib/wipe.dart, decisions-log 322; the owner: "Kalah wave: −1 hati, ulang"): checked at the end of
  `tick`, after the raised joined and before the win, unless the leaks just ended the game. `_armyDown`: a troop fell this wave (`fallen` isn't empty), none
  is alive (a troop Resurrection raised this tick counts), no Phoenix Plume rise is due (`_risesDue`, counted when its
  `later` is set, dropped by `_endEffects`), and a monster lives or is queued (the last troop and the last monster
  falling together is a win; a wave begun with no troop is never a wipe: only its leaks cost). Then `_wipe`:
  - `wipeLives` 2 lives go (a heart; floor 0), `wipedOut` is set (until the next wave starts), `wipedAt` = `t`, the
    lose sound, and the event `Wiped` (the lives left and lost, the monsters alive and queued, `over`). At 0 lives the
    game is over as by leaks: the monsters stay and cheer, the tick's end scores it (`WaveEnded(won: false)`).
  - Else the sweep: the living monsters leave `units` for `swept` (the UI draws them hopping for joy `wipeCheer` 2.4 s,
    then each goes in a summon circle, `_sweptGone`), the queue, line shots, beams, zones and the monsters'
    rings are cleared, the shots in the air are spent (they fly on and land their look alone, decisions-log 327), the march ends, `_endEffects`, the Grail's watch ends, `WaveEnded(won: false)`, the Tavern's
    boosts count the wave, the wave's materials lying on the field are lost (`waveMaterials` cleared: they come with a
    win), "Replace fallen" lists the fallen (not the Heroes: Recall's), Auto's `_autoWon`, no after-wave heal, Lewati's
    skip buff it carried is owed again (`skipBuffDue`), `lostWave` = the wave and `wave` goes back one.
  - No `victoryAt`, wave bonus, wave score, Shadow ease, Grudge target, Hero, boss chest or Town roll: they come when
    the wave is won (the win clears `lostWave`). What the wave paid as it went stays: kill gold, kill score, kills.
  - Between waves it reads as after the last win: the back line where it was, a Town due by `townAt == wave + 1`
    (one left before the lost wave isn't due again; one marked after it waits for its win), "from wave 15 won". The next
    `startWave` rolls the same wave afresh (its number, tide and slots; new dice), and `_omenWave` lands no catch-up
    on it (`lostWave == wave`).
  - Saved between waves as `lostWave` (only while set; loaded only when it is `wave` + 1), save version 3.

### Oaths in a fight (decisions-log 155, 247)

An oath (a Legenda Sumpah, loot-items-relics.md "Legenda") works on the whole army. Most change only the stats
(`_oathStats`, in `statsOf` after the Pusaka: Oath of One, Alliance, Oath of the Few, the Wall, the Vanguard, Blood's
attack; only the Tavern's boosts come after it, `_boostStats`, loot-items-relics.md "Towns: the Tavern"); four
reach into a fight, each a factor of exactly 1 with no oath:

- **Blood Oath's heal cut** (`_oathHealK` `bloodOathK.healIn` 0.5): first in the heal funnel, on an `inWave` heal only
  (its regen too), before Wound's factor; never the Grail's save, the after-wave heal or a heal between waves.
- **Oath of Spells' cooldowns** (`skillCd(base)`): ×`spellOathK.cd` 0.8, never under `cdFloor` 5 s and never longer
  than `base` (an infinite one stays infinite), at the three cast gates: the #10 skill (`_tryTroopSkill`), the
  awakening skill (`_awakenReady`; its wave-start stagger and Impale's window too) and a Hero's (`_heroSkillReady`).
- **Oath of Spells' cost** (`_oathBlowK` `spellOathK.blow` 0.8, in `_blowK`): a troop's normal attack and a healer's
  holy light, a normal attack's splash and what reads its blow (God's Thunder's leap, a worn relic's share) with it; a
  skill's blow and a hit back keep theirs.
- **Oath of Kings** (`auraNow`, `heroBoostNow`): the Hero aura ×1.25 and a Hero's own two attributes ×2 ("Heroes"
  below).

`_oathOn` is the oath the troops were last refit to; `_oathWatch` refits them every tick when the oath or `_oathK`
moves, so a new oath works from the next tick and a save's from load.

## Troop skills (`troopSkills`)

Every troop type has one skill (`Skill`: its name, English since #73, MP cost, cooldown), cast by itself during a
wave, never between waves:

- Each tick, before it attacks, a living troop not casting a heal casts its skill whenever it has a target
  (`Game.wantsSkill(u)`, the rules below), it holds the cost in MP (`Unit.mp`) and `cooldown` s have
  passed since its last one (`Unit.skillAt`; under Oath of Spells `skillCd(cooldown)`, "Oaths in a fight" above), unless a skill before it on the MP wants that MP: a Hero's own
  (`_savingUp`, Hero skills below) or its type's awakening skill (`_savingForAwaken`, Awakening skills below).
  `_trySkill` goes Hero skill, #10 skill (`_tryTroopSkill`), awakening skill, one cast a tick; it takes the MP
  and queues the troop in
  `Game.casts` for the UI (its skill's name pops up over it on its first cast of a wave, ui-hud.md). On the board the
  skill then winds up and lands on its strip's blow ("Skill strips" below, decisions-log 299); in a plain `Game()` it
  lands at once.
- **A target is enough** (decisions-log 298; the owner: "selagi masi ada mp, dan skill avaliable para army spam aja
  skillnya"): no rule waits for a crowd or for the troop's own low HP any more. `wantsSkill` changes nothing (a
  skill's wind-up asks it again where it lands).
- **Cost and cooldown:** each costs `skillMpShare` 25% of its type's base MP pool, which is 5 s of its regen (every
  type gets 5% of its pool back a second), so a full pool holds 4. It comes again after `skillCooldown` 4 s, or 2 s
  after its own effect ends (Hold Fast 5 s, Rampage 6 s, Holy Shield 6 s).
- MP comes back at the type's `mpRegen` all the time, so every troop starts a wave full. Awakening raises
  both (`awakenMp`) but not the cost, so an awakened troop casts as often as the cooldown lets it; a Hero that
  rolls MP has both ×3; the aura adds 15%.
- Measured on the fixtures' saves (a wave each): a troop cast about 2-4 times a minute before 298 and casts 10-15
  times a minute now (the cooldown is what holds it back), and the waves end sooner. Until 298 the skills cost
  15-40 MP (50-75% of the pool), came again after 10-16 s and most waited for 2-3 foes or a low HP; that was
  tuned with an auto-player probe (decisions-log 67).
- `Game.skills` (default true) turns them all off, for probes and tests.
- "Foes" are living monsters that have entered the field; "in reach" is within the troop's `range`.
- The names are English since #73 (decisions-log 100), like the Hero skills: Hold Fast was Bertahan, Circle
  Slash Tebasan Melingkar, Rampage Amukan, Arrow Rain Hujan Panah, Piercing Thrust Tusukan Tembus, Healing
  Prayer Doa Pemulihan, Crushing Blow Hantaman, Arcane Blast Ledakan Sihir and Holy Shield Perisai Suci.
  Only the name that pops up (and the battle log's cast line) changed; nothing saves it, so old saves are
  unaffected.

| Type | Skill | MP / cooldown | Casts when | Does |
|---|---|---|---|---|
| soldier | Hold Fast | 5 / 5 s | a foe in reach, and not guarded that strongly already | takes `guardSelf` 30% less damage for 3 s |
| knight | Circle Slash | 5 / 4 s | a foe within `slash.reach` 20 | hits each foe there for its damage (`slash.hit` 1×) |
| swordsman | Rampage | 7.5 / 6 s | a foe in reach, not already raging | attacks 1.67× as fast (`frenzy.rate` 0.6 × its rate) for 4 s |
| archer | Arrow Rain | 7.5 / 4 s | a foe in range | `volleyArrows` 2 extra arrows at the nearest foes in range (one at a lone foe) |
| lancer | Piercing Thrust | 5 / 4 s | a foe in reach | 1.25× its damage to its target and every foe up to `pierce.depth` 2 tiles behind it within 8 of its lane |
| priest | Healing Prayer | 15 / 4 s | the most hurt troop it can reach and `prayer.crowd` 2+ troops within 2 tiles of it (that one too) are below `prayer.hurt` 90% HP | heals every hurt troop within `prayer.reach` 2 tiles of that one by its heal (1×) |
| armored_axeman | Crushing Blow | 5 / 4 s | a foe within `slam.reach` 1.5 tiles | hits each for its damage and stuns each but the boss (any type) and the necromancer for 1 s, a mini boss 0.5 s (`_stunFor`, since #88 branch 2) |
| wizard | Arcane Blast | 20 / 4 s | a foe in reach | one big orb at the nearest: 1.5× its damage over a 32 splash (its normal one is 20) |
| knight_templar | Holy Shield | 10 / 6 s | a troop within `ward.reach` 3 tiles (itself too) fought in the last 2 s and isn't guarded that strongly yet | every troop within 3 tiles, itself too, takes `ward.cut` 20% less damage for 4 s |

The priest's single heals and its Healing Prayer share its MP: the prayer comes first ("Healers" below).

- **Guards** (`Unit.guardUntil`, `guardCut`) cut the damage after defence and the guard relic
  (`_hurt`). A stronger guard a troop already holds stays until it ends (`_guard`): a soldier's own
  Hold Fast isn't weakened by a Holy Shield over it.
- **Rampage** (`Unit.frenzyUntil`) halves the time between attacks (`Game.attackEvery(u)`); the UI
  squeezes the attack animation into it.
- **Stun** (`Unit.stunUntil`): a stunned monster doesn't move or attack (like one casting); MP keeps
  coming back. A boss-rank monster (any type) and the necromancer are never stunned; a mini boss is stunned
  half as long (`_stunFor`).
- **Arrow Rain** and **Arcane Blast** fire ordinary shots (`Shot`); Arcane Blast's carries its own
  damage and splash (`Shot.splash`) and is `big`: it flies as the wizard's ice star and lands with its flash and
  streak (`shards`), the plain shot as a fireball ("The wizard's magic").
- Every hit a skill does goes through `_hurt` with the troop as the attacker: kills, gold, the fang and
  the thorns work as for its normal blows (the fury relic counts only normal blows). Skill heals are
  plain HP, up to the troop's max.
- **Each skill's own look** (#81, decisions-log 117; how they are drawn: ui-hud.md "Skills"): the cast leaves it in
  the game as one of the skills' objects ("Special shots and ground objects", below), so the tests reach it. It
  never changes what the skill does. How long each shows is `skillLook` (s); the reach rings take `ringTime`.

  | Skill | What the cast leaves | For |
  |---|---|---|
  | Hold Fast | `Ring.over` the soldier, radius 12, `RingLook.brace`; its guard's `guardLook` is `brace` | `skillLook.brace` 0.5 s; the guard ring 3 s |
  | Circle Slash | `Ring.over` the knight, radius `slash.reach`, `RingLook.slash` | 0.4 s |
  | Rampage | `Ring.over` the swordsman, radius 18, `RingLook.rage`; the aura is drawn from `frenzyUntil` | 0.5 s; the aura 4 s |
  | Arrow Rain | a `Zone` that only shows (no `inside`, no `pulse`), `ZoneLook.volley`, centred on its targets and wide enough for all (`_volley`) | 0.8 s |
  | Piercing Thrust | a `Beam` from the lancer to `pierce.depth` past its target, `BeamLook.thrust` | 0.3 s |
  | Healing Prayer | a `Ring` round the most hurt, radius `prayer.reach`, `RingLook.prayer`; a `Ring.over` each troop it heals, radius 6, `RingLook.pillar` | `ringTime`; 0.8 s |
  | Crushing Blow | a `Ring` where the axeman stands, radius `slam.reach`, `RingLook.crack` | 0.8 s |
  | Arcane Blast | its shot carries `Shot.ring` `RingLook.arcane`: where it lands, a `Ring` over its splash | `ringTime` |
  | Holy Shield | a `Ring` round the templar, radius `ward.reach`, `RingLook.holy`; a `Ring.over` each troop whose guard it set, radius 9, `RingLook.dome`; their `guardLook` is `holy` | `ringTime`; 0.8 s; the guard ring 4 s |

  - `_guard(o, cut, time, [look])` returns whether it took; one that doesn't (a stronger guard stays) sets no
    look and gets no dome. A Hero skill's guard (Iron Skin, Holy Taunt) sets none: the plain pale ring.
  - Hold Fast, Rampage and Holy Shield no longer show the `upgrade` burst on the caster: that sword-and-plus is
    the items' and awakening's look, and in gold the Hero skills'.

## Skill strips (lib/skill_strips.dart; decisions-log 299)

A skill's cast plays one of the Tiny RPG pack's other attack strips (attack 2 / attack 3, assets.md "Packs → files"),
`tiny_<type>_<anim>.png` at the units' 10 fps (`skillStripFps`), so the body swings with the skill: the owner, "sama
animasi attack 2 dan 3 kenapa tidak di pakai ya, itu paadahal bisa di pakai untuk animation attack ketika skill".

- **What plays** (`SkillStrip`: the file's `anim`, its `entry` frame, its blow on `strike`):

  | Type | #10 skill (and its awakening skill): `troopSkillStrips` | Hero skills: `heroSkillStrips` |
  |---|---|---|
  | soldier | Hold Fast: attack2 0→3 (a leap and an overhead chop) | attack2 0→3 (its attack 3, a bow shot, fits no soldier skill) |
  | knight | Circle Slash: attack2 0→3 (two sweeps) | attack3 4→7 (a flame-charged slash) |
  | swordsman | Rampage: attack3 2→5 (a flurry of thrusts) | attack2 0→3 (a three-cut combo) |
  | archer | Arrow Rain: attack2 6→9 (the charged shot's glow, the release) | attack2 6→9; Snipe 4→9 |
  | lancer | Piercing Thrust: attack2 0→2 (a thrust with a blast of wind) | attack3 1→4 (two fire thrusts) |
  | priest | Healing Prayer: attack2 1→4 (the pack's Attack: the staff raised, then pointed) | attack2 1→4 |
  | armored_axeman | Crushing Blow: attack3 4→7 (the overhead slam into the ground) | attack2 1→4 (a spin); Earthquake attack3 4→7 |
  | wizard | Arcane Blast: attack2 1→4 (the staff overhead, then pointed) | attack2 1→4 |
  | knight_templar | Holy Shield: attack2 2→5 (the spear raised, then brought down) | attack3 4→7 (a sweep, then the smash) |

  The monsters' (`monsterSkillStrips`): attack2 for War Shout, Headbutt, Rally (orc), Swoop, Screech, Swarm (bat), Grave
  Call (skeleton), Pounce, Howl (werewolf), Bone Bash, Iron March (armored skeleton), Spear Throw, Second Wind (orc
  rider), Brutal Swing, Bloodrage (elite orc), Soul Rend, Grave Wave (greatsword skeleton), Maul (werebear), Slime Tide
  (slime), Curse of Frailty, Soul Drain, Death Nova (necromancer), Unholy Ward and Last Rites (the necro healer: the
  boss's recoloured); attack3 for Trample (orc rider), Skull Crusher (elite orc), Bulwark, Ground Slam, Earthshaker
  (armored orc), Blade Dance (greatsword skeleton) and Roar (werebear); the skeleton's `block` for Bone Shield. The
  skeleton archer has no second attack: Volley, Barbed Arrow and Bone Rain play its attack strip; so does the slime's
  Sticky Glob (its attack 2 draws a sword). None for the passive ones (Reassemble, Split, Frenzy, Thick Hide), Shield Up
  (a guard: the armored skeleton has no strip for it) and Mass Mend (the necro healer's cast strip, as before).
- **When** (`Unit.skillAnim`: the strip, `from`, `strikeAt`; set where a cast begins, `Game._playStrip`):
  - a troop's #10, awakening or Hero skill: at the cast, its blow (`strike` − `entry`) / 10 s later (0.2-0.3 s; Snipe's
    on its aim's end, `snipeK.aim`);
  - a monster's: from the start of its wind-up, its blow on the land (`windUntil`): its frames up to the blow at 10 fps,
    from an earlier frame when the wind-up is longer (0 at the earliest, held until the rest fit), from a later one when
    it is shorter (`skillStripFrame`); then on to its last frame. A cancelled wind-up (`_cancelWind`) stops it.
- Nothing in the fight reads `skillAnim`, and it is never saved.
- **The troops' wind-up** (`Game.skillWinds`, `Unit.troopWind`, `SkillWinds` in lib/skill_strips.dart; the owner, asked
  whether a troop's skill should land at its cast or on its strip's blow: "Ancang-ancang beneran", a real wind-up like
  the monsters'): on the board (`boardRules`) a troop's #10, awakening and Hero skills land on the blow, 0.2-0.3 s after
  the cast. The monsters' rules:
  - the MP and the cooldown are paid as it begins (`_try*Skill`, which also logs the cast and pops its name); the
    troop's `troopWind` holds what lands and when (`until`);
  - meanwhile it stands still and does nothing else: no attack, heal, step or other cast (`_troopWindTurn`, before
    `_trySkill` in the tick); its attack cooldown runs on;
  - a stun, a move (a knockback, a drag) or the wave's end cancels it (`_cancelTroopWind`): nothing lands, nothing is
    refunded, its strip stops;
  - on the blow its rule is asked again (MP and cooldown aside: `wantsSkill`, `wantsAwakenSkill` (Impale by its
    target alone, `_impaleTarget`: its cooldown has just begun; Unbroken by a foe in reach alone, `_foeInReach`: a
    knight healed back to full in the wind-up still lands it, decisions-log 320), `wantsHeroSkill`); with nobody to
    land on it fizzles (nothing refunded); else it lands (`_landTroopSkill`): its effect, then its type's `cast` Fx,
    Afterglow's charges and the Bayangan's answers to a cast, all moved from the cast to the blow;
  - an awakening skill's wind-up **claims** what it aims at (`TroopWind.claims` and `at`, `_awakenClaim`;
    decisions-log 320): Spellbreaker's, Disarm's and Impale's foe, the troops Lifeline lifts, Singularity's foe and the
    well's spot, Consecration's ground, Skyfall's landing spot. Another troop of its type passes over a claimed foe or
    troop (`_claimed`), takes no spot within the spacing of a claimed one (`_claimedSpots`: a ground `consecrationK.apart`
    of its radius, a well its radius, a leap the radius) and with nothing else to aim at doesn't start. Before, the
    troops of one type raced for one target, each paid its MP and cooldown, and all but the first fizzled on the blow:
    84% of Spellbreaker's wind-ups, 85% of Lifeline's, 49% of Consecration's;
  - no wind-up for a skill with no strip, Snipe (it aims `snipeK.aim` first anyway; its strip's release is timed to
    that) or a move (Shield Bash, Spear Sweep, Guardian Leap, Death Leap, Cavalry Charge, Chain Hook, Spear Wall:
    `instantHeroSkills`; the movement is the build-up): they land at the cast;
  - a plain `Game()` (the tests', the auto-player's, the replay kit's) has `skillWinds` off: every skill lands at its
    cast and its strip only shows, as before.
- How it is drawn: ui-hud.md "Skills" (the order of a unit's strips, the Hero cut-in's portrait).

## The wizard's magic (lib/wizard_fx.dart; decisions-log 313)

The wizard's shots are the Tiny RPG pack's own magic sheets, not the effect pack's orbs: the owner, "particle yang di
keluarkan sama mage perlu pakai dari dari sheet [Wizard_Attack02_Effect.png] [Wizard_Attack01_Effect.png] kalau mau di
rubah tinggal di filter saja warnanya" (the mage's particles should use these sheets; to change them, filter their
colour). The files are assets.md's `tiny_fx_wizard_*.png`, 100×100 frames facing right (`WizardMagic`).

| Shot | Sheet (the pack's file) | In flight | Where it lands |
|---|---|---|---|
| The plain shot | `tiny_fx_wizard_fireball.png` (`Wizard_Attack02_Effect`) | frames 0-3, the ball with its tail, over and over | 4-6: a dark ball, a burst, a fading puff (0.3 s) |
| Arcane Blast (`Shot.big`) | `tiny_fx_wizard_shards.png` (`Wizard_Attack01_Effect`) | 2-5, the spinning ice star, over and over | 6-9: its white flash, then a streak (0.4 s); the violet splash ring as before |

- **Timing and size:** the pack's 100 ms a frame (`magicFps` 10, its .aseprite's), the flight's loop from the tick the
  shot is first drawn; 1 world unit a sprite px, like the characters (the fireball about 22×15, the star 26×32).
- **Facing:** mirrored to face its flight (a shot at a foe to the left), never turned: a turned sprite's pixels tilt off
  the art's grid, and the fireball's tail, turned up a steep shot, reached 17 under the shot, behind the step from the
  lowest lane. Neither reaches more than 8 under the shot (the old orb's; ui-hud.md "Spawn bar"): the fireball's ball
  is on the shot's place, the star's middle 8 over it.
- **Not used:** the shards sheet's first two frames (the shards gathering, 60×73 px at the pack's size: they covered
  the wizard and its neighbours, and from the lowest lane reached under the step).
- **Where it lands** (`shotHitFx`): a wizard's own shot (`ShotLook.plain`) lands as `fireball` or `shards` (with
  `_awake<level>` for an awakened wizard), drawn at the body like the hit bursts (4 over the foe's place); every other
  shot keeps `hit_<type>` (`_big` for a skill's). The other `hit_wizard` bursts stay the effect pack's: Chain Lightning,
  Frost Storm, Singularity, God's Thunder.
- **Colour:** the sheets' own colours. An awakened wizard's shots and hits take its level's colour (`_awakeFx`, the
  troops' shots' and bursts' tint; Bangkit 4 and 5 Bangkit 3's gold), as its orbs did. Nothing else tints them: no
  element, status, relic or Pusaka of the game colours a wizard's shot.
- **The cast strip:** the pack drew the wizard's attack 2 strip (Arcane Blast's, its awakening skill's and a Hero
  wizard's skills', "Skill strips" above) with its staff glowing orange for its fireball. Here that strip fires the
  star, so its glow is recoloured to the star's blues once at load (`_staffBlue`: #C9512E to #086EC7, #EF6E10 to
  #43B4DF, #DB955A to #7DDDE1, colours found nowhere else in the wizard's strips). The attack strip (the plain shot's)
  keeps its orange, the fireball's.
- **Heroes** that are wizards shoot the same; monsters have no wizard magic.
- The cost: a sprite drawn a shot and a burst a hit, as the orbs were; nothing is made a frame.

## Awakening skills (`AwakenSkill`, lib/awaken_skills.dart; #88)

The owner: "ketika troops awekening troops juga dapat skill baru". The owner's answers to the design (#88's phase 1
report, 2026-09-29): one new skill per troop type, unlocked at Bangkit 1 and stronger at Bangkit 2 and 3; the skills
**use MP**; the nine names below; awakening mid-wave makes the skill ready at once, 0–3 s apart between troops of the
type (decisions-log 124).

- **Who:** every troop of a type that has awakened (`awakenLevel(type)` ≥ 1) has its type's skill at that level
  (`awakenSkillOf(type)`, only `built` ones; `AwakenSkills.awakenOf(u)`), troops bought later too. Nothing is saved:
  the level comes from `upgrades`. `Game.awakenLevel` is kept per type while its item list is the same list at the
  same length (`_levels`), so the book's try-on previews (`priceWith`, `assignPreview`) still read a new level.
- **Names** pop over the caster in the troops' pale blue with the level's ASCII numeral: "Disarm", "Disarm II",
  "Disarm III" (`AwakenSkill.titleAt`; `Game.awakenCasts`, ui-hud.md "Skills").
- **Cost: MP.** A cast costs `awakenCost` 40% of its type's MP pool at its level (`AwakenSkill.costAt`: the base
  pool raised by `awakenMp` a level, as `statsOf` raises it; a Hero's ×3 and the aura don't raise the cost). Every
  type gets back 5% of its pool a second, so a cast is 8 s of its regen at every level, and a full pool pays for the
  #10 skill and the awakening skill once each:

  | Type | MP pool (L1 / L2 / L3) | #10 skill | Awakening skill MP (L1 / L2 / L3) |
  |---|---|---|---|
  | soldier, knight, lancer, armored_axeman | 25 / 30 / 35 | 5 | 10 / 12 / 14 |
  | swordsman, archer | 38 / 45 / 53 | 7.5 | 15 / 18 / 21 |
  | knight_templar | 50 / 60 / 70 | 10 | 20 / 24 / 28 |
  | priest | 75 / 90 / 105 | 15 | 30 / 36 / 42 |
  | wizard | 100 / 120 / 140 | 20 | 40 / 48 / 56 |

  The #10 skill (since decisions-log 298 a quarter of the base pool every 4 s at most) would use more than the
  regen, so the awakening skill's first claim on the MP (below) is what keeps it coming.
- **Cooldown** by level: `awakenCdK` 0.5 of its table (`AwakenSkill.cooldown`; `cooldownAt`, decisions-log 298: the
  troops cast as often as their MP, cooldown and a target allow). The table's: Disarm, Unbroken and Lifeline
  22 / 20 / 18 s, Consecration and Skyfall 22 s, Phantom Rush and Impale 18 s, Spellbreaker 18 / 16 / 14 s,
  Singularity 24 / 22 / 20 s; so a Disarm comes every 11 / 10 / 9 s (the table below gives the halved ones).
- **A target is enough** (decisions-log 298): the crowds are 1 (Singularity was 4, Consecration, Phantom Rush and
  Skyfall 3), Unbroken waits for no low HP (hurt at all: `unbrokenK.low` and `hindered` 1), and Disarm takes any foe
  (`disarmK.worth` 0). What a skill names as its target stays: Lifeline lifts a troop in peril (below 50%), Impale
  pins a strong foe, Spellbreaker strips a foe with a buff; and so does Skyfall's 50% HP before the axeman leaps.
- **Bangkit 4 and 5** (bought with gold, #92 part 2, loot-items-relics.md "Bangkit 4-5") keep Bangkit 3's numbers,
  MP cost and numeral ("Disarm III"; `_at(level)` reads Bangkit 3's entry of every per-level list); only the cooldown
  shortens, ×`ascendSkillCd` 0.85 a level (`cooldownAt`: Disarm 18 → 15.3 → 13 s). The book's skill lines name the
  next one's ("Awaken 4: cooldown 15.3s"). Tempa past Bangkit 5 (decisions-log 163, loot-items-relics.md "Tempa")
  changes no skill: only the type's HP and damage.
- **One cast a tick, and who gets the MP** (`Game._trySkill`): the Hero skill, then the #10 skill, then the
  awakening skill. A type under Vow of Silence (a Legenda Pusaka, decisions-log 231) casts none of the three and
  spends no MP (`_fxSilent`, asked first). When the MP pays for both, the #10 skill casts and the awakening skill on the next tick. When it
  pays for only one, the awakening skill has it: the #10 skill waits while the awakening skill is ready and wanted and
  what the #10 skill would leave doesn't pay for it (`_savingForAwaken`), as a Hero saves for its Hero skill. So in
  a long fight the awakening skill casts about once a cooldown and the #10 skill gets the rest. A Hero saving up for
  its Hero skill (`_savingUp`) spends on neither.
- **Other MP rules** hold as they are: Gift of Mana counts a troop short of MP for its next skill (`mpWanted`, the
  dearer of the two); Soul Rend's lost MP and Mana Shield's soaked MP come off the one pool both skills use; a troop
  Resurrection brings back comes with no MP, so its awakening skill (ready at once) waits for its MP.
- **The clock** (`Unit.awakenSkillAt`): at a wave's start and at the awakening moment (an item completing a recipe
  mid-wave, `useItem`), every living troop of the type is ready by its place among them in the army's order: the
  i-th at t + (i % `awakenSlots` 4) × `awakenStagger` 1 s, so 0–3 s apart, never all on one tick
  (`_staggerAwaken`). A troop placed later is ready at once, as its #10 skill is.
- **Think interval:** when a ready skill's rule says no, the troop doesn't ask it again for `awakenThink` 0.25 s
  (`Unit.awakenThinkAt`). The cheap gates go first: the level, the clock, the MP, then the rule.
- **The march:** one that holds monsters (`AwakenSkill.holds`: Impale, Singularity) never casts while a stalled
  wave marches.
- `Game.awakenSkills` (default true) turns them all off, for probes and tests; off, a game plays as it did before
  them.
- Every blow goes through `_hurt` with the troop as the attacker, like a #10 skill's (kill gold, fang, thorns,
  Void Eye; not the fury relic or God's Thunder).
- **The moment:** when a type awakens, each of its living troops pops the skill's name with the new numeral (no
  cast, no event), and the battle log's awakening line names it ("Soldier: Awaken 2 - Disarm II").
- A cast is the `AwakenSkillCast` event (the battle log: "<name> uses Disarm II"; the telemetry counts it by the
  skill's id, telemetry.md).

The nine (branch 1 built Disarm, Unbroken and Consecration; branch 2 the movers Phantom Rush, Skyfall and Lifeline;
branch 3 the three that act on the monsters' own rules, Impale, Spellbreaker and Singularity; each with the design's
rules):

| Type | Skill (id) | Cooldown L1 / L2 / L3 | Casts when | Does (L1 / L2 / L3) |
|---|---|---|---|---|
| soldier | Disarm (`disarm`) | 11 / 10 / 9 s | a foe in reach (a taunted soldier: only its taunter), not weakened as strongly already (`effectK(o, weaken) > k`), and not Disarmed by any soldier in the last 30 s (`Unit.disarmedAt`, `disarmK.again`; decisions-log 156) | the highest ranked, then the one that hits hardest, then the nearest takes 1.5× / 2× / 2.5× its damage; if it lives it deals 0.9 / 0.85 / 0.8 (the boss rank 0.95 / 0.93 / 0.9) for 6 s (`Status.weaken`) |
| knight | Unbroken (`unbroken`) | 11 / 10 / 9 s | a foe in reach, and hurt and hit in the last 1 s, or hurt under a monster's hindrance (on the wind-up's blow a foe in reach alone, decisions-log 320) | it gets 25% / 30% / 35% of its max HP back, and the other troops within a tile 10% / 12% / 15% of theirs; it throws off every hindrance a monster put on it (`unbrokenFrees`: taunt, daze, bleed, slow, weaken, vulnerable, and a haste that slows); a Duel of Honour names a monster too, and stays |
| swordsman | Phantom Rush (`phantomRush`) | 9 s | a foe in reach, while it isn't taunted or falling back | its round is the foes within 2.5 tiles at the cast, the most wounded by HP share first, then the nearest, then the first placed (never a heap of bones: only holy blows hurt one); 3 / 3 / 4 dashes of 0.2 s, each to 8 beside the next living foe of the round (round again after the last) and a cut there of 1.2× / 1.3× / 1.5× its damage; one cut more while Rampage lasts (`frenzyUntil` at the cast), and one more once a cut kills (once a cast); then back where it stood in 0.15 s. A dash is a `Carry` hop of 1, through everyone; its attack pause doesn't run meanwhile. From its first dash until it is home it is a **phantom** (`isPhantom`): no blow, monster's effect or stun lands on it (decisions-log 320) |
| archer | Spellbreaker (`spellbreaker`) | 9 / 8 / 7 s | a foe in range that no silver arrow is flying at yet, with a monster's buff (`spellbreakerStrips`: might, haste, swift, steadfast, shotWard, absorb, reflect, lifesteal, soulRend, given by no troop) or a guard (Bulwark, Bone Shield, Thick Hide) with 1 s or more left; one it would only halve counts while not halved yet | the highest ranked, then the one with the most, then the nearest gets a silver arrow (`Shot.special`, 720/s) for 1.5× / 2× / 2.5× its damage; landing, it strips the foe, and at Bangkit 2 / 3 every foe within 1 / 1.5 tiles of it: a normal, elite or high-elite foe loses those buffs and its guard; a mini boss or the boss rank, and any foe for a buff the boss rank gave (Rally, Howl), loses half of what is left of each, once (`Effect.halved`, `Unit.guardHalved`). It never touches what troops put on monsters |
| lancer | Impale (`impale`, holds) | 9 s | a foe within its reach + a tile (a taunted lancer: only its taunter): first a **break**, a foe winding up a skill that comes again (a finite cooldown, so never a once-only one: Frenzy, Thick Hide), not the boss rank, not a necromancer (the escort's high elite neither), not stunned, not broken in the last 25 s (`Unit.interruptedAt`); else a **pin**, a strong foe (elite and up) not pinned yet. While a monster it could break stands within 5 tiles it keeps the lance for a break, for 3 s at most after the skill is ready | a lunge for 1.5× / 2× / 2.5× its damage; the lancer stays where it stands. A break picks the highest ranked, then the nearest, then the first placed: its wind-up ends (`_cancelWind`; its cooldown, begun with the wind-up, runs on) and it staggers 0.3 s (`_stunFor`: a mini boss 0.15 s). A pin picks the highest ranked, then the most HP, then the nearest: it walks at 0.1× (the boss rank 0.55×) for 2 / 2.5 / 3 s (`Status.impaled`), and still attacks and casts; no stagger |
| priest | Lifeline (`lifeline`) | 11 / 10 / 9 s | another troop in its reach, 2+ tiles from it, below 50% HP (30% until decisions-log 156), hit in the last 1 s, with a foe within a tile of it, and neither carried, braced nor holding its ground (`holdGround`) | the 1 / 1 / 2 most hurt (by HP share, then the first placed) are each lifted over 0.45 s (a `Carry` hop of 14, taking blows on the way) to 12 beside the priest, never behind the back line (`_troopRear`); landing with the priest alive, each gets 1.5× / 2× / 2.5× the priest's heal (`_healOf`), and `healedAt` and `waitFrom` are now, so the fall-back brain counts it come to its healer. Its priest fallen meanwhile, it lands unhealed |
| armored_axeman | Skyfall (`skyfall`) | 11 s | at 50%+ of its HP, not taunted or falling back, no foe in its reach, and a spot: 6 short of one of its 8 nearest foes 2.5–5 tiles away and ahead, held back to the x of the front-most troop that fought (attacked in the last 2 s) within its radius + a tile of it (there must be one), with a foe within the radius and no other axeman leaping to within the radius of it; the most foes, then the nearest foe | it leaps there in 0.5 s (a `Carry` hop of 22, taking blows in the air); landing alive, each foe within 1.25 / 1.5 / 1.5 tiles takes 1× / 1.25× / 1.5× its damage, and it takes 15% / 20% / 25% less damage for 3 s (`_guard`, the plain guard ring; a stronger guard stays). No stun, no shove |
| wizard | Singularity (`singularity`, holds) | 12 / 11 / 10 s | a foe in range it can pull (`_pullable`: on the field, not the boss rank, not carried, in no open well) | the one with the most, then the nearest, then the first placed: a well opens on that spot (a `Zone` of `Side.enemy`, radius 2 / 2.5 / 3 tiles, 2 / 2.5 / 3 s). Each tick each monster in it drifts toward its centre at 24 / 28 / 32 a second × its `shoveShare` (a mini boss half, the boss rank never), stopping 6 short: always the y part, the x part only away from the base and not for a monster with a troop in its reach. One well pulls a monster a tick (the oldest), none while the wave marches; a pulled monster still walks, fights and winds up. As it closes (`later`), the foes within 1.25 tiles of its centre take 1× / 1.25× / 1.5× the wizard's damage (fixed at the cast) |
| knight_templar | Consecration (`consecration`) | 11 s | a foe within its radius, and no Consecration's centre (anyone's) within 1.5× that radius of it | holy ground at its feet (a `Zone` of `Side.enemy`, radius 1.5 / 1.75 / 2 tiles, 4 / 4 / 5 s): each foe on it takes 0.15× / 0.2× / 0.25× its damage (fixed at the cast) every second, the first at once, 1.25× that on an undead one, with the templar as the attacker while it lives; the blows are holy, as Judgement's (`_holy`): no skeleton reassembles from them, and they end a heap of bones (Reassemble) |

- The numbers are the `<id>K` records (`disarmK`, `unbrokenK`, `consecrationK`, `phantomRushK`, `skyfallK`,
  `lifelineK`, `impaleK`, `spellbreakerK` with `spellbreakerStrips`, `singularityK`), one entry per level.
- **Disarm's window:** one monster is Disarmed at most once in 30 s (`disarmK.again`, counted from the cast, whichever
  soldier cast it; `Unit.disarmedAt`), so it deals less for at most 6 of every 30 s, and a soldier whose strongest foe
  is inside its window strikes the next one. Without it a crowd of soldiers kept the mini boss or the boss weakened
  nearly the whole fight, and the army lost about half as many troops on those waves (qa-3, decisions-log 156).
- **The movers** (branch 2) move only troops, so they cast during a march too. Their moves are `Carry`s
  ("Forced movement"): a carried troop does nothing else and nobody shoves it. The swordsman and the axeman cast
  their own move; Lifeline carries another troop, which a second priest's Lifeline then passes over.
  - Phantom Rush's swordsman is a phantom through its dashes and its way home (`isPhantom`; the owner, asked what to do
    about the swordsmen dying mid-rush: "Hantu: kebal saat melompat", a ghost, immune while it leaps; decisions-log
    320): `_hurt` lands nothing on it, and neither a monster's effect (`addEffect`'s `bad` ones) nor its stun
    (`stunTroop`) takes. It is the one carried troop that takes no blows. Until then 15-21% of rushes ended with the
    swordsman dead in the rush, most from full HP: the round hops it among the monsters' front, and every monster
    there makes it its nearest troop.
- **The three that act on the monsters' rules** (branch 3) keep the monsters' guard rails:
  - Only Impale cuts a monster's skill short, and at most once in 25 s on one monster (`impaleK.window`). Its break
    stuns only through `_stunFor`, so never the boss rank or a necromancer, a mini boss half as long. It never
    breaks a once-only skill: that skill's cooldown starts with its wind-up and is infinite, so a broken Frenzy or
    Thick Hide would be lost for good. No awakening skill resets or refunds a cooldown, and nothing silences.
  - The boss rank is never stunned, pulled or interrupted; it takes half a pin, and Spellbreaker only halves what is
    left of its buffs. A mini boss is pulled at half, staggered at half, and its buffs are halved, never stripped.
    Buffs from the boss rank (its moments' Rally and Howl, its War Shout) are only halved, on any monster.
  - The escort (#90): its high-elite necromancer is never broken (a necromancer) but may be pinned; its healing
    necromancers' Mass Mend may be broken like any skill; an Unholy Ward names no giver, so on a normal monster
    Spellbreaker strips it, and on the escorted boss halves it.
  - Impale and Singularity hold monsters (`AwakenSkill.holds`): neither casts during a march, and a well pulls
    nothing while one runs, so the stall watchdog stays in charge.
- **Looks** (ui-hud.md "Skills"): Disarm `Ring.over` the foe, `RingLook.shards` 0.5 s, then Disarm's weaken shows as
  the purple weaken ring for its 6 s; Unbroken `Ring.over` the knight, `RingLook.unchain` 0.6 s, and the heal burst on
  each troop it heals; Consecration its zone, `ZoneLook.consecrate`, and on each pulse the templar's hit (on an
  undead one the `holy` burst); Phantom Rush a `Beam` per dash (`BeamLook.rush`, 0.5 s), a `Ring.over` each foe it
  cuts (`RingLook.crossCut`, 0.3 s) with the swordsman's hit, and its afterimages while it dashes (`Carry.look`
  `CarryLook.ghost`), Sfx.dagger a cut and Sfx.sword the last; Skyfall its landing shadow while it is in the air
  (`CarryLook.skyfall`, `Carry.radius`), then a `Ring` where it lands (`RingLook.crater`, 0.8 s), the axeman's big
  hit there and its hit on each foe, Sfx.sword; Lifeline a `Beam.between` the priest and each troop it lifts
  (`BeamLook.tether`, 0.7 s), the troop's hop, and as it lands the `heal` burst and a `Ring.over` it
  (`RingLook.bloom`, 0.6 s), Sfx.magic; Impale a `Beam` from the lancer to the foe (`BeamLook.lunge`, 0.3 s) with the
  lancer's big hit, a break's `Ring` of shards (`RingLook.shatter`, 0.5 s) and Sfx.hit, and the pinned foe's dashed
  chartreuse ring with the lance stuck through it while the pin lasts, Sfx.sword; Spellbreaker its silver arrow
  (`ShotLook.silver`), Sfx.dagger, and where it lands a broken rune ring (`RingLook.dispel`, 0.5 s, as wide as its
  spread) and Sfx.hit, the stripped buffs' rings gone on that frame; Singularity its well (`ZoneLook.singularity`),
  Sfx.magic, and as it closes a `Ring` collapsing into its core (`RingLook.implode`, 0.4 s), the wizard's big hit
  there and its hit on each foe, Sfx.hit.
- **Balance:** decisions-log 124 (branch 1), 131 (branch 2) and 134 (branch 3).

## Hero skills (`HeroSkill`, lib/hero_skills.dart)

The owner (#48): "setiap jenis troops yang jadi hero punya skill unique random untuk setiap type troops kamu
coba sediakan 5 jenis skill unik untuk setiap jenis troops"; the 45 proposed were approved, "setuju tapi pakai
bahasa inggris": their names and lines are English (the #10 skills are English too since #73, decisions-log 100).

- **The roll:** a new Hero rolls one of its type's skills (`heroSkillPool(type)`: the `HeroSkill`s of that
  type that are `built`) with the `heroes` dice, right after its 2 attributes: crown pick, attribute,
  attribute, skill. It keeps it for life (saved, Heroes above). Each skill has a `title` (its English name;
  `name` is the id the save keeps), a `desc` line, a `mark` icon (`HeroMark`), an MP `cost` and a `cooldown`.
- **Casting** (`_tryHeroSkill`, called from `_trySkill`, so only during a wave, before the #10 skill; one
  cast a tick): it casts by itself when its rule holds (`wantsHeroSkill(u)`, which changes nothing), it has the MP
  and `heroCdK` 0.5 × `cooldown` s have passed since its last (`Unit.heroSkillAt`; decisions-log 298). It pays the
  MP, shows the gold `upgrade` burst, and is queued in `Game.heroCasts` for the UI (its title pops over it in gold
  on its first cast of a wave; #51's cut-in, ui-hud.md, hooks there too, at most one per Hero every 20 s).
  - **Ready at every wave's start:** `startWave` clears `heroSkillAt`, and MP starts every wave full. The
    cooldowns (20–45 s in the table, so 10–22.5 s) make it a Hero's two to four big moments a wave, next to
    its #10 skill; Resurrection's is infinite: once a wave.
  - **A target is enough** (decisions-log 298, "Spam penuh"): every `crowd` in the `<id>K` records is 1 (War Cry,
    Plunder, Bloodlust, Blessing, Holy Nova, Gift of Mana, Iron Skin, Earthquake, Exorcism, Whirlwind, Giant's Rage,
    Holy Taunt, Bastion, War Banner, Piercing Shot, Axe Throw (`crowd` and `few`), Chain Lightning, Frost Storm,
    Spear Sweep, Spear Wall: they were 2-4); every `below` that waited for the Hero's own low HP is 1, hurt at all
    (Bloodlust, Last Stand, Giant's Rage, Holy Taunt's ally, Bastion, Shield Bash), and Blessing's `hurt` 1; a foe's
    `worth` in HP is 0 (Cleave, Deep Wound: Cleave strikes a foe that outlasts its blow first, else the nearest). What
    a skill names as its target stays (a strong foe, a dying or badly hurt ally, a fallen troop, Execute's foe under
    25%), and so does every `above` that keeps a Hero from leaping or giving HP while low itself (Sacrifice, Shared
    Wounds, Guardian Leap, Death Leap).
  - **Saving up:** while its Hero skill is ready and wanted but its MP is short, the Hero doesn't spend MP
    on its #10 skill or its awakening skill (`_savingUp`); when the Hero skill isn't wanted, they cast as always.
  - **The march:** while a stalled wave marches (`Game.marching`, #39) a skill that moves, holds or
    redirects monsters (`HeroSkill.holds`) doesn't cast, and a slow no longer slows a marching monster:
    the stall watchdog stays in charge.
    - What was cast just before the march still runs its course: a stun already on a monster holds it
      (`tick` checks the stun before the march), and a Spear Wall braced before the march still stuns each
      monster coming into its reach, for up to its 5 s. Accepted as is (2026-09-28): it is short, and the
      march still ends the wave.
  - `Game.heroSkills` (default true) turns them off, for probes and tests (`Game.skills` turns off the #10
    ones).
- **The effect store:** what a Hero skill leaves on a unit, troop or monster, is a timed `Status` in
  `Unit.effects` (an `Effect`: until when, its strength `k`, the caster `by`, uses or ticks `n`).
  `addEffect(u, s, time, k:, by:, n:)` puts one on (a stronger one of the kind still running stays, one as
  strong is renewed); `under`, `effectK` and `effectOn` read them. Its time goes through the duration scaler, its one
  place (`_effectTime` in lib/pusaka_engine.dart, `scaledEffectTime`; decisions-log 182): 1 today, so every effect
  lasts what it says. The catalog's Unshaken, Mark Ward and Lingering will scale it; a shortened one never lasts under
  `effectTimeFloor` 0.3 s, or its own time when that is shorter. A stun (`stunUntil`, `_stunFor`) is no effect and
  doesn't go through it. Every effect ends when the wave does
  (`_endEffects`, which also drops what `later` still holds), and none is saved. Where each is felt:
  - `haste` (the pause between attacks and heals ×k, `attackEvery`), `might` (damage dealt ×k, before the
    target's defence), `weaken` (damage dealt ×k: a monster's under a Hero's curse, a troop's under a monster's
    skill, #59; its blows, shots and skills alike), `vulnerable` (damage taken from the other side ×k, after
    defence: a monster's from troops, a troop's from monsters, #59; a blow with no attacker, like a bleed
    whose source fell, doesn't count), `range` (×k, a stat effect: the troop is refit when it starts and
    ends), `slow` (walking ×k), `impaled` (a monster's walking ×k under Impale's pin, #88, or Ice Grip's hold at 0:
    apart from `slow`, so each keeps its own; `steadfast` and a march ignore both; the lance is drawn only for a
    lancer's pin), `voidMark` (damage taken from troops ×k, after
    defence, beside `vulnerable`: Void Eye's mark, decisions-log 138, so it stacks with Hunter's Mark; a violet
    ring), `pusakaMark` (the same, Vengeance Mark's mark on the monster that hit its troop, decisions-log 231; a rose
    ring), `noHeal` (a monster heals nothing, and a skeleton doesn't reassemble: "Cleanse and noHeal");
  - `Effect.bad`: a monster put it on this troop, so a troop's cleanse ends it ("Cleanse and noHeal");
  - `Effect.halved`: Spellbreaker (#88) has halved what was left of it, so it never halves it again;
  - in `_hurt`: `link` (another troop takes k of each blow, before defence: Shared Wounds', Guardian Chain's; a troop
    already passing that same blow on through its own link takes no share of it back, `Game._linking`, so two links on
    each other never loop), `duel` (with its foe `by`: it
    deals it k× before defence, and takes `duelK.cut` less from it after), `cap` (no blow over k of the max
    HP; at 0 a no-damage window: the Grail's save, Soul Shelter's, the Bayangan Deathless's, which a Side Swing hit
    meets too), `block` (the next n melee blows do nothing, each answered with k × its damage), `absorb` (an HP pool
    soaked first), `manaShield` (MP soaked first), then `lifesteal` (the attacker heals k of what it dealt),
    `killHeal` (a kill gives the attacker k of its max HP back) and `reflect` (k of a melee blow back, like
    the thorns; Mirror Shield's lasts the wave, from the troop itself, and comes back when a stronger one ends);
  - `heal` (k HP a second) and `bleed` (k damage every whole second, n times, from `by`) in `_tickEffects`;
  - `taunt` (a monster's foe is `by`, `_nearestFoe`; a healer monster mends and ignores it), `holdGround`
    (no falling back, `_fallBackTo`), `noShove` (holds its ground in the separation step; against another troop
    not when it gave it to itself: Anchor's whole-wave stand, the Pusaka's, holds against the monsters only, so its
    troops still make way for each other), `plunder` (kills
    near it pay k more gold), `giant` (max HP ×k and splash ×`giantRageK.splash`, a stat effect: the HP
    grown comes with it, and when it ends the HP is only capped, so it never kills), `hex`
    (a monster is a slime: its own stats wait in the effect's `was`, swapped back when it ends or its wave
    does; it dies a slime).
  - `later(delay, f)` runs `f` after `delay` s in the wave (staggered hits).
- **Guard rails:** no skill makes a Hero untouchable (damage cuts of 30% at most, short blocks and caps),
  a boss-rank monster (any type, #58) is never stunned, shoved, pulled or hexed and takes half a slow or curse
  (a mini boss: half a shove and half a stun, never hexed; the necromancer is never stunned either), and the
  revive never brings back a Hero.
- Every hit goes through `_hurt` with the Hero as the attacker, like a #10 skill's.

The first 33 (branch 1's 18; branch 2a's 7 that move units, in lib/hero_moves.dart: Forced movement, below;
branch 2b's 8 built from the special shots and ground objects, below; the numbers are the `<id>K` records beside
them). "Foes" and "in reach" as for the #10 skills; "elite or higher" includes the boss; "ahead" is towards the
monsters (right); a stun is `_stunFor`'s, below:

The cooldowns in the tables are `HeroSkill.cooldown`; a Hero waits `heroCdK` 0.5 of them (decisions-log 298).

| Type | Skill (id) | MP / cooldown | Casts when | Does |
|---|---|---|---|---|
| soldier | Shield Bash (`shieldBash`) | 15 / 30 s | an elite or higher foe in reach but the boss; or, hurt, any foe in reach | the nearest such takes a blow for 2× its damage, is knocked back 1 tile and stunned 1.5 s (the boss, met when it is hurt, only the blow) |
| soldier | War Cry (`warCry`) | 15 / 40 s | a troop within 3 tiles (itself too) fought in the last 2 s | each troop within 3 tiles attacks (and heals) 25% faster (pause ×0.8) for 6 s |
| soldier | Plunder (`plunder`) | 15 / 40 s | a foe within 3 tiles | for 8 s every monster killed within 3 tiles of it pays 50% more gold, rounded up (raised minions still pay nothing); the UI floats "+N" |
| knight | Cleave (`cleave`) | 15 / 25 s | a foe in reach (one that outlasts the blow first) | one blow for 3× its damage; a kill gives back half the MP |
| knight | Guardian Leap (`rescueLeap`) | 20 / 30 s | above 40% HP, a foe within 5 tiles and out of its reach that is within 1 tile of a troop healer or long-range troop | it leaps beside the nearest such, then a blow for 2× its damage and a 1 s stun |
| knight | War Banner (`banner`) | 20 / 45 s | a troop within 3 tiles (itself too) fought in the last 2 s | a banner (a `Zone`) at its feet for 10 s: every troop within 3 tiles of it deals 20% more damage (`might` 1.2, lingering 0.25 s after it steps out; heals aren't raised). It stays where it was planted |
| swordsman | Execute (`execute`) | 15 / 20 s | a foe in reach below 25% of its HP, not the boss or a mini boss | it dies at once (gold, score and loot as usual) |
| swordsman | Bloodlust (`bloodlust`) | 20 / 40 s | hurt, with a foe within 2 tiles | for 6 s it heals 40% of the damage it deals |
| swordsman | Death Leap (`deathLeap`) | 20 / 35 s | above 40% HP, a healing necromancer or skeleton archer within 5 tiles and out of its reach | it leaps beside the nearest such, a blow for 2.5× its damage, and fights on there; the one movement skill that casts on a march |
| swordsman | Deep Wound (`deepWound`) | 15 / 25 s | a foe in reach, not bleeding | a cut for 1× its damage, then 1× every second for 4 s |
| archer | Eagle Eye (`eagleEye`) | 20 / 40 s | a monster that shoots or heals within 1.4× its range, out of it | range ×1.4 and damage ×1.3 for 8 s |
| archer | Hunter's Mark (`huntersMark`) | 15 / 35 s | an elite or higher foe in range, not marked | the one with the most HP takes 25% more from troops for 8 s (the boss 15%) |
| archer | Snipe (`snipe`) | 20 / 30 s | a healing necromancer within 1.5× its range, or an elite or higher there | aims 0.5 s (no other shots; `Unit.cd`), then one arrow at the healer (the nearest), else the highest rank (the most max HP of a rank) for 5× its damage (`trail` look, big hit); none if either fell meanwhile |
| archer | Crippling Shot (`crippleShot`) | 15 / 25 s | a foe in range, not slowed yet, faster than the archer walks (`walkSpeed`) or within 1 tile of a troop healer | an ice arrow (`ice`) for 1.5× its damage that slows the foe to 50% for 5 s (the boss 75%) |
| archer | Piercing Shot (`pierceShot`) | 20 / 30 s | a foe within half a tile of the line through its nearest foe, out to 2× its range | a `LineShot` along that line out to 2× its range at 320/s (`long`): 2× its damage to each foe it passes |
| lancer | Cavalry Charge (`charge`) | 20 / 35 s | no foe within 3 tiles, and a foe ahead 3–6 tiles away with no other troop within 8 of the way there | it charges the farthest such at 3× its speed (its stat: the walk cap isn't in it): each other foe within 8 of its path takes 1× its damage and is shoved half a tile aside; the target 2× and a 1 s stun |
| lancer | Spear Wall (`spearWall`) | 15 / 35 s | no foe in reach, and a foe ahead within 3 tiles | it braces 5 s: each foe coming into its reach takes 1.5× its damage and a 1 s stun |
| lancer | Spear Sweep (`sweep`) | 15 / 25 s | a foe ahead in reach | each foe ahead within its reach + half a tile takes 1× its damage and is knocked back 1 tile |
| lancer | Flurry (`flurry`) | 15 / 25 s | an elite or higher foe in reach | three thrusts 0.2 s apart: 1×, 1× and 2× its damage |
| lancer | Javelin (`javelin`) | 15 / 25 s | none in its reach and a foe 2–5 tiles away | a spear (`spear`, big hit) at 220/s at the one with the most max HP there, for 2.5× its damage |
| priest | Blessing (`blessing`) | 30 / 40 s | a hurt troop in its reach | every troop in its reach gets 2% of its max HP back a second for 8 s |
| priest | Holy Nova (`holyNova`) | 40 / 35 s | a dark monster in its range, or the boss | each dark monster in its range takes 2.5× its heal × `holyShare` |
| priest | Gift of Mana (`manaGift`) | 30 / 40 s | a foe on the field and another troop in its reach short of MP for its skill (the #10 skill's cost, or the awakening skill's when that is dearer: `mpWanted`) | every other troop in its reach gets 15 MP |
| armored_axeman | Iron Skin (`ironSkin`) | 15 / 35 s | hit in the last 1 s with a foe in reach | a 15% guard (as Hold Fast's) and 60% of each melee blow sent back, for 6 s |
| armored_axeman | Earthquake (`quake`) | 20 / 40 s | a foe within 3 tiles | each takes 0.75× its damage and walks at 60% (the boss 80%) for 4 s |
| armored_axeman | Chain Hook (`hook`) | 20 / 35 s | a skeleton archer or healing necromancer 2–5 tiles away and out of its reach, not a mini boss or the boss | the nearest such is dragged beside it (it stands meanwhile), then a blow for 1× its damage and a 1 s stun |
| armored_axeman | Axe Throw (`axeThrow`) | 15 / 30 s | a foe within half a tile of the line ahead out to 4 tiles | a boomerang `LineShot` straight ahead 4 tiles and back at 128/s (1 s, `spin`): 1× its damage to each foe going out and again coming back |
| wizard | Curse of Weakness (`curse`) | 30 / 35 s | an elite or higher foe in range, not weakened as strongly (a disarmed foe's milder weakness still takes it, #88) | the one that hits hardest deals 60% and walks at 80% (the boss 80% / 90%) for 8 s |
| wizard | Chain Lightning (`chainLightning`) | 40 / 30 s | a foe in range | a chain strike from the nearest, 4 jumps of up to 2 tiles: 1.2× its damage, 15% less at each jump (1.2, 1.02, 0.87, 0.74, 0.63) |
| wizard | Frost Storm (`frostStorm`) | 50 / 40 s | a foe in range | a frost `Zone` of 2 tiles round it (the nearest such foe) for 5 s: foes inside walk at 50% (the boss 75%; lingering 0.25 s) and take 0.3× its damage every second |
| knight_templar | Judgement (`judgement`) | 25 / 30 s | a foe in reach that is dark, or elite or higher | a holy blow for 2× its damage, 4× on a dark one |
| knight_templar | Sacrifice (`sacrifice`) | 20 / 30 s | above 60% HP, another troop within 3 tiles below 25% | gives the most hurt one 25% of its HP (no more than it lacks) |
| knight_templar | Exorcism (`exorcism`) | 30 / 40 s | a raised minion within 3 tiles | the normal and elite ones crumble; a stronger one takes 3× its damage |

Ten more that change the damage rules or what units do (branch 2c). "Hit" means it took a blow in the last
1 s (`Unit.hurtAt`); "fighting" that a monster attacked in the last 2 s:

| Type | Skill (id) | MP / cooldown | Casts when | Does |
|---|---|---|---|---|
| soldier | Last Stand (`lastStand`) | 10 / 45 s | hurt, with a foe in reach | for 6 s it doesn't fall back to a healer (`holdGround`), deals 1.5× damage, and every kill gives it 20% of its max HP back |
| soldier | Parry (`parry`) | 15 / 35 s | hit, with a melee foe in reach | the next 3 melee blows within 5 s do nothing, each answered with 1.5× its damage; shots get through |
| knight | Duel of Honour (`duel`) | 20 / 40 s | an elite or higher foe within 2 tiles (not a healing necromancer, nor a necromancer raising the dead) | the highest-ranked one (a tie: the most HP) fights only the knight for 8 s while it lives (`taunt`); the knight deals it 1.5× and takes 30% less from it |
| knight | Shared Wounds (`shareWounds`) | 20 / 35 s | above 50% HP itself, another troop within 3 tiles below 30% that was hit and isn't linked | for 6 s the knight takes half of every blow the most hurt such troop takes (before defence: each side's own defence and guards apply) |
| swordsman | Whirlwind (`whirlwind`) | 25 / 35 s | a foe within 1.5 tiles | 4 cuts 0.5 s apart (the first at once), each foe within 1.5 tiles taking 0.7× its damage a cut (2.8× in all); its own attacks wait the 2 s, it can still walk |
| priest | Veil of Light (`lightVeil`) | 25 / 30 s | a troop in its reach below 50% that was hit and isn't veiled | the most hurt one gets a veil soaking 4× its heal of damage (48; ×3 with power) within 8 s |
| armored_axeman | Giant's Rage (`giantRage`) | 20 / 45 s | a foe within 2 tiles, or hurt with a foe in reach | for 8 s its max HP is ×1.5 (and it gains that HP) and its cleave (splash) ×1.5; drawn 1.3× as big |
| wizard | Mana Shield (`manaShield`) | 20 / 40 s | a foe within 2 tiles, or hit | for 8 s what it takes comes off its MP first, 1 MP a point, until the MP runs out |
| knight_templar | Holy Taunt (`holyTaunt`) | 30 / 40 s | another troop within 3 tiles hurt and hit, or a foe within 3 tiles fighting another troop | every monster within 3 tiles (not a healing necromancer, nor a necromancer raising the dead) fights the Templar for 5 s, and it takes 25% less (a guard, as Hold Fast's) |
| knight_templar | Bastion of Faith (`bastion`) | 30 / 45 s | the boss or a mini boss in reach, or hurt with a foe in reach | for 5 s no blow takes more than 8% of its max HP (27 of its buffed 336), and nothing shoves it (a longer stand already on it, Anchor's, stays) |

Duel of Honour and Holy Taunt turn monsters, so they never cast during a march.

The rare two (branch 3), both approved as designed ("<name> rises again!", once a wave):

| Type | Skill (id) | MP / cooldown | Casts when | Does |
|---|---|---|---|---|
| priest | Resurrection (`revive`) | 60 / once a wave | a troop fell this wave within its reach that isn't a Hero and was never brought back, and the army is under its capacity | the one that fell last comes back (a new `Unit`: same type and name, its drop spot, no relic: that went to the bag) where it fell, but no further forward than a tile ahead of the priest, with 30% HP and no MP. It rises over `riseTime` 0.5 s like a raised minion (drawn as its death strip backwards), comes off `fallen` (so off the win popup's list), is marked `revived` (saved: never again), and the message window says "<name> rises again!" (`Game.risen`), the one Hero skill that speaks |
| wizard | Slime Hex (`slimeHex`) | 50 / 45 s | an elite or high elite in range, not a necromancer or a healing necromancer, not hexed | the one that hits hardest is a slime for 5 s: a slime's stats for the wave (normal tier) but its own gold, and its rank (score, loot, bar colour); its share of HP carries over both ways. Killed as a slime it pays its own gold and score and dies a slime. It holds a monster, so never during a march |

With these, all 45 Hero skills are built and rolled.

## Special shots and ground objects (lib/hero_shots.dart)

The pieces #48's Hero skills `snipe`, `crippleShot`, `pierceShot`, `javelin`, `axeThrow`, `chainLightning`, `frostStorm` and `banner` are built from (branch 2b; the skills are in "Hero skills" above). Every hit they do
goes through `_hurt` with the shooter as the attacker, like a skill's.

- **A special shot** (`Shot.special(from, target, pos, dmg:, speed:, splash:, big:, look:, onHit:)`): a
  `Shot` with its own damage, speed and look (`ShotLook`), so a melee troop can throw one (its type's
  `shotSpeed` is 0). Like every shot it homes on its target however far away, so it can be fired past the
  shooter's range, and flies on to where its target went if that falls first ("Fighting rules", decisions-log 327). `onHit` runs on each unit it hurt, after the damage (with splash, on each one in it).
  A plain `Shot` has no speed of its own (`speed` null: the shooter's `shotSpeed`), the `plain` look and
  no `onHit`, so the normal attacks and #10's skills fly as before.
- **A line shot** (`LineShot`, in `Game.lineShots`): flies a straight line from `start` towards a point,
  `length` far at `speed`, instead of homing. Every foe (a living unit of the other side) within `width`
  (default `lineWidth`, half a tile) of its path is hit once as it passes: `dmg`, the shooter's
  `hit_<type>` burst, then `onHit`. It keeps flying through them and stops at the end of its line. Its
  path is on the ground, like the units' positions.
  - A `boomerang` turns at the end of its line and flies back to its thrower, where it stands now (to
    `start` if the thrower fell), hitting each foe on the way once more: a foe on its path is hit going
    out and again coming back. What is left of the step that reaches the end goes on home.
- **A chain** (`Game.chainFrom(first, jumps:, radius:)`): `first`, then again and again the living unit
  of its side nearest the last one, within `radius` of it and not in the chain yet, `jumps` times at most
  (fewer when none is near enough). `Game.chainStrike(from, first, dmg:, jumps:, radius:, falloff:)` picks
  the whole chain first, then hurts its i-th unit (0 = `first`) for dmg × (1 − falloff)^i with `from`'s
  hit burst, and shows a `Beam` from `from` through them for `chainBeamTime` 0.3 s.
- **A zone** (`Zone`, in `Game.zones`): a patch of ground round `at`, `radius` wide, for `duration` from
  `since`. Each living unit of its `side` inside it gets `inside` every tick and `pulse` every `every` s
  (default 1), the first pulse on the first tick it is there, `pulses` in all (5 for 5 s). A unit that
  walks out gets neither. It stays where it was placed; it goes when its time is up, and every zone goes
  when a wave ends.
- **A beam** (`Beam`, in `Game.beams`): a line through points (on the ground, like the units') that the
  UI draws from `since` until `until`; the game drops it then. One made `Beam.between(units, ...)` runs
  through those units where they are now (`Beam.at`), for a beam that lasts seconds (a drain), and goes as
  soon as one of them falls (`Beam.broken`).
- **A ring** (`Ring(at, radius:, since:, look:, [duration])`, in `Game.rings`; #59): a ring the UI draws
  on the ground round `at` over `radius` for its duration (`ringTime` 0.6 s unless given; the pack's ground
  circle, ui-hud.md), for a shout or a slam. The game drops it when its time is up. Its colour is a `RingLook` (pale,
  grey, dark, dust, red, orange, bone, brown, steel), which also colours a unit's guard ring
  (`Unit.guardLook`).
  - `Ring.over(u, ...)` (#81) stays on unit `u` as it moves (`Ring.centre`) and goes as soon as `u` falls
    (`Ring.broken`), like a `Beam.between`.
  - The troops' skills' looks (#81: brace, slash, rage, prayer, pillar, crack, arcane, holy, dome; "Troop
    skills" above) are `RingLook`s too, each its own shape in its own colour; the UI draws them (ui-hud.md).
- **A zone that only shows** (#81): one with neither `inside` nor `pulse` acts on nobody. Arrow Rain's
  (`ZoneLook.volley`) is one; it still goes at the wave's end with the others.
- **A shot's ring** (`Shot.ring`, #81): where the shot lands, a `Ring` of that look bursts out over its splash
  (at least a tile): Arcane Blast's violet blast.
- **The monsters' looks** (#59; the skills that use them come with #59's later branches): `ShotLook.glob`
  (a slime's Sticky Glob), `ZoneLook.slime` (Slime Tide's puddle), `ZoneLook.arrowRain` (Bone Rain),
  `BeamLook.drain` (Soul Drain), and the rings. A monster's special shot, zone pulse or beam blow hurts
  through `_hurt` with the monster as the attacker, like a Hero's, so a troop's `vulnerable` counts it.
- None of them is saved: saves are made between waves.

## Forced movement (`lib/hero_moves.dart`; #48)

The seven movement Hero skills (the table above) build on these, with their numbers from each skill's
`<id>K`. Since #59 they work the other way too, for the monster skills to come: a monster leaps or charges
at the troops, a troop is knocked back or dragged, a troop is stunned (within limits, `stunTroop`). `hero_skills.dart` sends each to `_wantsMove` (its rule and its target, `_bashTarget`,
`_rescueTarget`, ...) and `_castMove`; a leap's, a charge's and a hook's blow lands when the move gets there
(`_landOn`: nothing if either is dead by then). A Hero that a cast has just set moving does nothing else that
tick.

- **Carried** (`Unit.move`): a unit moved by something other than its own legs.
  - While carried it does nothing else: no walking, no blows, no casting. It still takes blows, except Phantom
    Rush's swordsman, a phantom from its first dash until it is home (`isPhantom`, "The movers" in Awakening skills;
    decisions-log 320). Its attack pause (`Unit.cd`) doesn't run meanwhile either.
  - The awakening skills' movers (#88 branch 2) are carries too: Phantom Rush's dashes (0.2 s, a hop of 1) and its
    way back (0.15 s), Skyfall's leap (0.5 s, a hop of 22) and Lifeline's lift of another troop (0.45 s, a hop of
    14, never behind the back line). `Carry.look` (`CarryLook`: plain, `ghost`, `skyfall`) and `Carry.radius`
    are for the drawing only (the afterimages, the landing shadow).
  - Nobody shoves it, and a troop doesn't step aside for anyone (`_firm`). A unit that bumps into it takes
    the whole push, as with a healer mid-cast.
  - It goes before the stun check in `tick`, so a stunned unit can still be knocked back.
  - Moves aren't saved: saves come between waves.
- **Knockback** (`knockBack(o, dist, [dir])`): unit `o` slides `dist` along `dir` over `slideTime`
  0.15 s. `dir` defaults to away from its foes: a monster away from the base (right), a troop towards it
  (left).
  - `shoveShare`: the boss (tier `boss`) isn't moved at all, and a mini boss goes half as far. A Hero goes
    `heroShoveShare` 0.5 as far, as a stun on it lasts half (#59); any other troop the whole way.
  - A monster never ends past the right edge (`rightLimit`, #42), a troop never behind the back line
    (`_troopRear`: `_rearEdge`, max(baseX, cam + `keepUpShift`), plus `clearOfLine`). One already past
    it isn't pushed further out.
  - A troop holding its ground isn't moved at all (`_shoveProof`: carried already, braced, or under
    `noShove`; one under Anchor's stand counts it for the Pusaka, `_fxStood`, a drag too). A monster always is, by
    its share.
  - It stays inside the field's rows.
- **Leap** (`leap(u, to, [onLand])`): unit `u` (a troop, or since #59 a monster) hops to `to` in `hopTime`
  0.35 s, facing it, and `onLand` runs as it lands.
  - The arc rises `hopHeight` 10 at its middle (`Move.liftAt`). Only the drawing shows it: the body and its
    bars rise and walk in the air, while the shadow and the rings stay on the ground.
  - In the air it bumps into nobody: separation skips it (`_passesThrough`).
- **Drag** (`drag(o, to, onEnd:, by:)`): unit `o` is pulled to `to` over `dragTime` 0.3 s, then `onEnd`
  runs. It never drags the boss, nor a troop holding its ground (as with a knockback), and never takes a
  troop behind the back line. `by` is who pulls it, for the drawing (Chain Hook's chain); the axeman
  stands carried in place while it pulls.
- **A well's pull** (Singularity, #88 branch 3; `_pull`, its `Zone.inside`) is no move: a monster in it drifts a
  little each tick toward the well's centre and goes on walking, fighting and winding up meanwhile. By its
  `shoveShare` (the boss rank never, a mini boss half), never one carried, never while the wave marches, by one well
  a tick (the oldest over it). Only its y part moves a monster that has a troop in its reach, and its x part only
  takes a monster away from the base, so a well never brings one nearer the base. It stays inside the field's rows.
- **Where a leap or drag ends** (`beside(target, from, gap)`): `gap` from the target, on the side
  towards `from`.
- **Charge** (`charge(u, target, speed:, lane:, hit:, shove:, [onArrive], [onPass])`): unit `u` (a troop,
  or since #59 a monster) runs at the target, re-aimed each tick, at `speed` × its own.
  - Every other foe of it (a monster for a troop, a troop for a monster) within `lane` of its path is met
    once: `hit` × its damage (through `_hurt`, with the `hit_orc_rider` dust; none at `hit` 0), then
    `onPass` on it if it still lives (a skill's own capped blow, or a stun), then a knockback `shove` to the
    side of the path it stands on (towards the field's middle when it's dead on the line).
  - It runs through the others: separation skips it (`_passesThrough`), so those on its path are met by
    the charge, not bulldozed ahead of it.
  - With the target in its reach it stops, and `onArrive` runs.
  - If the target dies first, `chargeMaxTime` 2 s passes, or the charger is stunned (#59: a monster's
    Trample under Crushing Blow, a troop's Cavalry Charge under a monster's stun), it just stops.
- **Stun** (`_stunFor(o, time)`): the monster stands frozen for `time` s (`Unit.stunUntil`, as with
  Crushing Blow). Never the necromancer or the boss; a mini boss half as long.
- **A troop's stun** (`stunTroop(o, time)`, #59, for a monster's skill): the troop stands frozen the same
  way, for at most `troopStunK.most` 0.8 s, a Hero `troopStunK.hero` half of that. It is then immune for
  `troopStunK.immune` 4 s after the stun ends (`Unit.stunImmuneUntil`): a stun meanwhile does nothing, so no
  stun-lock. It returns whether it took. It stops only what the troop would start: blows its skill already
  queued with `later` (Whirlwind's cuts, Flurry's thrusts) still land.
- **Brace** (`brace(u, time, [onMeet])`, `braced`): troop `u` doesn't move (`_moveToward` returns) and
  isn't shoved or stepped aside.
  - It still fights from where it stands.
  - `onMeet` runs once for each monster that comes into its reach, including those already in it.
  - It holds only during a wave.

## Monster skills (`MonsterSkill`, lib/monster_skills.dart; #59)

The owner: "setiap monster high elite, mini boss dan boss punya skill unique juga selayaknya para troops". The
owner's answers to the design (#59's report): English titles; high elite and up; the half-HP move for the boss only;
stuns on troops allowed with limits. Built so far: the core, seven types' signature
skills, branch 2a's four that move or shoot (Sticky Glob, Swoop, Pounce, Trample) and branch 2b's last
three (Reassemble, Maul, Curse of Frailty), below: every type has its signature. The mini-boss skills and
the boss's moments are in "Mini bosses and the boss" below.

- **Who casts** (`monsterSkillOf`): a wave's monster of high elite rank or higher (a mini boss or boss of the
  type too, #58) casts its type's signature skill. A normal or elite one, a necromancer's raised minion and a
  type with none built yet don't, nor one that is a slime for now (Slime Hex, `Status.hex`).
  `Game.monsterSkills` (default true) turns them all off, for probes and tests.
- **Cooldowns, not MP:** each skill has its own cooldown (`MonsterSkill.cooldown`, from `Unit.skillAt`). A
  monster's first cast comes `firstCastAfter` 2 s after it comes on, a second later for each place in the
  wave's queue (2, 3, 4, 5, 2… s), so a wave's high elites don't all fire at once; it uses no dice. The
  healing necromancer pays Mass Mend from its MP as well.
- **When** (`wantsMonsterSkill(u)`, the rules below): during a wave, never while it marches, once its
  cooldown is over.
- **The wind-up:** it first stands still for its `wind` s (`Unit.winding`, `windUntil`), its title popping
  over it (`Game.monsterCasts`; the battle log's `MonsterSkillCast`). Its cooldown runs from then. Its tell
  shows meanwhile (ui-hud.md "A monster's skill"): a red circle on the ground at its reach or its feet, a
  marker over each troop it will land on (`Game.windTargetsOf`: the landing's own target queries, read only,
  no dice), arrows along a charge's or a line's way. The tell only shows: nothing in play reads it.
  - A stun, a shove (a knockback or a drag, `Unit.move`), Slime Hex or a march in that time cancels it, and
    it still waits its cooldown. That is the counterplay: Crushing Blow and the Hero skills that hold
    monsters. An awakened lancer's Impale (#88) breaks one on purpose: it cancels the wind-up (`_cancelWind`) and
    staggers the monster, at most once in 25 s on one monster (`Unit.interruptedAt`), never a once-only skill,
    the boss rank's or a necromancer's ("Awakening skills").
  - A mini boss or a boss casts it stronger (the numbers below).
- **The cap:** one cast takes at most `monsterSkillCap` 35% of a troop's max HP, a Hero's 25%
  (`monsterSkillCapOf(o)`; `_hurt`'s `cap`, after defence; Volley's arrows carry it in their damage). A skill
  that strikes one troop several times in a cast shares it among those hits (decision 110): each of Blade
  Dance's cuts takes at most the cap ÷ its cuts (`_skillBlow`'s `hits`), each of Volley's arrows the cap ÷ the
  arrows that troop gets, and Pounce's bleed what its bite left (109). No single cast kills outright.
- "Troops" are living troops on the field; "in reach" is within the monster's `range`; a tile is 16.

| Type | Skill | Wind / cooldown | Casts when | Does (a mini boss or boss: stronger) |
|---|---|---|---|---|
| orc | War Shout | 0.4 / 14 s | 3+ monsters within `warShoutK.reach` 2 tiles (itself too) struck in the last 2 s | each of them deals 1.2× (`Status.might`) for 5 s (1.3×) |
| skeleton_archer | Volley | 0.6 / 12 s | 2+ troops in range | 3 arrows (5) of 0.8× its damage at as many troops in range, nearest first, again from the nearest when fewer |
| armored_skeleton | Shield Up | 0.3 / 12 s | a long-range troop hit it in the last 1 s | it takes half from long-range troops (archers, wizards and their skills: `Status.shotWard`) for 4 s; melee troops' blows and throws in full (also the monsters within a tile behind it) |
| elite_orc | Brutal Swing | 0.6 / 10 s | 2+ troops in reach | one swing at each troop in reach: 1.2× its damage (1.5×) |
| armored_orc | Bulwark | 0.4 / 16 s | not guarded, and 2+ troops in reach or a monster within 2 tiles below 50% HP | the melee troops within 2 tiles fight it for 4 s (`Status.taunt` on a troop), and it takes 30% less meanwhile (its guard, `guardCut`) (and sends back 30% of each melee blow, `Status.reflect`) |
| greatsword_skeleton | Blade Dance | 0.4 / 14 s | 2+ troops within 1.5 tiles | it spins: 3 cuts (4) 0.5 s apart, each 0.7× its damage to every troop within 1.5 tiles; its own attacks wait; a stun or a shove stops the spin |
| necro_healer | Mass Mend | 0.6 / 18 s | 16 MP (2 × `necroHealCost`), and 2+ monsters within 2 tiles below 70% HP (itself too), none of them in another healer's heal window (#78) | every hurt monster within 2 tiles not in another healer's window gets its heal (1.5×), which opens its window |

- A taunt now turns a troop too (`_nearestFoe`): Bulwark's melee troops go for the armored orc while it
  lasts, as a monster goes for a Hero's Holy Taunt.
- The stall watchdog (#39) stays in charge: nothing casts during a march, the only heals are a burst on an
  18 s cooldown and Reassemble's stand, once a skeleton's life, and the watchdog still ends a wave after
  `stallTime` without progress.

### Branch 2a: the skills that move or shoot (lib/monster_skill_moves.dart)

Four signatures ride the forced movement and the looks above, monster on troop (hero_moves.dart,
hero_shots.dart). monster_skills.dart sends them to `_wantsMoveSkill` / `_castMoveSkill` from one arm in each
switch; the numbers are `stickyGlobK`, `swoopK`, `pounceK` and `trampleK`. Each picks its target again when
the wind-up is over; none left, nothing happens. "Back-line" is a healer or a long-range troop (`Unit.line` 0
or 1).

| Type | Skill | Wind / cooldown | Casts when | Does (a mini boss or boss: stronger) |
|---|---|---|---|---|
| slime | Sticky Glob | 0.4 / 10 s | a back-line troop within 4 tiles | a glob (`Shot.special`, `ShotLook.glob`, 120/s) at the nearest one: 0.8× its damage, then for 3 s the troop walks at 0.7× (`Status.slow`) and attacks with its pause ×1/0.7 (`Status.haste` above 1) (0.6× for 4 s) |
| bat | Swoop | 0.4 / 12 s | a back-line troop within 5 tiles and out of its reach | it leaps (`leap`, over the front: in the air nobody bumps it) to land beside the nearest one and bites 1.5× its damage (2×), healing half of what the bite took |
| werewolf | Pounce | 0.4 / 12 s | a troop within 4 tiles below 50% of its HP (a Hero below 25%) | it leaps to land beside the one with the least of its HP left and bites 1.5× (2×); the troop then bleeds 0.3× its damage a second, 4 times (`Status.bleed`), bite and bleed together at most the cap |
| orc_rider | Trample | 0.5 / 15 s | a troop 2–5 tiles ahead of it (towards the base) | it charges (`charge`, 2× its speed) at the nearest back-line troop 2–5 tiles ahead, else the farthest troop there: each troop within 8 of its way takes 1× (1.5×, and a 0.5 s `stunTroop`) and is shoved half a tile aside (a Hero half as far); with its target in reach it stops and fights on there |

- Every blow and the glob's damage stop at the cap (`monsterSkillCapOf`; the glob's is worked out ahead).
  A Pounce is one cast under one cap: its bleed gets what the bite left of the cap, split over its 4 ticks,
  and none when that is under `minHit` a tick (a tick takes at least that). A vulnerable troop's ticks can
  still pass it a little: they carry no cap of their own. A bite shows the type's big hit; Trample's blows the hooves' dust.
- The counterplay: a stun or a shove during the wind-up cancels it (the core's rule). Once cast, a leap
  can't be stopped (it is in the air), but a stunned rider stops its charge where it is, and a shove
  (Shield Bash, Spear Sweep) ends it too.
- A glob's slow and attack slow take the place of a weaker haste or slow of the same kind on the troop (the
  effect store keeps the stronger of a kind): a troop under War Cry's haste that a glob hits attacks 30%
  slower until it ends.

### Branch 2b: the rest of the signatures (lib/monster_skill_signatures.dart)

monster_skills.dart sends Maul and Curse of Frailty to `_wantsSignatureSkill` / `_castSignatureSkill` from one
arm in each switch; Reassemble is passive. The numbers are `maulK`, `curseOfFrailtyK` and `reassembleK`.

| Type | Skill | Wind / cooldown | Casts when | Does (a mini boss or boss: stronger) |
|---|---|---|---|---|
| werebear | Maul | 0.8 / 12 s | a troop in reach | one blow at the nearest: 2.5× its damage (3×; the cap holds), and it knocks it back a tile (`knockBack`: a Hero half, a troop holding its ground not at all) |
| necromancer | Curse of Frailty | 0.6 / 18 s | 3+ troops within 3 tiles | each takes 1.15× from monsters for 5 s (`Status.vulnerable` by the necromancer; 1.2×) |
| skeleton | Reassemble | passive | the first blow that would kill it | below |

- Curse of Frailty is the necromancer's (the boss or mini boss in practice: no necromancer rolls a lower rank, #58). It casts
  it beside its summons and pays no MP for it.
- **Reassemble** (skeleton; passive, `reassembleK`): the first blow that would kill a skeleton of high elite
  rank or more drops it into a heap of bones instead (`Unit.downUntil`, `reassembled`; `_reassembles`, from
  `_hurt` right after the Grail's save). Once a life.
  - The heap lies for `down` 2 s at 1 HP, so it isn't a kill (no gold, no score, not fallen), then stands
    again at `stand` 30% of its max HP (a mini boss or boss: `strong` 50%). Its title pops and the battle log
    has the cast.
  - While it lies it does nothing, only holy damage touches it, and any holy blow ends it for good. The
    troops' own attacks pass it by (`_nearestFoe` skips a heap, and no melee spot is round one, #84), so they go
    for the next monster.
  - Holy damage (`_holyHurt`, `Game._holy`): a troop healer's light on the undead (`_smite`, which goes for
    the weakest undead in range: the heap), Holy Nova and Judgement. A holy killing blow never lets it
    reassemble. (Exorcism is holy too, but it only strikes raised minions, which never reassemble.)
  - Not a raised minion's, not while it is a slime (Slime Hex), not with `Game.monsterSkills` off.
  - Its cooldown is infinite, like Split's: it goes by its own rule. A skill it was winding up is cancelled
    (`_cancelWind`: a skeleton boss's moment winds up again later), and a heap is no grave for Grave Call: a
    skeleton leaves one only when it falls for good.
  - The killing blow still counts as a kill for a Hero's kill heal (`Status.killHeal`), as the Grail's save
    does.

### Mini bosses and the boss (lib/boss_skills.dart; #59 branch 3)

- **Who casts what** (`monsterSkillsOf(u)`, `MonsterSkill.rank`):
  - a high elite: its type's signature (above);
  - a mini boss: the signature, stronger, and its type's mini-boss skill (`MonsterRank.miniBoss`);
  - a boss: both, and its moment (`MonsterRank.moment`), once.

  Each turn it starts the first of them that may start and that it wants, in this order: the moment, the
  mini-boss skill, the signature. The same guards as above hold: no raised minion, no slime (Slime Hex), never
  during a march. `monsterSkillOf(u)` is still the signature alone.
- **Clocks.**
  - The signature runs on `Unit.skillAt`, the mini-boss skill on `Unit.bossSkillAt`.
  - The mini-boss skill's first cast comes `bossSkillGap` 3 s after the signature's (`_firstCast`).
  - A recurring skill never starts within 3 s of the monster beginning any skill (`Unit.castAt`), so a mini
    boss's two don't come back to back.
  - Split, Frenzy and Thick Hide are once only (an infinite cooldown). They go by their own rule, with no gap.
- **The boss's moment.**
  - It is ready once the boss's HP is down to `bossMomentK.at` half its max, and it comes first.
  - A stun during its wind-up cancels it like any skill, but it winds up again `bossMomentK.retry` 1.5 s later
    (`Unit.momentAt`), until it lands (`Unit.momentDone`). So a well-timed stun buys time, and the moment
    still comes, once.
  - Never during a march.
- **What a skill brings in is a raised minion** (`_bringIn`; Split, Swarm, Grave Call). That means
  `raisedBy` is the caster, as with the necromancer's skeletons: no gold, no score, no skills, and the stall
  watchdog (#39) doesn't count it. The wave goes on while it lives.
- **Grave Call's graves** (`Game.graves`): the skeleton kinds (`skeletonKinds`) of the wave's own that fell
  this wave, where they lay. They are cleared when a wave starts. A raised skeleton leaves none, and one that
  rises again leaves the list, its body gone.
- **New statuses** (hero_skills.dart):
  - `Status.swift`: a monster's walking speed ×k (Howl, Second Wind), apart from the troops' slows on it.
  - `Status.daze`: a troop's pause between attacks ×k (Screech), apart from its own haste.
  - `Status.soulRend`: each blow the monster lands takes k MP from the troop.

  A monster's line shot (Grave Wave) is a skill's blow: `_sweep` caps it with `monsterSkillCapOf`.
- **The cap is per cast per troop** (`CastBlows`, `_castBlow`): a skill that lands on one troop more than once
  shares its 35% (a Hero's 25%) across the blows. Barbed Arrow's arrow is set aside first, and its bleed gets
  what is left (none when that is under `minHit` a tick, as with Pounce, decision 109). Soul Drain's three
  drains and Bone Rain's arrows are counted as they land. The others (Earthshaker, Ground Slam, Death Nova,
  Grave Wave's one-way wave, …) hit a troop once per cast.
- The stuns go through `stunTroop` (at most 0.8 s, a Hero half, then 4 s it can't be stunned again), the shove
  through `knockBack` (a Hero half as far, never behind the back line), both from the PREP branch
  ("Forced movement").
- **A new status:** `Status.steadfast` (Iron March): no slow counts on the monster (`_pace`). A boss is never
  stunned or shoved anyway.

The mini-boss skills:

| Type | Skill | Wind / cooldown | Casts when | Does |
|---|---|---|---|---|
| slime | Split | — / once | it dies (not during a march) | it bursts into `splitK` 3 normal slimes of its wave, 10 round where it fell; the title pops over the first |
| bat | Screech | 0.5 / 15 s | 3+ troops within 2 tiles | their attacks come 1.25× as far apart (20% fewer) for 4 s (`Status.daze`) |
| skeleton | Bone Shield | 0.4 / 15 s | an undead monster (`Stats.dark`) within 2 tiles below 50% HP (itself too) that no guard as strong covers | the most hurt one takes 40% less for 4 s (its guard) |
| orc | Headbutt | 0.5 / 12 s | a troop in reach | the nearest: 1.2× its damage and a 0.5 s stun |
| skeleton_archer | Barbed Arrow | 0.5 / 14 s | a troop in range | an arrow at the nearest: 1× its damage, then the troop bleeds 0.5× a second, 4 times |
| werewolf | Frenzy | — / once | its HP drops below 50% | its attacks come 1/1.4 as far apart (40% faster) for 6 s, never under the attack floor |
| armored_skeleton | Bone Bash | 0.5 / 14 s | a troop in reach | the nearest: 1× its damage, knocked a tile back towards the base |
| orc_rider | Spear Throw | 0.5 / 12 s | a back-line troop (long range or a healer) within 5 tiles | a spear at the nearest (the `spear` look, 220/s): 1.5× |
| elite_orc | Bloodrage | 0.4 / 20 s | below 60% HP, with a troop in reach | it heals 30% of what it deals for 6 s (`Status.lifesteal`) |
| armored_orc | Ground Slam | 0.6 / 14 s | 3+ troops within 1.5 tiles | 1× to each of them |
| greatsword_skeleton | Soul Rend | 0.4 / 18 s | a troop in reach with 5+ MP | for 6 s each of its blows on a troop takes 5 MP too |
| werebear | Thick Hide | — / once | its HP drops below 50% | it takes 30% less for 6 s (its guard) |
| necromancer | Soul Drain | 0.6 / 20 s | a troop within 4 tiles | a drain beam to the one with the most HP there for 3 s: 0.6× its damage three times, a second apart, each healing it half of what it took; either falling, or a stun or a shove on it, ends it |
| necro_healer | Unholy Ward | 0.4 / 16 s | a monster in its range hit twice in the last 2 s (`Unit.hurtBefore`) | the most hurt such one soaks 2× its heal for 6 s (`Status.absorb`) |

The boss's moments (once, at half its HP; Skull Crusher waits for a troop in its reach):

| Type | Moment | Wind | Does |
|---|---|---|---|
| slime | Slime Tide | 0.6 s | a slime puddle 1.5 tiles round where it stands (3 across) for 6 s: troops in it walk 40% slower (`Status.slow` 0.6, 0.25 s after they step out) |
| bat | Swarm | 0.6 s | 4 normal bats of its wave come in round it, 14 away |
| skeleton | Grave Call | 0.8 s | up to 4 skeleton kinds that fell this wave within 4 tiles, nearest first, stand again where they lay, at 25% of their HP, their rank kept |
| orc | Rally | 0.8 s | every orc kind on the field (`orcKinds`: orc, orc rider, elite orc, armored orc) deals 1.25× and attacks 1/1.2 as far apart for 8 s |
| skeleton_archer | Bone Rain | 0.8 s | arrows fall for 4 s a tile round the troop in its range with the most troops within a tile of it: 0.5× its damage to each troop there every second |
| werewolf | Howl | 0.8 s | every monster within 3 tiles (itself too) walks 1.25× as fast and attacks 1/1.2 as far apart for 6 s |
| armored_skeleton | Iron March | 0.6 s | for 8 s no slow holds it (`Status.steadfast`) and it walks 1.3× as fast |
| orc_rider | Second Wind | 0.6 s | 25% of its max HP back; it walks 1.2× as fast and attacks 1/1.2 as far apart for 6 s |
| elite_orc | Skull Crusher | 1.0 s | once a troop is in its reach: the nearest takes 3× its damage (the cap holds) and a 0.8 s stun |
| armored_orc | Earthshaker | 0.8 s | 1.2× its damage to every troop within 3 tiles, and a 0.5 s stun |
| greatsword_skeleton | Grave Wave | 0.8 s | a wave (a line shot, the `long` look) towards the nearest troop (none: at the base), 5 tiles at 200/s: 2× to each troop on its line |
| werebear | Roar | 0.8 s | the troops within 3 tiles deal 0.75× for 5 s (`Status.weaken`) |
| necromancer | Death Nova | 1.0 s | 1.5× to every troop within 2.5 tiles |
| necro_healer | Last Rites | 1.0 s | every monster within 3 tiles (itself too) gets 20% of its max HP back |
