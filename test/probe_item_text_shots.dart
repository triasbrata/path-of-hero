// The item text seen (decisions-log 168, ui-hud.md "In-game text"): offscreen shots into <probe root>/shots/item-text/
// (`OUT`). A probe, not part of the suite (no `_test.dart`): queue `["test", "test/probe_item_text_shots.dart"]` with the
// worktree as `dir` (`--plain-name "item text 412"` for one size). It never touches the real save
// (flutter_test_config.dart's temp dir); the dice are seeded, so a rerun gives the same shots.
//
// From the owner's wave-86 save (the fixture: five types, its five Epik bound by default), with the four Langka, Dragon
// Crown and Alliance given (and in a second game Oath of One, which waits there), at 1266x713 (device pixel ratio 2, a
// Retina Mac) and 412x860 (ratio 3, a phone), shot at the device's own pixels:
// - tip-<loot>-<size>: the tooltip of every Pusaka, small relic and item in the Tas page's bag, cropped round it;
//   tipcell-<item>-<size>: an item cell's on a troop row; badge-<size>: a Pasukan row's Pusaka badge's;
// - tas-gudang-<size>: the Tas page with a Gudang Pusaka picked (its line, Jual and Lebur; Asah on the facing page),
//   lebur-<size>: its Lebur picker open, tas-oath-<size>: Oath of One picked while it waits;
// - chest-<rarity>-<size>: a wave-90 chest of three Epik, three Langka and the three Legenda;
// - hud-<size>: the gold panel (1552505 gold, for its 5s) and the wave meter.
// Every tooltip is checked to lie on the screen, and its lines are printed.
import 'dart:convert';
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

const out = String.fromEnvironment('OUT', defaultValue: '$probeRoot/shots/item-text');
const seed = int.fromEnvironment('SEED', defaultValue: 7);

