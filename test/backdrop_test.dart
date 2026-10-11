// The battle's backdrop (decisions-log 228, 244, 263; docs/camera-and-field.md "Backdrop"): GandalfHardcore's Normal BG
// layers in the band above the field, far to near, the clouds drifting over the sky, the props line at the horizon and
// the floor (battle_floor.png, battle_props.png, battle_clouds.png: tool/import_battle_floor.py) over the field, its
// front edge under the field's bottom, under the spawn bar's step (decisions-log 287), under the lowest a unit stands, each tiling over the whole view at every
// screen, camera and clock, all of them under everything on the field. The layout
// and the drawing order are sizes only, so they pass on the public repo's placeholders; the map of the pictures they
// rest on (where layer 1's pines end on its ground, where the floor turns opaque, the props' and clouds' rows, the
// meadow and the front edge) needs the real art.
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flame/game.dart' hide Game;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';
import 'package:tower_defense/main.dart';
import 'package:tower_defense/town_art.dart';

/// The view's width in world units on a [w]x[h] screen (Board's scale: the band and the field take the screen's
/// height).
double viewOf(double w, double h) => w / (h / (backdropH + fieldH));

/// The desk, the owner's tablet, the letterbox's (a view taller than wide, decisions-log 289), a large and an
/// ultra-wide desk, a phone.
const sizes = [(1266.0, 713.0), (1164.0, 777.0), (915.0, 610.0), (2560.0, 1440.0), (3440.0, 1440.0), (915.0, 412.0)];

/// A new game's, a view glided left of it, mid-field, the owner's wave-89 save's back line, and further still.
const cams = [0.0, -37.3, 123.4, 242976.0, 1e6 + 0.7];

/// The clouds' clock: a new game's, a minute and a half in, an evening's play, and far on.
const clocks = [0.0, 93.25, 4 * 3600.0, 1e7 + 0.3];

