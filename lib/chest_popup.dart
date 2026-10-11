part of 'main.dart';

// Peti Bos's popup, on screen the "Boss Chest" (decisions-log 152, 197; its rules: lib/draft.dart,
// docs/loot-items-relics.md "Peti Bos"; how it looks: docs/ui-hud.md). Once a won boss wave's cheering and any new Hero's
// splash are over, the screen dims and the chest opens in the tooltip frame: its ribbon ("Boss Chest", or an old save's
// "Missed Chest 1/3") and its three cards side by side. A card, its page
// frame recoloured by rarity, shows the Pusaka's icon, its name, the stars it will have (the ui_icons stars) with its
// rarity in its ink, what it does then and where it goes ("New: for Knight", "In Vault"); a Serpihan's (a "Shard") says
// it is a free reroll. Under them a hint with the gold, and the buttons: Reroll (its price, or free with a Shard; "Need
// 38k gold" greyed), Skip (its gold; a second press passes the chest over) and Take. A tap on a card picks it (lifted
// and lit), a tap on another moves the pick; Take, greyed until a card is picked, takes it. The chest can't be put off
// (decisions-log 281; the owner: "remove later button dari opsi chest boss jadi user wajib ambil"): it stays open
// until Take or Skip, and no wave starts before: Start pressed while a chest waits (a boss win's cheer, before the
// popup opens) opens it instead ([Board._chestNow]). A chest waiting while the popup can't show yet (the win's cheer,
// a Hero splash) is the pulsing "Chest!" chip under the Start/Pause toggle, which opens it too; never mid-wave, where
// no chest can wait any more. While a chest is due the auto start's countdown waits ([Board._chestHolds], on its
// `held:`, not [Board.holdAutoStart], which the Hero splash sets outright). Like the Hero splash, the HUD under it
// takes no taps or tooltips.

/// ui_icons.png's gift box: the chest's icon (the chip, the VICTORY! line, the log, a Serpihan's card).
const _icChest = Offset(128, 16);

/// Each rarity's ink: its name on a chest card, the card icon's glow, and the log line's. A Serpihan's is steel.
const _rarityInk = {
  Rarity.biasa: Color(0xFFD8CFBF),
  Rarity.langka: Color(0xFF3FA34D),
  Rarity.epik: Color(0xFF9B4DFF),
  Rarity.legenda: Color(0xFFFF9F1C),
};
const _serpihanInk = Color(0xFF8A9BB0);

/// ui_all.png's page frames' three colours ([Board._framePlain], [Board._frameLit]): the paper, the rim, and the dark
/// rim (the plain frame's corners, the lit one's outer line).
const _framePaper = Color(0xFFF6CA9F), _frameRim = Color(0xFFE69C69), _frameDark = Color(0xFFBF6F4A);

/// A chest card's frame by its rarity, the rim's and the dark rim's colours (the owner, 2026-10-02, over an ink box
/// drawn on the frame: "kotak ungu di takeout saja ... atau assetsnya yang kamu filter untuk mendapatkan warna yang
/// berbeda"): Langka a light green, Epik purple, Legenda gold, a Serpihan steel. The paper stays the book's.
const _rarityFrame = {
  Rarity.langka: (Color(0xFF8CC878), Color(0xFF4E8C46)),
  Rarity.epik: (Color(0xFFB98CF0), Color(0xFF7E50C8)),
  Rarity.legenda: (Color(0xFFF2C23C), Color(0xFFC8821E)),
};
const _serpihanFrame = (Color(0xFFA4B2C6), Color(0xFF6A7A92));

/// [_rarityFrame]'s paints (a Biasa, never on a card, keeps the plain frame), and a Serpihan's, made once: the page
/// frame itself recoloured ([_recolour]), so its pixel art's light and shadow stay.
final _rarityFramePaints = {for (final MapEntry(key: r, value: (rim, dark)) in _rarityFrame.entries) r: _framePaint(rim, dark)};
final _serpihanFramePaint = _framePaint(_serpihanFrame.$1, _serpihanFrame.$2);

