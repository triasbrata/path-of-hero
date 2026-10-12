// The Army in a Town (decisions-log 301; ui-hud.md "Town"): offscreen shots into <probe root>/shots/town-army-tab/
// (`OUT`). A probe, not part of the suite (no `_test.dart`): queue `["test", "test/probe_town_army_shots.dart"]` with
// the worktree or a mirror as `dir` (`--dart-define=SIZES=915x412` for some sizes only). It never touches the real save
// (flutter_test_config.dart's temp dir); every dice is seeded.
//
// At 1600x947, 1266x713, 1164x777 and 915x412 (<size>), a board game after wave 20 in its Town (the Towns and the forge
// on, four types):
// - army-smithy-<size>: the book on the Smithy, its six tabs;
// - army-tab-<size>: the Army's tab tapped: the grid and the archer's detail, the view on the tent;
// - army-shut-<size>: the book shut, the view at the Town's left end (the tent);
// - army-tent-<size>: the tent tapped: the book on the Army;
// - army-field-<size>: the field after Leave, the book on the Army (its three tabs);
// - army-tabs-<size>: the Town's tab strip (on the Smithy) zoomed 3x, each shut tab's press area outlined (red; drawn
//   on the shot only, for the reader).
// It prints each shot's page, the tabs and their press areas, and the HUD's band.
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flame/game.dart' hide Game;
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';
import 'package:tower_defense/main.dart';

import 'hud_font.dart';
import 'probe_root.dart';

const out = String.fromEnvironment('OUT', defaultValue: '$probeRoot/shots/town-army-tab');
const only = String.fromEnvironment('SIZES');

Future<void> frames(WidgetTester tester, [int n = 2]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

String r0(Rect r) => '(${r.left.round()},${r.top.round()} ${r.width.round()}x${r.height.round()})';

void main() {
  final sizes = [
    for (final s in const [Size(1600, 947), Size(1266, 713), Size(1164, 777), Size(915, 412)])
      if (only.isEmpty || only.split(',').contains('${s.width.round()}x${s.height.round()}')) s,
  ];
  for (final size in sizes) {
    final name = '${size.width.round()}x${size.height.round()}';
    testWidgets('town army shots $name', (tester) async {
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
      b.autoStart.set(false);

      Future<ui.Image> grab() async {
        final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        return (await tester.runAsync(() => boundary.toImage()))!;
      }

      Future<void> save(ui.Image img, String file) async {
        await tester.runAsync(() async {
          final png = await img.toByteData(format: ui.ImageByteFormat.png);
          File('$out/army-$file-$name.png')
            ..parent.createSync(recursive: true)
            ..writeAsBytesSync(png!.buffer.asUint8List());
        });
      }

      Future<void> shot(String file) async {
        await save(await grab(), file);
        // ignore: avoid_print
        print('wrote army-$file-$name.png: page ${b.bookPage}, book ${r0(b.bookArea)}, cam ${b.townCam.toStringAsFixed(1)}\n'
            '  tabs ${[for (final (t, r) in b.bookTabs) '$t ${r0(r)}']}\n'
            '  taps ${[for (final (t, r) in b.bookTabTaps) '$t ${r0(r)}']}\n'
            '  pages ${r0(b.bookPages.$1)} ${r0(b.bookPages.$2)}\n'
            '  hud toggle ${r0(b.toggleButton)} meter ${r0(b.waveMeter)} x2 ${r0(b.speedButton)} auto ${r0(b.autoButton)} '
            'counter ${r0(b.troopCounter)} chip ${r0(b.townChip)} boosts ${b.boostChips.map(r0).toList()}');
      }

      // The tab strip zoomed 3x, each shut tab's press area outlined.
      Future<void> zoom(String file) async {
        final img = await grab();
        final all = [for (final (_, r) in b.bookTabs) r, for (final (_, r) in b.bookTabTaps) r];
        final box = all.reduce((a, c) => a.expandToInclude(c)).inflate(12).intersect(Offset.zero & size);
        const k = 3.0;
        final rec = ui.PictureRecorder(), c = Canvas(rec);
        c.drawImageRect(img, box, Offset.zero & (box.size * k), Paint()..filterQuality = FilterQuality.none);
        final line = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = const Color(0xFFFF0000);
        for (final (_, r) in b.bookTabTaps) {
          final s = r.shift(-box.topLeft);
          c.drawRect(Rect.fromLTRB(s.left * k, s.top * k, s.right * k, s.bottom * k).deflate(0.5), line);
        }
        final pic = rec.endRecording();
        final zoomed = await tester.runAsync(() => pic.toImage((box.width * k).ceil(), (box.height * k).ceil()));
        await save(zoomed!, file);
      }

      Future<void> tab(String page) async {
        await tester.tapAt(b.bookTabTaps.firstWhere((x) => x.$1 == page).$2.center);
        await frames(tester, 40);
      }

      // A board game after wave 20 in its Town: a soldier, a knight, an archer and a priest.
      final g = Game(Random(1), Random(2)).boardRules()
        ..townDice = Random(3)
        ..armyMax = null
        ..wave = 20
        ..gold = 40000;
      for (final type in ['soldier', 'knight', 'archer', 'priest']) {
        g.autoPlace(type);
      }
      for (final u in g.troops) {
        u
          ..pos = u.post
          ..arriving = false;
      }
      g
        ..townAt = 21
        ..inTown = true;
      b.state = g;
      await frames(tester, 60);
      await shot('smithy');
      await zoom('tabs');
      await tab('troops');
      await tester.tapAt(b.troopRow('archer').center);
      await frames(tester, 30);
      await shot('tab');
      // Shut (a tap on the sky left of the book, under the HUD's band), the view to the left end.
      await tester.tapAt(Offset(8, b.waveMeter.bottom + 40));
      await frames(tester, 40);
      final mouse = TestPointer(9, PointerDeviceKind.mouse);
      await tester.sendEventToBinding(mouse.hover(Offset(size.width / 2, b.waveMeter.bottom + 40)));
      await tester.sendEventToBinding(mouse.scroll(const Offset(0, -3000)));
      await frames(tester, 40);
      await shot('shut');
      final tent = b.townScene['tent']!;
      await tester.tapAt(Offset(tent.center.dx, tent.bottom - tent.height / 4));
      await frames(tester, 40);
      await shot('tent');
      g.leaveTown();
      await frames(tester, 80);
      await shot('field');
      b.state = Game();
      await frames(tester, 5);
    });
  }
}
