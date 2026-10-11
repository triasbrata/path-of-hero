part of 'main.dart';

// One troop type's cell on the Army page's grid (decisions-log 187, its look 198, a cell since 218; ui-hud.md "Army"),
// drawn inside the cell's rect [r] and nothing else, so the book and the guide's pictures can place cells anywhere. The
// owner (2026-10-04): two columns "jadi spritenya bisa lebih besar dan jangan sampai ada box in box". One paper card, the
// Bag slot's (ui_all.png's page frame), lit cream and orange while it is the picked type, darker and grey while Oath of
// One bars the type; on it the idle sprite standing on the card (no well, no frame), outlined in its awakening colour;
// under it the name and how many live ("x3/8" with the type caps on, red at the cap or while barred: decisions-log 201),
// small; a Hero's crown at its top right and the bound Artifact's icon at its top left. No price and no Release on a
// cell: Buy and Release are the detail's (troop_detail.dart), where the picked type is.
//
// Release (Lepas jenis, [Game.releaseType], decisions-log 141) takes two taps, like #91's: the detail's Release arms it
// ([_Release]) and the detail's action row becomes a red confirm, "Send Templar home?" over "13 go home, +12k gold"; a tap
// on it sends the type's troops home for part of their price, any other tap lets it go. Greyed while it can't
// ([Game.whyNotRelease]: mid-wave, a Hero of it lives), and a tap then says why.

/// ui_icons.png: the full heart (HP), the lightning bolt (MP, tinted blue), the full and the empty star; the red
/// forbidden sign (a full or barred type's Buy).
const _heartIcon = Rect.fromLTWH(0, 0, 16, 16), _boltIcon = Rect.fromLTWH(144, 0, 16, 16);
const _starIcon = Rect.fromLTWH(48, 0, 16, 16), _emptyStarIcon = Rect.fromLTWH(80, 0, 16, 16);
const _forbidIcon = Rect.fromLTWH(208, 80, 16, 16);

/// ui_bars.png's green capsule (the full HP bar's, 12x6: a 1-px outline, cut corners, a darker bottom row): a step tag
/// ([_TagLook.go]); the red one beside it (the monsters' full HP bar's): an armed tag ([_TagLook.armed], decisions-log 202).
const _greenCapsule = Rect.fromLTWH(2, 65, 12, 6), _redCapsule = Rect.fromLTWH(2, 33, 12, 6);

/// A refused tag: the green capsule in grey, lighter (as the greyed buttons' white); under the mouse the tags a little
/// lighter.
final _greyTagPaint = Paint()
  ..filterQuality = FilterQuality.none
  ..colorFilter = const ColorFilter.matrix(<double>[
    0.17, 0.57, 0.06, 0, 50, //
    0.17, 0.57, 0.06, 0, 50, //
    0.17, 0.57, 0.06, 0, 50, //
    0, 0, 0, 1, 0, //
  ]);
final _lightTagPaint = Paint()
  ..filterQuality = FilterQuality.none
  ..colorFilter = const ColorFilter.matrix(<double>[
    1, 0, 0, 0, 30, //
    0, 1, 0, 0, 30, //
    0, 0, 1, 0, 30, //
    0, 0, 0, 1, 0, //
  ]);

/// A type Oath of One bars: its cell's card a darker, greyer paper, rim and corners (the Bag slot's recoloured,
/// [_bagSlotPaint]).
final _rowLockedPaint = _bagSlotPaint(const Color(0xFFD8C8B8), const Color(0xFFB09C88), const Color(0xFF86725F));

final _mpPaint = Paint()
  ..filterQuality = FilterQuality.none
  ..colorFilter = _tint(const Color(0xFF4DA6FF));
final _faintPaint = Paint()
  ..filterQuality = FilterQuality.none
  ..color = const Color(0x55FFFFFF);

/// Release on the Army page between frames: the type whose Release was tapped once (null: none) and where its confirm's
/// tap is on the right page (its press area; Rect.zero: none).
class _Release {
  String? armed;
  Rect confirm = Rect.zero;

