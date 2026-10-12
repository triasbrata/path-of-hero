part of 'main.dart';

// The Towns on the HUD (decisions-log 216; lib/town.dart; the scene is
// town_scene.dart's, decisions-log 224): a due Town is gone into once nothing of the win is left on screen (the
// "VICTORY!" cheer, the Hero splash, a Boss Chest: taken or skipped first), the book opening on its Smithy; the Start/Pause
// toggle's Start says "Leave town" there ([Words.leaveTown], start_button.dart) and leaves it, and Auto leaves after
// [TownSchedule.autoLeave] s unless a press in the Town stopped it, the wave starting right after the fade back (one
// wait, the Auto hold of the field still applying). From the mark until the Town opens, the wave meter shows the chip "Town after wave
// 12" under it ([Board._townChip]), with the Town's hammer (town_mark.png, Kenmi's Tools 351) and its tooltip; in the
// Town the meter itself says it's safe ([Board._inTownMeter]: a beer mug, town_mug.png, Kenmi's Food 3, and "In town",
// the Town's name since decisions-log 326: "In Millbrook"). As a Town comes up its name shows on a ribbon under the
// HUD's band for a moment ([Board._townArrival]).

/// town_mark.png: Kenmi's 16-px hammer, doubled into its 32x32 file (tool/import_fx.py's LOOT); town_mug.png, the
/// wave meter's beer mug in a Town, likewise.
const _townMarkSrc = Rect.fromLTWH(0, 0, 32, 32);

/// "In town" on the wave meter: the battle log's green for a won wave, a safe time.
const _townSafeInk = Color(0xFF9BE37A), _townNextInk = Color(0xFFFFF1D6);

/// The Town's name as it comes up ([Board._townArrival]): its seconds on screen from the fade's middle, the last
/// [_townArrivalOut] of them fading out.
const _townArrivalFor = 3.0, _townArrivalOut = 0.5;

extension _TownLook on Board {
  /// The Town's hammer over [to].
  void _townMark(Canvas c, Rect to) => c.drawImageRect(_img('town_mark.png'), _townMarkSrc, to, _px);

  /// The wave meter in a Town (the owner, 2026-10-04: "ketika di town wave metternya di ganti contentnya jadi semacam
  /// 'in town' … intinya mau kasi tau ke user kalau ini lagi mode aman"): in the meter's own panel, [inside] it from
  /// the icon's left to the caret's, the beer mug where the swords are, "In town" in green where the wave's number is,
  /// and the coming wave [next] at the right, "next wave 7" (only "7" if that doesn't fit). No bar, count or tide.
  void _inTownMeter(Canvas c, Rect inside, double pad, double icon, double ts, int next) {
    final y = inside.center.dy, x = inside.left + icon + pad;
    c.drawImageRect(_img('town_mug.png'), _townMarkSrc, Rect.fromLTWH(inside.left, inside.top + pad, icon, icon), _px);
    // The Town's name (decisions-log 326): "In Millbrook"; "In town" where it doesn't fit.
    final named = '${Words.inPlace} ${state.sceneIdentity.name}';
    final safe = _textWidth(named, ts) <= inside.right - x - pad ? named : Words.inTown;
    _text(c, safe, Offset(x, y), size: ts, color: _townSafeInk);
    final room = inside.right - x - _textWidth(safe, ts) - 2 * pad;
    final label = ['${Words.nextWave} $next', '$next'].firstWhere((l) => _textWidth(l, ts) <= room, orElse: () => '');
    _text(c, label, Offset(inside.right, y), size: ts, color: _townNextInk, anchor: Anchor.centerRight);
    _townMeterText = [safe, if (label.isNotEmpty) label].join(' · ');
  }

