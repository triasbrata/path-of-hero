// Every two letters and digits drawn apart (decisions-log 168 and 179; docs/ui-hud.md "The font"). Pixelify Sans grows
// bolder by growing each pixel on a fixed grid, so a one-pixel gap is 80 units at weight 400, 65 at 500 and 34 at 700,
// and at the HUD's sizes it blurred shut: its C and c were its O and o with one pixel out ("Cara Main" read "Oara
// Main", "Kocok" "Koook"), its i its l with one pixel out, its B and G an O with a mark ("Bos" read "Gos"). Here each
// of A-Z, a-z and 0-9 is drawn alone, at body and title sizes and at 400, 500 and 700, and every two differ by at least
// [apart] font pixels of ink: in the game's font, Poh Sans, all of them; in Pixelify Sans itself not, and each pair it
// draws too close has one of the glyphs Poh Sans redraws. And a redrawn glyph in a line is not drawn as its look-alike
// would be there.
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/hud_font.dart';

import 'hud_font.dart';
import 'poh_sans_test.dart' show redrawn;

/// The least ink two glyphs differ by, in font pixels (a font pixel is `drawn size / hudFontGrid` square): the sum of
/// their pixels' alpha differences. Pixelify Sans's closest two (C and O, i and l) are 0.2 to 1.0 apart at these
/// sizes, and 21 pairs are under 2 (B/G, S/8, 3/8, 6/8, … mostly in bold); in Poh Sans the closest, c and o, are 2.4.
const apart = 2.0;

/// The HUD sizes checked: the body texts' (the guide's cards, the foe splash's lines) and the titles'.
const sizes = [12.0, 14.0, 18.0, 22.0, 30.0];

/// The weights: the font's default, the body's and the titles'.
const weights = [FontWeight.w400, hudBody, hudBold];

/// A-Z, a-z and 0-9, from their code ranges (written out, the 62 letters read as a key to the export's secrets check).
final glyphs = String.fromCharCodes([
  for (final (from, to) in const [('A', 'Z'), ('a', 'z'), ('0', '9')])
    for (var c = from.codeUnitAt(0); c <= to.codeUnitAt(0); c++) c,
]);

/// Whether a pair is checked: not a letter and its own capital (the same letter: F and f differ by one corner pixel,
/// and the lower case of C, O, S, U, V, W, X, Z is its capital made small), nor O and 0, one outline in the font (a 0
/// stands among digits, an O among letters).
bool checked(String a, String b) => a.toLowerCase() != b.toLowerCase() && !{a, b}.containsAll(['O', '0']);

