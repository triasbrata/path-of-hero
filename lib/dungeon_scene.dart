part of 'main.dart';

// The Dungeon's scene (decisions-log 336, 337; docs/dungeon-design.md section 8; docs/ui-hud.md "Dungeon"): while a trip
// lasts ([Game.dungeon]) the Board draws the cave where the Town was, side on, a pixel of the pack a world unit (the
// Town's rule) at [_dunK] screen px: the dark fill behind everything, each room's back wall (BG Dirt1's slabs and pillars
// with a lit torch between them, lib/dungeon_art.dart), the stalactites along the view's top, the floor band's earth
// under the moss line at the wall's foot, the near ledge under the band; then by their feet's y the floor's props, the
// save point's campfire (the Town's town_campfire.png), the portal (the stairs) and the units (the field's own drawing,
// [Board._unit], with its bars), the shots and the bursts; over the units the hostile monsters' "!", the leader's crown
// and the pointed unit's name, and the numbers of the blows and heals rising and fading. The camera follows the leader
// ([DungeonTrip._aimCam]). Going in and coming out fades from black. The HUD and the Action chain are
// lib/dungeon_hud.dart's; the keys, the taps and the stick are read here.

/// The world units the view shows up the screen: its scale is the screen's height over this, whole (1 at the least),
/// so the tiles keep their pixels: 4 at 1600x947, 3 at 1266x713, 2 at 915x412.
const dungeonViewH = 236.0;

/// How far down the view the moss line at the back wall's foot ([bandTop]) lies: the wall and the ceiling above it, the
/// band and the near ledge under it.
const dungeonWallShare = 0.3;

/// The torches', the portal's and the campfire's frames a second.
const _dunFps = 8.0;

/// A blow's or a heal's number rises this far (world units) over [_dunPopTime] s of the game's clock, fading.
const _dunPopRise = 12.0, _dunPopTime = 0.8;

/// Going into the Dungeon or coming out fades from black over this long (s, the screen's clock).
const _dunFade = 0.35;

/// A unit takes a tap within this of its body's middle (screen px; at least [_dunTapMin], the tap rule's half).
const _dunTapMin = 22.0;

/// The foe's target ring: the necromancer's green summon ring ([Board._dunRing]) turned red, its green channel (the
/// brightest) as the red.
const _dunRedRing = ColorFilter.matrix(<double>[
  0, 1, 0, 0, 0, //
  0, 0.25, 0, 0, 0, //
  0, 0.25, 0, 0, 0, //
  0, 0, 0, 1, 0, //
]);

/// A number over a unit: on whom, where it rose from (world), its words, its colour and when it came (game clock).
typedef _DunPop = ({math.Point<double> at, String text, Color color, double t});

/// The Dungeon's view between frames ([Board._dun]).
class _DungeonView {
  Dungeon? trip; // the trip last seen: another one, or none, starts the view afresh
  double k = 2, top = 0; // screen px a world unit; the view's top in world y
  Offset o = Offset.zero; // where world (0, 0) is on the screen
  double fadeAt = double.negativeInfinity; // when the last trip began or ended (screen clock)
  final hp = <Unit, double>{}; // each unit's HP last frame: a drop is a blow's number, a rise a heal's
  final pops = <_DunPop>[];
  // The Action chain (lib/dungeon_hud.dart): its step (0 shut, 1 who, 2 what, 4 on whom: M1 has no step 3), the member
  // it is for, the pointer's row in the step's list.
  int step = 0, point = 0;
  Unit? who;
  // The joystick: its middle while a finger holds it, and where the finger is (screen).
  Offset? stickMid, stickAt;
  // This frame: what takes a tap (on tap down, in order), where each part was drawn by name (for tests), the units'
  // bodies on the screen.
  final taps = <(Rect, VoidCallback)>[];
  final at = <String, Rect>{};
  final bodies = <Unit, Offset>{};

  void clear() {
    taps.clear();
    at.clear();
    bodies.clear();
  }

  /// A new trip, or none: no chain, no numbers, no stick.
  void reset() {
    hp.clear();
    pops.clear();
    step = point = 0;
    who = null;
    stickMid = stickAt = null;
  }
}

extension _DungeonScene on Board {
  /// The scene's scale: screen px a world unit ([dungeonViewH]).
  double get _dunK => math.max(1.0, (size.y / dungeonViewH).roundToDouble());

