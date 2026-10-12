part of 'main.dart';

// The Army page's right page: the picked type's detail (decisions-log 187, its layout 218; ui-hud.md "Army"), as the owner
// asked, the list on the left and the detail on the right, and (2026-10-04) "button untuk buy dan release di taruh di
// detail kanan saja", "bingkai dan background hitam tempat sprite di takeout", attributes as "icon/short name value" over
// a short description, two to a row, and the Awaken needs one to a row, "<icon>/name filled/need how to get". From the
// top:
// 1. the header ([_detailHeader]): the idle sprite standing on the paper (no frame, no black well), at most a third of
//    the page wide; beside it the name, how many live ("x3/8") and the awakening stars and Forge, and the build name (or,
//    barred by Oath of One, why it can't join);
// 2. the body, between the header and the foot, scrolled when it is taller than its room (the Bag's scroll bar; on a
//    page too short for the body's least, [detailBodyMin], the header scrolls with it as its first lines):
//    the eight attributes as the field has them ([_detailStats]); the Awaken needs ([_detailNext]): below Awaken 3 each
//    recipe item with have/need and where it comes from, what the awakening unlocks and the green "Awaken 2 from the
//    Bag" while the bag holds it; from Awaken 3 the Shop's own Awaken / Forge tag ([Board._upgradeButton],
//    ascend_page.dart: one tap, the same buy and refusals); its Wishlist ([_detailWishlist], wishlist_look.dart,
//    decisions-log 282: its wishes, a tap to the Smithy, the picker); its Artifact ([_detailPusaka]); its Heroes
//    ([_detailHeroes]; its fallen Heroes' Recall too, [_recallLines], decisions-log 230); the relics its
//    troops wear ([_detailRelics]);
// 3. the foot ([_detailFoot]), one line on the page's bottom edge with no divider over it (decisions-log 288; the owner,
//    2026-10-09: "tidak perlu ada divider dan button relasenya di buat jangan full width containernya tapi cukup
//    sepanjang contentnya saja di kanan bawah"): at its right Release (whose first tap arms it and turns it into the red
//    confirm), the page's own action, while it shows (buying moved to the spawn bar, decisions-log 283: spawn_bar.dart);
//    at its left, between waves while someone of the last won wave can come back, the army's "Replace fallen" (#92; not
//    in a Town, decisions-log 301), each as wide as its words; Replace fallen on a line of its own over Release where
//    the two don't fit side by side.
//    A separator (the page's own printed line, ui_book.png) stood between them from decisions-log 218 until 288. "+Room"
//    stood beside Replace fallen until it moved up to the page's header (decisions-log 260), and from there to the spawn
//    bar (283).
// Its buttons act on tap UP ([Board._troopsTap]).

/// The least a tap target of the detail's foot is each way, its press area ([Board._detailFoot]): the tap rule's 44 px,
/// as the spawn bar's cards and buttons (spawn_bar.dart).
const detailTapMin = 44.0;

/// The least the detail's body is tall under its header (decisions-log 283: the landscape book shorter): on a page
/// shorter than that (915x412), the header scrolls with the body as its first lines ([Board._troopDetail]).
const detailBodyMin = 60.0;

/// The most fallen Heroes of a type the Army detail lists with their Recall ([Board._recallLines]); the rest
/// say "+1 more" and come up as those are recalled.
const recallShown = 2;

/// The detail between frames: each section's place this frame by key (`heading`, `stats`, `next`, `pusaka`, `heroes`,
/// `relics`; clipped to the body's view, Rect.zero when scrolled out of it) and its buttons' (`upgrade`, `change`,
/// `bag`, `shop`; the foot's as drawn, `release`, `confirm` (the armed Release's), `replace`, their press areas,
/// `releaseTap`, `replaceTap`, and their words' boxes, `releaseWords`, `confirmWords`, `replaceWords`), the words drawn in
/// each, and the buttons' taps, taken on tap UP. The
/// body ([body]: where it shows this frame; [content]: how tall its sections are) keeps its [scroll] between frames,
/// back to the top for another pick ([of]); [dragY] while a drag scrolls it.
class _Detail {
  final at = <String, Rect>{};
  final words = <String, List<String>>{};
  final inks = <String, Color>{}; // each attribute's value ink, by its short name (for tests)
  final hits = <(Rect, VoidCallback)>[];
  Rect body = Rect.zero;
  double content = 0, scroll = 0;
  double? dragY;
  String? of;

  void clear() {
    at.clear();
    words.clear();
    inks.clear();
    hits.clear();
    body = Rect.zero;
    content = 0;
  }
}

/// A light control on a busy part of a page (decisions-log 198; the owner, 2026-10-03: not every button a ui_buttons
/// button, least of all on top of a card or a section): words on one of ui_bars.png's capsules ([Board._tag]).
/// [link] opens another page: the outline capsule with the book's ink, the dark one with cream under the mouse; [go]
/// does a step (an Awaken, a Forge, "Awaken 3 from the Bag"): the green capsule, lighter under the mouse; [armed] is a
/// step whose next tap does it (a Bag row's Sell all, Sharpen, Carve: "Sure?"; decisions-log 202): the red capsule,
/// cream words; [off] is that one refused: greyed, and a tap says why.
enum _TagLook { link, go, armed, off }

/// One line of the detail's body: how tall it is, and how it draws with its top at a given y.
typedef _DetailLine = ({double h, void Function(double y) draw});

/// The detail's sizes at text scale [ts]: the words (never under 10 px), a line, a button, the gap between sections.
class _DetailSizes {
  _DetailSizes(this.ts)
      : small = math.max(10.0, 13 * ts),
        line = math.max(13.0, (18 * ts).roundToDouble()),
        button = math.max(18.0, (26 * ts).roundToDouble()),
        gap = math.max(3.0, (5 * ts).roundToDouble());

  final double ts, small, line, button, gap;
}

