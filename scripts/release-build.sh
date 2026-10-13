#!/usr/bin/env bash
# Build Path of Hero's macOS and Android releases and stage them in dist/ for itch.io (docs/itch-page.md
# "Build checklist" and "Pushing builds", decisions-log 145). The owner runs it from their own Terminal: a build
# needs the network (flutter_soloud's build hook downloads the Xiph libraries, Gradle its plugins).
#
#   scripts/release-build.sh <mac|android|all> [--dry-run]
#   scripts/release-build.sh check [<flutter_assets dir>] [--xiph <macos|android|linux|windows>]
#
# - The version is pubspec.yaml's `version:` (e.g. 0.1.0+1): the folders are named after 0.1.0, and butler's
#   --userversion is 0.1.0+1.
# - Before anything is built, assets/ may hold only what a release ships: every file must match ALLOWED_ASSETS (the
#   list in docs/itch-page.md "What a build ships"), and none may be floors.png or a Raven icon (DENIED). The same
#   check runs again on the assets the build bundled. The checkout may also hold the RETIRED_ASSETS (files no build
#   bundles any more, left until the owner's game is closed), which a build's assets may never hold.
# - pubspec.yaml must pin the release of flutter_soloud's prebuilt Xiph libraries (hooks: user_defines:
#   flutter_soloud: prebuild_tag: vX.Y.Z; decisions-log 148), and THIRD_PARTY_NOTICES.txt and CREDITS.md must name
#   it. After a build, the hook's own record of what it linked (in flutter_soloud's .dart_tool) must say that tag.
# - .itch.toml (the itch app's launch actions) goes at the root of every desktop build.
# - mac: `flutter build macos --release`, staged as dist/PathOfHero-mac-<v>/ with "Path of Hero.app" (copied with
#   ditto, which keeps the frameworks' symlinks), THIRD_PARTY_NOTICES.txt, CREDITS.txt and .itch.toml. Every binary
#   in the app must hold arm64 and x86_64.
# - android: `flutter build apk --release`, only with the release signing key (decisions-log 132): no
#   key.properties, or an APK not signed with our key, fails, so a debug-signed APK is never staged. The APK is
#   staged alone in dist/PathOfHero-android-<v>/: a one-file build downloads from itch as the .apk itself, and a
#   folder keeps butler from reading the APK (a zip) as an archive to unpack. Its notices are in the game. Every
#   native library in it must load with 16 KB memory pages (zipalign -c -P 16, and its ELF segments).
# - It pushes nothing. At the end it prints the owner's butler commands; butler takes the key from BUTLER_API_KEY.
#   This script reads no key or password file.
# - --dry-run runs the checks above and prints every other step without running it: no flutter, ditto, apksigner,
#   lipo, codesign or zipalign, and nothing is written.
# - The asset vault (docs/assets.md "The asset vault"): `tool/asset_vault.py check` must pass: every file a build
#   needs at its path with its sha256, none newer than its vault, every vault part whole. It reads no key.
# - check: the checks alone (the CI workflow runs it); with a build's flutter_assets folder, its assets/ too; with
#   --xiph <os>, after a build for that OS, the hook's record of the Xiph libraries it linked.
set -euo pipefail

FLUTTER_VERSION=3.47.5 # the Mac's Flutter (dev-workflow.md); .github/workflows/release.yml pins the same
ITCH_TARGET=triasbrata/path-of-hero
# The release signing key's certificate (public; dev-workflow.md "Android release signing").
RELEASE_CERT_SHA256=ac2058b2bb5f886feb66431f8a1a65cf878a7b5aa1c0feecee8da2ea21f7375b

