// The owner's limits (decisions-log 141, 201, 260; docs/units-and-combat.md "The owner's limits"): at most 36 troops alive
// whatever the capacity, at most a cap of troops of each type alive (priest 5, archer and wizard 8, the melee 10; the
// 4-type roster is gone), Lepas jenis, and the Auto hold's rule. Both limits are switches the board turns on
// ([Game.boardRules]); a plain Game() plays as before. The board's side: army_cap_ui_test.dart.
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';

import 'hero_skill_helpers.dart';

/// The owner's wave-86 save from before the limits (5,506 bytes): 48 troops of 5 types (priest 17, templar 13, wizard
/// 9, axeman 6, archer 3), capacity 48, the one Hero a priest; two archers hold fury and fang.
Map<String, dynamic> w86() => jsonDecode(File('test/fixtures/save-20261001-2005-pre-awaken.json').readAsStringSync()) as Map<String, dynamic>;

/// A game with the limits on, a 6-column zone (48 cells), no free healer and gold to spare.
Game limited() => bareGame()..boardRules();

/// Takes [n] living troops off the field (as if they fell), the last ones first.
void drop(Game g, int n) {
  for (final u in g.troops.where((u) => u.alive).toList().reversed.take(n)) {
    g.units.remove(u);
  }
}

/// Buys a [type] troop onto the first free cell; whether it was bought.
bool buy(Game g, String type) => g.autoPlace(type);

