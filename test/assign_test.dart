import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';

import 'hero_skill_helpers.dart';

// Game.assignPreview (#86 / #87): what one more item on a troop type or a relic on one troop would do, for the
// book's list and the field's popup. The book's list itself: book_assign_test.dart.

void main() {
  group('an item on a type', () {
    test('previews its stat, price, cap and awakening progress, and useItem then gives exactly that', () {
      final g = bareGame();
      placeNow(g, 'soldier', 1, 1);
      g.inventory[Item.sword] = 2;
      final base = g.statsOf('soldier'), price = g.priceOf('soldier');
      final p = g.assignPreview(Item.sword, 'soldier');
      expect(p.why, isNull);
      expect(p.stats, [(StatKind.dmg, base.dmg, base.dmg * swordDmg)]);
      expect(p.price, (price, g.priceWith('soldier', Item.sword)));
      expect(p.awaken, (0, 0));
      expect(p.count, ((0, 2), (1, 2)));
      expect(p.step, ((0, 9), (1, 9))); // the soldier's grade I set: its recipe's 8 items and an amulet
      // Only tried on: nothing changed.
      expect((g.countOf('soldier', Item.sword), g.statsOf('soldier').dmg, g.inventory[Item.sword]), (0, base.dmg, 2));
      expect(g.useItem(Item.sword, 'soldier'), isTrue);
      expect((g.statsOf('soldier').dmg, g.priceOf('soldier')), (p.stats.single.$3, p.price!.$2));
    });

    test('the item that completes a grade set previews the awakening: its HP and MP, the progress full', () {
      final g = bareGame();
      g.upgrades['soldier'] = [Item.sword, Item.sword, Item.shield, Item.shield, Item.bow, Item.gloves, Item.potion, Item.amulet];
      g.inventory[Item.boots] = 1;
      final now = g.statsOf('soldier'), p = g.assignPreview(Item.boots, 'soldier');
      expect(p.why, isNull);
      expect(p.awaken, (0, 1));
      expect(p.count, ((0, 1), (1, 1))); // grade I's one: grade II's boots are another item (decisions-log 249)
      expect(p.step, ((8, 9), (9, 9)));
      expect([for (final (k, _, _) in p.stats) k], containsAll([StatKind.hp, StatKind.mp, StatKind.speed]));
      final hp = p.stats.firstWhere((s) => s.$1 == StatKind.hp);
      expect(hp.$2, now.hp);
      g.useItem(Item.boots, 'soldier');
      expect((g.awakenLevel('soldier'), g.statsOf('soldier').hp), (1, hp.$3));
    });

    test('a refusal says why in the UI words, changes nothing and is exactly when useItem refuses', () {
      final g = bareGame();
      g.inventory[Item.staff] = 1;
      final p = g.assignPreview(Item.staff, 'soldier'); // not in the soldier's recipe
      expect((p.why, p.stats.length, p.count, p.price!.$1 == p.price!.$2), (refusalNames[Refusal.notInRecipe], 0, ((0, 0), (0, 0)), true));
      expect(g.useItem(Item.staff, 'soldier'), isFalse);
      // None in the bag: the bag's reason, though the type could take it (and the try-on still shows what it does).
      final empty = g.assignPreview(Item.sword, 'soldier');
      expect((empty.why, empty.stats.single.$1), (assignRefusals.empty, StatKind.dmg));
      expect(g.useItem(Item.sword, 'soldier'), isFalse);
      // At its cap: grade I's two swords (grade II's come with Awaken 1).
      g
        ..inventory[Item.sword] = 1
        ..upgrades['soldier'] = [Item.sword, Item.sword];
      expect(g.assignPreview(Item.sword, 'soldier').why, refusalNames[Refusal.maxed]);
      expect(g.useItem(Item.sword, 'soldier'), isFalse);
    });
  });

  group('a relic on a troop', () {
    test('a plain relic changes no stat and is not given by the preview; a Pusaka goes on a type, not here', () {
      final g = bareGame();
      final u = placeNow(g, 'soldier', 1, 1);
      g
        ..relicBag[Relic.fang] = 1
        ..givePusaka(Relic.dragonHeart);
      final fang = g.assignPreview(Relic.fang, u);
      expect((fang.why, fang.stats.length, fang.price, fang.count, fang.step), (null, 0, null, null, null));
      expect((u.relics.firstOrNull, g.relicBag[Relic.fang]), (null, 1)); // only tried on
      final heart = g.assignPreview(Relic.dragonHeart, u);
      expect((heart.why, heart.stats.isEmpty), (pusakaOnType, true)); // decisions-log 138
      expect(g.useRelic(Relic.dragonHeart, u), isFalse);
      expect(g.assignPreview(Relic.voidEye, u).why, pusakaOnType); // owned or not
    });

    test('one relic each: a troop holding one says which; a fallen troop and an empty bag refuse too', () {
      final g = bareGame();
      final a = placeNow(g, 'soldier', 1, 1), b = placeNow(g, 'archer', 1, 2);
      g.relicBag[Relic.fury] = 2;
      g.useRelic(Relic.fury, a);
      final held = g.assignPreview(Relic.fury, a);
      expect((held.why, held.stats.length), (holdsRelic(Relic.fury), 0));
      expect(held.why, holdsRelic(Relic.fury));
      expect(g.useRelic(Relic.fury, a), isFalse);
      expect(g.assignPreview(Relic.guard, b).why, assignRefusals.empty);
      b.dying = 0;
      expect(g.assignPreview(Relic.fury, b).why, assignRefusals.gone);
      expect(g.useRelic(Relic.fury, b), isFalse);
    });
  });

  test('the stats are as the troop row shows them: the pause between attacks never under the floor', () {
    const s = Stats(hp: 1, cost: 1, speed: 1, dmg: 1, range: 1, rate: 0.1);
    expect(StatKind.rate.of(s), minAttackInterval);
    expect([for (final k in StatKind.values) statName(k)],
        ['HP', 'MP', 'Defense', 'Attack', 'Range', 'Speed', 'Attack wait', 'Regen']);
    expect(statName(StatKind.dmg, heals: true), 'Heal');
  });
}
