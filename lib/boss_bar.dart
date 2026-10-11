part of 'main.dart';

// The boss bars (#67; the owner: "ketika muncul boss dan mini boss perlu dibuatkan bar darah khusus di
// guinya dan namanya siapa jadi user tau mini boss dan boss yang dilawan"). While the wave's mini boss or
// boss is on the field ([Game.bossBarUnits]) it has a bar of its own at the top of the screen, the boss's
// on top: on the HUD's dark panel, the pack's portrait frame with the monster in it; its name and
// title ([bossBarName]); its rank in the rank's colour and its type; its HP in layers of [bossBarLayer]
// ([bossLayers]): the current layer drains over the next one's colour, "×N" layers left beside it; its MP
// under it (the necromancers). As the monster dies its bar shakes, drops and fades ([deathTime]). With the Shadows on
// (omen_look.dart) a Barrier shows as a teal segment over the HP ([Unit.shield]), and the Escort it brings after its
// rank and type ("+2 escort").

/// The last layer's colour (×1): the pack's red strip, so red means nearly dead.
const _lastLayer = (Color(0xFFE43B44), Color(0xFF9E2835));

/// The other layers' colours (fill, shade), from ×2 up, cycling, so every layer that breaks shows a new
/// colour under the one draining ([_layerColor]).
const _layerColors = [
  (Color(0xFFFF8A24), Color(0xFFB2520C)), // the boss's orange
  (Color(0xFFFEE761), Color(0xFFFEAE34)), // the pack's gold
  (Color(0xFF63C74D), Color(0xFF3E8948)), // the pack's green
  (Color(0xFFD9DEE8), Color(0xFF8C94A3)), // the elites' silver (no HP is blue: blue means MP, #62)
  (Color(0xFFA24BD8), Color(0xFF65278F)), // the mini boss's purple
];

/// ui_bars.png: the portrait frame (its dark inside 13x13 from (3, 3)), the left one of the pack's
/// portrait-and-bars sets.
const _bossFrame = Rect.fromLTWH(256, 6, 19, 19);
const _bossBarLen = 70.0; // the HP bar's length in sprite px
const _bossBack = Color(0xFF414B63); // behind the portrait: a slate, so a dark monster stands out

/// Layer [n]'s colours (1 is the last).
(Color, Color) _layerColor(int n) => n <= 1 ? _lastLayer : _layerColors[(n - 2) % _layerColors.length];
const _bossRankInk = Color(0xFFE8D6B0); // the type's name after the rank: cream, as the troop list's names

extension _BossBars on Board {
  /// Every boss bar, stacked under the wave meter at the top right, right-aligned with it: under the open
  /// map (mini_map.dart) and the Shadows' chips (omen_look.dart). Full bars, unless two of them would reach down onto the
  /// field where the units walk (a small screen with the mini boss and the boss): then compact ones. While the book
  /// shows (opened mid-wave) its tabs and top edge would cover them under the meter: then compact, at the left under the top row (and
  /// under the open troop list and the Shadows' chips, which go there too; the map stays under the meter), clear of the
  /// book, until it closes ([Board._bossAside]). Where they are, all of them, is [Board._bossAt] (`render` resets both).
  void _bossBars(Canvas c, Game g) {
    final units = g.bossBarUnits;
    final aside = _bossAside = _asideLeft && units.isNotEmpty;
    final top0 = aside
        ? [_meterBottom, if (_troops.open) _troops.list.bottom, _omenRow.at.bottom].reduce(math.max) + 4
        : [_meterAt.isEmpty ? _meterBottom : _meterAt.bottom, _map.at.bottom, _omenRow.at.bottom, _townChipAt.bottom, _boostRowAt.bottom]
                .reduce(math.max) +
            6;
    final full = units.fold(top0 - 4, (y, u) => y + 4 + _bossBarH(u, false));
    final compact = aside || (units.length > 1 && full > _origin.dy + backdropH * _scale);
    var top = top0;
    final room = aside && !_bookArea.isEmpty ? _bookArea.left - 8 - _edgeL : null;
    for (final u in units) {
      top = _bossBar(c, u, top, compact, left: aside ? _edgeL : null, maxW: room) + 4;
    }
  }

  /// How tall boss [u]'s bar is: full (the portrait's height at least), or [compact] (one line of text over
  /// the bars, less padding).
  double _bossBarH(Unit u, bool compact) {
    final k = _meterK, barsH = (u.stats.mp > 0 ? 9 : 5) * k;
    return compact ? 7 * k + k + barsH + 3 * k : math.max(19 * k, 7 * k + 6 * k + k + barsH) + 4 * k;
  }

