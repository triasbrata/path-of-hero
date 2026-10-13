part of 'game.dart';

// The Dungeon's walk grid and paths (decisions-log 336, 337; docs/dungeon-design.md section 9, "Walls and
// collision", "Paths"): a floor is cut into [navCell] cells over its band, props, the wall and the ledge block cells,
// and units walk on A* paths (8 directions, no corner cut) and slide along what blocks them.

/// A walk cell's side in world units.
const navCell = 8.0;

/// A path is asked again at most this often per unit, or sooner when its goal moved more than [navRegoal] units.
const navEvery = 0.25, navRegoal = 16.0;

/// The most cells one A* opens: the grids are small and paths short (a follower to its spot, a monster to its prey or
/// home), so a goal past this is walked to straight.
const navMost = 6000;

/// The floor's walk grid: [cols] × [rows] cells of [navCell], each free or blocked.
class WalkGrid {
  WalkGrid(this.cols, this.rows) : _blocked = List.filled(cols * rows, true);

  final int cols, rows;
  final List<bool> _blocked;

  /// Whether cell ([c], [r]) can be walked; outside the grid it can't.
  bool free(int c, int r) => c >= 0 && r >= 0 && c < cols && r < rows && !_blocked[r * cols + c];

  /// The cell holding world point [p].
  (int, int) cellOf(Point<double> p) => ((p.x / navCell).floor(), (p.y / navCell).floor());

  /// Whether world point [p] stands on a free cell.
  bool freeAt(Point<double> p) {
    final (c, r) = cellOf(p);
    return free(c, r);
  }

  /// The centre of cell ([c], [r]) in world units.
  static Point<double> centre(int c, int r) => Point((c + 0.5) * navCell, (r + 0.5) * navCell);

  /// Opens (or with [blocked], closes) every cell whose centre lies in the box [x0]..[x1] × [y0]..[y1].
  void mark(double x0, double y0, double x1, double y1, {bool blocked = false}) {
    final c0 = max(0, (x0 / navCell).floor()), c1 = min(cols - 1, (x1 / navCell).ceil());
    final r0 = max(0, (y0 / navCell).floor()), r1 = min(rows - 1, (y1 / navCell).ceil());
    for (var r = r0; r <= r1; r++) {
      for (var c = c0; c <= c1; c++) {
        final p = centre(c, r);
        if (p.x >= x0 && p.x <= x1 && p.y >= y0 && p.y <= y1) _blocked[r * cols + c] = blocked;
      }
    }
  }

  /// How many cells are free (tests).
  int get freeCount => _blocked.where((b) => !b).length;

  /// The free cell nearest [p] (itself when free), searched ring by ring up to [most] cells away; null when none.
  (int, int)? nearestFree(Point<double> p, {int most = 12}) {
    final (c, r) = cellOf(p);
    if (free(c, r)) return (c, r);
    for (var d = 1; d <= most; d++) {
      (int, int)? best;
      var bestD = double.infinity;
      for (var dr = -d; dr <= d; dr++) {
        for (var dc = -d; dc <= d; dc++) {
          if (max(dr.abs(), dc.abs()) != d || !free(c + dc, r + dr)) continue;
          final dd = centre(c + dc, r + dr).distanceTo(p);
          if (dd < bestD) (best, bestD) = ((c + dc, r + dr), dd);
        }
      }
      if (best != null) return best;
    }
    return null;
  }

  /// Whether the straight line from [a] to [b] crosses only free cells (sampled every quarter cell).
  bool clear(Point<double> a, Point<double> b) {
    final d = b - a, len = d.magnitude, n = max(1, (len / (navCell / 4)).ceil());
    for (var i = 0; i <= n; i++) {
      if (!freeAt(a + d * (i / n))) return false;
    }
    return true;
  }

  /// [from] moved by [step], kept off blocked cells: the whole step if it lands free, else its x alone, else its y
  /// alone (sliding along what blocks it), else no move. A unit already on a blocked cell (pushed there) may step
  /// anywhere free.
  Point<double> slide(Point<double> from, Point<double> step) {
    final to = from + step;
    if (freeAt(to)) return to;
    final x = Point(to.x, from.y), y = Point(from.x, to.y);
    if (step.x != 0 && freeAt(x)) return x;
    if (step.y != 0 && freeAt(y)) return y;
    return from;
  }

