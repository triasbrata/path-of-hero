part of 'main.dart';

// The spawn bar (decisions-log 283, 287; ui-hud.md "Spawn bar"; the owner, 2026-10-09: "sama untuk spawn troops di
// keluarkan dari ui book di pindah ke bawah game saja, jadi book itu hanya isinya detail dari army dan bags saja kalau di
// battle field"; then, with a picture of a hotbar: "untuk sloot army-nya coba di pakaikan seperti ini tapi di sesuaikan
// tinggi dan lebarnya dan di taruh di tengah saja. terus buat untuk battle groundnya itu pada bagian bawah seperti ini
// ___/<menu spawn troops>\____ supaya battle jangan sampai di belakang dari action bar untuk spawn troops"). Troops are
// bought from a hotbar at the bottom of the battle screen, centred, on a raised step of the battle floor's own ground:
// - the hotbar (ui_hotbar.png: Cute Fantasy UI's premade hotbar, its tan panel stretched to hold the slots): one inset
//   slot per troop type in troopTypes order (the Army page's), the type's idle sprite in it, its price (the coin and
//   shortPrice) along its bottom and its count against its cap ("5/10") astride its top edge. A tap buys one
//   ([Board._buyTroop]: [Game.autoPlace], the rules the Army page's Buy had, mid-wave too). Too poor: the coin faded and
//   the price grey, a tap does nothing; refused for anything else ([Game.buyRefusal]): the slot greyed with the red
//   forbidden sign, a tap says why. Where they don't all fit they page by whole slots between two arrow buttons beside
//   the hotbar (the owner, 2026-10-09, of a cut card under a small arrow tag: "masa kamu buat seperti ini emang itu bisa
//   di click kalau kamu buat seperti itu?"), the light button, as tall as a slot, 44 px wide at the least, never over a
//   slot; the wheel and a swipe page them too;
// - on the step beside it (the owner: "Di atas panggung"): "+Room" at its left (the capacity buy, the Army header's until
//   decisions-log 283) and "Auto Buy" at its right (auto_replace.dart: the fallen bought back as the gold allows). The
//   army's count stays the top band's alone (troop_counter.dart);
// - the step ([Board._barStep], battle_step.png): Floor Tiles1's grass-topped earth under the whole bar, its top
//   ([stepLip]) under the lowest a unit's shadow reaches, its grass turning down a slope to the floor's low grass at each
//   end, one piece of earth with the floor's (decisions-log 295; the owner: "sambungannya tidak seamless"). The
//   scene is framed so nothing on the field is ever drawn behind the bar ([Board._origin]); on a short screen the field
//   zooms out a little too, so the first lane's bars stay under the top band ([Board._hotGeom]; the owner: "Zoom out
//   sedikit").
// Not in a Town, on the welcome screen or after the game. The open book stands over the field above it
// ([Board._bookLandscape]).

/// The spawn bar between frames: the first slot its page shows (where they don't all fit), a swipe's last x and how far
/// it has gone (null once it turned the page), and when the wheel last turned one; this frame the slots drawn (for taps
/// and tests) and how each looked, the whole bar ([area]: the step with its slopes, down to the screen's bottom), the
/// slots' strip ([list]: the hotbar and its arrows), the hotbar's [panel], "+Room" and "Auto Buy" (their press areas),
/// +Room's button as drawn and its words (for tests), the two arrow buttons (Rect.zero: all the slots fit) and how many
/// slots a page shows, and the slot a press went down on (its tap up buys only on that slot).
class _SpawnBar {
  int first = 0, per = 0;
  double? dragX;
  double swiped = 0, wheelAt = double.negativeInfinity;
  final cards = <(Rect, String)>[];
  final looks = <String, String>{}; // each slot's look this frame: 'buy', 'poor', 'refused' (for tests)
  Rect area = Rect.zero, list = Rect.zero, panel = Rect.zero, room = Rect.zero, auto = Rect.zero, roomFace = Rect.zero;
  Rect back = Rect.zero, on = Rect.zero;
  final roomWords = <(String, Rect)>[];
  String? down;

  void clear() {
    cards.clear();
    looks.clear();
    roomWords.clear();
    area = list = panel = room = auto = roomFace = back = on = Rect.zero;
  }
}

