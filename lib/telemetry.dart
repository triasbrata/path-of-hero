import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart' show debugPrint;

import 'game.dart';
import 'settings.dart';

// The telemetry (issue #64; the owner: "kita perlu buat fitur log yang dapat dikirim ke server di mana lognya
// itu mencatat semua kejadian yang terjadi dalam game supaya kita punya data untuk balancing gamenya ke
// depan"). A [TelemetryAdapter] listens to the game being played (Game.listeners, #60's event stream) and
// writes records to its [TelemetrySink]s: a few events as they happen, and one summary per wave (the army,
// what came, what fell, gold in and out (the store's too), loot, casts, time, lives). The local JSONL file always gets them; the
// server only when the player turns "Kirim data permainan" on and a server is built in. Nothing personal: an
// anonymous install id, never the scoreboard name, and the troops' own (generated) names are dropped.
// docs/telemetry.md has the records; tool/telemetry_summary.py reads the file.

/// The records' shape: raise it when a field changes (an event's own [eventVersion] rides inside it). 2: a wave's
/// `pusaka` (its start's and what each did), `gold.pusakaSpent` (decisions-log 138). 3: the boss chest's events and
/// `gold.chestSpent` / `gold.chestEarned` (decisions-log 152). 4: Asah's event and `gold.asahSpent` (decisions-log 154).
/// 5: a wave start's `tide.over`, the waves earlier its tide counts from for an army over the cap (Beban, decisions-log
/// 162; gone in 16).
/// 6: Tempa's event and `gold.tempaSpent` (decisions-log 163).
/// 7: Lebur's event and `gold.leburSpent` (decisions-log 164).
/// 8: the Bayangan's events (`omenGained`, `omenEased`), a chest's faces and a take's levels, and a wave start's
/// `omens` (decisions-log 180); Ukir's events, a wave's `ukirItems` / `ukirPoints` / `ukirSteps` and each Pusaka's
/// `ukir` (decisions-log 183). While [omensOn] is off no Bayangan field is written.
/// 9: the Towns' events (`townMarked`, `townEntered`, `townLeft`) and a won wave's `town`, what the Town roll after it
/// did (decisions-log 216); a wave's `materials` (dropped) and its start's (held, decisions-log 221); the Smithy's
/// `crafted` event, a wave's `crafted`, `materialsUsed` and `gold.craftSpent`, and a `townLeft`'s `crafts` and
/// `craftSpent` (decisions-log 233). Every game writes them (decisions-log 321: a test's Towns-off game wrote none).
/// The Bayangan Dusk's event (`omenDusk`, decisions-log 239) came without a raise: like every Bayangan field it is
/// written only while [omensOn] is on, which no player's game has yet, so no record changed.
/// The Tavern's (decisions-log 266: the events `boostBought` and `tavernRerolled`, a wave's `gold.tavernSpent` and
/// `boostSaved`, its start's `boosts`, a `townLeft`'s `tavern`) came without a raise too: only a game with
/// the Tavern's switch on wrote them, which no player's game had yet.
/// 10: the forge in every board game since its cut-over (decisions-log 272), so its fields reach every player's records:
/// a wave's `relics` and `relicPairs` (decisions-log 250), the items, stones and Enhance steps in a wave's `crafted`,
/// `materialsUsed` and `gold.craftSpent` and the events `itemCrafted`, `stoneCrafted`, `itemEnhanced` (decisions-log 249,
/// 255), and what changed meaning: `dropped` holds no item (none drops, decisions-log 246) and `materials` about three
/// times as many. The forge-off build, whose records were as at 9, is gone (decisions-log 296).
/// 11: the Tavern switched on (decisions-log 268): its fields and events (its own switch is gone, decisions-log 296).
/// 12: the Bayangan switched on (decisions-log 319): their fields (8's, Dusk's) reach every player's records.
/// 13: an army wiped mid-wave costs a heart and the wave is played again (decisions-log 322): the event `wipe`, and a
/// wave record's `end` `wiped`.
/// 14: the Towns' market and identities (decisions-log 326): a `storeSold` of an item or a small relic carries its
/// `margin` and `pressure`, a `townEntered` its `n` and `identity`; an item's and a small relic's `gain` is the market's.
/// 15: a Tavern boost's length is rolled with its offer (decisions-log 331): a `boostBought`'s `waves` 2 to 4, or 0 with
/// `untilTown`, and a wave start's `boosts` 0 for one until the next Town.
/// 16: the back line costs nothing (decisions-log 329): no monster heads for it, so a wave's `livesLost` is 0 or a lost
/// wave's heart; a `wipe` has its `cause` (`fell`, `empty`: no troop standing 5 s after the monsters came on, `slow`: its
/// charge not won within 60 s, with `marched` set), each a wave record's `end` `wiped`; Watchman's Brew and the wave's
/// `boostSaved` are gone, and so is a wave start's `tide.over` (Beban went).
/// 17: the Town checkpoint (decisions-log 333): a `wipe`'s `checkpoint` (the Town's slot, null before the first Town) and
/// `debuff` (the monsters' weakening after it), a `townEntered`'s `again` (the checkpoint's Town after a wipe), a wave
/// start's `weakened` and `again` (a wave won before, played again), and the event `wipeChoice` (`tryAgain`, `lives`).
const telemetryVersion = 17;

