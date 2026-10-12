part of 'main.dart';

// Pausing (docs/ui-hud.md "Pause"; #93, the owner: "popup jeda itu di remove aja di buat hover layar baru di atasnya
// ada tulisan "Pause" atau ketika buka tas maka otomatis game jadi ke pause, kalau window tidak focus juga game tetap
// berjalan"). The Start/Pause toggle (start_button.dart; decisions-log 220), Esc or P pause the game ([Game.paused]:
// its tick does nothing) and resume it. While
// paused the field is dimmed with "Pause" at its top centre, and that is all: the HUD and the book still take taps,
// drags and tooltips, so troops are bought and placed and loot is given while the game waits. Opening the book
// mid-wave pauses it too ([_bookPauses]), and shutting it resumes the game when the book paused it. On the desktop the
// window losing its focus or hiding pauses nothing: hidden, Flutter draws no frames, so a timer runs the game meanwhile
// ([_runHidden]). A phone's app going to the background pauses the game, and it stays paused when the player comes
// back ([TdGame.lifecycleStateChange]; decisions-log 146, [pauseInBackgroundOnMobile]); its sound holds meanwhile
// (decisions-log 147, [muteInBackgroundOnMobile]). The field's own animations stop while paused, and the music plays
// quieter.

/// ui_icons.png's small white dash (its visible pixels): two of them stood up are the pause sign.
const _pauseDash = Rect.fromLTWH(129, 40, 14, 5);

/// The game widget's keyboard focus (Esc / P). A text field (the name panel's) takes it; a press on the
/// game gives it back.
final _gameFocus = FocusNode(debugLabel: 'game');

/// The pause's state between frames.
class _Pause {
  double since = 0; // when the game was paused, on the screen clock: "Pause" pops in
  double still = 0; // screen time spent paused: the field's clock stops ([Board._fieldClock])
  bool byBook = false; // the book paused the game ([Board._bookPauses]): the book shutting resumes it
  bool book = false; // [Board._bookPauses] as it was last frame: the game pauses or resumes when it changes
  Rect title = Rect.zero; // "Pause", where it was last drawn (none: not paused)
}

extension on Board {
  /// The field's animation clock: the screen clock without the time spent paused.
  double get _fieldClock => _clock - _pause.still;

  /// Whether the book wants the game paused (#93): a wave is on and the player opened the book by hand (the book
  /// button in the top left row; whichever page it shows). Between waves it pauses nothing, and the auto start's
  /// countdown waits on Tas, a Town's pages and Settings instead ([Board.update]).
  bool get _bookPauses => state.waveActive && _bookOpened;

  /// Pauses the game; not on the welcome screen or after a game over. [byBook]: the book did ([_bookPauses]), so
  /// its shutting resumes the game.
  void _pauseGame({bool byBook = false}) {
    final g = state;
    if (welcome != null || g.over || g.paused) return;
    g.paused = true;
    _pause
      ..since = _clock
      ..byBook = byBook;
  }

  void _resume() {
    state.paused = false;
    _pause.byBook = false;
  }

  void _togglePause() => state.paused ? _resume() : _pauseGame();

  /// Pauses the game as the player's own pause, even one the book made: the book shutting or turning back to Army
  /// doesn't resume it, only the Start/Pause toggle, Esc or P do.
  void _ownPause() {
    _pauseGame();
    _pause.byBook = false;
  }

  /// Menu Utama during a wave: the game waits paused behind the welcome screen as the player's own pause, so
  /// "Continue" comes back to it paused.
  void _menuPause() {
    if (state.waveActive) _ownPause();
  }

  /// A key: a guide card takes its own first (coach.dart: Space, Enter and the arrows turn its pages, Esc closes it, P
  /// does nothing, so the game under it doesn't pause; on the welcome screen too). Else Esc or P: closes a foe skill's
  /// splash (foe_splash.dart) or a new Hero's, else Esc puts back the loot in hand (drop_popup.dart), else pauses or
  /// resumes. True when it did something.
  bool _pauseKey(LogicalKeyboardKey key) {
    if (_coachKey(key)) return true;
    if (_wipeAskKey(key)) return true; // Enter tries again, Esc gives up after a wipe (wipe_ask.dart)
    if (_foeSplashKey(key)) return true; // Esc or P closes a foe skill's splash, and P doesn't pause (foe_splash.dart)
    if (key != LogicalKeyboardKey.escape && key != LogicalKeyboardKey.keyP) return false;
    if (welcome != null || state.over) return false;
    if (_herald.who != null) {
      _heraldClose();
      return true;
    }
    if (key == LogicalKeyboardKey.escape && _held != null) {
      _putBack();
      return true;
    }
    _togglePause();
    return true;
  }

  /// Every frame: the book pausing the game as [_bookPauses] turns on, and resuming it as it turns off if the book
  /// paused it; the field's clock stopped while paused; the music quieter while paused, but on the Settings page,
  /// where its volume is set.
  void _whilePaused(double dt) {
    final g = state;
    if (welcome == null && !g.over && _bookPauses != _pause.book) {
      _pause.book = !_pause.book;
      if (_pause.book) {
        _pauseGame(byBook: true);
      } else if (_pause.byBook) {
        _resume();
      }
    }
    if (!g.paused) _pause.byBook = false; // resumed some other way, or another game came in
    Sounds.duck(g.paused && welcome == null && _page != _Page.settings);
    if (g.paused) _pause.still += dt;
  }

  /// A press: the keys' focus back from a text field.
  void _pauseDown() {
    if (_score.naming == null && !_gameFocus.hasFocus) _gameFocus.requestFocus();
  }

