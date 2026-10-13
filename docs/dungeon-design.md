# The Dungeon (design)

Purpose: the design of the Dungeon, a mode entered from a Town where a small party explores floors and fights in real
time, before it is built: its rules, its numbers, its screens, how it sits in the code and the milestones that build
it (decisions-log 336). Nothing here is in the game yet; each milestone moves what it builds into the documents that
describe the game (game-overview.md, units-and-combat.md, ui-hud.md, …) and marks it built here.

## What the owner asked for

- A mode entered from a Town. No waves: **floors**, and the deeper the floor, the fiercer its monsters.
- The player **moves his character** (a virtual joystick on a touch screen, WASD on the desktop) and, at the same time,
  **picks what it does** (attack, a skill, an item).
- **A small party**: he moves the leader; the others follow and fight on their own.
- Monsters don't all come at once: they **appear at random places**, and a unit must **get near enough to reach**
  before it can hit (the attack range matters).
- **Aggressive** monsters attack on sight; **neutral** ones attack only once they are attacked.
- The fight is not the tower-defence rules: every unit has a **gauge** that fills with time (its speed) and acts when
  full, and the party members follow **gambits**, rules of the form "when this, do that".
- Free exploration, but the party **can't leave at any time**: only at the **save points** spread over each floor.
- The art: the GandalfHardcore platformer set the Town already uses, so the Dungeon is **side view**, like the field.

