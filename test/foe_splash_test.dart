// A monster skill's first-sighting splash (lib/foe_splash.dart, champion-fx Part 4; docs/ui-hud.md "Foe splash") and
// its words (lib/monster_skill_texts.dart): the field stands still under it (no tick, no "Pause", the banners and cut-ins
// waiting); a tap, Esc or P closes it and does nothing else; a skill seen never splashes again (settings.json's seen
// set); none with no seen set or "Sorotan Musuh" off; one a wave, a boss's moment always; none while a guide card, a
// pause or another page is up, and the next cast tries again; every skill's splash fits a desk (1266x713) and a phone
// (915x412), its text in two lines; every number in the texts is its constant's; and the fight is the same with
// splashes on and off. One TdGame per widget test; settings.json goes to the test file's temp dir
// (flutter_test_config.dart).
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flame/game.dart' hide Game;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/cut_ins.dart';
import 'package:tower_defense/game.dart';
import 'package:tower_defense/guide_text.dart' show guideEn;
import 'package:tower_defense/hud_font.dart';
import 'package:tower_defense/main.dart';
import 'package:tower_defense/monster_skill_texts.dart';
import 'package:tower_defense/settings.dart';

import 'hud_font.dart';

/// Boots one TdGame in a [w]x[h] window and returns its board, past the welcome screen, with the game's font and the
/// minimap folded.
Future<Board> boot(WidgetTester tester, [double w = 1266, double h = 713]) async {
  tester.view
    ..physicalSize = Size(w, h)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await loadHudFont(tester);
  final game = TdGame();
  await tester.pumpWidget(GameWidget(game: game));
  for (var i = 0; i < 3000 && !game.isLoaded; i++) {
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 20)));
    await tester.pump();
  }
  expect(game.isLoaded, isTrue);
  return game.board
    ..welcome = null
    ..miniMapOpen = false;
}

/// Advances the game [n] frames of [ms] each.
Future<void> frames(WidgetTester tester, [int n = 2, int ms = 16]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(Duration(milliseconds: ms));
  }
}

/// The frames a splash shows at most, at 16 ms each, and two more.
final splashFrames = (foeSplashTime * 1000 / 16).ceil() + 2;

/// A monster of [type] and [tier] in [g] winding up [skill]: the Board drains it next frame.
Unit casts(Game g, String type, Tier tier, MonsterSkill skill, [Point<double> at = const Point(120.0, 60.0)]) {
  final u = g.monster(type, tier, at);
  g.monsterCasts.add((u, skill));
  return u;
}

/// A board game between waves with gold to spare and no army limit.
Game boardGame([int wave = 0]) => Game(Random(1)).boardRules()
  ..armyMax = null
  ..gold = 200000
  ..wave = wave;

/// The ranks a skill's caster may have (foe_cut_in_test.dart's).
List<Tier> ranksOf(MonsterSkill s) => switch (s.rank) {
      MonsterRank.signature => [Tier.highElite, Tier.miniBoss, Tier.boss],
      MonsterRank.miniBoss => [Tier.miniBoss, Tier.boss],
      MonsterRank.moment => [Tier.boss],
    };

/// Turns Pengaturan's "Sorotan Musuh" to [on] (saved in settings.json), then the book back to Pasukan.
Future<void> foeCuts(WidgetTester tester, Board b, bool on) async {
  if (loadSettings().foeCutIns == on) return;
  b.showSettings();
  await frames(tester, 40);
  await tester.tapAt(b.foeCutButton.center);
  await frames(tester, 5);
  await tester.tapAt(b.bookTabs.firstWhere((t) => t.$1 == 'troops').$2.center);
  await frames(tester, 5);
  expect((loadSettings().foeCutIns, b.storeShown, b.sendButton), (on, false, Rect.zero));
}

