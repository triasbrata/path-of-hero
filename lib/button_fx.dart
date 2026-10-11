part of 'main.dart';

// How the buttons answer the pointer (issue #54; the owner: "ui button harusnya ada effect ketika di hover
// dan di click", then "kalau button ini animationnya [3 states] itu state biasa, di hover dan di press"):
// the pack's own three looks (ui_buttons.png), normal, lit while the mouse is on them, pushed in while a
// press on them is held, and a click on the press. One rule for all ([buttonLook]): [Board._button]'s
// buttons, the Start/Pause toggle, the shut page tabs and the book's rows use it. A press acts on the way down, as
// before; the pushed-in look lasts until the pointer comes up and at least [pressMin] s, then the face comes
// back up through the hover look for [pressBack] s. Touch has no hover, only the press. A disabled button
// shows neither. The pointer presses too ([cursorFrame], #72).

/// A button's look this frame.
enum ButtonLook { normal, hover, pressed, disabled }

/// A press shows pushed in for at least [pressMin] s (a quick click too), then half way back (the hover look)
/// for [pressBack] s.
const pressMin = 0.08, pressBack = 0.08;

/// A press: where it went down, when, and when it came up (null: still held), on the screen clock.
typedef ButtonPress = ({Offset at, double down, double? up});

/// How [press] shows at [now] on what it went down on: pushed in while held and [pressMin] s at least, then
/// the hover look for [pressBack] s; null after.
ButtonLook? pressLook(ButtonPress? press, double now) {
  if (press == null) return null;
  final end = math.max(press.up ?? double.infinity, press.down + pressMin);
  if (now < end) return ButtonLook.pressed;
  if (now < end + pressBack) return ButtonLook.hover;
  return null;
}

/// [r]'s look at [now]: disabled when not [enabled]; as [press] shows ([pressLook]) when it went down on it;
/// lit while the mouse ([hover]; null on touch) is on it.
ButtonLook buttonLook(Rect r, {bool enabled = true, Offset? hover, ButtonPress? press, double now = 0}) {
  if (!enabled) return ButtonLook.disabled;
  if (press != null && r.contains(press.at)) {
    if (pressLook(press, now) case final look?) return look;
  }
  if (hover != null && r.contains(hover)) return ButtonLook.hover;
  return ButtonLook.normal;
}

/// Each of the pointer's press frames lasts [cursorStep] s.
const cursorStep = 0.05;

/// The pointer's frame for [press] at [now] (ui_icons.png's cursors: 0 the arrow, 1 and 2 pressing): a
/// press goes to 1, then 2 [cursorStep] s on, and stays there while held (both frames at least); coming up
/// it shows 1 for [cursorStep] s, then the arrow again.
int cursorFrame(ButtonPress? press, double now) {
  if (press == null) return 0;
  final end = math.max(press.up ?? double.infinity, press.down + 2 * cursorStep);
  if (now < end) return now - press.down < cursorStep ? 1 : 2;
  return now < end + cursorStep ? 1 : 0;
}

/// ui_buttons.png (UI_Buttons.png's first three columns): one colour per row 48 px apart ([Board._btnLight]
/// …), its looks side by side in 32x16 cells: normal, hover (the face 1 px lower, a thin shade), pressed (2 px
/// lower, darker, no shade). Their visible 30x14 from (1, 1), all ending on the same bottom row.
Rect _btnSrc(int row, ButtonLook look) =>
    Rect.fromLTWH(1 + 32.0 * switch (look) { ButtonLook.hover => 1, ButtonLook.pressed => 2, _ => 0 }, 1 + 48.0 * row, 30, 14);

/// ui_all.png's square slots (the book's cells; decisions-log 187): one colour per row 48 px apart, [slotTan] (an item, a
/// Pusaka), [slotWhite] (a small relic, a locked row), green, blue, [slotOrange] (the one picked), red, purple; each look
/// in a column of its own: normal at x 10 (a disabled slot shows it too), lit at x 202 (the mouse on it), pressed at x
/// 394 (the pack's column 8). Normal and lit are 28x31: a 1-px outline (3F2832), a light rim, the face, and a 6-px lip
/// under it, the lit one's rim 2 px wide; pressed is 28x28, its face sunk into the lip.
const slotTan = 0, slotWhite = 1, slotGreen = 2, slotBlue = 3, slotOrange = 4, slotRed = 5, slotPurple = 6, slotRows = 7;
Rect slotSrc(int row, ButtonLook look) => switch (look) {
      ButtonLook.hover => Rect.fromLTWH(202, 10 + 48.0 * row, 28, 31),
      ButtonLook.pressed => Rect.fromLTWH(394, 10 + 48.0 * row, 28, 28),
      _ => Rect.fromLTWH(10, 10 + 48.0 * row, 28, 31),
    };

