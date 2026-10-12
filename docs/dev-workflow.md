# Dev workflow

Purpose: how to build and run the game, its identity on each platform, and the traps that break it. The parts about
the author's own machine, the official builds and their signing stay in the private repository.

## What you need

- **Flutter 3.47.5** (stable; Dart 3.13), the version the official builds use, and Python 3 for the tools in `tool/`
  (the standard library only). Before the first build: `python3 tool/gen_placeholders.py` (README.md); with the
  team's key, `python3 tool/asset_vault.py unpack --only game` and `install-hooks` instead (assets.md "The asset
  vault").
- **macOS (`macos/`):** Xcode; deployment target macOS 12.0. flutter_soloud builds through Swift Package Manager and
  its native-assets hook: there is no Podfile, and CocoaPods isn't used. The app runs in the App Sandbox (debug and
  release), so `$HOME` in `lib/save.dart` is the app's container.
- **Android, Windows, Linux:** the Android SDK; Visual Studio with C++; GTK 3, clang, CMake and Ninja.
- `analysis_options.yaml` excludes the platform folders. flutter_soloud's build hook downloads the prebuilt Xiph
  libraries of the release pubspec.yaml pins (`prebuild_tag`) once per platform, so a first build needs the network.

## Run with hot reload

`flutter run -d macos` (or `windows`, `linux`, an Android device): `r` hot reload, `R` hot restart, `q` quit. A
change to `lib/game.dart` needs a hot restart (`R`), and so do new images (Traps, below).

## App identity (decisions-log 133)

