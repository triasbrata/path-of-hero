// The Bag's facing page (decisions-log 187 and 202; docs/ui-hud.md "Tas"): for each pick its heading (the icon 32 px on
// the desk, 16 on a phone; the count in the capsule), what it is (where an Artifact is; a line or two on what it does)
// and its action rows (an item's Give to troops and Give to an Artifact; a small relic's Equip, Remove while one is
// worn; an Artifact's types, To Vault while bound, Sharpen and Carve, a Vault one's Melt too; no Sell: the Bag sells
// nothing, decisions-log 230 and 296), inside the page, apart and in order, at 1266x713 and 915x412; the Vault's Melt
// greyed mid-wave with why; Melt's picker under the heading with its Back; the blank page with nothing picked; the new words in the game's font. The action list's choosers and its taps: bag_actions_test.dart;
// Carve's own states: carve_ui_test.dart. One TdGame per widget test.
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

/// A board game between waves at wave 30 (the Shop open) with no army cap, gold to spare, and a soldier and a knight
/// beside the free priest, standing at their posts.
Game bagGame() {
  final g = Game(Random(1)).boardRules()
    ..armyMax = null
    ..gold = 5000000
    ..wave = 30;
  for (final type in ['soldier', 'knight']) {
    expect(g.autoPlace(type), isTrue);
  }
  for (final u in g.troops) {
    u
      ..pos = u.post
      ..arriving = false;
  }
  return g;
}

/// [bagGame] with a long run's bag: items, small relics, and Pusaka bound (Dragon Heart ★2 on the knight; Void Eye on
/// the wizard, of whom none lives: asleep), in the Gudang (the Grail, Dawn Star) and an oath's; the soldier wears a Fang.
Game stocked() {
  final g = bagGame();
  g.inventory.addAll({Item.sword: 86, Item.shield: 1, Item.bow: 3, Item.potion: 1200, Item.staff: 2});
  g.relicBag.addAll({Relic.fang: 1, Relic.fury: 5, Relic.guard: 2, Relic.thorns: 12});
  g
    ..givePusaka(Relic.dragonHeart, type: 'knight', stars: 2)
    ..givePusaka(Relic.voidEye, type: 'wizard')
    ..givePusaka(Relic.grail)
    ..givePusaka(Relic.dawnStar)
    ..givePusaka(Relic.oathOfOne);
  g.troops.firstWhere((u) => u.alive && u.type == 'soldier').relics.add(Relic.fang);
  return g;
}

/// [loot]'s name, as the book says it.
String nameOf(Enum loot) => loot is Relic ? relicNames[loot]! : itemNames[loot as Item]!;

/// Whether [shown] is [full], or [full] cut to fit ("..": battle_log.dart's `_fit`).
bool fitted(String? shown, String full) =>
    shown != null && (shown == full || (shown.endsWith('..') && full.startsWith(shown.substring(0, shown.length - 2))));

/// The rarities' words on the where line.
const rarityWords = {Rarity.langka: Words.rare, Rarity.epik: Words.epic, Rarity.legenda: Words.legendary};

/// [inner] inside [outer], to half a pixel.
bool inside(Rect inner, Rect outer) => outer.inflate(0.5).contains(inner.topLeft) && outer.inflate(0.5).contains(inner.bottomRight);

/// The facing page's lines under the heading, in their order.
const stack = ['where', 'desc'];

/// The most lines the description takes at a heading icon of [side] px: 4 on a phone (16 px), 3 on the desk.
int descMost(double side) => side == 16 ? bagDescLinesPhone : bagDescLines;

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

/// The facing page's list wheeled from its top until what [at] gives shows whole in it (at 915x412 the shorter
/// landscape book's list holds about two rows, decisions-log 283; a wheel is no tap).
Future<void> wheelUntil(WidgetTester tester, Board b, Rect Function() at) async {
  final mouse = TestPointer(9, PointerDeviceKind.mouse);
  await tester.sendEventToBinding(mouse.hover(b.assignList.center));
  await tester.sendEventToBinding(mouse.scroll(const Offset(0, -2000)));
  await frames(tester);
  for (var i = 0; i < 60 && !inside(at(), b.assignList); i++) {
    await tester.sendEventToBinding(mouse.scroll(const Offset(0, 10)));
    await frames(tester);
  }
  await tester.sendEventToBinding(mouse.hover(b.bookArea.topLeft)); // off the rows: a touch tap under a tooltip is no tap
  await frames(tester);
}

