#!/usr/bin/env bash
# Tests scripts/release-build.sh and .github/workflows/release.yml without Flutter or the network
# (docs/testing.md "scripts/test-release-build.sh", decisions-log 145):
#
#   bash scripts/test-release-build.sh
#
# - On this repo it runs only --dry-run and check, which run no flutter and write nothing; stubs on the PATH record
#   any tool that runs anyway.
# - The checks that fail, and the real build path (staging, the signer, the bundled assets, the Xiph prebuilds'
#   record, 16 KB pages), run in a throwaway copy (a pubspec, the notices, .itch.toml, a few assets, a package config
#   pointing at a fake flutter_soloud) with flutter, lipo, codesign, apksigner and zipalign stubbed. ditto, unzip,
#   plutil and python3 are the real ones (macOS).
# - .itch.toml: its launch actions against the names the script and the workflow stage.
# - It never reads a key or password file: ANDROID_KEY_PROPERTIES points at empty files of its own.
set -euo pipefail

repo=$(cd "$(dirname "$0")/.." && pwd)
script=$repo/scripts/release-build.sh
workflow=$repo/.github/workflows/release.yml
tmp=$(mktemp -d "${TMPDIR:-/tmp}/test-release-build.XXXXXX")
trap 'rm -rf "$tmp"' EXIT

passed=0 failed=0
pass() {
  passed=$((passed + 1))
  echo "ok   $1"
}
fail() {
  failed=$((failed + 1))
  echo "FAIL $1" >&2
  [ -z "${2:-}" ] || printf '%s\n' "$2" | sed 's/^/     | /' >&2
}

# --- Stubs: each records its call in $STUB_CALLS ---------------------------------------------------------------

stubs=$tmp/stubs
mkdir -p "$stubs"
export STUB_CALLS=$tmp/calls
for tool in ditto lipo codesign apksigner zipalign butler; do
  printf '#!/bin/sh\necho "%s $*" >> "$STUB_CALLS"\n' "$tool" > "$stubs/$tool"
done
# flutter: --version, and `build macos|apk`, which write what the real build would (in the cwd, the copy's root).
cat > "$stubs/flutter" <<'EOF'
#!/bin/sh
echo "flutter $*" >> "$STUB_CALLS"
case "$1 $2" in
  "--version --machine")
    printf '{\n  "frameworkVersion": "%s",\n  "channel": "stable"\n}\n' "${STUB_FLUTTER_VERSION:-3.47.5}" ;;
  "build macos")
    frameworks=build/macos/Build/Products/Release/tower_defense.app/Contents/Frameworks
    # framework <name> <its Info.plist's CFBundleExecutable, or ""> [none: no binary]
    framework() {
      d=$frameworks/$1.framework exe=${2:-$1}
      mkdir -p "$d/Versions/A/Resources"
      ln -s A "$d/Versions/Current"
      ln -s Versions/Current/Resources "$d/Resources"
      [ -z "$2" ] || printf '<?xml version="1.0" encoding="UTF-8"?>\n<plist version="1.0"><dict><key>CFBundleExecutable</key><string>%s</string></dict></plist>\n' "$2" > "$d/Versions/A/Resources/Info.plist"
      [ "$3" = none ] && return
      echo binary > "$d/Versions/A/$exe"
      ln -s "Versions/Current/$exe" "$d/$exe"
    }
    fw=$frameworks/App.framework
    mkdir -p build/macos/Build/Products/Release/tower_defense.app/Contents/MacOS "$fw/Versions/A/Resources/flutter_assets"
    echo binary > build/macos/Build/Products/Release/tower_defense.app/Contents/MacOS/tower_defense
    echo binary > "$fw/Versions/A/App"
    ln -s A "$fw/Versions/Current"
    ln -s Versions/Current/Resources "$fw/Resources"
    ln -s Versions/Current/App "$fw/App"
    cp -R assets "$fw/Versions/A/Resources/flutter_assets/assets"
    framework flutter_soloud_plugin flutter_soloud_plugin # the native assets' framework
    framework Other other_bin                             # a binary named otherwise than its framework
    framework Data "" none                                # resources only
    [ -z "$STUB_FRAMEWORK_MISSING" ] || framework Broken missing_bin none
    [ -z "$STUB_BUNDLE_EXTRA" ] || echo x > "$fw/Versions/A/Resources/flutter_assets/assets/images/$STUB_BUNDLE_EXTRA" ;;
  "build apk")
    [ -z "$STUB_GRADLE_DEBUG" ] ||
      echo "WARNING: no Android release signing key (x not found; set ANDROID_KEY_PROPERTIES)." >&2
    mkdir -p build/app/outputs/flutter-apk
    python3 - <<'PY'
import os, struct, zipfile

def elf(is64, align):  # an ELF header and one LOAD segment aligned to `align`
    ident = b'\x7fELF' + bytes([2 if is64 else 1, 1, 1]) + bytes(9)
    if is64:
        return (struct.pack('<16sHHIQQQIHHHHHH', ident, 3, 183, 1, 0, 64, 0, 0, 64, 56, 1, 0, 0, 0)
                + struct.pack('<IIQQQQQQ', 1, 5, 0, 0, 0, 120, 120, align))
    return (struct.pack('<16sHHIIIIIHHHHHH', ident, 3, 40, 1, 0, 52, 0, 0, 52, 32, 1, 0, 0, 0)
            + struct.pack('<IIIIIIII', 1, 0, 0, 0, 84, 84, 5, align))

