part of 'main.dart';

// The book's Licenses page (decisions-log 137; docs/ui-hud.md "Licenses page"), opened by "Licenses" on Settings,
// whose tab stays the open one meanwhile. The left page: the game's licence in short and the credits
// (lib/licences.dart), with "Back" to Settings under them. The right page works like Flutter's
// showLicensePage: the packages in [LicenseRegistry] (Flutter's NOTICES, plus the native libraries
// [registerLicences] adds), one row each with how many licences it has; a tap on one shows its licences' text, and
// "All packages" goes back to the list. Each page's column scrolls with the wheel or a drag, like the Tas page's
// list. A package can hold thousands of paragraphs (ICU has over 500 licences), so a column lays out what shows and
// then a slice more each frame ([_Column.layOut]).

/// A paragraph on the Licenses page (and the How to Play page's, guide_page.dart): its text, how many steps it is
/// indented, and whether it is a heading, a name in bold at the text's size, centred, or the rule between two
/// licences (no text).
typedef _Para = ({String text, int indent, bool head, bool bold, bool centre, bool rule});

_Para _para(String text, {int indent = 0, bool head = false, bool bold = false, bool centre = false}) =>
    (text: text, indent: indent, head: head, bold: bold, centre: centre, rule: false);

const _Para _rule = (text: '', indent: 0, head: false, bold: false, centre: false, rule: true);

/// One page's scrolled column of wrapped paragraphs, between frames.
class _Column {
  double scroll = 0; // how far down, in px
  double? dragY; // a drag scrolling it: where it began (null: none)
  Rect list = Rect.zero; // where it shows this frame (Rect.zero: not)
  final shown = <String>[]; // the paragraphs drawn this frame (for tests)
  Object? _key; // what it is laid out for: its text, width and size; another starts it over
  final _laid = <(_Para, TextPainter?, double)>[]; // each paragraph laid out so far (a rule has no text), and its top
  double _height = 0;
  Iterator<_Para>? _rest; // the paragraphs still to lay out (null: all done)

  /// Lays out [paras] for [key] at [width]: at least down to a page below what shows, then [slice] more, so the
  /// scroll bar soon spans all of it.
  void layOut(Object key, Iterable<_Para> Function() paras, double width, double fs, {int slice = 60}) {
    if (key != _key) {
      _drop();
      _key = key;
      _rest = paras().iterator;
      scroll = 0;
    }
    var more = slice;
    while (_rest != null && (_height < scroll + 2 * list.height || more-- > 0)) {
      final bool next;
      try {
        next = _rest!.moveNext(); // a licence's paragraphs are parsed as they are reached
      } catch (_) {
        _rest = null; // a broken licence text ends the column there
        break;
      }
      if (!next) {
        _rest = null;
        break;
      }
      final p = _rest!.current, gap = fs * 0.6;
      if (p.rule) {
        _laid.add((p, null, _height + gap));
        _height += 2 * gap + 1;
        continue;
      }
      final inset = p.indent * fs * 1.5, w = math.max(fs * 4, width - inset);
      final tp = TextPainter(
        text: TextSpan(
            text: p.text,
            style: hudStyle(p.head ? fs * 1.2 : fs, height: 1.25, color: _ink, bold: p.head || p.bold)),
        textAlign: p.centre ? TextAlign.center : TextAlign.left,
        textDirection: TextDirection.ltr,
      )..layout(minWidth: p.centre ? w : 0, maxWidth: w);
      _laid.add((p, tp, _height));
      _height += tp.height + gap;
    }
  }

  /// How tall the column is, as far as it is laid out.
  double get height => _height;

  void _drop() {
    for (final (_, tp, _) in _laid) {
      tp?.dispose();
    }
    _laid.clear();
    _height = 0;
    _rest = null;
    _key = null;
  }

  /// Starts over at the top: the next [layOut] lays it out again.
  void reset() {
    _drop();
    scroll = 0;
  }

  static const _ink = Color(0xFF4A2C17);
}

/// The Licenses page between frames.
class _LicenceView {
  Future<void>? loading; // the registry being read: once, the first time the page opens
  List<(String, List<LicenseEntry>)>? packages; // each package and its licences, sorted by name (null: not read yet)
  String? open; // the package whose licences the right page shows (null: the list)
  final left = _Column(), right = _Column();
  final rows = <(Rect, String)>[]; // the list's rows this frame, clipped: a tap UP opens one (a drag scrolls)
  Rect button = Rect.zero, back = Rect.zero, all = Rect.zero; // Settings' "Licenses", "Back", "All packages"

  void clear() {
    left
      ..list = Rect.zero
      ..shown.clear();
    right
      ..list = Rect.zero
      ..shown.clear();
    rows.clear();
    button = back = all = Rect.zero;
  }