  /// Boss [u]'s bar, its top at [top], its left at [left] (none: its right at the wave meter's right); where
  /// its bottom is. [compact]: no portrait, and its rank then its name on
  /// one line (no type), the name cut with ".." to keep the bar within [maxW].
  double _bossBar(Canvas c, Unit u, double top, bool compact, {double? left, double? maxW}) {
    final k = _meterK, pad = (compact ? 1.5 : 2) * k, nameSize = 6 * k, lineSize = 5 * k, frame = compact ? 0.0 : 19 * k;
    final layers = bossLayers(u.hp, u.maxHp), mp = u.stats.mp > 0, guards = omensOn ? state.omenGuards : 0;
    final rank = '${tierNames[u.tier]} ', type = monsterTypeNames[u.type] ?? u.type, escort = guards > 0 ? '  +$guards escort' : '';
    final name = compact && maxW != null
        ? _fit(bossBarName(u), nameSize, math.max(0.0, maxW - 2 * pad - _textWidth(rank, nameSize)))
        : bossBarName(u);
    // The count keeps the room of the most layers it will show, so the bar doesn't twitch as it drops.
    final barW = _bossBarLen * k, countW = _textWidth('×${layers.total}', nameSize);
    final colW = [
      if (compact) _textWidth(rank, nameSize) + _textWidth(name, nameSize) else _textWidth(name, nameSize),
      if (!compact) _textWidth(rank, lineSize) + _textWidth(type, lineSize) + (escort.isEmpty ? 0 : _textWidth(escort, lineSize)),
      barW + pad + countW,
    ].reduce(math.max);
    final nameH = 7 * k, lineH = compact ? 0.0 : 6 * k;
    final h = _bossBarH(u, compact), w = (pad + (compact ? 0 : frame + 3 * k) + colW + pad).roundToDouble();
    final panel = Rect.fromLTWH(left ?? ((_meterAt.isEmpty ? size.x - _edgeR : _meterAt.right) - w).roundToDouble(), top, w, h);
    _bossAt = _bossAt.isEmpty ? panel : _bossAt.expandToInclude(panel);

    // Dying, it breaks away: a shake, then it drops and fades.
    final p = u.dying < 0 ? 0.0 : (u.dying / deathTime).clamp(0.0, 1.0);
    c.save();
    if (p > 0) {
      final shake = p < 0.3 ? math.sin(p * 90) * 2 * k * (1 - p / 0.3) : 0.0;
      c.translate(shake.roundToDouble(), (p * p * 12 * k).roundToDouble());
      c.saveLayer(panel.inflate(4 * k), Paint()..color = Colors.white.withValues(alpha: 1 - p));
    }
    _panel(c, panel);

    // The portrait: on a slate, the monster's idle strip, its visible pixels as tall as the frame's inside
    // (a wide one a little cropped at the sides), feet on the bottom, facing the troops.
    final fr = Rect.fromLTWH(panel.left + pad, (panel.center.dy - frame / 2).roundToDouble(), frame, frame);
    final back = Rect.fromLTWH(fr.left + 3 * k, fr.top + 3 * k, 13 * k, 13 * k);
    if (!compact) {
      c.drawImageRect(_img('ui_bars.png'), _bossFrame, fr, _px);
      c.drawRect(back, Paint()..color = _bossBack);
    }
    if (_idleBounds[u.type] case final b? when !compact) {
      final inside = back, s = math.min(inside.height / b.height, 1.4 * inside.width / b.width);
      c.save();
      c.clipRect(inside);
      c.translate(inside.center.dx, inside.bottom - k);
      c.scale(s);
      final f = (_clock * _fps).floor(), anchor = Offset(b.center.dx, b.bottom);
      _frame(c, 'tiny_${u.type}_idle.png', f, Offset.zero, anchor: anchor, flip: true);
      // Winding up a skill, it flashes red: the same frame over it, flat red and pulsing (skills.dart).
      if (u.winding != null) _frame(c, 'tiny_${u.type}_idle.png', f, Offset.zero, anchor: anchor, flip: true, paint: _windFlash());
      c.restore();
    }

    // Its name; its rank in the rank's colour, then its type. Compact: its rank, then its name.
    final x = compact ? panel.left + pad : fr.right + 3 * k, nameY = panel.top + pad + nameH / 2, lineY = panel.top + pad + nameH + lineH / 2;
    if (compact) {
      _text(c, rank, Offset(x, nameY), size: nameSize, color: _tierBar[u.tier]!.$1);
      _text(c, name, Offset(x + _textWidth(rank, nameSize), nameY), size: nameSize, color: u.winding != null ? _monsterPop : Colors.white);
    } else {
      _text(c, name, Offset(x, nameY), size: nameSize);
      _text(c, rank, Offset(x, lineY), size: lineSize, color: _tierBar[u.tier]!.$1);
      _text(c, type, Offset(x + _textWidth(rank, lineSize), lineY), size: lineSize, color: _bossRankInk);
      if (escort.isNotEmpty) _text(c, escort, Offset(x + _textWidth(rank, lineSize) + _textWidth(type, lineSize), lineY), size: lineSize, color: _monsterPop);
    }

    // The HP layers: the long empty bar ([_waveMeter]'s), the next layer's colour under the current one,
    // both a whole sprite px at a time; "×N" after it.
    final bar = Rect.fromLTWH(x, panel.top + pad + nameH + lineH + k, barW, 5 * k);
    _bossBarFrame(c, bar);
    final inside = _bossBarInside(bar);
    if (layers.left > 1) _bossFill(c, inside, 1, _layerColor(layers.left - 1));
    if (layers.left > 0) _bossFill(c, inside, layers.fill, _layerColor(layers.left));
    // A Barrier (omen_look.dart) over them: teal, its share of what it came on with ([Omens.omenK]'s of its max HP),
    // draining from the first blow that breaks some.
    if (u.shield > 0) {
      final full = u.maxHp * state.omenK(OmenKind.shield);
      _bossFill(c, inside, full > 0 ? math.min(1.0, u.shield / full) : 1.0, _barrierFill);
    }
    if (p > 0 && p < 0.2) c.drawRect(inside, Paint()..color = Colors.white); // the last blow's flash
    _text(c, '×${layers.left}', Offset(bar.right + pad, bar.center.dy), size: nameSize);

    // The MP: the same bar under it, sharing its bottom rim, filled cyan like a monster's MP on the field.
    if (mp) {
      final mpBar = bar.translate(0, 4 * k);
      _bossBarFrame(c, mpBar);
      _bossFill(c, _bossBarInside(mpBar), (u.mp / u.stats.mp).clamp(0.0, 1.0), _monsterMp);
    }
    if (p > 0) c.restore();
    c.restore();
    return panel.bottom;
  }