/// An image of the bundle and its RGBA bytes.
Future<(ui.Image, ByteData)> pixels(String name) async {
  final data = await rootBundle.load('assets/images/$name');
  final image = (await (await ui.instantiateImageCodec(data.buffer.asUint8List())).getNextFrame()).image;
  return (image, (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!);
}

/// [copies] cover a view [viewW] wide from its left edge to past its right one, side by side, each overlapping the
/// next, a repeat apart, none stretched from a [w]x[h] px picture.
void covers(List<Rect> copies, double viewW, int w, int h, String why) {
  expect(copies.first.left, lessThanOrEqualTo(0), reason: why);
  expect(copies.last.right, greaterThan(viewW), reason: '$why: a gap at the far right');
  for (var i = 1; i < copies.length; i++) {
    expect(copies[i].left, lessThan(copies[i - 1].right), reason: '$why: a seam before copy $i');
    expect(copies[i].left - copies[i - 1].left, closeTo(copies[0].width - 0.5, 1e-6), reason: why);
    expect(copies[i].top, copies[0].top, reason: why);
  }
  for (final to in copies) {
    expect((to.width - 0.5) / to.height, closeTo(w / h, 1e-9), reason: '$why: not stretched');
  }
}

/// How far [copies] at [b] moved left from [a] (modulo a repeat).
double moved(List<Rect> a, List<Rect> b) => (a.first.left - b.first.left) % (a.first.width - 0.5);

/// A canvas that only notes the images drawn on it, in order; every other call does nothing.
class _Drawn implements Canvas {
  final images = <ui.Image>[];

  @override
  void drawImageRect(ui.Image image, Rect src, Rect dst, Paint paint) => images.add(image);

  @override
  void drawImage(ui.Image image, Offset offset, Paint paint) => images.add(image);

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  test('the layers go far to near: the sky, the mountains, the far, middle and near pines', () {
    expect([for (final l in backdropLayers(0, 300)) l.image], townLayers.reversed.toList());
    expect(townLayers, ['town_bg_1.png', 'town_bg_2.png', 'town_bg_3.png', 'town_bg_4.png', 'town_bg_5.png']);
  });

  test('each layer, the clouds, the props line and the floor cover the whole view at every size, camera and clock', () {
    for (final (w, h) in sizes) {
      final viewW = viewOf(w, h);
      for (final cam in cams) {
        final at = 'at ${w.round()}x${h.round()}, cam $cam (the view $viewW wide)';
        for (final (:image, :copies) in backdropLayers(cam, viewW)) {
          covers(copies, viewW, townLayerW, townLayerH, '$image $at');
        }
        covers(propsCopies(cam, viewW), viewW, battlePropsW, battlePropsH, 'the props $at');
        covers(floorCopies(cam, viewW), viewW, battleFloorW, battleFloorH, 'the floor $at');
        for (final clock in clocks) {
          covers(cloudCopies(cam, viewW, clock), viewW, battleCloudsW, battleCloudsH, 'the clouds $at, clock $clock');
        }
      }
    }
  });

  test('top to bottom: the sky, the layers round the horizon, the props line standing on it, the floor to the bottom',
      () {
    final layers = backdropLayers(0, 400), sky = layers.first.copies.first, near = layers.last.copies.first;
    final props = propsCopies(0, 400).first, clouds = cloudCopies(0, 400, 0).first, floor = floorCopies(0, 400).first;
    final px = near.height / townLayerH; // world units a px: every picture is at the layers' scale
    for (final (name, r, h) in [
      ('props', props, battlePropsH),
      ('clouds', clouds, battleCloudsH),
      ('floor', floor, battleFloorH),
    ]) {
      expect(r.height / h, closeTo(px, 1e-12), reason: name);
    }
    expect(layers.first.image, 'town_bg_5.png');
    for (final l in layers) {
      expect(l.copies.first.top, sky.top, reason: '${l.image}: the layers keep their rows together');
    }
    // The opaque sky from the screen's top (its top row stretched over the band's top, _scenery) down past the
    // field's top, where the floor is opaque: no blank strip.
    expect(sky.top, inInclusiveRange(0, 16));
    expect(sky.bottom, greaterThan(backdropH));
    // Layer 1's pines' skirts end on its ground at rows 230-263: round the horizon (the field's top), so the props
    // line and the meadow meet them there; its ground runs on under the floor.
    expect(backdropH, inInclusiveRange(near.top + 230 * px, near.top + 263 * px));
    // The clouds over the sky's top part, from the screen's top (their row 0 at band y fieldFoot on the welcome screen,
    // which frames its scene fieldFoot higher, its front edge at its bottom; on the field at the step's lift, the band's
    // part over the screen's top, decisions-log 287); the props line from over the screen's top to just under the
    // horizon (its feet under the floor's opaque grass), above the first lane's feet (y 4 on the field), so a tall prop
    // never stands among the lanes; the floor to fieldFoot under the field's bottom, its front edge there, under the
    // spawn bar's step's top (stepLip).
    expect(fieldFoot, greaterThan(0));
    expect(clouds.top, fieldFoot);
    expect(clouds.bottom, lessThan(fieldFoot + backdropH / 2));
    expect(props.top, 0);
    expect(props.bottom, inExclusiveRange(backdropH, backdropH + 4));
    expect(floor.top, lessThan(backdropH));
    expect(floor.bottom, closeTo(backdropH + fieldH + fieldFoot, 1e-9));
    expect(frontLip, inExclusiveRange(fieldH, fieldH + fieldFoot));
    expect(stepLip, inExclusiveRange(fieldH, frontLip));
  });

  testWidgets('the front edge and the spawn bar\'s step (decisions-log 263, 287): the step\'s top (field y stepLip) at the '
      'bar\'s top, 2 world units under the lowest a unit\'s shadow reaches; the floor\'s grass lip under the step, its last '
      'row over the screen\'s bottom (the earth under it to the bottom); the view as wide as the screen at the field\'s '
      'scale: the screen\'s height over the scene\'s, a little less on a short screen (915x412: "Zoom out sedikit")', (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.view.physicalSize = const Size(1266, 713);
    final game = TdGame();
    await tester.pumpWidget(GameWidget(game: game));
    for (var i = 0; i < 3000 && !game.isLoaded; i++) {
      await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 20)));
      await tester.pump();
    }
    expect(game.isLoaded, isTrue);
    final b = game.board..welcome = null;
    // The lowest a unit stands: the game keeps every unit at y fieldH - 2 or above (here one shoved far under the field).
    final g = b.state = Game(Random(7), Random(107))..gold = 480;
    g.place('knight', 2, rows - 1);
    final knight = g.troops.firstWhere((u) => u.type == 'knight'); // beside the free priest
    knight.pos = Point(knight.pos.x, fieldH + 40);
    g.tick(0.02);
    final lowest = knight.pos.y;
    expect(lowest, fieldH - 2);
    // A unit's feet are 5 under its y (Board._unit's ground), and its shadow's last row is the feet's (art test below:
    // the strips' anchor row): 1 more.
    final shadowEnd = lowest + 5 + 1;
    expect(stepLip - shadowEnd, 2);
    for (final (w, h) in [(1266.0, 713.0), (1164.0, 777.0), (915.0, 412.0), (915.0, 610.0), (1600.0, 947.0), ...sizes]) {
      tester.view.physicalSize = Size(w, h);
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 16));
      final at = 'at ${w.round()}x${h.round()}', scale = b.toScreen(0, 1).dy - b.toScreen(0, 0).dy;
      final step = b.toScreen(0, stepLip).dy, shadow = b.toScreen(0, shadowEnd).dy;
      expect(step, closeTo(b.spawnBarArea.top, 1e-6), reason: '$at: the step\'s top on the bar\'s');
      expect(step - shadow, closeTo(2 * scale, 1e-6), reason: '$at: 2 world units under the lowest shadow');
      final lip = b.toScreen(0, frontLip).dy, last = b.toScreen(0, fieldH + fieldFoot).dy;
      expect((lip > step, last < h), (true, true), reason: '$at: the lip $lip under the step $step, the last row $last on the screen');
      final full = h / (backdropH + fieldH);
      expect(scale, h < 582 ? inExclusiveRange(full * 0.85, full) : closeTo(full, 1e-9), reason: '$at: the scale $scale');
      expect(b.state.viewW, closeTo(w / scale, 1e-6), reason: '$at: the view as wide as the screen');
    }
  });

  test('far layers scroll slower than near ones, the props line between layer 1 and the field, the floor with the '
      'field; the clouds drift left on the clock, wrapping round', () {
    final factors = [
      for (var i = 0; i < townLayers.length; i++) moved(backdropLayers(0, 300)[i].copies, backdropLayers(4, 300)[i].copies) / 4,
    ];
    final props = moved(propsCopies(0, 300), propsCopies(4, 300)) / 4;
    final clouds = moved(cloudCopies(0, 300, 0), cloudCopies(4, 300, 0)) / 4;
    for (final from in cams) {
      expect(moved(floorCopies(from, 300), floorCopies(from + 4, 300)), closeTo(4, 1e-6), reason: 'the floor from cam $from');
      expect(moved(propsCopies(from, 300), propsCopies(from + 4, 300)) / 4, closeTo(props, 1e-6), reason: 'props $from');
      for (var i = 0; i < factors.length; i++) {
        final l = backdropLayers(from, 300)[i].copies, r = backdropLayers(from + 4, 300)[i].copies;
        expect(moved(l, r) / 4, closeTo(factors[i], 1e-6), reason: '${backdropLayers(0, 300)[i].image} from cam $from');
      }
    }
    for (var i = 0; i < factors.length; i++) {
      final why = backdropLayers(0, 300)[i].image;
      expect(factors[i], inExclusiveRange(0, 1), reason: why);
      if (i > 0) expect(factors[i], greaterThan(factors[i - 1]), reason: why);
    }
    expect(props, inExclusiveRange(factors.last, 1));
    expect(clouds, inExclusiveRange(factors[0], factors[1])); // further than the mountains, nearer than the sky
    // The drift: on the clock alone, slowly left (a few world units a second), at every camera and on and on.
    final repeat = cloudCopies(0, 1, 0).first.width - 0.5;
    for (final cam in cams) {
      for (final clock in clocks) {
        final a = cloudCopies(cam, 300, clock), b = cloudCopies(cam, 300, clock + 1);
        expect(moved(a, b), inExclusiveRange(0.3, 3), reason: 'cam $cam, clock $clock: a second\'s drift');
        expect(a.first.left, inInclusiveRange(-repeat, 0), reason: 'cam $cam, clock $clock: wrapped round');
      }
    }
  });

  testWidgets('the backdrop\'s pictures are their sizes', (tester) async {
    await tester.runAsync(() async {
      for (final (name, w, h) in [
        ('battle_floor.png', battleFloorW, battleFloorH),
        ('battle_props.png', battlePropsW, battlePropsH),
        ('battle_clouds.png', battleCloudsW, battleCloudsH),
      ]) {
        final (image, _) = await pixels(name);
        expect((image.width, image.height), (w, h), reason: name);
        image.dispose();
      }
    });
  });

  testWidgets('the backdrop is under everything on the field: units, loot, rings, the HUD', (tester) async {
    tester.view
      ..physicalSize = const Size(1266, 713)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final game = TdGame();
    await tester.pumpWidget(GameWidget(game: game));
    for (var i = 0; i < 3000 && !game.isLoaded; i++) {
      await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 20)));
      await tester.pump();
    }
    expect(game.isLoaded, isTrue);
    final b = game.board
      ..welcome = null
      ..miniMapOpen = false;
    final g = b.state = Game(Random(7), Random(107))..gold = 480;
    for (final (type, col, row) in const [('knight', 2, 0), ('archer', 1, 0), ('priest', 0, 3)]) {
      g.place(type, col, row); // two in the first lane, right in front of the props line
    }
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    // Far to near: the sky (its stretched row, then its copies), the clouds, the mountains and pines, the props line,
    // the floor; then the field's own drawing (the troops, two in the first lane right in front of the props line)
    // and the HUD, none of the backdrop's pictures among them.
    const far = [
      'town_bg_5.png', 'battle_clouds.png', 'town_bg_4.png', 'town_bg_3.png', 'town_bg_2.png', 'town_bg_1.png', //
      'battle_props.png', 'battle_floor.png',
    ];
    final scenery = {for (final name in far) game.images.fromCache(name): name};
    final drawn = _Drawn();
    b.render(drawn);
    final first = drawn.images.indexWhere((i) => !scenery.containsKey(i));
    expect(first, greaterThan(0), reason: 'nothing drawn over the backdrop');
    expect(drawn.images.skip(first).where(scenery.containsKey), isEmpty, reason: 'a backdrop picture drawn over the field');
    final runs = <String>[];
    for (final i in drawn.images.take(first)) {
      if (runs.isEmpty || runs.last != scenery[i]) runs.add(scenery[i]!);
    }
    expect(runs, far);
    final knight = {for (final a in ['idle', 'walk']) game.images.fromCache('tiny_knight_$a.png')};
    expect(drawn.images.skip(first).where(knight.contains), isNotEmpty, reason: 'the knight in the first lane');
  });

  testWidgets('the map: layer 1 is opaque from its pines\' foot down; the floor is clear over the horizon but for the '
      'ground line and blade tips, opaque from it, a meadow, a grass top over earth along the front; the props line '
      'runs off the top with gaps between its props; the clouds stay in the sky', (tester) async {
    await tester.runAsync(() async {
      int alpha(ByteData px, int w, int x, int y) => px.getUint8((y * w + x) * 4 + 3);
      int rgb(ByteData px, int w, int x, int y) => px.getUint32((y * w + x) * 4) >> 8;
      // Layer 1: opaque from row 229 down in every column (the gaps between its pines end higher), so nothing behind
      // it shows through; from row 264 down only its flat ground (every pine's skirt ends above it).
      final (near, n) = await pixels('town_bg_1.png');
      final ground = rgb(n, near.width, 0, near.height - 1), holes = <String>[], skirts = <String>[];
      for (var x = 0; x < near.width; x++) {
        for (var y = 229; y < near.height; y++) {
          if (alpha(n, near.width, x, y) != 255) holes.add('($x, $y)');
          if (y >= 264 && rgb(n, near.width, x, y) != ground) skirts.add('($x, $y)');
        }
      }
      expect(holes, isEmpty, reason: 'town_bg_1.png not opaque');
      expect(skirts, isEmpty, reason: 'town_bg_1.png not its flat ground');
      // The floor: every pixel opaque from the horizon (the field's top) down; above it, clear between the ground
      // line's pieces and the blade tips, its first row clear.
      final floorAt = floorCopies(0, 1).first, px = floorAt.height / battleFloorH;
      final opaque = ((backdropH - floorAt.top) / px).round();
      final (floor, f) = await pixels('battle_floor.png');
      final w = floor.width, clear = <String>[];
      for (var y = opaque; y < floor.height; y++) {
        for (var x = 0; x < w; x++) {
          if (alpha(f, w, x, y) != 255) clear.add('($x, $y)');
        }
      }
      expect(clear, isEmpty, reason: 'battle_floor.png has holes');
      expect([for (var x = 0; x < w; x++) alpha(f, w, x, 0)].every((a) => a == 0), isTrue, reason: 'its row 0 clear');
      final over = [for (var y = 0; y < opaque; y++) for (var x = 0; x < w; x++) alpha(f, w, x, y)];
      expect(over.where((a) => a == 0).length, greaterThan(over.length ~/ 3), reason: 'the props line shows over it');
      expect(over.where((a) => a == 255).length, greaterThan(over.length ~/ 10), reason: 'the ground line');
      // Brightness of a band of rows (the mean of r + g + b): no shaded band under the horizon any more, the meadow
      // is as bright there as further down.
      double bright(int from, int to) {
        var sum = 0;
        for (var y = from; y < to; y++) {
          for (var x = 0; x < w; x++) {
            final c = rgb(f, w, x, y);
            sum += (c >> 16) + (c >> 8 & 0xFF) + (c & 0xFF);
          }
        }
        return sum / (w * (to - from));
      }

      final edge = bright(opaque + 30, opaque + 80), meadow = bright(opaque + 150, floor.height - 40);
      expect(edge, greaterThan(meadow * 0.9), reason: 'under the horizon $edge, the meadow $meadow');
      // The front edge: Floor Tiles1's cell's first rows, its grass top (rows 0-4, the meadow's own greens) at field y
      // frontLip, then its roots and brown-black earth (34, 31, 25) in the last rows; the meadow above it, no earth.
      int earth(int y) => [for (var x = 0; x < w; x++) rgb(f, w, x, y)].where((c) => c == 0x221F19).length;
      final lipRow = ((backdropH + frontLip - floorAt.top) / px).round();
      expect(floor.height - lipRow, 16, reason: 'the edge\'s rows');
      expect(earth(floor.height - 1), w);
      expect(earth(lipRow + 12), greaterThan(w * 0.9));
      for (var y = opaque; y < lipRow + 5; y++) {
        expect(earth(y), 0, reason: 'earth in row $y, over the lip');
      }
      // Every unit's shadow ends on its feet's row (Board's anchor, row 59 of a 100 px frame): the front edge test's
      // shadow is 1 under the feet.
      for (final type in [...troopTypes.keys, ...enemyTypes.keys, 'necromancer']) {
        final (shadow, sp) = await pixels('tiny_${type}_shadow.png');
        final sw = shadow.width;
        final last = [for (var y = 0; y < shadow.height; y++) if ([for (var x = 0; x < sw; x++) alpha(sp, sw, x, y)].any((a) => a > 0)) y].last;
        expect(last, lessThanOrEqualTo(59), reason: type);
        shadow.dispose();
      }
      // The props line: its trunks run up off the top of the screen (row 0 not all clear), and the parallax pines
      // show between its props (a third of the row at the pines' height clear).
      final (props, p) = await pixels('battle_props.png');
      final pw = props.width, pines = ((backdropH - 10) / px).round();
      expect([for (var x = 0; x < pw; x++) alpha(p, pw, x, 0)].where((a) => a == 255), isNotEmpty);
      expect([for (var x = 0; x < pw; x++) alpha(p, pw, x, pines)].where((a) => a == 0).length, greaterThan(pw ~/ 3));
      // The clouds: some sky has some, most of it none.
      final (clouds, c) = await pixels('battle_clouds.png');
      final cw = clouds.width;
      final all = [for (var y = 0; y < clouds.height; y++) for (var x = 0; x < cw; x++) alpha(c, cw, x, y)];
      expect(all.where((a) => a == 255).length, inExclusiveRange(all.length ~/ 50, all.length ~/ 4));
      for (final image in [near, floor, props, clouds]) {
        image.dispose();
      }
    });
  }, tags: 'art');
}