/// [who]'s row on the facing page's list, the list wheeled down until it shows whole (the rows are in their order).
Future<Rect> rowOf(WidgetTester tester, Board b, Object who) async {
  final mouse = TestPointer(9, PointerDeviceKind.mouse);
  await tester.sendEventToBinding(mouse.hover(b.assignList.center));
  final h = b.assignRows.map((r) => r.$2.height).reduce(max);
  for (var i = 0; i < 80 && !b.assignRows.any((r) => r.$1 == who && r.$2.height >= h - 0.5); i++) {
    await tester.sendEventToBinding(mouse.scroll(const Offset(0, 20)));
    await frames(tester);
  }
  await tester.sendEventToBinding(mouse.hover(b.bookArea.topLeft)); // off the rows: a touch tap under a tooltip is no tap
  await frames(tester);
  return b.assignRows.firstWhere((r) => r.$1 == who).$2;
}

/// Checks the facing page of the pick shown at [at]: every part inside the page; the heading's icon, name and count
/// apart on one band; under it the where line and the description one after another, then the action list (inside the
/// page, under them) and its rows, in [acts]' order from the top, apart, inside the list, the first [whole] whole.
/// Wheeled to its end, the list shows the last row whole. Returns the lines shown.
Future<Map<String, Rect>> laidOut(WidgetTester tester, Board b, String at, List<BagAction> acts, {int whole = 2}) async {
  final page = b.bagDetail('page'), icon = b.bagDetail('icon'), name = b.bagDetail('name'), count = b.bagDetail('count');
  expect(page, isNot(Rect.zero), reason: at);
  for (final r in [name, count, if (icon.width > 0) icon]) {
    expect(inside(r, page), isTrue, reason: '$at: $r in the page $page');
  }
  expect((name.overlaps(count), icon.width > 0 && icon.overlaps(name)), (false, false), reason: '$at: $icon $name $count');
  final heading = name.expandToInclude(count).expandToInclude(icon.width > 0 ? icon : name);
  final parts = {for (final k in stack) if (b.bagDetail(k) != Rect.zero) k: b.bagDetail(k)};
  var bottom = heading.bottom;
  for (final MapEntry(key: k, value: r) in parts.entries) {
    expect(inside(r, page), isTrue, reason: '$at: $k $r in the page $page');
    expect(r.top, greaterThanOrEqualTo(bottom - 0.5), reason: '$at: $k $r under what is over it ($bottom)');
    bottom = r.bottom;
  }
  final list = b.assignList, shown = b.bagActions;
  expect((list.top >= bottom, inside(list, page)), (true, true), reason: '$at: the list $list under $bottom, in $page');
  expect([for (final (act, _, _) in shown) act], acts.take(shown.length), reason: '$at: in order from the top');
  expect(shown.length, greaterThanOrEqualTo(min(2, acts.length)), reason: '$at: $list');
  final h = shown.first.$2.height;
  for (final (i, (act, r, _)) in shown.indexed) {
    expect(inside(r, list), isTrue, reason: '$at: $act $r in the list $list');
    if (i < whole) expect(r.height, closeTo(h, 0.5), reason: '$at: $act whole');
    if (i > 0) expect(r.top, greaterThan(shown[i - 1].$2.bottom), reason: '$at: $act apart from the one over it');
  }
  if (shown.length < acts.length || shown.last.$2.height < h - 0.5) {
    await wheel(tester, b, 60, 10);
    final (last, r, _) = b.bagActions.last;
    expect((last, (r.height - h).abs() <= 0.5), (acts.last, true), reason: '$at: wheeled to the end, $r whole');
    await wheel(tester, b, -60, 10);
  }
  return parts;
}

