// The Tavern boosts' lengths on screen (decisions-log 331; ui-hud.md "The Tavern" and "The Tavern in battle"): offscreen
// shots into <probe root>/shots/tavern-length/ (`OUT`). A probe, not part of the suite (no `_test.dart`): queue
// `["test", "test/probe_tavern_length_shots.dart"]` with the worktree as `dir`. It never touches the real save
// (flutter_test_config.dart's temp dir); the dice are seeded.
//
// First map-town_mark.png (the Town chip's hammer, the whole 32x32 file, at x4: what a boost until the next Town shows
// on its chip). Then at 1600x947 and 915x412 (<size>), the Town after wave 20 with lengths of 4 waves and until the
// next Town: offers-<size> (the rows' lengths, the first until-Town offer picked), bought-<size> (it and a 4-wave one
// bought: "Town" and "4" under Active), field-<size> (back on the field: the chips, the until-Town one's hammer) and
// tip-<size> (its tooltip with the Town marked).
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flame/game.dart' hide Game;
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';
import 'package:tower_defense/hud_font.dart';
import 'package:tower_defense/main.dart';

import 'hud_font.dart';
import 'probe_root.dart';

const out = String.fromEnvironment('OUT', defaultValue: '$probeRoot/shots/tavern-length');
const seed = int.fromEnvironment('SEED', defaultValue: 7);

Future<void> frames(WidgetTester tester, [int n = 2]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

/// A board game gone into the Town after wave 20, seeded, its offers 4 waves or until the next Town, a mixed army and
/// gold to spare.
Game board() {
  final g = Game(Random(seed), Random(seed + 100)).boardRules()
    ..seedDice(seed)
    ..townRules = TownRules.patch({
      'tavern': {
        'lengths': {'2': 0.0, '3': 0.0, '4': 0.4, 'town': 0.6},
      },
    })
    ..armyMax = null
    ..wave = 20;
  for (final type in ['knight', 'knight', 'archer', 'priest', 'wizard', 'soldier', 'lancer']) {
    g.autoPlace(type);
  }
  for (final u in g.troops) {
    u
      ..pos = u.post
      ..arriving = false;
  }
  g
    ..gold = 40000
    ..townAt = 21;
  expect(g.enterTown(), isTrue);
  return g;
}

void main() {
  testWidgets('map', (tester) async {
    await tester.runAsync(loadHudFontNow);
    final game = TdGame();
    await tester.pumpWidget(GameWidget(game: game));
    for (var i = 0; i < 3000 && !game.isLoaded; i++) {
      await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 20)));
      await tester.pump();
    }
    final img = game.images.fromCache('town_mark.png');
    const k = 4.0;
    final rec = ui.PictureRecorder(), c = Canvas(rec), w = img.width * k + 16, h = img.height * k + 40;
    c.drawRect(Rect.fromLTWH(0, 0, w, h), Paint()..color = const Color(0xFF4F4A45));
    final to = Rect.fromLTWH(8, 8, img.width * k, img.height * k);
    c.drawRect(to, Paint()..color = const Color(0xFFC8BCA0));
    c.drawImageRect(img, Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()), to, Paint()..filterQuality = FilterQuality.none);
    c.drawRect(to, Paint()
      ..style = PaintingStyle.stroke
      ..color = const Color(0xFFE0402A));
    TextPainter(text: TextSpan(text: '0 hammer 0,0 ${img.width}x${img.height}', style: hudStyle(11, color: Colors.white)), textDirection: TextDirection.ltr)
      ..layout(maxWidth: w - 8)
      ..paint(c, Offset(8, to.bottom + 4));
    final pic = rec.endRecording();
    await tester.runAsync(() async {
      final shot = await pic.toImage(w.round(), h.round());
      final png = await shot.toByteData(format: ui.ImageByteFormat.png);
      File('$out/map-town_mark.png')
        ..parent.createSync(recursive: true)
        ..writeAsBytesSync(png!.buffer.asUint8List());
    });
    // ignore: avoid_print
    print('wrote $out/map-town_mark.png: town_mark.png ${img.width}x${img.height}');
  });

  for (final size in const [Size(1600, 947), Size(915, 412)]) {
    final tag = '${size.width.round()}x${size.height.round()}';
    testWidgets('lengths $tag', (tester) async {
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
        ..miniMapOpen = false;
      b.autoStart.set(false);

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
        print('wrote $out/$name-$tag.png page ${b.bookPage} rows ${[
          for (final r in b.tavernRows) '${r.kind.name} ${r.price} "${b.tavernText('row:${r.slot}')}"'
        ]} line "${b.tavernText('line')}" effects ${[for (final e in b.tavernEffects) '${e.what} ${e.value}']} '
            'active ${[for (var i = 0; i < b.state.boosts.length; i++) b.tavernText('active:$i')]} msg ${b.message} '
            'chips ${b.boostChips} tip ${b.tooltipShown}');
      }

      Future<void> tap(Rect r) async {
        expect(r, isNot(Rect.zero));
        await tester.tapAt(r.center);
        await frames(tester, 3);
      }

      Future<void> shut() async {
        if (b.messageBox != Rect.zero) await tap(b.messageBox);
      }

      final g = b.state = board();
      // ignore: avoid_print
      print('offers ${[for (final o in g.tavernOffers) '${o.kind.name} ${o.length} ${g.offerPrice(o)}']}');
      await frames(tester, 40);
      await shut();
      await tap(b.bookTabs.firstWhere((t) => t.$1 == 'tavern').$2);
      final town = g.tavernOffers.indexWhere((o) => o.untilTown), four = g.tavernOffers.indexWhere((o) => !o.untilTown && o.waves == 4);
      if (town >= 0) await tap(b.tavernRows[town].at);
      await shot('offers', 40);
      for (final i in [town, four]) {
        if (i < 0) continue;
        await tap(b.tavernRows[i].at);
        expect(g.buyBoost(i), isTrue); // Buy may sit under the facing page's scroll at 915x412
        await frames(tester, 3);
      }
      await shot('bought');

      // Back on the field: the chips; the until-Town one's tooltip once the next Town is marked.
      expect(g.leaveTown(), isTrue);
      for (var i = 0; i < 120 && b.townShown; i++) {
        await frames(tester);
      }
      g.townAt = 26;
      await shot('field', 30);
      final at = g.boosts.indexWhere((x) => x.untilTown);
      if (at >= 0) {
        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        await mouse.addPointer(location: Offset.zero);
        addTearDown(mouse.removePointer);
        await mouse.moveTo(b.boostChips[at].center);
        await shot('tip', 30);
      }
    });
  }
}
