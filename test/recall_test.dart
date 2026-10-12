// "Hero Gugur", recalling a fallen Hero (#92 part 3, lib/recall.dart; docs/units-and-combat.md "Hero Gugur"): a fall
// keeps the Hero, the price, the one gate's refusals in order (the store, the army, five Heroes, the gold),
// the recall itself (the same Hero, nothing rolled, no dice drawn), heroMax, Resurrection, the save, and the log line;
// a full army's swap (decisions-log 167: one troop of the type home for half its price, the count unchanged; none to
// swap; room; over the cap; a type at its cap swaps too, decisions-log 201). On a booted board, the Army detail's Recall:
// town_shop_ui_test.dart.
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';
import 'package:tower_defense/main.dart' show logLine, logLines, shortPrice;

import 'hero_skill_helpers.dart';

/// Every item [type]'s awakening recipe asks for, [level] times over: the type at awakening [level].
List<Item> recipe(String type, int level) => [
      for (final MapEntry(key: item, value: n) in awakenRecipe[type]!.entries)
        for (var i = 0; i < n * level; i++) item,
    ];

/// A game between waves, wave [wave] won (the store open), with [gold] and a 6-column zone.
Game afterWave(int wave, [int gold = 1000000]) => bareGame()
  ..wave = wave
  ..gold = gold;

/// A troop of [type] at cell ([c], [r]) that never strikes (nor heals) on its own.
Unit idle(Game g, String type, int c, int r) => placeNow(g, type, c, r)..cd = hold;

/// The board's full army ([armyMaxBoard]) of idle troops, columns of 8: 8 of each of [four] by turns (the long range's
/// cap), then [fifth] for the rest (4 since decisions-log 260's 36).
List<Unit> fullOf(Game g, List<String> four, String fifth) =>
    [for (var i = 0; i < armyMaxBoard; i++) idle(g, i < 4 * 8 ? four[i % 4] : fifth, i ~/ rows, i % rows)];

/// Monsters [ms] strike their nearest foes once, now (they must be in reach): one tick.
void strike(Game g, List<Unit> ms) {
  for (final m in ms) {
    m
      ..busyUntil = double.negativeInfinity
      ..cd = 0;
  }
  g.tick(0.05);
  for (final m in ms) {
    m.busyUntil = hold;
  }
}

/// The next wave begins with nothing to spawn; [who] (at 1 HP) fall to an orc each, the skills off (a cast could
/// guard one or move it off); then the wave is won.
void fallAndWin(Game g, List<Unit> who) {
  g
    ..skills = false
    ..heroSkills = false
    ..awakenSkills = false
    ..startWave()
    ..queue.clear();
  for (final u in who) {
    u.hp = 1;
  }
  final orcs = [for (final u in who) foeAt(g, 'orc', u.pos + const Point(12, 0))];
  for (var i = 0; i < 10 && who.any((u) => u.alive); i++) {
    strike(g, orcs);
  }
  expect(who.any((u) => u.alive), isFalse);
  for (final e in g.enemies) {
    e.gone = true;
  }
  g.tick(0.05);
  expect((g.waveActive, g.over), (false, false));
}

/// A fallen knight Hero: HP and defence x3, its first Hero skill, fallen in wave 60.
FallenHero knight([String name = 'Budi Santoso']) =>
    FallenHero(name: name, type: 'knight', stats: const [HeroStat.hp, HeroStat.defence], skill: heroSkillPool('knight').first, fell: 60);

