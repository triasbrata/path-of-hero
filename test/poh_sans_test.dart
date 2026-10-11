// The game's font (decisions-log 179; docs/ui-hud.md "The font"): Poh Sans, Pixelify Sans with its 2, 3, 5, 6, 9, B,
// C, G, S, Z, a, c and i redrawn. Its file is what tool/make_poh_sans.py writes from google/fonts' Pixelify Sans (both
// sha256 pinned), it maps what Pixelify Sans maps, and a text in it is exactly as wide as in Pixelify Sans, as tall and
// on the same baseline, at 400, 500 and 700: the kerning is the font's own, with no drift (PohDigits, before it, lost
// the kern of every pair with a B, C or G: a kern never crosses from one font to another). A text with none of the 13 is the
// same pixels; test/letter_shapes_test.dart checks that every two letters and digits are drawn apart.
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/hud_font.dart';

import 'asset_manifest_test.dart' show sha256Hex;
import 'hud_font.dart';

/// The font's sha256: a change of the tool shows here (rerun it, then pin the new one). And its source's.
const pohSansSha256 = 'f011cc3f1a78b0f912b3301dcde9360b60677b4ad8c19ce9a8b5886b6a08ed30';
const pixelifySansSha256 = '9ba86cd010a4de309d263ceff8e8044092c9db7efda869620cb9ff1c4389e8a5';

/// The glyphs tool/make_poh_sans.py redraws.
const redrawn = '23569BCGSZaci';

void main() {
  test('the font is what tool/make_poh_sans.py writes from Pixelify Sans, and maps what it maps', () {
    expect(sha256Hex(File(hudFontAsset).readAsBytesSync()), pohSansSha256);
    expect(sha256Hex(File(sourceFontFile).readAsBytesSync()), pixelifySansSha256);
    expect(fontChars(), fontChars(sourceFontFile));
    expect(File(hudFontLicence).readAsStringSync(),
        allOf(contains('is a Modified Version of Pixelify Sans'), contains(pixelifySansSha256)));
    final ProcessResult check;
    try {
      check = Process.runSync('python3', ['tool/make_poh_sans.py', '--check']);
    } on ProcessException {
      markTestSkipped('no python3: the sha256 above stand for the tool');
      return;
    }
    expect(check.exitCode, 0, reason: '${check.stdout}${check.stderr}');
  });

  testWidgets('a text is as wide as in Pixelify Sans, its kerns and all, as tall, on one baseline, and the same pixels '
      'but where a glyph is redrawn', (tester) async {
    await loadHudFont(tester);
    await loadSourceFont(tester);
    TextPainter painter(String s, double size, FontWeight weight, String family) => TextPainter(
        text: TextSpan(
            text: s,
            style: TextStyle(
                fontFamily: family, fontSize: size * hudFontScale, fontWeight: weight, fontFeatures: hudFeatures)),
        textDirection: TextDirection.ltr)
      ..layout();
    Future<Uint8List> pixels(TextPainter p) async {
      final rec = ui.PictureRecorder();
      p.paint(Canvas(rec), Offset.zero);
      final img = await rec.endRecording().toImage(p.width.ceil() + 2, p.height.ceil() + 2);
      return (await img.toByteData(format: ui.ImageByteFormat.rawRgba))!.buffer.asUint8List();
    }

    // Pixelify Sans's kern of a pair (its width as a pair less each glyph alone), in pixels.
    double kern(String pair, double size, FontWeight w) =>
        painter(pair, size, w, sourceFont).width -
        painter(pair[0], size, w, sourceFont).width -
        painter(pair[1], size, w, sourceFont).width;

    var kerned = 0;
    for (final weight in [FontWeight.w400, hudBody, hudBold]) {
      for (final size in [14.0, 18.0, 30.0]) {
        for (final s in [
          '+5%', '25%', '15k', '1.552.505', '0123456789', 'Now: 5 types, +25%', 'SsOo0 1lI|8B2Z', //
          'ABCDEFGHIJKLMNOPQRSTUVWXYZ', 'abcdefghijklmnopqrstuvwxyz', 'DEFHJKLMNOPQRSTUVWXY', 'bdefghjklmnopqrstuvwxyz',
          'Cara Main', 'Curse of Frailty', 'Peti Bos & Pusaka', 'Items & Bangkit', 'Gelombang 12', 'XCYBAC', //
          'Kocok ulang', 'Circle Slash', 'Pindah', 'Pilih ini', 'The fight', 'at first', 'Zirah', 'aBco ct cT', //
          'Ksatria Pemanah Penyihir', 'Hero bertahan', 'Tower Defense', 'Ulang', 'Lanjutkan', //
        ]) {
          final now = painter(s, size, weight, hudFont), was = painter(s, size, weight, sourceFont);
          final what = '"$s" at $size, ${weight.value}';
          expect(now.width, was.width, reason: '$what: as wide, every kern kept');
          expect(now.height, was.height, reason: '$what: as tall');
          expect(now.computeDistanceToActualBaseline(TextBaseline.alphabetic),
              was.computeDistanceToActualBaseline(TextBaseline.alphabetic), reason: '$what: on one baseline');
          final (a, b) = await tester.runAsync(() async => (await pixels(now), await pixels(was))).then((v) => v!);
          final changed = s.split('').any(redrawn.contains);
          expect(listEquals(a, b), !changed, reason: '$what: ${changed ? 'a redrawn glyph drawn new' : 'the same pixels'}');
          for (var i = 0; i + 1 < s.length; i++) {
            final pair = s.substring(i, i + 2);
            if (pair.split('').any(redrawn.contains) && kern(pair, size, weight).abs() > 1e-3) kerned++;
          }
        }
      }
    }
    // "Bos", "aB", "co", "ct" and the rest are kerned pairs with a redrawn glyph: kerns PohDigits lost, kept here.
    expect(kerned, greaterThan(0));

    // The game's style is this font at the body and title weights.
    for (final bold in [false, true]) {
      final p = TextPainter(text: TextSpan(text: 'Cara Main 59', style: hudStyle(18, bold: bold)), textDirection: TextDirection.ltr)
        ..layout();
      final (a, b) = await tester
          .runAsync(() async => (await pixels(p), await pixels(painter('Cara Main 59', 18, bold ? hudBold : hudBody, hudFont))))
          .then((v) => v!);
      expect(listEquals(a, b), isTrue, reason: 'hudStyle(bold: $bold)');
    }
  });
}