  /// A boss bar's portrait winding up a skill: its sprite flat in the skill pop's red, pulsing.
  Paint _windFlash() => Paint()
    ..filterQuality = FilterQuality.none
    ..colorFilter = _flat(_monsterPop)
    ..color = Colors.white.withValues(alpha: 0.35 + 0.35 * math.sin(_fieldClock * 14).abs());

  /// ui_bars.png's long empty bar (1, 15, 30x5) stretched to [r]: its left 5 columns (the checkered end)
  /// and its last kept, the middle stretched.
  void _bossBarFrame(Canvas c, Rect r) {
    final k = r.height / 5, bars = _img('ui_bars.png');
    c.drawImageRect(bars, const Rect.fromLTWH(1, 15, 5, 5), Rect.fromLTWH(r.left, r.top, 5 * k, r.height), _px);
    c.drawImageRect(bars, const Rect.fromLTWH(6, 15, 24, 5), Rect.fromLTRB(r.left + 5 * k, r.top, r.right - k, r.bottom), _px);
    c.drawImageRect(bars, const Rect.fromLTWH(30, 15, 1, 5), Rect.fromLTRB(r.right - k, r.top, r.right, r.bottom), _px);
  }

  /// The inside of a long bar [r]: 3 sprite px tall, from its checkered end to its last column but one.
  Rect _bossBarInside(Rect r) {
    final k = r.height / 5;
    return Rect.fromLTRB(r.left + 5 * k, r.top + k, r.right - k, r.bottom - k);
  }

  /// [share] of [inside] filled from the left in whole sprite px (any share at all shows one): 2 px of the
  /// colour over 1 of its shade.
  void _bossFill(Canvas c, Rect inside, double share, (Color, Color) colors) {
    final k = inside.height / 3, n = (inside.width / k * share).ceil();
    if (share <= 0 || n <= 0) return;
    final w = n * k;
    c.drawRect(Rect.fromLTWH(inside.left, inside.top, w, 2 * k), Paint()..color = colors.$1);
    c.drawRect(Rect.fromLTWH(inside.left, inside.top + 2 * k, w, k), Paint()..color = colors.$2);
  }
}
