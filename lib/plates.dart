part of 'main.dart';

// Unit plates over the field (#55; ui-hud.md "Unit plates"). Pointing at a troop shows its nameplate
// ([_nameplate], tooltip.dart), at a monster its type, rank, kind and HP ([_monsterPlate]), once the
// pointer rests ([_tooltip]). A tap on a unit (a click; a drag is no tap) pins its plate ([Board._pinned]):
// it follows the unit and stays until a tap anywhere else, or until the unit dies or leaves the field; a
// tap on another unit moves the pin. Pointing at the others still shows theirs meanwhile.

/// A monster's rank on its plate, in its HP bar's colour: the pack's red and blue strips, then [_tierBar].
Color _tierColor(Tier t) => switch (t) {
      Tier.normal => const Color(0xFFE43B44),
      Tier.elite => const Color(0xFF0095E9),
      _ => _tierBar[t]!.$1,
    };

extension on Board {
  /// Whether something covers the field at screen point [p], so no unit there can be pointed at or tapped:
  /// the open book, a button, the troop counter or its list, the battle log's button or open panel, the wave
  /// meter and the open map, the boss bars, the off-view marker, the game over screens, or a Town. Not the pause's
  /// overlay (#93): paused, a troop is still pointed at, pinned and given loot.
  bool _covered(Offset p) =>
      state.over ||
      _townShown || // a Town's scene stands where the field was (town_scene.dart)
      _coach.showing || // a guide card covers the whole screen (coach.dart)
      _foeSplashBusy || // and so does a foe skill's splash (foe_splash.dart)
      _bookArea.contains(p) ||
      _hits.any((h) => h.$1.contains(p)) ||
      _troops.button.contains(p) ||
      _troops.list.contains(p) ||
      _log.button.contains(p) ||
      (_log.open && _log.panel.contains(p)) || // the battle log's button and open panel (battle_log.dart)
      _map.button.contains(p) ||
      _map.at.contains(p) || // the wave meter and the open map (mini_map.dart)
      _omenRow.at.contains(p) || // the Shadows' chips (omen_look.dart)
      _bossAt.contains(p) || // #74: panels over the field's edge
      _offViewAt.contains(p) ||
      _onBar(p); // the spawn bar's cards along the field's bottom (spawn_bar.dart)

  /// The living unit, troop or monster, at screen point [p]: within 12 units of the middle of its body (7 above
  /// its feet), the nearest; none where the field is [_covered].
  Unit? _unitAt(Offset p) {
    if (_covered(p)) return null;
    final w = _toWorld(Vector2(p.dx, p.dy));
    Unit? best;
    var bestD = 12.0;
    for (final u in state.units) {
      final at = _at(u), d = (Offset(at.x, at.y - 7) - w).distance; // a troop where it is drawn (body_look.dart)
      if (u.alive && d < bestD) (best, bestD) = (u, d);
    }
    return best;
  }

  /// A tap at [p]: on a unit it pins that unit's plate (moving the pin from another); anywhere else it
  /// unpins.
  void _pinTap(Offset p) => _pinned = welcome == null ? _unitAt(p) : null;

  /// Every frame: a pinned unit that died, left the field or isn't in this game (a new one) drops its pin,
  /// and so does the game's end.
  void _dropPin() {
    if (_pinned case final u? when !u.alive || state.over || !state.units.contains(u)) _pinned = null;
  }

  /// The pinned plate, under the HUD (the book and the buttons stay over it), and not while its unit is
  /// out of the view or dragged to a new spot; nor while loot is dragged or in hand, so it never stacks with the
  /// drop popup (#86, drop_popup.dart). The pin stays. A troop's has a Lepas button for each relic it holds
  /// ([_plateTaps], #91).
  void _pinnedPlate(Canvas c) {
    _pinnedAt = Rect.zero;
    _plateTaps.clear();
    final u = _pinned;
    if (u == null || u == _relocating || _held != null) return;
    final x = toScreen(u.pos.x, 0).dx;
    if (x >= 0 && x <= size.x) _pinnedAt = _plate(c, u, pinned: true);
  }

