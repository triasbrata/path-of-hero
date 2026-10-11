// A troop's cleanse and the monsters' noHeal (catalog step 0g, decisions-log 184; lib/cleanse.dart, lib/heal.dart;
// docs/units-and-combat.md "Cleanse and noHeal"). The cleanse: a table over every kind a monster puts on a troop (each
// monster skill's own scene: its marks are bad, and a cleanse ends every one and leaves the troop's own), a table over
// every status put on by a troop, a Pusaka or itself (never ended), the order of a cleanse of a few, and a static guard
// (only the monster skills mark an effect bad, and every effect they put on that isn't marked is listed: their own).
// noHeal: a table over every monster heal site (each heals through the funnel, and lands as 0 under it), Reassemble
// under it; the static guard over every HP write is heal_funnel_test.dart's. The engine's two Fx, `cleanse` and
// `noHeal`, each through a real trigger on a row swapped in. The rows that grant them (Salt Charm's cleanse and the
// others; Grave Seal's noHeal, batch G-3) are their batches' pusaka_*_test.dart's.
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';

import 'hero_skill_helpers.dart';

/// A game with no troop, Hero or awakening skills cast: what happens is the monsters' and the rules' doing.
Game plain([Random? rng]) => bareGame(rng)
  ..skills = false
  ..heroSkills = false
  ..awakenSkills = false;

/// A wave on (of [wave], nothing left to spawn) in a [plain] game, and a monster of [type] and [tier] at [at] that casts
/// but never strikes ([Unit.cd]); a [still] one never walks either (a slow of 0, boss_skills_test.dart's).
(Game, Unit) casterAt(String type, Tier tier, {Point<double> at = const Point(250.0, 60.0), int wave = 1, bool still = false}) {
  final g = plain()..wave = wave - 1;
  g
    ..startWave()
    ..queue.clear();
  final u = g.monster(type, tier, at)
    ..entered = true
    ..cd = hold
    ..summonCd = hold;
  g.units.add(u);
  if (still) g.addEffect(u, Status.slow, hold, k: 0);
  return (g, u);
}

/// A troop of [type] standing at [at] that never moves or fights ([hold]); [hp]: its max HP and HP instead.
Unit troopAt(Game g, String type, Point<double> at, {double? hp}) {
  final u = Unit(Side.troop, type, troopTypes[type]!, at)
    ..entered = true
    ..busyUntil = hold;
  if (hp != null) {
    u
      ..maxHp = hp.round()
      ..hp = hp;
  }
  g.units.add(u);
  return u;
}

/// Ticks until monster [u] has begun [skill] (any, when null) and then cast it; fails if it never began.
void lands(Game g, Unit u, [MonsterSkill? skill]) {
  for (var i = 0; i < 60 && (skill == null ? u.winding == null : u.winding != skill); i++) {
    g.tick(0.05);
  }
  expect(u.winding, skill ?? isNotNull, reason: '${u.type} began ${skill?.title ?? 'its skill'}');
  for (var i = 0; i < 40 && u.winding != null; i++) {
    g.tick(0.05);
  }
  expect(u.winding, isNull, reason: '${u.type} cast ${skill?.title ?? 'its skill'}');
}

/// Ticks [g] until [done] (at most [s] seconds).
void tickUntil(Game g, bool Function() done, [double s = 5]) {
  final end = g.t + s;
  while (!done() && g.t < end) {
    g.tick(0.05);
  }
}

/// [by]'s arrow of [dmg] on [o], landing this tick (not holy).
void arrow(Game g, Unit by, Unit o, double dmg) {
  g.shots.add(Shot.special(by, o, o.pos - const Point(1.0, 0), dmg: dmg, speed: 200));
  g.tick(0.05);
}

/// Whether a Soul Drain's beam is on troop [o].
bool drained(Game g, Unit o) => g.beams.any((b) => b.look == BeamLook.drain && b.follow?.last == o);

/// What a monster's skill left on troop [o]: its statuses, whether it stunned it, whether it drains it; [hurts]: what it
/// left would go on taking HP (a bleed, a drain).
typedef Marked = ({Game g, Unit o, Set<Status> on, bool stun, bool drain, bool hurts});

