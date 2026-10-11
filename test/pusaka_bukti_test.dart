// The Pusaka seen (P2 "Bukti", decisions-log 149; lib/pusaka_look.dart, ui-hud.md "The Pusaka in battle"): the Grail's
// save in the log and its cut-in once a wave, the relics a fall sends back, a won wave's report and its best counter on
// "VICTORY!" in one line that fits a phone, the build names; every glyph in the HUD's font. One TdGame (its own file: a
// second TdGame in one file breaks the shared image cache, docs/testing.md). The rules themselves: pusaka_test.dart.
import 'dart:math';

import 'package:flame/game.dart' hide Game;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';
import 'package:tower_defense/main.dart';

import 'hero_skill_helpers.dart';
import 'hud_font.dart';

/// A game with no skills cast, so what happens is the Pusaka's doing.
Game plain() => bareGame()
  ..skills = false
  ..heroSkills = false
  ..awakenSkills = false;

/// Lets [foe] strike once now (then it stands again).
void strikeBy(Game g, Unit foe) {
  foe
    ..busyUntil = double.negativeInfinity
    ..cd = 0;
  g.tick(0.05);
  foe.busyUntil = hold;
}

/// [u] at 1 HP takes [foe]'s blow: the Grail saves it, if its type has one left.
void killingBlow(Game g, Unit foe, Unit u) {
  foe.pos = u.pos + const Point(12, 0);
  u.hp = 1;
  strikeBy(g, foe);
}

/// A won wave's report as [Game] makes one ([PusakaReport]): the Pusaka [lines] as (relic, type, uses, worth).
PusakaReport report(List<(Relic, String, int, double)> lines, [Map<Relic, int> back = const {}]) => PusakaReport(90, 1,
    lines: [for (final (r, type, uses, worth) in lines) (relic: r, type: type, stars: 1, uses: uses, worth: worth)], returned: back);

