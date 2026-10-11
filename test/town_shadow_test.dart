// The Town's troops draw no ground shadow (decisions-log 270, which takes back 242's Town shadows; lib/town_life.dart,
// ui-hud.md "The troops' life"): plain or awakened, walking, standing, resting or talking, the Town draws only their idle
// and walk strips, and none of those carries a baked shadow (sprites_test.dart's count). The field still draws every
// troop's shadow strip under it: plain at unitShadowAlpha, an awakened one's in its level's colour.
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';
import 'package:tower_defense/main.dart';

import 'sprites_test.dart' show shadowPixels;
import 'town_hud_test.dart' show boot, frames, townGame;
import 'town_scene_test.dart' show intoTown, settle;

/// What [type] holds at awakening [level] in [g], by its rule ([Game.awakenNeeds]: by grade with the forge on, the board's
/// since decisions-log 272).
List<Item> recipe(Game g, String type, int level) => [
      for (final MapEntry(key: item, value: n) in g.awakenNeeds(type, level).entries) ...List.filled(n, item),
    ];

/// A canvas that only notes the images drawn on it and their paints, in order; every other call does nothing.
class _Drawn implements Canvas {
  final images = <(ui.Image, Paint)>[];

  @override
  void drawImageRect(ui.Image image, Rect src, Rect dst, Paint paint) => images.add((image, paint));

  @override
  void drawImage(ui.Image image, Offset offset, Paint paint) => images.add((image, paint));

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// The army's types at their awakening levels: plain, then 1, 3 and 2.
const _army = [('soldier', 0), ('knight', 1), ('archer', 3), ('priest', 2), ('lancer', 0)];

void main() {
  testWidgets('a Town troop, plain or awakened, walking, standing, resting or talking, draws no shadow', (tester) async {
    final b = await boot(tester)..townDice = Random(4);
    b.autoStart.set(false);
    final g = await intoTown(tester, b);
    g.units.removeWhere((u) => u.side == Side.troop);
    for (final (type, level) in _army) {
      g.upgrades[type] = recipe(g, type, level);
      g.units.add(Unit(Side.troop, type, troopTypes[type]!, const Point(8, 8)));
    }
    await settle(tester, b);
    await frames(tester, 3);
    for (final (type, level) in _army) {
      expect(g.awakenLevel(type), level, reason: type);
    }
    final images = b.game.images;
    final shadows = {for (final t in troopTypes.keys) images.fromCache('tiny_${t}_shadow.png')};
    final strips = {for (final f in b.townLife.folk) for (final s in [f.idle, f.walk]) images.fromCache(s)};

    // Their errands as they come, 2 s of them.
    final drawn = _Drawn();
    for (var i = 0; i < 12; i++) {
      await frames(tester, 10);
      b.render(drawn);
    }
    final seen = [for (final (i, _) in drawn.images) i];
    expect(seen.where(strips.contains), isNotEmpty, reason: 'the troops drawn');
    expect(seen.where(shadows.contains), isEmpty, reason: 'no ground shadow in the Town');

    // Each way of being there: walking, resting at the tent, talking (its bubble up), standing; one inside the Tavern.
    final life = b.townLife, folk = {for (final f in life.folk) f.unit.type: f};
    final walker = folk['soldier']!, rester = folk['knight']!, talker = folk['archer']!, mate = folk['priest']!;
    walker
      ..doing = TownDo.stroll
      ..goal = walker.x + 100
      ..until = double.infinity
      ..inside = false;
    rester
      ..doing = TownDo.rest
      ..x = life.spots['tent']!
      ..goal = double.nan
      ..inside = false;
    talker
      ..doing = TownDo.talk
      ..goal = double.nan
      ..inside = false
      ..mate = mate
      ..lead = true
      ..said = TownIcon.heart;
    mate
      ..doing = TownDo.talk
      ..goal = double.nan
      ..inside = false
      ..mate = talker;
    folk['lancer']!.inside = true;
    final now = _Drawn();
    b.render(now);
    final shot = [for (final (i, _) in now.images) i];
    expect(shot, contains(images.fromCache(walker.walk)), reason: 'the walker walks');
    for (final f in [rester, talker, mate]) {
      expect(shot, contains(images.fromCache(f.idle)), reason: '${f.unit.type} stands');
    }
    expect(b.townFolk.where((f) => f.feet != null).length, 4, reason: 'all but the one inside');
    expect(b.townFolk.firstWhere((f) => f.unit == talker.unit).bubble, isNot(Rect.zero), reason: 'its bubble up');
    expect(shot.where(shadows.contains), isEmpty, reason: 'no ground shadow in the Town');

    // And no strip the Town draws has a shadow baked in (the Soldier's is cleared at load): every troop type's.
    for (final t in troopTypes.keys) {
      final f = TownFolk(Unit(Side.troop, t, troopTypes[t]!, const Point(8, 8)), 0, 0);
      for (final s in [f.idle, f.walk]) {
        expect(await shadowPixels(tester, images.fromCache(s)), 0, reason: s);
      }
    }
  });

  testWidgets('the field still draws each troop\'s ground shadow: plain, or in its awakening colour', (tester) async {
    final b = await boot(tester);
    b.autoStart.set(false);
    final g = b.state = townGame();
    for (final (type, level) in _army) {
      g.upgrades[type] = recipe(g, type, level);
    }
    for (var i = 0; i < 3; i++) {
      final type = _army[i].$1;
      g.units.add(Unit(Side.troop, type, g.statsOf(type), Point(40.0 + 30 * i, 30.0)));
    }
    await frames(tester, 4);
    expect((g.inTown, b.coachCard), (false, null), reason: 'on the field, no guide card over it');
    final drawn = _Drawn();
    b.render(drawn);
    for (final (type, level) in _army.take(3)) {
      final shadow = b.game.images.fromCache('tiny_${type}_shadow.png');
      final paints = [for (final (i, p) in drawn.images) if (i == shadow) p];
      expect(paints, hasLength(1), reason: '$type: one shadow under it');
      final p = paints.single;
      if (level == 0) {
        expect(p.colorFilter, isNull, reason: '$type plain');
        expect(p.color.a, closeTo(unitShadowAlpha, 0.01));
      } else {
        expect(p.colorFilter, awakenShadowPaint(level, 0, 0).colorFilter, reason: '$type awakened $level: its colour');
        expect(p.color.a, inInclusiveRange(awakenShadowAlpha * 0.6, awakenShadowAlpha));
      }
    }
  });
}
