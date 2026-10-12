# Loot: items and relics

Purpose: drops, per-type item upgrades (capped by awakening), per-troop relics, the Pusaka bound to a troop type,
the boss's chest they come from (Peti Bos), and the store that buys and sells them.

## Drops

Monsters drop the Towns' materials, on dice of their own ("Town and Smithy: materials" below). No item and no relic
drops: a Town's Smithy crafts them (decisions-log 221, 246; every board game since the forge's cut-over, 272; every
game since 321). When a monster dies (`_hurt`) it still rolls on `loot`, a Random kept separate from the spawn `rng`,
what dropped before the Towns, and throws each draw away, so the `loot` dice stay where they were and a seeded game
plays the same:

1. An item at `dropChance` 0.08, one of the first `droppedItemKinds` 7 of `Item` (the grade-I kinds), each as likely,
   so the dice roll the same whatever comes after them in the enum. The boss (whatever its type) draws `bossDrops` 2
   for sure, and the wave's mini boss 1.
2. Then a relic, only from strong monsters, at `relicChance[tier]` (one table beside `Tier`, the owner's numbers): one
   of `droppedRelics` (fang, thorns, fury, guard), each as likely; no Pusaka ever dropped. With the chest on the boss's
   went first (`chestTakesBossRelic`, decisions-log 152; "Peti Bos" below), then every relic with the Towns (221).

   | Tier | normal | elite | high elite | mini boss | boss |
   |---|---|---|---|---|---|
   | Relic chance | 0 | 0 | 5% | 10% | 30% |

   A necromancer's raised minions (`raisedBy` set) roll no relic, whatever their tier, like the gold they don't pay.
   When relics dropped, a probe (3000 kills per tier through `_hurt`) gave 5.1% / 10.1% / 28.9%, and 0 for raised
   ones: over waves 1–30 about 12.7 relics a game (10 seeds; 9.9 of them from high elites), where the older rule (2%
   from every monster, the boss always) gave about 28.

Only the materials lie on the field until the wave is won, and the "VICTORY!" popup counts them (ui-hud.md "The Bag's
Materials"). Until decisions-log 321 a game without the Towns (the tests' alone) had its items and relics lie there
(`drops`, `relicDrops`), picked up at the win into `inventory` / `relicBag` and counted in the popup (`lastLoot`,
`lastRelics`, `lootCounts`); they went with the rules from before the Towns. The troops that fell in the wave show
under the popup's loot (ui-hud.md); their relics were back in the bag already.

## Items: per troop TYPE, capped by awakening

The owner's rule: an item improves every troop of the type, now and every one placed later. How many
of each kind a type can take is capped by its awakening recipe (below).

`useItem(item, type)` appends to `upgrades[type]`. `statsOf(type)` gives the result: the base stats
with every upgrade (`Stats.upgraded`, in order), then HP and MP raised by awakening (`awakenHp` /
`awakenMp` 25% of the base per level). `_refit` gives each living troop of the type those stats (HP
it gains comes with them), and `_newTroop` starts new troops with them.
`useItem` refuses (returns false, `Sfx.error`, the item stays in the bag) with none in stock, after game
over, or when `canUse(item, type)` is false.

| Item | Effect (`Stats.upgraded`; `Stats.statOf(item)` reads the stat) |
|---|---|
| sword | dmg ×`swordDmg` 1.25 |
| shield | def +`shieldDef` 2.5 (defence: every blow the troop takes loses it, `hitTaken`; units-and-combat.md) |
| boots | speed ×`bootsSpeed` 1.25 (long range and healers that fall behind booted melee catch up mid-wave: `speedTo`, formation-and-navigation.md) |
| bow | range ×`bowRange` 1.2 |
| gloves | rate ×`glovesRate` 0.8 (faster) |
| potion | +`potionRegen` 5 HP/s regen; on a healer (`Stats.heals`, e.g. the priest) also +`potionHeal` 3 HP to every heal |
| staff (on screen "Staff") | magic power: on a healer +`staffHeal` 3 HP to every heal, else dmg ×`staffDmg` 1.25. Only the casters' recipes (wizard, priest) take it, and they take no sword (`powerItem(type)`: staff for them, sword for the rest) |

Every troop's base regen and defence are 0. Upgrades compound, and gloves and bow work on healers too.
A healer's heal only ever gets added to (potions and staffs), so the order its items came in doesn't
change it (with the forge's Prayer Beads, which multiply it, the added heals are multiplied too: "The forge: the new
kinds' effects" below).
No item raises HP or MP: only awakening does (and the forge's Amulet raises max HP: "The forge: the new kinds'
effects").
The forge (on in every board game since its cut-over, decisions-log 272; "The forge: data" below) gives `Item` 42
values, each with a kind (`Item.slot`) and a grade: these seven are its first, the grade-I items monsters dropped before
it (`droppedItems`); every game has all 42 (decisions-log 321).
In the UI (the book's Tas page, ui-hud.md), tap an item and then a troop type in the list beside it
(#87: every type with what the item would do there, `Game.assignPreview` below, greyed with why not,
`whyNot` → `Refusal`) or any troop on the field, or drag the item onto a troop on the field; over the troop a
popup says what it would do to the whole type, or why not (#86, ui-hud.md "Loot in hand and the drop popup").
The item stays in hand while the bag holds more, so the next tap gives the next one. `canUse` is
`whyNot == null`. `typesFor(item)` (each type with taken/cap and why not) is what the list used before #87.

**Melee reach ceiling:** a bow never takes a melee fighter's range (`Stats.melee`: neither shoots nor
heals, i.e. front and heavy melee) past `meleeMaxRange` = 1.7 tiles = 27.2, at every awakening level.
`Stats.upgraded(bow)` clamps it (and never shrinks a longer base). Once a melee type is at the ceiling,
`canUse(bow, type)` is false. The clamp reads the type's own cap, `Stats.reachCap`: `meleeMaxRange` unless the forge's
spears raised it ("The forge: the new kinds' effects" below). No melee base reaches it: the longest is the lancer's 22 (1.375 tiles).
Bows until the ceiling: soldier 5, swordsman 5, knight / armored_axeman / knight_templar 4, lancer 2.

**Price:** every item a type has taken makes that type dearer, a little, and every awakening level
triples it. `priceOf(type)` is the base `cost` plus, per item, `Game.priceStep(type)` = `priceRise` 0.1
of the base cost (rounded, at least 1 gold), times `awakenPrice` 3 to the power of `awakenLevel(type)`: soldier 30 → 33
→ 36, and with its 8-item recipe 54 × 3 = 162 once awakened. Every item counts once (also items past a
cap); relics don't. Buying (`place` / `autoPlace`) and the book's price label go through it. It is
derived from `upgrades`, so it isn't saved. `priceWith(type, item)` is the price one more `item` would
give: `priceOf` with the item tried on and taken back, so an awakening it completes counts (the knight a
glove short of its recipe: 95 → 300); null when `whyNot` refuses it. The Tas page's list previews it.

## Awakening: recipes, caps and levels

The owner's rule: a troop type can't just stack one attribute; it has to raise the others to awaken,
and only then can it take more. `awakenRecipe` (lib/game.dart) gives each type how many of each item
kind it needs to awaken once. Since the forge each level takes that recipe in its own grade ("The forge: items crafted,
Awaken by grade" below), every game since decisions-log 321: the rule below, the recipe once more a level all in grade
I, is the one a save from before the forge keeps its levels by (`oldItemLevel`, `awakenKept`), and the recipe is what
each type's grade sets build on (`kindRecipe`):

| Type | sword | shield | boots | bow | gloves | potion | staff | Items |
|---|---|---|---|---|---|---|---|---|
| soldier | 2 | 2 | 1 | 1 | 1 | 1 | – | 8 |
| knight | 3 | 3 | 2 | – | 2 | – | – | 10 (the owner's example) |
| swordsman | 3 | – | 2 | – | 3 | 2 | – | 10 |
| archer | 2 | – | 1 | 4 | 3 | – | – | 10 |
| lancer | 2 | 2 | 4 | – | 1 | – | – | 9 (no bows: 2 reach the ceiling) |
| priest | – | 2 | – | 2 | 2 | 2 | 2 | 10 (the owner: casters use the staff; was shield 3, potion 3) |
| armored_axeman | 2 | 3 | 1 | – | 2 | 2 | – | 10 |
| wizard | – | – | – | 3 | 3 | 2 | 2 | 10 (the staff instead of its 2 swords) |
| knight_templar | 2 | 2 | 2 | 1 | – | 3 | – | 10 (the owner: more speed, fewer shields) |

- **Level** (by this rule `oldItemLevel(type)`, 0 to `maxAwaken` 3) is derived from `upgrades`: the most whole
  recipes the type's items hold (`min` over the recipe of count ÷ needed); `itemLevel(type)` reads the grade sets
  instead (below). `awakenLevel(type)` is that, plus at
  Bangkit 3 the levels bought with gold (`ascended`, "Bangkit 4-5" below), so 0 to `awakenTop` 5; every reader
  (stats, skills, looks) takes it, and the item rules below read only up to 3.
- **Caps** (by this rule; `capOf(type, item)` is by grade now, below): the recipe's count × (level + 1), at most × `maxAwaken`. Kinds missing
  from a recipe have cap 0: they never go on that type. So before awakening the knight takes at most
  3 swords; with its whole recipe it awakens (level 1) and may take up to 6. At level 3 the caps stay
  at the level-3 totals, so a type that has awakened three times takes no more items.
- `canUse(item, type)` = under the cap and not a bow on a melee type at its reach cap (`Stats.reachCap`, `meleeMaxRange`
  unless spears raised it).
- `awakenProgress(type)`: per kind of the next grade set, (have, need) toward the next level; every kind reads full at
  level 3. The book shows it under each row with the level in words (ui-hud.md).
- **The moment:** the item that completes a recipe awakens the type. Every living troop of it gets
  `awakeFx('upgrade', level)` instead of its item burst, and `Sfx.clear` plays after `Sfx.magic`. Mid-wave, its
  awakening skill is ready at once, the type's troops 0–3 s apart, and each pops the skill's new name
  (units-and-combat.md "Awakening skills").
- **The skill:** Bangkit 1 gives the type's troops a new skill that costs MP (Disarm, Unbroken, Phantom Rush,
  Spellbreaker, Impale, Lifeline, Skyfall, Singularity, Consecration: one per type);
  Bangkit 2 and 3 make it stronger ("Disarm II", "Disarm III"). The rules, the MP and the nine are in
  units-and-combat.md "Awakening skills" (#88).
- **Looks:** each level has a colour (blue, crimson, gold; Bangkit 4 violet, 5 white, below). The type's troops
  keep their own colours; their outline, ground shadow (see-through like every unit's, at 0.65 of its pulse, so the colour still reads) and rising sparks take the level's, and so do their hit bursts
  and shots (`awakeFx`: `hit_<type>_awake<level>`, `heal_awake<level>`; up to Bangkit 3's gold, `_fxColor`) and its
  book row's outline and stars (ui-hud.md).
- **HP and MP:** each level adds `awakenHp` / `awakenMp` 25% of the type's base HP / MP / MP regen
  (level 3: ×1.75; Bangkit 4 ×2.0, 5 ×2.25). The items give every other stat (and Bangkit 4-5 the damage).
- **Old saves** may hold more of a kind than its cap, or kinds outside the recipe. Nothing is removed:
  those items keep their stats and count for the level; they only block more of that kind until
  the caps rise. Shields saved before defence now give defence; a saved troop's HP is cut to its
  current most (`fromJson`), since shields no longer add HP.
- The recipes are one table to tune; with it, a type needs 8–10 items per level, 24–30 for level 3.
  Kinds asked for over all nine recipes per level: gloves 17, sword 16, shield 14, boots 13, potion 12,
  bow 11, staff 4.
- Each level takes its own grade: "The forge: items crafted, Awaken by grade" below.

## Bangkit 4-5 ("Kebangkitan Emas", #92 part 2)

The owner: "duitnya itu aku bingung di buat untuk apa karna tanpa artefak shop juga lawan masi bisa di atasi dengan
mudah" (late-game-design.md §2 part 2; decisions-log 143). Gold buys two more awakening levels for a type that is
at Bangkit 3. The rules are `lib/ascend.dart` (`extension Ascend on Game`); the constants sit beside `maxAwaken` in
game.dart, the prices in ascend.dart; they are bought on the type's Army detail, its Next tag (`_upgradeButton`, ui-hud.md
"Army"; the field's Toko had an Awaken section too until decisions-log 296). On screen the levels are "Awaken 4" and
"Awaken 5" (`awakenName`; `awakenTab`, "Awaken 4-5", the guide's K18 quotes).

- **Who:** a type at Bangkit 3 from its items (`itemLevel` 3) buys Bangkit 4, then 5 (`maxAscend` 2), for the whole
  type, its troops now and later. `ascended[type]` counts the levels bought; it only counts while the items are at
  Bangkit 3. Items, recipe and caps stay as at Bangkit 3: no more items fit (`capOf`, `whyNot` unchanged).
- **Price** (`ascendPrice`, per type): 100,000 for Bangkit 4, 250,000 for Bangkit 5 (the owner's decision 6 b, the
  default: five types to Bangkit 5 = 1.75M). `ascendPriceOf(type)` is the next one's, null at Bangkit 5.
- **What a level gives** (each past `maxAwaken`; `ascendFactor(level, k)` = k^(level − 3)):

  | | Bangkit 3 | Bangkit 4 | Bangkit 5 |
  |---|---|---|---|
  | HP and MP (`awakenHp` / `awakenMp` of the base, kept) | ×1.75 | ×2.0 | ×2.25 |
  | damage, a healer's heal (`ascendPower` 1.25) | ×1 | ×1.25 | ×1.5625 |
  | troop price (`ascendTroopPrice` 1.0: `_awakenedPrice` = `awakenPrice`^min(level, 3) × it^(level − 3)) | ×27 | ×27 | ×27 |
  | awakening skill cooldown (`ascendSkillCd` 0.85) | ×1 | ×0.85 | ×0.7225 |

  The damage multiplies the items' (`statsOf`), before the heavy types' +20%. The awakening skill's other numbers
  and its MP stay Bangkit 3's (units-and-combat.md "Awakening skills").
- **Buying** (`ascend(type)`, between waves): the gold goes, `ascended` rises, every living troop of the type is
  refitted (`_refit`: the HP and MP gained come with it) and bursts `awakeFx('upgrade', level)` in the new colour,
  `Sfx.magic` then `Sfx.clear`, and an `Ascended` event (type, level, cost) goes to the battle log and the telemetry.
- **Refusals** (`whyNotAscend(type)`, the UI's words, in this order): the store's own (`_armyClosed`,
  `storeRefusalNames`: "Opens after wave 15", "Only between waves", "Game over"), then `ascendRefusals`: "Needs Awaken 3 first", "Already Awaken 5
  (Max)", "Not enough gold". A refused buy changes nothing and plays `Sfx.error`.
- **Looks:** Bangkit 4 violet `#8E44FF`, Bangkit 5 white `#F2F6FF` (`_awakeColors`; book ink `#6B2FC9` and a slate
  `#55617A`), on the outline, ground shadow, sparks, HP-bar pips, stars, the log and the awakening's own burst. A troop's
  shots, orbs and hit bursts keep Bangkit 3's gold (`_fxColor`): violet would come near Arcane Blast's violet orb and
  Singularity's indigo, white near Spellbreaker's silver arrow and the healers' white smite on dark monsters, which
  only a heal's colour tells from a heal (skills.dart's colour table).
- **The bag's hint** (late-game-design.md "Fix the unused bag"; at wave 71 the owner's archers, priests and templars
  were 1-3 items short of Bangkit 3 with 29-48 of each in the bag): `bagLevel(type)` is the highest awakening (up to
  3) the type's items plus the bag's reach, counts only (two types may count the same items). Below Bangkit 3 the
  Shop's Awaken row and the Army page's detail say "Awaken n from the Bag" (`bagAwakensTo`) when it is higher than
  the type's level, and `bagAwakens` (some type with a living troop could) puts a dot on the Tas tab.
- **Saved:** `ascended` (type → levels bought), only once one is; old saves load with none. It loads before the
  troops, so they come back at their Bangkit 4-5 HP.
- Past Bangkit 5 the same rows sell Tempa (below).

## Tempa (Bangkit 6+, decisions-log 163)

Late-economy design J2 (reports/late-economy-design.md §2.2): once five types were at Bangkit 5 the owner's w86 save
banked 1.8M with nothing to buy. A type at Bangkit 5 keeps buying levels with gold, without end (a guard at 30). The
rules and every constant are `lib/tempa.dart` (`extension Tempa on Game`); it is bought on the type's Army detail
(ui-hud.md "Army"). On screen Tempa is "Forge": "Forge +3" (`tempaName`), its button "Forge +4  33k".

- **The purse** (`purse(w)`): about what wave w pays in kill gold late in a run, `purseK` 14 × (4 + 2w) ×
  (1 + `killGoldGrowth`)^(w − 1), rounded to `purseRound` 1000. Wave 86 156k, 87 166k, 100 358k, 105 479k (0.87-1.0
  of the formula's kill gold). Tempa's prices and the Shop tab's dot count in purses.
- **Who:** a type at Bangkit 5 (`tempaFrom` = `awakenTop`), between waves, for the whole type, its troops now and later.
  `tempa[type]` counts the levels bought; they count only while the type is at Bangkit 5 (`tempaOf`).
- **What a level gives:** HP ×(1 + `tempaHp` 0.05) and damage (a healer's heal) ×(1 + `tempaDmg` 0.05), compounding
  (`tempaFactors`: Tempa +6 ×1.34, +14 ×1.98, +30 ×4.32). In `statsOf` it multiplies Bangkit 5's HP and damage, before
  the heavy types' +20%, the stat Pusaka and the oath; a Hero gets it under its own ×3. MP, the other stats, the skills
  (troop, awakening, Hero) and their cooldowns stay; the troop price is ×`tempaTroopPrice` 1.0 a level (no dearer).
- **Price** (`tempaPrice(wave, n)`, `tempaPriceOf(type)`): level n + 1 costs `tempaK` 0.2 × purse(wave) × `tempaRise`
  1.2^n, rounded to `tempaRound` 1000 and at least that; `wave` is the last one won, so prices rise as the run goes on.

  | Level | 1 | 2 | 3 | 4 | 5 | 10 | 30 |
  |---|---|---|---|---|---|---|---|
  | after wave 87 | 33k | 40k | 48k | 57k | 69k | 171k | 6.57M |
  | after wave 100 | 72k | 86k | 103k | 124k | 148k | 369k | 14.2M |

  `tempaMax` 30 is a guard (no run gets there: all 30 at wave 105 cost 113M); `tempaPriceOf` is null at it.
- **Buying** (`temper(type)`): the gold goes, `tempa` rises, every living troop of the type is refitted (`_refit`: the HP
  gained comes with it) and bursts `awakeFx('upgrade', 5)` in Bangkit 5's white, `Sfx.magic` then `Sfx.clear`, and a
  `Tempered` event (type, level, cost) goes to the battle log ("Knight: Forge +1 (33k gold)") and the telemetry
  (`tempa`, `gold.tempaSpent`).
- **Refusals** (`whyNotTempa(type)`, in this order): the store's own (`storeRefusalNames`), then `tempaRefusals`: "Needs
  Awaken 5 first", "Already Forge +30 (Max)", "Not enough gold". A refused buy changes nothing and plays `Sfx.error`.
- **Lepas jenis** keeps the levels and refunds none of them: its refund stays half the troops' price; the type bought
  again fights with its Tempa.
- **The Army tab's dot** (`tokoNudge`, the owner's decision 4 a): while the gold is at least `nudgePurses` 3 × purse(wave +
  1) and a type with a living troop can buy its next Bangkit or Tempa level now (`whyNotAscend` / `whyNotTempa` null),
  a red dot on the Army's tab (ui-hud.md "Bookmarks"; the Toko's tab had it until decisions-log 296). Between waves only, since mid-wave the store refuses.
- **Saved:** `tempa` (type → levels), only once one is bought, loaded before the troops so they come back at their
  Tempa HP; an unknown type is dropped and a count over 30 cut to 30. Saves from before it have none.

## Relics: held by ONE troop (a Hero: two)

The small relics (`RelicScope.troop`, `Rarity.biasa`; `smallRelics`; the Pusaka are below): the first four
(`droppedRelics`: Fang, Thorns, Fury, Guard; the Basic tier) and the Smithy's seven ("The Smithy's seven" below). A
Town's Smithy crafts all eleven and none drops (the board since decisions-log 237, every game since 321: until then a
plain `Game()`, the tests', had monsters drop the four and never showed the seven). The forge's nine (`forgeRelics`,
"The forge: data" below) show and act in every game too ("The forge's nine" below). Each `Relic` has a `rarity`
(`Rarity` biasa, langka, epik, legenda: the chest's odds and its cards' colours come with it, P3) and a `scope`:
`troop` (held by one troop), `type` (a Pusaka, bound to a troop type) or `army` (an oath, P5); `Relic.pusaka` is
any scope but `troop`.

- `Unit.relics`: the relics a troop holds, in the order given. One slot per troop, two for a Hero
  (`Unit.relicSlots`: `heroRelicSlots` 2 when `Unit.hero`, #91), each a different kind (`Unit.holds(relic)`).
- `useRelic(relic, unit)` gives one from `relicBag`. It refuses (false, `Sfx.error`, nothing changes, the relic
  stays in the bag) with none in the bag, after game over, or when `relicRefusal(relic, unit)` says why:
  - a Pusaka: `pusakaOnType` "Artifacts go on a type, not one troop" (it is bound to a type, below);
  - not a living troop: `assignRefusals.gone` "Fallen";
  - it holds that kind already: "Already holds <relic>" (`holdsRelic`; a Hero can't double one kind);
  - no slot free: a troop with one slot names what it holds ("Already holds <relic>"), a Hero with both taken
    says `assignRefusals.full` "Relic slots full".

  The UI says it (#87): the Tas list's row in the message window (`showMessage`, ui-hud.md), the drop popup over
  a troop on the field in red (#86).
- **Taking one off** ("Remove", #91): `takeOff(relic, unit)` puts it back into `relicBag` (`Sfx.place`), from
  where it is given again or sold like any other. `whyNotTakeOff(relic, unit)` refuses (false, `Sfx.error`,
  nothing changes): `assignRefusals.over` after game over, `takeOffRefusals.midWave` "Only between waves"
  while a wave is on, paused or not (`waveActive`; `takeOffMidWave` false: between waves only, like the store),
  `gone` for a troop that fell, `takeOffRefusals.none` "Not held" for a relic it doesn't hold (a Pusaka is
  never held). It emits `RelicTakenOff` (telemetry.md). Giving is still allowed mid-wave.
- A troop that dies returns every relic it held to the bag (a Hero both); its `TroopFell` lists them (`relics`). So
  does a troop sent home by Lepas jenis (`releaseType`, decisions-log 141; units-and-combat.md); the released type's
  bound Pusaka goes to the Gudang, free ("Pusaka" below).
- Where they come from: a Town's Smithy crafts all twenty ("Town and Smithy: Craft" below); none drops (Drops, above).
  Where they go besides troops and the Town's Shop: Asah takes 10 from the bag for each star it gives a Pusaka ("Asah"
  below; any of them, the cheapest first).
- In the UI (#87), tap a relic in the Tas page's bag, then a troop in the list beside it: every living troop,
  one that can't take it greyed with why (`Game.assignPreview` below). Or tap a troop on the field, or drag the
  relic onto one (#86). It stays in hand while the bag holds more. Its icon shows left of that troop's HP bar (a
  Hero's second further left). To take one off: tap the held relic's slot on a Tas list row, then "Remove"; or
  the Remove beside it on the troop's pinned plate on the field (ui-hud.md).
- Every hook below reads all of a troop's relics (`holds`), so a Hero's two both work: guard with fang, fury
  counting beside another. None changes a stat; its type's Pusaka comes on top and takes no slot.

| Relic | Effect (in `_hurt` / the attack code) |
|---|---|
| fang | the holder heals `fangShare` 0.3 of the damage it deals |
| thorns | an attacker takes back `thornsShare` 0.3 of the blow (no bouncing between two thorns) |
| fury | every `furyEvery` 3rd attack does ×`furyHit` 2 (shots carry it in `Shot.dmg`; a troop healer's smites count, its heals don't); counts only while held |
| guard | the holder takes `guardCut` 25% less damage |

### The Smithy's seven (decisions-log 227)

Seven new small relics (lib/relics.dart), appended to `Relic` after the last Artifact (their names are their save keys,
so the enum is only ever appended to). Monsters never dropped them (`droppedRelics` stays the four), the Shop never
sells them (`storeGoods`), the Bag lists and the guide's relic page shows `Relics.relicsInPlay` (all eleven and the
forge's nine; until decisions-log 321 a game without the Towns had the four alone), and only a Town's Smithy makes them
("Town and Smithy: Craft", decisions-log 233). The
three display names are the owner's of 2026-10-04 (the design's Cleave, Last Stand and Blessing are Hero skills'
names): **Sweep** (`cleave`), **Iron Will** (`lastStand`), **Holy Charm** (`blessing`).

Their numbers are town.json's `relics` block (`Relics.relicK(relic, key)`, a patch moves them; the shipped ones below)
and their tier their recipe's (`TownRules.recipes`, `Relics.relicTier`): Basic (the four), Strong, Mighty. Each acts at
a site that already was one:

| Relic (key) | Tier | Effect | Where |
|---|---|---|---|
| Sweep (`cleave`) | Strong | its normal attack that lands (a blow, a shot where it lands) also hits the nearest other monster within `reach` 1.5 tiles of the target for `share` 30% of the attack's damage (as fired: a fury's and the type's Artifacts' power in), through that monster's own defence; one monster, the nearest; a smite doesn't sweep | `_strike` / the shot's landing → `_relicLanded`; the blow is `Hit.relic`, never a hit of its own, so it never sweeps again nor poisons |
| Venom (`venom`) | Strong | its normal attack that lands poisons the target: `share` 20% of the attack's damage again over `secs` 3 s, a tick a second (`Status.bleed`, as Deep Wound's and Bleeding Edge's, through the target's defence each tick); a stronger bleed already on it stays, an equal or weaker one is replaced, so poisons never stack | the same sites; the ticks are `Hit.bleed` |
| Mana Siphon (`manaSiphon`) | Strong | each normal attack that lands (a blow, a shot, a healer's smite) and each heal it gives (`_castHeal`, a healer's own heal, not a skill's) gives it `mp` 2 MP, never past its max | `_relicLanded`, `_relicHealed` |
| Spirit Ward (`spiritWard`) | Strong | at each wave's start a shield of `share` 15% of its max HP (`giveWard`, never past `wardMax`; after the Artifacts' `waveStart` Fx); it ends with the wave, like every ward | `startWave` → `_spiritWards` |
| Iron Will (`lastStand`) | Mighty | once a wave, a blow (any: a bleed's tick too) that leaves it alive under `below` 25% of its max HP heals it `heal` 40% of its max HP at once, through the heal funnel (`HealSrc.lastStand`: in a wave, so Wound cuts it); at the line exactly, nothing; a killing blow is the Grail's, never this. `Unit.ironWillUsed`, cleared at every wave's start, not saved | `_hurt`, after the blow → `_ironWill` |
| Giant Slayer (`giantSlayer`) | Mighty | its normal attacks and a healer's smites (`Hit.normal`, `Hit.smite`) on a mini boss or the boss do ×`k` 1.5, before their defence; a skill's blow, a splash past the target, a bleed and a sweep don't | `_hurt`, before defence → `_slayerK` |
| Holy Charm (`blessing`) | Mighty | heals on it are ×`k` 1.4 (after a Mercy Lily's ×, before Wound): every heal but its own regen and, as Mercy Lily, never the Grail's save or the after-wave heal (all its HP back anyway); the funnel's listener hears the heal asked | `_healTroop` → `charmK` |

- A Hero holds two of them like any two relics (two kinds): Sweep and Venom on one blow both act; Iron Will's heal on a
  Holy Charm holder is 1.4× bigger.
- "Best on" (`relicBestOn`, a hint only: nothing refuses a type): Fang Knight, Templar, Lancer, Swordsman; Thorns
  Knight, Templar, Axeman; Fury Archer, Wizard, Swordsman; Guard front melee, Heroes; Sweep Soldier, Knight, Axeman,
  Templar; Venom Archer, Swordsman, Lancer; Mana Siphon Wizard, Priest, Archer; Spirit Ward Soldier, Knight, Lancer;
  Iron Will front melee, Heroes; Giant Slayer Lancer, Swordsman, Archer; Holy Charm Knight, Templar, Axeman (with a
  Priest behind).
- Today's four keep their numbers in Dart (`fangShare`, `thornsShare`, `furyEvery`, `furyHit`, `guardCut`), equal to
  town.json's `fang`, `thorns`, `fury` and `guard` (test/town_materials_test.dart pins the file to the defaults); Fury's
  is entangled with Twin Fury's beat (`Fx.furyBeat`) and its catalog text, so they move to the rules in a later step.
- Telemetry: as any small relic (`RelicUsed`, `RelicTakenOff`, the bag's `relics` at a wave's start, by name).

### The forge's nine: their effects and the relics' cap (decisions-log 250)

The nine (`forgeRelics`, "The forge: data" below) act in every game (the forge's own switch went in decisions-log 296,
the Towns' in 321, when a game without them, the tests', last had none in play). A Smithy crafts them from their recipes (`craftRecipe`; the Mighty three
take their grade-II item, the gold is the forge's x0.7), and they are given and taken off like the eleven. Their numbers
are their town.json `relics` entries (`relicK`, a patch moves them). The code is lib/relics.dart; where each acts:

- **As a normal attack or a smite is made** (`_strike`, `_smite` → `Relics._relicBlowK`), its damage is multiplied by
  the holder's factors below, so a shot carries them where it lands, and so does everything that reads the attack as
  fired: a splash, Sweep's share, Venom's poison, God's Thunder's leaps. A skill's blow, a bleed tick and a sweep get
  none.
- **As it lands** (`_relicLanded`, after the blow): Chill's slow and Weak Spot's mark.
- **In `_hurt`**: Reaper's end (after every cut and soak, before the HP comes off: `_reap`), Weak Spot's counter
  (`_relicDealt`) and Hot Streak's kills (`_relicKill`).
- **A skill's cast** (a troop's skill, a Hero's, an awakening's; beside the Artifacts' `cast` Fx): Afterglow's charge
  (`_relicCast`).
- **A wave's start** (`_relicWave`): Afterglow's charges and Hot Streak's stacks are gone, the counters start afresh.

| Relic (key) | Tier | Effect | Numbers |
|---|---|---|---|
| Chill (`chill`) | Basic | every `every`th normal attack that lands (a blow, a shot where it lands; not a smite) slows the monster by `slow` for `secs` s (`Status.slow`, k 1 − slow); a mini boss or the boss by `bossShare` of that; a stronger slow on it stays. Its own count of the hits it landed (`Unit.chillHits`, never reset, like Fury's) | every 3, slow 0.30, secs 1.5, bossShare 0.5 (15%) |
| Shark Tooth (`sharkTooth`) | Basic | ×`k` on a bleeding or poisoned monster (`Status.bleed`: Venom's, Bleeding Edge's, a skill's) | k 1.25 |
| Grit (`grit`) | Basic | ×`k` while the holder is under `below` of its max HP (as the `hpBelow` condition) | below 0.50, k 1.30 |
| Ambush (`ambush`) | Strong | ×`k` on a held monster (`foeHeld`: slowed, pinned, stunned or hexed; Bully's Club's test) | k 1.35 |
| Weak Spot (`weakSpot`) | Strong | each normal attack or smite that lands marks the monster for `secs` s: it takes ×`taken` from every troop after its defence (a mini boss or the boss ×`boss`), as `Status.vulnerable`, the mark Hunter's Mark puts (the stronger stays); Void Eye's and Vengeance Mark's marks are their own and multiply with it | taken 1.12, boss 1.06, secs 3.0 |
| Hot Streak (`hotStreak`) | Strong | each kill the holder makes (any blow of its) is a stack for `secs` s, at most `most` (a new one past it takes the oldest's place): +`per` a stack (`Unit.streak`) | per 0.10, most 3, secs 4.0 |
| Avalanche (`avalanche`) | Mighty | +`per` for each other monster on the field within `reach` tiles of its target, at most `most` (`alliesNearOf`) | per 0.08, most 5, reach 2.0 |
| Afterglow (`afterglow`) | Mighty | each skill the holder casts charges its next `hits` normal attacks or smites at ×`k` (`Unit.glow`; a new cast charges them anew) | hits 3, k 1.5 |
| Reaper (`reaper`) | Mighty | a normal attack or a smite that would leave a monster alive under `below` of its max HP ends it (the blow takes all its HP; the Bayangan Deathless still saves a silver or gold one at 1 HP); never a mini boss or the boss: on one under that line its attack is ×`bossK` instead | below 0.15, bossK 1.5 |

- "Bosses" on the cards (Chill, Weak Spot, Reaper) are a mini boss and the boss, as Giant Slayer's.
- **The relics' cap** (town.json `combos.relicMost` 3.0, `Combos.relicMost`): on one blow the product of the small
  relics' factors (the nine's above, the Fury beat's ×2, ×2.5 under Relic Altar, and Giant Slayer's ×1.5 on a mini boss
  or the boss) is at most 3.0. Past it the nine's part comes down, under 1 when the beat and Giant Slayer alone pass it
  (under Relic Altar 2.5 × 1.5 = 3.75 is cut to 3.0). Giant Slayer with the beat, and Afterglow with the beat, are
  exactly 3.0. The Artifacts' own powers (War Drum, Bully's Club, Titan Bane, Rage Totem, Momentum's charge, every
  mark) stay outside it. The cut is made for the attack's target, so a splash past it and a swept monster share it.
  Relic Altar acts at the four sites it always did (Fang, Thorns, Fury, Guard), not on the seven or the nine.
- **What the cards say:** each card says only its own effect (`relicEffect`, the tier line, "Best on"); no card,
  guide or log line names a partner, a pair or a combo.
- **The counters** (`Game.relicWorth`, a `PusakaTally` a relic, over every troop holding one; cleared at a wave's
  start): `uses` are Chill's slows, Weak Spot's marks, Reaper's ends and boss hits, and the other six's hits powered;
  `worth` is the damage each added (before defence; Weak Spot's after it, from every troop's blows on its marks; Reaper's
  the HP it took past the blow), cut down alike under the cap. A won wave's report (`PusakaReport.relics`, `RelicDone`)
  has every one of the nine that did something, and the battle log a pale gold row each with its icon, after the
  Artifacts' rows (`relicCounter`): "Shark Tooth: +1.2k damage", "Chill: slowed 12 times", "Weak Spot: marked 9
  times, +812 damage". "VICTORY!" still names only an Artifact's counter. The telemetry's wave record has the same
  (`relics`) and the damage each pair a troop wields dealt (`relicPairs`, telemetry.md).
- **Combos** (the owner, 2026-10-04: relics and Artifacts may combine for the most damage, never told to the player):
  they come from shared mechanics, each relic or Artifact stating only its own: a bleed (Venom, Bleeding Edge → Shark
  Tooth), a hold (Chill, Snare Cord, Ice Grip → Ambush, Bully's Club), a mark (Weak Spot, Void Eye, Vengeance Mark), a
  crowd (Sweep, Avalanche, God's Thunder's leaps carry the blow), a cast (Mana Siphon's MP brings Afterglow's charges
  sooner), a kill chain (Hot Streak, Momentum), low HP (Grit, Rage Totem, Iron Will), a boss (Giant Slayer, Fury,
  Titan Bane).
- Not saved: Chill's count, Afterglow's charges, Hot Streak's stacks, a mark, the counters (a save holds no wave in
  progress).
- **Tests:** test/forge_relics_test.dart (each relic alone at its numbers, the bosses' halves and Reaper on a boss; the
  cap: Giant Slayer with the beat, under Relic Altar, Afterglow, an Artifact outside it, a patch; the combos' multiples;
  the cards; the report's rows and the telemetry's records; the save).

## Pusaka: bound to a troop TYPE (decisions-log 138)

The owner (2026-10-01): "sekarang user bener bener nga ada ngerasa apapun dari penggunaan artefaknya". The five
store artefacts (`Relic.store`, `RelicScope.type`, `Rarity.epik`), the boss chest's Langka (`Rarity.langka`: the
four of P3, decisions-log 152, batch L-1P's ten, decisions-log 205, batch L-2P's ten, decisions-log 207, and batch
L-3's six, decisions-log 209), batch E-1P's ten and E-2P's seven new Epik (`Rarity.epik`, chest-only: `newEpikStore`
false, decisions-log 211 and 214) and its three Legenda (`Rarity.legenda`, P5, decisions-log 155; "Legenda" below) are Pusaka:
each is bound to a troop TYPE (the two Legenda oaths, `RelicScope.army`, to the whole army) and
works on every living troop of it, its Heroes and the ones bought later included, and is never lost when they fall
(bound to a type none of which lives, it is "asleep", `pusakaAsleep`). The rules are `lib/pusaka.dart` (a part of
game.dart, `extension Pusaka on Game`); every number the owner may tune is one constant there. What each one does is
a row of the catalog, run by one engine ("The Pusaka catalog and its engine" below). Every number that goes with the
stars, in the rules and in every text, is read through one accessor, `pusakaAt(relic, stars, ukir:)` (Void Eye's on the
boss with `boss: true`; God's Thunder's leaps, a whole number, `pusakaCountAt`; a row's second Fx with `fx: 1`), which
reads the row's Fx and through it the named table, and also gives God's Thunder's share and Dragon Crown's cap, one
number at every star. `ukir` is the Pusaka's Ukir steps ("Ukir" below): at 0 the number is exactly the table's.

- `Game.pusaka`: each owned one (`OwnedPusaka`): its `type` (null: unbound, in the **Gudang**, `gudang`), its
  `stars` ★1 to `starMax` 3, `binds` (how many times it was bound; 0: the next binding is free), `suggested`
  (bound by the migration's default, which Batal still takes back), and its Ukir: `ukir` (steps, 0 to 5) and `feed`
  (the points on its next step's bar). One of each kind; a type holds one Pusaka
  (`pusakaOf(type)`), binding another onto it sends the first to the Gudang.
- **Binding** (`bindPusaka(relic, type)`, from the Gudang or from another type: a Pindah, "Move"): between waves only
  (`bindMidWave` false). Its first binding is free; every later one costs `bindPrice` = `rerollPrice(wave)` ×
  `pindahShare` 1.0, the chest's reroll price (P3): 600 × 1.05^(wave−1), rounded to 100 (700 on wave 5, 2.5k on
  30, 38k on 86). Unbinding (`unbindPusaka`) is free. `whyNotBind` / `whyNotUnbind` refuse (false, `Sfx.error`,
  nothing changes) with `pusakaRefusals` (English since decisions-log 187): `assignRefusals.over`, `midWave` "Only
  between waves", `notType` "Not a troop type", `none` "Not owned yet", `same` "Already on this type", `gold` "Not
  enough gold", `unbound` "Already in Vault", `oath` "Oath: for all troops" (an oath binds to no type and never
  unbinds).
  Lepas jenis (`releaseType`, decisions-log 141) sends the released type's Pusaka to the
  Gudang the same way, free. The type's troops are refit at once (`_refitType`: Dragon Heart's HP comes with it,
  and without it the HP is cut to the max); a binding plays `Sfx.magic` with the gold burst on each of them. It
  emits `PusakaBound` or `PusakaMoved` (telemetry.md).
- **Where they come from:** on the board (the chest on, `Game.offers`) only the boss's chest ("Peti Bos" below): a
  new one is bound by the default rule (`pusakaPrefs`), a duplicate adds a star. The Shop's Artifact shelf is closed
  there; a game without the chest (a plain `Game()`: tests, probes) keeps it, in a Town's Shop: the five epik, one of each (a copy of one owned is refused, "Owned"),
  into the Gudang at ★1. The Langka and the new Epik (batches E-1P's ten and E-2P's seven) are never sold; one in the Gudang sells back to
the store for half of its price (`langkaPrice` 16,000 for a Langka, `epikPrice` 25,000 for a new Epik) (the owner, 2026-10-03: "hanya bisa sell ke toko tapi untuk buy tidak bisa"), through a Town's Shop's Sell Basket (decisions-log 269). The Tas page binds, moves and unbinds them in two taps (its cell in
  the Bag's grid, then a type's row; an unowned one has no cell, decisions-log 187); it sold one from the Gudang until decisions-log 296, with the Towns off (decisions-log 151; ui-hud.md "Tas"; what a row previews:
  `pusakaPreview`, "What a Tas row previews" below).

| Pusaka (id) | ★1 / ★2 / ★3 | Hook |
|---|---|---|
| Dragon Heart (`dragonHeart`) | max HP ×1.6 / ×2.2 / ×3.0 (`dragonHeartK`), and 1% of it back a second (as regen) | `always` → stat HP: `_pusakaStats` in `statsOf`, so the book and the field agree |
| Dawn Star (`dawnStar`) | damage, or a healer's heal, ×1.3 / ×1.45 / ×1.6 (`dawnStarK`); no change to the pause (4 of the owner's 5 types already attack at `minAttackInterval`) | `always` → stat attack: `_pusakaStats` |
| God's Thunder (`godThunder`) | every blow or shot of the type that lands (its attacks, not a skill's own blows) leaps from its target to the 2 / 3 / 4 nearest other monsters within 3 tiles at 40% (`godThunderK`); each leap a yellow `Beam` (`BeamLook.thunder`, `chainBeamTime`) with the wizard's spark, at most `beamsPerSec` 12 drawn a second over the whole field (the damage is never capped) | `landed` → leap: `_fxLanded` after `_strike`'s blow and after any shot lands |
| Grail of Immortality (`grail`) | once a wave, each troop of the type lives through its first killing blow at 30% / 40% / 50% of its max HP, and for 2 s no blow hurts it (`grailK`; the effect store's `Status.cap` at 0, Bastion's) with the holy burst | `lethal` → save: `_fxLethal` in `_hurt`; `Unit.fxOnce` per troop, cleared by `startWave`, not saved |
| Void Eye (`voidEye`) | every monster the type hits takes ×1.25 / ×1.35 / ×1.45 from every troop (the boss ×1.15 / ×1.2 / ×1.25) for 5 s (`voidEyeK`): its own `Status.voidMark` (a violet ring), so it stacks with Hunter's Mark's `Status.vulnerable` (×1.25 × 1.25), and a monster's Curse of Frailty on a troop is untouched | `dealt` → status: `_fxDealt` in `_hurt`; read in `_afterDefence` beside `vulnerable` |
| Iron Banner (`ironBanner`, Langka) | every troop of the type takes 15% / 20% / 25% less damage (`ironBannerK`), after its defence and a worn guard's cut | `struck` → cut: `_fxStruck` in `_hurt` |
| Blood Fang (`bloodFang`, Langka) | every troop of the type heals 10% / 15% / 20% of the damage it deals (`bloodFangK`), on top of a worn fang | `dealt` → heal: `_fxDealt` in `_hurt` |
| War Drum (`warDrum`, Langka) | every 3rd normal attack (a blow, a shot, a healer's smite) of a troop of the type does ×1.5 / ×1.75 / ×2.0 (`warDrumK`); one blow counter with a worn fury (`Unit.blows`), so on the 3rd both multiply | `attack` (every 3rd) → power: `_blowK` in `_strike` and `_smite` |
| Mourning Bell (`mourningBell`, Langka) | when a troop of the type falls, every troop within 2 tiles of it (any type) heals 20% / 25% / 30% of its max HP (`mourningBellK`) with the heal burst | `fell` → heal: `_fxFell` in `_hurt`'s fall path |
| Titan Bane (`titanBane`, Langka) | every blow of a troop of the type on the boss or a mini boss (its normal attacks, its skills', a bleed it left) does ×1.15 / ×1.22 / ×1.30 (`titanBaneK`), before the monster's defence | `pierce` [`vsBoss`] → power: `_fxPierce` in `_hurt` |
| Finishing Blade (`finishingBlade`, Langka) | the same on a monster under 30% of its max HP before the blow: ×1.2 / ×1.3 / ×1.4 (`finishingBladeK`) | `pierce` [`foeHpBelow` 0.3] → power |
| First Cut (`firstCut`, Langka) | the same on a monster over 90% of its max HP: ×1.2 / ×1.3 / ×1.4 (`firstCutK`) | `pierce` [`foeHpAbove` 0.9] → power |
| Shell Cracker (`shellCracker`, Langka) | a normal attack of the type on a monster with a shield (`shielded`: an absorb, a shot ward, a Barrier, a guard) does ×1.2 / ×1.3 / ×1.4 (`shellCrackerK`) | `attack` [`foeShielded`] → power: `_blowK` |
| Twin Fury (`twinFury`, Langka) | a troop of the type that wears a fury does ×1.2 / ×1.3 / ×1.4 more on the fury's x2 attack (`twinFuryK`; every `furyEvery` 3rd on the fury's counter, `Fx.furyBeat`) | `attack` (every 3rd) [`holds` fury] → power: `_blowK` |
| Steady Stance (`steadyStance`, Langka) | a troop of the type over 80% of its max HP (before the blow) takes 18% / 24% / 30% less damage (`steadyStanceK`), like Iron Banner's cut | `struck` [`hpAbove` 0.8] → cut: `_fxStruck` |
| Turtle Shell (`turtleShell`, Langka) | the same under 40% of its max HP (`turtleShellK`) | `struck` [`hpBelow` 0.4] → cut |
| Dulling Mail (`dullingMail`, Langka) | a monster that takes HP off a troop of the type deals ×0.90 / ×0.86 / ×0.82 for 2 s (`dullingMailK`; the boss half the cut: ×0.95 / ×0.93 / ×0.91), at most once a second a troop (its own cooldown, `Unit.fxReady`) | `hurtBy` → status weaken (the attacker): `_fxHurtBy` in `_hurt` |
| Challenge Letter (`challengeLetter`, Langka) | every 4th normal attack of a melee troop of the type makes the monster it hits fight that troop (`Status.taunt`) for 2 / 2.5 / 3 s (`challengeLetterK`; the boss half as long; never a monster no taunt holds, `_tauntable`); on a type that shoots it does nothing | `attack` (every 4th) [`melee`] → status taunt: `_blowK` |
| Snare Cord (`snareCord`, Langka) | every 4th normal attack of a troop of the type slows the monster it hits to ×0.8 / ×0.75 / ×0.7 for 2 s (`snareCordK`; the boss half the slow: ×0.9 / ×0.875 / ×0.85) | `attack` (every 4th) → status slow: `_blowK` |
| Momentum (`momentum`, Langka) | a troop of the type that kills a monster does ×1.3 / ×1.45 / ×1.6 on its next normal attack (`momentumK`): one charge (`Unit.charge`; a stronger one kept, spent by that attack, dropped at a wave's start) | `kill` → power (one charge, itself): `_fxKill` sets it, `_blowK` spends it |
| Bleeding Edge (`bleedingEdge`, Langka) | every 3rd normal attack of a troop of the type makes the monster it hits bleed 30% / 45% / 60% of that attack over 3 s, a tick a second (`bleedingEdgeK`; `Status.bleed`, as Deep Wound's: each tick through the monster's defence; a stronger bleed already on it stays) | `attack` (every 3rd) → status bleed: `_blowK` |
| Shatter Shard (`shatterShard`, Langka) | every 5th normal attack of a troop of the type that lands: the other monsters within a tile of its target take 40% / 50% / 60% of it (`shatterShardK`; extra damage, `Hit.extra`, with the troop's own hit burst on each), at most once a second a troop (its own cooldown; it starts only when one stands near) | `landed` (every 5th) → burst (monsters near): `_fxLanded` |
| Pain Crystal (`painCrystal`, Langka) | a blow that hurts a troop of the type gives it 2% / 3% / 4% of its max MP (`painCrystalK`), at most once a second a troop | `struck` → MP (itself): `_fxStruck` |
| Watch Shield (`watchShield`, Langka) | every troop of the type starts each wave with a shield (its ward) of 10% / 14% / 18% of its max HP (`watchShieldK`); a troop bought mid-wave has none until the next | `waveStart` → ward (itself): `_fxWave` in `startWave` |
| Bone Buckler (`boneBuckler`, Langka) | each kill of a troop of the type gives it a shield of 4% / 5% / 6% of its max HP, up to 3 kills' worth: 12% / 15% / 18% (`boneBucklerK`; never past `wardMax`) | `kill` → ward (itself): `_fxKill` |
| Riposte (`riposte`, Langka) | every 3rd blow from a monster that fights up close (one that took HP off it) on a troop of the type: the troop hits that monster back for 40% / 55% / 70% of its own attack (`riposteK`; a `Hit.hitBack` with no attacker, as the thorns relic's, so nothing answers it); arrows count none | `hurtBy` (every 3rd) [`attackerMelee`] → burst (the attacker): `_fxHurtBy` |
| Mana Leech (`manaLeech`, Langka) | every 3rd normal attack of a troop of the type gives it 3% / 4.5% / 6% of its max MP (`manaLeechK`) | `attack` (every 3rd) → MP (itself): `_blowK` |
| Looter's Pouch (`lootersPouch`, Langka) | a monster a troop of the type kills pays ×1.10 / ×1.15 / ×1.20 of its gold (`lootersPouchK`; its gold after the Bayangan Thrift; whole coins as the shares add up, `Game._goldBits`, not saved; each floated as Plunder's is, `goldPops`); raised skeletons pay none | `kill` → gold: `_fxKill` |
| Spell Cutter (`spellCutter`, Langka) | every 5th normal attack of a troop of the type takes 1 good effect off the monster it hits: the one with the most time left of the buffs Spellbreaker strips (none a troop gave), or its guard; where Spellbreaker only halves (the boss, a mini boss, a buff the boss rank gave) half of what is left goes, once; then it waits 6 / 5 / 4 s (`spellCutterK`; its cooldown starts only when it took one), with Spellbreaker's silver rune ring | `attack` (every 5th) → strip: `_blowK` |
| Salt Charm (`saltCharm`, Langka) | a blow that hurts a troop of the type ends 1 bad effect a monster put on it (the one with the most time left, `cleanse`), then it waits 8 / 6 / 4 s (`saltCharmK`; its cooldown starts only when it ended one); it runs before the blow's own effects (the Bayangan Sap's weaken from a 4th blow stays, the next blow ends it) | `struck` → cleanse (itself): `_fxStruck` |
| Wolf Feast (`wolfFeast`, Langka) | each kill of a troop of the type heals it 4% / 6% / 8% of its max HP (`wolfFeastK`), through the heal funnel (Wound cuts it, Scar stops it) | `kill` → heal (itself): `_fxKill` |
| Full Cup (`fullCup`, Langka) | a healer's heal of the type that goes past the healed troop's full HP gives that troop a shield (its ward) of 50% / 75% / 100% of the extra (`fullCupK`), at most `fullCupK.most` 12% of its max HP; the shield is Full Cup's (`Unit.wardFrom`), so what it soaks counts for it on any type | `heals` [`healPastFull`] → ward (the troop healed): `_fxHealed` in `_castHeal` |
| Hidden Flask (`hiddenFlask`, Langka) | once a wave, a blow that leaves a troop of the type under 35% of its max HP (`hiddenFlaskK.below`) heals it 20% / 25% / 30% of its max HP (`hiddenFlaskK.heal`), once the blow has landed; a blow that fells it heals nothing (`belowOnce`, the Fx's own bit) | `struck` [`hpBelow` 0.35] → heal (itself): `_fxStruckAfter` in `_hurt` |
| Living Moss (`livingMoss`, Langka) | every troop of the type heals 0.4% / 0.6% / 0.8% of its max HP a second (`livingMossK.regen`, its regen through the heal funnel) and deals ×`livingMossK.dmg` 0.9 (attack or heal: the trade, which Carve never moves) | `always` → stat regen and stat attack: `_pusakaStats`; its counter `_fxRegen` at the regen tick |
| Pure Water (`pureWater`, Langka) | a healer's heal of the type also ends 1 bad effect a monster put on the troop healed (the most time left), then it waits 3 / 2.5 / 2 s (`pureWaterK`; it starts only when it ended one) | `heals` → cleanse (the troop healed): `_fxHealed` |
| Healer Bane (`healerBane`, Epik) | a normal attack of a troop of the type on a monster healer (`stats.heals`: the necro healer) does ×1.3 / ×1.45 / ×1.6 (`healerBaneK`) | `attack` [`foeHealer`] → power: `_blowK` |
| Bully's Club (`bullyClub`, Epik) | the same on a held monster (`foeHeld`: slowed, pinned by Impale, stunned, or hexed into a slime) ×1.3 / ×1.4 / ×1.5 (`bullyClubK`) | `attack` [`foeHeld`] → power: `_blowK` |
| Unity Ring (`unityRing`, Epik) | while `unityRingK.types` 4 or more troop types have a troop alive (`typesAliveNow`, counted once a tick), a normal attack of the type does ×1.25 / ×1.35 / ×1.45 (`unityRingK.hit`; a hard condition: no `condBonus`) | `attack` [`typesAlive` 4] → power: `_blowK` |
| Rune Gauntlet (`runeGauntlet`, Epik) | a troop of the type that casts a skill (its own, its awakening's or a Hero's) deals ×1.3 / ×1.4 / ×1.5 for 4 s (`runeGauntletK`; its might, `Status.might`; a stronger might already on it stays) | `cast` → status might (itself): `_fxCast` at the three cast sites |
| Hawk Feather (`hawkFeather`, Epik) | the type's range ×1.15 / ×1.22 / ×1.3 (`hawkFeatherK.range`; a melee type's no farther than its reach cap, `meleeMaxRange` unless spears raised it, as a bow's), and its attack or heal ×`hawkFeatherK.dmg` 0.9 (the trade, which Carve never moves) | `always` → stat range and stat attack: `_pusakaStats` |
| Witherroot (`witherroot`, Epik) | a monster a troop of the type takes HP off deals ×0.9 / ×0.87 / ×0.84 for 3 s (`witherrootK.dealt`; the boss ×0.95 / ×0.93 / ×0.91, `witherrootK.boss`; a mini boss the whole; a weaken, through the duration scaler; a blow on a weakened one refreshes it) | `dealt` → status weaken (the monster hit): `_fxDealt` |
| Arrow Catcher (`arrowCatcher`, Epik) | a troop of the type takes 20% / 25% / 30% less damage from a monster that shoots (`arrowCatcherK`), after its defence, like Iron Banner's cut | `struck` [`attackerRanged`] → cut: `_fxStruck` |
| Stone Coat (`stoneCoat`, Epik) | the type's defence +2.5 / +3.75 / +5 (`stoneCoatK.def` 1 / 1.5 / 2 × `shieldDef`: one Shield's to two) and its walk speed ×`stoneCoatK.speed` 0.9 (the trade) | `always` → stat defence and stat speed: `_pusakaStats` |
| Hero's Cloak (`heroCloak`, Epik) | the type's Hero takes 20% / 25% / 30% less damage (`heroCloakK`), after its defence (a hard condition: no `condBonus`) | `struck` [`hero`] → cut: `_fxStruck` |
| Moonwell (`moonwell`, Epik) | the type's MP comes back ×1.3 / ×1.45 / ×1.6 as fast (`moonwellK.mpRegen`) and its max HP ×`moonwellK.hp` 0.9 (the trade) | `always` → stat MP regen and stat HP: `_pusakaStats` |
| Ember Brand (`emberBrand`, Epik) | every 3rd normal attack of a troop of the type (`emberBrandK.every`) marks the monster hit for 4 s (`emberBrandK.time`; the Bayangan Mark Ward shortens it): the next blow on it from a troop of another type (a normal attack, a smite or a skill's) does ×1.5 / ×1.75 / ×2 (`emberBrandK.hit`, before its defence) and spends it; one mark a monster (`Unit.emberMark`; a new one replaces it), the boss's whole; it has no ring | `attack` → mark (the monster hit): `_fxMark`, spent by `_fxEmber` in `_hurt` |
| Funeral Pyre (`funeralPyre`, Epik) | a troop of the type that kills a monster burns every other monster within 1.5 tiles of the dead one (`funeralPyreK.reach`) for 60% / 80% / 100% (`funeralPyreK.share`) of the killing blow as it was before the dead one's defence, through their own; then that troop waits 1.5 s (`funeralPyreK.cd`; it starts only when one burned); none from a blow inside a burst or a leap | `kill` → burst (the monsters near the dead one): `_fxKill`, `_burst` |
| Null Stone (`nullStone`, Epik) | a monster that takes HP off a troop of the type loses its good effects and its guard by Spellbreaker's rules (the boss and a mini boss half of the time left, once; a troop's own effect on it, a slow, stays), with Spellbreaker's rune ring; then that troop waits 6 / 5 / 4 s (`nullStoneK.cd`, its k: `Fx.cdByStars`; it starts only when it took something) | `hurtBy` → strip (the attacker): `_fxHurtBy`, `_strip` |
| Fallen Flag (`fallenFlag`, Epik) | when a troop of the type falls, every troop within 2 tiles of it (`fallenFlagK.reach`; any type) deals ×1.2 / ×1.25 / ×1.3 for 4 s (`fallenFlagK.might`, `fallenFlagK.time`; a might from the fallen one; a stronger might already on it stays) | `fell` → status might (the troops near): `_fxFell` |
| Aegis Seal (`aegisSeal`, Epik) | a troop of the type that casts a skill (its own, its awakening's or a Hero's) gets a shield of 10% / 14% / 18% of its max HP (`aegisSealK`; never past `wardMax` 20%, Carve too) | `cast` → ward (itself): `_fxCast` at the three cast sites |
| Warden's Horn (`wardensHorn`, Epik) | every 6th normal attack (`wardensHornK.every`) of a troop of the type that fights up close makes every monster within 2 tiles of it (`wardensHornK.reach`) but the boss (a mini boss too) fight it for 2.5 / 3 / 3.5 s (`wardensHornK.time`; a taunt, through the duration scaler; not a healing necromancer nor one raising the dead); then that troop waits 6 s (`wardensHornK.cd`); a type that shoots, never | `attack` [`melee`] → status taunt (the monsters near): `_fxHorn` |
| Anchor (`anchor`, Epik) | from a wave's start every troop of the type stands firm all wave (`Status.noShove` from itself; a troop bought mid-wave has none): no shove or drag moves it and a monster bumping into it takes the whole push, while its troops still make way for each other (`_firm`); and its walk speed ×0.85 / ×0.9 / ×0.95 (`anchorK.speed`, the trade, which the stars and Carve lighten: the stand has no number) | `waveStart` → status noShove (itself): `_fxWave`; `always` → stat speed: `_pusakaStats` |
| Mana Hymn (`manaHymn`, Epik) | a healer's heal of the type also gives the troop healed 3% / 4% / 5% of its max MP (`manaHymnK`) while it lacks some | `heals` → MP (the troop healed): `_fxHealed`, `_fxMp` |
| Saint's Tear (`saintTear`, Epik) | a troop of the type that casts a skill (its own, its awakening's or a Hero's) ends every bad effect a monster put on it and on each troop within 2 tiles (`saintTearK.reach`; the Bayangan Sap's weaken and Bat Venom's bleed among them; a good effect stays), then it waits 6 / 5 / 4 s (`saintTearK.cd`, its k: `Fx.cdByStars`; it starts only when one of them had one to end) | `cast` → cleanse (itself and the troops near): `_fxCast` at the three cast sites |
| Brave Song (`braveSong`, Epik) | a healer's heal of the type gives the troop healed ×1.1 / ×1.15 / ×1.2 damage for 3 s (`braveSongK`; a might from the healer; a stronger might already on it stays) | `heals` → status might (the troop healed): `_fxHealed` |
| Halo Lantern (`haloLantern`, Epik) | a healer's heal of the type also heals the 2 troops nearest the one healed within a tile (`haloLanternK.most`, `haloLanternK.reach`) that lack HP, 15% / 20% / 25% of the heal each (`haloLanternK.share`), through the heal funnel; their heals set off no `heals` Fx (no chain) | `heals` → heal (the troops nearest the one healed): `_fxHealed` |
| Hearth (`hearth`, Epik) | at a won wave's end each living troop of the type under 40% / 60% / 80% of its max HP (`hearthK`; never past full, Carve too) heals up to it through the heal funnel, a heal between waves (Wound never cuts it) | `waveEnd` → heal (itself): `_fxWave(end: true)` |
| Heartbeat (`heartbeat`, Epik) | every 4th normal attack (`heartbeatK.every`) of a troop of the type heals it and each troop within 1.5 tiles (`heartbeatK.reach`) that lacks HP 3% / 4% / 5% of its own max HP (`heartbeatK.heal`), through the heal funnel | `attack` → heal (itself and the troops near): `_blowK`, `_fxHealNear` |
| Mercy Lily (`mercyLily`, Epik) | a heal a troop of the type gets while under 40% of its max HP (`mercyLilyK.below`, before the heal) lands ×1.35 / ×1.5 / ×1.7 (`mercyLilyK.heal`), before the Bayangan Wound's cut; not the Grail's save nor the after-wave heal; the heals its own healers give elsewhere never | `heals` [`hpBelow` 0.4] → heal (itself: a heal it gets): `_fxLily` in `_healTroop` |
| Bright Spring (`brightSpring`, Epik) | a troop of the type that casts a skill (its own, its awakening's or a Hero's) heals itself and each troop within 1.5 tiles (`brightSpringK.reach`) that lacks HP 6% / 9% / 12% of its own max HP (`brightSpringK.heal`), through the heal funnel | `cast` → heal (itself and the troops near): `_fxCast`, `_fxHealNear` |
| Dragon Crown (`dragonCrown`, Legenda) | ★1 only: no blow takes a troop of the type more than `crownCap` 60% of its max HP (a w86 templar takes at most 348 of the boss's 805) | `capped` → cap: `_fxCapped` in `_hurt`, after every other cut (units-and-combat.md "Damage") |
| Oath of One (`oathOfOne`, Legenda, a Sumpah) | ★1 only, the whole army: while `oathOneK.types` 2 types or fewer are alive (`typesAlive`), every troop's HP and damage (a healer's heal) ×`oathOneK.k` 1.5 and the type caps are off; with the board's caps no third type joins then ("Oath of One: only 2 types"); above 2 it waits ("Waiting: keep only 2 types", `oathWaiting`) | `oathWaits`, `typeCapOf`, `typeLocked`; `_oathK` in `statsOf` |
| Alliance (`alliance`, Legenda, a Sumpah) | ★1 only, the whole army: every troop's HP and damage +`allianceK.perType` 5% for each type with a troop alive, at most `allianceK.most` 6 counted (`typesAlive`; 6 types: +30%) | `_oathK` in `statsOf` |
| Oath of the Few (`fewOath`, Legenda, a Sumpah, batch G-4) | ★1 only, the whole army: while `fewOathK.army` 24 troops or fewer are alive (`armySize`), every troop's HP and damage (a healer's heal) ×`fewOathK.k` 1.35; with the board's army cap no 25th troop joins then (`armyLocked`: "Oath of the Few: up to 24 troops", `fewOathBar`; the cap itself stays, so Beban and the Bayangan's over-count never see it); above 24 it waits ("Waiting: keep 24 troops or fewer", `fewWaiting`) | `oathWaits`, `armyLocked`, `full`; `_oathK` in `statsOf` |
| Oath of the Wall (`wallOath`, Legenda, a Sumpah, batch G-4) | ★1 only, the whole army: every troop's max HP ×`wallOathK.hp` 1.4 and its damage (a healer's heal) ×`wallOathK.dmg` 0.8 (the trade) | `_oathStats` in `statsOf` |
| Blood Oath (`bloodOath`, Legenda, a Sumpah, batch G-4) | ★1 only, the whole army: every troop's damage ×`bloodOathK.dmg` 1.3 (a healer's heal not); every heal a troop gets in a wave lands ×`bloodOathK.healIn` 0.5 (the trade: first in the heal funnel, before the Bayangan Wound's cut; its regen too; not the Grail's save nor the heals between waves) | `_oathStats` in `statsOf`; `_oathHealK` in `_healTroop` |
| Oath of the Vanguard (`vanguardOath`, Legenda, a Sumpah, batch G-4) | ★1 only, the whole army: an up-close troop's (`Stats.melee`: no shot, no heal) HP and damage ×`vanguardOathK.melee` 1.4; every other troop's damage (a healer's heal) ×`vanguardOathK.back` 0.75 (the trade) | `_oathStats` in `statsOf` |
| Oath of Kings (`kingsOath`, Legenda, a Sumpah, batch G-4) | ★1 only, the whole army: the Hero aura is ×`kingsOathK.aura` 1.25 (not `auraBoost` 1.15) and a Hero's own two attributes ×`kingsOathK.heroBoost` 2 (not `heroBoost` 3; the trade) | `auraNow`, `heroBoostNow` in `_statsFor` and `fieldStats` |
| Oath of Spells (`spellOath`, Legenda, a Sumpah, batch G-4) | ★1 only, the whole army: every skill's cooldown (a troop's #10 skill, its awakening skill, a Hero's) ×`spellOathK.cd` 0.8, never under `cdFloor` 5 s nor over its own; a troop's normal attack (and a healer's holy light) ×`spellOathK.blow` 0.8 (the trade) | `skillCd` at the three cast gates; `_oathBlowK` in `_blowK` |
| Lone Wolf Pelt (`loneWolf`, Legenda) | ★1 only: while `loneWolfK.few` 3 or fewer troops of the type are alive (`aliveOf`, the one attacking among them), their normal attacks do ×`loneWolfK.power` 2 | `attack` [`fewOfType` 3] → power: `_attackK` |
| Martyr's Flame (`martyrFlame`, Legenda) | ★1 only: when a troop of the type falls, every monster within 2 tiles of it (`martyrFlameK.reach`) takes `martyrFlameK.share` 60% of the fallen one's max HP (extra damage, through each one's defence); the type's max HP ×`martyrFlameK.hp` 0.9 (the trade) | `fell` → burst (the monsters near): `_fxFell`, `_burst`; `always` → stat HP |
| Wide Blows (`wideBlows`, Legenda) | ★1 only: the type's normal attacks (a blow, a shot where it lands) also hit every monster within `wideBlowsK.splash` 16 px more of the target, on top of its own splash (a splash past the target is extra damage); its attack or heal ×`wideBlowsK.dmg` 0.8 (the trade) | `always` → stat splash (+px) and stat attack: `_pusakaStats`; its counter `_fxSplash` at the splash |
| Champion's Mantle (`champion`, Legenda) | ★1 only: the type's Heroes' normal attacks do ×`championK.hero` 1.8, the others' ×`championK.rest` 0.9 (the trade) | `attack` [`hero`] → power and `attack` [`notHero`] → power: `_attackK` |
| Vengeance Mark (`vengeance`, Legenda) | ★1 only: a monster that takes HP off a troop of the type is marked for `vengeanceK.time` 4 s (`Status.pusakaMark`, from that troop; the Bayangan Mark Ward shortens it): every troop's blow on it ×`vengeanceK.taken` 1.25 (the boss ×`vengeanceK.boss` 1.12; a mini boss the whole); the type takes ×`vengeanceK.selfTaken` 1.15 (the trade: a `struck` cut under 0) | `hurtBy` → status pusakaMark (the attacker): `_fxHurtBy`; read in `_afterDefence`; `struck` → cut −0.15 |
| Mirror Shield (`mirror`, Legenda) | ★1 only: from a wave's start every troop of the type reflects `mirrorK.share` 40% of every blow up close back at its attacker, the whole wave (`Status.reflect` from itself; a troop bought mid-wave has none; a stronger reflect, Iron Skin's, takes its slot while it lasts and it comes back after); its attack or heal ×`mirrorK.dmg` 0.8 (the trade) | `waveStart` → status reflect (itself): `_fxWave`, `_fxReflectBack`; its counter `_fxMirrored` in `_answer` |
| Ghost Step (`ghostStep`, Legenda) | ★1 only: every `ghostStepK.every` 3rd blow of a monster on a troop of the type misses (none of it lands; a bleed's tick is no blow; the Bayangan Executioner's bare blow lands, the count going on); its attack or heal ×`ghostStepK.dmg` 0.8 (the trade) | `struck` → status block (itself, every Nth on `Unit.fxN`): `_fxStruck` |
| Ice Grip (`iceGrip`, Legenda) | ★1 only: every `iceGripK.every` 4th normal attack of a troop of the type holds the monster hit in place for `iceGripK.hold` 1 s (`Status.impaled` at walk `fxHoldWalk` 0, from the troop; never over a pin that lasts longer; the Bayangan Unbowed may shrug it off); the boss and a mini boss are slowed to `iceGripK.bossSlow` 70% for `iceGripK.bossTime` 2 s instead; its attack or heal ×`iceGripK.dmg` 0.85 (the trade) | `attack` → status impaled (the monster hit): `_fxFoeStatus` |
| Relic Altar (`relicAltar`, Legenda) | ★1 only: the small relics its troops wear work ×`relicAltarK.k` 1.5 at the four sites the Bayangan Rust weakens (the guard's cut, the fang's heal, the thorns' hit back, the fury's extra; not the Smithy's seven); the type's max HP ×`relicAltarK.hp` 0.85 (the trade) | `always` → relicK: `_relicK` at the four sites, its counter `_fxAltar`; `always` → stat HP |
| Vow of Silence (`vowSilence`, Legenda) | ★1 only: the type's max HP and attack (a healer's heal) ×`vowSilenceK.k` 1.4; it never casts a skill (its #10 skill, its awakening skill nor a Hero's) and spends no MP on one (the trade) | `always` → stat HP and attack (`Stat.hpDmg`): `_pusakaStats`; `always` → skillGate: `_fxSilent` at `_trySkill`'s top |
| Rage Totem (`rageTotem`, Legenda) | ★1 only: while a troop of the type is under `rageTotemK.below` 50% of its max HP (as the attack finds it), its normal attacks do ×`rageTotemK.power` 1.6; every heal it gets lands ×`rageTotemK.healIn` 0.7 (the trade, before the Bayangan Wound's cut; not the Grail's save nor the after-wave heal) | `attack` [`hpBelow` 0.5] → power: `_attackK`; `heals` → heal ×k (itself: a heal it gets): `_fxLily` in `_healTroop` |
| Guardian Chain (`guardianChain`, Legenda) | ★1 only: every `guardianChainK.every` 4th normal attack of a troop of the type links every living troop of another type within 2 tiles of it (`guardianChainK.reach`) to it for `guardianChainK.time` 4 s (`Status.link`, Shared Wounds' link, from that troop; a stronger link on one stays): it takes `guardianChainK.share` 25% of every blow on them, through its own defence (the cost: the hits it takes); a troop already passing that same blow on takes no share of it back (no loop between two links) | `attack` → status link (the troops near): `_fxChain`; read in `_beforeDefence`, its counter `_fxLinked` |
| Phalanx (`phalanx`, Legenda) | ★1 only: while `phalanxK.near` 3 or more other troops stand within 1.5 tiles (`phalanxK.reach`) of a troop of the type, it takes `phalanxK.cut` 30% less damage; its attack or heal ×`phalanxK.dmg` 0.85 (the trade) | `struck` [`alliesNear` 3] → cut: `_fxStruck`; `always` → stat attack |
| Phoenix Plume (`phoenix`, Legenda) | ★1 only: once a wave the type's first troop to fall (never a Hero nor one brought back before: they leave the once for the next) rises again `phoenixK.delay` 3 s later where it fell, a new troop of its name and post at `phoenixK.hpLeft` 30% of its max HP with no MP, never brought back again (Resurrection's way, with its gold summon circle; none once the wave is over, nor while its type may take no troop); the type's max HP ×`phoenixK.hp` 0.85 (the trade) | `fell` [`firstOfTypeThisWave`] → revive (itself): `_fxFell`, `_fxRise`; `always` → stat HP |
| Soul Shelter (`soulShelter`, Legenda) | ★1 only: when a troop of the type falls, every living troop within 2 tiles of it (`soulShelterK.reach`) takes no damage for `soulShelterK.time` 1.5 s (`Status.cap` at 0 from the fallen one, the Grail save's window; a longer one on a troop stays), at most once every `soulShelterK.cd` 6 s for the whole type (one clock, `_fxTypeGate`, set ready at a wave's start; it starts only when one stood near); its attack or heal ×`soulShelterK.dmg` 0.85 (the trade) | `fell` → status cap (the troops near): `_fxFell`; its counter `_fxSheltered` in `_afterDefence`; `always` → stat attack |
| Mana Font (`manaFont`, Legenda) | ★1 only: a troop of the type that casts a skill (its own, its awakening's or a Hero's) gives each other troop within 3 tiles (`manaFontK.reach`) that has MP to fill `manaFontK.share` 25% of that troop's max MP (never one under Vow of Silence), with the heal burst in MP blue; its MP comes back ×`manaFontK.mpRegen` 0.7 as fast (the trade) | `cast` → MP (the troops near): `_fxCast`, `_fxMp`; `always` → stat MP regen |
| Hex Blade (`hexBlade`, Legenda) | ★1 only: every `hexBladeK.every` 8th normal attack of a troop of the type turns the monster hit into a slime for `hexBladeK.time` 2 s as Slime Hex does (`_hexInto`: a normal slime's stats, its gold kept, its own back after; through the duration scaler); never the boss, a mini boss, a necromancer or a healing necromancer, nor a slime; then that troop waits `hexBladeK.cd` 6 s (the Bayangan Unbowed's shrug spends it too); its attack or heal ×`hexBladeK.dmg` 0.85 (the trade) | `attack` → status hex (the monster hit): `_fxFoeStatus`, `_fxHexable`; `always` → stat attack |
| Glory Seeker (`glorySeeker`, Legenda) | ★1 only: a troop of the type that kills a gold monster (a high elite), a mini boss or the boss gives every living troop of its type ×`glorySeekerK.might` 1.25 damage for `glorySeekerK.time` 5 s (a might from it; a stronger might already on one stays); its attack or heal ×`glorySeekerK.dmg` 0.9 (the trade) | `kill` [`foeHighElite`] → status might (its type): `_fxKill`; `always` → stat attack |
| Vampire Kiss (`vampireKiss`, Legenda) | ★1 only: `vampireKissK.share` 12% of the HP a blow of a troop of the type takes off a monster heals the most hurt other troop within 2 tiles of it (`vampireKissK.reach`; the lowest HP share, the nearer on a tie; never itself, nor one at its heal ceiling: Scar's, the Bayangan Blight's), through the heal funnel; every heal it gets lands ×`vampireKissK.healIn` 0.6 (the trade, as Rage Totem's: before the Bayangan Wound's cut; not the Grail's save nor the after-wave heal) | `dealt` → heal (the most hurt troop near, `To.mostHurtNear`): `_fxDealt`, `_fxMostHurt`; `heals` → heal ×k (itself: a heal it gets): `_fxLily` in `_healTroop` |
| Wrath Psalm (`wrathPsalm`, Legenda) | ★1 only: a heal of a healer of the type (its heal, Healing Prayer) also strikes each monster within a tile (`wrathPsalmK.reach`) of the troop healed for `wrathPsalmK.share` 30% of the heal: holy light, a smite (`Hit.smite`) through each one's defence (the Bayangan Holy Ward cuts it on a skeleton), at most once every `wrathPsalmK.cd` 2 s a healer; its attack or heal ×`wrathPsalmK.heal` 0.75 (the trade) | `heals` → burst (the monsters near the troop healed): `_fxHealed`, `_fxPsalm`; `always` → stat attack |
| Grave Seal (`graveSeal`, Legenda) | ★1 only: a monster that a troop of the type takes HP off heals nothing for `graveSealK.time` 3 s (`Status.noHeal` from that troop; a new blow runs it from then; it lands on the killing blow too, so a skeleton never reassembles; the Bayangan Last Gasp's heal is stopped as any); its attack or heal ×`graveSealK.dmg` 0.9 (the trade) | `dealt` → noHeal (the monster hit): `_fxDealt`; its counter `_fxSealed` in `_healMonster`; `always` → stat attack |

Stars: ★1 for each Pusaka bought, migrated or new from the chest; a duplicate from the chest, an Asah ("Asah"
below) or a Lebur (another Pusaka melted into it, "Lebur" below) adds one, up to ★3 (`maxStars`: a Legenda stays ★1, `legendStars`). The Langka's numbers are first drafts
for the probes (the report's PROBE PLAN B), each one constant. A status a Langka puts on a monster (Dulling Mail's,
Challenge Letter's, Snare Cord's) does half on the boss (`Tier.boss`; a mini boss takes it whole), as the Hero
skills' slows and weakens do (`bossShare`), and goes through the duration scaler like theirs (the Bayangan Unshaken).
An `attack` status goes on the monster as the attack is made, a shot's flight aside. Batch L-1P's rows read
`live: liveL1P` (true; a probe's mirror turns it off to check the batch changes nothing else), batch L-2P's `live:
liveL2P`, batch L-3's `live: liveL3P`, batch E-1P's `live: liveE1P`, batch E-2P's `live: liveE2P`, batch E-3P's `live: liveE3P`, batch G-1P's `live: liveG1P`, batch G-2's `live: liveG2`, batch G-3's `live: liveG3` and batch G-4's `live: liveG4` (the same).
A Legenda has no ★2 or ★3: Carve moves one named number of each by its constant's `perStar` a star of worth (`ukirPerStar`,
which says the Fx: Wide Blows' and Ghost Step's trade, the others' first; a boss number beside it stays), so batch
G-1P's ten carve as God's Thunder's share and Dragon Crown's cap do; batch G-2's eight carve their first Fx's number
(Rage Totem's power, Guardian Chain's share, Phalanx's cut, Phoenix Plume's HP back, Soul Shelter's window, Mana
Font's share, Hex Blade's slime time, Glory Seeker's might), and batch G-3's three theirs (Vampire Kiss's share,
Wrath Psalm's share, Grave Seal's seal time).
Witherroot's weaken on the boss is its own list (`witherrootK.boss`), not half the cut; Warden's Horn's taunt has none
on the boss (its boss list is 0, `bossShare(…, 0)`). Anchor's stand has no number, so its first Fx has no k and
`pusakaAt` reads only its trade (`fx: 1`). A cleanse's cooldown, and Null Stone's strip's, is its k (`Fx.cdByStars`:
Salt Charm's, Pure Water's, Saint's Tear's, Null Stone's, so the stars and Carve shorten it; the Bayangan Drag stretches it, as it does
every Rare or Epic Fx's own cooldown). An every-Nth Fx of a Rare or Epic Artifact (never a Legenda's: Ghost Step's, Ice
Grip's, Guardian Chain's, Hex Blade's) waits for the Bayangan Off Beat's
extra hits (`_everyOf`): `_blowK`'s (Bleeding Edge, Mana Leech, Spell Cutter, Ember Brand's mark, Warden's Horn's
taunt, Heartbeat's heal) and `_fxNth`'s (Shatter Shard's hits landed, Riposte's hits taken, counted on `Unit.fxN`).

- **What each did** (`pusakaWorth`, a `PusakaTally` per Pusaka for the wave being fought, cleared by
  `startWave`; the wave's telemetry record carries it): `uses` (the Grail's saves) and `worth`, its effective
  counter: a Grail save is kept once its troop lives `keptAfter` 5 s more or to the wave's end; Dragon Heart counts
  a blow that took its troop past the HP its base would have had (`maxHp × (1 − 1/k)`) and was lived through; Dawn
  Star the extra damage and the extra healing that landed past the base heal (no overheal); God's Thunder the leaps'
  damage; Void Eye the bonus damage its mark added (each at most the HP the target had left); Iron Banner the
  damage it kept off; Blood Fang the HP it drew back (no overheal); War Drum its 3rd blows (`uses`) and the extra
  damage they added before the target's defence; Mourning Bell its tolls (`uses`) and the HP they healed; Titan Bane,
  Finishing Blade and First Cut the blows they raised (`uses`) and the damage they added before the monster's defence,
  Shell Cracker and Twin Fury as War Drum, Steady Stance and Turtle Shell as Iron Banner; Dulling Mail, Challenge Letter
  and Snare Cord the times their status took hold (`uses`; no `worth`); Momentum its charges spent and what they added,
  Bleeding Edge its bleeds and their whole damage (before the monster's defence), Shatter Shard and Riposte their
  bursts and the HP they took, Watch Shield and Bone Buckler the shields given (`uses`) and the damage the shield kept
  off (`_fxWardSoaked`), Pain Crystal and Mana Leech the MP that landed, Looter's Pouch the coins paid, Spell Cutter
  the effects it took (`uses`); Salt Charm and Pure Water the bad effects they ended (`uses`; no `worth`), Wolf Feast
  and Hidden Flask their heals (`uses`) and the HP that landed, Full Cup its shields (`uses`) and what they kept off
  (the shield's giver, `Unit.wardFrom`, gets it, whichever type wears it), Living Moss what its share of the regen
  healed (`_fxRegen`); Healer Bane, Bully's Club and Unity Ring as War Drum, Arrow Catcher and Hero's Cloak as Iron
  Banner, Rune Gauntlet the mights it gave and Witherroot the monsters it weakened anew (not a refresh) (`uses`; no
  `worth`), Hawk Feather the attacks it made from past its old range (the range ÷ k, `_fxReach`; `uses`), Stone Coat
  what its defence kept off each blow (`_fxDefence`), Moonwell the MP its quicker regen gave (`_fxMpRegen`, at the MP
  tick); Ember Brand its marks spent (`uses`) and what they added before the monster's defence, Funeral Pyre as
  Shatter Shard, Null Stone the monsters it stripped and Warden's Horn the monsters it taunted (each one; `uses`, no
  `worth`), Fallen Flag the mights it gave, Aegis Seal as Watch Shield, Anchor the shoves and drags its troops stood
  (`_fxStood`, `uses`); Mana Hymn the MP that landed, Saint's Tear the bad effects it ended (`uses`; no `worth`), Brave
  Song the mights it gave (`uses`), Halo Lantern, Heartbeat and Bright Spring their heals (`uses`, one a heal however
  many troops it reached) and the HP that landed, Hearth the troops it healed and the HP, Mercy Lily the heals it raised
  (`uses`) and the HP its × added (`worth`); Lone Wolf Pelt and Champion's Mantle (its Heroes') as War Drum, Martyr's
  Flame as Shatter Shard, Wide Blows the splash hits past the old splash (`uses`) and their damage, Vengeance Mark the
  marks it put on (`uses`) and the bonus damage they added (`fxMarks`), Mirror Shield the hits it sent back and their
  damage, Ghost Step the blows that missed (`uses`) and their damage, Ice Grip the monsters it held or slowed (`uses`;
  no `worth`), Relic Altar what the small relics did past what they would have without it (each site's × 1 − 1/k),
  Vow of Silence the damage and healing its × added (as Dawn Star); Rage Totem as War Drum, Guardian Chain the links
  it put on (`uses`) and the damage it took for the troops near (`_fxLinked`), Phalanx as Iron Banner, Phoenix Plume
  the troops it brought back, Soul Shelter the troops it sheltered (`uses`) and what the window kept off
  (`_fxSheltered`), Mana Font the MP that landed, Hex Blade the monsters it hexed and Glory Seeker the kills that gave
  its might (`uses`; no `worth`); Vampire Kiss its heals (`uses`) and the HP that landed, Wrath Psalm its smites
  (`uses`, one however many monsters it reached) and their damage, Grave Seal the monsters it sealed fresh (`uses`; a
  seal run on from a new blow counts none) and the HP of the monster heals its seal stopped (`_fxSealed`). A trade's own line (k under 1: Living Moss's and Hawk Feather's attack, Moonwell's
  max HP, Anchor's walk speed, Champion's Mantle's others, Rage Totem's and Vampire Kiss's heals got; a cut under 0: Vengeance Mark's more
  taken) counts nothing.
  The log's
  report and the "VICTORY!" line read them as "+5k damage blocked", "+3.2k HP drained", "+12k damage", "rang 2 times,
  +900 HP", "slowed 12 times", "stripped 3 times", "+40 MP", "+120 gold", "cleared 3 bad effects", "+340 HP from
  kills", "drunk once, +240 HP", "powered up 4 times", "34 hits past its old range", "stood firm 3 times", "+1.2k HP to
  troops near", "+900 HP at wave end", "+640 HP from hits", "+1.5k HP from skills", "+300 HP more healed", "held 5
  times", "+310 from relics", "+520 damage & heal", "took +640 for troops near", "sheltered 3 troops, +450 blocked", "brought
  back 1 troop", "hexed 3 times", "+1.2k HP to the most hurt", "stopped
  +2.3k monster heals" (decisions-log 197: "6 saved", "4 hits lived";
  a count of one singular, "1 hit", "rang once", "taunted once"). MP and gold never name "VICTORY!" (they don't weigh
  against damage).
- **What the player sees** (P2 "Bukti", decisions-log 149; the drawing is ui-hud.md "The Pusaka in battle"):
  - on the field: a 1 px ring in the Pusaka's colour under the feet of every troop of a bound type, and the Pusaka's
    icon left of its HP bar (past the small relics it holds);
  - the Grail's cut-in, once a wave, on its first save ("Grail saves Kael Drake!"): `Game.grailFirst`, set by
    the save (`_fxLethal`) when the wave's tally reaches 1 save and cleared by the UI (and by `startWave`);
  - the battle log: a line for each Grail save (`GrailSaved`: name, type, Hero), a second row under a fall for the
    small relics it sent back to the bag ("Fury back in the Bag", from `TroopFell.relics`), and at a won wave a
    `PusakaReport` (emitted right before `WaveEnded`): every bound Pusaka with its type, stars, `uses` and `worth`,
    in `Relic` order, and the small relics that came back from falls that wave (`Game.relicsBack`, cleared by
    `startWave`). None when nothing is bound and nothing came back. Both events stay out of the telemetry's stream:
    its wave record has the same counts;
  - "VICTORY!": one line from the report (`Game.lastPusaka`, the last won wave's), naming its best counter
    (`PusakaReport.best`): troops kept alive first, the Grail's kept saves or Dragon Heart's blows lived through,
    whichever is more (the Grail on a tie); else the most damage or healing added (Dawn Star, God's Thunder, Void
    Eye); none when every counter is 0;
  - **build names** (each row's `Art.epithet`, gathered in `buildEpithets`; `buildNameOf(type)`): a type with a Pusaka bound goes by
    the Pusaka's epithet before its name (English word order), on the Army page and its troops' plates: Grail
    "Undying" ("Undying Templar"), Dragon Heart "Giant" ("Giant Templar"), God's Thunder "Storm" ("Storm Wizard"), Dawn
    Star "Dawn" ("Dawn Priest"), Void Eye "Void" ("Void Archer"); the Langka Iron Banner "Steel", Blood Fang "Blood",
    War Drum "War", Mourning Bell "Mourning", Titan Bane "Fearless", Finishing Blade "Ruthless", First Cut "Keen",
    Shell Cracker "Breaching", Twin Fury "Furious", Steady Stance "Steady", Turtle Shell "Turtle", Dulling Mail
    "Dulling", Challenge Letter "Bold", Snare Cord "Snaring", Momentum "Rushing", Bleeding Edge "Rending", Shatter Shard
    "Shattering", Pain Crystal "Crystal", Watch Shield "Watchful", Bone Buckler "Bone", Riposte "Parrying", Mana Leech
    "Leeching", Looter's Pouch "Greedy", Spell Cutter "Dispelling", Salt Charm "Warding", Wolf Feast "Ravenous", Full
    Cup "Brimming", Hidden Flask "Prudent", Living Moss "Mossy", Pure Water "Pure"; the new Epik Healer Bane
    "Merciless", Bully's Club "Cruel", Unity Ring "United", Rune Gauntlet "Runic", Hawk Feather "Hawk", Witherroot
    "Withering", Arrow Catcher "Arrowproof", Stone Coat "Stone", Hero's Cloak "Cloaked", Moonwell "Moonlit", Ember Brand
    "Ember", Funeral Pyre "Burning", Null Stone "Null", Fallen Flag "Rallying", Aegis Seal "Aegis", Warden's Horn
    "Warden", Anchor "Anchored", Mana Hymn "Hymnal", Saint's Tear "Saintly", Brave Song "Brave", Halo Lantern "Haloed",
    Hearth "Hearty", Heartbeat "Pulsing", Mercy Lily "Merciful", Bright Spring "Bright"; the Legenda Dragon Crown
    "Crowned" (the oaths, the army's, none), Lone Wolf Pelt "Lone", Martyr's Flame "Martyred", Wide Blows "Sweeping",
    Champion's Mantle "Champion", Vengeance Mark "Vengeful", Mirror Shield "Mirrored", Ghost Step "Ghostly", Ice Grip
    "Frozen", Relic Altar "Hallowed", Vow of Silence "Silent", Rage Totem "Raging", Guardian Chain "Guardian", Phalanx
    "Serried", Phoenix Plume "Phoenix", Soul Shelter "Sheltering", Mana Font "Wellspring", Hex Blade "Hexing", Glory
    Seeker "Glorious". The twenty-six newer Langka, the twenty-five new Epik and the eighteen new Legenda have no colour of their own yet: their ring is cream and their build name
    the book's ink (`_pusakaColorElse`, `_pusakaInkElse`). `pusakaShortName` drops the Grail's "of Immortality" where a line is
    short.
- **A save from before them** (`_migratePusaka`, in `fromJson`): every artefact in its bag and every one its troops
  wore (taken off) counts: the first of a kind is owned at ★1, each further one adds a star up to ★3, past it pays
  back `copyRefund` 50% of its base price. Then the new ones are bound by default (`pusakaPrefs`: each in turn, in
  the order Dragon Heart, Grail, God's Thunder, Dawn Star, Void Eye, to the first living type on its list that
  holds none yet; with none, the Gudang), after the saved HP is restored, so Dragon Heart's HP comes with it. The
  owner's wave-86 save: Dragon Heart → Templar, Grail → Armored Axeman, God's Thunder → Wizard, Dawn Star → Priest,
  Void Eye → Archer, each ★1; its small relics are as they were. A one-time message waits (`Game.notes` lacks
  `pusakaNote`; `pusakaNoteDue`). The board shows it once when the game comes in (`pusakaNotes()`, which marks it
  shown, like `limitNotes`; decisions-log 151): "Artefak kini Pusaka: untuk semua pasukan sejenis, / juga yang dibeli
  lagi, tidak hilang saat gugur. / Put on for you: change or Undo in the Bag." (`pusakaNoteLines`,
  `pusakaNoteSuggested`; "Equip them in the Bag." when nothing could be bound; the last line English since the Bag's
  grid, decisions-log 187). While the suggestion stands (`pusakaSuggested`) the Bag page keeps Undo (`undoDefaultBinding`: every suggested one back to the Gudang, its
  first binding free again; `whyNotUndoDefault` refuses after game over, mid-wave or with none left, "Tidak ada saran
  lagi") and OK (`dismissPusakaNote`: the suggestion stands, a later move is a Pindah). A wave begun keeps it too
  (the board calls `dismissPusakaNote`). A new game, or an old save with no artefact, has nothing to tell.
- Probe hooks (instance members, so the probes reach them through `dynamic`): `givePusaka(relic, {type, stars})`
  (owns it at those stars, bound or in the Gudang; no price, no event) and `bindByDefault()` (the migration's rule
  for what waits in the Gudang).

### The Pusaka catalog and its engine (decisions-log 178)

The owner asked for about 30 Pusaka a tier (2026-10-02), so a Pusaka is data: one row of `pusakaCatalog`
(`lib/pusaka_catalog.dart`), run by one engine (`lib/pusaka_engine.dart`). Today's twelve are rows; nothing they do
changed (the w89 identity probe, testing.md "The Pusaka"). Batch L-1P (decisions-log 205) added the first ten new
Langka (the table above) as rows only, on the Fx it built below; batch L-2P (decisions-log 207) the next ten the same
way, batch L-3 (decisions-log 209) the last six, batch E-1P (decisions-log 211) the first ten new Epik, batch E-2P
(decisions-log 214) seven more, batch E-3P (decisions-log 223) the last eight, batch G-1P (decisions-log 231) the
first ten new Legenda, and batch G-2 (decisions-log 238) eight more.

- **A row** (`Art`): its `rarity`, Ukir `role` (attack, guard, life; none for an oath), `icon` (an `IconRef`), at most
  two `fx`, its build name's `epithet`, the Bayangan kind that answers it (`counter`, and Dawn Star's `healerCounter`
  on a healer), `store` (the Toko sells it: today's five) and `live` (false: never dealt by the chest nor sold, for a
  data batch switched off). `Relic.rarity` and `Relic.store` read the row; the enum value is the save key, so a new
  Pusaka is appended. The oaths' rows hold no Fx: their rules stay bespoke (pusaka.dart, "Legenda" below).
- **An Fx** (`Fx`): its trigger `on` (`Trig`), an optional condition `when` (`If`, with `ifK`, `ifR` and `ifRelic`, the
  small relic `holds` asks about), what it does `eff` (`Eff`, with `stat` or `status`) to whom `to` (`To`), and its
  numbers: `k` by stars (one: the same at every star; read through `pusakaAt`; a taunt's k is its time, a strip's its
  cooldown), `boss` (k on the boss), `every` (the trigger's every Nth; `furyBeat`: that Nth is a worn fury's, Twin
  Fury's, so the Bayangan that stretch an every-Nth Fx skip it), `count` (a whole number by stars, `pusakaCountAt`; a
  kill's ward: its most in kills' worth, Bone Buckler's), `r` (reach, px), `cd` (its own cooldown a troop,
  `Unit.fxReady`, through `_fxGate`; `FxBound.cd` holds it, or a strip's k; `Fx.cooled`: it has one), `cap`, `time`,
  and `regen` (with stat HP: that share of the new max HP back a second). Every number names a `*K` constant (`k: ironBannerK`).
- **The triggers** and where each fires: `always` (the stat fold, `_pusakaStats` in `statsOf`), `army` (the oaths,
  bespoke), `attack` (every Nth normal attack on `Unit.blows`, the counter a worn fury shares: `_blowK` in `_strike`
  and `_smite`), `landed` (`_fxLanded` after a blow and after any shot lands), in `_hurt`: `pierce` (a troop's blow on
  a monster, before its defence), `struck` (a troop hit, after its defence), `capped` (after every other cut), `dealt`
  (a troop's blow took HP), `hurtBy` (a troop lost HP; the attacker may be null), `lethal`, `fell` and `kill`; `heals`
  (`_castHeal`, Healing Prayer), `cast` (a troop skill, an awakening skill, a Hero skill), `waveStart` (`startWave`)
  and `waveEnd` (the win, before the wave's report).
- **The books:** `FxBook`, each type's bound Fx by trigger, each `FxBound` with its numbers at the stars read once.
  Rebuilt (`_rebook`) before the next read after any change to a Pusaka owned: `OwnedPusaka`'s `type` and `stars` and
  `Game.pusaka`'s entries (a `MapBase` that counts its writes) bump one count, `_pusakaEdits`, so no bind, star-up,
  Lebur, sale, load or test edit can leave a book stale. `_hurt` looks up the two books (the troop hit's type's, the
  attacking troop's type's) once a blow.
- **Extra damage** (a leap) runs only the `dealt` Fx in it (`Game._fxDepth`): never `pierce`, `hurtBy`, `kill` nor
  another leap. A reflect passes no attacker.
- **Unit state** (none saved): `fxOnce` (the once-a-wave flag, the Grail's save; cleared by `startWave`; it replaced
  `grailUsed`), `fxN` (the every-Nth count of `landed`, `struck`, `hurtBy`), `fxReady` (an Fx's own cooldown),
  `ward` (a shield's HP), `emberMark` (a one-hit mark from another type) and `charge` (a kill's power on the next
  normal attack: Momentum's, dropped at a wave's start); and the shared hooks' (below): `firstStrikeAt`, `belowHp` and
  the near counts' stamps.
- **Heals and the ward** (decisions-log 181): every heal an Fx gives goes through the troop heal funnel (`_healTroop`,
  lib/heal.dart; units-and-combat.md "The heal funnel"): Blood Fang's and Mourning Bell's tagged `pusaka`, the Grail's
  save `grail` (never cut by the Bayangan Wound). The funnel returns the heal past full HP, for the `healPastFull`
  condition. `Unit.ward` works: `giveWard` grants it up to `wardMax` (0.20 of max HP, the band's one value), `_hurt`
  breaks it before the HP, and it ends with the wave. Batch L-2P's Watch Shield (at a wave's start) and Bone Buckler
  (on a kill) give it; what it soaks counts for the Pusaka whose shield it is (`_fxWardSoaked`; a type holds one). On
  the field a troop with a ward shows the guard's mark over it, as an absorb does (ui-hud.md "The Pusaka in battle").
- **Cleanse and noHeal** (decisions-log 184; units-and-combat.md "Cleanse and noHeal"): `struck` → `cleanse` (itself)
  ends the bad effects monsters put on its troop (`Game.cleanse`), as many as its `count` a star (none: all), the most
  time left first, counted in the tally's `uses`; `dealt` → `noHeal` (the monster hit) puts `Status.noHeal` on it for
  its k s (its number, so Carve moves it: Grave Seal's; a seal fresh is a use, and `_fxSealed` counts the HP of each
  heal it stops): its heals land as 0, and a skeleton it kills doesn't reassemble. Each has its words ("When hit:
  clears 1 bad effect", "Monsters it hits can't heal for 3s"; the gist "Hit: no heals 3s"): Salt Charm's cleanse and
  Grave Seal's noHeal (batch G-3).
- **Built so far** (`fxBuilt`): `always` → stat HP or attack, `attack` → power, or a slow or a taunt on the monster hit
  (`_fxFoeStatus`), `landed` → leap, `pierce` → power (the monster hit), `struck` → cut or cleanse (itself), `capped`
  → cap, `dealt` → heal (self), Void Eye's mark or noHeal (the monster hit), `hurtBy` → weaken on the attacker (a
  living monster that took HP off the troop, on the Fx's own cooldown), `lethal` → save, `fell` → heal (troops
  near); batch L-2P's: `attack` → a bleed (the monster hit), MP (itself, `_fxMp`) or a strip (`_fxStrip`), `landed` →
  burst (the other monsters near the target, `_burst`), `struck` → MP, `hurtBy` → burst (a hit back at the attacker),
  `waveStart` and `kill` → ward (itself), `kill` → power (one charge) and gold (`_fxGold`); batch L-3's: `kill` and
  `struck` → heal (itself), `heals` → ward or cleanse (the troop healed), `always` → stat regen; batch E-1P's:
  `always` → stat range (a melee type's up to its reach cap, `Stats.reachCap`), defence (+), walk speed and MP regen, `dealt` →
  weaken (the monster hit, `_fxFoeStatus`), `cast` → might (itself, `_fxCast`); batch E-2P's (decisions-log 214):
  `attack` → a mark (the monster hit, `Unit.emberMark`: `_fxMark`; the next blow of another type spends it, `_fxEmber`
  in `_hurt`) and a taunt on the monsters near (`_fxHorn`, each through `_fxFoeStatus`), `kill` → burst (the monsters
  near the dead one, a share of the killing blow before its defence: `_fxKill`, `_burst`), `hurtBy` → strip (the
  attacker, Spellbreaker's `_strip`; its cooldown starts only when there was something to take, `_fxStrippable`),
  `fell` → might (the troops near), `waveStart` → noShove (itself, all wave), `cast` → ward (itself); batch G-1P's
  (decisions-log 231): `always` → stat splash (px added to a normal attack's splash), stat HP and attack together
  (`Stat.hpDmg`), relicK (the worn small relics ×, `_relicK`) and skillGate (no skill cast, `_fxSilent`), `attack` →
  a hold (`Status.impaled`; on the boss and a mini boss a slow), `fell` → burst (the monsters near the fallen one),
  `hurtBy` → `Status.pusakaMark` on the attacker, `struck` → a block (every Nth monster blow misses: `_fxStruck`
  returns none) and a cut under 0 (more damage taken), `waveStart` → reflect (itself, all wave); batch G-2's
  (decisions-log 238): `attack` → a link on the troops of other types near (`_fxChain`, Shared Wounds' `Status.link`)
  and a hex on the monster hit (`_fxFoeStatus`, Slime Hex's `_hexInto`), `heals` → heal ×k on every heal it gets (a
  trade under 1: Rage Totem's), `fell` → cap 0 (the troops near, on one cooldown for the whole type, `_fxTypeGate`)
  and revive (itself, `_fxRise`), `cast` → MP (the troops near), `kill` → might (every troop of its type); batch G-3's
  (decisions-log 243): `dealt` → heal (the most hurt other troop near, `To.mostHurtNear`: `_fxMostHurt`), `heals` →
  burst (the monsters near the troop healed, a smite: `_fxPsalm`), and `dealt` → noHeal's number is its k. Any other Fx throws a
  `StateError` naming it, and test/pusaka_catalog_test.dart fails its row first: each comes with the data batch that
  needs it.
- **The conditions** (`fxIfsBuilt`, decisions-log 182; `_fxWhen`), checked when the trigger fires, for the troop holding
  the Pusaka and the monster in play (the one it hits at `attack`, `landed`, `pierce`, `dealt` and `kill`; the one
  hitting it at `struck`, `capped`, `hurtBy`, `lethal` and `fell`; none at `heals`, `cast` and a wave's start or end):
  `hpBelow` / `hpAbove` (the troop's HP under / over `ifK` of its max HP, as the trigger finds it: before the blow at
  `struck`), `foeHpBelow` / `foeHpAbove` (the monster's), `alliesNear` (`ifK` or more other troops within `ifR` px) and
  `firstOfTypeThisWave` (the first time this wave the Fx's condition is asked and passes, for any troop of the type:
  the ask uses it up; cleared by `startWave`); batch L-1P's (decisions-log 205): `vsBoss` (the monster is the boss or
  a mini boss), `foeShielded` (it holds a shield, `shielded`), `melee` (the troop fights up close) and `holds` (the
  troop wears the small relic `ifRelic`); batch L-2P's (decisions-log 207): `attackerMelee` (the monster hitting the
  troop fights up close); batch L-3's: `healPastFull`; batch E-1P's (decisions-log 211): `foeHealer` (the monster is
  a healer), `foeHeld` (`foeHeld`: `held`, a slow, a pin or a stun, or a hex), `typesAlive` (`ifK` or more troop types
  alive, `typesAliveNow`: counted once a tick, `Game._typesTick`), `attackerRanged` (the monster hitting the troop
  shoots) and `hero` (the troop is a Hero); batch G-1P's (decisions-log 231): `fewOfType` (`ifK` or fewer troops of
  the type alive, `aliveOf`) and `notHero` (the troop is no Hero); batch G-2's (decisions-log 238): `foeHighElite` (the
  monster is a high elite, a mini boss or the boss, by rank). The others are stubs that their batches build.
- **The shared hooks** (decisions-log 182; the end of lib/pusaka_engine.dart): what the batches' rules read, changing
  no fight by themselves.
  - The near counts: `alliesNearOf(u, r)` (other living units of `u`'s side on the field within `r`: troops for a
    troop, monsters for a monster) and `foesNearOf(u, r)` (the other side's). Each is counted at most once a tick
    for a reach (`Game._ticks`), so a hot trigger (`struck` on every blow) scans the field once a tick, not once a
    blow.
  - `belowOnce(u, share, flag)`: true the first time living `u` is at or under `share` of its max HP for `flag` (a bit
    of `Unit.belowHp`, its rule's own), then false. A killing blow uses none. A monster keeps its bits for good; a
    troop's are cleared when a wave starts. For Second Skin, Last Rage, Last Gasp and Hidden Flask.
  - `Unit.firstStrikeAt`: when it first struck, its first blow through `_hurt` as the attacker (+∞ until then; a
    troop's anew each wave). For Enrage.
  - The duration scaler at `addEffect` (units-and-combat.md "The effect store"), 1 today; and the hit-source tag on
    every blow (`Hit`, units-and-combat.md "Damage").
- **The counters** by family (`FxFamily`, from the first Fx): `added` (power, a leap, a mark, a stat's attack, a burst,
  a bleed), `keptOff` (a cut, a cap, a ward's soak), `healed`, `saves` (and how many lived on), `survived` (a stat's
  HP: blows lived through; a trade's max HP down none), `applied` (a status that adds no damage of its own, a slow, a
  weaken, a taunt, a skill's might, or a strip: the times it took hold, never on "VICTORY!"; the log says "slowed 12
  times", "weakened once", "taunted 3 times", "powered up 4 times", "stripped 3 times"; a range's attacks from past
  the old one, "34 hits past its old range"; and a stand's shoves and drags stood, "stood firm 3 times"), `mana` ("+40 MP", a quicker MP regen's too) and `gold` ("+120 gold"),
  neither on "VICTORY!". A defence stat is `keptOff` ("+450 damage blocked": Stone Coat).
  `PusakaReport.best`, the "VICTORY!" line and the log's rows (`pusakaCounter`, `_counterLong`) read the family and the
  first Fx's trigger and effect, so a new row gets its counter's words for free. A mark's bonus is counted for the
  Pusaka that marks with it (`fxMarks`: Void Eye's `Status.voidMark`, Vengeance Mark's `Status.pusakaMark`; Ember
  Brand's one-hit mark names its own, `Unit.emberMark`). Batch G-1P's: a block is `keptOff` ("+160 damage blocked":
  Ghost Step), a hold `applied` ("held 5 times": Ice Grip), a reflect, a splash, a relicK and an HP-and-attack stat
  `added` ("+220 damage", "+310 from relics", "+520 damage & heal"). Batch G-2's: a link and a fall's shelter
  `keptOff` ("took +640 for troops near", "sheltered 3 troops, +450 blocked"), a revive `saves` ("brought back 1
  troop"), a hex and a kill's might `applied` ("hexed 3 times", "powered up 2 times"). Batch G-3's: a blow's heal
  on the most hurt troop near `healed` ("+1.2k HP to the most hurt"), a heal's smite `added` ("+640 damage"), a seal
  `keptOff` ("stopped +2.3k monster heals").
- **The words:** one template per (trigger, effect) (`fxLines` for the item text, `fxGist` for a Tas row; the
  tooltip's sums in `pusakaTotals` by the first Fx too), in the item text's simple English from the row's numbers.
  Owner decision 2's default: the templates may say "skill" and "MP" (`fxWords`).
- **The icons** (`IconRef`): a square cell of a sheet in `assets/images/`; `relicIcon(relic)` for every relic (a
  Pusaka its row's, a small relic its own `relic_<name>.png`). main.dart's preload, `_icon`, the chest's cards, the
  guide's pictures and the Toko read it. A Pusaka's is its own cell of the Artifacts' atlas (`artifactIcon(kind)`,
  `lib/artifact_icons.dart`), drawn whole and untinted: its rarity shows by the frame around it.
  - The loot icons, `item_<Item>.png` and `relic_<name>.png` (the eleven small relics, and the seven Pusaka that had
    one), are single icons of Kenmi's "Cute Fantasy Icons Premium" (decisions-log 194), 32×32 (the 16 px art
    doubled); `LOOT` in `tool/import_fx.py` names each one's icon in the pack. Fang is a white fang, Thorns a red
    shield with a jagged rim, Fury a burning skull, Guard a blue shield; the Smithy's seven (decisions-log 227):
    Sweep a steel axe on a long haft (Weapons 871), Venom a short green blade (Weapons 535), Mana Siphon a cyan crystal
    (Resources 26), Spirit Ward a silver ring (Resources 511), Iron Will a red heart (Monster_Drops 81), Giant Slayer a
    steel war hammer (Weapons 1321), Holy Charm a gold cross (Treasure&Keys 667); none another loot's or an
    Artifact's. The seven Pusaka files (Iron Banner, Blood
    Fang, War Drum, Mourning Bell, Dragon Crown, Oath of One, Alliance) are no longer drawn: their icons moved into
    the atlas, and the files go once the owner's game is closed (dev-workflow.md "Traps").
  - The Artifacts' atlas, `artifact_icons.png`: a 32×32 cell for each of the catalog's 90 kinds (30 Langka, 30 Epik,
    30 Legenda), 10 a row, in the order of `ARTIFACTS` in `tool/import_fx.py`, which names each one's icon in the
    pack and what it shows; `artifactIconKinds` holds the same order and pusaka_catalog_test checks they agree. A
    built Pusaka's kind is its `Relic` name, the rest are their catalog constant's stem (`titanBaneK`: `titanBane`),
    so a data batch's row says `artifactIcon('<kind>')`. Every kind has its own icon, and none looks like an item or
    a small relic. Where the pack has no such thing (it has no crown, scroll, banner, drum, bell, instrument or pyre)
    the icon shows the nearest one by name and effect: Iron Banner steel plate under a red war cloak, War Drum a red
    drum between wooden hoops, Mourning Bell a blue tear, Dragon Crown a gold horned helm, Alliance a gold chain,
    Oath of One and the six other padlocked oaths a padlock each (its own colour), Vow of Silence a small steel padlock, Brave
    Song a red plume, Funeral Pyre a burning torch, Martyr's Flame a torch of blue flame, Relic Altar a stone pillar,
    Rune Gauntlet a rock veined with violet runes (a gauntlet would look like the Gloves item), Challenge Letter a
    white sheet, Witherroot a grey dead twig, Lone Wolf Pelt a tuft of grey fur, Rage Totem a red tusked beast helm,
    Phoenix Plume a wing of fire, Soul Shelter a blue soul orb in a ring, Mana Font a blue ewer, Glory Seeker a gold
    medal, Vampire Kiss a grey wing, Wrath Psalm a red cross, Grave Seal a bone.
- **The band** (`fxBand`, anti-creep): by what an Fx gives (`Band`: power, HP, cut, heal of damage or of max HP, heal
  output, a mark, a leap, a save, a ward) and the rarity, the most at ★1 / ★2 / ★3, today's ranges; a condition (not
  a `hardConds` one) or a trade lets it go `condBonus` / `tradeBonus` 1.25 past; an every-Nth power at most War
  Drum's `perProcMax`, and a kill's one charge too (Momentum: a proc, no mean gain); a bleed and a burst count as
  power, their share of a hit on one monster ÷ their every, a skill's or a fall's might (Rune Gauntlet, Fallen Flag)
  its k − 1 and an every-Nth one-hit mark (Ember Brand) its k − 1 ÷ its every, at most `perProcMax` as a proc; a
  kill's burst (Funeral Pyre: a share of the blow that killed, on a cooldown) none, a probe arm; a heal of max HP an
  event (Heartbeat, Bright Spring) the heal of max HP, Epik's no bigger than Langka's (Mourning Bell's: the design names
  none); a share of a heal to each of its troops (Halo Lantern: k × its count) and a heal got ×k (Mercy Lily: k − 1,
  with its condition's bonus) heal output; a heal at a wave's end (Hearth) none, a probe arm; a trade's own
  line (k under 1) none; a ward its most (k × its `count` of kills); `fxBandExempt`
  names what no band measures (MP, gold, a strip, a taunt and a stand among them). A Legenda has no band (a rule and a real cost).
- **The owner's answers** (2026-10-03; one constant each): new Epik stay off the Toko's shelf (`newEpikStore` false,
  each new Epik row says `store: newEpikStore`), though one may still be sold to it; no Bayangan kind is shared in the
  end, each sits in one tier's pool (`OmenKind.tiers` stays a set: today's seven sat in all three until the Langka
  cut-over, batch L-3, took Armor, Mend, Barrier and Escort out of the Langka pool, and the Epik cut-over, batch E-3,
  Haste, Spikes, Wound, Barrier and Escort out of the Epik pool, and the Legenda cut-over, batch G-3, the last, Armor,
  Mend, Haste, Spikes and Wound out of the Legenda pool: `omenOneTier` holds every kind to one, "Bayangan" below); the texts may say "skill" and "MP"
  (`fxWords`).
- No die is drawn: the engine counts, compares and multiplies.

### Legenda (P5, decisions-log 155)

The rule-changers. Owner decision 7 is unanswered, so its default (a) is built: they come from the boss's chest from
wave `legendFrom` 20, each at most once a run, and at most one oath (Sumpah). Every number is one constant in
lib/pusaka.dart (`crownCap`, `oathOneK`, `allianceK`, `legendStars`, `legendaPrice`). Batch G-1P (decisions-log 231)
added ten more as catalog rows (the table above: Lone Wolf Pelt to Vow of Silence, `draft.dart`'s `*K` constants, ★1
only, never in the Toko, a Gudang one sold back at half of `legendaPrice`), and batch G-2 (decisions-log 238) eight
more the same way (Rage Totem to Glory Seeker), and batch G-3 (decisions-log 243) three more (Vampire Kiss, Wrath
Psalm, Grave Seal), and batch G-4 (decisions-log 247) the last six, all oaths (Oath of the Few, Oath of the Wall,
Blood Oath, Oath of the Vanguard, Oath of Kings, Oath of Spells; `pusaka.dart`'s `*K` constants), so the chest's
Legenda pool is thirty, the catalog's whole count (catalog-design §3.3), eight of them oaths.

- **Dragon Crown** binds to a type like any Pusaka (Pasang, Pindah, the Gudang, Jual for half of `legendaPrice`
  40,000). Its cap is its own check at the end of `_hurt`, never a `Status.cap` (the design's critique M3: a cap
  effect ends with the wave, a Grail save's would replace it, and Bastion fires only while no cap is on): a Grail
  save's untouchable (cap 0) and Bastion's 8% still go under it, and Bastion still fires. It caps a blow; it doesn't
  save a life: from below 60% the next blow still kills. Its counter (`pusakaWorth`): the blows it cut (`uses`) and
  the HP that kept (`worth`, at most what the troop had), "+4.6k blocked" ("3 hits cut, +4.6k HP kept" in
  the log).
- **The oaths** (`Relic.oath`, `Game.oath`): taken from a chest they work on the whole army at once; they bind to no
  type, are never in the Gudang (`gudang`, `inBag` 0), never sell and never come off: an oath is for the run, and
  Carve has none (`ukirRole` null: "An Oath can't be carved"). Oath of One and Alliance count the types alive
  (`typesAlive`: the types with a troop alive), since decisions-log 201 replaced the roster of 4 types a run with a cap
  per type (units-and-combat.md "The owner's limits"); Oath of the Few counts the troops alive (`armySize`). The oath
  the troops were last refit to is `_oathOn` (null with none) and the multiplier of a moving oath (One, Alliance, the
  Few) `_oathK` (1 with none); `_oathStats` applies the oath's change last in `statsOf` (HP rounded, damage; not the
  defence or the regen): `_oathK` on both, or the Wall's, Blood's or the Vanguard's own (the table above). Oath of
  Kings and Oath of Spells change no `statsOf`: Kings' aura and Hero ×2 are `auraNow` and `heroBoostNow` in `_statsFor`
  (and `fieldStats`, `auraLine`); Spells' cooldowns are `skillCd` and its normal hits `_oathBlowK` in `_blowK`; Blood's
  heal cut is `_oathHealK` in the heal funnel (units-and-combat.md "Oaths in a fight"). `_oathWatch` refits every troop
  when `oath` or `_oathK` moves (a type dies out or comes back, a troop falls or is bought, a type is sent home, an oath
  is taken), every tick and after each change between waves; a save's troops are all in before their stats, so the
  oath works on load. With no oath every one of these is exactly 1 (or the base), so a run without one fights the same.
  - **Oath of One** waits (`oathWaits`) while more than 2 types are alive; Lepas jenis (or the fight) brings them
    down, and at 2 or fewer it works (`oathOneWorks`). While it works the type caps are off (`typeCapOf` null): its two
    types may fill the army, as they could under the roster of 2 it had before. With the board's caps on, a type with
    none alive can't join while 2 types are alive (`typeLocked`, `oathOneBar` "Oath of One: only 2 types"; while it
    waits, with more, the same), so one tap never ends the oath; a type dying out frees its place. With no board caps
    (a plain `Game()`) it bars nothing. Its before/after: before, "the roster holds 2 types or fewer" (a type kept
    its place in the roster when it died out); now "2 types alive or fewer", plus the caps off.
  - **Alliance** counts the types alive, at most `allianceK.most` 6: a type dying out mid-wave takes its 5% away at the
    next tick (the HP only capped, as any refit), a type bought back gives it again. Its before/after: before, the
    roster's limit 6 (not 4) and +5% per roster type alive (so +30% at most); now no limit to open, and +5% per type
    alive up to 6 (+30% at most, the same).
  - **Oath of the Few** (batch G-4's M piece) waits while more than `fewOathK.army` 24 troops are alive (Lepas, a
    sale or the fight brings them down) and at 24 or fewer works: HP and damage ×1.35. With the board's army cap
    (`armyMax`) a 25th troop can't join while it is held (`armyLocked`, part of `full`: Buy refuses with
    `fewOathBar` "Oath of the Few: up to 24 troops", Resurrection and a recall swap respect it too, `autoHeld` counts
    against the 24); the cap itself (`armyCap`) stays, so Beban and the Bayangan's over-army count are untouched.
    With no board cap (a plain `Game()`) it bars nothing. Its wait words are its own (`oathWaitingOf`: "Waiting: keep
    24 troops or fewer", the Bag's "Waiting: 48/24 troops", the chest note "Oath waits: keep 24 troops or fewer").
  - **Oath of the Wall**, **Blood Oath** and **Oath of the Vanguard** are fixed trades (`_oathStats`): the Wall
    ×1.4 HP and ×0.8 damage on every troop; Blood ×1.3 damage (not a heal) and every heal a troop gets in a wave ×0.5
    (`_oathHealK`, first in `_healTroop`); the Vanguard ×1.4 HP and damage on an up-close troop (`Stats.melee`) and
    ×0.75 damage on the rest.
  - **Oath of Kings** puts the Hero aura at ×1.25 (not ×1.15) and a Hero's own two attributes at ×2 (not ×3): more for
    everyone while a Hero lives, less for the Hero. With no Hero alive it does nothing. The Hero plate and the book's
    Hero line say "x2" (`heroBoostNow`), the aura line "Hero aura x1.25".
  - **Oath of Spells** (batch G-4's M piece) makes every skill come back ×0.8 as soon (`skillCd(base)`: a troop's
    #10 skill in `_tryTroopSkill`, the awakening skill's `_awakenReady`, its wave-start stagger and Impale's window, a
    Hero's `_heroSkillReady`), never under `cdFloor` 5 s and never longer than its own (Cleave 12.5 s → 10 s,
    Rampage 6 s → 5 s, Circle Slash's 4 s stays 4 s: with the #10 skills at 4-6 s the oath shortens them little); the
    awakening tooltip's cooldown says the shorter one. The trade: a
    troop's normal attack and a healer's holy light ×0.8 (`_oathBlowK`), never a skill's blow.
- **Once a run** (`Game.legendsFound`, saved): a Legenda taken from a chest (or given, `givePusaka`) is found and
  never on a card again, even once sold; one oath found keeps every other oath off the cards (`_offerable`), and a
  chest rolled before that shows a Serpihan in its place when it opens. Once every Legenda is found (or kept off:
  the 22 that are no oath and one oath), a Legenda roll steps down to an Epik, as before wave 20; with one still
  missing, it comes. An old save's `legendsFound` loads as it was (names it doesn't know are dropped, every owned
  Legenda added).
- **The words** (the item text's simple English, decisions-log 168; ui-hud.md "In-game text"): `relicEffect` ("No hit
  takes over 60% max HP"; "Oath: only 2 types, no type cap", "All troops: +50% HP and attack"; "Oath: up to 6 types
  count", "Each type alive: +5% HP and attack"), `pusakaGist` ("Max 60% HP a hit", "2
  types: +50%", "6 types: +5% each"), `pusakaTotals` (none for Dragon Crown, whose effect line says it all; "Now: all
  troops, +50%", "Now: 6 types, +30%"; none while Oath of One waits), `pusakaWhere` ("On: all troops ★1", or
  `oathWaiting` while Oath of One waits), and `oathLine` "Lasts the whole run" in place of `pusakaLine`. The chest's
  message when one is taken: "Oath of One: Oath for all troops!" (decisions-log 197), and under it `oathWaitingNote`
  "Oath waits: keep only 2 types". Batch G-4's six (`relicEffect`, `pusakaGist`): "Oath: up to 24 troops (not 36)" (`armyMaxBoard`; "(not 32)" until decisions-log 260),
  "All troops: +35% HP and attack" ("24 troops: +35%"); "Oath: all troops +40% HP", "-20% attack and heal" ("+40% HP,
  -20% attack"); "Oath: all troops +30% attack", "Heals on troops -50%" ("+30% attack, -50% heals"); "Oath: up-close
  troops +40% HP and attack", "Others -25% attack and heal" ("Up close +40%, others -25%"); "Oath: a Hero gives all
  troops +25% (not 15%)", "Heroes' own stats x2 (not x3)" ("Aura +25%, Heroes x2"); "Oath: skills come back 20%
  sooner", "Normal hits -20% damage" ("Skills 20% sooner, hits -20%"). `pusakaTotals` has a line for the moving oaths
  only (One, Alliance, the Few: "Now: all troops, +35%"), none while one waits. Dragon Crown's build name
  epithet is "Crowned" ("Crowned Templar"); the oaths name no type. Their icons are the pack's ("The icons":
  `relic_dragonCrown` a gold horned helm, `relic_oathOfOne` a gold padlock, `relic_alliance` a gold chain; batch G-4's
  six a padlock each from the Artifact atlas, `artifactIcon('<name>')`, cells 63 to 68: the Few green, the Wall steel
  grey, Blood red, the Vanguard bronze, Kings ice blue, Spells violet).
- **Not counted**: the oaths have no tally of their own (their stats are in every troop's); the wave record lists an
  owned oath with `type` null (telemetry.md).

## Peti Bos: the boss's chest (P3, decisions-log 152)

The owner, 2026-10-01: "mungkin unsur rougelikenya bisa dari item artefak yang ada sekarang". After every won boss
wave a chest offers three Pusaka cards; one is taken. On screen it is the "Boss Chest" ("Missed Chest 1/3" for an old
save's catch-up one), its cards' rarities Rare, Epic and Legendary (`rarityNames`, from `Words`; decisions-log 197). The rules are `lib/draft.dart` (a part of game.dart, `extension
Draft on Game`), the popup `lib/chest_popup.dart` (ui-hud.md "Boss Chest"). Every number the owner may tune is one
constant there.

- **The switch:** `Game.offers`, off in a plain `Game()` (every test and probe as before) and on for every game the
  board starts or loads (`boardRules()`). With it on, the Shop's Pusaka shelf is closed (`artefactShelf` false,
  `shelfOpen`; owner decision 4a, which reverses decisions-log 99) and the boss's small relic went (Drops, above; every
  relic since the Towns).
- **When:** a won wave with `wave % bossEvery == 0` brings one (`_bossChest`, in `tick`'s win path right after
  `_crownHero`, so the auto-save holds its rolled cards and a reload shows the same). Never on a lost wave. It waits in
  `Game.chests` (`chest` the next) until dealt with, between waves only (`whyNotChest`: `chestRefusals` over
  "Game over", midWave "Only between waves", none "No chest"; `full` "Too many chests: open one", the red hint while
  three wait).
- **The cards:** `draftCards` 3, all different, rolled on their own dice, `Game.draft` (injectable like `loot`,
  decision 112). Each rolls a rarity by `chestOddsAt` of the chest's own wave (below), then a card of it; a rarity
  with none left steps down, then up (`_stepped`). A Legenda comes only from wave `legendFrom` 20, each once a run and
  at most one oath (`legendsFound`, "Legenda" above); before it, or with every Legenda found, a Legenda roll is an Epik. A
  card is a Pusaka under its top star (`_offerable`, `maxStars`: ★3, a Legenda ★1): new (★1, bound where `pusakaPrefs`
  says, `cardType`; with no free living type, into the Gudang; an oath the whole army) or one more star on one owned
  (`cardStars`).
  - **The odds rise a chest at a time** (decisions-log 185): the chest of wave w counts n = max(0, w ÷ `bossEvery`
    − 1) boss chests before it (w5 0, w10 1, w100 19), and each moves the odds `chestOddsStep` 0.0025 of Legenda
    further from `chestOdds` (Langka 0.55, Epik 0.37, Legenda 0.08) toward `chestOddsCap` (Langka 0.40, Epik 0.35,
    Legenda 0.25), Langka and Epik giving it up in the cap's proportion (15 to 2): Legenda 0.08 + 0.0025·n, Langka
    0.55 − (0.15/68)·n, Epik 0.37 − (0.02/68)·n. The cap is reached at n 68 (wave 345) and kept; the number of steps
    is (cap − first Legenda) ÷ `chestOddsStep`, so a new cap or step is one constant. The odds are the chest's own
    wave's (`Chest.wave`): a reroll of a chest that waited (a save's) keeps them, and a catch-up chest (an old save's, below) has its load
    wave's. Still one `draft` draw a card: only the thresholds move, and a seed draws as many values as before. Before
    wave 20 a Legenda roll is still an Epik, so there Epik or better comes at 0.45 + (0.15/68)·n.

    | Chest's wave | n | Langka | Epik | Legenda |
    |---|---|---|---|---|
    | 5 | 0 | 0.55 | 0.37 | 0.08 |
    | 10 | 1 | 0.5478 | 0.3697 | 0.0825 |
    | 20 | 3 | 0.5434 | 0.3691 | 0.0875 |
    | 50 | 9 | 0.5301 | 0.3674 | 0.1025 |
    | 100 | 19 | 0.5081 | 0.3644 | 0.1275 |
    | 200 | 39 | 0.464 | 0.3585 | 0.1775 |
    | 300 | 59 | 0.4199 | 0.3526 | 0.2275 |
    | ≥ 345 | 68 | 0.40 | 0.35 | 0.25 |
  - **The run's first chest** (`chestsGiven` 0) is three different Epik.
  - **Pity:** `draftDry` counts the chests in a row with no Epik or better (each chest's first roll; a reroll doesn't
    count); the `legendPity` 6th gets one in its first card.
  - **Serpihan:** with fewer than three cards left, a gap is a Serpihan (a null card): taken, it is kept
    (`Game.serpihan`) and pays the next Kocok ulang. A card whose Pusaka reached ★3 since its chest was rolled (another
    chest's) turns into one when the chest opens (`openChest`).
- **What the player does** (`takeCard`, `rerollChest`, `skipChest`; each refused does nothing but `Sfx.error`):
  - **Ambil**, on screen "Take" (`takeCard(i)`): a new Pusaka is owned at ★1 and bound by the default rule, a binding that doesn't
    count (`binds` 0: its first move is still free) with a `PusakaBound` at cost 0; an owned one gets a star where it
    is; the type's troops are refit and burst in gold, `Sfx.clear`. A Legenda is found (`legendsFound`); an oath works
    at once on the whole army (every troop's gold burst). It emits `OfferPicked`. The card's Bayangan, when it hides
    one, goes to the enemy ("Bayangan" below).
  - **Kocok ulang**, on screen "Reroll" (`rerollChest`): three new cards for `rerollCost`: `rerollPrice(wave)`
    (600 × 1.05^(wave−1), rounded to 100: 700 on wave 5, 2.5k on 30, 38k on 86) × `rerollRise` 2 for each reroll of that chest (back to the
    first price for the next chest); free, using one up, with a Serpihan (a "Shard") held. Refused "Not enough gold"
    when short (`chestRefusals.gold`), and the greyed button reads "Need 38k gold". It emits
    `OfferRerolled` and the new `OfferShown`.
  - **Lewati**, on screen "Skip" (`skipChest`): no card, `skipGold` = `skipShare` 1.0 × one reroll price in gold. An `OfferPicked` with
    `skipped`. It gives no Bayangan: from wave 20 the next wave owes the skip buff instead ("Bayangan" below).
  - No **Nanti** ("Later") since decisions-log 281 (the owner: "remove later button dari opsi chest boss jadi user wajib
    ambil"): a chest can't be put off; it is taken or skipped before the next wave starts (ui-hud.md "Boss Chest"). It
    was UI only, and so was its cap (`offerQueueMax` 2 waiting, `chestMayWait`), both gone; a save holds no "put off"
    mark, so a save with chests waiting opens them one after another.
- **An old save** (one without the `chests` key, `_loadChests`): min(`catchUpMax` 3, boss waves won ÷ `catchUpEvery`
  3) catch-up chests ("Missed Chest 1/3", `ChestKind.catchUp`), the first three Epik when the run had none. They are
  rolled when opened, not in `fromJson` (decision 112: loading draws no dice); the UI saves right after. The owner's
  wave-86 save gets 3.
- **The probes** (instance members, so `probe_knobs.dart` reaches them through `dynamic`): `offers`, `draftPolicy`
  (null: the player chooses; 'rarity': the highest rarity, then the card whose type has the most troops alive, then the
  first; 'first': the first; anything else throws), `giveChests(n)` (n boss chests of this wave, rolled now) and
  `pickChests()` (every waiting chest taken by the policy). With a policy a boss chest is taken at the win, and chests
  still waiting at the next `startWave`.
- **Telemetry** (telemetry.md): `OfferShown` (every roll), `OfferRerolled`, `OfferPicked` (also in the battle log, on
  its Pusaka chip), and the wave record's `gold.chestSpent` / `gold.chestEarned`.

## Bayangan: the enemy's hidden buffs (decisions-log 180)

The owner, 2026-10-02: every Pusaka card from a Peti Bos is a double-edged sword. Taking it also gives the enemy a
hidden buff, a Bayangan, revealed on the take. It answers a late game that was far too easy (waves 87-102: no troop
fell on 16 waves). The rules are `lib/omen.dart` (a part of game.dart, `extension Omens on Game`); every number is one
constant there.

- **On in every build** (decisions-log 319; the owner, 2026-10-12, asked to ship, park or cut them: "Nyalakan"):
  `omensOn` is `bool.fromEnvironment('OMENS', defaultValue: true)`. Their UI (decisions-log 191) shows the cards' marks,
  the reveal, the chips under the wave meter and their tooltip, the boss bar's Barrier and Escort (ui-hud.md "Shadows"),
  and the guide's card K25 explains them over the first chest that hides one. Off (`--dart-define=OMENS=false`, or a
  test setting `omensOn = false`), no Bayangan die is drawn, no save key is written and no event or telemetry field is
  sent, so a save loads and plays as it did before them: the off path the tests keep checking.
- **What they do** (decisions-log 188): each kind acts on the field through its hook, units-and-combat.md "Bayangan on
  the field". `omenE(kind)`, the effective level the hooks read (through `omenK`), is 0 while off, so off no hook acts.
- **The kinds** (`OmenKind`): today's seven, then the data batches' kinds (batch L-1B, decisions-log 204: the first ten
  Langka; L-2B, 206: the next ten; L-3B, 208: six more; L-3, 209: Sap, the Langka pool's troop debuff; E-1B, 210: the
  first ten Epik; E-2B, 212: ten more Epik; E-3B, 219: seven more Epik; E-3, 223: Bat Venom, the Epik pool's troop
  debuff; G-1B, 226: the first ten Legenda; G-2B, 236, and G-3B, 239: seventeen more; G-3, 243: Blight, the Legenda
  pool's troop debuff), each with its name, an icon from a sheet already in `assets/images/` (Guard none: its wave's boss-bar
  portrait; each (sheet, cell, tint) its own), `k` (what one effective level E does and the most it does), `tiers` (the
  chest rarities whose cards may hide it: a set; today's seven sat in all three until their tiers' cut-over batches, a
  data batch's kind in its own tier's alone; the Langka cut-over (batch L-3, decisions-log 209) took Armor, Mend,
  Barrier and Escort out of Langka's, the Epik one (batch E-3, decisions-log 223) Haste, Spikes, Wound, Barrier and
  Escort out of Epik's, and the Legenda one (batch G-3, decisions-log 243), the last, Armor, Mend, Haste, Spikes and
  Wound out of Legenda's: since then every kind sits in one, the owner's answer (`omenOneTier`, which the tests hold):
  Armor and Mend in Epik's (`_epik`), Haste, Spikes and Wound in Langka's (`_langka`), Barrier and Escort in Legenda's
  (`_legenda`)) and `live` (off: in no pool). A pool's order
  is the enum's, each batch's kinds in their place in the design's pool order: the Langka pool is Haste, Spikes and
  Wound, then Brace, Stubborn, Sunder, Shieldbreak, Unshaken, Quick Spells, Thrift, Lingering, Avenge, Feed, Grudge, Bear
  Hide, Eager, Healer Hunt, Sap, Hard Shell, Spell Tax, Off Beat, Drag, Scar, Deflect, Gloat, Rekindle, Pummel, Fade,
  Defiant and Straggler (30, the design's list); Epik's is Armor and Mend, then Prey, Dark Hymn, Bone Arrows, Arrow
  Ward, Second Skin, Bile Sacs, Blood Moon, Mark Ward, Herd Hunt, Last Rage, Parting Gift, Old Bones, Bat Venom, Grave
  Pact, Captain, Enrage, Heal Siphon, Hunker, Counterspell, Close Ranks, Wear Down, Blindside, Envy, Trickle, Toll, Zeal,
  Triumph and Muster (30, the design's list); Legenda's is Barrier and Escort, then Spell Ward, Scatter, Holy Ward, Cover,
  Hero Hunt, Thornproof, Blight, Renewal, Rust, Side Swing, Oathbane, Veterans, Last Gasp, Rider Rush, Hardy, Unbowed,
  Executioner, Spite, Deathless, Blunt, Adapt, Warlord, Spree, Vultures, Mana Burn, Dusk, Backlash and Horde (30, the
  design's list). A save with levels of a kind a cut-over took out of a pool (Armor, Mend, Barrier and Escort out of
  Langka's; Haste, Spikes, Wound, Barrier and Escort out of Epik's; Armor, Mend, Haste, Spikes and Wound out of
  Legenda's) keeps them and they act as before: a cut-over moves only which cards may hide them, and a card's levels that
  overflow go only to its own pool's kinds. A Pusaka's
  catalog row names the kind that answers it, its `counter` (Dawn Star's `healerCounter` on a healer type), so
  `OmenKind.answers` lists the Pusaka each kind answers.

  The player reads the kinds by their titles (`OmenKind.title`, the English glossary's): Thorns, Shield and Guard
  show as Spikes, Barrier and Escort, as the small relics Thorns and Guard and the item Shield keep those words;
  saves and telemetry keep the enum names.

  | Kind | `k` per E, most | What it does | Answers |
  |---|---|---|---|
  | Armor | 0.05, 0.4 | troop damage to enemies ×(1 − 0.05E) | Void Eye, Dawn Star (not on a healer) |
  | Haste | 0.05, 0.4 | an enemy's attack pause ÷(1 + 0.05E), the floors kept | Iron Banner |
  | Mend | 0.003, 0.024 | enemies heal 0.003E of their max HP a second; not the boss or the mini boss | God's Thunder, Null Stone |
  | Thorns (shown as Spikes) | 0.03, 0.24 | a melee troop takes 0.03E of the damage it deals back, at most 5% of its max HP a blow | War Drum, Twin Fury, Riposte |
  | Wound | 0.06, 0.5 | troop heals in a wave ×(1 − 0.06E); not the Grail, nor the heals between waves | Blood Fang, Mourning Bell, Living Moss |
  | Shield (shown as Barrier) | 0.05, 0.4 | the boss and the mini boss come on with a shield of 0.05E of their max HP | Dragon Crown |
  | Guard (shown as Escort) | 0.5, 2 | each boss and mini boss brings ⌈0.5 L⌉ more high elites (by level L, not E) | Oath of One, Alliance, Oath of the Few |
  | Brace (Langka) | 0.05, 0.3 | a troop's blow on a monster over 90% of its max HP ×(1 − 0.05E); in the taken floor | First Cut, Shatter Shard |
  | Stubborn (Langka) | 0.06, 0.3 | a troop's blow on a monster under 30% of its max HP ×(1 − 0.06E); in the taken floor | Finishing Blade |
  | Sunder (Langka, troop-side) | 0.08, 0.5 | every cut a troop takes less by (the small relic Guard's, a skill's guard, a Pusaka's `cut`) is ×(1 − 0.08E) | Steady Stance, Turtle Shell |
  | Unshaken (Langka) | 0.1, 0.5 | a troop's slow, stun, pin, taunt, weaken or hex on a monster lasts ×(1 − 0.1E), at least 0.3 s | Dulling Mail, Snare Cord |
  | Quick Spells (Langka) | 0.05, 0.3 | a high elite's skill cooldown ×(1 − 0.05E) | Salt Charm |
  | Thrift (Langka) | 0.04, 0.3 | a monster's kill gold (and a plunderer's extra) ×(1 − 0.04E), rounded | Looter's Pouch |
  | Bear Hide (Langka) | 0.06, 0.4 | a troop's blow on a werebear ×(1 − 0.06E); in the taken floor | faces only |
  | Hard Shell (Langka) | 0.05, 0.3 | a troop's blow on a monster with a shield (an absorb, a shot ward, a Barrier, a guard) ×(1 − 0.05E); in the taken floor | Shell Cracker |
  | Deflect (Langka) | a count | each monster cancels every 12th / 8th / 6th / 5th normal troop attack on it (by L, not E) | Titan Bane |
  | Defiant (Langka) | 0.06, 0.25 | a monster under a troop's taunt deals that troop ×(1 + 0.06E), the boss and mini boss half; in the dealt cap | Challenge Letter |
  | Shieldbreak (Langka) | 0.12, 0.6 | a monster's blow does ×(1 + 0.12E) to a troop's ward, absorb and Mana Shield; the rest of the blow lands as it was | Bone Buckler |
  | Lingering (Langka) | 0.1, 0.5 | a buff a monster gives a monster (the kinds Spellbreaker strips) lasts ×(1 + 0.1E) | Spell Cutter |
  | Avenge (Langka) | 0.04, 0.2 | a monster that dies gives the monsters within a tile an omen might of 1 + 0.04E for 3 s; in the dealt cap | Momentum |
  | Feed (Langka) | 0.02, 0.15 | a monster heals 0.02E of the HP its blow took off a troop; not the boss or the mini boss | faces only |
  | Eager (Langka) | 0.05, 0.3 | a monster the wave brings (not a raised one) comes on with an omen might of 1 + 0.05E for 5 s; in the dealt cap | faces only |
  | Healer Hunt (Langka) | 0.04, 0.25 | a monster's blow on a priest ×(1 + 0.04E); in the dealt cap | faces only |
  | Spell Tax (Langka, troop-side) | 0.05, 0.3 | every MP price of a troop's skill ×(1 + 0.05E), never past its max MP; the tooltips show it | Pain Crystal, Mana Leech |
  | Off Beat (Langka, troop-side) | a count | a Rare or Epic Artifact's every-few-hits Fx needs 1 / 1 / 2 / 2 more hits (by L); not Twin Fury's | Bleeding Edge |
  | Fade (Langka, troop-side) | 0.02, 0.08 | a troop's ward and absorb lose 0.02E of what is left each second | Watch Shield |
  | Straggler (Langka) | 0.06, 0.3 | a monster with no other within 2 tiles deals ×(1 + 0.06E); not the boss or a mini boss; in the dealt cap | faces only |
  | Grudge (Langka) | 0.04, 0.25 | a monster's blow on a troop of last won wave's top killer (the type whose troops killed the most; a tie to the first type; none after a wave with no troop kill) ×(1 + 0.04E); in the dealt cap | Wolf Feast |
  | Drag (Langka, troop-side) | 0.1, 0.5 | a Rare or Epic Artifact's Fx on its own cooldown waits ×(1 + 0.1E) before its next; not a Legendary one's | Pure Water |
  | Scar (Langka, troop-side) | 0.05, 0.15 | in a wave a troop's heals stop at 1 − 0.05E of its max HP, never lowering it; healers pass over a troop at that ceiling | Full Cup |
  | Gloat (Langka) | 0.05, 0.15 | a monster that kills a troop heals 0.05E of its max HP; not the boss or a mini boss | faces only |
  | Rekindle (Langka) | 0.03, 0.15 | a high elite heals 0.03E of its max HP each time its skill lands | faces only |
  | Pummel (Langka) | 0.1, 0.3 | every 3rd normal attack of a monster does ×(1 + 0.1E); not the boss or a mini boss; in the dealt cap | Hidden Flask |
  | Sap (Langka, the troop debuff) | 0.03, 0.2 | every 4th normal attack of a monster that lands (the boss's too; Pummel's count) makes the troop it hits deal ×(1 − 0.03E) for 2 s: a weaken, a bad effect a cleanse ends | faces only (Salt Charm and Pure Water end it) |
  | Dark Hymn (Epik) | 0.08, 0.4 | a monster healer's heal (its damage, which Mass Mend reads too) ×(1 + 0.08E); a stat kind | Healer Bane |
  | Bone Arrows (Epik) | 0.08, 0.4 | a skeleton archer's damage ×(1 + 0.08E), its range kept; a stat kind | Arrow Catcher |
  | Arrow Ward (Epik) | 0.08, 0.5 | a monster that comes on (a raised one too) takes ×(1 − 0.08E) from the troops that shoot for 6 s: an omen shot ward | Hawk Feather |
  | Enrage (Epik) | 0.06, 0.3 | a monster's blow ×(1 + 0.06E) once 10 s have passed since its first; not the boss or a mini boss; in the dealt cap | Stone Coat |
  | Hunker (Epik) | 0.05, 0.2 | a troop's blow on a monster under a slow, a hold or a stun ×(1 − 0.05E); in the taken floor | Bully's Club |
  | Counterspell (Epik) | 0.03, 0.12 | a troop's skill gives each high elite within 2.5 tiles an omen absorb of 0.03E of its max HP for 3 s, each once per 6 s | Moonwell, Aegis Seal, Mana Hymn, Saint's Tear |
  | Wear Down (Epik) | 0.0015, 0.01 | a monster's normal attack also deals 0.0015E of the troop's max HP, at most half the blow, before its defence; in the dealt cap | Dragon Heart, Hero's Cloak |
  | Envy (Epik) | 0.04, 0.25 | a monster's blow on a troop with a might over 1 or a haste under 1 ×(1 + 0.04E); in the dealt cap | Rune Gauntlet, Brave Song |
  | Zeal (Epik) | 0.05, 0.3 | a monster a monster healer's heal or Mass Mend gave HP gets an omen might of 1 + 0.05E for 3 s; in the dealt cap | Witherroot |
  | Muster (Epik) | 0.05, 0.3 | a boss or mini boss at 60% HP, once, gives the monsters within 3 tiles an omen might of 1 + 0.05E for 5 s; in the dealt cap | Unity Ring |
  | Second Skin (Epik) | 0.03, 0.2 | a monster below a mini boss at half HP, once, gets an omen absorb of 0.03E of its max HP for 6 s | faces only (Null Stone strips it) |
  | Bile Sacs (Epik) | 0.02, 0.12 | a slime that dies hurts each troop within a tile for 0.02E of its max HP, from no one, through its defence; a troop once per 0.5 s | Anchor |
  | Blood Moon (Epik) | 0.05, 0.3 | a werewolf or werebear that comes on heals 0.05E of what it deals for 8 s: an omen lifesteal | faces only |
  | Mark Ward (Epik) | 0.1, 0.5 | a mark on a monster (Hunter's Mark's, Void Eye's) lasts ×(1 − 0.1E), at least 0.3 s | Ember Brand |
  | Last Rage (Epik) | 0.1, 0.4 | a monster below a mini boss at 35% HP, once, gets an omen might of 1 + 0.1E for 4 s; in the dealt cap | faces only (Null Stone strips it) |
  | Parting Gift (Epik) | 0.03, 0.15 | a monster that dies heals each hurt monster below a mini boss within 1.5 tiles 0.03E of its max HP; each once a second | faces only |
  | Captain (Epik) | 0.04, 0.25 | a troop's blow on a monster with a living high elite (not itself) within 1.5 tiles ×(1 − 0.04E); in the taken floor | faces only |
  | Close Ranks (Epik) | 0.04, 0.15 | a monster that dies guards each monster within a tile, 0.04E less taken for 1.5 s, before the kill Fx; none inside a leap or burst; in the taken floor | Funeral Pyre |
  | Blindside (Epik) | 0.03, 0.15 | a monster's blow on a troop that struck another monster less than 1.5 s ago ×(1 + 0.03E); in the dealt cap | Warden's Horn |
  | Triumph (Epik) | 0.05, 0.2 | a troop that falls hastens each monster below a mini boss within 2 tiles: an omen haste of 1 / (1 + 0.05E) for 3 s | Fallen Flag |
  | Prey (Epik) | 0.06, 0.4 | a monster's blow on a troop under 30% of its max HP (before the blow) ×(1 + 0.06E); in the dealt cap | the Grail, Hearth, Mercy Lily |
  | Herd Hunt (Epik) | 0.04, 0.3 | a monster's blow on a troop whose type has 10 or more troops alive ×(1 + 0.04E); in the dealt cap | Heartbeat |
  | Old Bones (Epik) | 0.08, 0.4 | a skeleton kind (any rank, a raised one too) comes on with ×(1 + 0.08E) HP; a stat kind | faces only |
  | Bat Venom (Epik, the troop debuff) | 0.01, 0.04 | a bat's normal attack that lands makes the troop it hits bleed 0.01E of its max HP a second for 3 s (3 ticks), from no one, through its defence: a bleed, a bad effect a cleanse ends; a bite on a troop it holds runs it 3 s from now, its next tick kept; a stronger bleed stays | faces only (Saint's Tear ends it) |
  | Grave Pact (Epik) | 0.05, 0.3 | a troop's blow on a raised monster (a necromancer's minion, Split's, Swarm's, Grave Call's) while the one that raised it lives ×(1 − 0.05E); in the taken floor | faces only |
  | Heal Siphon (Epik) | 0.05, 0.3 | a troop's heal in a wave owes 0.05E of the HP it gave (after Wound and Scar), paid once a second to the nearest monster below a mini boss within 3 tiles of the troop; none in reach: dropped | Dawn Star on a healer, Halo Lantern, Bright Spring |
  | Trickle (Epik, troop-side) | 0.4 s, 2 s | a healer's heal, Healing Prayer, Sacrifice or a Pusaka's heal in a wave comes in over 0.4E s (seconds, not a share), each heal on its own clock; the rescues, regen, the heal statuses, a fang's, the after-wave heal and the Grail's save land at once | faces only |
  | Toll (Epik, troop-side) | 0.01, 0.04 | a troop that kills a monster loses 0.01E of its max HP through its defence, as a blow from no one; never below 25% of it; once per 2 s a troop | faces only |
  | Spell Ward (Legenda) | 0.06, 0.36 | a skill's blow on a monster (a troop's #10 skill, awakening skill, Hero skill, Holy Nova, Judgement), not a monster's, ×(1 − 0.06E); in the taken floor | Oath of Spells |
  | Scatter (Legenda) | 0.08, 0.4 | a troop's extra hit on a monster (a splash past its target, a Pusaka's leap or burst) ×(1 − 0.08E); in the taken floor | Wide Blows |
  | Holy Ward (Legenda) | 0.06, 0.4 | a troop healer's smite (a Priest's holy light) on a skeleton kind, any rank, ×(1 − 0.06E); in the taken floor | Wrath Psalm |
  | Cover (Legenda) | 0.05, 0.3 | a troop's blow on the boss or a mini boss while another living monster stands within 1.5 tiles of it ×(1 − 0.05E); in the taken floor | faces only (clear its neighbours first) |
  | Hero Hunt (Legenda) | 0.08, 0.5 | a monster's blow on a Hero ×(1 + 0.08E); in the dealt cap | Oath of Kings |
  | Thornproof (Legenda) | 0.12, 0.6 | a troop's hit back on a monster (worn thorns, a reflect, Parry's answer, Riposte's) ×(1 − 0.12E); in the taken floor, which holds its most at 0.5 | Mirror Shield |
  | Blight (Legenda, the troop debuff) | 0.75 s, 3 s | the boss's or a mini boss's normal or skill blow that lands on a troop stops its heals in a wave for 0.75E s (seconds): a noHeal a monster put on it, a bad effect a cleanse ends; no healer picks it, no heal lands on it, its body drawn olive; never the Grail's save nor the heals between waves | Vampire Kiss (Salt Charm, Pure Water and Saint's Tear end it) |
  | Renewal (Legenda) | 0.04, 0.25 | a monster that a troop's strip takes a good effect or its guard off gets a shield of 0.04E of its max HP, once a life: the Barrier's soak, which no strip takes | faces only |
  | Rust (Legenda, troop-side) | 0.1, 0.6 | a troop's worn small relics work ×(1 − 0.1E): fang's heal, thorns' hit back, guard's cut, fury's extra | Relic Altar (its relics too) |
  | Side Swing (Legenda) | 0.06, 0.3 | a melee monster's normal attack that lands on a troop also hits the nearest other troop within 1 tile of it for 0.06E of the blow, from no one, through its defence | Guardian Chain, Phalanx, Soul Shelter |
  | Oathbane (Legenda) | 0.06, 0.3 | while an oath is held (any of the eight), the boss and a mini boss (by rank, a raised one too) come on with ×(1 + 0.06E) HP; a stat kind | Blood Oath |
  | Veterans (Legenda) | 0.03, 0.15 | on the same draw, 0.03E more of a wave's monsters come silver (the elite threshold raised); never more gold | Martyr's Flame |
  | Last Gasp (Legenda) | 0.03, 0.15 | the boss or a mini boss at 40% HP for the first time heals 0.03E of its max HP, once, through the monster funnel (none under noHeal) | faces only (Grave Seal's noHeal stops it) |
  | Rider Rush (Legenda) | 0.12, 0.5 | an orc rider's first normal or skill blow on a troop ×(1 + 0.12E), once a monster; in the dealt cap | Oath of the Vanguard |
  | Hardy (Legenda) | 0.05, 0.3 | an elite and a high elite (a raised one too) come on with ×(1 + 0.05E) HP; a stat kind | Vow of Silence, Grave Seal |
  | Unbowed (Legenda) | a count | each monster shrugs off the first 1 / 1 / 2 / 2 pins, stuns or Slime Hexes a troop puts on it (by L, not E) | Ice Grip, Hex Blade |
  | Executioner (Legenda, troop-side) | 0.05, 0.2 | a monster's blow on a troop under 0.05E of its max HP (before the blow) skips its shields, blocks and cuts; its defence and a cap-0 window stay | Ghost Step |
  | Spite (Legenda) | 0.06, 0.3 | a monster's blow on a troop while Ember Brand's or Vengeance Mark's mark is on it ×(1 + 0.06E); in the dealt cap | Vengeance Mark |
  | Deathless (Legenda) | 0.2 s, 1.2 s | a silver or gold monster a blow would kill is left at 1 HP and takes no blow for 0.2E s (seconds), once a life; no gold, kill or drop until its real death | Glory Seeker |
  | Blunt (Legenda) | 0.06, 0.3 | on a silver, gold or boss monster, the part of a troop's blow past 20% of its max HP ×(1 − 0.06E); in the taken floor | Lone Wolf Pelt |
  | Adapt (Legenda) | 0.02, 0.1 a step | a troop's normal or skill blow on a monster from the same troop type as the last one on it ×(1 − 0.02E × the run): +1 a blow, at most 3; another type's sets it to 0; in the taken floor | faces only |
  | Warlord (Legenda) | 0.04, 0.25 | a monster's blow on a troop while the wave's boss or a mini boss lives ×(1 + 0.04E); not the boss's or a mini boss's own; in the dealt cap | faces only |
  | Spree (Legenda) | 0.03, 0.1 a kill | a silver or gold monster that kills a troop deals ×(1 + 0.03E × its kills) to troops for its life, at most 3 kills; in the dealt cap | Phoenix Plume |
  | Vultures (Legenda) | ranks | the ranks by L (L1-2 the high elites, L3-4 the elites too) go for the troop they reach with the lowest HP share (a shooter: within 1.5 tiles of its target), kept until it falls, leaves the reach or the next attack | Rage Totem |
  | Mana Burn (Legenda, troop-side) | 0.005, 0.03 | a monster's normal or skill blow that lands on a troop takes 0.005E of its max MP, at most once every 0.5 s a troop | faces only |
  | Dusk (Legenda) | 0.04, 0.3 | from 30 s after the wave's last crowd monster came on (not the boss, a mini boss, an escort or a Guard's), a monster's blow on a troop ×(1 + 0.04E); not the boss's or a mini boss's own; in the dealt cap | Oath of the Wall |
  | Backlash (Legenda) | 0.04, 0.25 | a troop's skill gives each monster within 2 tiles of it an omen might of 1 + 0.04E for 3 s, a monster at most once a second; in the dealt cap | Mana Font |
  | Horde (Legenda) | 0.015, 0.06 a step | a troop's blow on any monster ×(1 − 0.015E × steps), a step every 10 monsters alive, at most 3; in the taken floor | Champion's Mantle |

  Since the Legenda cut-over (batch G-3) every kind sits in one tier: Armor and Mend Epik's, Haste, Spikes and Wound
  Langka's, Barrier and Escort Legenda's. The ninety's hooks:
  units-and-combat.md "Bayangan on the field". "None yet" names the planned Pusaka whose rows will
  answer it; until they are built a face of it comes from the pool's even share alone. Batch L-1P's ten Langka
  (decisions-log 205) answer all of L-1B's but Quick Spells, Thrift and Bear Hide; L-2P's (decisions-log 207) answer
  Thrift and L-2B's but Feed, Eager, Healer Hunt and Straggler (faces only), and Brace and Spikes once more. L-3's
  (decisions-log 209) answer Quick Spells, L-3B's Grudge, Drag, Scar and Pummel, and Wound once more; Gloat and Rekindle
  are faces only, and Sap, the pool's one troop debuff (`OmenKind.debuff`, lasting at most `omenDebuffMax` 3 s), is
  never a counter (the tilt never aims a debuff): Salt Charm and Pure Water end it. Batch E-1P's ten Epik
  (decisions-log 211) answer batch E-1B's ten, one each (Dragon Heart answers Wear Down too since the Epik cut-over;
  Counterspell and Envy got more answers in batch E-3P). Batch E-2B's ten (decisions-log 212) are
  answered by batch E-2P's Pusaka (decisions-log 214): Ember Brand, Funeral Pyre, Warden's Horn, Fallen Flag and Anchor
  answer Mark Ward, Close Ranks, Blindside, Triumph and Bile Sacs; Second Skin, Blood Moon, Last Rage, Parting Gift and
  Captain are faces only. Null Stone answers Mend beside God's Thunder, and Aegis Seal Counterspell beside Moonwell.
  Batch E-3B's seven (decisions-log 219) are answered since the Epik cut-over (batch E-3, decisions-log 223): the
  Grail's counter became Prey, Dragon Heart's Wear Down and Dawn Star's healer counter Heal Siphon, and batch E-3P's
  Hearth and Mercy Lily answer Prey, Heartbeat Herd Hunt, and Halo Lantern and Bright Spring Heal Siphon (Mana Hymn and
  Saint's Tear answer Counterspell, Brave Song Envy); Old Bones, Grave Pact, Trickle and Toll are faces only. Bat Venom,
  the Epik pool's troop debuff (at most `omenDebuffMax` 3 s), is never a counter: Saint's Tear ends it. Batch G-1B's
  ten (decisions-log 226) are answered by batch G-1P's Legenda (decisions-log 231; the names in the table), and later
  batches answer Unbowed and Hardy once more. Batch G-1P's needs: Wide Blows' splash and Martyr's Flame's burst are an
  extra hit (Scatter), Mirror Shield's reflect a hit back (Thornproof), Vengeance Mark's `Status.pusakaMark` a mark and
  Spite's mark, Ice Grip's hold a hold (Unbowed); a Legenda's every-Nth is no `everyFx` (Off Beat never reaches it), and
  a type under Vow of Silence counts none of its skills (`mpSkill`, its #10, awakening and Hero skill's needs). Batch
  G-2B's ten (decisions-log 236) are answered by batch G-2's Legenda (decisions-log 238): Guardian Chain, Phalanx and
  Soul Shelter answer Side Swing, Glory Seeker Deathless, Phoenix Plume Spree, Rage Totem Vultures and Mana Font
  Backlash, and Hex Blade answers Unbowed beside Ice Grip; Cover, Renewal, Adapt, Warlord and Mana Burn are faces
  only. Batch G-2's needs: Hex Blade's hex is a hex source (`hex`, Unbowed's), Glory Seeker's kill might a might
  (`mightOrHaste`, Envy's). Of batch G-3B's seven (decisions-log 239), batch G-3's Wrath Psalm answers Holy Ward
  (decisions-log 243) and batch G-4's oaths answer the rest (decisions-log 247: Oath of Spells Spell Ward, Oath of
  Kings Hero Hunt, Blood Oath Oathbane, Oath of the Vanguard Rider Rush, Oath of the Wall Dusk, and Oath of the Few
  Guard beside Oath of One and Alliance); Last Gasp is faces only (Grave Seal's seal stops
  its heal). Batch G-3's Grave Seal answers Hardy beside Vow of Silence, and Blight, the Legenda pool's troop debuff (at
  most `omenDebuffMax` 3 s), unlike Sap and Bat Venom is a counter, Vampire Kiss's (catalog-bayangan-v2 §4: the heal
  penalty on the Artifact that heals); a cleanse ends it. Batch G-3's needs: Vampire Kiss's heal is a heal source
  (`heal`); Wrath Psalm's smite is no extra hit (Scatter's); Blight needs nothing.

- **The faces:** from wave `omenFrom` 20 each card of a chest hides one. `_roll` draws them after the cards, one
  `nextDouble()` a card on their own dice, `Game.omenDice`, always 3 a roll (a Serpihan, a chest before wave 20 and every
  roll while all are full draw theirs too, and show none), so the cards are the same with the Bayangan or without, and
  `draft`, `rng`, `slots` and `loot` are never touched. A draw under `omenTilt` 2/9 gives the card's counter (on the type
  `cardType` binds it to); the rest picks a kind of the card's pool (`omenPool(rarity)`, the live kinds of that tier)
  evenly. So in a pool of n kinds a card answers itself 2/9 + 7/(9n) of the time and any other kind is 7/(9n): with
  today's seven alone 1 in 3 and 1 in 9, in the Langka pool's 30 and the Epik pool's 30 about 0.25 and 0.026. A face comes only from the kinds that can
  act on the army (the v2 rules, decisions-log 192): see "The acting faces" below. The faces are saved on the chest beside
  its cards (`chests[].omens`). Kocok ulang draws new faces with the new cards. A card `openChest` turns into a Serpihan
  loses its face; a chest saved before the Bayangan has none. `policyPick` never reads a face.
- **The take** (`takeCard`): the taken card's face gives the enemy `omenMarks` levels by its rarity, Langka 1, Epik 2,
  Legenda 3 (the owner's answer: the card shows them as red "!" marks, the kind stays secret). A kind holds at most
  `omenCap` 4: the levels past it overflow to the next kind of the card's pool, round to its start (`omenPlace`), and at
  most `omenKindsMax` 8 kinds are held at once, of them at most `omenTroopRulesMax` 4 troop-side ones
  (`OmenKind.troopSide`: a rule on the troops, not the monsters; today Wound, Sunder, Spell Tax, Off Beat, Fade, Drag, Scar, Trickle, Toll, Rust, Executioner and Mana Burn). A troop-side kind not held yet
  has room only while fewer than 4 are held; otherwise its levels overflow the same way, and the reveal names the kinds
  that got them. With no kind of the pool left with room (at most 8 kinds of 4 levels) the card gives none ("Monsters:
  full"). The other faces go
  unseen. The levels count from the next wave's start. A Serpihan, Lewati, Asah, Lebur, Bangkit, Tempa, a Hero or an item
  gives none. A Pusaka's Ukir star gives its counter levels the same way, with no face drawn.
- **The acting faces** (the v2 rules, decisions-log 192): each kind names what in the army it needs to act
  (`OmenKind.needs`, any one of them, `OmenNeed`; none: it always acts, as today's seven, eight of batch L-1B's ten and
  five of L-2B's do; Unshaken needs a troop slow, hold, stun, taunt, weaken or hex source, Defiant a taunt source,
  Shieldbreak and Fade a troop shield source, Healer Hunt a healer type, Spell Tax a troop skill that costs MP, Off Beat
  a Rare or Epic every-few-hits Fx; of E-1B's ten, Hunker a troop slow, hold or stun source, Counterspell a troop skill
  that costs MP, Envy a might or haste source on troops; of E-2B's ten, Mark Ward a mark source, a Hero's Hunter's Mark
  or Void Eye bound; of E-3B's seven, Heal Siphon and Trickle a heal source, a healer type, a troop's regen or a bound
  heal or regen Fx; of G-1B's ten, Scatter an extra-hit source (a splash, a bound leap or burst), Thornproof a hit-back
  source (worn thorns, a Hero's Parry or Iron Skin, Riposte), Rust a worn small relic, Unbowed a troop hold, stun or hex
  source, Spite Ember Brand bound; of G-2B's ten, Mana Burn and Backlash a troop skill that costs MP; of G-3B's seven,
  Spell Ward a troop skill that costs MP, Holy Ward a healer type, Hero Hunt a Hero, Oathbane an oath held). At each
  roll `_faces` reads what the army meets once (`omenMet`) and draws each card's face from the kinds of its pool that
  can act (`omenCanAct`), on the same single draw: one die a card, as before, and the same faces when every kind acts. The
  tilt's counter is exempt (the card itself is its condition). With none acting the draw spreads over the whole pool.
  `omenActFilter` (a probe's knob, on) turns the filter off for an A/B arm.
  `omenMet` reads the living troops (their types' MP skills, a healer type, splash, regen, a small relic, worn thorns),
  their Heroes and Hero skills (a taunt, a stun, a slow, a weaken, a hex, a mark, a hit-back, a might or haste, Veil
  of Light's shield), their types' skills (Crushing Blow's stun) and awakening skills (Impale's hold and stun,
  Disarm's weaken), the oaths held and the Fx of the Pusaka bound to a living type (a ward, a heal or regen, a leap or
  burst, a mark, an every-Nth or cooldown Fx of a Langka or Epik, a status). Twin Fury's every is the worn fury's
  (`Fx.furyBeat`), so it is no every-Nth source; a Fx that needs a melee holder (Challenge Letter's taunt) counts only
  on a type that fights up close; Dulling Mail is the first cooldown Fx. Each switch the game has for those skills
  (`skills`, `heroSkills`, `awakenSkills`) is read. A need whose sources aren't in the game yet is not built
  (`OmenNeed.built`; every need is built since Ember Brand brought the Pusaka mark), and the batch that brings its
  first kind builds it.
- **The HUD numbers** (decisions-log 192): `omenShown(kind, level, e)` is what a kind's line shows: `{x}` its share,
  `omenShare(kind, e)` = min(max, perE × E), the very number its hook reads (`omenK`), or `{sec}` the same number in
  seconds (Trickle's time, "0.8s", and Deathless's); `{n}` its count by level
  (`OmenKind.byL`, Escort's 1, 1, 2, 2, which `omenGuards` reads); `{who}` its rank word by level (`OmenKind.who`: Vultures' "Strong", "Silver and gold"); and
  `{cap}` its named total, the share × `OmenKind.steps` (Horde's 3 steps, Adapt's 3 and Spree's 3 kills); `{s}` and `{es}` follow `{n}`'s plural
  (Unbowed's "2 holds, stuns or hexes"). The HUD fills its line from them (ui-hud.md), and Grudge's
  `{type}` from its target (`Game.grudgeType`: the type's plural, "none" with none). A share shows in percent with one
  decimal, two under 1% (`omenPercent`: Wear Down's 0.15%).
- **Lewati** gives no Bayangan (the owner's rule) and its gold stays as it was. From wave 20 the next wave owes the skip
  buff instead (`Game.skipBuffDue`, saved; moved onto the wave at its start, `waveSkipBuff`): that wave's first 30% of
  enemies get +10% to HP, damage, attack speed and walk speed (units-and-combat.md "Bayangan on the field"); two Lewati
  owe it once.
- **The levels** (`Game.omens`): one entry a level, oldest first, so a kind's level is its count (`omenLevel`).
- **The Beban factor** (`Game.omenFactor`), frozen at a wave's start beside Beban's: an army over the cap meets
  stronger Bayangan, by `armySize / armyCap` (1 at or under it, at most `omenOverMax` 2: 48 troops over a cap of 32 is
  ×1.5), × `omenScale` 1, and × `omenAtCap` 1 at or under the cap. A kind's effective level is E = L × the factor
  (`omenE`); Guard counts by L.
- **The ease:** at a won wave's end, each full `omenEaseShare` (an eighth) of the troops that started it fallen (6 of
  48, 4 of 32) takes the newest level away, at most `omenEaseMax` 2 a wave. What counts as a fall is the knob
  `omenEaseCount` (`OmenEaseCount`, `Game.omenFalls`): `falls`, every troop that fell, one Auto Buy bought back and that
  fell again too (as designed, and shipped); `starters`, only the troops that started the wave (`Game.omenStarters`),
  each once; `awakened`, only the falls of a type at Awaken 1 or more. Measured when they were switched on (decisions-log
  319): the owner's wave-58 army loses ~20 un-awakened fodder troops a wave, so with `falls` every wave eases 2, as many
  as the catch-up lands, and a chest's levels go within a wave or two; the owner decides.
- **An old save** (one without `omens`, with a Pusaka owned) catches up (the owner's answer): every Pusaka owned, the
  Toko's too, owes `omenMarks` × its stars levels of its counter, dealt one level at a time round-robin in `Relic` order,
  at most `omenCatchUpMax` 12 (`omenCatchUp`). They wait in `Game.omensOwed` and land `omenCatchUpStep` 2 a wave from
  the next wave's start (each overflowing as a take's do, along all the kinds). The owner's wave-86 save owes Wear Down
  2, Heal Siphon 2, Mend 2, Prey 2 and Armor 2 (its Dragon Heart's, its priests' Dawn Star's, God's Thunder's, the
  Grail's and Void Eye's counters since the Epik cut-over), all in by wave 91; the wave-89 save owes 19, so 12. `Game.omenCaughtUp` tells the UI to
  say so once ("Monsters answer your Artifacts: 12 Shadows come, 2 each wave").
- **Events:** `OfferShown.omens` (the faces), `OfferPicked.omen` / `levels` / `skipBuff`, `OmenGained` (`from` chest,
  catchUp or ukir) and `OmenEased` (both in the battle log's Musuh chip, in simple English like all in-game text:
  "Monsters got Armor 2 (Boss Chest w90)", "Late Shadow: Wound 2", "Carve: monsters got Haste 1", "Shadow eased: Armor
  down to 1"), and `WaveStarted.omens` (telemetry.md;
  `eventVersion` and `telemetryVersion` 8; 12 since they reach every player's records, decisions-log 319). Off, none is
  sent and no field written.

## Asah: a Pusaka's star for gold and small relics (P6, decisions-log 154)

The owner (2026-09-30): "iya bener duitnya itu aku bingung di buat untuk apa": gold had nothing left to buy (the
fixture's wave-86 save holds 1.8M). Asah is the Pusaka's gold sink and the small relics' (the design's §3.6 and §3.7,
owner decisions 4 and 6 at their defaults "a"). The rules are `lib/pusaka.dart` (`extension Asah on Game`), every
number one constant; the button is on the Tas page (ui-hud.md "Tas", "A Pusaka picked").

- **What it does** (`asah(relic)`): a Pusaka owned, bound or in the Gudang, gains a star for `asahPrice` in gold by
  the stars it has (60,000 to ★2, 150,000 to ★3; `asahPriceOf`) and `asahRelics` 10 small relics from `relicBag`.
  Its Ukir and the points on its bar stay ("Ukir" below). `asahItems` (owner decision 4 of the Ukir design, asked; its
  default: `[0, 0]`, none) is how many items it would also take from wave `ukirFrom` 40 on, by its stars
  (`asahItemTake`: one at a time from the kind with the most spare, `ukirSpare`), refused as `asahRefusals.items`
  "Not enough items" (in simple English, the owner's rule of 2026-10-03) after the relics; `PusakaAsah` then carries `items`.
  The bound type's troops refit at once (`_refitType`: Dragon Heart's HP comes with it, the HP gained added) and
  burst in gold, `Sfx.clear`, as the chest's Ambil; one in the Gudang just rises. It emits `PusakaAsah`
  (telemetry.md; the battle log on its Pusaka chip: "Sharpen: Dragon Heart ★2 on Templar (60k gold)", and a
  second row "Thorns 8, Fury 2 from the Bag").
- **Which relics** (`asahTake`; "Town and Smithy: Craft" below, decisions-log 233): any small relic in play, the
  cheapest first by craft gold, the dearer ones only once the cheaper are gone; among the kinds of one price one at a
  time from the kind the bag holds most of at that moment (ties: `Relic` order), so the bag stays even and the kind the
  player has least of is spared. The owner's wave-86 bag (Fang 17, Thorns 29, Fury 23, Guard 21) gives Thorns 10 (Fang
  and Thorns the cheapest). Relics held by troops are never taken. `asahTakeLine` writes it: "Thorns 10". Until
  decisions-log 321 a game without the Towns took from the four by count alone (that bag: Thorns 8, Fury 2).
- **Once per boss interval**, across all Pusaka, so the chest's duplicate cards keep their worth (§3.7):
  `Game.asahAt` is the wave of the last Asah (the wave last fought; `asahDone`). The interval is `wave ~/ bossEvery`:
  after wave 85's boss up to the end of wave 89 is one, and the next opens when the wave-90 boss is won
  (`asahAgainAt` 90).
- **Refusals** (`whyNotAsah(relic)`; refused, `asah` returns false with `Sfx.error` and nothing changes), in the
  design's order: `assignRefusals.over` after game over, `pusakaRefusals.none` "Not owned yet", then `asahRefusals`:
  `midWave` "Only between waves", `once` "Already sharpened this round", `gold` "Not enough gold", `relics` "Not
  enough relics (need 10)", and with no next star (no price, so neither the gold nor the relics are asked) `legend`
  "A Legendary can't be sharpened" (a Legenda stays ★1, design §3.4) or `maxed` "Already ★3".
- Stars come from three places, the chest's duplicates, Asah (critique M7) and Lebur (below). The star levels
  themselves were weighed with the chest (probes A1, C); Asah adds no new number to probe. The owner-telemetry check
  (critique H3e): over waves 87-100, gold spent should be at least 30% of income.

## Lebur: a Gudang Pusaka melted into another for a star (J3, decisions-log 164)

Late in a run the chest's cards pile up in the Gudang with nothing to do (the owner's w86 save keeps 3 there to w105,
late-economy design §3); Lebur gives them a use and gold another sink. Owner decision 3 at its default "(a)": any
rarity into any target, at Asah's price, no limit per boss interval. The rules are `lib/pusaka.dart`
(`extension Lebur on Game`), every number one constant; the button (Melt) and the picker are on the Bag page's facing
page (ui-hud.md "Tas": "Its strips" and "Melt's picker").

- **What it does** (`lebur(fodder, target)`): between waves a Pusaka in the Gudang (the fodder, not a Legenda) is
  melted into another Pusaka owned (the target, bound or in the Gudang, not a Legenda, under ★3), which gains
  `leburStars` 1 for `leburPrice` in gold by the target's stars (Asah's `asahPrice`: 60,000 to ★2, 150,000 to ★3;
  `leburPriceOf`) and `leburRelics` 0 small relics (`leburTake`, taken as Asah's would be). The target keeps the higher
  Ukir of the two and its own bar's points (`ukirMelt`, "Ukir" below; the picker's gist reads `leburUkir`). The fodder
  is gone (`pusaka.remove`) with its stars: nothing is paid back, and the chest may deal it again (`_offerable` asks only that
  it isn't at its top star, so a card can bring it back at ★1). The target's type refits at once and bursts in gold,
  `Sfx.clear`, as Asah's; one in the Gudang just rises. It emits `PusakaLebur` (telemetry.md; the battle log on its
  Pusaka chip: "Melt: Void Eye into Dragon Heart ★2 on Templar (60k gold)").
- **Apart from Asah** (`leburUsesAsah` false): `asahAt` is never touched, and a spent Asah never refuses a Lebur, so a
  boss interval can have an Asah and any number of Lebur. The fodder (chest cards, paid rerolls) is the limit, which
  keeps a duplicate card's worth (design §2.3). With the switch on, a Lebur would spend the interval's Asah and wait
  for it ("Already sharpened this round").
- **Rarity** (`leburRarity` false): any fodder into any target. With the switch on (decision 3's "(b)"), a Langka fodder feeds only a Langka target ("Rare only into Rare"); an Epik one still feeds any.
- **What it can go into** (`leburTargets(fodder)`): every Pusaka owned but the fodder and an oath, in `Relic`
  order; a Legenda and a ★3 one are listed and refused.
- **Refusals** (`whyNotLebur(fodder, [target])`; refused, `lebur` returns false with `Sfx.error` and nothing
  changes), in this order: `assignRefusals.over` after game over, `pusakaRefusals.none` "Not owned yet" (the
  fodder), then `leburRefusals`: `notGudang` "Only an Artifact in the Vault" (bound, or an oath), `midWave` "Only
  between waves", (`asahRefusals.once`, only with `leburUsesAsah`), `legend` "A Legendary can't be melted" (the
  fodder). Without a target (the button) last `noTarget` "No other Artifact under ★3" (no Pusaka could take a star;
  the gold isn't asked, the picker shows each price). With one: `same` "Same Artifact", `pusakaRefusals.none` (the
  target), `legend` (the target), `maxed` "Already ★3" (no price, so the gold isn't asked), (`rarity` "Rare only into
  Rare", only with `leburRarity`), `gold` "Not enough gold", (`relics` "Not enough relics (need n)", only with
  `leburRelics` above 0).
- No saved key: the fodder leaves `pusaka`, the target's stars are saved as before.

## Ukir: spare items into a Pusaka (decisions-log 183, 196)

The owner (2026-10-02) asked that items also make the artefacts stronger, so spare items keep a use late in a run (the
w91 save: 514 items in the bag, every troop item given). Between waves, from wave `ukirFrom` 40, spare items fill a
Pusaka's Ukir bar; a full bar is a step that adds part of a star. The rules are `lib/pusaka.dart` (`extension Ukir on
Game`), every number one constant there. The player sees it as **Carve** (the English glossary's name, `Words.carve`;
decisions-log 196): a Pusaka's Carve strip on the Bag's facing page taps it, and an item's Give rows give that kind to
one Pusaka (ui-hud.md "Tas"). The intro card K22 says so once it can be used (ui-hud.md "Guide").

- **Who:** every Pusaka with an Ukir role (its catalog row's `role`: attack Dawn Star, God's Thunder, Void Eye, War
  Drum; guard Dragon Heart, Iron Banner, Dragon Crown; life Grail, Blood Fang, Mourning Bell), bound or in the Gudang
  (`ukirGudang` true, owner decision 3's default). Never an oath.
- **Points:** an item of the Pusaka's role (`roleItems`: attack sword, bow, gloves; guard shield, boots; life potion,
  staff; each kind in one role) gives `ukirMatch` 2 points, any other kind `ukirAny` 1.
- **Steps:** `ukirCost` 60 / 90 / 135 / 200 / 300 points (785 in all), worth `ukirWorth` 0.2 / 0.2 / 0.2 / 0.1 / 0.1
  star (0.8 in all: owner decision 1's default, +5 worth 0.8 star), so ★n+5 never reaches ★(n+1). `OwnedPusaka.ukir`
  is the steps taken (0 to 5), `feed` the points on the next step's bar.
- **What it does** (`pusakaAt(relic, stars, ukir:)`, the one accessor, so the fight's books, the stats and every text
  agree): the level is the stars plus the worth of the steps taken (`ukirWorthOf`, to the thousandth). A number by
  stars goes on in a line between two stars, and past ★3 by the last gap (★3+5 = ★3 + 0.8 × (★3 − ★2)); at 0 it is
  exactly the table's. A number that is the same at every star moves by a named rule (`ukirPerStar`): God's Thunder's
  share of a leap +`thunderSharePerStar` 0.2 per star of worth (0.40 → 0.56 at +5), Dragon Crown's cap
  −`crownPerStar` 0.15 (0.60 → 0.48). Whole numbers (God's Thunder's leaps, `pusakaCountAt`) read the stars only.
  Examples: the Grail ★2 40% → 46% at +3, 48% at +5; Void Eye ★1 ×1.25 → ×1.33 at +5 (the boss ×1.19); Dragon Heart
  ★2 ×2.2 → ×2.84.
- **A tap** (`feedUkir(relic)`, the Carve button's second tap; what it would take: `ukirTake`): it gives at most `ukirTap` 60 points, the budget left
  and what the step still lacks (`ukirLeft`), so no point spills past a step. The items go one at a time from the
  spare ones (`ukirSpare`): the role's kinds first, each from the kind with the most spare then (ties in `Item` order:
  sword, shield, boots, bow, gloves, potion, staff), then the other kinds the same way. A role's item is never split:
  with 1 point left another kind gives it, or the tap stops there. On the w89 save God's Thunder's first tap takes bow
  15, sword 13 and gloves 2 (60 points).
- **A Give** (`feedUkir(relic, only: item)`, an item's Give row; `ukirTake(relic, only:)`, `whyNotUkir(relic, only:)`):
  the same tap with that kind alone, so the player picks which item goes where: its points (2 for the role's kind, 1
  for another), the same caps, `ukirKeep`, no split (a role's kind with 1 point lacking gives none: "Not enough
  items"). On the w89 save the Grail given boots takes 60 boots for its first step.
- **Kept back** (`ukirKeep` true; `ukirKept`): the items a type on the field (a troop of it alive) still needs for its
  next Bangkit (its recipe once more than its item level, less what it holds; none at Bangkit 3). The w89 save keeps 1
  bow (the Templar) and 1 glove (the Archers).
- **The budget** (`ukirPerBoss` 180 points a boss interval, all Pusaka together; `ukirBudget`): the interval is
  Asah's (the wave last fought ÷ 5), so a new 180 comes when the boss wave is won (`ukirAgainAt`). `Game.ukir`
  (`UkirRun`) keeps the interval of the last feed (`iv`), the points fed in it (`pts`) and the star worth fed in the
  run in thousandths (`milli`, +200 or +100 a step).
- **A step:** the bar is full, so `ukir` rises and the bar empties; the type's troops refit at once and burst in gold
  (Asah's), `Sfx.clear` (a tap without a step `Sfx.magic`).
- **Refusals** (`whyNotUkir(relic)`; refused, `feedUkir` returns false with `Sfx.error` and nothing changes), in
  order: `assignRefusals.over`, `pusakaRefusals.none`, then `ukirRefusals`, in the English glossary's words (the owner,
  2026-10-03: every in-game text is English; Carve and Artifact through `Words`): `midWave` "Only between waves"
  (`Words.onlyBetweenWaves`; `ukirMidWave` false), `from` "Carve opens at wave 40", `oath` "An Oath can't be carved",
  (`bound` "Equipped Artifacts only", only without `ukirGudang`), `full` "Carve is full", the budget "No points left:
  more at wave 95" (the wave that opens the next), `items` "Not enough items" (no spare item gives a point).
- **Kept, moved, lost:** a star-up (the chest's duplicate, Asah, Lebur) keeps `ukir` and `feed`; binding, a Pindah and
  the Gudang move them with the Pusaka; a sale loses them (the Pusaka is gone; one dealt or bought again starts at 0).
  A Lebur's target keeps the higher Ukir of the two and its own bar's points (`ukirMelt` `UkirMelt.higher`, owner
  decision 2's default; `sum` adds them up to +5, `lost` keeps the target's own); at +5 its bar is empty.
- **The enemy buffs:** each full `ukirOmenStars` 1.0 star of worth fed in a run (`UkirRun.milli` passing a multiple of
  1000; a sale never lowers it) calls the Bayangan star-up hook `_omenStarUp(relic)` once, on the step that passes it
  (`UkirStep.starUps`), lib/omen.dart's: while the Bayangan are on, from wave `omenFrom`, the Pusaka's counter gets
  levels by its rarity as a chest's take would ("Bayangan"). Deterministic: no die. The w89
  save's three bound Pusaka fed the full budget each interval (`ukirFill`) set off the first on the run's 5th step
  (the Grail's +2, interval 2) and the second on its 11th (the Grail's +4, interval 8).
- **Telemetry** (telemetry.md): `UkirFed` and `UkirStep` (trace events, never in the battle log), the wave record's
  `ukirItems`, `ukirPoints`, `ukirSteps` (only when some was fed) and each Pusaka's `ukir`.
- **Probe hooks:** `givePusaka(relic, {type, stars, ukir})` (`ukir` sets its steps, the bar empty) and `ukirFill({bound
  = true})`, which taps the bound Pusaka (every one owned with `bound: false`) until none takes more, each tap to the
  one with the fewest steps (ties in `Relic` order), so they rise together: the w89 save's three bound ones reach +1
  each in the first interval.

## Towns (decisions-log 216; on since 237)

The owner, 2026-10-03: small relics will no longer drop; they will be crafted at a Smithy, and only in a Town. A Town is
an interlude BETWEEN two waves, not a wave: the wave number and the difficulty don't move, and the mini boss / boss
schedule is untouched (the owner, 2026-10-04: "untuk town setiap wave antara wave 6 dan wave7, jadi harusnya tida
menggangu spawn mini boss atau boss"). This step builds the schedule and the Town's state; the materials and the rules
file's other blocks came next ("Town and Smithy: materials" below: relics no longer drop); the scene, the Smithy's
crafting and the Shop came in later steps. It shipped dark and is on since decisions-log 237, in every board game; the
TOWNS define (`townsOnBoard`) and the Towns-off UI it kept (the field's Shop tab, the Bag's Sell) went in decisions-log
296, and `Game.towns` with the rules from before the Towns in 321 (a plain `Game()`, the tests', the auto-player's and
the replay kit's, kept them till then): every game has the Towns. The switch-on made the save's format 2: a save from before the Towns is no save, and the
launch deletes it (architecture.md, lib/save.dart).

- **The numbers:** `assets/config/town.json`, the owner's tuning file (version 2: the materials' blocks below), `schedule` block: `chanceStart` 0.20,
  `chanceStep` 0.05, `chanceCap` 1.00, `minGap` 5, `firstTownAfter` 2, `autoLeave` 5.0 s. `main()` loads it before the
  first game into `loadedTownRules` (`TownRules.parse`: a file of another `version`, or not JSON, gives every default; a
  number missing, of the wrong kind or out of its range keeps its default; a cap under the start resets both; blocks it
  doesn't know are skipped, so later steps add theirs). Each game reads its own `Game.townRules`, so a test or probe swaps
  them per game: `TownRules.patch({'schedule': {'chanceStart': 1.0}})` (a Town at every unblocked roll). The defaults
  in code are the shipped file (test/town_test.dart).
- **Slots:** "a Town before wave s" (slot s) opens after wave s−1 is won, before wave s starts.
- **The roll** (`Towns._rollTown`, lib/town.dart), in `tick`'s win path after the Hero (`_crownHero`) and the Boss Chest
  (`_bossChest`), so the auto-save keeps it: after wave n is won, for slot n+2 (one wave of warning):
  - a Town already marked: no roll;
  - blocked, n+2 − `townLast` < `minGap`: no roll, and the chance doesn't grow;
  - else one draw on `Game.townDice` (a `Random` of its own, injectable like `draft`): under `townChance` the slot is
    marked (`townAt`) and the chance goes back to `chanceStart`; else `townChance` = min(`chanceCap`, `townChance` +
    `chanceStep`).
  - A new run counts as a Town before wave `firstTownAfter` (`townLast` 2), so the first roll comes after wave 5 and the
    first Town before wave 7 at the earliest; two Towns are at least 5 waves apart. With every roll hitting, Towns come
    before waves 7, 12, 17, 22, …
- **The Town:** `townDue` (`townAt == wave + 1`, no wave on). While it is due no wave starts
  (`canStartWave` is false; the start button hides) until it is gone into and left: `enterTown({auto})` (`inTown`) and
  `leaveTown({auto})`, which makes its slot `townLast` and clears the mark. `townMarked` (marked and not yet gone into)
  drives the wave meter's chip (ui-hud.md "The Town chip"). Each Town gone into counts (`townCount`, decisions-log
  326): its number picks its identity, its look and its market ("Towns: the market" below).
- **The scene:** the HUD goes into a due Town once nothing of the win is left on screen and draws the
  Town where the field was (ui-hud.md "Town"; the field waits as it was left); the start button says "Leave town" there
  (ui-hud.md "Towns on the HUD"), and Auto leaves it after `autoLeave` s unless a press in the Town stopped it. The book's
  Shop is a Town's then, and its Smithy tab crafts (ui-hud.md "The Smithy"; the Smithy's rule is "Town and Smithy:
  Craft"; "The store": it deals only there, decisions-log 230).
- **Probes:** `Game.townPolicy` 'leave' goes through a due Town (in and out at once) at the next wave's start
  (`startWave`); null leaves it to the HUD. `townRules`, `townDice` and `townPolicy` are members, so the probe
  knobs reach them by name (the shared probe knobs set `townPolicy` 'leave' by default: every game meets Towns).
- **The dice and determinism:** one draw a roll, none while blocked or marked; the Town dice aren't saved (decision
  112's rule, as the chest's), so the same seeds and the same play give the same Towns, and after a reload the later
  rolls are new draws. No other die moves: a seeded run plays the same, wave by wave, through Towns (a probe going
  through each) and with none (rules whose every roll misses), and the queue (a mini boss every 3rd wave, the boss
  every 5th) and the Boss Chests are the same.
- **Telemetry** (telemetry.md): `townMarked`, `townEntered` (its `n` and `identity` since decisions-log 326), `townLeft`, and a
  won wave's `town`.

## Town and Smithy: materials (decisions-log 221)

The owner, 2026-10-04: "buat ke 30": 30 materials, every monster type its own. Monsters drop materials and no relics
(the board since decisions-log 237, every game since 321); the Smithy crafts the small relics from them in a Town ("Town
and Smithy: Craft" below), and the Town's Shop buys them (decisions-log 230, "The store": the Bag sells none).

- **The 30** (`enum Mat`, lib/town.dart; the value is the save key and the icon's name `mat_<key>.png`, only appended;
  the names in `Words.materialNames`): each monster type's **Common** part and **Rare** part (the Necromancer has no
  Common: it is never normal or elite), and three **Trophies**. The enum's order is the Bag's: Common, Rare, Trophy,
  within a grade the monsters weakest first (`enemyTypes`), then the Necro Healer, then the Necromancer. The forge's two
  stones come after them (`craftedMats`; never dropped: "The forge: data" below).

  | Type | Common (sell) | Rare (sell) |
  |---|---|---|
  | Slime | Slime Gel (10) | Slime Core (40) |
  | Bat | Bat Wing (10) | Bat Fang (40) |
  | Skeleton | Bone Shard (15) | Skull (60) |
  | Orc | Orc Tooth (15) | Orc Tusk (60) |
  | Skeleton Archer | Bone Arrow (20) | Bone Bow (80) |
  | Werewolf | Wolf Claw (25) | Wolf Fang (100) |
  | Armored Skeleton | Rusty Plate (25) | Cracked Skull (100) |
  | Orc Rider | Leather Strap (30) | Warg Fang (120) |
  | Veteran Orc | Orc Ear (35) | Orc Heart (140) |
  | Armored Orc | Iron Scrap (40) | Iron Tusk (160) |
  | Greatsword Skeleton | Big Bone (40) | Grave Steel (160) |
  | Werebear | Bear Fur (50) | Bear Claw (200) |
  | Necro Healer | Teal Cloth (30) | Teal Gem (120) |
  | Necromancer | – | Dark Gem (200) |

  Trophies: Evil Eye (300, every mini boss), Soul Orb (600, every boss), Lich Orb (800, the Necromancer as a mini boss
  or the boss). "Sell" is what the Town's Shop will pay for one (town.json `materials`).
- **The drop** (`TownRules.dropOf(type, tier, dice)`, called from `_hurt` through `Materials._dropMaterials` after the
  item and relic rolls): by the kill's rank (town.json `drops`), its type's part of the rank's grade at the rank's
  chance, then the rank's always-drops:

  | Rank | normal | elite | high elite | mini boss | boss |
  |---|---|---|---|---|---|
  | Part | Common, 15% | Common, 30% | Rare, 35% | Rare ×2, always | Rare ×3, always |
  | Always | – | – | – | Evil Eye | Soul Orb |

  The Necromancer as a mini boss or the boss also drops a Lich Orb (`drops.necromancerSlot.plus`); as an escort's high
  elite its Dark Gem at 35%. A raised monster (`raisedBy`: a necromancer's minions, Split's slimes, Swarm's bats) drops
  none, like its gold. A hexed monster drops as its own type and rank (Slime Hex swaps only its stats).
- **The dice:** `Game.matDice` (a `Random` of its own, injectable, not saved; probes seed it with seed + 700): one draw
  a kill whose rank's chance is between 0 and 1 and whose type has that part; none for an always-drop. The `loot` dice
  draw as before the Towns (each kill's item and relic drawn and thrown away, Drops above), so everything else of a
  seeded run is the same.
- **Into the bag:** a kill's materials go into `waveMaterials` (the wave's tally) and lie where the kill fell until the
  wave is won, then fly to the Bag (`matPops`, ui-hud.md "The Bag's Materials", decisions-log 262; only the look); the
  win moves the tally into `materials` (kind → count) and keeps it as
  `lastMaterials` for the "VICTORY!" line ("3x" and the icon, each kind once, in the enum's order). A lost game loses
  the tally. Expected by wave 10 / 20 / 30 / 60 in a run that wins every wave: about 49 /
  161 / 328 / 1,122 in all (the design's model).
- **In the Bag** (ui-hud.md "The Bag's Materials"): a Materials chip, a cell per kind held after the
  small relics, a facing page that says who drops it and what it is for, and one row "Craft at the Smithy" naming the
  relics whose recipe takes it ("Fang, Fury"; "Only in a Town" outside one). No Sell row: the Town's Shop buys them,
  each at its own `sell` price (`sellPrice(mat)`). `inBag(mat)` counts them.
- **The rules file's other blocks** (town.json, version 3 since the forge's data, "The forge: data" below; the `relics`
  numbers of the Smithy's seven and the recipes' tiers since decisions-log 227, the recipes, the tiers' prices and the
  shop's item prices with the Craft step, decisions-log 233, "Town and Smithy: Craft" below): each small relic's recipe
  in its `relics` entry's `recipe` (version 2's `recipes` block, which still reads; the 11 of `townRelics` and the
  forge's nine, by save key: its tier, materials, items and gold; every one of the 30 is in some recipe), `tiers` (Basic / Strong / Mighty: a sale's share of the craft gold, the Shop's price 12,000 /
  20,000 / 32,000 and its rise 20% a buy), `relics` (each crafted relic's numbers: Fang's share 0.30, Fury's every 3
  and ×2, …), `shop` (open from wave 1 won, so in every Town, decisions-log 253; an item 2,000 + 200 a buy, sold back at half). `TownRules.parse` keeps a
  number's default when it is missing, of the wrong kind or out of range, and leaves out a name the game doesn't know
  (a material, a monster type, a relic, an item) where it stands, listing it in `TownRules.skipped` (main.dart prints
  each with `debugPrint`). test/town_materials_test.dart pins the file to the defaults. The shop's `from` is the wave
  after which a Town's Shop opens (`shopFrom`, decisions-log 237: "The store"); 1, the earliest a Town comes, opens it
  in every Town (the owner, 2026-10-07: "shop juga harusnya di buka ketika masuk kota"). It opens the Shop only: Awaken 4-5, Forge and Recall keep `storeFrom` (`armyBuysOpen`).
- **Saved:** `materials` (key → count, only when any); an unknown key is skipped. The tally of a wave in progress isn't
  (a save holds no wave in progress).
- **Telemetry** (telemetry.md): a wave record's `materials` (dropped) and its start's `materials` (held).

## The forge: drops (decisions-log 246)

The owner, 2026-10-04: items are crafted, never dropped by monsters; monsters drop more crafting materials; the Town
Shop sells only what dropped in earlier waves, at 2.5x the sell price. The forge is on in every board game since its
cut-over (decisions-log 272), and since decisions-log 296 it has no switch of its own (`forgeLive`, `Game.forgeOn` and
the `--dart-define=FORGE=false` build are gone), and since decisions-log 321 every game has it (a plain `Game()`, the
tests', had the rules from before the Towns until then).

- **No item drops** (the kill block in `_hurt`): every `loot` draw still happens (the item roll and its kind, the
  relic roll and its kind), and both are thrown away (Drops, above); items come from the Smithy.
- **The materials' table** (`TownRules.forgeDrops`, town.json `drops.forge`: a list a rank, each entry its type's part
  of a grade at a chance, a count, and always-drops), about 3x the table from before the forge (town.json's
  `drops.normal` to `drops.boss`, gone with the forge-off build, decisions-log 296: an old file's are noted in
  `skipped` and never read):

  | Rank | normal | elite | high elite | mini boss | boss |
  |---|---|---|---|---|---|
  | Common | 60% | always | always | ×3 always | ×4 always |
  | Rare | – | – | 50% | ×3 always | ×4 always |
  | Always | – | – | – | Evil Eye | Soul Orb |

  The Necromancer as a mini boss or the boss still adds a Lich Orb (`drops.necromancerSlot.plus`); having no Common, it
  drops its Dark Gem alone. `TownRules.dropOf(type, tier, dice)` goes through the rank's list in order, a
  `matDice` draw for each part with a chance between 0 and 1 (a normal's Common, a high elite's Rare), then every
  entry's always-drops. The Bag's "who drops it" line (`matSource`) reads the same table ("Common material. Slimes drop it, a slime mini boss 3, a boss 4."). A file entry missing a number keeps
  the shipped entry's (one past them drops nothing); a rank that isn't a list keeps its default.
- **How many:** a board run that wins every wave (4 seeds, every queue's monster killed) held 68 / 156 / 324 / 542
  materials by wave 6 / 10 / 15 / 20, as the design's model expects (68 / 156 / 326 / 543; today's table 22 / 49 /
  100 / 161).
- **The kinds seen** (`Game.matsSeen`, an insertion-ordered set): each kind joins the first time a kill drops it
  (`_dropMaterials`, before the win; a raised monster drops none). Nothing else adds to it: a material the Shop sells
  or one put in the bag another way doesn't, and selling the last one doesn't take it off. The forge's Town Shop
  sells only these.
- **The Shop's price for a material** (`shopMatPrice(mat, [bought])`, `TownShop.matPrice`): its sell price
  (`materials`' `sell`) × town.json `shop.matMarkup` (2.5) rounded up to 5 (Slime Gel 25, Wolf Claw 65, Bear Claw 500,
  Evil Eye 750, Soul Orb 1,500, Lich Orb 2,000), plus `shop.matRise` (0 as shipped) of that a buy, also rounded up to 5.
  The Shop's shelf and buy read it ("The forge: the Town Shop" below).

## The forge: the Town Shop (decisions-log 248)

The owner, 2026-10-04: "shop di town hanya menjual item yang pernah di drop dari wave sebelumnya dengan harga x2.5 harga
jual item ke toko" (the Town Shop sells only what dropped in earlier waves, at 2.5x what the Shop pays for it). Like
the drops above, every game has it (decisions-log 321).

- **The shelf** (`onShopShelf`): every material that has dropped this run (`matsSeen`, in first-drop order), each at
  `shopMatPrice` (Slime Gel 25, Wolf Claw 65, Evil Eye 750, Soul Orb 1,500, Lich Orb 2,000). No item and no small relic:
  they never drop, so they are never on the shelf; buying one is refused `notSold` "Not for sale",
  as is a material not seen yet. The store's Artifact shelf is unchanged. Nothing dropped yet: the shelf is empty.
- **Buying a material** (`buy`): its price in gold, one more in `materials` (a first one too), `Sfx.kill`, a
  `StoreBought` record with the material under `material`. It is counted in `storeBought` (saved by its name with the
  rest), so `shop.matRise` would raise that kind's next price a buy over the run, as the other goods rise; 0 as
  shipped, so a kind always costs the same. A bought material never joins `matsSeen`.
- **Selling** is unchanged: the Shop still buys everything, an item and a small relic at half their worth (`sellPrice`:
  the Towns' prices), a material at its sell price, a Vault Artifact as before. Selling the last of a kind leaves it on
  the shelf.
- **When:** the Shop opens as without the forge (`shopFrom`: every Town as shipped), in a Town only.
- **The page:** ui-hud.md "The Town's Shop" (Buy's sections: Materials alone, Items and Relics having none, decisions-log
  280; the empty shelf's line; Sell and its basket, decisions-log 269).

## Town and Smithy: Craft (dark, decisions-log 233)

The owner, 2026-10-03/04: the small relics are crafted at a Smithy, only in a Town, from the monsters' materials, as
many as the bag can pay for (no limit a visit); every one of the 30 materials goes into some recipe. The rules are
`extension Craft on Game` (lib/town.dart); the Smithy's pages draw them (ui-hud.md "The Smithy", decisions-log 235).

- **The recipes** (town.json `relics.<key>.recipe`, `TownRules.recipes`; `craftRecipe(relic)`, none for a Pusaka; the
  forge's changes, "The forge: data" below):

  | Relic (key) | Tier | Materials | Item | Gold | Sells for |
  |---|---|---|---|---|---|
  | Fang (`fang`) | Basic | Bat Wing 2, Slime Gel 2 | – | 300 | 150 |
  | Thorns (`thorns`) | Basic | Slime Gel 3, Bone Shard 2 | – | 300 | 150 |
  | Fury (`fury`) | Basic | Bat Wing 2, Bone Shard 2, Skull 1 | – | 400 | 200 |
  | Guard (`guard`) | Basic | Orc Tooth 3, Slime Gel 2 | – | 400 | 200 |
  | Sweep (`cleave`) | Strong | Wolf Claw 4, Leather Strap 3, Orc Tusk 2, Wolf Fang 1 | Sword | 1,000 | 500 |
  | Venom (`venom`) | Strong | Bone Arrow 4, Slime Core 2, Bat Fang 1, Bone Bow 1 | Bow | 1,000 | 500 |
  | Mana Siphon (`manaSiphon`) | Strong | Teal Cloth 4, Bat Fang 2, Slime Core 1, Teal Gem 1 | Staff | 1,000 | 500 |
  | Spirit Ward (`spiritWard`) | Strong | Rusty Plate 4, Skull 2, Cracked Skull 1, Warg Fang 1 | Shield | 1,000 | 500 |
  | Iron Will (`lastStand`) | Mighty | Bear Fur 3, Orc Heart 1, Bear Claw 1, Evil Eye 1 | Boots | 3,000 | 1,500 |
  | Giant Slayer (`giantSlayer`) | Mighty | Iron Scrap 4, Orc Ear 3, Iron Tusk 1, Soul Orb 1 | Gloves | 3,500 | 1,750 |
  | Holy Charm (`blessing`) | Mighty | Big Bone 4, Grave Steel 1, Dark Gem 2, Lich Orb 1 | Potion | 3,000 | 1,500 |

  The Basic four take the first monsters' Common parts (Fury a Skull), so the first Town can make them; the Strong four
  the middle monsters' Common parts and the early Rare parts and an item; the Mighty three the late monsters' parts, a
  Trophy and an item. Each item kind is in one recipe. On average (the design's model, 4,000 runs, gold not counted) a
  Basic relic is first covered at the first Town (before wave 10-14), a Strong one at a Town before wave 20-23, a
  Mighty one before wave 28-31.
- **Craft** (`craft(relic)`): takes the recipe's materials (`Game.materials`; the last one of a kind leaves no entry),
  its items (`inventory`) and its gold, adds one to `relicBag`, plays `Sfx.clear` and emits `Crafted` (telemetry.md;
  the battle log under Other: "Crafted Sweep (1,000 gold)", the relic's icon). The message window's line is
  `craftedLine(relic)`, "Sweep crafted!" (`Words.crafted`), which the Smithy's page shows after its Craft. Again and
  again while the bag can pay: no limit a visit. An item is taken even when a fielded type's next Awaken needs it (no
  reservation, the design's decision 11): the page's item row warns with `craftItemNeed(item)`, the first fielded type
  (a living troop of it, in the troop types' order) still short of that item for its next Awaken from items (below
  Awaken 3; `awakenShort`, by grade the next grade set): the type, how many more and which Awaken ("Knight needs 1 for Awaken 2"). Its material rows name where each
  comes from with `matFrom(m)`: the monster whose part it is ("Werewolf"), the Necromancer for the Lich Orb, a Trophy's
  rank ("Mini Boss", "Boss").
- **Refusals** (`whyNotCraft(relic)` → `CraftRefusal`: `why` (`CraftWhy`), `short` (the material or item short),
  `have`, `need` and its `text`), in this order; refused, `craft` returns false, nothing changes and `Sfx.error` plays:
  `over` "Game over"; `town` "Only in a Town" (`Words.onlyInTown`); `recipe` "No recipe" (a
  Pusaka); `material`, the recipe's first material short: "Need 2 more Wolf Claw" (2 of 4 held), "Need 4 Wolf Claw"
  (none held); `item`, its first item short: "Need 1 Bow"; `gold` "Not enough gold" (`Words.notEnoughGold`).
  `canCraft(relic)`: none of them.
- **The page's rows** (`craftRows(relic)`, each a `CraftRow` `(kind, have, need)`): each material, then each item, in
  the recipe's order, then the gold (`kind` null); none for a relic without a recipe.
- **A visit's crafts:** `TownLeft` carries the relics crafted in that Town (`crafts`) and their gold (`craftSpent`); the
  battle log says "Left town: 2 crafted" (just "Left town" for none).
- **The Shop's prices** (inside the Store's own `basePrice`, `buyPrice` and `sellPrice`, so their callers don't
  change; every number from town.json):
  - a small relic costs its tier's `shop` price, Basic 12,000, Strong 20,000, Mighty 32,000, and its `shopRise`, 20% of
    it, more after each one of that kind bought (`storeBought` counts per kind: Fang 12,000, 14,400, 16,800, …;
    `TierPrices.priceAfter`; the forge's Shop sells none, decisions-log 248, so only a count from before it raises it).
    The save restores `storeBought` of the Smithy's seven too;
  - it sells back at the market's price ("Towns: the market" below, decisions-log 326; until then for its tier's
    `sellShare`, half, of its craft gold, 150 to 1,750: `sellShare` stays in town.json, read by nothing);
  - an item: the `shop` block's `itemPrice` 2,000, +`itemRise` 200 a buy (the forge's Shop sells none); sold back at
    the market's price (until decisions-log 326 for `itemSellShare` half of `itemPrice`, 1,000 whatever the item:
    kept, read by nothing);
  - an Artifact as before ("The store" below).
  Until decisions-log 321 a game without the Towns priced by the field Toko's constants (`itemPrice`, `relicPrice`).
- **Asah** (`asahTake`, the design's decision 10: a 32,000-gold Mighty relic is never eaten while a
  300-gold one is in the Bag): it counts and takes any of the eleven (`asahRelicsInBag`), the cheapest first by craft
  gold: Fang and Thorns (300), then Fury and Guard (400), then the Strong four (1,000), then Iron Will and Holy Charm
  (3,000), then Giant Slayer (3,500), a dearer kind only once every cheaper one is gone; among the kinds of one price,
  one at a time from the one held most (ties: the `Relic` order). Fang 3, Thorns 5, Fury 4, Sweep 5 give Thorns 5,
  Fang 3, Fury 2.
- **Telemetry** (telemetry.md): the `crafted` event (`relic`, `materials`, `items`, `gold`); a wave record's `crafted`,
  `materialsUsed` and `gold.craftSpent` (the crafts since the last wave ended, so a Town's land in the next wave's
  record); a `townLeft`'s `crafts` and `craftSpent`.
- **Tests:** test/town_craft_test.dart (each refusal in order, no limit, the takes, the rows, every recipe from exactly
  its own, the prices, Asah's order, the event and the telemetry).

## The forge: data (decisions-log 245)

The owner, 2026-10-04: every item is crafted at the Smithy, in three grades, and more kinds of item; twenty small
relics; late in a run an item can be enhanced. This is the forge's data: the enums, town.json version 3, the words and
the icons. The items' crafting and Awaken by grade read it ("The forge: items crafted, Awaken by grade" below); the rest
waits for its own step. Like "The forge: drops" above, every game has it (decisions-log 321).

- **Items** (`enum Item`, game.dart): 14 kinds (`ItemSlot`) in 3 grades (`Item.grade`, 1 to 3), 42 in all, each value
  with its kind (`Item.slot`) and grade. The first seven are the items monsters drop (`droppedItems`, grade I, in the
  index the drop dice use, `droppedItemKinds`); then the five new kinds' grade I, grade II of the twelve kinds Awaken
  uses, their grade III, then the Cap's (`ItemSlot.helm`) and the Ring's three. The counts are the enum's: nothing
  counts kinds or grades by hand. `Relics.itemsInPlay` (the Bag's items, the guide's item page) is every item (until
  decisions-log 321 a game without the Towns had `droppedItems`); the store's goods, Carve and Asah keep
  `droppedItems`.
  The five new kinds each serve what no item did: the Amulet max HP, the Prayer Beads a healer's heals, the Torch damage
  to the undead (a foe with `Stats.dark`), the Spear a melee fighter's reach past `meleeMaxRange`, the Prism the splash
  area. Grades II and III of the twelve Awaken kinds are made from the middle and the late monsters' Common parts with no
  item (the Rare parts and the Trophies stay for the relics, the Cap and Ring line and the stones); the Cap and the Ring
  take their grade below. Gold by grade: 20, 60, 250 (the Cap and the Ring 150, 600, 2,500). town.json `items` holds
  each one's recipe and its `effect` (`ItemRecipe`); the seven's effects are today's numbers (`swordDmg` …):

  | Item (key) | Kind | Grade | Materials | Item | Gold | Effect |
  |---|---|---|---|---|---|---|
  | Sword (`sword`) | Sword | I | Bone Shard 2, Orc Tooth 2 | – | 20 | attack +25% |
  | Shield (`shield`) | Shield | I | Orc Tooth 2, Bone Shard 1, Slime Gel 1 | – | 20 | -2.5 damage a hit |
  | Boots (`boots`) | Boots | I | Bat Wing 2, Slime Gel 2 | – | 20 | walk +25% |
  | Bow (`bow`) | Bow | I | Bat Wing 2, Bone Shard 1, Teal Cloth 1 | – | 20 | reach +20% |
  | Gloves (`gloves`) | Gloves | I | Bat Wing 1, Slime Gel 1, Orc Tooth 1, Teal Cloth 1 | – | 20 | wait -20% |
  | Potion (`potion`) | Potion | I | Slime Gel 2, Bat Wing 1, Teal Cloth 1 | – | 20 | +5 HP/s |
  | Staff (`staff`) | Staff | I | Bone Shard 2, Teal Cloth 1, Slime Gel 1 | – | 20 | magic attack +25% |
  | Amulet (`amulet`) | Amulet | I | Orc Tooth 2, Slime Gel 1, Bone Shard 1 | – | 20 | max HP +8% |
  | Prayer Beads (`prayerBeads`) | Beads | I | Teal Cloth 2, Bat Wing 1 | – | 20 | heals +12% |
  | Torch (`torch`) | Torch | I | Bone Shard 2, Bat Wing 1 | – | 20 | to the undead +12% |
  | Spear (`spear`) | Spear | I | Orc Tooth 1, Bone Shard 1, Bat Wing 2 | – | 20 | melee reach +15% |
  | Prism (`prism`) | Prism | I | Slime Gel 2, Teal Cloth 1 | – | 20 | splash +15% |
  | Steel Sword (`steelSword`) | Sword | II | Wolf Claw 2, Orc Ear 1 | – | 60 | attack +28% |
  | Tower Shield (`towerShield`) | Shield | II | Rusty Plate 2, Leather Strap 1 | – | 60 | -4 damage a hit |
  | Swift Boots (`swiftBoots`) | Boots | II | Leather Strap 2, Wolf Claw 1 | – | 60 | walk +27% |
  | Long Bow (`longBow`) | Bow | II | Bone Arrow 2, Leather Strap 1 | – | 60 | reach +22% |
  | Steel Gloves (`steelGloves`) | Gloves | II | Leather Strap 1, Rusty Plate 1, Wolf Claw 1 | – | 60 | wait -22% |
  | Big Potion (`bigPotion`) | Potion | II | Orc Ear 2, Teal Cloth 1 | – | 60 | +8 HP/s |
  | Magic Staff (`magicStaff`) | Staff | II | Bone Arrow 1, Orc Ear 1, Teal Cloth 1 | – | 60 | magic attack +28% |
  | Silver Amulet (`silverAmulet`) | Amulet | II | Orc Ear 2, Rusty Plate 1 | – | 60 | max HP +10% |
  | Holy Beads (`holyBeads`) | Beads | II | Teal Cloth 2, Leather Strap 1 | – | 60 | heals +15% |
  | Holy Torch (`holyTorch`) | Torch | II | Bone Arrow 2, Rusty Plate 1 | – | 60 | to the undead +15% |
  | Winged Spear (`wingedSpear`) | Spear | II | Wolf Claw 1, Rusty Plate 1, Bone Arrow 1 | – | 60 | melee reach +18% |
  | Arcane Prism (`arcanePrism`) | Prism | II | Teal Cloth 1, Wolf Claw 1, Orc Ear 1 | – | 60 | splash +18% |
  | Royal Sword (`royalSword`) | Sword | III | Big Bone 2, Orc Ear 1 | – | 250 | attack +32% |
  | Royal Shield (`royalShield`) | Shield | III | Iron Scrap 2, Rusty Plate 1 | – | 250 | -6 damage a hit |
  | Wind Boots (`windBoots`) | Boots | III | Bear Fur 2, Leather Strap 1 | – | 250 | walk +30% |
  | Great Bow (`greatBow`) | Bow | III | Big Bone 2, Bone Arrow 1 | – | 250 | reach +25% |
  | Royal Gloves (`royalGloves`) | Gloves | III | Iron Scrap 1, Bear Fur 1, Leather Strap 1 | – | 250 | wait -25% |
  | Elixir (`elixir`) | Potion | III | Bear Fur 1, Orc Ear 1, Teal Cloth 1 | – | 250 | +12 HP/s |
  | Crystal Staff (`crystalStaff`) | Staff | III | Bear Fur 1, Big Bone 1, Teal Cloth 1 | – | 250 | magic attack +32% |
  | Gold Amulet (`goldAmulet`) | Amulet | III | Iron Scrap 1, Big Bone 1, Orc Ear 1 | – | 250 | max HP +12% |
  | Saint Beads (`saintBeads`) | Beads | III | Bear Fur 1, Teal Cloth 2 | – | 250 | heals +18% |
  | Sun Torch (`sunTorch`) | Torch | III | Big Bone 2, Bone Arrow 1 | – | 250 | to the undead +18% |
  | Royal Spear (`royalSpear`) | Spear | III | Iron Scrap 2, Wolf Claw 1 | – | 250 | melee reach +22% |
  | Royal Prism (`royalPrism`) | Prism | III | Bear Fur 1, Iron Scrap 1, Teal Cloth 1 | – | 250 | splash +22% |
  | Leather Cap (`leatherCap`) | Helm | I | Leather Strap 2, Orc Tooth 1 | – | 150 | damage taken -4% |
  | Steel Helm (`steelHelm`) | Helm | II | Rusty Plate 2, Skull 1 | Leather Cap | 600 | damage taken -5% |
  | Royal Helm (`royalHelm`) | Helm | III | Iron Scrap 2, Evil Eye 1 | Steel Helm | 2,500 | damage taken -7% |
  | Ring (`ring`) | Ring | I | Bat Fang 1, Slime Core 1 | – | 150 | +0.1 MP/s |
  | Gem Ring (`gemRing`) | Ring | II | Teal Gem 1, Wolf Fang 1 | Ring | 600 | +0.15 MP/s |
  | Royal Ring (`royalRing`) | Ring | III | Bear Claw 1, Soul Orb 1 | Gem Ring | 2,500 | +0.2 MP/s |

  `Stats.upgraded` reads each item's own effect, every grade of the seven and the Cap's and the
  Ring's ("The forge: items crafted, Awaken by grade" below, decisions-log 249) and the five new kinds' ("The forge: the
  new kinds' effects" below, decisions-log 251). The card (`itemEffect`) says the file's effect ("+12% max HP", "-7%
  damage taken", "+0.15 MP every second").
- **The nine new small relics** (`forgeRelics`, appended to `Relic` after the Artifacts; Basic, Strong, Mighty by their
  recipe's tier): Chill, Shark Tooth, Grit, Ambush, Weak Spot, Hot Streak, Avalanche, Afterglow, Reaper. Each has its
  numbers in its town.json `relics` entry (`relicK`), a one-line card (`relicEffect`: "Every 3rd hit slows 30% for 1.5 s
  (bosses 15%)", "Hits mark a monster 3 s: it takes +12% from all (bosses +6%)"; a card never names another relic or a
  combo), a "Best on" hint (`relicBestOn`) and an icon. Their effects: "The forge's nine" above (decisions-log 250).
  `Relics.relicsInPlay` lists them in every game (the Bag, the Town Shop's page and Asah then count them as any small
  relic in play);
  `smallRelics` stays the eleven, so no drop and no store ever offers them.
- **The relics' recipes with the forge** (`TownRules.forgeChanges`, a `relics` entry's `forge` block: only what
  changes; `forgeRecipe(key)`): every one of the eleven costs 70% of its gold, rounded to 50 (Fang 200, Fury 300, the
  Strong four 700, Iron Will and Holy Charm 2,100, Giant Slayer 2,450), Mana Siphon takes Bone Arrow 3 for Teal Cloth 4,
  and the Mighty three a grade-II item (Iron Will a Tower Shield, Giant Slayer Steel Gloves, Holy Charm a Big Potion).
  The nine's recipes are at that gold already (Chill 200 … Reaper 2,450). `craftRecipe(relic)` reads them (the
  eleven's own were a game without the Towns' until decisions-log 321).
- **The stones** (`craftedMats`: Mithril and Starmetal, appended to `Mat`, grade `MatGrade.crafted`, `Mat.crafted`):
  made at the Smithy for Enhance, never dropped. No drop rule names them, `matsSeen` never takes one (not from a drop,
  not from a save), the Bag shows them (`Materials.matsInPlay`: every `Mat`), and
  their "who drops it" line is "Made at the Smithy." (`Words.madeAtSmithy`). Their `sell` is half their worth (Mithril
  770, Starmetal 2,970).
- **The combos** (town.json `combos`, `Combos`): the small relics' damage factors on one blow multiply to at most
  `relicMost` 3.0 (the Artifacts' own outside it), and hidden pairings (`secret`), each setting one relic's numbers
  when its holder has what it names. Nothing in the game names them. Both act since decisions-log 250 ("The forge's
  nine" above).
- **Awaken by grade** (town.json `awaken`, `AwakenRules`): `share` [1, 1, 0.667]: Awaken L needs the type's recipe in
  grade-L items, grade III's counts two thirds of the recipe's, rounded up. Its `byGrade` switch (false kept the rule
  from before the grades) is gone (decisions-log 296): an old file's is ignored. The rules: "The forge: items crafted, Awaken by grade" below.
- **Enhance** (town.json `enhance`, `EnhanceRules`): from wave 30 (`from`) a crafted item goes up to +5 (`most`), each
  step adding a tenth of its own bonus (`per`), step n taking `stone` n (Mithril for +1 to +3, Starmetal for +4 and
  +5) and `gold` n (500, 1,000, 1,500, 2,500, 4,000); the stones' recipes are `stones` (Mithril: Evil Eye 1, Iron Scrap
  2, Grave Steel 1, 1,000 gold; Starmetal: Soul Orb 1, Lich Orb 1, Mithril 1, 3,000 gold), and an item at +n shows
  under `tints` n (the awakening colours, `#3D8BFF` … `#F2F6FF`) at `tintAlpha` 0.45. A file whose `gold`, `stone` and
  `tints` don't each have `most` entries keeps all four defaults. Enhance reads it ("The forge: Enhance" below).
- **town.json version 3** (`TownRules.version`; `versions` [2, 3]): each relic's recipe sits in its `relics` entry
  (`recipe`, and `forge` with the forge's changes) instead of version 2's `recipes` block; `items`, `combos`, `awaken`
  and `enhance` are new, and `materials` names the stones. A version-2 file still reads whole (its `recipes` block, the
  new blocks from their defaults), and `TownRules.patch` takes either nesting. test/fixtures/town-v2.json is the last
  version-2 file.
- **Icons** (tool/import_fx.py `LOOT`, from the Kenmi pack's 32 px singles, each mapped with tool/sprite_map.py first):
  `item_<key>.png` for the 35, `relic_<key>.png` for the nine, `mat_mithril.png` and `mat_starmetal.png`; the three
  grades of a new kind are one design in the pack's own colours (bronze, steel, gold where it has them). A `LOOT` entry
  may carry a tint (r, g, b) for a tinted variant of an icon another entry uses.
- **Tests:** test/forge_data_test.dart (the kinds and grades, names and cards, icons, both file versions, every recipe's
  materials and items, the stones, Awaken and Enhance blocks, the forge in every game, the save).

## The forge: items crafted, Awaken by grade (decisions-log 249)

The owner, 2026-10-04: every item is made at the Smithy, and "setiap awakenning butuh item dengan grade yang berbeda untuk
next awakening" (each Awaken level takes items of its own grade). Every game plays by it: the forge-off build and
town.json's `awaken.byGrade` went in decisions-log 296, and `Game.byGrade`, a plain `Game()`'s way to the rule from
before the forge ("Awakening: recipes, caps and levels" above), in 321 with the rules from before the Towns.

- **The recipe by grade** (`kindRecipe(type)`): today's `awakenRecipe`, counted by kind, plus the type's own new kind
  (`forgeAwakenKinds`): Soldier and Knight an Amulet, Swordsman, Archer and Templar a Torch, Lancer 2 Spears, Priest 2
  Prayer Beads, Axeman a Prism, Wizard 2 Prisms. Awaken L takes that recipe in grade L (`gradeSet(type, L)`, `itemOf(kind,
  grade)`), each count times town.json `awaken.share` L ([1, 1, 0.667]) rounded up, at least 1 (`gradeCount`; the
  share's last digit is a rounding, so 3 × 0.667 is 2, 4 × 0.667 is 3):

  | Type | each level (Awaken 3 where it differs) | items I / II / III |
  |---|---|---|
  | Soldier | Sword 2, Shield 2, Boots 1, Bow 1, Gloves 1, Potion 1, Amulet 1 | 9 / 9 / 9 |
  | Knight | Sword 3 (2), Shield 3 (2), Boots 2, Gloves 2, Amulet 1 | 11 / 11 / 9 |
  | Swordsman | Sword 3 (2), Boots 2, Gloves 3 (2), Potion 2, Torch 1 | 11 / 11 / 9 |
  | Archer | Sword 2, Boots 1, Bow 4 (3), Gloves 3 (2), Torch 1 | 11 / 11 / 9 |
  | Lancer | Sword 2, Shield 2, Boots 4 (3), Gloves 1, Spear 2 | 11 / 11 / 10 |
  | Priest | Staff 2, Shield 2, Bow 2, Gloves 2, Potion 2, Prayer Beads 2 | 12 / 12 / 12 |
  | Axeman | Sword 2, Shield 3 (2), Boots 1, Gloves 2, Potion 2, Prism 1 | 11 / 11 / 10 |
  | Wizard | Staff 2, Bow 3 (2), Gloves 3 (2), Potion 2, Prism 2 | 12 / 12 / 10 |
  | Templar | Sword 2, Shield 2, Boots 2, Bow 1, Potion 3 (2), Torch 1 | 11 / 11 / 10 |

- **Level** (`itemLevel`): the grade sets the type holds in a row from grade I (`awakenNeeds(type, L)` is every set up to
  L), or from the level it kept (below). A grade-II item never stands in for a grade-I one, nor the other way. A Cap or a
  Ring never counts.
- **A save from before the grades** (decisions-log 272, the cut-over): its items were taken by the old rule (the recipe
  once more a level, all grade I), and no grade set holds them, since none has the type's new kind. So at the load each
  type keeps the level its items gave by the old rule (`oldItemLevel`), in `awakenKept` (`keptLevel(type)`, at most 3),
  and counts on from it: the next Awaken takes the next grade's set alone (`awakenNeeds` and `awakenShort` start past the
  kept level), and Bangkit 4-5 and Tempa bought at Awaken 3 stay valid. The old items stay on the type with the stats
  they had (grade I's numbers are the old constants) and count against nothing: past their grade-I caps they only block
  more grade I, like the items from before the caps. Items in the Bag are grade I: they go on a type within its grade-I
  caps, or sell. The w89 save keeps the priest, the axeman and the wizard at Awaken 5 with their Tempa, the archer and
  the Templar at 2; without the floor every type would read Awaken 0. The Army detail says it first, in grey: "Awaken 3
  (kept from old items)" (ui-hud.md "Army"). Saved as `awakenKept` by every by-grade game, an empty map too, so a save
  of the by-grade game is never read by the old rule again (a new game's stays empty: its grade-I items never make a
  level); a save without the key gets it from its items.
- **Caps** (`capOf`): per kind and grade, the grade set's count once the grade is open: at Awaken L the grades up to L + 1
  (grade I from the start, II at Awaken 1, III at 2), else 0. So a type holds at most its grade sets, today's recipe × 3
  less the trimmed third of grade III (the knight 31 items where today's takes 30). Refusals (`whyNot`): a kind outside
  the recipe `notInRecipe`; a grade not open yet `awakenFirst`; a full grade `maxed` (its cap never rises). The bow's
  reach rule is today's. The refusal's words by grade (`itemRefusal`): a grade whose slots open with an Awaken names it,
  its tooltip's own line ("Opens at Awaken 1" for a grade-II item, "Opens at Awaken 2" for grade III; `gradeOpensAt`), in
  the Bag's picker rows, the drop popup and the message window; the others as today's (`refusalNames`: "Awaken first" for
  a Cap or a Ring at its cap).
- **The Cap and the Ring** (`outsideAwaken`: the kinds no Awaken counts): every type takes them, one of the kind (any
  grade, `heldOf`) per Awaken level and one more, 1 to 4. At that cap a better grade goes on and swaps out the type's
  lowest-grade one, which goes back to the Bag (`swapOut`; `useItem`, and `priceWith` / `assignPreview` try it on the
  same way); the same grade or a lower one is refused (`awakenFirst` below Awaken 3, then `maxed`). With Enhance the
  lowest goes by grade, then by "+" ("The forge: Enhance" below).
- **What each grade does** (`Stats.upgraded(item, k)`): `k` is the item's own number, town.json `items.<key>.effect`
  (`Game.itemK`), read for every item, grade I too (its numbers are the constants from before the forge). Swords and
  staffs (attack ×), shields (+defence), boots (walk ×), bows (reach ×, the melee clamp as before), gloves (wait ×) and
  potions (+regen) by their grade's number; a healer's heal from a potion is `potionHeal` × its regen ÷ grade I's (3,
  4.8, 7.2), from a staff `staffHeal` × its bonus ÷ grade I's (3, 3.36, 3.84) (`healOf`), each times the beads'
  `healK`. The Cap's grade multiplies a new stat, `Stats.taken` (damage taken after the defence, 0.96 / 0.95 / 0.93,
  compounding; `Game._hurt` cuts by it after the Guard relic, as Sunder weakens a cut, and the Executioner's bared blow
  skips it); the Ring adds MP regen (+0.10 / 0.15 / 0.20 a second). The five new kinds' effects (Amulet, Beads, Torch,
  Spear, Prism): "The forge: the new kinds' effects" below. The knight's swords at Awaken 3, 3 + 3 + 2 by grade: ×1.25³
  · 1.28³ · 1.32² = ×7.137 (today's nine grade-I swords ×7.45).
- **What the rest reads by grade:** `awakenProgress` (the next grade set, have/need), `awakenShort(type)` (what the next
  Awaken still lacks: the Bag's red dot, "Awaken 2 from the Bag" and the Bag's pick, Carve's kept items,
  `craftItemNeed`), `bagLevel` (the grade sets the type and the Bag hold in a row).
- **Crafting items** (`extension Craft`, lib/town.dart): every item from its town.json `items` recipe ("The forge: data"
  above): grades I, II and III of the twelve Awaken kinds from their own materials and 20 / 60 / 250 gold, the Cap's and
  the Ring's 150 / 600 / 2,500 and the grade below. `itemRecipe(item)`,
  `itemCraftRows(item)` (each material, the item it takes, the gold: have / need), `whyNotCraftItem(item)` (the relics'
  order: game over, not in a Town, no recipe, a material, the item ("Need 1 Leather Cap"), the gold), `canCraftItem`,
  `craftItem(item)` (takes them, one into `inventory`, `Sfx.clear`, the event `ItemCrafted`: the battle log's "Crafted
  Steel Sword (60 gold)" with its icon, the telemetry's `itemCrafted`, counted in a wave record's `crafted` and
  `materialsUsed` and in `craftSpent`). No limit a visit, as for relics. For the Army detail and the Smithy's Items board
  (every grade at once, decisions-log 277): `canMake(item)` (how many the Bag pays for, wherever the game is), `whyNotMake(item)` (what the
  Bag is short of, outside a Town too), `smithyItems(grade)` (the grade's 14 in `Item` order) and
  `craftableItems(grade)`. A craft never adds to `matsSeen`.
- **Tests:** test/forge_awaken_test.dart (the counts, the table, levels from exactly the grade set, caps and when grades
  open, the Cap and Ring swap, every recipe's gold and take, refusals, `canMake`, Stats per grade, the Cap's cut on a
  blow, the event, the old recipe the sets build on), test/forge_army_detail_test.dart (the Army detail),
  test/forge_cutover_test.dart (the forge on by default, and the saves from before it: the kept levels).

## The forge: the new kinds' effects (decisions-log 251)

The owner, 2026-10-04: more item kinds, each with one clear job: a stat no item served (`Stats` had `hp`, `splash` and
the `dark` foe flag, which no item touched) or a troop type without an item of its own. Like "The forge: data":
`Game.statsOf` hands `Stats.upgraded(item, k)` an item's own number `k` (`Game.itemK`: its town.json
`items.<name>.effect`); without one (`Stats.upgraded(item)`) the five change nothing. Each item multiplies, one at a time in the order taken (`upgrades[type]`), as
the seven do.

| Kind (grades I / II / III) | What one does (`Stats.upgraded`) | Whose Awaken recipe takes it |
|---|---|---|
| Amulet / Silver Amulet / Gold Amulet | max HP ×1.08 / 1.10 / 1.12 (`hp`, rounded at each one). At an Awaken level the awakening's HP (`awakenHp` of the base a level) is times what the amulets added, so both count (`statsOf`) | Soldier, Knight |
| Prayer Beads / Holy Beads / Saint Beads | a healer's heal ×1.12 / 1.15 / 1.18 (`dmg`, and `Stats.healK` the beads' product); a potion's and a staff's added heal (`potionHeal`, `staffHeal`) is times `healK`, so the order items came in still doesn't matter. The holy damage it does to the undead (`holyShare` of its heal) grows with it. A type that doesn't heal: nothing | Priest |
| Torch / Holy Torch / Sun Torch | its blows on the undead ×1.12 / 1.15 / 1.18 (`Stats.darkK`). The one new step in `Game._hurt`: right after Giant Slayer, before defence, a blow is times its striker's `darkK` when the foe is `Stats.dark` (every skeleton, both necromancers): any blow the troop strikes (its attack, a splash, a skill), never a monster's | Swordsman, Archer, Templar |
| Spear / Winged Spear / Royal Spear | a melee fighter's reach ×1.15 / 1.18 / 1.22 (`range`) and its own reach cap ×the same (`Stats.reachCap`, `meleeMaxRange` 27.2 to start), up to the ceiling below. A bow, the Hero's aura (`Stats.boosted`), Hawk Feather and `canUse`'s reach refusal stop at `reachCap`. A shooter or a healer: nothing | Lancer |
| Prism / Arcane Prism / Royal Prism | splash ×1.15 / 1.18 / 1.22 (`splash`), only for a type with splash (the Axeman's 16, the Wizard's 20), up to the ceiling below; any other: nothing | Axeman, Wizard |

- **The ceilings** (`Game._ceilings`, after the items compound; limits the owner may change, a value under 1 keeps the
  default). The prism's: town.json `items.prism.splashMost` 1.5 (`ItemRecipe.splashMost`, default `prismSplashMost`): a
  type's splash stops at 1.5 × its base, the Wizard's 20 at 30 (its whole set 2 + 2 + 2 would be ×2.74, 54.8, a circle
  near the field's height), the Axeman's 16 at 24 (its 1 + 1 + 1 would be ×1.66); Wide Blows' splash (+) comes after it.
  The spears': town.json `items.spear.reachMost` 1.5 (`ItemRecipe.reachMost`, default `spearReachMost`): `statsOf` stops
  a type's reach at 1.5 × its base reach and its reach cap at 1.5 × `meleeMaxRange` (40.8). A Lancer's 22 goes to 25.3 with a Spear, 29.9 with a Spear and a Winged
  Spear, and stops at 33; its whole set (2 + 2 + 2) would be ×2.74 (60, near an archer's 64). Hawk Feather and the aura on
  top stop at 40.8.
- **Stacking:** a Priest with two beads of each grade heals 12 × 1.12² × 1.15² × 1.18² = 27.7; an Archer with one torch of
  each grade does ×1.52 to the undead; a Wizard with two prisms (23 → 26.5) and an Arcane Prism reaches its ceiling, 30.
- **The card** (`itemEffect`): the file's number ("+8% max HP", "+12% heal", "+12% damage to the undead", "+15% melee
  reach", "+15% splash area"); over a type, "Now: n/cap" with its stat against its base (`Stats.statOf`; the torch's is
  `darkK`).
- **Tests:** test/forge_kinds_test.dart (each kind alone at each grade, stacking, the Amulet at Awaken 1 and on a troop
  in the field, the beads' heal and holy damage whatever the order, the torch only on undead foes and never a monster's
  blow, the spear's clamp, ceiling and patched ceiling with Hawk Feather and the aura, the prism only with splash and its
  ceiling, and `Stats.upgraded` without a number leaving them alone).

## The forge: Enhance (decisions-log 255)

The owner, 2026-10-04: late in a run an item can be enhanced, with stones the Smithy makes from the rarest trophies. Like
the rest of the forge, every game enhances (`Enhance.enhanceOn`, a game without the Towns' off switch, went in
decisions-log 321). The rules are lib/enhance.dart's
`extension Enhance on Game`, the numbers town.json `enhance` ("The forge: data" above). The Smithy's Enhance tab, the
Bag's stack cells and the tint are ui-hud.md's ("The Smithy", the Bag's "Enhanced stacks").

- **When** (`enhanceOpen`): once wave 30 is won (`enhance.from`): past it, or on it between waves, the same form of rule
  as the Shop's `storeOpen`. It is the one place the rule lives: the Smithy's strip greys its Enhance segment by it,
  and every refusal below reads it.
- **The stones** (`stoneRecipe`, `stoneCraftRows`, `whyNotCraftStone`, `canCraftStone`, `craftStone`): Mithril (Evil
  Eye 1, Iron Scrap 2, Grave Steel 1; 1,000 gold) and Starmetal (Soul Orb 1, Lich Orb 1, Mithril 1; 3,000 gold), made
  at the Smithy once Enhance is open, one into `materials` (never into `matsSeen`). Refused in the Smithy's order: the
  game over, not in a Town, no recipe (not a stone), "Opens after wave 30" (`CraftWhy.closed`), a
  material short ("Need 1 Mithril"), the gold. The event `StoneCrafted`: the battle log's "Crafted Mithril (1,000
  gold)" with its icon, the telemetry's `stoneCrafted`, counted in a wave record's `crafted`, `materialsUsed` and
  `craftSpent`.
- **A step** (`enhanceCost(plus)`, `enhanceRows(plus)`, `whyNotEnhance(item, plus)`, `canEnhance`, `enhance(item,
  plus)`): one item in the Bag at +n goes to +n+1 for the step's stone and gold, any item and any grade, the Cap and the
  Ring too, up to +5 (`enhance.most`, `plusMost`). It always works: nothing rolls dice.

  | Step | Stone | Gold |
  |---|---|---|
  | +1 | Mithril | 500 |
  | +2 | Mithril | 1,000 |
  | +3 | Mithril | 1,500 |
  | +4 | Starmetal | 2,500 |
  | +5 | Starmetal | 4,000 |

  From +0 to +5 an item takes Evil Eye 5, Soul Orb 2, Lich Orb 2, Iron Scrap 10, Grave Steel 5 and 20,500 gold, the
  stones' own included. Refused in this order: the game over, not in a Town, "Opens after
  wave 30", none at that "+" in the Bag ("Need 1 Royal Sword"), already at +5 ("Max: +5", `CraftWhy.top`), the stone
  ("Need 1 Starmetal"), the gold. Its gold counts in the visit's `craftSpent`. The event `ItemEnhanced`: the battle
  log's "Enhanced Royal Sword to +3 (1,500 gold)" (`Words.enhance`) with the item's icon, the telemetry's `itemEnhanced`, its stone in a
  wave record's `materialsUsed` and its gold in `craftSpent`.
- **What a "+" does** (`enhancedK(item, k, plus, per)`, read by `Game.itemK(item, plus)`): each step adds `enhance.per`
  (a tenth) of the item's own bonus. A factor becomes 1 + (k − 1)(1 + 0.1 × plus), so a gain grows and a cut deepens:
  Royal Sword ×1.32 → ×1.352 / 1.384 / 1.416 / 1.448 / 1.48 at +1 to +5, Royal Gloves' wait ×0.75 → ×0.625, Gold Amulet
  ×1.12 → ×1.18, Royal Helm's damage taken ×0.93 → ×0.895. A flat one (`flatKinds`: the shield, the potion, the ring)
  becomes k × (1 + 0.1 × plus): Royal Shield 6 → 9, Elixir 12 → 18 HP/s, Royal Ring 0.2 → 0.3 MP/s. +0 is the number
  itself. A potion's and a staff's heal on a healer follow their number (`Stats.upgraded`), and the spears' and the
  prisms' ceilings still stop them.
- **Stacks:** each (item, "+") is its own stack and its own Bag cell: +0 in `inventory`, +1 to +5 in `enhancedBag`
  (`bagOf(item, plus)`; `enhancedHeld`, in `Item` order, then by "+").
- **On a type** (`useItem(item, type, plus:)`): one from its stack goes on the type. `upgrades` still lists every item, so
  the Awaken counts, levels, caps and the price never change with a "+"; `upgradePlus` holds the "+" of the type's
  enhanced copies, per item, highest first (`plusesOn(type, item)`: one a copy, 0 for the rest). `statsOf` gives each
  copy its own number (`_itemsOn`; the items multiply and add, so which copy is which doesn't matter).
- **At the cap** (`swapOut(type, item, plus)`): an item whose grade's slots are full goes on when its "+" is above the
  type's lowest copy of it, which comes back to the Bag at its own "+"; an equal or lower one is refused as before
  (`maxed`, or `awakenFirst` while an Awaken still raises the cap). The Cap's and the Ring's chain stays: at their
  kind's cap the type's lowest by grade, then by "+", swaps out when the new one is above it, so a higher grade always
  wins (a Leather Cap +5 never swaps out a Steel Helm). `priceWith` and `assignPreview(item, type, plus:)` try it on
  the same way. A swap adds no item, so the price stays.
- **The Shop** (`sellPriceAt`, `whyNotSellAt`, `sellAt`): an enhanced item sells at the market's price for that exact
  product ("Towns: the market" below, decisions-log 326): each step's gold and its stone (the stone's materials and
  gold) in its cost, the enhanced column's margin; a Royal Sword +1 in the first Town 3,192, each piece of a stack at
  its own step. Until then the item's price plus half of what its steps cost (a Royal Sword +5 14,000). A `storeSold` of
  one carries its `plus`.
- **Saved:** `bagPlus` and `upgradePlus` ("Saved" below).
- **Tests:** test/forge_enhance_test.dart (each step's number and cost, the stones, +5 the most, every step works,
  the refusals, an enhanced item on a type, the swap at the cap and the Cap's chain, the Shop's price, the events, the
  save and a save without the keys).

## The Wishlist (decisions-log 282, 300, 302, 303)

The owner, 2026-10-09: the player puts the Smithy's products they mean to make on a list, per troop type, as a target.
A wish only marks and orders: nothing crafts or gives by itself (crafting and giving stay the player's taps). It is
set from the Smithy's item page and from each type's Army detail, and both edit the one list. Then (decisions-log 300):
"user harusnya bisa whitelist semua item yang yang dibutuhkan untuk enhance 1 army type, misal knight butuh 5 item maka
ke 5nya akan langsung di whitelist beserta quantitynya" (the player wishes at once for every item one type needs for its
next Awaken, each with its quantity). Then (decisions-log 302): "header yang army itu bisa di ganti ke item/ relics
yang lain yang bisa di buat" (a line's head need not be a troop type: any item or relic the Smithy makes), and the list
became the Smithy's first tab. Then (decisions-log 303): "wishlist yang ada di tabs smithy itu seharusnya adalah tempat
user untuk merealisasikan wishlistnya jadi harusnya tidak ada perubahan wishlist di situ. penambahan wishlist itu
dilakukan di tempat lain misalkan di page army,bags, dan smithy selain tab wishlist" (the tab is where wishes are made,
a row per thing to make with its materials have/need and whether it is ready; wishes go on from the Army detail, the Bag's
pages and the Smithy's other tabs, and come off from those and from the tab's rows). The rules are lib/wishlist.dart's
`extension Wishlist on Game`; the pages are ui-hud.md's ("The Smithy", "The Bag", "Army").

- **When:** in every game, where the Smithy makes items (`wishOn`, a game without the Towns' off switch, went in
  decisions-log 321).
- **What:** a type's wishes are items only (a small relic is worn by one troop, not by a type, and the Enhance stones go
  on no type; free lines take relics, below). `canWish(type, item)`: a troop type and an item with a Smithy recipe (`itemRecipe`) that the type can ever take: by
  grade a kind its Awaken counts (`kindRecipe`) in any of the three grades, or the Cap or the Ring (`outsideAwaken`),
  which every type takes; where Awaken doesn't go by grade, its recipe's items. So the knight can wish for 21 products
  (Sword, Shield, Boots, Gloves and Amulet, Cap and Ring, each in three grades), never a Bow or a Staff.
  `wishable(type)` lists them in `Item` order (the Army detail's picker, by grade).
- **The list:** `Game.wishlist`, type → its wishes in the order put on, each once, each with how many the type is to
  HOLD (its goal, `wishGoal`; decisions-log 300). `wish(type, item, [goal])` (false when it can't or already is; the goal
  one more than the type holds when none is given: a chip's tap), `unwish` (the last one leaves no entry), `toggleWish`
  (whether it is on after), `wishesOf(type)`, `wishersOf(item)` (the types, in the troop types' order, done ones too).
  No limit per type.
- **How far** (decisions-log 300): `wishCount(type, item)` is (have, need): what the type holds now (`countOf`, read
  live, so it is exact whichever way an item went on: the Bag, the drop popup, the Smithy) at most the need, and its goal.
  `wishDone` once it holds the goal. The open wishes are the ones not done: `openWishersOf(item)`, `wished(item)` (some
  open wish: the Items board's star and order), `wishedItems` (each once, in `Item` order). A craft changes no count
  (the item is in the Bag, not on the type).
- **A whole set** (decisions-log 300): `wishSetOf(type)` is every item the type's next Awaken still lacks
  (`awakenShort`) with the grade set's count as its goal (`awakenNeeds` of that level), in the set's order; empty at the
  top. `wishSet(type)` puts it on (an item already on keeps its place and holds at least the set's count; the rest go on
  last), `setWished(type)` whether it is all on, `unwishSet(type)` takes the set's items off (the type's other wishes
  stay), `unwishAll(type)` every wish of the type. The knight at Awaken 0 holding one Sword: Sword 1/3, Shield 0/3, Boots
  0/2, Gloves 0/2, Amulet 0/1. Set from the Army detail's "Wishlist all" (the Wishlist tab's "Add" picker had it from
  decisions-log 302 until 303; "Add a set" on the Items tab's block before). One item of it from the Army detail's needs
  row "+" (`wish` with the set's count; decisions-log 303) or its Wishlist section's picker; the Smithy's item page no
  longer wishes for a type (its chips went in decisions-log 303: a wish put on there is a free line). A group's Remove on
  the Wishlist tab is `unwishAll`.
- **Done** (`_wishGiven`, from `useItem`): a met wish stays on the list, shown done, until the type's next Awaken: then
  every done wish of the type drops off (the set ends there; nothing rolls on to the next Awaken, whose set is one tap to
  add). A met wish for a kind no Awaken counts (the Cap, the Ring: `outsideAwaken`) drops off at once.
- **Free lines** (decisions-log 302): `Game.wishFree`, product → how many the Bag is to HOLD, in the order put on: any
  product the Smithy makes, for no type (`canWishFree`: an item with a recipe, or a small relic in play with one; not a
  stone). `wishFreeAdd(kind, [more])` puts it on for `more` (at least one) more than the Bag holds now, last (false when
  it can't, or an open line has it); `wishFreeMore(kind, by)` asks more or fewer, never under one more than the Bag holds
  (a product's page's "-" and "+"; the Smithy's item and relic pages and, since decisions-log 303, the Bag's); `unwishFree`
  (a row's ✕, the page's "Remove"), `unwishFreeAll` (the "For the Bag" group's Remove); `toggleFree` (on for one more, or
  off; the Wishlist tab's picker until decisions-log 303).
  `freeCount(kind)` is (have, need), the Bag's count (`inBag`, read live) at most the goal; `freeDone` once the Bag holds
  it. A met line counts as none at once (`freeWishes`, the open ones, are all that is shown, starred or saved) and drops
  off (`_wishSweep`) at the craft that meets it (`Craft.craft`, `craftItem`) and, for one met another way (a chest's
  relic), when the Town is left (`leaveTown`). `freeParts(kind)` is what its recipe takes, each material then each item
  (not its gold), and `freeNeed(kind, part)` that part for the rest of the line, (the Bag's at most the need, the recipe's
  count times the ones still to make). An item on a free line is `wished` like a type's (the
  Items board's star and order), a relic on one carries the star on the Relics board (`freeWished`).
- **What a wish lacks:** `wishShort(item)`, the item's recipe rows (`itemCraftRows`) the Bag is short of, each
  material and item with have / need, then the gold; none: the Bag pays for one (`canMake`), wherever the game is (the
  Smithy page's "Ready to craft" / "Missing: …"). The recipe is the same whoever wishes for it.
- **The rows** (decisions-log 303; the Wishlist tab's): `wishRows`, one per open wish (the owner: "1 baris per
  barang"), each type's in the troop types' order (each type's in the order put on), then the free lines: its type
  (none for a free line), its product, `need` (how many it still wants: the goal less what the type or the Bag holds),
  `make` (how many are still to craft: a type's `need` less what the Bag already holds, so a Shield in the Bag is one
  less to make for a type; a free line's `need`, the Bag's count being what it waits on) and `parts` (the recipe's rows,
  `itemCraftRows` or `craftRows`, each its kind, the gold none, with the Bag's have and the row's need times `make`).
  `wishRowShort(row)` is what the Bag lacks for them (each part short and by how many; none: "Ready"). A met wish has no
  row; a type's row with nothing to make (the Bag holds them) has no parts and waits on its Give.
- **The materials:** `wishMats`, every material an open wish's recipe takes (held or short; a free relic's too): the
  Bag's Materials and the Shop's Buy mark them (decisions-log 300; the Smithy shows no materials' grid since
  decisions-log 302: its recipe rows and the Wishlist tab's rows say what each takes), and a material's tooltip
  ends "Needed for your wishlist" (`Words.neededForWishlist`).
- **The Smithy's order:** the Items board shows a grade's items with an open wish first, then the rest, each part in `Item` order
  (`smithyItemOrder`, smithy_page.dart). The board's sections and pages are as many as before: no item moves to another
  grade, and nothing is shown twice.
- **Saved** as `wishlist` (type → item name → goal, in order; its `free` the open free lines, product name → goal, in
  order), only with some wish ("Saved" below).
- **Tests:** test/wishlist_test.dart (who can wish for what, the list's edits, the counts read live, a whole set on and
  off, done and the Awaken's drop, the board's order, what a wish lacks and the materials, free lines and their drop,
  the rows and what they lack, the save with its free lines, a list from before the goals and an old save, nothing
  crafted or given by itself),
  test/wishlist_ui_test.dart and test/smithy_wish_ui_test.dart (the pages).

## Towns: the Tavern (decisions-log 266-268)

The owner, 2026-10-07: "terus di tavern ini aku mau ada feature user bisa beli temporary boost misal 500 gold untuk party
yang bisa meningkatkan 2 wave atk+ def untuk semua jenis troops, nah ini di buat jadi gacha juga opsi yang di tawarkan di
tavern" (the Tavern sells temporary boosts for the party, e.g. 500 gold for two waves of attack and defence for every
troop type, offered gacha-style), and on 2026-10-08: "500 adalah contoh saja, kalau bisa jangan terlalu mahal untuk di
kota kota awal" (500 was only an example; not too dear at the first Towns), "Sebanyak gold cukup" (buy as many as the
gold allows), "semua buff tavern adalah temporary buff untuk 2 wave setelahnya" (every Tavern boost lasts the two waves
after it), DEF as less damage taken, and the game's existing icons. On since decisions-log 268 (built dark in 266 and
267): every Town has its Tavern; its own switch and the `--dart-define=TAVERN=false` build are gone (decisions-log 296), and every game has the Towns since decisions-log 321. The rules are lib/tavern.dart's `extension
Tavern on Game`, the numbers town.json `tavern` (`TownRules.tavern`, `TavernRules`). The Tavern's page in the Town's
book (decisions-log 267) is ui-hud.md's "The Tavern": the offers, Reroll, the boosts running and Buy; the boosts in
battle (decisions-log 268: their chips under the wave meter, the troops' burst back from the Town, the log's lines) are
ui-hud.md's "The Tavern in battle"; the guide's K23 and its "Towns" topic name it.

- **The catalogue** (`Boost`, town.json `tavern.boosts.<kind>`; `boostNames`; each kind's `rarity`, its multipliers and
  `who`). Every kind runs for the next `waves` 2 waves fought; "Damage" is a healer's heal too.

  | Kind | Name | Rarity | What it does |
  |---|---|---|---|
  | `feast` | Feast | Rare | Damage ×1.20, damage taken ×0.85 (the owner's atk + def) |
  | `ale` | Strong Ale | Common | Damage ×1.15 |
  | `stew` | Hearty Stew | Common | Max HP ×1.20 |
  | `broth` | Iron Broth | Common | Damage taken ×0.88 |
  | `tea` | Spiced Tea | Common | Attack speed ×1.12 (the pause between attacks ÷1.12; the 0.3 s floor holds) |
  | `rations` | Travel Rations | Common | Damage ×1.06, damage taken ×0.94, max HP ×1.06 (a little of everything) |
  | `toast` | Lucky Toast | Common | Kill gold ×1.30 |
  | `mage` | Mage's Brew | Rare | MP regen ×1.60 |
  | `plate` | Champion's Plate | Epic | Damage ×1.40, attack speed ×1.15, on ONE troop type (`"who": "type"`, rolled with the offer among the types alive) |
  | `watch` | Watchman's Brew | Epic | The first monster over the back line each wave costs no life (`leaks` 1) |
  | `banquet` | King's Banquet | Legendary | Damage ×1.30, damage taken ×0.75, max HP ×1.25, attack speed ×1.10 |

  Travel Rations was "longer but weaker" (five waves) in the design; with every boost two waves it is a cheap Common
  with a little of everything. Every kind has the same length (`waves`, one number for all).
- **The roll** (`_rollTavern`, from `Towns.enterTown`): `offers` 3 different kinds, on `Game.tavernDice` (its own dice;
  not saved, a probe seeds it with seed + 800), so no other die moves. Each slot draws a rarity by `odds` (Common 0.55,
  Rare 0.30, Epic 0.13, Legendary 0.02, each a share of their sum) and a kind of it; a rarity with none left steps down,
  then up (the Boss Chest's way). Never offered: a kind running, a kind already in the roll, a Legendary before wave
  `legendFrom` 30, a one-type kind with no troop alive. The run's first Tavern (`Game.tavernSeen` false) has the Feast in
  its first slot (`firstFeast`). The pity: `Game.tavernDry` counts the visits in a row whose roll had no Epic or better;
  the `pity` 4th has an Epic in its last slot when none came before it. The offers are saved with the Town and go when
  it is left.
- **The price** (`boostPrice`): the rarity's `price.k` (Common 0.3, Rare 0.5, Epic 0.9, Legendary 1.5; a kind's own `k`
  over it) × the Tavern's purse of the wave won (`TavernRules.purseAt`: the game's purse before rounding, tempa.dart's
  `purseRaw`, × `early` 0.5 at wave 0 rising in a line to × 1 at `fullFrom` 20, since early waves pay well under the
  purse), rounded to 50 (to 1,000 from 10,000), at least `least` 50. A reroll (`tavernRerollPrice`) is `reroll.k` 0.1
  purse (at least 50, rounded the same) × `rise` 2 for each one bought before it in the visit.

  | Wave won | Common | Feast (Rare) | Epic | Legendary | First reroll |
  |---|---|---|---|---|---|
  | 6 (the first Town at the earliest) | 50 | 100 | 150 | (from wave 30) | 50 |
  | 7 | 50 | 100 | 200 | | 50 |
  | 12 | 150 | 250 | 500 | | 50 |
  | 20 | 450 | 800 | 1,400 | | 150 |
  | 30 | 1,100 | 1,850 | 3,300 | 5,550 | 350 |
  | 50 | 4,750 | 7,950 | 14,000 | 24,000 | 1,600 |
  | 70 | 18,000 | 29,000 | 53,000 | 88,000 | 5,850 |
  | 86 | 47,000 | 78,000 | 140,000 | 234,000 | 16,000 |

- **Buying** (`whyNotBuyBoost(i)`, `buyBoost(i)`): every offer once ("Sold"), as many as the gold allows (no limit a
  visit). Refused in this order (`BoostWhy`, `boostRefusals`): the game over, not in a Town with the Tavern ("Only in a
  Town"), bought already ("Sold"), the gold ("Not enough gold"). A buy takes the gold at once, the boost runs at once
  (`RunningBoost`, `Game.boosts`) and the living troops are refit (HP gained comes with it); `Sfx.clear` and the event
  `BoostBought`. **Reroll** (`whyNotRerollTavern`, `rerollTavern`): the unbought offers are rolled again in their slots
  (no first Feast, no pity), the bought ones stay; refused with every offer bought ("Sold out") or the gold short; the
  trace event `TavernRerolled`.
- **What a boost does** (`_boostStats`, the last step of `Game.statsOf`, after the oath; units-and-combat.md): the product
  of the multipliers of every boost running that works on the type, each stat's stopped by `most` (Damage, Max HP,
  Attack speed, MP regen ×1.8 at most, kill gold ×2.0, damage taken ×0.6 at least: the owner's no-limit buys made the
  cap a must). On top of the items, awakening, Tempa, the heavies' buff, the Pusaka and the oath, and under the Hero's
  aura (which multiplies the boosted stats). "Damage taken" multiplies `Stats.taken` (cut after the Guard relic, as the
  forge's Helm: every troop has it, shields or none); `def` and the blow's floor stay. A boost is a stat multiplier,
  never a relic factor: the relics' cap 3.0 neither counts it nor cuts it. A troop bought while a boost runs has it.
  Lucky Toast multiplies the kill gold at the pay line (after the Bayangan Thrift; not the won wave's bonus, not
  Plunder's extra: `_boostGold`); Watchman's Brew forgives the wave's first monster over the back line (`_boostLeak`: it
  still goes, no life is lost, the event `BoostSaved`).
- **The countdown** (`_boostWaveEnd`, at each wave's end, won or lost): one wave fewer each; a boost at 0 ends (the event
  `BoostEnded`) and the troops are refit, HP over the new max only capped (never killed). Bought between waves n and
  n+1, a boost runs through waves n+1 and n+2. A Town comes at least 5 waves after the last, so nothing runs into the
  next Town (unless `schedule.minGap` is under 2; then a kind still running is left out of that Town's rolls).
- **Probes:** `Game.tavernPolicy` ('top': the best offer it can pay, the highest rarity, then the dearest; 'all': every one
  it can pay in that order), from `_townByPolicy` before it leaves a Town; null: the player.
- **Events and telemetry** (telemetry.md): `boostBought` and `tavernRerolled` passed on, `townLeft.tavern`, a wave's
  `gold.tavernSpent`, `boostSaved` and its start's `boosts`; the battle log's lines "Feast: +20% damage, 15% less damage
  taken (2 waves)", "Feast ended" and "Watchman's Brew: no life lost".
- **Saved** ("Saved" below): the boosts running and the Town's Tavern keys.
- **Tests:** test/tavern_test.dart (town.json's block, the prices, the roll, the odds, buying, rerolling, the stats, the
  countdown, the gold, the leak, the save, the telemetry, the probe policy).

## Towns: the market (decisions-log 326)

The owner, 2026-10-12: forged goods are a way to earn gold, at 1.3x to 4x their cost; selling one product again and
again brings its price down, so the player sells a mix, and the price comes back after 2-3 Towns. lib/market.dart.

- **The Town's identity** (`TownIdentity`, `townIdentities`, `identityOf(n)`): by the Town's number in the run
  (`Game.townCount`, raised by `enterTown`; no dice, so seeded runs play as before). Six, two a tier, the two of a tier
  taking turns: Towns 1-3 Millbrook (a farming village: Boots, Potion, Gloves, Prayer Beads) and Willowmere (a
  riverside village: Bow, Spear, Torch, Shield), summer; 4-6 Ironvale (a mining town: Shield, Cap/Helm, Gloves,
  Amulet) and Ambergate (a harvest market: Potion, Staff, Ring, Prism), autumn; 7 on Frostgate (the royal capital:
  Sword, Cap/Helm, Ring, Amulet) and Highspire (a temple city: Staff, Prayer Beads, Torch, Prism), winter. The prices
  read `marketTown`: the Town the player is in, else the next. Its look: ui-hud.md "Town".
- **HPP** (`costOf`, `hppOf`): what a product cost to make, its parts at what the Shop pays for them (`materials`'
  `sell`: the owner's (R)) and its gold: an item's recipe (an item it takes at its own cost), each Enhance step's gold
  and stone (a stone's own materials and gold, a Mithril inside a Starmetal), a small relic's recipe. A Sword: 2 Bone
  Shards and 2 Orc Teeth (60) and 20 gold, 80.
- **The fresh margin** (`freshMargin`): town.json `market.towns`, a row a Town number (the last row for every Town past
  them): grade I, II, III and an enhanced item (+1 to +5); a small relic reads its tier (Basic I, Strong II, Mighty
  III). A kind the Town wants x`want` 1.3; kept in `floor` 1.3 .. `top` 4.0.

  | Town | Grade I | Grade II | Grade III | Enhanced |
  |---|---|---|---|---|
  | 1-3 | 3.0 | 2.2 | 1.6 | 1.4 |
  | 4 | 2.4 | 2.4 | 2.2 | 1.8 |
  | 5 | 2.0 | 2.4 | 2.4 | 1.9 |
  | 6 | 1.6 | 2.8 | 2.6 | 2.0 |
  | 7 on | 1.3 | 2.0 | 3.0 | 2.2 |

  The early Towns pay well for beginner goods, the late ones for high-class goods; a beginner item in a late Town stays
  at the floor.
- **The price** (`marketPrice`, `sellPrice`, `sellPriceAt`): the gold at the floor and the parts at the margin,
  round(gold x 1.3 + parts x margin), so never under 1.3x the HPP: any margin over 1 on the gold would print gold (buy the
  parts, forge, sell). A Sword in Millbrook 206 (20 x 1.3 + 60 x 3.0), Boots there 182 (x3.9); a Royal Sword in
  Frostgate 774 (x3.9), +2 there 8,293.
- **Pressure** (`Game.market`: a product's key → its pressure; `marketKey`: an item's name, `<name>+<plus>` for an
  enhanced one, `relic:<name>`, `mat:<name>` for a material bought): each piece sold adds 1, up to `most` 24. The margin
  is floor + (fresh - floor) x (1 - (pressure / 24)^`curve` 1.5): gentle at first, the floor at 24, never under it.
  Each exact product its own: a Sword, a Sword +2 and a Shield apart. A stack sells each piece at its own step
  (`marketSum`).
- **Recovery** (`enterTown`): each new Town takes `recover` 10 off every pressure (24 → 14 → 4 → gone: fresh in the
  third Town).
- **The materials** the Shop sells (`marketMatPrice`, `buyPrice`): `shopMatPrice` x (1 + `matRise` 0.10 x the ones
  bought, a Trophy `trophyRise` 0.25), rounded up to 5, at most 24 counted; the same recovery. Slime Gel 25, 30, 30,
  35; an Evil Eye 750, then 940. So buying the parts to forge and sell pays less each time.
- **The Sell page's words** (`marketWord`): "Hot in <Town>" for a kind it wants whose fresh margin is 2 or more,
  "Flooded: price falling" once a product is past half way to the floor; ui-hud.md "The Town's Shop".
- **town.json `market`**: `floor`, `top`, `want`, `most`, `curve`, `recover`, `matRise`, `trophyRise`, `towns` (rows of
  four margins; anything else keeps the default and is noted in `skipped`).
- **Events** (telemetry.md): `storeSold` carries `margin` (the first piece's, 2 decimals) and `pressure` (before the
  sale) for an item and a small relic; `townEntered` its `n` and `identity` (`eventVersion` 14).
- **Saved** ("Saved" below): `market`, and the Town count in `town`.
- **Tests:** test/market_test.dart (the identities, HPP, the prices by grade and Town, the pressure and the floor, the
  recovery, the materials, the words, the save and an old save's count, town.json's block), test/town_identity_test.dart
  (each identity on screen).

## The store ("Toko", on screen "Shop", #63)

The owner: "tambahkan fitur untuk beli di dalam store dengan menggunakan gold yang didapat dalam permainan;
item yang bisa dibeli semua item yang di drop oleh monster; ada beberapa artefak yang hanya bisa dibeli lewat
store dan itu harganya sangat mahal dan efeknya juga sangat overpower", and "harga item di dalam store itu
sangat mahal dan user juga bisa jual item yang dia dapat dari battle ke store, hanya dibuka ketika player
sudah melewati wave 15". The rules are `lib/store.dart` (a part of game.dart, `extension Store on Game`); the
page is a Town's Shop tab (ui-hud.md "The Town's Shop"; the field's own Shop tab of a game without the Towns, the
Toko, went in decisions-log 296). Each of the owner's choices (decisions-log 99) is one constant or switch
there. The economy they were weighed against was measured with the full-economy auto-player (#41, below).

- **When:** `storeOpen` once wave `shopFrom` is won (`wave > shopFrom`, or wave `shopFrom` and no wave on).
  `shopFrom` is town.json's `shop.from` (1 as shipped: a Town's Shop is open in every Town, decisions-log 253; 237
  read it, at `storeFrom` 15); the "locked" refusal says it (`storeWhy`: "Opens after wave <shopFrom>"). Awaken 4-5,
  Forge and Recall (the Army detail's) keep `storeFrom` 15 (`armyBuysOpen`, `_armyClosed`: "Opens after wave 15").
  The "VICTORY!" line that the Shop opened (`shopJustOpened`) is said only when `shopFrom` is over 1. Derived from the wave, so nothing is saved for it. `storeMidWave` false (the owner: between waves only): during a
  wave it is open but buys and sells nothing ("Only between waves"), even with the game paused (#93).
  The Shop page holds the auto start while it is open between waves, so the 5 s countdown is no race (so do
  Tas and Settings, #93; every page but the Army's).
- **What it sells** (only in a Town, below): the 5 epik Pusaka (`Relic.store`) while the shelf is open (`shelfOpen`:
  not with the chest on, "Peti Bos" above), and the materials that have dropped ("The forge: the Town Shop" above);
  never an item or a small relic, which the Smithy makes (`storeGoods` still names the 7 items and the 4 dropped relics
  the field's Toko sold until decisions-log 321). A Pusaka goes to the Gudang at ★1
  (`inBag` counts it 1 there), one of each. It never sells a Langka, a new Epik (`store` false: batches E-1P's ten and E-2P's seven) or a Legenda; one
  in the Gudang sells back for half of `langkaPrice` 16,000 (a new Epik: of its own `epikPrice` 25,000, so 12,500; Dragon Crown: of `legendaPrice` 40,000). An old save's copy past ★3 pays back `copyRefund` of the same price. An oath never sells (`inBag` 0).
- **Prices** (`buyPrice(kind)`; `storeBought[kind]` counts this game's purchases of each kind, and each one
  raises that kind's next price; selling never lowers it; a new game starts at the base):

  | Goods | Base | Each one bought adds | Sells for (`sellShare` 50% of base) |
  |---|---|---|---|
  | a Pusaka (`artefactPrice`) | Grail of Immortality 24,000; Dragon Heart 30,000; Void Eye 36,000; God's Thunder 40,000; Dawn Star 40,000 | ×`artefactRise` 1.5 (bought again after selling it) | half its base, its stars gone with it |

  A small relic and an item sell back at the market's price ("Towns: the market" above, decisions-log 326; until then
  half its craft gold, and the `shop` block's `itemSellShare` of its `itemPrice`, 1,000, decisions-log 233). The field's Toko sold an item at `itemPrice`
  2,000 (+200 a buy) and a dropped relic at `relicPrice` 8,000 (+1,600); both went with the rules from before the
  Towns (decisions-log 321). The owner doubled the design's prices and raised selling from 20% to half.
  Measured income (#63, on the kill gold before #83): about 1.1k a wave at wave 15, 2–2.7k after wave 30, with
  18k banked by wave 40 and 41k by wave 50 when nothing else is left to buy. Since #83 the kill gold grows 5% a
  wave (units-and-combat.md "Kill gold"): a wave cleared pays about 1k in kills at wave 15, 4.6k at 30, 8.8k at
  40 and 17.6k at 50, and the auto-player banks the Grail's 24,000 around wave 30 (decisions-log 119).
- **Buying:** `buy(kind)` takes `buyPrice` in gold, adds one to the bag and to `storeBought`, `Sfx.kill`
  (the coin). `whyNotBuy(kind)` → `StoreRefusal` (`storeRefusalNames`, English since decisions-log 187): `locked`
  "Opens after wave <shopFrom>" (`storeWhy`, "When" above), `midWave` "Only between waves", `over` "Game over", `owned` "Owned" (a Pusaka already owned:
  a purchase that does nothing is a trap; its card's Buy reads "Owned ★2", its shelf slot "★2" and "Owned" for the
  price, decisions-log 151), `shelf` "Boss Chest only" (a Pusaka with the shelf closed, or a Langka), `gold` "Not
  enough gold", `notSold` "Not for sale" (a material not seen to drop yet, an item, a small relic; decisions-log 248),
  and first of all `town` "Only in a Town" (below); refused, nothing changes and `Sfx.error` plays.
- **Selling:** `sell(kind, [n])` sells up to n from the bag (all there are when fewer) for `sellPrice(kind)`
  each. Only the bag sells: an item given to a type is part of its awakening, caps and price, and a relic on
  a troop is sold once it is taken off into the bag (between waves, "Relics" above). `whyNotSell` adds `none`
  "None in the Bag", and `bound` "Equipped: send it to Vault first" for a Pusaka bound to a type: only the Gudang
  sells.
  The book sells by this one rule in a Town's Shop alone (below). Until decisions-log 296 a game without the Towns
  sold in two places too (decisions-log 169 and 187): the Toko's card ("Sell", "Sell all") and the Bag page's facing
  page (Sell, Sell all; a Gudang Pusaka's Sell); both went with the Towns-off book.
- **Only in a Town** (decisions-log 230; the owner, 2026-10-04: "semua aktifitas shop hanya bisa di lakukan di town, di
  tas di remove, dan di reuse codenya ketika di kota"): outside one `whyNotBuy` and `whyNotSell` say `town` "Only in a
  Town" first, for every kind (so a stale tap or a probe can't buy or sell on the field). In a Town its refusals and
  prices are the ones above. It buys back every small relic in play (`relicsInPlay`: the Smithy's seven and the
  forge's nine too; their `storeBought` is saved by name like the rest) and the materials held, each at its own price
  (`sellPrice(mat)` = town.json `materials`' `sell`, e.g. Wolf Claw 25, Skull 60; the last one sold leaves no entry),
  and its record names it under `material` (`StoreSold`; telemetry.md). It sells only the materials that have dropped
  and the open Artifact shelf, no item or small relic ("The forge: the Town Shop" above). The page is the Town's Shop on
  the Bag's code (ui-hud.md "The Town's Shop"): the field's Bag sells nothing. The page splits buying and selling
  (decisions-log 269): Buy shows the shelf in sections (Items, Relics, the store's Artifacts, Materials; only those the
  shelf has some of, decisions-log 280), Sell
  everything in the Bag that no troop or type is using (each enhanced stack, the Vault Artifacts too; not a bound
  Artifact or an oath), sold in one press from a sell basket by these same rules (`shopSellBasket`: `sell` / `sellAt`
  per stack, the gold the sum of each piece's price). Awaken 4-5,
  Forge and the fallen Heroes' Recall aren't the store's deals: the Army detail buys them between any waves, in a Town
  or not (their refusals are the store's `locked` and `midWave` alone). Its prices, inside these same price functions:
  a small relic and an item bought back at the market's price ("Towns: the market" above, decisions-log 326), each
  piece at its own step.
- **The Pusaka** (`Relic.store`; names in English like the Hero skills, the owner's pick, in `relicNames`;
  their lines in simple English like every item's since decisions-log 168): what they do is "Pusaka" above. The optional Midas purse
  of the design (more kill gold) was left out: a gold engine in a gold sink.
- **Icons:** `ui_icons.png` 16 px icons drawn at the relics' size (their rows' `Art.icon`, pusaka_catalog.dart):
  the red heart, the gold star, the yellow bolt, the trophy and the black coin; no new files. A gold glow
  sits behind them in the store and on the card.

## What a gift would do (`assignPreview`, #86 / #87)

`Game.assignPreview(loot, to)` (lib/game.dart) is what one more item on a troop type (`to` a String) or a relic on
one troop (`to` a `Unit`) would do. The Tas page's list (ui-hud.md) and the field's popup (#86) both show it. It
returns an `AssignPreview` record:

- `why`: why it can't, in the UI's words, or null. It is null exactly when `useItem` / `useRelic` would give it.
  First `assignRefusals.over` "Game over", then `assignRefusals.empty` "Bag is empty" (none in the bag),
  then the target's own: an item's `refusalNames[whyNot]` ("Not for this type", "Awaken first", "At max", "Max
  range"); a relic's `relicRefusal` ("Fallen", "Already holds <relic>", "Relic slots full"; "Relics" above). A Pusaka
  skips "Bag is empty" and says `pusakaOnType`.
- `stats`: the stats that change, `(StatKind, now, after)`. `StatKind` is the troop row's eight in its order: hp,
  mp, def, dmg, range, speed, rate, regen. `StatKind.of(stats)` reads the rate as the troop attacks, never under
  `minAttackInterval`, so a change the floor hides isn't listed. `statName(kind, heals:)` gives the words:
  "Attack", "Heal" for a healer's power, "Attack wait", "Defense", "Regen", ….
  - An item: `fieldStats(type)` now (the type's `statsOf` times `auraBoost` while a Hero lives, the Army page's
    numbers: ui-hud.md "Field stats"), and with the item tried on and taken back (like `priceWith`). The HP and MP
    of an awakening it completes come with it.
  - A relic: `_statsFor(u)` now, and with it added to `u.relics` for a moment (on top of a Hero's first). No small
    relic changes a stat (they act in the fight), so they list none; the stat Pusaka are a type's (`statsOf`).
- An item only (null for a relic), each `(now, after)`: `price` (`priceOf`), `awaken` (the level), `count` (the
  kind's `(taken, cap)`; the cap doubles on an awakening), and `step`: `(have, need)` summed over the recipe,
  toward the awakening after the level now, so the item that completes one reads 7/8 ▸ 8/8 with `awaken` (0, 1).
  `step` is null at `maxAwaken`.
- The try-on happens whenever the target itself can take it (the item within its cap; the troop alive with a slot
  free and not holding that kind), whatever the bag or the game's end say. Otherwise every "after" is its "now" and `stats` is
  empty. Nothing is changed (test/assign_test.dart).

## What a Tas row previews (`pusakaPreview`, decisions-log 151)

`Game.pusakaPreview(relic, type)` (lib/pusaka.dart) is what a tap on troop `type`'s Tas row would do with Pusaka
`relic` picked (ui-hud.md "Tas"). It returns a `PusakaPreview` record:

- `action` (`PusakaAction`, `pusakaActionNames`, the `Words`): `lepas` "To Vault" on the type it is bound to (free);
  else `pasang` "Equip" when its next binding is free (`bindPrice` 0: never bound, or undone), else `pindah` "Move"
  for `price` = `bindPrice` (one `rerollPrice`: 38k at wave 86). `why`: `whyNotUnbind` / `whyNotBind` (mid-wave,
  "Not enough gold", …), null when the tap would do it.
- `alive`: the type's living troops; `stats`: the stats that change, `(StatKind, now, after)`, tried on and taken
  back (no refit, no event), as a troop of the type that isn't a Hero fights now: `fieldStats(type)`, its
  `statsOf` times `auraBoost` 1.15 while a Hero lives, what the field's plates show (the owner's wave-86 Templar has
  504 HP in the book and 580 on the field). A binding that sends the type's own Pusaka to the Gudang loses its stats
  too. Dragon Heart onto the owner's 13 Templar at wave 86: HP 580 → 927 each, +4,511 in all (the design said 928
  and +4,524: 580 × 1.6; the game rounds 504 × 1.6 to 806 before the aura's ×1.15). A Pusaka that changes no stat
  lists none; the row says what it does in a few words instead (`pusakaGist(relic, stars)`, "Hits 2 more, 40%"; the
  Langka "-20% damage taken", "Heals 15% of damage", "x1.75 every 3rd hit", "Death heals near troops 25%" at
  ★2, short enough for a phone's row).
- `blows` and `bossWave` (critique H1), when the HP changes: how many blows of the next boss wave's boss
  (`nextBossWave`: 90 after wave 86) a troop of the type lives through from full HP, now and after
  (`bossBlowsLived(type, hp, wave)`): the necromancer boss's blow, `enemyStats(boss, Tier.boss, wave).dmg` (the boss
  slot's reference; about 841 at wave 90), less the defence it fights with (`hitTaken`; the Templar's 20.7), counted as
  ⌈hp / hit⌉ − 1. No guard, skill or curse counts. The Templar with Dragon Heart at wave 90: 0 → 1 (927 − 820 = 107
  left).
- `pusakaTotals(relic)`: what a bound one gives its whole type now, one line marked "Now:", for its tooltip and the
  Shop's card (critique M6: totals, not one troop's factor), only where it adds a number to the effect line
  (decisions-log 168): "Now: 13 Templar, +4,511 HP, +121 HP/s" (Dragon Heart's HP and regen), "Now: 17 Priest,
  +1,173 heal/s" (Dawn Star: the extra heal, or damage, a second, from the field's stats and rate), "Now: 9 Wizard,
  +80% damage in crowds" (God's Thunder: jumps × share), "Now: up to 6 saves a wave" (Grail); Void Eye, the Langka and
  Dragon Crown none (it would repeat their effect line); asleep "Asleep: no Soldier alive"; nothing in the Gudang.
  `thousands(n)` writes the thousands the English way ("4,511"), here and in the messages and the Tas rows (until
  decisions-log 200 those used `grouped(n)`, the Indonesian "4.511").

## What the book says about them

`Game.itemInfo(item, [type])` and `Game.relicInfo(relic)` build the tooltips' words (ui-hud.md) from
the same constants the rules use, so they stay true when the balance changes; since decisions-log 168 in simple English
(ui-hud.md "In-game text": the style, the glossary, what stays as it is). Names: `itemNames`
(Sword, Shield, Boots, Bow, Gloves, Potion, Staff) and `relicNames` (Fang, Thorns, Fury, Guard; the Smithy's Sweep,
Venom, Mana Siphon, Spirit Ward, Iron Will, Giant Slayer, Holy Charm).
Each returns `(title, lines)`; `itemEffect(item, [type])` and `relicEffect(relic)` are the effect lines alone,
which the store's card shows:

- item: the effect of one ("+25% attack", "-2.5 damage taken per hit", "+25% walk speed", "+20% range", "-20% wait
  between attacks", "+5 HP every second"; the potion adds "Healers: +3 HP per heal", or over a healer's row "+3 HP per
  heal"; the staff "+25% magic attack", "Healers: +3 HP per heal" and who takes it, "Only for Priest, Wizard", or
  over a healer's row "+3 HP per heal"), "For a whole type, up to a cap", then "Cost: troop price +10%" — or, over a
  troop row ([type]), "Now: 2/3 on this type, +56%" (taken / `capOf`, then `fieldStats(type).statOf(item)`, the row's
  cell, against the base), with "With Hero aura: +15%" under it while a Hero lives (`itemAuraLine`); the shield says
  "-5 per hit", a healer's potions "+10 HP/s, +6 heal", a healer's staffs "+6 heal"; "Now: 0/3 on this type" before
  the first; "This type can't take it" for a kind outside the type's recipe) and "Cost: troop price +3" (`priceStep` ×
  `awakenPrice` per awakening level) — then "Tap, then pick a troop" (`tapLine`) and "In bag: n".
- `hpInfo(type)` / `mpInfo(type)` (a row's HP and MP cells, the row's numbers: `fieldStats`): "Max HP 175 (base
  140)" (with Dragon Heart bound to the type a line, "Dragon Heart ★1: x1.6") / "Max MP 25, regen 1.3/s", "Only
  Awaken raises it", "Each level: +25% of base", and while a Hero lives "Hero aura x1.15" (`auraLine`; the owner's w86
  Templar without Dragon Heart: "Max HP 580 (base 280)" and that line) (MP also what spends it: "For <#10 skill> (15
  MP)", and once the type has awakened with a built skill "and Disarm II (12 MP)"; under the Bayangan Spell Tax the
  price the troops pay, "For Arrow Rain (21.6 MP)", `skillPrice`).
- `awakenInfo(type)` (a row's stars): the level in words (`awakenName`: "Not awakened", "Awaken 2",
  "Awaken 5 (Max)"); then its awakening skill (`awakenLines`, none for a type whose skill isn't built yet):
  "Awaken 1 unlocks Disarm" before the first awakening, else "Skill: Disarm II", then what it does at that level
  (at level 0: at Awaken 1) in one or two lines ("x2 hit on the strongest monster", "Its attack -15% for 6s (boss
  -7%)"), "MP 12, cooldown 20s" (the price paid under Spell Tax, as `mpInfo`'s), and below level 3 the next level's numbers, "Awaken 3: Disarm III (x2.5, -20%)"
  (from level 3 the next bought level's cooldown, "Awaken 4: cooldown 15.3s"); then "Awaken 2 needs:" and one line
  per recipe kind led by its icon, "Sword 1/3" (`awakenProgress`); at levels 3 and 4 "Awaken 4: buy in the Shop";
  at level 5 "Max: can't Awaken more", then its Forge ("Forge +6: HP x1.34, attack x1.34", a healer's "heal") and
  "Forge +7: buy in the Shop" (below "Forge +30").
- relic: the effect ("Heals 30% of damage dealt", "Attackers take 30% back", "x2 damage every 3rd hit", "-25% damage
  taken"; the Smithy's seven from town.json's numbers: "Hits 1 more monster near the target for 30%", "Poisons: +20% of
  the hit over 3 s", "+2 MP each hit or heal", "Shield 15% HP each wave", "Once a wave: heals 40% HP below 25%", "x1.5
  damage to mini boss and boss", "Heals on it +40%"), its tier ("Strong relic", `relicTierLine`) and
  "Best on: Soldier, Knight, Axeman, Templar" (`relicBestLine`), then "One relic per troop (Hero: 2)"
  (`relicSlotsLine`), "Tap, then pick a troop", "In bag: n, in use: m" (m = living troops holding one, `relicsHeld`).
  The Bag's facing page also has the tier under the heading (Basic in the page's ink, Strong in a
  Rare's green, Mighty in an Epic's violet) and "Best on" after what it does, and the Army detail's relic icons have the
  tooltip (ui-hud.md).
- Pusaka: its effect at its stars (★1 when not owned; a change in percent, `_pct`, a hit's multiplier to two decimals,
  `_x`), e.g. "+60% max HP", "Heals 1% max HP every second"; "+45% attack or heal"; "Each hit also hits 2 more
  monsters", "within 3 tiles, for 40% damage"; "Once a wave: survive 1 deadly hit", "Left at 30% HP, no damage for
  2s"; "Marks monsters it hits for 5s", "Marked: +25% damage taken (boss +15%)"; the Langka "-15% damage taken",
  "Heals 10% of damage dealt", "x1.5 damage every 3rd hit", "When one dies, all troops", "within 2 tiles heal 20% max
  HP"; then its "Now:" line where it has one (`pusakaTotals`, above; decisions-log 151), `pusakaLine` "For a whole
  type, never lost" (an oath: `oathLine`, "Legenda" above) and where it is (`pusakaWhere`): "On: Templar ★1" (with
  " (asleep)" while none of the type lives), "In Vault ★2" or "Not owned yet". The tooltip shows over its Tas slot
  and its Army cell's badge; the "★" is drawn as the star icon (ui-hud.md "The Pusaka in battle").

## Saved

`toJson` saves `inventory`, `upgrades` (type → item names), `relicBag`, each troop's `relics` (a list of names,
only when it holds any; saves from before #91 have one `relic`, which still loads) and its `name`, and `storeBought` (kind name → count, a material's
too with the forge's Shop, decisions-log 248; only once something was bought; saves from before the store
have none, so every price is at its base). The Pusaka save as `pusaka` (name → `{type, stars, binds,
suggested}`, the type left out in the Gudang and for an oath, `binds` and `suggested` only when set; an unknown name,
or a type that isn't a troop type, is dropped; an oath loads on no type, a Legenda at ★1), the Legenda found this run
as `legendsFound` (a list of names, only when any; a save without it finds the Legenda it owns; decisions-log 155) and the one-time messages shown as `notes` (a list, only when any; `pusakaNote`
"pusaka", P4's own beside it). A save without `pusaka` is from before them: its artefacts migrate ("Pusaka" above),
and one with none has no message to show. Unknown relic names in the bag or on a troop
are skipped (so a build from before the Smithy's seven drops them: `cleave`, `venom`, `manaSiphon`, `spiritWard`,
`lastStand`, `giantSlayer`, `blessing`). Awakening levels, caps and prices come back from `upgrades` (by grade from the
level a save from before the grades kept too: `awakenKept`, type → level, written by every by-grade game, `{}` when
none; a save without it gets it from its items, "The forge: items crafted, Awaken by grade" above), Bangkit 4-5 from `ascended` (type →
levels bought, only once one is; none in saves from before #92 part 2) and Tempa from `tempa` (type → levels, only once
one is; none in saves from before decisions-log 163). The fallen Heroes the Army detail can call back are
`fallenHeroes` (units-and-combat.md "Hero Gugur"; none in saves from before #92 part 3). The last Asah's wave is
`asahAt` (only once one was done; none in saves from before Asah, so the first is free to come). Ukir adds `ukir` and
`feed` to a Pusaka's entry (each only when above 0; a step past +5 loads as +5, a bar past its step's cost under it, an
oath's as none) and `ukir` `{iv, pts, milli}` to the game (once anything was fed): a save from before it, or one never
fed, loads and writes exactly as before.

The boss chests save as `chests` (always written, `[]` when none: its absence marks a save from before the chest,
which gets its catch-up chests; each `{kind, wave, cards?, rerolls?, epik?, n?, of?}`, a card by name or `serpihan`,
`cards` left out until rolled; a card naming no Pusaka loads as a Serpihan), with `draftDry`, `chestsGiven` and
`serpihan` only when above 0. The draft dice are not saved (decision 112).

The Bayangan ("Bayangan" above) save while `omensOn` is on (every build since decisions-log 319, additive: the save's `v` stays 3): `omens` (the levels by kind name, one a level, oldest
first; always written then, `[]` when none, so its absence marks a save from before them, which gets the catch-up),
`omensOwed` (the catch-up still to land), `skipBuffDue` (only when owed) and `grudgeType` (Grudge's target, last won
wave's top killer type, only when there is one; an unknown type is skipped; units-and-combat.md "Bayangan on the
field"), and each rolled chest's `omens` (a face a card, null for none). An unknown kind is skipped. Off, none of them is written or read. The Bayangan dice are not saved.

The Towns ("Towns" above) save `town` in every game (until decisions-log 321 a game without the Towns, the tests',
wrote none): `{chance, last, at?, in?, n?}`, the next roll's chance, the last Town's slot, the marked slot (only while one
is marked), `in: true` (only while the player is in it: a save made there reopens in it) and `n`, the Towns gone into
(decisions-log 326, the identity's number; only from the first). On load a mark already
passed (`at` ≤ the wave) and an `in` without a due Town are dropped; a save without `n` guesses it: one Town each
`townGapGuess` 7.5 waves from `firstTownAfter` to `last`, and the one it is in. A save without it (a file from before the Towns is
no save since decisions-log 237) counts as a Town before its own wave (`last` = its wave, at least `firstTownAfter`), so the first
comes 5 waves on at the earliest, like a new run's. The Town dice are not saved. The market ("Towns: the market" above)
saves `market` (product key → pressure, only when any; on load a key this build doesn't know, a pressure that isn't a
whole number above 0 is let go, one over 24 kept at 24); a save without it starts every product fresh. The Towns' materials ("Town and Smithy: materials"
above) save as `materials` (key → count, only when any; an unknown key skipped); the
materials' dice are not saved. The kinds dropped so far ("The forge: drops" above) save as `matsSeen` (names in
first-drop order) only when any. It
loads in its order, an unknown name skipped; a save without it starts from the materials held, in `Mat` order.
Enhance ("The forge: Enhance" above) saves `bagPlus` (the Bag's enhanced stacks, each `{item, plus, n}`) and
`upgradePlus` (type → its enhanced copies the same way), again only when any.
`inventory` keeps the +0 items and `upgrades` every item, so a save without them (one from before Enhance) loads all +0, and the format stays version 3. On load an unknown item is skipped, a "+" is kept in 1 to
`enhance.most`, and a type keeps no more enhanced copies of an item than `upgrades` lists (its highest).
The Tavern ("Towns: the Tavern" above) saves `boosts` (the boosts running, each `{kind, left, type?}`, only while any
runs) and in `town` `tavern` (the visit's offers `{kind, type?, sold?}`, `rerolls`, `spent` and `bought`, only while in
a Town), `tavernDry` (above 0) and `tavernSeen` (once the first Tavern was rolled); none while unused, so a save of a
game without the Tavern is as before. `boosts` loads whatever the flags are (before the troops, so they fit with it); an
unknown kind, a Champion's Plate without a troop type and one with no wave left are dropped. A save in a Town without
`tavern` (made by a build without the Tavern) rolls its offers on load when the Tavern is on.
The Wishlist ("The Wishlist" above) saves `wishlist` (type → {item name: how many the type is to hold}, in the order put
on; decisions-log 300) only with some wish, so a save without one is as before and the format stays
version 3. It loads whatever the flags are, after the types' items: a save from before the goals (decisions-log 282:
type → a list of item names) wishes each for one more than the type holds, as it was wished; a type that isn't a troop
type, an item name this build doesn't know and a goal under 1 are skipped, an item twice kept once; a save without it has
an empty Wishlist. A build from before the goals skips a type whose value is a map (no wish, no crash). Its `free`
(decisions-log 302: the open free lines, product name → how many the Bag is to hold, in order; no item and no relic
share a name) loads the same way, an unknown name and a goal under 1 skipped; a build from before them skips the key
(it is no troop type), so the save keeps version 3.

The save's format is version 3 (`v`, `Game.saveVersion`) since the forge's data ("The forge: data" above); a
version-2 save (`Game.saveLoadsFrom`) loads forward whole, nothing discarded, and is written back as version 3. An item
or relic name the build doesn't know is skipped wherever it stands (`inventory`, `upgrades`, `relicBag`, a troop's
`relics`, `storeBought`), so an older build drops the forge's names and a forge build loads them. A forge stone in
`materials` loads as held, but never into `matsSeen`. test/fixtures/save-20261004-1919-w8-v2.json is a real version-2
save (wave 8, a Town due) the tests load.