/// Where [HttpSink] posts (`--dart-define=TELEMETRY_SERVER=https://...`). None by default, so nothing is sent.
const telemetryServer = String.fromEnvironment('TELEMETRY_SERVER');

/// The build in the records (`--dart-define=APP_VERSION=...`).
const appVersion = String.fromEnvironment('APP_VERSION', defaultValue: 'dev');

/// The events that go out as they happen; the others are only summed into the wave's record.
const passedOn = {
  EventKind.fell, EventKind.heroMade, EventKind.awakened, //
  EventKind.bought, EventKind.itemUsed, EventKind.relicUsed, EventKind.storeBought, EventKind.storeSold,
  EventKind.relicTakenOff, EventKind.typeReleased, EventKind.pusakaBound, EventKind.pusakaMoved, EventKind.ascended,
  EventKind.heroRecalled,
  EventKind.offerShown, EventKind.offerPicked, EventKind.offerRerolled, // the boss chest (draft.dart)
  EventKind.pusakaAsah, // a Pusaka's star bought (pusaka.dart's Asah)
  EventKind.tempa, // a Tempa level bought (tempa.dart)
  EventKind.pusakaLebur, // a Gudang Pusaka melted into another for a star (pusaka.dart's Lebur)
  EventKind.omenGained, EventKind.omenEased, // the Bayangan's levels gained and eased (omen.dart)
  EventKind.omenDusk, // the Bayangan Dusk fell in a wave (omen.dart)
  EventKind.ukirFed, EventKind.ukirStep, // items fed to a Pusaka's Ukir bar, and a step it took (pusaka.dart's Ukir)
  EventKind.townMarked, EventKind.townEntered, EventKind.townLeft, // a Town marked, gone into and left (town.dart)
  EventKind.crafted, // a relic crafted at a Town's Smithy (town.dart's Craft)
  EventKind.itemCrafted, // an item crafted there (decisions-log 249)
  EventKind.stoneCrafted, EventKind.itemEnhanced, // a stone made there and an item enhanced (decisions-log 255)
  EventKind.boostBought, EventKind.tavernRerolled, // a Tavern boost bought, its offers rerolled (decisions-log 266)
  EventKind.wipe, // an army wiped mid-wave: a heart lost, the wave played again (decisions-log 322)
  EventKind.wipeChoice, // then "Try again" or "Give up" (decisions-log 333)
};

/// Where the records go.
abstract interface class TelemetrySink {
  void add(Map<String, Object?> record);

  /// Writes or sends what was added. Never throws.
  Future<void> flush();
}

/// Takes the records and keeps none.
class NoSink implements TelemetrySink {
  const NoSink();

  @override
  void add(Map<String, Object?> record) {}

  @override
  Future<void> flush() async {}
}

/// JSON lines appended to [file] (telemetry.jsonl beside the save). Once a flush would take it past [maxBytes]
/// it becomes `<file>.1` (the older ones `.2` .. `.keep`, the oldest deleted), so the files never pass
/// (keep + 1) × maxBytes. Records wait in memory until [flush]; a file that can't be written loses them.
class FileSink implements TelemetrySink {
  FileSink(this.file, {this.maxBytes = 256 * 1024, this.keep = 2});

