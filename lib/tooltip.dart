part of 'main.dart';

// Tooltips over the loot in the book: the bag's slots ([Board._slots], [Board._relicSlots]) and the item
// icons in the troop rows ([_Tips.rows]); over a row's HP, MP and awakening stars ([_Tips.hints]); and a
// troop's name over a troop on the field ([_nameplate]; a monster's plate and the pinned one: plates.dart). The mouse shows one after resting [_hoverDelay]
// on it. Touch has no hover: a finger held still [_pressDelay] shows it, and lifting hides it without a
// tap (the row under it isn't bought). Nothing shows while something is dragged. The words are
// [Game.itemInfo] / [Game.relicInfo] / [Game.hpInfo] / [Game.mpInfo] / [Game.awakenInfo]; over the wave meter once
// the tide is on, [Game.tideTip] (#92; with the army cap's warning, decisions-log 161). They sit in the
// UI pack's tan tooltip frame, its pointer aimed at what they tell about ([Board._tipAt]).

const _hoverDelay = 0.25, _pressDelay = 0.4;

/// ui_all.png's wooden crate, 9-sliced: dark, so it reads over the field and the pages. The message window
/// uses it; the tooltips have the pack's pointer frame.
const _crate = Rect.fromLTWH(915, 4, 42, 41);

/// ui_tooltip.png (tool/import_fx.py, from UI_Frames.png's tan pointer panels), at [_tipK]: the body,
/// 9-sliced l 3, t 3, r 3, b 5; the pointer under it (its top 5 rows over the body's lip, the tip 5 below);
/// the pointer on its left edge (its column 6 on the edge, the tip at column 0, rows 5-7), flipped for the
/// right edge.
const _tipBody = Rect.fromLTWH(0, 0, 24, 26), _tipDown = Rect.fromLTWH(24, 0, 9, 10), _tipSide = Rect.fromLTWH(33, 0, 9, 13);
const _tipK = 2.0;

/// Where a tooltip's pointer is: under the box pointing down, on its left / right edge pointing out, or (the drop
/// popup's, drop_popup.dart) on its top edge pointing up: the side pointer turned a quarter.
enum _Aim { down, left, right, up }

/// What a troop row shows a tooltip for besides its items: HP, MP, the awakening stars, and the Hero crown
/// (hero.dart); the wave meter once the tide is on (#92, wave_meter.dart); a fallen Hero's Recall line on the Army
/// page's detail (troop_detail.dart): who that Hero is; a Pasukan row's Pusaka badge (bag.dart): its Pusaka's; the Shadows' chips
/// under the wave meter (omen_look.dart): what each does; and a Pusaka's Carve bar on the Bag's facing page (bag.dart):
/// how Carve works ([Ukir.carveInfo]), its Pusaka by name; and the wave meter's Town chip (town_look.dart): the Town
/// marked ([Towns.townTip]); with the Towns on, a small relic's icon on the Army page's detail (troop_detail.dart): its
/// tooltip ([Game.relicInfo], its tier among its lines; decisions-log 227); and the spawn bar's "+Room" (spawn_bar.dart,
/// the Army header's until decisions-log 283): what the capacity buy does and costs ([Game.roomTip], decisions-log 260,
/// 292).
enum _Hint { hp, mp, awaken, hero, tide, recall, pusaka, omens, carve, town, relic, room, boost, troop, autoReplace }

/// The tooltip's state between frames.
class _Tips {
  final rows = <(Rect, Item, String)>[]; // the troop rows' item icons drawn this frame: where, which, whose row
  final hints = <(Rect, _Hint, String)>[]; // the troop rows' HP, MP and stars drawn this frame
  Offset? press; // a finger held down (touch only; the mouse hovers)
  (Object, String?)? on; // what is pointed at (loot, or a troop on the field), since [since] (on the screen clock)
  double since = 0;
  bool shown = false;
  (String, List<String>)? drawn; // the loot tooltip's title and lines as drawn this frame (null: none), for tests
  Rect box = Rect.zero; // and its frame's box, for tests

  void down(TapDownEvent e) => press = e.deviceKind == ui.PointerDeviceKind.mouse ? null : e.localPosition.toOffset();

