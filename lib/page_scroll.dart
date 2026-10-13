part of 'main.dart';

// A part of a book page that scrolls where what it holds is taller than its room (decisions-log 283: the landscape book
// shorter, the owner: "buku di buat lebih pendek lagi"), as the Army detail's body does (troop_detail.dart): the wheel or a
// drag over it, the Bag's scroll bar down its right ([Board._capsuleBar]) with its lines clear of the bar, every line drawn
// clipped to it, and what takes a tap or a hover cut to it (out of it: nothing). The Smithy's facing page
// (smithy_page.dart) and the Tavern's two pages (tavern_page.dart) use it; before, they left lines out where short.

/// One such part between frames: where it shows this frame ([view]; Rect.zero: not drawn), how tall what it holds is
/// ([content]), how far it is scrolled ([scroll]; back to the top for another [of]) and a drag's last y ([dragY]).
class _PageScroll {
  Rect view = Rect.zero;
  double content = 0, scroll = 0;
  double? dragY;
  Object? of;

  /// A frame starts: not drawn until it is.
  void clear() {
    view = Rect.zero;
    content = 0;
  }

  /// Whether it is taller than its room this frame.
  bool get scrolls => content > view.height + 1e-9;
}

/// How long the lists a page's drawing adds to were before it drew a scrolling part ([Board._scrollBegin]): the taps on
/// tap down, the tooltips' hints and rows, the action rows' taps and the action rows kept for tests, and the action
/// list's rect.
typedef _ScrollMarks = ({int hits, int hints, int tips, int rows, int actions, Rect list});

extension on Board {
  /// How much narrower the lines are while [s]'s part scrolls: the scroll bar's width and a gap ([ts] the text scale).
  double _scrollBarRoom(double ts) => _capsuleBarW + (3 * ts).roundToDouble();

  /// [s] shows in [view] what is [content] tall, for [of] (another: back to the top): its scroll held in range, the clip
  /// begun. Returns where its first line goes (its top less the scroll) and the lists' marks for [_scrollEnd].
  (double, _ScrollMarks) _scrollBegin(Canvas c, _PageScroll s, Rect view, double content, Object? of) {
    if (s.of != of) {
      s
        ..of = of
        ..scroll = 0;
    }
    s
      ..view = view
      ..content = content
      ..scroll = s.scrolls ? s.scroll.clamp(0.0, content - view.height) : 0;
    c.save();
    c.clipRect(view);
    final a = _assign;
    return (view.top - s.scroll, (hits: _hits.length, hints: _tip.hints.length, tips: _tip.rows.length, rows: a.rows.length, actions: a.actions.length, list: a.list));
  }

  /// Ends [s]'s clip: what its drawing added since [m] to the taps, the tooltips and the action rows is cut to its view,
  /// and its scroll bar drawn while it scrolls.
  void _scrollEnd(Canvas c, _PageScroll s, _ScrollMarks m) {
    c.restore();
    final view = s.view;
    _cutTo(_hits, m.hits, view, (e, r) => (r, e.$2));
    _cutTo(_tip.hints, m.hints, view, (e, r) => (r, e.$2, e.$3));
    _cutTo(_tip.rows, m.tips, view, (e, r) => (r, e.$2, e.$3));
    _cutTo(_assign.rows, m.rows, view, (e, r) => (r, e.$2, e.$3, e.$4));
    final acts = _assign.actions; // kept out of view too, at Rect.zero (bag.dart)
    for (var i = m.actions; i < acts.length; i++) {
      final (act, r, ok) = acts[i];
      acts[i] = (act, _inView(r, view), ok);
    }
    if (_assign.list != m.list) _assign.list = _inView(_assign.list, view);
    if (s.scrolls) _capsuleBar(c, view, s.content, s.scroll); // bag.dart
  }

  /// Every page part that scrolls this way, for the wheel and drags.
  List<_PageScroll> get _pageScrolls => [_smithy.facing, _tavernPage.list, _tavernPage.facing, _dunPage.list];

  /// The wheel ([dy]) over a part that scrolls: down on, up back.
  void _pageScrollWheel(Offset p, double dy) {
    for (final s in _pageScrolls) {
      if (s.view.contains(p)) s.scroll += dy;
    }
  }

  /// A drag that begins on a part taller than its room scrolls it: true when one took it.
  bool _pageScrollDragStart(Offset p) {
    for (final s in _pageScrolls) {
      if (s.view.contains(p) && s.scrolls) {
        s.dragY = p.dy;
        return true;
      }
    }
    return false;
  }

  /// The drag moved [dy] (down: back up the part).
  void _pageScrollDragBy(double dy) {
    for (final s in _pageScrolls) {
      if (s.dragY != null) s.scroll -= dy;
    }
  }

  /// The drag ended.
  void _pageScrollDragEnd() {
    for (final s in _pageScrolls) {
      s.dragY = null;
    }
  }
}
