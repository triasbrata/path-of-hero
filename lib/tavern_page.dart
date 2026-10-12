part of 'main.dart';

// The Town's Tavern pages (decisions-log 267; tavern-design §5 with the owner's answers of 2026-10-08; docs/ui-hud.md
// "The Tavern"; its rules: tavern.dart, decisions-log 266), the book's Tavern tab in a Town (the owner: "UI tavern di
// gabung saja di dalam book ui juga"), drawn from the book's own pieces: the page frames recoloured by rarity as the Boss
// Chest's cards, the Bag's slots and capsules, the light tags, the one bevelled button and existing icons. The left page:
// "Tavern", "Offers" and in grey that new ones come every Town, the offers as inset paper-card rows in their rarity's
// frame (the pick on the lit card): the boost's icon, its name, its rarity in its ink and in grey its waves and its
// troops, the coin and the price on the right (red while short), or "Sold" with the icon faded and the words grey.
// Under them Reroll's light tag with its price (greyed while it can't be paid or every offer is sold) and in grey that
// the bought ones stay; then
// "Active", the boosts running as the Bag's slots in their rarity's colours with the waves left in the count's capsule
// (a lone one's effect beside it), or "None yet.". The right page is the pick's, action first: its heading, what it
// does, in grey its rarity and how long, "Effect" and a row per effect (inset cards that only tell), its troops and its
// waves, the page's one bevelled button Buy ("Buy (1,550 gold)"; refused, the white one with why, a press saying it
// again) and "No limit" in grey. Where a page's lines don't all fit (decisions-log 283: the landscape book shorter), the
// left page's under "Offers" and the right page's under its heading scroll (page_scroll.dart). The first time a visit's offers show, the rows come in one after another; an Epic's or
// a Legendary's bursts once with the field's upgrade burst (fx_upgrade.png). A reroll's new offers come in the same way.

/// One offer's row on the Tavern's left page as drawn (for tests): its slot, its kind, where, its price as shown
/// ("1,550", or "Sold" once bought), whether the gold is short of it, and whether it is the pick.
typedef TavernRow = ({int slot, Boost kind, Rect at, String price, bool short, bool picked});

/// One line of the facing page's Effect as drawn (for tests): where, what ("Damage", "Troops", "Waves") and how much
/// ("+20%", "All troops", "2").
typedef TavernEffectRow = ({Rect at, String what, String value});

/// The rows' coming in (tavern-design §5): each [_tavernRevealGap] s after the one above, over [_tavernRevealFor] s from
/// 60% opacity and [_tavernRevealDrop] px lower.
const _tavernRevealGap = 0.12, _tavernRevealFor = 0.25, _tavernRevealDrop = 4.0;

/// ui_icons.png's 16x16 icons the boosts show (tavern-design's map of the sheet): the heart, the bolt, the backpack.
const _icHeart = Offset(0, 0), _icBolt = Offset(144, 0), _icPack = Offset(160, 32);

/// Each effect key's icon (an [Item]'s, the Army page's stat icons; else a ui_icons.png [Offset]) and its word on the
/// facing page.
const _boostEffectLooks = <String, (Object, String)>{
  'dmg': (Item.sword, 'Damage'),
  'taken': (Item.shield, 'Damage taken'),
  'hp': (_icHeart, 'Max HP'),
  'rate': (Item.gloves, 'Attack speed'),
  'mpRegen': (_icBolt, 'MP regen'),
  'gold': (Board._icCoin, 'Kill gold'),
};

/// Each boost's icon: an [Item]'s, a ui_icons.png [Offset], an image file's (the Tavern's mug), or null for the
/// Champion's Plate, whose icon is its troop type's sprite.
const _boostIcons = <Boost, Object?>{
  Boost.feast: 'town_mug.png',
  Boost.ale: Item.sword,
  Boost.stew: _icHeart,
  Boost.broth: Item.shield,
  Boost.tea: Item.gloves,
  Boost.rations: _icPack,
  Boost.toast: Board._icCoin,
  Boost.mage: _icBolt,
  Boost.plate: null,
  Boost.banquet: _icCrown,
};

