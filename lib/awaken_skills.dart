part of 'game.dart';

// Awakening skills (#88; docs/units-and-combat.md, "Awakening skills"). The owner: "ketika troops awekening troops
// juga dapat skill baru". Each troop type has one ([AwakenSkill]): Bangkit 1 unlocks it for every troop of the type,
// Bangkit 2 and 3 make it stronger (its name pops as "Disarm", "Disarm II", "Disarm III"). A troop casts it by
// itself during a wave, like its #10 skill ([troopSkills]): after its Hero skill and its #10 skill, one cast a tick
// ([Game._trySkill]). It costs MP ([AwakenSkill.costAt], the owner's "Use MP") from the pool the #10 skill uses, and
// it has a cooldown by level. The level is its type's ([Game.awakenLevel]), so nothing new is saved. Bangkit 4 and 5,
// bought with gold (#92 part 2), keep Bangkit 3's numbers ([_at]) and only shorten the cooldown ([ascendSkillCd]).
//
// A new awakening skill plugs in here: `built: true` on its [AwakenSkill], a case in [AwakenSkills.wantsAwakenSkill],
// [AwakenSkills._castAwakenSkill] and [awakenLines], its numbers as `<id>K` (one entry per level), and its looks
// (a [RingLook], [BeamLook], [ZoneLook] or [ShotLook], coloured in lib/skills.dart's table of the awakening skills'
// colours and drawn there; every new [RingLook] needs its `_ringColors` entry in lib/hero_skill_fx.dart).

/// The nine awakening skills, one per troop type (the owner's structure A, decisions-log 124), in the troop
/// cards' order. Only [built] ones unlock ([awakenSkillOf]). [holds]: it moves, stops or cancels monsters, so it
/// never casts while a stalled wave marches ([Game.marching]). [cooldown]: seconds between casts at Bangkit 1, 2
/// and 3. The MP it costs is its type's ([costAt]).
enum AwakenSkill {
  /// Prajurit: a strike that knocks the weapon arm of the strongest foe in reach ([disarmK]).
  disarm('soldier', 'Disarm', [22, 20, 18], built: true),

  /// Ksatria: beaten to half, it heals, throws off the monsters' holds and heals the troops beside it ([unbrokenK]).
  unbroken('knight', 'Unbroken', [22, 20, 18], built: true),

  /// Pendekar: dashes cutting the most wounded foes round it, then back where it stood ([phantomRushK]).
  phantomRush('swordsman', 'Phantom Rush', [18, 18, 18], built: true),

  /// Pemanah: a silver arrow that strips the buffs and guards monsters gave a monster ([spellbreakerK]).
  spellbreaker('archer', 'Spellbreaker', [18, 16, 14], built: true),

  /// Penombak: a lunge past its reach that breaks a monster's wind-up or pins a strong foe ([impaleK]).
  impale('lancer', 'Impale', [18, 18, 18], built: true, holds: true),

  /// Pendeta: lifts a dying troop out of the melee to its side, mended ([lifelineK]).
  lifeline('priest', 'Lifeline', [22, 20, 18], built: true),

  /// Kapak Berzirah: leaps into a crowd where troops fight, and the ground bursts where it lands ([skyfallK]).
  skyfall('armored_axeman', 'Skyfall', [22, 22, 22], built: true),

  /// Penyihir: a well that drags the monsters round it into a knot, then bursts ([singularityK]).
  singularity('wizard', 'Singularity', [24, 22, 20], built: true, holds: true),

  /// Templar: holy ground at its feet that burns the monsters on it ([consecrationK]).
  consecration('knight_templar', 'Consecration', [22, 22, 22], built: true);

  const AwakenSkill(this.type, this.title, this.cooldown, {this.built = false, this.holds = false});

  /// The troop type it belongs to; [title] its name on screen (`name` is its id).
  final String type, title;

  /// Seconds between casts, at Bangkit 1, 2 and 3.
  final List<double> cooldown;
  final bool built, holds;

  /// Seconds between casts at [level] (1 to [awakenTop]): [awakenCdK] of its [cooldown] (decisions-log 298); Bangkit 4
  /// and 5 take Bangkit 3's times [ascendSkillCd] each.
  double cooldownAt(int level) => cooldown[_at(level)] * awakenCdK * ascendFactor(level, ascendSkillCd);

  /// The MP a cast costs at [level]: [awakenCost] of its type's MP pool at that level (the base pool raised by
  /// [awakenMp] a level, as [Game.statsOf] raises it; a Hero's ×3 and the aura don't raise the cost), rounded.
  /// Every type gets back 5% of its pool a second, so that is 8 s of its MP regen at every level: soldier,
  /// knight, lancer and axeman 10 / 12 / 14; swordsman and archer 15 / 18 / 21; templar 20 / 24 / 28; priest 30 /
  /// 36 / 42; wizard 40 / 48 / 56.
  int costAt(int level) => (awakenCost * (troopTypes[type]!.mp * (1 + awakenMp * level.clamp(1, maxAwaken))).round()).round();

  /// Its name at [level]: "Disarm" at Bangkit 1, then "Disarm II", "Disarm III" (ASCII numerals).
  String titleAt(int level) => level <= 1 ? title : '$title ${level == 2 ? 'II' : 'III'}';
}

/// An awakening skill costs this share of its type's MP pool at its level ([AwakenSkill.costAt]). With it a full
/// pool pays for the #10 skill and the awakening skill once each at every level (the soldier's 25 at Bangkit 1:
/// Hold Fast 15 + Disarm 10), and in a long fight the awakening skill takes 8 s of regen out of each cooldown.
const awakenCost = 0.4;

/// A wave's start, and the awakening moment mid-wave, make every troop's awakening skill ready, but the troops of
/// one type [awakenStagger] s apart, by their order in the army ([Game._staggerAwaken]): the i-th at
/// (i % [awakenSlots]) × [awakenStagger], so over 0–3 s, not all on one tick.
const awakenStagger = 1.0, awakenSlots = 4;

/// When a ready awakening skill's rule says no, the troop doesn't ask it again for this long (s) ([Unit.awakenThinkAt]).
const awakenThink = 0.25;

/// Where awakening [level]'s numbers are in a skill's per-level lists (Bangkit 1, 2, 3): Bangkit 4 and 5 (#92 part 2)
/// use Bangkit 3's.
int _at(int level) => level.clamp(1, maxAwaken) - 1;

/// The built awakening skill of each troop type.
final _awakenOfType = {for (final s in AwakenSkill.values) if (s.built) s.type: s};

/// The awakening skill of troop [type] (null: none built for it, or not a troop type).
AwakenSkill? awakenSkillOf(String type) => _awakenOfType[type];

// The numbers, one record per built skill (`<id>K`); a list holds one entry per level (Bangkit 1, 2, 3).

/// An awakening skill comes again after this share of its [AwakenSkill.cooldown] (decisions-log 298: the troops cast as
/// often as their MP and a target allow; a Hero's skill likewise, [heroCdK]).
const awakenCdK = 0.5;

/// Disarm: a foe in reach (a taunted soldier: only its taunter) with at least [worth] × the soldier's damage in HP
/// (0 since decisions-log 298: any foe), not already weakened as strongly, and not Disarmed by any soldier in the
/// last [again] s ([Unit.disarmedAt]). The highest ranked, then the one that hits hardest, then the nearest takes
/// [hit] × the soldier's damage, and if it lives it deals [weaken] (the boss rank [boss]) for [time] s
/// ([Status.weaken]). Its look, the shards over the foe, lasts [look] s. [again] keeps a crowd of soldiers from
/// holding the mini boss or the boss weakened the whole fight (qa-3, decisions-log 156): one foe is weakened at most
/// [time] of every [again] s, and the others still are.
const disarmK = (worth: 0.0, hit: [1.5, 2.0, 2.5], weaken: [0.9, 0.85, 0.8], boss: [0.95, 0.93, 0.9], time: 6.0, again: 30.0, look: 0.5);

