// The Towns switched on (decisions-log 237): offscreen shots into <probe root>/shots/town-T7/ (`OUT`). A probe, not
// part of the suite (no `_test.dart`): queue `["test", "test/probe_town_t7_shots.dart"]` with the worktree (or a
// `git archive` mirror) as `dir` (`--plain-name <size>` for one size). It never touches the real save
// (flutter_test_config.dart's temp dir); the dice are seeded.
//
// At 1266x713, 1164x777, 915x412 and 412x860 (<size>): welcome-old-<size> (the launch over a save from before the Towns:
// no "Continue", the file gone), k23-<size> (the first Town's card), k24-<size> (the first material's card),
// recall-<size> (the Army detail's Recall tag, a fallen Hero and a full army), smithy-grid-<size> (the Smithy's
// page; its close-up of 2-digit counts on the small material cells went with that grid, decisions-log 302), lancer-talk-<size> and its close-up lancer-zoom-<size>
// (the bubble over its helmet), town30-<size> (30 troops in the Town: on a phone a few at a place, the rest off-view).
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flame/game.dart' hide Game;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';
import 'package:tower_defense/main.dart';
import 'package:tower_defense/save.dart';

import 'hud_font.dart';
import 'town_hud_test.dart' show frames, townGame;
import 'town_life_test.dart' show ScriptDice, troop;
import 'town_scene_test.dart' show intoTown, settle;
import 'town_smithy_ui_test.dart' show smithyGame;
import 'town_switch_test.dart' show cardShown, closeCard, seenBut;
import 'probe_root.dart';

const out = String.fromEnvironment('OUT', defaultValue: '$probeRoot/shots/town-T7');

/// The owner's w89 save: from before the Towns (no `v`).
const _old = 'test/fixtures/save-20261002-2222-w89-sellbug.json';

