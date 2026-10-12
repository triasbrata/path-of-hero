// The Town's Tavern pages (decisions-log 267; ui-hud.md "The Tavern"; lib/tavern_page.dart; the rules: tavern_test.dart),
// booted TdGames with the Towns and the Tavern on (dark: turned on per game), in a Town gone into: the book's tabs (the
// Tavern after the Smithy, its dot while the offers are unseen), the left page's offers as rows in their slots (the
// first Town's Feast first, the pick, the prices, "Sold"), Reroll's tag and the boosts running, the right page's heading,
// lines, Effect rows and the one bevelled Buy, all inside the book at 1266x713, 1164x777 and 915x412 (the
// King's Banquet's six rows too); a buy by a tap ("Feast! 2 waves"), the refusals by a tap ("Sold", "Not enough gold"),
// a reroll by a tap, the Tavern's sign opening its page, leaving the Town shutting it, and the Tavern off: no tab, the
// sign opens the Bag. One TdGame per widget test.
//
// Never let a wave be won or the game end here (the Board then saves).
import 'dart:math';

import 'package:flame/game.dart' hide Game;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';
import 'package:tower_defense/main.dart';

import 'hud_font.dart';
import 'page_scroll.dart';
import 'town_scene_test.dart' show wheel;

Future<Board> boot(WidgetTester tester, [Size size = const Size(1266, 713)]) async {
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
    ..miniMapOpen = false
    ..autoStart.set(false);
}

