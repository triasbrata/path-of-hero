import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';
import 'package:tower_defense/main.dart' show logLine;

import 'hero_skill_helpers.dart';
import 'real_rules.dart';

// The game's event stream (#60, lib/game_events.dart): each kind lands in the log once, where it happens; the
// log's cap; the listeners (the telemetry, #64, subscribes there) and the telemetry's own events, which reach
// them but never the log; the JSON the telemetry sends; not saved.

/// The log's events of type [T], oldest first.
List<T> of<T extends GameEvent>(Game g) => g.log.entries.whereType<T>().toList();

/// What [g]'s listeners hear from now on of the telemetry's own events.
List<TraceEvent> traces(Game g) {
  final heard = <TraceEvent>[];
  g.listeners.add((e) {
    if (e is TraceEvent) heard.add(e);
  });
  return heard;
}

/// Starts wave [wave] with nothing to spawn.
void startAt(Game g, int wave) => g
  ..wave = wave - 1
  ..startWave()
  ..queue.clear();

/// Wins the wave on at once: one monster already beaten, and a tick of no time.
void winNow(Game g) {
  foeAt(g, 'slime', const Point(200.0, 60.0)).gone = true;
  g.tick(0);
}

/// Ticks [g] by 0.05 s until [done], at most [max] times (a game over stops the clock, so never "until a
/// time"); fails with [why] if it never is.
void tickUntil(Game g, bool Function() done, String why, {int max = 200}) {
  for (var i = 0; i < max && !done(); i++) {
    g.tick(0.05);
  }
  expect(done(), isTrue, reason: why);
}

