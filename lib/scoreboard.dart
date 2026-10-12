part of 'main.dart';

// The score's screens (docs/scoreboard.md): at a game over the score goes to the board ([ScoreRepository],
// scores.dart) under the player's name, asked once in a name panel whose text field is a Flame overlay
// ([_NameField]); the game-over screen shows the score with "Scoreboard" and "Play again"; "Scoreboard" (there
// and on the welcome screen) shows the best [_boardRows]. A server that can't be reached is told by
// [Board.showMessage], and the board then shows this device's scores.

const _boardRows = 10;

/// The name panel's text field, in [main]'s `overlayBuilderMap`.
const _nameOverlay = 'name';

/// Everything shrinks on small screens, like the welcome screen: 1 down from 600×540.
double _screenScale(Size s) => math.min(1.0, math.min(s.width / 600, s.height / 540));

/// The name panel's parchment, its text field and its OK button, and the screen scale: shared by the
/// canvas ([Board._namePanel]) and the overlay ([_NameField]), so the text field sits in its box. High on
/// the screen, clear of a phone's keyboard.
(Rect, Rect, Rect, double) _nameLayout(Size s) {
  final u = _screenScale(s);
  final panel = Rect.fromCenter(center: Offset(s.width / 2, s.height * 0.3), width: 440 * u, height: 230 * u);
  final field = Rect.fromCenter(center: Offset(panel.center.dx, panel.top + 114 * u), width: 320 * u, height: 52 * u);
  final ok = Rect.fromCenter(center: Offset(panel.center.dx, panel.top + 178 * u), width: 160 * u, height: 48 * u);
  return (panel, field, ok, u);
}

/// The score's state on [Board].
class _Scores {
  final repo = scoreRepository();
  String? player = loadPlayerName(); // asked once, at the first game over
  Game? ended; // the finished game already handled
  Game? naming; // the finished game waiting for the player's name: the name panel shows
  final name = TextEditingController();
  ScoreEntry? mine; // this device's last entry, lit on the board
  Future<void> sending = Future.value(); // its submit (never throws); the board loads after it
  _BoardView? view; // the board while it shows
}

/// One opening of the board.
class _BoardView {
  List<ScoreEntry>? entries; // null while loading
}

extension on Board {
  /// [g] is over: its score goes to the board once, after the player's name when it isn't known yet.
  void _gameEnded(Game g) {
    final s = _score;
    if (identical(s.ended, g)) return;
    s.ended = g;
    if (s.player != null) return _submit(g);
    s.naming = g;
    s.name.clear();
    _showNameField(true);
  }

  /// Adds or removes the name field overlay, after the frame: [update] also runs inside the game widget's
  /// build, where the overlays can't change.
  void _showNameField(bool on) => async.scheduleMicrotask(() => game.overlays.setActive(_nameOverlay, active: on));

  /// The name panel's OK (or Enter in its field): the name is kept (player.json) and the score sent.
  void _nameDone() {
    final s = _score, g = s.naming;
    if (g == null) return;
    final name = ScoreEntry.cleanName(s.name.text);
    s.player = name;
    try {
      savePlayerName(name);
    } catch (_) {
      // not kept: it is asked again after the next launch
    }
    s.naming = null;
    _showNameField(false);
    _submit(g);
  }

  void _submit(Game g) {
    final s = _score, e = ScoreEntry.of(g, s.player ?? ScoreEntry.defaultName);
    s.mine = e;
    s.sending = () async {
      try {
        await s.repo.submit(e);
        if (s.repo.offline && identical(state, g)) showMessage('Server not available'); // kept on this device
      } catch (error) {
        debugPrint('Score not saved: $error');
        if (identical(state, g)) showMessage('Score not saved');
      }
    }();
  }

  /// Opens the board: the best entries once the last score is in.
  Future<void> _openBoard() async {
    final s = _score, v = _BoardView();
    s.view = v;
    try {
      await s.sending;
      v.entries = await s.repo.top(limit: _boardRows);
      if (s.repo.offline && identical(s.view, v)) showMessage('Server not available'); // this device's scores
    } catch (_) {
      v.entries = const [];
    }
  }

