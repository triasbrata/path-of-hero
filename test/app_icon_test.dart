import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

// The app icon's platform files (tool/make_app_icon.py, assets.md "The app icon"): each one is there with its
// sizes, read from the PNG and ICO headers, and none is still Flutter's default logo. Paths are the repo's.

/// A PNG's width, height and the RGBA of its top left pixel (the first pixel of the first row reads the same
/// under every PNG filter).
(int, int, List<int>) png(Uint8List b) {
  expect(b.sublist(0, 8), [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A], reason: 'PNG signature');
  final d = ByteData.sublistView(b);
  expect(ascii.decode(b.sublist(12, 16)), 'IHDR');
  final w = d.getUint32(16), h = d.getUint32(20);
  expect((b[24], b[25]), (8, 6), reason: '8-bit RGBA');
  final idat = BytesBuilder();
  for (var i = 8; i < b.length;) {
    final n = d.getUint32(i), type = ascii.decode(b.sublist(i + 4, i + 8));
    if (type == 'IDAT') idat.add(b.sublist(i + 8, i + 8 + n));
    i += 12 + n;
  }
  final raw = ZLibCodec().decode(idat.takeBytes());
  return (w, h, raw.sublist(1, 5));
}

(int, int, List<int>) pngFile(String path) {
  final f = File(path);
  expect(f.existsSync(), isTrue, reason: '$path exists');
  return png(f.readAsBytesSync());
}

/// FNV-1a (32 bit) of a file's bytes.
int fnv(List<int> bytes) {
  var h = 0x811c9dc5;
  for (final b in bytes) {
    h = ((h ^ b) * 16777619) & 0xFFFFFFFF;
  }
  return h;
}

/// Flutter's template icons as they were in this repo before the game's own (`flutter create`'s logo).
const flutterLogo = {
  0x7229dac1, 0xf1553769, 0x197d5c7b, 0xe20fe734, 0xa88f3c1f, // android mipmap-*/ic_launcher.png
  0x5002065f, 0x321a4b64, 0x2f1deeff, 0xfa5c3ddf, 0xf3c41075, 0xebb30e67, 0xd3cc2a5c, // macos app_icon_*.png
  0x7c93a21c, 0x33daa1d9, 0xf8216f77, 0x7c884bfc, 0xf18c08cb, // web favicon.png, icons/Icon-*.png
  0x59ae9775, // windows app_icon.ico
};

const mac = 'macos/Runner/Assets.xcassets/AppIcon.appiconset';
const res = 'android/app/src/main/res';
const dpis = {'mdpi': 1.0, 'hdpi': 1.5, 'xhdpi': 2.0, 'xxhdpi': 3.0, 'xxxhdpi': 4.0};