/// Each kind a monster puts on a troop, by the skill that does it (the monster skill tests' set-ups).
final Map<String, Marked Function()> kinds = {
  'Screech: daze': () {
    final (g, bat) = casterAt('bat', Tier.miniBoss, still: true);
    final o = troopAt(g, 'knight', bat.pos - const Point(12.0, 8));
    troopAt(g, 'knight', bat.pos - const Point(12.0, -8));
    troopAt(g, 'soldier', bat.pos - const Point(20.0, 0));
    lands(g, bat, MonsterSkill.screech);
    return (g: g, o: o, on: {Status.daze}, stun: false, drain: false, hurts: false);
  },
  'Barbed Arrow: bleed': () {
    final (g, a) = casterAt('skeleton_archer', Tier.miniBoss, still: true);
    a.skillAt = double.infinity; // its Volley kept out of this
    final o = troopAt(g, 'knight', a.pos - const Point(30.0, 0), hp: 5000);
    lands(g, a, MonsterSkill.barbedArrow);
    runFor(g, 0.5);
    return (g: g, o: o, on: {Status.bleed}, stun: false, drain: false, hurts: true);
  },
  'Pounce: bleed': () {
    final (g, wolf) = casterAt('werewolf', Tier.highElite);
    final o = troopAt(g, 'knight_templar', const Point(215, 76))..hp = 112; // 40%: prey
    lands(g, wolf, MonsterSkill.pounce);
    runFor(g, hopTime + 0.05);
    return (g: g, o: o, on: {Status.bleed}, stun: false, drain: false, hurts: true);
  },
  'Sticky Glob: slow and slower attacks': () {
    final (g, slime) = casterAt('slime', Tier.highElite);
    final o = troopAt(g, 'priest', const Point(200, 64));
    lands(g, slime, MonsterSkill.stickyGlob);
    tickUntil(g, () => g.shots.isEmpty, 2);
    return (g: g, o: o, on: {Status.slow, Status.haste}, stun: false, drain: false, hurts: false);
  },
  'Slime Tide: slow': () {
    final (g, slime) = casterAt('slime', Tier.boss, still: true);
    final o = troopAt(g, 'knight', slime.pos - const Point(20.0, 0));
    slime.hp = slime.maxHp * 0.5;
    lands(g, slime, MonsterSkill.slimeTide);
    g.tick(0.05);
    return (g: g, o: o, on: {Status.slow}, stun: false, drain: false, hurts: false);
  },
  'Roar: weaken': () {
    final (g, bear) = casterAt('werebear', Tier.boss, still: true);
    final o = troopAt(g, 'knight', bear.pos - const Point(40.0, 0));
    bear.hp = bear.maxHp * 0.5;
    lands(g, bear, MonsterSkill.roar);
    return (g: g, o: o, on: {Status.weaken}, stun: false, drain: false, hurts: false);
  },
  'Curse of Frailty: vulnerable': () {
    final (g, necro) = casterAt(boss, Tier.highElite);
    necro.mp = 0; // no summons meanwhile
    final o = troopAt(g, 'knight', necro.pos - const Point(20.0, 0));
    for (final dx in [28.0, 36.0]) {
      troopAt(g, 'knight', necro.pos - Point(dx, 0));
    }
    lands(g, necro, MonsterSkill.curseOfFrailty);
    return (g: g, o: o, on: {Status.vulnerable}, stun: false, drain: false, hurts: false);
  },
  'Bulwark: taunt': () {
    final (g, orc) = casterAt('armored_orc', Tier.highElite);
    final o = troopAt(g, 'knight', orc.pos - const Point(8.0, 5));
    troopAt(g, 'soldier', orc.pos - const Point(8.0, -5)); // two in its reach
    lands(g, orc, MonsterSkill.bulwark);
    return (g: g, o: o, on: {Status.taunt}, stun: false, drain: false, hurts: false);
  },
  'Headbutt: stun': () {
    final (g, orc) = casterAt('orc', Tier.miniBoss, still: true);
    final o = troopAt(g, 'knight', orc.pos - const Point(10.0, 0), hp: 5000);
    lands(g, orc, MonsterSkill.headbutt);
    return (g: g, o: o, on: <Status>{}, stun: true, drain: false, hurts: false);
  },
  'Soul Drain: drain': () {
    final (g, necro) = casterAt(boss, Tier.miniBoss, wave: 5, still: true);
    necro.hp = necro.maxHp * 0.5;
    final o = troopAt(g, 'knight_templar', necro.pos - const Point(30.0, 0), hp: 5000);
    lands(g, necro, MonsterSkill.soulDrain);
    runFor(g, 0.6); // the first drain
    return (g: g, o: o, on: <Status>{}, stun: false, drain: true, hurts: true);
  },
};

