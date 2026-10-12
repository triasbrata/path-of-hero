part of 'main.dart';

// The welcome screen, drawn by [Board] in place of the game while [Board.welcome] is set: on launch, and
// again through [Board.showWelcome]. The valley drifts by with a squad marching across it; the title sits
// on a parchment panel with "Continue" (when there is a game to go back to), "New Game" (on a device that hasn't
// seen the guide's intro, it opens over the new game: coach.dart), and side by side "Scoreboard" (scoreboard.dart)
// and "How to Play" (the guide's intro, over the welcome screen; docs/ui-hud.md "Guide"). Each button's key in
// [Board._welcomeAt] is an id that never changes with its words: 'Lanjutkan', 'Main Baru', 'Papan Skor', 'Cara Main'.

/// ui_all.png's parchment with a dark rim and curled corners (32x32, 9-sliced 8 px in).
const _parchment = Rect.fromLTWH(1064, 104, 32, 32);

/// The squad marching across in the game's formation (healer | long range | heavy melee | front melee):
/// (type, x from its rear, lane), top lanes first so lower sprites overlap higher ones.
const _squad = [
  ('archer', 26.0, 5),
  ('knight', 78.0, 5),
  ('priest', 0.0, 6),
  ('lancer', 52.0, 6),
  ('wizard', 26.0, 7),
  ('soldier', 78.0, 7),
];
const _drift = 6.0, _march = 14.0; // world units per second: the valley scrolling, the squad over it

extension on Board {
  /// The whole screen while [w] shows. Its buttons go into [_hits] like the book's, so taps and the
  /// cursor work the same.
  void _welcome(Canvas c, Welcome w) {
    _hits.clear();
    _cards.clear();
    _slots.clear();
    _relicSlots.clear();
    _matSlots.clear();
    _pocketCells.clear();
    _welcomeAt.clear();

    // The scene fills the screen in both layouts: the field and the band above it take its height.
    final s = size.y / (backdropH + fieldH), viewW = size.x / s;
    c.drawRect(Offset.zero & Size(size.x, size.y), Paint()..color = _sky); // under the scene, like the field's ground colour
    c.save();
    c.scale(s);
    c.translate(0, -fieldFoot); // framed as the field is, its front edge at the bottom (main.dart's [fieldFoot])
    _scenery(c, _clock * _drift, viewW, _clock);
    c.translate(0, backdropH);
    final rear = _clock * _march % (viewW + 130) - 100; // walks in from off the left edge, out past the right
    for (final (i, (type, x, lane)) in _squad.indexed) {
      final feet = Offset(rear + x, lane * tile + tile / 2 + 5);
      _frame(c, 'tiny_${type}_shadow.png', 0, feet);
      _frame(c, 'tiny_${type}_walk.png', (_clock * _fps).floor() + i * 3, feet); // out of step
    }
    c.restore();

    const ink = Color(0xFF4A2C17);
    final u = math.min(1.0, math.min(size.x / 600, size.y / 540)); // everything shrinks on small screens
    final saved = w.saved, btnW = 280 * u, btnH = 56 * u;
    final panel = Rect.fromCenter(
        center: Offset(size.x / 2, size.y * 0.38), width: 520 * u, height: (saved != null ? 402 : 312) * u);
    c.drawRect(panel.shift(Offset(0, 8 * u)).deflate(4 * u), Paint()..color = Colors.black.withValues(alpha: 0.25)); // lifts it off the valley
    _nine(c, _parchment, panel, math.max(2.0, (4 * u).floorToDouble()), l: 8, t: 8, r: 8, b: 8);
    _text(c, 'Path of Hero', Offset(panel.center.dx, panel.top + 64 * u), size: 64 * u,
        color: const Color(0xFFFFD65A), anchor: Anchor.center, outline: const Color(0xFF3C1E0A), bold: true);
    Rect btnAt(double top) => Rect.fromLTWH(panel.center.dx - btnW / 2, top, btnW, btnH);
    var next = btnAt(panel.top + 120 * u);
    if (saved != null) {
      _button(c, _welcomeAt['Lanjutkan'] = next, () => _play(saved), row: Board._btnGreen, label: 'Continue', size: 28 * u);
      _text(c, 'Wave ${saved.wave}', Offset(next.center.dx, next.bottom + 19 * u), size: 21 * u, color: ink,
          anchor: Anchor.center);
      next = btnAt(next.bottom + 48 * u);
    }
    // Over a game to go back to, the first tap only asks "Sure?" (Welcome.fresh). Alone, it is the green one.
    final sure = w.confirming(_clock);
    _button(c, _welcomeAt['Main Baru'] = next, () {
      if (w.fresh(_clock) case final g?) {
        _play(g);
        _introIfNew(); // coach.dart
      }
    }, row: sure ? Board._btnRed : (saved == null ? Board._btnGreen : Board._btnLight), label: sure ? Words.sure : 'New Game',
        size: 28 * u);
    // The last row split in two (a fourth button stacked would run off a 915x412 screen's top): the scoreboard, and the
    // guide's intro played over this screen (coach.dart).
    final halfW = 224 * u, gap = 16 * u, row = next.bottom + 16 * u, labels = guideEn.labels;
    Rect half(int i) => Rect.fromLTWH(panel.center.dx - gap / 2 - halfW + i * (halfW + gap), row, halfW, btnH);
    void halfButton(Rect at, String label, VoidCallback fn) =>
        _button(c, at, fn, label: label, size: math.min(28 * u, 28 * u * (halfW - 24 * u) / _textWidth(label, 28 * u)));
    halfButton(_welcomeAt['Papan Skor'] = half(0), Words.scoreboard, _openBoard);
    halfButton(_welcomeAt['Cara Main'] = half(1), labels.howTo, () => _coachOpen(guideIntro));
    _scoreScreens(c);
    _messageBox(c);
    _coachCard(c); // the intro, from "How to Play" (coach.dart)
    _cursor(c);
  }

  void _play(Game g) {
    state = g.boardRules(); // the owner's limits (decisions-log 141), for a new game and a save alike
    welcome = null;
  }
}