  final File file;
  final int maxBytes, keep;
  final _lines = <String>[];

  @override
  void add(Map<String, Object?> record) => _lines.add(jsonEncode(record));

  @override
  Future<void> flush() async {
    if (_lines.isEmpty) return;
    final text = '${_lines.join('\n')}\n';
    _lines.clear();
    try {
      file.parent.createSync(recursive: true);
      final size = file.existsSync() ? file.lengthSync() : 0;
      if (size > 0 && size + utf8.encode(text).length > maxBytes) _rotate();
      file.writeAsStringSync(text, mode: FileMode.append, flush: true);
    } catch (e) {
      debugPrint('Telemetry not written (${file.path}): $e'); // no disk, no telemetry: the game goes on
    }
  }

  /// The [i]th older file.
  File older(int i) => File('${file.path}.$i');

  void _rotate() {
    if (keep < 1) {
      file.deleteSync();
      return;
    }
    if (older(keep).existsSync()) older(keep).deleteSync();
    for (var i = keep - 1; i >= 1; i--) {
      if (older(i).existsSync()) older(i).renameSync(older(i + 1).path);
    }
    file.renameSync(older(1).path);
  }
}

/// Sends [body] (JSON) to [url]; true when it was taken.
typedef TelemetryPost = Future<bool> Function(Uri url, String body);

/// A STUB until there is a server: posts the records to [url] in batches of [batch],
/// `{"tv": telemetryVersion, "records": [...]}`. Only [on] (the player turned it on, and [url] is set) does it
/// take records at all; at most [keepMax] wait, the oldest dropped. A batch that fails goes back to wait, and
/// nothing is tried again for [retry], doubling each failure up to [maxRetry]. Tests pass their own [post].
class HttpSink implements TelemetrySink {
  HttpSink(this.url,
      {this._enabled = false, // enabled:
      this._post = postJson, // post:
      this.batch = 100,
      this.keepMax = 1000,
      this.retry = const Duration(seconds: 5),
      this.maxRetry = const Duration(minutes: 5),
      DateTime Function()? now})
      : _now = now ?? DateTime.now,
        _wait = retry;

  final String url;
  final int batch, keepMax;
  final Duration retry, maxRetry;
  final TelemetryPost _post;
  final DateTime Function() _now;
  final _queue = <Map<String, Object?>>[];
  bool _enabled, _busy = false;
  DateTime? _retryAt;
  Duration _wait;

  /// The player's "Kirim data permainan" (settings.json). Turning it off drops what waits.
  bool get enabled => _enabled;
  set enabled(bool on) {
    _enabled = on;
    if (!on) _queue.clear();
  }

  /// Turned on, with somewhere to send to.
  bool get on => _enabled && url.trim().isNotEmpty;

  /// How many records wait to go.
  int get waiting => _queue.length;

  @override
  void add(Map<String, Object?> record) {
    if (!on) return;
    _queue.add(record);
    _trim();
  }

  void _trim() {
    if (_queue.length > keepMax) _queue.removeRange(0, _queue.length - keepMax); // the oldest go
  }

  @override
  Future<void> flush() async {
    if (!on || _busy || _queue.isEmpty) return;
    if (_retryAt case final at? when _now().isBefore(at)) return;
    _busy = true;
    try {
      while (on && _queue.isNotEmpty) {
        final sent = _queue.sublist(0, min(batch, _queue.length));
        _queue.removeRange(0, sent.length);
        var ok = false;
        try {
          ok = await _post(Uri.parse(url.trim()), jsonEncode({'tv': telemetryVersion, 'records': sent}));
        } catch (_) {
          // a failure like any other
        }
        if (!ok) {
          if (on) {
            _queue.insertAll(0, sent);
            _trim();
          }
          _retryAt = _now().add(_wait);
          _wait = _wait * 2 > maxRetry ? maxRetry : _wait * 2;
          return;
        }
        _retryAt = null;
        _wait = retry;
      }
    } finally {
      _busy = false;
    }
  }
}

