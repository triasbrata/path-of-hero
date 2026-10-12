// Ukir (item-artefact-design U2, decisions-log 183; docs/loot-items-relics.md "Ukir"): between waves, from wave 40, spare
// items fill a Pusaka's Ukir bar (its role's kinds 2 points, any other 1), five steps of 60/90/135/200/300 points worth
// 0.2/0.2/0.2/0.1/0.1 star, one budget of 180 points a boss interval for all Pusaka, at most 60 a tap. The constants,
// [pusakaAt] between and past the stars (God's Thunder's share and Dragon Crown's cap by their named rules), a tap's
// items and points (the fill order, no point spilled, a role's item never split, the Bangkit items kept), the shared
// budget and its reset, the refusals in order, what a star-up, a Pindah, a sale and a Lebur do with it, the star-ups for
// the enemy buffs, the save (the owner's save loads and writes unchanged) and the telemetry (tv 8); a Give row's tap
// (one kind alone, U4). The Bag's Carve strip and Give rows: carve_ui_test.dart.
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';
import 'package:tower_defense/telemetry.dart';

/// The owner's w89 save (a copy; never the real save): wave 89, bound God's Thunder ★1 (Penyihir), Grail ★2
/// (Armored Axeman), Void Eye ★1 (Templar); Dragon Heart ★2 and Dawn Star ★2 in the Gudang; Alliance taken; in the bag
/// gloves 76, shield 83, potion 83, bow 89, boots 72, staff 91, sword 86. On the field the types' next Awaken is grade
/// III's set (decisions-log 249), none of it the seven grade-I kinds Ukir takes, so a tap keeps none of the bag back.
Game w89() => Game.fromJson(jsonDecode(File('test/fixtures/save-20261002-2222-w89-sellbug.json').readAsStringSync()) as Map<String, dynamic>,
    Random(89), Random(189), Random(389));

/// [g] through its save, as a reload has it.
Game reload(Game g) => Game.fromJson(jsonDecode(jsonEncode(g.toJson())) as Map<String, dynamic>);

/// Wins the next wave of [g] at once: begun with nothing to spawn (through a due Town first), its one monster gone in the
/// tick (asah_test.dart).
void win(Game g) {
  g
    ..townPolicy = 'leave'
    ..startWave()
    ..queue.clear()
    ..units.add(g.monster('slime', Tier.normal, const Point(300, 60))..gone = true)
    ..tick(0.05);
  expect((g.waveActive, g.over), (false, false));
}

/// The bag's items, in [Item] order.
List<int> items(Game g) => [for (final i in droppedItems) g.inventory[i] ?? 0];

/// Every event [g] emits from now on, the telemetry's own too.
List<GameEvent> heard(Game g) {
  final out = <GameEvent>[];
  g.listeners.add(out.add);
  return out;
}

/// A [type] troop on the field at Awaken 0, its type holding no items: its whole grade I set (the seven kinds Ukir takes,
/// and its own new kind) is what a tap keeps back.
void field(Game g, String type) {
  g.upgrades.remove(type);
  g.units.add(Unit(Side.troop, type, g.statsOf(type), const Point(0, 60)));
}

/// What one tap on [relic] would take now ([Ukir.ukirTake]): exactly [items] for [points].
void expectTake(Game g, Relic relic, Map<Item, int> items, int points) {
  final take = g.ukirTake(relic);
  expect(take.items, items, reason: '$relic');
  expect(take.points, points, reason: '$relic');
}

/// What a Give row's tap of [item] on [relic] would take now ([Ukir.ukirTake] with `only`): exactly [items] for [points].
void expectGive(Game g, Relic relic, Item item, Map<Item, int> items, int points) {
  final take = g.ukirTake(relic, only: item);
  expect(take.items, items, reason: '$relic $item');
  expect(take.points, points, reason: '$relic $item');
}

/// A sink that keeps the records, through JSON.
class _Kept implements TelemetrySink {
  final records = <Map<String, dynamic>>[];

  @override
  void add(Map<String, Object?> record) => records.add(jsonDecode(jsonEncode(record)) as Map<String, dynamic>);

  @override
  Future<void> flush() async {}
}