  /// Whether time stands still for the Dungeon: the Action chain is open (Wait, the only mode in M1).
  bool get _dunStill => state.dungeon != null && _dun.step > 0;

  /// The touch screen's layout (the joystick, the Action button at the thumb, the chain as one panel at the bottom):
  /// on a phone or a tablet.
  bool get _dunTouch => _onPhone;

  /// [w] in world units on the screen.
  Offset _dunScreen(math.Point<double> w) => Offset(_dun.o.dx + w.x * _dun.k, _dun.o.dy + w.y * _dun.k);

  /// Before the tick: another trip (or none) starts the view afresh and fades in; the view's width and the leader's
  /// stick (WASD held, or the joystick) go to the trip.
  void _dungeonFrame(Game g) {
    final d = g.dungeon, v = _dun;
    if (!identical(d, v.trip)) {
      if (d != null || v.trip != null) v.fadeAt = _clock;
      v
        ..trip = d
        ..reset();
      // The bursts and the casts' names run on the game's clock, which a trip's end puts back: none carries over.
      _bursts.clear();
      _pops.clear();
    }
    if (d == null) return;
    d.viewW = size.x / _dunK;
    var x = 0.0, y = 0.0;
    if (v.stickMid case final mid?) {
      final r = _dun.at['joystick']?.width ?? 1, p = (v.stickAt ?? mid) - mid, len = p.distance, most = r * 0.4;
      if (len > 4) (x, y) = (p.dx / math.max(len, most), p.dy / math.max(len, most));
    } else {
      final keys = HardwareKeyboard.instance.logicalKeysPressed;
      if (keys.contains(LogicalKeyboardKey.keyA)) x -= 1;
      if (keys.contains(LogicalKeyboardKey.keyD)) x += 1;
      if (keys.contains(LogicalKeyboardKey.keyW)) y -= 1;
      if (keys.contains(LogicalKeyboardKey.keyS)) y += 1;
    }
    d.stick = math.Point(x, y);
  }

  /// After the tick: each unit's HP against last frame's makes its number (a blow white on a foe and red on a member, a
  /// heal green "+24"); the numbers that have risen go; the news of a trip that ended shows in the message window.
  void _dungeonAfter(Game g) {
    final v = _dun, d = g.dungeon;
    if (g.tripNews case (:final end, floor: _)?) {
      g.tripNews = null;
      showMessage(switch (end) {
        TripEnd.cleared => Words.floorCleared,
        TripEnd.fell => '${Words.partyFell}\n${Words.partyFellNote}',
        TripEnd.left => Words.leftDungeon,
      }, time: _noteTime);
    }
    if (d == null) return;
    v.pops.removeWhere((p) => g.t - p.t >= _dunPopTime || g.t < p.t);
    v.hp.removeWhere((u, _) => !g.units.contains(u));
    for (final u in g.units) {
      final was = v.hp[u], now = u.hp;
      v.hp[u] = now;
      if (was == null) continue;
      final dd = now - was;
      if (dd <= -0.5) {
        v.pops.add((at: u.pos, text: '${(-dd).round()}', color: u.side == Side.enemy ? Colors.white : const Color(0xFFFF7A6A), t: g.t));
      } else if (dd >= 1) {
        v.pops.add((at: u.pos, text: '+${dd.round()}', color: const Color(0xFF9CF07A), t: g.t));
      }
    }
    if (v.step >= 2 && !d.standing(v.who!)) _dunChainClose(); // its member fell
  }

