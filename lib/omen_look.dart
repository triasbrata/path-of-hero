part of 'main.dart';

// The Shadows seen (catalog step 0h, decisions-log 191; docs/ui-hud.md "Shadows"; their rules: lib/omen.dart, docs/
// loot-items-relics.md "Bayangan"). From wave [omenFrom] every Artifact card of a Boss Chest hides a Shadow, a buff
// the monsters get when the card is taken: the card shows "?" and its strength as red "!" marks by its rarity
// ([omenMarks]), never its kind ([Board._omenFace]). Taking it reveals it ([_Reveal]): the cards' marks flip over, the
// taken one's to its kind and level, the others' to theirs in grey with "Dodged", and the ribbon says what the monsters
// got; a tap skips it, and Auto waits for it. The kinds the monsters hold sit in a row of chips under the wave meter
// ([Board._omenChips]), with Lewati's skip buff as a "!" chip while it is owed or on; the pointer resting on it, or a
// tap, shows what each does ([Omens.omenTip]). Every picture is a cell of a sheet the game has: ui_icons.png's "?" and
// "!" tinted [_monsterPop], each kind's [OmenKind.icon], and Escort's the wave's strongest monster in gold. Nothing of
// it shows while [omensOn] is off.

/// The reveal after a take ([_Reveal]): how long it holds the popup, and how long one card's marks take to flip.
const omenRevealFor = 1.2, omenFlip = 0.3;

/// A troop under the Bayangan Blight ([Omens.blighted]: no heals for a while): its body recoloured part way to Blight's
/// olive ([tintOlive], its chip's), as a monster's rank recolours its own ([_partTint], tier_look.dart). The sprite as
/// drawn, no shape added.
final _blightPaint = Paint()
  ..filterQuality = FilterQuality.none
  ..colorFilter = _partTint(const Color(tintOlive), 0.45);

/// ui_icons.png's "?" (192, 48) and "!" (192, 32), cut to their inked columns over rows 1-14, so the marks sit close.
const _markAsk = Rect.fromLTWH(196, 49, 8, 14), _markBang = Rect.fromLTWH(198, 33, 4, 14);

/// The marks' red (the monster skills' pop, [_monsterPop]), a revealed Shadow's line on the card (catalog-design §2.6's
/// dark red, which reads on the card's paper), and a dodged one's grey.
const _omenInk = Color(0xFFA0322D), _dodgedInk = Color(0xFF8E8A86);

/// The marks tinted red, and the grey of a dodged Shadow and of marks with every kind full, made once.
final _markPaint = _tintedPaint(_monsterPop);
final _omenGrey = Paint()
  ..filterQuality = FilterQuality.none
  ..colorFilter = Board._greyscale;

/// A Barrier on a boss bar ([Board._bossBar]): the Shadows' teal ([tintTeal]) over its shade, as the bars' layers are.
const _barrierFill = (Color(tintTeal), Color(0xFF23877D));

/// How wide a row of marks [h] tall is ([Board._omenMarks]): "?" (with [ask]) and [n] "!", 2 sprite px apart.
double omenMarksWidth(int n, double h, {bool ask = true}) {
  final q = h / _markAsk.height, glyphs = n + (ask ? 1 : 0);
  return glyphs == 0 ? 0 : ((ask ? _markAsk.width : 0) + n * _markBang.width + (glyphs - 1) * 2) * q;
}

/// The reveal after a take ([Board._chestTake]): the chest's [cards] and [faces] as they were (and their lines and the
/// buttons' labels, as last drawn), the card [taken], the ribbon's line ([Omens.omenGotLine]), the taken chip's label
/// ("Armor 2"), the message to show after it, and when it began (the screen clock).
class _Reveal {
  _Reveal({required this.cards, required this.faces, required this.taken, required this.got, required this.label, required this.message, required this.since});

  final List<Relic?> cards;
  final List<OmenKind?> faces;
  final int taken;
  final String got, label, message;
  final double since;
  var lines = <List<_SplashLine>>[], labels = <String>[]; // the cards' lines and the buttons' labels as they were
}