void main() {
  test('the constants: 5 steps of 60/90/135/200/300 points (785) worth 0.2/0.2/0.2/0.1/0.1 star (0.8), 180 a boss '
      'interval, 60 a tap, 2 points for a role\'s kind and 1 for any other, from wave 40; every kind in one role', () {
    expect(ukirCost, [60, 90, 135, 200, 300]);
    expect(ukirCost.fold(0, (a, b) => a + b), 785);
    expect(ukirWorth, [0.2, 0.2, 0.2, 0.1, 0.1]);
    expect([for (var u = 0; u <= 5; u++) ukirWorthOf(u)], [0, 0.2, 0.4, 0.6, 0.7, 0.8]);
    expect((ukirPerBoss, ukirTap, ukirMatch, ukirAny, ukirFrom, ukirMidWave, ukirKeep), (180, 60, 2, 1, 40, false, true));
    expect((thunderSharePerStar, crownPerStar, ukirOmenStars), (0.2, 0.15, 1.0));
    // The owner's decisions at their defaults: +5 worth 0.8 star, the higher Ukir kept by a Lebur, the Gudang too, no
    // items for Asah.
    expect((ukirMelt, ukirGudang), (UkirMelt.higher, true));
    expect(asahItems, [0, 0]);
    expect([for (final i in droppedItems) roleItems.values.where((s) => s.contains(i)).length], List.filled(droppedItems.length, 1));
    expect(roleItems, {
      UkirRole.attack: {Item.sword, Item.bow, Item.gloves},
      UkirRole.guard: {Item.shield, Item.boots},
      UkirRole.life: {Item.potion, Item.staff},
    });
    // The design's roles; the oaths take no Ukir.
    final roles = {for (final r in Relic.values) if (r.pusaka) r: pusakaCatalog[r]!.role};
    expect(roles, {
      Relic.dragonHeart: UkirRole.guard, Relic.dawnStar: UkirRole.attack, Relic.godThunder: UkirRole.attack,
      Relic.grail: UkirRole.life, Relic.voidEye: UkirRole.attack, Relic.ironBanner: UkirRole.guard,
      Relic.bloodFang: UkirRole.life, Relic.warDrum: UkirRole.attack, Relic.mourningBell: UkirRole.life,
      Relic.dragonCrown: UkirRole.guard, Relic.oathOfOne: null, Relic.alliance: null,
      Relic.titanBane: UkirRole.attack, Relic.finishingBlade: UkirRole.attack, Relic.firstCut: UkirRole.attack,
      Relic.shellCracker: UkirRole.attack, Relic.twinFury: UkirRole.attack, Relic.steadyStance: UkirRole.guard,
      Relic.turtleShell: UkirRole.guard, Relic.dullingMail: UkirRole.guard, Relic.challengeLetter: UkirRole.guard,
      Relic.snareCord: UkirRole.attack,
      Relic.momentum: UkirRole.attack, Relic.bleedingEdge: UkirRole.attack, Relic.shatterShard: UkirRole.attack,
      Relic.painCrystal: UkirRole.guard, Relic.watchShield: UkirRole.guard, Relic.boneBuckler: UkirRole.guard,
      Relic.riposte: UkirRole.guard, Relic.manaLeech: UkirRole.life, Relic.lootersPouch: UkirRole.attack,
      Relic.spellCutter: UkirRole.attack, Relic.saltCharm: UkirRole.guard, Relic.wolfFeast: UkirRole.life,
      Relic.fullCup: UkirRole.life, Relic.hiddenFlask: UkirRole.life, Relic.livingMoss: UkirRole.life,
      Relic.pureWater: UkirRole.life,
      Relic.healerBane: UkirRole.attack, Relic.bullyClub: UkirRole.attack, Relic.unityRing: UkirRole.attack,
      Relic.runeGauntlet: UkirRole.attack, Relic.hawkFeather: UkirRole.attack, Relic.witherroot: UkirRole.guard,
      Relic.arrowCatcher: UkirRole.guard, Relic.stoneCoat: UkirRole.guard, Relic.heroCloak: UkirRole.guard,
      Relic.moonwell: UkirRole.life,
      Relic.emberBrand: UkirRole.attack, Relic.funeralPyre: UkirRole.attack, Relic.nullStone: UkirRole.attack,
      Relic.fallenFlag: UkirRole.attack, Relic.aegisSeal: UkirRole.guard, Relic.wardensHorn: UkirRole.guard,
      Relic.anchor: UkirRole.guard,
      Relic.manaHymn: UkirRole.life, Relic.saintTear: UkirRole.life, Relic.braveSong: UkirRole.life,
      Relic.haloLantern: UkirRole.life, Relic.hearth: UkirRole.life, Relic.heartbeat: UkirRole.life,
      Relic.mercyLily: UkirRole.life, Relic.brightSpring: UkirRole.life,
      Relic.loneWolf: UkirRole.attack, Relic.martyrFlame: UkirRole.attack, Relic.wideBlows: UkirRole.attack,
      Relic.champion: UkirRole.attack, Relic.vengeance: UkirRole.attack, Relic.mirror: UkirRole.guard,
      Relic.ghostStep: UkirRole.guard, Relic.iceGrip: UkirRole.guard, Relic.relicAltar: UkirRole.attack,
      Relic.vowSilence: UkirRole.attack,
      Relic.rageTotem: UkirRole.attack, Relic.guardianChain: UkirRole.guard, Relic.phalanx: UkirRole.guard,
      Relic.phoenix: UkirRole.life, Relic.soulShelter: UkirRole.life, Relic.manaFont: UkirRole.life,
      Relic.hexBlade: UkirRole.attack, Relic.glorySeeker: UkirRole.attack,
      // Batch G-3's three (decisions-log 243).
      Relic.vampireKiss: UkirRole.life, Relic.wrathPsalm: UkirRole.life, Relic.graveSeal: UkirRole.attack,
      // Batch G-4's six oaths (decisions-log 247): no Ukir, as the first two.
      Relic.fewOath: null, Relic.wallOath: null, Relic.bloodOath: null, Relic.vanguardOath: null, Relic.kingsOath: null,
      Relic.spellOath: null,
    });
  });

  test('pusakaAt: at Ukir 0 exactly the table; between two stars on the line, past ★3 by the last gap; never a star', () {
    // Every Fx with a number by stars (Anchor's stand has none: its trade, its second, carries them).
    final rows = [for (final r in Relic.values) if (r.pusaka && !r.oath) r];
    for (final r in rows) {
      for (final s in [1, 2, 3]) {
        for (final boss in [false, true]) {
          for (final (i, fx) in pusakaCatalog[r]!.fx.indexed) {
            if (fx.k.isEmpty) continue;
            expect(pusakaAt(r, s, boss: boss, ukir: 0, fx: i), pusakaAt(r, s, boss: boss, fx: i), reason: '$r ★$s');
          }
        }
      }
    }
    // The design's numbers (§4): Grail ★2 40% → 46% / 48%; Void Eye ★1 ×1.25 → ×1.31 / ×1.33, the boss ×1.19 at +5;
    // Dragon Heart ★2 ×2.2 → ×2.84; past the end ★3+5 ×3.64.
    expect(pusakaAt(Relic.grail, 2, ukir: 3), closeTo(0.46, 1e-12));
    expect(pusakaAt(Relic.grail, 2, ukir: 5), closeTo(0.48, 1e-12));
    expect(pusakaAt(Relic.voidEye, 1, ukir: 3), closeTo(1.31, 1e-12));
    expect(pusakaAt(Relic.voidEye, 1, ukir: 5), closeTo(1.33, 1e-12));
    expect(pusakaAt(Relic.voidEye, 1, boss: true, ukir: 5), closeTo(1.19, 1e-12));
    expect(pusakaAt(Relic.dragonHeart, 2, ukir: 5), closeTo(2.84, 1e-12));
    expect(pusakaAt(Relic.dragonHeart, 3, ukir: 5), closeTo(3.64, 1e-12));
    expect([for (var u = 0; u <= 5; u++) pusakaAt(Relic.dawnStar, 1, ukir: u)],
        [for (final w in [0, 0.2, 0.4, 0.6, 0.7, 0.8]) closeTo(1.3 + w * 0.15, 1e-12)]);
    // ★n+5 stays under ★(n+1) on every table that rises; a cut's falls (Iron Banner's is the share cut: it rises too).
    for (final r in rows) {
      final k = pusakaCatalog[r]!.fx.first.k;
      if (k.length < 3) continue;
      for (final s in [1, 2]) {
        final now = pusakaAt(r, s), up5 = pusakaAt(r, s, ukir: 5), next = pusakaAt(r, s + 1);
        expect((up5 - now).abs() < (next - now).abs(), isTrue, reason: '$r ★$s+5 $up5 vs ★${s + 1} $next');
        expect((up5 - now).sign, (next - now).sign, reason: '$r ★$s');
      }
    }
    // The named rules: God's Thunder's share 0.40 → 0.52 / 0.56 (its leaps by the stars alone), Dragon Crown's cap
    // 0.60 → 0.48; every step is the worth of its own.
    expect(pusakaAt(Relic.godThunder, 1, ukir: 3), closeTo(0.52, 1e-12));
    expect(pusakaAt(Relic.godThunder, 3, ukir: 5), closeTo(0.56, 1e-12));
    expect(pusakaCountAt(Relic.godThunder, 1), 2);
    expect(pusakaAt(Relic.dragonCrown, 1, ukir: 5), closeTo(0.48, 1e-12));
    expect(pusakaAt(Relic.dragonCrown, 1, ukir: 1), closeTo(0.57, 1e-12));
    // The texts read it: the book's lines and a Tas row's gist.
    expect(fxLines(Relic.godThunder, 1, ukir: 5), ['Each hit also hits 2 more monsters', 'within 3 tiles, for 56% damage']);
    expect(pusakaGist(Relic.dragonCrown, 1, ukir: 5), 'Max 48% HP a hit');
    expect(pusakaGist(Relic.grail, 2, ukir: 0), pusakaGist(Relic.grail, 2));
  });

  test('a tap: its role\'s kinds first (2 points each), the kind with the most spare each time (ties in Item order), '
      'at most 60 points; the Bangkit items of the types on the field kept back', () {
    final g = w89();
    expect(g.wave, 89);
    expect(items(g), [86, 83, 72, 89, 76, 83, 91]); // sword, shield, boots, bow, gloves, potion, staff
    expect(g.ukirKept.keys.where(droppedItems.contains), isEmpty); // grade III's sets next: no grade-I item
    expect(g.ukirSpare, {Item.sword: 86, Item.shield: 83, Item.boots: 72, Item.bow: 89, Item.gloves: 76, Item.potion: 83, Item.staff: 91});
    // God's Thunder (attack): bow down to sword's 86, then sword and bow in turn down to gloves' 76, then all three.
    expectTake(g, Relic.godThunder, {Item.bow: 15, Item.sword: 13, Item.gloves: 2}, 60);
    // The Grail (life): staff down to potion's 83, then potion and staff in turn.
    expectTake(g, Relic.grail, {Item.staff: 19, Item.potion: 11}, 60);
    expect(g.whyNotUkir(Relic.godThunder), isNull);
    final log = heard(g);
    expect(g.feedUkir(Relic.godThunder), isTrue);
    expect(items(g), [73, 83, 72, 74, 74, 83, 91]);
    final p = g.pusaka[Relic.godThunder]!;
    expect((p.ukir, p.feed, p.stars, p.type), (1, 0, 1, 'wizard')); // a full first step (60), the bar empty again
    expect((g.ukir.iv, g.ukir.pts, g.ukir.milli, g.ukirBudget), (17, 60, 200, 120));
    expect(log.whereType<UkirFed>().single.data,
        {'relic': 'godThunder', 'items': {'bow': 15, 'sword': 13, 'gloves': 2}, 'points': 60, 'type': 'wizard'});
    expect(log.whereType<UkirStep>().single.data, {'relic': 'godThunder', 'step': 1, 'stars': 1, 'type': 'wizard'});
    expect(g.log.entries.whereType<UkirFed>(), isEmpty); // the telemetry's only, never the battle log's
    // The share it leaps with now: 0.44.
    expect(g.relicEffect(Relic.godThunder), ['Each hit also hits 2 more monsters', 'within 3 tiles, for 44% damage']);
    expect(g.relicEffect(Relic.godThunder, stars: 1), ['Each hit also hits 2 more monsters', 'within 3 tiles, for 40% damage']);
    // Void Eye (attack) next: bow and gloves down to sword's 73, then sword, bow and gloves in turn.
    expectTake(g, Relic.voidEye, {Item.sword: 10, Item.bow: 10, Item.gloves: 10}, 60);
  });

  test('a tap never spills: at most what the step lacks and the budget left; a role\'s item is never split', () {
    final g = w89();
    final p = g.pusaka[Relic.grail]!..ukir = 1; // the next step costs 90
    expect(g.feedUkir(Relic.grail), isTrue);
    expect((p.ukir, p.feed, g.ukirLeft(Relic.grail)), (1, 60, 30));
    expect(g.ukirTake(Relic.grail).points, 30); // 15 items, not 30
    expect(g.feedUkir(Relic.grail), isTrue);
    expect((p.ukir, p.feed, g.ukirBudget), (2, 0, 90));
    // 1 point lacking, only life items: none fits whole, so another kind gives the point, or nothing does.
    p.feed = ukirCost[2] - 1;
    for (final i in Item.values) {
      g.inventory[i] = i == Item.potion ? 10 : 0;
    }
    expectTake(g, Relic.grail, <Item, int>{}, 0);
    expect(g.whyNotUkir(Relic.grail), ukirRefusals.items);
    g.inventory[Item.sword] = 1;
    expectTake(g, Relic.grail, {Item.sword: 1}, 1);
    // 3 points lacking: one potion (2), then a sword (1).
    p.feed = ukirCost[2] - 3;
    expectTake(g, Relic.grail, {Item.potion: 1, Item.sword: 1}, 3);
    // The budget: 90 left, so a step that lacks 135 takes 60, then 30, then nothing until the next boss.
    p.feed = 0;
    g.inventory[Item.potion] = 100;
    expect([g.ukirTake(Relic.grail).points, g.feedUkir(Relic.grail), g.ukirTake(Relic.grail).points], [60, true, 30]);
  });

  test('the budget: 180 points a boss interval for all Pusaka together, a new 180 once the boss wave is won', () {
    final g = w89();
    for (final r in [Relic.godThunder, Relic.grail, Relic.voidEye]) {
      expect(g.feedUkir(r), isTrue, reason: '$r');
    }
    expect((g.ukirBudget, g.ukir.pts), (0, 180));
    expect(g.whyNotUkir(Relic.dragonHeart), 'No points left: more at wave 90');
    expect(g.feedUkir(Relic.dragonHeart), isFalse);
    expect(g.pusaka[Relic.dragonHeart]!.feed, 0);
    win(g); // wave 90, the boss's: the next interval
    expect((g.wave, g.ukirBudget), (90, 180));
    expect(g.whyNotUkir(Relic.dragonHeart), isNull);
    expect(g.feedUkir(Relic.dragonHeart), isTrue);
    expect((g.ukir.iv, g.ukir.pts, g.ukirBudget), (18, 60, 120));
    for (var i = 0; i < 4; i++) {
      win(g); // waves 91-94: still the same interval
    }
    expect((g.wave, g.ukirBudget), (94, 120));
    win(g);
    expect((g.wave, g.ukirBudget), (95, 180));
  });

  test('the Bangkit items kept: a type on the field keeps what its next Bangkit needs; a type with none alive, or at '
      'Bangkit 3, keeps none', () {
    final g = w89();
    for (final i in Item.values) {
      g.inventory[i] = 0;
    }
    // The w89 types on the field need grade III's sets next: none of the seven kinds is kept.
    expect(g.ukirKept.keys.where(droppedItems.contains), isEmpty);
    field(g, 'soldier'); // its grade I set kept: two swords and shields, a boot, bow, glove and potion
    g
      ..inventory[Item.bow] = 1
      ..inventory[Item.gloves] = 1
      ..inventory[Item.shield] = 5;
    // Thunder's own kinds are all kept: it takes the shields past the soldier's two at 1 point each.
    expectTake(g, Relic.godThunder, {Item.shield: 3}, 3);
    g.inventory[Item.shield] = 2;
    expect(g.whyNotUkir(Relic.godThunder), ukirRefusals.items);
    // The knight has items but no troop on the field: it keeps nothing.
    expect(g.troops.where((u) => u.alive && u.type == 'knight'), isEmpty);
    expect(g.ukirKept.keys.where(droppedItems.contains), unorderedEquals([Item.sword, Item.shield, Item.boots, Item.bow, Item.gloves, Item.potion]));
    g.inventory[Item.bow] = 3;
    expectTake(g, Relic.godThunder, {Item.bow: 2}, 4);
  });

  test('the refusals in order: game over, not owned, mid-wave, before wave 40, an oath, full, the budget, no items', () {
    final g = w89();
    expect(g.whyNotUkir(Relic.ironBanner), pusakaRefusals.none);
    expect(g.whyNotUkir(Relic.alliance), ukirRefusals.oath);
    expect(g.whyNotUkir(Relic.dragonHeart), isNull); // in the Gudang: it takes Ukir too
    final p = g.pusaka[Relic.grail]!..ukir = ukirCost.length;
    expect((g.whyNotUkir(Relic.grail), g.ukirTake(Relic.grail).points), (ukirRefusals.full, 0));
    expect(g.feedUkir(Relic.grail), isFalse);
    expect((p.ukir, p.feed), (5, 0));
    g.startWave();
    expect(g.waveActive, isTrue);
    for (final r in [Relic.grail, Relic.alliance, Relic.godThunder]) {
      expect(g.whyNotUkir(r), ukirRefusals.midWave, reason: '$r');
    }
    expect(g.whyNotUkir(Relic.ironBanner), pusakaRefusals.none);
    g.lives = 0;
    expect(g.whyNotUkir(Relic.grail), assignRefusals.over);
    // Before wave 40: a plain game at wave 39, then 40.
    final h = Game(Random(1), Random(2))
      ..givePusaka(Relic.dawnStar, type: 'priest')
      ..givePusaka(Relic.oathOfOne)
      ..inventory[Item.sword] = 50
      ..wave = 39;
    expect((h.whyNotUkir(Relic.dawnStar), h.whyNotUkir(Relic.oathOfOne)), (ukirRefusals.from, ukirRefusals.from));
    h.wave = ukirFrom;
    expect((h.whyNotUkir(Relic.dawnStar), h.whyNotUkir(Relic.oathOfOne)), (null, ukirRefusals.oath));
    h.inventory[Item.sword] = 0;
    expect(h.whyNotUkir(Relic.dawnStar), ukirRefusals.items);
    expect([ukirRefusals.midWave, ukirRefusals.from, ukirRefusals.oath, ukirRefusals.full, ukirRefusals.items],
        ['Only between waves', 'Carve opens at wave 40', "An Oath can't be carved", 'Carve is full', 'Not enough items']);
    expect(ukirRefusals.bound, 'Equipped Artifacts only'); // unreachable while the Vault's take Carve ([ukirGudang])
  });

  test('a Give row\'s tap (U4): that kind alone, by the same rules: its points (2 for the role\'s kind, 1 for another), at '
      'most 60, the step and the budget; the Bangkit items kept; never split; refused when the kind gives nothing', () {
    final g = w89();
    // The Grail (life) given sword: 1 point each, 60 swords; given staff, its own kind: 2 points each, 30.
    expectGive(g, Relic.grail, Item.sword, {Item.sword: 60}, 60);
    expectGive(g, Relic.grail, Item.staff, {Item.staff: 30}, 60);
    expect(g.whyNotUkir(Relic.grail, only: Item.staff), isNull);
    final log = heard(g);
    expect(g.feedUkir(Relic.grail, only: Item.boots), isTrue);
    expect(items(g), [86, 83, 12, 89, 76, 83, 91]); // 60 boots, nothing else
    expect(log.whereType<UkirFed>().single.data['items'], {'boots': 60});
    expect((g.pusaka[Relic.grail]!.ukir, g.ukirBudget), (1, 120));
    // The Bangkit items kept: a soldier at Awaken 0 on the field keeps one bow and one glove; a kind with none spare gives
    // nothing.
    field(g, 'soldier');
    g.inventory
      ..[Item.bow] = 1
      ..[Item.gloves] = 3;
    expect(g.ukirTake(Relic.godThunder, only: Item.bow).points, 0);
    expect(g.whyNotUkir(Relic.godThunder, only: Item.bow), ukirRefusals.items);
    expect(g.feedUkir(Relic.godThunder, only: Item.bow), isFalse);
    expectGive(g, Relic.godThunder, Item.gloves, {Item.gloves: 2}, 4);
    // Never split: 1 point lacking, the role's kind alone gives none; another kind gives it.
    final p = g.pusaka[Relic.grail]!..feed = ukirCost[1] - 1;
    expect((g.ukirTake(Relic.grail, only: Item.potion).points, g.whyNotUkir(Relic.grail, only: Item.potion)), (0, ukirRefusals.items));
    expectGive(g, Relic.grail, Item.shield, {Item.shield: 1}, 1);
    expect(g.feedUkir(Relic.grail, only: Item.shield), isTrue);
    expect((p.ukir, p.feed), (2, 0));
    // The other refusals come first, as a plain tap's.
    g.startWave();
    expect(g.whyNotUkir(Relic.grail, only: Item.potion), ukirRefusals.midWave);
  });

  test('the effect: a step refits its type at once (Dragon Heart\'s HP), Dragon Crown\'s cap and Dawn Star\'s attack '
      'follow, as the book says', () {
    final g = Game(Random(1), Random(2))..wave = 60;
    g.givePusaka(Relic.dragonHeart, type: 'priest', stars: 2);
    final p = g.pusaka[Relic.dragonHeart]!..type = null;
    final base = g.statsOf('priest').hp;
    p.type = 'priest';
    expect(g.statsOf('priest').hp, (base * 2.2).round());
    g.inventory[Item.shield] = 200;
    final u = g.troops.single;
    expect(u.maxHp, (base * 2.2).round());
    expect(g.feedUkir(Relic.dragonHeart), isTrue);
    final hp1 = (base * pusakaAt(Relic.dragonHeart, 2, ukir: 1)).round();
    expect((p.ukir, u.maxHp, g.statsOf('priest').hp), (1, hp1, hp1));
    expect(pusakaAt(Relic.dragonHeart, 2, ukir: 1), closeTo(2.36, 1e-12));
    expect(g.impacts.last.$2, awakeFx('upgrade', maxAwaken)); // the gold burst
    expect(g.hpInfo('priest').$2, contains('${relicNames[Relic.dragonHeart]} ★2: x2.36'));
    g.givePusaka(Relic.dragonHeart, type: 'priest', stars: 2, ukir: 5);
    final hp5 = (base * pusakaAt(Relic.dragonHeart, 2, ukir: 5)).round();
    expect((p.ukir, g.statsOf('priest').hp, u.maxHp), (5, hp5, hp5));
    g.givePusaka(Relic.dragonCrown, type: 'knight', ukir: 5);
    expect(g.relicEffect(Relic.dragonCrown), ['No hit takes over 48% max HP']);
    expect(g.relicEffect(Relic.dragonCrown, stars: 1), ['No hit takes over 60% max HP']); // a card's: no Ukir
    g.givePusaka(Relic.dawnStar, type: 'knight_templar', stars: 3, ukir: 5);
    expect(pusakaGist(Relic.dawnStar, 3, ukir: g.pusaka[Relic.dawnStar]!.ukir), '+72% attack'); // 1.6 + 0.8 × 0.15
  });

  test('kept, moved, lost: a star-up keeps Ukir and its bar, a Pindah moves them, a sale loses them, a Lebur keeps the '
      'higher Ukir and its target\'s bar', () {
    final g = w89();
    expect(g.feedUkir(Relic.dragonHeart), isTrue); // in the Gudang, ★2: step 1
    expect(g.feedUkir(Relic.dragonHeart), isTrue); // 60 of 90
    final heart = g.pusaka[Relic.dragonHeart]!;
    expect((heart.ukir, heart.feed), (1, 60));
    // A Pindah: God's Thunder to the Templar's place, with its Ukir.
    g.givePusaka(Relic.godThunder, type: 'wizard', ukir: 2);
    g.pusaka[Relic.godThunder]!.feed = 40;
    expect(g.bindPusaka(Relic.godThunder, 'priest'), isTrue);
    expect((g.pusaka[Relic.godThunder]!.type, g.pusaka[Relic.godThunder]!.ukir, g.pusaka[Relic.godThunder]!.feed), ('priest', 2, 40));
    expect(g.unbindPusaka(Relic.godThunder), isTrue);
    expect((g.pusaka[Relic.godThunder]!.ukir, g.pusaka[Relic.godThunder]!.feed), (2, 40));
    // An Asah, in the next interval: ★3, its Ukir and bar kept.
    win(g);
    expect(g.asah(Relic.dragonHeart), isTrue);
    expect((heart.stars, heart.ukir, heart.feed), (3, 1, 60));
    // A Lebur: Dawn Star (Gudang, ★2, +3) into the Grail (★2, +1 with 10 points): the Grail ★3 +3 with its own 10.
    g.pusaka[Relic.dawnStar]!.ukir = 3;
    g.pusaka[Relic.grail]!
      ..ukir = 1
      ..feed = 10;
    expect(g.leburUkir(Relic.dawnStar, Relic.grail), 3);
    expect(g.lebur(Relic.dawnStar, Relic.grail), isTrue);
    expect((g.pusaka[Relic.grail]!.stars, g.pusaka[Relic.grail]!.ukir, g.pusaka[Relic.grail]!.feed), (3, 3, 10));
    // A lower one melted in: the target keeps its own.
    g.givePusaka(Relic.ironBanner, ukir: 1);
    g.givePusaka(Relic.voidEye, type: 'knight_templar', ukir: 4);
    g.pusaka[Relic.voidEye]!.feed = 7;
    expect(g.lebur(Relic.ironBanner, Relic.voidEye), isTrue);
    expect((g.pusaka[Relic.voidEye]!.ukir, g.pusaka[Relic.voidEye]!.feed), (4, 7));
    // Melted into the last step: the bar has nothing more to fill.
    g.givePusaka(Relic.warDrum, ukir: 5);
    g.pusaka[Relic.voidEye]!.ukir = 2;
    expect(g.lebur(Relic.warDrum, Relic.voidEye), isTrue);
    expect((g.pusaka[Relic.voidEye]!.ukir, g.pusaka[Relic.voidEye]!.feed), (5, 0));
    // A sale: Dragon Heart sells from the Gudang, its Ukir gone with it; the run's worth fed stays.
    final milli = g.ukir.milli;
    g.inTown = true; // the Shop buys only in a Town
    expect(g.sell(Relic.dragonHeart), 1);
    expect(g.pusaka.containsKey(Relic.dragonHeart), isFalse);
    g.givePusaka(Relic.dragonHeart);
    expect((g.pusaka[Relic.dragonHeart]!.ukir, g.pusaka[Relic.dragonHeart]!.feed, g.ukir.milli), (0, 0, milli));
  });

  test('the star-ups for the enemy buffs: one each time the run\'s worth fed passes a full star (1000 thousandths), '
      'on the step that passes it; deterministic', () {
    List<(Relic, int, int)> run() {
      final g = w89(), log = heard(g), steps = <(Relic, int, int)>[];
      for (final i in Item.values) {
        g.inventory[i] = 1000; // never short: every point from a role's kind but the odd last one
      }
      var fed = 0;
      for (var i = 0; i < 8; i++) {
        fed += g.ukirFill();
        expect(g.ukirBudget, 0, reason: 'interval $i');
        for (var w = 0; w < bossEvery; w++) {
          win(g);
        }
      }
      expect(fed, 8 * ukirPerBoss);
      for (final s in log.whereType<UkirStep>()) {
        steps.add((s.relic, s.step, s.starUps));
      }
      // Only the bound three rose, together; the Gudang's stayed.
      expect([for (final r in [Relic.godThunder, Relic.grail, Relic.voidEye, Relic.dragonHeart]) g.pusaka[r]!.ukir], [4, 4, 3, 0]);
      expect((g.pusaka[Relic.voidEye]!.feed, g.ukir.milli), (185, 2000));
      return steps;
    }

    final steps = run();
    var milli = 0;
    for (final (r, step, starUps) in steps) {
      final was = milli;
      milli += (ukirWorth[step - 1] * 1000).round();
      expect(starUps, milli ~/ 1000 - was ~/ 1000, reason: '$r step $step');
    }
    // Thunder +1, Grail +1, Void Eye +1 (600); Thunder +2 (800), Grail +2 (1000: the first star-up); ... Grail +4 (2000).
    expect(steps, [
      (Relic.godThunder, 1, 0), (Relic.grail, 1, 0), (Relic.voidEye, 1, 0), (Relic.godThunder, 2, 0), (Relic.grail, 2, 1),
      (Relic.voidEye, 2, 0), (Relic.godThunder, 3, 0), (Relic.grail, 3, 0), (Relic.voidEye, 3, 0), (Relic.godThunder, 4, 0),
      (Relic.grail, 4, 1),
    ]);
    expect(run(), steps); // the same again: no die
  });

  test('a star-up gives the enemy its Bayangan levels while they are on (omen.dart\'s hook), as a take of that Pusaka '
      'would; none while they are off', () {
    List<(String, OmenKind, int, int)> run({required bool on}) {
      omensOn = on;
      addTearDown(() => omensOn = omensDefault);
      final g = w89()..omensOwed.clear(), log = heard(g); // no old save's catch-up: only Ukir's levels
      for (final i in Item.values) {
        g.inventory[i] = 1000;
      }
      for (var i = 0; i < 2; i++) {
        g.ukirFill(); // the run's 5th step, the Grail's +2 in the second interval, passes the first full star
        for (var w = 0; w < bossEvery; w++) {
          win(g);
        }
      }
      expect(g.pusaka[Relic.grail]!.ukir, 2);
      return [
        for (final e in log)
          if (e is OmenGained) (e.from, e.omen, e.level, e.gained),
      ];
    }

    final grail = w89().pusaka[Relic.grail]!;
    expect(run(on: true), [('ukir', omenCounter(Relic.grail, grail.type), omenMarks[Relic.grail.rarity]!, omenMarks[Relic.grail.rarity]!)]);
    expect(run(on: false), isEmpty);
  });

  test('the save: the owner\'s save loads and writes as before; Ukir, its bar and the run\'s budget come back', () {
    final g = w89(), before = jsonEncode(g.toJson());
    expect(g.toJson().containsKey('ukir'), isFalse);
    for (final p in (g.toJson()['pusaka'] as Map).values) {
      expect((p as Map).keys.where((k) => k == 'ukir' || k == 'feed'), isEmpty);
    }
    expect(jsonEncode(reload(g).toJson()), before);
    expect(g.feedUkir(Relic.grail), isTrue);
    expect(g.feedUkir(Relic.godThunder), isTrue);
    g.pusaka[Relic.grail]!.feed = 33;
    final j = g.toJson();
    expect(j['ukir'], {'iv': 17, 'pts': 120, 'milli': 400});
    expect((j['pusaka'] as Map)['grail'], {'type': 'armored_axeman', 'stars': 2, 'binds': 1, 'ukir': 1, 'feed': 33});
    expect((j['pusaka'] as Map)['voidEye'], {'type': 'knight_templar', 'stars': 1, 'binds': 4});
    final h = reload(g);
    expect((h.pusaka[Relic.grail]!.ukir, h.pusaka[Relic.grail]!.feed, h.pusaka[Relic.godThunder]!.ukir), (1, 33, 1));
    expect((h.ukir.iv, h.ukir.pts, h.ukir.milli, h.ukirBudget), (17, 120, 400, 60));
    expect(jsonEncode(h.toJson()), jsonEncode(g.toJson()));
    expect(h.statsOf('wizard').hp, g.statsOf('wizard').hp);
    // A bad save: steps past the last, a bar past its cost, an oath's Ukir: clamped.
    final bad = jsonDecode(jsonEncode(j)) as Map<String, dynamic>;
    (bad['pusaka'] as Map)['grail'] = {'type': 'armored_axeman', 'stars': 2, 'ukir': 9, 'feed': 999};
    (bad['pusaka'] as Map)['godThunder'] = {'type': 'wizard', 'stars': 1, 'ukir': 2, 'feed': 999};
    (bad['pusaka'] as Map)['alliance'] = {'stars': 1, 'ukir': 3};
    final b = Game.fromJson(bad);
    expect([b.pusaka[Relic.grail]!.ukir, b.pusaka[Relic.grail]!.feed], [5, 0]);
    expect([b.pusaka[Relic.godThunder]!.ukir, b.pusaka[Relic.godThunder]!.feed], [2, 134]);
    expect(b.pusaka[Relic.alliance]!.ukir, 0);
  });

  test('telemetry tv 8: the taps and steps go out as they happen; the next wave\'s record sums them and lists each '
      'Pusaka\'s Ukir; a wave with none has no Ukir fields', () {
    expect((telemetryVersion >= 8, eventVersion >= 8), (true, true)); // 8 brought the Ukir; later versions keep it
    final g = w89(), sink = _Kept(), adapter = TelemetryAdapter([sink], installId: 'i', session: 's', platform: 'test')..attach(g);
    win(g); // a wave with no Ukir
    expect(g.feedUkir(Relic.godThunder), isTrue); // wave 90: a new interval
    expect(g.feedUkir(Relic.voidEye), isTrue);
    win(g);
    adapter.detach();
    expect(sink.records.every((r) => r['tv'] == telemetryVersion), isTrue);
    final events = [for (final r in sink.records) if (r['rec'] == 'event') r['event'] as Map<String, dynamic>];
    final fed = events.where((e) => e['kind'] == 'ukirFed').toList(), steps = events.where((e) => e['kind'] == 'ukirStep').toList();
    expect(fed.map((e) => (e['relic'], e['points'], e['type'], e['v'])), [('godThunder', 60, 'wizard', eventVersion), ('voidEye', 60, 'knight_templar', eventVersion)]);
    expect(fed.first['items'], {'bow': 15, 'sword': 13, 'gloves': 2});
    expect(steps.map((e) => (e['relic'], e['step'], e['stars'], e.containsKey('starUps'))), [('godThunder', 1, 1, false), ('voidEye', 1, 1, false)]);
    final waves = [for (final r in sink.records) if (r['rec'] == 'wave') r];
    expect(waves.map((w) => w['wave']), [90, 91]);
    expect(waves.first.keys.where((k) => k.startsWith('ukir')), isEmpty);
    expect((waves.first['pusaka'] as Map)['godThunder'], isNot(contains('ukir')));
    final last = waves.last;
    expect(last['ukirPoints'], 120);
    expect(last['ukirSteps'], {'godThunder': 1, 'voidEye': 1});
    expect(last['ukirItems'], {'bow': 25, 'sword': 23, 'gloves': 12});
    expect(((last['pusaka'] as Map)['godThunder'] as Map)['ukir'], 1);
    expect(((last['start'] as Map)['pusaka'] as Map)['voidEye'], {'type': 'knight_templar', 'stars': 1, 'ukir': 1});
    expect(((waves.first['start'] as Map)['pusaka'] as Map)['voidEye'], {'type': 'knight_templar', 'stars': 1});
  });

  test('Asah takes no items by default (owner decision 4, its default)', () {
    final g = w89();
    win(g);
    expect(g.asahItemTake(Relic.dragonHeart), isEmpty);
    final log = heard(g);
    expect(g.asah(Relic.dragonHeart), isTrue);
    expect(log.whereType<PusakaAsah>().single.data.containsKey('items'), isFalse);
  });
}
