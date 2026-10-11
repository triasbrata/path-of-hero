#!/usr/bin/env python3
"""Writes THIRD_PARTY_NOTICES.txt (decisions-log 137, docs/assets.md "Licence files").

Part 1: every Dart package the game depends on (pubspec.yaml's dependencies and what they need, versions from
pubspec.lock), with its LICENSE file from the pub cache or the Flutter SDK; packages with the same text share one
entry. Part 2: the native libraries inside flutter_soloud, taken from lib/licences.dart's `nativeLicences` (the same
texts the game adds to its Lisensi page), and the Xiph prebuilds' release that pubspec.yaml pins (decisions-log 148).
Part 3: the game's font, Poh Sans (Pixelify Sans with 13 glyphs redrawn), with its licence file (`FONTS`;
lib/licences.dart's `fontLicences` registers the same file, decisions-log 158 and 179). Rerun it after a dependency,
the pin or the font changes:

    python3 tool/third_party_notices.py

Stdlib only. Reads ~/.pub-cache and the Flutter SDK (FLUTTER_ROOT, default ~/development/flutter); `pub get` first.
"""
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PUB_CACHE = os.environ.get('PUB_CACHE', os.path.expanduser('~/.pub-cache'))
FLUTTER = os.environ.get('FLUTTER_ROOT', os.path.expanduser('~/development/flutter'))
SEP = '-' * 80
# The game's font: the name on the Lisensi page, the file, the licence file (lib/hud_font.dart, lib/licences.dart).
FONTS = [
    ('Poh Sans', 'assets/fonts/PohSans.ttf', 'assets/fonts/OFL-PohSans.txt'),
]


def lock_packages():
    """pubspec.lock: name -> (source, version)."""
    out, name, source = {}, None, None
    for line in open(os.path.join(ROOT, 'pubspec.lock'), encoding='utf-8'):
        if m := re.match(r'^  (\w+):$', line):
            name, source = m.group(1), None
        elif m := re.match(r'^    source: (\w+)', line):
            source = m.group(1)
        elif (m := re.match(r'^    version: "(.+)"', line)) and name:
            out[name] = (source, m.group(1))
    return out


def dependencies(pubspec):
    """The names under a pubspec.yaml's top-level `dependencies:`."""
    names, inside = [], False
    for line in open(pubspec, encoding='utf-8'):
        if re.match(r'^\S', line):
            inside = line.startswith('dependencies:')
        elif inside and (m := re.match(r'^  (\w+):', line)):
            names.append(m.group(1))
    return names


def package_dir(name, source, version):
    if source == 'hosted':
        return os.path.join(PUB_CACHE, 'hosted', 'pub.dev', f'{name}-{version}')
    return {'flutter': os.path.join(FLUTTER, 'packages', 'flutter'),
            'sky_engine': os.path.join(FLUTTER, 'bin', 'cache', 'pkg', 'sky_engine')}.get(name)


def kind(text):
    if 'Apache License' in text:
        return 'Apache-2.0'
    if 'Permission is hereby granted' in text:
        return 'MIT'
    if 'Redistribution and use' in text:
        return 'BSD-3-Clause'
    return 'see its entry'


def prebuild_tag():
    """pubspec.yaml's `hooks: user_defines: flutter_soloud: prebuild_tag:`, the Xiph prebuilds' release."""
    path, tag = [], None
    for line in open(os.path.join(ROOT, 'pubspec.yaml'), encoding='utf-8'):
        if not line.strip() or line.lstrip().startswith('#'):
            continue
        indent = len(line) - len(line.lstrip(' '))
        key, _, value = line.strip().partition(':')
        path = [(i, k) for i, k in path if i < indent] + [(indent, key)]
        if [k for _, k in path] == ['hooks', 'user_defines', 'flutter_soloud', 'prebuild_tag']:
            tag = value.split(' #')[0].strip().strip('\'"')
    if not tag:
        sys.exit('pubspec.yaml pins no prebuild_tag for flutter_soloud (decisions-log 148)')
    return tag


def native_licences():
    """lib/licences.dart's `nativeLicences`: ([package, ...], text) for each `(['a', 'b'], r'''...''')`."""
    dart = open(os.path.join(ROOT, 'lib', 'licences.dart'), encoding='utf-8').read()
    block = dart[dart.index('const nativeLicences'):]
    return [([p.strip().strip("'") for p in names.split(',')], text)
            for names, text in re.findall(r"\(\[([^\]]*)\], r'''\n(.*?)'''\)", block, re.S)]