/// Unbroken: a foe in reach, and below [low] of its HP hit in the last [within] s, or below [hindered] of its HP
/// under a monster's hindrance ([AwakenSkills._hindrance]); both 1 since decisions-log 298: any HP lost. It gets
/// [self] of its max HP back, throws off every such hindrance, and the other troops within [reach] get [allies] of
/// their max HP back. Its look, the chains snapping, lasts [look] s.
const unbrokenK = (low: 1.0, within: 1.0, hindered: 1.0, self: [0.25, 0.3, 0.35], allies: [0.1, 0.12, 0.15], reach: tile, look: 0.6);

/// The monsters' hindrances Unbroken throws off (a monster put them on the knight: [Effect.by] is one), and a haste
/// that slows (a Sticky Glob's, k > 1). A Duel of Honour names a monster too, and stays: it is the knight's own.
const unbrokenFrees = {Status.taunt, Status.daze, Status.bleed, Status.slow, Status.weaken, Status.vulnerable};

/// Impale: a lunge out to the lancer's reach + [reach] (a taunted lancer: only its taunter), the lancer staying where
/// it stands, for [hit] × its damage. A **break** first: a foe winding up a skill that comes again (a finite
/// cooldown; never a once-only one), not the boss rank or a necromancer, not stunned, and not broken in the last
/// [window] s ([Unit.interruptedAt]); the highest ranked, then the nearest, then the first placed. Its wind-up is
/// cancelled (its cooldown has started: the skill waits it out) and it staggers [stagger] s (a mini boss half:
/// [HeroMoves._stunFor]). Else a **pin**: a strong foe (elite and up) not pinned yet, the highest ranked, then the
/// most HP, then the nearest, walks at [slow] (the boss rank [boss]) for [pin] s ([Status.impaled]); it still
/// attacks and casts. While a monster it could break stands within [watch], the lancer keeps the lance for a break,
/// for at most [hold] s after the skill is ready. The lunge's shaft shows [shaft] s, a break's shards [shatter] s.
const impaleK = (
  reach: tile,
  hit: [1.5, 2.0, 2.5],
  window: 25.0,
  stagger: 0.3,
  pin: [2.0, 2.5, 3.0],
  slow: 0.1,
  boss: 0.55,
  watch: 5 * tile,
  hold: 3.0,
  shaft: 0.3,
  shatter: 0.5,
);

/// Spellbreaker: a foe in range that no silver arrow is flying at yet, with something to strip running [left] s or
/// more: a buff of the kinds it strips ([spellbreakerStrips]) that a troop didn't give it, or a guard (Bulwark, Bone
/// Shield, Thick Hide; [Unit.guardUntil]). The highest ranked, then the one with the most, then the nearest gets a
/// silver arrow at [speed] for [hit] × the archer's damage. Landing, it strips the foe and every foe within
/// [spread] of it: a normal, elite or high-elite one loses them; a mini boss or the boss rank, and a buff the boss
/// rank gave (Rally, Howl: its moments), lose half of what is left of each, once ([Effect.halved],
/// [Unit.guardHalved]). The broken rune ring shows [ring] s, at least [mark] across.
const spellbreakerK = (
  left: 1.0,
  hit: [1.5, 2.0, 2.5],
  spread: [0.0, tile, 1.5 * tile],
  speed: 720.0,
  ring: 0.5,
  mark: 10.0,
);

/// The buffs Spellbreaker strips off a monster ([spellbreakerK]): what the monsters' skills give each other (War
/// Shout, Rally, Frenzy, Howl, Iron March, Second Wind, Shield Up, Unholy Ward, Bulwark's reflect, Bloodrage, Soul
/// Rend). It never touches what troops put on monsters.
const spellbreakerStrips = {
  Status.might,
  Status.haste,
  Status.swift,
  Status.steadfast,
  Status.shotWard,
  Status.absorb,
  Status.reflect,
  Status.lifesteal,
  Status.soulRend,
};

/// Singularity: a foe in range that can be pulled ([AwakenSkills._pullable]: on the field, not the boss rank, not
/// carried, in no open well) with [crowd]+ such foes within [radius] of it (itself too); the most, then the nearest,
/// then the first placed. A well ([Zone], [ZoneLook.singularity]) opens on that spot for [time] s: each tick each
/// monster in it drifts toward its centre at [pull] a second × its [shoveShare] (a mini boss half, the boss none),
/// stopping [core] short of it. Only its y part moves a monster that has a troop in its reach, and its x part only
/// takes one away from the base, so a well never brings a monster nearer the base. One well pulls a monster a tick,
/// the oldest; none while the wave marches; a pulled monster still walks, fights and winds up. As the well closes,
/// the foes within [burst] of its centre take [hit] × the wizard's damage (fixed at the cast). The collapse shows
/// [implode] s.
const singularityK = (
  crowd: 1, // 4 until decisions-log 298: a target is enough
  radius: [2 * tile, 2.5 * tile, 3 * tile],
  time: [2.0, 2.5, 3.0],
  pull: [24.0, 28.0, 32.0],
  core: 6.0,
  burst: 1.25 * tile,
  hit: [1.0, 1.25, 1.5],
  implode: 0.4,
);

/// Consecration: with [crowd]+ foes within its [radius] and no Consecration's centre (anyone's) within [apart] × that
/// radius of the templar, holy ground of [radius] at its feet for [time] s: each foe on it takes [hit] × the
/// templar's damage (fixed at the cast) every second, the first at once, [undead] × that on an undead one. The
/// blows are holy (no skeleton reassembles from them, and they end a heap of bones: [reassembleK]).
const consecrationK = (
  radius: [1.5 * tile, 1.75 * tile, 2 * tile],
  time: [4.0, 4.0, 5.0],
  hit: [0.15, 0.2, 0.25],
  undead: 1.25,
  crowd: 1, // 3 until decisions-log 298: a target is enough
  apart: 1.5,
);

/// Phantom Rush: a foe in reach and [crowd]+ foes within [reach], while the swordsman isn't taunted or falling back.
/// Its round is the foes within [reach] at the cast (not a heap of bones, which only holy blows hurt), the most wounded
/// by HP share first, then the nearest, then the first placed. It makes [cuts] dashes of [dash] s, each to [gap]
/// beside the next living foe of the round (round again after the last), each ending in a cut of [hit] × its damage;
/// one cut more while Rampage lasts ([Unit.frenzyUntil]), and one more once a cut kills (once a cast). Then it is
/// back where it stood in [home] s. Each dash is a hop of [lift], through everyone, and leaves a zigzag streak for
/// [streak] s; each cut an X over the foe for [cross] s.
const phantomRushK = (
  crowd: 1, // 3 until decisions-log 298: a target is enough
  reach: 2.5 * tile,
  cuts: [3, 3, 4],
  hit: [1.2, 1.3, 1.5],
  dash: 0.2,
  home: 0.15,
  gap: 8.0,
  lift: 1.0,
  streak: 0.5,
  cross: 0.3,
);