/// What a boost of [kind] does, one sentence: "Every troop: +20% damage, 15% less damage taken.", "Knights: +40% damage,
/// +15% attack speed.", "+30% kill gold.".
String boostDoes(Game g, Boost kind, String? type) {
  final said = boostEffectLines(g.boostRule(kind).effects).join(', ');
  if (said.isEmpty) return '';
  return switch (boostWho(g, kind, type)) {
    null => '${said[0].toUpperCase()}${said.substring(1)}.',
    _ when type == null => 'Every troop: $said.',
    final who => '$who: $said.',
  };
}

/// The facing page's Effect lines for a boost of [kind] on [type]: (icon, what, how much) for each effect, then its troops
/// (the crossed swords) when it acts on troops, then its waves (the sword).
List<(Object, String, String)> boostEffectRows(Game g, Boost kind, String? type) {
  String percent(num v) => '${(v.abs() * 100).round()}%';
  final who = boostWho(g, kind, type);
  return [
    for (final MapEntry(:key, :value) in g.boostRule(kind).effects.entries)
      if (_boostEffectLooks[key] case (final icon, final what))
        (icon, what, key == 'taken' ? '-${percent(1 - value)}' : '+${percent(value - 1)}'),
    if (who != null) (Board._icSwords, 'Troops', who),
    (Board._icSword, 'Waves', '${g.townRules.tavern.waves}'),
  ];
}

/// The Tavern's pages between frames.
class _TavernView {
  int? pick; // the offer's slot the facing page shows (null: none yet: [Board._tavernPick] picks one)
  List<BoostOffer>? visit; // the visit's offers last shown ([Tavern.tavernOffers]: one list a visit): another visit, no pick
  final seen = <BoostOffer?>[]; // the offer each slot last showed, by identity: another one there comes in ([since])
  final since = <double>[]; // when each slot's offer starts coming in ([Board._clock])
  // This frame, for tests: where each part of the pages is by key ('offers', 'reroll', 'stay', 'active', 'none',
  // 'active:<i>' for the i-th boost running, 'icon', 'buy', 'noLimit'), the words drawn by key ('offers', 'reroll',
  // 'stay', 'none', 'active:<i>' (its waves left, and after a ':' the lone one's label), 'name', 'rarity', 'does',
  // 'line', 'buy', 'noLimit'), the offers' rows and the Effect's.
  final at = <String, Rect>{};
  final texts = <String, String>{};
  final rows = <TavernRow>[];
  final effects = <TavernEffectRow>[];
  final list = _PageScroll(); // the left page under "Offers" ([Board._tavernPages]): it scrolls past its room
  final facing = _PageScroll(); // the right page under its heading ([Board._tavernFacing]): the same

  void clear() {
    at.clear();
    texts.clear();
    rows.clear();
    effects.clear();
    list.clear();
    facing.clear();
  }
}

extension on Board {
  /// The offer the Tavern's facing page shows: the slot picked, else the first not bought, else the first; once shown it
  /// stays until another is picked or the book turns to another page ([Board._open]).
  int _tavernPick(Game g) {
    final offers = g.tavernOffers, v = _tavernPage;
    if (v.pick case final i? when i < offers.length) return i;
    final open = offers.indexWhere((o) => !o.sold);
    return v.pick = open < 0 ? 0 : open;
  }

  /// Whether the Tavern holds offers the player hasn't seen on its page yet (a new visit's, after a load): the red dot on
  /// its tab ([_tabDot]).
  bool _tavernUnseen(Game g) {
    final seen = _tavernPage.seen;
    return g.tavernOffers.indexed.any((e) => e.$1 >= seen.length || !identical(seen[e.$1], e.$2));
  }

  /// The offers shown this frame: one not shown before in its slot (a new visit's, a reroll's) starts coming in, one after
  /// another ([_tavernRevealGap]); another visit's (another Town, another game) drops the pick.
  void _tavernSee(Game g) {
    final v = _tavernPage, offers = g.tavernOffers;
    if (!identical(v.visit, offers)) {
      v
        ..visit = offers
        ..pick = null;
    }
    var n = 0;
    for (final (i, o) in offers.indexed) {
      if (i < v.seen.length && identical(v.seen[i], o)) continue;
      while (v.seen.length <= i) {
        v.seen.add(null);
        v.since.add(0);
      }
      v.seen[i] = o;
      v.since[i] = _clock + _tavernRevealGap * n++;
    }
  }

