part of 'main.dart';

// A monster champion's skill banner (champion-fx Part 3; the owner, 2026-10-02: "dan ketika champion musuh (< mini
// boss) skill juga ada effectnya dan ada splash screennya", and on its look: "effect buatanmu coba di ganti pakai
// asset yang ada karna jadi nga masuk sama gamenya"). When a high elite, a mini boss or the boss winds up a skill
// ([Game.monsterCasts], drained in skills.dart), a banner slides in for [foeCutTime] on the screen's clock: the
// tooltip frame's tan body ([_tipBody], the Hero splash's and Peti Bos's panel); in it the monster on the book's paper
// card (its own idle sprite in its rank's colours, as on the field), the skill's English title on the book's red
// ribbon behind the pack's "!", and "<rank> <type>" under it ("High Elite Orc"). The boss's moment gets a band
// across the screen instead: the pack's red studded frame with the boss standing big on it. Every piece is a sheet's;
// only the text is drawn. It pauses nothing and takes no press. Which casts get one is [FoeCutGate] (cut_ins.dart):
// once per skill and rank a wave, 4 high elites' at most and 4 s apart, a mini boss's and the boss's always and first
// in line. Off in Settings ("Monster spotlight", [Settings.foeCutIns]).

/// A foe's skill banner: the caster, its skill, and the rank it shows ([foeCutRank]).
typedef FoeCut = (Unit who, MonsterSkill skill, Tier rank);

/// The rank a banner shows for caster [u]: its own, or for a monster a skill brought in (Split's slimes) its
/// maker's, so a mini boss's Split shows as a mini boss's.
Tier foeCutRank(Unit u) => u.raisedBy?.tier ?? u.tier;

/// The line under a banner's title: `<rank> <type>` ("High Elite Orc", "Mini Boss Slime").
String foeCutLine(Unit u, Tier rank) => '${tierNames[rank]} ${monsterTypeNames[u.type] ?? u.type}';

/// ui_all.png's red frame with a stud at each corner (the pack's red row of panels), the moment's band: sliced l 7,
/// t 8, r 7, b 9, so the studs and the darker bottom lip keep their pixels.
const _redPlate = Rect.fromLTWH(681, 248, 30, 34);

/// ui_icons.png's yellow "!", before the title.
const _icAlert = Offset(192, 32);

/// The cream of text on the red ribbon and the red band (the phone HUD's red ribbons' ink).
const _foeInk = Color(0xFFFFF1D6);

/// The banner's slide in and out, as a share of [foeCutTime] each.
const _foeSlide = 0.15;

/// The banner between frames: which casts get one ([gate]); where the showing one rests this frame, its ribbon, and
/// its title (and its size) and line as drawn, cut to fit (for tests; [at] Rect.zero: none shows); and on a desk the
/// side it came in on, picked once per banner ([sideFor], its start on the screen's clock).
class _FoeCutLook {
  final gate = FoeCutGate();
  Rect at = Rect.zero, ribbon = Rect.zero;
  String title = '', line = '';
  double titleSize = 0;
  double sideFor = double.nan;
  bool left = false;
  Rect button = Rect.zero; // Settings' "Monster spotlight" this frame
}

extension on Board {
  /// [_drainCasts]: monster [u] winds up skill [s] (or Split goes off): its banner, if the setting is on, its rank
  /// ([foeCutRank]) is a high elite's or above, and the gate lets it in.
  void _foeCast(Game g, Unit u, MonsterSkill s) {
    final rank = foeCutRank(u);
    if (!_settings.foeCutIns || rank.index < Tier.highElite.index) return;
    // A skill's first sighting ever gets its splash instead (foe_splash.dart), counted as this wave's banner of that
    // skill and rank (a later cast of it shows none), but not against the high elites' cap.
    if (_foeSplashOpen(g, u, s, rank)) {
      _foeLook.gate.admit((s, rank), big: true, wave: g.wave, now: _clock);
      return;
    }
    if (_foeLook.gate.admit((s, rank), big: rank.index >= Tier.miniBoss.index, wave: g.wave, now: _clock)) {
      _foeCuts.add((u, s, rank), _clock);
    }
  }

  /// Where the banners rest: 6 under the Hero cut-in's band (hero_cast.dart, [_heroBandTop], [_heroBandH]), so both show
  /// at once.
  double _foeTop(double s) => (_heroBandTop + _heroBandH(s) + 6 * s).roundToDouble();

