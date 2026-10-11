// Peti Bos, the boss's chest (decisions-log 152, lib/draft.dart): a chest only on a won boss wave with the chest on
// ([Game.offers]); three different cards on the draft dice, the run's first chest three Epik, the pity, no Legenda before
// wave legendFrom (from it: legenda_test.dart), Serpihan when the pool runs dry, a duplicate's star and no ★3 card;
// Ambil, Kocok ulang (700 / 2.5k / 38k, doubling, back for the next chest) and Lewati; the Toko's closed shelf and the boss's relic drawn and thrown away (the loot dice
// stay aligned); an old save's catch-up chests (the owner's wave-86 save gets 3); the save, the probes' policy and
// determinism; the four Langka Pusaka at each star; the telemetry. The popup: draft_hud_test.dart. docs/loot-items-
// relics.md, "Peti Bos".
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';
import 'package:tower_defense/telemetry.dart';

import 'hero_skill_helpers.dart';

/// Draft dice that roll every rarity at [roll] (0: Langka, 0.6: Epik, 0.99: Legenda) and take the [pick]th card of a
/// pool (wrapping).
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

/// Dice that count their draws.
class _Counted implements Random {
  _Counted(this.inner);
  final Random inner;
  int draws = 0;

  @override
  double nextDouble() {
    draws++;
    return inner.nextDouble();
  }

  @override
  int nextInt(int max) {
    draws++;
    return inner.nextInt(max);
  }

  @override
  bool nextBool() {
    draws++;
    return inner.nextBool();
  }
}

/// A sink that keeps the records, through JSON.
class _Kept implements TelemetrySink {
  final records = <Map<String, dynamic>>[];

  @override
  void add(Map<String, Object?> record) => records.add(jsonDecode(jsonEncode(record)) as Map<String, dynamic>);

  @override
  Future<void> flush() async {}
}

/// A game with no skills cast, so what happens is the chest's and the Pusaka's doing.
Game plain([Random? rng]) => bareGame(rng)
  ..skills = false
  ..heroSkills = false
  ..awakenSkills = false;

/// [plain] with the chest on, between waves at [wave] (the next is a boss wave from 4), on [draft] dice.
Game chested({int wave = 4, Random? draft}) => plain(Random(1))
  ..offers = true
  ..wave = wave
  ..draft = draft ?? Random(7);

/// Wins the next wave of [g] at once: begun with nothing to spawn, its one monster gone in the tick.
void win(Game g) {
  g
    ..startWave()
    ..queue.clear()
    ..units.add(g.monster('slime', Tier.normal, const Point(300, 60))..gone = true)
    ..tick(0.05);
  expect((g.waveActive, g.over, g.victoryAt), (false, false, g.t));
}

/// Lets [foe] strike once now (then it stands again).
void strikeBy(Game g, Unit foe) {
  foe
    ..busyUntil = double.negativeInfinity
    ..cd = 0;
  g.tick(0.05);
  foe.busyUntil = hold;
}

/// The owner's wave-86 save from before the Pusaka and the chest (army-cap's and pusaka_test's fixture).
Map<String, dynamic> w86() => jsonDecode(File('test/fixtures/save-20261001-2005-pre-awaken.json').readAsStringSync()) as Map<String, dynamic>;

/// [g] through a save without the `chests` key: a save from before the chest.
Game legacy(Game g) => Game.fromJson(jsonDecode(jsonEncode(g.toJson()..remove('chests'))) as Map<String, dynamic>);

final pusakas = [for (final r in Relic.values) if (r.pusaka) r];
final langka = [for (final r in pusakas) if (r.rarity == Rarity.langka) r];
final epik = [for (final r in pusakas) if (r.rarity == Rarity.epik) r];

List<Rarity?> rarities(Chest c) => [for (final r in c.cards!) r?.rarity];

