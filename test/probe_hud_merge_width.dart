// How wide the landscape top band must be at each HUD scale k (decisions-log 220): the left row (the counter, the
// hearts-and-gold panel with 5 digits of gold, the book button in a wave), the toggle at its widest (Start with Auto's
// seconds), and the right group (x2, Auto, the wave meter with the tide's badge and 3-digit counts), 2·k apart. Prints
// one line per k; wave_meter.dart's [_rowWidthPerK] and [_rowWidthOff] are fitted to them. A probe, not part of the suite.
import 'package:flutter/foundation.dart' show debugDefaultTargetPlatformOverride;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';

import 'touch_hud_test.dart' show boot, frames;

void main() {
  testWidgets('hud merge widths', (tester) async {
    final b = await boot(tester);
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      for (final (k, h) in const [(2, 412.0), (3, 713.0), (4, 1080.0)]) {
        tester.view.physicalSize = Size(3000, h);
        b.autoStart.set(true);
        final g = b.state = Game()
          ..gold = 99999
          ..wave = 99;
        await frames(tester, 3);
        final start = b.toggleButton.width;
        g.startWave();
        await frames(tester, 3);
        final left = [b.troopCounter, b.heartsGoldPanel, b.bookButton].map((r) => r.right).reduce((a, c) => a > c ? a : c);
        final right = 3000 - b.speedButton.left, gap = 2 * b.hudScale;
        // ignore: avoid_print
        print('WIDTH k ${b.hudScale} (want $k): left $left start $start right $right needs ${left + gap + start + gap + right} '
            'meter ${b.waveMeter} x2 ${b.speedButton} auto ${b.autoButton} toggle ${b.toggleButton}');
      }
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
