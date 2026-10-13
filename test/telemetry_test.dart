import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';
import 'package:tower_defense/settings.dart';
import 'package:tower_defense/telemetry.dart';

import 'hero_skill_helpers.dart';

// The telemetry (#64, lib/telemetry.dart): the records an adapter writes for a game (the session, each game,
// the events passed on, one summary per wave), the local file's lines and rotation, the HTTP stub's batches
// and retries (off by default, never a real server: a fake poster), and the anonymous install id and the
// "Kirim data permainan" setting in settings.json. Every file in a temp dir.

/// A sink that keeps what it gets (through JSON, as a file or a server would) and counts its flushes.
class _Kept implements TelemetrySink {
  final records = <Map<String, dynamic>>[];
  int flushes = 0;

  @override
  void add(Map<String, Object?> record) => records.add(jsonDecode(jsonEncode(record)) as Map<String, dynamic>);

  @override
  Future<void> flush() async => flushes++;

  /// The records of kind [rec].
  List<Map<String, dynamic>> of(String rec) => [for (final r in records) if (r['rec'] == rec) r];
}

/// An adapter writing to [sink], with a fixed install, session, platform and clock.
TelemetryAdapter adapter(TelemetrySink sink) =>
    TelemetryAdapter([sink], installId: 'install', session: 'session', platform: 'test', now: () => DateTime.utc(2026, 9, 28, 12));

/// Hands [e] to [g]'s listeners, as the game does.
void send(Game g, GameEvent e) {
  for (final l in [...g.listeners]) {
    l(e);
  }
}

/// A new temp folder for one test's files, deleted after it.
Directory tempDir() {
  final d = Directory.systemTemp.createTempSync('td_telemetry');
  addTearDown(() => d.deleteSync(recursive: true));
  return d;
}

