// The auto start (issue #68; the owner: "tambahkan auto start wave dan ini di prioritaskan"). Pure Dart:
// the Board ticks it and starts the wave (ui-hud.md); whether it is on is kept in settings.json.

/// Seconds from a won wave to the next one starting by itself.
const autoStartDelay = 5.0;

/// While [on], a won wave starts a countdown of [autoStartDelay] seconds, and at 0 the next wave starts as
/// if Start were pressed. Only a win starts one: never before the first wave or right after a save is
/// loaded. It stands still while held (paused, the Hero splash), and stops when turned off or when the
/// wave starts some other way (Start pressed early) or the game ends.
class AutoStart {
  AutoStart({this.on = false});

  bool on;
  double? left; // seconds left of the countdown; null while none runs

  /// A wave was just won.
  void won() {
    if (on) left = autoStartDelay;
  }

  /// Turns it on or off; off stops a running countdown. Turning it on starts none: the next win does.
  void set(bool value) {
    on = value;
    if (!on) left = null;
  }

  /// Stops a running countdown.
  void cancel() => left = null;

  /// Counts [dt] seconds down unless [held]. True once it reaches 0 (the countdown is then over): start the
  /// wave now.
  bool tick(double dt, {bool held = false}) {
    final l = left;
    if (l == null || held) return false;
    if (l - dt > 0) {
      left = l - dt;
      return false;
    }
    left = null;
    return true;
  }

  /// The whole seconds left, as shown (5, 4 … 1); null while no countdown runs.
  int? get shown => left?.ceil();
}
