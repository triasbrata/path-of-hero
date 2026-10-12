part of 'main.dart';

// The field's rings and glows in the sprites' pixels (decisions-log 325; ui-hud.md "The field's rings in pixels"): the
// Pusaka's ring (pusaka_look.dart), the guard's and the effects' rings (skills.dart), Spear Wall's brace ring
// (hero_move_fx.dart), a Hero's halo (hero.dart) and a dragged troop's reach (main.dart). Each shape is cells one world
// unit each, like a sprite's pixels, built once at load ([_buildPixelShapes]) as a white image with a clear pixel all
// round (so the quad's own edges fall on clear pixels), and drawn nearest and without anti-aliasing, flat in its colour
// ([_pixelPaint]), a whole number of world units from the feet or the cell it is round: at any zoom its steps fall on
// the sprites' pixels and a screen pixel is the colour or nothing. No shape is drawn in code: the owner, 2026-10-12, "ring
// putih atau kuning di bawah troops di buat jadi pixelated", then every other ring and the halo and the reach too.

/// The rings' boxes, w × h world units, centred 1 above the feet: the Pusaka's (a little wider than the others, so they
/// sit inside it), the guard's, Spear Wall's brace and the effects' (one inside another from the outside in; a fifth and
/// later one takes the last size).
const _pusakaRingSize = (w: 20, h: 8), _guardRingSize = (w: 16, h: 7), _braceRingSize = (w: 18, h: 8);
const _effectRingSizes = [(w: 18, h: 8), (w: 14, h: 6), (w: 10, h: 4), (w: 6, h: 2)];

/// A dashed ring (Impale's pin, Ice Grip's hold): [ringDashes] dashes round it, each half of its share, turning
/// [_dashTurn] radians a second; drawn at one of [dashPhases] steps through a dash and its gap.
const ringDashes = 10, dashPhases = 8, _dashTurn = 0.8;

/// A Hero's halo: radius 14 ± 1.5 world units pulsing, drawn at the nearest whole radius, from [haloRadii].from to .to;
/// [haloBands] bands of alpha from the middle out.
const haloRadii = (from: 13, to: 16), haloBands = 4;

/// The images, built once at load ([_buildPixelShapes]); process-wide, like [_outlines].
final _ringImages = <(int, int), ui.Image>{}, _dashImages = <(int, int, int), ui.Image>{};
final _haloImages = <int, ui.Image>{}, _discImages = <int, ui.Image>{};

/// The cells of a 1 px oval [w] × [h] in the sprites' pixels, each (column, row) from the box's top left: every cell
/// whose middle is inside the oval and one of whose four neighbours' is not. Its edge steps like the units' shadows
/// (`tiny_<type>_shadow.png`) and is never two cells thick at the rings' sizes.
List<(int, int)> pixelRingCells(int w, int h) {
  bool inside(int i, int j) {
    final x = (i + 0.5) / w * 2 - 1, y = (j + 0.5) / h * 2 - 1;
    return i >= 0 && i < w && j >= 0 && j < h && x * x + y * y <= 1;
  }

  return [
    for (var j = 0; j < h; j++)
      for (var i = 0; i < w; i++)
        if (inside(i, j) && !(inside(i - 1, j) && inside(i + 1, j) && inside(i, j - 1) && inside(i, j + 1))) (i, j),
  ];
}

/// [pixelRingCells] of [w] × [h] dashed at step [phase] of [dashPhases]: the cells whose angle round the oval (as
/// `drawArc` measures it, clockwise from the right) falls in the first half of one of its [ringDashes] shares, the
/// shares turned on by [phase].
List<(int, int)> pixelDashCells(int w, int h, int phase) {
  final share = 2 * math.pi / ringDashes, turn = phase / dashPhases;
  return [
    for (final (i, j) in pixelRingCells(w, h))
      if ((math.atan2((j + 0.5) / h * 2 - 1, (i + 0.5) / w * 2 - 1) / share - turn) % 1 < 0.5) (i, j),
  ];
}

/// A halo of radius [r] in the sprites' pixels, 2r × 2r cells from its top left, each with its alpha (0-255): [haloBands]
/// bands out to the circle, each the old gradient's alpha (0xDD white in the middle, 0x88 at 60%, clear at the edge)
/// at the band's middle, so it steps where it faded.
Map<(int, int), int> pixelHaloCells(int r) {
  double fade(double t) => t < 0.6 ? 0xDD - (0xDD - 0x88) * t / 0.6 : 0x88 * (1 - t) / 0.4;
  return {
    for (var j = 0; j < 2 * r; j++)
      for (var i = 0; i < 2 * r; i++)
        if (math.sqrt(math.pow(i + 0.5 - r, 2) + math.pow(j + 0.5 - r, 2)) / r case final t when t <= 1)
          (i, j): fade((math.min(haloBands - 1, (t * haloBands).floor()) + 0.5) / haloBands).round(),
  };
}

