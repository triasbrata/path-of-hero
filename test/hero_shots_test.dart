import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';

import 'hero_skill_helpers.dart';

// #48 branch 2b: the special shots and ground objects (lib/hero_shots.dart), and the eight Hero skills built from
// them. docs/units-and-combat.md, "Special shots and ground objects" and "Hero skills".

/// A game with nothing on the field and skills off: only what a test puts there.
Game field() => Game()
  ..units.clear()
  ..skills = false;

/// A troop of [type] standing at [at] that never moves or strikes on its own.
Unit troopAt(Game g, String type, Point<double> at) {
  final u = Unit(Side.troop, type, troopTypes[type]!, at)
    ..entered = true
    ..busyUntil = hold;
  g.units.add(u);
  return u;
}

/// Ticks [g] for [seconds] in 0.05 s steps.
void ticks(Game g, double seconds) {
  for (var i = 0; i < (seconds / 0.05).round(); i++) {
    g.tick(0.05);
  }
}

/// The HP [u] has after [n] hits of [dmg].
double after(Unit u, double dmg, [int n = 1]) => u.maxHp - n * hitTaken(dmg, u.stats.def);

void main() {
  test('a plain shot keeps the old rules: the shooter\'s speed, no look of its own, nothing on hit', () {
    final g = field(), a = troopAt(g, 'archer', const Point(20, 64)), orc = foeAt(g, 'orc', const Point(120, 64));
    final s = Shot(a, orc, a.pos + const Point(0, -6), Hit.normal);
    expect((s.speed, s.look, s.onHit, s.dmg, s.splash, s.big, s.src), (null, ShotLook.plain, null, a.stats.dmg, 0.0, false, Hit.normal));
    g.shots.add(s);
    final was = s.pos.distanceTo(orc.pos);
    g.tick(0.05);
    expect(s.pos.distanceTo(orc.pos), closeTo(was - a.stats.shotSpeed * 0.05, 1e-9));
  });

  test('a special shot flies at its own speed, past the shooter\'s range, even from a melee troop, and runs its onHit after the damage', () {
    final g = field(), l = troopAt(g, 'lancer', const Point(20, 64)), orc = foeAt(g, 'orc', const Point(20 + 5 * tile, 64));
    expect(l.stats.shotSpeed, 0); // a melee troop
    expect(orc.pos.distanceTo(l.pos), greaterThan(3 * l.stats.range));
    final seen = <(Unit, double)>[];
    final s = Shot.special(l, orc, l.pos + const Point(0, -6), dmg: 30, speed: 220, look: ShotLook.spear, big: true, onHit: (u) => seen.add((u, u.hp)));
    expect((s.dmg, s.splash, s.look, s.big), (30.0, 0.0, ShotLook.spear, true));
    g.shots.add(s);
    final was = s.pos.distanceTo(orc.pos);
    g.tick(0.05);
    expect(s.pos.distanceTo(orc.pos), closeTo(was - 220 * 0.05, 1e-9));
    for (var i = 0; i < 20 && g.shots.isNotEmpty; i++) {
      g.tick(0.05);
    }
    expect(g.shots, isEmpty);
    expect(orc.hp, after(orc, 30));
    expect(seen, [(orc, after(orc, 30))]); // once, with the damage already taken
    expect(g.impacts.map((i) => i.$2), contains('hit_lancer_big'));
  });

  test('a special shot with splash runs its onHit on every unit it hurt, and on no one else', () {
    final g = field(), w = troopAt(g, 'wizard', const Point(20, 64));
    final target = foeAt(g, 'orc', const Point(100, 64)), near = foeAt(g, 'orc', const Point(114, 64)), far = foeAt(g, 'orc', const Point(140, 64));
    final hit = <Unit>[];
    g.shots.add(Shot.special(w, target, w.pos, dmg: 20, speed: 300, splash: 20, onHit: hit.add));
    ticks(g, 1);
    expect(g.shots, isEmpty);
    expect(hit.toSet(), {target, near});
    expect((target.hp, near.hp, far.hp), (after(target, 20), after(near, 20), far.maxHp.toDouble()));
  });

  test('a line shot hurts every foe within its width of its path once, and nothing past its length or off its line', () {
    final g = field(), a = troopAt(g, 'archer', const Point(20, 64));
    final onLine = [foeAt(g, 'orc', const Point(60, 64)), foeAt(g, 'orc', const Point(75, 64 + lineWidth - 1)), foeAt(g, 'orc', const Point(90, 64)), foeAt(g, 'orc', const Point(120, 64))];
    final off = foeAt(g, 'orc', const Point(100, 64 + lineWidth + 2)), beyond = foeAt(g, 'orc', const Point(170, 64));
    final hit = <Unit>[];
    final s = LineShot(a, a.pos, const Point(200, 64), dmg: 20, speed: 320, length: 128, onHit: hit.add);
    expect((s.dir, s.width, s.boomerang, s.look), (const Point(1.0, 0.0), lineWidth, false, ShotLook.plain));
    g.lineShots.add(s);
    g.tick(0.05);
    expect(s.pos, const Point(20 + 320 * 0.05, 64.0));
    ticks(g, 1);
    expect(g.lineShots, isEmpty);
    expect(s.pos, const Point(20 + 128.0, 64.0)); // it stopped at the end of its line
    expect(hit, onLine); // in the order it passed them, each once
    for (final o in onLine) {
      expect(o.hp, after(o, 20));
    }
    expect((off.hp, beyond.hp), (off.maxHp.toDouble(), beyond.maxHp.toDouble()));
    expect(g.impacts.where((i) => i.$2 == 'hit_archer'), hasLength(onLine.length));
  });

  test('a line shot flies the way it was aimed, and ahead when aimed at its own start', () {
    final g = field(), a = troopAt(g, 'archer', const Point(20, 64));
    final s = LineShot(a, a.pos, const Point(20 + 30, 64 + 40), dmg: 1, speed: 100, length: 50);
    expect(s.dir.x, closeTo(0.6, 1e-9));
    expect(s.dir.y, closeTo(0.8, 1e-9));
    g.lineShots.add(s);
    ticks(g, 1);
    expect(s.done, isTrue);
    expect(s.pos.x, closeTo(50, 1e-9));
    expect(s.pos.y, closeTo(104, 1e-9));
    expect(LineShot(a, a.pos, a.pos, dmg: 1, speed: 1, length: 1).dir, const Point(1.0, 0.0));
  });

  test('a boomerang flies out to the end of its line and back to its thrower, hitting each foe going out and again coming back', () {
    final g = field(), x = troopAt(g, 'armored_axeman', const Point(20, 64));
    final near = foeAt(g, 'orc', const Point(50, 64)), far = foeAt(g, 'orc', const Point(80, 64)), past = foeAt(g, 'orc', const Point(110, 64));
    final hit = <Unit>[];
    final s = LineShot(x, x.pos, const Point(100, 64), dmg: 15, speed: 128, length: 4 * tile, boomerang: true, look: ShotLook.spin, onHit: hit.add);
    g.lineShots.add(s);
    ticks(g, 0.5);
    expect((s.back, s.pos), (true, const Point(20 + 4 * tile, 64.0))); // turned at the end of its line
    expect(hit, [near, far]);
    ticks(g, 0.5);
    expect(g.lineShots, isEmpty);
    expect(s.pos, x.pos); // home
    expect(hit, [near, far, far, near]);
    expect((near.hp, far.hp, past.hp), (after(near, 15, 2), after(far, 15, 2), past.maxHp.toDouble()));
  });

  test('a boomerang comes back to where its thrower stands now, or to where it was thrown from if the thrower fell', () {
    final g = field(), x = troopAt(g, 'armored_axeman', const Point(20, 64));
    foeAt(g, 'orc', const Point(200, 64)); // keeps the wave on
    final s = LineShot(x, x.pos, const Point(100, 64), dmg: 1, speed: 128, length: 4 * tile, boomerang: true);
    g.lineShots.add(s);
    ticks(g, 0.6);
    x.pos = const Point(20, 96);
    expect(s.heading, x.pos);
    ticks(g, 1);
    expect((s.done, s.pos), (true, const Point(20.0, 96.0)));

    final h = field(), y = troopAt(h, 'armored_axeman', const Point(20, 64));
    foeAt(h, 'orc', const Point(200, 64));
    final b = LineShot(y, y.pos, const Point(100, 64), dmg: 1, speed: 128, length: 4 * tile, boomerang: true);
    h.lineShots.add(b);
    ticks(h, 0.6);
    y
      ..pos = const Point(20, 96)
      ..dying = 0; // fell
    ticks(h, 1);
    expect((b.done, b.pos), (true, const Point(20.0, 64.0)));
  });

  test('a chain goes from its first foe to the nearest one not in it yet within its radius, again and again, up to its jumps', () {
    final g = field();
    troopAt(g, 'wizard', const Point(20, 64));
    final a = foeAt(g, 'orc', const Point(60, 64)), b = foeAt(g, 'orc', const Point(75, 64)), c = foeAt(g, 'orc', const Point(100, 64));
    final d = foeAt(g, 'orc', const Point(60, 90)), e = foeAt(g, 'orc', const Point(130, 64));
    foeAt(g, 'orc', const Point(66, 70)).dying = 0; // nearer than b, but falling
    troopAt(g, 'knight', const Point(60, 40)); // near a, but not a foe
    // From b the nearest is a (15), already in; then c (25) before d (30). From e nothing is within 32.
    expect(g.chainFrom(a, jumps: 4, radius: 2 * tile), [a, b, c, e]);
    expect(g.chainFrom(a, jumps: 2, radius: 2 * tile), [a, b, c]);
    expect(g.chainFrom(d, jumps: 4, radius: 2 * tile), [d, a, b, c, e]); // d to a is 26
    expect(g.chainFrom(e, jumps: 4, radius: 20), [e]);
  });

  test('a chain strike hurts each foe of the chain with less damage at each jump, and shows a beam through them for chainBeamTime', () {
    final g = field(), w = troopAt(g, 'wizard', const Point(20, 64));
    final foes = [for (final x in [60.0, 80.0, 100.0, 120.0, 140.0, 160.0]) foeAt(g, 'orc', Point(x, 64))];
    final chain = g.chainStrike(w, foes.first, dmg: 26.4, jumps: 4, radius: 2 * tile, falloff: 0.15);
    expect(chain, foes.take(5));
    for (final (i, o) in foes.indexed) {
      expect(o.hp, i < 5 ? closeTo(after(o, 26.4 * pow(0.85, i)), 1e-9) : o.maxHp, reason: '$i');
    }
    expect(g.impacts.where((i) => i.$2 == 'hit_wizard'), hasLength(5));
    final beam = g.beams.single;
    expect(beam.points, [w.pos, for (final o in chain) o.pos]);
    expect((beam.since, beam.until, beam.look), (g.t, g.t + chainBeamTime, BeamLook.lightning));
    ticks(g, chainBeamTime - 0.1);
    expect(g.beams, hasLength(1));
    ticks(g, 0.15);
    expect(g.beams, isEmpty);
  });

  test('a zone acts on each unit of its side in its radius: inside every tick, a pulse every second from its first tick, and goes when its time is up', () {
    final g = field(), w = troopAt(g, 'wizard', const Point(20, 64));
    const at = Point(100.0, 64.0);
    final inner = foeAt(g, 'orc', at + const Point(10, 0)), edge = foeAt(g, 'orc', at + const Point(0, 2 * tile));
    final leaver = foeAt(g, 'orc', at + const Point(-10, -20)), out = foeAt(g, 'orc', at + const Point(2 * tile + 4, 0));
    final ally = troopAt(g, 'knight', at + const Point(-6, 12));
    final pulses = <Unit, int>{}, insides = <Unit, int>{};
    var lastInside = double.negativeInfinity;
    final z = Zone(w, at,
        since: g.t,
        duration: 5,
        radius: 2 * tile,
        side: Side.enemy,
        look: ZoneLook.frost,
        inside: (u) {
          insides[u] = (insides[u] ?? 0) + 1;
          lastInside = g.t;
        },
        pulse: (u) => pulses[u] = (pulses[u] ?? 0) + 1);
    expect((z.until, z.every, z.pulses), (g.t + 5, 1.0, 5));
    g.zones.add(z);
    g.tick(0.05);
    expect(pulses, {inner: 1, edge: 1, leaver: 1});
    expect(insides, {inner: 1, edge: 1, leaver: 1});
    ticks(g, 1.5);
    leaver.pos = at + const Point(0, -3 * tile); // walks out
    ticks(g, 3.3);
    expect(g.zones, hasLength(1));
    expect(pulses, {inner: 5, edge: 5, leaver: 2});
    ticks(g, 0.2);
    expect(g.zones, isEmpty);
    ticks(g, 1);
    expect(pulses, {inner: 5, edge: 5, leaver: 2});
    expect(lastInside, allOf(lessThan(z.until), greaterThan(z.until - 0.1))); // every tick of its time, and none after
    expect([out, ally].where(insides.containsKey), isEmpty);
  });

  test('a zone goes when the wave ends, however long it had left', () {
    final g = field()..gold = 1000;
    final k = troopAt(g, 'knight', const Point(40, 64)), foe = foeAt(g, 'orc', const Point(120, 64));
    g.zones.add(Zone(k, k.pos, since: g.t, duration: 10, radius: 3 * tile, side: Side.troop, look: ZoneLook.banner));
    g.tick(0.05);
    expect(g.zones, hasLength(1));
    foe.gone = true;
    g.tick(0.05);
    expect(g.waveActive, isFalse);
    expect(g.zones, isEmpty);
  });

  group('the eight Hero skills built from them', () {
    /// A troop of [type] at cell ([c], [r]) that never strikes on its own.
    Unit idle(Game g, String type, int c, int r) => placeNow(g, type, c, r)..cd = hold;

    test('War Banner: with a troop near that fought (decisions-log 298), a banner at its feet for 10 s: troops within 3 tiles of it deal 20% more', () {
      final (g, h) = heroCaster(HeroSkill.banner);
      foeAt(g, 'orc', const Point(250, 60)); // keeps the wave on
      final near = idle(g, 'knight', 2, 1), side = idle(g, 'archer', 1, 3), far = idle(g, 'knight', 2, 7);
      final fourth = idle(g, 'knight', 3, 3);
      g.tick(0.05);
      expect(h.heroSkillAt, double.negativeInfinity, reason: 'none fought');
      far.attackedAt = g.t;
      g.tick(0.05);
      expect(h.heroSkillAt, double.negativeInfinity, reason: 'only one 4 tiles off fought');
      for (final u in [h, near, side, fourth]) {
        u.attackedAt = g.t;
      }
      g.tick(0.05);
      expect(h.heroSkillAt, g.t);
      final z = g.zones.single, at = z.at;
      expect(at.distanceTo(h.pos), lessThan(2)); // at its feet as it cast (it may have stepped since)
      expect((z.radius, z.side, z.look, z.until), (bannerK.reach, Side.troop, ZoneLook.banner, g.t + bannerK.time));
      g.tick(0.05);
      expect([for (final u in [h, near, side, fourth, far]) g.effectK(u, Status.might)], [1.2, 1.2, 1.2, 1.2, 1.0]);
      h
        ..busyUntil = hold
        ..pos = at + const Point(6 * tile, 0); // the banner stays where it was planted
      runFor(g, 0.5);
      expect((g.effectK(h, Status.might), g.effectK(near, Status.might), g.zones.single.at), (1.0, 1.2, at));
      runFor(g, bannerK.time);
      expect(g.zones, isEmpty);
      expect(g.effectK(near, Status.might), 1.0);
    });

    test('Snipe: aims 0.5 s at a healing necromancer (first) or the highest-ranked elite within 1.5x its range, then a 5x arrow', () {
      final (g, h) = heroCaster(HeroSkill.snipe);
      foeAt(g, 'orc', h.pos + const Point(90, 0));
      g.tick(0.05);
      expect(h.heroSkillAt, double.negativeInfinity, reason: 'no healer, no elite');
      final elite = foeAt(g, 'orc', h.pos + const Point(90, 10), Tier.elite), high = foeAt(g, 'orc', h.pos + const Point(94, -10), Tier.highElite);
      foeAt(g, 'elite_orc', h.pos + const Point(100, 0), Tier.highElite); // past 1.5x its range
      h.cd = 0;
      g.tick(0.05);
      expect(h.heroSkillAt, g.t);
      expect(h.cd, closeTo(snipeK.aim, 0.05)); // aiming: no shot of its own
      expect(g.shots, isEmpty);
      h.cd = hold;
      runFor(g, snipeK.aim + 0.05);
      final s = g.shots.single;
      expect((s.target, s.dmg, s.speed, s.look, s.big), (high, h.stats.dmg * snipeK.hit, h.stats.shotSpeed, ShotLook.trail, true));
      runFor(g, 1);
      expect(high.hp, closeTo(after(high, h.stats.dmg * snipeK.hit), 1e-9));
      expect(elite.hp, elite.maxHp);

      final (b, bh) = heroCaster(HeroSkill.snipe);
      foeAt(b, 'orc', bh.pos + const Point(60, 0), Tier.highElite);
      final healer = foeAt(b, necroHealer, bh.pos + const Point(90, 0));
      b.tick(0.05);
      runFor(b, snipeK.aim + 0.05);
      expect(b.shots.single.target, healer);

      final (c, ch) = heroCaster(HeroSkill.snipe);
      final gone = foeAt(c, 'orc', ch.pos + const Point(60, 0), Tier.elite);
      foeAt(c, 'orc', const Point(300, 60)); // keeps the wave on
      c.tick(0.05);
      gone.gone = true; // it fell while the archer aimed
      runFor(c, snipeK.aim + 0.05);
      expect(c.shots, isEmpty);
    });

    test('Crippling Shot: a foe in range faster than the archer, or near a troop healer: a 1.5x ice arrow that slows it 50% for 5 s (the boss 25%)', () {
      final (g, h) = heroCaster(HeroSkill.crippleShot);
      foeAt(g, 'orc', h.pos + const Point(50, 0)); // slower than the archer
      g.tick(0.05);
      expect(h.heroSkillAt, double.negativeInfinity);
      final wolf = foeAt(g, 'werewolf', h.pos + const Point(60, 8));
      expect(wolf.stats.speed, greaterThan(h.stats.speed));
      g.tick(0.05);
      expect(h.heroSkillAt, g.t);
      final s = g.shots.single;
      expect((s.target, s.dmg, s.look), (wolf, h.stats.dmg * crippleShotK.hit, ShotLook.ice));
      runFor(g, 0.5);
      expect(wolf.hp, closeTo(after(wolf, h.stats.dmg * crippleShotK.hit), 1e-9));
      expect(g.effectK(wolf, Status.slow), crippleShotK.slow);
      expect(g.wantsHeroSkill(h), isFalse, reason: 'it is slowed already');
      runFor(g, crippleShotK.time);
      expect(g.under(wolf, Status.slow), isFalse);

      final (b, bh) = heroCaster(HeroSkill.crippleShot);
      final priest = idle(b, 'priest', 3, 3);
      final necro = foeAt(b, boss, priest.pos + const Point(tile, 0), Tier.boss); // slow, but beside the healer
      b.tick(0.05);
      expect(b.shots.single.target, necro);
      runFor(b, 0.5);
      expect(b.effectK(necro, Status.slow), crippleShotK.boss);
    });

    test('Piercing Shot: foes on the line through its nearest foe out to 2x its range (one is enough, decisions-log 298): one arrow through them all, 2x to each', () {
      final (g, h) = heroCaster(HeroSkill.pierceShot);
      final first = foeAt(g, 'orc', h.pos + const Point(40, 0)), second = foeAt(g, 'orc', h.pos + const Point(90, 6));
      final off = foeAt(g, 'orc', h.pos + const Point(70, 20)); // 20 off the line
      final third = foeAt(g, 'orc', h.pos + const Point(120, -4)), beyond = foeAt(g, 'orc', h.pos + const Point(140, 0));
      g.tick(0.05);
      expect(h.heroSkillAt, g.t);
      final s = g.lineShots.single;
      expect((s.dmg, s.speed, s.length, s.look, s.boomerang),
          (h.stats.dmg * pierceShotK.hit, pierceShotK.speed, h.stats.range * pierceShotK.reach, ShotLook.long, false));
      runFor(g, 0.5);
      expect(g.lineShots, isEmpty);
      for (final o in [first, second, third]) {
        expect(o.hp, closeTo(after(o, h.stats.dmg * pierceShotK.hit), 1e-9));
      }
      expect((off.hp, beyond.hp), (off.maxHp, beyond.maxHp));
    });

    test('Javelin: none in its reach and a foe 2-5 tiles away: a 2.5x spear at the one with the most max HP', () {
      final (g, h) = heroCaster(HeroSkill.javelin);
      final near = foeAt(g, 'orc', h.pos + const Point(20, 0)); // in its reach
      final big = foeAt(g, 'elite_orc', h.pos + const Point(4 * tile, 0)), small = foeAt(g, 'orc', h.pos + const Point(3 * tile, 8));
      foeAt(g, 'elite_orc', h.pos + const Point(6 * tile, 0), Tier.elite); // past 5 tiles
      g.tick(0.05);
      expect(h.heroSkillAt, double.negativeInfinity, reason: 'a foe in its reach');
      near.gone = true;
      g.tick(0.05);
      expect(h.heroSkillAt, g.t);
      final s = g.shots.single;
      expect((s.target, s.dmg, s.speed, s.look, s.big), (big, h.stats.dmg * javelinK.hit, javelinK.speed, ShotLook.spear, true));
      runFor(g, 0.5);
      expect(big.hp, closeTo(after(big, h.stats.dmg * javelinK.hit), 1e-9));
      expect(small.hp, small.maxHp);
      expect(g.impacts.map((i) => i.$2), contains('hit_lancer_big'));

      final (b, bh) = heroCaster(HeroSkill.javelin);
      foeAt(b, 'orc', bh.pos + const Point(1.5 * tile, 0)); // out of its reach, but under 2 tiles
      b.tick(0.05);
      expect(bh.heroSkillAt, double.negativeInfinity);
    });

    test('Axe Throw: a foe on the line ahead (decisions-log 298; it waited for 3, or 2 and none in its reach): the axe out 4 tiles and back, 1x each way', () {
      final (g, h) = heroCaster(HeroSkill.axeThrow);
      final a = foeAt(g, 'orc', h.pos + const Point(12, 0)), b = foeAt(g, 'elite_orc', h.pos + const Point(40, 5));
      final off = foeAt(g, 'orc', h.pos + const Point(30, 3 * tile));
      final c = foeAt(g, 'orc', h.pos + const Point(60, -6));
      g.tick(0.05);
      expect(h.heroSkillAt, g.t);
      final s = g.lineShots.single;
      expect((s.boomerang, s.length, s.speed, s.look, s.dmg), (true, axeThrowK.reach, axeThrowK.speed, ShotLook.spin, h.stats.dmg * axeThrowK.hit));
      runFor(g, 1.1);
      expect(g.lineShots, isEmpty);
      for (final o in [a, b, c]) {
        expect(o.hp, closeTo(after(o, h.stats.dmg * axeThrowK.hit, 2), 1e-9));
      }
      expect(off.hp, off.maxHp);

      final (g2, h2) = heroCaster(HeroSkill.axeThrow);
      foeAt(g2, 'orc', h2.pos + const Point(30, 3 * tile));
      g2.tick(0.05);
      expect(h2.heroSkillAt, double.negativeInfinity, reason: 'none on the line');
      foeAt(g2, 'orc', h2.pos + const Point(30, 0));
      g2.tick(0.05);
      expect(h2.heroSkillAt, g2.t, reason: 'one on the line');
    });

    test('Chain Lightning: a foe in range (decisions-log 298): a bolt to the nearest that leaps through 4 more within 2 tiles each, 1.2x and 15% less a leap', () {
      final (g, h) = heroCaster(HeroSkill.chainLightning);
      final line = [for (var i = 0; i < 6; i++) foeAt(g, 'elite_orc', h.pos + Point(40.0 + 24 * i, 0))];
      final extra = foeAt(g, 'elite_orc', h.pos + const Point(60, 24));
      g.tick(0.05);
      expect(h.heroSkillAt, g.t);
      for (final (i, o) in line.take(5).indexed) {
        expect(o.hp, closeTo(after(o, h.stats.dmg * chainLightningK.hit * pow(1 - chainLightningK.falloff, i)), 1e-9), reason: '$i');
      }
      expect((line.last.hp, extra.hp), (line.last.maxHp, extra.maxHp));
      final beam = g.beams.single.points;
      expect(beam.first.distanceTo(h.pos), lessThan(2)); // from the wizard as it cast (it may have stepped back since)
      expect(beam.skip(1).toList(), [for (final o in line.take(5)) o.pos]);
    });

    test('Frost Storm: a foe in range (decisions-log 298; it waited for 4 within 2 tiles): a 5 s field round the nearest; inside they walk at 50% (the boss 75%) and take 0.3x a second', () {
      final (g, h) = heroCaster(HeroSkill.frostStorm);
      final centre = h.pos + const Point(60, 0);
      final pack = [for (final d in const [Point(0.0, 0.0), Point(14.0, 0.0), Point(0.0, 14.0)]) foeAt(g, 'elite_orc', centre + d)];
      final out = foeAt(g, 'elite_orc', centre + const Point(3 * tile, 0));
      final necro = foeAt(g, boss, centre + const Point(-10, -10), Tier.boss); // the nearest: the storm's centre
      g.tick(0.05);
      expect(h.heroSkillAt, g.t);
      final z = g.zones.single;
      expect(z.at.distanceTo(necro.pos), lessThan(0.5));
      expect((z.radius, z.side, z.look, z.until), (frostStormK.radius, Side.enemy, ZoneLook.frost, g.t + frostStormK.time));
      g.tick(0.05);
      expect([for (final o in [...pack, necro, out]) g.effectK(o, Status.slow)], [0.5, 0.5, 0.5, frostStormK.boss, 1.0]);
      runFor(g, frostStormK.time + 0.5);
      expect(g.zones, isEmpty);
      for (final o in pack) {
        expect(o.hp, closeTo(after(o, h.stats.dmg * frostStormK.hit, 5), 1e-9));
        expect(g.under(o, Status.slow), isFalse);
      }
      expect(out.hp, out.maxHp);
    });
  });
}