# Every file under assets/ must match one of these: assets/<folder>/<file>, and a * never crosses a /. The same
# list is in docs/itch-page.md "What a build ships"; scripts/test-release-build.sh checks that they agree.
ALLOWED_ASSETS=(
  'assets/ai/retreat.json'
  'assets/config/town.json'
  'assets/fonts/OFL-PohSans.txt'
  'assets/fonts/PohSans.ttf'
  'assets/images/artifact_icons.png'
  'assets/images/battle_clouds.png'
  'assets/images/battle_floor.png'
  'assets/images/battle_props.png'
  'assets/images/battle_step.png'
  'assets/images/dungeon_*.png'
  'assets/images/fx_hit_*.png'
  'assets/images/fx_upgrade.png'
  'assets/images/item_*.png'
  'assets/images/mat_*.png'
  'assets/images/pocket_*.png'
  'assets/images/relic_*.png'
  'assets/images/tiny_*.png'
  'assets/images/town_autumn_*.png'
  'assets/images/town_bg_*.png'
  'assets/images/town_campfire.png'
  'assets/images/town_castle.png'
  'assets/images/town_ground.png'
  'assets/images/town_ground_*.png'
  'assets/images/town_house.png'
  'assets/images/town_mark.png'
  'assets/images/town_mug.png'
  'assets/images/town_ore.png'
  'assets/images/town_pine.png'
  'assets/images/town_props.png'
  'assets/images/town_smith.png'
  'assets/images/town_smithy.png'
  'assets/images/town_tent.png'
  'assets/images/town_winter_*.png'
  'assets/images/town_yards.png'
  'assets/images/ui_*.png'
  'assets/music/*.ogg'
  'assets/sfx/*.wav'
)
# No longer bundled, but still in the checkout: pubspec.yaml names none of them, and a file under assets/ is deleted
# only while the owner's game, which hot-reloads from the main checkout, is closed (dev-workflow.md "Traps"). Pixelify
# Sans and PohDigits, which Poh Sans replaced (decisions-log 179). The source check lets them be; a build's assets
# fail with them. Delete the files, then these lines.
RETIRED_ASSETS=(
  'assets/fonts/OFL-PixelifySans.txt'
  'assets/fonts/OFL-PohDigits.txt'
  'assets/fonts/PixelifySans.ttf'
  'assets/fonts/PohDigits-Bold.ttf'
  'assets/fonts/PohDigits-Medium.ttf'
)
# Never shipped, under any name (decisions-log 136): floors.png (of unknown origin) and the 10 loot icons of
# "Free - Raven Fantasy Icons" (free games only; Cute Fantasy Icons Premium ones have the same names), by their
# sha256 in git history (8a4ab07). Any file named floors.png or with "raven" in its path fails too. If the owner
# buys the Raven premium pack (itch-page.md, Licences), its icons may match these: drop the Raven lines then.
DENIED=(
  '9c30bb02ff1f776ed6a036270af63d9ad2e369c37c68440f28b1a87ad0d44891 floors.png'
  '45f50dd89729d5373c97577de599c2437c4cbfe2f7f23dfcc0216e33d5206b5e Raven item_sword.png'
  '7d25970c7178e3c77e6b29729ed5004ab1c607f46ecef5943dd1a7daefe3e340 Raven item_shield.png'
  'f17b83290a0f6485435c9f51b0289971aa65e27eb37207f4d49de73853704bee Raven item_boots.png'
  '579e32610f9b69697cb0a7578607746d12758c771a237f3ad44eac640a666cdc Raven item_bow.png'
  '4c07d2833fd8d988308c680acb2fe4a1919c9b19d55b9f3bb405c25509abe1be Raven item_gloves.png'
  '053eeb3f7b626010f5c911f9e7b68e9719da098513a1f55e3bb8010ab2bda581 Raven item_potion.png'
  '9ddcab9d656c90434c19f42f91e6daad056cf14cbcace34e81a5912fd584553f Raven relic_fang.png'
  '0d1871e06c9152d999b5980e2b3ed5f10a65203adfeac7f33080e60affa32751 Raven relic_thorns.png'
  '3194909df7f0935dca477a3f770b83d0fc701679afdd92e4458504363d443721 Raven relic_fury.png'
  'dd204ee89a41238c827bd8367a66de3be6b2066aeeec9acce86db6322fe348a2 Raven relic_guard.png'
)

usage() {
  echo "usage: $0 <mac|android|all> [--dry-run]" >&2
  echo "       $0 check [<flutter_assets dir>] [--xiph <macos|android|linux|windows>]" >&2
  exit 2
}
die() {
  echo "release-build: $*" >&2
  exit 1
}

