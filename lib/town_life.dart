part of 'main.dart';

// The Town's life (decisions-log 229; docs/ui-hud.md "Town", its "Town life"): every living troop of the army (its
// Heroes too; the fallen not) walks the Town's one street and does something there, the owner's note of 2026-10-04:
// "para pasukan nanti akan seperti jalan jalan di sekitar kota ... mereka bisa saling passthrough karna di kota hanya 1
// line. dan buat aktifitas untuk masing masing trops, ada yang berjaga, ada yang saling bicara dengan buble di atas
// kepala mereka terus ada yang lihat lihat shop dan ada yang lihat lihat smitty, ada yang ngobrol di dalam tavern" and
// "tenda hanya jadi seperti tempat per-istirahatan para troops". Dark like the Town ([Game.towns]).
//
// [TownLife] is the troops' errands along the street in the layout's world px ([_TownLayout.spots] are its anchors),
// rolled on its own VISUAL dice ([TownLife.dice]), never the game's: nothing in it reaches a [Game] but reading its
// units, so a run plays the same with the Towns' scene shown or not. The Board steps it in its update while the Town shows
// ([_townLifeTick]; not while paused) and draws it over the scene's pieces ([_townFolk]): the field's own strips
// (tiny_<type>_idle / _walk, no ground shadow: decisions-log 270), [townFolkK] world px a sprite px (about the field's
// own size on the screen in landscape), passing through each other on the lane, the lower drawn in front
// ([TownFolk.depth]); the bubbles from ui_all.png's speech bubbles (the white one said, the grey see-through one
// thought) with an icon in them, no words.

/// What a troop does in a Town ([TownLife]): strolls to a point and looks about; stands guard at the Town's end facing
/// out; talks with another (they meet before the Tavern's right side, the 'talk' anchor, or between them, face each
/// other, and a speech bubble shows over one head, then the other); browses the Shop's stalls or the Smithy's furnace
/// (a thought bubble: coins, the hammer); goes into the Tavern (up its doorstep, gone inside for a while, a bubble at its
/// window, out through its door again); rests in the tent's opening or by its fire.
enum TownDo { stroll, guard, talk, shop, smithy, tavern, rest }

/// How likely each [TownDo] is at a roll, in its order: one [TownLife.dice] draw in [0, 1) picks the one whose share of
/// the whole it falls in (stroll 6/25, guard 2/25, talk 5/25, the rest 3/25 each).
const townWeights = [6, 2, 5, 3, 3, 3, 3];

/// The most troops at once at a place (one more rolls a stroll): the guards (the Town's two ends), the Shop's and the
/// Smithy's browsers, the Tavern's guests, the resting.
const townMost = {TownDo.guard: 2, TownDo.shop: 4, TownDo.smithy: 4, TownDo.tavern: 8, TownDo.rest: 4};

/// How long a troop stays once there, seconds (from, to; the dice picks between): a stroll's look about, a guard's
/// watch, a browse, a Tavern visit (inside), a rest. A talk is [townTalkLines] lines of [townLine] s.
const townStay = {
  TownDo.stroll: (1.0, 3.0),
  TownDo.guard: (8.0, 16.0),
  TownDo.shop: (4.0, 9.0),
  TownDo.smithy: (4.0, 9.0),
  TownDo.tavern: (6.0, 14.0),
  TownDo.rest: (8.0, 16.0),
};

/// A talk's lines (from, to: 3 to 6) and each line's seconds; a line's bubble shows for its first [townSay] share, over
/// the one who began the talk on even lines, over the other on odd ones.
const townTalkLines = (3, 6), townLine = 1.6, townSay = 0.75;

/// World px a sprite px of a troop (the field's strips: 1 sprite px a world unit there); a stroll's pace, a share of its
/// type's speed on the field (and of its walk strip's frame rate); the street's ends no one walks past; how far apart
/// two talking stand; a browser's places beside the Shop's or the Smithy's anchor (slot by slot, either side, facing it);
/// a resting one's beside the tent's (the fire [townFire] right of it).
const townFolkK = 2.0, townPace = 0.6, townEdge = 10.0, townTalkGap = 26.0;
const townBrowse = [-18.0, 18.0, -34.0, 34.0], townRest = [0.0, 16.0, -14.0, 56.0], townFire = 38.0;

/// When a browser's thought shows, from its arrival (s): from, to.
const townThink = (0.6, 2.4);

