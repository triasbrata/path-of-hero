// The Bag's facing page, action first (decisions-log 202; docs/ui-hud.md "Tas"): each pick's action rows (an item's Give
// to troops and Give to an Artifact; a small relic's Equip on a troop and Remove from a troop while one is worn; an
// Artifact's Equip on / Move to a type, Take it off while bound, Sharpen, Carve, and a Vault one's Melt; an oath's Each
// type, Sharpen and Carve; no Sell: the Bag sells nothing, decisions-log 230 and 296), each with its line, greyed with why where its rule says no and a tap
// on it saying why; each chooser opening under the heading with its Back, acting from its rows and coming back; the
// taps the new actions take; the chooser's fit at 1266x713 and 915x412. The page's heading, description and
// rows' order and fit, and the Melt rows: bag_detail_test.dart. One TdGame per widget test.
//
// Never let a wave be won or the game end here: the board saves after a pick, into the queue's temp HOME
// (flutter_test_config.dart), never the real save.
import 'dart:math';
import 'dart:ui' show PointerDeviceKind;

import 'package:flame/game.dart' hide Game;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';
import 'package:tower_defense/main.dart';

import 'bag_pages.dart';
import 'hud_font.dart';

const desk = Size(1266, 713), wide = Size(915, 412);

/// Boots one TdGame in a [size] window, past the welcome screen, with the game's font and the minimap folded.
Future<Board> boot(WidgetTester tester, [Size size = desk]) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await loadHudFont(tester);
  final game = TdGame();
  await tester.pumpWidget(GameWidget(game: game));
  for (var i = 0; i < 3000 && !game.isLoaded; i++) {
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 20)));
    await tester.pump();
  }
  expect(game.isLoaded, isTrue);
  return game.board
    ..welcome = null
    ..miniMapOpen = false;
}

