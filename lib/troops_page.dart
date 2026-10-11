part of 'main.dart';

// The Army page (`_Page.troops`; decisions-log 187, its layout 218; ui-hud.md "Army"): the troop types on the left page,
// the picked type on the right one, as the owner asked ("untuk tas aku mau fokus di sisi kiri listnya dan detailnya di
// sisi kanan begitu juga dengan tab troops"; 2026-10-04: "di kiri di buat list troops yang bisa di panggil, dibuat menjadi
// 2 column jadi spritenya bisa lebih besar dan jangan sampai ada box in box"). On the left the nine troop types as a
// grid of two columns in troopTypes order, one paper-card cell each ([_typeCell], troop_row.dart: the sprite standing
// on the card, its name and "x3/8"); where five rows would leave the sprites too small (the 915x412 window) a page of
// fewer rows at a time, with the Bag's pager under them. A tap on a cell picks the type. The right page is the picked
// type's detail ([_troopDetail], troop_detail.dart): its sprite and name, attributes, Awaken needs, Artifact, Heroes and
// relics, Release, and under a separator "Replace fallen" (buying is the spawn bar's since decisions-log 283,
// spawn_bar.dart). Taps act on tap UP ([_troopsTap]).
//
// The header (decisions-log 256, 260; the owner: "army di buat ke ujung kiri", "di ujung kanannya di tambahkan informasi
// yang ada sekarang dan di tambahkan button di samping kanannya untuk expand quotanya"; then "tombol header = beli
// kapasitas footer yang lama ... dipindah ke header", "dibuat pakai button yang sama jangan belang belang gini"): "Army"
// at the left edge; at the right the "alive/cap" counter and left of it the oath's icon, as they stood centred, with the
// type caps on (decisions-log 201). The "+Room" button stood at the right edge until it moved to the spawn bar
// (decisions-log 283; the owner: "Pindah ke bar"; spawn_bar.dart).

/// The Army page between frames: the type picked (shown on the right page; not saved), the game it was picked in
/// (another game coming in picks again: [Board._troopPick]); the grid's page and, this frame, how many cells a page
/// holds, how many pages there are, the pager's two arrows (Rect.zero: one page) and the grid's area (the wheel turns
/// its page there).
class _ArmyPage {
  String? pick;
  Game? of;
  int page = 0, perPage = 9, pageCount = 1;
  double wheelAt = double.negativeInfinity; // when the wheel last turned a page ([_bagWheelGap], as the Bag's)
  Rect back = Rect.zero, on = Rect.zero, grid = Rect.zero;

  /// The header's "alive/cap" counter's place (Rect.zero: the caps are off) and the title's. As last drawn; for tests.
  Rect count = Rect.zero, title = Rect.zero;

  void clear() => back = on = grid = count = title = Rect.zero;
}

/// The smallest sprite (in screen px, its box's height) a cell of the Army page's grid may show: below it the grid
/// shows fewer rows a page, with a pager ([Board._troopsPages]).
const armyCellSpriteMin = 36.0;

extension on Board {
  /// The type the Army page shows on its right page: the one picked, kept across page turns; for a game that just came
  /// in, the first type with a living troop, else the soldier, and the grid turned to its page.
  String get _troopPick {
    final a = _army, g = state;
    if (!identical(a.of, g) || a.pick == null) {
      a
        ..of = g
        ..pick = troopTypes.keys.firstWhere((t) => (g.troopCounts[t] ?? 0) > 0, orElse: () => troopTypes.keys.first)
        ..page = troopTypes.keys.toList().indexOf(a.pick!) ~/ a.perPage;
    }
    return a.pick!;
  }

