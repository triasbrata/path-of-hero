part of 'main.dart';

// The Dungeon's HUD (decisions-log 336, 337; docs/dungeon-design.md section 3, "The battle HUD"; docs/ui-hud.md
// "Dungeon"), drawn with the game's kit at the HUD's scale ([Board._meterK]): the top left holds what changes slowly
// (the pause button, the target, the minimap, the Wait and Gambits chips), the top right what changes every second (the
// live action panel: a row per unit with an action, its gauge in the row), the bottom the party panel and the Action
// button, with the desk's row of key hints or a touch screen's joystick. The Action chain (M1: step 1 the member, step 2
// the action, Attack only, step 4 its target among the foes on screen) cascades left of the party panel on the desk and
// is one panel across the bottom on a touch screen; time stands still while it is open (Wait), a ribbon says so. At the
// save point a Leave button stands over the campfire. No book inside in M1: its pages are the army's and the Town's,
// set aside for the trip; Esc and the pause button pause.

/// The live action panel's rows at the most: 6 on a screen at least this tall, else 4 (at 915x412 more would cover the
/// fight).
const _dunTallRows = 560.0;

/// ui_icons.png's 16x16 icons the HUD uses besides the field's: the gold pointing hand (the chain's pointer), the bolt
/// (Skill) and the joystick's four white arrows (up, down, left, right).
const _icPoint = Offset(48, 224), _icSkill = Offset(144, 0);
const _icStickArrows = [Offset(208, 128), Offset(208, 160), Offset(192, 144), Offset(224, 144)];

/// ui_bars.png's fill strips (28x3 each): HP green and red, the gauge gold.
const _dunFillGreen = Rect.fromLTWH(66, 7, 28, 3), _dunFillRed = Rect.fromLTWH(2, 7, 28, 3), _dunFillGold = Rect.fromLTWH(2, 11, 28, 3);

/// The HUD's inks on its dark panels: cream words, the actions' gold, a foe's red, the headers' grey, on a lit (orange)
/// row the dark ink and its red; the members' MP blue.
const _dunCream = Color(0xFFFFF1DC), _dunGold = Color(0xFFFFD34A), _dunFoe = Color(0xFFFF9B8A), _dunGrey = Color(0xFFBFA77F),
    _dunInk = Color(0xFF3B2414), _dunInkAct = Color(0xFF6B2A10), _dunInkFoe = Color(0xFF8A2A2A), _dunMp = Color(0xFF6AA0D8);

/// One of the chain's step-2 actions: its word, its icon (a ui_icons.png 16x16, or null: the healing bottle) and whether
/// M1 has it (Attack; Skill and Item come with M2, shown greyed).
typedef _DunAction = ({String word, Offset? icon, bool on});

const _dunActions = <_DunAction>[
  (word: Words.attack, icon: Board._icSword, on: true),
  (word: Words.skill, icon: _icSkill, on: false),
  (word: Words.item, icon: null, on: false),
];

extension _DungeonHud on Board {
  /// What is drawn over the cave: the fade, the pause's dim, the HUD, the message window, the tooltip and the cursor;
  /// none of the field's or the Town's HUD (no book inside in M1), so what took a press there is cleared.
  void _dungeonOver(Canvas c, Game g) {
    _hits.clear();
    _tip.rows.clear();
    _tip.hints.clear();
    _cards.clear();
    _slots.clear();
    _relicSlots.clear();
    _matSlots.clear();
    _pocketCells.clear();
    _plateTaps.clear();
    _bookArea = Rect.zero;
    _pagesAt = (Rect.zero, Rect.zero);
    _dunFadeDim(c);
    _pauseOverlay(c); // pause.dart: dimmed, "Pause", under the HUD
    _dungeonHud(c, g);
    _messageBox(c);
    _coachCard(c);
    _tooltip(c);
    _fpsReadout(c);
    _cursor(c);
  }

  /// The HUD's own scale (sprite px), its words' size and the touch layout's.
  ({double u, double fs, double e, double top, bool touch, bool tall}) get _dunGeom {
    final u = _meterK;
    return (u: u, fs: 6 * u, e: _edgeL, top: _safe.top + 8, touch: _dunTouch, tall: size.y >= _dunTallRows);
  }