/// Every addEffect call in the monster skills' files that doesn't mark its effect bad, by file (the trimmed line): each
/// a monster's own, or its allies' (none on a troop). A new one fails the guard: a monster's effect on a troop says
/// `bad: true`; one on a monster is listed here.
const monstersOwn = <String, List<String>>{
  'boss_skills.dart': [
    'addEffect(u, Status.haste, frenzyK.time, k: frenzyK.pause);', // Frenzy
    'addEffect(u, Status.lifesteal, bloodrageK.time, k: bloodrageK.share);', // Bloodrage
    'addEffect(u, Status.soulRend, soulRendK.time, k: soulRendK.mp);', // Soul Rend
    'addEffect(o, Status.absorb, unholyWardK.time, k: _healOf(u) * unholyWardK.soak);', // Unholy Ward: a monster
    'addEffect(o, Status.might, rallyK.time, k: rallyK.might, by: u);', // Rally: the orcs
    'addEffect(o, Status.haste, rallyK.time, k: rallyK.pause, by: u);',
    'addEffect(o, Status.swift, howlK.time, k: howlK.walk, by: u);', // Howl: the monsters near
    'addEffect(o, Status.haste, howlK.time, k: howlK.pause, by: u);',
    'addEffect(u, Status.steadfast, ironMarchK.time);', // Iron March
    'addEffect(u, Status.swift, ironMarchK.time, k: ironMarchK.walk);',
    'addEffect(u, Status.swift, secondWindK.time, k: secondWindK.walk);', // Second Wind
    'addEffect(u, Status.haste, secondWindK.time, k: secondWindK.pause);',
  ],
  'monster_skills.dart': [
    'addEffect(o, Status.might, warShoutK.time, k: strong ? warShoutK.strong : warShoutK.might, by: u);', // War Shout
    'addEffect(o, Status.shotWard, shieldUpK.time, k: shieldUpK.ward, by: u);', // Shield Up
    'if (strong) addEffect(u, Status.reflect, bulwarkK.time, k: bulwarkK.reflect);', // Bulwark's reflect
  ],
};

/// The files of the monster skills: the only ones that mark an effect bad.
const monsterFiles = {'boss_skills.dart', 'monster_skills.dart', 'monster_skill_moves.dart', 'monster_skill_signatures.dart'};

/// A monster heal the funnel heard: the monster, its tag, the heal asked, the HP it gained.
typedef Healed = ({Unit u, MonsterHeal src, double asked, double gained});

/// Every monster heal of [g] from now on, in order.
List<Healed> hear(Game g) {
  final heard = <Healed>[];
  g.onMonsterHeal = (u, src, asked, gained) => heard.add((u: u, src: src, asked: asked, gained: gained));
  return heard;
}

/// Puts noHeal on monster [m] for the rest of the scene.
void seal(Game g, Unit m) => g.addEffect(m, Status.noHeal, 60);