Paint _framePaint(Color rim, Color dark) => Paint()
  ..filterQuality = FilterQuality.none
  ..colorFilter = _recolour([(_framePaper, _framePaper), (_frameRim, rim), (_frameDark, dark)]);

/// A colour matrix through black that takes each of three linearly independent colours to its pair's other, exactly
/// (any other colour goes where that linear map takes it); alpha untouched. M = T·S⁻¹, S's columns the colours from and
/// T's the colours to; S⁻¹ by its cofactors.
ColorFilter _recolour(List<(Color, Color)> pairs) {
  List<double> rgb(Color c) => [c.r, c.g, c.b];
  final from = [for (final (a, _) in pairs) rgb(a)], to = [for (final (_, b) in pairs) rgb(b)];
  double s(int i, int k) => from[k][i];
  double cof(int i, int j) =>
      s((i + 1) % 3, (j + 1) % 3) * s((i + 2) % 3, (j + 2) % 3) - s((i + 1) % 3, (j + 2) % 3) * s((i + 2) % 3, (j + 1) % 3);
  final det = s(0, 0) * cof(0, 0) + s(0, 1) * cof(0, 1) + s(0, 2) * cof(0, 2);
  double m(int i, int j) => [for (var k = 0; k < 3; k++) to[k][i] * cof(j, k)].reduce((a, b) => a + b) / det;
  return ColorFilter.matrix([for (var i = 0; i < 3; i++) ...[m(i, 0), m(i, 1), m(i, 2), 0, 0], 0, 0, 0, 1, 0]);
}

/// [_recolour] for four colours, through no fixed point: a colour matrix with an offset column that takes each of four
/// affinely independent colours to its pair's other, exactly (any other colour goes where that affine map takes it);
/// alpha untouched. A map through black can pin only three, and moves a dark outline that isn't black; this one can
/// keep the outline and the face of a slot while its rim and lip change ([_rarityCellPaints]).
ColorFilter _recolour4(List<(Color, Color)> pairs) => ColorFilter.matrix(recolourMatrix(pairs));

/// [_recolour4]'s 4x5 matrix, row-major, its offset column in 0-255 as [ColorFilter.matrix] takes it: for each of red,
/// green and blue, the a·r + b·g + c·b + d that takes the four colours from to that channel of the colours to, solved
/// by Gauss-Jordan with partial pivoting. Throws when the four are affinely dependent (on one plane). For tests.
List<double> recolourMatrix(List<(Color, Color)> pairs) {
  assert(pairs.length == 4);
  // One row per pair: r, g, b, 1 | the three channels to.
  final m = [for (final (a, b) in pairs) <double>[a.r, a.g, a.b, 1, b.r, b.g, b.b]];
  for (var col = 0; col < 4; col++) {
    final p = [for (var i = col; i < 4; i++) i].reduce((x, y) => m[y][col].abs() > m[x][col].abs() ? y : x);
    if (m[p][col].abs() < 1e-9) throw ArgumentError('recolourMatrix: the four colours are affinely dependent');
    final swap = m[col];
    m[col] = m[p];
    m[p] = swap;
    final lead = m[col][col];
    m[col] = [for (final v in m[col]) v / lead];
    for (var i = 0; i < 4; i++) {
      if (i == col) continue;
      final f = m[i][col];
      m[i] = [for (var j = 0; j < 7; j++) m[i][j] - f * m[col][j]];
    }
  }
  // m[k][4 + ch]: the coefficient k (r, g, b, then the offset) of channel ch.
  return [for (var ch = 0; ch < 3; ch++) ...[m[0][4 + ch], m[1][4 + ch], m[2][4 + ch], 0, m[3][4 + ch] * 255], 0, 0, 0, 1, 0];
}

/// ui_all.png's slots' four colours ([slotSrc]; the tan row's, the lit and pressed looks' too): the outline, the rim, the
/// face and the lip.
const _slotOutline = Color(0xFF3F2832), _slotRim = Color(0xFFEAD4AA), _slotFace = Color(0xFFE4A672), _slotLip = Color(0xFFB86F50);

