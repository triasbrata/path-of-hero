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
// The Town checkpoint (decisions-log 333; the owner, 2026-10-13: "kalau pasukan wipe user di balikkan lagi ke town
// terakhir yang dia datangin supaya bisa mengumpulkan uang, dan wave selanjutnya di debuff sampai next town"): since a
// Town has been gone into, a wipe sends the game back to the last one ([Wipe.checkpoint], its slot S) instead of the
// same wave: [Game.wave] goes to S - 1 and that Town is due again ([Towns.townAgain]), gone into once the swept monsters'
// hop is over (town_look.dart), as it was left: its identity, its market, a new Tavern visit. Leaving it starts wave S,
// so the waves from it to the lost one are played again. What was earned stays; a wave won again pays its kills, drops
// and win gold, but its once-a-number rewards (score, Hero, Boss Chest, the Shadows' catch-up) only past
// [Game.bestWon]. The Town schedule starts again from it ([_backToCheckpoint]). Before the first Town, 322's same-wave
// replay stands. Either way the monsters are weakened until the next new Town ([Game.weakened]: [weakenedHp],
// [weakenedDmg] in [Omens.spawnStats]).

/// The lives an army wiped costs: a heart (lives.dart's `heartFull`).
const wipeLives = 2;

/// How long the monsters a wipe swept off hop for joy where they stood ([Game.swept]) before they go.
const wipeCheer = victoryTime;

/// Whether a game takes "Try again" after a wipe by itself (decisions-log 333): on for the tests, the probes and any game
/// with no player; main() turns it off, and the player chooses in the dialog ([Game.wipeAsk], wipe_ask.dart).
bool autoTryAgain = true;

/// The monsters' HP and damage while weakened after a wipe, by [Game.weakened] (decisions-log 333): one wipe −20% HP and
/// −15% damage, a second before the next new Town −30% and −25%, the most ([weakenedMost]: a third wipe ends the game).
const weakenedHp = [1.0, 0.8, 0.7], weakenedDmg = [1.0, 0.85, 0.75];
const weakenedMost = 2;

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
    _emit(Wiped(wave, t,
        lives: lives,
        lost: before - lives,
        foes: left.length + queue.length,
        over: over,
        checkpoint: over ? null : _checkpointNow,
        town: over || _checkpointNow == null ? null : sceneIdentity.name,
        debuff: over ? weakened : min(weakenedMost, weakened + 1)));
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
    _backToCheckpoint();
    wipeAsk = !autoTryAgain; // the player chooses: Try again or Give up (wipe_ask.dart)
  }

  /// "Try again" ([Game.wipeAsk]): the game goes on from the checkpoint. False when nothing was asked.
  bool tryAgain() {
    if (!wipeAsk) return false;
    wipeAsk = false;
    _emit(WipeChosen(wave, t, tryAgain: true, lives: lives));
    return true;
  }

  /// "Give up" ([Game.wipeAsk]): the game is over now, as at 0 lives (the hearts left score nothing, as a game over's
  /// none do). False when nothing was asked.
  bool giveUp() {
    if (!wipeAsk) return false;
    wipeAsk = false;
    _emit(WipeChosen(wave, t, tryAgain: false, lives: lives));
    lives = 0;
    return true;
  }

  /// The checkpoint a wipe goes back to: the slot of the last Town gone into ([Towns.townLast] once one was left), or
  /// null before the first ([Game.townCount] 0).
  int? get checkpoint => townCount > 0 ? _townLast : null;

  /// The [checkpoint] a wipe in this wave goes back to: none past the wave (a test's odd state).
  int? get _checkpointNow => switch (checkpoint) { final s? when s <= wave => s, _ => null };

  /// After a wipe that didn't end the game: the lost wave is remembered ([Game.lostWave], the furthest one), the
  /// monsters are weakened a step more ([Game.weakened]), and the game goes back to the [checkpoint]: its Town is due
  /// again with [Game.wave] at its slot − 1, the schedule rolling from it afresh (a Town marked past it dropped, the
  /// chance back at its start, as when it was marked). With none, the same wave again (322).
  void _backToCheckpoint() {
    lostWave = max(lostWave ?? 0, wave);
    weakened = min(weakenedMost, weakened + 1);
    final s = _checkpointNow;
    if (s == null) {
      wave = max(0, wave - 1); // a test's fight with no wave begun has none to go back from
      return;
    }
    wave = s - 1;
    townAt = s;
    _townChance = null;
  }

  /// The swept monsters' hop is over ([wipeCheer]): each goes in a summon circle.
  void _sweptGone() {
    if (swept.isEmpty || t - wipedAt < wipeCheer) return;
    for (final u in swept) {
      impacts.add((u.pos, 'summon'));
    }
    swept.clear();
  }

  /// What the message window says after a wipe that didn't end the game: back to the checkpoint's Town and the waves
  /// played again ("Back to Millbrook: waves 21-27 again, foes weakened."), or the same wave before the first Town.
  String get wipeNote => '${Words.armyFell} -1 heart.\n$wipeBack, foes weakened.';

  /// The waves played again: "Back to Millbrook: waves 21-27 again" ("wave 21 again" for one), or "Wave 7 again".
  String get wipeBack {
    final next = wave + 1, last = max(next, lostWave ?? next);
    final waves = last > next ? 'waves $next-$last' : 'wave $next';
    return townAgain ? 'Back to ${townIdentity.name}: $waves again' : 'Wave $next again';
  }

  /// The "Weakened foes" chip's tooltip (wipe_ask.dart): what the monsters lose and until when.
  (String, List<String>) get weakenedTip => (
        Words.weakenedFoes,
        ['Monsters: $weakenedCut.', 'Until next ${Words.town}.', if (weakened >= weakenedMost) 'At its most.'],
      );

  /// The monsters' weakening ([Game.weakened]) in words: "-20% HP, -15% damage" (none at 0).
  String get weakenedCut {
    final n = min(weakened, weakenedMost);
    String cut(double k) => '-${((1 - k) * 100).round()}%';
    return n == 0 ? '' : '${cut(weakenedHp[n])} HP, ${cut(weakenedDmg[n])} damage';
  }
}
