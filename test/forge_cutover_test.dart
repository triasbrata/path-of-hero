// The forge's cut-over (decisions-log 272; loot-items-relics.md "The forge: items crafted, Awaken by grade"): the forge in
// every board game (its off switch gone, decisions-log 296), and a save written before it loading sanely. Awaken isn't saved but read from the items a
// type holds, and by grade no old item set counts (none holds the forge's new kinds), so a save without `awakenKept`
// keeps each type's level by the old rule ([Game.awakenKept]) and counts on from it; Bangkit and Tempa bought at Awaken 3
// stay with it. Pure Dart, on the old fixtures and a copy of the owner's last save before the cut-over (wave 13, in a Town).
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';
import 'package:tower_defense/telemetry.dart' show passedOn, telemetryVersion;

const w89 = 'test/fixtures/save-20261002-2222-w89-sellbug.json', w8 = 'test/fixtures/save-20261004-1919-w8-v2.json';
const w13 = 'test/fixtures/save-20261008-0438-w13-preforge.json';

Map<String, dynamic> json(String path) => jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

/// [j] loaded as the app loads a save (a board game: the Towns, and with them the forge, on).
Game load(Map<String, dynamic> j) => Game.fromJson(j, Random(1), Random(2), Random(3)).boardRules();

/// [j] loaded with the Towns off (a plain Game(), tests only): the rules from before the forge, Awaken by the old item
/// recipe ([Game.oldItemLevel]), as the forge-off board read it.
Game old(Map<String, dynamic> j) => Game.fromJson(j, Random(1), Random(2), Random(3));

String stats(Stats s) => 'hp ${s.hp} mp ${s.mp} heals ${s.heals} speed ${s.speed} dmg ${s.dmg} range ${s.range} rate ${s.rate} '
    'shotSpeed ${s.shotSpeed} splash ${s.splash} regen ${s.regen} def ${s.def} mpRegen ${s.mpRegen}';

/// [type]'s level, Bangkit and Tempa that count, and stats in [g].
(int, int, int, String) standing(Game g, String type) => (g.awakenLevel(type), g.ascended[type] ?? 0, g.tempaOf(type), stats(g.statsOf(type)));

