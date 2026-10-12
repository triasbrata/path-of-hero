// A Pusaka refactor's identity check (catalog step 0a, Ukir's U1: every per-star number read through [pusakaAt]): the
// owner's w89 save (the fixture) gives byte-identical stats ([Game.statsOf], [Pusaka.fieldStats]), Pusaka texts (the
// gist, the effect lines, the tooltips, the Tas previews) and fights on a base and on a branch. As saved, and with every
// Pusaka bound at every star (two sets: the five epik; the four Langka and Dragon Crown), each also fought for 45 s of
// wave 90 with seeded dice; then a seeded run of waves 90 and 91 with the telemetry listening (as saved and each set at
// ★2), every record and their hash (catalog step 0b, the Pusaka engine). It prints how long the 45 s fights take (the
// hot path's cost; not compared). A probe, not part of the suite (no `_test.dart`): a byte golden of a fight would
// break on every balance change. It plays the game players play: the Towns, the forge and the Tavern (every game has
// them, decisions-log 296, 321; the probe's TOWNS define and its Towns-off dump went with the Towns-off rules; on a base
// from before decisions-log 321 the same dump is its default run, before 296 with `--dart-define=FORGE=true`). The
// troops' skills wind up as on the board (decisions-log 299); `--dart-define=WINDS=false` gives the dump from before the
// wind-ups.
//
// Run it on the base with `--dart-define=OUT=<file>` (it writes the dump there), then on the branch with
// `--dart-define=OUT=<file2> --dart-define=GOLDEN=<file>`: it fails at the first line that differs. Queue
// `["test", "test/probe_pusaka_w89_identity.dart", "--dart-define=OUT=..."]` with the worktree (or a `git archive`
// mirror of the base) as `dir`. It never touches the real save (flutter_test_config.dart's temp dir).
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';
import 'package:tower_defense/telemetry.dart';

const _save = 'test/fixtures/save-20261002-2222-w89-sellbug.json';

const _out = String.fromEnvironment('OUT', defaultValue: 'build/pusaka_w89_identity.txt'), _golden = String.fromEnvironment('GOLDEN');

/// Whether the troops' skills wind up as on the board ([Game.skillWinds], decisions-log 299), unless
/// `--dart-define=WINDS=false`, which gives the dump from before them.
const _winds = bool.fromEnvironment('WINDS', defaultValue: true);

/// The w89 save with its dice seeded ([seed]), as the probes load it, the Towns' dice too.
Game _load([int seed = 89]) =>
    Game.fromJson(jsonDecode(File(_save).readAsStringSync()) as Map<String, dynamic>, Random(seed), Random(seed + 100))
      ..seedDice(seed) // every die at the probes' offsets, the Shadows' too (decisions-log 319)
      ..skillWinds = _winds;

/// The w89 save's five types, in its saved roster's order (decisions-log 141's `runTypes`, no longer read since 201):
/// the previews run over them in the same order on a base from before it and after.
const _types = ['archer', 'priest', 'armored_axeman', 'wizard', 'knight_templar'];

/// Every Pusaka on a type, bound to the w89 roster's five types, in two sets (a type holds one).
const _sets = <String, Map<Relic, String>>{
  'epik': {
    Relic.dragonHeart: 'knight_templar',
    Relic.dawnStar: 'priest',
    Relic.godThunder: 'wizard',
    Relic.grail: 'armored_axeman',
    Relic.voidEye: 'archer',
  },
  'langka+crown': {
    Relic.dragonCrown: 'knight_templar',
    Relic.ironBanner: 'armored_axeman',
    Relic.bloodFang: 'archer',
    Relic.warDrum: 'wizard',
    Relic.mourningBell: 'priest',
  },
};

String _stats(Stats s) => 'hp ${s.hp} cost ${s.cost} mp ${s.mp} heals ${s.heals} dark ${s.dark} speed ${s.speed} dmg ${s.dmg} '
    'range ${s.range} rate ${s.rate} shotSpeed ${s.shotSpeed} splash ${s.splash} regen ${s.regen} def ${s.def} mpRegen ${s.mpRegen}';

