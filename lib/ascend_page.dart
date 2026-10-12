part of 'main.dart';

// Awaken 4-5 and Forge on a button (#92 part 2, decisions-log 143, 163; their rules: lib/ascend.dart, lib/tempa.dart;
// docs/ui-hud.md "Army"): [Board._upgradeButton], the Army page's detail's (troop_detail.dart): "Awaken 4  40k" or at
// Bangkit 5 "Forge +5  33k" (purple), or greyed with why not, which a tap also says in the message window; a type below
// Bangkit 3 whose next awakening the bag holds ([Ascend.bagLevel]) gets "Awaken 2 from the Bag", which turns the book to
// the Bag with the item it needs picked. Tempa's "+n" after a type's stars ([Board._tempaMark]); the Bag tab's dot and
// the Army tab's ([Tempa.armyNudge]). Until decisions-log 296 the Toko (the Shop of a game without the Towns) had a
// Bangkit section here too, a row per type; it went with the Towns-off book.

/// ui_buttons.png's purple row (main.dart's `Board._btn*`; button_fx.dart): the Awaken and Forge buttons.
const _btnPurple = 6;

/// Shorter words for a refusal where a button is too narrow for it, longest first.
final _shortWhy = {
  ascendRefusals.first: ['Needs ${Words.awaken} $maxAwaken', '${Words.awaken} $maxAwaken first'],
  ascendRefusals.maxed: [awakenName(awakenTop), 'Max'],
  tempaRefusals.first: ['Needs ${Words.awaken} $tempaFrom', '${Words.awaken} $tempaFrom first'],
  tempaRefusals.maxed: [tempaName(tempaMax), 'Max'],
  storeRefusalNames[StoreRefusal.midWave]!: ['Between waves', 'Later'],
  storeRefusalNames[StoreRefusal.over]!: ['Over'],
};

/// The Tas tab's dot while a fielded type can awaken further from the bag ([Ascend.bagAwakens]); the Army tab's too
/// ([Tempa.armyNudge]).
const _bagDot = Color(0xFFE0402A);

/// Tempa's "+n" after the stars is this many times their height ([Board._tempaMark]).
const _markK = 1.2;

extension on Board {
  /// [type]'s next step on a button at [btn] (its words [size] tall, [ts] the page's scale), the Army page's detail's
  /// (troop_detail.dart), buying through [_ascend] / [_temper]: a type below Bangkit
  /// 3 whose next awakening the bag holds ([Ascend.bagLevel]) gets an orange "Awaken 2 from the Bag", which turns the
  /// book to the Bag with the first item it needs picked ([_toBagFor]); else at Bangkit 5 the next Tempa level, purple
  /// with its price ("Forge +5  33k"), or below it the next Bangkit ("Awaken 4  40k"); refused, white with why ([step],
  /// the detail's, names the step first: "Awaken 4: Opens after wave 15"), and a tap says it in the message window. The
  /// longest words that fit go on it, and are returned. Its tap goes in [into] ([_hits], on tap down, unless given).
  /// With [tag] (the detail's: inside a section, decisions-log 198) a green tag in place of the button ([_tag]), greyed
  /// when refused.
  String _upgradeButton(Canvas c, Game g, String type, Rect btn, double ts, double size,
      {List<(Rect, VoidCallback)>? into, String? step, bool tag = false}) {
    final level = g.awakenLevel(type), forge = level >= tempaFrom, bag = g.bagLevel(type);
    final why = forge ? g.whyNotTempa(type) : g.whyNotAscend(type), price = forge ? g.tempaPriceOf(type) : g.ascendPriceOf(type);
    final room = btn.width - 8 * ts;
    String fitted(List<String> words) => words.firstWhere((w) => _textWidth(w, size) <= room, orElse: () => _fit(words.last, size, room));
    final String label;
    if (level < maxAwaken && bag > level) {
      // The bag holds its next awakening: off to the Bag.
      label = fitted([bagAwakensTo(bag), '${Words.awaken} $bag in ${Words.bag}', 'To ${Words.bag}']);
      if (tag) {
        _tag(c, btn, () => _toBagFor(type), label, size, look: _TagLook.go, into: into);
        return label;
      }
      _button(c, btn, () => _toBagFor(type), row: Board._btnOrange, size: size, into: into, label: label);
    } else if (why == null) {
      final cost = shortPrice(price!);
      label = fitted(forge
          ? ['${tempaName(g.tempaOf(type) + 1)}  $cost', '${Words.forge}  $cost', cost]
          : ['${Words.awaken} ${level + 1}  $cost', '${Words.awaken}  $cost', cost]);
      if (tag) {
        _tag(c, btn, () => forge ? _temper(type) : _ascend(type), label, size, look: _TagLook.go, into: into);
        return label;
      }
      _button(c, btn, () => forge ? _temper(type) : _ascend(type), row: _btnPurple, size: size, into: into, label: label);
    } else {
      label = fitted([if (step != null) '$step: $why', why, ...?_shortWhy[why]]);
      if (tag) {
        _tag(c, btn, () => showMessage(why), label, size, look: _TagLook.off, into: into);
        return label;
      }
      _button(c, btn, () {}, enabled: false, size: size, label: label);
      (into ?? _hits).add((btn, () => showMessage(why)));
    }
    return label;
  }

