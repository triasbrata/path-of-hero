// The Town checkpoint (lib/wipe.dart, decisions-log 333; the owner, 2026-10-13: "kalau pasukan wipe user di balikkan
// lagi ke town terakhir yang dia datangin supaya bisa mengumpulkan uang, dan wave selanjutnya di debuff sampai next
// town"): a wipe after a Town goes back to it, the waves from it played again; what was earned stays, the once-a-number
// rewards come once; the monsters weakened until the next new Town; the save; "Try again" and "Give up".
import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';
import 'package:tower_defense/scores.dart' show ScoreEntry;

import 'hero_skill_helpers.dart';
import 'wipe_test.dart' show wipe, winNow;

/// No Town rolled by itself: the tests mark the ones they want.
final _noRolls = TownRules.patch({
  'schedule': {'chanceStart': 0.0, 'chanceStep': 0.0},
});

/// A game whose Town before wave [at] (after wave [at] - 1) has been gone into and left: the checkpoint.
Game checkpointed(int at) {
  final g = bareGame(Random(1))
    ..monsterSkills = false
    ..townRules = _noRolls
    ..wave = at - 1
    ..townAt = at;
  expect((g.enterTown(), g.leaveTown(), g.townCount), (true, true, 1));
  return g;
}

/// A soldier on the field, standing at once in the first free cell of the zone's second column.
Unit soldier(Game g) {
  for (var r = 0; r < rows; r++) {
    if (g.troopAt(g.baseCol + 1, r) == null) return placeNow(g, 'soldier', g.baseCol + 1, r);
  }
  throw StateError('no free cell');
}

/// Waves [from] to [to] started and won at once.
void winWaves(Game g, int from, int to) {
  for (var w = from; w <= to; w++) {
    g.startWave();
    expect(g.wave, w);
    winNow(g);
  }
}

/// The next wave started with a soldier standing, and its army cut down.
void loseNext(Game g) {
  soldier(g);
  g.startWave();
  wipe(g);
}