with zipfile.ZipFile("build/app/outputs/flutter-apk/app-release.apk", "w") as z:
    z.writestr("classes.dex", "dex")
    align = int(os.environ.get("STUB_ELF_ALIGN") or 16384)
    for abi in ("arm64-v8a", "x86_64"):
        for lib in ("libflutter.so", "libFLAC.so"):
            z.writestr(f"lib/{abi}/{lib}", elf(True, align if lib == "libFLAC.so" else 16384))
    z.writestr("lib/armeabi-v7a/libflutter.so", elf(False, 4096))
    for d, _, fs in os.walk("assets"):
        for f in fs:
            z.write(os.path.join(d, f), "assets/flutter_assets/" + os.path.join(d, f))
    extra = os.environ.get("STUB_BUNDLE_EXTRA")
    if extra:
        z.writestr("assets/flutter_assets/assets/images/" + extra, "x")
PY
    ;;
esac
EOF
cat > "$stubs/lipo" <<'EOF'
#!/bin/sh
echo "lipo $*" >> "$STUB_CALLS"
echo "${STUB_LIPO:-x86_64 arm64}"
EOF
# zipalign: its usage without arguments (with -P, as build-tools 35 and later, unless STUB_ZIPALIGN=old), and -c.
cat > "$stubs/zipalign" <<'EOF'
#!/bin/sh
if [ $# = 0 ]; then
  if [ "$STUB_ZIPALIGN" = old ]; then echo "Usage: zipalign -c [-p] [-v] <align> infile.zip"; else echo "Usage: zipalign -c [-p] [-P <pagesize_kb>] [-v] <align> infile.zip"; fi
  exit 2
fi
echo "zipalign $*" >> "$STUB_CALLS"
if [ "$STUB_ZIPALIGN" = bad ]; then
  echo "    4100 lib/arm64-v8a/libFLAC.so (BAD - 4)"
  echo "Verification FAILED"
  exit 1
fi
echo "Verification succesful"
EOF
cat > "$stubs/apksigner" <<'EOF'
#!/bin/sh
echo "apksigner $*" >> "$STUB_CALLS"
case "${STUB_SIGNER:-release}" in
  release)
    echo "Signer #1 certificate DN: CN=Path of Hero, O=Trias, L=Indonesia, C=ID"
    echo "Signer #1 certificate SHA-256 digest: ac2058b2bb5f886feb66431f8a1a65cf878a7b5aa1c0feecee8da2ea21f7375b" ;;
  debug)
    echo "Signer #1 certificate DN: C=US, O=Android, CN=Android Debug"
    echo "Signer #1 certificate SHA-256 digest: 1111111111111111111111111111111111111111111111111111111111111111" ;;
  other)
    echo "Signer #1 certificate DN: CN=Someone Else"
    echo "Signer #1 certificate SHA-256 digest: 2222222222222222222222222222222222222222222222222222222222222222" ;;
