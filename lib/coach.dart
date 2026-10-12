part of 'main.dart';

// The first-time guide on the screen (docs/ui-hud.md "Guide"; its words: lib/guide_text.dart, when its cards are due:
// lib/guide_rules.dart). Two looks, both from the game's own art:
// - A card: the Hero splash's panel (hero_splash.dart) over the dimmed screen: the tooltip frame's body, the UI pack's
//   ribbon with the page's title across its top, and beside its lines a picture made of the
//   game's own sprites, rows, buttons and icons. The intro (I1-I7: after a device's first "New Game", or "How to Play"
//   on the welcome screen) has its counter "3/7" and the buttons Skip, Back and Next ("Play!" on its last page); a
//   one-time card (K0-K22) says "Tap to continue". A tap that isn't on a button, Space, Enter or → goes on; ←
//   goes back; Esc (and Skip) closes it. Closed, it is seen ([Settings.seen], settings.json). While it shows nothing
//   under it takes a press, a drag, the wheel, a key or a tooltip, and Auto's countdown waits ([Board.update]).
//   A one-time card opens by itself at a break when it is due ([_coachNews]): one a break, once the board's own news
//   is over, and K5 and K12 over the boss chest's popup.
// - A pointer (P1-P5) between waves: the tooltip frame with the cursor set's gold hand tapping beside its line, its tail
//   aimed at what to press (an Army row's price, "Start", the Tas tab, an item, a type's row). It blocks nothing, never covers
//   what it points at, and hides while that isn't drawn. Each one ends on its action; the first two, or the item ones,
//   not done in [_pointerBreaks] breaks are dropped as seen.
// With no seen set (a widget test's board, which never runs main()) the guide is off: no intro on "New Game", no
// pointers; "How to Play" still plays the intro.

/// ui_icons.png's gold hand (the cursor set's yellow one, its finger up) and the same hand pressed: a pointer taps with
/// them, [_handBeat] s each.
const _icHand = Offset(304, 224), _icHandDown = Offset(304, 240), _handBeat = 0.4;

/// ui_icons.png's red arrow pointing right (the I7 picture: the loot goes to the bag).
const _icArrowRight = Offset(144, 208);

/// How many breaks a pointer waits to be done before it is dropped as seen.
const _pointerBreaks = 2;

/// How far inside the screen's edges a card and a pointer stay.
const _coachEdge = 8.0;

/// How long the boss chest's popup shows before a card over it (K5, K12) pops in (s, on the screen clock).
const _coachOverChest = 0.6;

/// ui_icons.png's big green and red up arrows and its big green plus (the cards' pictures).
const _icUpGreen = Offset(0, 144), _icUpRed = Offset(0, 160), _icPlusGreen = Offset(0, 48);

/// The guide between frames.
class _Coach {
  String? key; // the card showing: [guideIntro] or a card's key (null: none)
  List<GuidePage> pages = const [];
  int page = 0; // its page showing, 0 first
  double since = 0; // when it opened, on the screen clock: it pops in
  bool tapped = false; // the last press was the card's: its tap up and drag stay there
  final hits = <(Rect, VoidCallback)>[]; // its buttons this frame (a greyed one does nothing)
  final buttons = <String, Rect>{}; // and by name, for tests: 'skip', 'back', 'next'
  Rect panel = Rect.zero; // the card as drawn this frame, its ribbon in (Rect.zero: none)
  // The pointer shown this frame (null: none), its box and what it points at; the game the pointers watch, its army
  // and its wave's number last frame; the breaks the first two and the item ones have waited, and whether the
  // item ones have begun (a break with an item in the bag).
  String? pointer;
  Rect pointerBox = Rect.zero, pointerTarget = Rect.zero;
  Game? game;
  int army = 0, wave = 0, firstBreaks = 0, itemBreaks = 0;
  bool itemBegun = false;
  // The break whose one-time card was opened: its game and its wave (one card a break, [Board._coachNews]).
  Game? cardGame;
  int cardWave = 0;

  bool get showing => key != null;

  /// The intro's pictures' own games, made once: "Gold and troops"' (gold for a Soldier, not for a Knight) and "Troop
  /// caps"' (five Priests: their type at its cap, decisions-log 201).
  late final rowsGame = () {
    final g = Game().boardRules();
    return g..gold = (g.priceOf('soldier') + g.priceOf('knight')) ~/ 2;
  }();
  late final capsGame = () {
    final g = Game().boardRules()..gold = 1 << 20;
    while (!g.typeFull(Game.freeHealer) && g.autoPlace(Game.freeHealer)) {}
    return g;
  }();
}

extension on Board {
  /// This device's seen set (null: the guide is off).
  Set<String>? get _seen => _settings.seen;

  /// [change] on the seen set; saved when it changed it.
  void _seeBy(void Function(Set<String> seen) change) {
    final seen = _seen;
    if (seen == null) return;
    final before = seen.length;
    change(seen);
    if (seen.length != before) saveSettings(_settings);
  }

  void _see(Iterable<String> keys) => _seeBy((s) => s.addAll(keys));

  /// Shows [key]'s pages from the first: the intro's ([guideIntro]) or a card's ([GuideText.cards]).
  void _coachOpen(String key) => _coach
    ..key = key
    ..pages = key == guideIntro ? guideEn.intro : guideEn.cards[key]!
    ..page = 0
    ..since = _clock;

  /// "New Game" started a game: the intro, while this device hasn't seen it.
  void _introIfNew() {
    if (_seen case final seen? when !seen.contains(guideIntro)) _coachOpen(guideIntro);
  }

  /// The one-time card due at this break ([guideNext]) opens, after the board's own news, as the army cap's warning
  /// waits ([_capNews]): between waves, once this game's won wave's "VICTORY!" is over (not before its first win: a
  /// save coming in has its own notes), while no Hero splash, foe skill splash, message, pause or drag is on. A boss
  /// chest due holds every card but the ones over it (K5, K12: [GuideRule.atChest]), which open [_coachOverChest] s
  /// after its popup. One card a break: none after one opened since the wave was won. Auto's countdown waits while it
  /// shows.
  void _coachNews(Game g) {
    final co = _coach, seen = _seen;
    if (seen == null || co.showing || !(g.canStartWave || g.inTown) || g.paused) return; // a Town's own card there (K23)
    if (identical(g, co.cardGame) && co.cardWave == g.wave) return;
    if (g.victoryAt == double.negativeInfinity || g.t - g.victoryAt < victoryTime) return;
    if (_msg.text != null || _herald.who != null || _herald.next.isNotEmpty || _foeSplashBusy) return; // foe_splash.dart
    if (dragging != null || _itemDrag != null || _relicDrag != null) return;
    final chest = _chest.open;
    if (chest ? _clock - _chest.since < _coachOverChest : _chestHolds(g)) return;
    if (guideNext(g, seen, chest: chest) case final key?) {
      co
        ..cardGame = g
        ..cardWave = g.wave;
      _coachOpen(key);
    }
  }

  /// The card closes, seen.
  void _coachClose() {
    final key = _coach.key;
    _coach.key = null;
    if (key != null) _see([key]);
  }

  void _coachNext() {
    if (_coach.page < _coach.pages.length - 1) {
      _coach.page++;
    } else {
      _coachClose();
    }
  }

  void _coachBack() {
    if (_coach.page > 0) _coach.page--;
  }

  /// A press while a card shows: its button acts, anywhere else it goes on; either way it is used up. True when the
  /// card took it.
  bool _coachDown(Offset p) {
    final co = _coach;
    if (!co.showing) return co.tapped = false;
    Sounds.play(Sfx.click);
    for (final (rect, fn) in [...co.hits]) {
      if (rect.contains(p)) {
        fn();
        return co.tapped = true;
      }
    }
    _coachNext();
    return co.tapped = true;
  }

