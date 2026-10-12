// The Tavern in battle (decisions-log 268; ui-hud.md "The Tavern in battle"; lib/tavern_look.dart): offscreen shots into
// <probe root>/shots/tavern-hud/ (`OUT`). A probe, not part of the suite (no `_test.dart`): queue
// `["test", "test/probe_tavern_hud_shots.dart"]` with the worktree as `dir` (`--plain-name <size>` for one size). It never
// touches the real save (flutter_test_config.dart's temp dir); the dice are seeded.
//
// At 1266x713, 1164x777, 915x412 and 412x860 (<size>): k23-<size> (the first Town's card with its Tavern line),
// tab-<size> (its book on the Smithy, the Tavern tab's dot), bursts-<size> (the field back from the Town after the
// Feast was bought: the troops' upgrade bursts), log-<size> (the battle log open on "Other" … its Tavern line with the
// Feast's mug), chips-<size> (a Town marked and three boosts running: the chips under the Town chip), tip-<size> (the
// Feast chip's tooltip), six-<size> (six boosts: the chips in rows).
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flame/game.dart' hide Game;
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';
import 'package:tower_defense/main.dart';

import 'hud_font.dart';
import 'tavern_hud_test.dart' show fieldGame;
import 'town_scene_test.dart' show intoTown, settle;
import 'town_switch_test.dart' show cardShown, closeCard, seenBut;
import 'probe_root.dart';

const out = String.fromEnvironment('OUT', defaultValue: '$probeRoot/shots/tavern-hud');

Future<void> frames(WidgetTester tester, [int n = 2]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

void main() {
  for (final size in const [Size(1266, 713), Size(1164, 777), Size(915, 412), Size(412, 860)]) {
    final tag = '${size.width.round()}x${size.height.round()}';
    testWidgets('tavern hud $tag', (tester) async {
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
        print('wrote $out/$name-$tag.png  page ${b.bookPage} card ${b.coachCard?.$1} town ${b.townShown} chips '
            '${b.boostChips} meter ${b.waveMeter} townChip ${b.townChip} bursts ${b.fieldBursts.where((x) => x.$2 == 'upgrade').length} '
            'tip ${b.tooltipShown} log ${b.logPanel} dot ${b.storeAt('tavernDot')}');
      }

      // The first Town's card, then its book (the Tavern tab's dot).
      b.guideSeen = seenBut({'K23'});
      final g = await intoTown(tester, b);
      // ignore: avoid_print
      print('K23 card: ${await cardShown(tester, b)}');
      await shot('k23', 30);
      await closeCard(tester, b);
      await settle(tester, b);
      await shot('tab');

      // The Feast bought, the Town left: the troops burst as the field comes back.
      expect(g.buyBoost(g.tavernOffers.indexWhere((o) => o.kind == Boost.feast)), isTrue);
      expect(g.leaveTown(), isTrue);
      for (var i = 0; i < 120 && b.townShown; i++) {
        await frames(tester, 1);
      }
      await shot('bursts', 4);
      await tester.tapAt(b.logButton.center);
      await shot('log', 10);
      await tester.tapAt(b.logButton.center);
      await frames(tester, 3);

      // A Town marked and three boosts running: the chips under the Town chip; the Feast's tooltip.
      b.state = fieldGame()
        ..boosts.addAll([RunningBoost(Boost.feast, 2), RunningBoost(Boost.plate, 1, type: 'knight'), RunningBoost(Boost.toast, 2)]);
      await shot('chips', 30);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(b.boostChips.first.center);
      await shot('tip', 40);
      await mouse.moveTo(Offset.zero);
      await mouse.removePointer();

      // Six running: in rows.
      b.state = fieldGame(marked: false)
        ..boosts.addAll([for (final k in [Boost.feast, Boost.ale, Boost.stew, Boost.broth, Boost.tea, Boost.banquet]) RunningBoost(k, 2)]);
      await shot('six', 30);
    });
  }
}
