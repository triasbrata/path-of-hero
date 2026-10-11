part of 'main.dart';

// A short message window ([Board.showMessage]), e.g. why something was refused: cream lines (one per `\n`, and a line
// too wide for the screen broken at its spaces) in
// the pack's wooden crate (the tooltips' [_crate]: dark, so it reads over the field and the book's pages
// alike), popping in over the field. It closes on the next press (a press on it does nothing else) or
// after [_messageTime] (a one-time note, [Game.limitNotes]: [_noteTime]).

const _messageTime = 2.0, _noteTime = 8.0;

/// The least room the window leaves to the screen's edges either side, px: a longer line breaks at its spaces.
const _messageMargin = 8.0;

/// The message window's state between frames.
class _Message {
  String? text; // showing while set
  double since = 0; // on the screen clock
  double time = _messageTime; // how long it shows
  Rect at = Rect.zero; // where it was last drawn
  bool tapped = false; // the last press landed on it: its tap up and drag stay there

  /// A press closes the window. True when it landed on it: then it does nothing else.
  bool down(Offset p) {
    final on = text != null && at.contains(p);
    text = null;
    return tapped = on;
  }
}

extension on Board {
  void _messageBox(Canvas c) {
    final m = _msg, text = m.text, age = _clock - m.since;
    if (text == null) return;
    if (age > m.time) {
      m.text = null;
      return;
    }
    const k = 2.0, inL = 11 * k + 6, inT = 12 * k + 4; // inside the crate's posts and bars
    final u = math.min(1.0, math.min(size.x / 600, size.y / 540)), font = 20 * u;
    final room = size.x - 2 * (_messageMargin + inL); // a line wider than the screen breaks at its spaces (a phone)
    final lines = [for (final l in text.split('\n')) ..._wrap(l, font, room)];
    final lineH = font * 1.25, paint = TextPaint(style: hudStyle(font));
    final w = lines.map((l) => paint.getLineMetrics(l).width).reduce(math.max) + inL * 2;
    final box = Rect.fromCenter(center: Offset(size.x / 2, size.y * 0.3), width: w, height: font + (lines.length - 1) * lineH + inT * 2);
    m.at = box;
    c.save();
    c.translate(box.center.dx, box.center.dy);
    c.scale(math.min(1.0, 0.6 + age / 0.12 * 0.4)); // pops in
    final local = box.shift(-box.center);
    c.drawRect(local.shift(const Offset(0, 5)).deflate(3), Paint()..color = Colors.black.withValues(alpha: 0.3));
    _nine(c, _crate, local, k, l: 13, t: 12, r: 11, b: 13);
    for (final (i, line) in lines.indexed) {
      _text(c, line, Offset(0, (i - (lines.length - 1) / 2) * lineH), size: font, color: const Color(0xFFFFF1D6), anchor: Anchor.center);
    }
    c.restore();
  }
}