  /// While paused: the field dimmed, and "Pause" in the score screens' gold title at its top centre
  /// ([_pauseTitleAt]), popping in. Drawn over the field and under the HUD, which stays lit and takes taps, drags
  /// and tooltips as ever.
  void _pauseOverlay(Canvas c) {
    _pause.title = Rect.zero;
    if (!state.paused || state.over) return;
    c.drawRect(Rect.fromLTWH(0, 0, size.x, size.y), Paint()..color = Colors.black.withValues(alpha: 0.35));
    final at = _pause.title = _pauseTitleAt(_screenScale(Size(size.x, size.y)));
    c.save();
    c.translate(at.center.dx, at.center.dy);
    c.scale(math.min(1.0, 0.6 + (_clock - _pause.since) / 0.12 * 0.4)); // pops in
    _title(c, 'Pause', Offset.zero, at.height / 44);
    c.restore();
  }

  /// Where "Pause" goes, as big as the score screens' titles at [u] (44·u): centred at the top of the field, 4 px under
  /// the top band (its rows, the toggle, Auto and the wave meter, and the "Chest!" chip under the toggle); lower where
  /// the minimap or the boss bars hang over the middle; beside the book's tabs where they would reach it (left or right
  /// of their row, whichever keeps it nearer the middle; decisions-log 301, where they spread wider at 915×412), and
  /// smaller where the book would come up to it (915×412). From last frame's HUD: the title is drawn before it.
  Rect _pauseTitleAt(double u) {
    final top = [_meterBottom, _toggleAt.bottom, _autoAt.bottom, _chest.chip.bottom].reduce(math.max) + 4;
    var h = 44 * u;
    if (!_bookArea.isEmpty) h = math.max(20.0, math.min(h, _bookHigh - 4 - top));
    final w = _textWidth('Pause', h);
    var r = Rect.fromLTWH(((size.x - w) / 2).roundToDouble(), top, w, h);
    for (final over in [_map.at, _bossAt]) {
      if (r.overlaps(over)) r = r.shift(Offset(0, over.bottom + 4 - r.top));
    }
    // The tabs' row, 8 px round (the book bobs, and the open one is taller): over it, the title goes beside it, on the
    // side nearer the screen's middle where it fits on the screen.
    if (_tabAt.isEmpty) return r;
    final row = _tabAt.values.map((t) => t.inflate(8)).reduce((a, b) => a.expandToInclude(b));
    if (!r.overlaps(row)) return r;
    final left = r.shift(Offset(row.left - r.right, 0)), right = r.shift(Offset(row.right - r.left, 0)), mid = size.x / 2;
    return left.left >= 0 && (left.center.dx - mid).abs() <= (right.center.dx - mid).abs() ? left : right;
  }
}

/// How often the game is run while the window is hidden (about 30 times a second), and how much time one run
/// catches up at most, in steps of [_behindStepMax] (the tick's own cap, [Board.update]).
const _behindEvery = Duration(microseconds: 1000000 ~/ 30), _behindMost = 0.5, _behindStepMax = 0.1;

// The window hidden (#93; the owner: "kalau window tidak focus juga game tetap berjalan"). macOS tells the app it is
// hidden when none of its windows shows (minimized, covered, another Space, Cmd-H: FlutterEngine.mm's
// handleDidChangeOcclusionState). Flutter then draws no frames (SchedulerBinding.handleAppLifecycleStateChanged:
// frames off for hidden and paused), and Flame's loop is a Ticker on those frames, so the game would stand still. A
// timer runs its update meanwhile, nothing drawn; the frames' own updates are dropped while it runs
// ([TdGame.update]), and when frames come back it stops and the loop starts over, so no time counts twice. Flame's
// own pause on hiding (pauseWhenBackgrounded) is off there. On a phone it is on (decisions-log 146): the game pauses
// ([Board._ownPause]) and Flame stops its loop until the app comes back, and no timer runs.
extension on TdGame {
  /// The app's lifecycle changed to [state]: with frames off (hidden, paused) a timer runs the game every
  /// [_behindEvery], by the real time since its last run (the periodic timer's ticks count the periods gone by, a
  /// late one's too), [_behindMost] at most, in steps of [_behindStepMax]; x2, the pause and the auto start's
  /// countdown work as ever in [Board.update]. Frames back (inactive, resumed): it stops.
  void _runHidden(AppLifecycleState state) {
    final hidden = !WidgetsBinding.instance.framesEnabled &&
        (state == AppLifecycleState.hidden || state == AppLifecycleState.paused);
    if (!hidden) return _stopBehind();
    if (_behind != null) return;
    var last = 0;
    _behind = async.Timer.periodic(_behindEvery, (t) {
      if (WidgetsBinding.instance.framesEnabled) return _stopBehind(); // the frames run it again
      var left = math.min((t.tick - last) * _behindEvery.inMicroseconds / 1e6, _behindMost);
      last = t.tick;
      _behindStep = true;
      try {
        while (left > 1e-9) {
          final step = math.min(left, _behindStepMax);
          update(step);
          left -= step;
        }
      } finally {
        _behindStep = false;
      }
    });
  }

  /// Stops the timer running the game while hidden, if it runs; and, when [restart], starts the loop over, so its
  /// first frame doesn't count the hidden time again (its Ticker kept the last frame's time).
  void _stopBehind({bool restart = true}) {
    final t = _behind;
    if (t == null) return;
    t.cancel();
    _behind = null;
    if (!restart) return;
    pauseEngine();
    resumeEngine();
  }
}
