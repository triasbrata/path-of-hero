part of 'main.dart';

// The battle log (issue #60; the owner: "perlu di tambahkan fitur log dimana user bisa liat hal hal penting
// seperti ada pasukan yang mati, troops pakai skill, monster drop item, monster high level appear"). A button
// at the bottom right of the field (#80's re-layout, the owner: "log di pindah ke kanan bawah"; the pack's
// speech bubble on a pack button, a red count of the unread on it) opens a panel over it, opening upward: the
// game's events ([Game.log], game_events.dart), newest on top, an icon and a short English line each (decisions-log
// 197), with filter chips by kind. It stays open while playing: presses elsewhere go on
// to the field, so it can be read during a wave. The wheel or a drag on it scrolls it. It and the troop
// counter's list take turns: opening one folds the other. The Pusaka's proof (decisions-log 149): a line for each
// Grail save, a second row under a fall for the relics it sent back to the bag, and at a won wave a row for each
// bound Pusaka's counter, under their own chip ([logLines]: one event may take several rows).

/// ui_icons.png: the speech bubble (the log button), the dark heart (a troop fell), the crown, the trophy
/// (a wave won), the crossed swords (a strong monster), the full and the dark star.
const _icLog = Offset(0, 16), _icDarkHeart = Offset(32, 0), _icTrophy = Offset(80, 16), _icSwords = Offset(112, 16);
const _icStar = Offset(48, 0), _icDarkStar = Offset(80, 0);

/// A relic back in the bag (a fall's second row, a Pusaka report's last): pale gold.
const _backInk = Color(0xFFFFE9A8);

/// A Pusaka's colour on the log's dark panel: its ring's ([_pusakaColors]), but Void Eye's near black is its mark's
/// violet there, and Blood Fang's dried blood a lighter red.
Color _pusakaLogInk(Relic r) => switch (r) {
      Relic.voidEye => _violet,
      Relic.bloodFang => const Color(0xFFFF6F86), // its ring's dried blood is too dark on the log's panel
      _ => _pusakaColors[r] ?? _pusakaColorElse,
    };

/// The relic most sent back to the bag (the first by kind among equals).
Relic _mostBack(Map<Relic, int> back) => back.entries.reduce((a, b) => b.value > a.value || (b.value == a.value && b.key.index < a.key.index) ? b : a).key;

/// The filter chips over the log, and the kinds each shows.
enum _LogChip {
  all('All', EventKind.values), // the log holds no TraceEvents
  fell('Fallen', [EventKind.fell]),
  skill('Skill', [EventKind.skill, EventKind.heroSkill, EventKind.awakenSkill]),
  loot('Loot', [EventKind.drop]),
  pusaka(Words.artifact, [EventKind.grailSaved, EventKind.pusakaReport, EventKind.offerPicked, EventKind.pusakaAsah, EventKind.pusakaLebur]), // decisions-log 149, 152, 154, 164
  foe('Monsters', [EventKind.strongFoe, EventKind.monsterSkill, EventKind.omenGained, EventKind.omenEased, EventKind.omenDusk]), // decisions-log 180, 239
  rest('Other', [EventKind.heroMade, EventKind.heroRecalled, EventKind.awakened, EventKind.ascended, EventKind.tempa, EventKind.waveWon, EventKind.waveLost, //
    EventKind.townMarked, EventKind.townEntered, EventKind.townLeft, EventKind.crafted, EventKind.itemCrafted, //
    EventKind.stoneCrafted, EventKind.itemEnhanced, //
    EventKind.boostBought, EventKind.boostEnded, EventKind.boostSaved]); // decisions-log 216, 233, 249, 255, 268

  const _LogChip(this.label, this.kinds);
  final String label;
  final List<EventKind> kinds;
}

/// A monster type's name in the log, as its plate and the boss bars say it ([monsterTypeNames]: "Orc Rider").
String _monsterName(String type) => monsterTypeNames[type] ?? type;

/// A monster and its rank, the rank first ([tierNames]: "Mini Boss Orc Rider"); a normal one without its rank ("Orc").
String _foeName(String type, Tier? tier) => [if (tier != null && tier != Tier.normal) tierNames[tier]!, _monsterName(type)].join(' ');

