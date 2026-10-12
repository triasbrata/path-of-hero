part of 'main.dart';

// The Start/Pause toggle (decisions-log 220; the owner: "pause dan start button jadi 1 dan toggle", "tombol start/pause
// ada di tengah"): one button at the top centre in every state, where the start button was (#49: the pack's green
// button with the play icon and "Start", [Words.start]) and doing what the pause button did (#93, pause.dart):
// - between waves it starts the next wave: green, the play sign and "Start", pulsing; with Auto's countdown running,
//   "Start 5", "Start 4" …;
// - during a wave it pauses it: the light button with the pause sign;
// - while paused (by it, Esc or P, the book, the app going to the background) it resumes: orange, the play sign.
// Centred in the top band (the book stays below it; it is the sky over the field, clear of the troops). A press
// within [_toggleGuard] s of a wave starting does nothing, so a press meant for Start never lands as a pause (a double
// tap, or Auto starting the wave under a finger).
//
// Auto Wave (#68, auto_start.dart; [Words.autoWave], decisions-log 290: named apart from the spawn bar's Auto Buy) stands
// left of the wave meter in every state (hud_row.dart): while on, a won wave counts [autoStartDelay] seconds down on the
// toggle and then starts the next wave as Start does; settings.json keeps it. While the army is below 75% of its cap
// ([Game.autoHeld], decisions-log 141) the countdown holds, and a line under the toggle says why: "Army 20/36 · Auto Wave
// waits". Start still starts.
//
// In a Town (decisions-log 216, town_look.dart) its Start says "Leave town" ([Words.leaveTown]) and leaves it, through
// town_look.dart's hooks ([_startShows], [_startWord], [_startMost], [_leaveTown]); no countdown runs there, Auto or not
// (decisions-log 328): Auto Wave counts down once the Town is left. Paused in a Town it resumes, as anywhere.

/// ui_icons.png's big white arrow pointing right, the play sign: its visible pixels are 7x12 from (5, 2).
const _startIcon = Offset(144, 176);

/// It takes the pack's hover look (lighter, its face a pixel lower; button_fx.dart) [_startLitFor] s of every
/// [_startBlink] s (on the screen clock) while it starts a wave, and while the mouse is on it; it is pushed in while
/// pressed.
const _startBlink = 1.6, _startLitFor = 0.5;

/// For this long (screen seconds) after a wave starts, a press on the toggle (now a pause) does nothing.
const _toggleGuard = 0.35;

/// What the toggle does: start the next wave, pause the wave on, or resume the paused game.
enum _Toggle { start, pause, resume }

/// The toggle's state between frames: what it did last frame, and when it last turned from Start to Pause (a wave
/// began).
class _ToggleState {
  _Toggle? last;
  double since = double.negativeInfinity;
}

extension on Board {
  /// What the toggle does now (null: not drawn: after a game over, or while a Town is due but not yet gone into). Its
  /// Start is also a Town's "Leave town" ([_startShows]).
  _Toggle? _toggleOf(Game g) => g.over
      ? null
      : g.paused
          ? _Toggle.resume
          : _startShows(g)
              ? _Toggle.start
              : g.waveActive
                  ? _Toggle.pause
                  : null;

  /// Start: a book opened by hand shuts (mid-battle), and the wave starts. In a Town it leaves the Town instead (town_look.dart), starting no wave. While a
  /// boss chest waits (a boss win's cheer, before its popup opens) it opens the chest instead ([_chestNow],
  /// chest_popup.dart): no wave starts before the chest is taken or skipped (decisions-log 281).
  void _startPress(Game g) {
    if (g.inTown) return _leaveTown(g);
    if (_chestDue(g)) return _chestNow(g);
    _bookOpened = false;
    g.startWave();
  }