/// The row of the Shadows' chips under the wave meter between frames: where it was drawn (Rect.zero: none), each chip
/// and its kind (null: Lewati's skip buff), until when a tap keeps its tooltip up (the screen clock), and whether the
/// last press landed on it.
class _OmenRow {
  Rect at = Rect.zero;
  final chips = <(Rect, OmenKind?)>[];
  double tipUntil = 0;
  bool tapped = false;
}

extension _OmenLook on Board {
  /// Shadow [kind]'s icon in [to] ([OmenKind.icon]: a 16 px cell a tenth inside, as an Artifact's is); Escort's, which
  /// has none, the wave's strongest monster ([poolOf]'s last, as its boss bar's portrait shows it) in gold. [grey]:
  /// dodged.
  void _omenIcon(Canvas c, Game g, OmenKind kind, Rect to, {bool grey = false}) {
    if (kind.icon case final icon?) {
      final src = Rect.fromLTWH(icon.x.toDouble(), icon.y.toDouble(), icon.size.toDouble(), icon.size.toDouble());
      final paint = grey ? _omenGrey : switch (icon.tint) { null => _px, final tint => _iconTints[tint] ??= _tintedPaint(Color(tint)) };
      c.drawImageRect(_img(icon.sheet), src, icon.size == 16 ? to.deflate(to.width * 0.1) : to, paint);
      return;
    }
    final type = poolOf(g.waveActive ? g.wave : g.wave + 1).last, b = _idleBounds[type];
    if (b == null) return;
    final s = math.min(to.width / b.width, to.height / b.height);
    c.save();
    c.translate(to.center.dx, to.bottom);
    c.scale(s);
    _frame(c, 'tiny_${type}_idle.png', 0, Offset.zero,
        anchor: Offset(b.center.dx, b.bottom), flip: true, paint: grey ? _omenGrey : _iconTints[tintGold] ??= _tintedPaint(const Color(tintGold)));
    c.restore();
  }

  /// A row of marks [h] tall, its left middle at [at]: "?" (with [ask]) and [n] "!" ([omenMarksWidth]), in red, or in
  /// [paint]. Its width.
  double _omenMarks(Canvas c, Offset at, double h, int n, {bool ask = true, Paint? paint}) {
    final q = h / _markAsk.height, img = _img('ui_icons.png');
    var x = at.dx;
    for (final src in [if (ask) _markAsk, for (var i = 0; i < n; i++) _markBang]) {
      c.drawImageRect(img, src, Rect.fromLTWH(x, at.dy - h / 2, src.width * q, h), paint ?? _markPaint);
      x += (src.width + 2) * q;
    }
    return omenMarksWidth(n, h, ask: ask);
  }

  /// A chest card's hidden Shadow ([face], for card [i] of [relic]) in [area]: "?" and its marks ([omenMarks] by the
  /// card's rarity; grey when no kind has room, [omenPlace]) after "Monsters:" (text [ts]). While [reveal] shows, it
  /// flips over ([omenFlip]; the taken card's first, the others half a flip later) to the kind's icon and its label after
  /// it: the taken one's "Armor 2" on a red glow, the others' grey, "Dodged".
  void _omenFace(Canvas c, Game g, Rect area, OmenKind face, Relic relic, double ts, {required int i, _Reveal? reveal}) {
    final h = area.height, n = omenMarks[relic.rarity]!, taken = reveal != null && i == reveal.taken;
    final full = reveal == null && omenPlace(g.omens, face, omenPool(relic.rarity), n).isEmpty;
    final p = reveal == null ? 0.0 : ((_clock - reveal.since - (taken ? 0 : omenFlip / 2)) / omenFlip).clamp(0.0, 1.0);
    final back = p >= 0.5, sx = math.cos(math.pi * p).abs(), gap = 4 * h / 14;
    final name = taken ? reveal.label : 'Dodged', ink = taken ? _omenInk : _dodgedInk;
    final text = back ? name : 'Monsters:', textW = _textWidth(text, ts) + gap;
    final markW = back ? h : omenMarksWidth(n, h), x0 = area.center.dx - (textW + markW) / 2;
    _chest.faces.add(back ? name : '?${'!' * n}');
    void squash(Rect about, void Function() draw) {
      c.save();
      c.translate(about.center.dx, 0);
      c.scale(sx, 1);
      c.translate(-about.center.dx, 0);
      draw();
      c.restore();
    }

    squash(area, () {
      if (back) {
        final icon = Rect.fromLTWH(x0, area.top, h, h);
        if (taken) c.drawCircle(icon.center, h * 0.6, Paint()..color = _monsterPop.withValues(alpha: 0.3));
        _omenIcon(c, g, face, icon, grey: !taken);
        _text(c, text, Offset(icon.right + gap, area.center.dy), size: ts, color: ink);
      } else {
        _text(c, text, Offset(x0, area.center.dy), size: ts, color: _tipInk);
        _omenMarks(c, Offset(x0 + textW, area.center.dy), h, n, paint: full ? _omenGrey : null);
      }
    });
  }