/// Each monster heal site's scene, by its tag: what the funnel heard, and the monster it must heal; [sealed]: under
/// noHeal from before the heal lands (the monster skill tests' set-ups).
final Map<MonsterHeal, (List<Healed>, Unit) Function(bool sealed)> heals = {
  MonsterHeal.heal: (sealed) {
    final g = plain(), heard = hear(g);
    foeAt(g, necroHealer, const Point(250, 60)).busyUntil = double.negativeInfinity;
    final orc = foeAt(g, 'orc', const Point(260, 60))..hp = 10;
    if (sealed) seal(g, orc);
    tickUntil(g, () => heard.any((h) => h.u == orc));
    return (heard, orc);
  },
  MonsterHeal.massMend: (sealed) {
    final (g, h) = casterAt(necroHealer, Tier.highElite);
    final heard = hear(g), a = foeAt(g, 'orc', h.pos + const Point(10.0, 0))..hp = 10;
    foeAt(g, 'orc', h.pos - const Point(10.0, 0)).hp = 10;
    if (sealed) seal(g, a);
    lands(g, h, MonsterSkill.massMend);
    return (heard, a);
  },
  MonsterHeal.lastRites: (sealed) {
    final (g, h) = casterAt(necroHealer, Tier.boss, still: true);
    final heard = hear(g), near = foeAt(g, 'orc', h.pos + const Point(40.0, 0))..hp = 10;
    h.hp = h.maxHp * 0.5;
    if (sealed) seal(g, near);
    lands(g, h, MonsterSkill.lastRites);
    return (heard, near);
  },
  MonsterHeal.secondWind: (sealed) {
    final (g, rider) = casterAt('orc_rider', Tier.boss, still: true);
    final heard = hear(g);
    rider.hp = rider.maxHp * 0.5;
    if (sealed) seal(g, rider);
    lands(g, rider, MonsterSkill.secondWind);
    return (heard, rider);
  },
  MonsterHeal.drain: (sealed) {
    final (g, necro) = casterAt(boss, Tier.miniBoss, wave: 5, still: true);
    final heard = hear(g);
    necro.hp = necro.maxHp * 0.5;
    troopAt(g, 'knight_templar', necro.pos - const Point(30.0, 0), hp: 5000);
    if (sealed) seal(g, necro);
    lands(g, necro, MonsterSkill.soulDrain);
    runFor(g, 3.1);
    return (heard, necro);
  },
  MonsterHeal.bite: (sealed) {
    final (g, bat) = casterAt('bat', Tier.highElite);
    final heard = hear(g);
    troopAt(g, 'priest', const Point(190, 60));
    bat.hp = 5;
    if (sealed) seal(g, bat);
    lands(g, bat, MonsterSkill.swoop);
    runFor(g, hopTime + 0.05);
    return (heard, bat);
  },
  MonsterHeal.lifesteal: (sealed) {
    final (g, orc) = casterAt('elite_orc', Tier.miniBoss, still: true);
    final heard = hear(g);
    orc.hp = orc.maxHp * 0.55;
    troopAt(g, 'knight', orc.pos - const Point(10.0, 0), hp: 5000);
    lands(g, orc, MonsterSkill.bloodrage);
    if (sealed) seal(g, orc);
    orc.cd = 0;
    tickUntil(g, () => heard.any((h) => h.src == MonsterHeal.lifesteal), 2);
    return (heard, orc);
  },
  MonsterHeal.regen: (sealed) {
    final (g, orc) = casterAt('orc', Tier.normal, still: true);
    final heard = hear(g), s = orc.stats;
    orc
      ..stats = Stats(hp: s.hp, cost: s.cost, speed: s.speed, dmg: s.dmg, range: s.range, rate: s.rate, def: s.def, regen: 5)
      ..hp = 10;
    if (sealed) seal(g, orc);
    g.tick(0.05);
    return (heard, orc);
  },
  MonsterHeal.overTime: (sealed) {
    final (g, orc) = casterAt('orc', Tier.normal, still: true);
    final heard = hear(g);
    orc.hp = 10;
    g.addEffect(orc, Status.heal, 2, k: 20);
    if (sealed) seal(g, orc);
    runFor(g, 1);
    return (heard, orc);
  },
  MonsterHeal.feed: (sealed) {
    omensOn = true; // the Bayangan Feed: the orc's blow on a knight heals it (omen.dart)
    try {
      final (g, orc) = casterAt('orc', Tier.normal, still: true);
      g
        ..omens.addAll(List.filled(omenCap, OmenKind.feed))
        ..omenFactor = 2;
      final heard = hear(g);
      orc.hp = 10;
      troopAt(g, 'knight', orc.pos - const Point(10.0, 0), hp: 5000);
      if (sealed) seal(g, orc);
      orc.cd = 0;
      tickUntil(g, () => heard.any((h) => h.src == MonsterHeal.feed), 2);
      return (heard, orc);
    } finally {
      omensOn = false;
    }
  },
  MonsterHeal.gloat: (sealed) {
    omensOn = true; // the Bayangan Gloat: the orc that kills a knight heals (omen.dart)
    try {
      final (g, orc) = casterAt('orc', Tier.normal, still: true);
      g
        ..omens.addAll(List.filled(omenCap, OmenKind.gloat))
        ..omenFactor = 2;
      final heard = hear(g);
      orc.hp = 10;
      troopAt(g, 'knight', orc.pos - const Point(10.0, 0), hp: 1);
      if (sealed) seal(g, orc);
      orc.cd = 0;
      tickUntil(g, () => heard.any((h) => h.src == MonsterHeal.gloat), 2);
      return (heard, orc);
    } finally {
      omensOn = false;
    }
  },
  MonsterHeal.rekindle: (sealed) {
    omensOn = true; // the Bayangan Rekindle: a high elite's skill lands, and it heals (omen.dart)
    try {
      final (g, orc) = casterAt('elite_orc', Tier.highElite, still: true);
      g
        ..omens.addAll(List.filled(omenCap, OmenKind.rekindle))
        ..omenFactor = 2;
      final heard = hear(g);
      orc.hp = orc.maxHp * 0.7;
      for (final dy in [-6.0, 6.0]) {
        troopAt(g, 'knight', orc.pos + Point(-10.0, dy), hp: 5000); // Brutal Swing's crowd
      }
      if (sealed) seal(g, orc);
      lands(g, orc, MonsterSkill.brutalSwing);
      return (heard, orc);
    } finally {
      omensOn = false;
    }
  },
  MonsterHeal.partingGift: (sealed) {
    omensOn = true; // the Bayangan Parting Gift: an orc dies next to it, and it heals (omen.dart)
    try {
      final (g, orc) = casterAt('orc', Tier.normal, still: true);
      g
        ..omens.addAll(List.filled(omenCap, OmenKind.partingGift))
        ..omenFactor = 2;
      final heard = hear(g);
      orc.hp = 10;
      final dying = g.monster('orc', Tier.normal, orc.pos - const Point(10.0, 0))
        ..entered = true
        ..busyUntil = hold
        ..hp = 1;
      g.units.add(dying);
      troopAt(g, 'knight', dying.pos - const Point(12.0, 0)).busyUntil = double.negativeInfinity; // it kills the orc
      if (sealed) seal(g, orc);
      tickUntil(g, () => heard.any((h) => h.src == MonsterHeal.partingGift), 2);
      return (heard, orc);
    } finally {
      omensOn = false;
    }
  },
  MonsterHeal.bloodMoon: (sealed) {
    omensOn = true; // the Bayangan Blood Moon: a werewolf comes on with a lifesteal, and its bite heals it (omen.dart)
    try {
      final (g, _) = casterAt('orc', Tier.normal, at: const Point(400.0, 60.0), still: true);
      g
        ..omens.addAll(List.filled(omenCap, OmenKind.bloodMoon))
        ..omenFactor = 2;
      final wolf = g.monster('werewolf', Tier.normal, const Point(250.0, 60.0))
        ..entered = true
        ..summonCd = hold;
      g
        ..units.add(wolf)
        ..addEffect(wolf, Status.slow, hold, k: 0);
      final heard = hear(g);
      wolf.hp = 10;
      troopAt(g, 'knight', wolf.pos - const Point(10.0, 0), hp: 5000);
      if (sealed) seal(g, wolf);
      tickUntil(g, () => heard.any((h) => h.src == MonsterHeal.bloodMoon), 2);
      return (heard, wolf);
    } finally {
      omensOn = false;
    }
  },
  MonsterHeal.siphon: (sealed) {
    omensOn = true; // the Bayangan Heal Siphon: a knight next to it heals, and a share of that heals the orc (omen.dart)
    try {
      final (g, orc) = casterAt('orc', Tier.normal, still: true);
      g
        ..omens.addAll(List.filled(omenCap, OmenKind.healSiphon))
        ..omenFactor = 2;
      final heard = hear(g);
      orc.hp = 10;
      final k = troopAt(g, 'knight', orc.pos - const Point(20.0, 0), hp: 200)..hp = 100;
      g.addEffect(k, Status.heal, 1, k: 60); // a Blessing's heal over time
      if (sealed) seal(g, orc);
      tickUntil(g, () => heard.any((h) => h.src == MonsterHeal.siphon), 3);
      return (heard, orc);
    } finally {
      omensOn = false;
    }
  },
  MonsterHeal.lastGasp: (sealed) {
    omensOn = true; // the Bayangan Last Gasp: an arrow takes the boss under 40%, and it heals (omen.dart)
    try {
      final (g, boss) = casterAt('orc', Tier.boss, still: true);
      g
        ..omens.addAll(List.filled(omenCap, OmenKind.lastGasp))
        ..omenFactor = 2;
      final heard = hear(g), archer = troopAt(g, 'archer', const Point(150.0, 60.0));
      boss.hp = boss.maxHp * 0.45;
      if (sealed) seal(g, boss);
      arrow(g, archer, boss, boss.maxHp * 0.1 + boss.stats.def);
      tickUntil(g, () => heard.any((h) => h.src == MonsterHeal.lastGasp), 1);
      return (heard, boss);
    } finally {
      omensOn = false;
    }
  },
  MonsterHeal.reassemble: (sealed) {
    final (g, sk) = casterAt('skeleton', Tier.highElite);
    sk.busyUntil = hold;
    final heard = hear(g), archer = troopAt(g, 'archer', const Point(150.0, 60.0));
    arrow(g, archer, sk, sk.hp + 50);
    expect(g.t < sk.downUntil, isTrue, reason: 'a heap of bones');
    if (sealed) seal(g, sk); // laid on the heap (a killing blow's comes first: it falls, its own test)
    runFor(g, reassembleK.down);
    return (heard, sk);
  },
};