esac
EOF
chmod +x "$stubs"/*
export PATH="$stubs:$PATH" FLUTTER=$stubs/flutter
unset BUTLER_API_KEY STUB_FLUTTER_VERSION STUB_BUNDLE_EXTRA STUB_GRADLE_DEBUG STUB_LIPO STUB_SIGNER STUB_ZIPALIGN \
  STUB_ELF_ALIGN STUB_FRAMEWORK_MISSING ANDROID_SDK_ROOT
export ANDROID_HOME=$tmp/no-sdk # no build-tools: the stubs alone, never this Mac's zipalign
: > "$tmp/key.properties"
export ANDROID_KEY_PROPERTIES=$tmp/key.properties
no_key=$tmp/missing/key.properties

out= code=
# rb <script> <args...>: runs it, keeping its output in $out and its exit code in $code; the stub log starts empty.
rb() {
  local s=$1
  shift
  : > "$STUB_CALLS"
  code=0
  out=$("$s" "$@" 2>&1) || code=$?
}
has() { # <label> <fixed text>
  if printf '%s\n' "$out" | grep -qF -- "$2"; then pass "$1"; else fail "$1: no '$2' in the output" "$out"; fi
}
lacks() { # <label> <fixed text>
  if printf '%s\n' "$out" | grep -qF -- "$2"; then fail "$1: '$2' in the output" "$out"; else pass "$1"; fi
}
exits() { # <label> <code>
  if [ "$code" = "$2" ]; then pass "$1 (exit $2)"; else fail "$1: exit $code, expected $2" "$out"; fi
}
no_tools() { # <label>: no stub ran
  if [ -s "$STUB_CALLS" ]; then fail "$1: ran $(tr '\n' ';' < "$STUB_CALLS")"; else pass "$1: ran no tool"; fi
}

# --- Syntax ------------------------------------------------------------------------------------------------------

for f in "$script" "$0"; do
  if bash -n "$f"; then pass "bash -n ${f#"$repo"/}"; else fail "bash -n ${f#"$repo"/}"; fi
done

# --- The dry run on this repo ------------------------------------------------------------------------------------

version=$(sed -n 's/^version:[[:space:]]*\([^[:space:]#]*\).*$/\1/p' "$repo/pubspec.yaml" | head -n 1)
v=${version%%+*}
dist_before=$(ls -a "$repo/dist" 2>/dev/null || true)

rb "$script" all --dry-run
exits "all --dry-run" 0
no_tools "all --dry-run"
has "repo assets pass" "all on the allowlist"
has "version check printed" "--version --machine"
has "mac build" "flutter build macos --release --dart-define=APP_VERSION=$version"
has "universal check" "lipo -archs build/macos/Build/Products/Release/tower_defense.app/Contents/MacOS/tower_defense"
has "ditto into the staging folder" "ditto build/macos/Build/Products/Release/tower_defense.app dist/PathOfHero-mac-$v/Path\\ of\\ Hero.app"
has "signature check" "codesign --verify --deep --strict dist/PathOfHero-mac-$v/Path\\ of\\ Hero.app"
has "mac notices" "cp THIRD_PARTY_NOTICES.txt dist/PathOfHero-mac-$v/THIRD_PARTY_NOTICES.txt"
has "mac credits" "cp CREDITS.md dist/PathOfHero-mac-$v/CREDITS.txt"
has "mac launch manifest" "cp .itch.toml dist/PathOfHero-mac-$v/.itch.toml"
pin=$(sed -n 's/^      prebuild_tag: *\([^ #]*\).*/\1/p' "$repo/pubspec.yaml")
has "the repo pins flutter_soloud's Xiph prebuilds" "ok: flutter_soloud's Xiph prebuilds pinned to $pin, named in the notices and credits"
if [[ $pin =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then pass "the pin is a release tag: $pin"; else fail "the pin: '$pin'"; fi
has "mac: the Xiph record step" "check flutter_soloud's record of the Xiph prebuilds it linked for macos: must be $pin"
has "android: the Xiph record step" "check flutter_soloud's record of the Xiph prebuilds it linked for android: must be $pin"
has "android: the 16 KB check" "zipalign -c -P 16 -v 4 build/app/outputs/flutter-apk/app-release.apk"
has "android build" "flutter build apk --release --dart-define=APP_VERSION=$version"
has "android key.properties passed on" "ANDROID_KEY_PROPERTIES=$tmp/key.properties"
has "signer check" "apksigner verify --print-certs build/app/outputs/flutter-apk/app-release.apk"
has "apk staged alone" "cp build/app/outputs/flutter-apk/app-release.apk dist/PathOfHero-android-$v/PathOfHero-android-$v.apk"
has "butler dry run, mac" "butler push --dry-run dist/PathOfHero-mac-$v triasbrata/path-of-hero:mac --userversion $version"
has "butler push, mac" "butler push dist/PathOfHero-mac-$v triasbrata/path-of-hero:mac --userversion $version --if-changed"
has "butler dry run, android" "butler push --dry-run dist/PathOfHero-android-$v triasbrata/path-of-hero:android --userversion $version"
has "butler push, android" "butler push dist/PathOfHero-android-$v triasbrata/path-of-hero:android --userversion $version --if-changed"
has "butler status" "butler status triasbrata/path-of-hero"
has "key unset noted" "BUTLER_API_KEY isn't set"
if [ "$(ls -a "$repo/dist" 2>/dev/null || true)" = "$dist_before" ]; then
  pass "the dry run wrote nothing in dist/"
else
  fail "the dry run changed dist/"
fi

ANDROID_KEY_PROPERTIES=$no_key rb "$script" mac --dry-run
exits "mac --dry-run needs no Android key" 0
lacks "mac --dry-run: no android step" "flutter build apk"
lacks "mac --dry-run: no android push" ":android"

BUTLER_API_KEY=not-a-real-key rb "$script" mac --dry-run
has "key set noted, never printed" "BUTLER_API_KEY is set"
lacks "the key's value is never printed" "not-a-real-key"

ANDROID_KEY_PROPERTIES=$no_key rb "$script" android --dry-run
exits "android without release signing" 1
has "android without release signing: why" "Android release signing isn't configured"
lacks "android without release signing: nothing built" "flutter build"

ANDROID_KEY_PROPERTIES=$no_key rb "$script" all --dry-run
exits "all without release signing fails before mac builds" 1
lacks "all without release signing: nothing built" "flutter build"

rb "$script" check
exits "check" 0
no_tools "check"
has "check passes" "checks passed"
has "check: the asset vault" "ok: the asset vault (tool/asset_vault.py check)"

for args in "" "win" "mac android" "mac --bogus" "mac extra" "extra" "check a b" "check --xiph" "check --xiph beos" \
  "mac --xiph macos" "--xiph macos check" "check --xiph macos --xiph linux"; do
  # shellcheck disable=SC2086 # split on purpose
  rb "$script" $args
  exits "usage: '$args'" 2
done
rb "$script" check "$tmp/nowhere"
exits "check: a missing folder" 1

# --- A throwaway copy: the checks that fail, and the real build path -----------------------------------------------

fake=$tmp/repo
soloud=$tmp/pub-cache/flutter_soloud-5.1.2
fake_hooks=$'hooks:\n  user_defines:\n    flutter_soloud:\n      prebuild_tag: v1.0.2\n'
xiph_record() { # <folder under prebuild/> <tag>: the hook's record of the release it downloaded there
  mkdir -p "$soloud/.dart_tool/flutter_soloud/xiph/prebuild/$1"
  echo "$2" > "$soloud/.dart_tool/flutter_soloud/xiph/prebuild/$1/flutter_soloud_prebuild_version.txt"
}
make_fake() { # a fresh copy with valid assets, version 1.2.3+4 and the pin v1.0.2
  rm -rf "$fake"
  mkdir -p "$fake/scripts" "$fake/assets/ai" "$fake/assets/fonts" "$fake/assets/images" "$fake/assets/music" \
    "$fake/assets/sfx"
  cp "$script" "$fake/scripts/"
  printf 'name: tower_defense\nversion: 1.2.3+4 # a comment\n%s' "$fake_hooks" > "$fake/pubspec.yaml"
  echo "notices: the binaries of alnitak/flutter_soloud_prebuilds release v1.0.2 on GitHub" > "$fake/THIRD_PARTY_NOTICES.txt"
  echo "credits: [alnitak/flutter_soloud_prebuilds](https://github.com/alnitak/flutter_soloud_prebuilds) release v1.0.2, pinned" > "$fake/CREDITS.md"
  cp "$repo/.itch.toml" "$fake/.itch.toml"
  # flutter_soloud outside the copy, as in the pub cache, with the hook's records of v1.0.2 (as on this Mac).
  rm -rf "$soloud"
  for d in include macos android/arm64-v8a android/x86_64; do xiph_record "$d" v1.0.2; done
  mkdir -p "$fake/.dart_tool"
  printf '{\n  "configVersion": 2,\n  "packages": [\n    {\n      "name": "flutter_soloud",\n      "rootUri": "file://%s",\n      "packageUri": "lib/"\n    }\n  ]\n}\n' "$soloud" > "$fake/.dart_tool/package_config.json"
  echo '{}' > "$fake/assets/ai/retreat.json"
  echo font > "$fake/assets/fonts/PohSans.ttf"
  echo png > "$fake/assets/images/tiny_knight_idle.png"
  echo png > "$fake/assets/images/town_bg_1.png"
  cp "$repo/assets/images/item_sword.png" "$fake/assets/images/" # the loot icon of the name a Raven one had
  echo ogg > "$fake/assets/music/battle.ogg"
  echo wav > "$fake/assets/sfx/hit.wav"
}
fs=$fake/scripts/release-build.sh

make_fake
rb "$fs" mac --dry-run
exits "copy: mac --dry-run" 0
has "copy: the folder is named X.Y.Z" "dist/PathOfHero-mac-1.2.3/Path\\ of\\ Hero.app"
has "copy: --userversion is X.Y.Z+N" "--userversion 1.2.3+4 --if-changed"
has "copy: 7 assets" "7 files under assets/"
has "copy: no vault listing, said so" "skip: no tool/asset_vault.json here"

# The asset vault's check (tool/asset_vault.py check, which needs no key): a listing whose game vault holds the copy's
# knight, and a part that is only bytes (check never decrypts).
vault_copy() { # [<part's bytes, if not the listed ones>]
  mkdir -p "$fake/tool" "$fake/assets-vault"
  cp "$repo/tool/asset_vault.py" "$fake/tool/"
  printf 'part' > "$fake/assets-vault/game-x.tar.gz.enc"
  (cd "$fake" && python3 - "${1:-}" <<'PY'
import hashlib, json, sys
h = lambda b: hashlib.sha256(b).hexdigest()
knight = open("assets/images/tiny_knight_idle.png", "rb").read()
part = sys.argv[1].encode() or b"part"
doc = {"about": "", "format": {}, "vaults": [{"name": "game-x", "group": "game", "pack": "x", "licence": "x",
       "needed_by_build": True, "match": ["assets/images/tiny_*"], "tar": {"sha256": "0" * 64, "bytes": 0},
       "parts": [{"path": "assets-vault/game-x.tar.gz.enc", "bytes": len(part), "sha256": h(part)}],
       "files": [{"path": "assets/images/tiny_knight_idle.png", "bytes": len(knight), "sha256": h(knight),
                  "needed_by_build": True}]}]}
open("tool/asset_vault.json", "w").write(json.dumps(doc))
PY
  )
}
make_fake
vault_copy
rb "$fs" check
exits "copy: the vault holds what the build needs" 0
has "copy: the vault checked" "ok: the asset vault"
rm "$fake/assets/images/tiny_knight_idle.png"
rb "$fs" mac --dry-run
exits "copy: a needed file missing" 1
has "copy: a needed file missing: names it" "assets/images/tiny_knight_idle.png: missing (vault game-x)"
has "copy: a needed file missing: why" "the asset vault doesn't hold what a build needs"
lacks "copy: a needed file missing: nothing built" "flutter build"
make_fake
vault_copy
echo png > "$fake/assets/images/tiny_new_walk.png"
rb "$fs" check
exits "copy: a file newer than its vault" 1
has "copy: a file newer than its vault: names it" "assets/images/tiny_new_walk.png: not in vault game-x"
make_fake
vault_copy other
rb "$fs" check
exits "copy: a damaged vault part" 1
has "copy: a damaged vault part: names it" "assets-vault/game-x.tar.gz.enc: not the bytes tool/asset_vault.json lists"

bad_asset() { # <label> <path under the copy> <text the failure names> [<source file>]
  make_fake
  mkdir -p "$(dirname "$fake/$2")"
  if [ -n "${4:-}" ]; then cp "$4" "$fake/$2"; else echo x > "$fake/$2"; fi
  rb "$fs" mac --dry-run
  exits "$1" 1
  has "$1: names it" "$3"
  lacks "$1: nothing built" "flutter build"
}
bad_asset "floors.png" assets/images/floors.png "floors.png never ships"
bad_asset "a Raven file by name" assets/images/Raven_icon.png "a Raven Fantasy Icons file"
bad_asset "a hidden file" assets/images/.DS_Store "a hidden file"
bad_asset "a file off the allowlist" assets/images/notes.txt "not on the allowlist"
bad_asset "an unknown folder" assets/maps/a.json "not on the allowlist"
bad_asset "a nested file" assets/images/sub/tiny_a.png "not on the allowlist"
# The denied files' own bytes come from the commits that once held them: the private archive's history. A clone of
# the public history (one fresh commit, decisions-log 315) has neither, so these three are skipped there.
raven=$tmp/raven_sword.png
if git -C "$repo" show 8a4ab07:assets/images/item_sword.png > "$raven" 2>/dev/null; then
  bad_asset "a Raven icon under our name" assets/images/item_sword.png "the same file as the Raven item_sword.png" "$raven"
  bad_asset "a Raven icon renamed" assets/images/relic_x.png "the same file as the Raven item_sword.png" "$raven"
else
  echo "skip a Raven icon by its bytes (twice): its commit isn't in this clone's history"
fi
if git -C "$repo" show f03a899:assets/images/floors.png > "$tmp/floors.png" 2>/dev/null; then
  bad_asset "floors.png renamed" assets/images/ui_floor.png "the same file as the floors.png" "$tmp/floors.png"
else
  echo "skip floors.png by its bytes: its commit isn't in this clone's history"
fi

make_fake
rm -rf "$fake/assets"/*
rb "$fs" mac --dry-run
exits "no asset files" 1

# A retired file (RETIRED_ASSETS: no longer bundled, left in the checkout until the game is closed) passes the
# checkout's check, named; a file of the same folder that isn't on either list still fails.
make_fake
echo font > "$fake/assets/fonts/PixelifySans.ttf"
rb "$fs" mac --dry-run
exits "a retired file in the checkout" 0
has "a retired file in the checkout: named" "8 files under assets/, all on the allowlist but 1 retired ones no build bundles"
bad_asset "a font off both lists" assets/fonts/Other.ttf "not on the allowlist"

make_fake
printf 'version: 1.2\n' > "$fake/pubspec.yaml"
rb "$fs" mac --dry-run
exits "a version without +N" 1
has "a version without +N: why" "isn't X.Y.Z+N"

bad_pin() { # <label> <the pubspec's hooks: section> <text the failure names>
  make_fake
  printf 'name: tower_defense\nversion: 1.2.3+4\n%s' "$2" > "$fake/pubspec.yaml"
  rb "$fs" check
  exits "$1" 1
  has "$1: why" "$3"
}
bad_pin "no pin" "" "doesn't pin flutter_soloud's prebuilt Xiph libraries"
bad_pin "the pin under another package" $'hooks:\n  user_defines:\n    other:\n      prebuild_tag: v1.0.2\n' "doesn't pin"
bad_pin "the pin outside hooks" $'flutter_soloud:\n  prebuild_tag: v1.0.2\n' "doesn't pin"
bad_pin "the pin 'latest'" $'hooks:\n  user_defines:\n    flutter_soloud:\n      prebuild_tag: latest\n' "isn't one release tag vX.Y.Z"
bad_pin "the pin without its v" $'hooks:\n  user_defines:\n    flutter_soloud:\n      prebuild_tag: 1.0.2\n' "isn't one release tag vX.Y.Z"
bad_pin "the pin's release not in the notices" $'hooks:\n  user_defines:\n    flutter_soloud:\n      prebuild_tag: v1.0.3\n' "THIRD_PARTY_NOTICES.txt doesn't name the Xiph prebuilds' release v1.0.3"

make_fake
printf 'name: tower_defense\nversion: 1.2.3+4\nhooks:\n    user_defines:\n        flutter_soloud:\n            no_xiph_libs: false\n            prebuild_tag: "v1.0.2"   # pinned\nflutter:\n  uses-material-design: true\n' > "$fake/pubspec.yaml"
rb "$fs" check
exits "the pin quoted, with a comment, another indent" 0
has "the pin quoted: read" "pinned to v1.0.2"

make_fake
echo credits > "$fake/CREDITS.md"
rb "$fs" check
exits "the pin's release not in the credits" 1
has "the pin's release not in the credits: why" "CREDITS.md doesn't name the Xiph prebuilds' release v1.0.2"
make_fake
echo "credits: flutter_soloud_prebuilds release v1.0.20" > "$fake/CREDITS.md"
rb "$fs" check
exits "the credits name another release (v1.0.20)" 1

make_fake
rm "$fake/.itch.toml"
rb "$fs" mac --dry-run
exits "no .itch.toml" 1
has "no .itch.toml: why" "no .itch.toml"

# check --xiph <os>: the hook's records in the fake flutter_soloud.
make_fake
rb "$fs" check --xiph macos
exits "check --xiph macos" 0
has "check --xiph macos: the headers' record" "include/flutter_soloud_prebuild_version.txt: v1.0.2"
has "check --xiph macos: the platform's record" "macos/flutter_soloud_prebuild_version.txt: v1.0.2"
has "check --xiph macos: ok" "ok: the build linked the pinned Xiph prebuilds v1.0.2 for macos"
rb "$fs" check --xiph android
exits "check --xiph android (two ABIs)" 0
has "check --xiph android: each ABI" "android/x86_64/flutter_soloud_prebuild_version.txt: v1.0.2"
rb "$fs" check --xiph linux
exits "check --xiph linux: no record" 1
has "check --xiph linux: no record: why" "left no record of the Xiph prebuilds it linked for linux"
xiph_record linux/x64 v1.0.2
rb "$fs" check --xiph linux
exits "check --xiph linux" 0
xiph_record android/x86_64 v1.0.1
rb "$fs" check --xiph android
exits "check --xiph: one ABI linked another release" 1
has "check --xiph: another release: why" "another release than the pin v1.0.2"
xiph_record include latest
rb "$fs" check --xiph macos
exits "check --xiph: the headers of 'latest'" 1
rm "$soloud/.dart_tool/flutter_soloud/xiph/prebuild/include/flutter_soloud_prebuild_version.txt"
rb "$fs" check --xiph macos
exits "check --xiph: no headers' record" 1
make_fake
rm "$fake/.dart_tool/package_config.json"
rb "$fs" check --xiph macos
exits "check --xiph: no package config" 1
has "check --xiph: no package config: why" "no .dart_tool/package_config.json"

make_fake
mkdir -p "$tmp/bundle/assets/images"
echo x > "$tmp/bundle/assets/images/tiny_a.png"
rb "$fs" check "$tmp/bundle"
exits "check <flutter_assets>: clean" 0
cp "$tmp/floors.png" "$tmp/bundle/assets/images/floors.png"
rb "$fs" check "$tmp/bundle"
exits "check <flutter_assets>: floors.png" 1
has "check <flutter_assets>: names the build" "the build's assets"
rm "$tmp/bundle/assets/images/floors.png"
mkdir -p "$tmp/bundle/assets/fonts"
echo font > "$tmp/bundle/assets/fonts/PohDigits-Bold.ttf"
rb "$fs" check "$tmp/bundle"
exits "check <flutter_assets>: a retired file" 1
has "check <flutter_assets>: a retired file: why" "PohDigits-Bold.ttf: retired, no build may bundle it"

# The real path, with the stubs, but the real ditto.
if [ "$(uname)" = Darwin ]; then
  rm "$stubs/ditto"
  make_fake
  rb "$fs" all
  exits "copy: all (stubbed build)" 0
  stage=$fake/dist/PathOfHero-mac-1.2.3
  app="$stage/Path of Hero.app"
  if [ -f "$app/Contents/MacOS/tower_defense" ]; then pass "mac: Path of Hero.app staged"; else fail "mac: no app" "$out"; fi
  if [ -L "$app/Contents/Frameworks/App.framework/Resources" ]; then
    pass "mac: ditto kept the symlinks"
  else
    fail "mac: a framework symlink was lost"
  fi
  if cmp -s "$stage/THIRD_PARTY_NOTICES.txt" "$fake/THIRD_PARTY_NOTICES.txt" &&
    cmp -s "$stage/CREDITS.txt" "$fake/CREDITS.md"; then
    pass "mac: the notices and credits beside the app"
  else
    fail "mac: notices or credits missing"
  fi
  if cmp -s "$stage/.itch.toml" "$repo/.itch.toml"; then pass "mac: .itch.toml at the build's root"; else fail "mac: no .itch.toml"; fi
  listing=$(ls -A "$stage" | tr '\n' '|')
  if [ "$listing" = ".itch.toml|CREDITS.txt|Path of Hero.app|THIRD_PARTY_NOTICES.txt|" ]; then
    pass "mac: the build's root holds the app, the notices, the credits and .itch.toml"
  else
    fail "mac: the build's root holds $listing"
  fi
  has "mac: the Xiph prebuilds checked" "ok: the build linked the pinned Xiph prebuilds v1.0.2 for macos"
  has "mac: universal" "ok: universal (arm64 + x86_64): 4 binaries"
  has "mac: the native assets' framework checked" "Contents/Frameworks/flutter_soloud_plugin.framework/flutter_soloud_plugin: x86_64 arm64"
  has "mac: a framework's binary from its Info.plist" "Contents/Frameworks/Other.framework/other_bin: x86_64 arm64"
  lacks "mac: a resources-only framework skipped" "Data.framework"
  has "mac: bundled assets checked" "ok: the app's bundled assets: 7 files"
  if grep -qF "codesign --verify --deep --strict dist/PathOfHero-mac-1.2.3/Path of Hero.app" "$STUB_CALLS"; then
    pass "mac: staged app's signature checked"
  else
    fail "mac: no codesign" "$(cat "$STUB_CALLS")"
  fi
  if [ "$(ls -A "$fake/dist/PathOfHero-android-1.2.3")" = "PathOfHero-android-1.2.3.apk" ]; then
    pass "android: the APK staged alone (no .itch.toml: the itch app runs no APK)"
  else
    fail "android: staged $(ls -A "$fake/dist/PathOfHero-android-1.2.3" 2>&1)"
  fi
  has "android: the Xiph prebuilds checked" "ok: the build linked the pinned Xiph prebuilds v1.0.2 for android"
  has "android: signer checked" "ok: signed with the release signing key"
  has "android: zipalign -c -P 16" "ok: zipalign -c -P 16: every uncompressed .so in the APK aligned for 16 KB pages"
  if grep -qF "zipalign -c -P 16 -v 4 build/app/outputs/flutter-apk/app-release.apk" "$STUB_CALLS"; then
    pass "android: zipalign ran on the APK"
  else
    fail "android: no zipalign" "$(cat "$STUB_CALLS")"
  fi
  has "android: a 64-bit library's segments" "lib/arm64-v8a/libFLAC.so: LOAD segments aligned to 16384 bytes"
  has "android: a 32-bit library listed only" "lib/armeabi-v7a/libflutter.so: LOAD segments aligned to 4096 bytes (32-bit: 4 KB pages only)"
  has "android: the segments ok" "ok: every 64-bit native library's LOAD segments aligned to 16 KB or more"
  has "android: bundled assets checked" "ok: the APK's bundled assets: 7 files"
  has "android: the build's log" "build/release-build/android.log"
  has "staged, not pushed" "Staged (nothing was pushed)"
  if grep -q '^butler' "$STUB_CALLS"; then fail "butler ran"; else pass "butler never ran"; fi

  make_fake
  STUB_SIGNER=debug rb "$fs" android
  exits "android: a debug-signed APK" 1
  has "android: a debug-signed APK: why" "signed with the DEBUG key"
  if [ -e "$fake/dist/PathOfHero-android-1.2.3" ]; then fail "android: a debug-signed APK was staged"; else pass "android: a debug-signed APK isn't staged"; fi

  make_fake
  STUB_SIGNER=other rb "$fs" android
  exits "android: signed by another key" 1
  has "android: signed by another key: why" "not the release signing key"

  not_staged() { # <label>
    if [ -e "$fake/dist/PathOfHero-android-1.2.3" ]; then fail "$1: staged"; else pass "$1: nothing staged"; fi
  }
  make_fake
  STUB_ELF_ALIGN=4096 rb "$fs" android
  exits "android: a 64-bit library aligned to 4 KB" 1
  has "android: 4 KB: names it" "lib/arm64-v8a/libFLAC.so: LOAD segments aligned to 4096 bytes -- BAD, needs 16384"
  not_staged "android: 4 KB"

  make_fake
  STUB_ZIPALIGN=bad rb "$fs" android
  exits "android: zipalign -c -P 16 fails" 1
  has "android: zipalign fails: names the library" "lib/arm64-v8a/libFLAC.so (BAD - 4)"
  not_staged "android: zipalign fails"

  make_fake
  STUB_ZIPALIGN=old rb "$fs" android
  exits "android: a zipalign without -P" 1
  has "android: a zipalign without -P: why" "no zipalign with -P"
  not_staged "android: a zipalign without -P"

  make_fake
  xiph_record android/arm64-v8a v1.0.3
  rb "$fs" android
  exits "android: linked another release of the Xiph prebuilds" 1
  not_staged "android: another Xiph release"

  make_fake
  xiph_record macos v1.0.3
  rb "$fs" mac
  exits "mac: linked another release of the Xiph prebuilds" 1
  has "mac: another Xiph release: why" "another release than the pin v1.0.2"
  if [ -e "$fake/dist/PathOfHero-mac-1.2.3" ]; then fail "mac: another Xiph release was staged"; else pass "mac: another Xiph release isn't staged"; fi

  make_fake
  STUB_FRAMEWORK_MISSING=1 rb "$fs" mac
  exits "mac: a framework's declared binary missing" 1
  has "mac: a framework's declared binary missing: names it" "Broken.framework: no missing_bin, its Info.plist's CFBundleExecutable"

  make_fake
  STUB_GRADLE_DEBUG=1 rb "$fs" android
  exits "android: Gradle fell back to the debug key" 1
  has "android: Gradle fell back: why" "signed with the debug key"

  make_fake
  STUB_BUNDLE_EXTRA=floors.png rb "$fs" android
  exits "android: the APK bundled floors.png" 1
  if [ -e "$fake/dist/PathOfHero-android-1.2.3" ]; then fail "android: a bad APK was staged"; else pass "android: a bad APK isn't staged"; fi

  make_fake
  STUB_BUNDLE_EXTRA=floors.png rb "$fs" mac
  exits "mac: the app bundled floors.png" 1
  has "mac: the app bundled floors.png: names it" "the app's bundled assets"
  if [ -e "$fake/dist/PathOfHero-mac-1.2.3" ]; then fail "mac: a bad app was staged"; else pass "mac: a bad app isn't staged"; fi

  make_fake
  STUB_LIPO=arm64 rb "$fs" mac
  exits "mac: not universal" 1
  has "mac: not universal: why" "isn't universal"

  make_fake
  STUB_FLUTTER_VERSION=3.99.0 rb "$fs" mac
  exits "mac: another Flutter" 1
  has "mac: another Flutter: why" "a release is built with 3.47.5"
else
  echo "skip the stubbed builds: not macOS"
fi

# --- The docs and the workflow agree with the script ---------------------------------------------------------------

# The allowlist's copy for people is in the store page's doc: docs/itch-page.md here, the private notes' copy
# (private/docs/itch-page.md) in the public repository; a clone without the private notes skips the comparison.
script_list=$(sed -n '/^ALLOWED_ASSETS=($/,/^)$/p' "$script" | sed '1d;$d' | tr -d " '")
allow_doc=
for d in "$repo/docs/itch-page.md" "$repo/private/docs/itch-page.md"; do
  if [ -f "$d" ] && grep -q '<!-- ALLOWED_ASSETS' "$d"; then allow_doc=$d; break; fi
done
if [ -z "$allow_doc" ]; then
  echo "skip the allowlist's doc copy: no itch-page.md here (it is in the private notes)"
else
  doc_list=$(awk '/<!-- ALLOWED_ASSETS/ { found = 1; next }
    found && /^ *```/ { if (inside) exit; inside = 1; next }
    inside { sub(/^ +/, ""); print }' "$allow_doc")
  if [ -n "$script_list" ] && [ "$script_list" = "$doc_list" ]; then
    pass "${allow_doc#"$repo/"}'s allowlist is the script's"
  else
    fail "the allowlists differ" "$(diff <(echo "$script_list") <(echo "$doc_list") || true)"
  fi
fi

pin=$(sed -n 's/^FLUTTER_VERSION=\([0-9.]*\).*/\1/p' "$script")
if grep -qE "^  FLUTTER_VERSION: $pin( |$)" "$workflow" && grep -qF "Flutter $pin" "$repo/docs/dev-workflow.md"; then
  pass "one Flutter ($pin): the script, the workflow, dev-workflow.md"
else
  fail "the Flutter pins differ (script $pin)"
fi

if command -v ruby >/dev/null 2>&1; then
  if jobs=$(ruby -ryaml -e 'puts YAML.load_file(ARGV[0])["jobs"].keys.sort.join(" ")' "$workflow" 2>&1); then
    if [ "$jobs" = "linux windows" ]; then pass "the workflow parses: jobs $jobs"; else fail "workflow jobs: $jobs"; fi
  else
    fail "the workflow isn't valid YAML" "$jobs"
  fi
else
  echo "skip the YAML parse: no ruby"
fi
code_lines=$(grep -vE '^[[:space:]]*#' "$workflow")
guards=$(printf '%s\n' "$code_lines" | grep -cF "if: github.repository == 'triasbrata/path-of-hero' || github.repository == 'triasbrata/tower-defense'" || true)
if [ "$guards" = 2 ]; then pass "both jobs run only in the game's own repositories"; else fail "repository guards: $guards"; fi
for word in butler pull_request actions/cache 'set -x' add-mask; do
  if printf '%s\n' "$code_lines" | grep -qF -- "$word"; then fail "the workflow uses $word"; else pass "the workflow has no $word"; fi
done
# One secret, the asset vault's key: only as a step's env value (never inside a run: script), never printed.
secret_lines=$(printf '%s\n' "$code_lines" | grep -F 'secrets.' || true)
if [ "$(printf '%s\n' "$secret_lines" | grep -cxE ' +POH_VAULT_KEY: \$\{\{ secrets\.POH_VAULT_KEY \}\}' || true)" = 2 ] &&
  [ "$(printf '%s\n' "$secret_lines" | grep -c . || true)" = 2 ]; then
  pass "the only secret is POH_VAULT_KEY, as an env value of one step per job"
else
  fail "the workflow's secrets" "$secret_lines"
fi
key_uses=$(printf '%s\n' "$code_lines" | grep -E '\$\{?POH_VAULT_KEY' | grep -vxF '          if [ -n "${POH_VAULT_KEY:-}" ]; then' || true)
if [ -z "$key_uses" ]; then pass "the workflow never expands the key but to test it's set"; else fail "the key expanded" "$key_uses"; fi
for step in 'tool/asset_vault.py unpack --only game' 'tool/asset_vault.py check'; do
  c=$(printf '%s\n' "$code_lines" | grep -cF "\"\$py\" $step" || true)
  if [ "$c" = 2 ]; then pass "both jobs run $step"; else fail "$step in $c jobs"; fi
done
order=$(printf '%s\n' "$code_lines" | grep -oE 'name: The asset vault|name: Check assets/, the version and the pins' | tr '\n' '|')
if [ "$order" = "name: The asset vault|name: Check assets/, the version and the pins|name: The asset vault|name: Check assets/, the version and the pins|" ]; then
  pass "both jobs open the vault before the release checks"
else
  fail "the vault step's place" "$order"
fi
if printf '%s\n' "$code_lines" | grep -E 'uses: ' | grep -vqE 'uses: [^@]+@[0-9a-f]{40} '; then
  fail "an action isn't pinned by commit SHA" "$(printf '%s\n' "$code_lines" | grep -E 'uses: ')"
else
  pass "every action pinned by commit SHA"
fi
stage_lines=$(printf '%s\n' "$code_lines" | grep -cF 'cp .itch.toml "$stage/.itch.toml"' || true)
if [ "$stage_lines" = 2 ]; then pass "both jobs put .itch.toml at the build's root"; else fail ".itch.toml staged by $stage_lines jobs"; fi
for os in linux windows; do
  if printf '%s\n' "$code_lines" | grep -qF "bash scripts/release-build.sh check \"\$stage/data/flutter_assets\" --xiph $os"; then
    pass "the $os job checks the Xiph prebuilds it linked"
  else
    fail "the $os job doesn't check its Xiph prebuilds"
  fi
done
if printf '%s\n' "$code_lines" | grep -qE '^ +include-hidden-files: true'; then
  pass "the Windows artifact keeps .itch.toml (include-hidden-files)"
else
  fail "the Windows artifact would drop .itch.toml (upload-artifact leaves out dotfiles)"
fi
if printf '%s\n' "$code_lines" | grep -qF -- "-name '*.so.*'"; then
  pass "the glibc floor reads the SONAME-named Xiph libraries too"
else
  fail "the glibc floor misses lib/*.so.N"
fi

# .itch.toml: one "play" action per desktop platform, each the name the script or the workflow stages.
app_name=$(sed -n 's/^  local staged="\$stage\/\(.*\)"$/\1/p' "$script" | head -n 1)
windows_exe=$(sed -n 's/^ *test -f "\$stage\/\(.*\)"$/\1/p' "$workflow" | head -n 1)
linux_exe=$(sed -n 's/^ *test -x "\$stage\/\(.*\)"$/\1/p' "$workflow" | head -n 1)
if actions=$(python3 -c '
import sys, tomllib
manifest = tomllib.load(open(sys.argv[1], "rb"))
assert set(manifest) == {"actions"}, f"keys {sorted(manifest)}"
for a in manifest["actions"]:
    assert set(a) == {"name", "path", "platform"}, f"action keys {sorted(a)}"
    print("|".join([a["platform"], a["name"], a["path"]]))
' "$repo/.itch.toml" 2>&1); then
  expected=$(printf 'osx|play|%s\nwindows|play|%s\nlinux|play|%s' "$app_name" "$windows_exe" "$linux_exe")
  if [ -n "$app_name" ] && [ -n "$windows_exe" ] && [ -n "$linux_exe" ] && [ "$actions" = "$expected" ]; then
    pass ".itch.toml: play $app_name (osx), $windows_exe (windows), $linux_exe (linux)"
  else
    fail ".itch.toml's actions aren't the staged names" "$(diff <(echo "$expected") <(echo "$actions") || true)"
  fi
else
  fail ".itch.toml doesn't parse as an itch manifest" "$actions"
fi

if command -v actionlint >/dev/null 2>&1; then
  if actionlint "$workflow"; then pass "actionlint"; else fail "actionlint"; fi
else
  echo "skip actionlint: not installed"
fi

if grep -qiE '(key|pass)[a-z_-]*\.txt|\.jks|\.keystore' "$script"; then
  fail "the script names a key or password file"
else
  pass "the script names no key or password file"
fi

echo
echo "$passed passed, $failed failed"
[ "$failed" = 0 ]
