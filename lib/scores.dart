import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'game.dart';
import 'save.dart' show dataFile;

// The scoreboard's storage (docs/scoreboard.md): a [ScoreRepository] is where finished games' scores go
// and the top of the board comes from. [LocalScoreRepository] keeps them in a file on this device,
// [HttpScoreRepository] on a server; [scoreRepository] picks one. Pure Dart, so the tests reach it.

/// One finished game on the scoreboard.
class ScoreEntry {
  ScoreEntry({required String name, required this.score, required this.wave, this.kills = 0, DateTime? at})
      : name = cleanName(name),
        at = _wholeMs((at ?? DateTime.now()).toUtc());

  /// The entry for the finished game [g], played by [name].
  ScoreEntry.of(Game g, String name, [DateTime? at]) : this(name: name, score: g.score, wave: g.wave, kills: g.kills, at: at);

  /// Throws a [FormatException] (or a [TypeError]) when [j] isn't one.
  factory ScoreEntry.fromJson(Map<String, dynamic> j) => ScoreEntry(
      name: j['name'] as String,
      score: (j['score'] as num).toInt(),
      wave: (j['wave'] as num).toInt(),
      kills: (j['kills'] as num?)?.toInt() ?? 0,
      at: DateTime.parse(j['at'] as String));

  final String name;
  final int score, wave, kills;
  final DateTime at; // when it ended, UTC, in whole milliseconds (what a trip through JSON keeps)

  static const maxName = 12, defaultName = 'Player'; // entries kept as "Pemain" (before the English text) stay so

  Map<String, Object> toJson() => {'name': name, 'score': score, 'wave': wave, 'kills': kills, 'at': at.toIso8601String()};

  /// [s] without control characters and outer spaces, cut to [maxName] characters; [defaultName] when
  /// nothing is left.
  static String cleanName(String s) {
    final t = s.replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '').trim();
    return t.isEmpty ? defaultName : String.fromCharCodes(t.runes.take(maxName)).trimRight();
  }

  /// Board order: the higher score first; on a tie, the earlier game.
  static int byRank(ScoreEntry a, ScoreEntry b) => a.score != b.score ? b.score.compareTo(a.score) : a.at.compareTo(b.at);

  static DateTime _wholeMs(DateTime t) => DateTime.fromMillisecondsSinceEpoch(t.millisecondsSinceEpoch, isUtc: true);

  @override
  bool operator ==(Object other) =>
      other is ScoreEntry &&
      other.name == name &&
      other.score == score &&
      other.wave == wave &&
      other.kills == kills &&
      other.at == at;

  @override
  int get hashCode => Object.hash(name, score, wave, kills, at);

  @override
  String toString() => 'ScoreEntry($name, $score, wave $wave, $kills kills, $at)';
}

/// The entries of a JSON list; items that aren't an entry are skipped. Throws a [FormatException] when
/// [json] isn't a list.
List<ScoreEntry> entriesFromJson(Object? json) {
  if (json is! List) throw const FormatException('not a list of scores');
  final out = <ScoreEntry>[];
  for (final j in json) {
    try {
      out.add(ScoreEntry.fromJson(j as Map<String, dynamic>));
    } catch (_) {
      // a broken entry is left out, not the whole board
    }
  }
  return out;
}

/// Where scores are kept.
abstract class ScoreRepository {
  /// Puts [e] on the board.
  Future<void> submit(ScoreEntry e);

  /// The best [limit] entries, best first ([ScoreEntry.byRank]).
  Future<List<ScoreEntry>> top({int limit = 10});

  /// Whether the last call couldn't reach the server and was answered from this device instead
  /// ([ServerScoreRepository]). A repository that doesn't fall back throws instead.
  bool get offline => false;
}

/// A JSON list of entries in [file], read and written one call at a time (so two writes never mix).
/// A missing or broken file reads as empty; a write replaces the file whole (through a temporary one).
class _EntryFile {
  _EntryFile(this.file);

  final File file;
  Future<void> _last = Future.value();

  /// Runs [job] once every call before it has finished.
  Future<T> inTurn<T>(Future<T> Function() job) {
    final done = _last.then((_) => job());
    _last = done.then((_) {}, onError: (_) {});
    return done;
  }

  Future<List<ScoreEntry>> read() async {
    try {
      return await file.exists() ? entriesFromJson(jsonDecode(await file.readAsString())) : [];
    } catch (_) {
      return []; // a broken file just means an empty board
    }
  }

  Future<void> write(List<ScoreEntry> all) async {
    await file.parent.create(recursive: true);
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(jsonEncode([for (final e in all) e.toJson()]));
    await tmp.rename(file.path);
  }
}

/// The board in a file on this device (scores.json in the game's folder): the best [keep] entries.
class LocalScoreRepository extends ScoreRepository {
  LocalScoreRepository([File? file, this.keep = 100]) : _file = _EntryFile(file ?? dataFile('scores.json'));

  final _EntryFile _file;
  final int keep;

  File get file => _file.file;

  @override
  Future<void> submit(ScoreEntry e) => _file.inTurn(() async {
        final all = [...await _file.read(), e]..sort(ScoreEntry.byRank);
        await _file.write(all.take(keep).toList());
      });

  @override
  Future<List<ScoreEntry>> top({int limit = 10}) =>
      _file.inTurn(() async => (await _file.read()..sort(ScoreEntry.byRank)).take(limit).toList());
}