| Platform | Id | What the player sees | Where the game's files go (`dataDirFor`, lib/save.dart) |
|---|---|---|---|
| Android | `applicationId` and `namespace` `cloud.brata.poh` (android/app/build.gradle.kts); `MainActivity` in `src/main/kotlin/cloud/brata/poh/` | label "Path of Hero" (AndroidManifest.xml) | the app's files dir, `/data/user/0/cloud.brata.poh/files/tower_defense/` |
| macOS | `PRODUCT_BUNDLE_IDENTIFIER = cloud.brata.poh`, the tests `cloud.brata.poh.RunnerTests` | `CFBundleName`/`CFBundleDisplayName` "Path of Hero": the menu bar, the window and the app menu; the release's folder renamed to `Path of Hero.app` when packed (itch-page.md) | `~/Library/Containers/cloud.brata.poh/Data/.local/share/tower_defense/` |
| Linux | `APPLICATION_ID "cloud.brata.poh"` (linux/CMakeLists.txt) | the window title | `~/.local/share/tower_defense/` |
| Windows | `CompanyName "brata.cloud"` (windows/runner/Runner.rc) | `ProductName` / `FileDescription` "Path of Hero", the window title | `%APPDATA%\tower_defense\` |

- **The version** is pubspec.yaml's `version:` (`0.1.0+1` at first; SemVer, `1.0.0` at full release). Android's
  `versionName`/`versionCode` and macOS's `CFBundleShortVersionString`/`CFBundleVersion` come from it. The build number
  after `+` must rise with every release, or Android refuses the update.
- **Never change an id once a build is out.** Android installs an update only over the same application id (and the
  same signing key, "Android release signing"); on macOS the sandbox container, and with it every save, follows the
  bundle id.
- **Internal names keep `tower_defense`:**
  - the binaries: macOS's `PRODUCT_NAME` (the build is `tower_defense.app`, its executable and process
    `tower_defense`), Windows's and Linux's `BINARY_NAME` (`tower_defense.exe`, `tower_defense`). The agents check
    that the game runs with `pgrep -x tower_defense` (sdlc.md), and the Windows scripts stop `tower_defense.exe`.
    A `PRODUCT_NAME` with spaces would also need quoting in every script, the Xcode scheme's `BuildableName` and the
    tests' `TEST_HOST`;
  - the Dart package (`package:tower_defense/`), the save folder `tower_defense`, the repo and the project folder.
- **Phones set no `HOME`.** `main()` awaits `initDataDir()` first: on Android and iOS it asks path_provider for
  `getApplicationSupportDirectory()` (Android's `Context.getFilesDir()`, private to the app and deleted with it).
  path_provider is a direct dependency, though it was already in pubspec.lock through flutter_soloud, so no download.
  Desktop never asks, and its paths are unchanged.
- **Writes don't crash.** `saveGame`, `saveSettings`, `clearSave` and the telemetry's file catch I/O errors and log
  them (`debugPrint`); `saveGame`/`saveSettings` return false. A failed score write shows "Score not saved".
- **A save is never cut nor silently lost** (decisions-log 317). `saveGame` writes `save.json.tmp` and renames it over
  `save.json` in one step (the scoreboard's `scores.json` the same way), so a game killed mid-write, as a phone may end
  one in the background right after its save, leaves the save before whole. A `save.json` that can't be read (a cut
  or broken file, JSON that is no save, or a save this build fails on) is logged ("Save not loaded …" with the error)
  and renamed to `save.bad-<yyyyMMdd-HHmmss>.json` beside it (`-2`, `-3` … added while the name is taken;
  `keepAside`, lib/save.dart); the welcome then offers only a new game, as for no save, and the new game's saves
  start a new `save.json`, so the bad one stays for a look. Only a readable save from before `Game.saveLoadsFrom` is
  deleted (by the launch, decisions-log 237). If the rename itself fails, that is logged too and the next save writes
  over the file.
- **To the background** (the window hidden or minimized, or the app in the background, where Android may end it
  without a word): between waves the game is saved, so what was bought or put on since the last won wave stays.
  Mid-wave it isn't, because a save holds no wave in progress (loading it would skip that wave), so the last won
  wave's save stands. Nor on the welcome screen, where at launch a fresh game waits behind it. The telemetry's
  buffered records are written then too. On the desktop hiding pauses nothing (#93, ui-hud.md "The window"): a timer
  runs the game while Flutter draws no frames. On Android and iOS going to the background pauses the game, and it
  stays paused when the player comes back (decisions-log 146, ui-hud.md "A phone in the background pauses"; the
  switch `pauseInBackgroundOnMobile` in main.dart), and its music and effects hold until the player is back
  (decisions-log 147, ui-hud.md "A phone in the background is silent"; `muteInBackgroundOnMobile`).
- **A phone's game is full screen** (decisions-log 215, ui-hud.md "Layouts", "A touch device"). On Android and iOS
  `main()`, and every return to the front, ask for `SystemUiMode.immersiveSticky` (`_fullScreenOnPhone`): the status
  bar and the navigation or gesture bar hide, and a swipe in from an edge shows them over the game for a moment. Android
  15 and later draw an app edge to edge whatever it asks, so without this the bars lay over the HUD. Flutter's Android
  embedder asks with the old `setSystemUiVisibility` flags (`FULLSCREEN | HIDE_NAVIGATION | IMMERSIVE_STICKY`), which
  Android still turns into hiding the bars. The HUD also keeps inside the screen's safe insets (`MediaQuery`'s
  `viewPadding`, read from the view: a display cutout, the bars while they show) and, on a tablet, at the desk's share
  of the height. The desktop's window and HUD are unchanged.

### One copy of the game (macOS)

The game runs one copy at a time: `SingleInstance` in `macos/Runner/AppDelegate.swift` takes an exclusive `flock` on
`instance.lock` in the app's Application Support folder before the window, the engine or the save, and a later copy
quits at once (exit 0), asking the first to come to the front. Two copies would load and write the same save. An
XCTest host skips the guard.

## Tests

How to write and run them: testing.md. `flutter test -x art` and `flutter analyze` before every change.

## Traps

- **New images need a hot restart.** Images are loaded once, in `TdGame.onLoad`. After adding
  anything to that list (or new files under `assets/`), `touch lib/game.dart` to force a restart.
  Otherwise the HUD stops drawing at the first missing image
  (`image "x.png" does not exist in the cache`). This has already broken the book HUD twice.
  - The same goes for images `onLoad` builds in memory, such as the book's `book_<type>_idle`: a plain
    reload of `main.dart` spams `book_soldier_idle` "not in the cache" until `touch lib/game.dart`.
- **Never delete or rename files under `assets/` while the session runs.** Flutter's copy fails and the
  session dies.
- **A new field in `game.dart` is null on live objects after a hot reload.** That's why game.dart
  changes restart.
- **Dart:**
  - Never mix a record destructuring with another variable in one declaration
    (`final (a, b) = x, y = z;` does not compile); split it into two lines.
  - Flame exports its own `Timer`, so use `import 'dart:async' as async;`.
  - `flutter/material.dart` is imported with `hide PointerMoveEvent`.
- **The window title is `CFBundleDisplayName` in `macos/Runner/Info.plist`** ("Path of Hero").
  FlutterAppDelegate overwrites a title set in Swift, and puts the same name into the app menu's
  "About / Hide / Quit APP_NAME" items. The bold app name in the menu bar is `CFBundleName`, also
  "Path of Hero", written in Info.plist instead of `$(PRODUCT_NAME)`. Info.plist changes need a full
  app restart, not a hot reload.
- **The game is called "Path of Hero" in what the player sees** (decisions-log 37): the welcome title, the
  macOS window and menu, the Windows/Linux window titles and the Windows file details, the Android label,
  the web page's title and manifest. Since decisions-log 133 the ids are `cloud.brata.poh` ("App identity"); the
  binaries keep `tower_defense`.
- **Changing the bundle id moves the sandbox container**, so the existing save is no longer found ("The save's
  move to the new container").

## Release builds

`flutter build macos` (or `apk`, `windows`, `linux`) builds a release of your own, for your own use (LICENSE §2).
Android: without a signing config (`android/app/build.gradle.kts` reads the `key.properties` that
`ANDROID_KEY_PROPERTIES` names, else `android/key.properties`, git-ignored) a release build is signed with the debug
key, and Gradle warns. The official builds
on itch.io, their signing and their checks are the author's.