/// A Pusaka's cell by its rarity (decisions-log 187): the tan slot ([Board._slotFrame]) with its rim in the rarity's rim
/// colour and its lip in its dark ([_rarityFrame], the chest cards'), the face and the outline kept ([_recolour4]). The
/// same paint goes on the lit and pressed looks, drawn in the same four colours. A Biasa (never a Pusaka) keeps the tan
/// slot.
final _rarityCellPaints = {
  for (final MapEntry(key: r, value: (rim, dark)) in _rarityFrame.entries)
    r: Paint()
      ..filterQuality = FilterQuality.none
      ..colorFilter = _recolour4([(_slotOutline, _slotOutline), (_slotFace, _slotFace), (_slotRim, rim), (_slotLip, dark)]),
};

/// The battle log's line for a closed chest: "Boss Chest: Iron Banner ★1 (Rare) to Templar", "… to Vault", an oath's
/// "… for all troops", "Boss Chest: Shard", "Boss Chest skipped: +700 gold".
String offerLine(OfferPicked e) {
  final title = e.chest == ChestKind.catchUp.name ? Words.missedChest : Words.bossChest, pick = e.pick;
  if (e.skipped) return '$title skipped: +${shortPrice(e.gain)} gold';
  if (pick == null) return '$title: ${Words.shard}';
  final to = pick.oath ? 'for all troops' : (e.type == null ? 'to ${Words.vault}' : 'to ${troopTypeNames[e.type] ?? e.type}');
  return '$title: ${relicNames[pick]} ★${e.stars} (${rarityNames[pick.rarity]}) $to';
}

/// The chest popup between frames: the game it is for (another one, a new game or a load, starts it afresh), whether it
/// shows and since when, the card picked, Lewati pressed once, whether the last press was the popup's (its tap up and
/// drag stay there), and this frame's taps, cards, buttons and chip.
class _ChestView {
  Game? game;
  bool open = false, tapped = false, skipArmed = false;
  double since = 0;
  int? armed;
  final hits = <(Rect, VoidCallback)>[];
  final cards = <Rect>[];
  final buttons = <String, Rect>{}; // 'reroll', 'skip', 'take' (Ambil, greyed until a card is picked)
  Rect chip = Rect.zero, ribbon = Rect.zero; // the chip, and the popup's ribbon as drawn this frame (zero: none)
  _Reveal? reveal; // a take's Shadow being revealed (omen_look.dart): the popup stays up over it
  var lines = <List<_SplashLine>>[], labels = <String>[]; // the cards' lines and the buttons' labels last drawn, for it
  final faces = <String>[]; // each card's Shadow as drawn this frame: its marks ("?!!") or, revealed, "Armor 2" / "Dodged"
  String hint = ''; // the line under the cards as drawn this frame ('' while the popup is shut)
}

extension on Board {
  /// Opens the next chest once it is due ([_chestDue]), between waves, after the win's cheering ([victoryTime]) and any
  /// new Hero's splash; shuts the popup when no chest can be dealt with now (a wave on, the game over).
  void _chestNews(Game g) {
    final v = _chest;
    if (!identical(g, v.game)) {
      v
        ..game = g
        ..open = false
        ..armed = null
        ..skipArmed = false
        ..reveal = null;
    }
    // A take's reveal holds the popup up for [omenRevealFor] (a tap ends it sooner, [_chestDown]); then its message.
    if (v.reveal case final r?) {
      if (_clock - r.since < omenRevealFor) return;
      _endReveal();
    }
    if (g.whyNotChest != null) {
      v.open = false;
      return;
    }
    final calm = _herald.who == null && _herald.next.isEmpty && g.t - g.victoryAt >= victoryTime;
    if (!v.open && calm && _chestDue(g)) _openChest(g);
  }

  /// A chest is due: one waits. None can be put off (decisions-log 281).
  bool _chestDue(Game g) => g.chest != null;

  /// The auto start's countdown waits ([AutoStart.tick]'s `held:`): the popup is open or revealing a take's Shadow, or a
  /// chest is due.
  bool _chestHolds(Game g) => _chest.open || _chest.reveal != null || (g.whyNotChest == null && _chestDue(g));

  /// The reveal is over (its time, or a tap): the take's message shows ([_chestTake]), and the next chest due opens on
  /// the next frame.
  void _endReveal() {
    final r = _chest.reveal;
    _chest.reveal = null;
    if (r != null) showMessage(r.message);
  }