  /// The cave and everything in it, from the trip's camera (render's first part while [Game.dungeon]).
  void _dungeonScene(Canvas c, Game g) {
    final d = g.dungeon!, v = _dun..clear(), k = v.k = _dunK, h = size.y / k;
    v.top = bandTop - dungeonWallShare * h;
    final ox = -(d.cam * k).roundToDouble(), oy = -(v.top * k).roundToDouble();
    v.o = Offset(ox, oy);
    final x0 = d.cam - 2, x1 = d.cam + size.x / k + 2, y0 = v.top - 2, y1 = v.top + h + 2;
    final tiles = _img(dungeonTiles), props = _img(dungeonProps), frame = (_fieldClock * _dunFps).floor();
    Rect src(DungeonCell s, [int f = 0]) => Rect.fromLTWH((s.x + f * s.w).toDouble(), s.y.toDouble(), s.w.toDouble(), s.h.toDouble());
    void flat(String cell, Rect to) {
      final s = dungeonTileCells[cell]!;
      c.drawImageRect(tiles, Rect.fromLTWH(s.x + s.w / 2, s.y + s.h / 2, 1, 1), to, _px); // a flat colour's middle pixel
    }

    c.save();
    c.translate(ox, oy);
    c.scale(k);
    flat('fill', Rect.fromLTRB(x0, y0, x1, y1)); // the cave behind and above
    final rooms = [for (final r in d.floor.rooms) if (r.x1 > x0 && r.x0 < x1) r];
    // The back wall: the slabs and the pillars standing on the moss line, a lit torch between them.
    for (final r in rooms) {
      for (final p in r.props) {
        if (!p.wall || p.kind == 'torch') continue;
        final s = dungeonTileCells[p.kind]!;
        c.drawImageRect(tiles, src(s), Rect.fromLTWH(p.x - s.w / 2, bandTop - s.h, s.w.toDouble(), s.h.toDouble()), _px);
      }
    }
    for (final r in rooms) {
      for (final p in r.props) {
        if (p.kind != 'torch') continue;
        final s = dungeonPropCells['torch']!, n = dungeonPropFrames['torch']!;
        c.drawImageRect(props, src(s, (frame + p.x.toInt()) % n), Rect.fromLTWH(p.x - s.w / 2, bandTop - 10 - s.h, s.w.toDouble(), s.h.toDouble()), _px);
      }
    }
    // The ceiling: the stalactites along the view's top, moving with the floor.
    final st = dungeonTileCells['stalactites']!;
    for (var x = (x0 / st.w).floor() * st.w.toDouble(); x < x1; x += st.w) {
      c.drawImageRect(tiles, src(st), Rect.fromLTWH(x, v.top - 2, st.w.toDouble(), st.h.toDouble()), _px);
    }
    // The band: each room's earth from the moss line down to its depth; the near ledge under it, its moss on top.
    final ledge = dungeonTileCells['ledge']!, moss = dungeonTileCells['moss']!;
    for (final r in rooms) {
      flat('earth', Rect.fromLTRB(r.x0, bandTop, r.x1, r.bottom + 2));
      c.save();
      c.clipRect(Rect.fromLTRB(r.x0, r.bottom, r.x1, y1));
      for (var x = (r.x0 / ledge.w).floor() * ledge.w.toDouble(); x < r.x1; x += ledge.w) {
        c.drawImageRect(tiles, src(ledge), Rect.fromLTWH(x, r.bottom + 2, ledge.w.toDouble(), ledge.h.toDouble()), _px);
      }
      c.restore();
    }
    // The moss line along the wall's foot, its blades over the band's top edge (its last row, the earth's, left off).
    for (var x = (x0 / moss.w).floor() * moss.w.toDouble(); x < x1; x += moss.w) {
      c.drawImageRect(tiles, Rect.fromLTWH(moss.x.toDouble(), moss.y.toDouble(), moss.w.toDouble(), moss.h - 1.0),
          Rect.fromLTWH(x, bandTop - 6, moss.w.toDouble(), moss.h - 1.0), _px);
    }
    // By their feet's y: the props on the band, the save point, the portal and the units.
    final ground = <(double, VoidCallback)>[];
    for (final r in rooms) {
      for (final p in r.props) {
        if (p.wall) continue;
        final s = dungeonPropCells[p.kind]!;
        ground.add((p.y, () {
          final to = Rect.fromLTWH(p.x - s.w / 2, p.y + 2 - s.h, s.w.toDouble(), s.h.toDouble());
          if (!p.flip) return c.drawImageRect(props, src(s), to, _px);
          c
            ..save()
            ..translate(to.center.dx, 0)
            ..scale(-1, 1)
            ..translate(-to.center.dx, 0);
          c.drawImageRect(props, src(s), to, _px);
          c.restore();
        }));
      }
    }
    final save = d.floor.savePoint, portal = d.floor.portal;
    ground
      ..add((save.y, () {
        const f = townCampfireFrame;
        c.drawImageRect(_img(townCampfire), Rect.fromLTWH((frame % townCampfireFrames) * f.toDouble(), 0, f.toDouble(), f.toDouble()),
            Rect.fromLTWH(save.x - f / 2, save.y + 6 - f, f.toDouble(), f.toDouble()), _px);
      }))
      ..add((portal.y, () {
        const f = dungeonPortalFrame;
        c.drawImageRect(_img(dungeonPortal), Rect.fromLTWH((frame % dungeonPortalFrames) * f.toDouble(), 0, f.toDouble(), f.toDouble()),
            Rect.fromLTWH(portal.x - f / 2, portal.y + 8 - f, f.toDouble(), f.toDouble()), _px);
      }));
    _pusakaLook.refresh(g); // which type holds which Pusaka, for the rings and the bars (pusaka_look.dart)
    final ring = _dunRingOn(g);
    for (final u in g.units) {
      ground.add((u.pos.y, () {
        if (u == ring) _dunRing(c, u);
        _unit(c, g, u);
        _dunMarks(c, g, u);
      }));
    }
    ground.sort((a, b) => a.$1.compareTo(b.$1));
    for (final (_, draw) in ground) {
      draw();
    }
    _shotsDraw(c, g);
    _burstsDraw(c, g);
    c.restore();
    for (final u in g.units) {
      v.bodies[u] = _dunScreen(math.Point(u.pos.x, u.pos.y - 10));
    }
    v.at['scene'] = Offset.zero & Size(size.x, size.y);
    v.at['band'] = Rect.fromLTRB(0, _dunScreen(const math.Point(0, bandTop)).dy, size.x,
        _dunScreen(math.Point(0, d.floor.rooms.map((r) => r.bottom).reduce(math.max))).dy);
    _dunPops(c, g);
    _dunPointedName(c, g);
  }

