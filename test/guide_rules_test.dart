// When the first-time guide's one-time cards show (lib/guide_rules.dart, docs/ui-hud.md "Guide"), on plain games: each
// card's trigger, the order at a break, and the seen set in settings.json, a device from before the guide included (a
// save at wave 0, and the owner's wave-86 game: only K14, K15, K18 and K20-K23 left; its file, from before the Towns,
// is no save now).
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';
import 'package:tower_defense/guide_rules.dart';
import 'package:tower_defense/save.dart';
import 'package:tower_defense/settings.dart';

import 'hero_skill_helpers.dart';

const _fixture = 'test/fixtures/save-20261001-2005-pre-awaken.json';

/// The owner's wave-86 save, as the board plays it (its limits on).
Game w86() => Game.fromJson(jsonDecode(File(_fixture).readAsStringSync()) as Map<String, dynamic>, Random(1), Random(101),
    Random(301))
  .boardRules();

/// The keys of the rules due in [g] now.
List<String> due(Game g) => [for (final r in guideRules) if (r.due(g)) r.key];

/// Whether rule [key] is due in [g].
bool isDue(String key, Game g) => guideRules.firstWhere((r) => r.key == key).due(g);

/// A board's game between waves at [wave] (the free priest alone).
Game at(int wave) => Game(Random(1)).boardRules()..wave = wave;

