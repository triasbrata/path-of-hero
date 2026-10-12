part of 'main.dart';

// The Pusaka seen in battle (P2 "Bukti", decisions-log 149; ui-hud.md "The Pusaka in battle"). The owner, 2026-10-01:
// "sekarang user bener bener nga ada ngerasa apapun dari penggunaan artefaknya". P1a (pusaka.dart) made the Pusaka
// strong and type-wide; this makes that strength seen:
// - a 1 px ring in the Pusaka's colour under the feet of every troop of a bound type, and its icon left of the HP bar;
// - the Grail's cut-in, once a wave, on its first save ("Grail saves Kael Drake!"): short, and it takes no
//   press;
// - the type's build name ("Undying Templar", [Pusaka.buildNameOf]) on its Army row and its troops' plates;
// - the battle log's lines for a save, a relic back in the bag and the wave's report (battle_log.dart), and one line
//   on "VICTORY!" naming the wave's best counter ([pusakaWinLine]).
// The field's two are drawn for 32+ troops every frame, so they allocate no Paint: each bound type's Pusaka is looked
// up once a frame ([_PusakaLook.refresh]) and every ring is one of the paints below.

/// Each Pusaka's colour: its ring on the field and its line in the log. Kept off the awakening's blue, crimson, gold,
/// violet and white ([_awakeColors]) and off the grass's green, so a ring never reads as an awakened troop's.
const _pusakaColors = <Relic, Color>{
  Relic.dragonHeart: Color(0xFFFF6A1F), // ember orange
  Relic.dawnStar: Color(0xFFFF7FD0), // dawn pink
  Relic.godThunder: Color(0xFFFFF04A), // its leaps' lemon
  Relic.grail: Color(0xFF3FE6FF), // holy water
  Relic.voidEye: Color(0xFF1A0A2E), // the void: all but black
  // The chest's Langka (draft.dart, decisions-log 152).
  Relic.ironBanner: Color(0xFF9AA8BC), // iron grey
  Relic.bloodFang: Color(0xFF8E0E2A), // dried blood: darker than the awakening's crimson
  Relic.warDrum: Color(0xFFC98A4B), // the drum's skin
  Relic.mourningBell: Color(0xFFB4A7D6), // mourning lilac: greyer than the awakening's violet
  // The Legenda on a type (pusaka.dart, decisions-log 155); the oaths are the whole army's, so no ring marks them.
  Relic.dragonCrown: Color(0xFF2FD6A0), // jade: bluer than the grass, greener than the Grail
};

/// The same, dark enough for text on the book's page and the plates' tan: the build name.
const _pusakaInk = <Relic, Color>{
  Relic.dragonHeart: Color(0xFFB8420A),
  Relic.dawnStar: Color(0xFFB0307E),
  Relic.godThunder: Color(0xFF7A6800),
  Relic.grail: Color(0xFF0A7C96),
  Relic.voidEye: Color(0xFF3A1A5E),
  Relic.ironBanner: Color(0xFF4E5A6E),
  Relic.bloodFang: Color(0xFF7A0C24),
  Relic.warDrum: Color(0xFF7A4A14),
  Relic.mourningBell: Color(0xFF5E4E86),
  Relic.dragonCrown: Color(0xFF0B7A5A),
};

/// The paints of the tinted icons ([IconRef.tint]: catalog-design §2.6's tints), each made once, on its first draw.
final _iconTints = <int, Paint>{};

Paint _tintedPaint(Color c) => Paint()
  ..filterQuality = FilterQuality.none
  ..colorFilter = _tint(c);

/// A Pusaka without a colour of its own above: cream on the field, the book's ink on the page.
const _pusakaColorElse = Color(0xFFFFF1D6), _pusakaInkElse = Color(0xFF4A2C17);

/// The ring under a bound type's troops: 1 px, a little wider than a skill's ring ([_guardRing] 16, the effects' 18), so
/// those sit inside it. In the sprites' pixels (decisions-log 325): [pixelRingCells], one world unit a cell.
const _pusakaRingSize = Size(20, 8);

