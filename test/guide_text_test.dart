// The first-time guide's words (lib/guide_text.dart, docs/ui-hud.md "Guide"), no game: the page limits, every quoted
// name the UI's own, every number from a constant, the topics repeating every page once, every glyph in the HUD's font.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/auto_start.dart';
import 'package:tower_defense/game.dart';
import 'package:tower_defense/guide_rules.dart';
import 'package:tower_defense/guide_text.dart';

import 'hud_font.dart';
import 'lib_literals.dart';

/// A name quoted as on screen ("Bag").
final _quoted = RegExp(r'"([^"]*)"');

/// Every page the guide shows, by where it is: the intro's (with a touch screen and with a mouse), the pointers', the
/// cards'.
Map<String, List<String>> _pages(GuideText t) => {
      for (final (i, p) in t.intro.indexed) ...{
        'I${i + 1}': p.linesFor(touch: true),
        'I${i + 1} mouse': p.linesFor(touch: false),
      },
      ...t.pointers,
      for (final MapEntry(:key, :value) in t.cards.entries)
        for (final (i, p) in value.indexed) '$key/${i + 1}': p.lines,
    };

/// Every line and title the guide holds, its topics' own and its labels too.
List<String> _allText(GuideText t) => [
      for (final lines in _pages(t).values) ...lines,
      for (final p in t.intro) p.title,
      for (final pages in t.cards.values) for (final p in pages) p.title,
      for (final topic in t.topics) ...[topic.title, ...topic.lines],
      t.labels.back, t.labels.skip, t.labels.next, t.labels.play, t.labels.tapOn, t.labels.howTo, t.labels.replay,
      t.labels.sure, t.counter(t.intro.length),
    ];

/// The guide, with Awaken by grade and the forge's words (the forge-off guide went with its build, decisions-log 296): the
/// checks read it under its name.
final _both = {'by grade': guideFor()};

/// [line]'s words, a quoted name one.
int _words(String line) => line.replaceAll(_quoted, 'N').split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;

/// The string literals of every file in lib/ but the guide's own: where the UI's names are.
List<String> _uiLiterals() => [
      for (final f in libFiles()) if (!f.path.contains('guide_')) ...dartLiterals(f.readAsStringSync()),
    ];

