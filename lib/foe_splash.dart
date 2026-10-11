part of 'main.dart';

// A monster skill's first-sighting splash (champion-fx Part 4; the owner, 2026-10-02: "dan ketika champion musuh (<
// mini boss) skill juga ada effectnya dan ada splash screennya"; docs/ui-hud.md "Foe splash"). The first time this
// device ever sees one of the 42 monster skills cast ([Game.monsterCasts]: a wind-up beginning, Reassemble and Split as
// they go off), the field stands still for up to [foeSplashTime] while a panel says what the skill does and how to stop
// it. At most [foeSplashPerWave] a wave; a boss's moment always. It replaces that cast's banner (foe_cut_in.dart). A
// tap, Esc or P closes it, and that press does nothing else. The skills seen are `foe.<skill>` keys in the guide's seen
// set ([Settings.seen], settings.json), so a new game never brings one back; with no seen set (a widget test's board)
// and with Settings' "Monster spotlight" off there are none.
//
// The freeze is not the pause: the game's tick is skipped and the time goes into the field's stopped clock
// ([_Pause.still]), but there is no "Pause" title, no quieter music, and the screen-clock overlays (the Hero cut-ins,
// the foe banners, the Grail's plate) wait with it. The look is the packs' art: the tooltip frame's body, the book's
// red ribbon with the "!", the caster on the book's paper card in its rank's colours, the wave meter's bar for the time
// left. The screen dims round the caster as under a Hero's cut-in (hero_cast.dart), so its red wind-up circle
// (skills.dart) shows where it stands.

/// How long a foe skill's splash shows at most (s, on the screen's clock), and how many a wave may show besides a boss's
/// moments (which always show).
const foeSplashTime = 4.0, foeSplashPerWave = 1;

/// Skill [s]'s key in the seen set once its splash has shown: `foe.warShout`.
String foeSplashKey(MonsterSkill s) => 'foe.${s.name}';

/// The splash between frames: the cast showing (null: none) and since when (screen clock); whether the last press
/// closed it; the game and wave its count is for, and how many it has shown there (a boss's moment not counted); and
/// what the panel drew this frame, for tests.
class _FoeSplash {
  FoeCut? showing;
  double since = 0;
  bool tapped = false;
  Game? game;
  int wave = -1, shown = 0;
  Rect panel = Rect.zero;
  String title = '', line = '';
  String? hint;
  List<String> lines = const [];
  double textSize = 0, textRoom = 0, titleSize = 0;
}

/// The wave meter's long empty bar (ui_bars.png, 30×5; its left 5 and right 1 columns kept, wave_meter.dart), the
/// splash's time left, filled with the meter's red column ([_meterRed]).
const _splashBar = Rect.fromLTWH(1, 15, 30, 5);

extension on Board {
  /// Whether a foe splash shows: the guide's one-time cards wait for it (coach.dart), and so does a Hero splash.
  bool get _foeSplashBusy => _foeSplash.showing != null;

  /// [_foeCast]: monster [u] of rank [rank] casts [s]. Its splash opens when this device has never seen [s] (and keeps
  /// a seen set: none in a widget test until it sets one), "Monster spotlight" is on, nothing else is up (a splash, a guide
  /// card, the Hero splash, the chest, a pause, a book page off Army, a drag, the game over), and the wave has room
  /// ([foeSplashPerWave]; a boss's moment always). Shown, it is seen and settings.json saved. True when it opened; a
  /// cast turned away tries again with the skill's next cast.
  bool _foeSplashOpen(Game g, Unit u, MonsterSkill s, Tier rank) {
    final v = _foeSplash, seen = _settings.seen;
    if (seen == null || !_settings.foeCutIns || seen.contains(foeSplashKey(s))) return false;
    if (v.showing != null || _coach.showing || _herald.who != null || _chest.open) return false;
    if (g.paused || g.over || welcome != null || _page != _Page.troops || dragAt != null) return false;
    if (!identical(g, v.game) || g.wave != v.wave) {
      v
        ..game = g
        ..wave = g.wave
        ..shown = 0;
    }
    final moment = s.rank == MonsterRank.moment;
    if (!moment && v.shown >= foeSplashPerWave) return false;
    if (!moment) v.shown++;
    v
      ..showing = (u, s, rank)
      ..since = _clock;
    _see([foeSplashKey(s)]); // coach.dart: the seen set, saved
    return true;
  }

  void _foeSplashClose() => _foeSplash.showing = null;

