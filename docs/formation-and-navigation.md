# Formation and navigation

Purpose: how troops line up, walk in, make way and settle.

## Buying a troop (`autoPlace`)

- The troop box is TAP-TO-SPAWN (the owner replaced drag-to-deploy).
- `autoPlace(type)` picks a free zone cell. Before a wave with the zone full, it fails. Mid-wave it
  shares a cell.
- It calls `place()` (the gold check), then `_formUp()`.
- The new troop spawns off screen at `(baseX − 2·tile, its post's y)` with `entered = false`; mid-wave at
  `(cam − 2·tile, …)`, just left of the view wherever the back line is (#61; #79: the line stays put all
  wave, so it may be hundreds of tiles back, and #61's "or behind the line if further left" would have
  a troop bought late in a wave walk for minutes). Until it has entered it only walks toward its post,
  mid-wave at the catch-up pace (`speedTo`, below): no fighting, and no clamp to the back line. Mid-wave
  it usually starts past the line, so it counts as entered at once and heads for the fight, at the
  catch-up pace while out of sight.
- Mid-wave it is also `joining` (#85): the camera's troop front (camera-and-field.md) leaves it out until it
  fights, reaches the others' front less 2 tiles (`frontGap`), or the wave ends, so a troop bought 2 tiles
  left of the view doesn't drag the view back to itself. Not saved.
- `entered` becomes true once x ≥ min(post.x, baseX + tile).
- The free healer and loaded troops start at their posts (`_newTroop` sets `entered`).

## The formation (`_formUp`)

`Unit.rank`, back to front:

| Rank | Who |
|---|---|
| 0 | healer |
| 1 | long range |
| 2 | heavy melee: lancer, knight_templar, armored_axeman |
| 3 | front melee, `Unit.vanguard`: soldier, knight, swordsman |

- All living troops get new posts. Ranks 3, 2, 1, 0 fill ONE continuous list of zone cells: front
  column first, each column from the middle rows out (3, 4, 2, 5, 1, 6, 0, 7; ties go to the upper row),
  each rank in placement order (`id`).
- A rank starts a fresh column only if that still leaves a cell for everyone. Otherwise it continues
  the column the previous rank left.
- Only more troops than cells ever share. The overflow shares from the back-most cells, so an
  overflowing healer stays at the back.
- A manual drag (`move`, before a wave) is overridden by the next spawn.
- After a win, `_claimSpots` settles doubled cells: the first placed keeps the cell, and a later one
  moves on its role's side, to the nearest free cell (of two as near, the one nearer where it stands, #82). Then `_uncrossSpots` (#82): two troops of a rank whose walks back to their spots
  cross trade spots (unless they stand together, closer than `_personalSpace`), and so do two that would walk
  half a tile less between them the other way round (two swapping spots along one row). Each trade shortens the
  whole walk, so it ends and never trades back. So a troop comes home to a spot of its rank, not always the one
  it left (see "Paths that cross" below).

## Walking without shoving

| Mechanism | What it does |
|---|---|
| `arriving` | Set on a troop given a new post BEFORE a wave (spawn or re-form). It walks straight through others: no `_steer`, no `_makeWay`, no separation. Cleared at the post (< 1) or when `waveActive && entered`. Without it a re-forming army shoved forever (the owner's video of long range and healers "fighting over spots"). |
| `_moveToward` | Snaps onto the target when within 1 unit, so it isn't "moving". Sub-pixel walk-backs made neighbours give way in turn, forever. |
| `_passes(a, b)` | Who goes first: in battle, a mover coming through from behind (heading right, more ahead than beside), on its way to the fight. Then the one on the move before one standing, then the further forward (line), else the lower `id`. Between waves only that fixed order (#82), so between two walking troops who gives way never changes while they meet, and no ring of them each waits for the next. Coming through from behind went first between waves too until #82: a yielder pushed back came through next and took the way, so two back-rank troops crossing swapped it for good. |
| `_steer` | Between waves, a walking troop's way round the walking allies that go first (#82, below). It returns the step: a direction times the share of its speed it walks at. In battle only `_bendRound`: the nearest ally that goes first in the corridor ahead (`_lookAhead`, or as far as it goes; `_personalSpace` each side) bends its heading to the far side, harder the closer it is, and it never slows down. Spot mates (below) are not gone round. |
| `_makeWay` | A troop in the corridor of one that passes it (`_lookAhead` 20 ahead; between waves no further than that one still goes, and one settling back onto its spot, under half a tile to go, has none to clear: in a packed zone it set its neighbours stepping aside by turns for good, #82) steps aside (even while shooting) and waits (`yieldUntil`), then walks back. A tick's steps aside take it one of its own walk steps (its capped walk, `walkSpeed`, decisions-log 311) at most in all, however many troops pass it (decisions-log 309, the owner: "Ya, batasi juga"; until then a step for each, up to 14.6 units a tick on the owner's wave-30 save). Before a wave, non-melee never step forward. A healer mid-cast (`_casting`) doesn't step aside, nor does a carried or braced troop (`_firm`, units-and-combat.md "Forced movement"), nor a spot mate (below). Between waves a troop walking somewhere of its own (`_walking`) isn't pushed: it finds its own way (`_steer`); in battle it is. A kiting archer's step back (`kite`) is no walk to anywhere: it is pushed as before and doesn't steer (without that, archers kiting against the view's left edge jammed 2–3× longer). |
| Separation | `_personalSpace` 12 keeps units apart. Between troops the yielder moves: sideways, and backwards for non-melee before a wave; mid-wave its x part is the two troops' x apart over their distance (decisions-log 324: a whole half gap by the sign before, so allies one above the other shoved each other back and forth). A healer mid-cast holds its ground, and so does a carried unit, a braced troop or one under `noShove` (`_firm`): the other one yields, or (troop against monster) takes the whole push. Between two troops a stand a troop gave itself (the Pusaka Anchor's, all wave) doesn't count: it holds against the monsters, and its troops still part. A unit in a leap's air or charging (`_passesThrough`) is skipped, and so is a pair of troops where one walks through its allies (`_ghost`: `arriving`, or the stall detector's moment), and so are two spot mates (below). Between two monsters, one walking into one that stands takes the whole push and slides round it (`_slideRound`, units-and-combat.md "Fighting rules"). |
| Stall detector | `_watchStuck` (#82): a troop more than half a tile from where it heads that walked this tick, or that stands aside (`yieldUntil`) on its way home between waves, without getting on counts the tick (`Unit.stuckFor`). Getting on is, in battle, a quarter of its step (its capped walk) along its way; between waves (its spot stays put), a quarter of its step nearer its spot than it has been yet on this walk (`Unit.closest`): a troop pushed back and forth by one that kept stepping back onto its own spot on the way got on now and then, and a tick-by-tick count never reached the limit (the probe, auto-player seed 1 wave 14). After `_stuckAfter` 1.5 s of that it walks through its allies for `_throughFor` 1 s (`Unit.throughUntil`, `_ghost`). A jam of allies holds nobody for good; monsters still block. |

## How the moves look (decisions-log 307)

The rules above move a troop in steps the eye can't follow, measured on the owner's wave-30 save (34 troops, Auto Buy,
x1, 72 s, 16 ms ticks): the separation hands the yielder the whole gap to each neighbour, summed over every neighbour in
one tick (17,586 troop-ticks moved, up to 36 units in a tick, 108× a walk; with the y clamp at the field's edge up to
12); `_makeWay` stepped a yielder aside at its own speed once for every troop passing it (31,937 troop-ticks, up to 14.6
units a tick: the hero knight walks 275); the catch-up pace (`speedTo`) was the fastest living melee's (275 there, 8.6
to 13× an archer's or a wizard's walk, an Auto-Bought troop's too); Board.update's 0.1 s clamp carries a fast troop
0.1 s of walking in one frame. The Board draws each troop at a body that follows its position at a capped pace,
walking (ui-hud.md "Troops drawn moving"); the separation and the clamp are as they were. The catch-up pace and the
make-way step are the game's, and the owner capped both (decisions-log 309, above): the catch-up pace at 2× a troop's
own walk, a tick's steps aside at one walk step in all. Then every walk (decisions-log 311): no troop walks faster than
6× its type's base walk, what the walk strip can stride with its feet planted (units-and-combat.md "The walk cap"): the
hero knight's 275 is 144 since.

## Paths that cross (#82)

The owner: "ini path movementnya masi bug, dimana kalau tA dan tB sama sama mau lewat" (troop A heading for a spot
or foe low on the right, troop B for one high on the right: they got in each other's way). Decisions-log 118.

- **Walking round one another between waves (`_steer`).** A walking troop looks `_meetTime` 1 s ahead (or until it gets there) at
  each walking ally within `_meetRange` 3 tiles that goes first (`_passes`), from their positions and velocities
  (`Unit.vel`, set with `Unit.goal` by `_moveToward`). One that would come within `_personalSpace` of it is met
  (`_clash`), unless both head for the same place (goals under 12 apart: they close in, and separation keeps them
  apart there). It takes the first step of `_ways` that stays clear of all it meets:
  straight on; bent 20°, 40°, then 60° (the chosen side first); at 3/4, 1/2 and 1/4 of its speed; waiting;
  stepping aside (90°). With none clear it takes the one that keeps the most room.
- **Which side (`_passSide`, of the nearest met).** Behind one crossing its way (where it came from). Head-on, alongside or with the
  other standing still: on the side away from it. Dead ahead: on its goal's side of the other's goal, so the one
  whose goal is lower passes below; level, toward the middle lane.
- The one that goes first walks straight on.
- **In battle, main's rules stay.** One coming through from behind goes first (`_passes`), the others only bend
  round it at full pace (`_bendRound`), and walking troops in its corridor step aside (`_makeWay`). With the rules
  above in battle too, the owner's waves ran longer (a second or more; decisions-log 118 has the probe); with
  these, as long as on main. Crossings in battle are rarer and shorter: nearest picks don't cross, the melee take
  spots (#84), and nobody keeps a spot, so one pushed aside may step forward. The stall detector, the lanes and the
  kite hold work in battle as between waves.
- **Before (the repro, 30 s cap):**
  - two soldiers crossing got home 0.3–1.8 s late;
  - two archers, two priests, or a wizard and a priest crossing, or two archers swapping spots up and down,
    never got home: every time the yielder had been pushed back it came through from behind and took the way,
    and back-rank troops could only be pushed backward before a wave;
  - two idle healers whose lanes crossed: one froze.
- **After:** every pair gets home within 0.2–0.9 s of walking straight, the first with no detour.
- **Every case, and what handles it:**

  | Case | Handled by |
  |---|---|
  | The walk home after a win (not `arriving`) | `_uncrossSpots`, then `_steer` |
  | Re-forming before a wave (a buy) | `arriving`: they walk through each other (unchanged) |
  | Troops marching in | `arriving` (unchanged) |
  | Idle healers' lanes | `_topDown` |
  | The healing necromancers' lanes | `_topDown` |
  | A hurt troop falling back to a healer through troops walking up | `_passes` (the one walking up comes through first), `_bendRound` |
  | Catch-up walkers | `_bendRound` in battle, `_steer` between waves |
  | Melee walking to their spots round a monster (#84) | its spot assignment (two walking to spots of one monster swap them when that shortens their walks) and `_bendRound`; spot mates close in without either |

- **Other attack targets are never swapped.** `_nearestFoe` picks (long range) can't cross pairwise: if A→M1 and
  B→M2 crossed, then |AM2| + |BM1| < |AM1| + |BM2|, so one of the two isn't the nearest. Where the melee go is #84's
  (spots, below).

## Where melee stand to fight (spots; `lib/engage.dart`, #84)

The owner (#84): "para troops harus mencari posisi supaya mereka dapat melakukan hit enemy, ntah troops memutari
musuh dari belakang jika sekitarnya musuh bisa di pukul, dan jika 1 enemy tidak bisa dipukul karna spotnya sudah
penuh troops lain harus mencari musu lain sampai mereka dapat posisi untuk hit, jika tidak ada juga maka mereka
akan siap siap di dekat para enemy untuk menunggu ada spot untuk masuk melakukan hit", and then: eight spots like
a compass. Before, a melee troop walked at its nearest monster's centre, into the backs of the allies already
fighting it. Decisions-log 120.

- **The spots** (`Spot`, `spotCount` 8): front, front-top, top, back-top, back, back-bottom, bottom and
  front-bottom round every monster, like a compass. The front faces the troops (left, towards the back line).
- **Their size** (`spotRing`): every monster has one body today (the separation's `_personalSpace` 12), so a
  spot is that far from its centre at least and as far as the troop reaches at most, less `spotSlack` 0.01:
  a soldier stands 11.99 off (in reach, and not in the monster's body), a knight 13.99, a lancer 21.99, a melee
  troop with bows further. Eight spots at a soldier's reach are about 9 apart.
- **The order they fill** (`spotFill`, a row at a time): the front; front-top and front-bottom; top and bottom;
  back-top and back-bottom; the back last. Within a row a troop takes the one nearer to it. So a troop flanks round
  to the back only when the spots in front of those are taken.
- **Who holds what** (`_assignSpots`, once a tick before anyone moves, mid-wave only; melee troops that have
  entered and aren't falling back; the fields `Unit.spotOf`, `Unit.spot`, `Unit.waiting`):
  1. A troop that already reaches a foe fights it from where it stands (as ever) and holds that foe's spot: the
     one it walked to, else the free one on its side.
  2. A troop walking to a spot keeps it while the monster lives and the spot is open (on the field's rows, not
     behind the back line, not off the view's right edge, not inside another monster's body) and no fighter holds
     it.
  3. Everyone else, the one nearest a foe first, takes the first free spot in `spotFill` order on the monster
     nearest to it that has one (a taunted troop only its taunter's). A troop falling back gives its spot up.
  4. Two troops walking to spots of one monster swap them when that makes their walks shorter, so their paths
     don't cross.
- **Getting there** (`_meleeGoal`, `_spotWay`): lined up with its spot (within `stepInAt` 15°, seen from the
  monster) it steps straight in; else it goes to the point `orbitGap` 12 (a body) outside its reach in line with
  the spot, going round the monster an eighth of a turn at a time at that distance when the spot is further round
  (the roomier way when it is straight across, never off the field). So it goes round the troops already on spots
  instead of through them, and doesn't stop half way to fight from another's spot.
- **Spot mates** (`_spotMates`): two troops with different spots of the same monster, each within its reach plus
  half an `orbitGap`. They don't shove each other in the separation, nor step aside (`_makeWay`) or steer round
  (`_steer`) for each other: eight of them close in together.
- **Waiting** (`_waitPoint`): with every spot of every monster taken, a troop waits `waitBack` 1.5 tiles behind
  the front spot of the monster nearest to it, level with it within a tile (about 2.5 tiles from that monster),
  and takes the first spot that frees (it looks again every tick). Mid-wave (decisions-log 324) one already between
  there and the front spot stays at its x: a troop that has just lost its spot, or stepped aside, doesn't walk back
  to wait.
- **A hold before a turn** (`Game.turnHold` 0.6 s, `Unit.forwardAt`, not saved; decisions-log 324): mid-wave a melee
  troop that walked forward to its spot or its foe less than `turnHold` ago doesn't turn back to a goal more than
  `turnSlack` 1 unit behind it; it stands facing its foe meanwhile. A spot taken and freed again, a wait point that
  jumps with the nearest foe, or a step aside no longer sends it back and forth; a goal that stays behind it, it
  walks to after the hold.
- **Reach** (`reaches`): a unit reaches a foe within its reach plus `spotSlack`. The separation parts two bodies
  to exactly 12, a melee unit's reach, give or take a rounding error; without the slack one a hair out stepped in
  again, shoving, instead of striking.
- Long range, healers and hurt troops falling back keep their own rules (the long range's hold and kite,
  units-and-combat.md "Long range hold"; `_heal`; `_fallBackTo`). The walk
  to a spot keeps the catch-up pace (`speedTo`) and the light melee's `paceLimit` (below).

## Healers mid-battle (`_heal`)

- Fighters = those attacked in the last `_engagedFor` 2s (else all), so a fresh troop at the back
  doesn't pull the healers back.
- Rest line = max(max(baseX, cam + keepUpShift) + tile/2, rearmost fighter − tile, rearmost melee in the fight
  (not falling back) − `healBehind` 2.5 tiles): the last with `Game.keepSupports` only (decisions-log 324), so a healer
  follows the melee, not the long range standing back at their hold (archers about 3 tiles behind the melee, wizards
  up to 5: they now stand level with the healers or behind them). Never behind the back
  line, nor behind the keep-up floor at the view's left edge, `keepUpInset` 2 tiles inside it once the wave
  has shown a fight (#61: the line no longer follows the view, so the healers keep up with it by walking,
  `_rearEdge`). Since #85 the view is centred on the fight (camera-and-field.md), so in a settled fight that
  floor is viewW/2 − 2.5 tiles behind it (8.2 tiles on the Mac, 4 on a phone); the inset keeps it about where
  the view before #85 had it (camera-and-field.md, "What the view bounds"). Limit = max(rest, frontmost
  melee − range·0.8).
- A healer advances only as far as needed to reach the ally it heals, then falls back: troops falling
  back to be healed (`retreating`, below) first, then the most hurt.
- With nobody to heal it smites a dark monster already in its range (holy damage, units-and-combat.md)
  from where it stands, and otherwise keeps falling back: it never steps up for a monster.
- Idle healers spread a tile apart around the fighters' middle y, top to bottom as they stand (`_topDown`, #82).
  By placement order, two whose lanes crossed pushed against each other and one froze there for good.
- Mid-cast (`healCast` 0.6 s after it starts a heal) a healer stands still: see units-and-combat.md.
- **Out of sight** (decisions-log 312): with fighters on the field, a healer whose middle is more than `offViewBy` left
  of the view (once the wave has shown a fight, less than `keepUpShift` − `offViewBy` inside its left edge) walks up to
  its rest at the catch-up pace before it heals or smites, so no heal of its comes from off the screen: a Hero priest's
  ×3 reach (288) healed the whole field from the back line, never seen.
- **Left behind** (decisions-log 312, 324): one more than a tile behind its rest walks up toward it at the catch-up pace,
  never past it, whenever no heal of its is due (its cooldown running, short of the MP, saving it for a skill). And it
  walks up first: it stops to heal only an ally falling back or at `retreatAt` (half) of its HP or less, and doesn't stop
  to smite. A heal holds a healer `healCast` 0.6 s, and the priests cast about every 1.3 s, so stopping for every heal
  they averaged about 25 units a second against the army's 32 and trailed the melee by 6 to 9 tiles once the view
  centred the fight (324); a long reach (a Hero priest's 288) lets it heal the field from there, never seen.
- Both are `Game.keepSupports`'s (on); off, a healer heals from wherever it reaches.

## Hurt troops fall back to a healer (`_fallBackTo`, lib/retreat.dart)

The owner: "troops yang nyawanya tinggal setengah ke bawah mundur ke belakang untuk di-heal sama healer"
(#32), then (#50): don't let them die for keeping on attacking at low HP, "tapi jangan sampai karna nunggu
di heal mulu sampai tidak nyerang nyerang". Decisions-log 60 and 96.

- **The decision** is a `RetreatPolicy` (`Game.retreatPolicy`). Mid-wave, every tick, for each troop that
  isn't a healer (and isn't standing its ground, `Status.holdGround`, hero_skills.dart), game.dart builds
  its `RetreatFeatures` and acts on the answer, a `RetreatAction`: `fight`, `fallBack` (strike nothing on
  the way) or `fallBackFighting` (still strike a foe in reach). Between waves nobody falls back
  (`Unit.retreating` is cleared). The default is `RuleRetreatPolicy`; a trained model can replace it by
  reading the same features, without touching the combat code. There is no model today.
- **The brain:** every threshold is in `assets/ai/retreat.json` (`RetreatBrain`, `"version": 1`), which
  `main()` loads into `retreatBrain` before the game starts (not `TdGame.onLoad`: a widget test's game runs
  that, keeps the defaults, and boots no slower). A number that is missing, of the wrong kind or out of its range
  keeps its default in code; a file of another version, or no file, gives every default. The file and the
  defaults in code are the same (a test checks). `RetreatBrain.old` is the original rule alone (#32).
- **The features** (plain numbers): `hpShare`; `dpsShare`, the share of its most HP lost per second over
  `threatWindow` 2 s (`Unit.hurtLog`, written in `_hurt`); `healers`, the troop healers on the field;
  `healerReach`, its distance to the nearest one over that healer's reach; `waited`, seconds at that
  healer's spot without a heal (`Unit.waitFrom`, `Unit.healedAt`, set by a heal, Healing Prayer and the
  after-wave heal); `rank`, how many falling back at the same spot have more HP; `frontFighters`, melee
  troops not falling back; `foeToBase`, tiles from the back line to the nearest monster; `ranged`;
  `backRoom`, tiles to the back line.
- **The rule, as shipped** (`RuleRetreatPolicy`):
  - with no troop healer that has marched in, it fights on;
  - it falls back at or below `retreatAt` 50% of its HP, and fights on again at `returnAt` 80%;
  - **heals that don't come:** after `healWait` 3 s at the healer's spot without a heal, the one with the
    most HP there goes back in if it has at least `earlyReturnAt` 60%. Then the next one waits its turn
    the same way.
- **Parts switched off** (in the brain, each by its 0 / false; the A/B in decisions-log 96 found they didn't
  help): falling back early when the damage it takes would fell it within `doomTime` s (below
  `doomMaxShare`); going back in when fewer than `lineMin` melee troops still fight, or at anything above
  `retreatAt` when a monster is within `baseThreat` tiles of the back line; never going back in early into
  damage that would fell it; `holdFire` (a melee troop falling back strikes only when cornered: at the
  healer's spot or the back line); `carryHealQueue` (a new wave keeps the after-wave heals still to come,
  units-and-combat.md, and a healer ready to heal gives the next of them before its own heals).
- **Where:** toward the nearest healer, until within `retreatNear` 0.5 of that healer's reach (the priest's
  96 → 48), not all the way to the back line. It walks with `_moveToward` (steering and give-way apply: it is
  a mover, so idle troops step aside). The healer rests on the rest line above, so falling back never takes a
  troop out of sight or behind the back line (which stays put all wave, #79). Walking back
  is never sped up. Going back in, it walks to the fight like anyone else: at the catch-up pace if it fell
  behind (`speedTo`), and a light melee keeps within `paceLead` of the heavies (`paceLimit`; a heavy falling
  back isn't the front it keeps to).
- **Fighting:** it doesn't chase. With `holdFire` off (as shipped) it still strikes a foe in its reach,
  facing it as it backs off (`_strike`, the same attack as when fighting).
- **Healers** take retreating troops first (`_heal`, above).

## The healing necromancer (`_mend`)

The owner wanted it further back ("jangan terlalu depan, harusnya dia lebih sering di belakang untuk
support"), and then not standing there undecided ("ai necromencer healer juga masi suka diam bingung antara mau heal
dan dan melarikan diri", decisions-log 314). The priest's `_heal` rules don't apply to it. What it is doing is
`Unit.mend` (`Mend`: `rest`, `hold`, `toHeal`, `heal`, `backOff`, `swing`, `alone`; not saved), and a choice sticks:
it changes when it is done or no longer holds, never back and forth tick by tick.

- **Rest spot:** a tile behind (right of) the REARMOST monster, never past `rightLimit`. From there it is
  moved further right until it is `mendClear` (half a tile) out of the troops' reach. While a wave is still coming on,
  that is the right edge of the screen. Several healers spread a lane apart around the monsters' middle y,
  top to bottom as they stand (`_topDown`, #82: by their order of coming, two crossing at the same x pushed
  against each other for ~19 s in a repro; #82's one monster change).
  - An escort's healer (#90, from wave 50) rests a tile behind its own mini boss or boss instead, never the
    rearmost monster, and spreads with the rest of that escort around its boss's lane. Only the melee troops
    push it back (`escortMeleeOnly`), and at most `escortReach` 64 behind its boss. Once its boss falls it rests
    like the others.
  - **Held there** (`Mend.hold`): a rest spot still in a troop's reach + `necroSafety` (the right limit or `escortReach`
    stops the push), or one whose straight way runs through a reach (looked at a tile at a time), isn't walked into: it
    stands where it is. Until 314 it walked in to the margin, backed off a tick, walked in again: an escort's healers
    flipped about 5 times a second there on the owner's wave-60 save, standing still to the eye.
- **Safety:** it keeps `necroSafety` 2 tiles outside the reach of every hitting troop it can get away from (an
  escort's healer by its own boss: only the melee troops' reach, units-and-combat.md "The healer"). Troop healers don't
  count: they only smite it (holy damage) when none of theirs needs healing, from their line at the back.
  - **A reach it can't get out of doesn't count** (decisions-log 314): a troop whose reach + `necroSafety` takes in both
    ends of the edge it may back off to (x = max(`rightLimit`, its x), y half a tile from the top and the bottom)
    reaches every spot it may stand on. A late army's archers do: 570-656 on the w89 save, about 1150 on the owner's
    wave-58 army, with a view about 324 wide. It neither backs off from such a troop nor keeps its heal spots out of its
    reach: it heals under its fire. Until 314 every spot was "too close", so it stood pinned at the right edge (or past
    it, not yet on) and healed only what came within its reach: 300 of 366 healer-seconds on the owner's wave 59.
  - **Backing off:** when a troop comes closer than that, it backs off a tile at a time, straight away from the troop
    reaching furthest into its margin, and goes on until it is `mendClear` clear (it doesn't stop on the margin). Never
    right of `rightLimit` (one that hasn't come on yet, still right of it, doesn't back off further right at all). Held
    by that edge it goes along it, up or down away from the troop (away from the middle when level with it). When it
    can't move at all (cornered in a corner of the edge) it holds, and heals or swings at what it reaches from there.
    Without the cap a late archer (a bow reach of 150 px and more) chased the healers off the right of the screen, the
    monster they healed followed the archer, and the wave never ended: 3 of 12 auto-player runs stalled at wave 30
    once the view stopped following the foremost troop (#85, decisions-log 123).
- **Healing:** it picks the most hurt monster it may heal: hurt, in no other healer's window (units-and-combat.md,
  "The healer"), and in range or with a heal spot; an escort's healer picks its own boss first when it may. The heal
  spot is where it is now if that monster is in range (and its heal is ready, or it isn't too close there). Else it is
  on the ring at 0.9 × range round that monster: straight on its way first, then turned 40° and 80° to either side
  (`mendTurns`), the first that is `mendClear` outside the reach of the troops it keeps from, with a clear straight
  way there (an escort's healer's spot for its boss: behind the boss, outside the melee troops' reach). It walks only
  that far, heals as soon as it is in range, and falls back when there is nothing more to do. When a heal isn't ready
  and a troop is too close, it steps to a heal spot that is clear, or else backs off, instead of waiting there.
  - **Commitment:** the monster it walks to heal (or waits in range to heal) is kept `mendCommit` 1 s, needing then only
    a heal spot outside the reach (not `mendClear` beyond it), unless it is healed, in another healer's window or out
    of its reach; an escort's boss still comes first. After that it looks again for the most hurt.
- **Can't heal** (MP below `necroHealCost`, or nobody hurt it can safely reach): it swings at a troop in
  its scythe's reach, taking at most one short step to it. It never walks toward the troops to find a
  fight; otherwise it backs off, goes to its rest spot or holds.
- **Alone** (no other monster standing): it walks on toward the nearest troop, swinging at troops that reach it,
  so a wave can't stall on it; with no troop standing it waits (until decisions-log 329 it walked on toward the back
  line, like a monster with nobody to fight).
- `speedTo` (below) is troops only.
- Probe (a fixed army over 10 seeds, waves 5–20, while other monsters stand):
  - share of time inside a troop's reach + 1 tile: 42–57% before, 0–20% after;
  - mean distance to the nearest troop: 37–47 before, 50–69 after.
- Measured through the Board (1600×947, 16 ms frames) before and after decisions-log 314, on the owner's wave-58 save
  (waves 59 and 60) and the w89 save (wave 90):
  - healer-seconds standing still with the MP for a heal and a hurt monster about, not waiting out its heal's
    interval in range: 309 → 4, 661 → 14, 42 → 4;
  - heals a healer-minute: 2.9 → 28, 9.3 → 26, 28 → 33;
  - turns between walking in and backing off within a quarter second of the last: 0 → 1 (it never walked in),
    4878 → 11, 1352 → 3;
  - a healer's mean life: 73 → 34 s, 90 → 53 s, 16 → 13 s (it now heals within the archers' reach), every one killed
    in both.

## Nobody is left behind the fight (`speedTo`)

Melee with boots used to leave unbooted long range and healers far behind: 10–12 tiles with 4–6 boots on
the knights, too far to shoot or heal before the melee had won. Then (#56, the owner: "para troops bisa
saja off cam jika mereka tertinggal dan baru lari cepat ketika wave selesai") the melee too: the heavies
walked in far behind a fight the light melee had already started. `speedTo(u, to)` is the speed of every
walk a troop makes toward the fight or its spot: melee and long range walking to their foe (long range also stepping up to their hold, units-and-combat.md), and healers
walking to their rest spot or to the hurt.

- **Reference:** the rearmost melee (line 2) of those in the fight (attacked in the last `_engagedFor`
  2s), or of all entered melee if none is fighting. A fresh melee walking up from the back doesn't stop
  the catch-up once a fight is on.
- **Too far behind:** more than its rank's place, `(2 − line)·tile`, plus `_catchUp` 1.5 tiles behind
  that melee. That is 24 for melee, 40 for long range and 56 for healers. The supports' distances stay
  inside their reach of the melee's foe (archer 64, priest 96). A melee catches up only once a fight is on
  (with none, the rearmost melee is its own reference: while walking in, the light melee wait for the
  heavies instead, below). `Game.meleeCatchUp` (on) switches the melee's part, for probes and tests.
- **Then** it walks at max(its own walk, the fastest living melee's walk), but never more than `Game.catchUpMost`
  2× its own walk (decisions-log 309, the owner: "Batasi 2×") nor its walk cap (`walkCap`, 6× its type's base:
  decisions-log 311, units-and-combat.md "The walk cap"), and at its own walk again once back within that gap. Its
  walk is `Unit.walkSpeed` (its speed stat, capped). It never goes faster than the fastest melee. Melee keep their boots' edge. Until 309 the fastest melee's pace
  had no cap: on the owner's wave-30 save a booted Hero knight's 275, 8.6–13× an archer's or a wizard's walk, so a
  troop catching up or bought mid-wave slid there. Now supports behind fast booted melee trail them further (an
  archer behind knights with 4 boots: 84 units behind at the most, 39 before) and a troop bought mid-wave arrives
  later. Since 311 a booted knight (105 on the owner's wave-30 save) catches up or marches in at 144, not 210.
- **Bought mid-wave:** still marching in (`entered` false), it walks at that pace all the way to its spot
  (#61: it comes from left of the view).
- **Out of sight:** a troop whose middle is more than `offViewBy` left of the view (`cam`) walks up at
  that pace, however near the melee (#61). Once the wave has shown a fight the trigger moves in with the
  keep-up floor: less than `keepUpInset` − `offViewBy` (1.5 tiles) inside the edge (#85, camera-and-field.md).
- **Never:** before a wave or after a win (`waveActive` false: the walk to posts), with no melee alive,
  when walking backwards (`to.x <= pos.x`: falling back), or while kiting (that walk doesn't use it, even
  when it heads forward).

## Light melee keep near the heavies (`paceLimit`)

The owner (#56): "para pasukan light armor mele yang ada di depan itu mundur jika terlalu jauh dengan
pasukan heavy armor". The heavy-armored melee (`Unit.heavyArmor`: knight_templar, armored_axeman, speed 18)
fell far behind the light melee (soldier, knight, swordsman, lancer: 22–28, more with boots).

- **The limit:** mid-wave, a light melee walking in doesn't pass `paceLead` 2.5 tiles ahead of the
  foremost heavy walking in (entered, alive, not falling back). On its way to its spot (or where it waits
  for one) it stops at that line; already past it, it steps back to it (`_moveToward`), still facing the foe.
- **No limit** (`Game.paceLimit` null): while it is in the fight (it struck or was struck in the last
  `_engagedFor` 2 s, `_inFight`: it doesn't turn away, nor wait under a skeleton archer's shots; a foe in
  its reach is fought as always), once any heavy is in the fight (the same test), with no
  heavy walking in, for a foe not past the line, before a wave or after a win, and in the stall march
  (#39). `Game.heavyPace` (on) switches it, for probes and tests.
- Once the fight is on, the heavies left behind catch up (`speedTo`, above).

## The front stops at the view's right edge (`frontCap`, decisions-log 324)

The owner, of 312's elastic leash (the melee walked up to 1.5 tiles past their supports' line and dropped back to it from
3 tiles past): "yang troops maju mundur ini mungkin batas maksimal maju adalah sejauh kanan kamera, jadi yang paling depan
akan iddle atau attack saja tapi tida bisa maju lagi jika troops di belakang ada yang ketinggalan" (the troops going
forward and back: maybe the furthest they may go is the camera's right edge, so the front-most just idle or attack, but
can't go further while troops behind lag). So there is no line and no walking back; the view itself is the bound.

- **The cap** (`Game.frontCap`): mid-wave `capInset` a tile inside the view's right edge, `cam + viewW − capInset`, so a
  troop there is on the screen with its sprite and bar. No troop that has marched in walks past it (`_capWay`, in
  `_moveToward`: a way that runs past it ends where it crosses the cap). A melee troop whose spot or foe lies past it walks
  as far as the cap at its pace and stands there facing its foe; a foe in its reach it fights wherever it stands. One
  already past it (the view went back) stands where it is: it never steps back for the cap. A shove never pushes a troop
  past it, and the view gliding left leaves it where it is (after the shoves, as `rightLimit` holds the monsters); a
  troop carried by a move (a leap, a charge) lands where its move takes it. Standing at the cap is no walk, so the stall
  detector stays quiet.
- **The army stays together round the fight** (the owner, after the first cut in develop: "battle harus tetap di tengah
  layar, karna dengan pendekatan sekarang malah para mele di ujung kanan dan para healer ke di ujung kiri camera,
  harusnya para healer ikut maju agar battle field kembali ke center camera"): the view centres the battle point as
  before (#85, camera-and-field.md); it doesn't wait for anyone. The healers rest at most `healBehind` 2.5 tiles behind
  the rearmost melee in the fight ("Healers mid-battle"), the long range stand at their hold, and when the melee go on
  the supports follow at their pace (the catch-up pace when they fell behind, `speedTo`); a healer far behind walks up
  before it heals, unless one is at half its HP or less ("Left behind"). A troop far behind (bought
  mid-wave, revived) comes up at the catch-up pace; the view doesn't wait for it. With the fight in the middle, the cap
  is a safety that seldom binds. (The first cut held the view back so the rearmost troop stayed 2 tiles inside its
  left edge: the melee stood at the right edge and the healers at the left one.)
- **None** (`Game.keepSupports` off): before a wave and after a win, and in the stall march.
- **Kept:** the healers' walk-in and walk-up ("Healers mid-battle"), the catch-up pace (`speedTo`), make-way, the light
  melee's `paceLimit`, the melee spots (#84), the stall detector and `rightLimit`.
- **No wobble** (the owner's "maju mundur" itself: a troop moving forward keeps moving forward, or stops): without the leash the melee crowd the fight, and the spots' and the waiting's own turns came forward. Each
  turnaround charged to the step that made it (an instrumented copy of the game): of 5.9 turns of a tile a
  troop-minute with the cap alone (owner's wave 30, 1600×947), a troop that lost its spot walking back to wait 1.75, a
  spot taken again 1.47, walking back to wait after stepping aside 1.02, shoves 0.60, steps aside 0.43; on w89 23.2,
  the wait point jumping with the nearest foe 7.0. So a waiting troop stays at its x ("Waiting" above), a melee troop
  holds before it turns (`turnHold`, above), and mid-wave an ally's shove moves x as the two stand apart in x
  ("Walking without shoving").
- **Measured** (the owner's wave-30 save through the board, five dice, and w89's waves 90 and 91; main with 312's leash
  → now; 1600×947 | 915×412 | w89 at 1600×947): turns of a tile a troop-minute 6.60 → 2.55 | 3.20 → 3.03 | 7.36 → 0.47,
  of 6 units 28.0 → 8.0 | 18.1 → 7.7 | 21.3 → 8.4; a support out of sight 0 → 1.6 | 0 → 8.2 | 32.9 → 14.2 s a wave;
  healers behind the rearmost melee in the fight at the median 110 → 64 | 126 → 96 | 130 → 70 units; the fight shown
  off the view's centre 16 → 23 | 21 → 30 | 13 → 20 units on average (the view 324 | 477 | 324 wide); a melee troop at
  half its HP or less out of every healer's reach 0.4 → 0.0 | 0.1 → 1.2 troop-seconds; the wave 83.5 → 66.6 | 84.4 →
  78.9 | 142 → 129 s; troops lost 0 → 0.2 | 0.2 → 0.6 | 2.5 → 1.5 a run; no life lost. What's left out of sight is the
  melee's rush on a wide view: the fight goes on faster than twice a priest's walk, and the view doesn't wait.
- **Until 324** (decisions-log 312) the melee were on an elastic leash on `supportLine`, the least of each healer's x
  plus its heal reach and each long range's plus its hold (at most 0.4 of the view): a melee troop walked to at most
  1.5 tiles past it and, one more than 3 tiles past it, dropped back to it. The supports stayed on the screen, but the
  melee went back and forth: the walk to the leash and the drop back were 2.57 of 5.07 turns of a tile a troop-minute.
