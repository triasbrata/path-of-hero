// Batch E-3P (decisions-log 223; catalog-design §3.2 and §5.2, catalog-bayangan-v2 §4 and §5.2): the last eight new Epik
// Artifacts as catalog rows on the engine's Fx, the life ones: a healer's heal that gives MP, a might or a share to the
// troops next to the one healed (Mana Hymn, Brave Song, Halo Lantern), a skill that cleanses or heals the troops near
// (Saint's Tear, Bright Spring), every few hits a heal on the troops near (Heartbeat), a heal at a won wave's end
// (Hearth) and the heals a low troop gets landing bigger (Mercy Lily). Each one's effect at ★1, ★2 and ★3 and with Carve
// steps (the number [pusakaAt] gives), its words, its row (rarity, Carve role, the atlas's icon, epithet, counter,
// chest-only), the Shadows' needs it meets, the chest offering it, the save keeping an owned one, the Shop buying one
// back at its Epik price, the battle-log lines, and the cards on the Boss Chest at 915x412 and 1266x713. The rules every
// row keeps (band, key, icon, counter in its pool): pusaka_catalog_test.dart. docs/loot-items-relics.md "The Pusaka
// catalog and its engine".
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

/// The batch's eight, in [Relic] order (catalog-design §3.2's).
const batch = [
  Relic.manaHymn, Relic.saintTear, Relic.braveSong, Relic.haloLantern, Relic.hearth, Relic.heartbeat, Relic.mercyLily, //
  Relic.brightSpring,
];

/// The stars and Carve steps each effect is checked at: ★1-★3 bare, then two carved.
const _levels = [(1, 0), (2, 0), (3, 0), (1, 2), (3, 5)];

/// A game with no skills cast, so what happens is the Pusaka's doing.
Game plain([Random? rng]) => bareGame(rng)
  ..skills = false
  ..heroSkills = false
  ..awakenSkills = false
  ..monsterSkills = false;

/// What troop [u]'s next normal attack takes off [foe] (its cooldown over now; it waits again after).
double blow(Game g, Unit u, Unit foe) {
  final before = foe.hp;
  u.cd = 0;
  g.tick(0.05);
  u.cd = hold;
  return before - foe.hp;
}

/// Holds [u] where it stands: it neither walks nor attacks.
Unit stand(Unit u) => u
  ..busyUntil = hold
  ..cd = hold;

/// A troop heal [Game.onTroopHeal] heard: the troop, the source and the amount asked.
typedef Heard = ({Unit u, HealSrc src, double asked});

/// A priest at cell (0, 3) 40 px left of a knight at (2, 3) that stands at [hp] of its max HP, mid-wave (an orc far
/// off); [relic] bound to [holder] at [stars] and [ukir] Carve steps. Every troop heal is heard.
(Game, Unit, Unit, List<Heard>) healScene(Relic? relic, {String holder = 'priest', int stars = 1, int ukir = 0, double hp = 0.5}) {
  final g = plain(Random(2));
  final p = placeNow(g, 'priest', 0, 3);
  final k = stand(placeNow(g, 'knight', 2, 3));
  p.pos = k.pos + const Point(-40, 0);
  k.hp = k.maxHp * hp;
  if (relic != null) g.givePusaka(relic, type: holder, stars: stars, ukir: ukir);
  foeAt(g, 'orc', const Point(300, 60)); // mid-wave
  final heard = <Heard>[];
  g.onTroopHeal = (u, src, asked, _) => heard.add((u: u, src: src, asked: asked));
  return (g, p, k, heard);
}

/// Ticks [g] until the priest has healed [n] times (at most 10 s).
void untilHeals(Game g, List<Heard> heard, int n) {
  for (var i = 0; i < 200 && heard.where((h) => h.src == HealSrc.heal).length < n; i++) {
    g.tick(0.05);
  }
  expect(heard.where((h) => h.src == HealSrc.heal).length, greaterThanOrEqualTo(n), reason: 'the priest healed');
}

/// A soldier at cell (2, 3) holding [relic] on its type, in a wave, its MP full and its attack held, with two orcs
/// beside it (Hold Fast's crowd): its next tick casts Hold Fast. A knight a tile below it and an archer 2.5 tiles left of
/// it stand held, their MP empty (no cast of theirs).
(Game, Unit, Unit, Unit) castScene(Relic relic, {int stars = 1, int ukir = 0}) {
  final g = bareGame(Random(1))
    ..heroSkills = false
    ..monsterSkills = false;
  final u = placeNow(g, 'soldier', 2, 3);
  final mate = placeNow(g, 'knight', 2, 5), far = placeNow(g, 'archer', 0, 3);
  g
    ..givePusaka(relic, type: 'soldier', stars: stars, ukir: ukir)
    ..startWave()
    ..queue.clear();
  u
    ..cd = hold
    ..mp = u.stats.mp.toDouble();
  for (final (o, at) in [(mate, const Point(0.0, tile)), (far, const Point(-2.5 * tile, 0.0))]) {
    stand(o)
      ..pos = u.pos + at
      ..mp = 0;
  }
  for (final d in const <Point<double>>[Point(10, 0), Point(10, -8)]) {
    foeAt(g, 'orc', u.pos + d).hp = 1e4;
  }
  return (g, u, mate, far);
}