  /// Draws the toggle at the top centre and takes its press, k bigger all round: Start, Pause or Resume ([_toggleOf]).
  /// Sets [_toggleAt] (as drawn, whatever it does), [_startAt] while it starts a wave and [_pauseAt] while it pauses or
  /// resumes (Rect.zero otherwise).
  void _startToggle(Canvas c, Game g) {
    _toggleAt = _startAt = _pauseAt = _autoHeldAt = Rect.zero;
    final mode = _toggleOf(g), t = _toggle;
    if (mode == _Toggle.pause && t.last == _Toggle.start) t.since = _clock; // a wave began
    t.last = mode;
    if (mode == null) return;
    final h = _startH, kk = _meterK;
    final k = (h / 16).floorToDouble().clamp(1.0, 3.0); // the frame's pixels, as [_button]'s
    // The play sign as tall as inside the frame lets it (4 px of frame on top, 6 under), in whole pixels.
    final ik = math.max(1.0, ((h - 10 * k) / 12).floorToDouble());
    final font = (h * 0.42).clamp(14.0, 28.0), inset = 4 * k + 6;
    // Start keeps room for Auto's seconds while Auto is on, so it doesn't change width as they come and go; Pause and
    // Resume are square.
    final word = _startWord(g), most = _startMost(g);
    double startW(String label) => (inset + 7 * ik + 6 + _textWidth(label, font) + inset).roundToDouble();
    final w = mode == _Toggle.start ? startW(autoStart.on ? most : word) : math.max(h, 36.0);
    // Centred between the screen's safe insets, in the band; where the screen is too narrow for its widest look there (a
    // Start with Auto's seconds), it keeps that clear of x2 left of the wave meter, its middle the same in every state.
    final mid0 = (_safe.left + size.x - _safe.right) / 2, wide = startW(most), right = _speedAt.isEmpty ? double.infinity : _speedAt.left - 2 * kk;
    final x = (math.min(mid0, right - wide / 2) - w / 2).roundToDouble();
    final r = _toggleAt = Rect.fromLTWH(x, (_meterTop + (_meterH - h) / 2).roundToDouble(), w, h);
    var look = _look(r);
    if (mode == _Toggle.start && look == ButtonLook.normal && _clock % _startBlink < _startLitFor) look = ButtonLook.hover; // the pulse
    final row = switch (mode) { _Toggle.start => Board._btnGreen, _Toggle.pause => Board._btnLight, _Toggle.resume => Board._btnOrange };
    final sink = _btnFrame(c, r, row, look, k);
    final mid = r.center.dy - k + sink; // a touch up: the bottom is the button's edge
    void play(double left) => c.drawImageRect(
        _img('ui_icons.png'), _startIcon & const Size(16, 16), Rect.fromLTWH(left, (mid - 8 * ik).roundToDouble(), 16 * ik, 16 * ik), _px);
    switch (mode) {
      case _Toggle.start:
        play(r.left + inset - 5 * ik);
        final shown = autoStart.shown;
        _text(c, shown == null ? word : '$word $shown', Offset(r.left + inset + 7 * ik + 6, mid), size: font, color: const Color(0xFF3B2210));
        if (autoStart.left != null && g.autoHeld && !g.inTown) _autoHeldLine(c, g, r, font);
      case _Toggle.resume:
        play((r.center.dx - 8.5 * ik).roundToDouble()); // its visible 7x12 centred
      case _Toggle.pause:
        // The pause sign: ui_icons.png's small white dash twice, stood up (turned a quarter), 2 sprite px apart.
        final dk = h * 0.65 / _pauseDash.width, at = r.center + Offset(0, sink - 2);
        for (final dx in [-3.5 * dk, 3.5 * dk]) {
          c.save();
          c.translate(at.dx + dx, at.dy);
          c.rotate(math.pi / 2);
          c.drawImageRect(_img('ui_icons.png'), _pauseDash,
              Rect.fromCenter(center: Offset.zero, width: _pauseDash.width * dk, height: _pauseDash.height * dk), _px);
          c.restore();
        }
    }
    if (mode == _Toggle.start) {
      _startAt = r;
    } else {
      _pauseAt = r;
    }
    // A little bigger than it looks, for fingers: k all round.
    _hits.add((
      r.inflate(kk),
      () {
        // What it showed is what it does: a press that comes as it changes (Auto's countdown starting the wave under a
        // finger, a double tap on Start) does nothing.
        final now = _toggleOf(g);
        if (now != mode || (now == _Toggle.pause && _clock - t.since < _toggleGuard)) return;
        switch (now) {
          case _Toggle.start:
            _startPress(g);
          case _Toggle.pause:
            _pauseGame();
          case _Toggle.resume:
            _resume();
          case null:
        }
      }
    ));
  }

  /// Under the toggle [r], why Auto's countdown holds ([Game.autoHeld]): "Army 20/36 · Auto Wave waits", outlined over
  /// the field, kept on the screen.
  void _autoHeldLine(Canvas c, Game g, Rect r, double font) {
    final text = '${Words.army} ${g.armySize}/${g.armyCap} · ${Words.autoWave} waits', fs = font * 0.7, w = _textWidth(text, fs);
    final x = (r.center.dx - w / 2).clamp(_edgeL, math.max(_edgeL, size.x - _edgeR - w)).toDouble();
    final at = _autoHeldAt = Rect.fromLTWH(x, r.bottom + fs * 0.4, w, fs);
    _text(c, text, at.centerLeft, size: fs, color: const Color(0xFFFEE761), outline: const Color(0xFF3C1E0A));
  }

  /// How tall the toggle and the Auto button are: the band, 32 px at least.
  double get _startH => math.max(_meterH, 32.0);

  /// How big the Auto button is: as tall as the toggle, as wide as its words ([Words.autoWave]).
  Size get _autoSize {
    final h = _startH, font = (h * 0.42).clamp(14.0, 28.0), k = (h / 16).floorToDouble().clamp(1.0, 3.0);
    return Size((_textWidth(Words.autoWave, font) + 2 * (4 * k + 6)).roundToDouble(), h);
  }

  /// The Auto button, "Auto Wave", its top left [at] (left of the wave meter, hud_row.dart): orange while on (`_button`'s
  /// active look). Sets [_autoAt].
  void _autoToggle(Canvas c, Game g, Offset at) {
    final h = _startH, font = (h * 0.42).clamp(14.0, 28.0);
    _autoAt = Offset(at.dx.roundToDouble(), at.dy.roundToDouble()) & _autoSize;
    _button(c, _autoAt, () {
      autoStart.set(!autoStart.on);
      _settings.autoStart = autoStart.on;
      saveSettings(_settings);
    }, active: autoStart.on, label: Words.autoWave, size: font);
  }
}