extension on Board {
  /// The picked [type]'s detail on the [right] page ([ts]: the text's scale, [ps]: the book's pixel size).
  void _troopDetail(Canvas c, Game g, String type, Rect right, double ts, double ps) {
    final s = _DetailSizes(ts), d = _detail, x0 = right.left, x1 = right.right;
    if (d.of != type) {
      d
        ..of = type
        ..scroll = 0;
    }
    final foot = _detailFoot(c, g, type, right, s);
    // Under the header the body, unless that leaves it under its least ([detailBodyMin]): the header then scrolls with
    // it, its first lines.
    final under = (right.top + _detailHeaderH(right, s) + s.gap).roundToDouble(), low = (foot - s.gap).roundToDouble();
    final inBody = low - under < detailBodyMin;
    if (!inBody) _detailHeader(c, g, type, right, s, ps);
    final view = d.body = Rect.fromLTRB(x0, inBody ? right.top.roundToDouble() : under, x1, low);

    // The body's sections, each only when it has something to say; past its room it scrolls, its lines then clear of
    // the scroll bar down its right.
    List<(String, List<_DetailLine>)> sections(double x1) => [
          if (inBody)
            (
              'heading',
              [(h: _detailHeaderH(Rect.fromLTRB(x0, 0, x1, right.height), s), draw: (y) => _detailHeader(c, g, type, Rect.fromLTRB(x0, y, x1, y + right.height), s, ps))]
            ),
          ('stats', _detailStats(c, g, type, x0, x1, s)),
          ('next', _detailNext(c, g, type, x0, x1, s)),
          ('wishlist', _detailWishlist(c, g, type, x0, x1, s, ps)),
          ('pusaka', _detailPusaka(c, g, type, x0, x1, s)),
          ('heroes', _detailHeroes(c, g, type, x0, x1, s)),
          ('relics', _detailRelics(c, g, type, x0, x1, s)),
        ]..removeWhere((e) => e.$2.isEmpty);
    double tall(List<(String, List<_DetailLine>)> all) => all.fold(0.0, (h, e) => h + e.$2.fold(0.0, (h, l) => h + l.h)) + s.gap * (all.length - 1);
    var all = sections(x1);
    final scrolls = tall(all) > view.height;
    // Beside the bar the lines are narrower, so a picker's rows can wrap taller: the scroll reaches the narrow ones' end.
    if (scrolls) all = sections(x1 - _capsuleBarW - (3 * ts).roundToDouble());
    final content = d.content = tall(all);
    d.scroll = scrolls ? d.scroll.clamp(0.0, content - view.height) : 0;

    // Every line is drawn, clipped to the view, so each section's words are there for the tests wherever the scroll
    // is; what takes a tap or a hover is cut to the view (out of it: nothing).
    final hits = d.hits.length, hints = _tip.hints.length, rows = _tip.rows.length;
    c.save();
    c.clipRect(view);
    var y = view.top - d.scroll;
    for (final (i, (key, lines)) in all.indexed) {
      if (i > 0) y += s.gap;
      final top = y;
      for (final l in lines) {
        l.draw(y.roundToDouble());
        y += l.h;
      }
      d.at[key] = _inView(Rect.fromLTRB(x0, top, x1, y), view);
    }
    c.restore();
    for (final key in ['upgrade', 'change', 'bag', 'shop', ...d.at.keys.where((k) => k.startsWith('recall:'))]) {
      if (d.at[key] case final r?) d.at[key] = _inView(r, view);
    }
    _cutTo(d.hits, hits, view, (e, r) => (r, e.$2));
    _cutTo(_tip.hints, hints, view, (e, r) => (r, e.$2, e.$3));
    _cutTo(_tip.rows, rows, view, (e, r) => (r, e.$2, e.$3));
    if (scrolls) _capsuleBar(c, view, content, d.scroll); // bag.dart
  }

  /// [r] cut to [view]; Rect.zero when none of it shows.
  Rect _inView(Rect r, Rect view) => r.overlaps(view) ? r.intersect(view) : Rect.zero;

  /// The entries of [list] from [from] on (each a rect first) cut to [view] ([remake]: the entry with its new rect);
  /// those out of it go.
  void _cutTo<T extends Record>(List<T> list, int from, Rect view, T Function(T e, Rect r) remake) {
    final kept = [
      for (final e in list.skip(from))
        if (_inView(_rectOf(e), view) case final r when r != Rect.zero) remake(e, r),
    ];
    list
      ..removeRange(from, list.length)
      ..addAll(kept);
  }

  /// The rect a hit's or a tooltip's record starts with.
  Rect _rectOf(Record e) => switch (e) {
        (final Rect r, _) => r,
        (final Rect r, _, _) => r,
        (final Rect r, _, _, _) => r,
        _ => Rect.zero,
      };

  /// Draws [text] at [at] for the detail's section [key], and keeps its words for the tests ([Board.troopDetailWords]).
  void _say(Canvas c, String key, String text, Offset at, double size, Color color, {bool bold = false, Anchor anchor = Anchor.centerLeft}) {
    if (text.isEmpty) return;
    _text(c, text, at, size: size, color: color, bold: bold, anchor: anchor);
    (_detail.words[key] ??= []).add(text);
  }

  /// A shortcut [key] of the detail in [r]: a link tag ([_tag]) with its tap kept for tap UP, its place and its words
  /// kept for the tests.
  void _detailButton(Canvas c, String key, Rect r, VoidCallback fn, String label, double size) {
    _detail.at[key] = _tag(c, r, fn, label, size, into: _detail.hits);
    (_detail.words[key] ??= []).add(label);
  }

  /// Where a tag with [label] at text size [fs] (after [icon], a piece of ui_icons.png) goes in [btn]: its capsule
  /// ([capsuleSize]) at [btn]'s right, centred down it, on whole pixels; its tap from 3 px left of the capsule to [btn]'s
  /// right, [btn]'s whole height.
  ({Rect capsule, Rect hit}) _tagAt(Rect btn, String label, double fs, {Rect? icon}) {
    final size = capsuleSize(_textWidth(label, fs) + (icon == null ? 0 : icon.width + capsuleGap(fs)), fs);
    final cap = _whole(Rect.fromLTWH(btn.right - size.width, btn.center.dy - size.height / 2, size.width, size.height));
    return (capsule: cap, hit: Rect.fromLTRB(cap.left - 3, btn.top, btn.right, btn.bottom));
  }

