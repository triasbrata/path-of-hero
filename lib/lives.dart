part of 'main.dart';

// The lives (the owner, #40: "ubah jadi bar nyawa saja di samping jumlah troops"; #65: "untuk bar darah di
// kiri atas di ganti dengan icon heart tapi icon heartnya di bagi 2"): a row of the pack's hearts beside the troop
// counter, at the front of the panel they share with the gold (decisions-log 220, the owner: "hud uang dan darah di
// jadikan 1 container"; hud_row.dart). Each heart holds 2 lives ([hearts]): full, half (the left half red) or empty; a
// game starts with 3 (#79: "jadi 3 heart saja"). A heart that just lost a half pops for [_heartPop] s. More lives than
// [Game.startLives] (none today: an older save's are cut to it) would add hearts.

const _heartPop = 0.35;

/// ui_icons.png's empty, half and full hearts (by the halves they hold): their visible 14x14 pixels.
const _heartIcons = [Rect.fromLTWH(33, 1, 14, 14), Rect.fromLTWH(17, 1, 14, 14), Rect.fromLTWH(1, 1, 14, 14)];

/// The halves a full heart holds.
const heartFull = 2;

/// The hearts showing [lives]: one per [heartFull] lives of [Game.startLives] (or of [lives] if more), each
/// the lives it holds, left to right: [heartFull] full, 1 half (an odd count's last), 0 empty (lost).
List<int> hearts(int lives) => [
      for (var i = 0; i < (math.max(Game.startLives, lives) + heartFull - 1) ~/ heartFull; i++)
        (lives - heartFull * i).clamp(0, heartFull),
    ];

/// The hearts (their indexes) that change when the lives go [from] -> [to] (fewer): those that lose a half.
Iterable<int> heartsLost(int from, int to) sync* {
  for (var i = to ~/ heartFull; i <= (from - 1) ~/ heartFull; i++) {
    yield i;
  }
}

/// The lives' state between frames, to see a life go.
class _Lives {
  int seen = -1; // the lives last frame
  double lostAt = double.negativeInfinity;
  int lostFrom = 0, lostTo = 0; // the last loss: lostFrom -> lostTo
}

extension on Board {
  /// How wide the hearts are, edge to edge, at the HUD's scale: as big as the counter's shield (16·(k−1) a cell), a
  /// sprite pixel apart.
  double _heartsWidth(Game g) {
    final hk = _meterK - 1, n = hearts(g.lives).length;
    return n * 14 * hk + (n - 1) * hk;
  }

  /// Draws the hearts from [left], their middle at [midY] (on the hearts-and-gold panel, hud_row.dart).
  void _livesHearts(Canvas c, Game g, double left, double midY) {
    final l = _lifeState;
    if (g.lives < l.seen) {
      l
        ..lostAt = _clock
        ..lostFrom = l.seen
        ..lostTo = g.lives;
    }
    l.seen = g.lives;
    final hk = _meterK - 1, size = 14 * hk, halves = hearts(g.lives);
    final icons = _img('ui_icons.png'), top = (midY - size / 2).roundToDouble();
    // The pop: up to 1.3x and back, from its centre.
    final since = _clock - l.lostAt, pop = since < _heartPop ? 1 + 0.3 * math.sin(math.pi * since / _heartPop) : 1.0;
    final popped = pop > 1 ? heartsLost(l.lostFrom, l.lostTo).where((i) => i < halves.length).toSet() : const <int>{};
    void heart(int i, double scale) {
      final at = Rect.fromLTWH(left + i * (size + hk), top, size, size);
      c.drawImageRect(icons, _heartIcons[halves[i]], Rect.fromCenter(center: at.center, width: size * scale, height: size * scale), _px);
    }

    for (var i = 0; i < halves.length; i++) {
      if (!popped.contains(i)) heart(i, 1);
    }
    for (final i in popped) {
      heart(i, pop); // over its neighbours
    }
  }
}