/// A slot of the hotbar (and the buttons on the step as tall): [barCardShare] of the screen's height (the owner,
/// 2026-10-09: "Lebih besar, ~56px", 56 px in his 1600x947 window), never under [barCardMin] (the tap rule's 44): 44 at
/// 1266x713 and 915x412, 46 at 1164x777, 64 at 1920x1080.
const barCardShare = 56 / 947, barCardMin = 44.0;

/// The hotbar's frame: screen px per sprite px of ui_hotbar.png (its 2-px rim, the 5 px of tan round and between the
/// slots: 10 px).
const hotbarPx = 2.0;

/// The landscape book's height against the one its room alone gives it ([Board._bookLandscape]; the owner, 2026-10-09:
/// "buku di buat lebih pendek lagi").
const bookShort = 0.8;

/// The text sizes on a slot [h] px tall: its price 24% of it, its count 22%, never under the HUD's small floor of 11 px
/// (the owner, 2026-10-09, asked that they read at 1600x947: 13 and 12 px there).
double barPriceSize(double h) => math.max(11.0, (h * 0.24).roundToDouble());
double barCountSize(double h) => math.max(11.0, (h * 0.22).roundToDouble());

/// How wide a spawn bar's arrow button is (the tap rule's 44 px).
const barArrowMin = 44.0;

/// How far a swipe on the hotbar goes before it turns its page (px; once a swipe).
const barSwipe = 32.0;

/// The step's top, the grass lip of the plinth that holds the bar, in field y (decisions-log 287): 2 under the lowest a
/// unit's shadow reaches (a unit stands at y fieldH - 2 at the lowest, its shadow's last row 6 under it: 132). The scene
/// is framed so this is on the plinth's top ([Board._origin]): no unit, foe, shot or loot is ever drawn behind the bar.
const stepLip = 134.0;

/// How far over a unit's y its HP box (and a Hero's crown on it) reaches, world units: the first lane's units (y tile / 2)
/// keep theirs under the top band ([Board._hotGeom]).
const barReach = 24.0;

/// The hotbar's geometry this frame, without words (the framing reads it): a slot's side [s], the margin and gap round
/// the slots [m] (5 sprite px at [hotbarPx]), the panel's [bottom] and [panelTop], the field's [scale] (the screen's
/// height over the scene's, a little less on a short screen), the step's top on the screen ([stepTop]: the plinth's
/// grass lip, its grass and roots over the panel) and the floor's pixels on the screen ([q]: 5 a world unit).
typedef _HotGeom = ({double s, double m, double bottom, double panelTop, double scale, double stepTop, double q});

/// The pager's triangles ([_icPageBack], [_icPageOn]) on the spawn bar's arrow buttons, inked as a button's words: dark
/// brown, grey while the button is greyed (nothing more that way).
final _barArrowInk = Paint()
  ..filterQuality = FilterQuality.none
  ..colorFilter = const ColorFilter.mode(Color(0xFF3B2210), BlendMode.srcIn);
final _barArrowOff = Paint()
  ..filterQuality = FilterQuality.none
  ..colorFilter = const ColorFilter.mode(Color(0xFF8E8A86), BlendMode.srcIn);

/// A slot's price on the brown slot: cream outlined dark; grey while it can't buy.
const _barPriceInk = Color(0xFFFFF1DC), _barPriceOff = Color(0xFFB8AFA6), _barPriceLine = Color(0xFF3F2832);

/// battle_step.png (tool/import_battle_floor.py, decisions-log 295): one 352x76 strip of ground, a little hill
/// `___/top\___`, every column Floor Tiles1's grass-topped cell's lowered to the ground's height there: 32 px of low
/// ground, the slope up ([_stepUp], [_stepRun] wide, the low ground's grass 60 px under the top), three cells of
/// the step's top (the middle one [_stepTop]), the slope down ([_stepDown]) and low ground again. Each piece starts on a
/// whole cell, so the grass runs on unbroken from one to the next, and what lies round a piece in the strip is the
/// ground that goes on from it, so the floor's smoothed paint reads nothing foreign at its edges. [_stepEarth]: inside
/// the top's earth, one flat colour (the floor's earth's), stretched over any area.
const _stepRun = 96.0, _stepH = 76.0;
const _stepUp = Rect.fromLTWH(32, 0, _stepRun, _stepH), _stepTop = Rect.fromLTWH(160, 0, 32, 32);
const _stepDown = Rect.fromLTWH(224, 0, _stepRun, _stepH), _stepEarth = Rect.fromLTWH(136, 24, 80, 48);