  /// Opens the next chest ([Draft.openChest]); a catch-up chest's cards are rolled now, so the game is saved: a reload
  /// shows the same ones.
  void _openChest(Game g) {
    final rolled = g.chest?.cards == null;
    if (g.openChest() == null) return;
    _chest
      ..open = true
      ..since = _clock
      ..armed = null
      ..skipArmed = false
      ..hits.clear();
    if (rolled) saveGame(g);
  }

  /// A press while the popup shows: it acts on what it hit (a card, a button), else lets an armed Lewati go (the card
  /// picked stays picked: a press just off Take, between the buttons, mustn't grey it), and is used up. True when the
  /// popup took it.
  bool _chestDown(Offset p) {
    final v = _chest;
    if (v.reveal != null) {
      _endReveal(); // a tap skips the reveal
      return v.tapped = true;
    }
    if (!v.open) return v.tapped = false;
    for (final (rect, fn) in [...v.hits]) {
      if (rect.contains(p)) {
        Sounds.play(Sfx.click);
        fn();
        return v.tapped = true;
      }
    }
    v.skipArmed = false;
    return v.tapped = true;
  }

  /// Take: takes card [i], the one picked ([Draft.takeCard]); the message says what came ("Iron Banner ★1!"; an oath that it
  /// is the whole army's, and Oath of One while it waits, [oathWaitingNote]), and the game is saved. The next chest due
  /// opens on the next frame. A card hiding a Shadow (omen_look.dart) is revealed first ([_Reveal], with [Sfx.magic]):
  /// the popup stays up with the cards as they were, and the message, with what the monsters got under it ("Monsters
  /// got Armor 2: Monsters take 10% less damage."), comes after it.
  void _chestTake(Game g, int i) {
    final v = _chest, chest = g.chest, relic = chest?.cards?[i], held = g.omens.length;
    final faces = omensOn ? chest?.omens : null, face = faces?.elementAtOrNull(i);
    final (cards, lines, labels) = ([...?chest?.cards], v.lines, v.labels);
    if (!g.takeCard(i)) return;
    v
      ..open = false
      ..armed = null;
    final line = switch (relic) {
      null => '${Words.shard} +1: one free ${Words.reroll}',
      Relic(oath: true) => '${relicNames[relic]}: ${Words.oath} for all troops!${g.oathWaits ? '\n${oathWaitingNoteOf(relic)}' : ''}',
      _ => '${relicNames[relic]} ★${g.pusaka[relic]!.stars}!',
    };
    if (face == null || relic == null) {
      showMessage(line);
    } else {
      final plan = g.omens.sublist(held), got = g.omenGotLine(plan), kinds = {...plan};
      v.reveal = _Reveal(
          cards: cards,
          faces: [...faces!],
          taken: i,
          got: got,
          label: '${face.title} ${g.omenLevel(face)}',
          message: '$line\n${kinds.length == 1 ? '$got: ${g.omenEffect(kinds.first)}' : got}',
          since: _clock)
        ..lines = lines
        ..labels = labels;
      Sounds.play(Sfx.magic); // the cards' Shadows flip over
    }
    saveGame(g);
  }

  /// Kocok ulang ([Draft.rerollChest]): new cards, and the game saved.
  void _chestReroll(Game g) {
    if (g.whyNotReroll case final why?) return showMessage(why);
    if (!g.rerollChest()) return;
    _chest
      ..armed = null
      ..skipArmed = false;
    saveGame(g);
  }

  /// Lewati: a first press arms it, a second passes the chest over for its gold ([Draft.skipChest]).
  void _chestSkip(Game g) {
    final v = _chest;
    if (!v.skipArmed) {
      v
        ..skipArmed = true
        ..armed = null;
      return;
    }
    final gain = g.skipChest();
    if (gain == null) return;
    v
      ..open = false
      ..skipArmed = false;
    showMessage('Chest skipped: +${shortPrice(gain)} gold${g.skipBuffDue ? '\n${g.skipNote()}' : ''}'); // omen.dart
    saveGame(g);
  }

