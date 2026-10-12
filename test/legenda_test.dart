// The three Legenda Pusaka (decisions-log 155, lib/pusaka.dart, docs/loot-items-relics.md "Legenda"): ★1 only, from
// the boss's chest from wave legendFrom, each found once a run, at most one oath. Dragon Crown caps every blow its type
// takes at crownCap of the max HP, with its own check in _hurt that a Grail save's and Bastion's caps still go under;
// Oath of One sets the roster's limit to 2 and waits above it, else every troop's HP and damage x1.5; Alliance sets it
// to 6 and gives +5% for each roster type with a troop alive; the second oath is gone once one is found; a found one is
// never offered again, sold or not; the save round trip. The Tas page and the chest's cards: legenda_ui_test.dart.
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';

import 'hero_skill_helpers.dart';

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

/// A game with no skills cast, so what happens is the Pusaka's doing.
Game plain() => bareGame()
  ..skills = false
  ..heroSkills = false
  ..awakenSkills = false
  ..monsterSkills = false;

/// [plain] with the board's type caps ([typeCapBoard]) and the chest on, between waves at [wave], on [draft] dice; not
/// the run's first chest (that one is three Epik).
Game board({int wave = legendFrom, Random? draft}) => plain()
  ..typeCap = typeCapBoard
  ..offers = true
  ..wave = wave
  ..chestsGiven = 1
  ..draft = draft ?? _Dice(0.99);

/// Lets [foe] strike once now (then it stands again).
void strikeBy(Game g, Unit foe) {
  foe
    ..busyUntil = double.negativeInfinity
    ..cd = 0;
  g.tick(0.05);
  foe.busyUntil = hold;
}

/// [g] through its save and back, as the board loads it.
Game reload(Game g) => Game.fromJson(jsonDecode(jsonEncode(g.toJson())) as Map<String, dynamic>);

const legenda = [Relic.dragonCrown, Relic.oathOfOne, Relic.alliance];

