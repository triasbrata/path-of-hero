part of 'main.dart';

// The pocket bar on the battle HUD (decisions-log 332; ui-hud.md "The pocket bar"; the rules: pocket.dart): four slots
// in a column at the field's right edge, over the step's top, on the spawn bar's own hotbar art (ui_hotbar.png) stood
// upright; each its pocket item's icon, how many the Bag holds, its cooldown as a sweep of the slot's greyed copy, and a
// tap (or keys 1 to 4) uses one ([Pockets.usePocket]). Existing art only: ui_hotbar.png, the pocket items' icons.

/// The pocket bar between frames: its panel ([at]: Rect.zero while it doesn't show) and its four slots as placed this
/// frame (for taps, tooltips and tests), the slot a press went down on (its tap up uses it only on that slot), and the
/// running pocket boosts' chips under the wave meter (tavern_look.dart).
class _PocketBar {
  Rect at = Rect.zero;
  final cells = <Rect>[];
  final chips = <Rect>[];
  int? down;
}

extension _PocketLook on Board {
  /// Whether the pocket bar shows: on the battle field where the spawn bar does ([_barShown]: not in a Town, not on the
  /// welcome screen, not after the game), in a wave and between waves (the bottles work then, decisions-log 332), once
  /// a slot holds a kind (until the first is crafted the field's right edge stays clear).
  bool _pocketShown(Game g) => _barShown && g.pocketSlots.any((k) => k != null);

  /// Places the pocket bar for this frame ([_PocketBar.at], [_PocketBar.cells]), before what hangs under the wave meter
  /// is placed: they keep clear of it ([_stackRight]). A column of [pocketSlotCount] slots as big as the spawn bar's
  /// ([_hotGeom]), right-aligned with the wave meter, its bottom two meter px over the step's top. The room round and
  /// between them is the hotbar's, but less where the book (open between waves) leaves less on its right: the 60 book px
  /// it keeps there ([_bookFit]) take the column at one book px a pixel (915x412) with 6 px of it, the panel's rim.
  void _pocketPlace(Game g) {
    final p = _pocket..at = Rect.zero;
    p.cells.clear();
    if (!_pocketShown(g)) return;
    final h = _hotGeom(), s = h.s, ps = _bookFit().ps;
    final m = ((60 * ps - (_WaveMeter._edge - 6) - s) / 2).floorToDouble().clamp(6.0, h.m);
    final w = s + 2 * m, ht = pocketSlotCount * s + (pocketSlotCount + 1) * m;
    final right = size.x - _edgeR, bottom = h.stepTop - 2 * _meterK;
    p.at = Rect.fromLTWH((right - w).roundToDouble(), (bottom - ht).roundToDouble(), w, ht);
    for (var i = 0; i < pocketSlotCount; i++) {
      p.cells.add(Rect.fromLTWH(p.at.left + m, p.at.top + m + i * (s + m), s, s));
    }
  }

  /// Where a piece hanging under the wave meter ([top], [h] tall: the Shadows' chips, the Town chip, the boosts' chips,
  /// a boss bar) has its right: the meter's, but left of the pocket bar where it would come down beside it (915x412 with
  /// the map open).
  double _stackRight(double top, double h) {
    const gap = 6.0;
    final bar = _pocket.at, right = _meterAt.isEmpty ? size.x - _edgeR : _meterAt.right;
    return bar.isEmpty || top >= bar.bottom || top + h + gap <= bar.top ? right : bar.left - gap;
  }

  /// Whether the pocket bar is drawn and takes taps: placed ([_pocketPlace]), and the battle log shut (open, it stands
  /// over the bar; the bar keeps its place, so nothing under the wave meter moves as the log opens).
  bool get _pocketLive => !_pocket.at.isEmpty && !_log.open;

  /// The pocket bar as placed ([_pocketPlace]): the hotbar's panel and in it each slot ([_pocketSlot]).
  void _pocketBar(Canvas c, Game g) {
    final p = _pocket;
    if (!_pocketLive) return;
    _nine(c, const Rect.fromLTWH(0, 0, 11, 28), p.at, hotbarPx, l: 3, t: 3, r: 3, b: 3, sheet: 'ui_hotbar.png');
    for (final (i, r) in p.cells.indexed) {
      _pocketSlot(c, g, i, r);
    }
  }

