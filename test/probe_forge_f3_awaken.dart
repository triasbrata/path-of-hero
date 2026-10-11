// Awaken by grade on the board with the forge on (decisions-log 249; a quick behaviour probe, not a balance campaign):
// a board game a seed (the Towns on, and with them the forge) where, as in the design model
// (forge-design §2, §11: "a run that wins every wave"), every wave is won: each of its queue's monsters stands at 1 HP
// in front of four knights (probe_forge_drops.dart's way), so the kills, their gold and their materials are the game's
// own. The model's army is fielded (soldier, knight and the priest from wave 1, archer from 4, wizard from 10, templar
// from 16). At each Town it crafts what the fielded types' next Awaken still needs ([Game.awakenShort], the army's
// order, the lowest grade first) and gives it, while its craft budget lasts: SHARE (0.6, the model's split player's
// share for Awaken items) of 35% of the income so far (each wave's gold won: kills and the wave bonus), less what
// crafting spent. Prints a `W` line a wave (`W seed wave levels/of crafted spent income`), `A` lines (the first wave each
// type reached Awaken 1/2/3), `G` (the first grade-III item crafted, and the Towns), then the levels at waves 20 / 30 /
// 40 beside the model's (split player 0.82 / 8.39 / 14.86; items-first 0.92 / 9.78 / 17.40). A probe (no `_test.dart`):
// queue `["test", "test/probe_forge_f3_awaken.dart"]`; `SEED_FROM` (1), `SEEDS` (3),
// `MAX_WAVE` (40) and `SHARE` (0.6) change it. It never touches the real save (flutter_test_config.dart's temp dir).
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';

import 'hero_skill_helpers.dart';

const seedFrom = int.fromEnvironment('SEED_FROM', defaultValue: 1), seeds = int.fromEnvironment('SEEDS', defaultValue: 3);
const maxWave = int.fromEnvironment('MAX_WAVE', defaultValue: 40);
const shareText = String.fromEnvironment('SHARE', defaultValue: '0.6');
const craftShare = 0.35;

/// The model's army: each type and the wave it joins, and the cell it stands on (the knights also do the killing).
const army = [('soldier', 1, 1), ('knight', 1, -1), ('priest', 1, 3), ('archer', 4, 5), ('wizard', 10, 7), ('knight_templar', 16, 0)];

/// The model's split player's Awaken levels by wave, and the items-first player's.
const model = {20: (0.82, 0.92), 30: (8.39, 9.78), 40: (14.86, 17.40)};

void main() {
  test('Awaken by grade on the board, seeds $seedFrom..${seedFrom + seeds - 1}, to wave $maxWave, every wave won', () {
    final share = double.parse(shareText);
    final at = <int, List<int>>{}, clock = Stopwatch()..start();
    for (var seed = seedFrom; seed < seedFrom + seeds; seed++) {
      final g = Game(Random(seed), Random(seed + 100)).boardRules()
        ..heroes = Random(seed + 300)
        ..loot = Random(seed + 200)
        ..slots = Random(seed + 400)
        ..draft = Random(seed + 500)
        ..townDice = Random(seed + 600)
        ..matDice = Random(seed + 700)
        ..skills = false
        ..heroSkills = false
        ..awakenSkills = false
        ..monsterSkills = false
        ..capacity = 6 * rows
        ..gold = 1000000;
      expect((g.towns, g.byGrade), (true, true));
      final killers = [1, 3, 5, 7], knights = [for (final r in killers) placeNow(g, 'knight', 3, r)];
      var income = 0, spent = 0, crafted = 0, towns = 0;
      int? grade3;
      final first = {for (final (t, _, _) in army) t: <int, int>{}};
      double budget() => share * craftShare * income - spent;
      List<String> fielded(int wave) => [for (final (t, w, _) in army) if (w <= wave) t];
      for (var w = 1; w <= maxWave; w++) {
        for (final (type, from, row) in army) {
          // The army stands by (never moves or fights: the knights kill); the priest is the board's free one.
          if (from <= w && row >= 0 && !g.troops.any((u) => u.alive && u.type == type)) placeNow(g, type, 1, row).busyUntil = hold;
        }
        for (final (i, k) in knights.indexed) {
          if (!k.alive) knights[i] = placeNow(g, 'knight', 3, killers[i]); // a killer that fell, again
        }
        // A Town before this wave: craft and give what the next Awakens take, while the budget lasts.
        if (g.townDue && g.enterTown()) {
          towns++;
          for (var more = true; more;) {
            more = false;
            for (final type in fielded(w)) {
              for (final item in g.awakenShort(type).keys) {
                final gold = g.itemRecipe(item)!.gold;
                if (gold > budget() || !g.canCraftItem(item)) continue;
                expect(g.craftItem(item), isTrue);
                spent += gold;
                crafted++;
                if (item.grade == 3) grade3 ??= w;
                expect(g.useItem(item, type), isTrue, reason: '$item on $type');
                more = true;
              }
            }
          }
          expect(g.leaveTown(), isTrue);
        }
        final before = g.gold;
        g.startWave();
        final spawn = [...g.queue];
        g.queue.clear();
        final keep = foeAt(g, 'slime', const Point(2000, 10)); // far off: the wave stays on until all are down
        final foes = [
          for (final (i, (type, tier)) in spawn.indexed)
            foeAt(g, type, knights[i % knights.length].pos + Point(12.0, (i ~/ knights.length) * 0.01), tier)..hp = 1,
        ];
        for (var n = 0; n < 6000 && foes.any((u) => u.alive); n++) {
          g.tick(0.05);
        }
        expect(keep.alive, isTrue);
        for (final u in g.enemies) {
          u.gone = true; // the wave's leftovers (the keeper, a raised one): never killed, never dropping
        }
        g.tick(0.05);
        expect(g.waveActive, isFalse, reason: 'seed $seed wave $w won');
        income += max(0, g.gold - before);
        final types = fielded(w), levels = types.fold(0, (a, type) => a + min(maxAwaken, g.awakenLevel(type)));
        for (final type in types) {
          for (var l = 1; l <= min(maxAwaken, g.awakenLevel(type)); l++) {
            first[type]!.putIfAbsent(l, () => w);
          }
        }
        // ignore: avoid_print
        print('W $seed $w $levels/${3 * types.length} $crafted $spent $income');
        if (model.containsKey(w)) (at[w] ??= []).add(levels);
      }
      for (final (type, _, _) in army) {
        // ignore: avoid_print
        print('A $seed $type ${[for (final l in [1, 2, 3]) first[type]![l] ?? '-'].join(' / ')}');
      }
      // ignore: avoid_print
      print('G $seed first grade III crafted before wave ${grade3 ?? '-'}; $towns Towns; ${clock.elapsed.inSeconds}s');
    }
    for (final MapEntry(key: w, value: (split, first)) in model.entries) {
      final got = at[w] ?? const [];
      final mean = got.isEmpty ? double.nan : got.fold(0, (a, b) => a + b) / got.length;
      // ignore: avoid_print
      print('L w$w levels ${got.join(' ')} mean ${mean.toStringAsFixed(2)}; model split $split, items-first $first');
    }
  });
}
