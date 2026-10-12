// Asah (P6, decisions-log 154; docs/loot-items-relics.md "Asah", ui-hud.md "Tas"): between waves a Pusaka owned gains a
// star for gold (60k to ★2, 150k to ★3) and 10 small relics from the bag, the cheapest kinds first, once per boss
// interval across all Pusaka. The prices, the relics taken, each refusal in the design's order, the stars rising and
// the troops refitting with the burst, the event, the log's lines and the telemetry's gold.asahSpent, a save round
// trip; on the Tas page the button in two taps, a refusal's message, and the strip fitting 1266x713 and 915x412. One
// TdGame per widget test.
//
// Never let a wave be won or the game end in a widget test (the Board then saves); the rule tests win waves on a plain
// Game, which saves nothing.
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flame/game.dart' hide Game;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';
import 'package:tower_defense/main.dart';
import 'package:tower_defense/telemetry.dart';

import 'hud_font.dart';

/// The owner's wave-86 save from before the Pusaka (a copy; never the real save): its five Pusaka bound by default at
/// ★1 (Dragon Heart on the 13 Templar), 1.8M gold, and in the bag Taring 17, Duri 29, Amarah 23, Pelindung 21.
Game w86() => Game.fromJson(jsonDecode(File('test/fixtures/save-20261001-2005-pre-awaken.json').readAsStringSync()) as Map<String, dynamic>);

/// [g] through its save, as a reload has it.
Game reload(Game g) => Game.fromJson(jsonDecode(jsonEncode(g.toJson())) as Map<String, dynamic>);

/// The small relics' counts in [g]'s bag, Taring, Duri, Amarah, Pelindung.
List<int> bag(Game g) => [for (final r in droppedRelics) g.relicBag[r] ?? 0];

/// Wins the next wave of [g] at once: begun with nothing to spawn, its one monster gone in the tick (draft_test.dart).
void win(Game g) {
  g
    ..startWave()
    ..queue.clear()
    ..units.add(g.monster('slime', Tier.normal, const Point(300, 60))..gone = true)
    ..tick(0.05);
  expect((g.waveActive, g.over), (false, false));
}

/// A sink that keeps the records, through JSON.
class _Kept implements TelemetrySink {
  final records = <Map<String, dynamic>>[];

  @override
  void add(Map<String, Object?> record) => records.add(jsonDecode(jsonEncode(record)) as Map<String, dynamic>);

  @override
  Future<void> flush() async {}
}

/// Boots one TdGame in a [size] window, past the welcome screen, with the game's font and the minimap folded.
Future<Board> boot(WidgetTester tester, [Size size = const Size(1266, 713)]) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await loadHudFont(tester);
  final game = TdGame();
  await tester.pumpWidget(GameWidget(game: game));
  for (var i = 0; i < 3000 && !game.isLoaded; i++) {
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 20)));
    await tester.pump();
  }
  expect(game.isLoaded, isTrue);
  return game.board
    ..welcome = null
    ..miniMapOpen = false;
}

