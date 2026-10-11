// The shorter landscape book over the full-width spawn bar (decisions-log 283's follow-up; ui-hud.md "The book" and
// "Spawn bar"): offscreen shots into <probe root>/shots/spawn-bar/book (`OUT`). A probe, not part of the suite (no
// `_test.dart`): queue `["test", "test/probe_book_short_shots.dart"]` with a mirror as `dir` (`--plain-name <size>` for
// one size). It never touches the real save (flutter_test_config.dart's temp dir).
//
// At 1600x947, 1266x713, 1164x777, 915x412 and 412x860 (<size>): the owner's w89 save between waves with the book on
// each of its tabs (field-<tab>-<size>), then a Town's book on each of its tabs (town-<tab>-<size>). Each line printed
// gives the book, its pages' writing, the bar's row and the log button, for a crop, and the numbers ui-hud.md gives: the
// Army grid's cell and pages and the detail's body, the Bag's and the Smithy's pages, the bar's cards and arrows.
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

const out = String.fromEnvironment('OUT', defaultValue: '$probeRoot/shots/spawn-bar/book');

Game load() => Game.fromJson(jsonDecode(File('test/fixtures/save-20261002-2222-w89-sellbug.json').readAsStringSync()) as Map<String, dynamic>)
    .boardRules()
  ..chests.clear();

List<int> _r(Rect r) => [r.left.round(), r.top.round(), r.right.round(), r.bottom.round()];

void main() {
  for (final size in const [Size(1600, 947), Size(1266, 713), Size(1164, 777), Size(915, 412), Size(412, 860)]) {
    final tag = '${size.width.round()}x${size.height.round()}';
    testWidgets('book short shots $tag', (tester) async {
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
        print('BOOK ${jsonEncode({
              'shot': '$name-$tag.png',
              'page': b.bookPage,
              'book': _r(b.bookArea),
              'left': _r(b.bookPages.$1),
              'right': _r(b.bookPages.$2),
              'bar': _r(b.spawnBarArea),
              'log': _r(b.logButton),
              'tabs': [for (final (t, _) in b.bookTabs) t],
              if (b.bookPage == 'troops') 'army': {
                'cell': _r(b.troopRow(b.troopPicked)),
                'pages': b.armyPageCount,
                'body': _r(b.troopDetailBody),
                'content': b.troopDetailContent.round(),
              },
              if (b.bookPage == 'bag') 'bag': {'pages': b.bagPages, 'sizes': [b.bagPageSizes.$1, b.bagPageSizes.$2]},
              if (b.bookPage == 'smithy') 'smithy': {'boardPages': b.smithyBoardPages, 'bagPages': b.bagPages},
              'barCards': b.spawnBarCards.length,
              'barCard': b.spawnBarCards.isEmpty ? null : _r(b.spawnBarCards.first.$1),
              'barArrows': [_r(b.spawnBarArrows.$1), _r(b.spawnBarArrows.$2)],
            })}');
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

      // The field: the w89 save between waves, the book on each tab.
      b.state = load();
      await frames(tester, 60);
      for (final t in [for (final (t, _) in b.bookTabs) t]) {
        await page(t);
        await shot('field-$t');
      }
      await page('troops'); // a phone's wave with the book off Army pauses (ui-hud.md "The book pauses a wave")

      // A Town's book on each of its tabs.
      await intoTown(tester, b);
      await settle(tester, b);
      for (final t in [for (final (t, _) in b.bookTabs) t]) {
        await page(t);
        await shot('town-$t');
      }
    });
  }
}