  /// A tag in [btn] ([_tagAt], [_TagLook]): [label] on its capsule (after [icon] at its own size), a sprite px lower while
  /// pressed. Its tap [fn] goes in [into] ([_hits] unless given). Returns where its tap is.
  Rect _tag(Canvas c, Rect btn, VoidCallback fn, String label, double fs,
      {_TagLook look = _TagLook.link, List<(Rect, VoidCallback)>? into, Rect? icon}) {
    const ink = Color(0xFF3B2210), cream = Color(0xFFFFF1D6);
    final (:capsule, :hit) = _tagAt(btn, label, fs, icon: icon);
    final kk = capsuleK(capsule.height), state = _look(hit, enabled: look != _TagLook.off);
    final at = state == ButtonLook.pressed ? capsule.translate(0, kk) : capsule, hover = state == ButtonLook.hover;
    final (src, paint, color) = switch (look) {
      _TagLook.link => hover ? (_capsuleSrc, null, cream) : (_capsuleTrack, null, ink),
      _TagLook.go => (_greenCapsule, hover ? _lightTagPaint : null, ink),
      _TagLook.armed => (_redCapsule, hover ? _lightTagPaint : null, cream),
      _TagLook.off => (_greenCapsule, _greyTagPaint, const Color(0xFF4F4A45)),
    };
    _nine(c, src, at, kk, l: 1, t: 1, r: 1, b: src == _greenCapsule || src == _redCapsule ? 2 : 1, sheet: 'ui_bars.png', seam: 0, paint: paint);
    var x = at.left + capsulePad(fs, kk);
    if (icon != null) {
      c.drawImageRect(_img('ui_icons.png'), icon, Rect.fromLTWH(x.roundToDouble(), (at.center.dy - icon.height / 2).roundToDouble(), icon.width, icon.height), _px);
      x += icon.width + capsuleGap(fs);
    }
    _text(c, label, Offset(x, at.center.dy), size: fs, color: color);
    (into ?? _hits).add((hit, fn));
    return hit;
  }

  /// 1. The header at the [right] page's top: the idle sprite standing on the paper (no frame, no well) in a square at
  /// most 36% of the page wide and 20% of it tall (the owner: never half the page), outlined in its awakening colour,
  /// and the crown while a Hero of it lives. Beside it, one under another: the name, how many live ("x13", or "None on
  /// field"; with the type caps on "x3/8", red at the cap or while barred), the stars and the Forge "+n" (their hover:
  /// what the next awakening needs), and the build name in its Artifact's ink, or for a type Oath of One bars
  /// ([Game.typeLocked]) why it can't join, in red. Returns its height ([_detailHeaderH]).
  double _detailHeader(Canvas c, Game g, String type, Rect right, _DetailSizes s, double ps) {
    const ink = Color(0xFF4A2C17), grey = Color(0xFF9E9080);
    final ts = s.ts, nameFs = math.max(12.0, 20 * ts), nameH = (nameFs * 1.3).roundToDouble(), lines = nameH + 3 * s.line;
    final side = math.min(right.width * 0.36, right.height * 0.2).roundToDouble(), h = _detailHeaderH(right, s);
    final top = right.top.roundToDouble(), x0 = right.left.roundToDouble(), x1 = right.right;
    final level = g.awakenLevel(type), n = g.troopCounts[type] ?? 0, b = _idleBounds[type]!;
    final box = Rect.fromLTWH(x0, top + h - side, side, side), k = math.min(box.width / b.width, box.height / b.height);
    c.save();
    c.translate(box.center.dx, box.bottom);
    c.scale(k);
    _frame(c, 'book_${type}_idle', (_clock * _fps).floor(), Offset.zero, anchor: Offset(b.center.dx, b.bottom), line: _awakeLine(level));
    c.restore();
    _heroMark(c, g, type, box, box.inflate(4));

    final x = (box.right + 6 * ts).roundToDouble(), room = x1 - x;
    var y = top + (h - lines) / 2;
    _say(c, 'heading', _fit(troopTypeNames[type]!, nameFs, room), Offset(x, y + nameH / 2), nameFs, ink, bold: true);
    y += nameH;
    final (count, countInk) = _rowCount(g, type);
    _say(c, 'heading', _fitFirst([n > 0 || count.contains('/') ? count : 'None on field', 'x$n'], s.small, room), Offset(x, y + s.line / 2), s.small,
        count.isEmpty ? grey : countInk);
    y += s.line;
    final star = math.min(s.line - 2, math.max(8.0, 14 * ts)), stars = level > maxAwaken ? awakenTop : maxAwaken, tempa = g.tempaOf(type);
    final full = Rect.fromLTWH(x, y + (s.line - star) / 2, star * (stars + (stars - 1) * 0.07), star);
    final (shared, mark) = _besideMark(full, room, tempa);
    final at = tempa > 0 ? shared.translate(x - shared.left, 0) : full;
    _awakeStars(c, at, level);
    _tempaMark(c, tempa, at, room - at.width);
    _tip.hints.add((Rect.fromLTWH(at.left, at.top, at.width + mark, at.height).inflate(2), _Hint.awaken, type));
    y += s.line;
    final lineAt = Offset(x, y + s.line / 2);
    if (g.typeLocked(type)) {
      _say(c, 'heading', _fit(g.buyRefusal(type) ?? '', s.small, room), lineAt, s.small, _blockedInk);
    } else {
      _buildNameLine(c, g, type, lineAt, room, s.small);
      if (rowBuildName(type) case (final text, _)) (_detail.words['heading'] ??= []).add(text);
    }
    _detail.at['heading'] = Rect.fromLTRB(x0, top, x1, top + h);
    return h;
  }

  /// How tall the header is on [right] ([_detailHeader]): its square or its four lines, the taller.
  double _detailHeaderH(Rect right, _DetailSizes s) {
    final nameH = (math.max(12.0, 20 * s.ts) * 1.3).roundToDouble();
    return math.max(math.min(right.width * 0.36, right.height * 0.2).roundToDouble(), nameH + 3 * s.line);
  }

