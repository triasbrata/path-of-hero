part of 'main.dart';

// The off-view marker (#56; the owner: "para troops bisa saja off cam jika mereka tertinggal"): while living
// troops are out of sight left of the view ([Game.leftOfView]), a small dark panel on the field's left
// edge, level with them, holds the pack's arrow pointing left (the Start/Pause toggle's play sign, flipped) and
// how many they are.

extension on Board {
  /// Draws the marker for the troops left of the view, if any. Sets [_offViewAt].
  void _offViewMarker(Canvas c, Game g) {
    _offViewAt = Rect.zero;
    final left = g.leftOfView.toList();
    if (left.isEmpty) return;
    final s = _scale, k = _meterK, ik = math.max(1.0, k - 1), pad = 2 * k, font = 6 * k;
    final label = '${left.length}', h = 12 * ik + 2 * pad;
    final w = (pad + 7 * ik + pad + _textWidth(label, font) + pad).roundToDouble();
    // Level with them (their middle), inside the field.
    final o = _origin.dy, y = o + (backdropH + left.map((u) => u.pos.y).reduce((a, b) => a + b) / left.length) * s;
    final bottom = o + (backdropH + fieldH) * s - h, top = (y - h / 2).clamp(o + backdropH * s, bottom).roundToDouble();
    // Clear of an open panel over the field's left edge, as last drawn (the troop counter's list; the Shadows' chips
    // and the boss bars while the book puts them at the left): beside it.
    var r = Rect.fromLTWH(_safe.left + pad, top, w, h); // inside a phone's notch side (decisions-log 215)
    for (final p in [if (_troops.open) _troops.list, if (_asideLeft) _omenRow.at, if (_bossAside) _bossAt]) {
      if (p.overlaps(r)) r = r.translate(p.right + pad - r.left, 0);
    }
    _offViewAt = r;
    _panel(c, r);
    // The play sign's visible 7x12 is at (5, 2) of its 16x16 cell; flipped, at (4, 2).
    c.save();
    c.translate(r.left + pad - 4 * ik + 16 * ik, r.top + pad - 2 * ik);
    c.scale(-1, 1);
    c.drawImageRect(_img('ui_icons.png'), _startIcon & const Size(16, 16), Rect.fromLTWH(0, 0, 16 * ik, 16 * ik), _px);
    c.restore();
    _text(c, label, Offset(r.left + pad + 7 * ik + pad, r.center.dy), size: font);
  }
}
