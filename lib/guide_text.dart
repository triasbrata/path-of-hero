// The first-time guide's words (the owner, 2026-10-02: "aku perlu ada introduction ke user pertamakali main, untuk
// menjelaskan semua mekanik game ini"; docs/ui-hud.md "Guide"): the intro's pages after a device's first "Main Baru",
// the pointers of the first breaks, the one-time cards K0-K25 (when each shows: lib/guide_rules.dart) and the
// "Cara Main" page's topics. Pure Dart: the board draws them.
//
// - Simple English with the item text's glossary (docs/ui-hud.md "In-game text": troop, type, HP, attack, damage, heal,
//   hit, wave, boss, monster, star, "this type", "all troops", "whole run"; a Pusaka is "for a whole type, never lost",
//   a Sumpah an "Oath"); the game's own buttons, tabs and pages are quoted as on screen ("Start", "Bag"; the Army
//   page's from lib/words.dart, "Army", "+Room"). test/guide_text_test.dart finds every quoted name in lib/, or in [GuideText.labels].
// - A page holds at most [guideMaxLines] lines of at most [guideMaxWords] words (a quoted name counts as one).
// - Every number comes from its rule's constant; none is written here (the test reads this file for digits).
// - No aiming advice: troops pick their own monster (docs/units-and-combat.md).
// - A new card is a new key here and a rule in guide_rules.dart; nothing else moves.

import 'dart:math' show min;

import 'auto_start.dart' show autoStartDelay;
import 'game.dart';

/// The most lines on a page, and the most words in a line (a quoted name counts as one).
const guideMaxLines = 4, guideMaxWords = 6;

/// One page of the guide: its [title] and [lines]; [mouse] are the lines with a mouse instead of a touch screen, where
/// they differ (null: the same).
class GuidePage {
  const GuidePage(this.title, this.lines, {this.mouse});

  final String title;
  final List<String> lines;
  final List<String>? mouse;

  /// The lines for a touch screen ([touch]) or a mouse.
  List<String> linesFor({required bool touch}) => touch ? lines : mouse ?? lines;
}

/// The game's own texts a "How to Play" topic lists after its lines, read at run time so they never drift from the
/// tooltips: every item's, every small relic's, or the Pusaka's (the Epik and the Langka).
enum GuideLive { items, relics, pusaka }

/// One topic of the "How to Play" page: its [title], the intro pages ([intro], by number: 1 is the first) and the cards
/// ([cards], by key) it repeats word for word, then its own [lines] (the page only; any number of them), then the
/// game's texts of [live].
class GuideTopic {
  const GuideTopic(this.title, {this.intro = const [], this.cards = const [], this.lines = const [], this.live});

  final String title;
  final List<int> intro;
  final List<String> cards;
  final List<String> lines;
  final GuideLive? live;
}

/// The guide's own buttons and words: the intro's "Back", "Skip", "Next" and "Play!" (on its last page), a
/// card's "Tap to continue", the page's button "How to Play", its "Replay guide" and that button's second tap "Sure?".
typedef GuideLabels = ({
  String back,
  String skip,
  String next,
  String play,
  String tapOn,
  String howTo,
  String replay,
  String sure,
});

/// The guide in one language: the intro's pages, the pointers' lines by key (P1-P5), the cards' pages by key (K0-K25;
/// most one page, K4 and K5 two), the "How to Play" topics and the guide's own [labels].
class GuideText {
  const GuideText({required this.intro, required this.pointers, required this.cards, required this.topics, required this.labels});

  final List<GuidePage> intro;
  final Map<String, List<String>> pointers;
  final Map<String, List<GuidePage>> cards;
  final List<GuideTopic> topics;
  final GuideLabels labels;

  /// The intro's counter on page [n] (1 first): "3/7".
  String counter(int n) => '$n/${intro.length}';

  /// What [topic] repeats, in order: its intro pages, then its cards' pages.
  List<GuidePage> pagesOf(GuideTopic topic) => [for (final n in topic.intro) intro[n - 1], for (final k in topic.cards) ...cards[k]!];
}

/// [k] as whole percent: 0.15 → "15%".
String _pct(double k) => '${(k * 100).round()}%';