  /// 2. The eight attributes as the field has them (the Hero's aura in; [_rowStats]), two to a row, each as the owner
  /// drew it: `icon short-name value` over what it means (Words: "HP 140" over "Damage it can take"); after the
  /// value, at the cell's right, the item's taken/cap ("3/5", red once full) where it fits. The value green where what the
  /// type got raised it (items, awakening, its Artifact: the book's [Game.statsOf] against the base), red at a melee
  /// type's longest reach and at its fastest walk ([walkCap]); kinds outside the type's recipe faded. Their hovers:
  /// [Game.hpInfo], [Game.mpInfo], the item's.
  List<_DetailLine> _detailStats(Canvas c, Game g, String type, double x0, double x1, _DetailSizes s) {
    const ink = Color(0xFF4A2C17), grey = Color(0xFF9E9080);
    final ts = s.ts, colGap = math.max(6.0, (10 * ts).roundToDouble()), cellW = ((x1 - x0 - colGap) / 2).floorToDouble();
    final heals = troopTypes[type]!.heals;
    final valueFs = math.max(10.0, 14 * ts), countFs = math.max(10.0, 11 * ts), helpFs = math.max(10.0, 11 * ts);
    final lineA = math.max(14.0, (19 * ts).roundToDouble()), lineB = math.max(12.0, (15 * ts).roundToDouble());
    final rowGap = math.max(2.0, (4 * ts).roundToDouble()), gap = math.max(2.0, (3 * ts).roundToDouble());
    final base = troopTypes[type]!, now = g.fieldStats(type), book = g.statsOf(type);
    // Whole numbers from 100 up, one decimal below.
    String f(num v) => v is int || v >= 100 || v == v.roundToDouble() ? '${v.round()}' : v.toStringAsFixed(1);
    (String, List<String>) words(Item? item, int j) => switch (item?.slot) {
          null when j == 0 => (Words.hp, Words.hpHelp),
          null => (Words.mp, heals ? Words.healerMpHelp : Words.mpHelp),
          ItemSlot.amulet => (Words.hp, Words.hpHelp),
          ItemSlot.shield || ItemSlot.helm => (Words.defence, Words.defenceHelp),
          ItemSlot.sword || ItemSlot.staff || ItemSlot.beads || ItemSlot.torch || ItemSlot.prism =>
            heals ? (Words.heal, Words.healHelp) : (Words.damage, Words.damageHelp),
          ItemSlot.bow || ItemSlot.spear => (Words.range, Words.rangeHelp),
          ItemSlot.boots => (Words.speed, Words.speedHelp),
          ItemSlot.gloves => (Words.rate, heals ? Words.healRateHelp : Words.rateHelp),
          ItemSlot.potion => (Words.regen, Words.regenHelp),
          ItemSlot.ring => (Words.mp, heals ? Words.healerMpHelp : Words.mpHelp),
        };
    _rowStatTexts[type] = [for (final (_, stat) in _rowStats) f(stat(now))];

    void cell(int j, Rect r) {
      final (kind, stat) = _rowStats[j];
      final item = kind == Item.sword ? powerItem(type) : kind;
      final (name, help) = words(item, j);
      final icon = math.min(math.max(12.0, 16 * ts), lineA - 2), aMid = r.top + lineA / 2;
      final to = Rect.fromLTWH(r.left, (aMid - icon / 2).roundToDouble(), icon, icon);
      final (was, v) = (stat(base), stat(now));
      var color = stat(book) != was ? const Color(0xFF2E8B3A) : ink;
      var count = '', countInk = grey, up = 0;
      if (item == null) {
        // HP (the heart) and MP (the bolt, blue): only awakening raises them.
        c.drawImageRect(_img('ui_icons.png'), j == 0 ? _heartIcon : _boltIcon, to, j == 0 ? _px : _mpPaint);
        _tip.hints.add((r, j == 0 ? _Hint.hp : _Hint.mp, type));
      } else {
        // By grade (decisions-log 249) the kind's grades together: what it holds of them, the caps of those open.
        final grades = [for (var n = 1; n <= maxAwaken; n++) itemOf(item.slot, n)];
        final taken = grades.fold(0, (a, i) => a + g.countOf(type, i)), cap = grades.fold(0, (a, i) => a + g.capOf(type, i));
        // A melee type's reach at its ceiling shows as maxed, like a full item: by the rule's own reach (a bow is
        // refused, [Refusal.reach]), not the aura's, which ends with the Hero.
        if (item == Item.bow && book.melee && book.range >= book.reachCap) color = _blockedInk;
        // So does its walk at the fastest a troop of it walks ([walkCap], decisions-log 311): the number is that walk.
        if (item == Item.boots && v >= walkCap(type)) color = _blockedInk;
        // Enhanced (decisions-log 255): the kind's highest plus on the type tints its icon, its "+3" after the count.
        up = grades.fold(0, (a, i) => math.max(a, g.plusesOn(type, i).firstOrNull ?? 0));
        _icon(c, item, to, cap > 0 || taken > 0 ? _px : _ghost, up); // kinds outside the type's recipe are faded
        _tip.rows.add((r, item, type));
        if (cap > 0 || taken > 0) {
          count = cap > 0 ? '$taken/$cap' : 'x$taken';
          if (!grades.any((i) => g.canUse(i, type))) countInk = _blockedInk;
        }
      }
      final value = f(v), nx = to.right + gap, vx = nx + _textWidth(name, valueFs) + gap;
      _say(c, 'stats', name, Offset(nx, aMid), valueFs, ink);
      _say(c, 'stats', value, Offset(vx, aMid), valueFs, color);
      _detail.inks[name] = color;
      final end = r.right, plus = up > 0 ? ' +$up' : '', plusW = _textWidth(plus, countFs);
      final countAt = count.isEmpty ? double.infinity : vx + _textWidth(value, valueFs) + 2 * gap + _textWidth(count, countFs);
      if (plus.isNotEmpty && countAt + plusW <= end) {
        _say(c, 'stats', plus, Offset(end, aMid), countFs, _plusPaperInk(up), anchor: Anchor.centerRight);
        _say(c, 'stats', count, Offset(end - plusW, aMid), countFs, countInk, anchor: Anchor.centerRight);
      } else if (countAt <= end) {
        _say(c, 'stats', count, Offset(end, aMid), countFs, countInk, anchor: Anchor.centerRight);
      }
      _say(c, 'stats', _fitFirst(help, helpFs, end - r.left), Offset(r.left, r.top + lineA + lineB / 2), helpFs, grey);
    }

    final rows = (_rowStats.length / 2).ceil();
    return [
      for (var i = 0; i < rows; i++)
        (
          h: lineA + lineB + (i < rows - 1 ? rowGap : 0),
          draw: (top) {
            for (var j = 2 * i; j < math.min(2 * i + 2, _rowStats.length); j++) {
              cell(j, Rect.fromLTWH(x0 + (j % 2) * (cellW + colGap), top, cellW, lineA + lineB));
            }
          },
        ),
    ];
  }