/// Skyfall: at [above]+ of its HP, not taunted or falling back, and no foe in its reach (it stands behind the
/// front). Each of the [look] nearest foes [near]–[far] away and ahead gives a spot [gap] short of it on the
/// axeman's side, never further ahead than the troop that fought (attacked in the last [fought] s) within its
/// [radius] + a tile of it (the front-most such troop, not the axeman); there must be one, [crowd]+ foes within
/// [radius] of the spot, and no other axeman leaping to within [radius] of it. The most foes, then the nearest foe:
/// it leaps there in [time] s, [lift] high at the top. Landing alive, each foe within [radius] takes [hit] × its
/// damage, and it takes [guard] less damage for [guardTime] s (in its one guard slot: a stronger guard stays). The
/// crater shows [crater] s.
const skyfallK = (
  above: 0.5,
  near: 2.5 * tile,
  far: 5 * tile,
  look: 8,
  gap: 6.0,
  fought: 2.0,
  crowd: 1, // 3 until decisions-log 298: a target is enough
  radius: [1.25 * tile, 1.5 * tile, 1.5 * tile],
  hit: [1.0, 1.25, 1.5],
  guard: [0.15, 0.2, 0.25],
  guardTime: 3.0,
  time: 0.5,
  lift: 22.0,
  crater: 0.8,
);

/// Lifeline: a troop in the priest's reach and [far]+ from it, not the priest, alive and on the field, neither
/// carried nor braced nor holding its ground ([Status.holdGround]), below [below] of its HP, hit in the last [within]
/// s and with a foe within [near] of it. The [lifts] most hurt (by HP share) are each lifted [lift] high over [time] s
/// to [gap] beside the priest (never behind the back line), taking blows on the way; landing with the priest alive,
/// each gets [heal] × the priest's heal and counts as come to its healer ([Unit.waitFrom]). Each ribbon shows
/// [tether] s, the petals at its feet [bloom] s.
const lifelineK = (
  below: 0.5, // 0.3 until decisions-log 156 (qa-3: 0.08 casts a priest a wave at Bangkit 3)
  within: 1.0,
  near: tile,
  far: 2 * tile,
  lifts: [1, 1, 2],
  heal: [1.5, 2.0, 2.5],
  lift: 14.0,
  time: 0.45,
  gap: 12.0,
  tether: 0.7,
  bloom: 0.6,
);

/// What an awakening from [from] to [to] does to troop [type]'s awakening skill, for the loot previews (the Tas
/// list, the drop popup and the Army page's detail, #86 / #87): ("Unlocks Disarm", null) when it unlocks it, ("Disarm", "Disarm II") when it
/// raises it; null when it does neither (no level gained, or no skill built for the type).
(String, String?)? awakenSkillChange(String type, int from, int to) {
  final s = awakenSkillOf(type);
  if (s == null || to <= from) return null;
  return from == 0 ? ('Unlocks ${s.title}', null) : (s.titleAt(from), s.titleAt(to));
}

/// The book's lines for troop [type]'s awakening skill at awakening [level] ([Game.awakenInfo]): its name (at
/// level 0 the one Awaken 1 opens), what it does, its MP ([price] of its cost: the price the troops pay, under the
/// Bayangan Spell Tax too, [Omens.skillPrice]) and cooldown ([cd] of it: the one the troops wait, under Oath of Spells
/// too, [Pusaka.skillCd]), and the next level's numbers (from Bangkit 3, the shorter cooldown Bangkit 4 or 5 buys); none
/// when the type has no built skill.
List<String> awakenLines(String type, int level, {double Function(int base)? price, double Function(double base)? cd}) {
  final s = awakenSkillOf(type);
  if (s == null) return const [];
  final at = max(1, level), next = level + 1;
  return [
    level == 0 ? '${awakenName(1)} unlocks ${s.title}' : 'Skill: ${s.titleAt(level)}',
    ..._does(s, at),
    'MP ${_num(price?.call(s.costAt(at)) ?? s.costAt(at))}, cooldown ${_secs(cd?.call(s.cooldownAt(at)) ?? s.cooldownAt(at))}s',
    if (level > 0 && next <= maxAwaken) '${awakenName(next)}: ${s.titleAt(next)} (${_numbers(s, next)})',
    if (level >= maxAwaken && next <= awakenTop) '${awakenName(next)}: cooldown ${_secs(cd?.call(s.cooldownAt(next)) ?? s.cooldownAt(next))}s',
  ];
}

/// What [s] does at [level], in the book's words (one or two short lines), from its `<id>K` numbers.
List<String> _does(AwakenSkill s, int level) {
  final i = _at(level);
  return switch (s) {
    AwakenSkill.disarm => [
        'x${_num(disarmK.hit[i])} hit on the strongest monster',
        'Its attack ${_pct(disarmK.weaken[i])} for ${_num(disarmK.time)}s (boss ${_pct(disarmK.boss[i])})',
      ],
    AwakenSkill.impale => [
        'x${_dec(impaleK.hit[i])} thrust, reach +${_tiles(impaleK.reach / tile)}',
        "Stops a monster's skill (not a boss), or pins a strong one ${_dec(impaleK.pin[i])}s",
      ],
    AwakenSkill.spellbreaker => [
        'x${_dec(spellbreakerK.hit[i])} silver arrow takes monster buffs${spellbreakerK.spread[i] > 0 ? ' (${_tiles(spellbreakerK.spread[i] / tile)})' : ''}',
        'Boss and mini boss: half the time left',
      ],
    AwakenSkill.singularity => [
        'A ${_dec(singularityK.radius[i] / tile)}-tile well pulls monsters in for ${_dec(singularityK.time[i])}s',
        'Then it bursts for x${_dec(singularityK.hit[i])} damage',
      ],
    AwakenSkill.unbroken => [
        '${unbrokenK.low < 1 ? 'Under ${_share(unbrokenK.low)} HP' : 'Hurt'}: heals ${_share(unbrokenK.self[i])} HP, drops monster effects',
        'Troops beside it heal ${_share(unbrokenK.allies[i])} HP',
      ],
    AwakenSkill.consecration => [
        'Holy ground ${_tiles(consecrationK.radius[i] / tile)}, ${_num(consecrationK.time[i])}s',
        'Monsters on it take ${_num(consecrationK.hit[i])}x a second (undead x${_num(consecrationK.undead)})',
      ],
    AwakenSkill.phantomRush => [
        '${phantomRushK.cuts[i]} quick cuts x${_dec(phantomRushK.hit[i])} on the most hurt (${_tiles(phantomRushK.reach / tile)})',
        '+1 in Rampage, +1 on a kill; then back',
      ],
    AwakenSkill.skyfall => [
        'Leaps where troops fight (${_dec(skyfallK.near / tile)}-${_dec(skyfallK.far / tile)} tiles)',
        'x${_dec(skyfallK.hit[i])} slam (${_tiles(skyfallK.radius[i] / tile)}), shield ${_share(skyfallK.guard[i])} for ${_num(skyfallK.guardTime)}s',
      ],
    AwakenSkill.lifeline => [
        'Pulls ${lifelineK.lifts[i] > 1 ? '${lifelineK.lifts[i]} hurt troops' : 'a hurt troop'} (under ${_share(lifelineK.below)} HP) to its side',
        'Heals x${_dec(lifelineK.heal[i])} its heal',
      ],
  };
}