  /// A boost's icon over [to] ([_boostIcons]; the Champion's Plate's: [type]'s idle sprite standing in it), faded by
  /// [paint] where given.
  void _boostIcon(Canvas c, Boost kind, String? type, Rect to, [Paint? paint]) {
    switch (_boostIcons[kind]) {
      case final Item i:
        _icon(c, i, to, paint);
      case final Offset o:
        _uiIcon(c, o, to, paint);
      case final String file:
        c.drawImageRect(_img(file), _townMarkSrc, to, paint ?? _px);
      case _:
        final b = _idleBounds[type ?? troopTypes.keys.first];
        if (b == null) return;
        final k = math.min(to.width / b.width, to.height / b.height);
        c.save();
        c.translate(to.center.dx, to.bottom);
        c.scale(k);
        _frame(c, 'book_${type ?? troopTypes.keys.first}_idle', 0, Offset.zero, anchor: Offset(b.center.dx, b.bottom), paint: paint ?? _px);
        c.restore();
    }
  }

  /// An effect row's icon over [to]: an [Item]'s, or a ui_icons.png [Offset].
  void _boostEffectIcon(Canvas c, Object icon, Rect to) => icon is Item ? _icon(c, icon, to) : _uiIcon(c, icon as Offset, to);

  /// A rarity's ink on the page: its own ([_rarityInk]), a Common's grey (its own is too light on paper).
  Color _boostInk(Rarity r) => r == Rarity.biasa ? const Color(0xFF9E9080) : _rarityInk[r]!;