Future<void> frames(WidgetTester tester, [int n = 2]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

Future<void> tapOn(WidgetTester tester, Offset p) async {
  await tester.tapAt(p);
  await frames(tester);
}

/// Turns the open book to its Tas page, after closing the message window (the save's notes can lie over the tabs).
Future<void> openBag(WidgetTester tester, Board b) async {
  if (b.messageBox != Rect.zero) await tapOn(tester, b.messageBox.center);
  await tapOn(tester, b.bookTabs.firstWhere((t) => t.$1 == 'bag').$2.center);
  expect(b.bagOpen, isTrue);
}

void main() {
  test('the prices: 60k to Bintang 2, 150k to Bintang 3, 10 small relics each; none past 3, none for one not owned', () {
    expect(asahPrice, [60000, 150000]);
    expect((asahRelics, starMax), (10, 3));
    final g = w86();
    expect((g.pusaka[Relic.dragonHeart]!.stars, g.asahPriceOf(Relic.dragonHeart)), (1, 60000));
    g.pusaka[Relic.dragonHeart]!.stars = 2;
    expect(g.asahPriceOf(Relic.dragonHeart), 150000);
    g.pusaka[Relic.dragonHeart]!.stars = 3;
    expect(g.asahPriceOf(Relic.dragonHeart), isNull);
    expect(g.asahPriceOf(Relic.ironBanner), isNull); // not owned
    for (final r in Relic.values.where((r) => r.pusaka && r.rarity == Rarity.legenda)) {
      g.givePusaka(r); // a Legenda stays at ★1 (design §3.4), once P5 brings them
      expect((g.asahPriceOf(r), g.whyNotAsah(r)), (null, asahRefusals.legend), reason: '$r');
    }
  });

  test('the small relics come from the bag one at a time, the cheapest kinds first (by craft gold), among them the kind it '
      'holds most of then (ties: Taring first): the owner\'s bag gives Thorns 10', () {
    final g = w86();
    expect(bag(g), [17, 29, 23, 21]);
    expect(g.asahRelicsInBag, 90);
    expect(g.asahTake, {Relic.thorns: 10}); // Fang and Thorns 300 each, Thorns the more held (town_craft_test.dart)
    expect(asahTakeLine(g.asahTake), '${relicNames[Relic.thorns]} 10');
    // An even bag: the 300s (Fang, Thorns) first, then the 400s, Fang first on every tie, round and round.
    for (final r in droppedRelics) {
      g.relicBag[r] = 3;
    }
    expect(g.asahTake, {Relic.fang: 3, Relic.thorns: 3, Relic.fury: 2, Relic.guard: 2});
    // One kind alone, and a bag with fewer than 10: all of it (the refusal says why: below).
    g.relicBag
      ..[Relic.fang] = 0
      ..[Relic.thorns] = 12
      ..[Relic.fury] = 0
      ..[Relic.guard] = 0;
    expect(g.asahTake, {Relic.thorns: 10});
    g.relicBag[Relic.thorns] = 4;
    g.relicBag[Relic.guard] = 2;
    expect(g.asahTake, {Relic.thorns: 4, Relic.guard: 2});
    expect(g.asahRelicsInBag, 6);
  });

  test('an Asah raises the star, takes the gold and the relics, refits the type\'s troops at once with the burst, and is '
      'logged; one per boss interval', () {
    final g = w86()..dismissPusakaNote();
    final templars = g.troops.where((u) => u.alive && u.type == 'knight_templar').toList();
    expect(templars.length, 13);
    expect(templars.map((u) => u.maxHp).toSet(), {927});
    final gold = g.gold, hp = {for (final u in templars) u: u.hp};
    g
      ..sfx.clear()
      ..impacts.clear();
    expect(g.whyNotAsah(Relic.dragonHeart), isNull);
    expect(g.asah(Relic.dragonHeart), isTrue);
    expect((g.pusaka[Relic.dragonHeart]!.stars, g.pusaka[Relic.dragonHeart]!.type, g.gold), (2, 'knight_templar', gold - 60000));
    expect(bag(g), [17, 19, 23, 21]);
    // Refit at once: 504 in the book, ×2.2 (Dragon Heart ★2), with the Hero's aura on the field; the HP gained added.
    final maxHp = g.fieldStats('knight_templar').hp;
    expect(maxHp, greaterThan(927));
    expect(templars.map((u) => u.maxHp).toSet(), {maxHp});
    for (final u in templars) {
      expect(u.hp, min(hp[u]! + maxHp - 927, maxHp.toDouble()), reason: u.name); // the HP gained, at once
    }
    expect(g.impacts.length, 13); // a gold burst on each, as the chest's pick
    expect(g.impacts.map((i) => i.$2).toSet(), {awakeFx('upgrade', maxAwaken)});
    expect(g.sfx, [Sfx.clear]);
    final e = g.log.entries.whereType<PusakaAsah>().single;
    expect(e.toJson(), {
      'v': eventVersion,
      'kind': 'pusakaAsah',
      'wave': 86,
      't': g.t,
      'relic': 'dragonHeart',
      'stars': 2,
      'type': 'knight_templar',
      'cost': 60000,
      'relics': {'thorns': 10},
    });
    expect(eventVersion, greaterThanOrEqualTo(4)); // 4: Asah's event; later versions keep it
    expect(logLines(e), ['Sharpen: Dragon Heart ★2 on Templar (60k gold)', '${relicNames[Relic.thorns]} 10 from the Bag']);

    // Once per boss interval, across all Pusaka: waves 86 to 89 are one (the next Asah after the wave-90 boss).
    expect((g.asahAt, g.asahDone, g.asahAgainAt), (86, true, 90));
    expect(g.whyNotAsah(Relic.grail), asahRefusals.once);
    g.sfx.clear();
    expect(g.asah(Relic.grail), isFalse);
    expect((g.pusaka[Relic.grail]!.stars, g.gold), (1, gold - 60000));
    expect(g.sfx, [Sfx.error]);
    for (var i = 0; i < 3; i++) {
      win(g); // 87, 88, 89
    }
    expect((g.wave, g.whyNotAsah(Relic.grail)), (89, asahRefusals.once));
    win(g); // the boss's wave
    expect((g.wave, g.asahDone, g.whyNotAsah(Relic.dragonHeart)), (90, false, null));
    expect(g.asahPriceOf(Relic.dragonHeart), 150000);
    expect(g.asah(Relic.dragonHeart), isTrue);
    expect((g.pusaka[Relic.dragonHeart]!.stars, g.asahAt, g.asahAgainAt), (3, 90, 95));
    // A Pusaka in the Gudang rises too, nobody refit; logged "di Gudang".
    g
      ..wave = 95
      ..unbindPusaka(Relic.voidEye);
    g.impacts.clear();
    expect(g.asah(Relic.voidEye), isTrue);
    expect(g.pusaka[Relic.voidEye]!.stars, 2);
    expect(g.impacts, isEmpty);
    expect(logLine(g.log.entries.whereType<PusakaAsah>().last), 'Sharpen: Void Eye ★2 in Vault (60k gold)');
  });

  test('the refusals, in the design\'s order: mid-wave, already this boss interval, the gold, the relics, then a Legenda '
      'or one at Bintang 3; after game over and for one not owned the game\'s own', () {
    final g = w86()..dismissPusakaNote();
    String? why() => g.whyNotAsah(Relic.grail);
    expect(why(), isNull);
    expect(g.whyNotAsah(Relic.ironBanner), pusakaRefusals.none);
    // The relics short (9 in the bag), then the gold too: the gold is said first.
    for (final r in droppedRelics) {
      g.relicBag[r] = 0;
    }
    g.relicBag[Relic.fury] = 9;
    expect(why(), asahRefusals.relics);
    expect(asahRefusals.relics, 'Not enough relics (need 10)');
    g.gold = 59999;
    expect(why(), asahRefusals.gold);
    expect(asahRefusals.gold, Words.notEnoughGold);
    // An Asah done in this boss interval goes before both.
    g.asahAt = 85;
    expect(why(), asahRefusals.once);
    expect(asahRefusals.once, 'Already sharpened this round');
    // And a wave on before everything.
    g.startWave();
    expect(why(), asahRefusals.midWave);
    final sfx = g.sfx.length, gold = g.gold;
    expect(g.asah(Relic.grail), isFalse);
    expect((g.sfx.length, g.sfx.last, g.gold, g.pusaka[Relic.grail]!.stars, g.relicBag[Relic.fury]), (sfx + 1, Sfx.error, gold, 1, 9));

    // At Bintang 3 there is no price, so neither the gold nor the relics are asked.
    final h = w86()..dismissPusakaNote();
    h.pusaka[Relic.grail]!.stars = 3;
    expect(h.whyNotAsah(Relic.grail), asahRefusals.maxed);
    expect(asahRefusals.maxed, 'Already ★3');
    h.gold = 0;
    expect(h.whyNotAsah(Relic.grail), asahRefusals.maxed);
    h.asahAt = 86;
    expect(h.whyNotAsah(Relic.grail), asahRefusals.once); // the design's order: the interval first
    h.lives = 0; // game over
    expect(h.whyNotAsah(Relic.grail), assignRefusals.over);
  });

  test('the save keeps the Asah\'s wave (asahAt), the stars and the bag: a reload is still refused until the boss; a save '
      'without the key (from before Asah) has none', () {
    final g = w86()..dismissPusakaNote();
    expect(g.toJson().containsKey('asahAt'), isFalse);
    expect(reload(g).asahAt, isNull);
    g.asah(Relic.grail);
    expect(g.toJson()['asahAt'], 86);
    final r = reload(g);
    expect((r.asahAt, r.pusaka[Relic.grail]!.stars, r.gold), (86, 2, g.gold));
    expect(bag(r), [17, 19, 23, 21]);
    expect(r.whyNotAsah(Relic.dragonHeart), asahRefusals.once);
    expect(r.wave, 86);
  });

  test('telemetry: the event is passed on, and the next wave\'s record has gold.asahSpent (since version 4)', () {
    final g = w86()..dismissPusakaNote();
    final kept = _Kept();
    TelemetryAdapter([kept], installId: 'i', session: 's', platform: 'test', now: () => DateTime.utc(2026, 10, 2)).attach(g);
    g.asah(Relic.dragonHeart);
    win(g);
    final events = [for (final r in kept.records.where((r) => r['rec'] == 'event')) r['event'] as Map<String, dynamic>];
    final e = events.singleWhere((e) => e['kind'] == 'pusakaAsah');
    expect((e['relic'], e['stars'], e['cost']), ('dragonHeart', 2, 60000));
    expect(e['relics'], {'thorns': 10});
    final w = kept.records.lastWhere((r) => r['rec'] == 'wave');
    expect((w['wave'], (w['gold'] as Map)['asahSpent'], w['tv']), (87, 60000, telemetryVersion));
    expect(telemetryVersion, greaterThanOrEqualTo(4)); // 4 brought Asah; later versions keep it
    win(g);
    expect((kept.records.lastWhere((r) => r['rec'] == 'wave')['gold'] as Map)['asahSpent'], 0); // since then
  });

  test("every line Asah shows is in the HUD's font (a '★' is drawn as the star icon, so it is left out)", () {
    final font = fontChars();
    final g = w86();
    final lines = <String>[
      ...[asahRefusals.midWave, asahRefusals.once, asahRefusals.gold, asahRefusals.relics, asahRefusals.legend, asahRefusals.maxed],
      Words.sure, Words.sharpen, '${Words.sharpen} ★2', '${asahRefusals.once}: again after wave 90', 'Sharpened: again after wave 90',
      'Again after wave 90', 'Again after w90', ' + relics 7/10', ' + ${asahTakeLine(g.asahTake)}', ' + 10 relics', '60k',
      for (final r in Relic.values)
        if (r.pusaka) ...[
          '${relicNames[r]} ★2! -60k, ${asahTakeLine({Relic.fang: 1, Relic.thorns: 3, Relic.fury: 3, Relic.guard: 3})}',
          for (final type in [null, ...troopTypes.keys])
            ...logLines(PusakaAsah(86, 0, relic: r, stars: 3, type: type, cost: 150000, relics: {Relic.guard: 6, Relic.fang: 4})),
        ],
    ];
    for (final line in lines) {
      expect([for (final ch in line.replaceAll('★', '').runes) if (!font.contains(ch)) String.fromCharCode(ch)], isEmpty, reason: line);
    }
  });

  testWidgets('the Asah button on a Pusaka\'s facing page: two taps raise it and say what was taken; the next one says '
      'why not; mid-wave it is greyed', (tester) async {
    final b = await boot(tester);
    final g = b.state = w86().boardRules()..chests.clear(); // its catch-up chests' popup would take the taps
    g.dismissPusakaNote();
    await frames(tester, 50);
    await openBag(tester, b);
    expect(b.asahButton, Rect.zero); // nothing picked
    await tapOn(tester, b.bagSlot(Relic.dragonHeart).center);
    expect(b.picked, Relic.dragonHeart);
    expect(b.asahButton, isNot(Rect.zero));
    final gold = g.gold;
    // The first tap arms it ("Sure?"), nothing spent; the second raises it.
    await tapOn(tester, b.asahButton.center);
    expect((b.asahArmed, g.pusaka[Relic.dragonHeart]!.stars, g.gold), (Relic.dragonHeart, 1, gold));
    await tapOn(tester, b.asahButton.center);
    expect((b.asahArmed, g.pusaka[Relic.dragonHeart]!.stars, g.gold), (null, 2, gold - 60000));
    expect(b.message, 'Dragon Heart ★2! -60k, ${relicNames[Relic.thorns]} 10'); // the cheapest first (Fang, Thorns)
    expect(g.troops.where((u) => u.alive && u.type == 'knight_templar').map((u) => u.maxHp).toSet(), {g.fieldStats('knight_templar').hp});
    // Another Pusaka in the same boss interval: a tap says why, and arms nothing.
    await tapOn(tester, b.bagSlot(Relic.grail).center);
    expect(b.picked, Relic.grail);
    await tapOn(tester, b.asahButton.center);
    expect((b.asahArmed, b.message, g.pusaka[Relic.grail]!.stars), (null, asahRefusals.once, 1));
    // Mid-wave: refused before all else.
    g
      ..asahAt = null
      ..startWave(); // the book shuts for the wave
    await frames(tester, 40);
    await tapOn(tester, b.bookButton.center);
    await frames(tester, 40);
    await openBag(tester, b);
    await tapOn(tester, b.bagSlot(Relic.grail).center);
    await tapOn(tester, b.asahButton.center);
    expect((b.asahArmed, b.message, g.pusaka[Relic.grail]!.stars), (null, asahRefusals.midWave, 1));
    await frames(tester, 10); // the last tap's gesture timers run out
  });

  testWidgets('the Sharpen row fits 1266x713 and 915x412 (decisions-log 202): an action row on the facing page under its '
      'heading, its tag inside it, clear of the other rows', (tester) async {
    final b = await boot(tester);
    for (final size in const [Size(1266, 713), Size(915, 412)]) {
      tester.view.physicalSize = size;
      final g = b.state = w86().boardRules()..chests.clear();
      g.dismissPusakaNote();
      await frames(tester, 50);
      await openBag(tester, b);
      await tapOn(tester, b.bagSlot(Relic.dragonHeart).center);
      expect(b.picked, Relic.dragonHeart, reason: '$size');
      final btn = b.asahButton, list = b.assignList, book = b.bookArea, row = b.bagAction(BagAction.sharpen);
      expect(btn, isNot(Rect.zero), reason: '$size');
      expect(btn.left >= list.left && btn.right <= list.right + 0.5, isTrue, reason: '$size Asah $btn in the list $list');
      expect(book.contains(btn.topLeft) && book.contains(btn.bottomRight - const Offset(0.5, 0.5)), isTrue, reason: '$size $btn in $book');
      expect(row.inflate(0.5).contains(btn.topLeft) && row.inflate(0.5).contains(btn.bottomRight), isTrue, reason: '$size $btn on its row $row');
      expect(b.assignRows, isNotEmpty, reason: '$size');
      for (final (who, r, _) in b.assignRows) {
        expect(r.overlaps(btn), isFalse, reason: '$size $who row $r over Asah $btn');
      }
      expect(btn.height, greaterThanOrEqualTo(20), reason: '$size a finger\'s press');
      await tapOn(tester, b.bagSlot(Relic.dragonHeart).center); // put back
      expect(b.asahButton, Rect.zero, reason: '$size');
    }
    await frames(tester, 10);
  });
}
