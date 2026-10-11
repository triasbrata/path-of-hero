part of 'main.dart';

// A new Hero's splash screen (issue #47; the owner: "ketika hero bangkit perlu di bautkan splash screen
// beserta skill unique yang dia punya"). A Hero is crowned when every 10th wave is won ([Game.heroMade]);
// once the win's cheering is over the screen dims and a panel pops up over everything but the score
// screens: the UI pack's ribbon with "<name> (<type>) is now a Hero!", the Hero big (its idle sprite
// with its halo and crown, a gold burst behind it), its 2 rolled attributes x3 and its own skill ([Unit.
// heroSkill], #48): its mark, its English title in gold and what it does. A tap, Esc / P or [_heraldFor]
// seconds close it. A fallen Hero called back on its Army detail (Hero Gugur, #92 part 3, [Game.heroRecalled]) gets the
// same splash under "<name> is back!". The pieces ([_ribbonTitle], [_heroPortrait], [_heroLines]) are for a Hero's
// skill cut-in too (#51).

/// How long a splash stays at most (s, on the screen's clock), how long it takes to pop in, and to fade
/// out at the end of its time.
const _heraldFor = 4.0, _heraldIn = 0.35, _heraldOut = 0.3;

/// ui_ribbons.png (UI_Ribbons.png): the flat small ribbon, 64×20 at (8, 1). Its ends are [_ribbonEnd] px
/// (the tails folded under the band, and the band's first 8 px); the 16 px between them are plain band,
/// stretched to the title. The band's inside is x 16..47, y 3..14.
const _ribbon = Rect.fromLTWH(8, 1, 64, 20), _ribbonEnd = 24.0;

/// The gold of a new Hero: its portrait's light, a dropped relic's glint; the skill's name is in the darker gold ink
/// of the book's last awakening level, to read on the tan.
const _heroGold = Color(0xFFFFD54F);

/// A new Hero's ring on the field ([Board._heroRing]): fx_hit_knight_templar.png's frames from the first, this many
/// (its solid gold rings widening; the ones before are filled and would hide the Hero, the last are fading dots that
/// the dim swallows), at this many frames a second.
const _heroRingFrames = (3, 3), _heroRingFps = 6.0;

/// A Hero's portrait's burst ([Board._heroPortrait]): fx_hit_knight.png's gold sun ring played once over this long (s),
/// its last frame about this many times the portrait's width.
const _heroBurstTime = 0.6, _heroBurstW = 1.2;

/// The splash between frames: the Hero shown, since when, whether the last press closed it, the
/// Heroes waiting for theirs, and which of them were called back (Hero Gugur, recall_page.dart), not crowned.
class _Herald {
  Unit? who;
  double since = 0;
  bool tapped = false; // the last press closed it: its tap up and drag stay there
  final next = <Unit>[];
  final back = <Unit>{};
}

/// A line of the splash's text ([Board._heroLines]): how tall and wide it is, and how it draws itself from
/// its left middle.
typedef _SplashLine = (double h, double w, void Function(Canvas c, Offset at) draw);

/// [text] in lines no wider than [maxW] at [size], broken at spaces (a longer word keeps a line of its own).
List<String> _wrap(String text, double size, double maxW) {
  final lines = <String>[];
  var line = '';
  for (final word in text.split(' ')) {
    final longer = line.isEmpty ? word : '$line $word';
    if (line.isNotEmpty && _textWidth(longer, size) > maxW) {
      lines.add(line);
      line = word;
    } else {
      line = longer;
    }
  }
  return [...lines, if (line.isNotEmpty) line];
}

extension on Board {
  /// Takes the troops just made Heroes ([Game.heroMade]) and the Heroes just called back ([Game.heroRecalled]) for
  /// the splash, one at a time, from when the win's cheering is over ([victoryTime]: the "VICTORY!" popup first; at
  /// once if the next wave has started). It
  /// closes after [_heraldFor], or at once if its troop has left the game (a new game, or it fell and is gone).
  /// From the win until the last one closes, the auto start's countdown waits ([holdAutoStart]).
  void _heroNews(Game g) {
    final h = _herald;
    bool gone(Unit u) => !g.units.contains(u);
    h.back.addAll(g.heroRecalled);
    h.next
      ..addAll(g.heroMade)
      ..addAll(g.heroRecalled)
      ..removeWhere(gone);
    h.back.removeWhere(gone);
    g.heroMade.clear();
    g.heroRecalled.clear();
    if (h.who case final u? when gone(u) || _clock - h.since >= _heraldFor) _heraldClose();
    if (h.who == null && h.next.isNotEmpty && !_foeSplashBusy && (g.t - g.victoryAt >= victoryTime || g.waveActive)) {
      h
        ..who = h.next.removeAt(0)
        ..since = _clock;
    }
    holdAutoStart = h.who != null || h.next.isNotEmpty;
  }

  void _heraldClose() {
    _herald.back.remove(_herald.who);
    _herald.who = null;
    holdAutoStart = _herald.next.isNotEmpty;
  }

  /// A press: while the splash shows it closes it and is used up. True when it did.
  bool _heraldDown() {
    final on = _herald.who != null;
    if (on) _heraldClose();
    return _herald.tapped = on;
  }

