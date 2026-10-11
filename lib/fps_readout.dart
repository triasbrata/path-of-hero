part of 'main.dart';

// The dev FPS readout (decisions-log 308; the owner, 2026-10-09: "apakah ini bermasalah di fps dari gamenya soalnya kita
// belum ada fps counternya"). Settings' "Show FPS" (settings.json, off by default) shows, on a small dark panel at the
// field's bottom-left corner (in a Town the screen's), how many frames the last second drew and its slowest frame
// ("60 fps 17 ms"), once a second. Off, nothing is counted or drawn.

/// Frames counted a second at a time: [frame] takes each frame's time (s); once a second has gone by, [fps] and
/// [worstMs] take that second's numbers and the count starts afresh. Null [fps] until the first second is in.
class FpsMeter {
  double _time = 0, _worst = 0;
  int _frames = 0;
  int? fps;
  int worstMs = 0;

  void frame(double dt) {
    _time += dt;
    _frames++;
    _worst = math.max(_worst, dt);
    if (_time < 1) return;
    fps = (_frames / _time).round();
    worstMs = (_worst * 1000).round();
    _time = _worst = 0;
    _frames = 0;
  }

  /// Forgets what it counted ("Show FPS" turned off).
  void reset() {
    _time = _worst = 0;
    _frames = 0;
    fps = null;
    worstMs = 0;
  }

  /// What the readout says: "60 fps 17 ms"; null before the first second.
  String? get text => fps == null ? null : '$fps fps $worstMs ms';
}

/// A slowest frame from this many ms (under 30 fps) shows in the HP bar's red.
const fpsSlowMs = 34;

extension _FpsReadout on Board {
  /// A frame's time, while "Show FPS" is on ([Board.update]).
  void _fpsFrame(double dt) {
    if (_settings.showFps) _fpsMeter.frame(dt);
  }

  /// Turns "Show FPS" on or off; off forgets the count, so on again starts afresh.
  void _fpsToggle() {
    _settings.showFps = !_settings.showFps;
    _fpsMeter.reset();
    saveSettings(_settings);
  }

  /// The readout, while on and once a second is in: its text over the off-view marker's dark panel, at the field's
  /// bottom-left corner over the spawn bar's step (in a Town the screen's, over the battle log button's line), beside
  /// any panel open there (the troop counter's list, the boss bars and the Shadows' chips at the left, the off-view
  /// marker). Sets [_fpsAt].
  void _fpsReadout(Canvas c) {
    _fpsAt = Rect.zero;
    final text = _fpsMeter.text;
    if (!_settings.showFps || text == null) return;
    final k = _meterK, pad = 2 * k, font = math.max(11.0, 4 * k);
    final w = (_textWidth(text, font) + 2 * pad).roundToDouble(), h = (font + 2 * pad).roundToDouble();
    final bottom = _barShown ? _hotGeom().stepTop - pad : size.y - _edgeB;
    var r = Rect.fromLTWH(_edgeL, (bottom - h).roundToDouble(), w, h);
    for (final p in [if (_troops.open) _troops.list, if (_asideLeft) _omenRow.at, if (_bossAside) _bossAt, if (!_townShown) _offViewAt]) {
      if (p.overlaps(r)) r = r.translate(p.right + pad - r.left, 0);
    }
    _fpsAt = r;
    _panel(c, r);
    _text(c, text, Offset(r.left + pad, r.center.dy), size: font, color: _fpsMeter.worstMs >= fpsSlowMs ? const Color(0xFFE43B44) : Colors.white);
  }
}