void main() {
  for (final size in const [Size(1266, 713), Size(1164, 777), Size(915, 412), Size(412, 860)]) {
    final tag = '${size.width.round()}x${size.height.round()}';
    testWidgets('town T7 shots $tag', (tester) async {
      tester.view
        ..physicalSize = size
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      addTearDown(clearSave);
      await tester.runAsync(loadHudFontNow);
      final save = dataFile('save.json')
        ..createSync(recursive: true)
        ..writeAsStringSync(File(_old).readAsStringSync());
      final game = TdGame();
      final key = GlobalKey();
      await tester.pumpWidget(RepaintBoundary(key: key, child: GameWidget(game: game)));
      for (var i = 0; i < 3000 && !game.isLoaded; i++) {
        await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 20)));
        await tester.pump();
      }
      expect(game.isLoaded, isTrue);
      final b = game.board..miniMapOpen = false;

      Future<ui.Image> grab() async {
        final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        return (await tester.runAsync(() => boundary.toImage()))!;
      }

      Future<void> write(ui.Image img, String name) => tester.runAsync(() async {
            final png = await img.toByteData(format: ui.ImageByteFormat.png);
            File('$out/$name-$tag.png')
              ..parent.createSync(recursive: true)
              ..writeAsBytesSync(png!.buffer.asUint8List());
          });

      Future<ui.Image> shot(String name, [int settle = 20]) async {
        await frames(tester, settle);
        final img = await grab();
        await write(img, name);
        // ignore: avoid_print
        print('wrote $out/$name-$tag.png  page ${b.bookPage} card ${b.coachCard?.$1} town ${b.townShown} '
            'wave ${b.state.wave} msg ${b.message}');
        return img;
      }

      /// [r] of [img], [k] times, pixel for pixel, as <name>-<size>.png.
      Future<void> zoom(ui.Image img, Rect r, String name, int k) async {
        final at = r.intersect(Offset.zero & size);
        final rec = ui.PictureRecorder();
        Canvas(rec).drawImageRect(img, at, Rect.fromLTWH(0, 0, at.width * k, at.height * k), Paint()..filterQuality = FilterQuality.none);
        final big = (await tester.runAsync(() => rec.endRecording().toImage((at.width * k).round(), (at.height * k).round())))!;
        await write(big, name);
        // ignore: avoid_print
        print('wrote $out/$name-$tag.png  $at x$k');
      }

      Future<void> openPage(String page) async {
        if (b.bookPage == page) return;
        await tester.tapAt(b.bookTabs.firstWhere((t) => t.$1 == page).$2.center);
        await frames(tester, 3);
      }

      // The launch over a pre-Towns save: no "Continue", the file deleted.
      await frames(tester, 3);
      // ignore: avoid_print
      print('welcome: saved ${b.welcome?.saved?.wave} buttons ${b.welcomeButtons.keys.toList()} file ${save.existsSync()}');
      await shot('welcome-old', 6);
      b
        ..welcome = null
        ..autoStart.set(false);

      // K23: the first Town's card.
      b.guideSeen = seenBut({'K23'});
      await intoTown(tester, b);
      // ignore: avoid_print
      print('K23 card: ${await cardShown(tester, b)}');
      await shot('k23', 30);
      await closeCard(tester, b);

      // K24: after the first wave that drops a material.
      b.guideSeen = seenBut({'K24'});
      final g24 = b.state = townGame()..wave = 1;
      g24
        ..startWave()
        ..queue.clear()
        ..units.add(g24.monster('slime', Tier.normal, const Point(300, 60))..gone = true);
      await frames(tester, 3);
      g24.materials[Mat.slimeGel] = 1;
      // ignore: avoid_print
      print('K24 card: ${await cardShown(tester, b, 400)}');
      await shot('k24', 30);
      await closeCard(tester, b);
      b.guideSeen = seenBut({});

      // The Recall tag: a fallen Hero, a full army (so the tag can swap a knight), gold to spare.
      final gr = b.state = smithyGame()
        ..inTown = false
        ..townAt = null
        ..wave = 20
        ..gold = 1000000;
      gr.fallenHeroes.add(FallenHero(name: 'Hero 1', type: 'knight', stats: const [HeroStat.hp, HeroStat.power], fell: 19));
      gr.capacity = gr.armySize;
      await frames(tester, 40);
      await openPage('troops');
      await tester.tapAt(b.troopRow('knight').center);
      await frames(tester, 3);
      for (var i = 0; i < 40 && b.troopDetail('recall:0') == Rect.zero; i++) {
        b.troopDetailScroll += 30;
        await frames(tester, 2);
      }
      // ignore: avoid_print
      print('recall words: ${b.troopDetailWords('recall')}');
      final recall = await shot('recall');
      final tagAt = b.troopDetail('recall:0');
      if (tagAt != Rect.zero) await zoom(recall, tagAt.inflate(40), 'recall-zoom', 3);

      // The Smithy's grid with 2-digit counts.
      final gs = b.state = smithyGame();
      for (final m in Mat.values) {
        gs.materials[m] = 12 + m.index;
      }
      await frames(tester, 40);
      if (b.messageBox != Rect.zero) {
        await tester.tapAt(b.messageBox.center);
        await frames(tester, 3);
      }
      await shot('smithy-grid'); // (its materials' grid went, decisions-log 302: the zoom on it with it)

      // A lancer talking (the scripted dice of town_switch_test.dart), the Bag open so a phone shows the Tavern.
      final dice = ScriptDice();
      b.townDice = dice;
      final gl = await intoTown(tester, b);
      await settle(tester, b);
      await openPage('bag');
      await settle(tester, b);
      final x = b.townLife.width / 2;
      double draw(double world) => (world - townEdge) / (b.townLife.width - 2 * townEdge);
      dice.queue.addAll([
        0, 0, 0, 0,
        draw(x), 0.1, TownLife.drawFor(TownDo.stroll), draw(x + 4),
        draw(x + 30), 0.9, TownLife.drawFor(TownDo.talk), 0.9,
        0.99,
      ]);
      final lancer = troop('lancer');
      gl.units
        ..removeWhere((u) => u.side == Side.troop)
        ..addAll([troop('knight'), lancer]);
      Rect? said;
      Offset? feet;
      for (var i = 0; i < 600 && said == null; i++) {
        await frames(tester, 1);
        for (final f in b.townFolk) {
          if (f.unit == lancer && f.bubble != Rect.zero) (said, feet) = (f.bubble, f.feet);
        }
      }
      // ignore: avoid_print
      print('lancer bubble $said feet $feet');
      final talk = await shot('lancer-talk', 1);
      if (said != null) {
        await zoom(talk, Rect.fromLTRB(said.left - 40, said.top - 20, said.right + 40, feet!.dy + 10), 'lancer-zoom', 3);
      }

      // 30 troops in the Town.
      final g30 = b.state = townGame()
        ..capacity = 30
        ..gold = 1 << 24
        ..wave = 5
        ..townAt = 7;
      for (var i = 0; g30.troops.length < 30 && i < 200; i++) {
        g30.autoPlace(troopTypes.keys.elementAt(i % troopTypes.length));
      }
      b.townDice = Random(9);
      await frames(tester, 10);
      await openPage('troops'); // on a phone a wave pauses with the book off the Army page
      g30
        ..startWave()
        ..queue.clear()
        ..units.add(g30.monster('slime', Tier.normal, const Point(300, 60))..gone = true);
      for (var i = 0; i < 600 && !g30.inTown; i++) {
        await frames(tester, 1);
      }
      await settle(tester, b);
      await frames(tester, 600); // ~10 s of errands
      // ignore: avoid_print
      print('town30: ${g30.troops.length} troops');
      await shot('town30', 1);
    });
  }
}
