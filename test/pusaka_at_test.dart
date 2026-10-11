// The one read of a Pusaka's numbers by stars (catalog step 0a, Ukir's U1; lib/pusaka.dart): [pusakaAt] and
// [pusakaCountAt] give exactly the tables' numbers at every star, and nothing else in lib/ reads a number by stars from
// the tables, so a later step (Ukir) changes it in one place. Since the catalog (step 0b) the accessor reads the
// tables through [pusakaCatalog]'s rows, so the rows' definition is the one place that names them.
// docs/loot-items-relics.md, "Pusaka".
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';

/// Every field the accessor reads (through the catalog's rows): the numbers by stars, and the two Ukir will move (God's
/// Thunder's share, Dragon Crown's cap). Nothing in lib/ outside the rows names them (but their definitions and
/// comments).
const _accessorOnly = [
  'dragonHeartK.hp',
  'dawnStarK.power',
  'godThunderK.jumps',
  'godThunderK.share',
  'grailK.hpLeft',
  'voidEyeK.taken',
  'voidEyeK.boss',
  'ironBannerK',
  'bloodFangK',
  'warDrumK.hit',
  'mourningBellK.heal',
  'crownCap',
  // Batch L-1P (decisions-log 205).
  'titanBaneK',
  'finishingBladeK.hit',
  'firstCutK.hit',
  'shellCrackerK',
  'twinFuryK',
  'steadyStanceK.cut',
  'turtleShellK.cut',
  'dullingMailK.dealt',
  'challengeLetterK.time',
  'snareCordK.slow',
  // Batch L-2P (decisions-log 207).
  'momentumK',
  'bleedingEdgeK.share',
  'shatterShardK.share',
  'painCrystalK.mp',
  'watchShieldK',
  'boneBucklerK.add',
  'riposteK.share',
  'manaLeechK.mp',
  'lootersPouchK',
  'spellCutterK.cd',
  // Batch L-3 (decisions-log 209).
  'saltCharmK.cd',
  'wolfFeastK',
  'fullCupK.share',
  'hiddenFlaskK.heal',
  'livingMossK.regen',
  'pureWaterK.cd',
  // Batch E-1P (decisions-log 211).
  'healerBaneK',
  'bullyClubK',
  'unityRingK.hit',
  'runeGauntletK.might',
  'hawkFeatherK.range',
  'witherrootK.dealt',
  'witherrootK.boss',
  'arrowCatcherK',
  'stoneCoatK.def',
  'heroCloakK',
  'moonwellK.mpRegen',
  // Batch E-2P (decisions-log 214).
  'emberBrandK.hit',
  'funeralPyreK.share',
  'nullStoneK.cd',
  'fallenFlagK.might',
  'aegisSealK',
  'wardensHornK.time',
  'anchorK.speed',
  // Batch G-1P (decisions-log 231): one number each, Carve's step beside it (ukirPerStar).
  'loneWolfK.power',
  'martyrFlameK.share',
  'martyrFlameK.hp',
  'wideBlowsK.splash',
  'wideBlowsK.dmg',
  'championK.hero',
  'championK.rest',
  'vengeanceK.taken',
  'vengeanceK.boss',
  'vengeanceK.selfTaken',
  'mirrorK.share',
  'mirrorK.dmg',
  'ghostStepK.dmg',
  'iceGripK.hold',
  'iceGripK.bossSlow',
  'iceGripK.dmg',
  'relicAltarK.k',
  'relicAltarK.hp',
  'vowSilenceK.k',
  // Batch G-2 (decisions-log 238): the same.
  'rageTotemK.power',
  'rageTotemK.healIn',
  'guardianChainK.share',
  'phalanxK.cut',
  'phalanxK.dmg',
  'phoenixK.hpLeft',
  'phoenixK.hp',
  'soulShelterK.time',
  'soulShelterK.dmg',
  'manaFontK.share',
  'manaFontK.mpRegen',
  'hexBladeK.time',
  'hexBladeK.dmg',
  'glorySeekerK.might',
  'glorySeekerK.dmg',
];

/// [line] without its comment (from `//` on; a `//` inside a string ends it too early, which only hides more).
String _code(String line) {
  final at = line.indexOf('//');
  return at < 0 ? line : line.substring(0, at);
}

/// The lines of [lines] that are the body of the top-level declaration [signature] (up to its closing [end]).
Set<int> _body(List<String> lines, String signature, [String end = '}']) {
  final from = lines.indexWhere((l) => l.startsWith(signature));
  expect(from, isNot(-1), reason: '$signature not found');
  final to = lines.indexWhere((l) => l == end, from);
  return {for (var i = from; i <= to; i++) i};
}