  /// The Town's name as it comes up (decisions-log 326): ui_ribbons' flat ribbon (the signs' [_ribbonTitle]) at 1.5
  /// times the signs' scale [sk], under the HUD's band over the middle of the scene's room (left of the book when it is
  /// open), the name on it ("Millbrook") and under it "Town 1 · Farming village" in cream with a dark outline; for
  /// [_townArrivalFor] s from the fade's middle, fading out over its last [_townArrivalOut]. Never for a game loaded in
  /// a Town (no fade), nor as the Town is left.
  void _townArrival(Canvas c, Game g, double sk) {
    final t = _clock - _town.fadeAt - _townFade;
    _townArrivalAt = Rect.zero;
    if (!g.inTown || !_town.fadeAt.isFinite || t < 0 || t >= _townArrivalFor) return;
    final a = math.min(1.0, (_townArrivalFor - t) / _townArrivalOut), rk = (1.5 * sk).roundToDouble();
    final room = _town.book ? _bookFit().rest.left : size.x, who = g.sceneIdentity;
    if (a < 1) c.saveLayer(null, Paint()..color = Color.fromRGBO(0, 0, 0, a));
    final ribbon = _townArrivalAt =
        _ribbonTitle(c, who.name, Offset((room / 2).roundToDouble(), _meterBottom + 8 + 10 * rk), rk, room - 16);
    _text(c, '${Words.town} ${g.townCount} · ${who.line}', Offset(ribbon.center.dx, ribbon.bottom + 4 * rk),
        size: math.max(11.0, 5 * rk), color: _townNextInk, anchor: Anchor.center, outline: const Color(0xFF3C1E0A));
    if (a < 1) c.restore();
  }

  /// The chip's words: "Town after wave 12".
  String _townChipLabel(Game g) => '${Words.townAfter} ${(g.townAt ?? g.wave + 1) - 1}';

  /// The wave meter's Town chip ([Towns.townMarked]: from the mark until the Town opens): ui_bars.png's dark capsule (the
  /// Bag's counts', [_capsuleSrc]) with the hammer (16 px: its art at one screen px a pixel; 32 from the meter's k 4) and
  /// cream words, right-aligned under the wave meter 6 px down, and under what hangs there too: the open map, the
  /// Shadows' chips (the row's last) and the "Chest!" chip in its columns. While the book shows it stays there, in the sky over the book's top right, under the open map, which
  /// stays under the meter (decisions-log 220; the Shadows' chips go to the left then, [_asideLeft]). Sets
  /// [_townChipAt]; none at game over, in a Town or with no Town marked.
  void _townChip(Canvas c, Game g) {
    _townChipAt = Rect.zero;
    if (!g.townMarked || g.over || _meterAt.isEmpty) return;
    final k = _meterK, fs = math.max(11.0, 5 * k), icon = 16.0 * math.max(1.0, (k / 2).floorToDouble());
    final label = _townChipLabel(g), ck = capsuleK(icon + 4), pad = capsulePad(fs, ck), gap = capsuleGap(fs);
    final w = (2 * pad + icon + gap + _textWidth(label, fs)).ceilToDouble(), h = icon + 2 * (ck + 1);
    final left = (_meterAt.right - w).roundToDouble();
    final at = _townChipAt = Rect.fromLTWH(left, _underMeter(left, w), w, h);
    _nine(c, _capsuleSrc, at, ck, l: 1, t: 1, r: 1, b: 1, sheet: 'ui_bars.png', seam: 0); // its corners stay cut
    _townMark(c, Rect.fromLTWH(at.left + pad, at.top + ck + 1, icon, icon));
    _text(c, label, Offset(at.left + pad + icon + gap, at.center.dy), size: fs, color: const Color(0xFFFFF1D6));
  }