  void _dungeonHud(Canvas c, Game g) {
    final d = g.dungeon!, v = _dun, s = _dunGeom, u = s.u;
    final phoneChain = s.touch && v.step > 0;
    // The top left: the pause button, the target, the minimap, the chips.
    final pb = math.max(44.0, 14 * u), pause = Rect.fromLTWH(s.e, s.top, pb, pb);
    final sink = _button(c, pause, _togglePause, into: v.taps);
    final dk = pb * 0.5 / _pauseDash.width, mid = pause.center + Offset(0, sink - 2);
    for (final dx in [-3.5 * dk, 3.5 * dk]) {
      c
        ..save()
        ..translate(mid.dx + dx, mid.dy)
        ..rotate(math.pi / 2);
      c.drawImageRect(_img('ui_icons.png'), _pauseDash, Rect.fromCenter(center: Offset.zero, width: _pauseDash.width * dk, height: _pauseDash.height * dk), _px);
      c.restore();
    }
    v.at['pause'] = pause;
    final lw = (s.touch && !s.tall ? 110 : 120) * u, lx = pause.right + 4 * u;
    final target = _dunTargetPanel(c, g, Rect.fromLTWH(lx, s.top, lw, 15 * u));
    final map = _dunMiniMap(c, g, Rect.fromLTWH(lx, target.bottom + 3 * u, lw, 20 * u));
    _dunChips(c, g, Offset(lx, map.bottom + 3 * u));
    // The top right: the live action panel, as wide as the room right of the target leaves.
    final lpw = math.min(196 * u, size.x - _edgeR - lx - lw - 8 * u);
    _dunLivePanel(c, g, Rect.fromLTWH(size.x - _edgeR - lpw, s.top, lpw, 0));
    // The bottom: the party panel, the Action button and the hints or the joystick; the chain over them.
    if (!phoneChain) {
      final ab = s.touch ? math.max(60.0, 30 * u) : 28 * u, pw = 186 * u, rh = (s.touch ? 13 : 12) * u, ph = 3 * rh + 4 * u;
      final bottom = size.y - _edgeB;
      final party = s.touch
          ? Rect.fromLTWH(size.x - _edgeR - ab - 8 * u - pw, bottom - ph, pw, ph)
          : Rect.fromLTWH(size.x - _edgeR - pw, bottom - ph, pw, ph);
      _dunPartyPanel(c, g, party, rh);
      if (s.touch) {
        final btn = Rect.fromLTWH(size.x - _edgeR - ab, bottom - ab - 8 * u, ab, ab);
        _dunActionButton(c, g, btn, key: false);
        final r = math.max(60.0, 30 * u);
        _dunJoystick(c, Rect.fromLTWH(s.e, bottom - 2 * r, 2 * r, 2 * r));
      } else {
        final btn = Rect.fromLTWH(s.e, bottom - 28 * u - 10 * u, 28 * u, 28 * u);
        _dunActionButton(c, g, btn, key: true);
        if (v.step == 0) _dunHints(c, [Words.hintMove, Words.hintLeader, Words.hintAction, Words.hintGambits, Words.hintPause], Offset(btn.right + 8 * u, btn.center.dy));
      }
    }
    if (g.atSavePoint && v.step == 0) _dunLeave(c, g);
    if (v.step > 0) _dunChain(c, g);
    // The chain's ribbon at the top between the two top panels: time stands still (Wait).
    if (v.step > 0) {
      final rk = math.max(2.0, u - 1), left = map.right + 8 * u, right = v.at['live']!.left - 8 * u;
      v.at['ribbon'] = _ribbonTitle(c, '${Words.pausedStep} ${v.step} ${Words.stepOf} 4', Offset((left + right) / 2, s.top + 10 * rk), rk, right - left);
    }
    // Every control at least the tap rule's 44 px: a smaller part takes a press that big about its middle.
    for (var i = 0; i < v.taps.length; i++) {
      final (r, fn) = v.taps[i];
      v.taps[i] = (Rect.fromCenter(center: r.center, width: math.max(44, r.width), height: math.max(44, r.height)), fn);
    }
    if (d.end != null) v.taps.clear();
  }

  /// ui_bars.png's dark capsule over [r] at [k] (9-sliced 1 px), [frac] of its inside filled with the strip [fill].
  void _dunBar(Canvas c, Rect r, double frac, Rect fill, double k) {
    _nine(c, const Rect.fromLTWH(82, 33, 12, 6), r, k, l: 1, t: 1, r: 1, b: 1, sheet: 'ui_bars.png', seam: 0);
    final f = frac.clamp(0.0, 1.0);
    if (f <= 0) return;
    final inside = Rect.fromLTRB(r.left + k, r.top + k, r.right - k, r.bottom - k);
    c.drawImageRect(_img('ui_bars.png'), Rect.fromLTWH(fill.left, fill.top, math.max(1, fill.width * f), fill.height),
        Rect.fromLTWH(inside.left, inside.top, inside.width * f, inside.height), _px);
  }

  /// One of ui_bars.png's capsules over [r] at [k] ('dark', 'green', 'red' or 'outline'), [label] in it.
  void _dunCapsule(Canvas c, Rect r, String kind, double k, [String label = '', double fs = 12, Color ink = _dunCream]) {
    final src = switch (kind) {
      'green' => const Rect.fromLTWH(2, 65, 12, 6),
      'red' => const Rect.fromLTWH(2, 33, 12, 6),
      'outline' => const Rect.fromLTWH(98, 33, 12, 6),
      _ => const Rect.fromLTWH(82, 33, 12, 6),
    };
    _nine(c, src, r, k, l: 1, t: 1, r: 1, b: 1, sheet: 'ui_bars.png', seam: 0);
    if (label.isNotEmpty) _text(c, _fit(label, fs, r.width - 4 * k), r.center, size: fs, color: ink, anchor: Anchor.center);
  }

  /// A rank's ink: a normal monster's red, an elite's silver, a high elite's gold and so on ([_tierBar]).
  Color _dunRankInk(Unit u) => u.tier == Tier.normal ? _dunFoe : _tierBar[u.tier]!.$1;

