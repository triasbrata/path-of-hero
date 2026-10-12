// Tempa, Bangkit 6+ (late-economy J2, decisions-log 163, lib/tempa.dart; docs/loot-items-relics.md "Tempa"): the purse
// and the prices pinned, the gate and its refusals, the buy and its refit, the compounding stats (Heroes too, skills and
// troop price unchanged), Lepas jenis keeping the levels, the save, finite stats at the top of everything, the Army
// tab's dot, the tooltips, the log and the telemetry. The "+n" and the dot on a booted board: tempa_hud_test.dart.
import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';
import 'package:tower_defense/main.dart' show logLine;
import 'package:tower_defense/telemetry.dart';

import 'real_rules.dart';
import 'hero_skill_helpers.dart';
import 'hud_font.dart';

/// A game after wave 87 with [gold], and [type] at Bangkit 5 (its items' 3, both bought).
Game atFive(String type, [int gold = 10000000]) => bareGame()
  ..wave = 87
  ..gold = gold
  ..upgrades[type] = awakenItems(type, maxAwaken)
  ..ascended[type] = maxAscend;

/// Wins the next wave of [g] at once: begun with nothing to spawn, its one monster gone in the tick (asah_test.dart).
void win(Game g) {
  g
    ..startWave()
    ..queue.clear()
    ..units.add(g.monster('slime', Tier.normal, const Point(300, 60))..gone = true)
    ..tick(0.05);
  expect((g.waveActive, g.over), (false, false));
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
  test('the constants: Bangkit 5 on, +5% HP and damage a level, 20% of a purse x1.2 a level, a guard at 30, the dot at 3 '
      'purses', () {
    expect((purseK, purseRound, nudgePurses), (14, 1000, 3));
    expect((tempaFrom, tempaMax, tempaHp, tempaDmg, tempaTroopPrice), (awakenTop, 30, 0.05, 0.05, 1.0));
    expect((tempaK, tempaRise, tempaRound), (0.2, 1.2, 1000));
    expect([for (final n in [1, 7, 30]) tempaName(n)], ['${Words.forge} +1', '${Words.forge} +7', '${Words.forge} +30']);
  });

  test("the purse: wave 87 166k, 100 358k, 105 479k (the design's values), rounded to 1k", () {
    expect([for (final w in [86, 87, 100, 105]) purse(w)], [156000, 166000, 358000, 479000]);
    for (final w in [1, 15, 40, 63, 87, 120]) {
      final raw = purseK * (4 + 2 * w) * pow(1 + killGoldGrowth, w - 1);
      expect((purse(w) - raw).abs(), lessThanOrEqualTo(purseRound / 2), reason: 'wave $w');
      expect(purse(w) % purseRound, 0);
    }
  });

  test('the prices: wave 87 33k, 40k, 48k, 57k, 69k; wave 100 72k, 86k, 103k, 124k; never under 1k', () {
    expect([for (var n = 0; n < 5; n++) tempaPrice(87, n)], [33000, 40000, 48000, 57000, 69000]);
    expect([for (var n = 0; n < 4; n++) tempaPrice(100, n)], [72000, 86000, 103000, 124000]);
    expect((tempaPrice(15, 0), tempaPrice(1, 0)), (tempaRound, tempaRound), reason: 'a purse that small would round to 0');
    final g = atFive('knight');
    expect(g.tempaPriceOf('knight'), 33000);
    g.tempa['knight'] = 4;
    expect(g.tempaPriceOf('knight'), 69000);
    g.wave = 100;
    expect(g.tempaPriceOf('knight'), tempaPrice(100, 4), reason: "the wave's purse, now");
    g.tempa['knight'] = tempaMax;
    expect(g.tempaPriceOf('knight'), isNull);
  });

  test('the refusals, in order: the store closed (before wave 15, mid-wave, game over), not Bangkit 5, Tempa +30, gold', () {
    final g = atFive('knight')..wave = storeFrom - 1;
    expect(g.whyNotTempa('knight'), storeRefusalNames[StoreRefusal.locked]);
    g.wave = 87;
    expect(g.whyNotTempa('knight'), isNull);
    g.ascended['archer'] = maxAscend; // bought, but its items are short of Bangkit 3: it isn't at 5
    for (final (type, items) in [('archer', 2), ('wizard', 3)]) {
      g.upgrades[type] = awakenItems(type, items);
    }
    g.ascended['wizard'] = 1;
    expect((g.whyNotTempa('archer'), g.whyNotTempa('wizard'), g.whyNotTempa('soldier')),
        ('Needs Awaken 5 first', 'Needs Awaken 5 first', 'Needs Awaken 5 first'));
    g.startWave();
    expect((g.whyNotTempa('knight'), g.whyNotTempa('archer')), (storeRefusalNames[StoreRefusal.midWave], storeRefusalNames[StoreRefusal.midWave]),
        reason: 'the store first');
    g.queue.clear(); // won
    g.tick(0.05);
    expect(g.wave, 88);
    g.gold = g.tempaPriceOf('knight')! - 1;
    expect(g.whyNotTempa('knight'), 'Not enough gold');
    final gold = g.gold;
    expect((g.temper('knight'), g.gold, g.tempa['knight'], g.sfx.last), (false, gold, null, Sfx.error));
    g
      ..tempa['knight'] = tempaMax
      ..gold = 1 << 40;
    expect(g.whyNotTempa('knight'), 'Already Forge +30 (Max)');
    expect(g.temper('knight'), isFalse);
    g.lives = 0;
    expect(g.whyNotTempa('knight'), storeRefusalNames[StoreRefusal.over]);
  });

  test('buying: the price off the gold, every living troop of the type refit with its HP and bursting in Bangkit 5\'s '
      'colour, logged; the next level compounds', () {
    final g = atFive('knight');
    final k = placeNow(g, 'knight', 2, 3), other = placeNow(g, 'archer', 0, 2);
    final five = g.statsOf('knight'), maxHp = k.maxHp, otherHp = other.maxHp;
    k.hp = k.maxHp - 30.0; // wounded
    final gold = g.gold;
    expect(g.temper('knight'), isTrue);
    expect((g.gold, g.tempa['knight'], g.tempaOf('knight'), g.tempaPriceOf('knight')), (gold - 33000, 1, 1, 40000));
    expect(g.statsOf('knight').hp, (five.hp * 1.05).round());
    expect(g.statsOf('knight').dmg, closeTo(five.dmg * 1.05, 1e-9));
    expect(k.maxHp, g.statsOf('knight').hp);
    expect(k.hp, closeTo(k.maxHp - 30, 1e-9), reason: 'the HP gained comes with it');
    expect(k.maxHp - maxHp, (five.hp * 1.05).round() - five.hp);
    expect(k.stats.dmg, closeTo(g.statsOf('knight').dmg, 1e-9));
    expect(other.maxHp, otherHp, reason: 'another type');
    expect(g.impacts.last, (k.pos, awakeFx('upgrade', awakenTop)));
    expect(g.sfx.sublist(g.sfx.length - 2), [Sfx.magic, Sfx.clear]);
    final e = g.log.entries.whereType<Tempered>().single;
    expect(e.toJson(), {'v': eventVersion, 'kind': 'tempa', 'wave': 87, 't': g.t, 'type': 'knight', 'level': 1, 'cost': 33000});
    expect(logLine(e), '${troopTypeNames['knight']}: ${tempaName(1)} (33k gold)');

    expect(g.temper('knight'), isTrue);
    expect((g.gold, g.tempaOf('knight')), (gold - 73000, 2));
    expect(g.statsOf('knight').hp, (five.hp * pow(1.05, 2)).round(), reason: 'compounding, from Bangkit 5\'s');
    expect(g.statsOf('knight').dmg, closeTo(five.dmg * pow(1.05, 2), 1e-9));
    expect(logLine(g.log.entries.whereType<Tempered>().last), '${troopTypeNames['knight']}: ${tempaName(2)} (40k gold)');
  });

  test('the stats: HP and damage (a heal) x1.05 a level, compounding, after Bangkit 5\'s; the rest, the MP, the troop '
      'price and the awakening skill stay', () {
    for (final type in ['knight', 'archer', 'priest', 'wizard', 'knight_templar', 'armored_axeman']) {
      final g = atFive(type), five = g.statsOf(type), price = g.priceOf(type);
      final skill = awakenSkillOf(type), lines = awakenLines(type, awakenTop);
      for (final n in [1, 6, tempaMax]) {
        g.tempa[type] = n;
        final s = g.statsOf(type), k = pow(1.05, n);
        // The heavy types' +20% comes after, so their HP is rounded twice, Bangkit 5's rounding grown by k.
        expect(s.hp, closeTo(five.hp * k, heavyTypes.contains(type) ? 1.1 + 0.5 * k : 0.5), reason: '$type +$n');
        expect(s.dmg, closeTo(five.dmg * k, 1e-9 * k * five.dmg), reason: '$type +$n');
        expect((s.mp, s.mpRegen, s.def, s.range, s.speed, s.rate, s.regen), (five.mp, five.mpRegen, five.def, five.range, five.speed, five.rate, five.regen),
            reason: '$type +$n');
        expect(g.priceOf(type), price, reason: 'tempaTroopPrice 1: no dearer');
        expect(g.awakenLevel(type), awakenTop);
        expect(awakenSkillOf(type), skill, reason: 'skills unchanged');
        expect(awakenLines(type, g.awakenLevel(type)), lines, reason: 'skills unchanged');
      }
    }
  });

  test('Tempa counts only at Bangkit 5: levels on a type below it wait', () {
    final g = atFive('knight')..tempa['knight'] = 4;
    final withTempa = g.statsOf('knight');
    g.ascended['knight'] = 1; // Bangkit 4
    final four = (bareGame()
          ..upgrades['knight'] = awakenItems('knight', maxAwaken)
          ..ascended['knight'] = 1)
        .statsOf('knight');
    expect((g.tempaOf('knight'), g.statsOf('knight').hp, g.statsOf('knight').dmg), (0, four.hp, four.dmg));
    g.ascended['knight'] = maxAscend;
    expect((g.tempaOf('knight'), g.statsOf('knight').hp), (4, withTempa.hp));
  });

  test('a Hero gets its type\'s Tempa under its own x3', () {
    final g = atFive('knight');
    final h = placeNow(g, 'knight', 2, 3)
      ..hero = true
      ..heroStats = [HeroStat.hp, HeroStat.power];
    g.temper('knight'); // refits every living knight, the Hero too
    final aura = g.troops.any((o) => o != h && o.alive && o.hero) ? auraBoost : 1.0;
    final want = g.statsOf('knight').heroic(h.heroStats.toSet(), heroBoost, aura);
    expect((h.maxHp, h.stats.dmg), (want.hp, want.dmg));
    g.tempa['knight'] = 0;
    expect(want.hp, greaterThan(g.statsOf('knight').heroic(h.heroStats.toSet(), heroBoost, aura).hp));
  });

  test('Lepas jenis keeps the levels and pays back only the troops\' price share; bought again, they fight with them', () {
    final g = atFive('knight');
    placeNow(g, 'knight', 2, 3);
    placeNow(g, 'knight', 2, 4);
    final price = g.priceOf('knight');
    g.temper('knight');
    g.temper('knight');
    expect(g.priceOf('knight'), price);
    final gold = g.gold, refund = g.releaseRefundOf('knight');
    expect(refund, (2 * price * releaseRefund).round(), reason: 'no share of the Tempa\'s gold');
    expect(g.releaseType('knight'), refund);
    expect((g.gold, g.tempa['knight'], g.tempaOf('knight')), (gold + refund, 2, 2));
    final back = placeNow(g, 'knight', 1, 3);
    expect(back.maxHp, g.statsOf('knight').hp);
    expect(g.statsOf('knight').hp, (atFive('knight').statsOf('knight').hp * pow(1.05, 2)).round());
  });

  test('the save keeps the levels as `tempa {type: n}`, before the troops come in; an old save has none', () {
    final g = atFive('knight_templar');
    final t = placeNow(g, 'knight_templar', 2, 3);
    g
      ..temper('knight_templar')
      ..temper('knight_templar');
    final j = jsonDecode(jsonEncode(g.toJson())) as Map<String, dynamic>;
    expect(j['tempa'], {'knight_templar': 2});
    final back = Game.fromJson(j);
    expect(back.tempa, {'knight_templar': 2});
    expect(back.tempaOf('knight_templar'), 2);
    final u = back.troops.single;
    expect((u.maxHp, u.hp), (t.maxHp, t.hp), reason: 'loaded at its Tempa HP, not cut to Bangkit 5\'s');
    expect(jsonEncode(back.toJson()), jsonEncode(g.toJson()));

    final old = Game.fromJson(Map.of(j)..remove('tempa'));
    expect(old.tempa, isEmpty);
    expect((old.tempaOf('knight_templar'), old.toJson().containsKey('tempa')), (0, false));
    expect(bareGame().toJson().containsKey('tempa'), isFalse);
    // A save naming a type that isn't one, or more levels than the guard, loads what can be.
    final odd = Game.fromJson(Map.of(j)..['tempa'] = {'orc': 1, 'knight_templar': 99});
    expect(odd.tempa, {'knight_templar': tempaMax});
  });

  test('stats stay finite at the top of everything: a Bangkit 5 Hero at Tempa +30 with Dawn Star ★3 and Oath of One, '
      'fighting a boss', () {
    final g = atFive('knight')
      ..heroSkills = false
      ..monsterSkills = false;
    final h = placeNow(g, 'knight', 2, 3)
      ..hero = true
      ..heroStats = [HeroStat.hp, HeroStat.power];
    g
      ..tempa['knight'] = tempaMax - 1
      ..givePusaka(Relic.dawnStar, type: 'knight', stars: starMax)
      ..givePusaka(Relic.oathOfOne);
    expect((g.oath, g.oathWaits), (Relic.oathOfOne, false), reason: 'the knight alone: 1 type alive');
    expect(g.temper('knight'), isTrue);
    expect(g.tempaOf('knight'), tempaMax);
    final s = h.stats;
    for (final v in [s.hp, s.dmg, s.def, s.range, s.speed, s.rate, s.regen, s.mp, s.mpRegen, h.maxHp, h.hp]) {
      expect(v.isFinite && v >= 0, isTrue, reason: '$v');
    }
    // x2.25 (Bangkit 5) x4.32 (Tempa +30) x1.5 (the oath) x3 (the Hero's HP), and its amulets' HP: big, but nowhere near
    // overflowing.
    final base = troopTypes['knight']!, hp = base.hp * 2.25 * pow(1.05, 30) * oathOneK.k * heroBoost;
    final amulets = [for (final i in g.upgrades['knight']!) if (i.slot == ItemSlot.amulet) g.itemK(i)].fold(1.0, (a, k) => a * k);
    expect(h.maxHp, closeTo(hp * amulets, hp * amulets * 0.01));
    expect(h.maxHp, lessThan(1 << 31));
    expect(s.dmg, greaterThan(g.statsOf('knight').dmg), reason: 'the Hero\'s power x3 on top');
    g
      ..startWave()
      ..queue.clear();
    final boss = foeAt(g, 'orc', h.pos + const Point(10, 0), Tier.boss)..hp = 1e9;
    runFor(g, 3);
    expect(boss.hp.isFinite && boss.hp < 1e9, isTrue, reason: 'it hit, and the numbers held');
    expect(h.hp.isFinite, isTrue);
  });

  test("the Toko tab's dot: gold at 3 purses of the next wave, and a fielded type that can buy a Bangkit or Tempa level", () {
    final g = atFive('knight');
    placeNow(g, 'knight', 2, 3);
    final a = placeNow(g, 'archer', 0, 2);
    g.upgrades['archer'] = awakenItems('archer', 2);
    final bar = nudgePurses * purse(88);
    expect(bar, 528000);
    g.gold = bar - 1;
    expect(g.tokoNudge, isFalse, reason: 'not yet 3 purses');
    g.gold = bar;
    expect(g.tokoNudge, isTrue);
    g.tempa['knight'] = tempaMax;
    expect(g.tokoNudge, isFalse, reason: 'nothing left to buy for it');
    // The Bangkit 2 archer can't buy anything; at Bangkit 3 it can buy Bangkit 4.
    g.upgrades['archer'] = awakenItems('archer', 3);
    expect(g.tokoNudge, isTrue);
    a.gone = true; // no archer alive: its Bangkit 4 doesn't count
    expect(g.tokoNudge, isFalse);
    g.tempa['knight'] = 3;
    expect(g.tokoNudge, isTrue);
    g.startWave();
    expect(g.tokoNudge, isFalse, reason: 'between waves only');
  });

  test('the tooltips: the Bangkit row at Bangkit 5 tells the next Tempa level; the stars tell what it has', () {
    final g = atFive('knight');
    expect(g.tempaInfo('knight').$1, tempaName(1));
    expect(g.tempaInfo('knight').$2, [
      'HP +5%, attack +5%',
      'Stacks each level (max +30)',
      'All troops of this type, now and later',
      'Skills stay the same',
      'Troop price stays the same',
      'Price: 33,000 gold',
    ]);
    expect(g.awakenInfo('knight').$2.reversed.take(2).toList(), [(null, '${tempaName(1)}: buy on the ${Words.army} page'), (null, "Max: can't Awaken more")]);
    g.tempa['knight'] = 6;
    expect(g.tempaInfo('knight').$1, tempaName(7));
    expect(g.tempaInfo('knight').$2.reversed.take(2).toList(), ['Price: ${thousands(tempaPrice(87, 6))} gold', 'Now: HP x1.34, attack x1.34']);
    expect(g.awakenInfo('knight').$2.reversed.take(2).toList(), [(null, '${tempaName(7)}: buy on the ${Words.army} page'), (null, '${tempaName(6)}: HP x1.34, attack x1.34')]);
    final p = atFive('priest')..tempa['priest'] = 1;
    expect(p.tempaInfo('priest').$2.first, 'HP +5%, heal +5%');
    expect(p.awakenInfo('priest').$2.reversed.elementAt(1), (null, '${tempaName(1)}: HP x1.05, heal x1.05'));
    g.tempa['knight'] = tempaMax;
    expect((g.tempaInfo('knight').$1, g.tempaInfo('knight').$2.last), (tempaName(30), 'Max: ${tempaName(30)}'));
    expect(g.awakenInfo('knight').$2.last, (null, '${tempaName(30)}: HP x4.32, attack x4.32'));
  });

  test('telemetry: the event is passed on, and the next wave\'s record has gold.tempaSpent', () {
    final g = atFive('knight');
    placeNow(g, 'knight', 2, 3);
    final kept = _Kept();
    TelemetryAdapter([kept], installId: 'i', session: 's', platform: 'test', now: () => DateTime.utc(2026, 10, 2)).attach(g);
    g
      ..temper('knight')
      ..temper('knight');
    win(g);
    final events = [for (final r in kept.records.where((r) => r['rec'] == 'event')) r['event'] as Map<String, dynamic>];
    expect([for (final e in events.where((e) => e['kind'] == 'tempa')) (e['type'], e['level'], e['cost'])], [('knight', 1, 33000), ('knight', 2, 40000)]);
    final w = kept.records.lastWhere((r) => r['rec'] == 'wave');
    expect((w['wave'], (w['gold'] as Map)['tempaSpent'], w['tv']), (88, 73000, telemetryVersion));
    win(g);
    expect((kept.records.lastWhere((r) => r['rec'] == 'wave')['gold'] as Map)['tempaSpent'], 0); // since then
  });

  test("every line Tempa shows is in the HUD's font", () {
    final font = fontChars();
    final g = atFive('knight')..tempa['knight'] = 12;
    final lines = <String>[
      ...[tempaRefusals.first, tempaRefusals.maxed, tempaRefusals.gold, 'Needs Awaken 5', 'Awaken 5 first', 'Max'],
      'Forge +13  33k', 'Forge  33k', '33k', '+12', '+30', '${troopTypeNames['knight']}: ${tempaName(13)}!',
      ...g.tempaInfo('knight').$2, g.tempaInfo('knight').$1,
      for (final (_, l) in g.awakenInfo('knight').$2) l,
      for (final type in troopTypes.keys) logLine(Tempered(87, 0, type: type, level: 30, cost: 1222000)),
    ];
    for (final line in lines) {
      expect([for (final ch in line.runes) if (!font.contains(ch)) String.fromCharCode(ch)], isEmpty, reason: line);
    }
  });
}