/// The cells of a 1 px oval [w] × [h] in the sprites' pixels (decisions-log 325), each (column, row) from the box's top
/// left: every cell whose middle is inside the oval and one of whose four neighbours' is not. Its edge steps like the
/// units' shadows (`tiny_<type>_shadow.png`) and is never two cells thick.
List<(int, int)> pixelRingCells(int w, int h) {
  bool inside(int i, int j) {
    final x = (i + 0.5) / w * 2 - 1, y = (j + 0.5) / h * 2 - 1;
    return i >= 0 && i < w && j >= 0 && j < h && x * x + y * y <= 1;
  }

  return [
    for (var j = 0; j < h; j++)
      for (var i = 0; i < w; i++)
        if (inside(i, j) && !(inside(i - 1, j) && inside(i + 1, j) && inside(i, j - 1) && inside(i, j + 1))) (i, j),
  ];
}

/// The ring's image, built in memory once ([TdGame.onLoad], [_pixelRing]): [pixelRingCells] of [_pusakaRingSize] in
/// white, with a clear pixel all round.
const _pusakaRingImage = 'pusaka_ring';

/// Where the ring's image goes from a troop's feet: its box centred 1 above them, less its clear border. Whole world
/// units, as a sprite's pixels are from its feet ([_feet]), so its steps fall on the shadow's at any zoom.
const _pusakaRingAt = Offset(-11, -6);

/// [pixelRingCells] of [w] × [h] in white, framed by a clear pixel all round: the quad's own edges then fall on clear
/// pixels, so nothing at its border blends either.
Future<ui.Image> _pixelRing(int w, int h) {
  final px = Uint8List((w + 2) * (h + 2) * 4);
  for (final (i, j) in pixelRingCells(w, h)) {
    final at = ((j + 1) * (w + 2) + i + 1) * 4;
    px.fillRange(at, at + 4, 255);
  }
  final done = async.Completer<ui.Image>();
  ui.decodeImageFromPixels(px, w + 2, h + 2, ui.PixelFormat.rgba8888, done.complete);
  return done.future;
}

/// The rings' paints, one per Pusaka, made once: the ring's white image flat in the Pusaka's colour ([_flat]) at 90%,
/// nearest and without anti-aliasing, so every pixel is the colour or nothing.
final _pusakaRings = {for (final MapEntry(:key, :value) in _pusakaColors.entries) key: _ringPaint(value)};
final _pusakaRingElse = _ringPaint(_pusakaColorElse);

Paint _ringPaint(Color c) => Paint()
  ..filterQuality = FilterQuality.none
  ..isAntiAlias = false
  ..colorFilter = _flat(c)
  ..color = Colors.white.withValues(alpha: 0.9);

/// How long the Grail's cut-in shows (seconds on the screen's clock), and the share of it that fades in, and out.
const grailCutTime = 1.6, _grailFadeIn = 0.12, _grailFadeOut = 0.25;

/// The "VICTORY!" line ([pusakaWinLine]) fits this wide (a phone's field), from [_winLineSize] down to [_winLineMin].
const winLineMaxW = 361.0, _winLineSize = 18.0, _winLineMin = 12.0;

/// The Pusaka between frames: each bound type's Pusaka this frame ([types]), the build name the Army page drew
/// this frame and where ([rows], for tests), and the Grail's cut-in showing ([cutName], since [cutSince] on the screen's
/// clock; null: none).
class _PusakaLook {
  final types = <String, Relic>{};
  final rows = <String, (String, Rect)>{};
  String? cutName;
  double cutSince = 0;

  /// Once a frame, before the field: which type holds which Pusaka, so a troop finds its own in one lookup.
  void refresh(Game g) {
    types.clear();
    rows.clear();
    for (final MapEntry(key: r, value: p) in g.pusaka.entries) {
      if (p.type case final t?) types[t] = r;
    }
  }
}

/// The "VICTORY!" line for won wave [r] (decisions-log 149; the design's critique M4: the popup lasts [victoryTime], so
/// one line): the best counter ([PusakaReport.best]) and the small relics back in the bag. "Artifact: Grail 6 saved ·
/// Back to Bag: Fury ×2"; either part alone; null with neither. Only glyphs the HUD's font has (no "★").
String? pusakaWinLine(PusakaReport r) {
  final best = r.best, back = _returnedText(r.returned);
  final parts = [
    if (best != null) '${Words.artifact}: ${pusakaShortName(best.relic)} ${pusakaCounter(best)}',
    if (back != null) '$_backToBag: $back',
  ];
  return parts.isEmpty ? null : parts.join(' · ');
}

/// The small relics' row in a report and on the "VICTORY!" line: "Back to Bag: Fury ×2".
const _backToBag = 'Back to ${Words.bag}';

