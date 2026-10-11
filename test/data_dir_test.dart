import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';
import 'package:tower_defense/save.dart';
import 'package:tower_defense/scores.dart';
import 'package:tower_defense/settings.dart';

import 'flutter_test_config.dart' show ownDataDir;

// Where the tests' files go (decisions-log 144): each test file has the game's folder of its own, a temp dir made by
// flutter_test_config.dart, so test files running at once never share a save or settings.json, and none reaches HOME's.

void main() {
  test('under tests the game writes into a temp dir of this file, never under HOME', () {
    final dir = testDataDir!, app = dataDirFor(Platform.operatingSystem, Platform.environment);
    expect(dir, startsWith('${Directory.systemTemp.path}/td_data_'));
    expect(dir, isNot(startsWith(File(app).parent.path))); // not ~/.local/share (or %APPDATA%)
    expect(dataFile('settings.json').path, '$dir/settings.json');

    expect(LocalScoreRepository().file.path, '$dir/scores.json');
    expect(saveGame(Game()..gold = 321), isTrue);
    expect(saveSettings(Settings(music: 40)), isTrue);
    expect(Directory(dir).listSync().map((f) => f.uri.pathSegments.last).toSet(), containsAll(['save.json', 'settings.json']));
    expect((loadGame()?.gold, loadSettings().music), (321, 40));
  });

  test("two test files never see each other's settings: each starts in a fresh, empty dir", () {
    final mine = testDataDir!;
    saveSettings(Settings(autoStart: true));
    final other = ownDataDir(); // what flutter_test_config.dart makes for the next test file
    addTearDown(() {
      testDataDir = mine;
      other.deleteSync(recursive: true);
    });
    expect(other.path, isNot(mine));
    expect(other.listSync(), isEmpty);
    expect(loadSettings().autoStart, isFalse); // the defaults, not this file's Auto
    saveSettings(Settings(miniMap: true)); // what hud_test's neighbour saved over it in a shared HOME
    testDataDir = mine;
    expect((loadSettings().autoStart, loadSettings().miniMap), (true, false));
  });
}
