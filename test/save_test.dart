import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';
import 'package:tower_defense/save.dart';
import 'package:tower_defense/settings.dart';

// Where the game's files go on each platform, and writes that fail without a crash (decisions-log 133).

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
    final before = save.readAsStringSync();
    if (Process.runSync('chmod', ['444', save.path]).exitCode != 0) return; // no chmod: the first half stands
    expect(saveGame(Game()..gold = 456, save), isFalse);
    expect(save.readAsStringSync(), before);
  });
}