  /// 3. The Awaken needs. Below Awaken 3, by grade (decisions-log 249): "Awaken 2 needs (grade II):", then the grade set's
  /// items ([Game.gradeSet]) one a row, as the owner drew it: `icon name have/need where-from` in columns, the count green
  /// once it has enough; where from: "Done" (green) once held, "In Bag: 1" (green), "Smithy: can make 3" (green,
  /// [Craft.canMake]) or "Smithy: needs Leather Strap" (grey, [Craft.whyNotMake]; shorter in steps down to "Smithy");
  /// then what it unlocks and the grade after it ([awakenSkillChange]: "Next: Unlocks Unbroken. Awaken 3 needs grade
  /// III."), and while the bag holds it the green "Awaken 2 from the Bag". From Awaken 3: "Next: Awaken 4" (at 5 "Next: Forge +5") over the Shop's own
  /// step ([Board._upgradeButton]: "Awaken 4  100k", "Forge +5  33k", or greyed with why, "Awaken 4: Opens after wave
  /// 15"), one tap. First, by grade, a level the type kept from a save before the grades ([Game.keptLevel], decisions-log
  /// 272), in grey: "Awaken 3 (kept from old items)", or "Awaken 3 (kept)" where that doesn't fit.
  List<_DetailLine> _detailNext(Canvas c, Game g, String type, double x0, double x1, _DetailSizes s) {
    const ink = Color(0xFF4A2C17), grey = Color(0xFF9E9080), green = Color(0xFF2E8B3A);
    final level = g.awakenLevel(type), ts = s.ts, w = x1 - x0, out = <_DetailLine>[];
    final wide = w >= 212, bw = (wide ? math.min(w, math.max(w * 0.7, 200 * ts)) : w).roundToDouble();
    void button(double top, {String? step}) {
      final btn = Rect.fromLTWH((x1 - bw).roundToDouble(), top, bw, s.button);
      final label = _upgradeButton(c, g, type, btn, ts, s.small, into: _detail.hits, step: step, tag: true);
      _detail.at['upgrade'] = _tagAt(btn, label, s.small).hit;
      (_detail.words['next'] ??= []).add(label);
    }

    // A level kept from a save before the grades (decisions-log 272), said first: "Awaken 3 (kept from old items)".
    if (g.keptLevel(type) > 0) {
      final kept = awakenName(g.keptLevel(type));
      final text = _fitFirst(['$kept (${Words.keptFromOld})', '$kept (${Words.kept})'], s.small, w);
      out.add((h: s.line, draw: (top) => _say(c, 'next', text, Offset(x0, top + s.line / 2), s.small, grey)));
    }
    if (level < maxAwaken) {
      if (g.recipeOf(type).isEmpty) return out; // nothing awakens it
      final need = g.awakenProgress(type).entries.toList(), icon = (s.small * 1.2).roundToDouble(), gap = math.max(3.0, (4 * ts).roundToDouble());
      String said((int, int) p) => '${p.$1}/${p.$2}';
      // The columns: the names after the icons, the counts after the longest name, where from after the longest count.
      final nameX = x0 + icon + gap, countX = nameX + need.fold(0.0, (m, e) => math.max(m, _textWidth(itemNames[e.key]!, s.small))) + 2 * gap;
      final howX = countX + need.fold(0.0, (m, e) => math.max(m, _textWidth(said(e.value), s.small))) + 2 * gap;
      (List<String>, Color) how(Item item, (int, int) p) {
        final inBag = g.inventory[item] ?? 0;
        if (p.$1 >= p.$2) return ([Words.done], green);
        if (inBag > 0) return (['In ${Words.bag}: $inBag', '${Words.bag}: $inBag'], green);
        return _smithyHow(g, item, green, grey);
      }

      // The whole set on the Wishlist (decisions-log 300): "Wishlist all" at the line's right puts every item the Awaken
      // still lacks on the type's wishes with its count ([Wishlist.wishSet]); once on, "Remove set" takes them off.
      final setOn = g.setWished(type), setTag = g.wishSetOf(type).isNotEmpty ? (setOn ? Words.removeSet : Words.wishAll) : null;
      final tagW = setTag == null ? 0.0 : capsuleSize(_textWidth(setTag, s.small), s.small).width + 6 * ts;
      final needs =
          _fitFirst(['${awakenName(level + 1)} ${Words.needs} (${gradeName(level + 1)}):', '${awakenName(level + 1)} ${Words.needs}:'], s.small, w - tagW);
      out.add((
        h: s.line,
        draw: (top) {
          _say(c, 'next', needs, Offset(x0, top + s.line / 2), s.small, ink);
          if (setTag != null) _detailButton(c, 'wishAll', Rect.fromLTRB(x0, top, x1, top + s.line), () => _wishAllTap(type), setTag, s.small);
        },
      ));
      for (final MapEntry(key: item, value: p) in need) {
        out.add((
          h: s.line,
          draw: (top) {
            final mid = top + s.line / 2, to = Rect.fromLTWH(x0, (mid - icon / 2).roundToDouble(), icon, icon);
            _icon(c, item, to);
            _tip.rows.add((Rect.fromLTRB(x0, top, x1, top + s.line), item, type));
            _say(c, 'next', itemNames[item]!, Offset(nameX, mid), s.small, ink);
            _say(c, 'next', said(p), Offset(countX, mid), s.small, p.$1 >= p.$2 ? green : ink);
            final (words, color) = how(item, p);
            // With the Wishlist, an item still short and not on the type's wishes: a "+" at the right that wishes it with
            // the set's count (decisions-log 303), where its where-from words still fit whole beside it.
            const plus = '+';
            final tagW = capsuleSize(_textWidth(plus, s.small), s.small).width + 3;
            if (setTag != null && p.$1 < p.$2 && g.wishGoal(type, item) == null && g.canWish(type, item) && howX + _textWidth(words.first, s.small) + 4 * ts <= x1 - tagW) {
              _detailButton(c, 'wishOne:${item.name}', Rect.fromLTRB(x1 - tagW, top, x1, top + s.line), () => _wishOneTap(type, item, p.$2), plus, s.small);
            }
            _say(c, 'next', _fitFirst(words, s.small, x1 - howX), Offset(howX, mid), s.small, color);
          },
        ));
      }
      // The grade the Awaken after it takes: "Awaken 3 needs grade III." (decisions-log 249).
      final after = level + 2 <= maxAwaken ? '${awakenName(level + 2)} ${Words.needs} ${gradeName(level + 2)}.' : null;
      final change = switch (awakenSkillChange(type, level, level + 1)) { (final now, final then) => then ?? now, null => null };
      if (change != null || after != null) {
        final texts = [
          if (change != null && after != null) 'Next: $change. $after',
          if (change != null) 'Next: $change' else 'Next: $after',
        ];
        out.add((h: s.line, draw: (top) => _say(c, 'next', _fitFirst(texts, s.small, w), Offset(x0, top + s.line / 2), s.small, grey)));
      }
      if (g.bagLevel(type) > level) out.add((h: s.button + 2, draw: (top) => button(top + 2)));
      return out;
    }
    final forge = level >= tempaFrom, n = g.tempaOf(type);
    final step = forge ? (n < tempaMax ? tempaName(n + 1) : null) : awakenName(level + 1);
    if (step != null) {
      out.add((h: s.line, draw: (top) => _say(c, 'next', _fit('Next: $step', s.small, w), Offset(x0, top + s.line / 2), s.small, ink)));
    }
    out.add((h: s.button, draw: (top) => button(top, step: step)));
    return out;
  }

