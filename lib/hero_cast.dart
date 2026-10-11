part of 'main.dart';

// A Hero's cast cut-in (issue #51; the owner: "ketika hero melakukan skill di kasikan hilight atau splash
// screen supaya special gitu"). When a Hero casts its own skill ([Game.heroCasts], drained in skills.dart)
// the UI pack's gold studded band slides across the screen for [cutInTime]: the Hero big ([_heroPortrait], the
// splash's), its skill's mark and English title, and its name. Meanwhile the field dims round the Hero, a spotlight.
// It pauses nothing and takes no press. The queue (cut_ins.dart) shows one at a time, at most
// [cutInWaiting] waiting. Off in Settings ("Hero spotlight", [Settings.heroCutIns]).

/// The cut-in's slide in and out, as a share of [cutInTime] each.
const _cutSlide = 0.15;

/// ui_all.png's gold frame with a stud at each corner (the pack's gold row of panels, over the boss's moment's red
/// [_redPlate]), the cut-in's band: sliced l 7, t 8, r 7, b 9, as the red one.
const _goldPlate = Rect.fromLTWH(681, 200, 30, 34);

extension on Board {
  /// How much of the cut-in shows at [p] (0..1 of its time): rising over the first [_cutSlide], falling over
  /// the last.
  double _cutShown(double p) => math.min(p / _cutSlide, (1 - p) / _cutSlide).clamp(0.0, 1.0);

  /// While a cut-in shows, the field dims round its Hero (drawn over the field, under the pops and the
  /// HUD): clear round its body, black at 45% from four times that out.
  void _heroSpotlight(Canvas c) {
    final p = _cutIns.progress(_clock), cast = _cutIns.showing;
    if (p == null || cast == null || !cast.$1.alive) return;
    final u = cast.$1, at = _origin + Offset(u.pos.x - camX, u.pos.y - 11 + backdropH) * _scale, r = 24 * _scale;
    final dim = Colors.black.withValues(alpha: 0.45 * _cutShown(p));
    c.drawRect(Offset.zero & Size(size.x, size.y),
        Paint()..shader = ui.Gradient.radial(at, r * 4, [Colors.transparent, Colors.transparent, dim], const [0, 0.25, 1]));
  }

  /// Where the cut-in band's top stands: 30% down the screen.
  double get _heroBandTop => size.y * 0.3;

  /// The cut-in band's height at screen scale [s] (laid out like the boss's moment band, foe_cut_in.dart): the gold
  /// frame's top and bottom borders ([_goldPlate] at 2x) round the title's and the name's lines.
  double _heroBandH(double s) {
    final (ts, ns, pad) = _heroBandText(s);
    return (8 * 2 + pad + ts * 1.2 + ns * 1.3 + pad + 9 * 2).roundToDouble();
  }

  /// The cut-in band's title size, name size and padding at screen scale [s].
  (double, double, double) _heroBandText(double s) =>
      (math.max(18.0, (30 * s).roundToDouble()), math.max(12.0, (17 * s).roundToDouble()), (6 * s).roundToDouble());

  /// The cut-in ([_cutIns]): the UI pack's gold studded frame ([_goldPlate], the boss's moment band's in the Hero
  /// gold) across the screen 8 px in from its sides, sliding in from the left and out to the right; on it the Hero's
  /// portrait standing on its inside's bottom and rising over it, then the skill's mark and English title in cream
  /// outlined dark, and `"Hero <name>"` in the frame's dark ink. Over the HUD, under the Hero splash and the score
  /// screens.
  void _heroCutIn(Canvas c) {
    final p = _cutIns.progress(_clock), cast = _cutIns.showing;
    if (p == null || cast == null) return;
    final (u, skill) = cast;
    const k = 2.0, lip = 9 * k;
    final s = _screenScale(Size(size.x, size.y)), h = _heroBandH(s);
    final (ts, ns, pad) = _heroBandText(s);
    final top = _heroBandTop.roundToDouble();
    final slideIn = Curves.easeOutCubic.transform((p / _cutSlide).clamp(0.0, 1.0));
    final slideOut = Curves.easeInCubic.transform(((p - 1 + _cutSlide) / _cutSlide).clamp(0.0, 1.0));
    c.save();
    c.translate(((slideIn - 1 + slideOut) * size.x).roundToDouble(), 0);
    final band = Rect.fromLTWH(8, top, size.x - 16, h);
    _nine(c, _goldPlate, band, k, l: 7, t: 8, r: 7, b: 9);
    // The portrait as big as on the dark strip before the frame (1.5× its 84·s / 100·s): 1.5× the taller frame would
    // lie over the Grail's plate on a phone.
    final pic = (150 * s).roundToDouble();
    final box = Rect.fromLTWH(size.x * 0.16, band.bottom - lip - pic, pic, pic);
    _heroPortrait(c, u, box, _clock - _cutIns.since, cast: skill); // hero_splash.dart: its Hero strip once
    final titleH = (ts * 1.2).roundToDouble(), x = box.right + 10 * s, icon = (titleH * 1.1).roundToDouble();
    final mid = band.top + 8 * k + pad + titleH / 2, tx = x + icon + 6 * s;
    _heroMarkIcon(c, skill.mark, Rect.fromLTWH(x, mid - icon / 2, icon, icon)); // skills.dart
    _text(c, _fit(skill.title, ts, band.right - 7 * k - 8 * s - tx), Offset(tx, mid), size: ts, color: _foeInk, outline: _dark);
    _text(c, _fit('Hero ${u.name}', ns, band.right - 7 * k - 8 * s - tx), Offset(tx, mid + titleH / 2 + (ns * 1.3).roundToDouble() / 2),
        size: ns, color: _dark);
    c.restore();
  }
}