/// [n] [word]s: "1 hit", "4 hits".
String _count(int n, String word) => '$n $word${n == 1 ? '' : 's'}';

/// What [d]'s counter says, short, by its family ([fxFamily]): "6 saved" (saves kept: the Grail's), "4 hits lived"
/// (blows lived through: Dragon Heart's), "+5k blocked" (damage kept off: Iron Banner's, the HP Dragon Crown's cuts
/// kept), "+3.2k HP" (healing: Blood Fang's, Mourning Bell's), "+12.3k" / "+32k" (the damage or healing added: Dawn
/// Star, God's Thunder, Void Eye, War Drum), "x12" (the times a status took hold: Snare Cord's; it adds no worth, so
/// "VICTORY!" never names it), "+40 MP" (Mana Leech, Pain Crystal), "+120 gold" (Looter's Pouch; neither of the two is
/// ever "VICTORY!"'s, [PusakaReport.best]).
String pusakaCounter(PusakaDone d) => switch (fxFamily(d.relic)) {
      FxFamily.saves => '${d.worth.round()} saved',
      FxFamily.survived => '${_count(d.worth.round(), 'hit')} lived',
      FxFamily.keptOff => '+${_counterNum(d.worth)} blocked',
      FxFamily.healed => '+${_counterNum(d.worth)} HP',
      FxFamily.added || null => '+${_counterNum(d.worth)}',
      FxFamily.applied => 'x${d.uses}',
      FxFamily.mana => '+${_counterNum(d.worth)} ${fxWords.mp}',
      FxFamily.gold => '+${_counterNum(d.worth)} gold',
    };

/// A counter's amount, short: 940 as is, 1234 as "1.2k", 32049 as "32k" (no ".0"), 150000 as "150k".
String _counterNum(double v) {
  final n = v.round();
  if (n < 1000) return '$n';
  final k = n / 1000, s = k >= 100 ? '${k.round()}' : k.toStringAsFixed(1);
  return '${s.endsWith('.0') ? s.substring(0, s.length - 2) : s}k';
}

/// The battle log's rows for won wave [r]'s report, one a Pusaka, one each of the forge's small relics that did
/// something ([relicCounter]) and one for the relics back in the bag: "Grail (Axeman): 6 saves, 4 lived", "Dragon Heart
/// (Templar): 3 hits lived", "God's Thunder (Wizard): +12.3k damage", "Dawn Star (Priest): +5k damage & heal", "Shark
/// Tooth: +1.2k damage", "Chill: slowed 12 times", "Back to Bag: Fury ×2, Fang".
List<String> pusakaReportLines(PusakaReport r) => [
      for (final d in r.lines) '${pusakaShortName(d.relic)} (${troopTypeNames[d.type] ?? d.type}): ${_counterLong(d)}',
      for (final d in r.relics) '${relicNames[d.relic]}: ${relicCounter(d)}',
      if (_returnedText(r.returned, all: true) case final back?) '$_backToBag: $back',
    ];

/// What one of the forge's small relics did in a wave, in the log's words (decisions-log 250): only its own counter,
/// never another relic or an Artifact. Chill the slows it put ("slowed 12 times"), Weak Spot its marks and what they
/// added ("marked 9 times, +800 damage"), the others the damage they added ("+1.2k damage").
String relicCounter(RelicDone d) {
  String times(int n) => n == 1 ? 'once' : '$n times';
  return switch (d.relic) {
    Relic.chill => 'slowed ${times(d.uses)}',
    Relic.weakSpot => 'marked ${times(d.uses)}, +${_counterNum(d.worth)} damage',
    _ => '+${_counterNum(d.worth)} damage',
  };
}

