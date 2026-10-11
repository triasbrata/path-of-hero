// Peti Bos's odds by wave (decisions-log 185, lib/draft.dart): `chestOdds` in the first boss chest's wave, then each
// later boss wave a `chestOddsStep` of Legenda further toward `chestOddsCap` (reached at wave 345); still one draft
// draw a card, so a seed draws as many values at every wave; in the waves of no step (1-9) the cards' rarities are the
// head's (a seeded table); a chest keeps its own wave's odds, a reroll too. The rest of the chest: draft_test.dart,
// legenda_test.dart. docs/loot-items-relics.md, "Peti Bos".
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';

import 'hero_skill_helpers.dart';

/// Draft dice that roll every rarity at [roll] and take a pool's first card.
class _Dice implements Random {
  _Dice(this.roll);
  final double roll;

  @override
  double nextDouble() => roll;

  @override
  int nextInt(int max) => 0;

  @override
  bool nextBool() => false;
}

/// Dice that count their draws.
class _Counted implements Random {
  _Counted(this.inner);
  final Random inner;
  int draws = 0;

  @override
  double nextDouble() {
    draws++;
    return inner.nextDouble();
  }

  @override
  int nextInt(int max) {
    draws++;
    return inner.nextInt(max);
  }

  @override
  bool nextBool() {
    draws++;
    return inner.nextBool();
  }
}

/// A game with no skills cast and the chest on, between waves at [wave], past its first chest (three Epik), on [draft].
Game chested(int wave, Random draft) => bareGame(Random(1))
  ..skills = false
  ..heroSkills = false
  ..awakenSkills = false
  ..offers = true
  ..wave = wave
  ..draft = draft
  ..chestsGiven = 1;

const _letter = {Rarity.langka: 'L', Rarity.epik: 'E', Rarity.legenda: 'G'};

/// [g]'s waiting chests' rarities, a word a chest: "LEL EEL LLL".
String rarities(Game g) => [for (final c in g.chests) c.cards!.map((r) => _letter[r!.rarity]).join()].join(' ');

/// The head's (7bb3a8e) rarities of three chests on `Random(seed)` draft dice, seeds 1-8, in any wave before
/// legendFrom (a Legenda roll an Epik). Rarities, not names: the catalog adds Pusaka, which moves the names but not
/// the rarity rolls.
const headTable = [
  'ELE LLL ELL', 'LLE LLE LLE', 'LLE LLL ELL', 'LEE EEL LLL', //
  'LLL LEE LEL', 'LEL ELL ELL', 'LEL LLE LLE', 'LEL EEE LEL',
];

void main() {
  test('the odds: chestOdds at wave 5, a chestOddsStep more each boss chest after it, chestOddsCap from wave 345', () {
    expect((chestOddsCap, chestOddsStep), ((rare: 0.40, epic: 0.35, legend: 0.25), 0.0025));
    for (final w in [1, 5, 9]) {
      expect(chestOddsAt(w), chestOdds, reason: 'wave $w');
    }
    for (final w in [345, 400, 1000]) {
      expect(chestOddsAt(w), chestOddsCap, reason: 'wave $w');
    }
    // decisions-log 185's rows: w10 one step (as w14), w20 three, w100 nineteen, w344 sixty-seven.
    for (final (w, rare, epic, legend) in [
      (10, 0.547794, 0.369706, 0.0825),
      (14, 0.547794, 0.369706, 0.0825),
      (20, 0.543382, 0.369118, 0.0875),
      (100, 0.508088, 0.364412, 0.1275),
      (344, 0.402206, 0.350294, 0.2475),
    ]) {
      final o = chestOddsAt(w);
      expect(o.rare, closeTo(rare, 1e-6), reason: 'wave $w');
      expect(o.epic, closeTo(epic, 1e-6), reason: 'wave $w');
      expect(o.legend, closeTo(legend, 1e-12), reason: 'wave $w');
    }
    for (var w = 1; w <= 400; w++) {
      final o = chestOddsAt(w);
      expect(o.rare + o.epic + o.legend, closeTo(1, 1e-12), reason: 'wave $w');
      // Each boss wave after the first a step more, until the cap.
      final n = min(68, max(0, w ~/ bossEvery - 1));
      expect(o.legend, closeTo(chestOdds.legend + n * chestOddsStep, 1e-12), reason: 'wave $w');
    }
  });

  test('one draft draw a card at every wave: the same seed draws as many values (three chests and a reroll)', () {
    int draws(int wave) {
      final dice = _Counted(Random(5));
      final g = chested(wave, dice)..giveChests(3);
      g.gold = g.rerollCost(g.chest!); // 600 × 1.05^(wave − 1): billions by wave 345
      expect(g.rerollChest(), isTrue, reason: 'wave $wave');
      return dice.draws;
    }

    // Each card a rarity draw and a pick (no Serpihan: the pool is full), each chest three cards.
    for (final w in [1, 5, 10, 19, 20, 25, 100, 345, 400]) {
      expect(draws(w), 4 * draftCards * 2, reason: 'wave $w');
    }
  });

  test("in the waves of no step (1-9) every chest's cards have the head's rarities (a seeded table)", () {
    for (final wave in [1, 5, 9]) {
      for (var seed = 1; seed <= headTable.length; seed++) {
        final g = chested(wave, Random(seed))..giveChests(3);
        expect(rarities(g), headTable[seed - 1], reason: 'wave $wave, seed $seed');
      }
    }
  });

  test("a chest keeps its own wave's odds, a reroll too; a Legenda roll with all three found is still an Epik", () {
    // 0.911 is an Epik in a w20 chest (Legenda from 1 − 0.0875 = 0.9125) and a Legenda in a w25 one (from 0.91).
    final early = chested(legendFrom, _Dice(0.911))..giveChests(1);
    expect(rarities(early), 'EEE');
    early
      ..wave = 25 // put off (Nanti) past the next boss wave
      ..gold = 1000000;
    expect(early.rerollChest(), isTrue);
    expect(rarities(early), 'EEE', reason: "the reroll keeps the w20 chest's odds");
    final late = chested(25, _Dice(0.911))..giveChests(1);
    expect(rarities(late), 'GGG');
    final found = chested(100, _Dice(0.911));
    found.legendsFound.addAll([for (final r in Relic.values) if (r.rarity == Rarity.legenda) r]);
    found.giveChests(1);
    expect(rarities(found), 'EEE');
    // Before legendFrom a Legenda roll is an Epik, whatever the step.
    final before = chested(legendFrom - 1, _Dice(0.99))..giveChests(1);
    expect(rarities(before), 'EEE');
  });
}
