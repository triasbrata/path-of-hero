// An army wiped mid-wave (lib/wipe.dart, decisions-log 322; game-overview.md "Lose"): a heart lost and the same wave
// played again, the game over only when the hearts run out. Since decisions-log 329 the back line costs nothing, and a
// wave begun with no troop or a march not won in time is lost the same way.
import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';

import 'hero_skill_helpers.dart';

/// A game with one soldier standing at cell (4, 1) and gold to spare.
Game armyOfOne() => bareGame(Random(1))..monsterSkills = false;

/// Starts the next wave unless one is on, then a werebear beside each living troop, at 1 HP, cuts the army down.
void wipe(Game g) {
  if (!g.waveActive) g.startWave();
  for (final u in g.troops.where((u) => u.alive).toList()) {
    u.hp = 1;
    g.units.add(Unit(Side.enemy, 'werebear', enemyTypes['werebear']!, u.pos + const Point(10, 0))..entered = true);
  }
  for (var i = 0; i < 100 && !g.wipedOut; i++) {
    g.tick(0.05);
  }
  expect(g.wipedOut, isTrue, reason: 'the army fell');
}

/// The wave on is won at once: every monster gone (one more that goes this tick keeps it on until then), none to come.
void winNow(Game g) {
  g.queue.clear();
  for (final u in g.enemies) {
    u.gone = true;
  }
  g.units.add(Unit(Side.enemy, 'slime', enemyTypes['slime']!, Point(g.baseX + 200, fieldH / 2))..gone = true);
  g.tick(0.05);
  expect((g.waveActive, g.over), (false, false));
}