/// [s]'s numbers that grow at [level], short, for the next level's line in the book.
String _numbers(AwakenSkill s, int level) {
  final i = _at(level);
  return switch (s) {
    AwakenSkill.disarm => 'x${_num(disarmK.hit[i])}, ${_pct(disarmK.weaken[i])}',
    AwakenSkill.impale => 'x${_dec(impaleK.hit[i])}, pin ${_dec(impaleK.pin[i])}s',
    AwakenSkill.spellbreaker => 'x${_dec(spellbreakerK.hit[i])}, ${_tiles(spellbreakerK.spread[i] / tile)}',
    AwakenSkill.singularity => '${_tiles(singularityK.radius[i] / tile)}, x${_dec(singularityK.hit[i])}',
    AwakenSkill.unbroken => '${_share(unbrokenK.self[i])}, beside ${_share(unbrokenK.allies[i])}',
    AwakenSkill.consecration => '${_tiles(consecrationK.radius[i] / tile)}, ${_num(consecrationK.hit[i])}x',
    AwakenSkill.phantomRush => '${phantomRushK.cuts[i]} cuts x${_dec(phantomRushK.hit[i])}',
    AwakenSkill.skyfall => 'x${_dec(skyfallK.hit[i])}, ${_tiles(skyfallK.radius[i] / tile)}, shield ${_share(skyfallK.guard[i])}',
    AwakenSkill.lifeline => '${lifelineK.lifts[i] > 1 ? '${lifelineK.lifts[i]} troops, ' : ''}heal x${_dec(lifelineK.heal[i])}',
  };
}

/// Seconds to one decimal, without a trailing ".0": 18 → "18", 15.3 → "15.3", Bangkit 5's 13.005 → "13".
String _secs(double v) => _num((v * 10).round() / 10);

/// A share as a whole percent: 0.25 → "25%".
String _share(double k) => '${(k * 100).round()}%';

/// A number with up to two decimals and no trailing zeros: 1.25 → "1.25", 1.5 → "1.5", 2.0 → "2" ([_num] keeps
/// one).
String _dec(double v) => v.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');

/// A distance in tiles, as [_dec] writes it: "1 tile", "1.5 tiles" ([_count] keeps one decimal).
String _tiles(double v) => '${_dec(v)} ${v == 1 ? 'tile' : 'tiles'}';

/// Whether troop [u] is a phantom now: in Phantom Rush's dash or on its way home ([CarryLook.ghost]). No blow lands
/// on a phantom ([Game._hurt]), and the board draws it as a ghost the whole time (decisions-log 320; the owner: "Hantu:
/// kebal saat melompat"). The one carried troop that takes no blows ("Forced movement" in docs/units-and-combat.md).
bool isPhantom(Unit u) => u.side == Side.troop && u.move is Carry && (u.move as Carry).look == CarryLook.ghost;

/// The awakening skills' rules, casts and clocks (game.dart calls in from [Game._trySkill], [Game.startWave] and
/// [Game.useItem]).
extension AwakenSkills on Game {
  /// Troop [u]'s awakening skill and its level now, or null: a monster, a type with none built, or not awakened.
  (AwakenSkill, int)? awakenOf(Unit u) {
    if (u.side != Side.troop) return null;
    final s = awakenSkillOf(u.type);
    if (s == null) return null;
    final level = awakenLevel(u.type);
    return level > 0 ? (s, level) : null;
  }

  /// What troop [o] needs in MP for the skill it would cast next: its #10 skill's cost, or its awakening skill's
  /// when that is dearer (Gift of Mana gives to troops short of it).
  double mpWanted(Unit o) {
    final a = awakenSkills ? awakenOf(o) : null;
    return max(skillCost(o, troopSkills[o.type]?.cost ?? 0), a == null ? 0.0 : skillCost(o, a.$1.costAt(a.$2))); // as Spell Tax has them
  }

  /// Every living troop of an awakened type ([only]: of that type alone) gets its awakening skill ready, the i-th
  /// of its type (in the army's order) at t + (i % [awakenSlots]) × [awakenStagger]: at a wave's start, and at the
  /// awakening moment. A troop placed later comes ready at once, as its #10 skill does.
  void _staggerAwaken([String? only]) {
    final seen = <String, int>{};
    for (final u in troops) {
      if (!u.alive || (only != null && u.type != only)) continue;
      final a = awakenOf(u);
      if (a == null) continue;
      final i = seen[u.type] = (seen[u.type] ?? -1) + 1;
      u
        ..awakenSkillAt = t - skillCd(a.$1.cooldownAt(a.$2)) + (i % awakenSlots) * awakenStagger
        ..awakenThinkAt = double.negativeInfinity;
    }
  }

  /// [type] just awakened ([useItem]): each of its living troops pops its awakening skill's name with the new
  /// numeral, and the skill comes ready 0–3 s apart across them ([_staggerAwaken]), mid-wave too.
  void _awakened(String type) {
    if (!awakenSkills) return;
    _staggerAwaken(type);
    for (final u in troops) {
      if (!u.alive || u.type != type) continue;
      if (awakenOf(u) case (final s, final level)?) awakenCasts.add((u, s, level));
    }
  }

  /// [s] at [level] may be cast by [u] now, MP and its rule aside: its cooldown is over, and a skill that holds
  /// monsters waits out a march.
  bool _awakenReady(Unit u, AwakenSkill s, int level) => t - u.awakenSkillAt >= skillCd(s.cooldownAt(level)) && !(marching && s.holds);

  /// [s]'s rule holds for [u] now ([wantsAwakenSkill]); after a no it isn't asked again for [awakenThink] s.
  bool _awakenWanted(Unit u, AwakenSkill s, int level) {
    if (t < u.awakenThinkAt) return false;
    if (wantsAwakenSkill(u, s, level)) return true;
    u.awakenThinkAt = t + awakenThink;
    return false;
  }

  /// [u]'s #10 skill, costing [cost], leaves the MP to its awakening skill: that one is ready and wanted, and what
  /// the #10 skill would leave doesn't pay for it. The awakening skill comes first on the MP (it waits the longest
  /// and does the most), so a troop saves for it as a Hero saves for its own skill ([HeroSkills._savingUp]); when
  /// the MP pays for both, the #10 skill casts first and the awakening skill on the next tick.
  bool _savingForAwaken(Unit u, double cost) {
    if (!awakenSkills) return false;
    final a = awakenOf(u);
    if (a == null) return false;
    final (s, level) = a;
    return _awakenReady(u, s, level) && u.mp - cost < skillCost(u, s.costAt(level)) && _awakenWanted(u, s, level);
  }

  /// Troop [u] casts its awakening skill when its type has one and has awakened, it is ready ([_awakenReady]), it
  /// has the MP and its rule holds, and (a Hero) it isn't saving up for its Hero skill. It pays the MP, pops its
  /// name ([awakenCasts]) and is logged ([AwakenSkillCast]); winding up, it claims what it aims at ([_awakenClaim]).
  /// Whether it cast.
  bool _tryAwakenSkill(Unit u, bool hero) {
    final a = awakenOf(u);
    if (a == null) return false;
    final (s, level) = a;
    final cost = skillCost(u, s.costAt(level)); // more under the Bayangan Spell Tax (omen.dart)
    if (!_awakenReady(u, s, level) || u.mp < cost || !_awakenWanted(u, s, level)) return false;
    if (hero && _savingUp(u)) return false; // its Hero skill is ready and wanted, only short of MP: that first
    u
      ..mp -= cost
      ..awakenSkillAt = t;
    awakenCasts.add((u, s, level));
    _emit(AwakenSkillCast(wave, t, name: u.name, type: u.type, skill: s, level: level));
    final (claims, at) = skillWinds ? _awakenClaim(u, s, level) : (const <Unit>[], null); // only a wind-up holds a claim
    _windUp(u, WindKind.awaken, troopSkillStrips[u.type], awaken: s, level: level, claims: claims, at: at); // its type's strip, then it lands (skill_strips.dart)
    return true;
  }

