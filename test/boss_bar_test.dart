import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';

// #67 boss bars (lib/boss_bar.dart; ui-hud.md "Boss bars"): the layers' math, the names, and who has a bar.
// The drawing is checked by shots (the probe), not here.

void main() {
  group('the layers: one per 1000 HP, "×N" = hp / 1000 rounded up', () {
    test('13,000 HP: 13 layers, each 1000', () {
      expect(bossLayers(13000, 13000), (left: 13, fill: 1.0, total: 13));
      final hit = bossLayers(12999, 13000);
      expect((hit.left, hit.total), (13, 13));
      expect(hit.fill, closeTo(0.999, 1e-9));
      expect(bossLayers(12000, 13000), (left: 12, fill: 1.0, total: 13)); // a layer just broke
      final next = bossLayers(12000.5, 13000);
      expect(next.left, 13);
      expect(next.fill, closeTo(0.0005, 1e-9));
      expect(bossLayers(500, 13000), (left: 1, fill: 0.5, total: 13));
      final last = bossLayers(0.2, 13000); // a sliver: still ×1
      expect(last.left, 1);
      expect(last.fill, closeTo(0.0002, 1e-9));
    });

    test('what is over the whole thousands is the top layer, full at full health', () {
      expect(bossLayers(13500, 13500), (left: 14, fill: 1.0, total: 14));
      expect(bossLayers(13250, 13500), (left: 14, fill: 0.5, total: 14));
      expect(bossLayers(13000, 13500), (left: 13, fill: 1.0, total: 14));
      // Under 1000 HP (the first bosses): one layer, full at full health.
      expect(bossLayers(600, 600), (left: 1, fill: 1.0, total: 1));
      expect(bossLayers(150, 600), (left: 1, fill: 0.25, total: 1));
    });

    test('dead: no layers; and big numbers stay whole (#66 may make bosses far tougher)', () {
      expect(bossLayers(0, 13000), (left: 0, fill: 0.0, total: 13));
      expect(bossLayers(-40, 600), (left: 0, fill: 0.0, total: 1));
      expect(bossLayers(200000, 200000), (left: 200, fill: 1.0, total: 200));
      final big = bossLayers(123456, 200000);
      expect((big.left, big.total), (124, 200));
      expect(big.fill, closeTo(0.456, 1e-9));
      expect(bossLayers(1, 200000).left, 1);
    });
  });

  test('a boss\'s name: "<name> the <title>", its type\'s name without one; every type has a title', () {
    final g = Game(Random(1));
    final necro = g.monster(boss, Tier.boss, const Point(100, 50))..name = 'Morgath';
    expect(bossBarName(necro), 'Morgath the ${bossTitles[boss]}');
    final bear = g.monster('werebear', Tier.miniBoss, const Point(100, 50));
    expect(bossBarName(bear), monsterTypeNames['werebear']);
    expect(bossTitles.keys.toSet(), {...enemyTypes.keys, boss, necroHealer});
    expect(monsterTypeNames.keys.toSet(), {...enemyTypes.keys, boss, necroHealer});
    // The names: from the list, never one already on the field while another is free.
    final dice = Random(3);
    for (var i = 0; i < 20; i++) {
      expect(bossNames, contains(bossName(dice, {})));
    }
    final taken = {...bossNames}..remove('Vexa');
    expect(bossName(Random(4), taken), 'Vexa');
  });

  test('the wave\'s mini boss and boss get names as they come, and bars once on the field, the boss first', () {
    final g = Game(Random(5), Random(6))
      ..units.clear()
      ..wave = 14;
    g
      ..startWave()
      ..queue.clear()
      ..queue.addAll([('werebear', Tier.miniBoss), (boss, Tier.boss), ('slime', Tier.normal)]);
    for (var i = 0; i < 400 && g.queue.isNotEmpty; i++) {
      g.tick(0.05);
    }
    final bear = g.enemies.firstWhere((u) => u.type == 'werebear'), necro = g.enemies.firstWhere((u) => u.type == boss);
    final slime = g.enemies.firstWhere((u) => u.type == 'slime');
    expect(bossNames, containsAll([bear.name, necro.name]));
    expect(bear.name, isNot(necro.name));
    expect(slime.name, isEmpty);
    // A bar only once on the field (it comes from off the screen); then the boss's over the mini boss's, and
    // none for the slime.
    for (final u in [bear, necro]) {
      expect(g.bossBarUnits.contains(u), u.entered, reason: u.type);
    }
    for (final u in [bear, necro, slime]) {
      u.pos = Point(g.cam + g.viewW / 2, u.pos.y);
    }
    g.tick(0.01);
    expect(g.bossBarUnits, [necro, bear]);
    // A mini boss a necromancer raised has none.
    final raised = g.monster('skeleton', Tier.miniBoss, Point(g.cam + g.viewW / 2, 40))
      ..entered = true
      ..raisedBy = necro;
    g.units.add(raised);
    expect(g.bossBarUnits, [necro, bear]);
    // Dying, its bar stays (it breaks away); once the body is gone, so is the bar.
    bear
      ..hp = 0
      ..dying = 0;
    expect(g.bossBarUnits, [necro, bear]);
    bear.dying = deathTime;
    g.tick(0.01);
    expect(g.bossBarUnits, [necro]);
  });
}