/// The Tavern's window bubble: while anyone is inside, the first [townWindowFor] s of every [townWindowEvery].
const townWindowEvery = 5.0, townWindowFor = 1.8;

/// Inside is higher (decisions-log 274; the owner, 2026-10-08: "ketika animasi para army masuk bangunan harusnya ground
/// levelnya lebi naik lagi sedikit jadi terlihat ada perbedaan tinggi antar yang lagi di dalam bangunan dan yang diluar
/// bangunan"): a troop going in steps up at the threshold and stands there on the place's floor ([TownFolk.up],
/// [TownFolk.floor]), over the street's troops at any depth; it steps back down as it comes out. Since decisions-log
/// 279 the places stand on the ground strip's top edge with nothing over their feet, so each floor is its art's own:
/// the houses' porch, [townStep] (its 8 px) over the street's line, where a Tavern guest stands on the door's sill and
/// the smith on the Smithy's floor (4 until then, the porch hidden in the grass); the tent's, [townTentStep] over it,
/// the top of its canvas's darker hem (its last 4 rows; at the porch's 8 a resting troop hovered over the bare canvas).
/// Two places take one in: the Tavern, whose doorway a guest stands in for [townDoorway] s on the way in and again on
/// the way out (inside, not drawn, between), and the tent, whose opening ([townTentOpen] around its anchor, world px) a
/// resting one stands in. Since decisions-log 292 a troop's soles end on its line ([townFeet]): on the hem's top, on the
/// sill, on the street's strip at its depth; until then they ended 4 world px over every one of them.
const townStep = 8.0, townTentStep = 4.0, townDoorway = 0.6, townTentOpen = (-30.0, 22.0);

/// A bubble's icon: its file and its 16-px cell (the Town's 32x32 files are a 16-px icon doubled).
enum TownIcon {
  heart('ui_icons.png', Rect.fromLTWH(0, 0, 16, 16)),
  star('ui_icons.png', Rect.fromLTWH(48, 0, 16, 16)),
  coin('ui_icons.png', Rect.fromLTWH(96, 0, 16, 16)),
  sword('ui_icons.png', Rect.fromLTWH(16, 16, 16, 16)),
  crown('ui_icons.png', Rect.fromLTWH(64, 16, 16, 16)),
  trophy('ui_icons.png', Rect.fromLTWH(80, 16, 16, 16)),
  coins('ui_icons.png', Rect.fromLTWH(208, 48, 16, 16)),
  mug('town_mug.png', Rect.fromLTWH(0, 0, 32, 32)),
  hammer('town_mark.png', Rect.fromLTWH(0, 0, 32, 32));

  const TownIcon(this.file, this.src);
  final String file;
  final Rect src;
}

/// What a talk's lines are about: one icon a line, on the dice.
const townTopics = [TownIcon.heart, TownIcon.star, TownIcon.coin, TownIcon.sword, TownIcon.crown, TownIcon.trophy, TownIcon.mug];

/// One troop in a Town ([TownLife]): its unit on the field (read only), where it is and what it does.
class TownFolk {
  TownFolk(this.unit, this.depth, this.phase)
      : idle = 'tiny_${unit.type}_idle.png',
        walk = 'tiny_${unit.type}_walk.png',
        speed = (troopTypes[unit.type]?.speed ?? 20.0) * townPace * townFolkK;

  final Unit unit;

  /// World px under the lane its feet stand on (0 to 4: the lower drawn in front), and its strips' head start (s).
  final double depth, phase;

  /// Its strips (the field's, without their shadow: decisions-log 270) and its stroll's world px a second.
  final String idle, walk;
  final double speed;

  TownDo doing = TownDo.stroll;

  /// How far over the lane it stands while [up] (world px): resting, the tent's floor [townTentStep]; else the Tavern's
  /// porch, [townStep].
  double get floor => doing == TownDo.rest ? townTentStep : townStep;