/// The log's line for [e] (a Hero's or a monster's skill by its title).
String logLine(GameEvent e) => switch (e) {
      TroopFell(:final name, :final type, :final hero, :final killer, :final killerTier) =>
        '${hero ? 'Hero ' : ''}$name (${troopTypeNames[type] ?? type}) fell${killer == null ? '' : ' to ${_foeName(killer, killerTier)}'}',
      SkillCast(:final name, :final skill) => '$name uses $skill',
      HeroSkillCast(:final name, :final skill) => 'Hero $name: ${skill.title}',
      AwakenSkillCast(:final name, :final skill, :final level) => '$name uses ${skill.titleAt(level)}',
      LootDropped(:final from, :final tier, :final item, :final relic) =>
        '${_foeName(from, tier)} drops ${item != null ? itemNames[item] : relicNames[relic]}',
      StrongFoe(:final type, :final tier) => '${tierNames[tier]} appears: ${_monsterName(type)}',
      MonsterSkillCast(:final type, :final tier, :final skill) => '${_foeName(type, tier)}: ${skill.title}',
      HeroMade(:final name, :final type) => '$name (${troopTypeNames[type] ?? type}) is now a Hero!',
      HeroRecalled(:final name, :final type, :final cost) => '$name (${troopTypeNames[type] ?? type}) is back (${shortPrice(cost)} gold)',
      Awakened(:final type, :final level) =>
        '${troopTypeNames[type] ?? type}: ${awakenName(level)}${switch (awakenSkillOf(type)) { final s? => ' - ${s.titleAt(level)}', _ => '' }}',
      Ascended(:final type, :final level, :final cost) => '${troopTypeNames[type] ?? type}: ${awakenName(level)} (${shortPrice(cost)} gold)',
      Tempered(:final type, :final level, :final cost) => '${troopTypeNames[type] ?? type}: ${tempaName(level)} (${shortPrice(cost)} gold)',
      OfferPicked() => offerLine(e),
      PusakaAsah(:final relic, :final stars, :final type, :final cost) =>
        '${Words.sharpen}: ${relicNames[relic]} ★$stars ${_whereAt(type)} (${shortPrice(cost)} gold)',
      PusakaLebur(:final fodder, :final relic, :final stars, :final type, :final cost) =>
        '${Words.melt}: ${relicNames[fodder]} into ${relicNames[relic]} ★$stars ${_whereAt(type)} (${shortPrice(cost)} gold)',
      WaveEnded(:final wave, :final won) => won ? 'Wave $wave won' : 'Lost at wave $wave',
      GrailSaved(:final name, :final type, :final hero) =>
        '${pusakaShortName(Relic.grail)} saves ${hero ? 'Hero ' : ''}$name (${troopTypeNames[type] ?? type})',
      PusakaReport() => pusakaReportLines(e).firstOrNull ?? '',
      OmenGained(:final omen, :final level, :final from, :final chestWave) => switch (from) {
          'catchUp' => 'Late ${Words.shadow}: ${omen.title} $level',
          'ukir' => '${Words.carve}: monsters got ${omen.title} $level',
          _ => 'Monsters got ${omen.title} $level${chestWave == null ? '' : ' (${Words.bossChest} w$chestWave)'}',
        },
      OmenEased(:final omen, :final level) => '${Words.shadow} eased: ${omen.title} down to $level',
      OmenDusk(:final share) => '${OmenKind.dusk.title}: monsters (not bosses) deal ${omenPercent(share)}% more',
      TownMarked(:final slot) => '${Words.townAfter} ${slot - 1}', // town.dart
      TownEntered() => Words.town,
      TownLeft(:final crafts) => crafts.isEmpty ? 'Left town' : 'Left town: ${crafts.values.fold(0, (a, b) => a + b)} ${Words.crafted}',
      Crafted(:final relic, :final gold) => 'Crafted ${relicNames[relic]} (${thousands(gold)} gold)', // town.dart's Smithy
      ItemCrafted(:final item, :final gold) => 'Crafted ${itemNames[item]} (${thousands(gold)} gold)', // the forge's items
      StoneCrafted(:final stone, :final gold) => 'Crafted ${stone.label} (${thousands(gold)} gold)', // Enhance's stones
      ItemEnhanced(:final item, :final plus, :final gold) => '${Words.enhance}d ${itemNames[item]} to +$plus (${thousands(gold)} gold)',
      BoostBought(:final boost, :final type, :final effects, :final waves) => // the Tavern's (tavern.dart)
        '${boostNames[boost]}${type == null ? '' : ' (${troopTypePlurals[type] ?? type})'}: ${boostEffectLines(effects).join(', ')} ($waves waves)',
      BoostEnded(:final boost) => '${boostNames[boost]} ended',
      BoostSaved(:final boost) => '${boostNames[boost]}: no life lost',
      TraceEvent() => '', // the telemetry's only: never in the log
    };