dry=0 target= bundled= xiph_os=
while [ $# -gt 0 ]; do
  case $1 in
    --dry-run) dry=1 ;;
    --xiph)
      [ "$target" = check ] && [ -z "$xiph_os" ] && [ $# -ge 2 ] || usage
      case $2 in macos | android | linux | windows) xiph_os=$2 ;; *) usage ;; esac
      shift
      ;;
    mac | android | all | check)
      [ -z "$target" ] || usage
      target=$1
      ;;
    -*) usage ;;
    *)
      [ "$target" = check ] && [ -z "$bundled" ] || usage
      bundled=$1
      ;;
  esac
  shift
done
[ -n "$target" ] || usage
if [ -n "$bundled" ]; then # before the cd: a relative path is the caller's
  [ -d "$bundled" ] || die "no folder $bundled"
  bundled=$(cd "$bundled" && pwd)
fi
cd "$(dirname "$0")/.."

# Prints a step as a shell command; run() also runs it, unless --dry-run.
say() {
  printf '+'
  printf ' %q' "$@"
  printf '\n'
}
run() {
  say "$@"
  if [ "$dry" = 0 ]; then "$@"; fi
}

if command -v shasum >/dev/null 2>&1; then
  sha256() { shasum -a 256 "$@"; }
else
  sha256() { sha256sum "$@"; }
fi

# --- The checks --------------------------------------------------------------------------------------------------

# The file in which flutter_soloud's build hook records the release of the Xiph prebuilds it downloaded.
XIPH_RECORD=flutter_soloud_prebuild_version.txt

version=$(sed -n 's/^version:[[:space:]]*\([^[:space:]#]*\).*$/\1/p' pubspec.yaml | head -n 1)
version_re='^[0-9]+\.[0-9]+\.[0-9]+\+[0-9]+$'
[[ $version =~ $version_re ]] ||
  die "pubspec.yaml's version '$version' isn't X.Y.Z+N (dev-workflow.md \"App identity\")"
name=${version%%+*}

# check_assets <dir> <what> [checkout]: the files under <dir>/assets against ALLOWED_ASSETS and DENIED; with
# "checkout", the RETIRED_ASSETS may be there too (named, not counted).
check_assets() {
  local base=$1 what=$2 checkout=${3:-} f rest pat ok hash path entry problems=0 retired=0
  local files=()
  [ -d "$base/assets" ] || die "$what: no assets/ folder in $base"
  while IFS= read -r f; do files+=("$f"); done < <(cd "$base" && find assets ! -type d | LC_ALL=C sort)
  [ "${#files[@]}" -gt 0 ] || die "$what: no files under $base/assets"
  for f in "${files[@]}"; do
    rest=${f#assets/}
    case $(printf '%s' "$f" | tr '[:upper:]' '[:lower:]') in
      */floors.png) echo "  $f: floors.png never ships (of unknown origin; decisions-log 136)" >&2 ;;
      *raven*) echo "  $f: a Raven Fantasy Icons file (free games only; decisions-log 136)" >&2 ;;
      */.*) echo "  $f: a hidden file (Finder's .DS_Store?), which Flutter would bundle" >&2 ;;
      *)
        ok=0
        if [[ $rest == */* && ${rest#*/} != */* ]]; then
          for pat in "${ALLOWED_ASSETS[@]}"; do
            # shellcheck disable=SC2053 # $pat is a glob on purpose
            if [[ $f == $pat ]]; then
              ok=1
              break
            fi
          done
        fi
        [ "$ok" = 1 ] && continue
        for pat in "${RETIRED_ASSETS[@]}"; do
          [ "$f" = "$pat" ] || continue
          if [ -n "$checkout" ]; then
            ok=1
            retired=$((retired + 1))
          else
            echo "  $f: retired, no build may bundle it (RETIRED_ASSETS in scripts/release-build.sh)" >&2
            ok=2
          fi
          break
        done
        [ "$ok" = 1 ] && continue
        [ "$ok" = 2 ] || echo "  $f: not on the allowlist (docs/itch-page.md \"What a build ships\")" >&2
        ;;
    esac
    problems=$((problems + 1))
  done
  while read -r hash path; do
    path=${path#\*} # sha256sum's binary-mode mark
    for entry in "${DENIED[@]}"; do
      [ "$hash" = "${entry%% *}" ] || continue
      echo "  $path: the same file as the ${entry#* } that never ships (decisions-log 136)" >&2
      problems=$((problems + 1))
    done
  done < <(cd "$base" && sha256 "${files[@]}")
  [ "$problems" = 0 ] ||
    die "$what: $problems file(s) under assets/ must not ship. Take them out of $base/assets (in the main checkout only while the game isn't running: dev-workflow.md \"Traps\") and run this again."
  if [ "$retired" -gt 0 ]; then
    echo "ok: $what: ${#files[@]} files under assets/, all on the allowlist but $retired retired ones no build bundles (delete them while the game is closed: RETIRED_ASSETS)"
  else
    echo "ok: $what: ${#files[@]} files under assets/, all on the allowlist"
  fi
}

echo "Path of Hero $version: $target$([ "$dry" = 1 ] && echo ' (dry run: the checks run, nothing else does)')"
if commit=$(git rev-parse --short HEAD 2>/dev/null); then
  echo "from commit $commit$([ -n "$(git status --porcelain --untracked-files=no)" ] && echo ', with uncommitted changes (a release is built from a commit: warning only)')"
fi
# The pin: pubspec.yaml's hooks: user_defines: flutter_soloud: prebuild_tag, in block style as the file has it.
pin=$(awk '
  /^[[:space:]]*(#|$)/ { next }
  {
    match($0, /^ */)
    indent = RLENGTH
    line = substr($0, indent + 1)
    key = line
    sub(/:.*/, "", key)
    value = line
    if (!sub(/^[^:]*:/, "", value)) value = ""
    sub(/[[:space:]]+#.*$/, "", value)
    gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
    while (n > 0 && indent <= at[n]) n--
    n++
    at[n] = indent
    path[n] = key
    if (n == 4 && path[1] == "hooks" && path[2] == "user_defines" && path[3] == "flutter_soloud" &&
        path[4] == "prebuild_tag") {
      gsub(/^["\047]|["\047]$/, "", value)
      print value
    }
  }' pubspec.yaml)