/// Runs [body] with [relic]'s row holding [fx] in place of its own (the rest of the row kept), then puts the row back.
/// A Pusaka given inside [body] is booked from the swapped row.
void withFx(Relic relic, List<Fx> fx, void Function() body) {
  final was = pusakaCatalog[relic]!;
  pusakaCatalog[relic] = Art(was.rarity, was.role, was.icon,
      fx: fx, epithet: was.epithet, counter: was.counter, healerCounter: was.healerCounter, store: was.store, live: was.live);
  try {
    body();
  } finally {
    pusakaCatalog[relic] = was;
  }
}

void main() {
  group('a cleanse ends every kind a monster puts on a troop, and nothing else', () {
    for (final MapEntry(key: name, value: scene) in kinds.entries) {
      test(name, () {
        final s = scene(), g = s.g, o = s.o;
        expect(o.effects.keys.toSet(), s.on);
        expect(o.effects.values.every((e) => e.bad), isTrue, reason: "a monster's effect on a troop is marked bad");
        expect((g.t < o.stunUntil, drained(g, o)), (s.stun, s.drain));
        final n = s.on.length + (s.stun ? 1 : 0) + (s.drain ? 1 : 0);
        expect(g.badOn(o), n);
        g.addEffect(o, Status.might, 30, k: 1.2); // its own
        expect(g.cleanse(o), n);
        expect(g.badOn(o), 0);
        expect(o.effects.keys, [Status.might]);
        expect((g.t < o.stunUntil, drained(g, o)), (false, false));
        if (s.stun) expect(g.stunTroop(o, 0.5), isFalse, reason: 'its immunity stays');
        if (s.hurts) {
          final hp = o.hp;
          runFor(g, 1.5);
          expect(o.hp, hp, reason: 'what it left is over');
        }
      });
    }
  });

  test('a cleanse never ends a status a troop, a Pusaka or the troop itself put on it, whoever it names (a duel names '
      'the monster); every status marked bad ends, a stat one refits; mixed, exactly the bad ones end', () {
    final g = plain(), mate = troopAt(g, 'soldier', const Point(40, 40)), orc = foeAt(g, 'orc', const Point(200, 60));
    final statuses = [for (final s in Status.values) if (s != Status.hex && s != Status.noHeal) s]; // a monster's only
    void put(Unit u, bool Function(int i) bad) {
      for (final (i, s) in statuses.indexed) {
        g.addEffect(u, s, 10.0 + i, k: s.base == 0 ? 5.0 : 1.1, by: [mate, orc, null][i % 3], n: 2, bad: bad(i));
      }
    }

    final good = troopAt(g, 'knight', const Point(60, 60));
    put(good, (_) => false);
    final before = {for (final MapEntry(key: s, value: e) in good.effects.entries) s: (e.until, e.k)};
    expect(before.keys, statuses);
    expect((g.badOn(good), g.cleanse(good)), (0, 0));
    expect({for (final MapEntry(key: s, value: e) in good.effects.entries) s: (e.until, e.k)}, before);

    final bad = troopAt(g, 'knight', const Point(60, 80)), hp = bad.maxHp;
    put(bad, (_) => true);
    expect(bad.maxHp, greaterThan(hp), reason: 'giant');
    expect(g.cleanse(bad), statuses.length);
    expect(bad.effects, isEmpty);
    expect(bad.maxHp, hp, reason: 'refit');

    final mixed = troopAt(g, 'knight', const Point(60, 100));
    put(mixed, (i) => i.isOdd);
    expect(g.cleanse(mixed), statuses.length ~/ 2);
    expect(mixed.effects.keys, [for (final (i, s) in statuses.indexed) if (i.isEven) s]);
  });

  test('a cleanse of a few: those with the most time left first, alike in the order found; a fallen troop has none',
      () {
    final g = plain(), k = troopAt(g, 'knight', const Point(60, 60)), orc = foeAt(g, 'orc', const Point(200, 60));
    g
      ..addEffect(k, Status.slow, 2, k: 0.5, by: orc, bad: true)
      ..addEffect(k, Status.haste, 2, k: 1.4, by: orc, bad: true)
      ..addEffect(k, Status.weaken, 5, k: 0.8, by: orc, bad: true)
      ..addEffect(k, Status.daze, 3, k: 1.25, by: orc, bad: true)
      ..addEffect(k, Status.might, 9, k: 1.2);
    expect(g.stunTroop(k, 0.5), isTrue);
    expect(g.badOn(k), 5);
    expect(g.cleanse(k, most: 1), 1);
    expect(k.effects.keys.toSet(), {Status.slow, Status.haste, Status.daze, Status.might});
    expect(g.cleanse(k, most: 2), 2);
    expect(k.effects.keys.toSet(), {Status.haste, Status.might}, reason: 'the slow, found first of the two alike');
    expect(g.cleanse(k, most: 5), 2, reason: 'the haste, then the stun');
    expect(k.effects.keys, [Status.might]);
    expect(g.t < k.stunUntil, isFalse);
    expect(g.cleanse(k), 0);

    final fallen = troopAt(g, 'knight', const Point(60, 80));
    g.addEffect(fallen, Status.weaken, 5, k: 0.8, by: orc, bad: true);
    fallen.dying = 0;
    expect(g.cleanse(fallen), 0);
  });

  test("static guard: only the monster skills (and the Bayangan's troop debuff) mark an effect bad, and every effect they put on that isn't marked is "
      'listed (a monster\'s own)', () {
    final marking = <String>{}, unmarked = <String, List<String>>{};
    for (final f in Directory('lib').listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'))) {
      final name = f.uri.pathSegments.last;
      for (final line in f.readAsLinesSync()) {
        final code = line.trim();
        if (code.startsWith('//') || code.startsWith('///')) continue;
        if (code.contains('bad: true')) marking.add(name);
        if (monsterFiles.contains(name) && code.contains('addEffect(') && !code.contains('bad: true')) {
          (unmarked[name] ??= []).add(code.replaceFirst(RegExp(r'^inside: \(o\) => '), ''));
        }
      }
    }
    expect(marking, {...monsterFiles, 'omen.dart'}, reason: "and the Bayangan Sap's weaken, a monster's blow's (batch L-3)");
    expect(unmarked, monstersOwn,
        reason: "a monster skill's effect on a troop says bad: true (a cleanse ends it); one on a monster is listed in "
            'monstersOwn');
  });

  group('noHeal: every monster heal site heals through the funnel, and lands as 0 under it', () {
    test('the table covers every tag', () {
      expect(heals.keys.toSet(), MonsterHeal.values.toSet());
    });

    for (final MapEntry(key: src, value: scene) in heals.entries) {
      test(src.name, () {
        final (heard, m) = scene(false);
        final mine = heard.where((h) => h.u == m && h.src == src).toList();
        expect(mine, isNotEmpty, reason: 'heard: ${[for (final h in heard) h.src.name]}');
        expect(mine.any((h) => h.gained > 0), isTrue);
        final (sealedHeard, sealed) = scene(true);
        final none = sealedHeard.where((h) => h.u == sealed && h.src == src).toList();
        expect(none, isNotEmpty, reason: 'heard: ${[for (final h in sealedHeard) h.src.name]}');
        expect(none.every((h) => h.asked > 0 && h.gained == 0), isTrue, reason: '$none');
      });
    }

    test("a skeleton under noHeal doesn't reassemble: its killing blow is its last; laid on its heap, it stands again at "
        "the heap's HP", () {
      final (g, sk) = casterAt('skeleton', Tier.highElite);
      sk.busyUntil = hold;
      final archer = troopAt(g, 'archer', const Point(150.0, 60.0)), kills = g.kills;
      seal(g, sk);
      arrow(g, archer, sk, sk.hp + 50);
      expect((sk.alive, sk.reassembled, g.kills), (false, false, kills + 1));
      expect(g.monsterCasts, isEmpty);

      final (heard, heap) = heals[MonsterHeal.reassemble]!(true);
      expect((heap.alive, heap.hp), (true, min(1.0, heap.maxHp * reassembleK.stand)));
      expect(heard.single.gained, 0);
    });
  });

  group('the engine', () {
    /// A wave on with [type]'s troop at cell (2, 3) holding [relic] (standing still, never striking) and an orc next to
    /// it that strikes only when told.
    (Game, Unit, Unit) struck(Relic relic, [String type = 'knight']) {
      final g = plain()..wave = 9;
      final k = placeNow(g, type, 2, 3)..busyUntil = hold;
      g
        ..givePusaka(relic, type: type)
        ..startWave()
        ..queue.clear();
      return (g, k, foeAt(g, 'orc', k.pos + const Point(12, 0)));
    }

    void strikeBy(Game g, Unit foe) {
      foe
        ..busyUntil = double.negativeInfinity
        ..cd = 0;
      g.tick(0.05);
      foe.busyUntil = hold;
    }

    test('a `cleanse` Fx (struck, itself): the bad effects with the most time left end, its count a star (none: all); '
        "the troop's own stay; its words", () {
      expect(fxBuilt(const Fx(Trig.struck, Eff.cleanse, To.self)), isTrue);
      expect(fxBuilt(const Fx(Trig.struck, Eff.cleanse, To.nearTroops)), isFalse);
      for (final (count, left, words) in [
        ([1], {Status.daze, Status.might}, 'When hit: clears 1 bad effect'),
        (<int>[], {Status.might}, 'When hit: clears its bad effects'),
      ]) {
        withFx(Relic.ironBanner, [Fx(Trig.struck, Eff.cleanse, To.self, count: count)], () {
          final (g, k, orc) = struck(Relic.ironBanner);
          g
            ..addEffect(k, Status.weaken, 5, k: 0.8, by: orc, bad: true)
            ..addEffect(k, Status.daze, 3, k: 1.25, by: orc, bad: true)
            ..addEffect(k, Status.might, 9, k: 1.2);
          strikeBy(g, orc);
          expect(k.hp, lessThan(k.maxHp), reason: 'struck');
          expect(k.effects.keys.toSet(), left);
          expect(g.pusakaWorth[Relic.ironBanner]!.uses, 3 - left.length);
          expect(fxLines(Relic.ironBanner, 1), [words]);
          expect(fxGist(Relic.ironBanner, 1), words.replaceFirst('When hit', 'Hit'));
        });
      }
    });

    test('a `noHeal` Fx (dealt, the monster hit): no heal lands on it for its k s (its number, so Carve moves it: Grave '
        "Seal's, batch G-3); a skeleton it kills stays down; its words", () {
      expect(fxBuilt(const Fx(Trig.dealt, Eff.noHeal, To.foeHit)), isTrue);
      expect(fxBuilt(const Fx(Trig.dealt, Eff.noHeal, To.self)), isFalse);
      withFx(Relic.voidEye, [const Fx(Trig.dealt, Eff.noHeal, To.foeHit, k: [3])], () {
        final (g, orc) = casterAt('orc', Tier.normal, still: true);
        final archer = placeNow(g, 'archer', 2, 3)..busyUntil = hold;
        g.givePusaka(Relic.voidEye, type: 'archer');
        orc.hp = orc.maxHp * 0.5;
        arrow(g, archer, orc, 1);
        final e = g.effectOn(orc, Status.noHeal)!;
        expect((e.by, e.bad), (archer, false));
        expect(e.until, closeTo(g.t + 3, 0.051));
        final hp = orc.hp;
        g.addEffect(orc, Status.heal, 5, k: 50);
        runFor(g, 1);
        expect(orc.hp, hp);
        runFor(g, 2.1);
        expect(orc.hp, greaterThan(hp), reason: 'it heals again once it ends');

        final sk = foeAt(g, 'skeleton', const Point(300, 40), Tier.highElite);
        arrow(g, archer, sk, sk.hp + 50);
        expect((sk.alive, sk.reassembled), (false, false));

        expect(fxLines(Relic.voidEye, 1), ["Monsters it hits can't heal for 3s"]);
        expect(fxGist(Relic.voidEye, 1), 'Hit: no heals 3s');
      });
    });
  });
}
