// The Army page seen (ui-hud.md "Army", decisions-log 187): offscreen shots into <probe root>/shots/troops-t1/
// (`OUT`). A probe, not part of the suite (no `_test.dart`): queue `["test", "test/probe_troops_shots.dart"]` with a mirror
// as `dir`. It never touches the real save (flutter_test_config.dart's temp dir), and wins no wave.
//
// It writes, at 1266x713, 412x860 and 915x412 (`desk-` / `phone-` / `wide-`), on the owner's wave-89 save (the fixture):
// rows (the first type alive picked), templar (its Pusaka asleep), hero (the priest: the crown), none (the soldier, none
// alive), armed (the axeman's Release armed: the chip red, the confirm on the right page), poor (no gold: white prices);
// then with a full type: locked (the priests at their cap, 5/5, picked: the forbidden price; Replace fallen in the
// footer); and the guide's pictures I2 and I3 (`-pic-gold`, `-pic-roster`: since decisions-log 201 the type caps').
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flame/game.dart' hide Game;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';
import 'package:tower_defense/guide_rules.dart' show guideIntro;
import 'package:tower_defense/main.dart';

import 'hud_font.dart';
import 'probe_root.dart';

const out = String.fromEnvironment('OUT', defaultValue: '$probeRoot/shots/troops-t1/after');

Future<void> frames(WidgetTester tester, [int n = 2]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

/// The middle of field cell ([c], [r]), as a fallen troop's spot.
Point<double> cellMiddle(int c, int r) => Point(c * tile + tile / 2, r * tile + tile / 2);

Game load() => Game.fromJson(jsonDecode(File('test/fixtures/save-20261002-2222-w89-sellbug.json').readAsStringSync()) as Map<String, dynamic>)
    .boardRules()
  ..chests.clear();

/// A full type (decisions-log 201): the free priest and four more (5/5), a soldier, an archer and a knight; a soldier of
/// the last wave fell.
Game full() {
  final g = Game().boardRules()
    ..gold = 5000
    ..capacity = 12;
  for (final type in ['priest', 'priest', 'priest', 'priest', 'soldier', 'archer', 'knight']) {
    g.autoPlace(type);
  }
  for (final u in g.troops) {
    u
      ..pos = u.post
      ..arriving = false;
  }
  g.toReplace.add((type: 'soldier', post: cellMiddle(1, 1)));
  return g;
}

void main() {
  testWidgets('army page shots', (tester) async {
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
      print('wrote $out/$name.png ${img.width}x${img.height}; picked ${b.troopPicked}, rows ${b.bookRows.length}, '
          'stats ${b.troopRowStats(b.troopPicked)}, build ${b.rowBuildName(b.troopPicked)?.$1}, confirm ${b.releaseConfirm}');
    }

    Future<void> tap(Rect r) async {
      if (r == Rect.zero) return;
      await tester.tapAt(r.center);
      await frames(tester);
    }

    for (final (tag, size) in const [('desk', Size(1266, 713)), ('phone', Size(412, 860)), ('wide', Size(915, 412))]) {
      tester.view.physicalSize = size;
      final g = b.state = load();
      await frames(tester, 50);
      if (b.messageBox != Rect.zero) await tap(b.messageBox);
      await shot('$tag-rows');
      await tap(b.troopRow('knight_templar'));
      await shot('$tag-templar');
      await tap(b.troopRow('priest'));
      await shot('$tag-hero');
      await tap(b.troopRow('soldier'));
      await shot('$tag-none');
      await tap(b.releaseChip('armored_axeman'));
      await shot('$tag-armed');
      await tap(b.troopRow('soldier'));
      g.gold = 0;
      await shot('$tag-poor');

      b.state = full();
      await frames(tester, 50);
      await tap(b.troopRow('priest'));
      await shot('$tag-locked');

      b
        ..state = Game()
        ..guideSeen = {}
        ..openGuide(guideIntro);
      await frames(tester, 30);
      await tap(b.coachButtons['next']!);
      await shot('$tag-pic-gold');
      await tap(b.coachButtons['next']!);
      await shot('$tag-pic-roster');
      await tap(b.coachButtons['skip']!); // closes the intro
      b.guideSeen = null;
      b.state = Game();
      await frames(tester, 5);
    }
    await frames(tester, 10);
  });
}
