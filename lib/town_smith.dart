part of 'main.dart';

// The Town's smith (decisions-log 265; docs/ui-hud.md "Town"): one man hammering at his anvil in the Smithy's house, on
// its ground floor before its window, at the house's middle ([_TownLayout.mid]), facing right (the owner, 2026-10-07: "di
// dalam bangunan di kasi 1 npc yang lagi nempa saja"). tool/import_smith.py's strip (lib/town_smith_art.dart) at 1 world
// px a sprite px, the houses' own, its loop on the field's clock like the furnace's. Decoration only: no tap of its own,
// no rule, nothing a battle reads.

/// The smith's frame [seconds] into his loop: each of [townSmithBeats] in turn for its ms, [townSmithLoopMs] in all.
int townSmithFrameAt(double seconds) {
  var ms = (seconds * 1000).floor() % townSmithLoopMs;
  for (final b in townSmithBeats) {
    if (ms < b.ms) return b.frame;
    ms -= b.ms;
  }
  return townSmithBeats.last.frame;
}

extension _TownSmithLook on Board {
  /// The smith at his anvil, drawn by [_townScene] over the Smithy's house: his feet at its middle on its floor, the
  /// street's line ([_townGround]) raised [townStep] (its porch's top), [ox] the street's left on the screen, [top] the
  /// layers' top raised so, [k] screen px a world px. Where he is drawn is 'smith' in [townScene].
  void _townSmith(Canvas c, _TownLayout L, double ox, double top, double k) {
    final n = townSmithFrameAt(_fieldClock), x = L.mid('smithy') - townSmithFeet.x;
    final to = Rect.fromLTWH(ox + (x * k).roundToDouble(), top + (_townGround - townSmithH) * k, townSmithW * k, townSmithH * k);
    c.drawImageRect(_img(townSmith), Rect.fromLTWH(n * townSmithW.toDouble(), 0, townSmithW.toDouble(), townSmithH.toDouble()),
        to, _px);
    _town.at['smith'] = to;
  }
}
