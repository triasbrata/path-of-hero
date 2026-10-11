// The book's sprite kit seen (ui-hud.md "Sprite kit"): offscreen shots of the owner's wave-89 save (the fixture) into
// <probe root>/shots/book-kit/ (`OUT`). A probe, not part of the suite (no `_test.dart`): queue
// `["test", "test/probe_book_kit_shots.dart"]` with a mirror as `dir`, once on main and once on the branch, `OUT` set to
// two folders, and hold the two side by side. It never touches the real save (flutter_test_config.dart's temp dir),
// and wins no wave.
//
// It writes, at 1266x713 and 412x860 (`desk-` / `phone-`; the Toko's toko and toko-shelf went with it in decisions-log
// 296): tas-item (a sword picked: the heading's
// count), tas-pusaka (God's Thunder picked: its stars, the rows' Pusaka badges and the list's scroll bar), tas-none
// (nothing picked: blank), troops (the Pasukan rows' Pusaka badges) and licences (the Licences page's scroll
// bars); then kit.png, the slots' looks and the Pusaka cells (`--dart-define=NO_KIT=true` leaves it out: on main, which
// has no kit, delete that part first).
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
import 'probe_root.dart';

const out = String.fromEnvironment('OUT', defaultValue: '$probeRoot/shots/book-kit');

Future<void> frames(WidgetTester tester, [int n = 2]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

Game load() => Game.fromJson(jsonDecode(File('test/fixtures/save-20261002-2222-w89-sellbug.json').readAsStringSync()) as Map<String, dynamic>)
    .boardRules()
  ..chests.clear();

void main() {
  testWidgets('book kit shots', (tester) async {
    tester.view
      ..physicalSize = const Size(1266, 713)
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
      ..miniMapOpen = false;

    Future<void> shot(String name, [int settle = 20]) async {
      await frames(tester, settle);
      final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final img = (await tester.runAsync(() => boundary.toImage()))!;
      await tester.runAsync(() async {
        final png = await img.toByteData(format: ui.ImageByteFormat.png);
        File('$out/$name.png')
          ..parent.createSync(recursive: true)
          ..writeAsBytesSync(png!.buffer.asUint8List());
      });
      // ignore: avoid_print
      print('wrote $out/$name.png ${img.width}x${img.height}; list ${b.assignList}');
    }

    Future<void> tap(Offset p) async {
      await tester.tapAt(p);
      await frames(tester);
    }

    Future<void> page(String name) async {
      if (b.messageBox != Rect.zero) await tap(b.messageBox.center);
      await tap(b.bookTabs.firstWhere((t) => t.$1 == name).$2.center);
    }

    for (final (tag, size) in const [('desk', Size(1266, 713)), ('phone', Size(412, 860))]) {
      tester.view.physicalSize = size;
      b.state = load();
      await frames(tester, 50);
      await page('bag');
      await tap(b.bagSlot(Item.sword).center);
      await shot('$tag-tas-item');
      await tap(b.bagSlot(Item.sword).center);
      await tap(b.bagSlot(Relic.godThunder).center);
      await shot('$tag-tas-pusaka');
      await tap(b.bagSlot(Relic.godThunder).center);
      await shot('$tag-tas-none');

      await page('troops');
      await shot('$tag-troops');

      await page('settings');
      await tap(b.licenceButton.center);
      await shot('$tag-licences');
      await tap(b.licenceBack.center);
      b.state = Game();
      await frames(tester, 5);
    }
    await frames(tester, 10);
    if (const bool.fromEnvironment('NO_KIT')) return; // main has no kit: its run shoots the book alone

    // The kit itself (kit.png): each slot colour's three looks at k = 2, then each Pusaka rarity's tan cell at k = 3,
    // its rim and lip recoloured (the design) beside its rim alone (outline, face and lip kept), normal, lit, pressed.
    final rec = ui.PictureRecorder(), c = Canvas(rec), sheet = game.images.fromCache('ui_all.png');
    c.drawRect(const Rect.fromLTWH(0, 0, 820, 660), Paint()..color = const Color(0xFFF6CA9F)); // the book's paper
    const looks = [ButtonLook.normal, ButtonLook.hover, ButtonLook.pressed];
    for (var row = 0; row < slotRows; row++) {
      for (final (i, look) in looks.indexed) {
        b.drawSlot(c, Rect.fromLTWH(10 + i * 64.0, 10 + row * 70.0, 56, 62), row, look, 2);
      }
    }
    const rims = {Rarity.langka: (0xFF8CC878, 0xFF4E8C46), Rarity.epik: (0xFFB98CF0, 0xFF7E50C8), Rarity.legenda: (0xFFF2C23C, 0xFFC8821E)};
    const outline = Color(0xFF3F2832), rim = Color(0xFFEAD4AA), face = Color(0xFFE4A672), lip = Color(0xFFB86F50);
    for (final (n, MapEntry(key: rarity, value: (toRim, _))) in rims.entries.indexed) {
      final rimOnly = Paint()
        ..filterQuality = FilterQuality.none
        ..colorFilter = ColorFilter.matrix(recolourMatrix([(outline, outline), (face, face), (rim, Color(toRim)), (lip, lip)]));
      for (final (i, look) in looks.indexed) {
        final top = 10 + n * 110.0;
        b.drawSlot(c, Rect.fromLTWH(220 + i * 90.0, top, 84, 93), slotTan, look, 3, rarity: rarity);
        final src = slotSrc(slotTan, look);
        c.drawImageRect(sheet, src, Rect.fromLTWH(500 + i * 90.0, top + (look == ButtonLook.pressed ? 9 : 0), 84, src.height * 3), rimOnly);
      }
    }
    for (final (i, look) in looks.indexed) {
      b.drawSlot(c, Rect.fromLTWH(220 + i * 90.0, 340, 84, 93), slotTan, look, 3); // the plain tan, for the eye
      b.drawSlot(c, Rect.fromLTWH(220 + i * 90.0, 450, 84, 93), slotOrange, look, 3); // the pick beside a Legenda's
    }
    b.drawSlot(c, const Rect.fromLTWH(220, 560, 36, 40), slotTan, ButtonLook.normal, 1, rarity: Rarity.legenda); // a phone cell
    b.drawSlot(c, const Rect.fromLTWH(262, 560, 36, 40), slotOrange, ButtonLook.normal, 1);
    b.drawSlot(c, const Rect.fromLTWH(304, 560, 44, 50), slotTan, ButtonLook.normal, 2, rarity: Rarity.epik); // a desk cell
    b.drawSlot(c, const Rect.fromLTWH(354, 560, 44, 50), slotWhite, ButtonLook.normal, 2);
    final img = (await tester.runAsync(() => rec.endRecording().toImage(820, 660)))!;
    await tester.runAsync(() async {
      final png = await img.toByteData(format: ui.ImageByteFormat.png);
      File('$out/kit.png').writeAsBytesSync(png!.buffer.asUint8List());
    });
    // ignore: avoid_print
    print('wrote $out/kit.png');
  });
}