/// POSTs [body] as JSON to [url]; true on a 2xx answer. [HttpSink]'s own.
Future<bool> postJson(Uri url, String body, {Duration timeout = const Duration(seconds: 10)}) async {
  final client = HttpClient()..connectionTimeout = timeout;
  try {
    return await () async {
      final bytes = utf8.encode(body);
      final req = await client.postUrl(url);
      req.headers.contentType = ContentType.json;
      req.contentLength = bytes.length;
      req.add(bytes);
      final res = await req.close();
      await res.drain<void>();
      return res.statusCode >= 200 && res.statusCode < 300;
    }()
        .timeout(timeout);
  } finally {
    client.close(force: true);
  }
}

/// [bytes] random bytes in hex, from [rng] (a secure one by default): nothing about the player or the device.
String randomId([Random? rng, int bytes = 16]) {
  final r = rng ?? Random.secure();
  return [for (var i = 0; i < bytes; i++) r.nextInt(256).toRadixString(16).padLeft(2, '0')].join();
}

/// [s]'s anonymous install id, made and saved (to [file], settings.json by default) the first time.
String installIdOf(Settings s, {File? file, Random? rng}) {
  if (s.installId case final id?) return id;
  final id = s.installId = randomId(rng);
  saveSettings(s, file); // unsaved (no disk), it is new again next launch
  return id;
}

/// Listens to one [Game] at a time ([attach]) and writes the records to [sinks]: `session` once, `game` on
/// each attach, `event` for the [passedOn] kinds, and `wave` when a wave ends (won, lost, wiped, or left behind by
/// [detach]). Each carries [telemetryVersion] (`tv`), what it is (`rec`), the [installId], the [session], the
/// game's number within the session and the time (`at`, UTC). The sinks are flushed at each wave's end.
class TelemetryAdapter {
  TelemetryAdapter(this.sinks, {required this.installId, String? session, String? platform, DateTime Function()? now})
      : session = session ?? randomId(null, 8),
        _now = now ?? DateTime.now {
    _write('session', {'app': appVersion, 'platform': platform ?? Platform.operatingSystem, 'ev': eventVersion});
  }

  final List<TelemetrySink> sinks;
  final String installId, session;
  final DateTime Function() _now;
  Game? _game;
  int _games = 0;
  var _w = _WaveSum();

  /// A won wave's record waiting for what the Town roll after it did ([TownRolled], the same tick: the roll comes after
  /// the Hero and the chest in the win path), only while the game's Towns are on.
  Map<String, Object?>? _held;

  /// The game listened to.
  Game? get game => _game;

  /// Listens to [g] from now on (and no longer to the one before, [detach]); again for the same game does
  /// nothing. Writes a `game` record: a new game is at wave 0, a loaded save further on.
  void attach(Game g) {
    if (identical(g, _game)) return;
    detach();
    _game = g..listeners.add(_hear);
    _writeHeld();
    _games++;
    _w = _WaveSum();
    _write('game', {'wave': g.wave, 'gold': g.gold, 'lives': g.lives, 'score': g.score});
  }

  /// Stops listening; a wave still on is summed up as `left`. Flushes.
  void detach() {
    final g = _game;
    if (g == null) return;
    g.listeners.remove(_hear);
    if (_w.start != null) _sum(g, 'left');
    _writeHeld();
    _game = null;
    unawaited(flush());
  }

  Future<void> flush() => Future.wait([for (final s in sinks) s.flush()]);

  void _write(String rec, Map<String, Object?> body) {
    final r = {
      'tv': telemetryVersion,
      'rec': rec,
      'install': installId,
      'session': session,
      'game': _games,
      'at': _now().toUtc().toIso8601String(),
      ...body,
    };
    for (final s in sinks) {
      s.add(r);
    }
  }

