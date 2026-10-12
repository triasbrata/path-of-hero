part of 'main.dart';

// How a Hero looks ([Unit.hero]; game.dart: every [heroEvery]th wave one troop becomes one). A white halo
// in stepped bands glows behind its body and the pack's gold crown sits above its HP bar: an awakening only colours
// what is round a troop (its outline, ground shadow and sparks: blue, crimson, gold). Its nameplate reads
// "Hero <name>" with its 2 rolled attributes ([Unit.heroStats]) as the book's stat icons, "x3" each, and
// under them its own skill ([Unit.heroSkill]: its mark and name, [_heroSkillLine]); the book's troop row and
// the troop counter's list show the crown on a type with a living Hero, and hovering the row's crown lists
// that type's Heroes the same way ([_heroTip]). A new Hero's splash screen is in hero_splash.dart.
// A Hero skill's cast and effects look: skills.dart.

/// ui_icons.png's gold crown.
const _icCrown = Offset(64, 16);

/// How big a rolled attribute's icon is in the tooltips, and the text after it ("x3").
const _heroIcon = 16.0, _heroText = 14.0;

/// A Hero skill's name on the tooltips' tan: a dark gold.
const _heroSkillInk = Color(0xFF8A5A00);

extension on Board {
  /// The text after each rolled attribute: "x3", or under Oath of Kings "x2" ([Pusaka.heroBoostNow]).
  String get _heroX => 'x${state.heroBoostNow.round()}';

  /// The halo behind a Hero's body ([feet] on the ground, hopping with it): white light in [haloBands] stepped bands,
  /// fainter outward, in the sprites' pixels (pixel_shapes.dart, decisions-log 325), its radius pulsing 14 ± 1.5 by
  /// whole units (still while paused).
  void _heroHalo(Canvas c, Unit u, Offset feet) =>
      _haloAt(c, feet - const Offset(0, 11), (14 + math.sin(_fieldClock * 3 + u.id) * 1.5).round());

  /// The gold crown just above a Hero's bars (the HP bar's top at [barTop], the MP bar under it).
  void _heroCrown(Canvas c, Unit u, double barTop) => _uiIcon(c, _icCrown, Rect.fromLTWH(u.pos.x - 4, barTop - 8.5, 8, 8));

  /// The crown on the top right corner of a type's sprite [box] (the book's troop row, the troop counter's
  /// list) while that type has a living Hero. Given the list's [clip] (the book's row), hovering it lists
  /// that type's Heroes ([_heroTip]).
  void _heroMark(Canvas c, Game g, String type, Rect box, [Rect? clip]) {
    if (!g.hasHero(type)) return;
    final s = box.shortestSide * 0.4, mark = Rect.fromLTWH(box.right - s, box.top, s, s);
    _uiIcon(c, _icCrown, mark);
    if (clip != null) _tip.hints.add((mark.inflate(2).intersect(clip), _Hint.hero, type));
  }

  /// The icon of a Hero's rolled attribute [s] for troop [type]: the book row's (the heart, the blue bolt,
  /// or the icon of the item that raises it: the staff for a caster's power).
  void _heroStatIcon(Canvas c, HeroStat s, String type, Rect to) => switch (s) {
        HeroStat.hp => c.drawImageRect(_img('ui_icons.png'), _heartIcon, to, _px),
        HeroStat.mp => c.drawImageRect(_img('ui_icons.png'), _boltIcon, to, _mpPaint),
        HeroStat.power => _icon(c, powerItem(type), to),
        HeroStat.defence => _icon(c, Item.shield, to),
        HeroStat.rate => _icon(c, Item.gloves, to),
        HeroStat.speed => _icon(c, Item.boots, to),
        HeroStat.range => _icon(c, Item.bow, to),
      };

  /// How wide [_heroStats] draws Hero [u]'s attributes ([k] times the tooltips' size).
  double _heroStatsWidth(Unit u, [double k = 1]) => _heroStatListWidth(u.heroStats.length, k);

  /// How wide [_heroStatList] draws [n] attributes.
  double _heroStatListWidth(int n, [double k = 1]) => n * ((_heroIcon + 2 + 8) * k + _textWidth(_heroX, _heroText * k)) - 8 * k;

  /// Hero [u]'s rolled attributes from [at] (the line's left middle): each one's icon and "x3", [k] times
  /// the tooltips' size.
  void _heroStats(Canvas c, Unit u, Offset at, [double k = 1]) => _heroStatList(c, u.heroStats, u.type, at, k);

  /// [_heroStats] for attributes [stats] of a [type] Hero (a fallen one's too: recall_page.dart).
  void _heroStatList(Canvas c, List<HeroStat> stats, String type, Offset at, [double k = 1]) {
    final icon = _heroIcon * k, text = _heroText * k;
    var x = at.dx;
    for (final s in stats) {
      _heroStatIcon(c, s, type, Rect.fromLTWH(x, at.dy - icon / 2, icon, icon));
      x += icon + 2 * k;
      _text(c, _heroX, Offset(x, at.dy), size: text, color: _effectInk); // green, like an item's effect
      x += _textWidth(_heroX, text) + 8 * k;
    }
  }

  /// How wide [_heroSkillLine] draws Hero skill [s].
  double _heroSkillWidth(HeroSkill s) => _heroIcon + 4 + _textWidth(s.title, _heroText);

  /// Hero skill [s] from [at] (the line's left middle): its mark ([HeroMark]) and its name.
  void _heroSkillLine(Canvas c, HeroSkill s, Offset at) {
    _heroMarkIcon(c, s.mark, Rect.fromLTWH(at.dx, at.dy - _heroIcon / 2, _heroIcon, _heroIcon)); // skills.dart
    _text(c, s.title, Offset(at.dx + _heroIcon + 4, at.dy), size: _heroText, color: _heroSkillInk);
  }

  /// Over the book row's crown ([target]): "Hero", then each living Hero of [type] with its rolled
  /// attributes and its own skill, in the tooltip frame pointing at the crown.
  void _heroTip(Canvas c, String type, Rect target) {
    const icon = 24.0, lineH = 20.0, nameSize = 14.0;
    final heroes = [for (final u in state.troops) if (u.alive && u.hero && u.type == type) u];
    final w = [
      icon + 6 + _textWidth('Hero', 18),
      for (final u in heroes) _textWidth(u.name, nameSize) + 10 + _heroStatsWidth(u) + (u.heroSkill == null ? 0 : 12 + _heroSkillWidth(u.heroSkill!)),
    ].reduce(math.max);
    final at = _tipAt(target, w + _inL * 2, _inT + icon + 4 + heroes.length * lineH + _inB), box = at.$1;
    _tipFrame(c, at);
    _uiIcon(c, _icCrown, Rect.fromLTWH(box.left + _inL, box.top + _inT, icon, icon));
    _text(c, 'Hero', Offset(box.left + _inL + icon + 6, box.top + _inT + icon / 2), size: 18, color: _dark);
    for (final (i, u) in heroes.indexed) {
      final y = box.top + _inT + icon + 4 + (i + 0.5) * lineH;
      _text(c, u.name, Offset(box.left + _inL, y), size: nameSize, color: _tipInk);
      final statsAt = box.left + _inL + _textWidth(u.name, nameSize) + 10;
      _heroStats(c, u, Offset(statsAt, y));
      if (u.heroSkill case final s?) _heroSkillLine(c, s, Offset(statsAt + _heroStatsWidth(u) + 12, y));
    }
  }
}