  /// A key while a card shows: Space, Enter or → goes on, ← or Backspace goes back, Esc closes it, and P does nothing
  /// (the game under it doesn't pause). True when it was one of those.
  bool _coachKey(LogicalKeyboardKey key) {
    if (!_coach.showing) return false;
    if (key == LogicalKeyboardKey.space ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter ||
        key == LogicalKeyboardKey.arrowRight) {
      _coachNext();
    } else if (key == LogicalKeyboardKey.arrowLeft || key == LogicalKeyboardKey.backspace) {
      _coachBack();
    } else if (key == LogicalKeyboardKey.escape) {
      _coachClose();
    } else if (key != LogicalKeyboardKey.keyP) {
      return false;
    }
    return true;
  }

  /// What lies under a card takes nothing this frame: the book's and the HUD's buttons, rows, slots and tooltips (like
  /// the Hero splash; the field's plates: [_covered]).
  void _coachClear() {
    _hits.clear();
    _cards.clear();
    _slots.clear();
    _relicSlots.clear();
    _matSlots.clear();
    _pocketCells.clear();
    _plateTaps.clear();
    _tip.rows.clear();
    _tip.hints.clear();
    _tideAt = Rect.zero;
    _release.clear();
    _army.clear();
    _detail.clear();
    _bar.clear(); // the spawn bar's cards and pager (spawn_bar.dart)
    _assign.clear();
    _bag.clear(); // the Bag's cells, chips, pager and grid (bag.dart)
    _shop.clear(); // and the Town's Shop's
    _smithy.clear(); // and the Smithy's
    _tavernPage.clear(); // and the Tavern's
    _troops
      ..button = Rect.zero
      ..list = Rect.zero;
    _map.button = Rect.zero;
  }

  /// The card ([_Coach]) over the dimmed screen, popping in over [_heraldIn]: the panel in the tooltip frame's body, its
  /// picture ([_coachPicture]) and the page's lines beside it, the intro's counter and buttons or a card's "Tap to
  /// continue" at the bottom, and the ribbon with the title across its top. The text a little bigger than the screen
  /// scale, like the splash's.
  void _coachCard(Canvas c) {
    final co = _coach;
    co
      ..panel = Rect.zero
      ..hits.clear()
      ..buttons.clear();
    if (!co.showing) return;
    final intro = co.key == guideIntro, page = co.pages[co.page], pic = _coachPicture(co.key!, co.page);
    final t = _clock - co.since, pop = Curves.easeOutBack.transform((t / _heraldIn).clamp(0.0, 1.0));
    _coachClear();
    c.drawRect(Offset.zero & Size(size.x, size.y), Paint()..color = Colors.black.withValues(alpha: 0.65 * math.min(1, t / _heraldIn)));

    final s = _screenScale(Size(size.x, size.y)), f = s * 1.2;
    final k = s >= 0.9 ? 3.0 : 2.0, rk = k + 1, pad = 16 * s + 3 * k, gap = 16 * s, ribbonH = 20 * rk;
    final font = 18 * f, lineH = (font * 1.35).roundToDouble(), small = 14 * f;
    final room = size.x - 2 * _coachEdge - 2 * pad; // the most a panel's inside may be
    final lines = [for (final l in page.linesFor(touch: _touch)) ..._wrap(l, font, math.min(room, 380 * s))];
    final textW = lines.fold(0.0, (w, l) => math.max(w, _textWidth(l, font))), textH = lines.length * lineH;
    final picW = pic == null ? 0.0 : (180 * s * pic.$1).floorToDouble();
    final picH = pic == null ? 0.0 : (picW / pic.$1).floorToDouble();
    final inner = pic == null ? Size(textW, textH) : Size(picW + gap + textW, math.max(picH, textH));
    // The footer: the intro's counter over its three buttons, or a card's hint (its page count when it has more).
    final labels = guideEn.labels, last = co.page == co.pages.length - 1;
    final btnH = math.max(32.0, 30 * f).roundToDouble(), btnFont = 16 * f, bk = (btnH / 16).floorToDouble().clamp(1.0, 3.0);
    final btnMin = [labels.skip, labels.back, labels.next, labels.play].map((l) => _textWidth(l, btnFont) + 2 * (4 * bk + 6)).reduce(math.max);
    final hint = co.pages.length > 1 ? '${labels.tapOn}  ${co.page + 1}/${co.pages.length}' : labels.tapOn;
    final footH = intro ? small * 1.6 + btnH : small * 1.8;
    final innerW = math.max(inner.width, intro ? 3 * btnMin + 2 * gap : _textWidth(hint, small));
    final panel = Rect.fromCenter(
        center: Offset(size.x / 2, size.y / 2 + ribbonH / 4),
        width: (innerW + 2 * pad).roundToDouble(),
        height: (ribbonH / 2 + inner.height + gap + footH + 2 * pad).roundToDouble());

    c.save();
    c.translate(panel.center.dx, panel.center.dy);
    c.scale(0.6 + 0.4 * pop);
    c.translate(-panel.center.dx, -panel.center.dy);
    c.drawRect(panel.shift(const Offset(0, 6)).deflate(4), Paint()..color = Colors.black.withValues(alpha: 0.3));
    _nine(c, _tipBody, panel, k, l: 3, t: 3, r: 3, b: 5, sheet: 'ui_tooltip.png');
    final top = panel.top + pad + ribbonH / 2, middle = top + inner.height / 2;
    final centred = pic == null;
    var y = middle - textH / 2, x = panel.center.dx;
    if (pic != null) {
      final at = Rect.fromLTWH(panel.left + pad, middle - picH / 2, picW, picH);
      _coachPicturing(c, pic.$2, at);
      x = at.right + gap;
    }
    _coachClear(); // the picture's rows registered their tooltips and chips
    for (final l in lines) {
      _text(c, l, Offset(x, y + lineH / 2), size: font, color: _dark, anchor: centred ? Anchor.center : Anchor.centerLeft);
      y += lineH;
    }
    if (intro) {
      _text(c, guideEn.counter(co.page + 1), Offset(panel.center.dx, panel.bottom - pad - btnH - small * 0.8), size: small,
          color: _tipInk, anchor: Anchor.center);
      final row = Rect.fromLTWH(panel.left + pad, panel.bottom - pad - btnH, panel.width - 2 * pad, btnH), bw = (row.width - 2 * gap) / 3;
      Rect slot(int j) => Rect.fromLTWH((row.left + j * (bw + gap)).roundToDouble(), row.top, bw.roundToDouble(), btnH);
      double fit(String label) => math.min(btnFont, btnFont * (bw - 2 * (4 * bk + 4)) / math.max(1, _textWidth(label, btnFont)));
      final next = last ? labels.play : labels.next;
      _button(c, co.buttons['skip'] = slot(0), _coachClose, label: labels.skip, size: fit(labels.skip));
      _button(c, co.buttons['back'] = slot(1), _coachBack, label: labels.back, size: fit(labels.back), enabled: co.page > 0);
      _button(c, co.buttons['next'] = slot(2), _coachNext, row: Board._btnGreen, label: next, size: fit(next));
    } else {
      _text(c, hint, Offset(panel.center.dx, panel.bottom - pad - footH / 2), size: small, color: _tipInk.withValues(alpha: 0.6),
          anchor: Anchor.center);
    }
    final ribbon = _ribbonTitle(c, page.title, Offset(panel.center.dx, panel.top), rk, size.x - 2 * _coachEdge); // hero_splash.dart
    c.restore();
    co
      ..panel = panel.expandToInclude(ribbon)
      ..hits.addAll(_hits);
    if (intro && co.page == 0) co.hits.add((co.buttons['back']!, () {})); // greyed: a tap on it does nothing
  }