void main() {
  /// [s] in [family] at HUD size [size] and [weight], as the game draws it ([hudFeatures]): its painter and its pixels'
  /// alpha (0 to 1), on a canvas [w] x [h] (default: its size).
  Future<(TextPainter, Float64List, int)> draw(WidgetTester tester, String s, String family, double size,
      FontWeight weight, {int? w, int? h}) async {
    final p = TextPainter(
        text: TextSpan(
            text: s,
            style: TextStyle(
                fontFamily: family, fontSize: size * hudFontScale, fontWeight: weight, fontFeatures: hudFeatures)),
        textDirection: TextDirection.ltr)
      ..layout();
    final width = w ?? p.width.ceil() + 2, height = h ?? p.height.ceil() + 2;
    final rgba = (await tester.runAsync(() async {
      final rec = ui.PictureRecorder();
      p.paint(Canvas(rec), const Offset(1, 1));
      final img = await rec.endRecording().toImage(width, height);
      return (await img.toByteData(format: ui.ImageByteFormat.rawRgba))!.buffer.asUint8List();
    }))!;
    return (p, Float64List.fromList([for (var i = 3; i < rgba.length; i += 4) rgba[i] / 255]), width);
  }

  /// The ink [a] and [b] differ by in the columns [from] to [to] (of a canvas [w] wide), in font pixels at [size].
  double differ(Float64List a, Float64List b, int w, double size, {int from = 0, int? to}) {
    var sum = 0.0;
    for (var i = 0; i < a.length; i++) {
      final x = i % w;
      if (x >= from && x < (to ?? w)) sum += (a[i] - b[i]).abs();
    }
    final px = size * hudFontScale / hudFontGrid;
    return sum / (px * px);
  }

  /// The checked pairs [family] draws less than [apart] apart, as "c/o 0.62 at 14.0, 700", printing the closest pair
  /// at each size and weight.
  Future<List<String>> near(WidgetTester tester, String family) async {
    final out = <String>[];
    for (final weight in weights) {
      for (final size in sizes) {
        // One canvas for all, as wide as the widest (M, W) and as tall as a line, each glyph at the same origin.
        final (probe, _, _) = await draw(tester, 'W', family, size, weight);
        final w = probe.width.ceil() + 2, h = probe.height.ceil() + 2;
        final cells = {for (final c in glyphs.split('')) c: (await draw(tester, c, family, size, weight, w: w, h: h)).$2};
        final at = '$size, ${weight.value}';
        var least = (double.infinity, '');
        for (var i = 0; i < glyphs.length; i++) {
          for (var k = i + 1; k < glyphs.length; k++) {
            if (!checked(glyphs[i], glyphs[k])) continue;
            final d = differ(cells[glyphs[i]]!, cells[glyphs[k]]!, w, size);
            final pair = '${glyphs[i]}/${glyphs[k]}';
            if (d < least.$1) least = (d, pair);
            if (d < apart) out.add('$pair ${d.toStringAsFixed(2)} at $at');
          }
        }
        // ignore: avoid_print
        print('$family closest at $at: ${least.$2} ${least.$1.toStringAsFixed(2)}');
      }
    }
    return out;
  }

  testWidgets('every two letters and digits are drawn apart in the game\'s font, at body and title sizes, at 400, 500 '
      'and 700', (tester) async {
    await loadHudFont(tester);
    expect(await near(tester, hudFont), isEmpty, reason: 'glyphs drawn alike');
  });

  testWidgets('Pixelify Sans draws some alike, and each such pair has a glyph the game\'s font redraws', (tester) async {
    await loadSourceFont(tester);
    final alike = await near(tester, sourceFont);
    final pairs = {for (final n in alike) n.split(' ').first};
    // ignore: avoid_print
    print('Pixelify Sans: ${pairs.join(', ')}');
    expect(pairs, containsAll(['C/O', 'B/G', 'B/8', 'a/o', 'c/o', 'i/l', '6/8', '8/9', 'Z/2']));
    for (final p in pairs) {
      expect(p.split('/').any(redrawn.contains), isTrue, reason: '$p: neither glyph redrawn');
    }
  });

  testWidgets('a redrawn glyph in a line is not drawn as its look-alike would be there', (tester) async {
    await loadHudFont(tester);
    const like = {'C': 'O', 'c': 'o', 'i': 'l', 'a': 'o', 'B': 'G', 'G': 'B'};
    for (final weight in [hudBody, hudBold]) {
      for (final size in sizes) {
        for (final s in ['Cara Main', 'Curse of Frailty', 'Kocok ulang', 'Circle Slash', 'Pindah', 'Pilih ini',
          'Pasukan Ksatria', 'Peti Bos', 'Gelombang']) {
          final (ps, ink, w) = await draw(tester, s, hudFont, size, weight);
          for (var i = 0; i < s.length; i++) {
            final other = like[s[i]];
            if (other == null) continue;
            final t = s.replaceRange(i, i + 1, other);
            final (pt, inkT, wt) = await draw(tester, t, hudFont, size, weight);
            Rect box(TextPainter p) =>
                p.getBoxesForSelection(TextSelection(baseOffset: i, extentOffset: i + 1)).first.toRect();
            final bs = box(ps), bt = box(pt);
            // The two cells, each cut from its own line at its own place (a kern may move the other), side by side.
            final cw = bs.width.ceil() + 2, h = ink.length ~/ w;
            Float64List cut(Float64List img, int imgW, Rect b) => Float64List.fromList([
                  for (var y = 0; y < h; y++)
                    for (var x = 0; x < cw; x++) (b.left.floor() + x < imgW) ? img[y * imgW + b.left.floor() + x] : 0,
                ]);
            final d = differ(cut(ink, w, bs), cut(inkT, wt, bt), cw, size);
            expect(d, greaterThanOrEqualTo(apart),
                reason: '"$s" at $size, ${weight.value}: its ${s[i]} at $i drawn as "$t"\'s $other '
                    '(${d.toStringAsFixed(2)} apart)');
          }
        }
      }
    }
  });
}
