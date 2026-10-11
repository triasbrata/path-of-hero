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
| Separation | `_personalSpace` 12 keeps units apart. Between troops the yielder moves: sideways, and backwards for non-melee before a wave. A healer mid-cast holds its ground, and so does a carried unit, a braced troop or one under `noShove` (`_firm`): the other one yields, or (troop against monster) takes the whole push. Between two troops a stand a troop gave itself (the Pusaka Anchor's, all wave) doesn't count: it holds against the monsters, and its troops still part. A unit in a leap's air or charging (`_passesThrough`) is skipped, and so is a pair of troops where one walks through its allies (`_ghost`: `arriving`, or the stall detector's moment), and so are two spot mates (below). Between two monsters, one walking into one that stands takes the whole push and slides round it (`_slideRound`, units-and-combat.md "Fighting rules"). |
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
  and takes the first spot that frees (it looks again every tick).
- **Reach** (`reaches`): a unit reaches a foe within its reach plus `spotSlack`. The separation parts two bodies
  to exactly 12, a melee unit's reach, give or take a rounding error; without the slack one a hair out stepped in
  again, shoving, instead of striking.
- Long range, healers and hurt troops falling back keep their own rules (the long range's hold and kite,
  units-and-combat.md "Long range hold"; `_heal`; `_fallBackTo`). The walk
  to a spot keeps the catch-up pace (`speedTo`) and the light melee's `paceLimit` (below).

## Healers mid-battle (`_heal`)

- Fighters = those attacked in the last `_engagedFor` 2s (else all), so a fresh troop at the back
  doesn't pull the healers back.
- Rest line = max(max(baseX, cam + keepUpShift) + tile/2, rearmost fighter − tile): never behind the back
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
- **Left behind** (decisions-log 312): between heals (its cooldown running) one more than a tile behind its rest walks
  up toward it at the catch-up pace, never past it, and stands again to cast. A long reach kept it where it stood, and
  so held the melee on their leash ("Melee keep their supports in reach", below) for the whole wave.
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
- **Alone** (no other monster standing): it walks on toward the back line like a monster with nobody to
  fight, swinging at troops that reach it, so a wave can't stall on it.
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

## Melee keep their supports in reach (`supportLine`, decisions-log 312)

The owner: "make sure jangan sampai support teringgal dan membuat heal mereka tidak masuk dan off screen" (the
supports must not be left behind, their heals out of reach, off the screen), then, of a first cut that stopped the
melee at a line and held them there: "ini para trops sekarang seperti berbaris, yang aku maksud adalah mereka dinamis
bisa maju tapi ketika terlalu maju mereka akan turun lagi ke belakang dan jangan pasif dan berdiam saja" (they line up
now; they should push on, drop back when too far ahead, and never stand idle). So the melee are on an elastic leash.

- **The line** (`Game.supportLine`, one for every melee troop, found once a tick): for every troop healer and long
  range on the field (entered, not joining), alive, not falling back nor carried, its x plus its working reach (a
  healer's heal reach, a long range's hold, `holdAt`), never more than `supportView` 0.4 of the view's width
  (`viewW`), less `supportSlack` half a tile; the least of them. Past it a melee troop is out of a healer's reach, or
  fights a foe the long range don't cover. A long range with a foe in its reach already works and doesn't count (a
  kiting one's steps back would only tug the line). The line comes forward at once and goes back at `leashEase` half a
  tile a second at most, so a support's step back (a healer going to the hurt, a long range losing its foe) doesn't
  yank the melee.
- **No leash** (no line) with `Game.keepSupports` off, before a wave and after a win, in the stall march, with no
  support on the field, and for anyone but a melee troop on the field, not falling back.
- **The leash** (`leashCap` 1.5 tiles): a melee troop walking to its spot or its foe goes no further than `leashCap`
  past the line. With its way past it, it takes the nearest monster it can fight without going further (its near
  side, `spotRing` in front of it, within the leash; already past the leash, level with it or behind it) and walks
  to it at the catch-up pace; with none, it walks its way up to the leash and stands there facing its foe until the
  supports come up. A foe in its reach it fights wherever it stands, the leash or not. The light melee's
  `paceLimit` (above) holds while it is the nearer of the two.
- **The drop back** (`leashOut` 3 tiles, `Unit.leashed`, not saved): one more than `leashOut` past the line (a fight
  that drifted on, a shove, the line going back) walks back to the line (`leashBack` 0), facing its foe and striking
  what it reaches, so the monsters follow it into the supports' reach. At the line it is free again: the leash
  above. Falling back to a healer (`_fallBackTo`) comes first. Standing at the leash is no walk, so the stall
  detector stays quiet.
- **Why those numbers:** a first spec (the leash at 1.5 tiles, a drop back from past 2 tiles to half a tile inside
  the line) turned the melee back and forth: a shove of 8-10 units at the leash set it off, then a 40-unit walk back
  and one forward again, 29 turns of a tile or more a troop-minute on the owner's wave-30 save against 6-8 before.
  Another bound the spots themselves (no spot past the leash): melee waited beside monsters whose spots lay past it,
  and the wave took 60% longer on one dice. 1.5 tiles between the leash and the drop back, and back to the line only, keep the
  turns at the level before.
- **Measured** (the owner's wave-30 save played through the board, five dice, at 1600×947 and 915×412, before →
  after): a support out of sight 61.8 → 0 and 34.7 → 0 s a wave; a melee troop at half its HP or less out of every
  healer's reach 5.0 → 0.0 and 16.7 → 0.9 troop-seconds; heals 244 → 211 and 237 → 216; melee standing out of a fight
  with monsters about 93.5 → 95.5 and 144 → 113 troop-seconds; turns of a tile or more 5.9 → 5.5 and 4.7 → 3.9 a
  troop-minute (of 6 units or more 17.1 → 25.8 and 12.2 → 18.8: the push and pull itself, about two drop backs a
  melee troop a wave); the wave 78.6 → 90.5 and 87.7 → 92.5 s, no troop lost. The first cut (a melee walking to a
  foe, out of a fight, stopped at the line and held) had the supports out of sight 4 s but the melee standing 812
  troop-seconds.
