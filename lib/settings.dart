import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show debugPrint;

import 'save.dart' show dataFile;

/// The player's settings: music and effect volumes in percent (0..100, in steps of [step]), whether the
/// auto start is on (auto_start.dart, off by default), whether a Hero's cast shows its cut-in (cut_ins.dart,
/// on by default), whether a monster champion's skill shows its banner ([foeCutIns], foe_cut_in.dart, on by
/// default), whether the minimap hangs open under the wave meter ([miniMap], mini_map.dart, shut by
/// default), for the telemetry (#64, lib/telemetry.dart) the anonymous [installId] (made on first
/// use) and whether "Kirim data permainan" sends it to the server ([sendTelemetry], off by default), and the
/// first-time guide's cards already shown ([seen], lib/guide_rules.dart), and whether the dev FPS readout shows
/// ([showFps], fps_readout.dart, off by default). Kept in settings.json beside save.json, so a new game ("Ulang",
/// "Main Baru") never resets them.
class Settings {
  static const step = 10;
  int music, sfx;
  bool autoStart, heroCutIns, foeCutIns, miniMap, sendTelemetry, showFps;
  String? installId;

  /// The guide's keys already shown on this device (the intro, the pointers, the cards: lib/guide_rules.dart). Null
  /// while settings.json has none (a device from before the guide, or a fresh one): main() then gives it one by the
  /// save's wave (`seenFrom`) before the board starts.
  Set<String>? seen;

  Settings(
      {this.music = 100,
      this.sfx = 100,
      this.autoStart = false,
      this.heroCutIns = true,
      this.foeCutIns = true,
      this.miniMap = false,
      this.sendTelemetry = false,
      this.showFps = false,
      this.installId,
      this.seen});

  /// A missing or broken value keeps its default; the volumes are snapped to a step within 0..100, an install
  /// id is 32 hex digits or none, and the seen set keeps its strings (none without a list).
  factory Settings.fromJson(Map<String, dynamic> j) => Settings(
      music: _percent(j['music']),
      sfx: _percent(j['sfx']),
      autoStart: j['autoStart'] == true,
      heroCutIns: j['heroCutIns'] != false,
      foeCutIns: j['foeCutIns'] != false,
      miniMap: j['miniMap'] == true,
      sendTelemetry: j['sendTelemetry'] == true,
      showFps: j['showFps'] == true,
      installId: switch (j['installId']) { final String id when _hexId.hasMatch(id) => id, _ => null },
      seen: switch (j['seen']) { final List keys => {for (final k in keys) if (k is String) k}, _ => null });

  Map<String, dynamic> toJson() => {
        'music': music,
        'sfx': sfx,
        'autoStart': autoStart,
        'heroCutIns': heroCutIns,
        'foeCutIns': foeCutIns,
        'miniMap': miniMap,
        'sendTelemetry': sendTelemetry,
        'showFps': showFps,
        'installId': ?installId,
        if (seen case final keys?) 'seen': [...keys],
      };

  static final _hexId = RegExp(r'^[0-9a-f]{32}$');

  /// [v] moved [by] steps, kept within 0..100.
  static int nudge(int v, int by) => (v + by * step).clamp(0, 100);

  static int _percent(Object? v) => v is num && v.isFinite ? ((v / step).round() * step).clamp(0, 100) : 100;
}

File get _file => dataFile('settings.json');

/// The saved settings, or the defaults when there are none (or they can't be read). [file] is for tests.
Settings loadSettings([File? file]) {
  try {
    final f = file ?? _file;
    return f.existsSync() ? Settings.fromJson(jsonDecode(f.readAsStringSync()) as Map<String, dynamic>) : Settings();
  } catch (_) {
    return Settings(); // a broken file just means the defaults
  }
}

/// Saves [s]; false when it couldn't be written, which only logs (the settings still apply this session).
bool saveSettings(Settings s, [File? file]) {
  final f = file ?? _file;
  try {
    f.parent.createSync(recursive: true);
    f.writeAsStringSync(jsonEncode(s.toJson()));
    return true;
  } catch (e) {
    debugPrint('Settings not saved (${f.path}): $e');
    return false;
  }
}