void main() {
  test('the three Legenda: Dragon Crown on a type, the two oaths the whole army\'s, ★1 only; their numbers and icons', () {
    expect([for (final r in Relic.values) if (r.rarity == Rarity.legenda) r], containsAllInOrder(legenda)); // the catalog adds more
    expect([for (final r in legenda) (r.pusaka, r.scope, r.oath, maxStars(r))],
        [(true, RelicScope.type, false, 1), (true, RelicScope.army, true, 1), (true, RelicScope.army, true, 1)]);
    expect((maxStars(Relic.grail), maxStars(Relic.ironBanner), legendStars), (starMax, starMax, 1));
    expect((crownCap, oathOneK.types, oathOneK.k, allianceK.most, allianceK.perType, legendFrom, chestOdds.legend),
        (0.6, 2, 1.5, 6, 0.05, 20, 0.08));
    expect([for (final r in legenda) relicNames[r]], ['Dragon Crown', 'Oath of One', 'Alliance']);
    for (final r in legenda) {
      expect(File('assets/images/relic_${r.name}.png').existsSync(), isTrue, reason: '$r'); // tool/import_fx.py LOOT
    }
    expect(storeGoods.where(legenda.contains), isEmpty, reason: 'the store never sells one');
    expect((buildEpithets[Relic.dragonCrown], buildEpithets[Relic.oathOfOne], buildEpithets[Relic.alliance]), ('Crowned', null, null));
    expect([for (final r in legenda) pusakaGist(r, 1)],
        ['Max 60% HP a hit', '2 types: +50%', '6 types: +5% each']);
  });

  test('Dragon Crown: no blow takes its type\'s troop more than 60% of its max HP; a lighter one lands whole; another '
      'type takes it all; its counter', () {
    final g = plain()..wave = 59;
    final k = placeNow(g, 'knight', 2, 3)..busyUntil = hold, s = placeNow(g, 'knight_templar', 2, 7)..busyUntil = hold;
    g
      ..givePusaka(Relic.dragonCrown, type: 'knight')
      ..startWave()
      ..queue.clear();
    expect((g.pusakaOf('knight'), g.buildNameOf('knight'), g.pusakaWhere(Relic.dragonCrown)),
        (Relic.dragonCrown, '${buildEpithets[Relic.dragonCrown]} ${troopTypeNames['knight']}', 'On: ${troopTypeNames['knight']} ★1'));
    final bear = foeAt(g, 'werebear', k.pos + const Point(12, 0), Tier.miniBoss);
    final blow = hitTaken(bear.stats.dmg, k.stats.def);
    expect(blow, greaterThan(k.maxHp * crownCap), reason: 'a blow that would take more');
    strikeBy(g, bear);
    expect(k.hp, closeTo(k.maxHp * (1 - crownCap), 1e-6));
    expect(g.pusakaWorth[Relic.dragonCrown]!.uses, 1);
    expect(g.pusakaWorth[Relic.dragonCrown]!.worth, closeTo(min(blow, k.maxHp) - k.maxHp * crownCap, 1e-6));
    // From 40% left the next one still kills: the crown caps a blow, it doesn't save a life.
    strikeBy(g, bear);
    expect(k.alive, isFalse);
    // A lighter blow lands whole, and the counter doesn't move.
    final k2 = placeNow(g, 'knight', 3, 3)..busyUntil = hold;
    final orc = foeAt(g, 'orc', k2.pos + const Point(12, 0));
    final light = hitTaken(orc.stats.dmg, k2.stats.def);
    expect(light, lessThan(k2.maxHp * crownCap));
    strikeBy(g, orc);
    expect(k2.hp, closeTo(k2.maxHp - light, 1e-6));
    expect(g.pusakaWorth[Relic.dragonCrown]!.uses, 2); // the killing blow was cut too
    // Another type takes the whole blow.
    bear.pos = s.pos + const Point(12, 0);
    final whole = hitTaken(bear.stats.dmg, s.stats.def);
    s.hp = s.maxHp.toDouble();
    strikeBy(g, bear);
    expect(s.hp, closeTo(s.maxHp - whole, 1e-6));
  });

  test('Dragon Crown coexists with a Grail save\'s and Bastion\'s caps (critique M3): they still go under it, and '
      'Bastion still fires', () {
    // A Grail save's untouchable (Status.cap at 0, as pusaka_engine.dart's _fxLethal adds it) and Bastion's 8% hold on a
    // crowned troop: the crown is its own check after them, never a Status.cap of its own.
    final g = plain()..wave = 59;
    final k = placeNow(g, 'knight', 2, 3)..busyUntil = hold;
    g
      ..givePusaka(Relic.dragonCrown, type: 'knight')
      ..startWave()
      ..queue.clear();
    final bear = foeAt(g, 'werebear', k.pos + const Point(12, 0), Tier.miniBoss);
    g.addEffect(k, Status.cap, grailK.time, k: 0);
    strikeBy(g, bear);
    expect(k.hp, k.maxHp, reason: 'untouchable under the Grail save');
    runFor(g, grailK.time + 0.1); // the save's 2 s are over
    expect(g.under(k, Status.cap), isFalse);
    g.addEffect(k, Status.cap, 5, k: bastionK.cap);
    strikeBy(g, bear);
    expect(k.hp, closeTo(k.maxHp * (1 - bastionK.cap), 1e-6), reason: "Bastion's 8%, under the crown's 60%");
    expect(g.under(k, Status.cap), isTrue);

    // The real Bastion: a templar Hero with Dragon Crown on its type casts it with a mini boss in reach (a crown made of
    // Status.cap would have kept it from ever firing), and its blow then takes 8%.
    final (m, h) = heroCaster(HeroSkill.bastion);
    m
      ..monsterSkills = false
      ..givePusaka(Relic.dragonCrown, type: h.type);
    final big = foeAt(m, 'werebear', h.pos + Point(h.stats.range, 0), Tier.miniBoss);
    m.tick(0.05);
    expect(h.heroSkillAt, m.t, reason: 'a mini boss in reach: Bastion fires');
    expect(m.effectK(h, Status.cap), bastionK.cap);
    h.hp = h.maxHp.toDouble();
    strikeBy(m, big);
    expect(h.hp, closeTo(h.maxHp * (1 - bastionK.cap), 1e-6));

    // A real Grail save on another type, beside the crown: each does its own.
    final grail = plain()..wave = 59;
    final crowned = placeNow(grail, 'knight', 2, 3)..busyUntil = hold, saved = placeNow(grail, 'soldier', 2, 7)..busyUntil = hold;
    grail
      ..givePusaka(Relic.dragonCrown, type: 'knight')
      ..givePusaka(Relic.grail, type: 'soldier')
      ..startWave()
      ..queue.clear();
    final orc = foeAt(grail, 'orc', saved.pos + const Point(12, 0));
    saved.hp = 1;
    strikeBy(grail, orc);
    expect((saved.alive, saved.fxOnce), (true, true));
    expect(saved.hp, closeTo(saved.maxHp * grailK.hpLeft[0], 1e-9));
    final bear2 = foeAt(grail, 'werebear', crowned.pos + const Point(12, 0), Tier.miniBoss);
    strikeBy(grail, bear2);
    expect(crowned.hp, closeTo(crowned.maxHp * (1 - crownCap), 1e-6));
  });

  test('Oath of One: it waits at 3 types alive or more ("Waiting: keep only 2 types"); at 2 or fewer every troop has HP '
      'and damage x1.5 and the type caps are off; with the caps on no third type joins (decisions-log 201)', () {
    final g = board();
    final knights = [placeNow(g, 'knight', 2, 3), placeNow(g, 'knight', 2, 5)];
    final soldiers = [placeNow(g, 'soldier', 3, 3)];
    placeNow(g, 'archer', 3, 5);
    expect(g.typesAlive, 3);
    final base = g.statsOf('knight'), soldier = g.statsOf('soldier');
    expect((g.typeCapOf('knight'), g.oath), (typeCapBoard['knight'], null));
    g.givePusaka(Relic.oathOfOne);
    expect((g.oath, g.pusaka[Relic.oathOfOne]!.type, g.oathWaits, g.oathOneWorks), (Relic.oathOfOne, null, true, false));
    expect((g.statsOf('knight').hp, g.statsOf('knight').dmg), (base.hp, base.dmg), reason: 'it waits: nothing yet');
    expect((g.pusakaWhere(Relic.oathOfOne), oathWaiting, oathWaitingNote), (oathWaiting, 'Waiting: keep only 2 types', 'Oath waits: keep only 2 types'));
    expect(g.pusakaTotals(Relic.oathOfOne), isEmpty, reason: 'its where-line says it waits: not twice');
    // While it waits the caps hold and no new type joins; the types alive still may be bought.
    expect((g.typeCapOf('knight'), g.typeLocked('wizard'), g.typeLocked('knight')), (typeCapBoard['knight'], true, false));
    expect((g.buyRefusal('wizard'), oathOneBar), (oathOneBar, 'Oath of One: only 2 types'));
    expect(g.limitNotes(), isEmpty, reason: 'types the player chose to cut are no old save');
    // Lepas jenis down to 2 types alive: it works.
    g.releaseType('archer');
    expect((g.typesAlive, g.oathWaits, g.oathOneWorks), (2, false, true));
    expect(g.statsOf('knight').hp, (base.hp * oathOneK.k).round());
    expect(g.statsOf('knight').dmg, closeTo(base.dmg * oathOneK.k, 1e-9));
    expect(g.statsOf('knight').def, base.def, reason: 'HP and damage only');
    for (final k in knights) {
      expect((k.maxHp, k.hp), ((base.hp * oathOneK.k).round(), (base.hp * oathOneK.k).round()), reason: 'refit, HP raised with it');
    }
    expect(g.pusakaWhere(Relic.oathOfOne), 'On: all troops ★1');
    expect(g.pusakaTotals(Relic.oathOfOne), ['Now: all troops, +50%']);
    // A third type is refused.
    expect(g.buyRefusal('archer'), oathOneBar);
    expect(g.place('archer', 4, 3), isFalse);
    // The caps are off: its two types may fill the army; a troop bought later has the oath too.
    expect((g.typeCapOf('knight'), g.typeFull('knight')), (null, false));
    for (var i = 0; i < typeCapBoard['knight']!; i++) {
      expect(g.autoPlace('knight'), isTrue, reason: '$i');
    }
    expect((g.aliveOf('knight'), g.buyRefusal('knight')), (12, null));
    expect(g.troops.last.maxHp, (base.hp * oathOneK.k).round());
    expect(g.statsOf('soldier').hp, (soldier.hp * oathOneK.k).round(), reason: 'every type, the book too');
    // A type dying out frees its place: another type may join, and the oath still works.
    for (final u in soldiers) {
      g.units.remove(u);
    }
    expect((g.typesAlive, g.typeLocked('archer')), (1, false));
    expect(g.autoPlace('archer'), isTrue);
    expect((g.typesAlive, g.oathWaits, g.typeLocked('soldier')), (2, false, true));
    // With no board caps (a plain Game) the oath bars nothing.
    final free = plain()..givePusaka(Relic.oathOfOne);
    expect((free.typeCapOf('knight'), free.typeLocked('wizard')), (null, false));
  });

  test('Alliance: every troop has +5% HP and damage for each type with a troop alive, 6 types at most', () {
    final g = board();
    final k = placeNow(g, 'knight', 2, 3);
    final base = g.statsOf('knight');
    double kNow() => g.statsOf('knight').dmg / base.dmg;
    g.givePusaka(Relic.alliance);
    expect((g.oathWaits, g.typesAlive), (false, 1)); // the free priest isn't alive
    expect(kNow(), closeTo(1 + allianceK.perType, 1e-9));
    expect(k.maxHp, (base.hp * (1 + allianceK.perType)).round());
    var row = 0;
    for (final type in ['soldier', 'archer', 'wizard', 'lancer']) {
      placeNow(g, type, 3, row++);
    }
    expect(g.typesAlive, 5);
    expect(kNow(), closeTo(1 + 5 * allianceK.perType, 1e-9));
    expect(k.maxHp, (base.hp * 1.25).round(), reason: 'refit as each type came');
    final priest = placeNow(g, Game.freeHealer, 4, 0);
    expect(g.typesAlive, 6);
    expect(kNow(), closeTo(1.3, 1e-9));
    expect(g.pusakaTotals(Relic.alliance), ['Now: 6 types, +30%']);
    expect(g.pusakaWhere(Relic.alliance), 'On: all troops ★1');
    // A seventh type joins (no type limit) but counts no more.
    expect(g.buyRefusal('swordsman'), isNull);
    final sword = placeNow(g, 'swordsman', 4, 1);
    expect(g.typesAlive, 7);
    expect(kNow(), closeTo(1.3, 1e-9));
    expect(g.pusakaTotals(Relic.alliance), ['Now: 6 types, +30%']);
    // A type dying out takes its 5% away at the next tick (the HP only capped).
    priest.dying = 0; // fallen
    sword.dying = 0;
    g.tick(0.05);
    expect((g.typesAlive, k.maxHp), (5, (base.hp * 1.25).round()));
    expect(k.hp, lessThanOrEqualTo(k.maxHp));
  });

  test('the chest deals the Legenda from wave legendFrom, each once a run; one oath found takes the other off the cards, '
      'and a chest rolled before shows a Serpihan for it', () {
    final early = board(wave: legendFrom - 1)..giveChests(1);
    expect(early.chest!.cards!.map((r) => r!.rarity), everyElement(Rarity.epik), reason: 'before it, Epik');
    final g = board()..giveChests(2); // two rolled now, both with all three
    expect(g.chests[0].cards, legenda);
    expect(g.chests[1].cards, legenda);
    expect((g.cardType(Relic.oathOfOne), g.cardStars(Relic.oathOfOne)), (null, 1));
    expect(g.takeCard(1), isTrue); // Oath of One
    expect((g.oath, g.pusaka[Relic.oathOfOne]!.stars), (Relic.oathOfOne, 1));
    expect(g.legendsFound, {Relic.oathOfOne});
    // The chest put off: Oath of One owned at its top star, Alliance gone with it.
    expect(g.openChest(), [Relic.dragonCrown, null, null]);
    expect(g.takeCard(0), isTrue);
    expect(g.legendsFound, {Relic.oathOfOne, Relic.dragonCrown});
    expect(g.gudang, [Relic.dragonCrown]); // no troop: the Gudang
    // Sold, Dragon Crown stays found: never on a card again; the next Legenda come (batch G-1P's, decisions-log 231).
    g.inTown = true; // the Shop buys only in a Town
    expect((g.sellPrice(Relic.dragonCrown), g.sell(Relic.dragonCrown)), ((legendaPrice * sellShare).round(), 1));
    g.inTown = false;
    expect(g.pusaka.containsKey(Relic.dragonCrown), isFalse);
    g.giveChests(1);
    expect(g.chest!.cards, [Relic.loneWolf, Relic.martyrFlame, Relic.wideBlows]);
    // Every Legenda found, a Legenda roll is an Epik.
    final all = board()..legendsFound.addAll([for (final r in Relic.values) if (r.rarity == Rarity.legenda) r]);
    all.giveChests(1);
    expect(all.chest!.cards!.map((r) => r!.rarity), everyElement(Rarity.epik));
    // The other way round: Alliance found keeps Oath of One off.
    final a = board(draft: _Dice(0.99, 2))..giveChests(1);
    expect(a.chest!.cards, [Relic.alliance, Relic.loneWolf, Relic.martyrFlame]);
    a.takeCard(0);
    a.giveChests(1);
    expect(a.chest!.cards!.where((r) => r?.oath ?? false), isEmpty);
    expect(a.chest!.cards, [Relic.martyrFlame, Relic.wideBlows, Relic.champion]);
  });

  test('an oath binds to no type and never sells; Dragon Crown binds, moves and sells like any Pusaka', () {
    final g = plain()
      ..wave = 30
      ..inTown = true; // where the Shop buys
    placeNow(g, 'knight', 2, 3);
    g
      ..givePusaka(Relic.oathOfOne, type: 'knight') // a type given is ignored: an oath is the army's
      ..givePusaka(Relic.dragonCrown);
    expect(g.pusaka[Relic.oathOfOne]!.type, isNull);
    expect(g.gudang, [Relic.dragonCrown]);
    expect((g.whyNotBind(Relic.oathOfOne, 'knight'), g.bindPusaka(Relic.oathOfOne, 'knight')), (pusakaRefusals.oath, false));
    expect((g.whyNotUnbind(Relic.oathOfOne), g.unbindPusaka(Relic.oathOfOne)), (pusakaRefusals.oath, false));
    expect((g.inBag(Relic.oathOfOne), g.whyNotSell(Relic.oathOfOne), g.sell(Relic.oathOfOne)), (0, StoreRefusal.none, 0));
    expect(g.pusakaPreview(Relic.oathOfOne, 'knight').action, PusakaAction.sumpah);
    expect(g.bindPusaka(Relic.dragonCrown, 'knight'), isTrue);
    expect((g.pusakaOf('knight'), g.bindPrice(Relic.dragonCrown)), (Relic.dragonCrown, rerollPrice(30)));
    expect(g.relicInfo(Relic.oathOfOne).$2, [
      'Oath: only 2 types, no type cap',
      'All troops: +50% HP and attack',
      'Now: all troops, +50%',
      oathLine,
      'On: all troops ★1',
    ]);
  });

  test('the Tas rows for an oath show what it gives each type, without it and with it; a tap only says how it stands', () {
    final g = board();
    placeNow(g, 'knight', 2, 3);
    final without = g.fieldStats('knight');
    g.givePusaka(Relic.oathOfOne); // one type alive: it works
    final p = g.pusakaPreview(Relic.oathOfOne, 'knight');
    expect((p.why, p.action, p.price, p.alive), (null, PusakaAction.sumpah, 0, 1));
    expect(p.stats, contains((StatKind.hp, without.hp, (without.hp * oathOneK.k).round())));
    expect(pusakaActionNames[PusakaAction.sumpah], 'All troops');
    expect(g.fieldStats('knight').hp, (without.hp * oathOneK.k).round(), reason: 'the preview put the oath back');
  });

  test('the save: legendsFound and the oath round trip; an old save without the key finds the Legenda it owns', () {
    final g = board();
    final k = placeNow(g, 'knight', 2, 3);
    g
      ..givePusaka(Relic.oathOfOne)
      ..givePusaka(Relic.dragonCrown, type: 'knight')
      ..legendsFound.add(Relic.alliance); // say, sold or crumbled: found all the same
    final hp = k.maxHp;
    final j = jsonDecode(jsonEncode(g.toJson())) as Map<String, dynamic>;
    expect(j['legendsFound'], unorderedEquals(['oathOfOne', 'dragonCrown', 'alliance']));
    expect(j['pusaka']['oathOfOne'], {'stars': 1}, reason: 'on no type');
    final back = reload(g)..typeCap = typeCapBoard;
    expect(back.legendsFound, {Relic.oathOfOne, Relic.dragonCrown, Relic.alliance});
    expect((back.oath, back.pusaka[Relic.oathOfOne]!.type, back.pusakaOf('knight'), back.oathWaits),
        (Relic.oathOfOne, null, Relic.dragonCrown, false));
    expect(back.troops.single.maxHp, hp, reason: 'the oath works on load');
    expect(jsonEncode(back.toJson()), jsonEncode(g.toJson()));
    // No key (a save from before it): none found but the Legenda owned; an unknown name or a non-Legenda is skipped.
    final old = Map<String, dynamic>.from(j)..remove('legendsFound');
    expect(Game.fromJson(old).legendsFound, {Relic.oathOfOne, Relic.dragonCrown});
    final odd = Map<String, dynamic>.from(j)..['legendsFound'] = ['alliance', 'grail', 'noSuchRelic'];
    expect(Game.fromJson(odd).legendsFound, {Relic.alliance, Relic.oathOfOne, Relic.dragonCrown});
    expect(Game().toJson().containsKey('legendsFound'), isFalse, reason: 'written only when any');
    // A saved oath with a type (never written) loads on none; a Legenda's stars never pass ★1.
    final bad = Map<String, dynamic>.from(j)
      ..['pusaka'] = {
        'oathOfOne': {'type': 'knight', 'stars': 3},
        'dragonCrown': {'type': 'knight', 'stars': 2},
      };
    final b = Game.fromJson(bad);
    expect((b.pusaka[Relic.oathOfOne]!.type, b.pusaka[Relic.oathOfOne]!.stars, b.pusaka[Relic.dragonCrown]!.stars), (null, 1, 1));
  });
}
