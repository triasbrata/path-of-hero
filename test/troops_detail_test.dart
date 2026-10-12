// The Army page (decisions-log 187, its layout 218; docs/ui-hud.md "Army"): the left page's grid of the nine types (two
// columns of cells, a pager where five rows don't fit), and the right page's detail of the picked type
// (troop_detail.dart): its header, the body's sections (scrolled when taller than their room) and their collapse, the
// stats, the next step's button (Awaken 4-5 and Forge, their refusals), the shortcuts to the Bag, a fallen Hero's Recall
// (the field's Toko, which the detail once sent the fallen to, went in decisions-log 296), and the foot
// (decisions-log 288): no separator, Release at the bottom-right and Replace fallen at the bottom-left, each as wide as
// its words; no Buy and no +Room (buying and the room are the spawn bar's since decisions-log 283:
// test/spawn_bar_test.dart); the taps each action takes and the fit at the five test windows. One TdGame per widget
// test.
//
// Never let a wave be won or the game end here (the Board then saves): a wave begun runs a few frames only.
import 'dart:math';

import 'package:flame/game.dart' hide Game;
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';
import 'package:tower_defense/main.dart';

import 'hud_font.dart';
import 'real_rules.dart';

const desk = Size(1266, 713), wide = Size(915, 412), tablet = Size(1164, 777);

/// The middle of field cell ([c], [r]), as a fallen troop's spot.
Point<double> cellMiddle(int c, int r) => Point(c * tile + tile / 2, r * tile + tile / 2);

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

/// Taps [r]'s middle (never Rect.zero) and counts it in [taps].
Future<void> tapOn(WidgetTester tester, Rect r, [List<int>? taps]) async {
  expect(r, isNot(Rect.zero));
  await tester.tapAt(r.center);
  await frames(tester);
  taps?[0]++;
}

/// Picks troop [type] on the Army page: its cell, after turning the grid to its page with the pager where it is on
/// another one (each turn a tap, counted in [taps] too).
Future<void> pick(WidgetTester tester, Board b, String type, [List<int>? taps]) async {
  while (b.troopRow(type) == Rect.zero && b.armyPage > 0) {
    await tapOn(tester, b.armyPager.$1, taps);
  }
  while (b.troopRow(type) == Rect.zero && b.armyPage < b.armyPageCount - 1) {
    await tapOn(tester, b.armyPager.$2, taps);
  }
  await tapOn(tester, b.troopRow(type), taps);
}

/// Troop [type]'s cell, the grid turned to its page first where it is on another (the turns not counted: a row's tap
/// budget is its own taps; at 915x412 the grid pages).
Future<Rect> cellOf(WidgetTester tester, Board b, String type) async {
  while (b.troopRow(type) == Rect.zero && b.armyPage > 0) {
    await tapOn(tester, b.armyPager.$1);
  }
  while (b.troopRow(type) == Rect.zero && b.armyPage < b.armyPageCount - 1) {
    await tapOn(tester, b.armyPager.$2);
  }
  return b.troopRow(type);
}

/// [who]'s row in the Bag's chooser, the list wheeled until it shows whole (at 915x412 it holds about two rows; a wheel
/// is no tap).
Future<Rect> chooserRow(WidgetTester tester, Board b, Object who) async {
  final mouse = TestPointer(9, PointerDeviceKind.mouse);
  await tester.sendEventToBinding(mouse.hover(b.assignList.center));
  final h = b.assignRows.map((r) => r.$2.height).reduce(max);
  bool whole() => b.assignRows.any((r) => r.$1 == who && r.$2.height >= h - 0.5);
  if (!whole()) {
    await tester.sendEventToBinding(mouse.scroll(const Offset(0, -100000)));
    await frames(tester);
  }
  for (var i = 0; i < 80 && !whole(); i++) {
    await tester.sendEventToBinding(mouse.scroll(const Offset(0, 20)));
    await frames(tester);
  }
  await tester.sendEventToBinding(mouse.hover(b.bookArea.topLeft)); // off the rows: a touch tap under a tooltip is no tap
  await tester.sendEventToBinding(mouse.removePointer());
  await frames(tester);
  return b.assignRows.firstWhere((r) => r.$1 == who).$2;
}

/// Where each of the detail's [keys] lies in its body's sections, over every scroll the body has (one sweep, 6 px a
/// step): how far down the sections it starts (null: never drawn whole at its top), and the scroll that shows the most
/// of it with that height. Leaves the body scrolled back to the top.
Future<Map<String, ({double? top, double scroll, double height})>> sweep(WidgetTester tester, Board b, List<String> keys) async {
  final most = max(0.0, b.troopDetailContent - b.troopDetailBody.height);
  final out = {for (final k in keys) k: (top: null as double?, scroll: 0.0, height: 0.0)};
  for (var s = 0.0;; s = min(most, s + 6)) {
    b.troopDetailScroll = s;
    await frames(tester, 1);
    final body = b.troopDetailBody;
    for (final k in keys) {
      final r = b.troopDetail(k), was = out[k]!;
      if (r == Rect.zero) continue;
      final top = was.top ?? (s == 0 || r.top > body.top ? r.top - body.top + s : null);
      out[k] = r.height > was.height ? (top: top, scroll: s, height: r.height) : (top: top, scroll: was.scroll, height: was.height);
    }
    if (s >= most) break;
  }
  b.troopDetailScroll = 0;
  await frames(tester);
  return out;
}

/// Scrolls the detail's body to where [key] shows whole (the most of it) and returns its rect there.
Future<Rect> reveal(WidgetTester tester, Board b, String key) async {
  final at = (await sweep(tester, b, [key]))[key]!;
  b.troopDetailScroll = at.scroll;
  await frames(tester);
  return b.troopDetail(key);
}

/// [r] wholly inside [area].
bool inside(Rect r, Rect area) => r.left >= area.left - 0.5 && r.top >= area.top - 0.5 && r.right <= area.right + 0.5 && r.bottom <= area.bottom + 0.5;

/// The board's rules with plenty of gold: the free priest alone (1 of 4 types).
Game rich() => Game().boardRules()
  ..gold = 50000;

/// Four types: the free priest, a soldier, an archer and a knight, everyone at its post.
Game fourTypes() {
  final g = rich();
  for (final type in ['soldier', 'archer', 'knight']) {
    expect(g.autoPlace(type), isTrue);
  }
  for (final u in g.troops) {
    u
      ..pos = u.post
      ..arriving = false;
  }
  return g;
}