  /// The Army page: the title at the left edge, the army's "alive/cap" at the right one, the grid of
  /// the nine types (and its pager when they take more than one page) on the [left] page, the picked type on the
  /// [right] one ([ts]: the text's scale, [ps]: the book's pixel size).
  void _troopsPages(Canvas c, Game g, Rect left, Rect right, double ts, double ps) {
    const ink = Color(0xFF4A2C17);
    final title = _titleY(left, ts);
    // The title at the page's left edge (decisions-log 256; the owner: "army di buat ke ujung kiri").
    final tw = _textWidth(Words.army, 22 * ts);
    _army.title = Rect.fromLTWH(left.left + 12 * ts, title - 11 * ts, tw, 22 * ts);
    _text(c, Words.army, Offset(left.left + 12 * ts, title), size: 22 * ts, color: ink, anchor: Anchor.centerLeft, bold: true);
    // At the right edge the army's "alive/cap", red when over ("48/36"), and left of it the oath taken (pusaka.dart,
    // decisions-log 155): its icon, faded while Oath of One waits, its hover the oath's tooltip. The counter and the oath
    // with the type caps on (decisions-log 201), as the counter always was. "+Room" stood right of them (decisions-log
    // 260) until it moved to the spawn bar (decisions-log 283, spawn_bar.dart).
    if (g.typeCap != null) {
      final n = g.armySize, label = '$n/${g.armyCap}', fs = math.max(10.0, 14 * ts);
      final at = Offset(left.right, title), w = _textWidth(label, fs);
      _army.count = Rect.fromLTWH(at.dx - w, title - fs, w, 2 * fs);
      _text(c, label, at, size: fs, anchor: Anchor.centerRight, color: n > g.armyCap ? _blockedInk : ink);
      if (g.oath case final oath?) {
        final s = math.max(12.0, 18 * ts), box = Rect.fromLTWH(at.dx - w - 4 * ts - s, at.dy - s / 2, s, s);
        _icon(c, oath, box, g.oathWaits ? _ghost : _px);
        _tip.hints.add((box, _Hint.pusaka, ''));
      }
    }
    final pick = _troopPick;
    _troopsGrid(c, g, Rect.fromLTRB(left.left, _underTitle(left, ts) + 2 * ts, left.right, left.bottom), ts, ps, pick);
    _troopDetail(c, g, pick, right, ts, ps); // troop_detail.dart
  }

  /// The grid of the troop types in [area]: two columns of cells ([_typeCell]) in troopTypes order, the Bag board's
  /// 2 sprite px apart, as tall as the area allows on whole pixels and inside it. Five rows hold all nine; where that
  /// would leave a cell's sprite under [armyCellSpriteMin] the grid shows as many rows as keep it, a page at a time, with
  /// the Bag's pager at the bottom ([_armyPager]). The rows are counted from the area's unrounded top, a pixel kept for
  /// the rounding: the book bobs, and a room counted from a rounded top would change by a pixel from frame to frame (the
  /// Bag's grid had that flicker, bag.dart).
  void _troopsGrid(Canvas c, Game g, Rect area, double ts, double ps, String pick) {
    final a = _army, types = troopTypes.keys.toList(), gap = 2 * ps, cols = 2, band = armyCellBand(ts);
    final x0 = area.left.ceilToDouble(), cellW = ((area.right.floorToDouble() - x0 - gap * (cols - 1)) / cols).floorToDouble();
    double cellH(int rows, double room) => ((room - 1 - gap * (rows - 1)) / rows).floorToDouble();
    double sprite(double h) => h - 4 * ps - band - ps; // a cell's sprite box: its inside less the name's line
    final all = (types.length + cols - 1) ~/ cols, pagerH = math.max(20.0, (26 * ts).roundToDouble()), pagerGap = math.max(gap, (4 * ts).roundToDouble());
    var rows = all, room = area.height;
    if (sprite(cellH(all, room)) < armyCellSpriteMin) {
      room -= pagerH + pagerGap;
      while (rows > 1 && sprite(cellH(rows, room)) < armyCellSpriteMin) {
        rows--;
      }
    }
    final per = a.perPage = rows * cols, pages = a.pageCount = (types.length + per - 1) ~/ per;
    a
      ..page = a.page.clamp(0, pages - 1)
      ..grid = area;
    final h = cellH(rows, room), y0 = area.top.ceilToDouble();
    for (final (i, type) in types.skip(a.page * per).take(per).indexed) {
      final r = Rect.fromLTWH(x0 + (i % cols) * (cellW + gap), y0 + (i ~/ cols) * (h + gap), cellW, h);
      _typeCell(c, g, type, r, ts, area, picked: type == pick, k: ps);
    }
    if (pages > 1) _armyPager(c, Rect.fromLTRB(area.left, area.bottom - pagerH, area.right, area.bottom), ts);
  }