Future<void> frames(WidgetTester tester, [int n = 2]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

/// Taps [r]'s middle (never Rect.zero).
Future<void> tapOn(WidgetTester tester, Rect r, [String why = '']) async {
  expect(r, isNot(Rect.zero), reason: why);
  await tester.tapAt(r.center);
  await frames(tester, 3);
}

/// Shuts the message window (it can lie over the tabs or the rows).
Future<void> shutMessage(WidgetTester tester, Board b) async {
  if (b.messageBox != Rect.zero) await tapOn(tester, b.messageBox);
}

/// Turns the open book to [page] by its tab.
Future<void> turnTo(WidgetTester tester, Board b, String page) async {
  await shutMessage(tester, b);
  await tapOn(tester, b.bookTabs.firstWhere((t) => t.$1 == page).$2, page);
}

/// A point on the Town's bare scene: under the HUD's rows, left of the book, on no sign or place (town_scene_test.dart's).
Offset bare(Board b, Size size) {
  final taken = [...b.townScene.entries.where((e) => !const {'scene', 'street'}.contains(e.key)).map((e) => e.value),
    for (final place in const ['smithy', 'tavern', 'shop']) b.townSign(place),
    b.bookArea, b.waveMeter, b.logButton, b.troopCounter];
  for (var y = b.waveMeter.bottom + 12; y < size.height - 8; y += 8) {
    for (var x = 8.0; x < (b.bookArea.isEmpty ? size.width : b.bookArea.left) - 8; x += 8) {
      final p = Offset(x, y);
      if (!taken.any((r) => r.inflate(4).contains(p))) return p;
    }
  }
  fail('no bare scene to tap');
}

/// [r] wholly inside [area].
bool inside(Rect r, Rect area) => r.left >= area.left - 0.5 && r.top >= area.top - 0.5 && r.right <= area.right + 0.5 && r.bottom <= area.bottom + 0.5;

const sizes = [Size(1266, 713), Size(1164, 777), Size(915, 412)];

/// A board game (the Towns and with them the Tavern on) gone into the Town after wave [wave] ([Towns.enterTown]:
/// the Tavern rolls its offers, the run's first Town's Feast first), [rules] (the defaults), a soldier, a knight, an
/// archer and a priest, and [gold].
Game tavernGame({int wave = 20, int gold = 40000, TownRules rules = const TownRules()}) {
  final g = Game(Random(1), Random(2)).boardRules()
    ..townDice = Random(3)
    ..tavernDice = Random(4)
    ..towns = true
    ..townRules = rules
    ..armyMax = null
    ..wave = wave;
  for (final type in ['soldier', 'knight', 'archer', 'priest']) {
    g.autoPlace(type);
  }
  for (final u in g.troops) {
    u
      ..pos = u.post
      ..arriving = false;
  }
  g
    ..gold = gold
    ..townAt = wave + 1;
  expect(g.enterTown(), isTrue);
  return g;
}

/// What [at] gives on the Tavern's left page under "Offers" ([left]) or its right page under the heading, scrolled into
/// view ([scrolledTo]; each scrolls where it doesn't fit, decisions-log 283).
Future<Rect> seen(WidgetTester tester, Board b, Rect Function() at, {bool left = false}) =>
    scrolledTo(tester, b, left ? 'tavernList' : 'tavernFacing', at);

/// Every part of the Tavern's pages inside the book, each reached by its page's scroll where the page is short
/// (decisions-log 283): on the left page "Offers", the rows in order, Reroll under them, then what of "Active" is drawn;
/// on the right page the icon, the Effect rows in order, Buy under them and the grey "No limit" under Buy. Leaves both
/// pages scrolled back to their tops.
Future<void> fits(WidgetTester tester, Board b, String tag) async {
  Future<({Rect at, double top, double bottom})> on(String what, Rect Function() at, {bool left = false}) async {
    final r = await scrolledDown(tester, b, left ? 'tavernList' : 'tavernFacing', at);
    final page = left ? b.bookPages.$1 : b.bookPages.$2; // the book bobs: this frame's page
    expect(r.at != Rect.zero && inside(r.at, page), isTrue, reason: '$tag $what: ${r.at} in $page');
    return r;
  }

  expect(inside(b.tavernAt('offers'), b.bookPages.$1), isTrue, reason: '$tag offers: ${b.tavernAt('offers')}');
  var above = 0.0;
  for (var i = 0; i < b.tavernRows.length; i++) {
    final r = await on('row $i ${b.tavernRows[i].kind}', () => b.tavernRows[i].at, left: true);
    expect(r.top, greaterThanOrEqualTo(above), reason: '$tag: rows ${i - 1} and $i apart');
    above = r.bottom;
  }
  final reroll = await on('reroll', () => b.tavernAt('reroll'), left: true);
  expect(reroll.top, greaterThanOrEqualTo(above), reason: '$tag: Reroll under the rows');
  for (final key in ['stay', 'active', 'none', 'active:0', 'active:1']) {
    if (key != 'active' && (b.tavernText(key) ?? '').isEmpty) continue; // not drawn
    final r = await on(key, () => b.tavernAt(key), left: true);
    expect(r.top, greaterThanOrEqualTo(reroll.top), reason: '$tag $key: under Reroll');
  }
  expect(inside(b.tavernAt('icon'), b.bookPages.$2), isTrue, reason: '$tag icon: ${b.tavernAt('icon')}');
  above = 0;
  for (var i = 0; i < b.tavernEffects.length; i++) {
    final r = await on('effect ${b.tavernEffects[i].what}', () => b.tavernEffects[i].at);
    expect(r.top, greaterThanOrEqualTo(above), reason: '$tag: effects ${i - 1} and $i apart');
    above = r.bottom;
  }
  final buy = await on('buy', () => b.tavernAt('buy'));
  expect(buy.top, greaterThanOrEqualTo(above), reason: '$tag: Buy under the Effect rows');
  final noLimit = await on('noLimit', () => b.tavernAt('noLimit'));
  expect(noLimit.top, greaterThanOrEqualTo(buy.bottom - 0.5), reason: '$tag: "No limit" under Buy');
  b
    ..setPageScroll('tavernList', 0)
    ..setPageScroll('tavernFacing', 0);
  await frames(tester);
}

void main() {
  for (final size in sizes) {
    final tag = '${size.width.round()}x${size.height.round()}';
    testWidgets('the Tavern at $tag: its tab and dot, the offers, the facing page, Buy, the refusals, Reroll; it fits', (tester) async {
      final b = await boot(tester, size);
      final g = b.state = tavernGame();
      await frames(tester, 40);
      expect(b.bookPage, 'smithy', reason: 'a Town still opens the book on the Smithy');
      expect([for (final (name, _) in b.bookTabs) name], ['smithy', 'tavern', 'store', 'troops', 'bag', 'settings']);
      final tab = b.bookTabs.firstWhere((t) => t.$1 == 'tavern').$2;
      expect(b.storeAt('tavernDot'), isNot(Rect.zero), reason: 'the offers not seen yet: the dot on its tab');
      expect(inside(b.storeAt('tavernDot'), tab.inflate(4)), isTrue, reason: '$tag: the dot on the Tavern tab');

      await turnTo(tester, b, 'tavern');
      await frames(tester, 40);
      expect(b.bookPage, 'tavern');
      expect(b.storeAt('tavernDot'), Rect.zero, reason: 'seen: the dot goes');
      final offers = g.tavernOffers, kinds = [for (final o in offers) o.kind];
      expect(kinds.first, Boost.feast, reason: "the run's first Town: the Feast first");
      expect([for (final r in b.tavernRows) r.slot], [0, 1, 2]);
      expect([for (final r in b.tavernRows) r.kind], kinds);
      expect([for (final r in b.tavernRows) r.price], [for (final k in kinds) thousands(g.boostPrice(k))]);
      expect([for (final r in b.tavernRows) r.short], [false, false, false]);
      expect(b.tavernPick, 0, reason: 'the first offer not bought');
      expect([for (final r in b.tavernRows) r.picked], [true, false, false]);
      expect(b.tavernText('offers'), anyOf('New offers every Town', 'New every Town', ''));
      expect(b.tavernText('reroll'), 'Reroll ${thousands(g.tavernRerollPrice)}');
      expect(b.tavernText('none'), 'None yet.');
      await fits(tester, b, tag);

      // The Feast's page: its heading, what it does, how long, its Effect rows, Buy with its price.
      expect((b.tavernText('name'), b.tavernText('rarity')), ('Feast', 'Rare'));
      expect(b.tavernText('does')!.replaceAll('\n', ' '), 'Every troop: +20% damage, 15% less damage taken.');
      // In grey its rarity and how long: whole, or on a short page its first line (cut: "..") or none.
      final line = b.tavernText('line')!.replaceAll('\n', ' ').replaceAll('..', '');
      expect('Rare boost. Lasts the next 2 waves.'.startsWith(line), isTrue, reason: line);
      expect([for (final e in b.tavernEffects) (e.what, e.value)],
          [('Damage', '+20%'), ('Damage taken', '-15%'), ('Troops', 'All troops'), ('Waves', '2')]);
      final price = g.boostPrice(Boost.feast);
      expect(price, 700, reason: 'the Feast after wave 20 (decisions-log 266; 800 before 318)');
      expect(b.tavernText('buy'), anyOf('Buy (700 gold)', 'Buy (700)', 'Buy'));

      // Buy: it runs, the message says so, the row is sold and the boost shows under Active with its waves left.
      await tapOn(tester, await seen(tester, b, () => b.tavernAt('buy')), 'Buy');
      await frames(tester, 2);
      expect(b.message, 'Feast! 2 waves');
      expect(g.gold, 40000 - 700);
      expect([for (final x in g.boosts) (x.kind, x.left)], [(Boost.feast, 2)]);
      expect(b.tavernRows.first.price, 'Sold');
      expect(b.tavernText('buy'), 'Sold');
      expect(b.tavernAt('none'), Rect.zero);
      expect(b.tavernText('active:0')!.split(':').first, '2');
      await fits(tester, b, '$tag bought');
      // The white Buy says why again.
      await shutMessage(tester, b);
      await tapOn(tester, await seen(tester, b, () => b.tavernAt('buy')), 'Buy sold');
      expect(b.message, 'Sold');
      expect(g.gold, 40000 - 700, reason: 'nothing bought');

      // Another offer picked: its page; short of gold its price is red, Buy and Reroll say why.
      await shutMessage(tester, b);
      await tapOn(tester, await seen(tester, b, () => b.tavernRows[1].at, left: true), 'row 1');
      expect(b.tavernPick, 1);
      expect(b.tavernText('name'), boostNames[kinds[1]]);
      expect([for (final r in b.tavernRows) r.picked], [false, true, false]);
      g.gold = 0;
      await frames(tester, 2);
      expect([for (final r in b.tavernRows) r.short], [false, true, true]);
      expect(b.tavernText('buy'), 'Not enough gold');
      await tapOn(tester, await seen(tester, b, () => b.tavernAt('buy')), 'Buy short');
      expect(b.message, 'Not enough gold');
      expect(g.boosts.length, 1);
      await shutMessage(tester, b);
      await tapOn(tester, await seen(tester, b, () => b.tavernAt('reroll'), left: true), 'Reroll short');
      expect(b.message, 'Not enough gold');
      expect(g.tavernRerolls, 0);

      // Reroll with gold: the offers not bought are drawn again, the bought one stays; the next reroll costs double.
      await shutMessage(tester, b);
      g.gold = 40000;
      final first = g.tavernRerollPrice;
      await tapOn(tester, await seen(tester, b, () => b.tavernAt('reroll'), left: true), 'Reroll');
      await frames(tester, 40);
      expect(g.tavernRerolls, 1);
      expect(g.gold, 40000 - first);
      expect(g.tavernOffers.first.kind, Boost.feast);
      expect(g.tavernOffers.first.sold, isTrue);
      expect([for (final r in b.tavernRows) r.kind], [for (final o in g.tavernOffers) o.kind]);
      expect(b.tavernText('reroll'), 'Reroll ${thousands(g.tavernRerollPrice)}');
      expect(g.tavernRerollPrice, greaterThan(first));
      expect(b.storeAt('tavernDot'), Rect.zero, reason: 'the new offers seen on the page');
      await fits(tester, b, '$tag rerolled');

      // Leaving the Town shuts the Tavern: the Army's page.
      await shutMessage(tester, b);
      expect(g.leaveTown(), isTrue);
      await frames(tester, 3);
      expect(b.bookPage, isNot('tavern'));
      expect([for (final (name, _) in b.bookTabs) name], isNot(contains('tavern')));
    });

    testWidgets("the Tavern at $tag: the King's Banquet's six Effect rows and the Champion's Plate fit", (tester) async {
      final b = await boot(tester, size);
      // After wave 30 every roll a Legendary: the Banquet, then the Epics (the step down).
      final g = b.state = tavernGame(
          wave: 30,
          rules: TownRules.patch({
            'tavern': {
              'odds': {'common': 0.0, 'rare': 0.0, 'epic': 0.0, 'legendary': 1.0},
              'firstFeast': false,
            },
          }));
      await frames(tester, 40);
      await turnTo(tester, b, 'tavern');
      await frames(tester, 40);
      final kinds = [for (final o in g.tavernOffers) o.kind];
      expect(kinds.first, Boost.banquet);
      expect(kinds.skip(1).toSet(), {Boost.plate, Boost.watch});
      expect((b.tavernText('name'), b.tavernText('rarity')), ("King's Banquet", 'Legendary'));
      expect([for (final e in b.tavernEffects) e.what], ['Damage', 'Damage taken', 'Max HP', 'Attack speed', 'Troops', 'Waves']);
      await fits(tester, b, '$tag banquet');
      final buy = await seen(tester, b, () => b.tavernAt('buy'));
      expect(buy != Rect.zero && buy.bottom <= b.bookPages.$2.bottom + 0.5, isTrue, reason: '$tag: Buy $buy');

      // The Plate's page: its type's plural as its troops; the Watchman's Brew's: no Troops row.
      final plate = kinds.indexOf(Boost.plate), type = g.tavernOffers[plate].type!;
      await tapOn(tester, await seen(tester, b, () => b.tavernRows[plate].at, left: true), 'the Plate');
      expect(b.tavernText('does')!.replaceAll('\n', ' '), '${troopTypePlurals[type]}: +40% damage, +15% attack speed.');
      expect([for (final e in b.tavernEffects) (e.what, e.value)],
          [('Damage', '+40%'), ('Attack speed', '+15%'), ('Troops', troopTypePlurals[type]!), ('Waves', '2')]);
      await fits(tester, b, '$tag plate');
      await tapOn(tester, await seen(tester, b, () => b.tavernRows[kinds.indexOf(Boost.watch)].at, left: true), 'the Watch');
      expect(b.tavernText('does')!.replaceAll('\n', ' '), 'A leak a wave costs no life.');
      expect([for (final e in b.tavernEffects) (e.what, e.value)], [('Leaks forgiven', '1 a wave'), ('Waves', '2')]);
      await fits(tester, b, '$tag watch');
    });
  }

  testWidgets("the Tavern's sign opens its page", (tester) async {
    final b = await boot(tester);
    b.state = tavernGame();
    await frames(tester, 40);
    await shutMessage(tester, b);
    // The bare scene shuts the book (the Smithy in the middle, the Town wider than the screen: the wheel brings the
    // Tavern in, decisions-log 271), then the Tavern's sign opens its page.
    await tester.tapAt(bare(b, const Size(1266, 713)));
    await frames(tester, 40);
    expect(b.bookArea, Rect.zero);
    await wheel(tester, bare(b, const Size(1266, 713)), b.townSign('tavern').center.dx - 1266 / 2);
    final sign = b.townSign('tavern');
    expect(sign, isNot(Rect.zero));
    await tester.tapAt(sign.center);
    await frames(tester, 40);
    expect(b.bookPage, 'tavern');
    expect(b.tavernRows, hasLength(3));
  });
}
