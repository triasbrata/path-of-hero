// The Pusaka on the book (decisions-log 151; docs/ui-hud.md "Tas", loot-items-relics.md "Pusaka"): the Tas page binds
// one in two taps (its slot, then a type's row), moves it for a Pindah and takes it back to the Gudang (no Jual: the Bag
// sells nothing, decisions-log 296);
// the old save's note with OK and Batal; what a row previews at wave 86 (Dragon Heart on the Templar: HP 580 to 927, the
// wave-90 boss's blows 0 to 1); a Pasukan row's badge, faded while it sleeps, and its tooltip's type-wide totals; and the
// page fitting a desktop and a phone. The rules: pusaka_test.dart. One TdGame per widget test.
//
// Never let a wave be won or the game end here (the Board then saves): a wave begun runs a few frames only.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' show PointerDeviceKind;

import 'package:flame/game.dart' hide Game;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';
import 'package:tower_defense/main.dart';

import 'hud_font.dart';

/// Boots one TdGame in a [size] window, past the welcome screen, with the game's font and the minimap folded.
Future<Board> boot(WidgetTester tester, [Size size = const Size(1266, 713)]) async {
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

/// Turns the Army grid's pager to [type]'s cell: on the shorter landscape book (decisions-log 283) the grid takes two
/// pages at 1266x713.
Future<void> armyTo(WidgetTester tester, Board b, String type) async {
  for (var i = 0; i < 9 && b.troopRow(type) == Rect.zero && b.armyPage > 0; i++) {
    await tapOn(tester, b.armyPager.$1.center);
  }
  for (var i = 0; i < 9 && b.troopRow(type) == Rect.zero && b.armyPage < b.armyPageCount - 1; i++) {
    await tapOn(tester, b.armyPager.$2.center);
  }
  expect(b.troopRow(type), isNot(Rect.zero), reason: '$type on a page of the grid');
}

/// Turns the open book to its Tas page, after closing the message window (the save's notes can lie over the tabs:
/// a press on the window does nothing else).
Future<void> openBag(WidgetTester tester, Board b) async {
  if (b.messageBox != Rect.zero) await tapOn(tester, b.messageBox.center);
  await tapOn(tester, b.bookTabs.firstWhere((t) => t.$1 == 'bag').$2.center);
  expect(b.bagOpen, isTrue);
}

/// The owner's wave-86 save from before the Pusaka (a copy; never the real save): its five artefacts load as Pusaka
/// bound by default, ★1 each, and its note waits.
Game w86() => Game.fromJson(jsonDecode(File('test/fixtures/save-20261001-2005-pre-awaken.json').readAsStringSync()) as Map<String, dynamic>);

const five = [Relic.dragonHeart, Relic.dawnStar, Relic.godThunder, Relic.grail, Relic.voidEye];

void main() {
  test('what a Templar row previews for Dragon Heart at wave 86: HP 580 to 927 for 13, the wave-90 boss\'s blows 0 to 1', () {
    final g = w86()..undoDefaultBinding(); // Batal: all five in the Gudang, each first binding free
    final p = g.pusakaPreview(Relic.dragonHeart, 'knight_templar');
    expect((p.why, p.action, p.price, p.alive, p.bossWave, p.blows), (null, PusakaAction.pasang, 0, 13, 90, (0, 1)));
    // As the field has them, the Hero's aura included: 504 HP in the book is 580 (x1.15), and 806 with Dragon Heart is
    // 927 (the design's 928 was 580 x 1.6).
    expect((g.statsOf('knight_templar').hp, g.fieldStats('knight_templar').hp), (504, 580));
    expect(p.stats.first, (StatKind.hp, 580, 927));
    expect((thousands(13 * (927 - 580)), thousands(1803245), thousands(-4511), thousands(999)), ('4,511', '1,803,245', '-4,511', '999'));
    expect(g.bossBlowsLived('knight_templar', 927, 90), 1); // 841 a blow, less the defence 20.7: 107 HP left
    expect(g.bossBlowsLived('knight_templar', 580, 90), 0);
    // A Pusaka that changes no stat previews none, and no blows.
    final thunder = g.pusakaPreview(Relic.godThunder, 'wizard');
    expect(thunder.stats, isEmpty);
    expect((thunder.blows, thunder.alive), (null, 9));
    expect(pusakaGist(Relic.godThunder, 1), 'Hits 2 more, 40%');

    // Bound by default (the save as it loads): its row takes it back to the Gudang, another type's is a Pindah.
    final d = w86();
    final lepas = d.pusakaPreview(Relic.dragonHeart, 'knight_templar');
    expect((lepas.action, lepas.price, lepas.blows), (PusakaAction.lepas, 0, (1, 0)));
    expect(lepas.stats.first, (StatKind.hp, 927, 580));
    final pindah = d.pusakaPreview(Relic.dragonHeart, 'armored_axeman');
    expect((pindah.why, pindah.action, pindah.price, pindah.alive), (null, PusakaAction.pindah, rerollPrice(86), 6));
    expect(rerollPrice(86), 38000);
    // Short of gold, and mid-wave, the row can't.
    d.gold = 100;
    expect(d.pusakaPreview(Relic.dragonHeart, 'armored_axeman').why, pusakaRefusals.gold);
    d
      ..gold = 1000000
      ..startWave();
    expect(d.pusakaPreview(Relic.dragonHeart, 'armored_axeman').why, pusakaRefusals.midWave);
    expect(d.pusakaPreview(Relic.dragonHeart, 'knight_templar').why, pusakaRefusals.midWave); // Lepas too
  });

  test('a bound Pusaka\'s tooltip sums it over its type; asleep it says none lives', () {
    final g = w86();
    expect(g.pusakaTotals(Relic.dragonHeart), ['Now: 13 Templar, +4,511 HP, +121 HP/s']);
    expect(g.relicInfo(Relic.dragonHeart).$2, [
      '+60% max HP',
      'Heals 1% max HP every second',
      'Now: 13 Templar, +4,511 HP, +121 HP/s',
      pusakaLine,
      'On: Templar ★1',
    ]);
    expect(g.pusakaTotals(Relic.dawnStar).single, allOf(startsWith('Now: 17 ${troopTypeNames['priest']}, +'), endsWith(' heal/s')));
    expect(g.pusakaTotals(Relic.grail), ['Now: up to 6 saves a wave']);
    expect(g.pusakaTotals(Relic.godThunder), ['Now: 9 ${troopTypeNames['wizard']}, +80% damage in crowds']);
    expect((thousands(4511), thousands(1803245), thousands(-4511), thousands(999)), ('4,511', '1,803,245', '-4,511', '999'));
    g.givePusaka(Relic.voidEye, type: 'soldier'); // none of them alive
    expect(g.pusakaTotals(Relic.voidEye), ['Asleep: no ${troopTypeNames['soldier']} alive']);
    expect(g.relicInfo(Relic.voidEye).$2.last, 'On: ${troopTypeNames['soldier']} ★1 (asleep)');
    g.unbindPusaka(Relic.voidEye);
    expect(g.pusakaTotals(Relic.voidEye), isEmpty);
    expect(g.pusakaNotes().last, pusakaNoteSuggested);
    expect(g.pusakaNotes(), isEmpty); // once
  });

  testWidgets('a Pusaka binds in two taps from the Bag page; the note\'s Undo, a Move, To Vault, and mid-wave the '
      'rows say why', (tester) async {
    final b = await boot(tester);
    final g = b.state = w86().boardRules()..towns = false..chests.clear(); // its catch-up chests' popup would take the taps (draft_hud_test.dart)
    await frames(tester, 50); // the book floats in; the save's notes show
    expect(b.message, contains(pusakaNoteLines.first));
    expect(b.message, contains(pusakaNoteSuggested));
    await openBag(tester, b);
    for (final r in five) {
      expect(b.bagSlot(r), isNot(Rect.zero), reason: '$r');
      expect(b.bagMarks(r)!.bound, isNotNull, reason: '$r bound by default: its type\'s mark on its cell');
    }
    expect((b.pusakaNoteButton('ok') == Rect.zero, b.pusakaNoteButton('batal') == Rect.zero), (false, false));

    // Batal: the suggestion goes back to the Gudang, each first binding free again; the note is done.
    await tapOn(tester, b.pusakaNoteButton('batal').center);
    expect(g.gudang.toSet(), five.toSet());
    expect((b.message, g.pusakaSuggested), ('Suggestion undone: Artifacts to Vault', false));
    await frames(tester);
    for (final r in five) {
      expect((b.bagSlot(r) == Rect.zero, b.bagMarks(r)!.bound), (false, null), reason: '$r in the Gudang: the same cell, no mark');
    }
    expect(b.pusakaNoteButton('batal'), Rect.zero);

    // Tap 1: Dragon Heart's slot picks it, and the facing page says what it can do (decisions-log 202); tap 2: "Equip on a
    // type" lists the types.
    await tapOn(tester, b.bagSlot(Relic.dragonHeart).center);
    expect(b.picked, Relic.dragonHeart);
    expect(b.bagActions.map((a) => a.$1), containsAllInOrder([BagAction.types, BagAction.sharpen]));
    await tapOn(tester, b.bagAction(BagAction.types).center);
    expect(b.assignRows.first.$1, troopTypes.keys.first);
    await tapOn(tester, b.assignChip('knight_templar').center);
    final (who, row, ok) = b.assignRows.single;
    expect((who, ok), ('knight_templar', true));
    // Tap 3: the Templar row binds it, free; the pick and its chooser stay, so the rows show where it went.
    final gold = g.gold;
    await tapOn(tester, row.center);
    expect((g.pusaka[Relic.dragonHeart]!.type, g.gold, b.picked), ('knight_templar', gold, Relic.dragonHeart));
    expect(b.message, 'Dragon Heart now on Templar');
    expect(g.troops.where((u) => u.type == 'knight_templar').map((u) => u.maxHp).toSet(), {927});
    // Its row again: back to the Gudang, free. Again: a Pindah now, one reroll price.
    await tapOn(tester, row.center);
    expect((g.pusaka[Relic.dragonHeart]!.type, g.gold, b.message), (null, gold, 'Dragon Heart to Vault'));
    await tapOn(tester, row.center);
    expect((g.pusaka[Relic.dragonHeart]!.type, g.gold, b.message), ('knight_templar', gold - 38000, 'Dragon Heart moved to Templar -38k'));

    // Mid-wave its "Equip on a type" is greyed with why, and a tap on it says so and binds nothing.
    g.startWave(); // the book shuts for the wave
    await frames(tester, 40);
    await tapOn(tester, b.bookButton.center); // and opens on Pasukan
    await frames(tester, 40);
    await openBag(tester, b);
    await tapOn(tester, b.bagSlot(Relic.dawnStar).center);
    expect(b.picked, Relic.dawnStar);
    expect(b.bagActions.firstWhere((a) => a.$1 == BagAction.types).$3, isFalse);
    expect(b.bagDetailText('hint:types'), pusakaRefusals.midWave);
    await tapOn(tester, b.bagAction(BagAction.types).center);
    expect((b.message, g.pusaka[Relic.dawnStar]!.type, b.bagChooser), (pusakaRefusals.midWave, null, null));
    await frames(tester, 10); // the last tap's gesture timers run out
  });

  testWidgets('an Army cell shows its Pusaka\'s badge, faded while none of its type lives ("tidur"), and the Pusaka\'s '
      'tooltip over it', (tester) async {
    final b = await boot(tester);
    final g = b.state = w86().boardRules()..towns = false..chests.clear();
    await frames(tester, 50);
    expect((b.troopRow('soldier') == Rect.zero, b.pusakaBadge('soldier')), (false, Rect.zero)); // holds none
    await armyTo(tester, b, 'knight_templar');
    expect((b.pusakaBadge('knight_templar') == Rect.zero, b.pusakaBadgeAsleep('knight_templar')), (false, false));
    // Inside its cell, its icon in the top left corner (decisions-log 218: no price or Release on a cell).
    final row = b.troopRow('knight_templar'), badge = b.pusakaBadge('knight_templar');
    expect((row.contains(badge.topLeft), row.contains(badge.bottomRight - const Offset(1, 1))), (true, true));
    expect((badge.bottom < row.center.dy, badge.right < row.center.dx), (true, true));

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(b.pusakaBadge('knight_templar').center);
    await frames(tester, 30);
    expect(b.tooltipShown?.$1, 'Dragon Heart');
    expect(b.tooltipShown!.$2, containsAll(['Now: 13 Templar, +4,511 HP, +121 HP/s', 'On: Templar ★1']));
    await mouse.moveTo(Offset.zero); // off it, so no tooltip stays up (a tap while one shows is taken for a long press)
    await frames(tester, 10);
    g.givePusaka(Relic.voidEye, type: 'soldier'); // none alive: asleep
    await armyTo(tester, b, 'soldier');
    expect((b.pusakaBadge('soldier') == Rect.zero, b.pusakaBadgeAsleep('soldier')), (false, true));
    await mouse.moveTo(b.pusakaBadge('soldier').center);
    await frames(tester, 30);
    expect(b.tooltipShown?.$1, 'Void Eye');
    expect(b.tooltipShown!.$2, containsAll(['Asleep: no ${troopTypeNames['soldier']} alive', 'On: ${troopTypeNames['soldier']} ★1 (asleep)']));
    await mouse.moveTo(Offset.zero);
    await frames(tester);
    await mouse.removePointer();
    // The note's OK keeps the save's suggestion: its strip goes, and a later move is a Pindah.
    await openBag(tester, b);
    await tapOn(tester, b.pusakaNoteButton('ok').center);
    expect((g.pusakaSuggested, g.pusaka[Relic.dragonHeart]!.type), (false, 'knight_templar'));
    expect(b.pusakaNoteButton('ok'), Rect.zero);
    await frames(tester, 10);
  });

  testWidgets('the Army page and the Tas page\'s preview show the same HP for the w86 Templar, the field\'s (Game.fieldStats: '
      'the Hero\'s aura in): 927 with Dragon Heart, 580 without; the HP tooltip says the base and the aura', (tester) async {
    final b = await boot(tester);
    final g = b.state = w86().boardRules()..towns = false..chests.clear();
    await frames(tester, 50);
    if (b.messageBox != Rect.zero) await tapOn(tester, b.messageBox.center);
    await armyTo(tester, b, 'knight_templar');
    await tapOn(tester, b.troopRow('knight_templar').center); // its stats on the right page
    expect(b.troopPicked, 'knight_templar');
    // Bound by default: the page has what the Templars on the field have, not the book's 806.
    final templars = g.troops.where((u) => u.alive && !u.hero && u.type == 'knight_templar');
    expect((g.statsOf('knight_templar').hp, g.fieldStats('knight_templar').hp), (806, 927));
    expect(templars.map((u) => u.maxHp).toSet(), {927});
    expect(b.troopRowStats('knight_templar').first, '927');
    // Its Tas row with Dragon Heart picked: Lepas, 927 to 580.
    await openBag(tester, b);
    await tapOn(tester, b.bagSlot(Relic.dragonHeart).center);
    await tapOn(tester, b.bagAction(BagAction.types).center);
    await tapOn(tester, b.assignChip('knight_templar').center);
    expect(b.tasRowStat('knight_templar'), ('927', '580'));
    // Back in the Gudang (the note's Batal): the preview is 580 to 927, and the row 580 (the book's 504).
    await tapOn(tester, b.pusakaNoteButton('batal').center);
    await frames(tester);
    expect((g.pusaka[Relic.dragonHeart]!.type, b.tasRowStat('knight_templar')), (null, ('580', '927')));
    await tapOn(tester, b.bookTabs.firstWhere((t) => t.$1 == 'troops').$2.center);
    expect((g.statsOf('knight_templar').hp, b.troopRowStats('knight_templar').first), (504, '580'));
    expect(templars.map((u) => u.maxHp).toSet(), {580});
    // The book's number only where the tooltip explains it: the base, and the aura that makes it 580.
    expect(g.hpInfo('knight_templar').$2, [
      'Max HP 580 (base ${troopTypes['knight_templar']!.hp})',
      'Only Awaken raises it',
      'Each level: +${(awakenHp * 100).round()}% of base',
      'Hero aura x1.15',
    ]);
    await frames(tester, 10); // the last tap's gesture timers run out
  });

  testWidgets('the Tas page with a Pusaka picked fits 1266x713 and 1164x777: its cells and the note on the left page, its '
      'Sharpen and the Vault\'s Melt in its action rows on the facing page (decisions-log 202)', (tester) async {
    final b = await boot(tester);
    // 1164x777: at 915x412 the action rows take the list's scroll (bag_detail_test.dart and bag_grid_test.dart wheel
    // to them), so they are never all in view at once.
    for (final size in const [Size(1266, 713), Size(1164, 777)]) {
      tester.view.physicalSize = size;
      final g = b.state = w86().boardRules()..towns = false..chests.clear();
      g.unbindPusaka(Relic.voidEye); // one in the Gudang, the rest still the save's suggestion: every strip shows
      await frames(tester, 50);
      await openBag(tester, b);
      await tapOn(tester, b.bagSlot(Relic.voidEye).center);
      expect(b.picked, Relic.voidEye, reason: '$size');
      final book = b.bookArea, list = b.assignList, left = Rect.fromLTRB(book.left, book.top, list.left, list.bottom);
      final right = list;
      final boxes = [
        for (final (kind, cell) in b.bagCells) ('cell $kind', cell, left),
        ('OK', b.pusakaNoteButton('ok'), left),
        ('Undo', b.pusakaNoteButton('batal'), left),
        ('Asah', b.asahButton, right),
        ('Lebur', b.leburButton, right), // decisions-log 164
      ];
      expect([for (final r in five) b.bagSlot(r)], everyElement(isNot(Rect.zero)), reason: '$size');
      for (final (name, box, page) in boxes) {
        expect(box, isNot(Rect.zero), reason: '$size $name shown');
        expect(page.contains(box.topLeft) && page.contains(box.bottomRight - const Offset(0.5, 0.5)), isTrue, reason: '$size $name $box in $page');
      }
      for (final (i, (a, x, _)) in boxes.indexed) {
        for (final (b2, y, _) in boxes.skip(i + 1)) {
          expect(x.overlaps(y), isFalse, reason: '$size $a over $b2');
        }
      }
      expect(b.assignRows, isNotEmpty);
      for (final (who, r, _) in b.assignRows) {
        expect(r.left >= list.left && r.right <= list.right, isTrue, reason: '$size $who row $r in $list');
      }
      await tapOn(tester, b.bagSlot(Relic.voidEye).center); // put back
    }
    await frames(tester, 10);
  });

  testWidgets('the Lebur picker fits 1266x713 and 1164x777 (decisions-log 164): its row in the Vault '
      'Artifact\'s actions, then its head and Back under the heading, a row per target in the list, none over another', (tester) async {
    final b = await boot(tester);
    // 1164x777: at 915x412 the action rows take the list's scroll (bag_detail_test.dart and bag_grid_test.dart wheel
    // to them), so they are never all in view at once.
    for (final size in const [Size(1266, 713), Size(1164, 777)]) {
      tester.view.physicalSize = size;
      final g = b.state = w86().boardRules()..towns = false..chests.clear();
      g
        ..dismissPusakaNote()
        ..unbindPusaka(Relic.voidEye);
      for (final r in [Relic.ironBanner, Relic.bloodFang, Relic.warDrum, Relic.mourningBell]) {
        g.givePusaka(r); // eight targets: more than a phone's page holds
      }
      await frames(tester, 50);
      await openBag(tester, b);
      await tapOn(tester, b.bagSlot(Relic.voidEye).center);
      final book = b.bookArea, page = b.assignList; // the action rows' list
      final lebur = b.leburButton;
      expect(lebur, isNot(Rect.zero), reason: '$size');
      expect(page.contains(lebur.topLeft) && page.contains(lebur.bottomRight - const Offset(0.5, 0.5)), isTrue, reason: '$size Lebur $lebur in $page');
      expect(lebur.height, greaterThanOrEqualTo(20), reason: '$size Lebur $lebur');

      await tapOn(tester, lebur.center);
      expect(b.leburOpen, Relic.voidEye, reason: '$size');
      final list = b.assignList, back = b.leburBack;
      // On whole px at each end (the list's edges can fall between them: 708.3 at 1164x777).
      expect(back.left >= list.left - 0.5 && back.right <= list.right + 0.5 && back.bottom <= list.top, isTrue, reason: '$size Batal $back over $list');
      expect(book.contains(back.topLeft) && book.contains(back.bottomRight - const Offset(0.5, 0.5)), isTrue, reason: '$size $back in $book');
      expect(back.height, greaterThanOrEqualTo(20), reason: '$size a finger\'s press');
      final rows = b.assignRows;
      expect(rows.map((r) => r.$1).first, Relic.dragonHeart, reason: '$size');
      expect(rows.length, greaterThanOrEqualTo(3), reason: '$size');
      for (final (i, (who, r, _)) in rows.indexed) {
        expect(r.left >= list.left && r.right <= list.right && r.top >= list.top && r.bottom <= list.bottom, isTrue,
            reason: '$size $who row $r in $list');
        expect(r.overlaps(back), isFalse, reason: '$size $who row over Batal');
        for (final (who2, r2, _) in rows.skip(i + 1)) {
          expect(r.overlaps(r2), isFalse, reason: '$size $who over $who2');
        }
      }
      // A phone's list scrolls to the last target.
      final wheel = TestPointer(1, PointerDeviceKind.mouse);
      await tester.sendEventToBinding(wheel.hover(list.center));
      await tester.sendEventToBinding(wheel.scroll(const Offset(0, 10000)));
      await frames(tester);
      expect(b.assignRows.last.$1, Relic.mourningBell, reason: '$size');
      await tapOn(tester, b.leburBack.center);
      expect(b.leburOpen, isNull, reason: '$size');
      await tapOn(tester, b.bagSlot(Relic.voidEye).center); // put back
    }
    await frames(tester, 10);
  });
}