/// [d]'s counter in the log's words, by its first Fx's trigger and effect (pusaka_catalog.dart): the saves and how many
/// were kept (the Grail), the blows lived through (Dragon Heart), the damage and healing an attack stat added (Dawn
/// Star), the damage a cut kept off (Iron Banner), the HP drawn from blows (Blood Fang), how often a fall tolled and
/// what it healed (Mourning Bell), how many blows a cap cut and the HP that kept (Dragon Crown), how often a status
/// took hold ("slowed 12 times": Snare Cord, Dulling Mail, Challenge Letter; "stripped 3 times": Spell Cutter), what a
/// shield kept off (Watch Shield, Bone Buckler, Full Cup), the MP or gold it gave (Mana Leech, Pain Crystal, Looter's
/// Pouch), the bad effects a cleanse ended (Salt Charm, Pure Water), what a kill's heal, a flask or a regen healed (Wolf
/// Feast, Hidden Flask, Living Moss), what a defence kept off (Stone Coat), the MP a quicker regen gave (Moonwell), the
/// attacks from past the old range (Hawk Feather), how often a skill's might came ("powered up 4 times": Rune Gauntlet;
/// a fall's on the troops near: Fallen Flag; a heal's: Brave Song), the shoves a stand held ("stood firm 3 times":
/// Anchor), the MP a heal gave (Mana Hymn), the bad effects a skill's cleanse ended (Saint's Tear), what a heal's spread,
/// a low troop's bigger heals, a wave's end, a few hits or a skill healed (Halo Lantern, Mercy Lily, Hearth, Heartbeat,
/// Bright Spring), the blows that missed (Ghost Step), what the small relics did more (Relic Altar), the monsters held
/// ("held 5 times": Ice Grip), what a link took for the troops near (Guardian Chain), the troops a fall sheltered and
/// what that kept off (Soul Shelter), the troops brought back (Phoenix Plume), the monsters hexed ("hexed 3 times": Hex
/// Blade; a strong kill's might: Glory Seeker, "powered up"), what a blow's heal gave the most hurt troop near (Vampire
/// Kiss), the monster heals a seal stopped (Grave Seal), else the damage (a heal's smite: Wrath Psalm; a spent mark's: Ember Brand; a kill's
/// burst: Funeral Pyre; a mark's, a fall's burst, a splash, a reflect, a power: Vengeance Mark, Martyr's Flame, Wide
/// Blows, Mirror Shield, Lone Wolf Pelt, Champion's Mantle, Rage Totem; Vow of Silence's with its heals).
String _counterLong(PusakaDone d) => switch (pusakaCatalog[d.relic]?.fx.firstOrNull) {
      Fx(eff: Eff.save) => '${_count(d.uses, 'save')}, ${d.worth.round()} lived',
      Fx(on: Trig.always, eff: Eff.stat, stat: Stat.hp) => pusakaCounter(d),
      Fx(on: Trig.always, eff: Eff.stat, stat: Stat.dmg || Stat.hpDmg) => '${pusakaCounter(d)} damage & heal',
      Fx(eff: Eff.cut || Eff.ward) ||
      Fx(on: Trig.always, eff: Eff.stat, stat: Stat.def) ||
      Fx(eff: Eff.status, status: Status.block) =>
        '+${_counterNum(d.worth)} damage blocked',
      Fx(eff: Eff.relicK) => '${pusakaCounter(d)} from relics', // Relic Altar: what its × added
      Fx(on: Trig.always, eff: Eff.stat, stat: Stat.mpRegen) => pusakaCounter(d),
      Fx(on: Trig.always, eff: Eff.stat, stat: Stat.range) => '${_count(d.uses, 'hit')} past its old range',
      Fx(eff: Eff.mp || Eff.gold) => pusakaCounter(d),
      Fx(eff: Eff.strip) => 'stripped ${d.uses == 1 ? 'once' : '${d.uses} times'}',
      Fx(on: Trig.dealt, eff: Eff.heal, to: To.mostHurtNear) => '${pusakaCounter(d)} to the most hurt', // Vampire Kiss
      Fx(on: Trig.dealt, eff: Eff.heal) => '${pusakaCounter(d)} drained',
      Fx(on: Trig.fell, eff: Eff.heal) => 'rang ${d.uses == 1 ? 'once' : '${d.uses} times'}, ${pusakaCounter(d)}',
      Fx(on: Trig.kill, eff: Eff.heal) => '${pusakaCounter(d)} from kills',
      Fx(on: Trig.struck, eff: Eff.heal) => 'drunk ${d.uses == 1 ? 'once' : '${d.uses} times'}, ${pusakaCounter(d)}',
      Fx(on: Trig.always, eff: Eff.stat, stat: Stat.regen) => pusakaCounter(d),
      Fx(eff: Eff.cleanse) => 'cleared ${_count(d.uses, 'bad effect')}',
      Fx(on: Trig.heals, eff: Eff.heal, to: To.nearTroops) => '${pusakaCounter(d)} to troops near', // Halo Lantern
      Fx(on: Trig.heals, eff: Eff.heal, to: To.self) => '${pusakaCounter(d)} more healed', // Mercy Lily
      Fx(on: Trig.waveEnd, eff: Eff.heal) => '${pusakaCounter(d)} at wave end', // Hearth
      Fx(on: Trig.attack, eff: Eff.heal) => '${pusakaCounter(d)} from hits', // Heartbeat
      Fx(on: Trig.cast, eff: Eff.heal) => '${pusakaCounter(d)} from ${fxWords.skill}s', // Bright Spring
      Fx(eff: Eff.cap) => '${_count(d.uses, 'hit')} cut, +${_counterNum(d.worth)} HP kept',
      // Batch G-2's (decisions-log 238).
      Fx(eff: Eff.status, status: Status.link) => 'took +${_counterNum(d.worth)} for troops near', // Guardian Chain
      Fx(eff: Eff.status, status: Status.cap) => 'sheltered ${_count(d.uses, 'troop')}, +${_counterNum(d.worth)} blocked', // Soul Shelter
      Fx(eff: Eff.revive) => 'brought back ${_count(d.uses, 'troop')}', // Phoenix Plume
      // Batch G-3's (decisions-log 243); Wrath Psalm's smites are its damage (the last line).
      Fx(eff: Eff.noHeal) => 'stopped +${_counterNum(d.worth)} monster heals', // Grave Seal
      Fx(eff: Eff.status, :final status?) when _statusDone.containsKey(status) =>
        '${_statusDone[status]} ${d.uses == 1 ? 'once' : '${d.uses} times'}',
      _ => '${pusakaCounter(d)} damage',
    };

