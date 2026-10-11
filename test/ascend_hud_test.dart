import 'package:flame/game.dart' hide Game;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';
import 'package:tower_defense/main.dart';


// The Tas tab's dot (#92 part 2, lib/ascend_page.dart), as the player gets it: one TdGame (its own file: a second TdGame
// in one file breaks the shared image cache, docs/testing.md). The rules: ascend_test.dart. Awaken 4-5 is bought on the
// Army detail (troops_detail_test.dart); the Toko's Bangkit section it tested went in decisions-log 296.

/// Advances the game [n] frames.
Future<void> frames(WidgetTester tester, [int n = 2]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

/// Every item [type]'s awakening recipe asks for, [level] times over.
List<Item> recipe(String type, int level) => [
      for (final MapEntry(key: item, value: n) in awakenRecipe[type]!.entries)
        for (var i = 0; i < n * level; i++) item,
    ];

/// A game whose store is open, rich, with the knight at Bangkit 3 and an archer fielded at Bangkit 2 whose Bangkit 3
/// is in the bag. A plain Game() (the Towns off, tests only): its Awaken by the item recipe.
Game shopper() {
  final g = Game()..wave = storeFrom;
  g.upgrades['knight'] = recipe('knight', 3);
  g.upgrades['archer'] = recipe('archer', 2);
  for (final MapEntry(key: item, value: n) in awakenRecipe['archer']!.entries) {
    g.inventory[item] = n;
  }
  g.gold = 100000;
  expect(g.place('archer', 0, 1), isTrue);
  return g..gold = 1000000;
}

void main() {
  testWidgets("the Tas tab's dot while a fielded type's next Awaken is in the bag, gone without it; no Toko tab", (tester) async {
    tester.view
      ..physicalSize = const Size(1266, 713) // the owner's window
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final game = TdGame();
    await tester.pumpWidget(GameWidget(game: game));
    for (var i = 0; i < 3000 && !game.isLoaded; i++) {
      // onLoad decodes images in real time: let it run, then pump.
      await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 20)));
      await tester.pump();
    }
    expect(game.isLoaded, isTrue);
    final b = game.board..welcome = null;
    final g = b.state = shopper();
    await frames(tester, 40); // the book floats in between waves

    // The Tas tab's dot: the fielded archer's Bangkit 3 is in the bag.
    final dot = b.storeAt('bagDot'), tas = b.bookTabs.firstWhere((t) => t.$1 == 'bag').$2;
    expect(dot, isNot(Rect.zero));
    expect(tas.inflate(8).contains(dot.center), isTrue, reason: 'on the Tas tab');

    expect(b.bookTabs.map((t) => t.$1), ['troops', 'bag', 'settings'], reason: 'the field\'s book: no Toko');
    expect(b.storeTab, Rect.zero);

    // The bag's items gone: no dot.
    g.inventory.clear();
    await frames(tester);
    expect(b.storeAt('bagDot'), Rect.zero);

    await frames(tester, 10); // the tap's timers run out
  });
}