[ -n "$pin" ] ||
  die "pubspec.yaml doesn't pin flutter_soloud's prebuilt Xiph libraries: without hooks: user_defines: flutter_soloud: prebuild_tag: vX.Y.Z, its build hook links whatever alnitak/flutter_soloud_prebuilds released last (decisions-log 148)"
pin_re='^v[0-9]+\.[0-9]+\.[0-9]+$'
[[ $pin =~ $pin_re ]] ||
  die "pubspec.yaml's prebuild_tag '$(printf '%s' "$pin" | tr '\n' ' ')' isn't one release tag vX.Y.Z, written as GitHub names it (decisions-log 148)"
for f in THIRD_PARTY_NOTICES.txt CREDITS.md; do
  grep -qE "flutter_soloud_prebuilds\)? release ${pin//./\\.}([^0-9.]|\$)" "$f" ||
    die "$f doesn't name the Xiph prebuilds' release $pin that pubspec.yaml pins (THIRD_PARTY_NOTICES.txt: python3 tool/third_party_notices.py; CREDITS.md by hand)"
done
echo "ok: flutter_soloud's Xiph prebuilds pinned to $pin, named in the notices and credits"
[ -f .itch.toml ] || die "no .itch.toml (the itch app's launch actions, at the root of every desktop build)"