  /// Draws a picture [paint] in [box] as a still: nothing in it lights under the mouse or sinks under a press.
  void _coachPicturing(Canvas c, void Function(Canvas c, Rect box) paint, Rect box) {
    final mouse = _mouse, press = _press;
    _mouse = null;
    _press = null;
    paint(c, box);
    _mouse = mouse;
    _press = press;
  }

  /// [key]'s page [page]'s picture: how wide it is for its height, and how it draws itself in a box; null: none (the
  /// lines take the panel). The intro's, then the one-time cards'.
  (double, void Function(Canvas c, Rect box))? _coachPicture(String key, int page) => switch ((key, page)) {
        (guideIntro, 0) => (1.3, _picSquad),
        (guideIntro, 1) => (1.7, _picGoldRows),
        (guideIntro, 2) => (1.7, _picCaps),
        (guideIntro, 3) => (1.3, _picRoom),
        (guideIntro, 4) => (1.3, _picFight),
        (guideIntro, 5) => (1.3, _picWaves),
        (guideIntro, 6) => (1.3, _picLoot),
        ('K0', _) => (1.7, _picItems),
        ('K1', _) => (1.3, _picFell),
        ('K2', _) => (1.7, _picRanks),
        ('K3', _) => (1.3, _picHealer),
        ('K4', 0) => (1.3, _picRoom),
        ('K4', _) => (1.3, _picBoss),
        ('K5', 0) => (1.7, _picChestCards),
        ('K5', _) => (1.3, _picChestButtons),
        ('K6', _) => (1.3, _picPusaka),
        ('K7', _) => (1.3, _picRelic),
        ('K8', _) => (1.3, _picLimits),
        ('K9', _) => (1.7, _picBangkit),
        ('K10', _) => (1.3, _picHero),
        ('K11', _) => (1.7, _picToko),
        ('K12', _) => (1.3, _picLegenda),
        ('K13', _) => (1.7, _picCaps),
        ('K14', _) => (1.3, _picHeroFell),
        ('K15', _) => (1.7, _picFull),
        ('K16', _) => (1.3, _picStall),
        ('K17', _) => (1.3, _picTide),
        ('K18', _) => (1.7, _picSpend),
        ('K19', _) => (1.3, _picEscorts),
        ('K20', _) => (1.7, _picAsah),
        ('K21', _) => (1.7, _picLebur),
        ('K22', _) => (1.7, _picCarve),
        ('K23', _) => (1.7, _picTown),
        ('K24', _) => (1.7, _picMaterials),
        ('K25', 0) => (1.7, _picShadowCards),
        ('K25', _) => (1.3, _picShadowChips),
        _ => null,
      };

  /// [type]'s field strip [anim] (`tiny_<type>_<anim>.png`) with its shadow, its feet at [feet], [k] screen px per sprite
  /// px; [flip] faces it left (a monster). [f] holds one frame (else it plays); [paint] and [line] are a rank's body and
  /// outline ([_tierPaints], [_tierLines]) or an awakening's outline ([_awakeLine]); [ring] puts that Pusaka's ring under
  /// it ([_pusakaRing]).
  void _picUnit(Canvas c, String type, String anim, Offset feet, double k,
      {bool flip = false, int? f, Paint? paint, Paint? line, Relic? ring}) {
    c.save();
    c.translate(feet.dx, feet.dy);
    c.scale(k);
    _frame(c, 'tiny_${type}_shadow.png', 0, Offset.zero, flip: flip);
    if (ring != null) _ringUnder(c, Offset.zero, ring);
    _frame(c, 'tiny_${type}_$anim.png', f ?? (_clock * _fps).floor(), Offset.zero, flip: flip, paint: paint, line: line);
    c.restore();
  }

  /// Troop [type]'s book sprite (its visible pixels) standing in [r], at its bottom middle; [line] its awakening's
  /// outline.
  void _picSprite(Canvas c, String type, Rect r, {Paint? paint, Paint? line}) {
    final b = _idleBounds[type]!, k = math.min(r.width / b.width, r.height / b.height);
    c.save();
    c.translate(r.center.dx, r.bottom);
    c.scale(k);
    _frame(c, 'book_${type}_idle', (_clock * _fps).floor(), Offset.zero, anchor: Offset(b.center.dx, b.bottom), paint: paint, line: line);
    c.restore();
  }

  /// A unit's bar as the field draws it ([unitBar], ui_bars.png), over a unit whose feet are the canvas's origin: [hp]
  /// of its HP left (a troop's green, a monster's red, or a [tier]'s colour as [_unit] fills it), and with [mp] that
  /// much MP under it.
  void _picBar(Canvas c, double hp, {double? mp, bool troop = true, Tier? tier}) {
    const k = barK;
    final bar = unitBar(0, -5, mp: mp != null), box = bar.box, bars = _img('ui_bars.png');
    c.drawImageRect(bars, const Rect.fromLTWH(82, 34, 12, 4), Rect.fromLTRB(box.left, box.top + k - 0.05, box.right, box.bottom - k + 0.05), _px);
    c.drawImageRect(bars, const Rect.fromLTWH(82, 33, 12, 1), Rect.fromLTWH(box.left, box.top, box.width, k), _px);
    c.drawImageRect(bars, const Rect.fromLTWH(82, 37, 12, 1), Rect.fromLTWH(box.left, box.bottom - k, box.width, k), _px);
    final fill = Rect.fromLTWH(bar.hp.left, bar.hp.top, bar.hp.width * hp, bar.hp.height);
    if (_tierBar[tier] case (final top, final shade)?) {
      final line = fill.bottom - fill.height / 4;
      c.drawRect(Rect.fromLTRB(fill.left, fill.top, fill.right, line), Paint()..color = top);
      c.drawRect(Rect.fromLTRB(fill.left, line, fill.right, fill.bottom), Paint()..color = shade);
    } else {
      c.drawImageRect(bars, Rect.fromLTWH(83, troop ? 58.0 : 42.0, 10 * hp, 4), fill, _px);
    }
    if ((bar.mp, mp) case (final full?, final m?)) {
      c.drawImageRect(bars, Rect.fromLTWH(83, 50, 10 * m, 4), Rect.fromLTWH(full.left, full.top, full.width * m, full.height), _px);
    }
  }

  /// I1: the squad on the left facing right, two monsters coming from the right, and the hearts over them (the lives'
  /// own icons: two full, one half).
  void _picSquad(Canvas c, Rect box) {
    final k = box.height * 0.3 / _idleBounds['soldier']!.height, ground = box.top + box.height * 0.84;
    for (final (type, at) in const [('priest', 0.12), ('archer', 0.27), ('soldier', 0.43)]) {
      _picUnit(c, type, 'walk', Offset(box.left + box.width * at, ground), k);
    }
    _picUnit(c, 'slime', 'walk', Offset(box.left + box.width * 0.7, ground), k, flip: true);
    _picUnit(c, 'orc', 'walk', Offset(box.left + box.width * 0.88, ground), k, flip: true);
    final h = (box.height * 0.2).roundToDouble(), y = box.top + box.height * 0.06;
    for (final (i, halves) in const [2, 2, 1].indexed) {
      c.drawImageRect(_img('ui_icons.png'), _heartIcons[halves], Rect.fromLTWH(box.center.dx + (i - 1.5) * h * 1.1, y, h, h), _px);
    }
  }