  /// While the splash shows, a gold ring round its Hero on the field (under the dimming): fx_hit_knight_templar.png's
  /// gold ring widening out of it (its ring frames, [_heroRingFrames]) again and again, at the hit bursts' size (in
  /// field coordinates, drawn over the troops).
  void _heroRing(Canvas c) {
    final u = _herald.who;
    if (u == null || !u.alive) return;
    final (first, n) = _heroRingFrames;
    final f = first + ((_clock - _herald.since) * _heroRingFps).floor() % n;
    _sheetFrame(c, 'fx_hit_knight_templar.png', f, Offset(u.pos.x, u.pos.y), _burstSize, _px); // hero_skill_fx.dart
  }

  /// The splash ([_Herald]) over the dimmed screen: the panel in the tooltip frame's body, the ribbon with
  /// the title across its top, the Hero's portrait ([_heroPortrait]) and its lines ([_heroLines]) beside
  /// it, and "Tap to continue" ([GuideText.labels]) at the bottom. It pops in over [_heraldIn] and fades
  /// out over the last [_heraldOut]. Like the score screens, the HUD under it takes no taps, drags or tooltips.
  void _heroSplash(Canvas c, Game g) {
    final u = _herald.who;
    if (u == null) return;
    _hits.clear();
    _cards.clear();
    _slots.clear();
    _relicSlots.clear();
    _matSlots.clear();
    _tip.rows.clear();
    _tip.hints.clear();
    _troops
      ..button = Rect.zero
      ..list = Rect.zero;
    final t = _clock - _herald.since, shown = ((_heraldFor - t) / _heraldOut).clamp(0.0, 1.0);
    final pop = Curves.easeOutBack.transform((t / _heraldIn).clamp(0.0, 1.0));
    c.saveLayer(null, Paint()..color = Colors.black.withValues(alpha: shown));
    c.drawRect(Offset.zero & Size(size.x, size.y), Paint()..color = Colors.black.withValues(alpha: 0.65 * math.min(1, t / _heraldIn)));

    // The panel: the portrait and the lines side by side, as wide as they need. The text a little bigger than the
    // screen scale.
    final s = _screenScale(Size(size.x, size.y)), f = s * 1.2;
    final k = s >= 0.9 ? 3.0 : 2.0, rk = k + 1, pad = 16 * s + 3 * k, gap = 16 * s;
    final lineW = (360 * s).floorToDouble(), lines = _heroLines(u, f, lineW);
    final linesH = lines.fold(0.0, (h, l) => h + l.$1), linesW = lines.fold(0.0, (w, l) => math.max(w, l.$2));
    final portrait = 220 * s, hintH = 24 * f, ribbonH = 20 * rk;
    final inner = Size(portrait + gap + linesW, math.max(portrait, linesH));
    final panel = Rect.fromCenter(
        center: Offset(size.x / 2, size.y / 2 + ribbonH / 4),
        width: (inner.width + 2 * pad).roundToDouble(),
        height: (ribbonH / 2 + inner.height + hintH + 2 * pad).roundToDouble());
    c.save();
    c.translate(panel.center.dx, panel.center.dy);
    c.scale(0.6 + 0.4 * pop);
    c.translate(-panel.center.dx, -panel.center.dy);
    c.drawRect(panel.shift(const Offset(0, 6)).deflate(4), Paint()..color = Colors.black.withValues(alpha: 0.3));
    _nine(c, _tipBody, panel, k, l: 3, t: 3, r: 3, b: 5, sheet: 'ui_tooltip.png');
    final top = panel.top + pad + ribbonH / 2;
    final pic = Rect.fromLTWH(panel.left + pad, top + (inner.height - portrait) / 2, portrait, portrait);
    _heroPortrait(c, u, pic, t);
    var y = top + (inner.height - linesH) / 2;
    for (final (h, _, draw) in lines) {
      draw(c, Offset(pic.right + gap, y + h / 2));
      y += h;
    }
    _text(c, guideEn.labels.tapOn, Offset(panel.center.dx, panel.bottom - pad - hintH / 2 + 4 * s),
        size: 14 * f, color: _tipInk.withValues(alpha: 0.6), anchor: Anchor.center);
    // The ribbon across the panel's top edge, half over it.
    _ribbonTitle(c, _heraldTitle(u), Offset(panel.center.dx, panel.top), rk, size.x - 16);
    c.restore();
    c.restore();
  }

  /// The splash's title for Hero [u]: `<name> (<type>) is now a Hero!`, or for one called back `<name> is back!`.
  String _heraldTitle(Unit u) => _herald.back.contains(u) ? '${u.name} is back!' : '${u.name} (${troopTypeNames[u.type] ?? u.type}) is now a Hero!';

