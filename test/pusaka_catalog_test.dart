// The Pusaka catalog and its engine (catalog step 0b, decisions-log 178; lib/pusaka_catalog.dart, lib/pusaka_engine.dart):
// the rules every row must keep, so a data batch adds rows without touching a test that lists them. The band (no row
// past today's ranges), the key (no two rows lead with the same Fx), the icons (its own cell of the Artifacts' atlas,
// lib/artifact_icons.dart, in the order tool/import_fx.py writes it), the counters (a Bayangan kind of the row's
// own pool), what is built (a row waits for its batch), the templates, the books (rebuilt on every change) and no dice.
// docs/loot-items-relics.md, "The Pusaka catalog and its engine".
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';

import 'hero_skill_helpers.dart';

/// Today's twelve, the rows step 0b moved onto the engine with no change.
const today = [
  Relic.dragonHeart, Relic.dawnStar, Relic.godThunder, Relic.grail, Relic.voidEye, // the Epik
  Relic.ironBanner, Relic.bloodFang, Relic.warDrum, Relic.mourningBell, // the Langka
  Relic.dragonCrown, Relic.oathOfOne, Relic.alliance, // the Legenda
];

/// Each of today's twelve's counter, as the Bayangan design pairs them (enemy-buff-design.md §2's table; the Grail's and
/// Dragon Heart's catalog-bayangan-v2 §4's since the Epik cut-over, decisions-log 223).
const todayCounters = {
  Relic.ironBanner: OmenKind.haste,
  Relic.bloodFang: OmenKind.wound,
  Relic.warDrum: OmenKind.thorns,
  Relic.mourningBell: OmenKind.wound,
  Relic.grail: OmenKind.prey,
  Relic.dragonHeart: OmenKind.wearDown,
  Relic.voidEye: OmenKind.armor,
  Relic.godThunder: OmenKind.mend,
  Relic.dawnStar: OmenKind.armor,
  Relic.dragonCrown: OmenKind.shield,
  Relic.oathOfOne: OmenKind.guard,
  Relic.alliance: OmenKind.guard,
};

/// [file]'s lines without their comments.
String code(String file) => [for (final l in File(file).readAsLinesSync()) l.contains('//') ? l.substring(0, l.indexOf('//')) : l].join('\n');

/// A PNG's width and height (its IHDR).
(int, int) pngSize(String path) {
  final b = File(path).readAsBytesSync();
  int at(int i) => b[i] << 24 | b[i + 1] << 16 | b[i + 2] << 8 | b[i + 3];
  return (at(16), at(20));
}