  /// Reads [LicenseRegistry] into [packages], grouped by package like showLicensePage. A collector that fails
  /// (none should) ends the reading there, keeping what came before it.
  Future<void> read() async {
    registerLicences();
    final by = <String, List<LicenseEntry>>{};
    try {
      await for (final e in LicenseRegistry.licenses) {
        for (final p in e.packages) {
          (by[p] ??= []).add(e);
        }
      }
    } catch (_) {}
    packages = [for (final p in by.keys.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()))) (p, by[p]!)];
  }
}

extension on Board {
  /// Opens the Licenses page from Settings: on the package list, both columns at the top.
  void _openLicences() {
    _open(_Page.licence);
    _lic
      ..open = null
      ..loading ??= _lic.read();
    _lic.left.reset();
    _lic.right.reset();
  }

  /// The book's scrolled columns: the Licenses page's two and the How to Play page's (guide_page.dart). Only the open
  /// page's are on the screen this frame (the others' [_Column.list] is Rect.zero).
  List<_Column> get _columns => [_lic.left, _lic.right, _guide.topics, _guide.text];

  /// The wheel over a column scrolls it (not where the open battle log lies over it).
  void _licenceWheel(Offset p, double dy) {
    if (_log.open && _log.panel.contains(p)) return;
    for (final col in _columns) {
      if (col.list.contains(p)) col.scroll += dy;
    }
  }

  /// A drag that began on a column scrolls it; true when it did.
  bool _licenceDrag(Offset p) {
    for (final col in _columns) {
      if (col.list.contains(p)) {
        col.dragY = p.dy;
        return true;
      }
    }
    return false;
  }

  /// A tap UP on a package row opens its licences, on a How to Play topic's row that topic ([_guideTap]); true when it
  /// hit one.
  bool _licenceTap(Offset p) {
    for (final (r, name) in _lic.rows) {
      if (r.contains(p)) {
        _lic.open = name;
        _lic.right.reset();
        Sounds.play(Sfx.click);
        return true;
      }
    }
    return _guideTap(p);
  }

  /// The Licenses pages.
  void _licencePages(Canvas c, Rect left, Rect right, double ts, double btnH) {
    const ink = Color(0xFF4A2C17), grey = Color(0xFF9E9080);
    final gap = 8 * ts, fs = math.max(10.0, 13 * ts), lic = _lic;
    _text(c, 'Licenses', Offset(left.center.dx, _titleY(left, ts)), size: 22 * ts, color: ink, anchor: Anchor.center, bold: true);
    // Left: the game's licence and the credits, "Back" under them.
    final back = lic.back = Rect.fromLTRB(left.left, left.bottom - btnH, left.right, left.bottom);
    _button(c, back, () => _open(_Page.settings), label: Words.back, size: 18 * ts);
    lic.left.list = Rect.fromLTRB(left.left, _underTitle(left, ts), left.right, back.top - gap);
    _column(c, lic.left, 'credits', _creditParas, fs, ts);

    // Right: the packages, or the open one's licences with "All packages" under them.
    final packages = lic.packages, open = lic.open;
    final title = open ?? 'Packages';
    final titleFs = math.min(18 * ts, 18 * ts * right.width / _textWidth(title, 18 * ts, bold: true));
    _text(c, title, Offset(right.center.dx, _titleY(right, ts)), size: titleFs, color: ink, anchor: Anchor.center, bold: true);
    final top = _underTitle(right, ts);
    if (packages == null) {
      _text(c, 'Loading...', Offset(right.center.dx, top + 12 * ts), size: fs, color: grey, anchor: Anchor.center);
      return;
    }
    if (open case final name?) {
      final entries = [for (final (p, e) in packages) if (p == name) ...e];
      final all = lic.all = Rect.fromLTRB(right.left, right.bottom - btnH, right.right, right.bottom);
      _button(c, all, () => lic
        ..open = null
        ..right.reset(), label: 'All packages', size: 18 * ts);
      lic.right.list = Rect.fromLTRB(right.left, top, right.right, all.top - gap);
      _column(c, lic.right, name, () => _licenceParas(entries), fs, ts);
      return;
    }
    // The list: one row a package, its name and how many licences it has; a tap UP opens it.
    final col = lic.right, list = col.list = Rect.fromLTRB(right.left, top, right.right, right.bottom);
    if (packages.isEmpty) {
      _text(c, 'No licenses', Offset(list.center.dx, list.top + 12 * ts), size: fs, color: grey, anchor: Anchor.center);
      return;
    }
    final names = [for (final (name, _) in packages) name];
    for (final (r, i) in _rowList(c, col, names, fs, ts, count: (i) => '${packages[i].$2.length}')) {
      lic.rows.add((r, names[i]));
    }
  }

