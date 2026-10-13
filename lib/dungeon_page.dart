part of 'main.dart';

// The Dungeon's page in the Town book (decisions-log 336, 337; docs/dungeon-design.md sections 1 and 2; docs/ui-hud.md
// "Dungeon"): its tab beside the Shop's, or a tap on the cave's mouth at the street's far end (town_scene.dart), opens it.
// The left page: "Dungeon", the floor the trip starts on (M1: Floor 1 only, and in grey that more come later), "Your
// party" and its three places as the book's paper cards (a picked troop's sprite, name and type; the first leads), and
// the page's one bevelled button, Enter (the white one while no troop is picked, a press saying why). The right page:
// the army's living troops as cards, a picked one on the lit card with its place's number; a tap adds one (up to 3) or
// takes it out. The list scrolls where it doesn't fit (page_scroll.dart).

/// The Dungeon page between frames.
class _DungeonPageView {
  final picks = <Unit>[]; // the army's troops picked for the party, in order: the first leads
  final at = <String, Rect>{}; // this frame, for tests: 'enter', 'party:<i>', 'troop:<name>'
  final list = _PageScroll(); // the right page's troops: it scrolls past its room

  void clear() {
    at.clear();
    list.clear();
  }
}

extension on Board {
  /// The Dungeon's two pages in a Town: on [left] the floor, the party and Enter, on [right] the army to pick from.
  void _dungeonPages(Canvas c, Game g, Rect left, Rect right, double ts, double ps) {
    const ink = Color(0xFF4A2C17), grey = Color(0xFF9E9080);
    final v = _dunPage..clear();
    v.picks.removeWhere((u) => !u.alive || !g.troops.contains(u)); // fallen or released since
    _text(c, Words.dungeon, Offset(left.center.dx, _titleY(left, ts)), size: 22 * ts, color: ink, anchor: Anchor.center, bold: true);
    final fs = math.max(10.0, 13 * ts), small = math.max(10.0, 11 * ts), lineH = (fs * 1.5).roundToDouble();
    var y = _underTitle(left, ts).roundToDouble();
    _text(c, Words.floorOne, Offset(left.left, y + lineH / 2), size: fs, color: ink, bold: true);
    final later = _fitFirst([Words.dungeonFloors, ''], small, left.width - _textWidth(Words.floorOne, fs, bold: true) - 8 * ts);
    _text(c, later, Offset(left.right, y + lineH / 2), size: small, color: grey, anchor: Anchor.centerRight);
    y += lineH * 1.4;
    _text(c, Words.yourParty, Offset(left.left, y + lineH / 2), size: fs, color: ink, bold: true);
    _text(c, '${v.picks.length}/$partyMost', Offset(left.right, y + lineH / 2), size: fs, color: grey, anchor: Anchor.centerRight);
    y += lineH;
    // The party's three cards and Enter fit what is left of the page: a short book's cards are lower, their sprites
    // smaller (the army's list on the right page keeps the same cards).
    final gap = math.max(3.0, (5 * ts).roundToDouble()), bh = math.max(36.0, (34 * ts).roundToDouble());
    final pad = math.max(3.0, (6 * ts).roundToDouble()), fit = ((left.bottom - y - bh - (partyMost + 1) * gap) / partyMost).floorToDouble();
    final rowH = math.max(fs + small + 2 * pad, math.min(math.max(32.0, bagHeadIcon(ps)) + 2 * pad, fit)), side = rowH - 2 * pad;
    for (var i = 0; i < partyMost; i++) {
      final r = Rect.fromLTWH(left.left, y, left.width, rowH), u = v.picks.elementAtOrNull(i);
      _card(c, r, u == null ? Board._frameGrey : Board._framePlain);
      v.at['party:$i'] = r;
      if (u == null) {
        if (i == v.picks.length) _text(c, Words.pickParty, Offset(r.left + pad, r.center.dy), size: small, color: grey);
      } else {
        _dunPageTroop(c, g, u, r, side, pad, fs, small, lead: i == 0);
        _hits.add((r, () => v.picks.remove(u)));
      }
      y += rowH + gap;
    }
    // Enter: the page's one bevelled button, green; white while no troop is picked, its press saying why.
    final why = g.whyNotDungeon(v.picks);
    final enter = Rect.fromLTWH(left.left, y + gap, left.width, bh);
    _button(c, enter, () {
      if (!g.enterDungeon([...v.picks])) showMessage(g.whyNotDungeon(v.picks) ?? Words.dungeonPickParty);
    }, label: Words.enter, size: fs * 1.1, row: Board._btnGreen, enabled: why == null);
    if (why != null) _hits.add((enter, () => showMessage(why)));
    v.at['enter'] = enter;

    // The right page: the army's living troops to pick from.
    _text(c, Words.army, Offset(right.center.dx, _titleY(right, ts)), size: 22 * ts, color: ink, anchor: Anchor.center, bold: true);
    final army = [for (final u in g.troops) if (u.alive) u];
    final top = _underTitle(right, ts).roundToDouble(), view = Rect.fromLTRB(right.left, top, right.right, right.bottom);
    final tall = army.length * (rowH + gap);
    final w = tall > view.height ? right.width - _scrollBarRoom(ts) : right.width;
    final (first, marks) = _scrollBegin(c, v.list, view, tall, null);
    var ry = first;
    for (final u in army) {
      final r = Rect.fromLTWH(right.left, ry, w, rowH), place = v.picks.indexOf(u);
      _card(c, r, place >= 0 || _look(r) == ButtonLook.hover ? Board._frameLit : Board._framePlain);
      _dunPageTroop(c, g, u, r, side, pad, fs, small, lead: false, place: place);
      v.at['troop:${u.name}'] = _inView(r, view);
      _hits.add((r, () {
        if (place >= 0) {
          v.picks.remove(u);
        } else if (v.picks.length < partyMost) {
          v.picks.add(u);
        } else {
          showMessage(Words.dungeonPickParty);
        }
      }));
      ry += rowH + gap;
    }
    _scrollEnd(c, v.list, marks);
  }

