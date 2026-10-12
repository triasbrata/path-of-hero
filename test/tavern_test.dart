// The Tavern's boosts (decisions-log 266; lib/tavern.dart; docs/loot-items-relics.md "Towns: the Tavern"): town.json's
// `tavern` block, the prices by wave, the roll (the first Feast, different kinds, a kind running left out, Legendary from
// wave 30, the pity, the Plate's type, the odds), buying with no limit and the refusals, the reroll, the stats step (the
// oath under it, the Hero aura over it, the cap), damage taken through a blow, the countdown, Lucky Toast's gold, the
// save, the events and the telemetry, and the probe policy; each offer's length (decisions-log 331): its odds, its price,
// its countdown or its end at the next Town, a replay counting nothing, the save. (Watchman's Brew went with the back
// line's cost, decisions-log 329.)
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';
import 'package:tower_defense/main.dart' show logLine;
import 'package:tower_defense/telemetry.dart';

import 'hero_skill_helpers.dart';
import 'wipe_test.dart' show wipe;

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

/// The `tavern.lengths` block where only [given] have a share (decisions-log 331): `{'2': 1.0}`, every offer 2 waves.
Map<String, double> lengthsOnly(Map<String, double> given) => {'2': 0.0, '3': 0.0, '4': 0.0, 'town': 0.0, ...given};

/// Rules whose rolls are all of one [rarity] (no first Feast, no pity unless given), every offer of [lengths] (2 waves,
/// as before decisions-log 331, unless given).
TownRules only(String rarity, {bool firstFeast = false, int pity = 0, Map<String, double> lengths = const {'2': 1.0}}) => rules({
      'odds': {for (final r in ['common', 'rare', 'epic', 'legendary']) r: r == rarity ? 1.0 : 0.0},
      'firstFeast': firstFeast,
      'pity': pity,
      'lengths': lengthsOnly(lengths),
    });

List<Boost> kinds(Game g) => [for (final o in g.tavernOffers) o.kind];

/// Saved and loaded back, through JSON as the file does, into a game with the Towns (and so the Tavern) on.
Game reloaded(Game g) => Game.fromJson(jsonDecode(jsonEncode(g.toJson())) as Map<String, dynamic>);

/// Starts [g]'s next wave (through a due Town first) with [foes] put on the field (none: one slime gone at once, so the
/// wave is won), and ticks until it ends.
void fight(Game g, [List<Unit Function(Game)> foes = const []]) {
  if (g.townDue && !g.inTown) expect(g.enterTown(), isTrue);
  if (g.inTown) expect(g.leaveTown(), isTrue);
  g
    ..startWave()
    ..queue.clear();
  for (final f in foes) {
    f(g);
  }
  if (foes.isEmpty) foeAt(g, 'slime', Point(g.baseX + 200, 40)).gone = true;
  for (var i = 0; i < 200 && g.waveActive; i++) {
    g.tick(0.05);
  }
  expect(g.waveActive, isFalse);
}

