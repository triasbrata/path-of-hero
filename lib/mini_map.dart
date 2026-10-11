part of 'main.dart';

// The minimap (#80; the owner: "kita perlu buatkan map untuk melihatkan posisi pertarungan ada di mana dan
// garis akhir ada dimana", then "map pindah ke kanan atas dan dia itu dropdown dari meter wave"). A press on
// the wave meter drops it down under the meter (another folds it), like the troop counter's list; settings.json
// keeps whether it is open. On the battle bar's dark panel, a strip of the whole field ([miniMapSpan]: from the
// back line to where the monsters come on): the deploy zone, the back line in red, a dot per living unit
// (troops green; monsters in their rank's HP colour, the mini boss and the boss bigger), the view as a frame
// and the battle line ([battleLine]) in gold. It only tells: a press on it does nothing else. It stays under the
// meter in every state (decisions-log 220; the owner: "sama posisi map juga jangan pindah pindah"): with the book
// showing in landscape it is drawn over the book's top edge.

/// Inside the map: the field's earth, the deploy zone over it, and the lines and dots.
const _mapGround = Color(0xFF5E4A2E), _mapZone = Color(0x47FFFFFF), _mapBack = Color(0xFFE43B44);
const _mapTroop = Color(0xFF63C74D), _mapView = Color(0xE6FFFFFF), _mapBattle = Color(0xFFFEE761);

/// The part of the field the minimap shows, left to right: from the back line (or the view's left edge, or the
/// rearmost unit, when further back) to where the monsters come on (the view's right edge) or the foremost
/// unit, when further on; a tile more each side.
(double, double) miniMapSpan(Game g) {
  final xs = [for (final u in g.units) if (u.alive) u.pos.x];
  return ([g.baseX, g.cam, ...xs].reduce(math.min) - tile, [g.cam + g.viewW, ...xs].reduce(math.max) + tile);
}

/// Where the fight is: the last fight the camera centred this wave ([Game.fightX], the battle point in
/// contact, #85), held through lulls; null before the wave's first contact and between waves.
double? battleLine(Game g) => g.waveActive ? g.fightX : null;

/// The minimap's state between frames.
class _MiniMap {
  _MiniMap(this.open);

  bool open;
  Rect button = Rect.zero, at = Rect.zero; // the wave meter's press area and the map, as last drawn (the map while open)
  bool tapped = false; // the last press landed on the meter or the open map: its tap up and drag stay there
}

extension _MiniMapDraw on Board {
  /// A press: on the wave meter it opens or folds the map (settings.json keeps which); on the open map it does
  /// nothing else. True when it landed on either.
  bool _mapDown(Offset p) {
    final m = _map;
    if (m.button.contains(p)) {
      m.open = !m.open;
      _settings.miniMap = m.open;
      saveSettings(_settings);
      return m.tapped = true;
    }
    return m.tapped = m.open && m.at.contains(p);
  }

  /// Whether the boss bars and the Shadows' chips go to the left column: while the book shows, whose tabs and top edge
  /// are right under the wave meter's band (#74's option (b)). The map stays under the meter, over
  /// the book's top edge (decisions-log 220).
  bool get _asideLeft => _bookT > 0.01;

  /// The map, while open: under the wave meter and as wide, in every state. Sets [_MiniMap.at], and draws it, but while
  /// the book shows: then [_hud] draws it after the book ([_miniMapDraw]), over the book's top edge.
  void _miniMap(Canvas c, Game g) {
    final m = _map;
    m.at = Rect.zero;
    if (!m.open || g.over || _meterAt.isEmpty || g.inTown) return; // folded in a Town: nothing to map
    final k = _meterK, pad = 2 * k, h = 16 * k + 2 * pad, meter = _meterAt;
    m.at = Rect.fromLTWH(meter.left, meter.bottom + pad, meter.width, h);
    if (!_asideLeft) _miniMapDraw(c, g);
  }

  /// Draws the open map where [_miniMap] put it.
  void _miniMapDraw(Canvas c, Game g) {
    final at = _map.at;
    if (at.isEmpty) return;
    final k = _meterK, pad = 2 * k;
    _panel(c, at);

    final inner = at.deflate(pad);
    final (x0, x1) = miniMapSpan(g);
    final sx = inner.width / (x1 - x0), sy = inner.height / fieldH;
    double mx(double x) => (inner.left + (x - x0) * sx).roundToDouble();
    Paint paint(Color color) => Paint()..color = color;
    c.save();
    c.clipRect(inner);
    c.drawRect(inner, paint(_mapGround));
    c.drawRect(Rect.fromLTRB(mx(g.baseX), inner.top, mx(g.baseX + g.zoneCols * tile), inner.bottom), paint(_mapZone));
    // A dot per living unit, its middle where it stands: the troops, then the monsters by rank (the mini boss
    // and the boss last and bigger, ringed dark), so the strongest stay on top.
    void dot(Unit u, Color color, double d, {bool ring = false}) {
      final r = Rect.fromCenter(center: Offset(mx(u.pos.x), inner.top + u.pos.y * sy), width: d, height: d);
      final box = Rect.fromLTWH(r.left.roundToDouble(), r.top.roundToDouble(), d, d);
      if (ring) c.drawRect(box.inflate(math.max(1, k / 2).roundToDouble()), paint(const Color(0xFF1B120A)));
      c.drawRect(box, paint(color));
    }

    final small = (1.5 * k).roundToDouble(), big = 3 * k;
    for (final u in g.troops) {
      if (u.alive) dot(u, _mapTroop, small);
    }
    final foes = [for (final u in g.enemies) if (u.alive) u]..sort((a, b) => a.tier.index.compareTo(b.tier.index));
    for (final u in foes) {
      final boss = u.tier == Tier.miniBoss || u.tier == Tier.boss;
      dot(u, _tierBar[u.tier]?.$1 ?? _mapBack, boss ? big : small, ring: boss);
    }
    // The battle line, dashed gold; the view, a white frame.
    if (battleLine(g) case final x?) {
      for (var y = inner.top; y < inner.bottom; y += 2 * k) {
        c.drawRect(Rect.fromLTWH(mx(x) - (k / 2).roundToDouble(), y, k, k), paint(_mapBattle));
      }
    }
    final line = math.max(1.0, (k / 2).roundToDouble());
    c.drawRect(
        Rect.fromLTRB(mx(g.cam), inner.top, mx(g.cam + g.viewW), inner.bottom).deflate(line / 2),
        Paint()
          ..color = _mapView
          ..style = PaintingStyle.stroke
          ..strokeWidth = line);
    // The back line on top: a sprite pixel wide, red (between waves it is the view's left edge too).
    c.drawRect(Rect.fromLTWH(mx(g.baseX), inner.top, k, inner.height), paint(_mapBack));
    c.restore();
  }
}
