// A Dungeon trip leaves the wave run as it was (decisions-log 336, 337; lib/dungeon.dart): waves 1-5 from a seed are the
// same with and without a trip between two of them (the spawn sequence, the drops, the names, the clock); the same
// seed and dt make the same floor and the same fight; a save made during a trip is the game as it was at the door, and
// a save from before the Dungeon loads unchanged.
import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';

/// A game's state as one line a unit: the numbers, every unit with its name, the bag, the materials and who fell.
String digest(Game g) => [
      'wave ${g.wave} t ${g.t} gold ${g.gold} lives ${g.lives} kills ${g.kills} score ${g.score} cam ${g.cam}',
      for (final u in g.units)
        '${u.side.name} ${u.type} ${u.name} ${u.tier.name} ${u.alive} hp ${u.hp}/${u.maxHp} mp ${u.mp} at ${u.pos.x},${u.pos.y} '
            'blows ${u.blows} ${u.relics.map((r) => r.name).join('+')}',
      '${g.inventory} ${g.relicBag} ${g.materials} fell ${g.fallen.map((u) => u.name).join(',')}',
    ].join('\n');

/// Waves 1-5 of a seeded game buying [army]; with [trip], a trip into the Dungeon (a fight in its first room, then
/// back) between waves 2 and 3. A digest after each wave, the monsters' spawn order of each wave too.
List<String> run({required bool trip, int seed = 5}) {
  const army = ['soldier', 'archer', 'knight', 'wizard'];
  final g = Game(Random(seed), Random(seed + 100))
    ..seedDice(seed)
    ..gold = 3000
    ..capacity = 16;
  final out = <String>[];
  for (var w = 0; w < 5; w++) {
    for (final t in army) {
      if (g.gold >= g.priceOf(t)) g.autoPlace(t);
    }
    for (var i = 0; i < 300; i++) {
      g.tick(1 / 30);
    }
    if (trip && w == 2) {
      g.inTown = true;
      final picks = g.troops.where((u) => u.alive).take(3).toList();
      expect(g.enterDungeon(picks), isTrue);
      final d = g.dungeon!;
      d.stick = const Point(1, 0);
      for (var i = 0; i < 30 * 12; i++) {
        g.tick(1 / 30);
      }
      d.stick = const Point(0, 0);
      for (var i = 0; i < 30 * 10; i++) {
        g.tick(1 / 30);
      }
      expect(g.units.any((u) => u.side == Side.enemy), isTrue, reason: 'the first room\'s monsters came');
      g.endTripNow(TripEnd.left);
      g.inTown = false;
    }
    g.startWave();
    final spawns = <String>[];
    for (var i = 0; i < 30 * 600 && g.waveActive && !g.over; i++) {
      final seen = g.enemies.toSet();
      g.tick(1 / 30);
      for (final e in g.enemies) {
        if (!seen.contains(e)) spawns.add('${e.type}/${e.tier.name}@${e.pos.y}');
      }
    }
    out
      ..add(digest(g))
      ..add(spawns.join(' '));
  }
  return out;
}

void main() {
  test('waves 1-5 are the same with and without a trip between waves 2 and 3: spawns, drops, names, the clock', () {
    final without = run(trip: false), with_ = run(trip: true);
    expect(with_.length, without.length);
    for (var i = 0; i < without.length; i++) {
      expect(with_[i], without[i], reason: 'line $i');
    }
  });

  /// A trip's fight as text: every second, each unit's place and HP.
  String fight(int seed) {
    final g = Game(Random(seed), Random(seed + 100))
      ..seedDice(seed)
      ..gold = 3000
      ..capacity = 16;
    for (final t in ['knight', 'archer']) {
      g.autoPlace(t);
    }
    g.inTown = true;
    g.enterDungeon([...g.troops]);
    final d = g.dungeon!, lines = <String>['${d.seed} ${[for (final r in d.floor.rooms) '${r.kind.name} ${r.x0}']}'];
    d.stick = const Point(1, 0.2);
    for (var s = 0; s < 40 && g.dungeon != null; s++) {
      if (s == 20) d.stick = const Point(0, 0);
      for (var i = 0; i < 30; i++) {
        g.tick(1 / 30);
      }
      lines.add([for (final u in g.units) '${u.type} ${u.pos.x.toStringAsFixed(3)},${u.pos.y.toStringAsFixed(3)} ${u.hp.toStringAsFixed(3)}'].join('; '));
    }
    return lines.join('\n');
  }

  test('the same seed and dt make the same floor and the same fight', () {
    final a = fight(9);
    expect(fight(9), a);
    expect(a.split('\n').length, greaterThan(20));
    expect(fight(10).split('\n').first, isNot(a.split('\n').first), reason: 'another seed, another floor');
  });

  test('a save made during a trip is the game as it was at the door: the whole army, no party copies, no monsters; '
      'after the trip the save is the same again; a save has no Dungeon key', () {
    final g = Game(Random(1), Random(101))
      ..seedDice(1)
      ..gold = 3000
      ..capacity = 16;
    for (final t in ['knight', 'archer', 'soldier']) {
      g.autoPlace(t);
    }
    g.inTown = true;
    final door = jsonEncode(g.toJson());
    expect(door.contains('dungeon'), isFalse);
    g.enterDungeon(g.troops.take(3).toList());
    g.dungeon!.stick = const Point(1, 0);
    for (var i = 0; i < 30 * 15; i++) {
      g.tick(1 / 30);
    }
    expect(jsonEncode(g.toJson()), door);
    final loaded = Game.fromJson(jsonDecode(jsonEncode(g.toJson())) as Map<String, dynamic>);
    expect(loaded.troops.length, 4);
    expect(loaded.dungeon, isNull);
    g.endTripNow(TripEnd.left);
    expect(jsonEncode(g.toJson()), door);
  });
}