/// The numbers each skill's line holds, from its constants (in its order); none for the rest. A number differing by
/// rank (a mini boss's stronger War Shout) is in no line.
final expectedNumbers = <MonsterSkill, List<num>>{
  MonsterSkill.warShout: [warShoutK.time],
  MonsterSkill.shieldUp: [shieldUpK.time],
  MonsterSkill.bulwark: [bulwarkK.cut * 100],
  MonsterSkill.curseOfFrailty: [curseOfFrailtyK.time],
  MonsterSkill.split: [splitK.slimes],
  MonsterSkill.screech: [(1 - 1 / screechK.pause) * 100, screechK.time],
  MonsterSkill.boneShield: [boneShieldK.cut * 100, boneShieldK.time],
  MonsterSkill.frenzy: [(1 / frenzyK.pause - 1) * 100, frenzyK.time],
  MonsterSkill.bloodrage: [bloodrageK.share * 100, bloodrageK.time],
  MonsterSkill.soulRend: [soulRendK.time, soulRendK.mp],
  MonsterSkill.thickHide: [thickHideK.cut * 100, thickHideK.time],
  MonsterSkill.soulDrain: [soulDrainK.time],
  MonsterSkill.unholyWard: [unholyWardK.time],
  MonsterSkill.slimeTide: [(1 - slimeTideK.slow) * 100, slimeTideK.time],
  MonsterSkill.swarm: [swarmK.bats],
  MonsterSkill.graveCall: [graveCallK.most],
  MonsterSkill.rally: [(rallyK.might - 1) * 100, (1 / rallyK.pause - 1) * 100, rallyK.time],
  MonsterSkill.boneRain: [boneRainK.time],
  MonsterSkill.howl: [howlK.time],
  MonsterSkill.ironMarch: [ironMarchK.time],
  MonsterSkill.secondWind: [secondWindK.heal * 100],
  MonsterSkill.graveWave: [graveWaveK.length / tile],
  MonsterSkill.roar: [(1 - roarK.dealt) * 100, roarK.time],
  MonsterSkill.lastRites: [lastRitesK.heal * 100],
};

