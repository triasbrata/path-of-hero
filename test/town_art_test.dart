// The Town scene's art (decisions-log 222; docs/assets.md "Packs -> files"): the files tool/import_town.py writes into
// assets/images and lib/town_art.dart's names for them. Sizes, grids and rects only, so it passes on the public repo's
// placeholders too (tool/gen_placeholders.py keeps them); that every cell holds the sheet's own pixels is the tool's
// `--check`. test/fixtures/town_house_cells.json is the design's house, cell by cell, which the scene must rebuild.
// Every town_* file tool/asset_manifest.json lists is one the game names (decisions-log 294: no Town file left unused).
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/town_art.dart';
import 'package:tower_defense/town_smith_art.dart' show townSmith;

final houses = [
  for (final h in (jsonDecode(File('test/fixtures/town_house_cells.json').readAsStringSync()) as Map)['houses'] as List)
    h as Map<String, dynamic>,
];

/// [cell] lies inside a [w]x[h] image.
bool inside(TownCell cell, int w, int h) => cell.x >= 0 && cell.y >= 0 && cell.x + cell.w <= w && cell.y + cell.h <= h;

bool overlap(TownCell a, TownCell b) => a.x < b.x + b.w && b.x < a.x + a.w && a.y < b.y + b.h && b.y < a.y + a.h;

void main() {
  testWidgets('every Town image loads from the bundle at the size its names say', (tester) async {
    final sizes = <String, (int, int)>{};
    await tester.runAsync(() async {
      for (final name in townImages) {
        final data = await rootBundle.load('assets/images/$name');
        final image = (await (await ui.instantiateImageCodec(data.buffer.asUint8List())).getNextFrame()).image;
        sizes[name] = (image.width, image.height);
        image.dispose();
      }
    });
    expect(sizes.keys, townImages);
    expect(townImages.toSet().length, townImages.length);
    for (final layer in [...townLayers, townCastle]) {
      expect(sizes[layer], (townLayerW, townLayerH), reason: layer);
    }
    expect(sizes[townSmithy], (townSmithyFrames * townSmithyFrame, 2 * townSmithyFrame));
    expect((townFurnaceRow, townSawmillRow), (0, 1));
    expect(sizes[townCampfire], (townCampfireFrames * townCampfireFrame, townCampfireLoops * townCampfireFrame));
    final (hw, hh) = sizes[townHouse]!;
    final (pw, ph) = sizes[townProps]!;
    for (final MapEntry(key: name, value: cell) in townHouseCells.entries) {
      expect(inside(cell, hw, hh), isTrue, reason: '$name $cell is outside $townHouse ($hw x $hh)');
    }
    for (final MapEntry(key: name, value: cell) in townPropCells.entries) {
      expect(inside(cell, pw, ph), isTrue, reason: '$name $cell is outside $townProps ($pw x $ph)');
    }
  });

  test('every town_* file the manifest lists is one the game names: the scene\'s, the smith\'s or the Towns\' two icons', () {
    final manifest = jsonDecode(File('tool/asset_manifest.json').readAsStringSync()) as Map<String, dynamic>;
    final listed = {
      for (final f in manifest['files'] as List)
        if ((f['path'] as String).startsWith('assets/images/town_')) (f['path'] as String).substring('assets/images/'.length),
    };
    expect(listed, {...townImages, townSmith, 'town_mark.png', 'town_mug.png'});
  });

  test('the house cells sit each on a 16 px slot of the atlas, the porch\'s 16x8; the props never overlap', () {
    expect(townHouseCells.length, 64);
    final slots = <(int, int)>{};
    for (final MapEntry(key: name, value: c) in townHouseCells.entries) {
      expect((c.x % 16, c.y % 16, c.w), (0, 0, 16), reason: name);
      expect(c.h, ['baseL', 'porchL', 'porch', 'baseRa', 'baseRb'].contains(name) ? 8 : 16, reason: name);
      expect(slots.add((c.x, c.y)), isTrue, reason: '$name shares its slot');
    }
    final props = townPropCells.entries.toList();
    for (final (i, a) in props.indexed) {
      expect(a.value.w > 0 && a.value.h > 0, isTrue, reason: a.key);
      for (final b in props.skip(i + 1)) {
        expect(overlap(a.value, b.value), isFalse, reason: '${a.key} and ${b.key} overlap');
      }
    }
  });

  test('the design\'s houses use every house cell by its name, and each cell and prop of them lies inside the house', () {
    expect([for (final h in houses) (h['n'], h['storeys'])], [(0, 1), (0, 2), (1, 2)]);
    final used = <String>{};
    for (final h in houses) {
      final [w, ht] = [for (final v in h['size'] as List) v as int];
      final tag = 'n ${h['n']}, ${h['storeys']} storeys';
      expect(w, (14 + 2 * (h['n'] as int)) * 16, reason: tag);
      for (final [name as String, col as int, row as int] in h['cells'] as List) {
        final cell = townHouseCells[name];
        expect(cell, isNotNull, reason: '$tag: $name is not in townHouseCells');
        expect(col * 16 + cell!.w <= w && row * 16 + cell.h <= ht, isTrue, reason: '$tag: $name at ($col, $row)');
        used.add(name);
      }
      for (final [name as String, x as int, bottom as int] in h['props'] as List) {
        final prop = townPropCells[name];
        expect(prop, isNotNull, reason: '$tag: the prop $name is not in townPropCells');
        expect(x >= 0 && x + prop!.w <= w && bottom - prop.h >= 0 && bottom <= ht, isTrue, reason: '$tag: $name');
      }
    }
    expect(used, townHouseCells.keys.toSet());
  });
}
