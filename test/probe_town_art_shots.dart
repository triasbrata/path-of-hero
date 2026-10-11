// The Town scene's art drawn from the atlases by lib/town_art.dart's names (decisions-log 222), to look at beside the
// design's mockups: offscreen shots into <probe root>/shots/town-T5/ (`OUT`). A probe, not part of the suite (no
// `_test.dart`): queue `["test", "test/probe_town_art_shots.dart"]` with the worktree as `dir`.
//
// - houses.png: the design's three houses (test/fixtures/town_house_cells.json: n 0 one storey, n 0 two storeys, n 1
//   two storeys) rebuilt cell by cell from town_house.png at k 2, their props from town_props.png, on the design's
//   sky blue: the bottom row of its house-tiles picture.
// - frames.png: the smithy's 12 frames (row 0 the furnace, row 1 the sawmill) and the campfire's first loop, at k 2.
// - props.png: every prop of town_props.png by its name, then the tent, the ore rock and the pine, at k 2.
// - scene-1266x713.png: a rough desk composite at k 2 (the layers, the castle, the street, the Smithy, the
//   house, the campfire, the Shop), placed by eye after the design's town-1266x713 mockup: a look at the pieces
//   together, not the scene's layout.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/hud_font.dart';
import 'package:tower_defense/town_art.dart';

import 'hud_font.dart';
import 'probe_root.dart';

const out = String.fromEnvironment('OUT', defaultValue: '$probeRoot/shots/town-T5');
const k = 2.0;
const sky = Color(0xFF8FB6CF), paper = Color(0xFFE9DCC8), ink = Color(0xFF3C2A1E);

final images = <String, ui.Image>{};
final pixel = Paint()
  ..filterQuality = FilterQuality.none
  ..isAntiAlias = false;

/// [cell] of [file] with its top left at [at], [scale] screen px a sprite px.
void cell(Canvas c, String file, TownCell cell, Offset at, [double scale = k]) => c.drawImageRect(
    images[file]!,
    Rect.fromLTWH(cell.x.toDouble(), cell.y.toDouble(), cell.w.toDouble(), cell.h.toDouble()),
    Rect.fromLTWH(at.dx, at.dy, cell.w * scale, cell.h * scale),
    pixel);

/// The whole of [file] (or its frame [col], [row] of [frame] px) with its top left at [at].
void whole(Canvas c, String file, Offset at, {int? frame, int col = 0, int row = 0}) {
  final img = images[file]!;
  final (w, h) = frame == null ? (img.width, img.height) : (frame, frame);
  cell(c, file, (x: col * w, y: row * h, w: w, h: h), at);
}

void label(Canvas c, String text, Offset at, [double size = 14]) => (TextPainter(
      text: TextSpan(text: text, style: hudStyle(size, color: ink)),
      textDirection: TextDirection.ltr,
    )..layout())
        .paint(c, at);

final houses = [
  for (final h in (jsonDecode(File('test/fixtures/town_house_cells.json').readAsStringSync()) as Map)['houses'] as List)
    h as Map<String, dynamic>,
];

/// The fixture's house [h] cell by cell with its grid's top left at [at], and its props.
void house(Canvas c, Map<String, dynamic> h, Offset at) {
  for (final [name as String, col as int, row as int] in h['cells'] as List) {
    cell(c, townHouse, townHouseCells[name]!, at + Offset(col * 16 * k, row * 16 * k));
  }
  for (final [name as String, x as int, bottom as int] in h['props'] as List) {
    final p = townPropCells[name]!;
    cell(c, townProps, p, at + Offset(x * k, (bottom - p.h) * k));
  }
}

Future<void> save(String name, int w, int h, void Function(Canvas c) draw) async {
  final rec = ui.PictureRecorder();
  draw(Canvas(rec));
  final img = await rec.endRecording().toImage(w, h);
  final png = await img.toByteData(format: ui.ImageByteFormat.png);
  File('$out/$name.png')
    ..parent.createSync(recursive: true)
    ..writeAsBytesSync(png!.buffer.asUint8List());
  // ignore: avoid_print
  print('wrote $out/$name.png ${w}x$h');
}

