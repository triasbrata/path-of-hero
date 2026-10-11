import 'dart:math';

import 'package:flame/game.dart' hide Game;
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';
import 'package:tower_defense/main.dart';

// #55 unit plates (lib/plates.dart; ui-hud.md "Unit plates"): what a monster's plate says, and the pin
// rules as the player gets them (one TdGame, pressed with tester.tapAt, as in hud_test.dart).
//
// Never let a wave be won or the game end here: the Board then saves the game, or asks for a name and keeps
// the score, in the owner's real files (docs/testing.md). Every unit stands still (busyUntil), and a monster
// always stays on the field.

/// stunUntil for a unit that stands still and never fights (busyUntil would draw a summoner's strip,
/// which only the summoners have).
const hold = 1e9;

/// Advances the game [n] frames.
Future<void> frames(WidgetTester tester, [int n = 2]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

/// [u] on [g]'s field, standing still.
Unit put(Game g, Unit u) {
  u
    ..entered = true
    ..arriving = false
    ..stunUntil = hold;
  g.units.add(u);
  return u;
}

Unit troopAt(Game g, String type, double x, double y) => put(g, Unit(Side.troop, type, troopTypes[type]!, Point(x, y)));

Unit monsterAt(Game g, String type, double x, double y, [Tier tier = Tier.normal]) => put(g, g.monster(type, tier, Point(x, y)));

void main() {
  test("a monster's plate: its type's name, its rank, what kind it is, and its HP now / max", () {
    final g = Game();
    final healer = g.monster(necroHealer, Tier.elite, const Point(100, 50))..hp = 34.2;
    final plate = monsterPlate(healer);
    expect((plate.name, plate.tier, plate.hp), (monsterTypeNames[necroHealer], tierNames[Tier.elite], 'HP 35/${healer.maxHp}'));
    expect(plate.kinds, ['Undead', 'Healer']);
    final necro = g.monster(boss, Tier.boss, const Point(100, 50));
    expect((monsterPlate(necro).name, monsterPlate(necro).tier), (monsterTypeNames[boss], tierNames[Tier.boss]));
    expect(monsterPlate(necro).kinds, ['Undead', 'Summoner']);
    final raised = g.monster('skeleton', Tier.highElite, const Point(100, 50))..raisedBy = necro;
    expect(monsterPlate(raised).tier, tierNames[Tier.highElite]);
    expect(monsterPlate(raised).kinds, ['Undead', 'Raised']);
    final slime = g.monster('slime', Tier.miniBoss, const Point(100, 50))..hp = -3; // overkilled: 0, not negative
    expect((monsterPlate(slime).name, monsterPlate(slime).tier, monsterPlate(slime).hp), (monsterTypeNames['slime'], tierNames[Tier.miniBoss], 'HP 0/${slime.maxHp}'));
    expect(monsterPlate(slime).kinds, isEmpty);
    // Every monster the game makes has a name, and every rank one.
    expect(monsterTypeNames.keys.toSet(), {...enemyTypes.keys, boss, necroHealer});
    expect(tierNames.keys.toSet(), Tier.values.toSet());
  });

  testWidgets('a tap pins a unit\'s plate, anywhere else or its death unpins it, and a drag or hover leaves it', (tester) async {
    tester.view
      ..physicalSize = const Size(1266, 713)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final game = TdGame();
    await tester.pumpWidget(GameWidget(game: game));
    for (var i = 0; i < 3000 && !game.isLoaded; i++) {
      await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 20)));
      await tester.pump();
    }
    expect(game.isLoaded, isTrue);
    final b = game.board..welcome = null;
    Offset on(Unit u) => b.toScreen(u.pos.x, u.pos.y - 7); // the middle of its body

    // Between waves (the open book covers the field's right three quarters): two troops on the left.
    final g = b.state = Game()..units.clear();
    final knight = troopAt(g, 'knight', 40, 60), archer = troopAt(g, 'archer', 40, 100);
    await frames(tester, 30);
    await tester.tapAt(on(knight));
    await frames(tester);
    expect(b.pinned, knight);
    await tester.tapAt(on(knight)); // on it again: it stays
    await frames(tester);
    expect(b.pinned, knight);
    await tester.tapAt(on(archer)); // another: the pin moves
    await frames(tester);
    expect(b.pinned, archer);
    await tester.tapAt(b.toScreen(80, 30)); // bare field: unpinned
    await frames(tester);
    expect(b.pinned, isNull);
    // Dragging a troop to a new spot is no tap: the pin stays where it was, and the troop still moves.
    await tester.tapAt(on(knight));
    await frames(tester);
    final post = archer.post;
    await tester.dragFrom(b.toScreen(archer.pos.x, archer.pos.y), const Offset(0, -2 * tile * 713 / 192));
    await frames(tester);
    expect(b.pinned, knight);
    expect(archer.post, isNot(post));

    // During a wave (three monsters standing still, so it's never won): a monster pins too, and pointing at
    // another unit still shows its plate meanwhile.
    final w = b.state = Game()..units.clear();
    final soldier = troopAt(w, 'soldier', 150, 60);
    w
      ..startWave()
      ..queue.clear(); // nothing more comes
    final slime = monsterAt(w, 'slime', 190, 60), orc = monsterAt(w, 'orc', 190, 100, Tier.elite), bat = monsterAt(w, 'bat', 210, 30);
    await frames(tester, 120); // the book closes and the view settles
    await tester.tapAt(on(slime));
    await frames(tester);
    expect(b.pinned, slime);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: on(soldier));
    await mouse.moveTo(on(soldier) + const Offset(1, 0));
    await frames(tester, 30);
    expect((b.pinned, b.hovered), (slime, soldier));
    await mouse.moveTo(on(slime)); // the pinned one: no second plate for it
    await frames(tester, 30);
    expect((b.pinned, b.hovered), (slime, null));
    await mouse.removePointer();
    // It dies: unpinned.
    slime
      ..hp = 0
      ..dying = 0;
    await frames(tester);
    expect(b.pinned, isNull);
    // One that leaves the field: unpinned (the bat stays: the wave goes on).
    await tester.tapAt(on(orc));
    await frames(tester);
    expect(b.pinned, orc);
    orc.gone = true;
    await frames(tester);
    expect(b.pinned, isNull);
    expect(w.enemies.where((u) => u.alive), [bat]);

    // A button takes its press as ever, and the press unpins: the start button between waves.
    final s = b.state = Game()..units.clear();
    final priest = troopAt(s, 'priest', 40, 60);
    await frames(tester, 60);
    await tester.tapAt(on(priest));
    await frames(tester);
    expect(b.pinned, priest);
    await tester.tapAt(b.startButton.center);
    await frames(tester, 4); // (and the tap's 40 ms gesture timer runs out)
    expect((s.wave, s.waveActive, b.pinned), (1, true, null));
  });
}