  /// Every frame, before the game's tick: while a splash shows, the field stands still (true: no tick this frame). The
  /// time goes into the field's stopped clock (unless the game is paused too, which counts it already) and the
  /// screen-clock overlays wait: the Hero cut-ins, the foe banners (a desk banner's side too) and the Grail's plate.
  /// After [foeSplashTime], or once another game came in, it closes and the game goes on this frame.
  bool _foeSplashHolds(Game g, double dt) {
    final v = _foeSplash;
    if (v.showing == null) return false;
    if (!identical(g, v.game) || g.over || _clock - v.since >= foeSplashTime) {
      _foeSplashClose();
      return false;
    }
    _cutIns.since += dt;
    if (_foeLook.sideFor == _foeCuts.since) _foeLook.sideFor += dt;
    _foeCuts.since += dt;
    _pusakaLook.cutSince += dt;
    if (!g.paused) _pause.still += dt;
    return true;
  }

  /// A press while a splash shows closes it, and is used up (its tap up and drag go nowhere). True when it did.
  bool _foeSplashDown() {
    final on = _foeSplashBusy;
    if (on) _foeSplashClose();
    return _foeSplash.tapped = on;
  }

  /// Esc or P while a splash shows closes it (P doesn't pause). True when it did.
  bool _foeSplashKey(LogicalKeyboardKey key) {
    if (!_foeSplashBusy || (key != LogicalKeyboardKey.escape && key != LogicalKeyboardKey.keyP)) return false;
    _foeSplashClose();
    return true;
  }