  /// Start pressed ([Board._startPress]) or the chip tapped while a chest waits between waves (decisions-log 281): it
  /// opens now, the win's cheer cut short; while a new Hero's splash shows or waits it does nothing more, and the chest
  /// opens by itself after the splash (the splash would draw under the popup). No wave starts either way.
  void _chestNow(Game g) {
    if (g.whyNotChest case final why?) return showMessage(why);
    if (_herald.who == null && _herald.next.isEmpty) _openChest(g);
  }

  /// A tap on the chip: as Start then ([_chestNow]).
  void _chipTap(Game g) => _chestNow(g);

  /// The pulsing "Chest!" chip ("Chest! x2" with two waiting) while a chest waits between waves and the popup is shut
  /// (the win's cheer and a Hero splash before it opens; mid-wave no chest can wait since decisions-log 281): under the
  /// Start/Pause toggle (and its Auto hold line), centred on it (start_button.dart). The pack's orange button with the
  /// gift box, a gold glow beating round it.
  void _chestChip(Canvas c, Game g) {
    final v = _chest;
    v.chip = Rect.zero;
    if (v.open || v.reveal != null || g.chest == null || g.whyNotChest != null) return;
    final n = g.chests.length, h = _startH, font = (h * 0.42).clamp(14.0, 28.0), k = (h / 16).floorToDouble().clamp(1.0, 3.0);
    final label = n > 1 ? 'Chest! x$n' : 'Chest!', icon = math.max(16.0, (h - 10 * k).floorToDouble()), inset = 4 * k + 4;
    final w = (inset + icon + 4 + _textWidth(label, font) + inset).roundToDouble(), toggle = _toggleAt, gap = 2 * _meterK;
    final x = (toggle.center.dx - w / 2).clamp(_edgeL, math.max(_edgeL, size.x - _edgeR - w)), y = math.max(toggle.bottom, _autoHeldAt.bottom) + gap;
    final r = v.chip = Offset(x.roundToDouble(), y.roundToDouble()) & Size(w, h);
    final beat = 0.5 + 0.5 * math.sin(_clock * 5);
    c.drawRRect(RRect.fromRectAndRadius(r.inflate(2 + 3 * beat), Radius.circular(3 * k)),
        Paint()..color = _heroGold.withValues(alpha: 0.25 + 0.35 * beat));
    final sink = _button(c, r, () => _chipTap(g), row: Board._btnOrange);
    final mid = r.center.dy - k + sink; // a touch up: the bottom is the button's edge
    _uiIcon(c, _icChest, Rect.fromLTWH(r.left + inset, (mid - icon / 2).roundToDouble(), icon, icon));
    _text(c, label, Offset(r.left + inset + icon + 4, mid), size: font, color: const Color(0xFF3B2210));
  }

