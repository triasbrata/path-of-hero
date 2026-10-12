import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';

import 'touch_hud_test.dart' show boot, frames, on, pieces;

// The HUD's top row at every window size (decisions-log 217, docs/ui-hud.md "Layouts"): its scale is capped at the desk's
// share of the height and to what the row's width allows, on every platform, so no two pieces overlap at any landscape size from 900x400 to 2600x1500
// (a view taller than wide is letterboxed to one, decisions-log 289), and where the
// scale is 3 or 4 every button is at least 40 px each way (at 2, the phones' size, as before). Measured
// at its widest (decisions-log 220): five digits of gold, the tide's badge and 3-digit counts on the wave meter, Auto
// on (Start keeps room for its seconds); and x2, Auto and the meter stay where they were between waves, the Start/Pause
// toggle's middle too. In a Town (decisions-log 216) the toggle's Start is "Leave town 5", wider than "Start 5": no
// overlap there either.

void main() {
  for (final platform in [TargetPlatform.macOS, TargetPlatform.android]) {
    testWidgets('the HUD\'s pieces never overlap at any window size on $platform', (tester) async {
      final b = await boot(tester);
      final bad = <String>[];
      await on(platform, () async {
        for (var h = 400; h <= 1500; h += 50) {
          for (var w = 900; w <= 2600; w += 50) {
            if (h > w) continue; // taller than wide: the game lays out in the letterbox's landscape (letterbox_test.dart)
            Map<String, Rect>? between;
            for (final state in ['between', 'wave', 'town']) {
              final wave = state == 'wave';
              tester.view.physicalSize = Size(w.toDouble(), h.toDouble());
              b.autoStart.set(true);
              final g = b.state = Game()
                ..gold = 99999 // five digits: the widest the row is measured with
                ..wave = 99 // the tide's badge, and 3-digit counts
                ..townAt = state == 'town' ? 100 : null; // a Town only for the Town's state, no chip on the field
              if (wave) g.startWave();
              if (state == 'town') expect(g.enterTown(), isTrue);
              await frames(tester, 3);
              final at = pieces(b)..removeWhere((_, r) => r == Rect.zero);
              final k = b.hudScale, names = at.keys.toList(), tag = '${w}x$h $state k $k';
              if (between == null) {
                between = at;
              } else if (wave) {
                for (final name in ['x2', 'Auto', 'meter']) {
                  if (at[name] != between[name]) bad.add('$tag: $name moved from ${between[name]} to ${at[name]}');
                }
                if ((at['toggle']!.center.dx - between['toggle']!.center.dx).abs() > 1) bad.add('$tag: the toggle moved');
              }
              for (var i = 0; i < names.length; i++) {
                for (var j = i + 1; j < names.length; j++) {
                  if (at[names[i]]!.overlaps(at[names[j]]!)) bad.add('$tag: ${names[i]} over ${names[j]}');
                }
              }
              if (k >= 3) {
                for (final name in ['counter', 'x2', 'book', 'toggle', 'Auto', 'meter', 'log']) {
                  final r = at[name];
                  if (r != null && (r.width < 40 || r.height < 40)) bad.add('$tag: $name is $r');
                }
              }
            }
          }
        }
      });
      expect(bad, isEmpty, reason: '${bad.length}: ${bad.take(40).join('\n')}');
    });
  }

  testWidgets('the desk sizes that never overlapped keep their scale and their HUD, desktop and phone alike', (tester) async {
    final b = await boot(tester);
    for (final (size, k) in const [
      (Size(1266, 713), 3.0),
      (Size(1280, 720), 3.0),
      (Size(915, 412), 2.0),
      (Size(915, 610), 2.0), // the letterbox's, in a view taller than wide (decisions-log 289)
      (Size(1920, 1080), 4.0),
      (Size(2560, 1440), 4.0),
      (Size(1164, 777), 3.0), // the owner's tablet; the desktop window of that size too (4 before decisions-log 217)
      (Size(1366, 1024), 3.0),
    ]) {
      final huds = <Map<String, Rect>>[];
      for (final platform in [TargetPlatform.macOS, TargetPlatform.android]) {
        await on(platform, () async {
          tester.view.physicalSize = size;
          b.state = Game();
          await frames(tester, 3);
          expect(b.hudScale, k, reason: '$size on $platform');
          huds.add(pieces(b));
        });
      }
      expect(huds[0], huds[1], reason: '$size: the same HUD on both');
    }
  });
}