/// Where a Sharpen's or a Melt's Pusaka is: "in Vault", or "on Templar".
String _whereAt(String? type) => type == null ? 'in ${Words.vault}' : 'on ${troopTypeNames[type] ?? type}';

/// Every row [e] takes in the log (decisions-log 149): its line ([logLine]); for a fall that sent relics back to the
/// bag a second row, "Fury back in the Bag", and for an Asah the small relics it took, "Thorns 8, Fury 2 from the Bag"
/// (decisions-log 154); for a full army's recall the troop it sent home, "Kira Thorn goes home (+6k gold)"
/// (decisions-log 167); for a won wave's Pusaka report a row each ([pusakaReportLines]).
List<String> logLines(GameEvent e) => switch (e) {
      TroopFell(:final relics) when relics.isNotEmpty => [logLine(e), '${relics.map((r) => relicNames[r]).join(', ')} back in the ${Words.bag}'],
      PusakaAsah(:final relics) when relics.isNotEmpty => [logLine(e), '${asahTakeLine(relics)} from the ${Words.bag}'],
      PusakaLebur(:final relics) when relics.isNotEmpty => [logLine(e), '${asahTakeLine(relics)} from the ${Words.bag}'],
      HeroRecalled(:final swapped?, :final refund) => [logLine(e), '$swapped goes home (+${shortPrice(refund)} gold)'],
      PusakaReport() => pusakaReportLines(e),
      _ => [logLine(e)],
    };

/// How many rows [e] takes in the log ([logLines]), without making them.
int _logRowsOf(GameEvent e) => switch (e) {
      TroopFell(:final relics) => relics.isEmpty ? 1 : 2,
      PusakaAsah(:final relics) || PusakaLebur(:final relics) => relics.isEmpty ? 1 : 2,
      HeroRecalled(:final swapped) => swapped == null ? 1 : 2,
      PusakaReport(:final lines, :final relics, :final returned) => lines.length + relics.length + (returned.isEmpty ? 0 : 1),
      _ => 1,
    };

/// The battle log's state between frames.
class _BattleLog {
  bool open = false;
  Rect button = Rect.zero, panel = Rect.zero; // where they were last drawn (the panel while open)
  var chip = _LogChip.all;
  double scroll = 0; // how far down from the newest, in px
  int seen = 0; // the log's total when it was last looked at: the rest are unread
  bool tapped = false; // the last press landed on the button or the open panel: its tap up stays there
  double? dragY; // a drag scrolling it, where the pointer was
}

extension on Board {
  /// A press: on the button it opens or closes the log (and folds the troop counter's list); on the open
  /// panel it is the panel's (its chips are buttons). True when it toggled the log: nothing else then.
  bool _logDown(Offset p) {
    final l = _log;
    if (l.button.contains(p)) {
      l.open = !l.open;
      if (l.open) _troops.open = false;
      return l.tapped = true;
    }
    l.tapped = l.open && l.panel.contains(p);
    return false;
  }

  /// Book buttons [r] (as drawn this frame) that the open battle log keeps clear of ([_battleLog]), the book's whole
  /// bob up and down, so the panel's edge stays still while the book bobs.
  void _keepFromLog(Rect r) => _logKeep.add(Rect.fromLTRB(r.left, r.top - _bookBob - _bookBobK, r.right, r.bottom - _bookBob + _bookBobK));

  /// The wheel over the open panel scrolls it.
  void _logWheel(Offset p, double dy) {
    if (_log.open && _log.panel.contains(p)) _log.scroll += dy;
  }

