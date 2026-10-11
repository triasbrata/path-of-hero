// The Smithy's fit tables in ui-hud.md "The Smithy" (decisions-log 283: re-measured on the shorter landscape book): at
// 1600x947, 1266x713, 1164x777, 915x412 and 412x860 one line per board printed, its slot, columns and rows on each page,
// its pages, and the materials' grid under it (rows alone and with the pager, pages), and whether the facing page
// scrolls (its content against its view). With 26 kinds (forge_smithy_ui_test.dart's game): its Items and Relics tabs;
// then after wave 30 the Enhance tab with every item in the Bag (forge_enhance_ui_test.dart's game) and 26 kinds; a shot
// of each into `OUT` (smithy-<items|relics|enhance>-<size>.png). A probe, not part of the suite (no `_test.dart`): queue
// `["test", "test/probe_smithy_fit.dart"]` with a mirror as `dir`. It never touches the real save
// (flutter_test_config.dart's temp dir).
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flame/game.dart' hide Game;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';
import 'package:tower_defense/main.dart';

import 'forge_enhance_ui_test.dart' as enhance show enhanceGame;
import 'forge_smithy_ui_test.dart' as forge show forgeGame, giveMats, segment;
import 'hud_font.dart';
import 'town_smithy_ui_test.dart' show frames, tapOn;
import 'probe_root.dart';

const out = String.fromEnvironment('OUT', defaultValue: '$probeRoot/shots/spawn-bar/smithy');

/// A grid's cells as "slot WxH, columns c, rows r, n cells".
String grid(Iterable<Rect> cells) {
  final rs = cells.toList();
  if (rs.isEmpty) return 'none';
  final s = rs.first.size;
  return '${s.width.round()}x${s.height.round()} ${{for (final r in rs) r.left.round()}.length}c '
      '${{for (final r in rs) r.top.round()}.length}r n${rs.length}';
}

void main() {
  for (final size in const [Size(1600, 947), Size(1266, 713), Size(1164, 777), Size(915, 412), Size(412, 860)]) {
    final tag = '${size.width.round()}x${size.height.round()}';
    testWidgets('smithy fit $tag', (tester) async {
      tester.view
        ..physicalSize = size
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await loadHudFont(tester);
      final game = TdGame(), key = GlobalKey();
      await tester.pumpWidget(RepaintBoundary(key: key, child: GameWidget(game: game)));
      for (var i = 0; i < 3000 && !game.isLoaded; i++) {
        await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 20)));
        await tester.pump();
      }
      expect(game.isLoaded, isTrue);
      final b = game.board
        ..welcome = null
        ..miniMapOpen = false
        ..autoStart.set(false);
      Future<void> shot(String name) async {
        await frames(tester, 10);
        final img = (await tester.runAsync(() => (key.currentContext!.findRenderObject()! as RenderRepaintBoundary).toImage()))!;
        await tester.runAsync(() async {
          final png = await img.toByteData(format: ui.ImageByteFormat.png);
          File('$out/smithy-$name-$tag.png')
            ..parent.createSync(recursive: true)
            ..writeAsBytesSync(png!.buffer.asUint8List());
        });
      }

      String mats() => 'mats ${b.smithyText('kinds')} ${grid([for (final (_, r) in b.bagCells) r])} pages ${b.bagPages} '
          'perOne ${b.bagPageSizes.$1} perPaged ${b.bagPageSizes.$2}';
      String facing() => 'facing ${b.pageScrollContent('smithy').round()}/${b.pageScrollView('smithy').height.round()}';
      Future<String> boardPages() async {
        final out = <String>[];
        for (var p = 0; p < b.smithyBoardPages; p++) {
          if (p > 0) await tapOn(tester, b.smithyBoardPager('on'));
          out.add(grid([for (final (_, r) in b.smithyCells) r, for (final (_, r) in b.smithyEnhanceCells) r])); // the tab's board
        }
        while (b.smithyBoardPage > 0) {
          await tapOn(tester, b.smithyBoardPager('back'));
        }
        return '${b.smithyBoardPages} pages [${out.join(' | ')}]';
      }

      // 26 kinds: the Items tab, then the Relics tab.
      final f = b.state = forge.forgeGame();
      forge.giveMats(f, 26);
      await frames(tester, 40);
      final items = <String>[];
      for (var p = 0; p < b.smithyItemPages; p++) {
        if (p > 0) await tapOn(tester, b.smithyItemPager('on'));
        items.add(grid([for (final (_, r) in b.smithyItemCells) r]));
      }
      // ignore: avoid_print
      print('FIT $tag forge items ${b.smithyItemPages} pages [${items.join(' | ')}]; ${mats()}; ${facing()}');
      while (b.smithyItemPage > 0) {
        await tapOn(tester, b.smithyItemPager('back'));
      }
      await shot('items');
      await forge.segment(tester, b, 'tab:relics');
      // ignore: avoid_print
      print('FIT $tag forge relics ${await boardPages()}; ${mats()}; ${facing()}');
      await shot('relics');

      // After wave 30: the Enhance tab, every item in the Bag.
      final e = b.state = enhance.enhanceGame();
      e.inventory.addAll({for (final i in Item.values) i: 1});
      forge.giveMats(e, 26);
      await frames(tester, 40);
      await forge.segment(tester, b, 'tab:enhance');
      // ignore: avoid_print
      print('FIT $tag forge enhance ${await boardPages()}; ${mats()}; ${facing()}');
      await shot('enhance');
      await frames(tester, 40);
    });
  }
}
