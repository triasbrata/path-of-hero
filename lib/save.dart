import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show debugPrint, visibleForTesting;
import 'package:path_provider/path_provider.dart' show getApplicationSupportDirectory;

import 'game.dart';

/// The app's own files dir on a phone (Android's `Context.getFilesDir()`, iOS's Application Support), found by
/// [initDataDir]; null on desktop, in tests, or when the lookup failed.
String? _appDir;

/// Looks up the app's own files dir on Android and iOS, which set no HOME (decisions-log 133). Desktop needs
/// nothing. main() awaits it before the first [dataFile]; [lookup] is for tests.
Future<void> initDataDir({String? os, Future<Directory> Function() lookup = getApplicationSupportDirectory}) async {
  final phone = const {'android', 'ios'}.contains(os ?? Platform.operatingSystem);
  try {
    _appDir = phone ? (await lookup()).path : null;
  } catch (e) {
    _appDir = null;
    debugPrint('No app files dir, nothing will be saved: $e');
  }
}

/// The game's folder on [os] ([Platform.operatingSystem]'s names), from [env] and [appDir] ([initDataDir]'s):
/// - with [appDir] (Android, iOS): `<appDir>/tower_defense`;
/// - Windows: `%APPDATA%/tower_defense`;
/// - elsewhere (macOS, Linux): `~/.local/share/tower_defense`, on macOS inside the app's sandbox container.
///   A phone whose files dir wasn't found has no HOME and lands in `/`, where every write fails (and logs).
String dataDirFor(String os, Map<String, String> env, {String? appDir}) =>
    '${appDir ?? (os == 'windows' ? env['APPDATA'] : '${env['HOME'] ?? ''}/.local/share')}/tower_defense';

/// Tests only: the game's folder in place of [dataDirFor]'s. test/flutter_test_config.dart sets it to a fresh temp
/// dir for each test file, so test files running at once never share a save or settings.json, and no test reaches
/// HOME's (decisions-log 144). Null in the app.
@visibleForTesting
String? testDataDir;

/// A file in the game's folder ([dataDirFor]; [testDataDir] under tests).
File dataFile(String name) =>
    File('${testDataDir ?? dataDirFor(Platform.operatingSystem, Platform.environment, appDir: _appDir)}/$name');

/// Auto-save between waves.
File get _file => dataFile('save.json');

/// Whether [j] (a save file's JSON) is of a format this build loads: its `v` at least [Game.saveLoadsFrom] (2: a
/// version-2 save loads forward, decisions-log 245). A save from before the Towns has none (decisions-log 237).
bool _current(Object? j) => j is Map && switch (j['v']) { final int v => v >= Game.saveLoadsFrom, _ => false };

/// The saved game, or null when there is none, it can't be read, or it is from before [Game.saveLoadsFrom] (an old one
/// is no save: [launchSave] deletes it).
Game? loadGame() {
  try {
    final f = _file;
    if (!f.existsSync()) return null;
    final j = jsonDecode(f.readAsStringSync());
    return _current(j) ? Game.fromJson(j as Map<String, dynamic>) : null;
  } catch (_) {
    return null; // a broken save just means a fresh game
  }
}

/// Whether save.json holds a readable save from before [Game.saveLoadsFrom] (no `v`, or a lower one).
bool _oldSave() {
  try {
    final f = _file;
    return f.existsSync() && switch (jsonDecode(f.readAsStringSync())) { final Map j => !_current(j), _ => false };
  } catch (_) {
    return false; // a broken file is no save either ([loadGame]), and stays until the next save writes over it
  }
}

/// The save the launch offers ("Continue", [Welcome]): [loadGame]'s, after a save from before the Towns was deleted
/// ([clearSave]; the owner, 2026-10-04: "save lama di hapus saja, toh baru developer yang pakai"; decisions-log 237): the
/// welcome then offers only a new game. No refund, no migration, no note; settings.json, the scoreboard and the
/// telemetry are other files, untouched.
Game? launchSave() {
  if (_oldSave()) clearSave();
  return loadGame();
}

/// Saves [g] (to [file], save.json by default); false when it couldn't be written (no disk, no folder),
/// which only logs: the game goes on, and the save before stays.
bool saveGame(Game g, [File? file]) {
  final f = file ?? _file;
  try {
    f.parent.createSync(recursive: true);
    f.writeAsStringSync(jsonEncode(g.toJson()));
    return true;
  } catch (e) {
    debugPrint('Not saved (${f.path}): $e');
    return false;
  }
}

/// The wave of the saved game (save.json's, [file] in tests), or null when there is none, it can't be read or it is
/// from before [Game.saveLoadsFrom] ([loadGame]'s rule): what the guide's seen set starts from on a device from before
/// it (`seenFrom`, lib/guide_rules.dart). It reads the number alone, without loading the game.
int? savedWave([File? file]) {
  try {
    final f = file ?? _file;
    if (!f.existsSync()) return null;
    final j = jsonDecode(f.readAsStringSync());
    return _current(j) ? (j as Map<String, dynamic>)['wave'] as int? : null;
  } catch (_) {
    return null;
  }
}

void clearSave() {
  final f = _file;
  try {
    if (f.existsSync()) f.deleteSync();
  } catch (e) {
    debugPrint('Save not deleted (${f.path}): $e');
  }
}

/// The welcome screen's choice: back into [saved] ("Lanjutkan"), or a fresh game ("Main Baru"). A fresh
/// game throws [saved] away with the save file, so while there is one it takes a second tap within
/// [confirmTime] seconds; without one, one tap starts.
class Welcome {
  Welcome(this.saved, {this.discard = clearSave});

  final Game? saved;
  final void Function() discard; // deletes the save file (tests pass their own)
  static const confirmTime = 3.0;
  double _askedAt = double.negativeInfinity;

  /// Whether "Main Baru" waits for its second tap ("Yakin?") at [now], in seconds on any steady clock.
  bool confirming(double now) => now - _askedAt < confirmTime;

  /// "Main Baru" tapped at [now]: the fresh game (the save deleted), or null when this tap only asked.
  Game? fresh(double now) {
    if (saved != null && !confirming(now)) {
      _askedAt = now;
      return null;
    }
    discard();
    return Game();
  }
}