  /// The popup ([_ChestView]) over the dimmed screen, fading in over [_heraldIn]: the panel in the tooltip frame's body,
  /// the ribbon with the chest's title across its top, its cards ([_chestCard]), the hint and gold line, and the buttons.
  /// Cards hiding Shadows (omen_look.dart) show their marks in a row of their own at the card's bottom. While a take's
  /// Shadow is revealed ([_Reveal]) it shows the cards as they
  /// were, the taken one lifted, the buttons greyed and the ribbon saying what the monsters got.
  void _chestPopup(Canvas c, Game g) {
    final v = _chest, chest = g.chest, reveal = v.reveal;
    v.cards.clear();
    v.buttons.clear();
    v.faces.clear();
    v.hint = '';
    v.ribbon = Rect.zero;
    if (reveal == null && (!v.open || chest == null || chest.cards == null)) return;
    final cards = reveal?.cards ?? chest!.cards!, faces = reveal?.faces ?? (omensOn ? chest!.omens : null);
    final shown = faces != null && faces.any((f) => f != null); // the cards hide Shadows
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
    final fade = ((_clock - v.since) / _heraldIn).clamp(0.0, 1.0);
    c.saveLayer(null, Paint()..color = Colors.black.withValues(alpha: fade));
    c.drawRect(Offset.zero & Size(size.x, size.y), Paint()..color = Colors.black.withValues(alpha: 0.65));

    // The panel: three cards a row, as tall as the tallest card's lines need. The text a little bigger than the screen
    // scale.
    final s = _screenScale(Size(size.x, size.y)), f = s * 1.2;
    final k = s >= 0.9 ? 3.0 : 2.0, rk = k + 1, pad = 12 * s + 3 * k, gap = 10 * f, ribbonH = 20 * rk;
    final side = math.max(_edgeL, _edgeR); // it is centred: clear of what the screen keeps on either side
    final panelW = math.min(size.x - 2 * side, 3 * 230 * f + 2 * gap + 2 * pad).floorToDouble();
    final cardW = (panelW - 2 * pad - 2 * gap) / 3, cardPad = 8 * f, icon = 56 * f;
    final textW = cardW - 2 * cardPad;
    final lines = reveal?.lines ?? [for (final r in cards) _cardLines(g, r, f, textW)];
    if (reveal == null) v.lines = lines;
    final markH = shown ? 16 * f : 0.0; // the marks' row: the text's height
    final linesH = lines.map((l) => l.fold(0.0, (h, x) => h + x.$1)).reduce(math.max);
    final cardH = 2 * cardPad + icon + 6 * f + linesH + (shown ? markH + 4 * f : 0);
    final btnH = math.max(32.0, 32 * f), infoH = 22 * f;
    final panel = Rect.fromCenter(
        center: Offset(size.x / 2, size.y / 2 + ribbonH / 4),
        width: panelW,
        height: (ribbonH / 2 + pad + cardH + gap + infoH + gap + btnH + pad).roundToDouble());
    c.drawRect(panel.shift(const Offset(0, 6)).deflate(4), Paint()..color = Colors.black.withValues(alpha: 0.3));
    _nine(c, _tipBody, panel, k, l: 3, t: 3, r: 3, b: 5, sheet: 'ui_tooltip.png');

    final top = panel.top + ribbonH / 2 + pad;
    for (final (i, relic) in cards.indexed) {
      final at = Rect.fromLTWH(panel.left + pad + i * (cardW + gap), top, cardW, cardH);
      _chestCard(c, g, at, i, relic, lines[i], icon, f, face: faces?.elementAtOrNull(i), markH: markH);
    }

    // The hint at the left, the gold and the Serpihan at the right. With Shadows: Lewati armed says what it brings
    // instead ([Omens.skipNote]); and until the monsters hold any, what the marks mean.
    final infoY = top + cardH + gap + infoH / 2, fs = 14 * f;
    final hint = reveal != null
        ? ''
        : v.skipArmed && omensOn && g.wave >= omenFrom
            ? g.skipNote()
            : v.armed != null
                ? 'Tap ${Words.take} to get it'
                : shown && g.omens.isEmpty && g.omensOwed.isEmpty
                    ? 'Each card gives monsters a ${Words.shadow} (! = how strong)'
                    : 'Tap a card to pick it';
    v.hint = hint;
    final purse = [if (g.serpihan > 0) '${Words.shard} x${g.serpihan}', 'Gold ${shortPrice(g.gold)}'].join('   ');
    final purseW = _textWidth(purse, fs), hintFs = math.min(fs, fs * (panel.width - 2 * pad - purseW - gap) / math.max(1, _textWidth(hint, fs)));
    _text(c, hint, Offset(panel.left + pad, infoY), size: hintFs, color: _tipInk);
    _text(c, purse, Offset(panel.right - pad, infoY), size: fs, color: _storeGold, anchor: Anchor.centerRight);

    // The buttons: Kocok ulang, Lewati, Ambil, side by side; greyed with their labels as they were while a take's Shadow
    // is revealed. Ambil is the popup's main action: green, greyed until a card is picked, and it takes that card.
    final row = Rect.fromLTWH(panel.left + pad, panel.bottom - pad - btnH, panel.width - 2 * pad, btnH);
    final bw = (row.width - 2 * gap) / 3, bk = (btnH / 16).floorToDouble().clamp(1.0, 3.0);
    Rect slot(int j) => Rect.fromLTWH(row.left + j * (bw + gap), row.top, bw, btnH);
    double fit(String label) => math.min(16 * f, 16 * f * (bw - 2 * (4 * bk + 4)) / math.max(1, _textWidth(label, 16 * f)));
    if (reveal != null) {
      for (final (j, label) in reveal.labels.indexed) {
        _button(c, slot(j), () {}, enabled: false, label: label, size: fit(label));
      }
    } else {
      final open = chest!, cost = g.rerollCost(open), why = g.whyNotReroll, gain = shortPrice(g.skipGold);
      final reroll = why == chestRefusals.gold
          ? 'Need ${shortPrice(cost)} gold'
          : why ?? (g.serpihan > 0 ? 'Free ${Words.reroll}' : '${Words.reroll} ${shortPrice(cost)}');
      final skip = v.skipArmed ? '${Words.sure} +$gain' : '${Words.skip} +$gain', take = Words.take, picked = v.armed;
      v.labels = [reroll, skip, take];
      _button(c, v.buttons['reroll'] = slot(0), () => _chestReroll(g), enabled: why == null, label: reroll, size: fit(reroll));
      _button(c, v.buttons['skip'] = slot(1), () => _chestSkip(g), active: v.skipArmed, label: skip, size: fit(skip));
      _button(c, v.buttons['take'] = slot(2), () => _chestTake(g, picked!),
          enabled: picked != null, row: Board._btnGreen, label: take, size: fit(take));
    }

    // Its ribbon (hero_splash.dart), but not under a guide card over the chest (K5, K12: coach.dart), whose own ribbon
    // would sit right under it: one title over the two. A reveal's says what the monsters got.
    final title = reveal?.got ?? chest!.title;
    if (!_coach.showing) v.ribbon = _ribbonTitle(c, title, Offset(panel.center.dx, panel.top), rk, size.x - 16);
    c.restore();
    v.hits
      ..clear()
      ..addAll(reveal == null ? _hits : const []);
  }