  /// The banner showing ([_foeCuts]), over the HUD, under the Hero splash: it slides in over the first [_foeSlide] of
  /// its time and back out over the last (cubic eases); the moment's is the band ([_foeBand]).
  void _foeCutIn(Canvas c) {
    _foeLook.at = _foeLook.ribbon = Rect.zero;
    final p = _foeCuts.progress(_clock), cut = _foeCuts.showing;
    if (p == null || cut == null) return;
    final (u, skill, rank) = cut;
    final s = _screenScale(Size(size.x, size.y));
    final slideIn = Curves.easeOutCubic.transform((p / _foeSlide).clamp(0.0, 1.0));
    final slideOut = Curves.easeInCubic.transform(((p - 1 + _foeSlide) / _foeSlide).clamp(0.0, 1.0));
    if (skill.rank == MonsterRank.moment) return _foeBand(c, u, skill, rank, s, slideIn, slideOut);

    // The plate: the tooltip body at 2x; in it the portrait's card (3x, 2x on a small screen) beside the ribbon over the
    // rank line; as wide as they need, 360·s at most and 16 off the screen's edges.
    const k = 2.0, ribbonH = 18 * k, gap = 2 * k;
    final fk = s >= 0.9 ? 3.0 : 2.0, frame = 19 * fk, m = (4 * s).roundToDouble();
    final maxW = math.min(size.x - 32, 360 * s), fixed = 3 * k + m + frame + 4 * k + m + 3 * k + 2 * k;
    // The ribbon: its closed end, the "!" and the title, then its notched end; the title shrunk (to 11) and cut to fit.
    var ts = math.max(13.0, (18 * s).roundToDouble());
    while (ts > 11 && _textWidth(skill.title, ts, bold: true) > maxW - fixed - 30 * k) {
      ts -= 1;
    }
    final title = _fit(skill.title, ts, maxW - fixed - 30 * k), ribbonW = (30 * k + _textWidth(title, ts, bold: true)).roundToDouble();
    final lineSize = math.max(11.0, (14 * s).roundToDouble()), lineH = (lineSize * 1.3).roundToDouble();
    final line = _fit(foeCutLine(u, rank), lineSize, maxW - fixed);
    final w = (fixed + math.max(ribbonW, _textWidth(line, lineSize))).roundToDouble();
    final innerH = math.max(frame, ribbonH + gap + lineH), h = (3 * k + m + innerH + m + 5 * k).roundToDouble();
    final top = _foeTop(s);
    // The banner stands at the right, or at the left when its caster is under it there (picked as it comes in).
    if (_foeLook.sideFor != _foeCuts.since) {
      _foeLook
        ..sideFor = _foeCuts.since
        ..left = u.alive && Rect.fromLTWH(size.x - 16 - w, top, w, h).inflate(16).overlaps(_unitRect(u));
    }
    final x0 = _foeLook.left ? 16.0 : size.x - 16 - w;
    final plate = _foeLook.at = Rect.fromLTWH(x0, top, w, h);
    final off = _foeLook.left ? -(x0 + w) : size.x - x0; // how far off its own edge it slides
    c.save();
    c.translate((off * (1 - slideIn + slideOut)).roundToDouble(), 0);
    _nine(c, _tipBody, plate, k, l: 3, t: 3, r: 3, b: 5, sheet: 'ui_tooltip.png');
    final inside = plate.top + 3 * k + m;
    final fr = Rect.fromLTWH(plate.left + 3 * k + m, inside + ((innerH - frame) / 2).roundToDouble(), frame, frame);
    _foePortrait(c, u, rank, fr, fk);
    final x = fr.right + 4 * k, colTop = inside + ((innerH - ribbonH - gap - lineH) / 2).roundToDouble();
    final ribbon = _foeLook.ribbon = Rect.fromLTWH(x, colTop, ribbonW, ribbonH);
    _nine(c, Board._ribbonClosed(Board._ribRed), ribbon, k, l: 1, t: 0, r: 10, b: 0, sheet: 'ui_book_marks.png');
    _uiIcon(c, _icAlert, Rect.fromLTWH(ribbon.left + 3 * k, ribbon.top + k, 16 * k, 16 * k));
    _text(c, title, Offset(ribbon.left + 21 * k, ribbon.top + 9 * k), size: ts, color: _foeInk, bold: true);
    _text(c, line, Offset(x, ribbon.bottom + gap + lineH / 2), size: lineSize, color: _tipInk);
    _foeLook
      ..title = title
      ..titleSize = ts
      ..line = line;
    c.restore();
  }

