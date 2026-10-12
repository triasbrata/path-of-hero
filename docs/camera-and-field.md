# Camera and field

Purpose: the camera, the back line, the deploy zone and the field's size.

## Field size

- The field always spans the whole screen width: `Board._scale` = the screen's height / (backdropH + fieldH), but on a
  short screen a little less ("Zoom out sedikit", below; `_HotGeom.scale`).
- There is no portrait field (decisions-log 289): a view taller than wide shows the landscape game in its letterbox
  (ui-hud.md "Layouts"), laid out 1.5 as wide as tall and 915 px wide at the least (915×610 on a phone held upright), so
  the view is 288 world units (18 tiles) across there. (From decisions-log 284 until 289 an upright phone's field stood
  over the spawn bar at the width's scale, 192 world units across; before 284 it took the top 42%, the book docked under
  it.)
- `Game.viewW = screen width / scale`, so wider screens show more columns.
- **The scene stands on the spawn bar's step** (decisions-log 287; the owner, 2026-10-09: "buat untuk battle groundnya
  itu pada bagian bawah seperti ini `___/<menu spawn troops>\____` supaya battle jangan sampai di belakang dari action bar
  untuk spawn troops"): it is framed (`Board._origin`) so the field's y `stepLip` (134) lies on the step's top
  (`_HotGeom.stepTop`, ui-hud.md "Spawn bar"), 2 world units under the lowest a unit's shadow reaches (132: a unit at y
  `fieldH − 2`, its feet 5 under, the shadow 1 more), so nothing of the battle is ever drawn behind the bar. Only the
  frame moves: the lanes, the zone, every clamp, the units' and the camera's rules are as they were, and the scale and
  `viewW` too but on a short screen. The band shows that much less at its top (the sky's top rows over the screen's):
  the field's top (the horizon) at y 188 at 1600×947 (251 before), 132 at 1266×713 (189), 149 at 1164×777 (206), 76
  at 915×412 (109). The welcome screen frames its scene `fieldFoot` higher (its floor's last row at its bottom, no
  bar). `toScreen`, the tap mapping and everything drawn from `_origin` follow it. Until decisions-log 287 the scene was
  framed `fieldFoot` (13.2 then) higher than the field at the screen's bottom, and the bar of 283 stood over the lowest
  lane's feet at 915×412.