  /// The Tavern's two pages in a Town: on [left] the offers, Reroll and the boosts running, on [right] the pick's page
  /// ([_tavernFacing]). [ts] is the page's text scale, [ps] the book's pixel scale (the slots' sprite scale). Under
  /// "Offers" the left page's lines scroll where they don't all fit (page_scroll.dart), clear of the bar then; what takes
  /// a tap is cut to the view, and so are the parts and rows kept for tests (out of it: Rect.zero).
  void _tavernPages(Canvas c, Game g, Rect left, Rect right, double ts, double ps) {
    const ink = Color(0xFF4A2C17), grey = Color(0xFF9E9080);
    final v = _tavernPage, offers = g.tavernOffers;
    _text(c, Words.tavern, Offset(left.center.dx, _titleY(left, ts)), size: 22 * ts, color: ink, anchor: Anchor.center, bold: true);
    final fs = math.max(10.0, 13 * ts), small = math.max(10.0, 11 * ts), lineH = (fs * 1.5).roundToDouble();
    var y = _underTitle(left, ts).roundToDouble();
    final every = _fitFirst(['New offers every ${Words.town}', 'New every ${Words.town}', ''], fs, left.width - _textWidth('Offers', fs, bold: true) - 8 * ts);
    _text(c, 'Offers', Offset(left.left, y + lineH / 2), size: fs, color: ink, bold: true);
    _text(c, every, Offset(left.right, y + lineH / 2), size: fs, color: grey, anchor: Anchor.centerRight);
    v
      ..at['offers'] = Rect.fromLTRB(left.left, y, left.right, y + lineH)
      ..texts['offers'] = every;
    y += lineH;
    if (offers.isEmpty) {
      _text(c, 'No offers here.', Offset(left.left, y + lineH / 2), size: fs, color: grey);
      return;
    }
    _tavernSee(g);
    final pick = _tavernPick(g), waves = g.townRules.tavern.waves;

    // The offers: inset paper cards in their rarity's frame (a Common's the plain one), the pick and the one under the
    // mouse on the lit card; each coming in from below, faded, until it is in.
    final side = math.max(32.0, bagHeadIcon(ps)), pad = math.max(4.0, (7 * ts).roundToDouble());
    final nameFs = math.max(11.0, 15 * ts), rowH = math.max(side + 2 * pad, nameFs * 1.3 + small * 1.4 + 2 * pad).roundToDouble();
    final gap = math.max(3.0, (5 * ts).roundToDouble()), tagH = math.max(20.0, (24 * ts).roundToDouble());
    // Under "Offers" the view: the offers, Reroll and "Active" in it, a visit's from its top; past its room they scroll,
    // narrower by the bar.
    double tall(double w) => offers.length * (rowH + gap) + gap + tagH + 2 * gap + _tavernActiveTall(g, w, ts, ps);
    final view = Rect.fromLTRB(left.left, y, left.right, left.bottom);
    final w = tall(left.width) > view.height ? left.width - _scrollBarRoom(ts) : left.width;
    final page = Rect.fromLTRB(left.left, left.top, left.left + w, left.bottom);
    final (top, marks) = _scrollBegin(c, v.list, view, tall(w), offers);
    y = top;
    for (final (i, o) in offers.indexed) {
      final r = Rect.fromLTWH(left.left, y, w, rowH), picked = i == pick, rule = g.boostRule(o.kind);
      final t = ((_clock - v.since[i]) / _tavernRevealFor).clamp(0.0, 1.0);
      if (t < 1) {
        c.saveLayer(r.inflate(2 * ps).translate(0, _tavernRevealDrop), Paint()..color = Color.fromRGBO(0, 0, 0, 0.6 + 0.4 * t));
        c.translate(0, (_tavernRevealDrop * (1 - t)).roundToDouble());
      }
      _card(c, r, picked || _look(r) == ButtonLook.hover ? Board._frameLit : Board._framePlain, _rarityFramePaints[rule.rarity]);
      final box = _whole(Rect.fromLTWH(r.left + pad, r.center.dy - side / 2, side, side));
      _boostIcon(c, o.kind, o.type, box, o.sold ? _ghost : null);
      final x = box.right + 8 * ts, price = g.boostPrice(o.kind), short = !o.sold && g.gold < price;
      // On the right the coin and the price (red while short), or "Sold".
      final said = o.sold ? Words.sold : thousands(price), saidW = _textWidth(said, fs), end = r.right - pad;
      _text(c, said, Offset(end, r.center.dy), size: fs, color: o.sold ? grey : (short ? _blockedInk : ink), anchor: Anchor.centerRight);
      if (!o.sold) _uiIcon(c, Board._icCoin, _whole(Rect.fromLTWH(end - saidW - 4 * ts - 16, r.center.dy - 8, 16, 16)));
      final room = end - saidW - (o.sold ? 8 * ts : 26 * ts) - x, top = r.center.dy - (nameFs * 1.3 + small * 1.4) / 2;
      _text(c, _fit(boostNames[o.kind]!, nameFs, room), Offset(x, top + nameFs * 0.65), size: nameFs, color: o.sold ? grey : ink, bold: true);
      // Under the name its rarity in its ink, then in grey its waves and its troops where they fit.
      final rarity = rarityNames[rule.rarity]!, rarityW = _textWidth(rarity, small), who = boostWho(g, o.kind, o.type);
      final rest = _fitFirst([' · $waves waves${who == null ? '' : ' · $who'}', if (who != null) ' · $who', ''], small, room - rarityW);
      final lineY = top + nameFs * 1.3 + small * 0.7;
      _text(c, rarity, Offset(x, lineY), size: small, color: o.sold ? grey : _boostInk(rule.rarity));
      if (rest.isNotEmpty) _text(c, rest, Offset(x + rarityW, lineY), size: small, color: grey);
      _tavernBurst(c, rule.rarity, box, v.since[i]);
      if (t < 1) c.restore();
      _hits.add((r, () => v.pick = i));
      v.rows.add((slot: i, kind: o.kind, at: r, price: said, short: short, picked: picked));
      y += rowH + gap;
    }

    // Reroll: a light tag, green while it can be paid (greyed with every offer sold or the gold short: its press says
    // why), its price in it; at the right in grey that the bought ones stay.
    y += gap;
    final why = g.whyNotRerollTavern(), label = '${Words.reroll} ${thousands(g.tavernRerollPrice)}';
    final tagW = capsuleSize(_textWidth(label, fs), fs).width + 3;
    final tag = _tag(c, Rect.fromLTWH(left.left, y, tagW, tagH), _tavernReroll, label, fs, look: why == null ? _TagLook.go : _TagLook.off);
    final stay = _fitFirst(['Bought ones stay', ''], small, page.right - tag.right - 8 * ts);
    if (stay.isNotEmpty) _text(c, stay, Offset(page.right, y + tagH / 2), size: small, color: grey, anchor: Anchor.centerRight);
    v
      ..at['reroll'] = tag
      ..texts['reroll'] = label
      ..at['stay'] = stay.isEmpty ? Rect.zero : Rect.fromLTRB(page.right - _textWidth(stay, small), y, page.right, y + tagH)
      ..texts['stay'] = stay;
    y += tagH + 2 * gap;
    _tavernActive(c, g, page, y, ts, ps);
    _scrollEnd(c, v.list, marks);
    for (final MapEntry(:key, value: r) in [...v.at.entries]) {
      if (key != 'offers') v.at[key] = _inView(r, view); // the parts under "Offers"
    }
    for (final (i, r) in v.rows.indexed) {
      v.rows[i] = (slot: r.slot, kind: r.kind, at: _inView(r.at, view), price: r.price, short: r.short, picked: r.picked);
    }
    _tavernFacing(c, g, offers[pick], pick, right, ts, ps);
  }

