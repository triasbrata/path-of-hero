part of 'main.dart';

// After a wipe that left hearts (decisions-log 333; the owner, 2026-10-13: "dan saat troops wipe kan juga user akan masuk
// kembali ke kota, ini perlu di tampilkan juga kali apakah dia mau try again atau game over"): once the swept monsters'
// hop is over ([wipeCheer]) a dialog asks the player ([Game.wipeAsk], wipe.dart), over everything but a guide card: its
// ribbon "Your army fell!", the hearts left, the way back ([Wipe.wipeBack]: "Back to Millbrook: waves 21-27 again") and
// the foes weakened until the next Town, and two buttons: "Give up" ([Wipe.giveUp]: the game over and its scoreboard, as
// at 0 hearts) and "Try again" ([Wipe.tryAgain], green: on to the checkpoint's Town, or the same wave before the first).
// Enter is Try again, Esc Give up. The game waits under it: no wave starts and no Town opens until then, Auto Wave's
// countdown too. At 0 hearts no dialog: the game is over as before. Existing art only: the chest popup's tooltip-paper
// panel (ui_tooltip.png) and ribbon (ui_ribbons.png), the HUD's hearts (ui_icons.png), ui_buttons' buttons.
// Until the next new Town the wave meter has a "Weakened foes" chip ([Board._weakChip]; its tooltip [Wipe.weakenedTip]):
// the Town chip's capsule with ui_icons' green down arrow, under the Town chip and the boosts' chips.

/// The dialog's buttons: at least this tall on any screen (the 44-px tap rule), else 40 at its scale.
const _wipeAskBtnMin = 44.0;

/// ui_icons.png's big green down arrow (its cell mapped: 16x16 at 48,144, the arrow inside it with a clear edge): the
/// "Weakened foes" chip's icon.
const _icDownGreen = Offset(48, 144);

/// The dialog's state between frames: where it and its buttons were, and whether the last press was its own.
class _WipeAskView {
  Rect panel = Rect.zero, ribbon = Rect.zero;
  final hits = <(Rect, VoidCallback)>[];
  final buttons = <String, Rect>{};
  bool tapped = false;
}

extension _WipeAskLook on Board {
  /// Whether the dialog shows: a choice waits ([Game.wipeAsk]) and the swept monsters' hop is over, the game not over,
  /// not under the welcome screen. A game loaded with the choice waiting shows it at once (its [Game.wipedAt] is none).
  bool _wipeAskShown(Game g) => welcome == null && g.wipeAsk && !g.over && g.t - g.wipedAt >= wipeCheer;

  /// "Try again" ([Wipe.tryAgain]): saved, so a reload doesn't ask again; Auto Wave counts down as after a win (in a
  /// Town it waits until the Town is left, town_look.dart).
  void _wipeTryAgain(Game g) {
    if (!g.tryAgain()) return;
    saveGame(g);
    autoStart.won();
  }

  /// "Give up" ([Wipe.giveUp]): the game is over; its score goes to the board as at any game over (scoreboard.dart).
  void _wipeGiveUp(Game g) => g.giveUp();

  /// A press while the dialog shows: its buttons, and nothing under it. True when it showed.
  bool _wipeAskDown(Offset p) {
    final v = _wipeAsk;
    if (!_wipeAskShown(state)) return v.tapped = false;
    for (final (rect, fn) in [...v.hits]) {
      if (rect.contains(p)) {
        Sounds.play(Sfx.click);
        fn();
        break;
      }
    }
    return v.tapped = true;
  }

