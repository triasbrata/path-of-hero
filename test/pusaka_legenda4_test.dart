// Batch G-4 (decisions-log 247; catalog-design §3.3 and §5.2, catalog-bayangan-v2 §4): the last six Legenda Artifacts,
// all oaths: the whole army's, ★1 only, no Carve, at most one a run, each a rule with a real cost. Oath of the Few (×1.35
// HP and attack while 24 troops or fewer live; above it the oath waits, and with the board's army cap no 25th joins),
// Oath of the Wall (HP up, attack and heal down), Blood Oath (attack up, heals in a wave halved), Oath of the Vanguard (up
// close up, the rest down), Oath of Kings (the Hero's aura up, a Hero's own stats down) and Oath of Spells (skills sooner,
// never under cdFloor; normal hits down). Each one's rule and cost, its words, its row (rarity, the atlas's icon, no Carve
// role, no build name, counter, chest-only), the Shadows that answer it, the chest offering it, one oath a run, the
// Legenda pool at the design's 30, "every Legenda found" (a Legenda roll steps down to an Epik) against one missing, the
// save keeping an oath, and the Legenda cards on the Boss Chest at 915x412 and 1266x713. docs/loot-items-relics.md
// "Legenda".
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flame/game.dart' hide Game;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';
import 'package:tower_defense/main.dart';

import 'hero_skill_helpers.dart';
import 'hud_font.dart';

/// The batch's six, in [Relic] order (after batch G-3's three).
const batch = [Relic.fewOath, Relic.wallOath, Relic.bloodOath, Relic.vanguardOath, Relic.kingsOath, Relic.spellOath];

/// A game with no skills cast, so what happens is the oath's doing.
Game plain([Random? rng]) => bareGame(rng)
  ..skills = false
  ..heroSkills = false
  ..awakenSkills = false
  ..monsterSkills = false;

/// [g] through its save and back, as the board loads it.
Game reload(Game g) => Game.fromJson(jsonDecode(jsonEncode(g.toJson())) as Map<String, dynamic>);

/// Holds [u] where it stands: it neither walks nor attacks.
Unit stand(Unit u) => u
  ..busyUntil = hold
  ..cd = hold;

/// What troop [u]'s next normal attack takes off [foe] (its cooldown over now; it waits again after); a shot is let fly.
double blow(Game g, Unit u, Unit foe) {
  final before = foe.hp;
  u.cd = 0;
  g.tick(0.05);
  u.cd = hold;
  for (var i = 0; i < 60 && g.shots.isNotEmpty; i++) {
    g.tick(0.05);
  }
  return before - foe.hp;
}

/// A monster of [type] and [tier] at [at] with HP to spare, standing.
Unit bigFoe(Game g, Point<double> at, [String type = 'orc', Tier tier = Tier.normal]) => foeAt(g, type, at, tier)
  ..maxHp = 1000000
  ..hp = 1e6;

/// A knight, an archer and a priest standing (cells (2, 3), (0, 1), (0, 5)), [oath] taken (none: no oath).
(Game, Unit, Unit, Unit) trio(Relic? oath) {
  final g = plain(Random(2));
  final k = stand(placeNow(g, 'knight', 2, 3)), a = stand(placeNow(g, 'archer', 0, 1)), p = stand(placeNow(g, 'priest', 0, 5));
  if (oath != null) g.givePusaka(oath);
  return (g, k, a, p);
}

/// [n] soldiers and archers standing, cell by cell from (0, 0), in [g].
List<Unit> fill(Game g, int n) => [
      for (var i = 0; i < n; i++) stand(placeNow(g, i.isEven ? 'soldier' : 'archer', i ~/ rows, i % rows)),
    ];

/// Draft dice that roll every rarity at [roll] (0.99: Legenda) and take the [pick]th card of a pool (wrapping).
class _Dice implements Random {
  _Dice(this.roll, [this.pick = 0]);
  final double roll;
  final int pick;

  @override
  double nextDouble() => roll;

  @override
  int nextInt(int max) => pick % max;

  @override
  bool nextBool() => false;
}

/// A chest game between waves at [wave] on [draft] dice, not the run's first chest (that one is three Epik).
Game chestGame({int wave = legendFrom, Random? draft}) => plain()
  ..offers = true
  ..wave = wave
  ..chestsGiven = 1
  ..draft = draft ?? _Dice(0.99);