  /// The press is over. True when it was a long press that showed a tooltip: then it isn't a tap.
  bool up() {
    final long = press != null && shown;
    press = null;
    return long;
  }
}

extension on Board {
  /// The tooltip of the loot under the pointer, else the name of the troop on the field under it, once the
  /// pointer has rested there long enough, pointing at it ([_tipAt]).
  void _tooltip(Canvas c) {
    final t = _tip..drawn = null, p = t.press ?? _mouse;
    // A tap on the Shadows' chips keeps their tooltip up for a while (omen_look.dart), wherever the pointer is.
    final omens = _omenRow.at != Rect.zero && _clock < _omenRow.tipUntil ? (_omenRow.at, _Hint.omens, null) : null;
    if ((p == null || dragAt != null) && omens == null) return _point(null);
    final areas = <(Rect, Enum, String?)>[
      for (final (r, i, _) in _slots) (r, i, null),
      for (final (r, x) in _relicSlots) (r, x, null),
      for (final (r, m) in _matSlots) (r, m, null),
      ...t.rows,
      ...t.hints,
      if (_tideAt != Rect.zero) (_tideAt, _Hint.tide, null),
      if (_omenRow.at != Rect.zero) (_omenRow.at, _Hint.omens, null),
      if (_townChipAt != Rect.zero) (_townChipAt, _Hint.town, null),
      for (final (i, r) in _boostChipsAt.indexed) (r, _Hint.boost, '$i'), // a boost's chip under it (tavern_look.dart)
    ];
    final pointed = p == null || dragAt != null ? null : areas.where((a) => a.$1.contains(p)).firstOrNull, hit = pointed ?? omens;
    // An item cell's plus: an enhanced stack's tooltip is its own (decisions-log 255), from one cell to the next too.
    final plus = [for (final (r, _, plus) in _slots) if (r == pointed?.$1) plus].firstOrNull ?? 0;
    // Off the loot: a unit on the field, troop or monster (plates.dart), unless something covers it
    // ([_covered]); not the pinned one, whose plate is up already; none while loot is in hand (the drop popup
    // tells about the troop instead, drop_popup.dart).
    final unit = hit != null || _picked != null || p == null ? null : _unitAt(p);
    final plate = unit == _pinned ? null : unit;
    _point(hit != null ? (plus > 0 ? (kind: hit.$2, plus: plus) : hit.$2, hit.$3) : (plate == null ? null : (plate, null)));
    if (pointed == null && omens != null) t.shown = true;
    if (!t.shown) return;
    if (plate != null) {
      _plate(c, plate);
      return;
    }
    if (hit!.$2 == _Hint.hero) return _heroTip(c, hit.$3!, hit.$1); // hero.dart
    if (hit.$2 == _Hint.omens) return _omenTip(c, hit.$1); // omen_look.dart

    final what = hit.$2, type = hit.$3, target = hit.$1;
    // The title's icon, the title, and the lines, each maybe led by an item's icon.
    final (String title, List<(Item?, String)> lines) = switch (what) {
      Relic r => _plain(state.relicInfo(r)),
      Item i => _plain(state.itemInfo(i, type, plus)),
      // A material's (town.dart), and while a wish's recipe takes it "Needed for your wishlist" (decisions-log 282).
      Mat m => _plain(switch (state.matInfo(m)) { (final t, final l) => (t, [...l, if (state.wishMats.contains(m)) Words.neededForWishlist]) }),
      _Hint.hp => _plain(state.hpInfo(type!)),
      _Hint.mp => _plain(state.mpInfo(type!)),
      _Hint.tide => _plain(state.tideTip), // and the cap's warning while the army is full (decisions-log 161)
      _Hint.recall => _plain(state.recallInfo(state.fallenHeroes[int.parse(type!)])),
      _Hint.pusaka => _plain(state.relicInfo(state.pusakaOf(type!) ?? state.oath ?? Relic.dragonHeart)), // '': the oath's
      _Hint.carve => _plain(state.carveInfo(Relic.values.byName(type!))), // a Pusaka's Carve bar (bag.dart)
      _Hint.town => _plain(state.townTip), // the wave meter's Town chip (town_look.dart)
      _Hint.boost => _plain(state.boostTip(int.parse(type!))), // a boost's chip (tavern_look.dart)
      _Hint.room => _plain(state.roomTip), // the spawn bar's "+Room" (spawn_bar.dart)
      _Hint.troop => _plain(state.spawnTip(type!)), // a spawn bar's card (spawn_bar.dart)
      _Hint.autoReplace => _plain(state.autoTip), // the spawn bar's Auto (auto_replace.dart)
      // A small relic on the Army detail (troop_detail.dart): what it is, without the Bag's "Tap, then pick a troop".
      _Hint.relic => _plain(switch (state.relicInfo(Relic.values.byName(type!))) { (final t, final l) => (t, [...l]..remove(tapLine)) }),
      _ => state.awakenInfo(type!),
    };
    t.drawn = (title, [for (final (_, l) in lines) l]);
    const titleSize = 18.0, lineSize = 14.0, lineH = 19.0, icon = 24.0, lineIcon = 16.0;
    final textW = [
      icon + 6 + _textWidth(title, titleSize, bold: true),
      for (final (i, l) in lines) (i == null ? 0 : lineIcon + 4) + _textWidth(l, lineSize),
    ].reduce(math.max);
    final at = _tipAt(target, textW + _inL * 2, _inT + icon + 4 + lines.length * lineH + _inB), box = t.box = at.$1;
    _tipFrame(c, at);
    final titleIcon = Rect.fromLTWH(box.left + _inL, box.top + _inT, icon, icon);
    switch (what) {
      case _Hint.hp:
        c.drawImageRect(_img('ui_icons.png'), _heartIcon, titleIcon, _px);
      case _Hint.mp:
        c.drawImageRect(_img('ui_icons.png'), _boltIcon, titleIcon, _mpPaint);
      case _Hint.awaken:
        c.drawImageRect(_img('ui_icons.png'), _starIcon, titleIcon, _px);
      case _Hint.tide:
        c.drawImageRect(_img('ui_icons.png'), _meterSwords, titleIcon, _px); // the wave meter's crossed swords
      case _Hint.pusaka:
        _icon(c, state.pusakaOf(type!) ?? state.oath ?? Relic.dragonHeart, titleIcon);
      case _Hint.carve || _Hint.relic:
        _icon(c, Relic.values.byName(type!), titleIcon);
      case _Hint.recall:
        _uiIcon(c, _icCrown, titleIcon);
      case _Hint.town:
        _townMark(c, titleIcon); // the Town's hammer (town_look.dart)
      case _Hint.boost:
        final b = state.boosts[int.parse(type!)];
        _boostIcon(c, b.kind, b.type, titleIcon); // the boost's own icon (tavern_page.dart)
      case _Hint.room:
        _uiIcon(c, Board._icCoin, titleIcon); // the spawn bar's "+Room" (spawn_bar.dart)
      case _Hint.troop:
        _barSprite(c, state, type!, titleIcon); // a spawn bar's card: its type's sprite (spawn_bar.dart)
      case _Hint.autoReplace:
        c.drawImageRect(_img('ui_icons.png'), _counterShield, titleIcon, _px); // the army's shield (troop_counter.dart)
      default:
        _icon(c, what, titleIcon, null, plus);
    }
    _text(c, title, Offset(box.left + _inL + icon + 6, box.top + _inT + icon / 2), size: titleSize, color: _dark, bold: true);
    for (final (i, (item, l)) in lines.indexed) {
      final y = box.top + _inT + icon + 4 + (i + 0.5) * lineH;
      var x = box.left + _inL;
      if (item != null) {
        _icon(c, item, Rect.fromLTWH(x, y - lineIcon / 2, lineIcon, lineIcon));
        x += lineIcon + 4;
      }
      _text(c, l, Offset(x, y), size: lineSize, color: i == 0 ? _effectInk : _tipInk); // the effect first, in green
    }
  }

