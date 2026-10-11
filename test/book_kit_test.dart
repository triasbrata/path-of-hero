// The book's sprite kit (decisions-log 187; docs/ui-hud.md "Sprite kit"): ui_all.png's slots in their three looks, each
// 9-sliced exactly; a Pusaka's cell, the tan slot with its rarity's rim and lip and its face and outline kept (the
// affine four-colour recolour); ui_bars.png's capsule as the book's badge (the Tas heading's, a Pusaka's; the field's
// Toko, whose goods had it too, went in decisions-log 296) and, turned upright, as the lists' scroll bar. One TdGame per widget test. The tests that read the art's
// own pixels are tagged `art` (testing.md "Placeholder art").
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flame/game.dart' hide Game;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';
import 'package:tower_defense/main.dart';

import 'hud_font.dart';

Future<void> frames(WidgetTester tester, [int n = 2]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

Future<void> tapOn(WidgetTester tester, Offset p) async {
  await tester.tapAt(p);
  await frames(tester);
}

/// Boots one TdGame in a [size] window, past the welcome screen, with the game's font and the minimap folded.
Future<TdGame> boot(WidgetTester tester, [Size size = const Size(1266, 713)]) async {
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
  game.board
    ..welcome = null
    ..miniMapOpen = false;
  return game;
}

/// The owner's wave-89 save (six Pusaka: two in the Gudang, three bound, an oath), between waves, the chests put away.
Game w89() => Game.fromJson(jsonDecode(File('test/fixtures/save-20261002-2222-w89-sellbug.json').readAsStringSync()) as Map<String, dynamic>)
    .boardRules()
  ..towns = false // the Towns off (tests only, decisions-log 296: the rules from before them; the book is the Towns' still)
  ..chests.clear();

/// [image]'s pixels as 0xAARRGGBB, its colours not premultiplied.
Future<int Function(int, int)> pixelsOf(WidgetTester tester, ui.Image image) async {
  final px = (await tester.runAsync(() => image.toByteData(format: ui.ImageByteFormat.rawStraightRgba)))!;
  return (x, y) {
    final i = (y * image.width + x) * 4;
    return px.getUint8(i + 3) << 24 | px.getUint8(i) << 16 | px.getUint8(i + 1) << 8 | px.getUint8(i + 2);
  };
}

/// What [draw] puts on a fresh [w]x[h] canvas.
Future<int Function(int, int)> drawn(WidgetTester tester, int w, int h, void Function(Canvas) draw) async {
  final rec = ui.PictureRecorder();
  draw(Canvas(rec));
  final image = (await tester.runAsync(() => rec.endRecording().toImage(w, h)))!;
  return pixelsOf(tester, image);
}

/// Colour [a] within [d] of [b] in each of red, green and blue, both opaque; or both clear.
bool near(int a, int b, [int d = 3]) =>
    (a >> 24 == 0 && b >> 24 == 0) || (a >> 24 == 0xFF && b >> 24 == 0xFF && [16, 8, 0].every((s) => ((a >> s & 0xFF) - (b >> s & 0xFF)).abs() <= d));

String hex(int c) => '0x${c.toRadixString(16).padLeft(8, '0')}';

/// The slot's four colours (chest_popup.dart's), and each Pusaka rarity's rim and dark (the chest cards' frames').
const outline = 0xFF3F2832, rim = 0xFFEAD4AA, face = 0xFFE4A672, lip = 0xFFB86F50;
const rarityRims = {Rarity.langka: (0xFF8CC878, 0xFF4E8C46), Rarity.epik: (0xFFB98CF0, 0xFF7E50C8), Rarity.legenda: (0xFFF2C23C, 0xFFC8821E)};

const looks = [ButtonLook.normal, ButtonLook.hover, ButtonLook.pressed];

void main() {
  test('a pressed slot ends on the normal one\'s bottom row, 3 sprite px lower at the top; the other looks fill their rect',
      () {
    const r = Rect.fromLTWH(10, 20, 44, 50);
    for (final k in [1.0, 2.0, 3.0]) {
      expect(slotRect(r, ButtonLook.pressed, k), Rect.fromLTRB(10, 20 + 3 * k, 54, 70));
      for (final look in [ButtonLook.normal, ButtonLook.hover, ButtonLook.disabled]) {
        expect(slotRect(r, look, k), r);
      }
    }
    // Each colour 48 px below the last; the looks 192 px apart; the pressed one 3 rows shorter.
    for (var row = 0; row < slotRows; row++) {
      expect(slotSrc(row, ButtonLook.normal), Rect.fromLTWH(10, 10 + 48.0 * row, 28, 31));
      expect(slotSrc(row, ButtonLook.disabled), slotSrc(row, ButtonLook.normal));
      expect(slotSrc(row, ButtonLook.hover), Rect.fromLTWH(202, 10 + 48.0 * row, 28, 31));
      expect(slotSrc(row, ButtonLook.pressed), Rect.fromLTWH(394, 10 + 48.0 * row, 28, 28));
    }
    expect([slotTan, slotWhite, slotGreen, slotBlue, slotOrange, slotRed, slotPurple], [0, 1, 2, 3, 4, 5, 6]);
  });

  test('the four-colour recolour takes each colour to its pair exactly, keeps alpha, and refuses four on one plane', () {
    for (final MapEntry(key: rarity, value: (toRim, toDark)) in rarityRims.entries) {
      final pairs = [(outline, outline), (face, face), (rim, toRim), (lip, toDark)];
      final m = recolourMatrix([for (final (a, b) in pairs) (Color(a), Color(b))]);
      expect(m, hasLength(20));
      expect(m.sublist(15), [0, 0, 0, 1, 0], reason: '$rarity: alpha untouched');
      for (final (from, to) in pairs) {
        final rgb = [from >> 16 & 0xFF, from >> 8 & 0xFF, from & 0xFF];
        for (var ch = 0; ch < 3; ch++) {
          // ColorFilter.matrix's sum: channels 0-255, the offset column in 0-255.
          final out = m[ch * 5] * rgb[0] + m[ch * 5 + 1] * rgb[1] + m[ch * 5 + 2] * rgb[2] + m[ch * 5 + 3] * 255 + m[ch * 5 + 4];
          expect(out, closeTo((to >> (16 - 8 * ch) & 0xFF).toDouble(), 0.01), reason: '$rarity ${hex(from)} channel $ch');
        }
      }
    }
    // Black, white and two greys lie on one line: no affine map is set by them.
    final greys = [for (final v in [0x000000, 0x404040, 0x808080, 0xFFFFFF]) (Color(0xFF000000 | v), const Color(0xFF00FF00))];
    expect(() => recolourMatrix(greys), throwsArgumentError);
  });

  test("a badge holds its label: as tall as the text's line plus its outline, the label padded inside, an icon square",
      () {
    for (final fs in [10.0, 11.0, 12.0, 13.6, 16.0]) {
      final plain = capsuleSize(20, fs), withIcon = capsuleSize(20, fs, icon: true), k = capsuleK(plain.height);
      expect(plain.height, (fs * 1.3).roundToDouble(), reason: '$fs');
      expect(k, 1, reason: '$fs: a one-pixel outline beside the book text');
      // The font draws at 0.8 × the size, its glyphs 9 of 11 font pixels tall (cap height and descender): inside the
      // outline with a pixel to spare.
      expect(plain.height - 2 * k, greaterThanOrEqualTo(fs * 0.8 * 9 / 11 + 2), reason: '$fs');
      expect(plain.width, greaterThanOrEqualTo(20 + 2 * (k + 2)), reason: '$fs: at least 2 px each side inside the outline');
      expect(plain.width, plain.width.roundToDouble(), reason: '$fs: whole pixels');
      expect(withIcon.width - plain.width, closeTo(plain.height - 2 * k + capsuleGap(fs), 1), reason: '$fs: the icon is a square');
    }
  });

  test('a slot badge shows a count short: up to 999 as is, then 1.2k (cut), 12k, 123k', () {
    expect([for (final n in [2, 86, 999, 1000, 1234, 1299, 9999, 10000, 12500, 123456]) shortCount(n)],
        ['2', '86', '999', '1.0k', '1.2k', '1.2k', '9.9k', '10k', '12k', '123k']);
  });

  testWidgets('every slot look of every colour is 9-sliced exactly; a Pusaka cell is the tan slot in its rarity, its face and '
      'outline kept', (tester) async {
    final game = await boot(tester);
    final b = game.board;
    final sheet = game.images.fromCache('ui_all.png');
    final at = await pixelsOf(tester, sheet);

    // Every row of a slot's stretched middle is one colour across, every column one colour down, and the insets are the
    // least that do it: a slot stretched to any size keeps its pixel art.
    for (var row = 0; row < slotRows; row++) {
      for (final look in looks) {
        final src = slotSrc(row, look), x0 = src.left.toInt(), y0 = src.top.toInt(), w = src.width.toInt(), h = src.height.toInt();
        final why = 'colour $row $look';
        expect(at(x0, y0) >> 24, 0, reason: '$why: its corner is cut');
        expect(at(x0 + 14, y0), outline, reason: '$why: its top is the outline');
        expect(at(x0 + 14, y0 + h - 1), outline, reason: '$why: its bottom is the outline');
        expect(at(x0 + 14, y0 + h) >> 24, 0, reason: '$why: nothing under it');
        bool across(int l, int r) {
          for (var y = 0; y < h; y++) {
            if ({for (var x = l; x < w - r; x++) at(x0 + x, y0 + y)}.length > 1) return false;
          }
          return true;
        }

        bool down(int t, int b) {
          for (var x = 0; x < w; x++) {
            if ({for (var y = t; y < h - b; y++) at(x0 + x, y0 + y)}.length > 1) return false;
          }
          return true;
        }

        final i = slotInsets(look);
        final (l, t, r, bb) = (i.l.toInt(), i.t.toInt(), i.r.toInt(), i.b.toInt());
        expect((across(l, r), down(t, bb)), (true, true), reason: '$why: exact');
        expect((across(l - 1, r), across(l, r - 1), down(t - 1, bb), down(t, bb - 1)), (false, false, false, false),
            reason: '$why: the least insets');
      }
    }

    // The tan slot's four colours, where the recolour expects them.
    final tan = slotSrc(slotTan, ButtonLook.normal), tx = tan.left.toInt(), ty = tan.top.toInt();
    expect([at(tx + 3, ty), at(tx + 3, ty + 1), at(tx + 14, ty + 14), at(tx + 14, ty + 28)], [outline, rim, face, lip]);

    // Drawn at its own size (k = 1), each look of a Pusaka's cell is the tan slot pixel for pixel, its rim and lip in the
    // rarity's colours; with no rarity, the tan slot itself. Pressed, it sits 3 px lower.
    for (final rarity in <Rarity?>[null, ...rarityRims.keys]) {
      final (toRim, toDark) = rarityRims[rarity] ?? (rim, lip);
      for (final look in looks) {
        final px = await drawn(tester, 28, 31, (c) => b.drawSlot(c, const Rect.fromLTWH(0, 0, 28, 31), slotTan, look, 1, rarity: rarity));
        final src = slotSrc(slotTan, look), drop = look == ButtonLook.pressed ? 3 : 0;
        for (var y = 0; y < 31; y++) {
          for (var x = 0; x < 28; x++) {
            final sy = y - drop, from = sy < 0 || sy >= src.height ? 0 : at(src.left.toInt() + x, src.top.toInt() + sy);
            final want = switch (from) { rim => toRim, lip => toDark, _ => from };
            expect(near(px(x, y), want), isTrue, reason: '${rarity?.name ?? 'tan'} $look ($x, $y): ${hex(px(x, y))}, not ${hex(want)}');
          }
        }
      }
    }

    // At k = 2 the corners are the sprite's own pixels doubled; the stretched middle is one colour each way.
    final epik = rarityRims[Rarity.epik]!;
    final px = await drawn(tester, 88, 100, (c) => b.drawSlot(c, const Rect.fromLTWH(0, 0, 88, 100), slotTan, ButtonLook.normal, 2, rarity: Rarity.epik));
    for (var y = 0; y < 6; y++) {
      for (var x = 0; x < 6; x++) {
        final from = at(tx + x ~/ 2, ty + y ~/ 2), want = switch (from) { rim => epik.$1, lip => epik.$2, _ => from };
        expect(near(px(x, y), want), isTrue, reason: 'epik k2 corner ($x, $y)');
      }
    }
    expect([px(44, 1), px(44, 3), px(44, 50), px(44, 94), px(44, 99)].map(hex).toList(),
        [outline, epik.$1, face, epik.$2, outline].map(hex).toList(), reason: 'epik k2 down the middle');
    await frames(tester, 5);
  }, tags: 'art');

  testWidgets("the badges are the capsule, inside their slot or row with 10 px text; the lists' scroll bar is the turned capsule "
      'down their right, clear of the rows', (tester) async {
    final game = await boot(tester);
    final b = game.board;
    // 1164x777: at 915x412 the widest count's badge ("x9.9k") is as wide as its slot and pokes a pixel out of it
    // (decisions-log 289).
    for (final size in const [Size(1266, 713), Size(1164, 777)]) {
      tester.view.physicalSize = size;
      final g = b.state = w89()
        ..offers = false // no boss chest's offers, as this test always played
        ..inventory[Item.potion] = 9999; // the widest count, "x9.9k"
      await frames(tester, 50);
      final why = '${size.width.toInt()}x${size.height.toInt()}';

      // The Tas page: an item's heading count, a Pusaka's stars and the rows' Pusaka badges, the list's scroll bar.
      await tapOn(tester, b.bookTabs.firstWhere((t) => t.$1 == 'bag').$2.center);
      expect(b.bagOpen, isTrue, reason: why);
      await tapOn(tester, b.bagSlot(Relic.godThunder).center);
      expect(b.picked, Relic.godThunder, reason: why);
      await tapOn(tester, b.bagAction(BagAction.types).center); // its type rows (decisions-log 202)
      await frames(tester, 4);
      final list = b.assignList, rows = b.assignRows;
      expect(rows, isNotEmpty, reason: why);
      final bars = b.scrollBars, overflow = rows.length < troopTypes.length || rows.last.$2.bottom >= list.bottom - 0.5;
      expect(bars, hasLength(overflow ? 1 : 0), reason: '$why: a bar while the rows overflow the list');
      if (overflow) {
        final bar = bars.single;
        expect((bar.width, bar.top, bar.height), (6, list.top.roundToDouble(), list.height.roundToDouble()), reason: '$why: $bar by $list');
        expect((bar.right - list.right).abs(), lessThanOrEqualTo(1), reason: '$why: down the list\'s right');
        for (final (who, r, _) in rows) {
          expect(r.right, lessThanOrEqualTo(bar.left), reason: '$why: $who\'s row clear of the bar');
        }
      }

      // The Army page: each bound type's Pusaka mark inside its row: the capsule (10-px text) on a desk's wide row, the
      // 12-px icon on the sprite of a narrow one's.
      await tapOn(tester, b.bookTabs.firstWhere((t) => t.$1 == 'troops').$2.center);
      for (final type in [for (final t in troopTypes.keys) if (g.pusakaOf(t) != null) t]) {
        final row = b.troopRow(type), badge = b.pusakaBadge(type);
        if (row == Rect.zero) continue;
        expect(badge, isNot(Rect.zero), reason: '$why $type');
        expect(row.inflate(0.5).contains(badge.topLeft) && row.inflate(0.5).contains(badge.bottomRight), isTrue,
            reason: '$why $type: its badge $badge in its row $row');
        expect(badge.height, greaterThanOrEqualTo(row.width >= 220 ? 13 : 12), reason: '$why $type');
      }

      // The Licences page's lists scroll with the same bar.
      await tapOn(tester, b.bookTabs.firstWhere((t) => t.$1 == 'settings').$2.center);
      await tapOn(tester, b.licenceButton.center);
      await frames(tester, 4);
      expect(b.scrollBars, isNotEmpty, reason: '$why: the licences overflow their lists');
      expect(b.scrollBars.every((bar) => bar.width == 6), isTrue, reason: why);
      await tapOn(tester, b.licenceBack.center);
      b.state = Game(Random(1));
      await frames(tester, 5);
    }
  });
}
