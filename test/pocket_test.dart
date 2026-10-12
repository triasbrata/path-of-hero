// The pocket items (decisions-log 332; lib/pocket.dart; docs/loot-items-relics.md "Pocket items"): town.json's `pocket`
// block, the price by wave, the craft at the Smithy (the cap, the first slot), the use and its refusals, each kind's effect
// (the heal through the funnel, MP, the boosts under the Tavern's caps and their end, the frost, the fire's blow and its
// kills, the holy water's cleanse and ward, the watch), the cooldown across a wave's end, the bottles between waves, the
// save, the Shop's price and sale, the events and the telemetry.
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

/// A seeded game with [rules] (the defaults) and gold to spare (the free priest in).
Game pocketGame({TownRules rules = const TownRules(), int seed = 1, int gold = 100000}) => Game(Random(seed), Random(seed + 100))
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

/// [g] holding [n] of [kind] in the bar's slot [slot].
Game holding(Game g, PocketKind kind, {int n = 1, int slot = 0}) {
  g.pocketStock[kind] = n;
  expect(g.putInPocket(kind, slot), isTrue);
  return g;
}

/// [g] in a wave with nothing left to come: a knight standing idle at (2, 3) (the free priest too), and [foes] on the field.
(Game, Unit) inWave(Game g, [List<(String, Tier)> foes = const [('orc', Tier.normal)]]) {
  final k = placeNow(g, 'knight', 2, 3)..busyUntil = hold;
  for (final u in g.troops) {
    u.busyUntil = hold;
  }
  g
    ..startWave()
    ..queue.clear();
  for (final (i, (type, tier)) in foes.indexed) {
    foeAt(g, type, Point(g.baseX + 12 * tile, 20.0 + 16 * i), tier);
  }
  expect(g.waveActive, isTrue);
  return (g, k);
}

/// Saved and loaded back, through JSON as the file does.
Game reloaded(Game g) => Game.fromJson(jsonDecode(jsonEncode(g.toJson())) as Map<String, dynamic>);