  /// [g]'s gold on ui_book_marks.png's orange ribbon with the coin and the sum ([value]: written another way), [h] tall,
  /// its middle at [mid]. The book's own gold ribbon is gone (decisions-log 285); the HUD's gold panel is drawn in code,
  /// so the picture keeps the sheet's flag.
  void _picGold(Canvas c, Game g, Offset mid, double h, {String? value}) {
    final ps = h / 18, font = math.max(12.0, 9 * ps);
    value ??= '${g.gold}';
    final w = (3 + 16 + _textWidth(value, font) / ps + 2 + 11) * ps, at = Rect.fromCenter(center: mid, width: w, height: h);
    _nine(c, Board._ribbonClosed(Board._ribOrange), at, ps, l: 1, t: 0, r: 10, b: 0, sheet: 'ui_book_marks.png');
    _uiIcon(c, Board._icCoin, Rect.fromLTWH(at.left + 3 * ps, at.top + ps, 16 * ps, 16 * ps));
    _text(c, value, Offset(at.left + 21 * ps, at.top + 9 * ps), size: font, color: const Color(0xFF3B2210));
  }

  /// [types]' Army cells of [g] ([_typeCell]) side by side in [area], as the book's grid draws them. Returns each
  /// cell's rect.
  List<Rect> _picCells(Canvas c, Game g, List<String> types, Rect area) {
    final gap = (area.width * 0.04).roundToDouble(), w = ((area.width - gap * (types.length - 1)) / types.length).floorToDouble();
    final h = math.min(area.height, w).floorToDouble(), top = (area.center.dy - h / 2).roundToDouble();
    final cells = [for (final (i, _) in types.indexed) Rect.fromLTWH((area.left + i * (w + gap)).roundToDouble(), top, w, h)];
    for (final (i, type) in types.indexed) {
      _typeCell(c, g, type, cells[i], h / 90, area);
    }
    return cells;
  }

  /// I2 (decisions-log 283, 287): the gold over two of the spawn bar's slots on a piece of its hotbar ([_barCard], as the
  /// bar draws them): one it buys (the coin and the price in cream), one it doesn't (the coin faded, the price grey).
  void _picGoldRows(Canvas c, Rect box) {
    final g = _coach.rowsGame, top = box.height * 0.3;
    _picGold(c, g, Offset(box.center.dx, box.top + top / 2), top * 0.7);
    final room = Rect.fromLTRB(box.left, box.top + top, box.right, box.bottom);
    // The hotbar's frame as the bar's ([hotbarPx]) where the picture's slots are as big as the bar's, else smaller: two
    // slots 5 sprite px apart and from the panel's edges.
    final k = math.min(hotbarPx, math.max(1.0, (room.height / 38).floorToDouble())), m = 5 * k;
    final s = math.min(room.height - 2 * m, (room.width - 3 * m) / 2).floorToDouble();
    final panel = Rect.fromCenter(center: room.center, width: 2 * s + 3 * m, height: s + 2 * m);
    _nine(c, const Rect.fromLTWH(0, 0, 11, 28), _whole(panel), k, l: 3, t: 3, r: 3, b: 3, sheet: 'ui_hotbar.png');
    for (final (i, type) in const ['soldier', 'knight'].indexed) {
      _barCard(c, g, type, Rect.fromLTWH(_whole(panel).left + m + i * (s + m), _whole(panel).top + m, s, s), k, still: true);
    }
  }

  /// I3 and K13: a type at its cap (decisions-log 201): the free Priest's cell at "x5/5" in red, and the Archer's that
  /// still buys.
  void _picCaps(Canvas c, Rect box) => _picCells(c, _coach.capsGame, const [Game.freeHealer, 'archer'], box);

  /// I4 (and K4's first page, getting ready for the boss): the room at first, a troop a cell ([capacityStart]), and
  /// [capacityStep] more cells faded; "+Room" with its price under them (the spawn bar's button, decisions-log 283; the
  /// Army page header's from decisions-log 260).
  void _picRoom(Canvas c, Rect box) {
    final types = troopTypes.keys.toList(), n = capacityStart + capacityStep, perRow = (n + 1) ~/ 2;
    final cellW = box.width / perRow, cellH = box.height * 0.3;
    for (var i = 0; i < n; i++) {
      final cell = Rect.fromLTWH(box.left + i % perRow * cellW, box.top + i ~/ perRow * cellH * 1.1, cellW, cellH).deflate(cellH * 0.08);
      _picSprite(c, types[i % types.length], cell, paint: i < capacityStart ? null : _ghost);
    }
    final g = _coach.rowsGame, label = '${Words.room}  ${shortPrice(g.capacityCost)}', h = (box.height * 0.24).roundToDouble();
    final font = math.min(h * 0.45, h * 0.45 * box.width * 0.9 / _textWidth(label, h * 0.45));
    final btn = Rect.fromCenter(center: Offset(box.center.dx, box.bottom - h / 2), width: math.min(box.width, _textWidth(label, font) + h), height: h);
    final bk = (h / 16).floorToDouble().clamp(1.0, 3.0), sink = _btnFrame(c, btn, Board._btnLight, ButtonLook.normal, bk);
    _text(c, label, btn.center + Offset(0, sink - bk), size: font, anchor: Anchor.center, color: const Color(0xFF3B2210));
  }

  /// I5: a Ksatria hitting a monster, both with their bars (the troop's HP over its blue MP), the hit's burst on it.
  void _picFight(Canvas c, Rect box) {
    final k = box.height * 0.36 / _idleBounds['knight']!.height, ground = box.top + box.height * 0.86;
    final knight = Offset(box.left + box.width * 0.34, ground), orc = Offset(box.left + box.width * 0.66, ground);
    _picUnit(c, 'knight', 'attack', knight, k);
    _picUnit(c, 'orc', 'hurt', orc, k, flip: true);
    for (final (at, troop) in [(knight, true), (orc, false)]) {
      c.save();
      c.translate(at.dx, at.dy);
      c.scale(k);
      _picBar(c, troop ? 0.8 : 0.45, mp: troop ? 0.55 : null, troop: troop);
      c.restore();
    }
    final burst = 'fx_hit_knight.png', fs = _img(burst).height.toDouble();
    c.save();
    c.translate(orc.dx, orc.dy - 9 * k);
    c.scale(24 * k / fs);
    _frame(c, burst, (_clock * _fxFps).floor(), Offset.zero, anchor: Offset(fs / 2, fs / 2));
    c.restore();
  }

  /// I6: the start button counting down with Auto on, and the Auto toggle lit ("Auto Wave", [Words.autoWave]), as the
  /// top band draws them.
  void _picWaves(Canvas c, Rect box) {
    final h = (box.height * 0.32).roundToDouble(), k = (h / 16).floorToDouble().clamp(1.0, 3.0), font = h * 0.42;
    final ik = math.max(1.0, ((h - 10 * k) / 12).floorToDouble()), inset = 4 * k + 6, label = '${Words.start} ${autoStartDelay.ceil()}';
    final startW = inset + 7 * ik + 6 + _textWidth(label, font) + inset, autoW = _textWidth(Words.autoWave, font) + 2 * (4 * k + 6), gap = 8.0;
    final all = startW + gap + autoW, fit = math.min(1.0, box.width / all);
    c.save();
    c.translate(box.center.dx, box.center.dy);
    c.scale(fit);
    final start = Rect.fromLTWH((-all / 2).roundToDouble(), -h / 2, startW.roundToDouble(), h);
    final auto = Rect.fromLTWH(start.right + gap, -h / 2, autoW.roundToDouble(), h);
    final sink = _btnFrame(c, start, Board._btnGreen, ButtonLook.normal, k), mid = start.center.dy - k + sink;
    c.drawImageRect(_img('ui_icons.png'), _startIcon & const Size(16, 16),
        Rect.fromLTWH(start.left + inset - 5 * ik, (mid - 8 * ik).roundToDouble(), 16 * ik, 16 * ik), _px);
    _text(c, label, Offset(start.left + inset + 7 * ik + 6, mid), size: font, color: const Color(0xFF3B2210));
    _btnFrame(c, auto, Board._btnOrange, ButtonLook.normal, k);
    _text(c, Words.autoWave, auto.center + Offset(0, -k), size: font, anchor: Anchor.center, color: const Color(0xFF3B2210));
    c.restore();
  }

