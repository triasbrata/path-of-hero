// The Dungeon's screen (decisions-log 336, 337; lib/dungeon_scene.dart, lib/dungeon_hud.dart, lib/dungeon_page.dart;
// docs/ui-hud.md "Dungeon"): booted TdGames at 1600x947 and 1266x713 as on the desk and at 915x412 as on a phone, in a
// Town with a mixed army. The Dungeon's tab opens its page, three troops picked and Enter start a trip (the scene's
// whole-number scale); the HUD's parts on the screen, every control at least 44 px, nothing over the band's walkable
// middle (Leave over the campfire aside), the desk's key hints or a phone's joystick, the leader's row lit; the live
// panel's cap (6 rows, 4 on a short screen) and its "+N more"; the Action chain's steps 1, 2 and 4 by the keys on the
// desk and by taps on a phone, time standing still while it is open, an Attack on a foe given; the leader switched;
// Leave at the save point back to the Town.
import 'dart:math';

import 'package:flutter/foundation.dart' show debugDefaultTargetPlatformOverride;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';
import 'package:tower_defense/main.dart';

import 'town_hud_test.dart' show boot, frames, townGame;

/// Wins wave 6 of a Towns-on board game with a knight, an archer, a priest, a wizard and a soldier, and waits until the
/// Town is gone into.
Future<Game> intoTown(WidgetTester tester, Board b) async {
  final g = b.state = townGame()
    ..wave = 5
    ..townAt = 7
    ..gold = 40000;
  for (final type in ['knight', 'archer', 'priest', 'wizard', 'soldier']) {
    g.autoPlace(type);
  }
  g
    ..startWave()
    ..queue.clear()
    ..units.add(g.monster('slime', Tier.normal, const Point(300, 60))..gone = true);
  for (var i = 0; i < 600 && !g.inTown; i++) {
    await frames(tester, 1);
  }
  expect(g.inTown, isTrue);
  await frames(tester, 60);
  return g;
}

Future<void> key(WidgetTester tester, LogicalKeyboardKey k) async {
  await simulateKeyDownEvent(k);
  await simulateKeyUpEvent(k);
  await frames(tester, 3);
}

/// The band's walkable middle on the screen: its middle half, top to bottom.
Rect middle(Board b) {
  final band = b.dungeonParts['band']!;
  return Rect.fromLTRB(band.left, band.top + band.height / 4, band.right, band.bottom - band.height / 4);
}

/// Every tap of the Dungeon's screen at least 44 px each way, and on the screen.
void tapsBig(Board b, Size size, String when) {
  expect(b.dungeonTaps, isNotEmpty, reason: when);
  for (final r in b.dungeonTaps) {
    expect(r.width >= 44 - 1e-6 && r.height >= 44 - 1e-6, isTrue, reason: '$when: a tap of $r');
  }
  for (final MapEntry(:key, :value) in b.dungeonParts.entries) {
    if (key == 'scene' || key == 'band') continue;
    expect(value.left >= -1 && value.top >= -1 && value.right <= size.width + 1 && value.bottom <= size.height + 1, isTrue,
        reason: '$when: $key at $value off the screen');
  }
}

