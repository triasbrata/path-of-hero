// The Army detail's Awaken needs by grade (decisions-log 249; lib/troop_detail.dart `_detailNext`; docs/ui-hud.md
// "Army"): with the forge and the Towns on, "Awaken 2 needs (grade II):", the grade set's items with their have/need,
// where each comes from ("Done", "In Bag: 1", "Smithy: can make 3", "Smithy: needs Leather Strap"), the "Next" line with
// the grade after it; a stat cell counts the kind's grades together; a level kept from a save before the grades
// (decisions-log 272) said first, "Awaken 1 (kept from old items)". With the Towns off (tests only, decisions-log 296:
// the old recipe) the needs have no grade, and each its Smithy line all the same.
// One TdGame per widget test; no wave is ever won.
import 'dart:convert';

import 'package:flame/game.dart' hide Game;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';
import 'package:tower_defense/main.dart';

import 'hud_font.dart';

const desk = Size(1266, 713), phone = Size(915, 412);

/// Boots one TdGame in a [size] window, past the welcome screen, with the game's font and the minimap folded.
Future<Board> boot(WidgetTester tester, [Size size = desk]) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await loadHudFont(tester);
  final game = TdGame();
  await tester.pumpWidget(GameWidget(game: game));
  for (var i = 0; i < 3000 && !game.isLoaded; i++) {
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 20)));
    await tester.pump();
  }
  expect(game.isLoaded, isTrue);
  return game.board
    ..welcome = null
    ..miniMapOpen = false;
}