void main() {
  test('a troop falling is logged once, with the monster that struck it and its rank', () {
    final g = bareGame()..skills = false;
    final s = placeNow(g, 'soldier', 2, 3);
    startAt(g, 1);
    s
      ..hp = 1
      ..cd = hold;
    foeAt(g, 'orc', s.pos + const Point(8.0, 0), Tier.elite).busyUntil = 0; // in reach, and it strikes
    tickUntil(g, () => !s.alive, 'the soldier at 1 HP falls to the orc beside it', max: 100);
    final fell = of<TroopFell>(g);
    expect(fell.length, 1);
    expect((fell.single.name, fell.single.type, fell.single.hero, fell.single.killer, fell.single.killerTier),
        (s.name, 'soldier', false, 'orc', Tier.elite));
  });

  test('a troop casting its skill is logged once, by the skill\'s name', () {
    final g = bareGame();
    final s = placeNow(g, 'soldier', 2, 3);
    startAt(g, 1);
    s.cd = hold;
    foeAt(g, 'orc', s.pos + Point(s.stats.range, 0)); // a foe in reach: Hold Fast wants it (decisions-log 298)
    g.tick(0.05);
    expect(of<SkillCast>(g).map((e) => (e.name, e.type, e.skill)), [(s.name, 'soldier', troopSkills['soldier']!.name)]);
  });

  test('a Hero casting its own skill is logged once, with the skill', () {
    final (g, h) = heroCaster(HeroSkill.judgement);
    foeAt(g, 'skeleton', h.pos + Point(h.stats.range, 0));
    g.tick(0.05);
    expect(h.heroSkillAt, g.t); // it cast
    expect(of<HeroSkillCast>(g).map((e) => (e.name, e.type, e.skill)), [(h.name, h.type, HeroSkill.judgement)]);
  });

  test('a strong monster coming in is logged once; a normal or an elite one is not', () {
    final g = bareGame();
    placeNow(g, 'knight_templar', 0, 3)
      ..cd = hold
      ..hp = 1e9; // it outlasts them all, so the game goes on
    startAt(g, 1);
    g.queue.addAll([('orc', Tier.normal), ('orc', Tier.elite), ('orc', Tier.highElite), ('werebear', Tier.miniBoss), (boss, Tier.boss)]);
    for (var i = 0; i < 400 && g.queue.isNotEmpty; i++) {
      g.tick(0.05);
    }
    expect(g.queue, isEmpty);
    expect(of<StrongFoe>(g).map((e) => (e.type, e.tier)), [('orc', Tier.highElite), ('werebear', Tier.miniBoss), (boss, Tier.boss)]);
  });

  test('the battle log names a monster with its rank first, as its plate and the boss bars do; a normal one without its rank', () {
    expect(logLine(TroopFell(4, 1, name: 'Budi', type: 'soldier', killer: 'orc_rider', killerTier: Tier.miniBoss)),
        'Budi (${troopTypeNames['soldier']}) fell to ${tierNames[Tier.miniBoss]} ${monsterTypeNames['orc_rider']}');
    expect(logLine(TroopFell(4, 1, name: 'Budi', type: 'soldier', killer: 'orc_rider', killerTier: Tier.miniBoss)),
        'Budi (Soldier) fell to Mini Boss Orc Rider');
    expect(logLine(TroopFell(4, 1, name: 'Budi', type: 'soldier', killer: 'orc', killerTier: Tier.normal)), 'Budi (${troopTypeNames['soldier']}) fell to Orc');
    expect(logLine(StrongFoe(5, 1, type: boss, tier: Tier.boss)), '${tierNames[Tier.boss]} appears: ${monsterTypeNames[boss]}');
    expect(logLine(StrongFoe(6, 1, type: 'werebear', tier: Tier.miniBoss)), 'Mini Boss appears: Werebear');
  });

  test('a Hero made on a heroEvery-th win is logged once, after the win, with its attributes and skill', () {
    final g = bareGame()
      ..heroes = Random(3)
      ..townRules = noTowns; // no Town marked after the win (its events: town_test.dart)
    placeNow(g, 'knight', 2, 3);
    startAt(g, heroEvery);
    winNow(g);
    final h = g.troops.single, made = of<HeroMade>(g);
    expect(made.length, 1);
    expect((made.single.name, made.single.type, made.single.skill), (h.name, 'knight', h.heroSkill));
    expect(made.single.stats, h.heroStats);
    expect(g.log.entries.map((e) => e.kind), [EventKind.waveWon, EventKind.heroMade]);
    expect(of<WaveEnded>(g).map((e) => (e.wave, e.won)), [(heroEvery, true)]);
  });

  test('an awakening is logged once, with its level; an item that awakens nothing is not', () {
    final g = bareGame();
    final recipe = g.gradeSet('soldier', 1), items = [for (final e in recipe.entries) ...List.filled(e.value, e.key)];
    g.inventory.addAll(recipe);
    for (final (i, item) in items.indexed) {
      expect(g.useItem(item, 'soldier'), isTrue, reason: item.name);
      expect(of<Awakened>(g).length, i == items.length - 1 ? 1 : 0, reason: 'item $i');
    }
    expect((of<Awakened>(g).single.type, of<Awakened>(g).single.level), ('soldier', 1));
  });

  test('a lost game logs its wave lost once, however long it is ticked after', () {
    final g = bareGame()..lives = 1;
    placeNow(g, 'knight', 2, 3);
    startAt(g, 4);
    g.units.add(Unit(Side.enemy, 'slime', enemyTypes['slime']!, Point(g.baseX - 1, 60))); // past the base
    for (var i = 0; i < 5; i++) {
      g.tick(0.05);
    }
    expect(g.over, isTrue);
    expect(of<WaveEnded>(g).map((e) => (e.wave, e.won)), [(4, false)]);
  });

  test('the log keeps the last logSize events, the oldest dropped, and counts them all', () {
    final log = EventLog();
    for (var i = 0; i < logSize + 5; i++) {
      log.add(WaveEnded(i, 0, won: true));
    }
    expect((log.entries.length, log.total), (logSize, logSize + 5));
    expect((log.entries.first.wave, log.newestFirst.first.wave), (5, logSize + 4));
  });

  test('every listener gets each event as it is logged, in order, and the telemetry\'s own ones, which the log never keeps', () {
    final g = bareGame()..townRules = noTowns; // the roll after the win, never a Town marked (town_test.dart)
    final heard = <GameEvent>[], also = <EventKind>[];
    g.listeners
      ..add(heard.add)
      ..add((e) => also.add(e.kind));
    placeNow(g, 'knight', 2, 3);
    startAt(g, heroEvery);
    winNow(g);
    expect(heard.where((e) => e is! TraceEvent), g.log.entries);
    expect(also, [EventKind.bought, EventKind.waveStarted, EventKind.waveWon, EventKind.heroMade, EventKind.townRolled]); // the Towns' roll
    expect(g.log.entries.whereType<TraceEvent>(), isEmpty);
  });

  test('a wave starting tells the listeners the army, awakenings, Heroes, gold, capacity, lives and bags it begins with', () {
    final g = bareGame();
    final heard = traces(g);
    placeNow(g, 'soldier', 2, 2);
    placeNow(g, 'archer', 0, 3);
    placeNow(g, 'archer', 0, 4);
    placeNow(g, 'knight', 2, 4)
      ..hero = true
      ..heroSkill = HeroSkill.cleave;
    final recipe = g.gradeSet('soldier', 1);
    g.inventory.addAll(recipe);
    for (final e in recipe.entries) {
      for (var i = 0; i < e.value; i++) {
        expect(g.useItem(e.key, 'soldier'), isTrue);
      }
    }
    g.inventory[Item.potion] = 2;
    g.relicBag[Relic.fang] = 1;
    startAt(g, 3);
    final s = heard.whereType<WaveStarted>().single;
    expect((s.wave, s.t, s.gold, s.capacity, s.lives), (3, g.t, g.gold, g.capacity, g.lives));
    expect(s.army, {'soldier': 1, 'archer': 2, 'knight': 1});
    expect(s.levels, {'soldier': 1});
    expect(s.heroes, [('knight', 'cleave')]);
    expect(s.bag, {'potion': 2});
    expect(s.relics, {'fang': 1});
    expect(jsonDecode(jsonEncode(s.toJson()))['heroes'], [
      {'type': 'knight', 'skill': 'cleave'},
    ]);
  });

  test('each monster coming on tells the listeners its type and rank, from the wave\'s queue or raised by a necromancer', () {
    final g = bareGame();
    placeNow(g, 'knight_templar', 0, 3)
      ..cd = hold
      ..hp = 1e9; // it outlasts them all, so the game goes on
    startAt(g, 1);
    final heard = traces(g);
    g.queue.addAll([('orc', Tier.normal), ('slime', Tier.elite), ('werebear', Tier.miniBoss)]);
    for (var i = 0; i < 200 && g.queue.isNotEmpty; i++) {
      g.tick(0.05);
    }
    expect(heard.whereType<MonsterSpawned>().map((e) => (e.type, e.tier, e.raised)),
        [('orc', Tier.normal, false), ('slime', Tier.elite, false), ('werebear', Tier.miniBoss, false)]);

    final n = bareGame()..wave = 5;
    final raised = traces(n);
    final u = n.monster(boss, Tier.boss, const Point(250, 60))..summonCd = 0;
    n.units.add(u);
    n.tick(0.05);
    expect(n.minionsOf(u), hasLength(2));
    expect(raised.whereType<MonsterSpawned>().map((e) => (e.type, e.tier, e.raised)), List.filled(2, (minion, Tier.normal, true)));
  });

  test('gold spent tells the listeners what it bought and the price; an item or a relic given, to which troop type', () {
    final g = bareGame()..capacity = capacityStart;
    final heard = traces(g);
    final price = g.priceOf('archer');
    final a = placeNow(g, 'archer', 0, 3);
    final more = g.capacityCost;
    g.buyCapacity();
    g.inventory[Item.bow] = 1;
    g.relicBag[Relic.thorns] = 1;
    expect(g.useItem(Item.bow, 'archer'), isTrue);
    expect(g.useRelic(Relic.thorns, a), isTrue);
    expect(g.useRelic(Relic.thorns, a), isFalse); // refused: nothing
    expect(heard.map((e) => e.toJson()..remove('t')), [
      {'v': eventVersion, 'kind': 'bought', 'wave': 0, 'type': 'archer', 'cost': price},
      {'v': eventVersion, 'kind': 'bought', 'wave': 0, 'type': null, 'cost': more},
      {'v': eventVersion, 'kind': 'itemUsed', 'wave': 0, 'item': 'bow', 'type': 'archer'},
      {'v': eventVersion, 'kind': 'relicUsed', 'wave': 0, 'relic': 'thorns', 'type': 'archer'},
    ]);
  });

  test('a relic taken off tells the listeners which, from which troop type; a refused one nothing (#91)', () {
    final g = bareGame();
    final heard = traces(g);
    final a = placeNow(g, 'archer', 0, 3)..relics.add(Relic.thorns);
    expect(g.takeOff(Relic.thorns, a), isTrue);
    expect(g.takeOff(Relic.thorns, a), isFalse); // it holds none now: nothing
    expect(heard.map((e) => e.toJson()..remove('t')), [
      {'v': eventVersion, 'kind': 'bought', 'wave': 0, 'type': 'archer', 'cost': troopTypes['archer']!.cost},
      {'v': eventVersion, 'kind': 'relicTakenOff', 'wave': 0, 'relic': 'thorns', 'type': 'archer'},
    ]);
    expect(g.log.entries.whereType<RelicTakenOff>(), isEmpty); // the telemetry's only, like a relic given
  });

  test('the store tells the listeners what it sold and for how much, and what it bought back; a refused deal nothing', () {
    final g = bareGame()
      ..wave = storeFrom
      ..inTown = true; // the Shop deals only in a Town
    final heard = traces(g);
    final price = g.buyPrice(Relic.grail), back = g.marketSum(Item.potion, 0, 2), margin = g.freshMargin(Item.potion);
    g.inventory[Item.potion] = 3;
    expect(g.buy(Relic.grail), isTrue);
    expect(g.sell(Item.potion, 2), 2);
    g.gold = 0;
    expect(g.buy(Item.sword), isFalse); // no gold
    expect(heard.map((e) => e.toJson()..remove('t')), [
      {'v': eventVersion, 'kind': 'storeBought', 'wave': storeFrom, 'item': null, 'relic': 'grail', 'cost': price},
      {
        'v': eventVersion, 'kind': 'storeSold', 'wave': storeFrom, 'item': 'potion', 'relic': null, 'n': 2, 'gain': back, //
        'margin': (margin * 100).round() / 100, 'pressure': 0, // the market's (decisions-log 326): each at its own step
      },
    ]);
  });

  test('a wave stalling tells the listeners once, when its monsters begin to march', () {
    final g = bareGame();
    startAt(g, 1);
    final heard = traces(g);
    foeAt(g, 'slime', const Point(400.0, 60.0)); // it never moves: no progress
    tickUntil(g, () => g.marching, 'the wave stalls after stallTime', max: (stallTime / 0.05).round() + 40);
    for (var i = 0; i < 20; i++) {
      g.tick(0.05);
    }
    expect(heard.whereType<Marched>().map((e) => (e.wave, e.t > stallTime)), [(1, true)]);
  });

  test('an event\'s JSON carries the version, kind, wave, time and its fields; the log is not saved', () {
    final e = TroopFell(7, 12.5, name: 'Budi', type: 'soldier', killer: 'orc', killerTier: Tier.elite);
    expect(jsonDecode(jsonEncode(e.toJson())), {
      'v': eventVersion,
      'kind': 'fell',
      'wave': 7,
      't': 12.5,
      'name': 'Budi',
      'type': 'soldier',
      'hero': false,
      'killer': 'orc',
      'killerTier': 'elite',
      'relics': [], // what it held, back in the bag (decisions-log 138)
    });
    final g = bareGame()..log.add(e);
    final j = jsonDecode(jsonEncode(g.toJson())) as Map<String, dynamic>;
    expect(j.containsKey('log'), isFalse);
    expect(Game.fromJson(j).log.entries, isEmpty);
  });
}