Future<void> frames(WidgetTester tester, [int n = 2]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

Future<void> tapOn(WidgetTester tester, Offset p) async {
  await tester.tapAt(p);
  await frames(tester);
}

/// Closes the message window if it shows (a press on it does nothing else).
Future<void> quiet(WidgetTester tester, Board b) async {
  if (b.messageBox != Rect.zero) await tapOn(tester, b.messageBox.center);
}

/// Turns the open book to its Bag page.
Future<void> openBag(WidgetTester tester, Board b) async {
  await quiet(tester, b);
  await tapOn(tester, b.bookTabs.firstWhere((t) => t.$1 == 'bag').$2.center);
  expect(b.bagOpen, isTrue);
}

/// Picks [kind] in the grid (its cell, the grid turned to its page: [bagTo]), unless it is the pick already.
Future<void> pick(WidgetTester tester, Board b, Enum kind) async {
  await quiet(tester, b);
  if (b.picked != kind) {
    await bagTo(tester, b, kind);
    await tapOn(tester, b.bagSlot(kind).center);
  }
  expect(b.picked, kind);
}

/// Wheels the facing page's list by [dy] px, [n] times, then rests the mouse off the rows.
Future<void> wheel(WidgetTester tester, Board b, double dy, int n) async {
  final mouse = TestPointer(9, PointerDeviceKind.mouse);
  await tester.sendEventToBinding(mouse.hover(b.assignList.center));
  for (var i = 0; i < n; i++) {
    await tester.sendEventToBinding(mouse.scroll(Offset(0, dy)));
    await frames(tester);
  }
  await tester.sendEventToBinding(mouse.hover(b.bookArea.topLeft));
  await frames(tester);
}

/// [act]'s row, the action list wheeled from its top until it shows whole.
Future<Rect> actionOf(WidgetTester tester, Board b, BagAction act) async {
  await wheel(tester, b, -60, 6);
  final h = b.bagActions.first.$2.height;
  for (var i = 0; i < 20 && b.bagAction(act).height < h - 0.5; i++) {
    await wheel(tester, b, 30, 1);
  }
  return b.bagAction(act);
}

/// [who]'s row on the chooser's list, the list wheeled down until it shows whole (the rows are in their order).
Future<Rect> rowOf(WidgetTester tester, Board b, Object who) async {
  final h = b.assignRows.map((r) => r.$2.height).reduce(max);
  for (var i = 0; i < 80 && !b.assignRows.any((r) => r.$1 == who && r.$2.height >= h - 0.5); i++) {
    await wheel(tester, b, 20, 1);
  }
  return b.assignRows.firstWhere((r) => r.$1 == who).$2;
}

/// Opens [act]'s chooser for the pick: a tap on its row.
Future<void> open(WidgetTester tester, Board b, BagAction act) async {
  await tapOn(tester, (await actionOf(tester, b, act)).center);
  expect(b.bagChooser, act);
}

/// [kind]'s actions as the page shows them, the list wheeled through: what, whether it can now, its title and its line.
Future<List<(BagAction, bool, String?, String?)>> actionsOf(WidgetTester tester, Board b, Enum kind) async {
  await pick(tester, b, kind);
  final seen = <BagAction, (BagAction, bool, String?, String?)>{};
  for (var i = 0; i < 12; i++) {
    final h = b.bagActions.first.$2.height;
    for (final (act, r, ok) in b.bagActions) {
      if (r.height >= h - 0.5) seen[act] ??= (act, ok, b.bagDetailText('title:${act.name}'), b.bagDetailText('hint:${act.name}'));
    }
    await wheel(tester, b, 30, 1);
  }
  await wheel(tester, b, -60, 10);
  return [...seen.values];
}

/// A board game between waves at wave 45 (the Shop and Carve open), no army cap, gold to spare, a soldier and a knight
/// beside the free priest at their posts, the soldier wearing a Fang; a long run's bag, and Artifacts: Dragon Heart ★2
/// on the knight, the Grail (40 points on its Carve bar) and Dawn Star in the Vault, Oath of One.
Game stocked({int wave = 45}) {
  final g = Game(Random(1)).boardRules()
    ..armyMax = null
    ..gold = 5000000
    ..wave = wave;
  for (final type in ['soldier', 'knight']) {
    expect(g.autoPlace(type), isTrue);
  }
  for (final u in g.troops) {
    u
      ..pos = u.post
      ..arriving = false;
  }
  g.inventory.addAll({Item.sword: 86, Item.shield: 14, Item.bow: 3, Item.potion: 120, Item.staff: 40});
  g.relicBag.addAll({Relic.fang: 1, Relic.fury: 5, Relic.guard: 2, Relic.thorns: 12});
  g
    ..givePusaka(Relic.dragonHeart, type: 'knight', stars: 2)
    ..givePusaka(Relic.grail)
    ..givePusaka(Relic.dawnStar)
    ..givePusaka(Relic.oathOfOne);
  g.pusaka[Relic.grail]!.feed = 40;
  g.troops.firstWhere((u) => u.alive && u.type == 'soldier').relics.add(Relic.fang);
  return g;
}

/// "n things": "1 troop wears it", "2 troops wear it".
String count(int n, String one, String many) => n == 1 ? '1 $one' : '$n $many';

/// [inner] inside [outer], to half a pixel.
bool inside(Rect inner, Rect outer) => outer.inflate(0.5).contains(inner.topLeft) && outer.inflate(0.5).contains(inner.bottomRight);

void main() {
  testWidgets('each pick\'s action rows: titles, lines, greyed with why where its rule says no, and a greyed row\'s tap '
      'says why', (tester) async {
    final b = await boot(tester);
    final g = b.state = stocked();
    await frames(tester, 50);
    await openBag(tester, b);
    final types = troopTypes.keys.where((t) => g.assignPreview(Item.sword, t).why == null).length;
    final gives = [for (final r in g.pusaka.keys) if (!r.oath && g.whyNotUkir(r, only: Item.sword) == null) r].length;
    final wear = g.troops.where((u) => u.alive && g.assignPreview(Relic.fury, u).why == null).length;
    String? line(bool ok, String hint) => ok ? hint : null; // a greyed row's line is its why, checked below

    for (final (kind, want) in [
      (Item.sword, [
        (BagAction.giveTroops, true, 'Give to troops', count(types, 'type can take it', 'types can take it')),
        (BagAction.giveArtifact, true, 'Give to an Artifact', 'Carve: $gives can take it'),
      ]),
      (Relic.fury, [
        (BagAction.equip, true, 'Equip on a troop', count(wear, 'troop can wear it', 'troops can wear it')),
      ]),
      (Relic.fang, [
        (BagAction.equip, true, 'Equip on a troop', null),
        (BagAction.takeOff, true, 'Remove from a troop', '1 troop wears it'),
      ]),
      (Relic.grail, [
        (BagAction.types, true, 'Equip on a type',
            g.bindPrice(Relic.grail) == 0 ? 'Free: a whole type gets it' : 'Costs ${shortPrice(g.bindPrice(Relic.grail))}: a whole type gets it'),
        (BagAction.sharpen, g.whyNotAsah(Relic.grail) == null, 'Sharpen', null),
        (BagAction.carve, g.whyNotUkir(Relic.grail) == null, 'Carve', null),
        (BagAction.melt, g.whyNotLebur(Relic.grail) == null, 'Melt', line(g.whyNotLebur(Relic.grail) == null, 'Into another Artifact: +1 star')),
      ]),
      (Relic.dragonHeart, [
        (BagAction.types, true, 'Move to a type', 'Costs ${shortPrice(g.bindPrice(Relic.dragonHeart))}'),
        (BagAction.toVault, true, 'Take it off', '${troopTypeNames['knight']} loses it, free'),
        (BagAction.sharpen, g.whyNotAsah(Relic.dragonHeart) == null, 'Sharpen', null),
        (BagAction.carve, g.whyNotUkir(Relic.dragonHeart) == null, 'Carve', null),
      ]),
      (Relic.oathOfOne, [
        (BagAction.types, true, 'Each type', 'What it gives each type'),
        (BagAction.sharpen, g.whyNotAsah(Relic.oathOfOne) == null, 'Sharpen', null),
        (BagAction.carve, g.whyNotUkir(Relic.oathOfOne) == null, 'Carve', null),
      ]),
    ]) {
      final got = await actionsOf(tester, b, kind);
      expect([for (final (act, ok, _, _) in got) (act, ok)], [for (final (act, ok, _, _) in want) (act, ok)], reason: '$kind');
      for (final ((act, _, title, hint), (_, _, wantTitle, wantHint)) in [for (final (i, w) in want.indexed) (got[i], w)]) {
        expect(title, wantTitle, reason: '$kind $act');
        if (wantHint != null) expect(hint, wantHint, reason: '$kind $act');
      }
    }
    // Before Carve opens, Give to an Artifact is greyed with why; a tap on it says why and opens nothing.
    g.wave = ukirFrom - 1;
    await pick(tester, b, Item.sword);
    await frames(tester);
    final give = b.bagActions.firstWhere((a) => a.$1 == BagAction.giveArtifact);
    expect((give.$3, b.bagDetailText('hint:giveArtifact')!.startsWith('${Words.carve}:')), (false, false));
    await tapOn(tester, give.$2.center);
    expect((b.message, b.bagChooser), (ukirRefusals.from, null));
    await quiet(tester, b);
    g.wave = 45;

    // Mid-wave: an Artifact's type rows, Take it off, Sharpen and Melt greyed with why; a tap says why.
    g.startWave();
    await frames(tester, 40); // the book shuts for the wave
    for (var i = 0; i < 3 && b.bookTabs.isEmpty; i++) {
      await quiet(tester, b);
      await tapOn(tester, b.bookButton.center);
      await frames(tester, 40);
    }
    if (!b.bagOpen) await openBag(tester, b);
    final mid = {for (final (act, ok, _, _) in await actionsOf(tester, b, Relic.dragonHeart)) act: ok};
    expect(mid, {
      BagAction.types: bindMidWave,
      BagAction.toVault: g.whyNotUnbind(Relic.dragonHeart) == null,
      BagAction.sharpen: g.whyNotAsah(Relic.dragonHeart) == null,
      BagAction.carve: g.whyNotUkir(Relic.dragonHeart) == null,
    });
    if (!bindMidWave) {
      await tapOn(tester, b.bagAction(BagAction.types).center);
      expect((b.message, b.bagChooser), (pusakaRefusals.midWave, null));
      await quiet(tester, b);
    }
    if (g.whyNotUnbind(Relic.dragonHeart) case final why?) {
      await tapOn(tester, (await actionOf(tester, b, BagAction.toVault)).center);
      await tapOn(tester, b.bagDetail('toVault').center);
      expect((b.message, g.pusaka[Relic.dragonHeart]!.type), (why, 'knight'));
      await quiet(tester, b);
    }
    await frames(tester, 10);
  });

  for (final size in const [desk, wide]) {
    final at = '${size.width.round()}x${size.height.round()}';
    testWidgets('at $at each chooser opens under the heading (Back on the left, what it is for beside it, the chips '
        'where it lists troops or types, then its rows inside the page), acts from a row and Back comes back',
        (tester) async {
      final b = await boot(tester, size);
      final g = b.state = stocked();
      await frames(tester, 50);
      await openBag(tester, b);

      /// The open chooser's head and list at [at]: Back on the left under the heading, its title beside it, the chips
      /// (with [chips]) under them, the list under those, each row inside the list; returns its rows' who.
      List<Object> chooser(BagAction act, String title, {required bool chips}) {
        final page = b.bagDetail('page'), back = b.bagBack, list = b.assignList, why = '$at ${b.picked} $act';
        expect((b.bagChooser, inside(back, page), inside(list, page)), (act, true, true), reason: '$why: $back $list in $page');
        expect(back.top, greaterThanOrEqualTo(b.bagDetail('count').bottom - 0.5), reason: '$why: Back under the heading');
        expect(b.bagDetail('desc'), Rect.zero, reason: '$why: the description gives way');
        final shown = b.bagDetailText('chooser')!;
        expect(shown.isNotEmpty && (shown == title || (shown.endsWith('..') && title.startsWith(shown.substring(0, shown.length - 2)))),
            isTrue, reason: '$why: "$shown"');
        final chip = b.assignChip(null);
        expect(chip != Rect.zero, chips, reason: '$why: chips');
        if (chips) expect((chip.top >= back.bottom, list.top >= chip.bottom), (true, true), reason: '$why: $back $chip $list');
        if (!chips) expect(list.top, greaterThanOrEqualTo(back.bottom), reason: why);
        expect(b.assignRows, isNotEmpty, reason: why);
        for (final (who, r, _) in b.assignRows) {
          expect(inside(r, list), isTrue, reason: '$why: $who $r in $list');
        }
        return [for (final (who, _, _) in b.assignRows) who];
      }

      Future<void> back(BagAction first) async {
        await tapOn(tester, b.bagBack.center);
        expect((b.bagChooser, b.bagBack, b.bagActions.first.$1), (null, Rect.zero, first), reason: '$at: Back, from the top');
      }

      // An item: Give to troops lists the types; a row gives one copy and the chooser stays for the next.
      await pick(tester, b, Item.sword);
      await open(tester, b, BagAction.giveTroops);
      expect(chooser(BagAction.giveTroops, 'Give to troops', chips: true).every((w) => w is String), isTrue, reason: at);
      final (type as String, row, _) = b.assignRows.firstWhere((r) => r.$3);
      final had = g.countOf(type, Item.sword);
      await tapOn(tester, row.center);
      expect((g.countOf(type, Item.sword), b.bagChooser), (had + 1, BagAction.giveTroops), reason: '$at: given to $type');
      await quiet(tester, b);
      await back(BagAction.giveTroops);

      // Give to an Artifact lists the Artifacts that take Carve (no oath); a row feeds it.
      await open(tester, b, BagAction.giveArtifact);
      final arts = chooser(BagAction.giveArtifact, 'Give to an Artifact', chips: false);
      expect((arts.every((w) => w is Relic && !w.oath)), isTrue, reason: '$at: $arts');
      final swords = g.inBag(Item.sword);
      await tapOn(tester, b.assignRows.firstWhere((r) => r.$3).$2.center);
      expect(g.inBag(Item.sword), lessThan(swords), reason: '$at: fed');
      await quiet(tester, b);
      await back(BagAction.giveTroops);

      // A small relic: Equip on a troop lists the troops; a row puts it on.
      await pick(tester, b, Relic.fury);
      await open(tester, b, BagAction.equip);
      expect(chooser(BagAction.equip, 'Equip on a troop', chips: true).every((w) => w is Unit), isTrue, reason: at);
      final (who as Unit, r, _) = b.assignRows.firstWhere((r) => r.$3);
      await tapOn(tester, r.center);
      expect(who.relics, contains(Relic.fury), reason: '$at: on $who');
      await quiet(tester, b);
      await back(BagAction.equip);

      // Remove from a troop lists who wears it; a row takes it off, and with none worn the chooser goes.
      await pick(tester, b, Relic.fang);
      await open(tester, b, BagAction.takeOff);
      final wearer = g.troops.firstWhere((u) => u.alive && u.holds(Relic.fang));
      expect(chooser(BagAction.takeOff, 'Remove from a troop', chips: false), [wearer], reason: at);
      await tapOn(tester, b.assignRows.single.$2.center);
      expect((wearer.holds(Relic.fang), g.inBag(Relic.fang), b.bagChooser), (false, 2, null), reason: '$at: off');
      expect(b.bagActions.map((a) => a.$1), isNot(contains(BagAction.takeOff)), reason: at);
      await quiet(tester, b);

      // An Artifact in the Vault: Equip on a type; a row binds it, and the chooser stays, now to move it.
      await pick(tester, b, Relic.grail);
      await open(tester, b, BagAction.types);
      expect(chooser(BagAction.types, 'Equip on a type', chips: true).every((w) => w is String), isTrue, reason: at);
      await tapOn(tester, (await rowOf(tester, b, 'soldier')).center);
      expect((g.pusaka[Relic.grail]!.type, b.bagChooser), ('soldier', BagAction.types), reason: at);
      expect(chooser(BagAction.types, 'Move to a type', chips: true), isNotEmpty, reason: at);
      await quiet(tester, b);
      await back(BagAction.types);

      // An oath: Each type, what it gives each; a row says where it is.
      await pick(tester, b, Relic.oathOfOne);
      await open(tester, b, BagAction.types);
      expect(chooser(BagAction.types, 'Each type', chips: true).every((w) => w is String), isTrue, reason: at);
      await tapOn(tester, b.assignRows.first.$2.center);
      expect((b.message, b.bagChooser), (g.pusakaWhere(Relic.oathOfOne), BagAction.types), reason: at);
      await quiet(tester, b);
      await back(BagAction.types);

      // Another pick shows its own action list, never the last one's chooser.
      await open(tester, b, BagAction.types);
      await pick(tester, b, Relic.dragonHeart);
      expect((b.bagChooser, b.bagBack), (null, Rect.zero), reason: at);
      await frames(tester, 10);
    });
  }

  testWidgets('the taps the action list adds (decisions-log 202): Remove from the pick 3, Give to an Artifact 3, To '
      'Vault 2, Back 1; the Awaken shortcut opens its chooser', (tester) async {
    final b = await boot(tester);
    final g = b.state = stocked();
    await frames(tester, 50);
    await openBag(tester, b);
    var taps = 0;
    Future<void> tap(Rect r) async {
      expect(r, isNot(Rect.zero));
      taps++;
      await tapOn(tester, r.center);
    }

    Future<int> done() async {
      final n = taps;
      taps = 0;
      await quiet(tester, b);
      if (b.picked case final p?) await tapOn(tester, b.bagSlot(p).center); // put back: the next starts from none
      return n;
    }

    // Remove from the pick: its cell, "Remove from a troop", the troop's row.
    await tap(b.bagSlot(Relic.fang));
    await tap(b.bagAction(BagAction.takeOff));
    await tap(b.assignRows.single.$2);
    expect((g.inBag(Relic.fang), await done()), (2, 3));
    // Give to an Artifact: its cell, "Give to an Artifact", the Artifact's row.
    final swords = g.inBag(Item.sword);
    await tap(b.bagSlot(Item.sword));
    await tap(b.bagAction(BagAction.giveArtifact));
    await tap(b.assignRows.firstWhere((r) => r.$3).$2);
    expect((g.inBag(Item.sword) < swords, await done()), (true, 3));
    // To Vault: its cell, the tag.
    await tap(b.bagSlot(Relic.dragonHeart));
    await tap(b.bagDetail('toVault'));
    expect((g.pusaka[Relic.dragonHeart]!.type, await done()), (null, 2));
    // Back: 1, to the action list.
    await tapOn(tester, b.bagSlot(Item.shield).center);
    await tapOn(tester, b.bagAction(BagAction.giveTroops).center);
    await tap(b.bagBack);
    expect((b.bagChooser, await done()), (null, 1));
    await frames(tester, 10);
  });

  test('the action rows\' words are in the game\'s font', () {
    final chars = fontChars();
    for (final line in [
      'Give to troops', 'Give to an Artifact', 'Equip on a troop', 'Remove from a troop', 'Each type', 'Equip on a type',
      'Move to a type', 'Take it off', Words.toVault, Words.back, '12 types can take it', 'No type can take it now',
      'Carve: 4 can take it', 'No Artifact can take it', '12 troops can wear it', 'No troop can wear it now',
      '12 troops wear it', 'What it gives each type', 'Free: a whole type gets it', 'Costs 30k: a whole type gets it',
      'Templar loses it, free', 'Into another Artifact: +1 star', 'Into another: +1 star', 'What each type gets', 'Free',
      'Not for a Legendary', 'Gone for good', '1,000 gold each',
    ]) {
      final missing = line.runes.where((c) => !chars.contains(c)).map(String.fromCharCode).toList();
      expect(missing, isEmpty, reason: line);
    }
  });
}