extension on Board {
  /// Whether the spawn bar shows: on the battle field (not in a Town, nor fading into one), not on the welcome screen,
  /// not after the game.
  bool get _barShown => welcome == null && !state.over && !state.inTown && !_townShown;

  /// The hotbar's geometry ([_HotGeom]): a slot [barCardShare] of the screen's height (never under [barCardMin]); the
  /// panel's bottom on the battle log button's ([_edgeB] above the screen's bottom); the step's top 12 floor px (its
  /// grass and roots) over the panel. Whether the bar shows or not, so the field never jumps.
  ///
  /// The field's scale: the screen's height over the scene's, but no more than keeps the first lane's units' bars
  /// ([barReach] over a unit at y tile / 2) 2 px under the top band once the scene is lifted onto the step (decisions-log
  /// 287; the owner, 2026-10-09: "Zoom out sedikit"). Only a screen under ~582 px tall zooms out: 1.916 px a world unit
  /// at 915x412 for 2.146, a view 478 wide for 426; 1266x713 and taller keep theirs. On the screen the first lane's bar
  /// is at origin + (backdropH + tile / 2 - barReach) * scale, the origin stepTop - (backdropH + stepLip) * scale, and
  /// stepTop panelTop - 12 * scale * [_layerK].
  _HotGeom _hotGeom() {
    final s = math.max(barCardMin, (size.y * barCardShare).roundToDouble()), m = 5 * hotbarPx;
    final bottom = (size.y - _edgeB).roundToDouble(), panelTop = bottom - s - 2 * m;
    final scale = math.min(size.y / (backdropH + fieldH), (panelTop - _meterBottom - 2) / (stepLip + 12 * _layerK - tile / 2 + barReach));
    final q = scale * _layerK;
    return (s: s, m: m, bottom: bottom, panelTop: panelTop, scale: scale, stepTop: (panelTop - 12 * q).floorToDouble(), q: q);
  }

  /// The book in landscape (decisions-log 283; the owner, 2026-10-09: "Bar selebar layar di bawah buku", then "buku di
  /// buat lebih pendek lagi"), from what its room alone gives it ([_bookFit]: the scale [ps], the [room], the width
  /// [bw] and the height [bh]): the same scale, width and place across, so its covers, tabs and words keep their sizes,
  /// but [bookShort] of that height, its top where it was (under the top band's rows, the tabs on it) and its bottom, as
  /// low as it bobs, two slots' height over the hotbar's bottom at the most: where 283's rule (a bar's height over the
  /// bar) left it, so the Army detail, the Bag's and the Smithy's pages keep their room at 915x412, and always over the
  /// step's top (a slot is taller than the hotbar's frame and the step's rise over it; decisions-log 287). The same in a
  /// Town (no bar there), so the book looks the same everywhere. Its room is the room less what the book gave up at its bottom, so
  /// the book [_book] centres in it keeps that top.
  ({double ps, Rect room, double bw, double bh, Rect rest}) _bookLandscape(double ps, Rect room, double bw, double bh) {
    const bob = 6.0; // how far the book bobs in landscape ([_book])
    final top = room.center.dy - 8 - bh / 2, hot = _hotGeom();
    final h = math.min((bh * bookShort).roundToDouble(), (hot.bottom - 2 * hot.s - bob - top).floorToDouble());
    final r = Rect.fromLTRB(room.left, room.top, room.right, room.bottom - (bh - h));
    return (ps: ps, room: r, bw: bw, bh: h, rest: Rect.fromLTWH(r.right - bw, top, bw, h));
  }

  /// A button's frame on the bar at [h] px tall: a sprite px per 16 px of it, 1 to 3 ([_button]'s).
  double _barFrame(double h) => (h / 16).floorToDouble().clamp(1.0, 3.0);

  /// The words' size on the bar's buttons at a slot's height [h]: the top band's Auto Wave's (start_button.dart), 42% of it.
  double _barFont(double h) => (h * 0.42).clamp(14.0, 28.0).roundToDouble();

