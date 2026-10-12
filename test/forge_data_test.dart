// The forge's data (decisions-log 245; docs/loot-items-relics.md "The forge: data"): town.json version 3 (every item's
// recipe and effect, every small relic's numbers and recipe with what the forge changes, the combos, Awaken by grade and
// Enhance) read beside a version-2 file; [Item] with a kind and a grade per value, [Relic]'s nine new small ones, the
// two stones ([craftedMats]) and their icons; and the save's version 3, which a version-2 save loads forward into. The
// forge plays in every game, a plain Game() too (its off switch went in decisions-log 296, the Towns' in 321).
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';
import 'package:tower_defense/main.dart' show BagCategory, bagKinds, smithyRelics;
import 'package:tower_defense/save.dart';

const _v2Save = 'test/fixtures/save-20261004-1919-w8-v2.json', _v2Town = 'test/fixtures/town-v2.json';

/// The shipped town.json, read.
TownRules shipped() => TownRules.parse(File('assets/config/town.json').readAsStringSync());

/// The owner's version-2 save (wave 8, a Town due: a copy taken before the forge) as JSON.
Map<String, dynamic> v2Save() => jsonDecode(File(_v2Save).readAsStringSync()) as Map<String, dynamic>;

/// The shipped town.json with [change] made to its JSON, read.
TownRules edited(void Function(Map<String, dynamic> j) change) {
  final j = jsonDecode(File('assets/config/town.json').readAsStringSync()) as Map<String, dynamic>;
  change(j);
  return TownRules.parse(jsonEncode(j));
}

/// A board game (the Towns, and with them the forge, on).
Game board() => Game(Random(1), Random(2))..boardRules();

/// A PNG's width and height, from its header.
(int, int) pngSize(File f) {
  final b = f.readAsBytesSync();
  int at(int i) => (b[i] << 24) | (b[i + 1] << 16) | (b[i + 2] << 8) | b[i + 3];
  return (at(16), at(20));
}

