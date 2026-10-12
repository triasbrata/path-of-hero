import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';
import 'package:tower_defense/save.dart';
import 'package:tower_defense/scores.dart';

import 'real_rules.dart';

void run(Game g, {void Function(Game)? each}) {
  for (var i = 0; i < 6000 && g.waveActive; i++) {
    g.tick(0.05);
    each?.call(g);
  }
}

/// A game with the old 6-column deploy zone (as if bought wider), which most fixtures place into.
Game wide([Random? rng]) => Game(rng)..capacity = 6 * rows; // a 6-column zone

/// A [wide] game without the free healer.
Game bare([Random? rng]) => wide(rng)..units.clear();

/// The first boss wave whose boss may be the necromancer ([necroBossFrom]; before it the boss is a type of the pool).
const necroBossWave = (necroBossFrom + bossEvery - 1) ~/ bossEvery * bossEvery;

/// Wins the current wave outright: one slime shows up and is dealt with.
void winWave(Game g) {
  g.startWave();
  g.queue
    ..clear()
    ..add(('slime', Tier.normal));
  g.tick(0.05);
  g.enemies.single.gone = true;
  g.tick(0.05);
}

/// busyUntil for a unit that stands still and never fights.
const hold = 1e9;

/// [Game.place] with the troop standing on its cell at once instead of marching in from the left.
bool placeNow(Game g, String type, int c, int r) {
  if (!g.place(type, c, r)) return false;
  g.units.last
    ..pos = g.units.last.post
    ..entered = true
    ..arriving = false;
  return true;
}

void main() {
  test('every game starts with one free healer', () {
    final g = Game();
    expect(g.troops.single.type, Game.freeHealer);
    expect(g.gold, Game.startGold);
  });

  test('without a living healer a win does not restore the troops', () {
    final g = bare();
    placeNow(g, 'knight', 3, 3);
    final knight = g.troops.single..hp = 40;
    winWave(g);
    expect(g.victoryAt, g.t);
    expect(knight.hp, 40);

    final h = wide();

    placeNow(h, 'knight', 3, 3);
    h.troops.firstWhere((t) => t.type == 'knight').hp = 40;
    h.troops.firstWhere((t) => t.type == Game.freeHealer).hp = 0; // the healer falls…
    h.troops.firstWhere((t) => t.type == Game.freeHealer).dying = 0;
    winWave(h);
    expect(h.troops.firstWhere((t) => t.type == 'knight').hp, 40); // …so no recovery
  });

  test('after the cheering the healer heals everyone in turn: itself, then melee, then long range', () {
    final g = bare()..gold = 1000;
    placeNow(g, 'archer', 1, 1);
    placeNow(g, 'knight', 3, 5);
    placeNow(g, 'priest', 0, 3);
    for (final t in g.troops) {
      t.hp = 1;
    }
    winWave(g);
    final order = <String>[];
    while (order.length < 3 && g.t < 20) {
      g.tick(0.05);
      for (final t in g.troops) {
        if (t.hp == t.maxHp && !order.contains(t.type)) {
          expect(g.t - g.victoryAt, greaterThanOrEqualTo(victoryTime)); // not while cheering
          order.add(t.type);
        }
      }
    }
    expect(order, ['priest', 'knight', 'archer']);
    expect(g.impacts.where((i) => i.$2 == 'heal').length, greaterThanOrEqualTo(3));
  });

  test('after a win only hurt troops are queued and healed', () {
    final g = bare()..gold = 1000;
    placeNow(g, 'archer', 1, 1);
    placeNow(g, 'knight', 3, 5);
    placeNow(g, 'soldier', 3, 2);
    placeNow(g, 'priest', 0, 3);
    final archer = g.troops.firstWhere((t) => t.type == 'archer'), knight = g.troops.firstWhere((t) => t.type == 'knight');
    archer.hp = 1;
    knight.hp = 1;
    winWave(g);
    expect(g.healQueue, [knight, archer]); // melee before long range; the healthy priest and soldier are skipped
    g.impacts.clear();
    for (var i = 0; i < 200; i++) {
      g.tick(0.05);
    }
    expect((knight.hp, archer.hp), (knight.maxHp.toDouble(), archer.maxHp.toDouble()));
    expect(g.impacts.where((i) => i.$2 == 'heal'), hasLength(2)); // no heal wasted on the soldier
  });

  test('a walking troop goes around an idle ally in its path, passing on the far side', () {
    for (final offset in [0.0, 3.0]) {
      final g = bare()..gold = 1000;
      placeNow(g, 'soldier', 1, 3);
      placeNow(g, 'soldier', 4, 3);
      final mover = g.troops.first, ally = g.troops.last..pos += Point(0, offset);
      ally.post = ally.pos;
      mover.post = Point(8 * tile + tile / 2, mover.pos.y);
      var closest = double.infinity;
      for (var i = 0; i < 200; i++) {
        g.tick(0.05);
        closest = min(closest, mover.pos.distanceTo(ally.pos));
        if (offset > 0 && (mover.pos.x - ally.pos.x).abs() < 1) expect(mover.pos.y, lessThan(ally.pos.y)); // far side
      }
      expect(closest, greaterThanOrEqualTo(12 * 0.75), reason: 'offset $offset');
      expect(mover.pos.distanceTo(mover.post), lessThan(1));
    }
  });

  test('a walking troop keeps to its row; the idle ally in the way leaves it and comes back after', () {
    final g = bare()..gold = 1000;
    placeNow(g, 'soldier', 1, 3);
    placeNow(g, 'soldier', 4, 3);
    final mover = g.troops.first, idle = g.troops.last;
    final row = mover.pos.y;
    mover.post = Point(8 * tile + tile / 2, row);
    var closest = double.infinity;
    double? idleDyAtPass;
    for (var i = 0; i < 200; i++) {
      g.tick(0.05);
      expect((mover.pos.y - row).abs(), lessThanOrEqualTo(1), reason: 't=${g.t}'); // walks straight
      closest = min(closest, mover.pos.distanceTo(idle.pos));
      if ((mover.pos.x - idle.pos.x).abs() < 1.2) idleDyAtPass ??= (idle.pos.y - row).abs();
    }
    expect(idleDyAtPass, greaterThanOrEqualTo(tile * 0.75)); // out of the row as the mover went by
    expect(closest, greaterThanOrEqualTo(8));
    expect(mover.pos.distanceTo(mover.post), lessThan(1));
    expect(idle.pos.distanceTo(idle.post), lessThan(1)); // back on its spot
  });

  test('a troop walking back into one coming through from behind is the one that bends around', () {
    final g = bare()..gold = 1000;
    placeNow(g, 'soldier', 1, 3);
    placeNow(g, 'soldier', 4, 3);
    final through = g.troops.first, back = g.troops.last;
    final row = through.pos.y;
    through.post = Point(8 * tile + tile / 2, row);
    back.post = Point(tile / 2, row);
    var closest = double.infinity, bent = 0.0;
    for (var i = 0; i < 200; i++) {
      g.tick(0.05);
      expect((through.pos.y - row).abs(), lessThanOrEqualTo(1), reason: 't=${g.t}'); // has the right of way
      closest = min(closest, through.pos.distanceTo(back.pos));
      bent = max(bent, (back.pos.y - row).abs());
    }
    expect(bent, greaterThanOrEqualTo(tile / 2));
    expect(closest, greaterThanOrEqualTo(8));
    expect(through.pos.distanceTo(through.post), lessThan(1));
    expect(back.pos.distanceTo(back.post), lessThan(1));
  });

  test('an idle troop steps aside for a moving one; only melee yielders may be nudged forward', () {
    for (final type in ['archer', 'wizard', 'priest', 'soldier']) {
      final g = bare()..gold = 1000;
      placeNow(g, type, 1, 3);
      placeNow(g, type, 4, 3);
      final mover = g.troops.first, idle = g.troops.last..pos = g.troops.first.pos + const Point(5, 0);
      idle.post = idle.pos;
      mover.post = Point(12 * tile, mover.pos.y);
      final (mx, ix, iy) = (mover.pos.x, idle.pos.x, idle.pos.y);
      g.tick(0.05);
      expect(mover.pos.x, greaterThan(mx), reason: type); // not pushed back
      expect(idle.pos.y, isNot(iy), reason: type); // stepped aside
      if (type == 'soldier') {
        expect(idle.pos.x, greaterThan(ix)); // melee may be nudged forward
      } else {
        expect(idle.pos.x, lessThanOrEqualTo(ix), reason: type); // never shoved forward
      }
    }
  });

  /// [type] B at (1,3) sets off for a far post; an idle [type] A stands 18px ahead, dead in its path.
  (Game, Unit, Unit) passing(String type) {
    final g = bare()..gold = 1000;
    placeNow(g, type, 1, 3);
    placeNow(g, type, 4, 3);
    final b = g.troops.first, a = g.troops.last..pos = g.troops.first.pos + const Point(18, 0);
    a.post = a.pos;
    b.post = Point(10 * tile, b.pos.y);
    return (g, a, b);
  }

  test('an idle troop sees one coming, steps aside before they touch (never forward) and walks back after', () {
    for (final type in ['archer', 'priest']) {
      final (g, a, b) = passing(type);
      final start = a.pos;
      double? gapWhenStepped;
      for (var i = 0; i < 300; i++) {
        g.tick(0.05);
        if (a.pos != start) gapWhenStepped ??= a.pos.distanceTo(b.pos);
        expect(a.pos.x, lessThanOrEqualTo(start.x + 1e-9), reason: '$type t=${g.t}'); // never forward
      }
      expect(gapWhenStepped, greaterThan(12), reason: type); // moved while B was still out of reach
      expect(b.pos.distanceTo(b.post), lessThan(1), reason: type); // B got through
      expect(a.pos.distanceTo(a.post), lessThan(1), reason: type); // and A is back on its spot
    }
  });

  test('a troop busy shooting still steps aside for one coming through, and keeps firing', () {
    final g = bare()..gold = 1000;
    placeNow(g, 'soldier', 3, 3);
    placeNow(g, 'archer', 4, 3);
    final soldier = g.troops.first, archer = g.troops.last;
    soldier.pos = archer.pos - const Point(18, 0); // right behind, about to walk through
    g.units.add(Unit(Side.enemy, 'werebear', enemyTypes['werebear']!, archer.pos + const Point(56, 0))..busyUntil = hold);
    final start = archer.pos;
    g.tick(0.05);
    expect(soldier.moving, isTrue);
    expect(archer.attackedAt, g.t); // fired this tick…
    expect(g.shots, isNotEmpty);
    expect(archer.pos.y, isNot(start.y)); // …and stepped aside all the same
    expect(archer.yieldUntil, greaterThan(g.t));
  });

  test('mid-battle a priest walking up to heal gets past a kiting archer without bumping into it', () {
    final g = bare()..gold = 1000;
    placeNow(g, 'priest', 0, 3);
    placeNow(g, 'archer', 4, 3);
    placeNow(g, 'knight', 5, 3);
    final priest = g.troops.first, archer = g.troops.elementAt(1), knight = g.troops.last;
    // The knight is in the priest's row, a reach plus two tiles past the archer: to heal it the priest
    // has to get past the archer. The werebear it kites from stands off that row, out of the priest's way.
    knight
      ..pos = Point(archer.pos.x + troopTypes['priest']!.range + 2 * tile, 56)
      ..hp = 80
      ..busyUntil = hold;
    g.units.add(Unit(Side.enemy, 'werebear', enemyTypes['werebear']!, archer.pos + const Point(24, 18))..busyUntil = hold);
    var closest = double.infinity, kited = false;
    for (var i = 0; i < 200; i++) {
      g.tick(0.05);
      knight.attackedAt = g.t; // the knight is in the fight
      kited |= archer.moving && archer.dir == 1;
      closest = min(closest, priest.pos.distanceTo(archer.pos));
    }
    expect(kited, isTrue); // the archer was backing off while shooting
    expect(priest.pos.x, greaterThan(archer.pos.x)); // got past
    expect(closest, greaterThanOrEqualTo(8));
    expect(knight.hp, greaterThan(80));
  });

  test('a priest a tile behind an archer heals melee well ahead of the archer without passing it', () {
    // The rest a tile behind the rearmost fighter, long range too: with keepSupports a healer comes up to healBehind
    // behind the rearmost melee in the fight instead (decisions-log 324, front_cap_test).
    final g = bare()
      ..gold = 1000
      ..keepSupports = false;
    placeNow(g, 'priest', 3, 3);
    placeNow(g, 'archer', 4, 3);
    placeNow(g, 'knight', 5, 3);
    final priest = g.troops.first, archer = g.troops.elementAt(1), knight = g.troops.last;
    expect(archer.pos.x - priest.pos.x, tile);
    knight
      ..pos = archer.pos + const Point(64, 0)
      ..hp = 80
      ..busyUntil = hold;
    archer.busyUntil = hold;
    g.units.add(Unit(Side.enemy, 'werebear', enemyTypes['werebear']!, const Point(300, 104))..busyUntil = hold);
    for (var i = 0; i < 60; i++) {
      g.tick(0.05);
      expect(priest.pos.x, lessThan(archer.pos.x), reason: 't=${g.t}');
    }
    expect(knight.hp, greaterThan(80));
  });

  /// A mid-battle game with a priest behind knights and one far-off slime keeping the wave on.
  (Game, Unit) healerBattle(List<(int, int)> knights) {
    final g = bare()..gold = 1000;
    placeNow(g, 'priest', 0, 3);
    for (final (c, r) in knights) {
      placeNow(g, 'knight', c, r);
    }
    g.startWave();
    g.queue
      ..clear()
      ..add(('slime', Tier.normal));
    return (g, g.troops.first);
  }

  void expectBehindLine(Game g, Unit priest) {
    final rear = g.troops.where((t) => t != priest).map((t) => t.pos.x).reduce(min);
    expect(priest.pos.x, lessThanOrEqualTo(rear - tile + 0.5), reason: 't=${g.t}');
  }

  test('mid-battle a healer with no one hurt follows the army a tile behind its rearmost fighter', () {
    final (g, priest) = healerBattle([(2, 2), (2, 5)]);
    for (var i = 0; i < 100; i++) {
      g.tick(0.05);
      expectBehindLine(g, priest);
    }
    expect(g.waveActive, isTrue);
    expect(priest.pos.x, greaterThan(4 * tile)); // kept up
  });

  test('mid-battle a healer heals a hurt ally from behind the line', () {
    final (g, priest) = healerBattle([(2, 2), (2, 5)]);
    final knight = g.troops.last..hp = 50;
    for (var i = 0; i < 60; i++) {
      g.tick(0.05);
      expectBehindLine(g, priest);
    }
    expect(knight.hp, greaterThan(50));
  });

  test('mid-battle a healer goes up to reach hurt melee past the archers, then falls back', () {
    // The rest a tile behind the rearmost fighter, long range too: with keepSupports a healer comes up to healBehind
    // behind the rearmost melee in the fight instead (decisions-log 324, front_cap_test).
    final g = bare()
      ..gold = 1000
      ..keepSupports = false;
    placeNow(g, 'priest', 0, 3);
    placeNow(g, 'archer', 2, 2);
    placeNow(g, 'archer', 2, 5);
    placeNow(g, 'knight', 2, 3);
    final priest = g.troops.first, knight = g.troops.last
      ..pos = const Point(150, 56)
      ..hp = 80;
    // fighters (and the far-off slime keeping the wave on) stand still: fixed lines
    for (final t in g.troops.where((t) => t != priest)) {
      t.busyUntil = hold;
    }
    g.units.add(Unit(Side.enemy, 'slime', enemyTypes['slime']!, const Point(300, 100))..busyUntil = hold);
    final rest = 40.0 - tile, limit = 150 - troopTypes['priest']!.range * 0.8;
    expect(knight.pos.distanceTo(Point(rest, 56)), greaterThan(troopTypes['priest']!.range)); // out of reach from rest
    var furthest = priest.pos.x;
    for (var i = 0; i < 300 && knight.hp < knight.maxHp; i++) {
      g.tick(0.05);
      furthest = max(furthest, priest.pos.x);
      expect(priest.pos.x, lessThanOrEqualTo(limit + 0.5), reason: 't=${g.t}');
    }
    expect(knight.hp, knight.maxHp);
    expect(furthest, greaterThan(rest + tile)); // went up past the rest line
    for (var i = 0; i < 300; i++) {
      g.tick(0.05);
    }
    expect(g.waveActive, isTrue);
    expect((priest.pos.x - rest).abs(), lessThan(2)); // back at the rear
  });

  test('mid-battle a healer keys off the engaged fighters, and a fresh troop at the back does not pull it back', () {
    // The rest a tile behind the rearmost fighter, long range too: with keepSupports a healer comes up to healBehind
    // behind the rearmost melee in the fight instead (decisions-log 324, front_cap_test).
    final g = bare()
      ..gold = 1000
      ..keepSupports = false;
    placeNow(g, 'priest', 0, 3);
    placeNow(g, 'archer', 2, 2);
    placeNow(g, 'knight', 2, 4);
    placeNow(g, 'knight', 2, 5);
    final priest = g.troops.first, archer = g.troops.elementAt(1), knights = g.troops.skip(2).toList();
    // everyone but the priest stands still: fixed lines
    archer
      ..pos = const Point(72, 40)
      ..busyUntil = hold;
    for (final k in knights) {
      k
        ..pos = Point(120, k.pos.y)
        ..busyUntil = hold;
    }
    g.units.add(Unit(Side.enemy, 'slime', enemyTypes['slime']!, const Point(300, 100))..busyUntil = hold);
    void engage() {
      for (final k in knights) {
        k.attackedAt = g.t;
      }
    }

    void settle({bool engaged = false}) {
      for (var i = 0; i < 200; i++) {
        g.tick(0.05);
        if (engaged) engage();
      }
    }

    settle(); // nobody engaged yet: a tile behind the rearmost of all, the archer
    expect((priest.pos.x - (72 - tile)).abs(), lessThan(2));
    settle(engaged: true); // the knights are fighting, the archer isn't: a tile behind the knights
    expect((priest.pos.x - (120 - tile)).abs(), lessThan(2));

    expect(placeNow(g, 'soldier', g.baseCol, 6), isTrue); // the zone's back column (the back line moved up)
    final fresh = g.troops.last, settled = priest.pos.x, freshX = fresh.pos.x;
    for (var i = 0; i < 60; i++) {
      g.tick(0.05);
      engage();
      expect(priest.pos.x, greaterThan(settled - 2), reason: 't=${g.t}');
    }
    expect(fresh.pos.x, greaterThan(freshX + 2 * tile)); // walked up meanwhile
  });

  test('mid-battle a healer rests no further back than half a tile inside the keep-up floor, [keepUpInset] inside the view, '
      'walking up to it at the catch-up pace', () {
    // The floor alone: with keepSupports the healer's rest follows the knight's fight (decisions-log 324's healBehind).
    final g = bare()
      ..gold = 1000
      ..keepSupports = false;
    placeNow(g, 'priest', 0, 3);
    placeNow(g, 'archer', 2, 2);
    placeNow(g, 'knight', 5, 3);
    final ts = g.troops.toList();
    final (priest, archer, knight) = (ts[0], ts[1], ts[2]);
    archer.busyUntil = hold; // the rearmost fighter: the priest's rest would be a tile behind it
    knight
      ..pos = const Point(500, 56)
      ..busyUntil = hold; // the view centres its fight, far ahead of the rear (#85)
    g.units.add(Unit(Side.enemy, 'slime', enemyTypes['slime']!, const Point(512, 56))..busyUntil = hold);
    for (var i = 0; i < 20; i++) {
      g.tick(0.05);
    }
    expect(priest.pos.x, lessThan(g.cam - Game.offViewBy)); // out of sight, on its way
    expect(g.speedTo(priest, priest.pos + const Point(10, 0)), knight.stats.speed); // the fastest melee's
    for (var i = 0; i < 300; i++) {
      g.tick(0.05);
    }
    expect(g.baseX, lessThan(archer.pos.x)); // the back line stayed behind the archer ...
    expect(priest.pos.x, closeTo(g.cam + keepUpInset + tile / 2, 1)); // ... the priest kept up with the view
  });

  test('mid-battle a healer does not chase a hurt ally beyond reach of the line', () {
    final (g, priest) = healerBattle([(2, 3), (3, 5)]);
    final far = g.troops.last
      ..pos = const Point(200, 88)
      ..hp = 50;
    for (var i = 0; i < 20; i++) {
      g.tick(0.05);
      expectBehindLine(g, priest);
    }
    expect(far.hp, 50);
    expect(g.impacts.where((i) => i.$2 == 'heal'), isEmpty);
  });

  test('before a wave a troop moves to an empty zone cell, or swaps with the one standing there', () {
    final g = bare()..gold = 1000;
    placeNow(g, 'soldier', 1, 1);
    placeNow(g, 'knight', 3, 3);
    final soldier = g.troops.first, knight = g.troops.last;
    g.sfx.clear();
    expect(g.move(soldier, 2, 2), isTrue);
    expect((soldier.post, soldier.pos), (const Point(40.0, 40.0), const Point(40.0, 40.0)));
    expect(g.sfx, [Sfx.place]);
    expect(g.move(soldier, 3, 3), isTrue);
    expect((soldier.cell, soldier.pos), ((3, 3), const Point(56.0, 56.0)));
    expect((knight.post, knight.pos), (const Point(40.0, 40.0), const Point(40.0, 40.0))); // took the old spot
  });

  test('a move outside the zone, mid-battle or after game over fails and changes nothing', () {
    final g = bare()..gold = 1000;
    placeNow(g, 'soldier', 1, 1);
    final soldier = g.troops.single, at = soldier.post;
    final fails = <void Function()>[
      () => expect(g.move(soldier, g.zoneCols, 1), isFalse),
      () {
        g.units.add(Unit(Side.enemy, 'slime', enemyTypes['slime']!, const Point(300, 40)));
        expect(g.waveActive, isTrue);
        expect(g.move(soldier, 2, 2), isFalse);
        g.units.removeLast();
      },
      () {
        g.lives = 0;
        expect(g.move(soldier, 2, 2), isFalse);
      },
    ];
    for (final f in fails) {
      g.sfx.clear();
      f();
      expect(g.sfx, [Sfx.error]);
      expect((soldier.post, soldier.pos), (at, at));
    }
  });

  /// A werebear right next to a 1-hp soldier at (4,1): one swing kills it.
  (Game, Unit) doomedSoldier() {
    final g = bare()..gold = 1000;
    placeNow(g, 'soldier', 4, 1);
    final s = g.troops.single..hp = 1;
    g.units.add(Unit(Side.enemy, 'werebear', enemyTypes['werebear']!, s.pos + const Point(10, 0)));
    return (g, s);
  }

  test('the last troop falling costs a heart and the wave is played again (wipe_test.dart); at the last heart the game is '
      'over, and then stands still', () {
    expect(bare().over, isFalse); // no troops yet is not a wipe-out
    final (g, s) = doomedSoldier();
    g.tick(0.05);
    expect(s.alive, isFalse);
    expect((g.wipedOut, g.over, g.lives, g.waveActive), (true, false, Game.startLives - wipeLives, false));
    expect(g.sfx, contains(Sfx.lose));
    final (h, v) = doomedSoldier();
    h.lives = wipeLives;
    h.tick(0.05);
    expect((v.alive, h.wipedOut, h.over), (false, true, true));
    final t = h.t;
    h.tick(0.05);
    expect(h.t, t);
  });

  test('a troop falling while another still stands is not game over', () {
    final (g, s) = doomedSoldier();
    placeNow(g, 'soldier', 0, 7);
    g.tick(0.05);
    expect(s.alive, isFalse);
    expect((g.wipedOut, g.over), (false, false));
    expect(g.sfx, contains(Sfx.fall));
    expect(g.sfx, isNot(contains(Sfx.lose)));
  });

  /// [priests] priests and enough knights for a 9-troop heal queue, all at 1 hp, after a won wave.
  /// Returns the game and how long the after-wave heal took once the cheering ended.
  (Game, double) healRound(int priests) {
    final g = bare()..gold = 5000;
    for (var i = 0; i < priests; i++) {
      placeNow(g, 'priest', 0, i * 2 + 1);
    }
    for (var i = 0; i < 9 - priests; i++) {
      placeNow(g, 'knight', 3 + i ~/ rows, i % rows);
    }
    for (final t in g.troops) {
      t.hp = 1;
    }
    winWave(g);
    expect(g.healQueue, hasLength(9));
    g.impacts.clear(); // count only the after-wave round (mid-battle heals may reach them too)
    final firstHeal = <Unit, double>{};
    for (var i = 0; i < 400 && g.healQueue.isNotEmpty; i++) {
      g.tick(0.05);
      for (final p in g.troops.where((t) => t.stats.heals && t.attackedAt >= g.victoryAt)) {
        if (firstHeal.containsKey(p)) continue;
        firstHeal[p] = g.t;
        expect(p.hp, p.maxHp, reason: 'a hurt priest heals itself first');
      }
    }
    expect(g.healQueue, isEmpty);
    expect(firstHeal, hasLength(priests)); // every priest took part
    return (g, g.t - g.victoryAt - victoryTime);
  }

  test('after a win every priest heals at its own pace, itself first, draining the queue faster', () {
    final (one, slow) = healRound(1);
    final (three, fast) = healRound(3);
    expect(three.impacts.where((i) => i.$2 == 'heal'), hasLength(9));
    expect(three.troops.every((t) => t.hp == t.maxHp), isTrue);
    expect(one.troops.every((t) => t.hp == t.maxHp), isTrue);
    expect(fast, lessThan(slow / 2.5)); // ~3x faster
  });


  test('mid-battle a non-melee troop may be nudged forward by one coming through', () {
    final g = bare()..gold = 1000;
    placeNow(g, 'archer', 1, 3);
    placeNow(g, 'archer', 4, 3);
    final mover = g.troops.first, idle = g.troops.last
      ..pos = g.troops.first.pos + const Point(5, 0)
      ..busyUntil = hold;
    g.units.add(Unit(Side.enemy, 'werebear', enemyTypes['werebear']!, Point(300, mover.pos.y))..busyUntil = hold);
    expect(g.waveActive, isTrue);
    final ix = idle.pos.x;
    g.tick(0.05);
    expect(idle.pos.x, greaterThan(ix)); // before a wave this is ruled out (tests above)
  });

  /// An archer at [c],3 with a held werebear [gap]px in front of it.
  (Game, Unit, Unit) kiting(int c, double gap) {
    final g = bare()..gold = 1000;
    placeNow(g, 'archer', c, 3);
    final a = g.troops.single, foe = Unit(Side.enemy, 'werebear', enemyTypes['werebear']!, a.pos + Point(gap, 0))..busyUntil = hold;
    g.units.add(foe);
    return (g, a, foe);
  }

  test('an archer with a foe too close backs off while still shooting, facing it', () {
    final (g, a, foe) = kiting(3, 30);
    final range = troopTypes['archer']!.range, startX = a.pos.x;
    var shots = 0, lastShot = a.attackedAt, backedOff = false;
    for (var i = 0; i < 60; i++) {
      g.tick(0.05);
      if (a.attackedAt != lastShot) (shots, lastShot) = (shots + 1, a.attackedAt);
      if (a.moving) {
        backedOff = true;
        expect(a.pos.x, lessThan(startX));
      }
      expect(a.dir, 1, reason: 'faces the foe at t=${g.t}');
    }
    expect(backedOff, isTrue);
    expect(shots, greaterThanOrEqualTo(4)); // kept firing
    expect(a.pos.distanceTo(foe.pos), greaterThanOrEqualTo(range * 0.75 - 0.5));
    expect(a.moving, isFalse); // settled at the edge of its reach
  });

  test('a kiting archer backs off no further than half a tile inside the view when that is past the back line, '
      '[keepUpInset] further in once the wave has shown a fight (#85)', () {
    for (final shown in [false, true]) {
      final (g, a, foe) = kiting(3, 30); // it would back off to 38 (the test above)
      final inset = shown ? keepUpInset : 0.0, edge = a.pos.x - tile - inset; // the floor a tile behind it
      if (shown) g.fightX = foe.pos.x; // as if the view had centred a fight this wave
      for (var i = 0; i < 40; i++) {
        g.cam = edge; // held there
        g.tick(0.05);
        expect(g.baseX, lessThan(edge));
        expect(a.pos.x, greaterThanOrEqualTo(edge + inset + tile / 2 - 1e-9), reason: '$shown');
      }
      expect(a.pos.x, closeTo(edge + inset + tile / 2, 1e-9), reason: '$shown');
    }
  });

  test('a kiting archer never backs off past the back line', () {
    final (g, a, _) = kiting(0, 30);
    expect(a.pos.x, g.baseX + tile / 2);
    var shots = 0;
    for (var i = 0; i < 40; i++) {
      g.tick(0.05);
      if (a.attackedAt == g.t) shots++;
      expect(a.pos.x, greaterThanOrEqualTo(g.baseX + tile / 2 - 1e-9));
    }
    expect(shots, greaterThan(0));
  });

  test('two alike troops walking into each other: the later placed one makes way, the first is not pushed', () {
    for (final firstOnTop in [true, false]) {
      final g = bare()..gold = 1000;
      placeNow(g, 'soldier', 1, 3);
      placeNow(g, 'soldier', 1, 4);
      final first = g.troops.first, later = g.troops.last;
      final top = const Point(24.0, 56.0), low = const Point(24.0, 60.0); // 4px apart: overlapping
      first.pos = firstOnTop ? top : low;
      later.pos = firstOnTop ? low : top;
      for (final u in [first, later]) {
        u.post = Point(200, u.pos.y);
      }
      final (f0, gap0) = (first.pos, first.pos.distanceTo(later.pos));
      g.tick(0.05);
      expect((first.moving, later.moving), (true, true));
      expect(first.pos.x, closeTo(f0.x + troopTypes['soldier']!.speed * 0.05, 1e-9), reason: '$firstOnTop');
      expect(first.pos.y, f0.y, reason: '$firstOnTop'); // walked straight on, not shoved
      expect(later.pos.distanceTo(first.pos), greaterThan(gap0), reason: '$firstOnTop'); // the later one gave way
    }
  });

  test('idle mid-battle priests spread out a tile apart behind the fighters', () {
    final g = bare()..gold = 1000;
    for (final r in [1, 3, 6]) {
      placeNow(g, 'priest', 0, r);
    }
    for (final r in [2, 5]) {
      placeNow(g, 'knight', 3, r);
    }
    for (final k in g.troops.where((t) => t.type == 'knight')) {
      k
        ..pos = Point(120, k.pos.y)
        ..busyUntil = hold;
    }
    g.units.add(Unit(Side.enemy, 'werebear', enemyTypes['werebear']!, const Point(300, 64))..busyUntil = hold);
    final priests = g.troops.where((t) => t.stats.heals).toList();
    double closest() {
      var d = double.infinity;
      for (var i = 0; i < priests.length; i++) {
        for (var j = i + 1; j < priests.length; j++) {
          d = min(d, priests[i].pos.distanceTo(priests[j].pos));
        }
      }
      return d;
    }

    for (var i = 0; i < 300; i++) {
      g.tick(0.05);
      expect(closest(), greaterThanOrEqualTo(10), reason: 't=${g.t}');
    }
    expect(g.waveActive, isTrue);
    expect(closest(), greaterThanOrEqualTo(tile - 1));
    for (final p in priests) {
      expect(p.pos.x, closeTo(120 - tile, 2)); // behind the fighters
      expect(p.moving, isFalse);
    }
  });

  /// A held knight at [frontX] and a held soldier at the back; a held werebear at [foeX] keeps the wave on.
  (Game, Unit, Unit) front(double frontX, double foeX) {
    final g = bare()..gold = 1000;
    placeNow(g, 'knight', 3, 3);
    placeNow(g, 'soldier', 1, 2);
    final lead = g.troops.first
      ..pos = Point(frontX, 56)
      ..busyUntil = hold;
    final back = g.troops.last..busyUntil = hold;
    g.units.add(Unit(Side.enemy, 'werebear', enemyTypes['werebear']!, Point(foeX, 100))..busyUntil = hold);
    return (g, lead, back);
  }

  test('mid-wave the back line stays put, posts and all, however far the army goes; a win moves it up to the rearmost troop', () {
    final (g, lead, back) = front(500, 1000); // the werebear is off screen: the view follows the army's front
    const rear = 100.0;
    back.pos = Point(rear, back.pos.y);
    final posts = [lead.post, back.post];
    for (var i = 0; i < 60; i++) {
      g.tick(0.05);
    }
    expect(g.cam, closeTo(g.camTarget, 1));
    expect(g.cam, greaterThan(g.baseX + 2 * tile)); // the view went on ...
    back.pos = Point(300, back.pos.y); // ... and so did the rearmost troop
    g.tick(0.05);
    expect(g.baseX, 0); // the back line didn't
    expect([lead.post, back.post], posts);
    expect(g.lives, Game.startLives);

    g.enemies.single.gone = true; // the wave is won
    g.tick(0.05);
    expect(g.victoryAt, g.t);
    const to = 300 ~/ tile * tile; // the rearmost troop's tile edge
    expect(g.baseX, to);
    expect([lead.post, back.post], [for (final p in posts) p + const Point(to, 0)]);
  });

  test('mid-wave a troop is stopped at the back line, which never goes back, not even on a win with a troop still marching in', () {
    final (g, _, back) = front(500, 1000);
    g.baseX = 4 * tile; // where a win left it
    back.pos = Point(tile, back.pos.y); // fallen back behind it
    g.tick(0.05);
    expect((g.baseX, back.pos.x), (4 * tile, 4 * tile + Game.clearOfLine)); // moved up to the line
    expect(g.place('archer', g.baseCol + 1, 5), isTrue); // bought mid-wave: it marches in from behind the line
    final late = g.troops.last;
    g.enemies.single.gone = true;
    g.tick(0.05);
    expect(g.victoryAt, g.t);
    expect(late.pos.x, lessThan(4 * tile));
    expect(g.baseX, 4 * tile);
  });

  test('mid-wave a bought troop starts just left of the view, wherever the back line is, and marches in at the catch-up pace', () {
    final (g, _, _) = front(500, 1000);
    g.cam = g.baseX - 5 * tile; // the view left of the back line (a fight centred there)
    expect(g.place('archer', g.baseCol + 2, 4), isTrue);
    final u = g.troops.last, x = u.pos.x;
    expect((x, u.entered), (g.cam - 2 * tile, false));
    final pace = max(troopTypes['knight']!.speed, troopTypes['soldier']!.speed); // the fastest melee
    expect(g.speedTo(u, u.post), pace);
    g.tick(0.05);
    expect(u.pos.x, closeTo(x + pace * 0.05, 1e-9));

    // The view far ahead of the line, which stays put all wave: not from behind the line, but just off screen,
    // already past the line (entered), on its way to the fight at the same pace.
    g.cam = g.baseX + 40 * tile;
    expect(g.place('archer', g.baseCol + 2, 5), isTrue);
    final late = g.troops.last, from = late.pos.x;
    expect(from, g.cam - 2 * tile);
    g.tick(0.05);
    expect((late.entered, late.arriving), (true, false));
    g.cam = g.baseX + 40 * tile; // held there (the tick eased it toward the fight)
    expect(g.speedTo(late, late.pos + const Point(10, 0)), pace); // out of sight: the catch-up pace
  });

  test('before a wave the back line stays put', () {
    final g = bare()..gold = 1000;
    placeNow(g, 'knight', 3, 3);
    final lead = g.troops.single..pos = const Point(500, 56);
    final post = lead.post;
    g.tick(0.05);
    expect(g.waveActive, isFalse);
    expect(g.baseX, 0);
    expect(lead.post, post);
  });

  test('back-line troops make way for melee instead of being pushed forward', () {
    final g = bare()..gold = 1000;
    placeNow(g, 'priest', 1, 2);
    placeNow(g, 'archer', 2, 3);
    placeNow(g, 'knight', 0, 3);
    final priest = g.troops.firstWhere((t) => t.type == 'priest'), archer = g.troops.firstWhere((t) => t.type == 'archer');
    final knight = g.troops.firstWhere((t) => t.type == 'knight');
    knight
      ..pos = archer.pos - const Point(4, 0) // a fresh knight walks up through the archer…
      ..post = Point(200, archer.pos.y);
    priest.pos = archer.pos - const Point(3, 1); // …who is also crowded by the priest behind
    final (px, ax, kx) = (priest.pos.x, archer.pos.x, knight.pos.x);
    g.tick(0.05);
    expect(archer.pos.x, lessThanOrEqualTo(ax)); // never shoved to the front
    expect(priest.pos.x, lessThanOrEqualTo(px));
    expect((archer.pos.y - knight.pos.y).abs(), greaterThan(0)); // stepped aside
    expect(knight.pos.x, greaterThan(kx)); // the knight kept going
  });

  test('mid-battle troops drop on any cell; after the win the newer one finds a spot of its own', () {
    final g = bare()..gold = 1000;
    placeNow(g, 'knight', 3, 3);
    final knight = g.troops.single;
    g.startWave();
    g.queue
      ..clear()
      ..add(('slime', Tier.normal));
    g.tick(0.05);
    expect(placeNow(g, 'soldier', knight.cell.$1, knight.cell.$2), isTrue); // the knight's cell, but the battle is on
    final soldier = g.troops.firstWhere((t) => t.type == 'soldier');
    g.enemies.single.gone = true;
    g.tick(0.05);
    expect(g.victoryAt, g.t);
    expect(knight.cell, (3 + g.baseCol, 3)); // first come keeps it
    expect(soldier.cell, isNot(knight.cell));
    final (sc, sr) = soldier.cell;
    final (kc, kr) = knight.cell;
    expect((sc - kc).abs() + (sr - kr).abs(), 1); // the nearest free cell
    expect(placeNow(g, 'archer', kc, kr), isFalse); // between waves it's one per cell again
  });

  /// Drops [type] on [c],[r] mid-battle (any cell will do), then wins the wave.
  Unit dropMidBattle(Game g, String type, int c, int r) {
    g.startWave();
    g.queue
      ..clear()
      ..add(('slime', Tier.normal));
    g.tick(0.05);
    expect(placeNow(g, type, c, r), isTrue);
    final u = g.troops.last;
    g.enemies.single.gone = true;
    g.tick(0.05);
    expect(g.victoryAt, g.t);
    return u;
  }

  test('a melee troop dropped on a taken cell moves forward, never back', () {
    final g = bare()..gold = 1000;
    placeNow(g, 'soldier', 0, 7); // keeps the back line where it is
    for (final (c, r) in [(3, 2), (3, 4), (4, 3), (3, 3)]) {
      placeNow(g, 'knight', c, r);
    }
    final soldier = dropMidBattle(g, 'soldier', 3, 3);
    final (sc, sr) = soldier.cell;
    expect(sc, greaterThanOrEqualTo(3)); // (2,3) is free and nearer, but behind
    expect(g.troops.where((t) => t.cell == (sc, sr)), [soldier]);
    expect((sc - 3).abs() + (sr - 3).abs(), 2); // nearest free cell ahead
  });

  test('a long-range troop dropped on a taken cell stays in its column', () {
    final g = bare()..gold = 1000;
    placeNow(g, 'soldier', 0, 7);
    for (final (c, r) in [(3, 2), (3, 4), (3, 3)]) {
      placeNow(g, 'knight', c, r);
    }
    final archer = dropMidBattle(g, 'archer', 3, 3);
    expect(archer.cell.$1, 3); // (2,3) and (4,3) are free and nearer, but off its column
    expect(archer.cell.$2, anyOf(1, 5));
  });

  group('the battle point (#85): the view centres where the troops and the monsters meet', () {
    /// A troop of [type] at ([x], [y]) on the first free cell of the zone; it stands still and never fights
    /// unless [held] is false.
    Unit troop(Game g, String type, double x, double y, {bool held = true}) {
      g.gold = 100000;
      final (c, r) = [for (var c = g.baseCol; c < g.baseCol + g.zoneCols; c++) for (var r = 0; r < rows; r++) (c, r)]
          .firstWhere((cell) => g.troopAt(cell.$1, cell.$2) == null);
      expect(placeNow(g, type, c, r), isTrue);
      return g.troops.last
        ..pos = Point(x, y)
        ..busyUntil = held ? hold : double.negativeInfinity;
    }

    /// A monster of [type] at ([x], [y]), not entered; it stands still and never fights unless [held] is false.
    Unit foe(Game g, String type, double x, double y, {bool held = true}) {
      final u = Unit(Side.enemy, type, enemyTypes[type]!, Point(x, y))..busyUntil = held ? hold : double.negativeInfinity;
      g.units.add(u);
      return u;
    }

    /// Three knights at x 300 against three orcs at 312 (y 24, 56, 88): one fight of weight 6 at 306.
    (List<Unit>, List<Unit>) clash(Game g) =>
        ([for (final y in [24.0, 56.0, 88.0]) troop(g, 'knight', 300, y)], [for (final y in [24.0, 56.0, 88.0]) foe(g, 'orc', 312, y)]);

    test('a melee pair is the meeting point, the monster entered or not', () {
      final g = bare();
      troop(g, 'knight', 100, 56);
      final orc = foe(g, 'orc', 112, 56);
      expect(orc.entered, isFalse);
      expect(g.fights, [(x: 106.0, w: 2.0, lo: 106.0, hi: 106.0)]);
      g.aim();
      expect((g.meetX, g.fightX, g.meetMode, g.camTarget), (106.0, 106.0, MeetMode.contact, 106 - g.viewW / 2));
    });

    test('a shooter in contact weighs half: four make a fight, three only an approach at their midpoint', () {
      final g = bare();
      final archers = [for (final y in [60.0, 68.0, 76.0, 84.0]) troop(g, 'archer', 100, y)];
      foe(g, 'orc', 160, 72);
      expect(g.fights, [(x: 130.0, w: 2.0, lo: 130.0, hi: 130.0)]);
      g.aim();
      expect((g.meetMode, g.meetX), (MeetMode.contact, 130.0));
      g.units.remove(archers.last);
      g.t += contactGrace + 0.05;
      expect(g.fights, [(x: 130.0, w: 1.5, lo: 130.0, hi: 130.0)]);
      g.aim();
      expect((g.meetMode, g.meetX), (MeetMode.approach, 130.0)); // in reach of each other: front + 60/2
    });

    test('a shooter joins the fight nearest its target, not its own midpoint, so it never chains two fights', () {
      ContactPoint pt(double p, double w, double fx, int id, [bool ranged = false]) => (p: p, w: w, fx: fx, ranged: ranged, id: id);
      final fights = BattleFocus.fightsOf([
        pt(194, 1, 200, 1),
        pt(194, 1, 200, 2),
        for (var i = 0; i < 6; i++) pt(306, 1, 312, 10 + i),
        pt(236, 0.5, 200, 20, true),
        pt(276, 0.5, 312, 21, true),
        for (var i = 0; i < 4; i++) pt(400, 0.5, 440, 30 + i, true),
      ]);
      final want = [(202.4, 2.5, 194.0, 194.0), (1974 / 6.5, 6.5, 306.0, 306.0), (400.0, 2.0, 400.0, 400.0)];
      expect(fights, hasLength(3)); // chained on p alone, the first two would be one (gaps 42, 40, 30)
      for (var i = 0; i < 3; i++) {
        final (x, w, lo, hi) = want[i];
        expect([fights[i].x, fights[i].w, fights[i].lo, fights[i].hi], [closeTo(x, 1e-9), closeTo(w, 1e-9), lo, hi]);
      }
    });

    test('archers behind the clash join it', () {
      final g = bare();
      clash(g);
      for (final y in [40.0, 56.0, 72.0, 104.0]) {
        troop(g, 'archer', 250, y);
      }
      expect(g.fights, [(x: 299.75, w: 8.0, lo: 306.0, hi: 306.0)]);
    });

    test('a long reach pulls the fight back no more than reachPull: the view stays where they meet', () {
      final g = bare();
      clash(g);
      for (final y in [40.0, 56.0, 72.0, 88.0]) {
        troop(g, 'archer', 20, y).stats = const Stats(hp: 60, cost: 70, speed: 22, dmg: 9, range: 300, rate: 0.6, shotSpeed: 200);
      }
      // Each archer's point is 2.5 tiles behind its orc (272), not halfway (166): (306 x 6 + 272 x 2) / 8.
      expect(g.fights, [(x: 297.5, w: 8.0, lo: 306.0, hi: 306.0)]);
    });

    test('the fight shown is kept until another is 1.5x as heavy for 0.75 s', () {
      final g = bare();
      final (_, orcs) = clash(g); // weight 6 at 306
      troop(g, 'knight', 188, 8);
      troop(g, 'knight', 188, 120);
      foe(g, 'bat', 200, 8);
      foe(g, 'bat', 200, 120); // weight 4 at 194
      g.aim();
      expect(g.meetX, 306);
      orcs[0].dying = 0; // 4 against 4: not enough
      g.aim();
      expect(g.meetX, 306);
      orcs[1].dying = 0; // 2 against 4: the rival must hold on
      g.aim();
      for (var i = 0; i < 14; i++) {
        g.t += 0.05;
        g.aim();
      }
      expect(g.meetX, 306); // 0.70 s
      for (var i = 0; i < 2; i++) {
        g.t += 0.05;
        g.aim();
      }
      expect(g.meetX, 194); // 0.80 s
    });

    test('a troop that ran ahead does not move the view, even in a small fight of its own', () {
      final g = bare();
      clash(g);
      troop(g, 'swordsman', 420, 56);
      g.aim();
      expect(g.meetX, 306);
      foe(g, 'slime', 432, 56);
      expect(g.fights, contains((x: 426.0, w: 2.0, lo: 426.0, hi: 426.0)));
      for (var i = 0; i < 20; i++) {
        g.t += 0.05;
        g.aim();
        expect(g.meetX, 306);
      }
    });

    test('a fight with a boss outweighs two stray pairs', () {
      final g = bare();
      troop(g, 'knight', 300, 56);
      troop(g, 'knight', 150, 40);
      troop(g, 'knight', 150, 88);
      g.units.add(g.monster('orc', Tier.boss, const Point(312, 56))..busyUntil = hold); // weight 2 x 3
      foe(g, 'slime', 162, 40);
      foe(g, 'slime', 162, 88); // weight 4
      g.aim();
      expect(g.meetX, 306);
    });

    test('a unit in a hop is neither a contact point nor a foe', () {
      final g = bare();
      clash(g);
      final bat = foe(g, 'bat', 296, 72)..move = Carry(const Point(360, 72), const Point(296, 72), g.t, g.t + hopTime, lift: hopHeight);
      expect(g.fights, [(x: 306.0, w: 6.0, lo: 306.0, hi: 306.0)]);
      bat.move = null; // landed, on the knights
      final f = g.fights.single;
      expect([f.x, f.w], [closeTo(2134 / 7, 1e-9), 7.0]);
    });

    test('a pair parted a moment holds the point for contactGrace, then the view follows the front toward the next meeting', () {
      final g = bare();
      troop(g, 'knight', 300, 56);
      final orc = foe(g, 'orc', 312, 56);
      g.aim();
      expect((g.meetMode, g.meetX), (MeetMode.contact, 306.0));
      final t0 = g.t;
      orc.pos = const Point(340, 56); // knocked back
      g.t = t0 + 0.5;
      g.aim();
      expect((g.meetMode, g.meetX), (MeetMode.hold, 306.0));
      g.t = t0 + 1.05;
      g.aim();
      // Where they would meet (300 + 18 x 24/42 + 11) is further than the front + a tile.
      expect((g.meetMode, g.meetX), (MeetMode.approach, 316.0));
    });

    test('with no troop on the field the point holds (it used to go back to the line)', () {
      final g = bare();
      final knight = troop(g, 'knight', 300, 56);
      foe(g, 'orc', 312, 56);
      g.aim();
      knight.entered = false;
      g.aim();
      expect((g.meetMode, g.meetX, g.camTarget), (MeetMode.hold, 306.0, 146.0));
    });

    test('in the stall march, with every monster behind the front, the view follows the closest pursuit', () {
      final g = bare()..marching = true;
      troop(g, 'knight', 300, 40);
      troop(g, 'knight', 300, 88);
      foe(g, 'orc', 150, 40);
      foe(g, 'orc', 60, 88);
      g.aim();
      expect((g.meetMode, g.meetX), (MeetMode.chase, 225.0));
    });

    test('the troop front: a quartile from the front, capped 2 tiles ahead of the next; no healers, nor those falling back', () {
      final g = bare();
      final ks = [for (var i = 0; i < 4; i++) troop(g, 'knight', 200, 20.0 + 16 * i)];
      final far = troop(g, 'knight', 600, 56);
      expect(g.troopFront, 200); // one runner among five is left out
      g.units
        ..remove(ks[0])
        ..remove(ks[1]);
      expect(g.troopFront, 232); // among three, capped at the next + 2 tiles
      final priest = troop(g, 'priest', 900, 56);
      expect(g.troopFront, 232);
      far.retreating = true;
      expect(g.troopFront, 200);
      g.units.removeWhere((u) => u != priest);
      expect(g.troopFront, 900); // nobody else: whoever is on the field
    });

    test('a troop bought mid-wave is left out of the front until it fights or comes up to the others', () {
      final g = bare();
      troop(g, 'knight', 300, 56);
      foe(g, 'slime', 1000, 56);
      g.cam = 150;
      expect(g.place('archer', 1, 4), isTrue);
      final archer = g.troops.last;
      expect((archer.pos.x, archer.joining), (118.0, true));
      archer.entered = true;
      expect(g.troopFront, 300); // it would drag the front back to 150
      archer.attackedAt = g.t;
      g.aim();
      expect((archer.joining, g.troopFront), (false, 150.0));

      final h = bare();
      troop(h, 'knight', 300, 56);
      foe(h, 'slime', 1000, 56);
      expect(h.place('archer', 1, 4), isTrue);
      final late = h.troops.last
        ..entered = true
        ..pos = const Point(267, 60);
      h.aim();
      expect(late.joining, isTrue);
      late.pos = const Point(268, 60); // the others' front - 2 tiles
      h.aim();
      expect(late.joining, isFalse);
    });

    test('mid-wave the view glides at most 6 tiles a second and ignores moves under half a tile', () {
      final g = bare();
      troop(g, 'knight', 1000, 56);
      foe(g, 'orc', 1012, 56);
      g
        ..viewMid = 160
        ..cam = 0;
      g.tick(0.1);
      expect([g.viewMid, g.cam], [closeTo(169.6, 1e-9), closeTo(2.4, 1e-9)]);
      g.tick(0.1);
      expect([g.viewMid, g.cam], [closeTo(179.2, 1e-9), closeTo(6.6, 1e-9)]);
      g.viewMid = 1000;
      g.tick(0.1);
      expect(g.viewMid, 1000);
      g.viewMid = 990;
      g.tick(0.1);
      expect(g.viewMid, closeTo(998, 1e-9));

      final x2 = bare(); // at x2 speed, a tick is 0.2 s
      troop(x2, 'knight', 1000, 56);
      foe(x2, 'orc', 1012, 56);
      x2.viewMid = 160;
      x2.tick(0.2);
      expect(x2.viewMid, closeTo(179.2, 1e-9));
    });

    test('in a lull the view holds on the last fight; after the win it holds through the cheer, then glides back once', () {
      final g = bare();
      troop(g, 'knight', 300, 56);
      final orc = foe(g, 'orc', 312, 56);
      g.tick(0.05);
      expect(g.viewMid, 306); // a new game snaps to its goal
      orc.dying = 0;
      for (var i = 0; i < 10; i++) {
        g.tick(0.05);
        expect((g.meetMode, g.meetX, g.viewMid, g.camTarget), (MeetMode.hold, 306.0, 306.0, 146.0));
      }
      while (g.waveActive) {
        g.tick(0.05);
      }
      expect((g.victoryAt, g.baseX), (g.t, 288.0));
      var last = g.viewMid;
      for (var i = 0; i < 200 && g.viewMid != 448; i++) {
        g.tick(0.05);
        if (g.t - g.victoryAt < victoryTime) {
          expect(g.viewMid, 306); // the cheer, where they fought
        } else {
          expect(g.viewMid, greaterThanOrEqualTo(last));
          expect(g.viewMid - last, lessThanOrEqualTo(focusSpeed * 0.05 + 1e-9));
        }
        last = g.viewMid;
      }
      expect(g.viewMid, 448); // the back line (288) at the left edge
      for (var i = 0; i < 100; i++) {
        g.tick(0.05);
      }
      expect(g.cam, closeTo(288, 1e-3));
      troop(g, 'knight', 700, 56); // setting up: straight to the new rest view, no glide
      g.tick(0.05);
      expect(g.viewMid, 700 + 2 * tile - g.viewW + g.viewW / 2);
    });

    test('at a wave start the view slides with the front, a tile ahead at most, and is at the meeting point when they meet', () {
      final g = bare()
        ..skills = false
        ..heroSkills = false
        ..monsterSkills = false;
      final knight = troop(g, 'knight', 100, 56, held: false);
      foe(g, 'orc', 400, 56, held: false);
      var meet = double.negativeInfinity, mid = double.negativeInfinity, met = false;
      for (var i = 0; i < 30 * 20 && !met; i++) {
        g.tick(1 / 30);
        if (g.meetMode == MeetMode.contact) {
          met = true;
          expect((g.meetX! - 269.857).abs(), lessThanOrEqualTo(tile / 2), reason: 'meetX ${g.meetX}');
          break;
        }
        expect(g.meetMode, MeetMode.approach, reason: 't=${g.t}');
        expect(g.meetX, greaterThanOrEqualTo(meet - 1e-9), reason: 't=${g.t}'); // the meeting point stays put while both walk
        expect(g.viewMid, greaterThanOrEqualTo(mid - 1e-9), reason: 't=${g.t}');
        expect(g.meetX, lessThanOrEqualTo(max(knight.pos.x + tile, 160) + 1e-9), reason: 't=${g.t}');
        expect(knight.pos.x, greaterThanOrEqualTo(g.cam), reason: 't=${g.t}');
        (meet, mid) = (g.meetX!, g.viewMid);
      }
      expect(met, isTrue);
    });

    test('a monster never spawns less than 4 tiles ahead of the foremost troop', () {
      final g = bare();
      troop(g, 'knight', 600, 56);
      g.startWave();
      g.queue
        ..clear()
        ..add(('slime', Tier.normal));
      g
        ..cam = 0
        ..viewMid = 160;
      expect(g.spawnX, 600 + spawnClear);
      g.tick(0.05);
      expect(g.enemies.single.pos.x, closeTo(664, 1)); // it took its first step
    });

    test('a resized view keeps the fight in the middle', () {
      final g = bare();
      troop(g, 'knight', 300, 56);
      foe(g, 'orc', 312, 56);
      for (var i = 0; i < 60; i++) {
        g.tick(0.05);
      }
      g.viewW = 208; // a narrow view
      for (var i = 0; i < 60; i++) {
        g.tick(0.05);
      }
      expect([g.viewMid, g.cam], [306.0, closeTo(202, 1)]);
    });

    test('a loaded game starts at the rest view: the back line at the left edge', () {
      final g = bare()..baseX = 5 * tile;
      troop(g, 'knight', 0, 0).pos = g.troops.last.post;
      troop(g, 'archer', 0, 0).pos = g.troops.last.post;
      final l = Game.fromJson(jsonDecode(jsonEncode(g.toJson())) as Map<String, dynamic>);
      expect(l.viewMid, isNaN);
      l.tick(0.05);
      expect((l.cam, l.viewMid), (5 * tile, 5 * tile + l.viewW / 2));
    });
  });

  test('the view glides toward its target', () {
    final g = bare()..gold = 1000;
    placeNow(g, 'knight', 3, 3);
    g.troops.single
      ..pos = const Point(500, 56)
      ..busyUntil = hold;
    final to = g.camTarget;
    g.tick(0.1);
    expect(g.cam, closeTo(to * 0.25, 1e-9));
    g.tick(1);
    expect(g.cam, closeTo(to, 1e-9));
  });

  test('the right limit and the spawn point move with the view', () {
    final g = bare()..cam = 100;
    expect(g.rightLimit, 100 + g.viewW - 2 * tile);
    g.startWave();
    g.queue
      ..clear()
      ..add(('slime', Tier.normal));
    g.tick(0.05);
    expect(g.enemies.single.pos.x, closeTo(100 + g.viewW + 8 + spawnLead, 1));
  });

  test('a monster is not dragged left by the view gliding back, but a shove still cannot take it past the limit', () {
    final g = bare()..cam = 200;
    final e = Unit(Side.enemy, 'slime', enemyTypes['slime']!, Point(g.rightLimit - 8, 40))
      ..entered = true
      ..busyUntil = hold;
    g.units.add(e);
    final x = e.pos.x;
    g.tick(0.1);
    expect(g.rightLimit, lessThan(x)); // the view went left past it
    expect(e.pos.x, x);
    g.units.add(Unit(Side.enemy, 'slime', enemyTypes['slime']!, e.pos - const Point(1, 0))..busyUntil = hold);
    g.tick(0.05); // the one behind shoves it right
    expect(e.pos.x, x);
  });

  test('a re-forming army walks through itself and settles on its spots', () {
    final g = Game()
      ..gold = 100000
      ..capacity = 4 * rows;
    final types = troopTypes.keys.toList();
    for (var i = 0; i < 28; i++) {
      expect(g.autoPlace(types[i % types.length]), isTrue);
      for (var j = 0; j < 20; j++) {
        g.tick(0.05);
      }
    }
    for (var i = 0; i < 400; i++) {
      g.tick(0.05);
    }
    for (final u in g.troops) {
      expect(u.pos.distanceTo(u.post), lessThan(1), reason: '${u.type} ${u.cell}');
      expect((u.moving, u.arriving), (false, false), reason: '${u.type} ${u.cell}');
    }
    expect(g.troops.map((u) => u.cell).toSet(), hasLength(29));
  });

  test('monsters on screen are never shoved past the right limit', () {
    final g = bare();
    final e = Unit(Side.enemy, 'slime', enemyTypes['slime']!, Point(g.rightLimit - 1, 40));
    g.units.add(e);
    g.tick(0.05);
    expect(e.entered, isTrue);
    g.units.add(Unit(Side.enemy, 'slime', enemyTypes['slime']!, e.pos - const Point(1, 0)));
    g.tick(0.05); // the one behind pushes e ~5px right
    expect(e.pos.x, lessThanOrEqualTo(g.rightLimit));
  });

  test('a monster the view glided back past still walks on: the free priest alone against one bat ends in a march (#42)', () {
    final g = Game(Random(1)); // the free priest alone, which can't hurt a bat and out-heals it
    g.startWave();
    g.queue
      ..clear()
      ..add(('bat', Tier.normal)); // entering on its own; the view then glides left past it
    for (var i = 0; i < 4000 && g.waveActive; i++) {
      g.tick(0.05);
    }
    // The march not won in marchMax s: the wave lost (it leaked over the back line until decisions-log 329).
    expect((g.newMarch, g.waveActive, g.over, g.lives, g.wipeCause), (true, false, false, Game.startLives - wipeLives, WipeCause.slow));
  });

  test('freshly spawned monsters off screen are not clamped until they enter', () {
    final g = bare();
    final x = g.baseX + g.viewW + 8;
    final e = Unit(Side.enemy, 'slime', enemyTypes['slime']!, Point(x, 40));
    g.units.addAll([e, Unit(Side.enemy, 'slime', enemyTypes['slime']!, Point(x - 1, 40))]);
    g.tick(0.05);
    expect(e.entered, isFalse);
    expect(e.pos.x, greaterThan(x)); // pushed further out, left alone
  });

  test('a save round trip through JSON restores the game; troops waiting for a heal are saved healed', () {
    (String, Point<double>, double) sig(Unit u) => (u.type, u.post, u.hp);
    Game roundTrip(Game g) => Game.fromJson(jsonDecode(jsonEncode(g.toJson())) as Map<String, dynamic>);

    final g = wide(Random(1))..gold = 1000;
    placeNow(g, 'knight', 3, 3);
    placeNow(g, 'archer', 1, 4);
    g
      ..gold = 123
      ..lives = 5
      ..wave = 3
      ..baseX = 32;
    g.troops.firstWhere((t) => t.type == 'knight').hp = 50;
    var h = roundTrip(g);
    expect((h.gold, h.lives, h.wave, h.baseX), (123, 5, 3, 32.0));
    expect(h.troops.map(sig).toList(), g.troops.map(sig).toList());

    g
      ..baseX = 0
      ..gold = 1000;
    winWave(g);
    expect(g.healQueue, isNotEmpty); // still cheering: nobody healed yet
    h = roundTrip(g);
    expect(h.wave, 4);
    expect(h.troops.firstWhere((t) => t.type == 'knight').hp, troopTypes['knight']!.hp);
  });

  test('a game starts with 3 hearts of lives; a save from when it started with 10 comes back with at most that', () {
    expect(Game.startLives, 6);
    Game load(int lives) => Game.fromJson(jsonDecode(jsonEncode((Game()..lives = lives).toJson())) as Map<String, dynamic>);
    expect([for (final lives in [10, 7, 6, 5, 1]) load(lives).lives], [6, 6, 6, 5, 1]);
  });

  test('buying capacity adds troop slots for capacityPrice gold, capacityPriceRise more each time; the zone widens to hold them', () {
    final g = Game()..gold = 10000;
    expect((g.capacity, g.zoneCols, g.maxCapacity), (capacityStart, deployCols, 6 * rows)); // floor(320 * 0.3 / 16) columns
    expect(g.canPlace(deployCols, 0), isFalse);
    g.sfx.clear();
    expect(g.buyCapacity(), isTrue);
    expect((g.capacity, g.gold), (capacityStart + capacityStep, 10000 - capacityPrice));
    expect(g.capacityCost, capacityPrice + capacityPriceRise);
    expect(g.sfx, [Sfx.place]);
    expect(g.zoneCols, deployCols + 1); // every purchase widens the zone a column
    expect(g.canPlace(deployCols, 0), isTrue);
    while (g.buyCapacity()) {}
    expect((g.capacity, g.zoneCols), (6 * rows, 6)); // capped by the widest zone
    expect(g.sfx.last, Sfx.error);
    g.viewW = 640; // a wider screen allows more
    expect(g.maxZoneCols, 12);
    expect(g.buyCapacity(), isTrue);
  });

  test('buying capacity fails and changes nothing when too poor or the game is over', () {
    for (final setUp in <void Function(Game)>[(g) => g.gold = capacityPrice - 1, (g) => g..gold = 1000..lives = 0]) {
      final g = Game();
      setUp(g);
      final gold = g.gold;
      g.sfx.clear();
      expect(g.buyCapacity(), isFalse);
      expect((g.capacity, g.gold), (capacityStart, gold));
      expect(g.sfx, [Sfx.error]);
    }
  });

  test('the save keeps the capacity; old saves count each bought zone column as one purchase', () {
    final g = Game()..capacity = 10;
    final j = jsonDecode(jsonEncode(g.toJson())) as Map<String, dynamic>;
    expect(Game.fromJson(j).capacity, 10);
    j.remove('capacity');
    expect(Game.fromJson(j..['zoneCols'] = 5).capacity, capacityStart + 2 * capacityStep);
    expect(Game.fromJson(j..remove('zoneCols')).capacity, capacityStart + 3 * capacityStep); // older still: 6 columns
  });

  test('troops are set up in the left zone, one per cell', () {
    final g = Game();
    expect(g.canPlace(0, 0), isTrue);
    expect(g.canPlace(deployCols - 1, rows - 1), isTrue);
    expect(g.canPlace(deployCols, 5), isFalse); // outside the zone
    expect(placeNow(g, 'knight', 2, 3), isTrue);
    expect(g.gold, Game.startGold - 50);
    expect(placeNow(g, 'knight', 2, 3), isFalse); // taken
    expect(g.sfx, [Sfx.place, Sfx.error]);
  });

  test('a wave can start only between waves: never while one is on, or after game over', () {
    final g = wide();
    expect(g.canStartWave, isTrue);
    g.startWave();
    expect((g.wave, g.waveActive, g.canStartWave), (1, true, false));
    g.startWave(); // mid-wave it does nothing
    expect(g.wave, 1);

    final won = wide();
    winWave(won);
    expect((won.wave, won.waveActive, won.canStartWave), (1, false, true)); // the troops cheering or not
    won.lives = 0;
    expect((won.over, won.canStartWave), (true, false));
    won.startWave();
    expect(won.wave, 1);
  });

  test('monsters come from the right; a wave begun with no troop is lost when one reaches the back line (decisions-log '
      '329)', () {
    final g = bare(Random(1))..startWave();
    var spawnedRight = false;
    run(g, each: (g) => spawnedRight |= g.enemies.any((e) => e.pos.x > g.baseX + g.viewW));
    expect(spawnedRight, isTrue);
    expect((g.lives, g.wipedOut, g.wipeCause, g.wave, g.lostWave), (Game.startLives - wipeLives, true, WipeCause.empty, 0, 1));
    expect(g.sfx, contains(Sfx.lose));
    expect(g.sfx, isNot(contains(Sfx.leak)));
  });

  test('the necromancer fights in melee and raises skeletons', () {
    expect(bossStats.shotSpeed, 0);
    final g = bare(Random(1))..startWave();
    g.queue
      ..clear()
      ..add((boss, Tier.boss));
    for (var i = 0; i < 44; i++) {
      g.tick(0.05); // spawn, then walk until the first summon (~2s)
    }
    final necro = g.enemies.singleWhere((u) => u.type == boss);
    final skeletons = g.enemies.where((u) => u.type == minion).toList();
    expect(skeletons, hasLength(minions));
    expect(g.t, lessThan(necro.busyUntil)); // still casting
    final at = necro.pos;
    g.tick(0.5);
    expect(necro.pos, at); // stands still while casting
    expect(g.shots, isEmpty);
  });

  test('priests heal the most hurt ally in reach', () {
    final g = bare()
      ..gold = 500
      ..skills = false; // the plain heal, not Healing Prayer
    placeNow(g, 'priest', 1, 1);
    placeNow(g, 'knight', 1, 2);
    placeNow(g, 'soldier', 1, 3);
    final knight = g.troops.firstWhere((t) => t.type == 'knight'), soldier = g.troops.firstWhere((t) => t.type == 'soldier');
    knight.hp = 100;
    soldier.hp = 20;
    g.startWave(); // priests patch people up mid-battle (between waves it's the after-wave round)
    g.queue
      ..clear()
      ..add(('slime', Tier.normal));
    g.tick(0.05);
    expect(soldier.hp, 20 + troopTypes['priest']!.dmg);
    expect(knight.hp, 100);
    expect(g.impacts.single.$2, 'heal');
  });

  test('after a win the troops cheer in place, then retake the drop spots past the moved-up back line', () {
    final g = wide(Random(1));
    for (var r = 1; r <= 6; r++) {
      g.gold += 50;
      placeNow(g, 'knight', r.isEven ? 4 : 2, r);
    }
    final drops = {for (final t in g.troops) t: t.cell};
    g.startWave();
    var charged = false;
    run(g, each: (g) => charged |= g.troops.any((t) => t.pos.x > (drops[t]!.$1 + 3) * tile));
    expect(charged, isTrue);
    expect(g.lives, Game.startLives);
    expect(g.sfx, contains(Sfx.clear));
    expect(g.victoryAt, g.t);
    expect(g.lastBonus, Game.waveBonus(1));
    expect(g.baseX, greaterThan(0)); // the back line moved up at once

    final at = {for (final t in g.troops) t: t.pos};
    g.tick(victoryTime / 2);
    for (final t in g.troops) {
      expect(t.moving, isFalse); // cheering, not walking back
      expect(t.pos.distanceTo(at[t]!), lessThan(tile / 2));
    }

    for (var i = 0; i < 200; i++) {
      g.tick(0.05); // time to walk back
    }
    for (final t in g.troops) {
      expect(t.hp, t.maxHp); // healed
      expect(t.pos.distanceTo(t.post), lessThan(1)); // standing in a spot
    }
    // The drop spots, relative to the back line; two knights whose ways back crossed traded theirs (#82).
    expect({for (final t in g.troops) t.cell}, {for (final (c, r) in drops.values) (c + g.baseCol, r)});
    expect(g.baseX, greaterThan(0));
    expect(g.canPlace(g.baseCol, 0), isTrue);
    expect(g.canPlace(g.baseCol - 1, 0), isFalse);

    g.startWave();
    g.tick(0.05);
    expect(g.enemies.first.pos.x, greaterThan(g.baseX + g.viewW)); // next wave comes from the new right edge
  });

  test('a bought troop marches in from off screen left along its row to its spot, never held at the back line on the way', () {
    final g = wide()
      ..units.clear()
      ..baseX = 2 * tile;
    expect(g.place('knight', g.baseCol + 1, 3), isTrue);
    final u = g.troops.single, row = u.post.y;
    expect((u.pos, u.entered), (Point(g.baseX - 2 * tile, row), false));
    g.tick(0.05);
    expect(u.moving, isTrue);
    expect(u.pos.x, lessThan(g.baseX)); // not snapped up to baseX + 4
    expect(u.pos.x, greaterThan(g.baseX - 2 * tile));
    for (var i = 0; i < 200; i++) {
      g.tick(0.05);
      expect(u.pos.y, row);
    }
    expect(u.entered, isTrue);
    expect(u.pos.distanceTo(u.post), lessThan(1));
  });

  test('a marching troop does not fight a foe in range until it has entered', () {
    final g = bare();
    g.place('archer', 1, 3);
    final u = g.troops.single;
    final bear = Unit(Side.enemy, 'werebear', enemyTypes['werebear']!, u.pos + const Point(60, 0))..busyUntil = hold;
    g.units.add(bear);
    expect(bear.pos.distanceTo(u.pos), lessThanOrEqualTo(u.stats.range)); // in reach from the start
    var ticks = 0;
    while (!u.entered) {
      g.tick(0.05);
      expect(ticks++, lessThan(200));
      if (u.entered) break;
      expect((u.moving, g.shots.length, bear.hp), (true, 0, bear.maxHp.toDouble()), reason: 't=${g.t}');
    }
    for (var i = 0; i < 20; i++) {
      g.tick(0.05);
    }
    expect(bear.hp, lessThan(bear.maxHp)); // fights once in
  });

  test('troops not bought stand on their spots from the start: the free healer and a loaded save', () {
    final free = Game().troops.single;
    expect((free.pos, free.entered), (free.post, true));
    final g = bare()..gold = 1000;
    g.place('knight', 2, 3);
    final h = Game.fromJson(jsonDecode(jsonEncode(g.toJson())) as Map<String, dynamic>);
    final k = h.troops.single;
    expect((k.pos, k.post, k.entered), (g.troops.single.post, g.troops.single.post, true));
  });

  test('buying capacity leaves the army where it stands, even when the zone widens', () {
    final g = Game()..gold = 1000; // a purchase widens the zone
    g.autoPlace('knight');
    g.autoPlace('archer');
    final [priest, knight, archer] = g.troops.toList();
    expect([for (final u in [knight, archer, priest]) u.cell], [(2, 3), (1, 3), (0, 3)]);
    final posts = [for (final u in g.troops) u.post];
    expect(g.buyCapacity(), isTrue);
    expect(g.zoneCols, deployCols + 1);
    expect([for (final u in g.troops) u.post], posts);
  });

  test('drops roll their own dice and never change the spawn sequence', () {
    List<(String, double)> spawns(double roll) {
      final g = wide(Random(7))..gold = 1000;
      g.loot = _Dice(roll, 0);
      for (var r = 0; r < rows; r++) {
        placeNow(g, 'knight', 2, r);
      }
      final seen = <Unit>{}, out = <(String, double)>[];
      g.startWave();
      run(g, each: (g) {
        for (final e in g.enemies.where(seen.add)) {
          out.add((e.type, e.pos.y));
        }
      });
      expect([g.inventory, g.relicBag], everyElement(isEmpty)); // no item or relic drops: the Smithy makes them (decisions-log 321)
      return out;
    }

    expect(spawns(0), spawns(1)); // the loot dice still draw for every kill, whatever they roll
  });

  test('winning a wave leaves the items and relics in the bag as they were: none drops (decisions-log 321)', () {
    final g = bare();
    placeNow(g, 'knight', 2, 3);
    g.inventory[Item.sword] = 1;
    g.relicBag[Relic.fang] = 1;
    winWave(g);
    winWave(g);
    expect([g.inventory, g.relicBag], [{Item.sword: 1}, {Relic.fang: 1}]);
  });

  test('an upgrade goes to every living troop of its type and leaves the inventory', () {
    final k = troopTypes['soldier']!; // the soldier's recipe takes every kind
    final checks = <Item, void Function(Stats)>{
      Item.sword: (s) => expect(s.dmg, k.dmg * 1.25),
      Item.shield: (s) => expect((s.def, s.hp), (shieldDef, k.hp)), // defence, not HP
      Item.boots: (s) => expect(s.speed, k.speed * 1.25),
      Item.bow: (s) => expect(s.range, k.range * 1.2),
      Item.gloves: (s) => expect(s.rate, k.rate * 0.8),
    };
    for (final MapEntry(key: item, value: check) in checks.entries) {
      final g = bare()..gold = 1000;
      placeNow(g, 'soldier', 2, 3);
      placeNow(g, 'soldier', 2, 4);
      placeNow(g, 'knight', 2, 5);
      final soldiers = g.troops.where((t) => t.type == 'soldier').toList(), knight = g.troops.last;
      for (final u in soldiers) {
        u.hp = 60;
      }
      g.inventory[item] = 2;
      g.sfx.clear();
      expect(g.useItem(item, 'soldier'), isTrue);
      check(g.statsOf('soldier'));
      for (final u in soldiers) {
        check(u.stats);
        expect(u.maxHp, u.stats.hp);
        expect(u.hp, 60.0);
      }
      expect(knight.stats, troopTypes['knight']);
      expect(g.upgrades, {'soldier': [item]});
      expect(g.inventory[item], 1);
      expect(g.sfx, [Sfx.magic]);
      expect(g.impacts, [for (final u in soldiers) (u.pos, 'upgrade')]);
    }
  });

  test('upgrades stack up to the cap, work mid-wave or with none on the field, and go to troops placed later', () {
    final k = troopTypes['knight']!;
    final g = bare()..gold = 1000;
    g.inventory[Item.sword] = 5;
    expect(g.useItem(Item.sword, 'knight'), isTrue); // no knight yet
    placeNow(g, 'knight', 2, 3);
    g.units.add(Unit(Side.enemy, 'slime', enemyTypes['slime']!, const Point(300, 60))..busyUntil = hold);
    expect(g.waveActive, isTrue);
    for (var i = 0; i < 2; i++) {
      expect(g.useItem(Item.sword, 'knight'), isTrue);
    }
    // The knight's recipe asks for 3 swords: a 4th waits in the bag until it has awakened.
    g.sfx.clear();
    expect(g.useItem(Item.sword, 'knight'), isFalse);
    expect(g.sfx, [Sfx.error]);
    expect(g.inventory[Item.sword], 2);
    expect(g.upgrades['knight'], [Item.sword, Item.sword, Item.sword]);
    var dmg = k.dmg;
    for (var i = 0; i < 3; i++) {
      dmg *= 1.25;
    }
    expect(g.statsOf('knight').dmg, dmg);
    expect(g.statsOf('soldier'), troopTypes['soldier']);
    placeNow(g, 'knight', 1, 1);
    g.autoPlace('knight');
    expect(g.troops.map((t) => t.stats.dmg), [dmg, dmg, dmg]);
  });

  test('a potion is an upgrade too: its type regains HP every second, stacking, up to full', () {
    final g = bare()..gold = 1000;
    placeNow(g, 'knight_templar', 2, 3); // potions are in the templar's and the priest's recipes
    placeNow(g, 'soldier', 2, 4);
    final [knight, soldier] = g.troops.toList();
    g.inventory[Item.potion] = 3;
    expect(g.useItem(Item.potion, 'knight_templar'), isTrue);
    expect(g.useItem(Item.potion, 'knight_templar'), isTrue);
    expect(g.useItem(Item.potion, 'priest'), isTrue); // none on the field
    expect((g.statsOf('knight_templar').regen, knight.stats.regen, soldier.stats.regen), (2 * potionRegen, 2 * potionRegen, 0.0));
    expect(g.statsOf('priest').regen, potionRegen);
    expect(g.upgrades, {'knight_templar': [Item.potion, Item.potion], 'priest': [Item.potion]});
    expect(g.impacts, [(knight.pos, 'heal'), (knight.pos, 'heal')]);
    expect(knight.maxHp, (troopTypes['knight_templar']!.hp * (1 + heavyBuff)).round()); // a heavy's (#57), no potion in it

    knight.hp = 50;
    soldier.hp = 50;
    for (var i = 0; i < 20; i++) {
      g.tick(0.05);
    }
    expect(knight.hp, closeTo(50 + 2 * potionRegen, 1e-6));
    expect(soldier.hp, 50);
    knight.hp = knight.maxHp - 1.0;
    g.tick(1);
    expect(knight.hp, knight.maxHp);

    placeNow(g, 'priest', 1, 3);
    expect(g.troops.last.stats.regen, potionRegen);
    final h = Game.fromJson(jsonDecode(jsonEncode(g.toJson())) as Map<String, dynamic>);
    expect(h.troops.firstWhere((t) => t.type == 'knight_templar').stats.regen, 2 * potionRegen);
    expect(h.statsOf('priest').regen, potionRegen);
  });

  test('using an item fails and changes nothing without one in stock, on an unknown type or after game over', () {
    for (final (why, item, type, setUp) in <(String, Item, String, void Function(Game))>[
      ('none in stock', Item.sword, 'knight', (g) => g.inventory[Item.sword] = 0),
      ('none in stock', Item.potion, 'knight', (g) => g.inventory[Item.potion] = 0),
      ('unknown type', Item.sword, 'slime', (g) {}),
      ('unknown type', Item.sword, 'dragon', (g) {}),
      ('game over', Item.sword, 'knight', (g) => g.lives = 0),
      ('game over', Item.potion, 'knight', (g) => g.lives = 0),
    ]) {
      final g = bare();
      placeNow(g, 'knight', 2, 3);
      final u = g.troops.single..hp = 50;
      g.inventory.addAll({Item.sword: 1, Item.potion: 1});
      setUp(g);
      final stock = {...g.inventory};
      g.sfx.clear();
      expect(g.useItem(item, type), isFalse, reason: why);
      expect((u.stats, u.hp), (troopTypes['knight'], 50.0), reason: why);
      expect(g.upgrades, isEmpty, reason: why);
      expect(g.inventory, stock, reason: why);
      expect(g.sfx, [Sfx.error]);
    }
  });

  test('the save keeps the inventory and each type\'s upgrades; troops load and are placed upgraded', () {
    final g = bare()..gold = 1000;
    placeNow(g, 'knight', 2, 3);
    placeNow(g, 'archer', 1, 4);
    final knight = g.troops.firstWhere((t) => t.type == 'knight');
    g.inventory.addAll({Item.sword: 1, Item.shield: 1, Item.bow: 2, Item.potion: 1});
    g.useItem(Item.sword, 'knight');
    g.useItem(Item.shield, 'knight');
    g.useItem(Item.bow, 'wizard'); // none on the field
    knight.hp = 60;
    final h = Game.fromJson(jsonDecode(jsonEncode(g.toJson())) as Map<String, dynamic>)..gold = 1000;
    expect(h.inventory, {Item.sword: 0, Item.shield: 0, Item.bow: 1, Item.potion: 1});
    expect(h.upgrades, {'knight': [Item.sword, Item.shield], 'wizard': [Item.bow]});
    final k = h.troops.firstWhere((t) => t.type == 'knight'), a = h.troops.firstWhere((t) => t.type == 'archer');
    expect((k.stats.dmg, k.stats.hp, k.maxHp, k.hp), (knight.stats.dmg, knight.stats.hp, knight.maxHp, 60.0));
    expect((a.stats, a.maxHp), (troopTypes['archer'], troopTypes['archer']!.hp));
    placeNow(h, 'wizard', 0, 0);
    expect(h.troops.last.stats.range, troopTypes['wizard']!.range * 1.2);
  });

  test('a troop costs its base price until its type takes an item', () {
    final g = Game();
    for (final MapEntry(key: type, value: s) in troopTypes.entries) {
      expect(g.priceOf(type), s.cost, reason: type);
    }
  });

  test('every item a type takes raises its price by a tenth of its base, each kind counting', () {
    final g = bare();
    g.inventory.addAll({for (final i in Item.values) i: 1});
    expect(g.useItem(Item.sword, 'soldier'), isTrue);
    expect(g.priceOf('soldier'), 33);
    expect(g.useItem(Item.shield, 'soldier'), isTrue);
    expect(g.priceOf('soldier'), 36);
    for (final (n, item) in [Item.boots, Item.bow, Item.gloves, Item.potion].indexed) {
      expect(g.useItem(item, 'soldier'), isTrue);
      expect(g.priceOf('soldier'), 39 + 3 * n, reason: item.name);
    }
    expect(g.useItem(Item.sword, 'soldier'), isFalse); // none left: no upgrade, no rise
    expect(g.priceOf('soldier'), 48);
    expect(g.priceOf('knight'), 50);
  });

  test('every type\'s price rises by a tenth of its own base per item', () {
    const rise = {
      'soldier': 3,
      'knight': 5,
      'swordsman': 6,
      'archer': 7,
      'lancer': 8,
      'priest': 9,
      'armored_axeman': 11,
      'wizard': 12,
      'knight_templar': 15,
    };
    expect(rise.keys, unorderedEquals(troopTypes.keys));
    for (final MapEntry(key: type, value: step) in rise.entries) {
      for (var n = 0; n <= 3; n++) {
        final g = bare();
        g.upgrades[type] = List.filled(n, Item.boots);
        expect(g.priceOf(type), troopTypes[type]!.cost + n * step, reason: '$type with $n');
      }
    }
    expect((bare()..upgrades['knight_templar'] = [Item.sword, Item.bow]).priceOf('knight_templar'), 180);
    expect((bare()..upgrades['priest'] = [Item.potion]).priceOf('priest'), 99);
  });

  test('a relic held by a troop does not change its type\'s price', () {
    final g = bare()..gold = 1000;
    placeNow(g, 'soldier', 2, 3);
    g.relicBag[Relic.fang] = 1;
    expect(g.useRelic(Relic.fang, g.troops.single), isTrue);
    expect(g.priceOf('soldier'), 30);
    expect(g.place('soldier', 2, 4), isTrue);
    expect(g.gold, 1000 - 30 - 30);
  });

  test('buying a troop charges its current, risen price', () {
    final g = bare()..gold = 1000;
    g.upgrades['soldier'] = [Item.sword, Item.shield];
    expect(g.autoPlace('soldier'), isTrue);
    expect(g.gold, 1000 - 36);
    expect(g.place('soldier', 0, 0), isTrue);
    expect(g.gold, 1000 - 2 * 36);
    expect(g.place('knight', 0, 1), isTrue); // its own type took nothing
    expect(g.gold, 1000 - 2 * 36 - 50);
  });

  test('a troop cannot be bought for less than its risen price', () {
    for (final (how, buy) in <(String, bool Function(Game))>[
      ('tap', (g) => g.autoPlace('soldier')),
      ('drop', (g) => g.place('soldier', 2, 3)),
    ]) {
      final g = bare()..gold = 32;
      g.upgrades['soldier'] = [Item.sword];
      g.sfx.clear();
      expect(buy(g), isFalse, reason: how);
      expect((g.gold, g.troops.length), (32, 0), reason: how);
      expect(g.sfx, [Sfx.error], reason: how);

      g.gold = 33;
      expect(buy(g), isTrue, reason: how);
      expect((g.gold, g.troops.length), (0, 1), reason: how);
    }
  });

  test('the price is not saved but comes back from the saved upgrades; old saves load at base prices', () {
    final g = bare();
    g.upgrades['knight'] = [Item.sword, Item.shield];
    final text = jsonEncode(g.toJson());
    expect(text, isNot(contains('price')));
    final j = jsonDecode(text) as Map<String, dynamic>;
    expect((g.priceOf('knight'), Game.fromJson(j).priceOf('knight')), (60, 60));
    final old = Game.fromJson(j..remove('upgrades'));
    for (final MapEntry(key: type, value: s) in troopTypes.entries) {
      expect(old.priceOf(type), s.cost, reason: type);
    }
  });

  test('tapping a troop lines the army up Healer | long range | melee, each role from a column of its own', () {
    final g = Game()..gold = 1000; // the starting 3-column zone, with the free healer
    expect(g.autoPlace('archer'), isTrue);
    final archer = g.troops.last;
    expect(archer.pos, Point(g.baseX - 2 * tile, archer.post.y)); // marches in along its new row
    expect(g.autoPlace('knight'), isTrue);
    expect(g.troops.map((t) => (t.type, t.cell)), [('priest', (0, 3)), ('archer', (1, 3)), ('knight', (2, 3))]);

    final wide6 = bare()..gold = 1000;
    wide6
      ..baseX = 2 * tile
      ..autoPlace('priest')
      ..autoPlace('wizard')
      ..autoPlace('soldier');
    expect(wide6.troops.map((t) => t.cell), [(5, 3), (6, 3), (7, 3)]); // packed to the front, past a moved-up back line
  });

  test('melee lines up in two ranks: the vanguard in front of the heavy melee', () {
    expect([for (final t in ['priest', 'archer', 'lancer', 'knight']) Unit(Side.troop, t, troopTypes[t]!, const Point(0, 0)).rank], [0, 1, 2, 3]);
    final g = Game()
      ..gold = 1000
      ..capacity = capacityStart + capacityStep; // one purchase: a 4-column zone
    for (final t in ['lancer', 'archer', 'knight']) {
      g.autoPlace(t);
    }
    expect(g.troops.map((t) => (t.type, t.cell)), [('priest', (0, 3)), ('lancer', (2, 3)), ('archer', (1, 3)), ('knight', (3, 3))]);

    final narrow = Game()..gold = 1000; // 3 columns for 4 ranks: the healer shares the back one
    for (final t in ['lancer', 'archer', 'knight']) {
      narrow.autoPlace(t);
    }
    expect(narrow.troops.map((t) => (t.type, t.cell)), [('priest', (0, 4)), ('lancer', (1, 3)), ('archer', (0, 3)), ('knight', (2, 3))]);
  });

  test('tapping fills the front column middle rows out, upper first on a tie, then the next column back', () {
    final g = Game()
      ..gold = 1000
      ..viewW = 160 // a narrow view: the zone can't grow past deployCols
      ..capacity = deployCols * rows;
    for (var i = 0; i < rows + 1; i++) {
      g.autoPlace('soldier');
    }
    final soldiers = g.troops.where((t) => t.type == 'soldier').map((t) => t.cell).toList();
    expect(soldiers, [for (final r in [3, 4, 2, 5, 1, 6, 0, 7]) (2, r), (1, 3)]); // in the order they came
    expect(g.troops.first.cell, (0, 3)); // the healer starts a column of its own
  });

  test('tapping a troop into a full zone fails before a wave, shares a cell mid-wave, and needs the gold', () {
    final g = Game()
      ..gold = 100000
      ..viewW = 160 // a narrow view: the zone can't grow past deployCols
      ..capacity = deployCols * rows + 1; // room for one more troop than the zone has cells
    for (var i = 0; i < 3 * rows - 1; i++) {
      expect(g.autoPlace('soldier'), isTrue); // the healer takes the last cell: no column left of its own
    }
    final gold = g.gold, count = g.troops.length;
    g.sfx.clear();
    expect(g.autoPlace('knight'), isFalse);
    expect((g.gold, g.troops.length), (gold, count));
    expect(g.sfx, [Sfx.error]);

    g.units.add(Unit(Side.enemy, 'slime', enemyTypes['slime']!, const Point(300, 60))..busyUntil = hold);
    expect(g.autoPlace('soldier'), isTrue);
    expect(g.gold, gold - troopTypes['soldier']!.cost);
    expect(g.troops.last.cell, (0, 7));
    expect(g.troops.first.cell, (0, 7)); // out of cells: the healer, last in line, shares the back-most one

    final poor = bare()..gold = troopTypes['knight']!.cost - 1;
    expect(poor.autoPlace('knight'), isFalse);
    expect(poor.troops, isEmpty);
    expect(poor.sfx, [Sfx.error]);
  });

  test('a melee hit shows its impact on the foe; a shot shows it where it lands, not when fired', () {
    final g = bare();
    placeNow(g, 'knight', 2, 3);
    final bear = Unit(Side.enemy, 'werebear', enemyTypes['werebear']!, g.troops.single.pos + const Point(10, 0))..busyUntil = hold;
    final at = bear.pos;
    g.units.add(bear);
    g.tick(0.05);
    expect(g.impacts, [(at, 'hit_knight')]); // where it stood when struck, before the shove apart

    final s = bare()
      ..gold = 1000
      ..skills = false; // its plain shot, no Arrow Rain on a lone foe (decisions-log 298)
    placeNow(s, 'archer', 1, 3);
    final archer = s.troops.single;
    final target = Unit(Side.enemy, 'werebear', enemyTypes['werebear']!, archer.pos + const Point(55, 0))..busyUntil = hold;
    s.units.add(target);
    s.tick(0.05);
    expect(s.shots, hasLength(1));
    expect(s.impacts, isEmpty);
    while (s.shots.isNotEmpty) {
      s.tick(0.05);
    }
    expect(s.impacts, [(target.pos, 'hit_archer')]);
  });

  test('a troop holds one relic: a second one is refused and stays in the bag', () {
    final g = bare();
    placeNow(g, 'knight', 2, 3);
    final u = g.troops.single;
    g.relicBag.addAll({Relic.fang: 1, Relic.guard: 1});
    g.sfx.clear();
    expect(g.useRelic(Relic.fang, u), isTrue);
    expect((u.relics.firstOrNull, g.relicBag[Relic.fang]), (Relic.fang, 0));
    expect(g.useRelic(Relic.guard, u), isFalse);
    expect(u.relics.firstOrNull, Relic.fang);
    expect(g.relicBag, {Relic.fang: 0, Relic.guard: 1});
    expect(g.impacts, [(u.pos, 'upgrade')]);
    expect(g.sfx, [Sfx.magic, Sfx.error]);
  });

  test('handing a relic fails and changes nothing with none in the bag, on a dead or enemy unit, or after game over', () {
    for (final (why, setUp) in <(String, Unit Function(Game, Unit))>[
      ('none in the bag', (g, u) {
        g.relicBag[Relic.fury] = 0;
        return u;
      }),
      ('dead', (g, u) => u..dying = 0),
      ('enemy', (g, u) => Unit(Side.enemy, 'orc', enemyTypes['orc']!, u.pos)),
      ('game over', (g, u) {
        g.lives = 0;
        return u;
      }),
    ]) {
      final g = bare();
      placeNow(g, 'knight', 2, 3);
      g.relicBag.addAll({Relic.fury: 1, Relic.guard: 0});
      final u = setUp(g, g.troops.single); // holding none: a held relic refuses by itself
      final had = u.relics.firstOrNull, bag = {...g.relicBag};
      g.sfx.clear();
      expect(g.useRelic(Relic.fury, u), isFalse, reason: why);
      expect(u.relics.firstOrNull, had, reason: why);
      expect(g.relicBag, bag, reason: why);
      expect(g.sfx, [Sfx.error]);
    }
  });

  test('a fallen troop\'s relic goes back into the bag', () {
    final (g, s) = doomedSoldier();
    s.relics.add(Relic.thorns);
    g.tick(0.05);
    expect(s.alive, isFalse);
    expect(s.relics.firstOrNull, isNull);
    expect(g.relicBag, {Relic.thorns: 1});
  });

  test('the save keeps the relic bag and the relic each troop holds', () {
    final g = bare()..gold = 1000;
    placeNow(g, 'knight', 2, 3);
    placeNow(g, 'archer', 1, 4);
    g.troops.first.relics.add(Relic.fury);
    g.relicBag.addAll({Relic.guard: 2, Relic.fang: 0});
    final h = Game.fromJson(jsonDecode(jsonEncode(g.toJson())) as Map<String, dynamic>);
    expect(h.relicBag, {Relic.guard: 2, Relic.fang: 0});
    expect(h.troops.map((t) => (t.type, t.relics.firstOrNull)), [('knight', Relic.fury), ('archer', null)]);
  });

  /// A held troop of [type] with [relic] and a werebear next to it, held too unless [bearFights].
  (Game, Unit, Unit) relicDuel(String type, Relic? relic, {bool bearFights = false}) {
    final g = bare()
      ..gold = 1000
      ..skills = false; // plain blows: a lone foe is a #10 skill's target too (decisions-log 298)
    placeNow(g, type, 2, 3);
    final u = g.troops.single
      ..relics.addAll([?relic])
      ..busyUntil = bearFights ? hold : double.negativeInfinity;
    final bear = Unit(Side.enemy, 'werebear', enemyTypes['werebear']!, u.pos + const Point(10, 0))..busyUntil = bearFights ? double.negativeInfinity : hold;
    g.units.add(bear);
    return (g, u, bear);
  }

  test('guard cuts the damage its holder takes', () {
    final dmg = enemyTypes['werebear']!.dmg;
    final (g, u, _) = relicDuel('soldier', Relic.guard, bearFights: true);
    g.tick(0.05);
    expect(u.hp, u.maxHp - dmg * (1 - guardCut));
  });

  test('thorns hit the attacker back, and never bounce between two thorns holders', () {
    final dmg = enemyTypes['werebear']!.dmg;
    final (g, u, bear) = relicDuel('soldier', Relic.thorns, bearFights: true);
    g.tick(0.05);
    expect(u.hp, u.maxHp - dmg);
    expect(bear.hp, bear.maxHp - dmg * thornsShare);

    final (h, k, b) = relicDuel('knight', Relic.thorns);
    b.relics.add(Relic.thorns);
    h.tick(0.05);
    expect(b.hp, b.maxHp - troopTypes['knight']!.dmg);
    expect(k.hp, k.maxHp - troopTypes['knight']!.dmg * thornsShare); // and no thorns back from the knight
  });

  test('fang heals its holder by a share of the damage dealt, never more than the foe had', () {
    final dmg = troopTypes['knight']!.dmg;
    final (g, u, bear) = relicDuel('knight', Relic.fang);
    u.hp = 50;
    g.tick(0.05);
    expect(u.hp, 50 + dmg * fangShare);

    final (h, k, b) = relicDuel('knight', Relic.fang);
    k.hp = 50;
    b.hp = 5;
    h.tick(0.05);
    expect(b.alive, isFalse);
    expect(k.hp, 50 + 5 * fangShare);

    final (f, full, _) = relicDuel('knight', Relic.fang);
    f.tick(0.05);
    expect(full.hp, full.maxHp); // capped
  });

  test('fury doubles every third blow, melee or shot', () {
    final dmg = troopTypes['knight']!.dmg;
    final (g, _, bear) = relicDuel('knight', Relic.fury);
    final hits = <double>[];
    var hp = bear.hp;
    while (hits.length < 6) {
      g.tick(0.05);
      if (bear.hp != hp) hits.add(hp - bear.hp);
      hp = bear.hp;
    }
    expect(hits, [dmg, dmg, 2 * dmg, dmg, dmg, 2 * dmg]);

    final (s, archer, _) = relicDuel('archer', Relic.fury);
    archer.pos -= const Point(40, 0); // out of kiting range
    final fired = <Shot>{};
    while (fired.length < 3) {
      s.tick(0.05);
      fired.addAll(s.shots);
    }
    final a = troopTypes['archer']!.dmg;
    expect(fired.map((x) => x.dmg), [a, a, 2 * a]);

    final (n, _, _) = relicDuel('knight', null);
    final plain = <double>[];
    for (var i = 0; i < 200 && plain.length < 3; i++) {
      final before = n.enemies.single.hp;
      n.tick(0.05);
      if (n.enemies.single.hp != before) plain.add(before - n.enemies.single.hp);
    }
    expect(plain, [dmg, dmg, dmg]); // without fury, no doubling
  });

  test('a monster\'s stats grow with its tier and the wave; speed and attack rate up to a cap, melee reach never', () {
    final orc = enemyTypes['orc']!;
    final plain = enemyStats('orc', Tier.normal, 1);
    expect((plain.hp, plain.dmg, plain.speed, plain.rate, plain.range, plain.cost), (orc.hp, orc.dmg, orc.speed, orc.rate, orc.range, orc.cost));
    final elite = enemyStats('orc', Tier.elite, 5);
    expect((elite.hp, elite.cost), (242, 10)); // 80*1.8*1.68; 6*1.5*1.045^4 = 10.7, floored
    expect(elite.dmg, closeTo(16.12, 1e-9)); // 10*1.3*1.24
    expect(elite.speed, closeTo(20.412, 1e-9)); // 18*1.05*1.08
    expect(elite.rate, closeTo(1 / 1.04, 1e-9)); // 4% more attacks a second
    for (final tier in Tier.values.where((t) => t != Tier.boss)) {
      // (The werebear, the strongest type, starts from its own stats in the mini boss slot too; a boss of it
      // from the necromancer's: its own test.)
      for (final wave in [0, 1, 2, 7, 20, 26, 40]) {
        final s = enemyStats('werebear', tier, wave), b = enemyTypes['werebear']!, w = max(0, wave - 1);
        final (bHp, _, bDmg) = bossBuff(tier, wave);
        // From wave 35 the crowd has the tide on top, the mini boss slot not (#92, tide_test.dart).
        final (tHp, tDmg) = tided(tier) ? (tide(wave, tideHp), tide(wave, tideDmg)) : (1.0, 1.0);
        expect(s.hp, (b.hp * tier.hp * bHp * waveGrowth(wave, waveHp, waveHpLate) * tHp).round(), reason: '$tier $wave');
        expect(s.dmg, closeTo(b.dmg * tier.dmg * bDmg * waveGrowth(wave, waveDmg, waveDmgLate) * tDmg, 1e-9), reason: '$tier $wave');
        final late = max(0, wave - waveTempoTo); // waves past the early caps
        expect(s.speed, closeTo(b.speed * tier.speed * (1 + min(waveSpeedMost, min(waveSpeed * w, waveSpeedMax) + waveSpeedLate * late)), 1e-9),
            reason: '$tier $wave');
        expect(s.rate, closeTo(b.rate / (1 + min(waveRate * w, waveRateMax) + waveRateLate * late), 1e-9), reason: '$tier $wave');
        expect((s.range, s.shotSpeed, s.cost, s.def), (b.range, b.shotSpeed, killGold(b.cost, tier, wave), waveDefence(wave)), reason: '$tier $wave');
      }
    }
    final late = enemyStats('orc', Tier.normal, 26); // the early caps: speed at +50%, attacks a second at +25%
    expect(late.speed, closeTo(27, 1e-9));
    expect(late.rate, closeTo(1 / 1.25, 1e-9));
    final archer = enemyTypes['skeleton_archer']!; // long range: its reach grows too, +25% by wave 26
    expect(enemyStats('skeleton_archer', Tier.normal, 11).range, closeTo(archer.range * 1.1, 1e-9));
    expect(enemyStats('skeleton_archer', Tier.highElite, 26).range, closeTo(archer.range * 1.25, 1e-9));
    expect(enemyStats(boss, Tier.boss, 5).hp, (bossStats.hp * 1.68).round());
    expect(enemyStats(boss, Tier.boss, 1).cost, bossStats.cost * 4); // 160: the boss pays four times
  });

  test('from wave 16 monsters gain waveHpLate / waveDmgLate of their base a wave instead of waveHp / waveDmg (#36)', () {
    // The owner's pick: +30% base HP and +10% base damage a wave from wave 16, where it was +17% / +6% (+15% HP until
    // decisions-log 318).
    expect((waveHp, waveDmg, waveLateFrom, waveHpLate, waveDmgLate), (0.17, 0.06, 15, 0.30, 0.10));
    final orc = enemyTypes['orc']!;
    // Through wave 15 the early curve: 80 hp and 10 damage grow 17% and 6% a wave.
    expect(enemyStats('orc', Tier.normal, 15).hp, (orc.hp * (1 + waveHp * 14)).round()); // 270
    expect(enemyStats('orc', Tier.normal, 15).dmg, closeTo(orc.dmg * (1 + waveDmg * 14), 1e-9)); // 18.4
    // Wave 16: one late step, 80 × (1 + 2.38 + 0.3) and 10 × (1 + 0.84 + 0.1).
    expect(enemyStats('orc', Tier.normal, 16).hp, 294);
    expect(enemyStats('orc', Tier.normal, 16).dmg, closeTo(19.4, 1e-9));
    // Wave 30: 80 × (1 + 2.38 + 0.3 × 15) and 10 × (1 + 0.84 + 0.1 × 15); the old curve made it 80 × 5.35 = 428.
    expect(enemyStats('orc', Tier.normal, 30).hp, 630);
    expect(enemyStats('orc', Tier.normal, 30).dmg, closeTo(33.4, 1e-9));
    for (final wave in [16, 17, 20, 30, 40]) {
      final s = enemyStats('orc', Tier.normal, wave), late = wave - waveLateFrom;
      // From wave 35 the tide on top (#92, tide_test.dart).
      expect(s.hp, (orc.hp * (1 + waveHp * 14 + waveHpLate * late) * tide(wave, tideHp)).round(), reason: 'wave $wave');
      expect(s.dmg, closeTo(orc.dmg * (1 + waveDmg * 14 + waveDmgLate * late) * tide(wave, tideDmg), 1e-9), reason: 'wave $wave');
    }
    // Every late wave adds the late share of the base; the early ones the early share.
    expect(waveGrowth(31, waveHp, waveHpLate) - waveGrowth(30, waveHp, waveHpLate), closeTo(waveHpLate, 1e-9));
    expect(waveGrowth(10, waveHp, waveHpLate) - waveGrowth(9, waveHp, waveHpLate), closeTo(waveHp, 1e-9));
    expect(waveGrowth(1, waveHp, waveHpLate), 1);
    expect(waveGrowth(0, waveHp, waveHpLate), 1); // before the first wave, like wave 1
  });

  test('a long range monster\'s reach grows 1% of its base a wave, +25% by wave 26 (then #71); a melee one\'s or a healer\'s never', () {
    expect([for (final w in [1, 11, 26]) enemyStats('skeleton_archer', Tier.normal, w).range],
        [closeTo(60, 1e-9), closeTo(66, 1e-9), closeTo(75, 1e-9)]);
    expect(enemyStats('orc', Tier.normal, 40).range, 12);
    expect(enemyStats(boss, Tier.boss, 40).range, 20);
    expect(enemyStats(necroHealer, Tier.normal, 40).range, 64); // it doesn't shoot
  });

  test('walking speed grows 2% a wave and attacks a second 1%, +50% and +25% by wave 26 (then #71)', () {
    expect([for (final w in [1, 11, 26]) enemyStats('slime', Tier.normal, w).speed],
        [closeTo(18, 1e-9), closeTo(21.6, 1e-9), closeTo(27, 1e-9)]);
    expect(enemyStats('slime', Tier.normal, 11).rate, closeTo(0.8 / 1.1, 1e-9)); // rate is the pause
    expect(enemyStats('slime', Tier.normal, 26).rate, closeTo(0.8 / 1.25, 1e-9));
  });

  test('a tier multiplies on top of the wave\'s growth', () {
    expect(enemyStats('werewolf', Tier.elite, 26).speed, closeTo(32 * 1.05 * 1.5, 1e-9)); // 50.4
  });

  test('shot speed, splash and regen never grow with the wave, and kill gold only by killGold (#83)', () {
    for (final type in [...enemyTypes.keys, boss, necroHealer]) {
      final b = switch (type) { boss => bossStats, necroHealer => necroHealerStats, _ => enemyTypes[type]! };
      for (final tier in Tier.values) {
        final s = enemyStats(type, tier, 40);
        expect((s.shotSpeed, s.splash, s.regen, s.cost), (b.shotSpeed, b.splash, b.regen, killGold(b.cost, tier, 40)),
            reason: '$type $tier');
      }
    }
  });

  test('a monster healer heals more and faster with the wave, but reaches no further', () {
    final s = enemyStats(necroHealer, Tier.normal, 11);
    expect(s.dmg, closeTo(8 * 1.6, 1e-9)); // its heal is its damage: 12.8
    expect(s.rate, closeTo(1.2 / 1.1, 1e-9));
    expect(s.speed, closeTo(16 * 1.2, 1e-9));
    expect(s.range, 64);
  });

  test('a monster strikes at its wave\'s pace: a wave-11 orc waits 1/1.1 s between blows', () {
    final g = bare(Random(1))..gold = 1000;
    placeNow(g, 'knight', 3, 3);
    final knight = g.troops.single..busyUntil = hold;
    g
      ..wave = 10
      ..startWave();
    g.queue
      ..clear()
      ..add(('orc', Tier.normal));
    g.tick(0.05);
    final orc = g.enemies.single
      ..pos = knight.pos + const Point(10, 0)
      ..entered = true;
    for (var i = 0; i < 20 && orc.attackedAt == double.negativeInfinity; i++) {
      g.tick(0.05);
    }
    expect(orc.attackedAt, g.t); // it just struck
    expect(orc.cd, closeTo(1 / 1.1, 1e-9)); // not the orc's base 1.0
  });

  test('elites start at wave 3 and high elites at wave 7, both capped', () {
    expect([for (var w = 1; w <= 3; w++) eliteChance(w)], [0, 0, closeTo(0.05, 1e-9)]);
    expect(eliteChance(9), closeTo(0.35, 1e-9));
    expect(eliteChance(30), 0.35);
    expect([for (var w = 1; w <= 7; w++) highEliteChance(w)], [0, 0, 0, 0, 0, 0, closeTo(0.03, 1e-9)]);
    expect(highEliteChance(30), 0.2);
  });

  /// The queue of each wave from 1 to [waves], for a game seeded with [seed].
  List<List<(String, Tier)>> queues(int seed, int waves) {
    final g = bare(Random(seed))..slots = Random(seed), out = <List<(String, Tier)>>[];
    for (var w = 1; w <= waves; w++) {
      g.startWave();
      out.add([...g.queue]);
      g.queue.clear();
    }
    return out;
  }

  test('each wave brings 4 + 2n monsters, a mini boss every 3rd wave, no elites early', () {
    for (var seed = 0; seed < 20; seed++) {
      final all = queues(seed, 10);
      for (var w = 1; w <= 10; w++) {
        // The healing necromancers come on top of the wave (their own test covers where); counted apart.
        final q = all[w - 1].where((m) => m.$1 != necroHealer).toList(), pool = enemyTypes.keys.take(1 + (w >> 1)).toList();
        expect(all[w - 1].length - q.length, necroHealersIn(w), reason: 'seed $seed wave $w');
        final rolled = q.take(4 + 2 * w).toList();
        expect(q.length, 4 + 2 * w + (w % 3 == 0 || w % 5 == 0 ? 1 : 0), reason: 'seed $seed wave $w');
        expect(rolled.every((m) => pool.contains(m.$1) && m.$2.index <= Tier.highElite.index), isTrue, reason: 'seed $seed wave $w');
        if (w <= 2) expect(rolled.every((m) => m.$2 == Tier.normal), isTrue, reason: 'seed $seed wave $w');
        if (w < 7) expect(rolled.any((m) => m.$2 == Tier.highElite), isFalse, reason: 'seed $seed wave $w');
        // The slots hold any type of the pool (#58); from [necroMiniFrom] the mini boss slot may hold the
        // necromancer instead, and from [necroBossFrom] the boss slot.
        if (w % 3 == 0) {
          expect(q.last.$2, Tier.miniBoss, reason: 'seed $seed wave $w');
          expect(q.last.$1, w < necroMiniFrom ? isIn(pool) : anyOf(isIn(pool), boss), reason: 'seed $seed wave $w');
        }
        if (w % 5 == 0) {
          expect((q.last.$2, [...pool, if (w >= necroBossFrom) boss].contains(q.last.$1)), (Tier.boss, true), reason: 'seed $seed wave $w');
        }
      }
    }
  });

  test('by wave 20 elites and high elites turn up', () {
    final tiers = <Tier>[];
    for (var seed = 0; seed < 20; seed++) {
      final g = bare(Random(seed))..wave = 19;
      g.startWave();
      tiers.addAll(g.queue.take(4 + 2 * 20).map((m) => m.$2));
    }
    for (final t in [Tier.normal, Tier.elite, Tier.highElite]) {
      expect(tiers, contains(t));
    }
    final high = tiers.where((t) => t == Tier.highElite).length / tiers.length;
    expect(high, closeTo(highEliteChance(20), 0.05));
  });

  test('a spawned monster carries its tier and its wave\'s stats, at full health', () {
    final g = bare(Random(1))
      ..wave = 3
      ..startWave();
    g.queue
      ..clear()
      ..add(('orc', Tier.elite));
    g.tick(0.05);
    final e = g.enemies.single, want = enemyStats('orc', Tier.elite, 4);
    expect(e.tier, Tier.elite);
    expect((e.stats.hp, e.maxHp, e.hp, e.stats.dmg, e.stats.cost), (want.hp, want.hp, want.hp.toDouble(), want.dmg, want.cost));
    expect((e.stats.speed, e.stats.rate, e.stats.range), (want.speed, want.rate, want.range));
  });

  test('the necromancer\'s skeletons are normal ones of the wave', () {
    final g = bare(Random(1))
      ..wave = 4
      ..startWave();
    g.queue
      ..clear()
      ..add((boss, Tier.boss));
    for (var i = 0; i < 44; i++) {
      g.tick(0.05);
    }
    final skeletons = g.enemies.where((u) => u.type == minion).toList();
    expect(skeletons, hasLength(minions));
    for (final s in skeletons) {
      expect((s.tier, s.stats.hp, s.maxHp), (Tier.normal, enemyStats(minion, Tier.normal, 5).hp, enemyStats(minion, Tier.normal, 5).hp));
      expect(s.stats.speed, closeTo(20 * 1.08, 1e-9)); // the wave's pace, like any skeleton of wave 5
      expect(s.stats.rate, closeTo(0.9 / 1.04, 1e-9));
    }
  });

  test('a mini boss pays its reward', () {
    for (final roll in [1.0, 0.0]) {
      final g = bare();
      placeNow(g, 'knight', 2, 3);
      g.loot = _Dice(roll, Item.bow.index);
      final mini = Unit(Side.enemy, 'orc', enemyStats('orc', Tier.miniBoss, 3), g.troops.single.pos + const Point(10, 0))
        ..tier = Tier.miniBoss
        ..hp = 1
        ..busyUntil = hold;
      g.units.add(mini);
      final gold = g.gold;
      g.tick(0.05);
      expect(mini.alive, isFalse);
      expect(g.gold, gold + 19); // a mini boss pays three times the orc's 6, grown two waves: 18 × 1.092 = 19.66
    }
  });

  test('each tier pays 1, 1.5, 2, 3 or 4 times its type\'s base gold (#83)', () {
    expect([for (final t in Tier.values) t.reward], [1, 1.5, 2, 3, 4]);
  });

  test('kill gold is base × rank × (1 + killGoldGrowth)^(wave − 1), floored once at the end (#83)', () {
    expect(killGoldGrowth, 0.045); // decisions-log 318 (the owner's start was 0.05)
    // The werebear's 20 through the waves: 20 × 1.045 = 20.9, × 1.045^4 = 23.85, × 1.045^9 = 29.72, × 1.045^19 = 46.2.
    expect([for (final w in [1, 2, 5, 10, 20, 50]) killGold(20, Tier.normal, w)], [20, 20, 23, 29, 46, 172]);
    // Floored once, not wave by wave: a slime's 3 would stay 3 forever (3 × 1.045 = 3.135 → 3, and again).
    expect([for (final w in [1, 7, 8, 20]) killGold(3, Tier.normal, w)], [3, 3, 4, 6]);
    // Each rank on the orc's 6 in wave 10 (× 1.486): 8.9, 13.37, 17.8, 26.7, 35.7.
    expect([for (final t in Tier.values) killGold(6, t, 10)], [8, 13, 17, 26, 35]);
    expect(killGold(6, Tier.elite, 5), 10); // 9 × 1.1925 = 10.73
    expect(killGold(40, Tier.boss, 5), 190); // the necromancer boss's first wave: 160 × 1.1925 = 190.8
    // Before any wave (wave 0) it pays like wave 1.
    expect(killGold(20, Tier.miniBoss, 0), 60);
    // The owner's sketch with r = 30%: 1 → 1.3 → 1.69 → 2.197 → 2.8561 → 3.71293, on 100 gold.
    expect([for (final w in [1, 2, 3, 4, 5, 6]) killGold(100, Tier.normal, w, 0.3)], [100, 130, 169, 219, 285, 371]);
    // r = 0 is the old rule on the new ranks: base × rank in every wave (floored: an elite slime's 4.5 is 4).
    for (final type in [...enemyTypes.keys, boss, necroHealer]) {
      final b = switch (type) { boss => bossStats, necroHealer => necroHealerStats, _ => enemyTypes[type]! };
      for (final tier in Tier.values) {
        for (final wave in [1, 10, 50]) {
          expect(killGold(b.cost, tier, wave, 0), (b.cost * tier.reward).floor(), reason: '$type $tier $wave');
        }
      }
    }
    expect(killGold(3, Tier.elite, 30, 0), 4);
  });

  test('a kill pays the type\'s base gold times its tier, grown with the wave', () {
    for (final (type, wave, paid) in [
      ('orc', 1, [6, 9, 12, 18]),
      ('orc', 10, [8, 13, 17, 26]),
      ('werebear', 1, [20, 30, 40, 60]),
      ('werebear', 10, [29, 44, 59, 89]),
    ]) {
      for (final tier in [Tier.normal, Tier.elite, Tier.highElite, Tier.miniBoss]) {
        final g = bare();
        placeNow(g, 'knight', 2, 3);
        final e = Unit(Side.enemy, type, enemyStats(type, tier, wave), g.troops.single.pos + const Point(10, 0))
          ..tier = tier
          ..hp = 1
          ..busyUntil = hold;
        g.units.add(e);
        final gold = g.gold;
        g.tick(0.05);
        expect(e.alive, isFalse, reason: '$type $tier $wave');
        expect(g.gold - gold, paid[tier.index], reason: '$type $tier $wave');
      }
    }
  });

  test('the necromancer comes as the boss tier and its kill pays four times its gold, grown: 190 in wave 5', () {
    final g = bare(Random(1))..wave = 4;
    placeNow(g, 'knight', 2, 3);
    g.startWave();
    g.queue
      ..clear()
      ..add((boss, Tier.boss));
    g.tick(0.05);
    final necro = g.enemies.single;
    expect((necro.type, necro.tier, necro.stats.cost), (boss, Tier.boss, 190)); // 40 × 4 × 1.045^4 = 190.8
    necro
      ..pos = g.troops.single.pos + const Point(10, 0)
      ..hp = 1
      ..busyUntil = hold;
    final gold = g.gold;
    g.tick(0.05);
    expect(necro.alive, isFalse);
    expect(g.gold, gold + 190);
  });

  test('the necromancer\'s raised skeletons pay no gold', () {
    final g = bare(Random(1))..wave = 4;
    placeNow(g, 'knight', 2, 3);
    final knight = g.troops.single..busyUntil = hold; // stays put while the skeletons rise
    g.startWave();
    g.queue
      ..clear()
      ..add((boss, Tier.boss));
    for (var i = 0; i < 44; i++) {
      g.tick(0.05);
    }
    final skeletons = g.enemies.where((u) => u.type == minion).toList();
    expect(skeletons, hasLength(minions));
    expect([for (final s in skeletons) s.stats.cost], everyElement(0));
    for (final e in g.enemies) {
      e.busyUntil = hold;
    }
    knight.busyUntil = double.negativeInfinity;
    final raised = skeletons.first
      ..pos = knight.pos + const Point(10, 0)
      ..hp = 1;
    final gold = g.gold;
    g.tick(0.05);
    expect(raised.alive, isFalse);
    expect(g.gold, gold);
  });

  test('winning a wave still pays only its bonus, 20 + 10 per wave', () {
    final g = bare();
    for (var n = 1; n <= 6; n++) {
      final gold = g.gold;
      winWave(g);
      expect((g.wave, g.lastBonus, g.gold - gold), (n, 20 + 10 * n, 20 + 10 * n));
    }
  });

  test('before any tap "Main Baru" is not asking "Yakin?"', () {
    for (final w in [Welcome(null, discard: () {}), Welcome(Game()..wave = 3, discard: () {})]) {
      expect(w.confirming(0), isFalse);
      expect(w.confirming(100), isFalse);
    }
  });

  test('without a save one tap on "Main Baru" starts a fresh game and discards the save once', () {
    var discarded = 0;
    final w = Welcome(null, discard: () => discarded++);
    final g = w.fresh(0);
    expect(g, isNotNull);
    expect((g!.wave, g.gold, g.troops.length), (0, Game.startGold, 1));
    expect(discarded, 1);
  });

  test('over a save the first tap on "Main Baru" only asks "Yakin?", for 3 seconds', () {
    var discarded = 0;
    final saved = Game()..wave = 3;
    final w = Welcome(saved, discard: () => discarded++);
    expect(w.saved, same(saved)); // "Lanjutkan" goes back into it
    expect(w.fresh(0), isNull);
    expect(discarded, 0);
    expect(w.confirming(0), isTrue);
    expect(w.confirming(2.9), isTrue);
    expect(w.confirming(Welcome.confirmTime), isFalse);
  });

  test('a second tap on "Main Baru" within 3 seconds throws the save away and starts fresh', () {
    var discarded = 0;
    final saved = Game()..wave = 3;
    final w = Welcome(saved, discard: () => discarded++);
    expect(w.fresh(0), isNull);
    final g = w.fresh(2.5);
    expect(g, isNotNull);
    expect(g, isNot(same(saved)));
    expect(g!.wave, 0);
    expect(discarded, 1);
  });

  test('a second tap on "Main Baru" after 3 seconds only asks again, and a third in time starts fresh', () {
    var discarded = 0;
    final w = Welcome(Game()..wave = 3, discard: () => discarded++);
    expect(w.fresh(0), isNull);
    expect(w.fresh(3.5), isNull);
    expect(discarded, 0);
    expect(w.confirming(3.5), isTrue); // asking again from 3.5 s
    expect(w.fresh(4.0), isNotNull);
    expect(discarded, 1);
  });

  const fwd = Point(10.0, 0.0); // a step forward, for [Game.speedTo]
  final fast = troopTypes['knight']!.speed * pow(1.25, 4); // a knight with 4 boots
  /// The catch-up pace [u] walks at behind that knight: its pace, at most [Game.catchUpMost] × its own (decisions-log 309).
  double capped(Unit u) => min(fast, Game.catchUpMost * u.stats.speed);


  /// Mid-wave: an archer (0,3) and a priest (0,5) five columns behind a [melee] with [boots] boots at
  /// (5,3), 80px ahead of them. A held slime far off keeps the wave on.
  (Game, Unit, Unit, Unit) catchUpBattle({String melee = 'knight', int boots = 4}) {
    final g = bare()..gold = 100000;
    g.upgrades[melee] = List.filled(boots, Item.boots);
    placeNow(g, 'archer', 0, 3);
    placeNow(g, 'priest', 0, 5);
    placeNow(g, melee, 5, 3);
    g.startWave();
    g.queue.clear();
    g.units.add(Unit(Side.enemy, 'slime', enemyTypes['slime']!, const Point(300, 100))..busyUntil = hold);
    final ts = g.troops.toList();
    return (g, ts[0], ts[1], ts[2]);
  }

  test('mid-wave a support that fell behind the melee walks as fast as the fastest melee, at most twice its own speed (decisions-log 309)', () {
    final (g, archer, priest, knight) = catchUpBattle();
    expect(knight.stats.speed, closeTo(fast, 1e-9));
    expect(knight.pos.x - archer.pos.x, 5 * tile);
    expect(g.speedTo(archer, archer.pos + fwd), closeTo(capped(archer), 1e-9));
    expect(g.speedTo(priest, priest.pos + fwd), closeTo(capped(priest), 1e-9));
    expect(g.speedTo(knight, knight.pos + fwd), knight.stats.speed); // melee keep their own
    final slime = g.enemies.single;
    expect(g.speedTo(slime, slime.pos + fwd), slime.stats.speed);
    expect(g.speedTo(slime, slime.pos - fwd), slime.stats.speed);
  });

  test('a support catches up only when it trails the melee by more than its rank\'s place plus 1.5 tiles', () {
    final (g, archer, priest, knight) = catchUpBattle();
    double behind(Unit u, double gap) {
      u.pos = Point(knight.pos.x - gap, u.pos.y);
      return g.speedTo(u, u.pos + fwd);
    }

    expect(behind(archer, 40), archer.stats.speed); // a tile + 1.5 tiles
    expect(behind(archer, 41), closeTo(capped(archer), 1e-9));
    expect(behind(priest, 56), priest.stats.speed); // two tiles + 1.5 tiles
    expect(behind(priest, 57), closeTo(capped(priest), 1e-9));
  });

  test('a support never speeds up walking backwards, without living melee or between waves; marching in mid-wave it always does', () {
    final (g, archer, priest, knight) = catchUpBattle();
    expect(g.speedTo(archer, archer.pos - fwd), archer.stats.speed);
    archer
      ..entered = false // bought mid-wave (#61): at the catch-up pace all the way, however near
      ..pos = Point(knight.pos.x - tile, archer.pos.y);
    expect(g.speedTo(archer, archer.pos + fwd), closeTo(capped(archer), 1e-9));
    archer
      ..entered = true
      ..pos = Point(0.5 * tile, archer.pos.y);
    expect(g.speedTo(archer, archer.pos + fwd), closeTo(capped(archer), 1e-9));
    knight
      ..hp = 0
      ..dying = 0;
    expect(g.speedTo(archer, archer.pos + fwd), archer.stats.speed);
    expect(g.speedTo(priest, priest.pos + fwd), priest.stats.speed);

    final h = bare()..gold = 100000;
    h.upgrades['knight'] = List.filled(4, Item.boots);
    placeNow(h, 'archer', 0, 3);
    placeNow(h, 'knight', 5, 3);
    final a = h.troops.first;
    expect(h.waveActive, isFalse);
    expect(h.speedTo(a, a.pos + fwd), a.stats.speed);
  });

  test('out of sight left of the view (once the wave has shown a fight, within [keepUpInset] of its edge) a troop walking '
      'forward catches up, however near the melee', () {
    final (g, archer, _, knight) = catchUpBattle();
    g.tick(0.05); // the battle point takes up the wave
    archer.pos = Point(knight.pos.x - 40, archer.pos.y); // within its place: its own pace
    expect(g.speedTo(archer, archer.pos + fwd), archer.stats.speed);
    g.cam = archer.pos.x + Game.offViewBy - keepUpInset + 0.1;
    expect(g.speedTo(archer, archer.pos + fwd), archer.stats.speed); // no fight shown yet: the edge itself
    g.fightX = knight.pos.x; // the view has centred a fight this wave (#85)
    expect(g.speedTo(archer, archer.pos + fwd), closeTo(capped(archer), 1e-9));
    g
      ..fightX = null
      ..cam = archer.pos.x + Game.offViewBy + 0.1;
    expect(g.speedTo(archer, archer.pos + fwd), closeTo(capped(archer), 1e-9));
    expect(g.speedTo(archer, archer.pos - fwd), archer.stats.speed); // not walking back
  });

  test('a support catching up never walks slower than its own speed nor faster than the fastest melee nor twice its own', () {
    (double, double) supports(String melee, int boots) {
      final (g, archer, priest, _) = catchUpBattle(melee: melee, boots: boots);
      return (g.speedTo(archer, archer.pos + fwd), g.speedTo(priest, priest.pos + fwd));
    }

    expect(supports('armored_axeman', 0), (22, 20)); // melee 18: each keeps its own
    expect(supports('knight', 0), (24, 24)); // melee 24

    // A slow axeman at the rear is who they keep up with, but at the booted knight's pace.
    final (g, archer, _, _) = catchUpBattle();
    placeNow(g, 'armored_axeman', 4, 3);
    expect(g.speedTo(archer, archer.pos + fwd), closeTo(capped(archer), 1e-9));
  });

  test('a troop catching up walks at most twice its own speed, however fast the melee (decisions-log 309)', () {
    final (g, archer, priest, knight) = catchUpBattle(boots: 8);
    placeNow(g, 'wizard', 0, 1);
    final wizard = g.troops.last;
    expect(knight.stats.speed, greaterThan(4 * wizard.stats.speed)); // its pace was the knight's until 309
    for (final u in [archer, priest, wizard]) {
      expect(g.speedTo(u, u.pos + fwd), closeTo(Game.catchUpMost * u.stats.speed, 1e-9), reason: u.type);
    }
    for (var i = 0; i < 20; i++) {
      final before = {for (final u in [archer, priest, wizard]) u: u.pos};
      g.tick(0.05);
      for (final MapEntry(key: u, value: p) in before.entries) {
        expect(u.pos.distanceTo(p), lessThanOrEqualTo(Game.catchUpMost * u.stats.speed * 0.05 + 1e-9), reason: '${u.type} tick $i');
      }
    }
    expect(wizard.pos.x - wizard.post.x, greaterThan(wizard.stats.speed * 1.5)); // it did catch up, faster than its walk
  });

  test('a troop that three troops pass at once steps aside one of its own walk steps in the tick, not three (decisions-log 309)', () {
    final g = bare()..gold = 100000;
    for (final (c, r) in [(0, 1), (0, 3), (0, 5), (0, 7)]) {
      placeNow(g, c == 0 && r == 7 ? 'archer' : 'soldier', c, r);
    }
    final ts = g.troops.toList(), archer = ts[3];
    archer
      ..pos = archer.post = const Point(100, 56)
      ..busyUntil = hold; // it stands where they pass
    // Three soldiers walking at it from behind, from above and from ahead, each a tile and more from it and from each
    // other (no shove among them): each would have it step aside (down, left, down: 2.5 units in all until 309).
    for (final (u, at, to) in [
      (ts[0], const Point(82.0, 56.0), const Point(12 * tile, 56.0)),
      (ts[1], const Point(100.0, 38.0), const Point(100.0, 120.0)),
      (ts[2], const Point(118.0, 56.0), const Point(20.0, 56.0)),
    ]) {
      u
        ..pos = at
        ..post = to;
    }
    final from = archer.pos;
    g.tick(0.05);
    expect(ts.take(3).every((u) => u.moving), isTrue);
    expect(archer.yieldUntil, greaterThan(g.t)); // it stepped aside ...
    expect(archer.pos.distanceTo(from), closeTo(archer.stats.speed * 0.05, 1e-9)); // ... one walk step in all
  });

  test('the rearmost melee in the fight, not an idle one, is who a support keeps up with', () {
    final (g, archer, _, knight) = catchUpBattle();
    placeNow(g, 'knight', 1, 3); // idle, just ahead of the archer
    knight
      ..pos = Point(200, knight.pos.y)
      ..attackedAt = g.t;
    expect(g.speedTo(archer, archer.pos + fwd), closeTo(capped(archer), 1e-9));
    knight.attackedAt = g.t - 2.5; // nobody fighting: the rearmost of all, the idle knight, counts
    expect(g.speedTo(archer, archer.pos + fwd), archer.stats.speed);
  });

  test('mid-wave a melee more than 1.5 tiles behind the rearmost melee in the fight catches up too; with meleeCatchUp off it doesn\'t', () {
    final (g, _, _, knight) = catchUpBattle();
    placeNow(g, 'armored_axeman', 1, 3);
    final axe = g.troops.last;
    double behind(double gap) {
      axe.pos = Point(knight.pos.x - gap, 88);
      return g.speedTo(axe, axe.pos + fwd);
    }

    knight.attackedAt = g.t; // in the fight
    expect(behind(4 * tile), closeTo(capped(axe), 1e-9));
    expect(behind(1.5 * tile), axe.stats.speed);
    expect(behind(1.5 * tile + 1), closeTo(capped(axe), 1e-9));
    expect(g.speedTo(axe, axe.pos - fwd), axe.stats.speed); // walking back
    knight.attackedAt = g.t - 2.5; // nobody in the fight: a melee walking in keeps its own
    expect(behind(4 * tile), axe.stats.speed);
    knight.attackedAt = g.t;
    g.meleeCatchUp = false;
    expect(behind(4 * tile), axe.stats.speed);
  });

  /// Mid-wave: a templar held at (0,3), a [light] melee at ([col],3) and a held slime far off.
  (Game, Unit, Unit) paceBattle({String light = 'soldier', int col = 5}) {
    final g = bare()..gold = 100000;
    placeNow(g, 'knight_templar', 0, 3);
    placeNow(g, light, col, 3);
    g.startWave();
    g.queue.clear();
    g.units.add(Unit(Side.enemy, 'slime', enemyTypes['slime']!, const Point(300, 56))..busyUntil = hold);
    final ts = g.troops.toList();
    ts[0].busyUntil = hold; // stays where it is, walking in all the same (not fighting)
    return (g, ts[0], ts[1]);
  }

  test('light melee walking in may get paceLead ahead of the foremost heavy-armored melee walking in, no further', () {
    final (g, templar, soldier) = paceBattle();
    expect(g.paceLimit(soldier), templar.pos.x + Game.paceLead);
    placeNow(g, 'armored_axeman', 2, 5); // the foremost heavy counts
    final axe = g.troops.last;
    expect(g.paceLimit(soldier), axe.pos.x + Game.paceLead);
    axe.retreating = true; // falling back to a healer: not walking in
    expect(g.paceLimit(soldier), templar.pos.x + Game.paceLead);
    axe.retreating = false;
    for (final (row, light) in ['knight', 'swordsman', 'lancer'].indexed) {
      placeNow(g, light, 3, row);
      expect(g.paceLimit(g.troops.last), axe.pos.x + Game.paceLead, reason: light);
    }
    for (final other in ['knight_templar', 'armored_axeman']) {
      expect(g.paceLimit(g.troops.firstWhere((u) => u.type == other)), isNull, reason: other);
    }
    placeNow(g, 'archer', 0, 7);
    expect(g.paceLimit(g.troops.last), isNull);
  });

  test('no pace limit while the light melee fights or is hit, once a heavy fights or is hit, with no heavy walking in, between waves, in the stall march or when off', () {
    final (g, templar, soldier) = paceBattle();
    bool limited() => g.paceLimit(soldier) != null;
    expect(limited(), isTrue);
    soldier.attackedAt = g.t; // fighting: it doesn't turn away
    expect(limited(), isFalse);
    soldier.attackedAt = double.negativeInfinity;
    soldier.hurtAt = g.t; // under fire (a skeleton archer): it doesn't wait there
    expect(limited(), isFalse);
    soldier.hurtAt = g.t - 2.5;
    expect(limited(), isTrue);
    templar.attackedAt = g.t; // the heavies are in the fight
    expect(limited(), isFalse);
    templar.attackedAt = double.negativeInfinity;
    templar.hurtAt = g.t;
    expect(limited(), isFalse);
    templar.hurtAt = double.negativeInfinity;
    templar.entered = false; // still marching in
    expect(limited(), isFalse);
    templar
      ..entered = true
      ..hp = 0
      ..dying = 0;
    expect(limited(), isFalse);
    templar
      ..hp = templar.maxHp.toDouble()
      ..dying = -1;
    expect(limited(), isTrue);
    g.marching = true;
    expect(limited(), isFalse);
    g.marching = false;
    g.heavyPace = false;
    expect(limited(), isFalse);
    g.heavyPace = true;
    g.units.removeWhere((u) => u.side == Side.enemy); // between waves
    expect((g.waveActive, limited()), (false, false));
  });

  test('too far ahead of the heavies a light melee steps back to paceLead, facing its foe; behind it, it stops there on its way', () {
    final (g, templar, soldier) = paceBattle();
    final limit = templar.pos.x + Game.paceLead;
    expect(soldier.pos.x, greaterThan(limit));
    g.tick(0.05);
    expect((soldier.pos.x < 5.5 * tile, soldier.dir), (true, 1)); // backing off, still facing the slime
    for (var i = 0; i < 60; i++) {
      g.tick(0.05);
    }
    expect(soldier.pos.x, closeTo(limit, 1e-9));
    expect(soldier.moving, isFalse);

    final (h, _, behind) = paceBattle(col: 1);
    for (var i = 0; i < 60; i++) {
      h.tick(0.05);
    }
    expect(behind.pos.x, closeTo(limit, 1e-9));
    expect(behind.moving, isFalse);
    h.troops.first.attackedAt = h.t; // the templar reaches the fight: the soldier goes on
    h.tick(0.05);
    expect(behind.pos.x, greaterThan(limit));
  });

  test('the troops out of sight left of the view are the living ones whose middle is more than half a tile left of its edge', () {
    final g = bare();
    placeNow(g, 'knight', 0, 3);
    placeNow(g, 'archer', 0, 5);
    final (knight, archer) = (g.troops.first, g.troops.last);
    g.cam = knight.pos.x + Game.offViewBy;
    expect(g.leftOfView, isEmpty);
    g.cam += 0.1;
    expect(g.leftOfView.toList(), [knight, archer]);
    archer
      ..hp = 0
      ..dying = 0;
    expect(g.leftOfView.toList(), [knight]);
  });

  test('a kiting archer far behind the melee backs off at its own speed even when that is forward', () {
    final (g, archer, priest, knight) = catchUpBattle();
    knight
      ..pos = Point(300, knight.pos.y)
      ..busyUntil = hold;
    archer.pos = const Point(100, 56);
    priest.pos = const Point(40, 120);
    g.units.add(Unit(Side.enemy, 'werebear', enemyTypes['werebear']!, const Point(80, 56))..busyUntil = hold);
    expect(g.speedTo(archer, archer.pos + fwd), closeTo(capped(archer), 1e-9)); // walking up it would catch up
    final before = archer.pos;
    g.tick(0.05);
    expect(archer.pos.x, greaterThan(before.x)); // away from the werebear behind it
    expect(archer.pos.distanceTo(before), lessThanOrEqualTo(archer.stats.speed * 0.05 + 1e-9));
  });

  test('mid-wave unbooted supports keep up with booted knights, so the archer shoots and the priest heals', () {
    final g = Game(Random(1))
      ..gold = 100000
      ..viewW = 341;
    g.upgrades['knight'] = List.filled(4, Item.boots);
    for (final type in ['knight', 'knight', 'knight', 'archer']) {
      g.autoPlace(type);
    }
    for (var i = 0; i < 200; i++) {
      g.tick(0.05);
    }
    final priest = g.troops.firstWhere((u) => u.type == 'priest'), archer = g.troops.firstWhere((u) => u.type == 'archer');
    final knights = g.troops.where((u) => u.type == 'knight').toList();
    g.startWave();
    final t0 = g.t;
    var fought = false, shot = false, healed = false, archerGap = 0.0, priestGap = 0.0;
    run(g, each: (_) {
      fought |= knights.any((k) => k.attackedAt > t0);
      shot |= archer.attackedAt > t0;
      healed |= priest.attackedAt > t0;
      if (fought) return;
      final rear = knights.where((k) => k.alive).map((k) => k.pos.x).reduce(min);
      archerGap = max(archerGap, rear - archer.pos.x);
      priestGap = max(priestGap, rear - priest.pos.x);
    });
    expect(g.waveActive, isFalse); // won
    // At most twice their own walk since decisions-log 309, they trail the booted knights further than at the knights'
    // pace (38.9 and 57.8 then), and still shoot and heal.
    expect(archerGap, lessThanOrEqualTo(6 * tile)); // measured 84.2
    expect(priestGap, lessThanOrEqualTo(8 * tile)); // measured 120.9
    expect(shot, isTrue);
    expect(healed, isTrue);
  });

  test('a troop name is a first and a last name from the lists, never one already taken', () {
    final dice = Random(1), taken = <String>{};
    for (var i = 0; i < 200; i++) {
      final name = troopName(dice, taken);
      final [first, last] = name.split(' ');
      expect((firstNames.contains(first), lastNames.contains(last)), (true, true), reason: name);
      expect(taken.add(name), isTrue, reason: name);
    }
    final all = {for (final f in firstNames) for (final l in lastNames) '$f $l'};
    expect(troopName(Random(1), all.difference({'Zora Gray'})), 'Zora Gray'); // the one left
    expect(troopName(Random(1), all), '${firstNames.first} ${lastNames.first}'); // none left: a repeat
  });

  test('every troop, the free healer too, gets a name no other living troop has', () {
    final g = Game(Random(1), Random(2))
      ..capacity = 6 * rows
      ..gold = 100000;
    expect(g.troops.single.name.split(' '), hasLength(2));
    for (var i = 0; i < 40; i++) {
      expect(g.autoPlace(troopTypes.keys.elementAt(i % troopTypes.length)), isTrue);
    }
    final names = [for (final u in g.troops) u.name];
    expect(names, hasLength(41));
    expect(names.toSet(), hasLength(41));
  });

  test('names roll their own dice: the same dice give the same names, and never change the waves', () {
    List<String> army(Game g) {
      for (final t in ['knight', 'archer', 'soldier']) {
        g.autoPlace(t);
      }
      return [for (final u in g.troops) u.name];
    }

    final a = Game(Random(5), Random(1))..gold = 1000, b = Game(Random(5), Random(1))..gold = 1000;
    final c = Game(Random(5), Random(99))..gold = 1000;
    final names = army(a);
    expect(army(b), names);
    expect(army(c), isNot(names));
    a.startWave();
    c.startWave();
    expect(c.queue, a.queue);
  });

  test('a fallen troop\'s name is free again; a living one\'s is not', () {
    final g = Game(Random(1), _Dice(0, 0))..gold = 1000; // every draw is the lists' first names
    final healer = g.troops.single;
    expect(healer.name, '${firstNames.first} ${lastNames.first}');
    g.autoPlace('knight');
    expect(g.troops.last.name, '${firstNames.first} ${lastNames[1]}'); // taken: the first free one in order
    healer
      ..hp = 0
      ..dying = 0;
    g.autoPlace('archer');
    expect(g.troops.last.name, healer.name);
  });

  test('the save keeps every troop\'s name; troops from an older save without one are named on load', () {
    final g = wide(Random(1))..gold = 1000;
    for (final t in ['knight', 'archer', 'soldier']) {
      g.autoPlace(t);
    }
    final j = jsonDecode(jsonEncode(g.toJson())) as Map<String, dynamic>;
    expect([for (final u in Game.fromJson(j).troops) u.name], [for (final u in g.troops) u.name]);
    for (final t in j['troops'] as List) {
      (t as Map).remove('name');
    }
    final names = [for (final u in Game.fromJson(j, null, Random(3)).troops) u.name];
    expect(names, hasLength(4));
    expect(names.every((n) => n.split(' ').length == 2), isTrue);
    expect(names.toSet(), hasLength(4));
    expect([for (final u in Game.fromJson(j, null, Random(3)).troops) u.name], names); // its own dice
  });

  test('monsters have no name', () {
    final g = bare(Random(1))..startWave();
    g.tick(0.05);
    expect(g.enemies.single.name, '');
  });

  test('a wave meter counts every monster the wave spawns from its queue, up to its total', () {
    // waveTotal counts the queue: the rolled monsters, the mini boss or boss, and the healers.
    for (final (w, total) in [(1, 6), (3, 11), (5, 16)]) {
      final g = bare(Random(1))..wave = w - 1;
      g.startWave();
      expect((g.waveSpawned, g.waveTotal, g.queue.length), (0, total, total), reason: 'wave $w');
    }
    final g = bare(Random(1))..lives = 1000; // nobody defends: they walk on
    g.startWave();
    for (var i = 1; i <= 6; i++) {
      g.tick(Game.spawnGap); // one monster a gap
      expect((g.waveSpawned, g.waveTotal), (i, 6));
    }
    expect(g.queue, isEmpty);
    expect(g.waveSpawned, g.waveTotal);
  });

  test('a necromancer\'s raised skeletons are not in the wave meter', () {
    final g = bare(Random(1))
      ..slots = _Dice(0, 0) // the boss slot's necromancer roll: it
      ..wave = necroBossWave - 1;
    g.startWave();
    // A knight that never falls nor strikes, so the wave goes on: with no troop standing, a monster at the back line
    // would lose it (decisions-log 329; the lives soaked the leaks until then).
    expect(placeNow(g, 'knight', 2, 3), isTrue);
    g.troops.single
      ..busyUntil = hold
      ..maxHp = 1000000000
      ..hp = 1e9;
    final total = g.waveTotal;
    for (var i = 0; i < 4000 && !g.enemies.any((e) => e.type == minion && e.raisedBy != null); i++) {
      g.tick(0.05);
    }
    expect(g.enemies.any((e) => e.type == minion && e.raisedBy != null), isTrue);
    expect(g.waveTotal, total);
    expect(g.waveSpawned, lessThanOrEqualTo(total));
  });

  test('the next wave starts its meter from nothing, and a loaded game has none', () {
    final g = bare(Random(1));
    placeNow(g, 'knight', 2, 3);
    winWave(g);
    expect(g.waveActive, isFalse);
    g.startWave();
    expect((g.waveSpawned, g.waveTotal), (0, g.queue.length));
    g.tick(0.05);
    final h = Game.fromJson(jsonDecode(jsonEncode(g.toJson())) as Map<String, dynamic>);
    expect((h.waveSpawned, h.waveTotal), (0, 0));
  });

  test('a refused relic leaves the troop and its price alone, and can go to a troop without one', () {
    final g = bare()..gold = 1000;
    placeNow(g, 'knight', 2, 3);
    placeNow(g, 'soldier', 3, 4);
    final knight = g.troops.firstWhere((u) => u.type == 'knight'), soldier = g.troops.firstWhere((u) => u.type == 'soldier');
    g.relicBag.addAll({Relic.fang: 1, Relic.guard: 1});
    g.useRelic(Relic.fang, knight);
    final stats = (knight.stats, knight.maxHp, knight.hp), price = g.priceOf('knight');
    expect(g.useRelic(Relic.guard, knight), isFalse);
    expect((knight.stats, knight.maxHp, knight.hp), stats);
    expect(g.priceOf('knight'), price);
    expect(g.useRelic(Relic.guard, soldier), isTrue);
    expect((soldier.relics.firstOrNull, g.relicBag[Relic.guard]), (Relic.guard, 0));
  });

  test('a fallen troop\'s relic can go to a new troop', () {
    final (g, s) = doomedSoldier();
    s.relics.add(Relic.thorns);
    placeNow(g, 'knight', 1, 6); // someone left standing: no wipe-out
    final knight = g.troops.firstWhere((u) => u.type == 'knight');
    g.tick(0.05);
    expect((s.alive, g.over), (false, false));
    expect(g.relicBag, {Relic.thorns: 1});
    expect(g.useRelic(Relic.thorns, knight), isTrue);
    expect((knight.relics.firstOrNull, g.relicBag[Relic.thorns]), (Relic.thorns, 0));
  });

  test('the troop counter counts living troops by type, in the book\'s order, leaving out types with none', () {
    expect(Game().troopCounts, {'priest': 1});
    final g = bare()..gold = 1000;
    placeNow(g, 'knight', 3, 1);
    placeNow(g, 'soldier', 3, 2);
    placeNow(g, 'knight', 3, 3);
    expect(g.troopCounts, {'soldier': 1, 'knight': 2});
    expect(g.troopCounts.keys.toList(), ['soldier', 'knight']); // troopTypes' order, not placing order
    g.troops.firstWhere((u) => u.type == 'soldier').dying = 0;
    expect(g.troopCounts, {'knight': 2}); // no 'soldier': 0
  });

  test('the troop counter counts a troop still marching in, and never a monster', () {
    final g = bare(Random(1))..gold = 1000;
    g.autoPlace('archer');
    expect(g.troops.single.entered, isFalse);
    expect(g.troopCounts, {'archer': 1});
    g.startWave();
    for (var i = 0; i < 40 && g.enemies.isEmpty; i++) {
      g.tick(0.05);
    }
    expect(g.enemies, isNotEmpty);
    expect(g.troopCounts.values.fold(0, (a, n) => a + n), g.troops.where((u) => u.alive).length);
  });

  test('every troop type has a name in the UI, in the troop types\' order', () {
    expect(troopTypeNames.keys.toList(), troopTypes.keys.toList());
    expect(troopTypeNames.values.every((n) => n.isNotEmpty), isTrue);
  });

  test('a healing necromancer joins from wave 4, a second from wave 6, one more every 5 waves up to 5 (#70)', () {
    expect((necroHealerFrom, twoNecroHealersFrom, necroHealerEvery, necroHealersMax), (4, 6, 5, 5));
    expect([for (var w = 1; w <= 11; w++) necroHealersIn(w)], [0, 0, 0, 1, 1, 2, 2, 2, 2, 2, 3]);
    expect([for (final w in [15, 16, 20, 21, 40, 80]) necroHealersIn(w)], [3, 4, 4, 5, 5, 5]);
  });

  test('healers join after the first (and second) third of a wave, more spread evenly; on a boss wave the last one walks behind the boss', () {
    final all = queues(3, 21);
    List<int> healers(int w) => [for (final (i, m) in all[w - 1].indexed) if (m.$1 == necroHealer) i];
    expect(healers(4), [4]); // 12 ~/ 3
    expect(healers(8), [6, 14]); // 20 ~/ 3, and 2 * 20 ~/ 3 + 1
    expect(all[8].last.$2, Tier.miniBoss); // the mini boss stays last
    final five = all[4], ten = all[9], twenty = all[19];
    expect(healers(5), [five.length - 1]);
    expect(five[five.length - 2].$2, Tier.boss);
    expect(healers(10), [8, ten.length - 1]);
    expect(ten[ten.length - 2].$2, Tier.boss); // the boss, of any type (#58)
    expect(healers(11), [6, 14, 21]); // 26 in quarters: 26 ~/ 4, 2 * 26 ~/ 4 + 1, 3 * 26 ~/ 4 + 2
    expect(healers(20), [11, 23, 35, twenty.length - 1]); // 44 in quarters, and the escort
    expect(twenty[twenty.length - 2].$2, Tier.boss);
    expect(healers(21), [7, 16, 25, 33, 42]); // 46 in sixths
  });

  test('a healer rolls its tier like any monster of the wave, never a mini boss or boss', () {
    final tiers = <Tier>{};
    for (var seed = 0; seed < 20; seed++) {
      final g = bare(Random(seed))..wave = 19;
      g.startWave();
      for (final (_, tier) in g.queue.where((m) => m.$1 == necroHealer)) {
        expect(tier.index, lessThanOrEqualTo(Tier.highElite.index), reason: 'seed $seed');
        tiers.add(tier);
      }
    }
    expect(tiers, containsAll([Tier.normal, Tier.elite]));
  });

  test('a healer\'s stats grow with its tier and the wave like any monster\'s, and its kill pays its gold', () {
    for (final (wave, paid) in [(1, [12, 18, 24]), (4, [13, 20, 27]), (10, [17, 26, 35])]) {
      for (final tier in [Tier.normal, Tier.elite, Tier.highElite]) {
        final s = enemyStats(necroHealer, tier, wave), w = wave - 1;
        expect(s.hp, (70 * tier.hp * (1 + waveHp * w)).round(), reason: '$tier $wave');
        expect(s.dmg, closeTo(8 * tier.dmg * (1 + waveDmg * w), 1e-9), reason: '$tier $wave'); // its heal
        expect(s.rate, closeTo(1.2 / (1 + min(waveRate * w, waveRateMax)), 1e-9), reason: '$tier $wave');
        expect((s.cost, s.heals, s.range, s.mp, s.mpRegen), (paid[tier.index], true, 64.0, 40, 3.2), reason: '$tier $wave');
        final g = bare();
        placeNow(g, 'knight', 2, 3);
        final e = Unit(Side.enemy, necroHealer, s, g.troops.single.pos + const Point(10, 0))
          ..tier = tier
          ..hp = 1
          ..busyUntil = hold;
        g.units.add(e);
        final gold = g.gold;
        g.tick(0.05);
        expect(e.alive, isFalse, reason: '$tier $wave');
        expect(g.gold - gold, paid[tier.index], reason: '$tier $wave');
      }
    }
  });

  test('a kill scores by the monster\'s rank and counts once, and still pays its gold', () {
    expect(killScore, {Tier.normal: 10, Tier.elite: 25, Tier.highElite: 50, Tier.miniBoss: 150, Tier.boss: 500});
    for (final (type, tier) in [('orc', Tier.normal), ('orc', Tier.elite), ('orc', Tier.highElite), ('orc', Tier.miniBoss), (boss, Tier.boss)]) {
      final g = bare();
      placeNow(g, 'knight', 2, 3);
      final s = enemyStats(type, tier, 1);
      final e = Unit(Side.enemy, type, s, g.troops.single.pos + const Point(10, 0))
        ..tier = tier
        ..hp = 1
        ..busyUntil = hold;
      g.units.add(e);
      final gold = g.gold;
      g.tick(0.05);
      expect(e.alive, isFalse, reason: '$tier');
      expect((g.score, g.kills, g.gold - gold), (killScore[tier], 1, s.cost), reason: '$tier');
    }
  });

  test('a raised skeleton scores nothing, like its gold, but counts as a kill', () {
    final g = bare();
    placeNow(g, 'knight', 2, 3);
    final at = g.troops.single.pos + const Point(10, 0);
    g.units.add(Unit(Side.enemy, minion, const Stats(hp: 20, cost: 0, speed: 20, dmg: 5, range: 12, rate: 1), at)
      ..raisedBy = Unit(Side.enemy, boss, bossStats, at + const Point(60, 0))
      ..hp = 1
      ..busyUntil = hold);
    final gold = g.gold;
    g.tick(0.05);
    expect((g.score, g.kills, g.gold - gold), (0, 1, 0));
  });

  test('winning wave n scores 100 × n once, in the tick it is won', () {
    final g = bare()..wave = 4;
    winWave(g);
    expect((g.wave, g.victoryAt, g.score), (5, g.t, 5 * waveScore));
    for (var i = 0; i < 20; i++) {
      g.tick(0.05);
    }
    expect(g.score, 500);
    winWave(g);
    expect(g.score, 500 + 600);
  });

  test('the game\'s end adds nothing to the score: a lost wave ends it only at the last heart (wipe.dart)', () {
    final (g, s) = doomedSoldier();
    g.lives = wipeLives;
    g.tick(0.05);
    expect((s.alive, g.over, g.lives), (false, true, 0));
    expect(g.score, 0);
    g.tick(0.05);
    expect(g.score, 0);
  });

  test('the save keeps the score and the kills; an older save without them starts at 0', () {
    final g = bare()
      ..score = 1234
      ..kills = 56;
    final j = jsonDecode(jsonEncode(g.toJson())) as Map<String, dynamic>;
    final h = Game.fromJson(j);
    expect((h.score, h.kills), (1234, 56));
    final old = Game.fromJson(j
      ..remove('score')
      ..remove('kills'));
    expect((old.score, old.kills), (0, 0));
  });

  test('a score entry survives JSON, its time cut to whole milliseconds in UTC, and can come from a game', () {
    final e = ScoreEntry(name: 'Budi', score: 1250, wave: 12, kills: 80, at: DateTime.utc(2026, 9, 27, 13, 5, 7, 123, 456));
    expect(e.at, DateTime.utc(2026, 9, 27, 13, 5, 7, 123));
    expect(ScoreEntry.fromJson(e.toJson()), e);
    expect(ScoreEntry.fromJson(jsonDecode(jsonEncode(e.toJson())) as Map<String, dynamic>), e);
    final local = DateTime(2026, 9, 27, 20, 30);
    final l = ScoreEntry(name: 'Ani', score: 1, wave: 1, at: local);
    expect((l.at.isUtc, l.at), (true, local.toUtc()));

    final g = bare()
      ..score = 1234
      ..kills = 56
      ..wave = 7;
    final o = ScoreEntry.of(g, 'Budi', e.at);
    expect((o.name, o.score, o.wave, o.kills, o.at), ('Budi', 1234, 7, 56, e.at));
  });

  test('a player\'s name loses control characters and outer spaces, is at most 12 letters, and is never empty', () {
    expect(ScoreEntry.cleanName('  Budi  '), 'Budi');
    expect(ScoreEntry.cleanName('A\u0000B\u001F\u007F'), 'AB');
    expect(ScoreEntry.cleanName(''), 'Player');
    expect(ScoreEntry.cleanName('   '), 'Player');
    expect(ScoreEntry.cleanName('Abcdefghijklmnopqrst'), 'Abcdefghijkl');
    expect(ScoreEntry(name: '  Ani\u0007 ', score: 1, wave: 1).name, 'Ani');
  });

  test('the board ranks the higher score first, and on a tie the earlier game', () {
    ScoreEntry at(int score, int minute) => ScoreEntry(name: 'P$minute', score: score, wave: 1, at: DateTime.utc(2026, 9, 27, 12, minute));
    final (a, b, c) = (at(100, 2), at(200, 3), at(100, 1));
    expect([a, b, c]..sort(ScoreEntry.byRank), [b, c, a]);
  });

  test('a list of entries skips the broken ones; anything but a list is refused', () {
    final a = ScoreEntry(name: 'A', score: 10, wave: 1), b = ScoreEntry(name: 'B', score: 20, wave: 2);
    expect(entriesFromJson([a.toJson(), {'name': 'x'}, 5, 'junk', b.toJson()]), [a, b]);
    expect(entriesFromJson([]), isEmpty);
    expect(() => entriesFromJson({'scores': []}), throwsFormatException);
    expect(() => entriesFromJson(null), throwsFormatException);
  });

  /// A new folder for one test's files, deleted after it.
  Directory tempDir() {
    final d = Directory.systemTemp.createTempSync('td_scores');
    addTearDown(() => d.deleteSync(recursive: true));
    return d;
  }

  ScoreEntry entry(String name, int score, [int minute = 0]) =>
      ScoreEntry(name: name, score: score, wave: score ~/ 100, at: DateTime.utc(2026, 9, 27, 12, minute));

  test('the scores on this device come back best first, as many as asked', () async {
    final repo = LocalScoreRepository(File('${tempDir().path}/scores.json'));
    final (a, b, c) = (entry('A', 300, 1), entry('B', 900, 2), entry('C', 500, 3));
    for (final e in [a, b, c]) {
      await repo.submit(e);
    }
    expect(await repo.top(), [b, c, a]);
    expect(await repo.top(limit: 2), [b, c]);
  });

  test('the file on this device keeps only the best ones', () async {
    final repo = LocalScoreRepository(File('${tempDir().path}/scores.json'), 3);
    final all = [for (final (i, s) in [400, 100, 900, 300, 700].indexed) entry('P$i', s, i)];
    for (final e in all) {
      await repo.submit(e);
    }
    final kept = entriesFromJson(jsonDecode(repo.file.readAsStringSync()));
    expect(kept.map((e) => e.score), [900, 700, 400]);
  });

  test('a missing or broken scores file is an empty board, and the next score replaces a broken one', () async {
    final dir = tempDir();
    expect(await LocalScoreRepository(File('${dir.path}/none.json')).top(), isEmpty);
    final file = File('${dir.path}/scores.json')..writeAsStringSync('{not json');
    final repo = LocalScoreRepository(file);
    expect(await repo.top(), isEmpty);
    final e = entry('A', 300);
    await repo.submit(e);
    expect(await repo.top(), [e]);
  });

  /// A server backed by this device, with a fake server, the local file and the outbox in a temp folder.
  (ServerScoreRepository, _FakeServer) backed() {
    final dir = tempDir(), fake = _FakeServer();
    return (ServerScoreRepository(fake, LocalScoreRepository(File('${dir.path}/scores.json')), File('${dir.path}/outbox.json')), fake);
  }

  List<ScoreEntry> waiting(ServerScoreRepository repo) =>
      repo.outbox.existsSync() ? entriesFromJson(jsonDecode(repo.outbox.readAsStringSync())) : [];

  test('with the server down a score is kept on this device and waits in the outbox, without an error', () async {
    final (repo, fake) = backed();
    fake.down = true;
    final e = entry('A', 300);
    await repo.submit(e);
    expect(repo.offline, isTrue);
    expect(await repo.local.top(), [e]);
    expect(waiting(repo), [e]);
    expect(fake.got, isEmpty);
  });

  test('when the server is back the outbox goes first, oldest first, then the new score', () async {
    final (repo, fake) = backed();
    fake.down = true;
    final (a, b, c) = (entry('A', 900, 1), entry('B', 300, 2), entry('C', 500, 3));
    await repo.submit(a);
    await repo.submit(b);
    fake.down = false;
    await repo.submit(c);
    expect(fake.got, [a, b, c]);
    expect(waiting(repo), isEmpty);
    expect(repo.offline, isFalse);
    expect(await repo.local.top(), [a, c, b]);
  });

  test('the board comes from the server, or from this device while the server is down', () async {
    final (repo, fake) = backed();
    fake.down = true;
    final mine = entry('A', 300);
    await repo.submit(mine);
    expect(await repo.top(), [mine]);
    expect(repo.offline, isTrue);
    fake
      ..down = false
      ..board = [entry('X', 5000), entry('Y', 4000)];
    expect(await repo.top(limit: 1), [fake.board.first]);
    expect(repo.offline, isFalse);
    expect(fake.got, [mine]); // the outbox went out first
  });

  test('sending the outbox stops at the first score the server refuses, which waits with the ones after it', () async {
    final (repo, fake) = backed();
    fake.down = true;
    final (a, b, c) = (entry('A', 100, 1), entry('B', 200, 2), entry('C', 300, 3));
    for (final e in [a, b, c]) {
      await repo.submit(e);
    }
    fake
      ..down = false
      ..refuse = {b};
    await repo.top();
    expect(repo.offline, isTrue);
    expect(fake.got, [a]);
    expect(waiting(repo), [b, c]);
  });

  /// A local HTTP server answering every request with [status] and [body] (null: none; [hang]: never), and
  /// what it was sent: (method, path with query, content type, body).
  Future<(HttpScoreRepository, List<(String, String, String?, String)>, void Function(int, [String?]))> http(
      {bool hang = false, Duration timeout = const Duration(seconds: 5)}) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    final got = <(String, String, String?, String)>[];
    var status = 200;
    String? body;
    server.listen((req) async {
      got.add((req.method, req.uri.toString(), req.headers.contentType?.mimeType, await utf8.decoder.bind(req).join()));
      if (hang) return;
      req.response.statusCode = status;
      if (body != null) req.response.write(body);
      await req.response.close();
    });
    return (
      HttpScoreRepository('http://127.0.0.1:${server.port}/api/', timeout: timeout),
      got,
      (int s, [String? b]) {
        status = s;
        body = b;
      },
    );
  }

  test('a score is posted to the server as JSON, and a 201 or a 204 takes it', () async {
    final (repo, got, answer) = await http();
    expect(repo.baseUrl, endsWith('/api'));
    final e = entry('Budi', 1250);
    for (final status in [201, 204]) {
      answer(status);
      await repo.submit(e);
    }
    expect(got.length, 2);
    for (final (method, path, type, body) in got) {
      expect((method, path, type), ('POST', '/api/scores', 'application/json'));
      expect(jsonDecode(body), e.toJson());
    }
  });

  test('the server\'s board is asked for as many as needed, and comes back ranked and cut', () async {
    final (repo, got, answer) = await http();
    final all = [entry('A', 300, 1), entry('B', 900, 2), entry('C', 500, 3), entry('D', 700, 4), entry('E', 100, 5)];
    answer(200, jsonEncode([for (final e in all) e.toJson()]));
    expect(await repo.top(limit: 3), [all[1], all[3], all[2]]);
    expect((got.single.$1, got.single.$2), ('GET', '/api/scores?limit=3'));
  });

  test('a server that refuses or answers wrong gives a score server error', () async {
    final (repo, _, answer) = await http();
    final e = entry('A', 300);
    for (final status in [400, 500]) {
      answer(status);
      await expectLater(repo.submit(e), throwsA(isA<ScoreServerException>()), reason: 'POST $status');
    }
    for (final (status, body) in [(404, '[]'), (201, '[]'), (200, '{"scores": []}'), (200, '[not json')]) {
      answer(status, body);
      await expectLater(repo.top(), throwsA(isA<ScoreServerException>()), reason: 'GET $status $body');
    }
  });

  test('a server that never answers gives a score server error after the timeout', () async {
    final (repo, _, _) = await http(hang: true, timeout: const Duration(milliseconds: 200));
    await expectLater(repo.submit(entry('A', 300)), throwsA(isA<ScoreServerException>()));
    await expectLater(repo.top(), throwsA(isA<ScoreServerException>()));
  });

  test('the player\'s name is saved cleaned; a missing or broken file has none', () {
    final dir = tempDir(), f = File('${dir.path}/player.json');
    expect(loadPlayerName(f), isNull);
    savePlayerName('  Budi ', f);
    expect(loadPlayerName(f), 'Budi');
    f.writeAsStringSync('{"name": 5');
    expect(loadPlayerName(f), isNull);
  });

  test('every troop type has an awakening recipe of 8 to 12 items; nothing else has one', () {
    expect(awakenRecipe.keys, unorderedEquals(troopTypes.keys));
    for (final MapEntry(key: type, value: recipe) in awakenRecipe.entries) {
      expect(recipe.values.fold(0, (a, b) => a + b), inInclusiveRange(8, 12), reason: type);
      expect(recipe.values.every((n) => n >= 1), isTrue, reason: type);
    }
    expect(awakenRecipe['knight'], {Item.sword: 3, Item.shield: 3, Item.boots: 2, Item.gloves: 2});
    expect(awakenRecipe['knight_templar'], {Item.sword: 2, Item.shield: 2, Item.boots: 2, Item.bow: 1, Item.potion: 3});
    expect(awakenRecipe['lancer']!.keys, isNot(contains(Item.bow)));
    final g = bare();
    for (final type in ['slime', 'dragon']) {
      expect(g.recipeOf(type), isEmpty, reason: type);
      expect((g.awakenLevel(type), g.capOf(type, Item.sword), g.canUse(Item.sword, type)), (0, 0, false), reason: type);
    }
  });

  test('before it awakens a type takes no item its recipe leaves out', () {
    final g = bare();
    placeNow(g, 'knight', 2, 3);
    g.inventory.addAll({Item.bow: 1, Item.potion: 1});
    for (final item in [Item.bow, Item.potion]) {
      expect(g.capOf('knight', item), 0, reason: item.name);
      g.sfx.clear();
      expect(g.useItem(item, 'knight'), isFalse, reason: item.name);
      expect(g.sfx, [Sfx.error], reason: item.name);
    }
    expect(g.inventory, {Item.bow: 1, Item.potion: 1});
    expect(g.upgrades, isEmpty);
    expect(g.capOf('knight', Item.sword), 3);
  });

  test('the item that completes a recipe awakens the type: its troops burst in the new level\'s colour', () {
    final g = bare()..gold = 1000;
    placeNow(g, 'knight', 2, 3);
    placeNow(g, 'knight', 2, 4);
    placeNow(g, 'soldier', 2, 5);
    final knights = g.troops.where((u) => u.type == 'knight').toList(), soldier = g.troops.last;
    final recipe = awakenItems('knight', 1), n = recipe.length;
    expect(recipe.last, Item.amulet); // its grade I set: the recipe's kinds, then its own new kind
    for (final item in [...recipe, ...awakenItems('soldier', 1)]) {
      g.inventory[item] = (g.inventory[item] ?? 0) + 1;
    }
    for (final item in recipe.take(n - 2)) {
      expect(g.useItem(item, 'knight'), isTrue);
    }
    g
      ..impacts.clear()
      ..sfx.clear();
    expect(g.useItem(recipe[n - 2], 'knight'), isTrue); // one short
    expect(g.awakenLevel('knight'), 0);
    expect(g.impacts, [for (final k in knights) (k.pos, 'upgrade')]);
    expect(g.sfx, [Sfx.magic]);
    g
      ..impacts.clear()
      ..sfx.clear();
    expect(g.useItem(recipe.last, 'knight'), isTrue); // the last
    expect(g.awakenLevel('knight'), 1);
    expect(g.impacts, [for (final k in knights) (k.pos, 'upgrade_awake1')]);
    expect(g.sfx, [Sfx.magic, Sfx.clear]);

    // A potion that completes a recipe bursts as an awakening, not a heal.
    final soldierRecipe = [...awakenItems('soldier', 1).where((i) => i != Item.potion), Item.potion];
    for (final item in soldierRecipe.take(soldierRecipe.length - 1)) {
      expect(g.useItem(item, 'soldier'), isTrue);
    }
    g.impacts.clear();
    expect(g.useItem(Item.potion, 'soldier'), isTrue);
    expect(g.impacts, [(soldier.pos, 'upgrade_awake1')]);
  });

  test('the awakening level comes from the items a type holds, so the save keeps it and the price', () {
    final g = bare()..upgrades['knight'] = awakenItems('knight', 1);
    expect(g.awakenLevel('knight'), 1);
    g.upgrades['knight'] = awakenItems('knight', 1)..removeLast();
    expect(g.awakenLevel('knight'), 0);
    g.upgrades['knight'] = awakenItems('knight', 2);
    final h = Game.fromJson(jsonDecode(jsonEncode(g.toJson())) as Map<String, dynamic>);
    expect((h.awakenLevel('knight'), h.priceOf('knight')), (2, g.priceOf('knight')));
  });

  test('every awakening level doubles a type\'s price (triples until decisions-log 318), and buying charges it', () {
    final g = bare();
    // (50 + 5 a held item) x2 a level: its grade sets hold 11, 11 and 9 items (decisions-log 249).
    for (final (n, price) in [(1, 210), (2, 640), (3, 1640)]) {
      g.upgrades['knight'] = awakenItems('knight', n);
      expect(g.priceOf('knight'), price, reason: '$n');
    }
    g.upgrades['soldier'] = awakenItems('soldier', 1);
    expect(g.priceOf('soldier'), 114); // (30 + 9 x 3) x 2
    g.gold = 113;
    expect((g.autoPlace('soldier'), g.place('soldier', 2, 3)), (false, false));
    g.gold = 114;
    expect(g.place('soldier', 2, 3), isTrue);
    expect(g.gold, 0);
    g.gold = 114;
    expect(g.autoPlace('soldier'), isTrue);
    expect(g.gold, 0);
  });

  test('an awakened troop hits and heals in its level\'s colour; monsters and plain troops as before', () {
    expect((awakeFx('x', 0), awakeFx('x', 2)), ('x', 'x_awake2'));
    Unit dummy(Game g, Point<double> at) {
      final e = Unit(Side.enemy, 'slime', enemyTypes['slime']!, at)
        ..hp = 1000
        ..busyUntil = hold;
      g.units.add(e);
      return e;
    }

    final k = bare()
      ..gold = 100000
      ..upgrades['knight'] = awakenItems('knight', 1);
    placeNow(k, 'knight', 2, 3);
    dummy(k, k.troops.single.pos + const Point(10, 0));
    k.tick(0.05);
    expect(k.impacts.map((i) => i.$2), ['hit_knight_awake1']);

    final a = bare()
      ..gold = 100000
      ..upgrades['archer'] = awakenItems('archer', 2);
    placeNow(a, 'archer', 1, 3);
    final target = dummy(a, a.troops.single.pos + const Point(40, 0));
    a.tick(0.05);
    expect(a.shots.length, 1); // flying, not landed
    expect(a.impacts, isEmpty);
    for (var i = 0; i < 20 && a.impacts.isEmpty; i++) {
      a.tick(0.05);
    }
    expect(a.impacts.first, (target.pos, 'hit_archer_awake2'));

    final s = bare();
    placeNow(s, 'soldier', 2, 3);
    s.units.add(Unit(Side.enemy, 'orc', enemyTypes['orc']!, s.troops.single.pos + const Point(10, 0))..hp = 1000);
    s.tick(0.05);
    expect(s.impacts.map((i) => i.$2), containsAll(['hit_soldier', 'hit_orc']));

    final p = bare()
      ..gold = 100000
      ..upgrades['priest'] = awakenItems('priest', 1);
    placeNow(p, 'priest', 0, 3);
    placeNow(p, 'knight', 2, 3);
    final knight = p.troops.firstWhere((u) => u.type == 'knight')..hp = 50;
    dummy(p, const Point(380, 20)); // mid-wave
    for (var i = 0; i < 40 && p.impacts.isEmpty; i++) {
      p.tick(0.05);
    }
    expect(p.impacts.first.$2, 'heal_awake1');
    p.units.removeWhere((u) => u.side == Side.enemy);
    knight.hp = 50;
    winWave(p);
    p.impacts.clear();
    for (var i = 0; i < 400 && p.impacts.isEmpty; i++) {
      p.tick(0.05);
    }
    expect((p.waveActive, p.impacts.first.$2), (false, 'heal_awake1')); // after the win
  });

  test('a bow never takes a melee fighter past 27.2 reach; long range have no ceiling', () {
    expect(meleeMaxRange, 27.2);
    expect({for (final MapEntry(key: t, value: s) in troopTypes.entries) t: s.melee}, {
      'soldier': true,
      'knight': true,
      'swordsman': true,
      'archer': false,
      'lancer': true,
      'priest': false,
      'armored_axeman': true,
      'wizard': false,
      'knight_templar': true,
    });
    var lancer = troopTypes['lancer']!;
    final reach = [for (var n = 0; n < 3; n++) (lancer = lancer.upgraded(Item.bow)).range];
    expect(reach[0], closeTo(26.4, 1e-9));
    expect(reach.skip(1), [27.2, 27.2]);
    var archer = troopTypes['archer']!;
    for (var n = 1; n <= 5; n++) {
      archer = archer.upgraded(Item.bow);
      expect(archer.range, closeTo(64 * pow(1.2, n), 1e-9), reason: '$n');
    }
    expect(const Stats(hp: 1, cost: 1, speed: 1, dmg: 1, range: 30, rate: 1).upgraded(Item.bow).range, 30);

    final g = bare()..gold = 1000;
    g.upgrades['knight'] = List.filled(6, Item.bow); // an old save
    expect(g.statsOf('knight').range, meleeMaxRange);
    placeNow(g, 'knight', 2, 3);
    final h = Game.fromJson(jsonDecode(jsonEncode(g.toJson())) as Map<String, dynamic>);
    expect((g.troops.single.stats.range, h.troops.single.stats.range), (meleeMaxRange, meleeMaxRange));
  });

  test('an item\'s tooltip over a troop row tells how many its type holds of its cap', () {
    final g = bare();
    expect(g.itemInfo(Item.sword).$2, ['+25% attack', 'For a whole type, up to a cap', 'Cost: troop price +10%', tapLine, 'In bag: 0']);
    expect(g.itemInfo(Item.sword, 'knight').$2, contains('Now: 0/3 on this type'));
    g.upgrades['knight'] = [Item.sword, Item.sword];
    expect(g.itemInfo(Item.sword, 'knight').$2, contains('Now: 2/3 on this type, +56%'));
    expect(g.itemInfo(Item.bow, 'knight').$2, contains("This type can't take it"));
    g.upgrades['knight'] = awakenItems('knight', 1);
    expect(g.itemInfo(Item.sword, 'knight').$2, contains('Cost: troop price +10'));
  });

  test('a blow loses the target\'s defence, but always does a tenth of itself and at least 1', () {
    expect([hitTaken(10, 0), hitTaken(10, 4), hitTaken(10, 9.5), hitTaken(50, 48), hitTaken(3, 5)], [10, 6, 1, 5, 1]);
    for (final guard in [false, true]) {
      final g = bare()..upgrades['knight'] = [Item.shield, Item.shield];
      placeNow(g, 'knight', 2, 3);
      final knight = g.troops.single..relics.addAll([if (guard) Relic.guard]);
      expect(knight.stats.def, 5);
      g.units.add(Unit(Side.enemy, 'orc', enemyTypes['orc']!, knight.pos + const Point(10, 0))..hp = 1000);
      g.tick(0.05);
      expect(knight.hp, 140 - (guard ? 3.75 : 5), reason: 'guard $guard');
    }
  });

  test('monsters take a blow whole, and a cleave loses each target\'s own defence', () {
    final g = bare();
    placeNow(g, 'knight', 2, 3);
    final at = g.troops.single.pos + const Point(10, 0);
    final slime = Unit(Side.enemy, 'slime', enemyTypes['slime']!, at)
      ..hp = 1000
      ..busyUntil = hold;
    g.units.add(slime);
    g.tick(0.05);
    expect(slime.hp, 1000 - 20);

    final h = bare();
    placeNow(h, 'armored_axeman', 2, 3);
    final foe = h.troops.single.pos + const Point(10, 0);
    Unit orc(double def) => Unit(Side.enemy, 'orc', Stats(hp: 1000, cost: 6, speed: 18, dmg: 10, range: 12, rate: 1, def: def), foe)
      ..busyUntil = hold;
    final (plain, armoured) = (orc(0), orc(5));
    h.units.addAll([plain, armoured]);
    h.tick(0.05);
    final d = troopTypes['armored_axeman']!.dmg * (1 + heavyBuff); // a heavy's blow (#57)
    expect((plain.hp, armoured.hp), (1000 - d, 1000 - (d - 5)));
  });

  test('a shield adds defence, not HP: troops on the field keep their HP', () {
    final g = bare();
    placeNow(g, 'knight', 2, 3);
    g.inventory[Item.shield] = 3;
    for (var i = 0; i < 3; i++) {
      expect(g.useItem(Item.shield, 'knight'), isTrue);
    }
    final s = g.statsOf('knight'), u = g.troops.single;
    expect((s.hp, s.def), (140, 7.5));
    expect((u.maxHp, u.hp, u.stats.def), (140, 140.0, 7.5));
  });

  test('HP and MP rise only by awakening, a quarter of the base a level; no items is the base itself', () {
    final g = bare();
    for (final type in troopTypes.keys) {
      if (heavyTypes.contains(type)) continue; // raised by heavyBuff (their own test)
      expect(identical(g.statsOf(type), troopTypes[type]), isTrue, reason: type);
    }
    // The archer: no kind of its grade sets raises HP (the knight's amulet would).
    final k = troopTypes['archer']!;
    for (final (level, hp, mp) in [(1, 75, 38), (2, 90, 45), (3, 105, 53)]) {
      g.upgrades['archer'] = awakenItems('archer', level);
      final s = g.statsOf('archer'), items = g.upgrades['archer']!.fold(k, (st, i) => st.upgraded(i, g.itemK(i)));
      expect((g.awakenLevel('archer'), s.hp, s.mp), (level, hp, mp));
      expect(s.mpRegen, closeTo(1.5 * (1 + 0.25 * level), 1e-9));
      expect((s.dmg, s.def, s.speed, s.range, s.rate, s.regen), (items.dmg, items.def, items.speed, items.range, items.rate, items.regen));
    }
  });

  test('the heavies fight with heavyBuff more HP, attack and defence than their table, with items and awakening too', () {
    expect(heavyTypes, {'armored_axeman', 'knight_templar'});
    expect(heavyBuff, inInclusiveRange(0.2, 0.25)); // the owner's pick: about 20-25%
    const k = 1 + heavyBuff;
    final g = bare()..gold = 10000;
    for (final type in heavyTypes) {
      final t = troopTypes[type]!, s = g.statsOf(type);
      expect((s.hp, s.dmg, s.def), ((t.hp * k).round(), t.dmg * k, 0.0), reason: type); // no shields yet: none to raise
      expect((s.speed, s.range, s.rate, s.splash, s.cost, s.mp, s.mpRegen), (t.speed, t.range, t.rate, t.splash, t.cost, t.mp, t.mpRegen),
          reason: type); // the rest as it is
    }
    final t = troopTypes['knight_templar']!;
    g.upgrades['knight_templar'] = [Item.shield, Item.shield, Item.sword];
    final s = g.statsOf('knight_templar');
    expect((s.def, s.dmg), (2 * shieldDef * k, t.dmg * swordDmg * k));
    g.upgrades['knight_templar'] = awakenItems('knight_templar', 1); // awakened: level 1
    expect(g.statsOf('knight_templar').hp, ((t.hp * (1 + awakenHp)).round() * k).round());
    expect(placeNow(g, 'armored_axeman', 2, 3), isTrue);
    expect(g.troops.single.maxHp, (troopTypes['armored_axeman']!.hp * k).round()); // a troop on the field too
  });

  test('the item that awakens a type gives its living troops the HP and MP it adds', () {
    final g = bare(); // the archer: no item of its grade I set raises HP (the knight's amulet would)
    placeNow(g, 'archer', 1, 3);
    placeNow(g, 'archer', 1, 4);
    final [hurt, whole] = g.troops.toList();
    hurt
      ..hp = 40
      ..mp = 10;
    final recipe = awakenItems('archer', 1);
    for (final item in recipe) {
      g.inventory[item] = (g.inventory[item] ?? 0) + 1;
    }
    for (final item in recipe) {
      g.useItem(item, 'archer');
    }
    expect(g.awakenLevel('archer'), 1);
    expect((hurt.maxHp, hurt.hp, hurt.mp), (75, 55.0, 18.0)); // +15 HP, +8 MP (30 x 1.25 = 37.5, 38)
    expect((whole.maxHp, whole.hp, whole.mp), (75, 75.0, 38.0));
  });

  test('every troop type has its MP, and starts full; monsters have no defence, and only necromancers MP', () {
    expect({for (final MapEntry(key: t, value: s) in troopTypes.entries) t: (s.mp, s.mpRegen)}, {
      'soldier': (20, 1.0),
      'knight': (20, 1.0),
      'swordsman': (30, 1.5),
      'archer': (30, 1.5),
      'lancer': (20, 1.0),
      'priest': (60, 3.0),
      'armored_axeman': (20, 1.0),
      'wizard': (80, 4.0),
      'knight_templar': (40, 2.0),
    });
    final g = bare()..gold = 1000;
    placeNow(g, 'wizard', 1, 3);
    expect(g.troops.single.mp, 80);
    for (final type in enemyTypes.keys) {
      for (final tier in [Tier.normal, Tier.elite, Tier.highElite, Tier.miniBoss]) {
        final s = enemyStats(type, tier, 10);
        expect((s.def, s.mp, s.mpRegen), (0.0, 0, 0.0), reason: '$type $tier');
      }
    }
    expect((enemyStats(boss, Tier.boss, 10).def, enemyStats(necroHealer, Tier.normal, 10).def), (0.0, 0.0));
  });

  test('a troop saved with more HP than its type now has loads at its new most; one with less keeps it', () {
    final g = bare()..upgrades['knight'] = [Item.shield, Item.shield, Item.shield];
    placeNow(g, 'knight', 2, 3);
    for (final (saved, loaded) in [(300.0, 140.0), (100.0, 100.0)]) {
      final j = jsonDecode(jsonEncode(g.toJson())) as Map<String, dynamic>;
      ((j['troops'] as List).single as Map<String, dynamic>)['hp'] = saved;
      final u = Game.fromJson(j).troops.single;
      expect((u.maxHp, u.hp, u.stats.def), (140, loaded, 7.5), reason: '$saved');
    }
  });

  test('a potion also makes a healer\'s heals 3 HP bigger; others only regain HP', () {
    final g = bare()
      ..gold = 1000
      ..upgrades['priest'] = [Item.potion, Item.potion]
      ..upgrades['soldier'] = [Item.potion]
      ..keepSupports = false; // the heal's size alone (with it, far behind the knight walking on, it walks up first: 324)
    expect((g.statsOf('priest').dmg, g.statsOf('priest').regen), (18.0, 10.0));
    expect((g.statsOf('soldier').dmg, g.statsOf('soldier').regen), (10.0, 5.0));

    placeNow(g, 'priest', 0, 3);
    placeNow(g, 'knight', 2, 3);
    final knight = g.troops.firstWhere((u) => u.type == 'knight');
    g.units.add(Unit(Side.enemy, 'slime', enemyTypes['slime']!, const Point(380, 20))..busyUntil = hold); // mid-wave
    for (final (hp, healed) in [(50.0, 68.0), (135.0, 140.0)]) {
      knight.hp = hp;
      g.impacts.clear();
      for (var i = 0; i < 60 && g.impacts.isEmpty; i++) {
        g.tick(0.05);
      }
      expect((g.impacts.first.$2, knight.hp), ('heal', healed), reason: '$hp');
    }
  });

  test('a potion\'s tooltip tells a healer\'s bigger heals', () {
    final g = bare()..upgrades['priest'] = [Item.potion, Item.potion];
    expect(g.itemInfo(Item.potion).$2, contains('Healers: +3 HP per heal'));
    expect(g.itemInfo(Item.potion, 'priest').$2, containsAll(['+3 HP per heal', 'Now: 2/2 on this type, +10 HP/s, +6 heal']));
    expect(g.itemInfo(Item.potion, 'soldier').$2.where((l) => l.toLowerCase().contains('heal')), isEmpty);
  });

  test('the book tells defence, HP, MP and the awakening level with what the next one needs', () {
    final g = bare();
    expect(g.itemInfo(Item.shield).$2.first, '-2.5 damage taken per hit');
    g.upgrades['knight'] = [Item.shield, Item.shield];
    expect(g.itemInfo(Item.shield, 'knight').$2, contains('Now: 2/3 on this type, -5 per hit'));
    final (hp, hpLines) = g.hpInfo('knight');
    expect(hp, 'HP');
    expect(hpLines, ['Max HP 140 (base 140)', 'Only Awaken raises it', 'Each level: +25% of base']);
    expect(g.mpInfo('wizard').$2.first, 'Max MP 80, regen 4/s');
    expect([for (var l = 0; l <= 3; l++) awakenName(l)], ['Not awakened', '${Words.awaken} 1', '${Words.awaken} 2', '${Words.awaken} 3']); // 5 is the top (#92)
    g.upgrades.clear();
    final (level, needs) = g.awakenInfo('knight');
    expect(level, awakenName(0));
    // After the awakening skill's lines (#88, awaken_skills_test.dart), what the next awakening needs.
    expect(needs.skipWhile((l) => l.$2 != '${awakenName(1)} needs:'), [
      (null, '${awakenName(1)} needs:'),
      (Item.sword, '${itemNames[Item.sword]} 0/3'),
      (Item.shield, '${itemNames[Item.shield]} 0/3'),
      (Item.boots, '${itemNames[Item.boots]} 0/2'),
      (Item.gloves, '${itemNames[Item.gloves]} 0/2'),
      (Item.amulet, '${itemNames[Item.amulet]} 0/1'), // its own new kind (decisions-log 249)
    ]);
    g.upgrades['knight'] = awakenItems('knight', 3);
    final (maxed, none) = g.awakenInfo('knight');
    expect((maxed, none.last), (awakenName(3), (null, '${awakenName(4)}: buy on the ${Words.army} page'))); // no more items: gold buys the rest (#92)
  });

  test('a necromancer raises one tier below its own, and higher tiers only from later bosses\' waves', () {
    expect([for (final w in [5, 9, 10, 15, 20, 30]) summonCeiling(Tier.boss, w)],
        [Tier.normal, Tier.normal, Tier.elite, Tier.highElite, Tier.miniBoss, Tier.miniBoss]);
    expect([for (final w in [8, 13, 18, 25]) summonCeiling(Tier.miniBoss, w)], [Tier.normal, Tier.elite, Tier.highElite, Tier.highElite]);
    for (final w in [1, 10, 30]) {
      expect((summonCeiling(Tier.normal, w), summonCeiling(Tier.elite, w)), (Tier.normal, Tier.normal), reason: '$w');
    }
  });

  test('a summoner comes on with a quarter of its MP, every other monster with all of it', () {
    final g = bare()..wave = 5;
    Unit make(String type, Tier tier) => g.monster(type, tier, const Point(250, 60));
    final (b, m, h) = (make(boss, Tier.boss), make(boss, Tier.miniBoss), make(necroHealer, Tier.normal));
    expect((b.tier, b.stats.mp, b.stats.mpRegen, b.mp), (Tier.boss, 240, 7.0, 60.0));
    expect((m.tier, m.stats.mp, m.stats.mpRegen, m.mp), (Tier.miniBoss, 120, 4.0, 30.0));
    expect((h.stats.mp, h.stats.mpRegen, h.mp), (40, 3.2, 40.0));
    for (final type in enemyTypes.keys) {
      final u = make(type, Tier.elite);
      expect((u.stats.mp, u.stats.mpRegen, u.mp), (0, 0.0, 0.0), reason: type);
    }
    // its gold: 40 × 3, grown 4.5% a wave; its HP any mini boss's (#89): the wave's strongest type's × 6
    for (final (w, paid, base) in [(1, 120, 30 * 6), (8, 163, 40 * 6), (20, 276, 220 * 6)]) {
      final s = enemyStats(boss, Tier.miniBoss, w);
      final (bHp, _, bDmg) = bossBuff(Tier.miniBoss, w);
      expect((s.hp, s.cost), ((base * bHp * waveGrowth(w, waveHp, waveHpLate)).round(), paid), reason: '$w');
      expect(s.dmg, closeTo(30 * 0.6 * bDmg * waveGrowth(w, waveDmg, waveDmgLate), 1e-9), reason: '$w');
    }
  });

  test('the necromancer mini boss has the HP of any mini boss, its slot reference\'s × 6 (#89), and keeps its '
      'damage, MP and gold', () {
    for (final (w, strongest, base) in [(9, 'skeleton_archer', 240), (12, 'armored_skeleton', 900), (21, 'greatsword_skeleton', 1320),
      (22, 'werebear', 1920), (48, 'werebear', 1920)]) {
      final necro = enemyStats(boss, Tier.miniBoss, w), other = enemyStats(strongest, Tier.miniBoss, w);
      final (bHp, bMp, bDmg) = bossBuff(Tier.miniBoss, w);
      final hp = (base * bHp * waveGrowth(w, waveHp, waveHpLate)).round();
      expect((poolOf(w).last, necro.hp, other.hp), (strongest, hp, hp), reason: '$w');
      expect(necro.dmg, closeTo(bossStats.dmg * necroMiniDmg * bDmg * waveGrowth(w, waveDmg, waveDmgLate), 1e-9), reason: '$w');
      expect((necro.mp, necro.mpRegen, necro.cost), ((120 * bMp).round(), 4.0, killGold(bossStats.cost, Tier.miniBoss, w)),
          reason: '$w');
    }
    // The owner's wave-48 mini boss: ×19 on its bar before (240 base), now ×126 like the werebear's (×145 while the
    // boss buff was full from wave 50, before decisions-log 318).
    final hp48 = enemyStats(boss, Tier.miniBoss, 48).hp;
    expect((hp48, bossLayers(hp48.toDouble(), hp48).left), (125170, 126));
    // The boss necromancer is untouched.
    final (bHp, _, _) = bossBuff(Tier.boss, 48);
    expect(enemyStats(boss, Tier.boss, 48).hp, (bossStats.hp * bHp * waveGrowth(48, waveHp, waveHpLate)).round());
  });

  test('a necromancer\'s MP comes back every tick up to its most, even while it casts', () {
    final g = bare()..wave = 5;
    final u = g.monster(boss, Tier.boss, const Point(250, 60))
      ..mp = 0
      ..busyUntil = hold; // casting
    g.units.add(u);
    g.tick(0.5);
    expect(u.mp, closeTo(3.5, 1e-9));
    u.mp = 239;
    g.tick(0.5);
    expect(u.mp, 240);
  });

  test('the boss buff (#66): a wave\'s boss and mini boss get their HP, MP pool and damage multiplied, not their MP regen or gold; '
      'it ramps in from wave 5 to 60 (50 until decisions-log 318); raised minions none', () {
    expect((bossHpK, bossMpK, bossDmgK, miniHpK, miniMpK, miniDmgK), (10.0, 5.0, 3.0, 6.0, 3.0, 1.5)); // #75: ×2 → ×1.5
    expect((bossBuffFrom, bossBuffFull), (5, 60));
    for (final tier in [Tier.normal, Tier.elite, Tier.highElite]) {
      expect(bossBuff(tier, 30), (1.0, 1.0, 1.0), reason: '$tier');
    }
    for (final w in [0, 1, 5]) {
      expect((bossBuff(Tier.boss, w), bossBuff(Tier.miniBoss, w)), ((1.0, 1.0, 1.0), (1.0, 1.0, 1.0)), reason: '$w'); // none yet
    }
    for (final w in [60, 70, 80]) {
      expect((bossBuff(Tier.boss, w), bossBuff(Tier.miniBoss, w)), ((10.0, 5.0, 3.0), (6.0, 3.0, 1.5)), reason: '$w'); // all of it
    }
    final (bh, bm, bd) = bossBuff(Tier.boss, 14); // 9 waves of 55 in
    final (mh, mm, md) = bossBuff(Tier.miniBoss, 14);
    const f = 9 / 55;
    for (final (got, want) in [(bh, 1 + 9 * f), (bm, 1 + 4 * f), (bd, 1 + 2 * f), (mh, 1 + 5 * f), (mm, 1 + 2 * f), (md, 1 + 0.5 * f)]) {
      expect(got, closeTo(want, 1e-9));
    }
    final bear = enemyTypes['werebear']!;
    for (final wave in [5, 14, 50]) {
      final hp = waveGrowth(wave, waveHp, waveHpLate), dmg = waveGrowth(wave, waveDmg, waveDmgLate);
      final (bHp, bMp, bDmg) = bossBuff(Tier.boss, wave);
      final (mHp, mMp, mDmg) = bossBuff(Tier.miniBoss, wave);
      final b = enemyStats(boss, Tier.boss, wave), n = enemyStats(boss, Tier.miniBoss, wave), m = enemyStats('werebear', Tier.miniBoss, wave);
      expect((b.hp, n.hp, m.hp), ((bossStats.hp * bHp * hp).round(),
          (enemyTypes[poolOf(wave).last]!.hp * Tier.miniBoss.hp * mHp * hp).round(), (bear.hp * Tier.miniBoss.hp * mHp * hp).round()),
          reason: '$wave');
      expect(b.dmg, closeTo(bossStats.dmg * bDmg * dmg, 1e-9), reason: '$wave');
      expect(m.dmg, closeTo(bear.dmg * Tier.miniBoss.dmg * mDmg * dmg, 1e-9), reason: '$wave');
      expect((b.mp, b.mpRegen, n.mp, n.mpRegen), ((240 * bMp).round(), 7.0, (120 * mMp).round(), 4.0), reason: '$wave');
      expect((b.cost, m.cost), (killGold(bossStats.cost, Tier.boss, wave), killGold(bear.cost, Tier.miniBoss, wave)),
          reason: '$wave'); // the buff leaves the kill gold alone
    }
    expect((enemyStats(boss, Tier.boss, 60).mp, enemyStats(boss, Tier.boss, 14).mp), (1200, 397)); // 240 x 5, x 1.65
    // Any type in the boss slot (#58) gets it too, on top of its slot's start (the necromancer's HP, 0.65 of its
    // damage a second); it has no MP to multiply.
    final orc = enemyTypes['orc']!, ob = enemyStats('orc', Tier.boss, 60);
    expect(ob.hp, (bossStats.hp * bossTypeHp * bossHpK * waveGrowth(60, waveHp, waveHpLate)).round());
    expect(ob.dmg, closeTo(bossStats.dmg / bossStats.rate * orc.rate * bossTypeDmg * bossDmgK * waveGrowth(60, waveDmg, waveDmgLate), 1e-9));
    expect(ob.mp, 0);

    // A summoner at full MP on wave 50 raises mini-boss skeletons: they keep the tier's stats without the buff.
    final g = bare()..wave = 50;
    final u = g.monster(boss, Tier.boss, const Point(250, 60))..summonCd = 0;
    g.units.add(u..mp = u.stats.mp.toDouble());
    g.tick(0.05);
    final raised = g.minionsOf(u).toList();
    expect(raised.map((m) => m.tier), [Tier.miniBoss, Tier.miniBoss]);
    for (final m in raised) {
      expect((m.maxHp, m.stats.dmg), (enemyStats(minion, Tier.miniBoss, 50, raised: true).hp, enemyStats(minion, Tier.miniBoss, 50, raised: true).dmg));
      expect(m.maxHp, lessThan(enemyStats(minion, Tier.miniBoss, 50).hp));
    }
  });

  test('a necromancer raises now what it can pay for, saves up in calm for a better tier, and waits with six up', () {
    SummonChoice decide(int wave, {double? mp, double knightsAt = 0, int live = 0}) {
      final g = bare()..wave = wave;
      final u = g.monster(boss, Tier.boss, const Point(250, 60));
      if (mp != null) u.mp = mp;
      g.units.add(u);
      for (var i = 0; i < (knightsAt > 0 ? 6 : 0); i++) {
        g.units.add(Unit(Side.troop, 'knight', troopTypes['knight']!, u.pos - Point(knightsAt, 0))..entered = true);
      }
      for (var i = 0; i < live; i++) {
        g.units.add(Unit(Side.enemy, minion, enemyStats(minion, Tier.normal, wave), u.pos + Point(20, i * 10.0))..raisedBy = u);
      }
      final choice = g.decideSummon(u);
      expect(g.decideSummon(u).toString(), choice.toString()); // the same state, the same choice
      return choice;
    }

    final calm = decide(5); // a fresh boss, nobody near
    expect((calm.cast, calm.horizon), (Tier.normal, calmHorizon));
    final saving = decide(15, mp: 74); // a high elite pair needs 90: worth the wait
    expect((saving.cast, saving.saving), (null, Tier.highElite));
    final pressed = decide(15, mp: 74, knightsAt: 80); // they reach it before it could pay for high elites
    expect((pressed.cast, pressed.horizon < (90 - 74) / 7), (Tier.elite, true));
    final full = decide(15, mp: 240, live: maxMinions);
    expect((full.cast, full.saving), (null, null));
  });

  test('a cast pays for each minion it raises, two at most and never past six of its own', () {
    for (final (wave, tier, fx, live, n) in [(5, Tier.normal, 'summon', 0, 2), (10, Tier.elite, 'summon_elite', 0, 2), (5, Tier.normal, 'summon', 5, 1)]) {
      final g = bare()..wave = wave;
      final u = g.monster(boss, Tier.boss, const Point(250, 60))..summonCd = 0;
      g.units.add(u);
      for (var i = 0; i < live; i++) {
        g.units.add(Unit(Side.enemy, minion, enemyStats(minion, Tier.normal, wave), Point(120, 10.0 + 20 * i))
          ..raisedBy = u
          ..busyUntil = hold);
      }
      final mp = u.mp;
      g.tick(0.05);
      final raised = g.minionsOf(u).skip(live).toList();
      expect(raised, hasLength(n), reason: '$wave $live');
      expect(u.mp, closeTo(mp + 7 * 0.05 - n * summonCost[tier]!, 1e-9), reason: '$wave $live');
      for (final m in raised) {
        expect((m.raisedBy, m.tier, m.stats.cost), (u, tier, 0), reason: '$wave $live');
      }
      expect(g.impacts.map((i) => i.$2), List.filled(n, fx), reason: '$wave $live');
      expect((u.busyUntil, u.summonCd), (g.t + summonTime, summonEvery), reason: '$wave $live');
    }
  });

  test('from wave 8 the mini boss is sometimes the necromancer; before that never', () {
    var necros = 0;
    for (var seed = 0; seed < 40; seed++) {
      final g = bare(Random(seed))..wave = 8; // wave 9: the first mini boss from wave 8
      g.startWave();
      final mini = g.queue.where((m) => m.$2 == Tier.miniBoss).single;
      if (mini.$1 == boss) {
        necros++;
      } else {
        expect(mini.$1, isIn(poolOf(9)), reason: 'seed $seed');
      }
      for (final w in [3, 6]) {
        final early = bare(Random(seed))..wave = w - 1;
        early.startWave();
        expect(early.queue.where((m) => m.$2 == Tier.miniBoss).single.$1, isNot(boss), reason: 'seed $seed wave $w');
      }
    }
    expect(necros, inInclusiveRange(5, 25)); // about a third of 40
  });

  test('the mini boss necromancer pays 163 in wave 8; a raised mini boss pays nothing', () {
    for (final roll in [1.0, 0.0]) {
      final g = bare()..wave = 8;
      placeNow(g, 'knight', 2, 3);
      g.loot = _Dice(roll, Item.bow.index);
      final necro = g.monster(boss, Tier.miniBoss, g.troops.single.pos + const Point(10, 0))
        ..hp = 1
        ..busyUntil = hold;
      g.units.add(necro);
      final gold = g.gold;
      g.tick(0.05);
      expect((necro.alive, g.gold - gold), (false, 163), reason: '$roll'); // 40 × 3 × 1.045^7 = 163.3
    }
    for (final roll in [0.0, dropChance - 0.01, dropChance]) {
      final g = bare();
      placeNow(g, 'knight', 2, 3);
      g.loot = _Dice(roll, Item.boots.index);
      final at = g.troops.single.pos + const Point(10, 0);
      final raised = Unit(Side.enemy, minion, const Stats(hp: 300, cost: 0, speed: 20, dmg: 8, range: 12, rate: 0.9), at)
        ..tier = Tier.miniBoss
        ..raisedBy = Unit(Side.enemy, boss, bossStats, at + const Point(80, 0))
        ..hp = 1
        ..busyUntil = hold;
      g.units.add(raised);
      final gold = g.gold;
      g.tick(0.05);
      expect((raised.alive, g.gold - gold), (false, 0), reason: '$roll');
    }
  });

  test('a necromancer built without MP never raises anything', () {
    final g = bare()..wave = 5;
    final u = Unit(Side.enemy, boss, bossStats, const Point(250, 60))
      ..tier = Tier.boss
      ..summonCd = 0;
    g.units.add(u);
    for (var i = 0; i < 100; i++) {
      g.tick(0.05);
    }
    expect(g.minionsOf(u), isEmpty);
    expect((g.enemies.length, u.plan), (1, null));
  });

  /// A troop of [type] at [at] that neither walks nor fights.
  Unit standing(Game g, String type, Point<double> at) {
    final u = Unit(Side.troop, type, troopTypes[type]!, at)
      ..entered = true
      ..busyUntil = hold;
    g.units.add(u);
    return u;
  }

  /// A normal monster of [type] at [at] that neither walks nor fights, with [hp] left (else full).
  Unit still(Game g, String type, Point<double> at, [double? hp]) {
    final u = g.monster(type, Tier.normal, at)..busyUntil = hold;
    if (hp != null) u.hp = hp;
    g.units.add(u);
    return u;
  }

  /// The healing necromancer at [at] with [mp].
  Unit mender(Game g, Point<double> at, [double mp = 40]) {
    final u = g.monster(necroHealer, Tier.normal, at)..mp = mp;
    g.units.add(u);
    return u;
  }

  test('a healing necromancer pays MP for every heal, and heals nobody without enough', () {
    for (final (mp, healed) in [(40.0, true), (5.0, false)]) {
      final g = bare();
      final orc = still(g, 'orc', const Point(230, 60), 10);
      final u = mender(g, const Point(250, 60), mp);
      g.tick(0.05);
      expect(orc.hp, healed ? 10 + necroHealerStats.dmg : 10, reason: '$mp');
      expect(u.mp, closeTo(healed ? 40 - necroHealCost : 5 + 3.2 * 0.05, 1e-9), reason: '$mp');
    }
  });

  test('a healing necromancer that can\'t heal swings at a troop in reach, steps up to one just past it, and never charges', () {
    (Game, Unit, Unit) scene(double gap) {
      final g = bare();
      still(g, 'slime', const Point(270, 110)); // not alone
      final u = mender(g, const Point(250, 60), 0);
      return (g, u, standing(g, 'knight', Point(250 - gap, 60)));
    }

    final (g, u, knight) = scene(15);
    g.tick(0.05);
    expect(knight.hp, 140 - necroHealerStats.dmg * necroSwing.share);
    expect((u.swung, u.cd), (true, necroSwing.gap));
    expect(g.impacts, contains((knight.pos, 'hit_$boss')));

    for (final (gap, closer) in [(22.0, true), (40.0, false)]) {
      final (h, v, k) = scene(gap);
      h.tick(0.05);
      expect((v.swung, k.hp), (false, 140.0), reason: '$gap');
      expect(v.pos.distanceTo(k.pos) < gap, closer, reason: '$gap');
    }
  });

  test('a healing necromancer backs away from a troop that comes within its reach and a margin', () {
    final g = bare();
    still(g, 'slime', const Point(270, 100));
    final u = mender(g, const Point(250, 60));
    final knight = standing(g, 'knight', const Point(215, 60)); // 35 away: inside 14 + 32
    var d = u.pos.distanceTo(knight.pos);
    for (var i = 0; i < 10; i++) {
      g.tick(0.05);
      expect(u.pos.distanceTo(knight.pos), greaterThan(d), reason: '$i');
      d = u.pos.distanceTo(knight.pos);
    }
    expect(u.pos.x, lessThan(g.rightLimit));
  });

  test("a healing necromancer never backs off past the view's right limit, nor further right when it hasn't come "
      'on yet (#85): a long-reach troop would chase it, and the fight it heals, off the screen', () {
    for (final start in [276.0, 300.0]) { // just inside the right limit (288), and past it
      final g = bare();
      still(g, 'slime', const Point(250, 100));
      final u = mender(g, Point(start, 60));
      // 30 away: inside 22 + 32, out of its scythe's reach. Not an archer reaching both ends of the edge: it doesn't
      // back off from that one at all (necro_mend_test.dart, decisions-log 314).
      final lancer = standing(g, 'lancer', Point(start - 30, 60));
      for (var i = 0; i < 40; i++) {
        final x = u.pos.x, limit = g.rightLimit; // the limit this tick's moves keep to (the view moves after them)
        g.tick(0.05);
        expect(u.pos.x, lessThanOrEqualTo(max(limit, x) + 1e-9), reason: '$start $i');
      }
      // It still backs off, as far as the view lets it and then along the edge.
      expect(u.pos.distanceTo(lancer.pos), greaterThan(30 + tile / 2), reason: '$start');
    }
  });

  test('with nobody to heal a healing necromancer rests a tile behind the rearmost monster, out of the troops\' reach '
      '(by mendClear, decisions-log 314)', () {
    for (final (knightAt, x) in [(null, 196.0), (const Point(205.0, 60.0), 205 + 14 + necroSafety + mendClear)]) {
      final g = bare();
      still(g, 'slime', const Point(180, 60));
      final u = mender(g, const Point(240, 60));
      if (knightAt != null) standing(g, 'knight', knightAt);
      for (var i = 0; i < 100; i++) {
        g.tick(0.05);
      }
      expect(u.pos.x, closeTo(x, 1), reason: '$knightAt');
      expect(u.pos.y, closeTo(60, 1), reason: '$knightAt');
    }
  });

  test('a healing necromancer heals only the hurt it can reach from a safe spot', () {
    final g = bare();
    final unsafe = still(g, 'orc', const Point(120, 60), 10); // its heal spot is near the knight
    final safe = still(g, 'orc', const Point(170, 110), 40);
    standing(g, 'knight', const Point(160, 60));
    mender(g, const Point(250, 60));
    for (var i = 0; i < 100 && safe.hp == 40; i++) {
      g.tick(0.05);
    }
    expect(safe.hp, greaterThan(40));
    expect(unsafe.hp, 10);
  });

  test("healing necromancers' heals don't stack (#78): of two on one hurt monster one heals it and the other the "
      'next most hurt; a monster in its window takes no other healer\'s heal until it ends', () {
    final g = bare();
    final worst = still(g, 'orc', const Point(230, 60), 10), next = still(g, 'orc', const Point(230, 90), 20);
    final a = mender(g, const Point(250, 60)), b = mender(g, const Point(250, 80));
    g.tick(0.05);
    expect((worst.hp, next.hp), (10 + necroHealerStats.dmg, 20 + necroHealerStats.dmg));
    expect((worst.healedBy, next.healedBy), (a, b));
    expect(worst.healedUntil - g.t, closeTo(g.attackEvery(a) * healWindow, 0.051));

    final h = bare();
    final orc = still(h, 'orc', const Point(230, 60), 10);
    final first = mender(h, const Point(250, 60)), second = mender(h, const Point(250, 80))..cd = 0.5; // ready inside the window
    h.tick(0.05);
    expect((orc.hp, orc.healedBy), (10 + necroHealerStats.dmg, first));
    for (var i = 0; i < 20; i++) {
      h.tick(0.05); // to 1.05 s: the second is ready, the orc still in the first one's window
    }
    expect(orc.hp, 10 + necroHealerStats.dmg);
    expect(second.mp, 40); // no heal paid for
    first.mp = 0; // it can't heal again: when its window ends, the second one's heal lands
    for (var i = 0; i < 8 && orc.healedBy == first; i++) {
      h.tick(0.05);
    }
    expect((orc.hp, orc.healedBy), (10 + 2 * necroHealerStats.dmg, second));
    expect(h.t, greaterThanOrEqualTo(first.attackedAt + h.attackEvery(first) * healWindow - 1e-9));
  });

  test("troop healers' heals still stack (#78 is monsters only): two priests heal one hurt knight in the same tick", () {
    final p = bare()..gold = 1000;
    placeNow(p, 'priest', 1, 3);
    placeNow(p, 'priest', 1, 2);
    placeNow(p, 'knight', 3, 3);
    final [a, b, knight] = p.troops.toList();
    knight.hp = 50;
    still(p, 'slime', const Point(280, 20)); // mid-wave
    p.tick(0.05);
    expect(knight.hp, 50 + a.stats.dmg + b.stats.dmg);
    expect(knight.healedUntil, double.negativeInfinity);
  });

  test('a healing necromancer left alone walks on toward the back line, and swings at a troop in its way', () {
    final g = bare();
    final u = mender(g, const Point(250, 60));
    for (var i = 0; i < 5; i++) {
      final x = u.pos.x;
      g.tick(0.05);
      expect(u.pos.x, lessThan(x), reason: '$i');
    }
    final knight = standing(g, 'knight', u.pos - const Point(15, 0));
    g.tick(0.05);
    expect((u.swung, knight.hp), (true, 140 - necroHealerStats.dmg * necroSwing.share));
  });

  test('a healer holds its ground while it casts: whoever is in its way moves instead, and it walks again after', () {
    final g = bare();
    final orc = still(g, 'orc', const Point(230, 60), 10);
    final slime = still(g, 'slime', const Point(252, 60)); // on top of it
    final u = mender(g, const Point(250, 60));
    g.tick(0.05);
    expect((orc.hp, u.pos), (10 + necroHealerStats.dmg, const Point(250.0, 60.0)));
    expect(slime.pos.distanceTo(u.pos), greaterThan(2));
    orc.hp = orc.maxHp.toDouble(); // nobody to heal: it would go back to rest
    for (var i = 0; i < 10; i++) {
      g.tick(0.05);
      expect(u.pos, const Point(250.0, 60.0), reason: '$i');
    }
    for (var i = 0; i < 3; i++) {
      g.tick(0.05);
    }
    expect(u.pos, isNot(const Point(250.0, 60.0)));

    final p = bare()..gold = 1000;
    placeNow(p, 'priest', 1, 3);
    placeNow(p, 'knight', 3, 3);
    placeNow(p, 'soldier', 0, 0);
    final [priest, knight, soldier] = p.troops.toList();
    knight.hp = 50;
    soldier.pos = priest.pos - const Point(4, 0); // walks up through it
    still(p, 'slime', const Point(280, 20)); // mid-wave
    final at = priest.pos;
    for (var i = 0; i < 11; i++) {
      p.tick(0.05);
      expect(priest.pos, at, reason: '$i');
    }
    expect(p.impacts.first.$2, 'heal');

    // The after-win round holds it still too.
    final w = bare()..gold = 1000;
    placeNow(w, 'priest', 1, 3);
    placeNow(w, 'knight', 3, 3);
    final healer = w.troops.first;
    w.troops.last.hp = 50;
    winWave(w);
    w.impacts.clear();
    for (var i = 0; i < 100 && w.impacts.isEmpty; i++) {
      w.tick(0.05);
    }
    expect((w.waveActive, w.impacts.first.$2), (false, 'heal'));
    final off = healer.post + const Point(0, 10);
    healer.pos = off;
    for (var i = 0; i < 8; i++) {
      w.tick(0.05);
      expect(healer.pos, off, reason: '$i');
    }
    for (var i = 0; i < 6; i++) {
      w.tick(0.05);
    }
    expect(healer.pos, isNot(off)); // on its way back to its spot
  });

  test('a bow is refused a melee fighter already at the reach ceiling, before its cap is looked at', () {
    final g = bare()..upgrades['soldier'] = List.filled(6, Item.bow); // an old save: 6 bows on a 1-bow recipe
    expect(g.statsOf('soldier').range, meleeMaxRange);
    expect(g.whyNot(Item.bow, 'soldier'), Refusal.reach);
    g.upgrades['soldier'] = List.filled(4, Item.bow); // over its cap, still short of the ceiling (the 5th reaches it)
    expect(g.statsOf('soldier').range, lessThan(meleeMaxRange));
    expect(g.whyNot(Item.bow, 'soldier'), Refusal.maxed); // its grade I bow full: grade II's comes with Awaken 1
  });

  test('an item may go on a type exactly when nothing refuses it', () {
    final states = <String, void Function(Game)>{
      'fresh': (g) {},
      'upgraded': (g) => g
        ..upgrades['knight'] = [...awakenItems('knight', 1), Item.sword, Item.sword]
        ..upgrades['soldier'] = List.filled(6, Item.bow)
        ..upgrades['priest'] = awakenItems('priest', 3)
        ..upgrades['archer'] = [Item.bow, Item.bow],
    };
    for (final MapEntry(key: state, value: prepare) in states.entries) {
      final g = bare();
      prepare(g);
      for (final type in troopTypes.keys) {
        for (final item in Item.values) {
          expect(g.canUse(item, type), g.whyNot(item, type) == null, reason: '$state $type ${item.name}');
        }
      }
    }
  });

  test('the bag\'s picker lists every troop type for an item, with how many it took, its cap and why not', () {
    final g = bare();
    expect(g.typesFor(Item.sword), [
      for (final type in troopTypes.keys)
        (type, 0, awakenRecipe[type]![Item.sword] ?? 0, awakenRecipe[type]!.containsKey(Item.sword) ? null : Refusal.notInRecipe),
    ]);
    g.inventory[Item.sword] = 3;
    for (var i = 0; i < 3; i++) {
      expect(g.useItem(Item.sword, 'knight'), isTrue);
    }
    expect(g.typesFor(Item.sword).firstWhere((e) => e.$1 == 'knight'), ('knight', 3, 3, Refusal.maxed)); // grade I full
  });

  // The picker's price preview (#12): what [Game.priceWith] says is what the type costs after the drop.
  final previewStates = <String, void Function(Game)>{
    'fresh': (g) {},
    'upgraded': (g) => g
      ..upgrades['knight'] = (awakenItems('knight', 1)..remove(Item.gloves)) // a glove short of awakening
      ..upgrades['soldier'] = List.filled(6, Item.bow, growable: true) // at the reach ceiling
      ..upgrades['priest'] = (awakenItems('priest', 3)..remove(Item.crystalStaff)) // a grade III staff short of level 3
      ..upgrades['archer'] = awakenItems('archer', 3), // maxed
  };

  test('the price preview is the price after the item goes on, an awakening it completes included', () {
    for (final MapEntry(key: state, value: prepare) in previewStates.entries) {
      for (final type in troopTypes.keys) {
        for (final item in Item.values) {
          final g = bare()..inventory[item] = 1;
          prepare(g);
          final preview = g.priceWith(type, item);
          if (preview == null) continue; // refused: the next test
          expect(g.useItem(item, type), isTrue, reason: '$state $type ${item.name}');
          expect(g.priceOf(type), preview, reason: '$state $type ${item.name}');
        }
      }
    }
    final g = bare();
    previewStates['upgraded']!(g);
    expect((g.priceOf('knight'), g.priceWith('knight', Item.gloves)), (50 + 10 * 5, (50 + 11 * 5) * 2)); // it awakens
    expect((g.priceOf('priest'), g.priceWith('priest', Item.crystalStaff)), ((90 + 35 * 9) * 4, (90 + 36 * 9) * 8)); // level 2 → 3
    expect(bare().priceWith('soldier', Item.sword), 33);
  });

  test('no price preview for an item the type would refuse', () {
    for (final MapEntry(key: state, value: prepare) in previewStates.entries) {
      final g = bare();
      prepare(g);
      for (final type in troopTypes.keys) {
        for (final item in Item.values) {
          expect(g.priceWith(type, item) == null, g.whyNot(item, type) != null, reason: '$state $type ${item.name}');
        }
      }
    }
    final g = bare();
    previewStates['upgraded']!(g);
    expect(g.priceWith('soldier', Item.bow), isNull); // reach ceiling
    expect(g.priceWith('archer', Item.bow), isNull); // maxed
    expect(g.priceWith('knight', Item.sword), isNull); // at the cap until it awakens
    expect(g.priceWith('lancer', Item.bow), isNull); // not in its recipe
  });

  test('previewing a price leaves the type\'s items as they were', () {
    final g = bare();
    previewStates['upgraded']!(g);
    final before = {for (final MapEntry(key: t, value: items) in g.upgrades.entries) t: [...items]};
    final bag = {...g.inventory}, sounds = g.sfx.length;
    for (final type in troopTypes.keys) {
      for (final item in Item.values) {
        g.priceWith(type, item);
      }
    }
    expect(g.upgrades, before); // no type gained an entry or an item
    expect(g.inventory, bag);
    expect(g.sfx.length, sounds);
  });

  test('using an item fails exactly when it is refused; otherwise the type takes one and the bag gives one', () {
    for (final state in ['fresh', 'knight at its sword cap']) {
      for (final type in troopTypes.keys) {
        for (final item in Item.values) {
          final g = bare();
          if (state != 'fresh') g.upgrades['knight'] = [Item.sword, Item.sword, Item.sword];
          g.inventory[item] = 1;
          final why = g.whyNot(item, type), had = g.countOf(type, item);
          g.sfx.clear();
          expect(g.useItem(item, type), why == null, reason: '$state $type ${item.name}');
          if (why == null) {
            expect((g.countOf(type, item), g.inventory[item]), (had + 1, 0), reason: '$state $type ${item.name}');
          } else {
            expect((g.countOf(type, item), g.inventory[item]), (had, 1), reason: '$state $type ${item.name}');
            expect(g.sfx, [Sfx.error], reason: '$state $type ${item.name}');
          }
        }
      }
    }
  });

  test('every refusal has words for the picker', () {
    expect(refusalNames.keys, Refusal.values);
    expect(refusalNames.values, ['Not for this type', '${Words.awaken} first', 'At max', 'Max range']);
  });

  test('the troops that fall in a wave are kept in the order they fell, and a won wave hands them over', () {
    final (g, soldier) = doomedSoldier();
    placeNow(g, 'knight', 1, 6); // someone left standing
    placeNow(g, 'archer', 0, 1);
    final archer = g.troops.firstWhere((u) => u.type == 'archer')..hp = 1;
    g.tick(0.05);
    expect(g.fallen, [soldier]);
    g.units.add(Unit(Side.enemy, 'werebear', enemyTypes['werebear']!, archer.pos + const Point(10, 0)));
    g.tick(0.05);
    expect(g.fallen, [soldier, archer]);
    expect(g.lastFallen, isEmpty); // not won yet
    for (final e in g.enemies) {
      e.gone = true;
    }
    g.tick(0.05);
    expect((g.waveActive, g.over), (false, false));
    expect(g.lastFallen, [soldier, archer]);

    g.startWave();
    expect(g.fallen, isEmpty);
    expect(g.lastFallen, [soldier, archer]); // until the next win
    g
      ..queue.clear()
      ..units.add(Unit(Side.enemy, 'slime', enemyTypes['slime']!, const Point(300, 60)));
    g.tick(0.05);
    g.enemies.single.gone = true;
    g.tick(0.05);
    expect(g.lastFallen, isEmpty); // nobody fell this time
  });

  test('the fallen are counted by type in the book\'s order, leaving out types with none', () {
    Unit troop(String type) => Unit(Side.troop, type, troopTypes[type]!, const Point(0, 0));
    final counts = fallenCounts([troop('wizard'), troop('soldier'), troop('wizard'), troop('knight')]);
    expect(counts, {'soldier': 1, 'knight': 1, 'wizard': 2});
    expect(counts.keys, ['soldier', 'knight', 'wizard']);
    expect(fallenCounts([]), isEmpty);
    expect(fallenNamesMax, 3);
  });

  test('a mini boss comes every 3rd wave and the boss every 5th; on waves 15 and 30 both, the mini boss first', () {
    for (final seed in [1, 2, 3, 4]) {
      final all = queues(seed, 30);
      for (var n = 1; n <= 30; n++) {
        final q = all[n - 1], why = 'seed $seed wave $n';
        final minis = [for (final (i, m) in q.indexed) if (m.$2 == Tier.miniBoss) i];
        final bosses = [for (final (i, m) in q.indexed) if (m.$2 == Tier.boss) i];
        expect((minis.length, bosses.length), (n % 3 == 0 ? 1 : 0, n % 5 == 0 ? 1 : 0), reason: why);
        if (minis.isNotEmpty && bosses.isNotEmpty) expect(minis.single, lessThan(bosses.single), reason: why);
        final pool = enemyTypes.keys.take(min(enemyTypes.length, 1 + (n >> 1))).toList();
        if (minis.isNotEmpty && n < necroMiniFrom) expect(q[minis.single].$1, isIn(pool), reason: why);
        if (minis.isNotEmpty) expect(q[minis.single].$1, anyOf(isIn(pool), boss), reason: why);
        if (bosses.isNotEmpty && n < necroBossFrom) expect(q[bosses.single].$1, isIn(pool), reason: why);
        if (bosses.isNotEmpty) expect(q[bosses.single].$1, anyOf(isIn(pool), boss), reason: why);
        expect(q.length, 4 + 2 * n + (n % 3 == 0 ? 1 : 0) + (n % 5 == 0 ? 1 : 0) + necroHealersIn(n), reason: why);
      }
    }
  });

  test('a boss or mini boss slot holds any type of the pool, the stronger likelier; the necromancer at its chances (#58)', () {
    // The n-th type is n times as likely as the first: of three, 1/6, 2/6, 3/6.
    const three = ['a', 'b', 'c'];
    expect([for (final r in [0.0, 1 / 6 - 1e-9, 1 / 6, 0.5 - 1e-9, 0.5, 1 - 1e-9]) slotType(three, r)], ['a', 'a', 'b', 'b', 'c', 'c']);
    // Wave 30 brings both: over many games the boss is the necromancer about [necroBossChance] of the time, and
    // many types of the pool turn up in the two slots, the stronger more often.
    final seen = <String, int>{};
    var necroBosses = 0;
    const games = 90;
    for (var seed = 0; seed < games; seed++) {
      final g = bare(Random(seed))
        ..slots = Random(seed)
        ..wave = 29;
      g.startWave();
      final mini = g.queue.singleWhere((m) => m.$2 == Tier.miniBoss).$1, b = g.queue.singleWhere((m) => m.$2 == Tier.boss).$1;
      if (b == boss) necroBosses++;
      for (final t in [mini, b].where((t) => t != boss)) {
        seen[t] = (seen[t] ?? 0) + 1;
      }
    }
    expect(necroBosses / games, closeTo(necroBossChance, 0.12));
    expect(seen.keys, everyElement(isIn(poolOf(30))));
    expect(seen.length, greaterThanOrEqualTo(8));
    final pool = poolOf(30), weak = pool.take(4).fold(0, (n, t) => n + (seen[t] ?? 0)), strong = pool.skip(8).fold(0, (n, t) => n + (seen[t] ?? 0));
    expect(strong, greaterThan(2 * weak)); // weights 1-4 against 9-12
  });

  test('the slots\' dice never change the rest of a wave', () {
    List<List<(String, Tier)>> play(Random slots) {
      final g = bare(Random(5))..slots = slots, out = <List<(String, Tier)>>[];
      for (var w = 1; w <= 15; w++) {
        g.startWave();
        out.add([for (final m in g.queue) if (m.$2 != Tier.miniBoss && m.$2 != Tier.boss) m]);
        g.queue.clear();
      }
      return out;
    }

    expect(play(Random(1)), play(Random(2)));
  });

  test('a boss of a monster type starts from the necromancer boss, a mini boss from the wave\'s strongest type (#58)', () {
    // The boss: the necromancer's HP and damage a second ([bossTypeHp], [bossTypeDmg]), at its own pace, speed
    // and reach; it pays the boss's gold and has no MP (only the necromancer raises skeletons).
    final orc = enemyTypes['orc']!, b = enemyStats('orc', Tier.boss, 1);
    expect(b.hp, (bossStats.hp * bossTypeHp).round());
    expect(b.dmg, closeTo(bossStats.dmg / bossStats.rate * orc.rate * bossTypeDmg, 1e-9));
    expect((b.speed, b.range, b.rate, b.cost, b.mp), (orc.speed, orc.range, orc.rate, orc.cost * 4, 0));
    final shooter = enemyStats('skeleton_archer', Tier.boss, 11), archer = enemyTypes['skeleton_archer']!;
    expect(shooter.shotSpeed, archer.shotSpeed); // it still shoots
    expect(shooter.range, closeTo(archer.range * 1.1, 1e-9));
    // The mini boss: raised to the wave's strongest type (wave 9: the skeleton archer, 40 HP, 5.8 a second),
    // then the tier's ×6 / ×2.2 and the boss buff's ramp (#66); never lowered (the orc keeps its 80 HP and 10 a second).
    final slime = enemyTypes['slime']!, top = enemyTypes[poolOf(9).last]!, grow = waveGrowth(9, waveHp, waveHpLate);
    expect(poolOf(9).last, 'skeleton_archer');
    expect(enemyStats('slime', Tier.miniBoss, 9).hp, (top.hp * Tier.miniBoss.hp * bossBuff(Tier.miniBoss, 9).$1 * grow).round());
    expect(enemyStats('slime', Tier.miniBoss, 9).dmg,
        closeTo(max(slime.dmg, top.dmg / top.rate * slime.rate) * Tier.miniBoss.dmg * bossBuff(Tier.miniBoss, 9).$3 * waveGrowth(9, waveDmg, waveDmgLate), 1e-9));
    expect(enemyStats('orc', Tier.miniBoss, 9).hp, (orc.hp * Tier.miniBoss.hp * bossBuff(Tier.miniBoss, 9).$1 * grow).round());
    // The strongest type in its own slot is what the mini boss always was.
    expect(enemyStats('armored_skeleton', Tier.miniBoss, 12).hp,
        (150 * Tier.miniBoss.hp * bossBuff(Tier.miniBoss, 12).$1 * waveGrowth(12, waveHp, waveHpLate)).round());
    // A necromancer's raised minion keeps its own stats, whatever its rank.
    final skeleton = enemyTypes[minion]!, grow30 = waveGrowth(30, waveHp, waveHpLate);
    expect(enemyStats(minion, Tier.miniBoss, 30, raised: true).hp, (skeleton.hp * Tier.miniBoss.hp * grow30).round());
    expect(enemyStats(minion, Tier.miniBoss, 30).hp, (enemyTypes['werebear']!.hp * Tier.miniBoss.hp * bossBuff(Tier.miniBoss, 30).$1 * grow30).round());
    // Other ranks, and the necromancer in either slot, are as before.
    expect(enemyStats('slime', Tier.highElite, 9).hp, (slime.hp * Tier.highElite.hp * grow).round());
    expect(enemyStats(boss, Tier.boss, 5).hp, (bossStats.hp * 1.68).round());
  });

  test('the loot dice never change a wave\'s queue', () {
    List<List<(String, Tier)>> play(Random loot) {
      final g = bare(Random(5))
        ..loot = loot
        ..slots = Random(5);
      final out = <List<(String, Tier)>>[];
      for (var w = 1; w <= 8; w++) {
        g.startWave();
        out.add([...g.queue]);
        g.queue.clear();
      }
      return out;
    }

    expect(play(Random(1)), play(_Dice(0, 3)));
  });

  test('the wave meter counts a wave\'s mini boss', () {
    final g = bare(Random(1))..wave = 5;
    g.startWave();
    expect((g.wave, g.waveTotal), (6, 16 + 1 + necroHealersIn(6)));
  });

  test('a fresh game is not paused', () {
    expect(Game().paused, isFalse);
  });

  test('paused before a wave nothing moves and the clock stands; unpaused it runs again', () {
    final g = wide()..gold = 1000;
    expect(g.place('knight', 2, 3), isTrue); // marching in
    final t = g.t, before = [for (final u in g.troops) (u.pos, u.entered)];
    g.paused = true;
    for (var i = 0; i < 20; i++) {
      g.tick(0.05);
    }
    expect(g.t, t);
    expect([for (final u in g.troops) (u.pos, u.entered)], before);
    g.paused = false;
    g.tick(0.05);
    expect(g.t, greaterThan(t));
  });

  test('paused mid-wave nothing spawns, moves, fights or flies; unpaused the wave goes on', () {
    final g = wide(Random(1))..gold = 1000;
    placeNow(g, 'archer', 2, 3);
    g.startWave();
    for (var i = 0; i < 400 && g.waveSpawned < 2; i++) {
      g.tick(0.05);
    }
    List<Object> snapshot() => [g.waveSpawned, g.queue.length, g.shots.length, for (final u in g.units) (u.hp, u.pos)];
    final before = snapshot();
    g.paused = true;
    for (var i = 0; i < 40; i++) {
      g.tick(0.05);
    }
    expect(snapshot(), before);
    g.paused = false;
    final spawned = g.waveSpawned;
    for (var i = 0; i < 40; i++) {
      g.tick(0.05);
    }
    expect(g.waveSpawned, greaterThan(spawned));
  });

  test('paused, a troop with a potion regains no HP', () {
    final g = bare()..upgrades['knight_templar'] = [Item.potion];
    g.gold = 1000;
    placeNow(g, 'knight_templar', 2, 3);
    final u = g.troops.single..hp = 100;
    g.paused = true;
    g.tick(1);
    expect(u.hp, 100);
    g.paused = false;
    g.tick(1);
    expect(u.hp, 100 + potionRegen);
  });

  test('pausing is not saved: a loaded game is never paused', () {
    final g = bare()..paused = true;
    final j = jsonDecode(jsonEncode(g.toJson())) as Map<String, dynamic>;
    expect(j.containsKey('paused'), isFalse);
    expect(Game.fromJson(j).paused, isFalse);
  });

  test('a game over stays still whether paused or not', () {
    final (g, _) = doomedSoldier();
    g.lives = wipeLives; // the army wiped at the last heart (wipe.dart)
    g.tick(0.05);
    expect(g.over, isTrue);
    final t = g.t;
    for (final paused in [true, false]) {
      g
        ..paused = paused
        ..tick(0.05);
      expect(g.t, t, reason: 'paused $paused');
    }
  });

  test('a new army holds capacityStart troops, the free healer one of them; one more is refused', () {
    final g = Game()..gold = 100000;
    expect((g.capacity, g.armySize, g.full), (capacityStart, 1, false));
    for (var i = 1; i < capacityStart; i++) {
      expect(g.autoPlace('soldier'), isTrue, reason: '$i');
    }
    expect((g.armySize, g.full), (capacityStart, true));
    final gold = g.gold, count = g.troops.length;
    g.sfx.clear();
    expect(g.autoPlace('knight'), isFalse);
    expect(g.canPlace(0, 0), isTrue); // a free cell doesn't help
    expect(g.place('knight', 0, 0), isFalse);
    expect((g.gold, g.troops.length), (gold, count));
    expect(g.sfx, [Sfx.error, Sfx.error]);
  });

  test('a falling troop frees its slot at once', () {
    final g = Game()..gold = 100000;
    for (var i = 1; i < capacityStart; i++) {
      g.autoPlace('soldier');
    }
    expect(g.full, isTrue);
    g.troops.firstWhere((u) => u.type == 'soldier').dying = 0;
    expect((g.armySize, g.full), (capacityStart - 1, false));
    expect(g.autoPlace('knight'), isTrue);
    expect(g.full, isTrue);
  });

  test('a full army refuses a troop mid-wave too, though troops may share cells then', () {
    final g = Game()..gold = 100000;
    for (var i = 1; i < capacityStart; i++) {
      g.autoPlace('soldier');
    }
    g.units.add(Unit(Side.enemy, 'slime', enemyTypes['slime']!, const Point(300, 60))..busyUntil = hold);
    expect(g.waveActive, isTrue);
    final gold = g.gold, count = g.troops.length;
    g.sfx.clear();
    expect(g.autoPlace('soldier'), isFalse);
    expect((g.gold, g.troops.length), (gold, count));
    expect(g.sfx, [Sfx.error]);
  });

  test('each capacity purchase costs capacityPriceRise more than the last and adds capacityStep', () {
    final g = Game()..gold = 100000;
    for (var n = 0; n < 3; n++) {
      final cost = capacityPrice + n * capacityPriceRise, gold = g.gold;
      expect(g.capacityCost, cost, reason: '$n');
      expect(g.buyCapacity(), isTrue, reason: '$n');
      expect((g.gold, g.capacity), (gold - cost, capacityStart + (n + 1) * capacityStep), reason: '$n');
    }
  });

  test('the zone is deployCols plus a column for every capacity purchase, at most maxZoneCols', () {
    final g = Game(); // the 320-wide view: 6 columns at most
    expect(g.maxZoneCols, 6);
    for (var c = 1; c <= 60; c++) {
      g.capacity = c;
      final bought = max(0, (c - capacityStart) ~/ capacityStep); // between two steps the lower counts
      expect(g.zoneCols, min(deployCols + bought, 6), reason: 'capacity $c');
    }
    g
      ..gold = 100000
      ..capacity = g.maxCapacity;
    expect((g.maxCapacity, g.canBuyCapacity, g.buyCapacity(), g.capacity), (6 * rows, false, false, 6 * rows));
    g.capacity = g.maxCapacity - capacityStep;
    expect(g.canBuyCapacity, isTrue);
  });

  test('an old save loads with the capacity its zone columns bought, or its army\'s size when that is bigger', () {
    final g = Game()
      ..gold = 100000
      ..capacity = 12;
    for (var i = 0; i < 8; i++) {
      expect(g.autoPlace('soldier'), isTrue);
    }
    final j = jsonDecode(jsonEncode(g.toJson())) as Map<String, dynamic>..remove('capacity');
    expect(Game.fromJson(j..['zoneCols'] = deployCols).capacity, 9); // 9 troops, 6 bought: none is cut
    final small = jsonDecode(jsonEncode(Game().toJson())) as Map<String, dynamic>..remove('capacity');
    expect(Game.fromJson(small..['zoneCols'] = 4).capacity, capacityStart + capacityStep);
  });

  test('a capacity between two steps counts the purchases below it, for the price and the zone', () {
    final g = Game()..capacity = capacityStart + capacityStep + 1; // an old army's size
    expect((g.capacityBought, g.capacityCost, g.zoneCols), (1, capacityPrice + capacityPriceRise, deployCols + 1));
    g.capacity = capacityStart - 1;
    expect((g.capacityBought, g.capacityCost, g.zoneCols), (0, capacityPrice, deployCols));
  });

  /// [v] as the tooltips write a number: whole without ".0", else one decimal.
  String num1(num v) => v == v.roundToDouble() ? '${v.round()}' : v.toStringAsFixed(1);

  test('the staff is magic power: a caster\'s attack times staffDmg, a healer\'s heals staffHeal bigger, in any order', () {
    expect(troopTypes['wizard']!.upgraded(Item.staff).dmg, troopTypes['wizard']!.dmg * staffDmg);
    final priest = troopTypes['priest']!;
    expect(priest.upgraded(Item.staff).dmg, priest.dmg + staffHeal);
    Stats fold(List<Item> items) => items.fold(priest, (s, i) => s.upgraded(i));
    expect(fold([Item.staff, Item.potion, Item.staff]).dmg, fold([Item.potion, Item.staff, Item.staff]).dmg);
    expect(fold([Item.staff, Item.potion, Item.staff]).dmg, priest.dmg + 2 * staffHeal + potionHeal);
    final s = fold([Item.staff]);
    expect(s.statOf(Item.staff), s.dmg);
  });

  test('only the casters\' recipes take the staff, and they take no sword', () {
    for (final type in ['wizard', 'priest']) {
      expect((awakenRecipe[type]![Item.staff], awakenRecipe[type]!.containsKey(Item.sword)), (2, false), reason: type);
    }
    for (final MapEntry(key: type, value: recipe) in awakenRecipe.entries) {
      if (type != 'wizard' && type != 'priest') expect(recipe.containsKey(Item.staff), isFalse, reason: type);
      expect(recipe.values.fold(0, (a, b) => a + b), inInclusiveRange(8, 10), reason: type);
    }
    expect([for (final t in troopTypes.keys) if (powerItem(t) == Item.staff) t], unorderedEquals(['wizard', 'priest']));
    expect(powerItem('knight'), Item.sword);

    final g = bare();
    expect((g.whyNot(Item.staff, 'knight'), g.whyNot(Item.sword, 'wizard')), (Refusal.notInRecipe, Refusal.notInRecipe));
    final open = g.typesFor(Item.staff).where((e) => e.$4 == null || e.$4 == Refusal.awakenFirst).map((e) => e.$1);
    expect(open, unorderedEquals(['wizard', 'priest']));
  });

  test('the save keeps staffs in the bag and on a type', () {
    final h = bare()
      ..inventory[Item.staff] = 2
      ..upgrades['wizard'] = [Item.staff];
    final l = Game.fromJson(jsonDecode(jsonEncode(h.toJson())) as Map<String, dynamic>);
    expect(l.inventory[Item.staff], 2);
    expect(l.upgrades['wizard'], [Item.staff]);
    expect(l.statsOf('wizard').dmg, h.statsOf('wizard').dmg);
  });

  test('the staff\'s tooltip tells its magic, over a caster its sum, and elsewhere that it can\'t go', () {
    final g = bare();
    expect(g.itemInfo(Item.staff).$2, containsAll([
      '+${((staffDmg - 1) * 100).round()}% magic attack',
      'Healers: +${num1(staffHeal)} HP per heal',
      'Only for ${troopTypeNames['priest']}, ${troopTypeNames['wizard']}',
    ]));
    g.upgrades['priest'] = [Item.staff, Item.staff];
    expect(g.itemInfo(Item.staff, 'priest').$2, containsAll(['+${num1(staffHeal)} HP per heal', 'Now: 2/2 on this type, +${num1(2 * staffHeal)} heal']));
    g.upgrades['wizard'] = [Item.staff];
    expect(g.itemInfo(Item.staff, 'wizard').$2, contains('Now: 1/2 on this type, +${((staffDmg - 1) * 100).round()}%'));
    expect(g.itemInfo(Item.staff, 'knight').$2, contains("This type can't take it"));
    expect(g.itemInfo(Item.sword).$2.first, '+${((swordDmg - 1) * 100).round()}% attack');
  });

  /// A mid-wave game with nothing left to spawn and a priest standing at [at], ready to cast.
  (Game, Unit) holy([Point<double> at = const Point(60, 64)]) {
    final g = bare()..startWave();
    g.queue.clear();
    final p = Unit(Side.troop, 'priest', troopTypes['priest']!, at)..entered = true;
    g.units.add(p);
    return (g, p);
  }

  test('the undead are dark: the skeletons and both necromancers, raised ones too, and no troop', () {
    expect({for (final e in enemyTypes.entries) if (e.value.dark) e.key}, {'skeleton', 'skeleton_archer', 'armored_skeleton', 'greatsword_skeleton'});
    expect((bossStats.dark, necroHealerStats.dark), (true, true));
    expect(troopTypes.values.where((s) => s.dark), isEmpty);
    expect((enemyStats('skeleton', Tier.elite, 10).dark, enemyStats('orc', Tier.miniBoss, 10).dark, enemyStats(boss, Tier.boss, 5).dark),
        (true, false, true));
    final g = bare()..wave = 5;
    final u = g.monster(boss, Tier.boss, const Point(250, 60))..summonCd = 0;
    g.units.add(u);
    g.tick(0.05);
    expect(g.minionsOf(u), isNotEmpty);
    expect(g.minionsOf(u).every((m) => m.stats.dark), isTrue);
  });

  test('with nobody to heal a priest smites a dark monster in its reach for holyShare of its heal', () {
    final (g, p) = holy();
    final skeleton = g.monster('skeleton', Tier.normal, const Point(140, 64))..busyUntil = hold; // 80 away
    g.units.add(skeleton);
    final hp = skeleton.hp;
    g.tick(0.05);
    expect(skeleton.hp, closeTo(hp - troopTypes['priest']!.dmg * holyShare, 1e-9));
    expect(g.impacts, contains((skeleton.pos, 'holy')));
    expect(g.sfx, contains(Sfx.hit));
    expect((p.cd, p.attackedAt), (p.stats.rate, g.t));
  });

  test('a priest never smites a living monster', () {
    for (final type in ['orc', 'bat', 'werewolf']) {
      final (g, _) = holy();
      final foe = g.monster(type, Tier.normal, const Point(140, 64))..busyUntil = hold;
      g.units.add(foe);
      for (var i = 0; i < 40; i++) {
        g.tick(0.05);
      }
      expect(foe.hp, foe.maxHp, reason: type);
      expect(g.impacts.where((i) => i.$2 == 'holy'), isEmpty, reason: type);
    }
  });

  test('a priest heals first, and smites once nobody in its reach is hurt', () {
    final (g, p) = holy();
    final knight = Unit(Side.troop, 'knight', troopTypes['knight']!, const Point(90, 64))
      ..entered = true
      ..busyUntil = hold
      ..hp = 100;
    final skeleton = g.monster('skeleton', Tier.normal, const Point(140, 64))..busyUntil = hold;
    g.units.addAll([knight, skeleton]);
    g.tick(0.05);
    expect((knight.hp, skeleton.hp), (100 + p.stats.dmg, skeleton.maxHp.toDouble()));
    knight.hp = knight.maxHp.toDouble();
    for (var i = 0; i < 60 && skeleton.hp == skeleton.maxHp; i++) {
      g.tick(0.05);
    }
    expect(skeleton.hp, closeTo(skeleton.maxHp - p.stats.dmg * holyShare, 1e-9));
  });

  test('a priest never steps up to a dark monster out of its reach', () {
    final (g, p) = holy();
    final skeleton = g.monster('skeleton', Tier.normal, p.pos + Point(p.stats.range + 2 * tile, 0))..busyUntil = hold;
    g.units.add(skeleton);
    final d = p.pos.distanceTo(skeleton.pos);
    for (var i = 0; i < 60; i++) {
      g.tick(0.05);
      expect(p.pos.distanceTo(skeleton.pos), greaterThanOrEqualTo(d), reason: '$i');
    }
    expect(g.impacts.where((i) => i.$2 == 'holy'), isEmpty);
  });

  test('a smite is a blow like any other: it pays, scores, counts for fury, and feeds a fang', () {
    final (g, _) = holy();
    final weak = g.monster('skeleton', Tier.normal, const Point(140, 64))
      ..busyUntil = hold
      ..hp = 1;
    g.units.add(weak);
    final (gold, kills, score) = (g.gold, g.kills, g.score);
    g.tick(0.05);
    expect((weak.alive, g.gold - gold, g.kills - kills, g.score - score), (false, weak.stats.cost, 1, killScore[Tier.normal]));

    final (f, p) = holy();
    p.relics.add(Relic.fury);
    final tough = f.monster('skeleton', Tier.normal, const Point(140, 64))
      ..busyUntil = hold
      ..hp = 1000;
    f.units.add(tough);
    final drops = <double>[];
    var last = tough.hp;
    for (var i = 0; i < 200 && drops.length < furyEvery; i++) {
      f.tick(0.05);
      if (tough.hp < last) drops.add(last - tough.hp);
      last = tough.hp;
    }
    final smite = p.stats.dmg * holyShare;
    expect(drops.length, furyEvery);
    for (final (n, d) in drops.indexed) {
      expect(d, closeTo(n == furyEvery - 1 ? smite * furyHit : smite, 1e-9), reason: 'smite ${n + 1}');
    }

    // A priest standing ahead of its army doesn't count itself among those to heal, so hurt it still smites.
    final (h, q) = holy(const Point(200, 64));
    h.units.add(Unit(Side.troop, 'knight', troopTypes['knight']!, const Point(40, 64))
      ..entered = true
      ..busyUntil = hold);
    q
      ..relics.add(Relic.fang)
      ..hp = 30;
    final dark = h.monster('skeleton', Tier.normal, const Point(260, 64))..busyUntil = hold;
    h.units.add(dark);
    h.tick(0.05);
    expect(dark.hp, closeTo(dark.maxHp - q.stats.dmg * holyShare, 1e-9));
    expect(q.hp, closeTo(30 + q.stats.dmg * holyShare * fangShare, 1e-9));
  });

  test('a priest stands still while it smites, then walks on to its line', () {
    final (g, p) = holy();
    g.units.add(Unit(Side.troop, 'knight', troopTypes['knight']!, p.pos + const Point(1.5 * tile, 0))
      ..entered = true
      ..busyUntil = hold); // its line is a tile behind the knight: it wants to walk (from further back it walks first, 324)
    final skeleton = g.monster('skeleton', Tier.normal, const Point(100, 110))..busyUntil = hold;
    g.units.add(skeleton);
    final at = p.pos;
    g.tick(0.05);
    expect(g.impacts, contains((skeleton.pos, 'holy')));
    for (var i = 0; i < 10; i++) {
      g.tick(0.05);
      expect(p.pos, at, reason: '$i');
    }
    for (var i = 0; i < 4; i++) {
      g.tick(0.05);
    }
    expect(p.pos, isNot(at));
  });

  test('a healing necromancer still heals the dark monsters', () {
    final g = bare();
    final skeleton = still(g, 'skeleton', const Point(230, 60), 10);
    mender(g, const Point(250, 60));
    g.tick(0.05);
    expect(skeleton.hp, 10 + necroHealerStats.dmg);
  });

  /// Mid-wave: a priest at (8, 56) that never casts, a soldier at (72, 56) and a slime held far to the right.
  (Game, Unit, Unit) retreatScene() {
    final g = bare()
      ..gold = 1000
      ..skills = false; // no Hold Fast on the lone slime, no Healing Prayer (decisions-log 298)
    placeNow(g, 'priest', 0, 3);
    placeNow(g, 'soldier', 4, 3);
    final [priest, soldier] = g.troops.toList();
    priest.cd = hold; // the retreat alone, no heals
    g.units.add(g.monster('slime', Tier.normal, const Point(200, 56))..busyUntil = hold);
    return (g, priest, soldier);
  }

  test('a troop above half its HP keeps fighting', () {
    final (g, _, soldier) = retreatScene();
    soldier.hp = 0.6 * soldier.maxHp;
    final x = soldier.pos.x;
    g.tick(0.05);
    expect((soldier.retreating, soldier.pos.x > x), (false, true)); // on toward its foe
  });

  test('at half its HP a troop falls back until well inside a healer\'s reach, and stands there', () {
    final (g, priest, soldier) = retreatScene();
    soldier.hp = retreatAt * soldier.maxHp;
    final d = soldier.pos.distanceTo(priest.pos);
    g.tick(0.05);
    expect(soldier.retreating, isTrue);
    expect(soldier.pos.distanceTo(priest.pos), lessThan(d));
    for (var i = 0; i < 100; i++) {
      g.tick(0.05);
    }
    expect(soldier.pos.distanceTo(priest.pos), lessThanOrEqualTo(priest.stats.range * retreatNear + 1e-9));
    expect((soldier.retreating, soldier.moving), (true, false));
  });

  test('a falling-back troop fights again only once healed to returnAt', () {
    final (g, _, soldier) = retreatScene();
    soldier.hp = retreatAt * soldier.maxHp;
    g.tick(0.05);
    soldier.hp = (returnAt - 0.01) * soldier.maxHp;
    g.tick(0.05);
    expect(soldier.retreating, isTrue);
    soldier.hp = returnAt * soldier.maxHp;
    final x = soldier.pos.x;
    g.tick(0.05);
    expect((soldier.retreating, soldier.pos.x > x), (false, true));
  });

  test('with no troop healer on the field, or only one still marching in, nobody falls back', () {
    final (g, priest, soldier) = retreatScene();
    priest.dying = 0;
    soldier.hp = 0.3 * soldier.maxHp;
    g.tick(0.05);
    expect(soldier.retreating, isFalse);

    final (h, marching, other) = retreatScene();
    marching
      ..pos = Point(h.baseX - 2 * tile, marching.pos.y)
      ..entered = false;
    other.hp = 0.3 * other.maxHp;
    for (var i = 0; i < 3; i++) {
      h.tick(0.05);
      expect((marching.entered, other.retreating), (false, false), reason: '$i');
    }
  });

  test('a healer never falls back', () {
    final (g, priest, _) = retreatScene();
    priest.hp = 0.3 * priest.maxHp;
    g.tick(0.05);
    expect(priest.retreating, isFalse);
  });

  test('a falling-back troop still strikes a foe in its reach, but never walks toward one', () {
    final (g, _, soldier) = retreatScene();
    soldier.hp = 0.4 * soldier.maxHp;
    final near = g.monster('slime', Tier.normal, soldier.pos + const Point(10, 0))..busyUntil = hold;
    g.units.add(near);
    final x = soldier.pos.x, hp = near.hp;
    g.tick(0.05);
    expect(soldier.retreating, isTrue);
    expect((near.hp, soldier.attackedAt), (hp - soldier.stats.dmg, g.t));
    expect(soldier.pos.x, lessThan(x)); // backing off toward the healer, away from both foes
  });

  test('a healer patches up those falling back first, even before someone lower on HP', () {
    final g = bare()
      ..gold = 1000
      ..skills = false; // the plain heal, not Healing Prayer (the knight is below its 35%)
    placeNow(g, 'priest', 0, 3);
    placeNow(g, 'soldier', 2, 2);
    placeNow(g, 'knight', 2, 4);
    final [priest, soldier, knight] = g.troops.toList();
    soldier
      ..hp = 0.45 * soldier.maxHp
      ..retreating = true
      ..busyUntil = hold;
    knight
      ..hp = 0.3 * knight.maxHp
      ..retreating = false
      ..busyUntil = hold;
    g.units.add(g.monster('slime', Tier.normal, const Point(200, 56))..busyUntil = hold); // mid-wave
    g.tick(0.05);
    expect(soldier.hp, closeTo(0.45 * soldier.maxHp + priest.stats.dmg, 1e-9));
    expect(knight.hp, 0.3 * knight.maxHp);
  });

  test('once the wave is won nobody is falling back', () {
    final (g, _, soldier) = retreatScene();
    soldier.hp = 0.4 * soldier.maxHp;
    g.tick(0.05);
    expect(soldier.retreating, isTrue);
    for (final e in g.enemies) {
      e.gone = true;
    }
    g.tick(0.05); // won
    g.tick(0.05);
    expect(g.waveActive, isFalse);
    expect(g.troops.where((u) => u.retreating), isEmpty);
  });

  test('the fall-back brain reads its numbers from JSON, keeping the default for any missing, mistyped or out of range; another version is ignored', () {
    const d = RetreatBrain();
    final all = RetreatBrain.parse(jsonEncode({
      'version': RetreatBrain.version,
      'retreatAt': 0.4,
      'returnAt': 0.9,
      'retreatNear': 0.3,
      'threatWindow': 1.5,
      'doomTime': 2.5,
      'doomMaxShare': 0.7,
      'earlyReturnAt': 0.65,
      'lineMin': 3,
      'baseThreat': 1.5,
      'healWait': 4,
      'holdFire': !d.holdFire,
      'carryHealQueue': !d.carryHealQueue,
    }));
    expect(all.toJson(), {
      'version': RetreatBrain.version,
      'retreatAt': 0.4,
      'returnAt': 0.9,
      'retreatNear': 0.3,
      'threatWindow': 1.5,
      'doomTime': 2.5,
      'doomMaxShare': 0.7,
      'earlyReturnAt': 0.65,
      'lineMin': 3,
      'baseThreat': 1.5,
      'healWait': 4.0,
      'holdFire': !d.holdFire,
      'carryHealQueue': !d.carryHealQueue,
    });
    expect(RetreatBrain.parse(jsonEncode(all.toJson())).toJson(), all.toJson()); // a round trip
    final bad = RetreatBrain.parse(jsonEncode({
      'version': RetreatBrain.version,
      'retreatAt': 1.5, // not a share
      'retreatNear': 0, // it could never stop
      'threatWindow': 0, // no window
      'doomTime': -1,
      'lineMin': 2.5, // not a count
      'healWait': 'soon',
      'holdFire': 1,
    }));
    expect(bad.toJson(), d.toJson());
    expect(RetreatBrain.parse(jsonEncode({'version': RetreatBrain.version, 'retreatAt': 0.9, 'returnAt': 0.6})).toJson(), d.toJson(),
        reason: 'back in below falling back: both defaults');
    for (final text in ['', 'not json', '[]', jsonEncode({'version': RetreatBrain.version + 1, 'retreatAt': 0.1}), jsonEncode({'retreatAt': 0.1})]) {
      expect(RetreatBrain.parse(text).toJson(), d.toJson(), reason: text);
    }
  });

  test('the shipped brain file holds the defaults in code', () {
    expect(RetreatBrain.parse(File('assets/ai/retreat.json').readAsStringSync()).toJson(), const RetreatBrain().toJson());
    expect(jsonDecode(File('assets/ai/retreat.json').readAsStringSync()), const RetreatBrain().toJson()); // every number written out
  });

  /// A mid-wave troop's features: far from its only healer, unhurt, with a full line and no monster near.
  RetreatFeatures feat({
    bool retreating = false,
    double hpShare = 1,
    double dpsShare = 0,
    int healers = 1,
    double healerReach = 2,
    double waited = 0,
    int rank = 0,
    int frontFighters = 5,
    double foeToBase = double.infinity,
    bool ranged = false,
    double backRoom = 10,
  }) =>
      (
        retreating: retreating,
        hpShare: hpShare,
        dpsShare: dpsShare,
        healers: healers,
        healerReach: healerReach,
        waited: waited,
        rank: rank,
        frontFighters: frontFighters,
        foeToBase: foeToBase,
        ranged: ranged,
        backRoom: backRoom,
      );

  /// Every part of the rule on, at the default numbers.
  const everyPart = RetreatBrain(doomTime: 2, lineMin: 2, baseThreat: 2, healWait: 3, holdFire: true);
  const fight = RetreatAction.fight, back = RetreatAction.fallBack, backFighting = RetreatAction.fallBackFighting;

  test('the rule: with no troop healer a troop fights on; else it falls back at retreatAt and goes back in at returnAt', () {
    for (final b in [RetreatBrain.old, everyPart]) {
      final p = RuleRetreatPolicy(b);
      final b2 = p.brain;
      expect(p.decide(feat(healers: 0, hpShare: 0.1)), fight);
      expect(p.decide(feat(hpShare: b2.retreatAt + 0.01)), fight);
      expect(p.decide(feat(hpShare: b2.retreatAt)), isNot(fight));
      expect(p.decide(feat(retreating: true, hpShare: b2.returnAt - 0.01, frontFighters: 5)), isNot(fight));
      expect(p.decide(feat(retreating: true, hpShare: b2.returnAt)), fight);
    }
  });

  test('the rule: below doomMaxShare a troop that would fall within doomTime falls back early, unless the base is threatened; doomTime 0 never', () {
    const p = RuleRetreatPolicy(everyPart);
    final share = (everyPart.retreatAt + everyPart.doomMaxShare) / 2, deadly = share / everyPart.doomTime;
    expect(p.decide(feat(hpShare: share, dpsShare: deadly)), isNot(fight));
    expect(p.decide(feat(hpShare: share, dpsShare: deadly * 0.99)), fight);
    expect(p.decide(feat(hpShare: everyPart.doomMaxShare, dpsShare: 1)), fight); // not that hurt yet
    expect(p.decide(feat(hpShare: share, dpsShare: deadly, foeToBase: everyPart.baseThreat / 2)), fight);
    expect(const RuleRetreatPolicy(RetreatBrain.old).decide(feat(hpShare: share, dpsShare: 1)), fight);
    // Falling back, deadly damage keeps it back even past earlyReturnAt with the line gone.
    expect(p.decide(feat(retreating: true, hpShare: everyPart.returnAt - 0.01, dpsShare: 1, frontFighters: 0)), isNot(fight));
  });

  test('the rule: heals that don\'t come send the healthiest one at the healer back in from earlyReturnAt after healWait s; healWait 0 never', () {
    const p = RuleRetreatPolicy(everyPart);
    final waiting = feat(retreating: true, hpShare: everyPart.earlyReturnAt, healerReach: everyPart.retreatNear, waited: everyPart.healWait);
    expect(p.decide(waiting), fight);
    for (final (why, f) in [
      ('not long enough', feat(retreating: true, hpShare: everyPart.earlyReturnAt, healerReach: everyPart.retreatNear, waited: everyPart.healWait - 0.1)),
      ('a healthier one goes first', feat(retreating: true, hpShare: everyPart.earlyReturnAt, healerReach: everyPart.retreatNear, waited: everyPart.healWait, rank: 1)),
      ('too hurt', feat(retreating: true, hpShare: everyPart.earlyReturnAt - 0.01, healerReach: everyPart.retreatNear, waited: everyPart.healWait)),
      ('deadly damage', feat(retreating: true, hpShare: everyPart.earlyReturnAt, healerReach: everyPart.retreatNear, waited: everyPart.healWait, dpsShare: 1)),
    ]) {
      expect(p.decide(f), isNot(fight), reason: why);
    }
    expect(const RuleRetreatPolicy(RetreatBrain(healWait: 0)).decide(waiting), isNot(fight));
  });

  test('the rule: a collapsing line or a threatened base brings a falling-back troop back in; lineMin and baseThreat 0 never', () {
    const p = RuleRetreatPolicy(everyPart);
    final ok = everyPart.earlyReturnAt;
    expect(p.decide(feat(retreating: true, hpShare: ok, frontFighters: everyPart.lineMin - 1)), fight);
    expect(p.decide(feat(retreating: true, hpShare: ok, frontFighters: everyPart.lineMin)), isNot(fight));
    expect(p.decide(feat(retreating: true, hpShare: ok - 0.01, frontFighters: 0)), isNot(fight)); // too hurt for the line
    // A monster at the base: anything above retreatAt goes, deadly damage or not.
    final near = everyPart.baseThreat / 2;
    expect(p.decide(feat(retreating: true, hpShare: everyPart.retreatAt + 0.01, dpsShare: 1, foeToBase: near)), fight);
    expect(p.decide(feat(retreating: true, hpShare: everyPart.retreatAt, foeToBase: near)), isNot(fight));
    const off = RuleRetreatPolicy(RetreatBrain(lineMin: 0, baseThreat: 0));
    expect(off.decide(feat(retreating: true, hpShare: ok, frontFighters: 0, foeToBase: 0)), isNot(fight));
  });

  test('the rule: falling back, a melee troop strikes only when cornered, a ranged one always; with holdFire off everyone does', () {
    const p = RuleRetreatPolicy(everyPart);
    final hurt = everyPart.retreatAt;
    expect(p.decide(feat(hpShare: hurt)), back);
    expect(p.decide(feat(hpShare: hurt, ranged: true)), backFighting);
    expect(p.decide(feat(hpShare: hurt, healerReach: everyPart.retreatNear)), backFighting); // at the healer
    expect(p.decide(feat(hpShare: hurt, backRoom: 0.5)), backFighting); // at the back line
    expect(const RuleRetreatPolicy(RetreatBrain(holdFire: false)).decide(feat(hpShare: hurt)), backFighting);
  });

  test('the game asks its RetreatPolicy, mid-wave only: a troop falls back or fights on as told', () {
    final (g, priest, soldier) = retreatScene();
    g.retreatPolicy = _SpyPolicy(RetreatAction.fallBack);
    final d = soldier.pos.distanceTo(priest.pos);
    g.tick(0.05);
    expect(soldier.retreating, isTrue); // unhurt, but told to
    expect(soldier.pos.distanceTo(priest.pos), lessThan(d));

    final (h, _, hurt) = retreatScene();
    h.retreatPolicy = _SpyPolicy(RetreatAction.fight);
    hurt.hp = 0.1 * hurt.maxHp;
    final x = hurt.pos.x;
    h.tick(0.05);
    expect((hurt.retreating, hurt.pos.x > x), (false, true)); // on toward its foe

    final between = bare()..gold = 1000;
    placeNow(between, 'priest', 0, 3);
    placeNow(between, 'soldier', 4, 3);
    final spy = between.retreatPolicy = _SpyPolicy(RetreatAction.fallBack);
    between.tick(0.05);
    expect(spy.asked, isEmpty); // no wave: nobody asks
    expect(between.troops.any((u) => u.retreating), isFalse);
  });

  test('the features the policy reads: HP, damage over threatWindow, healers, reach, time waited at the spot, rank, the line, the base, room behind', () {
    final (g, priest, soldier) = retreatScene();
    final spy = g.retreatPolicy = _SpyPolicy(RetreatAction.fight);
    soldier.cd = hold; // it never strikes back
    final orc = g.monster('orc', Tier.normal, soldier.pos + Point(enemyTypes['orc']!.range, 0))..entered = true;
    g.units.add(orc);
    g.tick(0.05); // the orc strikes
    orc.busyUntil = hold; // once
    final hit = hitTaken(orc.stats.dmg, soldier.stats.def), window = spy.brain.threatWindow;
    expect(soldier.maxHp - soldier.hp, hit);
    g.tick(0.05);
    var f = spy.asked.last;
    expect(f.hpShare, soldier.hp / soldier.maxHp);
    expect(f.dpsShare, closeTo(hit / window / soldier.maxHp, 1e-12));
    expect((f.retreating, f.healers, f.frontFighters, f.ranged, f.rank, f.waited), (false, 1, 1, false, 0, 0.0));
    expect(f.healerReach, closeTo(soldier.pos.distanceTo(priest.pos) / priest.stats.range, 1e-12));
    expect(f.foeToBase, closeTo((orc.pos.x - g.baseX) / tile, 1e-12));
    expect(f.backRoom, closeTo((soldier.pos.x - g.baseX) / tile, 1e-12));
    while (g.t < window + 0.1) {
      g.tick(0.05);
    }
    expect(spy.asked.last.dpsShare, 0); // the blow is out of the window

    // Falling back to the priest with a second one: at its spot the healthier ranks first, and the time
    // waited there without a heal counts up.
    final (h, hp, lead) = retreatScene();
    placeNow(h, 'knight', 4, 6); // its spot by the priest clear of the soldier's
    final other = h.troops.last;
    final hs = h.retreatPolicy = _SpyPolicy(RetreatAction.fallBack);
    lead.hp = 0.7 * lead.maxHp;
    other.hp = 0.6 * other.maxHp;
    double? arrived;
    for (var i = 0; i < 400 && (arrived == null || h.t - arrived < 1); i++) {
      h.tick(0.05);
      if (arrived == null && [lead, other].every((u) => u.pos.distanceTo(hp.pos) <= hp.stats.range * retreatNear)) arrived = h.t;
    }
    expect(arrived, isNotNull);
    final [fl, fo] = hs.asked.sublist(hs.asked.length - 2); // this tick: the soldier, then the knight
    expect((fl.retreating, fo.retreating, fl.rank, fo.rank, fl.frontFighters), (true, true, 0, 1, 0));
    expect(fl.waited, greaterThanOrEqualTo(h.t - arrived! - 0.05));
    expect(fl.healerReach, lessThanOrEqualTo(retreatNear));
    lead.healedAt = h.t; // a heal: the wait starts over
    h.tick(0.05);
    expect(hs.asked[hs.asked.length - 2].waited, closeTo(0.05, 1e-9));
  });

  test('heals that don\'t come: after healWait s at the priest without one a troop from earlyReturnAt goes back in; one below it waits on', () {
    final (g, priest, soldier) = retreatScene(); // the priest never heals
    placeNow(g, 'knight', 4, 6);
    final knight = g.troops.last;
    const brain = RetreatBrain(doomTime: 0, lineMin: 0, baseThreat: 0, healWait: 3, holdFire: false);
    g.retreatPolicy = const RuleRetreatPolicy(brain);
    soldier.hp = brain.retreatAt * soldier.maxHp;
    knight.hp = brain.retreatAt * knight.maxHp;
    g.tick(0.05); // both fall back
    soldier.hp = brain.earlyReturnAt * soldier.maxHp; // then got some heals
    knight.hp = brain.earlyReturnAt * knight.maxHp - 1;
    double? arrived;
    for (var i = 0; i < 400 && soldier.retreating; i++) {
      g.tick(0.05);
      if (arrived == null && soldier.pos.distanceTo(priest.pos) <= priest.stats.range * brain.retreatNear) arrived = g.t;
    }
    expect(arrived, isNotNull);
    expect(g.t - arrived!, inInclusiveRange(brain.healWait, brain.healWait + 0.2));
    expect((soldier.retreating, knight.retreating), (false, true));
  });

  test('with carryHealQueue a new wave leaves the after-wave heals to come and the healers go on with them; without, it drops them', () {
    for (final carry in [true, false]) {
      final g = bare()
        ..gold = 1000
        ..retreatPolicy = RuleRetreatPolicy(RetreatBrain(carryHealQueue: carry));
      placeNow(g, 'priest', 0, 3);
      placeNow(g, 'knight', 3, 3);
      final knight = g.troops.last..hp = 50;
      winWave(g);
      expect(g.healQueue, contains(knight)); // still cheering: nobody healed yet
      g.startWave();
      expect(g.healQueue.contains(knight), carry);
      // Past the cheering and one heal's gap more (the priest may have just healed the knight as it ended),
      // but too short for the priest's own heals to fill the knight up.
      for (var i = 0; i < (victoryTime + 2 * troopTypes['priest']!.rate) / 0.05; i++) {
        g.tick(0.05);
      }
      expect(knight.hp == knight.maxHp, carry, reason: 'carry $carry');
    }
  });

  /// What a Hero or its aura multiplies, then what it leaves alone.
  List<num> boostable(Stats s) => [s.hp, s.dmg, s.def, s.regen, s.mp, s.mpRegen, s.speed, s.rate, s.range, s.splash, s.shotSpeed, s.cost];

  /// A knight, an archer and a priest (in that order) standing, with [heroes] as the Hero dice.
  Game heroGame(Random heroes, [Random? rng]) {
    final g = bare(rng)
      ..gold = 10000
      ..heroes = heroes;
    placeNow(g, 'knight', 2, 3);
    placeNow(g, 'archer', 1, 3);
    placeNow(g, 'priest', 0, 3);
    return g;
  }

  /// Starts wave [wave] (with nothing in it, so the next can start at once).
  void startAt(Game g, int wave) {
    g
      ..wave = wave - 1
      ..startWave()
      ..queue.clear();
  }

  /// Wins wave [wave] at once: started with nothing in it but one monster already beaten, and a tick of no
  /// time, so the win happens and nothing moves. Winning every [heroEvery]th wave makes a Hero.
  void winAt(Game g, int wave) {
    startAt(g, wave);
    g.units.add(Unit(Side.enemy, 'slime', enemyTypes['slime']!, const Point(200.0, 60.0))..gone = true);
    g.tick(0);
  }

  test('when every heroEvery-th wave is won one living troop that isn\'t a Hero yet becomes one, by the heroes dice', () {
    for (final seed in [1, 2, 3]) {
      final g = heroGame(Random(seed)), dice = Random(seed);
      for (var w = 1; w < heroEvery; w++) {
        startAt(g, w);
        expect(g.troops.where((u) => u.hero), isEmpty, reason: 'seed $seed wave $w');
      }
      final first = [...g.troops][dice.nextInt(3)];
      for (var i = 0; i < heroStatCount; i++) {
        dice.nextInt(heroPoolOf(first.type).length - i); // its attributes, rolled with the same dice
      }
      dice.nextInt(heroSkillPool(first.type).length); // then its own skill (#48)
      winAt(g, heroEvery);
      expect(g.troops.where((u) => u.hero), [first], reason: 'seed $seed');
      startAt(g, heroEvery + 1);
      expect(g.troops.where((u) => u.hero), [first], reason: 'seed $seed');
      final second = [for (final u in g.troops) if (!u.hero) u][dice.nextInt(2)];
      winAt(g, 2 * heroEvery);
      expect(g.troops.where((u) => u.hero).toSet(), {first, second}, reason: 'seed $seed');
    }
    final empty = bare();
    winAt(empty, heroEvery);
    expect(empty.heroMade, isEmpty); // nobody to crown, and no error
  });

  test('a Hero has heroBoost times the heroStatCount attributes it rolled from its pool, the rest as they are', () {
    for (final (type, pick) in [('knight', 0), ('archer', 43)]) { // 43: the archer (43 % 3), rolling range then MP
      final g = heroGame(_Dice(0, pick));
      winAt(g, heroEvery);
      final h = g.troops.singleWhere((u) => u.hero), s = h.stats, base = g.statsOf(type), pool = heroPoolOf(type);
      expect(h.type, type);
      expect(h.heroStats, [for (var i = 0; i < heroStatCount; i++) pool.removeAt(pick % pool.length)], reason: type);
      num up(HeroStat a, num plain, num x3) => h.heroStats.contains(a) ? x3 : plain;
      expect((s.hp, h.maxHp), (up(HeroStat.hp, base.hp, (base.hp * heroBoost).round()), s.hp), reason: type);
      expect([s.dmg, s.def, s.rate, s.speed, s.range], [
        up(HeroStat.power, base.dmg, base.dmg * heroBoost),
        up(HeroStat.defence, base.def, base.def * heroBoost),
        up(HeroStat.rate, base.rate, base.rate / heroBoost),
        up(HeroStat.speed, base.speed, base.speed * heroBoost),
        up(HeroStat.range, base.range, base.range * heroBoost),
      ], reason: type);
      expect((s.mp, s.mpRegen), (up(HeroStat.mp, base.mp, (base.mp * heroBoost).round()), up(HeroStat.mp, base.mpRegen, base.mpRegen * heroBoost)),
          reason: type); // the archer rolls range and MP
      expect((s.regen, s.splash, s.shotSpeed, s.cost), (base.regen, base.splash, base.shotSpeed, base.cost), reason: type);
    }
  });

  test('while a Hero lives every other troop has the aura, troops bought later too, and two Heroes don\'t add up', () {
    final g = heroGame(_Dice(0, 0));
    winAt(g, heroEvery); // the knight
    expect(g.autoPlace('soldier'), isTrue);
    for (final u in g.troops.where((u) => !u.hero)) {
      expect(boostable(u.stats), boostable(g.statsOf(u.type).boosted(auraBoost)), reason: u.type);
    }
    winAt(g, 2 * heroEvery); // the archer, first of those left
    expect(g.troops.where((u) => u.hero).map((u) => u.type), ['knight', 'archer']);
    for (final u in g.troops.where((u) => !u.hero)) {
      expect(boostable(u.stats), boostable(g.statsOf(u.type).boosted(auraBoost)), reason: u.type);
    }
  });

  test('when the last Hero falls the aura ends without killing anyone; while another lives it stays', () {
    final g = heroGame(_Dice(0, 0))..skills = false; // no Healing Prayer to save the knight at 1 HP
    winAt(g, heroEvery);
    final [knight, archer, priest] = g.troops.toList();
    expect(archer.hp, archer.maxHp); // full with the aura's HP
    knight.hp = 1;
    g.units.add(Unit(Side.enemy, 'werebear', enemyTypes['werebear']!, knight.pos + const Point(10, 0)));
    g.tick(0.05);
    expect(knight.alive, isFalse);
    for (final u in [archer, priest]) {
      expect(boostable(u.stats), boostable(g.statsOf(u.type)), reason: u.type);
      expect((u.alive, u.hp <= u.maxHp), (true, true), reason: u.type);
    }
    expect(archer.hp, archer.maxHp);

    final h = heroGame(_Dice(0, 0))..skills = false;
    winAt(h, heroEvery);
    winAt(h, 2 * heroEvery); // knight, then archer
    final [k, _, p] = h.troops.toList();
    k.hp = 1;
    h.units.add(Unit(Side.enemy, 'werebear', enemyTypes['werebear']!, k.pos + const Point(10, 0)));
    h.tick(0.05);
    expect(k.alive, isFalse);
    expect(boostable(p.stats), boostable(h.statsOf('priest').boosted(auraBoost)));
  });

  test('a troop made a Hero gains the HP and MP it adds: a full one stays full, a hurt one gains the difference', () {
    final g = heroGame(_Dice(0, 0));
    final [knight, archer, priest] = g.troops.toList();
    knight
      ..hp = 70
      ..mp = 10;
    priest.busyUntil = hold; // no heal in the winning tick
    final (maxHp, maxMp) = (knight.maxHp, knight.stats.mp);
    winAt(g, heroEvery);
    expect(knight.hp, 70 + knight.maxHp - maxHp);
    expect(knight.mp, 10 + knight.stats.mp - maxMp);
    expect(archer.hp, archer.maxHp);
  });

  test('the save keeps each Hero, its stats and its HP; an older save has none', () {
    final g = heroGame(_Dice(0, 0));
    winAt(g, heroEvery);
    final knight = g.troops.first..hp = 200;
    final j = jsonDecode(jsonEncode(g.toJson())) as Map<String, dynamic>;
    final l = Game.fromJson(j);
    final [lk, la, _] = l.troops.toList();
    expect((lk.hero, la.hero, lk.hp), (true, false, 200.0));
    expect(boostable(lk.stats), boostable(knight.stats));
    expect(boostable(la.stats), boostable(l.statsOf('archer').boosted(auraBoost)));

    for (final t in j['troops'] as List) {
      (t as Map).remove('hero');
    }
    final old = Game.fromJson(j);
    expect(old.troops.where((u) => u.hero), isEmpty);
    expect(identical(old.troops.first.stats, troopTypes['knight']), isTrue);
    expect(old.troops.first.hp, troopTypes['knight']!.hp); // capped at its plain most
  });

  test('a Hero is announced, and the book knows which type has a living one', () {
    final g = heroGame(_Dice(0, 1));
    expect((g.heroAlive, g.hasHero('archer'), g.heroMade.isEmpty), (false, false, true));
    g.sfx.clear();
    winAt(g, heroEvery);
    final h = g.troops.singleWhere((u) => u.hero);
    expect((h.type, g.heroMade.single, g.heroAlive, g.hasHero('archer'), g.hasHero('knight')), ('archer', h, true, true, false));
    expect(g.sfx, contains(Sfx.clear));
    expect(g.impacts, contains((h.pos, 'upgrade')));
    h.dying = 0;
    expect((g.heroAlive, g.hasHero('archer')), (false, false));
  });

  test('each troop made a Hero is announced exactly once, when its wave is won', () {
    final g = heroGame(_Dice(0, 0));
    winAt(g, heroEvery); // the knight
    final first = g.troops.singleWhere((u) => u.hero);
    expect(g.heroMade, [first]);
    g.heroMade.clear(); // the Board takes it
    for (var w = heroEvery + 1; w < 2 * heroEvery; w++) {
      startAt(g, w);
      expect(g.heroMade, isEmpty, reason: 'wave $w');
    }
    winAt(g, 2 * heroEvery);
    final second = g.troops.singleWhere((u) => u.hero && u != first);
    expect(g.heroMade, [second]);
  });

  test('the Hero comes when the heroEvery-th wave is won, not when it starts, and never with a lost game', () {
    final g = heroGame(_Dice(0, 0));
    startAt(g, heroEvery);
    g.units.add(Unit(Side.enemy, 'slime', enemyTypes['slime']!, const Point(200.0, 60.0)));
    g.tick(0.05);
    expect((g.waveActive, g.troops.any((u) => u.hero), g.heroMade.isEmpty), (true, false, true)); // on: no Hero yet
    g.enemies.single.gone = true;
    g.tick(0.05); // won
    expect(g.troops.where((u) => u.hero).length, 1);
    expect(g.heroMade.length, 1);

    final z = heroGame(_Dice(0, 0));
    winAt(z, 0); // before the first wave (a test's): wave 0 is no heroEvery-th wave
    expect((z.troops.any((u) => u.hero), z.heroMade.isEmpty), (false, true));

    final l = heroGame(_Dice(0, 0))..lives = 1;
    startAt(l, heroEvery);
    for (final u in l.troops.toList()) {
      u.hp = 1; // a werebear by each: the army falls, and that costs the last life
      l.units.add(Unit(Side.enemy, 'werebear', enemyTypes['werebear']!, u.pos + const Point(10, 0))..entered = true);
    }
    for (var i = 0; i < 100 && !l.over; i++) {
      l.tick(0.05);
    }
    expect((l.over, l.troops.where((u) => u.hero).isEmpty, l.heroMade.isEmpty), (true, true, true));
  });

  test('at most heroMax Heroes live at once: with that many the win crowns nobody; one falling frees its place', () {
    expect((heroEvery, heroMax), (10, 5)); // a Hero when every 10th wave is won, while fewer than 5 live
    final g = heroGame(_Dice(0, 0));
    for (final (i, t) in ['soldier', 'lancer', 'wizard'].indexed) {
      expect(placeNow(g, t, i, 4), isTrue, reason: t); // six troops: one left to crown
    }
    int living() => g.troops.where((u) => u.alive && u.hero).length;
    for (var n = 1; n <= heroMax; n++) {
      winAt(g, n * heroEvery);
      expect(living(), n, reason: 'crowning $n');
    }
    g.heroMade.clear();
    winAt(g, (heroMax + 1) * heroEvery);
    expect((living(), g.heroMade.isEmpty), (heroMax, true)); // full: nobody, so no splash
    g.troops.firstWhere((u) => u.hero).dying = 0; // one falls
    winAt(g, (heroMax + 2) * heroEvery);
    expect((living(), g.heroMade.length), (heroMax, 1)); // its place taken by the sixth troop
  });

  test('a loaded game announces no Hero, not even an old one that rolls its attributes on load', () {
    final g = heroGame(_Dice(0, 0));
    winAt(g, heroEvery);
    final j = jsonDecode(jsonEncode(g.toJson())) as Map<String, dynamic>;
    expect(Game.fromJson(j).heroMade, isEmpty);
    ((j['troops'] as List).first as Map).remove('heroStats'); // saved before the roll
    final old = Game.fromJson(j), knight = old.troops.first;
    expect((knight.hero, knight.heroStats.length), (true, heroStatCount)); // rolled now
    expect(old.heroMade, isEmpty);
  });

  test('the Hero dice never change the waves, and the same dice pick the same troop', () {
    List<(String, Tier)> wave10(int heroes) {
      final g = heroGame(Random(heroes), Random(7))..slots = Random(1);
      startAt(g, heroEvery - 1);
      g.startWave();
      return [...g.queue];
    }

    expect(wave10(1), wave10(2));
    String picked(int heroes) {
      final g = heroGame(Random(heroes));
      winAt(g, heroEvery);
      return g.troops.singleWhere((u) => u.hero).type;
    }

    expect(picked(3), picked(3));
  });

  test('boosting by 1 is the stats themselves', () {
    for (final s in [...troopTypes.values, ...enemyTypes.values]) {
      expect(identical(s.boosted(1), s), isTrue);
    }
  });

  /// The values Hero attribute [h] stands for in [s] (MP comes with its regen).
  List<num> attribute(Stats s, HeroStat h) => switch (h) {
        HeroStat.hp => [s.hp],
        HeroStat.power => [s.dmg],
        HeroStat.defence => [s.def],
        HeroStat.rate => [s.rate],
        HeroStat.speed => [s.speed],
        HeroStat.range => [s.range],
        HeroStat.mp => [s.mp, s.mpRegen],
      };

  /// Expects [got] to be [base] with the [picked] attributes as [Stats.boosted] by [heroBoost] makes them and
  /// every other one (regen too) as boosted by [rest]; what nothing boosts stays.
  void expectHeroic(Stats got, Stats base, Iterable<HeroStat> picked, double rest, String reason) {
    for (final h in HeroStat.values) {
      expect(attribute(got, h), attribute(picked.contains(h) ? base.boosted(heroBoost) : base.boosted(rest), h), reason: '$reason: $h');
    }
    expect(got.regen, base.boosted(rest).regen, reason: '$reason: regen');
    expect([got.splash, got.shotSpeed, got.cost], [base.splash, base.shotSpeed, base.cost], reason: reason);
  }

  test('a Hero\'s pool holds only what its role uses: never reach for melee, defence only with shields in the recipe, MP only while heroMp, never attack rate', () {
    final noDefence = <String>[];
    for (final type in troopTypes.keys) {
      final s = troopTypes[type]!, pool = heroPoolOf(type);
      expect(pool.toSet().length, pool.length, reason: '$type: nothing twice');
      expect(pool, containsAll([HeroStat.hp, HeroStat.power, HeroStat.speed]), reason: type); // a healer's power is its heal
      expect(pool, isNot(contains(HeroStat.rate)), reason: type); // #69
      expect(pool.contains(HeroStat.range), !s.melee, reason: type);
      final shields = awakenRecipe[type]!.containsKey(Item.shield);
      expect(pool.contains(HeroStat.defence), shields, reason: type);
      if (!shields) {
        noDefence.add(type);
        expect(s.def, 0, reason: '$type: no shields, so its defence stays 0 and x$heroBoost would do nothing');
      }
      expect(pool.contains(HeroStat.mp), heroMp, reason: type);
    }
    expect(noDefence, unorderedEquals(['swordsman', 'archer', 'wizard']));
  });

  test('a Hero rolls heroStatCount different attributes from its pool, whatever the dice, and the same dice roll the same', () {
    List<HeroStat> crown(String type, int seed) {
      final g = bare()
        ..gold = 10000
        ..heroes = Random(seed);
      expect(placeNow(g, type, 2, 3), isTrue, reason: type);
      winAt(g, heroEvery);
      final h = g.troops.single;
      expect(h.hero, isTrue, reason: type);
      expectHeroic(h.stats, g.statsOf(type), h.heroStats, 1, '$type seed $seed'); // alone: no aura on the rest
      return h.heroStats;
    }

    for (final type in troopTypes.keys) {
      for (var seed = 0; seed < 20; seed++) {
        final rolled = crown(type, seed), why = '$type seed $seed: $rolled';
        expect(rolled.length, heroStatCount, reason: why);
        expect(rolled.toSet().length, heroStatCount, reason: why);
        expect(heroPoolOf(type), containsAll(rolled), reason: why);
        expect(crown(type, seed), rolled, reason: why);
      }
    }
  });

  test('a Hero\'s attributes it didn\'t roll have the aura while another Hero lives, its rolled ones heroBoost alone', () {
    final g = heroGame(_Dice(0, 0))..skills = false; // no Healing Prayer to save the knight at 1 HP
    winAt(g, heroEvery);
    winAt(g, 2 * heroEvery); // the knight, then the archer
    final [knight, archer, _] = g.troops.toList();
    for (final h in [knight, archer]) {
      expect(h.hero, isTrue, reason: h.type);
      expectHeroic(h.stats, g.statsOf(h.type), h.heroStats, auraBoost, h.type); // not heroBoost × auraBoost
    }
    knight.hp = 1;
    g.units.add(Unit(Side.enemy, 'werebear', enemyTypes['werebear']!, knight.pos + const Point(10, 0)));
    g.tick(0.05);
    expect(knight.alive, isFalse);
    expectHeroic(archer.stats, g.statsOf('archer'), archer.heroStats, 1, 'the archer, the last Hero');
  });

  test('a Hero saved before the roll rolls heroStatCount attributes from its pool on load, its HP capped to its new most', () {
    final g = heroGame(_Dice(0, 0));
    winAt(g, heroEvery); // the knight
    final base = g.statsOf('knight'), allUp = base.boosted(heroBoost).hp; // a Hero had every attribute up then
    final j = jsonDecode(jsonEncode(g.toJson())) as Map<String, dynamic>;
    final saved = (j['troops'] as List).first as Map<String, dynamic>;
    expect((saved['hero'], saved.containsKey('heroStats')), (true, true));
    saved
      ..remove('heroStats')
      ..['hp'] = allUp;
    for (var i = 0; i < 20; i++) {
      final l = Game.fromJson(j), k = l.troops.first, rolled = k.heroStats, why = 'load $i: $rolled';
      expect(k.hero, isTrue, reason: why);
      expect(rolled.length, heroStatCount, reason: why);
      expect(rolled.toSet().length, heroStatCount, reason: why);
      expect(heroPoolOf('knight'), containsAll(rolled), reason: why);
      expectHeroic(k.stats, l.statsOf('knight'), rolled, 1, why);
      expect(k.maxHp, rolled.contains(HeroStat.hp) ? allUp : base.hp, reason: why);
      expect(k.hp, k.maxHp, reason: why); // capped
    }
  });

  test('the save keeps a Hero\'s rolled attributes in their order; saving draws no Hero dice and loading rolls none', () {
    final g = heroGame(_Dice(0, 4)); // the archer, rolling MP then HP (MP last in its pool)
    winAt(g, heroEvery);
    final h = g.troops.singleWhere((u) => u.hero), rolled = h.heroStats, pool = heroPoolOf(h.type);
    expect(pool.indexOf(rolled.first), greaterThan(pool.indexOf(rolled.last))); // not in the pool's order
    final j = jsonDecode(jsonEncode(g.toJson())) as Map<String, dynamic>;
    final l = Game.fromJson(j), lh = l.troops.singleWhere((u) => u.hero);
    expect(lh.heroStats, rolled);
    expect(boostable(lh.stats), boostable(h.stats));

    final other = [for (final s in pool) if (!rolled.contains(s)) s].take(heroStatCount).toList();
    for (final t in j['troops'] as List) {
      if ((t as Map)['hero'] == true) t['heroStats'] = [for (final s in other) s.name];
    }
    final og = Game.fromJson(j), o = og.troops.singleWhere((u) => u.hero);
    expect(o.heroStats, other); // as saved, not rolled again
    expectHeroic(o.stats, og.statsOf(o.type), other, 1, 'as saved'); // the only Hero: no aura on the rest

    for (final seed in [1, 2, 3]) {
      final d = heroGame(Random(seed)), dice = Random(seed);
      final first = [...d.troops][dice.nextInt(d.troops.length)];
      for (var i = 0; i < heroStatCount; i++) {
        dice.nextInt(heroPoolOf(first.type).length - i);
      }
      dice.nextInt(heroSkillPool(first.type).length); // its own skill (#48)
      winAt(d, heroEvery);
      Game.fromJson(jsonDecode(jsonEncode(d.toJson())) as Map<String, dynamic>);
      expect(d.heroes.nextDouble(), dice.nextDouble(), reason: 'seed $seed');
    }
  });

  test('heroic raises only the attributes picked: none leaves the stats, rate divides, a melee reach stays capped, HP leaves regen, MP brings its regen', () {
    var capped = 0;
    for (final type in troopTypes.keys) {
      final s = troopTypes[type]!;
      expect(boostable(s.heroic({}, heroBoost)), boostable(s.boosted(1)), reason: type);
      for (final h in HeroStat.values) {
        expectHeroic(s.heroic({h}, heroBoost), s, [h], 1, '$type $h');
        expectHeroic(s.heroic({h}, heroBoost, auraBoost), s, [h], auraBoost, '$type $h with the aura');
      }
      expect(s.heroic({HeroStat.rate}, heroBoost).rate, s.rate / heroBoost, reason: type);
      final hp = s.heroic({HeroStat.hp}, heroBoost), mp = s.heroic({HeroStat.mp}, heroBoost);
      expect((hp.hp, hp.regen), ((s.hp * heroBoost).round(), s.regen), reason: type);
      expect((mp.mp, mp.mpRegen), ((s.mp * heroBoost).round(), s.mpRegen * heroBoost), reason: type);
      if (s.melee && s.range * heroBoost > meleeMaxRange) {
        expect(s.heroic({HeroStat.range}, heroBoost).range, meleeMaxRange, reason: type);
        capped++;
      }
    }
    expect(capped, greaterThan(0));
  });

  test('the lives the hearts show: startLives in a new game; a monster at the back line costs none (decisions-log 329)', () {
    expect(Game().lives, Game.startLives);
    final g = bare();
    expect(placeNow(g, 'knight', 2, 3), isTrue);
    g.troops.single.busyUntil = hold; // stays put
    final at = [for (var i = 0; i < 4; i++) Unit(Side.enemy, 'slime', enemyTypes['slime']!, Point(g.baseX - 1, fieldH / 2 + 8 * i))];
    g.units.addAll(at); // over the line, as one was that leaked
    g.tick(0.05);
    expect((g.lives, g.over), (Game.startLives, false));
    expect(at.every((u) => u.alive && u.pos.x >= g.baseX), isTrue, reason: 'the line holds them');
  });

  test('a wave nobody can finish stalls after stallTime: its monsters charge the back line, and marchMax s on the wave '
      'is lost', () {
    final g = Game(Random(1)); // the free priest alone: it can't hurt a bat and outheals its bites
    g.startWave();
    g.queue
      ..clear()
      ..add(('bat', Tier.normal));
    final start = g.t;
    g.tick(1 / 30);
    g.enemies.single.pos = Point(g.viewW / 2, fieldH / 2); // mid-screen, clear of the right-edge limit
    double? marchedAt;
    for (var i = 0; i < (stallTime + 90) * 30 && g.waveActive; i++) {
      g.tick(1 / 30);
      if (g.marching && marchedAt == null) {
        marchedAt = g.t;
        expect(g.newMarch, isTrue);
      }
    }
    expect(marchedAt, isNotNull);
    expect(marchedAt! - start, greaterThan(stallTime));
    expect(g.t - marchedAt, inInclusiveRange(marchMax, marchMax + 0.05));
    expect(g.troops.single.alive, isTrue);
    expect((g.waveActive, g.over, g.lives, g.marching, g.wipeCause, g.wave), (false, false, Game.startLives - wipeLives, false, WipeCause.slow, 0));
  });

  test('a wave the army wins never marches, a boss wave neither', () {
    final g = Game(Random(1))..gold = 1000;
    g
      ..autoPlace('knight')
      ..autoPlace('archer')
      ..startWave();
    run(g, each: (g) => expect(g.marching, isFalse, reason: 'wave 1 at ${g.t}'));
    expect((g.waveActive, g.over), (false, false));

    final b = wide(Random(1))..gold = 100000;
    for (final type in [...List.filled(6, 'knight'), ...List.filled(4, 'archer'), 'wizard', 'wizard', 'knight_templar', 'knight_templar']) {
      expect(b.autoPlace(type), isTrue);
    }
    for (var i = 0; i < 200; i++) {
      b.tick(0.05); // everyone at their spots
    }
    b
      ..slots = _Dice(0, 0) // the boss slot's necromancer roll: before [necroBossFrom] a type of the pool,
      ..wave = bossEvery - 1
      ..startWave();
    // so the necromancer goes in its place: wave 5 as it was before decisions-log 176 (the same dice). At wave 10 this
    // fresh army of 14 loses to it.
    b.queue[b.queue.indexWhere((m) => m.$2 == Tier.boss)] = (boss, Tier.boss);
    run(b, each: (g) => expect(g.marching, isFalse, reason: 'boss wave at ${g.t}'));
    expect((b.waveActive, b.over), (false, false));
  });

  test('raised minions falling never count as the wave\'s progress', () {
    final g = bare()..gold = 1000;
    placeNow(g, 'knight', 2, 3);
    final knight = g.troops.single;
    g.startWave();
    g.queue.clear();
    final necro = g.monster(boss, Tier.boss, const Point(280, 60))..busyUntil = hold; // never moves or casts
    g.units.add(necro);
    final start = g.t;
    while (!g.marching && g.t - start < stallTime + 2) {
      if (g.minionsOf(necro).isEmpty) {
        g.units.add(Unit(Side.enemy, minion, const Stats(hp: 50, cost: 0, speed: 20, dmg: 8, range: 12, rate: 0.9), knight.pos + const Point(10, 0))
          ..raisedBy = necro
          ..hp = 1
          ..busyUntil = hold);
      }
      g.tick(0.05);
    }
    expect(g.kills, greaterThan(10)); // they kept dying
    expect(g.marching, isTrue);
    expect(g.t - start, inInclusiveRange(stallTime, stallTime + 1));
  });

  test('a spawn is progress: while the queue still spawns the wave never marches', () {
    final g = bare()..startWave();
    g.queue
      ..clear()
      ..addAll(List.filled((1.5 * stallTime / Game.spawnGap).ceil(), ('slime', Tier.normal)));
    void standStill() {
      for (final e in g.enemies) {
        e.busyUntil = hold; // every monster stands still
      }
    }

    while (g.queue.isNotEmpty) {
      g.tick(0.05);
      standStill();
      expect(g.marching, isFalse, reason: 'at ${g.t}');
    }
    final last = g.t;
    while (!g.marching && g.t - last < stallTime + 2) {
      g.tick(0.05);
      standStill();
    }
    expect(g.marching, isTrue);
    expect(g.t - last, greaterThan(stallTime));
  });

  test('marching monsters walk through the troops, and neither strike, raise nor heal', () {
    final g = bare()..gold = 1000;
    placeNow(g, 'knight', 2, 3);
    final knight = g.troops.single..busyUntil = hold; // doesn't hit back either
    final bear = g.monster('werebear', Tier.normal, knight.pos + const Point(2, 0)); // on top of it
    g.units.add(bear);
    g.marching = true;
    var x = bear.pos.x;
    for (var i = 0; i < 30; i++) {
      g.tick(0.05);
      expect(bear.pos.x, lessThan(x), reason: '$i');
      x = bear.pos.x;
    }
    expect(bear.pos.x, lessThan(knight.pos.x)); // walked through
    expect(knight.hp, knight.maxHp);

    final n = bare()..wave = 5;
    final necro = n.monster(boss, Tier.boss, const Point(250, 60))
      ..summonCd = 0
      ..mp = 240;
    n.units.add(necro);
    n.marching = true;
    for (var i = 0; i < 20; i++) {
      n.tick(0.05);
    }
    expect(n.minionsOf(necro), isEmpty);

    final h = bare();
    final orc = still(h, 'orc', const Point(230, 60), 10);
    mender(h, const Point(250, 60));
    h.marching = true;
    for (var i = 0; i < 20; i++) {
      h.tick(0.05);
    }
    expect(orc.hp, 10);
  });

  test('the march ends with the wave, and the next wave starts its stall clock afresh', () {
    final g = bare()..startWave();
    g.queue.clear();
    final slime = g.monster('slime', Tier.normal, const Point(250, 60))..busyUntil = hold;
    g.units.add(slime);
    while (!g.marching && g.t < stallTime + 5) {
      g.tick(0.05);
    }
    expect(g.marching, isTrue);
    slime.gone = true;
    g.tick(0.05);
    expect((g.waveActive, g.marching), (false, false));

    g.marching = true; // as if left over
    g.startWave();
    expect(g.marching, isFalse);
    // The same stuck slime again, and no spawn to count as progress: only a fresh clock keeps it from
    // marching at once.
    g.queue.clear();
    g.units.add(g.monster('slime', Tier.normal, const Point(250, 60))..busyUntil = hold);
    final start = g.t;
    while (g.t - start < stallTime - 1) {
      g.tick(0.05);
      expect(g.marching, isFalse, reason: 'at ${g.t - start}');
    }
  });

  /// A monster of [type] and [tier] at [at], already on the field, that neither walks nor fights.
  Unit foeAt(Game g, String type, Point<double> at, [Tier tier = Tier.normal]) {
    final u = g.monster(type, tier, at)
      ..entered = true
      ..busyUntil = hold;
    g.units.add(u);
    return u;
  }

  /// A wave with nothing left to spawn and one troop of [type] standing at its cell that never strikes on
  /// its own ([Unit.cd]), so what happens is its skill's doing.
  (Game, Unit) caster(String type) {
    final g = bare()..gold = 10000;
    expect(placeNow(g, type, 2, 3), isTrue);
    g
      ..startWave()
      ..queue.clear();
    return (g, g.troops.single..cd = hold);
  }

  test('every troop type has a skill costing skillMpShare of its base MP, coming again after skillCooldown s or 2 s after its own effect (decisions-log 298)', () {
    expect((skillMpShare, skillCooldown), (0.25, 4.0));
    expect(troopSkills.keys.toSet(), troopTypes.keys.toSet());
    const lasts = {'soldier': 3.0, 'swordsman': 4.0, 'knight_templar': 4.0}; // Hold Fast's, Rampage's, Holy Shield's own time
    expect((guardSelf.time, frenzy.time, ward.time), (lasts['soldier'], lasts['swordsman'], lasts['knight_templar']));
    for (final MapEntry(key: type, value: s) in troopSkills.entries) {
      expect(s.cost, troopTypes[type]!.mp * skillMpShare, reason: type);
      expect(s.cooldown, lasts.containsKey(type) ? lasts[type]! + 2 : skillCooldown, reason: type);
      expect(s.name, isNotEmpty, reason: type);
    }
  });

  test('MP comes back at the type\'s MP regen up to its most, even between waves', () {
    final g = bare()..gold = 1000;
    placeNow(g, 'wizard', 1, 3);
    final w = g.troops.single..mp = 0;
    for (var i = 0; i < 20; i++) {
      g.tick(0.05);
    }
    expect(w.mp, closeTo(w.stats.mpRegen * 20 * 0.05, 1e-9));
    while (g.t < w.stats.mp / w.stats.mpRegen + 1) {
      g.tick(0.05);
    }
    expect(w.mp, w.stats.mp);
  });

  test('a troop casts its skill when it has a target: it pays the MP and waits out the cooldown; never short of MP, with skills off, or between waves', () {
    final bertahan = troopSkills['soldier']!;
    (Game, Unit) hurtSoldier() {
      final (g, s) = caster('soldier');
      foeAt(g, 'orc', s.pos + Point(s.stats.range, 0)); // at the edge of its reach: close, but never shoved
      return (g, s);
    }

    final (g, s) = hurtSoldier();
    g.tick(0.05);
    final first = g.t;
    expect((s.skillAt, s.mp), (first, s.stats.mp - bertahan.cost)); // it was full
    expect(g.casts, [s]);
    while (s.skillAt == first && g.t - first < bertahan.cooldown + 1) {
      s.mp = s.stats.mp.toDouble(); // never short of MP
      g.tick(0.05);
    }
    expect(s.skillAt - first, inInclusiveRange(bertahan.cooldown, bertahan.cooldown + 0.05));
    expect(g.casts, [s, s]);

    final (short, ss) = hurtSoldier();
    final (off, os) = hurtSoldier();
    off.skills = false;
    for (var i = 0; i < bertahan.cooldown / 0.05; i++) {
      ss.mp = bertahan.cost - 1.0;
      short.tick(0.05);
      off.tick(0.05);
    }
    for (final (game, u, why) in [(short, ss, 'short of MP'), (off, os, 'skills off')]) {
      expect((u.skillAt, game.casts.isEmpty), (double.negativeInfinity, true), reason: why);
    }
    expect(os.mp, os.stats.mp, reason: 'skills off: it keeps its MP');

    // A priest's rule needs no foe (a soldier's would start a wave): between waves it waits.
    for (final wave in [false, true]) {
      final p = bare()..gold = 1000;
      placeNow(p, 'priest', 0, 3);
      placeNow(p, 'knight', 2, 3);
      placeNow(p, 'knight', 2, 4);
      final [priest, ...knights] = p.troops.toList();
      priest.cd = hold;
      for (final k in knights) {
        k.hp = k.maxHp * prayer.hurt / 2; // two hurt side by side: a crowd to heal
      }
      if (wave) foeAt(p, 'orc', const Point(250, 60));
      p.tick(0.05);
      expect(p.waveActive, wave);
      expect(priest.skillAt == p.t, wave, reason: wave ? 'mid-wave' : 'between waves');
    }
  });

  test('Hold Fast: a guarded soldier takes guardSelf.cut less of what gets past its defence, for guardSelf.time s, then all of it', () {
    final (g, s) = caster('soldier');
    g.inventory[Item.shield] = 1;
    expect(g.useItem(Item.shield, 'soldier'), isTrue);
    expect(s.stats.def, shieldDef);
    final orc = foeAt(g, 'orc', s.pos + Point(s.stats.range, 0))..busyUntil = 0; // it strikes, from where it stands
    final full = hitTaken(orc.stats.dmg, s.stats.def), guarded = full * (1 - guardSelf.cut);
    final hits = <(double, double)>[];
    var hp = s.hp;
    g.tick(0.05);
    final until = s.guardUntil, again = s.skillAt + g.skillCd(troopSkills['soldier']!.cooldown); // it casts again then (decisions-log 298)
    expect((s.guardCut, until), (guardSelf.cut, g.t + guardSelf.time));
    expect(again, greaterThan(until + 1));
    do {
      if (s.hp < hp) hits.add((g.t, hp - s.hp));
      hp = s.hp;
      g.tick(0.05);
    } while (g.t < again);
    expect(s.alive, isTrue);
    expect(hits.where((h) => h.$1 < until), isNotEmpty);
    expect(hits.where((h) => h.$1 >= until), isNotEmpty);
    for (final (at, loss) in hits) {
      expect(loss, closeTo(at < until ? guarded : full, 1e-9), reason: 'at $at');
    }
  });

  test('a Holy Shield ward never weakens a stronger Hold Fast, and a soldier under a ward can still cast Hold Fast', () {
    // A foe in both their reaches and the templar fighting; they cast in one tick, in the order they were placed.
    (Game, Unit, Unit) pair({required bool soldierFirst}) {
      final g = bare()..gold = 10000;
      for (final type in soldierFirst ? ['soldier', 'knight_templar'] : ['knight_templar', 'soldier']) {
        placeNow(g, type, 3, type == 'soldier' ? 3 : 4);
      }
      g
        ..startWave()
        ..queue.clear();
      final s = g.troops.singleWhere((u) => u.type == 'soldier'), tp = g.troops.singleWhere((u) => u.type != 'soldier');
      s.cd = hold;
      tp
        ..cd = hold
        ..attackedAt = g.t; // fighting: a troop for its ward
      foeAt(g, 'orc', (s.pos + tp.pos) * 0.5 + Point(s.stats.range / 2, 0)); // in both their reaches
      g.tick(0.05);
      expect((s.skillAt, tp.skillAt), (g.t, g.t));
      return (g, s, tp);
    }

    final (g, s, tp) = pair(soldierFirst: true); // Hold Fast, then the ward
    expect((tp.guardCut, tp.guardUntil), (ward.cut, g.t + ward.time));
    expect((s.guardCut, s.guardUntil), (guardSelf.cut, g.t + guardSelf.time));

    final (h, hs, _) = pair(soldierFirst: false); // the ward, then Hold Fast all the same
    expect((hs.guardCut, hs.guardUntil), (guardSelf.cut, h.t + guardSelf.time));
  });

  test('Circle Slash: with foes within slash.reach the knight deals its damage to each; a lone one is enough, none beyond the reach (decisions-log 298)', () {
    final (g, k) = caster('knight');
    final near = [foeAt(g, 'orc', k.pos + Point(slash.reach / 2, 0)), foeAt(g, 'orc', k.pos + Point(slash.reach / 2, slash.reach / 2))];
    final far = foeAt(g, 'orc', k.pos + Point(slash.reach + tile, 0));
    g.tick(0.05);
    expect((k.skillAt, k.mp), (g.t, k.stats.mp - troopSkills['knight']!.cost));
    for (final o in near) {
      expect(o.hp, o.maxHp - hitTaken(k.stats.dmg * slash.hit, o.stats.def));
    }
    expect(far.hp, far.maxHp);

    final (h, hk) = caster('knight');
    final lone = foeAt(h, 'orc', hk.pos + Point(slash.reach / 2, 0));
    h.tick(0.05);
    expect((hk.skillAt, lone.hp), (h.t, lone.maxHp - hitTaken(hk.stats.dmg * slash.hit, lone.stats.def)));

    final (n, nk) = caster('knight');
    final out = foeAt(n, 'orc', nk.pos + Point(slash.reach + tile, 0));
    n.tick(0.05);
    expect((nk.skillAt, nk.mp, out.hp), (double.negativeInfinity, nk.stats.mp, out.maxHp));
  });

  test('Rampage: while it lasts the swordsman attacks frenzy.rate as far apart, and after frenzy.time s at its rate again', () {
    final (g, w) = caster('swordsman');
    foeAt(g, 'orc', w.pos + Point(w.stats.range / 2, 0));
    expect(g.attackEvery(w), w.stats.rate);
    g.tick(0.05);
    final cast = g.t;
    expect(w.skillAt, cast);
    while (g.t < cast + frenzy.time) {
      expect(g.attackEvery(w), w.stats.rate * frenzy.rate, reason: 'at ${g.t - cast}');
      g.tick(0.05);
    }
    expect(g.attackEvery(w), w.stats.rate);
    expect(w.skillAt, cast); // no second one yet
  });

  test('no unit attacks faster than minAttackInterval, however hasted; the wave\'s boss down to bossMinAttackInterval (#71)', () {
    expect((minAttackInterval, bossMinAttackInterval), (0.3, 0.2));
    final (g, w) = caster('swordsman');
    g.skills = false;
    final bear = foeAt(g, 'werebear', w.pos + Point(w.stats.range / 2, 0))..hp = 1e9;
    // Every haste there is: gloves on its type, a Hero's x3, Rampage and War Cry.
    w
      ..stats = troopTypes['swordsman']!.upgraded(Item.gloves).upgraded(Item.gloves).upgraded(Item.gloves).boosted(3)
      ..frenzyUntil = g.t + 10;
    g.addEffect(w, Status.haste, 10, k: warCryK.haste);
    expect(w.stats.rate * frenzy.rate * warCryK.haste, lessThan(minAttackInterval / 2));
    expect(g.attackEvery(w), minAttackInterval);
    w.cd = 0;
    var blows = 0, last = w.attackedAt;
    for (var i = 0; i < 60; i++) {
      g.tick(0.05);
      if (w.attackedAt != last) (blows, last) = (blows + 1, w.attackedAt);
    }
    expect(blows, inInclusiveRange(9, 10)); // 3 s at one blow every 0.3 s
    expect(bear.alive, isTrue);

    // The floor for monsters: the wave's boss 0.2 s, any other (its mini boss too) 0.3 s.
    Unit quick(String type, Tier tier) => g.monster(type, tier, const Point(250, 60))..stats = const Stats(hp: 100, cost: 0, speed: 10, dmg: 1, range: 12, rate: 0.1);
    expect([for (final (type, tier) in [(boss, Tier.boss), (boss, Tier.miniBoss), ('orc', Tier.highElite)]) g.attackEvery(quick(type, tier))],
        [bossMinAttackInterval, minAttackInterval, minAttackInterval]);
    final slow = foeAt(g, 'orc', const Point(260, 60));
    expect(g.attackEvery(slow), slow.stats.rate); // above the floor, its own pace
  });

  test('after wave 26 walking, attacks and long reach keep growing a little a wave; from wave 16 monsters gain defence (#71)', () {
    expect((waveTempoTo, waveSpeedLate, waveRateLate, waveRangeLate, waveSpeedMost, waveRangeMost, waveDef), (26, 0.005, 0.005, 0.005, 0.75, 0.5, 0.05));
    final orc = enemyTypes['orc']!, archer = enemyTypes['skeleton_archer']!;
    for (final wave in [26, 27, 40, 80, 120]) {
      final s = enemyStats('orc', Tier.normal, wave), a = enemyStats('skeleton_archer', Tier.normal, wave), late = wave - 26;
      expect(s.speed, closeTo(orc.speed * (1 + min(waveSpeedMost, waveSpeedMax + waveSpeedLate * late)), 1e-9), reason: '$wave');
      expect(s.rate, closeTo(orc.rate / (1 + waveRateMax + waveRateLate * late), 1e-9), reason: '$wave');
      expect(a.range, closeTo(archer.range * (1 + min(waveRangeMost, waveRangeMax + waveRangeLate * late)), 1e-9), reason: '$wave');
      expect(s.range, orc.range, reason: '$wave'); // melee reach never grows
    }
    expect(enemyStats('orc', Tier.normal, 120).speed, closeTo(orc.speed * 1.75, 1e-9)); // walking at its most
    expect(enemyStats(boss, Tier.boss, 120).rate, greaterThan(bossMinAttackInterval)); // the floor is the only cap on attacks
    for (final (wave, def) in [(1, 0.0), (15, 0.0), (16, waveDef), (17, 2 * waveDef), (40, 25 * waveDef)]) {
      for (final type in ['slime', 'werebear', boss, necroHealer]) {
        expect(enemyStats(type, Tier.normal, wave).def, closeTo(def, 1e-9), reason: '$type $wave');
      }
    }
    final orc40 = enemyStats('orc', Tier.normal, 40); // a knight's blow on it loses the defence
    expect(hitTaken(20, orc40.def), closeTo(20 - 25 * waveDef, 1e-9));
  });

  test('Arrow Rain: with foes in range the archer looses up to volleyArrows extra arrows at the nearest; a lone one takes one; none out of range (decisions-log 298)', () {
    final (g, a) = caster('archer');
    final foes = [for (var i = volleyArrows + 1; i > 0; i--) foeAt(g, 'orc', a.pos + Point(a.stats.range * i / (volleyArrows + 1), 0))];
    g.tick(0.05);
    expect(a.skillAt, g.t);
    expect(g.shots.map((s) => s.from), List.filled(volleyArrows, a));
    expect(g.shots.map((s) => s.target), foes.reversed.take(volleyArrows)); // nearest first
    expect(g.shots.map((s) => s.dmg), List.filled(volleyArrows, a.stats.dmg));

    final (h, ha) = caster('archer');
    final lone = foeAt(h, 'orc', ha.pos + Point(ha.stats.range / 2, 0));
    h.tick(0.05);
    expect(ha.skillAt, h.t);
    expect([for (final s in h.shots) s.target], [lone]);

    final (n, na) = caster('archer');
    foeAt(n, 'orc', na.pos + Point(na.stats.range + tile, 0));
    n.tick(0.05);
    expect((na.skillAt, n.shots.isEmpty), (double.negativeInfinity, true));
  });

  test('Piercing Thrust: the lancer hits its target and the foes up to pierce.depth behind it in its lane; any lone foe in reach is enough (decisions-log 298)', () {
    final (g, l) = caster('lancer');
    final target = foeAt(g, 'orc', l.pos + Point(l.stats.range / 2, 0));
    final behind = foeAt(g, 'orc', target.pos + Point(pierce.depth * 3 / 4, 0)); // 1.5 tiles
    final tooDeep = foeAt(g, 'orc', target.pos + Point(pierce.depth + tile, 0)); // 3 tiles
    final offLane = foeAt(g, 'orc', target.pos + Point(pierce.depth / 2, 2 * pierce.lane));
    g.tick(0.05);
    expect(l.skillAt, g.t);
    for (final o in [target, behind]) {
      expect(o.hp, o.maxHp - hitTaken(l.stats.dmg * pierce.hit, o.stats.def));
    }
    expect((tooDeep.hp, offLane.hp), (tooDeep.maxHp.toDouble(), offLane.maxHp.toDouble()));

    for (final (tier, inReach) in [(Tier.elite, true), (Tier.normal, true), (Tier.normal, false)]) {
      final (h, hl) = caster('lancer');
      final lone = foeAt(h, 'orc', hl.pos + Point(inReach ? hl.stats.range / 2 : hl.stats.range + tile, 0), tier);
      h.tick(0.05);
      expect(hl.skillAt == h.t, inReach, reason: '$tier $inReach');
      expect(lone.hp < lone.maxHp, inReach, reason: '$tier $inReach');
    }
  });

  test('Healing Prayer: with prayer.crowd troops below prayer.hurt round the most hurt, every hurt troop near it gains the priest\'s heal, never past its most; not for one alone (decisions-log 298)', () {
    (Game, Unit, List<Unit>) patients(List<double> shares) {
      final g = bare()..gold = 10000;
      placeNow(g, 'priest', 0, 3);
      for (var r = 0; r < shares.length; r++) {
        placeNow(g, 'knight', 3, 2 + r); // a tile apart, one under the other
      }
      final [p, ...ks] = g.troops.toList();
      p.cd = hold;
      for (final (i, k) in ks.indexed) {
        k.hp = k.maxHp * shares[i];
      }
      foeAt(g, 'orc', const Point(250, 60)); // mid-wave
      return (g, p, ks);
    }

    // The worst in the middle; next to it one a hair short of full, a tile off one unhurt, 2 tiles off one hurt (the
    // second of the crowd), 3 tiles off one hurt.
    expect(prayer.crowd, 2);
    final (g, p, [nearFull, worst, unhurt, second, farHurt]) = patients([0.99, 0.2, 1, 0.5, 0.5]);
    final (worstHp, secondHp, farHp) = (worst.hp, second.hp, farHurt.hp);
    g.tick(0.05);
    expect((p.skillAt, p.mp), (g.t, p.stats.mp - troopSkills['priest']!.cost));
    final heal = p.stats.dmg * prayer.heal;
    expect((worst.hp, second.hp), (worstHp + heal, secondHp + heal));
    expect((nearFull.hp, unhurt.hp), (nearFull.maxHp.toDouble(), unhurt.maxHp.toDouble())); // capped
    expect(farHurt.hp, farHp); // out of the prayer's reach

    final low = prayer.hurt * 0.8, scratched = (prayer.hurt + 1) / 2; // hurt; and hurt, but above prayer.hurt
    for (final (shares, casts) in [
      (List.filled(prayer.crowd - 1, low), false),
      (List.filled(prayer.crowd, low), true),
      ([low, ...List.filled(prayer.crowd, scratched)], false),
    ]) {
      final (h, priest, _) = patients(shares);
      h.tick(0.05);
      expect(priest.skillAt == h.t, casts, reason: '$shares');
    }
  });

  test('Crushing Blow: 2 foes within slam.reach take the axeman\'s damage and stand stunned slam.stun s, MP still coming back; never the boss', () {
    final (g, x) = caster('armored_axeman');
    Unit loose(Game g, String type, Point<double> at, [Tier tier = Tier.normal]) => foeAt(g, type, at, tier)..busyUntil = 0;
    final orc = loose(g, 'orc', x.pos + Point(slam.reach / 2, -slam.reach / 2));
    final healer = loose(g, necroHealer, x.pos + Point(slam.reach / 2, slam.reach / 2))..mp = 0;
    g.tick(0.05);
    expect(x.skillAt, g.t);
    for (final o in [orc, healer]) {
      expect(o.hp, o.maxHp - hitTaken(x.stats.dmg * slam.hit, o.stats.def), reason: o.type);
      expect(o.stunUntil, g.t + slam.stun, reason: o.type);
    }
    x.busyUntil = hold; // it stays put, so nothing shoves them
    final (orcAt, healerAt, xHp) = (orc.pos, healer.pos, x.hp);
    var mp = healer.mp;
    while (g.t + 0.05 < orc.stunUntil) {
      g.tick(0.05);
      expect((orc.pos, healer.pos, x.hp), (orcAt, healerAt, xHp), reason: 'stunned at ${g.t}');
      expect(healer.mp, greaterThan(mp));
      mp = healer.mp;
    }
    for (var i = 0; i < 10; i++) {
      g.tick(0.05);
    }
    expect(orc.pos, isNot(orcAt)); // on its way again

    final (h, hx) = caster('armored_axeman');
    final necro = loose(h, boss, hx.pos + Point(slam.reach / 2, -slam.reach / 2), Tier.boss);
    final other = loose(h, 'orc', hx.pos + Point(slam.reach / 2, slam.reach / 2));
    h.tick(0.05);
    expect(hx.skillAt, h.t);
    expect(necro.hp, lessThan(necro.maxHp));
    expect((necro.stunUntil, other.stunUntil), (double.negativeInfinity, h.t + slam.stun));
  });

  test('Arcane Blast: with a foe in range the wizard fires one big orb at it for blast.hit its damage over blast.splash; a lone foe is enough (decisions-log 298)', () {
    final (g, w) = caster('wizard');
    final target = foeAt(g, 'orc', w.pos + Point(w.stats.range / 2, 0));
    final near = [foeAt(g, 'orc', target.pos + Point(0, blast.splash / 2)), foeAt(g, 'orc', target.pos + Point(blast.splash / 2, 0))];
    final beyond = foeAt(g, 'orc', target.pos + Point(blast.splash + tile, 0));
    g.tick(0.05);
    expect(w.skillAt, g.t);
    final orb = g.shots.single;
    expect((orb.from, orb.target, orb.big, orb.dmg, orb.splash), (w, target, true, w.stats.dmg * blast.hit, blast.splash));
    for (var i = 0; i < 100 && g.shots.isNotEmpty; i++) {
      g.tick(0.05);
    }
    expect(g.shots, isEmpty);
    expect(g.impacts.map((i) => i.$2), contains('shards')); // its ice star's flash and streak (wizard_fx_test.dart)
    for (final o in [target, ...near]) {
      expect(o.hp, o.maxHp - hitTaken(orb.dmg, o.stats.def));
    }
    expect(beyond.hp, beyond.maxHp);

    final (h, hw) = caster('wizard');
    final t2 = foeAt(h, 'orc', hw.pos + Point(hw.stats.range / 2, 0));
    h.tick(0.05);
    expect((hw.skillAt, h.shots.single.target), (h.t, t2)); // a lone foe

    final (n, nw) = caster('wizard');
    foeAt(n, 'orc', nw.pos + Point(nw.stats.range + tile, 0));
    n.tick(0.05);
    expect((nw.skillAt, n.shots.isEmpty), (double.negativeInfinity, true)); // out of range
  });

  test('Holy Shield: with a fighting troop near, every troop within ward.reach (the templar too) is guarded ward.cut for ward.time s; not while they all are already, nor with none fighting (decisions-log 298)', () {
    (Game, Unit, List<Unit>, Unit) line({bool fighting = true}) {
      final g = bare()..gold = 10000;
      placeNow(g, 'knight_templar', 2, 3);
      for (final (c, r) in [(3, 2), (3, 3), (3, 4), (1, 3)]) {
        placeNow(g, 'soldier', c, r); // within ward.reach: three at the front, one behind
      }
      placeNow(g, 'soldier', 5, 7); // out of it
      final [tp, ...near] = g.troops.toList();
      final far = near.removeLast();
      foeAt(g, 'orc', const Point(250, 60)); // mid-wave
      if (fighting) near.first.attackedAt = g.t; // one fighting
      return (g, tp, near, far);
    }

    final (g, tp, near, far) = line();
    expect(far.pos.distanceTo(tp.pos), greaterThan(ward.reach));
    g.tick(0.05);
    expect(tp.skillAt, g.t);
    for (final u in [tp, ...near]) {
      expect((u.guardCut, u.guardUntil), (ward.cut, g.t + ward.time), reason: '${u.pos}');
    }
    expect(far.guardUntil, double.negativeInfinity);

    final (h, htp, hnear, _) = line();
    for (final u in [htp, ...hnear]) {
      u
        ..guardCut = ward.cut
        ..guardUntil = h.t + ward.time;
    }
    hnear.first.guardCut = guardSelf.cut; // a stronger guard counts too
    h.tick(0.05);
    expect(htp.skillAt, double.negativeInfinity);

    final (n, ntp, _, _) = line(fighting: false);
    ntp.cd = hold; // nor itself
    n.tick(0.05);
    expect(ntp.skillAt, double.negativeInfinity);
  });

  test('a Hero that rolls MP has its type\'s MP and MP regen heroBoost times, so it has a skill\'s MP back heroBoost times as soon', () {
    Game? g;
    Unit? h;
    for (var pick = 0; h == null && pick < 50; pick++) {
      final c = heroGame(_Dice(0, pick));
      winAt(c, heroEvery); // no monsters: between waves, nothing casts
      final u = c.troops.singleWhere((u) => u.hero);
      if (u.heroStats.contains(HeroStat.mp)) (g, h) = (c, u);
    }
    expect(h != null, heroMp); // MP can be rolled exactly while it is in the pools
    if (g == null || h == null) return;
    final base = g.statsOf(h.type), skill = troopSkills[h.type]!;
    expect((h.stats.mp, h.stats.mpRegen), ((base.mp * heroBoost).round(), base.mpRegen * heroBoost));
    final other = g.troops.firstWhere((u) => !u.hero);
    h.mp = 0;
    other.mp = 0;
    var (heroBack, otherBack) = (double.nan, double.nan);
    final start = g.t;
    while (otherBack.isNaN && g.t - start < 60) {
      g.tick(0.05);
      if (heroBack.isNaN && h.mp >= skill.cost) heroBack = g.t - start;
      if (other.mp >= troopSkills[other.type]!.cost) otherBack = g.t - start;
    }
    expect(heroBack, closeTo(skill.cost / (base.mpRegen * heroBoost), 0.05));
    expect(otherBack, closeTo(troopSkills[other.type]!.cost / (g.statsOf(other.type).mpRegen * auraBoost), 0.05)); // the aura
  });
}

/// A fall-back policy that always answers [act] and keeps every feature record it was asked about.
class _SpyPolicy extends RetreatPolicy {
  _SpyPolicy(this.act);

  final RetreatAction act;
  final asked = <RetreatFeatures>[];

  @override
  RetreatBrain get brain => const RetreatBrain();

  @override
  RetreatAction decide(RetreatFeatures f) {
    asked.add(f);
    return act;
  }
}

/// Loot dice that always roll [roll] and pick [pick] (wrapped to the choices on offer).
class _Dice implements Random {
  final double roll;
  final int pick;
  _Dice(this.roll, this.pick);
  @override
  double nextDouble() => roll;
  @override
  int nextInt(int max) => pick % max;
  @override
  bool nextBool() => false;
}

/// A score server that takes what it is sent into [got], unless it is [down] or told to [refuse] it; its
/// board is [board].
class _FakeServer extends ScoreRepository {
  bool down = false;
  Set<ScoreEntry> refuse = {};
  List<ScoreEntry> board = [];
  final got = <ScoreEntry>[];

  @override
  Future<void> submit(ScoreEntry e) async {
    if (down || refuse.contains(e)) throw ScoreServerException('down');
    got.add(e);
  }

  @override
  Future<List<ScoreEntry>> top({int limit = 10}) async {
    if (down) throw ScoreServerException('down');
    return board.take(limit).toList();
  }
}