  /// The spawn bar (decisions-log 287), about the screen's middle: the hotbar centred, its slots the troop types' in
  /// troopTypes order; where they don't all fit, an arrow button beside it at each end and as many whole slots a page as
  /// fit with "+Room" left of that and "Auto Buy" right of it, 2 gaps clear, +Room within the screen's left edge and
  /// Auto Buy clear of the battle log's button; all of it on the step ([_barStep]), as wide each way as the wider side
  /// needs.
  void _spawnBar(Canvas c, Game g) {
    final b = _bar..clear();
    if (!_barShown) return;
    final h = _hotGeom(), s = h.s, m = h.m, k = _meterK, aw = barArrowMin;
    final types = troopTypes.keys.toList(), n = types.length;
    double widthOf(int i) => i * s + (i + 1) * m; // a panel holding i slots
    final rowTop = h.panelTop + m, rowBottom = h.bottom - m; // the slots' row: the buttons and the arrows level with it
    final fs = _barFont(s), margin = 2 * (4 * _barFrame(s) + 6); // the top band's Auto Wave's margins
    final autoW = (_textWidth(Words.autoBuy, fs) + margin).roundToDouble();
    final roomW = (math.max(_textWidth('${Words.room}  8888', fs), _textWidth(Words.roomMax, fs)) + margin).roundToDouble();
    final cx = (size.x / 2).roundToDouble(), side = 2 * m + math.max(roomW, autoW);
    // Half the room for the hotbar and its arrows: +Room's side less +Room, Auto Buy's (to the log's button) less Auto Buy.
    final half = math.min(cx - _edgeL - 2 * m - roomW, size.x - _edgeR - _meterH - 3 * k - cx - 2 * m - autoW);
    var (from, per) = (0, n);
    if (widthOf(n) / 2 > half) {
      per = 1;
      while (per < n && widthOf(per + 1) / 2 + m + aw <= half) {
        per++;
      }
      from = b.first = b.first.clamp(0, n - per);
    } else {
      b.first = 0;
    }
    b.per = per;
    final panel = b.panel = Rect.fromLTWH(cx - (widthOf(per) / 2).roundToDouble(), h.panelTop, widthOf(per), h.bottom - h.panelTop);
    final out = per < n ? m + aw : 0.0; // the arrows beside it
    final room = Rect.fromLTRB(panel.left - out - 2 * m - roomW, rowTop, panel.left - out - 2 * m, rowBottom);
    final auto = Rect.fromLTRB(panel.right + out + 2 * m, rowTop, panel.right + out + 2 * m + autoW, rowBottom);
    final reach = panel.width / 2 + out + side + m; // the step's flat top, each way from the middle
    b.area = _barStep(c, h, cx - reach, cx + reach);
    _nine(c, const Rect.fromLTWH(0, 0, 11, 28), panel, hotbarPx, l: 3, t: 3, r: 3, b: 3, sheet: 'ui_hotbar.png');
    b.list = panel;
    if (per < n) {
      final back = Rect.fromLTRB(panel.left - m - aw, rowTop, panel.left - m, rowBottom);
      final on = Rect.fromLTRB(panel.right + m, rowTop, panel.right + m + aw, rowBottom);
      b.list = Rect.fromLTRB(back.left, panel.top, on.right, panel.bottom);
      _barArrow(c, b.back = back, _icPageBack, from > 0, () => _barPage(-1));
      _barArrow(c, b.on = on, _icPageOn, from + per < n, () => _barPage(1));
    }
    for (var i = 0; i < per; i++) {
      _barCard(c, g, types[from + i], Rect.fromLTWH(panel.left + m + i * (s + m), rowTop, s, s), hotbarPx);
    }
    // Their press areas k round, clear of the arrows and the hotbar (2 gaps away).
    _barRoom(c, g, room, b.room = room.inflate(k), fs);
    _barAuto(c, g, auto, b.auto = auto.inflate(k), fs);
  }