  /// What [u]'s wind-up of [s] at [level] claims (decisions-log 320): the foe it aims at (Disarm, Impale, Spellbreaker,
  /// Singularity's centre), the troops it would lift (Lifeline), and the spot of its ground, well or leap (Consecration,
  /// Singularity, Skyfall). Others of its type skip a claimed foe or troop, and a spot as if its ground, well or leap were
  /// there already ([_claimed], [_claimedSpots]): with the 0.3 s wind-up (decisions-log 299) they all picked the same
  /// one, and all but the first fizzled on their blow, MP and cooldown paid (84% of Spellbreaker's casts, 85% of
  /// Lifeline's at w41-70). Unbroken and Phantom Rush claim nothing.
  (List<Unit>, Point<double>?) _awakenClaim(Unit u, AwakenSkill s, int level) => switch (s) {
        AwakenSkill.disarm => ([?_disarmTarget(u, level)], null),
        AwakenSkill.impale => ([?_impaleTarget(u)?.$1], null),
        AwakenSkill.spellbreaker => ([?_spellbreakerTarget(u)], null),
        AwakenSkill.singularity => switch (_singularityCentre(u, level)) { final c? => ([c], c.pos), null => (const [], null) },
        AwakenSkill.lifeline => (_lifelines(u, level), null),
        AwakenSkill.consecration => (const [], u.pos),
        AwakenSkill.skyfall => (const [], _skyfallSpot(u, level)),
        AwakenSkill.unbroken || AwakenSkill.phantomRush => (const [], null),
      };

  /// The foes or troops another troop's wind-up of [s] claims now ([_awakenClaim]).
  Set<Unit> _claimed(AwakenSkill s) => {
        for (final b in troops)
          if (b.alive && b.troopWind != null && b.troopWind!.awaken == s) ...b.troopWind!.claims,
      };

  /// The spots other troops' wind-ups of [s] claim now ([_awakenClaim]), each with its caster's level.
  List<(Point<double>, int)> _claimedSpots(AwakenSkill s) => [
        for (final b in troops)
          if (b.alive && b.troopWind?.awaken == s && b.troopWind!.at != null) (b.troopWind!.at!, b.troopWind!.level),
      ];

  /// Whether troop [u] has a foe within its reach (Unbroken's first rule; alone on its blow, decisions-log 320).
  bool _foeInReach(Unit u) => enemies.any((o) => o.alive && o.entered && o.pos.distanceTo(u.pos) <= u.stats.range);

  /// Whether troop [u]'s awakening skill [s] at [level] would do something now, by its rule (MP, cooldown and the
  /// march aside).
  bool wantsAwakenSkill(Unit u, AwakenSkill s, int level) => switch (s) {
        AwakenSkill.disarm => _disarmTarget(u, level) != null,
        AwakenSkill.impale => _impaleTarget(u, t - u.awakenSkillAt - skillCd(s.cooldownAt(level))) != null,
        AwakenSkill.spellbreaker => _spellbreakerTarget(u) != null,
        AwakenSkill.singularity => _singularityCentre(u, level) != null,
        AwakenSkill.unbroken => _wantsUnbroken(u),
        AwakenSkill.consecration => _wantsConsecration(u, level),
        AwakenSkill.phantomRush => _wantsRush(u),
        AwakenSkill.skyfall => _skyfallSpot(u, level) != null,
        AwakenSkill.lifeline => _lifelines(u, level).isNotEmpty,
      };

  /// What [s] at [level] does, cast by [u] (the `<id>K` records hold the numbers). Every blow goes through [_hurt]
  /// with [u] as the attacker, like a #10 skill's.
  void _castAwakenSkill(Unit u, AwakenSkill s, int level) {
    final i = _at(level), dmg = u.stats.dmg;
    switch (s) {
      case AwakenSkill.disarm:
        final o = _disarmTarget(u, level)!;
        rings.add(Ring.over(o, radius: 8, since: t, look: RingLook.shards, duration: disarmK.look));
        impacts.add((o.pos, _fxOf(u, 'hit_soldier_big')));
        u.attackedAt = t; // the swing
        _face(u, o.pos.x - u.pos.x, 0);
        o.disarmedAt = t;
        _hurt(o, dmg * disarmK.hit[i], Hit.skill, u);
        if (o.alive) addEffect(o, Status.weaken, disarmK.time, k: o.tier == Tier.boss ? disarmK.boss[i] : disarmK.weaken[i], by: u);
        sfx.add(Sfx.sword);
      case AwakenSkill.impale:
        final (o, broke) = _impaleTarget(u)!; // its clock just restarted: no holding now
        u.attackedAt = t; // the thrust; the lancer stays where it stands
        _face(u, o.pos.x - u.pos.x, 0);
        beams.add(Beam([u.pos, o.pos], since: t, duration: impaleK.shaft, look: BeamLook.lunge));
        impacts.add((o.pos, _fxOf(u, 'hit_lancer_big')));
        _hurt(o, dmg * impaleK.hit[i], Hit.skill, u);
        if (broke) {
          o.interruptedAt = t;
          _cancelWind(o); // its cooldown started with the wind-up: the skill waits it out
          if (o.alive) _stunFor(o, impaleK.stagger);
          rings.add(Ring(o.pos, radius: 10, since: t, look: RingLook.shatter, duration: impaleK.shatter));
          sfx.add(Sfx.hit);
        } else if (o.alive) {
          addEffect(o, Status.impaled, impaleK.pin[i], k: o.tier == Tier.boss ? impaleK.boss : impaleK.slow, by: u);
        }
        sfx.add(Sfx.sword);
      case AwakenSkill.spellbreaker:
        final o = _spellbreakerTarget(u)!, spread = spellbreakerK.spread[i];
        u.attackedAt = t;
        _face(u, o.pos.x - u.pos.x, 0);
        shots.add(Shot.special(u, o, u.pos, dmg: dmg * spellbreakerK.hit[i], speed: spellbreakerK.speed, look: ShotLook.silver, onHit: (h) {
          for (final f in {h, ..._foesNear(h.pos, spread)}) {
            if (f.alive) _strip(f);
          }
          rings.add(Ring(h.pos, radius: max(spread, spellbreakerK.mark), since: t, look: RingLook.dispel, duration: spellbreakerK.ring));
          sfx.add(Sfx.hit);
        }));
        sfx.add(Sfx.dagger);
      case AwakenSkill.singularity:
        final at = _singularityCentre(u, level)!.pos, pull = singularityK.pull[i], burst = dmg * singularityK.hit[i];
        late final Zone well;
        well = Zone(u, at, since: t, duration: singularityK.time[i], radius: singularityK.radius[i], side: Side.enemy,
            look: ZoneLook.singularity, inside: (o) => _pull(well, o, pull));
        zones.add(well);
        u.attackedAt = t;
        _face(u, at.x - u.pos.x, 0);
        later(singularityK.time[i], () {
          // The well collapses: a flash at its core and a blow to each foe near it.
          rings.add(Ring(at, radius: well.radius, since: t, look: RingLook.implode, duration: singularityK.implode));
          impacts.add((at, _fxOf(u, 'hit_wizard_big')));
          for (final o in _foesNear(at, singularityK.burst)) {
            impacts.add((o.pos, _fxOf(u, 'hit_wizard')));
            _hurt(o, burst, Hit.skill, u.alive ? u : null);
          }
          sfx.add(Sfx.hit);
        });
        sfx.add(Sfx.magic);
      case AwakenSkill.unbroken:
        rings.add(Ring.over(u, radius: 14, since: t, look: RingLook.unchain, duration: unbrokenK.look));
        u.effects.removeWhere(_hindrance); // its rings at its feet go with them
        _healTroop(u, u.maxHp * unbrokenK.self[i], HealSrc.unbroken);
        impacts.add((u.pos, _fxOf(u, 'heal')));
        for (final o in _alliesNear(u.pos, unbrokenK.reach)) {
          if (o == u || o.hp >= healCeil(o)) continue; // at its heal ceiling: Scar's (omen.dart)
          _healTroop(o, o.maxHp * unbrokenK.allies[i], HealSrc.unbroken);
          o.healedAt = t;
          impacts.add((o.pos, _fxOf(u, 'heal')));
        }
        sfx.add(Sfx.magic);
      case AwakenSkill.consecration:
        final hit = dmg * consecrationK.hit[i], undead = consecrationK.undead;
        zones.add(Zone(u, u.pos, since: t, duration: consecrationK.time[i], radius: consecrationK.radius[i], side: Side.enemy,
            look: ZoneLook.consecrate, pulse: (o) {
          impacts.add((o.pos, o.stats.dark ? 'holy' : _fxOf(u, 'hit_knight_templar')));
          _holy = true; // holy ground, as [MonsterSkillSignatures._holyHurt]: no skeleton reassembles on it, and a heap ends
          _hurt(o, o.stats.dark ? hit * undead : hit, Hit.skill, u.alive ? u : null);
          _holy = false;
        }));
        sfx.add(Sfx.magic);
      case AwakenSkill.phantomRush:
        _rush(u, _rushRound(u), u.pos, cuts: phantomRushK.cuts[i] + (t < u.frenzyUntil ? 1 : 0), hit: phantomRushK.hit[i]);
      case AwakenSkill.skyfall:
        final p = _skyfallSpot(u, level)!, r = skyfallK.radius[i];
        _face(u, p.x - u.pos.x, 0);
        u.move = Carry(u.pos, _onField(p), t, t + skyfallK.time, lift: skyfallK.lift, look: CarryLook.skyfall, radius: r, onEnd: () {
          rings.add(Ring(u.pos, radius: r, since: t, look: RingLook.crater, duration: skyfallK.crater));
          impacts.add((u.pos, _fxOf(u, 'hit_armored_axeman_big')));
          u.attackedAt = t; // the slam
          for (final o in _foesNear(u.pos, r)) {
            impacts.add((o.pos, _fxOf(u, 'hit_armored_axeman')));
            _hurt(o, u.stats.dmg * skyfallK.hit[i], Hit.skill, u);
          }
          _guard(u, skyfallK.guard[i], skyfallK.guardTime); // the plain guard ring
          sfx.add(Sfx.sword);
        });
      case AwakenSkill.lifeline:
        final heal = _healOf(u) * lifelineK.heal[i], lifted = _lifelines(u, level);
        _face(u, lifted.first.pos.x - u.pos.x, 0);
        for (final o in lifted) {
          final spot = beside(u, o.pos, lifelineK.gap);
          beams.add(Beam.between([u, o], since: t, duration: lifelineK.tether, look: BeamLook.tether));
          // Set down beside the priest, never behind the back line (one already behind it isn't taken further).
          o.move = Carry(o.pos, _onField(Point(max(spot.x, min(_troopRear, o.pos.x)), spot.y)), t, t + lifelineK.time, lift: lifelineK.lift,
              onEnd: () {
            if (!u.alive) return; // its priest fell meanwhile: set down, unhealed
            _healTroop(o, heal, HealSrc.lifeline);
            o
              ..healedAt = t
              ..waitFrom = t; // come to its healer: the fall-back brain counts its wait from now
            impacts.add((o.pos, _fxOf(u, 'heal')));
            rings.add(Ring.over(o, radius: 10, since: t, look: RingLook.bloom, duration: lifelineK.bloom));
          });
        }
        sfx.add(Sfx.magic);
    }
  }