  double x = double.nan; // along the street, world px (NaN: not placed yet)
  double goal = double.nan; // where it walks to (NaN: it stands)
  double from = 0; // when it got there (a talk: when both stood)
  double until = double.infinity; // when its stay ends (+inf: on its way, or waiting for its mate)
  int dir = 1; // facing: 1 right
  int slot = 0; // its place among those doing the same (a guard's end, a browser's or a resting one's place)
  bool inside = false; // in the Tavern: not drawn
  bool up = false; // on a place's floor (the Tavern's doorway, the tent's opening): [floor] higher, no depth
  TownFolk? mate; // talking with
  bool lead = false; // a talk's: began it, says the even lines
  int line = -1; // a talk's line now (the lead's)
  TownIcon? topic; // and that line's icon (the lead's)
  TownIcon? said; // its bubble now (null: none)
  bool thought = false; // that bubble a thought (grey) rather than said (white)

  // As drawn this frame (screen px), for tests: whether it showed, its feet, its bubble's box (bw 0: none).
  bool shown = false;
  double sx = 0, sy = 0, bx = 0, by = 0, bw = 0, bh = 0;

  bool get walking => !goal.isNaN;
}

/// The troops' life in a Town: [folk] follow the army's living troops ([sync]) and [step] along a street [width] world
/// px long with its anchors ([stage]), each on errands rolled on [dice] ([TownDo]).
class TownLife {
  TownLife([math.Random? dice]) : dice = dice ?? math.Random();

  /// The visual dice: every roll of the Town's life, never the game's. Tests set their own.
  math.Random dice;

  /// The troops, back to front (by [TownFolk.depth], then the order they joined).
  final folk = <TownFolk>[];
  final _of = <Unit, TownFolk>{};

  /// The life's clock (s; it stands while the game is paused), the street's length (world px; 0: not staged) and its
  /// anchors (the layout's: 'guard', 'tent', 'smithy', 'tavernDoor', 'talk', 'shop').
  double t = 0, width = 0;
  final spots = <String, double>{};

  /// Everyone gone, the clock back to 0, not staged: a Town coming in starts afresh.
  void reset() {
    folk.clear();
    _of.clear();
    t = 0;
    width = 0;
    spots.clear();
  }

  /// The street: [w] world px long, its anchors [at]. A new street (the screen's size changed) sends everyone on to a new
  /// errand from where they stand.
  void stage(double w, Map<String, double> at) {
    final again = width > 0;
    width = w;
    spots
      ..clear()
      ..addAll(at);
    if (!again) return;
    for (final f in folk) {
      if (f.x.isNaN) continue;
      f.x = f.x.clamp(townEdge, math.max(townEdge, w - townEdge));
      _next(f);
    }
  }

  /// Brings [folk] in line with [units]' living troops: a new one joins (placed at the next [step]), one gone (fallen,
  /// sent home, another game's) leaves, and its mate finds something else to do. Nothing allocated while they match.
  void sync(List<Unit> units) {
    var n = 0, fresh = false;
    for (var i = 0; i < units.length; i++) {
      final u = units[i];
      if (u.side != Side.troop || !u.alive) continue;
      n++;
      if (!_of.containsKey(u)) fresh = true;
    }
    if (!fresh && n == folk.length) return;
    final alive = {for (final u in units) if (u.side == Side.troop && u.alive) u};
    for (final f in [...folk]) {
      if (alive.contains(f.unit)) continue;
      folk.remove(f);
      _of.remove(f.unit);
      if (f.mate case final m?) {
        m
          ..mate = null
          ..goal = double.nan
          ..until = t; // its stay ends now: it rolls again
      }
    }
    for (final u in alive) {
      if (_of.containsKey(u)) continue;
      final f = TownFolk(u, (dice.nextDouble() * 5).floorToDouble(), dice.nextDouble() * 10);
      folk.add(f);
      _of[u] = f;
    }
    folk.sort((a, b) => a.depth != b.depth ? a.depth.compareTo(b.depth) : a.unit.id.compareTo(b.unit.id));
  }

  /// [dt] s of the life: a troop not yet placed stands somewhere along the street and rolls an errand; one on its way
  /// walks on (facing where it goes) and starts it on arriving; one whose stay is over rolls the next. Then the bubbles.
  void step(double dt) {
    if (width <= 0) return;
    t += dt;
    for (var i = 0; i < folk.length; i++) {
      final f = folk[i];
      if (f.x.isNaN) {
        f
          ..x = townEdge + dice.nextDouble() * math.max(0.0, width - 2 * townEdge)
          ..dir = dice.nextDouble() < 0.5 ? -1 : 1;
        _next(f);
      }
      if (f.walking) {
        final d = f.goal - f.x, s = f.speed * dt;
        if (d != 0) f.dir = d < 0 ? -1 : 1;
        if (d.abs() <= s) {
          f
            ..x = f.goal
            ..goal = double.nan;
          _arrive(f);
        } else {
          f.x += d < 0 ? -s : s;
        }
      } else if (t >= f.until) {
        _next(f);
      } else if (f.doing == TownDo.tavern) {
        f.inside = t >= f.from + townDoorway && t < f.until - townDoorway; // in its doorway at either end of the visit
      }
    }
    for (var i = 0; i < folk.length; i++) {
      _bubble(folk[i]);
    }
  }