  /// A tap at [p] on a Lepas button of the pinned plate (#91): it takes that relic off (or says why it can't), and
  /// the pin stays. Not where the HUD covers the field ([_covered]), nor a tap that closed a window or began on the
  /// welcome screen.
  bool _plateTap(Offset p) {
    if (_welcomeTap || _herald.tapped || _msg.tapped || _covered(p)) return false;
    for (final (r, fn) in [..._plateTaps]) {
      if (r.contains(p)) {
        fn();
        return true;
      }
    }
    return false;
  }

  /// [u]'s plate, pointing at it: a troop's nameplate or a monster's; [pinned], a troop's with its Lepas buttons.
  /// Where it was drawn.
  Rect _plate(Canvas c, Unit u, {bool pinned = false}) => u.side == Side.troop ? _nameplate(c, u, pinned: pinned) : _monsterPlate(c, u);

  /// How high a unit's plate may reach: under the top rows (the troop counter, the hearts and the gold, the buttons;
  /// the toggle, x2, Auto and the "Chest!" chip), the wave meter, and under the map and the boss bars hanging from it,
  /// so a plate never covers them. A unit too near the top for its plate above it gets it beside it ([_tipAt]).
  double get _plateTop => [
        _rowsTop,
        _map.at.bottom + 4, // 0 while folded; always under the wave meter (decisions-log 220)
        if (!_asideLeft) _omenRow.at.bottom + 4, // the Shadows' chips under them (omen_look.dart): 0 without
        _townChipAt.bottom + 4, // the Town chip, under the meter even while the book shows (town_look.dart): 0 without
        _boostRowAt.bottom + 4, // the boosts' chips under it (tavern_look.dart): 0 without
        _weakChipAt.bottom + 4, // the weakened foes' chip under those (wipe_ask.dart): 0 without
        if (!_bossAside) _bossAt.bottom + 4, // 0 without boss bars; at the left (the book open) they are no band
      ].reduce(math.max);

  /// Under the top rows and the wave meter alone: how high the drop popup may reach, which keeps clear of the map
  /// and the boss bars by itself ([_dropPlace]), so it can sit beside them rather than under them.
  double get _rowsTop =>
      [_troops.button.bottom, _meterBottom, _toggleAt.bottom, _speedAt.bottom, _autoAt.bottom, _chest.chip.bottom, _meterAt.bottom].reduce(math.max) + 4;

  /// On the screen, a unit from the top of its bar down to its feet: what its plate points at.
  Rect _unitRect(Unit u) => Rect.fromPoints(toScreen(u.pos.x - 7, u.pos.y - 23), toScreen(u.pos.x + 7, u.pos.y + 5));

  /// A monster's plate ([monsterPlate]): its type's name; its rank in its HP bar's colour, then what kind
  /// of monster it is (and the Shadows every monster has, Armor and Spikes: [Omens.omenPlateKinds]); and its HP now /
  /// max after the heart.
  Rect _monsterPlate(Canvas c, Unit u) {
    const nameSize = 18.0, nameH = 22.0, lineSize = 14.0, lineH = 18.0, icon = 14.0, gap = 6.0;
    final p = monsterPlate(u), kinds = [...p.kinds, ...state.omenPlateKinds].join(', '), tierW = _textWidth(p.tier, lineSize);
    final w = [
      _textWidth(p.name, nameSize),
      tierW + (kinds.isEmpty ? 0 : gap + _textWidth(kinds, lineSize)),
      icon + 4 + _textWidth(p.hp, lineSize),
    ].reduce(math.max);
    final at = _tipAt(_unitRect(u), w + _inL * 2, _inT + nameH + 2 * lineH + _inB, floor: _plateTop);
    _tipFrame(c, at);
    final box = at.$1, x = box.left + _inL, rank = box.top + _inT + nameH + lineH / 2, hp = rank + lineH;
    _text(c, p.name, Offset(x, box.top + _inT + nameH / 2), size: nameSize, color: _dark);
    _text(c, p.tier, Offset(x, rank), size: lineSize, color: _tierColor(u.tier), outline: _dark);
    if (kinds.isNotEmpty) _text(c, kinds, Offset(x + tierW + gap, rank), size: lineSize, color: _tipInk);
    c.drawImageRect(_img('ui_icons.png'), _heartIcon, Rect.fromLTWH(x, hp - icon / 2, icon, icon), _px);
    _text(c, p.hp, Offset(x + icon + 4, hp), size: lineSize, color: _tipInk);
    return box;
  }
}
