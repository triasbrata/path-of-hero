part of 'game.dart';

// Auto: replace the fallen (decisions-log 283; ui-hud.md "Spawn bar"; the owner, 2026-10-09, the spawn bar's "<auto spawn
// troops>": "Auto ganti yang gugur"). While [Game.autoReplace] is on, every troop that falls (not a Hero: a Hero's is
// Recall's, recall.dart) is bought back, the same type, through a buy's own rules ([Game.buyRefusal], [Game.autoPlace]),
// in the order they fell:
// - mid-wave from the queue ([Game._autoQueue]), filled as they fall: the first one the gold doesn't cover yet holds the
//   queue until it does; one refused for anything else (its type at its cap, an oath, no room) is skipped, saying nothing;
// - at the win "Replace fallen"'s list ([Game.toReplace]) leaves out those Auto bought back during the wave;
// - between waves it works through that list in the order they fell, each back to its old spot as "Replace fallen" puts
//   it ([Game._replaceOne]); one refused for more than the gold stays on the list (its greyed button says why);
// - at the next wave's start what is left on the list goes into the queue; what of it the gold hasn't covered by the
//   next win is let go, as the list's offer itself ends at a wave's start.
// Off by default (a game without it plays as before); saved, the queue isn't (it is empty between waves).

extension AutoReplace on Game {
  /// Turns Auto on or off. On between waves, it starts on [toReplace] at once (the next tick).
  void setAutoReplace(bool on) {
    autoReplace = on;
    if (!on) _autoQueue.clear();
  }

  /// The tooltip of the spawn bar's "Auto Buy" ([Words.autoBuy], decisions-log 290; ui-hud.md "Spawn bar"): what it
  /// does, and whether it is on.
  (String, List<String>) get autoTip => (
        Words.autoBuy,
        ['${Words.autoBuy}: replace fallen troops.', autoReplace ? 'On: each one comes back as gold allows.' : 'Off.'],
      );

  /// A troop [u] fell: with Auto on (not a Hero), it joins the queue.
  void _autoFell(Unit u) {
    if (autoReplace && !u.hero) _autoQueue.add((type: u.type, carried: false));
  }

  /// A wave starts: with Auto on, the troops still on [toReplace] go into the queue (in the order they fell) before the
  /// list clears.
  void _autoWaveStart() {
    _autoBack.clear();
    if (autoReplace) _autoQueue.addAll([for (final f in toReplace) (type: f.type, carried: true)]);
  }

  /// The wave is won and [toReplace] was just made from its fallen: those Auto bought back during it leave the list (one
  /// of their type each, the last to fall first), and the queue ends with the wave (this wave's fallen still in it are on
  /// the list; those carried from the last list are let go).
  void _autoWon() {
    for (final MapEntry(key: type, value: n) in _autoBack.entries) {
      for (var i = 0; i < n; i++) {
        final at = toReplace.lastIndexWhere((f) => f.type == type);
        if (at >= 0) toReplace.removeAt(at);
      }
    }
    _autoBack.clear();
    _autoQueue.clear();
  }

  /// Once a tick, with Auto on and the game going: mid-wave the queue, between waves [toReplace], as many as the gold
  /// and the room allow now.
  void _autoReplaceTick() {
    if (!autoReplace || over) return;
    if (waveActive) {
      while (_autoQueue.isNotEmpty) {
        final next = _autoQueue.first, why = buyRefusal(next.type);
        if (why == buyRefusals.gold) return; // the gold doesn't cover it yet: the queue waits
        _autoQueue.removeAt(0);
        if (why != null || _autoCell == null || !autoPlace(next.type)) continue; // refused: skipped, nothing said
        if (!next.carried) _autoBack[next.type] = (_autoBack[next.type] ?? 0) + 1;
      }
      return;
    }
    for (var i = 0; i < toReplace.length;) {
      final f = toReplace[i], why = buyRefusal(f.type);
      if (why == buyRefusals.gold) return; // the gold doesn't cover it yet: the rest wait behind it
      if (why == null && _replaceRoom(f) && _replaceOne(f)) {
        toReplace.removeAt(i);
      } else {
        i++; // refused (or no cell for it now): it stays on the list for "Replace fallen", greyed with why
      }
    }
  }
}