/// Rich, the Shop open (wave [storeFrom] won), a knight on the field at Awaken 3 (its Awaken 4 for sale), the free
/// priest beside it.
Game shopper() {
  final g = rich()..wave = storeFrom;
  g.upgrades['knight'] = awakenItems('knight', 3);
  expect(g.autoPlace('knight'), isTrue);
  return g..gold = 1000000;
}

/// [shopper] with an archer fielded at Awaken 2 whose Awaken 3 the bag holds (its grade III set).
Game bagReady() {
  final g = shopper();
  g.upgrades['archer'] = awakenItems('archer', 2);
  g.inventory.addAll(g.gradeSet('archer', 3));
  expect(g.autoPlace('archer'), isTrue);
  return g;
}

/// The words of the detail's section [key] drawn this frame, joined.
String said(Board b, String key) => b.troopDetailWords(key).join(' | ');

/// Indonesian words that must not show on the detail (the in-game text is English; test/english_text_test.dart holds
/// lib/'s literals, this the page as drawn).
final _indonesian = RegExp(r'(?<![A-Za-z])(Bangkit|Tempa|Gugur|Pusaka|Gudang|Toko|Tas|Lepas|Jual|Beli|Emas|kurang|penuh|dulu|'
    r'Butuh|Sudah|Hanya|gelombang|Jenis|Pasukan|Membuka|Maks|Belum|Tidak|Prajurit|Ksatria|Pemanah|Pendeta)(?![A-Za-z])');