  void clear() => confirm = Rect.zero;
}

/// The armed Release's confirm words ([Board._confirmWords]): its one or two lines, their sizes, the widest's width.
typedef _ConfirmWords = ({List<String> lines, double f1, double f2, double width});

/// A type's stats as the right page shows them: HP and MP (no item), then each stat beside the item that raises it
/// (the attack beside the staff instead of the sword for the casters, [powerItem]).
final _rowStats = <(Item?, num Function(Stats))>[
  (null, (s) => s.hp),
  (null, (s) => s.mp),
  (Item.shield, (s) => s.def),
  (Item.sword, (s) => s.dmg),
  (Item.bow, (s) => s.range),
  (Item.boots, (s) => s.speed),
  (Item.gloves, (s) => math.max(minAttackInterval, s.rate)), // what it attacks at: never under the floor (#71)
  (Item.potion, (s) => s.regen),
];

extension on Board {
  /// Draws troop [type]'s cell in [r] (clipped to [clip], the page) at [k] screen px per sprite px (the book's pixel
  /// scale), lit while it is the [picked] type. Registers the cell ([_cards]) and its tooltips (a Hero's crown, the bound
  /// Artifact's icon: [Board.pusakaBadge]).
  void _typeCell(Canvas c, Game g, String type, Rect r, double ts, Rect clip, {bool picked = false, double k = 1}) {
    const ink = Color(0xFF4A2C17);
    final level = g.awakenLevel(type), locked = g.typeLocked(type);
    r = _whole(r);
    final inset = 2 * k, band = armyCellBand(ts);

    // The card (the Bag's paper slot, decisions-log 198): lit under the mouse and sunk a sprite px while pressed, as the
    // Bag's slots; the picked type's lit in the pick's cream and orange and stays as it is (a tap on it again does
    // nothing); a type Oath of One bars darker and grey.
    final look = picked || dragAt != null ? ButtonLook.normal : _look(r);
    final sink = look == ButtonLook.pressed ? k : 0.0, at = r.translate(0, sink), inner = at.deflate(inset);
    _bagSlot(c, at, k,
        frame: picked || look == ButtonLook.hover || look == ButtonLook.pressed ? Board._frameLit : Board._framePlain,
        paint: picked ? _bagPickPaint : (locked ? _rowLockedPaint : null));
    if (r.overlaps(clip)) _cards.add((r.intersect(clip), type));

    // The idle sprite standing on the card over the name's line, as big as the cell allows, outlined in its awakening
    // colour; faded while Oath of One bars the type.
    final box = Rect.fromLTRB(inner.left, inner.top, inner.right, inner.bottom - band - k), b = _idleBounds[type]!;
    final s = math.min(box.width / b.width, box.height / b.height);
    c.save();
    c.translate(box.center.dx, box.bottom);
    c.scale(s);
    _frame(c, 'book_${type}_idle', (_clock * _fps).floor(), Offset.zero, anchor: Offset(b.center.dx, b.bottom),
        paint: locked ? _ghost : _px, line: _awakeLine(level, ghost: locked));
    c.restore();
    // The marks in the top corners, the size of the name's line: the crown while a Hero of it lives (hero.dart), the
    // bound Artifact's icon, faded while it sleeps.
    final m = math.min(band + 2 * k, (box.height * 0.4).roundToDouble());
    _heroMark(c, g, type, Rect.fromLTWH(inner.right - m * 2.5, inner.top, m * 2.5, m * 2.5), clip);
    if (g.pusakaOf(type) case final relic?) {
      final to = Rect.fromLTWH(inner.left, inner.top, m, m);
      _icon(c, relic, to, g.pusakaAsleep(relic) ? _ghost : null);
      _pusakaMark(c, g, type, to, clip);
    }

    // The name on the left of the line under it, how many live on its right ([_rowCount]), small.
    final fs = math.max(10.0, 14 * ts), countFs = math.max(10.0, 12 * ts), y = inner.bottom - band / 2;
    final (count, countInk) = _rowCount(g, type);
    final countW = count.isEmpty ? 0.0 : _textWidth(count, countFs), name = _fit(troopTypeNames[type]!, fs, inner.width - countW - 3 * k);
    _text(c, name, Offset(inner.left, y), size: fs, color: ink);
    if (count.isNotEmpty) _text(c, count, Offset(inner.right, y), size: countFs, color: countInk, anchor: Anchor.centerRight);
  }

