// The Bayangan's ease count (decisions-log 319, lib/omen.dart's [OmenEaseCount]): what a won wave's end counts as its
// falls: every fall (as designed and shipped), only the troops that started the wave once each, or only an awakened
// type's. The knob for the owner's answer on an army that loses its fodder every wave.
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';

/// Every item [type]'s first awakening asks for: the type at Awaken 1.
List<Item> awakenOne(String type) => [
      for (final MapEntry(key: item, value: n) in awakenRecipe[type]!.entries)
        for (var i = 0; i < n; i++) item,
    ];

void main() {
  setUp(() => omensOn = true);

  test('the knob ships the owner\'s pick: only an awakened type\'s falls count, at most omenEaseMax levels a wave', () {
    expect((omenEaseCount, omenEaseShare, omenEaseMax), (OmenEaseCount.awakened, 0.125, 2)); // falls until decisions-log 318
  });

  test('falls counts a rebought troop\'s fall again; starters each starter once; awakened an awakened type\'s only', () {
    final g = Game(Random(1), Random(101))
      ..wave = 29
      ..gold = 1000000
      ..upgrades['knight'] = awakenOne('knight');
    for (final type in ['knight', 'soldier', 'knight', 'soldier', 'soldier']) {
      g.autoPlace(type); // with the free priest the room's 6
    }
    expect((g.awakenLevel('knight'), g.awakenLevel('soldier')), (1, 0));
    g.startWave();
    final knights = g.troops.where((u) => u.type == 'knight').toList(), soldiers = g.troops.where((u) => u.type == 'soldier').toList();
    expect((knights.length, soldiers.length), (2, 3));
    expect(g.omenStarters, containsAll([...knights, ...soldiers]));
    final rebought = soldiers.last; // as one Auto Buy bought mid-wave: not one the wave started with
    g.omenStarters.remove(rebought);
    g.fallen.addAll([soldiers[0], soldiers[1], rebought, rebought, knights[0]]);
    expect(g.omenFalls(), 1, reason: 'the knob as shipped: awakened');
    expect(
        [for (final how in OmenEaseCount.values) g.omenFalls(how)], [5, 3, 1],
        reason: 'falls: all five; starters: two soldiers and a knight; awakened: the knight');
  });
}