  /// The unit whose ring shows under it: the pointed one while the chain's target list is open, else the leader's
  /// action's target.
  Unit? _dunRingOn(Game g) {
    final d = g.dungeon!;
    if (_dun.step == 4) return _dunPointed(g);
    return d.minds[d.leader]?.act?.target;
  }

  /// The target's ring under [u]'s feet: the necromancer's summon ring ([tiny_fx_summon.png]'s full frame), its own
  /// green under a member, red under a foe ([_dunRedRing]).
  void _dunRing(Canvas c, Unit u) {
    final paint = u.side == Side.enemy ? (_dunRedPaint ??= Paint()
      ..filterQuality = FilterQuality.none
      ..colorFilter = _dunRedRing) : _px;
    _frame(c, 'tiny_fx_summon.png', 3, Offset(u.pos.x, u.pos.y + 5), paint: paint);
  }

  /// Over a unit's bar ([unitBar]): a hostile monster's yellow "!" (ui_icons.png's, [_icAlert]), the leader's crown
  /// (over a Hero's own crown when it is one).
  void _dunMarks(Canvas c, Game g, Unit u) {
    final d = g.dungeon!;
    if (!u.alive || u.dying >= 0) return;
    final top = unitBar(u.pos.x, u.pos.y, mp: u.stats.mp > 0).box.top;
    if (u.side == Side.enemy && d.hostile(u)) _uiIcon(c, _icAlert, Rect.fromLTWH(u.pos.x - 4, top - 9, 8, 8));
    if (u == d.leader) _uiIcon(c, _icCrown, Rect.fromLTWH(u.pos.x - 4, top - (u.hero ? 17 : 8.5), 8, 8));
  }

  /// The numbers rising over the units and fading ([_DungeonView.pops]), in the HUD's font with an outline, on the
  /// screen.
  void _dunPops(Canvas c, Game g) {
    final fs = math.max(14.0, 5 * _dun.k);
    for (final p in _dun.pops) {
      final age = ((g.t - p.t) / _dunPopTime).clamp(0.0, 1.0);
      final at = _dunScreen(math.Point(p.at.x, p.at.y - 26 - _dunPopRise * age));
      final a = 1 - age * age;
      _text(c, p.text, at, size: fs, color: p.color.withValues(alpha: a), anchor: Anchor.center,
          outline: const Color(0xFF1B1010).withValues(alpha: a), bold: true);
    }
  }

  /// The pointed unit's name over it while the chain's target list is open.
  void _dunPointedName(Canvas c, Game g) {
    if (_dun.step != 4) return;
    final u = _dunPointed(g);
    if (u == null) return;
    final at = _dunScreen(math.Point(u.pos.x, unitBar(u.pos.x, u.pos.y, mp: u.stats.mp > 0).box.top - 12));
    _text(c, _dunName(u), at, size: math.max(12.0, 5 * _dun.k), anchor: Anchor.center, outline: const Color(0xFF1B1010));
  }