/// Troop [type]'s name, and its cap on the board ([typeCapBoard], decisions-log 201).
String _name(String type) => troopTypeNames[type]!;
int _capOf(String type) => typeCapBoard[type]!;

/// A share in words: "half" for 0.5, "two thirds" for 2/3 (town.json writes 0.667), else its percent.
String _share(double k) => k == 0.5 ? 'half' : (k - 2 / 3).abs() < 0.001 ? 'two thirds' : _pct(k);

/// The share of its counts the last Awaken's grade set takes ([Game.gradeSet]: town.json `awaken.share`, its last for a
/// level past it).
double get _lastGradeShare {
  final share = loadedTownRules.awaken.share;
  return share[min(maxAwaken, share.length) - 1];
}

/// [n] as an English ordinal: 10 → "10th", 3 → "3rd".
String _nth(int n) => '$n${n % 100 ~/ 10 == 1 ? 'th' : switch (n % 10) { 1 => 'st', 2 => 'nd', 3 => 'rd', _ => 'th' }}';

/// Seconds as the player reads them: 5.0 → "5", 2.5 → "2.5".
String _secs(double s) => s == s.roundToDouble() ? '${s.round()}' : '$s';

/// "1 star", "2 stars".
String _stars(int n) => n == 1 ? '$n star' : '$n stars';

/// The free healer's name ([Game.freeHealer]), "Priest".
final _healer = troopTypeNames[Game.freeHealer]!;


/// Tempa's level in words: "+5% HP and attack" (or each its own when they differ).
final _tempaGain = tempaHp == tempaDmg ? '+${_pct(tempaHp)} HP and attack' : '+${_pct(tempaHp)} HP, +${_pct(tempaDmg)} attack';

/// The seconds Auto waits in a Town before it leaves ([TownSchedule.autoLeave], town.json).
double get _townAuto => loadedTownRules.schedule.autoLeave;

/// How long a Tavern boost lasts (town.json `tavern.lengths`, decisions-log 331): "2-4 waves, or until next Town".
String get _tavernLengths {
  final r = loadedTownRules.tavern, n = [for (final MapEntry(:key, :value) in r.lengths.entries) if (value > 0) key];
  return [
    if (n.isNotEmpty) n.first == n.last ? boostLengthWords(n.first) : '${n.first}-${n.last} waves',
    if (r.lengthTown > 0) boostLengthWords(0, untilTown: true, inLine: true),
  ].join(', or ');
}

/// The guide in simple English (the owner's decision 1 a), with the UI's Indonesian names. The board plays with the Towns
/// on (decisions-log 237), so the Shop, the relics and the Recall are told as a Town has them, and with the forge's
/// (decisions-log 272): Awaken by grade, K8, K9 and the "Items & Awaken" topic naming the grades (decisions-log 249,
/// 252); the boss leaving materials, not items (K4); the Shop selling the materials that dropped (K11); the Smithy
/// making items too (K23, K24). Its words from before the forge went with the forge-off build (decisions-log 296).
final guideEn = guideFor();