/// Advances the game [n] frames.
Future<void> frames(WidgetTester tester, [int n = 2]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

void main() {
  group('the game tells', () {
    test('every Grail save is logged; the first of a wave, and only it, waits for the cut-in, wave after wave', () {
      final g = plain();
      final a = placeNow(g, 'soldier', 2, 3), b = placeNow(g, 'soldier', 2, 5), c = placeNow(g, 'soldier', 2, 7);
      for (final u in [a, b, c]) {
        u.busyUntil = hold;
      }
      g
        ..givePusaka(Relic.grail, type: 'soldier')
        ..startWave()
        ..queue.clear();
      final orc = foeAt(g, 'orc', a.pos + const Point(12, 0));
      killingBlow(g, orc, a);
      expect((a.alive, g.grailFirst), (true, a));
      g.grailFirst = null; // the UI took it
      killingBlow(g, orc, b);
      killingBlow(g, orc, c);
      expect((b.alive, c.alive, g.grailFirst), (true, true, null)); // saved, but no second cut-in this wave
      final saves = g.log.entries.whereType<GrailSaved>().toList();
      expect([for (final e in saves) (e.name, e.type, e.wave)], [(a.name, 'soldier', 1), (b.name, 'soldier', 1), (c.name, 'soldier', 1)]);
      expect(logLine(saves.first), 'Grail saves ${a.name} (${troopTypeNames['soldier']})');
      // The next wave's first save waits again.
      orc.gone = true; // off the field: the wave is won
      for (var n = 0; n < 100 && g.waveActive; n++) {
        g.tick(0.05);
      }
      g
        ..startWave()
        ..queue.clear();
      final orc2 = foeAt(g, 'orc', b.pos + const Point(12, 0));
      killingBlow(g, orc2, b);
      expect((b.alive, g.grailFirst), (true, b));
    });

    test("a fall's relics come back in its log rows and in the wave's count; a new wave counts afresh", () {
      final g = plain();
      final u = placeNow(g, 'knight', 2, 3)..busyUntil = hold, v = placeNow(g, 'knight', 2, 5)..busyUntil = hold;
      placeNow(g, 'soldier', 1, 7).busyUntil = hold; // someone lives on, so the wave can be won
      g.relicBag
        ..[Relic.fury] = 2
        ..[Relic.fang] = 1;
      g
        ..useRelic(Relic.fury, u)
        ..useRelic(Relic.fury, v)
        ..startWave()
        ..queue.clear();
      final orc = foeAt(g, 'orc', u.pos + const Point(12, 0));
      killingBlow(g, orc, u);
      killingBlow(g, orc, v);
      final fell = g.log.entries.whereType<TroopFell>().first;
      expect(logLines(fell), [logLine(fell), '${relicNames[Relic.fury]} back in the Bag']);
      expect(g.relicsBack, {Relic.fury: 2});
      orc.gone = true; // off the field: the wave is won
      for (var n = 0; n < 100 && g.waveActive; n++) {
        g.tick(0.05);
      }
      expect(g.waveActive, isFalse);
      expect(g.lastPusaka?.returned, {Relic.fury: 2}); // maps one by one: in a record they compare by identity
      expect(g.relicsBack, {Relic.fury: 2});
      g.startWave(); // a wave's count is its own
      expect(g.relicsBack, isEmpty);
    });

    test('a won wave reports each bound Pusaka and the relics back, right before its win; nothing to tell, no report', () {
      final g = plain();
      final k = placeNow(g, 'knight', 2, 3), s = placeNow(g, 'soldier', 2, 5)..busyUntil = hold;
      g.relicBag[Relic.guard] = 1;
      g
        ..useRelic(Relic.guard, s)
        ..givePusaka(Relic.godThunder, type: 'knight', stars: 2)
        ..givePusaka(Relic.grail, type: 'priest') // none lives: in the report with nothing done
        ..givePusaka(Relic.voidEye) // in the Gudang: not in it
        ..startWave()
        ..queue.clear();
      final orc = foeAt(g, 'orc', s.pos + const Point(12, 0));
      killingBlow(g, orc, s);
      orc.gone = true; // off the field: the wave is won
      foeAt(g, 'orc', k.pos + const Point(14, 0)).hp = 30;
      foeAt(g, 'orc', k.pos + const Point(26, 0)).hp = 3;
      for (var n = 0; n < 200 && g.waveActive; n++) {
        g.tick(0.05);
      }
      expect(g.waveActive, isFalse);
      final r = g.lastPusaka!;
      expect([for (final d in r.lines) (d.relic, d.type, d.stars, d.uses, d.worth)],
          [(Relic.godThunder, 'knight', 2, 0, 3.0), (Relic.grail, 'priest', 1, 0, 0.0)]); // the leap took the 3 HP the other had
      expect(r.returned, {Relic.guard: 1});
      final tail = g.log.entries.reversed.take(2).toList();
      expect((tail[0] is WaveEnded, identical(tail[1], r)), (true, true)); // newest first: the win, then its report
      expect(logLines(r), ["God's Thunder (${troopTypeNames['knight']}): +3 damage", 'Grail (${troopTypeNames['priest']}): 0 saves, 0 lived', 'Back to Bag: ${relicNames[Relic.guard]}']);
      expect(pusakaWinLine(r), "Artifact: God's Thunder +3 · Back to Bag: ${relicNames[Relic.guard]}");
      // A wave with no Pusaka bound and no relic back has nothing to tell.
      final h = plain();
      placeNow(h, 'knight', 2, 3);
      h
        ..startWave()
        ..queue.clear();
      foeAt(h, 'orc', h.troops.first.pos + const Point(14, 0)).hp = 3;
      for (var n = 0; n < 200 && h.waveActive; n++) {
        h.tick(0.05);
      }
      expect((h.waveActive, h.lastPusaka), (false, null));
      expect(h.log.entries.whereType<PusakaReport>(), isEmpty);
    });

    test('the best counter: troops kept alive first (the Grail on a tie), else the most damage or healing added', () {
      expect(report([(Relic.godThunder, 'wizard', 0, 50000), (Relic.grail, 'armored_axeman', 6, 4), (Relic.dragonHeart, 'knight_templar', 0, 3)]).best?.relic,
          Relic.grail);
      expect(report([(Relic.grail, 'armored_axeman', 6, 2), (Relic.dragonHeart, 'knight_templar', 0, 5)]).best?.relic, Relic.dragonHeart);
      expect(report([(Relic.dragonHeart, 'knight_templar', 0, 3), (Relic.grail, 'armored_axeman', 3, 3)]).best?.relic, Relic.grail);
      expect(report([(Relic.grail, 'armored_axeman', 2, 0), (Relic.dawnStar, 'priest', 0, 900), (Relic.voidEye, 'archer', 0, 1200)]).best?.relic,
          Relic.voidEye); // its saves all fell later: no kept one
      expect(report([(Relic.grail, 'armored_axeman', 0, 0), (Relic.dawnStar, 'priest', 0, 0)]).best, isNull);
    });

    test('a build name for each Pusaka: the type and its epithet; none unbound', () {
      // Every Pusaka but an oath has its own epithet (the catalog's rows: pusaka_catalog_test.dart); today's twelve:
      final epithets = [for (final r in Relic.values) if (r.pusaka && !r.oath) buildEpithets[r]];
      expect((epithets.contains(null), epithets.toSet().length), (false, epithets.length));
      expect([for (final r in Relic.values) if (r.oath) buildEpithets[r]], everyElement(isNull));
      const today = [Relic.dragonHeart, Relic.dawnStar, Relic.godThunder, Relic.grail, Relic.voidEye, Relic.ironBanner, Relic.bloodFang, //
        Relic.warDrum, Relic.mourningBell, Relic.dragonCrown, Relic.oathOfOne, Relic.alliance];
      expect({for (final r in today) r: buildEpithets[r]}, {
        Relic.dragonHeart: 'Giant',
        Relic.dawnStar: 'Dawn',
        Relic.godThunder: 'Storm',
        Relic.grail: 'Undying',
        Relic.voidEye: 'Void',
        Relic.ironBanner: 'Steel', // the chest's Langka (draft.dart)
        Relic.bloodFang: 'Blood',
        Relic.warDrum: 'War',
        Relic.mourningBell: 'Mourning',
        Relic.dragonCrown: 'Crowned', // the Legenda (legenda_test.dart); the oaths name no type
        Relic.oathOfOne: null,
        Relic.alliance: null,
      });
      final g = plain();
      expect(g.buildNameOf('knight_templar'), isNull);
      final names = <String>[];
      const bound = [
        (Relic.grail, 'knight_templar'),
        (Relic.dragonHeart, 'knight_templar'),
        (Relic.godThunder, 'wizard'),
        (Relic.dawnStar, 'priest'),
        (Relic.voidEye, 'archer'),
      ];
      for (final (r, type) in bound) {
        g.givePusaka(r, type: type);
        names.add(g.buildNameOf(type)!);
      }
      // The epithet first, as English puts an adjective (ui-hud.md "In-game text").
      expect(names, [for (final (r, type) in bound) '${buildEpithets[r]} ${troopTypeNames[type]}']);
      expect(names.first, 'Undying Templar');
      g.givePusaka(Relic.voidEye); // to the Gudang
      expect(g.buildNameOf('archer'), isNull);
    });
  });

  test('the VICTORY! line: the best counter, the relics back (most first, past two kinds "+n"), either alone, none', () {
    expect(pusakaWinLine(report([(Relic.grail, 'armored_axeman', 7, 6)], {Relic.fury: 2})), 'Artifact: Grail 6 saved · Back to Bag: ${relicNames[Relic.fury]} ×2');
    expect(pusakaWinLine(report([(Relic.dragonHeart, 'knight_templar', 0, 4)])), 'Artifact: Dragon Heart 4 hits lived');
    expect(pusakaWinLine(report([(Relic.dawnStar, 'priest', 0, 12345)])), 'Artifact: Dawn Star +12.3k');
    // The counts in English: one hit, one toll.
    expect(pusakaWinLine(report([(Relic.dragonHeart, 'knight_templar', 0, 1)])), 'Artifact: Dragon Heart 1 hit lived');
    expect(logLines(report([(Relic.mourningBell, 'priest', 1, 3200), (Relic.mourningBell, 'knight', 3, 3200), (Relic.grail, 'knight', 1, 1)])), [
      'Mourning Bell (${troopTypeNames['priest']}): rang once, +3.2k HP',
      'Mourning Bell (${troopTypeNames['knight']}): rang 3 times, +3.2k HP',
      'Grail (${troopTypeNames['knight']}): 1 save, 1 lived',
    ]);
    expect([for (final v in [940.0, 1234.0, 32049.0, 150400.0]) pusakaCounter((relic: Relic.godThunder, type: 'wizard', stars: 1, uses: 0, worth: v))],
        ['+940', '+1.2k', '+32k', '+150k']);
    expect(pusakaWinLine(report([(Relic.voidEye, 'archer', 0, 0)], {Relic.fang: 1, Relic.guard: 3, Relic.fury: 1, Relic.thorns: 2})),
        'Back to Bag: ${relicNames[Relic.guard]} ×3, ${relicNames[Relic.thorns]} ×2, +2');
    expect(pusakaWinLine(report([(Relic.voidEye, 'archer', 0, 0)])), isNull);
    expect(logLines(report([], {Relic.fang: 1, Relic.guard: 3, Relic.fury: 1})), ['Back to Bag: ${relicNames[Relic.guard]} ×3, ${relicNames[Relic.fang]}, ${relicNames[Relic.fury]}']);
  });

  test("every line the Pusaka show is in the HUD's font: no '★' or '→'", () {
    final font = fontChars();
    final g = plain()..givePusaka(Relic.grail, type: 'knight_templar');
    final lines = [
      pusakaWinLine(report([(Relic.grail, 'armored_axeman', 7, 6), (Relic.godThunder, 'wizard', 0, 1)], {Relic.fury: 2, Relic.fang: 1, Relic.guard: 1}))!,
      ...logLines(report([
        for (final r in Relic.values)
          if (r.pusaka) (r, 'armored_axeman', 3, 2500.0),
      ], {for (final r in droppedRelics) r: 2})),
      logLine(GrailSaved(1, 0, name: 'Kael Drake', type: 'knight_templar', hero: true)),
      for (final type in troopTypes.keys)
        for (final r in Relic.values)
          if (r.pusaka) '${troopTypeNames[type]} ${buildEpithets[r]}',
      g.buildNameOf('knight_templar')!,
      'Grail saves Kael Drake!',
    ];
    for (final line in lines) {
      expect([for (final ch in line.runes) if (!font.contains(ch)) String.fromCharCode(ch)], isEmpty, reason: line);
    }
  });

  testWidgets('on screen: the VICTORY! line fits a phone, the Grail cut-in shows once a wave, the build name sits on the row',
      (tester) async {
    tester.view
      ..physicalSize = const Size(915, 412)
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
    final b = game.board
      ..welcome = null
      ..miniMapOpen = false;

    // VICTORY!: one line, the best counter named; it fits 361 px at every size, at 14 px or more for the design's
    // example, and a long one shrinks or is cut rather than run over.
    for (final size in const [Size(915, 412), Size(1266, 713)]) {
      tester.view.physicalSize = size;
      for (final (r, line) in [
        (report([(Relic.grail, 'armored_axeman', 7, 6)], {Relic.fury: 2}), 'Artifact: Grail 6 saved · Back to Bag: ${relicNames[Relic.fury]} ×2'),
        (report([(Relic.dragonHeart, 'knight_templar', 0, 128)], {Relic.guard: 12, Relic.thorns: 11, Relic.fang: 9, Relic.fury: 8}), null),
      ]) {
        final g = b.state = Game()..lastPusaka = r;
        await frames(tester, 2);
        final shown = b.winPusakaLine!;
        expect(shown.width, lessThanOrEqualTo(winLineMaxW), reason: '$size ${shown.text}');
        if (line != null) expect((shown.text, shown.size >= 14), (line, true), reason: '$size');
        expect(g.over, isFalse);
      }
    }
    tester.view.physicalSize = const Size(915, 412);

    // The Grail's cut-in: on the wave's first save only, however many follow; the next wave's first shows again.
    // Drawn units stand still by stunUntil: busyUntil would draw a rising strip (plates_test.dart).
    final g = b.state = plain()..givePusaka(Relic.grail, type: 'soldier');
    final a = placeNow(g, 'soldier', 2, 3), s2 = placeNow(g, 'soldier', 2, 5), s3 = placeNow(g, 'soldier', 2, 7);
    for (final u in [a, s2, s3]) {
      u.stunUntil = hold;
    }
    g
      ..startWave()
      ..queue.clear();
    final orc = foeAt(g, 'orc', a.pos + const Point(12, 0))
      ..busyUntil = double.negativeInfinity
      ..stunUntil = hold;
    void blow(Unit u) {
      orc
        ..pos = u.pos + const Point(12, 0)
        ..stunUntil = double.negativeInfinity
        ..cd = 0;
      u.hp = 1;
      g.tick(0.05);
      orc.stunUntil = hold;
    }

    await frames(tester, 2);
    expect(b.grailCutIn, isNull);
    blow(a);
    await frames(tester, 2);
    expect((a.alive, b.grailCutIn), (true, 'Grail saves ${a.name}!'));
    blow(s2);
    await frames(tester, (grailCutTime / 0.016).ceil() + 5); // the first runs its time out
    expect((s2.alive, b.grailCutIn), (true, null));
    blow(s3);
    await frames(tester, 3);
    expect((s3.alive, b.grailCutIn), (true, null)); // a third save, no second cut-in
    expect(g.log.entries.whereType<GrailSaved>().length, 3);

    // The build name on the Army page: in the picked type's heading on the right page (the soldier, the first type alive),
    // none for a type without a Pusaka.
    g.typeCap = typeCapBoard;
    orc.gone = true; // off the field: the wave is won
    for (var n = 0; n < 200 && g.waveActive; n++) {
      await frames(tester, 1);
    }
    expect(g.waveActive, isFalse);
    await frames(tester, 60);
    for (var n = 0; n < 600 && b.bookArea == Rect.zero; n++) {
      await frames(tester, 1); // the book floats in after the win's cheer
    }
    await frames(tester, 40);
    expect(b.troopPicked, 'soldier');
    final (name, at) = b.rowBuildName('soldier')!;
    expect(name, '${buildEpithets[Relic.grail]} ${troopTypeNames['soldier']}');
    expect(at.left, greaterThan(b.troopRow('soldier').right)); // right of the list
    expect(at.right, lessThanOrEqualTo(915)); // on the screen
    await tester.tapAt(b.troopRow('knight').center);
    await frames(tester, 2);
    expect((b.troopPicked, b.rowBuildName('knight')), ('knight', null)); // no Pusaka
    await frames(tester, 30); // past the tap's own timer
  });
}