  /// The step under the bar (decisions-log 287, 295; the owner, 2026-10-09: `___/<menu spawn troops>\____`, so the
  /// battle is never behind the bar; then "bagian sininya sambungannya tidak seamless"), in the battle floor's own art at
  /// the floor's pixels ([_HotGeom.q], the floor's paint; battle_step.png, tool/import_battle_floor.py): Floor Tiles1's
  /// grass-topped cell along its flat top from [l] to [r] ([stepLip]), widened to a whole number of cells about the same
  /// middle (half a cell each side at the most) so its grass runs on unbroken into both slopes; at each end the grass
  /// turns down a slope ([_stepRun] floor px wide) to the floor's low grass, 60 floor px (12 world units,
  /// [frontLip]) lower, where the floor's own front edge goes on; the earth under all of it one flat fill, the floor's
  /// colour, down to the screen's bottom. Returns the whole step, its slopes too, down to the screen's bottom.
  Rect _barStep(Canvas c, _HotGeom h, double l, double r) {
    final img = _img('battle_step.png'), cell = 32 * h.q, top = h.stepTop, run = _stepRun * h.q, deep = _stepH * h.q;
    final mid = (l + r) / 2, n = ((r - l) / cell).ceil();
    l = (mid - n * cell / 2).roundToDouble();
    r = l + n * cell;
    // The earth: under the top's grass cells, and under the slopes' strips; each a single fill, so no seam between cells.
    c.drawImageRect(img, _stepEarth, Rect.fromLTRB(l - 1, top + cell - 1, r + 1, size.y), _bg);
    c.drawImageRect(img, _stepEarth, Rect.fromLTRB(l - run, top + deep - 2, r + run, size.y), _bg);
    // The top's cells, each a screen px wider than a cell (and its source as much, the strip's next column), so every
    // pixel is wholly some cell's: an edge between two that only half covers a pixel would let the field show through.
    // Their ends run 1 px under the slopes' first columns, opaque at the shoulders.
    final top1 = Rect.fromLTWH(_stepTop.left, 0, _stepTop.width + 1 / h.q, _stepTop.height);
    c.save();
    c.clipRect(Rect.fromLTRB(l - 1, top, r + 1, top + cell));
    for (var i = 0; i < n; i++) {
      c.drawImageRect(img, top1, Rect.fromLTWH(l + i * cell, top, cell + 1, cell), _bg);
    }
    c.restore();
    c.drawImageRect(img, _stepUp, Rect.fromLTWH(l - run, top, run, deep), _bg);
    c.drawImageRect(img, _stepDown, Rect.fromLTWH(r, top, run, deep), _bg);
    return Rect.fromLTRB(l - run, top, r + run, size.y);
  }

  /// An arrow button beside the hotbar in [r] ([icon]: the pager's triangle that way): the light button of +Room and
  /// Auto Buy ([_button], on tap down), the triangle on it at twice its size or more, inked as its words; greyed while
  /// nothing more is that way ([can] false), when a tap does nothing.
  void _barArrow(Canvas c, Rect r, Rect icon, bool can, VoidCallback fn) {
    final sink = _button(c, r, fn, enabled: can), s = math.max(2.0, (r.height * 0.4 / icon.height).floorToDouble());
    c.drawImageRect(_img('ui_icons.png'), icon,
        _whole(Rect.fromCenter(center: r.center + Offset(0, sink - _barFrame(r.height)), width: icon.width * s, height: icon.height * s)),
        can ? _barArrowInk : _barArrowOff);
  }

  /// Turns the hotbar's page [by] (1: on, -1: back): the next or the last slots a page shows, held to the first and the
  /// last whole page (the last page shows the last slots).
  void _barPage(int by) {
    final b = _bar, n = troopTypes.length;
    if (b.per == 0 || b.per >= n) return;
    b.first = (b.first + by * b.per).clamp(0, n - b.per);
  }