void main() {
  test('an adapter writes a session record once and a game record on each attach; the same game again is nothing', () {
    final kept = _Kept(), t = adapter(kept);
    final g = bareGame(), loaded = bareGame()..wave = 4;
    t
      ..attach(g)
      ..attach(g)
      ..attach(loaded);
    expect(kept.records.map((r) => (r['rec'], r['game'])), [('session', 0), ('game', 1), ('game', 2)]);
    expect((kept.of('session').single['platform'], kept.of('session').single['ev']), ('test', eventVersion));
    expect(kept.of('game').map((r) => r['wave']), [0, 4]);
    for (final r in kept.records) {
      expect((r['tv'], r['install'], r['session'], r['at']), (telemetryVersion, 'install', 'session', '2026-09-28T12:00:00.000Z'));
    }
    expect((g.listeners.length, loaded.listeners.length, t.game), (0, 1, loaded)); // only the one attached
    t.detach();
    expect((loaded.listeners.length, t.game), (0, null));
  });

  test('a wave is summed up once when it ends: the army, what came and what fell, gold in and out, loot, casts, time and lives', () {
    final kept = _Kept();
    final g = bareGame()
      ..wave = 2
      ..t = 99
      ..kills = 7;
    adapter(kept).attach(g);
    send(g, Bought(2, 99, type: 'archer', cost: 30)); // the shop before the wave
    send(g, StoreBought(2, 99.2, loot: Relic.grail, cost: 24000)); // the store, between waves
    send(g, StoreSold(2, 99.3, loot: Item.potion, n: 2, gain: 2000));
    send(g, Ascended(2, 99.4, type: 'knight', level: 4, cost: 100000)); // Bangkit 4 in the Toko (#92 part 2)
    send(g, Tempered(2, 99.42, type: 'priest', level: 1, cost: 33000)); // Tempa in the Toko (decisions-log 163)
    send(g, HeroRecalled(2, 99.45, name: 'Budi', type: 'knight', stats: const [HeroStat.hp, HeroStat.defence], fell: 1, cost: 3000)); // Hero Gugur (#92 part 3)
    send(g, ItemUsed(2, 99.5, item: Item.bow, type: 'archer'));
    send(g, RelicTakenOff(2, 99.6, relic: Relic.guard, type: 'knight')); // back into the bag (#91)
    final start = WaveStarted(3, 100,
        army: {'archer': 2, 'knight': 1}, levels: {'archer': 1}, heroes: [('knight', 'cleave')], gold: 470, capacity: 12, lives: 10,
        bag: {'potion': 1}, relics: {});
    send(g, start);
    for (final (type, tier) in [('orc', Tier.normal), ('orc', Tier.normal), ('orc', Tier.elite), ('werebear', Tier.miniBoss)]) {
      send(g, MonsterSpawned(3, 101, type: type, tier: tier));
    }
    send(g, StrongFoe(3, 101, type: 'werebear', tier: Tier.miniBoss));
    send(g, MonsterSpawned(3, 102, type: minion, tier: Tier.normal, raised: true));
    send(g, SkillCast(3, 103, name: 'Sari', type: 'archer', skill: 'Arrow Rain'));
    send(g, HeroSkillCast(3, 104, name: 'Budi', type: 'knight', skill: HeroSkill.cleave));
    send(g, HeroSkillCast(3, 105, name: 'Budi', type: 'knight', skill: HeroSkill.cleave));
    send(g, MonsterSkillCast(3, 105.5, type: 'orc', tier: Tier.highElite, skill: MonsterSkill.warShout));
    send(g, MonsterSkillCast(3, 105.6, type: 'orc', tier: Tier.miniBoss, skill: MonsterSkill.warShout));
    send(g, TroopFell(3, 106, name: 'Sari', type: 'archer', killer: 'orc', killerTier: Tier.elite));
    send(g, TroopFell(3, 107, name: 'Budi', type: 'knight', hero: true)); // nothing struck it
    send(g, Bought(3, 110, cost: 50)); // more capacity mid-wave
    send(g, StoreSold(3, 111, loot: Item.sword, n: 1, gain: 500)); // mid-wave (were the store open then)
    send(g, Marched(3, 130.25));
    g
      ..t = 142.5
      ..gold = 1020
      ..lives = 8
      ..kills = 12
      ..score = 90;
    expect(kept.flushes, 0);
    send(g, WaveEnded(3, 142.5, won: true));
    expect(kept.flushes, 0); // a won wave's record waits for the Towns' roll, in the same tick
    send(g, TownRolled(3, 142.5, town: {'blocked': true}));
    expect(kept.flushes, 1);

    final w = kept.of('wave').single;
    expect((w['wave'], w['end'], w['secs'], w['marched'], w['livesLost'], w['kills'], w['score']), (3, 'won', 42.5, 30.25, 2, 5, 90));
    expect(w['town'], {'blocked': true});
    expect(w['start'], jsonDecode(jsonEncode(start.data)));
    expect(w['spawns'], {
      'orc': {'normal': 2, 'elite': 1},
      'werebear': {'miniBoss': 1},
    });
    expect(w['raised'], {
      minion: {'normal': 1},
    });
    expect([w['fallen'], w['heroesFallen']], [
      {'archer': 1, 'knight': 1},
      1,
    ]);
    expect(w['killers'], {
      'orc': {'elite': 1},
    });
    expect(w['bought'], {'archer': 1, 'capacity': 1});
    expect([w['storeBought'], w['storeSold']], [
      {'grail': 1},
      {'potion': 2, 'sword': 1},
    ]);
    // Earned in battle: 1020 - 470, plus the 50 spent after the start, less the store's 500 after it; spent:
    // the shop's 30 too; the store's all of it; the bonus the win pays.
    expect(w['gold'], {
      'start': 470,
      'end': 1020,
      'earned': 100,
      'spent': 80,
      'storeSpent': 24000,
      'storeEarned': 2500,
      'ascendSpent': 100000,
      'recallSpent': 3000,
      'pusakaSpent': 0,
      'chestSpent': 0, // the boss chest's (draft_test.dart)
      'chestEarned': 0,
      'asahSpent': 0, // Asah's (asah_test.dart)
      'tempaSpent': 33000, // between waves: never in what the wave earned
      'trainSpent': 0, // Train's (train_test.dart)
      'leburSpent': 0, // Lebur's (lebur_test.dart)
      'craftSpent': 0, // the Smithy's (town_craft_test.dart)
      'tavernSpent': 0, // the Tavern's (tavern_test.dart)
      'bonus': Game.waveBonus(3),
    });
    expect([w['dropped'], w['relicsDropped'], w['used'], w['relicsUsed'], w['relicsTakenOff']], [
      {}, // nothing drops on the field (decisions-log 321): kept empty
      {},
      {'bow': 1},
      {},
      {'guard': 1},
    ]);
    expect([w['casts'], w['heroCasts'], w['monsterCasts']], [
      {'Arrow Rain': 1},
      {'cleave': 2},
      {
        'warShout': {'highElite': 1, 'miniBoss': 1},
      },
    ]);

    // Passed on as they happened: the buys, the store's deals, the item and the falls; no troop's name.
    final events = [for (final r in kept.of('event')) r['event'] as Map<String, dynamic>];
    expect(events.map((e) => e['kind']),
        ['bought', 'storeBought', 'storeSold', 'ascended', 'tempa', 'heroRecalled', 'itemUsed', 'relicTakenOff', 'fell', 'fell', 'bought', 'storeSold']);
    expect(events.any((e) => e.containsKey('name')), isFalse);
    expect(events.firstWhere((e) => e['kind'] == 'fell'), {'v': eventVersion, 'kind': 'fell', 'wave': 3, 't': 106, 'type': 'archer', 'hero': false, 'killer': 'orc', 'killerTier': 'elite', 'relics': []});

    // The next wave starts from nothing, and a lost one pays no bonus.
    send(g, WaveStarted(4, 150, army: {'knight': 1}, levels: {}, heroes: [], gold: 1020, capacity: 14, lives: 8, bag: {}, relics: {}));
    g
      ..t = 160
      ..lives = 0;
    send(g, WaveEnded(4, 160, won: false));
    final lost = kept.of('wave').last;
    expect([lost['wave'], lost['end'], lost['secs'], lost['livesLost'], lost['spawns'], lost['fallen'], lost['bought']], [4, 'lost', 10.0, 8, {}, {}, {}]);
    expect(lost['gold'], {'start': 1020, 'end': 1020, 'earned': 0, 'spent': 0, 'storeSpent': 0, 'storeEarned': 0, 'ascendSpent': 0, 'recallSpent': 0, 'pusakaSpent': 0, 'chestSpent': 0, 'chestEarned': 0, 'asahSpent': 0, 'tempaSpent': 0, 'trainSpent': 0, 'leburSpent': 0, 'craftSpent': 0, 'tavernSpent': 0,
        'bonus': 0});
    expect([lost['storeBought'], lost['storeSold']], [{}, {}]);
  });

  test('a wave still on when its game is left (another comes in) is summed up as left; one ended is not again', () {
    final kept = _Kept(), t = adapter(kept);
    final g = bareGame();
    t.attach(g);
    send(g, WaveStarted(1, 0, army: {}, levels: {}, heroes: [], gold: 100, capacity: 6, lives: 10, bag: {}, relics: {}));
    g.t = 12;
    t.attach(bareGame());
    expect(kept.of('wave').map((w) => (w['wave'], w['end'], w['secs'])), [(1, 'left', 12.0)]);
    t.detach();
    expect(kept.of('wave'), hasLength(1));
  });

  test('a real wave: every monster that came is counted by type and rank, the kills and falls add up, and the gold', () {
    final kept = _Kept();
    final g = bareGame(Random(5))
      ..slots = Random(1)
      ..loot = Random(2);
    adapter(kept).attach(g);
    placeNow(g, 'knight_templar', 2, 3);
    placeNow(g, 'archer', 0, 2);
    placeNow(g, 'archer', 0, 4);
    final spent = 100000 - g.gold;
    g.startWave();
    final total = g.waveTotal;
    for (var i = 0; i < 6000 && g.waveActive && !g.over; i++) {
      g.tick(0.05);
    }
    expect((g.waveActive, g.over), (false, false), reason: 'wave 1 is won');
    final w = kept.of('wave').single;
    int sum(Object? m) => (m as Map<String, dynamic>).values.fold(0, (n, v) => n + (v is Map ? sum(v) : v as int));
    expect([w['wave'], w['end'], sum(w['spawns']), w['raised']], [1, 'won', total, {}]);
    expect((w['kills'], sum(w['fallen'])), (g.kills, g.lastFallen.length));
    expect(w['bought'], {'knight_templar': 1, 'archer': 2});
    final gold = w['gold'] as Map<String, dynamic>;
    expect((gold['start'], gold['end'], gold['spent'], gold['bonus']), (100000 - spent, g.gold - Game.waveBonus(1), spent, Game.waveBonus(1)));
    expect(gold['earned'], (gold['end'] as int) - (gold['start'] as int));
    expect(w['secs'], closeTo(g.t, 0.01));
    final text = jsonEncode(kept.records);
    for (final u in g.troops) {
      expect(text.contains('"${u.name}"'), isFalse, reason: 'a troop\'s name: ${u.name}');
    }
  });

  test('the file sink appends a JSON line per record at a flush, none before; one it cannot write loses them quietly', () async {
    final dir = tempDir(), f = File('${dir.path}/deep/telemetry.jsonl');
    final s = FileSink(f)..add({'a': 1});
    expect(f.existsSync(), isFalse);
    await s.flush();
    s
      ..add({'b': 2})
      ..add({'c': 'é'});
    await s.flush();
    expect(f.readAsLinesSync().map(jsonDecode), [
      {'a': 1},
      {'b': 2},
      {'c': 'é'},
    ]);
    File('${dir.path}/plain').writeAsStringSync('');
    final broken = FileSink(File('${dir.path}/plain/telemetry.jsonl'))..add({'a': 1}); // under a file: no folder
    await broken.flush(); // no throw
  });

  test('past maxBytes the file moves to .1 and .1 to .2, the oldest going: the files never pass (keep + 1) x maxBytes', () async {
    final f = File('${tempDir().path}/telemetry.jsonl');
    final s = FileSink(f, maxBytes: 100, keep: 2);
    for (var i = 0; i < 42; i++) {
      s.add({'i': i, 'pad': 'x' * 10}); // 27-28 bytes a line with its newline: 3 a file
      await s.flush();
    }
    expect([for (final x in [f, s.older(1), s.older(2)]) x.lengthSync() <= 100], [true, true, true]);
    expect(s.older(3).existsSync(), isFalse);
    final kept = [
      for (final x in [s.older(2), s.older(1), f]) ...x.readAsLinesSync().map((l) => (jsonDecode(l) as Map)['i'] as int),
    ];
    expect(kept, [for (var i = 42 - kept.length; i < 42; i++) i]); // the newest, in order
    expect(kept.length, 9);
  });

  test('the HTTP sink is off by default and without a server: it takes nothing and never posts', () async {
    var posts = 0;
    Future<bool> post(Uri url, String body) async => ++posts > 0;
    for (final s in [HttpSink('http://127.0.0.1:9/t', post: post), HttpSink('', enabled: true, post: post), HttpSink(' ', enabled: true, post: post)]) {
      s.add({'a': 1});
      await s.flush();
      expect((s.on, s.waiting), (false, 0));
    }
    expect(posts, 0);
    expect((telemetryServer, HttpSink(telemetryServer).on), ('', false)); // no server is built into the tests
  });

  test('turned on, the HTTP sink posts what waits in batches, oldest first, with the version; turned off it drops them', () async {
    final urls = <Uri>[], bodies = <Map<String, dynamic>>[];
    final s = HttpSink('http://telemetry.test/in', enabled: true, batch: 2, post: (url, body) async {
      urls.add(url);
      bodies.add(jsonDecode(body) as Map<String, dynamic>);
      return true;
    });
    for (var i = 0; i < 5; i++) {
      s.add({'i': i});
    }
    expect(s.waiting, 5);
    await s.flush();
    expect(bodies.map((b) => [for (final r in b['records'] as List) r['i']]), [
      [0, 1],
      [2, 3],
      [4],
    ]);
    expect(bodies.every((b) => b['tv'] == telemetryVersion), isTrue);
    expect(urls.toSet(), {Uri.parse('http://telemetry.test/in')});
    expect(s.waiting, 0);
    s
      ..add({'i': 5})
      ..enabled = false;
    expect(s.waiting, 0);
    s.add({'i': 6});
    await s.flush();
    expect((s.waiting, bodies.length), (0, 3));
  });

  test('a batch the server fails (or that throws) waits and goes again after the backoff, doubling up to its cap; at most keepMax wait', () async {
    var now = DateTime.utc(2026, 9, 28), ok = false, posts = 0;
    final s = HttpSink('http://telemetry.test/in',
        enabled: true, batch: 10, keepMax: 3, retry: const Duration(seconds: 5), maxRetry: const Duration(seconds: 12), now: () => now,
        post: (url, body) async {
      posts++;
      if (posts == 2) throw const SocketException('down');
      return ok;
    });
    Future<void> at(int secs) async {
      now = now.add(Duration(seconds: secs));
      await s.flush();
    }

    s.add({'i': 0});
    await s.flush();
    expect((posts, s.waiting), (1, 1));
    await at(4); // 5 s after the failure: not yet
    expect(posts, 1);
    await at(1); // throws; then 10 s
    expect((posts, s.waiting), (2, 1));
    await at(9);
    expect(posts, 2);
    await at(1); // fails; then 20 s, capped at 12
    expect(posts, 3);
    await at(11);
    expect(posts, 3);
    for (var i = 1; i < 5; i++) {
      s.add({'i': i});
    }
    expect(s.waiting, 3); // the oldest dropped
    ok = true;
    await at(1);
    expect((posts, s.waiting), (4, 0));
    s.add({'i': 5});
    await s.flush(); // a success resets the wait
    expect(posts, 5);
  });

  test('the install id is made once, 32 hex digits, and settings.json keeps it; a broken one is none', () {
    final f = File('${tempDir().path}/settings.json');
    final s = Settings();
    final id = installIdOf(s, file: f, rng: Random(1));
    expect(id, matches(RegExp(r'^[0-9a-f]{32}$')));
    expect((s.installId, loadSettings(f).installId), (id, id));
    expect(installIdOf(loadSettings(f), file: f, rng: Random(2)), id); // not made again
    expect(randomId(Random(2)), isNot(id));
    for (final bad in ['"Budi"', '12', '"${'A' * 32}"', 'null']) {
      f.writeAsStringSync('{"installId": $bad}');
      expect(loadSettings(f).installId, isNull, reason: bad);
    }
  });

  test('"Kirim data permainan" is off by default, when missing or broken, and settings.json keeps it on', () {
    final f = File('${tempDir().path}/settings.json');
    expect((Settings().sendTelemetry, loadSettings(f).sendTelemetry), (false, false));
    saveSettings(Settings(sendTelemetry: true), f);
    expect(loadSettings(f).sendTelemetry, isTrue);
    expect(jsonDecode(f.readAsStringSync()), {'music': 100, 'sfx': 100, 'autoStart': false, 'heroCutIns': true, 'foeCutIns': true, 'miniMap': false, 'sendTelemetry': true, 'showFps': false});
    for (final bad in ['"yes"', '1', 'null']) {
      f.writeAsStringSync('{"sendTelemetry": $bad}');
      expect(loadSettings(f).sendTelemetry, isFalse, reason: bad);
    }
  });
}