void main() {
  test('the forge plays in every board game; a plain Game() without the Towns plays as before', () {
    final board = Game().boardRules();
    expect((board.byGrade, board.enhanceOn, board.forgeShop, board.smithyItems(1).length), (true, true, true, 14));
    expect(Game().byGrade, isFalse);
    expect(Game().smithyItems(1), isEmpty);
  });

  test("the telemetry's and the events' version 10 or later: the forge's fields reach every player's records now", () {
    expect((telemetryVersion >= 10, eventVersion >= 10), (true, true)); // 11: the Tavern's (decisions-log 268)
    final g = Game().boardRules();
    expect((g.towns, passedOn.containsAll([EventKind.itemCrafted, EventKind.stoneCrafted, EventKind.itemEnhanced])),
        (true, true));
  });

  test('the w89 save (items by the old rule, Bangkit 5 and Tempa): every type keeps its level, Bangkit, Tempa and stats',
      () {
    final off = old(json(w89)), on = load(json(w89));
    expect(on.byGrade, isTrue);
    expect(on.awakenKept, {'priest': 3, 'armored_axeman': 3, 'archer': 2, 'wizard': 3, 'knight_templar': 2});
    for (final type in troopTypes.keys) {
      expect(standing(on, type), standing(off, type), reason: type);
      expect(on.awakenKept[type] ?? 0, off.oldItemLevel(type), reason: type);
    }
    // What the game from before the forge reads: Awaken 5 with its Tempa for the three that bought Bangkit 5.
    expect([for (final t in ['priest', 'armored_axeman', 'wizard']) (on.awakenLevel(t), on.tempaOf(t))], [(5, 4), (5, 6), (5, 1)]);
    // Without the floor the grade sets would hold nothing: the forge's new kinds are in every set.
    final bare = load(json(w89))..awakenKept.clear();
    expect([for (final type in troopTypes.keys) bare.awakenLevel(type)], everyElement(0));
    // A game with the Towns off never writes the key (its save is as before the forge); the by-grade game always does.
    expect(off.toJson().containsKey('awakenKept'), isFalse);
    expect(on.toJson()['awakenKept'], on.awakenKept);
  });

  test('a kept level counts on by grade: the next Awaken takes the next grade set only, the old items past their caps',
      () {
    final g = load(json(w89));
    expect((g.keptLevel('archer'), g.awakenLevel('archer')), (2, 2));
    expect(g.awakenShort('archer'), g.gradeSet('archer', 3), reason: 'grade III only: grades I and II are kept');
    expect(g.awakenProgress('archer').keys, g.gradeSet('archer', 3).keys);
    expect(g.capOf('archer', Item.bow), g.gradeSet('archer', 1)[Item.bow]);
    expect(g.countOf('archer', Item.bow), 12, reason: 'the old bows stay on the type and count');
    expect(g.whyNot(Item.bow, 'archer'), Refusal.maxed);
    expect(g.capOf('archer', Item.greatBow), greaterThan(0), reason: 'grade III opens at Awaken 2');
    for (final MapEntry(key: item, value: n) in g.gradeSet('archer', 3).entries) {
      g.upgrades['archer'] = [...g.upgrades['archer']!, ...List.filled(n, item)];
    }
    expect(g.awakenLevel('archer'), 3);
    expect(g.awakenShort('archer'), isEmpty);
    // Saved and loaded again, the kept level is the save's, not the items' again.
    final again = load(jsonDecode(jsonEncode(g.toJson())) as Map<String, dynamic>);
    expect(again.awakenKept, g.awakenKept);
    expect(again.awakenLevel('archer'), 3);
  });

  test('a new forge game never keeps a level: its save writes an empty awakenKept, and its grade-I items stay by grade',
      () {
    final g = Game().boardRules();
    expect(g.toJson()['awakenKept'], isEmpty);
    // The knight's old recipe in grade I, without its Amulet: Awaken 1 by the old rule, 0 by grade.
    g.upgrades['knight'] = [for (final MapEntry(key: item, value: n) in g.recipeOf('knight').entries) ...List.filled(n, item)];
    expect((g.oldItemLevel('knight'), g.awakenLevel('knight')), (1, 0));
    final j = jsonDecode(jsonEncode(g.toJson())) as Map<String, dynamic>;
    expect(j['awakenKept'], isEmpty);
    final again = load(j);
    expect(again.awakenKept, isEmpty);
    expect(again.awakenLevel('knight'), 0);
    // The same items in a save without the key (one from before the forge) keep Awaken 1.
    final old = load(Map.of(j)..remove('awakenKept'));
    expect(old.awakenKept, {'knight': 1});
    expect(old.awakenLevel('knight'), 1);
  });

  test("the owner's save before the cut-over (wave 13, in a Town, no items): loads with its gold, materials and Artifacts, "
      'and the Smithy crafts a grade-I item', () {
    final j = json(w13), g = load(j);
    expect((g.wave, g.gold, g.lives, g.score, g.troops.length, g.inTown), (13, 719, j['lives'], 15340, 18, true));
    expect({for (final e in g.materials.entries) e.key.name: e.value}, j['materials']);
    expect(g.matsSeen, [for (final m in droppedMats) if (g.materials.containsKey(m)) m], reason: 'seeded from what is held');
    expect(g.pusaka.keys.map((r) => r.name), unorderedEquals(['brightSpring', 'wardensHorn']));
    expect([g.awakenKept, g.inventory, g.upgrades], everyElement(isEmpty));
    final can = g.craftableItems(1);
    expect(can, isNotEmpty);
    final item = can.first, gold = g.gold, cost = g.itemRecipe(item)!.gold;
    expect(g.craftItem(item), isTrue);
    expect((g.inventory[item], g.gold), (1, gold - cost));
    expect(g.toJson()['awakenKept'], isEmpty);
  });

  test('the version-2 save at wave 8 loads into the forge: its items keep the level they gave', () {
    final off = old(json(w8)), on = load(json(w8));
    for (final type in troopTypes.keys) {
      expect(standing(on, type), standing(off, type), reason: type);
    }
    expect(on.gold, off.gold);
    expect(on.inventory, off.inventory);
    expect(on.relicBag, off.relicBag);
  });
}