/// Nothing is drawn on the facing page: no heading, count, icon, line, chips, rows, slots or actions (decisions-log 241).
void expectBlank(Board b, String at) {
  for (final key in const ['name', 'count', 'empty', 'where', 'desc']) {
    expect(b.bagDetailText(key), isNull, reason: '$at: $key');
  }
  expect((b.bagDetail('icon'), b.bagDetail('count'), b.bagDetail('desc'), b.bagDetail('empty')), (Rect.zero, Rect.zero, Rect.zero, Rect.zero), reason: at);
  expect(([for (final t in [null, ...troopTypes.keys]) b.assignChip(t)].every((r) => r == Rect.zero), b.assignRows.length, b.assignSlots.length, b.bagActions.length, b.bagChooser, b.assignList), (true, 0, 0, 0, null, Rect.zero), reason: at);
  expect(b.bagDetail('page'), isNot(Rect.zero), reason: '$at: the blank paper is still the page');
}

void main() {
  for (final (size, side) in const [(desk, 32.0), (wide, 16.0)]) {
    final at = '${size.width.round()}x${size.height.round()}';
    testWidgets('at $at each pick\'s heading (icon ${side.round()} px, name, count), what it is and its action rows fit the '
        'facing page in order: an item, a small relic, one worn, an Artifact in the Vault, bound, asleep, an oath, and '
        'nothing', (tester) async {
      final b = await boot(tester, size);
      final g = b.state = stocked();
      await frames(tester, 50);
      await openBag(tester, b);

      // Nothing picked: the page is blank (decisions-log 241): no title, count, icon, line, chip, row or action.
      expectBlank(b, at);

      // An item and a small relic: what it does for whom (a relic's tier and who it suits, decisions-log 227), then its
      // actions.
      for (final (kind, count, desc, acts) in [
        (Item.sword, 'x86', '${g.itemEffect(Item.sword).first} for one troop type. Each type takes a few.',
            [BagAction.giveTroops, BagAction.giveArtifact]),
        (Relic.fury, 'x5', '${g.relicEffect(Relic.fury).first}. ${g.relicBestLine(Relic.fury)}. $relicSlotsLine.', [BagAction.equip]),
        (Relic.fang, 'x1', '${g.relicEffect(Relic.fang).first}. ${g.relicBestLine(Relic.fang)}. $relicSlotsLine.',
            [BagAction.equip, BagAction.takeOff]),
      ]) {
        await pick(tester, b, kind);
        // At 915x412 a small relic's text (its tier's best type, decisions-log 227) leaves one row whole over the list's
        // fold; the wheel brings the next.
        final parts = await laidOut(tester, b, '$at $kind', acts, whole: kind is Relic && size == wide ? 1 : 2);
        expect(parts.keys, ['desc'], reason: '$at $kind');
        expect(b.bagDetail('icon').size, Size(side, side), reason: '$at $kind: crisp, a whole multiple of the art');
        expect((fitted(b.bagDetailText('name'), nameOf(kind)), b.bagDetailText('count')), (true, count), reason: '$at $kind');
        final lines = b.bagDetailText('desc')!.split('\n');
        expect((lines.length <= descMost(side), lines.join(' ')), (true, desc), reason: '$at $kind: whole, never cut');
      }

      // The Artifacts: where it is, what it does, its actions.
      final darkWizard = g.pusakaAsleep(Relic.voidEye);
      expect(darkWizard, isTrue, reason: 'no wizard lives');
      const bound = [BagAction.types, BagAction.toVault, BagAction.sharpen, BagAction.carve];
      for (final (relic, where, acts) in [
        (Relic.grail, '${rarityWords[Relic.grail.rarity]} · in ${Words.vault}',
            [BagAction.types, BagAction.sharpen, BagAction.carve, BagAction.melt]),
        (Relic.dawnStar, '${rarityWords[Relic.dawnStar.rarity]} · in ${Words.vault}',
            [BagAction.types, BagAction.sharpen, BagAction.carve, BagAction.melt]),
        (Relic.dragonHeart, '${rarityWords[Relic.dragonHeart.rarity]} · on ${troopTypeNames['knight']} (1)', bound),
        (Relic.voidEye, '${rarityWords[Relic.voidEye.rarity]} · on ${troopTypeNames['wizard']} (asleep)', bound),
        (Relic.oathOfOne, g.oathWaits ? oathWaitingRow(g.typesAlive) : '${Words.oath}: all troops',
            [BagAction.types, BagAction.sharpen, BagAction.carve]),
      ]) {
        await pick(tester, b, relic);
        final parts = await laidOut(tester, b, '$at $relic', acts);
        expect(parts.keys, ['where', 'desc'], reason: '$at $relic');
        expect(b.bagDetail('icon').size, Size(side, side), reason: '$at $relic');
        expect((fitted(b.bagDetailText('name'), nameOf(relic)), b.bagDetailText('count')), (true, '★${g.pusaka[relic]!.stars}'),
            reason: '$at $relic');
        expect(fitted(b.bagDetailText('where'), where), isTrue, reason: '$at $relic: ${b.bagDetailText('where')}');
        final effect = g.relicEffect(relic), desc = relic.oath ? '${effect.join('. ')}.' : '${firstSentence(effect)}. $pusakaLine.';
        expect(b.bagDetailText('desc')!.split('\n').join(' '), desc, reason: '$at $relic: whole, never cut');
      }
      await frames(tester, 10);
    });
  }

  for (final (size, side) in const [(desk, 32.0), (wide, 16.0)]) {
    final at = '${size.width.round()}x${size.height.round()}';
    testWidgets('at $at every Langka and Epik Artifact\'s description (decisions-log 214), at ★1 and at ★3 carved +5, '
        'shows whole in at most ${descMost(side)} lines (never a word cut; one too long drops "$pusakaLine", never a word of '
        'what it does), the action rows under it', (tester) async {
      final b = await boot(tester, size);
      final g = b.state = bagGame();
      await frames(tester, 50);
      await openBag(tester, b);
      final arts = [for (final r in pusakaCatalog.keys) if (r.rarity == Rarity.langka || r.rarity == Rarity.epik) r];
      expect(arts.length, 60, reason: '30 Langka, 30 Epik');
      var (longest, most, dropped) = ('', 0, <String>[]);
      for (final r in arts) {
        for (final (stars, ukir) in const [(1, 0), (3, 5)]) {
          g.givePusaka(r, stars: stars, ukir: ukir);
          await frames(tester);
          await pick(tester, b, r);
          final why = '$at ${relicNames[r]} ★$stars+$ukir';
          final lines = b.bagDetailText('desc')!.split('\n'), shown = lines.join(' ');
          final effect = '${firstSentence(g.relicEffect(r))}.';
          expect(lines.length, lessThanOrEqualTo(descMost(side)), reason: '$why: $lines');
          expect(['$effect $pusakaLine.', effect], contains(shown), reason: '$why: whole, never cut');
          expect(lines.where((l) => l.endsWith('..')), isEmpty, reason: why);
          final desc = b.bagDetail('desc'), page = b.bagDetail('page');
          expect((inside(desc, page), b.assignList.top >= desc.bottom - 0.5), (true, true), reason: '$why: $desc in $page, the rows under it');
          if (lines.length > most) (longest, most) = ('${relicNames[r]} ★$stars+$ukir', lines.length);
          if (shown == effect) dropped.add('${relicNames[r]} ★$stars+$ukir');
          g.pusaka.remove(r);
          await frames(tester);
        }
      }
      // ignore: avoid_print
      print('bag desc $at: the longest $longest ($most lines); without "$pusakaLine": ${dropped.isEmpty ? 'none' : dropped.join(', ')}');
    });
  }

  for (final size in const [desk, wide]) {
    final at = '${size.width.round()}x${size.height.round()}';
    testWidgets('at $at mid-wave a Vault Artifact\'s Melt is greyed with why under it; a tap says why and melts nothing',
        (tester) async {
      final b = await boot(tester, size);
      final g = b.state = stocked();
      await frames(tester, 50);
      g.startWave();
      await frames(tester, 40); // the book shuts for the wave
      for (var i = 0; i < 3 && b.bookTabs.isEmpty; i++) {
        await quiet(tester, b);
        await tapOn(tester, b.bookButton.center);
        await frames(tester, 40);
      }
      if (!b.bagOpen) await openBag(tester, b);
      await pick(tester, b, Relic.grail);
      await wheelUntil(tester, b, () => b.leburButton); // at 915x412 the list shows two rows or three
      expect(b.bagActions.firstWhere((a) => a.$1 == BagAction.melt).$3, isFalse, reason: '$at mid-wave: Melt greyed');
      await tapOn(tester, b.leburButton.center);
      expect((b.message, b.leburOpen, b.bagChooser), (leburRefusals.midWave, null, null), reason: '$at mid-wave: Melt');
      await quiet(tester, b);
      await frames(tester, 10);
    });

    testWidgets('at $at Melt\'s picker takes the page under the heading; Back closes it; a target\'s row melts in two '
        'taps and the pick moves to it', (tester) async {
      final b = await boot(tester, size);
      final g = b.state = stocked();
      await frames(tester, 50);
      await openBag(tester, b);
      await pick(tester, b, Relic.grail);
      final heading = b.bagDetail('name'), bob = b.bookArea.top; // the book bobs: read the heading against its top
      await wheel(tester, b, 60, 10); // its row in sight
      await tapOn(tester, b.bagAction(BagAction.melt).center);
      expect((b.leburOpen, b.bagChooser), (Relic.grail, BagAction.melt), reason: at);
      expect((b.bagDetail('name').top - b.bookArea.top - (heading.top - bob)).abs() < 0.5 && fitted(b.bagDetailText('name'), nameOf(Relic.grail)), isTrue,
          reason: '$at: the heading stays');
      expect(([for (final k in stack) b.bagDetail(k)].every((r) => r == Rect.zero), b.bagActions.length), (true, 0),
          reason: '$at: no line, no action');
      expect((b.leburBack == b.bagBack, b.bagBack == Rect.zero), (true, false), reason: at);
      expect(b.leburBack.top, greaterThanOrEqualTo(b.bagDetail('count').bottom - 0.5), reason: '$at: Back under the heading');
      final name = nameOf(Relic.grail), forms = ['${Words.melt} $name ★1 into:', '${Words.melt} $name into:', '${Words.melt} into:'];
      expect(forms.contains(b.bagDetailText('chooser')), isTrue, reason: '$at: ${b.bagDetailText('chooser')}: the longest that fits');
      expect(b.assignList.top, greaterThanOrEqualTo(b.bagBack.bottom - 0.5), reason: '$at: the rows under Back');
      await tapOn(tester, b.leburBack.center);
      expect((b.leburOpen, b.bagChooser, b.bagActions.first.$1), (null, null, BagAction.types), reason: '$at: Back, from the top');

      await wheel(tester, b, 60, 10);
      await tapOn(tester, b.bagAction(BagAction.melt).center);
      await tapOn(tester, (await rowOf(tester, b, Relic.dragonHeart)).center);
      expect((b.leburArmed, g.pusaka.containsKey(Relic.grail)), (Relic.dragonHeart, true), reason: '$at: armed');
      await tapOn(tester, (await rowOf(tester, b, Relic.dragonHeart)).center);
      expect((g.pusaka.containsKey(Relic.grail), g.pusaka[Relic.dragonHeart]!.stars, b.picked), (false, 3, Relic.dragonHeart), reason: at);
      expect(b.message, startsWith('${relicNames[Relic.dragonHeart]} ★3! -'), reason: at);
      expect(b.message, endsWith(', ${relicNames[Relic.grail]} melted'), reason: at);
      expect(b.bagChooser, isNull, reason: '$at: the new pick\'s action list');
      await quiet(tester, b);
      await frames(tester, 10);
    });
  }

  for (final size in const [desk, wide, Size(1164, 777)]) {
    final at = '${size.width.round()}x${size.height.round()}';
    testWidgets('at $at nothing picked: the facing page is blank, with relics worn and with none; a pick shows its page and '
        'a second tap, or another tab, puts it back', (tester) async {
      final b = await boot(tester, size);
      final g = b.state = stocked();
      await frames(tester, 50);
      await openBag(tester, b);
      expectBlank(b, '$at relics worn');
      g.troops.where((u) => u.alive).forEach((u) => u.relics.clear());
      await frames(tester);
      expectBlank(b, '$at none worn');
      g.units.removeWhere((u) => u.side == Side.troop);
      await frames(tester);
      expectBlank(b, '$at no army');

      await pick(tester, b, Item.sword);
      expect(b.picked, Item.sword, reason: at);
      expect(b.bagDetailText('name'), isNotNull, reason: at);
      await tapOn(tester, b.bagSlot(Item.sword).center);
      expect(b.picked, isNull, reason: '$at: tapped again');
      expectBlank(b, '$at unpicked');
      await pick(tester, b, Item.sword);
      await tapOn(tester, b.bagChip(BagCategory.relics).center);
      await frames(tester);
      expectBlank(b, '$at another tab hides the pick');
      await frames(tester, 10);
    });
  }

  test('the facing page\'s new words are in the game\'s font (a star is drawn as an icon)', () {
    final chars = fontChars();
    for (final line in [
      'No troops.', 'Sure?', Words.melt, Words.sharpen, Words.carve, Words.back, Words.remove, 'All',
      'Rare · in Vault', 'Epic · in Vault', 'Legendary · on Templar (13)', 'Epic · on Wizard (asleep)', 'Oath: all troops',
      'Melt God\'s Thunder into:', 'Already sharpened this round: again after wave 90',
      'Sharpened: again after wave 90', 'Again after w90',
      'Dragon Heart now on Templar', 'Dragon Heart moved to Templar -30k', 'Dragon Heart to Vault', 'x0 (asleep)',
      'Boss hits lived (wave 90)', 'Boss hits (w90)', 'Grail melted',
      // decisions-log 202: the action rows, their lines and the descriptions' tails.
      'Give to troops', 'Give to an Artifact', 'Equip on a troop', 'Remove from a troop', 'Each type', 'Equip on a type',
      'Move to a type', 'Take it off', Words.toVault, '1 type can take it', '7 types can take it', 'No type can take it now',
      'Carve: 4 can take it', 'No Artifact can take it', '1 troop can wear it', '5 troops can wear it', 'No troop can wear it now',
      '1 troop wears it', '2 troops wear it', 'What it gives each type', 'Free: a whole type gets it',
      'Costs 30k: a whole type gets it', 'Costs 30k', 'Templar loses it, free', 'Into another Artifact: +1 star',
      'for one troop type. Each type takes a few.', '$relicSlotsLine.', '$pusakaLine.', 'Carve +3 is lost',
      for (final why in [...pusakaRefusalsAll, ...asahRefusalsAll, ...leburRefusalsAll]) why,
    ]) {
      final missing = line.replaceAll('★', '').runes.where((c) => !chars.contains(c)).map(String.fromCharCode).toList();
      expect(missing, isEmpty, reason: line);
    }
  });
}

/// The refusal tables the facing page shows, every value.
final pusakaRefusalsAll = [
  pusakaRefusals.midWave, pusakaRefusals.none, pusakaRefusals.same, pusakaRefusals.gold, pusakaRefusals.unbound, //
  pusakaRefusals.notType, pusakaRefusals.noSuggestion, pusakaRefusals.oath, ...pusakaActionNames.values,
];
final asahRefusalsAll = [
  asahRefusals.midWave, asahRefusals.once, asahRefusals.gold, asahRefusals.relics, asahRefusals.items, asahRefusals.legend, //
  asahRefusals.maxed,
];
final leburRefusalsAll = [
  leburRefusals.notGudang, leburRefusals.midWave, leburRefusals.legend, leburRefusals.noTarget, leburRefusals.same, //
  leburRefusals.maxed, leburRefusals.rarity, leburRefusals.gold, leburRefusals.relics,
];