def main():
    lock = lock_packages()
    seen, order = set(), []

    def walk(name):
        if name in seen or name not in lock:
            return
        seen.add(name)
        order.append(name)
        d = package_dir(name, *lock[name])
        if d is None or not os.path.exists(os.path.join(d, 'pubspec.yaml')):
            sys.exit(f'no pubspec.yaml for {name} ({d}): run flutter pub get first')
        for dep in dependencies(os.path.join(d, 'pubspec.yaml')):
            walk(dep)

    for name in dependencies(os.path.join(ROOT, 'pubspec.yaml')):
        walk(name)
    order.sort(key=str.lower)

    texts = {}  # licence text -> the packages that have it
    for name in order:
        if name == 'sky_engine':
            continue  # the engine's 1.2 MB of notices: the build's NOTICES has them
        d = package_dir(name, *lock[name])
        lic = sorted(f for f in os.listdir(d) if f.upper().startswith('LICENSE'))
        if not lic:
            sys.exit(f'{name}: no LICENSE file in {d}')
        text = open(os.path.join(d, lic[0]), encoding='utf-8').read().strip('﻿\n ').rstrip()
        texts.setdefault(text, []).append(name)

    version_file = os.path.join(FLUTTER, 'bin', 'cache', 'flutter.version.json')
    flutter_version = json.load(open(version_file))['frameworkVersion'] if os.path.exists(version_file) else 'SDK'
    rows = []
    for name in order:
        source, version = lock[name]
        if name == 'sky_engine':
            rows.append(f'  {"sky_engine (the Flutter engine)":38} {flutter_version:14} its own notices, in the NOTICES of every build')
            continue
        text = next(t for t, names in texts.items() if name in names)
        rows.append(f'  {name:38} {version if source == "hosted" else flutter_version:14} {kind(text)}')
    soloud = lock['flutter_soloud'][1]
    tag = prebuild_tag()
    (font, font_file, font_licence), = FONTS
    head = f'''THIRD-PARTY NOTICES FOR PATH OF HERO

Path of Hero (Copyright (c) 2026 Trias BYM) is built with the software below, which stays under its own licence. The
game's own licence is in LICENSE, and the credits for its art and audio are in CREDITS.md.

Every build of the game also carries Flutter's own notices (the NOTICES file Flutter builds in): the licence of every
Dart package and of the Flutter engine's own third-party code (Skia, ICU, HarfBuzz and about 130 more). In the game,
"Lisensi" on the book's Pengaturan page shows them, together with the libraries of part 2.

Part 1: the Dart packages the game depends on (pubspec.yaml's dependencies and what they need, at the versions in
pubspec.lock), each with its LICENSE file. The Flutter engine's notices (Flutter's sky_engine/LICENSE, about
1.2 MB) are in every build's NOTICES and are not repeated here.
Part 2: the native libraries that flutter_soloud {soloud} compiles into the game's sound library: SoLoud and the code
inside it, miniaudio, pffft, Signalsmith's DSP headers, and the prebuilt Xiph libraries (libogg, libvorbis with
vorbisfile and vorbisenc, libopus, libFLAC). No package's LICENSE file carries their notices, so Flutter's NOTICES
lacks them; the game adds them to its licence page (lib/licences.dart).
The Xiph libraries are the binaries of alnitak/flutter_soloud_prebuilds release {tag} on GitHub. pubspec.yaml pins
that release (hooks: user_defines: flutter_soloud: prebuild_tag), so every build links the same ones.
Part 3: the game's font, {font} ({font_file}), a Modified Version of Pixelify Sans from Google Fonts
(google/fonts, ofl/pixelifysans) under the same SIL Open Font License 1.1: its 2, 3, 5, 6, 9, B, C, G, S, Z, a, c and i
redrawn, which tool/make_poh_sans.py writes from the original. Its licence file ({font_licence}) ships
inside every build, and the game shows it on the Lisensi page too.

Each entry: the names it covers, a blank line, the licence text, then a line of dashes. Written by
tool/third_party_notices.py; rerun it after a dependency, the pin or a font changes.

Dart packages (part 1):
'''
    out = [head + '\n'.join(rows) + '\n', SEP, '', 'PART 1. DART PACKAGES', '', SEP]
    for text, names in texts.items():
        out += ['\n'.join(names), '', text, SEP]
    out += ['', f'PART 2. NATIVE LIBRARIES INSIDE FLUTTER_SOLOUD {soloud}', '', SEP]
    for names, text in native_licences():
        out += ['\n'.join(names), '', text, SEP]
    out += ['', 'PART 3. THE FONTS', '', SEP]
    for font, _, font_licence in FONTS:
        text = open(os.path.join(ROOT, font_licence), encoding='utf-8').read().strip('\ufeff\n ').rstrip()
        out += [font, '', text, SEP]
    path = os.path.join(ROOT, 'THIRD_PARTY_NOTICES.txt')
    open(path, 'w', encoding='utf-8').write('\n'.join(out) + '\n')
    print(f'{path}: {len(order)} packages ({len(texts)} texts), {len(native_licences())} native entries')


if __name__ == '__main__':
    main()
