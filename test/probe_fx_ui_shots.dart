// The screen's looks cut from the packs' sheets (ui-hud.md): offscreen shots of the owner's wave-89 save (the fixture)
// into <probe root>/shots/pack-looks/ui (`OUT`). A probe, not part of the suite (no `_test.dart`): queue
// `["test", "test/probe_fx_ui_shots.dart"]` with the worktree as `dir`. It never touches the real save
// (flutter_test_config.dart's temp dir), and wins no wave. The dice are seeded and every frame is 16 ms, so main and a
// branch give the same moments.
//
// It writes, at 1266x713 and 412x860 (`desk-` / `phone-`): tas (a sword picked on the Tas page: its rows' "now ▸
// after"), locked (the Pasukan page with the roster full: the locked rows' padlocks); then with a wave on, win and
// win-later 0.1 s on (the "MENANG!" popup's sparks, a dropped relic's glint beside a dropped item), cut-early and cut
// (a Hero's cut-in band 0.2 s in, its portrait's burst, and after its slide, with the Grail's plate), splash-early and
// splash (the Hero splash 0.25 s in and later, its ring on the field under the dim).
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flame/game.dart' hide Game;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';
import 'package:tower_defense/main.dart';

import 'hud_font.dart';
import 'probe_root.dart';

const out = String.fromEnvironment('OUT', defaultValue: '$probeRoot/shots/pack-looks/ui');

Future<void> frames(WidgetTester tester, [int n = 2]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

/// The fixture, its dice seeded (so a branch's shots and main's show the same moments).
Game load() => Game.fromJson(jsonDecode(File('test/fixtures/save-20261002-2222-w89-sellbug.json').readAsStringSync()) as Map<String, dynamic>,
        Random(7), Random(107), Random(307))
    .boardRules()
  ..chests.clear()
  ..loot = Random(207);

void main() {
  testWidgets('fx ui shots', (tester) async {
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

    Future<void> shot(String name) async {
      final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final img = (await tester.runAsync(() => boundary.toImage()))!;
      await tester.runAsync(() async {
        final png = await img.toByteData(format: ui.ImageByteFormat.png);
        File('$out/$name.png')
          ..parent.createSync(recursive: true)
          ..writeAsBytesSync(png!.buffer.asUint8List());
      });
      // ignore: avoid_print
      print('wrote $out/$name.png ${img.width}x${img.height}; grail ${b.grailCutIn}');
    }

    Future<void> tap(Offset p) async {
      await tester.tapAt(p);
      await frames(tester);
    }

    for (final (tag, size) in const [('desk', Size(1266, 713)), ('phone', Size(412, 860))]) {
      tester.view.physicalSize = size;
      final g = b.state = load();
      await frames(tester, 50);
      b.showMessage('', time: 0);
      final hero = g.troops.where((u) => u.alive && u.hero && u.heroSkill != null).first;

      // The Tas page (the book is open between waves), a sword picked: its rows' "now ▸ after".
      if (b.messageBox != Rect.zero) await tap(b.messageBox.center);
      await tap(b.bookTabs.firstWhere((t) => t.$1 == 'bag').$2.center);
      await tap(b.bagSlot(Item.sword).center);
      await frames(tester, 20);
      await shot('$tag-tas');

      // The Army page with every type full (each cap at its count alive, the save's Alliance oath set aside): every row's
      // count red, the forbidden sign where its price goes (decisions-log 201).
      final caps = g.typeCap, pusaka = {...g.pusaka};
      g.pusaka.remove(Relic.alliance);
      g.typeCap = {for (final t in troopTypes.keys) t: g.troopCounts[t] ?? 0};
      await tap(b.bookTabs.firstWhere((t) => t.$1 == 'troops').$2.center);
      await frames(tester, 20);
      await shot('$tag-locked');
      g.typeCap = caps;
      g.pusaka
        ..clear()
        ..addAll(pusaka); // in its order

      // A wave on: the book shuts, the field shows.
      g.startWave();
      await frames(tester, 40);

      // The win's popup, with a relic and an item dropped on the field in view.
      final drop = Point(g.cam + g.viewW * 0.72, 22.0);
      g.relicDrops.add((drop, Relic.fang));
      g.drops.add((drop + const Point(16.0, 0), Item.sword));
      g.victoryAt = g.t - 0.9;
      await frames(tester, 2);
      await shot('$tag-win');
      await frames(tester, 6); // 0.1 s on: the sparks and the glint a step further
      await shot('$tag-win-later');
      g
        ..victoryAt = double.negativeInfinity
        ..relicDrops.clear()
        ..drops.clear();
      await frames(tester, 4);

      // A Hero's cut-in, and the Grail's plate with it.
      g
        ..heroCasts.add((hero, hero.heroSkill!))
        ..grailFirst = hero;
      await frames(tester, 12);
      await shot('$tag-cut-early');
      await frames(tester, 16);
      await shot('$tag-cut');
      await frames(tester, 120); // both over

      // The Hero splash, its Hero moved into view at the field's left (its ring shows beside the panel).
      hero.pos = Point(g.cam + g.viewW * 0.12, 70.0);
      g.heroMade.add(hero);
      await frames(tester, 16);
      await shot('$tag-splash-early');
      await frames(tester, 50);
      await shot('$tag-splash');
      await tap(Offset(size.width / 2, size.height / 2)); // closes it
      await frames(tester, 40); // past the taps' timers
      b.state = Game();
      await frames(tester, 5);
    }
  });
}