void main() {
  testWidgets('a cell tap picks and spends nothing, the pick lasting across page turns; no Buy on the detail (the spawn '
      'bar\'s, decisions-log 283)', (tester) async {
    final b = await boot(tester);
    for (final size in [desk, wide]) {
      tester.view.physicalSize = size;
      final g = b.state = rich();
      await frames(tester, 40); // the book floats in between waves
      expect(b.troopPicked, Game.freeHealer, reason: '$size: the first type with a living troop');
      final gold = g.gold, army = g.armySize;
      await tapOn(tester, b.troopRow('knight'));
      expect((b.troopPicked, g.gold, g.armySize), ('knight', gold, army), reason: '$size: a cell tap only picks');
      await tapOn(tester, b.troopRow('knight'));
      expect((b.troopPicked, g.gold, g.armySize), ('knight', gold, army), reason: '$size: again: nothing');
      expect(b.troopDetail('buy'), Rect.zero, reason: '$size: no Buy on the detail');
      expect(b.troopDetailWords('buy'), isEmpty, reason: '$size: no Buy on the detail');
      expect(b.spawnCard('knight'), isNot(Rect.zero), reason: '$size: the bar buys it');
      // The pick lasts across page turns, and another game picks again.
      await tapOn(tester, b.bookTabs.firstWhere((t) => t.$1 == 'bag').$2);
      await tapOn(tester, b.bookTabs.firstWhere((t) => t.$1 == 'troops').$2);
      expect(b.troopPicked, 'knight', reason: '$size');
      b.state = rich();
      await frames(tester);
      expect(b.troopPicked, Game.freeHealer, reason: '$size');
      await frames(tester, 30);
    }
  });

  testWidgets('Release is the picked type\'s: two taps (Release, the confirm), three from another type (its cell first); '
      'any other tap lets it go', (tester) async {
    final b = await boot(tester);
    for (final size in [desk, wide]) {
      tester.view.physicalSize = size;
      final g = b.state = fourTypes();
      await frames(tester, 40);
      await tapOn(tester, b.troopRow('knight'));
      expect((b.troopPicked, b.releaseChip('soldier')), ('knight', Rect.zero), reason: '$size: no Release on a cell');
      // Armed, then let go by a cell tap, which picks that cell.
      await tapOn(tester, b.troopRow('soldier'));
      await tapOn(tester, b.releaseChip('soldier'));
      expect((b.releaseArmed, b.troopPicked), ('soldier', 'soldier'), reason: '$size');
      expect(b.releaseConfirm.left, greaterThan(b.troopRow('soldier').right), reason: '$size: the confirm on the right page');
      expect(b.releaseConfirm.bottom, lessThanOrEqualTo(size.height), reason: '$size');
      await tapOn(tester, b.troopRow('archer'));
      expect((b.releaseArmed, b.releaseConfirm, b.troopPicked), (null, Rect.zero, 'archer'), reason: '$size');
      // Three taps from another type: the cell, Release, the confirm.
      final taps = [0], gold = g.gold, refund = g.releaseRefundOf('soldier');
      await tapOn(tester, b.troopRow('soldier'), taps);
      await tapOn(tester, b.releaseChip('soldier'), taps);
      await tapOn(tester, b.releaseConfirm, taps);
      expect((taps.single, g.troopCounts['soldier'], g.gold, b.releaseArmed), (3, null, gold + refund, null), reason: '$size');
      await frames(tester, 140);
    }
  });

  testWidgets('Replace fallen is on the right page at the foot\'s bottom-left on Release\'s line, under the troop\'s '
      'detail and clear of Release, which keeps its place whether it shows; no separator (decisions-log 288); +Room is not '
      'in the book (the spawn bar\'s, decisions-log 283)', (tester) async {
    final b = await boot(tester);
    for (final size in [desk, wide, tablet]) {
      tester.view.physicalSize = size;
      final g = b.state = rich();
      await frames(tester, 40);
      final room = b.capacityButton, buy = b.releaseChip(b.troopPicked); // the priest lives
      expect((room == Rect.zero, buy == Rect.zero, b.replaceButton, b.troopDetail('separator')), (false, false, Rect.zero, Rect.zero),
          reason: '$size');
      final list = b.bookRows.map((r) => r.right).reduce(max);
      expect(room.overlaps(b.bookArea), isFalse, reason: '$size: +Room in the spawn bar, $room');
      // The book bobs up and down between frames: Release keeps its place on the page (its left and size) while Replace
      // comes and goes at the foot's left.
      g.toReplace.add((type: 'soldier', post: cellMiddle(1, 1)));
      await frames(tester, 3);
      final at = b.replaceButton, now = b.releaseChip(b.troopPicked), right = b.bookPages.$2;
      expect((now.left, now.size), (buy.left, buy.size), reason: '$size: Release stays');
      expect((at.left, at.bottom, at.left > list, inside(at, right.inflate(1))), (right.left.roundToDouble(), now.bottom, true, true),
          reason: '$size: at the bottom-left, on Release\'s line, on the right page: $at in $right');
      expect((at.overlaps(now), b.troopDetail('replaceTap').overlaps(b.troopDetail('releaseTap'))), (false, false), reason: '$size');
      expect(at.top, greaterThan(b.troopDetailBody.bottom), reason: '$size: under the troop\'s detail');
      expect(b.replaceLabel, '${Words.replaceFallen} (1)  ${shortPrice(g.priceOf('soldier'))}', reason: '$size');
      g.toReplace.clear();
      await frames(tester, 3);
      final again = b.releaseChip(b.troopPicked);
      expect((again.left, again.size, b.replaceButton), (buy.left, buy.size, Rect.zero), reason: '$size');
      await frames(tester, 30);
    }
  });

  testWidgets('the Army page fits at 915x412, 1164x777 and 1266x713: the nine types in two columns of '
      'cells of one size (a pager in landscape), no price or Release on them; the detail right of them, its header at most '
      'half the page, then the body, and Release at the bottom-right, no separator (decisions-log 288)', (tester) async {
    final b = await boot(tester);
    for (final size in [wide, tablet, desk]) {
      tester.view.physicalSize = size;
      b.state = fourTypes();
      await frames(tester, 40);
      final screen = Offset.zero & size;
      // The shorter landscape book (decisions-log 283): two rows a page at 915x412 (two pages before it), two pages at
      // 1164x777 and 1266x713 (one before it).
      expect(b.armyPageCount, switch (size) { wide => 3, _ => 2 }, reason: '$size');
      // Every type on one page of the grid, in troopTypes order, two to a row.
      final cells = <String, Rect>{}, pages = <String, int>{};
      for (var p = 0; p < b.armyPageCount; p++) {
        if (p > 0) await tapOn(tester, b.armyPager.$2);
        expect(b.armyPage, p, reason: '$size');
        final (back, on) = b.armyPager;
        final leftPage = b.bookPages.$1; // the book bobs: this frame's page
        expect((back == Rect.zero, on == Rect.zero), (b.armyPageCount == 1, b.armyPageCount == 1), reason: '$size: the pager');
        for (final t in troopTypes.keys) {
          final r = b.troopRow(t);
          if (r == Rect.zero) continue;
          expect(cells.containsKey(t), isFalse, reason: '$size $t: on one page');
          cells[t] = r;
          pages[t] = p;
          expect(inside(r, leftPage.inflate(1)), isTrue, reason: '$size $t: $r in $leftPage');
          if (b.armyPageCount > 1) expect(r.bottom, lessThanOrEqualTo(min(back.top, on.top)), reason: '$size $t: over the pager');
        }
      }
      expect(cells.keys, troopTypes.keys, reason: '$size: every type, in order');
      final rows = cells.values.toList(), first = rows.first;
      for (final (i, r) in rows.indexed) {
        expect(r.size, first.size, reason: '$size cell $i: one size');
        expect(inside(r, screen), isTrue, reason: '$size cell $i: $r');
        expect(r.height, greaterThanOrEqualTo(48), reason: '$size cell $i: room for a big sprite');
      }
      for (final (i, t) in troopTypes.keys.indexed) {
        final r = cells[t]!;
        if (i % 2 == 1) {
          final before = cells[troopTypes.keys.elementAt(i - 1)]!;
          expect((r.top, r.left > before.right), (before.top, true), reason: '$size $t: beside the one before');
        } else if (i > 0 && pages[t] == pages[troopTypes.keys.elementAt(i - 1)]) {
          final above = cells[troopTypes.keys.elementAt(i - 2)]!;
          expect((r.left, r.top > above.bottom), (above.left, true), reason: '$size $t: under its column\'s first');
        }
      }
      // No price and no Release on the cells: Release is the detail's, for the pick; no Buy anywhere in the book.
      final listRight = rows.map((r) => r.right).reduce(max), pickNow = b.troopPicked;
      for (final t in troopTypes.keys) {
        expect(b.releaseChip(t) == Rect.zero, t != pickNow, reason: '$size $t');
      }
      expect(b.troopDetail('buy'), Rect.zero, reason: '$size: no Buy (decisions-log 283)');
      // The right page: the header at most half the page, the body under it, the foot under that.
      final head = b.troopDetail('heading'), body = b.troopDetailBody, release = b.releaseChip(pickNow);
      final tap = b.troopDetail('releaseTap');
      final rightPage = b.bookPages.$2;
      expect(head.height, lessThan(rightPage.height / 2), reason: '$size: the header under half the page');
      for (final (key, r) in [('head', head), ('body', body), ('release', release), ('its tap', tap)]) {
        expect(r.left, greaterThan(listRight), reason: '$size $key: $r right of the list');
        expect(inside(r, screen) && inside(r, rightPage.inflate(1)), isTrue, reason: '$size $key: $r in $rightPage');
      }
      // The header over the body (the foot one line since decisions-log 288, the body at least detailBodyMin under it at
      // 915x412 too), Release's tap under the body, Release at the page's bottom-right, narrower than half the page.
      expect([head.bottom <= body.top, body.bottom <= tap.top], everyElement(isTrue), reason: '$size: $head $body $tap');
      expect((release.height >= 24, release.right, release.bottom, release.width < rightPage.width / 2, b.troopDetail('separator')),
          (true, rightPage.right.roundToDouble(), rightPage.bottom.roundToDouble(), true, Rect.zero),
          reason: '$size: Release at the bottom-right, as wide as its words; no separator');
      expect(b.troopRowStats(pickNow), hasLength(8), reason: '$size');
      for (final (r, _, type) in b.itemCells) {
        expect((type, r.left > listRight, inside(r, screen)), (pickNow, true, true), reason: '$size: $r');
      }
      b.state = Game();
      await frames(tester, 30);
    }
  });

  testWidgets('the grid\'s pager at 915x412: its arrows and the wheel turn the page, the pick stays; picking a type on the '
      'other page shows it on the right', (tester) async {
    final b = await boot(tester, wide);
    b.state = fourTypes();
    await frames(tester, 40);
    // Three pages: two rows a page on the shorter landscape book (decisions-log 283).
    expect((b.armyPage, b.armyPageCount, b.troopPicked), (0, 3, 'soldier'), reason: 'the first type alive, on the first page');
    final last = troopTypes.keys.last;
    expect((b.troopRow(last), b.troopRow(troopTypes.keys.first) == Rect.zero), (Rect.zero, false));
    await tapOn(tester, b.armyPager.$1);
    expect(b.armyPage, 0, reason: 'no page before the first');
    await tapOn(tester, b.armyPager.$2);
    expect((b.armyPage, b.troopRow(last), b.troopRow(troopTypes.keys.first)), (1, Rect.zero, Rect.zero), reason: 'the middle page');
    await tapOn(tester, b.armyPager.$2);
    expect((b.armyPage, b.troopRow(last) == Rect.zero, b.troopRow(troopTypes.keys.first), b.troopPicked), (2, false, Rect.zero, 'soldier'));
    await tapOn(tester, b.troopRow(last));
    expect(b.troopPicked, last);
    expect(said(b, 'heading'), startsWith(troopTypeNames[last]!));
    // The wheel over the grid: a page back (up), and on (down).
    final mouse = TestPointer(9, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(mouse.hover(b.troopRow(last).center));
    await tester.sendEventToBinding(mouse.scroll(const Offset(0, -40)));
    await frames(tester);
    expect((b.armyPage, b.troopPicked), (1, last));
    await frames(tester, 30); // past the wheel's gap
    await tester.sendEventToBinding(mouse.scroll(const Offset(0, 40)));
    await frames(tester);
    expect(b.armyPage, 2);
    await frames(tester, 30);
  });

  testWidgets('the Army page\'s rows of the tap budget: +Room 1, Replace fallen 1, Release 2 when picked, 3 from another '
      'type (a buy is the spawn bar\'s: test/spawn_bar_test.dart)', (tester) async {
    final b = await boot(tester);
    for (final size in [desk, wide]) {
      tester.view.physicalSize = size;
      final g = b.state = rich()..capacity = 12;
      await frames(tester, 40);
      for (final t in ['soldier', 'knight']) {
        expect(g.autoPlace(t), isTrue);
      }
      await frames(tester, 3);
      await pick(tester, b, 'soldier');
      var taps = [0];
      final cap = g.capacity;
      await tapOn(tester, b.capacityButton, taps);
      expect((taps.single, g.capacity), (1, cap + capacityStep), reason: '$size: +Room');
      g.toReplace.add((type: 'knight', post: cellMiddle(1, 2)));
      await frames(tester, 3);
      taps = [0];
      final army = g.armySize;
      await tapOn(tester, b.replaceButton, taps);
      expect((taps.single, g.armySize, g.toReplace.length), (1, army + 1, 0), reason: '$size: Replace fallen');
      taps = [0];
      await tapOn(tester, b.releaseChip('soldier'), taps);
      await tapOn(tester, b.releaseConfirm, taps);
      expect((taps.single, g.troopCounts['soldier']), (2, null), reason: '$size: Release of the picked type');
      await frames(tester, 140); // its message goes (a tap on it would only close it)
      taps = [0];
      await pick(tester, b, 'knight', taps);
      await tapOn(tester, b.releaseChip('knight'), taps);
      await tapOn(tester, b.releaseConfirm, taps);
      expect((taps.single, g.troopCounts['knight']), (3, null), reason: '$size: Release of another type');
      await frames(tester, 140);
    }
  });

  testWidgets('the detail: header, stats and next step always; the Artifact, Heroes and relics only with something to '
      'say; every word English', (tester) async {
    final b = await boot(tester);
    for (final size in [desk, wide]) {
      tester.view.physicalSize = size;
      final g = b.state = rich(); // the free priest alone, before wave 15
      await frames(tester, 40);
      expect(b.troopPicked, Game.freeHealer, reason: '$size');
      for (final key in ['heading', 'stats', 'next', 'relics']) {
        expect(said(b, key), isNotEmpty, reason: '$size $key');
      }
      expect(b.troopDetail('release'), isNot(Rect.zero), reason: '$size: the priest lives: Release');
      expect(b.troopDetail('buy'), Rect.zero, reason: '$size: no Buy');
      for (final key in ['pusaka', 'heroes', 'upgrade', 'recall:0']) {
        expect((b.troopDetail(key), said(b, key)), (Rect.zero, ''), reason: '$size $key: nothing to say');
      }
      expect(said(b, 'heading'), contains('${troopTypeNames[Game.freeHealer]} | x1'), reason: '$size');
      expect(said(b, 'next'), startsWith('${awakenName(1)} needs'), reason: '$size'); // (grade I) where it fits
      expect(said(b, 'relics'), 'Relics: none', reason: '$size');

      // None alive: "None on field", and no relics line.
      await tapOn(tester, b.troopRow('soldier'));
      expect(said(b, 'heading'), matches('^${troopTypeNames['soldier']} \\| (None on field|x0(/\\d+)?)\$'), reason: '$size');
      expect(said(b, 'relics'), '', reason: '$size');

      // An Artifact owned (in the Vault): "No Artifact" and Bag; bound to the type: its name and Change.
      g.pusaka[Relic.dragonHeart] = OwnedPusaka(stars: 1);
      await tapOn(tester, b.troopRow('knight'));
      expect(said(b, 'pusaka'), 'No Artifact', reason: '$size');
      expect((said(b, 'bag'), said(b, 'change')), (Words.bag, ''), reason: '$size');
      g.pusaka[Relic.dragonHeart] = OwnedPusaka(type: 'knight', stars: 2);
      await frames(tester);
      expect(said(b, 'pusaka'), startsWith('${relicNames[Relic.dragonHeart]} | ${pusakaGist(Relic.dragonHeart, 2)}'), reason: '$size');
      expect((said(b, 'change'), said(b, 'bag')), ('Change', ''), reason: '$size');

      // A Hero of it, its relics, and a fallen one: "Fallen: Kael" and its Recall tag.
      expect(g.autoPlace('knight'), isTrue);
      final k = g.troops.firstWhere((u) => u.type == 'knight')
        ..hero = true
        ..relics.add(Relic.fang);
      await frames(tester);
      expect(said(b, 'heroes'), startsWith('Hero: ${k.name}'), reason: '$size');
      expect(said(b, 'relics'), 'Relics: | x1', reason: '$size');
      expect(b.troopDetailWords('recall'), isEmpty, reason: '$size: none fallen yet');
      g
        ..wave = storeFrom
        ..fallenHeroes.add(FallenHero(name: 'Kael', type: 'knight', stats: const [HeroStat.hp], fell: storeFrom));
      await frames(tester);
      expect(said(b, 'heroes'), contains('Fallen: Kael'), reason: '$size');
      expect(await reveal(tester, b, 'recall:0'), isNot(Rect.zero), reason: '$size');
      for (final key in ['heading', 'stats', 'next', 'pusaka', 'heroes', 'relics', 'release']) {
        expect(_indonesian.hasMatch(said(b, key)), isFalse, reason: '$size $key: ${said(b, key)}');
      }
      await frames(tester, 30);
    }
  });

  testWidgets('the attributes are the field\'s, two to a row, each a short name and value over what it means; each '
      'item\'s taken/cap beside it', (tester) async {
    final b = await boot(tester);
    final g = b.state = shopper();
    await frames(tester, 40);
    await tapOn(tester, b.troopRow('knight'));
    String f(num v) => v is int || v >= 100 || v == v.roundToDouble() ? '${v.round()}' : v.toStringAsFixed(1);
    final s = g.fieldStats('knight');
    expect(b.troopRowStats('knight'),
        [for (final v in [s.hp, s.mp, s.def, s.dmg, s.range, s.speed, max(minAttackInterval, s.rate), s.regen]) f(v)]);
    final words = b.troopDetailWords('stats');
    for (final w in [Words.hp, Words.mp, Words.defence, Words.damage, Words.range, Words.speed, Words.rate, Words.regen]) {
      expect(words, contains(w), reason: 'the short name $w');
    }
    expect(words, contains(Words.hpHelp.first), reason: 'what HP means, under it');
    for (final item in awakenRecipe['knight']!.keys) {
      // By grade the kind's grades together (decisions-log 249): what the knight holds of them, the caps of those open.
      final grades = [for (var n = 1; n <= maxAwaken; n++) itemOf(item.slot, n)];
      final (taken, cap) = (grades.fold(0, (a, i) => a + g.countOf('knight', i)), grades.fold(0, (a, i) => a + g.capOf('knight', i)));
      expect(words, contains('$taken/$cap'), reason: '$item');
    }
    // Two to a row: the first two item cells (Def and Dmg) side by side, the next two under them.
    final cells = [for (final (r, _, type) in b.itemCells) if (type == 'knight') r];
    expect((cells[0].top, cells[1].left > cells[0].right, cells[2].top > cells[0].bottom), (cells[1].top, true, true));
    // A healer's power is its heal.
    await tapOn(tester, b.troopRow(Game.freeHealer));
    expect(b.troopDetailWords('stats'), containsAll([Words.heal, Words.healHelp.first]));
    await frames(tester, 30);
  });

  testWidgets('a type whose speed stat passes its walk cap shows the walk it gets, red like a reach at its ceiling '
      '(decisions-log 311)', (tester) async {
    final b = await boot(tester);
    final g = b.state = shopper();
    await frames(tester, 40);
    await tapOn(tester, b.troopRow('knight'));
    const red = Color(0xFFB0302A);
    final under = g.fieldStats('knight').speed;
    expect(under, lessThan(walkCap('knight')));
    expect(b.troopStatInk(Words.speed), isNot(red));
    g.upgrades['knight'] = [...g.upgrades['knight']!, ...List.filled(12, Item.boots)];
    await frames(tester);
    expect(g.statsOf('knight').speed, greaterThan(walkCap('knight'))); // the stat: 24 × 1.25^12 and more
    expect(g.fieldStats('knight').speed, walkCap('knight')); // what it walks: 144
    expect(b.troopRowStats('knight')[5], '144');
    expect(b.troopStatInk(Words.speed), red);
    await frames(tester, 30);
  });

  testWidgets('the Awaken needs: one item a row with have/need and where it comes from (the Smithy; the Bag when it '
      'holds some)', (tester) async {
    final b = await boot(tester);
    final g = b.state = rich();
    g.inventory[Item.sword] = 1;
    await frames(tester, 40);
    await tapOn(tester, b.troopRow('soldier'));
    final next = said(b, 'next');
    expect(next, startsWith('${awakenName(1)} needs (${gradeName(1)}):'));
    for (final MapEntry(key: item, value: n) in g.gradeSet('soldier', 1).entries) {
      expect(next, contains('${itemNames[item]} | 0/$n'), reason: '$item');
    }
    expect(next, contains('In ${Words.bag}: 1'), reason: 'the sword in the Bag');
    expect(next, contains(Words.smithy), reason: 'the rest from the Smithy');
    await frames(tester, 30);
  });

  testWidgets('the next step\'s button buys Awaken 4-5 and refuses: closed, short of gold, mid-wave; at Awaken 5 it '
      'forges (the Toko\'s Awaken rows, which bought the same, went in decisions-log 296)', (tester) async {
    final b = await boot(tester);
    // The detail's button on [g]: the gold, level, Forge level and message after its tap.
    Future<(int, int, int, String?)> via(Game g) async {
      b.state = g;
      await frames(tester, 40);
      await tapOn(tester, b.troopRow('knight'));
      await tapOn(tester, await reveal(tester, b, 'upgrade'));
      final out = (g.gold, g.awakenLevel('knight'), g.tempaOf('knight'), b.message);
      await frames(tester, 140); // the message goes
      return out;
    }

    // Bought: Awaken 4 for 100k, "Knight: Awaken 4!".
    expect(await via(shopper()), (1000000 - ascendPrice[0], 4, 0, '${troopTypeNames['knight']}: ${Words.awaken} 4!'));
    // Short of gold: refused, with why.
    expect(await via(shopper()..gold = 1000), (1000, 3, 0, Words.notEnoughGold));
    // At Awaken 5: Forge +1.
    Game five() => shopper()..ascended['knight'] = maxAscend;
    expect(await via(five()), (1000000 - five().tempaPriceOf('knight')!, 5, 1, '${troopTypeNames['knight']}: ${tempaName(1)}!'));

    // The Shop closed (before wave 15): white, "Awaken 4: Opens after wave 15", and a tap says why.
    final g = b.state = shopper()..wave = storeFrom - 1;
    await frames(tester, 40);
    await tapOn(tester, b.troopRow('knight'));
    final why = storeRefusalNames[StoreRefusal.locked]!;
    expect(b.troopDetailWords('next').last, anyOf('${awakenName(4)}: $why', why), reason: 'greyed with why');
    await tapOn(tester, await reveal(tester, b, 'upgrade'));
    expect((g.awakenLevel('knight'), g.gold, b.message), (3, 1000000, why));
    await frames(tester, 140);

    // Mid-wave on the phone (915x412), the book opened by its button (pausing the wave): "Only between waves".
    tester.view.physicalSize = wide;
    final w = b.state = shopper()..wave = storeFrom + 1;
    await frames(tester, 40);
    w.startWave();
    await frames(tester, 3);
    await tapOn(tester, b.bookButton);
    await frames(tester, 30); // the book slides in
    await tapOn(tester, b.troopRow('knight'));
    await tapOn(tester, await reveal(tester, b, 'upgrade'));
    expect((w.awakenLevel('knight'), b.message, w.paused), (3, Words.onlyBetweenWaves, true));
    b.state = Game(); // leave no wave to win
    await frames(tester, 140);
  });

  testWidgets('the shortcuts: Change opens the Bag with the Artifact picked, on screen and its types listed, Bag its '
      'Artifacts, "Awaken 3 from the Bag" the item it needs with its types listed (then one row '
      'tap gives it)', (tester) async {
    final b = await boot(tester);
    for (final size in [desk, wide]) {
      tester.view.physicalSize = size;
      var g = b.state = shopper();
      g.pusaka[Relic.dragonHeart] = OwnedPusaka(type: 'knight', stars: 2);
      await frames(tester, 40);
      await tapOn(tester, b.troopRow('knight'));
      await tapOn(tester, await reveal(tester, b, 'change'));
      expect((b.bagOpen, b.picked, b.bagChooser), (true, Relic.dragonHeart, BagAction.types), reason: '$size: its types');
      expect(b.bagSlot(Relic.dragonHeart), isNot(Rect.zero), reason: '$size: its cell shows');
      await tapOn(tester, b.bookTabs.firstWhere((t) => t.$1 == 'troops').$2);

      // "No Artifact": Bag opens on the Artifacts chip.
      g.pusaka[Relic.dragonHeart] = OwnedPusaka(stars: 2);
      await frames(tester);
      await tapOn(tester, await reveal(tester, b, 'bag'));
      expect((b.bagOpen, b.picked, b.bagCategory), (true, null, BagCategory.artifacts), reason: '$size');
      await tapOn(tester, b.bagChip(BagCategory.all)); // leave the chip as it was
      await tapOn(tester, b.bookTabs.firstWhere((t) => t.$1 == 'troops').$2);

      // "Awaken 3 from the Bag": the first item the archer needs, picked; a tap on its row gives it.
      g = b.state = bagReady();
      await frames(tester, 40);
      await tapOn(tester, b.troopRow('archer'));
      expect(b.troopDetailWords('next').last, bagAwakensTo(3), reason: '$size');
      final taps = [0];
      await tapOn(tester, await reveal(tester, b, 'upgrade'), taps);
      final need = [for (final item in g.awakenShort('archer').keys) if ((g.inventory[item] ?? 0) > 0) item].first;
      expect((b.bagOpen, b.picked, b.bagChooser), (true, need, BagAction.giveTroops), reason: '$size: its types');
      final had = g.countOf('archer', need);
      await tapOn(tester, await chooserRow(tester, b, 'archer'), taps);
      expect((taps.single, g.countOf('archer', need)), (2, had + 1), reason: '$size: 2 taps (3 before)');
      await tapOn(tester, b.bookTabs.firstWhere((t) => t.$1 == 'troops').$2);
      await frames(tester, 30);
    }
  });

  testWidgets('the foot: Release arms and becomes its confirm (2 taps); mid-wave Release says why; a type with none alive '
      'has no Release, its body down to the page\'s bottom (no separator, decisions-log 288)', (tester) async {
    final b = await boot(tester);
    for (final size in [desk, wide]) {
      tester.view.physicalSize = size;
      final g = b.state = fourTypes();
      await frames(tester, 40);
      await tapOn(tester, b.troopRow('archer'));
      final taps = [0], refund = g.releaseRefundOf('archer'), was = g.gold, room = b.capacityButton;
      await tapOn(tester, b.troopDetail('release'), taps);
      expect((b.releaseArmed, b.troopDetail('release'), b.troopDetail('releaseConfirm') == Rect.zero), ('archer', Rect.zero, false), reason: '$size');
      final yes = b.troopDetail('confirm'), page = b.bookPages.$2;
      expect((inside(yes, page.inflate(1)), yes.right, yes.bottom), (true, page.right.roundToDouble(), page.bottom.roundToDouble()),
          reason: '$size: the confirm at the bottom-right of the page');
      expect((b.capacityButton.left, b.capacityButton.size), (room.left, room.size), reason: '$size: +Room stays (the spawn bar\'s)');
      expect(_indonesian.hasMatch(said(b, 'releaseConfirm')), isFalse, reason: said(b, 'releaseConfirm'));
      await tapOn(tester, b.troopDetail('releaseConfirm'), taps);
      expect((taps.single, g.troopCounts['archer'], g.gold, b.releaseArmed), (2, null, was + refund, null), reason: '$size');
      // None alive now: no Release, the body reaching down to the page's bottom, a gap over it.
      await frames(tester, 3);
      expect((b.troopDetail('release'), b.troopDetail('releaseTap'), b.troopDetail('separator')), (Rect.zero, Rect.zero, Rect.zero), reason: '$size');
      expect(b.bookPages.$2.bottom - b.troopDetailBody.bottom, lessThan(10), reason: '$size: the body takes the foot\'s room');
      await frames(tester, 140);
    }
    // Mid-wave on the phone (915x412), the book opened by its button (pausing the wave): Release is greyed and says
    // why; the pick stays.
    tester.view.physicalSize = wide;
    final w = b.state = fourTypes();
    await frames(tester, 40);
    w.startWave();
    await frames(tester, 3);
    await tapOn(tester, b.bookButton);
    await frames(tester, 30); // the book slides in
    await tapOn(tester, b.troopRow('knight'));
    await tapOn(tester, b.troopDetail('release'));
    expect((b.releaseArmed, b.message, w.troopCounts['knight'], b.troopPicked, w.paused), (null, w.whyNotRelease('knight'), 1, 'knight', true));
    b.state = Game(); // leave no wave to win
    await frames(tester, 140);
  });

  testWidgets('the foot (decisions-log 288) at 1600x947, 1266x713, 1164x777 and 915x412: no separator; Release '
      'as wide as its words at the page\'s bottom-right; armed, the red confirm grows leftwards from the same right edge '
      'as wide as its words, inside the row; Replace fallen at the bottom-left, as wide as its words, beside Release or '
      'over it, never on it; every press area 44 px each way at least; the taps arm, confirm and replace as before',
      (tester) async {
    final b = await boot(tester);
    // A button of the foot: as wide as its words with the button's own margins (its bevel and 6 px a side, the spawn
    // bar's rule), [row] wide at the most (the confirm's words may need the row), its words inside it.
    void wordsWide(Rect face, Rect words, String what, {double row = double.infinity}) {
      final k = (face.height / 16).floorToDouble().clamp(1.0, 3.0);
      expect((face.width, inside(words, face)), (min(row, (words.width + 2 * (4 * k + 6)).roundToDouble()), true),
          reason: '$what: $face $words');
    }

    // Its press area: 44 px each way at least, around the button.
    void tapRule(Rect press, Rect face, String what) {
      expect((press.width >= detailTapMin, press.height >= detailTapMin, inside(face, press)), (true, true, true), reason: '$what: $press');
    }

    for (final size in [const Size(1600, 947), desk, tablet, wide]) {
      tester.view.physicalSize = size;
      final g = b.state = fourTypes();
      await frames(tester, 40);
      await pick(tester, b, 'knight');
      var page = b.bookPages.$2;
      final release = b.troopDetail('release');
      final x1 = page.right.roundToDouble();
      expect(b.troopDetail('separator'), Rect.zero, reason: '$size: no separator');
      expect((release.right, release.bottom, release.height >= 24), (x1, page.bottom.roundToDouble(), true),
          reason: '$size: Release at the bottom-right, $release');
      wordsWide(release, b.troopDetail('releaseWords'), '$size Release');
      tapRule(b.troopDetail('releaseTap'), release, '$size Release');
      expect(b.troopDetailBody.bottom, lessThanOrEqualTo(b.troopDetail('releaseTap').top), reason: '$size: the body over the foot');

      // Armed: the confirm in its place, from the same right edge leftwards, as wide as its words (which name the type),
      // inside the row; a tap on the same spot sends the knight home.
      final gold = g.gold, refund = g.releaseRefundOf('knight'), spot = release.center;
      await tester.tapAt(spot);
      await frames(tester);
      final yes = b.troopDetail('confirm');
      page = b.bookPages.$2; // the book bobs: this frame's page
      expect((b.releaseArmed, b.troopDetail('release'), yes.right, yes.bottom, yes.left <= release.left, yes.contains(spot)),
          ('knight', Rect.zero, x1, page.bottom.roundToDouble(), true, true), reason: '$size: $yes');
      expect(inside(yes, page.inflate(1)), isTrue, reason: '$size: the confirm in the row');
      wordsWide(yes, b.troopDetail('confirmWords'), '$size confirm', row: x1 - page.left.roundToDouble());
      tapRule(b.releaseConfirm, yes, '$size confirm');
      expect(said(b, 'releaseConfirm'), 'Send Knight home? 1 goes home, +${shortPrice(refund)} gold', reason: '$size: it says what it does');
      await tester.tapAt(spot);
      await frames(tester);
      expect((g.troopCounts['knight'], g.gold, b.releaseArmed), (null, gold + refund, null), reason: '$size: 2 taps on one spot');

      // Replace fallen with Release (the archer's): one fallen, then seven knights (a longer price), each armed too.
      await pick(tester, b, 'archer');
      for (final fell in [1, 7]) {
        g.toReplace.clear();
        for (var i = 0; i < fell; i++) {
          g.toReplace.add((type: i == 0 ? 'soldier' : 'knight', post: cellMiddle(1 + i % 3, 1 + i)));
        }
        for (final armed in [false, true]) {
          if (armed) await tapOn(tester, b.troopDetail('release'));
          await frames(tester);
          page = b.bookPages.$2;
          final at = b.replaceButton, tap = b.troopDetail('replaceTap'), what = '$size $fell fell${armed ? ', armed' : ''}';
          final right = armed ? b.troopDetail('confirm') : b.troopDetail('release'), rightTap = armed ? b.releaseConfirm : b.troopDetail('releaseTap');
          expect((b.releaseArmed, at.left, right.right, right.bottom), (armed ? 'archer' : null, page.left.roundToDouble(), x1, page.bottom.roundToDouble()),
              reason: what);
          expect((at.overlaps(right), tap.overlaps(rightTap), at.bottom == right.bottom || at.bottom < right.top), (false, false, true),
              reason: '$what: $at beside or over $right');
          expect(b.replaceLabel, contains('($fell)'), reason: what);
          wordsWide(at, b.troopDetail('replaceWords'), what);
          tapRule(tap, at, what);
          expect(b.troopDetailBody.bottom, lessThanOrEqualTo(min(tap.top, rightTap.top)), reason: '$what: the body over the foot');
        }
        await tapOn(tester, b.troopRow('archer')); // lets it go
        expect(b.releaseArmed, isNull, reason: size.toString());
      }
      // A press on Replace fallen buys them back, as before.
      g
        ..toReplace.clear()
        ..toReplace.add((type: 'soldier', post: cellMiddle(1, 1)));
      await frames(tester, 3);
      final soldiers = g.troopCounts['soldier'] ?? 0;
      await tapOn(tester, b.replaceButton);
      expect((g.toReplace.length, g.troopCounts['soldier'], b.replaceButton), (0, soldiers + 1, Rect.zero), reason: '$size');
      b.state = Game();
      await frames(tester, 140);
    }
  });

  testWidgets('the detail fits at 915x412, 1164x777 and 1266x713 with every section on: its body '
      'between the header and the foot (at 915x412 under a two-line foot, too short for its least under the header, the '
      'header its first lines), each section reached by its scroll, in order, inside the page', (tester) async {
    final b = await boot(tester);
    const keys = ['stats', 'next', 'pusaka', 'heroes', 'relics'];
    for (final size in [wide, tablet, desk]) {
      tester.view.physicalSize = size;
      final g = b.state = bagReady()..wave = storeFrom + 1;
      g.pusaka[Relic.dragonHeart] = OwnedPusaka(type: 'archer', stars: 2);
      final a = g.troops.firstWhere((u) => u.type == 'archer')
        ..hero = true
        ..relics.addAll([Relic.fang, Relic.guard]);
      g.fallenHeroes.add(FallenHero(name: 'Kael', type: 'archer', stats: const [HeroStat.hp], fell: storeFrom));
      await frames(tester, 40);
      await pick(tester, b, 'archer');
      expect(a.alive, isTrue);
      final screen = Offset.zero & size, listRight = b.bookRows.map((r) => r.right).reduce(max);
      final head = b.troopDetail('heading'), body = b.troopDetailBody, foot = b.troopDetail('release');
      // The body under the header, at least detailBodyMin tall: with the foot one line (decisions-log 288) at every size.
      expect([head.bottom <= body.top, body.bottom <= foot.top, body.height >= detailBodyMin], everyElement(isTrue),
          reason: '$size: $head $body $foot');
      for (final key in keys) {
        expect(said(b, key), isNotEmpty, reason: '$size $key: something to say');
      }
      // Each section shown whole (or as much as the body holds) at some scroll, inside the body, in order.
      final at = await sweep(tester, b, [...keys, 'upgrade', 'change', 'recall:0']);
      for (final (i, key) in keys.indexed) {
        final top = at[key]!.top;
        expect(top, isNotNull, reason: '$size $key: reached');
        if (i > 0) expect(top!, greaterThan(at[keys[i - 1]]!.top!), reason: '$size $key under ${keys[i - 1]}');
        b.troopDetailScroll = at[key]!.scroll;
        await frames(tester);
        final r = b.troopDetail(key), view = b.troopDetailBody; // the book bobs: the body of the same frame
        expect(inside(r, view) && inside(r, b.bookPages.$2.inflate(1)) && r.left > listRight, isTrue, reason: '$size $key: $r in $view');
      }
      for (final key in ['upgrade', 'change', 'recall:0']) {
        b.troopDetailScroll = at[key]!.scroll;
        await frames(tester);
        final r = b.troopDetail(key), view = b.troopDetailBody;
        expect(r.height, greaterThanOrEqualTo(18), reason: '$size $key: big enough to tap');
        expect(inside(r, view) && inside(r, screen), isTrue, reason: '$size $key: $r in $view');
      }
      // The body scrolls only as far as its sections go; a new pick shows its top.
      b.troopDetailScroll = 1e6;
      await frames(tester);
      final most = max(0.0, b.troopDetailContent - b.troopDetailBody.height);
      expect(b.troopDetailScroll, most, reason: '$size');
      if (size == wide) expect(most, greaterThan(0), reason: '$size: taller than its room');
      await pick(tester, b, 'knight');
      expect(b.troopDetailScroll, 0, reason: '$size: a new pick from the top');
      // Every type's item icons (its stats' and the next awakening's recipe) inside the page.
      for (final type in troopTypes.keys) {
        await pick(tester, b, type);
        final page = b.bookPages.$2, view = b.troopDetailBody;
        for (final (r, _, _) in b.itemCells) {
          expect(inside(r, page.inflate(1)) && inside(r, view.inflate(1)), isTrue, reason: '$size $type: $r in $view');
        }
      }
      if (size == wide) {
        // On the shorter landscape book at 915x412 (decisions-log 283) a two-line foot (Replace fallen over the armed
        // confirm, the knight's) leaves the body too little under the header, so the header scrolls with it, its first
        // lines.
        await pick(tester, b, 'knight');
        g.toReplace.add((type: 'soldier', post: cellMiddle(1, 1)));
        await tapOn(tester, b.troopDetail('release'));
        final (yes, again) = (b.troopDetail('confirm'), b.replaceButton);
        expect((b.releaseArmed, again.bottom < yes.top), ('knight', true), reason: '$size: Replace fallen over the confirm: $again $yes');
        expect(inside(b.troopDetail('heading'), b.troopDetailBody), isTrue, reason: '$size: the header in the body');
        g.toReplace.clear();
        await tapOn(tester, b.troopRow('knight')); // lets it go
        expect((b.releaseArmed, inside(b.troopDetail('heading'), b.troopDetailBody)), (null, false), reason: '$size');
      }
      b.state = Game();
      await frames(tester, 30);
    }
  });

  testWidgets('the detail\'s body scrolls by the wheel and by a drag where it is taller than its room', (tester) async {
    final b = await boot(tester, wide); // the shortest page
    final g = b.state = bagReady()..wave = storeFrom + 1;
    g.pusaka[Relic.dragonHeart] = OwnedPusaka(type: 'archer', stars: 2);
    await frames(tester, 40);
    await pick(tester, b, 'archer');
    final body = b.troopDetailBody;
    expect(b.troopDetailContent - body.height, greaterThan(60), reason: 'room to scroll');
    final mouse = TestPointer(9, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(mouse.hover(body.center));
    await tester.sendEventToBinding(mouse.scroll(const Offset(0, 30)));
    await frames(tester);
    expect(b.troopDetailScroll, greaterThan(0), reason: 'the wheel');
    b.troopDetailScroll = 0;
    await frames(tester);
    await tester.dragFrom(body.center, const Offset(0, -40));
    await frames(tester);
    expect(b.troopDetailScroll, greaterThan(10), reason: 'a drag up scrolls down');
    expect(b.troopPicked, 'archer', reason: 'a drag picks nothing');
    await frames(tester, 30);
  });

  testWidgets('the detail rows of the tap budget: Awaken 4 / Forge 2 from another type (cell + button), 1 when picked; '
      'Recall 1 from the detail (its tag); Release 2 from the detail', (tester) async {
    final b = await boot(tester);
    for (final size in [desk, wide]) {
      tester.view.physicalSize = size;
      var g = b.state = shopper();
      await frames(tester, 40);
      await tapOn(tester, await cellOf(tester, b, Game.freeHealer)); // another type picked
      final knight = await cellOf(tester, b, 'knight');
      var taps = [0];
      await tapOn(tester, knight, taps);
      await tapOn(tester, await reveal(tester, b, 'upgrade'), taps);
      expect((taps.single, g.awakenLevel('knight')), (2, 4), reason: '$size: Awaken 4');
      await frames(tester, 140);
      taps = [0];
      await tapOn(tester, await reveal(tester, b, 'upgrade'), taps);
      expect((taps.single, g.awakenLevel('knight')), (1, 5), reason: '$size: Awaken 5, already picked');
      await frames(tester, 140);
      taps = [0];
      await tapOn(tester, await reveal(tester, b, 'upgrade'), taps);
      expect((taps.single, g.tempaOf('knight')), (1, 1), reason: '$size: Forge +1');
      await frames(tester, 140);

      // Recall: the fallen Hero's tag on the detail (2 with the Toko's Shop button first, until decisions-log 296).
      g.fallenHeroes.add(FallenHero(name: 'Kael', type: 'knight', stats: const [HeroStat.hp], fell: storeFrom));
      await frames(tester);
      taps = [0];
      final heroes = g.heroCount;
      await tapOn(tester, await reveal(tester, b, 'recall:0'), taps);
      expect((taps.single, g.heroCount, g.fallenHeroes.length), (1, heroes + 1, 0), reason: '$size: Recall');
      await frames(tester, 300); // the Hero's splash closes

      // Release: the detail's button, then its confirm.
      g = b.state = fourTypes();
      await frames(tester, 40);
      await tapOn(tester, await cellOf(tester, b, 'soldier'));
      taps = [0];
      await tapOn(tester, b.troopDetail('release'), taps);
      await tapOn(tester, b.troopDetail('releaseConfirm'), taps);
      expect((taps.single, g.troopCounts['soldier']), (2, null), reason: '$size: Release');
      await frames(tester, 30);
    }
  });
}