  /// I7: the win's gold and a field's loot going to the bag: the coins, two items, an arrow and the Tas tab's bag.
  void _picLoot(Canvas c, Rect box) => _picStrip(c, box, [
        (r) => _uiIcon(c, _icCoins, r),
        (r) => _icon(c, Item.sword, r),
        (r) => _icon(c, Item.potion, r),
        _picArrow(c),
        (r) => _uiIcon(c, Board._icBag, r),
      ]);

  /// [cells] side by side in square cells, centred in [box] round [y] of its height: as big as [h] of its height, or
  /// as the width lets them be (a gap of 0.15 of a cell between them).
  void _picStrip(Canvas c, Rect box, List<void Function(Rect r)> cells, {double y = 0.5, double h = 0.32}) {
    final n = cells.length, s = math.min(box.height * h, box.width / (n + (n - 1) * 0.15)), gap = s * 0.15;
    var x = box.center.dx - (n * s + (n - 1) * gap) / 2;
    for (final draw in cells) {
      draw(Rect.fromLTWH(x, box.top + box.height * y - s / 2, s, s));
      x += s + gap;
    }
  }

  /// A strip's cell with ui_icons.png's red ▶ ("then", "goes to").
  void Function(Rect r) _picArrow(Canvas c) => (r) => _uiIcon(c, _icArrowRight, r.deflate(r.width * 0.15));

  /// A button as the book draws it (ui_buttons.png's [row]) in [r], its [label] fitted on it: a still, it takes no press.
  void _picButton(Canvas c, Rect r, String label, {int row = Board._btnLight}) {
    final k = (r.height / 16).floorToDouble().clamp(1.0, 3.0), sink = _btnFrame(c, r, row, ButtonLook.normal, k), font = r.height * 0.45;
    _text(c, label, r.center + Offset(0, sink - k), size: math.min(font, font * (r.width - 2 * (4 * k + 4)) / _textWidth(label, font)),
        anchor: Anchor.center, color: const Color(0xFF3B2210));
  }

  /// A shut page tab of the book (ui_book_marks.png's tan one) as wide as [r], in its middle, with [icon] on it; with
  /// [dot] the red dot the Tas and Army tabs get when there is something to do there ([_tabDot]).
  void _picTab(Canvas c, Offset icon, Rect r, {bool dot = false}) {
    final ps = r.width / Board._tabTan.width, at = Rect.fromLTWH(r.left, r.center.dy - Board._tabTan.height * ps / 2, r.width, Board._tabTan.height * ps);
    c.drawImageRect(_img('ui_book_marks.png'), Board._tabTan, at, _px);
    final ic = Rect.fromLTWH(at.left + 2 * ps, at.top + ps, 16 * ps, 16 * ps);
    _uiIcon(c, icon, ic);
    if (dot) {
      _tabDot(c, ic, ps, 'coach'); // ascend_page.dart
      _storeAt.remove('coach');
    }
  }

  /// A Boss Chest card for [relic] in [r] as the chest's popup draws one ([_chestCard]): its page frame in its rarity's
  /// colours, the Pusaka's icon on its rarity's glow, and the star it comes with.
  void _picChestCard(Canvas c, Rect r, Relic relic) {
    _card(c, r, Board._framePlain, _rarityFramePaints[relic.rarity]);
    final icon = r.width * 0.6, at = Rect.fromCenter(center: Offset(r.center.dx, r.top + r.height * 0.42), width: icon, height: icon);
    c.drawCircle(at.center, icon * 0.5, Paint()..color = _rarityInk[relic.rarity]!.withValues(alpha: 0.3));
    _icon(c, relic, Board._iconIn(relic, at, icon * 0.1));
    final star = r.height * 0.14;
    _uiIcon(c, _icStar, Rect.fromCenter(center: Offset(r.center.dx, r.bottom - r.height * 0.17), width: star, height: star));
  }

  /// A Pusaka's icon in [r] on the store's gold glow.
  void _picPusakaIcon(Canvas c, Relic relic, Rect r) {
    c.drawCircle(r.center, r.width * 0.5, Paint()..color = _artefactGlow);
    _icon(c, relic, Board._iconIn(relic, r, r.width * 0.1));
  }

  /// K0: an item for a type: the sword, ▶, and three of the type's troops.
  void _picItems(Canvas c, Rect box) => _picStrip(c, box, [
        (r) => _icon(c, Item.sword, r),
        _picArrow(c),
        for (var i = 0; i < 3; i++) (r) => _picSprite(c, 'soldier', r),
      ]);

  /// K1: three troops fallen (their death strips' last frames) over "Replace fallen".
  void _picFell(Canvas c, Rect box) {
    final k = box.height * 0.24 / _idleBounds['knight']!.height, ground = box.top + box.height * 0.5;
    for (final (type, at) in const [('soldier', 0.17), ('archer', 0.5), ('knight', 0.83)]) {
      _picUnit(c, type, 'death', Offset(box.left + box.width * at, ground), k, f: _frames('tiny_${type}_death.png') - 1);
    }
    final h = (box.height * 0.28).roundToDouble();
    _picButton(c, Rect.fromLTWH(box.left, box.bottom - h, box.width, h), Words.replaceFallen);
  }

  /// K2: the ranks' colours: four orcs coming, silver, gold, purple and orange, each with its bar in its colour.
  void _picRanks(Canvas c, Rect box) {
    final k = box.height * 0.32 / _idleBounds['orc']!.height, ground = box.top + box.height * 0.9;
    for (final (i, tier) in const [Tier.elite, Tier.highElite, Tier.miniBoss, Tier.boss].indexed) {
      final feet = Offset(box.left + box.width * (0.14 + 0.24 * i), ground);
      _picUnit(c, 'orc', 'walk', feet, k, flip: true, paint: _tierPaints[tier], line: _tierLines[tier]);
      c.save();
      c.translate(feet.dx, feet.dy);
      c.scale(k);
      _picBar(c, 1, troop: false, tier: tier);
      c.restore();
    }
  }

  /// K3: the healing necromancer at the back casting, its heal on the orc in front of it, a Ksatria hitting the orc.
  void _picHealer(Canvas c, Rect box) {
    final k = box.height * 0.3 / _idleBounds['orc']!.height, ground = box.top + box.height * 0.86;
    final orc = Offset(box.left + box.width * 0.42, ground);
    _picUnit(c, 'knight', 'attack', Offset(box.left + box.width * 0.14, ground), k);
    _picUnit(c, 'orc', 'idle', orc, k, flip: true);
    _picUnit(c, necroHealer, 'cast', Offset(box.left + box.width * 0.76, ground), box.height * 0.5 / _idleBounds[boss]!.height,
        flip: true); // the boss recoloured: its sprite's size
    c.save();
    c.translate(orc.dx, orc.dy);
    c.scale(k);
    _frame(c, 'tiny_fx_heal.png', (_clock * _fps).floor(), Offset.zero);
    c.restore();
  }

