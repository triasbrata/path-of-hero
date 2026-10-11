// The wizard's magic seen (decisions-log 313, units-and-combat.md "The wizard's magic"): offscreen frames of wizards
// firing their plain shots (as they are, and awakened at Awaken 2) and casting Arcane Blast, level and 45 degrees up,
// once the view has settled on them, into
// <probe root>/shots/mage-fx/probe/ (`OUT`), named `<TAG>-<size>-<scene>-<nn>.png`, one every 48 ms for 0.86 s
// (3 frames of 16 ms each). A probe, not part of the suite (no `_test.dart`): queue
// `["test", "test/probe_wizard_fx_shots.dart", "--dart-define=TAG=after"]` with the worktree (or a `git archive` mirror
// of a base, `TAG=before`) as `dir`. It reads no save and never touches the real one (flutter_test_config.dart's temp
// dir); the dice are seeded. Each scene prints the screen box round its wizards and foes, for cropping.
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flame/game.dart' hide Game;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';
import 'package:tower_defense/main.dart';

import 'hero_skill_helpers.dart';
import 'hud_font.dart';
import 'probe_root.dart';

const out = String.fromEnvironment('OUT', defaultValue: '$probeRoot/shots/mage-fx/probe');
const tag = String.fromEnvironment('TAG', defaultValue: 'after');

/// Every item [type]'s awakening recipe asks for, [level] times over: the type at awakening [level].
List<Item> recipe(String type, int level) => [
      for (final MapEntry(key: item, value: n) in awakenRecipe[type]!.entries)
        for (var i = 0; i < n * level; i++) item,
    ];

/// Two wizards (cells (2, 2) and (2, 4)), each with an orc before it that never falls: the first's level with it, the
/// second's up and ahead of it at 45 degrees. [arcane]: their skill is what they cast; else no skills.
/// [level]: their awakening. Everyone is held still until [release]d.
(Game, List<Unit>) scene({bool arcane = false, int level = 0}) {
  final g = bareGame(Random(1))
    ..heroSkills = false
    ..monsterSkills = false
    ..skills = arcane
    ..skillWinds = true; // as on the board: Arcane Blast winds up and fires on its strip's blow (skill_strips.dart)
  if (level > 0) g.upgrades['wizard'] = recipe('wizard', level);
  final ws = [placeNow(g, 'wizard', 2, 2), placeNow(g, 'wizard', 2, 4)];
  g
    ..startWave()
    ..queue.clear();
  final foes = <Unit>[];
  for (final (i, w) in ws.indexed) {
    w
      ..cd = hold
      ..mp = 0;
    foes.add(foeAt(g, 'orc', w.pos + (i == 0 ? const Point(44.0, 0.0) : const Point(36.0, -36.0)))
      ..hp = 1e6
      ..cd = hold
      ..busyUntil = double.negativeInfinity // drawn standing (a held one is drawn rising)
      ..stunUntil = 1e9); // and never walking off: frozen mid-flinch
  }
  return (g, [...ws, ...foes]);
}

/// Lets [units]' wizards act at once: Arcane Blast with [arcane], else their plain shot.
void release(List<Unit> units, {required bool arcane}) {
  for (final u in units.where((u) => u.side == Side.troop)) {
    u
      ..cd = arcane ? hold : 0
      ..mp = arcane ? u.stats.mp.toDouble() : 0;
  }
}

void main() {
  testWidgets('wizard fx shots', (tester) async {
    await tester.runAsync(() async {
      await loadHudFontNow();
    });
    tester.view
      ..physicalSize = const Size(1600, 947)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
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
    }

    for (final (size, label) in const [(Size(1600, 947), '1600'), (Size(915, 412), '915')]) {
      tester.view.physicalSize = size;
      for (final (name, arcane, level) in const [('plain', false, 0), ('awake2', false, 2), ('arcane', true, 0)]) {
        final (g, units) = scene(arcane: arcane, level: level);
        b.state = g;
        for (var i = 0; i < 90; i++) {
          await tester.pump(const Duration(milliseconds: 16)); // the view settles on them
        }
        release(units, arcane: arcane);
        final xs = [for (final u in units) u.pos.x], ys = [for (final u in units) u.pos.y];
        final lt = b.toScreen(xs.reduce(min) - 20, ys.reduce(min) - 30), rb = b.toScreen(xs.reduce(max) + 20, ys.reduce(max) + 14);
        // ignore: avoid_print
        print('box $tag-$label-$name ${lt.dx.round()} ${lt.dy.round()} ${(rb.dx - lt.dx).round()} ${(rb.dy - lt.dy).round()}');
        for (var i = 0; i < 18; i++) {
          await shot('$tag-$label-$name-${i.toString().padLeft(2, '0')}');
          for (var k = 0; k < 3; k++) {
            await tester.pump(const Duration(milliseconds: 16));
          }
        }
        // ignore: avoid_print
        print('$tag-$label-$name t ${g.t.toStringAsFixed(2)} casts ${[for (final u in units.take(2)) u.skillAt.toStringAsFixed(2)]}');
      }
    }
    await tester.pump(const Duration(milliseconds: 16));
  });
}
