// The Pusaka (decisions-log 138, lib/pusaka.dart): the five artefacts bound to a troop TYPE, at ★1–★3, working on every
// troop of it (one bought later, a Hero) and never lost when they fall; binding, unbinding and Pindah between waves;
// the store refusing a copy and buying one back from the Gudang; the effective counters and the telemetry; the
// migration of a save from before them (the owner's wave-86 save, a wave-68-shaped one, copies) with its default
// binding and Batal; and the four small relics as they were. docs/loot-items-relics.md, "Pusaka".
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';
import 'package:tower_defense/telemetry.dart';

import 'hero_skill_helpers.dart';

/// A game with no skills cast, so what happens is the Pusaka's doing.
Game plain() => bareGame()
  ..skills = false
  ..heroSkills = false
  ..awakenSkills = false;

/// Lets [foe] strike once now (then it stands again).
void strikeBy(Game g, Unit foe) {
  foe
    ..busyUntil = double.negativeInfinity
    ..cd = 0;
  g.tick(0.05);
  foe.busyUntil = hold;
}

/// The owner's save from before the Pusaka (wave 86, 48 troops, the five artefacts in the bag): a copy of their
/// 2026-10-01 snapshot, the one the design names (army-cap's P4 tests read the same file).
Map<String, dynamic> w86() => jsonDecode(File('test/fixtures/save-20261001-2005-pre-awaken.json').readAsStringSync()) as Map<String, dynamic>;

/// [g]'s save as one from before the Pusaka: no `pusaka` and no `notes` key.
Map<String, dynamic> legacy(Game g) => jsonDecode(jsonEncode(g.toJson()..remove('pusaka')..remove('notes'))) as Map<String, dynamic>;

/// Each owned Pusaka's type and stars.
Map<Relic, (String?, int)> owned(Game g) => {for (final MapEntry(key: r, value: p) in g.pusaka.entries) r: (p.type, p.stars)};

/// A sink that keeps the records, through JSON.
class _Kept implements TelemetrySink {
  final records = <Map<String, dynamic>>[];

  @override
  void add(Map<String, Object?> record) => records.add(jsonDecode(jsonEncode(record)) as Map<String, dynamic>);

  @override
  Future<void> flush() async {}
}