/// [slotSrc]'s 9-slice in sprite px, the same for every colour: the least that leaves every row of the stretched middle
/// one colour across and every column one colour down, so a slot stretched to any size keeps its pixel art exactly.
/// Normal: the corners 3 and the lip 6; lit 4 and 7 (its wider rim); pressed 6 left and top, 5 right and bottom (its
/// shade down the right).
({double l, double t, double r, double b}) slotInsets(ButtonLook look) => switch (look) {
      ButtonLook.hover => (l: 4, t: 4, r: 4, b: 7),
      ButtonLook.pressed => (l: 6, t: 6, r: 5, b: 5),
      _ => (l: 3, t: 3, r: 3, b: 6),
    };

/// [r] with its edges on whole pixels: a sprite drawn on it at a whole scale keeps every pixel.
Rect _whole(Rect r) => Rect.fromLTRB(r.left.roundToDouble(), r.top.roundToDouble(), r.right.roundToDouble(), r.bottom.roundToDouble());

/// Where a slot over [r] at [k] screen px per sprite px draws its [look]: pressed, its 28 rows end on the normal one's
/// bottom row, so it starts 3·[k] lower (the 3 rows of lip it lost); the other looks fill [r].
Rect slotRect(Rect r, ButtonLook look, double k) => look == ButtonLook.pressed ? Rect.fromLTRB(r.left, r.top + 3 * k, r.right, r.bottom) : r;

extension on Board {
  /// A 9-sliced [_btnSrc] button over [r] at [k] screen px per sprite px (l/r 4: the cut corners; t/b 6: rows
  /// 7–8 are the only ones straight in all three looks). Returns how far its face moved down (hover 1 sprite
  /// px, pressed 2), for what is drawn on it.
  double _btnFrame(Canvas c, Rect r, int row, ButtonLook look, double k) {
    _nine(c, _btnSrc(row, look), r, k, l: 4, t: 6, r: 4, b: 6, sheet: 'ui_buttons.png');
    return switch (look) { ButtonLook.hover => k, ButtonLook.pressed => 2 * k, _ => 0 };
  }

  /// A slot of colour [row] ([slotSrc]) over [r] in [look] at [k] screen px per sprite px, 9-sliced exactly
  /// ([slotInsets]; pressed 3·[k] lower, [slotRect]) on whole pixels; [paint] recolours it (a Pusaka's rarity,
  /// [_rarityCellPaints]). Returns how far its face moved down (pressed 3 sprite px), for what is drawn on it.
  double _slotFrame(Canvas c, Rect r, int row, ButtonLook look, double k, {Paint? paint}) {
    final i = slotInsets(look), on = slotRect(_whole(r), look, k);
    _nine(c, slotSrc(row, look), on, k, l: i.l, t: i.t, r: i.r, b: i.b, paint: paint, seam: k == k.roundToDouble() ? 0 : 0.5);
    return look == ButtonLook.pressed ? 3 * k : 0;
  }

  /// A book row that acts on a tap (a troop row, a Tas page's type row), in its card [frame]: the lit card
  /// under the mouse, and pushed in while pressed (the lit card, its paper a shade darker). Drawn before the
  /// row's content. A row that can't act ([enabled] false) shows neither. [paint] recolours the frame ([_card]).
  void _rowCard(Canvas c, Rect r, Rect frame, {bool enabled = true, Paint? paint}) {
    final look = _look(r, enabled: enabled);
    if (look == ButtonLook.normal || look == ButtonLook.disabled) return _card(c, r, frame, paint);
    _card(c, r, Board._frameLit, paint);
    if (look == ButtonLook.pressed) {
      final k = math.max(1.0, (r.shortestSide / 24).floorToDouble()); // the card's, as [_card]'s
      c.drawRect(r.deflate(2 * k), Paint()..color = const Color(0x245A3620));
    }
  }

  /// [r]'s look from the mouse and the last press. Nothing lights or sinks while something is dragged.
  ButtonLook _look(Rect r, {bool enabled = true}) {
    if (!enabled) return ButtonLook.disabled;
    if (dragAt != null) return ButtonLook.normal;
    return buttonLook(r, hover: _mouse, press: _press, now: _clock);
  }
}