  /// Impale's foe for lancer [u] ([impaleK]), and whether the lunge breaks its wind-up (else it pins): a foe in its
  /// reach + [impaleK].reach (a taunted lancer: only its taunter) winding up a skill it can break ([_breakable]),
  /// the highest ranked, then the nearest, then the first placed; else a strong foe not pinned yet, the highest
  /// ranked, then the most HP, then the nearest, unless one it could break stands within [impaleK].watch and its
  /// skill has been ready less than [impaleK].hold s ([readyFor]). Null: none.
  (Unit, bool)? _impaleTarget(Unit u, [double readyFor = double.infinity]) {
    final reach = u.stats.range + impaleK.reach, taunter = u.effects.isEmpty ? null : _taunter(u), taken = _claimed(AwakenSkill.impale);
    Unit? broken, pinned;
    var (bd, pd, watched) = (0.0, 0.0, false);
    for (final o in enemies) {
      if (!o.alive || !o.entered || (taunter != null && o != taunter)) continue;
      final d = o.pos.distanceTo(u.pos);
      if (d <= impaleK.watch && monsterSkills && monsterSkillsOf(o).any((s) => _breakable(o, s))) watched = true;
      if (d > reach || taken.contains(o)) continue; // another lancer's lunge is on its way to it
      if (o.winding case final s? when _breakable(o, s) && t >= o.stunUntil) {
        if (broken == null || o.tier.index > broken.tier.index || (o.tier == broken.tier && (d < bd || (d == bd && o.id < broken.id)))) {
          (broken, bd) = (o, d);
        }
      } else if (HeroSkills._strong(o) && !under(o, Status.impaled)) {
        if (pinned == null ||
            o.tier.index > pinned.tier.index ||
            (o.tier == pinned.tier && (o.hp > pinned.hp || (o.hp == pinned.hp && d < pd)))) {
          (pinned, pd) = (o, d);
        }
      }
    }
    if (broken != null) return (broken, true);
    if (pinned == null) return null;
    return watched && readyFor < impaleK.hold ? null : (pinned, false); // holding the lance for a break
  }

  /// Whether Impale can break monster [o]'s skill [s] as it winds up: one that comes again (a finite cooldown, so
  /// a broken once-only skill isn't lost for good), on a monster not of the boss rank nor a necromancer (the
  /// escort's high elite neither), not broken in the last [impaleK].window s.
  bool _breakable(Unit o, MonsterSkill s) =>
      s.cooldown.isFinite && o.tier != Tier.boss && o.type != boss && t - o.interruptedAt >= impaleK.window;

  /// Spellbreaker's foe for archer [u] ([spellbreakerK]): of the foes in its range that no silver arrow is flying
  /// at, with something to strip ([_strippable]), the highest ranked, then the one with the most, then the nearest.
  Unit? _spellbreakerTarget(Unit u) {
    Unit? best;
    var most = 0;
    final taken = _claimed(AwakenSkill.spellbreaker);
    for (final o in _foesNear(u.pos, u.stats.range)) {
      if (taken.contains(o)) continue; // another archer is drawing a silver arrow at it
      final n = _strippable(o);
      if (n == 0 || (best != null && (o.tier.index < best.tier.index || (o.tier == best.tier && n <= most)))) continue;
      if (shots.any((s) => s.look == ShotLook.silver && s.target == o)) continue; // one on its way already
      (best, most) = (o, n);
    }
    return best;
  }

  /// Whether Spellbreaker only halves what is left of a buff or guard on monster [o] rather than taking it off:
  /// [o] is a mini boss or of the boss rank, or the buff [e] is the boss rank's gift (its moments' Rally, Howl).
  bool _halvesOnly(Unit o, [Effect? e]) => o.tier == Tier.miniBoss || o.tier == Tier.boss || e?.by?.tier == Tier.boss;