void main() {
  test('macOS: every Contents.json entry is a file of its size; outside the rounded square is clear', () {
    final contents = jsonDecode(File('$mac/Contents.json').readAsStringSync()) as Map<String, dynamic>;
    final files = <String>{};
    for (final e in (contents['images'] as List).cast<Map<String, dynamic>>()) {
      final side = int.parse((e['size'] as String).split('x').first), scale = int.parse((e['scale'] as String)[0]);
      final (w, h, corner) = pngFile('$mac/${e['filename']}');
      expect((w, h), (side * scale, side * scale), reason: '${e['filename']} is ${e['size']}@${e['scale']}');
      expect(corner[3], 0, reason: 'Apple\'s grid leaves the corners clear');
      files.add(e['filename'] as String);
    }
    expect(files, {for (final s in [16, 32, 64, 128, 256, 512, 1024]) 'app_icon_$s.png'});
  });

  test('Windows: app_icon.ico holds 16, 24, 32, 48, 64, 128 and 256 as PNG entries', () {
    final b = File('windows/runner/resources/app_icon.ico').readAsBytesSync(), d = ByteData.sublistView(b);
    expect((d.getUint16(0, Endian.little), d.getUint16(2, Endian.little)), (0, 1), reason: 'an icon file');
    final sizes = <int>[];
    for (var i = 0; i < d.getUint16(4, Endian.little); i++) {
      final at = 6 + 16 * i, side = b[at] == 0 ? 256 : b[at];
      final size = d.getUint32(at + 8, Endian.little), offset = d.getUint32(at + 12, Endian.little);
      expect(offset + size, lessThanOrEqualTo(b.length));
      final (w, h, _) = png(b.sublist(offset, offset + size));
      expect((w, h), (side, side));
      sizes.add(side);
    }
    expect(sizes, [16, 24, 32, 48, 64, 128, 256]);
    expect(File('windows/runner/Runner.rc').readAsStringSync(), contains(r'resources\\app_icon.ico'));
  });

  test('Linux: a 256 px window icon, installed into the bundle and set on the window', () {
    final (w, h, _) = pngFile('linux/runner/resources/app_icon.png');
    expect((w, h), (256, 256));
    expect(File('linux/CMakeLists.txt').readAsStringSync(), contains('install(FILES "runner/resources/app_icon.png"'));
    final runner = File('linux/runner/my_application.cc').readAsStringSync();
    expect(runner, contains('gtk_window_set_icon_from_file'));
    expect(runner, contains('"data", "app_icon.png"'));
  });

  test('Android: the legacy launcher icons and the adaptive icon\'s three layers at every density', () {
    for (final MapEntry(key: dpi, value: k) in dpis.entries) {
      final (w, h, _) = pngFile('$res/mipmap-$dpi/ic_launcher.png');
      expect((w, h), ((48 * k).round(), (48 * k).round()), reason: '$dpi ic_launcher');
      for (final layer in ['foreground', 'background', 'monochrome']) {
        final (w, h, corner) = pngFile('$res/mipmap-$dpi/ic_launcher_$layer.png');
        expect((w, h), ((108 * k).round(), (108 * k).round()), reason: '$dpi $layer');
        // The background fills the whole layer; the knight's layers are clear outside the safe circle.
        expect(corner[3], layer == 'background' ? 255 : 0, reason: '$dpi $layer corner');
      }
    }
    final xml = File('$res/mipmap-anydpi-v26/ic_launcher.xml').readAsStringSync();
    expect(xml, contains('<adaptive-icon'));
    for (final layer in ['background', 'foreground', 'monochrome']) {
      expect(xml, contains('<$layer android:drawable="@mipmap/ic_launcher_$layer"/>'));
    }
    expect(File('android/app/src/main/AndroidManifest.xml').readAsStringSync(), contains('android:icon="@mipmap/ic_launcher"'));
  });

  test('web: the favicon and every icon the manifest names, at the size it gives', () {
    expect(pngFile('web/favicon.png').$1, 32);
    expect(File('web/index.html').readAsStringSync(), contains('href="favicon.png"'));
    final manifest = jsonDecode(File('web/manifest.json').readAsStringSync()) as Map<String, dynamic>;
    final icons = (manifest['icons'] as List).cast<Map<String, dynamic>>();
    expect(icons, hasLength(4));
    for (final icon in icons) {
      final side = int.parse((icon['sizes'] as String).split('x').first);
      final (w, h, corner) = pngFile('web/${icon['src']}');
      expect((w, h), (side, side), reason: icon['src']);
      // A maskable icon is full bleed (the browser cuts its shape); the plain ones are a rounded square.
      expect(corner[3], icon['purpose'] == 'maskable' ? 255 : 0, reason: '${icon['src']} corner');
    }
  });

  test("no platform file is still Flutter's default logo", () {
    final files = [
      for (final s in [16, 32, 64, 128, 256, 512, 1024]) '$mac/app_icon_$s.png',
      'windows/runner/resources/app_icon.ico',
      'linux/runner/resources/app_icon.png',
      for (final dpi in dpis.keys) '$res/mipmap-$dpi/ic_launcher.png',
      'web/favicon.png',
      for (final n in ['Icon-192', 'Icon-512', 'Icon-maskable-192', 'Icon-maskable-512']) 'web/icons/$n.png',
    ];
    for (final f in files) {
      expect(flutterLogo, isNot(contains(fnv(File(f).readAsBytesSync()))), reason: f);
    }
  });
}
