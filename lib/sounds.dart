import 'package:flutter/foundation.dart';
import 'package:flutter_soloud/flutter_soloud.dart';

import 'game.dart';

/// Background loops from tool/gen_music.py: calm-but-brave between waves, driving during one.
enum Music { idle, battle }

/// Plays sound effects and music through [output] (SoLoud's). Stays silent until [init] succeeds, so tests
/// and machines without an audio device just run quietly.
class Sounds {
  /// Where the sound goes. Tests can't load SoLoud's native library: one that checks what would be heard sets a
  /// fake of its own here, before [init].
  static SoundOutput output = SoLoudOutput();
  static final _clock = Stopwatch()..start();
  static final _lastPlayed = <Sfx, int>{};
  static Music _scene = Music.idle;
  static const _musicVolume = .35, _fade = Duration(milliseconds: 900), _turn = Duration(milliseconds: 80);
  static double _music = 1, _sfx = 1; // the player's volumes (Settings), 0..1
  static const _ducked = .4; // the music's share while the game is paused
  static double _duck = 1;
  static bool _away = false; // the app is in the background ([background]): every sound holds, none starts
  static double get _loop => _musicVolume * _music * _duck;

  /// The player's volumes (0..1). Call it before [init] for the start; later the music follows at
  /// once (even mid cross-fade) and effects from the next one.
  static void volumes(double music, double sfx) {
    _music = music;
    _sfx = sfx;
    output.fade(_scene, _loop, _turn); // replaces a running fade
  }

  /// Quieter music while the game is paused ([on]), full again after; a no-op when it already is.
  static void duck(bool on) {
    final d = on ? _ducked : 1.0;
    if (d == _duck) return;
    _duck = d;
    output.fade(_scene, _loop, _turn);
  }

  /// A phone's app went to the background ([away]) or came back (main.dart's `muteInBackgroundOnMobile`): away,
  /// every sound holds where it is and no effect starts; back, they go on from there, the music where it was. The
  /// player's volumes stay as they are, so one at 0 stays silent. A no-op when it already is.
  static void background(bool away) {
    if (away == _away) return;
    _away = away;
    output.hold(away);
  }

  /// Forgets when each effect last played, so the next one isn't held back by its gap. For tests, whose boots are
  /// quick enough now for one test's effect to fall inside the gap of the same effect in the one before.
  @visibleForTesting
  static void forgetPlayed() => _lastPlayed.clear();

  static Future<void> init() async {
    try {
      await output.open();
      output.start(_scene, _loop);
    } catch (e) {
      debugPrint('Sound off: $e');
    }
  }

  /// Cross-fades to [m]; a no-op when it's already playing.
  static void scene(Music m) {
    if (m == _scene) return;
    final old = _scene;
    _scene = m;
    output.crossFade(old, m, _loop, _fade);
  }

  // Attacks fire constantly (rogues 4x a second, x2 speed): keep them quiet and spaced out.
  static const _volume = {Sfx.sword: .35, Sfx.dagger: .2, Sfx.magic: .3, Sfx.hit: .3, Sfx.kill: .4, Sfx.fall: .5, Sfx.click: .35};
  static const _gapMs = {Sfx.sword: 90, Sfx.dagger: 120, Sfx.magic: 150, Sfx.hit: 90, Sfx.kill: 70};

  static void play(Sfx s) {
    if (_sfx == 0 || _away) return;
    final now = _clock.elapsedMilliseconds;
    if (now - (_lastPlayed[s] ?? -1 << 30) < (_gapMs[s] ?? 60)) return;
    _lastPlayed[s] = now;
    output.effect(s, (_volume[s] ?? .7) * _sfx);
  }
}

/// What [Sounds] plays through: the effects and the music's loops, by name. Every call before [open] has
/// finished, or after it failed, does nothing.
abstract interface class SoundOutput {
  /// Loads every effect and loop, the loops paused at their start. Throws when there is no sound (no audio
  /// device, no native library).
  Future<void> open();

  /// Starts loop [m] at [volume].
  void start(Music m, double volume);

  /// Plays effect [s] once at [volume].
  void effect(Sfx s, double volume);

  /// Fades loop [m] to [volume] over [time], replacing a fade that runs.
  void fade(Music m, double volume, Duration time);

  /// Fades loop [from] out over [time], pausing it after, and [to] in from silence to [volume].
  void crossFade(Music from, Music to, double volume, Duration time);

  /// Holds every sound where it is ([on]), or lets them go on from there. What starts meanwhile (a loop, a
  /// cross-fade's) waits for it too. Never throws.
  void hold(bool on);
}

/// SoLoud's output: every sound loaded once in [open], played from memory.
class SoLoudOutput implements SoundOutput {
  final _sources = <Sfx, AudioSource>{};
  final _tracks = <Music, SoundHandle>{};
  final _held = <SoundHandle>{}; // the loops [hold] keeps paused: they go on after it
  bool _open = false, _holding = false;

  static SoLoud get _s => SoLoud.instance;

  @override
  Future<void> open() async {
    // miniaudio's Auto tries ALSA first and gives up when there's no ALSA card (WSLg, many
    // PipeWire desktops) even though PulseAudio works; ask for Pulse first, then fall back.
    try {
      await _s.init(linuxAudioBackend: LinuxAudioBackend.pulseAudio);
    } catch (_) {
      await _s.init();
    }
    _open = true;
    for (final s in Sfx.values) {
      _sources[s] = await _s.loadAsset('assets/sfx/${s.name}.wav');
    }
    for (final m in Music.values) {
      final src = await _s.loadAsset('assets/music/${m.name}.ogg');
      _tracks[m] = _s.play(src, looping: true, volume: 0, paused: true);
    }
  }

  @override
  void start(Music m, double volume) {
    final h = _tracks[m];
    if (h == null) return;
    _s.setVolume(h, volume);
    _unpause(h);
  }

  @override
  void effect(Sfx s, double volume) {
    if (_sources[s] case final src?) _s.play(src, volume: volume);
  }

  @override
  void fade(Music m, double volume, Duration time) {
    if (_tracks[m] case final h?) _s.fadeVolume(h, volume, time);
  }

  @override
  void crossFade(Music from, Music to, double volume, Duration time) {
    final old = _tracks[from], now = _tracks[to];
    if (old == null || now == null) return;
    _s.fadeVolume(old, 0, time);
    _s.schedulePause(old, time);
    _s.setVolume(now, 0);
    _unpause(now);
    _s.fadeVolume(now, volume, time);
  }

  /// SoLoud has no pause for everything: the loops that play are paused (a paused voice keeps its place, and its
  /// fades and scheduled pause wait), and the global volume at 0 quiets an effect still sounding. With no voice
  /// playing, SoLoud stops the audio device by itself, and starts it again for the first one.
  @override
  void hold(bool on) {
    if (on == _holding) return;
    _holding = on;
    if (!_open) return;
    try {
      _s.setGlobalVolume(on ? 0 : 1);
      if (on) {
        for (final h in _tracks.values) {
          if (_s.getPause(h)) continue;
          _s.setPause(h, true);
          _held.add(h);
        }
      } else {
        for (final h in _held) {
          _s.setPause(h, false);
        }
        _held.clear();
      }
    } catch (e) {
      debugPrint('Sound hold: $e');
    }
  }

  void _unpause(SoundHandle h) => _holding ? _held.add(h) : _s.setPause(h, false);
}