  void _hear(GameEvent e) {
    final w = _w;
    if (passedOn.contains(e.kind)) _write('event', {'event': e.toJson()..remove('name')});
    switch (e) {
      case final WaveStarted s:
        _writeHeld(); // a held record never waits past the next wave (it can't: the roll is in the win's tick)
        w
          ..start = s
          ..kills = _game!.kills;
      case MonsterSpawned(:final type, :final tier, :final raised):
        _count2(raised ? w.raised : w.spawns, type, tier.name);
      case SkillCast(:final skill):
        _count(w.casts, skill);
      case HeroSkillCast(:final skill):
        _count(w.heroCasts, skill.name);
      case AwakenSkillCast(:final skill):
        _count(w.awakenCasts, skill.name); // by the skill's id: its levels aren't told apart
      case MonsterSkillCast(:final skill, :final tier):
        _count2(w.monsterCasts, skill.name, tier.name);
      case TroopFell(:final type, :final hero, :final killer, :final killerTier):
        _count(w.fallen, type);
        if (hero) w.heroesFallen++;
        if (killer != null) _count2(w.killers, killer, killerTier!.name);
      case Bought(:final type, :final cost):
        _count(w.bought, type ?? 'capacity');
        w.spent += cost;
        if (w.start != null) w.spentOn += cost;
      case StoreBought(:final loot, :final cost):
        _count(w.storeBought, loot.name);
        w.storeSpent += cost;
        if (w.start != null) w.storeSpentOn += cost;
      case Ascended(:final cost):
        w.ascendSpent += cost;
        if (w.start != null) w.ascendSpentOn += cost;
      case HeroRecalled(:final cost):
        w.recallSpent += cost;
        if (w.start != null) w.recallSpentOn += cost;
      case StoreSold(:final loot, :final n, :final gain):
        w.storeSold[loot.name] = (w.storeSold[loot.name] ?? 0) + n;
        w.storeEarned += gain;
        if (w.start != null) w.storeEarnedOn += gain;
      case ItemUsed(:final item):
        _count(w.used, item.name);
      case RelicUsed(:final relic):
        _count(w.relicsUsed, relic.name);
      case RelicTakenOff(:final relic):
        _count(w.relicsTakenOff, relic.name);
      case PusakaBound(:final cost) || PusakaMoved(:final cost):
        w.pusakaSpent += cost; // a Pindah's; passed on as it happens
      case Marched():
        w.marchedAt = e.t;
      case WaveEnded(:final won):
        _sum(_game!, won ? 'won' : (_game!.over ? 'lost' : 'wiped')); // wiped: played again (wipe.dart)
      case OfferRerolled(:final price):
        w.chestSpent += price; // a Serpihan's reroll is free: 0
      case OfferPicked(:final gain):
        w.chestEarned += gain; // Lewati's gold
      case PusakaAsah(:final cost):
        w.asahSpent += cost; // between waves only, so never in a wave's own earnings
      case Tempered(:final cost):
        w.tempaSpent += cost; // between waves only, like Asah
      case PusakaLebur(:final cost):
        w.leburSpent += cost; // between waves only, like Asah
      case UkirFed(:final items, :final points):
        for (final MapEntry(key: i, value: n) in items.entries) {
          w.ukirItems[i.name] = (w.ukirItems[i.name] ?? 0) + n;
        }
        w.ukirPoints += points; // between waves only, like Asah
      case UkirStep(:final relic):
        _count(w.ukirSteps, relic.name);
      case TownRolled(:final town):
        _writeHeld(town); // the won wave's record, with what the roll after it did
      case Crafted(:final relic, :final materials, :final gold):
        _count(w.crafted, relic.name);
        for (final MapEntry(key: m, value: n) in materials.entries) {
          w.materialsUsed[m.name] = (w.materialsUsed[m.name] ?? 0) + n;
        }
        w.craftSpent += gold; // in a Town, between waves only, like Asah
      case ItemCrafted(:final item, :final materials, :final gold):
        _count(w.crafted, item.name); // an item's name is never a relic's
        for (final MapEntry(key: m, value: n) in materials.entries) {
          w.materialsUsed[m.name] = (w.materialsUsed[m.name] ?? 0) + n;
        }
        w.craftSpent += gold;
      case StoneCrafted(:final stone, :final materials, :final gold):
        _count(w.crafted, stone.name); // a stone's name is never an item's or a relic's
        for (final MapEntry(key: m, value: n) in materials.entries) {
          w.materialsUsed[m.name] = (w.materialsUsed[m.name] ?? 0) + n;
        }
        w.craftSpent += gold;
      case ItemEnhanced(:final stone, :final gold):
        w.materialsUsed[stone.name] = (w.materialsUsed[stone.name] ?? 0) + 1;
        w.craftSpent += gold;
      case BoostBought(:final price) || TavernRerolled(:final price):
        w.tavernSpent += price; // in a Town, between waves only, like Asah
      case BoostEnded():
        break; // the next wave's start has the boosts still running
      case StrongFoe() || HeroMade() || Awakened() || TypeReleased() || GrailSaved() || PusakaReport() || OfferShown() || OmenGained() || OmenEased() || OmenDusk():
        break;
      case TownMarked() || TownEntered() || TownLeft():
        break; // passed on as they happen // the spawns count the strong foes, the wave record has the Pusaka's; the others are passed on
      case Wiped():
        break; // passed on as it happens; the WaveEnded right after closes the record as `wiped` (or `lost`)
      case WipeChosen():
        break; // passed on as it happens, between waves (decisions-log 333)
    }
  }