/// What a status Pusaka did to a monster, in the log's words ([_counterLong]).
const _statusDone = {
  Status.slow: 'slowed',
  Status.weaken: 'weakened',
  Status.taunt: 'taunted',
  Status.might: 'powered up',
  Status.noShove: 'stood firm', // the shoves it stood (Anchor)
  Status.impaled: 'held', // the monsters it held, the bosses it slowed (Ice Grip)
  Status.hex: 'hexed', // the monsters it turned into slimes (Hex Blade)
};

/// The Grail's cut-in's words for the troop it saved, [name]: "Grail saves Kael Drake!".
String _grailCutLine(String name) => '${pusakaShortName(Relic.grail)} saves $name!';

/// The small relics back in the bag, most first: "Fury ×2, Fang"; past two kinds "+n" more ([all]: every kind).
String? _returnedText(Map<Relic, int> back, {bool all = false}) {
  if (back.isEmpty) return null;
  final kinds = back.entries.toList()..sort((a, b) => b.value != a.value ? b.value - a.value : a.key.index - b.key.index);
  final shown = all ? kinds : kinds.take(2);
  final rest = kinds.skip(shown.length).fold(0, (n, e) => n + e.value);
  return [for (final e in shown) '${relicNames[e.key]}${e.value > 1 ? ' ×${e.value}' : ''}', if (rest > 0) '+$rest'].join(', ');
}

extension on Board {
  /// Under troop [u]'s feet ([ground]), drawn after its shadow: its type's Pusaka's ring, while it lives.
  void _pusakaRing(Canvas c, Unit u, Offset ground) {
    if (u.side != Side.troop || !u.alive) return;
    final r = _pusakaLook.types[u.type];
    if (r == null) return;
    _ringUnder(c, ground, r);
  }

  /// [r]'s ring round the feet at [ground] (the field's, the guide's pictures): the ring's image ([_pusakaRingImage]) at
  /// [_pusakaRingAt], in [r]'s paint.
  void _ringUnder(Canvas c, Offset ground, Relic r) =>
      c.drawImage(_img(_pusakaRingImage), ground + _pusakaRingAt, _pusakaRings[r] ?? _pusakaRingElse);

  /// Left of troop [u]'s HP bar ([box]), past the small relics it holds: its type's Pusaka's icon.
  void _pusakaBarIcon(Canvas c, Unit u, Rect box) {
    if (u.side != Side.troop) return;
    if (_pusakaLook.types[u.type] case final r?) _icon(c, r, Rect.fromLTWH(box.left - 6.5 - 6.5 * u.relics.length, box.center.dy - 3, 6, 6));
  }