  /// The target (top left): the leader's action's target, or the one pointed while the chain's list is open: its name,
  /// its rank in the rank's colour, Hostile, Neutral or Party, and its HP bar (red, a member's green; no numbers).
  Rect _dunTargetPanel(Canvas c, Game g, Rect r) {
    final d = g.dungeon!, s = _dunGeom, u = s.u, fs = s.fs;
    _panel(c, r);
    _dun.at['target'] = r;
    _text(c, Words.target, Offset(r.left + 5 * u, r.top + 4 * u), size: fs * 0.62, color: _dunGrey);
    final t = _dun.step == 4 ? _dunPointed(g) : d.minds[d.leader]?.act?.target;
    final y = r.top + 10.5 * u;
    if (t == null || !t.alive) {
      _text(c, Words.noFoes, Offset(r.left + 5 * u, y), size: fs * 0.9, color: _dunGrey);
      return r;
    }
    final foe = t.side == Side.enemy, bw = 40 * u;
    var x = r.left + 5 * u;
    final name = _fit(_dunName(t), fs, r.width - bw - 30 * u);
    _text(c, name, Offset(x, y), size: fs, color: _dunGold);
    x += _textWidth(name, fs) + 3 * u;
    if (foe && t.tier != Tier.normal) {
      _text(c, tierNames[t.tier]!, Offset(x, y), size: fs * 0.8, color: _dunRankInk(t));
      x += _textWidth(tierNames[t.tier]!, fs * 0.8) + 3 * u;
    }
    final temper = !foe ? Words.party : d.hostile(t) ? Words.hostile : Words.neutral;
    if (x + _textWidth(temper, fs * 0.8) < r.right - bw - 8 * u) {
      _text(c, temper, Offset(x, y), size: fs * 0.8, color: !foe ? const Color(0xFFA8F08A) : d.hostile(t) ? const Color(0xFFFF9B9B) : const Color(0xFFCFE8FF));
    }
    _dunBar(c, Rect.fromLTWH(r.right - 5 * u - bw, r.top + 5 * u, bw, 5 * u), t.hp / t.maxHp, foe ? _dunFillRed : _dunFillGreen, u);
    return r;
  }

  /// The minimap (under the target): "Floor 1" and the floor as a strip of rooms (ui_bars.png's capsules, the rooms the
  /// party has come near lighter), the save point (the campfire), the stairs (the portal), the party (the crown) and the
  /// foes on the floor (red squares).
  Rect _dunMiniMap(Canvas c, Game g, Rect r) {
    final d = g.dungeon!, s = _dunGeom, u = s.u, f = d.floor;
    _panel(c, r);
    _dun.at['minimap'] = r;
    _text(c, '${Words.floor} ${f.number}', Offset(r.left + 5 * u, r.top + 5 * u), size: s.fs * 0.8, color: const Color(0xFFFFE2A8));
    final strip = Rect.fromLTRB(r.left + 5 * u, r.top + 10 * u, r.right - 5 * u, r.bottom - 3 * u);
    double at(double x) => strip.left + strip.width * (x / f.width);
    for (final room in f.rooms) {
      final seen = room.index == 0 || d.called.contains(room.index) || d.leader.pos.x >= room.x0;
      _dunCapsule(c, Rect.fromLTRB(at(room.x0) + u, strip.center.dy - 2.5 * u, at(room.x1) - u, strip.center.dy + 2.5 * u), seen ? 'outline' : 'dark', 1);
    }
    final icon = 8 * u;
    const cf = townCampfireFrame, pf = dungeonPortalFrame;
    c.drawImageRect(_img(townCampfire), const Rect.fromLTWH(0, 0, cf * 1.0, cf * 1.0),
        Rect.fromCenter(center: Offset(at(f.savePoint.x), strip.center.dy - u), width: icon, height: icon), _px);
    c.drawImageRect(_img(dungeonPortal), const Rect.fromLTWH(0, 0, pf * 1.0, pf * 1.0),
        Rect.fromCenter(center: Offset(at(f.portal.x), strip.center.dy - u), width: icon * 1.2, height: icon * 1.2), _px);
    for (final o in g.units) {
      if (o.side != Side.enemy || !o.alive) continue;
      c.drawImageRect(_img('ui_bars.png'), const Rect.fromLTWH(8, 8, 2, 2),
          Rect.fromCenter(center: Offset(at(o.pos.x), strip.center.dy), width: 2 * u, height: 2 * u), _px);
    }
    _uiIcon(c, _icCrown, Rect.fromCenter(center: Offset(at(d.leader.pos.x), strip.center.dy - 0.5 * u), width: 6 * u, height: 6 * u));
    return r;
  }

  /// Under the minimap: the Wait chip (M1's only mode) and the Gambits chip, green while on; a tap switches it.
  void _dunChips(Canvas c, Game g, Offset at) {
    final d = g.dungeon!, s = _dunGeom, u = s.u, fs = s.fs * 0.72, h = 10 * u;
    final wait = Rect.fromLTWH(at.dx, at.dy, _textWidth(Words.wait, fs) + 8 * u, h);
    _dunCapsule(c, wait, 'dark', 1, Words.wait, fs);
    final word = d.gambits ? Words.gambitsOn : Words.gambitsOff;
    final gam = Rect.fromLTWH(wait.right + 3 * u, at.dy, _textWidth(Words.gambitsOff, fs) + 8 * u, h);
    _dunCapsule(c, gam, d.gambits ? 'green' : 'dark', 1, word, fs, d.gambits ? _dunInk : _dunCream);
    _dun
      ..at['wait'] = wait
      ..at['gambits'] = gam
      ..taps.add((gam, g.toggleGambits));
  }