void main() {
  group('town.json `pocket` (decisions-log 332)', () {
    test('the shipped block is the defaults, nothing skipped: eight kinds, the owner\'s four first', () {
      final text = File('assets/config/town.json').readAsStringSync(), file = TownRules.parse(text);
      expect(file.skipped, isEmpty);
      expect(file.pocket.toJson(), (jsonDecode(text) as Map)['pocket']);
      expect(const PocketRules().toJson(), (jsonDecode(text) as Map)['pocket']);
      final p = file.pocket;
      expect(p.kinds.keys, PocketKind.values);
      expect(pocketNames.keys, PocketKind.values);
      expect(pocketFx.keys, PocketKind.values);
      expect((p.sell, p.least), (0.5, 50));
      expect(p.kinds[PocketKind.healBottle]!.effects, {'heal': 0.35});
      expect(p.kinds[PocketKind.manaBottle]!.effects, {'mp': 0.5});
      expect(p.kinds[PocketKind.rageTonic]!.effects, {'dmg': 1.25, 'rate': 1.15});
      expect(p.kinds[PocketKind.ironDraught]!.effects, {'taken': 0.7});
      expect([for (final k in PocketKind.values) if (p.kinds[k]!.between) k], [PocketKind.healBottle, PocketKind.manaBottle],
          reason: 'the owner: "Botol juga di jeda wave"');
      expect([for (final k in PocketKind.values) p.kinds[k]!.cap], [5, 5, 3, 3, 3, 3, 3, 2]);
      expect([for (final k in PocketKind.values) p.kinds[k]!.cooldown], [30, 30, 60, 60, 45, 45, 45, 90]);
      for (final k in PocketKind.values) {
        final n = p.kinds[k]!.materials.values.fold(0, (a, b) => a + b);
        expect(n, inInclusiveRange(13, 16), reason: '"butuh banyak untuk 1 item": $k takes $n');
      }
      expect(TownRules.patch({}).pocket.toJson(), p.toJson(), reason: 'a patch round-trips the block');
    });

    test('a number out of range or of the wrong kind keeps its default; a name it doesn\'t know is noted', () {
      final r = TownRules.patch({
        'pocket': {
          'sell': 2,
          'least': -1,
          'kinds': {
            'healBottle': {'heal': 1.5, 'cooldown': -3, 'cap': 0, 'materials': {'dragonScale': 2, 'slimeGel': 1}},
            'elixirOfLife': {'heal': 1},
          },
          'shelf': true,
        },
      });
      final heal = r.pocket.kinds[PocketKind.healBottle]!;
      expect((r.pocket.sell, r.pocket.least), (0.5, 50));
      expect((heal.heal, heal.cooldown, heal.cap), (0.35, 30, 5));
      expect(heal.materials, {Mat.slimeGel: 1, Mat.tealCloth: 4, Mat.batWing: 4}, reason: 'a patch merges into the shipped recipe');
      expect(r.skipped, containsAll(['pocket: no shelf', 'pocket.kinds: no elixirOfLife', 'pocket.kinds.healBottle.materials: dragonScale 2']));
    });

    test('the effect lines say each kind in numbers', () {
      final p = const PocketRules().kinds;
      expect(pocketEffectLines(p[PocketKind.healBottle]!), ['Every troop heals 35% of its HP.']);
      expect(pocketEffectLines(p[PocketKind.rageTonic]!), ['Every troop for 15 s: +25% damage, +15% attack speed.']);
      expect(pocketEffectLines(p[PocketKind.ironDraught]!), ['Every troop for 15 s: 30% less damage taken.']);
      expect(pocketEffectLines(p[PocketKind.frostBomb]!), ['Every monster walks and attacks 40% slower for 6 s (bosses 20%).']);
      expect(pocketEffectLines(p[PocketKind.fireBomb]!), ['Every monster loses 8% of its HP (bosses 2%).']);
      expect(pocketEffectLines(p[PocketKind.holyWater]!), ["Ends every troop's bad effects; none take hold for 5 s."]);
      expect(pocketEffectLines(p[PocketKind.pocketWatch]!), ["Every troop's skills are ready now (MP still pays)."]);
    });
  });

  group('the Smithy makes them (decisions-log 332)', () {
    test('the gold is k of the Tavern\'s purse of the wave won, rounded its way, at least 50', () {
      final g = pocketGame(), r = g.townRules;
      for (final w in [1, 6, 10, 20, 30, 50, 70, 86]) {
        g.wave = w;
        for (final k in PocketKind.values) {
          final want = max(50, r.tavern.rounded(r.pocket.kinds[k]!.k * r.tavern.purseAt(w)));
          expect(g.pocketPrice(k), want, reason: '$k at wave $w');
        }
      }
      g.wave = 70;
      expect(g.pocketPrice(PocketKind.pocketWatch), greaterThan(g.pocketPrice(PocketKind.rageTonic)));
      expect(g.pocketPrice(PocketKind.rageTonic), greaterThan(g.pocketPrice(PocketKind.healBottle)));
    });

    test('only in a Town; the materials and the gold taken; a new kind into the first empty slot; the cap', () {
      final events = <GameEvent>[];
      final g = pocketGame()..listeners.add(events.add);
      final rule = g.pocketRule(PocketKind.rageTonic);
      for (final MapEntry(key: m, value: n) in rule.materials.entries) {
        g.materials[m] = n * 5;
      }
      g.wave = 20;
      expect(g.whyNotCraftPocket(PocketKind.rageTonic)?.why, CraftWhy.town);
      expect(g.craftPocket(PocketKind.rageTonic), isFalse);
      inTown(g, 20);
      g.pocketSlots[0] = PocketKind.healBottle; // the player's
      final gold = g.gold, price = g.pocketPrice(PocketKind.rageTonic);
      expect(g.craftPocket(PocketKind.rageTonic), isTrue);
      expect(g.gold, gold - price);
      expect(g.pocketHeld(PocketKind.rageTonic), 1);
      expect(g.pocketSlots, [PocketKind.healBottle, PocketKind.rageTonic, null, null]);
      expect(g.materials[Mat.orcTooth], 8 * 4);
      final made = events.whereType<PocketCrafted>().single;
      expect((made.pocket, made.gold, made.materials), (PocketKind.rageTonic, price, rule.materials));
      expect(logLine(made), 'Crafted Rage Tonic (${thousands(price)} gold)');
      expect(g.craftPocket(PocketKind.rageTonic) && g.craftPocket(PocketKind.rageTonic), isTrue);
      expect(g.pocketHeld(PocketKind.rageTonic), 3);
      final full = g.whyNotCraftPocket(PocketKind.rageTonic)!;
      expect((full.why, full.text), (CraftWhy.full, 'Full: 3/3'));
      expect(g.craftPocket(PocketKind.rageTonic), isFalse);
      // Taken out of the bar while some are held, it stays out when more are made.
      g.pocketStock[PocketKind.rageTonic] = 1;
      expect(g.takeOutOfPocket(PocketKind.rageTonic), isTrue);
      expect(g.craftPocket(PocketKind.rageTonic), isTrue);
      expect(g.pocketSlots, [PocketKind.healBottle, null, null, null]);
    });

    test('a material short or the gold short says so, in the recipe\'s order', () {
      final g = inTown(pocketGame(gold: 0), 20);
      expect(g.whyNotCraftPocket(PocketKind.healBottle)!.text, 'Need 8 Slime Gel');
      for (final MapEntry(key: m, value: n) in g.pocketRule(PocketKind.healBottle).materials.entries) {
        g.materials[m] = n;
      }
      expect(g.whyNotCraftPocket(PocketKind.healBottle)!.why, CraftWhy.gold);
      expect(g.pocketCraftRows(PocketKind.healBottle).last, (kind: null, have: 0, need: g.pocketPrice(PocketKind.healBottle)));
    });

    test('the bar: put in moves a kind from its old slot, a slot\'s kind leaves the bar but not the Bag', () {
      final g = pocketGame()..pocketStock.addAll({PocketKind.healBottle: 2, PocketKind.fireBomb: 1});
      expect(g.putInPocket(PocketKind.healBottle), isTrue);
      expect(g.putInPocket(PocketKind.fireBomb, 3), isTrue);
      expect(g.pocketSlots, [PocketKind.healBottle, null, null, PocketKind.fireBomb]);
      expect(g.putInPocket(PocketKind.fireBomb, 0), isTrue);
      expect(g.pocketSlots, [PocketKind.fireBomb, null, null, null]);
      expect(g.pocketHeld(PocketKind.healBottle), 2);
      expect(g.putInPocket(PocketKind.healBottle, 4), isFalse);
    });
  });

  group('a use (decisions-log 332)', () {
    test('the refusals, in order: over, paused, (a wipe\'s choice,) Town, empty, none left, not in a wave, cooling, nobody to help', () {
      final g = pocketGame();
      expect(g.whyNotUsePocket(0), PocketWhy.empty);
      holding(g, PocketKind.rageTonic, n: 0);
      expect(g.whyNotUsePocket(0), PocketWhy.none);
      g.pocketStock[PocketKind.rageTonic] = 2;
      expect(g.whyNotUsePocket(0), PocketWhy.wave, reason: 'a booster only in a wave');
      inWave(g);
      expect(g.whyNotUsePocket(0), isNull);
      g.paused = true;
      expect(g.whyNotUsePocket(0), PocketWhy.paused);
      expect(g.usePocket(0), isFalse);
      g.paused = false;
      expect(g.usePocket(0), isTrue);
      expect(g.whyNotUsePocket(0), PocketWhy.cooling);
      expect(g.pocketCoolLeft(PocketKind.rageTonic), 60);
      expect(g.pocketCoolShare(PocketKind.rageTonic), 1);
      holding(g, PocketKind.healBottle, slot: 1);
      expect(g.whyNotUsePocket(1), PocketWhy.hurt, reason: 'every troop at full HP');
      holding(g, PocketKind.manaBottle, slot: 2);
      for (final u in g.troops) {
        u.mp = u.stats.mp.toDouble();
      }
      expect(g.whyNotUsePocket(2), PocketWhy.mp);
      holding(g, PocketKind.fireBomb, slot: 3);
      for (final m in g.enemies) {
        m.entered = false; // not on the field yet
      }
      expect(g.whyNotUsePocket(3), PocketWhy.foes);
      g.lives = 0;
      expect(g.whyNotUsePocket(3), PocketWhy.over);
    });

    test("none while a wipe's choice waits (decisions-log 333: its dialog over everything), the bottles between waves too",
        () {
      final g = holding(pocketGame(), PocketKind.healBottle);
      for (final u in g.troops) {
        u.hp = u.maxHp * 0.5;
      }
      expect(g.whyNotUsePocket(0), isNull, reason: 'a bottle between waves');
      g.wipeAsk = true;
      expect((g.whyNotUsePocket(0), g.usePocket(0), g.pocketHeld(PocketKind.healBottle)), (PocketWhy.asked, false, 1));
      expect(g.pocketWhyText(0), '${Words.tryAgain} or ${Words.giveUp} first');
      expect(g.tryAgain(), isTrue);
      expect(g.whyNotUsePocket(0), isNull);
    });

    test('Heal Bottle: every troop heals 35% of its max HP through the funnel (HealSrc.pocket); one fewer; the event', () {
      final events = <GameEvent>[], heard = <HealSrc>[];
      final g = holding(pocketGame(), PocketKind.healBottle, n: 3)
        ..listeners.add(events.add)
        ..onTroopHeal = (u, src, asked, past) => heard.add(src);
      final (_, k) = inWave(g);
      k.hp = k.maxHp * 0.5;
      final priest = g.troops.firstWhere((u) => u.type == 'priest')..hp = 1;
      expect(g.usePocket(0), isTrue);
      expect(k.hp, closeTo(k.maxHp * 0.85, 1e-6));
      expect(priest.hp, closeTo(1 + priest.maxHp * 0.35, 1e-6));
      expect(heard, [HealSrc.pocket, HealSrc.pocket]);
      expect(g.pocketHeld(PocketKind.healBottle), 2);
      final used = events.whereType<PocketUsed>().single;
      expect((used.pocket, used.slot, used.inWave, used.troops, used.foes), (PocketKind.healBottle, 0, true, 2, 0));
      expect(used.healed, (k.maxHp * 0.35 + priest.maxHp * 0.35).round());
      expect(logLine(used), 'Used Heal Bottle (+${thousands(used.healed)} HP)');
      expect(g.impacts.where((i) => i.$2 == 'heal'), hasLength(2));
    });

    test('Mana Bottle: every troop with MP gets half of its max MP', () {
      final g = holding(pocketGame(), PocketKind.manaBottle);
      final (_, k) = inWave(g);
      k.mp = 0;
      expect(g.usePocket(0), isTrue);
      expect(k.mp, k.stats.mp * 0.5);
      expect(g.pocketHeld(PocketKind.manaBottle), 0);
      expect(g.pocketStock.containsKey(PocketKind.manaBottle), isFalse, reason: 'the last one leaves no entry');
      expect(g.pocketSlots[0], PocketKind.manaBottle, reason: 'its slot keeps the kind');
    });

    test('the bottles work between waves (not in a Town); the boosters and bombs only in a wave', () {
      final g = holding(pocketGame(), PocketKind.healBottle);
      final k = placeNow(g, 'knight', 2, 3)..hp = 10;
      expect(g.waveActive, isFalse);
      expect(g.usePocket(0), isTrue);
      expect(k.hp, closeTo(10 + k.maxHp * 0.35, 1e-6));
      expect(g.healKind(HealSrc.pocket), HealKind.between);
      for (final kind in [PocketKind.rageTonic, PocketKind.frostBomb, PocketKind.holyWater, PocketKind.pocketWatch]) {
        holding(g, kind, slot: 1);
        expect(g.whyNotUsePocket(1), PocketWhy.wave, reason: '$kind');
      }
      inTown(g);
      holding(g, PocketKind.manaBottle, slot: 2);
      expect(g.whyNotUsePocket(2), PocketWhy.town);
    });

    test('Rage Tonic: every troop\'s damage and attack speed for 15 s, then refit back; a second use renews it', () {
      final g = holding(pocketGame(), PocketKind.rageTonic, n: 2);
      final (_, k) = inWave(g);
      final before = g.statsOf('knight');
      expect(g.usePocket(0), isTrue);
      final on = g.statsOf('knight');
      expect(on.dmg, closeTo(before.dmg * 1.25, 1e-9));
      expect(before.rate / on.rate, closeTo(1.15, 1e-9));
      expect(k.stats.dmg, closeTo(on.dmg, 1e-9), reason: 'the living troops refit at once');
      runFor(g, 10);
      expect(g.pocketBoosts, hasLength(1));
      runFor(g, 5.1);
      expect(g.pocketBoosts, isEmpty);
      expect(g.statsOf('knight').dmg, closeTo(before.dmg, 1e-9));
      expect(k.stats.dmg, closeTo(before.dmg, 1e-9));
      g.pocketReady.clear();
      expect(g.usePocket(0), isTrue);
      runFor(g, 1);
      g.pocketStock[PocketKind.rageTonic] = 1;
      g.pocketReady.clear();
      expect(g.usePocket(0), isTrue);
      expect(g.pocketBoosts.single.until, closeTo(g.t + 15, 1e-9), reason: 'renewed, not stacked');
    });

    test('Iron Draught: damage taken x0.7 through a blow; a Tavern boost with a pocket one stops at the Tavern\'s caps', () {
      final g = holding(pocketGame(), PocketKind.ironDraught);
      final (_, k) = inWave(g);
      final before = g.statsOf('knight').taken;
      expect(g.usePocket(0), isTrue);
      expect(g.statsOf('knight').taken, closeTo(before * 0.7, 1e-9));
      // The caps: a Banquet (x1.3 damage) and a stronger rage (x1.6) stop at x1.8.
      final strong = pocketGame(rules: TownRules.patch({'pocket': {'kinds': {'rageTonic': {'dmg': 1.6}}}}));
      holding(strong, PocketKind.rageTonic);
      inWave(strong);
      final base = strong.statsOf('knight').dmg;
      strong.boosts.add(RunningBoost(Boost.banquet, 2));
      expect(strong.usePocket(0), isTrue);
      expect(strong.statsOf('knight').dmg, closeTo(base * 1.8, 1e-9));
      expect(k.alive, isTrue);
    });

    test('the boosts end with the wave; the cooldown runs on across it', () {
      final g = holding(pocketGame(), PocketKind.rageTonic, n: 2);
      inWave(g);
      expect(g.usePocket(0), isTrue);
      for (final m in g.enemies) {
        m.dying = 0; // falls: the wave is won once it is gone
      }
      for (var i = 0; i < 40 && g.waveActive; i++) {
        g.tick(0.05);
      }
      expect(g.waveActive, isFalse);
      expect(g.pocketBoosts, isEmpty);
      expect(g.pocketCoolLeft(PocketKind.rageTonic), greaterThan(55));
    });

    test('Frost Bomb: every monster on the field slowed and its attacks as much slower for 6 s; a boss half', () {
      final g = holding(pocketGame(), PocketKind.frostBomb);
      inWave(g, [('orc', Tier.normal), ('orc', Tier.boss)]);
      final far = g.monster('orc', Tier.normal, Point(g.baseX + 40 * tile, 40))..entered = false;
      g.units.add(far);
      final [orc, chief] = [for (final u in g.enemies) if (u.entered) u];
      final every = g.attackEvery(orc);
      expect(g.usePocket(0), isTrue);
      expect(g.effectK(orc, Status.slow), 0.6);
      expect(g.attackEvery(orc), closeTo(every / 0.6, 1e-9));
      expect(g.effectK(chief, Status.slow), 0.8);
      expect(g.effectK(far, Status.slow), 1, reason: 'not on the field yet');
      runFor(g, 6.1);
      expect(g.effectK(orc, Status.slow), 1);
    });

    test('Fire Bomb: every monster on the field loses 8% of its max HP (a boss 2%) as a blow; a kill pays its gold', () {
      final events = <GameEvent>[];
      final g = holding(pocketGame(), PocketKind.fireBomb)..listeners.add(events.add);
      inWave(g, [('orc', Tier.normal), ('orc', Tier.boss), ('slime', Tier.normal)]);
      final [orc, chief, slime] = [...g.enemies];
      slime.hp = 1;
      final (hp, bossHp, gold, kills) = (orc.hp, chief.hp, g.gold, g.kills);
      expect(g.usePocket(0), isTrue);
      expect(hp - orc.hp, closeTo(hitTaken(orc.maxHp * 0.08, orc.stats.def), 1e-6));
      expect(bossHp - chief.hp, closeTo(hitTaken(chief.maxHp * 0.02, chief.stats.def), 1e-6));
      expect(slime.alive, isFalse);
      expect(g.kills, kills + 1);
      expect(g.gold, greaterThanOrEqualTo(gold + slime.stats.cost));
      final used = events.whereType<PocketUsed>().single;
      expect((used.foes, used.killed, used.troops), (3, 1, 2));
      expect(logLine(used), 'Used Fire Bomb (3 monsters, 1 killed)');
    });

    test('Holy Water: every troop\'s bad effects end, and for 5 s none takes hold, nor a monster\'s stun', () {
      final g = holding(pocketGame(), PocketKind.holyWater);
      final (_, k) = inWave(g);
      g.addEffect(k, Status.weaken, 20, k: 0.5, bad: true);
      g.addEffect(k, Status.haste, 20, k: 0.8); // its own: stays
      expect(g.usePocket(0), isTrue);
      expect(g.under(k, Status.weaken), isFalse);
      expect(g.under(k, Status.haste), isTrue);
      g.addEffect(k, Status.weaken, 20, k: 0.5, bad: true);
      expect(g.under(k, Status.weaken), isFalse, reason: 'the ward');
      expect(g.stunTroop(k, 2), isFalse);
      runFor(g, 5.1);
      g.addEffect(k, Status.weaken, 20, k: 0.5, bad: true);
      expect(g.under(k, Status.weaken), isTrue);
    });

    test('Pocket Watch: every troop\'s skills ready now; the bombs\' and the watch\'s cooldowns', () {
      final g = holding(pocketGame(), PocketKind.pocketWatch);
      final (_, k) = inWave(g);
      runFor(g, 1);
      k
        ..skillAt = g.t
        ..awakenSkillAt = g.t
        ..heroSkillAt = g.t;
      expect(g.usePocket(0), isTrue);
      expect([k.skillAt, k.awakenSkillAt, k.heroSkillAt], everyElement(double.negativeInfinity));
      expect(g.pocketCoolLeft(PocketKind.pocketWatch), 90);
    });
  });

  group('the save and the Shop (decisions-log 332)', () {
    test('the stock and the slots come back; none written with nothing; an unknown kind or one twice skipped; the cap', () {
      final g = pocketGame();
      expect(g.toJson().containsKey('pocket'), isFalse);
      holding(g, PocketKind.fireBomb, n: 2, slot: 2);
      g.pocketStock[PocketKind.healBottle] = 4;
      final j = g.toJson();
      expect(j['pocket'], {
        'slots': [null, null, 'fireBomb', null],
        'stock': {'fireBomb': 2, 'healBottle': 4},
      });
      final back = reloaded(g);
      expect(back.pocketSlots, [null, null, PocketKind.fireBomb, null]);
      expect(back.pocketStock, {PocketKind.fireBomb: 2, PocketKind.healBottle: 4});
      final odd = jsonDecode(jsonEncode(j)) as Map<String, dynamic>
        ..['pocket'] = {
          'slots': ['dragonTear', 'fireBomb', 'fireBomb', null, 'healBottle'],
          'stock': {'fireBomb': 9, 'dragonTear': 1, 'healBottle': 0},
        };
      final o = Game.fromJson(odd);
      expect(o.pocketSlots, [null, PocketKind.fireBomb, null, null]);
      expect(o.pocketStock, {PocketKind.fireBomb: 3});
      expect(Game.fromJson(g.toJson()..remove('pocket')).pocketStock, isEmpty, reason: 'a save from before them');
    });

    test('the Shop never sells one, buys one at half its worth (its materials\' prices and its gold), outside the market', () {
      final g = inTown(pocketGame(), 20)..pocketStock[PocketKind.healBottle] = 2;
      final r = g.pocketRule(PocketKind.healBottle);
      final worth = g.pocketPrice(PocketKind.healBottle) +
          r.materials.entries.fold(0, (a, e) => a + g.townRules.materials[e.key]!.sell * e.value);
      expect(g.sellPrice(PocketKind.healBottle), (worth * 0.5).round());
      expect(g.whyNotBuy(PocketKind.healBottle), StoreRefusal.notSold);
      expect(g.marketed(PocketKind.healBottle), isFalse);
      final gold = g.gold;
      expect(g.sell(PocketKind.healBottle), 1);
      expect(g.gold, gold + g.sellPrice(PocketKind.healBottle));
      expect(g.inBag(PocketKind.healBottle), 1);
      expect(g.market, isEmpty, reason: 'no pressure recorded');
    });
  });

  test('the telemetry: pocketUsed and pocketCrafted passed on; a wave\'s pocket uses and crafts; its start\'s stock', () {
    final sink = _Kept();
    final g = pocketGame();
    TelemetryAdapter([sink], installId: 'i', session: 's', platform: 'test', now: () => DateTime.utc(2026, 10, 13)).attach(g);
    for (final MapEntry(key: m, value: n) in g.pocketRule(PocketKind.fireBomb).materials.entries) {
      g.materials[m] = n;
    }
    inTown(g, 20);
    expect(g.craftPocket(PocketKind.fireBomb), isTrue);
    expect(g.leaveTown(), isTrue);
    inWave(g);
    expect(g.usePocket(0), isTrue);
    for (final m in g.enemies) {
      m.dying = 0;
    }
    for (var i = 0; i < 40 && g.waveActive; i++) {
      g.tick(0.05);
    }
    g.tick(0.05);
    expect(passedOn, containsAll([EventKind.pocketUsed, EventKind.pocketCrafted]));
    final events = [for (final r in sink.of('event')) r['event'] as Map<String, dynamic>];
    expect(events.where((e) => e['kind'] == 'pocketCrafted').single['pocket'], 'fireBomb');
    expect(events.where((e) => e['kind'] == 'pocketUsed').single['foes'], 1);
    final wave = sink.of('wave').last;
    expect(wave['pocket'], {'fireBomb': 1});
    expect(wave['crafted'], {'fireBomb': 1});
    expect(wave['start']['pocket'], {'fireBomb': 1});
    expect(telemetryVersion, 18);
    expect(eventVersion, 18);
  });
}