  /// The Shadows' chips under the wave meter ([_OmenRow]), right-aligned with it, under the open map, and under the
  /// "Peti!" chip where it shares their columns (under the Start/Pause
  /// toggle: [Board._chestChip], as last drawn), the boss bars under them ([_bossBars]); while the book shows at the left
  /// under the top row, as the boss bars go ([_asideLeft]; the map stays under the meter). On the HUD's dark panel, one chip a kind the
  /// monsters hold ([OmenKind] order), its icon on a red glow and its level, 11 sprite px wide at the wave meter's
  /// scale; then Lewati's skip buff, owed or on, as a "!" ([Game.skipBuffDue], [Game.waveSkipBuff]). None while
  /// [omensOn] is off, at game over or with nothing to show.
  void _omenChips(Canvas c, Game g) {
    final row = _omenRow..at = Rect.zero;
    row.chips.clear();
    if (!omensOn || g.over || _meterAt.isEmpty) return;
    final kinds = <OmenKind?>[
      for (final k in OmenKind.values)
        if (g.omenLevel(k) > 0) k,
      if (g.skipBuffDue || g.waveSkipBuff) null,
    ];
    if (kinds.isEmpty) return;
    final k = _meterK, pad = 2 * k, icon = 7 * k, chipW = 11 * k, gap = k, n = kinds.length;
    final w = 2 * pad + n * chipW + (n - 1) * gap, h = icon + 2 * pad, aside = _asideLeft;
    final left = (aside ? _edgeL : _meterAt.right - w).roundToDouble(), chip = _chest.chip; // the "Peti!" chip, as last drawn
    final underChip = chip.right > left && chip.left < left + w; // in the same columns (under the Start/Pause toggle)
    final top = aside
        ? [_meterBottom, if (_troops.open) _troops.list.bottom, if (underChip) chip.bottom].reduce(math.max) + 4
        : [_meterAt.bottom, _map.at.bottom, if (underChip) chip.bottom].reduce(math.max) + 6;
    // Under the meter, left of the pocket bar where it would come down beside it (pocket_look.dart).
    final at = row.at = Rect.fromLTWH(aside ? left : (_stackRight(top, h) - w).roundToDouble(), top.roundToDouble(), w, h);
    _panel(c, at);
    var x = at.left + pad;
    for (final kind in kinds) {
      final ic = Rect.fromLTWH(x, at.top + pad, icon, icon);
      c.drawCircle(ic.center, icon * 0.5, Paint()..color = _monsterPop.withValues(alpha: 0.3));
      if (kind == null) {
        _omenMarks(c, Offset(x + (chipW - omenMarksWidth(1, icon, ask: false)) / 2, ic.center.dy), icon, 1, ask: false);
      } else {
        _omenIcon(c, g, kind, ic);
        _text(c, '${g.omenLevel(kind)}', Offset(ic.right + k / 2, ic.center.dy + k / 2), size: 5 * k);
      }
      row.chips.add((Rect.fromLTWH(x, at.top + pad, chipW, icon), kind));
      x += chipW + gap;
    }
  }

  /// A press: on the chips' row it shows their tooltip for a while ([_OmenRow.tipUntil]), or hides it if it shows; any
  /// other press hides it. True when it landed on the row.
  bool _omenDown(Offset p) {
    final row = _omenRow;
    row.tapped = row.at.contains(p);
    row.tipUntil = row.tapped && _clock >= row.tipUntil ? _clock + _omenTipFor : 0;
    return row.tapped;
  }