void main() {
  test('a page holds at most 4 lines of at most 6 words (a quoted name one); titles and the topics\' lines too', () {
    expect((guideMaxLines, guideMaxWords), (4, 6));
    for (final MapEntry(key: which, value: guide) in _both.entries) {
      for (final MapEntry(key: where, value: lines) in _pages(guide).entries) {
        expect(lines, isNotEmpty, reason: '$which $where');
        expect(lines.length, lessThanOrEqualTo(guideMaxLines), reason: '$which $where');
        for (final line in lines) {
          expect(line.trim(), line, reason: '$which $where: "$line"');
          expect(_words(line), inInclusiveRange(1, guideMaxWords), reason: '$which $where: "$line"');
        }
      }
      for (final line in _allText(guide)) {
        expect(_words(line), inInclusiveRange(1, guideMaxWords), reason: '$which: "$line"');
      }
    }
    // The word count: a quoted name is one word, whatever it holds.
    expect(_words('"Replace fallen" buys'), 2);
    expect(_words('Shop, tab "Awaken 4-5":'), 3);
  });

  test('the intro has 7 pages, the pointers P1-P5, the cards K0-K25 as the rules (K4, K5 and K25 two pages, the rest one)', () {
    expect(guideEn.intro, hasLength(7));
    expect(guideEn.counter(3), '3/7');
    expect(guideEn.pointers.keys, guidePointers);
    expect(guideEn.cards.keys, [for (final r in guideRules) r.key]);
    expect(guideEn.cards.keys, [for (var i = 0; i <= 25; i++) 'K$i']);
    for (final MapEntry(:key, :value) in guideEn.cards.entries) {
      expect(value, hasLength(key == 'K4' || key == 'K5' || key == 'K25' ? 2 : 1), reason: key);
    }
    // Only I7's third line differs with a mouse.
    for (final (i, p) in guideEn.intro.indexed) {
      expect(p.mouse == null, i != 6, reason: 'I${i + 1}');
    }
    expect(guideEn.intro[6].linesFor(touch: true)[2], 'Hold a thing to read more.');
    expect(guideEn.intro[6].linesFor(touch: false)[2], 'Point at things to read more.');
  });

  test('the "Cara Main" topics repeat every intro page and every card once, word for word', () {
    final intro = [for (final t in guideEn.topics) ...t.intro], cards = [for (final t in guideEn.topics) ...t.cards];
    expect(intro..sort(), [1, 2, 3, 4, 5, 6, 7]);
    expect(cards.toSet(), guideEn.cards.keys.toSet());
    expect(cards, hasLength(guideEn.cards.length));
    final items = guideEn.topics.firstWhere((t) => t.title == 'Items & ${Words.awaken}');
    expect(guideEn.pagesOf(items), [...guideEn.cards['K0']!, ...guideEn.cards['K8']!, ...guideEn.cards['K9']!]);
    expect(guideEn.pagesOf(guideEn.topics.first), [guideEn.intro[0], guideEn.intro[6]]);
    expect({for (final t in guideEn.topics) if (t.live != null) t.title: t.live},
        {'Items & ${Words.awaken}': GuideLive.items, 'Relics': GuideLive.relics, '${Words.bossChest} & ${Words.artifact}s': GuideLive.pusaka});
  });

  test('every quoted name is the UI\'s own: in a string in lib/, or one of the guide\'s labels', () {
    final ui = _uiLiterals(), own = {
      guideEn.labels.back, guideEn.labels.skip, guideEn.labels.next, guideEn.labels.play, guideEn.labels.tapOn,
      guideEn.labels.howTo, guideEn.labels.replay, guideEn.labels.sure,
      awakenTab, // built from its numbers, so no literal: the Shop's tab draws this very constant (recall_page.dart)
    };
    final names = {for (final guide in _both.values) for (final line in _allText(guide)) for (final m in _quoted.allMatches(line)) m[1]!};
    expect(names, containsAll([Words.army, Words.start, Words.autoWave, 'Bag', Words.shop, Words.room, Words.bossChest, Words.reroll, Words.skip, Words.take, Words.recall, Words.smithy, Words.leaveTown, Words.howTo]));
    for (final name in names) {
      final word = RegExp('(^|[^A-Za-z0-9])${RegExp.escape(name)}(\$|[^A-Za-z0-9])');
      expect(own.contains(name) || ui.any(word.hasMatch), isTrue, reason: '"$name" is no string in lib/');
    }
    // The finder itself: an interpolation is left out, a comment isn't read.
    expect(dartLiterals("  final a = 'Mulai \${x ? 'a' : 'b'} \$n'; // 'Tas'"), ['Mulai  ']);
    expect(ui.any(RegExp(r'(^|[^A-Za-z0-9])Replace fallen($|[^A-Za-z0-9])').hasMatch), isTrue);
  });

  test('no number is written in lib/guide_text.dart: each comes from a constant (a quoted name aside)', () {
    final source = File('lib/guide_text.dart').readAsStringSync();
    for (final text in dartLiterals(source).where((s) => !RegExp(r'^[IPK]\d+$').hasMatch(s))) { // the keys aren't shown
      expect(text.replaceAll(_quoted, ''), isNot(contains(RegExp(r'\d'))), reason: "'$text'");
    }
  });

  test('the numbers the guide shows are its constants\'', () {
    int pct(double k) => (k * 100).round();
    final allowed = [ // a list: several constants share a value
      capacityStart, capacityStep, armyMaxBoard, ...typeCapBoard.values, autoStartDelay.round(),
      heroEvery, pct(auraBoost - 1), miniBossEvery, necroHealerFrom, bossEvery, bossDrops, draftCards, escortFrom,
      asahRelics, leburStars, pct(priceRise), pct(tempaHp), pct(tempaDmg), tempaFrom, guideEn.intro.length,
      loadedTownRules.tavern.waves, marchMax.round(),
    ];
    for (final line in [for (final guide in _both.values) ..._allText(guide)]) {
      for (final m in RegExp(r'\d+').allMatches(line.replaceAll(_quoted, ''))) {
        expect(allowed, contains(int.parse(m[0]!)), reason: '"$line"');
      }
    }
    String lines(String key, [int page = 0]) => guideEn.cards[key]![page].lines.join(' / ');
    expect(guideEn.intro[3].lines.join(' / '),
        'Room for $capacityStart troops at first. / "${Words.room}" gives $capacityStep more. / The most is $armyMaxBoard troops.');
    expect(guideEn.intro[2].lines.take(3).join(' / '),
        'Each type has a cap: / ${troopTypeNames[Game.freeHealer]} ${typeCapBoard[Game.freeHealer]}, Archer ${typeCapBoard['archer']}, '
        'Wizard ${typeCapBoard['wizard']}, / the others ${typeCapBoard['soldier']}.');
    expect(guideEn.intro[5].lines[2], '${autoStartDelay.round()} seconds after a win.');
    expect(lines('K2'), startsWith('Wave $miniBossEvery has a mini boss.'));
    // decisions-log 329: the back line costs nothing; a march not won in marchMax s costs a heart.
    expect(guideEn.intro[0].lines.join(' / '),
        'Monsters come from the right. / Lose your army: lose a heart, / and play the wave again. / No hearts left: game over.');
    expect(lines('K16'), 'The wave took too long: / the monsters charge your line. / Kill them in ${marchMax.round()} s / or lose a heart.');
    expect(lines('K3'), startsWith('Wave $necroHealerFrom: a healer monster.'));
    // K4 first says how to get ready (decisions-log 176), then what the boss leaves.
    expect(lines('K4'),
        'Wave $bossEvery has a boss! / Get ready: fill your room / with troops, buy "${Words.room}" / and a second ${troopTypeNames[Game.freeHealer]}.');
    // The boss leaves rare materials (the forge's, decisions-log 272).
    expect(lines('K4', 1), 'One comes every $bossEvery waves. / Win it: rare materials / and a "${Words.bossChest}".');
    expect(lines('K5'), startsWith('Pick one of $draftCards cards.'));
    expect(lines('K10'), 'Every ${heroEvery}th wave won: a Hero. / Its own skill and big stats. / While a Hero lives, / all troops get +${pct(auraBoost - 1)}%.');
    expect(lines('K13'), endsWith('and ${releaseRefund == 0.5 ? 'half' : '${pct(releaseRefund)}%'} their gold comes back.'));
    expect(lines('K15'), startsWith('$armyMaxBoard troops is the most.'));
    expect(lines('K18'), contains('Red dot on "${Words.army}":'), reason: 'the dot K18 points at (decisions-log 237)');
    expect(lines('K18'), endsWith('After ${Words.awaken} $tempaFrom: ${Words.forge}.'));
    expect(lines('K19'), startsWith('From wave $escortFrom, bosses'));
    expect(lines('K20'),
        'An Artifact can get a star! / "Bag": tap it, then "${Words.sharpen}". / Costs gold and $asahRelics relics. / Once every $bossEvery waves.');
    expect(lines('K21'), endsWith('for +$leburStars star.'));
    expect(lines('K22'), 'New: spare items make an Artifact / a bit stronger. / "Bag": tap it, then "${Words.carve}". / '
        'Or pick an item: "${Words.give}".');
    expect(guideEn.topics.firstWhere((t) => t.title == '${Words.town}s').lines.join(' / '),
        'The wave meter shows / when the next ${Words.town} comes. / There, "Auto Wave" waits / '
        'until you tap "${Words.leaveTown}". / Tap the tent for "${Words.army}". / '
        'The "${Words.tavern}" sells boosts for / 2-4 waves, or until next ${Words.town}. / '
        'A "${Words.wishlist}" marks items to make, / set in "${Words.smithy}" or "${Words.army}".');
    final late = guideEn.topics.firstWhere((t) => t.title == 'Late game').lines.join(' ');
    expect(late, contains('+${pct(tempaHp)}% HP'));
  });

  test('the Awaken words name the grades: the grade line, the last level\'s share town.json\'s', () {
    String lines(GuideText guide, String key) => guide.cards[key]![0].lines.join(' / ');
    List<String> topic(GuideText guide) => guide.topics.firstWhere((t) => t.title == 'Items & ${Words.awaken}').lines;
    final (grades, n) = (_both['by grade']!, Words.gradeNumerals);
    // By grade (decisions-log 252): the two Awaken cards name the grades, the topic the last level's share of the counts.
    expect(lines(grades, 'K8'),
        'A type takes only a few / of each item. / Fill its list: it can ${Words.awaken}, / ${Words.grade} ${n[0]}, then ${n[1]}, then ${n[2]}.');
    expect(lines(grades, 'K9'), endsWith('More HP, MP and a skill. / Its levels: ${Words.grade} ${n[0]}, ${n[1]}, ${n[2]}.'));
    expect(topic(grades).skip(2).join(' / '),
        '${Words.awaken} levels take ${Words.grade} ${n[0]}, / then ${n[1]}, then ${n[2]}. / The last level: two thirds.');
    // That share is town.json's (0.667: two thirds), not a word written here (decisions-log 259).
    expect(loadedTownRules.awaken.share.last, closeTo(2 / 3, 0.001));
    final shipped = loadedTownRules;
    addTearDown(() => loadedTownRules = shipped);
    loadedTownRules = TownRules.patch({'awaken': {'share': [1, 1, 0.75]}});
    expect(topic(guideFor()).last, 'The last level: 75%.');
    loadedTownRules = shipped;
    // Every game plays the forge (decisions-log 272, 296, 321): its guide is the one by grade, word for word.
    for (final key in ['K8', 'K9']) {
      expect(lines(guideEn, key), lines(grades, key), reason: key);
    }
    expect(topic(guideEn), topic(grades));
  });

  test('the guide gives no aiming advice: troops pick their own monster', () {
    for (final line in [for (final guide in _both.values) ..._allText(guide)]) {
      expect(line.toLowerCase(), isNot(contains(RegExp(r'\b(aim|target|focus)'))), reason: '"$line"');
    }
  });

  test('every character the guide shows is in the HUD\'s font', () {
    final font = fontChars();
    for (final line in [for (final guide in _both.values) ..._allText(guide)]) {
      expect(line.runes.where((c) => !font.contains(c)).map(String.fromCharCode), isEmpty, reason: '"$line"');
    }
  });
}