  /// [_held] written, with [town] when it came; nothing when none waits.
  void _writeHeld([Map<String, Object>? town]) {
    final h = _held;
    if (h == null) return;
    _held = null;
    _write('wave', {...h, 'town': ?town});
    unawaited(flush());
  }

  /// The `wave` record of the wave begun at [_WaveSum.start], ended now as [end], read off [g]; then a
  /// fresh sum and a flush. A won one waits for its Town roll ([_held]).
  void _sum(Game g, String end) {
    final w = _w, s = w.start;
    _w = _WaveSum();
    if (s != null) {
      double secs(double t) => ((t - s.t) * 100).round() / 100;
      final record = <String, Object?>{
        'wave': s.wave,
        'end': end, // won, lost (the game is over), wiped (the army fell: played again) or left (a new game or a save came in mid-wave)
        'secs': secs(g.t), // time to clear
        'marched': w.marchedAt == null ? null : secs(w.marchedAt!), // when it stalled and the monsters marched
        'start': s.data, // the army, awakening levels, Heroes, gold, capacity, lives and bags it began with
        'livesLost': s.lives - g.lives,
        'spawns': w.spawns, // type -> tier -> how many came from the wave's queue
        'raised': w.raised, // the same for the necromancers' minions
        'kills': g.kills - w.kills,
        'fallen': w.fallen, // troop type -> how many fell
        'heroesFallen': w.heroesFallen,
        'killers': w.killers, // monster type -> tier -> troops it felled
        'bought': w.bought, // troop type (or 'capacity') -> how many, since the last wave ended
        'storeBought': w.storeBought, // item, relic or (the forge's Shop) material -> how many bought in the store (#63), since then
        'storeSold': w.storeSold, // item or relic -> how many sold to it
        'gold': {
          'start': s.gold,
          'end': g.gold, // before the win's bonus
          'earned': g.gold - s.gold + w.spentOn + w.storeSpentOn + w.ascendSpentOn + w.recallSpentOn - w.storeEarnedOn, // in battle: kills and plunder
          'spent': w.spent, // on troops and capacity since the last wave ended: before it and during it
          'storeSpent': w.storeSpent, // in the store, since then
          'storeEarned': w.storeEarned, // what the store paid for loot sold, since then
          'ascendSpent': w.ascendSpent, // on Bangkit 4 and 5 in the Toko (#92 part 2), since then
          'recallSpent': w.recallSpent, // on calling fallen Heroes back in the Toko (#92 part 3), since then
          'pusakaSpent': w.pusakaSpent, // on Pindah (binding a Pusaka again), since then
          'chestSpent': w.chestSpent, // on the boss chest's rerolls (Kocok ulang), since then
          'chestEarned': w.chestEarned, // from passing boss chests over (Lewati), since then
          'asahSpent': w.asahSpent, // on Asah (a Pusaka's star, on the Tas page), since then
          'tempaSpent': w.tempaSpent, // on Tempa (past Bangkit 5, in the Toko), since then
          'leburSpent': w.leburSpent, // on Lebur (a Gudang Pusaka melted into another for a star), since then
          'craftSpent': w.craftSpent, // on relics crafted at a Town's Smithy, since then
          'tavernSpent': w.tavernSpent, // on the Tavern's boosts and rerolls, since then
          'bonus': end == 'won' ? Game.waveBonus(s.wave) : 0,
        },
        // Each Pusaka owned: its type and stars now, and what it did in the wave (decisions-log 138): `uses` (the
        // Grail's saves) and `worth`, its effective counter (pusaka.dart's PusakaTally).
        // Its Ukir steps too, once it has any (decisions-log 183).
        'pusaka': {
          for (final MapEntry(key: r, value: p) in g.pusaka.entries)
            r.name: {
              'type': p.type,
              'stars': p.stars,
              if (p.ukir > 0) 'ukir': p.ukir,
              'uses': g.pusakaWorth[r]?.uses ?? 0,
              'worth': _round(g.pusakaWorth[r]?.worth ?? 0),
            },
        },
        // The forge's small relics (relics.dart, decisions-log 250): each of the nine that did something, its uses and the
        // damage it added; and each pair a troop wielded (its relics, "@" its type's Artifact: "fury+giantSlayer",
        // "chill@snareCord"), the troops of it that dealt damage and how much.
        'relics': {
          for (final r in forgeRelics)
            if (g.relicWorth[r] case final w? when w.uses > 0) r.name: {'uses': w.uses, 'worth': _round(w.worth)},
        },
        'relicPairs': {
          for (final MapEntry(:key, :value) in g.relicPairs.entries) key: {'troops': value.ids.length, 'dealt': _round(value.dealt)},
        },
        // Ukir (pusaka.dart), only when some was fed since the last wave ended: the items fed by kind, their points, and
        // each Pusaka's steps taken.
        if (w.ukirPoints > 0) ...{'ukirItems': w.ukirItems, 'ukirPoints': w.ukirPoints, 'ukirSteps': w.ukirSteps},
        // No item or relic drops on the field (decisions-log 246, 321): always empty, kept so the record's shape stays.
        'dropped': const <String, int>{},
        'relicsDropped': const <String, int>{},
        // The Towns' materials the wave dropped (town.dart; summed, never an event each): read off the game before a win
        // moves them into the bag.
        'materials': {for (final MapEntry(:key, :value) in g.waveMaterials.entries) key.name: value},
        // The relics crafted at a Town's Smithy since the last wave ended (town.dart's Craft), by kind, and the materials
        // they took.
        'crafted': w.crafted,
        'materialsUsed': w.materialsUsed,
        'used': w.used, // items given, since the last wave ended
        'relicsUsed': w.relicsUsed,
        'relicsTakenOff': w.relicsTakenOff, // relics taken off troops back into the bag (#91), since the last wave ended
        'casts': w.casts, // troop skill -> casts
        'heroCasts': w.heroCasts, // Hero skill -> casts
        'awakenCasts': w.awakenCasts, // awakening skill (#88) -> casts
        'monsterCasts': w.monsterCasts, // monster skill -> rank -> casts (#59)
        'score': g.score,
      };
      if (end == 'won') {
        _held = record; // [TownRolled] comes later in this tick
        return;
      }
      _write('wave', record);
    }
    unawaited(flush());
  }