void main() {
  test('a wipe after a Town goes back to it: the Town due again before the wave after it, the same Town, and leaving it '
      'starts that wave', () {
    final g = checkpointed(21);
    final name = g.sceneIdentity.name, market = {...g.market}..['sword'] = 3;
    g.market['sword'] = 3; // something sold there
    winWaves(g, 21, 26);
    expect((g.bestWon, g.townAt), (26, null));
    final events = <GameEvent>[];
    g.listeners.add(events.add);
    soldier(g);
    final gold = g.gold;
    g.startWave(); // wave 27
    wipe(g);
    expect((g.lives, g.over, g.wave, g.lostWave, g.bestWon, g.weakened), (Game.startLives - wipeLives, false, 20, 27, 26, 1));
    expect((g.townAt, g.townLast, g.townAgain, g.townDue, g.canStartWave, g.townCount), (21, 21, true, true, false, 1));
    expect(g.gold, gold, reason: 'what was earned stays');
    final w = events.whereType<Wiped>().single;
    expect((w.wave, w.checkpoint, w.debuff, w.town), (27, 21, 1, name));
    expect(w.toJson(), containsPair('checkpoint', 21));
    expect(w.toJson(), containsPair('debuff', 1));
    expect(g.wipeNote, 'Your army fell! -1 heart.\nBack to $name: waves 21-27 again, foes weakened.');
    // The same Town: its number, its name and its market as left; a new Tavern visit.
    expect(g.enterTown(), isTrue);
    final e = events.whereType<TownEntered>().single;
    expect((e.slot, e.n, e.again, e.toJson()['again']), (21, 1, true, true));
    expect((g.townCount, g.sceneIdentity.name, g.townIdentity.name, g.market), (1, name, name, market));
    expect(g.leaveTown(), isTrue);
    expect((g.townLast, g.townAt, g.canStartWave), (21, null, true));
    g.startWave();
    expect(g.wave, 21);
    final s = events.whereType<WaveStarted>().last.toJson();
    expect((s['weakened'], s['again']), (1, true));
  });

  test('one wave from the Town: "wave 21 again"', () {
    final g = checkpointed(21);
    loseNext(g);
    expect((g.wave, g.lostWave), (20, 21));
    expect(g.wipeBack, 'Back to ${g.sceneIdentity.name}: wave 21 again');
  });

  test('waves won again pay their win gold again; their score, Hero and Boss Chest come only the first time', () {
    final g = checkpointed(26)..offers = true;
    winWaves(g, 26, 29);
    soldier(g);
    winWaves(g, 30, 30); // the boss wave and the tenth: a chest and a Hero
    expect((g.chests.length, g.heroCount), (1, 1));
    final score = g.score;
    loseNext(g); // wave 31: the Hero falls with the army
    expect((g.wave, g.heroCount, g.fallenHeroes.length), (25, 0, 1));
    expect((g.enterTown(), g.leaveTown()), (true, true));
    for (var w = 26; w <= 30; w++) {
      if (w == 30) soldier(g); // one to crown, if a Hero came again
      final gold = g.gold;
      winWaves(g, w, w);
      expect(g.gold, gold + Game.waveBonus(w), reason: 'wave $w: its win gold again');
    }
    expect((g.chests.length, g.heroCount, g.score), (1, 0, score), reason: 'no second chest, Hero or wave score');
    expect((g.lostWave, g.bestWon), (31, 30));
    winWaves(g, 31, 31);
    expect((g.score, g.lostWave, g.bestWon), (score + waveScore * 31, null, 31), reason: 'wave 31 won the first time');
  });

  test('the Shadows\' catch-up lands once a wave number, on the waves played again too', () {
    final g = checkpointed(omenFrom + 1);
    g.omensOwed.addAll(OmenKind.values.take(8));
    winWaves(g, omenFrom + 1, omenFrom + 2);
    final owed = g.omensOwed.length;
    expect(owed, 8 - 2 * omenCatchUpStep);
    loseNext(g); // wave omenFrom + 3: its catch-up landed as it began
    expect(g.omensOwed.length, owed - omenCatchUpStep);
    expect((g.enterTown(), g.leaveTown()), (true, true));
    winWaves(g, omenFrom + 1, omenFrom + 2);
    g.startWave(); // the lost wave again
    expect(g.omensOwed.length, owed - omenCatchUpStep, reason: 'nothing more on waves already begun');
    winNow(g);
    g.startWave();
    expect(g.omensOwed.length, owed - 2 * omenCatchUpStep, reason: 'the next new wave lands its share');
  });

  test('the monsters weakened: -20% HP and -15% damage, -30% and -25% at the most, their gold kept', () {
    final g = bareGame(Random(1))..wave = 30;
    for (final (type, tier) in [('orc', Tier.normal), ('werebear', Tier.elite), ('skeleton', Tier.miniBoss)]) {
      g.weakened = 0;
      final base = g.spawnStats(type, tier);
      for (final (n, hp, dmg) in [(1, 0.8, 0.85), (2, 0.7, 0.75), (5, 0.7, 0.75)]) {
        g.weakened = n;
        final s = g.spawnStats(type, tier);
        expect((s.hp, s.cost), ((base.hp * hp).round(), base.cost), reason: '$type $tier at $n');
        expect(s.dmg, closeTo(base.dmg * dmg, 1e-9), reason: '$type $tier at $n');
      }
    }
    g.weakened = 1;
    final m = g.monster('orc', Tier.normal, const Point(300, 60));
    expect(m.maxHp, (g.spawnStats('orc', Tier.normal).hp).toDouble());
    g.weakened = 0;
    expect(m.maxHp, lessThan(g.spawnStats('orc', Tier.normal).hp));
    expect([weakenedHp, weakenedDmg, weakenedMost], [
      [1.0, 0.8, 0.7],
      [1.0, 0.85, 0.75],
      2,
    ]);
  });

  test('a second wipe before a new Town weakens them more; the checkpoint again keeps it, the next new Town ends it; '
      'the third wipe ends the game', () {
    final g = checkpointed(21);
    final until = RunningBoost(Boost.values.first, 0, untilTown: true);
    g.boosts.add(until);
    loseNext(g);
    expect((g.weakened, g.lives), (1, 4));
    expect((g.enterTown(), g.weakened, g.boosts.contains(until)), (true, 1, true), reason: 'not a new Town');
    expect(g.leaveTown(), isTrue);
    loseNext(g);
    expect((g.weakened, g.lives, g.wave, g.townAgain), (2, 2, 20, true));
    expect(g.weakenedCut, '-30% HP, -25% damage');
    expect((g.enterTown(), g.leaveTown()), (true, true));
    g.townAt = 23; // a new Town after wave 22
    winWaves(g, 21, 22);
    expect((g.townDue, g.townAgain), (true, false));
    expect((g.enterTown(), g.weakened, g.townCount, g.boosts.contains(until)), (true, 0, 2, false));
    expect(g.leaveTown(), isTrue);
    final events = <GameEvent>[];
    g.listeners.add(events.add);
    loseNext(g); // wave 23, the last heart
    expect((g.over, g.lives, g.wave, g.weakened, g.waveReached), (true, 0, 23, 0, 23));
    expect(events.whereType<Wiped>().map((w) => (w.checkpoint, w.debuff, w.over)), [(null, 0, true)]);
  });

  test('the game over in a wave played again: the scoreboard\'s wave is the furthest reached', () {
    final g = checkpointed(21)..lives = 2 * wipeLives;
    winWaves(g, 21, 24);
    loseNext(g); // wave 25
    expect((g.enterTown(), g.leaveTown()), (true, true));
    winWaves(g, 21, 21);
    loseNext(g); // wave 22, the last heart
    expect((g.over, g.wave, g.waveReached), (true, 22, 25));
  });

  test('before the first Town: the same wave again (322), the foes weakened until the first Town', () {
    final g = bareGame(Random(1))
      ..monsterSkills = false
      ..wave = 4;
    final events = <GameEvent>[];
    g.listeners.add(events.add);
    loseNext(g);
    expect((g.wave, g.lostWave, g.weakened, g.checkpoint, g.townAt, g.canStartWave), (4, 5, 1, null, null, true));
    expect(g.wipeNote, 'Your army fell! -1 heart.\nWave 5 again, foes weakened.');
    expect(events.whereType<Wiped>().map((w) => (w.checkpoint, w.debuff, w.town)), [(null, 1, null)]);
    g.townAt = 6;
    winWaves(g, 5, 5);
    expect(g.enterTown(), isTrue);
    expect((g.weakened, g.townCount), (0, 1));
  });

  test('the save: after the wipe it goes back into the same Town, made in it it reopens there, the waves won and the '
      'weakening kept; an old save reads as before', () {
    final g = checkpointed(21);
    winWaves(g, 21, 23);
    loseNext(g); // wave 24
    final j = jsonDecode(jsonEncode(g.toJson())) as Map<String, dynamic>;
    expect((j['v'], j['wave'], j['bestWon'], j['weakened'], j['lostWave'], j['wipeAsk']), (Game.saveVersion, 20, 23, 1, 24, null));
    expect(((j['town'] as Map)['at'], (j['town'] as Map)['last'], (j['town'] as Map)['n']), (21, 21, 1));
    final h = Game.fromJson(j, Random(2))..townRules = _noRolls;
    expect((h.wave, h.bestWon, h.weakened, h.lostWave, h.townAt, h.townAgain, h.townDue, h.townCount), (20, 23, 1, 24, 21, true, true, 1));
    expect(h.enterTown(), isTrue);
    expect((h.townCount, h.weakened), (1, 1));
    final k = Game.fromJson(jsonDecode(jsonEncode(h.toJson())) as Map<String, dynamic>, Random(3));
    expect((k.inTown, k.townAgain, k.townCount, k.sceneIdentity.name), (true, true, 1, g.sceneIdentity.name));
    expect(k.leaveTown(), isTrue);
    k.startWave();
    expect((k.wave, k.weakened), (21, 1));
    // A save from before: its wave is the highest won, nothing weakened, nothing to choose.
    final old = Map<String, dynamic>.from(j)
      ..remove('bestWon')
      ..remove('weakened')
      ..remove('lostWave');
    final o = Game.fromJson(old);
    expect((o.bestWon, o.weakened, o.lostWave, o.wipeAsk), (20, 0, null, false));
  });

  test('what opened at a wave won stays open after a trip back; one Sharpen and one Carve budget a boss interval', () {
    final g = bareGame(Random(1))
      ..wave = 12
      ..bestWon = 40;
    expect((g.armyBuysOpen, g.storeOpen, g.enhanceOpen, g.ukirOpen, g.wonWave(40), g.wonWave(41)), (true, true, true, true, true, false));
    g.bestWon = 12;
    expect((g.armyBuysOpen, g.enhanceOpen, g.ukirOpen), (false, false, false));
    g
      ..wave = 31
      ..asahAt = 35;
    expect((g.asahDone, g.asahAgainAt), (true, 40), reason: 'the later interval\'s Sharpen counts');
    g.ukir
      ..iv = 7
      ..pts = 100;
    expect((g.ukirBudget, g.ukirAgainAt), (ukirPerBoss - 100, 40));
  });

  group('Try again or Give up (the player chooses: autoTryAgain off)', () {
    setUp(() => autoTryAgain = false);
    tearDown(() => autoTryAgain = true);

    test('the game waits on the choice: no wave, no Town; it is saved; Try again goes on to the Town', () {
      final g = checkpointed(21);
      final events = <GameEvent>[];
      g.listeners.add(events.add);
      loseNext(g);
      expect((g.wipeAsk, g.canStartWave, g.townDue, g.over), (true, false, true, false));
      expect(g.enterTown(), isFalse);
      g.startWave();
      expect(g.wave, 20, reason: 'no wave starts');
      final j = jsonDecode(jsonEncode(g.toJson())) as Map<String, dynamic>;
      expect((j['wipeAsk'], Game.fromJson(j).wipeAsk), (true, true));
      expect((g.tryAgain(), g.wipeAsk, g.tryAgain(), g.giveUp()), (true, false, false, false));
      expect(events.whereType<WipeChosen>().map((e) => e.toJson()['tryAgain']), [true]);
      expect((g.enterTown(), g.leaveTown()), (true, true));
      g.startWave();
      expect(g.wave, 21);
    });

    test('Give up ends the game at once: no heart left, its score as it was, the furthest wave on the scoreboard', () {
      final g = checkpointed(21);
      winWaves(g, 21, 22);
      final events = <GameEvent>[];
      g.listeners.add(events.add);
      loseNext(g); // wave 23
      final score = g.score;
      expect(g.giveUp(), isTrue);
      expect((g.over, g.lives, g.wipeAsk, g.score, g.waveReached, g.canStartWave), (true, 0, false, score, 23, false));
      expect(events.whereType<WipeChosen>().map((e) => (e.tryAgain, e.lives)), [(false, Game.startLives - wipeLives)]);
      expect(ScoreEntry.of(g, 'x').wave, 23);
    });

    test('the last heart asks nothing: the game is over', () {
      final g = checkpointed(21)..lives = wipeLives;
      loseNext(g);
      expect((g.over, g.wipeAsk), (true, false));
    });
  });
}