void main() {
  test('the chest is off in a plain Game() and on with the board rules; it comes on won boss waves only, rolled at once', () {
    expect((Game().offers, Game().draftPolicy, Game().boardRules().offers), (false, null, true));
    final off = plain()..wave = 4;
    win(off);
    expect(off.wave, 5);
    expect(off.chests, isEmpty);
    final g = chested(wave: 3);
    win(g);
    expect(g.wave, 4);
    expect(g.chests, isEmpty, reason: 'not a boss wave');
    win(g);
    expect((g.wave, g.chests.length, g.chestsGiven), (5, 1, 1));
    final c = g.chest!;
    expect((c.kind, c.wave, c.title, c.cards!.length, c.cards!.toSet().length), (ChestKind.boss, 5, 'Boss Chest', draftCards, 3));
    expect([draftCards, catchUpMax, legendPity], [3, 3, 6]); // offerQueueMax went with Later (decisions-log 281)
    // A lost boss wave brings none: its last troop falls.
    final lost = chested(wave: 9);
    final k = placeNow(lost, 'knight', 2, 3)..busyUntil = hold;
    lost
      ..startWave()
      ..queue.clear();
    final orc = foeAt(lost, 'orc', k.pos + const Point(12, 0));
    k.hp = 1;
    strikeBy(lost, orc);
    lost.tick(0.05);
    expect((lost.wave, lost.over), (10, true));
    expect(lost.chests, isEmpty);
    expect(chestOdds.rare + chestOdds.epic + chestOdds.legend, closeTo(1, 1e-12));
  });

  test("the run's first chest is three different Epik; then a card's rarity is rolled (Langka 55%, Epik 37%, Legenda 8%)", () {
    final g = chested(draft: _Dice(0)); // every roll Langka
    g.giveChests(2);
    expect((g.chests[0].epik, g.chests[0].cards!.toSet().length), (true, 3));
    expect(rarities(g.chests[0]), everyElement(Rarity.epik));
    expect(g.chests[1].epik, isFalse);
    expect(rarities(g.chests[1]), everyElement(Rarity.langka));
    expect(g.chests[1].cards!.toSet().length, 3);
    final h = chested(draft: _Dice(chestOdds.rare + 0.01))..chestsGiven = 1;
    h.giveChests(1);
    expect(rarities(h.chest!), everyElement(Rarity.epik));
  });

  test('the draft dice decide: different dice, different first Epik; the same dice, the same cards', () {
    List<Relic?> first(int seed) => (chested(draft: Random(seed))..giveChests(1)).chest!.cards!;
    String picks(int seed) => (first(seed).map((r) => r!.name).toList()..sort()).join(',');
    expect({for (var seed = 1; seed <= 6; seed++) picks(seed)}.length, greaterThan(1));
    expect(first(3), first(3));
  });

  test('before wave legendFrom a Legenda roll steps down to Epik (the Legenda themselves: legenda_test.dart)', () {
    // Today's Pusaka of each rarity are among them (the catalog adds more: pusaka_catalog_test.dart checks every row).
    expect(pusakas.where((r) => r.rarity == Rarity.legenda), containsAllInOrder([Relic.dragonCrown, Relic.oathOfOne, Relic.alliance]));
    expect(langka, containsAllInOrder([Relic.ironBanner, Relic.bloodFang, Relic.warDrum, Relic.mourningBell]));
    expect(epik, containsAllInOrder([Relic.dragonHeart, Relic.dawnStar, Relic.godThunder, Relic.grail, Relic.voidEye]));
    final g = chested(wave: legendFrom - 1, draft: _Dice(0.99))..chestsGiven = 1;
    g.giveChests(1);
    expect(rarities(g.chest!), everyElement(Rarity.epik));
    // With no Epik left a Langka; with no Langka left either, the rarity above (step down, then up).
    for (final r in epik) {
      g.givePusaka(r, stars: starMax);
    }
    g.giveChests(1);
    expect(rarities(g.chests.last), everyElement(Rarity.langka));
  });

  test('the pity: the 6th chest in a row with no Epik or better gets one in its first card; a reroll counts for nothing', () {
    final g = chested(draft: _Dice(0));
    g.giveChests(1); // the first: Epik, not dry
    expect(g.draftDry, 0);
    for (var n = 1; n <= legendPity - 1; n++) {
      g.giveChests(1);
      expect(g.draftDry, n, reason: 'dry chest $n');
      expect(rarities(g.chests.last), everyElement(Rarity.langka), reason: 'dry chest $n');
    }
    g.rerollChest(); // the open chest's reroll is no new chest
    expect(g.draftDry, legendPity - 1);
    g.giveChests(1);
    expect(rarities(g.chests.last), [Rarity.epik, Rarity.langka, Rarity.langka]);
    expect(g.draftDry, 0);
    g.giveChests(1);
    expect(g.draftDry, 1);
    expect(rarities(g.chests.last), everyElement(Rarity.langka));
  });

  test('with too few cards left a gap is a Serpihan: taking it keeps a free reroll', () {
    final g = chested()..chestsGiven = 1;
    for (final r in pusakas.skip(2)) {
      g.givePusaka(r, stars: starMax); // ★3: never offered
    }
    g.giveChests(1);
    expect(g.chest!.cards!.where((r) => r == null).length, 1);
    expect(g.chest!.cards!.whereType<Relic>().toSet(), pusakas.take(2).toSet());
    for (final r in pusakas.take(2)) {
      g.givePusaka(r, stars: starMax);
    }
    g.giveChests(1);
    expect(g.chests.last.cards, [null, null, null]);
    g.chests.removeAt(0);
    final gold = g.gold;
    expect((g.takeCard(1), g.serpihan), (true, 1));
    expect(g.chests, isEmpty);
    g.giveChests(1);
    expect((g.rerollCost(g.chest!), g.whyNotReroll), (0, null));
    expect((g.rerollChest(), g.serpihan, g.gold, g.chest!.rerolls), (true, 0, gold, 1)); // paid with the Serpihan
    expect(g.rerollCost(g.chest!), rerollPrice(g.wave) * 2);
  });

  test('a card for a Pusaka owned adds a star where it is bound; a new one is bound by the default rule, its first move free', () {
    final g = chested()..chestsGiven = 1;
    final k = placeNow(g, 'knight', 2, 3);
    placeNow(g, 'swordsman', 2, 5);
    g.givePusaka(Relic.ironBanner, type: 'knight');
    final events = <GameEvent>[];
    g.listeners.add(events.add);
    g.chests.add(Chest(ChestKind.boss, 5, cards: [Relic.ironBanner, Relic.bloodFang, Relic.mourningBell]));
    expect((g.cardType(Relic.ironBanner), g.cardStars(Relic.ironBanner)), ('knight', 2));
    expect((g.cardType(Relic.bloodFang), g.cardStars(Relic.bloodFang)), ('swordsman', 1));
    expect(g.takeCard(0), isTrue);
    expect((g.pusaka[Relic.ironBanner]!.stars, g.pusakaOf('knight')), (2, Relic.ironBanner));
    final pick = events.whereType<OfferPicked>().single;
    expect((pick.pick, pick.stars, pick.type, pick.skipped, pick.chest, pick.chestWave), (Relic.ironBanner, 2, 'knight', false, 'boss', 5));
    expect(g.impacts.where((i) => i.$1 == k.pos), isNotEmpty); // the gold burst
    expect(g.log.entries.last, pick); // in the battle log

    g.chests.add(Chest(ChestKind.boss, 5, cards: [Relic.bloodFang, Relic.mourningBell, Relic.warDrum]));
    expect(g.takeCard(0), isTrue);
    final fang = g.pusaka[Relic.bloodFang]!;
    expect((fang.type, fang.stars, fang.binds, g.bindPrice(Relic.bloodFang)), ('swordsman', 1, 0, 0)); // its first move is still free
    expect(events.whereType<PusakaBound>().last.cost, 0);
    expect(g.cardType(Relic.mourningBell), isNull, reason: 'its living types hold one each: the knight, the swordsman');
    g.chests.add(Chest(ChestKind.boss, 5, cards: [Relic.mourningBell, Relic.warDrum, Relic.grail]));
    expect(g.takeCard(0), isTrue);
    expect(g.pusaka[Relic.mourningBell]!.type, isNull);
    expect(g.gudang, [Relic.mourningBell]); // into the Gudang
  });

  test('no ★3 Pusaka is offered; a card that reached ★3 since its chest was rolled is a Serpihan when opened', () {
    final g = chested(draft: _Dice(0))..chestsGiven = 1;
    g.givePusaka(Relic.ironBanner, stars: starMax);
    for (var n = 0; n < 8; n++) {
      g
        ..draft = _Dice(0, n)
        ..giveChests(1);
      expect(g.chests.last.cards, isNot(contains(Relic.ironBanner)));
    }
    g.chests
      ..clear()
      ..add(Chest(ChestKind.boss, 5, cards: [Relic.bloodFang, Relic.warDrum, Relic.grail]));
    g.givePusaka(Relic.warDrum, stars: starMax);
    expect(g.openChest(), [Relic.bloodFang, null, Relic.grail]);
  });

  test('Kocok ulang: 700 on wave 5, 2.5k on 30, 38k on 86, doubling for each reroll of one chest, back for the next', () {
    for (final (wave, price) in [(5, 700), (30, 2500), (86, 38000)]) {
      final g = chested(wave: wave)
        ..chestsGiven = 1
        ..gold = 1000000
        ..giveChests(2);
      final events = <GameEvent>[];
      g.listeners.add(events.add);
      final first = [...g.chest!.cards!];
      for (var n = 0; n < 3; n++) {
        expect(g.rerollCost(g.chest!), price * pow(2, n), reason: 'wave $wave reroll $n');
        final gold = g.gold;
        expect(g.rerollChest(), isTrue);
        expect(g.gold, gold - price * pow(2, n));
      }
      expect(g.chest!.rerolls, 3);
      expect(events.whereType<OfferRerolled>().map((e) => e.price), [price, price * 2, price * 4]);
      expect(events.whereType<OfferShown>().map((e) => e.reroll), [1, 2, 3]);
      expect(g.chest!.cards, isNot(first), reason: 'new cards (wave $wave)');
      expect(g.takeCard(0), isTrue);
      expect(g.rerollCost(g.chest!), price, reason: 'the next chest starts again');
      expect(g.skipGold, price);
    }
    final poor = chested(wave: 30)
      ..chestsGiven = 1
      ..giveChests(1)
      ..gold = 2499;
    expect((poor.whyNotReroll, poor.rerollChest(), poor.gold, poor.chest!.rerolls), (chestRefusals.gold, false, 2499, 0));
  });

  test("Lewati: no card, one reroll price's gold; nothing is dealt with mid-wave", () {
    final g = chested(wave: 30)
      ..chestsGiven = 1
      ..giveChests(2);
    final events = <GameEvent>[];
    g.listeners.add(events.add);
    final gold = g.gold;
    expect((g.skipChest(), g.gold, g.chests.length), (2500, gold + 2500, 1));
    expect(g.pusaka, isEmpty);
    final skip = events.whereType<OfferPicked>().single;
    expect((skip.skipped, skip.gain, skip.pick), (true, 2500, null));
    g
      ..startWave()
      ..queue.clear()
      ..units.add(g.monster('slime', Tier.normal, const Point(300, 60)));
    expect((g.whyNotChest, g.openChest(), g.takeCard(0), g.skipChest(), g.rerollChest()), (chestRefusals.midWave, null, false, null, false));
    expect(g.chests.length, 1);
  });

  test('with the chest on the Toko sells no Pusaka; its items and small relics stay; it never sells a Langka', () {
    expect(artefactShelf, isFalse);
    final g = bareGame()
      ..wave = storeFrom
      ..gold = 1000000;
    expect((g.shelfOpen, g.whyNotBuy(Relic.grail), g.whyNotBuy(Relic.ironBanner)), (true, null, StoreRefusal.shelf));
    expect(storeGoods.where((k) => langka.contains(k)), isEmpty);
    g.offers = true;
    expect((g.shelfOpen, g.whyNotBuy(Relic.grail), g.whyNotBuy(Item.sword), g.whyNotBuy(Relic.fang)), (false, StoreRefusal.shelf, null, null));
    expect((g.buy(Relic.grail), g.gold), (false, 1000000));
    expect(g.pusaka, isEmpty);
    expect(storeRefusalNames[StoreRefusal.shelf], 'Boss Chest only');
    g.givePusaka(Relic.ironBanner); // in the Gudang: sold back for half its worth
    expect((g.sellPrice(Relic.ironBanner), g.sell(Relic.ironBanner), g.gold), (langkaPrice ~/ 2, 1, 1000000 + langkaPrice ~/ 2));
  });

  test("with the chest on, the boss's small relic is drawn and thrown away: the loot dice draw the same", () {
    (int, List<(Point<double>, Relic)>) bossFalls(bool offers) {
      final g = plain(Random(3))
        ..offers = offers
        ..wave = 4;
      final dice = _Counted(Random(11));
      g
        ..loot = dice
        ..startWave()
        ..queue.clear();
      final k = placeNow(g, 'knight', 2, 3);
      final b = foeAt(g, boss, k.pos + const Point(14, 0), Tier.boss)..hp = 1;
      for (var n = 0; n < 100 && b.alive; n++) {
        g.tick(0.05);
      }
      expect(b.alive, isFalse);
      return (dice.draws, [...g.relicDrops]);
    }

    final (offDraws, _) = bossFalls(false);
    final (onDraws, onRelics) = bossFalls(true);
    expect(onDraws, offDraws);
    expect(onRelics, isEmpty);
    expect(chestTakesBossRelic, isTrue);
    // Dice that always drop: the boss's relic goes, a high elite's stays.
    final g = plain(Random(3))
      ..loot = _Dice(0)
      ..wave = 4
      ..offers = true;
    g
      ..startWave()
      ..queue.clear();
    final k = placeNow(g, 'knight', 2, 3);
    final b = foeAt(g, boss, k.pos + const Point(14, 0), Tier.boss)..hp = 1;
    final orc = foeAt(g, 'orc', k.pos + const Point(14, 8), Tier.highElite)..hp = 1;
    for (var n = 0; n < 200 && (b.alive || orc.alive); n++) {
      g.tick(0.05);
    }
    expect((b.alive, orc.alive), (false, false));
    expect(g.relicDrops.length, 1, reason: "a high elite's relic stays: only the boss's goes");
  });

  test("an old save gets its catch-up chests: one per 3 boss waves won, at most 3, rolled when opened; the owner's w86 save 3", () {
    for (final (wave, n) in [(14, 0), (15, 1), (44, 2), (45, 3), (90, 3)]) {
      expect(legacy(Game()..wave = wave).chests.length, n, reason: 'wave $wave');
    }
    final g = Game.fromJson(w86(), Random(1), Random(2), Random(3))..draft = Random(9);
    expect(g.chests.map((c) => (c.kind, c.wave, c.cards, c.epik, c.title)), [
      (ChestKind.catchUp, 86, null, true, 'Missed Chest 1/3'),
      (ChestKind.catchUp, 86, null, false, 'Missed Chest 2/3'),
      (ChestKind.catchUp, 86, null, false, 'Missed Chest 3/3'),
    ]);
    expect(g.chestsGiven, 3);
    final again = Game.fromJson(jsonDecode(jsonEncode(g.toJson())) as Map<String, dynamic>);
    expect(again.chests.length, 3, reason: 'saved as they are: no more catch-up');
    final cards = g.openChest()!;
    final epikOpen = epik.where((r) => (g.pusaka[r]?.stars ?? 0) < starMax).length;
    expect(cards.toSet().length, 3);
    expect(cards.where((r) => r?.rarity == Rarity.epik).length, min(3, epikOpen));
    expect(Game().boardRules().chests, isEmpty, reason: 'a new game has none');
    expect(legacy(Game()..wave = 45).chests.first.epik, isTrue);
    expect(legacy(Game()..wave = 45..chestsGiven = 1).chests.first.epik, isFalse);
  });

  test('the save keeps the chests, their cards and rerolls, the pity, the chests given and the Serpihan', () {
    final g = chested()
      ..giveChests(2)
      ..serpihan = 2
      ..draftDry = 4;
    g.chests.first.rerolls = 2;
    g.chests.last.cards = [Relic.warDrum, null, Relic.grail];
    final j = jsonDecode(jsonEncode(g.toJson())) as Map<String, dynamic>;
    expect((j['serpihan'], j['draftDry'], j['chestsGiven']), (2, 4, 2));
    expect((j['chests'] as List).last, {'kind': 'boss', 'wave': 4, 'cards': ['warDrum', 'serpihan', 'grail']});
    final back = Game.fromJson(j);
    expect(jsonEncode(back.toJson()), jsonEncode(g.toJson()));
    expect((back.chests.first.rerolls, back.chests.first.epik), (2, true));
    expect(back.chests.last.cards, [Relic.warDrum, null, Relic.grail]);
    final odd = Game.fromJson(j..['chests'] = [{'kind': 'boss', 'wave': 5, 'cards': ['grail', 'noSuchRelic', 'fang']}]);
    expect(odd.chests.single.cards, [Relic.grail, null, null], reason: 'an unknown card, or a small relic, is a Serpihan');
    expect(bareGame().toJson()['chests'], isEmpty, reason: 'always written: its absence marks a save from before the chest');
  });

  test("draftPolicy (the probes'): 'rarity' takes the highest rarity, then the type with the most troops; 'first' the first", () {
    final g = chested()..draftPolicy = 'rarity';
    placeNow(g, 'knight', 2, 3);
    for (final r in [3, 5, 7]) {
      placeNow(g, 'swordsman', 3, r);
    }
    expect(g.policyPick([Relic.ironBanner, Relic.grail, null]), 1);
    expect(g.policyPick([null, Relic.ironBanner, Relic.bloodFang]), 2); // the knight's 1 against the swordsmen's 3
    expect(g.policyPick([Relic.bloodFang, Relic.ironBanner, null]), 0);
    g.draftPolicy = 'first';
    expect(g.policyPick([null, Relic.grail, Relic.ironBanner]), 0);
    g.draftPolicy = 'best';
    expect(() => g.policyPick([null]), throwsArgumentError);
    // With a policy the boss's chest is taken at once, and chests still waiting at the next wave's start.
    final h = chested()..draftPolicy = 'rarity';
    placeNow(h, 'knight', 2, 3);
    win(h);
    expect(h.chests, isEmpty);
    expect((h.pusaka.length, h.pusaka.keys.single.rarity), (1, Rarity.epik));
    final old = legacy(Game()..wave = 45)
      ..offers = true
      ..draftPolicy = 'first';
    expect(old.pickChests(), 3);
    expect(old.chests, isEmpty);
    expect(old.pusaka.values.fold(0, (n, p) => n + p.stars), 3); // a card each
  });

  test('two runs from the same seeds with the chest on and a draft policy are the same wave by wave', () {
    List<String> run(int seed) {
      const army = ['soldier', 'archer', 'knight', 'priest', 'wizard', 'lancer', 'swordsman'];
      final g = Game(Random(seed), Random(seed + 100))
        ..loot = Random(seed + 200)
        ..heroes = Random(seed + 300)
        ..slots = Random(seed + 400)
        ..draft = Random(seed + 500)
        ..gold = 3000
        ..capacity = 16
        ..offers = true
        ..draftPolicy = 'rarity';
      final out = <String>[];
      for (var w = 0; w < 10 && !g.over; w++) {
        for (final t in army) {
          if (g.gold >= g.priceOf(t)) g.autoPlace(t);
        }
        for (var i = 0; i < 300; i++) {
          g.tick(1 / 30);
        }
        g.startWave();
        for (var i = 0; i < 30 * 600 && g.waveActive && !g.over; i++) {
          g.tick(1 / 30);
        }
        out.add([
          'wave ${g.wave} t ${g.t} gold ${g.gold} lives ${g.lives} kills ${g.kills} over ${g.over}',
          for (final u in g.units) '${u.side.name} ${u.type} ${u.alive} hp ${u.hp}/${u.maxHp} at ${u.pos.x},${u.pos.y}',
          '${{for (final MapEntry(key: r, value: p) in g.pusaka.entries) r.name: '${p.type} ${p.stars}'}}',
          'chests ${g.chests.length} given ${g.chestsGiven} dry ${g.draftDry} serpihan ${g.serpihan}',
        ].join('\n'));
      }
      return out;
    }

    final a = run(4), b = run(4);
    expect(a.length, 10);
    for (var w = 0; w < a.length; w++) {
      expect(b[w], a[w], reason: 'wave ${w + 1}');
    }
    expect(a.last, contains('given 2'));
  });

  group('the four Langka Pusaka, type-wide', () {
    for (final stars in [1, 2, 3]) {
      final i = stars - 1;

      test('Iron Banner ★$stars: the type takes ${ironBannerK[i]} less damage, after its defence', () {
        double loss(bool banner) {
          final g = plain(Random(2));
          final k = placeNow(g, 'knight', 2, 3)..busyUntil = hold;
          if (banner) g.givePusaka(Relic.ironBanner, type: 'knight', stars: stars);
          final orc = foeAt(g, 'orc', k.pos + const Point(12, 0));
          final hp = k.hp;
          strikeBy(g, orc);
          if (banner) expect(g.pusakaWorth[Relic.ironBanner]!.worth, closeTo((hp - k.hp) / (1 - ironBannerK[i]) * ironBannerK[i], 1e-6));
          return hp - k.hp;
        }

        final base = loss(false);
        expect(base, greaterThan(0));
        expect(loss(true), closeTo(base * (1 - ironBannerK[i]), 1e-9));
      });

      test('Blood Fang ★$stars: the type heals ${bloodFangK[i]} of the damage it deals', () {
        double hpAfter(bool fang) {
          final g = plain(Random(2));
          final k = placeNow(g, 'knight', 2, 3)..hp = 10;
          if (fang) g.givePusaka(Relic.bloodFang, type: 'knight', stars: stars);
          k.hp = 10;
          foeAt(g, 'orc', k.pos + const Point(14, 0)).hp = 100000;
          g.tick(0.05);
          if (fang) expect(g.pusakaWorth[Relic.bloodFang]!.worth, closeTo(20 * bloodFangK[i], 1e-9));
          return k.hp;
        }

        expect(hpAfter(true) - hpAfter(false), closeTo(20 * bloodFangK[i], 1e-9)); // its blow: 20
      });

      test('War Drum ★$stars: every 3rd attack of the type does x${warDrumK.hit[i]}; with a worn fury both', () {
        final g = plain();
        final k = placeNow(g, 'knight', 2, 3), o = placeNow(g, 'knight', 2, 5);
        g.givePusaka(Relic.warDrum, type: 'knight', stars: stars);
        final orc = foeAt(g, 'orc', k.pos + const Point(14, 0))..hp = 100000;
        o.cd = hold;
        final hits = <double>[];
        for (var n = 0; n < 6; n++) {
          final before = orc.hp;
          k.cd = 0;
          g.tick(0.05);
          hits.add(before - orc.hp);
        }
        final drum = 20 * warDrumK.hit[i];
        expect(hits, [20, 20, closeTo(drum, 1e-9), 20, 20, closeTo(drum, 1e-9)]);
        expect(g.pusakaWorth[Relic.warDrum]!.uses, 2);
        expect(g.pusakaWorth[Relic.warDrum]!.worth, closeTo(2 * (drum - 20), 1e-9));
        expect(g.useRelic(Relic.fury, k), isFalse, reason: 'none in the bag');
        g.relicBag[Relic.fury] = 1;
        expect(g.useRelic(Relic.fury, k), isTrue);
        k.blows = 0;
        hits.clear();
        for (var n = 0; n < 3; n++) {
          final before = orc.hp;
          k.cd = 0;
          g.tick(0.05);
          hits.add(before - orc.hp);
        }
        expect(hits.last, closeTo(20 * furyHit * warDrumK.hit[i], 1e-9));
      });

      test('Mourning Bell ★$stars: when one of the type falls, every troop within 2 tiles heals ${mourningBellK.heal[i]} of its max HP', () {
        final g = plain();
        final s = placeNow(g, 'soldier', 2, 3), mate = placeNow(g, 'soldier', 2, 4), knight = placeNow(g, 'knight', 3, 3);
        final far = placeNow(g, 'soldier', 2, 7), other = placeNow(g, 'knight', 3, 7);
        for (final u in [s, mate, knight, far, other]) {
          u
            ..busyUntil = hold
            ..hp = 1;
        }
        g.givePusaka(Relic.mourningBell, type: 'soldier', stars: stars);
        final orc = foeAt(g, 'orc', s.pos + const Point(-12, 0));
        strikeBy(g, orc);
        expect(s.alive, isFalse);
        expect(mate.hp, closeTo(1 + mate.maxHp * mourningBellK.heal[i], 1e-9));
        expect(knight.hp, closeTo(1 + knight.maxHp * mourningBellK.heal[i], 1e-9), reason: 'every troop near, of any type');
        expect((far.hp, other.hp), (1, 1));
        expect(g.pusakaWorth[Relic.mourningBell]!.uses, 1);
        // A knight falling rings nothing: the bell is the soldiers'.
        orc.pos = other.pos + const Point(12, 0);
        strikeBy(g, orc);
        expect((other.alive, far.hp), (false, 1));
      });
    }

    test("the Langka's lines name what each does at its stars", () {
      final g = Game();
      expect(g.relicEffect(Relic.ironBanner, stars: 3), ['-25% damage taken']);
      expect(g.relicEffect(Relic.bloodFang, stars: 2), ['Heals 15% of damage dealt']);
      expect(g.relicEffect(Relic.warDrum), ['x1.5 damage every 3rd hit']);
      expect(g.relicEffect(Relic.mourningBell, stars: 3), ['When one dies, all troops', 'within 2 tiles heal 30% max HP']);
      // The chest's first four (batch L-1P's ten and the later batches': pusaka_langka1_test.dart).
      final four = langka.take(4).toList();
      expect([for (final r in four) relicNames[r]], ['Iron Banner', 'Blood Fang', 'War Drum', 'Mourning Bell']);
      expect([for (final r in langka) g.basePrice(r)], everyElement(langkaPrice));
      // The Tas page's (pusaka.dart): a row's gist, and what one bound gives its type.
      expect([for (final r in four) pusakaGist(r, 2)],
          ['-20% damage taken', 'Heals 15% of damage', 'x1.75 every 3rd hit', 'Death heals near troops 25%']);
      final h = plain(Random(1));
      placeNow(h, 'knight', 2, 3);
      h.givePusaka(Relic.ironBanner, type: 'knight', stars: 1);
      expect(h.pusakaTotals(Relic.ironBanner), isEmpty, reason: 'its effect line says it all');
    });
  });

  test("the telemetry: the chest's events, and the wave record's gold spent on rerolls and earned from Lewati", () {
    final g = chested(wave: 30)
      ..gold = 100000
      ..chestsGiven = 1;
    final kept = _Kept();
    TelemetryAdapter([kept], installId: 'i', session: 's', platform: 'test', now: () => DateTime.utc(2026, 10, 2)).attach(g);
    g.giveChests(2);
    g.rerollChest();
    g.takeCard(0);
    g.skipChest();
    placeNow(g, 'knight', 2, 3);
    win(g);
    final events = [for (final r in kept.records.where((r) => r['rec'] == 'event')) r['event'] as Map<String, dynamic>];
    expect(events.map((e) => e['kind']).where((k) => '$k'.startsWith('offer')),
        ['offerShown', 'offerShown', 'offerRerolled', 'offerShown', 'offerPicked', 'offerPicked']);
    final shown = events.firstWhere((e) => e['kind'] == 'offerShown');
    expect((shown['v'], shown['chest'], shown['chestWave'], shown['reroll'], (shown['cards'] as List).length), (eventVersion, 'boss', 30, 0, 3));
    expect(eventVersion, greaterThanOrEqualTo(3)); // 3 brought the chest's; Asah's 4 (asah_test.dart)
    final w = kept.records.lastWhere((r) => r['rec'] == 'wave');
    expect(((w['gold'] as Map)['chestSpent'], (w['gold'] as Map)['chestEarned']), (2500, 2500));
    expect(w['tv'], telemetryVersion);
    expect(telemetryVersion, greaterThanOrEqualTo(3));
  });
}
