// The store (#63): when it opens, its prices, buying and selling, the save, and the five Pusaka it alone sells (one
// of each: decisions-log 138; what they do is pusaka_test.dart's). docs/loot-items-relics.md, "The store".
import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';
import 'package:tower_defense/main.dart' show shortPrice;

import 'hero_skill_helpers.dart';

/// Loot dice: every roll [roll], every pick [pick] (modulo its range).
class _Dice implements Random {
  final double roll;
  final int pick;
  _Dice(this.roll, this.pick);
  @override
  double nextDouble() => roll;
  @override
  int nextInt(int max) => pick % max;
  @override
  bool nextBool() => false;
}

/// A game whose store is open (wave [storeFrom] won), with [gold].
Game openStore([int gold = 1000000]) => bareGame()
  ..wave = storeFrom
  ..gold = gold;

void main() {
  final artefacts = [for (final r in Relic.values) if (r.store) r];

  test('the store opens once wave 15 is won and stays open, dealing between waves only', () {
    final g = bareGame()..wave = storeFrom - 1;
    expect((g.storeOpen, g.whyNotBuy(Item.sword), g.whyNotSell(Item.sword)), (false, StoreRefusal.locked, StoreRefusal.locked));
    g.startWave(); // wave 15 is on: not yet
    expect((g.wave, g.waveActive, g.storeOpen), (storeFrom, true, false));
    g.queue.clear(); // won
    expect((g.waveActive, g.storeOpen, g.whyNotBuy(Item.sword)), (false, true, null));
    g.inventory[Item.sword] = 1;
    g.startWave(); // during a wave it is open but doesn't deal (the owner: between waves only)
    expect(storeMidWave, isFalse);
    expect((g.waveActive, g.storeOpen, g.whyNotBuy(Item.sword), g.whyNotSell(Item.sword)), (true, true, StoreRefusal.midWave, StoreRefusal.midWave));
    final gold = g.gold;
    expect((g.buy(Item.sword), g.sell(Item.sword), g.gold, g.inventory[Item.sword]), (false, 0, gold, 1));
    g.queue.clear(); // won again
    expect((g.whyNotBuy(Item.sword), g.whyNotSell(Item.sword)), (null, null));
    g.lives = 0; // game over
    expect(g.whyNotBuy(Item.sword), StoreRefusal.over);
  });

  test('every kind has its base price and rises with each one of it bought: items +200, relics +1600, Pusaka x1.5', () {
    final g = openStore();
    expect([for (final i in droppedItems) g.buyPrice(i)], everyElement(itemPrice.base));
    expect([for (final r in droppedRelics) g.buyPrice(r)], everyElement(relicPrice.base));
    expect({for (final r in artefacts) r: g.buyPrice(r)},
        {Relic.dragonHeart: 30000, Relic.dawnStar: 40000, Relic.godThunder: 40000, Relic.grail: 24000, Relic.voidEye: 36000});
    expect((itemPrice.base, relicPrice.base), (2000, 8000)); // the owner: twice the design's

    final paid = <int>[];
    for (var i = 0; i < 3; i++) {
      final (price, gold) = (g.buyPrice(Item.gloves), g.gold);
      expect(g.buy(Item.gloves), isTrue);
      expect(g.gold, gold - price);
      paid.add(price);
    }
    expect(paid, [2000, 2200, 2400]);
    expect((g.inventory[Item.gloves], g.buyPrice(Item.gloves), g.buyPrice(Item.gloves, 1)), (3, 2600, 2800));
    expect(g.buyPrice(Item.sword), 2000); // each kind rises on its own
    expect([for (var i = 0; i < 2; i++) (g.buyPrice(Relic.fang), g.buy(Relic.fang)).$1], [8000, 9600]);
    expect((g.buyPrice(Relic.grail), g.buy(Relic.grail)), (24000, true));
    expect((g.relicBag[Relic.fang], g.relicBag[Relic.grail], g.inBag(Relic.grail)), (2, null, 1));
    expect(g.gudang, [Relic.grail]); // a Pusaka waits in the Gudang, not the bag
    final gold = g.gold;
    expect((g.whyNotBuy(Relic.grail), g.buy(Relic.grail), g.gold), (StoreRefusal.owned, false, gold)); // one of each
    expect(g.sell(Relic.grail), 1); // sold back, it can be bought again, for more
    expect((g.whyNotBuy(Relic.grail), g.buyPrice(Relic.grail), g.buy(Relic.grail)), (null, 36000, true));
    expect(g.storeBought, {Item.gloves: 3, Relic.fang: 2, Relic.grail: 2});
    expect(g.sfx, contains(Sfx.kill)); // the coin
  });

  test('buying is refused and changes nothing when the gold is short, before wave 15 is won, or after game over', () {
    for (final (why, g) in [
      (StoreRefusal.gold, openStore(itemPrice.base - 1)),
      (StoreRefusal.locked, bareGame()..wave = storeFrom - 1),
      (StoreRefusal.over, openStore()..lives = 0),
    ]) {
      final gold = g.gold;
      expect((g.whyNotBuy(Item.sword), g.buy(Item.sword)), (why, false), reason: '$why');
      expect((g.gold, g.sfx.last), (gold, Sfx.error), reason: '$why');
      expect(g.inventory, isEmpty, reason: '$why');
      expect(g.storeBought, isEmpty, reason: '$why');
    }
    expect(openStore(itemPrice.base).buy(Item.sword), isTrue); // just enough
  });

  test('selling pays half the base price, only from the bag, and never lowers a price', () {
    final g = openStore(0);
    g.inventory[Item.staff] = 5;
    g.storeBought[Item.staff] = 4; // risen to 2800
    expect(g.sellPrice(Item.staff), 1000);
    expect(g.sell(Item.staff), 1);
    expect((g.gold, g.inventory[Item.staff], g.buyPrice(Item.staff)), (1000, 4, 2800));
    expect(g.sell(Item.staff, 10), 4); // "Jual semua": all there are
    expect((g.gold, g.inventory[Item.staff]), (5000, 0));
    expect((g.whyNotSell(Item.staff), g.sell(Item.staff)), (StoreRefusal.none, 0));
    expect(g.gold, 5000);

    // A relic held by a troop isn't in the bag, so it isn't sold; an item given to a type isn't either.
    final k = placeNow(g, 'knight', 2, 3);
    g
      ..relicBag[Relic.fang] = 2
      ..givePusaka(Relic.voidEye) // in the Gudang
      ..givePusaka(Relic.grail, type: 'knight');
    expect(g.useRelic(Relic.fang, k), isTrue);
    g.inventory[Item.sword] = 1;
    expect(g.useItem(Item.sword, 'knight'), isTrue);
    g.gold = 0;
    expect((g.sell(Relic.fang, 5), g.gold, k.relics.firstOrNull), (1, 4000, Relic.fang));
    expect(g.sell(Item.sword), 0);
    expect(g.upgrades['knight'], [Item.sword]);
    expect((g.sell(Relic.voidEye), g.gold, g.pusaka.containsKey(Relic.voidEye)), (1, 4000 + 18000, false)); // half its 36000
    expect((g.whyNotSell(Relic.grail), g.sell(Relic.grail), g.pusakaOf('knight')), (StoreRefusal.bound, 0, Relic.grail)); // bound
    expect([for (final r in artefacts) g.sellPrice(r)], [15000, 20000, 20000, 12000, 18000]);
  });

  test('monsters never drop an artefact: a relic roll picks from the four dropped ones', () {
    expect(droppedRelics, [Relic.fang, Relic.thorns, Relic.fury, Relic.guard]);
    expect(artefacts, [Relic.dragonHeart, Relic.dawnStar, Relic.godThunder, Relic.grail, Relic.voidEye]);
    for (var pick = 0; pick < Relic.values.length; pick++) {
      final g = bareGame()..skills = false;
      final k = placeNow(g, 'knight', 2, 3);
      g.loot = _Dice(0, pick); // every roll drops
      final m = foeAt(g, 'orc', k.pos + const Point(14, 0), Tier.highElite)..hp = 1;
      g.tick(0.05);
      expect(m.alive, isFalse);
      expect(g.relicDrops.single.$2, droppedRelics[pick % droppedRelics.length], reason: '$pick');
    }
  });

  test('a Pusaka bought waits in the Gudang at ★1 and never goes on one troop', () {
    final g = openStore()..skills = false;
    final k = placeNow(g, 'knight', 2, 3)..cd = hold;
    expect(g.buy(Relic.dawnStar), isTrue);
    expect(g.gudang, [Relic.dawnStar]);
    expect((g.pusaka[Relic.dawnStar]!.stars, g.pusaka[Relic.dawnStar]!.binds), (1, 0));
    expect((g.useRelic(Relic.dawnStar, k), k.relics.isEmpty, g.relicRefusal(Relic.dawnStar, k)), (false, true, pusakaOnType));
    expect(g.bindPusaka(Relic.dawnStar, 'knight'), isTrue); // its first binding: free
    expect(g.impacts.last, (k.pos, awakeFx('upgrade', maxAwaken))); // a Pusaka's burst is gold
  });

  test('the save keeps what the store sold and the Pusaka; saves from before the store have none', () {
    final g = openStore(5000)..capacity = 20;
    final t = placeNow(g, 'knight_templar', 2, 3);
    g
      ..storeBought.addAll({Item.gloves: 2, Relic.fury: 1, Relic.grail: 1})
      ..relicBag[Relic.fang] = 0
      ..givePusaka(Relic.voidEye)
      ..givePusaka(Relic.dragonHeart, type: 'knight_templar', stars: 3);
    t.hp = 500;
    final j = jsonDecode(jsonEncode(g.toJson())) as Map<String, dynamic>;
    expect(j['storeBought'], {'gloves': 2, 'fury': 1, 'grail': 1});
    final h = Game.fromJson(j);
    expect(h.storeBought, {Item.gloves: 2, Relic.fury: 1, Relic.grail: 1});
    expect((h.buyPrice(Item.gloves), h.buyPrice(Relic.grail)), (2400, 36000));
    expect(h.relicBag, {Relic.fang: 0});
    expect((h.gudang.single, h.pusakaOf('knight_templar'), h.pusaka[Relic.dragonHeart]!.stars), (Relic.voidEye, Relic.dragonHeart, 3));
    final back = h.troops.single;
    expect((back.relics.isEmpty, back.maxHp, back.hp), (true, (troopTypes['knight_templar']!.hp * (1 + heavyBuff)).round() * 3, 500.0));
    expect(h.storeOpen, isTrue);

    final old = j
      ..remove('storeBought')
      ..['wave'] = 4;
    final o = Game.fromJson(old);
    expect(o.storeBought, isEmpty);
    expect(o.storeOpen, isFalse);
  });

  test('the words: every relic has a name, and the Pusaka\'s lines come from their numbers at their stars', () {
    expect(relicNames.keys, Relic.values);
    final g = openStore();
    expect({for (final r in artefacts) relicNames[r]: g.relicEffect(r)}, {
      'Dragon Heart': ['+60% max HP', 'Heals 1% max HP every second'],
      'Dawn Star': ['+30% attack or heal'],
      "God's Thunder": ['Each hit also hits 2 more monsters', 'within 3 tiles, for 40% damage'],
      'Grail of Immortality': ['Once a wave: survive 1 deadly hit', 'Left at 30% HP, no damage for 2s'],
      'Void Eye': ['Marks monsters it hits for 5s', 'Marked: +25% damage taken (boss +15%)'],
    });
    for (final r in artefacts) {
      g.givePusaka(r, stars: 2);
    }
    expect([for (final r in artefacts) g.relicEffect(r).first],
        ['+120% max HP', '+45% attack or heal', 'Each hit also hits 3 more monsters', 'Once a wave: survive 1 deadly hit', 'Marks monsters it hits for 5s']);
    for (final r in artefacts) {
      g.givePusaka(r, stars: 3);
    }
    expect({for (final r in artefacts) relicNames[r]: g.relicEffect(r).last}, {
      'Dragon Heart': 'Heals 1% max HP every second',
      'Dawn Star': '+60% attack or heal',
      "God's Thunder": 'within 3 tiles, for 40% damage',
      'Grail of Immortality': 'Left at 50% HP, no damage for 2s',
      'Void Eye': 'Marked: +45% damage taken (boss +25%)',
    });
    expect(g.relicEffect(Relic.dragonHeart).first, '+200% max HP');
    expect(g.relicInfo(Relic.grail).$2.skip(2), [pusakaLine, 'In Vault ★3']);
    g.givePusaka(Relic.grail, type: 'knight', stars: 1);
    expect(g.relicInfo(Relic.grail).$2.last, 'On: ${troopTypeNames['knight']} ★1 (asleep)'); // no knight alive
    placeNow(g, 'knight', 2, 3);
    expect(g.pusakaWhere(Relic.grail), 'On: ${troopTypeNames['knight']} ★1');
    expect(openStore().pusakaWhere(Relic.grail), 'Not owned yet');
    expect(g.relicInfo(Relic.fang).$2, ['Heals 30% of damage dealt', relicSlotsLine, tapLine, 'In bag: 0, in use: 0']);
    expect(g.relicInfo(Relic.fang).$2, isNot(contains(pusakaLine)));
    expect(g.itemInfo(Item.sword).$2, [...g.itemEffect(Item.sword), tapLine, 'In bag: 0']);
    expect(storeRefusalNames.keys, StoreRefusal.values);
    expect([for (final n in [1000, 9999, 12000, 22500, 33700, 150000]) shortPrice(n)], ['1000', '9999', '12k', '22.5k', '33.7k', '150k']);
  });
}
