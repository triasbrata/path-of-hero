// Melee keep their supports in reach (decisions-log 312; the owner: "make sure jangan sampai support teringgal dan
// membuat heal mereka tidak masuk dan off screen", then "mereka dinamis bisa maju tapi ketika terlalu maju mereka akan
// turun lagi ke belakang dan jangan pasif dan berdiam saja"): the supports' line per support kind and how it moves; the
// leash on it (the walk cap, a foe within it taken, a fight past the cap kept, the drop back from past [Game.leashOut]
// striking on the way, free again at the line); a healer out of sight walking into view before it heals, and one left
// behind the army walking up between heals; the stall detector quiet through all of it.
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';

import 'hero_skill_helpers.dart';

/// Mid-wave on a bare field (no free healer, the #10 skills off), nothing left to spawn; a slime held far off keeps
/// the wave on.
Game midWave() {
  final g = bareGame(Random(1))..skills = false;
  g
    ..startWave()
    ..queue.clear();
  foeAt(g, 'slime', const Point(900, 120));
  return g;
}

var _cell = 0;

/// A troop of [type] standing at ([x], [y]) on [g]'s field, its spot there; [held]: it never moves nor acts.
Unit troopAt(Game g, String type, double x, double y, {bool held = false}) {
  final c = _cell++ % 48;
  final u = placeNow(g, type, c ~/ rows, c % rows)
    ..pos = Point(x, y)
    ..post = Point(x, y)
    ..joining = false; // on the field already, not walking in
  if (held) u.busyUntil = hold;
  return u;
}

/// A Hero priest: its reach ×[heroBoost] (288).
void heroReach(Game g, Unit u) => u
  ..hero = true
  ..heroStats = [HeroStat.range]
  ..stats = g.statsOf(u.type).heroic({HeroStat.range}, heroBoost);