/// What the book shows of the Pusaka on [g] now: each type's stats and HP tooltip, each Pusaka's tooltip, effect lines
/// at every star, gist at every star and its preview on every roster type.
void _book(StringBuffer out, Game g) {
  for (final type in troopTypes.keys) {
    out
      ..writeln('statsOf $type: ${_stats(g.statsOf(type))}')
      ..writeln('fieldStats $type: ${_stats(g.fieldStats(type))}')
      ..writeln('hpInfo $type: ${g.hpInfo(type)}');
  }
  for (final r in Relic.values) {
    if (!r.pusaka && !droppedRelics.contains(r)) continue; // the Smithy's seven are new (decisions-log 227): none on a base before them
    out.writeln('relicInfo ${r.name}: ${g.relicInfo(r)}');
    for (final s in [1, 2, 3]) {
      out.writeln('relicEffect ${r.name} ★$s: ${g.relicEffect(r, stars: s)}');
    }
    if (!r.pusaka) continue;
    for (final s in [0, 1, 2, 3, 4]) {
      out.writeln('pusakaGist ${r.name} ★$s: ${pusakaGist(r, s)}');
    }
    out.writeln('pusakaTotals ${r.name}: ${g.pusakaTotals(r)}');
    for (final type in _types) {
      final p = g.pusakaPreview(r, type);
      out.writeln('pusakaPreview ${r.name} $type: why ${p.why} ${p.action.name} price ${p.price} alive ${p.alive} '
          'stats ${[for (final (k, a, b) in p.stats) '${k.name} $a>$b']} blows ${p.blows} boss ${p.bossWave}');
    }
  }
}

/// The fight: [g] settles 10 s, then fights wave 90 for 45 s, every 15 s its state and the Pusaka's tallies.
void _fight(StringBuffer out, Game g) {
  const dt = 1 / 30;
  void step(int n) {
    for (var i = 0; i < n; i++) {
      g.viewW = 341;
      g.tick(dt);
    }
  }

  String sum(Iterable<Unit> us) => us.fold(0.0, (a, u) => a + u.hp).toString();
  step(300);
  g.startWave();
  for (var k = 1; k <= 3; k++) {
    step(450);
    final troops = g.troops.where((u) => u.alive), foes = g.enemies.where((u) => u.alive);
    out
      ..writeln('fight +${15 * k}s: t ${g.t} wave ${g.wave} active ${g.waveActive} over ${g.over} gold ${g.gold} kills ${g.kills} '
          'score ${g.score} fallen ${g.fallen.length}')
      ..writeln('  troops ${troops.length} hp ${sum(troops)} foes ${foes.length} hp ${sum(foes)}')
      ..writeln('  tallies ${[for (final MapEntry(key: r, value: v) in g.pusakaWorth.entries) '${r.name} ${v.uses} ${v.worth}']}');
  }
}

/// A sink that keeps the telemetry's records as their JSON lines, their version labels masked ([_unversioned]).
class _Lines implements TelemetrySink {
  final lines = <String>[];

  @override
  void add(Map<String, Object?> record) => lines.add(_unversioned(jsonEncode(record)));

  @override
  Future<void> flush() async {}
}

/// [line] with the records' version labels masked (`"tv"`, `"ev"` and the events' `"v"` → `_`): the identity compares
/// what the game did, and a version bump (8: the Bayangan and Ukir, decisions-log 180 and 183) changes only the label.
/// The suite's tests pin the versions themselves.
String _unversioned(String line) => line.replaceAllMapped(RegExp(r'"(tv|ev|v)":\d+'), (m) => '"${m[1]}":_');

/// FNV-1a, 64 bit, over [s]'s UTF-16 code units: the telemetry's hash (no package for a digest).
String _fnv(String s) {
  var h = 0xcbf29ce484222325;
  for (final c in s.codeUnits) {
    h = (h ^ c) * 0x100000001b3;
  }
  String half(int v) => (v & 0xffffffff).toRadixString(16).padLeft(8, '0');
  return '${half(h >> 32)}${half(h)}';
}