  /// An Epic's or a Legendary's offer bursting once over its icon [box] as it comes in at [since] (the field's upgrade
  /// burst, fx_upgrade.png, at [_fxFps], a quarter again the icon's size, clear of the name); a Common's and a Rare's
  /// never.
  void _tavernBurst(Canvas c, Rarity rarity, Rect box, double since) {
    if (rarity.index < Rarity.epik.index) return;
    const file = 'fx_upgrade.png';
    final f = ((_clock - since) * _fxFps).floor();
    if (f < 0 || f >= _frames(file)) return;
    final fs = _img(file).height.toDouble(), k = box.width * 1.25 / fs;
    c.save();
    c.translate(box.center.dx, box.center.dy);
    c.scale(k);
    _frame(c, file, f, Offset.zero, anchor: Offset(fs / 2, fs / 2));
    c.restore();
  }

  /// How many of the Bag's slots a row of "Active" holds in [w] ([ps] the book's pixel scale).
  int _tavernActiveCols(double w, double ps) {
    final (gapX, _) = bagCellGaps(ps);
    return math.max(1, ((w + gapX) / (bagCellSize(ps).size.width + gapX)).floor());
  }

  /// How tall "Active" is in [w] ([_tavernActive]): its line, then "None yet." or the slots' rows.
  double _tavernActiveTall(Game g, double w, double ts, double ps) {
    final lineH = (math.max(10.0, 13 * ts) * 1.5).roundToDouble();
    if (g.boosts.isEmpty) return 2 * lineH;
    final (_, gapY) = bagCellGaps(ps);
    final rows = (g.boosts.length / _tavernActiveCols(w, ps)).ceil();
    return lineH + rows * bagCellSize(ps).size.height + (rows - 1) * gapY;
  }

  /// "Active" from [top] on [left], and in grey "waves left": each boost running as the Bag's slot in its rarity's
  /// colours ([_bagRarityPaints]; a Common's the plain one), its icon in it and its waves left in the count's capsule, in
  /// rows the page's width; a lone one's name and effect beside it. None: "None yet.". All of it is drawn: the left
  /// page's view clips it ([_tavernPages]).
  void _tavernActive(Canvas c, Game g, Rect left, double top, double ts, double ps) {
    const ink = Color(0xFF4A2C17), grey = Color(0xFF9E9080);
    final v = _tavernPage, fs = math.max(10.0, 13 * ts), small = math.max(10.0, 11 * ts), lineH = (fs * 1.5).roundToDouble();
    _text(c, 'Active', Offset(left.left, top + lineH / 2), size: fs, color: ink, bold: true);
    _text(c, 'waves left', Offset(left.right, top + lineH / 2), size: fs, color: grey, anchor: Anchor.centerRight);
    v.at['active'] = Rect.fromLTRB(left.left, top, left.right, top + lineH);
    final y = top + lineH;
    if (g.boosts.isEmpty) {
      const none = 'None yet.';
      _text(c, none, Offset(left.left, y + lineH / 2), size: fs, color: grey);
      v
        ..at['none'] = Rect.fromLTWH(left.left, y, _textWidth(none, fs), lineH)
        ..texts['none'] = none;
      return;
    }
    final cell = bagCellSize(ps);
    final (gapX, gapY) = bagCellGaps(ps);
    final cols = _tavernActiveCols(left.width, ps);
    for (final (i, b) in g.boosts.indexed) {
      final at = Offset(left.left + (i % cols) * (cell.size.width + gapX), y + (i ~/ cols) * (cell.size.height + gapY)) & cell.size;
      final rule = g.boostRule(b.kind);
      _bagSlot(c, at, ps, paint: _bagRarityPaints[rule.rarity]);
      _boostIcon(c, b.kind, b.type, _whole(cell.icon.shift(at.topLeft)));
      _capsule(c, '${b.left}', small, Offset(at.right - ps, at.bottom - ps), anchor: Anchor.bottomRight);
      var said = '${b.left}';
      if (g.boosts.length == 1) {
        final label = _fit('${boostNames[b.kind]}: ${boostEffectLines(rule.effects).join(', ')}', small, left.right - at.right - 8 * ts);
        _text(c, label, Offset(at.right + 8 * ts, at.center.dy), size: small, color: ink);
        said = '$said:$label';
      }
      v
        ..at['active:$i'] = at
        ..texts['active:$i'] = said;
    }
  }

