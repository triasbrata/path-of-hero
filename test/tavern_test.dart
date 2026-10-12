// The Tavern's boosts (decisions-log 266; lib/tavern.dart; docs/loot-items-relics.md "Towns: the Tavern"): town.json's
// `tavern` block, the prices by wave, the roll (the first Feast, different kinds, a kind running left out, Legendary from
// wave 30, the pity, the Plate's type, the odds), buying with no limit and the refusals, the reroll, the stats step (the
// oath under it, the Hero aura over it, the cap), damage taken through a blow, the countdown, Lucky Toast's gold,
// Watchman's Brew's leak, the save, the events and the telemetry, and the probe policy.
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';
import 'package:tower_defense/main.dart' show logLine;
import 'package:tower_defense/telemetry.dart';

import 'hero_skill_helpers.dart';

/// A sink that keeps what it gets, through JSON as a file would.
class _Kept implements TelemetrySink {
  final records = <Map<String, dynamic>>[];

  @override
  void add(Map<String, Object?> record) => records.add(jsonDecode(jsonEncode(record)) as Map<String, dynamic>);

  @override
  Future<void> flush() async {}

  List<Map<String, dynamic>> of(String rec) => [for (final r in records) if (r['rec'] == rec) r];
}

/// A seeded game with the Towns and the Tavern on, [rules] (the defaults) and [gold] to spare (the free priest in).
Game tavern({TownRules rules = const TownRules(), int seed = 1, int gold = 100000}) => Game(Random(seed), Random(seed + 100))
  ..heroes = Random(seed + 300)
  ..loot = Random(seed + 200)
  ..slots = Random(seed + 400)
  ..draft = Random(seed + 500)
  ..townRules = rules
  ..townDice = Random(seed + 600)
  ..matDice = Random(seed + 700)
  ..tavernDice = Random(seed + 800)
  ..gold = gold;

/// [g] gone into the Town after wave [wave].
Game inTown(Game g, [int wave = 6]) {
  g
    ..wave = wave
    ..townAt = wave + 1;
  expect(g.enterTown(), isTrue);
  return g;
}

/// The defaults with the `tavern` block's [p] put in.
TownRules rules(Map<String, dynamic> p) => TownRules.patch({'tavern': p});

/// Rules whose rolls are all of one [rarity] (no first Feast, no pity unless given).
TownRules only(String rarity, {bool firstFeast = false, int pity = 0}) => rules({
      'odds': {for (final r in ['common', 'rare', 'epic', 'legendary']) r: r == rarity ? 1.0 : 0.0},
      'firstFeast': firstFeast,
      'pity': pity,
    });

List<Boost> kinds(Game g) => [for (final o in g.tavernOffers) o.kind];

/// Saved and loaded back, through JSON as the file does, into a game with the Towns (and so the Tavern) on.
Game reloaded(Game g) => Game.fromJson(jsonDecode(jsonEncode(g.toJson())) as Map<String, dynamic>);

/// Starts [g]'s next wave (through a due Town first) with [foes] put on the field (none: one slime that leaks at once),
/// and ticks until it ends.
void fight(Game g, [List<Unit Function(Game)> foes = const []]) {
  if (g.townDue && !g.inTown) expect(g.enterTown(), isTrue);
  if (g.inTown) expect(g.leaveTown(), isTrue);
  g
    ..startWave()
    ..queue.clear();
  for (final f in foes) {
    f(g);
  }
  if (foes.isEmpty) foeAt(g, 'slime', Point(g.baseX - 2, 40));
  for (var i = 0; i < 200 && g.waveActive; i++) {
    g.tick(0.05);
  }
  expect(g.waveActive, isFalse);
}

