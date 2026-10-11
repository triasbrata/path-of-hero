// A monster champion's skill banner (lib/foe_cut_in.dart, champion-fx Part 3): what feeds it (Game.monsterCasts, a
// high elite's and up, the rank Split's slimes show), the gate and the line as the Board runs them, Pengaturan's
// "Sorotan Musuh", that every skill's banner fits a desk (1266x713) and a phone (915x412), and that the banners
// change nothing in the fight. The queue and the gate alone: test/cut_in_test.dart.
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flame/game.dart' hide Game;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/cut_ins.dart';
import 'package:tower_defense/game.dart';
import 'package:tower_defense/main.dart';
import 'package:tower_defense/settings.dart';

import 'hud_font.dart';

/// Boots one TdGame in a [w]x[h] window and returns its board, past the welcome screen, with the game's font and
/// the minimap folded.
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

/// A monster of [type] and [tier] off the field, winding up [skill] in [g]: the Board drains it next frame.
Unit casts(Game g, String type, Tier tier, MonsterSkill skill, [Point<double> at = const Point(120.0, 60.0)]) {
  final u = g.monster(type, tier, at);
  g.monsterCasts.add((u, skill));
  return u;
}

/// The ranks a skill's caster may have: a signature's from the high elite up, a mini-boss skill's from the mini
/// boss, a moment's the boss's.
List<Tier> ranksOf(MonsterSkill s) => switch (s.rank) {
      MonsterRank.signature => [Tier.highElite, Tier.miniBoss, Tier.boss],
      MonsterRank.miniBoss => [Tier.miniBoss, Tier.boss],
      MonsterRank.moment => [Tier.boss],
    };