void main() {
  final all = [for (final r in Relic.values) if (r.store) r]; // the chest's four Langka: draft_test.dart

  test('the five artefacts are the epik Pusaka in the Toko, bound to a type; the Langka too; the four small relics stay on one troop', () {
    // Today's five first; a new Epik joins them only with [newEpikStore] (pusaka_catalog_test.dart checks every row).
    expect(all.take(5), [Relic.dragonHeart, Relic.dawnStar, Relic.godThunder, Relic.grail, Relic.voidEye]);
    if (!newEpikStore) expect(all.length, 5);
    expect([for (final r in all) (r.rarity, r.scope, r.pusaka)], everyElement((Rarity.epik, RelicScope.type, true)));
    final langka = [for (final r in Relic.values) if (r.pusaka && r.rarity == Rarity.langka) r];
    expect(langka, containsAllInOrder([Relic.ironBanner, Relic.bloodFang, Relic.warDrum, Relic.mourningBell]));
    expect([for (final r in Relic.values) if (r.pusaka && r.rarity == Rarity.legenda) r],
        containsAllInOrder([Relic.dragonCrown, Relic.oathOfOne, Relic.alliance])); // the Legenda: legenda_test.dart
    expect([for (final r in langka) (r.rarity, r.scope)], everyElement((Rarity.langka, RelicScope.type)));
    expect([for (final r in droppedRelics) (r.rarity, r.scope, r.pusaka)], everyElement((Rarity.biasa, RelicScope.troop, false)));
    expect([rerollPrice(5), rerollPrice(30), rerollPrice(86)], [700, 2500, 38000]);
  });

  group('the effects, type-wide', () {
    for (final stars in [1, 2, 3]) {
      final i = stars - 1;

      test('Dragon Heart ★$stars: max HP x${dragonHeartK.hp[i]} and 1% of it back a second, in statsOf; other types none', () {
        final g = plain();
        final t = placeNow(g, 'knight_templar', 2, 3), k = placeNow(g, 'knight', 3, 3);
        final base = g.statsOf('knight_templar'), knight = g.statsOf('knight').hp;
        g.givePusaka(Relic.dragonHeart, type: 'knight_templar', stars: stars);
        final hp = (base.hp * dragonHeartK.hp[i]).round();
        expect((g.statsOf('knight_templar').hp, t.maxHp, t.hp), (hp, hp, hp.toDouble())); // the HP gained comes with it
        expect(t.stats.regen, closeTo(base.regen + base.hp * dragonHeartK.hp[i] * dragonHeartK.regen, 1e-9));
        expect((g.statsOf('knight').hp, k.maxHp), (knight, knight));
        t.hp = 100;
        runFor(g, 1);
        expect(t.hp, closeTo(100 + t.stats.regen, 1e-6));
      });

      test("Dawn Star ★$stars: damage, a healer's heal, x${dawnStarK.power[i]}; the pause as it was", () {
        final g = plain();
        final k = placeNow(g, 'knight', 2, 3), p = placeNow(g, 'priest', 0, 3), a = placeNow(g, 'archer', 1, 3);
        final (kd, kr, pd, ad) = (k.stats.dmg, k.stats.rate, p.stats.dmg, a.stats.dmg);
        g
          ..givePusaka(Relic.dawnStar, type: 'knight', stars: stars)
          ..givePusaka(Relic.godThunder, type: 'priest'); // the priest's type holds another
        expect(k.stats.dmg, closeTo(kd * dawnStarK.power[i], 1e-9));
        expect(g.statsOf('knight').dmg, closeTo(kd * dawnStarK.power[i], 1e-9));
        expect((k.stats.rate, p.stats.dmg, a.stats.dmg), (kr, pd, ad));
        g.givePusaka(Relic.dawnStar, type: 'priest', stars: stars); // moved: the knight loses it
        expect(k.stats.dmg, kd);
        expect(p.stats.dmg, closeTo(pd * dawnStarK.power[i], 1e-9));
        expect((g.pusakaOf('priest'), g.gudang.single), (Relic.dawnStar, Relic.godThunder)); // a type holds one
      });

      test("God's Thunder ★$stars: a blow leaps to the ${godThunderK.jumps[i]} nearest other monsters within 3 tiles, at 40%", () {
        final g = plain();
        final k = placeNow(g, 'knight', 2, 3);
        g.givePusaka(Relic.godThunder, type: 'knight', stars: stars);
        final foe = foeAt(g, 'orc', k.pos + const Point(14, 0));
        final near = [for (final d in [12.0, 24.0, 36.0, 44.0, 47.0, 60.0]) foeAt(g, 'orc', foe.pos + Point(d, 0))];
        final full = foe.hp, from = foe.pos, at = [for (final o in near) o.pos];
        g.tick(0.05);
        final jumps = godThunderK.jumps[i], leap = 20 * godThunderK.share; // no defence
        expect(foe.hp, full - 20);
        expect([for (final o in near) full - o.hp], [for (var n = 0; n < 6; n++) n < jumps ? leap : 0]);
        expect([for (final b in g.beams) b.points], [for (final p in at.take(jumps)) [from, p]]);
        expect(g.beams.map((b) => b.look), everyElement(BeamLook.thunder));
        expect(g.pusakaWorth[Relic.godThunder]!.worth, closeTo(jumps * leap, 1e-9)); // its counter: the leaps' damage
      });

      test('Grail ★$stars: once a wave each troop of the type lives through its killing blow at ${grailK.hpLeft[i]} HP, 2 s untouchable', () {
        final g = plain();
        final s = placeNow(g, 'soldier', 2, 3), mate = placeNow(g, 'soldier', 2, 5), other = placeNow(g, 'knight', 2, 7);
        for (final u in [s, mate, other]) {
          u.busyUntil = hold;
        }
        g
          ..givePusaka(Relic.grail, type: 'soldier', stars: stars)
          ..startWave()
          ..queue.clear();
        final orc = foeAt(g, 'orc', s.pos + const Point(12, 0));
        s.hp = 1;
        strikeBy(g, orc);
        expect((s.alive, s.fxOnce), (true, true));
        expect(s.hp, closeTo(s.maxHp * grailK.hpLeft[i], 1e-9));
        expect(g.effectOn(s, Status.cap)!.k, 0);
        expect(g.effectOn(s, Status.cap)!.until, closeTo(g.t + grailK.time, 1e-9));
        final hp = s.hp;
        strikeBy(g, orc);
        expect(s.hp, hp); // untouchable
        runFor(g, grailK.time);
        strikeBy(g, orc);
        expect(s.hp, lessThan(hp)); // hurt again
        s.hp = 1;
        strikeBy(g, orc);
        expect(s.alive, isFalse); // its one save this wave is used
        // Its mate has a save of its own; a troop of another type none.
        orc.pos = mate.pos + const Point(12, 0);
        mate.hp = 1;
        strikeBy(g, orc);
        expect(mate.alive, isTrue);
        orc.pos = other.pos + const Point(12, 0);
        other.hp = 1;
        strikeBy(g, orc);
        expect(other.alive, isFalse);
        expect(g.pusakaWorth[Relic.grail]!.uses, 2);
        final k = placeNow(g, 'knight', 3, 6); // bought mid-wave, it strikes at once
        orc
          ..pos = k.pos + const Point(14, 0)
          ..hp = 1;
        for (var n = 0; n < 100 && g.waveActive; n++) {
          g.tick(0.05); // its blow wins the wave: the mate lived to the end, so its save is kept; the soldier's isn't
        }
        expect((g.waveActive, orc.alive, mate.alive), (false, false, true));
        expect(g.pusakaWorth[Relic.grail]!.worth, 1);
        g.startWave();
        expect(mate.fxOnce, isFalse); // every wave's start makes it ready again
      });

      test('Void Eye ★$stars: a monster the type hits takes x${voidEyeK.taken[i]} from every troop for 5 s (the boss x${voidEyeK.boss[i]})', () {
        final g = plain();
        final k = placeNow(g, 'knight', 2, 3);
        g.givePusaka(Relic.voidEye, type: 'knight', stars: stars);
        final orc = foeAt(g, 'orc', k.pos + const Point(14, 0));
        g.tick(0.05);
        expect(orc.maxHp - orc.hp, 20); // the first blow as it is
        final e = g.effectOn(orc, Status.voidMark)!;
        expect(e.k, voidEyeK.taken[i]);
        expect(e.until, closeTo(g.t + voidEyeK.time, 1e-9));
        expect(g.under(orc, Status.vulnerable), isFalse); // its own mark, not Hunter's Mark's
        expect(g.pusakaWorth[Relic.voidEye]?.worth ?? 0, 0);
        k.cd = 0;
        final before = orc.hp;
        g.tick(0.05);
        expect(before - orc.hp, closeTo(20 * voidEyeK.taken[i], 1e-9));
        expect(g.pusakaWorth[Relic.voidEye]!.worth, closeTo(20 * voidEyeK.taken[i] - 20, 1e-9)); // its bonus

        // A troop of another type marks nothing; the boss takes less.
        final h = plain();
        final b = placeNow(h, 'knight', 2, 3)..cd = hold, arch = placeNow(h, 'archer', 1, 3);
        h.givePusaka(Relic.voidEye, type: 'knight', stars: stars);
        final far = foeAt(h, 'orc', arch.pos + const Point(56, 0));
        runFor(h, 0.6);
        expect((far.hp < far.maxHp, h.under(far, Status.voidMark)), (true, false));
        b.cd = 0;
        final necro = foeAt(h, boss, b.pos + const Point(14, 0), Tier.boss);
        h.tick(0.05);
        expect(h.effectK(necro, Status.voidMark), voidEyeK.boss[i]);
      });
    }

    test("Void Eye stacks with Hunter's Mark (x1.25 x 1.25), and a troop's Curse of Frailty is untouched", () {
      final g = plain();
      final k = placeNow(g, 'knight', 2, 3)..cd = hold;
      g.givePusaka(Relic.voidEye, type: 'knight');
      final orc = foeAt(g, 'orc', k.pos + const Point(14, 0));
      g
        ..addEffect(orc, Status.vulnerable, 8, k: huntersMarkK.taken)
        ..addEffect(orc, Status.voidMark, 5, k: voidEyeK.taken[0]);
      k.cd = 0;
      g.tick(0.05);
      expect(orc.maxHp - orc.hp, closeTo(20 * 1.25 * 1.25, 1e-9));

      // A monster's Curse of Frailty on a troop of the Void Eye's type: it takes x1.15, no more.
      g.addEffect(k, Status.vulnerable, 5, k: curseOfFrailtyK.taken);
      orc.pos = k.pos + const Point(12, 0); // in its reach
      final hp = k.hp;
      strikeBy(g, orc);
      expect(hp - k.hp, closeTo(hitTaken(orc.stats.dmg, k.stats.def) * curseOfFrailtyK.taken, 1e-9));
      expect(g.under(k, Status.voidMark), isFalse);
    });

    test("God's Thunder draws at most 12 leaps a second over the field; every leap still hurts", () {
      final g = plain();
      final ks = [for (var r = 0; r < rows; r++) placeNow(g, 'knight', 2, r)];
      g.givePusaka(Relic.godThunder, type: 'knight', stars: 3);
      final foes = [
        for (final k in ks) ...[foeAt(g, 'orc', k.pos + const Point(14, 0))..hp = 1e6, foeAt(g, 'orc', k.pos + const Point(26, 0))..hp = 1e6],
      ];
      g.tick(0.05); // 8 blows, each leaping to 4: 32 leaps
      expect(g.beams.length, godThunderK.beamsPerSec);
      expect(foes.every((o) => o.hp < 1e6), isTrue); // every foe was hit, by a blow or a leap
      expect(g.pusakaWorth[Relic.godThunder]!.worth, closeTo(rows * 4 * 20 * godThunderK.share, 1e-6));
      final first = g.t, later = <Beam>{};
      while (g.t < first + 2) {
        g.tick(0.05);
        later.addAll(g.beams.where((b) => b.since > first));
      }
      expect(later.length, inInclusiveRange(1, godThunderK.beamsPerSec)); // a second on, the budget is back
    });

    test('a troop bought later gets it, and a fall loses nothing: bound, asleep, and back with the next one', () {
      final g = plain();
      final t = placeNow(g, 'knight_templar', 2, 3);
      final hp = (g.statsOf('knight_templar').hp * dragonHeartK.hp[0]).round();
      g.givePusaka(Relic.dragonHeart, type: 'knight_templar');
      final later = placeNow(g, 'knight_templar', 2, 4); // a rebuy
      expect((t.maxHp, later.maxHp), (hp, hp));
      t.dying = 0;
      later.dying = 0; // every templar fell
      expect((g.pusakaOf('knight_templar'), g.pusakaAsleep(Relic.dragonHeart)), (Relic.dragonHeart, true));
      expect(g.pusakaWhere(Relic.dragonHeart), endsWith('★1 (asleep)'));
      final back = placeNow(g, 'knight_templar', 3, 3);
      expect((g.pusakaAsleep(Relic.dragonHeart), back.maxHp), (false, hp));
    });

    test('a Hero of the type gets it too', () {
      final g = plain();
      final h = placeNow(g, 'knight_templar', 2, 3)
        ..hero = true
        ..heroStats = [HeroStat.hp];
      g.givePusaka(Relic.dragonHeart, type: 'knight_templar');
      final withIt = h.maxHp;
      g.unbindPusaka(Relic.dragonHeart);
      expect(withIt / h.maxHp, closeTo(dragonHeartK.hp[0], 0.01));
      expect(h.maxHp, greaterThan(g.statsOf('knight_templar').hp * 2)); // a Hero's HP, x3
    });

    test('useRelic refuses a Pusaka on one troop, and the preview says why', () {
      final g = plain();
      final u = placeNow(g, 'knight', 2, 3);
      g.givePusaka(Relic.grail);
      g.sfx.clear();
      expect(g.useRelic(Relic.grail, u), isFalse);
      expect((g.sfx.single, u.relics.isEmpty), (Sfx.error, true));
      expect(g.assignPreview(Relic.grail, u).why, pusakaOnType);
      expect(g.relicRefusal(Relic.dawnStar, u), 'Artifacts go on a type, not one troop');
    });

    test('the four small relics keep their numbers', () {
      expect((fangShare, thornsShare, furyEvery, furyHit, guardCut, heroRelicSlots), (0.3, 0.3, 3, 2, 0.25, 2));
      final g = plain();
      final u = placeNow(g, 'knight', 2, 3)..cd = hold;
      g.relicBag[Relic.guard] = 1;
      expect(g.useRelic(Relic.guard, u), isTrue);
      final orc = foeAt(g, 'orc', u.pos + const Point(12, 0));
      strikeBy(g, orc);
      expect(u.maxHp - u.hp, closeTo(hitTaken(orc.stats.dmg, u.stats.def) * (1 - guardCut), 1e-9));
    });
  });

  group('binding', () {
    test('the first binding is free, unbinding is free, a later binding (Pindah) costs one reroll price', () {
      final g = plain()
        ..wave = 30
        ..gold = 10000;
      placeNow(g, 'knight', 2, 3);
      g.givePusaka(Relic.grail, type: null);
      expect(g.pusaka[Relic.grail]!.binds, 0);
      final heard = <GameEvent>[];
      g.listeners.add(heard.add);
      final gold = g.gold;
      expect((g.bindPrice(Relic.grail), g.bindPusaka(Relic.grail, 'knight')), (0, true));
      expect((g.gold, g.pusakaOf('knight')), (gold, Relic.grail));
      expect(g.unbindPusaka(Relic.grail), isTrue);
      expect((g.gold, g.gudang.single), (gold, Relic.grail));
      expect(g.bindPrice(Relic.grail), (rerollPrice(30) * pindahShare).round());
      expect(g.bindPusaka(Relic.grail, 'archer'), isTrue); // no archer alive: bound, asleep
      expect((g.gold, g.pusakaAsleep(Relic.grail)), (gold - 2500, true));
      expect(g.bindPusaka(Relic.grail, 'knight'), isTrue); // a Pindah straight from type to type
      expect(g.gold, gold - 5000);
      g.gold = 100;
      expect(g.whyNotBind(Relic.grail, 'archer'), pusakaRefusals.gold);
      expect((g.whyNotBind(Relic.grail, 'knight'), g.whyNotBind(Relic.dawnStar, 'knight')), (pusakaRefusals.same, pusakaRefusals.none));
      expect((g.whyNotBind(Relic.grail, 'goblin'), g.whyNotUnbind(Relic.dawnStar)), (pusakaRefusals.notType, pusakaRefusals.none));
      expect(heard.map((e) => e.toJson()..remove('t')), [
        {'v': eventVersion, 'kind': 'pusakaBound', 'wave': 30, 'relic': 'grail', 'type': 'knight', 'stars': 1, 'cost': 0},
        {'v': eventVersion, 'kind': 'pusakaMoved', 'wave': 30, 'relic': 'grail', 'from': 'knight', 'to': null, 'cost': 0},
        {'v': eventVersion, 'kind': 'pusakaBound', 'wave': 30, 'relic': 'grail', 'type': 'archer', 'stars': 1, 'cost': 2500},
        {'v': eventVersion, 'kind': 'pusakaMoved', 'wave': 30, 'relic': 'grail', 'from': 'archer', 'to': 'knight', 'cost': 2500},
      ]);
      expect(g.log.entries.whereType<PusakaBound>(), isEmpty); // the telemetry's, not the battle log's
    });

    test('binding onto a type that holds one puts that one in the Gudang', () {
      final g = plain();
      placeNow(g, 'knight', 2, 3);
      g
        ..givePusaka(Relic.dawnStar, type: 'knight')
        ..givePusaka(Relic.grail);
      expect(g.bindPusaka(Relic.grail, 'knight'), isTrue);
      expect((g.pusakaOf('knight'), g.gudang.single), (Relic.grail, Relic.dawnStar));
    });

    test('mid-wave and after game over it is refused and nothing changes', () {
      final g = plain();
      placeNow(g, 'knight', 2, 3);
      g
        ..givePusaka(Relic.grail)
        ..givePusaka(Relic.dawnStar, type: 'knight')
        ..startWave();
      expect(bindMidWave, isFalse);
      g.sfx.clear();
      expect((g.whyNotBind(Relic.grail, 'knight'), g.bindPusaka(Relic.grail, 'knight')), (pusakaRefusals.midWave, false));
      expect((g.whyNotUnbind(Relic.dawnStar), g.unbindPusaka(Relic.dawnStar)), (pusakaRefusals.midWave, false));
      expect((g.pusakaOf('knight'), g.gudang.single), (Relic.dawnStar, Relic.grail));
      expect(g.sfx, [Sfx.error, Sfx.error]);
      g.queue.clear();
      g.tick(0.05); // won
      expect(g.whyNotBind(Relic.grail, 'knight'), isNull);
      g.lives = 0;
      expect(g.whyNotBind(Relic.grail, 'knight'), assignRefusals.over);
    });
  });

  test('the store: a Pusaka bought waits in the Gudang at ★1; a copy is refused; a bound one is not bought back', () {
    final g = plain()
      ..wave = storeFrom
      ..inTown = true // the Shop deals only in a Town
      ..gold = 1000000;
    placeNow(g, 'knight', 2, 3);
    expect(g.buy(Relic.grail), isTrue);
    expect((g.gudang.single, g.pusaka[Relic.grail]!.stars, g.inBag(Relic.grail), g.relicBag[Relic.grail]), (Relic.grail, 1, 1, null));
    final gold = g.gold;
    expect((g.whyNotBuy(Relic.grail), g.buy(Relic.grail), g.gold), (StoreRefusal.owned, false, gold));
    expect(storeRefusalNames[StoreRefusal.owned], 'Owned');
    g.bindPusaka(Relic.grail, 'knight');
    expect((g.inBag(Relic.grail), g.whyNotSell(Relic.grail), g.sell(Relic.grail)), (0, StoreRefusal.bound, 0));
    g
      ..unbindPusaka(Relic.grail)
      ..givePusaka(Relic.grail, stars: 3);
    expect(g.sell(Relic.grail), 1); // from the Gudang: half its base, its stars gone with it
    expect((g.gold, g.pusaka.containsKey(Relic.grail)), (gold + artefactPrice[Relic.grail]! ~/ 2, false));
    expect((g.whyNotBuy(Relic.grail), g.buyPrice(Relic.grail)), (null, (artefactPrice[Relic.grail]! * artefactRise).round()));
  });

  group('the counters', () {
    test('Dragon Heart counts a blow that took its troop past its base HP and was lived through', () {
      final g = plain();
      final t = placeNow(g, 'knight_templar', 2, 3)..busyUntil = hold;
      g
        ..givePusaka(Relic.dragonHeart, type: 'knight_templar')
        ..startWave()
        ..queue.clear();
      final orc = foeAt(g, 'orc', t.pos + const Point(12, 0));
      final extra = t.maxHp * (1 - 1 / dragonHeartK.hp[0]), blow = hitTaken(orc.stats.dmg, t.stats.def);
      t.hp = extra + blow / 2; // at its base HP this blow would have killed it
      strikeBy(g, orc);
      expect((t.alive, g.pusakaWorth[Relic.dragonHeart]!.worth), (true, 1));
      strikeBy(g, orc); // under that line already: not again
      expect(g.pusakaWorth[Relic.dragonHeart]!.worth, 1);
    });

    test('Dawn Star counts the healing that landed past its base heal, no overheal', () {
      final g = plain();
      final p = placeNow(g, 'priest', 0, 3), k = placeNow(g, 'knight', 1, 3)..busyUntil = hold;
      g
        ..givePusaka(Relic.dawnStar, type: 'priest')
        ..startWave()
        ..queue.clear();
      foeAt(g, 'orc', const Point(300, 60)); // keeps the wave on
      final heal = p.stats.dmg, base = heal / dawnStarK.power[0];
      k.hp = k.maxHp - heal / 2; // only what it lacks lands: less than the base heal
      for (var n = 0; n < 60 && k.hp < k.maxHp; n++) {
        g.tick(0.05);
      }
      expect(k.hp, k.maxHp.toDouble());
      expect(g.pusakaWorth[Relic.dawnStar]?.worth ?? 0, 0);
      k.hp = k.maxHp - 2 * heal;
      for (var n = 0; n < 60 && k.hp <= k.maxHp - 2 * heal; n++) {
        g.tick(0.05);
      }
      expect(g.pusakaWorth[Relic.dawnStar]!.worth, closeTo(heal - base, 1e-9));
    });

    test('the telemetry: a wave starts with its Pusaka and its record says what each did', () {
      final g = plain();
      final kept = _Kept();
      TelemetryAdapter([kept], installId: 'i', session: 's', platform: 'test', now: () => DateTime.utc(2026, 10, 1)).attach(g);
      final k = placeNow(g, 'knight', 2, 3);
      g
        ..givePusaka(Relic.godThunder, type: 'knight', stars: 2)
        ..givePusaka(Relic.grail)
        ..startWave()
        ..queue.clear();
      foeAt(g, 'orc', k.pos + const Point(14, 0)).hp = 30;
      foeAt(g, 'orc', k.pos + const Point(26, 0)).hp = 3;
      for (var n = 0; n < 200 && g.waveActive; n++) {
        g.tick(0.05);
      }
      expect(g.waveActive, isFalse);
      final w = kept.records.lastWhere((r) => r['rec'] == 'wave');
      expect((w['start'] as Map)['pusaka'], {
        'godThunder': {'type': 'knight', 'stars': 2},
        'grail': {'stars': 1},
      });
      expect(w['pusaka'], {
        'godThunder': {'type': 'knight', 'stars': 2, 'uses': 0, 'worth': 3}, // the leap took the 3 HP the other had
        'grail': {'type': null, 'stars': 1, 'uses': 0, 'worth': 0},
      });
      expect((w['gold'] as Map)['pusakaSpent'], 0);
    });
  });

  test("a fallen troop's relics are in its TroopFell, back in the bag", () {
    final g = plain();
    final u = placeNow(g, 'knight', 2, 3)..busyUntil = hold;
    g.relicBag[Relic.fang] = 1;
    g.useRelic(Relic.fang, u);
    u.hp = 1;
    strikeBy(g, foeAt(g, 'orc', u.pos + const Point(12, 0)));
    final fell = g.log.entries.whereType<TroopFell>().single;
    expect(fell.relics, [Relic.fang]);
    expect(fell.toJson()['relics'], ['fang']);
    expect(g.relicBag[Relic.fang], 1);
  });

  group('the save', () {
    test('a round trip keeps each Pusaka, its type, stars and bindings, and the notes; nothing migrates again', () {
      final g = plain()..wave = 20;
      placeNow(g, 'knight_templar', 2, 3);
      g
        ..givePusaka(Relic.dragonHeart, type: 'knight_templar', stars: 2)
        ..givePusaka(Relic.voidEye, stars: 3);
      final hp = g.troops.single.maxHp;
      final j = jsonDecode(jsonEncode(g.toJson())) as Map<String, dynamic>;
      expect(j['pusaka'], {
        'dragonHeart': {'type': 'knight_templar', 'stars': 2, 'binds': 1},
        'voidEye': {'stars': 3},
      });
      expect(j['notes'], [pusakaNote]);
      final h = Game.fromJson(j);
      expect(owned(h), {Relic.dragonHeart: ('knight_templar', 2), Relic.voidEye: (null, 3)});
      expect((h.troops.single.maxHp, h.pusakaNoteDue, h.bindPrice(Relic.dragonHeart), h.bindPrice(Relic.voidEye)), (hp, false, rerollPrice(20), 0));
      // An unknown Pusaka name or type is dropped, not thrown on.
      j['pusaka'] = {
        'dragonHeart': {'type': 'goblin', 'stars': 9},
        'ironCrown': {'stars': 1},
      };
      j['relicBag'] = {'fang': 2, 'ironCrown': 1};
      final o = Game.fromJson(j);
      expect(owned(o), {Relic.dragonHeart: (null, 3)});
      expect(o.relicBag, {Relic.fang: 2});
    });

    test("the owner's wave-86 save: its 5 artefacts become Pusaka at ★1, bound by default; the small relics as they were", () {
      final j = w86();
      final g = Game.fromJson(j, Random(1), Random(2), Random(3));
      expect(owned(g), {
        Relic.dragonHeart: ('knight_templar', 1),
        Relic.grail: ('armored_axeman', 1),
        Relic.godThunder: ('wizard', 1),
        Relic.dawnStar: ('priest', 1),
        Relic.voidEye: ('archer', 1),
      });
      expect(g.pusaka.values.every((p) => p.suggested && p.binds == 1), isTrue);
      expect(g.relicBag, {Relic.fury: 23, Relic.thorns: 29, Relic.fang: 17, Relic.guard: 21});
      expect([for (final u in g.troops) ...u.relics]..sort((a, b) => a.index.compareTo(b.index)), [Relic.fang, Relic.fang, Relic.fury]);
      expect((g.troops.length, g.wave, g.gold, g.pusakaNoteDue), (48, 86, j['gold'], true));
      expect((g.storeBought[Relic.grail], (g..inTown = true).whyNotBuy(Relic.grail)), (1, StoreRefusal.owned)); // in a Town

      // The templars got Dragon Heart's HP, what they had lost kept: the HP gained came with it.
      final base = Game.fromJson(w86(), Random(1), Random(2), Random(3))..undoDefaultBinding();
      final saved = [for (final t in j['troops'] as List) if (t['type'] == 'knight_templar') (t['hp'] as num).toDouble()];
      final templars = [for (final u in g.troops) if (u.type == 'knight_templar') u];
      final oldMax = base.troops.firstWhere((u) => u.type == 'knight_templar').maxHp, newMax = templars.first.maxHp;
      expect(templars.length, 13);
      expect(newMax, closeTo(oldMax * dragonHeartK.hp[0], 1)); // the Hero's aura rounds after it
      for (final (n, u) in templars.indexed) {
        expect(u.hp, closeTo(min(newMax.toDouble(), min(saved[n], oldMax) + newMax - oldMax), 1e-9));
      }

      // Its save keeps them, and the note still waits.
      final again = Game.fromJson(jsonDecode(jsonEncode(g.toJson())) as Map<String, dynamic>, Random(1), Random(2), Random(3));
      expect(owned(again), owned(g));
      expect((again.pusakaNoteDue, again.pusaka[Relic.grail]!.suggested), (true, true));
    });

    test('Batal sends all 5 to the Gudang and the first binding stays free; kept, a later move is a Pindah', () {
      final g = Game.fromJson(w86(), Random(1), Random(2), Random(3));
      final hp = g.statsOf('knight_templar').hp;
      expect(g.undoDefaultBinding(), isTrue);
      expect((g.gudang.toSet().containsAll(all), g.pusakaNoteDue), (true, false));
      expect([for (final r in all) g.bindPrice(r)], everyElement(0));
      expect(g.statsOf('knight_templar').hp, (hp / dragonHeartK.hp[0]).round());
      expect(g.troops.every((u) => u.hp <= u.maxHp), isTrue);
      expect(g.undoDefaultBinding(), isFalse); // once

      final h = Game.fromJson(w86(), Random(1), Random(2), Random(3))..dismissPusakaNote();
      expect((h.pusakaNoteDue, h.undoDefaultBinding(), h.bindPrice(Relic.grail)), (false, false, rerollPrice(86)));
      expect(h.pusakaOf('armored_axeman'), Relic.grail);
    });

    test('Lepas jenis sends the released type\'s Pusaka to the Gudang, free; binding it again is a Pindah', () {
      final g = Game.fromJson(w86(), Random(1), Random(2), Random(3))..boardRules();
      final heard = <GameEvent>[];
      g.listeners.add(heard.add);
      final gold = g.gold, refund = g.releaseRefundOf('archer');
      expect(g.releaseType('archer'), refund);
      expect(g.gold, gold + refund); // no price for the Pusaka
      expect((g.pusaka[Relic.voidEye]!.type, g.pusaka[Relic.voidEye]!.suggested, g.gudang.single), (null, false, Relic.voidEye));
      expect([for (final e in heard.whereType<PusakaMoved>()) e.toJson()..remove('t')], [
        {'v': eventVersion, 'kind': 'pusakaMoved', 'wave': 86, 'relic': 'voidEye', 'from': 'archer', 'to': null, 'cost': 0},
      ]);
      expect(heard.last, isA<TypeReleased>());
      expect(owned(g).length, 5); // the other four stay where they are
      expect(g.bindPrice(Relic.voidEye), rerollPrice(86));
      expect(g.releaseType('wizard'), isNotNull);
      expect(g.pusakaOf('wizard'), isNull);
      expect(g.gudang.toSet(), {Relic.voidEye, Relic.godThunder});
    });

    test('a wave-68-shaped save: the 5 worn on templars come off, are counted and bound one per type', () {
      final g = plain();
      final types = ['knight_templar', 'knight_templar', 'knight_templar', 'knight_templar', 'knight_templar', 'armored_axeman', 'wizard', 'priest', 'archer'];
      for (final (n, type) in types.indexed) {
        placeNow(g, type, 2 + n ~/ rows, n % rows);
      }
      final j = legacy(g);
      for (final (n, t) in (j['troops'] as List).take(5).indexed) {
        (t as Map)['relics'] = [all[n].name];
        t['hp'] = 1e6; // the old single-troop HP, say: cut to the max
      }
      final h = Game.fromJson(j);
      expect(h.troops.every((u) => u.relics.isEmpty), isTrue);
      expect(owned(h), {
        Relic.dragonHeart: ('knight_templar', 1),
        Relic.dawnStar: ('priest', 1),
        Relic.godThunder: ('wizard', 1),
        Relic.grail: ('armored_axeman', 1),
        Relic.voidEye: ('archer', 1),
      });
      expect(h.troops.every((u) => u.hp == u.maxHp), isTrue);
      expect(h.pusakaNoteDue, isTrue);
    });

    test('copies: each further one adds a star, past ★3 it pays back half its base; with no type for it, the Gudang', () {
      final g = plain();
      placeNow(g, 'priest', 0, 3);
      g.gold = 0;
      final j = legacy(g)..['relicBag'] = {'grail': 4, 'dawnStar': 1};
      (j['troops'] as List).single['relics'] = ['dawnStar'];
      final h = Game.fromJson(j);
      expect(owned(h), {Relic.grail: (null, 3), Relic.dawnStar: ('priest', 2)}); // no grail type alive
      expect(h.gold, (artefactPrice[Relic.grail]! * copyRefund).round());
      expect(h.relicBag.keys.where((r) => r.pusaka), isEmpty);
    });

    test('a save with no artefacts has no note to show, nor a new game', () {
      final g = plain();
      placeNow(g, 'knight', 2, 3);
      expect((g.pusakaNoteDue, Game.fromJson(legacy(g)).pusakaNoteDue), (false, false));
    });
  });
}