  /// Where a chip [w] wide from [left] goes under the wave meter (the Town chip, the Tavern's boost chips): 6 px under
  /// it, and under what hangs there too: the open map, the Shadows'
  /// chips (unless they are at the left, [_asideLeft]) and the "Chest!" chip when it is in the same columns (under the
  /// Start/Pause toggle). On a whole pixel.
  double _underMeter(double left, double w) {
    final chest = _chest.chip;
    final underChest = chest.right > left && chest.left < left + w;
    return ([
              _meterAt.bottom,
              _map.at.bottom,
              if (!_asideLeft) _omenRow.at.bottom,
              if (underChest) chest.bottom,
            ].reduce(math.max) +
            6)
        .roundToDouble();
  }

  /// The Towns' turn in the Board's update: a due Town is gone into once nothing of the win is left on screen (the
  /// cheer's [victoryTime], the Hero splash, the chest's popup or a chest due, a monster skill's splash, a guide card),
  /// never under the welcome screen; the game is saved there (a reload reopens it) and the book opens on the Smithy. With
  /// Auto on, its countdown runs [TownSchedule.autoLeave] s in the Town ("Leave town 5" … "1"), holding as the start's
  /// does while paused, behind a card or splash or a chest due; a press in the Town stops it for the visit
  /// (town_scene.dart's [_townPress]); at 0 it leaves and the start's countdown is left at 0, so the wave starts once the
  /// fade back is over unless the field's Auto hold waits ([Game.autoHeld]). True while in a Town (the start's countdown
  /// is then this one's).
  bool _townTick(Game g, double dt) {
    final calm = !holdAutoStart && !_chestHolds(g) && !_foeSplashBusy && !_coach.showing && g.t - g.victoryAt >= victoryTime;
    if (welcome == null && g.townDue && !g.inTown && calm && g.enterTown(auto: autoStart.on)) {
      saveGame(g);
      _open(_Page.smithy); // the book opens on the Smithy (town_scene.dart)
      _town.book = true;
      if (autoStart.on) autoStart.left = g.townRules.schedule.autoLeave;
    }
    if (!g.inTown) return false;
    if (autoStart.tick(math.min(dt, 0.1), held: g.paused || !calm)) {
      _leaveTown(g, auto: true);
      autoStart.left = 0; // the start's countdown, done: the wave starts now, or once the Auto hold lets it
    }
    return true;
  }

  /// Leaves the Town ([Towns.leaveTown]; [auto]: Auto left it) and saves, so a reload doesn't reopen it. The start
  /// button's press in a Town.
  void _leaveTown(Game g, {bool auto = false}) {
    if (g.leaveTown(auto: auto)) saveGame(g);
  }

  // The Start/Pause toggle's hooks (start_button.dart reads them): in a Town its Start shows,
  // says "Leave town", counts Auto's [TownSchedule.autoLeave] down, and a press is [_leaveTown].

  /// The toggle shows Start: a wave can start, or the player is in a Town.
  bool _startShows(Game g) => g.canStartWave || g.inTown;

  /// Its word: "Leave town" in a Town, else "Start".
  String _startWord(Game g) => g.inTown ? Words.leaveTown : Words.start;

  /// The most seconds Auto's countdown shows on it (its width keeps room for them).
  int _startMost(Game g) => (g.inTown ? g.townRules.schedule.autoLeave : autoStartDelay).ceil();
}

/// How long a dropped material hops from the kill onto its pile on the ground (decisions-log 221, 262).
const _matPopTime = 0.6;

/// The materials lying on the field (decisions-log 262): a drop within [_matPileReach] field units of a pile of its kind
/// joins it, and past [_matPileMost] piles the oldest that has a kind's neighbour joins its nearest. At a won wave the
/// piles take off for the Bag nearest it first, [_matFlyWait] s after the win and [_matFlyGap] s apart (closer when there
/// are many: the last at most [_matFlyGaps] s after the first), each flying [_matFlyTime] s; the Bag's icon stays
/// [_matBagLinger] s after the last lands.
const _matPileReach = 24.0, _matPileMost = 40;
const _matFlyWait = 0.2, _matFlyGap = 0.03, _matFlyGaps = 0.3, _matFlyTime = 0.5, _matBagLinger = 0.25;