void main() {
  group('town.json `tavern` (decisions-log 266)', () {
    test('the shipped block is the defaults, nothing skipped: 11 kinds, every one two waves, the owner\'s Feast', () {
      final text = File('assets/config/town.json').readAsStringSync(), file = TownRules.parse(text);
      expect(file.skipped, isEmpty);
      expect(file.tavern.toJson(), (jsonDecode(text) as Map)['tavern']);
      expect(const TavernRules().toJson(), (jsonDecode(text) as Map)['tavern']);
      final t = file.tavern;
      expect((t.offers, t.waves, t.legendFrom, t.pity, t.firstFeast), (3, 2, 30, 4, true));
      expect(t.boosts.keys, Boost.values);
      expect({for (final r in Rarity.values) rarityKeys[r]: [for (final MapEntry(:key, :value) in t.boosts.entries) if (value.rarity == r) key.name]}, {
        'common': ['ale', 'stew', 'broth', 'tea', 'rations', 'toast'],
        'rare': ['feast', 'mage'],
        'epic': ['plate', 'watch'],
        'legendary': ['banquet'],
      });
      expect(t.boosts[Boost.feast]!.effects, {'dmg': 1.20, 'taken': 0.85}, reason: 'the owner: atk + def, for every troop');
      expect(t.boosts[Boost.plate]!.oneType, isTrue);
      expect([for (final b in Boost.values) if (t.boosts[b]!.oneType) b], [Boost.plate]);
      expect(boostNames.keys, Boost.values);
      expect((t.most.dmg, t.most.maxHp, t.most.rate, t.most.mpRegen, t.most.gold, t.most.taken), (1.8, 1.8, 1.8, 1.8, 2.0, 0.6));
      expect(TownRules.patch({}).tavern.toJson(), t.toJson(), reason: 'a patch round-trips the block');
    });

    test('a number out of range or of the wrong kind keeps its default; a name it doesn\'t know is noted', () {
      final odd = rules({
        'offers': 0,
        'waves': 0,
        'pity': -1,
        'firstFeast': 'yes',
        'odds': {'common': -1, 'mythic': 0.5},
        'price': {'k': {'rare': 0}, 'early': 2, 'fullFrom': 0, 'round': 0, 'least': 10},
        'reroll': {'rise': 0.5, 'k': 0.2},
        'most': {'dmg': 0.5, 'taken': 1.5, 'gold': 3},
        'boosts': {
          'feast': {'rarity': 'shiny', 'dmg': -1, 'taken': 0.5, 'who': 'some'},
          'pie': {'rarity': 'common'},
        },
        'bar': 1,
      });
      final t = odd.tavern, d = const TavernRules();
      expect((t.offers, t.waves, t.pity, t.firstFeast), (d.offers, d.waves, d.pity, d.firstFeast));
      expect(t.odds, d.odds);
      expect(t.price, d.price);
      expect((t.early, t.fullFrom, t.round, t.priceLeast), (d.early, d.fullFrom, d.round, 10));
      expect((t.rerollRise, t.rerollK), (d.rerollRise, 0.2));
      expect((t.most.dmg, t.most.taken, t.most.gold), (1.8, 0.6, 3.0));
      final feast = t.boosts[Boost.feast]!;
      expect((feast.rarity, feast.dmg, feast.taken, feast.oneType), (Rarity.langka, 1.2, 0.5, false));
      expect(odd.skipped, containsAll(['tavern: no bar', 'tavern.odds: no mythic', 'tavern.boosts: no pie', 'tavern.boosts.feast.rarity: shiny', 'tavern.boosts.feast.who: some']));
      // A version-2 file has no block: every default.
      expect(TownRules.parse('{"version": 2}').tavern.toJson(), d.toJson());
    });
  });

  test('the prices by the wave won: the first Towns cheap (the owner: "jangan terlalu mahal untuk di kota kota awal"), '
      'then about half a wave\'s purse; rerolls double in a visit', () {
    final table = <int, List<int>>{};
    for (final w in [6, 7, 12, 20, 30, 50, 70, 86]) {
      final g = inTown(tavern(), w);
      table[w] = [for (final b in [Boost.ale, Boost.feast, Boost.plate, Boost.banquet]) g.boostPrice(b)];
    }
    expect(table, {
      6: [50, 100, 150, 300],
      7: [50, 100, 200, 350],
      12: [150, 250, 500, 800],
      20: [450, 800, 1400, 2350],
      30: [1100, 1850, 3300, 5550],
      50: [4750, 7950, 14000, 24000],
      70: [18000, 29000, 53000, 88000],
      86: [47000, 78000, 140000, 234000],
    });
    expect(table[6]![1], lessThan(500), reason: 'the Feast well under 500 at the first Towns');
    // A kind's own k prices it over its rarity's.
    final own = inTown(tavern(rules: rules({'boosts': {'ale': {'k': 1.0}}})), 20);
    expect(own.boostPrice(Boost.ale), 1550);
    // The rerolls: 0.1 purse at least 50, ×2 each in the visit.
    final g = inTown(tavern(rules: only('common')), 20);
    final prices = <int>[];
    for (var i = 0; i < 4; i++) {
      prices.add(g.tavernRerollPrice);
      expect(g.rerollTavern(), isTrue);
    }
    expect(prices, [150, 300, 600, 1250]);
    expect(inTown(tavern(), 7).tavernRerollPrice, 50);
  });

  group('the roll', () {
    test('three different kinds on the Tavern dice, the same for the same seed; the run\'s first Tavern has the Feast first', () {
      final a = inTown(tavern(seed: 3)), b = inTown(tavern(seed: 3));
      expect(kinds(a), kinds(b));
      expect(kinds(a), hasLength(3));
      expect(kinds(a).toSet(), hasLength(3));
      expect(kinds(a).first, Boost.feast);
      expect(a.tavernSeen, isTrue);
      // The next Town has no guarantee: over ten seeds the Feast isn't always first.
      final firsts = <Boost>{};
      for (var s = 0; s < 10; s++) {
        final g = inTown(tavern(seed: s))..leaveTown();
        firsts.add(kinds(inTown(g, 12)).first);
      }
      expect(firsts.length, greaterThan(1));
      // With firstFeast off, nothing is first.
      expect(inTown(tavern(rules: only('common'))).tavernOffers.every((o) => g0(o.kind) == Rarity.biasa), isTrue);
    });

    test('a kind running is never offered; a Legendary only from wave 30 (before it, Epic, then down); the Plate\'s type '
        'is one alive', () {
      final g = tavern(rules: only('common'))..boosts.add(RunningBoost(Boost.ale, 2));
      for (var s = 0; s < 20; s++) {
        if (g.inTown) g.leaveTown();
        g.tavernDice = Random(s);
        expect(kinds(inTown(g)), isNot(contains(Boost.ale)));
      }
      final early = inTown(tavern(rules: only('legendary')), 29);
      expect([for (final k in kinds(early)) g0(k)], [Rarity.epik, Rarity.epik, Rarity.langka]);
      final late = inTown(tavern(rules: only('legendary')), 30);
      expect(kinds(late).first, Boost.banquet);
      // The free priest is the only type alive: the Plate is a Priests' one.
      final plate = inTown(tavern(rules: only('epic')));
      expect(plate.tavernOffers.firstWhere((o) => o.kind == Boost.plate).type, 'priest');
      expect(plate.tavernOffers.where((o) => o.kind != Boost.plate).every((o) => o.type == null), isTrue);
      // No troop alive: no Plate.
      final none = tavern(rules: only('epic'))..units.clear();
      expect(kinds(inTown(none)), isNot(contains(Boost.plate)));
    });

    test('the pity: after three visits without an Epic or better, the fourth\'s last slot is one; an Epic resets it', () {
      final g = tavern(rules: only('common', pity: 4));
      for (var v = 1; v <= 3; v++) {
        inTown(g, 6 * v);
        expect(g.tavernOffers.every((o) => g0(o.kind) == Rarity.biasa), isTrue, reason: 'visit $v');
        expect(g.tavernDry, v);
        g.leaveTown();
      }
      inTown(g, 24);
      expect([for (final k in kinds(g)) g0(k)], [Rarity.biasa, Rarity.biasa, Rarity.epik]);
      expect(g.tavernDry, 0);
      // A reroll never counts and never lifts.
      expect(g.rerollTavern(), isTrue);
      expect(g.tavernDry, 0);
    });

    test('the odds over 10,000 first slots at wave 40: Common 55%, Rare 30%, Epic 13%, Legendary 2%', () {
      final g = tavern(rules: rules({'firstFeast': false, 'pity': 0}));
      final count = <Rarity, int>{};
      for (var i = 0; i < 10000; i++) {
        inTown(g, 40);
        final r = g0(kinds(g).first);
        count[r] = (count[r] ?? 0) + 1;
        g.leaveTown();
      }
      expect(count[Rarity.biasa]! / 10000, closeTo(0.55, 0.02));
      expect(count[Rarity.langka]! / 10000, closeTo(0.30, 0.02));
      expect(count[Rarity.epik]! / 10000, closeTo(0.13, 0.015));
      expect(count[Rarity.legenda]! / 10000, closeTo(0.02, 0.007));
    });
  });

  group('buying', () {
    test('every offer while the gold lasts (no buy limit): paid at once, Sold, running for the next two waves', () {
      final g = inTown(tavern(rules: only('common'), gold: 1000), 20);
      final prices = [for (final o in g.tavernOffers) g.boostPrice(o.kind)];
      expect(prices, everyElement(450));
      for (var i = 0; i < 2; i++) {
        expect(g.buyBoost(i), isTrue);
      }
      expect(g.gold, 100);
      expect(g.tavernOffers.map((o) => o.sold), [true, true, false]);
      expect([for (final b in g.boosts) (b.kind, b.left)], [for (final k in kinds(g).take(2)) (k, 2)]);
      expect(g.sfx.last, Sfx.clear);
      // The refusals, in order.
      expect(g.whyNotBuyBoost(0), BoostWhy.sold);
      expect(g.whyNotBuyBoost(2), BoostWhy.gold);
      expect(g.buyBoost(2), isFalse);
      expect(g.sfx.last, Sfx.error);
      expect(g.whyNotBuyBoost(7), BoostWhy.town);
      g.gold = 450;
      expect(g.buyBoost(2), isTrue);
      expect((g.gold, g.boosts.length, g.tavernSpent), (0, 3, 1350));
      expect(g.whyNotRerollTavern(), BoostWhy.soldOut);
      g.leaveTown();
      expect(g.whyNotBuyBoost(0), BoostWhy.town);
      g.lives = 0;
      expect(g.whyNotBuyBoost(0), BoostWhy.over);
      expect(boostRefusals[BoostWhy.gold], Words.notEnoughGold);
      expect(boostRefusals.keys, BoostWhy.values);
    });

    test('a reroll rolls only the unbought offers, each in its slot, never a kind bought; refused when short', () {
      final g = inTown(tavern(rules: only('common'), gold: 100000), 20);
      expect(g.buyBoost(1), isTrue);
      final bought = kinds(g)[1];
      for (var i = 0; i < 6; i++) {
        expect(g.rerollTavern(), isTrue);
        expect(kinds(g)[1], bought);
        expect(g.tavernOffers[1].sold, isTrue);
        expect(kinds(g).toSet(), hasLength(3));
      }
      expect(g.tavernRerolls, 6);
      g.gold = g.tavernRerollPrice - 1;
      expect(g.whyNotRerollTavern(), BoostWhy.gold);
      expect(g.rerollTavern(), isFalse);
    });
  });

  group('the stats (statsOf\'s last step)', () {
    test('the Feast: damage (a healer\'s heal) ×1.2 and damage taken ×0.85 on every type, shields or none; the troops '
        'on the field take it at once', () {
      final g = tavern();
      placeNow(g, 'knight', g.baseCol + 1, 1);
      final before = {for (final t in troopTypes.keys) t: g.statsOf(t)};
      inTown(g);
      final i = kinds(g).indexOf(Boost.feast);
      expect(g.buyBoost(i), isTrue);
      for (final t in troopTypes.keys) {
        final s = g.statsOf(t), b = before[t]!;
        expect(s.dmg, closeTo(b.dmg * 1.2, 1e-9), reason: t);
        expect(s.taken, closeTo(0.85, 1e-12), reason: t);
        expect((s.hp, s.rate, s.def, s.mpRegen), (b.hp, b.rate, b.def, b.mpRegen), reason: t);
      }
      final knight = g.troops.firstWhere((u) => u.type == 'knight'), priest = g.troops.firstWhere((u) => u.type == 'priest');
      expect(knight.stats.dmg, closeTo(troopTypes['knight']!.dmg * 1.2, 1e-9));
      expect(priest.stats.dmg, closeTo(troopTypes['priest']!.dmg * 1.2, 1e-9), reason: 'a heal 20% bigger');
      // A troop bought while it runs has it too.
      g.leaveTown();
      final archer = placeNow(g, 'archer', g.baseCol + 1, 2);
      expect(archer.stats.dmg, closeTo(troopTypes['archer']!.dmg * 1.2, 1e-9));
    });

    test('on top of the oath; the Hero aura on top of it; HP gained comes with it', () {
      final g = tavern(rules: only('common'));
      g.pusaka[Relic.wallOath] = OwnedPusaka();
      final knight = placeNow(g, 'knight', g.baseCol + 1, 1);
      final hero = placeNow(g, 'soldier', g.baseCol + 1, 2)
        ..hero = true
        ..heroStats = [HeroStat.values.first];
      g.boosts.addAll([RunningBoost(Boost.stew, 2), RunningBoost(Boost.ale, 2)]);
      inTown(g);
      expect(g.buyBoost(0), isTrue); // a third Common (never the two running); any buy refits
      final k = troopTypes['knight']!, extra = g.boosts.last.kind;
      final dmgK = 1.15 * boostK(g, extra, 'dmg'), hpK = 1.20 * boostK(g, extra, 'hp');
      expect(g.statsOf('knight').dmg, closeTo(k.dmg * wallOathK.dmg * dmgK, 1e-9));
      expect(g.statsOf('knight').hp, ((k.hp * wallOathK.hp).round() * hpK).round());
      expect(knight.stats.dmg, closeTo(g.statsOf('knight').dmg * auraBoost, 1e-9), reason: 'the aura multiplies the boosted');
      expect(knight.maxHp, knight.stats.hp);
      expect(knight.hp, knight.maxHp, reason: 'the HP gained comes with it');
      expect(hero.hero, isTrue);
    });

    test('the cap (tavern.most): the boosts together stop at ×1.8 on a stat and at ×0.6 damage taken; the Plate only on '
        'its type; attack speed divides the pause', () {
      final g = tavern()
        ..boosts.addAll([
          RunningBoost(Boost.plate, 2, type: 'knight'),
          RunningBoost(Boost.banquet, 2),
          RunningBoost(Boost.feast, 2),
          RunningBoost(Boost.broth, 2),
          RunningBoost(Boost.tea, 2),
        ]);
      final k = troopTypes['knight']!, s = troopTypes['soldier']!;
      expect(g.statsOf('knight').dmg, closeTo(k.dmg * 1.8, 1e-9), reason: '1.4 × 1.3 × 1.2 = 2.18, capped');
      expect(g.statsOf('soldier').dmg, closeTo(s.dmg * 1.3 * 1.2, 1e-9), reason: 'no Plate on a soldier');
      expect(g.statsOf('knight').taken, closeTo(0.6, 1e-12), reason: '0.75 × 0.85 × 0.88 = 0.561, floored');
      expect(g.statsOf('knight').rate, closeTo(k.rate / (1.15 * 1.10 * 1.12), 1e-9));
      expect(g.statsOf('soldier').rate, closeTo(s.rate / (1.10 * 1.12), 1e-9));
      expect(g.statsOf('soldier').hp, (s.hp * 1.25).round());
      final m = tavern()..boosts.add(RunningBoost(Boost.mage, 2));
      expect(m.statsOf('wizard').mpRegen, closeTo(troopTypes['wizard']!.mpRegen * 1.6, 1e-9));
    });

    test('damage taken: a blow lands ×0.85 under the Feast, after the defence', () {
      final g = bareGame()
        ..boosts.add(RunningBoost(Boost.feast, 2));
      final u = placeNow(g, 'soldier', 2, 3)..busyUntil = hold;
      expect(u.stats.taken, 0.85);
      final bear = Unit(Side.enemy, 'werebear', enemyTypes['werebear']!, u.pos + const Point(10, 0));
      g.units.add(bear);
      g.tick(0.05);
      expect(u.hp, closeTo(u.maxHp - enemyTypes['werebear']!.dmg * 0.85, 1e-9));
    });
  });

  group('the waves', () {
    test('counted down at each wave\'s end: gone after the second, the troops refit, HP over the max capped, never killed', () {
      final events = <GameEvent>[];
      final g = tavern(rules: only('common'))..listeners.add(events.add);
      placeNow(g, 'knight', g.baseCol + 1, 1);
      g.boosts.add(RunningBoost(Boost.stew, 2));
      inTown(g);
      expect(g.buyBoost(0), isTrue);
      final bought = kinds(g).first, knight = g.troops.firstWhere((u) => u.type == 'knight');
      expect(knight.maxHp, greaterThan(troopTypes['knight']!.hp));
      fight(g);
      expect(g.boosts.map((b) => b.left), [1, 1]);
      expect(knight.maxHp, greaterThan(troopTypes['knight']!.hp));
      fight(g);
      expect(g.boosts, isEmpty);
      expect((knight.alive, knight.maxHp, knight.hp <= knight.maxHp), (true, troopTypes['knight']!.hp, true));
      expect(events.whereType<BoostEnded>().map((e) => e.boost), unorderedEquals([Boost.stew, bought]));
      expect(logLine(events.whereType<BoostEnded>().first), '${boostNames[Boost.stew]} ended');
    });

    test('Lucky Toast: a kill pays ×1.3 at the pay line', () {
      for (final on in [false, true]) {
        final g = bareGame();
        if (on) g.boosts.add(RunningBoost(Boost.toast, 2));
        placeNow(g, 'knight', 2, 3);
        final s = enemyStats('orc', Tier.elite, 1);
        final e = Unit(Side.enemy, 'orc', s, g.troops.single.pos + const Point(10, 0))
          ..tier = Tier.elite
          ..hp = 1
          ..busyUntil = hold;
        g.units.add(e);
        final gold = g.gold;
        g.tick(0.05);
        expect(e.alive, isFalse);
        expect(g.gold - gold, on ? (s.cost * 1.3).round() : s.cost);
      }
    });

    test('Watchman\'s Brew: the first monster over the back line each wave costs no life, the next does', () {
      final events = <GameEvent>[];
      final g = tavern()
        ..listeners.add(events.add)
        ..boosts.add(RunningBoost(Boost.watch, 2));
      final lives = g.lives;
      fight(g, [(g) => foeAt(g, 'slime', Point(g.baseX - 2, 40)), (g) => foeAt(g, 'slime', Point(g.baseX - 2, 60))]);
      expect(g.lives, lives - 1);
      fight(g);
      expect(g.lives, lives - 1, reason: 'one forgiven again in the next wave');
      fight(g);
      expect(g.lives, lives - 2, reason: 'its two waves are over');
      expect(events.whereType<BoostSaved>(), hasLength(2));
      expect(logLine(events.whereType<BoostSaved>().first), "${boostNames[Boost.watch]}: no life lost");
    });
  });

  group('the save', () {
    test('in a Town: the offers, sold, the rerolls and the gold spent, the pity and the first Tavern; the boosts running', () {
      final g = inTown(tavern(rules: only('common', pity: 4)), 20);
      expect(g.buyBoost(2), isTrue);
      expect(g.rerollTavern(), isTrue);
      final bought = kinds(g)[2], j = jsonDecode(jsonEncode(g.toJson())) as Map<String, dynamic>;
      expect(j['boosts'], [{'kind': bought.name, 'left': 2}]);
      expect((j['town'] as Map)['tavern'], {
        'offers': [for (final o in g.tavernOffers) {'kind': o.kind.name, if (o.sold) 'sold': true}],
        'rerolls': 1,
        'spent': g.tavernSpent,
        'bought': [bought.name],
      });
      expect(((j['town'] as Map)['tavernDry'], (j['town'] as Map)['tavernSeen']), (1, true));
      final b = reloaded(g);
      expect((b.inTown, b.tavernRerolls, b.tavernSpent, b.tavernDry, b.tavernSeen), (true, 1, g.tavernSpent, 1, true));
      expect(kinds(b), kinds(g));
      expect([for (final o in b.tavernOffers) o.sold], [false, false, true]);
      expect([for (final r in b.boosts) (r.kind, r.left)], [(bought, 2)]);
      expect((b.statsOf('priest').dmg, b.statsOf('priest').hp, b.statsOf('priest').taken),
          (g.statsOf('priest').dmg, g.statsOf('priest').hp, g.statsOf('priest').taken));
      // Out of the Town: no visit, the boosts still running; a plate keeps its type.
      g
        ..leaveTown()
        ..boosts.add(RunningBoost(Boost.plate, 1, type: 'priest'));
      final c = reloaded(g);
      expect(c.tavernOffers, isEmpty);
      expect([for (final r in c.boosts) (r.kind, r.left, r.type)], [(bought, 2, null), (Boost.plate, 1, 'priest')]);
      expect((jsonDecode(jsonEncode(g.toJson()))['town'] as Map).containsKey('tavern'), isFalse);
    });

    test('an unknown kind, a Plate without a type and a boost with no wave left are dropped', () {
      final j = jsonDecode(jsonEncode(tavern().toJson())) as Map<String, dynamic>
        ..['boosts'] = [
          {'kind': 'pie', 'left': 2},
          {'kind': 'plate', 'left': 2},
          {'kind': 'ale', 'left': 0},
          {'kind': 'feast', 'left': 1, 'type': 'knight'},
        ];
      final g = Game.fromJson(j);
      expect([for (final b in g.boosts) (b.kind, b.left, b.type)], [(Boost.feast, 1, null)]);
    });
  });

  test('the events and the telemetry: boostBought and tavernRerolled passed on, the visit in townLeft, the wave\'s '
      'tavernSpent, boostSaved and its start\'s boosts', () {
    final sink = _Kept(), events = <GameEvent>[];
    final g = tavern(rules: only('epic'))..listeners.add(events.add);
    TelemetryAdapter([sink], installId: 'i', session: 's', platform: 'test', now: () => DateTime.utc(2026, 10, 8)).attach(g);
    inTown(g, 20);
    expect(kinds(g), contains(Boost.watch));
    expect(g.rerollTavern(), isTrue);
    final w = kinds(g).indexOf(Boost.watch), price = g.boostPrice(Boost.watch), reroll = g.tavernSpent, offered = [...kinds(g)];
    expect(w, isNonNegative, reason: 'both Epics come in every roll');
    expect(g.buyBoost(w), isTrue);
    final bought = events.whereType<BoostBought>().single;
    expect((bought.boost, bought.rarity, bought.price, bought.waves, bought.slot), (Boost.watch, Rarity.epik, price, 2, w));
    expect(bought.effects, {'leaks': 1});
    expect(logLine(bought), "${boostNames[Boost.watch]}: a leak a wave costs no life (2 waves)");
    expect(passedOn, containsAll([EventKind.boostBought, EventKind.tavernRerolled]));
    fight(g); // one slime leaks: forgiven
    final ev = [for (final r in sink.of('event')) r['event'] as Map<String, dynamic>];
    expect(ev.singleWhere((e) => e['kind'] == 'boostBought'), containsPair('boost', 'watch'));
    expect(ev.singleWhere((e) => e['kind'] == 'boostBought'), containsPair('rarity', 'epic'));
    expect(ev.singleWhere((e) => e['kind'] == 'tavernRerolled'), containsPair('price', reroll));
    final left = ev.singleWhere((e) => e['kind'] == 'townLeft');
    expect(left['tavern'], {'offered': [for (final k in offered) k.name], 'bought': ['watch'], 'rerolls': 1, 'spent': reroll + price});
    expect(kinds(g), isEmpty, reason: 'the offers go with the Town');
    final wave = sink.of('wave').single;
    expect((wave['gold']['tavernSpent'], wave['boostSaved'], wave['livesLost']), (reroll + price, 1, 0));
    expect(wave['start']['boosts'], {'watch': 2});
  });

  test('a plate\'s log line names its type; every effect has its words', () {
    final e = BoostBought(1, 0, boost: Boost.plate, rarity: Rarity.epik, price: 900, waves: 2, type: 'knight', slot: 0, effects: const {'dmg': 1.4, 'rate': 1.15});
    expect(logLine(e), "${boostNames[Boost.plate]} (${troopTypePlurals['knight']}): +40% damage, +15% attack speed (2 waves)");
    expect(boostEffectLines(const {'taken': 0.85, 'hp': 1.2, 'mpRegen': 1.6, 'gold': 1.3, 'leaks': 2}),
        ['15% less damage taken', '+20% max HP', '+60% MP regen', '+30% kill gold', '2 leaks a wave cost no life']);
  });

  test('the probe policy: "top" buys the best offer it can pay, "all" every one, highest rarity first', () {
    final top = inTown(tavern(rules: only('epic'))..tavernPolicy = 'top', 20)..leaveTown();
    expect(top.boosts, isEmpty, reason: 'only through the Town policy');
    for (final policy in ['top', 'all']) {
      final g = tavern(rules: rules({'firstFeast': true, 'pity': 0}), seed: 5)
        ..townPolicy = 'leave'
        ..tavernPolicy = policy
        ..wave = 20
        ..townAt = 21;
      final offers = <Boost>[];
      g.listeners.add((e) {
        if (e is TownLeft) offers.addAll([for (final k in (e.tavern!['offered'] as List)) Boost.values.byName(k as String)]);
      });
      g.startWave();
      final best = ([...offers]..sort((a, b) => g0(b).index.compareTo(g0(a).index))).first;
      expect(g.wave, 21, reason: 'through the Town, then the wave');
      expect(g0(g.boosts.first.kind), g0(best));
      expect(g.boosts.length, policy == 'top' ? 1 : 3);
    }
  });
}

/// [kind]'s rarity in the defaults.
Rarity g0(Boost kind) => const TavernRules().boosts[kind]!.rarity;

/// [kind]'s multiplier [stat] in [g]'s rules (1 when it has none).
double boostK(Game g, Boost kind, String stat) => (g.boostRule(kind).effects[stat] ?? 1).toDouble();