  /// The orange "Awaken 2 from the Bag": the book turns to the Bag with the first item [type] still needs for its next
  /// awakening picked (in its recipe's order, one the bag holds; [Game.awakenShort], by grade the next grade's) and its
  /// "Give to troops" open (decisions-log 202), so a tap on its row there gives it.
  void _toBagFor(String type) {
    final g = state;
    _openBag(act: BagAction.giveTroops, pick: [
      for (final item in g.awakenShort(type).keys)
        if ((g.inventory[item] ?? 0) > 0) item,
    ].firstOrNull);
  }

  /// Buys [type]'s next level ([Ascend.ascend]); the message window says it: "Templar: Awaken 4!".
  void _ascend(String type) {
    if (state.ascend(type)) showMessage('${troopTypeNames[type]}: ${Words.awaken} ${state.awakenLevel(type)}!');
  }

  /// Buys [type]'s next Tempa level ([Tempa.temper]); the message window says it: "Knight: Forge +1!".
  void _temper(String type) {
    if (state.temper(type)) showMessage('${troopTypeNames[type]}: ${tempaName(state.tempaOf(type))}!');
  }

  /// A type's Tempa [n] as "+n" in Bangkit 5's book ink, right after its [stars] (a bit taller than them), in at most
  /// [room] beside them (shrunk to fit; nothing at Tempa 0). Kept in [_tempaMarks] for tests.
  void _tempaMark(Canvas c, int n, Rect stars, double room) {
    if (n <= 0 || room <= 0) return;
    final label = '+$n', gap = stars.height * 0.2, big = stars.height * _markK;
    final size = math.min(big, big * (room - gap) / math.max(1, _textWidth(label, big)));
    final at = Offset(stars.right + gap, stars.center.dy);
    _text(c, label, at, size: size, color: _awakeInk[tempaFrom - 1], anchor: Anchor.centerLeft);
    _tempaMarks.add((Rect.fromLTWH(at.dx, at.dy - size / 2, _textWidth(label, size), size), label));
  }

  /// Where a row's [stars] go with Tempa [n]'s "+n" after them ([_tempaMark]), both centred where the stars were and
  /// together at most [width] wide (the stars narrower when they must be), and the room the mark gets. Unchanged at 0.
  (Rect, double) _besideMark(Rect stars, double width, int n) {
    if (n <= 0) return (stars, 0);
    final mark = _textWidth('+$n', stars.height * _markK) + stars.height * 0.2;
    final w = math.max(0.0, math.min(stars.width, width - mark));
    return (Rect.fromLTWH(stars.center.dx - (w + mark) / 2, stars.top, w, stars.height), mark);
  }
  /// The Tas tab's dot in the top right of its icon [icon] while a fielded type can awaken further from the bag
  /// ([Ascend.bagAwakens]): the owner had the items for Bangkit 3 and didn't see it.
  void _bagTabDot(Canvas c, Game g, Rect icon, double ps) {
    if (g.bagAwakens) _tabDot(c, icon, ps, 'bagDot');
  }

  /// The Army tab's dot (its detail buys them, decisions-log 230), the same, while gold piles up and a fielded type can
  /// buy its next Bangkit or Tempa level ([Tempa.armyNudge], decisions-log 163; the owner's decision 4 a).
  void _armyTabDot(Canvas c, Game g, Rect icon, double ps) {
    if (g.armyNudge) _tabDot(c, icon, ps, 'armyDot');
  }

  /// A red dot, dark-rimmed, on the top right of a tab's [icon]; where it is goes in [_storeAt] as [key].
  void _tabDot(Canvas c, Rect icon, double ps, String key) {
    final at = icon.topRight + Offset(-1.5 * ps, 1.5 * ps), r = 2.5 * ps;
    c.drawCircle(at, r + ps * 0.7, Paint()..color = const Color(0xFF3B2210));
    c.drawCircle(at, r, Paint()..color = _bagDot);
    _storeAt[key] = Rect.fromCircle(center: at, radius: r);
  }
}