  /// A troop's card's insides over [r]: its idle sprite standing in a [side] box, its name (the leader's crown before it
  /// with [lead]), its type and its type's HP and damage; with a [place] its party number in the count's capsule.
  void _dunPageTroop(Canvas c, Game g, Unit u, Rect r, double side, double pad, double fs, double small, {required bool lead, int place = -1}) {
    const ink = Color(0xFF4A2C17), grey = Color(0xFF7A6A58);
    final box = _whole(Rect.fromLTWH(r.left + pad, r.center.dy - side / 2, side, side));
    final b = _idleBounds[u.type];
    if (b != null) {
      final k = math.min(box.width / b.width, box.height / b.height);
      c.save();
      c.translate(box.center.dx, box.bottom);
      c.scale(k);
      _frame(c, 'book_${u.type}_idle', 0, Offset.zero, anchor: Offset(b.center.dx, b.bottom));
      c.restore();
    }
    var x = box.right + 6;
    if (lead) {
      _uiIcon(c, _icCrown, Rect.fromLTWH(x, r.center.dy - fs * 0.65 - 7, 14, 14));
      x += 16;
    }
    final s = g.statsOf(u.type), line = '${troopTypeNames[u.type] ?? u.type} · ${Words.hp} ${s.hp} · ${Words.damage} ${s.dmg.round()}';
    final room = r.right - pad - x - (place >= 0 ? 28 : 0);
    _text(c, _fit('${u.hero ? 'Hero ' : ''}${u.name}', fs, room), Offset(x, r.center.dy - fs * 0.55), size: fs, color: ink, bold: true);
    _text(c, _fit(line, small, r.right - pad - box.right - 6), Offset(box.right + 6, r.center.dy + small * 0.75), size: small, color: grey);
    if (place >= 0) _capsule(c, '${place + 1}', small, Offset(r.right - pad, r.top + pad));
  }
}