void main() {
  test('a wiped army costs a heart: its monsters are swept off, the wave ends lost, and the same wave is played again', () {
    final g = armyOfOne();
    placeNow(g, 'soldier', 4, 1);
    final events = <GameEvent>[];
    g.listeners.add(events.add);
    g.startWave();
    final roster = g.waveTotal;
    wipe(g);
    expect((g.lives, g.over, g.wave, g.lostWave, g.waveActive, g.canStartWave), (Game.startLives - wipeLives, false, 0, 1, false, true));
    expect([...g.enemies, ...g.queue, ...g.shots, ...g.zones], isEmpty);
    expect(g.swept, isNotEmpty, reason: 'they hop for joy a moment');
    expect(g.sfx, contains(Sfx.lose));
    expect(g.toReplace.map((f) => f.type), ['soldier'], reason: '"Replace fallen" holds the army');
    final w = events.whereType<Wiped>().single;
    expect((w.wave, w.lives, w.lost, w.over, w.foes), (1, 4, 2, false, g.swept.length + roster - g.waveSpawned));
    expect(events.whereType<WaveEnded>().map((e) => (e.wave, e.won)), [(1, false)]);
    expect(w.toJson()['kind'], 'wipe');
    expect(g.wipeNote, 'Your army fell! -1 heart.\nWave 1 again.');
    // The swept monsters go after their hop, each in a summon circle.
    g.impacts.clear();
    runFor(g, wipeCheer + 0.1);
    expect(g.swept, isEmpty);
    expect(g.impacts.where((i) => i.$2 == 'summon'), isNotEmpty);
    // The same wave again: as many monsters, rolled afresh.
    g.startWave();
    expect((g.wave, g.lostWave, g.wipedOut, g.waveTotal), (1, 1, false, roster));
  });

  test('what the lost wave paid stays, what its win pays comes once, when it is won', () {
    final g = armyOfOne();
    placeNow(g, 'soldier', 4, 1);
    g.startWave();
    final mat = Mat.values.first;
    g.waveMaterials[mat] = 3; // lying on the field
    final (gold, score, kills, bonus) = (g.gold, g.score, g.kills, g.lastBonus);
    wipe(g);
    expect((g.gold, g.score, g.kills, g.lastBonus), (gold, score, kills, bonus), reason: 'no wave bonus, no wave score');
    expect((g.waveMaterials.isEmpty, g.materials[mat]), (true, null), reason: 'what lay on the field comes only with a win');
    g.tick(0.05);
    g.startWave();
    final paid = g.gold;
    winNow(g);
    expect((g.wave, g.lostWave, g.lastBonus, g.gold), (1, null, Game.waveBonus(1), paid + Game.waveBonus(1)));
    expect(g.score, score + waveScore);
    expect(g.toJson().containsKey('lostWave'), isFalse);
  });

  test('the last heart ends the game: the monsters stay and cheer, and the clock stands still', () {
    for (final lives in [wipeLives, 1]) {
      final g = armyOfOne()..lives = lives;
      placeNow(g, 'soldier', 4, 1);
      final events = <GameEvent>[];
      g.listeners.add(events.add);
      wipe(g);
      expect((g.lives, g.over, g.wipedOut, g.wave, g.lostWave), (0, true, true, 1, null));
      expect(g.enemies.where((u) => u.alive), isNotEmpty);
      expect(g.swept, isEmpty);
      expect(events.whereType<Wiped>().map((e) => (e.lost, e.over)), [(lives, true)]);
      expect(events.whereType<WaveEnded>().map((e) => e.won), [false]);
      expect(g.score, 0, reason: 'no life left to score');
      final t = g.t;
      g.tick(0.05);
      expect(g.t, t);
    }
  });

  test('no monster heads for the back line, and nothing is lost there: one goes past it to meet a troop walking in '
      '(decisions-log 329)', () {
    final g = armyOfOne();
    final s = placeNow(g, 'soldier', 4, 1);
    s
      ..pos = Point(g.baseX - 60, s.pos.y) // bought mid-wave, behind the line, still walking in
      ..entered = false
      ..busyUntil = hold // and it stays there
      ..maxHp = 1000000
      ..hp = 1e6;
    g
      ..startWave()
      ..queue.clear();
    final slime = Unit(Side.enemy, 'slime', enemyTypes['slime']!, Point(g.baseX + 30, s.pos.y))..entered = true;
    g.units.add(slime);
    runFor(g, 3);
    expect((slime.alive, slime.gone, g.lives, g.waveActive, g.wipedOut), (true, false, Game.startLives, true, false));
    expect(slime.pos.x, lessThan(g.baseX), reason: 'it went to the troop, over the line');
    expect(g.sfx, isNot(contains(Sfx.leak)));
  });

  test('a wave begun with no troop: its monsters wait, and emptyGrace s after they came on the wave is lost', () {
    final g = armyOfOne();
    final events = <GameEvent>[];
    g.listeners.add(events.add);
    g.startWave();
    while (g.waveSpawned == 0) {
      g.tick(0.05);
    }
    final from = g.t, first = g.enemies.first;
    for (var i = 0; i < 400 && !g.wipedOut; i++) {
      g.tick(0.05);
      if (!g.wipedOut) expect(first.moving, isFalse, reason: 'it waits where it is');
    }
    expect((g.wipedOut, g.lives, g.wave, g.lostWave, g.wipeCause), (true, Game.startLives - wipeLives, 0, 1, WipeCause.empty));
    expect(g.wipedAt - from, inInclusiveRange(emptyGrace, emptyGrace + 0.1));
    final w = events.whereType<Wiped>().single;
    expect((w.cause, w.toJson()['cause']), (WipeCause.empty, 'empty'));
    expect(g.wipeNote, 'No troops! -1 heart.\nWave 1 again.');
  });

  test('with no troop standing, a troop bought within emptyGrace s keeps the wave on; monsters a test put on the field with '
      'no spawn are no wave', () {
    final g = armyOfOne()..startWave();
    while (g.waveSpawned == 0) {
      g.tick(0.05);
    }
    runFor(g, emptyGrace - 1);
    expect((g.wipedOut, g.lives, g.waveActive), (false, Game.startLives, true));
    placeNow(g, 'soldier', 4, 1); // bought in time
    runFor(g, 2);
    expect((g.wipedOut, g.lives), (false, Game.startLives), reason: 'a troop stands');

    final h = armyOfOne()
      ..startWave()
      ..queue.clear();
    h.units.add(Unit(Side.enemy, 'slime', enemyTypes['slime']!, Point(h.baseX + 200, fieldH / 2))..entered = true);
    runFor(h, emptyGrace + 1);
    expect((h.wipedOut, h.lives), (false, Game.startLives));
  });

  test('a stalled wave\'s monsters charge the troops and strike them; not won in marchMax s, the wave is lost', () {
    final g = armyOfOne()..skills = false;
    final s = placeNow(g, 'soldier', 4, 1)..busyUntil = hold; // never strikes back
    final events = <GameEvent>[];
    g.listeners.add(events.add);
    g
      ..startWave()
      ..queue.clear();
    final orc = foeAt(g, 'orc', Point(s.pos.x + 400, s.pos.y))
      ..maxHp = 1000000
      ..hp = 1e6
      ..busyUntil = double.negativeInfinity;
    s
      ..maxHp = 1000000
      ..hp = 1e6;
    for (var i = 0; i < 2000 && !g.marching; i++) {
      g.tick(0.05);
    }
    expect((g.marching, g.newMarch), (true, true));
    expect(g.sfx, contains(Sfx.leak), reason: 'the charge\'s alarm');
    final at = g.t, hp = s.hp;
    runFor(g, 5);
    expect(orc.pos.distanceTo(s.pos), lessThan(orc.stats.range + 8), reason: 'at the soldier');
    expect(s.hp, lessThan(hp), reason: 'it strikes');
    expect(g.lives, Game.startLives);
    for (var i = 0; i < 2000 && !g.wipedOut; i++) {
      g.tick(0.05);
    }
    expect((g.wipedOut, g.wipeCause, g.lives, g.wave, g.lostWave), (true, WipeCause.slow, Game.startLives - wipeLives, 0, 1));
    expect(g.wipedAt - at, inInclusiveRange(marchMax, marchMax + 0.1));
    expect(events.whereType<Wiped>().single.cause, WipeCause.slow);
    expect(g.wipeNote, 'Too slow! -1 heart.\nWave 1 again.');
    expect(marchNote, 'Monsters charge!\nWin in 60 s or lose a heart.');
  });

  test('a march won in time is a won wave', () {
    final g = armyOfOne();
    placeNow(g, 'soldier', 4, 1);
    g
      ..startWave()
      ..queue.clear();
    final orc = foeAt(g, 'orc', Point(g.baseX + 400, fieldH / 2))..busyUntil = double.negativeInfinity;
    g.marching = true; // as [stallTime] would
    runFor(g, 1);
    orc.gone = true; // the troops cut it down
    for (var i = 0; i < 40 && g.waveActive; i++) {
      g.tick(0.05);
    }
    expect((g.waveActive, g.wipedOut, g.wave, g.lives), (false, false, 1, Game.startLives));
  });

  test('a boss wave lost: no chest and no Hero until it is won, then one of each', () {
    final g = armyOfOne()
      ..offers = true
      ..wave = heroEvery - 1;
    expect(heroEvery % bossEvery, 0);
    placeNow(g, 'soldier', 4, 1);
    g.startWave();
    expect(g.queue.where((q) => q.$2 == Tier.boss), hasLength(1));
    wipe(g);
    expect((g.wave, g.chests.length, g.heroCount), (heroEvery - 1, 0, 0));
    g.tick(0.05);
    g.startWave();
    expect((g.wave, g.queue.where((q) => q.$2 == Tier.boss).length), (heroEvery, 1), reason: 'the boss comes again');
    placeNow(g, 'soldier', 4, 2);
    winNow(g);
    expect((g.chests.length, g.heroCount), (1, 1));
  });

  test('Towns: one left before the lost wave is not due again; one marked after it waits for its win', () {
    final g = armyOfOne()
      ..wave = 7
      ..townAt = 8;
    placeNow(g, 'soldier', 4, 1);
    expect((g.townDue, g.enterTown(), g.leaveTown()), (true, true, true));
    g.townAt = 10; // the next, before wave 10 (as a roll after wave 8 would mark it)
    wipe(g); // wave 8
    expect((g.wave, g.townDue, g.townAt, g.canStartWave), (7, false, 10, true));
    placeNow(g, 'soldier', 4, 2);
    g.startWave();
    winNow(g); // wave 8 again
    expect((g.wave, g.townDue), (8, false));
    g.startWave();
    winNow(g); // wave 9
    expect((g.wave, g.townDue), (9, true));
  });

  test('the Shadows: the catch-up lands once a wave number, and Lewati\'s skip buff owed meets the replay too', () {
    final g = armyOfOne()..wave = omenFrom + 4;
    final owed = OmenKind.values.take(6).toList();
    g
      ..omensOwed.addAll(owed)
      ..skipBuffDue = true;
    placeNow(g, 'soldier', 4, 1);
    g.startWave();
    final levels = g.omens.length;
    expect((g.omensOwed.length, g.waveSkipBuff, levels > 0), (owed.length - omenCatchUpStep, true, true));
    wipe(g);
    expect(g.skipBuffDue, isTrue);
    placeNow(g, 'soldier', 4, 2);
    g.startWave(); // the replay
    expect((g.omensOwed.length, g.omens.length, g.waveSkipBuff), (owed.length - omenCatchUpStep, levels, true));
    winNow(g);
    g.startWave();
    expect(g.omensOwed.length, owed.length - 2 * omenCatchUpStep);
  });

  test('a save between a wipe and its replay: the last won wave, the hearts as lost, the wave to play again', () {
    final g = armyOfOne()..wave = 4;
    placeNow(g, 'soldier', 4, 1);
    wipe(g);
    final j = jsonDecode(jsonEncode(g.toJson())) as Map<String, dynamic>;
    expect((j['v'], j['wave'], j['lives'], j['lostWave']), (Game.saveVersion, 4, 4, 5));
    final h = Game.fromJson(j, Random(2));
    expect((h.wave, h.lives, h.lostWave, h.over, h.wipedOut, h.canStartWave), (4, 4, 5, false, false, true));
    expect(h.toReplace.map((f) => f.type), ['soldier']);
    h.startWave();
    expect((h.wave, h.lostWave), (5, 5));
    // A lostWave that isn't the next wave (an edited save) is dropped.
    expect(Game.fromJson({...j, 'lostWave': 3}).lostWave, isNull);
    expect(Game.fromJson({...j}..remove('lostWave')).lostWave, isNull);
  });

  test('a Phoenix Plume rise due keeps the army from being wiped; once it fell again with none due, it is', () {
    final g = armyOfOne()
      ..skills = false
      ..heroSkills = false
      ..awakenSkills = false;
    final u = placeNow(g, 'knight', 2, 3)..cd = hold;
    g
      ..givePusaka(Relic.phoenix, type: 'knight')
      ..startWave()
      ..queue.clear();
    final orc = foeAt(g, 'orc', u.pos + const Point(12, 0))
      ..maxHp = 1000000
      ..hp = 1e6;
    void strike() {
      orc
        ..busyUntil = double.negativeInfinity
        ..cd = 0;
      g.tick(0.05);
      orc.busyUntil = hold;
    }

    u.hp = 1;
    strike();
    expect((u.alive, g.wipedOut, g.waveActive), (false, false, true));
    runFor(g, phoenixK.delay + 0.2);
    final r = g.troops.singleWhere((o) => o.alive);
    expect((r.revived, g.wipedOut, g.lives), (true, false, Game.startLives));
    runFor(g, riseTime + 0.1);
    r.hp = 1;
    for (var i = 0; i < 20 && r.alive; i++) {
      strike();
    }
    expect((r.alive, g.wipedOut, g.lives), (false, true, Game.startLives - wipeLives));
  });

  test('the auto-player plays on: Auto Buy brings the army back, the wave starts again, and the third wipe ends the run', () {
    final g = armyOfOne()..setAutoReplace(true);
    placeNow(g, 'soldier', 4, 1);
    final waves = <int>[], lives = <int>[];
    for (var i = 0; i < 5 && !g.over; i++) {
      expect(g.canStartWave, isTrue);
      g.startWave();
      waves.add(g.wave);
      wipe(g);
      lives.add(g.lives);
      if (g.over) break;
      runFor(g, 1); // the fallen's body gone, Auto buys it back
      for (final u in g.troops.where((u) => u.alive)) {
        u
          ..pos = u.post // on its spot at once, not marching in past the back line
          ..entered = true
          ..arriving = false;
      }
      expect(g.troops.where((u) => u.alive).map((u) => u.type), ['soldier'], reason: 'Auto Buy refilled the army');
      expect(g.toReplace, isEmpty);
    }
    expect(waves, [1, 1, 1]);
    expect(lives, [4, 2, 0]);
    expect(g.over, isTrue);
  });
}