  /// The grid's pager in [r] (more than a page, the Bag's: [Board._bagPager]): a small arrow tag at each end
  /// ([_arrowTag]), faded at the ends, and "1/2" between them. A tap on a tag's place turns a page ([_armyTurn]).
  void _armyPager(Canvas c, Rect r, double ts) {
    const ink = Color(0xFF4A2C17);
    final a = _army, w = math.max(32.0, (42 * ts).roundToDouble()), fs = math.max(10.0, 13 * ts);
    final back = a.back = Rect.fromLTWH(r.left, r.top, w, r.height), on = a.on = Rect.fromLTWH(r.right - w, r.top, w, r.height);
    for (final (btn, by, icon) in [(back, -1, _icPageBack), (on, 1, _icPageOn)]) {
      _arrowTag(c, btn, icon, fs, by < 0 ? a.page > 0 : a.page < a.pageCount - 1, () => _armyTurn(by));
    }
    _text(c, '${a.page + 1}/${a.pageCount}', r.center, size: fs, color: ink, anchor: Anchor.center);
  }

  /// Turns the grid's page [by] (1: on, -1: back), within its pages; the pick stays (the right page keeps it).
  void _armyTurn(int by) {
    final a = _army;
    a.page = (a.page + by).clamp(0, a.pageCount - 1);
  }

  /// The wheel ([dy]) over the Army page: over the grid a page on (down) or back (up), at most once in [_bagWheelGap]
  /// s; over the detail's body it scrolls it (troop_detail.dart).
  void _armyWheel(Offset p, double dy) {
    if (_log.open && _log.panel.contains(p)) return;
    final a = _army;
    if (a.grid.contains(p) && dy != 0 && a.pageCount > 1 && _clock - a.wheelAt >= _bagWheelGap) {
      a.wheelAt = _clock;
      _armyTurn(dy > 0 ? 1 : -1);
    }
    if (_detail.body.contains(p)) _detail.scroll += dy;
  }

  /// "Replace fallen" (#92): buys the last won wave's fallen back ([Game.replaceFallen]). When not everyone could come
  /// back the message window says why: the reason alone when nobody did, else "Replaced 5 of 7 (not enough gold)".
  void _replaceFallen() {
    final (:bought, :of, :why) = state.replaceFallen();
    if (why == null) return;
    showMessage(bought == 0 ? why : 'Replaced $bought of $of (${why[0].toLowerCase()}${why.substring(1)})');
  }

  /// A tap on the Army page, on tap UP, in this order: the armed Release's confirm; any other tap lets an armed Release
  /// go; then a button of the detail (troop_detail.dart: Release (which arms it), the tags), a cell (picks its
  /// type; the detail's body scrolls back to the top). The foot's "Replace fallen" takes its press on tap down
  /// ([_hits]), as the pager's arrows. True when it took the tap. Nothing while the cells aren't there
  /// ([_cards] empty: another page, or a splash, popup or card over them cleared them).
  bool _troopsTap(Offset p) {
    final rel = _release;
    if (_cards.isEmpty) {
      rel.armed = null;
      return false;
    }
    if (rel.armed case final type? when rel.confirm.contains(p)) {
      _releaseTap(type);
      return true;
    }
    rel.armed = null;
    for (final (rect, fn) in [..._detail.hits]) {
      if (!rect.contains(p)) continue;
      Sounds.play(Sfx.click); // a button, as on the other pages
      fn();
      return true;
    }
    for (final (rect, type) in _cards) {
      if (!rect.contains(p)) continue;
      _army.pick = type;
      return true;
    }
    return false;
  }

  /// A buy of one [type] troop onto the field ([Game.autoPlace]; a spawn bar card's tap, spawn_bar.dart, the Army
  /// detail's Buy until decisions-log 283); refused, the message window says why ([Game.buyRefusal]: a full or barred
  /// type, a full army), except too poor, which the card's grey price says.
  void _buyTroop(String type) {
    final g = state;
    if (g.over) return;
    if (g.buyRefusal(type) case final why? when why != buyRefusals.gold) showMessage(why);
    g.autoPlace(type);
  }
}

/// The height of a cell's name line at text scale [ts] ([Board._typeCell]): its words max(10, 14·ts) and a little air.
double armyCellBand(double ts) => (math.max(10.0, 14 * ts) * 1.3).roundToDouble();
