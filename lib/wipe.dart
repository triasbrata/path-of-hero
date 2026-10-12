part of 'game.dart';

// An army wiped mid-wave (decisions-log 322; game-overview.md "Lose"). Until then the game ended when the last troop
// fell, so every run ended in a wipe at full hearts and the lives never mattered; the owner, 2026-10-12, picked "Kalah
// wave: −1 hati, ulang". Now:
// - the wipe ([Wipe._armyDown]): a troop fell this wave and none is alive (one Resurrection raised this tick counts), no
//   Phoenix Plume rise is due ([Game._risesDue]), and a monster still lives or is queued: the last troop and the last
//   monster falling together is a win;
// - it costs [wipeLives] lives, a heart; at 0 the game is over as before (the monsters cheer, the scoreboard);
// - else the wave's living and queued monsters are swept off with no gold, loot or score ([Game.swept] hop for joy a
//   moment), the wave's effects end as at a won wave's end, and what it paid stays (kill gold, score, kills) while the
//   materials lying on the field are lost (they come with a win);
// - the same wave is played again: [Game.wave] goes back to the last won one, so between waves everything reads as after
//   that win (a Town due, the wave meter's next wave), and [Game.lostWave] marks the replay. No wave bonus, score, Hero,
//   chest, Town roll, Shadow ease or Grudge target comes until it is won; the Shadows' catch-up doesn't land twice
//   ([Omens._omenWave]) and Lewati's skip buff owed for it is owed again; the Tavern's boosts don't count it (decisions-log
//   331: the replay is the same wave, so a boost bought for waves 7 and 8 still covers 7 played again and 8);
// - between waves as after any: "Replace fallen" lists the army ([Game.toReplace]), Auto Buy refills it, and the UI says
//   so, pops the heart, saves and starts Auto Wave's countdown (main.dart).

/// The lives an army wiped costs: a heart (lives.dart's `heartFull`).
const wipeLives = 2;

/// How long the monsters a wipe swept off hop for joy where they stood ([Game.swept]) before they go.
const wipeCheer = victoryTime;

extension Wipe on Game {
  /// The army is down mid-wave ([Game.tick], after the raised joined): a troop fell this wave, none is alive and no rise
  /// is due, while a monster lives or is still queued.
  bool get _armyDown =>
      fallen.isNotEmpty && _risesDue == 0 && !troops.any((u) => u.alive) && (queue.isNotEmpty || enemies.any((u) => u.alive));

  /// The army fell: [wipeLives] lives go, and unless that ends the game the wave's monsters are swept off, it ends as
  /// lost and it is played again (the file's comment).
  void _wipe() {
    final before = lives, left = enemies.where((u) => u.alive).toList();
    lives = max(0, lives - wipeLives);
    wipedOut = true;
    wipedAt = t;
    sfx.add(Sfx.lose);
    _emit(Wiped(wave, t, lives: lives, lost: before - lives, foes: left.length + queue.length, over: over));
    if (over) return; // the game is over: the monsters cheer, and the tick's end scores it
    _endEffects(); // every effect ends (a hexed monster hops as itself), and what was left for later (hero_skills.dart)
    swept
      ..clear()
      ..addAll(left);
    units.removeWhere((u) => u.side == Side.enemy);
    queue.clear();
    for (final s in shots) {
      s
        ..to ??= s.target.pos // a swept monster is gone from the field: its shot flies on to where it stood
        ..spent = true; // and lands its look alone (decisions-log 327)
    }
    lineShots.clear();
    beams.clear();
    zones.clear();
    rings.removeWhere((r) => r.follow?.side == Side.enemy);
    marching = false;
    _watchGrail(end: true);
    _emit(WaveEnded(wave, t, won: false));
    _boostWaveEnd(replay: true); // the Tavern's boosts don't count a wave played again (tavern.dart)
    _pocketWaveEnd(); // the pocket's boosts and ward end with it (pocket.dart)
    waveMaterials.clear(); // what lay on the field comes only with a win
    toReplace
      ..clear()
      ..addAll([for (final u in fallen) if (!u.hero) (type: u.type, post: u.post)]);
    _autoWon(); // those Auto bought back during the wave leave the list (auto_replace.dart)
    healQueue.clear();
    if (waveSkipBuff) skipBuffDue = true; // Lewati's skip buff meets the replay too (omen.dart)
    lostWave = wave;
    wave = max(0, wave - 1); // a test's fight with no wave begun has none to go back from
  }

  /// The swept monsters' hop is over ([wipeCheer]): each goes in a summon circle.
  void _sweptGone() {
    if (swept.isEmpty || t - wipedAt < wipeCheer) return;
    for (final u in swept) {
      impacts.add((u.pos, 'summon'));
    }
    swept.clear();
  }

  /// What the message window says after a wipe that didn't end the game.
  String get wipeNote => 'Your army fell! -1 heart.\nWave ${wave + 1} again.';
}
