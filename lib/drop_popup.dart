part of 'main.dart';

// Loot in hand (#86; ui-hud.md "Loot in hand and the drop popup"). An item or a relic dragged out of the bag,
// or picked there with a tap ([Board._picked]), is drawn at the pointer with how many the bag holds ("x3"; a
// Pusaka, bound or in the Gudang, its stars, "★2", as its Tas slot says). Over
// a troop on the field a popup in the tooltip frame says what giving it would do: an item to the troop's whole
// TYPE (every troop of it, its stats before and after, its caps and the awakening it counts toward), a relic
// to that one troop (its effect), or why it can't, in red. Its words come from [Game.assignPreview], which the
// book's lists share (#87). No troop is ringed. A drop, or a tap on the troop, gives it; the loot then stays in
// hand while the bag holds more, a refused one too, until the bag runs out of it, or it is put back: a tap on
// bare ground or on its slot, Esc, a right click, turning the page, the book closing.
// Held but not dragged, with the pointer over the open book, it isn't drawn at the pointer, where it would cover the
// button about to be tapped (Asah's "Yakin?", Jual, a row): its lit slot says what is in hand (ghost-book).

/// The drop popup as drawn this frame: the troop it tells about, where, and its lines as text; the loot at the
/// pointer and the count by it (Rect.zero, null: none drawn); and the held loot's lit slot while it isn't drawn at
/// the pointer over the book (Rect.zero: not so). For tests.
class _DropShown {
  Unit? on;
  Rect at = Rect.zero;
  List<String> lines = const [];
  Rect ghost = Rect.zero;
  String? count;
  Rect cue = Rect.zero;
}

/// A line of the drop popup: led by an icon (an [Item] or [Relic], or a ui_icons.png rect), its words in [ink],
/// and for a change a drawn arrow and what it becomes in [afterInk].
typedef _DropLine = ({Object? icon, String text, Color ink, String? after, Color afterInk});

/// How far above a finger the loot and the popup go, so the finger doesn't hide them (touch only), and the size
/// of the count beside the loot.
const _fingerLift = 28.0, _countSize = 18.0;

extension on Board {
  /// The loot being dragged, else the one in hand; null: none.
  Enum? get _held => _itemDrag ?? _relicDrag ?? _picked;

  /// [_held]'s plus: an enhanced item's stack (decisions-log 255), dragged ([Board._dragPlus]) or in hand; else 0.
  int get _heldPlus => _itemDrag != null ? _dragPlus : (_relicDrag != null ? 0 : _pickPlus);

  /// Where the loot held is: where it is dragged, else the pointer's last place (the mouse; a finger's last
  /// press).
  Offset? get _heldAt => dragAt?.toOffset() ?? _handAt;

  /// The troop the loot held would go to now; null: none, or nothing held.
  Unit? get _heldOver => _held == null ? null : switch (_heldAt) { final p? => _dropTarget(p), _ => null };

  /// The troop loot dropped (or tapped) at screen point [p] goes to: the living troop nearest it within
  /// reach, unless the HUD covers the field there ([_covered]: a drop over the book, a button, the log or the
  /// boss bars reaches no troop hidden under it).
  Unit? _dropTarget(Offset p) => _covered(p) ? null : _troopNear(Vector2(p.dx, p.dy));

  /// Gives [loot] to [u]: an item to its whole type (an enhanced one from its stack at +[plus], decisions-log 255), a
  /// relic to it. A refusal plays the error; the popup over the troop says why, so no message window. True when it went
  /// on.
  bool _give(Enum loot, Unit u, [int plus = 0]) => switch (loot) {
        final Item i => _useItem(i, u.type, say: false, plus: plus),
        final Relic r => _useRelic(r, u, say: false),
        _ => false,
      };

  /// A drag of [loot] (an item's enhanced stack at +[plus]) let go at [p]: on a troop it is given (or refused), and stays
  /// in hand while it can ([_canHold]: the bag holds more, a Pusaka is owned); anywhere else it is put back.
  void _dropLoot(Enum loot, Offset p, [int plus = 0]) {
    final u = _dropTarget(p);
    if (u != null) _give(loot, u, plus);
    _pickedAt = u != null && _canHold(state, loot, plus) ? (kind: loot, plus: plus) : null;
  }