  /// [names] as rows down [col]'s list, clipped and scrolled, with its scroll bar: a card each ([_rowCard]: lit under
  /// the mouse, pushed in while pressed; neither while it scrolls), the name on its left (shrunk to fit) and [count]'s
  /// text in grey on its right; the row [lit] in the lit card. Returns each row drawn, clipped to the list, and its
  /// index (the Licenses page's packages, the How to Play page's topics).
  List<(Rect, int)> _rowList(Canvas c, _Column col, List<String> names, double fs, double ts, {String Function(int i)? count, int? lit}) {
    const ink = Color(0xFF4A2C17), grey = Color(0xFF9E9080);
    final list = col.list, drawn = <(Rect, int)>[];
    final inset = math.max(3.0, 4 * ts), rowH = (2 * inset + fs * 1.4).roundToDouble(), rowGap = math.max(2.0, 3 * ts);
    final content = names.length * (rowH + rowGap) - rowGap, barW = _capsuleBarW, scrolls = content > list.height;
    col.scroll = col.scroll.clamp(0.0, math.max(0.0, content - list.height));
    c.save();
    c.clipRect(list);
    for (final (i, name) in names.indexed) {
      final r = Rect.fromLTWH(list.left, list.top + i * (rowH + rowGap) - col.scroll, list.width - (scrolls ? barW + 2 * ts : 0), rowH);
      if (r.bottom <= list.top || r.top >= list.bottom) continue;
      if (i == lit) {
        _card(c, r, Board._frameLit);
      } else if (col.dragY != null) {
        _card(c, r, Board._framePlain); // scrolling: no row lights or sinks
      } else {
        _rowCard(c, r, Board._framePlain); // lit under the mouse, pushed in while pressed
      }
      final n = count?.call(i) ?? '';
      if (n.isNotEmpty) _text(c, n, Offset(r.right - inset - 2 * ts, r.center.dy), size: fs, color: grey, anchor: Anchor.centerRight);
      final room = r.width - 3 * inset - (n.isEmpty ? 0 : _textWidth(n, fs)) - 4 * ts;
      _text(c, name, Offset(r.left + inset + 2 * ts, r.center.dy), size: math.min(fs, fs * room / _textWidth(name, fs)), color: ink);
      drawn.add((r.intersect(list), i));
      col.shown.add(name);
    }
    c.restore();
    if (scrolls) _capsuleBar(c, list, content, col.scroll);
    return drawn;
  }

  /// [col]'s paragraphs ([paras], laid out for [key]) in its list, clipped and scrolled, with its scroll bar.
  void _column(Canvas c, _Column col, Object key, Iterable<_Para> Function() paras, double fs, double ts) {
    final list = col.list, barW = _capsuleBarW;
    col.layOut((key, list.width.round(), fs), paras, list.width - barW - 2 * ts, fs);
    final content = col.height;
    col.scroll = col.scroll.clamp(0.0, math.max(0.0, content - list.height));
    c.save();
    c.clipRect(list);
    for (final (p, tp, y) in col._laid) {
      final at = list.top + y - col.scroll;
      if (at >= list.bottom) break;
      if (tp == null) {
        c.drawRect(Rect.fromLTWH(list.left, at, list.width - barW - 2 * ts, 1), Paint()..color = const Color(0x554A2C17));
        continue;
      }
      if (at + tp.height <= list.top) continue;
      tp.paint(c, Offset(list.left + p.indent * fs * 1.5, at));
      col.shown.add(p.text);
    }
    c.restore();
    if (content > list.height) _capsuleBar(c, list, content, col.scroll);
  }
}

/// The left page: the game's licence in short, then the credits (lib/licences.dart).
Iterable<_Para> _creditParas() sync* {
  yield _para('Path of Hero', head: true);
  for (final line in licenceSummary) {
    yield _para(line);
  }
  yield _para('Kredit', head: true);
  for (final c in credits) {
    yield _para('${c.role}: ${c.work}, oleh ${c.by} (${c.link})');
  }
  yield _para(ownWork);
  yield _para(madeWith);
}

/// One package's licences, as showLicensePage lays them out: each licence's paragraphs (indented, or centred),
/// a rule between two licences.
Iterable<_Para> _licenceParas(List<LicenseEntry> entries) sync* {
  for (final (i, e) in entries.indexed) {
    if (i > 0) yield _rule;
    for (final p in e.paragraphs) {
      final centre = p.indent == LicenseParagraph.centeredIndent;
      yield _para(p.text, indent: centre ? 0 : p.indent, centre: centre);
    }
  }
}