/// A pile of one material lying where monsters fell: how many (its share of [Game.waveMaterials]), when its first and
/// last drop came, and from when it flies to the Bag (null until the wave is won).
class _MatPile {
  _MatPile(this.at, this.mat, this.t0) : last = t0;
  final math.Point<double> at;
  final Mat mat;
  int n = 0;
  double t0, last;
  double? fly;
}

/// [n] of [pile]'s material on their way onto it from [from] (where the kill fell, or a pile merged into it), since [t0].
class _MatHop {
  _MatHop(this.from, this.pile, this.n, this.t0);
  final math.Point<double> from;
  _MatPile pile;
  final int n;
  final double t0;
}

extension _MatLook on Board {
  /// The materials the game just dropped ([Game.matPops]) hop onto their piles; at a won wave the piles lying take off
  /// for the Bag, oldest first; the hops landed and the piles in the Bag go. The piles lying always hold the wave's
  /// tally ([Game.waveMaterials]): a kind whose tally was dropped or reset without a win (a new game, a save loaded)
  /// leaves the field with it.
  void _matPopsIn(Game g) {
    for (final (at, m, n) in g.matPops) {
      final near = _matPileNear(m, at), pile = near ?? _MatPile(at, m, g.t);
      if (near == null) _matLoot.add(pile);
      pile
        ..n += n
        ..last = g.t;
      _matPops.add(_MatHop(at, pile, n, g.t));
    }
    g.matPops.clear();
    _matPileCap(g);
    final won = [for (final p in _matLoot) if (p.fly == null && p.t0 <= g.victoryAt) p];
    if (won.isNotEmpty) {
      // A stream into the Bag rather than a block: nearest it first.
      final bag = _matBagAim(g).$1.center, s = _scale, o = _origin;
      double far(_MatPile p) => (o + Offset(p.at.x - camX, backdropH + p.at.y) * s - bag).distanceSquared;
      won.sort((a, b) => far(a).compareTo(far(b)));
      final gap = math.min(_matFlyGap, _matFlyGaps / math.max(1, won.length - 1));
      for (final (i, p) in won.indexed) {
        p.fly = math.max(g.victoryAt + _matFlyWait + i * gap, p.last + _matPopTime);
      }
    }
    final lying = <Mat, int>{};
    for (final p in _matLoot) {
      if (p.fly == null) lying[p.mat] = (lying[p.mat] ?? 0) + p.n;
    }
    final off = {for (final MapEntry(key: m, value: n) in lying.entries) if (g.waveMaterials[m] != n) m};
    _matLoot.removeWhere((p) => p.fly == null && off.contains(p.mat) || p.fly != null && g.t >= p.fly! + _matFlyTime + _matBagLinger);
    _matPops.removeWhere((h) => g.t - h.t0 >= _matPopTime || !_matLoot.contains(h.pile));
  }

  /// The nearest pile of [m] still lying within [_matPileReach] of [at].
  _MatPile? _matPileNear(Mat m, math.Point<double> at) {
    _MatPile? near;
    var best = _matPileReach;
    for (final p in _matLoot) {
      final d = p.at.distanceTo(at);
      if (p.mat == m && p.fly == null && d <= best) (near, best) = (p, d);
    }
    return near;
  }

  /// Past [_matPileMost] piles lying, the oldest that has another of its kind hops into the nearest of them.
  void _matPileCap(Game g) {
    while (_matLoot.where((p) => p.fly == null).length > _matPileMost) {
      final from = _matLoot.where((p) => p.fly == null && _matLoot.any((o) => o != p && o.mat == p.mat && o.fly == null)).firstOrNull;
      if (from == null) return; // every kind once: nothing to merge
      final into = _matLoot.where((o) => o != from && o.mat == from.mat && o.fly == null).reduce(
          (a, b) => a.at.distanceTo(from.at) <= b.at.distanceTo(from.at) ? a : b);
      into
        ..n += from.n
        ..t0 = math.min(into.t0, from.t0)
        ..last = math.max(into.last, g.t); // it takes off for the Bag once this hop has landed
      var landed = from.n; // what lay on it hops over; what was still on its way to it lands on [into] instead
      for (final h in _matPops) {
        if (h.pile != from) continue;
        h.pile = into;
        landed -= h.n;
      }
      if (landed > 0) _matPops.add(_MatHop(from.at, into, landed, g.t));
      _matLoot.remove(from);
    }
  }