void main() {
  group('town.json `tavern` (decisions-log 266)', () {
    test('the shipped block is the defaults, nothing skipped: 10 kinds, every one two waves, the owner\'s Feast', () {
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
        'epic': ['plate'], // Watchman's Brew went in decisions-log 329
        'legendary': ['banquet'],
      });
      expect(t.boosts[Boost.feast]!.effects, {'dmg': 1.20, 'taken': 0.85}, reason: 'the owner: atk + def, for every troop');
      expect(t.boosts[Boost.plate]!.oneType, isTrue);
      expect([for (final b in Boost.values) if (t.boosts[b]!.oneType) b], [Boost.plate]);
      expect(boostNames.keys, Boost.values);
      expect((t.most.dmg, t.most.maxHp, t.most.rate, t.most.mpRegen, t.most.gold, t.most.taken), (1.8, 1.8, 1.8, 1.8, 2.0, 0.6));
      expect(t.lengths, {2: 0.45, 3: 0.25, 4: 0.18}, reason: 'decisions-log 331');
      expect((t.lengthTown, t.priceTown), (0.12, 1.1));
      expect(TownRules.patch({}).tavern.toJson(), t.toJson(), reason: 'a patch round-trips the block');
    });

    test('a number out of range or of the wrong kind keeps its default; a name it doesn\'t know is noted', () {
      final odd = rules({
        'offers': 0,
        'waves': 0,
        'pity': -1,
        'firstFeast': 'yes',
        'odds': {'common': -1, 'mythic': 0.5},
        'price': {'k': {'rare': 0}, 'early': 2, 'fullFrom': 0, 'round': 0, 'least': 10, 'town': -1},
        'lengths': {'0': 1, 'long': 1, '3': -1, '6': 0.5},
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
      expect(t.lengths, {2: 0.45, 3: 0.25, 4: 0.18, 6: 0.5});
      expect((t.lengthTown, t.priceTown), (0.12, d.priceTown));
      final feast = t.boosts[Boost.feast]!;
      expect((feast.rarity, feast.dmg, feast.taken, feast.oneType), (Rarity.langka, 1.2, 0.5, false));
      expect(odd.skipped, containsAll(['tavern: no bar', 'tavern.odds: no mythic', 'tavern.boosts: no pie', 'tavern.boosts.feast.rarity: shiny', 'tavern.boosts.feast.who: some', 'tavern.lengths: no 0', 'tavern.lengths: no long']));
      // No length with a share: the defaults.
      expect(rules({'lengths': lengthsOnly({})}).tavern.lengths, d.lengths);
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
      6: [50, 100, 150, 250],
      7: [50, 100, 200, 350],
      12: [150, 250, 450, 750],
      20: [450, 700, 1300, 2150],
      30: [950, 1600, 2900, 4800],
      50: [3800, 6300, 11000, 19000],
      70: [13000, 21000, 38000, 63000],
      86: [31000, 52000, 93000, 156000],
    }); // the purse grows with the kill gold's 4.5% a wave (5% until decisions-log 318)
    expect(table[6]![1], lessThan(500), reason: 'the Feast well under 500 at the first Towns');
    // A kind's own k prices it over its rarity's.
    final own = inTown(tavern(rules: rules({'boosts': {'ale': {'k': 1.0}}})), 20);
    expect(own.boostPrice(Boost.ale), 1400);
    // The rerolls: 0.1 purse at least 50, ×2 each in the visit.
    final g = inTown(tavern(rules: only('common')), 20);
    final prices = <int>[];
    for (var i = 0; i < 4; i++) {
      prices.add(g.tavernRerollPrice);
      expect(g.rerollTavern(), isTrue);
    }
    expect(prices, [150, 300, 550, 1150]);
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
      expect([for (final k in kinds(early)) g0(k)], [Rarity.epik, Rarity.langka, Rarity.langka]); // one Epic since 329
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

    test('Watchman\'s Brew is gone (decisions-log 329): no kind forgives a monster, and a saved one is dropped', () {
      expect(Boost.values.asNameMap().containsKey('watch'), isFalse);
      final j = jsonDecode(jsonEncode(tavern().toJson())) as Map<String, dynamic>..['boosts'] = [{'kind': 'watch', 'left': 2}];
      expect(Game.fromJson(j).boosts, isEmpty);
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
        'offers': [for (final o in g.tavernOffers) {'kind': o.kind.name, 'waves': 2, if (o.sold) 'sold': true}],
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
      'tavernSpent and its start\'s boosts', () {
    final sink = _Kept(), events = <GameEvent>[];
    final g = tavern(rules: only('epic'))..listeners.add(events.add);
    TelemetryAdapter([sink], installId: 'i', session: 's', platform: 'test', now: () => DateTime.utc(2026, 10, 8)).attach(g);
    inTown(g, 20);
    expect(kinds(g), contains(Boost.plate));
    expect(g.rerollTavern(), isTrue);
    final w = kinds(g).indexOf(Boost.plate), price = g.boostPrice(Boost.plate), reroll = g.tavernSpent, offered = [...kinds(g)];
    expect(w, isNonNegative, reason: 'the one Epic comes in every roll');
    expect(g.buyBoost(w), isTrue);
    final bought = events.whereType<BoostBought>().single;
    expect((bought.boost, bought.rarity, bought.price, bought.waves, bought.slot, bought.type), (Boost.plate, Rarity.epik, price, 2, w, 'priest'));
    expect(bought.effects, {'dmg': 1.4, 'rate': 1.15});
    expect(passedOn, containsAll([EventKind.boostBought, EventKind.tavernRerolled]));
    fight(g);
    final ev = [for (final r in sink.of('event')) r['event'] as Map<String, dynamic>];
    expect(ev.singleWhere((e) => e['kind'] == 'boostBought'), containsPair('boost', 'plate'));
    expect(ev.singleWhere((e) => e['kind'] == 'boostBought'), containsPair('rarity', 'epic'));
    expect(ev.singleWhere((e) => e['kind'] == 'tavernRerolled'), containsPair('price', reroll));
    final left = ev.singleWhere((e) => e['kind'] == 'townLeft');
    expect(left['tavern'], {'offered': [for (final k in offered) k.name], 'bought': ['plate'], 'rerolls': 1, 'spent': reroll + price});
    expect(kinds(g), isEmpty, reason: 'the offers go with the Town');
    final wave = sink.of('wave').single;
    expect((wave['gold']['tavernSpent'], wave.containsKey('boostSaved'), wave['livesLost']), (reroll + price, false, 0));
    expect(wave['start']['boosts'], {'plate': 2});
  });

  group('the lengths (decisions-log 331)', () {
    test('each offer rolls its own on the Tavern dice: 2 waves 45%, 3 waves 25%, 4 waves 18%, until the next Town 12%; '
        'the same for the same seed; a reroll rolls the new offers\' afresh', () {
      final a = inTown(tavern(seed: 3)), b = inTown(tavern(seed: 3));
      List<(int, bool)> lengths(Game g) => [for (final o in g.tavernOffers) (o.waves, o.untilTown)];
      expect(lengths(a), lengths(b));
      final g = tavern(rules: rules({'firstFeast': false, 'pity': 0}));
      final count = <String, int>{};
      for (var i = 0; i < 5000; i++) {
        inTown(g, 40);
        for (final o in g.tavernOffers) {
          count[o.length] = (count[o.length] ?? 0) + 1;
        }
        g.leaveTown();
      }
      final n = count.values.fold(0, (a, b) => a + b);
      expect(n, 15000);
      expect(count.keys.toSet(), {'2 waves', '3 waves', '4 waves', 'Until next Town'});
      expect(count['2 waves']! / n, closeTo(0.45, 0.015));
      expect(count['3 waves']! / n, closeTo(0.25, 0.015));
      expect(count['4 waves']! / n, closeTo(0.18, 0.015));
      expect(count['Until next Town']! / n, closeTo(0.12, 0.012));
      // A reroll: the bought offer keeps its length, the new ones roll theirs.
      final r = inTown(tavern(rules: only('common', lengths: {'2': 0.5, '4': 0.5}), seed: 2), 20);
      expect(r.buyBoost(0), isTrue);
      final kept = r.tavernOffers.first.waves, seen = <int>{};
      for (var i = 0; i < 6; i++) {
        expect(r.rerollTavern(), isTrue);
        expect(r.tavernOffers.first.waves, kept);
        seen.addAll([for (final o in r.tavernOffers.skip(1)) o.waves]);
      }
      expect(seen, {2, 4});
    });

    test('the price grows with the length: × waves / 2 over the 2-wave price, a step over the one a wave shorter; '
        'until the next Town × the 7.42 waves to it on average × 1.1', () {
      expect(townGapMean(const TownSchedule()), closeTo(7.4243, 1e-3));
      expect(townGapMean(const TownSchedule(chanceStart: 1, minGap: 3)), 3.0);
      expect(townGapMean(const TownSchedule(chanceStart: 0, chanceStep: 0)), 5 + 199.0, reason: 'never a hit: the 200th roll');
      List<int> four(Game g, Boost k) =>
          [for (final n in [2, 3, 4]) g.boostPrice(k, waves: n), g.boostPrice(k, untilTown: true)];
      final w6 = inTown(tavern(), 6), w20 = inTown(tavern(), 20), w50 = inTown(tavern(), 50);
      expect(four(w6, Boost.ale), [50, 100, 150, 200], reason: '4 waves a step over 3 (×2 is 100)');
      expect(four(w6, Boost.feast), [100, 150, 200, 350]);
      expect(four(w6, Boost.plate), [150, 250, 350, 650]);
      expect(four(w20, Boost.ale), [450, 650, 850, 1750]);
      expect(four(w20, Boost.feast), [700, 1050, 1400, 2900]);
      expect(four(w20, Boost.plate), [1300, 1900, 2550, 5200]);
      expect(four(w50, Boost.ale), [3800, 5650, 7550, 15000]);
      // The 2-wave price is the one from before 331; every longer one dearer, at every wave.
      for (var w = 1; w <= 100; w++) {
        final g = tavern()..wave = w;
        for (final k in Boost.values) {
          final p = four(g, k);
          expect(p.first, g.boostPrice(k), reason: 'wave $w $k');
          for (var i = 1; i < p.length; i++) {
            expect(p[i], greaterThan(p[i - 1]), reason: 'wave $w $k: $p');
          }
        }
      }
      // An offer costs its own length's, and buying takes it.
      final g = inTown(tavern(rules: only('rare', lengths: {'4': 1}), gold: 10000), 20);
      expect({for (final o in g.tavernOffers.take(2)) o.kind}, {Boost.feast, Boost.mage});
      expect([for (final o in g.tavernOffers.take(2)) g.offerPrice(o)], [1400, 1400], reason: 'a Rare\'s 4 waves after wave 20');
      expect(g.buyBoost(0), isTrue);
      expect((g.gold, g.boosts.single.left, g.boosts.single.untilTown), (10000 - 1400, 4, false));
    });

    test('a 3-wave boost runs three waves, a 4-wave one four', () {
      for (final n in [3, 4]) {
        final g = inTown(tavern(rules: only('common', lengths: {'$n': 1})), 20)..lives = 99;
        expect(g.buyBoost(0), isTrue);
        for (var w = 1; w <= n; w++) {
          expect(g.boosts.single.left, n - w + 1);
          fight(g);
          expect(g.boosts.length, w < n ? 1 : 0, reason: '$n waves: after wave $w');
        }
      }
    });

    test('until the next Town: it runs every wave until then, its tip says so (the Town once marked), and it ends as '
        'that Town is entered, before its Tavern rolls (which may offer it again)', () {
      final events = <GameEvent>[];
      final g = inTown(tavern(rules: only('rare', lengths: {'town': 1})), 6)
        ..lives = 99
        ..listeners.add(events.add);
      expect(g.tavernOffers.every((o) => o.untilTown && o.length == Words.untilNextTown), isTrue);
      final kind = kinds(g).first;
      expect(g.buyBoost(0), isTrue);
      expect((g.boosts.single.untilTown, g.boosts.single.fought), (true, 0));
      expect(g.boostTip(0).$1, '${boostNames[kind]}: until next ${Words.town}');
      expect(logLine(events.whereType<BoostBought>().single), endsWith('(until next ${Words.town})'));
      expect(g.leaveTown(), isTrue);
      var fought = 0;
      while (!g.townDue) {
        expect(g.boosts, hasLength(1), reason: 'wave ${g.wave + 1}');
        fight(g);
        expect(g.boosts.single.fought, ++fought);
        if (g.townMarked && !g.townDue) expect(g.boostTip(0).$2.first, '${Words.townAfter} ${g.townAt! - 1}');
      }
      expect(fought, greaterThanOrEqualTo(g.townRules.schedule.minGap));
      expect(events.whereType<BoostEnded>(), isEmpty);
      expect(g.enterTown(), isTrue);
      expect(g.boosts, isEmpty);
      expect(events.whereType<BoostEnded>().single.boost, kind);
      expect(kinds(g), contains(kind), reason: 'over: offered again (two Rares, both in the roll)');
    });

    test('a wave lost to a wipe and played again counts nothing: a boost for waves 21 and 22 still covers 21 again and 22', () {
      final g = inTown(tavern(rules: only('common')), 20);
      expect(g.buyBoost(0), isTrue);
      expect(g.buyBoost(1), isTrue);
      g.leaveTown();
      wipe(g);
      expect(g.wave, 20, reason: 'wave 21 to play again');
      expect([for (final b in g.boosts) (b.left, b.fought)], [(2, 0), (2, 0)]);
      fight(g);
      expect([for (final b in g.boosts) b.left], [1, 1]);
      fight(g);
      expect(g.boosts, isEmpty);
      // Until the next Town: a wipe changes nothing either.
      final t = inTown(tavern(rules: only('common', lengths: {'town': 1})), 20);
      expect(t.buyBoost(0), isTrue);
      t.leaveTown();
      wipe(t);
      expect((t.boosts.single.untilTown, t.boosts.single.fought), (true, 0));
    });

    test('saved: each offer\'s length, a boost until the next Town and the waves it fought; a save from before 331 '
        'lasts 2 waves', () {
      final g = inTown(tavern(rules: only('common', lengths: {'town': 1})), 20)..lives = 99;
      expect(g.buyBoost(0), isTrue);
      var j = jsonDecode(jsonEncode(g.toJson())) as Map<String, dynamic>;
      expect(j['boosts'], [{'kind': kinds(g).first.name, 'town': true}]);
      expect(((j['town'] as Map)['tavern'] as Map)['offers'],
          [for (final (i, o) in g.tavernOffers.indexed) {'kind': o.kind.name, 'town': true, if (i == 0) 'sold': true}]);
      final b = reloaded(g);
      expect([for (final o in b.tavernOffers) (o.untilTown, b.offerPrice(o))], [for (final o in g.tavernOffers) (true, g.offerPrice(o))]);
      fight(g);
      fight(g);
      j = jsonDecode(jsonEncode(g.toJson())) as Map<String, dynamic>;
      expect(j['boosts'], [{'kind': g.boosts.single.kind.name, 'town': true, 'fought': 2}]);
      final c = reloaded(g);
      expect([for (final r in c.boosts) (r.kind, r.untilTown, r.fought)], [(g.boosts.single.kind, true, 2)]);
      // A 3-wave boost: its left and fought.
      final f = inTown(tavern(rules: only('common', lengths: {'3': 1})), 20)..lives = 99;
      expect(f.buyBoost(0), isTrue);
      fight(f);
      expect([for (final r in reloaded(f).boosts) (r.left, r.fought, r.untilTown)], [(2, 1, false)]);
      // From before 331: offers without a length and a boost without `fought` (every one was 2 waves).
      final old = inTown(tavern(rules: only('common')), 20);
      final o = jsonDecode(jsonEncode(old.toJson())) as Map<String, dynamic>;
      for (final x in ((o['town'] as Map)['tavern'] as Map)['offers'] as List) {
        (x as Map).remove('waves');
      }
      o['boosts'] = [
        {'kind': 'stew', 'left': 1},
      ];
      final loaded = Game.fromJson(o);
      expect([for (final x in loaded.tavernOffers) (x.waves, x.untilTown)], [(2, false), (2, false), (2, false)]);
      expect([for (final r in loaded.boosts) (r.kind, r.left, r.fought, r.untilTown)], [(Boost.stew, 1, 1, false)]);
    });

    test('the telemetry: an until-Town buy has waves 0 and untilTown; the wave\'s start lists it as 0', () {
      final sink = _Kept();
      final g = tavern(rules: only('epic', lengths: {'town': 1}));
      TelemetryAdapter([sink], installId: 'i', session: 's', platform: 'test', now: () => DateTime.utc(2026, 10, 12)).attach(g);
      inTown(g, 20);
      final w = kinds(g).indexOf(Boost.plate); // the one Epic (Watchman's Brew went in decisions-log 329)
      expect(g.buyBoost(w), isTrue);
      fight(g);
      final bought = [for (final r in sink.of('event')) r['event'] as Map<String, dynamic>].singleWhere((e) => e['kind'] == 'boostBought');
      expect((bought['waves'], bought['untilTown']), (0, true));
      expect(sink.of('wave').single['start']['boosts'], {'plate': 0});
    });

    test('the probe policy "top": of one rarity the dearest, so the longest', () {
      for (var seed = 0; seed < 8; seed++) {
        final g = tavern(rules: only('common', lengths: {'2': 0.5, 'town': 0.5}), seed: seed)
          ..townPolicy = 'leave'
          ..tavernPolicy = 'top'
          ..wave = 20
          ..townAt = 21;
        var anyTown = false;
        g.listeners.add((e) {
          if (e is TownEntered) anyTown = g.tavernOffers.any((o) => o.untilTown);
        });
        g.startWave();
        expect(g.boosts.single.untilTown, anyTown, reason: 'seed $seed');
      }
    });
  });

  test('a plate\'s log line names its type; every effect has its words', () {
    final e = BoostBought(1, 0, boost: Boost.plate, rarity: Rarity.epik, price: 900, waves: 2, type: 'knight', slot: 0, effects: const {'dmg': 1.4, 'rate': 1.15});
    expect(logLine(e), "${boostNames[Boost.plate]} (${troopTypePlurals['knight']}): +40% damage, +15% attack speed (2 waves)");
    expect(boostEffectLines(const {'taken': 0.85, 'hp': 1.2, 'mpRegen': 1.6, 'gold': 1.3}),
        ['15% less damage taken', '+20% max HP', '+60% MP regen', '+30% kill gold']);
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