  /// The game-over screen: the wave and the score, "Scoreboard" and "Play again" (a fresh game, the save
  /// deleted). Hidden while the name panel or the board covers it.
  void _gameOver(Canvas c, Game g) {
    if (_score.naming != null || _score.view != null) return;
    final u = _screenScale(Size(size.x, size.y)), mid = Offset(size.x / 2, size.y / 2);
    c.drawRect(Offset.zero & Size(size.x, size.y), Paint()..color = Colors.black.withValues(alpha: 0.35)); // light enough to see the monsters cheer
    _text(c, 'GAME OVER  -  Wave ${g.waveReached}', mid - Offset(0, 64 * u), size: 36 * u, anchor: Anchor.center);
    _text(c, 'Score ${g.score}', mid - Offset(0, 14 * u), size: 30 * u, color: const Color(0xFFFFD65A), anchor: Anchor.center,
        outline: const Color(0xFF3C1E0A));
    final top = mid.dy + 30 * u, h = 44 * u, gap = 8 * u;
    _button(c, Rect.fromLTWH(mid.dx - gap - 180 * u, top, 180 * u, h), _openBoard, label: Words.scoreboard, size: 20 * u);
    _button(c, Rect.fromLTWH(mid.dx + gap, top, 140 * u, h), () {
      clearSave();
      state = Game().boardRules();
    }, label: 'Play again', size: 20 * u);
  }

  /// The name panel or the board, over the game-over or welcome screen: only their buttons take taps.
  void _scoreScreens(Canvas c) {
    final s = _score;
    if (s.naming == null && s.view == null) return;
    _hits.clear();
    _cards.clear();
    _slots.clear();
    _relicSlots.clear();
    _matSlots.clear();
    _pocketCells.clear();
    _tip.rows.clear();
    c.drawRect(Offset.zero & Size(size.x, size.y), Paint()..color = Colors.black.withValues(alpha: 0.45));
    if (s.naming != null) return _namePanel(c);
    _scoreBoard(c, s.view!);
  }

  /// The welcome screen's parchment, with its shadow.
  void _sheet(Canvas c, Rect panel, double u) {
    c.drawRect(panel.shift(Offset(0, 8 * u)).deflate(4 * u), Paint()..color = Colors.black.withValues(alpha: 0.25));
    _nine(c, _parchment, panel, math.max(2.0, (4 * u).floorToDouble()), l: 8, t: 8, r: 8, b: 8);
  }

  void _title(Canvas c, String t, Offset at, double u) =>
      _text(c, t, at, size: 44 * u, color: const Color(0xFFFFD65A), anchor: Anchor.center, outline: const Color(0xFF3C1E0A), bold: true);

  /// "Name", the box the text field overlay ([_NameField]) types in, and OK.
  void _namePanel(Canvas c) {
    final (panel, field, ok, u) = _nameLayout(Size(size.x, size.y));
    _sheet(c, panel, u);
    _title(c, 'Name', Offset(panel.center.dx, panel.top + 52 * u), u);
    _card(c, field, Board._framePlain);
    _button(c, ok, _nameDone, row: Board._btnGreen, label: 'OK', size: 24 * u);
  }

