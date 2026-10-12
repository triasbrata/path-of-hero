part of 'main.dart';

// How awakening looks (the rules are in game.dart: awakenRecipe, Game.awakenLevel). An awakened troop
// keeps its own colours; only what is round it takes its level's colour: a 1 px outline (built in memory
// at load, [_outlines]), its ground shadow and sparks rising round it, and level pips by its HP bar. Its
// hit bursts and shots are recoloured toward it ([awakeFx] names). The book's rows and the troop counter
// draw the outline round their sprites too, and stars under each row's sprite show the level
// (lib/troop_row.dart). Bangkit 4 and 5, bought with gold (#92 part 2), have their own colours for all that is round
// the troop, but its shots and bursts stay Bangkit 3's gold ([_fxColor]).

/// Level 1, 2, 3: blue, crimson, gold; Bangkit 4 and 5 (bought, [maxAscend]): violet and white.
const _awakeColors = [Color(0xFF3D8BFF), Color(0xFFE8203A), Color(0xFFFFC93C), Color(0xFF8E44FF), Color(0xFFF2F6FF)];

/// The same, dark enough for text on the book's page (white's a cool slate).
const _awakeInk = [Color(0xFF1F5FBF), Color(0xFFC0182E), Color(0xFFB07A00), Color(0xFF6B2FC9), Color(0xFF55617A)];

/// The colour a troop of awakening [level] (1 up) tints its shots and hit bursts with: its level's up to [maxAwaken].
/// Bangkit 4 and 5 keep Bangkit 3's gold there: their violet and white would come near the skills' own (Arcane
/// Blast's violet ring, Spellbreaker's silver arrow, the healers' white smite, which only a heal's colour tells from a
/// heal), so only the outline, shadow, sparks, pips and stars take them.
Color _fxColor(int level) => _awakeColors[math.min(level, maxAwaken) - 1];

/// Recolours toward [c] and keeps the shading: each pixel's brightness, times [c] and brightened,
/// over a fifth of its own colour, plus a little of [c] so it glows. Dark outlines stay dark, so the
/// pixel art still reads.
ColorFilter _tint(Color c) => ColorFilter.matrix(_tintMatrix(c));

/// [_tint]'s colour matrix (4x5, row by row).
List<double> _tintMatrix(Color c) {
  const keep = 0.2, lift = 2.0, glow = 30.0, lum = [0.299, 0.587, 0.114];
  List<double> row(double ch, int i) =>
      [for (var j = 0; j < 3; j++) (i == j ? keep : 0) + (1 - keep) * lift * ch * lum[j], 0, glow * ch];
  return [...row(c.r, 0), ...row(c.g, 1), ...row(c.b, 2), 0, 0, 0, 1, 0];
}

/// Dyes a white or pale sheet [c], keeping its shading: each pixel times [c] (the hit bursts that are white), where
/// [_tint] would wash a bright one out to white.
ColorFilter _dye(Color c) => ColorFilter.mode(c, BlendMode.modulate);

/// Each level's colour as a tint ([_tint]): an awakened troop's hit bursts and shots (arrows, the wizard's magic:
/// [Board._awakeFx], up to Bangkit 3's), the stars and the log's star icon.
final _awakeFxPaints = [for (final c in _awakeColors) Paint()..filterQuality = FilterQuality.none..colorFilter = _tint(c)];

/// Flat in [c], keeping each pixel's alpha: the white outlines and the ground shadow.
ColorFilter _flat(Color c) => ColorFilter.mode(c, BlendMode.srcIn);

/// The outline in each level's colour; faded for a troop being dragged or one the player can't afford.
final _linePaints = [for (final c in _awakeColors) Paint()..filterQuality = FilterQuality.none..colorFilter = _flat(c)];
final _lineGhosts = [
  for (final c in _awakeColors) Paint()..filterQuality = FilterQuality.none..colorFilter = _flat(c.withValues(alpha: 0.6)),
];
final _shadowFilters = [for (final c in _awakeColors) _flat(c)];

/// The ground shadow of an awakened troop (level 1 and up): flat in its level's colour at [awakenShadowAlpha], pulsing a
/// little with [clock] (out of step by [id]). The field's ([Board._awakeShadow]); the Town's troops have none (decisions-log 270).
Paint awakenShadowPaint(int level, int id, double clock) => Paint()
  ..filterQuality = FilterQuality.none
  ..colorFilter = _shadowFilters[level - 1]
  ..color = Colors.white.withValues(alpha: awakenShadowAlpha * (0.8 + 0.2 * math.sin(clock * 3 + id)));

/// Each troop strip's outline by the strip's name (`tiny_<type>_<anim>.png`, `book_<type>_idle`), built
/// at load ([_outlined]); [Board._frame] draws it under the body when given a `line` paint.
final _outlines = <String, ui.Image>{};