void main() {
  for (final (size, platform) in const [
    (Size(1600, 947), TargetPlatform.macOS),
    (Size(1266, 713), TargetPlatform.macOS),
    (Size(915, 412), TargetPlatform.android),
  ]) {
    final tag = '${size.width.round()}x${size.height.round()}', touch = platform == TargetPlatform.android;
    testWidgets('the Dungeon at $tag: in from its page, the HUD, the live panel\'s cap, the chain, the leader, Leave',
        (tester) async {
      debugDefaultTargetPlatformOverride = platform; // the HUD asks it every frame: the desk's layout or a phone's
      try {
        await sweep(tester, size, touch);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  }
}

Future<void> sweep(WidgetTester tester, Size size, bool touch) async {
  final b = await boot(tester, size);
  b.autoStart.set(false);
  final g = await intoTown(tester, b);
  final army = [for (final u in g.troops) if (u.alive) u.name];

  // The page: its tab, three troops picked (the first leads), Enter.
  await tester.tapAt(b.bookTabs.firstWhere((t) => t.$1 == 'dungeon').$2.center);
  await frames(tester, 30);
  expect(b.bookPage, 'dungeon');
  final picks = [for (final type in ['knight', 'archer', 'priest']) g.troops.firstWhere((u) => u.type == type)];
  for (final u in picks) {
    await tester.tapAt(b.dungeonPage['troop:${u.name}']!.center);
    await frames(tester, 2);
  }
  expect(b.dungeonPicks, picks);
  await tester.tapAt(b.dungeonPage['enter']!.center);
  await frames(tester, 30);
  final d = g.dungeon!;
  expect([for (final u in d.party) u.name], [for (final u in picks) u.name], reason: 'the party in the picked order');
  expect(d.leader.name, picks.first.name, reason: 'the first picked leads');
  expect(b.dungeonK, max(1.0, (size.height / 236).roundToDouble()), reason: 'a whole-number scale: 236 world units tall');

  // Just in: the HUD; every control 44 px; nothing over the band's walkable middle but Leave over the campfire.
  expect(g.atSavePoint, isTrue);
  final p = b.dungeonParts;
  for (final part in ['pause', 'target', 'minimap', 'wait', 'gambits', 'live', 'party', 'action', 'leave', 'lit:party']) {
    expect(p[part], isNotNull, reason: part);
  }
  expect(p['lit:party'], p['member:0'], reason: "the leader's row lit");
  tapsBig(b, size, 'just in');
  for (final MapEntry(:key, :value) in p.entries) {
    if (const {'scene', 'band', 'leave'}.contains(key)) continue;
    expect(value.overlaps(middle(b)), isFalse, reason: '$key at $value over the band\'s middle ${middle(b)}');
  }
  if (touch) {
    expect(p['joystick']!.width, greaterThanOrEqualTo(120), reason: "a phone's joystick");
    expect(p.keys.where((k) => k.startsWith('hint:')), isEmpty, reason: 'no key hints on a phone');
  } else {
    expect(p['joystick'], isNull, reason: 'no joystick on the desk');
    final hints = [for (var i = 0; p['hint:$i'] != null; i++) p['hint:$i']!];
    expect(hints.length, 5, reason: 'WASD, the arrows, Enter, G, Esc');
    for (final h in hints) {
      expect(h.overlaps(p['action']!) || h.overlaps(p['party']!), isFalse, reason: 'a hint at $h');
    }
  }

  // A fight: eight foes hostile on the leader, the leader on one of them. The live panel shows its cap and "+N more".
  final foes = [
    for (var i = 0; i < 8; i++)
      g.addDungeonFoe(i.isEven ? 'slime' : 'bat', Point(d.leader.pos.x + 80 + 12 * i, bandTop + 16 + 10 * i)),
  ];
  for (final f in foes) {
    d.minds[f]! // as a hit turns it: hostile, the leader its prey, its chase's clock from now
      ..hostile = true
      ..prey = d.leader
      ..reachedAt = g.t
      ..act = Act(ActKind.attack, d.leader);
  }
  g.command(d.leader, ActKind.attack, foes.first);
  await frames(tester, 6);
  final cap = size.height >= 560 ? 6 : 4, rows = g.liveRows().length;
  expect(rows, greaterThan(cap));
  final shown = [for (var i = 0; b.dungeonParts['row:$i'] != null; i++) i];
  expect(shown.length, cap, reason: 'the live panel at most $cap rows');
  expect(b.dungeonParts['more'], isNotNull, reason: '"+${rows - cap} more"');
  expect(b.dungeonParts['lit:live'], b.dungeonParts['row:0'], reason: "the leader's row first, lit");
  expect(b.dungeonParts['live']!.overlaps(middle(b)), isFalse, reason: "the live panel clear of the band's middle");
  expect(b.dungeonParts['leave'], isNull, reason: 'no Leave with a foe hostile');

  // The chain: steps 1, 2 and 4; time stands still while it is open.
  final member = d.party[1];
  if (touch) {
    await tester.tapAt(b.dungeonParts['action']!.center);
    await frames(tester, 3);
    expect(b.dungeonStep, 1);
    final t = g.t;
    await frames(tester, 10);
    expect(g.t, t, reason: 'time stands still in the chain (Wait)');
    expect(b.dungeonParts['card'], isNotNull);
    tapsBig(b, size, 'step 1');
    await tester.tapAt(b.dungeonParts['member:1']!.center);
    await frames(tester, 3);
    expect(b.dungeonStep, 2);
    tapsBig(b, size, 'step 2');
    await tester.tapAt(b.dungeonParts['action:0']!.center);
    await frames(tester, 3);
    expect(b.dungeonStep, 4);
    expect(b.dungeonParts['foe:0'], isNotNull);
    tapsBig(b, size, 'step 4');
    await tester.tapAt(b.dungeonParts['foe:0']!.center);
    await frames(tester, 3);
  } else {
    await key(tester, LogicalKeyboardKey.enter);
    expect(b.dungeonStep, 1);
    final t = g.t;
    await frames(tester, 10);
    expect(g.t, t, reason: 'time stands still in the chain (Wait)');
    expect(b.dungeonParts['ribbon'], isNotNull, reason: '"Paused: step 1 of 4"');
    await key(tester, LogicalKeyboardKey.arrowDown);
    expect(b.dungeonPoint, 1);
    expect(b.dungeonParts['lit:party'], b.dungeonParts['member:1'], reason: 'the pointed member lit');
    tapsBig(b, size, 'step 1');
    await key(tester, LogicalKeyboardKey.enter);
    expect(b.dungeonStep, 2);
    expect(b.dungeonParts['card:action'], isNotNull);
    final hints = [for (var i = 0; b.dungeonParts['hint:$i'] != null; i++) b.dungeonParts['hint:$i']!];
    expect(hints.length, 3, reason: "the chain's keys");
    for (final h in hints) {
      for (final part in ['card:action', 'action', 'party']) {
        expect(h.overlaps(b.dungeonParts[part]!), isFalse, reason: 'a hint at $h over the $part');
      }
    }
    tapsBig(b, size, 'step 2');
    await key(tester, LogicalKeyboardKey.enter);
    expect(b.dungeonStep, 4);
    expect(b.dungeonParts['card:target'], isNotNull);
    expect(b.dungeonParts['foe:0'], isNotNull);
    tapsBig(b, size, 'step 4');
    await key(tester, LogicalKeyboardKey.enter);
  }
  expect(b.dungeonStep, 0, reason: 'a foe picked closes the chain');
  final act = d.minds[member]!.act!;
  expect((act.kind, act.byPlayer, act.target?.side), (ActKind.attack, true, Side.enemy), reason: "the member's Attack");

  // The leader switched: the arrows on the desk, a tap on a member on a phone.
  final before = d.leader;
  if (touch) {
    await tester.tapAt(b.dungeonBody(d.party[2]));
    await frames(tester, 3);
    expect(d.leader, d.party[2], reason: 'a tap on a member leads it');
  } else {
    await key(tester, LogicalKeyboardKey.arrowDown);
    expect(d.leader, isNot(before), reason: 'Down: the next member leads');
  }

  // The foes gone and the party at the save point: Leave over the campfire, back to the Town.
  g.units.removeWhere((u) => u.side == Side.enemy);
  d.minds.removeWhere((u, _) => u.side == Side.enemy);
  d.due.clear();
  for (final (i, u) in d.party.indexed) {
    u.pos = d.floor.savePoint + Point(10.0 + 14 * i, 4.0);
  }
  await frames(tester, 10);
  expect(g.atSavePoint, isTrue);
  await tester.tapAt(b.dungeonParts['leave']!.center);
  await frames(tester, 30);
  expect((g.dungeon, g.inTown), (null, true), reason: 'Leave: back in the Town');
  expect([for (final u in g.troops) if (u.alive) u.name], army, reason: 'the army whole again');
}