  /// How many are inside the Tavern now.
  int get inTavern {
    var n = 0;
    for (var i = 0; i < folk.length; i++) {
      if (folk[i].inside) n++;
    }
    return n;
  }

  /// Whether the Tavern's window shows its bubble now ([townWindowEvery], [townWindowFor]).
  bool get windowBubble => inTavern > 0 && t % townWindowEvery < townWindowFor;

  /// The [TownDo] a draw [r] in [0, 1) picks ([townWeights]).
  static TownDo pick(double r) {
    final total = townWeights.fold(0, (a, b) => a + b);
    var at = r * total;
    for (var i = 0; i < townWeights.length; i++) {
      at -= townWeights[i];
      if (at < 0) return TownDo.values[i];
    }
    return TownDo.values.last;
  }

  /// A draw in [0, 1) that [pick]s [what] (the middle of its share): for tests' dice.
  static double drawFor(TownDo what) {
    final total = townWeights.fold(0, (a, b) => a + b);
    final before = townWeights.take(what.index).fold(0, (a, b) => a + b);
    return (before + townWeights[what.index] / 2) / total;
  }

  double _roll((double, double) span) => span.$1 + dice.nextDouble() * (span.$2 - span.$1);

  int _count(TownDo what, TownFolk but) {
    var n = 0;
    for (final o in folk) {
      if (!identical(o, but) && o.doing == what) n++;
    }
    return n;
  }

  /// The lowest place [what] has free (another doing it holds its own).
  int _freeSlot(TownDo what, TownFolk but) {
    for (var s = 0;; s++) {
      if (!folk.any((o) => !identical(o, but) && o.doing == what && o.slot == s)) return s;
    }
  }

  /// [f]'s next errand, rolled: a talk takes the nearest one strolling (none: a stroll); a full place ([townMost]) a
  /// stroll too. It sets out for it at once.
  void _next(TownFolk f) {
    if (f.mate case final m? when identical(m.mate, f)) m.mate = null;
    f
      ..mate = null
      ..lead = false
      ..inside = false
      ..up = false // it steps down as it sets out
      ..said = null
      ..thought = false
      ..line = -1
      ..topic = null
      ..doing = TownDo.stroll
      ..until = double.infinity
      ..slot = 0;
    var what = pick(dice.nextDouble());
    TownFolk? mate;
    if (what == TownDo.talk) {
      for (final o in folk) {
        if (identical(o, f) || o.doing != TownDo.stroll || o.mate != null || o.x.isNaN) continue;
        if (mate == null || (o.x - f.x).abs() < (mate.x - f.x).abs()) mate = o;
      }
      if (mate == null) what = TownDo.stroll;
    }
    if (townMost[what] case final most? when _count(what, f) >= most) what = TownDo.stroll;
    f.doing = what;
    switch (what) {
      case TownDo.stroll:
        f.goal = _strollTo();
      case TownDo.guard:
        f.slot = _freeSlot(what, f);
        final end = spots['guard'] ?? townEdge;
        f.goal = f.slot == 0 ? end : width - end; // the Town's left end, then its right
      case TownDo.shop || TownDo.smithy:
        f.slot = _freeSlot(what, f);
        f.goal = (spots[what.name] ?? width / 2) + townBrowse[f.slot % townBrowse.length];
      case TownDo.tavern:
        f.goal = spots['tavernDoor'] ?? width / 2;
      case TownDo.rest:
        f.slot = _freeSlot(what, f);
        f.goal = (spots['tent'] ?? townEdge) + townRest[f.slot % townRest.length];
      case TownDo.talk:
        _pair(f, mate!);
    }
    f.goal = f.goal.clamp(townEdge, math.max(townEdge, width - townEdge));
  }

  /// A stroll's goal: anywhere along the street.
  double _strollTo() => townEdge + dice.nextDouble() * math.max(0.0, width - 2 * townEdge);

