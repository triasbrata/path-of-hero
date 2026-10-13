// The Dungeon's fight (decisions-log 336, 337; lib/dungeon.dart, lib/gambits.dart, lib/dungeon_gen.dart,
// lib/dungeon_nav.dart; docs/dungeon-design.md sections 2-6): the gauges and the field's damage a second, the flow of an
// action (walk while the gauge fills, fire when full and in reach), the 75% rule's one queue slot, the player's command
// first, the gambits' reading, a target lost, the monsters' temper, aggro and leash, the rooms' appearances, following,
// the walk grid, the leader's switch, knock-outs and the wipe.
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';

/// A seeded game in a Town with [types] in its army, gone into the Dungeon with them (the first leads).
Game trip(List<String> types, {int seed = 3}) {
  final g = Game(Random(seed), Random(seed + 100))
    ..seedDice(seed)
    ..gold = 100000
    ..capacity = 20;
  final picks = <Unit>[];
  for (final t in types) {
    final had = g.troops.where((u) => u.type == t).toSet();
    if (t != 'priest' || had.isEmpty) expect(g.autoPlace(t), isTrue, reason: t);
    picks.add(g.troops.firstWhere((u) => u.type == t && !picks.contains(u)));
  }
  g.inTown = true;
  expect(g.enterDungeon(picks), isTrue);
  return g;
}

/// A monster that never acts (stunned for good) with [hp] HP, hostile, at [at].
Unit dummy(Game g, Point<double> at, {double hp = 1e6, String type = 'slime'}) {
  final u = g.addDungeonFoe(type, at)
    ..maxHp = hp.round()
    ..hp = hp
    ..stunUntil = 1e9;
  g.dungeon!.minds[u]!
    ..hostile = true
    ..reachedAt = 1e9;
  return u;
}

void ticks(Game g, double seconds, [void Function()? each]) {
  for (var i = 0; i < (seconds * 30).round() && g.dungeon != null; i++) {
    g.tick(1 / 30);
    each?.call();
  }
}

Mind mind(Game g, Unit u) => g.dungeon!.minds[u]!;

