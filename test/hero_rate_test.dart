import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';

// #69: attack rate is no Hero attribute any more (the owner: "keluarkan attack speed dari pool attribute
// hero yang di enhance"). No pool holds it, and a Hero saved with it rolls just that pick again on load.

void main() {
  test('no Hero pool holds attack rate', () {
    for (final pool in heroPools.values) {
      expect(pool, isNot(contains(HeroStat.rate)));
    }
    for (final type in troopTypes.keys) {
      expect(heroPoolOf(type), isNot(contains(HeroStat.rate)), reason: type);
    }
  });

  test('a Hero saved with attack rate rolls just that pick again on load: from its pool, never its other pick, which stays in place', () {
    for (final type in troopTypes.keys) {
      for (final other in heroPoolOf(type)) {
        for (final rateFirst in [true, false]) {
          final g = Game()
            ..units.clear()
            ..gold = 10000;
          expect(g.place(type, 1, 3), isTrue, reason: type);
          g.troops.single
            ..hero = true
            ..heroStats = rateFirst ? [HeroStat.rate, other] : [other, HeroStat.rate];
          final l = Game.fromJson(jsonDecode(jsonEncode(g.toJson())) as Map<String, dynamic>), h = l.troops.single;
          final why = '$type, $other, rate ${rateFirst ? 'first' : 'last'}: ${h.heroStats}';
          expect(h.hero, isTrue, reason: why);
          expect(h.heroStats.length, heroStatCount, reason: why);
          expect(h.heroStats[rateFirst ? 1 : 0], other, reason: why); // kept, in its place
          final rolled = h.heroStats[rateFirst ? 0 : 1];
          expect(heroPoolOf(type), contains(rolled), reason: why);
          expect(rolled, isNot(other), reason: why);
          expect(h.stats.rate, l.statsOf(type).rate, reason: why); // its attacks as often as its type's again
        }
      }
    }
  });
}
