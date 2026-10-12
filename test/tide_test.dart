import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';

// "Pasang", the tide, and "Ganti yang gugur" (#92 part 1, decisions-log 142; docs/units-and-combat.md "The tide").
// The HUD's side (the meter's badge, the Pasukan page's button): tide_hud_test.dart.

/// A game with a 6-column deploy zone and no free healer (as game_test.dart's `bare`).
Game bare([Random? rng]) => (Game(rng)..capacity = 6 * rows)..units.clear();

/// [Game.place] with the troop standing on its cell at once instead of marching in from the left.
bool placeNow(Game g, String type, int c, int r) {
  if (!g.place(type, c, r)) return false;
  g.units.last
    ..pos = g.units.last.post
    ..entered = true
    ..arriving = false;
  return true;
}

/// A monster's stats without the tide: its tide starts after the wave.
Stats untided(String type, Tier tier, int wave, {bool raised = false}) => enemyStats(type, tier, wave, raised: raised, tideStart: 1000);

Point<double> cellMiddle(int c, int r) => Point(c * tile + tile / 2, r * tile + tile / 2);

Map<String, dynamic> roundTrip(Map<String, Object> j) => jsonDecode(jsonEncode(j)) as Map<String, dynamic>;

void main() {
  test('its numbers: from wave 35, HP +1% a wave since decisions-log 161 (was 1.5%), damage and pace 0.5%', () {
    expect((tideFrom, tideHp, tideDmg, tidePace, tideGapMin, tideCatchUp), (35, 0.01, 0.005, 0.005, 0.5, 20));
  });

  test('the tide is 1 up to its first wave, then compounds: HP x1.3478 and damage x1.1614 on wave 65', () {
    for (final k in [tideHp, tideDmg, tidePace]) {
      expect((tide(1, k), tide(34, k), tide(35, k)), (1.0, 1.0, 1.0));
    }
    expect(tide(65, tideHp), closeTo(1.3478, 1e-4));
    expect(tide(65, tideDmg), closeTo(1.1614, 1e-4));
    expect(tide(100, tideHp), closeTo(1.9094, 1e-4));
    // Counted from another wave (an old save's catch-up): wave 72 from 52 is what a new game meets on wave 55.
    expect((tide(72, tideHp, 52), tide(72, tideDmg, 52)), (tide(55, tideHp), tide(55, tideDmg)));
    expect(tide(72, tideHp, 52), closeTo(1.2202, 1e-4));
  });

  test('the spawn gap shortens by 0.5% a wave from the tide on, never under 0.5 s', () {
    expect((spawnGapOf(1), spawnGapOf(34), spawnGapOf(35)), (Game.spawnGap, Game.spawnGap, Game.spawnGap));
    expect(spawnGapOf(65), closeTo(0.7744, 1e-4));
    expect(spawnGapOf(72, 52), closeTo(0.8141, 1e-4));
    expect((spawnGapOf(200), spawnGapOf(1000)), (tideGapMin, tideGapMin));
  });

  test('wave 65\'s orc has HP 1,952 and damage x6.84 x1.1614; kill gold, speed, reach, defence and MP stay', () {
    final orc = enemyTypes['orc']!, s = enemyStats('orc', Tier.normal, 65);
    expect(waveGrowth(65, waveDmg, waveDmgLate), closeTo(6.84, 1e-9));
    expect(s.hp, 1952);
    expect(s.dmg, closeTo(orc.dmg * 6.84 * tide(65, tideDmg), 1e-9));
    expect(s.cost, killGold(orc.cost, Tier.normal, 65));
    expect(untided('orc', Tier.normal, 65).hp, 1448);
  });

  test('every crowd monster gets the tide, raised minions too; the wave\'s boss and mini boss slots don\'t', () {
    const wave = 65;
    final hp = tide(wave, tideHp), dmg = tide(wave, tideDmg);
    final crowd = [
      for (final type in [...enemyTypes.keys, necroHealer]) for (final tier in [Tier.normal, Tier.elite, Tier.highElite]) (type, tier, false),
      (boss, escortSummonerTier, false), // an escort's high-elite summoner (#90)
      for (final tier in [Tier.normal, Tier.elite, Tier.highElite, Tier.miniBoss]) (minion, tier, true), // raised, a mini boss too
      ('slime', Tier.normal, true), // a slime split off
    ];
    for (final (type, tier, raised) in crowd) {
      final s = enemyStats(type, tier, wave, raised: raised), u = untided(type, tier, wave, raised: raised);
      final why = '$type ${tier.name}${raised ? ' raised' : ''}';
      expect(s.hp, closeTo(u.hp * hp, 2.0), reason: why); // each rounded once
      expect(s.dmg, closeTo(u.dmg * dmg, 1e-9), reason: why); // a healing necromancer's heal is its dmg
      expect((s.cost, s.speed, s.rate, s.range, s.def, s.mp, s.mpRegen), (u.cost, u.speed, u.rate, u.range, u.def, u.mp, u.mpRegen),
          reason: why);
    }
    // The slots: any type's mini boss and boss, the necromancer as either.
    for (final type in [...enemyTypes.keys, boss]) {
      for (final tier in [Tier.miniBoss, Tier.boss]) {
        final s = enemyStats(type, tier, wave), u = untided(type, tier, wave);
        expect((s.hp, s.dmg), (u.hp, u.dmg), reason: '$type ${tier.name}');
      }
    }
    expect(enemyStats('werebear', Tier.miniBoss, 65).hp, 208512);
  });

  test('the game\'s monsters, its summoner\'s minions and its spawn gap follow the game\'s tideStart', () {
    final g = bare()
      ..wave = 65
      ..tideStart = 50;
    expect(g.monster('orc', Tier.elite, const Point(250, 60)).maxHp, enemyStats('orc', Tier.elite, 65, tideStart: 50).hp);
    expect(g.monster('orc', Tier.elite, const Point(250, 60)).maxHp, lessThan(enemyStats('orc', Tier.elite, 65).hp)); // a later start
    final u = g.monster(boss, Tier.boss, const Point(250, 60))..summonCd = 0;
    g.units.add(u..mp = u.stats.mp.toDouble());
    g.tick(0.05);
    final raised = g.minionsOf(u).toList();
    expect(raised, isNotEmpty);
    for (final m in raised) {
      final want = enemyStats(minion, m.tier, 65, raised: true, tideStart: 50);
      expect((m.maxHp, m.stats.dmg), (want.hp, want.dmg));
    }
  });

  test('a wave-65 queue comes on every 0.7744 s; without the tide every 0.9 s', () {
    for (final (from, gap) in [(tideFrom, spawnGapOf(65)), (1000, Game.spawnGap)]) {
      final g = bare(Random(1))
        ..wave = 64
        ..lives = 1000
        ..tideStart = from;
      g.startWave();
      final (type, tier) = g.queue.first;
      g.tick(0.05); // the first comes at once
      expect(g.waveSpawned, 1);
      final first = g.enemies.single;
      if (tided(tier)) expect(first.maxHp, enemyStats(type, tier, 65, tideStart: from).hp);
      g.tick(gap - 0.004);
      expect(g.waveSpawned, 1, reason: 'from $from');
      g.tick(0.008);
      expect(g.waveSpawned, 2, reason: 'from $from');
    }
  });

  test('the tide is saved; a save from before it catches up halfway, and says so once when it is already on', () {
    expect(Game().tideStart, tideFrom);
    expect(Game().toJson()['tideStart'], tideFrom);
    Game old(int wave) => Game.fromJson(roundTrip((Game()..wave = wave).toJson())..remove('tideStart'));
    expect([for (final w in [10, 33, 34, 40, 55, 72]) (old(w).tideStart, old(w).tideCaughtUp)],
        [(35, false), (35, false), (35, true), (35, true), (35, true), (52, true)]);
    // Loaded once, it is saved with its start, and comes back as it was, nothing to say.
    final l = Game.fromJson(roundTrip(old(72).toJson()));
    expect((l.tideStart, l.tideCaughtUp), (52, false));
    expect(enemyStats('orc', Tier.normal, 73, tideStart: l.tideStart).hp, greaterThan(enemyStats('orc', Tier.normal, 73, tideStart: 1000).hp));
    final kept = Game.fromJson(roundTrip((Game()..tideStart = 40).toJson()));
    expect((kept.tideStart, kept.tideCaughtUp), (40, false));
  });

  test('the win before the tide\'s first wave is the one the popup tells; the meter\'s words and percent', () {
    expect([for (final w in [33, 34, 35]) (Game()..wave = w).tideRising], [false, true, false]);
    expect((Game()
          ..wave = 51
          ..tideStart = 52)
        .tideRising, isTrue);
    expect((tidePercent(34), tidePercent(35), tidePercent(36), tidePercent(65), tidePercent(100)), (0, 0, 1, 35, 91));
    expect(tideInfo(65).$1, Words.tide);
    expect(tideInfo(65).$2, ['Monster HP +35%', 'Monster attack +16%', 'A monster every 0.77 s', 'Not the boss or mini boss']);
    expect(tideInfo(72, 52).$2.first, 'Monster HP +22%');
  });

  test('WaveStarted tells the tide on the wave\'s crowd', () {
    final g = bare(Random(1))
      ..wave = 64
      ..lives = 1000;
    final started = <WaveStarted>[];
    g.listeners.add((e) {
      if (e is WaveStarted) started.add(e);
    });
    g.startWave();
    expect(started.single.data['tide'], {'hp': 1.3478, 'dmg': 1.1614, 'gap': 0.7743, 'over': 0});
  });

  group('Ganti yang gugur', () {
    /// [type] troops that fell, each with its old spot: cell (c, r).
    void fell(Game g, List<(String, int, int)> who) =>
        g.toReplace.addAll([for (final (type, c, r) in who) (type: type, post: cellMiddle(c, r))]);

    test('a won wave offers its fallen back, not its Heroes, at their spots moved up with the back line', () {
      final g = bare()..gold = 1000;
      placeNow(g, 'knight', 1, 3); // the one left standing
      placeNow(g, 'soldier', 4, 1);
      placeNow(g, 'archer', 4, 6);
      final soldier = g.troops.firstWhere((u) => u.type == 'soldier')..hp = 1;
      final archer = g.troops.firstWhere((u) => u.type == 'archer')
        ..hp = 1
        ..hero = true;
      for (final u in [soldier, archer]) {
        g.units.add(Unit(Side.enemy, 'werebear', enemyTypes['werebear']!, u.pos + const Point(10, 0)));
      }
      final (spot, line) = (soldier.post, g.baseX);
      for (var i = 0; i < 40 && g.fallen.length < 2; i++) {
        g.tick(0.05);
      }
      expect(g.fallen, unorderedEquals([soldier, archer]));
      expect(g.toReplace, isEmpty); // not won yet
      for (final e in g.enemies) {
        e.gone = true;
      }
      g.tick(0.05);
      expect((g.waveActive, g.over), (false, false));
      expect(g.baseX, greaterThan(line)); // the line moved up to the knight's column
      final post = spot + Point(g.baseX - line, 0);
      expect(g.toReplace, [(type: 'soldier', post: post)]);
      expect(g.replaceCost, g.priceOf('soldier'));

      final gold = g.gold;
      expect(g.replaceFallen(), (bought: 1, of: 1, why: null));
      expect(g.gold, gold - g.priceOf('soldier'));
      expect(g.troops.where((u) => u.alive && u.type == 'soldier').single.post, post);
      expect(g.toReplace, isEmpty);
    });

    test('it buys the cheapest first as far as the gold goes, each to its old cell, and says why the rest stayed', () {
      final g = bare();
      placeNow(g, 'knight', 0, 0);
      fell(g, [('wizard', 2, 2), ('soldier', 1, 4), ('knight', 2, 6)]);
      expect(g.replaceCost, g.priceOf('wizard') + g.priceOf('soldier') + g.priceOf('knight'));
      g.gold = g.priceOf('soldier') + g.priceOf('knight') + 10; // not the wizard
      expect(g.whyNotReplace, isNull);
      final bought = <String?>[];
      g.listeners.add((e) {
        if (e is Bought) bought.add(e.type);
      });
      expect(g.replaceFallen(), (bought: 2, of: 3, why: buyRefusals.gold));
      expect(bought, ['soldier', 'knight']); // cheapest first
      expect(g.gold, 10);
      expect([for (final u in g.troops.skip(1)) (u.type, u.cell)], [('soldier', (1, 4)), ('knight', (2, 6))]);
      expect(g.toReplace, [(type: 'wizard', post: cellMiddle(2, 2))]);
      // Now even the cheapest left is too dear: nothing is bought, and the button says why.
      expect(g.whyNotReplace, buyRefusals.gold);
      g.sfx.clear();
      expect(g.replaceFallen(), (bought: 0, of: 1, why: buyRefusals.gold));
      expect(g.sfx, [Sfx.error]);
    });

    test('a taken spot sends it in where autoPlace puts it', () {
      final g = bare()..gold = 1000;
      placeNow(g, 'knight', 2, 2);
      fell(g, [('soldier', 2, 2)]);
      expect(g.replaceFallen(), (bought: 1, of: 1, why: null));
      final soldier = g.troops.firstWhere((u) => u.type == 'soldier');
      expect(soldier.cell, isNot((2, 2)));
      expect(g.inZone(soldier.cell.$1, soldier.cell.$2), isTrue);
      expect(g.troops.map((u) => u.cell).toSet().length, 2); // a cell each
    });

    test('the capacity stops it: partly, or wholly with "No room"', () {
      final g = bare()..gold = 1000;
      placeNow(g, 'knight', 0, 0);
      fell(g, [('soldier', 1, 1), ('soldier', 1, 2)]);
      g.capacity = 2; // room for one more
      expect(g.replaceFallen(), (bought: 1, of: 2, why: buyRefusals.full));
      expect((g.armySize, g.toReplace.length), (2, 1));
      expect(g.whyNotReplace, buyRefusals.full);
      expect(g.replaceFallen(), (bought: 0, of: 1, why: buyRefusals.full));
    });

    test('only between waves, not after the game: a wave start ends the offer', () {
      final g = bare()..gold = 1000;
      placeNow(g, 'knight', 0, 0);
      fell(g, [('soldier', 1, 1)]);
      g.units.add(Unit(Side.enemy, 'slime', enemyTypes['slime']!, const Point(300, 60))); // a wave is on
      expect(g.whyNotReplace, Words.onlyBetweenWaves);
      expect(g.replaceFallen(), (bought: 0, of: 1, why: Words.onlyBetweenWaves));
      expect((g.armySize, g.gold), (1, 1000 - g.priceOf('knight')));
      g.units.removeWhere((u) => u.side == Side.enemy); // between waves again (no win: that would make a new offer)
      g.lives = 0;
      expect(g.whyNotReplace, Words.gameOver);
      g.lives = 3;
      expect(g.whyNotReplace, isNull);
      g.startWave();
      expect(g.toReplace, isEmpty);
    });

    test('the offer is saved with the game; none, no key', () {
      final g = bare();
      expect(g.toJson().containsKey('toReplace'), isFalse);
      fell(g, [('soldier', 1, 1), ('wizard', 2, 5)]);
      final l = Game.fromJson(roundTrip(g.toJson()));
      expect(l.toReplace, [(type: 'soldier', post: cellMiddle(1, 1)), (type: 'wizard', post: cellMiddle(2, 5))]);
    });
  });

  group('the army cap\'s warning (decisions-log 161)', () {
    /// Wave [won] won, [n] soldiers on the field (columns of 8), then the board's limits on (so 48, a save from before
    /// the cap, can stand).
    Game atCap({int n = armyMaxBoard, int won = 63}) {
      final g = bare()
        ..gold = 1 << 30
        ..wave = won;
      for (var i = 0; i < n; i++) {
        expect(placeNow(g, 'soldier', i ~/ rows, i % rows), isTrue);
      }
      return g
        ..boardRules()
        ..typeCap = null; // the type caps aside (decisions-log 201): an army of one type, the army's cap alone
    }

    Unit soldier() => Unit(Side.troop, 'soldier', troopTypes['soldier']!, const Point(8, 8));

    test('its words and its gap', () {
      expect((capWarnEvery, capWarningText(32, 87), capTip(32)),
          (5, '${Words.army} full: cap 32 - ${Words.tide} +87%\nMake types stronger in the ${Words.army} page (${Words.awaken})',
              '${Words.army} full (32): make types stronger'));
    });

    test('pressed while the army is full at the cap, the tide is on and a fielded type can still grow', () {
      expect(atCap().capPressed, isTrue);
      expect((atCap()..armyMax = null).capPressed, isFalse, reason: 'no cap: a plain Game()');
      expect((atCap(n: 20)..capacity = 20).capPressed, isFalse, reason: 'full at a capacity that can still grow');
      final short = atCap(n: armyMaxBoard - 1);
      expect(short.capPressed, isFalse, reason: '35 of 36: a buy still grows the army');
      short.fallen.add(soldier()); // one fell in the wave just won: the army stood at the cap
      expect(short.capPressed, isTrue);
      // An army over the cap (the owner's 48 from before it) is full too.
      expect(atCap(n: 48).capPressed, isTrue);
      // The tide: not before it, nor on its first wave ("+0%"), from its second.
      expect([for (final won in [33, 34, 35]) atCap(won: won).capPressed], [false, false, true]);
      expect((atCap(won: 70)..tideStart = 71).capPressed, isFalse, reason: 'an old save\'s tide counts from its own start');
      // Every fielded type at Bangkit 5: nothing is left to buy, so it says nothing.
      // Awaken 3 from its items by the board's rule (by grade: the forge is on since decisions-log 272), then Bangkit 5.
      final top = atCap(n: armyMaxBoard - 1);
      top
        ..upgrades['soldier'] = [
          for (final MapEntry(key: item, value: n) in top.awakenNeeds('soldier', maxAwaken).entries) ...List.filled(n, item),
        ]
        ..ascended['soldier'] = maxAscend;
      expect((top.awakenLevel('soldier'), top.capPressed), (awakenTop, false));
      expect(placeNow(top, 'knight', 5, 0), isTrue);
      expect(top.capPressed, isTrue, reason: 'the knight can still grow');
      // In a wave the meter shows the wave itself.
      final inWave = atCap(won: 35)..units.add(Unit(Side.enemy, 'slime', enemyTypes['slime']!, const Point(300, 60)));
      expect((inWave.waveActive, inWave.capPressed), (true, false));
      inWave.wave = 36;
      expect(inWave.capPressed, isTrue);
    });

    test('it is due between waves, once every 5 waves, with the coming wave\'s tide', () {
      final g = atCap();
      expect(g.capWarning(), capWarningText(armyMaxBoard, tidePercent(64)));
      expect(g.capWarnedAt, 63);
      final shown = <int>[];
      for (var won = 63; won <= 75; won++) {
        g.wave = won;
        if (g.capWarning() != null) shown.add(won);
      }
      expect(shown, [68, 73]);
      // Not mid-wave, nor while it isn't pressed; neither marks it shown.
      g
        ..wave = 80
        ..units.add(Unit(Side.enemy, 'slime', enemyTypes['slime']!, const Point(300, 60)));
      expect(g.capWarning(), isNull);
      g.units.removeWhere((u) => u.side == Side.enemy);
      g.units.remove(g.troops.first); // 35 alive, nobody fell
      expect((g.capWarning(), g.capWarnedAt), (null, 73));
      expect(placeNow(g, 'soldier', 0, 0), isTrue);
      expect(g.capWarning(), isNotNull);
    });

    test('the wave meter\'s tooltip ends with it while the army is full', () {
      final g = atCap();
      expect(g.tideTip.$1, tideInfo(64).$1);
      expect(g.tideTip.$2, [...tideInfo(64).$2, capTip(armyMaxBoard)]);
      g.units.remove(g.troops.first);
      expect(g.tideTip.$2, tideInfo(64).$2);
      final old = atCap(won: 72)..tideStart = 52;
      expect(old.tideTip.$2.first, tideInfo(73, 52).$2.first);
    });
  });

  group('Beban, the over-cap tide (decisions-log 162)', () {
    /// The cap the mechanism's numbers below were worked out at, as decisions-log 162 had it: 48 over 32 is 16 over. The
    /// board's is 36 since decisions-log 260 (12 over for the same 48: the last test here, army_cap_test, omen_test).
    const cap = 32;

    /// Wave [won] won with the tide from 66 (the owner's w86 save), [n] soldiers on the field (columns of 8), then the
    /// board's limits on at the cap of [cap], so 48 stand over it.
    Game overCap({int n = 48, int won = 86}) {
      final g = bare()
        ..gold = 1 << 30
        ..lives = 1000
        ..wave = won
        ..tideStart = 66;
      for (var i = 0; i < n; i++) {
        expect(placeNow(g, 'soldier', i ~/ rows, i % rows), isTrue);
      }
      return g
        ..boardRules()
        ..armyMax = cap
        ..typeCap = null; // the type caps aside (decisions-log 201): an army of one type, the army's cap alone
    }

    /// Ends the wave on: nothing left to come, no monster left (no win: the game stays as it is).
    void endWave(Game g) {
      g.queue.clear();
      g.units.removeWhere((u) => u.side == Side.enemy);
      expect(g.waveActive, isFalse);
    }

    /// [n] of [g]'s living troops fall (taken off the field).
    void fall(Game g, int n) => g.units.removeWhere((u) => u.side == Side.troop && n-- > 0);

    test('its numbers and words', () {
      expect((overTide, overTideMax, overRamp, overPace), (2, 60, 5, true));
      expect((overTip(16, 32), overTip(1, 1)), ('16 over the cap: ${Words.tide} +32 waves', '1 over the cap: ${Words.tide} +1 wave'));
      expect(overNote(32), '${Words.army} cap 32. Each troop over it:\n${Words.tide} +2 waves');
    });

    test('2 waves a troop over, at most 60, a fifth more each wave from the first over the cap, rounded', () {
      expect([for (final w in [87, 88, 89, 90, 91, 92, 120]) overTideWaves(16, w, 87)], [6, 13, 19, 26, 32, 32, 32]);
      expect([for (final over in [0, 1, 2, 16, 30, 31, 40]) overTideWaves(over, 99, 87)], [0, 2, 4, 32, 60, 60, 60]);
      expect((overTideWaves(3, 87, 87), overTideWaves(1, 87, 87), overTideWaves(-3, 99, 87), overTideWaves(16, 86, 87)),
          (1, 0, 0, 0)); // one troop over on its first wave rounds to none yet
    });

    test('48 at the cap of 32 counts the tide from 32 waves earlier, for every monster the wave makes', () {
      final g = overCap()..overFrom = 82; // ramped in already
      expect(g.overBy, 16);
      g.startWave();
      expect((g.wave, g.waveOver, g.waveTideFrom, g.overFrom), (87, (by: 16, waves: 32), 34, 82));
      final orc = g.monster('orc', Tier.elite, const Point(250, 60));
      expect(orc.maxHp, enemyStats('orc', Tier.elite, 87, tideStart: 34).hp);
      expect(tide(87, tideHp, 34), closeTo(1.6945, 1e-4)); // the crowd's HP at full strength (x1.23 from 66)
      expect(orc.maxHp, greaterThan(enemyStats('orc', Tier.elite, 87, tideStart: 66).hp));
      // Each troop less over the cap gives 2 waves back; 30 over is capped at 60.
      endWave(g);
      fall(g, 4);
      g.startWave();
      expect((g.waveOver, g.waveTideFrom), ((by: 12, waves: 24), 42));
      final big = overCap(n: 48)..overFrom = 70;
      for (var i = 0; i < 16; i++) {
        big.units.add(Unit(Side.troop, 'soldier', troopTypes['soldier']!, const Point(8, 8)));
      }
      big.startWave();
      expect(big.waveOver, (by: 32, waves: 60));
    });

    test('a summoner\'s minions follow the wave\'s tide', () {
      final g = bare()
        ..wave = 87
        ..tideStart = 66
        ..waveOver = (by: 16, waves: 48);
      final u = g.monster(boss, Tier.boss, const Point(250, 60))..summonCd = 0;
      g.units.add(u..mp = u.stats.mp.toDouble());
      g.tick(0.05);
      final raised = g.minionsOf(u).toList();
      expect(raised, isNotEmpty);
      for (final m in raised) {
        final want = enemyStats(minion, m.tier, 87, raised: true, tideStart: 18);
        expect((m.maxHp, m.stats.dmg), (want.hp, want.dmg));
      }
    });

    test('the spawn gap follows the wave\'s tide too (overPace on)', () {
      final g = overCap()..overFrom = 80;
      g.startWave();
      expect((g.waveTideFrom, g.wavePaceFrom), (34, 34));
      final (type, tier) = g.queue.first;
      g.tick(0.05);
      expect(g.waveSpawned, 1);
      if (tided(tier)) expect(g.enemies.single.maxHp, enemyStats(type, tier, 87, tideStart: 34).hp);
      // 48 troops: the spawn floor (decisions-log 225) brings the first 6 one a tick, and the gap runs from the last.
      expect(g.spawnFloor, 6);
      for (var i = 2; i <= 6; i++) {
        g.tick(0.05);
      }
      expect(g.waveSpawned, 6);
      g.tick(spawnGapOf(87, 34) - 0.004);
      expect(g.waveSpawned, 6);
      g.tick(0.008);
      expect(g.waveSpawned, 7);
      expect(spawnGapOf(87, 34), lessThan(spawnGapOf(87, 66)), reason: 'off, it would keep the base pace');
    });

    test('it ramps in over 5 waves from the first wave started over the cap, which is saved', () {
      final g = overCap();
      expect(g.overFrom, isNull);
      final ramp = <int>[];
      for (var i = 0; i < 6; i++) {
        g.startWave();
        ramp.add(g.waveOver.waves);
        endWave(g);
      }
      expect(ramp, [6, 13, 19, 26, 32, 32]);
      expect(g.overFrom, 87);
      // Saved, and the ramp goes on from it after a load.
      final l = Game.fromJson(roundTrip(g.toJson()))
        ..boardRules()
        ..armyMax = cap;
      expect((l.overFrom, l.wave), (87, 92));
      // At the cap it is off, and the first wave stays: back over later, it is at full strength at once.
      fall(g, 16);
      g.startWave();
      expect((g.waveOver, g.waveTideFrom, g.overFrom), ((by: 0, waves: 0), 66, 87));
      endWave(g);
      g.units.add(Unit(Side.troop, 'soldier', troopTypes['soldier']!, const Point(8, 8)));
      g.startWave();
      expect(g.waveOver, (by: 1, waves: 2));
      // A loaded save without the key sets it on its first wave over the cap.
      final old = Game.fromJson(roundTrip(overCap().toJson())..remove('overFrom'))
        ..boardRules()
        ..armyMax = cap;
      expect(old.overFrom, isNull);
      old.startWave();
      expect((old.overFrom, old.waveOver.waves), (87, 6));
    });

    test('frozen for the wave: troops falling in it change nothing until the next', () {
      final g = overCap()..overFrom = 82;
      g.startWave();
      final hp = g.monster('orc', Tier.normal, const Point(250, 60)).maxHp;
      fall(g, 10);
      expect((g.overBy, g.waveOver, g.waveTideFrom), (6, (by: 16, waves: 32), 34));
      expect(g.monster('orc', Tier.normal, const Point(250, 60)).maxHp, hp);
      expect(g.shownOver, (by: 16, waves: 32), reason: 'in a wave the HUD shows the wave\'s own');
      endWave(g);
      // Between waves the HUD shows the coming wave's as the army stands now.
      expect((g.shownOver, g.shownTideFrom), ((by: 6, waves: 12), 54));
      g.startWave();
      expect((g.waveOver, g.waveTideFrom), ((by: 6, waves: 12), 54));
    });

    test('off with no cap (a plain Game()) and for an army at the cap or under it, so nothing is saved', () {
      final plain = overCap()..armyMax = null;
      plain.startWave();
      expect((plain.overBy, plain.waveOver, plain.waveTideFrom, plain.overFrom), (0, (by: 0, waves: 0), 66, null));
      final at = overCap(n: 32);
      at.startWave();
      expect((at.overBy, at.waveOver, at.waveTideFrom, at.overFrom), (0, (by: 0, waves: 0), 66, null));
      expect(at.toJson().containsKey('overFrom'), isFalse);
      expect(Game().overFrom, isNull);
      expect(Game().toJson().containsKey('overFrom'), isFalse);
    });

    test('a wave at the board\'s cap plays the same with the cap on as with it off', () {
      String play(bool cap) {
        final g = bare(Random(5))
          ..loot = Random(6)
          ..heroes = Random(7)
          ..slots = Random(8)
          ..draft = Random(9)
          ..gold = 1 << 30
          ..lives = 1000
          ..wave = 6 // wave 7: no boss, no mini boss, the tide on from 2
          ..tideStart = 2;
        for (var i = 0; i < armyMaxBoard; i++) {
          expect(placeNow(g, i % 4 == 0 ? 'archer' : 'soldier', i ~/ rows, i % rows), isTrue);
        }
        g.capacity = armyMaxBoard; // so the army is full at the same count either way
        if (cap) g.armyMax = armyMaxBoard;
        g.startWave();
        final spawned = <int>[];
        for (var i = 0; i < 20 * 600 && g.waveActive; i++) {
          g.tick(0.05);
          for (final e in g.enemies) {
            if (!spawned.contains(e.id)) spawned.add(e.id);
          }
        }
        return [
          g.wave, g.waveActive || g.over, g.t.toStringAsFixed(6), g.gold, g.kills, g.lives, g.score, g.waveTideFrom, spawned.length,
          for (final u in g.troops) '${u.type} ${u.alive} ${u.hp.toStringAsFixed(6)} ${u.pos.x.toStringAsFixed(4)}',
        ].join('|');
      }

      final on = play(true);
      expect(on, play(false));
      final [wave, going, _, _, kills, ...] = on.split('|');
      expect((wave, going, int.parse(kills) > 10), ('7', 'false', true), reason: on); // the wave fought out, and won
    });

    test('the HUD\'s words: the tooltip\'s line, the cap\'s warning and the one-time note follow it', () {
      final g = overCap()..overFrom = 82;
      expect(g.tideTip.$2, [...tideInfo(87, 34).$2, overTip(16, 32), capTip(cap)]); // its pace too (overPace)
      expect(g.capWarning(), capWarningText(cap, tidePercent(87, 34)));
      expect(tidePercent(87, 34), 69);
      fall(g, 16); // at the cap: the tide as before
      expect(g.tideTip.$2, [...tideInfo(87, 66).$2, capTip(cap)]);
      // The note, once, for an army alive over the cap; with the "army" note for a save that hasn't seen it.
      final owner = overCap()..notes.add('army');
      expect(owner.limitNotes(), [overNote(32)]);
      expect(owner.limitNotes(), isEmpty);
      expect(overCap().limitNotes(), ['The army cap is now 32. You keep your troops;\nbuy more when under 32.', overNote(32)]);
      final under = overCap(n: 32)..capacity = 48; // capacity over the cap, the army not
      expect(under.limitNotes(), ['The army cap is now 32. You keep your troops;\nbuy more when under 32.']);
      expect((overCap()..armyMax = null).limitNotes(), isEmpty);
    });

    test('WaveStarted tells it: the tide\'s multipliers from the earlier wave, and how many waves earlier', () {
      final started = <WaveStarted>[];
      final g = overCap()..overFrom = 82;
      g.listeners.add((e) {
        if (e is WaveStarted) started.add(e);
      });
      g.startWave();
      final want = {'hp': tide(87, tideHp, 34), 'dmg': tide(87, tideDmg, 34), 'gap': spawnGapOf(87, 34)};
      final tideData = started.single.data['tide'] as Map;
      expect(tideData['over'], 32);
      for (final MapEntry(:key, :value) in want.entries) {
        expect(tideData[key], closeTo(value, 1e-4), reason: key);
      }
      endWave(g);
      fall(g, 16);
      g.startWave();
      expect((started.last.data['tide'] as Map)['over'], 0);
    });

    test('at the board\'s 36 (decisions-log 260) the same 48 are 12 over: the tide from 24 waves earlier', () {
      final g = overCap()
        ..armyMax = armyMaxBoard
        ..overFrom = 82;
      expect((armyMaxBoard, g.overBy), (36, 12));
      g.startWave();
      expect((g.waveOver, g.waveTideFrom), ((by: 12, waves: 24), 42));
      endWave(g);
      fall(g, 12); // at the cap: the tide as before
      g.startWave();
      expect((g.waveOver, g.waveTideFrom), ((by: 0, waves: 0), 66));
    });
  });
}