  /// A tap at [p] with loot in hand, on the field: on a troop it gives it (true: that is all the tap did); on
  /// bare ground it puts the loot back. Not a tap on the HUD, that closed a window, hit a panel or began on the
  /// welcome screen. Paused too (#93).
  bool _handTap(Offset p) {
    final loot = _picked;
    if (loot == null || _welcomeTap || _herald.tapped || _msg.tapped || _troops.tapped || _log.tapped || _map.tapped ||
        _covered(p)) {
      return false;
    }
    if (_dropTarget(p) case final u?) {
      _give(loot, u, _pickPlus);
      return true;
    }
    _picked = null;
    return false;
  }

  /// Puts the loot in hand back, and a drag of loot's (Esc, a right click): nothing is given.
  void _putBack() {
    _picked = null;
    if (_itemDrag == null && _relicDrag == null) return;
    _itemDrag = _relicDrag = null;
    dragAt = null;
  }

  /// Whether screen point [p] is over the open book this frame: its pages ([_bookArea]) or a tab on its top edge, or
  /// where a shut one takes a press ([bookTabTap]).
  bool _overBook(Offset p) => _bookArea.contains(p) || [..._tabAt.values, ..._tabTapAt.values].any((r) => r.contains(p));

  /// The loot held, at the pointer (above a finger), faded, with how many the bag holds (a Pusaka's stars: the bag
  /// counts a bound one 0); and the popup over the troop it would go to. Drawn over the HUD, placed clear of it
  /// ([_dropPlace]). Only held, not dragged, with the pointer over the open book: not drawn (no troop there takes
  /// it, so no popup either), so it covers nothing the player is about to tap; its slot, lit while picked, shows it.
  void _dropPopup(Canvas c) {
    final d = _drop
      ..on = null
      ..at = Rect.zero
      ..lines = const []
      ..ghost = Rect.zero
      ..count = null
      ..cue = Rect.zero;
    final loot = _held, plus = _heldPlus, p = _heldAt;
    if (loot == null || p == null || welcome != null) return;
    if (_itemDrag == null && _relicDrag == null && _overBook(p)) {
      d.cue = loot is Item && plus > 0 ? bagStackSlot(loot, plus) : bagSlot(loot);
      return;
    }
    final at = _touch ? p - const Offset(0, _fingerLift) : p, g = 14 * _scale;
    final count = d.count = switch ((state.pusaka[loot], loot)) {
      (final own?, _) => '$_starGlyph${own.stars}',
      (_, final Item item) => 'x${state.bagOf(item, plus)}',
      _ => 'x${state.inBag(loot)}',
    };
    final ghost = d.ghost = Rect.fromCenter(center: at, width: g, height: g);
    final countAt = Offset(ghost.right - g * 0.1, ghost.bottom - 10), countW = _textWidth(count, _countSize);
    final pointer = ghost.expandToInclude(Rect.fromLTWH(countAt.dx, countAt.dy - 12, countW + 4, 24)).inflate(2);
    if (_dropTarget(p) case final u?) {
      final (icon, title, lines) = _dropWords(loot, u, plus);
      _dropBox(c, icon, title, lines, _unitRect(u).expandToInclude(pointer), plus);
      d
        ..on = u
        ..lines = [title, for (final l in lines) l.after == null ? l.text : '${l.text} > ${l.after}'];
    }
    _icon(c, loot, ghost, _ghost, plus);
    _text(c, count, countAt, size: _countSize, color: const Color(0xFFFFF1D6), outline: _dark);
  }