void main() {
  final rows = pusakaCatalog.entries.toList();

  test('every Pusaka has a row and every row is a Pusaka; an oath\'s holds no Fx (bespoke), another 1 or 2', () {
    expect({for (final r in Relic.values) if (r.pusaka) r}, pusakaCatalog.keys.toSet());
    expect(pusakaCatalog.keys.toList(), [for (final r in Relic.values) if (r.pusaka) r], reason: 'in Relic order');
    for (final MapEntry(key: r, value: art) in rows) {
      expect(art.fx.length, r.oath ? 0 : inInclusiveRange(1, 2), reason: '$r');
      expect((art.role == null, art.epithet == null), (r.oath, r.oath), reason: '$r: an oath takes no Ukir, names no type');
      expect(r.rarity, art.rarity, reason: '$r');
    }
    expect(today, everyElement(predicate((Relic r) => pusakaCatalog[r]!.live)), reason: "today's are in the game");
    expect([for (final r in Relic.values) if (r.store) r], [Relic.dragonHeart, Relic.dawnStar, Relic.godThunder, Relic.grail, Relic.voidEye]);
  });

  test('every row is built (its trigger, effect and condition run in the engine), and its templates render at every star', () {
    for (final MapEntry(key: r, value: art) in rows) {
      for (final fx in art.fx) {
        expect(fxBuilt(fx), isTrue, reason: '$r: ${fx.on.name} → ${fx.eff.name} waits for its batch');
        expect(fx.when == null || fxIfsBuilt.contains(fx.when), isTrue, reason: '$r: ${fx.when} waits for its batch');
        expect(fx.on, isNot(Trig.army), reason: '$r: an oath is bespoke');
        expect(fx.k.length, anyOf(0, 1, starMax), reason: '$r: one number, or one a star');
        expect(fx.count.length, anyOf(0, 1, starMax), reason: '$r');
      }
      if (r.oath) continue;
      for (var s = 1; s <= starMax; s++) {
        expect(fxLines(r, s), isNotEmpty, reason: '$r ★$s');
        expect(fxGist(r, s), isNotEmpty, reason: '$r ★$s');
      }
    }
    // A row that came before its batch is refused, not run: an unbuilt Fx, and a condition.
    expect(fxBuilt(const Fx(Trig.kill, Eff.heal, To.nearTroops, k: [0.04])), isFalse);
    expect(fxBuilt(const Fx(Trig.always, Eff.stat, To.type, stat: Stat.mp, k: [1.1])), isFalse);
    // Batch E-2P's rows (pusaka_epik2_test.dart) add no condition: Warden's Horn's is L-1P's melee.
    // The conditions step 0f built (fx_hooks_test.dart), batch L-1P's (pusaka_langka1_test.dart), L-2P's
    // (pusaka_langka2_test.dart), L-3's (pusaka_langka3_test.dart), E-1P's (pusaka_epik1_test.dart), G-1P's
    // (pusaka_legenda1_test.dart) and G-2's (pusaka_legenda2_test.dart); each other waits for its batch.
    expect(fxIfsBuilt, {
      If.hpBelow, If.hpAbove, If.foeHpBelow, If.foeHpAbove, If.alliesNear, If.firstOfTypeThisWave, //
      If.vsBoss, If.foeShielded, If.melee, If.holds, If.attackerMelee, If.healPastFull, //
      If.foeHealer, If.foeHeld, If.typesAlive, If.attackerRanged, If.hero, If.fewOfType, If.notHero, If.foeHighElite,
    });
    expect(fxIfsBuilt.contains(If.attackerVsBoss), isFalse);
  });

  test('the band: no Fx gives more than today\'s range for its rarity (a condition or a trade a quarter more); an every-Nth '
      'power at most War Drum\'s', () {
    var measured = 0;
    for (final MapEntry(key: r, value: art) in rows) {
      if (r.oath || art.rarity == Rarity.legenda) continue; // a Legenda: a rule and a real cost instead
      final trade = art.fx.any((f) => f.eff == Eff.stat && f.k.isNotEmpty && f.k.every((k) => k < 1));
      for (var i = 0; i < art.fx.length; i++) {
        final fx = art.fx[i];
        for (var s = 1; s <= starMax; s++) {
          if (fx.k.isEmpty) continue;
          final k = pusakaAt(r, s, fx: i), count = fx.count.isEmpty ? 1 : pusakaCountAt(r, s, fx: i);
          if ((fx.eff == Eff.power || fx.eff == Eff.mark) && fx.every > 1) {
            expect(k, lessThanOrEqualTo(perProcMax[s - 1]), reason: '$r ★$s: per proc');
          }
          final gain = fxGain(fx, k, count);
          if (gain == null) continue;
          final (band, got) = gain;
          final range = fxBand[band]?[art.rarity];
          expect(range, isNotNull, reason: '$r: no ${band.name} band for ${art.rarity.name}: add one, or exempt it');
          var most = range![s - 1];
          if (fx.when != null && !hardConds.contains(fx.when)) most *= condBonus;
          if (trade) most *= tradeBonus;
          expect(got, lessThanOrEqualTo(most + 0.005), reason: '$r ★$s: ${band.name} $got over $most'); // the band's two decimals
          measured++;
        }
      }
    }
    expect(measured, greaterThanOrEqualTo(9 * starMax), reason: "today's nine below Legenda are measured");
    // A new Legenda (not an oath) pays for its rule: a condition, or a trade (a number under 1, a cut under 0: more
    // taken; or no skills: Vow of Silence's gate; or the hits it takes: Guardian Chain's link, its share under 1).
    var legenda = 0;
    for (final MapEntry(key: r, value: art) in rows) {
      if (r.oath || art.rarity != Rarity.legenda || today.contains(r)) continue;
      legenda++;
      expect(art.fx.any((f) => f.when != null || f.eff == Eff.skillGate || (f.k.isNotEmpty && f.k.every((k) => k < 1))), isTrue,
          reason: '$r');
    }
    expect(legenda, greaterThanOrEqualTo(18), reason: "batch G-1P's ten, G-2's eight");
  });

  test('the key: no two rows lead with the same Fx (trigger, condition, effect with its stat or status, target)', () {
    final seen = <Object, Relic>{};
    for (final MapEntry(key: r, value: art) in rows) {
      if (art.fx.isEmpty) continue;
      final key = art.fx.first.key;
      expect(seen[key], isNull, reason: '$r leads with ${seen[key]}\'s Fx $key');
      seen[key] = r;
    }
    expect(seen.length, rows.where((e) => !e.key.oath).length);
  });

  test('the icons: its own cell of the Artifacts\' atlas, untinted; the atlas holds the catalog\'s 90 kinds once each, '
      'in tool/import_fx.py\'s order', () {
    expect(artifactIconKinds.length, 90, reason: '30 a tier');
    expect(artifactIconKinds.toSet().length, artifactIconKinds.length, reason: 'a kind twice');
    expect(pngSize('assets/images/artifact_icons.png'), (artifactIconCols * 32, (artifactIconKinds.length / artifactIconCols).ceil() * 32));
    final tool = File('tool/import_fx.py').readAsStringSync();
    final written = tool.substring(tool.indexOf('ARTIFACTS = ['), tool.indexOf('\n]', tool.indexOf('ARTIFACTS = [')));
    expect([for (final m in RegExp(r'^    \("(\w+)", "[\w&]+", \d+\),', multiLine: true).allMatches(written)) m[1]], artifactIconKinds,
        reason: 'the atlas is written in this order');
    for (final MapEntry(key: r, value: art) in rows) {
      final icon = art.icon, own = artifactIcon(r.name);
      expect((icon.sheet, icon.x, icon.y, icon.size, icon.tint), (own.sheet, own.x, own.y, 32, null), reason: '$r: not its own cell');
    }
    expect(() => artifactIcon('nothing'), throwsArgumentError);
    expect(relicIcon(Relic.fang).sheet, 'relic_fang.png', reason: 'a small relic keeps its own file');
  });

  test('the counters: a Bayangan kind of the row\'s own pool; today\'s as the Bayangan design pairs them; only an attack '
      'stat that heals on a healer names a second', () {
    for (final MapEntry(key: r, value: art) in rows) {
      expect(art.counter.tiers, contains(art.rarity), reason: '$r: ${art.counter} is not in the ${art.rarity.name} pool');
      if (art.healerCounter case final h?) {
        expect(h.tiers, contains(art.rarity), reason: '$r');
        expect(art.fx.first, isA<Fx>().having((f) => (f.on, f.eff, f.stat), 'its lead', (Trig.always, Eff.stat, Stat.dmg)), reason: '$r');
      }
    }
    expect({for (final r in today) r: pusakaCatalog[r]!.counter}, todayCounters);
    expect([for (final MapEntry(key: r, value: a) in rows) if (a.healerCounter != null) (r, a.healerCounter)], [(Relic.dawnStar, OmenKind.healSiphon)]);
  });

  test('the counter families: today\'s twelve count what their first Fx does', () {
    expect({for (final r in today) r: fxFamily(r)}, {
      Relic.dragonHeart: FxFamily.survived,
      Relic.dawnStar: FxFamily.added,
      Relic.godThunder: FxFamily.added,
      Relic.grail: FxFamily.saves,
      Relic.voidEye: FxFamily.added,
      Relic.ironBanner: FxFamily.keptOff,
      Relic.bloodFang: FxFamily.healed,
      Relic.warDrum: FxFamily.added,
      Relic.mourningBell: FxFamily.healed,
      Relic.dragonCrown: FxFamily.keptOff,
      Relic.oathOfOne: null,
      Relic.alliance: null,
    });
    expect(fxMarks.first, (Status.voidMark, Relic.voidEye), reason: "today's one (batch G-1P's Vengeance Mark follows)");
    expect([for (final r in today) if (fxRaisesHp(r)) r], [Relic.dragonHeart]);
  });

  test('the books: a change to a Pusaka owned works at once, however it is made (bind, star, the map, a direct field)', () {
    final g = bareGame();
    placeNow(g, 'knight', 2, 3);
    final base = g.statsOf('knight').hp;
    int hp() => g.statsOf('knight').hp;
    g.givePusaka(Relic.dragonHeart, type: 'knight');
    expect(hp(), (base * dragonHeartK.hp[0]).round());
    g.pusaka[Relic.dragonHeart]!.stars = 3; // a direct field
    expect(hp(), (base * dragonHeartK.hp[2]).round());
    g.pusaka[Relic.dragonHeart]!.type = null; // to the Gudang by hand
    expect(hp(), base);
    g.pusaka.remove(Relic.dragonHeart);
    g.pusaka[Relic.dragonHeart] = OwnedPusaka(type: 'knight', stars: 2); // the map
    expect(hp(), (base * dragonHeartK.hp[1]).round());
    g.pusaka.clear();
    expect(hp(), base);
    // Another game's change only rebuilds this one's book: the same numbers.
    final other = bareGame()..givePusaka(Relic.dawnStar, type: 'knight');
    expect((hp(), other.statsOf('knight').dmg), (base, troopTypes['knight']!.dmg * dawnStarK.power[0]));
  });

  test('no die is drawn: the engine and the catalog name no dice', () {
    for (final file in ['lib/pusaka_engine.dart', 'lib/pusaka_catalog.dart']) {
      final src = code(file);
      expect(RegExp(r'\b(rng|loot|slots|draft|names|heroes|omenDice)\s*\.\s*next|\bRandom\s*\(').hasMatch(src), isFalse, reason: file);
    }
  });

  test('the owner\'s defaults are one constant each: new Epik stay out of the Toko, the texts may say skill and MP', () {
    expect((newEpikStore, fxWords.skill, fxWords.mp), (false, 'skill', 'MP'));
    expect(OmenKind.values.where((k) => k.tiers.length == 3), isEmpty,
        reason: "today's seven sat in every pool until their cut-overs; Langka's took out Armor, Mend, Barrier and Escort, "
            "Epik's Haste, Spikes, Wound, Barrier and Escort");
  });
}