  /// K4's second page: the boss coming (its rank's orange), and what it leaves: two items and the chest.
  void _picBoss(Canvas c, Rect box) {
    final k = box.height * 0.62 / _idleBounds[boss]!.height;
    _picUnit(c, boss, 'walk', Offset(box.left + box.width * 0.3, box.top + box.height * 0.92), k,
        flip: true, paint: _tierPaints[Tier.boss], line: _tierLines[Tier.boss]);
    final s = math.min(box.height * 0.3, box.width * 0.2), x = box.right - 2.1 * s;
    _icon(c, Item.sword, Rect.fromLTWH(x, box.top + box.height * 0.12, s, s));
    _icon(c, Item.shield, Rect.fromLTWH(x + s * 1.1, box.top + box.height * 0.12, s, s));
    _uiIcon(c, _icChest, Rect.fromLTWH(x + s * 0.55, box.top + box.height * 0.55, s, s));
  }

  /// K5's first page: three Boss Chest cards, a Rare, an Epic and a Legendary.
  void _picChestCards(Canvas c, Rect box) {
    final gap = box.width * 0.05, w = (box.width - 2 * gap) / 3, h = math.min(box.height, w * 1.4);
    for (final (i, relic) in const [Relic.ironBanner, Relic.grail, Relic.dragonCrown].indexed) {
      _picChestCard(c, Rect.fromLTWH(box.left + i * (w + gap), box.center.dy - h / 2, w, h), relic);
    }
  }

  /// K25's first page: K5's three cards a little shorter, each with the Shadow it hides under it as the popup shows it:
  /// "?" and its rarity's red "!" marks ([omenMarks]: Rare 1, Epic 2, Legendary 3; omen_look.dart's [_omenMarks]).
  void _picShadowCards(Canvas c, Rect box) {
    final gap = box.width * 0.05, w = (box.width - 2 * gap) / 3, h = math.min(box.height * 0.74, w * 1.4), mark = box.height * 0.16;
    final top = box.top + (box.height - h - mark * 1.5) / 2;
    for (final (i, relic) in const [Relic.ironBanner, Relic.grail, Relic.dragonCrown].indexed) {
      final r = Rect.fromLTWH(box.left + i * (w + gap), top, w, h), n = omenMarks[relic.rarity]!;
      _picChestCard(c, r, relic);
      _omenMarks(c, Offset(r.center.dx - omenMarksWidth(n, mark) / 2, r.bottom + mark), mark, n);
    }
  }

  /// K25's second page: the Shadows' chips as the HUD shows them ([_omenChips]): three kinds' icons on their red glow,
  /// each with its level, on the HUD's dark panel.
  void _picShadowChips(Canvas c, Rect box) {
    const kinds = [(OmenKind.armor, 2), (OmenKind.haste, 1), (OmenKind.wound, 3)];
    final icon = math.min(box.height * 0.5, box.width / 5), chipW = icon * 11 / 7, pad = icon * 2 / 7;
    final w = 2 * pad + kinds.length * chipW, at = Rect.fromCenter(center: box.center, width: w, height: icon + 2 * pad);
    _panel(c, at);
    for (final (i, (kind, level)) in kinds.indexed) {
      final ic = Rect.fromLTWH(at.left + pad + i * chipW, at.top + pad, icon, icon);
      c.drawCircle(ic.center, icon * 0.5, Paint()..color = _monsterPop.withValues(alpha: 0.3));
      _omenIcon(c, state, kind, ic);
      _text(c, '$level', Offset(ic.right + icon / 14, ic.center.dy + icon / 14), size: icon * 5 / 7);
    }
  }

  /// K5's second page: the chest's three buttons, one over the other, Take in its green (decisions-log 281).
  void _picChestButtons(Canvas c, Rect box) {
    final h = (box.height * 0.27).roundToDouble(), gap = (box.height - 3 * h) / 2, w = box.width * 0.8;
    for (final (i, label) in const [Words.reroll, Words.skip, Words.take].indexed) {
      _picButton(c, Rect.fromLTWH(box.center.dx - w / 2, box.top + i * (h + gap), w, h), label,
          row: label == Words.take ? Board._btnGreen : Board._btnLight);
    }
  }

  /// K6: a Pusaka over three troops of its type, its ring under each.
  void _picPusaka(Canvas c, Rect box) {
    final icon = box.height * 0.36;
    _picPusakaIcon(c, Relic.grail, Rect.fromCenter(center: Offset(box.center.dx, box.top + icon * 0.55), width: icon, height: icon));
    final k = box.height * 0.26 / _idleBounds['knight']!.height, ground = box.top + box.height * 0.9;
    for (final x in const [0.2, 0.5, 0.8]) {
      _picUnit(c, 'knight', 'idle', Offset(box.left + box.width * x, ground), k, ring: Relic.grail);
    }
  }

  /// K7: a small relic for one troop: the relic, ▶, a troop.
  void _picRelic(Canvas c, Rect box) => _picStrip(c, box, [
        (r) => _icon(c, Relic.fang, r),
        _picArrow(c),
        (r) => _picSprite(c, 'knight', r),
      ], h: 0.42);

  /// K8: a type's whole item list (the Ksatria's), and the type going from plain to its first Bangkit's outline.
  void _picLimits(Canvas c, Rect box) {
    _picStrip(c, box, [for (final item in awakenRecipe['knight']!.keys) (r) => _icon(c, item, r)], y: 0.2, h: 0.3);
    _picStrip(c, box, [(r) => _picSprite(c, 'knight', r), _picArrow(c), (r) => _picSprite(c, 'knight', r, line: _awakeLine(1))],
        y: 0.7, h: 0.48);
  }

  /// K9: the Tas tab with its red dot, ▶, a troop in its first Bangkit's outline, the green up arrow.
  void _picBangkit(Canvas c, Rect box) => _picStrip(c, box, [
        (r) => _picTab(c, Board._icBag, r, dot: true),
        _picArrow(c),
        (r) => _picSprite(c, 'knight', r, line: _awakeLine(1)),
        (r) => _uiIcon(c, _icUpGreen, r.deflate(r.width * 0.15)),
      ], h: 0.4);

  /// K10: a Hero as its splash shows it ([_heroPortrait]): this game's own, else the free Pendeta.
  void _picHero(Canvas c, Rect box) {
    final u = state.troops.where((u) => u.hero && u.alive).firstOrNull ?? _coach.rowsGame.troops.first;
    _heroPortrait(c, u, Rect.fromCenter(center: box.center, width: box.height, height: box.height), _clock - _coach.since);
  }

  /// K11: the Shop's tab (a Town's), and two materials, for gold: what a Town's Shop sells since the forge (decisions-log
  /// 317; a Sword and a Fang until then, from before it).
  void _picToko(Canvas c, Rect box) => _picStrip(c, box, [
        (r) => _picTab(c, _icCoins, r),
        _picArrow(c),
        (r) => _icon(c, Mat.orcTooth, r),
        (r) => _icon(c, Mat.wolfClaw, r),
        (r) => _uiIcon(c, Board._icCoin, r.deflate(r.width * 0.1)),
      ]);

  /// K12: two Legendary cards: the Dragon Crown and an Oath.
  void _picLegenda(Canvas c, Rect box) {
    final gap = box.width * 0.08, w = math.min((box.width - gap) / 2, box.height / 1.4), h = w * 1.4;
    for (final (i, relic) in const [Relic.dragonCrown, Relic.oathOfOne].indexed) {
      _picChestCard(c, Rect.fromLTWH(box.center.dx - w - gap / 2 + i * (w + gap), box.center.dy - h / 2, w, h), relic);
    }
  }

  /// K14: a fallen Hero (faded, its crown on), ▶, the tab that calls it back: the Army's (its type's detail,
  /// decisions-log 230).
  void _picHeroFell(Canvas c, Rect box) {
    final type = state.fallenHeroes.firstOrNull?.type ?? 'knight';
    _picStrip(c, box, [
      (r) {
        _picSprite(c, type, r.deflate(r.width * 0.08), paint: _ghost);
        _uiIcon(c, _icCrown, Rect.fromLTWH(r.right - r.width * 0.4, r.top - r.width * 0.1, r.width * 0.4, r.width * 0.4));
      },
      _picArrow(c),
      (r) => _picTab(c, Board._icSwords, r),
    ], h: 0.42);
  }