# check_xiph <os>: the Xiph prebuilds the build hook linked for <os> (macos, android, linux, windows) are the pinned
# release. The hook keeps them in flutter_soloud's own folder (.dart_tool/flutter_soloud/xiph/prebuild/), with a
# record of their release in each folder it fills: the headers' (include) and the platform's.
check_xiph() {
  local os=$1 config=.dart_tool/package_config.json uri root dir f recorded records=() bad=0
  [ -f "$config" ] || die "no $config, so no flutter_soloud to check (a build's flutter pub get writes it)"
  uri=$(grep -A3 '"name": *"flutter_soloud"' "$config" | sed -n 's/.*"rootUri": *"\([^"]*\)".*/\1/p' | head -n 1)
  [ -n "$uri" ] || die "$config names no flutter_soloud"
  case $uri in
    file://*) root=${uri#file://} ;;
    *) root=.dart_tool/$uri ;; # relative to the package config's folder
  esac
  root=${root//%20/ }
  case $root in /[A-Za-z]:/*) root=${root#/} ;; esac # file:///C:/... on Windows
  dir=$root/.dart_tool/flutter_soloud/xiph/prebuild
  [ -f "$dir/include/$XIPH_RECORD" ] && records+=("$dir/include/$XIPH_RECORD")
  while IFS= read -r f; do records+=("$f"); done < <(find "$dir/$os" -name "$XIPH_RECORD" 2>/dev/null | LC_ALL=C sort)
  [ "${#records[@]}" -ge 2 ] && [ "${records[0]}" = "$dir/include/$XIPH_RECORD" ] ||
    die "flutter_soloud's build hook left no record of the Xiph prebuilds it linked for $os in $dir (include/ and $os/)"
  for f in "${records[@]}"; do
    recorded=$(tr -d '\r\n' < "$f")
    echo "  ${f#"$dir"/}: $recorded"
    [ "$recorded" = "$pin" ] || bad=1
  done
  [ "$bad" = 0 ] ||
    die "the build linked Xiph prebuilds of another release than the pin $pin (in $dir). Delete $dir and build again: the hook downloads the pinned one."
  echo "ok: the build linked the pinned Xiph prebuilds $pin for $os"
}

# check_vault: tool/asset_vault.py check, in a checkout that has the vault's listing (a copy without one says so).
check_vault() {
  local py out
  if [ ! -f tool/asset_vault.json ]; then
    echo "skip: no tool/asset_vault.json here, so no asset vault to check"
    return
  fi
  case $(uname -s) in
    MINGW* | MSYS* | CYGWIN*) py=$(command -v python || command -v python3 || true) ;; # python3 may be the Store's stub
    *) py=$(command -v python3 || command -v python || true) ;;
  esac
  [ -n "$py" ] || die "no python3 to run tool/asset_vault.py check"
  if out=$("$py" tool/asset_vault.py check 2>&1); then
    printf '%s\n' "$out" | sed 's/^/  /'
    echo "ok: the asset vault (tool/asset_vault.py check)"
  else
    printf '%s\n' "$out" | sed 's/^/  /' >&2
    die "the asset vault doesn't hold what a build needs (docs/assets.md \"The asset vault\"): pack it with python3 tool/asset_vault.py pack, or unpack it"
  fi
}

check_assets . "assets/ in $(pwd)" checkout
check_vault
if [ "$target" = check ]; then
  if [ -n "$bundled" ]; then check_assets "$bundled" "the build's assets in $bundled"; fi
  if [ -n "$xiph_os" ]; then check_xiph "$xiph_os"; fi
  echo "checks passed"
  exit 0
fi

# The release signing's key.properties: ANDROID_KEY_PROPERTIES, else this clone's `git config poh.androidKeyProperties`
# (a machine's own setting, never in the repository), else android/key.properties (git-ignored). Exported, so Gradle
# reads the same one (android/app/build.gradle.kts).
key_properties=${ANDROID_KEY_PROPERTIES:-$(git config --get poh.androidKeyProperties 2>/dev/null || echo android/key.properties)}
case $key_properties in "~/"*) key_properties=$HOME/${key_properties#"~/"} ;; /*) ;; *) key_properties=$PWD/$key_properties ;; esac
if [ "$target" != mac ]; then
  # Only whether it exists: Gradle reads it (android/app/build.gradle.kts), and fails on one that doesn't work.
  [ -f "$key_properties" ] ||
    die "Android release signing isn't configured: $key_properties not found (set ANDROID_KEY_PROPERTIES, or git config poh.androidKeyProperties <path>; dev-workflow.md \"Android release signing\"). Without it Gradle signs with the debug key, and a debug-signed APK is never staged (decisions-log 132)."
  echo "ok: Android release signing: $key_properties"
  export ANDROID_KEY_PROPERTIES=$key_properties
fi

if [ -n "${FLUTTER:-}" ]; then
  flutter=$FLUTTER
elif command -v flutter >/dev/null 2>&1; then
  flutter=$(command -v flutter)
else
  flutter=$HOME/development/flutter/bin/flutter
fi
if [ "$dry" = 1 ]; then
  say "$flutter" --version --machine
  echo "  (must be Flutter $FLUTTER_VERSION)"
else
  [ -x "$flutter" ] || die "no flutter at $flutter (set FLUTTER)"
  flutter_version=$("$flutter" --version --machine |
    sed -n 's/.*"frameworkVersion"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n 1)
  [ "$flutter_version" = "$FLUTTER_VERSION" ] ||
    die "$flutter is Flutter '$flutter_version'; a release is built with $FLUTTER_VERSION, as CI is"
  echo "ok: Flutter $flutter_version"
fi

# --- macOS -------------------------------------------------------------------------------------------------------

# check_universal <app>: every Mach-O binary in the app holds arm64 and x86_64 (the page says Apple silicon and
# Intel): the app's, every framework's (the native assets' among them: flutter_soloud_plugin.framework, with the Xiph
# libraries linked in, and objective_c.framework) and every dylib. A framework's binary is its Info.plist's
# CFBundleExecutable (else the framework's name); a declared binary that's missing fails too.
check_universal() {
  local app=$1 fw exe bin archs bad=0
  local bins=("$app/Contents/MacOS/tower_defense")
  while IFS= read -r fw; do
    if exe=$(plutil -extract CFBundleExecutable raw "$fw/Resources/Info.plist" 2>/dev/null) && [ -n "$exe" ]; then
      if [ ! -e "$fw/$exe" ]; then
        echo "  ${fw#"$app"/}: no $exe, its Info.plist's CFBundleExecutable"
        bad=1
        continue
      fi
    else
      exe=$(basename "$fw" .framework)
      [ -e "$fw/$exe" ] || continue # resources only
    fi
    bins+=("$fw/$exe")
  done < <(find "$app/Contents" -name '*.framework' -type d | LC_ALL=C sort)
  while IFS= read -r bin; do bins+=("$bin"); done < <(find "$app/Contents" -name '*.dylib' -type f | LC_ALL=C sort)
  for bin in "${bins[@]}"; do
    archs=$(lipo -archs "$bin" 2>/dev/null) || archs="(not a Mach-O binary)"
    case " $archs " in *" arm64 "*) ;; *) bad=1 ;; esac
    case " $archs " in *" x86_64 "*) ;; *) bad=1 ;; esac
    echo "  ${bin#"$app"/}: $archs"
  done
  [ "$bad" = 0 ] || die "$app isn't universal: every binary above needs both arm64 and x86_64"
  echo "ok: universal (arm64 + x86_64): ${#bins[@]} binaries"
}

staged_mac= staged_android=

build_mac() {
  local app=build/macos/Build/Products/Release/tower_defense.app
  local stage=dist/PathOfHero-mac-$name
  local staged="$stage/Path of Hero.app"
  echo
  echo "== macOS"
  local bundled_assets=$app/Contents/Frameworks/App.framework/Resources/flutter_assets
  run "$flutter" build macos --release "--dart-define=APP_VERSION=$version"
  if [ "$dry" = 1 ]; then
    echo "+ check flutter_soloud's record of the Xiph prebuilds it linked for macos: must be $pin"
    say lipo -archs "$app/Contents/MacOS/tower_defense"
    echo "  (and every framework and dylib: each must hold arm64 and x86_64)"
    echo "+ check the bundled assets: $bundled_assets/assets"
  else
    [ -d "$app" ] || die "the build made no $app"
    check_xiph macos
    check_universal "$app"
    check_assets "$bundled_assets" "the app's bundled assets"
  fi
  run rm -rf "$stage"
  run mkdir -p "$stage"
  run ditto "$app" "$staged"
  say codesign --verify --deep --strict "$staged"
  if [ "$dry" = 0 ] && ! codesign --verify --deep --strict "$staged"; then
    rm -rf "$stage"
    die "the staged app's signature doesn't verify, so nothing is staged"
  fi
  run cp THIRD_PARTY_NOTICES.txt "$stage/THIRD_PARTY_NOTICES.txt"
  run cp CREDITS.md "$stage/CREDITS.txt"
  run cp .itch.toml "$stage/.itch.toml"
  staged_mac=$stage
}

# --- Android -----------------------------------------------------------------------------------------------------

# check_signer <apk>: signed with the release signing key alone, never the debug key.
check_signer() {
  local apk=$1 sdk apksigner= tool out digests digest
  sdk=${ANDROID_HOME:-${ANDROID_SDK_ROOT:-$HOME/Library/Android/sdk}}
  if command -v apksigner >/dev/null 2>&1; then
    apksigner=$(command -v apksigner)
  else
    for tool in "$sdk"/build-tools/*/apksigner; do [ -x "$tool" ] && apksigner=$tool; done
  fi
  [ -n "$apksigner" ] || die "no apksigner (in $sdk/build-tools; set ANDROID_HOME): can't check who signed $apk"
  out=$("$apksigner" verify --print-certs "$apk") ||
    die "$apksigner refused $apk (it needs java on the PATH)"
  if printf '%s\n' "$out" | grep -q 'CN=Android Debug'; then
    die "$apk is signed with the DEBUG key: never stage or upload it (decisions-log 132)"
  fi
  digests=$(printf '%s\n' "$out" | sed -n 's/^Signer #[0-9]* certificate SHA-256 digest:[[:space:]]*//p' |
    tr -d '\r :' | tr '[:upper:]' '[:lower:]')
  [ -n "$digests" ] || die "$apksigner printed no signer for $apk"
  for digest in $digests; do
    [ "$digest" = "$RELEASE_CERT_SHA256" ] ||
      die "$apk is signed by $digest, not the release signing key ($RELEASE_CERT_SHA256)"
  done
  echo "ok: signed with the release signing key (CN=Path of Hero)"
}