  /// [key] is what the pointer is on now (null: nothing with a tooltip). Moving from one tooltip straight
  /// onto the next shows it at once.
  void _point((Object, String?)? key) {
    final t = _tip;
    if (key != t.on) {
      t
        ..on = key
        ..since = t.shown && key != null ? double.negativeInfinity : _clock;
    }
    t.shown = key != null && _clock - t.since >= (t.press != null ? _pressDelay : _hoverDelay);
  }

  /// Where a [w]×[h] tooltip about [target] goes, and its pointer (where its piece starts: x under the box,
  /// y on a side). Above the target, pointing down at its top middle; where that runs off the top, beside
  /// it (right, else left), pointing at its middle. Kept on the screen, on whole pixels. [floor]: how high it
  /// may reach (a unit's plate stays under the top rows, the wave meter, the map and the boss bars, [_plateTop]).
  /// [side]: beside it on that side whatever the room above ([_Aim.left]: the pointer on the box's left, so the
  /// box right of the target; the drop popup's other places, drop_popup.dart).
  (Rect, _Aim, double) _tipAt(Rect target, double w, double h, {double floor = 0, _Aim? side}) {
    const k = _tipK, m = 4.0, reach = 6 * k; // reach: how far the side pointer sticks out of the box
    double fit(double v, double lo, double hi) => v.clamp(lo, math.max(lo, hi)).roundToDouble();
    final (bw, bh) = (w.ceilToDouble(), h.ceilToDouble());
    final minTop = math.max(m, floor);
    final top = target.top - (_tipDown.height - 5) * k - bh; // the tip just touching the target
    if (side == null && top >= minTop) {
      final box = Rect.fromLTWH(fit(target.center.dx - bw / 2, m, size.x - bw - m), top.roundToDouble(), bw, bh);
      return (box, _Aim.down, fit(target.center.dx - _tipDown.width * k / 2, box.left + 3 * k, box.right - 3 * k - _tipDown.width * k));
    }
    final right = target.right + reach, left = target.left - reach - bw;
    final aim = side ?? (right + bw <= size.x - m || left < m ? _Aim.left : _Aim.right); // the pointer on the box's left: the box right of it
    final box = Rect.fromLTWH(aim == _Aim.left ? fit(right, m, size.x - bw - m) : left.roundToDouble(),
        fit(target.center.dy - bh / 2, minTop, size.y - bh - m), bw, bh);
    return (box, aim, fit(target.center.dy - 6.5 * k, box.top + 3 * k, box.bottom - 5 * k - _tipSide.height * k));
  }