  /// A unit's name as the HUD writes it: a member's own, a monster's type's.
  String _dunName(Unit u) => u.side == Side.troop ? u.name : monsterTypeNames[u.type] ?? u.type;

  /// Going in or coming out: the fade from black over the scene (and the Town's, as it comes back).
  void _dunFadeDim(Canvas c) {
    final t = (_clock - _dun.fadeAt) / _dunFade;
    if (t < 0 || t >= 1) return;
    c.drawRect(Offset.zero & Size(size.x, size.y), Paint()..color = Colors.black.withValues(alpha: 1 - t));
  }

  // ---- the input ---------------------------------------------------------------------------------------------------

  /// A key in the Dungeon (before the pause's and the pocket's): with the chain shut Up / Down switch the leader, Enter
  /// or Space open the chain, G turns the gambits on or off; with it open Up / Down move its pointer, Enter or Space pick,
  /// Esc or Backspace go back a step (from the first it shuts). WASD are read held, each frame ([_dungeonFrame]). Esc
  /// with the chain shut and P pause as on the field. True when it did something.
  bool _dungeonKey(LogicalKeyboardKey key) {
    final g = state, d = g.dungeon, v = _dun;
    if (d == null || welcome != null || _coach.showing || g.paused) return false;
    final up = key == LogicalKeyboardKey.arrowUp, down = key == LogicalKeyboardKey.arrowDown;
    final pick = key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.numpadEnter || key == LogicalKeyboardKey.space;
    if (v.step > 0) {
      if (up || down) {
        _dunPointBy(g, up ? -1 : 1);
      } else if (pick) {
        _dunPick(g);
      } else if (key == LogicalKeyboardKey.escape || key == LogicalKeyboardKey.backspace) {
        _dunBack();
      } else {
        return key == LogicalKeyboardKey.arrowLeft || key == LogicalKeyboardKey.arrowRight; // the tabs: Foes only in M1
      }
      return true;
    }
    if (up || down) {
      g.switchLeader(up ? -1 : 1);
    } else if (pick) {
      _dunChainOpen(g);
    } else if (key == LogicalKeyboardKey.keyG) {
      g.toggleGambits();
    } else {
      return false;
    }
    return true;
  }

  /// A press in the Dungeon ([Board.onTapDown], after the cards and windows over everything): the HUD's parts in their
  /// order, the joystick (it holds from the press), else on the scene with the chain shut a foe gives the leader an
  /// Attack on it and a member leads. True while a trip lasts: nothing under it takes the press.
  bool _dungeonDown(Offset p) {
    final g = state, d = g.dungeon, v = _dun;
    if (d == null || welcome != null) return false;
    if (v.at['joystick'] case final joy? when joy.contains(p) && !g.paused) {
      v
        ..stickMid = joy.center
        ..stickAt = p;
      return true;
    }
    for (final (r, fn) in v.taps) {
      if (r.contains(p)) {
        Sounds.play(Sfx.click);
        fn();
        return true;
      }
    }
    if (v.step > 0 || g.paused) return true;
    final u = _dunUnitAt(p);
    if (u == null) return true;
    if (u.side == Side.enemy) {
      g.command(d.leader, ActKind.attack, u);
    } else {
      g.lead(u);
    }
    return true;
  }

  /// The joystick's finger moved to [p].
  void _dungeonDrag(Offset p) {
    if (_dun.stickMid != null) _dun.stickAt = p;
  }

  /// The joystick let go.
  void _dungeonLetGo() => _dun.stickMid = _dun.stickAt = null;

  /// The unit nearest [p] within its tap distance: the body's middle within [_dunTapMin] px, or 9 world units at a
  /// bigger scale; a member knocked out takes none.
  Unit? _dunUnitAt(Offset p) {
    final g = state, d = g.dungeon!, reach = math.max(_dunTapMin, 9 * _dun.k);
    Unit? best;
    var bestD = reach;
    for (final MapEntry(key: u, value: at) in _dun.bodies.entries) {
      if (!u.alive || u.dying >= 0 || (u.side == Side.troop && !d.standing(u))) continue;
      final dd = (at - p).distance;
      if (dd <= bestD) (best, bestD) = (u, dd);
    }
    return best;
  }
}

/// The foe's ring paint, made once.
Paint? _dunRedPaint;