/// A call to the score server that failed: no connection, no answer within the timeout, a status other
/// than 2xx, or a body that isn't what the contract says.
class ScoreServerException implements Exception {
  ScoreServerException(this.message);

  final String message;

  @override
  String toString() => 'ScoreServerException: $message';
}

/// The board on a server (docs/scoreboard.md has the contract): `POST {baseUrl}/scores` with an entry,
/// `GET {baseUrl}/scores?limit=N` for the best N. Every failure throws a [ScoreServerException].
class HttpScoreRepository extends ScoreRepository {
  HttpScoreRepository(String baseUrl, {this.timeout = const Duration(seconds: 5), HttpClient? client})
      : baseUrl = baseUrl.trim().replaceFirst(RegExp(r'/+$'), ''),
        _client = (client ?? HttpClient())..connectionTimeout = timeout;

  final String baseUrl; // without a trailing slash
  final Duration timeout; // for each whole call: connecting, sending and reading the answer
  final HttpClient _client;

  @override
  Future<void> submit(ScoreEntry e) async {
    final (status, _) = await _call('POST', Uri.parse('$baseUrl/scores'), e.toJson());
    if (status < 200 || status > 299) throw ScoreServerException('POST /scores answered $status');
  }

  @override
  Future<List<ScoreEntry>> top({int limit = 10}) async {
    final (status, body) = await _call('GET', Uri.parse('$baseUrl/scores?limit=$limit'));
    if (status != 200) throw ScoreServerException('GET /scores answered $status');
    try {
      return (entriesFromJson(jsonDecode(body))..sort(ScoreEntry.byRank)).take(limit).toList();
    } on FormatException catch (e) {
      throw ScoreServerException('GET /scores: ${e.message}');
    }
  }

  /// The status and body of [method] [url] with [json] as the body.
  Future<(int, String)> _call(String method, Uri url, [Object? json]) async {
    try {
      return await () async {
        final req = await _client.openUrl(method, url);
        req.headers.set(HttpHeaders.acceptHeader, 'application/json');
        if (json != null) {
          final bytes = utf8.encode(jsonEncode(json));
          req.headers.contentType = ContentType.json;
          req.contentLength = bytes.length;
          req.add(bytes);
        }
        final res = await req.close();
        return (res.statusCode, await res.transform(utf8.decoder).join());
      }()
          .timeout(timeout);
    } catch (e) {
      throw ScoreServerException('$method $url: $e');
    }
  }
}

/// A server with this device as its backup, so no score is lost while the server is down or not there
/// yet. Every entry is written to [local] as well. One the server didn't take waits in [outbox] and is
/// sent again, oldest first, before the next call. When the server can't be reached, [top] answers
/// from [local] and [offline] says so; [submit] then doesn't throw either.
class ServerScoreRepository extends ScoreRepository {
  ServerScoreRepository(this.server, this.local, File outbox) : _outbox = _EntryFile(outbox);

  final ScoreRepository server;
  final LocalScoreRepository local;
  final _EntryFile _outbox;
  Future<void>? _sending; // the outbox on its way, shared by calls that start meanwhile

  @override
  bool offline = false;

  File get outbox => _outbox.file;

  @override
  Future<void> submit(ScoreEntry e) async {
    await local.submit(e);
    try {
      await _flush();
      await server.submit(e);
      offline = false;
    } catch (_) {
      offline = true;
      await _outbox.inTurn(() async => _outbox.write([...await _outbox.read(), e]));
    }
  }

  @override
  Future<List<ScoreEntry>> top({int limit = 10}) async {
    try {
      await _flush();
      final best = await server.top(limit: limit);
      offline = false;
      return best;
    } catch (_) {
      offline = true;
      return local.top(limit: limit);
    }
  }

  /// Sends what waits in the outbox, oldest first; throws at the first one the server doesn't take,
  /// which stays there with the ones after it.
  Future<void> _flush() => _sending ??= _outbox.inTurn(() async {
        final waiting = await _outbox.read();
        for (final (i, e) in waiting.indexed) {
          try {
            await server.submit(e);
          } catch (_) {
            await _outbox.write(waiting.sublist(i));
            rethrow;
          }
        }
        if (waiting.isNotEmpty) await _outbox.write([]);
      }).whenComplete(() => _sending = null);
}

/// The score server given at build time (`--dart-define=SCORE_SERVER=https://…`); empty for none.
const scoreServer = String.fromEnvironment('SCORE_SERVER');

/// Where this game's scores go: the file on this device, or with a [server] URL that server, backed by
/// the file (and scores_outbox.json for what it hasn't taken yet).
ScoreRepository scoreRepository([String server = scoreServer]) => server.trim().isEmpty
    ? LocalScoreRepository()
    : ServerScoreRepository(HttpScoreRepository(server), LocalScoreRepository(), dataFile('scores_outbox.json'));

/// The name the player gave, kept in player.json beside save.json; null until asked. [file] is for tests.
String? loadPlayerName([File? file]) {
  try {
    final f = file ?? dataFile('player.json');
    if (!f.existsSync()) return null;
    return ScoreEntry.cleanName((jsonDecode(f.readAsStringSync()) as Map<String, dynamic>)['name'] as String);
  } catch (_) {
    return null; // a broken file: ask again
  }
}

void savePlayerName(String name, [File? file]) {
  final f = file ?? dataFile('player.json');
  f.parent.createSync(recursive: true);
  f.writeAsStringSync(jsonEncode({'name': ScoreEntry.cleanName(name)}));
}
