// The Smithy's Craft on a real save (decisions-log 233; a behaviour probe, not a balance one): the owner's w89 save with
// the Towns on, in a Town, its bag given a seeded handful (2 to 12) of each of the 30 materials ([seed]); for each of the 11 small
// relics it prints the recipe's rows (have / need), why it can't be crafted or that it can, then crafts it while it can
// and prints what that took, the Shop's buy and sell prices, and what Asah would take from the Bag afterwards. A probe
// (no `_test.dart`): queue `["test", "test/probe_town_craft.dart"]`; `SEED` (1) changes the handful.
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';

const seed = int.fromEnvironment('SEED', defaultValue: 1);

String _name(Enum? k) => switch (k) { final Mat m => m.label, final Item i => itemNames[i]!, null => 'gold', final Enum e => e.name };

void main() {
  test('craft each of the 11 on the w89 save, seed $seed', () {
    final g = Game.fromJson(
        jsonDecode(File('test/fixtures/save-20261002-2222-w89-sellbug.json').readAsStringSync()) as Map<String, dynamic>,
        Random(seed), Random(seed + 100), Random(seed + 300));
    final dice = Random(seed + 700);
    for (final m in Mat.values) {
      g.materials[m] = 2 + dice.nextInt(11); // 2 to 12 of each: most recipes covered, some twice
    }
    g.townAt = g.wave + 1;
    expect(g.enterTown(), isTrue);
    final out = StringBuffer('w89 save, wave ${g.wave}, gold ${thousands(g.gold)}, items ${g.inventory}\n');
    for (final relic in smallRelics) {
      final rows = g.craftRows(relic).map((r) => '${_name(r.kind)} ${r.have}/${r.need}').join(', ');
      out.writeln('${relicNames[relic]} (${g.relicTier(relic).name}): $rows -> ${g.whyNotCraft(relic)?.text ?? 'can craft'}');
      final gold = g.gold;
      var n = 0;
      while (g.craft(relic)) {
        n++;
      }
      out.writeln('  crafted $n, gold -${thousands(gold - g.gold)}, now ${g.whyNotCraft(relic)?.text}; '
          'Shop buy ${thousands(g.buyPrice(relic))} then ${thousands(g.buyPrice(relic, 1))}, sell ${thousands(g.sellPrice(relic))}');
    }
    out.writeln('Bag: ${{for (final r in smallRelics) if ((g.relicBag[r] ?? 0) > 0) relicNames[r]: g.relicBag[r]}}');
    out.writeln('Asah takes: ${asahTakeLine(g.asahTake)}');
    final left = (g..leaveTown()).log.entries.whereType<TownLeft>().single;
    out.writeln('Left town: ${left.data['crafts']}, ${left.data['craftSpent']} gold');
    // ignore: avoid_print
    print(out);
    expect(g.log.entries.whereType<Crafted>(), isNotEmpty);
  });
}