void main() {
  group('the texts', () {
    test('every skill has a line ending in a full stop, every number in it its constant\'s', () {
      for (final s in MonsterSkill.values) {
        final text = monsterSkillText(s), why = '${s.name}: "$text"';
        expect(text.endsWith('.') && text[0] == text[0].toUpperCase(), isTrue, reason: why);
        final numbers = [for (final m in RegExp(r'\d+(\.\d+)?').allMatches(text)) num.parse(m[0]!)];
        expect(numbers, [for (final n in expectedNumbers[s] ?? const <num>[]) (n * 10).round() / 10], reason: why);
      }
    });

    test('no number is written in the file: every one comes from a constant', () {
      final literal = RegExp(r"'(?:[^'\\]|\\.)*'");
      for (final line in File('lib/monster_skill_texts.dart').readAsLinesSync()) {
        if (line.trimLeft().startsWith('//')) continue;
        for (final m in literal.allMatches(line)) {
          final text = m[0]!.replaceAll(RegExp(r'\$\{[^}]*\}'), '');
          expect(RegExp(r'\d').hasMatch(text), isFalse, reason: line);
        }
      }
    });

    test('the hints: how to stop a wind-up, the necromancer only shoved; Reassemble\'s holy damage; none for a boss\'s '
        'cast or a skill that never winds up', () {
      expect(monsterSkillHint(MonsterSkill.warShout, 'orc', Tier.highElite), 'Stun or shove it while it winds up.');
      expect(monsterSkillHint(MonsterSkill.headbutt, 'orc', Tier.miniBoss), 'Stun or shove it while it winds up.');
      expect(monsterSkillHint(MonsterSkill.curseOfFrailty, boss, Tier.highElite), 'Shove it while it winds up.');
      expect(monsterSkillHint(MonsterSkill.massMend, necroHealer, Tier.highElite), 'Stun or shove it while it winds up.');
      expect(monsterSkillHint(MonsterSkill.reassemble, 'skeleton', Tier.highElite), 'Holy damage stops it.');
      for (final s in [MonsterSkill.warShout, MonsterSkill.earthshaker, MonsterSkill.split, MonsterSkill.frenzy, MonsterSkill.thickHide]) {
        expect(monsterSkillHint(s, s.type, s == MonsterSkill.warShout || s == MonsterSkill.earthshaker ? Tier.boss : Tier.miniBoss), isNull,
            reason: s.name);
      }
    });

    test('every glyph is in the HUD\'s font', () {
      final chars = fontChars();
      final all = [
        for (final s in MonsterSkill.values) ...[monsterSkillText(s), s.title],
        for (final s in MonsterSkill.values) for (final r in Tier.values) ?monsterSkillHint(s, s.type, r),
        guideEn.labels.tapOn,
      ];
      for (final t in all) {
        expect(t.runes.where((c) => !chars.contains(c)), isEmpty, reason: t);
      }
    });
  });

  testWidgets('a skill\'s first cast ever freezes the field under its splash: the game\'s clock still, no "Pause", the '
      'music not lowered, the banner it replaces not shown and the one already showing waiting; after its time it closes '
      'and the game goes on', (tester) async {
    final b = await boot(tester)..guideSeen = {'foe.warShout'};
    final g = b.state = boardGame(5);
    await frames(tester, 2);
    casts(g, 'orc', Tier.highElite, MonsterSkill.warShout); // seen: its banner
    await frames(tester, 1);
    expect((b.foeSplash, b.foeCutShowing?.$2), (null, MonsterSkill.warShout));
    casts(g, 'armored_orc', Tier.highElite, MonsterSkill.bulwark, const Point(300.0, 60.0));
    await frames(tester, 1);
    expect(b.foeSplash?.cast.$2, MonsterSkill.bulwark);
    expect((b.foeSplash?.title, b.foeSplash?.line), ('Bulwark', '${tierNames[Tier.highElite]} ${monsterTypeNames['armored_orc']}'));
    expect(b.foeCutsWaiting, isEmpty, reason: 'its splash replaces its banner');
    expect(b.guideSeen, contains(foeSplashKey(MonsterSkill.bulwark)));
    expect(loadSettings().seen, contains('foe.bulwark'));
    final t0 = g.t;
    await frames(tester, splashFrames - 4);
    expect(b.foeSplash, isNotNull);
    expect((g.t, g.paused, b.pauseTitle), (t0, false, Rect.zero));
    expect(b.foeCutShowing?.$2, MonsterSkill.warShout, reason: 'the banner waits with the field: its 1.4 s would be over');
    await frames(tester, 6);
    expect(b.foeSplash, isNull);
    await frames(tester, 2);
    expect(g.t > t0, isTrue);
    await frames(tester, (foeCutTime * 1000 / 16).ceil() + 2);
    expect(b.foeCutShowing, isNull);
  });

  testWidgets('a tap closes the splash and does nothing else: the spawn bar\'s card under it buys nothing; Esc closes it, and '
      'P closes it without pausing', (tester) async {
    final b = await boot(tester)..guideSeen = {};
    final g = b.state = boardGame();
    await frames(tester, 40); // the book floats in
    const type = 'soldier'; // the spawn bar's first card, in view (decisions-log 283)
    final row = b.spawnCard(type), army = g.armySize, gold = g.gold;
    expect(row, isNot(Rect.zero));
    casts(g, 'orc', Tier.highElite, MonsterSkill.warShout);
    await frames(tester, 2);
    expect(b.foeSplash, isNotNull);
    expect(b.spawnCard(type), Rect.zero, reason: 'nothing under it takes a press');
    await tester.tapAt(row.center);
    await frames(tester, 2);
    expect((b.foeSplash, g.armySize, g.gold), (null, army, gold));
    await tester.tapAt(b.spawnCard(type).center);
    await frames(tester, 2);
    expect(g.armySize, army + 1, reason: 'the next tap buys');

    casts(g, 'skeleton_archer', Tier.highElite, MonsterSkill.volley);
    await frames(tester, 2);
    expect(b.foeSplash, isNull, reason: 'one a wave');
    g.wave++;
    casts(g, 'skeleton_archer', Tier.highElite, MonsterSkill.volley);
    await frames(tester, 2);
    expect(b.foeSplash?.cast.$2, MonsterSkill.volley);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await frames(tester, 2);
    expect(b.foeSplash, isNull);
    g.wave++;
    casts(g, 'elite_orc', Tier.highElite, MonsterSkill.brutalSwing);
    await frames(tester, 2);
    expect(b.foeSplash?.cast.$2, MonsterSkill.brutalSwing);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyP);
    await frames(tester, 2);
    expect((b.foeSplash, g.paused), (null, false));
  });

  testWidgets('a skill seen never splashes again, even in a new game; one a wave, a boss\'s moment always, and a skill '
      'turned away splashes on a later cast', (tester) async {
    final b = await boot(tester)..guideSeen = {};
    var g = b.state = boardGame(5);
    await frames(tester, 2);
    casts(g, 'orc', Tier.highElite, MonsterSkill.warShout);
    await frames(tester, 2);
    expect(b.foeSplash?.cast.$2, MonsterSkill.warShout);
    await tester.tapAt(const Offset(4, 700));
    await frames(tester, 2);
    casts(g, 'skeleton_archer', Tier.highElite, MonsterSkill.volley);
    await frames(tester, 2);
    expect((b.foeSplash, b.foeCutShowing?.$2), (null, MonsterSkill.volley), reason: 'the wave has had its splash: a banner');
    expect(b.guideSeen, isNot(contains('foe.volley')));
    casts(g, 'armored_orc', Tier.boss, MonsterSkill.earthshaker);
    await frames(tester, 2);
    expect((b.foeSplash?.cast.$2, b.foeSplash?.cast.$3, b.foeSplash?.hint), (MonsterSkill.earthshaker, Tier.boss, null),
        reason: 'a boss\'s moment always');
    await tester.tapAt(const Offset(4, 700));
    await frames(tester, 2);
    g.wave = 6;
    casts(g, 'skeleton_archer', Tier.miniBoss, MonsterSkill.volley);
    await frames(tester, 2);
    expect((b.foeSplash?.cast.$2, b.foeSplash?.line), (MonsterSkill.volley, '${tierNames[Tier.miniBoss]} ${monsterTypeNames['skeleton_archer']}'));
    await tester.tapAt(const Offset(4, 700));
    await frames(tester, 2);
    // A new game: what was seen stays seen.
    g = b.state = boardGame(9);
    await frames(tester, 2);
    for (final (type, tier, s) in [
      ('orc', Tier.highElite, MonsterSkill.warShout),
      ('skeleton_archer', Tier.highElite, MonsterSkill.volley),
      ('armored_orc', Tier.boss, MonsterSkill.earthshaker),
    ]) {
      casts(g, type, tier, s);
      await frames(tester, 2);
      expect(b.foeSplash, isNull, reason: s.name);
    }
    expect(loadSettings().seen, containsAll(['foe.warShout', 'foe.volley', 'foe.earthshaker']));
  });

  testWidgets('none with no seen set (a widget test\'s board) or with "Sorotan Musuh" off', (tester) async {
    final b = await boot(tester)..guideSeen = null;
    final g = b.state = boardGame(5);
    await frames(tester, 2);
    casts(g, 'orc', Tier.highElite, MonsterSkill.warShout);
    await frames(tester, 2);
    expect((b.foeSplash, b.foeCutShowing?.$2), (null, MonsterSkill.warShout));
    b.guideSeen = {};
    await foeCuts(tester, b, false);
    casts(g, 'armored_orc', Tier.highElite, MonsterSkill.bulwark);
    await frames(tester, 2);
    expect(b.foeSplash, isNull);
    expect(b.guideSeen, isEmpty);
    await foeCuts(tester, b, true);
    casts(g, 'armored_orc', Tier.highElite, MonsterSkill.bulwark);
    await frames(tester, 2);
    expect(b.foeSplash?.cast.$2, MonsterSkill.bulwark);
  });

  testWidgets('none while a guide card shows, the game is paused or the book is on another page; the skill\'s next cast '
      'tries again', (tester) async {
    final b = await boot(tester)..guideSeen = {};
    final g = b.state = boardGame(5);
    await frames(tester, 40);
    b.openGuide('K1');
    await frames(tester, 2);
    casts(g, 'orc', Tier.highElite, MonsterSkill.warShout);
    await frames(tester, 2);
    expect((b.coachCard?.$1, b.foeSplash), ('K1', null));
    await tester.sendKeyEvent(LogicalKeyboardKey.escape); // the card closes
    await frames(tester, 2);
    expect(b.coachCard, isNull);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyP);
    await frames(tester, 2);
    expect(g.paused, isTrue);
    casts(g, 'orc', Tier.highElite, MonsterSkill.warShout);
    await frames(tester, 2);
    expect(b.foeSplash, isNull);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyP);
    await frames(tester, 2);
    b.showSettings();
    await frames(tester, 2);
    casts(g, 'orc', Tier.highElite, MonsterSkill.warShout);
    await frames(tester, 2);
    expect(b.foeSplash, isNull);
    await tester.tapAt(b.bookTabs.firstWhere((t) => t.$1 == 'troops').$2.center);
    await frames(tester, 2);
    expect(b.guideSeen!.where((k) => k.startsWith('foe.')), isEmpty, reason: 'turned away three times: still unseen');
    casts(g, 'orc', Tier.highElite, MonsterSkill.warShout);
    await frames(tester, 2);
    expect(b.foeSplash?.cast.$2, MonsterSkill.warShout);
    // While it shows no guide card opens over it (a one-time card waits for it: coach.dart).
    expect(b.coachCard, isNull);
  });

  for (final (w, h) in [(1266.0, 713.0), (915.0, 412.0)]) {
    testWidgets('every skill\'s splash fits at every rank it is cast at: its title whole at 11 px at least, its text in two '
        'lines, its hint whole, the panel inside the screen, away from the caster (${w.round()}x${h.round()})', (tester) async {
      final b = await boot(tester, w, h);
      for (final s in MonsterSkill.values) {
        for (final rank in ranksOf(s)) {
          b.guideSeen = {};
          final g = b.state = boardGame(5); // a new game: none showing, the wave's count afresh
          await frames(tester, 1);
          final u = casts(g, s.type, rank, s, Point(g.cam + 40, 60));
          await frames(tester, 1);
          final f = b.foeSplash, why = '${s.name} ${rank.name} at ${w}x$h: ${f?.lines} ${f?.panel}';
          expect(f, isNotNull, reason: why);
          expect((f!.title, f.line, f.hint), (s.title, foeCutLine(u, rank), monsterSkillHint(s, s.type, rank)), reason: why);
          expect(f.titleSize >= 11 && f.textSize >= 12, isTrue, reason: why);
          expect(f.lines.length <= 2 && f.lines.join(' ') == monsterSkillText(s), isTrue, reason: why);
          for (final l in f.lines) {
            expect(TextPaint(style: hudStyle(f.textSize)).getLineMetrics(l).width <= f.textRoom, isTrue, reason: '$why: "$l"');
          }
          final p = f.panel;
          expect(p.left >= 0 && p.top >= 0 && p.right <= w && p.bottom <= h, isTrue, reason: why);
          expect(p.left > b.toScreen(u.pos.x, 0).dx, isTrue, reason: '$why: the caster stands at the left');
        }
      }
    });
  }

  testWidgets('the splashes change nothing in the fight: the owner\'s wave-86 save plays its next wave the same with them '
      'on and off', (tester) async {
    final b = await boot(tester);
    final save = jsonDecode(File('test/fixtures/save-20261001-2005-pre-awaken.json').readAsStringSync()) as Map<String, dynamic>;
    String digest(Game g) => [
          't ${g.t} gold ${g.gold} lives ${g.lives} kills ${g.kills} score ${g.score}',
          for (final u in g.units) '${u.side.name} ${u.type} ${u.tier.name} ${u.alive} ${u.hp} ${u.mp} ${u.pos.x},${u.pos.y}',
        ].join('\n');
    // The same steps both ways: a new game, the save loaded and left to settle (the book's float in and out), its wave
    // started and played at 0.2 s a tick to the same game time.
    Future<(String, Set<MonsterSkill>, int)> run(bool on) async {
      b.guideSeen = on ? {} : null;
      b.state = Game();
      await frames(tester, 2);
      final g = b.state = Game.fromJson(save, Random(7), Random(107), Random(307))..loot = Random(207);
      b.speed = 2;
      await frames(tester, 30, 100);
      g.startWave();
      final end = g.t + 40, seen = <MonsterSkill>{};
      var still = 0;
      for (var i = 0; i < 1000 && g.waveActive && g.t < end; i++) {
        final t = g.t;
        await frames(tester, 1, 100);
        if (b.foeSplash case final f?) seen.add(f.cast.$2);
        if (g.t == t) still++;
      }
      b.speed = 1;
      return (digest(g), seen, still);
    }

    final (off, seenOff, stillOff) = await run(false);
    final (on, seenOn, stillOn) = await run(true);
    expect(seenOff, isEmpty);
    expect(stillOff, 0);
    expect(seenOn, isNotEmpty, reason: 'splashes did show');
    expect(stillOn, greaterThan(0), reason: 'and the field stood still under them');
    expect(on, off);
  });
}
