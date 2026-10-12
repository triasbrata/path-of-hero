// The Towns' schedule and state (decisions-log 216; lib/town.dart; docs/loot-items-relics.md "Towns (dark)"): the
// shipped numbers, the roll (20% at first, +5% a miss, the cap, back to 20% after a Town), the block within 5 waves of
// the last Town, the first Town before wave 7 at the earliest, the mark two waves ahead, going in and out, the start
// held while a Town is due, the save, the dice, the boss schedule untouched and the telemetry, against games no Town
// comes to ([noTowns]: every game has the Towns, a plain Game() too, decisions-log 321; town_switch_test.dart).
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';
import 'package:tower_defense/main.dart' show logLine;
import 'package:tower_defense/telemetry.dart';

import 'real_rules.dart';

/// A die that gives [draws] in turn (and counts them).
class _Dice implements Random {
  _Dice(this.draws);

  final List<double> draws;
  int used = 0;

  @override
  double nextDouble() => draws[used++];

  @override
  int nextInt(int max) => throw UnsupportedError('the Town dice draw doubles');

  @override
  bool nextBool() => throw UnsupportedError('the Town dice draw doubles');
}

/// A sink that keeps what it gets, through JSON as a file would.
class _Kept implements TelemetrySink {
  final records = <Map<String, dynamic>>[];

  @override
  void add(Map<String, Object?> record) => records.add(jsonDecode(jsonEncode(record)) as Map<String, dynamic>);

  @override
  Future<void> flush() async {}

  List<Map<String, dynamic>> of(String rec) => [for (final r in records) if (r['rec'] == rec) r];
}

/// A seeded game with the Towns on, [rules] (the defaults) and [dice] (seeded).
Game towns({TownRules rules = const TownRules(), Random? dice, int seed = 1}) => Game(Random(seed), Random(seed + 100))
  ..heroes = Random(seed + 300)
  ..loot = Random(seed + 200)
  ..slots = Random(seed + 400)
  ..draft = Random(seed + 500)
  ..townRules = rules
  ..townDice = dice ?? Random(seed + 600);

/// Rules whose every roll hits: a Town every [TownSchedule.minGap] waves from wave 7.
final always = TownRules.patch({
  'schedule': {'chanceStart': 1.0},
});

/// [r]'s version and `schedule`, as the file writes them.
Map<String, dynamic> schedule(TownRules r) => {for (final k in ['version', 'schedule']) k: r.toJson()[k]};

/// Wins [g]'s next wave outright (one slime that is dealt with), going through a due Town first. What the wave's
/// queue held when it started (its slots).
List<(String, Tier)> winWave(Game g) {
  if (g.townDue) {
    expect(g.enterTown(), isTrue);
    expect(g.leaveTown(), isTrue);
  }
  g.startWave();
  final queue = [...g.queue];
  g.queue
    ..clear()
    ..add(('slime', Tier.normal));
  g.tick(0.05);
  g.enemies.single.gone = true;
  g.tick(0.05);
  expect(g.waveActive, isFalse);
  return queue;
}

/// The Towns' slots [g] went through in [waves] won waves.
List<int> slots(Game g, int waves) {
  final out = <int>[];
  for (var i = 0; i < waves; i++) {
    if (g.townDue) out.add(g.townAt!);
    winWave(g);
  }
  return out;
}

/// The file's version and its `schedule` block (the materials' blocks: town_materials_test.dart).
const defaults = {
  'version': 3,
  'schedule': {'chanceStart': 0.20, 'chanceStep': 0.05, 'chanceCap': 1.0, 'minGap': 5, 'firstTownAfter': 2, 'autoLeave': 5.0},
};