  /// The Shadows' tooltip under their chips ([target], the row), pointing up at it: "Monster Shadows" by a red "!",
  /// then [Omens.omenTip]'s lines, a kind's led by its icon and Lewati's by a "!", each wrapped to the screen (at most
  /// 360 px of text; where that box won't fit under the row, as on a phone's short screen, at most 600, decisions-log
  /// 291). Right-aligned with the row (at the left, left-aligned).
  void _omenTip(Canvas c, Rect target) {
    final g = state, kinds = [for (final k in OmenKind.values) if (g.omenLevel(k) > 0) k];
    final (title, lines) = g.omenTip;
    const titleSize = 18.0, lineSize = 14.0, lineH = 19.0, icon = 24.0, lineIcon = 16.0, k = _tipK, m = 4.0;
    final skip = g.skipBuffDue || g.waveSkipBuff, under = target.bottom + 6 * k;
    // Each line wrapped to [width] (the screen's at the most); its first row led by its kind's icon (a kind's line) or the
    // "!" (Lewati's, the last).
    List<(Object?, double, String)> wrapAt(double width) {
      final maxW = math.min(width, size.x - 2 * m - 2 * _inL), rows = <(Object?, double, String)>[];
      for (final (i, l) in lines.indexed) {
        final Object? lead = i < kinds.length ? kinds[i] : (skip && i == lines.length - 1 ? 'skip' : null);
        final indent = lead == null ? 0.0 : lineIcon + 4;
        for (final (j, piece) in _wrap(l, lineSize, maxW - indent).indexed) {
          rows.add((j == 0 ? lead : null, indent, piece));
        }
      }
      return rows;
    }

    double heightOf(int rows) => (_inT + icon + 4 + rows * lineH + _inB).ceilToDouble();
    var rows = wrapAt(360);
    if (under + heightOf(rows.length) > size.y - m) rows = wrapAt(600); // too tall to fit under the row: wider, fewer rows
    _tip.drawn = (title, [for (final (_, _, l) in rows) l]); // as drawn: the lines wrapped
    final textW = [icon + 6 + _textWidth(title, titleSize, bold: true), for (final (_, x, l) in rows) x + _textWidth(l, lineSize)].reduce(math.max);
    final (bw, bh) = ((textW + 2 * _inL).ceilToDouble(), heightOf(rows.length));
    double fit(double v, double lo, double hi) => v.clamp(lo, math.max(lo, hi)).roundToDouble();
    final box = _tip.box = Rect.fromLTWH(
        fit(_asideLeft ? target.left : target.right - bw, m, size.x - bw - m), fit(under, m, size.y - bh - m), bw, bh);
    final piece = _tipSide.height * k;
    _tipFrame(c, (box, _Aim.up, fit(target.center.dx - piece / 2, box.left + 3 * k, box.right - 3 * k - piece)));
    final titleIcon = Rect.fromLTWH(box.left + _inL, box.top + _inT, icon, icon);
    c.drawCircle(titleIcon.center, icon * 0.5, Paint()..color = _monsterPop.withValues(alpha: 0.3));
    _omenMarks(c, Offset(titleIcon.center.dx - omenMarksWidth(1, icon * 0.8, ask: false) / 2, titleIcon.center.dy), icon * 0.8, 1, ask: false);
    _text(c, title, Offset(titleIcon.right + 6, titleIcon.center.dy), size: titleSize, color: _dark, bold: true);
    for (final (i, (lead, indent, l)) in rows.indexed) {
      final y = box.top + _inT + icon + 4 + (i + 0.5) * lineH, x = box.left + _inL;
      final to = Rect.fromLTWH(x, y - lineIcon / 2, lineIcon, lineIcon);
      if (lead case final OmenKind kind) _omenIcon(c, g, kind, to);
      if (lead == 'skip') _omenMarks(c, Offset(to.center.dx - omenMarksWidth(1, lineIcon, ask: false) / 2, y), lineIcon, 1, ask: false);
      _text(c, l, Offset(x + indent, y), size: lineSize, color: _tipInk);
    }
  }
}

/// How long a tap keeps the Shadows' tooltip up ([Board._omenDown]): another tap on the row, or any press, hides it.
const _omenTipFor = 6.0;