Future<void> frames(WidgetTester tester, [int n = 2]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

/// The detail's words of [key], joined.
String said(Board b, String key) => b.troopDetailWords(key).join(' | ');

/// The knight at Awaken 1 (its grade-I set) on a board game with the forge on, and toward Awaken 2: a Steel Sword in the
/// Bag (1 of 3 given), Tower Shields the Bag's materials make 3 of (Rusty Plate 2, Leather Strap 1 each), the Steel Gloves
/// held in full, no Wolf Claw for the Swift Boots and no Orc Ear for the Silver Amulet.
Game knightAt1() {
  final g = Game().boardRules()
    ..gold = 5000;
  g.upgrades['knight'] = [
    for (final MapEntry(key: item, value: n) in g.gradeSet('knight', 1).entries) ...List.filled(n, item),
    Item.steelSword,
    Item.steelGloves,
    Item.steelGloves,
  ];
  g.inventory[Item.steelSword] = 1;
  g.materials.addAll({Mat.rustyPlate: 6, Mat.leatherStrap: 3});
  expect(g.autoPlace('knight'), isTrue);
  return g;
}

void main() {
  for (final size in [desk, phone]) {
    testWidgets('by grade at $size: "Awaken 2 needs (grade II):", each item where it comes from, the next grade after it',
        (tester) async {
      final b = await boot(tester, size);
      final g = b.state = knightAt1();
      await frames(tester, 40);
      await tester.tapAt(b.troopRow('knight').center);
      await frames(tester, 4);
      expect(g.awakenLevel('knight'), 1);
      expect((g.canMake(Item.towerShield), g.whyNotMake(Item.swiftBoots)!.short), (3, Mat.wolfClaw));
      final next = said(b, 'next');
      expect(next, startsWith(size == desk ? '${awakenName(2)} needs (${gradeName(2)}):' : '${awakenName(2)} needs'), reason: '$size');
      expect(next, contains('${itemNames[Item.steelSword]} | 1/3 | In ${Words.bag}: 1'), reason: '$size');
      expect(next, contains('${itemNames[Item.towerShield]} | 0/3 | ${Words.smithy}'), reason: '$size: the Smithy');
      expect(next, contains('${itemNames[Item.steelGloves]} | 2/2 | ${Words.done}'), reason: '$size');
      expect(next, contains('${itemNames[Item.silverAmulet]} | 0/1 | ${Words.smithy}'), reason: '$size');
      if (size == desk) {
        expect(next, contains('${Words.smithy}: ${Words.canMake} 3'));
        expect(next, contains('${Words.smithy}: ${Words.needs} ${Mat.wolfClaw.label}'), reason: 'the Swift Boots');
        expect(next, contains('${Words.smithy}: ${Words.needs} ${Mat.orcEar.label}'), reason: 'the Silver Amulet: Orc Ear 2, Rusty Plate 1');
        expect(next, contains('. ${awakenName(3)} needs ${gradeName(3)}.'));
      }
      for (final item in g.gradeSet('knight', 2).keys) {
        expect(next, contains(itemNames[item]!), reason: '$item');
      }
      expect(next, isNot(contains('Drops')));
      // The stat cells count the kind's grades: 3 swords + 1 Steel Sword of 3 + 3 open.
      expect(said(b, 'stats'), contains('4/6'));
      b.state = Game();
      await frames(tester, 5);
    });
  }

  testWidgets('by grade at Awaken 0 and 2: grade I, then grade III with no grade after it', (tester) async {
    final b = await boot(tester);
    final g = b.state = Game().boardRules()
      ..gold = 1000;
    expect(g.autoPlace('archer'), isTrue);
    await frames(tester, 40);
    await tester.tapAt(b.troopRow('archer').center);
    await frames(tester, 4);
    var next = said(b, 'next');
    expect(next, startsWith('${awakenName(1)} needs (${gradeName(1)}):'));
    expect(next, contains('${itemNames[Item.torch]} | 0/1 | ${Words.smithy}: ${Words.needs} ${Mat.boneShard.label}'));
    expect(next, contains('${awakenName(2)} needs ${gradeName(2)}.'));
    g.upgrades['archer'] = [
      for (var l = 1; l <= 2; l++)
        for (final MapEntry(key: item, value: n) in g.gradeSet('archer', l).entries) ...List.filled(n, item),
    ];
    await frames(tester, 4);
    next = said(b, 'next');
    expect(next, startsWith('${awakenName(3)} needs (${gradeName(3)}):'));
    expect(next, contains('${itemNames[Item.greatBow]} | 0/3'));
    expect(next, isNot(contains('needs ${gradeName(3)}.')), reason: 'no grade after grade III');
    b.state = Game();
    await frames(tester, 5);
  });

  for (final size in [desk, phone]) {
    testWidgets('a level kept from a save before the grades at $size: "Awaken 1 (kept from old items)" first, then the '
        'grade-II needs', (tester) async {
      final b = await boot(tester, size);
      // A knight at Awaken 1 by the rule from before the grades (its recipe once, all grade I) in a game with the Towns off
      // (tests only: the forge-off build that wrote such saves is gone, decisions-log 296), saved, then loaded by grade.
      final old = Game();
      old.upgrades['knight'] = [for (final MapEntry(key: item, value: n) in old.recipeOf('knight').entries) ...List.filled(n, item)];
      final j = jsonDecode(jsonEncode(old.toJson())) as Map<String, dynamic>;
      expect(j.containsKey('awakenKept'), isFalse, reason: 'a save from before the grades keeps no level');
      final g = b.state = Game.fromJson(j).boardRules()
        ..gold = 5000;
      expect((g.keptLevel('knight'), g.awakenLevel('knight')), (1, 1));
      expect(g.autoPlace('knight'), isTrue);
      await frames(tester, 40);
      await tester.tapAt(b.troopRow('knight').center);
      await frames(tester, 4);
      final next = said(b, 'next'), kept = awakenName(1);
      expect(next, anyOf(startsWith('$kept (${Words.keptFromOld}) | '), startsWith('$kept (${Words.kept}) | ')), reason: '$size');
      if (size == desk) {
        expect(next, startsWith('$kept (${Words.keptFromOld}) | ${awakenName(2)} needs (${gradeName(2)}):'));
      }
      for (final item in g.gradeSet('knight', 2).keys) {
        expect(next, contains(itemNames[item]!), reason: '$item: the next grade alone');
      }
      expect(next, isNot(contains('| ${itemNames[Item.amulet]} |')), reason: 'grade I is kept, not asked for');
      b.state = Game();
      await frames(tester, 5);
    });
  }

  testWidgets('the Towns off (tests only): "Awaken 1 needs:" with no grade, where from the Smithy', (tester) async {
    final b = await boot(tester);
    final g = b.state = Game().boardRules()
      ..towns = false
      ..gold = 5000;
    expect(g.autoPlace('knight'), isTrue);
    await frames(tester, 40);
    await tester.tapAt(b.troopRow('knight').center);
    await frames(tester, 4);
    final next = said(b, 'next');
    expect(next, startsWith('${awakenName(1)} needs:'));
    expect(next, contains(Words.smithy));
    expect(next, isNot(contains(Words.grade)));
    expect(next, isNot(contains('Drops')));
    b.state = Game();
    await frames(tester, 5);
  });
}