  /// [a] begins a talk with [b]: they meet before the Tavern's right side when no other pair talks there (half the
  /// time), else halfway between them, and stand [townTalkGap] apart.
  void _pair(TownFolk a, TownFolk b) {
    final there = !folk.any((o) => o.doing == TownDo.talk && o.slot == 1) && dice.nextDouble() < 0.5;
    final meet = there ? spots['talk'] ?? width / 2 : (a.x + b.x) / 2;
    final (l, r) = a.x <= b.x ? (a, b) : (b, a);
    for (final (f, other, side) in [(l, r, -1), (r, l, 1)]) {
      f
        ..doing = TownDo.talk
        ..mate = other
        ..lead = identical(f, a)
        ..slot = there ? 1 : 0
        ..until = double.infinity
        ..said = null
        ..thought = false
        ..line = -1
        ..goal = (meet + side * townTalkGap / 2).clamp(townEdge, math.max(townEdge, width - townEdge));
    }
  }

  /// [f] got there: it turns to what it came for and stays; the Tavern takes it inside; a talk begins once both stand.
  void _arrive(TownFolk f) {
    f.from = t;
    switch (f.doing) {
      case TownDo.stroll:
        f.until = t + _roll(townStay[TownDo.stroll]!);
      case TownDo.guard:
        f
          ..dir = f.slot == 0 ? -1 : 1 // out of the Town
          ..until = t + _roll(townStay[TownDo.guard]!);
      case TownDo.shop || TownDo.smithy:
        f
          ..dir = (spots[f.doing.name] ?? f.x) >= f.x ? 1 : -1
          ..until = t + _roll(townStay[f.doing]!);
      case TownDo.tavern:
        f
          ..up = true // up its doorstep, into the doorway; inside after [townDoorway] s ([step])
          ..until = t + townDoorway + _roll(townStay[TownDo.tavern]!) + townDoorway;
      case TownDo.rest:
        final tent = spots['tent'] ?? f.x;
        f
          ..up = f.x - tent >= townTentOpen.$1 && f.x - tent <= townTentOpen.$2 // in the tent's opening: on its floor
          ..dir = tent + townFire >= f.x ? 1 : -1
          ..until = t + _roll(townStay[TownDo.rest]!);
      case TownDo.talk:
        final m = f.mate;
        if (m == null) {
          f.until = t; // its mate is gone: it rolls again
          return;
        }
        f.dir = m.x >= f.x ? 1 : -1;
        if (m.walking) return; // it waits, facing the other coming
        final lines = townTalkLines.$1 + (dice.nextDouble() * (townTalkLines.$2 - townTalkLines.$1 + 1)).floor();
        m.dir = -f.dir;
        for (final o in [f, m]) {
          o
            ..from = t
            ..until = t + lines * townLine;
        }
    }
  }

  /// [f]'s bubble now: a talk's lead rolls each line's icon and puts it over the one saying it, during [townSay] of the
  /// line; a browser thinks of the coins or the hammer for a moment after arriving.
  void _bubble(TownFolk f) {
    switch (f.doing) {
      case TownDo.talk:
        final m = f.mate;
        if (!f.lead) {
          if (m == null) f.said = null;
          return; // the lead sets both
        }
        f.said = null;
        m?.said = null;
        if (m == null || f.walking || m.walking || f.until == double.infinity || t >= f.until) return;
        final since = t - f.from, line = (since / townLine).floor();
        if (line != f.line) {
          f
            ..line = line
            ..topic = townTopics[(dice.nextDouble() * townTopics.length).floor().clamp(0, townTopics.length - 1)];
        }
        if (since - line * townLine < townLine * townSay) (line.isEven ? f : m).said = f.topic;
      case TownDo.shop || TownDo.smithy:
        final there = !f.walking && t - f.from >= townThink.$1 && t - f.from < townThink.$2;
        f
          ..said = there ? (f.doing == TownDo.shop ? TownIcon.coins : TownIcon.hammer) : null
          ..thought = true;
      default:
        f.said = null;
    }
  }
}