  /// K15: the army at its most ([armyMaxBoard]: "36/36") over two full rows of troops.
  void _picFull(Canvas c, Rect box) {
    final types = troopTypes.keys.toList(), top = box.height * 0.22, perRow = 8;
    _text(c, '$armyMaxBoard/$armyMaxBoard', Offset(box.right - 4, box.top + top / 2), size: top * 0.6, color: const Color(0xFF4A2C17),
        anchor: Anchor.centerRight);
    final cellW = box.width / perRow, cellH = (box.height - top) / 2;
    for (var i = 0; i < 2 * perRow; i++) {
      _picSprite(c, types[i % types.length],
          Rect.fromLTWH(box.left + i % perRow * cellW, box.top + top + i ~/ perRow * cellH, cellW, cellH).deflate(cellH * 0.06));
    }
  }

  /// K16: a wave that took too long: its monsters marching on, a heart and a half lost (the lives' own icons).
  void _picStall(Canvas c, Rect box) {
    final h = (box.height * 0.22).roundToDouble();
    for (final (i, halves) in const [2, 1, 0].indexed) {
      c.drawImageRect(_img('ui_icons.png'), _heartIcons[halves], Rect.fromLTWH(box.center.dx + (i - 1.5) * h * 1.1, box.top + box.height * 0.04, h, h), _px);
    }
    final k = box.height * 0.32 / _idleBounds['orc']!.height, ground = box.top + box.height * 0.88;
    for (final (type, at) in const [('skeleton', 0.2), ('orc', 0.5), ('slime', 0.8)]) {
      _picUnit(c, type, 'walk', Offset(box.left + box.width * at, ground), k, flip: true);
    }
  }

  /// K17: the tide: the same monster stronger wave by wave, drawn bigger each time, the red up arrows between.
  void _picTide(Canvas c, Rect box) {
    final k = box.height * 0.5 / _idleBounds['orc']!.height, ground = box.top + box.height * 0.88, a = box.height * 0.22;
    for (final (i, grow) in const [0.6, 0.8, 1.0].indexed) {
      _picUnit(c, 'orc', 'walk', Offset(box.left + box.width * (0.12 + 0.38 * i), ground), k * grow, flip: true);
      if (i < 2) _uiIcon(c, _icUpRed, Rect.fromLTWH(box.left + box.width * (0.31 + 0.38 * i) - a / 2, box.top + box.height * 0.2, a, a));
    }
  }

  /// K18: this game's gold waiting, over the tab with its red dot (the Army's, whose detail buys them, decisions-log
  /// 230), ▶, a type in Bangkit 4's outline, the green up arrow.
  void _picSpend(Canvas c, Rect box) {
    final top = box.height * 0.28;
    _picGold(c, state, Offset(box.center.dx, box.top + top / 2), top * 0.85, value: shortPrice(state.gold));
    _picStrip(c, Rect.fromLTRB(box.left, box.top + top, box.right, box.bottom), [
      (r) => _picTab(c, Board._icSwords, r, dot: true),
      _picArrow(c),
      (r) => _picSprite(c, 'knight', r, line: _awakeLine(maxAwaken + 1)),
      (r) => _uiIcon(c, _icUpGreen, r.deflate(r.width * 0.15)),
    ], h: 0.55);
  }

  /// K19: the boss coming with healing necromancers behind it.
  void _picEscorts(Canvas c, Rect box) {
    final kb = box.height * 0.62 / _idleBounds[boss]!.height, ground = box.top + box.height * 0.92;
    _picUnit(c, boss, 'walk', Offset(box.left + box.width * 0.25, ground), kb,
        flip: true, paint: _tierPaints[Tier.boss], line: _tierLines[Tier.boss]);
    for (final (i, x) in const [0.56, 0.72, 0.88].indexed) {
      _picUnit(c, necroHealer, 'walk', Offset(box.left + box.width * x, ground - (i.isOdd ? box.height * 0.12 : 0)), kb * 0.6, flip: true);
    }
  }

  /// K20: Asah: a Pusaka, relics and gold, ▶, a star.
  void _picAsah(Canvas c, Rect box) => _picStrip(c, box, [
        (r) => _picPusakaIcon(c, Relic.grail, r),
        (r) => _icon(c, Relic.fang, r),
        (r) => _uiIcon(c, Board._icCoin, r.deflate(r.width * 0.1)),
        _picArrow(c),
        (r) => _uiIcon(c, _icStar, r),
      ]);

  /// K21: Lebur: a spare Pusaka, ▶, another one, a star more.
  void _picLebur(Canvas c, Rect box) => _picStrip(c, box, [
        (r) => _picPusakaIcon(c, Relic.ironBanner, r),
        _picArrow(c),
        (r) => _picPusakaIcon(c, Relic.grail, r),
        (r) => _uiIcon(c, _icPlusGreen, r.deflate(r.width * 0.2)),
        (r) => _uiIcon(c, _icStar, r),
      ]);

  /// K22: Carve: spare items, ▶, a Pusaka, a bit more (the green plus, no star: Carve is never a star).
  void _picCarve(Canvas c, Rect box) => _picStrip(c, box, [
        (r) => _icon(c, Item.potion, r),
        (r) => _icon(c, Item.staff, r),
        _picArrow(c),
        (r) => _picPusakaIcon(c, Relic.grail, r),
        (r) => _uiIcon(c, _icPlusGreen, r.deflate(r.width * 0.2)),
      ]);

  /// K23: a Town: the Tavern's ale mug (the wave meter's "In town", a safe stop), ▶, the Smithy's hammer making a relic
  /// (town_mug.png, town_mark.png: decisions-log 216).
  void _picTown(Canvas c, Rect box) => _picStrip(c, box, [
        (r) => c.drawImageRect(_img('town_mug.png'), _townMarkSrc, r, _px),
        _picArrow(c),
        (r) => _townMark(c, r),
        (r) => _icon(c, Relic.cleave, r),
      ]);

  /// K24: materials (a Common part, a Rare part), ▶, the Smithy's hammer, a relic.
  void _picMaterials(Canvas c, Rect box) => _picStrip(c, box, [
        (r) => _icon(c, Mat.slimeGel, r),
        (r) => _icon(c, Mat.batWing, r),
        _picArrow(c),
        (r) => _townMark(c, r),
        (r) => _icon(c, Relic.fang, r),
      ]);

  /// The pointers' bookkeeping, every frame: each one ends on its action (P1 a troop bought: the army grew; P2 a wave
  /// started; P3 the Tas page open, P4 an item picked; P5 one given, [Board._useItem]), and the first two (P1, P2) or the
  /// item ones (P3-P5, from their first break with an item in the bag) not done in [_pointerBreaks] breaks are dropped
  /// as seen ([dropItemPointers]: K0 says it then).
  void _coachTick(Game g) {
    final co = _coach, seen = _seen;
    if (seen == null || welcome != null) return;
    if (!identical(g, co.game)) {
      co
        ..game = g
        ..army = g.armySize
        ..wave = g.wave
        ..firstBreaks = 0
        ..itemBreaks = 0
        ..itemBegun = false;
    }
    // A wave began since last frame: its number rose (even one won within its first tick).
    final started = g.wave > co.wave, rose = g.armySize > co.army;
    co
      ..wave = g.wave
      ..army = g.armySize;
    if (!seen.contains(guideIntro)) return;
    if (!seen.contains('P1')) {
      if (rose) {
        _see(['P1']);
      } else if (started && ++co.firstBreaks >= _pointerBreaks) {
        _see(['P1', 'P2']);
      }
    } else if (!seen.contains('P2') && (g.waveActive || started)) {
      _see(['P2']);
    }
    if (!seen.contains('P2') || seen.contains('P5')) return;
    if (g.canStartWave && _itemWaits(g)) {
      co.itemBegun = true;
      if (_page == _Page.bag) _see(['P3']);
      if (_picked is Item) _see(['P4']);
    }
    if (started && co.itemBegun && ++co.itemBreaks >= _pointerBreaks) _seeBy(dropItemPointers);
  }

