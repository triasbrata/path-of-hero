// The Towns' identities on screen (decisions-log 326; ui-hud.md "Town"; lib/town_scene.dart, lib/town_look.dart): a
// booted TdGame gone into each identity's first Town (1 Millbrook, 2 Willowmere, 4 Ironvale, 5 Ambergate, 7 Frostgate,
// 8 Highspire): its season's parallax layers, castle and street drawn and no other season's; its own yard's pieces
// on the street, no other identity's; its name on the ribbon under the HUD's band as it comes up, gone after 3 s; the
// wave meter "In <name>".
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';
import 'package:tower_defense/main.dart';

import 'town_hud_test.dart' show boot, frames, townGame;

/// A canvas that notes each image drawn; every other call does nothing.
class _Drawn implements Canvas {
  final images = <ui.Image>[];

  @override
  void drawImageRect(ui.Image image, Rect src, Rect dst, Paint paint) => images.add(image);

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// Each identity's yard, by its pieces' names in the scene (town_scene.dart's `_townYards`).
const yards = {
  'millbrook': ['flowerTree', 'wheat', 'wheat2', 'sack', 'sheaf'],
  'willowmere': ['willow', 'boat', 'potGreen', 'potOlive', 'potSmall'],
  'ironvale': ['birch', 'oreGold', 'torch'],
  'ambergate': ['smallTent', 'flowerTable', 'sunflowers', 'grapeBowl'],
  'frostgate': ['cypress', 'urnFern', 'angel', 'urnRed', 'torch'],
  'highspire': ['torch', 'bust', 'alchemyTable', 'urn', 'gardenTree'],
};

void main() {
  for (final n in const [1, 2, 4, 5, 7, 8]) {
    final who = identityOf(n);
    testWidgets('Town $n, ${who.name}: its ${who.season.name} backdrop and street, its yard, its name as it comes up '
        'and on the meter', (tester) async {
      final b = await boot(tester, const Size(1600, 947));
      b.autoStart.set(false);
      final g = b.state = townGame()
        ..wave = 5
        ..townAt = 7
        ..townCount = n - 1;
      g
        ..startWave()
        ..queue.clear()
        ..units.add(g.monster('slime', Tier.normal, const Point(300, 60))..gone = true);
      for (var i = 0; i < 600 && !g.inTown; i++) {
        await frames(tester, 1);
      }
      expect((g.inTown, g.townCount, g.sceneIdentity.key), (true, n, who.key));
      for (var i = 0; i < 200 && !(b.townShown && b.townFade == 0); i++) {
        await frames(tester, 1); // the fade: the field dims, then the Town comes up
      }
      await frames(tester, 20);

      // Its season's art, none of the others'.
      final drawn = _Drawn();
      b.render(drawn);
      final images = b.game.images, art = townSeasonArt[who.season]!;
      bool shown(String file) => drawn.images.contains(images.fromCache(file));
      for (final file in [...art.layers, art.castle, art.ground]) {
        expect(shown(file), isTrue, reason: '${who.key}: $file');
      }
      for (final other in townSeasonArt.entries.where((e) => e.key != who.season)) {
        for (final file in [...other.value.layers, other.value.castle, other.value.ground]) {
          expect(shown(file), isFalse, reason: '${who.key}: not $file');
        }
      }
      // Its yard on the street (where the view shows it), no other identity's; the yard's span its pieces'.
      final scene = b.townScene, mine = yards[who.key]!;
      final others = {for (final y in yards.values) ...y}.difference(mine.toSet());
      expect(scene.keys.where(others.contains), isEmpty, reason: '${who.key}: ${scene.keys}');
      final seen = mine.where(scene.containsKey).toList();
      expect(seen, isNotEmpty, reason: '${who.key}: its yard in view');
      for (final name in seen) {
        expect(scene[name]!.bottom, b.townLane, reason: '$name on the street');
      }
      // Its name: the ribbon under the HUD's band, the meter's words.
      final ribbon = b.townArrival;
      expect(ribbon, isNot(Rect.zero), reason: 'the ribbon as the Town comes up');
      expect(ribbon.top, greaterThanOrEqualTo(b.waveMeter.bottom), reason: "under the HUD's band");
      expect(b.townMeterText, startsWith('In ${who.name}'));
      await frames(tester, 200); // 3.2 s more: past its 3 s
      expect(b.townArrival, Rect.zero, reason: 'gone after 3 s');
    });
  }
}