  /// The live action panel (top right): "Now" and a row per unit with an action ([DungeonTrip.liveRows]: the party's,
  /// the leader's first on the orange slot with its crown, then the foes engaged, the soonest to fire first): the cog
  /// when a gambit chose it, the name (a foe's in red or its rank's colour), the action, the play arrow and the target
  /// ("target lost" for a moment when it fell or got away), the gauge at the row's end ("Ready" over it when full); a
  /// queued action on a line under its row ("then Attack Bat"). At most 6 rows (4 on a short screen), then "+2 more".
  void _dunLivePanel(Canvas c, Game g, Rect r) {
    final d = g.dungeon!, s = _dunGeom, u = s.u, fs = s.fs * 0.92, small = fs * 0.8;
    final rows = g.liveRows(), cap = s.tall ? 6 : 4, shown = rows.take(cap).toList(), more = rows.length - shown.length;
    final rh = (s.tall ? 12 : 10) * u, sub = 6 * u, head = 8 * u;
    final h = head + shown.length * rh + shown.where((w) => w.queued != null).length * sub + (more > 0 ? 7 * u : 0) + 3 * u;
    final p = Rect.fromLTWH(r.left, r.top, r.width, math.max(h, head + rh));
    _panel(c, p);
    _dun.at['live'] = p;
    _text(c, Words.now, Offset(p.left + 5 * u, p.top + 4.5 * u), size: fs * 0.65, color: _dunGrey);
    if (rows.isEmpty) return;
    final gw = 30 * u, nameX = p.left + 12 * u, actX = p.left + p.width * 0.36, arrowX = p.left + p.width * 0.56;
    var y = p.top + head;
    for (final (i, w) in shown.indexed) {
      final lead = w.unit == d.leader, foe = w.unit.side == Side.enemy, m = d.minds[w.unit];
      final row = Rect.fromLTWH(p.left + 2 * u, y, p.width - 4 * u, rh + (w.queued != null ? sub : 0));
      if (lead) {
        _slotFrame(c, row, slotOrange, ButtonLook.normal, math.max(1.0, u - 1));
        _dun.at['lit:live'] = row;
      }
      _dun.at['row:$i'] = row;
      final mid = y + rh * 0.5;
      if (w.act?.byGambit ?? false) _uiIcon(c, Board._icGear, Rect.fromLTWH(p.left + 3 * u, mid - 4 * u, 8 * u, 8 * u));
      var x = nameX;
      if (lead) {
        _uiIcon(c, _icCrown, Rect.fromLTWH(x, mid - 3.5 * u, 7 * u, 7 * u));
        x += 8 * u;
      }
      final nameInk = foe ? _dunRankInk(w.unit) : (lead ? _dunInk : _dunCream);
      _text(c, _fit(_dunName(w.unit), fs, actX - x - 3 * u), Offset(x, mid), size: fs, color: nameInk);
      if (w.act case final a?) {
        _text(c, _fit(_dunActWord(a.kind), fs, arrowX - actX - 3 * u), Offset(actX, mid), size: fs, color: lead ? _dunInkAct : _dunGold);
        _uiIcon(c, _startIcon, Rect.fromLTWH(arrowX - 2 * u, mid - 4 * u, 8 * u, 8 * u), lead ? _dunDarkPaint : null);
        final tx = arrowX + 6 * u, room = p.right - 5 * u - gw - 4 * u - tx;
        if (a.target case final t?) {
          final tFoe = t.side == Side.enemy;
          _text(c, _fit(_dunName(t), fs, room), Offset(tx, mid), size: fs,
              color: lead ? (tFoe ? _dunInkFoe : _dunInk) : (tFoe && !foe ? _dunFoe : _dunCream));
        }
      } else if (w.lost) {
        _text(c, _fit(Words.targetLost, small, arrowX + 40 * u - actX), Offset(actX, mid), size: small, color: lead ? _dunInkFoe : _dunFoe);
      }
      // The gauge: ui_bars.png's dark capsule, its gold strip; "Ready" over it when full.
      final gauge = Rect.fromLTWH(p.right - 5 * u - gw, mid - 2.5 * u, gw, 5 * u);
      _dunBar(c, gauge, w.gauge, _dunFillGold, u);
      if ((m?.full ?? false) && w.act != null) {
        _text(c, Words.ready, gauge.center, size: small, color: const Color(0xFFFFF7D6), anchor: Anchor.center, outline: const Color(0xFF3B1D08));
      }
      y += rh;
      if (w.queued case final q?) {
        _uiIcon(c, _startIcon, Rect.fromLTWH(actX - 1 * u, y + sub / 2 - 2.5 * u, 5 * u, 5 * u), lead ? _dunDarkPaint : null);
        final then = '${Words.then} ${_dunActWord(q.kind)} ${q.target == null ? '' : _dunName(q.target!)}';
        _text(c, _fit(then, small, p.right - 6 * u - actX - 6 * u), Offset(actX + 6 * u, y + sub / 2), size: small,
            color: lead ? const Color(0xFF1D4F88) : const Color(0xFFCFE8FF));
        y += sub;
      }
    }
    if (more > 0) {
      final line = '+$more ${Words.more}';
      _text(c, line, Offset(nameX, y + 3.5 * u), size: small, color: _dunGrey);
      _dun.at['more'] = Rect.fromLTWH(nameX, y, _textWidth(line, small), 7 * u);
    }
  }

  /// An action's word on the HUD.
  String _dunActWord(ActKind k) => switch (k) { ActKind.attack => Words.attack, ActKind.heal => Words.heal, ActKind.follow => Words.follow };