void main() {
  group('gauges', () {
    test('turn time is twice the attack time, at least 1.0 s; each of an Attack\'s two blows is the field blow × turn ÷ '
        'attack ÷ 2', () {
      final g = trip(['soldier', 'wizard']);
      final d = g.dungeon!, soldier = d.party[0], wizard = d.party[1];
      expect(g.turnOf(soldier), closeTo(2 * g.attackEvery(soldier), 1e-9));
      expect(g.turnOf(wizard), closeTo(2 * g.attackEvery(wizard), 1e-9));
      soldier.stats = Stats(hp: 90, cost: 0, speed: 22, dmg: 10, range: 12, rate: 0.2);
      expect(g.attackEvery(soldier), minAttackInterval);
      expect(g.turnOf(soldier), turnMin);
      expect(g.blowKOf(soldier), closeTo(1 / 0.3 / 2, 1e-9));
    });

    test('a soldier, a wizard and a unit at the attack floor deal the field\'s damage a second (within 2%) on a dummy '
        'over 300 s', () {
      for (final (type, floor) in [('soldier', false), ('wizard', false), ('soldier', true)]) {
        final g = trip([type]);
        final d = g.dungeon!, u = d.party.first;
        if (floor) u.stats = Stats(hp: 90, cost: 0, speed: 22, dmg: 10, range: 12, rate: 0.2);
        d.gambits = false;
        final foe = dummy(g, u.pos + const Point(10, 0));
        g.command(u, ActKind.attack, foe);
        final hp0 = foe.hp, field = hitTaken(u.stats.dmg, foe.stats.def) / g.attackEvery(u);
        ticks(g, 300);
        final dps = (hp0 - foe.hp) / 300;
        expect(dps, closeTo(field, field * 0.02), reason: '$type floor $floor');
      }
    });

    test('a stun stops the gauge', () {
      final g = trip(['soldier']);
      final u = g.dungeon!.party.first;
      ticks(g, 0.5);
      final before = mind(g, u).gauge;
      u.stunUntil = g.t + 1;
      ticks(g, 0.9);
      expect(mind(g, u).gauge, before);
    });
  });

  group('the flow of an action', () {
    test('the member walks to its target while its gauge fills, never fires out of reach, fires the moment it arrives '
        'when already full; moving never empties the gauge', () {
      final g = trip(['soldier']);
      final d = g.dungeon!, u = d.party.first;
      d.gambits = false;
      ticks(g, 2); // the gauge full, standing
      expect(mind(g, u).full, isTrue);
      final foe = dummy(g, u.pos + const Point(80, 0));
      g.command(u, ActKind.attack, foe);
      var fired = false;
      ticks(g, 8, () {
        if (fired) return;
        if (foe.hp < foe.maxHp) {
          fired = true;
          expect(g.reaches(u, foe), isTrue, reason: 'it fired in reach');
        } else {
          expect(mind(g, u).full, isTrue, reason: 'walking keeps it full');
        }
      });
      expect(fired, isTrue);
    });

    test('a target lost: the action is dropped with "target lost" shown, the queued one comes next, else the gambits, '
        'else the member waits; the gauge stays', () {
      final g = trip(['soldier']);
      final d = g.dungeon!, u = d.party.first;
      d.gambits = false;
      ticks(g, 2);
      final a = dummy(g, u.pos + const Point(200, 0)), b = dummy(g, u.pos + const Point(220, 10));
      g.command(u, ActKind.attack, a);
      g.command(u, ActKind.attack, b); // full gauge: queued behind a
      expect(mind(g, u).queued?.target, b);
      a.hp = 0;
      a.dying = 0;
      ticks(g, 1 / 30);
      final m = mind(g, u);
      expect(m.act?.target, b);
      expect(m.queued, isNull);
      expect(m.full, isTrue);
      expect(g.liveRows().first.lost, isTrue);
      b.dying = 0;
      ticks(g, 1 / 30);
      expect(m.act, isNull, reason: 'nothing queued and the leader\'s gambits off: it waits');
    });
  });

  group('the 75% rule', () {
    test('under 75% a new action replaces the current one at once, the gauge kept; at 75% or more it is queued: the '
        'current fires first, then the queued one starts from 0; a later one replaces the queued one, never the current', () {
      final g = trip(['soldier']);
      final d = g.dungeon!, u = d.party.first, m = mind(g, u);
      d.gambits = false;
      final a = dummy(g, u.pos + const Point(230, 0)), b = dummy(g, u.pos + const Point(230, 30));
      final c = dummy(g, u.pos + const Point(10, 0));
      m.gauge = 0.5;
      g.command(u, ActKind.attack, a);
      g.command(u, ActKind.attack, b);
      expect((m.act?.target, m.queued, m.gauge), (b, null, 0.5));
      m.gauge = 0.8;
      g.command(u, ActKind.attack, a);
      expect((m.act?.target, m.queued?.target), (b, a));
      g.command(u, ActKind.attack, c);
      expect((m.act?.target, m.queued?.target), (b, c), reason: 'one slot: c replaced a, never the current');
      // The current fires when it gets there; then the queued one, from an empty gauge.
      m.gauge = 1;
      ticks(g, 15, () {});
      expect(b.hp, lessThan(b.maxHp));
      expect(m.queued, isNull);
    });
  });

  group('the player\'s command first', () {
    test('with the gambits off an Attack repeats on the same target; with them on it is done once, then the gambits; a '
        'gambit never replaces a command, current or queued', () {
      final g = trip(['soldier', 'archer']);
      final d = g.dungeon!, archer = d.party[1];
      final near = dummy(g, archer.pos + const Point(30, 0)), far = dummy(g, archer.pos + const Point(55, 30));
      // The archer's gambits are on (it is not the leader); its rules would pick the nearest or lowest-HP foe.
      far.hp = far.maxHp * 0.1; // the lowest HP: rule 2 picks it
      final m = mind(g, archer)..gauge = 0.2;
      g.command(archer, ActKind.attack, near);
      ticks(g, 0.6);
      expect(m.act?.target, near, reason: 'a gambit never replaces a command');
      expect(m.act?.byPlayer, isTrue);
      ticks(g, 4);
      expect(m.act?.byGambit, isTrue, reason: 'after it fired once, the gambits took over');
      // The leader's gambits are off: its Attack repeats.
      final lead = d.leader, lm = mind(g, lead);
      final foe = dummy(g, lead.pos + const Point(10, 0));
      g.command(lead, ActKind.attack, foe);
      var hits = 0;
      var last = foe.hp;
      ticks(g, 8, () {
        if (foe.hp < last) hits++;
        last = foe.hp;
      });
      expect(hits, greaterThan(4), reason: 'two blows a turn, turn after turn');
      expect(lm.act?.target, foe);
    });
  });

  group('gambits', () {
    test('the default lists by type, from the design\'s table', () {
      expect(defaultGambits('soldier').map((r) => '$r'), ['selfHp30->skill', 'foeTargetingAlly->attack', 'foeLeaderTarget->attack', 'foeNearest->attack']);
      expect(defaultGambits('priest').map((r) => '$r'), ['allyHp50->heal', 'allyHp70->skill', 'foeUndead->attack']);
      expect(defaultGambits('archer').first.when, GambitIf.foeCrowd);
      for (final t in troopTypes.keys) {
        expect(defaultGambits(t), isNotEmpty, reason: t);
      }
    });

    test('a skill rule never fits in M1; a foe rule sees only hostile foes: a neutral monster at peace is left alone', () {
      final g = trip(['soldier', 'knight']);
      final d = g.dungeon!, knight = d.party[1];
      final slime = g.addDungeonFoe('slime', knight.pos + const Point(30, 0)); // neutral, at peace
      expect(g.readGambits(knight), isNull);
      d.minds[slime]!
        ..hostile = true
        ..reachedAt = 1e9;
      final (i, act) = g.readGambits(knight)!;
      expect((i, act.kind, act.target), (3, ActKind.attack, slime), reason: 'foe nearest; Circle Slash (a skill) skipped');
    });

    test('a higher rule that fits replaces a lower one; the same rule keeps its target while it holds', () {
      final g = trip(['soldier', 'knight']);
      final d = g.dungeon!, knight = d.party[1], m = mind(g, knight);
      final a = dummy(g, knight.pos + const Point(40, 0)), b = dummy(g, knight.pos + const Point(40, 1));
      ticks(g, 1 / 30);
      expect(m.act?.rule, 3);
      final first = m.act!.target;
      // Equally near: the rule keeps its target at every read.
      ticks(g, 2, () => expect(m.act?.target, first));
      // A foe goes for the soldier (an ally): rule 1 fits and replaces rule 3 under 75%.
      final other = first == a ? b : a;
      d.minds[other]!.prey = d.party[0];
      m.gauge = 0.3;
      m.readAt = 0;
      ticks(g, 1 / 30);
      expect((m.act?.rule, m.act?.target), (1, other));
    });

    test('the condition is checked again before it fires: no heal wasted on an ally healed meanwhile', () {
      final g = trip(['soldier', 'priest']);
      final d = g.dungeon!, soldier = d.party[0], priest = d.party[1], m = mind(g, priest);
      soldier.hp = soldier.maxHp * 0.4;
      ticks(g, 1 / 30);
      expect((m.act?.kind, m.act?.target), (ActKind.heal, soldier));
      soldier.hp = soldier.maxHp * 0.9; // healed by something else
      final mp = priest.mp;
      m.gauge = 1;
      ticks(g, 1 / 30);
      expect(priest.mp, greaterThanOrEqualTo(mp), reason: 'no heal cast');
      expect(m.act?.kind, isNot(ActKind.heal));
    });
  });

  group('monsters', () {
    test('an aggressive monster turns hostile on a member inside its aggro radius; a neutral one only once hit; an orc '
        'calls its kind within 96', () {
      final g = trip(['soldier']);
      final d = g.dungeon!, u = d.party.first;
      d.gambits = false;
      final bat = g.addDungeonFoe('bat', u.pos + const Point(100, 0));
      final orc = g.addDungeonFoe('orc', u.pos + const Point(60, 20)), orc2 = g.addDungeonFoe('orc', u.pos + const Point(120, 20));
      final slime = g.addDungeonFoe('slime', u.pos + const Point(40, -20));
      ticks(g, 1 / 30);
      expect([d.hostile(bat), d.hostile(orc), d.hostile(slime)], [false, false, false], reason: 'the bat 100 away, its radius 72');
      bat.pos = u.pos + const Point(60, 0);
      ticks(g, 1 / 30);
      expect(d.hostile(bat), isTrue);
      expect(mind(g, bat).prey, u);
      g.command(u, ActKind.attack, orc);
      ticks(g, 4);
      expect(d.hostile(orc), isTrue);
      expect(d.hostile(orc2), isTrue, reason: 'called by its kind');
      expect(d.hostile(slime), isFalse);
    });

    test('the leash: past 320 from home a hostile monster walks home, mending, and is neutral again there', () {
      final g = trip(['soldier']);
      final d = g.dungeon!, u = d.party.first;
      final orc = g.addDungeonFoe('orc', const Point(350, 60));
      final m = mind(g, orc)
        ..home = const Point(16, 60)
        ..hostile = true
        ..prey = u
        ..reachedAt = g.t;
      orc.hp = orc.maxHp * 0.3;
      u.pos = const Point(300, 100);
      ticks(g, 1 / 30);
      expect(m.homing, isTrue);
      ticks(g, 40);
      expect((m.homing, m.hostile), (false, false));
      expect(orc.hp, orc.maxHp);
    });

    test('a room\'s monsters appear as the leader nears it, one or two at a time, never near its entrance, and never again',
        () {
      final g = trip(['knight']);
      final d = g.dungeon!, room = d.floor.rooms[1];
      expect(room.monsters.length, inInclusiveRange(3, 4));
      d.leader.pos = Point(room.x0 - spawnNear + 20, d.leader.pos.y);
      ticks(g, 0.2);
      expect(d.called, contains(room.index));
      var most = 0;
      ticks(g, 12, () => most = max(most, g.enemies.length));
      expect(g.enemies.length, room.monsters.length);
      for (final e in g.enemies) {
        final home = d.minds[e]!.home; // where it appeared
        expect(home.distanceTo(Point(room.x0, room.midY)), greaterThanOrEqualTo(appearClear));
        expect(d.floor.grid.freeAt(home), isTrue);
      }
      final before = d.due.length;
      ticks(g, 1);
      expect(d.due.length, lessThanOrEqualTo(before));
      expect(d.called.where((i) => i == room.index), hasLength(1));
    });
  });

  group('the party', () {
    test('followers keep their spots behind the leader by role, and are put beside it past 400', () {
      final g = trip(['knight', 'soldier', 'archer']);
      final d = g.dungeon!, lead = d.leader;
      d.stick = const Point(1, 0);
      ticks(g, 6);
      d.stick = const Point(0, 0);
      ticks(g, 4);
      for (final u in d.party.skip(1)) {
        expect(u.pos.distanceTo(g.followSpot(u)), lessThan(followSlack + 1), reason: u.type);
        expect(u.pos.x, lessThan(lead.pos.x), reason: '${u.type} behind the leader');
      }
      final archer = d.party[2];
      archer.pos = lead.pos - const Point(450, 0);
      ticks(g, 1 / 30);
      expect(archer.pos.distanceTo(lead.pos), lessThan(80));
    });

    test('a follower never chases a foe more than 160 from the leader', () {
      final g = trip(['knight', 'soldier']);
      final d = g.dungeon!, soldier = d.party[1];
      final far = dummy(g, d.leader.pos + const Point(260, 0));
      g.command(soldier, ActKind.attack, far);
      ticks(g, 5);
      expect(soldier.pos.distanceTo(d.leader.pos), lessThan(chaseCap));
    });

    test('A* walks round what blocks, and everyone stays on free cells of the band', () {
      final grid = WalkGrid(40, 16)..mark(0, 8, 320, 112);
      grid.mark(150, 8, 166, 96, blocked: true); // a wall with a gap at the bottom
      final way = grid.path(const Point(100, 50), const Point(220, 50))!;
      expect(way, isNotEmpty);
      var at = const Point(100.0, 50.0);
      for (final p in way) {
        expect(grid.clear(at, p), isTrue);
        at = p;
      }
      expect(way.any((p) => p.y > 96), isTrue, reason: 'round the bottom of the wall');
      expect(grid.slide(const Point(140, 50), const Point(20, 5)), const Point(140.0, 55.0), reason: 'slides along it');
      final g = trip(['knight', 'archer', 'priest']);
      final d = g.dungeon!;
      d.stick = const Point(1, 0.4);
      ticks(g, 20, () {
        for (final u in d.party) {
          if (d.standing(u)) expect(d.floor.grid.freeAt(u.pos), isTrue, reason: '${u.type} at ${u.pos}');
        }
      });
    });

    test('Up / Down cycle the standing members, wrapping; a knocked-out leader passes the lead on; the last one down '
        'wipes: back to the Town, no heart and no troop lost, the army as it was', () {
      final g = trip(['knight', 'soldier', 'archer']);
      final d = g.dungeon!;
      final [k, s, a] = d.party;
      g.switchLeader(1);
      expect(d.leader, s);
      g.switchLeader(1);
      g.switchLeader(1);
      expect(d.leader, k);
      g.switchLeader(-1);
      expect(d.leader, a);
      final lives = g.lives;
      d.gambits = false; // nobody hits back: the orc keeps the prey it is given
      a.hp = 1;
      final foe = g.addDungeonFoe('orc', a.pos + const Point(10, 0))
        ..maxHp = 1000000
        ..hp = 1e6;
      g.dungeon!.minds[foe]!
        ..hostile = true
        ..prey = a
        ..reachedAt = g.t;
      ticks(g, 4);
      expect(mind(g, a).down, isTrue);
      expect(d.leader, isNot(a));
      for (final u in [k, s]) {
        u.hp = 0.5;
        g.dungeon!.minds[foe]!.prey = u;
        ticks(g, 4);
      }
      ticks(g, wipeDelay + 0.5);
      expect(g.dungeon, isNull);
      expect(g.tripNews, (end: TripEnd.fell, floor: 1));
      expect(g.lives, lives);
      expect(g.troops.where((u) => u.alive), hasLength(4), reason: 'the three picked and the free priest');
      expect(g.troops.every((u) => u.hp == u.maxHp), isTrue);
    });
  });

  test('the floor: 4-6 rooms, the arrival room first with the save point and no monsters, the portal at the right end, '
      'every room\'s band on the field\'s rows; the same seed makes the same floor', () {
    for (final seed in [1, 2, 3, 4, 5]) {
      final f = makeFloor(seed, 1);
      expect(f.rooms.length, inInclusiveRange(4, 6));
      expect(f.rooms.first.monsters, isEmpty);
      expect(f.grid.freeAt(f.savePoint), isTrue);
      expect(f.grid.freeAt(f.portal), isTrue);
      expect(f.portal.x, greaterThan(f.rooms.last.x0));
      for (final r in f.rooms) {
        expect(r.bottom, lessThanOrEqualTo(fieldH - 2));
        if (r.index > 0) expect(r.monsters.every((m) => ['slime', 'bat'].contains(m.$1)), isTrue, reason: 'floor 1 is wave 3');
      }
      expect(f.grid.path(f.savePoint, f.portal), isNotNull, reason: 'seed $seed: the portal is reachable');
      final again = makeFloor(seed, 1);
      expect([for (final r in again.rooms) '${r.kind} ${r.x0} ${r.depth} ${r.monsters}'],
          [for (final r in f.rooms) '${r.kind} ${r.x0} ${r.depth} ${r.monsters}']);
    }
  });
}