  /// What troop [type]'s cell says after its name: how many live, "x13" in grey (none: nothing); with the type caps on
  /// against its cap ([Game.typeCapOf], decisions-log 201), "x3/8", red at it or over it ("x5/5", "x17/5"), and red
  /// while Oath of One bars the type ([Game.typeLocked]): no troop of it can join now.
  (String, Color) _rowCount(Game g, String type) {
    final n = g.troopCounts[type] ?? 0, cap = g.typeCapOf(type), barred = g.typeLocked(type);
    if (cap == null) return (n > 0 || barred ? 'x$n' : '', barred ? _blockedInk : const Color(0xFF9E9080));
    return ('x$n/$cap', n >= cap || barred ? _blockedInk : const Color(0xFF9E9080));
  }

  /// The bound Pusaka's mark on troop [type]'s cell at [box]: its tooltip, and where it is for tests ([Board.pusakaBadge]).
  void _pusakaMark(Canvas c, Game g, String type, Rect box, Rect clip) {
    if (!box.overlaps(clip)) return;
    _tip.hints.add((box.intersect(clip), _Hint.pusaka, type));
    _assign.badges[type] = (box.intersect(clip), g.pusakaAsleep(g.pusakaOf(type)!));
  }

  /// Type [type]'s Release button at [btn] (the detail's foot; its press area [press], [btn] unless given): "Release"
  /// ([fs]); red while armed ([_Release]), greyed while it can't ([Game.whyNotRelease]). Registers its tap
  /// ([_releaseTap]) in [into].
  void _releaseButton(Canvas c, Game g, String type, Rect btn, double fs, {required List<(Rect, VoidCallback)> into, Rect? press}) {
    final rel = _release, why = g.whyNotRelease(type), tap = press ?? btn;
    if (why != null && rel.armed == type) rel.armed = null; // a wave began, a Hero came
    final armed = rel.armed == type, k = (btn.height / 16).floorToDouble().clamp(1.0, 3.0);
    final sink = _btnFrame(c, btn, why != null ? Board._btnWhite : (armed ? Board._btnRed : Board._btnLight), _look(tap, enabled: why == null), k);
    _text(c, Words.release, btn.center + Offset(0, sink - k), size: fs, anchor: Anchor.center,
        color: why != null ? const Color(0xFF8E8A86) : (armed ? const Color(0xFFFFF1D6) : const Color(0xFF3B2210)));
    into.add((tap, () => _releaseTap(type)));
  }

  /// The armed Release's confirm words for [type] on a button [h] tall with [room] across for them: what goes home and
  /// what it pays back, on two lines where it is tall enough ("Send Templar home?" at [f1] over "13 go home, +12k gold"
  /// at [f2]), else on one at [f2], the longest that fits ("Send Templar home? 13 go home, +12k gold", "Send Templar
  /// home? +12k", "Sure? +12k"); [width]: the widest line's (the confirm is that wide with its margins,
  /// [Board._detailFoot]). [named]: only words that name the type and the gold (no "Sure?"), whole; null when none fits.
  _ConfirmWords? _confirmWords(Game g, String type, double h, double room, double ts, {bool named = false}) {
    final n = g.troopCounts[type] ?? 0, name = troopTypeNames[type]!, short = '+${shortPrice(g.releaseRefundOf(type))}', back = '$short gold';
    final f1 = math.max(10.0, 15 * ts), f2 = math.max(10.0, 12 * ts);
    final ask = 'Send $name home?', goes = n == 0 ? 'No one goes home' : '${n == 1 ? '1 goes' : '$n go'} home, $back';
    final sets = h < f1 + f2 + 8
        ? [(['$ask $goes', '$ask $short', if (!named) '${Words.sure} $short'], f2)]
        : [([ask, if (!named) Words.sure], f1), ([goes, back], f2)];
    if (named && sets.any((e) => _textWidth(e.$1.last, e.$2) > room)) return null;
    final lines = [for (final (words, size) in sets) _fitFirst(words, size, room)];
    final width = lines.length == 1 ? _textWidth(lines[0], f2) : math.max(_textWidth(lines[0], f1), _textWidth(lines[1], f2));
    return (lines: lines, f1: f1, f2: f2, width: width);
  }

