// "Bangkit 4-5", Kebangkitan Emas (#92 part 2, lib/ascend.dart; docs/loot-items-relics.md "Bangkit 4-5"): the level,
// the stats and the price, the refusals, the buy and its refit, the awakening skills past Bangkit 3, the save, the
// log and the bag's hint. The Tas tab's dot on a booted board: ascend_hud_test.dart.
import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';
import 'package:tower_defense/main.dart' show logLine;

import 'awaken_items.dart';
import 'hero_skill_helpers.dart';

/// A game whose store is open (wave [storeFrom] won) with [gold], and [type] at Bangkit 3 from its items.
Game atThree(String type, [int gold = 1000000]) => bareGame()
  ..wave = storeFrom
  ..gold = gold
  ..upgrades[type] = awakenItems(type, maxAwaken);

void main() {
  test('the constants: two levels past Bangkit 3, x1.25 damage, the same troop price, -15% cooldown, 100k and 250k', () {
    expect((maxAscend, awakenTop, ascendPower, ascendTroopPrice, ascendSkillCd), (2, 5, 1.25, 1.0, 0.85));
    expect(ascendPrice, [100000, 250000]);
    expect([for (var l = 0; l <= awakenTop; l++) awakenName(l)],
        [awakenName(0), awakenName(1), awakenName(2), awakenName(3), awakenName(4), awakenName(5)]);
  });

  test('the level counts what was bought only at Bangkit 3 from the items', () {
    final g = bareGame()..ascended['knight'] = 2;
    g.upgrades['knight'] = awakenItems('knight', 2);
    expect((g.itemLevel('knight'), g.awakenLevel('knight')), (2, 2), reason: 'Bangkit 2: what was bought waits');
    g.upgrades['knight'] = awakenItems('knight', 3);
    expect((g.itemLevel('knight'), g.awakenLevel('knight')), (3, 5));
    g.ascended['knight'] = 1;
    expect(g.awakenLevel('knight'), 4);
    expect(g.awakenLevel('archer'), 0);
  });

  test('Bangkit 4 and 5: HP and MP x2 and x2.25 of the base, damage (a heal) x1.25 and x1.5625; price and caps unchanged', () {
    for (final type in ['knight', 'archer', 'priest', 'knight_templar']) {
      final g = atThree(type), base = troopTypes[type]!, three = g.statsOf(type);
      final price = g.priceOf(type), caps = {for (final i in Item.values) i: g.capOf(type, i)};
      for (final (level, hp, dmg) in [(4, 2.0, 1.25), (5, 2.25, 1.5625)]) {
        g.ascended[type] = level - maxAwaken;
        final s = g.statsOf(type);
        // The HP of Awaken 3's x1.75 scaled to x2 / x2.25, the items' (an amulet's) share with it (decisions-log 321).
        expect(s.hp, closeTo(three.hp * hp / (1 + awakenHp * maxAwaken), 2), reason: '$type $level');
        expect(s.mp, (base.mp * hp).round(), reason: '$type $level');
        expect(s.mpRegen, closeTo(base.mpRegen * hp, 1e-9));
        expect(s.dmg, closeTo(three.dmg * dmg, 1e-9), reason: '$type $level');
        expect((s.def, s.range, s.speed, s.rate, s.regen), (three.def, three.range, three.speed, three.rate, three.regen));
        expect(g.priceOf(type), price, reason: 'ascendTroopPrice 1: no dearer');
        expect({for (final i in Item.values) i: g.capOf(type, i)}, caps, reason: 'no more items fit');
        expect(g.whyNot(Item.sword, type), g.recipeOf(type).containsKey(Item.sword) ? Refusal.maxed : Refusal.notInRecipe);
      }
    }
  });

  test('the refusals, in order: the store closed (before wave 15, mid-wave, game over), not Bangkit 3, Bangkit 5, gold', () {
    final g = atThree('knight')..wave = storeFrom - 1;
    expect(g.whyNotAscend('knight'), storeRefusalNames[StoreRefusal.locked]);
    g.wave = storeFrom;
    expect(g.whyNotAscend('archer'), 'Needs Awaken 3 first');
    expect(g.whyNotAscend('knight'), isNull);
    g.startWave();
    expect(g.whyNotAscend('knight'), storeRefusalNames[StoreRefusal.midWave]);
    expect(g.whyNotAscend('archer'), storeRefusalNames[StoreRefusal.midWave], reason: 'the store first');
    g.queue.clear(); // won
    g.tick(0.05);
    g.gold = ascendPrice[0] - 1;
    expect(g.whyNotAscend('knight'), 'Not enough gold');
    final gold = g.gold;
    expect((g.ascend('knight'), g.gold, g.ascended['knight'], g.sfx.last), (false, gold, null, Sfx.error));
    g.ascended['knight'] = maxAscend;
    g.gold = 10000000;
    expect(g.whyNotAscend('knight'), 'Already ${awakenName(5)}');
    g.lives = 0;
    expect(g.whyNotAscend('knight'), storeRefusalNames[StoreRefusal.over]);
  });

  test('buying: 100k then 250k off the gold, every living troop of the type refit with its HP and bursting, logged', () {
    final g = atThree('knight');
    final k = placeNow(g, 'knight', 2, 3), other = placeNow(g, 'archer', 0, 2);
    g.gold = 400000;
    k.hp = k.maxHp - 30.0; // wounded
    final (maxHp, otherHp) = (k.maxHp, other.maxHp);
    expect(g.ascendPriceOf('knight'), 100000);
    expect(g.ascend('knight'), isTrue);
    expect((g.gold, g.ascended['knight'], g.awakenLevel('knight'), g.ascendPriceOf('knight')), (300000, 1, 4, 250000));
    expect(k.maxHp, closeTo(maxHp * (1 + awakenHp * 4) / (1 + awakenHp * 3), 1), reason: 'x2 of the base for x1.75, with its amulets');
    expect(k.maxHp, g.statsOf('knight').hp);
    expect(k.hp, closeTo(k.maxHp - 30, 1e-9), reason: 'the HP gained comes with it');
    expect(k.stats.dmg, closeTo(g.statsOf('knight').dmg, 1e-9));
    expect(other.maxHp, otherHp, reason: 'another type');
    expect(g.impacts.last, (k.pos, awakeFx('upgrade', 4)));
    expect(g.sfx.sublist(g.sfx.length - 2), [Sfx.magic, Sfx.clear]);
    final e = g.log.entries.whereType<Ascended>().single;
    expect(e.toJson(), {'v': eventVersion, 'kind': 'ascended', 'wave': storeFrom, 't': g.t, 'type': 'knight', 'level': 4, 'cost': 100000});
    expect(logLine(e), '${troopTypeNames['knight']}: ${awakenName(4)} (100k gold)');

    expect(g.ascend('knight'), isTrue);
    expect((g.gold, g.awakenLevel('knight'), g.ascendPriceOf('knight'), g.whyNotAscend('knight')), (50000, 5, null, 'Already ${awakenName(5)}'));
    expect(k.maxHp, g.statsOf('knight').hp);
    expect(logLine(g.log.entries.whereType<Ascended>().last), '${troopTypeNames['knight']}: ${awakenName(5)} (250k gold)');
  });

  test('the awakening skill past Bangkit 3: its numbers and MP stay Bangkit 3\'s, its cooldown x0.85 a level', () {
    for (final s in AwakenSkill.values) {
      expect(s.cooldownAt(4), closeTo(s.cooldown[2] * awakenCdK * 0.85, 1e-9), reason: s.name);
      expect(s.cooldownAt(5), closeTo(s.cooldown[2] * awakenCdK * 0.85 * 0.85, 1e-9), reason: s.name);
      expect((s.costAt(4), s.costAt(5), s.titleAt(5)), (s.costAt(3), s.costAt(3), s.titleAt(3)), reason: s.name);
      expect(awakenLines(s.type, 5).skip(1).take(2), awakenLines(s.type, 3).skip(1).take(2), reason: '${s.name}: what it does');
    }
    expect(awakenLines('soldier', 3).skip(3), ['MP 14, cooldown 9s', '${awakenName(4)}: cooldown 7.7s']); // awakenCdK (decisions-log 298)
    expect(awakenLines('soldier', 4).skip(3), ['MP 14, cooldown 7.7s', '${awakenName(5)}: cooldown 6.5s']);
    expect(awakenLines('soldier', 5).skip(3), ['MP 14, cooldown 6.5s']);

    // A Bangkit 5 soldier casts Disarm with Bangkit 3's numbers, its clock at the shorter cooldown.
    final g = bareGame(Random(1))
      ..heroSkills = false
      ..monsterSkills = false
      ..ascended['soldier'] = 2;
    g.upgrades['soldier'] = awakenItems('soldier', 3);
    final u = placeNow(g, 'soldier', 2, 3);
    g
      ..startWave()
      ..queue.clear();
    u
      ..cd = hold
      ..mp = u.stats.mp.toDouble()
      ..skillAt = g.t;
    final boss = foeAt(g, 'orc', u.pos + const Point(10, 0), Tier.boss)..hp = 1e5;
    expect(g.awakenOf(u), (AwakenSkill.disarm, 5));
    final hp = boss.hp;
    g.tick(0.05);
    expect(g.log.entries.whereType<AwakenSkillCast>().single.level, 5);
    expect(boss.hp, closeTo(hp - hitTaken(u.stats.dmg * disarmK.hit[2], boss.stats.def), 1e-6));
    expect(g.effectK(boss, Status.weaken), disarmK.boss[2]);
    expect(u.mp, closeTo(u.stats.mp - AwakenSkill.disarm.costAt(3), 1e-6));
  });

  test('the book: the stars\' tooltip names the Army page from Bangkit 3, Max at 5; the section\'s card', () {
    final g = atThree('priest');
    expect((g.awakenInfo('priest').$1, g.awakenInfo('priest').$2.last), (awakenName(3), (null, '${awakenName(4)}: buy on the ${Words.army} page')));
    g.ascended['priest'] = 1;
    expect(g.awakenInfo('priest').$2.last, (null, '${awakenName(5)}: buy on the ${Words.army} page'));
    g.ascended['priest'] = 2;
    expect(g.awakenInfo('priest').$1, awakenName(5));
    expect(g.awakenInfo('priest').$2.reversed.take(2).toList(), [(null, '${tempaName(1)}: buy on the ${Words.army} page'), (null, "Max: can't Awaken more")],
        reason: 'then Tempa (tempa_test.dart)');
    g.ascended.clear();
    expect(g.ascendInfo('priest').$1, awakenName(4));
    expect(g.ascendInfo('priest').$2, [
      '+25% base HP and MP',
      'Heal x1.25',
      'All troops of this type, now and later',
      'Awaken skill: cooldown -15%',
      'Troop price stays the same',
      'Price: 100,000 gold',
    ]);
    expect(g.ascendInfo('archer').$2[1], 'Attack x1.25');
    expect(g.ascendInfo('archer').$1, awakenName(4), reason: 'below Bangkit 3 it tells of the first one bought');
    g.ascended['priest'] = 2;
    expect(g.ascendInfo('priest').$1, awakenName(5));
    expect(g.ascendInfo('priest').$2.last, 'Troop price stays the same', reason: 'nothing left to buy');
  });

  test('the save keeps what was bought, before the troops come in; an old save has none', () {
    final g = atThree('knight_templar');
    final t = placeNow(g, 'knight_templar', 2, 3);
    g.ascend('knight_templar');
    final j = jsonDecode(jsonEncode(g.toJson())) as Map<String, dynamic>;
    expect(j['ascended'], {'knight_templar': 1});
    final back = Game.fromJson(j);
    expect(back.ascended, {'knight_templar': 1});
    expect(back.awakenLevel('knight_templar'), 4);
    final u = back.troops.single;
    expect((u.maxHp, u.hp), (t.maxHp, t.hp), reason: 'loaded at its Bangkit 4 HP, not cut to Bangkit 3\'s');
    expect(jsonEncode(back.toJson()), jsonEncode(g.toJson()));

    final old = Map.of(j)..remove('ascended');
    final o = Game.fromJson(old);
    expect(o.ascended, isEmpty);
    expect((o.awakenLevel('knight_templar'), o.toJson().containsKey('ascended')), (3, false));
    expect(bareGame().toJson().containsKey('ascended'), isFalse);
    // A save naming a type that isn't one, or more than can be bought, loads what can be.
    final odd = Game.fromJson(Map.of(j)..['ascended'] = {'orc': 1, 'knight': 9});
    expect(odd.ascended, {'knight': maxAscend});
  });

  test('the bag\'s hint: how far the bag\'s items take a type, and the Tas tab\'s dot for a fielded one', () {
    final g = bareGame()..upgrades['archer'] = awakenItems('archer', 2);
    placeNow(g, 'archer', 0, 2);
    expect((g.bagLevel('archer'), g.bagAwakens), (2, false));
    final three = g.gradeSet('archer', 3), short = three.keys.first;
    g.inventory.addAll(three); // just Bangkit 3's grade set
    expect((g.bagLevel('archer'), g.bagAwakens), (3, true));
    g.inventory[short] = g.inventory[short]! - 1; // one short
    expect((g.bagLevel('archer'), g.bagAwakens), (2, false));
    g.inventory[short] = 99;
    expect(g.bagLevel('wizard'), 0, reason: 'its grade sets are missing');
    for (final item in g.awakenNeeds('wizard', maxAwaken).keys) {
      g.inventory[item] = 99;
    }
    expect(g.bagLevel('wizard'), maxAwaken, reason: 'counts only: the bag holds its three grade sets');
    g.units.clear(); // no archer fielded: no dot, though the bag still holds it
    expect((g.bagLevel('archer'), g.bagAwakens), (3, false));
    g.upgrades['archer'] = awakenItems('archer', 3);
    expect(g.bagLevel('archer'), 3, reason: 'Bangkit 3: the rest is bought');
  });
}