  /// The pick's facing page in [right] ([o], slot [i]), from the top: its heading (icon, name, its rarity in its ink at
  /// the right), what it does ([boostDoes]), in grey "Rare boost. Lasts the next 2 waves.", "Effect" and a row per line
  /// of [boostEffectRows] (inset cards that only tell, the effects' values in green), Buy ([_tavernBuyButton]) and the
  /// grey "No limit" line. Under the heading they scroll where they don't all fit (decisions-log 283: the landscape book
  /// shorter; page_scroll.dart), clear of the bar then; what takes a tap is cut to the view, and so are the parts and rows
  /// kept for tests. Nothing is left out (until then the page drew the rows' icons at 16 px, left out "No limit", drew
  /// the rows closer, then fewer lines above them).
  void _tavernFacing(Canvas c, Game g, BoostOffer o, int i, Rect right, double ts, double ps) {
    const ink = Color(0xFF4A2C17), grey = Color(0xFF9E9080);
    final v = _tavernPage, rule = g.boostRule(o.kind), rarity = rarityNames[rule.rarity]!, waves = g.townRules.tavern.waves;
    final fs = math.max(10.0, 13 * ts), lineH = math.max(14.0, (fs * 1.15).roundToDouble());
    // The heading: as the Bag's ([_detailHeading]): the icon 16 px on a phone and 32 on the desk.
    final cy = right.top + (24 * ts).roundToDouble(), side = bagHeadIcon(ps);
    final icon = _whole(Rect.fromLTWH(right.left, cy - side / 2, side, side));
    _boostIcon(c, o.kind, o.type, icon);
    _text(c, rarity, Offset(right.right, cy), size: fs, color: _boostInk(rule.rarity), anchor: Anchor.centerRight, bold: true);
    final nameFs = 20 * ts, nameX = icon.right + 6 * ts;
    final name = _fit(boostNames[o.kind]!, nameFs, right.right - _textWidth(rarity, fs, bold: true) - 8 * ts - nameX);
    _text(c, name, Offset(nameX, cy), size: nameFs, color: ink);
    v
      ..at['icon'] = icon
      ..texts['name'] = name
      ..texts['rarity'] = rarity;
    final head = math.max(right.top + (42 * ts).roundToDouble(), icon.bottom + 4);

    final rows = boostEffectRows(g, o.kind, o.type), n = rows.length;
    final gap = math.max(4.0, (6 * ts).roundToDouble()), rowGap = math.max(2.0, (4 * ts).roundToDouble());
    final btnH = math.max(20.0, (32 * ts).roundToDouble()), pad = math.max(3.0, (5 * ts).roundToDouble());
    final doesText = boostDoes(g, o.kind, o.type), lineText = '$rarity ${Words.boost.toLowerCase()}. Lasts the next $waves waves.';
    // A row: its icon (the heading's: 16 px on a phone, 32 on the desk), a few px over and under it.
    final rowIcon = bagHeadIcon(ps), rowH = math.max(rowIcon + 4, (fs * 1.4 + 12 * ts).roundToDouble());
    (List<String>, List<String>) wrapped(double w) => (this._wrap(doesText, fs, w, 3), this._wrap(lineText, fs, w, 2));
    double tall((List<String>, List<String>) l) =>
        (l.$1.length + l.$2.length) * lineH + gap + lineH + n * rowH + (n - 1) * rowGap + gap + btnH + lineH;

    // Under the heading the view: an offer's from its top; past its room it scrolls, narrower by the bar.
    final view = Rect.fromLTRB(right.left, head, right.right, right.bottom);
    final w = tall(wrapped(right.width)) > view.height ? right.width - _scrollBarRoom(ts) : right.width;
    final (does, line) = wrapped(w);
    var (y, marks) = _scrollBegin(c, v.facing, view, tall((does, line)), (visit: g.tavernOffers, slot: i));
    for (final (lines, color, key) in [(does, ink, 'does'), (line, grey, 'line')]) {
      for (final (j, said) in lines.indexed) {
        _text(c, said, Offset(right.left, y + (j + 0.5) * lineH), size: fs, color: color);
      }
      v.texts[key] = lines.join('\n');
      y += lines.length * lineH;
    }
    y += gap;
    _text(c, 'Effect', Offset(right.left, y + lineH / 2), size: fs, color: ink, bold: true);
    y += lineH;
    for (final (iconOf, what, value) in rows) {
      final r = Rect.fromLTWH(right.left, y.roundToDouble(), w, rowH);
      _card(c, r, Board._framePlain);
      final box = _whole(Rect.fromLTWH(r.left + pad, r.center.dy - rowIcon / 2, rowIcon, rowIcon));
      _boostEffectIcon(c, iconOf, box);
      final good = value.startsWith('+') || value.startsWith('-');
      _text(c, value, Offset(r.right - pad, r.center.dy), size: fs, color: good ? _haveInk : ink, anchor: Anchor.centerRight);
      final x = box.right + 6 * ts;
      _text(c, _fit(what, fs, r.right - pad - _textWidth(value, fs) - 6 * ts - x), Offset(x, r.center.dy), size: fs, color: ink);
      v.effects.add((at: r, what: what, value: value));
      y += rowH + rowGap;
    }
    y += gap - rowGap;
    _tavernBuyButton(c, g, o, i, Rect.fromLTWH(right.left, y.roundToDouble(), w, btnH), ts);
    y += btnH;
    final said = _fitFirst(['No limit: buy any you can pay', 'No limit'], fs, w);
    _text(c, said, Offset(right.left + w / 2, y + lineH / 2), size: fs, color: grey, anchor: Anchor.center);
    v
      ..at['noLimit'] = Rect.fromLTWH(right.left, y, w, lineH)
      ..texts['noLimit'] = said;
    _scrollEnd(c, v.facing, marks);
    for (final key in ['buy', 'noLimit']) {
      if (v.at[key] case final r?) v.at[key] = _inView(r, view);
    }
    for (final (j, e) in v.effects.indexed) {
      v.effects[j] = (at: _inView(e.at, view), what: e.what, value: e.value);
    }
  }