/// A seeded run with the telemetry listening (a fixed clock, install and session): [g] settles 10 s, then fights
/// wave 90 to its end (at most 240 s), takes the boss chest's first card (a Pusaka bound or starred mid-run), and
/// fights wave 91 the same. Every record (the last wave's summed up as it stands), and their hash.
void _telemetry(StringBuffer out, Game g) {
  const dt = 1 / 30;
  final sink = _Lines();
  final adapter = TelemetryAdapter([sink], installId: 'install', session: 'session', platform: 'probe', now: () => DateTime.utc(2026, 10, 3))
    ..attach(g);
  for (var w = 0; w < 2 && !g.over; w++) {
    while (g.chest != null && g.takeCard(0)) {}
    for (var i = 0; i < 300; i++) {
      g.viewW = 341;
      g.tick(dt);
    }
    g.startWave();
    for (var i = 0; i < 30 * 240 && g.waveActive && !g.over; i++) {
      g.viewW = 341;
      g.tick(dt);
    }
  }
  adapter.detach();
  final text = sink.lines.join('\n');
  out
    ..writeln('telemetry: ${sink.lines.length} records, hash ${_fnv(text)}, wave ${g.wave} over ${g.over}')
    ..writeln(text);
}

/// The w89 save with [set] bound at [stars] (or as saved).
Game _variant([Map<Relic, String>? set, int stars = 1]) {
  final g = _load();
  for (final MapEntry(key: r, value: type) in (set ?? const <Relic, String>{}).entries) {
    g.givePusaka(r, type: type, stars: stars);
  }
  return g;
}

/// How long the 45 s fights of the dump take ([_fight]: as saved and every set at every star), the best of [runs]:
/// the hot path's cost (`_hurt` on every blow), reported, not compared.
int _fightMs([int runs = 3]) {
  var best = 1 << 30;
  for (var i = 0; i < runs; i++) {
    final watch = Stopwatch()..start();
    _fight(StringBuffer(), _variant());
    for (final set in _sets.values) {
      for (final stars in [1, 2, 3]) {
        _fight(StringBuffer(), _variant(set, stars));
      }
    }
    best = min(best, watch.elapsedMilliseconds);
  }
  return best;
}

String _dump() {
  final out = StringBuffer();
  out.writeln('== w89 as saved');
  _book(out, _load());
  _fight(out, _load());
  for (final MapEntry(key: name, value: set) in _sets.entries) {
    for (final stars in [1, 2, 3]) {
      out.writeln('== $name ★$stars');
      _book(out, _variant(set, stars));
      _fight(out, _variant(set, stars));
    }
  }
  out.writeln('== telemetry, as saved');
  _telemetry(out, _variant());
  for (final MapEntry(key: name, value: set) in _sets.entries) {
    out.writeln('== telemetry, $name ★2');
    _telemetry(out, _variant(set, 2));
  }
  return '$out';
}

void main() {
  test('the w89 save: the Pusaka stats, texts, tooltips, previews and fights, byte for byte against GOLDEN', () {
    final dump = _dump();
    File(_out)
      ..createSync(recursive: true)
      ..writeAsStringSync(dump);
    // ignore: avoid_print
    print('wrote $_out: ${dump.length} chars, ${'\n'.allMatches(dump).length} lines');
    // ignore: avoid_print
    print('fights: ${_fightMs()} ms (the 7 fights of 45 s, best of 3)');
    for (final l in dump.split('\n').where((l) => l.startsWith('telemetry:'))) {
      // ignore: avoid_print
      print(l);
    }
    if (_golden.isEmpty) return;
    final want = File(_golden).readAsStringSync();
    if (dump == want) {
      // ignore: avoid_print
      print('SAME as $_golden');
      return;
    }
    final a = want.split('\n'), b = dump.split('\n');
    final i = Iterable.generate(min(a.length, b.length)).firstWhere((i) => a[i] != b[i], orElse: () => min(a.length, b.length));
    fail('DIFFERS from $_golden at line ${i + 1}:\n  golden: ${i < a.length ? a[i] : '(end)'}\n  now:    ${i < b.length ? b[i] : '(end)'}');
  });
}
