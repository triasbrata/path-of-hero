// The book's "Cara Main" page (docs/ui-hud.md "Cara Main page", lib/guide_page.dart), as the player gets it: at
// 1266x713 and 915x412 Pengaturan's "Cara Main" sits under the volume bars, clear of them and of the right
// page's buttons; it opens the page, its topics and its words inside the book, every topic reachable and opened by a
// tap, the words scrolled by the wheel and a drag; each topic holds its intro pages and cards word for word, its own
// lines and the game's own item, relic and Pusaka texts; "Ulang panduan" plays the intro over the page and leaves the
// seen set as it is; "Kembali" goes back to Pengaturan. One TdGame per widget test (docs/testing.md).
import 'dart:math';

import 'package:flame/game.dart' hide Game;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';
import 'package:tower_defense/guide_rules.dart';
import 'package:tower_defense/guide_text.dart';
import 'package:tower_defense/main.dart';

import 'hud_font.dart';

const sizes = [Size(1266, 713), Size(915, 412)];

Future<Board> boot(WidgetTester tester, Size size) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await loadHudFont(tester);
  final game = TdGame();
  await tester.pumpWidget(GameWidget(game: game));
  for (var i = 0; i < 3000 && !game.isLoaded; i++) {
    // onLoad decodes images in real time: let it run, then pump.
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 20)));
    await tester.pump();
  }
  expect(game.isLoaded, isTrue);
  final b = game.board
    ..welcome = null
    ..miniMapOpen = false;
  b.state = Game(Random(1)).boardRules();
  return b;
}