  /// Buy in [r], the page's one bevelled button (its main standalone action; the owner's button rule): the green one,
  /// "Buy (1,550 gold)" ("Buy (1550)", "Buy" where shorter), while offer [i] can be bought ([Tavern.whyNotBuyBoost]);
  /// else the white one with why ("Not enough gold", "Sold"). A press buys it ([_tavernBuy]) or says why again.
  void _tavernBuyButton(Canvas c, Game g, BoostOffer o, int i, Rect r, double ts) {
    final why = g.whyNotBuyBoost(i), fs = math.max(10.0, 14 * ts), room = r.width - 12 * ts, price = g.boostPrice(o.kind);
    final label = why == null
        ? _fitFirst(['${Words.buy} (${thousands(price)} gold)', '${Words.buy} (${shortPrice(price)})', Words.buy], fs, room)
        : _fit(boostRefusals[why]!, fs, room);
    _button(c, r, () => _tavernBuy(i), label: label, size: fs, enabled: why == null, row: Board._btnGreen);
    if (why != null) _hits.add((r, () => _tavernBuy(i))); // the white one's press says why again
    _tavernPage
      ..at['buy'] = r
      ..texts['buy'] = label;
  }

  /// A press on Buy for offer [i]: it runs from now ([Tavern.buyBoost]) and the message window says so ("Feast! 2
  /// waves"). Refused: the error and why ([boostRefusals]).
  void _tavernBuy(int i) {
    final g = state;
    if (g.whyNotBuyBoost(i) case final why?) {
      g.buyBoost(i); // the error
      return showMessage(boostRefusals[why]!);
    }
    final kind = g.tavernOffers[i].kind;
    if (g.buyBoost(i)) showMessage('${boostNames[kind]}! ${g.townRules.tavern.waves} waves');
  }

  /// A press on Reroll: the offers not bought are drawn again ([Tavern.rerollTavern]) and come in on the page. Refused:
  /// the error and why ("Sold out", "Not enough gold").
  void _tavernReroll() {
    final g = state;
    if (g.whyNotRerollTavern() case final why?) {
      g.rerollTavern(); // the error
      return showMessage(boostRefusals[why]!);
    }
    g.rerollTavern();
  }
}