  /// "Scoreboard": rank, name, score and wave of the best [_boardRows], this device's last entry lit (and
  /// under them when it isn't among them), and "Back".
  void _scoreBoard(Canvas c, _BoardView v) {
    const ink = Color(0xFF4A2C17), gold = Color(0xFF9A5B00);
    final u = _screenScale(Size(size.x, size.y));
    final panel = Rect.fromCenter(center: Offset(size.x / 2, size.y / 2), width: 520 * u, height: 500 * u);
    _sheet(c, panel, u);
    _title(c, Words.scoreboard, Offset(panel.center.dx, panel.top + 54 * u), u);
    final rankX = panel.left + 82 * u, nameX = panel.left + 98 * u, scoreX = panel.left + 386 * u, waveX = panel.right - 50 * u;
    final rowH = 26 * u, font = 18 * u, first = panel.top + 134 * u; // the first row's middle
    void line(String rank, String name, String score, String wave, double y, Color color, [double? s]) {
      if (rank.isNotEmpty) _text(c, rank, Offset(rankX, y), size: s ?? font, color: color, anchor: Anchor.centerRight);
      _text(c, name, Offset(nameX, y), size: s ?? font, color: color);
      _text(c, score, Offset(scoreX, y), size: s ?? font, color: color == ink ? gold : color, anchor: Anchor.centerRight);
      _text(c, wave, Offset(waveX, y), size: s ?? font, color: color, anchor: Anchor.centerRight);
    }

    void entry(String rank, ScoreEntry e, double y) {
      if (e == _score.mine) {
        final r = Rect.fromLTRB(panel.left + 38 * u, y - rowH / 2, panel.right - 38 * u, y + rowH / 2);
        _card(c, r, Board._frameLit);
        c.drawRect(r.deflate(3), Paint()..color = const Color(0xA0FFF4DC)); // a light band inside the frame
      }
      line(rank, e.name, '${e.score}', '${e.wave}', y, ink);
    }

    line('', 'Name', 'Score', 'Wave', panel.top + 104 * u, ink.withValues(alpha: 0.6), 16 * u); // nothing over the ranks
    c.drawRect(Rect.fromLTRB(panel.left + 44 * u, panel.top + 116 * u, panel.right - 44 * u, panel.top + 117 * u),
        Paint()..color = ink.withValues(alpha: 0.3));
    final list = v.entries, mid = Offset(panel.center.dx, first + rowH * 4);
    if (list == null) {
      _text(c, 'Loading...', mid, size: font, color: ink.withValues(alpha: 0.6), anchor: Anchor.center);
    } else if (list.isEmpty) {
      _text(c, 'No scores yet', mid, size: font, color: ink.withValues(alpha: 0.6), anchor: Anchor.center);
    }
    for (final (i, e) in (list ?? const <ScoreEntry>[]).indexed) {
      entry('${i + 1}', e, first + i * rowH);
    }
    if (_score.mine case final m? when list != null && !list.contains(m)) entry('-', m, first + _boardRows * rowH + 6 * u);

    final back = Rect.fromCenter(center: Offset(panel.center.dx, panel.bottom - 46 * u), width: 200 * u, height: 48 * u);
    _button(c, back, () => _score.view = null, label: Words.back, size: 24 * u);
  }
}

/// The name panel's text field: a Flutter [TextField] over the box [Board._namePanel] draws, so typing
/// works on every platform (a phone gets its keyboard). A Flame overlay: above the game's own input, so a
/// press on it stays there, and one anywhere else still reaches the canvas (its OK button).
class _NameField extends StatelessWidget {
  const _NameField(this.board);

  final Board board;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
        final (_, field, _, u) = _nameLayout(box.biggest);
        const ink = Color(0xFF4A2C17);
        final style = hudStyle(26 * u, color: ink);
        return Stack(children: [
          Positioned.fromRect(
            rect: field.deflate(8 * u),
            child: MouseRegion(
              cursor: SystemMouseCursors.text,
              onEnter: (_) => board._mouse = null, // the pixel cursor would stay where it left the canvas
              // No MaterialApp here: the text field gets its Material, localizations and editing keys.
              child: Localizations(
                locale: const Locale('en'),
                delegates: const [DefaultMaterialLocalizations.delegate, DefaultWidgetsLocalizations.delegate],
                child: Material(
                  type: MaterialType.transparency,
                  child: DefaultTextEditingShortcuts(
                    child: Center(
                      child: TextField(
                        controller: board._score.name,
                        autofocus: true,
                        style: style,
                        cursorColor: ink,
                        textAlign: TextAlign.center,
                        textInputAction: TextInputAction.done,
                        autocorrect: false,
                        enableSuggestions: false,
                        maxLength: ScoreEntry.maxName,
                        buildCounter: (_, {required currentLength, required isFocused, required maxLength}) => null,
                        // No selection handles or menu: they need an Overlay, which only an app has.
                        enableInteractiveSelection: false,
                        contextMenuBuilder: null,
                        decoration: InputDecoration.collapsed(
                            hintText: ScoreEntry.defaultName, hintStyle: style.copyWith(color: ink.withValues(alpha: 0.35))),
                        onSubmitted: (_) => board._nameDone(),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ]);
      });
}