  /// Every frame: the wave's first Grail save ([Game.grailFirst]) starts its cut-in, and one that has shown
  /// [grailCutTime] ends.
  void _grailNews(Game g) {
    if (_pusakaLook.cutName != null && _clock - _pusakaLook.cutSince >= grailCutTime) _pusakaLook.cutName = null;
    if (g.grailFirst case final u?) {
      _pusakaLook
        ..cutName = u.hero ? 'Hero ${u.name}' : u.name
        ..cutSince = _clock;
      g.grailFirst = null;
    }
  }

  /// The Grail's cut-in, once a wave ([grailCutTime]): the tooltip frame's tan body at 2x ([_tipBody], the foe
  /// banner's plate), centred on the screen under the top rows, the map and the boss bars ([_plateTop]): the Grail's
  /// icon and "Grail saves `name`!" ([_grailCutLine]) in the tooltip ink. It rises in and fades out (one layer, so the frame's
  /// slices fade as one); it pauses nothing and takes no press (over the field, under the HUD).
  void _grailCutIn(Canvas c) {
    final look = _pusakaLook, name = look.cutName;
    if (name == null) return;
    final p = (_clock - look.cutSince) / grailCutTime;
    if (p >= 1 || p < 0) return; // its end is [_grailNews]'
    const k = 2.0;
    final a = math.min(p / _grailFadeIn, (1 - p) / _grailFadeOut).clamp(0.0, 1.0), s = _screenScale(Size(size.x, size.y));
    final font = math.max(13.0, (18 * s).roundToDouble()), icon = (font * 1.3).roundToDouble(), m = (4 * s).roundToDouble();
    final gap = (6 * s).roundToDouble(), sides = 2 * (3 * k + m);
    final text = _fit(_grailCutLine(name), font, size.x - 32 - sides - icon - gap);
    final w = sides + icon + gap + _textWidth(text, font), h = 3 * k + m + icon + m + 5 * k;
    final top = _plateTop + 6 * s + (1 - math.min(1.0, p / _grailFadeIn)) * 8; // rising in
    final plate = Rect.fromLTWH(((size.x - w) / 2).roundToDouble(), top.roundToDouble(), w.roundToDouble(), h.roundToDouble());
    final mid = plate.top + 3 * k + m + icon / 2;
    c.saveLayer(plate.inflate(2), Paint()..color = Colors.white.withValues(alpha: a));
    _nine(c, _tipBody, plate, k, l: 3, t: 3, r: 3, b: 5, sheet: 'ui_tooltip.png');
    _icon(c, Relic.grail, Rect.fromLTWH(plate.left + 3 * k + m, mid - icon / 2, icon, icon));
    _text(c, text, Offset(plate.left + 3 * k + m + icon + gap, mid), size: font, color: _tipInk);
    c.restore();
  }

  /// The Grail's cut-in showing: its text, or null (for tests).
  String? get _grailCutText => switch (_pusakaLook.cutName) { final name? => _grailCutLine(name), _ => null };

  /// Troop [type]'s build name ([Pusaka.buildNameOf]) on the Army page's right page (troops_page.dart), its left middle at
  /// [at], at most [room] wide (cut with ".."), [font] tall, in its Pusaka's ink; greyed while it sleeps
  /// ([Pusaka.pusakaAsleep]). Nothing without a Pusaka. Kept in [_PusakaLook.rows] for tests.
  void _buildNameLine(Canvas c, Game g, String type, Offset at, double room, double font) {
    final name = g.buildNameOf(type), relic = g.pusakaOf(type);
    if (name == null || relic == null || room < font * 3) return;
    final text = _fit(name, font, room);
    _text(c, text, at, size: font, color: g.pusakaAsleep(relic) ? const Color(0xFF9E9080) : (_pusakaInk[relic] ?? _pusakaInkElse));
    _pusakaLook.rows[type] = (text, Rect.fromLTWH(at.dx, at.dy - font / 2, _textWidth(text, font), font));
  }

  /// The "VICTORY!" line ([pusakaWinLine]) for the last won wave, and its font: the biggest from [_winLineSize] down to
  /// [_winLineMin] at which it fits [maxW] (and [winLineMaxW]), cut with ".." if not even that one does; null: none.
  (String, double)? _winLine(Game g, double maxW) {
    final line = switch (g.lastPusaka) { final r? => pusakaWinLine(r), _ => null };
    if (line == null) return null;
    final room = math.min(maxW, winLineMaxW);
    var size = _winLineSize;
    while (size > _winLineMin && _textWidth(line, size) > room) {
      size -= 1;
    }
    return (_fit(line, size, room), size);
  }
}