  /// The armed Release's confirm at [yes] (the detail's foot; its tap [press]): the red button with [words]
  /// ([_confirmWords]) in cream, one line in its middle or two about it. Returns the lines drawn.
  List<String> _releaseConfirm(Canvas c, _ConfirmWords words, Rect yes, Rect press) {
    const cream = Color(0xFFFFF1D6);
    final k = (yes.height / 16).floorToDouble().clamp(1.0, 3.0), sink = _btnFrame(c, yes, Board._btnRed, _look(press), k);
    final (:lines, :f1, :f2, width: _) = words;
    final mid = yes.center + Offset(0, sink - k);
    _release.confirm = press;
    if (lines.length == 1) {
      _text(c, lines[0], mid, size: f2, anchor: Anchor.center, color: cream);
      return lines;
    }
    final step = (f1 + f2) / 4 + 1;
    _text(c, lines[0], mid - Offset(0, step), size: f1, anchor: Anchor.center, color: cream);
    _text(c, lines[1], mid + Offset(0, step), size: f2, anchor: Anchor.center, color: cream);
    return lines;
  }

  /// A tap on type [type]'s Release or its confirm: the first picks the type and arms it, the second sends it home
  /// ([Game.releaseType]) and says what came back. Refused: the error and why.
  void _releaseTap(String type) {
    final g = state, rel = _release;
    _army.pick = type;
    if (g.whyNotRelease(type) case final why?) {
      rel.armed = null;
      g.releaseType(type); // the error
      return showMessage(why);
    }
    if (rel.armed != type) {
      rel.armed = type;
      return;
    }
    rel.armed = null;
    final n = g.troopCounts[type] ?? 0, refund = g.releaseType(type)!, name = troopTypeNames[type]!;
    showMessage(n == 0 ? '$name sent home' : '$name sent home: ${n == 1 ? '1 troop' : '$n troops'}, +${thousands(refund)} gold');
  }

  /// [maxAwaken] stars across [box] ([awakenTop] once a type bought Bangkit 4, or with [all]; smaller, so they fit):
  /// the levels reached filled, each in its own level's colour (blue, crimson, gold: the icon's own, violet, white),
  /// the rest empty and faint. From Bangkit 3 they glow in the level's colour.
  void _awakeStars(Canvas c, Rect box, int level, {bool all = false}) {
    final n = all || level > maxAwaken ? awakenTop : maxAwaken;
    final s = math.min(box.height, box.width / (n + (n - 1) * 0.07)), gap = (box.width - s * n) / (n - 1), top = box.center.dy - s / 2;
    if (level >= maxAwaken) {
      c.drawOval(box.inflate(s * 0.25), Paint()..color = _awakeColors[level - 1].withValues(alpha: 0.18 + 0.1 * math.sin(_clock * 3)));
    }
    for (var i = 0; i < n; i++) {
      final to = Rect.fromLTWH(box.left + i * (s + gap), top, s, s);
      c.drawImageRect(_img('ui_icons.png'), i < level ? _starIcon : _emptyStarIcon, to,
          i >= level ? _faintPaint : (i == maxAwaken - 1 ? _px : _awakeFxPaints[i]));
    }
  }
}