  /// Where a by-grade Awaken item comes from when the Bag holds none (decisions-log 249): "Smithy: can make 3" (green)
  /// while the Bag's materials and gold pay for one ([Craft.canMake]), else what the Smithy still needs
  /// ([Craft.whyNotMake]): "Smithy: needs Wolf Claw" (grey), shorter in steps down to "Smithy".
  (List<String>, Color) _smithyHow(Game g, Item item, Color green, Color grey) {
    const smithy = Words.smithy;
    final n = g.canMake(item);
    if (n > 0) return (['$smithy: ${Words.canMake} $n', '$smithy: $n', smithy], green);
    final short = switch (g.whyNotMake(item)) {
      CraftRefusal(short: final Mat m) => m.label,
      CraftRefusal(short: final Item i) => itemNames[i]!,
      CraftRefusal(why: CraftWhy.gold) => 'gold',
      _ => null,
    };
    return ([if (short != null) ...['$smithy: ${Words.needs} $short', '$smithy: $short'], smithy], grey);
  }

  /// 4. Its Artifact: the capsule (its icon and stars, faded while it sleeps; its hover the Artifact's), its name and
  /// "Change", which turns the book to the Bag with it picked and its type rows open ([_openBag], [BagAction.types]: they
  /// move it or send it to the Vault); under them what it does ([pusakaGist]). Without one, while some Artifact is owned: "No Artifact" and "Bag"
  /// (the Bag on its Artifacts chip).
  List<_DetailLine> _detailPusaka(Canvas c, Game g, String type, double x0, double x1, _DetailSizes s) {
    const grey = Color(0xFF9E9080);
    final relic = g.pusakaOf(type), ts = s.ts, w = x1 - x0;
    double buttonW(String label) => (_textWidth(label, s.small) + 14 * ts + 6).roundToDouble();
    if (relic == null) {
      if (!g.pusaka.keys.any((r) => !r.oath)) return const [];
      return [
        (
          h: s.button,
          draw: (top) {
            final btn = Rect.fromLTWH((x1 - buttonW(Words.bag)).roundToDouble(), top, buttonW(Words.bag), s.button);
            _say(c, 'pusaka', _fit('No ${Words.artifact}', s.small, btn.left - x0 - 4), Offset(x0, btn.center.dy), s.small, grey);
            _detailButton(c, 'bag', btn, () => _openBag(category: BagCategory.artifacts), Words.bag, s.small);
          },
        ),
      ];
    }
    final asleep = g.pusakaAsleep(relic), p = g.pusaka[relic]!;
    final gist = '${pusakaGist(relic, p.stars, ukir: p.ukir)}${asleep ? ' (asleep)' : ''}';
    return [
      (
        h: s.button,
        draw: (top) {
          const change = 'Change';
          final btn = Rect.fromLTWH((x1 - buttonW(change)).roundToDouble(), top, buttonW(change), s.button);
          final cap = _pusakaCapsule(c, g, relic, Offset.zero, math.max(10.0, 12 * ts), draw: false);
          final at = _pusakaCapsule(c, g, relic, Offset(x0 + cap.width, btn.center.dy), math.max(10.0, 12 * ts));
          _tip.hints.add((at, _Hint.pusaka, type));
          final x = at.right + 4 * ts;
          _say(c, 'pusaka', _fit(relicNames[relic]!, s.small, btn.left - 4 - x), Offset(x, btn.center.dy), s.small,
              asleep ? grey : (_pusakaInk[relic] ?? _pusakaInkElse));
          _detailButton(c, 'change', btn, () => _openBag(pick: relic, act: BagAction.types), change, s.small);
        },
      ),
      (h: s.line, draw: (top) => _say(c, 'pusaka', _fit(gist, s.small, w), Offset(x0, top + s.line / 2), s.small, grey)),
    ];
  }

  /// 5. Its Heroes: the crown and the living ones' names (on a wide page, one alone with its skill; the hover: the
  /// Heroes' tooltip, hero.dart); its fallen ones, recalled here between any waves ([_recallLines], decisions-log 230;
  /// the Toko's Fallen Heroes side, a game without the Towns', went in decisions-log 296).
  List<_DetailLine> _detailHeroes(Canvas c, Game g, String type, double x0, double x1, _DetailSizes s) {
    const ink = Color(0xFF4A2C17);
    final heroes = [for (final u in g.troops) if (u.alive && u.hero && u.type == type) u], ts = s.ts, w = x1 - x0;
    final out = <_DetailLine>[];
    if (heroes.isNotEmpty) {
      out.add((
        h: s.line,
        draw: (top) {
          final mid = top + s.line / 2, icon = (s.line - 2).roundToDouble(), crown = Rect.fromLTWH(x0, mid - icon / 2, icon, icon);
          _uiIcon(c, _icCrown, crown);
          final names = heroes.map((u) => u.name).join(', '), skill = heroes.length == 1 && w >= 212 ? heroes.single.heroSkill : null;
          final x = crown.right + 4 * ts, words = heroes.length == 1 ? 'Hero: $names' : 'Heroes: $names';
          final text = _fitFirst([if (skill != null) '$words - ${skill.title}', words], s.small, x1 - x);
          _say(c, 'heroes', text, Offset(x, mid), s.small, ink);
          _tip.hints.add((Rect.fromLTRB(x0, top, math.min(x1, x + _textWidth(text, s.small)), top + s.line), _Hint.hero, type));
        },
      ));
    }
    out.addAll(_recallLines(c, g, type, x0, x1, s));
    return out;
  }