/// Draft dice that roll every rarity at [roll] and take the [pick]th card of a pool (wrapping).
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

void main() {
  tearDown(() => omensOn = omensDefault);

  group('the rows', () {
    test("eight Epik appended after batch E-2P's (save keys), chest-only (sold back at the Epik price), in the game; "
        "names, the life Carve role, epithets, the atlas's icons and catalog-bayangan-v2's counters, which now name them", () {
      expect(Relic.values.skipWhile((r) => r != Relic.anchor).skip(1).take(batch.length).toList(), batch,
          reason: "the last Artifacts (the Smithy's small relics come after them: relics_test.dart)");
      expect({for (final r in batch) r: relicNames[r]}, {
        Relic.manaHymn: 'Mana Hymn',
        Relic.saintTear: "Saint's Tear",
        Relic.braveSong: 'Brave Song',
        Relic.haloLantern: 'Halo Lantern',
        Relic.hearth: 'Hearth',
        Relic.heartbeat: 'Heartbeat',
        Relic.mercyLily: 'Mercy Lily',
        Relic.brightSpring: 'Bright Spring',
      });
      for (final r in batch) {
        final art = pusakaCatalog[r]!;
        expect((r.rarity, r.scope, r.store, art.live, r.oath, maxStars(r)), (Rarity.epik, RelicScope.type, false, true, false, starMax), reason: '$r');
        expect(art.icon.sheet, 'artifact_icons.png', reason: '$r');
        expect((art.icon.x, art.icon.y, art.icon.tint), (artifactIcon(r.name).x, artifactIcon(r.name).y, null), reason: '$r');
        expect(art.fx, hasLength(1), reason: '$r');
        expect((art.healerCounter, art.role), (null, UkirRole.life), reason: '$r');
      }
      (String, int, int, int?) cell(Art a) => (a.icon.sheet, a.icon.x, a.icon.y, a.icon.tint);
      final cells = [for (final a in pusakaCatalog.values) cell(a)];
      for (final r in batch) {
        expect(cells.where((c) => c == cell(pusakaCatalog[r]!)), hasLength(1), reason: '$r: its own icon');
      }
      expect((liveE3P, newEpikStore), (true, false));
      expect({for (final r in batch) r: buildEpithets[r]}, {
        Relic.manaHymn: 'Hymnal',
        Relic.saintTear: 'Saintly',
        Relic.braveSong: 'Brave',
        Relic.haloLantern: 'Haloed',
        Relic.hearth: 'Hearty',
        Relic.heartbeat: 'Pulsing',
        Relic.mercyLily: 'Merciful',
        Relic.brightSpring: 'Bright',
      });
      expect(buildEpithets.values.toSet().length, buildEpithets.length, reason: 'an epithet twice');
      expect({for (final r in batch) r: pusakaCatalog[r]!.counter}, {
        Relic.manaHymn: OmenKind.counterspell,
        Relic.saintTear: OmenKind.counterspell,
        Relic.braveSong: OmenKind.envy,
        Relic.haloLantern: OmenKind.healSiphon,
        Relic.hearth: OmenKind.prey,
        Relic.heartbeat: OmenKind.herdHunt,
        Relic.mercyLily: OmenKind.prey,
        Relic.brightSpring: OmenKind.healSiphon,
      });
      for (final r in batch) {
        final counter = pusakaCatalog[r]!.counter;
        expect(counter.answers, contains(r), reason: '$r');
        expect(omenPool(Rarity.epik), contains(counter), reason: '$r');
      }
      expect(OmenKind.counterspell.answers, [Relic.moonwell, Relic.aegisSeal, Relic.manaHymn, Relic.saintTear]);
      expect(OmenKind.healSiphon.answers, [Relic.dawnStar, Relic.haloLantern, Relic.brightSpring], reason: 'Dawn Star on a priest');
      expect(OmenKind.prey.answers, [Relic.grail, Relic.hearth, Relic.mercyLily]);
      expect(OmenKind.herdHunt.answers, [Relic.heartbeat]);
      expect(OmenKind.wearDown.answers, [Relic.dragonHeart, Relic.heroCloak], reason: "Dragon Heart's since the Epik cut-over");
      // The Shop never sells one; one in the Vault sells to it at its share of epikPrice.
      expect(storeGoods.where(batch.contains), isEmpty, reason: 'never in the Shop');
      for (final r in batch) {
        final g = Game()
          ..wave = storeFrom
          ..inTown = true; // the Shop buys only in a Town
        expect(g.basePrice(r), epikPrice, reason: '$r');
        g.givePusaka(r);
        final gold = g.gold;
        expect(g.whyNotSell(r), isNull, reason: '$r in the Vault');
        expect(g.sell(r), 1, reason: '$r');
        expect((g.gold - gold, g.pusaka.containsKey(r)), (epikPrice ~/ 2, false), reason: '$r');
        final bound = Game()
          ..wave = storeFrom
          ..inTown = true; // the Shop buys only in a Town
        bound.givePusaka(r, type: 'knight');
        expect(bound.whyNotSell(r), StoreRefusal.bound, reason: '$r: equipped');
      }
    });

    test('each leads with its own Fx (no other row shares its key); the band measures Brave Song as a might, Halo '
        "Lantern's share to its two and Mercy Lily's × as heal output (Mercy Lily's with its condition's bonus), "
        "Heartbeat's and Bright Spring's heal of max HP; Mana Hymn's MP, Saint's Tear's cleanse and Hearth's heal "
        'between waves are unmeasured (probe arms)', () {
      final keys = {for (final MapEntry(key: r, value: a) in pusakaCatalog.entries) if (a.fx.isNotEmpty) a.fx.first.key: r};
      for (final r in batch) {
        expect(keys[pusakaCatalog[r]!.fx.first.key], r, reason: '$r');
      }
      Fx fx(Relic r) => pusakaCatalog[r]!.fx.first;
      double band(Band b, int i) => fxBand[b]![Rarity.epik]![i];
      for (var s = 1; s <= starMax; s++) {
        final i = s - 1;
        for (final r in [Relic.manaHymn, Relic.saintTear, Relic.hearth]) {
          expect(fxGain(fx(r), pusakaAt(r, s), 1), isNull, reason: '$r: a probe arm instead');
        }
        expect(fxGain(fx(Relic.braveSong), pusakaAt(Relic.braveSong, s), 1), (Band.power, braveSongK.might[i] - 1));
        final halo = fxGain(fx(Relic.haloLantern), pusakaAt(Relic.haloLantern, s), pusakaCountAt(Relic.haloLantern, s))!;
        expect(halo, (Band.healOutput, haloLanternK.share[i] * haloLanternK.most));
        expect(halo.$2, lessThanOrEqualTo(band(Band.healOutput, i)));
        final lily = fxGain(fx(Relic.mercyLily), pusakaAt(Relic.mercyLily, s), 1)!;
        expect(lily, (Band.healOutput, mercyLilyK.heal[i] - 1));
        expect(lily.$2, lessThanOrEqualTo(band(Band.healOutput, i) * condBonus), reason: 'under 40% HP: a condition');
        for (final (r, table) in [(Relic.heartbeat, heartbeatK.heal), (Relic.brightSpring, brightSpringK.heal)]) {
          expect(fxGain(fx(r), pusakaAt(r, s), 1), (Band.healMaxHp, table[i]), reason: '$r');
          expect(table[i], lessThanOrEqualTo(band(Band.healMaxHp, i)), reason: '$r');
        }
        expect(braveSongK.might[i] - 1, lessThanOrEqualTo(band(Band.power, i)));
        expect(pusakaCountAt(Relic.haloLantern, s), haloLanternK.most);
      }
      expect(fxBand[Band.healMaxHp]![Rarity.epik], fxBand[Band.healMaxHp]![Rarity.langka], reason: "no bigger than Mourning Bell's");
      expect({for (final r in batch) r: (fx(r).every, fx(r).cooled)}, {
        Relic.manaHymn: (0, false),
        Relic.saintTear: (0, true),
        Relic.braveSong: (0, false),
        Relic.haloLantern: (0, false),
        Relic.hearth: (0, false),
        Relic.heartbeat: (heartbeatK.every, false),
        Relic.mercyLily: (0, false),
        Relic.brightSpring: (0, false),
      });
      expect(fx(Relic.saintTear).cdByStars, isTrue, reason: "a cleanse's k is its cooldown");
      expect(fx(Relic.saintTear).k, saintTearK.cd);
      expect(fx(Relic.saintTear).r, saintTearK.reach);
      expect((fx(Relic.mercyLily).when, fx(Relic.mercyLily).ifK, fx(Relic.mercyLily).to), (If.hpBelow, mercyLilyK.below, To.self));
      expect((fx(Relic.haloLantern).r, fx(Relic.heartbeat).r, fx(Relic.brightSpring).r), (haloLanternK.reach, heartbeatK.reach, brightSpringK.reach));
      expect(fx(Relic.braveSong).time, braveSongK.time);
      for (final r in batch) {
        expect(fxBuilt(fx(r)), isTrue, reason: '$r: the engine runs it');
      }
    });

    test("their words at ★1, from the constants: the card and tooltip lines, the Bag row's gist and the Bag detail's first "
        'sentence; ★2, ★3 and Carve move the numbers', () {
      final g = Game();
      expect({for (final r in batch) r: g.relicEffect(r, stars: 1)}, {
        Relic.manaHymn: ['Its heals also give 3% max MP'],
        Relic.saintTear: ['After it uses a skill: it and troops', 'within 2 tiles lose their bad effects', 'Every 6s at most'],
        Relic.braveSong: ['Troops it heals: +10% damage', 'for 3s'],
        Relic.haloLantern: ['Its heals also heal 2 troops', 'next to that one, 15% as much'],
        Relic.hearth: ['At wave end: heals it', 'up to 40% of its max HP'],
        Relic.heartbeat: ['Every 4th hit: troops within', '1.5 tiles heal 3% max HP'],
        Relic.mercyLily: ['Under 40% HP: +35% heal on it'],
        Relic.brightSpring: ['After it uses a skill: it and troops', 'within 1.5 tiles heal 6% max HP'],
      });
      expect({for (final r in batch) r: pusakaGist(r, 1)}, {
        Relic.manaHymn: 'Heal: +3% MP',
        Relic.saintTear: 'Skill: clears near, every 6s',
        Relic.braveSong: 'Heal: +10% damage',
        Relic.haloLantern: 'Heal: 15% to 2 near',
        Relic.hearth: 'Wave end: up to 40% HP',
        Relic.heartbeat: 'Every 4th: near heal 3%',
        Relic.mercyLily: 'Under 40%: +35% heal',
        Relic.brightSpring: 'Skill: near heal 6%',
      });
      expect({for (final r in batch) r: firstSentence(g.relicEffect(r, stars: 1))}, {
        Relic.manaHymn: 'Its heals also give 3% max MP',
        Relic.saintTear: 'After it uses a skill: it and troops within 2 tiles lose their bad effects',
        Relic.braveSong: 'Troops it heals: +10% damage for 3s',
        Relic.haloLantern: 'Its heals also heal 2 troops next to that one, 15% as much',
        Relic.hearth: 'At wave end: heals it up to 40% of its max HP',
        Relic.heartbeat: 'Every 4th hit: troops within 1.5 tiles heal 3% max HP',
        Relic.mercyLily: 'Under 40% HP: +35% heal on it',
        Relic.brightSpring: 'After it uses a skill: it and troops within 1.5 tiles heal 6% max HP',
      });
      expect(g.relicEffect(Relic.manaHymn, stars: 3), ['Its heals also give 5% max MP']);
      expect(g.relicEffect(Relic.saintTear, stars: 3).last, 'Every 4s at most');
      expect(g.relicEffect(Relic.braveSong, stars: 2).first, 'Troops it heals: +15% damage');
      expect(g.relicEffect(Relic.haloLantern, stars: 3).last, 'next to that one, 25% as much');
      expect(g.relicEffect(Relic.hearth, stars: 3).last, 'up to 80% of its max HP');
      expect(g.relicEffect(Relic.heartbeat, stars: 2).last, '1.5 tiles heal 4% max HP');
      expect(g.relicEffect(Relic.mercyLily, stars: 3), ['Under 40% HP: +70% heal on it']);
      expect(g.relicEffect(Relic.brightSpring, stars: 3).last, 'within 1.5 tiles heal 12% max HP');
      expect(fxLines(Relic.saintTear, 3, ukir: 5).last, 'Every 3.2s at most', reason: 'its cooldown shorter past ★3');
      expect(fxLines(Relic.mercyLily, 3, ukir: 5), ['Under 40% HP: +86% heal on it'], reason: 'past ★3 by the last gap');
      expect(fxLines(Relic.hearth, 3, ukir: 5).last, 'up to 96% of its max HP');
      for (final r in batch) {
        for (final (s, u) in _levels) {
          for (final line in [...fxLines(r, s, ukir: u), fxGist(r, s, ukir: u)]) {
            expect(line.codeUnits.every((c) => c < 128), isTrue, reason: '$r: $line');
          }
        }
      }
    });
  });

  group('the effects at ★1, ★2, ★3 and carved', () {
    for (final (stars, ukir) in _levels) {
      final at = '★$stars${ukir > 0 ? ' +$ukir' : ''}';

      test('$at: the table, or past it by the Carve steps', () {
        final i = stars - 1;
        for (final (r, table) in [
          (Relic.manaHymn, manaHymnK),
          (Relic.saintTear, saintTearK.cd),
          (Relic.braveSong, braveSongK.might),
          (Relic.haloLantern, haloLanternK.share),
          (Relic.hearth, hearthK),
          (Relic.heartbeat, heartbeatK.heal),
          (Relic.mercyLily, mercyLilyK.heal),
          (Relic.brightSpring, brightSpringK.heal),
        ]) {
          final k = pusakaAt(r, stars, ukir: ukir);
          if (ukir == 0) {
            expect(k, table[i], reason: '$r $at');
          } else {
            expect((k - table[i]).abs(), greaterThan(0), reason: '$r $at: Carve moves it');
            expect((k - table[i]).sign, (table[2] - table[0]).sign, reason: '$r $at: the way the stars go');
          }
        }
      });

      test("$at Mana Hymn: a priest's heal gives the troop healed k of its max MP while it lacks some; one full of MP gets "
          'none', () {
        final k = pusakaAt(Relic.manaHymn, stars, ukir: ukir);
        final (g, p, kn, heard) = healScene(Relic.manaHymn, stars: stars, ukir: ukir);
        kn.mp = 0;
        untilHeals(g, heard, 1);
        final most = kn.stats.mp.toDouble();
        expect(kn.mp, greaterThanOrEqualTo(most * k - 1e-9));
        expect(g.pusakaWorth[Relic.manaHymn]!.uses, 1);
        expect(g.pusakaWorth[Relic.manaHymn]!.worth, closeTo(most * k, 1e-9));
        kn.mp = most;
        untilHeals(g, heard, 2);
        expect((kn.mp, g.pusakaWorth[Relic.manaHymn]!.uses), (most, 1), reason: 'full: none');
        expect(p.mp, lessThanOrEqualTo(p.stats.mp), reason: 'the priest itself: never past its max');
      });

      test("$at Saint's Tear: its type's skill ends every bad effect a monster put on it and the troops within 2 tiles "
          '(a good effect stays; farther, none); its cooldown starts only when one had one', () {
        final cd = pusakaAt(Relic.saintTear, stars, ukir: ukir);
        final (g, u, mate, far) = castScene(Relic.saintTear, stars: stars, ukir: ukir);
        final orc = g.enemies.first;
        g
          ..addEffect(u, Status.slow, 30, k: 0.5, by: orc, bad: true)
          ..addEffect(mate, Status.weaken, 30, k: 0.8, by: orc, bad: true)
          ..addEffect(mate, Status.daze, 30, k: 1.25, by: orc, bad: true)
          ..addEffect(mate, Status.might, 30, k: 1.2)
          ..addEffect(far, Status.slow, 30, k: 0.5, by: orc, bad: true);
        g.tick(0.05);
        expect(g.log.entries.whereType<SkillCast>(), hasLength(1), reason: 'Hold Fast cast');
        expect([g.badOn(u), g.badOn(mate), g.badOn(far)], [0, 0, 1]);
        expect(g.effectOn(mate, Status.might)?.k, 1.2, reason: 'a good effect stays');
        expect(g.pusakaWorth[Relic.saintTear]!.uses, 3);
        expect(u.fxReady, closeTo(g.t + cd, 0.051));
        // Nothing bad on any: no cleanse, no cooldown.
        final (h, v, _, _) = castScene(Relic.saintTear, stars: stars, ukir: ukir);
        h.tick(0.05);
        expect(h.log.entries.whereType<SkillCast>(), hasLength(1));
        expect((h.pusakaWorth[Relic.saintTear], v.fxReady), (null, double.negativeInfinity));
      });

      test("$at Brave Song: a priest's heal gives the troop healed a might of k for 3s, from the priest; a stronger might "
          'stays', () {
        final k = pusakaAt(Relic.braveSong, stars, ukir: ukir);
        final (g, p, kn, heard) = healScene(Relic.braveSong, stars: stars, ukir: ukir);
        untilHeals(g, heard, 1);
        final m = g.effectOn(kn, Status.might)!;
        expect((m.k, m.by, m.bad), (k, p, false));
        expect(m.until, closeTo(g.t + braveSongK.time, 0.051));
        expect(g.pusakaWorth[Relic.braveSong]!.uses, 1);
        final (h, _, strong, strongHeard) = healScene(Relic.braveSong, stars: stars, ukir: ukir);
        h.addEffect(strong, Status.might, 30, k: 2.0);
        untilHeals(h, strongHeard, 1);
        expect(h.effectOn(strong, Status.might)!.k, 2.0, reason: 'the stronger stays');
        expect(h.pusakaWorth[Relic.braveSong], isNull);
      });

      test("$at Halo Lantern: a priest's heal also heals the two troops nearest the one healed within a tile that lack HP, "
          'k of the heal each, through the heal funnel; the third, a full one and a far one get none; no chain', () {
        final k = pusakaAt(Relic.haloLantern, stars, ukir: ukir);
        final g = plain(Random(2));
        final p = placeNow(g, 'priest', 0, 3);
        final kn = stand(placeNow(g, 'knight', 2, 3));
        final near1 = stand(placeNow(g, 'soldier', 3, 3)), near2 = stand(placeNow(g, 'swordsman', 3, 5));
        final third = stand(placeNow(g, 'lancer', 1, 5)), full = stand(placeNow(g, 'archer', 1, 1));
        final far = stand(placeNow(g, 'armored_axeman', 3, 1));
        g.givePusaka(Relic.haloLantern, type: 'priest', stars: stars, ukir: ukir);
        p.pos = kn.pos + const Point(-40, 0);
        for (final (o, d) in [
          (full, const Point(0.0, -12.0)),
          (near1, const Point(12.0, 0.0)),
          (near2, const Point(0.0, 13.0)),
          (third, const Point(-15.5, 0.0)),
          (far, const Point(0.0, 2 * tile)),
        ]) {
          o.pos = kn.pos + d;
        }
        kn.hp = kn.maxHp * 0.3;
        for (final o in [near1, near2, third, far]) {
          o.hp = o.maxHp * 0.8;
        }
        foeAt(g, 'orc', const Point(300, 60)); // mid-wave
        final heard = <Heard>[];
        g.onTroopHeal = (u, src, asked, _) => heard.add((u: u, src: src, asked: asked));
        untilHeals(g, heard, 1);
        final first = heard.firstWhere((h) => h.src == HealSrc.heal);
        expect(first.u, kn, reason: 'the priest heals the worst');
        final halo = [for (final h in heard) if (h.src == HealSrc.pusaka) h];
        expect([for (final h in halo) h.u], unorderedEquals([near1, near2]));
        for (final h in halo) {
          expect(h.asked, closeTo(p.stats.dmg * k, 1e-9), reason: h.u.type);
        }
        expect(g.pusakaWorth[Relic.haloLantern]!.uses, 1);
        expect(g.pusakaWorth[Relic.haloLantern]!.worth, closeTo(2 * p.stats.dmg * k, 1e-9));
        expect(heard.where((h) => h.src == HealSrc.heal), hasLength(1), reason: 'no chain: its heals set off no `heals` Fx');
      });

      test('$at Hearth: at a won wave\'s end each living troop of its type under k of its max HP heals up to it (never past '
          "full), a heal between waves; one over it, and the wave's middle, none", () {
        final k = pusakaAt(Relic.hearth, stars, ukir: ukir);
        final g = plain(Random(2));
        final a = stand(placeNow(g, 'knight', 2, 3)), b = stand(placeNow(g, 'knight', 2, 5));
        final s = stand(placeNow(g, 'soldier', 1, 3));
        g
          ..givePusaka(Relic.hearth, type: 'knight', stars: stars, ukir: ukir)
          ..startWave()
          ..queue.clear();
        a.hp = a.maxHp * 0.1;
        s.hp = s.maxHp * 0.1;
        final kinds = <HealKind>[];
        g.onTroopHeal = (u, src, _, _) {
          if (src == HealSrc.pusaka) kinds.add(g.healKind(src));
        };
        final slime = g.monster('slime', Tier.normal, const Point(300, 60));
        g
          ..units.add(slime)
          ..tick(0.05);
        expect(a.hp, closeTo(a.maxHp * 0.1, 1e-9), reason: 'mid-wave: none');
        slime.gone = true;
        g.tick(0.05);
        expect(g.waveActive, isFalse, reason: 'won');
        expect(a.hp, closeTo(a.maxHp * min(1.0, k), 1e-9));
        expect((b.hp, s.hp), (b.maxHp.toDouble(), s.maxHp * 0.1), reason: 'full; another type');
        expect(kinds, [HealKind.between]);
        expect(g.pusakaWorth[Relic.hearth]!.uses, 1);
        expect(g.pusakaWorth[Relic.hearth]!.worth, closeTo(a.maxHp * (min(1.0, k) - 0.1), 1e-9));
      });

      test('$at Heartbeat: every 4th normal attack heals each troop within 1.5 tiles of it (itself too) that lacks HP k of '
          'its max HP; a full one and a far one none', () {
        final k = pusakaAt(Relic.heartbeat, stars, ukir: ukir);
        final g = plain(Random(2));
        final u = placeNow(g, 'knight', 2, 3)..cd = hold;
        final mate = stand(placeNow(g, 'soldier', 2, 5)), full = stand(placeNow(g, 'archer', 1, 5));
        final far = stand(placeNow(g, 'swordsman', 0, 1));
        g.givePusaka(Relic.heartbeat, type: 'knight', stars: stars, ukir: ukir);
        mate.pos = u.pos + const Point(0, tile);
        full.pos = u.pos + const Point(-tile, 0);
        far.pos = u.pos + const Point(-2 * tile, tile);
        u
          ..maxHp = 100000
          ..hp = 50000;
        mate.hp = mate.maxHp * 0.5;
        far.hp = far.maxHp * 0.5;
        final orc = foeAt(g, 'orc', u.pos + const Point(12, 0))
          ..maxHp = 1000000
          ..hp = 1e6;
        final heard = <Heard>[];
        g.onTroopHeal = (o, src, asked, _) {
          if (src == HealSrc.pusaka) heard.add((u: o, src: src, asked: asked));
        };
        for (var n = 1; n < heartbeatK.every; n++) {
          blow(g, u, orc);
          expect(heard, isEmpty, reason: 'blow $n');
        }
        blow(g, u, orc);
        expect({for (final h in heard) h.u: h.asked}, {u: closeTo(100000 * k, 1e-6), mate: closeTo(mate.maxHp * k, 1e-9)});
        expect(g.pusakaWorth[Relic.heartbeat]!.uses, 1);
        expect(g.pusakaWorth[Relic.heartbeat]!.worth, closeTo(100000 * k + mate.maxHp * k, 1e-6));
        expect(g.impacts.where((i) => i.$2 == 'heal'), hasLength(2), reason: "the heal's sparkle on each");
      });

      test("$at Mercy Lily: a heal on a troop of its type under 40% HP lands ×k, before Wound's cut (its counter: what the "
          '× added); over 40%, the heal as it was; the listener hears the heal asked', () {
        final k = pusakaAt(Relic.mercyLily, stars, ukir: ukir);
        final (g, p, kn, heard) = healScene(Relic.mercyLily, holder: 'knight', stars: stars, ukir: ukir, hp: 0.3);
        final heal = p.stats.dmg.toDouble(), before = kn.hp;
        untilHeals(g, heard, 1);
        expect(kn.hp - before, closeTo(heal * k, 1e-9));
        expect(heard.single.asked, heal, reason: 'the heal asked');
        expect(g.pusakaWorth[Relic.mercyLily]!.uses, 1);
        expect(g.pusakaWorth[Relic.mercyLily]!.worth, closeTo(heal * (k - 1), 1e-9));
        // Over 40%: as it was.
        final (h, _, high, highHeard) = healScene(Relic.mercyLily, holder: 'knight', stars: stars, ukir: ukir, hp: 0.5);
        final from = high.hp;
        untilHeals(h, highHeard, 1);
        expect((high.hp - from, h.pusakaWorth[Relic.mercyLily]), (heal, null));
        // Wound's cut after it: ×k, then ×0.5.
        final (w, _, cut, cutHeard) = healScene(Relic.mercyLily, holder: 'knight', stars: stars, ukir: ukir, hp: 0.3);
        w.woundForce = 0.5;
        final low = cut.hp;
        untilHeals(w, cutHeard, 1);
        expect(cut.hp - low, closeTo(heal * k * 0.5, 1e-9));
        expect(w.pusakaWorth[Relic.mercyLily]!.worth, closeTo(heal * k * 0.5 * (1 - 1 / k), 1e-9));
        // On the priest's type it is the priest's own heals got, not the ones it gives.
        final (q, _, other, otherHeard) = healScene(Relic.mercyLily, stars: stars, ukir: ukir, hp: 0.3);
        final was = other.hp;
        untilHeals(q, otherHeard, 1);
        expect((other.hp - was, q.pusakaWorth[Relic.mercyLily]), (heal, null));
      });

      test("$at Bright Spring: its type's skill heals it and every troop within 1.5 tiles that lacks HP k of each one's max "
          'HP; farther, none', () {
        final k = pusakaAt(Relic.brightSpring, stars, ukir: ukir);
        final (g, u, mate, far) = castScene(Relic.brightSpring, stars: stars, ukir: ukir);
        for (final o in [u, mate, far]) {
          o.hp = o.maxHp * 0.5;
        }
        final heard = <Heard>[];
        g.onTroopHeal = (o, src, asked, _) {
          if (src == HealSrc.pusaka) heard.add((u: o, src: src, asked: asked));
        };
        g.tick(0.05);
        expect(g.log.entries.whereType<SkillCast>(), hasLength(1), reason: 'Hold Fast cast');
        expect({for (final h in heard) h.u: h.asked}, {u: closeTo(u.maxHp * k, 1e-9), mate: closeTo(mate.maxHp * k, 1e-9)});
        expect(g.pusakaWorth[Relic.brightSpring]!.uses, 1);
        expect(g.pusakaWorth[Relic.brightSpring]!.worth, closeTo((u.maxHp + mate.maxHp) * k, 1e-9));
      });
    }
  });

  group('the Shadows that answer them', () {
    setUp(() => omensOn = true);

    test("Wound at its most never cuts Hearth's heal, one between waves", () {
      final g = plain(Random(2));
      final a = stand(placeNow(g, 'knight', 2, 3));
      g
        ..givePusaka(Relic.hearth, type: 'knight')
        ..omens.addAll(List.filled(omenCap, OmenKind.wound))
        ..startWave()
        ..queue.clear()
        ..omenFactor = 2;
      expect(g.omenK(OmenKind.wound), greaterThan(0));
      a.hp = a.maxHp * 0.1;
      g
        ..units.add(g.monster('slime', Tier.normal, const Point(300, 60))..gone = true)
        ..tick(0.05);
      expect(g.waveActive, isFalse);
      expect(a.hp, closeTo(a.maxHp * hearthK[0], 1e-9));
    });
  });

  group('the chest, the save, the Shadows\' needs, the log', () {
    test('the chest deals each of the eight (the Epik pool is thirty now; the run\'s first chest, three Epik, may show '
        'them), binds it by its default rule, and keeps a ★3 one off its cards', () {
      final epik = [for (final r in Relic.values) if (r.pusaka && r.rarity == Rarity.epik && pusakaCatalog[r]!.live) r];
      expect(epik, hasLength(30));
      expect(epik.skip(22), batch);
      final epicRoll = chestOddsAt(30).rare + chestOddsAt(30).epic / 2;
      final dealt = <Relic>{};
      for (var pick = 0; pick < epik.length; pick++) {
        final g = plain(Random(1))
          ..offers = true
          ..wave = 30
          ..chestsGiven = 1
          ..draft = _Dice(epicRoll, pick)
          ..giveChests(1);
        expect(g.chest!.cards!.map((r) => r!.rarity), everyElement(Rarity.epik));
        dealt.add(g.chest!.cards!.first!);
      }
      expect(dealt, epik.toSet());
      final first = <Relic>{};
      for (var pick = 0; pick < epik.length; pick++) {
        final g = plain(Random(1))
          ..offers = true
          ..wave = 5
          ..draft = _Dice(0, pick)
          ..giveChests(1);
        expect(g.chest!.epik, isTrue);
        first.addAll(g.chest!.cards!.cast<Relic>());
      }
      expect(first, containsAll(batch), reason: "the run's first chest");
      const army = ['knight', 'archer', 'wizard', 'priest'];
      for (final r in batch) {
        final g = plain(Random(1))
          ..offers = true
          ..wave = 30;
        for (final (i, type) in army.indexed) {
          placeNow(g, type, 2 * (i % 2), 1 + 4 * (i ~/ 2));
        }
        g.chests.add(Chest(ChestKind.boss, 30, cards: [r]));
        expect(g.openChest(), [r], reason: '$r');
        expect(g.takeCard(0), isTrue);
        final type = pusakaPrefs[r]!.firstWhere(army.contains);
        expect((g.pusaka[r]!.stars, g.pusaka[r]!.type), (1, type), reason: '$r');
        g.givePusaka(r, type: type, stars: starMax);
        g.chests.add(Chest(ChestKind.boss, 30, cards: [r]));
        expect(g.openChest(), [null], reason: '$r ★3: a Shard');
      }
      for (final r in [Relic.manaHymn, Relic.braveSong, Relic.haloLantern]) {
        expect(pusakaPrefs[r], ['priest'], reason: '$r: a healer\'s heals');
      }
      expect(pusakaPrefs[Relic.mercyLily]!.contains('priest'), isFalse, reason: 'the heals a troop gets');
    });

    test("the save keeps an owned one (its type, stars and Carve steps); a might is a wave's only; the owner's save holds "
        'none', () {
      final g = plain(Random(1));
      placeNow(g, 'priest', 0, 3);
      placeNow(g, 'knight', 2, 3);
      g
        ..givePusaka(Relic.manaHymn, type: 'priest', stars: 2, ukir: 3)
        ..givePusaka(Relic.hearth, type: 'knight', stars: 3, ukir: 1)
        ..givePusaka(Relic.mercyLily, stars: 1);
      final back = Game.fromJson(jsonDecode(jsonEncode(g.toJson())) as Map<String, dynamic>);
      final p = back.pusaka;
      expect((p[Relic.manaHymn]!.type, p[Relic.manaHymn]!.stars, p[Relic.manaHymn]!.ukir), ('priest', 2, 3));
      expect((p[Relic.hearth]!.type, p[Relic.hearth]!.stars, p[Relic.hearth]!.ukir), ('knight', 3, 1));
      expect(p[Relic.mercyLily]!.type, isNull);
      expect(back.gudang, contains(Relic.mercyLily));
      final w89 = Game.fromJson(jsonDecode(File('test/fixtures/save-20261002-2222-w89-sellbug.json').readAsStringSync()) as Map<String, dynamic>);
      expect(w89.pusaka.keys.where(batch.contains), isEmpty, reason: "the owner's save holds none");
    });

    test("the Shadows' needs they meet: a heal (Halo Lantern, Hearth, Heartbeat, Bright Spring; not Mercy Lily, which "
        "only raises the heals a troop gets), a cooldown (Saint's Tear), every few hits (Heartbeat), a might (Brave Song)", () {
      Game army() {
        final g = plain(Random(1));
        placeNow(g, 'knight', 2, 3);
        placeNow(g, 'archer', 0, 3);
        return g;
      }

      Set<OmenNeed> met(Relic r) => (army()..givePusaka(r, type: 'knight')).omenMet;
      final none = army().omenMet;
      expect(none.contains(OmenNeed.heal), isFalse, reason: 'no healer, no regen');
      expect({for (final r in batch) r: met(r).difference(none)}, {
        Relic.manaHymn: <OmenNeed>{},
        Relic.saintTear: {OmenNeed.cdFx},
        Relic.braveSong: {OmenNeed.mightOrHaste},
        Relic.haloLantern: {OmenNeed.heal},
        Relic.hearth: {OmenNeed.heal},
        Relic.heartbeat: {OmenNeed.everyFx, OmenNeed.heal},
        Relic.mercyLily: <OmenNeed>{},
        Relic.brightSpring: {OmenNeed.heal},
      });
    });

    test("the battle log's report lines and the counter families", () {
      String line(Relic r, String type, int uses, double worth) => pusakaReportLines(PusakaReport(1, 0, lines: [
            (relic: r, type: type, stars: 1, uses: uses, worth: worth),
          ])).single;
      expect(line(Relic.manaHymn, 'priest', 6, 40), 'Mana Hymn (Priest): +40 MP');
      expect(line(Relic.saintTear, 'knight', 3, 0), "Saint's Tear (Knight): cleared 3 bad effects");
      expect(line(Relic.saintTear, 'knight', 1, 0), "Saint's Tear (Knight): cleared 1 bad effect");
      expect(line(Relic.braveSong, 'priest', 9, 0), 'Brave Song (Priest): powered up 9 times');
      expect(line(Relic.haloLantern, 'priest', 4, 1200), 'Halo Lantern (Priest): +1.2k HP to troops near');
      expect(line(Relic.hearth, 'knight', 2, 900), 'Hearth (Knight): +900 HP at wave end');
      expect(line(Relic.heartbeat, 'soldier', 8, 640), 'Heartbeat (Soldier): +640 HP from hits');
      expect(line(Relic.mercyLily, 'knight', 5, 300), 'Mercy Lily (Knight): +300 HP more healed');
      expect(line(Relic.brightSpring, 'knight', 3, 1500), 'Bright Spring (Knight): +1.5k HP from skills');
      expect({for (final r in batch) r: fxFamily(r)}, {
        Relic.manaHymn: FxFamily.mana,
        Relic.saintTear: FxFamily.applied,
        Relic.braveSong: FxFamily.applied,
        Relic.haloLantern: FxFamily.healed,
        Relic.hearth: FxFamily.healed,
        Relic.heartbeat: FxFamily.healed,
        Relic.mercyLily: FxFamily.healed,
        Relic.brightSpring: FxFamily.healed,
      });
      expect([for (final r in batch) if (fxRaisesHp(r)) r], isEmpty);
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
      testWidgets('each of the eight fits ${size.width.round()}x${size.height.round()}: the purple Epik cards and the '
          'buttons on the screen, apart', (tester) async {
        final b = await boot(tester, size);
        final g = b.state = Game(Random(1)).boardRules()
          ..armyMax = null
          ..gold = 200000
          ..wave = 86
          ..chestsGiven = 1;
        for (final type in ['soldier', 'archer', 'knight', 'priest']) {
          expect(g.autoPlace(type), isTrue);
        }
        // The eight three a chest, the longest together (Saint's Tear, Bright Spring, Heartbeat); the last with an old Epik.
        final hands = [
          [Relic.saintTear, Relic.brightSpring, Relic.heartbeat],
          [Relic.manaHymn, Relic.braveSong, Relic.haloLantern],
          [Relic.hearth, Relic.mercyLily, Relic.grail],
        ];
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