  /// Caster [u] in [fr] on the book's paper card (ui_all.png's page frame, [Board._framePlain], at [fk]), as a troop
  /// stands on its Pasukan row: its idle sprite inside the rim, its visible pixels as tall as the inside (a wide one a
  /// little cropped at the sides), feet on the bottom, facing the troops, in rank [rank]'s colours and outline
  /// (tier_look.dart). Paper, not the boss bars' dark portrait frame: a mini boss's purple or a dark type sank into
  /// that frame's navy, which the boss bars lift with a slate drawn in code.
  void _foePortrait(Canvas c, Unit u, Tier rank, Rect fr, double fk) {
    _nine(c, Board._framePlain, fr, fk);
    final b = _idleBounds[u.type] ?? _idleBounds[boss]; // the healing necromancer is the boss recoloured
    if (b == null) return;
    final inside = fr.deflate(2 * fk);
    final k = math.min(inside.height / b.height, 1.4 * inside.width / b.width);
    c.save();
    c.clipRect(inside);
    c.translate(inside.center.dx, inside.bottom - fk);
    c.scale(k);
    _frame(c, 'tiny_${u.type}_idle.png', (_clock * _fps).floor(), Offset.zero,
        anchor: Offset(b.center.dx, b.bottom), flip: true, paint: _tierPaints[rank], line: _tierLines[rank]);
    c.restore();
  }

  /// The boss's moment ([MonsterRank.moment]): the red studded frame across the screen 8 px in from its sides, as
  /// tall as its two lines need, sliding in from the right and out to the left; the boss standing on its inside's
  /// bottom at the right, 1.3x the band tall, facing left, its head clear of the Hero cut-in's band; the "!" and the
  /// title in cream, outlined, and the rank line under them.
  void _foeBand(Canvas c, Unit u, MonsterSkill skill, Tier rank, double s, double slideIn, double slideOut) {
    const k = 2.0, lip = 9 * k; // the frame's bottom border, studs and lip
    final pad = (6 * s).roundToDouble(), lineSize = math.max(12.0, (17 * s).roundToDouble());
    var ts = math.max(18.0, (30 * s).roundToDouble());
    final titleH = (ts * 1.2).roundToDouble(), lineH = (lineSize * 1.3).roundToDouble();
    final h = 8 * k + pad + titleH + lineH + pad + lip, pic = (h * 1.3).roundToDouble();
    final band = _foeLook.at = Rect.fromLTWH(8, _foeTop(s) + lip + pic - h, size.x - 16, h);
    c.save();
    c.translate(((1 - slideIn - slideOut) * size.x).roundToDouble(), 0);
    _nine(c, _redPlate, band, k, l: 7, t: 8, r: 7, b: 9);
    final box = Rect.fromLTWH(band.right - size.x * 0.12 - pic, band.bottom - lip - pic, pic, pic);
    if (_idleBounds[u.type] ?? _idleBounds[boss] case final b?) {
      final sk = math.min(box.width * 0.8 / b.width, box.height / b.height);
      c.save();
      c.translate(box.center.dx, box.bottom);
      c.scale(sk);
      _frame(c, 'tiny_${u.type}_idle.png', (_clock * _fps).floor(), Offset.zero,
          anchor: Offset(b.center.dx, b.bottom), flip: true, paint: _tierPaints[rank], line: _tierLines[rank]);
      c.restore();
    }
    final x = band.left + 7 * k + 10 * s, icon = (titleH * 1.1).roundToDouble(), mid = band.top + 8 * k + pad + titleH / 2;
    final room = box.left - 8 * s - (x + icon + 6 * s);
    while (ts > 11 && _textWidth(skill.title, ts) > room) {
      ts -= 1;
    }
    final title = _fit(skill.title, ts, room), tx = x + icon + 6 * s;
    _uiIcon(c, _icAlert, Rect.fromLTWH(x, mid - icon / 2, icon, icon));
    _text(c, title, Offset(tx, mid), size: ts, color: _foeInk, outline: _dark);
    final line = _fit(foeCutLine(u, rank), lineSize, box.left - 8 * s - tx);
    _text(c, line, Offset(tx, mid + titleH / 2 + lineH / 2), size: lineSize, color: _foeInk);
    _foeLook
      ..title = title
      ..titleSize = ts
      ..line = line
      ..ribbon = Rect.fromLTWH(tx, mid - ts / 2, _textWidth(title, ts), ts);
    c.restore();
  }
}
