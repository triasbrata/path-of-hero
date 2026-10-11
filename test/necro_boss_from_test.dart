// A new player's first boss is never the necromancer (decisions-log 176): before [necroBossFrom] the boss slot is a
// type of the pool. The die is the same: the boss's necromancer roll is still drawn, and a roll under [necroBossChance]
// takes `slotType(pool, roll / necroBossChance)` (the pair rule's way), so no die draws more. Every wave's queue but
// that boss's type is built as on 0db06e3, the head before the change (its queues: headQueues below).
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';

/// The game of die [k] as the w5 replay builds it (the app's rules; its slots' dice `Random(k + 400)`).
Game diced(int k) => (Game(Random(k), Random(k + 100))
      ..loot = Random(k + 200)
      ..heroes = Random(k + 300)
      ..slots = Random(k + 400))
    .boardRules();

/// FNV-1a (32 bits) of queue [q], each monster as "type/tier", comma separated.
int fnv(Iterable<(String, Tier)> q) {
  var h = 0x811c9dc5;
  for (final c in [for (final (t, tier) in q) '$t/${tier.name}'].join(',').codeUnits) {
    h = ((h ^ c) * 0x01000193) & 0xffffffff;
  }
  return h;
}

/// The head's queues (0db06e3, before [necroBossFrom]) of waves 1-20 for the game of seed s ([diced] with no
/// [Game.boardRules], waves started one after another, each queue then cleared), as [fnv]s.
const headQueues = {
  1: [1831848243, 2553930496, 1877114181, 645582631, 2204290230, 3874863174, 474805767, 2198270917, 2929333937,
      4225379792, 1181225356, 3565836790, 959375297, 3644935201, 1903322258, 2300916736, 877171805, 3001897832,
      1503865351, 4108428962],
  2: [1831848243, 2042788637, 444484319, 2014131857, 2108784, 3435267319, 2251647863, 2025757021, 599827763,
      1378735699, 3189256565, 233194439, 1863721425, 983048356, 235562921, 2479501371, 3292675266, 1739379761,
      2853033129, 201218027],
  3: [1831848243, 4188386185, 3438517846, 2897830529, 2131353620, 2502241894, 407689308, 1063547065, 2956190565,
      1032698814, 2088676592, 448725153, 1407511184, 3966530477, 1846506628, 1934077882, 2876501810, 2690527358,
      1311513470, 696136411],
  4: [1831848243, 2367995568, 885405878, 3125281773, 726111147, 655639923, 1624206365, 683899703, 2144709466,
      297196207, 3050032609, 38820361, 3823062301, 3618255727, 583529270, 2487747651, 3204667813, 3614222760,
      1685722483, 2334964377],
  5: [1831848243, 3185612318, 512674996, 3547947583, 2173961346, 627387585, 1230606046, 3961611235, 1170135373,
      3938974950, 85096739, 2071039334, 539265876, 405193888, 1663912922, 2959301117, 889827322, 2029650946,
      1091713245, 3253760077],
  6: [1831848243, 330685174, 1218495072, 2990130872, 3860882007, 374415515, 3985466526, 1114729531, 460485809,
      206652581, 3619711693, 1307355633, 228450644, 2128514142, 232185465, 3107673527, 1932044151, 4050014208,
      3493885822, 1553508647],
  7: [1831848243, 467260896, 928606350, 1683573658, 2407903275, 2547210390, 1090712612, 1361670814, 210021700,
      1385420759, 843645947, 263840103, 213506147, 3486492055, 247489322, 3618430867, 941667193, 3963206214, 770558865,
      3282324434],
  8: [1831848243, 436881276, 2450499046, 733916487, 61180527, 3855133545, 2749523253, 3631251102, 2251164004,
      3332285008, 576652696, 435302389, 3929190838, 2132827203, 3802793916, 1809552112, 2373564122, 1158578131,
      613269994, 2734571541],
};

/// The head's wave 5 of the same games: its queue without the boss ([fnv]) and the boss's type.
const headWave5 = {
  1: (2425307077, 'skeleton'),
  2: (916407717, 'bat'),
  3: (2617696511, 'skeleton'),
  4: (3640326928, 'necromancer'),
  5: (3317035791, 'skeleton'),
  6: (1749507868, 'skeleton'),
  7: (4272741520, 'necromancer'),
  8: (2058658084, 'skeleton'),
};

/// The boss's type in [q].
String bossOf(List<(String, Tier)> q) => q.singleWhere((m) => m.$2 == Tier.boss).$1;

void main() {
  test('necroBossFrom is wave 10, a boss wave', () {
    expect((necroBossFrom, necroBossFrom % bossEvery), (10, 0));
  });

  test('dice 0-39: the wave-5 boss is never the necromancer; the 13 that drew it take a type of the pool from that roll',
      () {
    var drew = 0;
    for (var k = 0; k < 40; k++) {
      final g = diced(k)..wave = bossEvery - 1;
      final roll = Random(k + 400).nextDouble(); // wave 5's first die of [Game.slots]: the boss's necromancer roll
      g.startWave();
      final b = bossOf(g.queue), pool = poolOf(bossEvery);
      expect(b, isIn(pool), reason: 'die $k');
      if (roll < necroBossChance) {
        drew++;
        expect(b, slotType(pool, roll / necroBossChance), reason: 'die $k');
      }
    }
    expect(drew, 13); // on the head these 13 of 40 brought the necromancer, and a 5-troop opening lost every one
  });

  test('waves 1-20 are built as on the head, but wave 5\'s boss when it drew the necromancer: no die draws more', () {
    for (final MapEntry(key: s, value: head) in headQueues.entries) {
      final g = Game(Random(s), Random(s + 100))
        ..loot = Random(s + 200)
        ..heroes = Random(s + 300)
        ..slots = Random(s + 400);
      for (var w = 1; w <= 20; w++) {
        g.startWave();
        final q = [...g.queue], why = 'seed $s wave $w';
        g.queue.clear();
        if (w != bossEvery) {
          expect(fnv(q), head[w - 1], reason: why);
          continue;
        }
        final (rest, was) = headWave5[s]!;
        expect(fnv(q.where((m) => m.$2 != Tier.boss)), rest, reason: why); // the wave around its boss
        expect(bossOf(q), was == boss ? isIn(poolOf(w)) : was, reason: why);
      }
    }
    // Two of the eight drew the necromancer at wave 5 on the head, so the golden holds a moved boss.
    expect(headWave5.values.where((h) => h.$2 == boss), hasLength(2));
  });

  test('before wave 10 no boss is the necromancer; from it about a third are, on every boss wave', () {
    const games = 300;
    final necro = <int, int>{};
    for (var s = 0; s < games; s++) {
      final g = Game(Random(s))..slots = Random(s * 7 + 1);
      for (var w = 1; w <= 30; w++) {
        g.startWave();
        if (w % bossEvery == 0 && bossOf(g.queue) == boss) necro[w] = (necro[w] ?? 0) + 1;
        g.queue.clear();
      }
    }
    for (var w = bossEvery; w <= 30; w += bossEvery) {
      expect((necro[w] ?? 0) / games, w < necroBossFrom ? 0 : closeTo(necroBossChance, 0.1), reason: 'wave $w');
    }
  });
}