/// A filled disc of radius [r] in the sprites' pixels, 2r × 2r cells from its top left: every cell whose middle is in it.
List<(int, int)> pixelDiscCells(int r) => [
      for (var j = 0; j < 2 * r; j++)
        for (var i = 0; i < 2 * r; i++)
          if (math.pow(i + 0.5 - r, 2) + math.pow(j + 0.5 - r, 2) <= r * r) (i, j),
    ];

/// [cells] (each with its alpha) as a white image [w] × [h] framed by a clear pixel all round. Premultiplied white, so
/// only the alpha counts once [_pixelPaint] lays its colour on.
Future<ui.Image> _pixelImage(int w, int h, Iterable<((int, int), int)> cells) {
  final px = Uint8List((w + 2) * (h + 2) * 4);
  for (final ((i, j), a) in cells) {
    final at = ((j + 1) * (w + 2) + i + 1) * 4;
    px.fillRange(at, at + 4, a);
  }
  final done = async.Completer<ui.Image>();
  ui.decodeImageFromPixels(px, w + 2, h + 2, ui.PixelFormat.rgba8888, done.complete);
  return done.future;
}

/// Builds every shape once ([TdGame.onLoad]): each ring size whole and dashed at every step, the halo at every radius
/// and the reach disc of every troop type's range.
Future<void> _buildPixelShapes() async {
  Iterable<((int, int), int)> opaque(List<(int, int)> cells) => cells.map((c) => (c, 255));
  for (final (:w, :h) in {_pusakaRingSize, _guardRingSize, _braceRingSize, ..._effectRingSizes}) {
    _ringImages[(w, h)] = await _pixelImage(w, h, opaque(pixelRingCells(w, h)));
  }
  for (final (:w, :h) in _effectRingSizes) {
    for (var p = 0; p < dashPhases; p++) {
      _dashImages[(w, h, p)] = await _pixelImage(w, h, opaque(pixelDashCells(w, h, p)));
    }
  }
  for (var r = haloRadii.from; r <= haloRadii.to; r++) {
    _haloImages[r] = await _pixelImage(2 * r, 2 * r, [for (final MapEntry(:key, :value) in pixelHaloCells(r).entries) (key, value)]);
  }
  for (final r in {for (final s in troopTypes.values) s.range.round()}) {
    _discImages[r] = await _pixelImage(2 * r, 2 * r, opaque(pixelDiscCells(r)));
  }
}

/// The paint of a shape in colour [c] at [alpha]: one per colour, made once and given its alpha at each draw (a draw
/// takes the paint as it is then). Nearest, no anti-alias, the shape's white flat in [c] ([_flat]).
final _pixelPaints = <Color, Paint>{};
Paint _pixelPaint(Color c, double alpha) => (_pixelPaints[c] ??= Paint()
      ..filterQuality = FilterQuality.none
      ..isAntiAlias = false
      ..colorFilter = _flat(c))
  ..color = Colors.white.withValues(alpha: alpha.clamp(0.0, 1.0));

/// Where a ring's image goes from the feet at [ground]: its box ([size]) centred 1 above them, an odd height's top half a
/// unit higher so it stays on a whole unit, less the image's clear border.
Offset _ringImageAt(Offset ground, ({int w, int h}) size) =>
    ground + Offset(-size.w / 2 - 1, (-1 - size.h / 2).floorToDouble() - 1);

/// The ring of [size] round the feet at [ground] in [paint].
void _pixelRingAt(Canvas c, Offset ground, ({int w, int h}) size, Paint paint) =>
    c.drawImage(_ringImages[(size.w, size.h)]!, _ringImageAt(ground, size), paint);

/// The same ring dashed ([pixelDashCells]), turned by [clock] (seconds).
void _dashedRingAt(Canvas c, Offset ground, ({int w, int h}) size, double clock, Paint paint) {
  final phase = (clock * _dashTurn / (2 * math.pi / ringDashes) * dashPhases).floor() % dashPhases;
  c.drawImage(_dashImages[(size.w, size.h, phase)]!, _ringImageAt(ground, size), paint);
}

/// A Hero's halo of radius [r] (a whole number, [haloRadii]) round [middle], in white.
void _haloAt(Canvas c, Offset middle, int r) =>
    c.drawImage(_haloImages[r]!, middle - Offset(r + 1.0, r + 1.0), _pixelPaint(const Color(0xFFFFFFFF), 1));

/// A dragged troop's reach [range] round [middle] (the cell's middle, on whole units): white at [alpha].
void _discAt(Canvas c, Offset middle, double range, double alpha) {
  final r = range.round();
  c.drawImage(_discImages[r]!, middle - Offset(r + 1.0, r + 1.0), _pixelPaint(const Color(0xFFFFFFFF), alpha));
}