  /// The UI pack's ribbon centred on [mid] at scale [k] with [title] on its band (12 of its 20 rows), its
  /// plain middle stretched to the title; shrunk to fit [maxW]. Returns where it was drawn.
  Rect _ribbonTitle(Canvas c, String title, Offset mid, double k, double maxW) {
    var ts = 6.5 * k, textW = _textWidth(title, ts, bold: true);
    final fit = maxW - 38 * k; // the room left: the ends and 3 px of band either side
    if (textW > fit) (ts, textW) = (ts * fit / textW, fit);
    final w = math.max(64 * k, textW + 38 * k).roundToDouble();
    final ribbon = Rect.fromCenter(center: mid, width: w, height: 20 * k);
    _nine(c, _ribbon, ribbon, k, l: _ribbonEnd, t: 0, r: _ribbonEnd, b: 0, sheet: 'ui_ribbons.png');
    _text(c, title, Offset(ribbon.center.dx, ribbon.top + 9 * k), size: ts, color: _dark, anchor: Anchor.center, bold: true);
    return ribbon;
  }

  /// Hero [u] big in [box], [t] s after it came: fx_hit_knight.png's gold sun ring bursting behind it once (over
  /// [_heroBurstTime], at a whole number of screen px a sprite px), light turning slowly, its halo, its idle sprite
  /// (its visible pixels, [_idleBounds], filling the box under the crown; outlined in its awakening colour; in a cast's
  /// cut-in, [cast], its Hero skill strip once first: skill_strips.dart) and the
  /// crown over its head. The light's rays and glow are drawn in code: no sheet in the packs has rays or a soft glow.
  void _heroPortrait(Canvas c, Unit u, Rect box, double t, {HeroSkill? cast}) {
    final mid = box.center, r = box.width / 2;
    if (t < _heroBurstTime) {
      const name = 'fx_hit_knight.png';
      final n = _frames(name), fs = _img(name).height.toDouble(), k = math.max(1.0, (box.width * _heroBurstW / fs).roundToDouble());
      _sheetFrame(c, name, math.min(n - 1, (t / _heroBurstTime * n).floor()), mid, fs * k, _px); // hero_skill_fx.dart
    }
    for (var i = 0; i < 10; i++) {
      final a = _clock * 0.4 + i * math.pi / 5;
      c.drawPath(
          Path()
            ..moveTo(mid.dx, mid.dy)
            ..lineTo(mid.dx + math.cos(a - 0.12) * r, mid.dy + math.sin(a - 0.12) * r)
            ..lineTo(mid.dx + math.cos(a + 0.12) * r, mid.dy + math.sin(a + 0.12) * r)
            ..close(),
          Paint()..color = _heroGold.withValues(alpha: 0.18));
    }
    c.drawCircle(mid, r * 0.7, Paint()
      ..shader = ui.Gradient.radial(mid, r * 0.7, const [Color(0xDDFFFFFF), Color(0x66FFF3C0), Color(0x00FFFFFF)], const [0, 0.6, 1]));
    final crown = box.width * 0.2, b = _idleBounds[u.type]!;
    final k = math.min(box.width * 0.8 / b.width, (box.height * 0.9 - crown) / b.height), feet = box.bottom - box.height * 0.05;
    c.save();
    c.translate(mid.dx, feet);
    c.scale(k);
    // A cast's cut-in ([cast]) plays its Hero strip once from its entry frame, then the idle (decisions-log 299).
    final strip = cast == null ? null : heroSkillStrip(cast), name = 'tiny_${u.type}_${strip?.anim}.png';
    final f = strip == null ? -1 : strip.entry + (t * _fps).floor();
    final playing = strip != null && f < _frames(name);
    _frame(c, playing ? name : 'book_${u.type}_idle', playing ? f : (_clock * _fps).floor(), Offset.zero, anchor: Offset(b.center.dx, b.bottom),
        line: _awakeLine(state.awakenLevel(u.type)));
    c.restore();
    _uiIcon(c, _icCrown, Rect.fromLTWH(mid.dx - crown / 2, feet - b.height * k - crown - 2, crown, crown));
  }

  /// Hero [u]'s lines for the splash at [s] times the tooltips' size, no wider than [maxW]: its 2 rolled
  /// attributes x3 ([_heroStats]); then its own skill ([Unit.heroSkill], when its type has one built): the
  /// mark and English title in the nameplate's dark gold, and what it does.
  List<_SplashLine> _heroLines(Unit u, double s, double maxW) {
    final k = 1.6 * s, skill = u.heroSkill;
    return [
      (34 * s, _heroStatsWidth(u, k), (c, at) => _heroStats(c, u, at, k)),
      if (skill != null) ...[
        (8 * s, 0, (c, at) {}),
        () {
          final icon = 22 * s, size = 20 * s, w = icon + 6 * s + _textWidth(skill.title, size);
          return (28 * s, w, (Canvas c, Offset at) {
            _heroMarkIcon(c, skill.mark, Rect.fromLTWH(at.dx, at.dy - icon / 2, icon, icon)); // skills.dart
            _text(c, skill.title, Offset(at.dx + icon + 6 * s, at.dy), size: size, color: _heroSkillInk);
          });
        }(),
        for (final line in _wrap(skill.desc, 15 * s, maxW))
          (20 * s, _textWidth(line, 15 * s), (Canvas c, Offset at) => _text(c, line, at, size: 15 * s, color: _tipInk)),
      ],
    ];
  }
}