void main() {
  group('Item and Relic (decisions-log 245)', () {
    test('every item has a kind and a grade: each kind once at each grade, counted from the enum; the first ones are '
        'the grade-I items monsters drop, in the order the drop dice index', () {
      for (final slot in ItemSlot.values) {
        expect([for (final i in Item.values) if (i.slot == slot) i.grade], [1, 2, 3], reason: '$slot');
      }
      expect(Item.values.length, ItemSlot.values.length * 3);
      expect(droppedItems, Item.values.take(droppedItemKinds), reason: 'the drop dice: Item.values[loot.nextInt($droppedItemKinds)]');
      expect([for (final i in droppedItems) (i.slot.name, i.grade)], [for (final i in droppedItems) (i.name, 1)],
          reason: 'the seven of before, their own kind, grade I');
      expect({for (final r in awakenRecipe.values) ...r.keys}, droppedItems.toSet(), reason: 'every Awaken recipe kind drops');
      expect({for (final i in Item.values.skip(droppedItemKinds)) i.slot}, ItemSlot.values.toSet(),
          reason: 'the forge adds grades to every kind, five new kinds, the helm and the ring');
    });

    test("the forge's relics: small ones appended, never dropped, never offered, out of smallRelics", () {
      expect(Relic.values.skip(Relic.values.length - forgeRelics.length), forgeRelics, reason: 'appended');
      for (final r in forgeRelics) {
        expect((r.scope, r.pusaka, r.store, r.rarity), (RelicScope.troop, false, false, Rarity.biasa), reason: '$r');
        expect(pusakaCatalog.containsKey(r), isFalse, reason: '$r is no Artifact');
      }
      expect(smallRelics.toSet().intersection(forgeRelics.toSet()), isEmpty);
      expect([for (final r in Relic.values) if (r.scope == RelicScope.troop) r], [...smallRelics, ...forgeRelics]);
      expect(droppedRelics.toSet().intersection(forgeRelics.toSet()), isEmpty);
    });

    test('names: English, one each, none shared with an item, a relic or an Artifact; every card says only its own '
        'effect', () {
      final names = [...itemNames.values, ...relicNames.values];
      expect(itemNames.keys, Item.values);
      expect(relicNames.keys.toSet().containsAll(forgeRelics), isTrue);
      expect(names.toSet().length, names.length, reason: 'a name twice');
      for (final n in [for (final i in Item.values.skip(droppedItemKinds)) itemNames[i]!, for (final r in forgeRelics) relicNames[r]!]) {
        expect(RegExp(r'^[A-Z][a-z]+( [A-Z][a-z]+)?$').hasMatch(n), isTrue, reason: n);
      }
      final g = board();
      final others = [for (final r in Relic.values) relicNames[r]!];
      for (final r in forgeRelics) {
        final lines = g.relicEffect(r);
        expect(lines, hasLength(1), reason: '$r: one line');
        expect(lines.single.toLowerCase(), isNot(contains('combo')), reason: '$r');
        for (final o in others) {
          expect(lines.single.contains(o), isFalse, reason: '$r names $o');
        }
        expect(relicBestOn[r], hasLength(3), reason: '$r');
        expect(g.relicTierLine(r), endsWith('relic'));
      }
      for (final i in Item.values.skip(droppedItemKinds)) {
        expect(g.itemEffect(i), isNotEmpty, reason: '$i');
        for (final type in troopTypes.keys) {
          expect(g.itemInfo(i, type).$2, isNotEmpty, reason: '$i on $type');
        }
      }
      expect(g.relicEffect(Relic.chill), ['Every 3rd hit slows 30% for 1.5 s (bosses 15%)']);
      expect(g.relicEffect(Relic.weakSpot), ['Hits mark a monster 3 s: it takes +12% from all (bosses +6%)']);
      expect(g.itemEffect(Item.royalHelm).first, '-7% damage taken');
      expect([for (final i in [Item.goldAmulet, Item.saintBeads, Item.sunTorch, Item.royalSpear, Item.royalPrism]) g.itemEffect(i).first],
          ['+12% max HP', '+18% heal', '+18% damage to the undead', '+22% melee reach', '+22% splash area']);
      expect([for (final i in [Item.ring, Item.gemRing, Item.royalRing]) g.itemEffect(i).first],
          ['+0.1 ${Words.mp} every second', '+0.15 ${Words.mp} every second', '+0.2 ${Words.mp} every second']);
    });

    test('icons: one file each, 32x32, all different, from the import tool\'s list: every item, small relic and material '
        '(the two stones too)', () {
      final files = [
        for (final i in Item.values) 'item_${i.name}',
        for (final r in [...smallRelics, ...forgeRelics]) 'relic_${r.name}',
        for (final m in Mat.values) 'mat_${m.name}',
      ];
      final tool = File('tool/import_fx.py').readAsStringSync();
      final hashes = <String, String>{};
      for (final name in files) {
        final f = File('assets/images/$name.png');
        expect(f.existsSync(), isTrue, reason: name);
        expect(pngSize(f), (32, 32), reason: name);
        expect(tool, contains('    "$name": ('), reason: '$name: in tool/import_fx.py LOOT');
        final h = base64Encode(f.readAsBytesSync());
        expect(hashes[h], isNull, reason: '$name is ${hashes[h]}');
        hashes[h] = name;
      }
      expect(relicIcon(Relic.reaper).sheet, 'relic_reaper.png');
    }, tags: 'art'); // the pack's icons are all different; two placeholders may be one drawing

    test('the two stones: crafted materials after the 30, named, never dropped by any rule', () {
      final r = shipped();
      expect(Mat.values, [...droppedMats, ...craftedMats]);
      expect([for (final m in craftedMats) m.label], ['Mithril', 'Starmetal']);
      expect([for (final m in Mat.values) if (r.materials[m]!.grade == MatGrade.crafted) m], craftedMats);
      expect([for (final m in Mat.values) if (m.crafted) m], craftedMats);
      final dropped = {
        for (final ds in r.forgeDrops.values)
          for (final d in ds) ...d.plus.keys,
        ...r.necromancerPlus.keys,
        for (final (c, rare) in r.parts.values) ...[?c, ?rare],
      };
      expect(dropped.intersection(craftedMats.toSet()), isEmpty);
      expect(board().matSource(Mat.mithril), '${Words.madeAtSmithy}.');
    });
  });

  group('town.json version 3 (decisions-log 245)', () {
    test('the shipped file is version 3 and reads whole: every item, 20 relics, the combos, Awaken and Enhance; nothing '
        'skipped', () {
      final text = File('assets/config/town.json').readAsStringSync(), j = jsonDecode(text) as Map<String, dynamic>;
      final r = shipped();
      expect(j['version'], TownRules.version);
      expect(r.skipped, isEmpty);
      expect(r.items.keys, Item.values);
      expect(r.recipes.keys, [for (final k in [...smallRelics, ...forgeRelics]) k.name]);
      expect(r.relics.keys, r.recipes.keys);
      expect((j['items'] as Map).keys, [for (final i in Item.values) i.name]);
      expect((r.combos.relicMost, r.combos.secrets.length), (3.0, 4));
      expect(j.containsKey('recipes'), isFalse, reason: 'version 3 keeps each recipe in its relics entry');
      // Awaken by grade: a share per grade, as many as the items have.
      final grades = {for (final i in Item.values) i.grade};
      expect(r.awaken.share, [1.0, 1.0, 0.667]);
      expect(r.awaken.share, hasLength(grades.length));
      // Enhance: a stone, a gold and a tint per step; the stones are the crafted ones, made from what exists.
      final e = r.enhance;
      expect((e.from, e.most, e.per, e.tintAlpha), (30, 5, 0.10, 0.45));
      expect([e.gold.length, e.stone.length, e.tints.length], [e.most, e.most, e.most]);
      expect(e.gold, [500, 1000, 1500, 2500, 4000]);
      expect(e.stone.toSet(), craftedMats.toSet());
      expect(e.stones.keys, craftedMats);
      expect(e.stones[Mat.starmetal]!.materials, {Mat.soulOrb: 1, Mat.lichOrb: 1, Mat.mithril: 1});
      expect(e.tints, [0xFF3D8BFF, 0xFFE8203A, 0xFFFFC93C, 0xFF8E44FF, 0xFFF2F6FF]);
      expect(j['enhance']['tints'], ['#3D8BFF', '#E8203A', '#FFC93C', '#8E44FF', '#F2F6FF']);
    });

    test('Awaken and Enhance blocks: a bad share or a step list of the wrong length keeps the defaults and is noted', () {
      final odd = edited((j) {
        j['awaken'] = {'byGrade': false, 'share': [1, 2]}; // an old file's byGrade: ignored (decisions-log 296)
        j['enhance']['gold'] = [1, 2];
        j['enhance']['stones']['dragonGem'] = {'gold': 5};
      });
      expect(odd.awaken.share, const AwakenRules().share);
      expect(odd.enhance.gold, const EnhanceRules().gold);
      expect(odd.enhance.stones.keys, craftedMats);
      expect(odd.skipped, ['awaken.share: [1, 2]', 'enhance: gold, stone and tints need 5 steps each', 'enhance.stones: no dragonGem']);
      final more = edited((j) => j['enhance']
        ..['most'] = 2
        ..['gold'] = [10, 20]
        ..['stone'] = ['mithril', 'starmetal']
        ..['tints'] = ['#000000', '#ffffff']);
      expect(more.skipped, isEmpty);
      expect([more.enhance.most, more.enhance.gold, more.enhance.stone, more.enhance.tints],
          [2, [10, 20], [Mat.mithril, Mat.starmetal], [0xFF000000, 0xFFFFFFFF]]);
    });

    test("a version-2 file still reads: today's recipes and numbers, and the forge's defaults", () {
      final v2 = TownRules.parse(File(_v2Town).readAsStringSync()), v3 = shipped();
      expect(jsonDecode(File(_v2Town).readAsStringSync())['version'], 2);
      expect(v2.skipped, [for (final t in Tier.values) 'drops: no ${t.name}'], reason: 'the drops from before the forge, gone');
      // The Shop's opening aside: 15 in version 2's file, 1 since decisions-log 253 (a Town's Shop in every Town).
      Map<String, dynamic> from15(TownRules r) => r.toJson()..['shop'] = {...r.shop.toJson(), 'from': 15};
      expect((v2.shop.from, v3.shop.from, const TownRules().shop.from), (15, 1, 1));
      expect(v2.toJson(), from15(v3), reason: 'every number the same; the forge\'s blocks from their defaults');
      expect(v2.toJson(), from15(const TownRules()));
    });

    test("today's values unchanged: the eleven's recipes and numbers as version 2's, the grade-I items' effects the "
        "game's own", () {
      final old = jsonDecode(File(_v2Town).readAsStringSync()) as Map<String, dynamic>, r = shipped();
      for (final MapEntry(key: k, value: v) in (old['recipes'] as Map<String, dynamic>).entries) {
        expect(r.recipes[k]!.toJson(), v, reason: k);
      }
      for (final MapEntry(key: k, value: v) in (old['relics'] as Map<String, dynamic>).entries) {
        expect({for (final MapEntry(:key, :value) in r.relics[k]!.entries) if ((v as Map).containsKey(key)) key: value}, v, reason: k);
      }
      expect(r.relics['cleave']!['targets'], 1, reason: 'one more monster, as Sweep hits today');
      expect([for (final i in droppedItems) r.items[i]!.effect], [swordDmg, shieldDef, bootsSpeed, bowRange, glovesRate, potionRegen, staffDmg]);
      for (final k in ['schedule', 'parts', 'tiers']) {
        expect(r.toJson()[k], old[k], reason: k);
      }
      for (final k in ['necromancerSlot', 'forge']) {
        expect((r.toJson()['drops'] as Map)[k], (old['drops'] as Map)[k], reason: 'drops.$k');
      }
      expect({...r.shop.toJson(), 'from': 15}, old['shop'], reason: "the Shop's prices; its opening 1 since decisions-log 253");
      final mats = r.toJson()['materials'] as Map<String, dynamic>;
      expect({for (final m in droppedMats) m.name: mats[m.name]}, old['materials'], reason: 'the 30 as before');
    });

    test('every recipe takes materials that exist and items that exist: the Awaken kinds Commons only and no item, gold '
        'by grade; the Cap and the Ring their grade below; a Mighty relic a grade-II item with the forge; every dropped '
        'material is in some recipe', () {
      final r = shipped(), used = <Mat>{}, chained = <ItemSlot>{}, goldByGrade = <int, Set<int>>{};
      for (final MapEntry(key: i, value: rec) in r.items.entries) {
        expect(rec.materials, isNotEmpty, reason: '$i');
        expect(rec.materials.values.every((n) => n > 0), isTrue, reason: '$i');
        used.addAll(rec.materials.keys);
        if (rec.items.isNotEmpty) {
          expect(rec.items, {for (final l in Item.values) if (l.slot == i.slot && l.grade == i.grade - 1) l: 1}, reason: '$i');
          chained.add(i.slot);
        }
        expect(rec.gold, greaterThan(0), reason: '$i');
      }
      expect(chained, {ItemSlot.helm, ItemSlot.ring}, reason: 'only the Cap and the Ring take the grade below');
      for (final MapEntry(key: i, value: rec) in r.items.entries) {
        if (chained.contains(i.slot)) {
          expect([for (final l in Item.values) if (l.slot == i.slot) r.items[l]!.items.length], [0, 1, 1], reason: '$i');
          continue;
        }
        expect(rec.materials.keys.every((m) => r.materials[m]!.grade == MatGrade.common), isTrue, reason: '$i: Commons only');
        (goldByGrade[i.grade] ??= {}).add(rec.gold);
      }
      expect(goldByGrade, {1: {20}, 2: {60}, 3: {250}});
      for (final key in r.recipes.keys) {
        for (final rec in [r.recipes[key]!, r.forgeRecipe(key)!]) {
          expect(rec.materials, isNotEmpty, reason: key);
          used.addAll(rec.materials.keys);
          expect(rec.items.keys.every(Item.values.contains), isTrue, reason: key);
        }
        if (r.recipes[key]!.tier == RelicTier.mighty) {
          expect([for (final i in r.forgeRecipe(key)!.items.keys) i.grade], [2], reason: '$key takes a grade-II item with the forge');
        }
      }
      expect(used, droppedMats.toSet(), reason: 'every dropped material is in some recipe');
      for (final MapEntry(key: s, value: rec) in r.enhance.stones.entries) {
        expect((rec.materials.isNotEmpty, rec.gold > 0, rec.materials.containsKey(s)), (true, true, false), reason: '$s');
      }
      // What the forge changes: every relic's gold to 70%, rounded to 50; Mana Siphon's materials; the Mighty three's item.
      expect(r.forgeChanges.keys, townRelics);
      for (final k in townRelics) {
        expect(r.forgeRecipe(k)!.gold, (r.recipes[k]!.gold * 0.7 / 50).round() * 50, reason: k);
      }
      expect([for (final f in forgeRelics) r.recipes[f.name]!.gold], [200, 300, 300, 700, 700, 700, 2100, 2100, 2450],
          reason: 'the nine at the forge\'s gold already');
      expect(r.forgeRecipe('lastStand')!.items, {Item.towerShield: 1});
      expect(r.forgeRecipe('manaSiphon')!.materials, {Mat.boneArrow: 3, Mat.batFang: 2, Mat.slimeCore: 1, Mat.tealGem: 1});
      expect(r.forgeRecipe('fang')!.toJson(), {...r.recipes['fang']!.toJson(), 'gold': 200});
    });

    test('the combos: each secret names small relics, an Artifact where it names one, and numbers its relic has; a bad '
        'one is left out and noted', () {
      final c = shipped().combos;
      expect(c.secrets.keys, ['venom+sharkTooth', 'cleave+avalanche', 'weakSpot@voidEye', 'chill@snareCord']);
      for (final MapEntry(key: k, value: s) in c.secrets.entries) {
        expect(s.holds, contains(s.relic), reason: k);
        expect(s.holds.every((h) => !h.pusaka), isTrue, reason: k);
        expect(s.artifact?.pusaka ?? true, isTrue, reason: k);
        expect(shipped().relics[s.relic.name]!.keys, containsAll(s.set.keys), reason: k);
      }
      expect(c.secrets['chill@snareCord']!.set, {'every': 2});
      final odd = edited((j) => j['combos'] = {
        'relicMost': 0.5,
        'secret': {
          'ok': {'holds': ['fang'], 'relic': 'fang', 'set': {'share': 0.5}},
          'noRelic': {'holds': ['fang'], 'relic': 'thorns', 'set': {'share': 0.5}},
          'notArtifact': {'holds': ['fang'], 'artifact': 'fury', 'relic': 'fang', 'set': {'share': 0.5}},
          'noNumber': {'holds': ['fang'], 'relic': 'fang', 'set': {'reach': 2}},
          'aPusaka': {'holds': ['grail'], 'relic': 'grail', 'set': {'k': 2}},
        },
      });
      expect(odd.combos.relicMost, 3.0);
      expect(odd.combos.secrets.keys, ['ok']);
      expect(odd.skipped, [for (final k in ['noRelic', 'notArtifact', 'noNumber', 'aPusaka']) 'combos.secret.$k: not a secret']);
    });

    test('the file moves an item, a forge change and the cap; another version still gives every default', () {
      final p = edited((j) {
        j['items']['steelSword'] = {'gold': 999, 'effect': 1.5};
        j['relics']['lastStand']['forge'] = {'items': {'royalShield': 1}};
        j['combos']['relicMost'] = 4.0;
      });
      expect(p.skipped, isEmpty);
      expect((p.items[Item.steelSword]!.gold, p.items[Item.steelSword]!.effect), (999, 1.5));
      expect(p.items[Item.steelSword]!.materials, const TownRules().items[Item.steelSword]!.materials, reason: 'its defaults');
      expect(p.forgeRecipe('lastStand')!.items, {Item.royalShield: 1});
      expect(p.forgeRecipe('lastStand')!.gold, 3000, reason: 'what the forge block leaves out is the recipe\'s own');
      expect(p.combos.relicMost, 4.0);
      expect(TownRules.parse('{"version": 4, "combos": {"relicMost": 9.0}}').combos.relicMost, 3.0);
    });
  });

  group('the forge in every game (decisions-log 321)', () {
    test('a board game: every item, the 20 relics and the stones, the forge\'s recipes; a plain Game() the same', () {
      final plain = Game();
      expect([plain.itemsInPlay, plain.relicsInPlay, plain.matsInPlay], [Item.values, [...smallRelics, ...forgeRelics], Mat.values]);
      expect(plain.craftRecipe(Relic.lastStand)!.items, {Item.towerShield: 1});
      final g = board();
      expect([g.itemsInPlay, g.relicsInPlay, g.matsInPlay], [Item.values, [...smallRelics, ...forgeRelics], Mat.values]);
      expect(g.craftRecipe(Relic.lastStand)!.items, {Item.towerShield: 1});
      expect(g.craftRecipe(Relic.fang)!.gold, 200);
      expect(g.craftRecipe(Relic.reaper)!.items, {Item.longBow: 1});
      expect([for (final r in smithyRelics(g)) g.relicTier(r)], [
        ...List.filled(7, RelicTier.basic),
        ...List.filled(7, RelicTier.strong),
        ...List.filled(6, RelicTier.mighty),
      ]);
      g.inventory.addAll({for (final i in Item.values) i: 1});
      expect(bagKinds(g, BagCategory.items), Item.values);
      g.materials.addAll({for (final m in Mat.values) m: 1});
      expect(bagKinds(g, BagCategory.materials), Mat.values);
    });
  });

  group('the save, version 3 (decisions-log 245)', () {
    tearDown(clearSave);

    test("the owner's version-2 save loads forward: nothing discarded, its items and materials as saved; written back "
        'as version 3', () {
      final j = v2Save();
      expect(j['v'], 2);
      final g = Game.fromJson(j, Random(1), Random(2), Random(3));
      expect({for (final MapEntry(:key, :value) in g.inventory.entries) key.name: value}, j['inventory']);
      expect({for (final MapEntry(:key, :value) in g.upgrades.entries) key: [for (final i in value) i.name]}, j['upgrades']);
      expect({for (final MapEntry(:key, :value) in g.materials.entries) key.name: value}, j['materials']);
      expect((g.wave, g.gold, g.troops.length), (j['wave'], j['gold'], (j['troops'] as List).length));
      final out = jsonDecode(jsonEncode(g.toJson())) as Map<String, dynamic>;
      expect(out['v'], 3);
      for (final k in ['inventory', 'upgrades', 'materials', 'gold', 'wave']) {
        expect(out[k], j[k], reason: k);
      }
    });

    test('the launch keeps a version-2 save and offers it; a version-3 one too', () {
      dataFile('save.json')
        ..createSync(recursive: true)
        ..writeAsStringSync(File(_v2Save).readAsStringSync());
      expect((loadGame()?.wave, savedWave()), (8, 8));
      expect(launchSave()?.wave, 8);
      expect(dataFile('save.json').existsSync(), isTrue, reason: 'not deleted');
      final g = launchSave()!;
      expect(saveGame(g), isTrue);
      expect(jsonDecode(dataFile('save.json').readAsStringSync())['v'], Game.saveVersion);
      expect(launchSave()?.wave, 8);
    });

    test("a name this build doesn't know is skipped (an item, a relic), and the forge's names load", () {
      final j = v2Save()
        ..['inventory'] = {'sword': 2, 'excalibur': 1, 'steelSword': 3}
        ..['upgrades'] = {
          'knight': ['shield', 'excalibur', 'towerShield'],
        }
        ..['relicBag'] = {'fang': 1, 'moonBlade': 2, 'reaper': 1}
        ..['storeBought'] = {'sword': 1, 'chill': 2, 'moonBlade': 1};
      (j['troops'] as List).first['relics'] = ['moonBlade', 'grit'];
      final g = Game.fromJson(j, Random(1), Random(2), Random(3));
      expect(g.inventory, {Item.sword: 2, Item.steelSword: 3});
      expect(g.upgrades['knight'], [Item.shield, Item.towerShield]);
      expect(g.relicBag, {Relic.fang: 1, Relic.reaper: 1});
      expect(g.storeBought, {Item.sword: 1, Relic.chill: 2});
      expect(g.troops.first.relics, [Relic.grit]);
    });

    test('a stone never counts as dropped: a saved matsSeen naming one, or a save without matsSeen holding one', () {
      final seen = v2Save()..['matsSeen'] = ['mithril', 'slimeGel', 'starmetal'];
      expect(Game.fromJson(seen, Random(1), Random(2), Random(3)).matsSeen, {Mat.slimeGel});
      final held = v2Save()..['materials'] = {'batWing': 2, 'mithril': 1};
      final g = Game.fromJson(held, Random(1), Random(2), Random(3));
      expect(g.materials, {Mat.batWing: 2, Mat.mithril: 1});
      expect(g.matsSeen, {Mat.batWing});
    });
  });
}