void main() {
  testWidgets('town art shots', (tester) async {
    await loadHudFont(tester);
    await tester.runAsync(() async {
      for (final name in townImages) {
        final data = await rootBundle.load('assets/images/$name');
        images[name] = (await (await ui.instantiateImageCodec(data.buffer.asUint8List())).getNextFrame()).image;
      }

      // The three houses, as the design's house-tiles picture's bottom row.
      await save('houses', 1500, 520, (c) {
        c.drawRect(const Rect.fromLTWH(0, 0, 1500, 520), Paint()..color = paper);
        var x = 16.0;
        for (final h in houses) {
          final [w, ht] = [for (final v in h['size'] as List) (v as int) * k];
          label(c, 'n ${h['n']}, ${h['storeys']} storey${h['storeys'] == 1 ? '' : 's'} (${w ~/ k}x${ht ~/ k})',
              Offset(x, 10));
          c.drawRect(Rect.fromLTWH(x, 40, w, ht + 4), Paint()..color = sky);
          house(c, h, Offset(x, 42));
          x += w + 24;
        }
      });

      // The smithy's frames and the campfire's first loop.
      await save('frames', 6 * 64 * 2 + 32, 2 * 64 * 2 + 32 * 2 + 3 * 28 + 16, (c) {
        c.drawRect(const Rect.fromLTWH(0, 0, 2000, 2000), Paint()..color = paper);
        label(c, 'town_smithy.png: row 0 the furnace, row 1 the sawmill, frames 0-5', const Offset(16, 6));
        for (final row in [townFurnaceRow, townSawmillRow]) {
          for (var f = 0; f < townSmithyFrames; f++) {
            final at = Offset(16 + f * 64 * k, 30 + row * 64 * k);
            c.drawRect(at & const Size(64 * k - 2, 64 * k - 2), Paint()..color = sky);
            whole(c, townSmithy, at, frame: townSmithyFrame, col: f, row: row);
          }
        }
        final y = 30 + 2 * 64 * k + 8;
        label(c, 'town_campfire.png: loop 0, frames 0-4', Offset(16, y));
        for (var f = 0; f < townCampfireFrames; f++) {
          final at = Offset(16 + f * 40 * k, y + 24);
          c.drawRect(at & const Size(32 * k, 32 * k), Paint()..color = sky);
          whole(c, townCampfire, at, frame: townCampfireFrame, col: f);
        }
      });

      // Every prop by its name, then the single pieces.
      await save('props', 1300, 560, (c) {
        c.drawRect(const Rect.fromLTWH(0, 0, 1300, 560), Paint()..color = paper);
        var (x, y, rowH) = (16.0, 10.0, 0.0);
        void put(String name, String file, TownCell p) {
          final w = p.w * k, h = p.h * k;
          if (x + w > 1284) (x, y, rowH) = (16.0, y + rowH + 34, 0.0);
          label(c, name, Offset(x, y));
          c.drawRect(Rect.fromLTWH(x, y + 22, w, h), Paint()..color = sky);
          cell(c, file, p, Offset(x, y + 22));
          x += (w > 90 ? w : 90) + 16;
          if (h > rowH) rowH = h;
        }

        for (final MapEntry(key: name, value: p) in townPropCells.entries) {
          put(name, townProps, p);
        }
        for (final file in [townTent, townOre, townPine]) {
          final img = images[file]!;
          put(file, file, (x: 0, y: 0, w: img.width, h: img.height));
        }
      });

      // A rough desk composite (633 world px wide at k 2), the street at world y 262 lying ~85% down.
      await save('scene-1266x713', 1266, 713, (c) {
        const street = 262, top = 606 - street * k;
        Offset at(num x, num bottom, num h) => Offset(x * k, top + (bottom - h) * k);
        // Above the layers, the sky's own top row stretched up.
        c.drawImageRect(images[townLayers[4]]!, const Rect.fromLTWH(0, 0, townLayerW + 0.0, 1),
            Rect.fromLTWH(0, 0, 1266, top + 1), pixel);
        for (final layer in [townLayers[4], townLayers[3], townCastle, townLayers[2], townLayers[1], townLayers[0]]) {
          whole(c, layer, const Offset(0, top));
        }
        for (var x = 0; x < 633; x += townGroundW) {
          whole(c, townGroundTile, at(x, street + townGroundH, townGroundH));
        }
        cell(c, townProps, townPropCells['logPile']!, at(6, street, 21));
        whole(c, townSmithy, at(36, street, 64), frame: townSmithyFrame, row: townSawmillRow);
        whole(c, townSmithy, at(96, street, 64), frame: townSmithyFrame, row: townFurnaceRow);
        cell(c, townProps, townPropCells['stumpAxe']!, at(134, street, 21));
        whole(c, townOre, at(146, street, 38));
        whole(c, townPine, at(212, street, 128));
        cell(c, townProps, townPropCells['clothesLine']!, at(184, street, 62));
        final n1 = houses.last, hh = (n1['size'] as List)[1] as int;
        house(c, n1, at(282, street, hh));
        whole(c, townCampfire, at(430, street, 32), frame: townCampfireFrame);
        cell(c, townProps, townPropCells['crates2']!, at(498, street, 32));
        whole(c, townTent, at(522, street, 121));
        cell(c, townProps, townPropCells['basket']!, at(526, street, 15));
        cell(c, townProps, townPropCells['fruitTable']!, at(548, street, 30));
        cell(c, townProps, townPropCells['barrels']!, at(598, street, 18));
      });
    });
  });
}