void main() {
  test('the price: 2500 x 1.045^(wave - 1), to the thousand: 42k at 65, 57k at 72, 81k at 80, 195k at 100', () {
    expect((heroRecallK, heroRecallRound, killGoldGrowth, heroMax), (2500, 1000, 0.045, 5));
    expect([for (final w in [65, 72, 80, 100]) heroRecallPrice(w)], [42000, 57000, 81000, 195000]);
    expect([heroRecallPrice(0), heroRecallPrice(1), heroRecallPrice(storeFrom)], [3000, 3000, 5000]);
    expect(afterWave(72).recallPrice, 57000, reason: 'the last wave played');
  });

  test('a Hero that falls is kept (name, type, attributes, skill, the wave); a troop is not; its relics are in the bag', () {
    final g = afterWave(64);
    idle(g, 'archer', 0, 0); // left standing
    final skill = heroSkillPool('knight').first; // melee, as the fall needs: an archer steps back out of an orc's reach
    final h = idle(g, 'knight', 2, 3)
      ..hero = true
      ..heroStats = [HeroStat.power, HeroStat.speed]
      ..heroSkill = skill
      ..relics.addAll([Relic.fury, Relic.fang]);
    final s = idle(g, 'soldier', 2, 5);
    fallAndWin(g, [h, s]);
    final f = g.fallenHeroes.single;
    expect((f.name, f.type, f.skill, f.fell), (h.name, 'knight', skill, 65));
    expect(f.stats, [HeroStat.power, HeroStat.speed]); // (a list in a record compares by identity)
    expect((g.relicBag[Relic.fury], g.relicBag[Relic.fang]), (1, 1), reason: 'its relics stay in the Bag');
    expect(g.toReplace.map((t) => t.type), ['soldier'], reason: '"Ganti yang gugur" still leaves the Heroes out');
    expect(() => f.stats.add(HeroStat.hp), throwsUnsupportedError, reason: 'kept as it fell');
  });

  test('Resurrection never raises a fallen Hero, so its entry stays for the Toko', () {
    final (g, priest) = heroCaster(HeroSkill.revive);
    idle(g, 'knight', 0, 0);
    final t = idle(g, 'soldier', 4, 3)
      ..hp = 1
      ..hero = true;
    strike(g, [foeAt(g, 'orc', t.pos + const Point(12, 0))]);
    expect(t.alive, isFalse);
    g.tick(0.05);
    expect(priest.heroSkillAt, double.negativeInfinity, reason: 'not cast');
    expect(g.fallenHeroes.map((f) => f.name), [t.name]);
  });

  test('a recall brings back the same Hero, nothing rolled and no dice drawn, with its type as it is now and empty slots', () {
    final g = afterWave(65), priest = idle(g, 'priest', 0, 0), f = knight();
    g
      ..heroes = Random(7)
      ..names = Random(8);
    final events = <GameEvent>[];
    g.listeners.add(events.add);
    g.upgrades['knight'] = recipe('knight', maxAwaken);
    g.ascended['knight'] = 1; // Bangkit 4
    g.givePusaka(Relic.dawnStar, type: 'knight');
    g.fallenHeroes.add(f);
    final gold = g.gold;
    expect(g.whyNotRecall(f), isNull);
    expect(g.recallHero(f), isTrue);

    final u = g.heroRecalled.single;
    expect(g.troops.where((o) => o.alive), contains(u));
    expect((u.name, u.type, u.hero, u.heroSkill, u.relics.isEmpty, u.relicSlots, u.revived),
        ('Budi Santoso', 'knight', true, f.skill, true, heroRelicSlots, false));
    expect(u.heroStats, [HeroStat.hp, HeroStat.defence]);
    final want = g.statsOf('knight').heroic({HeroStat.hp, HeroStat.defence}, heroBoost);
    expect((u.stats.hp, u.stats.def, u.stats.dmg, u.hp), (want.hp, want.def, want.dmg, want.hp.toDouble()), reason: 'Bangkit 4 and Dawn Star, x3, full HP');
    expect(priest.stats.hp, g.statsOf('priest').boosted(auraBoost).hp, reason: 'the aura is back');
    expect((g.gold, g.fallenHeroes.isEmpty, g.aliveOf('knight'), g.heroCount), (gold - 42000, true, 1, 1));
    expect(g.heroes.nextInt(1 << 30), Random(7).nextInt(1 << 30), reason: 'no Hero dice');
    expect(g.names.nextInt(1 << 30), Random(8).nextInt(1 << 30), reason: 'no name dice');
    // autoPlace's cell, marching in from the left.
    expect(g.inZone((u.post.x / tile).floor(), (u.post.y / tile).floor()), isTrue);
    expect((u.arriving, u.entered, u.pos.x < g.baseX, u.pos.y), (true, false, true, u.post.y));
    final e = events.whereType<HeroRecalled>().single;
    expect((e.name, e.type, e.skill, e.fell, e.cost, e.wave), ('Budi Santoso', 'knight', f.skill, 60, 42000, 65));
    expect(e.stats, [HeroStat.hp, HeroStat.defence]);
    expect(events.whereType<Bought>(), isEmpty, reason: 'not a troop bought');
    expect(g.sfx, contains(Sfx.clear));
    // Called back again it is refused: the entry is gone.
    expect(g.recallHero(f), isFalse);
    expect(g.sfx.last, Sfx.error);
  });

  test('heroMax holds: with 5 Heroes alive "Already 5 Heroes"; a 10th wave crowns none past 5', () {
    final g = afterWave(69);
    final heroes = [for (var i = 0; i < 5; i++) idle(g, 'soldier', 0, i)..hero = true];
    idle(g, 'archer', 1, 0);
    final f = knight();
    g.fallenHeroes.add(f);
    final gold = g.gold;
    expect(g.whyNotRecall(f), 'Already 5 Heroes');
    expect((g.recallHero(f), g.gold, g.fallenHeroes.length, g.sfx.last), (false, gold, 1, Sfx.error));
    g.units.remove(heroes.last); // fell
    expect(g.recallHero(f), isTrue);
    expect(g.heroCount, heroMax);
    g
      ..startWave() // 70
      ..queue.clear()
      ..tick(0.05);
    expect((g.wave, g.waveActive, g.heroCount), (70, false, heroMax), reason: 'the archer is not crowned');
  });

  test('the refusals, in order, through the one gate: the store, the army, five Heroes, the gold', () {
    final g = afterWave(storeFrom - 1)..boardRules();
    final f = knight();
    g.fallenHeroes.add(f);
    expect(g.whyNotRecall(f), storeRefusalNames[StoreRefusal.locked]);
    g.wave = 65;
    // 36 troops of 5 types (8 lancers, soldiers, archers and wizards, 4 swordsmen; each under its cap), 5 of them
    // Heroes, and the gold short.
    final army = fullOf(g, const ['lancer', 'soldier', 'archer', 'wizard'], 'swordsman');
    for (final u in army.take(heroMax)) {
      u.hero = true;
    }
    g.gold = 0;
    g
      ..startWave()
      ..queue.clear();
    g.units.add(Unit(Side.enemy, 'orc', enemyTypes['orc']!, const Point(300, 40))); // the wave is on
    expect(g.whyNotRecall(f), storeRefusalNames[StoreRefusal.midWave]);
    g.enemies.single.gone = true;
    g.tick(0.05); // won: 66
    expect((g.waveActive, g.wave), (false, 66));
    g.lives = 0;
    expect(g.whyNotRecall(f), storeRefusalNames[StoreRefusal.over]);
    g.lives = Game.startLives;
    expect(g.whyNotRecall(f), 'Army full: no ${troopTypeNames['knight']} to swap', reason: 'full, and no knight to swap');
    g.units.remove(army.last); // 35
    expect(g.whyNotRecall(f), 'Already 5 Heroes');
    army.first.hero = false;
    g.gold = g.recallPrice - 1;
    expect(g.gold, greaterThan(g.priceOf('knight')), reason: 'a knight troop it could buy');
    expect(g.whyNotRecall(f), Words.notEnoughGold);
    g.gold++;
    expect((g.whyNotRecall(f), g.recallHero(f), g.gold), (null, true, 0));
    expect(g.armySize, armyMaxBoard);

    // Without the board's limits a full army says "No room" ([buyRefusals].full).
    final plain = afterWave(65)..capacity = 1;
    idle(plain, 'priest', 0, 0);
    expect(plain.whyNotRecall(f), '${buyRefusals.full}: no ${troopTypeNames['knight']} to swap');
  });

  /// A game after wave 65 with the board's limits and its 36 troops (8 each of lancers, knights, archers, wizards by
  /// turns, the knights under their cap, then 4 soldiers), [f] fallen.
  (Game, List<Unit>) fullArmy(FallenHero f) {
    final g = afterWave(65)..boardRules();
    final army = fullOf(g, const ['lancer', 'knight', 'archer', 'wizard'], 'soldier');
    g.fallenHeroes.add(f);
    return (g, army);
  }

  test('a full army swaps: its plain troop of the type with the lowest HP share goes home for half its price, the '
      'Hero takes its place, the count stays', () {
    final f = knight();
    final (g, army) = fullArmy(f);
    final knights = army.where((u) => u.type == 'knight').toList();
    knights.first
      ..hero = true // a Hero is never swapped, however hurt
      ..hp = 1;
    knights[2].hp = knights[5].hp = knights[2].maxHp * 0.5; // the lowest share of the plain ones: of equals the first placed
    knights[3].hp = knights[3].maxHp * 0.4;
    g.healQueue.add(knights[3]); // waiting for the after-wave heal: as whole, as the save keeps it
    knights[2].relics.add(Relic.fury);
    final events = <GameEvent>[];
    g.listeners.add(events.add);
    expect((g.full, g.armySize, g.heroCount), (true, armyMaxBoard, 1));
    final out = knights[2], gold = g.gold, bag = g.relicBag[Relic.fury] ?? 0;
    expect(g.recallSwapOf(f), out);
    expect((recallSwapRefund, g.recallSwapRefundOf('knight')), (releaseRefund, (g.priceOf('knight') * 0.5).round()));
    final refund = g.recallSwapRefundOf('knight');
    expect(g.whyNotRecall(f), isNull);
    expect(g.recallHero(f), isTrue);

    final u = g.heroRecalled.single;
    expect((g.armySize, g.heroCount, g.gold), (armyMaxBoard, 2, gold - 42000 + refund), reason: 'the count unchanged');
    expect((out.alive, g.units.contains(out), g.toReplace.isEmpty, g.fallen.isEmpty), (false, false, true, true),
        reason: 'home, not fallen');
    expect(g.relicBag[Relic.fury], bag + 1, reason: 'its relic back to the bag');
    expect(g.troops.where((t) => t.alive && t.type == 'knight' && !t.hero).length, 6);
    expect(g.troops.where((t) => t.alive), contains(u));
    expect(g.inZone((u.post.x / tile).floor(), (u.post.y / tile).floor()), isTrue);
    expect(g.fallenHeroes, isEmpty);
    final e = events.whereType<HeroRecalled>().single;
    expect((e.swapped, e.refund, e.cost), (out.name, refund, 42000));
    expect(e.toJson()['refund'], refund);
    expect(e.toJson().containsKey('swapped'), isFalse, reason: 'no troop names in the telemetry');
    expect(logLines(e), ['Budi Santoso (${troopTypeNames['knight']}) is back (42k gold)', '${out.name} goes home (+${shortPrice(refund)} gold)']);
    expect(events.whereType<TypeReleased>(), isEmpty, reason: 'the type stays');

    // The next recall swaps the next: knights[5] now (knights[3] is as whole).
    final f2 = knight('Sari');
    g.fallenHeroes.add(f2);
    expect(g.recallSwapOf(f2), knights[5]);
  });

  test('a full army with no plain troop of the type: "Army full: no Knight to swap"; then five '
      'Heroes, then the gold against the whole price', () {
    final f = knight();
    final (g, army) = fullArmy(f);
    for (final u in army.where((u) => u.type == 'knight')) {
      u.hero = true; // 8 Hero knights, none to swap
    }
    expect(g.recallSwapOf(f), isNull);
    expect(g.whyNotRecall(f), 'Army full: ${recallNoSwap('knight')}');
    expect(g.whyNotRecall(f), 'Army full: no ${troopTypeNames['knight']} to swap');
    final gold = g.gold;
    expect((g.recallHero(f), g.gold, g.armySize, g.fallenHeroes.length, g.sfx.last), (false, gold, armyMaxBoard, 1, Sfx.error));

    // One plain knight to swap: the army no longer refuses, five Heroes do.
    army[1].hero = false;
    expect(g.recallSwapOf(f), army[1]);
    expect(g.whyNotRecall(f), 'Already 5 Heroes');
    for (final u in army.where((u) => u.type == 'knight').skip(1).take(4)) {
      u.hero = false; // 3 Heroes left
    }
    // The gold: the whole price, though the refund would make up the difference.
    g.gold = g.recallPrice - 1;
    expect(g.gold + g.recallSwapRefundOf('knight'), greaterThan(g.recallPrice));
    expect(g.whyNotRecall(f), Words.notEnoughGold);
    g.gold++;
    expect(g.recallHero(f), isTrue);
    expect((g.gold, g.armySize), (g.recallSwapRefundOf('knight'), armyMaxBoard));
  });

  test('with room in the army nobody is swapped, as before', () {
    final f = knight();
    final (g, army) = fullArmy(f);
    g.units.remove(army.last); // 35
    final events = <GameEvent>[];
    g.listeners.add(events.add);
    final before = [...g.troops.where((u) => u.alive)], gold = g.gold;
    expect((g.full, g.recallSwapOf(f)), (false, null));
    expect(g.recallInfo(f).$2.where((l) => l.contains('goes home')), isEmpty);
    expect(g.recallHero(f), isTrue);
    expect(g.troops.where((u) => u.alive), containsAll(before));
    expect((g.armySize, g.gold), (armyMaxBoard, gold - 42000));
    final e = events.whereType<HeroRecalled>().single;
    expect((e.swapped, e.refund, logLines(e).length), (null, 0, 1));
  });

  test('over the cap (a save\'s 48) the swap works the same: the count stays 48', () {
    final g = afterWave(65); // the limits on after the army is in, as a loaded save of 48
    const four = ['priest', 'knight', 'archer', 'wizard'];
    final army = [for (var i = 0; i < 48; i++) idle(g, four[i % 4], i ~/ rows, i % rows)];
    g.boardRules();
    final f = knight();
    g.fallenHeroes.add(f);
    expect((g.armySize, g.armyCap, g.full), (48, armyMaxBoard, true));
    final out = g.recallSwapOf(f);
    expect(out, army[1], reason: 'all whole: the first placed knight');
    expect(g.recallInfo(f).$2, contains('Army full: ${out!.name} goes home (+${thousands(g.recallSwapRefundOf('knight'))} gold)'));
    expect(g.whyNotRecall(f), isNull);
    expect(g.recallHero(f), isTrue);
    expect((g.armySize, g.heroCount, out.alive), (48, 1, false));
  });

  test('the gold is weighed against the recall price, not the troop price', () {
    final g = afterWave(storeFrom, 0);
    g.upgrades['knight_templar'] = recipe('knight_templar', maxAwaken);
    final f = FallenHero(name: 'Sari', type: 'knight_templar', stats: const [HeroStat.hp, HeroStat.power], fell: 10);
    g.fallenHeroes.add(f);
    g.gold = g.recallPrice - 1; // the troop price in hand (Awaken 3 is x8 since decisions-log 318), the recall's not
    expect((g.recallPrice, g.priceOf('knight_templar') <= g.gold), (5000, true));
    expect(g.whyNotRecall(f), buyRefusals.gold);
    g.gold = g.recallPrice;
    expect(g.whyNotRecall(f), isNull);
    expect(g.recallHero(f), isTrue);
  });

  test('a Hero whose type is at its cap swaps too (decisions-log 201): its plain troop goes home, the count stays', () {
    final g = afterWave(65)..boardRules();
    final knights = [for (var i = 0; i < typeCapBoard['knight']!; i++) idle(g, 'knight', i ~/ rows, i % rows)];
    final f = knight();
    g.fallenHeroes.add(f);
    expect((g.full, g.typeFull('knight'), g.buyRefusal('knight')), (false, true, 'Knights full 10/10'));
    expect(g.recallSwapOf(f), knights.first, reason: 'all whole: the first placed');
    expect(g.recallInfo(f).$2, contains('Knights full: ${knights.first.name} goes home (+${thousands(g.recallSwapRefundOf('knight'))} gold)'));
    expect(g.whyNotRecall(f), isNull);
    final gold = g.gold;
    expect(g.recallHero(f), isTrue);
    expect((g.aliveOf('knight'), g.heroCount, g.gold), (10, 1, gold - g.recallPrice + g.recallSwapRefundOf('knight')));
    // All of them Heroes but the cap's worth: none to swap, its cap refuses.
    final f2 = knight('Sari');
    g.fallenHeroes.add(f2);
    for (final u in g.troops.where((u) => u.alive && u.type == 'knight')) {
      u.hero = true;
    }
    expect((g.recallSwapOf(f2), g.whyNotRecall(f2)), (null, 'Knights full 10/10'));
    // Without the caps (a plain game) nobody is swapped under the army's cap.
    final plain = afterWave(65);
    for (var i = 0; i < 12; i++) {
      idle(plain, 'knight', i ~/ rows, i % rows);
    }
    expect(plain.recallSwapOf(f), isNull);
  });

  test('the save keeps the fallen Heroes; old saves have none; an unknown type is dropped, an unknown skill rolled', () {
    final g = afterWave(65);
    idle(g, 'priest', 0, 0);
    expect(g.toJson().containsKey('fallenHeroes'), isFalse, reason: 'none: no key');
    g.fallenHeroes.addAll([knight(), FallenHero(name: 'Sari', type: 'archer', stats: const [HeroStat.range, HeroStat.speed], fell: 66)]);
    final j = jsonDecode(jsonEncode(g.toJson())) as Map<String, dynamic>;
    expect(j['fallenHeroes'], [
      {'name': 'Budi Santoso', 'type': 'knight', 'stats': ['hp', 'defence'], 'skill': heroSkillPool('knight').first.name, 'fell': 60},
      {'name': 'Sari', 'type': 'archer', 'stats': ['range', 'speed'], 'fell': 66},
    ]);
    final back = Game.fromJson(j);
    expect([for (final f in back.fallenHeroes) f.toJson()], j['fallenHeroes'], reason: 'a round trip');
    expect([for (final f in back.fallenHeroes) (f.name, f.skill)], [('Budi Santoso', heroSkillPool('knight').first), ('Sari', null)]);
    expect(back.fallenHeroes.first.stats, [HeroStat.hp, HeroStat.defence]);

    // From before it: none.
    expect(Game.fromJson({...j}..remove('fallenHeroes')).fallenHeroes, isEmpty);
    final w86 = jsonDecode(File('test/fixtures/save-20261001-2005-pre-awaken.json').readAsStringSync()) as Map<String, dynamic>;
    expect(Game.fromJson(w86).fallenHeroes, isEmpty);

    // Unknown names: the type drops the entry, an attribute is left out, a skill is rolled on the recall.
    final odd = Game.fromJson({
      ...j,
      'fallenHeroes': [
        {'name': 'X', 'type': 'dragon', 'stats': ['hp'], 'fell': 1},
        {'name': 'Budi', 'type': 'knight', 'stats': ['hp', 'rage'], 'skill': 'noSuchSkill', 'fell': 60},
      ],
    }, Random(1), Random(2), Random(3));
    final f = odd.fallenHeroes.single;
    expect((f.name, f.skill), ('Budi', null));
    expect(f.stats, [HeroStat.hp]);
    expect(odd.recallHero(f), isTrue);
    expect(heroSkillPool('knight'), contains(odd.heroRecalled.single.heroSkill));
  });

  test('the battle log says it, and the event goes out with its cost and the wave it fell in', () {
    final f = knight('Budi');
    final e = HeroRecalled(65, 12.5, name: 'Budi', type: 'knight', stats: f.stats, skill: f.skill, fell: 60, cost: 57000);
    expect(logLine(e), 'Budi (${troopTypeNames['knight']}) is back (57k gold)');
    expect(e.toJson(), {
      'v': eventVersion, 'kind': 'heroRecalled', 'wave': 65, 't': 12.5, 'name': 'Budi', 'type': 'knight',
      'stats': ['hp', 'defence'], 'skill': f.skill!.name, 'fell': 60, 'cost': 57000, 'refund': 0,
    });
  });
}
