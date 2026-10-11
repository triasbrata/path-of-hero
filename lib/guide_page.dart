part of 'main.dart';

// The book's "How to Play" page (docs/ui-hud.md "How to Play page"; the guide: "Guide"), opened by "How to Play" on
// Settings' left page, whose tab stays the open one meanwhile. It is the Licenses page's twin (licence_page.dart):
// the same scrolled columns of paragraphs ([_Column], [_Para]), row list, wheel, drag and tap UP.
// - The left page: the guide's topics ([GuideText.topics]), a row each, the open one lit; a tap UP opens another. Under
//   them "Back" to Settings.
// - The right page: the open topic's title, then its words: each intro page and card it repeats, word for word, under
//   its title (a page's lines joined: they were broken for the card's width); its own lines, a sentence a paragraph;
//   then the game's own texts it lists ([GuideLive]: every item's, every small relic's, the Epic and Rare Pusaka's),
//   read from the game as its tooltips are, so they never drift. Under them "Replay guide" plays the intro again over
//   the page; the seen set stays as it is (the one-time cards don't come back: their words are all here).

/// The How to Play page between frames.
class _GuideView {
  int topic = 0; // the open topic, an index into [GuideText.topics]: the first at launch, the last one opened after
  final topics = _Column(), text = _Column(); // the left page's list (only its scroll and place) and the right page's words
  final rows = <(Rect, int)>[]; // the topics' rows this frame, clipped: a tap UP opens one (a drag scrolls)
  Rect button = Rect.zero, back = Rect.zero, replay = Rect.zero; // Settings' "How to Play", "Back", "Replay guide"

  void clear() {
    topics
      ..list = Rect.zero
      ..shown.clear();
    text
      ..list = Rect.zero
      ..shown.clear();
    rows.clear();
    button = back = replay = Rect.zero;
  }
}

extension on Board {
  /// Opens the How to Play page from Settings: on the topic open last, its words from the top.
  void _openGuidePage() {
    _open(_Page.guide);
    _guide.text.reset();
  }

  /// A tap UP on a topic's row opens it, its words from the top; true when it hit one.
  bool _guideTap(Offset p) {
    for (final (r, i) in _guide.rows) {
      if (r.contains(p)) {
        if (i != _guide.topic) _guide.text.reset();
        _guide.topic = i;
        Sounds.play(Sfx.click);
        return true;
      }
    }
    return false;
  }

  /// The How to Play pages.
  void _guidePages(Canvas c, Rect left, Rect right, double ts, double btnH) {
    const ink = Color(0xFF4A2C17);
    final gap = 8 * ts, fs = math.max(10.0, 13 * ts), gv = _guide, labels = guideEn.labels, topics = guideEn.topics;
    _text(c, labels.howTo, Offset(left.center.dx, _titleY(left, ts)), size: 22 * ts, color: ink, anchor: Anchor.center, bold: true);
    // Left: the topics, "Back" under them.
    final back = gv.back = Rect.fromLTRB(left.left, left.bottom - btnH, left.right, left.bottom);
    _button(c, back, () => _open(_Page.settings), label: labels.back, size: 18 * ts);
    gv.topics.list = Rect.fromLTRB(left.left, _underTitle(left, ts), left.right, back.top - gap);
    gv.rows.addAll(_rowList(c, gv.topics, [for (final t in topics) t.title], fs, ts, lit: gv.topic));

    // Right: the open topic's title (shrunk to fit), its words, "Replay guide" under them.
    final topic = topics[gv.topic];
    final titleFs = math.min(18 * ts, 18 * ts * right.width / _textWidth(topic.title, 18 * ts, bold: true));
    _text(c, topic.title, Offset(right.center.dx, _titleY(right, ts)), size: titleFs, color: ink, anchor: Anchor.center, bold: true);
    final replay = gv.replay = Rect.fromLTRB(right.left, right.bottom - btnH, right.right, right.bottom);
    final replayFs = math.min(18 * ts, 18 * ts * (replay.width - 16 * ts) / _textWidth(labels.replay, 18 * ts));
    _button(c, replay, () => _coachOpen(guideIntro), label: labels.replay, size: replayFs); // coach.dart
    gv.text.list = Rect.fromLTRB(right.left, _underTitle(right, ts), right.right, replay.top - gap);
    // Laid out once a topic (licence_page.dart): I7's line as the pointer is then (a mouse's or a finger's).
    _column(c, gv.text, topic.title, () => _topicParas(state, topic, touch: _touch), fs, ts);
  }
}

/// [topic]'s words on the How to Play page: each page it repeats under its title (a title once when pages share it, as
/// K5's two), the page's lines in one paragraph; after a rule its own lines, a paragraph a sentence; after a rule
/// the game's texts it lists ([_liveParas], from [g]). I7's third line as the player's pointer has it ([touch]).
Iterable<_Para> _topicParas(Game g, GuideTopic topic, {required bool touch}) sync* {
  String? title;
  for (final page in guideEn.pagesOf(topic)) {
    if (page.title != title) yield _para(title = page.title, head: true);
    yield _para(page.linesFor(touch: touch).join(' '));
  }
  if (topic.lines.isNotEmpty) {
    if (title != null) yield _rule;
    var sentence = <String>[];
    for (final line in topic.lines) {
      sentence.add(line);
      if (RegExp(r'[.!?]$').hasMatch(line)) {
        yield _para(sentence.join(' '));
        sentence = [];
      }
    }
    if (sentence.isNotEmpty) yield _para(sentence.join(' '));
  }
  if (topic.live case final live?) {
    yield _rule;
    yield* _liveParas(g, live);
  }
}

/// The game's own texts [live] lists, read from [g] as the tooltips read them: every item's ([Game.itemEffect], as
/// the Shop's card), every small relic's ([Game.relicEffect] and its slots' line), or the Epic and Rare Pusaka's (at
/// one star, with their rarity; the Legenda are left to be found). Each one's name in bold, its lines under it; a line
/// all of them have is said once, before them.
Iterable<_Para> _liveParas(Game g, GuideLive live) sync* {
  final entries = switch (live) {
    GuideLive.items => [for (final item in g.itemsInPlay) (itemNames[item]!, g.itemEffect(item))],
    GuideLive.relics => [for (final r in g.relicsInPlay) (relicNames[r]!, [...g.relicEffect(r), relicSlotsLine])],
    GuideLive.pusaka => [
        for (final r in Relic.values)
          if (r.pusaka && r.rarity != Rarity.legenda) ('${relicNames[r]} (${rarityNames[r.rarity]})', g.relicEffect(r, stars: 1)),
      ],
  };
  final shared = [for (final l in entries.first.$2) if (entries.every((e) => e.$2.contains(l))) l];
  for (final l in shared) {
    yield _para(l);
  }
  for (final (name, lines) in entries) {
    yield _para(name, bold: true);
    for (final l in lines) {
      if (!shared.contains(l)) yield _para(l, indent: 1);
    }
  }
}
