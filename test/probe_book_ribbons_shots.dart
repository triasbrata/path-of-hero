// The book without its gold and wave ribbons (decisions-log 285; ui-hud.md "Bookmarks"): offscreen shots into
// <probe root>/shots/book-ribbons/ (`OUT`). A probe, not part of the suite (no `_test.dart`): queue
// `["test", "test/probe_book_ribbons_shots.dart"]` with a mirror as `dir` (`--plain-name <size>` for one size). It never
// touches the real save (flutter_test_config.dart's temp dir); the dice are seeded.
//
// At 1266x713, 1164x777, 915x412, 412x860 and 1600x947 (<size>): army-<size> and bag-<size> (the owner's w89 save on
// the field, the book on Army and on Bag), smithy-<size> and shop-<size> (a Town's book on the Smithy and the Shop).
// Each line printed says the book's rect and its tabs, the gold panel and the wave meter.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flame/game.dart' hide Game;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';
import 'package:tower_defense/main.dart';

import 'hud_font.dart';
import 'town_hud_test.dart' show frames;
import 'town_scene_test.dart' show intoTown, settle;
import 'probe_root.dart';

const out = String.fromEnvironment('OUT', defaultValue: '$probeRoot/shots/book-ribbons');

Game load() => Game.fromJson(jsonDecode(File('test/fixtures/save-20261002-2222-w89-sellbug.json').readAsStringSync()) as Map<String, dynamic>)
    .boardRules()
  ..chests.clear();

void main() {
  for (final size in const [Size(1266, 713), Size(1164, 777), Size(915, 412), Size(412, 860), Size(1600, 947)]) {
    final tag = '${size.width.round()}x${size.height.round()}';
    testWidgets('book ribbons shots $tag', (tester) async {
      tester.view
        ..physicalSize = size
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.runAsync(loadHudFontNow);
      final game = TdGame();
      final key = GlobalKey();
      await tester.pumpWidget(RepaintBoundary(key: key, child: GameWidget(game: game)));
      for (var i = 0; i < 3000 && !game.isLoaded; i++) {
        await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 20)));
        await tester.pump();
      }
      expect(game.isLoaded, isTrue);
      final b = game.board
        ..welcome = null
        ..miniMapOpen = false
        ..guideSeen = null;

      Future<void> shot(String name, [int settle = 20]) async {
        await frames(tester, settle);
        final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final img = (await tester.runAsync(() => boundary.toImage()))!;
        await tester.runAsync(() async {
          final png = await img.toByteData(format: ui.ImageByteFormat.png);
          File('$out/$name-$tag.png')
            ..parent.createSync(recursive: true)
            ..writeAsBytesSync(png!.buffer.asUint8List());
        });
        // ignore: avoid_print
        print('wrote $out/$name-$tag.png  page ${b.bookPage} book ${b.bookArea} tabs ${b.bookTabs.map((t) => t.$1).toList()} '
            'gold ${b.state.gold} at ${b.heartsGoldPanel} wave ${b.state.wave} meter ${b.waveMeter}');
      }

      Future<void> page(String name) async {
        if (b.messageBox != Rect.zero) {
          await tester.tapAt(b.messageBox.center);
          await frames(tester);
        }
        if (b.bookPage == name) return;
        await tester.tapAt(b.bookTabs.firstWhere((t) => t.$1 == name).$2.center);
        await frames(tester, 3);
      }

      // The field: the w89 save between waves, the book on Army, then on Bag.
      b.state = load();
      await frames(tester, 60);
      await page('troops');
      await shot('army');
      await page('bag');
      await shot('bag');
      await page('troops'); // a phone's wave with the book off Army pauses (ui-hud.md "The book pauses a wave")

      // A Town's book on the Smithy, then on the Shop.
      await intoTown(tester, b);
      await settle(tester, b);
      await page('smithy');
      await shot('smithy');
      await page('store');
      await shot('shop');
    });
  }
}
