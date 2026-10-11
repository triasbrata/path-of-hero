import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// The app's identity in the platform folders (decisions-log 133): the id cloud.brata.poh (Android, Linux, macOS),
// "Path of Hero" for the player, the version from pubspec. An id must never change once a build is out:
// Android installs no update over another id, and on macOS the sandbox container (the save) follows it.

String read(String path) => File(path).readAsStringSync();

void main() {
  test('Android: application id and namespace cloud.brata.poh, MainActivity in that package, the version from pubspec',
      () {
    final gradle = read('android/app/build.gradle.kts');
    expect(gradle, contains('namespace = "cloud.brata.poh"'));
    expect(gradle, contains('applicationId = "cloud.brata.poh"'));
    expect(gradle, contains('versionCode = flutter.versionCode'));
    expect(gradle, contains('versionName = flutter.versionName'));
    // The release signing (decisions-log 132) stays.
    expect(gradle, contains('signingConfigs.getByName(if (hasReleaseKey) "release" else "debug")'));
    expect(read('android/app/src/main/kotlin/cloud/brata/poh/MainActivity.kt'), startsWith('package cloud.brata.poh\n'));
    expect(Directory('android/app/src/main/kotlin/com').existsSync(), isFalse);
    expect(read('android/app/src/main/AndroidManifest.xml'), contains('android:label="Path of Hero"'));
    expect(RegExp(r'^version: \d+\.\d+\.\d+\+\d+$', multiLine: true).hasMatch(read('pubspec.yaml')), isTrue);
  });

  test('macOS: bundle id cloud.brata.poh (and its tests), the name Path of Hero, the executable still tower_defense', () {
    final info = read('macos/Runner/Configs/AppInfo.xcconfig'), project = read('macos/Runner.xcodeproj/project.pbxproj');
    expect(info, contains('PRODUCT_BUNDLE_IDENTIFIER = cloud.brata.poh\n'));
    // The process keeps its name (`pgrep -x tower_defense`, sdlc.md); the release's folder is renamed when packed.
    expect(info, contains('PRODUCT_NAME = tower_defense\n'));
    expect('cloud.brata.poh.RunnerTests;'.allMatches(project).length, 3);
    final plist = read('macos/Runner/Info.plist');
    for (final key in ['CFBundleName', 'CFBundleDisplayName']) {
      expect(plist, contains('<key>$key</key>\n\t<string>Path of Hero</string>'), reason: key);
    }
  });

  test('Linux and Windows: the same id and company, the name Path of Hero', () {
    expect(read('linux/CMakeLists.txt'), contains('set(APPLICATION_ID "cloud.brata.poh")'));
    final rc = read('windows/runner/Runner.rc');
    for (final (key, value) in [('CompanyName', 'brata.cloud'), ('ProductName', 'Path of Hero'), ('FileDescription', 'Path of Hero')]) {
      expect(rc, contains('VALUE "$key", "$value" "\\0"'), reason: key);
    }
  });

  test('no Flutter template id is left in the platform folders', () {
    for (final dir in ['android', 'linux', 'macos', 'windows', 'web']) {
      for (final f in Directory(dir).listSync(recursive: true).whereType<File>()) {
        if (f.path.contains('/ephemeral/') || f.path.contains('/build/') || f.path.contains('/.gradle/')) continue;
        final String text;
        try {
          text = f.readAsStringSync();
        } on FileSystemException {
          continue; // a binary (an icon)
        }
        expect(text, isNot(contains('com.example')), reason: f.path);
      }
    }
  });
}