  /// Card [i] of the chest, [relic] (null: a Serpihan), in [r] (lifted while picked): the page card recoloured by its
  /// rarity ([_rarityFramePaints]; lit while picked or under the mouse), the icon over a glow in its ink at the top and
  /// its [lines]. A tap picks it (a tap on another moves the pick; on it again, it stays picked): the button row's Ambil
  /// takes it (decisions-log 281; until then a second tap took it, with a green Ambil on the card). Its hidden Shadow
  /// [face] ([Board._omenFace], [markH] tall) at its bottom. While a take's Shadow is revealed the taken card stays
  /// lifted, and nothing takes a tap.
  void _chestCard(Canvas c, Game g, Rect r0, int i, Relic? relic, List<_SplashLine> lines, double icon, double f,
      {OmenKind? face, double markH = 0}) {
    final v = _chest, reveal = v.reveal, armed = reveal == null ? v.armed == i : reveal.taken == i;
    final r = armed ? r0.shift(Offset(0, -6 * f)) : r0, pad = 8 * f;
    final ink = relic == null ? _serpihanInk : _rarityInk[relic.rarity]!;
    final frame = relic == null ? _serpihanFramePaint : _rarityFramePaints[relic.rarity];
    if (armed) {
      _card(c, r, Board._frameLit, frame);
    } else {
      _rowCard(c, r, Board._framePlain, paint: frame, enabled: reveal == null);
    }
    final iconAt = Rect.fromLTWH(r.center.dx - icon / 2, r.top + pad, icon, icon);
    c.drawCircle(iconAt.center, icon * 0.5, Paint()..color = ink.withValues(alpha: 0.3));
    if (relic == null) {
      _uiIcon(c, _icChest, iconAt.deflate(icon * 0.12));
    } else {
      _icon(c, relic, Board._iconIn(relic, iconAt, icon * 0.1));
    }
    var y = iconAt.bottom + 6 * f;
    for (final (h, w, draw) in lines) {
      draw(c, Offset(r.center.dx - w / 2, y + h / 2));
      y += h;
    }
    if (face != null && relic != null) {
      _omenFace(c, g, Rect.fromLTWH(r.left + pad, r.bottom - pad - markH, r.width - 2 * pad, markH), face, relic, 13 * f,
          i: i, reveal: reveal);
    }
    if (reveal == null) {
      _hits.add((
        r,
        () {
          v.armed = i;
          v.skipArmed = false;
        }
      ));
    }
    v.cards.add(r);
  }

