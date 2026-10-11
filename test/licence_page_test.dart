import 'dart:io';

import 'package:flame/game.dart' hide Game;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';
import 'package:tower_defense/licences.dart';
import 'package:tower_defense/main.dart';

import 'hud_font.dart';

// The licence files (decisions-log 137) and the book's Lisensi page as the player gets it: one TdGame (its own
// file: a second TdGame in one file breaks the shared image cache, docs/testing.md). A test binding reads no
// NOTICES, so the page's packages here are only the native libraries the game adds (licences.dart).

/// Advances the game [n] frames.
Future<void> frames(WidgetTester tester, [int n = 2]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

/// The left page's line for credit [c], as licence_page.dart writes it.
String creditLine(Credit c) => '${c.role}: ${c.work}, oleh ${c.by} (${c.link})';

void main() {
  test('the native libraries the game registers are part 2 of THIRD_PARTY_NOTICES.txt, word for word', () {
    final notices = File('THIRD_PARTY_NOTICES.txt').readAsStringSync();
    final names = {for (final (packages, _) in nativeLicences) ...packages};
    expect(names, containsAll(['SoLoud', 'miniaudio', 'dr_libs', 'pffft', 'libogg', 'libvorbis', 'libopus', 'libFLAC']));
    for (final (packages, text) in nativeLicences) {
      expect(notices, contains('${packages.join('\n')}\n\n$text\n${'-' * 80}'), reason: packages.join(', '));
    }
    // Part 3 is the game's font with its licence file as it is bundled (the Lisensi page registers the same file):
    // Poh Sans's, what was changed and from what, then Pixelify Sans's licence with a copyright line for the change.
    expect([for (final (_, file) in fontLicences) file], ['assets/fonts/OFL-PohSans.txt']);
    final ofl = [
      for (final (_, file) in fontLicences) File(file).readAsStringSync().replaceAll('\r\n', '\n').trim(), // CRLF, as google/fonts'
    ];
    final source = File('tool/fonts/OFL-PixelifySans.txt').readAsStringSync().replaceAll('\r\n', '\n').trim();
    expect(source, allOf(startsWith('Copyright 2021 The Pixelify Sans Project Authors'), contains('SIL OPEN FONT LICENSE Version 1.1')));
    expect(ofl[0], allOf(startsWith('Poh Sans (assets/fonts/PohSans.ttf) is a Modified Version of Pixelify Sans'),
        contains('What was changed, and from what'), contains('Copyright 2021 The Pixelify Sans Project Authors'), endsWith(source.split('\n').last)));
    expect(ofl[0].replaceFirst(RegExp(r'^[\s\S]*?\n\nCopyright 2021'), 'Copyright 2021').replaceFirst('\nCopyright 2026 Trias BYM (the redrawn glyphs)', ''),
        source, reason: "Poh Sans's licence is Pixelify Sans's word for word after its own lines");
    expect(notices, contains('PART 3. THE FONTS\n\n${'-' * 80}\n'
        '${[for (final (i, (names, _)) in fontLicences.indexed) '${names.join('\n')}\n\n${ofl[i]}\n${'-' * 80}'].join('\n')}'));
    // Part 1 has the packages pubspec.yaml names, with their own licences.
    for (final package in ['flutter', 'flame', 'flutter_soloud', 'path_provider']) {
      expect(notices, contains(RegExp('^  $package +\\S', multiLine: true)), reason: package);
    }
  });

  test('CREDITS.md credits every pack the Lisensi page does, with its author and page; nothing names an open licence', () {
    final md = File('CREDITS.md').readAsStringSync();
    for (final c in credits) {
      expect(md, allOf(contains(c.work), contains(c.by), contains('https://${c.link}/')), reason: c.work);
    }
    // Source-available, never called by an open licence model's name (the release plan, OSD #1): only LICENSE
    // says what it is not. The phrase is built from two halves, so the public export's scan (scripts/export_public.py,
    // which allows it only in LICENSE) doesn't find it in this file.
    const banned = 'open' ' source';
    for (final text in [md, File('README.md').readAsStringSync(), ...licenceSummary, ownWork, madeWith]) {
      expect(text.toLowerCase(), isNot(contains(banned)));
    }
    expect(File('LICENSE').readAsStringSync(), startsWith('# Path of Hero License\n\nCopyright (c) 2026 Trias BYM.'));
  });

  testWidgets('"Lisensi" on Pengaturan opens the licence and credits, the package licences, one package, and goes back',
      (tester) async {
    tester.view
      ..physicalSize = const Size(1266, 713)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await loadHudFont(tester);
    final game = TdGame();
    await tester.pumpWidget(GameWidget(game: game));
    for (var i = 0; i < 3000 && !game.isLoaded; i++) {
      // onLoad decodes images in real time: let it run, then pump.
      await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 20)));
      await tester.pump();
    }
    expect(game.isLoaded, isTrue);
    final b = game.board..welcome = null;
    b.state = Game();
    await frames(tester);
    Future<void> tap(Rect r) async {
      expect(r, isNot(Rect.zero));
      await tester.tapAt(r.center);
      await frames(tester, 5); // past the tap's own timer
    }

    expect(b.licenceButton, Rect.zero); // the troops' page
    b.showSettings();
    await frames(tester, 40); // the book is open between waves
    await tap(b.licenceButton);
    expect((b.licenceShown, b.sendButton), (true, Rect.zero));

    // The left page: the game's licence in short, then the credits; the wheel scrolls it to the end.
    expect(b.licenceLeft.take(2), ['Path of Hero', licenceSummary.first]);
    final seen = {...b.licenceLeft};
    final mouse = TestPointer(1, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(mouse.hover(b.licenceColumns[0].center));
    for (var i = 0; i < 5; i++) {
      await tester.sendEventToBinding(mouse.scroll(const Offset(0, 120)));
      await frames(tester);
      seen.addAll(b.licenceLeft);
    }
    expect(seen, containsAll([...licenceSummary, 'Kredit', ...credits.map(creditLine), ownWork, madeWith]));

    // The right page: the packages in the registry, by name, a row each.
    for (var i = 0; i < 100 && b.licenceRows.isEmpty; i++) {
      await frames(tester, 1);
    }
    final rows = {for (final (name, r) in b.licenceRows) name: r};
    expect(rows.keys, containsAll(['dr_libs', 'libFLAC', 'libogg', 'libopus', 'libvorbis', 'miniaudio', 'Poh Sans', 'SoLoud']));
    expect(rows.keys.toList(), [...rows.keys]..sort((x, y) => x.toLowerCase().compareTo(y.toLowerCase())));

    // A package's row shows its licences (SoLoud has two); "Semua paket" goes back to the list.
    await tap(rows['SoLoud']!);
    expect(b.licencePackage, 'SoLoud');
    expect(b.licenceRight, anyElement(contains('Copyright (c) 2013-2018 Jari Komppa'))); // a paragraph's lines are joined
    expect(b.licenceRows, isEmpty);
    await tap(b.licenceAll);
    expect((b.licencePackage, b.licenceRows.isNotEmpty), (null, true));

    // The font's row shows its licence, read from the file bundled beside the font: what was changed first, then the
    // OFL, which the wheel over the column brings up as a player reads down to it (the shorter landscape book,
    // decisions-log 283, shows only what was changed at first).
    await tap({for (final (name, r) in b.licenceRows) name: r}['Poh Sans']!);
    expect(b.licencePackage, 'Poh Sans');
    expect(b.licenceRight.first, contains('Modified Version of Pixelify'), reason: 'what was changed first');
    final read = [...b.licenceRight];
    await tester.sendEventToBinding(mouse.hover(b.licenceColumns[1].center));
    for (var i = 0; i < 20 && !read.any((t) => t.contains('SIL OPEN FONT LICENSE Version 1.1')); i++) {
      await tester.sendEventToBinding(mouse.scroll(const Offset(0, 120)));
      await frames(tester);
      read.addAll(b.licenceRight);
    }
    expect(read, allOf(anyElement(contains('Modified Version of Pixelify')), anyElement(contains('SIL OPEN FONT LICENSE Version 1.1'))));
    await tap(b.licenceAll);

    // "Kembali" turns back to Pengaturan.
    await tap(b.licenceBack);
    expect(b.licenceShown, isFalse);
    expect(b.sendButton, isNot(Rect.zero));
  });
}