# check_16k <apk>: every native library in the APK loads on a phone with 16 KB memory pages (Android 15 and later
# allow them; Google Play requires it): zipalign finds every uncompressed .so aligned to 16 KB in the APK, and each
# 64-bit library's LOAD segments are aligned to 16 KB or more (a 32-bit one is listed only: 16 KB pages are 64-bit).
check_16k() {
  local apk=$1 sdk zipalign= tool out
  sdk=${ANDROID_HOME:-${ANDROID_SDK_ROOT:-$HOME/Library/Android/sdk}}
  for tool in "$sdk"/build-tools/*/zipalign "$(command -v zipalign || true)"; do
    # -P (a page size) came with build-tools 35. zipalign without arguments prints its usage and fails.
    if [ -x "$tool" ] && { "$tool" 2>&1 || true; } | grep -q -- '-P <pagesize_kb>'; then zipalign=$tool; fi
  done
  [ -n "$zipalign" ] ||
    die "no zipalign with -P (Android build-tools 35 or newer, in $sdk/build-tools; set ANDROID_HOME): can't check $apk for 16 KB pages"
  out=$("$zipalign" -c -P 16 -v 4 "$apk" 2>&1) || {
    printf '%s\n' "$out" | grep -E 'BAD|FAIL|rror' >&2 || printf '%s\n' "$out" >&2
    die "$apk: zipalign -c -P 16 failed: a native library isn't aligned for 16 KB pages"
  }
  echo "ok: zipalign -c -P 16: every uncompressed .so in the APK aligned for 16 KB pages"
  python3 - "$apk" <<'PY' || die "$apk: a 64-bit native library isn't aligned for 16 KB pages (above)"
import struct, sys, zipfile

bad = n = 0
with zipfile.ZipFile(sys.argv[1]) as z:
    for name in sorted(z.namelist()):
        if not (name.startswith('lib/') and name.endswith('.so')):
            continue
        data = z.read(name)
        n += 1
        if data[:4] != b'\x7fELF':
            print(f'  {name}: not an ELF file')
            bad += 1
            continue
        is64, end = data[4] == 2, '<' if data[5] == 1 else '>'
        phoff, = struct.unpack_from(end + ('Q' if is64 else 'I'), data, 32 if is64 else 28)
        size, count = struct.unpack_from(end + 'HH', data, 54 if is64 else 42)
        aligns = []
        for i in range(count):
            at = phoff + i * size
            if struct.unpack_from(end + 'I', data, at)[0] == 1:  # PT_LOAD
                aligns += struct.unpack_from(end + ('Q' if is64 else 'I'), data, at + (48 if is64 else 28))
        low = min(aligns, default=0)
        ok = low >= 16384 or not is64
        print(f'  {name}: LOAD segments aligned to {low} bytes' + ('' if is64 else ' (32-bit: 4 KB pages only)')
              + ('' if ok else ' -- BAD, needs 16384'))
        bad += not ok
if n == 0:
    print('  no native library (lib/*/*.so) in the APK')
    sys.exit(1)