  /// The tooltip frame round [at]'s box, with its pointer ([_tipAt]).
  void _tipFrame(Canvas c, (Rect, _Aim, double) at) {
    const k = _tipK;
    final (box, aim, p) = at;
    final img = _img('ui_tooltip.png');
    _nine(c, _tipBody, box, k, l: 3, t: 3, r: 3, b: 5, sheet: 'ui_tooltip.png');
    final side = Size(_tipSide.width * k, _tipSide.height * k);
    switch (aim) {
      case _Aim.down:
        c.drawImageRect(img, _tipDown, Rect.fromLTWH(p, box.bottom - 5 * k, _tipDown.width * k, _tipDown.height * k), _px);
      case _Aim.left:
        c.drawImageRect(img, _tipSide, Offset(box.left - 6 * k, p) & side, _px);
      case _Aim.right:
        c.save();
        c.translate(box.right + 6 * k, p);
        c.scale(-1, 1);
        c.drawImageRect(img, _tipSide, Offset.zero & side, _px);
        c.restore();
      case _Aim.up: // [p]: where the piece starts along the top edge; its column 6 on the edge, the tip above
        c.save();
        c.translate(p + _tipSide.height * k, box.top - 6 * k);
        c.rotate(math.pi / 2);
        c.drawImageRect(img, _tipSide, Offset.zero & side, _px);
        c.restore();
    }
  }

