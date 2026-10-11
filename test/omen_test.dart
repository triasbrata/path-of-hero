// Bayangan, the enemy's hidden buffs (catalog step 0c, decisions-log 180, lib/omen.dart; docs/loot-items-relics.md
// "Bayangan"): off by default, and off nothing changes (no die, no key, no event); on, one face a card on its own dice
// (the cards are the same), none before omenFrom nor on a Serpihan, the 2/9 tilt to the card's counter, the take's marks
// by rarity, the overflow and "penuh", a reroll's new faces, Lewati's skip buff owed instead of a level, an old faceless
// chest, the save round trip, the old saves' catch-up (b86: exactly Wear Down 2 / Heal Siphon 2 / Mend 2 / Prey 2 /
// Armor 2, 2 a wave, once; w89: 19 owed, 12 dealt), the Beban factor, the ease, the events and telemetry 8, the log lines
// in English, and policyPick unchanged.
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';
import 'package:tower_defense/main.dart' show logLine;
import 'package:tower_defense/telemetry.dart';

import 'hero_skill_helpers.dart';

/// Dice that give [rolls] in turn (the last one again once they run out) and count their draws.
class _Seq implements Random {
  _Seq(this.rolls);
  final List<double> rolls;
  int draws = 0;

  @override
  double nextDouble() => rolls[min(draws++, rolls.length - 1)];

  @override
  int nextInt(int max) {
    draws++;
    return 0;
  }

  @override
  bool nextBool() {
    draws++;
    return false;
  }
}

/// A sink that keeps the records, through JSON.
class _Kept implements TelemetrySink {
  final records = <Map<String, dynamic>>[];

  @override
  void add(Map<String, Object?> record) => records.add(jsonDecode(jsonEncode(record)) as Map<String, dynamic>);

  @override
  Future<void> flush() async {}

  Iterable<Map<String, dynamic>> events(String kind) =>
      [for (final r in records) if (r['rec'] == 'event' && (r['event'] as Map)['kind'] == kind) r['event'] as Map<String, dynamic>];
}

/// A game with no skills cast and the chest on, between waves at [wave], on [draft] dice and [omens] dice; its first
/// chest given, so the next is rolled by rarity.
Game chested({int wave = 29, Random? draft, Random? omens}) => (bareGame(Random(1))
  ..skills = false
  ..heroSkills = false
  ..awakenSkills = false
  ..offers = true
  ..wave = wave
  ..chestsGiven = 1
  ..draft = draft ?? Random(7)
  ..omenDice = omens ?? Random(11));

/// Draft dice whose every rarity roll is Langka, Epik or Legenda.
Random langkaDice() => _Seq([0.0]);
Random epikDice() => _Seq([chestOdds.rare + 0.01]);
Random legendaDice() => _Seq([0.99]);

/// Starts the next wave of [g] with nothing in it, so the one after may start at once.
void nextWave(Game g) {
  g
    ..startWave()
    ..queue.clear();
}

/// Wins the next wave of [g] at once, its [fell] troops (the first ones) counted fallen.
void win(Game g, {int fell = 0}) {
  g.startWave();
  g.queue.clear();
  g.fallen.addAll(g.troops.take(fell));
  g
    ..units.add(g.monster('slime', Tier.normal, const Point(300, 60))..gone = true)
    ..tick(0.05);
  expect([g.waveActive, g.over], [false, false]);
}

Map<String, dynamic> fixture(String name) => jsonDecode(File('test/fixtures/$name').readAsStringSync()) as Map<String, dynamic>;

/// The owner's wave-86 save from before the Pusaka and the chest (b86).
Map<String, dynamic> b86() => fixture('save-20261001-2005-pre-awaken.json');

/// The owner's wave-89 save (Pusaka, Legenda, the chest).
Map<String, dynamic> w89() => fixture('save-20261002-2222-w89-sellbug.json');

/// The levels [g]'s enemy holds, kind by kind.
Map<OmenKind, int> levels(Game g) => {for (final k in OmenKind.values) if (g.omenLevel(k) > 0) k: g.omenLevel(k)};

