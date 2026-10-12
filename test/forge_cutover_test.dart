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

/// What the game from before the forge read for each type of [w89] and [w8] (its level, Bangkit and Tempa that count, and
/// its stats): the Towns-off rules, Awaken by the old item recipe, recorded before they went (decisions-log 321).
const _before = <String, Map<String, (int, int, int, String)>>{
  'w89': {
    'soldier': (0, 0, 0, 'hp 113 mp 20 heals false speed 27.5 dmg 12.5 range 14.399999999999999 rate 0.6400000000000001 shotSpeed 0.0 splash 0.0 regen 0.0 def 0.0 mpRegen 1.0'),
    'knight': (0, 0, 0, 'hp 175 mp 20 heals false speed 37.5 dmg 39.0625 range 14.0 rate 0.5120000000000001 shotSpeed 0.0 splash 0.0 regen 0.0 def 5.0 mpRegen 1.0'),
    'swordsman': (0, 0, 0, 'hp 138 mp 30 heals false speed 28.0 dmg 17.5 range 13.0 rate 0.5 shotSpeed 0.0 splash 0.0 regen 0.0 def 0.0 mpRegen 1.5'),
    'archer': (2, 0, 0, 'hp 113 mp 45 heals false speed 42.96875 dmg 42.91534423828125 range 570.6304286883839 rate 0.10066329600000004 shotSpeed 200.0 splash 0.0 regen 0.0 def 0.0 mpRegen 2.25'),
    'lancer': (0, 0, 0, 'hp 150 mp 20 heals false speed 63.4765625 dmg 22.5 range 22.0 rate 0.8 shotSpeed 0.0 splash 0.0 regen 0.0 def 0.0 mpRegen 1.0'),
    'priest': (5, 2, 4, 'hp 205 mp 135 heals true speed 20.0 dmg 113.95371093750002 range 286.6544639999999 rate 0.3145728000000001 shotSpeed 0.0 splash 0.0 regen 30.0 def 15.0 mpRegen 6.75'),
    'armored_axeman': (5, 2, 6, 'hp 815 mp 45 heals false speed 35.15625 dmg 263.59055126085883 range 14.0 rate 0.28835840000000007 shotSpeed 0.0 splash 16.0 regen 30.0 def 27.0 mpRegen 2.25'),
    'wizard': (5, 2, 1, 'hp 149 mp 180 heals false speed 18.0 dmg 172.10841178894043 range 371.5041853439999 rate 0.18790481920000002 shotSpeed 140.0 splash 20.0 regen 30.0 def 0.0 mpRegen 9.0'),
    'knight_templar': (2, 0, 0, 'hp 630 mp 60 heals false speed 68.66455078125 dmg 148.773193359375 range 20.16 rate 1.0 shotSpeed 0.0 splash 0.0 regen 45.0 def 18.0 mpRegen 3.0'),
  },
  'w8': {
    'soldier': (0, 0, 0, 'hp 90 mp 20 heals false speed 22.0 dmg 10.0 range 12.0 rate 0.8 shotSpeed 0.0 splash 0.0 regen 0.0 def 0.0 mpRegen 1.0'),
    'knight': (0, 0, 0, 'hp 140 mp 20 heals false speed 24.0 dmg 20.0 range 14.0 rate 0.6400000000000001 shotSpeed 0.0 splash 0.0 regen 0.0 def 2.5 mpRegen 1.0'),
    'swordsman': (0, 0, 0, 'hp 110 mp 30 heals false speed 28.0 dmg 14.0 range 13.0 rate 0.5 shotSpeed 0.0 splash 0.0 regen 0.0 def 0.0 mpRegen 1.5'),
    'archer': (0, 0, 0, 'hp 60 mp 30 heals false speed 22.0 dmg 9.0 range 64.0 rate 0.6 shotSpeed 200.0 splash 0.0 regen 0.0 def 0.0 mpRegen 1.5'),
    'lancer': (0, 0, 0, 'hp 120 mp 20 heals false speed 26.0 dmg 18.0 range 22.0 rate 1.0 shotSpeed 0.0 splash 0.0 regen 0.0 def 0.0 mpRegen 1.0'),
    'priest': (0, 0, 0, 'hp 60 mp 60 heals true speed 20.0 dmg 18.0 range 115.19999999999999 rate 1.2 shotSpeed 0.0 splash 0.0 regen 5.0 def 2.5 mpRegen 3.0'),
    'armored_axeman': (0, 0, 0, 'hp 216 mp 20 heals false speed 18.0 dmg 26.4 range 14.0 rate 1.1 shotSpeed 0.0 splash 16.0 regen 0.0 def 0.0 mpRegen 1.0'),
    'wizard': (0, 0, 0, 'hp 50 mp 80 heals false speed 18.0 dmg 22.0 range 72.0 rate 1.4 shotSpeed 140.0 splash 20.0 regen 0.0 def 0.0 mpRegen 4.0'),
    'knight_templar': (0, 0, 0, 'hp 336 mp 40 heals false speed 18.0 dmg 31.2 range 14.0 rate 1.0 shotSpeed 0.0 splash 0.0 regen 0.0 def 0.0 mpRegen 2.0'),
  },
};