  /// A key while it shows: Enter is Try again, Esc Give up; P does nothing (nothing runs under it). True when it was one
  /// of those.
  bool _wipeAskKey(LogicalKeyboardKey key) {
    final g = state;
    if (!_wipeAskShown(g)) return false;
    if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.numpadEnter) {
      _wipeTryAgain(g);
    } else if (key == LogicalKeyboardKey.escape) {
      _wipeGiveUp(g);
    } else if (key != LogicalKeyboardKey.keyP) {
      return false;
    }
    return true;
  }

  /// The dialog (the file's comment), centred over the dimmed screen; under it nothing takes a tap or shows a tooltip.
  void _wipeAskDialog(Canvas c, Game g) {
    final v = _wipeAsk;
    v.hits.clear();
    v.buttons.clear();
    v.panel = v.ribbon = Rect.zero;
    if (!_wipeAskShown(g)) return;
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
    c.drawRect(Offset.zero & Size(size.x, size.y), Paint()..color = Colors.black.withValues(alpha: 0.6));

    // The panel: as the chest popup's, the text a little bigger than the screen scale; as wide as its lines need, at
    // most the screen less what it keeps on either side.
    final s = _screenScale(Size(size.x, size.y)), f = s * 1.2;
    final k = s >= 0.9 ? 3.0 : 2.0, rk = k + 1, pad = 12 * s + 3 * k, gap = 10 * f, ribbonH = 20 * rk;
    final side = math.max(_edgeL, _edgeR) + 8, room = size.x - 2 * side;
    final fs = 16 * f, back = g.wipeBack, weak = g.weakened > 0 ? 'Foes weakened until next ${Words.town}' : '';
    final cut = g.weakenedCut;
    final heart = 14 * k, halves = hearts(g.lives), heartsW = halves.length * (heart + k) - k;
    final linesW = [back, weak, cut].map((l) => _textWidth(l, fs)).reduce(math.max);
    final panelW = math.min(room, math.max(360 * f, linesW + 2 * pad + 2 * gap)).floorToDouble();
    final textW = panelW - 2 * pad, lineH = 22 * f, btnH = math.max(_wipeAskBtnMin, 40 * f).roundToDouble();
    final lines = [back, if (weak.isNotEmpty) weak, if (cut.isNotEmpty) cut];
    final bodyH = heart + gap + lines.length * lineH;
    final panel = v.panel = Rect.fromCenter(
        center: Offset(size.x / 2, size.y / 2 + ribbonH / 4),
        width: panelW,
        height: (ribbonH / 2 + pad + bodyH + gap + btnH + pad).roundToDouble());
    c.drawRect(panel.shift(const Offset(0, 6)).deflate(4), Paint()..color = Colors.black.withValues(alpha: 0.3));
    _nine(c, _tipBody, panel, k, l: 3, t: 3, r: 3, b: 5, sheet: 'ui_tooltip.png');

    // The hearts left (the HUD's, lives.dart), centred under the ribbon.
    final icons = _img('ui_icons.png'), top = panel.top + ribbonH / 2 + pad;
    for (final (i, h) in halves.indexed) {
      final at = Rect.fromLTWH((panel.center.dx - heartsW / 2 + i * (heart + k)).roundToDouble(), top, heart, heart);
      c.drawImageRect(icons, _heartIcons[h], at, _px);
    }
    // The way back in the tooltips' ink, the weakened foes in their effect green; each line shrinks to fit.
    var y = top + heart + gap + lineH / 2;
    for (final (i, l) in lines.indexed) {
      final ts = math.min(fs, fs * textW / math.max(1, _textWidth(l, fs)));
      _text(c, l, Offset(panel.center.dx, y), size: ts, color: i == 0 ? _tipInk : _effectInk, anchor: Anchor.center);
      y += lineH;
    }

    // The buttons: Give up at the left, Try again (green, the main answer) at the right.
    final row = Rect.fromLTWH(panel.left + pad, panel.bottom - pad - btnH, panel.width - 2 * pad, btnH);
    final bw = (row.width - gap) / 2, bk = (btnH / 16).floorToDouble().clamp(1.0, 3.0);
    double fit(String label) => math.min(18 * f, 18 * f * (bw - 2 * (4 * bk + 4)) / math.max(1, _textWidth(label, 18 * f)));
    _button(c, v.buttons['giveUp'] = Rect.fromLTWH(row.left, row.top, bw, btnH), () => _wipeGiveUp(g),
        label: Words.giveUp, size: fit(Words.giveUp), into: v.hits);
    _button(c, v.buttons['tryAgain'] = Rect.fromLTWH(row.right - bw, row.top, bw, btnH), () => _wipeTryAgain(g),
        row: Board._btnGreen, label: Words.tryAgain, size: fit(Words.tryAgain), into: v.hits);

    // Its ribbon (hero_splash.dart's), over the panel's top edge.
    v.ribbon = _ribbonTitle(c, Words.armyFell, Offset(panel.center.dx, panel.top), rk, size.x - 16);
  }

  /// The wave meter's "Weakened foes" chip while the monsters are weakened ([Game.weakened]), in the Town too: the Town
  /// chip's look ([_townChip]: ui_bars.png's dark capsule, the icon 16 px from its art at one screen px a pixel, 32 from
  /// the meter's k 4), the green down arrow and "Weakened foes" in the safe green ("Weakened" where the meter is too
  /// narrow for it), right-aligned under the boosts' chips, else under the Town chip, else where those go
  /// ([_underMeter]). Sets [_weakChipAt]; none at game over or without the weakening.
  void _weakChip(Canvas c, Game g) {
    _weakChipAt = Rect.zero;
    if (g.weakened <= 0 || g.over || _meterAt.isEmpty) return;
    final k = _meterK, fs = math.max(11.0, 5 * k), icon = 16.0 * math.max(1.0, (k / 2).floorToDouble());
    final ck = capsuleK(icon + 4), pad = capsulePad(fs, ck), gap = capsuleGap(fs);
    double width(String l) => (2 * pad + icon + gap + _textWidth(l, fs)).ceilToDouble();
    final label = width(Words.weakenedFoes) <= _meterAt.width ? Words.weakenedFoes : Words.weakened;
    final w = width(label), h = icon + 2 * (ck + 1), left = (_meterAt.right - w).roundToDouble();
    final top = !_boostRowAt.isEmpty
        ? _boostRowAt.bottom + 6
        : !_townChipAt.isEmpty
            ? _townChipAt.bottom + 6
            : _underMeter(left, w);
    // Left of the pocket bar where it would come down beside it (pocket_look.dart, decisions-log 332).
    final at = _weakChipAt = Rect.fromLTWH((_stackRight(top, h) - w).roundToDouble(), top, w, h);
    _nine(c, _capsuleSrc, at, ck, l: 1, t: 1, r: 1, b: 1, sheet: 'ui_bars.png', seam: 0); // its corners stay cut
    _uiIcon(c, _icDownGreen, Rect.fromLTWH(at.left + pad, at.top + ck + 1, icon, icon));
    _text(c, label, Offset(at.left + pad + icon + gap, at.center.dy), size: fs, color: _townSafeInk);
  }
}
