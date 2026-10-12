import 'dart:collection' show MapBase;
import 'dart:convert' show jsonDecode, jsonEncode;
import 'dart:math';

import 'names.dart';
import 'retreat.dart';
import 'words.dart';

export 'names.dart';
export 'retreat.dart';
export 'words.dart';

part 'hero_shots.dart';
part 'game_events.dart';
part 'hero_moves.dart';
part 'battle_focus.dart';
part 'hero_skills.dart';
part 'awaken_skills.dart';
part 'monster_skills.dart';
part 'monster_skill_moves.dart';
part 'monster_skill_signatures.dart';
part 'boss_skills.dart';
part 'skill_strips.dart';
part 'store.dart';
part 'ascend.dart';
part 'tempa.dart';
part 'recall.dart';
part 'pusaka.dart';
part 'pusaka_catalog.dart';
part 'artifact_icons.dart';
part 'pusaka_engine.dart';
part 'omen.dart';
part 'omen_catalog.dart';
part 'draft.dart';
part 'engage.dart';
part 'heal.dart';
part 'cleanse.dart';
part 'town.dart';
part 'market.dart';
part 'relics.dart';
part 'enhance.dart';
part 'tavern.dart';
part 'wishlist.dart';
part 'auto_replace.dart';
part 'wipe.dart';

const tile = 16.0;
const cols = 20, rows = 8; // one screen: cols x rows of battlefield under the backdrop
const deployCols = 3; // troops are placed in the leftmost columns; the zone starts this wide, a column more per capacity purchase ([Game.zoneCols])
// The army's size limit ([Game.capacity]): where it starts, how much one purchase adds, and its price (the
// first, then this much more for each bought: 40, 50, 60, ...).
const capacityStart = 6, capacityStep = 2, capacityPrice = 40, capacityPriceRise = 10;
// The owner's limits (decisions-log 141, 201): at most [armyMaxBoard] troops alive whatever the capacity, and at most
// [typeCapBoard] troops of each type alive ([Game.typeCap]). The board turns them on ([Game.boardRules]); a plain Game()
// leaves them off, so tests and probes play as before. 36 since decisions-log 260 (the owner, 2026-10-07: "yang mana
// batas atasnya harusnya memang 36"; 32 until then), the same at every screen size ([Game.maxCapacity]).
const armyMaxBoard = 36;

/// How many troops of one type may be alive at once on the board (decisions-log 201; the owner, 2026-10-03: "user tidak
/// bisa beli lebih dari 5 priest, tidak bisa beli 20 archer supaya game tetap balance"): the healer 5, the long range 8,
/// the melee 10. No type fills the army alone ([armyMaxBoard] 36), nor do three (10 + 10 + 10 = 30); four do unless the
/// healer is one of them (10 + 10 + 10 + 5 = 35); any five do.
const typeCapBoard = {
  'soldier': 10,
  'knight': 10,
  'swordsman': 10,
  'archer': 8,
  'lancer': 10,
  'priest': 5,
  'armored_axeman': 10,
  'wizard': 8,
  'knight_templar': 10,
};
const autoHoldShare = 0.75; // Auto's countdown waits while fewer than this share of [Game.armyCap] are alive ([Game.autoHeld])
const releaseRefund = 0.5; // Lepas jenis ([Game.releaseType]): each troop sent home pays back this share of its price
const fieldH = rows * tile;
const deathTime = 0.6;
const victoryTime = 2.4; // troops cheer in place this long after a won wave, then return to their spots

enum Side { troop, enemy }

enum Face { side, up, down }

/// Sound cues queued by the logic and played by the UI; names match assets/sfx/*.wav (tool/gen_sfx.py). [leak] was a
/// monster over the back line; since decisions-log 329 it is the alarm of a stalled wave's monsters charging.
enum Sfx { place, sword, dagger, magic, hit, kill, fall, leak, wave, clear, error, lose, click }

/// [cost] is the base price for troops (what one costs now: [Game.priceOf]) and the gold reward for
/// enemies. [shotSpeed] 0 = melee;
/// melee with [splash] cleaves everyone around the target.
class Stats {
  final int hp, cost, mp; // mp: the most MP it holds (0: it has none; troops don't spend theirs yet)
  final bool heals, dark;
  // regen: HP back per second; def: taken off every blow ([hitTaken]); mpRegen: MP back per second
  final double speed, dmg, range, rate, shotSpeed, splash, regen, def, mpRegen;

  /// What a blow that got past its defence still does to it: 1, less with the forge's Cap and Helm ([upgraded];
  /// decisions-log 249). [Game._hurt] cuts by it after the Guard relic.
  final double taken;

  /// The forge's (decisions-log 251): the farthest a melee fighter's reach goes ([meleeMaxRange], raised by the spear's),
  /// its blows on the undead ([dark] foes) times [darkK] (the torch's), and the product of its heal multipliers
  /// ([healK], the prayer beads'), which a potion's or a staff's added heal takes too, so the order items were taken in
  /// doesn't matter.
  final double reachCap, darkK, healK;

  /// Healers restore [dmg] HP to the most hurt ally in [range] instead of attacking. [dark] monsters (the
  /// undead) are hurt by a troop healer's heal instead ([holyShare]).
  const Stats({
    required this.hp,
    required this.cost,
    required this.speed,
    required this.dmg,
    required this.range,
    required this.rate,
    this.shotSpeed = 0,
    this.splash = 0,
    this.heals = false,
    this.dark = false,
    this.regen = 0,
    this.def = 0,
    this.mp = 0,
    this.mpRegen = 0,
    this.taken = 1,
    this.reachCap = meleeMaxRange,
    this.darkK = 1,
    this.healK = 1,
  });

  Stats _with({int? hp, int? cost, double? speed, double? dmg, double? range, double? rate, double? splash, double? regen, double? def, int? mp, double? mpRegen,
          double? taken, double? reachCap, double? darkK, double? healK}) =>
      Stats(
          hp: hp ?? this.hp,
          cost: cost ?? this.cost,
          speed: speed ?? this.speed,
          dmg: dmg ?? this.dmg,
          range: range ?? this.range,
          rate: rate ?? this.rate,
          shotSpeed: shotSpeed,
          splash: splash ?? this.splash,
          heals: heals,
          dark: dark,
          regen: regen ?? this.regen,
          def: def ?? this.def,
          mp: mp ?? this.mp,
          mpRegen: mpRegen ?? this.mpRegen,
          taken: taken ?? this.taken,
          reachCap: reachCap ?? this.reachCap,
          darkK: darkK ?? this.darkK,
          healK: healK ?? this.healK);

  /// Fights up close: neither shoots nor heals (the formation's front and heavy melee).
  bool get melee => shotSpeed == 0 && !heals;

  /// These stats with [item] carried, its effect [k] (the game gives each item its own number, [Game.itemK],
  /// decisions-log 249; null: its kind's grade-I number, [swordDmg] …). A bow never takes a melee fighter's reach past its [reachCap]
  /// ([meleeMaxRange] unless spears raised it) (nor shrinks a longer base reach); a potion also makes a healer's heals
  /// [potionHeal] HP bigger (a grade's in the share of its regen to grade I's). The staff is magic power: a healer's heals
  /// [staffHeal] HP bigger (a grade's in the share of its bonus to grade I's), anyone else's attack ×[staffDmg]; both added
  /// heals times the prayer beads' [healK]. The Cap and Helm cut the damage taken ([taken]), the Ring adds MP regen (both
  /// only with their number). The forge's five (decisions-log 251), only with their number: the amulet's max HP ×[k] (no
  /// other item raises HP; awakening does, [Game.statsOf]); the prayer beads' heal ×[k] (only a healer's, and with it its
  /// holy damage on the undead); the torch's blows on the undead ×[k] ([darkK]); the spear's melee reach ×[k] and its
  /// [reachCap] ×[k] (only a melee fighter's; [Game.statsOf] then stops both at the spear's ceiling, town.json
  /// `items.spear.reachMost`); the prism's splash ×[k] (only for a type with splash; up to its ceiling,
  /// `items.prism.splashMost`). None of the forge's items is ever given while it is off.
  Stats upgraded(Item item, [double? k]) => switch (item.slot) {
        ItemSlot.sword => _with(dmg: dmg * (k ?? swordDmg)),
        ItemSlot.shield => _with(def: def + (k ?? shieldDef)),
        ItemSlot.boots => _with(speed: speed * (k ?? bootsSpeed)),
        ItemSlot.bow => _with(range: melee ? max(range, min(range * (k ?? bowRange), reachCap)) : range * (k ?? bowRange)),
        ItemSlot.gloves => _with(rate: rate * (k ?? glovesRate)),
        ItemSlot.potion =>
          _with(regen: regen + (k ?? potionRegen), dmg: heals ? dmg + (k == null ? potionHeal : potionHeal * k / potionRegen) * healK : dmg),
        ItemSlot.staff => _with(dmg: heals ? dmg + (k == null ? staffHeal : staffHeal * (k - 1) / (staffDmg - 1)) * healK : dmg * (k ?? staffDmg)),
        ItemSlot.helm when k != null => _with(taken: taken * k),
        ItemSlot.ring when k != null => _with(mpRegen: mpRegen + k),
        ItemSlot.amulet when k != null => _with(hp: (hp * k).round()),
        ItemSlot.beads when k != null && heals => _with(dmg: dmg * k, healK: healK * k),
        ItemSlot.torch when k != null => _with(darkK: darkK * k),
        ItemSlot.spear when k != null && melee => _with(range: max(range, min(range * k, reachCap * k)), reachCap: reachCap * k),
        ItemSlot.prism when k != null && splash > 0 => _with(splash: splash * k), // then [Game.statsOf]'s ceiling
        ItemSlot.amulet || ItemSlot.beads || ItemSlot.torch || ItemSlot.spear || ItemSlot.prism || ItemSlot.helm || ItemSlot.ring => this,
      };

  /// These stats [k] times as strong (a Hero, or a Hero's aura): HP, damage (a healer's heal), defence,
  /// regen, MP and speed times [k], attacks [k] times as often, and reach times [k], except that a melee
  /// fighter's stops at its [reachCap] (a longer base reach isn't cut).
  Stats boosted(double k) => k == 1
      ? this
      : _with(
          hp: (hp * k).round(),
          dmg: dmg * k,
          def: def * k,
          regen: regen * k,
          mp: (mp * k).round(),
          mpRegen: mpRegen * k,
          speed: speed * k,
          rate: rate / k, // the pause between attacks
          range: melee ? max(range, min(range * k, reachCap)) : range * k);

  /// These stats with a Hero's [picked] attributes ([HeroStat]) [k] times as strong the way [boosted] makes
  /// them, and the rest [rest] times (another Hero's aura, or 1). HP is the most HP (its regen stays), MP
  /// comes with its regen.
  Stats heroic(Set<HeroStat> picked, double k, [double rest = 1]) {
    final (up, s) = (boosted(k), boosted(rest));
    T? pick<T>(HeroStat h, T v) => picked.contains(h) ? v : null;
    return s._with(
        hp: pick(HeroStat.hp, up.hp),
        dmg: pick(HeroStat.power, up.dmg),
        def: pick(HeroStat.defence, up.def),
        rate: pick(HeroStat.rate, up.rate),
        speed: pick(HeroStat.speed, up.speed),
        range: pick(HeroStat.range, up.range),
        mp: pick(HeroStat.mp, up.mp),
        mpRegen: pick(HeroStat.mp, up.mpRegen));
  }

  /// These stats with the speed at most [walkCap] of [type]: as fast as a troop of it walks (decisions-log 311).
  Stats walking(String type) => speed > walkCap(type) ? _with(speed: walkCap(type)) : this;

  /// The stat [item] raises (by its kind, [Item.slot]): an amulet's is the max HP, the beads' the heal, the torch's the
  /// damage on the undead ([darkK]), the spear's the reach, the prism's the splash, a ring's the MP regen, a helm's the
  /// damage taken ([taken]).
  num statOf(Item item) => switch (item.slot) {
        ItemSlot.sword || ItemSlot.staff || ItemSlot.beads => dmg,
        ItemSlot.torch => darkK,
        ItemSlot.shield => def,
        ItemSlot.helm => taken,
        ItemSlot.boots => speed,
        ItemSlot.bow || ItemSlot.spear => range,
        ItemSlot.gloves => rate,
        ItemSlot.potion => regen,
        ItemSlot.amulet => hp,
        ItemSlot.prism => splash,
        ItemSlot.ring => mpRegen,
      };
}

/// An item's kind (decisions-log 245): the seven an Awaken recipe counts today ([awakenRecipe]), the forge's five new ones
/// (forge-design §10: the amulet's max HP, the prayer beads' heals, the torch's damage to the undead, the spear's melee
/// reach, the prism's splash), then the helm (less damage taken) and the ring (MP regen), which no Awaken recipe counts.
enum ItemSlot { sword, shield, boots, bow, gloves, potion, staff, amulet, beads, torch, spear, prism, helm, ring }

/// An item, made at a Town's Smithy (town.dart; none drops) and used on a troop TYPE: an upgrade goes to
/// every troop of that type, now and later, and stacks up to the type's cap ([Game.capOf], its awakening
/// recipe) (a potion adds [potionRegen]). The staff ("Tongkat Sihir") is for the casters only: only the
/// wizard's and the priest's recipes take it, and they take no sword ([powerItem]). The value is the save key and the
/// icon's name (`item_<name>.png`), so a new one is only ever appended: the first seven are the ones monsters dropped
/// ([droppedItems]), then the forge's 35 (decisions-log 245) by grade: the five new kinds' grade I, grade II of the twelve Awaken kinds, their grade
/// III, then the helm's and the ring's three grades. Each has its kind ([slot]) and its [grade] (1 to 3); how many kinds
/// and grades there are is read from the enum, never counted by hand.
enum Item {
  sword(ItemSlot.sword),
  shield(ItemSlot.shield),
  boots(ItemSlot.boots),
  bow(ItemSlot.bow),
  gloves(ItemSlot.gloves),
  potion(ItemSlot.potion),
  staff(ItemSlot.staff),
  // The forge's 35 (decisions-log 245; forge-design §1, §3, §10, §11), by grade.
  amulet(ItemSlot.amulet),
  prayerBeads(ItemSlot.beads),
  torch(ItemSlot.torch),
  spear(ItemSlot.spear),
  prism(ItemSlot.prism),
  steelSword(ItemSlot.sword, 2),
  towerShield(ItemSlot.shield, 2),
  swiftBoots(ItemSlot.boots, 2),
  longBow(ItemSlot.bow, 2),
  steelGloves(ItemSlot.gloves, 2),
  bigPotion(ItemSlot.potion, 2),
  magicStaff(ItemSlot.staff, 2),
  silverAmulet(ItemSlot.amulet, 2),
  holyBeads(ItemSlot.beads, 2),
  holyTorch(ItemSlot.torch, 2),
  wingedSpear(ItemSlot.spear, 2),
  arcanePrism(ItemSlot.prism, 2),
  royalSword(ItemSlot.sword, 3),
  royalShield(ItemSlot.shield, 3),
  windBoots(ItemSlot.boots, 3),
  greatBow(ItemSlot.bow, 3),
  royalGloves(ItemSlot.gloves, 3),
  elixir(ItemSlot.potion, 3),
  crystalStaff(ItemSlot.staff, 3),
  goldAmulet(ItemSlot.amulet, 3),
  saintBeads(ItemSlot.beads, 3),
  sunTorch(ItemSlot.torch, 3),
  royalSpear(ItemSlot.spear, 3),
  royalPrism(ItemSlot.prism, 3),
  leatherCap(ItemSlot.helm),
  steelHelm(ItemSlot.helm, 2),
  royalHelm(ItemSlot.helm, 3),
  ring(ItemSlot.ring),
  gemRing(ItemSlot.ring, 2),
  royalRing(ItemSlot.ring, 3);

  const Item(this.slot, [this.grade = 1]);

  /// Its kind: what it raises, and what an Awaken recipe counts it as.
  final ItemSlot slot;

  /// 1 (a grade-I item, the kind's first), 2 or 3.
  final int grade;
}

/// The items monsters dropped ([droppedItemKinds]) in a game without the Towns (gone, decisions-log 321), in [Item]
/// order: the first seven kinds' grade I.
const droppedItems = [Item.sword, Item.shield, Item.boots, Item.bow, Item.gloves, Item.potion, Item.staff];

/// The item kinds monsters dropped: the first seven of [Item] (grade I, one of each kind), so the [loot] dice roll as they
/// did before [Item] grew (decisions-log 245).
const droppedItemKinds = 7;

/// A kill's item roll from before the Smithy made every item: a normal or elite monster at [dropChance], the boss
/// [bossDrops] for sure; the [Game.loot] dice still draw them and throw them away (decisions-log 321). [potionRegen]:
/// a potion's HP/s.
const dropChance = 0.08, bossDrops = 2, potionRegen = 5.0;

/// What each item multiplies its stat by ([Stats.upgraded]); the shield adds [shieldDef] defence and the
/// potion [potionRegen] HP/s (and, on a healer, [potionHeal] HP to every heal) instead. The staff
/// multiplies a caster's attack by [staffDmg], like the sword, but adds [staffHeal] HP to a healer's
/// heals (added, like the potion's, so the order items were taken in doesn't matter).
const swordDmg = 1.25, bootsSpeed = 1.25, bowRange = 1.2, glovesRate = 0.8, staffDmg = 1.25;
const shieldDef = 2.5, potionHeal = 3.0, staffHeal = 3.0;

/// A blow loses the target's defence, but always does at least [minHitShare] of itself, and at least
/// [minHit]: nobody is untouchable.
const minHitShare = 0.1, minHit = 1.0;

/// What a blow of [dmg] does to a target with defence [def].
double hitTaken(double dmg, double def) => max(dmg - def, max(minHit, dmg * minHitShare));

/// HP and MP rise only through awakening: every level adds this share of the type's base.
const awakenHp = 0.25, awakenMp = 0.25;

/// Every item a troop type has taken raises its price by this share of its base price (at least 1 gold).
const priceRise = 0.1;

/// The farthest a melee fighter reaches, however many bows its type takes (at every awakening level); the forge's spears
/// raise a type's own cap ([Stats.reachCap], decisions-log 251), up to their ceiling (town.json `items.spear.reachMost`).
const meleeMaxRange = 1.7 * tile;

/// When every [heroEvery]th wave is won one living troop that isn't a Hero yet becomes one ([Unit.hero],
/// picked with [Game.heroes]): [heroStatCount] of its attributes, rolled from its role's pool with the same
/// dice ([heroPoolOf]), are its type's times [heroBoost], the rest stay (the owner: "yang dinaikkan cuma
/// 2 attribute saja bukan semua dikali 3x"). While a Hero lives, every other troop's attributes are times
/// [auraBoost] (+15%), a Hero's other attributes too while another Hero lives; more Heroes don't add more.
const heroEvery = 10, heroBoost = 3.0, auraBoost = 1.15, heroStatCount = 2;

/// At most this many Heroes live at once: a [heroEvery]th wave's win crowns one only while fewer are alive,
/// and a fallen Hero frees its place (the owner: "hero yang sudah mati maka slotnya bisa di pakai lagi
/// untuk hero baru muncul di setiap 10 wave").
const heroMax = 5;

/// A Hero's attributes that can be rolled ([Unit.heroStats]): its HP, its power (a healer's heal), defence,
/// walking speed, reach and MP. Attack rate (attacks [heroBoost] times as often) is in no pool any more
/// (#69); it stays here because old saves name it, and such a Hero rolls that pick again on load.
enum HeroStat { hp, power, defence, rate, speed, range, mp }

/// MP (and its regen) is in every pool: troop skills spend it (#10). False takes it out again.
const heroMp = true;

/// What a Hero may roll, by role ([Unit.line]: 0 healer, 1 long range, 2 melee), only what that role uses
/// (the owner: "harus kontekstual"): melee never rolls reach, which stops at [meleeMaxRange] anyway, and a
/// healer's power is its heal. Defence only for a type that can carry shields ([heroPoolOf]). Never attack
/// rate (#69, the owner: "keluarkan attack speed dari pool attribute hero yang di enhance").
const heroPools = <int, List<HeroStat>>{
  0: [HeroStat.hp, HeroStat.power, HeroStat.defence, HeroStat.speed, HeroStat.range, if (heroMp) HeroStat.mp],
  1: [HeroStat.hp, HeroStat.power, HeroStat.defence, HeroStat.speed, HeroStat.range, if (heroMp) HeroStat.mp],
  2: [HeroStat.hp, HeroStat.power, HeroStat.defence, HeroStat.speed, if (heroMp) HeroStat.mp],
};

/// [type]'s Hero pool ([heroPools] for its role), without defence when its recipe has no shields: its
/// defence is 0 for good, so ×3 would do nothing.
List<HeroStat> heroPoolOf(String type) {
  final s = troopTypes[type]!, shields = awakenRecipe[type]?.containsKey(Item.shield) ?? false;
  return [for (final h in heroPools[s.heals ? 0 : (s.shotSpeed > 0 ? 1 : 2)]!) if (h != HeroStat.defence || shields) h];
}

/// Awakening: what each troop type needs of each item kind to awaken, and at the same time the most of
/// each kind it can take before it does. A type awakens (level 1) the moment it holds its whole recipe;
/// then it can take the recipe once more and awakens again with it (level 2 holds the recipe twice),
/// up to [maxAwaken]. Kinds missing from a recipe never go on that type. Every level multiplies the
/// type's price by [awakenPrice] (×2, Awaken 3 at 8×; ×3, 27×, until decisions-log 318, so a late army's rebuys ate
/// every coin) and gives it the level's colour (round its troops, not on them) and hit effect ([awakeFx]). Past it,
/// gold buys Bangkit 4 and 5 ([maxAscend]).
const awakenRecipe = <String, Map<Item, int>>{
  // front melee
  'soldier': {Item.sword: 2, Item.shield: 2, Item.boots: 1, Item.bow: 1, Item.gloves: 1, Item.potion: 1},
  'knight': {Item.sword: 3, Item.shield: 3, Item.boots: 2, Item.gloves: 2}, // the owner's example
  'swordsman': {Item.sword: 3, Item.boots: 2, Item.gloves: 3, Item.potion: 2},
  // long range
  'archer': {Item.sword: 2, Item.boots: 1, Item.bow: 4, Item.gloves: 3},
  // heavy melee (no bows for the lancer: two already take its reach to [meleeMaxRange])
  'lancer': {Item.sword: 2, Item.shield: 2, Item.boots: 4, Item.gloves: 1},
  // healer
  'priest': {Item.staff: 2, Item.shield: 2, Item.bow: 2, Item.gloves: 2, Item.potion: 2}, // the owner: casters use the staff
  'armored_axeman': {Item.sword: 2, Item.shield: 3, Item.boots: 1, Item.gloves: 2, Item.potion: 2},
  'wizard': {Item.staff: 2, Item.bow: 3, Item.gloves: 3, Item.potion: 2}, // the staff instead of the sword
  'knight_templar': {Item.sword: 2, Item.shield: 2, Item.boots: 2, Item.bow: 1, Item.potion: 3}, // the owner: more speed, fewer shields
};
const maxAwaken = 3, awakenPrice = 2;

/// Each type's own new kind and its count a level, added to its [awakenRecipe] for Awaken by grade ([Game.kindRecipe],
/// decisions-log 249; forge-design §11): the amulet's max HP for the shield line, the torch for the
/// undead-killers, the spear for the lancer, the beads for the healer, the prism for the splash.
const forgeAwakenKinds = <String, Map<ItemSlot, int>>{
  'soldier': {ItemSlot.amulet: 1},
  'knight': {ItemSlot.amulet: 1},
  'swordsman': {ItemSlot.torch: 1},
  'archer': {ItemSlot.torch: 1},
  'lancer': {ItemSlot.spear: 2},
  'priest': {ItemSlot.beads: 2},
  'armored_axeman': {ItemSlot.prism: 1},
  'wizard': {ItemSlot.prism: 2},
  'knight_templar': {ItemSlot.torch: 1},
};

/// [grade] (1 to 3) in words: "grade II" ([Words.grade]).
String gradeName(int grade) => '${Words.grade} ${Words.gradeNumerals[grade - 1]}';

/// The item of kind [slot] in [grade] (1 to 3).
Item itemOf(ItemSlot slot, int grade) => _itemBy[(slot, grade)]!;
final _itemBy = {for (final i in Item.values) (i.slot, i.grade): i};

/// The kinds no Awaken counts (the forge's Cap and Ring, decisions-log 249): every type takes them, up to one of the
/// kind per Awaken level and one more ([Game.capOf]), and a better grade at that cap swaps out its lowest-grade one.
const outsideAwaken = {ItemSlot.helm, ItemSlot.ring};

/// How many of a kind of which a level takes [n] Awaken's grade set takes at [share] of it ([AwakenRules.share]): rounded
/// up, at least 1; the share's last digit is a rounding (0.667 is two thirds), so a product less than 0.01 past a whole
/// number is that number (3 × 0.667 → 2, 4 × 0.667 → 3, 2 × 0.667 → 2).
int gradeCount(int n, double share) => max(1, (n * share - 0.01).ceil());

/// "Bangkit 4-5", Kebangkitan Emas (#92 part 2, decisions-log 143; the owner: "duitnya itu aku bingung di buat untuk
/// apa"): a type at Bangkit 3 buys up to [maxAscend] more levels with gold on its Army detail ([Ascend.ascend], lib/ascend.dart),
/// for the whole type, now and later. Its items, recipe and caps stay as at Bangkit 3. Each level past [maxAwaken]
/// still adds [awakenHp] / [awakenMp] of the base, multiplies its damage (a healer's heal) by [ascendPower], its
/// price by [ascendTroopPrice] (1: a templar stays at its Bangkit 3 price) and its awakening skill's cooldown by
/// [ascendSkillCd]; the skill's other numbers stay at Bangkit 3's.
const maxAscend = 2, ascendPower = 1.25, ascendTroopPrice = 1.0, ascendSkillCd = 0.85;

/// The top awakening level: Bangkit 3 from items, then the ones bought ([maxAscend]).
const awakenTop = maxAwaken + maxAscend;

/// [k] once for every level of [level] past [maxAwaken] (1 up to it): Bangkit 4 and 5's multipliers.
double ascendFactor(int level, double k) => pow(k, max(0, level - maxAwaken)).toDouble();

/// The item that raises [type]'s attack (or a healer's heal): the staff for the casters, whose recipes
/// take it, else the sword. The book shows that stat under its icon.
Item powerItem(String type) => (awakenRecipe[type] ?? const {}).containsKey(Item.staff) ? Item.staff : Item.sword;

/// Awakening [level] in words, for the book: "Not awakened", "Awaken 2", "Awaken 5 (Max)" ([awakenTop]).
String awakenName(int level) => level == 0 ? 'Not awakened' : '${Words.awaken} $level${level >= awakenTop ? ' (Max)' : ''}';

/// Burst [fx] as a troop of awakening [level] shows it: `<fx>_awake<level>` (the UI tints and enlarges
/// it), or plain [fx] before any awakening.
String awakeFx(String fx, int level) => level > 0 ? '${fx}_awake$level' : fx;

/// Rarer loot. The small relics ([RelicScope.troop], [Rarity.biasa]) are held by ONE troop (one relic each, a Hero
/// two) and change only how that troop fights: fang heals it by [fangShare] of the damage it deals, thorns hit an
/// attacker back with [thornsShare] of the blow, fury multiplies every [furyEvery]th attack by [furyHit], guard cuts
/// the damage taken by [guardCut]. The Smithy makes them (relics.dart); strong monsters dropped the first four
/// ([droppedRelics], [relicChance]) in a game without the Towns, gone in decisions-log 321. A fallen troop's relic goes
/// back in the bag. Every Pusaka is a row of [pusakaCatalog] (pusaka_catalog.dart), which gives its
/// [rarity] and whether the Toko sells it ([store]); the enum value is its save key, so a new one is only ever
/// appended. The [store] ones, today's five artefacts, are Pusaka (pusaka.dart, decisions-log 138):
/// bound to a whole troop TYPE ([RelicScope.type]), with stars ([dragonHeartK], [dawnStarK], [godThunderK], [grailK],
/// [voidEyeK]); they never drop. The four Langka Pusaka come only from the boss's chest (draft.dart, P3): Iron Banner
/// ([ironBannerK]), Blood Fang ([bloodFangK]), War Drum ([warDrumK]) and Mourning Bell ([mourningBellK]), and batch
/// L-1P's ten after the oaths (decisions-log 205: Titan Bane ([titanBaneK]) to Snare Cord ([snareCordK])), batch L-2P's
/// ten after them (decisions-log 207: Momentum ([momentumK]) to Spell Cutter ([spellCutterK])) and batch L-3's six after
/// those (decisions-log 209: Salt Charm ([saltCharmK]) to Pure Water ([pureWaterK])); since the chest, the epik ones too
/// (the store's shelf closes, [artefactShelf]), and batch E-1P's ten new Epik after them only from it, never in the Toko
/// (decisions-log 211: Healer Bane ([healerBaneK]) to Moonwell ([moonwellK])), and batch E-2P's seven after those
/// (decisions-log 214: Ember Brand ([emberBrandK]) to Anchor ([anchorK])), and batch E-3P's eight after those (decisions-log
/// 223: Mana Hymn ([manaHymnK]) to Bright Spring ([brightSpringK])). The Legenda change a rule, ★1 only, from the chest from wave
/// [legendFrom], each once a run (pusaka.dart, decisions-log 155): Dragon Crown ([crownCap]) on a type, and the first two oaths
/// ("Sumpah", [RelicScope.army]: the whole army, at most one a run), Oath of One ([oathOneK]) and Alliance
/// ([allianceK]); batch G-1P's ten after the Epik, on a type (decisions-log 231: Lone Wolf Pelt ([loneWolfK]) to Vow of
/// Silence ([vowSilenceK])), batch G-2's eight after them (decisions-log 238: Rage Totem ([rageTotemK]) to Glory
/// Seeker ([glorySeekerK])) and batch G-3's three after those (decisions-log 243: Vampire Kiss ([vampireKissK]), Wrath
/// Psalm ([wrathPsalmK]), Grave Seal ([graveSealK])); batch G-4's six oaths after those (decisions-log 247: Oath of the Few
/// ([fewOathK]) to Oath of Spells ([spellOathK])).
enum Relic {
  fang,
  thorns,
  fury,
  guard,
  dragonHeart(RelicScope.type),
  dawnStar(RelicScope.type),
  godThunder(RelicScope.type),
  grail(RelicScope.type),
  voidEye(RelicScope.type),
  ironBanner(RelicScope.type),
  bloodFang(RelicScope.type),
  warDrum(RelicScope.type),
  mourningBell(RelicScope.type),
  dragonCrown(RelicScope.type),
  oathOfOne(RelicScope.army),
  alliance(RelicScope.army),
  // Batch L-1P (decisions-log 205; catalog-design §3.1): the first ten new Langka, chest-only like the four.
  titanBane(RelicScope.type),
  finishingBlade(RelicScope.type),
  firstCut(RelicScope.type),
  shellCracker(RelicScope.type),
  twinFury(RelicScope.type),
  steadyStance(RelicScope.type),
  turtleShell(RelicScope.type),
  dullingMail(RelicScope.type),
  challengeLetter(RelicScope.type),
  snareCord(RelicScope.type),
  // Batch L-2P (decisions-log 207; catalog-design §3.1): ten more Langka, chest-only like the four.
  momentum(RelicScope.type),
  bleedingEdge(RelicScope.type),
  shatterShard(RelicScope.type),
  painCrystal(RelicScope.type),
  watchShield(RelicScope.type),
  boneBuckler(RelicScope.type),
  riposte(RelicScope.type),
  manaLeech(RelicScope.type),
  lootersPouch(RelicScope.type),
  spellCutter(RelicScope.type),
  // Batch L-3 (decisions-log 209; catalog-design §3.1): the last six Langka, chest-only like the four.
  saltCharm(RelicScope.type),
  wolfFeast(RelicScope.type),
  fullCup(RelicScope.type),
  hiddenFlask(RelicScope.type),
  livingMoss(RelicScope.type),
  pureWater(RelicScope.type),
  // Batch E-1P (decisions-log 211; catalog-design §3.2): the first ten new Epik, chest-only (never in the Toko).
  healerBane(RelicScope.type),
  bullyClub(RelicScope.type),
  unityRing(RelicScope.type),
  runeGauntlet(RelicScope.type),
  hawkFeather(RelicScope.type),
  witherroot(RelicScope.type),
  arrowCatcher(RelicScope.type),
  stoneCoat(RelicScope.type),
  heroCloak(RelicScope.type),
  moonwell(RelicScope.type),
  // Batch E-2P (decisions-log 214; catalog-design §3.2): seven more new Epik, chest-only (never in the Toko).
  emberBrand(RelicScope.type),
  funeralPyre(RelicScope.type),
  nullStone(RelicScope.type),
  fallenFlag(RelicScope.type),
  aegisSeal(RelicScope.type),
  wardensHorn(RelicScope.type),
  anchor(RelicScope.type),
  // Batch E-3P (decisions-log 223; catalog-design §3.2): the last eight new Epik, chest-only (never in the Toko).
  manaHymn(RelicScope.type),
  saintTear(RelicScope.type),
  braveSong(RelicScope.type),
  haloLantern(RelicScope.type),
  hearth(RelicScope.type),
  heartbeat(RelicScope.type),
  mercyLily(RelicScope.type),
  brightSpring(RelicScope.type),
  // The Smithy's seven new small relics (decisions-log 227; town-design rev 2 §6; relics.dart): crafted in a Town only,
  // never dropped ([droppedRelics] stays the first four). Strong: Sweep, Venom, Mana Siphon, Spirit Ward; Mighty: Iron
  // Will, Giant Slayer, Holy Charm. Their save keys are the design's (cleave, lastStand, blessing: the names the owner
  // changed so they don't read as the Hero skills Cleave, Last Stand and Blessing).
  cleave,
  venom,
  manaSiphon,
  spiritWard,
  lastStand,
  giantSlayer,
  blessing,
  // Batch G-1P (decisions-log 231; catalog-design §3.3): the first ten new Legenda, chest-only like Dragon Crown.
  loneWolf(RelicScope.type),
  martyrFlame(RelicScope.type),
  wideBlows(RelicScope.type),
  champion(RelicScope.type),
  vengeance(RelicScope.type),
  mirror(RelicScope.type),
  ghostStep(RelicScope.type),
  iceGrip(RelicScope.type),
  relicAltar(RelicScope.type),
  vowSilence(RelicScope.type),
  // Batch G-2 (decisions-log 238; catalog-design §3.3): eight more new Legenda, chest-only like Dragon Crown.
  rageTotem(RelicScope.type),
  guardianChain(RelicScope.type),
  phalanx(RelicScope.type),
  phoenix(RelicScope.type),
  soulShelter(RelicScope.type),
  manaFont(RelicScope.type),
  hexBlade(RelicScope.type),
  glorySeeker(RelicScope.type),
  // Batch G-3 (decisions-log 243; catalog-design §3.3): the last three new Legenda but the oaths, chest-only.
  vampireKiss(RelicScope.type),
  wrathPsalm(RelicScope.type),
  graveSeal(RelicScope.type),
  // Batch G-4 (decisions-log 247; catalog-design §3.3): the last six Legenda, the oaths, chest-only like Oath of One.
  fewOath(RelicScope.army),
  wallOath(RelicScope.army),
  bloodOath(RelicScope.army),
  vanguardOath(RelicScope.army),
  kingsOath(RelicScope.army),
  spellOath(RelicScope.army),
  // The forge's nine new small relics (decisions-log 245; forge-design §5; [forgeRelics]): crafted at a Smithy only
  // ([Relics.relicsInPlay]); never dropped, never offered. Basic: Chill, Shark Tooth, Grit; Strong:
  // Ambush, Weak Spot, Hot Streak; Mighty: Avalanche, Afterglow, Reaper. Their numbers are town.json's `relics`.
  chill,
  sharkTooth,
  grit,
  ambush,
  weakSpot,
  hotStreak,
  avalanche,
  afterglow,
  reaper;

  const Relic([this.scope = RelicScope.troop]);
  final RelicScope scope;

  /// Its rarity: a Pusaka's row's ([Art.rarity]); a small relic is biasa.
  Rarity get rarity => pusakaCatalog[this]?.rarity ?? Rarity.biasa;

  /// The Toko sells it ([Art.store]): today's five Epik.
  bool get store => pusakaCatalog[this]?.store ?? false;

  /// A Pusaka: bound to a troop type (or, an oath, to the army), never held by one troop.
  bool get pusaka => scope != RelicScope.troop;

  /// An oath ("Sumpah"): works on the whole army once taken, never bound to a type nor in the Gudang (pusaka.dart).
  bool get oath => scope == RelicScope.army;
}

/// A relic's rarity: the small relics are biasa, today's five Pusaka epik, the chest's four Langka langka and its three
/// Legenda legenda (the chest's odds and its cards' colours come with it, draft.dart).
enum Rarity { biasa, langka, epik, legenda }

/// Who a relic works on: the troop holding it (the small relics), every troop of the type it is bound to (a Pusaka),
/// or the whole army (an oath, decisions-log 155).
enum RelicScope { troop, type, army }

/// The four small relics monsters dropped before the Smithy made them (decisions-log 221): the [loot] dice still draw
/// one of them and throw it away; never a Pusaka nor one only the Smithy crafts ([smallRelics], relics.dart).
const droppedRelics = [Relic.fang, Relic.thorns, Relic.fury, Relic.guard];

/// The forge's nine new small relics (decisions-log 245), in [Relic] order ([Relics.relicsInPlay]); [smallRelics] leaves
/// them out.
const forgeRelics = [
  Relic.chill, Relic.sharkTooth, Relic.grit, Relic.ambush, Relic.weakSpot, Relic.hotStreak, Relic.avalanche, //
  Relic.afterglow, Relic.reaper,
];

const fangShare = 0.3, thornsShare = 0.3, furyEvery = 3, furyHit = 2, guardCut = 0.25;

/// A Hero holds this many relics, each a different kind; every other troop one (#91, [Unit.relicSlots]).
const heroRelicSlots = 2;

/// Whether a relic can be taken off a troop while a wave is on (#91, [Game.takeOff]): no, between waves only, like
/// the store ([storeMidWave]), so a Grail that saved its holder can't be handed on for a second save that wave.
const takeOffMidWave = false;

/// Loot names in the book's tooltips ([Game.itemInfo], [Game.relicInfo]).
const itemNames = {
  Item.sword: 'Sword',
  Item.shield: 'Shield',
  Item.boots: 'Boots',
  Item.bow: 'Bow',
  Item.gloves: 'Gloves',
  Item.potion: 'Potion',
  Item.staff: 'Staff',
  // The forge's 35 (decisions-log 245; forge-design §1, §10), in the enum's order.
  Item.amulet: 'Amulet',
  Item.prayerBeads: 'Prayer Beads',
  Item.torch: 'Torch',
  Item.spear: 'Spear',
  Item.prism: 'Prism',
  Item.steelSword: 'Steel Sword',
  Item.towerShield: 'Tower Shield',
  Item.swiftBoots: 'Swift Boots',
  Item.longBow: 'Long Bow',
  Item.steelGloves: 'Steel Gloves',
  Item.bigPotion: 'Big Potion',
  Item.magicStaff: 'Magic Staff',
  Item.silverAmulet: 'Silver Amulet',
  Item.holyBeads: 'Holy Beads',
  Item.holyTorch: 'Holy Torch',
  Item.wingedSpear: 'Winged Spear',
  Item.arcanePrism: 'Arcane Prism',
  Item.royalSword: 'Royal Sword',
  Item.royalShield: 'Royal Shield',
  Item.windBoots: 'Wind Boots',
  Item.greatBow: 'Great Bow',
  Item.royalGloves: 'Royal Gloves',
  Item.elixir: 'Elixir',
  Item.crystalStaff: 'Crystal Staff',
  Item.goldAmulet: 'Gold Amulet',
  Item.saintBeads: 'Saint Beads',
  Item.sunTorch: 'Sun Torch',
  Item.royalSpear: 'Royal Spear',
  Item.royalPrism: 'Royal Prism',
  Item.leatherCap: 'Leather Cap',
  Item.steelHelm: 'Steel Helm',
  Item.royalHelm: 'Royal Helm',
  Item.ring: 'Ring',
  Item.gemRing: 'Gem Ring',
  Item.royalRing: 'Royal Ring',
};
const relicNames = {
  Relic.fang: 'Fang',
  Relic.thorns: 'Thorns',
  Relic.fury: 'Fury',
  Relic.guard: 'Guard',
  // The store's artefacts, in English like the Hero skills (the owner, #63; store.dart).
  Relic.dragonHeart: 'Dragon Heart',
  Relic.dawnStar: 'Dawn Star',
  Relic.godThunder: "God's Thunder",
  Relic.grail: 'Grail of Immortality',
  Relic.voidEye: 'Void Eye',
  // The chest's Langka (draft.dart), in English like them.
  Relic.ironBanner: 'Iron Banner',
  Relic.bloodFang: 'Blood Fang',
  Relic.warDrum: 'War Drum',
  Relic.mourningBell: 'Mourning Bell',
  // The chest's Legenda (pusaka.dart, decisions-log 155).
  Relic.dragonCrown: 'Dragon Crown',
  Relic.oathOfOne: 'Oath of One',
  Relic.alliance: 'Alliance',
  // Batch L-1P's Langka (draft.dart, decisions-log 205).
  Relic.titanBane: 'Titan Bane',
  Relic.finishingBlade: 'Finishing Blade',
  Relic.firstCut: 'First Cut',
  Relic.shellCracker: 'Shell Cracker',
  Relic.twinFury: 'Twin Fury',
  Relic.steadyStance: 'Steady Stance',
  Relic.turtleShell: 'Turtle Shell',
  Relic.dullingMail: 'Dulling Mail',
  Relic.challengeLetter: 'Challenge Letter',
  Relic.snareCord: 'Snare Cord',
  // Batch L-2P's Langka (draft.dart, decisions-log 207).
  Relic.momentum: 'Momentum',
  Relic.bleedingEdge: 'Bleeding Edge',
  Relic.shatterShard: 'Shatter Shard',
  Relic.painCrystal: 'Pain Crystal',
  Relic.watchShield: 'Watch Shield',
  Relic.boneBuckler: 'Bone Buckler',
  Relic.riposte: 'Riposte',
  Relic.manaLeech: 'Mana Leech',
  Relic.lootersPouch: "Looter's Pouch",
  Relic.spellCutter: 'Spell Cutter',
  // Batch L-3's Langka (draft.dart, decisions-log 209).
  Relic.saltCharm: 'Salt Charm',
  Relic.wolfFeast: 'Wolf Feast',
  Relic.fullCup: 'Full Cup',
  Relic.hiddenFlask: 'Hidden Flask',
  Relic.livingMoss: 'Living Moss',
  Relic.pureWater: 'Pure Water',
  // Batch E-1P's Epik (draft.dart, decisions-log 211).
  Relic.healerBane: 'Healer Bane',
  Relic.bullyClub: "Bully's Club",
  Relic.unityRing: 'Unity Ring',
  Relic.runeGauntlet: 'Rune Gauntlet',
  Relic.hawkFeather: 'Hawk Feather',
  Relic.witherroot: 'Witherroot',
  Relic.arrowCatcher: 'Arrow Catcher',
  Relic.stoneCoat: 'Stone Coat',
  Relic.heroCloak: "Hero's Cloak",
  Relic.moonwell: 'Moonwell',
  // Batch E-2P's Epik (draft.dart, decisions-log 214).
  Relic.emberBrand: 'Ember Brand',
  Relic.funeralPyre: 'Funeral Pyre',
  Relic.nullStone: 'Null Stone',
  Relic.fallenFlag: 'Fallen Flag',
  Relic.aegisSeal: 'Aegis Seal',
  Relic.wardensHorn: "Warden's Horn",
  Relic.anchor: 'Anchor',
  // Batch E-3P's Epik (draft.dart, decisions-log 223).
  Relic.manaHymn: 'Mana Hymn',
  Relic.saintTear: "Saint's Tear",
  Relic.braveSong: 'Brave Song',
  Relic.haloLantern: 'Halo Lantern',
  Relic.hearth: 'Hearth',
  Relic.heartbeat: 'Heartbeat',
  Relic.mercyLily: 'Mercy Lily',
  Relic.brightSpring: 'Bright Spring',
  // The Smithy's (relics.dart): the owner's names of 2026-10-04 for cleave, lastStand and blessing (decisions-log 227).
  Relic.cleave: 'Sweep',
  Relic.venom: 'Venom',
  Relic.manaSiphon: 'Mana Siphon',
  Relic.spiritWard: 'Spirit Ward',
  Relic.lastStand: 'Iron Will',
  Relic.giantSlayer: 'Giant Slayer',
  Relic.blessing: 'Holy Charm',
  // Batch G-1P's Legenda (draft.dart, decisions-log 231).
  Relic.loneWolf: 'Lone Wolf Pelt',
  Relic.martyrFlame: "Martyr's Flame",
  Relic.wideBlows: 'Wide Blows',
  Relic.champion: "Champion's Mantle",
  Relic.vengeance: 'Vengeance Mark',
  Relic.mirror: 'Mirror Shield',
  Relic.ghostStep: 'Ghost Step',
  Relic.iceGrip: 'Ice Grip',
  Relic.relicAltar: 'Relic Altar',
  Relic.vowSilence: 'Vow of Silence',
  // Batch G-2's Legenda (draft.dart, decisions-log 238).
  Relic.rageTotem: 'Rage Totem',
  Relic.guardianChain: 'Guardian Chain',
  Relic.phalanx: 'Phalanx',
  Relic.phoenix: 'Phoenix Plume',
  Relic.soulShelter: 'Soul Shelter',
  Relic.manaFont: 'Mana Font',
  Relic.hexBlade: 'Hex Blade',
  Relic.glorySeeker: 'Glory Seeker',
  // Batch G-3's Legenda (draft.dart, decisions-log 243).
  Relic.vampireKiss: 'Vampire Kiss',
  Relic.wrathPsalm: 'Wrath Psalm',
  Relic.graveSeal: 'Grave Seal',
  // Batch G-4's oaths (pusaka.dart, decisions-log 247).
  Relic.fewOath: 'Oath of the Few',
  Relic.wallOath: 'Oath of the Wall',
  Relic.bloodOath: 'Blood Oath',
  Relic.vanguardOath: 'Oath of the Vanguard',
  Relic.kingsOath: 'Oath of Kings',
  Relic.spellOath: 'Oath of Spells',
  // The forge's nine (relics.dart, decisions-log 245; forge-design §5).
  Relic.chill: 'Chill',
  Relic.sharkTooth: 'Shark Tooth',
  Relic.grit: 'Grit',
  Relic.ambush: 'Ambush',
  Relic.weakSpot: 'Weak Spot',
  Relic.hotStreak: 'Hot Streak',
  Relic.avalanche: 'Avalanche',
  Relic.afterglow: 'Afterglow',
  Relic.reaper: 'Reaper',
};

/// How many of the troops in [fallen] were of each type, in [troopTypes]' order (the book's); a type with
/// none is left out. The "VICTORY!" popup lists a won wave's fallen ([Game.lastFallen]) this way when more
/// than [fallenNamesMax] fell, else by name.
Map<String, int> fallenCounts(Iterable<Unit> fallen) {
  final n = <String, int>{};
  for (final u in fallen) {
    n[u.type] = (n[u.type] ?? 0) + 1;
  }
  return {for (final t in troopTypes.keys) t: ?n[t]};
}

const fallenNamesMax = 3;

/// A multiplier as a change: 1.25 → "+25%", 0.8 → "-20%".
String _pct(num k) => '${k < 1 ? '-' : '+'}${((k - 1).abs() * 100).round()}%';

/// A whole number without ".0", else one decimal.
String _num(num v) => v == v.roundToDouble() ? '${v.round()}' : v.toStringAsFixed(1);

/// A multiplier to two decimals at most, without trailing zeros: 3, 1.6, 1.45 (a Pusaka's stars).
String _x(num v) => v.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');

// The item text is in simple English (decisions-log 168; ui-hud.md "In-game text"): these write its words.

/// [n] as an English ordinal: 3 → "3rd", 4 → "4th", 11 → "11th".
String _nth(int n) => '$n${n % 100 ~/ 10 == 1 ? 'th' : switch (n % 10) { 1 => 'st', 2 => 'nd', 3 => 'rd', _ => 'th' }}';

/// [n] of [word], with an English plural: "1 tile", "3 tiles", "5 types".
String _count(num n, String word) => '${_num(n)} $word${n == 1 ? '' : 's'}';

// Cheapest first: the order of the troop box.
const troopTypes = {
  'soldier': Stats(hp: 90, cost: 30, speed: 22, dmg: 10, range: 12, rate: 0.8, mp: 20, mpRegen: 1),
  'knight': Stats(hp: 140, cost: 50, speed: 24, dmg: 20, range: 14, rate: 0.8, mp: 20, mpRegen: 1),
  'swordsman': Stats(hp: 140, cost: 60, speed: 28, dmg: 14, range: 13, rate: 0.5, mp: 30, mpRegen: 1.5), // hp 110 until decisions-log 318
  'archer': Stats(hp: 60, cost: 70, speed: 22, dmg: 9, range: 64, rate: 0.6, shotSpeed: 200, mp: 30, mpRegen: 1.5),
  'lancer': Stats(hp: 120, cost: 80, speed: 26, dmg: 18, range: 22, rate: 1.0, mp: 20, mpRegen: 1),
  'priest': Stats(hp: 60, cost: 90, speed: 20, dmg: 12, range: 96, rate: 1.2, heals: true, mp: 60, mpRegen: 3), // reaches past the long range
  'armored_axeman': Stats(hp: 180, cost: 110, speed: 18, dmg: 22, range: 14, rate: 1.1, splash: 16, mp: 20, mpRegen: 1),
  'wizard': Stats(hp: 50, cost: 120, speed: 18, dmg: 22, range: 72, rate: 1.4, shotSpeed: 140, splash: 20, mp: 80, mpRegen: 4),
  'knight_templar': Stats(hp: 280, cost: 150, speed: 18, dmg: 26, range: 14, rate: 1.0, mp: 40, mpRegen: 2),
};

/// No troop walks faster than its legs can be drawn (decisions-log 311; the owner picked "Batasi kecepatan jalan" over a
/// quicker stride): at most this many times its type's base walk speed ([troopTypes]), whatever its speed stat says
/// (boots, a Hero's ×3, the aura, an Artifact, a boost). 6× is the quickest the walk strip strides with its feet planted
/// on a 60 fps screen (body_look.dart's `bodyStride`). A Hero knight with boots walked 275 on the owner's wave-30 save,
/// 11.5× its 24: now 144. Only walking ([Unit.walkSpeed]): a charge, a leap, a dash and a carry keep their own speeds.
const walkMost = 6.0;

/// The fastest a troop of [type] walks: [walkMost] × its base walk speed (no limit for a type not in [troopTypes]).
double walkCap(String type) => walkMost * (troopTypes[type]?.speed ?? double.infinity);

/// The heavy troops, and how much stronger than their table they fight (#57; the owner: the templar and the
/// axeman lag behind and die first, "jadi mereka seperti last hope"): their HP, attack and defence (their
/// shields') times 1 + [heavyBuff], with items and awakening ([Game.statsOf]).
const heavyTypes = {'armored_axeman', 'knight_templar'}, heavyBuff = 0.2;

/// Each troop type's name, e.g. in the troop counter's list (lib/troop_counter.dart) and the bag's item
/// picker (lib/bag.dart).
const troopTypeNames = {
  'soldier': 'Soldier',
  'knight': 'Knight',
  'swordsman': 'Swordsman',
  'archer': 'Archer',
  'lancer': 'Lancer',
  'priest': 'Priest',
  'armored_axeman': 'Axeman',
  'wizard': 'Wizard',
  'knight_templar': 'Templar',
};

/// Each troop type's name for more than one of them: the type cap's refusal ("Priests full 5/5", [Game.typeRefusal]).
const troopTypePlurals = {
  'soldier': 'Soldiers',
  'knight': 'Knights',
  'swordsman': 'Swordsmen',
  'archer': 'Archers',
  'lancer': 'Lancers',
  'priest': 'Priests',
  'armored_axeman': 'Axemen',
  'wizard': 'Wizards',
  'knight_templar': 'Templars',
};

/// Each monster type's name, on its plate over the field (lib/plates.dart).
const monsterTypeNames = {
  'slime': 'Slime',
  'bat': 'Bat',
  'skeleton': 'Skeleton',
  'orc': 'Orc',
  'skeleton_archer': 'Skeleton Archer',
  'werewolf': 'Werewolf',
  'armored_skeleton': 'Armored Skeleton',
  'orc_rider': 'Orc Rider',
  'elite_orc': 'Veteran Orc',
  'armored_orc': 'Armored Orc',
  'greatsword_skeleton': 'Greatsword Skeleton',
  'werebear': 'Werebear',
  boss: 'Necromancer',
  necroHealer: 'Necro Healer',
};

/// Each monster rank's name, on a monster's plate in its HP bar's colour; it goes before the type's name ("High Elite
/// Orc", [foeCutLine]).
const tierNames = {Tier.normal: 'Normal', Tier.elite: 'Elite', Tier.highElite: 'High Elite', Tier.miniBoss: 'Mini Boss', Tier.boss: 'Boss'};

/// What monster [u]'s plate says (lib/plates.dart): its type's name ([monsterTypeNames]), its rank
/// ([tierNames]), what kind of monster it is (undead, a healer, a summoner, raised by a necromancer), and its
/// HP now (rounded up: a sliver left shows as 1) / max.
({String name, String tier, List<String> kinds, String hp}) monsterPlate(Unit u) => (
      name: monsterTypeNames[u.type] ?? u.type,
      tier: tierNames[u.tier]!,
      kinds: [
        if (u.stats.dark) 'Undead',
        if (u.stats.heals) 'Healer',
        if (u.type == boss) 'Summoner',
        if (u.raisedBy != null) 'Raised',
      ],
      hp: 'HP ${max(0.0, u.hp).ceil()}/${u.maxHp}',
    );

/// Why one more item can't go on a troop type ([Game.whyNot]): not in its awakening recipe, at its cap
/// until it awakens, at its cap for good, or a bow on a melee fighter already at [meleeMaxRange].
enum Refusal { notInRecipe, awakenFirst, maxed, reach }

/// The refusals as the bag's item picker says them.
const refusalNames = {
  Refusal.notInRecipe: 'Not for this type',
  Refusal.awakenFirst: '${Words.awaken} first',
  Refusal.maxed: 'At max',
  Refusal.reach: 'Max range',
};

/// A stat the book's troop row shows, in its order (lib/troop_row.dart), for what a gift changes
/// ([Game.assignPreview]).
enum StatKind {
  hp,
  mp,
  def,
  dmg,
  range,
  speed,
  rate,
  regen;

  /// Its value in [s]; the pause between attacks as the troop attacks: never under [minAttackInterval].
  num of(Stats s) => switch (this) {
        StatKind.hp => s.hp,
        StatKind.mp => s.mp,
        StatKind.def => s.def,
        StatKind.dmg => s.dmg,
        StatKind.range => s.range,
        StatKind.speed => s.speed,
        StatKind.rate => max(minAttackInterval, s.rate),
        StatKind.regen => s.regen,
      };
}

/// What one more loot on a troop type (an [Item]) or on one troop (a [Relic]) would do ([Game.assignPreview]):
/// why it can't, in the UI's words (null: it can); the stats it changes, (kind, now, after), as the troop row
/// shows them; and for an item, each (now, after): the type's price, its awakening level, the kind's (taken,
/// cap), and the (have, need) summed over its recipe toward the awakening after its level now (null at
/// [maxAwaken]).
typedef AssignPreview = ({
  String? why,
  List<(StatKind, num, num)> stats,
  (int, int)? price,
  (int, int)? awaken,
  ((int, int), (int, int))? count,
  ((int, int), (int, int))? step,
});

/// Why a gift can't go on at all ([Game.assignPreview]): the game is over, or none is left in the bag; and why
/// a relic can't go on one troop: it fell (or isn't a troop), it holds that kind or its one relic already
/// ([holdsRelic]), or it is a Hero with both its slots taken ([full]).
const assignRefusals = (over: Words.gameOver, empty: '${Words.bag} is empty', gone: 'Fallen', full: 'Relic slots full');

/// A troop holding [relic] refuses another: one relic each (a Hero two, of different kinds).
String holdsRelic(Relic relic) => 'Already holds ${relicNames[relic]}';

/// Why a relic can't come off a troop ([Game.whyNotTakeOff]), besides [assignRefusals]' over and gone: a wave is
/// on ([takeOffMidWave]), or it doesn't hold that relic.
const takeOffRefusals = (midWave: Words.onlyBetweenWaves, none: 'Not held');

/// A grade whose slots open with an Awaken (decisions-log 252; by grade, [Game.itemRefusal] and [Game.itemInfo]'s
/// line): grade II "Opens at Awaken 1", grade III "Opens at Awaken 2".
String gradeOpensAt(Item item) => 'Opens at ${awakenName(item.grade - 1)}';

/// Why a troop can't be bought ([Game.buyRefusal]): too poor, or the army at its capacity. The limits' own refusals
/// (decisions-log 141, 201) say their numbers: "Priests full 5/5" ([Game.typeRefusal]), "Army full 36/36".
const buyRefusals = (gold: Words.notEnoughGold, full: 'No room');

/// Why a type can't be sent home ([Game.whyNotRelease]), besides [assignRefusals].over and
/// [takeOffRefusals].midWave: none of it is alive, or a Hero of it lives.
const releaseRefusals = (none: 'Not a type in your army', hero: "A Hero can't be sent home");

/// How many relics a troop holds, the book's words for it (the tooltips and the store's card).
const relicSlotsLine = 'One relic per troop (Hero: 2)';

/// How an item or a small relic is given, the tooltips' words for it.
const tapLine = 'Tap, then pick a troop';

/// A stat's name in the previews, in [Game.itemEffect]'s words: a healer's power is its heal.
String statName(StatKind k, {bool heals = false}) => switch (k) {
      StatKind.hp => 'HP',
      StatKind.mp => 'MP',
      StatKind.def => 'Defense',
      StatKind.dmg => heals ? 'Heal' : 'Attack',
      StatKind.range => 'Range',
      StatKind.speed => 'Speed',
      StatKind.rate => 'Attack wait',
      StatKind.regen => 'Regen',
    };

// Ordered weakest → strongest; later waves unlock more of the list. The undead are [Stats.dark]: every
// skeleton and both necromancers (the bat and the were-beasts are living creatures).
const enemyTypes = {
  'slime': Stats(hp: 30, cost: 3, speed: 18, dmg: 5, range: 12, rate: 0.8),
  'bat': Stats(hp: 20, cost: 3, speed: 34, dmg: 4, range: 12, rate: 0.6),
  'skeleton': Stats(hp: 50, cost: 5, speed: 20, dmg: 8, range: 12, rate: 0.9, dark: true),
  'orc': Stats(hp: 80, cost: 6, speed: 18, dmg: 10, range: 12, rate: 1.0),
  'skeleton_archer': Stats(hp: 40, cost: 7, speed: 18, dmg: 7, range: 60, rate: 1.2, shotSpeed: 150, dark: true),
  'werewolf': Stats(hp: 90, cost: 9, speed: 32, dmg: 12, range: 12, rate: 0.8),
  'armored_skeleton': Stats(hp: 150, cost: 10, speed: 15, dmg: 12, range: 12, rate: 1.0, dark: true),
  'orc_rider': Stats(hp: 130, cost: 12, speed: 30, dmg: 14, range: 14, rate: 1.0),
  'elite_orc': Stats(hp: 180, cost: 14, speed: 17, dmg: 16, range: 14, rate: 1.0),
  'armored_orc': Stats(hp: 240, cost: 16, speed: 14, dmg: 18, range: 14, rate: 1.1),
  'greatsword_skeleton': Stats(hp: 220, cost: 16, speed: 16, dmg: 24, range: 16, rate: 1.3, dark: true),
  'werebear': Stats(hp: 320, cost: 20, speed: 16, dmg: 26, range: 14, rate: 1.3),
};

/// A troop healer's heal on a [Stats.dark] monster takes this share of it off as holy damage: heal 10 on
/// an ally, 8 damage to a skeleton ([Game._smite]).
const holyShare = 0.8;

/// Joins every fifth wave (and sometimes takes the mini boss slot): a scythe fighter that spends its MP
/// raising skeletons ([Game.decideSummon]). From [escortFrom] a high elite one also escorts every mini boss
/// and boss.
const boss = 'necromancer';
const bossStats = Stats(hp: 600, cost: 40, speed: 12, dmg: 30, range: 20, rate: 1.5, dark: true);

/// The necromancer as a mini boss has this share of its (boss) dmg. Its HP is any mini boss's, from the slot's
/// reference (the owner's #89, [enemyStats]).
const necroMiniDmg = 0.6;

/// The owner's boss buff (#66), on top of the tier and the wave ([bossBuff]): in full, a wave's boss has
/// [bossHpK] × its HP, [bossMpK] × its MP pool and [bossDmgK] × its damage; its mini boss (of any type)
/// [miniHpK], [miniMpK] and [miniDmgK]. A necromancer's raised minions don't get it. MP comes back as fast as
/// before. The mini boss's damage was ×2 until the owner softened it (#75).
const bossHpK = 10.0, bossMpK = 5.0, bossDmgK = 3.0;
const miniHpK = 6.0, miniMpK = 3.0, miniDmgK = 1.5;

/// The boss buff comes in with the wave: none up to [bossBuffFrom], in full from [bossBuffFull], in a straight
/// line between (the full buff on wave 5 beat every early army; in full from wave 30 it still walled the runs
/// round wave 25, so the owner moved it to 50; to 60 in decisions-log 318, with the gentler late gold).
const bossBuffFrom = 5, bossBuffFull = 60;

/// [tier]'s boss buff on [wave] as (hp, MP pool, dmg) multipliers: none below the mini boss.
(double, double, double) bossBuff(Tier tier, int wave) {
  final (hp, mp, dmg) = switch (tier) {
    Tier.boss => (bossHpK, bossMpK, bossDmgK),
    Tier.miniBoss => (miniHpK, miniMpK, miniDmgK),
    _ => (1.0, 1.0, 1.0),
  };
  final f = ((wave - bossBuffFrom) / (bossBuffFull - bossBuffFrom)).clamp(0.0, 1.0);
  double k(double full) => 1 + (full - 1) * f;
  return (k(hp), k(mp), k(dmg));
}

/// From wave [necroMiniFrom], the mini boss slot is the necromancer at [necroMiniChance]; from wave [necroBossFrom]
/// the boss slot is it at [necroBossChance]. Otherwise either slot is any type of the wave's pool ([slotType], #58).
/// Both on one wave when both draw it, unless [Game.necroPairAllowed] is off. Before [necroBossFrom] the boss is
/// always a type of the pool: a 5-troop opening lost every necromancer boss at wave 5 (decisions-log 176).
const necroMiniChance = 1 / 3, necroMiniFrom = 8, necroBossChance = 1 / 3, necroBossFrom = 10;

/// A boss or mini boss of a monster type (not the necromancer) starts from its slot's reference ([slotBase]):
/// the boss from the necromancer boss, times [bossTypeHp] HP and [bossTypeDmg] damage; the mini boss from the
/// wave's strongest type, times its tier's multipliers. At the necromancer's full damage a second such a boss
/// killed twice the troops (it fights the whole time, the necromancer mostly casts); at 0.65 it kills about
/// as many (the #36 auto-player, 9 seeds, decisions-log 91).
const bossTypeHp = 1.0, bossTypeDmg = 0.65;

/// Wave [wave]'s pool: the first 1 + wave/2 types of [enemyTypes], weakest first.
List<String> poolOf(int wave) => enemyTypes.keys.take(min(enemyTypes.length, 1 + (wave >> 1))).toList();

/// The type in a boss or mini boss slot drawn with [roll] (0 ≤ roll < 1) from [pool] (weakest first): the
/// n-th type is n times as likely as the first, so the stronger types come more often.
String slotType(List<String> pool, double roll) {
  final total = pool.length * (pool.length + 1) / 2;
  var upTo = 0.0;
  for (final (i, type) in pool.indexed) {
    upTo += (i + 1) / total;
    if (roll < upTo) return type;
  }
  return pool.last;
}

/// What a monster [s] in wave [wave]'s boss or mini boss [tier] slot starts from, before its tier and the
/// wave: its own HP and damage, raised to at least the slot's reference, the necromancer boss ([bossStats])
/// for the boss and the wave's strongest type as a mini boss; its damage so it hits as hard a second at its
/// own pace ([Stats.rate]). Its speed and reach stay its own, so a bat boss is quick and a skeleton archer
/// boss shoots. The necromancer mini boss takes only the mini boss reference's HP ([enemyStats], #89).
(double, double) slotBase(Stats s, Tier tier, int wave) {
  final ref = tier == Tier.boss ? bossStats : enemyTypes[poolOf(wave).last]!;
  return (max(s.hp, ref.hp).toDouble(), max(s.dmg, ref.dmg / ref.rate * s.rate));
}

/// Every [miniBossEvery]th wave adds a mini boss and every [bossEvery]th the boss; waves 15, 30… bring both.
const miniBossEvery = 3, bossEvery = 5;

/// The boss bars at the top of the screen (#67; lib/boss_bar.dart): the wave's mini boss and boss get a
/// name when they come ([bossName]) and a title from their type, `<name> the <title>` ([bossBarName]).
const bossTitles = {
  'slime': 'Sticky',
  'bat': 'Nightwing',
  'skeleton': 'Ironbone',
  'orc': 'Crusher',
  'skeleton_archer': 'Deadeye',
  'werewolf': 'Moonfang',
  'armored_skeleton': 'Ironclad',
  'orc_rider': 'Stormrider',
  'elite_orc': 'Warlord',
  'armored_orc': 'Steelwall',
  'greatsword_skeleton': 'Gravesword',
  'werebear': 'Rockclaw',
  boss: 'Summoner',
  necroHealer: 'Dark Healer',
};

/// A boss bar's name for [u]: `<name> the <title>` ("Morgath the Summoner"), or its type's name when it came without
/// one (a test's).
String bossBarName(Unit u) =>
    u.name.isEmpty ? monsterTypeNames[u.type] ?? u.type : '${u.name} the ${bossTitles[u.type] ?? monsterTypeNames[u.type] ?? u.type}';

/// HP per layer of a boss bar (#67): the owner's "setiap 1000HP akan ada muncul x1 jadi kalau boss/mini boss
/// hpnya 13000 maka `<bar hp>` x 13".
const bossBarLayer = 1000;

/// A boss bar's layers for [hp] of [maxHp]: [left] layers still stand (the "×N": [hp] / [bossBarLayer]
/// rounded up), the current one [fill] full (0–1), [total] of them at full health. Every layer is
/// [bossBarLayer] HP but the top one, which holds what is over the whole thousands (13,500 HP: 14 layers,
/// the top one 500), so a boss at full health shows a full bar.
({int left, double fill, int total}) bossLayers(double hp, int maxHp) {
  final total = max(1, (maxHp / bossBarLayer).ceil());
  if (hp <= 0) return (left: 0, fill: 0.0, total: total);
  final left = min(total, (hp / bossBarLayer).ceil()), size = left == total ? maxHp - (total - 1) * bossBarLayer : bossBarLayer;
  return (left: left, fill: size <= 0 ? 1.0 : ((hp - (left - 1) * bossBarLayer) / size).clamp(0.0, 1.0), total: total);
}

/// A wave whose own monsters make no progress for this long (none gets nearer the base or falls to a new
/// low of HP, none dies, none spawns) has stalled: its monsters drop their tactics and charge the troops
/// ([Game.marching]), and the wave must be won within [marchMax] s. A necromancer's endless skeletons in
/// front of 1–2 kiting archers stalled wave 5 for good (#39).
const stallTime = 30.0;

/// The wave's own monsters nearest the base standing this much further from it than they have since the last
/// spawn or death are drifting off: while they do, their falling HP is no progress ([Game._watchStall]). A
/// lone wizard led a mini boss 2,000+ px off, its HP falling ~10% every 2 min, and that read as progress for good
/// (qa-3). Twice Death Leap's reach (a monster turning on a troop that leapt behind it), ten knockbacks.
const stallDrift = 10 * tile;

/// This long after the wave's last spawn or the last [stallProgress], its monsters march whatever
/// else ([Game._watchStall]). None of the owner's 149 waves of telemetry (w1–86, none marched) went on much over 110 s
/// after its last spawn, by its spawn count (the longest, w78, 230 s in all); only a near-wiped army fights on longer.
const stallOvertime = 180.0;

/// The wave's slot monsters (its mini boss and boss, alive) losing this share of their summed max HP since the
/// overtime clock last started starts it afresh ([stallOvertime]): a slow slot fight the army is still winning goes
/// on. qa-4: at 14437d0's strength the overtime marched late slot fights that 6–10 troops were winning (one won at
/// 515 s without it), and the mini boss leaked a life each time (the back line went in decisions-log 329). A plain
/// monster falling is no such progress.
const stallProgress = 0.05;

/// This long after the wave's last spawn, its monsters march whatever the slots'
/// [stallProgress] ([Game._watchStall]): a slot monster ground down a little at a time, or healed back between
/// blows, can't hold the wave for good. qa-4's one stalled wave (w90, 1 troop left whittling a boss) still ran at
/// 600 s on the slots' progress alone; the slowest win of the late replays it ended came 278 s after the last spawn.
const stallOvertimeMax = 300.0;

/// A wave still on this long after its monsters began to charge ([Game.marching]) is lost as a wiped one is: a heart,
/// and the wave again ([WipeCause.slow], wipe.dart). Until decisions-log 329 the march walked through the troops to the
/// back line, each monster over it half a heart, and the wave then counted as won: a w60 boss wave lost 5 lives that
/// way, 87 s into its march. Of the other 6 marches in that audit's 397 waves, the troops killed every marcher within
/// seconds.
const marchMax = 60.0;

/// The other necromancer ("Nekromanser Penyembuh", drawn as the boss recoloured teal): a support that
/// stays at the very back ([Game._mend]) and heals the most hurt monster it can safely reach that no other
/// healer has just healed ([healWindow]): [Stats.dmg] HP every [Stats.rate] s within [Stats.range], for
/// [necroHealCost] MP each. It joins waves from [necroHealerFrom], more of them from [twoNecroHealersFrom]
/// ([necroHealersIn]); on a boss wave the last one walks behind the boss.
const necroHealer = 'necro_healer';
const necroHealerStats = Stats(hp: 70, cost: 12, speed: 16, dmg: 8, range: 64, rate: 1.2, heals: true, dark: true, mp: 40, mpRegen: 3.2);
const necroHealerFrom = 4, twoNecroHealersFrom = 6;

/// From [twoNecroHealersFrom] one more healing necromancer every [necroHealerEvery] waves, up to
/// [necroHealersMax] (#70: 6: 2, 11: 3, 16: 4, 21 on: 5).
const necroHealerEvery = 5, necroHealersMax = 5;

/// Every heal costs the healing necromancer this much MP (it comes on with its [Stats.mp] full).
const necroHealCost = 8.0;

/// Every heal a troop healer gives in a wave costs it this much MP (decisions-log 297; the owner: "army/enemy healer
/// harusnya ketika melakukan heal itu akan menggunakan mp-nya"), the healing necromancer's way: 10% of a priest's base
/// pool, whatever awakening or a Hero adds to the pool. Short of it, it gives none ([Game._heal]); its smites and the
/// after-wave heals ([Game._healFromQueue]) are free.
const healMp = 6.0;

/// When it can't heal (short of MP, or nobody it can safely reach is hurt), the healing necromancer
/// swings its scythe at a troop within [necroSwing].reach, taking a short [necroSwing].step to one just
/// out of it (never further: it doesn't go looking for a fight): [necroSwing].share of its heal as damage,
/// every [necroSwing].gap s.
const necroSwing = (share: 0.6, reach: 18.0, step: 8.0, gap: 1.4);

/// How far outside every troop's reach the healing necromancer keeps; it backs off when one comes closer.
const necroSafety = 2 * tile;

/// What a healing necromancer is doing ([Game._mend], [Unit.mend]): resting behind the monsters, holding where it
/// stands (its rest spot isn't safe to reach, or it is cornered), walking to a heal spot, healing (or waiting out its
/// heal's interval in range), backing off, swinging its scythe, or walking on alone.
enum Mend { rest, hold, toHeal, heal, backOff, swing, alone }

/// The healing necromancer's choices stick (decisions-log 314; the owner: "ai necromencer healer juga masi suka diam
/// bingung antara mau heal dan dan melarikan diri"). It starts backing off when a troop reaches into its margin
/// ([necroSafety]) and goes on until it is [mendClear] outside it; a heal spot or rest spot it picks is [mendClear]
/// outside it too, and so the walk there never starts a back-off at once. A monster it walks to heal is kept
/// [mendCommit] s at least while it may still heal it.
const mendClear = tile / 2, mendCommit = 1.0;

/// The heal spot's tries: turns, in degrees, from the straight way between the hurt monster and the healing
/// necromancer, on the ring at 0.9 × its reach round the monster (decisions-log 314): straight first, then wider.
const mendTurns = [0.0, 40.0, -40.0, 80.0, -80.0];

/// A healer stands still this long once it starts a heal (and the healing necromancer after a swing): no
/// walking, no falling back, and nobody shoves it aside until the cast is over.
const healCast = 0.6;

/// Healing necromancers' heals don't stack (#78; the owner: "Keep 4, heals don't stack"): a monster one of
/// them heals (a heal or Mass Mend) takes no other healer's heal for [healWindow]× the heal interval of the one
/// that healed it ([Game.attackEvery]); the others heal the next most hurt they can reach instead. Troop
/// healers are not affected.
const healWindow = 1.0;

/// A troop type's skill (#10): cast by itself during a wave whenever it has a target ([Game.wantsSkill]), paid
/// with [cost] MP, at most once every [cooldown] s. [name] shows over the troop on its first cast of a wave.
class Skill {
  final String name;
  final double cost, cooldown;
  const Skill(this.name, this.cost, this.cooldown);
}

/// Every troop type's skill (decisions-log 298; the owner: "selagi masi ada mp, dan skill avaliable para army spam aja
/// skillnya"): a troop casts it whenever it has the MP, the cooldown is over and it has a target. Each costs
/// [skillMpShare] of its type's base MP pool (5 s of its regen, which is 5% of the pool a second; a full pool holds
/// 4), and comes again after [skillCooldown] s, or 2 s after its own effect ends (Hold Fast's [guardSelf].time,
/// Rampage's [frenzy].time, Holy Shield's [ward].time). Until 298 they cost 15-40 MP, 50-75% of the pool, came again
/// after 10-16 s and waited for a crowd or a low HP.
const troopSkills = {
  'soldier': Skill('Hold Fast', 5, 5),
  'knight': Skill('Circle Slash', 5, skillCooldown),
  'swordsman': Skill('Rampage', 7.5, 6),
  'archer': Skill('Arrow Rain', 7.5, skillCooldown),
  'lancer': Skill('Piercing Thrust', 5, skillCooldown),
  'priest': Skill('Healing Prayer', 15, skillCooldown),
  'armored_axeman': Skill('Crushing Blow', 5, skillCooldown),
  'wizard': Skill('Arcane Blast', 20, skillCooldown),
  'knight_templar': Skill('Holy Shield', 10, 6),
};

/// A #10 skill's cost as a share of its type's base MP pool, and its cooldown (s) unless its effect lasts longer
/// ([troopSkills]).
const skillMpShare = 0.25, skillCooldown = 4.0;

/// Hold Fast (soldier): with a foe in reach and no guard as strong on it, it takes [guardSelf].cut less damage for
/// [guardSelf].time s.
const guardSelf = (cut: 0.3, time: 3.0);

/// Circle Slash (knight): with a foe within [slash].reach, hits each one there for [slash].hit × its damage.
const slash = (reach: 20.0, hit: 1.0);

/// Rampage (swordsman): with a foe in reach, attacks [frenzy].rate as far apart (1.67× as fast) for [frenzy].time s.
const frenzy = (rate: 0.6, time: 4.0);

/// Arrow Rain (archer): with a foe in range, [volleyArrows] extra arrows at the nearest ones in range.
const volleyArrows = 2;

/// Piercing Thrust (lancer): with a foe in reach, [pierce].hit × its damage to it and every foe up to
/// [pierce].depth behind it within [pierce].lane lanes.
const pierce = (hit: 1.25, depth: 2 * tile, lane: 8.0);

/// Healing Prayer (priest): heals every troop within [prayer].reach of the most hurt one it can reach by
/// [prayer].heal × its heal, when [prayer].crowd+ of them (that one too) are below [prayer].hurt of their HP: a
/// crowd to heal, else its single heals do ([Game._heal]).
const prayer = (reach: 2 * tile, heal: 1.0, crowd: 2, hurt: 0.9);

/// Crushing Blow (armored_axeman): with a foe within [slam].reach, [slam].hit × its damage to each one there, and
/// each but the boss is stunned for [slam].stun s (no moving or attacking).
const slam = (reach: 1.5 * tile, hit: 1.0, stun: 1.0);

/// Arcane Blast (wizard): with a foe in range, one big orb at it for [blast].hit × its damage over [blast].splash.
const blast = (hit: 1.5, splash: 32.0);

/// Holy Shield (knight_templar): with a fighting troop within [ward].reach (itself too) not yet guarded that strongly,
/// every troop there takes [ward].cut less damage for [ward].time s.
const ward = (reach: 3 * tile, cut: 0.2, time: 4.0);

/// How long each troop skill's own look shows (s; #81, lib/skills.dart draws them): Hold Fast's brace, Circle
/// Slash's sweep, Rampage's burst, Arrow Rain's falling arrows ([ZoneLook.volley]), Piercing Thrust's streak
/// ([BeamLook.thrust]), Healing Prayer's columns, Crushing Blow's cracks and Holy Shield's domes. Arcane Blast's
/// ring and the reach rings of Healing Prayer and Holy Shield take [ringTime]. What lasts (a guard, Rampage) shows
/// as long as it does.
const skillLook = (brace: 0.5, slash: 0.4, rage: 0.5, volley: 0.8, thrust: 0.3, pillar: 0.8, crack: 0.8, dome: 0.8);

/// How many healing necromancers wave [wave] brings.
int necroHealersIn(int wave) => wave < necroHealerFrom
    ? 0
    : (wave < twoNecroHealersFrom ? 1 : min(necroHealersMax, 2 + (wave - twoNecroHealersFrom) ~/ necroHealerEvery));

/// From wave [escortFrom] every mini boss and boss comes with an escort (the owner's #90: "wave 50+ miniboss dan
/// bossnya di backup 3 necromencer penyembuh biar ada perlawanan dan 1 necromencer pemanggil level high elite"):
/// [escortHealers] healing necromancers of the usual ranks, then [escortSummoners] necromancer of rank
/// [escortSummonerTier], right behind it in the queue and on top of the wave's own healers ([necroHealersIn]). A
/// wave with both (60, 75, 90…) has two. Its healers heal their boss first and rest behind it ([Game._mend]).
const escortFrom = 50, escortHealers = 3, escortSummoners = 1;
const escortSummonerTier = Tier.highElite;

/// An escort's healers back up their boss (the owner's #90: "di backup 3 necromencer penyembuh biar ada perlawanan";
/// the orchestrator's option B): for their own boss's heal spot and their rest spot behind it only the melee troops'
/// reach (+ [necroSafety]) counts ([escortMeleeOnly]). So they stand in arrows and spells, at most [escortReach]
/// behind it (its heal range) and never past it; for everything else they keep out of every troop's reach as any
/// healer does. Under the whole rule the long-range troops of a late army covered the field: in a probe of the
/// owner's army they sat 150–240 px behind their boss and healed it 0–1 times a slot.
const escortMeleeOnly = true, escortReach = 4 * tile;

/// Monster ranks: the same sprite in the rank's colour (ui-hud.md), stronger stats the higher the rank.
/// Multipliers on hp, dmg, speed and the gold a kill pays ([reward], on the type's base [Stats.cost], grown
/// by the wave: [killGold]). Any type can hold any rank (#58). A boss or mini boss starts from its slot's
/// reference ([slotBase]); the necromancer's own stats are already a boss's, so as the boss the tier raises
/// only its gold (as a mini boss it has the slot reference's HP × the tier's, like any mini boss, and
/// [necroMiniDmg] of its own damage; as an escort's high elite, [escortFrom], the same reference's HP × its tier's
/// and a damage share like the mini boss's), and another type's boss has [bossTypeHp] / [bossTypeDmg] instead of
/// the tier's ×1.
/// The boss and the mini boss also get the owner's [bossBuff] on top (#66).
enum Tier {
  normal(1, 1, 1, 1),
  elite(1.8, 1.3, 1.05, 1.5),
  highElite(3, 1.7, 1.1, 2),
  miniBoss(6, 2.2, 1, 3),
  boss(1, 1, 1, 4);

  final double hp, dmg, speed, reward;
  const Tier(this.hp, this.dmg, this.speed, this.reward);
}

/// Kill gold grows by this share every wave after the first, compounding (the owner's #83: "setiap wave coin
/// drop naik ... konstanta ini nanti bisa di adjust"; they picked 5% to start, 4.5% in decisions-log 318: at 5% the
/// flat troop prices made every rebuy free past wave 80).
const killGoldGrowth = 0.045;

/// The gold a kill of a monster of [base] gold ([Stats.cost] of its type) and rank [tier] pays in [wave]:
/// base × [Tier.reward] × (1 + [r])^(wave − 1), floored once at the end, not wave by wave (#83).
int killGold(int base, Tier tier, int wave, [double r = killGoldGrowth]) => (base * tier.reward * pow(1 + r, max(0, wave - 1))).floor();

/// The score ([Game.score], docs/scoreboard.md): points for every kill by the monster's rank (the boss's
/// raised skeletons pay no gold and score nothing) and [waveScore] × n for winning wave n. The lives left paid 50 each
/// at the game's end until decisions-log 329: since 322 a game ends only at 0 lives, so they paid nothing.
const killScore = {Tier.normal: 10, Tier.elite: 25, Tier.highElite: 50, Tier.miniBoss: 150, Tier.boss: 500};
const waveScore = 100;

/// A wave's monster dropped a relic at this chance by its rank in a game without the Towns (decisions-log 321): none from
/// normal and elite ones, the boss at most, never for sure; a necromancer's raised minions none. The [Game.loot] dice
/// still roll it and throw it away.
const relicChance = {Tier.normal: 0.0, Tier.elite: 0.0, Tier.highElite: 0.05, Tier.miniBoss: 0.10, Tier.boss: 0.30};

/// Every wave after the first adds this share of the base hp / dmg (a healer's heal) to every monster, up to
/// wave [waveLateFrom]; every wave after it adds [waveHpLate] / [waveDmgLate] instead, so the late waves stay
/// hard ([waveGrowth]; the owner's pick in #36; [waveHp] 0.15 until decisions-log 318 made waves 2-15 a little harder).
const waveHp = 0.17, waveDmg = 0.06;
const waveLateFrom = 15, waveHpLate = 0.30, waveDmgLate = 0.10;

/// What a monster's base hp or dmg is multiplied by in [wave]: 1 in wave 1, then [early] more a wave through
/// wave [waveLateFrom], and [late] more a wave after it.
double waveGrowth(int wave, double early, double late) {
  final w = max(0, wave - 1);
  return 1 + early * min(w, waveLateFrom - 1) + late * max(0, w - (waveLateFrom - 1));
}

/// ...and this share of its walking speed, its attacks per second and, for long range only, its reach, each
/// up to its early cap (all three are reached at wave [waveTempoTo], 26). Melee reach never grows.
const waveSpeed = 0.02, waveSpeedMax = 0.5, waveRate = 0.01, waveRateMax = 0.25, waveRange = 0.01, waveRangeMax = 0.25;

/// After wave [waveTempoTo] they keep growing (the owner's #71, "monster juga semua attributenya di buff"):
/// [waveSpeedLate], [waveRateLate] and [waveRangeLate] more a wave, walking up to [waveSpeedMost] more in all
/// and reach up to [waveRangeMost]; attacks have no cap of their own but the floor [minAttackInterval].
const waveTempoTo = 26;
const waveSpeedLate = 0.005, waveRateLate = 0.005, waveRangeLate = 0.005, waveSpeedMost = 0.75, waveRangeMost = 0.5;

/// And from the first late wave (after [waveLateFrom]) every monster has [waveDef] more defence a wave ([Stats.def],
/// taken off every blow it takes, [hitTaken]); monsters have none of their own (#71).
const waveDef = 0.05;

/// What a monster's walking speed, attacks per second or reach is multiplied by in [wave]: [early] more a
/// wave up to [earlyMax], then after wave [waveTempoTo] [late] more a wave, up to [most] more in all.
double tempoGrowth(int wave, double early, double earlyMax, double late, [double most = double.infinity]) {
  final w = max(0, wave - 1);
  return 1 + min(most, min(early * w, earlyMax) + late * max(0, wave - waveTempoTo));
}

/// A monster's defence in [wave] ([waveDef]).
double waveDefence(int wave) => waveDef * max(0, wave - waveLateFrom);

/// "Pasang", the tide (#92, decisions-log 142; the owner: "late game too easy"): from wave [tideFrom] the crowd
/// grows on top of [waveGrowth], compounding: [tideHp] more HP and [tideDmg] more damage (a healer's heal too) every
/// wave, and the gap between two monsters coming on [tidePace] shorter ([spawnGapOf]), never under [tideGapMin] s.
/// Every monster gets it but the wave's own boss and mini boss (their slots already bite): normal, elite and high
/// elite ones, the healing necromancers, an escort's high-elite summoner (#90) and every raised minion. Kill gold,
/// score, drops, speed, reach, defence and MP don't change. [tideHp] was 0.015 until decisions-log 161: with the army
/// cap that cliff took the owner's w63 army in 2-3 waves at w78-84 (3 of 6 runs over); at 0.01 none ended by w90 and the
/// falls rose over ~15 waves.
const tideFrom = 35, tideHp = 0.01, tideDmg = 0.005, tidePace = 0.005, tideGapMin = 0.5;

/// A save from before the tide catches up halfway: its tide counts from [tideCatchUp] waves before the wave it was
/// saved at, never before [tideFrom] ([Game.tideStart]). 999 would be the full tide at once, 0 a start from the load.
const tideCatchUp = 20;

/// The tide's multiplier in [wave] for a growth of [k] a wave, counted from wave [from] (1 up to it).
double tide(int wave, double k, [int from = tideFrom]) => pow(1 + k, max(0, wave - from)).toDouble();

/// The seconds between two monsters coming on in [wave], with the tide from wave [from]: [Game.spawnGap], [tidePace]
/// shorter a wave from [from], at least [tideGapMin].
double spawnGapOf(int wave, [int from = tideFrom]) => max(tideGapMin, Game.spawnGap * pow(1 - tidePace, max(0, wave - from)));

/// The spawn floor (the owner, 2026-10-04: "minimal jumlah enemy di field adalah jumlah troops/8"): while a wave's
/// queue still holds monsters, at least one monster alive on the field for every [spawnFloorPer] living troops
/// ([spawnFloorOf]). Below it the next one comes on at once, skipping the gap ([Game.tick]).
const spawnFloorPer = 8;

/// The spawn floor for [troops] living troops: [troops] / [spawnFloorPer], rounded up (0 with none, 1 with 1 to 8).
int spawnFloorOf(int troops) => (troops / spawnFloorPer).ceil();

/// Whether a monster of [tier] gets the tide: all but the wave's own boss and mini boss (a [raised] one does).
bool tided(Tier tier, {bool raised = false}) => raised || (tier != Tier.boss && tier != Tier.miniBoss);

/// The tide's HP in [wave] (from [from]) as the wave meter's badge shows it: whole percent more.
int tidePercent(int wave, [int from = tideFrom]) => ((tide(wave, tideHp, from) - 1) * 100).round();

/// The wave meter's tooltip on the tide in [wave] (from [from]): its name, then what it does to the crowd.
(String, List<String>) tideInfo(int wave, [int from = tideFrom]) => (Words.tide, [
      'Monster HP +${tidePercent(wave, from)}%',
      'Monster attack +${((tide(wave, tideDmg, from) - 1) * 100).round()}%',
      'A monster every ${spawnGapOf(wave, from).toStringAsFixed(2)} s',
      'Not the boss or mini boss',
    ]);

/// What the "VICTORY!" popup says on the win before the tide's first wave, and the message window when a save from
/// before the tide loads with it already on ([Game.tideCaughtUp]).
const tideNews = ('The ${Words.tide} rises!', 'Monsters get stronger every wave');

/// The army cap's warning (decisions-log 161; qa-4 on the owner's w63 save: once the army was down at the cap, the
/// tide took it in 2-3 waves and nothing had said so). While the army is full at the cap and the tide is on
/// ([Game.capPressed]), the message window says so between waves, once every [capWarnEvery] waves ([Game.capWarning]),
/// and the wave meter's tooltip ends with [capTip] ([Game.tideTip]).
const capWarnEvery = 5;

/// The warning's words: the cap and the coming wave's tide (whole percent of HP, as the meter's badge), then what
/// makes the army stronger now that it can't grow: the Army page's Awaken (decisions-log 230, 237).
String capWarningText(int cap, int tidePct) =>
    '${Words.army} full: cap $cap - ${Words.tide} +$tidePct%\nMake types stronger in the ${Words.army} page (${Words.awaken})';

/// The wave meter tooltip's last line while the army is full at the cap of [cap].
String capTip(int cap) => '${Words.army} full ($cap): make types stronger';

/// The one-time note ([Game.limitNotes], key "caps") for a game with types alive over their cap ([Game.overCaps]: "Priest
/// 17/5"), three to a line: they stay, and their buys wait (decisions-log 201).
String capsNote(List<String> over) => [
      'Each troop type has a cap now. You keep yours;',
      for (var i = 0; i < over.length; i += 3) '${i == 0 ? 'over it: ' : ''}${over.skip(i).take(3).join(', ')}${i + 3 < over.length ? ',' : '.'}',
      'Buy more of a type when under its cap.',
    ].join('\n');

/// No unit attacks (or heals) faster than once every [minAttackInterval] s, whatever speeds it up (gloves,
/// awakening, a Hero, War Cry, Rampage, the wave's growth); the wave's boss may go down to
/// [bossMinAttackInterval] ([Game.attackEvery]; the owner's #71: "maksimal attack speed hanya boleh 0.3 ...
/// kecuali boss, boss bisa sampai 0.2").
const minAttackInterval = 0.3, bossMinAttackInterval = 0.2;

/// A monster's stats: its type's (a boss's or mini boss's from its slot, [slotBase], unless it is a
/// necromancer's [raised] minion), raised by its [tier] (and a boss's or mini boss's [bossBuff], again not a
/// [raised] minion's) and the [wave] (a healer's heal, its [Stats.dmg], grows like damage), and the tide from wave
/// [tideStart] on HP and damage when it gets one ([tided]). Its [Stats.cost] is the gold its kill pays ([killGold]):
/// every monster's reward comes from here (the necromancer's raised skeletons get 0).
Stats enemyStats(String type, Tier tier, int wave, {bool raised = false, int tideStart = tideFrom}) {
  final s = switch (type) { boss => bossStats, necroHealer => necroHealerStats, _ => enemyTypes[type]! };
  final slot = !raised && enemyTypes.containsKey(type) && (tier == Tier.boss || tier == Tier.miniBoss);
  final (hp, dmg) = slot
      ? slotBase(s, tier, wave)
      // The necromancer mini boss has any mini boss's HP, its slot's reference's, not its own (the owner's #89), and
      // so does the high-elite one (an escort's summoner, #90).
      : (tier == Tier.miniBoss || tier == Tier.highElite) && type == boss
          ? (enemyTypes[poolOf(wave).last]!.hp.toDouble(), s.dmg)
          : (s.hp.toDouble(), s.dmg);
  final (kHp, kDmg) = switch (tier) {
    Tier.miniBoss when type == boss => (tier.hp, necroMiniDmg),
    // Its damage is the mini boss's share scaled by the two tiers' damage: 0.6 × 1.7 / 2.2 of its own (#90).
    Tier.highElite when type == boss => (tier.hp, necroMiniDmg * tier.dmg / Tier.miniBoss.dmg),
    Tier.boss when type != boss => (bossTypeHp, bossTypeDmg),
    _ => (tier.hp, tier.dmg),
  };
  final (bHp, bMp, bDmg) = raised ? (1.0, 1.0, 1.0) : bossBuff(tier, wave);
  final (tHp, tDmg) = tided(tier, raised: raised) ? (tide(wave, tideHp, tideStart), tide(wave, tideDmg, tideStart)) : (1.0, 1.0);
  return s._with(
      hp: (hp * kHp * bHp * waveGrowth(wave, waveHp, waveHpLate) * tHp).round(),
      dmg: dmg * kDmg * bDmg * waveGrowth(wave, waveDmg, waveDmgLate) * tDmg,
      speed: s.speed * tier.speed * tempoGrowth(wave, waveSpeed, waveSpeedMax, waveSpeedLate, waveSpeedMost),
      rate: s.rate / tempoGrowth(wave, waveRate, waveRateMax, waveRateLate), // [Stats.rate] is the pause between attacks
      range: s.shotSpeed > 0 ? s.range * tempoGrowth(wave, waveRange, waveRangeMax, waveRangeLate, waveRangeMost) : s.range,
      def: s.def + waveDefence(wave),
      mp: type == boss && necroMp[tier] != null ? (necroMp[tier]!.max * bMp).round() : null,
      mpRegen: type == boss ? necroMp[tier]?.regen : null,
      cost: killGold(s.cost, tier, wave));
}

/// Chances a monster of wave [wave] is elite / high elite (the rest are normal).
double eliteChance(int wave) => (0.05 * (wave - 2)).clamp(0.0, 0.35);
double highEliteChance(int wave) => (0.03 * (wave - 6)).clamp(0.0, 0.2);

/// A cast: the necromancer stands still [summonTime] and raises up to [minions] [minion]s of one tier
/// (they rise over [riseTime]), then can't cast again for [summonEvery]. After deciding to wait it thinks
/// again in [summonThink]. At most [maxMinions] of its raised ones live at once.
const summonEvery = 6.0, summonTime = 1.0, riseTime = 0.5, minions = 2, minion = 'skeleton';
const summonThink = 0.5, maxMinions = 6;

/// MP one raised minion of each tier costs. It grows faster than the tier's HP×DPS, so a higher tier
/// gives more for its MP ([Game.decideSummon] saves up for one when it is safe).
const summonCost = {Tier.normal: 10.0, Tier.elite: 22.0, Tier.highElite: 45.0, Tier.miniBoss: 110.0};

/// A summoner's MP by its own tier: the most it holds and what comes back per second. It starts with
/// [mpStart] of the most, so its first cast is a small one. The high elite is an escort's ([escortFrom]).
const necroMp = {Tier.highElite: (max: 60, regen: 2.0), Tier.miniBoss: (max: 120, regen: 4.0), Tier.boss: (max: 240, regen: 7.0)};
const mpStart = 0.25;

/// The waves from which a necromancer may raise elites, high elites and mini bosses: each boss after the
/// first raises one tier higher (wave 5 skeletons, 10 elites, 15 high elites, 20 on mini bosses).
const eliteSummonFrom = 10, highEliteSummonFrom = 15, miniBossSummonFrom = 20;

/// How far ahead (s) a necromancer at full health with nobody near plans ([Game.decideSummon]).
const calmHorizon = 30.0;

/// The highest tier a necromancer of tier [own] may raise in [wave]: one below its own, and no higher
/// than the wave allows ([eliteSummonFrom], [highEliteSummonFrom], [miniBossSummonFrom]).
Tier summonCeiling(Tier own, int wave) {
  final gate = wave >= miniBossSummonFrom
      ? Tier.miniBoss
      : wave >= highEliteSummonFrom
          ? Tier.highElite
          : wave >= eliteSummonFrom
              ? Tier.elite
              : Tier.normal;
  return Tier.values[max(0, min(own.index - 1, gate.index))];
}

/// What [Game.decideSummon] made of the situation: the tier to raise now ([cast]), or to wait
/// ([cast] null), saving up for [saving] (null when its minions are at [maxMinions]). [horizon] is how far
/// ahead it planned: the least of [calmHorizon] × its HP share, [reach] + [shield] and [life].
/// [scores] holds each tier's HP×DPS raised within the horizon.
class SummonChoice {
  final Tier? cast, saving;
  final double horizon, reach, shield, life;
  final Map<Tier, double> scores;
  const SummonChoice({this.cast, this.saving, required this.horizon, required this.reach, required this.shield, required this.life, this.scores = const {}});

  @override
  String toString() {
    String s(double v) => v.isFinite ? v.toStringAsFixed(1) : '∞';
    final what = cast != null ? 'cast ${cast!.name}' : (saving != null ? 'wait for ${saving!.name}' : 'wait (full)');
    return '$what | H ${s(horizon)} (reach ${s(reach)} shield ${s(shield)} life ${s(life)}) | '
        '${[for (final e in scores.entries) '${e.key.name} ${e.value.round()}'].join(', ')}';
  }
}

class Unit {
  final Side side;
  final String type;
  Stats stats; // grows with the upgrades its type has been given
  int maxHp;
  Point<double> pos;
  Point<double> post; // troops: where the player dropped them (shifted with the back line), walked back to when there's nobody to fight
  double hp, cd = 0, attackedAt = double.negativeInfinity, hurtAt = double.negativeInfinity, dying = -1;
  // Casting a summon or rising from the ground: stands still and doesn't fight until [busyUntil].
  double busyFrom = double.negativeInfinity, busyUntil = double.negativeInfinity, summonCd = 2;
  int dir; // horizontal facing: 1 = right
  Face face = Face.side;
  bool moving = false, gone = false;
  bool entered = false; // has walked onto the screen: monsters from the right, bought troops from the left
  bool arriving = false; // troops: walking to a spot they were just given, through the others rather than round them
  bool joining = false; // troops: bought mid-wave, still on the way in ([BattleFocus.troopFront] leaves it out). Not saved.
  bool retreating = false; // troops: hurt, falling back to a healer ([Game.retreatPolicy], [Game._fallBackTo])
  // Troops, for the fall-back decision ([RetreatFeatures]): the HP each blow took lately (time, HP), when a
  // healer last healed it, and since when it has stood at its healer's spot while falling back (NaN: not).
  final hurtLog = <(double, double)>[];
  double healedAt = double.negativeInfinity, waitFrom = double.nan;
  // Monsters: a healing necromancer's heal keeps the other healers' off it until then ([healWindow], #78).
  double healedUntil = double.negativeInfinity;
  Unit? healedBy;
  final relics = <Relic>[]; // troops: the relics this troop holds, in the order given: one, a Hero two ([relicSlots])
  // Troops, the Pusaka engine's (pusaka_engine.dart): its type's once-a-wave Fx used this wave (the Grail's save,
  // [grailK]; cleared at every wave's start), the every-Nth counter of the `landed`/`struck`/`hurtBy` Fx (an attack's
  // count is [blows]; a monster's: the troops' normal attacks on it, for the Bayangan Deflect, [Omens._omenDeflect]),
  // when an Fx's own cooldown ends, its shield's HP (its ward, up to [wardMax] of its max HP, gone at
  // the wave's end: heal.dart), a monster's one-hit mark from another type (Ember Brand's, batch E-2P: the Pusaka, the
  // type that marked it, its ×, until when; [FxEngine._fxEmber] spends it), and a troop's
  // one charge of power on its next normal attack (Momentum's, batch L-2P: the Pusaka and its ×; gone at a wave's
  // start). None saved.
  bool fxOnce = false;
  int fxN = 0;
  // Iron Will ([Relic.lastStand], relics.dart): its once-a-wave heal was used this wave; cleared at every wave's start.
  bool ironWillUsed = false;
  // The forge's nine (relics.dart, decisions-log 250), none saved: Chill's count of the hits it landed (never reset,
  // like Fury's [blows]), Afterglow's charged hits left after a skill and Hot Streak's stacks (each one's end, s), both
  // gone at a wave's start; on a monster, the Weak Spot mark it holds (the [Effect] put, for its counter); a troop's
  // relics and Artifact as the telemetry's pair key ([Relics.comboKeyOf], set at a wave's start).
  int chillHits = 0, glow = 0;
  final streak = <double>[];
  Effect? weakMark;
  String? comboKey;
  double fxReady = double.negativeInfinity, ward = 0;
  Relic? wardFrom; // the Pusaka that last added to its ward (heal.dart's giveWard): its counter gets what the ward soaks
  ({Relic relic, String from, double k, double until})? emberMark;
  ({Relic relic, double k})? charge;
  // The catalog's shared hooks (pusaka_engine.dart, catalog step 0f), none saved: when it first struck a foe (its first
  // blow through [Game._hurt] as the attacker; a troop's anew each wave, +∞ until then), the HP thresholds it went under
  // that answer once ([FxEngine.belowOnce]'s bits: a monster's for good, a troop's for a wave), and its near counts of
  // this tick ([FxEngine.alliesNearOf], [FxEngine.foesNearOf]: the tick, the reach and the count of each).
  double firstStrikeAt = double.infinity;
  int belowHp = 0;
  int alliesTick = -1, foesTick = -1, alliesN = 0, foesN = 0;
  double alliesR = 0, foesR = 0;
  String name = ''; // troops: a first and a last name ([troopName]); the wave's mini boss and boss one ([bossName]); other monsters none
  bool hero = false; // troops: made a Hero ([heroEvery]) for good; saved
  List<HeroStat> heroStats = const []; // a Hero's attributes ×[heroBoost] ([heroPoolOf]); saved
  int blows = 0; // attacks made, for [Relic.fury] and an `attack` Fx's every Nth (War Drum); a monster's for the Bayangan Pummel
  Tier tier = Tier.normal; // monsters: their rank
  // The necromancers' MP: the summoner raises minions with it (its last decision: [plan],
  // [Game.decideSummon]), the healing one pays for its heals.
  double mp; // MP now, up to [Stats.mp]
  SummonChoice? plan;
  bool swung = false; // the healing necromancer: its last action was a scythe swing, not a heal (for the UI)
  bool dry = false; // a troop healer: a heal found it short of MP ([healMp]) and its "No MP" popped; until it has it again. Not saved.
  SkillAnim? skillAnim; // the skill strip its last cast plays (skill_strips.dart): the UI's, never read by the fight, not saved
  TroopWind? troopWind; // a troop's skill winding up until it lands (skill_strips.dart, decisions-log 299); not saved
  // Skills ([troopSkills]): when this troop last cast its own (a monster its skill, monster_skills.dart); a
  // guard cutting [guardCut] of the damage it takes until [guardUntil] (Hold Fast, Holy Shield; a monster's
  // Bulwark); attacking faster until [frenzyUntil] (Rampage); a monster stunned until [stunUntil] (Crushing Blow).
  double skillAt = double.negativeInfinity, guardUntil = double.negativeInfinity, guardCut = 0;
  double frenzyUntil = double.negativeInfinity, stunUntil = double.negativeInfinity;
  // A troop a monster stunned can't be stunned again until [stunImmuneUntil] ([HeroMoves.stunTroop], #59); a
  // guard ring in its skill's colour ([guardLook]: a monster's skill's, Hold Fast's steel blue, Holy Shield's white;
  // null: the pale blue).
  double stunImmuneUntil = double.negativeInfinity;
  RingLook? guardLook;
  HeroSkill? heroSkill; // a Hero's own skill ([heroSkillPool]), rolled when it is made; saved
  bool revived = false; // troops: brought back by Resurrection once, never again; saved
  double heroSkillAt = double.negativeInfinity; // when it last cast [heroSkill]; cleared at every wave's start
  // Its type's awakening skill (awaken_skills.dart, #88): when it last cast it (set at every wave's start and at
  // the awakening moment so the type's troops come ready 0–3 s apart), and until when it doesn't ask its rule again
  // after the rule said no ([awakenThink]).
  double awakenSkillAt = double.negativeInfinity, awakenThinkAt = double.negativeInfinity;
  // Monster skills (monster_skills.dart): the one being wound up and when it lands (a stun or a shove before
  // then cancels it); when a long-range troop last hit this monster (Shield Up). Its cooldown runs from
  // [skillAt].
  MonsterSkill? winding;
  double windUntil = double.negativeInfinity, rangedHitAt = double.negativeInfinity;
  // Awakening skills on a monster (awaken_skills.dart, #88): when Impale last broke its wind-up (no second break
  // within [impaleK].window s), when a soldier last Disarmed it (no second Disarm within [disarmK].again s), and the
  // end Spellbreaker halved its guard to (its guard is halved once; a new guard ends elsewhere, NaN: none halved).
  double interruptedAt = double.negativeInfinity, disarmedAt = double.negativeInfinity, guardHalved = double.nan;
  // Reassemble (monster_skill_signatures.dart): a heap of bones until [downUntil], once a life ([reassembled]).
  double downUntil = double.negativeInfinity;
  bool reassembled = false;
  // A mini boss's other skill (boss_skills.dart): when it last cast it, and when it last began any skill; the
  // boss's moment: whether it landed, and when a cancelled one may wind up again; when this unit was hit before
  // its last hit (Unholy Ward).
  double bossSkillAt = double.negativeInfinity, castAt = double.negativeInfinity;
  double momentAt = double.negativeInfinity, hurtBefore = double.negativeInfinity;
  bool momentDone = false;
  final effects = <Status, Effect>{}; // what Hero skills left on this unit, troop or monster; cleared when a wave ends
  // Hero skills' movement (hero_moves.dart): carried by a knockback, a leap, a charge or a drag; bracing.
  Move? move;
  Brace? brace;
  Unit? raisedBy; // a raised minion: the necromancer that raised it (not one of the wave's monsters)
  Unit? escortOf; // one of a mini boss's or boss's escort ([escortFrom]): that mini boss or boss
  // A healing necromancer's ([Game._mend], decisions-log 314): what it is doing, since when, and the monster it heals
  // or walks to heal. Not saved (a save holds no wave in progress).
  Mend mend = Mend.rest;
  double mendAt = 0;
  Unit? mendOn;
  // The Bayangan (omen.dart) on a monster: a guard Guard brought ([Omens._omenQueue]), that mini boss or boss; one of
  // the wave's first after Lewati, with the skip buff in its stats ([skipBuffK]); a slot's Shield, the HP a blow breaks
  // before its own ([Omens._shieldSoak]), gone at the wave's end.
  Unit? guardOf;
  bool skipBuffed = false;
  double shield = 0;
  // A guard a Bayangan gave ([guardUntil], [guardCut]; the v2 rules, step 0j): its cut counts in the taken floor
  // ([Omens._omenTaken]), not after it. Every other guard clears it.
  bool guardOmen = false;
  // When the Bayangan Counterspell last shielded this high elite ([Omens._omenCounterspell]): once per
  // [omenCounterspellEvery] s. Not saved.
  double counterAt = double.negativeInfinity;
  // The Bayangan of batch E-2B (omen.dart), none saved: when Parting Gift last healed this monster
  // ([Omens._omenPartingGift]: once per [omenPartingGiftEvery] s) and Bile Sacs last hurt this troop ([Omens._omenBile]:
  // once per [omenBileEvery] s); the monster this troop last struck and when ([Game._strike], only while [omensOn] is
  // on: Blindside's, [Omens._omenBlindside]).
  double giftAt = double.negativeInfinity, bileAt = double.negativeInfinity;
  ({Unit foe, double at})? lastFoe;
  // The Bayangan of batch E-3B (omen.dart), none saved: this troop's heals the Bayangan Trickle spreads, each paying until
  // its own end ([Heal._healTroop], [Omens._omenTrickle]); what its heals owe the Bayangan Heal Siphon, paid each
  // [omenHealSiphonEvery] s to the nearest monster ([Omens._omenSiphon]); when the Bayangan Toll last took its share
  // ([Omens._omenToll]: once per [omenTollEvery] s). The first two end with the wave ([HeroSkills._endEffects]).
  final trickle = <TrickleHeal>[];
  double siphonDue = 0, tollAt = double.negativeInfinity;
  // The Bayangan Unbowed on a monster (batch G-1B, omen.dart): the holds, stuns and hexes it still shrugs off
  // ([Omens._omenShrug]), set as it comes on ([Omens._omenSpawn]). Not saved.
  int shrugs = 0;
  // The Bayangan of batch G-2B (omen.dart), none saved: on a monster, whether Renewal's shield ([Omens._omenRenewal]) and
  // Deathless's save ([Omens._omenDeathless]) were spent, once a life each; Adapt's run, the troop type whose blow struck
  // it last and how many of its blows in a row past the first ([Omens._omenAdapt]); Spree's troop kills
  // ([Omens._omenSpreeKill]); Vultures' target and its attack count when it was picked ([Omens._omenVultures]); when
  // Backlash last raised it ([Omens._omenBacklash]). On a troop, when Mana Burn last took its MP ([Omens._omenManaBurn]).
  bool renewed = false, omenSaved = false;
  String? adaptType;
  int adaptRun = 0, troopKills = 0, vultureBlows = 0;
  Unit? vultureFoe;
  double backlashAt = double.negativeInfinity, burnAt = double.negativeInfinity;
  // The Bayangan Rider Rush on an orc rider (batch G-3B, omen.dart): whether its first hit on a troop was spent
  // ([Omens._omenRiderRush]), once a life. Not saved.
  bool rushed = false;
  static int _ids = 0;
  final int id = _ids++; // creation order: the earlier-placed troop wins a tie on who passes
  Point<double> heading = const Point(1, 0); // direction of the last step
  double yieldUntil = double.negativeInfinity; // troops: standing aside for one passing, don't walk back yet
  // Troops walking ([Game._moveToward]): where to and how fast (the others look ahead with it, [Game._steer], #82),
  // and when last; how long it has walked without getting on, and until when it walks through its allies once
  // that went on too long ([Game._ghost]).
  Point<double>? goal;
  Point<double> vel = const Point(0, 0);
  double walkedAt = double.negativeInfinity, stuckFor = 0, throughUntil = double.negativeInfinity;
  // Between waves, the closest it has come to [closestTo] on this walk there ([Game._watchStuck]).
  double closest = double.infinity;
  Point<double>? closestTo;
  // Melee troops mid-wave (engage.dart, #84): the monster whose [spot] it holds or walks to, or that it waits for
  // one to free ([waiting]).
  Unit? spotOf;
  Spot? spot;
  bool waiting = false;
  // Mid-wave, when it last walked forward to a spot or its foe ([Game.turnHold]). Not saved.
  double forwardAt = double.negativeInfinity;
  Unit(this.side, this.type, this.stats, this.pos)
      : maxHp = stats.hp,
        hp = stats.hp.toDouble(),
        mp = stats.mp.toDouble(),
        post = pos,
        dir = side == Side.troop ? 1 : -1;

  bool get alive => dying < 0 && !gone;

  /// How fast it walks: its speed stat, a troop's at most [walkCap] (decisions-log 311). Whatever walks reads this (its
  /// walk, kiting, falling back, the catch-up pace, its steps aside, the stall detector); a charge goes at its speed stat.
  double get walkSpeed => side == Side.troop ? min(stats.speed, walkCap(type)) : stats.speed;

  /// Whether this troop holds [relic] (a Hero's two slots are two different kinds).
  bool holds(Relic relic) => relics.contains(relic);

  /// How many relics this troop can hold: one, a Hero [heroRelicSlots].
  int get relicSlots => hero ? heroRelicSlots : 1;

  /// Where a troop belongs, back to front: 0 healer, 1 long range, 2 melee.
  int get line => stats.heals ? 0 : (stats.shotSpeed > 0 ? 1 : 2);

  /// Place in the formation, back to front: healer 0, long range 1, heavy melee 2 (cavalry, spear,
  /// axe), front melee 3 ([vanguard]).
  int get rank => line + (vanguard.contains(type) ? 1 : 0);
  static const vanguard = {'soldier', 'knight', 'swordsman'};

  /// The heavy-armored melee (speed 18): the light melee walking in don't run far ahead of them
  /// ([Game.paceLimit], #56).
  static const heavyArmor = {'knight_templar', 'armored_axeman'};
  (int, int) get cell => ((post.x / tile).floor(), (post.y / tile).floor());
}

/// Where a blow comes from: every [Game._hurt] names one (catalog step 0f, catalog-design §2.3), for the catalog's
/// rules that read it (Scatter, Spell Ward, Thornproof, Holy Ward, the Oath of Spells). Nothing reads it yet.
enum Hit {
  /// A normal attack on its target: a fighter's blow or shot, the necromancer's scythe.
  normal,

  /// A troop healer's holy light on a dark monster ([Game._smite]).
  smite,

  /// A skill's blow, everyone its area hits included: a troop's, an awakening's, a Hero's, a monster's.
  skill,

  /// Extra damage: a normal attack's splash past its target, a Pusaka's leap.
  extra,

  /// Damage sent back at an attacker: worn thorns, a reflect, a Parry's answer.
  hitBack,

  /// A bleed's tick.
  bleed,

  /// A small relic's own blow: Sweep's hit on the monster next to the target (relics.dart).
  relic,
}

class Shot {
  final Unit from, target;
  final Hit src; // its blow's source ([Hit]): a normal attack's, or a skill's
  final double dmg; // what it does when it lands (a fury blow is doubled when fired)
  final double splash; // over what radius: the shooter's, or a skill's
  final bool big; // a skill's shot (Arcane Blast): drawn as the skill's (the ice star), with a bigger hit ([shotHitFx])
  final RingLook? ring; // a ring bursting out over its splash where it lands (Arcane Blast's, #81)
  final double? speed; // its own speed (hero_shots.dart), else the shooter's [Stats.shotSpeed]
  final ShotLook look; // how the UI draws it: the shooter's own arrow or magic, or a Hero skill's
  final void Function(Unit hit)? onHit; // after its damage, on each unit it hurt
  Point<double> pos;
  bool done = false;

  /// Where it flies once its target fell or left (swept off, gone): the target's place at that moment, frozen there;
  /// null while it homes on its living target. It lands there as on its target (decisions-log 327, [Game.tick]).
  Point<double>? to;

  /// In the air when its wave ended or the army was wiped: it lands its look and does nothing (decisions-log 327).
  bool spent = false;
  bool pummel = false; // a monster's every 3rd under the Bayangan Pummel ([Omens._omenPummel]): set as it is fired
  bool sap = false; // a monster's every 4th under the Bayangan Sap ([Omens._omenSapBlow]): set as it is fired
  Shot(this.from, this.target, this.pos, this.src, [double? dmg, double? splash, this.big = false, this.ring])
      : dmg = dmg ?? from.stats.dmg,
        splash = splash ?? from.stats.splash,
        speed = null,
        look = ShotLook.plain,
        onHit = null;

  /// A shot that isn't [from]'s normal attack (a Hero skill's): its own [dmg], [speed] and [look], so a
  /// melee troop can throw one too, and [onHit] on each unit it hurts. Like every shot it homes on
  /// [target] however far that is, so it may be fired past the shooter's range.
  Shot.special(this.from, this.target, this.pos,
      {required this.dmg,
      required double this.speed,
      this.splash = 0,
      this.big = false,
      this.look = ShotLook.plain,
      this.onHit,
      this.ring})
      : src = Hit.skill;

  /// Where it flies: its living target, or the spot that target went from ([to]).
  Point<double> get aim => to ?? target.pos;
}

/// How near the spot a shot lands on, when its target went ([Shot.to]), a unit of that target's side must stand to take
/// the shot as its target would have (decisions-log 327): half a tile, a line shot's width ([lineWidth]). Every splash
/// reaches further, so that unit is always in it.
const landReach = lineWidth;

const _attackSfx = {'archer': Sfx.dagger, 'wizard': Sfx.magic, 'priest': Sfx.magic, necroHealer: Sfx.magic};

/// The burst shot [s] shows where it lands ([Game.impacts]): its shooter's hit burst (`hit_<type>`, `hit_<type>_big`
/// for a skill's [Shot.big]), but a wizard's own shots land as the Tiny RPG pack's magic they are drawn with
/// (decisions-log 313; main.dart's wizard_fx.dart): `fireball` its plain shot's, `shards` Arcane Blast's. Only the look:
/// the other `hit_wizard` bursts (a Hero's or an awakening's magic, God's Thunder) stay.
String shotHitFx(Shot s) => s.from.type == 'wizard' && s.look == ShotLook.plain
    ? (s.big ? 'shards' : 'fireball')
    : 'hit_${s.from.type}${s.big ? '_big' : ''}';

class Game {
  static const spawnGap = 0.9, startGold = 150, startLives = 6, _personalSpace = 12.0, _lookAhead = 20.0, _engagedFor = 2.0, _kiteAt = 0.75;

  /// Two walking troops closer than [_meetRange] whose ways would bring them within [_personalSpace] in the next
  /// [_meetTime] s meet: the one that doesn't go first finds a way round ([_steer], #82).
  static const _meetRange = 3 * tile, _meetTime = 1.0;

  /// A troop that has walked [_stuckAfter] s without getting on walks through its allies for [_throughFor] s
  /// ([_ghost]): nobody freezes in a jam (#82).
  static const _stuckAfter = 1.5, _throughFor = 1.0;

  /// How much further than its rank's place a support may trail the melee before it catches up ([speedTo]).
  static const _catchUp = 1.5 * tile;

  /// The catch-up pace is at most this many times the troop's own walk speed ([speedTo]; decisions-log 309, the owner:
  /// "Batasi 2×"). Before, the fastest melee's: 275 on the owner's wave-30 save (a Hero knight with boots), 8.6-13×
  /// an archer's or a wizard's walk.
  static const catchUpMost = 2.0;

  /// A troop that has entered stays at least this far past the back line.
  static const clearOfLine = 4.0;

  /// How far ahead of the foremost heavy-armored melee walking in the light melee may get ([paceLimit]).
  static const paceLead = 2.5 * tile;

  /// The front's cap (decisions-log 324): mid-wave no troop walks past [capInset] inside the view's right edge
  /// ([frontCap]), so it stays on the screen with its sprite and bar. The view centres the fight, so it seldom binds.
  static const capInset = tile;

  /// Mid-wave a troop healer rests no further than this behind the rearmost melee in the fight (decisions-log 324),
  /// so the supports follow the melee and the army stays together round the fight the view centres ([_heal]).
  static const healBehind = 2.5 * tile;

  /// A melee troop that walked forward less than this long ago doesn't turn back to a spot or a wait point behind it
  /// (more than [turnSlack] behind): it stands facing its foe meanwhile, so a spot taken and freed again, or a step
  /// aside, doesn't send it back and forth (decisions-log 324).
  static const turnHold = 0.6, turnSlack = 1.0;

  /// A troop whose centre is this far left of the view's edge is out of sight ([leftOfView]): the tiny
  /// sprites' bodies are about a tile wide.
  static const offViewBy = tile / 2;

  /// Whether [a] goes first when it meets [b]: the one on the move before one standing, then the further
  /// forward (Healer | long range | melee), else the one placed first. Between waves that is all: a fixed order,
  /// so between two walking troops who gives way never changes while they meet, and no ring of troops each waits
  /// for the next (#82). In battle a troop coming through from behind (on the move, heading forward, further
  /// back) goes first before that: it heads for the fight. Between waves it did too until #82, and a yielder
  /// pushed back came through next and took the way, so two archers crossing swapped it back and forth for good.
  /// There is always an answer, so two troops never just shove each other back and forth.
  bool _passes(Unit a, Unit b) {
    if (waveActive) {
      // [o] is ahead of [u] rather than beside it, and [u] is walking forward into it.
      bool comingThrough(Unit u, Unit o) => u.moving && u.heading.x > 0 && o.pos.x - u.pos.x > (o.pos.y - u.pos.y).abs();
      if (comingThrough(a, b) != comingThrough(b, a)) return comingThrough(a, b);
    }
    if (a.moving != b.moving) return a.moving;
    return a.line != b.line ? a.line > b.line : a.id < b.id;
  }

  final Random rng;
  int gold = startGold, lives = startLives, wave = 0;

  /// The wave the tide counts from ([tide], #92): [tideFrom] in a new game; a save from before the tide catches up
  /// halfway ([tideCatchUp]). Saved.
  int tideStart = tideFrom;

  /// A save from before the tide came in with it already on: the UI says so once ([tideNews]) and clears it. Not
  /// saved.
  bool tideCaughtUp = false;

  /// The wave just won is the last before the tide's first ([tideStart]): the "VICTORY!" popup says so ([tideNews]).
  bool get tideRising => wave == tideStart - 1;

  /// The wave meter's tooltip ([tideInfo]) on the wave it shows (this one in a wave, else the next), ending with [capTip]
  /// while the army is full at the cap ([capPressed], decisions-log 161). Beban's line for an army over the cap (its tide
  /// counted from earlier waves, decisions-log 162) went with Beban in decisions-log 329.
  (String, List<String>) get tideTip {
    final (title, lines) = tideInfo(waveActive ? wave : wave + 1, tideStart);
    return (title, [...lines, if (capPressed) capTip(armyMax!)]);
  }

  /// Points so far ([killScore], [waveScore]) and monsters killed
  /// (the boss's raised skeletons too): what goes on the scoreboard.
  int score = 0, kills = 0;

  /// The back line: the deploy zone starts here, and no monster goes past it (it cost a life until decisions-log 329:
  /// the monsters there wait for the troops, and nothing is lost). It stays put all
  /// wave, however far the fight goes (#79, the owner: "garis belakang di majukan setiap selesai wave
  /// saja"), and when a wave is won it moves up to wherever the rearmost troop stands, never back.
  double baseX = 0;
  double victoryAt = double.negativeInfinity;

  /// How much of the field one screen shows; the UI widens it to fill the screen.
  double viewW = cols * tile;

  /// Left edge of the view. It eases after [viewMid] − viewW/2 ([BattleFocus]); the UI draws from it.
  double cam = 0;

  /// World x of the view's centre: the battle point mid-wave ([BattleFocus.viewGoal]). NaN until the first
  /// tick. Not saved, nor is the rest of the battle point's state below.
  double viewMid = double.nan;

  /// Where the view's centre heads mid-wave ([BattleFocus.aim]), held through lulls; the last fight's x this
  /// wave (the minimap's gold line); and what the aim is doing.
  double? meetX, fightX;
  MeetMode meetMode = MeetMode.rest;
  double? _rivalSince; // when a clearly heavier fight began to outrank the one shown
  double _contactAt = double.negativeInfinity;
  bool _gliding = false, _wasActive = false;
  int _aimWave = 0;

  /// Where the view's left edge is heading ([BattleFocus.viewGoal]): mid-wave the battle point, where the
  /// troops and the monsters meet, mid-screen (#85); between waves the back line at the left edge, or further
  /// on when the front troop would walk off the right one.
  double get camTarget => viewGoal - viewW / 2;

  /// Monsters on screen are kept this far from its right edge, so a shove never pushes them out of view.
  double get rightLimit => cam + viewW - 2 * tile;

  /// Gold for winning wave [n]; [lastBonus] is what the last won wave paid.
  static int waveBonus(int n) => 20 + 10 * n;
  int lastBonus = 0;
  int get baseCol => (baseX / tile).round();
  double t = 0, _spawnTimer = 0, _dt = 0; // [_dt]: the tick's step
  final units = <Unit>[], shots = <Shot>[], queue = <(String, Tier)>[], sfx = <Sfx>[];

  /// The skills' line shots, ground zones, beams and bursting rings (hero_shots.dart), a Hero's or a monster's.
  /// Not saved: saves are made between waves, and a wave's end clears the zones.
  final lineShots = <LineShot>[], zones = <Zone>[], beams = <Beam>[], rings = <Ring>[];

  /// How many of this wave's [queue] have come on so far; with what is still queued that is the whole
  /// wave ([waveTotal]), for the wave meter. The boss's raised skeletons don't count.
  int waveSpawned = 0;
  int get waveTotal => waveSpawned + queue.length;

  /// The mini boss or boss that came on last from [escortFrom], and how many of its escort are still to come:
  /// the healing necromancers and the high-elite necromancer right behind it in the [queue] ([Unit.escortOf]).
  Unit? _escorted;
  int _escortDue = 0;

  /// The Guard Bayangan's monsters in this wave's [queue] (omen.dart, [Omens._omenQueue]): their places in the wave
  /// (0 the first to come on, as [waveSpawned] counts), and the last mini boss or boss to come on and its row, which
  /// its guards take. Not saved (a save holds no wave in progress).
  final _guardsAt = <int>{};
  ({Unit slot, double y})? _guarded;

  /// How many of this wave's first monsters, by the order they come on, get Lewati's skip buff ([waveSkipBuff],
  /// [skipBuffShare] of the queue, counted at its start by [Omens._omenQueue]); 0 with none owed. Not saved.
  int skipBuffN = 0;

  /// Bursts for the UI to draw (where, effect: a troop's splash or 'summon'; an awakened troop's in its
  /// level's look, [awakeFx]); drained like [sfx].
  final impacts = <(Point<double>, String)>[];
  final raised = <Unit>[]; // summoned this tick, joined after the update loop
  final healQueue = <Unit>[]; // troops still waiting for their after-wave heal
  static const healGap = 0.4;

  /// The Bag's items at +0, how many of each: the Smithy makes them (town.dart); no monster drops one (decisions-log 321).
  final inventory = <Item, int>{};

  /// The Bag's enhanced items (decisions-log 255; enhance.dart): how many of each (item, plus) stack, the plus 1 to
  /// [EnhanceRules.most]; +0 is [inventory]'s. Each stack is its own Bag cell.
  final enhancedBag = <(Item, int), int>{};
  final relicBag = <Relic, int>{};

  /// The Towns' materials (town.dart, decisions-log 221): the ones held (saved, by name), the ones dropped in the wave
  /// being fought (they come into [materials] when it is won, and a lost game loses them, like the loot), and the ones
  /// the last won wave brought.
  final materials = <Mat, int>{};
  final waveMaterials = <Mat, int>{};
  Map<Mat, int> lastMaterials = const {};

  /// The kinds of material that have dropped this run, in the order they first dropped ([Materials._dropMaterials]; one
  /// bought never adds): the forge's Town Shop sells only these (decisions-log 246). Saved as `matsSeen` once any was
  /// seen; a save without it starts from the materials held.
  final matsSeen = <Mat>{};

  /// Materials just dropped, where the kill fell, which and how many, for the UI: they lie there until the wave is won
  /// ([Materials._dropMaterials], decisions-log 262); drained like [impacts].
  final matPops = <(Point<double>, Mat, int)>[];

  /// How many of each kind ([Item] or [Relic]; with the forge's Town Shop a material, [Mat]) the store sold this game: its
  /// price rises with each (store.dart).
  final storeBought = <Enum, int>{};

  /// The Pusaka owned (pusaka.dart): each bound to a troop type or waiting in the Gudang, with its stars. Saved. Every
  /// change to it rebuilds the books ([_books]).
  final Map<Relic, OwnedPusaka> pusaka = _PusakaMap();

  /// Each type's bound Fx by trigger (pusaka_engine.dart, [FxEngine._bookOf]), as of [_bookAt] ([_pusakaEdits]); and
  /// how deep in extra damage (a leap) the fight is now: there only the `dealt` Fx run. Not saved.
  final _books = <String, FxBook>{};
  int _bookAt = -1, _fxDepth = 0;

  /// The ticks run ([tick]): the stamp of the near counts ([FxEngine.alliesNearOf]). And the Fx a
  /// [If.firstOfTypeThisWave] condition let through this wave, by Pusaka and Fx number ([FxEngine._fxWhen]; cleared by
  /// [startWave]). Not saved.
  int _ticks = 0;
  final _fxFirsts = <(Relic, int)>{};

  /// When each Pusaka's type-wide cooldown ends ([FxEngine._fxTypeGate]: Soul Shelter's, batch G-2; cleared by
  /// [startWave]), and the troops passing a share of the blow being dealt on through a link now
  /// ([HeroSkills._beforeDefence]: Shared Wounds', Guardian Chain's), so two links on each other never loop. Not saved.
  final _fxTypeReady = <Relic, double>{};
  final _linking = <Unit>{};

  /// The types with a troop alive as counted at tick [_typesTick] ([FxEngine.typesAliveNow], Unity Ring's condition):
  /// counted at most once a tick. Not saved.
  int _typesTick = -1, _typesN = 0;

  /// The living high elites on the field as found at tick [_captainsTick] ([Omens._captained], the Bayangan Captain's
  /// aura): found at most once a tick. Not saved.
  int _captainsTick = -1;
  final _captains = <Unit>[];

  /// The living monsters on the field as counted at tick [_hordeTick] ([Omens._omenHorde], the Bayangan Horde's steps):
  /// counted at most once a tick. Not saved.
  int _hordeTick = -1, _hordeN = 0;

  /// Whether the wave's boss or mini boss lives, as found at tick [_slotAliveTick] ([Omens._omenWarlord], the Bayangan
  /// Warlord's): found at most once a tick. Not saved.
  int _slotAliveTick = -1;
  bool _slotAlive = false;

  /// The Bayangan Dusk (omen.dart), none saved: the place in the wave's queue of its last crowd monster, the last that
  /// isn't the boss or a mini boss, an escort nor a Guard's ([Omens._omenCrowd], found as the wave starts; -1: none, or
  /// the omens off); the time it came on, the crowd all in (null until then); and whether Dusk has fallen,
  /// [omenDuskAfter] s after that, until the next wave's start ([Omens._omenDuskTick]). Only while [omensOn] is on.
  int _crowdLast = -1;
  double? _crowdInAt;
  bool duskOn = false;

  /// The HP the last troop heal gave ([Heal._healTroop]): what landed, or a heal the Bayangan Trickle spreads in full at
  /// the call. The sites that count a heal read it (the heals Fx, the Pusaka's counters). Not saved.
  double _healGained = 0;

  /// When the Bayangan Heal Siphon last paid the troops' debts ([Omens._omenSiphon]): once every
  /// [omenHealSiphonEvery] s. Not saved.
  double _siphonAt = double.negativeInfinity;

  /// A `gold` Fx's extra gold not paid yet, under one coin (Looter's Pouch, [FxEngine._fxGold]): a share of a small
  /// kill's gold adds up until it is a whole coin. Not saved (a save drops less than a coin).
  double _goldBits = 0;

  /// The Bayangan Deflect cancelled the last normal attack [_hurt] took ([Omens._omenDeflect]): [_strike] and a shot's
  /// landing lower it before their blow and read it after, so a cancelled hit runs no `landed` Fx. Not saved.
  bool _deflected = false;

  /// The monster's normal attack [_hurt] takes now is a Bayangan Pummel's ([Omens._omenPummel]): [_strike] and a shot's
  /// landing ([Shot.pummel]) raise it around their blow, and [Omens._omenDealt] reads it. Not saved.
  bool _pummeled = false;

  /// The monster's normal attack [_hurt] takes now is a Bayangan Sap's ([Omens._omenSapBlow]): raised as [_pummeled] is
  /// ([Shot.sap] for a shot), and [_hurt] weakens the troop it lands on ([Omens._omenSap]). Not saved.
  bool _sapped = false;

  /// The heal funnel (heal.dart): a Wound factor a test or a probe puts in place of the Bayangan levels' ([Heal._woundK];
  /// null: the levels'), and a test's listener on every troop heal, once it landed (the troop, its tag, the heal asked
  /// before Wound, the heal past full HP; null in the game), and on every monster heal (the monster, its tag, the heal
  /// asked, the HP it gained: 0 under [Status.noHeal]). Not saved.
  double? woundForce;
  void Function(Unit u, HealSrc src, double asked, double past)? onTroopHeal;
  void Function(Unit u, MonsterHeal src, double asked, double gained)? onMonsterHeal;

  /// The one-time messages already shown, by key, so none shows twice: [pusakaNote] "pusaka" (a new game has seen it),
  /// and the limits' "army", "over" and "caps" ([limitNotes]; an older save's "types" stays, unread). Saved (only when
  /// any).
  final notes = <String>{};

  /// The wave (the last one fought) when a Pusaka last gained a star by Asah (pusaka.dart, [Asah.asah]); null: never.
  /// One Asah per boss interval ([Asah.asahDone]). Saved (only when set).
  int? asahAt;

  /// The run's Ukir (pusaka.dart, [Ukir.feedUkir]): the boss interval's budget spent and the star worth fed. Saved once
  /// fed.
  final ukir = UkirRun();

  /// What each Pusaka did in the wave being fought ([PusakaTally]); cleared at every wave's start, not saved.
  final pusakaWorth = <Relic, PusakaTally>{};

  /// What each of the forge's nine small relics did in the wave being fought ([PusakaTally]: its uses and the damage it
  /// added; relics.dart, decisions-log 250), and the damage each pair a troop wields dealt ([RelicPair], by
  /// [Relics.comboKeyOf]); both cleared at every wave's start, not saved.
  final relicWorth = <Relic, PusakaTally>{};
  final relicPairs = <String, RelicPair>{};

  /// The Legenda found this run (decisions-log 155): taken from a chest (or given), so never on a card again, even
  /// once sold; one oath found keeps every other off the cards too ([Draft._offerable]). So every Legenda is found once
  /// each one but the oaths and one oath is: then a Legenda roll steps down to an Epik (decisions-log 247). Saved (only
  /// when any).
  final legendsFound = <Relic>{};

  /// What the oath multiplies every troop's HP and damage by in [statsOf], as the troops were last refit
  /// ([_refitTroops]; [Pusaka._oathWatch] refits them when it moves). 1 with no oath. Not saved.
  double _oathK = 1;

  /// The oath the troops were last refit to ([_refitTroops]; [Pusaka._oathWatch] refits them when it changes), or null:
  /// what the stats ([Pusaka._oathStats]) and the fight read (Blood Oath's heals, Oath of Spells' blows and cooldowns, Oath
  /// of Kings' Hero numbers: decisions-log 247). Not saved: a load refits.
  Relic? _oathOn;

  /// The Grail saves of this wave not yet kept or lost: the troop, when, and the Pusaka that saved it ([keptAfter],
  /// [Pusaka._watchGrail]).
  final _grailWatch = <(Unit, double, Relic)>[];

  /// The wave's first Grail save, for the UI's cut-in ("Grail menyelamatkan Kael Drake!", one a wave; decisions-log
  /// 149); the UI clears it.
  Unit? grailFirst;

  /// The small relics that went back to the bag as their troops fell in the wave being fought, by kind; cleared when a
  /// wave starts, not saved. [lastPusaka] is the last won wave's report of them and of the Pusaka, for the "VICTORY!"
  /// line (null: nothing to tell).
  final relicsBack = <Relic, int>{};
  PusakaReport? lastPusaka;

  /// When God's Thunder last drew its leaps ([godThunderK].beamsPerSec): the times of the last second's.
  final _thunderLooks = <double>[];

  /// Owns [relic] at [stars], bound to [type] (null: in the Gudang), with no price, no wave check and no event: for
  /// loads, tests and probes (probe_knobs.dart reaches it by name, so it is a member, not pusaka.dart's). [ukir]: its
  /// Ukir steps (its own kept when null; the bar empty). The player binds with [Pusaka.bindPusaka].
  void givePusaka(Relic relic, {String? type, int stars = 1, int? ukir}) {
    _givePusaka(relic, type, stars);
    if (ukir != null) {
      pusaka[relic]!
        ..ukir = relic.oath ? 0 : ukir.clamp(0, ukirCost.length)
        ..feed = 0;
      if (pusaka[relic]!.type case final t?) _refitType(t);
    }
  }

  /// Taps Ukir on the bound Pusaka (every one owned without [bound]) until none takes more, the fewest steps first, so
  /// they rise together ([Ukir.feedUkir]); the points fed. A probe's player (the probes reach it through `dynamic`).
  int ukirFill({bool bound = true}) => _ukirFill(bound: bound);

  /// Every Pusaka in the Gudang bound by the migration's rule ([pusakaPrefs]), free (probe_knobs.dart's PUSAKA=bound).
  void bindByDefault() => _bindByDefault();

  /// The troops that fell in the wave being fought, in the order they fell (their relics went back to the
  /// bag as they fell); [lastFallen] is the last won wave's, for the "VICTORY!" popup.
  final fallen = <Unit>[];
  List<Unit> lastFallen = const [];

  /// "Ganti yang gugur" (#92): the last won wave's fallen troops (not the Heroes) that can still be bought back
  /// between waves ([replaceFallen]), each with its old spot, moved up with the back line like the living troops'.
  /// Cleared when a wave starts. Saved.
  final toReplace = <({String type, Point<double> post})>[];

  /// Auto (decisions-log 283, auto_replace.dart): every troop that falls (not a Hero) is bought back as the gold allows.
  /// Off by default; saved. Its queue mid-wave, in the order they fell, each marked when it came from [toReplace] at the
  /// wave's start; and how many of each type it bought back of this wave's fallen (they leave [toReplace] at the win).
  bool autoReplace = false;
  final _autoQueue = <({String type, bool carried})>[];
  final _autoBack = <String, int>{};

  /// What buying back every troop in [toReplace] would cost now ([priceOf]).
  int get replaceCost => toReplace.fold(0, (sum, f) => sum + priceOf(f.type));

  /// "Hero Gugur" (#92 part 3, recall.dart): every Hero that fell and hasn't been called back, in the order they fell,
  /// each with its name, type, attributes and skill ([FallenHero]). Saved; saves from before it have none.
  final fallenHeroes = <FallenHero>[];

  /// The Heroes just called back ([Recall.recallHero]), for the UI's splash (`<name> kembali!`); drained like
  /// [heroMade]. Not saved.
  final heroRecalled = <Unit>[];

  /// Hands [u] one small [relic] from the bag. A troop holds one relic, a Hero two of different kinds
  /// ([Unit.relicSlots]): one that holds that kind, or has no slot free, refuses it ([relicRefusal]), and the
  /// relic stays in the bag. A Pusaka is never given to one troop: it is bound to a type ([Pusaka.bindPusaka]).
  bool useRelic(Relic relic, Unit u) {
    if ((relicBag[relic] ?? 0) == 0 || over || relicRefusal(relic, u) != null) {
      sfx.add(Sfx.error);
      return false;
    }
    relicBag[relic] = relicBag[relic]! - 1;
    u.relics.add(relic);
    u.comboKey = comboKeyOf(u); // a pair given mid-wave counts at once (relics.dart)
    _emit(RelicUsed(wave, t, relic: relic, type: u.type));
    impacts.add((u.pos, 'upgrade'));
    sfx.add(Sfx.magic);
    return true;
  }

  /// Why troop [u] itself can't take [relic], in the UI's words, or null (the bag and the game's end aside): it is a
  /// Pusaka ([pusakaOnType]), it isn't a living troop ([assignRefusals].gone), it holds that kind already
  /// ([holdsRelic]), or no slot is free ([Unit.relicSlots]): a troop then says the relic it holds, a Hero
  /// [assignRefusals].full.
  String? relicRefusal(Relic relic, Unit u) {
    if (relic.pusaka) return pusakaOnType;
    if (!(u.side == Side.troop && u.alive)) return assignRefusals.gone;
    if (u.holds(relic)) return holdsRelic(relic);
    if (u.relics.length < u.relicSlots) return null;
    return u.relicSlots == 1 ? holdsRelic(u.relics.first) : assignRefusals.full;
  }

  /// Why [relic] can't come off troop [u] now, in the UI's words, or null: the game is over, a wave is on
  /// ([takeOffMidWave]), the troop fell, or it doesn't hold it.
  String? whyNotTakeOff(Relic relic, Unit u) {
    if (over) return assignRefusals.over;
    if (!takeOffMidWave && waveActive) return takeOffRefusals.midWave;
    if (!(u.side == Side.troop && u.alive)) return assignRefusals.gone;
    return u.holds(relic) ? null : takeOffRefusals.none;
  }

  /// Takes [relic] off troop [u] back into the bag (#91, "Lepas"), between waves: from there it is given again or
  /// sold like any other. A refusal ([whyNotTakeOff]) plays the error and changes nothing.
  bool takeOff(Relic relic, Unit u) {
    if (whyNotTakeOff(relic, u) != null) {
      sfx.add(Sfx.error);
      return false;
    }
    u.relics.remove(relic);
    relicBag[relic] = (relicBag[relic] ?? 0) + 1;
    u.comboKey = comboKeyOf(u);
    _emit(RelicTakenOff(wave, t, relic: relic, type: u.type));
    sfx.add(Sfx.place);
    return true;
  }
  Random loot = Random(); // its own dice, so drops don't shift the spawn sequence
  Random names; // the troops' names' dice ([troopName]), apart for the same reason
  Random heroes = Random(); // who becomes a Hero ([heroEvery]), apart for the same reason
  Random slots = Random(); // the boss's and the mini boss's types (#58), apart for the same reason
  Random draft = Random(); // the boss chest's cards (draft.dart), apart for the same reason
  Random omenDice = Random(); // the cards' Bayangan faces (omen.dart), apart so the cards are the same with them or not

  /// Every die the game rolls ([rng] and [names] first, as [Game] and [Game.fromJson] take them). A new die goes here
  /// and in [seedDice] (test/dice_test.dart holds both to the `Random` fields).
  List<Random> get dice => [rng, names, loot, heroes, slots, draft, omenDice, tavernDice, townDice, matDice];

  /// Seeds every die after [rng] and [names] from [seed] for a probe or a test that must replay ([dice]), at the offsets
  /// the probes have used: [loot] +200, [heroes] +300, [slots] +400, [draft] +500, [townDice] +600, [matDice] +700,
  /// [tavernDice] +800 and [omenDice] +900 (none seeded it before decisions-log 319, so a run with the Shadows on was
  /// never the same twice). The game itself never calls it: a player's dice are unseeded.
  Game seedDice(int seed) => this
    ..loot = Random(seed + 200)
    ..heroes = Random(seed + 300)
    ..slots = Random(seed + 400)
    ..draft = Random(seed + 500)
    ..townDice = Random(seed + 600)
    ..matDice = Random(seed + 700)
    ..tavernDice = Random(seed + 800)
    ..omenDice = Random(seed + 900);

  /// The Bayangan the enemy holds (omen.dart, decisions-log 180): one entry a level, oldest first, so a kind's level is
  /// its count ([Omens.omenLevel]) and the ease takes the last. Saved, only while [omensOn] is on.
  final omens = <OmenKind>[];

  /// An old save's catch-up levels still to land ([Omens.omenCatchUp], [omenCatchUpStep] a wave), oldest first. Saved.
  final omensOwed = <OmenKind>[];

  /// A chest was passed over (Lewati) from [omenFrom]: the next wave's first enemies get the skip buff (the owner's
  /// rule, catalog-design §4.4; step 0d builds it). Moved onto that wave at its start ([waveSkipBuff]). Saved.
  bool skipBuffDue = false;

  /// The wave being fought owes Lewati's skip buff (step 0d reads it at each spawn): [skipBuffDue], frozen at its
  /// start. Not saved (a save holds no wave in progress).
  bool waveSkipBuff = false;

  /// The Bayangan's Beban factor ([omenOverMax], [omenScale], [omenAtCap]) and the troops alive, both frozen at a wave's
  /// start ([Omens._omenWave]): a kind's effective level E is its level × [omenFactor] ([Omens.omenE]), and the ease
  /// counts the falls against [omenTroops]. Not saved.
  double omenFactor = 1;
  int omenTroops = 0;

  /// The troops alive at the wave's start ([Omens._omenWave]), for the ease's [OmenEaseCount.starters]. Not saved.
  final omenStarters = Set<Unit>.identity();

  /// The Bayangan Grudge's target ([Omens._omenTopKiller]): the last won wave's top killer, the troop type whose troops
  /// killed the most monsters in it; null with none (a wave no troop killed in, or none won yet). Set at a won wave's
  /// end, so it holds through the next wave. Saved, only while [omensOn] is on.
  String? grudgeType;

  /// Grudge's tally of the wave being fought: the monsters each troop type's troops killed ([Omens._omenKill]), only while
  /// [omensOn] is on; afresh at each wave's start. Not saved (a save holds no wave in progress).
  final _waveKills = <String, int>{};

  /// A save from before the Bayangan came in with a catch-up owed ([omensOwed]): the UI says so once (0h) and clears
  /// it. Not saved.
  bool omenCaughtUp = false;

  /// Peti Bos (draft.dart, P3): a won boss wave brings a chest of [draftCards] Pusaka cards, take one, and it replaces
  /// the boss's small-relic drop. Off in a plain Game(), so every test and probe plays as before; the board turns it
  /// on ([boardRules]). Not saved. A probe reaches it by name (probe_knobs.dart's OFFERS), so it is a member here.
  bool offers = false;

  /// How a probe takes its chests with no player ([Draft.policyPick]): 'rarity' (the highest rarity, then the type with
  /// the most troops) or 'first'; null (the player) leaves them to the chest's popup. With one, a boss chest is taken at
  /// its win, any other at the next wave's start. Not saved.
  String? draftPolicy;

  /// The troops' skill wind-ups (skill_strips.dart, decisions-log 299: the owner's "Ancang-ancang beneran"): a troop's
  /// #10, awakening and Hero skills land on their strip's blow, 0.2-0.3 s after the cast, the troop standing still
  /// meanwhile. Off in a plain Game(), so every test and probe plays as before (each lands at its cast); the board turns
  /// it on ([boardRules]). Not saved. A probe reaches it by name, so it is a member.
  bool skillWinds = false;

  /// The Towns' numbers this game reads (lib/town.dart): the ones loaded at start, or a test's or probe's own.
  TownRules townRules = loadedTownRules;

  /// The Tavern's boosts (decisions-log 266, lib/tavern.dart): every Town has its Tavern (the Tavern-off build is gone,
  /// decisions-log 296). Its dice, apart so the rest of the game rolls as it did (not saved; a probe seeds them with
  /// seed + 800). The boosts running; the visit's offers while in a Town; the visits in a row without an Epic
  /// or better and whether the run's first Tavern was rolled (saved, the last three with the Town). How a probe buys
  /// there with no player ([Tavern._tavernByPolicy]; null: the player; not saved).
  Random tavernDice = Random();
  final boosts = <RunningBoost>[];
  TavernVisit? _tavern;
  int tavernDry = 0;
  bool tavernSeen = false;
  String? tavernPolicy;

  /// The Towns' dice ([Towns._rollTown]): one draw a roll, apart so the rest of the game rolls as it did. Not saved.
  Random townDice = Random();

  /// The materials' dice ([Materials._dropMaterials]): one draw a kill whose drop has a chance (none for an always-drop),
  /// apart so the [loot] dice and the rest of the game roll as they did. Not saved; a probe seeds it with seed + 700.
  Random matDice = Random();

  /// The market's memory (decisions-log 326, market.dart): each product's pressure ([Market.marketKey] -> 1 ..
  /// [MarketRules.most]), a piece sold or a material bought, less [MarketRules.recover] at each new Town. Saved.
  final market = <String, int>{};

  /// The Towns gone into this run, the one the player is in counted ([Towns.enterTown]): the Town's number, which picks
  /// its identity ([identityOf]). Saved in `town`.
  int townCount = 0;

  /// The rolls' chance once one moved it ([Towns.townChance]), the last Town's slot once one was left or a save set it
  /// ([Towns.townLast]), and the game time the player went into the Town ([Towns.enterTown]). Saved (the first two).
  double? _townChance;
  int? _townLast;
  double _townSince = 0;

  /// The relics crafted in the Town the player is in, and the gold they took ([Craft.craft]), for [TownLeft]. Not saved.
  final _townCrafts = <Relic, int>{};
  int _townCraftSpent = 0;

  /// The slot of the Town marked (it comes before wave [townAt]), and whether the player is in it ([Towns.enterTown]).
  /// Saved.
  int? townAt;
  bool inTown = false;

  /// How a probe goes through a due Town with no player ([Towns._townByPolicy]): 'leave' (in and out at once, at the
  /// next wave's start); null (the player, or the UI) leaves it to the HUD. Not saved.
  String? townPolicy;

  /// The chests waiting to be opened, the next first ([Chest]): a won boss wave's (rolled at once), and an old save's
  /// catch-up ones ([catchUpMax], rolled when opened). Saved, with their cards.
  final chests = <Chest>[];

  /// The chests in a row whose first roll had no Epik or better ([legendPity]), how many chests this run has been
  /// given (the first is three different Epik), and the Serpihan held (each pays one reroll, [rerollChest]). Saved.
  int draftDry = 0, chestsGiven = 0, serpihan = 0;

  /// Gives [n] boss chests now, as if [n] boss waves were won (probes: one card per boss won, [pickChests]); rolled at
  /// once, the run's first one three Epik.
  void giveChests(int n) => _giveChests(n);

  /// Takes every waiting chest by [draftPolicy] now, rolling the unrolled ones (between waves; none without a policy).
  /// How many were taken.
  int pickChests() => _pickChests();

  /// A wave whose boss is the necromancer may have it as its mini boss too. On (decisions-log 165, amending 140):
  /// off, the mini boss takes a type of the pool instead ([startWave]), any type at the stronger-likelier odds, and
  /// qa-4 measured those waves harder than the pair (a werebear or an armored orc costs more than a necromancer mini
  /// boss, dead in ~52 s). A probe or test can turn it off to compare (140's rule). On, every wave rolls as on main
  /// before 140. Not saved.
  bool necroPairAllowed = true;

  /// The troops just made Heroes ([_crownHero]), for the UI's splash screen; drained like [sfx]. Not saved:
  /// a loaded game's Heroes (old ones rolling their attributes too) are not news.
  final heroMade = <Unit>[];

  /// Upgrades each troop type has been given, in order (they compound).
  final upgrades = <String, List<Item>>{};

  /// The pluses of each troop type's enhanced items (decisions-log 255; enhance.dart), per item, highest first: each
  /// is one of that item's copies in [upgrades] (the others +0), so never more than [countOf] of it. Enhance never
  /// changes the Awaken counts.
  final upgradePlus = <String, Map<Item, List<int>>>{};

  /// The Wishlist (decisions-log 282, 300; wishlist.dart): per troop type, the Smithy's items the player means to make
  /// for it, in the order put on, each with how many the type is to hold. It only marks: nothing crafts or gives by
  /// itself.
  final wishlist = <String, Map<Item, int>>{};

  /// The Wishlist's free lines (decisions-log 302; wishlist.dart): the Smithy's products wished for no type, an item or a
  /// small relic, in the order put on, each with how many the Bag is to hold.
  final wishFree = <Enum, int>{};

  /// The Wishlist's ingredient wishes (decisions-log 323; wishlist.dart's [WishPart]): a product the Smithy makes that a
  /// wished product's recipe takes, put on and taken off with the wish it is for, in the order put on (a parent before
  /// its own).
  final wishParts = <WishPart>{};

  /// What a troop of [type] fights with now: its base stats with every upgrade of its type, and its HP
  /// and MP raised by [awakenHp] / [awakenMp] of the base for every awakening level, its damage (a healer's heal)
  /// times [ascendPower] for each bought past [maxAwaken], and at Bangkit 5 its HP and damage times its Tempa's
  /// ([Tempa.tempaFactors], lib/tempa.dart); a heavy one's HP, attack and defence then times 1 +
  /// [heavyBuff] ([heavyTypes]); then its type's stat Pusaka (Dragon Heart's HP and regen, Dawn Star's power,
  /// pusaka.dart); then the oath's, for the whole army ([Pusaka._oathStats]: Oath of One's, the Few's and Alliance's
  /// HP and damage ×[_oathK], decisions-log 155; the Wall's, Blood Oath's and the Vanguard's own, decisions-log 247);
  /// then the Tavern's boosts running ([Tavern._boostStats], decisions-log 266). Its items' own numbers ([itemK]), an enhanced one's at its plus ([_itemsOn]); the spears' reach and
  /// the prisms' splash stop at their ceilings ([_ceilings]), and what the amulets add to its HP and the rings to its MP
  /// regen stays on top of the awakening's (decisions-log 251).
  Stats statsOf(String type) {
    final base = troopTypes[type]!, level = awakenLevel(type), items = _itemsOn(type, base);
    final up = 1 + awakenMp * level, held = _ceilings(base, items);
    var s = level == 0
        ? held
        : held._with(hp: (base.hp * (1 + awakenHp * level) * (held.hp / base.hp)).round(), mp: (base.mp * up).round(),
            mpRegen: base.mpRegen * up + (held.mpRegen - base.mpRegen), dmg: held.dmg * ascendFactor(level, ascendPower));
    if (tempaOf(type) > 0) {
      final (hp, dmg) = tempaFactors(type);
      s = s._with(hp: (s.hp * hp).round(), dmg: s.dmg * dmg);
    }
    if (heavyTypes.contains(type)) {
      const k = 1 + heavyBuff;
      s = s._with(hp: (s.hp * k).round(), dmg: s.dmg * k, def: s.def * k);
    }
    if (pusaka.isNotEmpty) s = _pusakaStats(type, s); // its stat Pusaka: Dragon Heart, Dawn Star (pusaka.dart)
    if (_oathOn != null) s = _oathStats(s); // the oath's, the whole army's (pusaka.dart)
    return boosts.isEmpty ? s : _boostStats(type, s); // the Tavern's boosts running (tavern.dart)
  }

  /// [base] with every item [type] holds ([upgrades], in order), each at its own number ([itemK]). An enhanced type's
  /// copies of an item take its pluses ([upgradePlus]), highest first, and the rest +0 (decisions-log 255;
  /// the items multiply and add, so which copy is which doesn't change the sum).
  Stats _itemsOn(String type, Stats base) {
    final items = upgrades[type] ?? const <Item>[], pluses = upgradePlus[type];
    if (pluses == null || pluses.isEmpty) return items.fold(base, (s, i) => s.upgraded(i, itemK(i)));
    final seen = <Item, int>{};
    return items.fold(base, (s, i) {
      final n = seen[i] = (seen[i] ?? 0) + 1, p = pluses[i];
      return s.upgraded(i, itemK(i, p != null && n <= p.length ? p[n - 1] : 0));
    });
  }

  /// The spears' and the prisms' ceilings (decisions-log 251; town.json `items.spear.reachMost` and
  /// `items.prism.splashMost`, [ItemRecipe]): however many spears a type holds, its reach stops at that many times its
  /// [base] reach and its reach cap ([Stats.reachCap], which bows, the Hero's aura and Hawk Feather stop at) at that many
  /// times [meleeMaxRange]; however many prisms, its splash at that many times its base splash. Without a spear (its cap
  /// never raised) or a prism (its splash never raised) [items] as they are.
  Stats _ceilings(Stats base, Stats items) {
    var s = items;
    if (s.reachCap > base.reachCap) {
      final most = townRules.items[Item.spear]?.reachMost ?? spearReachMost;
      s = s._with(range: min(s.range, max(base.range, base.range * most)), reachCap: min(s.reachCap, meleeMaxRange * most));
    }
    if (s.splash > base.splash) s = s._with(splash: min(s.splash, base.splash * (townRules.items[Item.prism]?.splashMost ?? prismSplashMost)));
    return s;
  }

  /// What one [item] does on a type (its effect's number, [Stats.upgraded]'s k; decisions-log 249 and 251): its town.json
  /// `items` effect ([TownRules.items], grade I's too), at +[plus] that much more ([enhancedK], town.json `enhance.per`;
  /// decisions-log 255).
  double itemK(Item item, [int plus = 0]) => enhancedK(item, townRules.items[item]!.effect, plus, townRules.enhance.per);

  /// What every item a troop type takes adds to its price: [priceRise] of its base price (rounded, at
  /// least 1 gold).
  static int priceStep(String type) => max(1, (troopTypes[type]!.cost * priceRise).round());

  /// What a troop of [type] costs now: its base price plus [priceStep] for every item its type has
  /// taken, times [awakenPrice] for every awakening level up to [maxAwaken], [ascendTroopPrice] for each past it and
  /// [tempaTroopPrice] for each Tempa level. Relics don't count.
  int priceOf(String type) => ((troopTypes[type]!.cost + (upgrades[type]?.length ?? 0) * priceStep(type)) * _awakenedPrice(type)).round();

  /// What a troop of [type] would cost with one more [item]: [priceOf] as it will be after [useItem], an
  /// awakening that item completes included; null when [type] can't take it ([canUse]), so the book
  /// previews no price for a drop that would be refused. An enhanced one ([plus], decisions-log 255) is tried on at it.
  int? priceWith(String type, Item item, {int plus = 0}) {
    if (!canUse(item, type, plus: plus)) return null;
    return _triedOn(type, item, plus, () => priceOf(type));
  }

  /// What [type]'s price is multiplied by for its awakening: [awakenPrice] per level up to [maxAwaken], then
  /// [ascendTroopPrice] per level bought ([maxAscend]), then [tempaTroopPrice] per Tempa level ([Tempa.tempaOf]).
  double _awakenedPrice(String type) {
    final level = awakenLevel(type);
    return pow(awakenPrice, min(level, maxAwaken)).toDouble() * ascendFactor(level, ascendTroopPrice) * pow(tempaTroopPrice, tempaOf(type));
  }

  /// The book's tooltip for [item]: its name, then what one does (from the numbers the rules use), who
  /// gets it, what it does to the price, how it's used and how many are in the bag. Over a troop row
  /// ([type]) it speaks of that type: how many it took and what they add up to now, and its price step. An enhanced
  /// stack's ([plus], decisions-log 255): "Royal Sword +3", what one does at it, and how many of that stack.
  (String, List<String>) itemInfo(Item item, [String? type, int plus = 0]) =>
      (itemLabel(item, plus), [...itemEffect(item, type, plus), tapLine, 'In bag: ${bagOf(item, plus)}']);

  /// What one potion or staff [item] adds to a healer's heal ([Stats.upgraded]): [potionHeal] / [staffHeal] for grade
  /// I's number, a better grade's in the share of its regen (its bonus) to grade I's (decisions-log 249); 0 for any other.
  /// At +[plus] its enhanced number's share ([itemK]).
  double healOf(Item item, [int plus = 0]) {
    final k = itemK(item, plus);
    return switch (item.slot) {
      ItemSlot.potion => k == potionRegen ? potionHeal : potionHeal * k / potionRegen,
      ItemSlot.staff => k == staffDmg ? staffHeal : staffHeal * (k - 1) / (staffDmg - 1),
      _ => 0,
    };
  }

  /// [itemInfo]'s lines up to how it's used: what one does, who gets it and what it does to the price (the
  /// store's card shows these). At +[plus] what one of that stack does (decisions-log 255).
  List<String> itemEffect(Item item, [String? type, int plus = 0]) {
    final one = itemK(item, plus), heal = healOf(item, plus);
    final heals = type != null && troopTypes[type]!.heals;
    // [k]: a multiplier, or for the potion (and the ring) the HP (MP) per second.
    String does(num k) => switch (item.slot) {
          ItemSlot.sword => '${_pct(k)} ${heals ? 'heal' : 'attack'}',
          ItemSlot.shield => '-${_num(k)} damage taken per hit',
          ItemSlot.boots => '${_pct(k)} walk speed',
          ItemSlot.bow => '${_pct(k)} range',
          ItemSlot.gloves => '${_pct(k)} wait between attacks',
          ItemSlot.potion => '+${_num(k)} HP every second',
          ItemSlot.staff => heals ? '+${_num(heal)} HP per heal' : '${_pct(k)} magic attack',
          ItemSlot.amulet => '${_pct(k)} max HP',
          ItemSlot.beads => '${_pct(k)} heal',
          ItemSlot.torch => '${_pct(k)} damage to the undead',
          ItemSlot.spear => '${_pct(k)} melee reach',
          ItemSlot.prism => '${_pct(k)} splash area',
          ItemSlot.helm => '${_pct(k)} damage taken',
          ItemSlot.ring => '+${k.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '')} ${Words.mp} every second',
        };
    final lines = [
      does(one),
      // A potion also strengthens a healer's heals; so does the staff, which only the casters take.
      if (item.slot == ItemSlot.potion && (type == null || heals)) '${type == null ? 'Healers: ' : ''}+${_num(heal)} HP per heal',
      if (item.slot == ItemSlot.staff && type == null) ...[
        'Healers: +${_num(heal)} HP per heal',
        'Only for ${[for (final t in troopTypes.keys) if (powerItem(t) == Item.staff) troopTypeNames[t]].join(', ')}',
      ],
      'For a whole type, up to a cap',
    ];
    if (type == null) {
      lines.add('Cost: troop price ${_pct(1 + priceRise)}');
    } else {
      // What the row's cell shows ([fieldStats]: the Hero's aura in, then a line says so), against the base.
      final n = heldOf(type, item), cap = capOf(type, item), now = fieldStats(type).statOf(item);
      final base = troopTypes[type]!.statOf(item);
      final sum = switch (item.slot) {
        ItemSlot.potion => '+${_num(now)} HP/s${heals ? ', +${_num(n * heal)} heal' : ''}',
        ItemSlot.shield => '-${_num(now)} per hit',
        ItemSlot.staff when heals => '+${_num(n * heal)} heal',
        _ when base == 0 => '+${_num(now)}', // a stat none of the seven raises from 0 (a forge item's, decisions-log 245)
        _ => _pct(now / base),
      };
      lines.addAll([
        if (cap == 0 && n == 0)
          // A grade whose slots open with an Awaken (decisions-log 249) says which.
          whyNot(item, type) == Refusal.awakenFirst ? gradeOpensAt(item) : "This type can't take it"
        else
          'Now: $n/$cap on this type${n == 0 ? '' : ', $sum'}',
        if (n > 0) ?itemAuraLine,
        'Cost: troop price +${(priceStep(type) * _awakenedPrice(type)).round()}',
      ]);
    }
    return lines;
  }

  /// The book's tooltip for [relic]: its name, what it does, its tier and who it suits ([relicTierLine], [relicBestLine]:
  /// relics.dart), who holds it, how it's used, and how many
  /// are in the bag and held by living troops; a Pusaka's: what it does at its stars, what that sums to over its type
  /// now ([Pusaka.pusakaTotals], critique M6), that it goes on a whole type (an oath: for the whole run), and where it
  /// is ([pusakaWhere]); a carved one's Carve steps after what it does ([ukirGist], decisions-log 196).
  (String, List<String>) relicInfo(Relic relic) => (relicNames[relic]!, [
        ...relicEffect(relic),
        if (pusaka[relic] case OwnedPusaka(:final ukir) when ukir > 0) ukirGist(ukir), // its Carve (pusaka.dart)
        if (relic.pusaka) ...[...pusakaTotals(relic), relic.oath ? oathLine : pusakaLine, pusakaWhere(relic)] else ...[
          relicTierLine(relic), ?relicBestLine(relic), // decisions-log 227
          relicSlotsLine,
          tapLine,
          'In bag: ${relicBag[relic] ?? 0}, in use: ${relicsHeld(relic)}',
        ],
      ]);

  /// Where Pusaka [relic] is, in the book's words: "On: Templar ★1" (with "(asleep)" while none of the type lives),
  /// "In Vault ★2", or "Not owned yet"; an oath taken "On: all troops ★1", or while Oath of One or the Few waits
  /// [oathWaiting], [fewWaiting].
  String pusakaWhere(Relic relic) => switch (pusaka[relic]) {
        null => 'Not owned yet',
        _ when relic == oath && oathWaits => oathWaitingOf(relic),
        OwnedPusaka(:final stars) when relic.oath => 'On: all troops ★$stars',
        OwnedPusaka(type: final t?, :final stars) => 'On: ${troopTypeNames[t] ?? t} ★$stars${pusakaAsleep(relic) ? ' (asleep)' : ''}',
        OwnedPusaka(:final stars) => 'In ${Words.vault} ★$stars',
      };

  /// How many living troops hold [relic] (a Hero's two slots are two kinds, so one each).
  int relicsHeld(Relic relic) => troops.where((u) => u.alive && u.holds(relic)).length;

  /// What [relic] does, in the book's words, from the numbers the rules use ([relicInfo]'s first lines, and
  /// the store's card); a Pusaka's at its stars and Ukir steps (★1 when not owned), or at [stars] (the chest's card: the
  /// star it would reach) and [ukir] (0 when not given).
  List<String> relicEffect(Relic relic, {int? stars, int? ukir}) {
    String share(double s) => '${(s * 100).round()}%';
    final at = stars ?? pusaka[relic]?.stars ?? 1, steps = ukir ?? (stars == null ? pusaka[relic]?.ukir ?? 0 : 0);
    return switch (relic) {
      Relic.fang => ['Heals ${share(fangShare)} of damage dealt'],
      Relic.thorns => ['Attackers take ${share(thornsShare)} back'],
      Relic.fury => ['x$furyHit damage every ${_nth(furyEvery)} hit'],
      Relic.guard => ['${_pct(1 - guardCut)} damage taken'],
      Relic(pusaka: false) => _newRelicEffect(relic), // the Smithy's seven (relics.dart)
      // The oaths' bespoke rules (pusaka.dart, decisions-log 155): ★1 only.
      Relic.oathOfOne => ['Oath: only ${oathOneK.types} types, no type cap', 'All troops: ${_pct(oathOneK.k)} HP and attack'],
      Relic.alliance => ['Oath: up to ${allianceK.most} types count', 'Each type alive: +${share(allianceK.perType)} HP and attack'],
      // Batch G-4's (decisions-log 247): the oath's rule first, then what it gives and what it costs.
      Relic.fewOath => ['Oath: up to ${fewOathK.army} troops (not $armyMaxBoard)', 'All troops: ${_pct(fewOathK.k)} HP and attack'],
      Relic.wallOath => ['Oath: all troops ${_pct(wallOathK.hp)} HP', '${_pct(wallOathK.dmg)} attack and heal'],
      Relic.bloodOath => ['Oath: all troops ${_pct(bloodOathK.dmg)} attack', 'Heals on troops ${_pct(bloodOathK.healIn)}'],
      Relic.vanguardOath => ['Oath: up-close troops ${_pct(vanguardOathK.melee)} HP and attack', 'Others ${_pct(vanguardOathK.back)} attack and heal'],
      Relic.kingsOath => [
          'Oath: a Hero gives all troops +${share(kingsOathK.aura - 1)} (not ${share(auraBoost - 1)})',
          "Heroes' own stats x${_x(kingsOathK.heroBoost)} (not x${_x(heroBoost)})",
        ],
      Relic.spellOath => ['Oath: skills come back ${share(1 - spellOathK.cd)} sooner', 'Normal hits ${_pct(spellOathK.blow)} damage'],
      _ => fxLines(relic, at, ukir: steps), // every other Pusaka: its row's templates (pusaka_catalog.dart)
    };
  }

  /// The book's tooltip for a troop row's HP cell: what it is as the row shows it ([fieldStats]) against the base, that
  /// only awakening raises it, and the type's Pusaka that raises it (Dragon Heart, [fxRaisesHp]) and the Hero's aura
  /// ([auraLine]) when they do.
  (String, List<String>) hpInfo(String type) => ('HP', [
        'Max HP ${fieldStats(type).hp} (base ${troopTypes[type]!.hp})',
        'Only ${Words.awaken} raises it',
        'Each level: +${(awakenHp * 100).round()}% of base',
        if (pusakaOf(type) case final r? when fxRaisesHp(r))
          '${relicNames[r]} ★${pusaka[r]!.stars}: x${_x(pusakaAt(r, pusaka[r]!.stars, ukir: pusaka[r]!.ukir))}',
        ?auraLine,
      ]);

  /// The book's tooltip for a troop row's MP cell: what it is as the row shows it ([fieldStats]), that only awakening
  /// raises it, the Hero's aura ([auraLine]) while it does, and what spends it: a healer's heals ([healMp],
  /// decisions-log 297), the #10 skill and, once the type has awakened, its awakening skill, each with its cost.
  (String, List<String>) mpInfo(String type) {
    final s = fieldStats(type), skill = troopSkills[type], awaken = awakenSkillOf(type), level = awakenLevel(type);
    return ('MP', [
      'Max MP ${s.mp}, regen ${_num(s.mpRegen)}/s',
      'Only ${Words.awaken} raises it',
      'Each level: +${(awakenMp * 100).round()}% of base',
      ?auraLine,
      if (s.heals) 'Each heal: ${_num(healMp)} MP',
      if (skill != null) 'For ${skill.name} (${_num(skillPrice(type, skill.cost))} MP)', // as Spell Tax has it (omen.dart)
      if (awaken != null && level > 0) 'and ${awaken.titleAt(level)} (${_num(skillPrice(type, awaken.costAt(level)))} MP)',
    ]);
  }

  /// The book's tooltip for a troop row's awakening stars: the level in words; the awakening skill of the level
  /// (at level 0 the one Bangkit 1 opens), what it does, its MP and cooldown, and the next level's numbers
  /// ([awakenLines]); then what the next awakening needs, one line per recipe kind with its icon and have/need
  /// ([awakenProgress]); from Bangkit 3 that the next is bought on the Army page (its detail's tag, decisions-log 230;
  /// [maxAscend]); "Max" once there is none, then its Tempa (lib/tempa.dart): what it has, and that the next is bought
  /// there too.
  (String, List<(Item?, String)>) awakenInfo(String type) {
    final buyInShop = 'buy on the ${Words.army} page';
    final level = awakenLevel(type);
    final skill = [for (final l in awakenLines(type, level, price: (base) => skillPrice(type, base), cd: skillCd)) (null, l)];
    if (level >= awakenTop) {
      final n = tempaOf(type);
      final (hp, dmg) = tempaFactors(type);
      return (awakenName(level), [
        ...skill,
        (null, "Max: can't ${Words.awaken} more"),
        if (n > 0) (null, '${tempaName(n)}: HP ${_times(hp)}, ${troopTypes[type]!.heals ? 'heal' : 'attack'} ${_times(dmg)}'),
        if (n < tempaMax) (null, '${tempaName(n + 1)}: $buyInShop'),
      ]);
    }
    if (level >= maxAwaken) return (awakenName(level), [...skill, (null, '${awakenName(level + 1)}: $buyInShop')]);
    return (awakenName(level), [
      ...skill,
      (null, '${awakenName(level + 1)} needs:'),
      for (final MapEntry(key: item, value: (have, need)) in awakenProgress(type).entries) (item, '${itemNames[item]} $have/$need'),
    ]);
  }

  /// The items [type] needs to awaken once ([awakenRecipe]); empty for anything that isn't a troop.
  Map<Item, int> recipeOf(String type) => awakenRecipe[type] ?? const {};

  /// The kinds [type]'s Awaken counts by grade and how many of each a level takes (decisions-log 249; forge-design §11:
  /// Awaken L takes [type]'s grade-L set, [gradeSet], and a type holds per kind and grade, [capOf]): its
  /// [awakenRecipe]'s, then its own new kind ([forgeAwakenKinds]). Empty for anything that isn't a troop.
  Map<ItemSlot, int> kindRecipe(String type) => {
        for (final MapEntry(key: item, value: n) in recipeOf(type).entries) item.slot: n,
        ...?forgeAwakenKinds[type],
      };

  /// What Awaken [level] (1 to [maxAwaken]) takes by grade: each kind of [type]'s [kindRecipe] in grade
  /// [level] ([itemOf]), its count at the level's share (town.json `awaken.share`, its last for a level past it;
  /// [gradeCount]): the knight's Awaken 3 takes Royal Sword 2, Royal Shield 2, Wind Boots 2, Royal Gloves 2, Gold Amulet 1.
  Map<Item, int> gradeSet(String type, int level) {
    final share = townRules.awaken.share, k = share[min(level, share.length) - 1];
    return {for (final MapEntry(key: slot, value: n) in kindRecipe(type).entries) itemOf(slot, level): gradeCount(n, k)};
  }

  /// The items [type] holds once it has awakened to [level] (0 to [maxAwaken]): every grade set up to it ([gradeSet])
  /// past the level it kept ([keptLevel], decisions-log 272).
  Map<Item, int> awakenNeeds(String type, int level) => {for (var l = keptLevel(type) + 1; l <= level; l++) ...gradeSet(type, l)};

  /// What [type] still lacks for its next Awaken from items ([awakenNeeds] of the level after [itemLevel]): each item it
  /// is short of and how many; none at [maxAwaken].
  Map<Item, int> awakenShort(String type) {
    final level = itemLevel(type);
    if (level >= maxAwaken) return const {};
    return {
      for (final MapEntry(key: item, value: n) in awakenNeeds(type, level + 1).entries)
        if (n > countOf(type, item)) item: n - countOf(type, item),
    };
  }

  /// How many [item]s troop [type] has taken.
  int countOf(String type, Item item) => (upgrades[type] ?? const <Item>[]).where((i) => i == item).length;

  /// How many of [item] count against its cap on [type] ([capOf]): a Cap's or a Ring's whole kind, any grade
  /// ([outsideAwaken]); else [countOf].
  int heldOf(String type, Item item) => outsideAwaken.contains(item.slot)
      ? (upgrades[type] ?? const <Item>[]).where((i) => i.slot == item.slot).length
      : countOf(type, item);

  /// How many times [type] has awakened: the grade sets its items hold ([itemLevel]), and at Bangkit 3 the levels bought
  /// past it ([ascended], up to [awakenTop]).
  int awakenLevel(String type) {
    final level = itemLevel(type);
    return level >= maxAwaken ? level + (ascended[type] ?? 0) : level;
  }

  /// How many levels past [maxAwaken] each troop type bought with gold (Bangkit 4 and 5, [Ascend.ascend]); none
  /// until one is. Saved; saves from before #92 part 2 have none.
  final ascended = <String, int>{};

  /// The Awaken level each troop type kept from a save written before Awaken by grade (decisions-log 272): such a save's
  /// items were taken by the old rule (the same recipe once more for each level), and no grade set holds them (none has
  /// the forge's new kinds), so at its load each type keeps the level its items gave ([oldItemLevel]) and by grade counts
  /// on from it ([itemLevel]): the next Awaken takes the next grade's set, and Bangkit and Tempa bought at Awaken 3 stay.
  /// Saved, empty included, so a save of the by-grade game is never read by the old rule again; a save without the key
  /// gets it from its items, and a new game has none.
  final awakenKept = <String, int>{};

  /// How many Tempa levels each troop type bought with gold past Bangkit 5 ([Tempa.temper], lib/tempa.dart); none until
  /// one is. They count only at Bangkit 5 ([Tempa.tempaOf]); Lepas jenis keeps them (no refund). Saved; saves from before
  /// decisions-log 163 have none.
  final tempa = <String, int>{};

  /// [awakenLevel] from the items alone: the grade sets [type] holds in a row from grade I ([gradeSet], decisions-log
  /// 249), on from the level it kept ([keptLevel]). Items past a cap (from saves made before the caps) stay and count.
  /// Kept per type while its list of items is the same list with the same length and the level kept the same
  /// ([_levels]): [priceWith] and [assignPreview] try an item on and take it back, a test may put a new list in, and each
  /// of those reads the level anew.
  int itemLevel(String type) {
    final items = upgrades[type], n = items?.length ?? 0, kept = keptLevel(type);
    if (_levels[type] case (final was, final len, final k, final level) when identical(was, items) && len == n && k == kept) {
      return level;
    }
    var level = 0;
    if (recipeOf(type).isNotEmpty) {
      bool holds(Map<Item, int> set) => set.entries.every((e) => countOf(type, e.key) >= e.value);
      level = kept; // a level kept from a save before the grades (decisions-log 272) counts on from there
      while (level < maxAwaken && holds(gradeSet(type, level + 1))) {
        level++;
      }
    }
    _levels[type] = (items, n, kept, level);
    return level;
  }

  /// [type]'s level by the rule before Awaken by grade: the most recipes (up to [maxAwaken]) its items hold in full, any
  /// item counting as its own; 0 for anything that isn't a troop. What a save from before the grades keeps
  /// ([awakenKept]).
  int oldItemLevel(String type) {
    final recipe = recipeOf(type);
    return recipe.isEmpty ? 0 : recipe.entries.map((e) => countOf(type, e.key) ~/ e.value).reduce(min).clamp(0, maxAwaken);
  }

  /// The Awaken level [type] kept from a save before the grades ([awakenKept]), at most [maxAwaken]; 0 without one.
  int keptLevel(String type) => min(awakenKept[type] ?? 0, maxAwaken);

  /// [awakenLevel]'s memo: per type, the list of items it read, its length then, the level kept ([keptLevel]) and the
  /// level. Every tick asks it for every troop (the awakening skills, the tinted hits), so it isn't worked out again each
  /// time.
  final _levels = <String, (List<Item>?, int, int, int)>{};

  /// How far [type] is toward its next awakening, per item of the next grade set ([gradeSet]; at the top, grade III's,
  /// full): (have, need), have at most need.
  Map<Item, (int, int)> awakenProgress(String type) {
    final level = awakenLevel(type);
    return {
      for (final MapEntry(key: item, value: need) in gradeSet(type, min(level + 1, maxAwaken)).entries)
        item: (level >= maxAwaken ? need : min(countOf(type, item), need), need),
    };
  }

  /// The most [item]s [type] can hold before its next awakening (decisions-log 249): its grade's count of [gradeSet] once
  /// the grade is open (at Awaken L, grades up to L + 1), else 0 (0 for kinds not in its sets); a Cap or a Ring
  /// ([outsideAwaken]) one of the kind, any grade ([heldOf]), per level and one more (1 to 4).
  int capOf(String type, Item item) {
    final level = min(awakenLevel(type), maxAwaken);
    if (outsideAwaken.contains(item.slot)) return recipeOf(type).isEmpty ? 0 : level + 1;
    if (!kindRecipe(type).containsKey(item.slot) || item.grade > level + 1) return 0;
    return gradeSet(type, item.grade)[item]!;
  }

  /// The item one more [item] at +[plus] on [type] would send back to the Bag, its lowest-plus copy ([Enhance._lowPlus])
  /// going at its own plus: a Cap or a Ring given at its kind's cap ([capOf]) swaps out the type's lowest one by
  /// grade, then plus, when [item]'s grade and [plus] are above it (decisions-log 249, 255); any other item at its cap
  /// swaps out its own lowest-plus copy when [plus] is above it (Enhance's swap, decisions-log 255); else null.
  Item? swapOut(String type, Item item, [int plus = 0]) {
    final cap = capOf(type, item);
    if (cap == 0 || heldOf(type, item) < cap) return null;
    if (outsideAwaken.contains(item.slot)) {
      final held = {for (final i in upgrades[type] ?? const <Item>[]) if (i.slot == item.slot) i};
      if (held.isEmpty) return null;
      int rank(Item i, int p) => i.grade * 1000 + p; // grade first, then plus (a plus never reaches 1000)
      final low = held.reduce((a, b) => rank(b, _lowPlus(type, b)) < rank(a, _lowPlus(type, a)) ? b : a);
      return rank(low, _lowPlus(type, low)) < rank(item, plus) ? low : null;
    }
    return plus > 0 && countOf(type, item) > 0 && _lowPlus(type, item) < plus ? item : null;
  }

  /// [type]'s items with one more [item] at +[plus]: added, less the one it swaps out ([swapOut]), and their pluses
  /// ([upgradePlus]): the one out takes its lowest, the new one its [plus]. New lists, for [useItem] and [_triedOn].
  (List<Item>, Map<Item, List<int>>) _given(String type, Item item, [int plus = 0]) {
    final items = [...?upgrades[type]];
    final pluses = {for (final MapEntry(:key, :value) in (upgradePlus[type] ?? const <Item, List<int>>{}).entries) key: [...value]};
    if (swapOut(type, item, plus) case final out?) {
      items.remove(out);
      if (_lowPlus(type, out) > 0) {
        pluses[out]!.removeLast(); // its lowest
        if (pluses[out]!.isEmpty) pluses.remove(out);
      }
    }
    if (plus > 0) (pluses[item] ??= [])..add(plus)..sort((a, b) => b - a);
    return (items..add(item), pluses);
  }

  /// [type]'s pluses set to [pluses] (none: no entry).
  void _setPluses(String type, Map<Item, List<int>> pluses) {
    if (pluses.isEmpty) {
      upgradePlus.remove(type);
    } else {
      upgradePlus[type] = pluses;
    }
  }

  /// What [read] says with one [item] at +[plus] tried on [type] ([_given]), which is then taken back: [priceWith]'s and
  /// [assignPreview]'s.
  T _triedOn<T>(String type, Item item, int plus, T Function() read) {
    final (had, hadPlus) = (upgrades[type], upgradePlus[type]);
    final (items, pluses) = _given(type, item, plus);
    upgrades[type] = items;
    _setPluses(type, pluses);
    final v = read();
    if (had == null) {
      upgrades.remove(type);
    } else {
      upgrades[type] = had;
    }
    if (hadPlus == null) {
      upgradePlus.remove(type);
    } else {
      upgradePlus[type] = hadPlus;
    }
    return v;
  }

  /// Whether one more [item] may go on [type]: under its cap, and a bow not on a melee fighter already
  /// at its reach cap ([Stats.reachCap]: [meleeMaxRange] unless spears raised it).
  bool canUse(Item item, String type, {int plus = 0}) => whyNot(item, type, plus: plus) == null;

  /// Why one more [item] can't go on [type], or null when it can ([canUse]). By grade (decisions-log 249): a grade not
  /// open yet is [Refusal.awakenFirst], a full grade [Refusal.maxed] (its cap never rises; a Cap's or a Ring's rises with
  /// each awakening, [Refusal.awakenFirst] until the last), and a Cap or a Ring at its cap goes on when it swaps out a
  /// lower grade ([swapOut]). An enhanced one ([plus], decisions-log 255) at its cap
  /// goes on when it swaps out a lower plus.
  Refusal? whyNot(Item item, String type, {int plus = 0}) {
    final cap = capOf(type, item);
    if (cap == 0) return kindRecipe(type).containsKey(item.slot) ? Refusal.awakenFirst : Refusal.notInRecipe;
    if (item == Item.bow && statsOf(type).melee && statsOf(type).range >= statsOf(type).reachCap) return Refusal.reach;
    if (heldOf(type, item) < cap || swapOut(type, item, plus) != null) return null;
    final rises = outsideAwaken.contains(item.slot) && awakenLevel(type) < maxAwaken;
    return rises ? Refusal.awakenFirst : Refusal.maxed;
  }

  /// Why one more [item] can't go on [type], as the player reads it ([refusalNames]): a grade whose slots open with an
  /// Awaken (decisions-log 249) says which, its tooltip's line ([gradeOpensAt]); else [refusalNames]'s.
  String itemRefusal(Item item, String type, Refusal refusal) =>
      refusal == Refusal.awakenFirst && capOf(type, item) == 0 ? gradeOpensAt(item) : refusalNames[refusal]!;

  /// Every troop type for one more [item], in the troop box's order: (type, taken, cap, why not or null).
  /// The bag's item picker lists these.
  List<(String, int, int, Refusal?)> typesFor(Item item) =>
      [for (final type in troopTypes.keys) (type, heldOf(type, item), capOf(type, item), whyNot(item, type))];

  /// Uses one [item] from the inventory on troop [type]: an upgrade for every troop of it, now and
  /// placed later (a potion is one too: more HP back every second). Past its cap ([canUse]) it stays in
  /// the bag. The item that completes a recipe awakens the type: every troop of it bursts in the new
  /// level's colour. A Cap or a Ring that swaps out a lower grade ([swapOut]) sends that one back to the Bag. An enhanced
  /// one ([plus], decisions-log 255) comes from its own stack ([Enhance.bagOf]) and keeps its plus on the type; one it
  /// swaps out goes back at its own.
  bool useItem(Item item, String type, {int plus = 0}) {
    final mine = [for (final u in troops) if (u.alive && u.type == type) u];
    if (bagOf(item, plus) == 0 || !canUse(item, type, plus: plus) || over) {
      sfx.add(Sfx.error);
      return false;
    }
    final was = awakenLevel(type);
    _toBagAt(item, plus, -1);
    if (swapOut(type, item, plus) case final out?) {
      final outPlus = _lowPlus(type, out);
      final (items, pluses) = _given(type, item, plus);
      upgrades[type] = items; // a new list, so the level's memo reads it anew
      _setPluses(type, pluses);
      _toBagAt(out, outPlus, 1);
    } else if (plus > 0) {
      final (items, pluses) = _given(type, item, plus);
      upgrades[type] = items;
      _setPluses(type, pluses);
    } else {
      (upgrades[type] ??= []).add(item);
    }
    _emit(ItemUsed(wave, t, item: item, type: type, plus: plus));
    final level = awakenLevel(type);
    _wishGiven(type, item, awakened: level > was); // a done wish drops off with its Awaken (wishlist.dart)
    for (final u in mine) {
      _refit(u);
      impacts.add((u.pos, level > was ? awakeFx('upgrade', level) : (item.slot == ItemSlot.potion ? 'heal' : 'upgrade')));
    }
    sfx.add(Sfx.magic);
    if (level > was) {
      sfx.add(Sfx.clear);
      _emit(Awakened(wave, t, type: type, level: level));
      _awakened(type); // its awakening skill pops over its troops and comes ready 0–3 s apart (awaken_skills.dart)
    }
    return true;
  }

  /// What one more [loot] on [to] would do, for the book's list (#87) and the field's popup (#86): an [Item] on
  /// a troop type (a String), a [Relic] on one troop (a [Unit]). [AssignPreview.why] is null exactly when
  /// [useItem] / [useRelic] would give it. The rest is tried on (and taken back) only where the target itself
  /// can take it (the item within its cap, the troop alive with a slot free for a kind it doesn't hold), whatever
  /// the bag or the game's end say; otherwise every "after" is its "now" and no stat changes. The stats are the
  /// field's: an item's the type's [fieldStats] (the Pasukan row's numbers), a relic's the troop's own. An enhanced item
  /// ([plus], decisions-log 255) from its own stack, tried on at it.
  AssignPreview assignPreview(Enum loot, Object to, {int plus = 0}) {
    List<(StatKind, num, num)> changes(Stats a, Stats b) =>
        [for (final k in StatKind.values) if (k.of(a) != k.of(b)) (k, k.of(a), k.of(b))];
    final String? why;
    if (loot case final Relic relic) {
      final u = to as Unit, refusal = relicRefusal(relic, u);
      why = over
          ? assignRefusals.over
          : !relic.pusaka && (relicBag[relic] ?? 0) == 0
              ? assignRefusals.empty
              : refusal;
      var stats = const <(StatKind, num, num)>[];
      if (refusal == null) {
        final now = _statsFor(u);
        u.relics.add(relic); // tried on, then taken back
        stats = changes(now, _statsFor(u));
        u.relics.removeLast();
      }
      return (why: why, stats: stats, price: null, awaken: null, count: null, step: null);
    }
    final item = loot as Item, type = to as String, refusal = whyNot(item, type, plus: plus);
    why = over
        ? assignRefusals.over
        : bagOf(item, plus) == 0
            ? assignRefusals.empty
            : refusal == null
                ? null
                : itemRefusal(item, type, refusal); // the bag's picker, the drop popup (decisions-log 252)
    final level = awakenLevel(type);
    // Toward the awakening after [level]: the next grade set's items held, at most each one's count (decisions-log 249).
    (int, int)? progress() {
      if (level >= maxAwaken) return null;
      var (have, need) = (0, 0);
      for (final MapEntry(key: item, value: n) in gradeSet(type, level + 1).entries) {
        have += min(countOf(type, item), n);
        need += n;
      }
      return (have, need);
    }

    final (stats, price, count, step) = (fieldStats(type), priceOf(type), (heldOf(type, item), capOf(type, item)), progress());
    if (refusal != null) {
      return (why: why, stats: const [], price: (price, price), awaken: (level, level), count: (count, count), step: step == null ? null : (step, step));
    }
    final after = _triedOn(type, item, plus, () =>
        (stats: fieldStats(type), price: priceOf(type), level: awakenLevel(type), count: (heldOf(type, item), capOf(type, item)), step: progress()));
    return (
      why: why,
      stats: changes(stats, after.stats),
      price: (price, after.price),
      awaken: (level, after.level),
      count: (count, after.count),
      step: step == null ? null : (step, after.step!),
    );
  }

  /// Burst [fx] as troop [u] shows it: in its type's awakening colour ([awakeFx]); monsters' plain.
  String _fxOf(Unit u, String fx) => u.side == Side.troop ? awakeFx(fx, awakenLevel(u.type)) : fx;

  /// Whether a Hero is alive: then every other troop has the Hero's aura ([auraBoost]).
  bool get heroAlive => troops.any((u) => u.alive && u.hero);

  /// Whether a living troop of [type] is a Hero (the UI marks the type).
  bool hasHero(String type) => troops.any((u) => u.alive && u.hero && u.type == type);

  /// How many Heroes are alive, against [heroMax].
  int get heroCount => troops.where((u) => u.alive && u.hero).length;

  /// What troop [u] fights with: its type's stats as they are now ([statsOf]), a Hero's rolled attributes
  /// times [heroBoost], and the rest times [auraBoost] while a Hero (another one, for a Hero) lives; under Oath of Kings
  /// its own two ([Pusaka.heroBoostNow], [Pusaka.auraNow]).
  Stats _statsFor(Unit u) {
    final aura = troops.any((o) => o != u && o.alive && o.hero) ? auraNow : 1.0;
    final s = u.hero ? statsOf(u.type).heroic(u.heroStats.toSet(), heroBoostNow, aura) : statsOf(u.type).boosted(aura);
    return u.effects.isEmpty ? s : _withEffects(u, s); // a Hero skill's stat effects ([Status.stat])
  }

  /// Rolls Hero [u]'s [heroStatCount] different attributes from its pool ([heroPoolOf]) with the [heroes]
  /// dice.
  void _rollHeroStats(Unit u) {
    final pool = heroPoolOf(u.type);
    u.heroStats = [for (var i = 0; i < heroStatCount && pool.isNotEmpty; i++) pool.removeAt(heroes.nextInt(pool.length))];
  }

  /// Rolls again, with the [heroes] dice, each of Hero [u]'s attributes that its pool no longer has (attack
  /// rate since #69), from what is left of the pool: its other picks stay, in their place, and none comes
  /// twice. A Hero with nothing out of its pool draws no dice.
  void _rerollOutOfPool(Unit u) {
    final own = heroPoolOf(u.type), left = [...own]..removeWhere(u.heroStats.contains);
    u.heroStats = [for (final h in u.heroStats) own.contains(h) || left.isEmpty ? h : left.removeAt(heroes.nextInt(left.length))];
  }

  /// Gives [u] its stats as they are now ([_statsFor]). HP and MP it gains (awakening, becoming a Hero, the
  /// aura) come with them; what it loses (the aura ending) only caps them, so it never kills.
  void _refit(Unit u) {
    final (before, mpBefore) = (u.maxHp, u.stats.mp);
    u.stats = _statsFor(u);
    u.maxHp = u.stats.hp;
    u.hp = min(u.hp + max(0, u.maxHp - before), u.maxHp.toDouble());
    u.mp = min(u.mp + max(0, u.stats.mp - mpBefore), u.stats.mp.toDouble());
  }

  /// [_refit] for every living troop: a Hero came or fell, so the aura may have changed (or the oath's multiplier,
  /// which it takes as it is now, [Pusaka._oathWatch]).
  void _refitTroops() {
    _oathOn = oath;
    _oathK = _oathKNow;
    for (final u in troops) {
      if (u.alive) _refit(u);
    }
  }

  /// One living troop that isn't a Hero yet becomes one, picked with the [heroes] dice ([heroEvery]). It
  /// bursts like an upgrade with the win jingle, and the UI announces it ([heroMade]).
  void _crownHero() {
    final pick = [for (final u in troops) if (u.alive && !u.hero) u];
    if (pick.isEmpty) return;
    final h = pick[heroes.nextInt(pick.length)]..hero = true;
    _rollHeroStats(h);
    _rollHeroSkill(h); // then its own skill, with the same dice
    _refitTroops(); // its own x3, and everyone else's aura
    heroMade.add(h);
    _emit(HeroMade(wave, t, name: h.name, type: h.type, stats: h.heroStats, skill: h.heroSkill));
    impacts.add((h.pos, 'upgrade'));
    sfx.add(Sfx.clear);
  }

  /// Every game starts with one free healer at the back of the middle lane.
  Game([Random? rng, Random? names])
      : rng = rng ?? Random(),
        names = names ?? Random() {
    _addTroop(freeHealer, 0, rows ~/ 2);
    notes.add(pusakaNote); // nothing to tell a new game
  }

  static const freeHealer = 'priest';

  /// The save's format, written first as `v` ([toJson]; lib/save.dart reads it): 2 since the Towns are on (decisions-log
  /// 237), 3 since the forge's items and relics (decisions-log 245: names a version-2 build doesn't know). A save file
  /// without `v` at least [saveLoadsFrom] is from before the Towns, and is no save: the launch deletes it ([loadGame],
  /// [launchSave]; the owner, 2026-10-04: "save lama di hapus saja, toh baru developer yang pakai"). No refund, no
  /// migration, no note. [Game.fromJson] reads any version (the tests' and probes' fixtures).
  static const saveVersion = 3;

  /// The oldest format the launch loads ([loadGame]): a version-2 save loads forward into this build, nothing discarded
  /// (decisions-log 245): its items and relics keep their names, and a name this build doesn't know is skipped.
  static const saveLoadsFrom = 2;

  /// Everything needed to pick up between waves. Troops still waiting for the after-wave heal are saved healed. Its
  /// format first ([saveVersion]).
  Map<String, Object> toJson() => {
        'v': saveVersion,
        'gold': gold,
        'lives': lives,
        'wave': wave,
        'tideStart': tideStart,
        'score': score,
        'kills': kills,
        'baseX': baseX,
        'capacity': capacity,
        'inventory': {for (final e in inventory.entries) e.key.name: e.value},
        'upgrades': {for (final e in upgrades.entries) e.key: [for (final i in e.value) i.name]},
        'relicBag': {for (final e in relicBag.entries) e.key.name: e.value},
        if (materials.isNotEmpty) 'materials': {for (final e in materials.entries) e.key.name: e.value}, // the Towns' (town.dart)
        if (matsSeen.isNotEmpty) 'matsSeen': [for (final m in matsSeen) m.name], // the forge's (town.dart)
        if (storeBought.isNotEmpty) 'storeBought': {for (final e in storeBought.entries) e.key.name: e.value},
        if (pusaka.isNotEmpty) 'pusaka': {for (final e in pusaka.entries) e.key.name: e.value.toJson()},
        if (notes.isNotEmpty) 'notes': [...notes], // the one-time messages shown
        'asahAt': ?asahAt, // the last Asah's wave
        'lostWave': ?lostWave, // the furthest wave the army was wiped in, played again (wipe.dart)
        if (bestWon > wave) 'bestWon': bestWon, // the highest wave won, past the wave after a trip back (wipe.dart)
        if (weakened > 0) 'weakened': weakened, // the monsters weakened after a wipe until the next new Town (wipe.dart)
        if (wipeAsk) 'wipeAsk': true, // Try again or Give up, still to be chosen (wipe.dart)
        if (ukir.fed) 'ukir': ukir.toJson(), // the run's Ukir, once fed (pusaka.dart)
        if (legendsFound.isNotEmpty) 'legendsFound': [for (final r in legendsFound) r.name], // never offered again (pusaka.dart)
        if (toReplace.isNotEmpty) 'toReplace': [for (final f in toReplace) {'type': f.type, 'x': f.post.x, 'y': f.post.y}],
        if (autoReplace) 'autoReplace': true, // Auto, the spawn bar's (decisions-log 283)
        if (ascended.isNotEmpty) 'ascended': ascended,
        'awakenKept': awakenKept, // empty too: this save's items are by grade (decisions-log 272)
        if (tempa.isNotEmpty) 'tempa': tempa,
        if (fallenHeroes.isNotEmpty) 'fallenHeroes': [for (final f in fallenHeroes) f.toJson()],
        // The boss chests waiting (draft.dart), always written: a save without the key is from before them and gets its
        // catch-up chests.
        'chests': [for (final c in chests) c.toJson()],
        if (draftDry > 0) 'draftDry': draftDry,
        if (chestsGiven > 0) 'chestsGiven': chestsGiven,
        if (serpihan > 0) 'serpihan': serpihan,
        ..._omenJson, // the Bayangan (omen.dart): no key while they are off
        ..._townJson, // the Towns (town.dart)
        ..._marketJson, // the market's memory (market.dart): no key while it is fresh
        ..._boostsJson, // the Tavern's boosts running (tavern.dart): no key while none runs
        ..._enhanceJson, // Enhance's pluses (enhance.dart): no key with nothing enhanced
        ..._wishJson, // the Wishlist (wishlist.dart): no key with no wish
        'troops': [
          for (final u in troops.where((u) => u.alive))
            {
              'type': u.type,
              'x': u.post.x,
              'y': u.post.y,
              'hp': healQueue.contains(u) ? u.maxHp : u.hp,
              'name': u.name,
              if (u.relics.isNotEmpty) 'relics': [for (final r in u.relics) r.name],
              if (u.hero) 'hero': true,
              if (u.hero) 'heroStats': [for (final s in u.heroStats) s.name],
              if (u.heroSkill case final s?) 'heroSkill': s.name,
              if (u.revived) 'revived': true,
            },
        ],
      };

  /// [heroes]: the dice a Hero from an older save rolls its missing picks with, here in the constructor (its
  /// attributes, its skill). A probe that seeds its dice passes it here: set by a cascade after the
  /// constructor (`..heroes = Random(s)`), it comes too late for those, and runs of one seed differ (#76).
  Game.fromJson(Map<String, dynamic> j, [Random? rng, Random? names, Random? heroes])
      : rng = rng ?? Random(),
        names = names ?? Random() {
    if (heroes != null) this.heroes = heroes;
    gold = j['gold'] as int;
    lives = min(j['lives'] as int, startLives); // saves from when a game started with 10 (before #79) keep at most 3 hearts
    wave = j['wave'] as int;
    // A save from before the tide (#92) catches up halfway: its tide counts from [tideCatchUp] waves back. Said once
    // when that already reaches the coming wave.
    final saved = j['tideStart'] as int?;
    tideStart = saved ?? max(tideFrom, wave - tideCatchUp);
    tideCaughtUp = saved == null && wave + 1 >= tideStart;
    score = j['score'] as int? ?? 0; // saves from before the scoreboard start at 0
    kills = j['kills'] as int? ?? 0;
    baseX = cam = (j['baseX'] as num).toDouble();
    // Saves from before capacity bought the zone's width instead, a column at a time at the same prices:
    // each column past [deployCols] counts as one purchase (saves older still had 6 columns).
    capacity = j['capacity'] as int? ?? capacityStart + ((j['zoneCols'] as int? ?? 6) - deployCols) * capacityStep;
    // The rooms 256's Army-header ladder sold (its save key `capBought`, gone since decisions-log 260) become capacity,
    // up to the board's most and never lower than the capacity was: the owner's save, 30 + 6, comes back at 36.
    if (j['capBought'] case final int bought when bought > 0) capacity = max(capacity, min(capacity + bought, armyMaxBoard));
    // An item name this build doesn't know is skipped (decisions-log 245), here and in [upgrades].
    for (final e in ((j['inventory'] as Map?) ?? {}).entries) {
      if (Item.values.asNameMap()[e.key] case final i?) inventory[i] = e.value as int;
    }
    // A relic name this build doesn't know is skipped; an artefact in the bag of a save from before the Pusaka is a
    // copy to count ([Pusaka._migratePusaka]), never a relic in the bag.
    final copies = <Relic>[];
    for (final e in ((j['relicBag'] as Map?) ?? {}).entries) {
      final r = Relic.values.asNameMap()[e.key];
      if (r == null) continue;
      if (r.pusaka) {
        copies.addAll(List.filled(e.value as int, r));
      } else {
        relicBag[r] = e.value as int;
      }
    }
    for (final e in ((j['upgrades'] as Map?) ?? {}).entries) {
      upgrades[e.key as String] = [for (final i in e.value as List) ?Item.values.asNameMap()[i]];
    }
    // The Awaken levels kept from before the grades (decisions-log 272): a save without the key was written by a game
    // reading the old rule, so each type keeps the level its items gave; one with it, what it says.
    if (j['awakenKept'] case final Map kept) {
      for (final MapEntry(:key, :value) in kept.entries) {
        if ((key, value) case (final String type, final int n) when n > 0 && troopTypes.containsKey(type)) awakenKept[type] = min(n, maxAwaken);
      }
    } else {
      for (final type in upgrades.keys) {
        if (troopTypes.containsKey(type) && oldItemLevel(type) > 0) awakenKept[type] = oldItemLevel(type);
      }
    }
    _loadEnhance(j); // the enhanced items' pluses (enhance.dart): none in a save without them
    _loadWishes(j); // the Wishlist (wishlist.dart): none in a save without it
    // The Towns' materials (town.dart): none in saves from before them; a name this build doesn't know is skipped.
    for (final e in ((j['materials'] as Map?) ?? {}).entries) {
      if ((Mat.values.asNameMap()[e.key], e.value) case (final m?, final int n) when n > 0) materials[m] = n;
    }
    // The kinds dropped so far (the forge's, town.dart): in the save's order, an unknown name skipped; a save without
    // them starts from the materials held, in [Mat] order. A stone ([craftedMats]) never drops, so never counts.
    if (j['matsSeen'] case final List seen) {
      matsSeen.addAll([for (final n in seen) if (Mat.values.asNameMap()[n] case final m? when !m.crafted) m]);
    } else {
      matsSeen.addAll([for (final m in droppedMats) if (materials.containsKey(m)) m]);
    }
    // What the store sold so far, for its rising prices (store.dart); none in saves from before it. The Town's Shop
    // sells the Smithy's seven small relics too (decisions-log 230, 233), the forge's nine (decisions-log 245) and the
    // forge's the materials (decisions-log 248), so their counts come back as well.
    for (final e in ((j['storeBought'] as Map?) ?? {}).entries) {
      if ([...storeGoods, ...smallRelics, ...forgeRelics, ...Mat.values].where((k) => k.name == e.key).firstOrNull case final kind?) {
        storeBought[kind] = e.value as int;
      }
    }
    // The Pusaka (pusaka.dart): by name, each with its type (null: the Gudang) and stars; none in saves from before
    // them. An unknown name, or a type that isn't a troop type, is dropped.
    for (final e in ((j['pusaka'] as Map?) ?? {}).entries) {
      final r = Relic.values.asNameMap()[e.key], v = e.value as Map;
      if (r == null || !r.pusaka) continue;
      final type = v['type'] as String?;
      // Its Ukir (pusaka.dart): none in saves from before it, or never fed; the bar under its step's cost.
      final steps = r.oath ? 0 : (v['ukir'] as int? ?? 0).clamp(0, ukirCost.length);
      pusaka[r] = OwnedPusaka(
          type: troopTypes.containsKey(type) && !r.oath ? type : null, // an oath is the army's, on no type
          stars: (v['stars'] as int? ?? 1).clamp(1, maxStars(r)),
          binds: v['binds'] as int? ?? 0,
          suggested: v['suggested'] == true,
          ukir: steps,
          feed: steps < ukirCost.length ? (v['feed'] as int? ?? 0).clamp(0, ukirCost[steps] - 1) : 0);
    }
    notes.addAll([for (final n in (j['notes'] as List?) ?? const []) n as String]);
    asahAt = j['asahAt'] as int?; // none in saves from before Asah (pusaka.dart)
    lostWave = switch (j['lostWave']) { final int w when w > wave => w, _ => null }; // a wiped wave, still ahead (wipe.dart)
    bestWon = max(wave, j['bestWon'] as int? ?? 0); // a save is made between waves: its wave was won (wipe.dart)
    weakened = (j['weakened'] as int? ?? 0).clamp(0, weakenedMost);
    wipeAsk = j['wipeAsk'] == true;
    if (j['ukir'] case final Map u) {
      // the run's Ukir (pusaka.dart); none in saves from before it, or never fed
      ukir
        ..iv = u['iv'] as int? ?? 0
        ..pts = u['pts'] as int? ?? 0
        ..milli = u['milli'] as int? ?? 0;
    }
    // An older save's `overFrom` (Beban's first wave over the cap, decisions-log 162) is read as nothing since 329.
    autoReplace = j['autoReplace'] == true; // Auto (decisions-log 283): off in saves from before it
    // "Ganti yang gugur"'s fallen troops still to buy back (#92); none in saves from before it.
    for (final f in (j['toReplace'] as List?) ?? const []) {
      if (troopTypes.containsKey(f['type'])) toReplace.add((type: f['type'] as String, post: Point((f['x'] as num).toDouble(), (f['y'] as num).toDouble())));
    }
    // Bangkit 4 and 5 bought (lib/ascend.dart), before the troops come in with their stats; none in older saves.
    for (final e in ((j['ascended'] as Map?) ?? {}).entries) {
      if (troopTypes.containsKey(e.key)) ascended[e.key as String] = (e.value as int).clamp(0, maxAscend);
    }
    // Tempa bought (lib/tempa.dart), before the troops too; none in older saves.
    for (final e in ((j['tempa'] as Map?) ?? {}).entries) {
      if (troopTypes.containsKey(e.key)) tempa[e.key as String] = (e.value as int).clamp(0, tempaMax);
    }
    _loadBoosts(j); // the Tavern's boosts running (tavern.dart), before the troops too
    // The fallen Heroes to call back (recall.dart); none in saves from before it, and one of an unknown type is dropped.
    for (final f in (j['fallenHeroes'] as List?) ?? const []) {
      if (FallenHero.fromJson(f as Map) case final h?) fallenHeroes.add(h);
    }
    // The Legenda found this run (pusaka.dart), by name (an unknown one skipped); one owned is found too.
    for (final name in (j['legendsFound'] as List?) ?? const []) {
      if (Relic.values.asNameMap()[name] case final r? when r.rarity == Rarity.legenda) legendsFound.add(r);
    }
    legendsFound.addAll(pusaka.keys.where((r) => r.rarity == Rarity.legenda));
    final loaded = <(Unit, double)>[]; // each troop and the HP it was saved with
    for (final t in j['troops'] as List) {
      final type = t['type'] as String;
      final u = _newTroop(type, Point((t['x'] as num).toDouble(), (t['y'] as num).toDouble()), t['name'] as String?);
      units.add(u
        ..hero = t['hero'] == true // saves from before Heroes have none
        ..heroStats = [for (final s in (t['heroStats'] as List?) ?? const []) HeroStat.values.byName(s as String)]
        ..heroSkill = u.hero ? HeroSkill.values.asNameMap()[t['heroSkill']] : null
        ..relics.addAll([
          // Saves from before a Hero's second slot (#91) have its one relic as 'relic'. A worn artefact (from before
          // the Pusaka) comes off as a copy to count, below; an unknown name is skipped.
          for (final r in (t['relics'] as List?) ?? [?t['relic']])
            if (Relic.values.asNameMap()[r] case final relic? when !relic.pusaka) relic,
        ])
        ..revived = t['revived'] == true);
      // A Hero from before the rolled attributes (all ×3) gets its roll now, like a new one; one with an
      // attribute no longer rolled (attack rate, #69) rolls just that one again.
      if (u.hero && u.heroStats.isEmpty) _rollHeroStats(u);
      if (u.hero) _rerollOutOfPool(u);
      // A Hero from before its own skill (or with one no longer known) rolls it now, like a new one.
      if (u.hero && u.heroSkill == null) _rollHeroSkill(u);
      for (final r in (t['relics'] as List?) ?? [?t['relic']]) {
        if (Relic.values.asNameMap()[r] case final relic? when relic.pusaka) copies.add(relic);
      }
      loaded.add((u, (t['hp'] as num).toDouble()));
    }
    // A save's `runTypes` (decisions-log 141's roster, gone with 201) is no longer read.
    _refitTroops(); // the Heroes' stats and their aura (and an oath's: the types alive), now that every troop is in
    // Saves from before names get one now; saves from before defence counted shields as HP, so a troop
    // can't come back with more than it has now.
    _loadedHpBack(loaded);
    // A save from before the Pusaka: its artefacts become Pusaka, bound by default (the HP Dragon Heart gives comes
    // with it), and the one-time message waits ([pusakaNote]); one with none has nothing to tell.
    final migrated = _migratePusaka(copies);
    if (!migrated && !j.containsKey('pusaka')) notes.add(pusakaNote);
    capacity = max(capacity, armySize); // an old army bigger than that isn't cut
    _loadChests(j); // the boss chests waiting, or an old save's catch-up ones (draft.dart)
    _loadOmens(j); // the Bayangan, or an old save's catch-up (omen.dart)
    _loadTown(j); // the Towns' chance, last slot and mark (town.dart)
    _loadMarket(j); // the market's memory (market.dart): fresh in a save without it
  }

  /// A monster of [type] and [tier] of this wave at [at], its stats through the Bayangan's hooks ([Omens.spawnStats];
  /// [skipBuff]: one of the wave's first after Lewati, [skipBuffN]) and a slot's Shield ([Omens._omenSpawn]). It comes
  /// on with full MP, except the summoner, which starts at [mpStart] of it.
  Unit monster(String type, Tier tier, Point<double> at, {bool skipBuff = false}) {
    final u = Unit(Side.enemy, type, spawnStats(type, tier, skipBuff: skipBuff), at)
      ..tier = tier
      ..skipBuffed = skipBuff;
    if (type == boss) u.mp *= mpStart;
    _omenSpawn(u);
    return u;
  }

  Iterable<Unit> get troops => units.where((u) => u.side == Side.troop);
  Iterable<Unit> get enemies => units.where((u) => u.side == Side.enemy);

  /// Who has a boss bar (#67; lib/boss_bar.dart): the wave's mini boss and boss (not one a necromancer
  /// raised) once they are on the field, alive or dying (the bar breaks away), the boss first.
  List<Unit> get bossBarUnits => [
        for (final u in enemies)
          if (u.entered && !u.gone && u.raisedBy == null && (u.tier == Tier.boss || u.tier == Tier.miniBoss)) u
      ]..sort((a, b) => b.tier.index.compareTo(a.tier.index));

  /// How many living troops of each type there are, in [troopTypes]' order (the book's); a type with
  /// none is left out. The troop counter shows them (lib/troop_counter.dart).
  Map<String, int> get troopCounts {
    final n = <String, int>{};
    for (final u in troops) {
      if (u.alive) n[u.type] = (n[u.type] ?? 0) + 1;
    }
    return {for (final t in troopTypes.keys) t: ?n[t]};
  }

  bool get waveActive => queue.isNotEmpty || _anyEnemy;

  /// Whether a monster is in [units] ([enemies] isn't empty), looked for from the end, where the monsters come in after
  /// the troops: [waveActive] is read thousands of times a tick late in a wave, and [enemies] walked every troop first
  /// (decisions-log 317).
  bool get _anyEnemy {
    for (var i = units.length - 1; i >= 0; i--) {
      if (units[i].side == Side.enemy) return true;
    }
    return false;
  }

  /// The fewest monsters alive on the field while the wave's [queue] holds more ([spawnFloorOf]): one for every
  /// [spawnFloorPer] living troops, Heroes too, rounded up. Every living monster counts toward it, a raised minion too
  /// (each keeps the wave on, [waveActive]); a dying one doesn't.
  int get spawnFloor => spawnFloorOf(troops.where((u) => u.alive).length);

  /// Whether fewer monsters live on the field than the [spawnFloor] while the [queue] holds more: the next comes on now.
  bool get belowSpawnFloor => queue.isNotEmpty && enemies.where((u) => u.alive).length < spawnFloor;
  /// The game is over: no life is left (the last heart a lost wave cost, wipe.dart).
  bool get over => lives <= 0;

  /// The wave just fought ended with the army wiped ([Wipe._wipe], wipe.dart): set as it falls, until the next wave
  /// starts. Not saved ([lostWave] is).
  bool wipedOut = false;

  /// When the army was last wiped ([t]), for the UI to say so and save once; [double.negativeInfinity] in a game where
  /// it wasn't.
  double wipedAt = double.negativeInfinity;

  /// Why the wave was last lost ([wipedAt]), for the UI's note (wipe.dart).
  WipeCause wipeCause = WipeCause.fell;

  /// The furthest wave the army was wiped in, to be played again (wipe.dart): past [wave] between waves (the next one
  /// with no Town gone into yet, further after a trip back to the checkpoint's Town), [wave] or past it while the waves
  /// up to it are played again; null once it is won. Saved.
  int? lostWave;

  /// The highest wave won this run (wipe.dart, decisions-log 333): after a wipe sent the game back to a Town, a wave won
  /// again pays its once-a-number rewards (the wave's score, a Hero, a Boss Chest, the Shadows' catch-up) only past it,
  /// and what opens at a wave won ([wonWave]) stays open. Saved.
  int bestWon = 0;

  /// How weakened the monsters are after a wipe (wipe.dart: [weakenedHp], [weakenedDmg] by it, at most [weakenedMost]),
  /// until the next new Town is gone into ([Towns.enterTown]). Saved.
  int weakened = 0;

  /// After a wipe that left hearts, the player hasn't chosen yet between "Try again" and "Give up" (wipe.dart, wipe_ask.dart;
  /// never while [autoTryAgain] is on): no wave starts and no Town opens until then. Saved, so a reload asks again.
  bool wipeAsk = false;

  /// Wave [n] has been won: past it, on it between waves, or before a wipe sent the game back ([bestWon]).
  bool wonWave(int n) => bestWon >= n || wave > n || (wave == n && !waveActive);

  /// The furthest wave this run got to: the one fought or just won, or the one after [bestWon] after a trip back (the
  /// game-over screen and the scoreboard's wave).
  int get waveReached => max(wave, lostWave ?? 0);

  /// The monsters a wipe swept off the field, no longer in [units]: they hop for joy where they stood for [wipeCheer] s
  /// (the UI draws them), then go ([Wipe._sweptGone]).
  final swept = <Unit>[];

  /// Phoenix Plume rises due ([HeroSkills.later]): while one is, the army isn't wiped. A wave's end drops them.
  int _risesDue = 0;

  /// The wave stalled ([stallTime]): its monsters charge the troops ([_charge]) and don't heal, summon or back off any
  /// more. Within [marchMax] s of its start the wave is won, or lost (wipe.dart). Cleared when the wave ends.
  bool marching = false;

  /// When the monsters began to charge ([marching]).
  double _marchAt = 0;

  /// Since when no troop has stood in this wave whose monsters came on and none of which fell ([emptyGrace], wipe.dart);
  /// null while one stands.
  double? _emptyFrom;

  /// The monsters just started marching ([marching]), for the UI to say so; the UI clears it.
  bool newMarch = false;

  /// This wave (between waves, the last one) stalled and its monsters marched ([marching]), which stays so through the
  /// break: the guide's "Too slow" card (lib/guide_rules.dart). Set with [newMarch], cleared when a wave starts. Not
  /// saved.
  bool stalled = false;
  double _stallLow = double.infinity, _progressAt = 0, _frontLow = double.infinity, _quietFrom = 0; // [_watchStall]
  double _overtimeFrom = 0, _slotHp = 0, _slotMaxHp = 0; // the overtime clock's start, the slots' HP and max HP then
  int _stallCount = 0; // [_watchStall]

  /// The game is paused (the UI's pause button, Esc / P, or the book opened mid-wave): [tick] does nothing, so
  /// nothing moves, fights, spawns, heals or counts down. Not saved: a loaded game starts unpaused.
  bool paused = false;

  /// Troops use their skills ([troopSkills]); a probe or test can turn them off to compare.
  bool skills = true;

  /// Troops that just cast their skill, for the UI (its name pops up over them); drained like [sfx].
  final casts = <Unit>[];

  /// Troop healers a heal just found short of MP ([healMp], [Unit.dry]), for the UI ("No MP" pops up over them); drained
  /// like [casts].
  final noMp = <Unit>[];

  /// Troops cast their type's awakening skill ([AwakenSkill], awaken_skills.dart, #88); a probe or test can turn
  /// them off to compare. Off, a game plays as it did before them.
  bool awakenSkills = true;

  /// Troops whose awakening skill's name pops over them, with the skill and its level: they just cast it, or their
  /// type just reached that level (the awakening moment). For the UI, drained like [casts]; the casts alone are the
  /// [AwakenSkillCast] events.
  final awakenCasts = <(Unit, AwakenSkill, int)>[];

  /// When a hurt troop falls back and when it goes back in: the rule with the brain loaded at start
  /// ([RuleRetreatPolicy], [retreatBrain]); a probe or test may give it another.
  RetreatPolicy retreatPolicy = const RuleRetreatPolicy();

  /// Heroes use their own skills ([Unit.heroSkill], hero_skills.dart); a probe or test can turn them off.
  bool heroSkills = true;

  /// Light melee walking in keep near the heavies ([paceLimit]), and melee left behind the fight catch up
  /// ([speedTo]); a probe or test can turn either off to compare (#56).
  bool heavyPace = true, meleeCatchUp = true;

  /// Nobody is left off the screen: no troop walks past the view's right edge ([frontCap]), the healers rest close
  /// behind the melee ([healBehind]), and the melee don't turn back and forth ([turnHold], decisions-log 324); a troop
  /// healer out of sight walks into view before it heals, and one left behind the army walks up between heals
  /// (decisions-log 312). A probe or test can turn it off to compare.
  bool keepSupports = true;

  /// On: a kiting troop past its foe (the foe between it and the base) keeps its x and only steps aside, so a kite
  /// never takes it away from the base. Off by default (decisions-log 153): qa-3's stall (a lone wizard right of a
  /// ranged mini boss backed off right and the boss followed, 2,000+ px in 4 min with the view, so [rightLimit],
  /// in tow) is ended by [_watchStall] ([stallDrift], [stallOvertime]), and where the hold binds, after a near-wipe,
  /// it took the last troops' way out: on 14437d0 two of qa-3's three stalled waves ended with the army wiped instead
  /// of won. Kept for the QA cycle to weigh, on against off.
  bool holdPastFoe = false;

  /// Heroes that just cast their own skill, and which, for the UI; drained like [casts].
  final heroCasts = <(Unit, HeroSkill)>[];

  /// High elites and up use their type's skills ([MonsterSkill], monster_skills.dart, #59); a probe or test can
  /// turn them off to compare.
  bool monsterSkills = true;

  /// The blow [_hurt] is dealing now is holy ([MonsterSkillSignatures._holyHurt]): no skeleton reassembles
  /// from it, and it ends a heap of bones.
  bool _holy = false;

  /// Monsters that just began a skill's wind-up, and which, for the UI (its title pops up over them in red);
  /// drained like [casts].
  final monsterCasts = <(Unit, MonsterSkill)>[];

  /// The skeleton-kind monsters that fell this wave, where they lie, for a skeleton boss's Grave Call
  /// (boss_skills.dart); cleared when a wave starts.
  final graves = <Unit>[];

  /// Extra kill gold (Plunder) where it was paid, for the UI to float; drained like [sfx].
  final goldPops = <(Point<double>, int)>[];

  /// The game's events, the last [logSize] of them (game_events.dart; the battle log shows them). Not saved.
  final log = EventLog();

  /// Called with every event as it happens (the telemetry, #64, subscribes here).
  final listeners = <void Function(GameEvent)>[];

  /// Logs [e] (not a [TraceEvent]) and hands it to every listener.
  void _emit(GameEvent e) {
    if (e is! TraceEvent) log.add(e);
    for (final l in listeners) {
      l(e);
    }
  }
  final _later = <(double, void Function())>[]; // [HeroSkills.later]

  /// Troops just brought back by Resurrection, for the UI to announce by name; the UI clears it.
  final risen = <Unit>[];

  /// A wave can start: none is on, the game isn't over and no Town is due ([Towns.townDue]: marked for the next wave,
  /// until it is left), nor a wipe's choice waiting ([wipeAsk]). The Start/Pause toggle starts a wave only then
  /// (ui-hud.md); in a Town it says "Leave town".
  bool get canStartWave => !waveActive && !over && !townDue && !wipeAsk;

  void startWave() {
    if (townPolicy != null) _townByPolicy(); // a probe's due Town, gone through first (town.dart)
    if (!canStartWave) return;
    if (draftPolicy != null && chests.isNotEmpty) _pickChests(); // a probe's chests still waiting (draft.dart)
    wave++;
    _omenWave(); // the Bayangan's factor frozen, Lewati's skip buff, the catch-up landing (omen.dart)
    waveSpawned = 0;
    fallen.clear();
    wipedOut = false; // a new fight (a wave lost to a wipe is played again: wipe.dart)
    swept.clear();
    _risesDue = 0;
    _autoWaveStart(); // Auto takes what is left of the offer into its queue (auto_replace.dart)
    toReplace.clear(); // the offer lasts until the next wave
    graves.clear();
    // The fight is back on: whoever wasn't healed yet goes in as they are, unless the healers carry on with
    // the after-wave heals while it starts ([RetreatBrain.carryHealQueue]).
    if (!retreatPolicy.brain.carryHealQueue) healQueue.clear();
    marching = stalled = false;
    _emptyFrom = null;
    _stallLow = _frontLow = double.infinity;
    _progressAt = _quietFrom = _overtimeFrom = t;
    _slotHp = _slotMaxHp = 0;
    _stallCount = 0;
    for (final u in troops) {
      u.heroSkillAt = double.negativeInfinity; // every Hero's own skill is ready again
      u.fxOnce = false; // and every once-a-wave Pusaka Fx (the Grail's save, [grailK])
      u.ironWillUsed = false; // and Iron Will's heal (relics.dart)
      u
        ..charge = null // a charge from the last wave's kill is gone (Momentum)
        ..firstStrikeAt = double.infinity // it strikes first anew ([FxEngine])
        ..belowHp = 0; // and its once-an-HP-threshold flags answer again
    }
    _fxFirsts.clear(); // each type's first again ([If.firstOfTypeThisWave])
    _fxTypeReady.clear(); // and each type-wide cooldown ready (Soul Shelter's)
    pusakaWorth.clear(); // what the Pusaka do, counted afresh ([PusakaTally])
    _grailWatch.clear();
    _fxWave(); // the Pusaka's `waveStart` Fx (pusaka_engine.dart)
    _spiritWards(); // Spirit Ward's shields (relics.dart)
    _relicWave(); // the forge's nine: charges and stacks gone, counted afresh (relics.dart)
    relicsBack.clear();
    grailFirst = null;
    _staggerAwaken(); // every awakening skill comes ready over the wave's first 0–3 s (awaken_skills.dart)
    sfx.add(Sfx.wave);
    _escorted = null;
    _escortDue = 0;
    final pool = poolOf(wave), n = 4 + 2 * wave;
    final veterans = omenK(OmenKind.veterans); // the Bayangan Veterans: more silver on the same draw, never more gold (omen.dart)
    Tier rank([Random? dice]) {
      final r = (dice ?? rng).nextDouble(), high = highEliteChance(wave);
      return r < high ? Tier.highElite : (r < high + eliteChance(wave) + veterans ? Tier.elite : Tier.normal);
    }
    queue.addAll(List.generate(n, (_) => (pool[rng.nextInt(pool.length)], rank())));
    // The slots' types come from [slots], so the spawn sequence stays; the mini boss's necromancer roll stays
    // on [rng], as before.
    var necroRoll = 1.0; // the mini boss's roll for the necromancer, under [necroMiniChance] when it drew it
    if (wave % miniBossEvery == 0) {
      // Any type of the pool, the stronger likelier, or from [necroMiniFrom] sometimes the necromancer.
      if (wave >= necroMiniFrom) necroRoll = rng.nextDouble();
      queue.add((necroRoll < necroMiniChance ? boss : slotType(pool, slots.nextDouble()), Tier.miniBoss));
    }
    if (wave % bossEvery == 0) {
      // The necromancer at [necroBossChance], else any type of the pool; after the mini boss when both come. Before
      // [necroBossFrom] a roll that drew it takes a type of the pool from that roll scaled back to 0–1 (the pair rule's
      // way below), so no die draws more: every die of a later wave stays as it was.
      final roll = slots.nextDouble(), drew = roll < necroBossChance, necro = drew && wave >= necroBossFrom;
      queue.add((necro ? boss : slotType(pool, drew ? roll / necroBossChance : slots.nextDouble()), Tier.boss));
      // With [necroPairAllowed] off, never the necromancer twice: the mini boss, rolled before the boss, takes a type
      // of the pool from its own necromancer roll scaled back to 0–1, at any mini boss's odds. No die draws more than
      // with it on, so everything else of the wave, the later waves and the saved waves' replays stay as they were.
      if (necro && necroRoll < necroMiniChance && !necroPairAllowed) {
        queue[queue.length - 2] = (slotType(pool, necroRoll / necroMiniChance), Tier.miniBoss);
      }
    }
    // From [escortFrom] each of them (the queue's tail) brings its escort right behind it (#90); its healers' ranks
    // come from [slots] after the slots' own rolls, so the rest of the wave is the same as without them.
    for (var i = queue.length - 1; wave >= escortFrom && i >= n; i--) {
      queue.insertAll(i + 1, [
        for (var k = 0; k < escortHealers; k++) (necroHealer, rank(slots)),
        for (var k = 0; k < escortSummoners; k++) (boss, escortSummonerTier),
      ]);
    }
    // Healers come after the first (and second) third of the wave, so there is a front to stand behind (more
    // than two spread evenly: after each quarter, fifth…); on a boss wave the last one walks right behind the boss
    // (behind its escort, from [escortFrom]).
    final healers = necroHealersIn(wave), behind = wave % bossEvery == 0 && healers > 0, parts = max(3, healers - (behind ? 1 : 0) + 1);
    for (var i = 0; i < healers; i++) {
      final h = (necroHealer, rank());
      behind && i == healers - 1 ? queue.add(h) : queue.insert(n * (i + 1) ~/ parts + i, h);
    }
    _guarded = null;
    _omenQueue(); // Guard's monsters behind each slot's escort, Lewati's skip buff counted (omen.dart)
    _spawnTimer = 0;
    _emit(WaveStarted(wave, t,
        army: troopCounts,
        levels: {for (final type in troopTypes.keys) if (awakenLevel(type) > 0) type: awakenLevel(type)},
        heroes: [for (final u in troops) if (u.alive && u.hero) (u.type, u.heroSkill?.name)],
        gold: gold,
        capacity: capacity,
        lives: lives,
        bag: {for (final MapEntry(:key, :value) in inventory.entries) if (value > 0) key.name: value},
        relics: {for (final MapEntry(:key, :value) in relicBag.entries) if (value > 0) key.name: value},
        tide: (hp: tide(wave, tideHp, tideStart), dmg: tide(wave, tideDmg, tideStart), gap: spawnGapOf(wave, tideStart)),
        pusaka: pusakaState,
        omens: _omenState,
        materials: {for (final MapEntry(:key, :value) in materials.entries) key.name: value},
        boosts: boosts.isEmpty ? null : {for (final b in boosts) b.kind.name: b.untilTown ? 0 : b.left}, // the Tavern's (tavern.dart)
        weakened: weakened, // the monsters weakened after a wipe (wipe.dart)
        again: wave <= bestWon));
  }

  /// Troops are set up in the zone just ahead of the back line, one per cell; mid-battle any cell will do
  /// (clashes are sorted out when the wave is won, see [_claimSpots]).
  bool canPlace(int c, int r) => inZone(c, r) && (waveActive || troopAt(c, r) == null);

  bool inZone(int c, int r) => c >= baseCol && r >= 0 && c < baseCol + zoneCols && r < rows;

  /// How many troops may be alive at once ("Kapasitas"). More is bought [capacityStep] at a time
  /// ([buyCapacity]); a troop bought when the army is [full] is refused.
  int capacity = capacityStart;

  /// What the next [capacityStep] costs: [capacityPrice], [capacityPriceRise] more for each bought.
  int get capacityCost => capacityPrice + capacityPriceRise * capacityBought;

  /// Capacity purchases so far (an old save's capacity may sit between two: the lower counts).
  int get capacityBought => max(0, (capacity - capacityStart) ~/ capacityStep);

  /// The most capacity there is: the board's [armyMax], the same at every screen size (decisions-log 260: until then
  /// also no more than the widest zone held, so a phone held upright stopped at 32); with no [armyMax] (a plain `Game()`)
  /// as many troops as the widest zone holds (30% of the field on screen).
  int get maxCapacity => armyMax ?? maxZoneCols * rows;
  bool get canBuyCapacity => capacity + capacityStep <= maxCapacity && gold >= capacityCost && !over;

  /// No "+Room" is left: one more [capacityStep] would pass [maxCapacity]. The spawn bar's "+Room" then reads "Room:
  /// max" ([Words.roomMax]; spawn_bar.dart, decisions-log 260, 283).
  bool get capacityMaxed => capacity + capacityStep > maxCapacity;

  /// Why a "+Room" buy ([buyCapacity]) can't go now, in the UI's words, or null: it can, or the game is over (no bar
  /// then). The spawn bar's greyed "+Room" says it on a tap (decisions-log 260, 292): at the most, "Army room is at its
  /// most (36)." (the room it holds: the capacity, no more than [maxCapacity]); too poor, "Not enough gold (need 110).",
  /// the next buy's price. [canBuyCapacity] has no other block.
  String? get whyNotCapacity => over
      ? null
      : capacityMaxed
          ? _roomAtMost
          : gold < capacityCost
              ? _roomShort
              : null;
  String get _roomAtMost => '${Words.roomAtMost} (${min(capacity, maxCapacity)}).';
  String get _roomShort => '${Words.notEnoughGold} (need ${thousands(capacityCost)}).';

  /// The tooltip of troop [type]'s card on the spawn bar (decisions-log 283; ui-hud.md "Spawn bar"): its name over its
  /// price ("Buy one: 50 gold."), how many live against its cap ("On the field: 3/10."), and why it can't be bought
  /// now ([buyRefusal]: "Not enough gold.", "Priests full 5/5").
  (String, List<String>) spawnTip(String type) {
    final why = buyRefusal(type), cap = typeCapOf(type), n = troopCounts[type] ?? 0;
    return (
      troopTypeNames[type]!,
      [
        '${Words.buy} one: ${thousands(priceOf(type))} gold.',
        'On the field: ${cap == null ? '$n' : '$n/$cap'}.',
        if (why != null) why == buyRefusals.gold ? '$why.' : why,
      ],
    );
  }

  /// The spawn bar's "+Room" tooltip (spawn_bar.dart; decisions-log 260, 292), the title first: what it does and costs
  /// ("+Room: more army room (110 gold)."), the room now and after, the zone's new column while it still widens
  /// ([zoneCols]), and why not while too poor; at the most, what it does and that ([whyNotCapacity]'s words).
  (String, List<String>) get roomTip {
    if (capacityMaxed) return (Words.room, ['${Words.room}: ${Words.moreRoom}.', _roomAtMost]);
    final after = (deployCols + max(0, (capacity + capacityStep - capacityStart) ~/ capacityStep)).clamp(deployCols, maxZoneCols);
    return (
      Words.room,
      [
        '${Words.room}: ${Words.moreRoom} (${thousands(capacityCost)} gold).',
        'Room $capacity now, ${capacity + capacityStep} after.',
        if (after > zoneCols) 'The deploy zone gets 1 column wider.',
        if (gold < capacityCost) _roomShort,
      ],
    );
  }

  /// The most troops alive at once whatever the [capacity] (the owner, decisions-log 141: [armyMaxBoard]), or null:
  /// none past the capacity. The board turns it on ([boardRules]); not saved.
  int? armyMax;

  /// How many troops may be alive now: the [capacity], at most [armyMax]. An army bigger than that (a save from
  /// before the cap: 48) keeps every troop; buys wait until fewer than this are alive ([full]).
  int get armyCap => min(capacity, armyMax ?? capacity);

  /// Troops alive now, against [armyCap].
  int get armySize => troops.where((u) => u.alive).length;

  /// No troop more joins now: the army at its cap, or Oath of the Few's size reached ([armyLocked]).
  bool get full => armySize >= armyCap || armyLocked;

  /// No troop more joins under Oath of the Few (decisions-log 247): the board's army cap on ([armyMax]), the oath taken
  /// and [fewOathK].army troops alive already, so one more would make it wait ([fewOathBar]). The cap itself stays
  /// ([armyCap]: what Beban and the Shadows' factor count), so an army over the oath's size pays nothing for it but the
  /// wait. With no army cap (a plain `Game()`) it bars nothing, as Oath of One's [typeLocked].
  bool get armyLocked => armyMax != null && pusaka.containsKey(Relic.fewOath) && armySize >= fewOathK.army;

  /// How many troops of each type may be alive at once ([typeCapBoard], decisions-log 201), or null: no cap. The board
  /// turns it on ([boardRules]); not saved. A type over its cap (a save from before the caps: the owner's 17 priests)
  /// keeps every troop; its buys wait until fewer than its cap are alive ([typeFull]).
  Map<String, int>? typeCap;

  /// [type]'s cap now, or null: none. The ONE place the cap is read (the rules, the Army page, the troop counter): the
  /// board's [typeCap], or none while Oath of One works (its two types may fill the army, as they could under
  /// decisions-log 155's roster of 2: pusaka.dart, decisions-log 201).
  int? typeCapOf(String type) => typeCap == null || oathOneWorks ? null : typeCap![type];

  /// Troops of [type] alive now, its Heroes too: what its cap counts.
  int aliveOf(String type) => troops.where((u) => u.alive && u.type == type).length;

  /// [type] is at its cap or over it ([typeCapOf]): no troop of it is bought ([buyRefusal]) or brought back by
  /// Resurrection until one falls.
  bool typeFull(String type) => switch (typeCapOf(type)) { final cap? => aliveOf(type) >= cap, _ => false };

  /// [type] can't join the army under Oath of One (decisions-log 201): the caps on, the oath taken, none of [type] alive
  /// and [oathOneK].types types alive already, so a third type would end the oath (while it waits, more than that).
  bool typeLocked(String type) =>
      typeCap != null && pusaka.containsKey(Relic.oathOfOne) && aliveOf(type) == 0 && typesAlive >= oathOneK.types;

  /// Why no troop of [type] can join now for its type, in the UI's words, or null: Oath of One bars it ([typeLocked],
  /// [oathOneBar]), or it is full ([typeFull]: "Priests full 5/5", the count as it is: "Priests full 17/5").
  String? typeRefusal(String type) {
    if (typeLocked(type)) return oathOneBar;
    if (typeFull(type)) return '${troopTypePlurals[type] ?? type} full ${aliveOf(type)}/${typeCapOf(type)}';
    return null;
  }

  /// Turns on the owner's limits the way the board plays (decisions-log 141, 201): [armyMax] [armyMaxBoard] and
  /// [typeCap] [typeCapBoard]; and the boss chest, [offers] (decisions-log 152); the troops' skill wind-ups,
  /// [skillWinds] (decisions-log 299). This game, for a cascade. None of them changes a troop's stats, so a save's troops
  /// ([Game.fromJson] fits them under the game's one set of rules, decisions-log 317, 321) stay as loaded.
  Game boardRules() {
    armyMax = armyMaxBoard;
    typeCap = typeCapBoard;
    offers = true; // and the boss chest (draft.dart, P3)
    skillWinds = true; // and the troops' skill wind-ups (skill_strips.dart)
    return this;
  }

  /// Each troop [Game.fromJson] read ([loaded]) back at the HP it was saved with, at most its max under the rules it is
  /// fitted to. A load's restore, not a heal (test/heal_funnel_test.dart's `notHeals`).
  void _loadedHpBack(List<(Unit, double)> loaded) {
    for (final (u, hp) in loaded) {
      u.hp = min(hp, u.maxHp.toDouble());
    }
  }

  /// Auto's countdown waits (decisions-log 141; qa-1: Auto began w86 5 s after a wave that left 20 of 48): with
  /// [armyMax] on, while fewer than [autoHoldShare] of [armyCap] are alive, until the player buys them back or
  /// presses Start. Under Oath of the Few the army is at most its [fewOathK].army, so that is what the share is of.
  bool get autoHeld => armyMax != null && armySize < autoHoldShare * (pusaka.containsKey(Relic.fewOath) ? min(armyCap, fewOathK.army) : armyCap);

  /// The wave won when the cap's warning last showed ([capWarning]). Not saved: a loaded game may say it once more.
  int? capWarnedAt;

  /// The army is full at the cap with the tide on (decisions-log 161): [armyMax] on and the capacity at it, the army
  /// as it stood this wave (the living and the wave's [fallen]: between waves, the last won one's) at the cap, the
  /// wave the meter shows past the tide's first ("+0%"), and a fielded type below [awakenTop], so there is a level
  /// left to buy.
  bool get capPressed {
    final cap = armyMax;
    if (cap == null || armyCap < cap || armySize + fallen.length < cap) return false;
    return (waveActive ? wave : wave + 1) > tideStart && troops.any((u) => u.alive && awakenLevel(u.type) < awakenTop);
  }

  /// The cap's warning ([capWarningText]) when it is due between waves, marked shown; else null. Due while
  /// [capPressed], and not in the [capWarnEvery] waves after it last showed.
  String? capWarning() {
    if (!canStartWave || !capPressed || (capWarnedAt != null && wave - capWarnedAt! < capWarnEvery)) return null;
    capWarnedAt = wave;
    return capWarningText(armyMax!, tidePercent(wave + 1, tideStart));
  }

  /// The limits' one-time notes due for this game (decisions-log 141, 201; their keys in [notes]: "army", "caps"), in the
  /// UI's words, each marked shown: an army or capacity over [armyMax] keeps its troops, and a type alive over its cap
  /// keeps its troops ([capsNote]). Empty with the limits off or within them. (The "over" note, Beban's tide for an army
  /// alive over the cap, went with Beban in decisions-log 329; an older save's "over" key stays, unread.)
  List<String> limitNotes() => [
        if (armyMax case final cap? when max(capacity, armySize) > cap && notes.add('army'))
          'The army cap is now $cap. You keep your troops;\nbuy more when under $cap.',
        if (overCaps case final over when over.isNotEmpty && notes.add('caps')) capsNote(over),
      ];

  /// The types alive over their cap ([typeCapOf]), in the book's order, as the caps' note says them: "Priest 17/5".
  List<String> get overCaps => [
        for (final type in troopTypes.keys)
          if (typeCapOf(type) case final cap? when aliveOf(type) > cap) '${troopTypeNames[type]} ${aliveOf(type)}/$cap',
      ];

  bool buyCapacity() {
    if (!canBuyCapacity) {
      sfx.add(Sfx.error);
      return false;
    }
    _emit(Bought(wave, t, cost: capacityCost));
    gold -= capacityCost;
    capacity += capacityStep; // and the zone a column wider (until 30% of the view); the army stays where it stands
    sfx.add(Sfx.place);
    return true;
  }

  /// Columns of the deploy zone: [deployCols], and one more for every capacity purchase (the owner: more
  /// capacity, more room to deploy), at most [maxZoneCols]. It always holds [capacity] troops: 8 per column against 2
  /// per purchase.
  int get zoneCols => (deployCols + capacityBought).clamp(deployCols, maxZoneCols);

  /// The widest the deploy zone gets: 30% of the field on screen (70% stays battleground), and on a view too narrow
  /// for that to hold the board's [armyMax] as many columns as do (decisions-log 260, which made it for a phone held
  /// upright; since decisions-log 289 the game is landscape only, and a window near square still needs it): 5 for 36.
  int get maxZoneCols => max(max(deployCols, (viewW * 0.3 / tile).floor()), switch (armyMax) { final cap? => (cap / rows).ceil(), _ => 0 });

  Unit? troopAt(int c, int r) => troops.where((t) => t.alive && t.cell == (c, r)).firstOrNull;

  /// Before a wave, a troop on the field can be moved to another cell of the zone; one already
  /// standing there swaps places with it.
  bool move(Unit u, int c, int r) {
    if (waveActive || over || !u.alive || !inZone(c, r)) {
      sfx.add(Sfx.error);
      return false;
    }
    final other = troopAt(c, r), from = u.post;
    u.post = u.pos = Point(c * tile + tile / 2, r * tile + tile / 2);
    if (other != null && other != u) other.post = other.pos = from;
    sfx.add(Sfx.place);
    return true;
  }

  /// Gives every troop a spot of its own: the first placed keeps a shared cell; a later one takes a free
  /// cell on its side of the ranks (Healer | long range | melee: melee forward, healers back, long range
  /// along its column), nearest first, and of two as near the one nearer where it stands (#82: not across the
  /// way of the one that kept the cell).
  void _claimSpots() {
    final taken = <(int, int)>{};
    for (final u in troops.where((u) => u.alive)) {
      if (taken.add(u.cell)) continue;
      final (uc, ur) = u.cell;
      (int, int)? best;
      var bestD = double.infinity;
      for (var c = baseCol; c < baseCol + zoneCols; c++) {
        for (var r = 0; r < rows; r++) {
          final dc = c - uc;
          final wrongSide = switch (u.line) { 2 => dc < 0, 0 => dc > 0, _ => dc != 0 };
          final d = (wrongSide ? 1000 : 0) + dc * dc + (r - ur) * (r - ur) + u.pos.distanceTo(Point(c * tile + tile / 2, r * tile + tile / 2)) * 1e-6;
          if (d < bestD && !taken.contains((c, r))) (best, bestD) = ((c, r), d);
        }
      }
      if (best == null) continue; // ponytail: a full zone leaves the clash; add a second zone if 48 troops ever happens
      taken.add(best);
      u.post = Point(best.$1 * tile + tile / 2, best.$2 * tile + tile / 2);
    }
  }

  /// After a win, two troops of a rank ([Unit.rank]) whose walks back to their spots cross trade spots, so the
  /// army walks home without cutting across itself (#82); so do two that would walk half a tile less between
  /// them the other way round (two swapping spots along one row). A crossing pair always walks less the other way
  /// round, so each trade shortens the whole walk: it ends, and never trades back. Less than that isn't worth a
  /// trade without a crossing, nor for two standing together (closer than [_personalSpace]: either may go first),
  /// so the first placed keeps a shared cell ([_claimSpots]).
  void _uncrossSpots() {
    final alive = troops.where((u) => u.alive).toList();
    for (var pass = 0, traded = true; traded && pass < alive.length; pass++) {
      traded = false;
      for (var i = 0; i < alive.length; i++) {
        for (var j = i + 1; j < alive.length; j++) {
          final a = alive[i], b = alive[j];
          if (a.rank != b.rank) continue;
          final gain = a.pos.distanceTo(a.post) + b.pos.distanceTo(b.post) - a.pos.distanceTo(b.post) - b.pos.distanceTo(a.post);
          final crossing = a.pos.distanceTo(b.pos) >= _personalSpace && _crosses(a.pos, a.post, b.pos, b.post);
          if (gain <= 0 || (gain < tile / 2 && !crossing)) continue;
          final post = a.post;
          a.post = b.post;
          b.post = post;
          traded = true;
        }
      }
    }
  }

  /// The walks [a0]→[a1] and [b0]→[b1] cross (touching at an end, or running along one line, doesn't count).
  static bool _crosses(Point<double> a0, Point<double> a1, Point<double> b0, Point<double> b1) {
    double side(Point<double> p, Point<double> q, Point<double> r) => (q.x - p.x) * (r.y - p.y) - (q.y - p.y) * (r.x - p.x);
    return side(a0, a1, b0) * side(a0, a1, b1) < 0 && side(b0, b1, a0) * side(b0, b1, a1) < 0;
  }

  /// Why a [type] troop can't be bought now, in the UI's words, or null (where it would go aside: [canPlace]). Every
  /// buy goes through it ([place]: the Army rows, [autoPlace], the rebuys; a fallen Hero's recall, recall.dart): its type
  /// can't take one more ([typeRefusal]: at its cap, or barred by Oath of One), the army is [full] (at [armyMax] "Army
  /// full 32/32", else [buyRefusals].full), unless the buy sends a troop of its type home for the one it brings
  /// ([swap]: a recall into a full army or type), for a Hero ([hero]) [heroMax] Heroes live already
  /// ([recallRefusals]), or it is too poor for [price] (a troop's own [priceOf] unless given).
  String? buyRefusal(String type, {int? price, bool hero = false, bool swap = false}) {
    if (!swap) {
      if (typeRefusal(type) case final why?) return why;
    }
    if (full && !swap) {
      if (armySize < armyCap) return fewOathBar; // Oath of the Few's size, under the cap ([armyLocked])
      return armyMax != null && armyCap == armyMax ? '${Words.army} full $armySize/$armyCap' : buyRefusals.full;
    }
    if (hero && heroCount >= heroMax) return recallRefusals.heroes;
    if (gold < (price ?? priceOf(type))) return buyRefusals.gold;
    return null;
  }

  /// Buys a [type] troop onto cell ([c], [r]) of the zone; refused ([buyRefusal]) when its type is full or barred, the
  /// army is [full] or it is too poor, or when the cell is taken.
  bool place(String type, int c, int r) {
    final price = priceOf(type);
    if (buyRefusal(type) != null || !canPlace(c, r)) {
      sfx.add(Sfx.error);
      return false;
    }
    gold -= price;
    _emit(Bought(wave, t, type: type, cost: price));
    _addTroop(type, c, r);
    _marchIn(units.last);
    _oathWatch(); // a type alive again lifts Alliance (pusaka.dart)
    sfx.add(Sfx.place);
    return true;
  }

  /// Troop [u], just added at its spot, marches in to it from off screen on the left; mid-wave from just left of the
  /// view (#61), however far behind it the back line is (#79: mid-wave the line stays put, so it may be hundreds of
  /// tiles back). Past the line it counts as entered and heads for the fight at the catch-up pace.
  void _marchIn(Unit u) => u
    ..pos = Point((waveActive ? cam : baseX) - 2 * tile, u.post.y)
    ..entered = false
    ..arriving = true
    ..joining = waveActive; // out of the troop front until it has joined ([BattleFocus.troopFront])

  /// Sends a [type] troop in and lines the whole army up again ([_formUp]). Before a wave it needs a
  /// free cell; mid-battle, with the zone full, troops share cells.
  bool autoPlace(String type) {
    final cell = _autoCell;
    if (cell == null) {
      sfx.add(Sfx.error);
      return false;
    }
    if (!place(type, cell.$1, cell.$2)) return false;
    _fallIn(units.last);
    return true;
  }

  /// The cell [autoPlace] sends a troop to: the zone's first free one, mid-battle with the zone full its first; null
  /// before a wave with none free.
  (int, int)? get _autoCell {
    final cells = [for (var c = baseCol; c < baseCol + zoneCols; c++) for (var r = 0; r < rows; r++) (c, r)];
    return cells.where((c) => troopAt(c.$1, c.$2) == null).firstOrNull ?? (waveActive ? cells.first : null);
  }

  /// [autoPlace]'s last step for troop [u], just sent in: the whole army lines up again ([_formUp]), and [u] marches
  /// in along its new row.
  void _fallIn(Unit u) {
    _formUp();
    u.pos = Point(u.pos.x, u.post.y);
  }

  /// Why [type] can't be sent home now (Lepas jenis, [releaseType]), in the UI's words, or null: the game is over, a
  /// wave is on, none of it is alive, or a Hero of it lives (Heroes are too rare to lose to a tap).
  String? whyNotRelease(String type) {
    if (over) return assignRefusals.over;
    if (waveActive) return takeOffRefusals.midWave;
    if (aliveOf(type) == 0) return releaseRefusals.none;
    if (hasHero(type)) return releaseRefusals.hero;
    return null;
  }

  /// What Lepas jenis on [type] pays back now: [releaseRefund] of its [priceOf] for each living troop of it.
  int releaseRefundOf(String type) => ((troopCounts[type] ?? 0) * priceOf(type) * releaseRefund).round();

  /// Lepas jenis (decisions-log 141, 201): sends [type] home between waves, to make room for other types or to bring
  /// Oath of One's types down to its two. Its living troops go home, each paying back [releaseRefund] of its [priceOf],
  /// and their relics go back to the bag; its fallen leave [toReplace]; its bound Pusaka goes to the Gudang
  /// (decisions-log 138), free.
  /// A refusal ([whyNotRelease]) plays the error and changes nothing. The gold paid back, or null when refused.
  int? releaseType(String type) {
    if (whyNotRelease(type) != null) {
      sfx.add(Sfx.error);
      return null;
    }
    final home = [for (final u in troops) if (u.alive && u.type == type) u], refund = releaseRefundOf(type);
    _sendHome(home);
    toReplace.removeWhere((f) => f.type == type); // "Ganti yang gugur" won't bring it back
    _oathWatch(); // a type fewer alive: Oath of One may work now, Alliance counts one type less (pusaka.dart)
    gold += refund;
    if (pusakaOf(type) case final r?) _toGudang(r); // its bound Pusaka waits in the Gudang, free (pusaka.dart)
    _emit(TypeReleased(wave, t, type: type, troops: home.length, refund: refund));
    sfx.add(Sfx.place);
    return refund;
  }

  /// Troops [home] go home between waves (Lepas jenis, a full army's recall swap: recall.dart): off the field, not
  /// fallen, and their relics back to the bag.
  void _sendHome(List<Unit> home) {
    for (final u in home) {
      for (final r in u.relics) {
        relicBag[r] = (relicBag[r] ?? 0) + 1;
      }
      u
        ..relics.clear()
        ..gone = true; // not fallen: off the field now (between waves nothing aims at a troop)
      impacts.add((u.pos, 'upgrade'));
    }
    units.removeWhere(home.contains);
    healQueue.removeWhere(home.contains);
  }

  /// Why "Ganti yang gugur" can buy nobody now, in the UI's words, or null: the game is over, a wave is on, or not
  /// one troop in [toReplace] can be bought ([buyRefusal]: the first one's reason).
  String? get whyNotReplace {
    if (over) return assignRefusals.over;
    if (waveActive) return takeOffRefusals.midWave;
    final why = [for (final f in toReplace) buyRefusal(f.type)];
    return why.contains(null) ? null : why.firstOrNull;
  }

  /// "Ganti yang gugur" (#92): buys the last won wave's fallen troops back ([toReplace]), between waves, the cheapest
  /// first, as many as [place] allows (the gold, the capacity: [buyRefusal]). Each goes back to its old spot, or,
  /// when that is taken, wherever [autoPlace] puts it. Returns how many came back, of how many, and why the rest
  /// didn't (the first refusal met; null when all came back).
  ({int bought, int of, String? why}) replaceFallen() {
    final of = toReplace.length;
    if (whyNotReplace case final why?) {
      sfx.add(Sfx.error);
      return (bought: 0, of: of, why: why);
    }
    int cheaper((int, ({String type, Point<double> post})) a, (int, ({String type, Point<double> post})) b) =>
        priceOf(a.$2.type) == priceOf(b.$2.type) ? a.$1.compareTo(b.$1) : priceOf(a.$2.type).compareTo(priceOf(b.$2.type));
    final order = [...toReplace.indexed]..sort(cheaper); // ties in the order they fell
    var bought = 0;
    String? why;
    for (final (_, f) in order) {
      if (buyRefusal(f.type) case final no?) {
        why ??= no;
        continue;
      }
      if (_replaceOne(f)) {
        toReplace.remove(f);
        bought++;
      }
    }
    return (bought: bought, of: of, why: why);
  }

  /// One of [toReplace] bought back: to its old spot when that is in the zone and free, else wherever [autoPlace] puts
  /// it. Whether it came.
  bool _replaceOne(({String type, Point<double> post}) f) {
    final (c, r) = ((f.post.x / tile).floor(), (f.post.y / tile).floor());
    return inZone(c, r) && troopAt(c, r) == null ? place(f.type, c, r) : autoPlace(f.type);
  }

  /// Whether [f] of [toReplace] has a cell to come back to now: its old spot, or one [autoPlace] gives.
  bool _replaceRoom(({String type, Point<double> post}) f) {
    final (c, r) = ((f.post.x / tile).floor(), (f.post.y / tile).floor());
    return inZone(c, r) && troopAt(c, r) == null || _autoCell != null;
  }

  /// Healer | long range | heavy melee | front melee ([Unit.rank]): the ranks fill the zone's cells
  /// front column first, each column from the middle rows out, each rank in the order placed. A rank
  /// starts a column of its own when that still leaves a cell for everyone; otherwise it carries on
  /// in the column the rank before it left. Only more troops than cells ever share one.
  void _formUp() {
    double mid(int r) => (r - (rows - 1) / 2).abs() + r * 0.01; // ties: the upper row
    final rowOrder = [for (var r = 0; r < rows; r++) r]..sort((a, b) => mid(a).compareTo(mid(b)));
    final cells = [for (var c = baseCol + zoneCols - 1; c >= baseCol; c--) for (final r in rowOrder) (c, r)];
    final ranks = [
      for (final rank in [3, 2, 1, 0]) troops.where((u) => u.alive && u.rank == rank).toList()..sort((a, b) => a.id.compareTo(b.id)),
    ];
    var i = 0, left = ranks.fold(0, (n, r) => n + r.length);
    for (final mine in ranks.where((r) => r.isNotEmpty)) {
      final skip = (rows - i % rows) % rows;
      if (cells.length - i - skip >= left) i += skip;
      for (final u in mine) {
        // Past the last cell (mid-battle only) the rest share cells from the back forward.
        final (c, r) = i < cells.length ? cells[i] : cells[cells.length - 1 - (i - cells.length) % cells.length];
        i++;
        final post = Point(c * tile + tile / 2, r * tile + tile / 2);
        // Setting up, a troop sent to a new spot walks straight through the others: with the whole
        // army re-forming at once, making way for each other only ends in shoving.
        if (post != u.post && !waveActive) u.arriving = true;
        u.post = post;
      }
      left -= mine.length;
    }
  }

  void _addTroop(String type, int c, int r) => units.add(_newTroop(type, Point(c * tile + tile / 2, r * tile + tile / 2)));

  /// A troop with every upgrade its type has been given ([statsOf]), and its [name] (else a new one no
  /// living troop has).
  Unit _newTroop(String type, Point<double> at, [String? name]) =>
      Unit(Side.troop, type, statsOf(type).boosted(heroAlive ? auraNow : 1), at) // with a living Hero's aura
    ..entered = true
    ..name = name ?? troopName(names, {for (final o in troops) if (o.alive) o.name});

  /// Every living healer works through [healQueue] at its own pace, patching itself up first ([_healFromQueue]).
  void _afterWaveHeal() {
    final healers = troops.where((u) => u.alive && u.stats.heals).toList();
    if (healers.isEmpty) return healQueue.clear();
    for (final h in healers) {
      if (healQueue.isEmpty) return;
      if (h.cd <= 0) _healFromQueue(h); // ticks down in the update loop
    }
  }

  /// Healer [h] gives the next troop in [healQueue] (itself first) its full health back.
  void _healFromQueue(Unit h) {
    final o = healQueue.contains(h) ? h : healQueue.first;
    healQueue.remove(o);
    h.cd = healGap;
    if (!o.alive) return;
    _healTroop(o, o.maxHp.toDouble(), HealSrc.queue); // all its HP back: never under Wound (heal.dart)
    o.healedAt = t;
    h.attackedAt = t;
    if (o != h) _face(h, o.pos.x - h.pos.x, 0);
    impacts.add((o.pos, _fxOf(h, 'heal')));
    sfx.add(_attackSfx[h.type]!);
  }

  /// A troop in the path of one that goes first ([_passes]) sees it coming and steps out of its way,
  /// even while fighting (shooting goes on), and walks back to its spot once it has passed. Between waves one
  /// walking somewhere of its own finds its own way round instead ([_steer], #82): pushed aside across its way it
  /// could only wait there, and a back-rank troop was even pushed back over it. A tick's steps aside take a yielder one
  /// of its own walk steps at most in all, however many troops pass it (decisions-log 309, the owner: "Ya, batasi
  /// juga"; before, a step for each: up to 14.6 units a tick on the owner's wave-30 save).
  void _makeWay(double dt) {
    final all = troops.where((u) => u.alive).toList(), stepped = <Unit, double>{};
    for (final b in all.where((u) => u.moving && !_ghost(u))) {
      // Its way ahead: [_lookAhead]; between waves no further than it still goes. A troop settling back onto its
      // spot (less than half a tile to go) has none to clear: in a packed zone its neighbours stand a tile off, and
      // it set them stepping aside by turns for good (#82).
      final h = b.heading, perp = Point(-h.y, h.x);
      final way = waveActive ? _lookAhead : min(_lookAhead, b.pos.distanceTo(b.goal ?? b.pos + h * _lookAhead));
      if (way < tile / 2) continue;
      for (final a in all) {
        if (a == b || _ghost(a) || _firm(a, troop: true) || _spotMates(a, b)) continue; // spot mates close in together (engage.dart)
        if (!waveActive && _walking(a)) continue; // it finds its own way round
        final rel = a.pos - b.pos, along = rel.x * h.x + rel.y * h.y, lat = h.x * rel.y - h.y * rel.x;
        if (along <= 0 || along > _lookAhead || _passes(a, b)) continue;
        if ((along <= way ? lat.abs() : rel.distanceTo(h * way)) >= _personalSpace) continue; // clear of its way
        var side = lat.abs() > 0.5 ? lat.sign : (perp.y * (fieldH / 2 - a.pos.y) >= 0 ? 1.0 : -1.0);
        // Setting up, the ranks hold (only melee may step forward); in battle nobody keeps a spot.
        if (!waveActive && a.line < 2 && perp.x * side > 0) side = -side;
        final step = a.walkSpeed * dt - (stepped[a] ?? 0); // what is left of its one walk step this tick
        if (step > 0) {
          a.pos += perp * (side * step);
          stepped[a] = a.walkSpeed * dt;
        }
        a.yieldUntil = t + 0.3;
      }
    }
  }

  /// A troop with nothing to do cheers in place after a win, then walks back to where it was dropped.
  /// Mid-wave (no monster about for now, or a healer with nobody to back) it holds where it is: its spot is
  /// in the zone at the back line, which stays put all wave ([baseX]), so walking to it would give up the
  /// ground the army has won.
  void _rest(Unit u, double dt) {
    if (waveActive || t - victoryAt < victoryTime || t < u.yieldUntil) {
      u.moving = false;
      return;
    }
    _moveToward(u, u.post, dt);
    if (!u.moving) u.dir = 1;
  }

  /// What troop [u] does about falling back ([retreatPolicy]), with the troop healer it falls back to (null
  /// while it fights). Mid-wave only, never for a healer itself, and never while it stands its ground.
  (RetreatAction, Unit?) _fallBackTo(Unit u) {
    final holds = u.effects.isNotEmpty && under(u, Status.holdGround); // it stands its ground ([Status.holdGround])
    if (holds || !waveActive || u.side != Side.troop || u.stats.heals) {
      u
        ..retreating = false
        ..waitFrom = double.nan;
      return (RetreatAction.fight, null);
    }
    final healers = troops.where((o) => o.alive && o.entered && o.stats.heals).toList();
    final healer = healers.isEmpty ? null : _nearestOf(healers, u);
    final act = retreatPolicy.decide(_retreatFeatures(u, healer, healers));
    u.retreating = act != RetreatAction.fight && healer != null;
    return (act, u.retreating ? healer : null);
  }

  /// Top to bottom as they stand (the placed first on a tie): the order healers take their lanes in.
  static int _topDown(Unit a, Unit b) => a.pos.y != b.pos.y ? a.pos.y.compareTo(b.pos.y) : a.id.compareTo(b.id);

  /// The one of [us] nearest to [u].
  Unit _nearestOf(List<Unit> us, Unit u) => us.reduce((a, b) => a.pos.distanceTo(u.pos) <= b.pos.distanceTo(u.pos) ? a : b);

  /// What the fall-back decision reads about troop [u] ([RetreatFeatures]); [healer] is the nearest of the
  /// troop [healers] (null with none).
  RetreatFeatures _retreatFeatures(Unit u, Unit? healer, List<Unit> healers) {
    final b = retreatPolicy.brain;
    u.hurtLog.removeWhere((h) => t - h.$1 > b.threatWindow);
    final reach = healer == null ? double.infinity : healer.pos.distanceTo(u.pos) / healer.stats.range;
    final atSpot = u.retreating && reach <= b.retreatNear;
    if (!atSpot) {
      u.waitFrom = double.nan;
    } else if (u.waitFrom.isNaN) {
      u.waitFrom = t;
    }
    final share = u.hp / u.maxHp;
    var rank = 0;
    if (atSpot) {
      for (final o in troops) {
        if (o == u || !o.alive || !o.retreating || o.waitFrom.isNaN || _nearestOf(healers, o) != healer) continue;
        if (o.hp / o.maxHp > share) rank++;
      }
    }
    final foes = [for (final e in enemies) if (e.alive && e.entered) e.pos.x];
    return (
      retreating: u.retreating,
      hpShare: share,
      dpsShare: u.hurtLog.fold(0.0, (s, h) => s + h.$2) / b.threatWindow / u.maxHp,
      healers: healers.length,
      healerReach: reach,
      waited: atSpot ? t - max(u.waitFrom, u.healedAt) : 0.0,
      rank: rank,
      frontFighters: troops.where((o) => o.alive && o.entered && o.line == 2 && !o.retreating).length,
      foeToBase: foes.isEmpty ? double.infinity : (foes.reduce(min) - baseX) / tile,
      ranged: u.stats.shotSpeed > 0,
      backRoom: (u.pos.x - baseX) / tile,
    );
  }

  /// [u] attacks [foe] now: a shot, or a blow (with its splash).
  void _strike(Unit u, Unit foe) {
    u.cd = attackEvery(u); // its rate, quicker while Rampage lasts
    u.attackedAt = t;
    if (omensOn && u.side == Side.troop) u.lastFoe = (foe: foe, at: t); // whom it fights, for the Bayangan Blindside (omen.dart)
    var dmg = u.stats.dmg * _blowK(u, u.stats.dmg, foe); // a worn fury's every 3rd blow, and its type's War Drum's (pusaka_engine.dart)
    if (u.relics.isNotEmpty) dmg *= _relicBlowK(u, foe, dmg); // the forge's nine, under the relics' cap (relics.dart)
    final pummel = omensOn && u.side == Side.enemy && _omenPummel(u); // a monster's every 3rd under Pummel (omen.dart)
    final sap = omensOn && u.side == Side.enemy && _omenSapBlow(u); // and its every 4th under Sap, on the same count
    if (u.stats.shotSpeed > 0) {
      shots.add(Shot(u, foe, u.pos + const Point(0, -6), Hit.normal, dmg)
        ..pummel = pummel
        ..sap = sap); // shows its hit when it lands
    } else {
      impacts.add((foe.pos, _fxOf(u, 'hit_${u.type}')));
      _deflected = false;
      _pummeled = pummel;
      _sapped = sap;
      if (u.stats.splash > 0) {
        for (final o in units.where((o) => o.side == foe.side && o.pos.distanceTo(foe.pos) <= u.stats.splash).toList()) {
          final dealt = _hurt(o, dmg, o == foe ? Hit.normal : Hit.extra, u); // past its target the splash is extra
          if (o != foe) _fxSplash(u, foe.pos, o, dealt, u.stats.splash); // Wide Blows' counter (pusaka_engine.dart)
        }
      } else {
        _hurt(foe, dmg, Hit.normal, u);
      }
      _pummeled = _sapped = false;
      if (!_deflected) _fxLanded(u, foe, dmg); // its type's `landed` Fx: God's Thunder (pusaka_engine.dart); none on a Deflected hit (omen.dart)
      if (!_deflected && u.relics.isNotEmpty) _relicLanded(u, foe, dmg, Hit.normal); // Sweep, Venom, Mana Siphon (relics.dart)
    }
    sfx.add(u.side == Side.troop ? _attackSfx[u.type] ?? Sfx.sword : Sfx.hit);
  }

  Unit? _nearestFoe(Unit u) {
    if (u.effects.isNotEmpty) {
      if (_taunter(u) case final by?) return by; // taunted ([Status.taunt]): a monster by a Hero, a troop by Bulwark
    }
    Unit? best;
    var bestD = double.infinity;
    for (final o in units) {
      if (o.side == u.side || !o.alive || t < o.downUntil) continue; // not a heap of bones (Reassemble)
      final d = o.pos.distanceTo(u.pos);
      if (d < bestD) (best, bestD) = (o, d);
    }
    return best;
  }

  void _face(Unit u, double dx, double dy) {
    if (dx.abs() > 0.01) u.dir = dx < 0 ? -1 : 1;
    u.face = dy.abs() > dx.abs() ? (dy > 0 ? Face.down : Face.up) : Face.side;
  }

  /// How fast [u] walks to [to]. Mid-wave a troop walking forward that has fallen behind the melee, more
  /// than its rank's place (a tile per rank: none for the melee) plus [_catchUp] behind the rearmost of them
  /// (of those in the fight, if any; a melee only once a fight is on), goes as fast as the fastest melee walks, but
  /// never more than [catchUpMost] × its own walk (decisions-log 309) nor than its legs can be drawn ([walkCap],
  /// decisions-log 311), until it is back within that gap: melee keep what their boots give them, and nobody is left
  /// behind (the supports; with [meleeCatchUp] the melee too, #56). A troop bought mid-wave marches in at that pace all
  /// the way, and one out of sight left of the view ([offViewBy]; once a fight was shown, less than [keepUpShift] −
  /// [offViewBy] inside it) walks up at it (#61, #85). Otherwise its own walk ([Unit.walkSpeed]).
  double speedTo(Unit u, Point<double> to) {
    final own = u.walkSpeed;
    if (u.side != Side.troop || (u.line == 2 && !meleeCatchUp) || !waveActive || to.x <= u.pos.x) return own;
    final melee = troops.where((o) => o.alive && o.entered && o.line == 2).toList();
    if (melee.isEmpty) return own;
    final fastest = min(min(catchUpMost * own, walkCap(u.type)), max(own, melee.map((o) => o.walkSpeed).reduce(max)));
    if (!u.entered || u.pos.x < cam + keepUpShift - offViewBy) return fastest; // bought mid-wave, or at the view's edge
    final fighting = melee.where((o) => t - o.attackedAt < _engagedFor);
    final rear = (fighting.isEmpty ? melee : fighting).map((o) => o.pos.x).reduce(min);
    return rear - u.pos.x <= (2 - u.line) * tile + _catchUp ? own : fastest;
  }

  /// The x a light melee [u] walking in doesn't pass: [paceLead] ahead of the foremost heavy-armored melee
  /// ([Unit.heavyArmor]) walking in, so the front doesn't run off from the heavies (#56). Null (no limit)
  /// for anyone else, while [u] is in the fight (it doesn't turn away, nor wait under fire), with no heavy
  /// walking in or one already in the fight, and before a wave or during the stall march ([marching]).
  double? paceLimit(Unit u) {
    if (!heavyPace || !waveActive || marching || u.side != Side.troop || u.line != 2 || Unit.heavyArmor.contains(u.type)) return null;
    if (!u.entered || _inFight(u)) return null;
    double? front;
    for (final o in troops) {
      if (!o.alive || !o.entered || !Unit.heavyArmor.contains(o.type)) continue;
      if (_inFight(o)) return null; // the heavies are in the fight
      if (!o.retreating) front = max(front ?? o.pos.x, o.pos.x);
    }
    return front == null ? null : front + paceLead;
  }

  /// How far a troop may walk mid-wave (decisions-log 324; the owner: "yang troops maju mundur ini mungkin batas maksimal
  /// maju adalah sejauh kanan kamera, jadi yang paling depan akan iddle atau attack saja tapi tida bisa maju lagi jika
  /// troops di belakang ada yang ketinggalan"): [capInset] inside the view's right edge. A troop whose way runs past it
  /// walks as far as the cap and stands there facing its foe, striking what it reaches; one already past it (the view
  /// went back) stands where it is: it never steps back for the cap ([_capWay]), and a shove doesn't push it past it.
  /// The view centres the fight (the owner: "battle harus tetap di tengah layar"), so the cap is a safety that seldom
  /// binds. Null (no cap) with [keepSupports] off, before a wave and after a win, and in the stall march ([marching]).
  double? get frontCap => keepSupports && waveActive && !marching ? cam + viewW - capInset : null;

  /// Troop [u]'s way to [to] cut at [frontCap]: the point on it level with the cap when it runs past it, where [u]
  /// stands when it is at or past the cap already; else [to].
  Point<double> _capWay(Unit u, Point<double> to) {
    final cap = u.side == Side.troop && u.entered ? frontCap : null;
    if (cap == null || to.x <= cap || to.x <= u.pos.x) return to;
    if (u.pos.x >= cap) return u.pos;
    return u.pos + (to - u.pos) * ((cap - u.pos.x) / (to.x - u.pos.x));
  }

  /// The back line or the view's left edge ([keepUpShift] inside it once the wave has shown a fight), whichever
  /// is further on: mid-wave the supports don't settle behind it (a healer's rest, a kiting archer), so they keep
  /// up with the view without being dragged (#61: the back line no longer follows the view; #85: the inset).
  /// #61's option A: with the back line not following the view (since #79 it stays put all wave), the supports keep up
  /// with the view themselves, and anyone at or past its left edge walks up at the catch-up pace ([speedTo]). #61's
  /// rule alone (option B, the back line only) left the rear out of sight in its A/B, and 40% more troops fell; its
  /// switch, always on, went in decisions-log 329.
  double get _rearEdge => max(baseX, cam + keepUpShift);

  /// [u] struck or was struck in the last [_engagedFor] s.
  bool _inFight(Unit u) => t - u.attackedAt < _engagedFor || t - u.hurtAt < _engagedFor;

  /// The living troops out of sight left of the view ([offViewBy]), for the UI's marker (off_view.dart).
  Iterable<Unit> get leftOfView => troops.where((u) => u.alive && u.pos.x < cam - offViewBy);

  /// [catchUp]: at [speedTo]'s pace (a troop heading for the fight or its spot), not its own. [kite]: backing off
  /// a foe while shooting, a step at a time, not a walk to anywhere: it neither finds its way round the others
  /// ([_steer]) nor counts as walking ([_walking]), so they may push it aside as before (#82).
  void _moveToward(Unit u, Point<double> to, double dt, {bool catchUp = false, bool kite = false}) {
    if (braced(u)) {
      u.moving = false;
      return;
    }
    if (u.side == Side.troop) to = _capWay(u, to); // mid-wave never past the view's right edge (decisions-log 324)
    final d = to - u.pos, len = d.magnitude;
    u.moving = len > 1;
    u.goal = to;
    if (!u.moving) {
      // A nudge this small snaps back rather than walking, which would make the neighbours give way
      // in turn and set the whole rank shuffling for good.
      u.pos = to;
      return;
    }
    final dir = d * (1 / len), speed = (catchUp ? speedTo(u, to) : u.walkSpeed) * _pace(u); // a slow ([Status.slow])
    final step = u.side == Side.troop && !kite ? _steer(u, dir, len, speed) : dir; // its way round the allies it meets
    final k = step.magnitude;
    u
      ..heading = k > 1e-9 ? step * (1 / k) : dir
      ..vel = step * speed
      ..walkedAt = kite ? u.walkedAt : t
      ..pos += step * min(len, speed * dt);
    _face(u, d.x, d.y);
  }

  /// [u] walked this tick or the last (units later in the update loop haven't had their turn yet): on its way
  /// somewhere, not carried, fighting or standing.
  bool _walking(Unit u) => u.moving && u.walkedAt >= t - _dt - 1e-9;

  /// [u] walks through its allies, and they through it: arriving at a new spot before a wave ([Unit.arriving]),
  /// or for a moment after walking too long without getting on ([Unit.throughUntil], [_watchStuck]).
  bool _ghost(Unit u) => u.arriving || t < u.throughUntil;

  /// The ways [_steer] tries, in order: a turn in degrees (toward the chosen side first, then the other) and
  /// the share of its speed it walks at.
  static const _ways = [(0, 1.0), (20, 1.0), (40, 1.0), (0, 0.75), (60, 1.0), (0, 0.5), (0, 0.25), (0, 0.0), (90, 1.0)];

  /// Troops find their way round the walking allies that go first ([_passes]) instead of into them (#82). A
  /// troop looks ahead, [_meetTime] s or until it gets there ([len] to go), at where it and each such ally within
  /// [_meetRange] are heading ([_clash]); one that would come within [_personalSpace] of it is met, unless both
  /// head for the same place (they close in, and [_personalSpace] keeps them apart there). It takes the first of
  /// [_ways] that stays clear of them all: straight on, bending more and more ([_passSide] of the nearest met:
  /// behind one crossing its way, else round it on the side away from it, or on its goal's side), slowing down,
  /// waiting, stepping aside; with none clear, the one that keeps the most room. Returns the step's direction
  /// times the share of its [speed] it walks at. Allies that aren't walking step aside themselves ([_makeWay]).
  /// That is between waves; in battle it only bends ([_bendRound]).
  Point<double> _steer(Unit u, Point<double> dir, double len, double speed) {
    if (_ghost(u)) return dir;
    if (waveActive) return _bendRound(u, dir, len);
    final near = <Unit>[], ahead = min(_meetTime, len / max(speed, 1e-6));
    Unit? first;
    for (final o in troops) {
      if (o == u || !o.alive || _ghost(o) || !_walking(o) || _passes(u, o) || _spotMates(u, o)) continue;
      final rel = o.pos - u.pos;
      if (rel.magnitude > _meetRange || (o.goal != null && u.goal!.distanceTo(o.goal!) < _personalSpace)) continue;
      near.add(o);
      if (_clash(rel, o.vel - dir * speed, ahead) < _personalSpace && (first == null || rel.magnitude < first.pos.distanceTo(u.pos))) first = o;
    }
    if (first == null) return dir;
    final side = _passSide(u, first, dir), perp = Point(-dir.y, dir.x);
    double room(Point<double> step) => near.fold(double.infinity, (m, o) => min(m, _clash(o.pos - u.pos, o.vel - step * speed, ahead)));
    var (best, most) = (dir, double.negativeInfinity);
    for (final (deg, share) in _ways) {
      for (final s in deg == 0 ? const [1.0] : [side, -side]) {
        final a = s * deg * pi / 180, step = (dir * cos(a) + perp * sin(a)) * share, r = room(step);
        if (r >= _personalSpace) return step;
        if (r > most) (best, most) = (step, r);
      }
    }
    return best;
  }

  /// [_steer] in battle: the nearest ally that goes first in the corridor ahead ([_lookAhead], or as far as it
  /// goes; [_personalSpace] each side) bends the heading to its far side, harder the closer it is (dead ahead,
  /// toward the middle lane), and it never slows down: on its way to the fight, a step held back is a blow later.
  /// Allies that give way are walked straight at; they step aside ([_makeWay]). (#82's probe: looking ahead and
  /// slowing down as between waves made the owner's waves 1.4 s longer.)
  Point<double> _bendRound(Unit u, Point<double> dir, double len) {
    Unit? block;
    var blockAlong = min(len, _lookAhead), blockLat = 0.0;
    for (final o in troops) {
      if (o == u || !o.alive || _ghost(o) || _passes(u, o) || _spotMates(u, o)) continue;
      final rel = o.pos - u.pos, along = rel.x * dir.x + rel.y * dir.y;
      final lat = dir.x * rel.y - dir.y * rel.x; // + : on the left of the heading
      if (along <= 0 || along >= blockAlong || lat.abs() >= _personalSpace) continue;
      (block, blockAlong, blockLat) = (o, along, lat);
    }
    if (block == null) return dir;
    final perp = Point(-dir.y, dir.x);
    final side = blockLat.abs() > 0.5 ? -blockLat.sign : (perp.y * (fieldH / 2 - u.pos.y) >= 0 ? 1.0 : -1.0);
    final bent = dir + perp * (side * (0.6 + 1 - blockAlong / _lookAhead));
    return bent * (1 / bent.magnitude);
  }

  /// How close an ally at [rel] from a troop comes to it in the next [ahead] s, [w] being the ally's velocity
  /// less the troop's: infinite when it isn't closing in.
  static double _clash(Point<double> rel, Point<double> w, double ahead) {
    final closing = -(rel.x * w.x + rel.y * w.y);
    if (closing <= 0) return double.infinity;
    return (rel + w * min(ahead, closing / (w.x * w.x + w.y * w.y))).magnitude;
  }

  /// Which way [u], walking along [dir], goes round the ally [o] that goes first: +1 toward dir's left normal
  /// (−dir.y, dir.x), −1 the other way. Behind [o] when [o] is crossing its way (where [o] has come from); head-on,
  /// alongside or with [o] still, on the side away from [o]; dead ahead, on its goal's side of [o]'s goal (the
  /// one whose goal is lower passes below), and level with it toward the middle lane.
  int _passSide(Unit u, Unit o, Point<double> dir) {
    final perp = Point(-dir.y, dir.x), rel = o.pos - u.pos, speed = o.vel.magnitude;
    double across(Point<double> p) => perp.x * p.x + perp.y * p.y;
    if (speed > 1e-6 && across(o.vel).abs() / speed > 0.34) return across(o.vel) > 0 ? -1 : 1;
    if (across(rel).abs() > 0.5) return across(rel) > 0 ? -1 : 1;
    final goals = across(u.goal! - (o.goal ?? o.pos));
    if (goals.abs() > 0.5) return goals > 0 ? 1 : -1;
    return perp.y * (fieldH / 2 - u.pos.y) >= 0 ? 1 : -1;
  }

  /// The stall detector (#82): a troop still more than half a tile from where it heads that walked this tick, or
  /// that stands aside on its way home between waves ([Unit.yieldUntil]), without getting on adds the tick to
  /// [Unit.stuckFor]; after [_stuckAfter] s of that it walks through its allies for [_throughFor] s ([_ghost]), so a
  /// jam holds nobody for good (nor do neighbours that keep sending it aside again). Getting on is, in battle,
  /// a quarter of its step along its way; between waves, heading for a spot that stays put, a quarter of its step
  /// nearer it than it has been yet on this walk ([Unit.closest]): pushed back and forth by one that keeps
  /// stepping back onto its own spot on the way, a troop got on now and then, so no tick-by-tick count ever reached
  /// the limit.
  void _watchStuck(Unit u, Point<double> from, double dt) {
    final aside = !waveActive && t < u.yieldUntil, walked = u.walkedAt == t && u.moving;
    final to = aside ? u.post : u.goal, d = to == null ? 0.0 : u.pos.distanceTo(to);
    if (!(aside || walked) || _ghost(u) || to == null || d <= tile / 2) {
      u
        ..stuckFor = 0
        ..closestTo = null;
      return;
    }
    final step = 0.25 * u.walkSpeed * _pace(u) * dt;
    final bool gotOn;
    if (waveActive) {
      final gone = u.pos - from;
      gotOn = walked && gone.x * u.heading.x + gone.y * u.heading.y >= step;
    } else {
      if (u.closestTo != to) {
        u
          ..closestTo = to
          ..closest = double.infinity;
      }
      gotOn = u.closest - d >= step - 1e-9;
      u.closest = min(u.closest, d);
    }
    if (gotOn) {
      u.stuckFor = 0;
      return;
    }
    if ((u.stuckFor += dt) < _stuckAfter) return;
    u
      ..stuckFor = 0
      ..throughUntil = t + _throughFor;
  }

  /// [u] takes [dmg] from [by] (when a fighter struck it, for the relics that answer a blow), less its defence
  /// ([hitTaken]); at most [cap] of its max HP when that is given (a monster skill's blow), and a troop whose type holds
  /// Dragon Crown at most [crownCap] of it; a troop's ward (heal.dart) soaks what is left before its HP does. [src]:
  /// where the blow comes from ([Hit]; every call names one, test/hit_source_test.dart). Returns the HP it took off (at
  /// most what [u] had; the Pusaka's counters read it). The Pusaka's Fx (pusaka_engine.dart) run from the books of [u]'s
  /// type and [by]'s: `pierce`,
  /// `struck`, `capped`, `dealt`, `hurtBy`, `lethal`, `fell` and `kill`; inside extra damage only `dealt`. A monster's
  /// one-hit mark (Ember Brand's, [Unit.emberMark]) is spent before its defence by a direct blow of another type. A
  /// monster's blow on a troop the Bayangan Executioner bares ([Omens._omenBare], read before the blow) skips the troop's
  /// shields, blocks and cuts; a silver or gold monster the Bayangan Deathless saves ([Omens._omenDeathless]) is left at
  /// 1 HP right after the blow, which then took only what it lost. A phantom ([isPhantom], Phantom Rush's swordsman while
  /// it dashes) takes nothing.
  double _hurt(Unit u, double dmg, Hit src, [Unit? by, double? cap]) {
    if (!u.alive) return 0;
    if (u.move != null && isPhantom(u)) return 0; // Phantom Rush: no blow lands on a phantom (awaken_skills.dart, decisions-log 320)
    final bare = omensOn && u.side == Side.troop && by?.side == Side.enemy && _omenBare(u); // Executioner (omen.dart)
    if (by != null && t < by.firstStrikeAt) by.firstStrikeAt = t; // its first blow ([Unit.firstStrikeAt])
    final heap = t < u.downUntil; // a heap of bones (Reassemble): only holy damage touches it, and ends it
    if (heap && !_holy) return 0;
    if (omensOn && src == Hit.normal && u.side == Side.enemy && by?.side == Side.troop && _omenDeflect(u)) return 0; // Deflect (omen.dart)
    if (by != null && by.relics.isNotEmpty && (src == Hit.normal || src == Hit.smite)) dmg *= _slayerK(by, u); // Giant Slayer (relics.dart)
    if (by != null && by.stats.darkK != 1 && u.stats.dark) dmg *= by.stats.darkK; // the torch's: its type's blows on the undead (decisions-log 251)
    if (by != null && by.stats.shotSpeed > 0) u.rangedHitAt = t; // for Shield Up (monster_skills.dart)
    final effects = u.effects.isNotEmpty || (by?.effects.isNotEmpty ?? false); // Hero skills' ([Status])
    final ub = pusaka.isEmpty ? null : _bookOf(u), bb = pusaka.isEmpty || by == null ? null : _bookOf(by); // the Pusaka's books
    if (effects) dmg = _beforeDefence(u, dmg, by, src);
    if (bb != null && u.side == Side.enemy && _fxDepth == 0) dmg = _fxPierce(bb, by!, u, dmg); // the attacker type's `pierce` Fx
    if (u.emberMark != null && by?.side == Side.troop) dmg = _fxEmber(u, by!, dmg, src); // a one-hit mark another type spends: Ember Brand
    if (omensOn && u.side == Side.troop && by?.side == Side.enemy) dmg = _omenDealt(u, dmg, src, by!); // the dealt cap (omen.dart)
    final raw = dmg;
    dmg = hitTaken(dmg, u.stats.def);
    if (ub != null) _fxDefence(ub, u, raw, dmg); // its type's `always` defence Fx's counter: Stone Coat
    final keep = _omenSunder(u); // the share of a troop's cuts the Bayangan Sunder leaves (omen.dart; 1 without it)
    if (u.holds(Relic.guard) && !bare) {
      final cut = guardCut * keep * _relicK(u); // stronger under Relic Altar, weaker under the Bayangan Rust (pusaka_engine.dart)
      _fxAltar(u, dmg * cut);
      dmg *= 1 - cut;
    }
    if (u.stats.taken != 1 && !bare) dmg *= 1 - (1 - u.stats.taken) * keep; // the forge's Cap and Helm (decisions-log 249)
    if (ub != null) {
      final d = _fxStruck(ub, u, by, dmg, src, bare: bare); // its type's `struck` Fx: Iron Banner
      if (d == null) return 0; // a blow that misses: Ghost Step
      dmg = d;
    }
    if (omensOn && u.side == Side.enemy) dmg *= _omenTaken(u, dmg, src, by); // the taken floor: Armor's cut and every Bayangan's (omen.dart)
    if (t < u.guardUntil && !(omensOn && u.guardOmen) && !bare) dmg *= 1 - u.guardCut * keep; // a skill's guard (Hold Fast, Holy Shield); a Bayangan's is in the floor
    if (effects) {
      if (_afterDefence(u, dmg, by, bare: bare) case final d?) {
        dmg = d;
      } else {
        return 0; // blocked
      }
    }
    if (cap != null) dmg = min(dmg, u.maxHp * cap); // a monster skill's blow ([monsterSkillCap])
    if (ub != null && !bare) dmg = _fxCapped(ub, u, by, dmg); // its type's `capped` Fx, after every cut: Dragon Crown
    if (heap) dmg = max(dmg, u.hp); // for good
    if (u.ward > 0 && !bare) dmg = _wardSoak(u, dmg, by); // a troop's ward breaks first (heal.dart)
    if (u.shield > 0) dmg = _shieldSoak(u, dmg); // a slot's Shield, the Bayangan's (omen.dart)
    if (by != null && by.relics.isNotEmpty && u.side == Side.enemy && dmg > 0 && dmg < u.hp && (src == Hit.normal || src == Hit.smite)) {
      dmg = _reap(by, u, dmg); // Reaper ends a monster it leaves low (relics.dart)
    }
    var dealt = min(dmg, u.hp);
    final hpBefore = u.hp;
    u.hp -= dmg;
    if (omensOn && u.hp <= 0 && u.side == Side.enemy && !heap && _omenDeathless(u, hpBefore)) dealt = hpBefore - u.hp; // Deathless: left at 1 HP (omen.dart)
    u
      ..hurtBefore = u.hurtAt
      ..hurtAt = t;
    if (u.side == Side.troop && !u.stats.heals) {
      u.hurtLog
        ..removeWhere((h) => t - h.$1 > retreatPolicy.brain.threatWindow)
        ..add((t, dealt));
    }
    if (pusaka.isNotEmpty) _fxCounters(u, by, ub, bb, dealt, hpBefore); // the Pusaka's counters, before a new mark
    if (by != null && by.side == Side.troop && u.side == Side.enemy && (u.weakMark != null || by.comboKey != null)) _relicDealt(u, by, dealt); // the forge's counters (relics.dart)
    if (by != null && by.alive) {
      if (by.holds(Relic.fang)) {
        _healTroop(by, dealt * fangShare * _relicK(by), HealSrc.fang); // more under Relic Altar, less under Rust (pusaka_engine.dart)
        _fxAltar(by, _healGained);
      }
      if (omensOn && u.side == Side.troop && by.side == Side.enemy) _omenFeed(by, dealt); // Feed (omen.dart)
      if (omensOn && u.side == Side.troop && by.side == Side.enemy && (src == Hit.normal || src == Hit.skill)) _omenManaBurn(u); // Mana Burn (omen.dart)
      if (omensOn && src == Hit.normal && u.side == Side.troop && by.side == Side.enemy && by.stats.melee) _omenSideSwing(u, by, raw); // Side Swing (omen.dart)
      if (_sapped && src == Hit.normal && u.side == Side.troop && u.hp > 0) _omenSap(u, by); // Sap: it deals less (omen.dart)
      if (omensOn && src == Hit.normal && u.side == Side.troop && u.hp > 0 && by.type == omenBatVenomType) _omenVenom(u, by); // Bat Venom: it bleeds (omen.dart)
      if (omensOn && (src == Hit.normal || src == Hit.skill) && u.side == Side.troop && u.hp > 0 && by.side == Side.enemy && //
          (by.tier == Tier.boss || by.tier == Tier.miniBoss)) {
        _omenBlight(u, by); // Blight: no heals on it for a while (omen.dart)
      }
      if (bb != null) _fxDealt(bb, by, u, dealt); // its type's `dealt` Fx, on top: Blood Fang, Void Eye's mark
      if (u.holds(Relic.thorns)) _fxAltar(u, _hurt(by, dmg * thornsShare * _relicK(u), Hit.hitBack)); // no [by]: thorns don't bounce back and forth
      if (omensOn && u.side == Side.enemy && by.side == Side.troop && by.stats.melee) _omenThorns(by, dmg); // Thorns (omen.dart)
      if (effects) _answer(u, dmg, dealt, by);
    }
    if (ub != null && _fxDepth == 0) _fxHurtBy(ub, u, by, dealt); // its type's `hurtBy` Fx
    if (ub != null && u.hp > 0) _fxStruckAfter(ub, u, by); // its type's `struck` heal once the blow landed: Hidden Flask
    if (u.hp > 0 && u.relics.isNotEmpty) _ironWill(u); // Iron Will, once a wave (relics.dart)
    if (omensOn && u.side == Side.enemy && u.hp > 0) _omenBelow(u); // Second Skin, Last Rage, Muster, Last Gasp: under a line once (omen.dart)
    if (u.hp <= 0 && ub != null) _fxLethal(ub, u, by); // its type's `lethal` Fx: the Grail, once a wave
    if (u.hp <= 0 && _reassembles(u)) return dealt; // Reassemble (monster_skill_signatures.dart)
    if (u.hp > 0) return dealt;
    u.dying = 0;
    if (u.side == Side.enemy) {
      gold += _boostGold(_omenGold(u.stats.cost)); // less under the Bayangan Thrift (omen.dart), more under a Tavern boost (tavern.dart)
      _plunder(u);
      kills++;
      if (u.stats.cost > 0) score += killScore[u.tier]!; // not the raised skeletons, like their gold
      sfx.add(Sfx.kill);
      if (omensOn && _fxDepth == 0) _omenCloseRanks(u); // Close Ranks: a guard on the monsters next to it, before the kill Fx (omen.dart)
      if (bb != null && _fxDepth == 0) _fxKill(bb, by!, u, raw); // the killer type's `kill` Fx (Funeral Pyre's burst: of the blow before defence)
      if (omensOn) _omenAvenge(u); // Avenge: a might on the monsters next to it (omen.dart)
      if (omensOn) _omenPartingGift(u); // Parting Gift: the monsters near it heal (omen.dart)
      if (omensOn) _omenBile(u); // Bile Sacs: a slime hurts the troops next to it (omen.dart)
      if (omensOn && by?.side == Side.troop) _omenKill(by!); // Grudge's tally of the wave's kills by type (omen.dart)
      if (by != null && by.side == Side.troop && by.relics.isNotEmpty) _relicKill(by); // Hot Streak's stack (relics.dart)
      _monsterFell(u); // a slime mini boss's Split, a grave for Grave Call (boss_skills.dart)
      if (omensOn && by?.side == Side.troop) _omenToll(by!); // Toll: the killer pays a share of its HP (omen.dart)
      // The loot dice roll as when items and relics fell here: the wave's boss and mini boss (whatever their type) draw
      // their items, a raised mini boss only rolls, and every monster not raised rolls a relic. Nothing drops (the Smithy
      // makes items and relics, decisions-log 221, 246), but each draw is still made and thrown away, so the [loot] dice
      // stay where they were (decisions-log 321).
      final isBoss = u.tier == Tier.boss;
      if (isBoss || (u.tier == Tier.miniBoss && u.raisedBy == null)) {
        for (var i = 0; i < (isBoss ? bossDrops : 1); i++) {
          loot.nextInt(droppedItemKinds);
        }
      } else if (loot.nextDouble() < dropChance) {
        loot.nextInt(droppedItemKinds);
      }
      if (u.raisedBy == null && loot.nextDouble() < relicChance[u.tier]!) loot.nextInt(droppedRelics.length);
      if (u.raisedBy == null) _dropMaterials(u); // town.dart: its type's part by its rank, on [matDice]
    } else {
      final back = [...u.relics];
      for (final r in back) {
        relicBag[r] = (relicBag[r] ?? 0) + 1; // a Hero's both
        relicsBack[r] = (relicsBack[r] ?? 0) + 1;
      }
      u.relics.clear();
      fallen.add(u);
      _autoFell(u); // Auto queues it to buy back (auto_replace.dart)
      if (u.hero) fallenHeroes.add(FallenHero.of(u, wave)); // "Hero Gugur" keeps it to call back (recall.dart)
      _emit(TroopFell(wave, t, name: u.name, type: u.type, hero: u.hero, killer: by?.type, killerTier: by?.tier, relics: back));
      if (ub != null) _fxFell(ub, u, by); // its type's `fell` Fx: Mourning Bell heals those near
      if (omensOn && by != null) _omenGloat(by); // Gloat: the monster that killed it heals (omen.dart)
      if (omensOn && by != null) _omenSpreeKill(by); // Spree: a silver or gold killer counts it (omen.dart)
      if (omensOn) _omenTriumph(u); // Triumph: the monsters near it attack faster (omen.dart)
      if (u.hero) _refitTroops(); // its aura ends, unless another Hero lives
      sfx.add(Sfx.fall); // the last one too: [Wipe._wipe] adds the lose
    }
    return dealt;
  }

  /// A healer mid-cast ([healCast] since it started a heal, or the healing necromancer a swing).
  bool _casting(Unit u) => u.stats.heals && t - u.attackedAt < healCast;

  /// Holds its ground when shoved and doesn't step aside: a healer mid-cast, a carried or braced unit
  /// ([_held], hero_moves.dart), or a unit under [Status.noShove]. Against another troop ([troop]: making way) not under
  /// one it gave itself, Anchor's stand against the monsters for the whole wave (pusaka_engine.dart), so a type that
  /// holds it still makes way for the others and never piles up on one spot.
  bool _firm(Unit u, {bool troop = false}) {
    if (_casting(u) || _held(u)) return true;
    final stand = u.effects.isEmpty ? null : effectOn(u, Status.noShove);
    return stand != null && !(troop && stand.by == u);
  }

  /// The HP one heal of [u] restores: its [Stats.dmg].
  double _healOf(Unit u) => u.stats.dmg;

  /// [u] heals [o] by [_healOf] (never past full; a troop through the heal funnel, heal.dart) and starts its cast; a
  /// troop healer pays [healMp] MP for it (a healing necromancer has paid its own, [necroHealCost]); a monster's heal
  /// opens [o]'s window.
  void _castHeal(Unit u, Unit o) {
    u
      ..cd = attackEvery(u)
      ..attackedAt = t
      ..swung = false;
    if (u.side == Side.troop) u.mp = max(0.0, u.mp - healMp);
    final heal = _healOf(u);
    final past = _healUnit(o, heal, HealSrc.heal); // a troop's through the funnel (heal.dart)
    o.healedAt = t;
    if (u.side == Side.enemy) _openHealWindow(u, o);
    if (u.side == Side.troop && pusaka.isNotEmpty) _fxHealed(u, o, _healGained, heal, past); // Dawn Star's counter, the `heals` Fx
    if (u.relics.isNotEmpty) _relicHealed(u); // Mana Siphon (relics.dart)
    impacts.add((o.pos, _fxOf(u, 'heal')));
    sfx.add(_attackSfx[u.type]!);
  }

  /// Whether monster [o] is inside another healer's heal window ([healWindow]), so no heal of healer [u]'s
  /// lands on it (its own next one comes when the window ends anyway).
  bool _healWindowed(Unit o, Unit u) => t < o.healedUntil && o.healedBy != u;

  /// Healer [u] healed monster [o]: no other healer's heal lands on it for [healWindow]× [u]'s heal interval.
  void _openHealWindow(Unit u, Unit o) => o
    ..healedUntil = t + attackEvery(u) * healWindow
    ..healedBy = u;

  /// Troop [u]'s skills, one cast a tick: a Hero's own first, then its #10 skill, then its type's awakening skill
  /// (awaken_skills.dart). Each step says whether it cast. None for a type under Vow of Silence ([FxEngine._fxSilent]).
  void _trySkill(Unit u) {
    if (_fxSilent(u)) return;
    final hero = u.heroSkill != null && heroSkills;
    if (hero && _tryHeroSkill(u)) return; // a Hero's own skill first
    if (skills && _tryTroopSkill(u, hero)) return;
    if (awakenSkills) _tryAwakenSkill(u, hero);
  }

  /// Troop [u] casts its skill ([troopSkills]) when its rule holds ([wantsSkill]), it has the MP and its
  /// cooldown has passed since its last one, unless a skill that comes before it on the MP wants that MP: a Hero's
  /// own ([_savingUp]) or its awakening skill ([_savingForAwaken]).
  bool _tryTroopSkill(Unit u, bool hero) {
    final s = troopSkills[u.type];
    if (s == null) return false;
    final cost = skillCost(u, s.cost); // more under the Bayangan Spell Tax (omen.dart)
    if (u.mp < cost || t - u.skillAt < skillCd(s.cooldown) || !wantsSkill(u)) return false; // sooner under Oath of Spells (pusaka.dart)
    if (hero && _savingUp(u)) return false; // its own skill is ready and wanted, only short of MP: that first
    if (_savingForAwaken(u, cost)) return false; // its awakening skill is ready and wanted: it has the MP first
    u
      ..mp -= cost
      ..skillAt = t;
    casts.add(u);
    _emit(SkillCast(wave, t, name: u.name, type: u.type, skill: s.name));
    _windUp(u, WindKind.troop, troopSkillStrips[u.type]); // its strip's wind-up, then it lands (skill_strips.dart)
    return true;
  }

  /// [u] begins a skill's [strip] now, its blow at [strikeAt] (by default as its frames from [SkillStrip.entry] take):
  /// what the UI plays ([Unit.skillAnim], skill_strips.dart). Nothing in the fight reads it.
  void _playStrip(Unit u, SkillStrip? strip, [double? strikeAt]) {
    if (strip != null) u.skillAnim = (strip: strip, from: t, strikeAt: strikeAt ?? t + (strip.strike - strip.entry) / skillStripFps);
  }

  /// Living monsters on the field within [r] of [p], nearest first.
  List<Unit> _foesNear(Point<double> p, double r) =>
      [for (final o in enemies) if (o.alive && o.entered && o.pos.distanceTo(p) <= r) o]
        ..sort((a, b) => a.pos.distanceTo(p).compareTo(b.pos.distanceTo(p)));

  /// The living unit of [side] nearest [at] within [landReach], which a shot whose target went takes as its target where
  /// it lands ([Shot.to], decisions-log 327), or null when none stands there.
  Unit? _standingOn(Point<double> at, Side side) {
    Unit? on;
    var best = landReach;
    for (final o in units) {
      if (o.side != side || !o.alive) continue;
      final d = o.pos.distanceTo(at);
      if (d <= best && (on == null || d < best)) (on, best) = (o, d);
    }
    return on;
  }

  /// Living troops on the field within [r] of [p].
  List<Unit> _alliesNear(Point<double> p, double r) =>
      [for (final o in troops) if (o.alive && o.entered && o.pos.distanceTo(p) <= r) o];

  /// Who Piercing Thrust hits: [target] and every foe up to [pierce].depth behind it (further from the
  /// lancer [u]) within [pierce].lane of its lane.
  List<Unit> _pierced(Unit u, Unit target) {
    final dir = target.pos.x >= u.pos.x ? 1 : -1;
    return [
      for (final o in enemies)
        if (o.alive && o.entered && (o.pos.y - target.pos.y).abs() <= pierce.lane)
          if ((o.pos.x - target.pos.x) * dir case final behind when behind >= 0 && behind <= pierce.depth) o,
    ];
  }

  /// The most hurt troop the priest [u] can reach, for Healing Prayer (one at its heal ceiling isn't hurt: Scar's,
  /// [Omens.healCeil]).
  Unit? _mostHurt(Unit u) {
    Unit? worst;
    for (final o in troops) {
      if (!o.alive || o.hp >= healCeil(o) || o.pos.distanceTo(u.pos) > u.stats.range) continue;
      if (worst == null || o.hp / o.maxHp < worst.hp / worst.maxHp) worst = o;
    }
    return worst;
  }

  /// [o] takes [cut] less damage for [time] s, its guard ring in [look]'s colour (null: the pale blue); a stronger
  /// guard it already holds stays until it ends. Whether it took.
  bool _guard(Unit o, double cut, double time, [RingLook? look]) {
    if (t < o.guardUntil && o.guardCut > cut) return false;
    o
      ..guardCut = cut
      ..guardUntil = t + time
      ..guardLook = look
      ..guardOmen = false; // a Bayangan's guard sets it after
    return true;
  }

  /// How far apart [u]'s attacks (and heals) are now: its rate, [frenzy].rate of it while Rampage lasts, less
  /// under a haste and more under a monster's Screech ([Status.daze]), but never under [minAttackInterval]
  /// ([bossMinAttackInterval] for the wave's boss).
  double attackEvery(Unit u) => max(u.side == Side.enemy && u.tier == Tier.boss ? bossMinAttackInterval : minAttackInterval,
      u.stats.rate * (t < u.frenzyUntil ? frenzy.rate : 1) * (u.effects.isEmpty ? 1 : effectK(u, Status.haste) * effectK(u, Status.daze)));

  /// Whether troop [u]'s skill ([troopSkills]) has a target now (MP and cooldown aside; decisions-log 298: no crowd and no
  /// low HP needed, a target is enough). It changes nothing (a wind-up's land asks it again).
  bool wantsSkill(Unit u) {
    final nearest = _nearestFoe(u);
    final foe = nearest != null && nearest.entered && nearest.pos.distanceTo(u.pos) <= u.stats.range ? nearest : null; // in reach
    switch (u.type) {
      case 'soldier':
        return foe != null && (t >= u.guardUntil || u.guardCut < guardSelf.cut); // not guarded, or only by a weaker Holy Shield
      case 'knight':
        return _foesNear(u.pos, slash.reach).isNotEmpty;
      case 'swordsman':
        return foe != null && t >= u.frenzyUntil;
      case 'archer':
        return _foesNear(u.pos, u.stats.range).isNotEmpty;
      case 'lancer' || 'wizard':
        return foe != null;
      case 'priest':
        final worst = _mostHurt(u);
        if (worst == null || worst.hp >= worst.maxHp * prayer.hurt) return false;
        return _alliesNear(worst.pos, prayer.reach).where((o) => o.hp < o.maxHp * prayer.hurt).length >= prayer.crowd;
      case 'armored_axeman':
        return _foesNear(u.pos, slam.reach).isNotEmpty;
      case 'knight_templar':
        bool open(Unit o) => t >= o.guardUntil || o.guardCut < ward.cut; // not guarded that strongly yet
        return _alliesNear(u.pos, ward.reach).any((o) => open(o) && t - o.attackedAt < _engagedFor);
    }
    return false;
  }

  /// What troop [u]'s skill does ([troopSkills]; the constants beside it hold the numbers). Each shows a look of
  /// its own (#81): a [Ring], [Beam] or show-only [Zone] ([skillLook]), drawn by lib/skills.dart.
  void _castSkill(Unit u) {
    final foe = _nearestFoe(u), dmg = u.stats.dmg;
    switch (u.type) {
      case 'soldier': // Hold Fast
        _guard(u, guardSelf.cut, guardSelf.time, RingLook.brace);
        rings.add(Ring.over(u, radius: 12, since: t, look: RingLook.brace, duration: skillLook.brace));
        sfx.add(Sfx.magic);
      case 'knight': // Circle Slash
        rings.add(Ring.over(u, radius: slash.reach, since: t, look: RingLook.slash, duration: skillLook.slash));
        for (final o in _foesNear(u.pos, slash.reach)) {
          impacts.add((o.pos, _fxOf(u, 'hit_knight')));
          _hurt(o, dmg * slash.hit, Hit.skill, u);
        }
        sfx.add(Sfx.sword);
      case 'swordsman': // Rampage
        u.frenzyUntil = t + frenzy.time;
        rings.add(Ring.over(u, radius: 18, since: t, look: RingLook.rage, duration: skillLook.rage));
        sfx.add(Sfx.magic);
      case 'archer': // Arrow Rain
        final targets = _foesNear(u.pos, u.stats.range).take(volleyArrows).toList();
        for (final o in targets) {
          shots.add(Shot(u, o, u.pos + const Point(0, -6), Hit.skill));
        }
        zones.add(_volley(u, targets));
        sfx.add(Sfx.dagger);
      case 'lancer': // Piercing Thrust
        final dir = foe!.pos.x >= u.pos.x ? 1 : -1; // as [_pierced] reads it
        beams.add(Beam([u.pos, foe.pos + Point(dir * pierce.depth, 0.0)], since: t, duration: skillLook.thrust, look: BeamLook.thrust));
        for (final o in _pierced(u, foe)) {
          impacts.add((o.pos, _fxOf(u, 'hit_lancer')));
          _hurt(o, dmg * pierce.hit, Hit.skill, u);
        }
        sfx.add(Sfx.sword);
      case 'priest': // Healing Prayer
        final worst = _mostHurt(u)!;
        rings.add(Ring(worst.pos, radius: prayer.reach, since: t, look: RingLook.prayer));
        for (final o in _alliesNear(worst.pos, prayer.reach)) {
          if (o.hp >= healCeil(o)) continue; // at its heal ceiling (Scar's, omen.dart)
          final heal = _healOf(u) * prayer.heal;
          final past = _healTroop(o, heal, HealSrc.prayer);
          o.healedAt = t;
          if (pusaka.isNotEmpty) _fxHealed(u, o, _healGained, heal, past); // Dawn Star's counter, the `heals` Fx
          impacts.add((o.pos, _fxOf(u, 'heal')));
          rings.add(Ring.over(o, radius: 6, since: t, look: RingLook.pillar, duration: skillLook.pillar));
        }
        sfx.add(Sfx.magic);
      case 'armored_axeman': // Crushing Blow
        rings.add(Ring(u.pos, radius: slam.reach, since: t, look: RingLook.crack, duration: skillLook.crack));
        for (final o in _foesNear(u.pos, slam.reach)) {
          impacts.add((o.pos, _fxOf(u, 'hit_armored_axeman')));
          _hurt(o, dmg * slam.hit, Hit.skill, u);
          _stunFor(o, slam.stun); // never the boss rank or the necromancer, a mini boss half as long (#88)
        }
        sfx.add(Sfx.sword);
      case 'wizard': // Arcane Blast
        shots.add(Shot(u, foe!, u.pos + const Point(0, -6), Hit.skill, dmg * blast.hit, blast.splash, true, RingLook.arcane));
        sfx.add(Sfx.magic);
      case 'knight_templar': // Holy Shield
        rings.add(Ring(u.pos, radius: ward.reach, since: t, look: RingLook.holy));
        for (final o in _alliesNear(u.pos, ward.reach)) {
          if (_guard(o, ward.cut, ward.time, RingLook.holy)) {
            rings.add(Ring.over(o, radius: 9, since: t, look: RingLook.dome, duration: skillLook.dome));
          }
        }
        sfx.add(Sfx.magic);
    }
  }

  /// Arrow Rain's look ([ZoneLook.volley]): a zone that only shows, over archer [u]'s [targets], its arrows
  /// falling into it for [skillLook].volley s.
  Zone _volley(Unit u, List<Unit> targets) {
    final at = targets.map((o) => o.pos).reduce((a, b) => a + b) * (1 / targets.length);
    final reach = targets.map((o) => o.pos.distanceTo(at)).reduce(max) + tile / 2;
    return Zone(u, at, since: t, duration: skillLook.volley, radius: max(reach, tile), side: Side.enemy, look: ZoneLook.volley);
  }

  /// [u], a troop healer, "heals" the dark monster [o] and starts its cast: holy light that takes
  /// [holyShare] of the heal off instead, a blow like any other (gold, loot, the relics that answer one).
  void _smite(Unit u, Unit o) {
    u
      ..cd = attackEvery(u)
      ..attackedAt = t
      ..swung = false;
    impacts.add((o.pos, 'holy')); // the heal burst in holy colours, whatever the healer's awakening
    var dmg = _healOf(u) * holyShare * _blowK(u, _healOf(u) * holyShare, o);
    if (u.relics.isNotEmpty) dmg *= _relicBlowK(u, o, dmg); // the forge's nine, under the relics' cap (relics.dart)
    _holyHurt(o, dmg, u, Hit.smite);
    if (u.relics.isNotEmpty) _relicLanded(u, o, dmg, Hit.smite); // Mana Siphon (relics.dart)
    sfx.add(Sfx.hit);
  }

  /// Mid-battle a troop healer keeps to the back line: it follows the army a tile behind the rearmost
  /// fighter, but never more than [healBehind] behind the rearmost melee in the fight (decisions-log 324), and never
  /// steps past that line. From there it patches up the most hurt ally it can reach, for [healMp]
  /// MP a heal (decisions-log 297); with nobody to heal, or short of the MP ([healMp], or what a skill of its that is
  /// ready and has a target needs first: [_healWaits]), it smites the weakest dark monster already in its range
  /// ([_smite]), never stepping up for one, or waits. More than a tile behind that line it walks up first, healing only
  /// one falling back or at [retreatAt] of its HP or less on the way (decisions-log 324). The first heal that finds it
  /// short of [healMp] pops "No MP" over it ([noMp]), once until it has the MP again.
  void _heal(Unit u, double dt) {
    final all = troops.where((o) => o.alive && !o.stats.heals).toList();
    // Once the fighting has started, only those in it count: a fresh troop dropped at the back mid-battle
    // doesn't pull the healers back while it walks up.
    final engaged = all.where((o) => t - o.attackedAt < _engagedFor).toList();
    final fighters = engaged.isEmpty ? all : engaged;
    final melee = fighters.where((o) => o.line == 2).map((o) => o.pos.x);
    // It waits a tile behind the rearmost fighter. To heal it may go up as far as it takes to reach the
    // melee line (the long range stand back at their own reach, so from behind them it could never heal
    // the front), and once nobody needs it, it falls back again.
    // With [keepSupports] (decisions-log 324) never more than [healBehind] behind the rearmost melee of those, so it
    // follows the melee rather than the long range standing back at their hold.
    final front = [for (final o in fighters) if (o.line == 2 && !o.retreating) o.pos.x];
    final behind = keepSupports && front.isNotEmpty ? front.reduce(min) - healBehind : double.negativeInfinity;
    final rest = fighters.isEmpty ? double.infinity : max(max(_rearEdge + tile / 2, fighters.map((o) => o.pos.x).reduce(min) - tile), behind);
    final limit = melee.isEmpty ? rest : max(rest, melee.reduce(min) - u.stats.range * 0.8);
    // Troops falling back to be healed first, then the most hurt.
    bool before(Unit a, Unit b) => a.retreating != b.retreating ? a.retreating : a.hp / a.maxHp < b.hp / b.maxHp;
    Unit? worst;
    for (final o in troops) {
      if (!o.alive || o.hp >= healCeil(o) || o.pos.x - limit > u.stats.range * 0.9) continue; // at its heal ceiling: Scar's (omen.dart)
      if (worst == null || before(o, worst)) worst = o;
    }
    if (u.dry && u.mp >= healMp) u.dry = false;
    // Its smite: the weakest dark monster already in its range, when its cast is due.
    bool smote() {
      Unit? dark;
      for (final o in enemies) {
        if (!o.alive || !o.stats.dark || o.pos.distanceTo(u.pos) > u.stats.range) continue;
        if (dark == null || o.hp < dark.hp) dark = o;
      }
      if (dark == null || u.cd > 0) return false;
      u.moving = false;
      _face(u, dark.pos.x - u.pos.x, 0);
      _smite(u, dark);
      return true;
    }

    // Out of sight left of the view (decisions-log 312), it walks up into it before it heals or smites, so no heal of its
    // comes from off the screen (a Hero priest's ×3 reach healed the whole field from the back line, never seen).
    final away = keepSupports && fighters.isNotEmpty && u.pos.x < cam + keepUpShift - offViewBy;
    // More than a tile behind its rest (decisions-log 324) it walks up first: it stops only to heal one falling back or
    // at [retreatAt] of its HP or less, and not to smite. A heal holds it [healCast] s, so stopping for every one left the
    // healers 6 to 9 tiles behind a melee that walks on as the view centres the fight.
    final lagging = keepSupports && fighters.isNotEmpty && u.pos.x < rest - tile;
    if (lagging && worst != null && !worst.retreating && worst.hp > worst.maxHp * retreatAt) worst = null;
    if (worst == null || away) {
      if (!away && !lagging && smote()) return;
      if (fighters.isEmpty) return _rest(u, dt);
      // Back to the rear, keeping up with the army; the healers spread a lane apart around its middle
      // so they don't all head for the same spot, top to bottom as they stand, so none crosses another's way (#82).
      final healers = troops.where((o) => o.alive && o.stats.heals).toList()..sort(_topDown);
      final mid = fighters.map((o) => o.pos.y).reduce((a, b) => a + b) / fighters.length;
      final y = (mid + (healers.indexOf(u) - (healers.length - 1) / 2) * tile).clamp(tile / 2, fieldH - tile / 2);
      _moveToward(u, Point(rest, y), dt, catchUp: true);
      if (!u.moving) u.dir = 1;
    } else if (worst.pos.distanceTo(u.pos) > u.stats.range) {
      _moveToward(u, Point(min(worst.pos.x, limit), worst.pos.y), dt, catchUp: true);
    } else if (keepSupports && fighters.isNotEmpty && u.pos.x < rest - tile && (u.cd > 0 || u.mp < healMp || _healWaits(u))) {
      // One left behind the army walks up behind it whenever no heal of its is due (decisions-log 312, 324): between
      // heals, short of the MP or saving it for a skill. A long reach (a Hero priest's) healed the field from where it
      // stood, and a healer short of MP stood there too, so the healers fell behind the melee and off the screen.
      if (u.cd <= 0 && u.mp < healMp) {
        if (!u.dry) {
          u.dry = true;
          noMp.add(u);
        }
        if (smote()) return;
      }
      _moveToward(u, Point(rest, u.pos.y), dt, catchUp: true);
    } else if (u.cd <= 0 && (u.mp < healMp || _healWaits(u))) {
      // Short of the MP (decisions-log 297): no heal. A smite costs nothing; else it waits where it stands.
      if (u.mp < healMp && !u.dry) {
        u.dry = true;
        noMp.add(u);
      }
      if (smote()) return;
      u.moving = false;
      _face(u, worst.pos.x - u.pos.x, 0);
    } else {
      u.moving = false;
      _face(u, worst.pos.x - u.pos.x, 0);
      if (u.cd <= 0) _castHeal(u, worst);
    }
  }

  /// Troop healer [u]'s heal waits for a skill of its (decisions-log 297: "skill first, heals use the rest"): its Hero
  /// skill ([HeroSkills._savingUp]), its awakening skill ([AwakenSkills._savingForAwaken]) or its #10 skill is ready
  /// and has a target, and the MP a heal would leave doesn't pay for it.
  bool _healWaits(Unit u) {
    if (_fxSilent(u)) return false; // no skill under Vow of Silence (pusaka_engine.dart)
    if (u.heroSkill != null && heroSkills && _savingUp(u, healMp)) return true;
    if (awakenSkills && _savingForAwaken(u, healMp)) return true;
    final s = skills ? troopSkills[u.type] : null;
    return s != null && t - u.skillAt >= skillCd(s.cooldown) && u.mp - healMp < skillCost(u, s.cost) && wantsSkill(u);
  }

  /// The healing necromancer ([necroHealer]) supports from the very back. It waits a tile behind the
  /// rearmost monster, keeps [necroSafety] outside every troop's reach (backing off when one comes
  /// closer), and steps up only as far as it takes to get the most hurt monster it can safely reach
  /// within its heal range, then falls back; each heal costs [necroHealCost] MP. A monster another healer
  /// has just healed is skipped for the next most hurt ([healWindow]). When it can't heal (short
  /// of MP, or nobody it can safely reach is hurt) it swings its scythe at a troop within reach
  /// ([necroSwing]); it never goes looking for a fight. Left alone it walks on like any monster.
  /// An escort's healer ([Unit.escortOf], #90) heals its mini boss or boss first whenever it may, and waits a
  /// tile behind it rather than behind the rearmost monster; by its boss only melee troops keep it away
  /// ([escortMeleeOnly]). Once its boss falls it is like any other.
  /// Its choices stick ([Unit.mend], decisions-log 314): a back-off goes on until it is [mendClear] clear, the spots it
  /// walks to are that clear and so is the way there, and a monster it walks to heal is kept [mendCommit] s. A troop
  /// whose reach takes in the whole edge it may back off to (a late archer's) doesn't count: it can't get away from
  /// it, so it heals under its fire. Cornered, it holds and heals only what it reaches from there.
  void _mend(Unit u, double dt) {
    // Troop healers only smite, and only when none of theirs is hurt: it doesn't keep out of their reach.
    final hitters = troops.where((o) => o.alive && o.entered && !o.stats.heals).toList();
    // The furthest right it may go: the view's right limit, or where it stands while it hasn't come on yet (#85).
    final edge = max(rightLimit, u.pos.x);
    // The troops it keeps from: those it can get out of the reach (+ [necroSafety]) of. One that reaches both ends of
    // that edge reaches every spot it may stand on (a late army's archers: 600-1200 px), so backing off from it only
    // pinned it at the edge, in its reach anyway, with the hurt monsters left unhealed (decisions-log 314).
    final keep = [
      for (final o in hitters)
        if (max(o.pos.distanceTo(Point(edge, tile / 2)), o.pos.distanceTo(Point(edge, fieldH - tile / 2))) > o.stats.range + necroSafety) o,
    ];
    // An escort's healer, its boss alive: by its boss (and backing off) only the melee troops count
    // ([escortMeleeOnly], #90).
    final lead = u.escortOf?.alive == true ? u.escortOf : null;
    final feared = lead != null && escortMeleeOnly ? keep.where((o) => o.line == 2).toList() : keep;
    // How far [p] is inside the reach (plus the margin) of the troop of [from] that reaches furthest into it; > 0
    // is too close.
    double reachInto(List<Unit> from, Point<double> p) =>
        from.fold(double.negativeInfinity, (d, o) => max(d, o.stats.range + necroSafety - o.pos.distanceTo(p)));
    // Whether the walk from here to [p] keeps out of [from]'s reach (+ the margin), looked at a tile at a time.
    bool clearWay(List<Unit> from, Point<double> p) {
      final n = (u.pos.distanceTo(p) / tile).ceil();
      for (var i = 1; i < n; i++) {
        if (reachInto(from, u.pos + (p - u.pos) * (i / n)) > 0) return false;
      }
      return true;
    }

    void act(Mend m, [Unit? on]) {
      if (u.mend != m || u.mendOn != on) {
        u
          ..mend = m
          ..mendAt = t
          ..mendOn = on;
      }
    }

    // Backing off starts when a troop reaches into its margin and goes on until it is [mendClear] clear.
    final backing = reachInto(feared, u.pos) > (u.mend == Mend.backOff ? -mendClear : 0);
    // Where it backs off to: a tile away from the troop that reaches furthest into its margin, but never further right
    // than [edge]: a troop that reaches far enough would otherwise chase it off the screen, and the fight it heals
    // after it, and the wave never ends (#85). Held there, it goes along the edge, up or down away from the troop.
    // Null when it can't: cornered.
    Point<double>? backTo() {
      final o = feared.reduce((a, b) => a.stats.range - a.pos.distanceTo(u.pos) >= b.stats.range - b.pos.distanceTo(u.pos) ? a : b);
      final away = u.pos - o.pos, len = away.magnitude;
      var to = u.pos + (len < 0.01 ? const Point(1.0, 0.0) : away * (1 / len)) * tile;
      if (to.x > edge) to = Point(edge, u.pos.y + (away.y.abs() > 0.01 ? away.y.sign : (u.pos.y < fieldH / 2 ? 1 : -1)) * tile);
      to = Point(to.x, to.y.clamp(tile / 2, fieldH - tile / 2));
      return to.distanceTo(u.pos) > tile / 4 ? to : null;
    }

    final back = backing ? backTo() : null, cornered = backing && back == null;
    // Where it heals [o] from: here, if [o] is in range and its heal is ready, or it isn't too close here, or it has
    // nowhere to go. Else on the ring at 0.9 × its range round [o], straight on its way first, then turned
    // ([mendTurns]): the first [slack] outside the reach of the troops it keeps from, with the way there clear. Its own
    // boss from behind it, never past it, where no melee troop reaches ([escortMeleeOnly]).
    Point<double>? spotFor(Unit o, double slack) {
      final d = o.pos.distanceTo(u.pos);
      if (d <= u.stats.range && (u.cd <= 0 || !backing || cornered)) return u.pos;
      if (cornered) return null;
      final from = o == lead ? feared : keep, way = (u.pos - o.pos) * (1 / max(d, 0.01));
      for (final turn in mendTurns) {
        final c = cos(turn * pi / 180), s = sin(turn * pi / 180);
        final spot = o.pos + Point(way.x * c - way.y * s, way.x * s + way.y * c) * (u.stats.range * 0.9);
        if (spot.x > edge || spot.y < tile / 2 || spot.y > fieldH - tile / 2 || (o == lead && spot.x < o.pos.x)) continue;
        if (reachInto(from, spot) <= -slack && clearWay(from, spot)) return spot;
      }
      return null;
    }

    // The one it heals: its own boss first (an escort's healer, #90), then the one it walks to heal already (for
    // [mendCommit] s), then the most hurt. A new one's heal spot must be [mendClear] clear, the one it is on the margin.
    Unit? worst;
    Point<double>? spot;
    if (u.mp >= necroHealCost) {
      final on = u.mend == Mend.toHeal || u.mend == Mend.heal ? u.mendOn : null;
      double slackOf(Unit o) => o == on ? 0 : mendClear;
      Point<double>? may(Unit o) => o.alive && o.hp < o.maxHp && !_healWindowed(o, u) ? spotFor(o, slackOf(o)) : null;
      if (lead != null) (worst, spot) = (lead, may(lead));
      if (spot == null && on != null && t - u.mendAt < mendCommit) (worst, spot) = (on, may(on));
      if (spot == null) {
        worst = null;
        final hurt = [
          for (final o in enemies)
            if (o.alive && o.hp < o.maxHp && !_healWindowed(o, u)) o,
        ]..sort((a, b) => a.hp / a.maxHp != b.hp / b.maxHp ? (a.hp / a.maxHp).compareTo(b.hp / b.maxHp) : a.id.compareTo(b.id));
        for (final o in hurt) {
          if (spotFor(o, slackOf(o)) case final s?) {
            (worst, spot) = (o, s);
            break;
          }
        }
      }
    }
    if (worst != null && spot != null) {
      if (spot == u.pos) {
        act(Mend.heal, worst);
        u.moving = false;
        _face(u, worst.pos.x - u.pos.x, 0);
        if (u.cd > 0) return; // waiting out its heal's interval
        u.mp -= necroHealCost;
        return _castHeal(u, worst);
      }
      act(Mend.toHeal, worst);
      return _moveToward(u, spot, dt);
    }
    // It can't heal: a troop in reach of its scythe, or a short step from it, gets a swing.
    final near = _nearestFoe(u), d = near?.pos.distanceTo(u.pos) ?? double.infinity;
    if (near != null && d <= necroSwing.reach + necroSwing.step) {
      act(Mend.swing);
      if (d > necroSwing.reach) return _moveToward(u, near.pos, dt);
      u.moving = false;
      _face(u, near.pos.x - u.pos.x, 0);
      if (u.cd <= 0) {
        u
          ..cd = necroSwing.gap
          ..attackedAt = t
          ..swung = true;
        impacts.add((near.pos, 'hit_$boss'));
        _hurt(near, u.stats.dmg * necroSwing.share, Hit.normal, u);
        sfx.add(Sfx.hit);
      }
      return;
    }
    final others = enemies.where((o) => o.alive && !o.stats.heals).toList();
    // Alone, it walks on toward the troops (into their reach), so a wave never stalls; with none standing it waits.
    if (others.isEmpty) {
      act(Mend.alone);
      final to = _nearestFoe(u);
      if (to == null) {
        u.moving = false;
        return;
      }
      return _moveToward(u, to.pos, dt);
    }
    if (back != null) {
      act(Mend.backOff);
      return _moveToward(u, back, dt);
    }
    // A tile behind the rearmost monster (an escort's healer: behind its boss, #90; never off the right of the
    // screen), moved further back until it is [mendClear] out of the troops' reach (an escort's healer: the melee
    // troops', at most [escortReach] behind its boss); the healers there spread a lane apart around the monsters'
    // middle (its boss's lane), top to bottom as they stand (#82: by their order of coming, two crossing at one x
    // pushed against each other for seconds). It sets off for a rest spot only half [mendClear] clear or more, keeps
    // to it while it is out of the reach, and with no clear way there it doesn't go: it holds where it is, as a
    // cornered one does. So a rest spot the edge keeps in or at the reach isn't walked into and backed off from in turn.
    Unit? leadOf(Unit o) => o.escortOf?.alive == true ? o.escortOf : null;
    final healers = enemies.where((o) => o.alive && o.stats.heals && leadOf(o) == lead).toList()..sort(_topDown);
    final mid = lead?.pos.y ?? others.map((o) => o.pos.y).reduce((a, b) => a + b) / others.length;
    final farthest = lead == null ? rightLimit : min(rightLimit, lead.pos.x + escortReach);
    var rest = Point(min(farthest, (lead?.pos.x ?? others.map((o) => o.pos.x).reduce(max)) + tile),
        (mid + (healers.indexOf(u) - (healers.length - 1) / 2) * tile).clamp(tile / 2, fieldH - tile / 2));
    for (var i = 0; i < 4 && reachInto(feared, rest) > -mendClear && rest.x < farthest; i++) {
      rest = Point(min(farthest, rest.x + reachInto(feared, rest) + mendClear), rest.y);
    }
    if (!cornered && reachInto(feared, rest) <= (u.mend == Mend.rest ? 0 : -mendClear / 2) && clearWay(feared, rest)) {
      act(Mend.rest);
      _moveToward(u, rest, dt);
    } else {
      act(Mend.hold);
      u.moving = false;
    }
    if (!u.moving) u.dir = -1;
  }

  /// The necromancer's raised minions still standing (also those rising this tick).
  List<Unit> minionsOf(Unit u) => [for (final m in [...units, ...raised]) if (m.raisedBy == u && m.alive) m];

  /// The summoner stops to raise up to [minions] [minion]s of [tier] just in front of it (never more than
  /// [maxMinions] of its own at once), paying [summonCost] MP for each. They pay no gold, so a
  /// necromancer can't be farmed.
  void _summon(Unit u, Tier tier) {
    final n = min(minions, maxMinions - minionsOf(u).length);
    u
      ..mp -= n * summonCost[tier]!
      ..summonCd = summonEvery
      ..busyFrom = t
      ..busyUntil = t + summonTime
      ..moving = false;
    for (var i = 0; i < n; i++) {
      final at = u.pos + Point(u.dir * 14.0, (i - (n - 1) / 2) * 20);
      raised.add(Unit(Side.enemy, minion, spawnStats(minion, tier, raised: true)._with(cost: 0), Point(at.x, at.y.clamp(4.0, fieldH - 2)))
        ..tier = tier
        ..raisedBy = u
        ..dir = u.dir
        ..busyFrom = t
        ..busyUntil = t + riseTime);
      _omenSpawn(raised.last);
      impacts.add((raised.last.pos, tier == Tier.normal ? 'summon' : 'summon_${tier.name}'));
      _emit(MonsterSpawned(wave, t, type: minion, tier: tier, raised: true));
    }
    sfx.add(Sfx.magic);
  }

  /// What the summoner [u] does with its MP now: raise minions of one tier, or wait (saving up for a
  /// better one). Pure and deterministic (no dice), so it can be tested and traced.
  ///
  /// It plans over a horizon: [calmHorizon] s at full health, shorter as it is hurt, and no longer than it
  /// has before the troops reach it (their walk, plus how long its standing minions hold them: reach +
  /// shield) or before the troops already hitting it would kill it (life). For each tier up to its
  /// [summonCeiling] it counts the minions it could raise within that horizon (waiting for the MP first,
  /// then one cast every [summonEvery] s or as fast as its regen pays), up to [maxMinions], times what one
  /// is worth (HP × damage per second). The best one is cast now if it can pay for it, or saved up for;
  /// with none worth anything in time it waits for the cheapest.
  SummonChoice decideSummon(Unit u) {
    final live = minionsOf(u), free = maxMinions - live.length;
    final fighters = troops.where((o) => o.alive && o.entered && !o.stats.heals).toList();
    var reach = double.infinity, troopDps = 0.0, hitDps = 0.0;
    for (final f in fighters) {
      final d = f.pos.distanceTo(u.pos), dps = f.stats.dmg / f.stats.rate;
      reach = min(reach, max(0, d - f.stats.range) / (f.walkSpeed + u.stats.speed));
      troopDps += dps;
      if (d <= f.stats.range + tile) hitDps += dps;
    }
    final wall = live.fold(0.0, (s, m) => s + m.hp);
    final shield = live.isEmpty ? 0.0 : (troopDps == 0 ? double.infinity : wall / troopDps);
    final life = hitDps == 0 ? double.infinity : u.hp / hitDps;
    final horizon = max(0.0, min(calmHorizon * u.hp / u.maxHp, min(reach + shield, life)));
    SummonChoice choice({Tier? cast, Tier? saving, Map<Tier, double> scores = const {}}) =>
        SummonChoice(cast: cast, saving: saving, horizon: horizon, reach: reach, shield: shield, life: life, scores: scores);
    if (free <= 0) return choice();
    final scores = <Tier, double>{}, waits = <Tier, double>{};
    for (final tier in Tier.values.take(summonCeiling(u.tier, wave).index + 1)) {
      final cost = summonCost[tier]!, m = spawnStats(minion, tier, raised: true);
      final wait = waits[tier] = max(0, min(minions, free) * cost - u.mp) / u.stats.mpRegen;
      if (wait > horizon) {
        scores[tier] = 0;
        continue;
      }
      final period = max(summonEvery, minions * cost / u.stats.mpRegen), casts = 1 + (horizon - wait) / period;
      scores[tier] = min(free.toDouble(), casts * minions) * m.hp * m.dmg / m.rate;
    }
    var best = Tier.normal;
    for (final tier in scores.keys) {
      if (scores[tier]! > scores[best]!) best = tier; // a tie keeps the lower tier
    }
    if (scores[best]! <= 0) {
      final cheapest = waits.keys.reduce((a, b) => waits[b]! < waits[a]! ? b : a);
      return choice(saving: cheapest, scores: scores);
    }
    return waits[best]! > 0 ? choice(saving: best, scores: scores) : choice(cast: best, scores: scores);
  }

  /// A charging monster ([marching], decisions-log 329: the owner, "monster juga nga perlu ke garis belakang karna kan
  /// targetnya para troops"): straight at the troop it goes for ([_monsterFoe]), to the edge of its reach, and it strikes
  /// there; no heal, summon, skill or backing off. With no troop standing it waits where it is. Until 329 the march walked
  /// through the troops to the back line, and each monster over it cost half a heart.
  void _charge(Unit u, double dt) {
    u.cd -= dt;
    final foe = _monsterFoe(u);
    if (foe == null) {
      u.moving = false;
      return;
    }
    if (!reaches(u, foe)) return _moveToward(u, _reachPoint(u, foe), dt);
    u.moving = false;
    _face(u, foe.pos.x - u.pos.x, 0);
    if (u.cd <= 0) _strike(u, foe);
  }

  /// How much of the wave is left to do: its own monsters' HP plus their way to the base (raised minions
  /// don't count). A new low of it, or a spawn, is progress; none for [stallTime] and the wave has
  /// stalled: the monsters march ([marching]). Two more stalls, for fights whose falling HP alone read as progress
  /// (qa-3): while the monsters nearest the base stand more than [stallDrift] further from it than they have since
  /// the last spawn or death, a new low doesn't count; and [stallOvertime] after the last spawn or [stallProgress] of
  /// the slot monsters, or [stallOvertimeMax] after the last spawn, they march whatever else.
  void _watchStall(bool spawned) {
    if (!waveActive || marching) return;
    final own = enemies.where((u) => u.alive && u.raisedBy == null).toList();
    double way(Unit u) => max(0.0, u.pos.x - baseX);
    final left = own.fold(0.0, (s, u) => s + u.hp + way(u)), front = own.isEmpty ? 0.0 : own.map(way).reduce(min);
    _frontLow = spawned || own.length != _stallCount ? front : min(_frontLow, front); // a spawn or death: afresh
    // Only a spawn brings a slot monster, so between two starts of the overtime clock the same ones are counted, a
    // dead one at 0 HP. HP healed back has to be lost again before it counts.
    final slotted = own.where((u) => u.tier == Tier.boss || u.tier == Tier.miniBoss);
    final slotHp = slotted.fold(0.0, (s, u) => s + u.hp);
    if (spawned) _quietFrom = t;
    if (spawned || (_slotMaxHp > 0 && _slotHp - slotHp >= stallProgress * _slotMaxHp)) {
      _overtimeFrom = t;
      _slotHp = slotHp;
      _slotMaxHp = slotted.fold(0.0, (s, u) => s + u.maxHp);
    }
    _stallCount = own.length;
    final drifting = front - _frontLow > stallDrift;
    if (spawned || (left < _stallLow && !drifting)) {
      _stallLow = left;
      _progressAt = t;
    }
    final stalled = t - _progressAt > stallTime, longest = t - _quietFrom > stallOvertimeMax;
    if (stalled || longest || t - _overtimeFrom > stallOvertime) {
      marching = newMarch = this.stalled = true; // the field (the guide's card), not the local above
      _marchAt = t;
      sfx.add(Sfx.leak); // the charge's alarm (a monster over the back line until decisions-log 329)
      _emit(Marched(wave, t,
          why: stalled
              ? (drifting ? MarchCause.drifting : MarchCause.stalled)
              : (longest ? MarchCause.overtimeMax : MarchCause.overtime)));
    }
  }

  void tick(double dt) {
    if (over || paused) return;
    final wasActive = waveActive;
    final start = {for (final u in units) u: u.pos}; // for the right-edge limit on shoves, and the stall detector
    t += dt;
    _dt = dt;
    _sweptGone(); // a wipe's swept monsters go once their hop is over (wipe.dart)
    _ticks++; // the near counts are counted afresh ([FxEngine.alliesNearOf])
    _tickEffects(dt); // Hero skills' effects: what is due, heals and bleeds, what ran out
    _omenFade(dt); // Fade: the troops' shields shrink, a stunned or busy troop's too (omen.dart)
    _omenHeals(); // Trickle's spread heals land, Heal Siphon pays (omen.dart)

    // Below the spawn floor the next monster comes on at once, one a tick; every spawn starts the gap afresh, so the
    // timer runs again from the one that reaches the floor.
    final spawned = queue.isNotEmpty && (belowSpawnFloor || (_spawnTimer -= dt) <= 0);
    if (spawned) {
      final (type, tier) = queue.removeAt(0);
      // A guard (the Guard Bayangan, omen.dart) comes on its slot's row, drawing no row: [rng] stays paired.
      final guard = _guardsAt.contains(waveSpawned);
      final y = guard ? _guarded?.y ?? (rows ~/ 2 + 0.5) * tile : (rng.nextInt(rows) + 0.5) * tile;
      final u = monster(type, tier, Point(spawnX, y), skipBuff: waveSpawned < skipBuffN);
      if (guard) u.guardOf = _guarded?.slot;
      _firstCast(u); // its skill's first cast a few seconds after it comes on (monster_skills.dart)
      // The wave's mini boss and boss get a name for their bars (#67), with the names' dice.
      if (tier == Tier.miniBoss || tier == Tier.boss) {
        u.name = bossName(names, {for (final o in enemies) o.name});
        _guarded = (slot: u, y: y);
      }
      // From [escortFrom] a mini boss or boss brings its escort: the healing necromancers and the high-elite
      // necromancer that come right after it (#90).
      if (tier == Tier.miniBoss || tier == Tier.boss) {
        _escorted = wave >= escortFrom ? u : null;
        _escortDue = _escorted == null ? 0 : escortHealers + escortSummoners;
      } else if (_escortDue > 0 && (type == necroHealer || (type == boss && tier == escortSummonerTier))) {
        u.escortOf = _escorted;
        _escortDue--;
      } else {
        _escortDue = 0;
      }
      units.add(u);
      _emit(MonsterSpawned(wave, t, type: type, tier: tier));
      if (strongTiers.contains(tier)) _emit(StrongFoe(wave, t, type: type, tier: tier));
      waveSpawned++;
      _spawnTimer = spawnGapOf(wave, tideStart); // the tide shortens it from [tideStart]
    }
    _omenDuskTick(); // Dusk: the crowd all in, and 30 s after it the monsters hit harder (omen.dart)

    _assignSpots(); // where each melee troop fights from (engage.dart)
    for (final u in units) {
      if (u.dying >= 0) {
        u.dying += dt;
        continue;
      }
      // A monster skill's wind-up is cancelled by a stun, a shove or a march (monster_skills.dart).
      if (u.winding != null && (u.move != null || t < u.stunUntil || marching || !monsterSkillsOf(u).contains(u.winding))) _cancelWind(u);
      // A troop skill's wind-up is cancelled by a stun, a move or the wave's end (skill_strips.dart).
      if (u.troopWind != null && (u.move != null || t < u.stunUntil || !waveActive)) _cancelTroopWind(u);
      if (u.stats.mpRegen > 0) {
        final before = u.mp;
        u.mp = min(u.stats.mp.toDouble(), u.mp + u.stats.mpRegen * dt); // even while casting
        if (u.mp > before && u.side == Side.troop && pusaka.isNotEmpty) _fxMpRegen(u, u.mp - before); // Moonwell's counter
      }
      if (_moves(u, dt)) continue; // carried: knocked back, leaping, charging or dragged (hero_moves.dart)
      if (t < u.busyUntil || t < u.stunUntil || t < u.downUntil) {
        u.moving = false; // casting, rising, stunned (Crushing Blow) or a heap of bones (Reassemble)
        continue;
      }
      if (marching && u.side == Side.enemy) {
        _charge(u, dt); // the wave stalled: straight at the troops
        continue;
      }
      // The summoner thinks about raising minions every so often ([decideSummon]); after deciding to wait
      // it thinks again soon.
      if (u.type == boss && u.stats.mp > 0 && (u.summonCd -= dt) <= 0) {
        final plan = u.plan = decideSummon(u);
        if (plan.cast case final tier?) {
          _summon(u, tier);
          continue;
        }
        u.summonCd = summonThink;
      }
      u.cd -= dt;
      if (u.stats.regen > 0) {
        final before = u.hp;
        _healUnit(u, u.stats.regen * dt, HealSrc.regen);
        if (u.hp > before && u.side == Side.troop && pusaka.isNotEmpty) _fxRegen(u, u.hp - before); // Living Moss's counter
      }
      if (u.side == Side.troop && !u.entered) {
        // Still marching in: heads for its spot until it is over the back line (mid-wave at the catch-up pace).
        _moveToward(u, u.post, dt, catchUp: true);

        continue;
      }
      if (_casting(u)) {
        u.moving = false; // a healer mid-cast stands still
        continue;
      }
      if (u.troopWind != null) {
        _troopWindTurn(u); // winding up a skill, or landing it (skill_strips.dart)
        continue;
      }
      if (u.side == Side.troop && (skills || heroSkills || awakenSkills) && waveActive) _trySkill(u);
      if (u.troopWind != null) continue; // it began a skill's wind-up: nothing else this tick
      if (u.side == Side.enemy && monsterSkills && waveActive && _monsterSkillTurn(u)) continue; // winding up or casting
      if (u.move != null) continue; // a Hero skill just set it moving: it does nothing else (hero_moves.dart)
      if (u.stats.heals) {
        if (u.side == Side.enemy) {
          _mend(u, dt);
        } else if (waveActive && u.cd <= 0 && healQueue.isNotEmpty && t - victoryAt >= victoryTime) {
          _healFromQueue(u); // after-wave heals carried into the wave ([RetreatBrain.carryHealQueue]) come first
        } else {
          waveActive ? _heal(u, dt) : _rest(u, dt); // between waves healing is the after-wave round below
        }
        continue;
      }
      final foe = u.side == Side.enemy ? _monsterFoe(u) : _nearestFoe(u); // a monster fights a troop it meets (engage.dart)
      final inReach = foe != null && reaches(u, foe);
      if (_fallBackTo(u) case (final act, final healer?)) {
        // Hurt: back toward the healer until well inside its reach. It doesn't chase, and hits a foe in its
        // reach (facing it as it backs off) only when the policy says so: a ranged troop, or a melee one that
        // can't back off any further.
        if (healer.pos.distanceTo(u.pos) > healer.stats.range * retreatPolicy.brain.retreatNear) {
          _moveToward(u, healer.pos, dt);
        } else {
          u.moving = false;
        }
        if (inReach && act == RetreatAction.fallBackFighting) {
          _face(u, foe.pos.x - u.pos.x, 0);
          if (u.cd <= 0) _strike(u, foe);
        }
        continue;
      }
      if (inReach) {
        final d = foe.pos.distanceTo(u.pos), hold = holdAt(u);
        if (u.side == Side.troop && u.stats.shotSpeed > 0 && d < kiteAt(u)) {
          // Long range back off while shooting to keep the foe near their hold ([holdAt], [kiteAt])
          // (never behind the back line, nor out of sight: [_rearEdge]). Pinned there, it backs straight up to it
          // and holds: sliding along it only ran it into the archers beside it, for seconds on end (#82).
          // With [holdPastFoe] on, nor away from the base: past its foe it keeps its x and only steps aside.
          final away = (u.pos - foe.pos) * (tile / max(d, 0.01)), edge = _rearEdge + tile / 2;
          var to = u.pos + away;
          if (holdPastFoe && to.x > u.pos.x) to = Point(u.pos.x, to.y);
          _moveToward(u, to.x >= edge ? to : Point(edge, u.pos.y), dt, kite: true);
        } else if (u.stats.shotSpeed > 0 && d > hold + spotSlack) {
          // A shooter further off than its hold steps up to it while shooting, so its shots don't fly long
          // (decisions-log 199): a troop at the catch-up pace if it fell behind ([speedTo]).
          _moveToward(u, _reachPoint(u, foe), dt, catchUp: true);
        } else {
          u.moving = false;
        }
        _face(u, foe.pos.x - u.pos.x, 0);
        if (u.cd <= 0) _strike(u, foe);
      } else if (foe != null) {
        // A melee troop walks to its spot round a monster, or to where it waits for one (engage.dart).
        final to = u.side == Side.troop ? _meleeGoal(u) ?? foe.pos : _reachPoint(u, foe);
        if (paceLimit(u) case final limit? when to.x > limit) {
          // Too far ahead of the heavies: it stops at the limit on its way, or steps back to it, still facing
          // the foe.
          final d = to - u.pos;
          _moveToward(u, u.pos.x < limit ? u.pos + d * ((limit - u.pos.x) / d.x) : Point(limit, u.pos.y), dt);
          _face(u, foe.pos.x - u.pos.x, 0);
        } else {
          // Only one that fell behind speeds up. A way past the view's right edge ends at the cap ([frontCap]), where it
          // stands facing its foe until the view moves on.
          final way = _capWay(u, to);
          if (keepSupports && u.side == Side.troop && way.x < u.pos.x - turnSlack && t - u.forwardAt < turnHold) {
            u.moving = false; // it walked forward a moment ago: it holds before it turns back ([turnHold])
            _face(u, foe.pos.x - u.pos.x, 0);
          } else {
            _moveToward(u, way, dt, catchUp: true);
            if (way != to) _face(u, foe.pos.x - u.pos.x, 0);
            if (u.moving && u.heading.x > 0) u.forwardAt = t;
          }
        }
      } else if (u.side == Side.enemy) {
        u.moving = false; // no troop standing (a Phoenix rise due, a wave begun with none): it waits (decisions-log 329)
      } else {
        _rest(u, dt);
      }
    }

    if (healQueue.isNotEmpty && t - victoryAt >= victoryTime) _afterWaveHeal();

    units.addAll(raised);
    raised.clear();

    _makeWay(dt);

    // Keep units from stacking on one spot.
    final live = units.where((u) => u.alive).toList();
    for (final u in live) {
      if (u.side == Side.enemy) u.entered |= u.pos.x <= rightLimit; // before any shove can push it back out
    }
    for (var i = 0; i < live.length; i++) {
      for (var j = i + 1; j < live.length; j++) {
        final a = live[i], b = live[j], d = b.pos - a.pos, len = d.magnitude;
        if (len >= _personalSpace) continue; // (a march walked through the troops until decisions-log 329: it charges them now)
        if (_passesThrough(a) || _passesThrough(b)) continue; // hopping over, or charging through
        final push = len > 0.01 ? d * ((_personalSpace - len) / 2 / len) : Point(0.0, (_personalSpace / 2) * (i.isEven ? 1 : -1));
        if (a.side == Side.troop && b.side == Side.troop) {
          if (_ghost(a) || _ghost(b)) continue; // walks through, see [Unit.arriving] and [_watchStuck]
          if (_spotMates(a, b)) continue; // on spots of one monster, closer than this (engage.dart)
          // Troops make way for each other: whoever is on the move passes and the one standing steps
          // aside; between two alike, the one further back (Healer | long range | melee) gives way, and
          // between two of a kind the later placed one does ([_passes]).
          var (yielder, keeper) = _passes(a, b) ? (b, a) : (a, b);
          if (_firm(yielder, troop: true)) {
            if (_firm(keeper, troop: true)) continue;
            (yielder, keeper) = (keeper, yielder); // a healer mid-cast holds its ground, and so does a unit nothing shoves
          }
          final away = yielder.pos - keeper.pos, gap = _personalSpace - len;
          final dy = away.y.abs() > 0.5 ? away.y.sign : (yielder.pos.y < fieldH / 2 ? 1.0 : -1.0);
          // Setting up, only melee may be nudged forward; in battle nobody keeps a spot.
          // Mid-wave the x part goes as the two stand apart in x, not a whole half gap either way for a hair: shoved
          // between allies above and below, a troop went back and forth (decisions-log 324).
          final dx = keepSupports && waveActive
              ? away.x / max(len, 0.01)
              : (yielder.line == 2 || waveActive ? away.x.sign : min(0.0, away.x.sign));
          yielder.pos += Point(dx * gap / 2, dy * gap);
          continue;
        }
        if (_slideRound(a, b, len)) continue; // a monster walking up behind one that stands (engage.dart)
        // A healer mid-cast holds its ground, and so does a unit nothing shoves (carried, braced, [Status.noShove]);
        // the other takes the whole shove.
        final fa = _firm(a), fb = _firm(b);
        final (ka, kb) = fa == fb ? (1.0, 1.0) : (fa ? (0.0, 2.0) : (2.0, 0.0));
        a.pos -= push * ka;
        b.pos += push * kb;
      }
    }
    _aimView(dt); // the view's centre after the battle point (battle_focus.dart)
    for (final u in live) {
      u.pos = Point(u.pos.x, u.pos.y.clamp(4.0, fieldH - 2));
      if (u.side == Side.troop) {
        u.entered |= u.pos.x >= min(u.post.x, baseX + tile);
        if (u.pos.distanceTo(u.post) < 1 || (waveActive && u.entered)) u.arriving = false;
        if (u.entered && u.pos.x < baseX + clearOfLine) u.pos = Point(baseX + clearOfLine, u.pos.y); // left behind the line
        // A shove never pushes it past the front's cap, and the view gliding left leaves it where it is (decisions-log 324):
        // carried (a leap, a charge) it lands where its move takes it.
        if (frontCap case final cap? when u.entered && u.move == null && u.pos.x > cap) {
          u.pos = Point(max(cap, min(u.pos.x, start[u]?.x ?? u.pos.x)), u.pos.y);
        }
        if (start[u] case final from?) _watchStuck(u, from, dt);
      }
      if (u.side == Side.enemy) {
        u.entered |= u.pos.x <= rightLimit;
        // A shove never pushes it out past the right edge, and the view gliding left leaves it where it is,
        // but its own steps left stand: a monster the view glided past still comes on (#42).
        if (u.entered && u.pos.x > rightLimit) u.pos = Point(max(rightLimit, min(u.pos.x, start[u]?.x ?? u.pos.x)), u.pos.y);
      }
      // No monster heads for the back line any more: its goal is always a troop, and with none standing it waits
      // (decisions-log 329). One past the line, meeting a troop that walks in from behind it, costs nothing; until 329 it
      // was gone and cost a life, half a heart.
    }

    // A shot whose target fell or left flies on to where it was, and lands there as on it (decisions-log 327).
    for (final s in shots) {
      final e = s.target;
      if (s.to == null && !e.alive) s.to = e.pos; // frozen where it went
      final at = s.aim, dist = s.pos.distanceTo(at), mv = (s.speed ?? s.from.stats.shotSpeed) * dt;
      if (dist <= mv) {
        s.done = true;
        impacts.add((at, _fxOf(s.from, shotHitFx(s))));
        if (s.ring case final look?) rings.add(Ring(at, radius: max(s.splash, tile), since: t, look: look));
        if (s.spent) continue; // in the air when the wave ended: its look alone
        final on = s.to == null ? e : _standingOn(at, e.side); // its target, or the unit standing where it was, if any
        _deflected = false;
        _pummeled = s.pummel;
        _sapped = s.sap;
        if (s.splash > 0) {
          for (final o in units.toList()) {
            if (o.side == e.side && o.alive && o.pos.distanceTo(at) <= s.splash) {
              final dealt = _hurt(o, s.dmg, o == on || s.src != Hit.normal ? s.src : Hit.extra, s.from); // a normal shot's splash past its target is extra
              if (o != on && s.src == Hit.normal) _fxSplash(s.from, at, o, dealt, s.splash); // Wide Blows' counter (pusaka_engine.dart)
              s.onHit?.call(o);
            }
          }
        } else if (on != null) {
          _hurt(on, s.dmg, s.src, s.from);
          s.onHit?.call(on);
        }
        _pummeled = _sapped = false;
        if (on == null) continue; // nobody where its target was: the splash alone, or its look
        if (!_deflected) _fxLanded(s.from, on, s.dmg); // its type's `landed` Fx: God's Thunder (pusaka_engine.dart); none on a Deflected hit (omen.dart)
        if (!_deflected && s.src == Hit.normal && s.from.relics.isNotEmpty) _relicLanded(s.from, on, s.dmg, Hit.normal); // relics.dart
      } else {
        s.pos += (at - s.pos) * (mv / dist);
      }
    }
    shots.removeWhere((s) => s.done);
    _moveSpecials(dt); // hero_shots.dart
    _watchGrail(); // a Grail save kept once its troop has lived [keptAfter] s since (pusaka.dart)
    if (pusaka.isNotEmpty) _oathWatch(); // a type died out or came back: Alliance's multiplier moves (pusaka.dart)
    units.removeWhere((u) => u.gone || u.dying >= deathTime);
    _watchStall(spawned);
    // The army down, or a march not won in time: a heart lost, the wave swept and played again (wipe.dart).
    if (wasActive && !wipedOut && !over) {
      if (_waveLost() case final why?) _wipe(why);
    }

    if (wasActive && !waveActive && !over && !wipedOut) {
      marching = false;
      _endEffects(); // Hero skills' effects end with the wave
      sfx.add(Sfx.clear);
      victoryAt = t;
      _watchGrail(end: true); // the wave's end: every save whose troop lives is kept
      _fxWave(end: true); // the Pusaka's `waveEnd` Fx (pusaka_engine.dart)
      lastPusaka = _pusakaReport(); // what they did, for the log (under the win's line) and the "MENANG!" line
      if (lastPusaka case final r?) _emit(r);
      _emit(WaveEnded(wave, t, won: true));
      _boostWaveEnd(); // the Tavern's boosts count the wave (tavern.dart)
      _omenEase(); // the wave's falls take Bayangan levels away (omen.dart)
      _omenTopKiller(); // the wave's top killer, Grudge's target in the next (omen.dart)
      // A wave won again after a trip back to a Town pays its kills, drops and win gold again, its once-a-number
      // rewards only the first time (wipe.dart).
      final first = wave > bestWon;
      bestWon = max(bestWon, wave);
      if (lostWave case final w? when w <= wave) lostWave = null; // the wave the army was wiped in is won now
      lastBonus = waveBonus(wave);
      gold += lastBonus;
      if (first) score += waveScore * wave;
      lastMaterials = {...waveMaterials};
      for (final MapEntry(key: m, value: n) in waveMaterials.entries) {
        materials[m] = (materials[m] ?? 0) + n;
      }
      waveMaterials.clear();
      zones.clear(); // a Hero skill's ground lasts no longer than its wave
      for (final s in shots) {
        s.spent = true; // in the air still: it lands its look and hurts nobody (decisions-log 327)
      }
      lastFallen = [...fallen];
      final rear = troops.isEmpty ? baseX : troops.map((u) => u.pos.x).reduce(min);
      final shift = max(0.0, (rear / tile).floor() * tile - baseX); // how far the back line moves up, below
      toReplace
        ..clear()
        ..addAll([for (final u in fallen) if (!u.hero) (type: u.type, post: u.post + Point(shift, 0))]);
      _autoWon(); // those Auto bought back during the wave leave it (auto_replace.dart)
      // Survivors recover between waves only while a healer is still standing: once the cheering is over
      // the healers heal the hurt in turn, healers first, then the melee, then the long range.
      final alive = troops.where((u) => u.alive).toList();
      healQueue
        ..clear()
        ..addAll([for (final line in [0, 2, 1]) ...alive.where((u) => u.line == line && u.hp < u.maxHp)]);
      if (!alive.any((u) => u.stats.heals)) healQueue.clear();
      for (final tr in troops) {
        tr.dir = 1;
      }
      if (troops.isNotEmpty) {
        // The back line moves up to the rearmost troop ([shift]), and every drop spot moves with it.
        baseX += shift;
        for (final tr in troops) {
          tr.post += Point(shift, 0);
        }
        _claimSpots();
        _uncrossSpots();
      }
      // Every [heroEvery]th wave won makes a Hero, between waves (the owner: "setelah wave 10 baru muncul
      // hero baru, bukan di awal wave 10"), while fewer than [heroMax] live; the auto-save after the win keeps it.
      if (first && wave > 0 && wave % heroEvery == 0 && heroCount < heroMax) _crownHero();
      // A won boss wave brings the boss's chest (draft.dart), rolled now so the auto-save keeps its cards.
      if (first && offers && wave % bossEvery == 0) _bossChest();
      _rollTown(); // then the Town two waves ahead, rolled now so the auto-save keeps it (town.dart)
    }
    _autoReplaceTick(); // Auto buys back the fallen the gold now covers (auto_replace.dart)
    // The game ended this tick (the next one returns at once): the wave is lost.
    if (over) {
      _watchGrail(end: true);
      _emit(WaveEnded(wave, t, won: false));
      _boostWaveEnd();
    }
  }
}