void main() {
  test('the shipped town.json is the defaults, every number written out; a Game reads the rules loaded at start', () {
    expect(schedule(TownRules.parse(File('assets/config/town.json').readAsStringSync())), defaults);
    expect(schedule(const TownRules()), defaults);
    expect(Game().townRules.toJson(), const TownRules().toJson());
  });

  test('the file: another version, not JSON, a number out of range or of the wrong kind keep their defaults; a patch '
      'puts numbers in', () {
    expect(schedule(TownRules.parse('{"version": 1, "schedule": {"minGap": 9}}')), defaults);
    expect(schedule(TownRules.parse('not json')), defaults);
    expect(schedule(TownRules.parse('{"version": 2}')), defaults);
    final odd = TownRules.parse('{"version": 2, "materials": {}, "schedule": {"chanceStart": 1.5, "chanceStep": 0.1, '
            '"chanceCap": 0.5, "minGap": 0, "firstTownAfter": -1, "autoLeave": "soon"}}')
        .schedule;
    expect((odd.chanceStart, odd.chanceStep, odd.chanceCap, odd.minGap, odd.firstTownAfter, odd.autoLeave), (0.2, 0.1, 0.5, 5, 2, 5.0));
    final under = TownRules.parse('{"version": 2, "schedule": {"chanceStart": 0.6, "chanceCap": 0.5}}').schedule;
    expect((under.chanceStart, under.chanceCap), (0.2, 1.0), reason: 'a cap under the start: both defaults');
    final p = TownRules.patch({
      'schedule': {'chanceStep': 0.5, 'minGap': 3},
    }).schedule;
    expect((p.chanceStart, p.chanceStep, p.chanceCap, p.minGap, p.firstTownAfter, p.autoLeave), (0.2, 0.5, 1.0, 3, 2, 5.0));
  });

  test('the roll: blocked (no draw, the chance stays) until wave 5, then 20% and +5% a miss', () {
    final dice = _Dice(List.filled(40, 0.999));
    final g = towns(dice: dice);
    for (var w = 1; w <= 4; w++) {
      winWave(g);
      expect((g.wave, dice.used, g.townChance), (w, 0, 0.2), reason: 'blocked: wave $w + 2 is within 5 of the run start (2)');
    }
    for (var w = 5; w <= 10; w++) {
      winWave(g);
      expect(dice.used, w - 4);
      expect(g.townChance, closeTo(0.2 + 0.05 * (w - 4), 1e-9));
    }
    expect(g.townAt, isNull);
  });

  test('the cap: the chance grows to chanceCap and stays; a hit marks slot n+2 and takes it back to chanceStart', () {
    final dice = _Dice([0.99, 0.99, 0.99, 0.79]);
    final g = towns(rules: TownRules.patch({'schedule': {'chanceStep': 0.5, 'chanceCap': 0.8}}), dice: dice);
    final marked = <TownMarked>[];
    g.listeners.add((e) => e is TownMarked ? marked.add(e) : null);
    for (var w = 1; w <= 5; w++) {
      winWave(g);
    }
    expect(g.townChance, closeTo(0.7, 1e-9));
    winWave(g); // wave 6: 0.99 against 0.7
    expect(g.townChance, 0.8, reason: 'min(cap, 1.2)');
    winWave(g); // wave 7: 0.99 against 0.8
    expect((g.townChance, g.townAt), (0.8, null));
    winWave(g); // wave 8: 0.79 against 0.8: a hit
    expect((g.townAt, g.townChance, dice.used), (10, 0.2, 4));
    expect(marked.single.toJson(), {'v': eventVersion, 'kind': 'townMarked', 'wave': 8, 't': g.t, 'slot': 10, 'chance': 0.8, 'rolls': 4});
    expect(eventVersion, greaterThanOrEqualTo(9)); // 9 brought the Towns'; later versions keep it (10: the forge's, 11: the Tavern's)
  });

  test('every roll hitting: the first Town before wave 7, then one every 5 waves; marked two waves ahead; a marked Town '
      'and the waves within 5 of the last draw nothing', () {
    final dice = _Dice(List.filled(20, 0.5));
    final g = towns(rules: always, dice: dice);
    for (var w = 1; w <= 4; w++) {
      winWave(g);
    }
    expect((g.townAt, dice.used), (null, 0));
    winWave(g); // wave 5 won: slot 7 marked, the Town after wave 6
    expect((g.townAt, g.townMarked, g.townDue, g.canStartWave, dice.used), (7, true, false, true, 1));
    winWave(g); // wave 6 won: marked, so no draw; the Town is due
    expect((g.wave, g.townAt, g.townDue, g.canStartWave, dice.used), (6, 7, true, false, 1));
    expect(slots(g, 30), [7, 12, 17, 22, 27, 32]);
    expect(g.townLast, 32);
  });

  test('random dice over 60 seeds: the first Town never before wave 7, never two within 5 waves', () {
    final firsts = <int>[];
    for (var seed = 1; seed <= 60; seed++) {
      final g = towns(seed: seed), got = slots(g, 40);
      expect(got, isNotEmpty, reason: 'seed $seed: the chance reaches 100% within 17 rolls');
      expect(got.first, greaterThanOrEqualTo(7), reason: 'seed $seed');
      for (var i = 1; i < got.length; i++) {
        expect(got[i] - got[i - 1], greaterThanOrEqualTo(5), reason: 'seed $seed: $got');
      }
      firsts.add(got.first);
    }
    expect(firsts.contains(7), isTrue, reason: 'a 20% first roll hits in some of 60 runs');
  });

  test('going in and out: only a due Town, once; in it no wave starts; leaving makes it the last Town and clears the '
      'mark; the events and the log lines', () {
    final g = towns(rules: always);
    for (var w = 1; w <= 5; w++) {
      winWave(g);
    }
    expect(g.enterTown(), isFalse, reason: 'marked, not due yet');
    expect(g.leaveTown(), isFalse, reason: 'not in one');
    winWave(g);
    expect(g.townDue, isTrue);
    g.startWave();
    expect((g.wave, g.waveActive), (6, false), reason: 'no wave while the Town is due');
    final gold = g.gold;
    expect(g.enterTown(auto: true), isTrue);
    expect(g.enterTown(), isFalse, reason: 'already in it');
    expect((g.inTown, g.townDue, g.townMarked, g.canStartWave), (true, true, false, false));
    g.startWave();
    expect(g.wave, 6, reason: 'no wave in a Town');
    g.tick(0.5);
    expect(g.leaveTown(), isTrue);
    expect((g.inTown, g.townAt, g.townLast, g.townDue, g.canStartWave), (false, null, 7, false, true));
    final log = g.log.entries;
    final entered = log.whereType<TownEntered>().single, left = log.whereType<TownLeft>().single;
    expect(entered.toJson(), {
      'v': eventVersion, 'kind': 'townEntered', 'wave': 6, 't': entered.t, 'slot': 7, 'gold': gold, 'auto': true, //
      'n': 1, 'identity': 'millbrook',
    });
    // With the Tavern on (as shipped, decisions-log 268) the visit's `tavern` too: its three offers, nothing bought.
    final leftJson = left.toJson(), tavern = leftJson.remove('tavern') as Map;
    expect(leftJson,
        {'v': eventVersion, 'kind': 'townLeft', 'wave': 6, 't': left.t, 'slot': 7, 'secs': 0.5, 'auto': false, 'crafts': {}, 'craftSpent': 0});
    expect(tavern.keys, ['offered', 'bought', 'rerolls', 'spent']);
    expect((tavern['offered'] as List).length, 3);
    expect(tavern['bought'], isEmpty);
    expect((tavern['rerolls'], tavern['spent']), (0, 0));
    expect([for (final e in log) if (e is TownMarked || e is TownEntered || e is TownLeft) logLine(e)],
        ['${Words.townAfter} 6', '${Words.town}: Millbrook', 'Left town'], reason: 'the Town gone into by its identity (decisions-log 326)');
    expect(logLine(log.whereType<TownMarked>().single), 'Town after wave 6');
    g.startWave();
    expect(g.wave, 7);
  });

  test("a probe's townPolicy goes through a due Town at the next wave's start", () {
    final g = towns(rules: always)..townPolicy = 'leave';
    for (var w = 1; w <= 6; w++) {
      winWave(g);
    }
    expect(g.townDue, isTrue);
    g.startWave();
    expect((g.wave, g.waveActive, g.townLast, g.townAt), (7, true, 7, null));
    final left = g.log.entries.whereType<TownLeft>().single;
    expect((left.auto, g.log.entries.whereType<TownEntered>().single.auto), (true, true));
  });

  test('the save: `town` {chance, last, at, in, n}; a save in the Town reopens in it; a passed '
      "mark and a stray `in` are dropped; a save without the key counts a Town before its own wave", () {
    final g = towns(dice: _Dice([0.99, 0.99, 0.1, 0.5]));
    for (var w = 1; w <= 7; w++) {
      winWave(g); // misses after 5 and 6, a hit after 7: slot 9
    }
    Map<String, dynamic> save(Game g) => jsonDecode(jsonEncode(g.toJson())) as Map<String, dynamic>;
    expect(save(g)['town'], {'chance': 0.2, 'last': 2, 'at': 9});
    Game load(Map<String, dynamic> j) => Game.fromJson(j, Random(1), Random(2), Random(3));
    final marked = load(save(g));
    expect((marked.townChance, marked.townLast, marked.townAt, marked.inTown, marked.townMarked), (0.2, 2, 9, false, true));
    winWave(g);
    g.enterTown();
    final inside = save(g);
    // The Tavern's visit rides along (on as shipped; its own save: tavern_test.dart).
    expect({...inside['town'] as Map}..removeWhere((k, _) => '$k'.startsWith('tavern')),
        {'chance': 0.2, 'last': 2, 'at': 9, 'in': true, 'n': 1}, reason: 'n: the Towns gone into (decisions-log 326)');
    expect((inside['town'] as Map).containsKey('tavern'), isTrue, reason: "the visit's offers");
    final back = load(inside);
    expect((back.inTown, back.townDue, back.canStartWave), (true, true, false));
    expect(back.leaveTown(), isTrue);
    expect((back.townLast, back.townAt), (9, null));
    // A mark already passed, and `in` with no Town due, are dropped.
    final stale = load({...inside, 'wave': 9});
    expect((stale.townAt, stale.inTown, stale.canStartWave), (null, false, true));
    final stray = load({
      ...inside,
      'town': {'chance': 0.35, 'last': 2, 'at': 11, 'in': true},
    });
    expect((stray.townChance, stray.townAt, stray.inTown), (0.35, 11, false));
    // A save from before the Towns: no key, so it counts a Town before its own wave.
    final off = save(g)..remove('town');
    expect(load(off).townLast, 8);
    expect(load({...off, 'wave': 0}).townLast, 2, reason: "a new run's start");
    expect(load({...off, 'wave': 1}).townLast, 2);
  });

  test('the dice: the same seeds and the same play give the same Towns; the Town dice alone move them', () {
    List<int> run(int seed, int dice) => slots(towns(seed: seed, dice: Random(dice)), 60);
    expect(run(4, 11), run(4, 11));
    expect(run(9, 11), run(4, 11), reason: "only the Town dice draw the Towns, whatever the game's other seeds");
    expect(run(4, 12), isNot(run(4, 11)));
  });

  test('the boss schedule is untouched: the same queue every wave with a Town every 5 waves and with none (a mini boss '
      'every 3rd, the boss every 5th), and the same Boss Chests', () {
    final on = towns(rules: always)..offers = true, off = towns(rules: noTowns)..offers = true;
    for (var w = 1; w <= 30; w++) {
      final a = winWave(on), b = winWave(off);
      expect(a, b, reason: 'wave $w');
      expect(a.any((s) => s.$2 == Tier.miniBoss), w % miniBossEvery == 0, reason: 'wave $w');
      expect(a.any((s) => s.$2 == Tier.boss), w % bossEvery == 0, reason: 'wave $w');
      expect([for (final c in on.chests) c.wave], [for (final c in off.chests) c.wave], reason: 'wave $w');
    }
    expect(on.townLast, 27, reason: 'Towns before waves 7, 12, 17, 22, 27 came and went');
    expect(on.chests, isNotEmpty);
  });

  test('a Town changes nothing else: a seeded 8-wave run played through a Town (a probe going through it before wave 7) '
      'and with none is the same, wave by wave; no relic or item drops, the forge\'s rule: materials do (decisions-log '
      '221, 246)', () {
    String digest(Game g) => [
          'wave ${g.wave} t ${g.t} gold ${g.gold} lives ${g.lives} kills ${g.kills} score ${g.score}',
          for (final u in g.units) '${u.side.name} ${u.type} ${u.tier.name} ${u.alive} ${u.hp} ${u.pos}',
        ].join('\n');
    List<String> play(Game g) {
      final out = <String>[];
      for (var w = 0; w < 8 && !g.over; w++) {
        for (final t in ['soldier', 'archer', 'knight']) {
          if (g.gold >= g.priceOf(t)) g.autoPlace(t);
        }
        for (var i = 0; i < 300; i++) {
          g.tick(1 / 30);
        }
        g.startWave();
        for (var i = 0; i < 30 * 600 && g.waveActive && !g.over; i++) {
          g.tick(1 / 30);
        }
        out.add(digest(g));
      }
      return out;
    }

    Game rich(Game g) => g
      ..gold = 100000
      ..capacity = 12;
    // The Bag aside: with the Towns on the forge drops no item (forge_drops_test.dart pins that it draws the same loot dice
    // and throws the items away), and no item is given here.
    final on = rich(towns(rules: always))..townPolicy = 'leave', off = rich(towns(rules: noTowns));
    expect(play(on), play(off));
    expect((on.over, on.wave, on.townLast, off.townLast), (false, 8, 7, 2), reason: 'the Town before wave 7 came, and none');
    for (final g in [on, off]) {
      expect((g.relicBag.isEmpty, g.inventory.isEmpty, g.materials.isNotEmpty), (true, true, true),
          reason: 'materials drop and relics and items don\'t');
    }
  });

  test('telemetry: the Town events go out as they happen; a won wave record says what the roll after it did', () {
    expect(telemetryVersion, greaterThanOrEqualTo(9)); // 9 brought the Towns'; later versions keep it (10: the forge's, 11: the Tavern's)
    final sink = _Kept();
    final g = towns(rules: always)..townPolicy = 'leave';
    TelemetryAdapter([sink], installId: 'i', session: 's', platform: 'test', now: () => DateTime.utc(2026, 10, 4)).attach(g);
    for (var w = 1; w <= 8; w++) {
      winWave(g);
    }
    final waves = {for (final r in sink.of('wave')) r['wave'] as int: r['town']};
    expect(waves, {
      1: {'blocked': true},
      2: {'blocked': true},
      3: {'blocked': true},
      4: {'blocked': true},
      5: {'chance': 1.0, 'hit': true, 'slot': 7},
      6: {'marked': 7},
      7: {'blocked': true},
      8: {'blocked': true},
    });
    final events = [for (final r in sink.of('event')) r['event'] as Map<String, dynamic>];
    expect([for (final e in events) if ('${e['kind']}'.startsWith('town')) (e['kind'], e['slot'])],
        [('townMarked', 7), ('townEntered', 7), ('townLeft', 7)]);
    expect(sink.records.where((r) => r['rec'] == 'event' && (r['event'] as Map)['kind'] == 'townRolled'), isEmpty,
        reason: 'the roll goes into the wave record only');
  });

  test("the chip's tooltip: the wave after which the Town comes and which Town it is (decisions-log 326), the Smithy, "
      'the Tavern (decisions-log 268), and the Shop once it is open (in every Town as shipped, decisions-log 253) with '
      'what the Town pays well for', () {
    final g = towns()
      ..wave = 10
      ..townAt = 12;
    const millbrook = 'Pays well for Boots, Potion, Gloves and Prayer Beads.';
    expect(g.townTip.$1, 'Town after wave 11: Millbrook, a farming village');
    expect(g.townTip.$2, ['Smithy: craft items and relics', 'Tavern: buy boosts', 'Shop: buy and sell', millbrook],
        reason: 'the forge on: items too');
    g.townRules = TownRules.patch({
      'shop': {'from': 15},
    });
    expect(g.townTip.$2, ['Smithy: craft items and relics', 'Tavern: buy boosts'], reason: 'a later shop.from: no Shop before it');
    g
      ..wave = 14
      ..townAt = 16
      ..townCount = 3;
    expect(g.townTip.$1, 'Town after wave 15: Ironvale, a mining town');
    expect(g.townTip.$2, [
      'Smithy: craft items and relics',
      'Tavern: buy boosts',
      'Shop: buy and sell',
      'Pays well for Shield, Leather Cap, Gloves and Amulet.',
    ]);
  });
}
