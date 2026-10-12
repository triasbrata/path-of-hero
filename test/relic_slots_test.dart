// Relics taken off and a Hero's two relic slots (#91): taking one off between waves only, back into the bag; a
// Hero holding two different kinds, both working, and its type's Pusaka on top (decisions-log 138); the save.
// docs/loot-items-relics.md, "Relics".
import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';

import 'hero_skill_helpers.dart';

/// A game with no skills cast (a troop's own guard, a Hero's), so what happens is the relics' doing.
Game plain() => bareGame()
  ..skills = false
  ..heroSkills = false;

/// A troop of [type] at cell (2, 3); a Hero when [hero], with no rolled attributes, so a Hero's stats are its
/// type's ([Game.useRelic] refits them).
Unit troop(Game g, String type, {bool hero = false}) => placeNow(g, type, 2, 3)..hero = hero;

/// A werebear next to [u] that strikes it, or only stands there when not [fights].
Unit bearBy(Game g, Unit u, {bool fights = true}) {
  final bear = Unit(Side.enemy, 'werebear', enemyTypes['werebear']!, u.pos + const Point(10, 0))..busyUntil = fights ? double.negativeInfinity : hold;
  g.units.add(bear);
  return bear;
}

void main() {
  group('taking a relic off', () {
    test('between waves it comes off into the bag, from where it is given again or sold', () {
      final g = plain()..wave = storeFrom; // the store is open: the relic can be sold
      final a = troop(g, 'knight'), b = placeNow(g, 'archer', 1, 4);
      g.relicBag[Relic.guard] = 1;
      expect(g.useRelic(Relic.guard, a), isTrue);
      g.sfx.clear();
      expect((g.whyNotTakeOff(Relic.guard, a), g.takeOff(Relic.guard, a)), (null, true));
      expect(a.relics, isEmpty);
      expect((g.relicBag[Relic.guard], g.relicsHeld(Relic.guard)), (1, 0));
      expect(g.sfx, [Sfx.place]);
      expect(g.useRelic(Relic.guard, b), isTrue); // given again, to another troop
      expect(b.relics, [Relic.guard]);
      expect(g.relicBag[Relic.guard], 0);
      expect(g.takeOff(Relic.guard, b), isTrue);
      final gold = g.gold;
      g.inTown = true; // the Shop buys only in a Town
      expect(g.sell(Relic.guard), 1); // or sold
      expect((g.gold, g.relicBag[Relic.guard]), (gold + g.sellPrice(Relic.guard), 0));
    });

    test('mid-wave it is refused and nothing changes: between waves only', () {
      final g = plain();
      final a = troop(g, 'knight');
      g.relicBag[Relic.guard] = 1;
      expect(g.useRelic(Relic.guard, a), isTrue); // giving is fine mid-wave or not
      g.startWave();
      expect((takeOffMidWave, g.waveActive), (false, true));
      g.sfx.clear();
      expect(g.whyNotTakeOff(Relic.guard, a), takeOffRefusals.midWave);
      expect(g.takeOff(Relic.guard, a), isFalse);
      expect((a.relics.single, g.relicBag[Relic.guard]), (Relic.guard, 0));
      expect(g.sfx, [Sfx.error]);
      g.queue.clear(); // won
      expect(g.waveActive, isFalse);
      expect(g.takeOff(Relic.guard, a), isTrue);
      expect(g.relicBag[Relic.guard], 1);
    });

    test('it is refused for a relic the troop does not hold, a fallen troop, or after game over', () {
      for (final (why, want, setUp) in <(String, String, void Function(Game, Unit))>[
        ('not held', takeOffRefusals.none, (g, u) => u.relics.clear()),
        ('fallen', assignRefusals.gone, (g, u) => u.dying = 0),
        ('game over', assignRefusals.over, (g, u) => g.lives = 0),
      ]) {
        final g = plain();
        final u = troop(g, 'knight')..relics.add(Relic.fang);
        setUp(g, u);
        final held = [...u.relics];
        g.sfx.clear();
        expect(g.whyNotTakeOff(Relic.fang, u), want, reason: why);
        expect(g.takeOff(Relic.fang, u), isFalse, reason: why);
        expect(u.relics, held, reason: why);
        expect(g.relicBag[Relic.fang] ?? 0, 0, reason: why);
        expect(g.sfx, [Sfx.error], reason: why);
      }
    });

    test('a Pusaka is not on a troop to take off; unbound, it takes its stats with it: the HP cut to the max', () {
      final g = plain();
      final u = troop(g, 'knight');
      final hp = u.maxHp;
      g.givePusaka(Relic.dragonHeart, type: 'knight');
      expect((u.maxHp, u.hp, u.relics.isEmpty), ((hp * dragonHeartK.hp[0]).round(), (hp * dragonHeartK.hp[0]).roundToDouble(), true));
      expect(g.whyNotTakeOff(Relic.dragonHeart, u), takeOffRefusals.none);
      expect(g.unbindPusaka(Relic.dragonHeart), isTrue);
      expect((u.maxHp, u.hp, u.stats.regen), (hp, hp.toDouble(), 0));
    });
  });

  group('a Hero holds two', () {
    test('two different kinds; the same kind again, or a third, is refused and stays in the bag', () {
      final g = plain();
      final h = troop(g, 'knight', hero: true);
      g.relicBag.addAll({Relic.guard: 2, Relic.fang: 1, Relic.fury: 1});
      expect((h.relicSlots, heroRelicSlots), (2, 2));
      expect(g.useRelic(Relic.guard, h), isTrue);
      expect(g.assignPreview(Relic.guard, h).why, holdsRelic(Relic.guard)); // no doubling one kind
      g.sfx.clear();
      expect(g.useRelic(Relic.guard, h), isFalse);
      expect(g.sfx, [Sfx.error]);
      expect(g.assignPreview(Relic.fang, h).why, isNull);
      expect(g.useRelic(Relic.fang, h), isTrue);
      expect(h.relics, [Relic.guard, Relic.fang]);
      expect(g.assignPreview(Relic.fury, h).why, assignRefusals.full);
      expect(g.useRelic(Relic.fury, h), isFalse);
      expect(h.relics, [Relic.guard, Relic.fang]);
      expect(g.relicBag, {Relic.guard: 1, Relic.fang: 0, Relic.fury: 1});
      expect((g.relicsHeld(Relic.guard), g.relicsHeld(Relic.fang)), (1, 1));
      expect(g.relicInfo(Relic.guard).$2, containsAllInOrder([relicSlotsLine, 'In bag: 1, in use: 1']));
    });

    test('any other troop still holds one', () {
      final g = plain();
      final u = troop(g, 'knight');
      g.relicBag.addAll({Relic.guard: 1, Relic.fang: 1});
      expect(u.relicSlots, 1);
      expect(g.useRelic(Relic.guard, u), isTrue);
      expect(g.assignPreview(Relic.fang, u).why, holdsRelic(Relic.guard)); // what it holds, not "full"
      expect(g.useRelic(Relic.fang, u), isFalse);
      expect(u.relics, [Relic.guard]);
    });

    test('both work: guard cuts the blows it takes and fang heals it from its own', () {
      final g = plain();
      final h = troop(g, 'knight', hero: true)..busyUntil = hold; // doesn't strike yet
      h.relics.addAll([Relic.guard, Relic.fang]);
      final bear = bearBy(g, h);
      g.tick(0.05);
      final taken = h.maxHp - h.hp;
      expect(taken, closeTo(hitTaken(enemyTypes['werebear']!.dmg, h.stats.def) * (1 - guardCut), 1e-9));
      h
        ..busyUntil = double.negativeInfinity
        ..cd = 0;
      bear.busyUntil = hold;
      final hp = h.hp, bearHp = bear.hp;
      g.tick(0.05);
      final dealt = bearHp - bear.hp;
      expect(dealt, greaterThan(0));
      expect(h.hp, closeTo(hp + dealt * fangShare, 1e-9));
    });

    test('its type\'s Pusaka comes on top of its two relics, and takes no slot', () {
      final g = plain();
      final h = troop(g, 'archer', hero: true);
      final before = h.stats;
      g.relicBag.addAll({Relic.guard: 1, Relic.fang: 1});
      expect(g.useRelic(Relic.guard, h) && g.useRelic(Relic.fang, h), isTrue);
      g.givePusaka(Relic.dawnStar, type: 'archer');
      expect(h.relics, [Relic.guard, Relic.fang]);
      expect(h.stats.dmg, closeTo(before.dmg * dawnStarK.power[0], 1e-9));
      expect(h.stats.rate, before.rate);
      expect(g.assignPreview(Relic.dawnStar, h).why, pusakaOnType);
    });

    test('fury counts with another relic held beside it', () {
      final g = plain();
      final h = troop(g, 'knight', hero: true)..relics.addAll([Relic.guard, Relic.fury]);
      final bear = bearBy(g, h, fights: false)..hp = 1e6;
      final hits = <double>[];
      var last = bear.hp;
      for (var i = 0; i < 200 && hits.length < furyEvery; i++) {
        g.tick(0.05);
        if (bear.hp < last) hits.add(last - bear.hp);
        last = bear.hp;
      }
      expect(hits, [h.stats.dmg, h.stats.dmg, h.stats.dmg * furyHit]); // the werebear has no defence
    });

    test('a fallen Hero gives both back to the bag', () {
      final g = plain();
      final h = troop(g, 'knight', hero: true)..relics.addAll([Relic.thorns, Relic.guard]);
      h.hp = 1;
      bearBy(g, h);
      g.tick(0.05);
      expect(h.alive, isFalse);
      expect(h.relics, isEmpty);
      expect(g.relicBag, {Relic.thorns: 1, Relic.guard: 1});
    });

    test('taking one off leaves the other, and frees its slot', () {
      final g = plain();
      final h = troop(g, 'knight', hero: true)..relics.addAll([Relic.guard, Relic.fang]);
      g.relicBag[Relic.fury] = 1;
      expect(g.takeOff(Relic.guard, h), isTrue);
      expect(h.relics, [Relic.fang]);
      expect(g.relicBag[Relic.guard], 1);
      expect(g.useRelic(Relic.fury, h), isTrue);
      expect(h.relics, [Relic.fang, Relic.fury]);
    });
  });

  test('the save keeps both of a Hero\'s relics, and a save from before them still loads its one', () {
    final g = plain();
    final hero = troop(g, 'knight', hero: true), archer = placeNow(g, 'archer', 1, 4);
    placeNow(g, 'soldier', 1, 2);
    g.relicBag.addAll({Relic.guard: 1, Relic.fang: 1, Relic.thorns: 1});
    for (final (r, u) in [(Relic.guard, hero), (Relic.fang, hero), (Relic.thorns, archer)]) {
      expect(g.useRelic(r, u), isTrue);
    }
    final j = jsonDecode(jsonEncode(g.toJson())) as Map<String, dynamic>;
    expect([for (final t in j['troops'] as List) t['relics']], [
      ['guard', 'fang'],
      ['thorns'],
      null,
    ]);
    final h = Game.fromJson(j);
    expect([for (final t in h.troops) t.relics], [
      [Relic.guard, Relic.fang],
      [Relic.thorns],
      isEmpty,
    ]);
    expect(h.troops.elementAt(1).maxHp, archer.maxHp);

    // Before #91 a troop's one relic was saved as 'relic'.
    for (final t in j['troops'] as List) {
      if ((t as Map)['relics'] case [final one, ...]) t['relic'] = one;
      t.remove('relics');
    }
    final old = Game.fromJson(jsonDecode(jsonEncode(j)) as Map<String, dynamic>);
    expect([for (final t in old.troops) t.relics], [
      [Relic.guard],
      [Relic.thorns],
      isEmpty,
    ]);
  });
}
