part of 'main.dart';

// The troop counter at the top left of the field, always on (between waves and in battle): on the HUD's dark panel, level with the wave meter and as big as it, a shield, how
// many troops are alive out of what the army may hold ([Game.armyCap]: the capacity, at most 36 (decisions-log 260;
// 32 until then); gold when full, red when over, "48/36") and a caret. The lives' hearts and the gold go beside it on one panel (lives.dart,
// hud_row.dart). A press on it drops a list down under the row: each
// type on the field ([Game.troopCounts], the book's order; a type with none has no row) with its book sprite (no
// shadow, in its awakening colour), its name ([troopTypeNames]) and its count; with the type caps on ([Game.typeCapOf],
// decisions-log 201) against its cap, "5/5" (gold at it, red over it: "17/5"). Another press on it, or a press
// anywhere else, folds it up; a press on the list does nothing else.

// ui_icons.png: the grey shield, and the small white triangles (their visible pixels) for the caret.
const _counterShield = Rect.fromLTWH(192, 0, 16, 16);
const _caretDown = Rect.fromLTWH(83, 181, 10, 7), _caretUp = Rect.fromLTWH(35, 182, 10, 7);

/// The troop counter's state between frames.
class _TroopList {
  bool open = false;
  Rect button = Rect.zero, list = Rect.zero; // where they were last drawn (the list while open)
  String count = ''; // the counter's "alive/cap", last drawn
  List<String> types = const [], counts = const []; // the open list's types, top down, and their counts ("5/5")
  bool tapped = false; // the last press landed on the counter or its list: its tap up and drag stay there

  /// A press: on the counter it opens or folds the list; anywhere else it folds it. True when it landed
  /// on the counter or on the open list: then it does nothing else.
  bool down(Offset p) {
    if (button.contains(p)) {
      open = !open;
      return tapped = true;
    }
    tapped = open && list.contains(p);
    if (!tapped) open = false;
    return tapped;
  }
}

extension on Board {
  void _troopCounter(Canvas c, Game g) {
    final t = _troops, alive = g.troopCounts, total = alive.values.fold(0, (a, n) => a + n);
    final k = _meterK, icon = 16 * (k - 1), pad = 2 * k, ts = 6 * k, cream = const Color(0xFFFFF1D6);
    // Alive / the army's cap. As wide as two digits each at least, so the panel doesn't twitch as troops come and
    // fall.
    final count = t.count = '$total/${g.armyCap}', caret = _caretDown.size * (k - 1);
    final textW = math.max(_textWidth(count, ts), _textWidth('88/88', ts));
    final panel = Rect.fromLTWH(_edgeL, _meterTop,
        (pad + icon + pad + textW + pad + caret.width + pad).roundToDouble(), _meterH);
    if (g.over) t.open = false;
    t.button = g.over ? Rect.zero : panel.inflate(pad); // a little bigger than it looks, for fingers
    _panel(c, panel);
    final y = panel.center.dy;
    _uiIcon(c, _counterShield.topLeft, Rect.fromLTWH(panel.left + pad, y - icon / 2, icon, icon));
    // Gold: full; red: over (a save from before the cap keeps its 48).
    final ink = total > g.armyCap ? const Color(0xFFFF6B5A) : (g.full ? const Color(0xFFFEE761) : Colors.white);
    _text(c, count, Offset(panel.left + 2 * pad + icon, y), size: ts, color: ink);
    c.drawImageRect(_img('ui_icons.png'), t.open ? _caretUp : _caretDown,
        Offset(panel.right - pad - caret.width, (y - caret.height / 2).roundToDouble()) & caret, _px);
    _hudRow(c, g, panel); // the hearts and the gold on one panel beside it, then the book button in a wave (hud_row.dart)

    t
      ..list = Rect.zero
      ..types = const []
      ..counts = const [];
    if (!t.open || alive.isEmpty) return;
    t
      ..types = [...alive.keys]
      ..counts = [for (final MapEntry(key: type, value: n) in alive.entries) if (g.typeCapOf(type) case final cap?) '$n/$cap' else '$n'];
    // Under it, one row per type: its sprite, its name, its count. As wide as the longest name of any type,
    // so it keeps its width as types come and go.
    final rowH = 12 * k, box = rowH - k, nameW = troopTypeNames.values.map((n) => _textWidth(n, ts)).reduce(math.max);
    // As wide as "88/88" with the caps on (else "88"), so it keeps its width as troops come and fall.
    final countW = [...t.counts, g.typeCap == null ? '88' : '88/88'].map((s) => _textWidth(s, ts)).reduce(math.max);
    final list = Rect.fromLTWH(panel.left, _meterBottom + pad, pad + box + pad + nameW + 2 * pad + countW + pad,
        pad + alive.length * rowH + pad);
    t.list = list;
    _panel(c, list);
    for (final (i, MapEntry(key: type, value: n)) in alive.entries.indexed) {
      final r = Rect.fromLTWH(list.left, list.top + pad + i * rowH, list.width, rowH);
      if (i > 0) {
        c.drawRect(Rect.fromLTWH(r.left + pad, r.top, r.width - 2 * pad, math.max(1.0, k / 2)),
            Paint()..color = const Color(0x668A5E34)); // the panel's rim colour, faint
      }
      // The book's sprite: its visible pixels fill the box, feet on the box's bottom.
      final b = _idleBounds[type]!, s = math.min(box / b.width, box / b.height);
      c.save();
      c.translate(r.left + pad + box / 2, r.top + (rowH + box) / 2);
      c.scale(s);
      _frame(c, 'book_${type}_idle', (_clock * _fps).floor(), Offset.zero, anchor: Offset(b.center.dx, b.bottom),
          paint: n > 0 ? _px : _ghost, line: _awakeLine(g.awakenLevel(type), ghost: n == 0));
      c.restore();
      _heroMark(c, g, type, Rect.fromLTWH(r.left + pad, r.top + (rowH - box) / 2, box, box)); // hero.dart
      _text(c, troopTypeNames[type]!, Offset(r.left + 2 * pad + box, r.center.dy), size: ts, color: cream);
      // Its count, against its cap with the caps on: gold at it, red over it (a save from before the caps: "17/5").
      final cap = g.typeCapOf(type), capInk = cap == null || n < cap ? Colors.white : (n > cap ? const Color(0xFFFF6B5A) : const Color(0xFFFEE761));
      _text(c, t.counts[i], Offset(r.right - pad, r.center.dy), size: ts, anchor: Anchor.centerRight, color: capInk);
    }
  }
}