  /// The log's button at the bottom right of the field and, while open, its panel over it, opening upward and
  /// right-aligned with it: its top under the wave meter, the map and the boss bars. Gone after a game over.
  void _battleLog(Canvas c, Game g) {
    final l = _log, k = _meterK, pad = 2 * k;
    if (g.log.total < l.seen) l.seen = 0; // another game came in
    if (l.open) l.seen = g.log.total;
    l.button = l.panel = Rect.zero;
    if (g.over) return;
    final b = Rect.fromLTWH(size.x - _edgeR - _meterH, size.y - _edgeB - _meterH, _meterH, _meterH);
    l.button = b.inflate(pad);
    final sink = _button(c, b, () {}, active: l.open); // the press is taken in [_logDown]
    _uiIcon(c, _icLog, Rect.fromCenter(center: b.center + Offset(0, sink - k), width: 8 * k, height: 8 * k));
    final unread = g.log.total - l.seen;
    if (!l.open && unread > 0) {
      // On its top left corner: the right one is at the screen's edge.
      final badge = '${math.min(unread, 99)}', r = 4 * k;
      final at = Offset(b.left + k, b.top + k), w = math.max(2 * r, _textWidth(badge, 4 * k) + 2 * k);
      c.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: at, width: w, height: 2 * r), Radius.circular(r)),
          Paint()..color = const Color(0xFFD8342A));
      _text(c, badge, at, size: 4 * k, anchor: Anchor.center);
    }
    if (!l.open) return;

    // The panel: chips on top, the rows under them, newest first, clipped and scrolled. Up to 330 tall, less where the
    // top right's pieces come down: the wave meter, the map and the boss bars under it (the bars not while they are at
    // the left). It keeps room for the chips and a row, over them if it must.
    final floor = [
          _meterAt.bottom,
          _map.at.bottom,
          if (!_asideLeft) _omenRow.at.bottom, // the Shadows' chips (omen_look.dart)
          _townChipAt.bottom, // the Town chip, under the meter even while the book shows (town_look.dart)
          _boostRowAt.bottom, // the boosts' chips under it (tavern_look.dart)
          if (!_bossAside) _bossAt.bottom,
        ].reduce(math.max) +
        pad;
    final w = math.min(340.0, size.x * 0.25).roundToDouble();
    final most = math.min(size.y * 0.5, 330.0), least = 3 * pad + 7 * k + 9 * k;
    var bottom = b.top - pad;
    // The spawn bar's controls as drawn (spawn_bar.dart, drawn before it: the hotbar and its arrows, +Room, Auto Buy,
    // on the step since decisions-log 287) under its span: its bottom never comes over them, so it hides none of them
    // by the log's button. The step's own ground it may cover.
    final bar = _bar, auto = bar.auto == Rect.zero ? Rect.zero : bar.auto.deflate(_meterK); // Auto Buy's face
    for (final r in [bar.list, bar.roomFace, auto]) {
      if (r != Rect.zero && r.right > b.right - w && r.left < b.right) bottom = math.min(bottom, r.top);
    }
    var top = math.min(math.max(bottom - most, floor), bottom - least).roundToDouble();
    // The book's buttons it would hide ([_logKeep]: the Shop card's Buy and Sell, the Bag page's Sell strip) stay
    // clear: one in its lower half lifts its bottom above it, one in its upper half takes its top below it. The chips
    // and a row stay, over a button if they must.
    for (final keep in _logKeep) {
      if (!keep.overlaps(Rect.fromLTRB(b.right - w, top, b.right, bottom))) continue;
      if (keep.center.dy > (top + bottom) / 2) {
        bottom = (keep.top - pad).roundToDouble();
      } else {
        top = (keep.bottom + pad).roundToDouble();
      }
    }
    top = math.min(top, bottom - least);
    final panel = Rect.fromLTRB(b.right - w, top, b.right, bottom);
    l.panel = panel;
    _panel(c, panel);
    final chipH = (7 * k).roundToDouble(), chipGap = k;
    final chipW = ((panel.width - 2 * pad - chipGap * (_LogChip.values.length - 1)) / _LogChip.values.length).floorToDouble();
    for (final (i, chip) in _LogChip.values.indexed) {
      final r = Rect.fromLTWH(panel.left + pad + i * (chipW + chipGap), panel.top + pad, chipW, chipH);
      _button(c, r, () {
        l
          ..chip = chip
          ..scroll = 0;
      }, active: l.chip == chip, label: chip.label, size: math.min(4.5 * k, chipW / 4.8));
    }
    final list = Rect.fromLTRB(panel.left + pad, panel.top + 2 * pad + chipH, panel.right - pad, panel.bottom - pad);
    final rows = [
      for (final e in g.log.newestFirst)
        if (l.chip.kinds.contains(e.kind))
          for (var i = 0; i < _logRowsOf(e); i++) (e, i), // an event's rows top down (logLines)
    ];
    final rowH = 9 * k, icon = 6 * k, ts = math.max(5 * k, 11.0), waveW = _textWidth('88', ts * 0.8) + 2 * k;
    l.scroll = l.scroll.clamp(0.0, math.max(0.0, rows.length * rowH - list.height));
    c.save();
    c.clipRect(list);
    if (rows.isEmpty) {
      _text(c, 'Nothing yet', list.topLeft + Offset(k, rowH / 2), size: ts, color: const Color(0x99FFF1D6));
    }
    final first = (l.scroll / rowH).floor(), last = math.min(rows.length, ((l.scroll + list.height) / rowH).ceil());
    for (var i = first; i < last; i++) {
      final (e, row) = rows[i];
      final y = list.top + i * rowH - l.scroll, mid = y + rowH / 2;
      // A faint line between events; an event's later rows (row > 0) are indented under its first, without the wave.
      if (i > 0 && row == 0) c.drawRect(Rect.fromLTWH(list.left, y, list.width, math.max(1.0, k / 2)), Paint()..color = const Color(0x448A5E34));
      if (row == 0) _text(c, '${e.wave}', Offset(list.left + waveW - k, mid), size: ts * 0.8, color: const Color(0x99FFF1D6), anchor: Anchor.centerRight);
      final at = Rect.fromLTWH(list.left + waveW + k + (row > 0 && e is TroopFell ? 3 * k : 0), mid - icon / 2, icon, icon);
      _logIcon(c, e, at, row);
      final x = at.right + 2 * k;
      _text(c, _fit(row == 0 ? logLine(e) : logLines(e)[row], ts, list.right - x), Offset(x, mid), size: ts, color: _logInk(e, row));
    }
    c.restore();
  }

  /// [t] cut to [maxW] at [size], ".." marking the cut.
  String _fit(String t, double size, double maxW) {
    if (_textWidth(t, size) <= maxW) return t;
    var n = t.length;
    while (n > 1 && _textWidth('${t.substring(0, n)}..', size) > maxW) {
      n--;
    }
    return '${t.substring(0, n)}..';
  }

  /// The first of [words] that fits [room] at [size], else the last cut to it ([_fit]).
  String _fitFirst(List<String> words, double size, double room) =>
      words.firstWhere((w) => _textWidth(w, size) <= room, orElse: () => _fit(words.last, size, room));

  /// An event's icon on its [row] ([logLines]): the dark heart for a fall (on its second row the relic it sent back), the
  /// MP bolt for a skill, a Hero skill's mark, a star in the level's colour for an awakening skill (#88) and for an
  /// awakening, what dropped, the crossed swords for a strong monster or a monster's skill, the crown for a new Hero,
  /// the trophy for a won wave and the dark star for a lost one; the Grail's for a save, an Asah's Pusaka (on its second
  /// row the small relic it took first), and on a Pusaka report each row's Pusaka, then each forge relic's own (the
  /// last row's: the relic most sent back); the Town's hammer for a Town marked, gone into or left; the relic or the item the Smithy crafted.
  void _logIcon(Canvas c, GameEvent e, Rect to, [int row = 0]) => switch (e) {
        TroopFell(:final relics) when row > 0 => _icon(c, relics.first, to), // what went back to the bag
        TroopFell() => _uiIcon(c, _icDarkHeart, to),
        GrailSaved() => _icon(c, Relic.grail, to),
        PusakaAsah(:final relics) || PusakaLebur(:final relics) when row > 0 => _icon(c, relics.keys.first, to), // the most taken from the bag
        PusakaAsah(:final relic) || PusakaLebur(:final relic) => _icon(c, relic, to),
        PusakaReport(:final lines, :final relics, :final returned) => _icon(
            c,
            row < lines.length
                ? lines[row].relic
                : row < lines.length + relics.length
                    ? relics[row - lines.length].relic // a forge relic's row: its own icon
                    : _mostBack(returned),
            to),
        SkillCast() => c.drawImageRect(_img('ui_icons.png'), _boltIcon, to, _mpPaint),
        HeroSkillCast(:final skill) => _heroMarkIcon(c, skill.mark, to),
        AwakenSkillCast(:final level) || Awakened(:final level) || Ascended(:final level) =>
          c.drawImageRect(_img('ui_icons.png'), _icStar & const Size(16, 16), to, level == maxAwaken ? _px : _awakeFxPaints[level - 1]),
        Tempered() => c.drawImageRect(_img('ui_icons.png'), _icStar & const Size(16, 16), to, _awakeFxPaints[tempaFrom - 1]), // Bangkit 5's white
        LootDropped(:final item, :final relic) => _icon(c, (item ?? relic)!, to),
        StrongFoe() || MonsterSkillCast() => _uiIcon(c, _icSwords, to),
        HeroMade() || HeroRecalled() => _uiIcon(c, _icCrown, to),
        OfferPicked(:final pick) => pick == null ? _uiIcon(c, _icChest, to) : _icon(c, pick, to), // chest_popup.dart
        WaveEnded(:final won) => _uiIcon(c, won ? _icTrophy : _icDarkStar, to),
        OmenGained(:final omen) || OmenEased(:final omen) => _omenIcon(c, state, omen, to), // omen_look.dart
        OmenDusk() => _omenIcon(c, state, OmenKind.dusk, to),
        TownMarked() || TownEntered() || TownLeft() => _townMark(c, to), // the Town's hammer (town_look.dart)
        Crafted(:final relic) => _icon(c, relic, to), // the relic the Smithy made
        ItemCrafted(:final item) => _icon(c, item, to), // the item the Smithy made (decisions-log 249)
        StoneCrafted(:final stone) => _icon(c, stone, to), // the stone the Smithy made (decisions-log 255)
        ItemEnhanced(:final item) => _icon(c, item, to), // the item enhanced (decisions-log 255)
        BoostBought(:final boost, :final type) || BoostEnded(:final boost, :final type) => _boostIcon(c, boost, type, to), // its own (tavern_page.dart)
        BoostSaved(:final boost) => _boostIcon(c, boost, null, to),
        TraceEvent() => null, // never in the log
      };

  /// An event line's colour on its [row]: a fall and a lost wave red, a Hero's gold, a strong monster (or its skill) in
  /// its rank's colour, an awakening in its level's, a won wave green, a Grail save, an Asah and a Pusaka's report row
  /// in the Pusaka's colour ([_pusakaLogInk]), a forge relic's report row and the relics back in the bag (or an Asah took
  /// from it) pale gold, the rest cream.
  Color _logInk(GameEvent e, [int row = 0]) => switch (e) {
        TroopFell() || PusakaAsah() || PusakaLebur() when row > 0 => _backInk,
        GrailSaved() => _pusakaLogInk(Relic.grail),
        PusakaAsah(:final relic) || PusakaLebur(:final relic) => _pusakaLogInk(relic),
        PusakaReport(:final lines) => row < lines.length ? _pusakaLogInk(lines[row].relic) : _backInk, // the small relics' rows pale gold
        TroopFell() || WaveEnded(won: false) => const Color(0xFFFF8A80),
        HeroSkillCast() || HeroMade() || HeroRecalled() => _heroPop,
        OfferPicked(:final pick?) => _rarityInk[pick.rarity]!,
        StrongFoe(:final tier) || MonsterSkillCast(:final tier) => _tierBar[tier]?.$1 ?? Colors.white,
        Awakened(:final level) || Ascended(:final level) => _awakeColors[level - 1],
        Tempered() => _awakeColors[tempaFrom - 1],
        WaveEnded(won: true) => const Color(0xFF9BE37A),
        _ => const Color(0xFFFFF1D6),
      };
}