  /// Whether Spellbreaker would strip effect [e] of kind [s] off monster [o] now: a kind it strips, not a troop's,
  /// running; one it only halves not halved yet.
  bool _stripsOff(Unit o, Status s, Effect e) =>
      spellbreakerStrips.contains(s) && e.by?.side != Side.troop && t < e.until && !(e.halved && _halvesOnly(o, e));

  /// How many things Spellbreaker would take off (or halve on) monster [o] with [spellbreakerK].left s or more to
  /// run: its buffs ([_stripsOff]) and its guard.
  int _strippable(Unit o) {
    var n = 0;
    for (final MapEntry(key: s, value: e) in o.effects.entries) {
      if (_stripsOff(o, s, e) && e.until - t >= spellbreakerK.left) n++;
    }
    if (o.guardUntil - t >= spellbreakerK.left && !(o.guardHalved == o.guardUntil && _halvesOnly(o))) n++;
    return n;
  }

  /// A silver arrow lands on monster [o] (or near it, [spellbreakerK].spread): its buffs ([_stripsOff]) and its
  /// guard come off, or, where Spellbreaker only halves ([_halvesOnly]), half of what is left of each goes, once.
  /// Their rings go with them. A monster that lost something gets the Bayangan Renewal's shield once ([Omens._omenRenewal]).
  void _strip(Unit o) {
    var took = false;
    for (final MapEntry(key: s, value: e) in o.effects.entries.toList()) {
      if (!_stripsOff(o, s, e)) continue;
      took = true;
      if (!_halvesOnly(o, e)) {
        o.effects.remove(s);
      } else {
        e
          ..until = t + (e.until - t) / 2
          ..halved = true;
      }
    }
    if (t < o.guardUntil) {
      if (!_halvesOnly(o)) {
        o.guardUntil = t;
        took = true;
      } else if (o.guardHalved != o.guardUntil) {
        o.guardUntil = o.guardHalved = t + (o.guardUntil - t) / 2;
        took = true;
      }
    }
    if (took) _omenRenewal(o); // Renewal (omen.dart)
  }

  /// Whether Singularity may pull monster [o] ([singularityK]): on the field, not the boss rank, not carried, and
  /// not in a well already.
  bool _pullable(Unit o) => o.alive && o.entered && o.tier != Tier.boss && o.move == null && !_inWell(o);

  /// Whether monster [o] stands in an open Singularity.
  bool _inWell(Unit o) => zones.any((z) => z.look == ZoneLook.singularity && t < z.until && z.covers(o));

  /// Singularity's centre for wizard [u] at [level]: of the foes in its range it may pull ([_pullable]), the one with
  /// the most such foes within the well's radius (itself too), [singularityK].crowd at least; then the nearest,
  /// then the first placed. Null: none.
  Unit? _singularityCentre(Unit u, int level) {
    final r = singularityK.radius[_at(level)], wells = _claimedSpots(AwakenSkill.singularity);
    // Not in an open well, nor in one another wizard is winding up ([_awakenClaim]).
    final free = [
      for (final o in enemies)
        if (_pullable(o) && !wells.any((w) => o.pos.distanceTo(w.$1) <= singularityK.radius[_at(w.$2)])) o,
    ];
    if (free.length < singularityK.crowd) return null;
    Unit? best;
    var (most, bd) = (0, 0.0);
    for (final c in free) {
      final d = c.pos.distanceTo(u.pos);
      if (d > u.stats.range) continue;
      var n = 0;
      for (final o in free) {
        if (o.pos.distanceTo(c.pos) <= r) n++;
      }
      if (n < singularityK.crowd || n < most || (n == most && (d > bd || (d == bd && c.id > best!.id)))) continue;
      (best, most, bd) = (c, n, d);
    }
    return best;
  }

  /// [Zone.inside], every tick: monster [o] in Singularity [well] drifts toward its centre at [speed] a second × its
  /// [shoveShare] ([singularityK]), never closer than [singularityK].core. The y part always; the x part only away
  /// from the base, and not for one with a troop in its reach (it isn't dragged off its fight). Not while the wave
  /// marches, not while it is carried, and by the oldest well over it only.
  void _pull(Zone well, Unit o, double speed) {
    final share = shoveShare(o);
    if (marching || share <= 0 || o.move != null) return;
    if (zones.firstWhere((z) => z.look == ZoneLook.singularity && z.covers(o)) != well) return; // another pulls it
    final d = well.at - o.pos, len = d.magnitude;
    if (len <= singularityK.core) return;
    final step = d * (min(speed * share * _dt, len - singularityK.core) / len);
    final fighting = troops.any((b) => b.alive && b.entered && reaches(o, b));
    o.pos = _onField(Point(o.pos.x + (fighting ? 0.0 : max(0.0, step.x)), o.pos.y + step.y));
  }

  /// Unbroken's rule: a foe in [u]'s reach, and it is below [unbrokenK].low of its HP and was hit in the last
  /// [unbrokenK].within s, or below [unbrokenK].hindered under a monster's hindrance.
  bool _wantsUnbroken(Unit u) {
    if (!enemies.any((o) => o.alive && o.entered && o.pos.distanceTo(u.pos) <= u.stats.range)) return false;
    final share = u.hp / u.maxHp;
    return (share < unbrokenK.low && t - u.hurtAt < unbrokenK.within) || (share < unbrokenK.hindered && u.effects.entries.any((e) => _hindrance(e.key, e.value)));
  }

  /// Whether effect [e] of kind [s] on a troop is a monster's hindrance Unbroken throws off ([unbrokenFrees]): one a
  /// monster put on it, running now.
  bool _hindrance(Status s, Effect e) =>
      t < e.until && e.by?.side == Side.enemy && (unbrokenFrees.contains(s) || (s == Status.haste && e.k > 1));

  /// Consecration's rule at [level]: [consecrationK].crowd+ foes within its radius, and no Consecration's centre
  /// within [consecrationK].apart × that radius of [u] (so two never lie more than half over each other).
  bool _wantsConsecration(Unit u, int level) {
    final r = consecrationK.radius[_at(level)];
    if (zones.any((z) => z.look == ZoneLook.consecrate && t < z.until && z.at.distanceTo(u.pos) <= consecrationK.apart * r)) return false;
    if (_claimedSpots(AwakenSkill.consecration).any((c) => c.$1.distanceTo(u.pos) <= consecrationK.apart * r)) return false; // one winding up
    var n = 0;
    for (final o in enemies) {
      if (o.alive && o.entered && o.pos.distanceTo(u.pos) <= r && ++n >= consecrationK.crowd) return true;
    }
    return false;
  }

  /// Disarm's foe: of the foes in [u]'s reach (a taunted soldier: only its taunter) with at least [disarmK].worth ×
  /// its damage in HP, not already weakened as strongly as Disarm would and not Disarmed in the last [disarmK].again
  /// s, the highest ranked, then the one that hits hardest, then the nearest.
  Unit? _disarmTarget(Unit u, int level) {
    final i = _at(level), taunter = u.effects.isEmpty ? null : _taunter(u), taken = _claimed(AwakenSkill.disarm);
    Unit? best;
    for (final o in _foesNear(u.pos, u.stats.range)) {
      if ((taunter != null && o != taunter) || taken.contains(o)) continue; // another soldier's Disarm is on its way to it
      final k = o.tier == Tier.boss ? disarmK.boss[i] : disarmK.weaken[i];
      if (o.hp < u.stats.dmg * disarmK.worth || t - o.disarmedAt < disarmK.again || effectK(o, Status.weaken) <= k) continue;
      if (best == null || o.tier.index > best.tier.index || (o.tier == best.tier && o.stats.dmg > best.stats.dmg)) best = o;
    }
    return best;
  }

