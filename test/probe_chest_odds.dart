// Probe (not in the suite): Peti Bos's rarity shares by wave (decisions-log 185). 1000 boss chests (3000 cards) at each
// of waves 25, 100 and 345, past the run's first chest, on `Random(SEED)` draft dice (default 1), nothing taken (so no
// Legenda is found and none steps down); prints each wave's Langka / Epik / Legenda shares beside chestOddsAt. The
// pity (a 6th dry chest's first card an Epik) is in the shares. Queue: ["test", "test/probe_chest_odds.dart"].
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';

import 'hero_skill_helpers.dart';

const seed = int.fromEnvironment('SEED', defaultValue: 1), chests = 1000;

void main() {
  test('Peti Bos rarity shares at waves 25, 100, 345', () {
    for (final wave in [25, 100, 345]) {
      final g = bareGame(Random(1))
        ..skills = false
        ..heroSkills = false
        ..awakenSkills = false
        ..offers = true
        ..wave = wave
        ..draft = Random(seed)
        ..chestsGiven = 1
        ..giveChests(chests);
      final n = {for (final r in [Rarity.langka, Rarity.epik, Rarity.legenda]) r: 0};
      var cards = 0;
      for (final c in g.chests) {
        for (final r in c.cards!) {
          n[r!.rarity] = n[r.rarity]! + 1;
          cards++;
        }
      }
      String share(Rarity r) => (n[r]! / cards).toStringAsFixed(3);
      final o = chestOddsAt(wave);
      // ignore: avoid_print
      print('CHEST-ODDS w$wave seed $seed: $cards cards: Langka ${share(Rarity.langka)} '
          '(${o.rare.toStringAsFixed(3)}), Epik ${share(Rarity.epik)} (${o.epic.toStringAsFixed(3)}), '
          'Legenda ${share(Rarity.legenda)} '
          '(${o.legend.toStringAsFixed(3)}); counts ${n[Rarity.langka]} / ${n[Rarity.epik]} / ${n[Rarity.legenda]}');
      expect(cards, chests * draftCards);
    }
  });
}