  /// An A* path from [from] to [to] on the free cells, 8 directions (a diagonal only where both its sides are free),
  /// as world points from the first step to [to] itself, smoothed where a straight line is clear. Empty when [to] is
  /// in [from]'s cell or in sight; null when no path is found within [navMost] cells.
  List<Point<double>>? path(Point<double> from, Point<double> to) {
    if (clear(from, to)) return [to];
    final start = nearestFree(from), goal = nearestFree(to);
    if (start == null || goal == null) return null;
    final (sc, sr) = start;
    final (gc, gr) = goal;
    final n = cols * rows, si = sr * cols + sc, gi = gr * cols + gc;
    final g = <int, double>{si: 0}, came = <int, int>{}, closed = <int>{};
    final open = _Heap()..push(si, _h(sc, sr, gc, gr));
    var opened = 0;
    while (open.isNotEmpty) {
      final i = open.pop();
      if (i == gi) break;
      if (!closed.add(i)) continue;
      if (++opened > navMost) return null;
      final c = i % cols, r = i ~/ cols, gi0 = g[i]!;
      for (final (dc, dr, cost) in _steps) {
        final nc = c + dc, nr = r + dr;
        if (!free(nc, nr)) continue;
        if (dc != 0 && dr != 0 && (!free(c + dc, r) || !free(c, r + dr))) continue; // no corner cut
        final ni = nr * cols + nc;
        if (ni < 0 || ni >= n || closed.contains(ni)) continue;
        final ng = gi0 + cost;
        if (ng >= (g[ni] ?? double.infinity)) continue;
        g[ni] = ng;
        came[ni] = i;
        open.push(ni, ng + _h(nc, nr, gc, gr));
      }
    }
    if (!came.containsKey(gi) && gi != si) return null;
    final cells = <int>[];
    for (var i = gi; i != si; i = came[i]!) {
      cells.add(i);
    }
    final way = [for (final i in cells.reversed) centre(i % cols, i ~/ cols)];
    if (way.isNotEmpty) way[way.length - 1] = freeAt(to) ? to : way.last;
    // Smoothing: from where it stands, the farthest point still in sight, then on from there.
    final out = <Point<double>>[];
    var at = from, k = 0;
    while (k < way.length) {
      var far = k;
      for (var j = way.length - 1; j > k; j--) {
        if (clear(at, way[j])) {
          far = j;
          break;
        }
      }
      out.add(way[far]);
      at = way[far];
      k = far + 1;
    }
    return out;
  }

  static const _steps = [(1, 0, 1.0), (-1, 0, 1.0), (0, 1, 1.0), (0, -1, 1.0), (1, 1, 1.4142), (1, -1, 1.4142), (-1, 1, 1.4142), (-1, -1, 1.4142)];

  /// The octile distance between two cells.
  static double _h(int c, int r, int gc, int gr) {
    final dx = (c - gc).abs(), dy = (r - gr).abs();
    return max(dx, dy) + 0.4142 * min(dx, dy);
  }
}

/// A binary min-heap of cell indices by priority, for [WalkGrid.path] (ties by the order pushed, so a path is the
/// same every run).
class _Heap {
  final _items = <(double, int, int)>[];
  int _n = 0;
  bool get isNotEmpty => _items.isNotEmpty;

  void push(int i, double p) {
    _items.add((p, _n++, i));
    var k = _items.length - 1;
    while (k > 0) {
      final up = (k - 1) >> 1;
      if (!_less(_items[k], _items[up])) break;
      final s = _items[k];
      _items[k] = _items[up];
      _items[up] = s;
      k = up;
    }
  }

  int pop() {
    final top = _items.first, last = _items.removeLast();
    if (_items.isNotEmpty) {
      _items[0] = last;
      var k = 0;
      while (true) {
        final l = 2 * k + 1, r = l + 1;
        var m = k;
        if (l < _items.length && _less(_items[l], _items[m])) m = l;
        if (r < _items.length && _less(_items[r], _items[m])) m = r;
        if (m == k) break;
        final s = _items[k];
        _items[k] = _items[m];
        _items[m] = s;
        k = m;
      }
    }
    return top.$3;
  }

  static bool _less((double, int, int) a, (double, int, int) b) => a.$1 < b.$1 || (a.$1 == b.$1 && a.$2 < b.$2);
}