  /// Slot [i] in [r]: the hotbar's inset slot, lighter under the mouse or while its boost runs, its face sunk a sprite px
  /// while pressed; greyed between waves for a kind that works only in a wave. Its kind's icon (faded with none left), how
  /// many the Bag holds astride its top edge at its right (red at none), the cooldown as the slot's greyed copy over it,
  /// clipped to the share still to run clockwise from the top, and its seconds in the middle. No key on it: its tooltip
  /// says it on the desktop ([Pockets.pocketSlotTip]); an empty slot shows the slot alone.
  void _pocketSlot(Canvas c, Game g, int i, Rect r) {
    const k = hotbarPx;
    final kind = g.pocketSlots[i];
    final look = _look(r), sink = look == ButtonLook.pressed ? k : 0.0, at = r.translate(0, sink);
    final held = kind == null ? 0 : g.pocketHeld(kind);
    final idle = kind != null && g.whyNotUsePocket(i) == PocketWhy.wave;
    final lit = look == ButtonLook.hover || look == ButtonLook.pressed || (kind != null && g.pocketBoostOf(kind) != null);
    void face(Paint? paint) {
      _nine(c, const Rect.fromLTWH(12, 0, 18, 18), _whole(at), k, l: 2, t: 3, r: 2, b: 1, sheet: 'ui_hotbar.png', paint: paint);
      if (kind == null) return;
      final inner = Rect.fromLTRB(at.left + 2 * k, at.top + 3 * k, at.right - 2 * k, at.bottom - k);
      final side = 16.0 * math.max(1.0, (inner.shortestSide / 16).floorToDouble());
      _icon(c, kind, _whole(Rect.fromCenter(center: inner.center, width: side, height: side)),
          paint == _greyTagPaint ? _greyTagPaint : (held == 0 ? _ghost : null));
    }

    face(idle ? _greyTagPaint : (lit ? _lightTagPaint : null));
    _tip.hints.add((r, _Hint.pocket, '$i'));
    if (kind == null) return;
    final cool = g.pocketCoolShare(kind);
    if (cool > 0 && !idle) {
      final pie = Path()
        ..moveTo(at.center.dx, at.center.dy)
        ..arcTo(Rect.fromCircle(center: at.center, radius: at.longestSide), -math.pi / 2, 2 * math.pi * cool, false)
        ..close();
      c.save();
      c.clipRect(at);
      c.clipPath(pie);
      face(_greyTagPaint);
      c.restore();
      _text(c, '${g.pocketCoolLeft(kind).ceil()}', at.center, size: math.max(13.0, (r.height * 0.34).roundToDouble()),
          color: Colors.white, outline: const Color(0xFF3F2832), anchor: Anchor.center);
    }
    _capsule(c, '$held', barCountSize(r.height), Offset(at.right + 1, at.top), anchor: Anchor.centerRight, tight: true, red: held == 0);
  }

  /// The pocket slot under [p] (none while the bar isn't drawn, [_pocketLive]), or null.
  int? _pocketSlotAt(Offset p) => !_pocketLive ? null : [for (final (i, r) in _pocket.cells.indexed) if (r.contains(p)) i].firstOrNull;

  /// A tap up on the pocket bar: on the slot the press went down on, it uses one ([_pocketUse]). True when the tap was
  /// the bar's (anywhere on it): nothing under it takes it.
  bool _pocketTap(Offset p) {
    final down = _pocket.down;
    _pocket.down = null;
    if (!_pocketLive || !_pocket.at.contains(p)) return false;
    if (down != null && _pocketSlotAt(p) == down) _pocketUse(down);
    return true;
  }

  /// Keys 1 to 4 (the number row or the keypad) use the pocket bar's slots while it is placed (the open log over it too).
  bool _pocketKey(LogicalKeyboardKey key) {
    final i = const [LogicalKeyboardKey.digit1, LogicalKeyboardKey.digit2, LogicalKeyboardKey.digit3, LogicalKeyboardKey.digit4].indexOf(key);
    final pad = const [LogicalKeyboardKey.numpad1, LogicalKeyboardKey.numpad2, LogicalKeyboardKey.numpad3, LogicalKeyboardKey.numpad4].indexOf(key);
    final slot = i >= 0 ? i : pad;
    if (slot < 0 || state.dungeon != null || _pocket.at.isEmpty || _coach.showing || _foeSplashBusy || _herald.who != null || _chest.open || _chest.reveal != null) {
      return false; // a card, a splash or the chest's popup over it
    }
    _pocketUse(slot);
    return true;
  }

  /// Uses slot [i]'s pocket item ([Pockets.usePocket]); refused, the error sound, and why in the message window but for
  /// its cooldown (the slot counts it down), the pause and a wipe's choice (its dialog says it, wipe_ask.dart).
  void _pocketUse(int i) {
    final g = state;
    final why = g.whyNotUsePocket(i);
    if (why == null) {
      g.usePocket(i);
      return;
    }
    g.usePocket(i); // the error sound
    if (why != PocketWhy.cooling && why != PocketWhy.paused && why != PocketWhy.asked) showMessage(g.pocketWhyText(i)!);
  }
}