  /// The party panel (the bottom right; on a touch screen between the joystick and the Action button): a row per
  /// member, its current action right-aligned ("Follow" when it has none), the cog when a gambit chose it, the crown
  /// before the leader's name, HP now/most and MP; a member knocked out greyed. The leader's row is on the orange slot,
  /// and in the chain's step 1 the pointed one with the pointing hand. On the desk a click on a row makes that member
  /// the leader (in step 1 it picks it); on a touch screen its rows are only read.
  void _dunPartyPanel(Canvas c, Game g, Rect r, double rh) {
    final d = g.dungeon!, v = _dun, s = _dunGeom, u = s.u, fs = s.fs * 0.9;
    _panel(c, r);
    v.at['party'] = r;
    final members = d.party, picking = v.step == 1 && !s.touch;
    final pointed = picking ? _dunMembers(g).elementAtOrNull(v.point) : null;
    for (final (i, m) in members.indexed) {
      final row = Rect.fromLTWH(r.left + 2 * u, r.top + 2 * u + i * rh, r.width - 4 * u, rh - u);
      final up = d.standing(m), lit = picking ? m == pointed : m == d.leader && v.step == 0;
      if (lit) {
        _slotFrame(c, row, slotOrange, ButtonLook.normal, math.max(1.0, u - 1));
        v.at['lit:party'] = row;
      }
      if (lit && picking) _uiIcon(c, _icPoint, Rect.fromLTWH(r.left - 12 * u, row.center.dy - 6 * u, 12 * u, 12 * u));
      v.at['member:$i'] = row;
      final mid = row.center.dy - u / 2, ink = !up ? _dunGrey : lit ? _dunInk : _dunCream;
      final mind = d.minds[m], act = mind?.act;
      final word = !up ? '' : act == null ? Words.follow : _dunActWord(act.kind);
      final ax = r.left + 46 * u;
      _text(c, _fit(word, fs, 42 * u), Offset(ax, mid), size: fs, color: lit ? _dunInkAct : const Color(0xFFFFE9A8), anchor: Anchor.centerRight);
      if (act?.byGambit ?? false) _uiIcon(c, Board._icGear, Rect.fromLTWH(ax + 2 * u, mid - 4 * u, 8 * u, 8 * u));
      var nx = ax + 12 * u;
      if (m == d.leader) {
        _uiIcon(c, _icCrown, Rect.fromLTWH(nx - u, mid - 3.5 * u, 7 * u, 7 * u));
        nx += 7 * u;
      }
      final hx = r.left + 112 * u, mx = r.left + 154 * u;
      _text(c, _fit(m.name, fs, hx - 3 * u - nx), Offset(nx, mid), size: fs, color: ink);
      _text(c, Words.hp, Offset(hx, mid), size: fs * 0.8, color: lit ? _dunInkFoe : const Color(0xFFC86A6A));
      _text(c, '${m.hp.ceil()}/${m.maxHp}', Offset(mx - 4 * u, mid), size: fs, color: ink, anchor: Anchor.centerRight);
      _text(c, Words.mp, Offset(mx, mid), size: fs * 0.8, color: lit ? const Color(0xFF1D4F88) : _dunMp);
      _text(c, '${m.mp.floor()}', Offset(r.right - 5 * u, mid), size: fs, color: ink, anchor: Anchor.centerRight);
      if (!s.touch && up) {
        v.taps.add((row, () => picking ? _dunPickMember(g, m) : g.lead(m)));
      }
    }
  }

  /// The Action button: the orange slot with ui_icons.png's crossed swords; on the desk with its key ("Enter") in a
  /// capsule over its corner, "Action" under it; a tap opens the chain at step 1.
  void _dunActionButton(Canvas c, Game g, Rect r, {required bool key}) {
    final s = _dunGeom, u = s.u, look = _look(r);
    final sink = _slotFrame(c, r, slotOrange, look == ButtonLook.disabled ? ButtonLook.normal : look, math.max(1.0, u - 1));
    _uiIcon(c, Board._icSwords, Rect.fromCenter(center: r.center + Offset(0, sink - 2 * u), width: r.width * 0.58, height: r.width * 0.58));
    if (key) _dunCapsule(c, Rect.fromLTWH(r.center.dx - 2 * u, r.bottom - 9 * u, 20 * u, 8 * u), 'dark', 1, Words.enter, s.fs * 0.6, const Color(0xFFFFE9A8));
    _text(c, Words.action, Offset(r.center.dx, r.bottom + 4.5 * u), size: s.fs * 0.8, anchor: Anchor.center, outline: const Color(0xFF24160C));
    _dun
      ..at['action'] = r
      ..taps.add((r, () => _dunChainOpen(g)));
  }

  /// The desk's row of key hints from [at] (its left, its middle's height): dark capsules.
  void _dunHints(Canvas c, List<String> hints, Offset at) {
    final s = _dunGeom, u = s.u, fs = s.fs * 0.66, h = 10 * u;
    var x = at.dx;
    for (final (i, t) in hints.indexed) {
      final r = Rect.fromLTWH(x, at.dy - h / 2, _textWidth(t, fs) + 8 * u, h);
      if (r.right > size.x - _edgeR) break;
      _dunCapsule(c, r, 'dark', 1, t, fs);
      _dun.at['hint:$i'] = r;
      x = r.right + 3 * u;
    }
  }

  /// The joystick (a touch screen's, bottom left): ui_all.png's tan slot with ui_icons.png's four arrows round its middle
  /// and the orange knob, pushed toward the finger while one holds it ([_DungeonView.stickAt]).
  void _dunJoystick(Canvas c, Rect r) {
    final s = _dunGeom, u = s.u, v = _dun, rr = r.width / 2;
    _slotFrame(c, r, slotTan, ButtonLook.normal, math.max(1.0, u - 1));
    for (final (i, dir) in [const Offset(0, -1), const Offset(0, 1), const Offset(-1, 0), const Offset(1, 0)].indexed) {
      _uiIcon(c, _icStickArrows[i], Rect.fromCenter(center: r.center + dir * (rr - 9 * u), width: 10 * u, height: 10 * u));
    }
    var knob = r.center;
    if (v.stickMid != null && v.stickAt != null) {
      final p = v.stickAt! - v.stickMid!, len = p.distance, most = rr * 0.45;
      knob += len > most ? p * (most / len) : p;
    }
    _slotFrame(c, Rect.fromCenter(center: knob, width: 18 * u, height: 19 * u), slotOrange, ButtonLook.normal, math.max(1.0, u - 1));
    v.at['joystick'] = r;
  }

