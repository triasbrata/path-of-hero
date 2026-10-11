import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/save.dart';

// Flutter runs testExecutable around the main() of every test file under test/ (decisions-log 144, docs/testing.md
// "Where the tests' files go").

/// Gives this test file the game's folder of its own ([ownDataDir]), deleted after its last test. `flutter test`
/// runs several test files at once, and when they shared the job's HOME one file's settings.json overwrote
/// another's (hud_test read its Auto toggle back off).
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  final dir = ownDataDir();
  tearDownAll(() => dir.deleteSync(recursive: true));
  await testMain();
}

/// A fresh, empty temp dir, made the game's folder ([testDataDir]): save.json, settings.json, the scores and the
/// telemetry all go there.
Directory ownDataDir() {
  final dir = Directory.systemTemp.createTempSync('td_data_');
  testDataDir = dir.path;
  return dir;
}
