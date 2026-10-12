part of 'main.dart';

// The Tavern on the HUD (decisions-log 268; tavern-design §5 "In battle"; ui-hud.md "The Tavern in battle"; the rules:
// tavern.dart): the boosts running as chips under the wave meter ([Board._boostChips]: under the Town chip when both
// show; each its icon and its waves left, or the Town's hammer for one until the next Town, decisions-log 331; its
// tooltip what it does, [Tavern.boostTip]), and as the field comes back from
// a Town the troops a boost bought there touches burst once with the field's upgrade burst ([Board._boostBursts]).
// Existing art only: ui_bars.png's dark capsule (the Town chip's), the boosts' own icons ([Board._boostIcon]), the Town
// chip's hammer (town_mark.png), fx_upgrade.png.

/// The room between two boost chips, and between their rows, in screen px.
const _boostChipGap = 4.0;

extension _TavernLook on Board {
  /// The boosts running ([Game.boosts], in the order bought) as chips under the wave meter (the Town chip's look,
  /// [_townChip]: ui_bars.png's dark capsule, the icon 16 px from its art at one screen px a pixel, 32 from the meter's k
  /// 4, and the waves left in cream, or for one until the next Town the Town chip's hammer as big as the icon), all as
  /// wide as the widest, in rows right-aligned with the meter, as many a row as
  /// its width takes; under the Town chip when it shows, else where it would go ([_underMeter]). Sets [_boostChipsAt]
  /// and [_boostRowAt] (what the battle log, the boss bars and the plates keep clear of); none at game over.
  void _boostChips(Canvas c, Game g) {
    _boostChipsAt.clear();
    _boostRowAt = Rect.zero;
    if (g.boosts.isEmpty || g.over || _meterAt.isEmpty) return;
    final k = _meterK, fs = math.max(11.0, 5 * k), icon = 16.0 * math.max(1.0, (k / 2).floorToDouble());
    final ck = capsuleK(icon + 4), pad = capsulePad(fs, ck), gap = capsuleGap(fs), h = icon + 2 * (ck + 1);
    final widest = g.boosts.map((b) => b.untilTown ? icon : _textWidth('${b.left}', fs)).reduce(math.max);
    final w = (2 * pad + icon + gap + widest).ceilToDouble();
    final cols = math.max(1, ((_meterAt.width + _boostChipGap) / (w + _boostChipGap)).floor());
    final rowW = math.min(cols, g.boosts.length) * (w + _boostChipGap) - _boostChipGap, left = (_meterAt.right - rowW).roundToDouble();
    final top = _townChipAt.isEmpty ? _underMeter(left, rowW) : _townChipAt.bottom + 6;
    for (final (i, b) in g.boosts.indexed) {
      final row = i ~/ cols, inRow = math.min(cols, g.boosts.length - row * cols);
      final x = _meterAt.right - inRow * (w + _boostChipGap) + _boostChipGap + (i % cols) * (w + _boostChipGap);
      final at = Rect.fromLTWH(x.roundToDouble(), top + row * (h + _boostChipGap), w, h);
      _nine(c, _capsuleSrc, at, ck, l: 1, t: 1, r: 1, b: 1, sheet: 'ui_bars.png', seam: 0); // its corners stay cut
      _boostIcon(c, b.kind, b.type, Rect.fromLTWH(at.left + pad, at.top + ck + 1, icon, icon));
      if (b.untilTown) {
        _townMark(c, Rect.fromLTWH(at.left + pad + icon + gap, at.top + ck + 1, icon, icon));
      } else {
        _text(c, '${b.left}', Offset(at.left + pad + icon + gap, at.center.dy), size: fs, color: const Color(0xFFFFF1D6));
      }
      _boostChipsAt.add(at);
    }
    _boostRowAt = _boostChipsAt.reduce((a, r) => a.expandToInclude(r));
  }

  /// The field back from a Town ([_townSync]): each living troop a boost bought there touches ([Tavern.boostTouches]; a
  /// boost no wave has counted yet, [RunningBoost.fought] 0) bursts once with the field's upgrade burst, as a chest's
  /// take does.
  void _boostBursts(Game g) {
    final fresh = [for (final b in g.boosts) if (b.fought == 0) b];
    if (fresh.isEmpty) return;
    for (final u in g.troops) {
      if (u.alive && fresh.any((b) => g.boostTouches(b, u.type))) _bursts.add((Offset(u.pos.x, u.pos.y), 'upgrade', g.t));
    }
  }
}