  /// What the drop popup says about giving [loot] to [u] ([Game.assignPreview]; an item's enhanced stack at +[plus],
  /// decisions-log 255): the title's icon, the title, and the lines.
  (Enum, String, List<_DropLine>) _dropWords(Enum loot, Unit u, [int plus = 0]) {
    final g = state, heals = u.stats.heals;
    _DropLine line(String text, {Object? icon, Color ink = _tipInk, String? after}) =>
        (icon: icon, text: text, ink: ink, after: after, afterInk: _effectInk);
    // A stat as the troop row writes it: whole from 100 up, else one decimal (none when whole); two when one
    // would show no change (a short pause between attacks).
    String f(num v) => v is int || v >= 100 || v == v.roundToDouble() ? '${v.round()}' : v.toStringAsFixed(1);
    _DropLine change(StatKind kind, num now, num after) {
      final (a, b) = f(now) == f(after) ? (now.toStringAsFixed(2), after.toStringAsFixed(2)) : (f(now), f(after));
      return line('${statName(kind, heals: heals)} $a', after: b);
    }

    final p = g.assignPreview(loot, loot is Item ? u.type : u, plus: plus), why = p.why;
    final changes = [if (why == null) for (final (kind, now, after) in p.stats) change(kind, now, after)];
    if (loot is Relic) {
      return (
        loot,
        u.hero ? 'Hero ${u.name}' : u.name,
        [
          line(troopTypeNames[u.type] ?? u.type),
          // A Hero's two slots (#91): how many are taken, now and after, then each relic it holds.
          if (u.relicSlots > 1) ...[
            line('Relic slots ${u.relics.length}/${u.relicSlots}', after: why == null ? '${u.relics.length + 1}/${u.relicSlots}' : null),
            for (final r in u.relics) line(relicNames[r]!, icon: r),
          ],
          if (why != null)
            line(why, ink: _blockedInk)
          else ...[
            for (final e in g.relicEffect(loot)) line(e, ink: _effectInk),
            ...changes,
          ],
        ],
      );
    }
    final item = loot as Item, all = g.troops.where((t) => t.alive && t.type == u.type).length;
    final lines = <_DropLine>[if (why != null) line(why, ink: _blockedInk), ...changes];
    // The kind's taken / cap (none for a kind outside the type's recipe), and the awakening it counts toward (or,
    // at its cap until then, how far that is).
    if (p.count case ((final n, final cap), (final n2, final cap2)) when cap > 0 || n > 0) {
      lines.add(line('${itemNames[item]} $n/$cap', icon: item, after: why == null ? '$n2/$cap2' : null));
    }
    final soon = why == null || g.whyNot(item, u.type, plus: plus) == Refusal.awakenFirst;
    if (p.awaken case (final level, final after) when after > level) {
      lines.add((icon: _starIcon, text: awakenName(level), ink: _tipInk, after: awakenName(after), afterInk: _awakeInk[after - 1]));
      // Its awakening skill unlocked or raised (#88): "Unlocks Disarm", or "Disarm > Disarm II".
      if (awakenSkillChange(u.type, level, after) case (final text, final to)?) {
        lines.add((icon: null, text: text, ink: to == null ? _awakeInk[after - 1] : _tipInk, after: to, afterInk: _awakeInk[after - 1]));
      }
    } else if (p.step case ((final have, final need), (final have2, _)) when soon) {
      final next = awakenName(g.awakenLevel(u.type) + 1);
      lines.add(line('$next: $have/$need', icon: _starIcon, after: why == null ? '$have2/$need' : null));
    }
    return (item, 'Every ${troopTypeNames[u.type] ?? u.type} ($all)', lines);
  }

  /// The drop popup: [title] led by [icon] (an item's enhanced stack's in its level's colour, [plus]), then [lines], in the
  /// tooltip frame, pointing at [target] (the troop and the loot at the pointer).
  void _dropBox(Canvas c, Enum icon, String title, List<_DropLine> lines, Rect target, [int plus = 0]) {
    const titleSize = 18.0, lineSize = 14.0, lineH = 19.0, iconW = 24.0, lineIcon = 16.0, gap = 3.0;
    // ui_icons.png's small white arrow between now and after (the font has none), as the Tas rows' ([Board._change]).
    final ak = math.max(1.0, (lineSize * 0.6 / _icThen.height).roundToDouble()), aw = _icThen.width * ak;
    double lead(_DropLine l) => (l.icon == null ? 0 : lineIcon + 4) + _textWidth(l.text, lineSize);
    final w = [
      iconW + 6 + _textWidth(title, titleSize, bold: true),
      for (final l in lines) lead(l) + (l.after == null ? 0 : gap * 2 + aw + _textWidth(l.after!, lineSize)),
    ].reduce(math.max);
    final at = _dropPlace(target, w + _inL * 2, _inT + iconW + 4 + lines.length * lineH + _inB), box = at.$1;
    _drop.at = box;
    _tipFrame(c, at);
    _icon(c, icon, Rect.fromLTWH(box.left + _inL, box.top + _inT, iconW, iconW), null, plus);
    _text(c, title, Offset(box.left + _inL + iconW + 6, box.top + _inT + iconW / 2), size: titleSize, color: _dark, bold: true);
    for (final (i, l) in lines.indexed) {
      final y = box.top + _inT + iconW + 4 + (i + 0.5) * lineH;
      var x = box.left + _inL;
      switch (l.icon) {
        case final Enum e:
          _icon(c, e, Rect.fromLTWH(x, y - lineIcon / 2, lineIcon, lineIcon));
        case final Rect src:
          c.drawImageRect(_img('ui_icons.png'), src, Rect.fromLTWH(x, y - lineIcon / 2, lineIcon, lineIcon), _px);
      }
      if (l.icon != null) x += lineIcon + 4;
      _text(c, l.text, Offset(x, y), size: lineSize, color: l.ink);
      if (l.after case final after?) {
        final ax = (x + _textWidth(l.text, lineSize) + gap).roundToDouble();
        c.drawImageRect(_img('ui_icons.png'), _icThen,
            Rect.fromLTWH(ax, (y - _icThen.height * ak / 2).roundToDouble(), aw, _icThen.height * ak), _px);
        _text(c, after, Offset(ax + aw + gap, y), size: lineSize, color: l.afterInk);
      }
    }
  }

