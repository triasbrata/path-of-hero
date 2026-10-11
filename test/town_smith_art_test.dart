// The Town's smith (decisions-log 265; docs/assets.md "Packs -> files"): the strip tool/import_smith.py writes into
// assets/images and lib/town_smith_art.dart's names for it. Sizes, frames and the loop only, so it passes on the public
// repo's placeholders too (tool/gen_placeholders.py draws one); that every frame holds the packs' own pixels is the
// tool's `--check`.
import 'dart:ui' as ui;

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/town_smith_art.dart';

void main() {
  testWidgets('the smith\'s strip loads at its frames\' size, every frame drawn, his feet on its bottom row',
      (tester) async {
    late int w, h;
    final drawn = <bool>[];
    await tester.runAsync(() async {
      final data = await rootBundle.load('assets/images/$townSmith');
      final image = (await (await ui.instantiateImageCodec(data.buffer.asUint8List())).getNextFrame()).image;
      (w, h) = (image.width, image.height);
      final px = (await image.toByteData())!.buffer.asUint8List(); // RGBA, a byte each
      for (var f = 0; f < townSmithFrames; f++) {
        var any = false;
        for (var y = 0; y < h && !any; y++) {
          for (var x = f * townSmithW; x < (f + 1) * townSmithW && !any; x++) {
            any = px[(y * w + x) * 4 + 3] > 0;
          }
        }
        drawn.add(any);
      }
      image.dispose();
    });
    expect((w, h), (townSmithFrames * townSmithW, townSmithH));
    expect(drawn, List.filled(townSmithFrames, true));
    expect(townSmithFeet.x, inInclusiveRange(1, townSmithW - 1));
    expect(townSmithFeet.y, townSmithH, reason: 'the frame is cut at his feet\'s row');
  });

  test('the loop plays every frame, each beat a frame of the strip, and lasts townSmithLoopMs', () {
    expect(townSmithBeats.every((b) => b.frame >= 0 && b.frame < townSmithFrames && b.ms > 0), isTrue);
    expect({for (final b in townSmithBeats) b.frame}, {for (var f = 0; f < townSmithFrames; f++) f});
    expect(townSmithBeats.fold(0, (s, b) => s + b.ms), townSmithLoopMs);
    // Three blows (raised, swing, strike) between the backswing and the pause, the pack's own timing.
    expect(townSmithBeats.where((b) => b.frame == 3).length, 3);
    expect(townSmithBeats.first.frame, 0);
    expect(townSmithBeats.last, (frame: 4, ms: 800));
  });
}