  /// A card's lines at [f] times the tooltips' size, no wider than [maxW] (a long one shrinks, an effect wraps): the
  /// name; the stars it will have (the one it gains glowing; a Legenda has one, [maxStars]), an owned one's Carve steps
  /// after them (its gold "+3", which the star-up keeps; decisions-log 196) and its rarity; what it does at them
  /// ([Game.relicEffect]); where it goes ([Draft.cardType]; an oath the whole army for the whole run, and Oath of
  /// One's wait in red while more than its types are alive, Oath of the Few's while more than its troops are). A Serpihan's: its name, what it is, and how many are held.
  /// Its words are the item text's simple English (decisions-log 168).
  List<_SplashLine> _cardLines(Game g, Relic? relic, double f, double maxW) {
    _SplashLine text(String s, double size, Color color) {
      final fs = math.min(size, size * maxW / math.max(1, _textWidth(s, size)));
      return (size * 1.3, _textWidth(s, fs), (Canvas c, Offset at) => _text(c, s, at, size: fs, color: color));
    }

    List<_SplashLine> para(String s, double size, Color color) => [for (final l in _wrap(s, size, maxW)) text(l, size, color)];
    if (relic == null) {
      return [
        text(Words.shard, 18 * f, _dark),
        ...para('One free ${Words.reroll}, kept', 13 * f, _tipInk),
        if (g.serpihan > 0) text('You have: ${g.serpihan}', 13 * f, _dark),
      ];
    }
    final stars = g.cardStars(relic), owned = g.pusaka.containsKey(relic), ink = _rarityInk[relic.rarity]!;
    final type = g.cardType(relic), typeName = type == null ? null : troopTypeNames[type] ?? type;
    final st = 15 * f, step = st + 2 * f, rarity = rarityNames[relic.rarity]!, top = maxStars(relic);
    // It would wait (pusaka.dart): Oath of One with more types alive than its own, Oath of the Few with more troops.
    final waits = (relic == Relic.oathOfOne && g.typesAlive > oathOneK.types) || (relic == Relic.fewOath && g.armySize > fewOathK.army);
    // An owned one's Carve steps, kept by the star-up: their gold "+3" in the book's badge after the stars.
    final carve = g.pusaka[relic]?.ukir ?? 0, mark = ukirMark(carve), capFs = 11 * f;
    final capW = mark == null ? 0.0 : capsuleSize(_textWidth(mark, capFs), capFs).width + 3 * f;
    return [
      text(relicNames[relic]!, 18 * f, _dark),
      (20 * f, top * step + capW + 4 * f + _textWidth(rarity, 13 * f), (Canvas c, Offset at) {
        for (var j = 0; j < top; j++) {
          final to = Rect.fromLTWH(at.dx + j * step, at.dy - st / 2, st, st);
          if (j == stars - 1) c.drawCircle(to.center, st * 0.6, Paint()..color = _heroGold.withValues(alpha: 0.5));
          _uiIcon(c, j < stars ? _icStar : _icDarkStar, to);
        }
        if (mark != null) _capsule(c, '', capFs, Offset(at.dx + top * step + f, at.dy), anchor: Anchor.centerLeft, tail: mark);
        _text(c, rarity, Offset(at.dx + top * step + capW + 4 * f, at.dy), size: 13 * f, color: ink);
      }),
      for (final line in g.relicEffect(relic, stars: stars, ukir: carve)) ...para(line, 13 * f, _tipInk),
      if (relic.oath)
        text('New: all troops, whole run', 13 * f, _dark)
      else
        text(owned ? (typeName == null ? 'In ${Words.vault}' : 'On $typeName') : (typeName == null ? 'New: to ${Words.vault}' : 'New: for $typeName'),
            13 * f, _dark),
      if (waits) ...para('${oathWaitingOf(relic)} (now ${relic == Relic.fewOath ? g.armySize : g.typesAlive})', 13 * f, _blockedInk),
    ];
  }
}