  /// At the save point with no monster hostile: the bevelled green Leave button over the campfire; a tap goes back to
  /// the Town.
  void _dunLeave(Canvas c, Game g) {
    final d = g.dungeon!, s = _dunGeom, u = s.u, h = math.max(44.0, 14 * u), fs = s.fs;
    final fire = _dunScreen(math.Point(d.floor.savePoint.x, d.floor.savePoint.y - 30));
    final w = _textWidth(Words.leave, fs) + 16 * u;
    final r = Rect.fromLTWH((fire.dx - w / 2).clamp(_edgeL, size.x - _edgeR - w), fire.dy - h, w, h);
    _button(c, r, () => g.leaveDungeon(), label: Words.leave, size: fs, row: Board._btnGreen, into: _dun.taps);
    _dun.at['leave'] = r;
  }

  // ---- the Action chain --------------------------------------------------------------------------------------------

  /// The members the chain's step 1 lists: the standing ones, in the party's order.
  List<Unit> _dunMembers(Game g) => g.dungeon!.standingParty;

  /// The foes the chain's step 4 lists: the monsters on the screen, standing, nearest the chain's member first.
  List<Unit> _dunFoes(Game g) {
    final d = g.dungeon!, from = (_dun.who ?? d.leader).pos;
    return [
      for (final u in g.units)
        if (u.side == Side.enemy && u.alive && u.dying < 0 && u.pos.x >= d.cam && u.pos.x <= d.cam + d.viewW) u,
    ]..sort((a, b) => a.pos.distanceTo(from).compareTo(b.pos.distanceTo(from)));
  }

  /// The foe pointed in step 4.
  Unit? _dunPointed(Game g) => _dun.step == 4 ? _dunFoes(g).elementAtOrNull(_dun.point) : null;

  /// Opens the chain at step 1, the pointer on the leader (Enter, Space, the Action button).
  void _dunChainOpen(Game g) {
    final d = g.dungeon;
    if (d == null || d.end != null || g.paused) return;
    final up = _dunMembers(g);
    if (up.isEmpty) return;
    _dun
      ..step = 1
      ..who = null
      ..point = math.max(0, up.indexOf(d.leader));
  }

  void _dunChainClose() => _dun
    ..step = 0
    ..who = null
    ..point = 0;

  /// The pointer moves [by] rows in the open step's list, wrapping round; step 2's greyed actions are skipped.
  void _dunPointBy(Game g, int by) {
    final v = _dun;
    final n = switch (v.step) { 1 => _dunMembers(g).length, 4 => _dunFoes(g).length, _ => _dunActions.length };
    if (n == 0) return;
    var p = v.point;
    for (var i = 0; i < n; i++) {
      p = (p + by) % n;
      if (v.step != 2 || _dunActions[p].on) break;
    }
    v.point = p;
  }

  /// Enter on the pointed row: step 1 picks the member, step 2 the action (Attack: on to its target, none on screen says
  /// so), step 4 gives the member the Attack on the pointed foe (the 75% rule) and shuts the chain.
  void _dunPick(Game g) {
    final v = _dun;
    switch (v.step) {
      case 1:
        if (_dunMembers(g).elementAtOrNull(v.point) case final m?) _dunPickMember(g, m);
      case 2:
        _dunPickAction(g, v.point);
      case 4:
        if (_dunFoes(g).elementAtOrNull(v.point) case final foe?) _dunPickFoe(g, foe);
    }
  }

  void _dunPickMember(Game g, Unit m) => _dun
    ..who = m
    ..step = 2
    ..point = 0;

  void _dunPickAction(Game g, int i) {
    if (!_dunActions[i].on) return;
    final foes = _dunFoes(g);
    if (foes.isEmpty) return showMessage(Words.noFoes);
    final now = g.dungeon!.minds[_dun.who]?.act?.target;
    _dun
      ..step = 4
      ..point = math.max(0, foes.indexOf(now ?? foes.first));
  }

  void _dunPickFoe(Game g, Unit foe) {
    final who = _dun.who;
    if (who != null) g.command(who, ActKind.attack, foe);
    _dunChainClose();
  }

  /// Esc or Backspace (or the Back button): a step back; from the first the chain shuts.
  void _dunBack() {
    final v = _dun, g = state;
    switch (v.step) {
      case 4:
        v
          ..step = 2
          ..point = 0;
      case 2:
        v
          ..step = 1
          ..point = math.max(0, _dunMembers(g).indexOf(v.who ?? g.dungeon!.leader));
      default:
        _dunChainClose();
    }
  }