void main() {
  setUp(() => _cell = 0);

  test('the line: a healer\'s x plus its heal reach, a long range\'s plus its hold, at most 0.4 of the view, half a tile '
      'inside; the least of them; a long range already shooting doesn\'t count', () {
    double? lineOf(void Function(Game g) put) {
      final g = midWave();
      put(g);
      final knight = troopAt(g, 'knight', 200, 56);
      return g.supportLine(knight);
    }

    const slack = Game.supportSlack;
    expect(lineOf((g) {}), isNull, reason: 'no support: no leash');
    expect(lineOf((g) => troopAt(g, 'archer', 40, 20, held: true)), 40 + 64 - slack); // its hold: 64
    expect(lineOf((g) => troopAt(g, 'wizard', 40, 20, held: true)), 40 + 70 - slack); // 140 × 0.5
    expect(lineOf((g) => troopAt(g, 'priest', 40, 20, held: true)), 40 + 96 - slack);
    final view = Game.supportView * cols * tile; // 128 on a 320 wide view
    expect(lineOf((g) => heroReach(g, troopAt(g, 'priest', 40, 20, held: true))), 40 + view - slack); // not 288
    expect(
      lineOf((g) {
        troopAt(g, 'priest', 0, 20, held: true); // 88
        troopAt(g, 'archer', 40, 100, held: true); // 96
      }),
      0 + 96 - slack,
    );
    expect(
      lineOf((g) {
        troopAt(g, 'priest', 0, 20, held: true); // 88
        troopAt(g, 'archer', -30, 100, held: true); // 26, but it shoots the orc: it doesn't count
        foeAt(g, 'orc', const Point(20, 100));
      }),
      0 + 96 - slack,
    );
  });

  test('no leash with it off, before the wave, for anyone but a melee troop, and on a stalled wave\'s march', () {
    final g = midWave(), archer = troopAt(g, 'archer', 40, 20, held: true), knight = troopAt(g, 'knight', 200, 56);
    expect(g.supportLine(knight), isNotNull);
    expect(g.supportLine(archer), isNull);
    expect((midWave()..keepSupports = false).supportLine(knight), isNull);
    final calm = bareGame(Random(1));
    troopAt(calm, 'archer', 40, 20);
    expect(calm.supportLine(troopAt(calm, 'knight', 200, 56)), isNull);
    final m = midWave()..marching = true;
    troopAt(m, 'archer', 40, 20);
    expect(m.supportLine(troopAt(m, 'knight', 200, 56)), isNull);
  });

  test('the line comes forward at once and goes back at most leashEase a second', () {
    final g = midWave(), archer = troopAt(g, 'archer', 40, 20, held: true), knight = troopAt(g, 'knight', 300, 56);
    const slack = Game.supportSlack;
    expect(g.supportLine(knight), 40 + 64 - slack);
    archer.pos = const Point(100, 20);
    g.t += 0.1; // once a tick: a new tick's line
    expect(g.supportLine(knight), 100 + 64 - slack);
    archer.pos = const Point(0, 20);
    g.t += 0.5;
    expect(g.supportLine(knight), closeTo(100 + 64 - slack - Game.leashEase * 0.5, 1e-9));
    g.t += 20;
    expect(g.supportLine(knight), 0 + 64 - slack);
  });

  test('a melee troop walks at its foe up to the leash past the line and stands there facing it; a foe within the leash '
      'it takes; the stall detector stays quiet', () {
    final g = midWave();
    troopAt(g, 'archer', 40, 20, held: true); // the line at 96, the leash to 120
    final knight = troopAt(g, 'knight', 60, 56);
    foeAt(g, 'slime', const Point(260, 56));
    final keep = g.supportLine(knight)! + Game.leashCap;
    var most = knight.pos.x;
    for (var i = 0; i < 80; i++) {
      g.tick(0.05);
      most = max(most, knight.pos.x);
      expect(knight.throughUntil, double.negativeInfinity, reason: 'tick $i: never "stuck"');
    }
    expect(most, lessThanOrEqualTo(keep + 1e-6));
    expect(knight.pos.x, closeTo(keep, 0.5));
    expect(knight.moving, isFalse);
    expect(knight.dir, 1); // facing the slime
    expect(knight.leashed, isFalse);
    // An orc comes within the leash (its near side inside it), off the knight's row: it goes and fights it.
    final orc = foeAt(g, 'orc', Point(keep - 4, 100));
    runFor(g, 3);
    expect(orc.hp, lessThan(orc.maxHp));
    expect(knight.pos.x, lessThanOrEqualTo(keep + 1e-6));
  });

  test('past the leash but short of leashOut, a troop in a fight fights on where it stands', () {
    final g = midWave();
    troopAt(g, 'archer', 40, 20, held: true); // the line at 96: leashCap to 120, leashOut at 144
    final knight = troopAt(g, 'knight', 138, 56), slime = foeAt(g, 'slime', const Point(152, 56)); // in its reach
    final x = knight.pos.x;
    runFor(g, 2);
    expect(knight.leashed, isFalse);
    expect(knight.pos.x, closeTo(x, 1));
    expect(slime.hp, lessThan(slime.maxHp));
  });

  test('one more than leashOut past the line drops back to it facing its foe and striking it while it reaches it, then '
      'is free: back up to the leash', () {
    final g = midWave();
    troopAt(g, 'archer', 40, 20, held: true);
    final line = 40 + 64 - Game.supportSlack;
    final knight = troopAt(g, 'knight', line + Game.leashOut + 6, 56);
    final slime = foeAt(g, 'slime', Point(knight.pos.x + 14, 56)); // in its reach
    g.tick(0.05);
    expect(knight.leashed, isTrue);
    expect(knight.moving, isTrue);
    expect(knight.dir, 1); // backing off, facing the slime
    expect(slime.hp, lessThan(slime.maxHp)); // struck on the way
    var least = knight.pos.x;
    var freed = double.nan;
    for (var i = 0; i < 100; i++) {
      g.tick(0.05);
      least = min(least, knight.pos.x);
      if (freed.isNaN && !knight.leashed) freed = knight.pos.x;
      expect(knight.throughUntil, double.negativeInfinity, reason: 'tick $i');
    }
    expect(freed, closeTo(line + Game.leashBack, 2)); // free at the line
    expect(least, greaterThan(line - tile / 2)); // not further back
    expect(knight.leashed, isFalse);
    expect(knight.pos.x, closeTo(line + Game.leashCap, 0.5)); // up to the leash again, the slime still beyond it
  });

  test('with keepSupports off a melee troop walks all the way to its foe (as before decisions-log 312)', () {
    final g = midWave()..keepSupports = false;
    troopAt(g, 'archer', 40, 20, held: true);
    final knight = troopAt(g, 'knight', 60, 56), slime = foeAt(g, 'slime', const Point(260, 56));
    runFor(g, 12);
    expect(slime.hp, lessThan(slime.maxHp));
    expect(knight.pos.x, greaterThan(40 + 64 - Game.supportSlack + Game.leashOut)); // well past where the leash holds
  });

  test('a troop healer out of sight left of the view walks into it before it heals', () {
    final g = midWave();
    final priest = troopAt(g, 'priest', 20, 20);
    heroReach(g, priest); // it reaches the knight from out of sight
    final knight = troopAt(g, 'knight', 330, 56);
    foeAt(g, 'slime', const Point(344, 56));
    knight.hp = knight.maxHp / 2;
    g.cam = 200; // the view on the fight
    var healedAway = false, healed = false;
    for (var i = 0; i < 200 && !healed; i++) {
      final away = priest.pos.x < g.cam + g.keepUpShift - Game.offViewBy, x = priest.pos.x, hp = knight.hp;
      g.tick(0.05);
      if (knight.hp > hp) (away ? healedAway = true : healed = true);
      if (away) expect(priest.pos.x, greaterThan(x), reason: 'tick $i: it walks up');
    }
    expect(healedAway, isFalse);
    expect(healed, isTrue);
  });

  test('a troop healer left behind the army walks up behind it between heals, and heals on', () {
    final g = midWave();
    final priest = troopAt(g, 'priest', 120, 20);
    heroReach(g, priest);
    final knight = troopAt(g, 'knight', 330, 56);
    foeAt(g, 'slime', const Point(344, 56));
    knight.hp = 1;
    final from = priest.pos.x, hp = knight.hp;
    runFor(g, 2.5);
    expect(knight.hp, greaterThan(hp)); // it healed
    expect(priest.pos.x, greaterThan(from + tile)); // and came up between heals
    expect(priest.pos.x, lessThanOrEqualTo(knight.pos.x - tile + 1e-6)); // never past its rest behind the army
    // keepSupports off: it heals from where it stands, as before.
    final h = midWave()..keepSupports = false;
    final p = troopAt(h, 'priest', 120, 20);
    heroReach(h, p);
    troopAt(h, 'knight', 330, 56).hp = 1;
    foeAt(h, 'slime', const Point(344, 56));
    runFor(h, 2.5);
    expect(p.pos.x, closeTo(120, 1e-6));
  });
}