/// Each troop type's head in its strips' 100x100 frames (frame px; its feet's last row is [townFeet]): where a bubble's
/// tail points. Mapped from the idle strips, their six frames together (decisions-log 253): x the middle of the head itself
/// (the helmet, hood, hair or hat) between its columns' outer edges; y its crown's top, the first row 5 px wide (a
/// plume or a hat's tip counts, a weapon's tip never: the lancer's lance rises 8 rows over it). Weapons held beside the
/// head are left out of its columns: the lancer's lance (56-58), the axeman's axe (its shaft 54-56, its blade to 62),
/// the wizard's staff (its orb 55-59), the archer's bow (59-60). Until then a rule read off the pixels (the median
/// column of those rows) put the axeman's over its axe, whose blade touches its helmet there.
const townHeads = <String, Offset>{
  'soldier': Offset(50, 39), // its helmet, columns 45-54
  'knight': Offset(48, 39), // its helmet 41-54, the plume 45-47 on top
  'swordsman': Offset(50, 38), // its hair and helmet, 44-55
  'archer': Offset(50, 40), // its hood, 45-54
  'lancer': Offset(49, 27), // its helmet 43-54, the plume's top
  'priest': Offset(50, 37), // its mitre, 44-55
  'armored_axeman': Offset(49.5, 38), // its helmet, 45-53
  'wizard': Offset(49, 38), // its hat and face, 43-54
  'knight_templar': Offset(50, 39), // its helmet, 45-54
};

/// Each troop type's feet in its strips' 100x100 frames: the last row its feet's pixels reach in its idle strip, every
/// frame (decisions-log 292; the owner, 2026-10-09: a priest resting in the tent "still a little up", its feet floating
/// over the tent's hem). Mapped from the idle strips in the body's own columns, 44-55: the weapons held beside it reach
/// lower and are left out (the priest's and the wizard's staff, column 56, to row 57; the swordsman's blade, from column
/// 58, to row 59), and so is the Soldier's baked-in shadow (rows 55-59, cleared at load: `_unshadowed`). All nine stand on
/// row 56 in all six frames. The Town draws a troop with this row's bottom edge on its line ([TownFolk.sx], [TownFolk.sy]:
/// the street at its depth, the tent's hem, the Tavern's sill). Until then it drew every troop with the frame's row 59 on
/// its line (the field's [_feet], where its ground shadow goes), so its soles ended 2 sprite px, 4 world px, over it.
const townFeet = <String, int>{
  'soldier': 56, // its boots, columns 46-54 (its shadow under them to row 59)
  'knight': 56, // its boots, 47-53
  'swordsman': 56, // its boots, 47-53 (its blade's tip to row 59, columns 58-65)
  'archer': 56, // its boots, 47-53
  'lancer': 56, // its horse's hooves, 42-48 and 54-59
  'priest': 56, // its shoes, 47-53 (its staff to row 57, column 56)
  'armored_axeman': 56, // its boots, 47-55
  'wizard': 56, // its robe's hem and shoes, 47-53 (its staff to row 57, column 56)
  'knight_templar': 56, // its boots, 44-55
};

/// A strip's frames (100x100, the Tiny RPG pack's), made once: drawing a troop allocates nothing.
final _townFrames = [for (var i = 0; i < 12; i++) Rect.fromLTWH(i * 100.0, 0, 100, 100)];

/// Where a frame is drawn round its line at 1 screen px a sprite px: its middle column over the line's x, its feet's last
/// row ([townFeet]; a type without one: the field's [_feet]) just over the line. Made once, a rect per type.
final _townBodies = {for (final MapEntry(:key, :value) in townFeet.entries) key: Rect.fromLTWH(-50, -value - 1.0, 100, 100)};
const _townBody = Rect.fromLTWH(-50, -59, 100, 100); // a type without [townFeet]: the field's [_feet] on the line

/// The frame's row whose bottom edge stands on a [type]'s line ([townFeet] + 1; without one, the field's [_feet]).
double townSole(String type) => switch (townFeet[type]) { final row? => row + 1.0, _ => _feet.dy };

/// The bubble frames in ui_all.png (the white speech bubble, the grey thought, 20x24: [townBubbleTip] is where its tail
/// points) and the icon's room inside them.
const _townSaid = Rect.fromLTWH(926, 62, 20, 24), _townThought = Rect.fromLTWH(926, 206, 20, 24);
const _townBubbleAt = Rect.fromLTWH(0, 0, 20, 24), _townIconAt = Rect.fromLTWH(2, 1, 16, 16);
const townBubbleTip = Offset(9.5, 24);