void main() {
  test('a rule per card K0-K25, each gated at the wave a game has met it (none for K14, K15, K18, K20, K21, K22, K23)', () {
    expect([for (final r in guideRules) r.key], [for (var i = 0; i <= 25; i++) 'K$i']);
    expect({for (final r in guideRules) r.key: r.gate}, {
      'K0': 1, 'K1': 1, 'K2': 2, 'K3': 3, 'K4': 4, 'K5': 5, 'K6': 5, 'K7': 7, 'K8': 10, 'K9': 10, 'K10': 10,
      'K11': 15, 'K12': 20, 'K13': 1, 'K14': null, 'K15': null, 'K16': 1, 'K17': 34, 'K18': null, 'K19': 49,
      'K20': null, 'K21': null, 'K22': null, 'K23': null, 'K24': 1, 'K25': omenFrom,
    });
    expect([for (final r in guideRules) if (r.passing) r.key], ['K2', 'K3', 'K4', 'K17', 'K19']);
    expect([for (final r in guideRules) if (r.inTown) r.key], ['K23'], reason: 'the first Town\'s, in it (decisions-log 237)');
    expect([for (final r in guideRules) if (r.after != null) '${r.key}<${r.after}'], ['K0<P5']);
    expect(guidePointers, ['P1', 'P2', 'P3', 'P4', 'P5']);
  });

  test('a new game owes no card: nothing is due at wave 0', () {
    expect(due(Game().boardRules()), isEmpty);
    expect(due(Game()), isEmpty);
  });

  test('K0 items: one waits in the bag and none was given yet', () {
    final g = at(1);
    expect(isDue('K0', g), isFalse);
    g.inventory[Item.sword] = 1;
    expect(isDue('K0', g), isTrue);
    g.upgrades['priest'] = [Item.staff];
    expect(isDue('K0', g), isFalse); // the player has given one: they know
  });

  test('K1: troops fell this wave (Ganti yang gugur)', () {
    final g = at(1);
    expect(isDue('K1', g), isFalse);
    g.toReplace.add((type: 'soldier', post: const Point(24, 24)));
    expect(isDue('K1', g), isTrue);
  });

  test('K2-K4 and K19: the wave before a mini boss, a healer monster, a boss, escorts; only then', () {
    for (final (key, wave) in [('K2', miniBossEvery - 1), ('K3', necroHealerFrom - 1), ('K4', bossEvery - 1), ('K19', escortFrom - 1)]) {
      expect([isDue(key, at(wave - 1)), isDue(key, at(wave)), isDue(key, at(wave + 1))], [false, true, false], reason: key);
    }
    expect((miniBossEvery, necroHealerFrom, bossEvery, escortFrom), (3, 4, 5, 50));
  });

  test('K5 and K12: a chest waits; the one to open shows a Legenda', () {
    final g = at(bossEvery);
    expect((isDue('K5', g), isDue('K12', g)), (false, false));
    g.chests.add(Chest(ChestKind.boss, bossEvery, cards: [Relic.grail, Relic.voidEye, Relic.dawnStar]));
    expect((isDue('K5', g), isDue('K12', g)), (true, false));
    g.chests.add(Chest(ChestKind.boss, legendFrom, cards: [Relic.dragonCrown, Relic.ironBanner, null]));
    expect(isDue('K12', g), isFalse); // the second waits behind the first
    g.chests.removeAt(0);
    expect((isDue('K5', g), isDue('K12', g)), (true, true));
  });

  test('K6: a Pusaka bound to a type (not one in the Gudang, nor an oath)', () {
    final g = at(bossEvery)..givePusaka(Relic.grail);
    expect(isDue('K6', g), isFalse);
    g.givePusaka(Relic.alliance);
    expect(isDue('K6', g), isFalse);
    g.givePusaka(Relic.voidEye, type: 'priest');
    expect(isDue('K6', g), isTrue);
  });

  test('K7: a small relic in the bag', () {
    final g = at(7)..relicBag[Relic.fang] = 0;
    expect(isDue('K7', g), isFalse);
    g.relicBag[Relic.grail] = 1; // a Pusaka (an old save's) is no small relic
    expect(isDue('K7', g), isFalse);
    g.relicBag[Relic.guard] = 1;
    expect(isDue('K7', g), isTrue);
  });

  test('K8 item limits and K9 Bangkit: a fielded type that must awaken first for an item in the bag; the bag can awaken '
      'one', () {
    final g = bareGame()..wave = 10;
    g.inventory[Item.longBow] = 1; // grade II: open from Awaken 1 (decisions-log 249)
    expect((isDue('K8', g), isDue('K9', g)), (false, false)); // no archer on the field
    placeNow(g, 'archer', 0, 0);
    expect(g.whyNot(Item.longBow, 'archer'), Refusal.awakenFirst);
    expect((isDue('K8', g), isDue('K9', g)), (true, false));
    g.inventory.addAll(g.gradeSet('archer', 1)); // its grade I set in the bag
    expect((g.bagAwakens, isDue('K9', g)), (true, true));
  });

  test('K10 Hero: one was made (alive or fallen)', () {
    final g = at(heroEvery);
    expect(isDue('K10', g), isFalse);
    g.troops.first.hero = true;
    expect(isDue('K10', g), isTrue);
    final h = at(heroEvery)..fallenHeroes.add(FallenHero(name: 'Hera Quill', type: 'priest', stats: const [], fell: 11));
    expect(isDue('K10', h), isTrue);
  });

  test('K11 Shop: from the Shop\'s opening (every Town\'s, from wave 1\'s win, once a Town is marked, decisions-log 253; '
      'the Towns off never: no Town, and the field\'s Toko went in decisions-log 296); K14 Hero fell: from wave 15\'s win, '
      'when Recall opens', () {
    FallenHero fell() => FallenHero(name: 'Hera Quill', type: 'priest', stats: const [], fell: 12);
    expect((isDue('K11', at(0)..townAt = 2), isDue('K11', at(6)), isDue('K11', at(6)..townAt = 8)), (false, false, true));
    expect((isDue('K11', at(storeFrom - 1)..towns = false), isDue('K11', at(storeFrom)..towns = false)), (false, false));
    expect(isDue('K14', at(storeFrom)), isFalse);
    expect(isDue('K14', at(storeFrom - 1)..fallenHeroes.add(fell())), isFalse);
    expect(isDue('K14', at(storeFrom)..fallenHeroes.add(fell())), isTrue);
  });

  test('K13: a type at its cap on the board (decisions-log 201); with no caps never', () {
    final g = at(1)..gold = 1 << 20, plain = Game(Random(1))..gold = 1 << 20;
    while (g.aliveOf(Game.freeHealer) < typeCapBoard[Game.freeHealer]! - 1) {
      expect((g.autoPlace(Game.freeHealer), plain.autoPlace(Game.freeHealer)), (true, true));
    }
    expect(isDue('K13', g), isFalse);
    expect((g.autoPlace(Game.freeHealer), plain.autoPlace(Game.freeHealer)), (true, true));
    expect((g.typeFull(Game.freeHealer), isDue('K13', g)), (true, true));
    expect(isDue('K13', plain), isFalse);
  });

  test('K15: the army at the most alive (36 on the board); a plain game has no most', () {
    final g = bareGame().boardRules();
    const four = ['soldier', 'knight', 'swordsman', 'lancer']; // each under its cap (decisions-log 201)
    for (var i = 0; i < armyMaxBoard - 1; i++) {
      placeNow(g, four[i % 4], i ~/ rows, i % rows);
    }
    expect(isDue('K15', g), isFalse);
    placeNow(g, four[(armyMaxBoard - 1) % 4], (armyMaxBoard - 1) ~/ rows, (armyMaxBoard - 1) % rows);
    expect((g.armySize, isDue('K15', g)), (armyMaxBoard, true));
    expect(isDue('K15', g..armyMax = null), isFalse);
  });

  test('K16: the last wave stalled and marched; the next wave clears it, and it is never saved', () {
    final g = Game(Random(1)); // the free priest alone, which can't hurt a bat and out-heals it (game_test.dart)
    g.startWave();
    g.queue
      ..clear()
      ..add(('bat', Tier.normal));
    expect(g.stalled, isFalse);
    for (var i = 0; i < 2400 && g.waveActive; i++) {
      g.tick(0.05);
    }
    expect((g.waveActive, g.marching, g.stalled, isDue('K16', g)), (false, false, true, true));
    expect(Game.fromJson(g.toJson()).stalled, isFalse);
    g.startWave();
    expect((g.stalled, isDue('K16', g)), (false, false));
  });

  test('K17 Pasang: the win before the tide\'s first wave', () {
    expect([isDue('K17', at(tideFrom - 2)), isDue('K17', at(tideFrom - 1)), isDue('K17', at(tideFrom))], [false, true, false]);
  });

  test('K18, K20, K21 on the owner\'s w86 save: gold for the Toko, an Asah; a Lebur once a Pusaka waits in the Gudang', () {
    final g = w86();
    expect((isDue('K18', g), g.tokoNudge), (true, true));
    expect(isDue('K20', g), isTrue); // its five Pusaka at ★1, 1.8M gold, 90 small relics
    g.asahAt = g.wave;
    expect(isDue('K20', g), isFalse); // one Asah a boss interval
    expect(isDue('K21', g), isFalse); // every Pusaka bound
    g.pusaka[Relic.grail]!.type = null;
    expect(isDue('K21', g), isTrue);
    g.gold = 0;
    expect((isDue('K18', g), isDue('K21', g)), (false, true)); // Lebur's button doesn't ask the gold
  });

  test('K22 Carve: from wave 40, between waves, once some Pusaka can take Carve (spare items in the bag)', () {
    final g = at(ukirFrom - 1)
      ..givePusaka(Relic.grail)
      ..inventory[Item.potion] = 30;
    expect(isDue('K22', g), isFalse); // Carve opens at wave 40
    g.wave = ukirFrom;
    expect(isDue('K22', g), isTrue);
    g.inventory[Item.potion] = 0;
    expect(isDue('K22', g), isFalse); // nothing to give
    g
      ..inventory[Item.potion] = 30
      ..startWave();
    expect(isDue('K22', g), isFalse); // mid-wave
    final h = at(ukirFrom)
      ..givePusaka(Relic.oathOfOne)
      ..inventory[Item.potion] = 30;
    expect(isDue('K22', h), isFalse); // an oath takes no Carve
  });

  test('guideNext: between waves only, after the intro, one card, a passing one first, else in order', () {
    final g = at(miniBossEvery - 1)..toReplace.add((type: 'soldier', post: const Point(24, 24)));
    expect(guideNext(g, {}), isNull); // the intro first
    final seen = {guideIntro};
    expect(guideNext(g, seen), 'K2'); // its wave goes; K1 comes again whenever troops fall
    seen.add('K2');
    expect(guideNext(g, seen), 'K1');
    seen.add('K1');
    expect(guideNext(g, seen), isNull);
    g.inventory[Item.sword] = 1;
    expect(guideNext(g, seen), isNull); // K0 waits for the item pointers to be dropped
    dropItemPointers(seen);
    expect(seen, containsAll(['P3', 'P4', 'P5']));
    expect(guideNext(g, seen), 'K0');
    final done = {guideIntro};
    itemPointersDone(done);
    expect(done, {guideIntro, 'P3', 'P4', 'P5', 'K0'}); // the pointers taught it
    expect(guideNext(g, done), 'K2');
    g.startWave();
    expect(guideNext(g, seen), isNull); // mid-wave, never
  });

  test('guideNext with the chest\'s popup open: only K5, K12 and K25 (they sit over it), in order; without it never them', () {
    expect([for (final r in guideRules) if (r.atChest) r.key], ['K5', 'K12', 'K25']);
    final g = at(bossEvery)
      ..chests.add(Chest(ChestKind.boss, bossEvery, cards: [Relic.dragonCrown, Relic.grail, Relic.voidEye]))
      ..relicBag[Relic.fang] = 1;
    final seen = {guideIntro};
    expect(guideNext(g, seen), 'K7');
    expect(guideNext(g, seen, chest: true), 'K5');
    seen.add('K5');
    expect(guideNext(g, seen, chest: true), 'K12');
    seen.add('K12');
    expect(guideNext(g, seen, chest: true), isNull);
    expect(guideNext(g, seen), 'K7');
  });

  test('the seen set from before the guide: none with no save; at wave 0 the intro and the pointers', () {
    expect(seenFrom(null), isEmpty);
    expect(seenFrom(0), {guideIntro, ...guidePointers});
    expect(seenFrom(4), {guideIntro, ...guidePointers, 'K0', 'K1', 'K2', 'K3', 'K4', 'K13', 'K16', 'K24'});
  });

  test('the owner\'s w86 save at wave 86 keeps K14, K15, K18, K20-K23 to see; on it K15 comes first, then K18, K20 and K22',
      () {
    final g = w86();
    expect(savedWave(File(_fixture)), isNull, reason: 'a pre-Towns save is no save now (decisions-log 237)');
    final seen = seenFrom(86);
    expect([for (final r in guideRules) if (!seen.contains(r.key)) r.key], ['K14', 'K15', 'K18', 'K20', 'K21', 'K22', 'K23']);
    expect(seen, containsAll([guideIntro, ...guidePointers]));
    final shown = <String>[];
    for (var k = guideNext(g, seen); k != null; k = guideNext(g, seen)) {
      shown.add(k);
      seen.add(k);
    }
    expect(shown, ['K15', 'K18', 'K20', 'K22']); // no fallen Hero, no Pusaka in the Gudang on it; its bag can Carve
  });

  test('settings.json keeps the seen set; missing or broken it is none; "Main Baru" never clears it', () {
    final dir = Directory.systemTemp.createTempSync('td_seen'), file = File('${dir.path}/settings.json');
    addTearDown(() => dir.deleteSync(recursive: true));
    expect(loadSettings(file).seen, isNull);
    expect(saveSettings(Settings(seen: {guideIntro, 'P1', 'K5'}), file), isTrue);
    expect(loadSettings(file).seen, {guideIntro, 'P1', 'K5'});
    expect(jsonDecode(file.readAsStringSync())['seen'], [guideIntro, 'P1', 'K5']);
    expect(Settings().toJson().containsKey('seen'), isFalse);
    expect(Settings.fromJson({'seen': 'intro'}).seen, isNull);
    expect(Settings.fromJson({'seen': ['intro', 3, null, 'K1']}).seen, {'intro', 'K1'});
    expect(Settings.fromJson({'seen': []}).seen, isEmpty); // "Ulang panduan" leaves it empty, not missing

    // The game's own folder (this file's temp dir): a save, the settings, then "Main Baru" twice over the save.
    final g = at(7);
    expect((saveGame(g), saveSettings(Settings(seen: seenFrom(savedWave())))), (true, true));
    expect(savedWave(), 7);
    final welcome = Welcome(loadGame());
    expect(welcome.fresh(0), isNull); // "Yakin?"
    expect(welcome.fresh(1), isNotNull);
    expect(savedWave(), isNull);
    expect(loadSettings().seen, seenFrom(7));
  });

  test('savedWave: the save\'s wave alone; none without one or from a broken one', () {
    final dir = Directory.systemTemp.createTempSync('td_wave');
    addTearDown(() => dir.deleteSync(recursive: true));
    expect(savedWave(File('${dir.path}/none.json')), isNull);
    expect(savedWave(File('${dir.path}/broken.json')..writeAsStringSync('{"wave": ')), isNull);
    expect(savedWave(File('${dir.path}/odd.json')..writeAsStringSync('{"wave": "86"}')), isNull);
    final save = File('${dir.path}/save.json');
    expect(saveGame(at(12), save), isTrue);
    expect(savedWave(save), 12);
  });
}