  /// The Recall of [type]'s fallen Heroes in its Heroes section (decisions-log 230; the Town design's
  /// section 8: the Shop's Fallen Heroes tab moved here, so they come back between any waves, in a Town or not): one
  /// line per Hero, the last to fall first, at most [recallShown] and then "+1 more": the crown faded, "Fallen: Aldric",
  /// and on the right a green tag "Recall 57k" ([Recall.recallPrice]; with the army or the type full, where it fits,
  /// "Recall 57k, swap 1 Templar", decisions-log 167 and 201; it always says Recall, decisions-log 237: "Recall 6k" where
  /// "6000" won't fit), one tap ([Recall.recallHero]); refused ([Recall.whyNotRecall]: before wave 15, mid-wave, the
  /// gold, no troop to swap) greyed with why, and a tap says it. The line's hover tells about the Hero and, with a swap,
  /// who goes home and what it pays back ([Recall.recallInfo]).
  List<_DetailLine> _recallLines(Canvas c, Game g, String type, double x0, double x1, _DetailSizes s) {
    const ink = Color(0xFF4A2C17), grey = Color(0xFF9E9080);
    final fallen = [for (final (i, f) in g.fallenHeroes.indexed) if (f.type == type) (i, f)].reversed.toList(), ts = s.ts;
    final name = troopTypeNames[type] ?? type, out = <_DetailLine>[];
    for (final (i, f) in fallen.take(recallShown)) {
      out.add((
        h: s.button,
        draw: (top) {
          final mid = top + s.button / 2, icon = (s.line - 2).roundToDouble(), crown = Rect.fromLTWH(x0, mid - icon / 2, icon, icon);
          _uiIcon(c, _icCrown, crown, _ghost); // faded: fallen
          final why = g.whyNotRecall(f), cost = shortPrice(g.recallPrice), pad = capsuleSize(0, s.small).width;
          final room = ((x1 - x0) * 0.62).roundToDouble() - pad, costs = {cost, kPrice(g.recallPrice)};
          final label = _fitFirst(
              why == null
                  ? [
                      if (g.recallSwapOf(f) != null) '${Words.recall} $cost, swap 1 $name', // the swap and its gold back: the hover's
                      for (final k in costs) '${Words.recall} $k',
                      Words.recall,
                    ]
                  : [
                      why,
                      if (why.endsWith(recallNoSwap(type))) ...['No $name to swap', 'No $name'],
                      ...?_shortWhy[why],
                      ..._shorter(why),
                    ],
              s.small,
              room);
          final btn = Rect.fromLTRB(x0, top, x1, top + s.button);
          void tap() {
            if (why == null) {
              state.recallHero(f);
            } else {
              showMessage(why);
            }
          }
          final hit = _tag(c, btn, tap, label, s.small, look: why == null ? _TagLook.go : _TagLook.off, into: _detail.hits);
          _detail.at['recall:$i'] = hit;
          (_detail.words['recall'] ??= []).add(label);
          final x = crown.right + 4 * ts, end = hit.left - 4 * ts;
          _say(c, 'heroes', _fitFirst(['Fallen: ${f.name}', f.name], s.small, end - x), Offset(x, mid), s.small, ink);
          _tip.hints.add((Rect.fromLTRB(x0, top, end, top + s.button), _Hint.recall, '$i'));
        },
      ));
    }
    if (fallen.length > recallShown) {
      final more = '+${fallen.length - recallShown} more';
      out.add((h: s.line, draw: (top) => _say(c, 'heroes', _fit(more, s.small, x1 - x0), Offset(x0, top + s.line / 2), s.small, grey)));
    }
    return out;
  }

  /// Shorter words for a Recall refusal [why] the tag can't hold: the part before its colon ("Army full: no Templar to
  /// swap"), and "Full" for a full army or type ("Army full 32/32", "Templars full 10/10": [Game.buyRefusal]).
  List<String> _shorter(String why) => [
        if (why.contains(':')) why.split(':').first,
        if (why.contains(' full')) 'Full',
      ];

  /// 6. The small relics its living troops wear, summed by kind ("Relics: (Fang) 3 (Guard) 1"), or "Relics: none";
  /// nothing while none of it lives. Each icon has the relic's tooltip ([Game.relicInfo]: its tier).
  List<_DetailLine> _detailRelics(Canvas c, Game g, String type, double x0, double x1, _DetailSizes s) {
    const ink = Color(0xFF4A2C17), grey = Color(0xFF9E9080);
    if ((g.troopCounts[type] ?? 0) == 0) return const [];
    final worn = <Relic, int>{};
    for (final u in g.troops) {
      if (!u.alive || u.type != type) continue;
      for (final r in u.relics) {
        worn[r] = (worn[r] ?? 0) + 1;
      }
    }
    return [
      (
        h: s.line,
        draw: (top) {
          final mid = top + s.line / 2, head = worn.isEmpty ? 'Relics: none' : 'Relics:', icon = (s.small * 1.2).roundToDouble();
          _say(c, 'relics', head, Offset(x0, mid), s.small, worn.isEmpty ? grey : ink);
          var x = x0 + _textWidth(head, s.small) + 4 * s.ts;
          for (final r in [for (final r in Relic.values) if (worn.containsKey(r)) r]) {
            final n = 'x${worn[r]}';
            if (x + icon + 2 + _textWidth(n, s.small) > x1) break;
            _icon(c, r, Rect.fromLTWH(x, mid - icon / 2, icon, icon));
            _tip.hints.add((Rect.fromLTWH(x, mid - icon / 2, icon, icon), _Hint.relic, r.name)); // its tooltip: tier, Best on (decisions-log 227)
            x += icon + 2;
            _say(c, 'relics', n, Offset(x, mid), s.small, ink);
            x += _textWidth(n, s.small) + 6 * s.ts;
          }
        },
      ),
    ];
  }

