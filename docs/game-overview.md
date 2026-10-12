# Game overview

Purpose: what the game is and how a round plays, for someone who has never seen it.

**Path of Hero** (the owner's name for it; the repo, folder and Dart package are still
`tower-defense` / `tower_defense`, dev-workflow.md): a Plants-vs-Zombies-like side-scrolling lane
battle, built in Flutter + Flame with the Tiny RPG character sprites. The owner's words: "mirip plants vs zombie tapi troopsnya bebas bergerak" — like PvZ,
but the troops move freely.

## A round

0. **Welcome.** The game opens on a welcome screen: the title over the forest and the meadow, with "Continue"
   (back into the saved game, its wave shown) and "New Game" (a fresh game; over a save it asks
   "Sure?" first, because the save is deleted).
1. **Setup.** The field is 8 lanes of a grassy meadow under a pine forest. Troops stand in the deploy zone on the left. The
   player taps a troop's slot on the hotbar at the bottom of the battle screen (the spawn bar, on a raised step of the
   ground, with "+Room" and "Auto Buy" beside it; ui-hud.md "Spawn bar") to buy that troop, mid-wave too. It marches in
   from off screen on the left and takes its place in the formation: healer | long range | heavy melee | front melee.
   The book's Army page shows each type's detail; buying left it (decisions-log 283).
2. **Wave.** The green "Start" button at the top starts a wave; during the wave the same button pauses it, and while
   paused resumes it. With "Auto Wave" on (beside the wave meter), the next wave starts by itself 5 s after a win. Monsters come from the right in random lanes. Everyone fights
   freely: troops chase, long range kite, healers follow behind and heal. The camera keeps the battle
   mid-screen. The back line stays where it is all wave, however far the army fights its way forward.
3. **Win.** When the last monster falls, the troops cheer in place. The back line moves up to the
   rearmost troop (only now), and the troops walk back to their spots. If a healer is alive, the healers heal
   everyone hurt. Gold bonus and the materials lying on the ground (they fly to the Bag) are collected, and the game
   auto-saves.
4. **Town.** Now and then the next wave waits behind a Town (loot-items-relics.md "Towns"): a safe stop between two
   waves, never a wave itself, warned a wave ahead on the wave meter (the first before wave 7 at the earliest, then
   at least 5 waves apart). Its Smithy crafts the items and the small relics from the monsters' materials (and from
   wave 30 enhances items), its Shop sells the materials that have dropped and buys back what the Bag holds (in every
   Town), its Tavern sells boosts for the next 2 waves (offered three at a time, gacha-style; loot-items-relics.md
   "Towns: the Tavern"); a drag, the wheel or a trackpad's swipe pans it sideways to look around; "Leave town" goes on
   to the next wave (with Auto Wave on, 5 s after coming in).
5. **Lose.** A monster crossing the back line costs a life, half a heart: a game starts with 3 hearts
   (6 lives). When the whole army falls mid-wave the wave is lost, not the game (decisions-log 322): it costs a heart,
   the wave's monsters cheer a moment and are swept off, and the same wave is played again after a break to buy the
   army back ("Your army fell! -1 heart. Wave N again."). Its win's gold, Hero, boss chest and Town come only when it is
   won. Game over at 0 lives (3 hearts = 3 chances); then the monsters cheer. The score (kills by rank, won waves) goes
   on the scoreboard under the player's name, asked the first time ("Scoreboard", also on the welcome screen).

## What the player manages

- **Gold:** paid per kill (more for higher ranks, most for the boss, and a little more every wave) and per
  won wave. It buys troops, and "+Room" (room for 2 more troops; the army starts with room for 6). At
  most 36 troops are alive and each troop type has a cap of its own; "Release" frees a type between waves
  (decisions-log 141, 201, 260).
- **Items** (crafted at a Town's Smithy, never dropped since the forge, decisions-log 272; per troop TYPE, stacking up
  to the type's caps): 14 kinds in three grades (I, II, III): sword, shield (defence), boots, bow, gloves, potion
  (regen; a healer also heals more), staff (magic power, for the wizard and the priest only, who take no sword),
  amulet (max HP), prayer beads (heals), torch (against the undead), spear (melee reach), prism (splash), and outside
  the recipes a cap (less damage taken) and a ring (MP regen). From wave 30 the Smithy enhances an item up to +5.
- **Awakening:** a troop type that takes its whole item recipe awakens (up to 3 times), each level in its own grade
  (Awaken 1 grade I, 2 grade II, 3 grade III): an outline, shadow and sparks in the level's colour (blue, crimson,
  gold), a recoloured hit effect, triple price, more HP and MP (the Amulet aside, the only way they rise), and room for
  the next grade.