void main() {
  test('pusakaAt is every table at every star, exactly; pusakaCountAt the whole numbers', () {
    for (final s in [1, 2, 3]) {
      final i = s - 1;
      expect(pusakaAt(Relic.dragonHeart, s), dragonHeartK.hp[i]);
      expect(pusakaAt(Relic.dawnStar, s), dawnStarK.power[i]);
      expect(pusakaAt(Relic.godThunder, s), godThunderK.share);
      expect(pusakaCountAt(Relic.godThunder, s), godThunderK.jumps[i]);
      expect(pusakaAt(Relic.grail, s), grailK.hpLeft[i]);
      expect(pusakaAt(Relic.voidEye, s), voidEyeK.taken[i]);
      expect(pusakaAt(Relic.voidEye, s, boss: true), voidEyeK.boss[i]);
      expect(pusakaAt(Relic.ironBanner, s), ironBannerK[i]);
      expect(pusakaAt(Relic.bloodFang, s), bloodFangK[i]);
      expect(pusakaAt(Relic.warDrum, s), warDrumK.hit[i]);
      expect(pusakaAt(Relic.mourningBell, s), mourningBellK.heal[i]);
      expect(pusakaAt(Relic.dragonCrown, s), crownCap);
    }
  });

  test('only a row whose Fx names one has a number on the boss; stars clamp to ★1-★3; a relic with no number by stars '
      'throws', () {
    final boss = [for (final MapEntry(key: r, value: a) in pusakaCatalog.entries) if (a.fx.firstOrNull?.boss != null) r];
    expect(boss, [
      Relic.voidEye, Relic.dullingMail, Relic.challengeLetter, Relic.snareCord, Relic.witherroot, Relic.wardensHorn, //
      Relic.vengeance, Relic.iceGrip,
    ]);
    expect(pusakaAt(Relic.wardensHorn, 2, boss: true), 0, reason: 'its taunt: none on the boss');
    for (final r in [for (final r in Relic.values) if (r.pusaka && !r.oath) r]) {
      // Its first Fx's number, or (Anchor's stand and Ghost Step's miss have none) its first with one: the trade.
      final i = pusakaCatalog[r]!.fx.indexWhere((f) => f.k.isNotEmpty);
      for (final s in [1, 2, 3]) {
        if (!boss.contains(r)) expect(pusakaAt(r, s, boss: true, fx: i), pusakaAt(r, s, fx: i), reason: '$r ★$s');
      }
      expect((pusakaAt(r, 0, fx: i), pusakaAt(r, 4, fx: i)), (pusakaAt(r, 1, fx: i), pusakaAt(r, starMax, fx: i)), reason: '$r');
    }
    expect(() => pusakaAt(Relic.anchor, 1), throwsArgumentError, reason: 'its stand has no number by stars');
    expect(pusakaAt(Relic.anchor, 2, fx: 1), anchorK.speed[1]);
    expect((pusakaCountAt(Relic.godThunder, 0), pusakaCountAt(Relic.godThunder, 9)), (godThunderK.jumps.first, godThunderK.jumps.last));
    for (final r in [Relic.oathOfOne, Relic.alliance, Relic.fang, Relic.thorns, Relic.fury, Relic.guard]) {
      expect(() => pusakaAt(r, 1), throwsArgumentError, reason: '$r');
    }
    expect(() => pusakaCountAt(Relic.dragonHeart, 1), throwsArgumentError);
  });

  test('no number by stars is read in lib/ but through pusakaAt / pusakaCountAt', () {
    final pusaka = File('lib/pusaka.dart').readAsLinesSync(), catalog = File('lib/pusaka_catalog.dart').readAsLinesSync();
    final accessor = {..._body(pusaka, 'double pusakaAt('), ..._body(pusaka, 'int pusakaCountAt(')};
    final rows = _body(catalog, 'final pusakaCatalog = ', '};');
    final rowsCode = [for (final i in rows) _code(catalog[i])].join('\n');
    String name(String field) => field.replaceAll('.', r'\.');
    for (final f in _accessorOnly) {
      expect(RegExp('\\b${name(f)}\\b').hasMatch(rowsCode), isTrue, reason: 'a row names $f');
    }
    final accessorCode = [for (final i in accessor) _code(pusaka[i])].join('\n');
    expect(accessorCode, contains('pusakaCatalog[relic]'), reason: 'the accessor reads the rows');
    // Every table of a Pusaka's numbers (a `*K` constant in pusaka.dart, draft.dart or pusaka_catalog.dart, the ones to
    // come too): indexed nowhere but in the accessor.
    final tables = <String>{
      for (final file in ['lib/pusaka.dart', 'lib/draft.dart', 'lib/pusaka_catalog.dart'])
        for (final m in RegExp(r'^const (\w+K) =', multiLine: true).allMatches(File(file).readAsStringSync())) m[1]!,
    };
    expect(tables, containsAll(['dragonHeartK', 'grailK', 'voidEyeK', 'ironBannerK', 'warDrumK', 'mourningBellK']));
    final named = RegExp('\\b(${_accessorOnly.map(name).join('|')})\\b');
    final indexed = RegExp('\\b(${tables.join('|')})(\\.\\w+)?\\s*\\[');
    final definition = RegExp(r'^const \w+ =');
    final offenders = <String>[];
    for (final file in Directory('lib').listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'))) {
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (file.path.endsWith('lib/pusaka.dart') && accessor.contains(i)) continue;
        if (file.path.endsWith('lib/pusaka_catalog.dart') && rows.contains(i)) continue; // the rows name their tables
        final code = _code(lines[i]);
        if (definition.hasMatch(code)) continue;
        if (named.hasMatch(code) || indexed.hasMatch(code)) offenders.add('${file.path}:${i + 1}: ${lines[i].trim()}');
      }
    }
    expect(offenders, isEmpty, reason: 'read these through pusakaAt / pusakaCountAt (lib/pusaka.dart)');
  });
}