- **Zoom out sedikit** (the owner's pick for a short screen): the step lifts the scene by a slot and its frame, which on
  a short screen would take the first lane's units' bars under the top band. So the scale is the least of the screen's
  height over the scene's and what keeps the first lane's bars (`barReach` 24 over a unit at y `tile / 2`) 2 px under
  the top band (`_meterBottom`) with the field's y `stepLip` on the step's top: (the hotbar's top − `_meterBottom` − 2)
  / (`stepLip` + 12 floor px − `tile / 2` + `barReach`). Only a screen under about 582 px tall zooms out: 915×412 at
  1.916 px a world unit (2.146 before), its view 477.6 wide (426.4 before, 12% more of the field) and some of the forest
  still showing over the field; 568×320 (an iPhone SE held sideways) at 1.312 (1.667), its view 432.8 wide (340.8);
  1600×947 (4.932), 1266×713 (3.714), 1164×777 (4.047), 915×610 and taller keep theirs. The HUD's own scale
  (`_meterK`) is the screen's height over the scene's, never the zoom's: the top band and the bar keep their sizes.

## Camera: the view's centre is the battle point (#85, lib/battle_focus.dart)

The owner: "center cam adalah battle field. battle field adalah titik pertemuan antara troops dengan enemy":
the middle of the screen is where our troops and the monsters actually hit each other (decisions-log 123).

- `Game.viewMid` is the world x of the view's centre; `Game.cam` (the view's left edge, which the UI draws
  from) eases after `viewMid − viewW/2`: `cam += (viewMid − viewW/2 − cam)·min(1, dt·camEase)`, camEase 2.5.
  `camTarget` = `viewGoal − viewW/2`, where the view is heading. None of it is saved; a new or loaded game
  snaps `viewMid` to its goal on the first tick (cam = baseX after a load, as before).
- The camera never reads `cam` itself nor a monster's `entered` (which `rightLimit`, and so the camera, sets).

### The battle point (`BattleFocus.aim`, once a tick mid-wave; `meetMode`)

| Mode | When | `meetX` (where the centre heads) |
|---|---|---|
| contact | a fight weighs ≥ `minFight` 2 | the fight shown (below) |
| hold | no fight, but one less than `contactGrace` 1 s ago (a knockback, a hop, a charge through a pair) | where it was |
| hold | no troop entered (only ones marching in) | where it was (it used to go back to the line) |
| approach | no fight, a monster at or ahead of the troop front | toward the next meeting (below) |
| chase | no fight, every monster behind the troop front (the stall march, or the army walked past them) | the closest troop–monster pair's midpoint in x |
| hold | no monster alive (a spawn gap, the last one dying) | where it was |

- **Contact points** (`contactPoints`): every unit in battle — alive, not in a hop's air or a charge
  (`_passesThrough`), a troop once entered, a monster entered or not — that is not a healer and whose nearest
  foe in battle (healers included, Euclidean, a tie to the lower id) is within its reach + `contactSlack`
  (half a tile) marks the midpoint x of the two, but never more than `reachPull` 2.5 tiles from the foe: bows
  stack ×1.2 each, and a late army's archers shot from 15–20 tiles, whose midpoints pulled the view 5–7 tiles
  back off the melee line and pushed the melee against the right edge (a base archer's or wizard's point is the
  plain midpoint). Since the long range's hold (units-and-combat.md "Long range hold") a shooter holds at most 100
  px (6.25 tiles) from its foe: its midpoint is 3.1 tiles off at most, and the cap trims it by 0.6 of a tile at most. Weight: `contactRanged` 0.5 for a shooter, 1 for melee, times `tierWeight` of the pair's
  monster (normal 1, elite 1.25, high elite 1.5, mini boss 2, boss 3).
- **Fights** (`fightsOf`, `fights`): melee points sorted by x are chained, a gap over `fightGap` 3 tiles
  starting a new fight; a fight's span is its melee points'. A shooter joins the fight whose span is nearest
  its target's x, within `fightGap` (so archers never chain two fights); the rest chain among themselves.
  A fight's x is its points' weighted mean, its weight their sum.
- **Which fight** (`fightPick`, the owner's default `FightPick.bigger`): the one shown (its span, padded
  half a `fightGap`, holds `meetX`) is kept until another weighs `switchRatio` 1.5× as much for `switchHold`
  0.75 s without a break. With none shown, the heaviest (a tie to the one nearer the view, then further on).
  `FightPick.frontMost` would show the front-most instead (the same hold, no ratio). So one runner, a bat
  that swooped behind the line, a monster that slipped past or the necromancer healer at the back doesn't
  pull the view: alone, it weighs 2 at most.
- **Troop front** (`troopFront`): the upper quartile (`frontTrim` 0.25) of the x of the troops alive,
  entered, not healers, not falling back, not in the air and not joining, never more than `frontGap` 2 tiles
  ahead of the next one behind it (failing that, joining ones too; failing that, everyone entered). One
  runner is ignored among 5 or more, two among 9; with 4 or fewer a runner moves it 2 tiles at most.
- **Approach** (the owner's default, `approachFollowsFront`): the monster that meets the front first at their
  walking speeds (a troop's capped, units-and-combat.md "The walk cap"); already in reach of each other, their contact point; else the pair's contact point at first
  contact (it stays put while both walk), but no more than `approachLead` a tile ahead of the front, unless the view
  already sits further on. So before the sides touch the view slides with the front, about a tile left of
  centre, and is at the meeting point when they meet. `approachFollowsFront = false` would go straight to
  the predicted meeting point (part of the army off the left edge).
- **Band:** without a fight, `meetX` keeps the troop front `frontIn` 3 tiles inside both edges of the view.
- A new wave forgets the last one's point (`meetX`, `fightX`).

### The glide (`_aimView`, in `tick` after the moves and shoves, before the entered and `rightLimit` clamps (#42))

- Mid-wave `viewMid` ignores moves under `focusSlack` half a tile and goes at most `focusSpeed` 6 tiles/s
  (≈ 3× the fastest walker, so a walking fight is followed exactly). A 10-tile switch takes ~1.7 s.
- After a win it holds where they fought for `victoryTime` (the cheer), then glides once, at the same cap, to
  the rest view.
- **Rest view** (between waves, `_restMid`): the back line at the left edge, or further on when the front
  troop would walk off the right one (max(baseX, front + 2·tile − viewW) as the left edge); baseX with no
  troops. Setting up between waves (after the glide) goes there at once: cam eases as it always did.
- A resized window or a rotated phone keeps the fight centred: `viewMid` is world x.

### What moves with the view

- **The front's cap** (`Game.frontCap = cam + viewW − capInset`, a tile; decisions-log 324): mid-wave no troop that has
  marched in walks past it, and a shove doesn't push one past it; one past it already (the view went back) stands where
  it is (formation-and-navigation.md "The front stops at the view's right edge"). The view centres the fight, so it
  seldom binds: viewW/2 − a tile ahead of a centred fight, 146 world units at 1600×947 (viewW 324.4), 223 at 915×412
  (477.6).
- `rightLimit = cam + viewW − 2·tile`: monsters on screen are kept 2 tiles from the right edge. In a
  centred fight that is viewW/2 − 2 tiles ahead of it (8.7 tiles on the Mac). The clamp only
  stops moving **right** past it: an entered monster past `rightLimit` goes to max(rightLimit, min(its x
  now, its x at the tick's start)). So a shove can't push it out, and the view gliding left never drags it.
  Its own steps left stand. Before #42 the clamp put it back to its tick-start x, which undid those steps
  too: a monster the view had glided past (the front troop within 2 tiles of the view's left edge, e.g. a
  lone priest) stood there for good, never came to fight, and not even the stall march (#39) could end the
  wave.
- A monster not yet entered isn't clamped. The healing necromancer, which walks away from the troops, keeps to
  `rightLimit` by its own rules: its rest spot and its back-off (or where it stands, when already past it;
  formation-and-navigation.md). Its back-off didn't until #85, and with the view on the fight rather than the
  foremost troop a late archer chased the healers, and the mini boss they healed, off the screen until the
  wave stalled.
- `rightLimit` bounds nothing a fight drags along: it moves with the view, and the view follows the fight. A lone
  wizard kiting right, away from a mini boss that followed it, took the view, the limit and the boss 2,000+ px off
  in 4 min (qa-3). The stall watch ends such a wave: monsters drifting away from the base are no progress
  (`stallDrift`), and `stallOvertime` marches a fight that runs on (units-and-combat.md "Stalled waves"). Holding
  the troop's x instead (`holdPastFoe`, off: "Long range kite") cost the last troops in near-wipes.
- `entered` for monsters means they have walked onto the screen (x ≤ `rightLimit`). It still gates the Hero
  skills' targets, the boss bars, the fall-back brain's `foeToBase` and #84's spots; the camera doesn't read
  it, so a monster enters before it meets the troops, lulls included.
- A troop is out of sight left of the view when its middle is more than `offViewBy` half a tile left of
  `cam` (`Game.leftOfView`; the tiny sprites' bodies are about a tile wide). The off-view marker shows
  how many (ui-hud.md, #56).
- Monsters spawn at `spawnX` = max(`cam + viewW + 8 + spawnLead`, the foremost entered troop + `spawnClear`
  4 tiles): `spawnLead` 2 tiles off the right edge, and never on top of a troop that ran on while the view
  shows a fight behind it.
- **What the view bounds, kept where it was** (`spawnLead`, `keepUpInset`, both 2 tiles): the view before
  #85 sat about 1.5 tiles ahead of the fight (its centre halfway between the foremost troop and the nearest
  monster, and the foremost troop leads the clash), and the spawn point and the supports' keep-up floor
  were tuned with it. Centred on the fight they came 2 tiles nearer our rear: the same saved armies (238
  waves from main's auto-player, 14–27, three dice each) lost 0.28 more troops a wave (16%, SE 0.06). A
  variant with every view-bound rule reading main's old view instead lost 0.03 more: nothing else in the
  battle point changes the fighting. So monsters spawn `spawnLead` further out, and once the wave has shown
  a fight (`fightX`) the keep-up floor and the catch-up trigger sit `keepUpInset` inside the left edge
  (`keepUpShift`, below). Before the first fight the old view was the rest view, further back than the
  approach's, so there the floor stays at the edge, as the spec's approach analysis has it. The replay's
  numbers are in decisions-log 123. The right limit stays 2 tiles inside the right edge: moved alone it
  changed nothing, and a monster held at the very edge would be half off screen.
- The minimap's gold line is `fightX`, the last fight shown this wave (ui-hud.md).
- Before #85 the view centred (front troop x + leftmost *entered* monster x)/2 while both sides had someone
  on screen, else the rest view: one runner, a swooping bat or a monster that slipped past dragged it, it
  swung ~9 tiles at each lull, and a monster waiting off screen never entered (rightLimit sat on the troops).

## Back line (`baseX`) and deploy zone

- `baseX` is the zone start, and the line no monster passes (decisions-log 329: a monster there stands at it and waits
  for the troops; until then one over it was gone and cost a life, half a heart). It only moves forward, and only when
  a wave is won
  (#79, the owner: "garis belakang di majukan setiap selesai wave saja"):
  - mid-wave it stays put, however far the army fights its way forward. The view centres the battle, so
    the line and the zone can be far off screen to the left (the minimap shows them, #80: ui-hud.md "Minimap").
  - on a win, to the rearmost troop (the tile edge at or behind it), never back; every drop spot moves
    with it, and the troops walk back to their spots once they have cheered.
  - Before: until #61 it followed the view's left edge mid-wave, floor(cam / tile)·tile, and so dragged
    the rear along with the view; #61 (decision 92) kept it `lineRoom` 2 tiles behind the rearmost
    troop mid-wave instead; #79 (decision 115) dropped that too.
  - With the line not dragging the rear along, the supports keep up with the view themselves
    (the orchestrator's option A; its switch `keepUpWithView`, always on, went in decisions-log 329): a healer's
    rest and a kiting archer never go
    behind max(baseX, cam + `keepUpShift`) + tile/2, and anyone out of sight (once the wave has shown a
    fight, within `keepUpInset` − `offViewBy` of the view's left edge) walking forward goes at the catch-up
    pace (#85's inset, above)
    (formation-and-navigation.md). Such a healer walks in before it heals (decisions-log 312: off screen 62 → 0 s a
    wave on the owner's wave-30 save at 1600×947), and the healers rest close behind the melee (decisions-log 324). With it off (the issue's rule alone, option B), a 36-seed A/B had 40%
    more troops fallen and 15× the time out of sight. With #79's line it is needed still more (the line no
    longer keeps even the rear in step): off, the probe's runs ended sooner (the auto-player's mean end wave
    28.1 → 24.4; the owner's save sooner on all 6 seeds) with more troops fallen and out of sight (decision 115).
  - Mid-wave a troop with nothing to do (no monster about for now, or a healer with nobody to back) holds
    where it is (`_rest`) instead of walking to its spot: the spot is in the zone at the line, which may
    be far behind the fight, and walking there would give up the ground the army has won.
- Troops that have entered are clamped to x ≥ baseX + `clearOfLine` 4.
- Mid-wave the view centres the battle, so the zone may be off screen, and the rear with it (the off-view
  marker shows how many, below). A troop bought then (tap-to-spawn) starts 2 tiles left of the view, not
  behind the line however far back that is (#79), and marches in at the catch-up pace
  (formation-and-navigation.md). It is `joining` until it fights, comes up to the others' front (−2 tiles) or
  the wave ends, and until then the troop front leaves it out, so a mass buy doesn't drag the view back (#85).
- The zone is no longer bought; it sizes itself to the army's **capacity** (the owner: "zona -> maksimal
  jumlah troops", "+Zona jadi +Kapasitas"):
  - `capacity` = how many troops may be alive at once; it starts at `capacityStart` 6.
  - "+Room" in the Army page's header (`buyCapacity`; "+Kapasitas" until decisions-log 187; at the detail's foot until
    decisions-log 260) adds `capacityStep` 2 for `capacityCost` = `capacityPrice` 40 +
    `capacityPriceRise` 10 per purchase already made: 40, 50, 60, ... (it began at the old +Zona's 75 +
    25; the owner made it cheaper, decisions-log 57).
  - It goes up to `maxCapacity`: with the board's army cap (`armyMax` 36, decisions-log 141 and 260; 32 until then)
    36 at most, 15 purchases, the same at every screen size (until decisions-log 260 also no more than the widest
    zone's cells, so a 412×860 phone stopped at 32); with no cap (a plain `Game()`) `maxZoneCols` × rows. The zone
    keeps its geometry (a 48-capacity save keeps its columns; at 36, 12 of a 6-column zone's cells stay empty).
  - A troop bought while `full` (`armySize` ≥ `armyCap` = min(capacity, `armyMax`)) is refused (`place` /
    `autoPlace`: `Sfx.error`); the book says "No room", or at the cap "Army full 36/36"
    (`buyRefusal`, units-and-combat.md).
  - An old save's `capBought` (the rooms decisions-log 256's header ladder sold, gone since 260) becomes capacity on
    load, up to 36 and never lower than the saved capacity (the owner's save: 30 + 6 = 36); it is never written again.
  - `zoneCols` = `deployCols` 3 + `capacityBought` (one column more per purchase, so the zone visibly
    widens each time: the owner, "menambah kapasitas akan menambah jumlah row spawn"), at most
    `maxZoneCols` = 30% of viewW (70% stays battleground), or, on a view too narrow for that to hold the board's
    `armyMax`, as many columns as do (⌈36 / 8⌉ = 5; decisions-log 260, the owner: "kalau potrai hp harunsya tetap
    sama, toh juga posisi buku berada di bawah jadi para troops tidak akan ketutupan"); past that, purchases add
    capacity only. With viewW = width × 192 / the field's height: 1266×713 6 columns (48 cells), 1164×777 5 (40),
    915×412 7 (56), the letterbox's 915×610 5 (40); the narrow-view rule held the upright phones' 5 where 30% gave 3,
    until decisions-log 289 took the portrait game away. It always holds the capacity (8 per column against 2
    per purchase). `capacityBought` =
    ⌊(capacity − 6) / 2⌋: an old save's capacity between two steps counts the lower.
  - Buying capacity does NOT re-form the army; a widened zone is used from the next troop on (the old
    +Zona moved the army up to the new front; decision 15 is changed).
  - Saves keep `capacity`. Older saves had `zoneCols` (6 before it could be bought): each column past
    `deployCols` counts as one purchase (same prices), and the capacity is at least the saved army.
- The zone and spawn lines are NOT drawn (the owner removed them). The zone only lights up while a
  troop is being dragged to a new cell.

## Backdrop (decisions-log 228, 244, 263; the pictures: tool/import_battle_floor.py)

`_scenery` (lib/main.dart) draws it, the field's and the welcome screen's, far to near: the sky, the clouds, the
mountains and pines (the band above the field, `backdropH` 64 world units), the props line at the horizon, then the
floor over the field. All are GandalfHardcore's FREE Platformer Assets, at one scale: 5 of the pack's px a world unit
(`_layerK` 0.2). Every one is drawn before anything on the field, so units, loot, rings and the HUD are all over it
(test/backdrop_test.dart records a frame's drawing order). The horizon is the field's top (band y 64): the meadow
starts there, and nothing tall stands below it.

- **The band** is the pack's Normal BG set, the Town's own files (`townLayers` in lib/town_art.dart, 1024×346 px each,
  no second copy), far to near: `town_bg_5` the sky (opaque, one colour a row), `town_bg_4` the mountains,
  `town_bg_3`, `town_bg_2` and `town_bg_1` the far, middle and near pines. `backdropLayers(cam, viewW)` lays them out.
  - Each tiles sideways (its left and right edges meet) at a fraction of the camera (`_parallax`), far to near
    0.05 / 0.1 / 0.2 / 0.3 / 0.45. A layer's copies (like the clouds', the props line's and the floor's: `_repeats`)
    run from at or left of the view's left edge to past its right one at any camera (the w89 save's ~243,000 and
    beyond) and any width (an ultra-wide 3440×1440 included); each copy is 0.5 wider than a repeat, so neighbours
    overlap without a seam.
  - One size in world units on every screen: a layer is 204.8 wide and 69.2 tall. The band takes the same share of
    the scene's height at every aspect, so every screen shows it whole and a wider one more of it sideways.
  - Their row 0 is at band y 14 (`_bandTop`), so layer 1's pines' skirts end on its flat dark ground (54,66,42)
    between its rows 230 and 263, band y 60–66.6, round the horizon (the median column at 250, y 64). From its row
    264 down it is only that ground, to its last row (y 83.2), under the floor. Before decisions-log 244 their row 0
    was the band's top and the pines stood at y 46–52.6, over a band of shaded grass down to y 76 (the owner: a
    "grass fence"; the battle belt too tall).
  - Above the layers the sky's top row is stretched up to the band's top and over anything above it (`_skyAbove`
    1000; no screen shows any today), so the opaque sky starts at the top of every screen: no blank strip (the
    Valley's white haze, #44, is gone with it). The welcome screen lays its colour (`_sky`) under its whole scene.
  - The Autumn and Winter sets of the pack are unused (whether seasons change by wave is the owner's call).
  - The Valley pack's band layers (`bg_valley_5/4/3`, decisions-log 16 until 228) are drawn no more, and their files
    were deleted in decisions-log 234.
- **The clouds** are one picture, `battle_clouds.png` (3072×130 px: 614.4 × 26 world units, row 0 at the screen's top,
  the band's y the frame puts there: `fieldFoot` on the welcome screen, the step's lift on the field (decisions-log
  287), so they keep their place on the screen while the scene is framed higher):
  the pack's cloud1..cloud6, each whole at the pack's pixels, twelve of them at a few heights, the big ones low. They
  are drawn over the sky and under the mountains, which hide their lower parts. `cloudCopies(cam, viewW, clock)` lays
  them out: they drift left 1.2 world units a second (`_cloudDrift`, about 4.5 screen px a second at 1266×713) and move
  at 0.07 of the camera (`_cloudK`, between the sky and the mountains), wrapping round. The battle's clock is the
  field's (`_fieldClock`: they stop while the game is paused); the welcome screen's is its own.
- **The props line** is one picture, `battle_props.png` (2048×330 px: 409.6 × 66 world units, row 0 at the band's top),
  the owner's forest example: Pine forest sheet.png's three big trunks, its pine and a fallen log, Decor.png's
  boulders (the rock pile with grass at its foot), rocks, bushes and ferns, all doubled (each pixel 2×2: at the pack's
  1x a trunk is a pole a fifth of a knight wide), and Tree1.png and Tree2.png (the apple tree) at 1x, the size of
  trees a little further back. Every prop stands on band y 65.6, just under the horizon; the trunks run up off the
  top of the screen. Gaps between them show the parallax pines. `propsCopies(cam, viewW)` lays it out at 0.7 of the
  camera (`_propsK`, between layer 1 and the field). Its feet, which slide over the floor as the camera moves, are
  under the floor's opaque grass and its ground line.
  - Nothing of it stands below the horizon, so a tall prop never stands among the lanes, and the first lane's units
    (feet at field y 4 and lower) are always in front of it.
- **The floor** is one picture, `battle_floor.png` (1024×786 px: 204.8 × 157.2 world units), built by
  tool/import_battle_floor.py from the pack's sheets (each mapped first: tool/sprite_map.py). `floorCopies(cam, viewW)`
  lays it out: its row 0 at band y 56 (`_floorTop`), its last row `fieldFoot` (21.2) under the field's bottom, tiled
  sideways like a layer and moving with the field. Under it Floor Tiles1's earth (`battle_step.png`'s `_stepEarth`, one
  flat colour, `_underFloor`) goes on down to the screen's bottom as one fill, and the spawn bar's step stands over its
  front, its slopes' grass meeting the floor's lip (ui-hud.md "Spawn bar").
  - **Its grass** is Tall Grass.png's strip of blades in rows 6 px apart, each over the one above it, the strip's
    copies overlapping and shifted sideways at random (a fixed LCG; a regular shift lines the blades up in diagonal
    streaks). Every pixel from the horizon (its row 40, band y 64) down is opaque; the first four rows' blade tips
    stand over it, and above them the picture is clear but for the ground line.
  - **The ground line**: Pine forest sheet's red and orange flower tufts, Decor's ferns, small bushes and rocks, all
    doubled, side by side along the horizon, their feet sunk between the grass rows (the rows after them cover their
    bottoms). It hides where the props line and layer 1 meet the meadow.
  - **The lanes' meadow**: the grass a little darker over its first rows, then a step lighter than the pack draws it
    (the pack's grass greens, darkest to lightest, from Tall Grass and Floor Tiles' grass tops), with Decor's small
    rocks, mossy rocks, small bushes and ferns at 1x (their feet above field y 120). Its grass tufts are left out: they
    are the grass's own colours. No shaded band any more: the meadow is as bright under the horizon as further down.
    The grass runs on under the field's bottom down to the front edge.
  - **The front edge** (decisions-log 263; the owner: a bottom padding, no troop or monster lower than it): Floor
    Tiles1.png's solid block's top middle cell (32×32 px: its grass top over brown-black earth), its first 16 rows (the
    grass top, rows 0-4, in the meadow's own greens; the roots, 5-11; four rows of earth) side by side along the
    picture's last 16 rows: its grass lip at field y 146 (`frontLip`; 138 until decisions-log 287 moved it under the
    step's top, the meadow 8 world units longer), its earth to 149.2. Beside the spawn bar's step it shows; under the
    step it doesn't (the step's own grass top, `stepLip` 134, is the field's edge there).
    - Under the lowest a unit stands: the game keeps every unit at y `fieldH − 2` (126) or above (the tick's clamp,
      the spots, the hero moves), and a unit's feet are 5 under its y and its shadow's last row 1 more (field y 132).
      The last lane stands at y 120 (its shadow to 126), and a shove or a spot under a monster in it takes a unit to
      126: on the w89 save's waves at every size checked. The step's top 2 under that is, in screen px under the lowest
      shadow: 10 at 1600×947, 7 at 1266×713, 8 at 1164×777 and 4 at 915×412 (until decisions-log 287 the lip, 6 under
      it, was 22, 24 and 13 px under it; an upright phone's 11 to 13 went with the portrait game, decisions-log 289).
    - Until decisions-log 263 the cell was whole along the last 32 rows, field y 121.6 to the field's bottom: the
      last lane's feet (y 125) stood on its earth, and a unit at y 126 had its feet under the screen's bottom.
    - Floor Tiles2.png, the same tiles with a blue-black earth, is the Town's street (decisions-log 279), not the field's.
  - Everything is under the units: nothing in the floor hides a troop.
  - LudicArts' Valley road (`bg_ground`, decisions-log 16 until 228, stacked twice over the 8 lanes) is drawn no
    more, and its file was deleted in decisions-log 234.
- **What stays the same**: the lanes, the field's size (`fieldH` 128, `backdropH` 64), the scale and the view's width
  (but a short screen's, decisions-log 287: "Field size"), the units' places and every hit area. Only the pictures and
  their rows moved, and the scene's framing (decisions-log 263, 287); a run at the same view's width plays out byte for
  byte as before (the w89 identity dump, at 341). A short screen's wider view (915×412: 477.6 for 426.4) is read as any
  screen's width is: by the camera and the battle point, the right clamp (`rightLimit`), the spawn line (`spawnX`) and
  the deploy zone's widest (`maxZoneCols`: 8 columns there for 7), so a fight there can differ.