  /// 7. The foot, on the [right] page's bottom edge, with no divider over it (decisions-log 288; the owner, 2026-10-09:
  /// "tidak perlu ada divider dan button relasenya di buat jangan full width containernya tapi cukup sepanjang contentnya
  /// saja di kanan bawah"): one line of ui_buttons buttons max(24, 30·ts) tall, each as wide as its words with the
  /// button's own margins (the spawn bar's +Room and Auto rule, [_footW]). At its right, while it shows ([_hasActions]),
  /// the troop's "Release" (its first tap arms it, [_releaseTap]; while armed the red confirm stands in its place, grown
  /// leftwards from the same right edge as wide as its words, the row's width where they need it, [_releaseConfirm]); at its
  /// left, between waves while someone of the last won wave can be bought back, the army's "Replace fallen (7)  12.5k"
  /// ([_armyRow]). Where Replace fallen doesn't fit beside Release with its price ("Replace (7)  12.5k" at the shortest),
  /// it goes on a line of its own over it, at the left, as wide as its words there; armed, the confirm's words (and its
  /// own) shorten to keep it on the line where they can (below). Each line is [detailTapMin] tall at the
  /// least, its buttons on its bottom: a button's press area is its line's height and k wider each side. The body
  /// reaches down to a gap over the top line, and to the page's bottom with neither. Returns the foot's top.
  double _detailFoot(Canvas c, Game g, String type, Rect right, _DetailSizes s) {
    final x0 = right.left.roundToDouble(), x1 = right.right.roundToDouble(), bottom = right.bottom.roundToDouble(), room = x1 - x0;
    final h = math.max(24.0, (30 * s.ts).roundToDouble()), line = math.max(h, detailTapMin), fs = s.small;
    final k = (h / 16).floorToDouble().clamp(1.0, 3.0), margin = _footW(0, k), gap = 2 * s.gap; // the button's frame ([_button])
    _replaceAt = Rect.zero;
    replaceLabel = '';
    // A button [w] wide at the right or the left of the line whose bottom is [low], and its press area.
    (Rect, Rect) atRight(double w, double low) => (
          Rect.fromLTRB(x1 - w, low - h, x1, low),
          Rect.fromLTRB(math.max(x0, x1 - w - k), low - line, x1, low),
        );
    (Rect, Rect) atLeft(double w, double low) => (
          Rect.fromLTRB(x0, low - h, x0 + w, low),
          Rect.fromLTRB(x0, low - line, math.min(x1, x0 + w + k), low),
        );

    // Replace fallen beside Release with its price where that fits ([besides], the longest first). While Release is
    // armed it stays on the line where it can: its words, else its shorter ones, beside the confirm's longest words that
    // fit and still name the type and the gold ("Send Knight home? +25"). Where none fit, Replace fallen goes on a line
    // of its own over it, and the confirm's words have the whole row as the full-width row's had (12·ts of it for its
    // edges): the confirm then the row's width where its words need it.
    final armed = _release.armed == type, actions = _hasActions(g, type), replace = _replaceWords(g);
    final releaseW = _footW(_textWidth(Words.release, fs), k);
    final besides = [if (actions) for (final t in replace.take(2)) if (_footW(_textWidth(t, fs), k) + gap + releaseW <= room) t];
    var label = besides.firstOrNull;
    _ConfirmWords? words;
    if (armed) {
      label = null;
      for (final t in besides) {
        if (_confirmWords(g, type, h, room - _footW(_textWidth(t, fs), k) - gap - margin, s.ts, named: true) case final w?) {
          (words, label) = (w, t);
          break;
        }
      }
      words ??= _confirmWords(g, type, h, room - 12 * s.ts, s.ts);
    }
    var top = bottom;
    if (actions) {
      final (face, press) = atRight(words == null ? releaseW : _footW(words.width, k).clamp(releaseW, room), bottom);
      _detailActions(c, g, type, face, press, s, words);
      top = press.top;
    }
    if (replace.isNotEmpty) {
      final text = label ?? _fitFirst(replace, fs, room - margin), low = label != null || !actions ? bottom : top - s.gap;
      final (face, press) = atLeft(math.min(room, _footW(_textWidth(text, fs), k)), low);
      _armyRow(c, g, face, press, text, fs);
      top = math.min(top, press.top);
    }
    return top;
  }

  /// How wide a button of the foot is for words [textW] wide at frame scale [k]: the words and the button's own margins
  /// on each side, its 4-sprite-px bevel and 6 px (the spawn bar's +Room and Auto, spawn_bar.dart).
  double _footW(double textW, double k) => (textW + 2 * (4 * k + 6)).roundToDouble();

  /// "Replace fallen"'s words, the longest first ("Replace fallen (7)  12.5k", "Replace (7)  12.5k", "Replace (7)"),
  /// between waves while someone of the last won wave can be bought back ([Game.toReplace], #92); else none. Not in a
  /// Town (decisions-log 301): no troop is bought there, as the spawn bar's hidden; the offer waits for the field, where
  /// it lasts until the next wave.
  List<String> _replaceWords(Game g) {
    if (g.waveActive || g.over || g.inTown || g.toReplace.isEmpty) return const [];
    final n = g.toReplace.length, price = shortPrice(g.replaceCost);
    return ['${Words.replaceFallen} ($n)  $price', 'Replace ($n)  $price', 'Replace ($n)'];
  }

  /// The army's "Replace fallen" at [face] (its press area [press]) with [label] at [fs] ([_replaceWords]): a ui_buttons
  /// button (the page's standalone action), greyed when none can be bought back (a press then says why,
  /// [Game.whyNotReplace]), taken on tap down ([_hits]) as before. "+Room" stood at its right until decisions-log 260
  /// moved it to the page's header, and 283 to the spawn bar ([_barRoom], spawn_bar.dart).
  void _armyRow(Canvas c, Game g, Rect face, Rect press, String label, double fs) {
    final why = g.whyNotReplace;
    _replaceAt = face;
    replaceLabel = label;
    _detail.at
      ..['replace'] = face
      ..['replaceTap'] = press
      ..['replaceWords'] = _wordsAt(face, [(label, fs)]);
    _button(c, face, _replaceFallen, enabled: why == null, label: label, size: fs, into: []);
    _hits.add((press, why == null ? _replaceFallen : () => showMessage(why)));
  }

  /// Whether the detail's foot shows Release for [type]: while the type caps are on and troops of it are alive, or while
  /// its confirm is armed. Buying left the foot for the spawn bar (decisions-log 283, spawn_bar.dart).
  bool _hasActions(Game g, String type) => _release.armed == type || (g.typeCap != null && (g.troopCounts[type] ?? 0) > 0);

  /// The troop's action at [face] (its press area [press]): "Release" while the type has troops alive with the type caps
  /// on (its first tap arms it: [_releaseTap]); while armed ([words]), the red confirm ([_releaseConfirm]). Buy stood at
  /// its left until decisions-log 283 moved buying to the spawn bar at the bottom of the battle screen.
  void _detailActions(Canvas c, Game g, String type, Rect face, Rect press, _DetailSizes s, _ConfirmWords? words) {
    if (words != null) {
      final (:lines, :f1, :f2, width: _) = words;
      _detail.at
        ..['confirm'] = face
        ..['confirmWords'] = _wordsAt(face, [for (final (i, l) in lines.indexed) (l, lines.length == 1 || i == 1 ? f2 : f1)]);
      for (final line in _releaseConfirm(c, words, face, press)) {
        (_detail.words['releaseConfirm'] ??= []).add(line);
      }
      return;
    }
    _releaseButton(c, g, type, face, s.small, into: _detail.hits, press: press);
    _detail.at
      ..['release'] = face
      ..['releaseTap'] = press
      ..['releaseWords'] = _wordsAt(face, [(Words.release, s.small)]);
    (_detail.words['release'] ??= []).add(Words.release);
  }

  /// Where [lines] (each with its size) sit on a foot button at [face], centred on it as drawn (before a press sinks
  /// them), as wide as the widest, for the tests ([Board.troopDetail]: `releaseWords`, `confirmWords`, `replaceWords`).
  Rect _wordsAt(Rect face, List<(String, double)> lines) => Rect.fromCenter(
      center: face.center,
      width: lines.fold(0.0, (w, l) => math.max(w, _textWidth(l.$1, l.$2))),
      height: lines.fold(0.0, (h, l) => h + l.$2 * hudFontScale));
}