extension _TownLifeLook on Board {
  /// The Town's life's turn in the Board's update: while the Town shows, its troops follow the living army and, unless
  /// the game is paused, go about their errands ([TownLife.step], at most 0.1 s a frame).
  void _townLifeTick(Game g, double dt) {
    if (!_town.shown || !g.inTown) return;
    _townLife.sync(g.units);
    if (!g.paused) _townLife.step(math.min(dt, 0.1));
  }

  /// The troops over the scene's pieces ([_townScene]), in two turns: with [up] those inside on a building's floor
  /// ([TownFolk.up], [TownFolk.floor] over the lane), the street [L] staged on the life first when it changed; then
  /// the rest on the street's strip at their depth under the lane, in front of them. [ox] the street's left on the
  /// screen, [k] screen px a world px, a body [townFolkK]·k a sprite px; its idle or walk strip (the life's clock, the
  /// walk's at [townPace]), facing its way, with no ground shadow (decisions-log 270); after the street's troops the
  /// bubbles over the heads (at max(2, k) a sprite px, to be read), and the Tavern's window's while anyone is inside.
  void _townFolk(Canvas c, _TownLayout L, double ox, double k, {required bool up}) {
    final life = _townLife, v = _town;
    if (up && life.width != L.viewW) life.stage(L.viewW, L.spots);
    final s = k * townFolkK, bk = math.max(2.0, k);
    for (var i = 0; i < life.folk.length; i++) {
      final f = life.folk[i];
      if (f.up != up) continue;
      f
        ..shown = !f.inside && !f.x.isNaN
        ..bw = 0;
      if (!f.shown) continue;
      final fx = (ox + f.x * k).roundToDouble(), fy = (v.lane + (up ? -f.floor : f.depth) * k).roundToDouble();
      final img = _img(f.walking ? f.walk : f.idle), n = img.width ~/ img.height;
      final frame = ((life.t + f.phase) * _fps * (f.walking ? townPace : 1)).floor() % n;
      f
        ..sx = fx
        ..sy = fy;
      c
        ..save()
        ..translate(fx, fy)
        ..scale(f.dir * s, s)
        ..drawImageRect(img, _townFrames[frame], _townBodies[f.unit.type] ?? _townBody, _px)
        ..restore();
    }
    if (up) return; // the bubbles go over everyone, after the street's troops
    for (var i = 0; i < life.folk.length; i++) {
      final f = life.folk[i], icon = f.said;
      if (!f.shown || icon == null) continue;
      // Over its head ([townHeads]: the head's own middle and top, not a lance's tip or an axe's blade).
      final at = townHeads[f.unit.type] ?? const Offset(50, 40);
      final head = f.sy - (townSole(f.unit.type) - at.dy) * s, mid = f.sx + (at.dx - _feet.dx) * s * f.dir;
      _townBubble(c, icon, f.thought, mid, head - bk, bk);
      f
        ..bx = (mid - townBubbleTip.dx * bk).roundToDouble()
        ..by = (head - bk - townBubbleTip.dy * bk).roundToDouble()
        ..bw = 20 * bk
        ..bh = 24 * bk;
    }
    v.window = Rect.zero;
    if (!life.windowBubble) return;
    for (final (name, r) in v.buildings['tavern'] ?? const <(String, Rect)>[]) {
      if (name != 'winTL') continue;
      _townBubble(c, TownIcon.mug, false, r.right, r.top + 2 * k, bk); // its tail on the window's top, in its middle
      v.window = Rect.fromLTWH((r.right - townBubbleTip.dx * bk).roundToDouble(),
          (r.top + 2 * k - townBubbleTip.dy * bk).roundToDouble(), 20 * bk, 24 * bk);
    }
  }

  /// A bubble ([icon] in ui_all.png's speech bubble, or its grey thought) at [bk] screen px a sprite px, its tail's tip
  /// on ([x], [y]).
  void _townBubble(Canvas c, TownIcon icon, bool thought, double x, double y, double bk) {
    c
      ..save()
      ..translate((x - townBubbleTip.dx * bk).roundToDouble(), (y - townBubbleTip.dy * bk).roundToDouble())
      ..scale(bk)
      ..drawImageRect(_img('ui_all.png'), thought ? _townThought : _townSaid, _townBubbleAt, _px)
      ..drawImageRect(_img(icon.file), icon.src, _townIconAt, _px)
      ..restore();
  }
}
