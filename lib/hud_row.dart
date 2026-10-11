part of 'main.dart';

// The rest of the top band (#80's re-layout, the owner: "gold, x2 dan pause di pindah ke kiri"; decisions-log 220, the
// owner: "hud uang dan darah di jadikan 1 container", "auto button jangan di pindah pindah taruh di samping wave saja
// terus. sekalian di pindah posisi btn speed, jadi layoutnyaa seperti btn speed _ btn auto _ wave meter"):
// - the top left: after the troop counter, the hearts and the gold on one dark panel, then, during a wave, the button
//   that opens the book;
// - the top right: x2 and Auto left of the wave meter, the same in every state;
// - the top centre: the Start/Pause toggle (start_button.dart).
// All as tall as the counter (Auto and the toggle as [_startH]), 2·k apart.

extension on Board {
  /// Draws the hearts and the gold on one panel right of the troop counter's [counter] panel, then during a wave the book
  /// button after the panel. Sets [_heartsGoldAt], [_livesAt] (its hearts' part), [_goldAt] (its gold's part) and
  /// [_bookBtnAt].
  void _hudRow(Canvas c, Game g, Rect counter) {
    final k = _meterK, h = _meterH, pad = 2 * k, icon = 16 * (k - 1), ts = 6 * k;
    final top = _meterTop, left = counter.right + pad;

    // The hearts, then the coin and how much gold (as wide as 4 digits at least, so it doesn't twitch).
    final value = '${g.gold}';
    final lives = _livesAt = Rect.fromLTWH(left, top, pad + _heartsWidth(g) + pad, h);
    final gold = _goldAt = Rect.fromLTWH(
        lives.right, top, (pad + icon + pad + math.max(_textWidth(value, ts), _textWidth('8888', ts)) + pad).roundToDouble(), h);
    final panel = _heartsGoldAt = lives.expandToInclude(gold);
    _panel(c, panel);
    _livesHearts(c, g, lives.left + pad, panel.center.dy); // lives.dart
    _uiIcon(c, Board._icCoin, Rect.fromLTWH(gold.left + pad, gold.center.dy - icon / 2, icon, icon));
    _text(c, value, Offset(gold.left + 2 * pad + icon, gold.center.dy), size: ts, color: Colors.amber);
    if (g.over || !g.waveActive) return;

    // The pack's red book icon (ui_icons.png): opens the book mid-fight, which pauses the game, and shuts it, which
    // resumes it if the book paused it (pause.dart). A little bigger for fingers than it looks (k all round).
    void toggleBook() => _bookOpened = !_bookOpened;
    final w = math.max(h, 36.0);
    final bookBtn = _bookBtnAt = Rect.fromLTWH(panel.right + pad, top, w, h);
    final sink = _button(c, bookBtn, toggleBook, active: _bookOpened);
    _hits.add((bookBtn.inflate(k), toggleBook));
    c.drawImageRect(_img('ui_icons.png'), const Rect.fromLTWH(192, 16, 16, 16),
        Rect.fromCenter(center: bookBtn.center + Offset(0, sink - k), width: icon, height: icon), _px);
  }

  /// x2 and Auto left of the wave meter, Auto right beside it, in every state, in its band (Auto, as tall as the
  /// Start/Pause toggle, centred on it). Not after a game over (no meter then). Sets [_speedAt] and [_autoAt].
  void _speedAuto(Canvas c, Game g) {
    _speedAt = _autoAt = Rect.zero;
    final meter = _meterAt;
    if (g.over || meter.isEmpty) return;
    final k = _meterK, h = _meterH, pad = 2 * k, auto = _autoSize;
    final top = _meterTop, autoAt = Offset(meter.left - pad - auto.width, top + (h - auto.height) / 2);
    _autoToggle(c, g, autoAt); // start_button.dart
    // x2: "x1" / "x2", orange at 2, as wide as its word; a little bigger for fingers than it looks (k all round).
    final font = (h * 0.42).clamp(14.0, 28.0), bk = (h / 16).floorToDouble().clamp(1.0, 3.0);
    final w = (_textWidth('x2', font) + 2 * (4 * bk + 6)).roundToDouble();
    final speedBtn = _speedAt = Rect.fromLTWH(_autoAt.left - pad - w, top, w, h);
    void toggleSpeed() => speed = speed == 1 ? 2 : 1;
    _button(c, speedBtn, toggleSpeed, active: speed == 2, label: 'x$speed', size: font);
    _hits.add((speedBtn.inflate(k), toggleSpeed));
  }
}
