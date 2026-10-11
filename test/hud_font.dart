// The game's font for the tests (lib/hud_font.dart): a test has no bundled fonts, so a widget test that measures or
// shows text loads it first, else every glyph is an Ahem box.
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show FontLoader, rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/hud_font.dart';

/// Pixelify Sans as google/fonts released it, the source tool/make_poh_sans.py builds the game's font from: the
/// tests that hold the two side by side load it under [sourceFont] ([loadSourceFont]).
const sourceFont = 'PixelifySans', sourceFontFile = 'tool/fonts/PixelifySans.ttf';

/// Loads the game's font under its family ([hudFont]), from inside a test.
Future<void> loadHudFont(WidgetTester tester) => tester.runAsync(loadHudFontNow);

/// [loadHudFont] for code that already runs in `tester.runAsync`.
Future<void> loadHudFontNow() => (FontLoader(hudFont)..addFont(rootBundle.load(hudFontAsset))).load();

/// Loads Pixelify Sans itself under [sourceFont] (a file of the repo, not a bundled asset), from inside a test.
Future<void> loadSourceFont(WidgetTester tester) => tester.runAsync(() => (FontLoader(sourceFont)
      ..addFont(Future.value(ByteData.sublistView(File(sourceFontFile).readAsBytesSync()))))
    .load());

/// The code points the game's font maps, from its cmap's format 4 subtables: what a line may use (the HUD has no
/// fallback font of its own; a glyph the font lacks, like "★" or an arrow, is drawn instead). With [asset], another
/// font file's.
Set<int> fontChars([String asset = hudFontAsset]) {
  final b = ByteData.sublistView(File(asset).readAsBytesSync());
  var cmap = 0;
  for (var i = 0; i < b.getUint16(4); i++) {
    final at = 12 + 16 * i;
    if (String.fromCharCodes([for (var k = 0; k < 4; k++) b.getUint8(at + k)]) == 'cmap') cmap = b.getUint32(at + 8);
  }
  final chars = <int>{};
  for (var i = 0; i < b.getUint16(cmap + 2); i++) {
    final st = cmap + b.getUint32(cmap + 8 + 8 * i);
    if (b.getUint16(st) != 4) continue;
    final segs = b.getUint16(st + 6) ~/ 2;
    for (var k = 0; k < segs; k++) {
      final end = b.getUint16(st + 14 + 2 * k), start = b.getUint16(st + 16 + 2 * segs + 2 * k);
      for (var c = start; c <= end && c != 0xFFFF; c++) {
        chars.add(c);
      }
    }
  }
  return chars;
}