/// A 1 px outline round the visible pixels of [src], a strip of square frames, frame by frame: in white,
/// every clear pixel with a visible one left, right, above or below it; the rest clear.
Future<ui.Image> _outlined(ui.Image src) async {
  final px = (await src.toByteData(format: ui.ImageByteFormat.rawRgba))!.buffer.asUint8List();
  final w = src.width, h = src.height, fs = h, out = Uint8List(w * h * 4);
  bool on(int x, int y) => px[(y * w + x) * 4 + 3] != 0;
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      if (on(x, y)) continue;
      final fx = x % fs; // no pixel counts across a frame's edge
      if ((fx > 0 && on(x - 1, y)) || (fx < fs - 1 && on(x + 1, y)) || (y > 0 && on(x, y - 1)) || (y < h - 1 && on(x, y + 1))) {
        out.fillRange((y * w + x) * 4, (y * w + x) * 4 + 4, 255);
      }
    }
  }
  final done = async.Completer<ui.Image>();
  ui.decodeImageFromPixels(out, w, h, ui.PixelFormat.rgba8888, done.complete);
  return done.future;
}

/// A burst name split into the plain burst and the awakening level it was queued in ([awakeFx]). Read several times a
/// burst every frame, so each name is split once ([_awakeOfs]; the names are a small fixed set; decisions-log 317).
(String, int) _awakeOf(String who) => _awakeOfs[who] ??= switch (_awakeName.firstMatch(who)) {
      final m? => (m[1]!, int.parse(m[2]!)),
      null => (who, 0),
    };
final _awakeName = RegExp(r'^(.+)_awake(\d)$'), _awakeOfs = <String, (String, int)>{};

extension on Board {
  /// The outline paint for a troop of awakening [level] (none at 0), faded for a [ghost].
  Paint? _awakeLine(int level, {bool ghost = false}) => level == 0 ? null : (ghost ? _lineGhosts : _linePaints)[level - 1];

  /// The paint for an awakened troop's bursts and arrows: recoloured ([_fxColor]: Bangkit 4 and 5 as Bangkit 3), or
  /// plain [_px] at 0.
  Paint _awakeFx(int level) => level == 0 ? _px : _awakeFxPaints[math.min(level, maxAwaken) - 1];

  /// The paint for an awakening's own burst (`upgrade_awake<level>`): in the level's colour, Bangkit 4 and 5's too.
  Paint _awakeMark(int level) => level == 0 ? _px : _awakeFxPaints[level - 1];

  /// An awakened troop's ground shadow: flat in its level's colour, pulsing a little ([awakenShadowPaint]).
  Paint _awakeShadow(Unit u, int level) => awakenShadowPaint(level, u.id, _fieldClock);

  /// Sparks of the level's colour rising round an awakened troop (in front of the body): one-pixel
  /// squares, like the art, fading as they climb; one more for each level. Each troop's are out of step
  /// with the others'.
  void _auraSparks(Canvas c, Unit u, int level, Offset ground) {
    final color = _awakeColors[level - 1], n = 3 + level;
    for (var i = 0; i < n; i++) {
      final p = (_fieldClock * 0.9 + i / n + u.id * 0.37) % 1.0, seed = (u.id * 7 + i * 13) % 11 / 10;
      final at = ground + Offset((seed - 0.5) * 14 + math.sin(p * 6 + i) * 1.5, -2 - p * 20);
      c.drawRect(Rect.fromCenter(center: at, width: 1.2, height: 1.2), Paint()..color = color.withValues(alpha: 1 - p));
    }
  }
}

/// What can't take one more item: the Tas row's shade; the count and the maxed stat on the book's page, and a
/// refusal in the drop popup (drop_popup.dart).
const _blocked = Color(0xFFE0402A), _blockedInk = Color(0xFFB0302A);

/// How wide [t] is in the game's font at [size] (the troop counter lays its list out with it); each [_starGlyph] as
/// [Board._text] draws it, a star icon [_starW] wide.
double _textWidth(String t, double size, {bool bold = false}) {
  if (!t.contains(_starGlyph)) return TextPaint(style: hudStyle(size, bold: bold)).getLineMetrics(t).width;
  final pieces = t.split(_starGlyph);
  return pieces.fold(0.0, (w, p) => w + (p.isEmpty ? 0 : _textWidth(p, size, bold: bold))) + (pieces.length - 1) * _starW(size);
}

/// The Pusaka's star in the book's words ("Di Gudang ★2"). The game's font has no such glyph (nor an arrow), so
/// [Board._text] draws each one as ui_icons.png's full star, [_starW] wide at text [size].
const _starGlyph = '★';
double _starW(double size) => size * 0.85;

extension on Board {
  /// A Tas row whose type can't take the item dragged onto its troop on the field: shaded and framed red.
  void _refuse(Canvas c, Rect r, double ts) {
    final rr = RRect.fromRectAndRadius(r.deflate(2 * ts), Radius.circular(4 * ts));
    c.drawRRect(rr, Paint()..color = _blocked.withValues(alpha: 0.22));
    c.drawRRect(rr, Paint()
      ..color = _blocked
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2 * ts);
  }

  /// [level] pips in its colour, dark-rimmed, from [at] (the first one's left, mid height) rightwards:
  /// an awakened troop's level beside its HP bar.
  void _levelPips(Canvas c, Offset at, int level) {
    for (var i = 0; i < level; i++) {
      final o = at + Offset(i * 2.4, 0);
      c.drawRect(Rect.fromLTWH(o.dx, o.dy - 1, 2, 2), Paint()..color = const Color(0xFF2A1A0E));
      c.drawRect(Rect.fromLTWH(o.dx + 0.4, o.dy - 0.6, 1.2, 1.2), Paint()..color = _awakeColors[level - 1]);
    }
  }
}