  /// Where a [w]×[h] drop popup about [target] goes, and its pointer (as [_tipAt]'s). Tried in turn: above it
  /// (as a plate goes), left of it, right of it, and below it (the pointer up), each centred on it or lined up
  /// with one of its edges, and last beside it hanging from its bottom as low as the screen allows (under the shorter
  /// landscape book's edge, decisions-log 283, the room left there); the first that covers the least of the HUD wins (#74: the open book, the battle
  /// log's button and panel, the boss bars, the wave meter and the minimap, the troop counter and its list, the
  /// off-view marker, the Start/Pause toggle, x2 and Auto), and the target itself (the pointer) counts ten times. On the
  /// screen, under the top rows ([_rowsTop]; not a plate's floor under the map and the boss bars), on whole pixels.
  (Rect, _Aim, double) _dropPlace(Rect target, double w, double h) {
    const k = _tipK, m = 4.0, reach = 6 * k;
    final (bw, bh) = (w.ceilToDouble(), h.ceilToDouble());
    final top = math.max(m, _rowsTop);
    double fit(double v, double lo, double hi) => v.clamp(lo, math.max(lo, hi)).roundToDouble();
    Rect boxAt(double x, double y) => Rect.fromLTWH(fit(x, m, size.x - bw - m), fit(y, top, size.y - bh - m), bw, bh);
    final xs = [target.center.dx - bw / 2, target.right - bw, target.left], ys = [target.center.dy - bh / 2, target.top, target.bottom - bh];
    // Along the top or bottom edge, where the pointer's piece starts (its tip over the target's middle).
    double along(Rect box, double piece) => fit(target.center.dx - piece / 2, box.left + 3 * k, box.right - 3 * k - piece);
    final tries = [
      for (final x in xs)
        switch (boxAt(x, target.top - (_tipDown.height - 5) * k - bh)) { final box => (box, _Aim.down, along(box, _tipDown.width * k)) },
      for (final (aim, x) in [(_Aim.right, target.left - reach - bw), (_Aim.left, target.right + reach)])
        for (final y in ys)
          switch (boxAt(x, y)) {
            final box => (box, aim, fit(target.center.dy - 6.5 * k, box.top + 3 * k, box.bottom - 5 * k - _tipSide.height * k))
          },
      for (final x in xs)
        switch (boxAt(x, target.bottom + 6 * k)) { final box => (box, _Aim.up, along(box, _tipSide.height * k)) },
      // Last, beside it hanging from its bottom where it stays beside it (under the shorter landscape book's edge,
      // decisions-log 283, the room there).
      for (final (aim, x) in [(_Aim.right, target.left - reach - bw), (_Aim.left, target.right + reach)])
        if (boxAt(x, target.bottom) case final box when box.right <= target.left || box.left >= target.right)
          (box, aim, fit(target.center.dy - 6.5 * k, box.top + 3 * k, box.bottom - 5 * k - _tipSide.height * k)),
    ];
    final keep = [
      _bookArea, _log.button, if (_log.open) _log.panel, _bossAt, _meterAt, _map.at, _troops.button, _troops.list, //
      _offViewAt, _toggleAt, _speedAt, _autoAt, _chest.chip,
    ];
    double area(Rect a, Rect b) {
      final i = a.intersect(b);
      return i.width > 0 && i.height > 0 ? i.width * i.height : 0;
    }

    double covers(Rect box) => keep.fold(area(box, target) * 10, (sum, r) => sum + area(box, r));
    return tries.reduce((best, t) => covers(t.$1) < covers(best.$1) ? t : best);
  }
}
