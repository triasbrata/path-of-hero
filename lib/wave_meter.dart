part of 'main.dart';

// The wave meter at the top right of the field (#80's re-layout; it was at the top centre), in every state
// but game over: on a dark panel like the troop counter's, crossed swords, the wave's number (between waves
// the coming one's), a bar that fills as the wave's monsters come on, "spawned/total" ([Game.waveSpawned],
// [Game.waveTotal]; none between waves, when the coming wave's size isn't known yet) and a caret. Once the
// whole wave is out the bar turns gold and stays full until the wave is won. In a Town (decisions-log 216) the same
// panel shows a beer mug, "In town" and the coming wave instead ([Board._inTownMeter]). A press on it drops the minimap
// down under it (mini_map.dart); the caret points down while it is folded, up while open. It stays put when
// the book opens ("meter wave jangan ikut terdorong"): in landscape the book keeps below its band
// ([_meterBottom]).

// ui_bars.png: the long empty bar (black inside, a checkered left end) is 30x5 at (1, 15); its left 5
// and right 1 columns stay, the middle stretches. Fill columns: the red strip (2 px red over 1 px shade)
// and the gold one.
const _meterRed = Rect.fromLTWH(2, 7, 1, 3), _meterGold = Rect.fromLTWH(2, 11, 1, 3);
const _meterSwords = Rect.fromLTWH(112, 16, 16, 16); // ui_icons.png
const _meterLen = 60.0; // the bar's length in sprite px

/// The tide's badge (#92): light blue, so it reads on the dark panel.
const _tideInk = Color(0xFF7FC8FF);

/// The desk's top band ([_meterH] at k 3) and window height (1266x713, the owner's): the HUD takes no more of its
/// screen's height than this (decisions-log 215, on every platform since 217).
const _deskBand = 44.0, _deskH = 713.0;

/// A landscape top band's width as the scale k grows (it needs [_rowWidthPerK]·k − [_rowWidthOff] px: the counter, the
/// hearts-and-gold panel and the book button, the Start/Pause toggle, x2, Auto Wave and the wave meter side by side;
/// decisions-log 217, re-measured with decisions-log 220's layout by test/probe_hud_merge_width.dart, and again with
/// "Auto Wave" for "Auto", decisions-log 290: fitted to k 3 and 4, the only ones it decides between).
const _rowWidthPerK = 399.0, _rowWidthOff = 130.0;

extension _WaveMeter on Board {
  /// Screen px per sprite px of the HUD: the screen's height over the scene's (the field's scale but for a short
  /// screen's zoom, which the HUD never takes: [Board._hotGeom] reads the top band's bottom; decisions-log 287), whole, 2
  /// to 4, on every platform and at every window size,
  /// and also at most
  /// - the largest whose top band ([_meterH]) takes no more of the screen's height than the desk's does (44 of 713 px;
  ///   decisions-log 215: the owner's tablet, 1164x777, has 3, not 4; decisions-log 217: the same on the desktop), and
  /// - the largest whose top band fits the screen's width without a piece over another: 399·k − 130 px
  ///   (measured: 1067 at k 3, 1466 at k 4, with 5 digits of gold, the tide's badge, 3-digit counts, "Auto Wave" and
  ///   Auto's seconds on Start; ui-hud.md "Layouts").
  double get _meterK {
    final k = (size.y / (backdropH + fieldH)).floorToDouble().clamp(2.0, 4.0);
    // 20·k − 16 ≤ height · 44 / 713, in whole numbers so the desk's own height gives exactly 3.
    final tall = ((size.y * _deskBand + 16 * _deskH) / (20 * _deskH)).floorToDouble();
    final wide = ((size.x + _rowWidthOff) / _rowWidthPerK).floorToDouble();
    return math.min(k, math.max(2.0, math.min(tall, wide)));
  }

  double get _meterH => 20 * _meterK - 16; // the panel: the icon (16·(k−1)) and its padding (2·k) round it
  // Its middle at y 32; both below what a phone's screen keeps at the top ([_safe]).
  double get _meterTop => _safe.top + math.max(10.0, 32 - _meterH / 2);

  /// Where the meter's band ends: the top row's bottom; the book stays below it, so the meter never has to move.
  double get _meterBottom => _meterTop + _meterH;

  /// How far the HUD keeps from the screen's edges.
  static const _edge = 10.0;

  /// The HUD's left and right edges: [_edge] inside what a phone's screen keeps on that side ([_safe]: a notch, a
  /// camera hole; decisions-log 215). The desktop's are [_edge].
  double get _edgeL => _safe.left + _edge;
  double get _edgeR => _safe.right + _edge;

  /// The battle log's button's bottom edge: [_edge] above the screen's bottom, and above what a phone's screen keeps
  /// there.
  double get _edgeB => _safe.bottom + _edge;