Future<void> frames(WidgetTester tester, [int n = 2]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

/// The fixture (the owner's w86 save), its catch-up chests cleared, its note seen.
Game load() {
  final save = jsonDecode(File('test/fixtures/save-20261001-2005-pre-awaken.json').readAsStringSync()) as Map<String, dynamic>;
  return Game.fromJson(save, Random(seed), Random(seed + 100), Random(seed + 300))
    ..loot = Random(seed + 200)
    ..draft = Random(seed + 500)
    ..boardRules()
    ..chests.clear()
    ..dismissPusakaNote();
}

void main() {
  for (final (size, ratio) in const [(Size(1266, 713), 2.0), (Size(412, 860), 3.0)]) {
    final tag = '${size.width.round()}';
    testWidgets('item text $tag', (tester) async {
      tester.view
        ..physicalSize = size * ratio
        ..devicePixelRatio = ratio;
      addTearDown(tester.view.reset);
      await loadHudFont(tester);
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

      Future<ui.Image> grab() async {
        final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        return (await tester.runAsync(() => boundary.toImage(pixelRatio: ratio)))!;
      }

      Future<void> save(ui.Image img, String name, [Rect? crop]) async {
        await tester.runAsync(() async {
          var shot = img;
          if (crop != null) {
            final r = crop.inflate(6).intersect(Offset.zero & size);
            final px = Rect.fromLTRB(r.left * ratio, r.top * ratio, r.right * ratio, r.bottom * ratio);
            final rec = ui.PictureRecorder();
            Canvas(rec).drawImageRect(img, px, Offset.zero & px.size, Paint()..filterQuality = FilterQuality.none);
            shot = await rec.endRecording().toImage(px.width.round(), px.height.round());
          }
          final png = await shot.toByteData(format: ui.ImageByteFormat.png);
          File('$out/$name.png')
            ..parent.createSync(recursive: true)
            ..writeAsBytesSync(png!.buffer.asUint8List());
          // ignore: avoid_print
          print('wrote $out/$name.png ${shot.width}x${shot.height}');
        });
      }

      Future<void> shot(String name, [int settle = 20]) async {
        await frames(tester, settle);
        await save(await grab(), name);
      }

      Future<void> tap(Offset p) async {
        await tester.tapAt(p);
        await frames(tester, 2);
      }

      Future<void> closeMessage() async {
        await frames(tester, 150);
        if (b.messageBox != Rect.zero) await tap(b.messageBox.center);
      }

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      Future<void> off() async {
        await mouse.moveTo(const Offset(1, 1));
        await frames(tester, 3);
      }

      /// The tooltip over [at], cropped round it as [name]; its lines printed; it lies on the screen.
      Future<void> tip(Offset at, String name) async {
        await off();
        await mouse.moveTo(at);
        await frames(tester, 30);
        final box = b.tooltipBox;
        expect(box, isNot(Rect.zero), reason: '$name: no tooltip');
        expect((Offset.zero & size).inflate(0.5).contains(box.topLeft) && (Offset.zero & size).inflate(0.5).contains(box.bottomRight),
            isTrue, reason: '$name: $box off the screen $size');
        // ignore: avoid_print
        print('$name ${box.width.round()}x${box.height.round()}: ${b.tooltipShown}');
        await save(await grab(), name, box);
      }

      Future<void> page(String tab) async {
        await off();
        await tap(b.bookTabs.firstWhere((t) => t.$1 == tab).$2.center);
        await frames(tester, 20);
      }

      // The fixture with every Pusaka owned: the four Langka (one bound, the rest in the Gudang at their stars), Dragon
      // Crown in the Gudang, Alliance taken; a Hero alive, so an item's row says its aura.
      final g = b.state = load()
        ..givePusaka(Relic.ironBanner, type: 'knight_templar')
        ..givePusaka(Relic.bloodFang, stars: 2)
        ..givePusaka(Relic.warDrum, stars: 3)
        ..givePusaka(Relic.mourningBell)
        ..givePusaka(Relic.dragonCrown)
        ..givePusaka(Relic.alliance);
      // ignore: avoid_print
      print('w${g.wave}: types ${g.troopCounts.keys}, alive ${g.typesAlive}, hero ${g.heroAlive}, gudang ${g.gudang}');
      await frames(tester, 20);
      // A HUD number with 5s in it: the gold panel and the wave meter.
      final gold = g.gold;
      g.gold = 1552505;
      await frames(tester, 20);
      await save(await grab(), 'hud-$tag', b.goldPanel.expandToInclude(b.waveMeter == Rect.zero ? b.goldPanel : b.waveMeter));
      g.gold = gold;

      await page('bag');
      for (final loot in <Enum>[...Item.values, ...Relic.values.where((r) => !r.pusaka), ...Relic.values.where((r) => r.pusaka && r != Relic.oathOfOne)]) {
        final at = b.bagSlot(loot);
        if (at == Rect.zero) continue;
        await tip(at.center, 'tip-${loot.name}-$tag');
      }
      await off();
      // A Gudang Pusaka picked: the line under the Gudang, Jual and Lebur; its Asah strip on the facing page.
      await tap(b.bagSlot(Relic.bloodFang).center);
      await shot('tas-gudang-$tag');
      await tap(b.leburButton.center);
      await shot('lebur-$tag');
      await tap(b.leburBack.center);
      await tap(b.bagSlot(Relic.bloodFang).center); // put back

      await page('troops');
      final cell = b.itemCells.where((c) => c.$3 == 'knight_templar').firstOrNull ?? b.itemCells.first;
      await tip(cell.$1.center, 'tipcell-${cell.$2.name}-$tag');
      final shield = b.itemCells.where((c) => c.$2 == Item.shield && c.$3 == 'knight_templar').firstOrNull;
      if (shield != null) await tip(shield.$1.center, 'tipcell-shield-$tag');
      await tip(b.pusakaBadge('knight_templar').center, 'badge-$tag');

      // Wave-90 chests: three Epik, three Langka (stars on the ones owned), the three Legenda (a fresh game, so they are new).
      await off();
      for (final (name, cards, game) in [
        ('epik', [Relic.dragonHeart, Relic.dawnStar, Relic.voidEye], g),
        ('langka', [Relic.ironBanner, Relic.bloodFang, Relic.warDrum], g),
        ('legenda', [Relic.dragonCrown, Relic.oathOfOne, Relic.alliance], load()),
      ]) {
        b.state = game..wave = 90;
        game.chests
          ..clear()
          ..add(Chest(ChestKind.boss, 90, cards: cards));
        await frames(tester, 3);
        await tap(const Offset(2, 2));
        await shot('chest-$name-$tag', 30);
        game.chests.clear();
        await frames(tester, 5);
      }

      // Oath of One taken in the fixture (five types: it waits): its tooltip, and the Tas page with it picked.
      final o = b.state = load()..givePusaka(Relic.oathOfOne);
      await frames(tester, 20);
      await closeMessage();
      await page('bag');
      await tip(b.bagSlot(Relic.oathOfOne).center, 'tip-oathOfOne-$tag');
      await off();
      await tap(b.bagSlot(Relic.oathOfOne).center);
      await shot('tas-oath-$tag');
      // ignore: avoid_print
      print('oath of one: waits ${o.oathWaits}, where "${o.pusakaWhere(Relic.oathOfOne)}"');
      await mouse.removePointer();
    });
  }
}