  /// An item waits in the bag.
  bool _itemWaits(Game g) => g.inventory.values.any((n) => n > 0);

  /// An item went on a type ([Board._useItem]): the item pointers are done, and K0, which says the same, is seen.
  void _coachItemGiven() {
    if (_seen case final seen? when !seen.contains(guidePointers.last)) _seeBy(itemPointersDone);
  }

  /// The pointer to show now and what it points at, or null: between waves, once the intro is seen and the book is open,
  /// while no card, Hero splash or chest shows. P1 at the spawn bar ([_p1Target]), P2 at "Start", then
  /// with an item in the bag P3 at the Tas tab, P4 (on the Tas page) at the item's slot, P5 (an item picked) at the
  /// first type's row that takes it, or at its "Give to troops" that opens them. Its target is Rect.zero while not drawn.
  (String, Rect)? _pointerNow(Game g) {
    final seen = _seen;
    if (seen == null || !seen.contains(guideIntro) || welcome != null || !g.canStartWave) return null;
    if (_bookT < 1) return null;
    if (_coach.showing || _herald.who != null || _chest.open || _chest.reveal != null) return null;
    if (!seen.contains('P1')) return ('P1', _p1Target(g));
    if (!seen.contains('P2')) return ('P2', _startAt);
    if (seen.contains(guidePointers.last) || !_itemWaits(g)) return null;
    if (_page != _Page.bag) return ('P3', _tabAt[_Page.bag] ?? Rect.zero);
    // P4: the first item cell shown (items come first in the Bag), else the chip that shows them (bag.dart).
    if (_picked is! Item) return ('P4', [for (final (r, _, _) in _slots) r].firstOrNull ?? _bag.chips[BagCategory.items] ?? Rect.zero);
    // P5: the first type's row that takes it, else (its chooser shut) the item's "Give to troops" (decisions-log 202).
    return ('P5', [for (final (r, who, ok, _) in _assign.rows) if (ok && (who is String || who == BagAction.giveTroops) && !r.isEmpty) r].firstOrNull ?? Rect.zero);
  }

  /// P1's target (decisions-log 283; the Army detail's Buy until then, 218): the spawn bar's first card on its page that
  /// can buy now; else, while a type on another page can, the arrow button toward it; else its first card, whose tap
  /// says why. Rect.zero while the bar isn't drawn (spawn_bar.dart).
  Rect _p1Target(Game g) {
    final cards = _bar.cards;
    if (cards.isEmpty) return Rect.zero;
    if ([for (final (r, type) in cards) if (g.buyRefusal(type) == null) r].firstOrNull case final r?) return r;
    final shown = {for (final (_, type) in cards) type};
    final later = troopTypes.keys.toList().indexWhere((t) => !shown.contains(t) && g.buyRefusal(t) == null);
    final arrow = later < 0 ? Rect.zero : (later < troopTypes.keys.toList().indexOf(cards.first.$2) ? _bar.back : _bar.on);
    return arrow.isEmpty ? cards.first.$1 : arrow;
  }

  /// The pointer ([_pointerNow]) in the tooltip frame ([_pointerAt]): the gold hand tapping, its lines beside it.
  void _coachPointer(Canvas c) {
    final co = _coach;
    co
      ..pointer = null
      ..pointerBox = co.pointerTarget = Rect.zero;
    final now = _pointerNow(state);
    if (now == null || now.$2.isEmpty) return;
    final (key, target) = now;
    final lines = guideEn.pointers[key]!;
    const font = 16.0, lineH = 20.0, hand = 32.0, gap = 8.0;
    final textW = lines.map((l) => _textWidth(l, font)).reduce(math.max), textH = lines.length * lineH;
    final at = _pointerAt(target, _inL + hand + gap + textW + _inL, _inT + math.max(hand, textH) + _inB);
    final box = at.$1;
    _tipFrame(c, at);
    final mid = box.top + _inT + math.max(hand, textH) / 2;
    _uiIcon(c, (_clock / _handBeat).floor().isEven ? _icHand : _icHandDown, Rect.fromLTWH(box.left + _inL, mid - hand / 2, hand, hand));
    for (final (i, l) in lines.indexed) {
      _text(c, l, Offset(box.left + _inL + hand + gap, mid - textH / 2 + (i + 0.5) * lineH), size: font, color: _dark);
    }
    co
      ..pointer = key
      ..pointerBox = box
      ..pointerTarget = target;
  }

  /// Where a [w]×[h] pointer at [target] goes, as [_tipAt]'s (its box, where its tail points from, where the tail
  /// starts): above it pointing down, else under it pointing up, else right of it, else left. The first place that keeps
  /// [_coachEdge] inside the screen and clear of the target, the tail's tip a few px off it, bobbing toward it.
  (Rect, _Aim, double) _pointerAt(Rect target, double w, double h) {
    const k = _tipK, far = 5.0; // far: the tip's gap off the target at the bob's top
    final (bw, bh) = (w.ceilToDouble(), h.ceilToDouble());
    final m = _coachEdge, bob = far - 3 * (0.5 + 0.5 * math.sin(_clock * 5));
    double fitX(double x) => x.clamp(m, math.max(m, size.x - bw - m)).roundToDouble();
    double fitY(double y) => y.clamp(m, math.max(m, size.y - bh - m)).roundToDouble();
    final x = fitX(target.center.dx - bw / 2), y = fitY(target.center.dy - bh / 2);
    final right = (Rect.fromLTWH((target.right + 6 * k + far).roundToDouble(), y, bw, bh), _Aim.left, const Offset(-1, 0));
    final places = [
      (Rect.fromLTWH(x, (target.top - 5 * k - far - bh).roundToDouble(), bw, bh), _Aim.down, const Offset(0, 1)),
      (Rect.fromLTWH(x, (target.bottom + 6 * k + far).roundToDouble(), bw, bh), _Aim.up, const Offset(0, -1)),
      right,
      (Rect.fromLTWH((target.left - 6 * k - far - bw).roundToDouble(), y, bw, bh), _Aim.right, const Offset(1, 0)),
    ];
    final screen = (Offset.zero & Size(size.x, size.y)).deflate(m);
    bool inside(Rect r) => r.left >= screen.left && r.top >= screen.top && r.right <= screen.right && r.bottom <= screen.bottom;
    final (placed, aim, toward) = places.firstWhere((p) => inside(p.$1) && !p.$1.overlaps(target), orElse: () => places.first);
    final box = placed.shift(toward * (far - bob).roundToDouble());
    final p = switch (aim) {
      _Aim.down => (target.center.dx - _tipDown.width * k / 2).clamp(box.left + 3 * k, box.right - 3 * k - _tipDown.width * k),
      _Aim.up => (target.center.dx - 6.5 * k).clamp(box.left + 3 * k, box.right - 3 * k - _tipSide.height * k),
      _ => (target.center.dy - 6.5 * k).clamp(box.top + 3 * k, box.bottom - 5 * k - _tipSide.height * k),
    };
    return (box, aim, p.roundToDouble());
  }
}