sys.exit(1 if bad else 0)
PY
  echo "ok: every 64-bit native library's LOAD segments aligned to 16 KB or more"
}

build_android() {
  local apk=build/app/outputs/flutter-apk/app-release.apk
  local log=build/release-build/android.log
  local stage=dist/PathOfHero-android-$name
  local staged=$stage/PathOfHero-android-$name.apk
  echo
  echo "== Android"
  if [ "$dry" = 1 ]; then
    say env "ANDROID_KEY_PROPERTIES=$key_properties" "$flutter" build apk --release "--dart-define=APP_VERSION=$version"
    echo "  (its output also goes to $log; Gradle's \"no Android release signing key\" warning fails the build)"
    echo "+ check flutter_soloud's record of the Xiph prebuilds it linked for android: must be $pin"
    say apksigner verify --print-certs "$apk"
    echo "  (the only signer must be the release signing key, SHA-256 $RELEASE_CERT_SHA256)"
    say zipalign -c -P 16 -v 4 "$apk"
    echo "  (and every 64-bit native library's LOAD segments aligned to 16 KB: phones with 16 KB pages)"
    echo "+ check the bundled assets: assets/flutter_assets/assets/ inside $apk"
  else
    mkdir -p "$(dirname "$log")"
    rm -f "$apk" # never stage an APK an earlier build left
    say env "ANDROID_KEY_PROPERTIES=$key_properties" "$flutter" build apk --release "--dart-define=APP_VERSION=$version"
    echo "  (its output also goes to $log)"
    ANDROID_KEY_PROPERTIES=$key_properties "$flutter" build apk --release "--dart-define=APP_VERSION=$version" 2>&1 |
      tee "$log"
    if grep -q 'no Android release signing key' "$log"; then
      die "Gradle found no release signing key and signed with the debug key (see $log)"
    fi
    [ -f "$apk" ] || die "the build made no $apk"
    check_xiph android
    check_signer "$apk"
    check_16k "$apk"
    local unpacked=build/release-build/apk
    rm -rf "$unpacked"
    unzip -q "$apk" 'assets/flutter_assets/assets/*' -d "$unpacked" || die "no assets in $apk"
    check_assets "$unpacked/assets/flutter_assets" "the APK's bundled assets"
  fi
  run rm -rf "$stage"
  run mkdir -p "$stage"
  run cp "$apk" "$staged"
  staged_android=$stage
}