String stats(Stats s) => 'hp ${s.hp} mp ${s.mp} heals ${s.heals} speed ${s.speed} dmg ${s.dmg} range ${s.range} rate ${s.rate} '
    'shotSpeed ${s.shotSpeed} splash ${s.splash} regen ${s.regen} def ${s.def} mpRegen ${s.mpRegen}';

/// [type]'s level, Bangkit and Tempa that count, and stats in [g].
(int, int, int, String) standing(Game g, String type) => (g.awakenLevel(type), g.ascended[type] ?? 0, g.tempaOf(type), stats(g.statsOf(type)));

void main() {
  test('the forge plays in every game, a plain Game() too (decisions-log 321)', () {
    for (final g in [Game().boardRules(), Game()]) {
      expect((g.byGrade, g.enhanceOn, g.forgeShop, g.smithyItems(1).length), (true, true, true, 14));
    }
  });

  test("the telemetry's and the events' version 10 or later: the forge's fields reach every player's records now", () {
    expect((telemetryVersion >= 10, eventVersion >= 10), (true, true)); // 11: the Tavern's (decisions-log 268)
    final g = Game().boardRules();
    expect((g.towns, passedOn.containsAll([EventKind.itemCrafted, EventKind.stoneCrafted, EventKind.itemEnhanced])),
        (true, true));
  });

  test('the w89 save (items by the old rule, Bangkit 5 and Tempa): every type keeps its level, Bangkit, Tempa and stats',
      () {
    final on = load(json(w89));
    expect(on.byGrade, isTrue);
    expect(on.awakenKept, {'priest': 3, 'armored_axeman': 3, 'archer': 2, 'wizard': 3, 'knight_templar': 2});
    for (final type in troopTypes.keys) {
      expect(standing(on, type), _before['w89']![type], reason: type);
      expect(on.awakenKept[type] ?? 0, on.oldItemLevel(type), reason: type);
    }
    // What the game from before the forge reads: Awaken 5 with its Tempa for the three that bought Bangkit 5.
    expect([for (final t in ['priest', 'armored_axeman', 'wizard']) (on.awakenLevel(t), on.tempaOf(t))], [(5, 4), (5, 6), (5, 1)]);
    // Without the floor the grade sets would hold nothing: the forge's new kinds are in every set.
    final bare = load(json(w89))..awakenKept.clear();
    expect([for (final type in troopTypes.keys) bare.awakenLevel(type)], everyElement(0));
    // The by-grade game always writes the key.
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
    final on = load(json(w8));
    for (final type in troopTypes.keys) {
      expect(standing(on, type), _before['w8']![type], reason: type);
    }
    expect(on.gold, 279);
    expect(on.inventory, {Item.potion: 1, Item.shield: 0, Item.bow: 0, Item.staff: 2, Item.gloves: 1, Item.sword: 1});
    expect(on.relicBag, isEmpty);
  });
}
