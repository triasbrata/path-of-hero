// tool/asset_manifest.json and tool/assets.sha256 (decisions-log 157, docs/assets.md "Placeholder art"): what the
// public repo carries in place of the licensed files under assets/, which tool/gen_placeholders.py draws placeholders
// from. `python3 tool/asset_manifest.py` writes both; these tests fail while assets/ has changed without it. The
// first and the last pass on placeholders too (the public repo); the hashes need the real art (`art`).
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

final manifest = jsonDecode(File('tool/asset_manifest.json').readAsStringSync()) as Map<String, dynamic>;
final files = [for (final f in manifest['files'] as List) f as Map<String, dynamic>];

/// A manifest pattern: a `*` never crosses a `/`.
RegExp glob(String pattern) => RegExp('^${pattern.split('*').map(RegExp.escape).join('[^/]*')}\$');

/// Every file under assets/ but hidden ones (Finder's .DS_Store), sorted.
List<String> assetFiles() => [
      for (final f in Directory('assets').listSync(recursive: true))
        if (f is File && !f.uri.pathSegments.last.startsWith('.')) f.path,
    ]..sort();

/// SHA-256 (FIPS 180-4), so the test needs no package.
String sha256Hex(Uint8List data) {
  const k = [
    0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5, //
    0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
    0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
    0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
    0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
    0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
    0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
    0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
  ];
  final h = [0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a, 0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19];
  const mask = 0xffffffff;
  int rotr(int x, int n) => (x >>> n | x << (32 - n)) & mask;
  final n = data.length, padded = (n + 9 + 63) ~/ 64 * 64;
  final m = Uint8List(padded)..setRange(0, n, data);
  m[n] = 0x80;
  final bytes = ByteData.sublistView(m)
    ..setUint32(padded - 8, n * 8 ~/ 0x100000000)
    ..setUint32(padded - 4, n * 8 & mask);
  final w = Uint32List(64);
  for (var o = 0; o < padded; o += 64) {
    for (var i = 0; i < 16; i++) {
      w[i] = bytes.getUint32(o + i * 4);
    }
    for (var i = 16; i < 64; i++) {
      final s0 = rotr(w[i - 15], 7) ^ rotr(w[i - 15], 18) ^ w[i - 15] >>> 3;
      final s1 = rotr(w[i - 2], 17) ^ rotr(w[i - 2], 19) ^ w[i - 2] >>> 10;
      w[i] = w[i - 16] + s0 + w[i - 7] + s1; // a Uint32List keeps the low 32 bits
    }
    var [a, b, c, d, e, f, g, hh] = h;
    for (var i = 0; i < 64; i++) {
      final t1 = (hh + (rotr(e, 6) ^ rotr(e, 11) ^ rotr(e, 25)) + (e & f ^ ~e & g) + k[i] + w[i]) & mask;
      final t2 = ((rotr(a, 2) ^ rotr(a, 13) ^ rotr(a, 22)) + (a & b ^ a & c ^ b & c)) & mask;
      (hh, g, f, e, d, c, b, a) = (g, f, e, (d + t1) & mask, c, b, a, (t1 + t2) & mask);
    }
    for (final (i, v) in [a, b, c, d, e, f, g, hh].indexed) {
      h[i] = (h[i] + v) & mask;
    }
  }
  return [for (final v in h) v.toRadixString(16).padLeft(8, '0')].join();
}

void main() {
  test('sha256Hex is SHA-256', () {
    expect(sha256Hex(Uint8List(0)), 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855');
    expect(sha256Hex(utf8.encode('abc')), 'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad');
    // Two blocks, and a length that fills the first one's padding.
    expect(sha256Hex(utf8.encode('abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq')),
        '248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1');
  });

  test('every file under assets/ is licensed and in the manifest at its image size and grid, or our own', () {
    final licensed = [for (final p in manifest['licensed'] as List) glob(p as String)];
    final own = [for (final p in manifest['own'] as List) glob(p as String)];
    final listed = {for (final f in files) f['path'] as String: f};
    expect(listed.length, files.length, reason: 'a path listed twice');
    for (final path in assetFiles()) {
      final isOwn = own.any((g) => g.hasMatch(path)), isLicensed = licensed.any((g) => g.hasMatch(path));
      expect(isOwn || isLicensed, isTrue,
          reason: '$path: neither licensed nor our own (tool/asset_manifest.py LICENSED or OWN, once its licence is checked)');
      expect(listed.containsKey(path), isLicensed && !isOwn,
          reason: '$path: ${isOwn ? 'our own, so not' : 'licensed, so'} in tool/asset_manifest.json (python3 tool/asset_manifest.py)');
    }
    for (final f in files) {
      final path = f['path'] as String, file = File(path);
      expect(licensed.any((g) => g.hasMatch(path)), isTrue, reason: '$path is not licensed');
      expect(file.existsSync(), isTrue, reason: '$path is gone (python3 tool/asset_manifest.py)');
      final head = ByteData.sublistView(file.readAsBytesSync());
      final (w, h) = (head.getUint32(16), head.getUint32(20));
      expect((w, h), (f['width'], f['height']), reason: '$path: its image size');
      if (f['frame'] case [final int fw, final int fh]) {
        expect((w % fw, h % fh, w ~/ fw * (h ~/ fh)), (0, 0, f['frames']), reason: '$path: its grid');
      }
    }
  });

  test('the manifest and assets.sha256 hold every licensed file\'s bytes', () {
    final hashes = File('tool/assets.sha256').readAsLinesSync();
    expect(hashes.map((l) => l.substring(66)), files.map((f) => f['path']), reason: 'the same files, in order');
    for (final (i, f) in files.indexed) {
      final bytes = File(f['path'] as String).readAsBytesSync();
      expect(bytes.length, f['bytes'], reason: '${f['path']}: its size (python3 tool/asset_manifest.py)');
      expect(hashes[i].substring(0, 64), sha256Hex(bytes), reason: '${f['path']}: its sha256 (python3 tool/asset_manifest.py)');
    }
  }, tags: 'art');

  test('the public repo ignores every licensed file: tool/placeholders.gitignore has each licensed pattern', () {
    final lines = [
      for (final l in File('tool/placeholders.gitignore').readAsLinesSync())
        if (l.isNotEmpty && !l.startsWith('#')) l,
    ];
    expect(lines, [for (final p in manifest['licensed'] as List) '/$p']);
  });
}