void main() {
  test('a plain Game() has neither limit: the cap is the capacity, no type cap, no Auto hold', () {
    final g = Game();
    expect((g.armyMax, g.typeCap, g.armyCap, g.maxCapacity, g.autoHeld), (null, null, g.capacity, g.maxZoneCols * rows, false));
    final wide = bareGame();
    for (var i = 0; i < 12; i++) {
      expect(buy(wide, 'priest'), isTrue, reason: '$i');
    }
    expect((wide.typeCapOf('priest'), wide.typeFull('priest'), wide.typeRefusal('priest')), (null, false, null));
    expect(wide.overCaps, isEmpty);
    for (final type in troopTypes.keys) {
      expect(buy(wide, type), isTrue, reason: type);
    }
  });

  test('boardRules turns on 36 troops (32 until decisions-log 260) and the type caps: the healer 5, the long range 8, the '
      'melee 10', () {
    final g = Game().boardRules();
    expect((g.armyMax, g.typeCap), (armyMaxBoard, typeCapBoard));
    expect((armyMaxBoard, autoHoldShare, releaseRefund), (36, 0.75, 0.5));
    expect(typeCapBoard, {
      'soldier': 10, 'knight': 10, 'swordsman': 10, 'archer': 8, 'lancer': 10, 'priest': 5, 'armored_axeman': 10, 'wizard': 8,
      'knight_templar': 10,
    });
    expect(typeCapBoard.keys, troopTypes.keys, reason: 'every troop type has one');
    for (final type in troopTypes.keys) {
      expect(g.typeCapOf(type), typeCapBoard[type], reason: type);
      expect(troopTypePlurals[type], isNotNull, reason: type);
    }
    // No type fills the army alone, nor three; four do unless the healer is one of them; any five do.
    int sum(List<String> types) => types.fold(0, (a, t) => a + typeCapBoard[t]!);
    final caps = typeCapBoard.values.toList()..sort();
    expect((caps.last < armyMaxBoard, caps.reversed.take(3).fold(0, (a, n) => a + n) < armyMaxBoard), (true, true));
    expect(sum(['priest', 'soldier', 'knight', 'swordsman']), 35);
    expect(sum(['archer', 'wizard', 'soldier', 'knight']), armyMaxBoard);
    expect(sum(['priest', 'archer', 'wizard', 'soldier', 'knight']), greaterThanOrEqualTo(armyMaxBoard), reason: 'the least five');
  });

  group('the army cap', () {
    test('capacity buys stop at 36 ("Room: max"), and the army is full at 36: "Army full 36/36"', () {
      final g = Game().boardRules()..gold = 100000;
      expect(g.maxZoneCols * rows, 48, reason: 'the default view holds more than the cap');
      expect(g.maxCapacity, armyMaxBoard);
      var bought = 0;
      while (g.buyCapacity()) {
        bought++;
      }
      expect((bought, g.capacity, g.canBuyCapacity), (15, 36, false)); // 6 + 15 x 2
      while (g.armySize < 36) {
        expect(buy(g, ['swordsman', 'soldier', 'lancer', 'knight'][g.armySize % 4]), isTrue, reason: '${g.armySize}');
      }
      expect((g.full, g.armyCap), (true, 36));
      final gold = g.gold;
      expect(g.buyRefusal('soldier'), '${Words.army} full 36/36');
      expect(buy(g, 'soldier'), isFalse);
      expect((g.armySize, g.gold), (36, gold));
    });

    test('under the cap, a full capacity still says "No room"', () {
      final g = Game().boardRules()..gold = 100000;
      for (var i = 1; i < capacityStart; i++) {
        expect(buy(g, 'soldier'), isTrue);
      }
      expect((g.full, g.armyCap, g.buyRefusal('soldier')), (true, capacityStart, buyRefusals.full));
    });

    test('the w86 save keeps all 48 and its capacity; buys wait until 35 or fewer are alive', () {
      final g = Game.fromJson(w86())..boardRules();
      expect((g.armySize, g.capacity, g.armyCap, g.maxCapacity, g.canBuyCapacity), (48, 48, 36, 36, false));
      expect((g.full, g.buyRefusal('soldier')), (true, '${Words.army} full 48/36'));
      drop(g, 12);
      expect((g.armySize, g.full, g.buyRefusal('soldier')), (36, true, '${Words.army} full 36/36'));
      drop(g, 1);
      expect(g.buyRefusal('soldier'), isNull);
      expect(buy(g, 'soldier'), isTrue);
      expect((g.armySize, buy(g, 'soldier')), (36, false));
    });

    test('Resurrection stops at the cap: 37 alive, one falls, and nobody rises', () {
      bool revivesAt(int alive, {required bool limits}) {
        final (g, h) = heroCaster(HeroSkill.revive);
        if (limits) g.boardRules();
        final t = placeNow(g, 'soldier', 4, 3)
          ..cd = hold
          ..hp = 1;
        for (var i = g.armySize; i < alive; i++) {
          g.units.add(Unit(Side.troop, 'knight', g.statsOf('knight'), const Point(8, 8))
            ..entered = true
            ..busyUntil = hold
            ..cd = hold); // past the gate, like an old save's army
        }
        final foe = foeAt(g, 'orc', t.pos + const Point(12, 0))
          ..busyUntil = double.negativeInfinity
          ..cd = 0;
        g.tick(0.05);
        foe.busyUntil = hold;
        expect((t.alive, g.armySize), (false, alive - 1));
        g.tick(0.05);
        return h.heroSkillAt == g.t;
      }

      expect(revivesAt(33, limits: false), isTrue, reason: 'capacity 48: room for one more');
      expect(revivesAt(37, limits: true), isFalse, reason: '36 alive: the cap');
      expect(revivesAt(36, limits: true), isTrue, reason: '35 alive');
    });
  });

  group('the type caps', () {
    test('a type stops at its cap, mid-wave too: "Priests full 5/5"; the other types still buy', () {
      final g = limited();
      for (var i = 0; i < 5; i++) {
        expect(buy(g, 'priest'), isTrue, reason: '$i');
      }
      expect((g.aliveOf('priest'), g.typeFull('priest'), g.buyRefusal('priest')), (5, true, 'Priests full 5/5'));
      final (gold, alive) = (g.gold, g.armySize);
      expect(buy(g, 'priest'), isFalse);
      expect(g.place('priest', g.baseCol + 2, 0), isFalse);
      expect((g.gold, g.armySize, g.aliveOf('priest')), (gold, alive, 5));
      expect(buy(g, 'archer'), isTrue, reason: 'another type still buys');
      g
        ..startWave()
        ..queue.clear();
      g.units.add(g.monster('orc', Tier.normal, const Point(200, 40))..busyUntil = hold); // the wave goes on
      expect(g.waveActive, isTrue);
      while (g.aliveOf('archer') < typeCapBoard['archer']!) {
        expect(buy(g, 'archer'), isTrue, reason: 'mid-wave ${g.aliveOf('archer')}');
      }
      expect((buy(g, 'archer'), g.buyRefusal('archer')), (false, 'Archers full 8/8'));
      expect(g.buyRefusal('armored_axeman'), isNull);
      for (final type in troopTypes.keys) {
        expect(g.typeLocked(type), isFalse, reason: '$type: no type is locked out by the count of types');
      }
    });

    test('its Heroes count; one falls, and it buys again', () {
      final g = limited();
      for (var i = 0; i < 10; i++) {
        expect(buy(g, 'knight'), isTrue, reason: '$i');
      }
      g.troops.first.hero = true;
      expect(g.buyRefusal('knight'), 'Knights full 10/10');
      g.units.remove(g.troops.last);
      expect((g.aliveOf('knight'), g.typeFull('knight'), g.buyRefusal('knight')), (9, false, null));
      expect(buy(g, 'knight'), isTrue);
    });

    test('nine types fill the army, none locked; every refusal names its type', () {
      final g = limited();
      for (final type in troopTypes.keys) {
        expect(buy(g, type), isTrue, reason: type);
      }
      expect((g.typesAlive, g.armySize), (troopTypes.length, troopTypes.length));
      for (final type in troopTypes.keys) {
        while (buy(g, type)) {}
        expect(g.buyRefusal(type), anyOf('${troopTypePlurals[type]} full ${typeCapBoard[type]}/${typeCapBoard[type]}', startsWith('${Words.army} full')),
            reason: type);
      }
      expect(g.armySize, armyMaxBoard);
    });

    test('the w86 save keeps its 17 priests, 13 templars and 9 wizards; each type buys again under its cap', () {
      final g = Game.fromJson(w86())..boardRules();
      expect(g.troopCounts, {'archer': 3, 'priest': 17, 'armored_axeman': 6, 'wizard': 9, 'knight_templar': 13});
      expect((g.buyRefusal('priest'), g.buyRefusal('knight_templar'), g.buyRefusal('wizard')),
          ('Priests full 17/5', 'Templars full 13/10', 'Wizards full 9/8'));
      expect(g.buyRefusal('archer'), '${Words.army} full 48/36');
      expect(g.overCaps, ['Priest 17/5', 'Wizard 9/8', 'Templar 13/10']);
      // 13 priests and 4 templars fall: 31 alive, the priests at 4.
      for (final (type, n) in [('priest', 13), ('knight_templar', 4)]) {
        for (final u in g.troops.where((u) => u.alive && u.type == type && !u.hero).take(n).toList()) {
          g.units.remove(u);
        }
      }
      expect((g.armySize, g.aliveOf('priest'), g.buyRefusal('priest')), (31, 4, null));
      expect(buy(g, 'priest'), isTrue);
      expect((g.buyRefusal('priest'), buy(g, 'priest')), ('Priests full 5/5', false));
    });

    test('a save no longer writes the roster, and an older save\'s is ignored', () {
      final g = limited();
      buy(g, 'archer');
      final j = jsonDecode(jsonEncode(g.toJson())) as Map<String, dynamic>;
      expect(j.containsKey('runTypes'), isFalse);
      j['runTypes'] = ['dragon', 'knight', 'archer'];
      final back = Game.fromJson(j)..boardRules();
      expect(back.troopCounts, {'archer': 1});
      expect(back.buyRefusal('soldier'), isNull);
    });

    test('autoPlace and place are the one gate: a full type and a full army are refused either way', () {
      final g = limited();
      for (var i = 0; i < 5; i++) {
        expect(g.place('priest', g.baseCol, i), isTrue);
      }
      expect((g.place('priest', g.baseCol + 1, 0), buy(g, 'priest')), (false, false));
      g.armyMax = g.armySize; // the cap reached
      expect(g.buyRefusal('soldier'), '${Words.army} full 5/5');
      expect((g.place('soldier', g.baseCol + 1, 0), buy(g, 'soldier')), (false, false));
    });

    test('Resurrection brings back only a type under its cap: a soldier at 10 stays down', () {
      bool revivesAt(int soldiers) {
        final (g, h) = heroCaster(HeroSkill.revive);
        g.boardRules();
        final t = placeNow(g, 'soldier', 4, 3)
          ..cd = hold
          ..hp = 1;
        for (var i = 1; i < soldiers; i++) {
          g.units.add(Unit(Side.troop, 'soldier', g.statsOf('soldier'), const Point(8, 8))
            ..entered = true
            ..busyUntil = hold
            ..cd = hold);
        }
        final foe = foeAt(g, 'orc', t.pos + const Point(12, 0))
          ..busyUntil = double.negativeInfinity
          ..cd = 0;
        g.tick(0.05);
        foe.busyUntil = hold;
        expect((t.alive, g.aliveOf('soldier')), (false, soldiers - 1));
        g.tick(0.05);
        return h.heroSkillAt == g.t;
      }

      expect(revivesAt(10), isTrue, reason: '9 alive: under the cap');
      expect(revivesAt(11), isFalse, reason: '10 alive: at the cap');
    });
  });

  group('"Ganti yang gugur" (#92) goes through the same gate', () {
    test('it buys back only up to the army\'s cap and its type\'s, and says why', () {
      final g = limited();
      for (final type in ['soldier', 'archer', 'priest', 'priest', 'priest', 'priest']) {
        expect(buy(g, type), isTrue);
      }
      g
        ..armyMax = 8
        ..toReplace.addAll([
          for (final type in ['soldier', 'soldier', 'soldier', 'priest', 'priest']) (type: type, post: Point(g.baseX + tile * 1.5, tile * 5.5)),
        ]);
      final back = g.replaceFallen(); // the cheapest first: the soldiers until the cap
      expect((back.bought, back.of, back.why), (2, 5, '${Words.army} full 8/8'));
      expect((g.armySize, g.toReplace.length, g.whyNotReplace), (8, 3, '${Words.army} full 8/8'));
      g.armyMax = armyMaxBoard;
      final more = g.replaceFallen(); // the last soldier, then one priest to 5
      expect((more.bought, more.why, g.toReplace.single.type), (2, 'Priests full 5/5', 'priest'));
      expect(g.whyNotReplace, 'Priests full 5/5');
    });

    test('Lepas jenis takes the released type\'s fallen off the offer', () {
      final g = limited();
      buy(g, 'soldier');
      buy(g, 'archer');
      g.toReplace.addAll([(type: 'soldier', post: const Point(24, 24)), (type: 'archer', post: const Point(24, 40))]);
      g.releaseType('soldier');
      expect(g.toReplace.single.type, 'archer');
    });
  });

  group('Lepas jenis', () {
    test('between waves: the type\'s troops go home for half their price, their relics to the bag', () {
      final g = Game.fromJson(w86())..boardRules();
      final events = <GameEvent>[];
      g.listeners.add(events.add);
      final price = g.priceOf('archer'), gold = g.gold;
      final (fury, fang) = (g.relicBag[Relic.fury]!, g.relicBag[Relic.fang]!);
      expect(g.whyNotRelease('archer'), isNull);
      final refund = g.releaseType('archer');
      expect(refund, (3 * price * releaseRefund).round());
      expect((g.gold, g.armySize, g.troopCounts.containsKey('archer')), (gold + refund!, 45, false));
      expect(g.units.where((u) => u.type == 'archer'), isEmpty, reason: 'off the field, not fallen');
      expect((g.relicBag[Relic.fury], g.relicBag[Relic.fang]), (fury + 1, fang + 1));
      expect((g.typesAlive, g.fallen.length, g.whyNotRelease('archer')), (4, 0, releaseRefusals.none));
      expect(events.whereType<TypeReleased>().single.toJson(),
          {'v': eventVersion, 'kind': 'typeReleased', 'wave': 86, 't': g.t, 'type': 'archer', 'troops': 3, 'refund': refund});
      // The wizards over their cap (9/8) go home too: the room is the soldiers'.
      g.releaseType('wizard');
      expect((g.armySize, g.buyRefusal('wizard')), (36, '${Words.army} full 36/36'));
      expect(g.overCaps, ['Priest 17/5', 'Templar 13/10']);
    });

    test('refused for a type with none alive, mid-wave and while a Hero of it lives', () {
      final g = limited();
      buy(g, 'knight');
      buy(g, 'priest');
      g.units.removeWhere((u) => u.type == 'knight');
      expect((g.whyNotRelease('knight'), g.releaseType('knight')), (releaseRefusals.none, null));

      g.troops.single.hero = true;
      expect(g.whyNotRelease('priest'), releaseRefusals.hero);
      g.sfx.clear();
      expect(g.releaseType('priest'), isNull);
      expect((g.troops.single.type, g.armySize, g.sfx.single), ('priest', 1, Sfx.error));

      g.troops.single.hero = false;
      g
        ..startWave()
        ..queue.clear();
      g.units.add(g.monster('orc', Tier.normal, const Point(200, 40))..busyUntil = hold);
      expect((g.whyNotRelease('priest'), g.releaseType('priest')), (takeOffRefusals.midWave, null));
      g.lives = 0;
      expect(g.whyNotRelease('priest'), assignRefusals.over);
    });
  });

  group('the Auto hold', () {
    test('with the cap on, Auto waits while fewer than 75% of the cap are alive', () {
      final g = Game.fromJson(w86())..boardRules();
      expect(g.autoHeld, isFalse, reason: '48 of 36');
      drop(g, 21);
      expect((g.armySize, g.autoHeld), (27, false)); // 27 = 75% of 36
      drop(g, 1);
      expect(g.autoHeld, isTrue);
      g.armyMax = null;
      expect(g.autoHeld, isFalse, reason: 'the cap off');
      final early = Game().boardRules()..gold = 1000;
      expect((early.armyCap, early.autoHeld), (capacityStart, true), reason: '1 of 6');
      for (var i = 0; i < 4; i++) {
        buy(early, 'soldier');
      }
      expect((early.armySize, early.autoHeld), (5, false));
    });
  });

  group('the one-time notes', () {
    test('the w86 save is told once that it keeps its 48 troops (and pays in tide for them, Beban) and its types over '
        'their caps; the notes are saved', () {
      final g = Game.fromJson(w86())..boardRules();
      final notes = g.limitNotes();
      expect(notes, [
        'The army cap is now 36. You keep your troops;\nbuy more when under 36.',
        overNote(36), // decisions-log 162
        'Each troop type has a cap now. You keep yours;\nover it: Priest 17/5, Wizard 9/8, Templar 13/10.\n'
            'Buy more of a type when under its cap.', // decisions-log 201
      ]);
      expect(capsNote(['A 1/0', 'B 1/0', 'C 1/0', 'D 1/0']), contains('over it: A 1/0, B 1/0, C 1/0,\nD 1/0.\n'), reason: 'three a line');
      expect(g.limitNotes(), isEmpty, reason: 'once');
      final again = Game.fromJson(jsonDecode(jsonEncode(g.toJson())) as Map<String, dynamic>)..boardRules();
      expect(again.notes, {'army', 'over', 'caps'});
      expect(again.limitNotes(), isEmpty);
      expect(Game.fromJson(w86()).limitNotes(), isEmpty, reason: 'the limits off');
      expect(Game().boardRules().limitNotes(), isEmpty, reason: 'a game within them');
    });
  });
}