/// Every live Legenda, in [Relic] order.
List<Relic> get liveLegenda => [for (final r in Relic.values) if (r.pusaka && r.rarity == Rarity.legenda && pusakaCatalog[r]!.live) r];

void main() {
  tearDown(() => omensOn = false);

  group('the rows', () {
    test("six oaths appended after batch G-3's three (save keys), the army's, chest-only, never sold, ★1 only, no Carve and no "
        "build name, in the game; names, the atlas's padlocks and catalog-bayangan-v2's counters, which now name them", () {
      expect(Relic.values.skipWhile((r) => r != Relic.graveSeal).skip(1).take(batch.length).toList(), batch,
          reason: "right after G-3 (the forge's small relics follow)");
      expect({for (final r in batch) r: relicNames[r]}, {
        Relic.fewOath: 'Oath of the Few',
        Relic.wallOath: 'Oath of the Wall',
        Relic.bloodOath: 'Blood Oath',
        Relic.vanguardOath: 'Oath of the Vanguard',
        Relic.kingsOath: 'Oath of Kings',
        Relic.spellOath: 'Oath of Spells',
      });
      for (final r in batch) {
        final art = pusakaCatalog[r]!;
        expect((r.rarity, r.scope, r.oath, r.pusaka, r.store, art.live, maxStars(r)), (Rarity.legenda, RelicScope.army, true, true, false, true, 1),
            reason: '$r');
        expect((art.role, art.fx.isEmpty, art.epithet, buildEpithets[r], art.healerCounter, ukirPerStar[r]), (null, true, null, null, null, null),
            reason: '$r: bespoke, no Carve, no build name');
        expect((art.icon.sheet, art.icon.x, art.icon.y, art.icon.tint), ('artifact_icons.png', artifactIcon(r.name).x, artifactIcon(r.name).y, null),
            reason: '$r');
      }
      // Their cells in the Artifact atlas (artifact_icons.dart, mapped with the sheet): the padlocks after Oath of One's
      // and Alliance's, each its own colour.
      expect([for (final r in batch) artifactIconKinds.indexOf(r.name)], [63, 64, 65, 66, 67, 68]);
      (String, int, int, int?) cell(Art a) => (a.icon.sheet, a.icon.x, a.icon.y, a.icon.tint);
      final cells = [for (final a in pusakaCatalog.values) cell(a)];
      for (final r in batch) {
        expect(cells.where((c) => c == cell(pusakaCatalog[r]!)), hasLength(1), reason: '$r: its own icon');
      }
      expect(liveG4, isTrue);
      expect({for (final r in batch) r: pusakaCatalog[r]!.counter}, {
        Relic.fewOath: OmenKind.guard,
        Relic.wallOath: OmenKind.dusk,
        Relic.bloodOath: OmenKind.oathbane,
        Relic.vanguardOath: OmenKind.riderRush,
        Relic.kingsOath: OmenKind.heroHunt,
        Relic.spellOath: OmenKind.spellWard,
      });
      // The answers filled (G-3B's five had none; the core Guard names the Few beside the first two oaths).
      expect({
        for (final k in const [OmenKind.guard, OmenKind.dusk, OmenKind.oathbane, OmenKind.riderRush, OmenKind.heroHunt, OmenKind.spellWard])
          k: k.answers,
      }, {
        OmenKind.guard: [Relic.oathOfOne, Relic.alliance, Relic.fewOath],
        OmenKind.dusk: [Relic.wallOath],
        OmenKind.oathbane: [Relic.bloodOath],
        OmenKind.riderRush: [Relic.vanguardOath],
        OmenKind.heroHunt: [Relic.kingsOath],
        OmenKind.spellWard: [Relic.spellOath],
      });
      for (final r in batch) {
        expect(omenPool(Rarity.legenda), contains(pusakaCatalog[r]!.counter), reason: '$r');
      }
      // The Shop never sells one, and an oath is never in the Gudang, so it never sells back either.
      expect(storeGoods.where(batch.contains), isEmpty, reason: 'never in the Shop');
      for (final r in batch) {
        final g = Game()..wave = storeFrom;
        g.givePusaka(r, type: 'knight'); // a type given is ignored: an oath is the army's
        expect((g.pusaka[r]!.type, g.gudang.isEmpty, g.inBag(r), g.whyNotSell(r), g.sell(r)), (null, true, 0, StoreRefusal.none, 0), reason: '$r');
        expect((g.whyNotBind(r, 'knight'), g.whyNotUnbind(r)), (pusakaRefusals.oath, pusakaRefusals.oath), reason: '$r');
      }
    });

    test('the catalog is whole: 90 Artifacts, 30 a rarity, all in the game; 90 distinct icons', () {
      final rows = pusakaCatalog.entries;
      expect(rows, hasLength(90));
      for (final rarity in const [Rarity.langka, Rarity.epik, Rarity.legenda]) {
        expect(rows.where((e) => e.value.rarity == rarity && e.value.live), hasLength(30), reason: '$rarity');
      }
      expect({for (final a in pusakaCatalog.values) (a.icon.x, a.icon.y)}, hasLength(90));
      expect([for (final r in Relic.values) if (r.oath) r], [Relic.oathOfOne, Relic.alliance, ...batch], reason: 'eight oaths');
    });

    test("their words, from the constants: the card and tooltip lines, the Bag row's gist; ★2 and ★3 read ★1; plain English",
        () {
      final g = Game();
      expect({for (final r in batch) r: g.relicEffect(r, stars: 1)}, {
        Relic.fewOath: ['Oath: up to 24 troops (not $armyMaxBoard)', 'All troops: +35% HP and attack'],
        Relic.wallOath: ['Oath: all troops +40% HP', '-20% attack and heal'],
        Relic.bloodOath: ['Oath: all troops +30% attack', 'Heals on troops -50%'],
        Relic.vanguardOath: ['Oath: up-close troops +40% HP and attack', 'Others -25% attack and heal'],
        Relic.kingsOath: ['Oath: a Hero gives all troops +25% (not 15%)', "Heroes' own stats x2 (not x3)"],
        Relic.spellOath: ['Oath: skills come back 20% sooner', 'Normal hits -20% damage'],
      });
      expect({for (final r in batch) r: pusakaGist(r, 1)}, {
        Relic.fewOath: '24 troops: +35%',
        Relic.wallOath: '+40% HP, -20% attack',
        Relic.bloodOath: '+30% attack, -50% heals',
        Relic.vanguardOath: 'Up close +40%, others -25%',
        Relic.kingsOath: 'Aura +25%, Heroes x2',
        Relic.spellOath: 'Skills 20% sooner, hits -20%',
      });
      for (final r in batch) {
        expect(g.relicEffect(r, stars: 3), g.relicEffect(r, stars: 1), reason: '$r: ★3 is ★1');
        for (final line in [...g.relicEffect(r), pusakaGist(r, 1)]) {
          expect(line.codeUnits.every((c) => c < 128), isTrue, reason: '$r: $line');
        }
        // Not owned, then taken: the oath's lines in the book, no totals but the Few's.
        expect(g.pusakaWhere(r), 'Not owned yet');
      }
      for (final r in batch) {
        final (o, _, _, _) = trio(r);
        expect((o.pusakaWhere(r), o.relicInfo(r).$2.contains(oathLine)), ('On: all troops ★1', true), reason: '$r');
        expect(o.pusakaTotals(r), r == Relic.fewOath ? ['Now: all troops, +35%'] : <String>[], reason: '$r');
      }
      expect((fewWaiting, fewWaitingNote, fewWaitingRow(30), fewOathBar),
          ('Waiting: keep 24 troops or fewer', 'Oath waits: keep 24 troops or fewer', 'Waiting: 30/24 troops', 'Oath of the Few: up to 24 troops'));
      expect((fewOathK.army, fewOathK.k, wallOathK.hp, wallOathK.dmg, bloodOathK.dmg, bloodOathK.healIn), (24, 1.35, 1.4, 0.8, 1.3, 0.5));
      expect((vanguardOathK.melee, vanguardOathK.back, kingsOathK.aura, kingsOathK.heroBoost, spellOathK.cd, spellOathK.blow, cdFloor),
          (1.4, 0.75, 1.25, 2.0, 0.8, 0.8, 5.0));
    });
  });

  group('the rules and their costs', () {
    test("Oath of the Wall: every troop's max HP ×1.4, its attack (a healer's heal) ×0.8", () {
      final (g, k, a, p) = trio(null);
      final (w, wk, wa, wp) = trio(Relic.wallOath);
      for (final (type, was, now) in [('knight', k, wk), ('archer', a, wa), ('priest', p, wp)]) {
        expect(w.statsOf(type).hp, (g.statsOf(type).hp * wallOathK.hp).round(), reason: type);
        expect(w.statsOf(type).dmg, closeTo(g.statsOf(type).dmg * wallOathK.dmg, 1e-9), reason: type);
        expect((now.maxHp, now.stats.dmg), (w.statsOf(type).hp, w.statsOf(type).dmg), reason: '$type: refit at once');
        expect(now.hp, greaterThan(was.hp), reason: '$type: the HP it gains comes with it');
      }
    });

    test("Blood Oath: every troop's attack ×1.3, a healer's heal not; a heal on a troop in a wave ×0.5; the after-wave heal "
        'and the Grail whole', () {
      final (g, _, _, _) = trio(null);
      final (b, k, _, _) = trio(Relic.bloodOath);
      for (final type in ['knight', 'archer']) {
        expect(b.statsOf(type).dmg, closeTo(g.statsOf(type).dmg * bloodOathK.dmg, 1e-9), reason: type);
        expect(b.statsOf(type).hp, g.statsOf(type).hp, reason: type);
      }
      expect(b.statsOf('priest').dmg, g.statsOf('priest').dmg, reason: "a healer's heal not");
      double healed(Game h, Unit v) {
        v
          ..maxHp = 100000
          ..hp = 1000;
        h.addEffect(v, Status.heal, 1, k: 100);
        runFor(h, 1.2);
        return v.hp - 1000;
      }

      final (h0, k0, _, _) = trio(null);
      bigFoe(h0, k0.pos + const Point(60, 0)); // a wave on: a monster on the field
      bigFoe(b, k.pos + const Point(60, 0));
      final whole = healed(h0, k0);
      expect(whole, greaterThanOrEqualTo(100 - 1e-9));
      expect(healed(b, k), closeTo(whole * bloodOathK.healIn, 1e-6), reason: 'in a wave: halved');
      // Between waves (no monster) a heal lands whole.
      final (q, qk, _, _) = trio(Relic.bloodOath);
      expect(q.waveActive, isFalse);
      expect(healed(q, qk), closeTo(whole, 1e-6), reason: 'between waves: whole');
    });

    test('Oath of the Vanguard: a type that fights up close ×1.4 HP and attack; a shooter and a healer ×0.75 attack or heal, '
        'their HP as it was', () {
      final (g, _, _, _) = trio(null);
      final (v, _, _, _) = trio(Relic.vanguardOath);
      expect((troopTypes['knight']!.melee, troopTypes['archer']!.melee, troopTypes['priest']!.melee), (true, false, false));
      expect(v.statsOf('knight').hp, (g.statsOf('knight').hp * vanguardOathK.melee).round());
      expect(v.statsOf('knight').dmg, closeTo(g.statsOf('knight').dmg * vanguardOathK.melee, 1e-9));
      for (final type in ['archer', 'priest']) {
        expect(v.statsOf(type).hp, g.statsOf(type).hp, reason: type);
        expect(v.statsOf(type).dmg, closeTo(g.statsOf(type).dmg * vanguardOathK.back, 1e-9), reason: type);
      }
    });

    test("Oath of Kings: a living Hero's aura ×1.25 on the others (not 1.15); a Hero's own rolled stats ×2 (not ×3); the "
        'book says so', () {
      (Game, Unit, Unit) court(Relic? oath) {
        final g = plain(Random(2));
        final h = stand(placeNow(g, 'knight', 2, 3))
          ..hero = true
          ..heroStats = [HeroStat.hp];
        final o = stand(placeNow(g, 'knight', 2, 4));
        g.givePusaka(Relic.ironBanner, type: 'knight'); // refits the knights (Iron Banner moves no stat)
        if (oath != null) g.givePusaka(oath);
        return (g, h, o);
      }

      final (g, h, o) = court(null);
      final (kg, kh, ko) = court(Relic.kingsOath);
      final hp = g.statsOf('knight').hp;
      expect((g.auraNow, g.heroBoostNow, kg.auraNow, kg.heroBoostNow), (auraBoost, heroBoost, kingsOathK.aura, kingsOathK.heroBoost));
      expect((h.maxHp, kh.maxHp), ((hp * heroBoost).round(), (hp * kingsOathK.heroBoost).round()), reason: "the Hero's own HP");
      expect((o.maxHp, ko.maxHp), ((hp * auraBoost).round(), (hp * kingsOathK.aura).round()), reason: "the Hero's aura");
      expect((kg.fieldStats('knight').hp, kg.auraLine, kg.itemAuraLine), ((hp * kingsOathK.aura).round(), 'Hero aura x1.25', 'With Hero aura: +25%'));
      expect((g.auraLine, g.itemAuraLine), ('Hero aura x1.15', 'With Hero aura: +15%'));
    });

    test('Oath of Spells: normal attacks (a blow, a shot) ×0.8; skill cooldowns ×0.8 through skillCd, never under cdFloor '
        'nor over the skill\'s own, once a wave stays once a wave', () {
      for (final type in ['knight', 'archer']) {
        // What its normal attack takes off a big orc, and what it would take at k of its attack.
        (double, double) hit(Relic? oath, double k) {
          final g = plain(Random(2));
          final u = placeNow(g, type, 2, 3)..cd = hold;
          if (oath != null) g.givePusaka(oath);
          final o = bigFoe(g, u.pos + Point(type == 'archer' ? 60 : 12, 0));
          return (blow(g, u, o), hitTaken(u.stats.dmg * k, o.stats.def));
        }

        final (bare, whole) = hit(null, 1);
        final (cut, eight) = hit(Relic.spellOath, spellOathK.blow);
        expect(bare, closeTo(whole, 1e-6), reason: type);
        expect(cut, closeTo(eight, 1e-6), reason: type);
        expect(cut, lessThan(bare), reason: type);
      }
      final g = plain(), s = plain()..givePusaka(Relic.spellOath);
      expect([for (final b in [10.0, 25.0, 6.0, 4.0, double.infinity]) g.skillCd(b)], [10.0, 25.0, 6.0, 4.0, double.infinity]);
      expect([for (final b in [10.0, 25.0, 6.0, 4.0, double.infinity]) s.skillCd(b)], [8.0, 20.0, cdFloor, 4.0, double.infinity]);
      // The awakening skill's tooltip shows the cooldown the troops wait (the knight's Unbroken, 22 s × awakenCdK at
      // Bangkit 1).
      String cdLine(Game h) => h.awakenInfo('knight').$2.map((l) => l.$2).firstWhere((l) => l.contains('cooldown'));
      expect(cdLine(g), contains('cooldown 11s'));
      expect(cdLine(s), contains('cooldown 8.8s'));
    });
  });

  group('the two engine pieces (M)', () {
    test("Oath of the Few: ×1.35 while 24 or fewer troops live; with more it waits (×1, the words say why) until the army is "
        'back within it', () {
      final g = plain(Random(2));
      final army = fill(g, 25);
      final base = g.statsOf('soldier');
      g.givePusaka(Relic.fewOath);
      expect((g.oath, g.armySize, g.oathWaits), (Relic.fewOath, 25, true));
      expect((g.statsOf('soldier').hp, g.pusakaWhere(Relic.fewOath), g.pusakaTotals(Relic.fewOath).isEmpty), (base.hp, fewWaiting, true));
      expect(g.oathOneWorks, isFalse, reason: 'Oath of One alone lifts the type caps');
      army.last.dying = 0; // one falls: 24 alive
      g.tick(0.05);
      expect((g.armySize, g.oathWaits), (24, false));
      expect(g.statsOf('soldier').hp, (base.hp * fewOathK.k).round());
      expect(g.statsOf('soldier').dmg, closeTo(base.dmg * fewOathK.k, 1e-9));
      expect(army.first.maxHp, (base.hp * fewOathK.k).round(), reason: 'refit at the next tick');
      expect(g.pusakaWhere(Relic.fewOath), 'On: all troops ★1');
      expect(g.pusakaTotals(Relic.fewOath), ['Now: all troops, +35%']);
    });

    test("Oath of the Few with the board's army cap: no 25th troop joins (the words say why), the cap and the Shadows' "
        'factor stay 32, and Auto waits only under 75% of 24; without the cap it bars nothing', () {
      final g = plain(Random(2))..armyMax = armyMaxBoard;
      fill(g, 24);
      expect((g.armyLocked, g.full), (false, false), reason: 'no oath yet');
      g.givePusaka(Relic.fewOath);
      expect((g.armyLocked, g.full, g.armyCap, g.overBy), (true, true, armyMaxBoard, 0));
      expect(g.buyRefusal('knight'), fewOathBar);
      expect(g.place('knight', 3, 0), isFalse);
      expect(g.armySize, 24);
      expect(g.autoHeld, isFalse);
      for (final u in g.troops.take(6).toList()) {
        u.dying = 0; // 18 alive: 75% of 24
      }
      g.tick(0.05);
      expect((g.armySize, g.autoHeld, g.armyLocked, g.buyRefusal('knight')), (18, false, false, null));
      g.troops.where((u) => u.alive).first.dying = 0; // one more falls
      g.tick(0.05);
      expect((g.armySize, g.autoHeld), (17, true));
      // Without the army cap it bars nothing; above 24 it only waits.
      final free = plain(Random(2));
      fill(free, 24);
      free.givePusaka(Relic.fewOath);
      expect((free.armyLocked, free.buyRefusal('knight')), (false, null));
      placeNow(free, 'knight', 3, 0);
      expect((free.armySize, free.oathWaits), (25, true));
    });

    test('Oath of Spells: the troop skill and the Hero skill come back 20% sooner (cdFloor aside)', () {
      // A #10 skill on two monsters next to its troop, its MP kept full: the knight's Circle Slash, the swordsman's
      // Rampage.
      double slashGap(Relic? oath, [String type = 'knight']) {
        final g = bareGame(Random(2))
          ..heroSkills = false
          ..awakenSkills = false
          ..monsterSkills = false;
        final k = placeNow(g, type, 2, 3)..cd = hold;
        if (oath != null) g.givePusaka(oath);
        g
          ..startWave()
          ..queue.clear();
        bigFoe(g, k.pos + const Point(12, 0));
        bigFoe(g, k.pos + const Point(0, 12));
        final casts = <double>[];
        for (var i = 0; i < 600 && casts.length < 2; i++) {
          k.mp = k.stats.mp.toDouble();
          final was = k.skillAt;
          g.tick(0.05);
          if (k.skillAt != was) casts.add(k.skillAt);
        }
        expect(casts, hasLength(2), reason: '${troopSkills[type]!.name} twice');
        return casts[1] - casts[0];
      }

      // Since decisions-log 298 the #10 skills come back in 4-6 s: × 0.8 is under cdFloor, so the oath leaves a 4 s one
      // as it is and brings a 6 s one to the floor.
      expect((troopSkills['knight']!.cooldown, troopSkills['swordsman']!.cooldown), (4, 6));
      expect(slashGap(null), closeTo(4, 0.06));
      expect(slashGap(Relic.spellOath), closeTo(4, 0.06));
      expect(slashGap(null, 'swordsman'), closeTo(6, 0.06));
      expect(slashGap(Relic.spellOath, 'swordsman'), closeTo(cdFloor, 0.06));
      // The knight Hero's Cleave (25 s × heroCdK) on a big monster in reach.
      double cleaveGap(Relic? oath) {
        final (g, h) = heroCaster(HeroSkill.cleave, Random(2));
        if (oath != null) g.givePusaka(oath);
        bigFoe(g, h.pos + const Point(12, 0));
        final casts = <double>[];
        for (var i = 0; i < 1200 && casts.length < 2; i++) {
          h.mp = h.stats.mp.toDouble();
          final was = h.heroSkillAt;
          g.tick(0.05);
          if (h.heroSkillAt != was) casts.add(h.heroSkillAt);
        }
        expect(casts, hasLength(2), reason: 'Cleave twice');
        return casts[1] - casts[0];
      }

      expect(HeroSkill.cleave.cooldown * heroCdK, 12.5);
      expect(cleaveGap(null), closeTo(12.5, 0.06));
      expect(cleaveGap(Relic.spellOath), closeTo(12.5 * spellOathK.cd, 0.06));
    });
  });

  group('the chest, one oath a run, every Legenda, the save', () {
    test('the chest deals each of the six from wave legendFrom (the Legenda pool is the design\'s thirty now); one taken works '
        'at once on the whole army and keeps every other oath off the cards', () {
      final legenda = liveLegenda;
      expect(legenda, hasLength(30));
      expect(legenda.skip(24).toList(), batch);
      final dealt = <Relic>{};
      for (var pick = 0; pick < legenda.length; pick++) {
        final g = chestGame(draft: _Dice(0.99, pick))..giveChests(1);
        expect(g.chest!.cards!.map((r) => r!.rarity), everyElement(Rarity.legenda));
        dealt.add(g.chest!.cards!.first!);
      }
      expect(dealt, legenda.toSet());
      final early = chestGame(wave: legendFrom - 1)..giveChests(1);
      expect(early.chest!.cards!.where(batch.contains), isEmpty, reason: 'before legendFrom');
      for (final r in batch) {
        final g = chestGame(wave: 30);
        final k = placeNow(g, 'knight', 2, 3);
        final hp = k.maxHp;
        g.chests.add(Chest(ChestKind.boss, 30, cards: [r]));
        expect(g.openChest(), [r], reason: '$r');
        expect(g.takeCard(0), isTrue);
        expect((g.oath, g.pusaka[r]!.stars, g.pusaka[r]!.type, g.legendsFound.contains(r)), (r, 1, null, true), reason: '$r');
        if (const {Relic.fewOath, Relic.wallOath, Relic.vanguardOath}.contains(r)) expect(k.maxHp, greaterThan(hp), reason: '$r: at once');
        // Every other oath is off the cards now; a chest rolled before shows a Shard in its place.
        g.chests.add(Chest(ChestKind.boss, 30, cards: [Relic.oathOfOne, Relic.spellOath, Relic.dragonCrown]));
        expect(g.openChest(), [null, null, Relic.dragonCrown], reason: '$r');
      }
    });

    test('every Legenda found (each but the oaths, and one oath): a Legenda roll steps down to an Epik; one missing comes; '
        'with no oath found, the eight oaths are what is left', () {
      final oaths = [for (final r in liveLegenda) if (r.oath) r], rest = [for (final r in liveLegenda) if (!r.oath) r];
      expect((oaths.length, rest.length), (8, 22));
      Game found(Iterable<Relic> those) => chestGame()..legendsFound.addAll(those);
      // Every one a run can find: the 22 and one oath.
      final all = found([...rest, Relic.kingsOath])..giveChests(1);
      expect(all.chest!.cards!.map((r) => r!.rarity), everyElement(Rarity.epik), reason: 'stepped down');
      // One missing: it comes, the other two cards step down.
      for (final missing in [Relic.dragonCrown, Relic.graveSeal, Relic.vowSilence]) {
        final one = found([...rest.where((r) => r != missing), Relic.spellOath])..giveChests(1);
        expect(one.chest!.cards!.first, missing, reason: '$missing');
        expect(one.chest!.cards!.skip(1).map((r) => r!.rarity), everyElement(Rarity.epik), reason: '$missing');
      }
      // No oath found yet: the three cards are oaths.
      final noOath = found(rest)..giveChests(1);
      expect(noOath.chest!.cards!.every((r) => r!.oath), isTrue);
      expect(noOath.chest!.cards, oaths.take(3).toList());
      // Found by the save's list, sold or not: the same.
      final back = reload(found([...rest, Relic.wallOath]));
      expect(back.legendsFound, {...rest, Relic.wallOath});
      back
        ..chests.clear() // a save without chests gets its catch-up ones: not this check's
        ..offers = true
        ..chestsGiven = 1
        ..draft = _Dice(0.99)
        ..giveChests(1);
      expect(back.chest!.cards!.map((r) => r!.rarity), everyElement(Rarity.epik));
    });

    test('the save keeps an oath (on no type, found) and it works on load; an old save without the key finds the oath it owns',
        () {
      for (final r in batch) {
        final (g, _, _, _) = trio(r);
        final back = reload(g);
        expect((back.oath, back.pusaka[r]!.type, back.pusaka[r]!.stars), (r, null, 1), reason: '$r');
        expect(back.legendsFound, {r}, reason: '$r');
        for (final type in ['knight', 'archer', 'priest']) {
          expect((back.statsOf(type).hp, back.statsOf(type).dmg), (g.statsOf(type).hp, g.statsOf(type).dmg), reason: '$r $type');
        }
        expect((back.skillCd(10), back.auraNow, back.heroBoostNow), (g.skillCd(10), g.auraNow, g.heroBoostNow), reason: '$r');
        expect(jsonEncode(back.toJson()), jsonEncode(g.toJson()), reason: '$r');
        final old = jsonDecode(jsonEncode(g.toJson())) as Map<String, dynamic>..remove('legendsFound');
        expect(Game.fromJson(old).legendsFound, {r}, reason: '$r');
      }
      final w89 = Game.fromJson(jsonDecode(File('test/fixtures/save-20261002-2222-w89-sellbug.json').readAsStringSync()) as Map<String, dynamic>);
      expect(w89.oath, Relic.alliance, reason: "the owner's save holds Alliance");
      expect(w89.pusaka.keys.where(batch.contains), isEmpty);
    });

    test("the Shadows' needs: an oath held meets Oathbane's; Spell Ward needs an MP skill, Hero Hunt a Hero", () {
      for (final r in batch) {
        final (g, _, _, _) = trio(r);
        expect(g.omenMet, contains(OmenNeed.oath), reason: '$r');
      }
      expect([OmenKind.oathbane.needs, OmenKind.spellWard.needs, OmenKind.heroHunt.needs], [
        {OmenNeed.oath},
        {OmenNeed.mpSkill},
        {OmenNeed.hero},
      ]);
      for (final k in const [OmenKind.dusk, OmenKind.riderRush, OmenKind.guard]) {
        expect(k.needs, isEmpty, reason: '$k always acts');
      }
    });
  });

  group('the Boss Chest card', () {
    /// Boots one TdGame in a [size] window, past the welcome screen, with the game's font.
    Future<Board> boot(WidgetTester tester, Size size) async {
      tester.view
        ..physicalSize = size
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await loadHudFont(tester);
      final game = TdGame();
      await tester.pumpWidget(GameWidget(game: game));
      for (var i = 0; i < 3000 && !game.isLoaded; i++) {
        await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 20)));
        await tester.pump();
      }
      expect(game.isLoaded, isTrue);
      return game.board
        ..welcome = null
        ..miniMapOpen = false;
    }

    Future<void> frames(WidgetTester tester, [int n = 2]) async {
      for (var i = 0; i < n; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
    }

    for (final size in const [Size(915, 412), Size(1266, 713)]) {
      testWidgets('each of the six fits ${size.width.round()}x${size.height.round()}: the gold Legenda cards and the buttons on '
          'the screen, apart', (tester) async {
        final b = await boot(tester, size);
        final g = b.state = Game(Random(1)).boardRules()
          ..armyMax = null
          ..gold = 200000
          ..wave = 86
          ..chestsGiven = 1;
        for (final type in ['soldier', 'archer', 'knight', 'priest']) {
          expect(g.autoPlace(type), isTrue);
        }
        final hands = [batch.sublist(0, 3), batch.sublist(3), [Relic.vanguardOath, Relic.kingsOath, Relic.dragonCrown]];
        g.chests.add(Chest(ChestKind.boss, 86, cards: hands.first));
        await frames(tester, 30);
        expect(b.chestOpen, isTrue);
        for (final hand in hands) {
          g.chests.first.cards = hand;
          await frames(tester, 3);
          final screen = Offset.zero & size, rects = [...b.chestCards, ...b.chestButtons.values];
          expect(b.chestCards, hasLength(3), reason: '$hand');
          for (final (i, r) in rects.indexed) {
            expect(screen.intersect(r), r, reason: '$hand: $r off the screen');
            for (final o in rects.skip(i + 1)) {
              final x = r.intersect(o);
              expect(x.width <= 0 || x.height <= 0, isTrue, reason: '$hand: $r over $o');
            }
          }
        }
        await frames(tester, 30);
      });
    }
  });
}