- **Materials:** every monster type drops its own parts (30 kinds, about three times as many as before the forge),
  lying where it fell until the wave is won, then into the Bag for the Smithy.
- **Tavern boosts** (a Town's Tavern): eleven kinds from Common to Legendary, each for the next 2 waves: the Feast
  (every troop +20% damage, 15% less damage taken), damage, max HP, damage taken, attack speed, MP regen, kill gold, a
  forgiven leak a wave, or the Champion's Plate for one troop type; as many as the gold buys, cheap at the first
  Towns, a reroll of the unbought ones doubling in price.
- **Relics** (one per troop, a Hero two): crafted at a Town's Smithy from materials, items and gold, twenty small
  relics in three tiers: seven Basic (fang, thorns, fury, guard and the forge's chill, shark tooth and grit), seven
  Strong and six Mighty (assets/config/town.json `relics`).
- **The store** (a Town's Shop, open in every Town): sells only the materials
  that have dropped (2.5x their sell price), no item or small relic (the Smithy makes them); what is in the bag sells
  back (items and relics for half their worth). Its Artifact shelf (five overpowered artefacts) opens only in a game
  without the Boss Chest: on the board the chest is the Artifacts' one source.
- **Awaken 4-5** (Bangkit 4-5 in the code, #92 part 2): a type at Awaken 3 buys two more awakening levels with gold
  on its Army page (40k, then 100k), between any waves from wave 15 won: violet, then white, more HP and MP, ×1.25 damage a level and a shorter
  awakening-skill cooldown.
- **Forge** (Tempa in the code, decisions-log 163): past Awaken 5 the same Army page keeps selling levels, "Forge +1",
  "Forge +2", …: +5% HP and damage each, compounding, for a fifth of a late wave's gold, ×1.2 a level. A dot on the
  Army tab says when gold piles up (3 waves' worth) and something there can be bought.
- **Fallen Heroes** (Hero Gugur in the code, #92 part 3): a fallen Hero is kept, and its type's Army page calls it
  back ("Recall") between waves for about one wave's income (42k at wave 65): the same name,
  attributes and skill; its relics stay in the bag. With the army full it swaps: one troop of its type goes home for
  half its price and the Hero takes its place.
- Before a wave, troops on the field can be dragged to another cell of the zone.
- Speed x1/x2.

Every troop type has one skill (Hold Fast, Arrow Rain, Healing Prayer…) that a troop casts by itself,
paid with its MP. Every 10th wave won, one troop becomes a **Hero** (at most 5 alive): two of its
attributes tripled to fit its role, and one of five skills of its type's own (a one-second cut-in shows
each cast). Details: units-and-combat.md.

Monsters come in ranks (normal, elite, high elite, mini boss, boss), each in its own colour on the body
and the HP bar; any type can hold any rank. Every 3rd wave adds a mini boss, and every 5th the boss (waves
15, 30… bring both): any monster type made a boss, or from wave 10 sometimes the necromancer, which raises
skeletons (never on wave 5, a new army's first boss).
The strong ones (high elites, mini bosses and the boss) drop the rare materials and the trophies, and also cast
skills of their own (so far seven types have one). From wave 35 the Tide makes the crowd a little
stronger and quicker to come every wave (the wave meter shows "+35%" on wave 65), and the troops that fell in a won wave can
be bought back in one press ("Replace fallen" on the Army page).

A first-time guide (ui-hud.md "Guide"): seven intro cards after a device's first "New Game" (or from "How to Play" on
the welcome screen), then pointers that show where to tap through the first waves (buy a troop, "Start", give the first
item to a type), and a one-time card between waves (the first Town's in it) when each system first matters (one a break, waiting for the win's
"VICTORY!", a new Hero's splash and the boss chest). Settings' "How to Play" page holds every card by topic, with
the game's own item, relic and Pusaka texts, and plays the intro again ("Replay guide").