/// The Bayangan's keys in a save: the game's and each chest's.
List<String> omenKeys(Map<String, dynamic> save) => [
      for (final k in ['omens', 'omensOwed', 'skipBuffDue']) if (save.containsKey(k)) k,
      for (final c in (save['chests'] as List?) ?? const []) if ((c as Map).containsKey('omens')) 'chests[].omens',
    ];

Game roundTrip(Game g) => Game.fromJson(jsonDecode(jsonEncode(g.toJson())) as Map<String, dynamic>);

const armor = OmenKind.armor, haste = OmenKind.haste, mend = OmenKind.mend, wound = OmenKind.wound;
const thorns = OmenKind.thorns, shield = OmenKind.shield, guard = OmenKind.guard;

void main() {
  test('off by default (no OMENS define): ship dark until the UI step', () {
    expect(omensOn, isFalse);
  });

  group('off', () {
    setUp(() => omensOn = false);

    test('no face is drawn, no key is written, no field is sent: a chest, a take, a Lewati and a wave as before', () {
      final dice = _Seq([0.0]);
      final g = chested(omens: dice);
      final events = <GameEvent>[];
      g.listeners.add(events.add);
      g.giveChests(2);
      g.rerollChest();
      expect(g.takeCard(0), isTrue);
      expect(g.skipChest(), isNotNull);
      nextWave(g);
      expect(dice.draws, 0, reason: 'the Bayangan dice are never touched');
      expect([g.omens, g.omensOwed, g.skipBuffDue, g.waveSkipBuff], [isEmpty, isEmpty, false, false]);
      g.giveChests(1);
      expect(omenKeys(g.toJson()), isEmpty);
      expect(jsonEncode((Chest(ChestKind.boss, 30, cards: [Relic.grail], omens: [haste])).toJson()).contains('omens'), isFalse);
      for (final e in events) {
        expect(e, isNot(anyOf(isA<OmenGained>(), isA<OmenEased>())));
        // The Bayangan's fields (a wave start's own `levels` are Bangkit's).
        final fields = e is OfferPicked ? const ['omen', 'levels', 'skipBuff'] : const ['omens'];
        expect(e.data.keys.where(fields.contains), isEmpty, reason: '${e.kind}');
      }
      expect(g.omenE(armor), 0);
    });

    test("the owner's saves load with no Bayangan and write none back: no catch-up while off", () {
      for (final j in [b86(), w89()]) {
        final g = Game.fromJson(j);
        expect([g.omens, g.omensOwed, g.omenCaughtUp], [isEmpty, isEmpty, false]);
        expect(omenKeys(g.toJson()), isEmpty);
      }
      // A save written while on loads with its Bayangan ignored, and writes none.
      omensOn = true;
      final on = Game.fromJson(b86());
      final saved = jsonDecode(jsonEncode(on.toJson())) as Map<String, dynamic>;
      expect(saved.containsKey('omens'), isTrue);
      omensOn = false;
      final off = Game.fromJson(saved);
      expect([off.omens, off.omensOwed], [isEmpty, isEmpty]);
      expect(omenKeys(off.toJson()), isEmpty);
    });
  });

  group('on', () {
    setUp(() => omensOn = true);
    tearDown(() => omensOn = false);

    test("the seven kinds: in enum order in their pools (since the Langka cut-over Armor, Mend, Barrier and Escort out of "
        "Langka's, since the Epik one Haste, Spikes, Wound, Barrier and Escort out of Epik's, since the Legenda one Armor, "
        "Mend, Haste, Spikes and Wound out of Legenda's), their numbers and icons; the counters link back to today's rows", () {
      final seven = OmenKind.values.take(7).toList(); // the data batches' kinds follow (omen_langka_test.dart)
      expect(seven, [armor, haste, mend, thorns, wound, shield, guard]);
      expect(omenPool(Rarity.legenda).take(2), [OmenKind.shield, OmenKind.guard],
          reason: "Barrier and Escort first since the Legenda cut-over (omen_legenda_cutover_test.dart); G-1B's kinds follow");
      expect(omenPool(Rarity.epik).take(2), [armor, mend], reason: 'the Epik cut-over (omen_epik_cutover_test.dart)');
      expect(omenPool(Rarity.langka).take(3), [haste, thorns, wound], reason: 'the Langka cut-over (omen_cutover_test.dart)');
      expect(omenPool(Rarity.biasa), isEmpty);
      expect(omenOrder, OmenKind.values);
      expect([omenFrom, omenMarks, omenCap, omenKindsMax, omenTilt], [20, {Rarity.langka: 1, Rarity.epik: 2, Rarity.legenda: 3}, 4, 8, 2 / 9]);
      expect([omenScale, omenAtCap, omenOverMax, omenEaseShare, omenEaseMax, omenCatchUpMax, omenCatchUpStep], [1.0, 1.0, 2.0, 0.125, 2, 12, 2]);
      expect({for (final k in seven) k: k.k}, {
        armor: (perE: 0.05, max: 0.4),
        haste: (perE: 0.05, max: 0.4),
        mend: (perE: 0.003, max: 0.024),
        thorns: (perE: 0.03, max: 0.24),
        wound: (perE: 0.06, max: 0.5),
        shield: (perE: 0.05, max: 0.4),
        guard: (perE: 0.5, max: 2.0),
      });
      // The owner's answer: each kind sits in one tier ([omenOneTier] since the Legenda cut-over, batch G-3): of the
      // seven, Armor and Mend Epik's, Haste, Spikes and Wound Langka's, Barrier and Escort Legenda's.
      Set<Rarity> tierOf(OmenKind k) => [haste, thorns, wound].contains(k)
          ? {Rarity.langka}
          : [shield, guard].contains(k)
              ? {Rarity.legenda}
              : {Rarity.epik};
      expect(omenOneTier, isTrue);
      for (final k in OmenKind.values) {
        expect(k.tiers, seven.contains(k) ? tierOf(k) : hasLength(1), reason: '$k');
      }
      for (final k in OmenKind.values) {
        expect(k.live, isTrue);
        if (k.icon case final icon?) expect(File('assets/images/${icon.sheet}').existsSync(), isTrue, reason: '$k');
      }
      expect(guard.icon, isNull, reason: "the wave's boss-bar portrait");
      expect(wound.answers, containsAll([Relic.bloodFang, Relic.mourningBell]));
      expect(wound.answers.where((r) => r.rarity == Rarity.epik), isEmpty, reason: 'Dragon Heart and Dawn Star switched');
      expect(guard.answers, [Relic.oathOfOne, Relic.alliance, Relic.fewOath]); // Oath of the Few since G-4 (decisions-log 247)
      expect([omenCounter(Relic.dawnStar, 'priest'), omenCounter(Relic.dawnStar, 'archer'), omenCounter(Relic.dawnStar, null)],
          [OmenKind.healSiphon, armor, armor]);
      expect(omenCounter(Relic.dragonHeart, 'priest'), OmenKind.wearDown);
    });

    test('a face: under 2/9 the card\'s counter, else the pool evenly; none on a Serpihan', () {
      final pool = omenPool(Rarity.langka), n7 = pool.length; // Iron Banner's and War Drum's
      expect(omenFace(Relic.ironBanner, null, 0), haste);
      expect(omenFace(Relic.ironBanner, null, omenTilt - 1e-9), haste);
      expect([for (var i = 0; i < n7; i++) omenFace(Relic.ironBanner, null, omenTilt + (i + 0.5) * (1 - omenTilt) / n7)], pool);
      expect(omenFace(Relic.ironBanner, null, 1 - 1e-12), pool.last);
      expect(omenFace(Relic.dawnStar, 'priest', 0.1), OmenKind.healSiphon);
      expect(omenFace(null, null, 0.1), isNull);
      // Over many draws: the counter 2/9 + 7/9 × 1/n, each other kind 7/9 × 1/n (with today's seven alone 1/3 and 1/9).
      final rng = Random(3), n = <OmenKind, int>{};
      for (var i = 0; i < 90000; i++) {
        final k = omenFace(Relic.warDrum, null, rng.nextDouble())!;
        n[k] = (n[k] ?? 0) + 1;
      }
      expect(n[thorns]! / 90000, closeTo(2 / 9 + 7 / 9 / n7, 0.01));
      for (final k in pool.where((k) => k != thorns)) {
        expect(n[k]! / 90000, closeTo(7 / 9 / n7, 0.01), reason: '$k');
      }
    });

    test('one omenDice draw a card, always 3 a roll (a Serpihan, a chest before omenFrom); the cards are the same on or off', () {
      List<List<Relic?>> deal(bool on, Random omens) {
        omensOn = on;
        final g = chested(wave: 9, draft: Random(5), omens: omens);
        g.giveChests(3); // waves 9: before omenFrom
        g.wave = 29;
        g.giveChests(3);
        g.rerollChest();
        for (final r in Relic.values.where((r) => r.pusaka)) {
          g.givePusaka(r, stars: starMax); // nothing left: Serpihan
        }
        g.giveChests(1);
        return [for (final c in g.chests) c.cards!];
      }

      final dice = _Seq([0.5]);
      final on = deal(true, dice);
      expect(dice.draws, 3 * 8, reason: '7 chests and a reroll');
      expect(deal(false, _Seq([0.5])), on);
      omensOn = true;
      final g = chested(wave: 9, omens: _Seq([0.0]));
      g.giveChests(1);
      expect(g.chest!.omens, [null, null, null], reason: 'before omenFrom');
      g.wave = omenFrom;
      g.giveChests(1);
      expect(g.chests.last.omens, [for (final r in g.chests.last.cards!) pusakaCatalog[r]!.counter]);
      for (final r in Relic.values.where((r) => r.pusaka)) {
        g.givePusaka(r, stars: starMax);
      }
      g.giveChests(1);
      expect([g.chests.last.cards, g.chests.last.omens], [[null, null, null], [null, null, null]], reason: 'Serpihan');
    });

    test('the take: Langka 1, Epik 2, Legenda 3 levels of the taken face only; levels act from the next wave', () {
      for (final (dice, gained) in [(langkaDice(), 1), (epikDice(), 2), (legendaDice(), 3)]) {
        final g = chested(draft: dice, omens: _Seq([0.0]));
        g.giveChests(1);
        final c = g.chest!, relic = c.cards![0]!;
        expect(c.omens, [for (final r in c.cards!) pusakaCatalog[r]!.counter]);
        expect(g.takeCard(0), isTrue);
        final face = pusakaCatalog[relic]!.counter;
        expect(levels(g), {face: gained}, reason: '$relic');
        expect(g.omens, List.filled(gained, face));
      }
    });

    test('a reroll draws new faces; the taken one counts, the rest go unseen', () {
      final dice = _Seq([0.0, 0.0, 0.0, 0.99, 0.99, 0.99]);
      final g = chested(draft: langkaDice(), omens: dice);
      g.giveChests(1);
      expect(g.chest!.omens, [haste, wound, thorns]); // Iron Banner, Blood Fang, War Drum's counters
      expect(g.rerollChest(), isTrue);
      // 0.99: the Langka pool's last kind that acts on this army (Straggler since batch L-2B; it needs nothing).
      expect([dice.draws, g.chest!.omens], [6, [OmenKind.straggler, OmenKind.straggler, OmenKind.straggler]]);
      g.takeCard(1);
      expect(levels(g), {OmenKind.straggler: 1});
    });

    test('overflow: past omenCap to the next kind of the pool (round to its start); "penuh" when all are full', () {
      final pool = OmenKind.values.take(7).toList(); // today's seven, a pool of their own (omenPlace takes any)
      expect(omenPlace([], armor, pool, 3), [armor, armor, armor]);
      expect(omenPlace(List.filled(3, armor), armor, pool, 3), [armor, haste, haste]);
      expect(omenPlace([...List.filled(4, guard), ...List.filled(4, armor)], guard, pool, 2), [haste, haste]);
      final full = [for (final k in pool) ...List.filled(omenCap, k)];
      expect(full.length, 28);
      expect(omenPlace(full, wound, pool, 3), isEmpty);
      expect(omenPlace([...full]..removeLast(), wound, pool, 3), [guard]);
      // At most omenKindsMax kinds held: a new kind is full while that many are (here 2).
      expect(omenPlace([armor, haste], mend, pool, 2, kindsMax: 2), [armor, armor]);
      expect(omenPlace([armor], mend, pool, 2, kindsMax: 2), [mend, mend]);
      // Through a take: an Epik's 2 levels on a kind at 3 split along the Epik pool, and with omenKindsMax kinds full (the
      // seven and Dark Hymn) the card gives none.
      const wearDown = OmenKind.wearDown, blindside = OmenKind.blindside;
      final g = chested(draft: epikDice(), omens: _Seq([0.0]));
      g.omens.addAll(List.filled(3, wearDown));
      g.giveChests(1);
      final events = <GameEvent>[];
      g.listeners.add(events.add);
      g.takeCard(0); // Dragon Heart: Wear Down
      expect(levels(g), {wearDown: 4, blindside: 1});
      final picked = events.whereType<OfferPicked>().single;
      expect([picked.omen, picked.levels], [wearDown, [wearDown, blindside]]);
      expect([for (final e in events.whereType<OmenGained>()) (e.omen, e.level, e.gained, e.from, e.chestWave)],
          [(wearDown, 4, 1, 'chest', 29), (blindside, 1, 1, 'chest', 29)]);
      g.omens
        ..clear()
        ..addAll([...full, ...List.filled(omenCap, OmenKind.darkHymn)]);
      g.giveChests(1);
      events.clear();
      g.takeCard(0);
      expect([g.omens.length, events.whereType<OfferPicked>().single.levels, events.whereType<OmenGained>()], [32, isEmpty, isEmpty]);
    });

    test('a card openChest turns into a Serpihan loses its face; an old chest without faces gives none', () {
      final g = chested(draft: langkaDice(), omens: _Seq([0.0]));
      g.giveChests(1);
      g.givePusaka(g.chest!.cards![1]!, stars: starMax);
      expect(g.openChest(), [Relic.ironBanner, null, Relic.warDrum]);
      expect(g.chest!.omens, [haste, null, thorns]);
      g.takeCard(1); // the Serpihan
      expect([g.omens, g.serpihan], [isEmpty, 1]);
      // A chest from before the Bayangan (no faces): its card gives none.
      final old = Chest.fromJson({'kind': 'boss', 'wave': 25, 'cards': ['grail', 'voidEye', 'dawnStar']});
      expect(old.omens, isNull);
      g.chests.add(old);
      final events = <GameEvent>[];
      g.listeners.add(events.add);
      expect(g.takeCard(0), isTrue);
      expect(g.omens, isEmpty);
      final picked = events.whereType<OfferPicked>().single;
      expect([picked.omen, picked.levels], [null, isEmpty]);
    });

    test('Lewati gives no Bayangan: its gold as before, and from omenFrom the next wave owes the skip buff, once', () {
      final g = chested(omens: _Seq([0.0]));
      g.giveChests(2);
      final gold = g.gold, gain = g.skipGold;
      expect(g.skipChest(), gain);
      expect([g.gold, g.omens, g.skipBuffDue], [gold + gain, isEmpty, true]);
      expect(gain, (rerollPrice(g.wave) * skipShare).round(), reason: "Lewati's gold stays as today");
      final back = roundTrip(g);
      expect([back.skipBuffDue, roundTrip(g).toJson()['skipBuffDue']], [true, true]);
      g.skipChest(); // a second Lewati: still one wave's buff
      nextWave(g);
      expect([g.waveSkipBuff, g.skipBuffDue], [true, false]);
      expect(g.toJson().containsKey('skipBuffDue'), isFalse);
      nextWave(g);
      expect(g.waveSkipBuff, isFalse, reason: 'one wave only');
      // Before omenFrom no buff is owed.
      final early = chested(wave: 9)..giveChests(1);
      early.skipChest();
      expect(early.skipBuffDue, isFalse);
    });

    test('the save: levels (oldest first), the catch-up owed, the skip buff and the chests\' faces round-trip by name', () {
      final g = chested(draft: langkaDice(), omens: _Seq([0.0, 0.99, 0.5]));
      g.omens.addAll([mend, armor, mend]);
      g.omensOwed.addAll([wound, haste]);
      g.skipBuffDue = true;
      g.giveChests(1);
      final saved = jsonDecode(jsonEncode(g.toJson())) as Map<String, dynamic>;
      expect([saved['omens'], saved['omensOwed'], saved['skipBuffDue']], [['mend', 'armor', 'mend'], ['wound', 'haste'], true]);
      expect((saved['chests'] as List).single['omens'], ['haste', 'straggler', 'thrift']); // the Langka pool's faces (L-3's 30)
      final back = Game.fromJson(saved);
      expect([back.omens, back.omensOwed, back.skipBuffDue, back.chest!.omens, back.omenCaughtUp],
          [[mend, armor, mend], [wound, haste], true, [haste, OmenKind.straggler, OmenKind.thrift], false]);
      // A new game writes its (empty) levels, so it never counts as an old save.
      final fresh = Game();
      expect(fresh.toJson()['omens'], isEmpty);
      expect(roundTrip(fresh).omensOwed, isEmpty);
      // An unknown kind is skipped; a face past the cards is none.
      final odd = Game.fromJson(saved
        ..['omens'] = ['mend', 'nope']
        ..['chests'] = [
          {'kind': 'boss', 'wave': 30, 'cards': ['grail', 'voidEye'], 'omens': ['nope']}
        ]);
      expect([odd.omens, odd.chest!.omens], [[mend], [null, null]]);
    });

    test("b86's catch-up: exactly Wear Down 2 / Heal Siphon 2 / Mend 2 / Prey 2 / Armor 2, dealt round-robin, landing 2 a "
        'wave, once', () {
      const wearDown = OmenKind.wearDown, siphon = OmenKind.healSiphon, prey = OmenKind.prey;
      final g = Game.fromJson(b86());
      expect(g.pusaka[Relic.dawnStar]!.type, 'priest', reason: 'bound by default to the priests: Heal Siphon');
      expect(g.omensOwed, [wearDown, siphon, mend, prey, armor, wearDown, siphon, mend, prey, armor]);
      expect([g.omens, g.omenCaughtUp], [isEmpty, true]);
      final events = <GameEvent>[];
      g.listeners.add(events.add);
      for (var w = 87; w <= 91; w++) {
        nextWave(g);
        expect([g.wave, g.omens.length, g.omensOwed.length], [w, 2 * (w - 86), 10 - 2 * (w - 86)]);
      }
      expect(levels(g), {wearDown: 2, siphon: 2, mend: 2, prey: 2, armor: 2});
      expect(events.whereType<OmenGained>().every((e) => e.from == 'catchUp'), isTrue);
      expect([for (final e in events.whereType<OmenGained>().take(3)) (e.omen, e.level, e.gained)], [(wearDown, 1, 1), (siphon, 1, 1), (mend, 1, 1)]);
      nextWave(g);
      expect(g.omens.length, 10);
      // Once: saved with its levels, the save is no longer an old one.
      final back = roundTrip(g);
      expect([levels(back), back.omensOwed, back.omenCaughtUp], [{wearDown: 2, siphon: 2, mend: 2, prey: 2, armor: 2}, isEmpty, false]);
      // Saved halfway, the rest still lands.
      final half = Game.fromJson(b86());
      nextWave(half);
      final again = roundTrip(half);
      expect([again.omens.length, again.omensOwed.length], [2, 8]);
    });

    test("w89: 19 owed, so 12, round-robin over its six Pusaka (Alliance's Guard too)", () {
      final g = Game.fromJson(w89());
      final total = [for (final MapEntry(key: r, value: p) in g.pusaka.entries) omenMarks[r.rarity]! * p.stars].fold(0, (a, b) => a + b);
      expect(total, 19);
      const six = [OmenKind.wearDown, armor, mend, OmenKind.prey, armor, guard]; // Dragon Heart's and the Grail's switched
      expect(g.omensOwed, [...six, ...six]);
      expect(g.omensOwed.length, omenCatchUpMax);
      // A save with no Pusaka owes none.
      expect(Game.fromJson(w89()..remove('pusaka')).omensOwed, isEmpty);
    });

    test('the Beban factor, frozen at the wave start: armySize / armyCap from 1 to 2; E = level × factor', () {
      final g = Game.fromJson(b86())..armyMax = armyMaxBoard;
      expect([g.armySize, g.armyCap], [48, 36]); // the board's 36 (decisions-log 260)
      final starts = <WaveStarted>[];
      g.listeners.add((e) {
        if (e is WaveStarted) starts.add(e);
      });
      nextWave(g);
      expect(g.omenFactor, 48 / 36);
      expect(g.omenE(OmenKind.wearDown), 1 * 48 / 36, reason: "the first two owed: Wear Down's and Heal Siphon's");
      expect(g.omenE(guard), 0);
      expect(starts.single.omens, {'levels': {'wearDown': 1, 'healSiphon': 1}, 'factor': 1.3333, 'owed': 8, 'skipBuff': false});
      g.armyMax = 20;
      nextWave(g);
      expect(g.omenFactor, omenOverMax);
      g.armyMax = 64;
      nextWave(g);
      expect(g.omenFactor, 1.0);
      g.armyMax = null;
      nextWave(g);
      expect(g.omenFactor, 1.0);
      omensOn = false;
      expect(g.omenE(OmenKind.wearDown), 0);
    });

    test('the ease: each full eighth of the starting troops fallen takes the newest level, at most 2 a wave', () {
      Game army(int n) {
        final g = chested(wave: 30);
        for (var i = 0; i < n; i++) {
          placeNow(g, 'archer', i ~/ rows, i % rows);
        }
        g.omens.addAll([armor, haste, mend, wound, thorns]);
        return g;
      }

      final g = army(16); // an eighth is 2
      final events = <GameEvent>[];
      g.listeners.add(events.add);
      win(g, fell: 1);
      expect(g.omens.length, 5);
      win(g, fell: 3);
      expect(g.omens, [armor, haste, mend, wound]);
      expect([for (final e in events.whereType<OmenEased>()) (e.omen, e.level, e.wave)], [(thorns, 0, 32)]);
      win(g, fell: 16);
      expect(g.omens, [armor, haste], reason: 'at most omenEaseMax');
      final h = army(48);
      win(h, fell: 5);
      expect(h.omens.length, 5);
      win(h, fell: 6);
      expect(h.omens.length, 4, reason: '6 of 48');
    });

    test('telemetry 8: the faces, the take, the levels and the wave start in the records', () {
      expect([eventVersion >= 8, telemetryVersion >= 8], [true, true]); // 8 brought the Omens; later versions keep it
      expect(passedOn, containsAll([EventKind.omenGained, EventKind.omenEased]));
      final sink = _Kept();
      final g = chested(draft: langkaDice(), omens: _Seq([0.0]));
      final adapter = TelemetryAdapter([sink], installId: 'i', session: 's', platform: 'test', now: () => DateTime.utc(2026, 10, 3))
        ..attach(g);
      g.giveChests(1);
      g.takeCard(0);
      nextWave(g);
      adapter.detach();
      expect(sink.events('offerShown').single['omens'], ['haste', 'wound', 'thorns']);
      final picked = sink.events('offerPicked').single;
      expect([picked['v'], picked['omen'], picked['levels'], picked['skipBuff']], [eventVersion, 'haste', ['haste'], false]);
      expect(sink.events('omenGained').single, containsPair('omen', 'haste'));
      final wave = sink.records.lastWhere((r) => r['rec'] == 'wave');
      expect([wave['tv'], (wave['start'] as Map)['omens']], [telemetryVersion, {'levels': {'haste': 1}, 'factor': 1.0, 'owed': 0, 'skipBuff': false}]);
    });

    test("the battle log's lines, in simple English (the owner's rule: all in-game text is English)", () {
      expect(logLine(OmenGained(90, 0, omen: armor, level: 2, gained: 2, from: 'chest', chestWave: 90)), 'Monsters got Armor 2 (Boss Chest w90)');
      expect(logLine(OmenGained(91, 0, omen: wound, level: 2, gained: 1, from: 'catchUp')), 'Late Shadow: Wound 2');
      expect(logLine(OmenGained(92, 0, omen: haste, level: 1, gained: 1, from: 'ukir')), 'Carve: monsters got Haste 1');
      expect(logLine(OmenEased(93, 0, omen: armor, level: 1)), 'Shadow eased: Armor down to 1');
    });

    test('policyPick never reads a face: a probe takes the same cards on or off', () {
      List<String> run(bool on) {
        omensOn = on;
        final g = chested(draft: Random(4), omens: Random(9))..draftPolicy = 'rarity';
        for (var i = 0; i < 6; i++) {
          g.giveChests(1);
          g.pickChests();
        }
        return [for (final MapEntry(key: r, value: p) in g.pusaka.entries) '${r.name} ${p.stars}'];
      }

      expect(run(true), run(false));
    });
  });
}