  /// A foe Phantom Rush cuts: living, on the field, and not a heap of bones (Reassemble: only holy blows hurt it).
  bool _rushable(Unit o) => o.alive && o.entered && t >= o.downUntil;

  /// Phantom Rush's rule: a foe in [u]'s reach and [phantomRushK].crowd+ within [phantomRushK].reach, while it isn't
  /// taunted or falling back.
  bool _wantsRush(Unit u) {
    if (u.retreating || (u.effects.isNotEmpty && _taunter(u) != null)) return false;
    var inReach = false, n = 0;
    for (final o in enemies) {
      if (!_rushable(o)) continue;
      final d = o.pos.distanceTo(u.pos);
      inReach |= d <= u.stats.range;
      if (d <= phantomRushK.reach) n++;
    }
    return inReach && n >= phantomRushK.crowd;
  }

  /// Phantom Rush's round: the foes within [phantomRushK].reach of [u], the most wounded by HP share first, then the
  /// nearest, then the first placed.
  List<Unit> _rushRound(Unit u) => [
        for (final o in enemies)
          if (_rushable(o) && o.pos.distanceTo(u.pos) <= phantomRushK.reach) o
      ]..sort((a, b) {
          final byShare = (a.hp / a.maxHp).compareTo(b.hp / b.maxHp);
          if (byShare != 0) return byShare;
          final byNear = a.pos.distanceTo(u.pos).compareTo(b.pos.distanceTo(u.pos));
          return byNear != 0 ? byNear : a.id.compareTo(b.id);
        });

  /// Phantom Rush's next dash for [u], [done] of its [cuts] cuts made: to [phantomRushK].gap beside the first living
  /// foe of [round] from its place [next] on (round again after the last), and a cut of [hit] × its damage there
  /// ([killed]: a cut of this cast already killed, so a kill earns no more); then the next dash. With its cuts made,
  /// or no foe of the round left, it goes back [home].
  void _rush(Unit u, List<Unit> round, Point<double> home, {required int cuts, required double hit, int done = 0, int next = 0, bool killed = false}) {
    final at = done >= cuts ? null : [for (var k = 0; k < round.length; k++) (next + k) % round.length].where((j) => _rushable(round[j])).firstOrNull;
    if (at == null) {
      u.move = Carry(u.pos, home, t, t + phantomRushK.home, lift: phantomRushK.lift, look: CarryLook.ghost);
      return;
    }
    final foe = round[at], to = beside(foe, u.pos, phantomRushK.gap);
    _face(u, foe.pos.x - u.pos.x, 0);
    beams.add(Beam([u.pos, to], since: t, duration: phantomRushK.streak, look: BeamLook.rush));
    u.move = Carry(u.pos, to, t, t + phantomRushK.dash, lift: phantomRushK.lift, look: CarryLook.ghost, onEnd: () {
      var (all, kill) = (cuts, killed);
      if (_rushable(foe)) {
        _face(u, foe.pos.x - u.pos.x, 0);
        u.attackedAt = t; // the cut's swing
        rings.add(Ring.over(foe, radius: 8, since: t, look: RingLook.crossCut, duration: phantomRushK.cross));
        impacts.add((foe.pos, _fxOf(u, 'hit_swordsman')));
        _hurt(foe, u.stats.dmg * hit, Hit.skill, u);
        if (!foe.alive && !kill) (all, kill) = (all + 1, true); // a kill: one cut more, once
        sfx.add(done + 1 >= all ? Sfx.sword : Sfx.dagger); // the last cut rings like a sword
      }
      _rush(u, round, home, cuts: all, hit: hit, done: done + 1, next: at + 1, killed: kill);
    });
  }

  /// Skyfall's spot for [u] at [level] ([skyfallK]): beside one of the nearest foes [skyfallK].near–[skyfallK].far
  /// away and ahead, no further ahead than the front-most troop that fought near it, with [skyfallK].crowd+ foes within
  /// its radius and no other axeman leaping there; the most foes, then the nearest foe. Null: none, or [u] can't go
  /// (below [skyfallK].above of its HP, taunted, falling back, or a foe in its reach).
  Point<double>? _skyfallSpot(Unit u, int level) {
    if (u.hp < u.maxHp * skyfallK.above || u.retreating || (u.effects.isNotEmpty && _taunter(u) != null)) return null;
    final r = skyfallK.radius[_at(level)], near = _foesNear(u.pos, skyfallK.far), leaps = _claimedSpots(AwakenSkill.skyfall);
    if (near.isNotEmpty && near.first.pos.distanceTo(u.pos) <= u.stats.range) return null; // in a fight already
    Point<double>? best;
    var most = 0;
    for (final o in near.where((o) => o.pos.x > u.pos.x && o.pos.distanceTo(u.pos) >= skyfallK.near).take(skyfallK.look)) {
      var p = beside(o, u.pos, skyfallK.gap);
      double? front;
      for (final b in troops) {
        if (b == u || !b.alive || !b.entered || t - b.attackedAt >= skyfallK.fought || b.pos.distanceTo(p) > r + tile) continue;
        front = max(front ?? b.pos.x, b.pos.x);
      }
      if (front == null) continue; // no troop fights there
      if (p.x > front) p = Point(front, p.y); // never past the front melee
      if (troops.any((b) => b != u && b.alive && b.move is Carry && (b.move as Carry).look == CarryLook.skyfall && (b.move as Carry).to.distanceTo(p) <= r) ||
          leaps.any((c) => c.$1.distanceTo(p) <= r)) {
        continue; // another axeman lands there, or winds up to
      }
      var n = 0;
      for (final f in enemies) {
        if (f.alive && f.entered && f.pos.distanceTo(p) <= r) n++;
      }
      if (n >= skyfallK.crowd && n > most) (best, most) = (p, n); // nearest first: a tie stays with the nearer
    }
    return best;
  }

  /// Whether troop [o] is one priest [u]'s Lifeline would lift ([lifelineK]): another troop in its reach and
  /// [lifelineK].far+ from it, on the field, neither carried nor braced nor holding its ground, below
  /// [lifelineK].below of its HP, hit in the last [lifelineK].within s, with a foe within [lifelineK].near.
  bool _inPeril(Unit u, Unit o) {
    if (o == u || !o.alive || !o.entered || o.hp >= o.maxHp * lifelineK.below || t - o.hurtAt >= lifelineK.within || _held(o)) return false;
    final d = o.pos.distanceTo(u.pos);
    if (d > u.stats.range || d < lifelineK.far || (o.effects.isNotEmpty && under(o, Status.holdGround))) return false;
    return enemies.any((e) => e.alive && e.entered && e.pos.distanceTo(o.pos) <= lifelineK.near);
  }

  /// The troops priest [u]'s Lifeline at [level] lifts: of those in peril ([_inPeril]) that no other priest's wind-up
  /// claims ([_claimed]), the [lifelineK].lifts most hurt by HP share (the first placed on a tie).
  List<Unit> _lifelines(Unit u, int level) {
    final taken = _claimed(AwakenSkill.lifeline); // another priest is winding up to lift it
    return ([
      for (final o in troops)
        if (!taken.contains(o) && _inPeril(u, o)) o,
    ]..sort((a, b) {
            final byShare = (a.hp / a.maxHp).compareTo(b.hp / b.maxHp);
            return byShare != 0 ? byShare : a.id.compareTo(b.id);
          }))
        .take(lifelineK.lifts[_at(level)])
        .toList();
  }
}