  /// The chain's open step: on the desk its cards cascade left of the party panel (step 1 is the party panel itself),
  /// with the chain's keys over them; on a touch screen one card across the bottom, its question at its top and a Back
  /// button at its top right.
  void _dunChain(Canvas c, Game g) {
    final v = _dun, s = _dunGeom, u = s.u, fs = s.fs, ck = math.max(1.0, u - 1);
    final who = v.who, foes = v.step == 4 ? _dunFoes(g) : const <Unit>[];
    if (v.step == 4 && foes.isEmpty) return _dunBack(); // the last foe went: back to the actions
    v.point = v.point.clamp(0, math.max(0, (v.step == 1 ? _dunMembers(g).length : v.step == 4 ? foes.length : 3) - 1)).toInt();
    if (s.touch) return _dunPhoneChain(c, g, foes);
    final party = v.at['party']!, bottom = size.y - _edgeB;
    var x = party.left - 10 * u;
    if (v.step >= 2 && who != null) {
      final w = 64 * u, h = 16 * u + _dunActions.length * 17 * u, r = Rect.fromLTWH(x - w, bottom - h, w, h);
      _nine(c, Board._framePlain, r, ck);
      _text(c, _fit(who.name, fs, w - 12 * u), Offset(r.left + 6 * u, r.top + 8 * u), size: fs, color: const Color(0xFF5A3A22), bold: true);
      for (final (i, a) in _dunActions.indexed) {
        final t = Rect.fromLTWH(r.left + 6 * u, r.top + 14 * u + i * 17 * u, w - 12 * u, 15 * u);
        _dunActionTile(c, t, a, i, pointed: i == v.point && v.step == 2, picked: v.step == 4 && i == 0, wide: true);
      }
      v.at['card:action'] = r;
      x = r.left - 6 * u;
    }
    if (v.step == 4) {
      final w = 108 * u, room = bottom - (v.at['live']?.bottom ?? 0) - 8 * u - 34 * u, most = math.max(1, (room / (16 * u)).floor());
      final n = math.min(foes.length, most), first = (v.point - n + 1).clamp(0, math.max(0, foes.length - n)).toInt();
      final h = 34 * u + n * 16 * u, r = Rect.fromLTWH(x - w, bottom - h, w, h);
      _nine(c, Board._framePlain, r, ck);
      _text(c, '${Words.attack}: ${Words.onWhom}', Offset(r.left + 6 * u, r.top + 8 * u), size: fs, color: const Color(0xFF5A3A22), bold: true);
      for (var j = 0; j < n; j++) {
        final i = first + j, t = Rect.fromLTWH(r.left + 6 * u, r.top + 14 * u + j * 16 * u, w - 12 * u, 14 * u);
        _dunFoeRow(c, g, t, foes[i], i, pointed: i == v.point);
      }
      _dunTabs(c, Rect.fromLTWH(r.left + 7 * u, r.bottom - 15 * u, w - 14 * u, 11 * u));
      v.at['card:target'] = r;
    }
    // The chain's keys over its cards, the Action button and the party panel (the mockup's row above the cards).
    final over = [party, ?v.at['action'], ?v.at['card:action'], ?v.at['card:target']].map((r) => r.top).reduce(math.min);
    _dunHints(c, [Words.hintUpDown, Words.hintPick, Words.hintBack], Offset(_edgeL, over - 4 * u - 5 * u));
  }

  /// One of step 2's actions over [t]: the tan slot (the pointed one orange with the hand, a greyed one white), its icon
  /// and word; a tap picks it.
  void _dunActionTile(Canvas c, Rect t, _DunAction a, int i, {required bool pointed, bool picked = false, required bool wide}) {
    final s = _dunGeom, u = s.u, ck = math.max(1.0, u - 1), lit = pointed || picked;
    _slotFrame(c, t, lit ? slotOrange : (a.on ? slotTan : slotWhite), ButtonLook.normal, ck);
    final isz = wide ? 10 * u : t.height * 0.5;
    final ib = wide ? Rect.fromLTWH(t.left + 4 * u, t.center.dy - isz / 2 - u, isz, isz) : Rect.fromLTWH(t.center.dx - isz / 2, t.top + 3 * u, isz, isz);
    final faded = a.on ? null : _ghost;
    if (a.icon case final ic?) {
      _uiIcon(c, ic, ib, faded);
    } else {
      c.drawImageRect(_img('pocket_healBottle.png'), const Rect.fromLTWH(0, 0, 32, 32), ib, faded ?? _px);
    }
    final ink = a.on ? _dunInk : const Color(0xFF7D7A80);
    if (wide) {
      _text(c, a.word, Offset(ib.right + 4 * u, t.center.dy - u), size: s.fs * 0.95, color: ink);
    } else {
      _text(c, a.word, Offset(t.center.dx, t.bottom - 7 * u), size: s.fs, color: ink, anchor: Anchor.center);
    }
    if (pointed) _uiIcon(c, _icPoint, Rect.fromLTWH(t.left - 9 * u, t.center.dy - 6 * u, 12 * u, 12 * u));
    _dun.at['action:$i'] = t;
    if (a.on) _dun.taps.add((t, () => _dunPickAction(state, i)));
  }

  /// One of step 4's foes over [t]: the slot (the pointed one orange with the hand), its name in its rank's ink, its
  /// rank, Hostile or Neutral; a tap gives the Attack on it.
  void _dunFoeRow(Canvas c, Game g, Rect t, Unit foe, int i, {required bool pointed}) {
    final d = g.dungeon!, s = _dunGeom, u = s.u, fs = s.fs * 0.9;
    _slotFrame(c, t, pointed ? slotOrange : slotTan, ButtonLook.normal, math.max(1.0, u - 1));
    final temper = d.hostile(foe) ? Words.hostile : Words.neutral, rank = foe.tier == Tier.normal ? '' : '${tierNames[foe.tier]} ';
    final right = '$rank$temper', rw = _textWidth(right, fs * 0.75);
    _text(c, _fit(_dunName(foe), fs, t.width - rw - 14 * u), Offset(t.left + 5 * u, t.center.dy - u / 2), size: fs, color: _dunInk);
    _text(c, right, Offset(t.right - 4 * u, t.center.dy - u / 2), size: fs * 0.75, color: foe.tier == Tier.normal ? const Color(0xFF6B4A30) : _dunInkFoe, anchor: Anchor.centerRight);
    if (pointed) _uiIcon(c, _icPoint, Rect.fromLTWH(t.left - 9 * u, t.center.dy - 6 * u, 12 * u, 12 * u));
    _dun.at['foe:$i'] = t;
    _dun.taps.add((t, () {
      if (_dun.point == i || _dunTouch) return _dunPickFoe(g, foe);
      _dun.point = i;
    }));
  }

  /// Step 4's two tabs over [r]: Foes (on, the red capsule) and Party (M2's, greyed).
  void _dunTabs(Canvas c, Rect r) {
    final s = _dunGeom, u = s.u, w = (r.width - 3 * u) / 2;
    _dunCapsule(c, Rect.fromLTWH(r.left, r.top, w, r.height), 'red', 1, Words.foes, s.fs * 0.8);
    _dunCapsule(c, Rect.fromLTWH(r.left + w + 3 * u, r.top, w, r.height), 'outline', 1, Words.party, s.fs * 0.8, const Color(0xFF8E8A86));
    _dun.at['tabs'] = r;
  }