Future<void> frames(WidgetTester tester, [int n = 2]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

Future<void> tap(WidgetTester tester, Rect r, String why) async {
  expect(r, isNot(Rect.zero), reason: '$why: drawn');
  await tester.tapAt(r.center);
  await frames(tester, 5); // past the tap's own timer
}

/// [r] inside [outer].
void within(Rect r, Rect outer, String why) {
  expect(r, isNot(Rect.zero), reason: '$why: drawn');
  expect((r.left >= outer.left, r.top >= outer.top, r.right <= outer.right, r.bottom <= outer.bottom), (true, true, true, true),
      reason: '$why: $r in $outer');
}

/// [a] and [b] not overlapping.
void clear(Rect a, Rect b, String why) =>
    expect(a.intersect(b).width <= 0 || a.intersect(b).height <= 0, isTrue, reason: '$why: $a over $b');

/// Opens Pengaturan, then its "Cara Main".
Future<void> openPage(WidgetTester tester, Board b) async {
  b.showSettings();
  await frames(tester, 40); // the book is open between waves
  await tap(tester, b.howToButton, 'Cara Main');
  expect(b.howToShown, isTrue);
}

/// The mouse's wheel over [at]: [n] notches of [dy] px, a frame after each; what [seen] collects after each.
Future<void> wheel(WidgetTester tester, Offset at, double dy, {int n = 1, void Function()? seen}) async {
  final mouse = TestPointer(1, PointerDeviceKind.mouse);
  await tester.sendEventToBinding(mouse.hover(at));
  for (var i = 0; i < n; i++) {
    await tester.sendEventToBinding(mouse.scroll(Offset(0, dy)));
    await frames(tester);
    seen?.call();
  }
}

/// Opens the topic [title]: the list scrolled to the top, then down until its row shows whole, and a tap on it.
Future<void> openTopic(WidgetTester tester, Board b, String title) async {
  final list = b.howToColumns[0];
  await wheel(tester, list.center, -2000);
  Rect? row() => {for (final (t, r) in b.howToTopics) t: r}[title];
  final whole = b.howToTopics.map((e) => e.$2.height).reduce(max); // a row not cut by the list's edge
  for (var i = 0; i < 40 && (row() == null || row()!.height < whole - 0.5); i++) {
    await wheel(tester, list.center, 20);
  }
  await tap(tester, row()!, title);
  expect(b.howToTopic, title);
}

void main() {
  final topics = [for (final t in guideEn.topics) t.title];

  for (final size in sizes) {
    final tag = '${size.width.round()}x${size.height.round()}';

    testWidgets('$tag: "Cara Main" under the volume bars opens the page; every topic opens, its words scroll; Kembali',
        (tester) async {
      final b = await boot(tester, size);
      b.showSettings();
      await frames(tester, 40);
      // Pengaturan's left page: "Cara Main" under both volume rows, clear of them, in the book; the right page's
      // buttons clear of it.
      final button = b.howToButton, book = b.bookArea, screen = Offset.zero & size;
      expect(b.volumeRows, hasLength(2));
      for (final row in b.volumeRows) {
        expect(button.top, greaterThan(row.bottom), reason: '$tag: under the volume bar $row');
        clear(button, row, '$tag: the volume bar');
      }
      within(button, book, '$tag: Cara Main in the book');
      within(book, screen, '$tag: the book on the screen');
      for (final other in [b.sendButton, b.licenceButton, b.foeCutButton, b.heroCutButton, b.menuButton]) {
        expect(other, isNot(Rect.zero));
        clear(button, other, '$tag: a right page button');
      }

      await tap(tester, button, 'Cara Main');
      expect((b.howToShown, b.sendButton, b.howToButton), (true, Rect.zero, Rect.zero));
      expect(b.howToTopic, topics.first);
      // Pengaturan's tab stays the open one: a tap on it changes nothing.
      final tab = {for (final (name, r) in b.bookTabs) name: r}['settings']!;
      await tap(tester, tab, 'the Pengaturan tab');
      expect(b.howToShown, isTrue);

      // Everything on its pages, inside the book: the two columns, Kembali under the list, Ulang panduan under the words.
      final [list, words] = b.howToColumns;
      for (final (r, why) in [(list, 'the topics'), (words, 'the words'), (b.howToBack, 'Kembali'), (b.howToReplay, 'Ulang panduan')]) {
        within(r, book, '$tag: $why');
      }
      clear(list, words, '$tag: the columns');
      expect(b.howToBack.top, greaterThan(list.bottom), reason: '$tag: Kembali under the topics');
      expect(b.howToReplay.top, greaterThan(words.bottom), reason: '$tag: Ulang panduan under the words');
      clear(b.howToBack, b.howToReplay, '$tag: the two buttons');
      for (final (title, r) in b.howToTopics) {
        within(r, list, '$tag: $title');
      }

      // Every topic is in the list (the wheel scrolls it where it is longer than the page), and opens on a tap with
      // its words from the top: its first page's title and lines, or its own first line.
      final listed = {for (final (t, _) in b.howToTopics) t};
      await wheel(tester, list.center, 30, n: 20, seen: () => listed.addAll([for (final (t, _) in b.howToTopics) t]));
      expect(listed, topics.toSet(), reason: tag);
      for (final topic in guideEn.topics) {
        await openTopic(tester, b, topic.title);
        await frames(tester, 3);
        final pages = guideEn.pagesOf(topic), text = b.howToText;
        if (pages.isEmpty) {
          expect(text.first, topic.lines.first, reason: topic.title);
        } else {
          expect(text.take(2), [pages.first.title, pages.first.lines.join(' ')], reason: topic.title);
        }
      }

      // The words scroll: "Items & Awaken" runs past the page; the wheel brings its last line up, and a drag takes it
      // back to the top. A drag on the topics opens none.
      await openTopic(tester, b, 'Items & Awaken');
      await frames(tester, 10); // all of it laid out
      final last = b.howToParas.last, first = b.howToText.first;
      expect(first, 'Items');
      expect(b.howToText, isNot(contains(last)), reason: '$tag: the end is below the page');
      await wheel(tester, words.center, 40, n: 60);
      expect(b.howToText, contains(last), reason: tag);
      expect(b.howToText, isNot(contains(first)), reason: tag);
      await tester.dragFrom(list.center, const Offset(0, 30));
      await frames(tester, 5);
      expect(b.howToTopic, 'Items & Awaken', reason: '$tag: a drag opens no topic');
      for (var i = 0; i < 30 && !b.howToText.contains(first); i++) {
        await tester.dragFrom(Offset(words.center.dx, words.top + 10), Offset(0, words.height - 20));
        await frames(tester, 5);
      }
      expect(b.howToText.first, first, reason: '$tag: dragged back to the top');

      // "Kembali": Pengaturan again; and its "Cara Main" opens on the topic open last.
      await tap(tester, b.howToBack, 'Kembali');
      expect((b.howToShown, b.sendButton == Rect.zero), (false, false));
      await tap(tester, b.howToButton, 'Cara Main');
      expect((b.howToShown, b.howToTopic), (true, 'Items & Awaken'));
    });
  }

  testWidgets('each topic holds its intro pages and cards word for word, its own lines and the game\'s own texts', (tester) async {
    final b = await boot(tester, sizes.first);
    await openPage(tester, b);
    final g = b.state;
    for (final topic in guideEn.topics) {
      await openTopic(tester, b, topic.title);
      await frames(tester, 10); // all of it laid out
      final all = b.howToParas, joined = all.join(' ');
      for (final page in guideEn.pagesOf(topic)) {
        expect(all, contains(page.title), reason: topic.title);
        expect(all, anyOf(contains(page.lines.join(' ')), contains(page.linesFor(touch: false).join(' '))), reason: topic.title);
      }
      expect(joined, contains(topic.lines.join(' ')), reason: topic.title);
      // A title once where a card's pages share it (K4's two, K5's two).
      for (final k in topic.cards.where((k) => const ['K4', 'K5'].contains(k))) {
        expect(all.where((p) => p == guideEn.cards[k]!.first.title), hasLength(1), reason: k);
      }
      switch (topic.live) {
        case GuideLive.items:
          for (final item in g.itemsInPlay) {
            expect(all, contains(itemNames[item]), reason: '$item');
            expect(all, containsAll(g.itemEffect(item)), reason: '$item');
          }
          expect(all.where((p) => p == 'For a whole type, up to a cap'), hasLength(1), reason: 'a line every item has, once');
        case GuideLive.relics:
          for (final r in g.relicsInPlay) {
            expect(all, containsAll([relicNames[r], ...g.relicEffect(r)]), reason: '$r');
          }
          // Every game has the Towns (decisions-log 237, 321): all eleven, and the forge's nine (decisions-log 272).
          expect(g.relicsInPlay, [...smallRelics, ...forgeRelics]);
          expect(all.where((p) => p == relicSlotsLine), hasLength(1));
        case GuideLive.pusaka:
          for (final r in Relic.values.where((r) => r.pusaka)) {
            final name = '${relicNames[r]} (${rarityNames[r.rarity]})';
            if (r.rarity == Rarity.legenda) {
              expect(joined, isNot(contains(relicNames[r]!)), reason: 'a Legenda is left to be found: $r');
            } else {
              expect(all, containsAll([name, ...g.relicEffect(r, stars: 1)]), reason: '$r');
            }
          }
        case null:
          expect(joined, isNot(contains(itemNames[Item.sword]!)), reason: topic.title);
      }
    }
    // Every intro page and card is on the page, each in one topic.
    expect([for (final t in guideEn.topics) ...guideEn.pagesOf(t)], hasLength(guideEn.intro.length + [for (final c in guideEn.cards.values) ...c].length));
  });

  testWidgets('"Ulang panduan" plays the intro over the page; the seen set stays; no seen set plays it too', (tester) async {
    final b = await boot(tester, sizes.last);
    final seen = {guideIntro, 'P1', 'P2', 'K1', 'K13'};
    b.guideSeen = {...seen};
    await openPage(tester, b);
    await openTopic(tester, b, 'Waves & ${Words.autoWave}');
    await tap(tester, b.howToReplay, 'Ulang panduan');
    expect(b.coachCard, (guideIntro, 0));
    // Under it the page takes nothing: a tap on a topic's row (one clear of the card's buttons) only turns the intro's
    // page.
    final buttons = b.coachButtons.values;
    final row = [for (final (_, r) in b.howToTopics) if (!buttons.any((x) => x.contains(r.center))) r].first;
    await tap(tester, row, 'a topic under the intro');
    expect((b.coachCard, b.howToTopic), ((guideIntro, 1), 'Waves & ${Words.autoWave}'));
    await tap(tester, b.coachButtons['skip']!, 'Lewati');
    expect((b.coachCard, b.howToShown, b.howToTopic), (null, true, 'Waves & ${Words.autoWave}'));
    expect(b.guideSeen, seen, reason: 'the cards seen stay seen');
    // Watched to its end ("Main!"), the same.
    await tap(tester, b.howToReplay, 'Ulang panduan');
    for (var i = 0; i < guideEn.intro.length && b.coachCard != null; i++) {
      await frames(tester, 20);
      await tap(tester, b.coachButtons['next']!, 'Lanjut');
    }
    expect(b.coachCard, isNull);
    expect(b.guideSeen, seen);
    // No seen set (the guide off): it still plays, and nothing is saved.
    b.guideSeen = null;
    await tap(tester, b.howToReplay, 'Ulang panduan');
    expect(b.coachCard, (guideIntro, 0));
    await tap(tester, b.coachButtons['skip']!, 'Lewati');
    expect((b.coachCard, b.guideSeen, b.howToShown), (null, null, true));
  });
}