  /// A troop's own name ([Unit.name], after "Hero" for a Hero) in the tooltip frame, pointing at the troop,
  /// its type's name ([troopTypeNames]; its build name in its Pusaka's ink with one bound, [Pusaka.buildNameOf]) under it, under that a Hero's rolled attributes and its own skill
  /// (hero.dart), then a line for each relic it holds: its icon and name. [pinned] (plates.dart), each relic's
  /// line ends in a Remove button that takes it off ([Board._takeOff], #91); while it can't come off (a wave is on,
  /// [Game.whyNotTakeOff]) they are greyed and why shows in red under them.
  Rect _nameplate(Canvas c, Unit u, {bool pinned = false}) {
    const nameSize = 18.0, nameH = 22.0, typeSize = 14.0, typeH = 18.0, statsH = 20.0, relicH = 22.0, relicIcon = 16.0, btnH = 18.0;
    final build = state.buildNameOf(u.type), type = build ?? troopTypeNames[u.type] ?? u.type; // "Undying Templar" (pusaka_look.dart)
    final name = u.hero ? 'Hero ${u.name}' : u.name, skill = u.hero ? u.heroSkill : null;
    final why = pinned && u.relics.isNotEmpty ? state.whyNotTakeOff(u.relics.first, u) : null, btnW = _textWidth(Words.remove, typeSize) + 14;
    final w = [
      _textWidth(name, nameSize),
      _textWidth(type, typeSize),
      if (u.hero) _heroStatsWidth(u),
      if (skill != null) _heroSkillWidth(skill),
      for (final r in u.relics) relicIcon + 4 + _textWidth(relicNames[r]!, typeSize) + (pinned ? 10 + btnW : 0),
      if (why != null) _textWidth(why, typeSize),
    ].reduce(math.max);
    final top = nameH + typeH + (u.hero ? statsH : 0) + (skill != null ? statsH : 0);
    final at = _tipAt(_unitRect(u), w + _inL * 2, _inT + top + u.relics.length * relicH + (why != null ? typeH : 0) + _inB, floor: _plateTop);
    _tipFrame(c, at);
    final box = at.$1, x = box.left + _inL;
    _text(c, name, Offset(x, box.top + _inT + nameH / 2), size: nameSize, color: _dark);
    _text(c, type, Offset(x, box.top + _inT + nameH + typeH / 2), size: typeSize,
        color: build == null ? _tipInk : (_pusakaInk[state.pusakaOf(u.type)] ?? _pusakaInkElse));
    if (u.hero) _heroStats(c, u, Offset(x, box.top + _inT + nameH + typeH + statsH / 2));
    if (skill != null) _heroSkillLine(c, skill, Offset(x, box.top + _inT + nameH + typeH + statsH * 1.5));
    for (final (i, r) in u.relics.indexed) {
      final y = box.top + _inT + top + (i + 0.5) * relicH;
      _icon(c, r, Rect.fromLTWH(x, y - relicIcon / 2, relicIcon, relicIcon));
      _text(c, relicNames[r]!, Offset(x + relicIcon + 4, y), size: typeSize, color: _tipInk);
      if (!pinned) continue;
      final btn = Rect.fromLTWH(box.right - _inL - btnW, y - btnH / 2, btnW, btnH);
      final sink = _btnFrame(c, btn, why == null ? Board._btnLight : Board._btnWhite, _look(btn, enabled: why == null), 1);
      _text(c, Words.remove, btn.center + Offset(0, sink - 1), size: typeSize, anchor: Anchor.center,
          color: why == null ? const Color(0xFF3B2210) : const Color(0xFF8E8A86));
      _plateTaps.add((btn, () => _takeOff(r, u))); // refused: the error and why
    }
    if (why != null) _text(c, why, Offset(x, box.top + _inT + top + u.relics.length * relicH + typeH / 2), size: typeSize, color: _blockedInk);
    return box;
  }
}

/// Plain lines, none led by an icon.
(String, List<(Item?, String)>) _plain((String, List<String>) info) => (info.$1, [for (final l in info.$2) (null, l)]);

// Inside the tooltip frame (at [_tipK]): its border, and at the bottom its lip.
const _inL = 3 * _tipK + 5, _inT = 3 * _tipK + 4, _inB = 5 * _tipK + 3;
// On its tan: the title dark brown, the lines the book's ink, the effect line dark green.
const _dark = Color(0xFF3C1E0A), _tipInk = Color(0xFF5A3620), _effectInk = Color(0xFF2E6B1E);
