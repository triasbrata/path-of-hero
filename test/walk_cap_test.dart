// The walk speed cap (decisions-log 311; the owner picked "Batasi kecepatan jalan"): no troop walks faster than [walkMost]
// × its type's base walk, whatever raises its speed stat (boots, a Hero's ×3, the aura), Heroes included; monsters keep
// theirs. The catch-up pace and the steps aside stay under the same ceiling; a charge and a leap (and any carry) keep
// their own speeds. The field's stats (the Army page's plate: troops_detail_test.dart) show the walk it gets.
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';

import 'hero_skill_helpers.dart';

/// A game without the free healer, with a 6-column zone and gold to spare ([bareGame]), the #10 skills off.
Game bare() => bareGame(Random(1))..skills = false;

/// Troop [u] made a Hero of [stats] ×[heroBoost], as [Game] refits one (without another Hero's aura).
void crown(Game g, Unit u, List<HeroStat> stats) => u
  ..hero = true
  ..heroStats = stats
  ..stats = g.statsOf(u.type).heroic(stats.toSet(), heroBoost);

void main() {
  test('no troop walks faster than 6x its type\'s base walk, its speed stat as it is; a monster walks at its own', () {
    expect(walkMost, 6);
    for (final MapEntry(key: type, value: base) in troopTypes.entries) {
      expect(walkCap(type), walkMost * base.speed, reason: type);
      final fast = Unit(Side.troop, type, base.boosted(10), const Point(40, 40));
      final slow = Unit(Side.troop, type, base.boosted(5), const Point(40, 40));
      expect(fast.stats.speed, closeTo(10 * base.speed, 1e-9), reason: '$type: the stat stays');
      expect(fast.walkSpeed, walkCap(type), reason: type);
      expect(slow.walkSpeed, slow.stats.speed, reason: '$type under the cap');
      expect(base.boosted(10).walking(type).speed, walkCap(type), reason: type);
      expect(base.walking(type), same(base), reason: type);
    }
    final slime = Unit(Side.enemy, 'slime', enemyTypes['slime']!.boosted(20), const Point(200, 40));
    expect(slime.walkSpeed, slime.stats.speed);
  });

  test('boots, a Hero\'s x3 and the aura raise the speed stat, never the walk past the cap; Heroes included', () {
    final g = bare();
    g.upgrades['knight'] = List.filled(4, Item.boots);
    g.upgrades['archer'] = List.filled(8, Item.boots);
    g.upgrades['wizard'] = List.filled(12, Item.boots);
    final hero = placeNow(g, 'knight', 2, 3), booted = placeNow(g, 'knight', 2, 5);
    final archer = placeNow(g, 'archer', 0, 3), wizard = placeNow(g, 'wizard', 0, 5);
    crown(g, hero, [HeroStat.speed, HeroStat.hp]);
    expect(hero.stats.speed, closeTo(24 * pow(1.25, 4) * heroBoost, 1e-9)); // 176
    expect(hero.walkSpeed, walkCap('knight')); // 144
    expect(booted.walkSpeed, closeTo(24 * pow(1.25, 4), 1e-9)); // 58.6: under it, as it was
    expect(wizard.stats.speed, greaterThan(walkCap('wizard'))); // 18 × 1.25^12: boots alone
    expect(wizard.walkSpeed, walkCap('wizard'));
    expect(archer.walkSpeed, archer.stats.speed); // 22 × 1.25^8 = 131: just under its 132
    archer.stats = g.statsOf('archer').boosted(auraBoost); // a living Hero's aura on it, as the game refits it
    expect(archer.stats.speed, greaterThan(walkCap('archer'))); // 151
    expect(archer.walkSpeed, walkCap('archer'));
  });

  test('a Hero knight with its boots walks at its cap tick by tick, and only a walk is capped: its charge and a leap keep '
      'their own speeds', () {
    final g = bare();
    g.upgrades['knight'] = List.filled(4, Item.boots);
    final hero = placeNow(g, 'knight', 1, 3);
    crown(g, hero, [HeroStat.speed, HeroStat.hp]);
    hero.post = hero.pos + const Point(240, 0); // its spot far ahead, an open field: it walks there
    for (var i = 0; i < 10; i++) {
      final from = hero.pos;
      g.tick(0.05);
      expect(hero.moving, isTrue, reason: 'tick $i');
      expect(hero.pos.distanceTo(from), closeTo(walkCap('knight') * 0.05, 1e-6), reason: 'tick $i'); // 7.2, not 8.8
    }
    // A leap: a carry, as far as it goes in its time (100 units in 0.35 s, 286 a second).
    final at = hero.pos, to = at + const Point(100, 0);
    hero.post = to; // it lands on its spot and stays
    g.leap(hero, to);
    runFor(g, hopTime + 0.05);
    expect(hero.move, isNull);
    expect(hero.pos.distanceTo(at), closeTo(100, 1e-6));

    // Cavalry Charge: its gallop at chargeK.speed × its speed stat, the cap not in it.
    final (c, h) = heroCaster(HeroSkill.charge);
    h.stats = h.stats.heroic({HeroStat.speed}, 10);
    expect(h.stats.speed, greaterThan(walkCap(h.type)));
    foeAt(c, 'orc', h.pos + const Point(80, 0));
    c.tick(0.05);
    expect(h.heroSkillAt, c.t);
    final x = h.pos.x;
    c.tick(0.05);
    expect(h.pos.x - x, closeTo(chargeK.speed * h.stats.speed * 0.05, 1e-6));
  });

  /// Mid-wave: an archer with [archerBoots] boots at (0,3), a knight with 12 boots (its walk at the cap, the stat 349)
  /// five columns ahead at (5,3); a held slime far off keeps the wave on.
  (Game, Unit, Unit) catchUp({int archerBoots = 6}) {
    final g = bare();
    g.upgrades['archer'] = List.filled(archerBoots, Item.boots);
    g.upgrades['knight'] = List.filled(12, Item.boots);
    final archer = placeNow(g, 'archer', 0, 3), knight = placeNow(g, 'knight', 5, 3);
    g
      ..startWave()
      ..queue.clear();
    foeAt(g, 'slime', const Point(300, 100));
    return (g, archer, knight);
  }

  test('the catch-up pace is at most twice its own walk and never past its cap: a booted archer behind a booted knight', () {
    final (g, archer, knight) = catchUp();
    const fwd = Point(10.0, 0.0);
    expect(knight.stats.speed, greaterThan(walkCap('knight')));
    expect(knight.walkSpeed, walkCap('knight')); // the fastest melee walks 144
    expect(Game.catchUpMost * archer.walkSpeed, greaterThan(walkCap('archer'))); // 2 × 83.8 = 168 > 132
    expect(g.speedTo(archer, archer.pos + fwd), walkCap('archer')); // was 168 (2× its walk) before 311
    for (var i = 0; i < 20; i++) {
      final from = archer.pos;
      g.tick(0.05);
      expect(archer.pos.distanceTo(from), lessThanOrEqualTo(walkCap('archer') * 0.05 + 1e-9), reason: 'tick $i');
    }
    expect(archer.pos.x - archer.post.x, greaterThan(archer.walkSpeed * 0.05 * 20)); // it did catch up, faster than its walk
    // One bought mid-wave marches in at that pace too: its cap.
    archer.entered = false;
    expect(g.speedTo(archer, archer.pos + fwd), walkCap('archer'));
    // With fewer boots, twice its own walk, as in decisions-log 309.
    final (h, slow, _) = catchUp(archerBoots: 2);
    expect(h.speedTo(slow, slow.pos + fwd), closeTo(Game.catchUpMost * slow.walkSpeed, 1e-9));
  });

  test('a troop that walkers pass steps aside one walk step a tick at most, of its capped walk', () {
    final g = bare();
    g.upgrades['archer'] = List.filled(12, Item.boots); // its speed stat 320: 16 units a tick
    final soldier = placeNow(g, 'soldier', 0, 1), archer = placeNow(g, 'archer', 0, 7);
    archer
      ..pos = archer.post = const Point(100, 56)
      ..busyUntil = hold; // it stands where the soldier passes
    soldier
      ..pos = const Point(82, 56)
      ..post = const Point(12 * tile, 56);
    final from = archer.pos;
    g.tick(0.05);
    expect(soldier.moving, isTrue);
    expect(archer.yieldUntil, greaterThan(g.t)); // it stepped aside ...
    expect(archer.pos.distanceTo(from), closeTo(walkCap('archer') * 0.05, 1e-9)); // ... 6.6 units, not 16
  });
}