  /// The splash ([_FoeSplash]) over the HUD: the screen dimmed 45% but round the caster, then the panel popping in over
  /// [_heraldIn] and fading over the last [_heraldOut]. In the tooltip frame's body (as the Hero splash's panel): the
  /// caster on the book's paper card ([_foePortrait], 3×) beside the red ribbon with the "!" and the skill's English
  /// title, `<type> <rank>` under it; then what it does ([monsterSkillText], 2 lines at most), how to stop it
  /// ([monsterSkillHint]), the time left on the wave meter's bar, draining, and "Tap to continue", at the side away from
  /// the caster. Nothing under it takes a press, a hover or a tooltip ([_coachClear]).
  void _foeSplashCard(Canvas c) {
    final v = _foeSplash..panel = Rect.zero;
    final cut = v.showing;
    if (cut == null) return;
    final (u, skill, rank) = cut;
    _coachClear(); // coach.dart
    final t = _clock - v.since, fadeIn = math.min(1.0, t / _heraldIn);
    final shown = ((foeSplashTime - t) / _heraldOut).clamp(0.0, 1.0);
    final pop = Curves.easeOutBack.transform(fadeIn);
    final screen = Offset.zero & Size(size.x, size.y), dim = Colors.black.withValues(alpha: 0.45 * fadeIn);
    if (shown < 1) c.saveLayer(null, Paint()..color = Colors.black.withValues(alpha: shown));
    if (u.alive) {
      final at = toScreen(u.pos.x, u.pos.y - 11), r = 24 * _scale; // the Hero cut-in's spotlight (hero_cast.dart)
      c.drawRect(screen, Paint()..shader = ui.Gradient.radial(at, r * 4, [Colors.transparent, Colors.transparent, dim], const [0, 0.25, 1]));
    } else {
      c.drawRect(screen, Paint()..color = dim);
    }

    // The panel's size: as wide as the screen allows, 360·f at most; the text a little bigger than the screen scale,
    // like the Hero splash's.
    final s = _screenScale(Size(size.x, size.y)), f = s * 1.2;
    final k = s >= 0.9 ? 3.0 : 2.0, rk = 2.0, fk = 3.0, pad = (8 * s).roundToDouble(), gap = (6 * s).roundToDouble();
    final w = math.min(360 * f, size.x - 32).roundToDouble();
    final inL = 3 * k + pad, inR = 3 * k + pad, inT = 3 * k + pad, inB = 5 * k + pad, room = w - inL - inR;
    final card = 19 * fk, ribbonH = 18 * rk;
    // The head: the card, and beside it the ribbon over the rank line.
    final headX = card + 4 * rk, headRoom = room - headX;
    var ts = math.max(13.0, (18 * f).roundToDouble());
    while (ts > 11 && _textWidth(skill.title, ts, bold: true) > headRoom - 30 * rk) {
      ts -= 1;
    }
    final title = _fit(skill.title, ts, headRoom - 30 * rk);
    final lineSize = math.max(11.0, (14 * f).roundToDouble()), rankLine = _fit(foeCutLine(u, rank), lineSize, headRoom);
    final headH = math.max(card, ribbonH + 2 * rk + lineSize * 1.3);
    // The body: what it does, its hint, the bar and the footer.
    final textSize = math.max(12.0, (15 * f).roundToDouble()), textH = (textSize * 1.3).roundToDouble();
    final lines = _wrap(monsterSkillText(skill), textSize, room);
    final hint = switch (monsterSkillHint(skill, u.type, rank)) { final h? => _fit(h, lineSize, room), _ => null };
    final hintH = hint == null ? 0.0 : (lineSize * 1.4).roundToDouble();
    const bk = 2.0;
    final barH = 5 * bk, small = math.max(11.0, (12 * f).roundToDouble()), footH = (small * 1.5).roundToDouble();
    final h = (inT + headH + gap + lines.length * textH + hintH + gap + barH + gap / 2 + footH + inB).roundToDouble();

    // Where: mid-height at the side away from the caster.
    final casterX = u.alive ? _unitRect(u).center.dx : size.x / 2;
    final mid = casterX < size.x / 2 ? size.x * 0.72 : size.x * 0.28;
    final x0 = (mid - w / 2).clamp(16.0, math.max(16.0, size.x - 16 - w)).roundToDouble();
    final y0 = ((size.y - h) / 2).clamp(8.0, math.max(8.0, size.y - h - 8)).roundToDouble();
    final panel = v.panel = Rect.fromLTWH(x0, y0, w, h);

    c.save();
    c.translate(panel.center.dx, panel.center.dy);
    c.scale(0.6 + 0.4 * pop);
    c.translate(-panel.center.dx, -panel.center.dy);
    c.drawRect(panel.shift(const Offset(0, 6)).deflate(4), Paint()..color = Colors.black.withValues(alpha: 0.3));
    _nine(c, _tipBody, panel, k, l: 3, t: 3, r: 3, b: 5, sheet: 'ui_tooltip.png');
    final left = panel.left + inL;
    var y = panel.top + inT;
    final fr = Rect.fromLTWH(left, y + ((headH - card) / 2).roundToDouble(), card, card);
    _foePortrait(c, u, rank, fr, fk); // foe_cut_in.dart
    final ribbonW = (30 * rk + _textWidth(title, ts, bold: true)).roundToDouble();
    final colTop = y + ((headH - ribbonH - 2 * rk - lineSize * 1.3) / 2).roundToDouble();
    final ribbon = Rect.fromLTWH(left + headX, colTop, ribbonW, ribbonH);
    _nine(c, Board._ribbonClosed(Board._ribRed), ribbon, rk, l: 1, t: 0, r: 10, b: 0, sheet: 'ui_book_marks.png');
    _uiIcon(c, _icAlert, Rect.fromLTWH(ribbon.left + 3 * rk, ribbon.top + rk, 16 * rk, 16 * rk));
    _text(c, title, Offset(ribbon.left + 21 * rk, ribbon.top + 9 * rk), size: ts, color: _foeInk, bold: true);
    _text(c, rankLine, Offset(ribbon.left, ribbon.bottom + 2 * rk + lineSize * 0.65), size: lineSize, color: _tipInk);
    y += headH + gap;
    for (final l in lines) {
      _text(c, l, Offset(left, y + textH / 2), size: textSize, color: _dark);
      y += textH;
    }
    if (hint != null) {
      _text(c, hint, Offset(left, y + hintH / 2), size: lineSize, color: _tipInk);
      y += hintH;
    }
    y += gap;
    // The time left: the wave meter's empty bar across the panel, its red column filling what is left.
    final bars = _img('ui_bars.png'), bar = Rect.fromLTWH(left, y, room, barH);
    c.drawImageRect(bars, Rect.fromLTWH(_splashBar.left, _splashBar.top, 5, 5), Rect.fromLTWH(bar.left, bar.top, 5 * bk, barH), _px);
    c.drawImageRect(bars, Rect.fromLTWH(_splashBar.left + 5, _splashBar.top, 24, 5), Rect.fromLTRB(bar.left + 5 * bk, bar.top, bar.right - bk, bar.bottom), _px);
    c.drawImageRect(bars, Rect.fromLTWH(_splashBar.right - 1, _splashBar.top, 1, 5), Rect.fromLTRB(bar.right - bk, bar.top, bar.right, bar.bottom), _px);
    final inside = bar.width - 6 * bk, n = (inside / bk * (1 - t / foeSplashTime).clamp(0.0, 1.0)).ceil();
    if (n > 0) c.drawImageRect(bars, _meterRed, Rect.fromLTWH(bar.left + 5 * bk, bar.top + bk, n * bk, 3 * bk), _px);
    y += barH + gap / 2;
    _text(c, guideEn.labels.tapOn, Offset(panel.center.dx, y + footH / 2), size: small, color: _tipInk.withValues(alpha: 0.6), anchor: Anchor.center);
    c.restore();
    if (shown < 1) c.restore();
    v
      ..title = title
      ..titleSize = ts
      ..line = rankLine
      ..lines = lines
      ..hint = hint
      ..textSize = textSize
      ..textRoom = room;
  }
}