/// The guide built from the rules loaded now ([loadedTownRules]): [guideEn], or a test's after it patched them.
GuideText guideFor() => GuideText(
  intro: [
    const GuidePage('Path of Hero', [
      'Monsters come from the right.',
      'A monster past the line',
      'takes half a heart.',
      'No hearts or troops: game over.',
    ]),
    const GuidePage('Gold and troops', [
      'Gold buys troops.',
      'Tap a troop at the bottom.',
      'Grey price: not enough gold.',
      'You can buy during a wave.',
    ]),
    GuidePage('Troop caps', [
      'Each type has a cap:',
      '$_healer ${_capOf(Game.freeHealer)}, ${_name('archer')} ${_capOf('archer')}, ${_name('wizard')} ${_capOf('wizard')},',
      'the others ${_capOf('soldier')}.',
      'Keep a $_healer: it heals.',
    ]),
    GuidePage('More room', [
      'Room for $capacityStart troops at first.',
      '"${Words.room}" gives $capacityStep more.',
      'The most is $armyMaxBoard troops.',
    ]),
    const GuidePage('The fight', [
      'Troops fight by themselves.',
      'Skills use MP: the blue bar.',
      'Hurt troops go to a healer.',
      'Your job: a strong army.',
    ]),
    GuidePage('Waves', [
      'Tap "${Words.start}" to begin a wave.',
      '"${Words.autoWave}" starts the next wave',
      '${_secs(autoStartDelay)} seconds after a win.',
      'It waits if many troops fell.',
    ]),
    const GuidePage('Winning', [
      'Win a wave: get gold.',
      'Field loot comes to "Bag".',
      'Hold a thing to read more.',
      'More help: "${Words.howTo}".',
    ], mouse: [
      'Win a wave: get gold.',
      'Field loot comes to "Bag".',
      'Point at things to read more.',
      'More help: "${Words.howTo}".',
    ]),
  ],
  pointers: const {
    'P1': ['Tap a troop at the bottom', 'to add it.'],
    'P2': ['Ready? Tap "${Words.start}".'],
    'P3': ['New item! Tap "Bag".'],
    'P4': ['Tap the item.'],
    'P5': ['Give it to a type.', 'All troops of this type', 'get it, now and later.'],
  },
  cards: {
    'K0': const [
      GuidePage('Items', [
        'You have an item in "Bag".',
        'Tap it, then give it',
        'to a type: all its troops',
        'get it, now and later.',
      ]),
    ],
    'K1': const [
      GuidePage('Troops fell', [
        'Some troops fell this wave.',
        '"${Words.replaceFallen}" buys',
        'them all back at once.',
      ]),
    ],
    'K2': const [
      GuidePage('Next: a mini boss', [
        'Wave $miniBossEvery has a mini boss.',
        'Strong monsters have colours:',
        'silver strong, gold stronger,',
        'purple mini boss, orange boss.',
      ]),
    ],
    'K3': const [
      GuidePage('Healer monster', [
        'Wave $necroHealerFrom: a healer monster.',
        'It stays behind the others',
        'and heals them.',
        'More attack beats its heal.',
      ]),
    ],
    // How to get ready first (decisions-log 176: a 5-troop opening with room left lost every early necromancer boss).
    'K4': [
      GuidePage('Next: the boss', [
        'Wave $bossEvery has a boss!',
        'Get ready: fill your room',
        'with troops, buy "${Words.room}"',
        'and a second $_healer.',
      ]),
      GuidePage('Next: the boss', [
        'One comes every $bossEvery waves.',
        'Win it: rare materials',
        'and a "${Words.bossChest}".',
      ]),
    ],
    'K5': const [
      GuidePage('Pick an ${Words.artifact}', [
        'Pick one of $draftCards cards.',
        'An ${Words.artifact}: for a whole type,',
        'never lost.',
        'Pick a type you will keep.',
      ]),
      GuidePage('Pick an ${Words.artifact}', [
        '"${Words.reroll}": new cards, for gold.',
        '"${Words.skip}": gold, no card.',
        '"${Words.take}": get the card you picked.',
      ]),
    ],
    'K6': const [
      GuidePage(Words.artifact, [
        'Your ${Words.artifact} is on a type.',
        'A ring shows under its troops.',
        'Same card again: one more star.',
        'Move it in "Bag", between waves.',
      ]),
    ],
    'K7': const [
      GuidePage('Relic', [
        'A relic is in "Bag".',
        'It helps one troop.',
        'Tap it, then a troop.',
        'Troop falls: relic comes back.',
      ]),
    ],
    // The grade line (decisions-log 252; not const: a const list can't be indexed for Words.gradeNumerals).
    'K8': [
      GuidePage('Item limits', [
        'A type takes only a few',
        'of each item.',
        'Fill its list: it can ${Words.awaken},',
        '${Words.grade} ${Words.gradeNumerals[0]}, then ${Words.gradeNumerals[1]}, then ${Words.gradeNumerals[2]}.',
      ]),
    ],
    'K9': [
      GuidePage(Words.awaken, [
        'Red dot on "Bag":',
        'a type can ${Words.awaken} now!',
        'More HP, MP and a skill.',
        'Its levels: ${Words.grade} ${Words.gradeNumerals[0]}, ${Words.gradeNumerals[1]}, ${Words.gradeNumerals[2]}.',
      ]),
    ],
    'K10': [
      GuidePage('Hero', [
        'Every ${_nth(heroEvery)} wave won: a Hero.',
        'Its own skill and big stats.',
        'While a Hero lives,',
        'all troops get +${_pct(auraBoost - 1)}.',
      ]),
    ],
    // The Shop deals only in a Town (decisions-log 230, 237) and sells the materials that dropped (decisions-log 248,
    // 272).
    'K11': [
      GuidePage(Words.shop, [
        'Every ${Words.town} has a "${Words.shop}" now:',
        'buy materials that dropped,',
        'sell what you do not need.',
      ]),
    ],
    'K12': const [
      GuidePage(Words.legendary, [
        'Orange card: ${Words.legendary}.',
        'It changes a rule.',
        'Each one comes once a run.',
        'An Oath works on all troops.',
      ]),
    ],
    'K13': [
      GuidePage('Type full', [
        'A type is at its cap.',
        'Buy other types to grow.',
        '"${Words.release}" sends a type home',
        'and ${_share(releaseRefund)} their gold comes back.',
      ]),
    ],
    // Recalled from its type's Army detail (decisions-log 230).
    'K14': const [
      GuidePage('Hero fell', [
        'Your Hero fell.',
        '"${Words.army}": pick its type,',
        'then "${Words.recall}" brings it back',
        'for gold.',
      ]),
    ],
    'K15': const [
      GuidePage('Full army', [
        '$armyMaxBoard troops is the most.',
        'Now make types stronger:',
        'items, ${Words.awaken}, ${Words.artifact}s.',
      ]),
    ],
    'K16': const [
      GuidePage('Too slow', [
        'The wave took too long.',
        'Monsters ran to the line.',
        'Make your army stronger.',
      ]),
    ],
    'K17': const [
      GuidePage(Words.tide, [
        'Monsters now grow every wave.',
        'Bosses do not. It never stops.',
        'Make your types stronger.',
      ]),
    ],
    // The dot is on the Army tab: its detail buys Awaken 4-5 and Forge (decisions-log 230).
    'K18': const [
      GuidePage('Spend gold', [
        'Gold is waiting!',
        'Red dot on "${Words.army}":',
        'a type can buy more power.',
        'After ${Words.awaken} $tempaFrom: ${Words.forge}.',
      ]),
    ],
    'K19': const [
      GuidePage('Escorts', [
        'From wave $escortFrom, bosses',
        'bring healer monsters.',
        'Make your army hit harder.',
      ]),
    ],
    'K20': const [
      GuidePage(Words.sharpen, [
        'An Artifact can get a star!',
        '"Bag": tap it, then "${Words.sharpen}".',
        'Costs gold and $asahRelics relics.',
        'Once every $bossEvery waves.',
      ]),
    ],
    'K21': [
      GuidePage(Words.melt, [
        'A spare Artifact in the Vault?',
        '"${Words.melt}" puts it into another',
        'for +${_stars(leburStars)}.',
      ]),
    ],
    'K22': const [
      GuidePage(Words.carve, [
        'New: spare items make an Artifact',
        'a bit stronger.',
        '"Bag": tap it, then "${Words.carve}".',
        'Or pick an item: "${Words.give}".',
      ]),
    ],
    // The Towns (decisions-log 237): at the first Town, in it; after the first wave that drops a material. With the forge
    // the Smithy makes the items too (decisions-log 249, 272); its third line the Tavern's (decisions-log 268), whose first
    // offer there is the Feast.
    'K23': [
      GuidePage('A ${Words.town}!', [
        'A safe stop between waves.',
        '"${Words.smithy}": craft items and relics.',
        '"${Words.tavern}": buy boosts.',
        '"${Words.leaveTown}" goes on.',
      ]),
    ],
    'K24': [
      GuidePage(Words.materials, [
        'Monsters drop materials.',
        'They wait in "${Words.bag}".',
        'In a ${Words.town}, the "${Words.smithy}"',
        'makes items and relics.',
      ]),
    ],
    // The Shadows (decisions-log 319): over the first chest whose cards hide one; the chips and the ease.
    'K25': [
      GuidePage('Monster ${Words.shadow}s', [
        'Each card hides a ${Words.shadow}:',
        'a buff for the monsters.',
        'More "!": a stronger one.',
        '"${Words.take}" shows what they got.',
      ]),
      GuidePage('Monster ${Words.shadow}s', [
        'Chips show the ones they hold.',
        'Tap one to read them all.',
        'A wave where many troops fall',
        'takes the newest one away.',
      ]),
    ],
  },
  topics: [
    const GuideTopic('Goal', intro: [1, 7], lines: [
      'Score: kills, waves won, hearts left.',
      'See it at the end',
      'and on "${Words.scoreboard}".',
    ]),
    const GuideTopic('Troops & types', intro: [2, 3, 4], cards: ['K13', 'K15']),
    const GuideTopic('The fight', intro: [5], lines: ['Each troop hits the nearest monster.']),
    const GuideTopic('Waves & ${Words.autoWave}', intro: [6], cards: ['K1', 'K16'], lines: [
      '${Words.autoWave} also waits in "Bag"',
      'or "${Words.settings}".',
    ]),
    const GuideTopic('Controls', lines: [
      'Pause: Esc or P.',
      'Mid-wave, the top button too.',
      '"x2": faster.',
      'Paused, you can still buy',
      'and give items.',
      'Between waves, drag a troop',
      'to a new spot.',
      'Red dot on "Bag" or "${Words.army}":',
      'something to do there.',
    ]),
    GuideTopic('Items & ${Words.awaken}', cards: ['K0', 'K8', 'K9'], live: GuideLive.items, lines: [
      'An item on a type:',
      'its troops cost ${_pct(priceRise)} more.',
      // The Awaken levels' grades (decisions-log 252; the cards' grade line, its counts' share here, town.json's).
      '${Words.awaken} levels take ${Words.grade} ${Words.gradeNumerals[0]},',
      'then ${Words.gradeNumerals[1]}, then ${Words.gradeNumerals[2]}.',
      'The last level: ${_share(_lastGradeShare)}.',
    ]),
    const GuideTopic('Relics', cards: ['K7'], live: GuideLive.relics, lines: [
      'The "${Words.smithy}" makes them,',
      'in a ${Words.town}.',
      'To take a relic off:',
      'tap its slot, between waves.',
    ]),
    GuideTopic('Monsters', cards: ['K2', 'K3', 'K4', 'K19'], lines: [
      'At ${_share(bossMomentK.at)} HP a boss',
      'does a big move.',
      'A stun can delay it.',
    ]),
    GuideTopic('${Words.bossChest} & ${Words.artifact}s', cards: ['K5', 'K6', 'K12', 'K25'], live: GuideLive.pusaka, lines: [
      '"${Words.equip}": free the first time.',
      '"${Words.move}": costs gold.',
      '"${Words.sell}": pays ${_share(sellShare)}.',
    ]),
    const GuideTopic('Heroes', cards: ['K10', 'K14']),
    GuideTopic('${Words.town}s', cards: ['K23', 'K24'], lines: [
      'The wave meter shows',
      'when the next ${Words.town} comes.',
      'There, "${Words.autoWave}" leaves',
      'after ${_secs(_townAuto)} seconds.',
      // The tent opens the Army page (decisions-log 301).
      'Tap the tent for "${Words.army}".',
      'The "${Words.tavern}" sells boosts for',
      '$_tavernLengths.',
      // The Wishlist (decisions-log 282): set on the Smithy's item page and on a type's Army detail.
      'A "${Words.wishlist}" marks items to make,',
      'set in "${Words.smithy}" or "${Words.army}".',
    ]),
    const GuideTopic(Words.shop, cards: ['K11', 'K18']),
    GuideTopic('Late game', cards: ['K17', 'K20', 'K21', 'K22'], lines: [
      '"${Words.forge}": each level gives',
      '$_tempaGain.',
    ]),
  ],
  labels: (
    back: Words.back,
    skip: Words.skip,
    next: 'Next',
    play: 'Play!',
    tapOn: 'Tap to continue',
    howTo: Words.howTo,
    replay: 'Replay guide',
    sure: Words.sure,
  ),
);