case $target in
  mac) build_mac ;;
  android) build_android ;;
  all)
    build_mac
    build_android
    ;;
esac

# --- What the owner runs next ------------------------------------------------------------------------------------

push_steps() { # <folder> <channel>
  echo "  butler push --dry-run $1 $ITCH_TARGET:$2 --userversion $version"
  echo "  butler push $1 $ITCH_TARGET:$2 --userversion $version --if-changed"
}

echo
if [ "$dry" = 1 ]; then echo "Would stage (nothing was built, written or pushed):"; else echo "Staged (nothing was pushed):"; fi
[ -z "$staged_mac" ] || echo "  $staged_mac/  (Path of Hero.app, THIRD_PARTY_NOTICES.txt, CREDITS.txt, .itch.toml)"
[ -z "$staged_android" ] || echo "  $staged_android/  (PathOfHero-android-$name.apk alone)"
echo
echo "To publish (the owner, from this folder; docs/itch-page.md \"Pushing builds\"). butler takes the key from"
echo "BUTLER_API_KEY, which you set yourself; never run 'butler login'. First the dry run, which lists the files"
echo "it would send, then the push:"
[ -z "$staged_mac" ] || push_steps "$staged_mac" mac
[ -z "$staged_android" ] || push_steps "$staged_android" android
echo "  butler status $ITCH_TARGET"
if [ -n "${BUTLER_API_KEY:-}" ]; then
  echo "(BUTLER_API_KEY is set in this shell.)"
else
  echo "(BUTLER_API_KEY isn't set in this shell.)"
fi