  /// The touch screen's chain: one card across the bottom, its question at its top ("Who?", "Kira Thorn: what?", "Attack:
  /// on whom?"), a Back button (44 px) at its top right; step 1 the members as 44 px rows (the action, HP, MP and the
  /// turn's gauge), step 2 the three actions as tiles, step 4 the foes in two columns of 44 px rows.
  void _dunPhoneChain(Canvas c, Game g, List<Unit> foes) {
    final d = g.dungeon!, v = _dun, s = _dunGeom, u = s.u, fs = s.fs, ck = math.max(1.0, u - 1);
    final rh = math.max(44.0, 22 * u), gap = 2 * u, x = _edgeL, w = size.x - _edgeL - _edgeR;
    final members = _dunMembers(g);
    final rowsN = switch (v.step) { 1 => members.length, 4 => math.min(3, (foes.length / 2).ceil()), _ => 1 };
    final body = v.step == 2 ? math.max(88.0, 44 * u) : rowsN * (rh + gap);
    final h = 16 * u + math.max(rh, 14 * u) + body - rh + 8 * u, r = Rect.fromLTWH(x, size.y - _edgeB - h, w, h);
    _nine(c, Board._framePlain, r, ck);
    v.at['card'] = r;
    final title = switch (v.step) { 1 => Words.who, 2 => '${v.who?.name ?? ''}: ${Words.what}', _ => '${Words.attack}: ${Words.onWhom}' };
    _text(c, title, Offset(r.left + 7 * u, r.top + 9 * u), size: fs, color: const Color(0xFF5A3A22), bold: true);
    // Back: a light slot with the big white left arrow, at the card's top right.
    final bw = math.max(80.0, 40 * u), bh = 44.0, back = Rect.fromLTWH(r.right - bw - 5 * u, r.top + 3 * u, bw, bh);
    _slotFrame(c, back, slotTan, _look(back), ck);
    _uiIcon(c, const Offset(96, 128), Rect.fromLTWH(back.left + 4 * u, back.center.dy - 6 * u, 10 * u, 10 * u));
    _text(c, Words.back, Offset(back.right - 5 * u, back.center.dy - u), size: fs * 0.8, color: _dunInk, anchor: Anchor.centerRight);
    v
      ..at['back'] = back
      ..taps.add((back, _dunBack));
    final top = math.max(r.top + 16 * u, back.bottom + 2 * u);
    switch (v.step) {
      case 1:
        for (final (i, m) in members.indexed) {
          final t = Rect.fromLTWH(r.left + 12 * u, top + i * (rh + gap), r.width - 24 * u, rh);
          _slotFrame(c, t, i == v.point ? slotOrange : slotTan, ButtonLook.normal, ck);
          var nx = t.left + 6 * u;
          if (m == d.leader) {
            _uiIcon(c, _icCrown, Rect.fromLTWH(nx, t.center.dy - 4.5 * u, 8 * u, 8 * u));
            nx += 10 * u;
          }
          _text(c, m.name, Offset(nx, t.center.dy - u), size: fs, color: _dunInk);
          final act = d.minds[m]?.act;
          _text(c, act == null ? Words.follow : _dunActWord(act.kind), Offset(t.left + t.width * 0.42, t.center.dy - u), size: fs * 0.85, color: const Color(0xFF6B4A30));
          // The turn's gauge at the row's end, HP and MP before it.
          final gauge = Rect.fromLTWH(t.right - 6 * u - 34 * u, t.center.dy - 3 * u, 34 * u, 5 * u);
          _dunBar(c, gauge, d.minds[m]?.shown ?? 0, _dunFillGold, u);
          _text(c, '${Words.hp} ${m.hp.ceil()}/${m.maxHp}   ${Words.mp} ${m.mp.floor()}', Offset(gauge.left - 6 * u, t.center.dy - u), size: fs * 0.85,
              color: _dunInk, anchor: Anchor.centerRight);
          v.at['member:$i'] = t;
          v.taps.add((t, () => _dunPickMember(g, m)));
        }
      case 2:
        final n = _dunActions.length, tw = (r.width - 24 * u - (n - 1) * 3 * u) / n, th = body - 4 * u;
        for (final (i, a) in _dunActions.indexed) {
          _dunActionTile(c, Rect.fromLTWH(r.left + 12 * u + i * (tw + 3 * u), top, tw, th), a, i, pointed: false, wide: false);
        }
      case 4:
        _dunTabs(c, Rect.fromLTWH(back.left - 3 * u - 76 * u, r.top + 5 * u, 74 * u, math.max(20.0, 10 * u)));
        final cw = (r.width - 24 * u - 3 * u) / 2, n = math.min(foes.length, 6), first = ((v.point ~/ 6) * 6).clamp(0, math.max(0, foes.length - n)).toInt();
        for (var j = 0; j < n && first + j < foes.length; j++) {
          final i = first + j, t = Rect.fromLTWH(r.left + 12 * u + (j % 2) * (cw + 3 * u), top + (j ~/ 2) * (rh + gap), cw, rh);
          _dunFoeRow(c, g, t, foes[i], i, pointed: i == v.point);
        }
    }
  }
}

/// The dark ink for the play arrow on a lit row: ui_icons.png's white arrow darkened.
final _dunDarkPaint = Paint()
  ..filterQuality = FilterQuality.none
  ..colorFilter = const ColorFilter.mode(_dunInkAct, BlendMode.srcIn);