The owner's reference was a description of another game's real-time party battles. This design takes the mechanics he
asked for and describes them in our own words; no name or text of that game goes into the game or this repository.
"Gambit" is used as the common English word (a chess opening's planned move).

## 1. Entry and exit

- **The door.** Every Town, from the first (before wave 7 at the earliest), has a cave mouth at its street's far end: a
  mossy rock mound with a dark portal at its foot, two lit torches and the Town's sign ribbon "Dungeon" (mockup D). A
  tap on it (or the Town book's new **Dungeon** tab beside Smithy, Shop and Tavern) opens the Dungeon page: pick the
  party (section 2), pick the floor to start on, and **Enter**.
- **Free trips while in the Town** (the owner's answer, decisions-log 336): a **trip** lasts from Enter until the
  party leaves at a save point or falls; back in the Town the player may craft, sell, buy, change the party and go
  in again, as often as he likes, until "Leave town".
- **Each Town has its own dungeon.** The first trip in a Town makes it: its floors come from the Town's seed (section 9),
  and it lasts until "Leave town"; the next Town makes a new one. What happens in it stays for every trip of that
  Town: a room's monsters that fell stay fallen, cleared rooms stay empty, opened crates stay open; monsters that lived
  through a fight go home and mend. So the trips of one Town share one fixed amount of loot, the floors' contents down
  to where the party can go: leaving and coming back never refills anything, and a Town can't be farmed (section 7).
- **The start floor**, on the door's page: floor 1; the save point where the last trip of this Town left or last
  rested ("Back to Floor 4"); or the deepest floor the run has reached (its arrival save point touched), "Floor 6". The run remembers its
  deepest floor (`dungeon.deepest` in the save); a new Town's dungeon is new even there.
- **The wave run waits.** While the party is inside, the run stays in the Town as it was left: no wave can start,
  Auto Wave's countdown stops, the Tavern's boosts (counted in waves) don't run down, and the rest of the army waits in
  the Town. Coming back puts the player in the Town again, where "Leave town" goes on to the next wave as before.
- **Leaving only at a save point.** A save point is a campfire on the floor (the pack's animated campfire). Each floor
  has two: one where the party arrives and one about halfway. Walking into its light, with no monster hostile to the
  party, shows two buttons:
  - **Rest:** saves the trip, heals every member to full HP and MP, revives the knocked out, and **banks** the loot
    carried since the last rest (section 7). The trip resumes from here after the game is closed.
  - **Leave:** back to the Town with everything carried and banked. The trip is over; the next one may start here.
- **A party wipe** (every member knocked out): "The party fell". Back to the Town; **only the loot carried since the
  last Rest is lost** (the owner: "Hilang loot yang dibawa saja"), the banked loot is kept, and the trip is over.
  **No heart is lost and no troop dies**: the Dungeon's knock-outs are not the field's deaths. The deepest floor
  reached still counts, the monsters the party felled stay fallen, and the player may go in again.

## 2. The party

- **Up to 3 members**, picked on the Dungeon page from the army's living troops: any type, Heroes too. The page shows
  the army as the Bag's slot cells (portrait, name, the type's power); a tap adds or removes one.
- **Their numbers are the army's:** `Game.statsOf` with everything that raises a troop (items, Awaken 1-5, Forge,
  Train, the heavies' buff, a Hero's tripled attributes, a Hero's aura on the other members), the troop's small relics
  and its type's Pusaka where their effect is a fight's (a hit, a heal, a kill; the ones that count waves or the
  army's size do nothing inside; the full list is written when M4 audits them). Not the Tavern's boosts (they belong
  to waves), not the tide, not "Weakened foes". HP and MP start full.
- **No reserve**: the three picked at the door are the trip's party (the owner agreed); another trip may take others.
- **The leader** is the member the player moves; the camera follows it. The lead switches at any time: a tap on a
  member's card, Tab, or 1-3 on the keyboard. A knocked-out member can't lead; if the leader is knocked out the lead
  passes to the next standing member.
- **Following.** Each follower keeps a spot behind the leader by its role: melee 24 units behind, long range and
  healers 40-56 behind, spread 20 units apart in depth. Farther than 32 units from its spot it walks there by a path
  on the floor's grid (section 9); farther than 400 (off screen, after stairs) it is put beside the leader.
- **Fighting.** Followers fight by their gambits (section 4). They leave their spot to fight but never chase a foe
  more than 160 units from the leader: past that they turn back to the leader.
- **Knocked out** at 0 HP: the member lies where it fell (its death strip's last frame) and its card greys. It is
  revived by a **Rest**, or by a Hero priest's Resurrection. Monsters lose interest in it.

## 3. The fight: gauges in real time

- **Every unit has a gauge** (party and monsters). It fills over the unit's **turn time** and the unit acts when it is
  full; then it empties and fills again.
  - Turn time = 2 × the unit's time between attacks on the field (`Game.attackEvery`, with everything that changes it:
    gloves, Train's rate, War Cry, Rampage, the Rage Tonic, a slow), at least 1.0 s. A soldier's 0.8 s attack is a 1.6 s
    turn, a wizard's 1.4 s a 2.8 s turn, a unit at the attack floor (0.3 s) a 1.0 s turn.
  - An **Attack** deals the unit's damage × turn time ÷ attack time (2× a field blow; at the floor 3.3×), played as
    two swings or two shots. So every unit does the same **damage per second** as on the field, and everything that
    makes a troop strong on the field makes it strong here.
  - A stun stops the gauge; slows make it fill slower; haste faster.
- **Reach.** An action fires only when its target is within the unit's reach (the field's rule, `reaches`: its range
  plus the slack). Melee reach is 12-27 units, a body or two; long range 60-96. Until then the action waits.
  - **Followers** walk into reach by themselves.
  - **The leader** goes where the stick says. When the stick is let go with an action waiting, the leader walks into
    reach by itself (the owner agreed; a setting turns it off for players who want to close in by hand). Out
    of reach, the target line shows red and "Out of reach" (mockup A).
  - Units act standing: a melee unit stops to swing, an archer stops to shoot; moving never empties the gauge.
- **The commands** (the leader's; the buttons at the bottom right, mockup A):
  - **Attack** (J or Space): attack the target. It stays the leader's order, every time the gauge fills, until the
    target falls or another command is given.
  - **Skill** (K): the list of the leader's skills: its type's skill, its Hero skill, its Awaken skill, each with its
    MP, its reach and its cooldown (the field's costs and cooldowns). A skill takes the full gauge, the MP and its
    cooldown. Area skills centre on the caster or the target as on the field.
  - **Item** (L): the four pocket slots (loot-items-relics.md "Pocket items", decisions-log 332), from the Bag's
    stock, with the field's cooldowns. Every kind works inside: the bottles, the Rage Tonic, the Iron Draught, Holy
    Water and the Pocket Watch act on the party; the bombs on every foe on screen. An item is instant (no gauge).
  - **Lead** (Tab): the next member leads.
  - **Target**: the leader's target is the nearest foe ahead until the player picks one: a tap on a foe, or Q / E for
    the previous / next foe on screen. The target wears the red pointer (ui_icons.png's red arrow).
  - There is no Flee: walking away is fleeing (monsters give up at their leash, section 5), except in a boss arena.
- **Wait and Active.** In **Wait** (the default) time stands still while a list is open (Skill, Item, the book,
  the gambit editor): the field dims and a ribbon says "Paused: pick a skill" (mockup A, the menu). The Attack
  button, a tap on a foe and Lead never stop time. **Active** keeps time running with a list open. A chip at the top
  right switches them; Settings keeps the choice.
- **Desktop keys:** WASD or the arrows move; J / Space Attack; K Skill; L Item; Q / E target; Tab or 1-3 lead; G
  gambits on/off; Esc the book (pause). The buttons show their key (mockup A at 1600x947).
- **Touch:** the joystick at the bottom left (a large slot from ui_all.png with ui_icons' arrows and a knob), the
  action buttons at the bottom right (Attack the largest), the party cards along the top on a phone and at the bottom
  centre on a large screen. Every control is at least 44 px (ui-hud.md).

## 4. Gambits

- **Each member has an ordered list of rules**, each "condition → action", each with its own On/Off. When the
  member's gauge fills (and the player gave it no command), the rules are read from the top: the **first rule whose
  condition finds a target and whose action can be paid** (MP, cooldown, an item in stock) is what it does. If none
  fits, it follows the leader.
- The leader's rules are **off** by default (the player plays it); turning them on lets the leader fight by itself
  while the stick is idle. A command from the player always wins over the rules for that gauge.
- **"Gambits on"** at the top right (G) switches every member's rules on or off at once.
- The rules are **the troop's own**, saved with the troop (its save entry), so a troop taken again keeps its rules.
  A troop that never had any starts from its type's default list.
- **Slots:** 4 rules a member at first, one more the first time the run reaches floors 5, 10, 15 and 20 (8 at most).
- **Conditions** (the free ones in bold; the others are found in crates, section 7, one new one a floor's first crate
  until all are found; once found, every member may use it):

  | Ally | Foe | Self |
  |---|---|---|
  | **HP < 50%**, HP < 70%, HP < 30% | **nearest**, **the leader's target**, **targeting me** | **HP < 30%**, HP < 50% |
  | knocked out | targeting an ally, lowest HP, highest HP | MP ≥ 50% |
  | being hit, stunned | in reach, 3 or more close together | always |
  | MP < 30%, the leader | undead, shoots, elite or stronger, hostile | |

- **Actions:** **Attack**, each of the member's own skills (type, Hero, Awaken), each pocket item kind (the shared
  stock and cooldown), **Follow** (back to the leader), Keep away (long range: step back out of a melee foe's reach).
- **Default lists** by type (the rules a troop starts with):

  | Type | 1 | 2 | 3 | 4 |
  |---|---|---|---|---|
  | soldier | Self HP < 30% → Hold Fast | Foe targeting an ally → Attack | Foe the leader's target → Attack | Foe nearest → Attack |
  | knight | Foe 3+ close → Circle Slash | Foe targeting an ally → Attack | Foe the leader's target → Attack | Foe nearest → Attack |
  | swordsman | Foe elite or stronger → Rampage | Foe the leader's target → Attack | Foe nearest → Attack | |
  | archer | Foe 3+ close → Arrow Rain | Foe lowest HP → Attack | Foe the leader's target → Attack | Foe nearest → Attack |
  | lancer | Foe 3+ close → Piercing Thrust | Foe the leader's target → Attack | Foe nearest → Attack | |
  | priest | Ally HP < 50% → Heal | Ally HP < 70% → Healing Prayer | Foe undead → Attack | |
  | axeman | Foe 3+ close → Crushing Blow | Foe the leader's target → Attack | Foe nearest → Attack | |
  | wizard | Foe 3+ close → Arcane Blast | Foe the leader's target → Attack | Foe nearest → Attack | |
  | templar | Ally being hit → Holy Shield | Foe targeting an ally → Attack | Foe nearest → Attack | |

  A Hero's or an Awaken skill goes in the first free slot with its role's usual condition (a heal under 50%, an area
  hit on 3+ close, a buff on "being hit"). "Heal" is the healer's plain action (its attack on an ally).
- **The editor** (mockup C) is a page of the book, opened from the book (Esc, or the book button) at any time; in
  Wait it stops time. The left page: the three members as icon chips (the leader's crown on its chip), then the
  chosen member's rules as rows: the number, the On/Off capsule, the condition capsule → the action capsule, and up /
  down arrows to reorder; locked slots are grey slots ("Slot 5: reach Floor 5"). A tap on a capsule opens the right
  page's picker: tabs (Ally / Foe / Self for a condition; Attack / Skills / Items for an action) over the choices as
  paper-card slots, the ones not found yet grey ("in crates"). Rows are 44 px at 915x412 (1 more below scrolls).

## 5. Monsters

- **The roster** is the field's: the 12 monster types, the necromancer and the necro healer, with their sprites, rank
  recolours, HP bars, signature skills (high elites and up) and boss moments.
- **Temperament** by type:

  | Aggressive (attack on sight; aggro radius in units) | Neutral (attack once hit) |
  |---|---|
  | bat 72, skeleton 96, skeleton archer 128, werewolf 128, armored skeleton 80, orc rider 128, greatsword skeleton 96, necromancer 160 | slime, orc, elite orc, armored orc, werebear |

  - The undead, the wolves, the riders and the bats hunt; the slimes, the orcs on foot and the bears mind their own.
  - A **neutral** monster that is hit turns hostile and **calls its kind** within 96 units (the orcs fight as a
    gang; slimes and bears don't call). Once hostile it stays hostile until it is back home (below).
  - The **necro healer** never starts a fight: it follows the nearest hostile monster and heals as on the field.
  - Deeper is fiercer here too: from floor 10 the elites and stronger of the neutral types are aggressive (radius 96),
    and from floor 15 every aggro radius is 25% wider.
- **Marks:** a hostile monster shows ui_icons' yellow "!" over its HP bar; a neutral one shows none (mockup A).
- **Chase and leash.** A hostile monster chases the party member nearest to it (or the one that hit it last). It gives
  up past its **leash**, 320 units from where it appeared, or after 10 s without reaching anyone: it walks back home,
  mending 20% of its HP a second, a neutral one neutral again, an aggressive one aggressive again once home.
- **Appearing at random places.** Each room holds its monsters (count and kinds rolled with the floor). When the
  party comes within a screen of the room, they appear at random free points of its floor (never within 96 units of
  its entrance or a save point), one or two at a time over 3-6 s: the undead rise out of the necromancer's summon
  circle (`tiny_fx_summon`), the bats drop from the ceiling, the rest walk out of the back wall's tunnel holes. At
  most 6 at once in a room (3-4 on floors 1-4).
  - **Ambush rooms** (from floor 4, one room in six): the monsters appear only when the party reaches the room's
    middle, on both sides of it.
  - **No respawn** (the owner agreed): a room's monsters appear once per Town's dungeon, whatever the number of trips
    (section 1). Going back through a cleared room is safe, and a floor can't be farmed.
- **Strength by depth.** A floor's monsters use the field's numbers (`enemyStats`) at the floor's **depth wave** =
  3 + 4 × (floor − 1): floor 1 is wave 3, floor 5 wave 19, floor 10 wave 39, floor 20 wave 79. So HP, damage, walk,
  attack speed and defence grow with depth exactly as with waves; the types come from the field's pool for that wave
  (`poolOf`), so the early floors hold slimes, bats, skeletons and orcs. No tide and no "Weakened foes" inside.
- **Ranks by depth:** elite 5% + 2% a floor (40% at most); high elite from floor 4, 2% + 1% a floor (20% at most); a
  **mini boss** guards the stairs from floor 3; every 5th floor ends in a **boss arena** (its entrance closes behind
  the party until the boss falls; no leaving through it): any type made a boss as on the field, the necromancer from
  floor 10. The boss buff (`bossBuff`) follows the depth wave.
- Monsters' gauges follow the party's rule (turn time 2 × attack time, double blows), so a monster also hits as hard
  a second as on the field.

## 6. Floors

- **A floor is a side-scrolling level**: 6-10 rooms in a row, left to right. The party arrives at the left end (the
  arrival save point), a second save point stands about halfway, and the stairs down (the portal) are at the right
  end, guarded by the mini boss's room (from floor 3) or the boss arena (every 5th floor). Walking into the portal goes
  down; the floor below starts at its arrival save point.
- **Made from hand-made rooms**: a few dozen room templates, picked and mirrored by the floor's dice (the Town's
  dungeon seed and the floor number: every trip of a Town meets the same floors, section 9):
  - a **hall**: a wide floor band (96-112 units deep), 1.5 screens long;
  - a **corridor**: a narrow band (48 deep), one screen;
  - a **cavern**: pillars and boulders to walk round;
  - a **pool**: water across part of the band, a plank bridge over it;
  - an **ore vein**: ore rocks at the wall's foot;
  - a **grave room**: gravestones and crosses, where the undead rise;
  - a **supply nook**: a stack of crates (the treasure, section 7).
- **The floor band.** Every room is the same side view (mockup A): the dark cave behind, the ceiling's stalactites at
  the top, the back wall's earth slabs and pillars with their tunnel holes, torches on the wall, a moss (rust, frost)
  line where the wall meets the floor, then the floor band the units walk on, in x and in depth, then the near ledge.
  Rooms differ in length, band depth, blockers and props.
- **Size:** a room is 400-900 units long; a floor 4,000-6,000 units, about 5-10 minutes with its fights.
- **The camera** follows the leader sideways (the leader kept between 35% and 65% of the width), stops at the floor's
  ends, and keeps the band's whole depth in view. Its scale follows the field's rule (about 200 world units of height
  on screen: ×4.5-4.9 at 1600x947, ×2 at 915x412).
- **Depth themes** from the pack's three seasonal sets: floors 1-4 Mossy Halls (green moss, the brown earth), 5-9 Rust
  Caves (the autumn tops, the red earth BG Dirt2), 10-14 Frost Deep (the snow tops); from 15 they repeat with Floor
  Tiles1's browner earth. The floor's number always shows.
- **Later (M4):** side rooms behind the back wall's tunnels (walk up into a hole: the screen fades to a small side
  room, a nook or a shortcut).
- **Not planned:** traps (no art for them).

## 7. Rewards and economy

- **Drops lie on the ground** where a monster fell, as on the field (their icons, the field's look): its materials by
  the field's drop table and its rank (Common, Rare, the trophies), and gold. A party member walking over a drop picks
  it up; when a room's last monster falls, the room's drops fly to the leader (the field's win sweep).
- **Gold:** half the field's kill gold at the depth wave (`dungeonGold` 0.5 × `killGold`). The Hero skill Plunder adds
  its share as on the field.
- **Crates** (the pack's stacked crates, one stack a floor in its supply nook, more on deep floors): the party breaks
  them with attacks. A floor's crates give gold, a pocket item or two, the floor's first gambit condition or action
  not found yet (section 4), and from floor 5 a Rare part.
- **Carried and banked.** What the party picks up is **carried** until a Rest or Leave **banks** it (into the Bag and
  the gold); a wipe loses the carried loot (section 1). The HUD shows carried gold and the Bag's count.
- **How it ties in:** the materials go to the Bag like the field's, so the Smithy crafts with them, the Shop buys
  them (at the market's prices: selling many of one kind still lowers its price, loot-items-relics.md "Towns: the
  market"), and the deep floors are a second source of the late monsters' Rare parts that Train needs (Bear Claw, Orc
  Heart, Iron Tusk, Teal Gem, Dark Gem, Wolf Fang, Warg Fang, Bone Bow).
- **What keeps the wave run's balance:** one dungeon per Town whose fallen stay fallen however many trips (so a Town
  pays at most its floors' contents down to the party's depth), no respawn, half gold, depth gating the strong parts,
  and the telemetry (section 9) measuring a Town's trips' gold and materials against the waves to the next Town; they
  are weighed after the build (the probe plan, section 10).
- **If a Town's dungeon still pays too much**, the levers in that order: fewer drops on a floor already reached in an
  earlier Town (×0.5 on the run's floors above the deepest), the drop chances rolling down with each trip of the same
  Town (×0.8 a trip after the first), `dungeonGold` lower.
- **A hunt chain** (M4): killing the same monster type again and again raises a chain ("Chain 4: Orc");
  every third step gives one more Common part roll, from the sixth +10% Rare chance; another type's kill or a Rest
  breaks it.
- The scoreboard stays the wave run's; the deepest floor shows on the Dungeon page and in the run's summary.

## 8. View and art

**Side view with a 2.5D floor band** (the owner's pick; mockup A), compared with a platformer (mockup B):

| | A. Floor band (x and a shallow depth) | B. Platformer (run, jump, platforms) |
|---|---|---|
| Movement | the joystick and WASD map one to one: up/down is depth | left/right only; a jump button on top of the four actions |
| The fight | the field's: reach is a distance on a 2D floor, three members and six monsters spread in depth, melee can surround | reach across two levels (who can hit whom on a ledge?), everyone in a line |
| Following and monsters | paths on a 2D grid, as the field moves | followers and monsters must jump gaps: hard to make reliable, falls |
| Our units | walk, attack, hurt, death strips are all it needs | the Tiny RPG units have no jump or climb frames |
| The pack | floors, walls, ceiling, props all fit | made for it, but no ladders |
| The screen | the band in the middle, the HUD in the corners | the ground ends under the bottom HUD on a wide screen |

Platformers read as "a dungeon" more at first sight, but the band keeps our combat, our pathing and our sprites as
they are and plays well with a joystick; the owner chose A.

- **Scale:** one pixel of the pack is one world unit, as the units' (the Town's rule); drawn at the field's screen
  scale (section 6).
- **Depth sorting:** units and the props on the band are drawn by their feet's y (nearer = lower = later), as the field
  does; the wall and its props behind, the near ledge in front. The units' shadows (`tiny_<type>_shadow`) make depth
  readable.
- **Facing:** units face left or right by where they walk or what they hit, flipped as on the field.
- **What the pack gives a cave** (each piece mapped before use, then cut by exact boxes or cells by a new import
  tool, as the Town's `tool/import_town.py` does):
  - `Floor Tiles1/2.png`: the dark earth fill (the cave behind and above), the moss / autumn / snow top edges (the line
    at the wall's foot and the near ledge), the stalactite ceiling piece (cells 7-8 of the block rows), floating
    platforms;
  - `BG Dirt1/2.png`: the earth slabs with two tunnel holes and the pillars (the back wall; the holes are where
    monsters walk out); BG Dirt2's red earth for the Rust Caves;
  - `Other Tiles1/2.png`: the plank strips and the stone post (bridges over pools), rocky slopes;
  - `Ores.png` (four crystal rocks), `Torch.png` (the wall torch, lit, 6 frames; the standing one at the door),
    the animated water and waterfall (pools), `Decor.png` (rocks, boulders, gravestones, a cross, crates, barrels, a
    cauldron, a brick wall), the portal (the stairs and the door's mouth), the campfire (the save points), the Angel
    Statue (a boss arena's entrance).
- **What is missing:**
  - a treasure chest (none in any pack: the crates stand in);
  - traps (none: no traps);
  - a gate for the boss arena (the Decor brick wall standing in the way until the boss falls, or new art);
  - a cave back wall that tiles (the wall is the dark fill with the slabs placed on it, which reads well in mockup A);
  - light: no darkness or glow effect; the torches are the light. A dark vignette would be drawn in code, so it is
    not planned.
- **The HUD** uses the game's kit: the top row's dark panels (the field's), ui_bars.png's portrait frame with three
  bars for each member's card (HP green, MP blue, the gauge yellow), the field's 12×8 HP/MP box over every unit with a
  thin gauge under the party's, ui_all.png's slots for the action buttons and the joystick, ui_icons.png's icons (the
  sword, the bolt, the crown, the "!", the red pointer, the small marks of the target line), ui_bars' capsules for
  chips, the book for the gambit editor, ui_ribbons.png for "Paused: pick a skill".
- **Drawn in code (exceptions for the owner):** none planned in the game. The mockups' dashed aggro ring is a design
  aid only, and the pause button's two bars were drawn for the mockup (the game has its own).
- **Mockups** (made from the packs and the game's images, not in the repository; the owner looked at them before
  approving), each at 1600x947 and 915x412:
  - A, a floor band in a fight (the party: knight leader, archer, priest; an aggressive skeleton chasing, a neutral
    orc, a slime; a save point; the gauges, the action buttons, WASD or the joystick);
  - A with the Skill list open in Wait;
  - B, the same scene as a platformer;
  - C, the gambit editor;
  - D, the door in a Town.

## 9. How it sits in the code

- **One `Game`, a dungeon mode.** The skills, effects, shots, heals, hits, statuses, relics and pocket items are
  written against `Game` (extensions over `units`, `shots`, `t`). So the Dungeon runs **inside the run's own `Game`**
  while it is in a Town: `Game.dungeon` (a new `Dungeon`, lib/dungeon.dart) is non-null during a trip; the army's
  units are set aside and the party's and the room's monsters are `units`; `Game.tick` hands the tick to the dungeon's
  rules (`_dungeonTick`) instead of the field's waves, formation, march and stall. The per-unit helpers (attack,
  shots, `hitTaken`, effects, `_trySkill`'s casts) are shared; where the field's own rules are inside them (targeting,
  where melee stand, the back line), M1 opens a seam (the decision of *who* and *where* comes from the mode).
  On leaving, the party's members go back to the army (healed, as the field's troops between waves) and the set-aside
  units return.
- **The tick:** the field's (`g.tick(min(dt, 0.1) × speed)`), Speed x1/x2 too. Order per tick: the leader's input,
  each unit's decision (the player's command, else its gambits; monsters: temperament, leash, target), movement (paths,
  separation as the field's), gauges, actions that fire, shots and effects, knock-outs, drops and pickups, room
  spawns, the camera.
- **Lib files (new):** `dungeon.dart` (the trip, floors, rooms, spawns, temperament, leash, gauges, loot),
  `dungeon_gen.dart` (rooms from templates by the dice), `gambits.dart` (conditions, actions, the reading of a list,
  defaults by type), `dungeon_nav.dart` (the walk grid, A*), `dungeon_scene.dart` and `dungeon_art.dart` (drawing,
  the tile rects the import tool writes), `dungeon_hud.dart` (cards, buttons, joystick, the Skill / Item lists),
  `gambit_page.dart` (the editor), `dungeon_page.dart` (the door's page in the Town book).
- **Walls and collision.** Each room has a walk grid of 8-unit cells over its band (a 900 × 100 room is 113 × 13
  cells); props marked solid, water and pillars block cells. Units are circles (the field's body sizes) kept out of
  blocked cells and apart from each other by the field's separation. The leader's stick moves it at its walk speed
  (the walk cap applies), sliding along blocked cells.
- **Paths:** A* on the grid, 8 directions, for followers (to their spot or into reach) and monsters (to their target
  or home); a path is re-asked at most every 0.25 s per unit, or when its goal moved more than 16 units. The grids are
  small, so this is cheap.
- **Dice and determinism.** The Dungeon has its own dice (`dungeonDice`), like `names`, `loot` and `matDice`, so a
  trip never shifts the wave run's rolls. A Town's dungeon seed comes from the run and the Town count; a floor's layout
  and its rooms' monsters (kinds, ranks, count) from (that seed, the floor number); where they appear, the fights and
  the drops from the dungeon dice. Tests and probes run a trip at a fixed `dt`
  and get the same floor and fights.
- **Save** (lib/save.dart): new keys with defaults, so older saves load unchanged (no `saveVersion` step unless a
  milestone needs one):
  - `dungeon`: `deepest`, `slots`, `found` (the conditions and actions found); `town`, the Town's dungeon (its seed,
    the Town count it belongs to, per floor reached the rooms cleared, the monsters fallen in rooms half fought, the
    crates opened, and the save point the last trip left from), dropped at "Leave town"; and while a trip is saved at
    a Rest, `trip`: its floor, save point, the party (the troops by name, which no two living troops share, and their
    HP/MP) and the banked loot so far;
  - each troop's `gambits` in its own entry.
  A Rest saves the game (it is still "between waves"); a relaunch mid-trip resumes at that save point.
- **Telemetry** (`GameEvent`s, telemetry.md; `eventVersion` +1): `TripStarted` (Town, the trip's number in it, start
  floor, the party's types, Heroes, power), `FloorReached` (floor, time), `TripRest` (floor, point), `TripEnded` (left / wiped, floor, time,
  gold and materials banked, lost), `DungeonKill` (type, rank, floor, by whom), and per trip the gambit and command
  counts (rules fired, menu commands, items). They answer: how deep does an army of wave W go, how many trips a Town
  takes, and does a Town's dungeon pay more than the waves to the next Town.
- **Reused:** `Stats`, `statsOf` / `fieldStats`, `Unit`, `enemyStats`, `Tier`, `bossBuff`, `poolOf`, `killGold`, the
  drop tables, the skills (type, Hero, Awaken, monster), shots and effects, pocket items (their scope adapted: the
  party / the foes on screen), the Bag, the unit drawing (`_frame`, outlines, rank tints, awakening looks), the
  `fx_hit_*` effects, the sounds, the book, the S0 kit's slots and capsules, `Words`, the HUD font.
- **Art pipeline:** `tool/import_dungeon.py` (stdlib, like `import_town.py`) cuts the pieces from the pack's sheets by
  their mapped boxes and cells into `assets/images/dungeon_*.png` (tiles, wall pieces, props, the campfire, the
  portal, torches, water), with `--check`; the new files go on the release allowlist, the asset manifest and the
  asset vault, and assets.md's table.
- **New words** (`Words`, ui-hud.md "In-game text"): Dungeon, Floor, Save point, Rest, Leave, Gambits, Lead, Out of
  reach, Wait, Active, "Back to Floor 4", "The party fell", Chain.

## 10. Milestones

Each one is playable on its own and goes through the full checks (decisions-log 273).

1. **M1: one floor (L).** The door in the Town and its page (the party of 3, Enter); one generated floor of 4-6 rooms
   in the Mossy Halls look; WASD and the joystick; the party following on paths; monsters appearing at random points
   as the party nears, aggressive and neutral, aggro radius, chase, leash; gauges; Attack by reach (melee and shots)
   with the field's damage per second; the default gambits running (no editor); knock-outs; the arrival save point
   (Leave) and the portal at the end (back to the Town: "Floor cleared"); a wipe back to the Town. The HUD: party
   cards, Attack, the joystick. The import tool and the art. *The owner sees: walk a cave, fight by reach, monsters
   that hunt or mind their own.*
2. **M2: commands and gambits (L).** Skill, Item and Lead; targeting (tap, Q / E); Wait and Active; the skills
   (type, Hero, Awaken) through the commands and the rules; pocket items inside; the gambit editor in the book; slots
   and the free conditions and actions (every one unlocked while M3's crates don't exist yet).
3. **M3: floors and depth (XL, may split in two).** Stairs down and floors by depth (depth wave, themes, ranks, the
   mini boss at the stairs, the boss arena every 5th floor); two save points a floor with Rest; the deepest floor and
   the start choices at the door; the Town's dungeon (free trips, the fallen stay fallen until "Leave town"); drops,
   pickups, carried and banked loot, gold; crates with the gambit finds; slots by floor.
4. **M4: saves, telemetry and polish (M).** The trip saved at a Rest and resumed after a relaunch; the telemetry
   events; the hunt chain; ambush rooms; side rooms; the relics' and Pusaka's audit inside; How to Play's cards and
   the guide's first pointers; sounds. Then the probe plan (below) runs.

**Probe plan** (after the build, never on its way to main), with the owner's saves at waves ~10, 30, 60 and 90 and the
default gambits, the leader's rules on, no player input:
- **Depth:** the deepest floor an army reaches, a floor's time, knock-outs, wipes. A problem: past floor 15 at wave
  30, or under floor 3 at wave 60.
- **A Town's pay with free trips:** a bot that goes in, clears down to where it wipes or a floor takes over 10 minutes,
  leaves at a save point, comes back and repeats until nothing is left above its depth; the total gold and materials
  banked in that Town against the gold and materials of the waves to the next Town (the run's own telemetry). A
  problem: the Town's dungeon pays more than those waves, or a Rare part Train needs comes faster than one a Town.
- **No refill:** after a trip, another trip of the same Town finds every felled monster still gone and every crate open,
  and its pay is only what was left; the same after a wipe.
- **The levers** if the pay is too high are in section 7.

## 11. The owner's answers (decisions-log 336)

1. The view: **A, the side-view floor band** ("a. 2.5D pita kedalaman").
2. A wipe: **only the loot carried since the last Rest is lost** ("Hilang loot yang dibawa saja"); no heart, no troop.
3. Trips: **free while in the Town** ("Bebas selama di kota"), not one a Town; the Town's dungeon (section 1) keeps it
   from being farmed.
4. Everything else as proposed ("Setuju semua"): the leader walks into reach by itself (a setting turns it off), no
   reserve, no respawn, gambits 4 → 8 slots with conditions found in crates and the word "Gambits", the hunt chain in
   M4, the door in every Town from the first, Wait as the default on every device.
