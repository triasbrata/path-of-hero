// A Hero's cast cut-in (issue #51; the owner: "ketika hero melakukan skill di kasikan hilight atau splash
// screen supaya special gitu"). Pure Dart: the queue of what to show and when. The Board feeds it
// Game.heroCasts and draws the one showing (lib/hero_cast.dart, ui-hud.md). The same queue, with its own time
// and line, holds the banners of a monster champion's skill (lib/foe_cut_in.dart; the owner, 2026-10-02: "dan
// ketika champion musuh (< mini boss) skill juga ada effectnya dan ada splash screennya"), and [FoeCutGate]
// decides which casts get one.

/// How long one cut-in shows (seconds on the screen's clock), and how many casts may wait behind it.
const cutInTime = 1.0, cutInWaiting = 3;

/// A Hero's cast gets its cut-in at most once every [heroCutEvery] s, and none comes within [heroCutGap] s of another
/// Hero's (screen clock; decisions-log 298: the troops cast as soon as they may, so the cut-ins are limited; the cast
/// itself always happens). [HeroCutGate] decides.
const heroCutEvery = 20.0, heroCutGap = 3.0;

/// A foe's skill banner: how long it shows (screen clock), how many may wait, how many high elites' banners a wave
/// may show and how far apart (s, screen clock). A mini boss's and the boss's banners count against neither.
const foeCutTime = 1.4, foeCutWaiting = 2, foeCutPerWave = 4, foeCutGap = 4.0;

/// Cut-ins shown one at a time for [time] each, in the order they came. At most [most] wait: a new one past
/// that drops the oldest waiting (the oldest not [front], while there is one). One with the same [key] as a waiting
/// one (the same Hero casting again) takes that one's place instead of queueing; the one showing is never cut
/// short. One that is [front] goes before every waiting one that isn't (after the [front] ones already waiting).
class CutIns<T> {
  CutIns({required this.key, this.time = cutInTime, this.most = cutInWaiting, bool Function(T)? front}) : front = front ?? _never;

  /// What makes two cut-ins the same (their Hero).
  final Object? Function(T) key;

  /// How long one shows, and how many may wait.
  final double time;
  final int most;

  /// Which ones jump the line (a mini boss's banner).
  final bool Function(T) front;

  static bool _never(Object? _) => false;

  /// The one showing, and since when.
  T? showing;
  double since = 0;

  /// The ones waiting, next first.
  final waiting = <T>[];

  /// [item] came at [now]: shown at once if none is, else it waits (see the class).
  void add(T item, double now) {
    if (showing == null) {
      showing = item;
      since = now;
      return;
    }
    final same = waiting.indexWhere((w) => key(w) == key(item));
    if (same >= 0) {
      waiting[same] = item;
      return;
    }
    if (front(item)) {
      final at = waiting.indexWhere((w) => !front(w));
      waiting.insert(at < 0 ? waiting.length : at, item);
    } else {
      waiting.add(item);
    }
    if (waiting.length > most) {
      final plain = waiting.indexWhere((w) => !front(w));
      waiting.removeAt(plain < 0 ? 0 : plain);
    }
  }

  /// At [now]: the one showing ends after [time], and the next waiting one starts.
  void tick(double now) {
    if (showing == null || now - since < time) return;
    showing = waiting.isEmpty ? null : waiting.removeAt(0);
    since = now;
  }

  /// How far into the one showing we are at [now], 0..1; null when none shows.
  double? progress(double now) => showing == null ? null : ((now - since) / time).clamp(0.0, 1.0);

  /// Drops them all (the cut-ins were turned off, or another game came in).
  void clear() {
    showing = null;
    waiting.clear();
  }
}

/// Which foe skill casts get a banner (the owner's choice (a), 2026-10-02): once per key (a skill and its caster's
/// rank) a wave; a high elite's ([big] false) at most [foeCutPerWave] a wave and [foeCutGap] s apart, and one turned
/// away stays unseen, so a later cast of it may still show; a mini boss's or the boss's ([big]) always, the first
/// cast of each of its skills. A new wave starts it afresh.
class FoeCutGate {
  int? _wave;
  final _seen = <Object?>{};
  int _shown = 0;
  double _last = double.negativeInfinity;

  /// How many high elites' banners wave [wave] has shown so far (0 for another wave).
  int shownIn(int wave) => wave == _wave ? _shown : 0;

  /// A cast of [key] in [wave] at [now] (screen clock): whether it gets a banner; if so it is counted.
  bool admit(Object? key, {required bool big, required int wave, required double now}) {
    if (wave != _wave) {
      _wave = wave;
      clear();
    }
    if (_seen.contains(key)) return false;
    if (!big) {
      if (_shown >= foeCutPerWave || now - _last < foeCutGap) return false;
      _shown++;
      _last = now;
    }
    _seen.add(key);
    return true;
  }

  /// Forgets the wave's banners (another game came in).
  void clear() {
    _seen.clear();
    _shown = 0;
    _last = double.negativeInfinity;
  }
}

/// Which Hero casts get a cut-in (decisions-log 298): one of a Hero's at most every [heroCutEvery] s, and none within
/// [heroCutGap] s of any other let through (screen clock). The Board asks it for each `Game.heroCasts` entry.
class HeroCutGate {
  final _at = <Object?, double>{};
  double _last = double.negativeInfinity;

  /// A cast of Hero [key] at [now]: whether it gets its cut-in; if so it is counted.
  bool admit(Object? key, double now) {
    final mine = _at[key];
    if (now - _last < heroCutGap || (mine != null && now - mine < heroCutEvery)) return false;
    _at[key] = _last = now;
    return true;
  }

  /// Forgets every cut-in let through (another game came in).
  void clear() {
    _at.clear();
    _last = double.negativeInfinity;
  }
}

/// A skill's name pops over its caster on its first cast of a wave only (decisions-log 298: the troops cast every few
/// seconds; the skill's own look shows on every cast). [first] says whether a cast of [key] (a caster and which of its
/// skills) in [wave] is that one.
class FirstCasts {
  int? _wave;
  final _seen = <Object?>{};

  /// Whether [key]'s cast in [wave] is its first of the wave; it is marked.
  bool first(Object? key, int wave) {
    if (wave != _wave) {
      _wave = wave;
      _seen.clear();
    }
    return _seen.add(key);
  }

  /// Forgets every wave's casts (another game came in).
  void clear() {
    _wave = null;
    _seen.clear();
  }
}