  /// How many of each pile are still on their way onto it.
  Map<_MatPile, int> _matInAir() {
    final air = <_MatPile, int>{};
    for (final h in _matPops) {
      air[h.pile] = (air[h.pile] ?? 0) + h.n;
    }
    return air;
  }

  /// The piles lying where monsters fell, on the ground under the units (in field units, as the items' loot was before
  /// decisions-log 321: a 10-unit icon bobbing 2 units on the field's clock), each its material's icon; from 2 up its count in the Bag's capsule
  /// ("x5"), in screen pixels over every icon. Called inside the field's transform, before the units.
  void _matLootDraw(Canvas c, Game g) {
    if (_matLoot.isEmpty) return;
    final air = _matInAir(), counts = <(Offset, int)>[];
    for (final p in _matLoot) {
      final n = p.n - (air[p] ?? 0);
      if (n <= 0 || p.fly != null && g.t >= p.fly!) continue; // still hopping onto it, or off to the Bag
      final at = Offset(p.at.x, p.at.y - math.sin(_fieldClock * 4 + p.at.x).abs() * 2);
      _icon(c, p.mat, Rect.fromCenter(center: at, width: 10, height: 10));
      if (n > 1) counts.add((at, n));
    }
    if (counts.isEmpty) return;
    final s = _scale, o = _origin, fs = math.max(10.0, (3.2 * s).roundToDouble()), tight = s < 2.5;
    c.save();
    c.translate(camX, -backdropH); // back to screen pixels, so the capsule keeps whole ones
    c.scale(1 / s);
    c.translate(-o.dx, -o.dy);
    for (final (at, n) in counts) {
      _matCount(c, 'x${shortCount(n)}', fs, tight, o + Offset(at.dx + 5 - camX, backdropH + at.dy + 5) * s + const Offset(2, 2));
    }
    c.restore();
  }

  /// A pile's count: the Bag's count capsule ([_capsule]) with its bottom right at [corner], recorded once for each
  /// [label], size and tightness ([_matCounts]) and drawn from that, so no frame lays its text out again.
  void _matCount(Canvas c, String label, double fs, bool tight, Offset corner) {
    var count = _matCounts[(label, fs, tight)];
    if (count == null) {
      if (_matCounts.length >= 64) {
        for (final (picture, _) in _matCounts.values) {
          picture.dispose();
        }
        _matCounts.clear();
      }
      final rec = ui.PictureRecorder(), box = _capsule(Canvas(rec), label, fs, Offset.zero, anchor: Anchor.topLeft, tight: tight);
      count = _matCounts[(label, fs, tight)] = (rec.endRecording(), box.size);
    }
    final (picture, size) = count;
    c.save();
    c.translate((corner.dx - size.width).roundToDouble(), (corner.dy - size.height).roundToDouble());
    c.drawPicture(picture);
    c.restore();
  }

  /// Each drop hopping from where the monster fell onto its pile (screen space over the field at [o] and scale [s], over
  /// the units, as the casts' names): its icon growing in from 60%, up 16 field units at the hop's top, down onto the
  /// ground over [_matPopTime].
  void _matPopsDraw(Canvas c, Game g, Offset o, double s) {
    for (final h in _matPops) {
      final p = ((g.t - h.t0) / _matPopTime).clamp(0.0, 1.0), grow = math.min(1.0, 0.6 + p * 2), to = h.pile.at;
      final x = h.from.x + (to.x - h.from.x) * p, y = h.from.y - 8 + (to.y - h.from.y + 8) * p - 64 * p * (1 - p);
      final side = (10 * s * grow).roundToDouble();
      _icon(c, h.pile.mat, Rect.fromCenter(center: o + Offset(x - camX, backdropH + y) * s, width: side, height: side));
    }
  }