  static void _count(Map<String, int> m, String k) => m[k] = (m[k] ?? 0) + 1;

  /// [v] to two decimals, for the file.
  static double _round(double v) => (v * 100).round() / 100;

  static void _count2(Map<String, Map<String, int>> m, String k, String k2) => _count(m[k] ??= {}, k2);
}

/// One wave's sums, from the end of the one before to its own.
class _WaveSum {
  WaveStarted? start;
  // The ...On: after the wave's start.
  int kills = 0, heroesFallen = 0, spent = 0, spentOn = 0, storeSpent = 0, storeSpentOn = 0, storeEarned = 0, storeEarnedOn = 0;
  int ascendSpent = 0, ascendSpentOn = 0, recallSpent = 0, recallSpentOn = 0;
  int chestSpent = 0, chestEarned = 0;
  int pusakaSpent = 0, asahSpent = 0, tempaSpent = 0, leburSpent = 0, craftSpent = 0, tavernSpent = 0;
  double? marchedAt;
  final spawns = <String, Map<String, int>>{}, raised = <String, Map<String, int>>{}, killers = <String, Map<String, int>>{};
  final monsterCasts = <String, Map<String, int>>{};
  final casts = <String, int>{}, heroCasts = <String, int>{}, awakenCasts = <String, int>{}, fallen = <String, int>{}, bought = <String, int>{};
  final used = <String, int>{}, relicsUsed = <String, int>{};
  final storeBought = <String, int>{}, storeSold = <String, int>{}, relicsTakenOff = <String, int>{};
  final ukirItems = <String, int>{}, ukirSteps = <String, int>{};
  final crafted = <String, int>{}, materialsUsed = <String, int>{};
  int ukirPoints = 0;
}
