import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';
import 'package:tower_defense/save.dart';
import 'package:tower_defense/settings.dart';

// Where the game's files go on each platform, and writes that fail without a crash (decisions-log 133); a save loaded
// for the board fights with the board's stats (decisions-log 317).

String _stats(Stats s) => 'hp ${s.hp} mp ${s.mp} dmg ${s.dmg} def ${s.def} range ${s.range} speed ${s.speed} rate ${s.rate} '
    'regen ${s.regen} mpRegen ${s.mpRegen} splash ${s.splash} reachCap ${s.reachCap}';

void main() {
  test('the game folder: desktop as before, a phone in its own files dir', () {
    expect(dataDirFor('macos', {'HOME': '/Users/p'}), '/Users/p/.local/share/tower_defense');
    expect(dataDirFor('linux', {'HOME': '/home/p'}), '/home/p/.local/share/tower_defense');
    expect(dataDirFor('windows', {'APPDATA': r'C:\Users\p\AppData\Roaming', 'HOME': '/x'}),
        r'C:\Users\p\AppData\Roaming/tower_defense');
    const files = '/data/user/0/cloud.brata.poh/files';
    expect(dataDirFor('android', const {}, appDir: files), '$files/tower_defense');
    expect(dataDirFor('ios', {'HOME': '/var/app'}, appDir: '/var/app/Library/Application Support'),
        '/var/app/Library/Application Support/tower_defense');
    // Android sets no HOME: without its files dir the folder is under /, where writes fail.
    expect(dataDirFor('android', const {}), '/.local/share/tower_defense');
  });

  test('initDataDir: Android asks for its files dir, desktop never does, a failed lookup leaves the old paths',
      () async {
    final own = testDataDir; // this file's temp dir (flutter_test_config.dart): off here, where only paths are read
    testDataDir = null;
    addTearDown(() => testDataDir = own);
    addTearDown(() => initDataDir(os: Platform.operatingSystem));
    final desktop = dataFile('save.json').path;
    var asked = 0;
    Future<Directory> files() async {
      asked++;
      return Directory('/data/user/0/cloud.brata.poh/files');
    }

    await initDataDir(os: 'android', lookup: files);
    expect((asked, dataFile('save.json').path), (1, '/data/user/0/cloud.brata.poh/files/tower_defense/save.json'));
    await initDataDir(os: 'macos', lookup: files);
    expect((asked, dataFile('save.json').path), (1, desktop));
    await initDataDir(os: 'android', lookup: () async => throw StateError('no plugin'));
    expect(dataFile('save.json').path, desktop); // here HOME's; on a phone /, where saving fails quietly
  });

  test('saveGame and saveSettings fail quietly where nothing can be written, and the save before stays', () {
    final dir = Directory.systemTemp.createTempSync('td_save');
    addTearDown(() => dir.deleteSync(recursive: true));
    final blocker = File('${dir.path}/blocker')..writeAsStringSync('a file, not a folder');
    expect(saveGame(Game(), File('${blocker.path}/save.json')), isFalse);
    expect(saveSettings(Settings(), File('${blocker.path}/settings.json')), isFalse);

    final save = File('${dir.path}/save.json');
    expect(saveGame(Game()..gold = 123, save), isTrue);
    expect(File('${save.path}.tmp').existsSync(), isFalse, reason: 'written as save.json.tmp, then renamed');
    final before = save.readAsStringSync();
    // A folder nothing can be written in (the tmp file can't be made): no save, and the one before stays whole.
    if (Process.runSync('chmod', ['555', dir.path]).exitCode != 0) return; // no chmod: the first half stands
    addTearDown(() => Process.runSync('chmod', ['755', dir.path]));
    expect(saveGame(Game()..gold = 456, save), isFalse);
    expect(save.readAsStringSync(), before);
  });

  test('a save that can\'t be read is logged and kept aside as save.bad-<time>.json; the next save starts afresh', () {
    final save = dataFile('save.json')..createSync(recursive: true);
    String? said;
    final print = debugPrint;
    debugPrint = (m, {wrapWidth}) => said = m;
    addTearDown(() => debugPrint = print);
    List<File> bad() => [for (final f in save.parent.listSync()) if (f is File && f.uri.pathSegments.last.startsWith('save.bad-')) f];
    // A cut file, JSON that is no save, and a save this build fails on (a troop without its type).
    final broken = ['{"v": 3, "wave": ', '[1, 2]', jsonEncode({...Game().toJson(), 'troops': [<String, Object>{'x': 1}]})];
    for (final text in broken) {
      save.writeAsStringSync(text);
      expect(loadGame(), isNull);
      expect(save.existsSync(), isFalse);
    }
    expect({for (final f in bad()) f.readAsStringSync()}, broken.toSet(), reason: 'each one kept, none written over');
    expect(said, startsWith('The unreadable save is kept as '));
    expect(saveGame(Game()..gold = 321), isTrue);
    expect(loadGame()?.gold, 321);
    expect(bad().length, broken.length);

    // The name: the time, and a number while it is taken.
    final at = DateTime(2026, 10, 12, 9, 5, 7);
    final a = keepAside(File(save.path)..writeAsStringSync('a'), at), b = keepAside(File(save.path)..writeAsStringSync('b'), at);
    expect([a?.uri.pathSegments.last, b?.uri.pathSegments.last], ['save.bad-20261012-090507.json', 'save.bad-20261012-090507-2.json']);
    expect([a?.readAsStringSync(), b?.readAsStringSync()], ['a', 'b']);
  });

  // decisions-log 317: Game.fromJson fits the troops under a plain Game()'s rules (the Towns off); "Continue" turns the
  // board's on (boardRules), which fits them again, each at its saved HP.
  test('a save loaded for the board fights with the board\'s stats, at its saved HP', () {
    // The w89 save, two of its templars' swords enhanced to +3 (enhance.dart): pluses only the board's rules count.
    final j = jsonDecode(File('test/fixtures/save-20261002-2222-w89-sellbug.json').readAsStringSync()) as Map<String, dynamic>
      ..['upgradePlus'] = {
        'knight_templar': [
          {'item': 'sword', 'plus': 3, 'n': 2},
        ],
      };
    final g = Game.fromJson(j, Random(1), Random(2), Random(3));
    final types = {for (final u in g.troops) u.type};
    final off = {for (final t in types) t: _stats(g.statsOf(t))};
    g.boardRules();
    // The two rules part on this save, or the test would prove nothing.
    expect(types.where((t) => _stats(g.statsOf(t)) != off[t]), isNotEmpty);
    final saved = [for (final t in j['troops'] as List) (t['hp'] as num).toDouble()];
    expect(g.troops.length, saved.length);
    for (final (i, u) in g.troops.indexed) {
      final aura = g.troops.any((o) => o != u && o.alive && o.hero) ? g.auraNow : 1.0;
      final board = u.hero ? g.statsOf(u.type).heroic(u.heroStats.toSet(), g.heroBoostNow, aura) : g.statsOf(u.type).boosted(aura);
      expect(_stats(u.stats), _stats(board), reason: '${u.type} #$i');
      expect(u.maxHp, board.hp);
      expect(u.hp, min(saved[i], board.hp.toDouble()), reason: '${u.type} #$i: its saved HP');
    }
  });

  test('a new game on the board: boardRules changes no troop', () {
    final plain = Game(Random(1), Random(2)), board = Game(Random(1), Random(2)).boardRules();
    expect([for (final u in board.troops) (_stats(u.stats), u.hp, u.mp)], [for (final u in plain.troops) (_stats(u.stats), u.hp, u.mp)]);
  });
}