  /// Where the lying materials fly at a won wave: the book's Bag tab, its icon's box, and whether the book shows it; in
  /// landscape, where the book is shut at the win, where that tab stands once it opens ([_bookFit]'s rest).
  (Rect, bool) _matBagAim(Game g) {
    if (_tabAt[_Page.bag] case final tab? when _bookT > 0.99) {
      return (Rect.fromCenter(center: tab.center, width: tab.width * 0.8, height: tab.width * 0.8), true);
    }
    final (:ps, :rest, room: _, bw: _, bh: _) = _bookFit();
    final i = _bookTabs(g).indexWhere((t) => t.$2 == _Page.bag);
    return (Rect.fromLTWH(rest.left + bookTabLeft(i, ps) + 2 * ps, rest.top - 9 * ps, 16 * ps, 16 * ps), false);
  }

  /// At a won wave the piles fly to the Bag (screen space, over the field and the "VICTORY!" line, under the HUD):
  /// each on an arc from where it lay to the Bag tab's icon, shrinking to it and fading at the end, into the tab (the
  /// book's, drawn over them) or, while the book doesn't show its tab, into the tab's bag icon (ui_icons.png) shown
  /// there for the flight, bumping as each lands.
  void _matFlight(Canvas c, Game g, Offset o, double s) {
    final flown = [for (final p in _matLoot) if (p.fly != null) p];
    if (flown.isEmpty) return;
    final (bag, real) = _matBagAim(g);
    var bump = 0.0;
    for (final p in flown) {
      final k = (g.t - p.fly!) / _matFlyTime;
      if (k < 0) continue;
      if (k >= 1) {
        bump = math.max(bump, 1 - (k - 1) * _matFlyTime / 0.12);
        continue;
      }
      final e = k * k * (3 - 2 * k), from = o + Offset(p.at.x - camX, backdropH + p.at.y) * s, to = bag.center;
      final top = Offset((from.dx + to.dx) / 2, math.min(from.dy, to.dy) - 40); // the arc's pull, above both ends
      final at = from * ((1 - e) * (1 - e)) + top * (2 * (1 - e) * e) + to * (e * e);
      final side = (10 * s + (bag.width - 10 * s) * e).roundToDouble(), fade = k > 0.8 ? (1 - k) / 0.2 : 1.0;
      _icon(c, p.mat, Rect.fromCenter(center: at, width: side, height: side), _matPopPaints[(fade * 10).round()]);
    }
    if (real) return;
    final first = flown.map((p) => p.fly!).reduce(math.min), end = flown.map((p) => p.fly!).reduce(math.max) + _matFlyTime;
    final a = ((g.t - first + 0.15) / 0.15).clamp(0.0, 1.0) * ((end + _matBagLinger - g.t) / _matBagLinger).clamp(0.0, 1.0);
    final big = 1 + 0.25 * bump.clamp(0.0, 1.0);
    _uiIcon(c, Board._icBag, Rect.fromCenter(center: bag.center, width: bag.width * big, height: bag.height * big),
        _matPopPaints[(a * 10).round()]);
  }
}

/// The piles' counts as drawn ([_MatLook._matCount]), by label, size and tightness: at most 64, then recorded afresh.
final _matCounts = <(String, double, bool), (ui.Picture, Size)>{};

/// A material pop's paints, by its opacity in tenths.
final _matPopPaints = [
  for (var i = 0; i <= 10; i++)
    Paint()
      ..filterQuality = FilterQuality.none
      ..color = Color.fromRGBO(255, 255, 255, i / 10),
];