void main() {
  testWidgets('a high elite\'s skill shows its banner: its English title and "<type> <rank>"; an elite\'s or a normal '
      'one\'s none', (tester) async {
    final b = await boot(tester);
    var g = b.state = Game(Random(1));
    await frames(tester);
    expect(b.foeCutIn, isNull);
    casts(g, 'skeleton_archer', Tier.highElite, MonsterSkill.volley);
    await frames(tester, 1);
    expect((b.foeCutIn?.title, b.foeCutIn?.line, b.foeCutIn?.band), ('Volley', '${tierNames[Tier.highElite]} ${monsterTypeNames['skeleton_archer']}', false));
    await frames(tester, (foeCutTime * 1000 / 16).ceil() + 2);
    expect(b.foeCutIn, isNull); // its time is over
    for (final tier in [Tier.normal, Tier.elite]) {
      g = b.state = Game(Random(1));
      await frames(tester);
      casts(g, 'skeleton_archer', tier, MonsterSkill.volley);
      await frames(tester, 2);
      expect(b.foeCutIn, isNull, reason: tier.name);
    }
  });

  testWidgets('Split shows its mini boss\'s rank; a mini boss\'s banner goes before a high elite\'s waiting; the next '
      'wave shows a skill again', (tester) async {
    final b = await boot(tester);
    final g = b.state = Game(Random(1))..wave = 6;
    await frames(tester);
    // A slime mini boss bursts as it dies (boss_skills.dart): the cast is the first newcomer's, a normal slime raised
    // by it.
    final maker = g.monster('slime', Tier.miniBoss, const Point(120.0, 60.0));
    final slime = g.monster('slime', Tier.normal, const Point(122.0, 60.0))..raisedBy = maker;
    expect(foeCutRank(slime), Tier.miniBoss);
    g.monsterCasts.add((slime, MonsterSkill.split));
    await frames(tester, 1);
    expect((b.foeCutIn?.title, b.foeCutIn?.line), ('Split', '${tierNames[Tier.miniBoss]} ${monsterTypeNames['slime']}'));
    casts(g, 'orc', Tier.highElite, MonsterSkill.warShout);
    await frames(tester, 1);
    casts(g, 'orc', Tier.miniBoss, MonsterSkill.headbutt);
    await frames(tester, 1);
    expect([for (final (_, s, r) in b.foeCutsWaiting) (s, r)], [(MonsterSkill.headbutt, Tier.miniBoss), (MonsterSkill.warShout, Tier.highElite)]);
    expect(b.foeCutShowing?.$2, MonsterSkill.split); // the one showing runs its time
    // The same skill and rank again this wave: no banner; in the next wave: one.
    await frames(tester, (3 * foeCutTime * 1000 / 16).ceil() + 4);
    expect(b.foeCutShowing, isNull);
    casts(g, 'orc', Tier.miniBoss, MonsterSkill.headbutt);
    await frames(tester, 1);
    expect(b.foeCutShowing, isNull);
    g.wave = 7;
    casts(g, 'orc', Tier.miniBoss, MonsterSkill.headbutt);
    await frames(tester, 1);
    expect((b.foeCutIn?.title, b.foeCutIn?.line), ('Headbutt', '${tierNames[Tier.miniBoss]} Orc'));
    // The same skill at another rank is another banner.
    casts(g, 'orc', Tier.boss, MonsterSkill.headbutt);
    await frames(tester, 1);
    expect([for (final (_, s, r) in b.foeCutsWaiting) (s, r)], [(MonsterSkill.headbutt, Tier.boss)]);
  });

  testWidgets('a desk\'s banner stands at the right under the Hero cut-in\'s band, at the left when its caster is '
      'under it', (tester) async {
    final b = await boot(tester);
    var g = b.state = Game(Random(1));
    await frames(tester);
    casts(g, 'orc', Tier.highElite, MonsterSkill.warShout, const Point(20.0, 60.0));
    await frames(tester, 12); // slid in
    final right = b.foeCutIn!.at;
    expect((right.right, right.top >= 713 * 0.3 + 100), (1266 - 16, true));
    // A caster standing where it rests: the next banner comes in at the left.
    final o = b.toScreen(0, 0), k = b.toScreen(1, 0).dx - o.dx, under = right.center;
    g = b.state = Game(Random(1));
    await frames(tester);
    casts(g, 'orc', Tier.highElite, MonsterSkill.warShout, Point((under.dx - o.dx) / k + g.cam, (under.dy - o.dy) / k));
    await frames(tester, 12);
    expect((b.foeCutIn!.at.left, b.foeCutIn!.at.top), (16.0, right.top));
  });

  for (final (w, h) in [(1266.0, 713.0), (915.0, 412.0)]) {
    testWidgets('Pengaturan\'s "Sorotan Musuh" turns the banners off and on, kept in settings.json; off drops the one '
        'showing; its four rows fit the page (${w.round()}x${h.round()})', (tester) async {
      final b = await boot(tester, w, h);
      final g = b.state = Game(Random(1));
      await frames(tester);
      b.showSettings();
      await frames(tester, 40); // the book is open between waves
      // The four at the bottom of the right page, Lisensi over Sorotan Musuh over Sorotan Hero over Menu Utama, under
      // "Kirim data permainan"'s line and inside the screen.
      final rows = [b.licenceButton, b.foeCutButton, b.heroCutButton, b.menuButton];
      expect(rows.every((r) => !r.isEmpty), isTrue, reason: '$rows');
      expect(b.sendNote.bottom <= rows.first.top, isTrue, reason: '${b.sendNote} over ${rows.first} at ${w}x$h');
      for (var i = 1; i < rows.length; i++) {
        expect(rows[i - 1].bottom < rows[i].top, isTrue, reason: '${rows[i - 1]} over ${rows[i]} at ${w}x$h');
      }
      expect(rows.last.bottom <= h, isTrue);
      casts(g, 'orc', Tier.highElite, MonsterSkill.warShout);
      await frames(tester, 2);
      expect(b.foeCutIn, isNotNull);
      await tester.tapAt(b.foeCutButton.center);
      await frames(tester, 2);
      expect((b.foeCutIn, loadSettings().foeCutIns, loadSettings().heroCutIns), (null, false, true));
      casts(g, 'orc', Tier.miniBoss, MonsterSkill.headbutt);
      await frames(tester, 2);
      expect(b.foeCutIn, isNull); // off: none
      await tester.tapAt(b.foeCutButton.center);
      await frames(tester, 5);
      expect(loadSettings().foeCutIns, isTrue);
      casts(g, 'orc', Tier.miniBoss, MonsterSkill.groundSlam);
      await frames(tester, 2);
      expect(b.foeCutIn?.title, 'Ground Slam');
    });
  }

  for (final (w, h) in [(1266.0, 713.0), (915.0, 412.0)]) {
    testWidgets('every skill\'s banner fits at every rank it is cast at: its title whole, at 11 px at least, inside its '
        'ribbon and the screen; every type\'s line whole (${w.round()}x${h.round()})',
        (tester) async {
      final b = await boot(tester, w, h);
      Future<({String title, String line, double titleSize, bool band, Rect at, Rect ribbon})> show(String type, Tier rank, MonsterSkill s) async {
        final g = b.state = Game(Random(1)); // a new game: none showing or waiting, the gate afresh
        await frames(tester, 1);
        casts(g, type, rank, s);
        await frames(tester, 1);
        final cut = b.foeCutIn;
        expect(cut, isNotNull, reason: '${s.name} ${rank.name} at ${w}x$h');
        return cut!;
      }

      for (final s in MonsterSkill.values) {
        for (final rank in ranksOf(s)) {
          final cut = await show(s.type, rank, s), why = '${s.name} ${rank.name} at ${w}x$h: $cut';
          expect((cut.title, cut.band), (s.title, s.rank == MonsterRank.moment), reason: why);
          expect(cut.titleSize >= 11, isTrue, reason: why);
          expect(cut.at.left >= 0 && cut.at.right <= w && cut.at.top >= 0 && cut.at.bottom <= h, isTrue, reason: why);
          expect(cut.at.contains(cut.ribbon.topLeft) && cut.at.contains(cut.ribbon.bottomRight - const Offset(1, 1)), isTrue, reason: why);
        }
      }
      // Any type may hold any rank: every type's line, with the longest title.
      for (final type in monsterTypeNames.keys) {
        for (final rank in [Tier.highElite, Tier.miniBoss, Tier.boss]) {
          final u = Game(Random(1)).monster(type, rank, const Point(0.0, 0.0));
          final cut = await show(type, rank, MonsterSkill.curseOfFrailty);
          expect((cut.title, cut.line), ('Curse of Frailty', foeCutLine(u, rank)), reason: '$type ${rank.name} at ${w}x$h');
        }
      }
    });
  }

  testWidgets('the banners change nothing in the fight: the owner\'s wave-86 save plays wave 87 the same with them on '
      'and off', (tester) async {
    final b = await boot(tester);
    final save = jsonDecode(File('test/fixtures/save-20261001-2005-pre-awaken.json').readAsStringSync()) as Map<String, dynamic>;
    String digest(Game g) => [
          't ${g.t} gold ${g.gold} lives ${g.lives} kills ${g.kills} score ${g.score}',
          for (final u in g.units) '${u.side.name} ${u.type} ${u.tier.name} ${u.alive} ${u.hp} ${u.mp} ${u.pos.x},${u.pos.y}',
        ].join('\n');
    // Both runs go through the same steps: Pengaturan's toggle turned once, back to Pasukan, the save loaded and left to
    // settle (the book's float in and out) before its wave starts.
    Future<(String, Set<MonsterSkill>)> run(bool on) async {
      expect(loadSettings().foeCutIns, !on);
      b.state = Game();
      await frames(tester, 2);
      b.showSettings();
      await frames(tester, 40);
      await tester.tapAt(b.foeCutButton.center);
      await frames(tester, 5);
      await tester.tapAt(b.bookTabs.firstWhere((t) => t.$1 == 'troops').$2.center);
      await frames(tester, 5);
      expect((loadSettings().foeCutIns, b.storeShown, b.sendButton), (on, false, Rect.zero));
      final g = b.state = Game.fromJson(save, Random(7), Random(107), Random(307))..loot = Random(207);
      b.speed = 2;
      await frames(tester, 30, 100);
      g.startWave();
      final seen = <MonsterSkill>{};
      for (var i = 0; i < 150 && g.waveActive; i++) {
        await frames(tester, 1, 100); // a tick of 0.2 s a frame
        if (b.foeCutShowing case (_, final s, _)) seen.add(s);
      }
      b.speed = 1;
      return (digest(g), seen);
    }

    final (off, seenOff) = await run(false);
    final (on, seenOn) = await run(true); // and settings.json back on
    expect(seenOn, isNotEmpty); // banners did show
    expect(seenOff, isEmpty);
    expect(on, off);
  });
}