  /// "+Room" at [r] (its press area [press]), moved from the Army page's header (decisions-log 260 → 283; the owner:
  /// "Pindah ke bar"), the same button: the light bevel with "+Room  40" ([Words.room], two spaces, `shortPrice` of
  /// [Game.capacityCost]), "Room: max" ([Words.roomMax]) at the most; a tap buys what it did ([Game.buyCapacity]:
  /// [capacityStep] more room, the zone a column wider); greyed whole while it can't buy, when a tap says why in the
  /// message window ([Game.whyNotCapacity], decisions-log 292: "Not enough gold (need 110).", "Army room is at its most
  /// (36)."); its tooltip under the mouse or a long press ([Game.roomTip]: "+Room: more army room (110 gold)." first).
  /// On tap down ([_hits]).
  void _barRoom(Canvas c, Game g, Rect r, Rect press, double fs) {
    final b = _bar, can = g.canBuyCapacity, line = g.capacityMaxed ? Words.roomMax : '${Words.room}  ${shortPrice(g.capacityCost)}';
    final sink = _button(c, r, g.buyCapacity, enabled: can, label: line, size: fs, into: []);
    b.roomFace = r;
    b.roomWords.add((line, Rect.fromCenter(center: r.center + Offset(0, sink - _barFrame(r.height)), width: _textWidth(line, fs), height: fs * hudFontScale)));
    final why = g.whyNotCapacity;
    _hits.add((press, why == null ? g.buyCapacity : () => showMessage(why)));
    _tip.hints.add((press, _Hint.room, ''));
  }

  /// "Auto Buy" ([Words.autoBuy], decisions-log 290) at [r] (its press area [press]): the top band's Auto Wave look
  /// (the light bevel, orange while on) for [Game.autoReplace] (auto_replace.dart: the fallen bought back as the gold
  /// allows); a tap turns it on or off (on tap down, [_hits]); its tooltip ([Game.autoTip]).
  void _barAuto(Canvas c, Game g, Rect r, Rect press, double fs) {
    _button(c, r, () {}, active: g.autoReplace, label: Words.autoBuy, size: fs, into: []);
    _hits.add((press, () => g.setAutoReplace(!g.autoReplace)));
    _tip.hints.add((press, _Hint.autoReplace, ''));
  }

  /// Troop [type]'s slot in [r] at [k] px per sprite px ([still]: a guide card's picture, which neither lights nor takes
  /// a tap): the hotbar's inset slot (ui_hotbar.png), lighter under the mouse and its face sunk a sprite px while pressed;
  /// the idle sprite in it in its awakening's outline, the count against the type's cap astride its top edge ("5/10",
  /// [_rowCount]: red at the cap), and along its bottom the coin and the price; its tooltip ([Game.spawnTip]). Too poor:
  /// the coin faded, the price grey. Refused for anything else ([Game.buyRefusal]): the slot greyed, the sprite faded
  /// under the red forbidden sign, the price grey.
  void _barCard(Canvas c, Game g, String type, Rect r, double k, {bool still = false}) {
    final why = g.buyRefusal(type), price = g.priceOf(type), afford = g.gold >= price, locked = why != null && why != buyRefusals.gold;
    final look = still ? ButtonLook.normal : _look(r), sink = look == ButtonLook.pressed ? k : 0.0, at = r.translate(0, sink);
    _nine(c, const Rect.fromLTWH(12, 0, 18, 18), _whole(r), k, l: 2, t: 3, r: 2, b: 1, sheet: 'ui_hotbar.png',
        paint: locked ? _greyTagPaint : (look == ButtonLook.hover || look == ButtonLook.pressed ? _lightTagPaint : null));
    if (!still) {
      _bar.cards.add((r, type));
      _bar.looks[type] = locked ? 'refused' : (afford ? 'buy' : 'poor');
      _tip.hints.add((r, _Hint.troop, type)); // its name, price and count, and why not (tooltip.dart)
    }
    // Inside the slot's outline and its top's shade; the words at the HUD's small floor (11 px) at the least (the owner,
    // 2026-10-09: readable at 1600x947, where they are 13 and 12 px).
    final inner = Rect.fromLTRB(at.left + 2 * k, at.top + 3 * k, at.right - 2 * k, at.bottom - k);
    final fs = barPriceSize(r.height), band = (fs * 1.2).roundToDouble();

    // The sprite over the price's line, as big as the room allows.
    final box = Rect.fromLTRB(inner.left, inner.top, inner.right, inner.bottom - band);
    _barSprite(c, g, type, box, faded: locked);
    if (locked) {
      final sign = 16.0 * math.max(1.0, (box.shortestSide / 24).floorToDouble());
      c.drawImageRect(_img('ui_icons.png'), _forbidIcon, _whole(Rect.fromCenter(center: box.center, width: sign, height: sign)), _px);
    }

    // The count in the Bag's dark capsule astride the slot's top edge at its right, so it reads and hides little of the
    // sprite ("5/10", red at the type's cap; without the caps "13"; none: nothing).
    final (count, countInk) = _rowCount(g, type);
    if (count.isNotEmpty) {
      _capsule(c, count.substring(1), barCountSize(r.height), Offset(at.right + 1, at.top),
          anchor: Anchor.centerRight, red: countInk == _blockedInk, tight: true);
    }

    // The coin and the price along the bottom, centred.
    final coin = math.min(fs, band), cost = shortPrice(price), w = coin + 2 + _textWidth(cost, fs);
    final x = (inner.center.dx - w / 2).roundToDouble(), y = inner.bottom - band / 2;
    _uiIcon(c, Board._icCoin, Rect.fromLTWH(x, (y - coin / 2).roundToDouble(), coin, coin), afford && !locked ? _px : _ghost);
    _text(c, cost, Offset(x + coin + 2, y), size: fs, color: afford && !locked ? _barPriceInk : _barPriceOff, outline: _barPriceLine);
  }

