// The Army detail's foot seen (decisions-log 288; ui-hud.md "Army", the foot): offscreen shots into
// <probe root>/shots/release-foot/new (`OUT`). A probe, not part of the suite (no `_test.dart`): queue
// `["test", "test/probe_release_foot_shots.dart"]` with a mirror as `dir`. It never touches the real save
// (flutter_test_config.dart's temp dir), and wins no wave. It uses only getters the foot had before 288 (releaseChip,
// releaseConfirm, replaceButton, troopDetailBody), so the same file shoots the page before and after.
//
// At 1600x947 (the owner's window), 1266x713, 1164x777 and 915x412 (landscape only: decisions-log 289), on four
// types (the free priest, a soldier, an archer, a knight; the knight picked): release (Release showing), armed (its
// confirm), replace (a soldier of the last wave fell: Replace fallen with Release), replace-armed; then the wave-89 save
// (the fixture, the Templars picked): w89, w89-armed, and with seven Templars of the last wave fallen w89-replace,
// w89-replace-armed. Each line printed gives the right page, the body and its content,
// Release, the confirm and its words, Replace fallen and its label, for a crop and the numbers.
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

const out = String.fromEnvironment('OUT', defaultValue: '$probeRoot/shots/release-foot/new');

Future<void> frames(WidgetTester tester, [int n = 2]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

/// The middle of field cell ([c], [r]), as a fallen troop's spot.
Point<double> cellMiddle(int c, int r) => Point(c * tile + tile / 2, r * tile + tile / 2);

/// Four types: the free priest, a soldier, an archer and a knight, everyone at its post (troops_detail_test's).
Game fourTypes() {
  final g = Game().boardRules()..gold = 50000;
  for (final type in ['soldier', 'archer', 'knight']) {
    g.autoPlace(type);
  }
  for (final u in g.troops) {
    u
      ..pos = u.post
      ..arriving = false;
  }
  return g;
}

Game w89() => Game.fromJson(jsonDecode(File('test/fixtures/save-20261002-2222-w89-sellbug.json').readAsStringSync()) as Map<String, dynamic>)
    .boardRules()
  ..chests.clear()
  ..notes.addAll(const {'army', 'over', 'caps'});

String r(Rect x) => x == Rect.zero ? '-' : '(${x.left.toStringAsFixed(1)},${x.top.toStringAsFixed(1)} ${x.width.toStringAsFixed(1)}x${x.height.toStringAsFixed(1)})';

void main() {
  testWidgets('release foot shots', (tester) async {
    tester.view
      ..physicalSize = const Size(1600, 947)
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
      final p = b.troopPicked;
      // ignore: avoid_print
      print('SHOT $name ${img.width}x${img.height} picked $p right ${r(b.bookPages.$2)} body ${r(b.troopDetailBody)} '
          'content ${b.troopDetailContent.toStringAsFixed(1)} release ${r(b.releaseChip(p))} confirm ${r(b.releaseConfirm)} '
          '"${b.troopDetailWords('releaseConfirm').join(' / ')}" replace ${r(b.replaceButton)} "${b.replaceLabel}" '
          'separator ${r(b.troopDetail('separator'))}');
    }

    Future<void> tap(Rect x) async {
      if (x == Rect.zero) return;
      await tester.tapAt(x.center);
      await frames(tester);
    }

    // The type's cell, after turning the grid to its page.
    Future<void> pick(String type) async {
      for (var i = 0; i < 4 && b.troopRow(type) == Rect.zero && b.armyPage > 0; i++) {
        await tap(b.armyPager.$1);
      }
      for (var i = 0; i < 4 && b.troopRow(type) == Rect.zero && b.armyPage < b.armyPageCount - 1; i++) {
        await tap(b.armyPager.$2);
      }
      await tap(b.troopRow(type));
    }

    for (final (tag, size) in const [
      ('1600x947', Size(1600, 947)),
      ('1266x713', Size(1266, 713)),
      ('1164x777', Size(1164, 777)),
      ('915x412', Size(915, 412)),
    ]) {
      tester.view.physicalSize = size;
      final g = b.state = fourTypes();
      await frames(tester, 50);
      if (b.messageBox != Rect.zero) await tap(b.messageBox);
      await pick('knight');
      await shot('$tag-release');
      await tap(b.releaseChip('knight'));
      await shot('$tag-armed');
      await pick('archer'); // lets it go
      await pick('knight');
      g.toReplace.add((type: 'soldier', post: cellMiddle(1, 1)));
      await shot('$tag-replace');
      await tap(b.releaseChip('knight'));
      await shot('$tag-replace-armed');
      await pick('archer');

      b.state = w89();
      await frames(tester, 50);
      if (b.messageBox != Rect.zero) await tap(b.messageBox);
      await pick('knight_templar');
      await shot('$tag-w89');
      await tap(b.releaseChip('knight_templar'));
      await shot('$tag-w89-armed');
      await pick('archer');
      final w = b.state;
      for (var i = 0; i < 7; i++) {
        w.toReplace.add((type: 'knight_templar', post: cellMiddle(1 + i % 3, 1 + i)));
      }
      await pick('knight_templar');
      await shot('$tag-w89-replace');
      await tap(b.releaseChip('knight_templar'));
      await shot('$tag-w89-replace-armed');
      await pick('archer');
      b.state = Game();
      await frames(tester, 5);
    }
    await frames(tester, 10);
  });
}
