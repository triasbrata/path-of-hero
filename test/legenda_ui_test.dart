// The three Legenda on the board (decisions-log 155; docs/ui-hud.md "Tas", "Peti Bos"): the Tas page's Pusaka slots in a
// row for each rarity (the Legenda under the Langka); an oath picked lists every type with what it gives it, and a tap
// only says how it stands (Oath of One waiting above 2 types); a chest of the three Legenda fits a phone and a laptop,
// its Oath of One card says it would wait, and taking it says so; every new line is in the HUD's font. The rules:
// legenda_test.dart. One TdGame per widget test.
//
// Never let a wave be won or the game end here: the board saves after a pick, into the queue's temp HOME
// (flutter_test_config.dart), never the real save.
import 'dart:math';

import 'package:flame/game.dart' hide Game;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';
import 'package:tower_defense/main.dart';

import 'hud_font.dart';

/// Boots one TdGame in a [size] window, past the welcome screen, with the game's font and the minimap folded.
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
    ..miniMapOpen = false;
}

Future<void> frames(WidgetTester tester, [int n = 2]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

Future<void> tapOn(WidgetTester tester, Offset p) async {
  await tester.tapAt(p);
  await frames(tester);
}

/// A board game between waves at [wave] with the chest on (no army limit), gold to spare and a soldier and a knight
/// beside the free priest: 3 types alive, over Oath of One's 2.
Game boardGame({int wave = 30}) {
  final g = Game(Random(1)).boardRules()
    ..armyMax = null
    ..gold = 200000
    ..wave = wave
    ..chestsGiven = 1
    ..draft = Random(5);
  for (final type in ['soldier', 'knight']) {
    expect(g.autoPlace(type), isTrue);
  }
  for (final u in g.troops) {
    u
      ..pos = u.post
      ..arriving = false;
  }
  return g;
}

/// [rects] all on a [size] screen, none overlapping another.
void fitsApart(List<Rect> rects, Size size, String why) {
  final screen = Offset.zero & size;
  for (final (i, r) in rects.indexed) {
    expect(screen.intersect(r) == r, isTrue, reason: '$why: $r off the screen');
    for (final o in rects.skip(i + 1)) {
      final x = r.intersect(o);
      expect(x.width <= 0 || x.height <= 0, isTrue, reason: '$why: $r over $o');
    }
  }
}

const legenda = [Relic.dragonCrown, Relic.oathOfOne, Relic.alliance];

void main() {
  for (final size in const [Size(915, 412), Size(1266, 713)]) {
    testWidgets('the Bag at ${size.width.round()}x${size.height.round()}: a cell for each Pusaka owned, none for the rest, '
        'the Legenda first; an oath picked lists every type, and a tap says it waits', (tester) async {
      final b = await boot(tester, size);
      final g = b.state = boardGame()
        ..givePusaka(Relic.dragonCrown, type: 'knight')
        ..givePusaka(Relic.oathOfOne);
      expect((g.oathWaits, g.typesAlive), (true, 3));
      await frames(tester, 30);
      if (b.messageBox != Rect.zero) await tapOn(tester, b.messageBox.center);
      await tapOn(tester, b.bookTabs.firstWhere((t) => t.$1 == 'bag').$2.center);
      // The grid (decisions-log 187): the owned two after the bag's items and relics, in Relic order within the
      // Legenda; the oath marked by its crossed swords, Dragon Crown by the Knight it is on.
      final cells = b.bagCells, kinds = [for (final (kind, _) in cells) kind];
      expect([for (final k in kinds) if (k is Relic && k.pusaka) k], [for (final r in Relic.values) if (legenda.contains(r) && g.pusaka.containsKey(r)) r]);
      expect(kinds.indexOf(Relic.dragonCrown), greaterThan(kinds.lastIndexWhere((k) => k is! Relic || !k.pusaka)));
      for (final r in Relic.values) {
        if (r.pusaka && !g.pusaka.containsKey(r)) expect(b.bagSlot(r), Rect.zero, reason: '$r not owned: no cell');
      }
      expect((b.bagMarks(Relic.dragonCrown)!.bound, b.bagMarks(Relic.oathOfOne)!.oath, b.bagMarks(Relic.oathOfOne)!.bound), ('knight', true, null));
      final slots = {Relic.dragonCrown: b.bagSlot(Relic.dragonCrown), Relic.oathOfOne: b.bagSlot(Relic.oathOfOne)};
      fitsApart([for (final (_, r) in cells) r], size, 'cells');
      for (final (_, r) in cells) {
        expect(b.bookArea.intersect(r) == r, isTrue, reason: '$r outside the book');
      }

      // Oath of One picked: its "Each type" (decisions-log 202) lists a row for every type, none refused; the last line
      // says it waits; a tap says so and binds nothing.
      await tapOn(tester, slots[Relic.oathOfOne]!.center);
      expect(b.picked, Relic.oathOfOne);
      expect(b.bagActions.map((a) => a.$1), [BagAction.types, BagAction.sharpen, BagAction.carve]);
      await tapOn(tester, b.bagAction(BagAction.types).center);
      expect(b.assignRows, isNotEmpty);
      expect(b.assignRows.map((r) => r.$3), everyElement(isTrue));
      final (_, row, _) = b.assignRows.firstWhere((r) => r.$1 == 'knight');
      await tapOn(tester, row.center);
      expect((b.message, g.pusaka[Relic.oathOfOne]!.type, g.pusakaOf('knight')), (oathWaiting, null, Relic.dragonCrown));
      await tapOn(tester, slots[Relic.oathOfOne]!.center); // put back
      expect(b.picked, isNull);
      await frames(tester, 10);
    });

    testWidgets('a chest of the three Legenda at ${size.width.round()}x${size.height.round()}: the cards and buttons fit '
        'apart; Oath of One\'s card says it would wait, and taking it says so', (tester) async {
      final b = await boot(tester, size);
      final g = b.state = boardGame(wave: 40);
      g.chests.add(Chest(ChestKind.boss, 40, cards: legenda));
      await frames(tester, 30);
      expect(b.chestOpen, isTrue);
      expect(b.chestCards, hasLength(3));
      fitsApart([...b.chestCards, ...b.chestButtons.values], size, 'the popup');
      expect(g.cardType(Relic.oathOfOne), isNull);
      await tapOn(tester, b.chestCards[1].center);
      await tapOn(tester, b.chestButtons['take']!.center);
      expect((g.oath, g.oathWaits), (Relic.oathOfOne, true));
      expect(g.legendsFound, {Relic.oathOfOne});
      expect(b.message, 'Oath of One: Oath for all troops!\n$oathWaitingNote');
      expect(b.chestOpen, isFalse);
      await frames(tester, 30);
    });
  }

  test("the Legenda's lines are in the HUD's font (no '≤' or '→'; '★' is drawn as an icon)", () {
    final font = fontChars();
    final g = boardGame()
      ..givePusaka(Relic.dragonCrown, type: 'knight')
      ..givePusaka(Relic.alliance);
    final crown = (relic: Relic.dragonCrown, type: 'knight', stars: 1, uses: 3, worth: 4567.0);
    final lines = <String>[
      for (final r in legenda) ...[relicNames[r]!, pusakaGist(r, 1), ...g.relicEffect(r), rarityNames[r.rarity]!],
      ...g.pusakaTotals(Relic.dragonCrown),
      ...g.pusakaTotals(Relic.alliance),
      g.pusakaWhere(Relic.dragonCrown).replaceAll('★', ''),
      g.pusakaWhere(Relic.alliance).replaceAll('★', ''),
      oathWaiting,
      oathWaitingNote,
      oathWaitingRow(5),
      oathLine,
      pusakaRefusals.oath,
      pusakaActionNames[PusakaAction.sumpah]!,
      g.buildNameOf('knight')!,
      pusakaCounter(crown),
      ...pusakaReportLines(PusakaReport(30, 0, lines: [crown])),
      'New: all troops, whole run',
      '$oathWaiting (now 5)',
      'Oath of One: Oath for all troops!',
      offerLine(OfferPicked(30, 0, pick: Relic.oathOfOne, stars: 1, rerolls: 0, chest: 'boss', chestWave: 30)),
    ];
    expect(pusakaCounter(crown), '+4.6k blocked');
    expect(pusakaReportLines(PusakaReport(30, 0, lines: [crown])), ['Dragon Crown (${troopTypeNames['knight']}): 3 hits cut, +4.6k HP kept']);
    expect(offerLine(OfferPicked(30, 0, pick: Relic.oathOfOne, stars: 1, rerolls: 0, chest: 'boss', chestWave: 30)),
        'Boss Chest: Oath of One ★1 (Legendary) for all troops');
    for (final l in lines) {
      final missing = {for (final c in l.replaceAll('★', '').runes) if (!font.contains(c)) String.fromCharCode(c)};
      expect(missing, isEmpty, reason: '"$l"');
    }
  });
}