  void _waveMeter(Canvas c, Game g) {
    final on = g.waveActive, total = on ? g.waveTotal : 0, shown = on ? g.wave : g.wave + 1;
    final k = _meterK, h = _meterH;
    final icon = 16 * (k - 1), barW = _meterLen * k, pad = 2 * k, ts = 6 * k;
    // As wide as the widest wave number and count, so it doesn't twitch as it counts up or the wave starts.
    final wave = '$shown', waveW = math.max(_textWidth(wave, ts), _textWidth('88', ts));
    // From the tide's first wave its HP after the number ("+35%" on wave 65, #92), with room for "+999%".
    final from = g.tideStart;
    _tideLabel = shown >= from ? '+${tidePercent(shown, from)}%' : '';
    final tideW = _tideLabel.isEmpty ? 0.0 : math.max(_textWidth(_tideLabel, ts), _textWidth('+999%', ts)) + pad;
    // The count keeps room for the coming wave's size between waves too (4 + 2 a wave, and its bosses, healers and escorts:
    // twice that, to be sure), so the meter, and x2 and Auto beside it, never move as a wave starts (decisions-log 220).
    final room = '8' * math.max('${math.max(total, 2 * (4 + 2 * shown))}'.length, 2);
    final countW = math.max(_textWidth('$total/$total', ts), _textWidth('$room/$room', ts)), caret = _caretDown.size * (k - 1);
    final w = pad + icon + pad + waveW + tideW + pad + barW + pad + countW + pad + caret.width + pad;
    final panel = Rect.fromLTWH((size.x - _edgeR - w).roundToDouble(), _meterTop, w.roundToDouble(), h);
    _meterAt = panel; // the map hangs under it, the boss bars under that, and x2 and Auto beside it (hud_row.dart)
    _map.button = panel.inflate(pad); // a little bigger than it looks, for fingers
    _panel(c, panel);

    final y = panel.center.dy;
    _tideAt = Rect.zero;
    c.drawImageRect(_img('ui_icons.png'), _map.open ? _caretUp : _caretDown,
        Offset(panel.right - pad - caret.width, (y - caret.height / 2).roundToDouble()) & caret, _px);
    // In a Town the same panel says it's safe: a beer mug, "In town" and the coming wave (town_look.dart).
    if (g.inTown) {
      final inside = Rect.fromLTRB(panel.left + pad, panel.top, panel.right - 2 * pad - caret.width, panel.bottom);
      _tideLabel = ''; // its room kept, so the meter doesn't change size
      return _inTownMeter(c, inside, pad, icon, ts, shown);
    }
    c.drawImageRect(_img('ui_icons.png'), _meterSwords, Rect.fromLTWH(panel.left + pad, panel.top + pad, icon, icon), _px);
    _text(c, wave, Offset(panel.left + 2 * pad + icon, y), size: ts);
    if (_tideLabel.isNotEmpty) {
      final x = panel.left + 3 * pad + icon + waveW;
      _text(c, _tideLabel, Offset(x, y), size: ts, color: _tideInk);
      _tideAt = panel; // the whole meter shows the tide's tooltip (tooltip.dart)
    }
    final bars = _img('ui_bars.png');
    final bar = Rect.fromLTWH(panel.left + 3 * pad + icon + waveW + tideW, (y - 2.5 * k).roundToDouble(), barW, 5 * k);
    c.drawImageRect(bars, const Rect.fromLTWH(1, 15, 5, 5), Rect.fromLTWH(bar.left, bar.top, 5 * k, bar.height), _px);
    c.drawImageRect(bars, const Rect.fromLTWH(6, 15, 24, 5), Rect.fromLTRB(bar.left + 5 * k, bar.top, bar.right - k, bar.bottom), _px);
    c.drawImageRect(bars, const Rect.fromLTWH(30, 15, 1, 5), Rect.fromLTRB(bar.right - k, bar.top, bar.right, bar.bottom), _px);
    if (!on || total == 0) return; // between waves: the coming wave's number, the bar empty
    // The inside (3 px tall, from the checkered end to the right edge) fills a whole sprite px at a time:
    // red with a gold leading edge while monsters come, all gold once the wave is out.
    final done = g.queue.isEmpty, n = ((_meterLen - 6) * g.waveSpawned / total).round();
    final fill = Rect.fromLTWH(bar.left + 5 * k, bar.top + k, n * k, 3 * k);
    c.drawImageRect(bars, done ? _meterGold : _meterRed, fill, _px);
    if (!done && n > 0) c.drawImageRect(bars, _meterGold, Rect.fromLTWH(fill.right - k, fill.top, k, fill.height), _px);

    _text(c, '${g.waveSpawned}/$total', Offset(bar.right + pad, y), size: ts, color: done ? const Color(0xFFFEE761) : Colors.white);
  }
}