  /// Troop [type]'s shadowless idle sprite (`book_<type>_idle`, its visible pixels [_idleBounds]) as big as [box]
  /// allows, its feet on the box's bottom, animated, outlined in its awakening's colour; [faded] for a refused card.
  void _barSprite(Canvas c, Game g, String type, Rect box, {bool faded = false}) {
    final b = _idleBounds[type]!, s = math.min(box.width / b.width, box.height / b.height);
    c.save();
    c.translate(box.center.dx, box.bottom);
    c.scale(s);
    _frame(c, 'book_${type}_idle', (_clock * _fps).floor(), Offset.zero, anchor: Offset(b.center.dx, b.bottom),
        paint: faded ? _ghost : _px, line: _awakeLine(g.awakenLevel(type), ghost: faded));
    c.restore();
  }

  /// Troop [type]'s card this frame (Rect.zero: on another page of the strip).
  Rect _barCardRect(String type) => [for (final (r, t) in _bar.cards) if (t == type) r].firstOrNull ?? Rect.zero;

  /// The card under [p] this frame (null: none).
  String? _barCardAt(Offset p) => [for (final (r, type) in _bar.cards) if (r.contains(p)) type].firstOrNull;

  /// Whether [p] is on the bar (the step with everything on it, or a button's press area) this frame: the field under it
  /// takes no press, hover or drag ([_covered], plates.dart).
  bool _onBar(Offset p) => _bar.area.contains(p) || _bar.room.contains(p) || _bar.auto.contains(p);

  /// The wheel ([delta]) over the cards' strip turns its page: down or right on, up or left back, a page a notch (the
  /// Bag's gap between turns, [_bagWheelGap]).
  void _barWheel(Offset p, Offset delta) {
    final b = _bar, d = delta.dy + delta.dx;
    if (!b.list.contains(p) || d == 0 || _clock - b.wheelAt < _bagWheelGap) return;
    b.wheelAt = _clock;
    _barPage(d > 0 ? 1 : -1);
  }

  /// A drag that begins on the cards' strip is the bar's (the field under it takes none): a swipe there turns its page.
  /// True when it took the drag.
  bool _barDragStart(Offset p) {
    if (!_barShown || !_bar.list.contains(p)) return false;
    _bar
      ..dragX = p.dx
      ..swiped = 0;
    return true;
  }

  /// The drag on the strip moved to [p]: past [barSwipe] px it turns the page once (the finger going left: the next),
  /// and the rest of it does nothing.
  void _barDragTo(Offset p) {
    final b = _bar;
    if (b.dragX case final x?) {
      b
        ..swiped += p.dx - x
        ..dragX = p.dx;
      if (b.swiped.abs() >= barSwipe) {
        _barPage(b.swiped < 0 ? 1 : -1);
        b.dragX = null;
      }
    }
  }

  /// A tap up on the bar: on the card the press went down on, it buys one of its type ([_buyTroop]) with the click.
  /// True when the tap was the bar's (anywhere on it): nothing under it takes it.
  bool _barTap(Offset p) {
    final down = _bar.down;
    _bar.down = null;
    if (!_onBar(p)) return false;
    if (down != null && _barCardAt(p) == down) {
      Sounds.play(Sfx.click);
      _buyTroop(down); // troops_page.dart
    }
    return true;
  }
}
