// Lebur (J3, decisions-log 164; docs/loot-items-relics.md "Lebur", ui-hud.md "Tas"): between waves a Pusaka in the
// Gudang is melted into another one owned, which gains a star at Asah's price by its stars (60k to ★2, 150k to ★3), with
// no small relics and no limit per boss interval. The constants and prices, a Lebur (the fodder gone with its stars,
// the target's star, the troops refit with the burst, the event, the log's line), the fodder offerable on a chest again,
// Asah's interval untouched both ways, each refusal and their order, a save round trip and the telemetry's
// gold.leburSpent; on the Tas page the button beside Jual, the picker in two taps, a refusal's message. The picker
// fitting 1266x713 and 915x412 is pusaka_tas_ui_test.dart's. One TdGame per widget test.
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
/// ★1 (Dragon Heart on the 13 Templar, Void Eye on the archers), 1.8M gold, its note shown and kept.
Game w86() =>
    Game.fromJson(jsonDecode(File('test/fixtures/save-20261001-2005-pre-awaken.json').readAsStringSync()) as Map<String, dynamic>)
      ..dismissPusakaNote();

/// [g] through its save, as a reload has it.
Game reload(Game g) => Game.fromJson(jsonDecode(jsonEncode(g.toJson())) as Map<String, dynamic>);

/// The small relics' counts in [g]'s bag, Taring, Duri, Amarah, Pelindung.
List<int> bag(Game g) => [for (final r in droppedRelics) g.relicBag[r] ?? 0];

/// Wins the next wave of [g] at once: begun with nothing to spawn, its one monster gone in the tick (asah_test.dart).
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

/// The picker's row for [r] this frame (Rect.zero: not shown).
Rect rowOf(Board b, Relic r) => b.assignRows.where((row) => row.$1 == r).firstOrNull?.$2 ?? Rect.zero;

void main() {
  test('the constants: Asah\'s prices by the target\'s stars, one star, no small relics, apart from Asah, any rarity', () {
    expect(leburPrice, [60000, 150000]);
    expect(identical(leburPrice, asahPrice), isTrue); // Asah's own
    expect((leburStars, leburRelics, leburUsesAsah, leburRarity, starMax), (1, 0, false, false, 3));
    final g = w86();
    expect((g.pusaka[Relic.dragonHeart]!.stars, g.leburPriceOf(Relic.dragonHeart)), (1, 60000));
    g.pusaka[Relic.dragonHeart]!.stars = 2;
    expect(g.leburPriceOf(Relic.dragonHeart), 150000);
    g.pusaka[Relic.dragonHeart]!.stars = 3;
    expect(g.leburPriceOf(Relic.dragonHeart), isNull);
    expect(g.leburPriceOf(Relic.ironBanner), isNull); // not owned
    g.givePusaka(Relic.dragonCrown);
    expect(g.leburPriceOf(Relic.dragonCrown), isNull); // a Legenda stays ★1
    expect(g.leburTake, isEmpty);
    // What a Gudang one could go into: every Pusaka owned but itself and an oath, in Relic order.
    g
      ..givePusaka(Relic.oathOfOne)
      ..unbindPusaka(Relic.voidEye);
    expect(g.leburTargets(Relic.voidEye), [Relic.dragonHeart, Relic.dawnStar, Relic.godThunder, Relic.grail, Relic.dragonCrown]);
    expect(g.leburTargets(Relic.voidEye), isNot(contains(Relic.oathOfOne)));
  });

  test('a Lebur: the fodder is gone with its stars, the target gains a star for the price, its troops refit at once with '
      'the burst, the bag and Asah\'s interval untouched; logged', () {
    final g = w86()..unbindPusaka(Relic.voidEye);
    g.pusaka[Relic.voidEye]!.stars = 2; // its stars are lost with it
    final templars = g.troops.where((u) => u.alive && u.type == 'knight_templar').toList();
    expect(templars.length, 13);
    expect(templars.map((u) => u.maxHp).toSet(), {927});
    final gold = g.gold, relics = bag(g), hp = {for (final u in templars) u: u.hp};
    g
      ..sfx.clear()
      ..impacts.clear();
    expect(g.whyNotLebur(Relic.voidEye), isNull);
    expect(g.whyNotLebur(Relic.voidEye, Relic.dragonHeart), isNull);
    expect(g.lebur(Relic.voidEye, Relic.dragonHeart), isTrue);
    expect(g.pusaka.containsKey(Relic.voidEye), isFalse);
    expect(g.gudang, isEmpty);
    expect((g.pusaka[Relic.dragonHeart]!.stars, g.pusaka[Relic.dragonHeart]!.type, g.gold), (2, 'knight_templar', gold - 60000));
    expect(bag(g), relics); // leburRelics 0
    expect(g.asahAt, isNull); // Asah's interval untouched
    expect(g.whyNotAsah(Relic.grail), isNull);
    // Refit at once, as Asah's: Dragon Heart ★2 with the Hero's aura on the field, the HP gained added.
    final maxHp = g.fieldStats('knight_templar').hp;
    expect(maxHp, greaterThan(927));
    expect(templars.map((u) => u.maxHp).toSet(), {maxHp});
    for (final u in templars) {
      expect(u.hp, min(hp[u]! + maxHp - 927, maxHp.toDouble()), reason: u.name); // the HP gained, at once
    }
    expect(g.impacts.length, 13);
    expect(g.impacts.map((i) => i.$2).toSet(), {awakeFx('upgrade', maxAwaken)});
    expect(g.sfx, [Sfx.clear]);
    final e = g.log.entries.whereType<PusakaLebur>().single;
    expect(e.toJson(), {
      'v': eventVersion,
      'kind': 'pusakaLebur',
      'wave': 86,
      't': g.t,
      'fodder': 'voidEye',
      'fodderStars': 2,
      'relic': 'dragonHeart',
      'stars': 2,
      'type': 'knight_templar',
      'cost': 60000,
      'relics': <String, int>{},
    });
    expect(eventVersion, greaterThanOrEqualTo(7));
    expect(logLines(e), ['Melt: Void Eye into Dragon Heart ★2 on Templar (60k gold)']);

    // No limit per boss interval: an Asah, then another Lebur in the same interval; ★2 to ★3 costs 150k.
    expect(g.asah(Relic.grail), isTrue);
    expect((g.asahAt, g.asahDone), (86, true));
    g.unbindPusaka(Relic.godThunder);
    final before = g.gold;
    expect(g.whyNotLebur(Relic.godThunder, Relic.dragonHeart), isNull);
    expect(g.lebur(Relic.godThunder, Relic.dragonHeart), isTrue);
    expect((g.pusaka[Relic.dragonHeart]!.stars, g.gold, g.asahAt), (3, before - 150000, 86));
    // Into a Pusaka in the Gudang: it just rises, nobody refit; logged "di Gudang".
    g
      ..unbindPusaka(Relic.dawnStar)
      ..unbindPusaka(Relic.grail)
      ..impacts.clear();
    expect(g.lebur(Relic.dawnStar, Relic.grail), isTrue);
    expect(g.pusaka[Relic.grail]!.stars, 3);
    expect(g.impacts, isEmpty);
    expect(logLine(g.log.entries.whereType<PusakaLebur>().last), 'Melt: Dawn Star into Grail of Immortality ★3 in Vault (150k gold)');
  });

  test('the fodder can be dealt again: a ★3 one in the Gudang is on no chest card, melted it is', () {
    final g = w86().boardRules()..chests.clear();
    // Nothing else on a card: every other Pusaka owned at ★3, the Legenda found.
    for (final r in Relic.values.where((r) => r.pusaka && r.rarity != Rarity.legenda)) {
      if (g.pusaka[r] case final p?) {
        p.stars = 3;
      } else {
        g.givePusaka(r, stars: 3);
      }
    }
    g.legendsFound.addAll(Relic.values.where((r) => r.pusaka && r.rarity == Rarity.legenda));
    g
      ..unbindPusaka(Relic.voidEye)
      ..pusaka[Relic.dragonHeart]!.stars = 2; // the target: one star to give
    g.giveChests(1);
    expect(g.chests.single.cards, [Relic.dragonHeart, null, null]);
    g.chests.clear();
    expect(g.lebur(Relic.voidEye, Relic.dragonHeart), isTrue);
    expect(g.pusaka[Relic.dragonHeart]!.stars, 3);
    g.giveChests(1);
    expect(g.chests.single.cards, [Relic.voidEye, null, null]);
    // Taken again, it comes back at ★1.
    expect(g.takeCard(0), isTrue);
    expect(g.pusaka[Relic.voidEye]!.stars, 1);
  });

  test('the refusals, in their order: the fodder (in the Gudang, between waves, not a Legenda, with some Pusaka to take '
      'its star), then the target (not itself, owned, not a Legenda, under ★3, the gold); after game over the game\'s own', () {
    final g = w86()..unbindPusaka(Relic.voidEye);
    String? why([Relic target = Relic.dragonHeart]) => g.whyNotLebur(Relic.voidEye, target);
    expect(why(), isNull);
    expect(g.whyNotLebur(Relic.ironBanner), pusakaRefusals.none); // not owned
    expect(g.whyNotLebur(Relic.grail), leburRefusals.notGudang); // bound
    expect(leburRefusals.notGudang, 'Only an ${Words.artifact} in the ${Words.vault}');
    expect(why(Relic.voidEye), leburRefusals.same);
    expect(why(Relic.ironBanner), pusakaRefusals.none);
    // The gold short, and then a ★3 target: no price, so the gold isn't asked.
    g.gold = 59999;
    expect(why(), leburRefusals.gold);
    expect(leburRefusals.gold, Words.notEnoughGold);
    g.pusaka[Relic.dragonHeart]!.stars = 3;
    expect(why(), leburRefusals.maxed);
    expect(leburRefusals.maxed, 'Already ★3');
    g.pusaka[Relic.dragonHeart]!.stars = 1;
    // A Legenda target (bound to a type, or an oath), and a Legenda fodder.
    g.givePusaka(Relic.dragonCrown, type: 'knight');
    expect(why(Relic.dragonCrown), leburRefusals.legend);
    expect(leburRefusals.legend, "A ${Words.legendary} can't be melted");
    g.givePusaka(Relic.oathOfOne);
    expect(why(Relic.oathOfOne), leburRefusals.legend);
    expect(g.whyNotLebur(Relic.oathOfOne), leburRefusals.notGudang); // an oath is never in the Gudang
    g.unbindPusaka(Relic.dragonCrown);
    expect(g.whyNotLebur(Relic.dragonCrown, Relic.grail), leburRefusals.legend);
    // Asah's interval spent: Lebur doesn't care (leburUsesAsah false).
    g.asahAt = 86;
    expect(why(Relic.grail), leburRefusals.gold);
    g.gold = 1000000;
    expect(why(Relic.grail), isNull);
    // A wave on goes before the fodder's own refusals and every target's.
    g.startWave();
    expect((why(), why(Relic.dragonCrown), g.whyNotLebur(Relic.dragonCrown)), (leburRefusals.midWave, leburRefusals.midWave, leburRefusals.midWave));
    final sfx = g.sfx.length, gold = g.gold;
    expect(g.lebur(Relic.voidEye, Relic.dragonHeart), isFalse);
    expect((g.sfx.length, g.sfx.last, g.gold, g.pusaka.containsKey(Relic.voidEye), g.pusaka[Relic.dragonHeart]!.stars),
        (sfx + 1, Sfx.error, gold, true, 1));

    // No Pusaka could take a star (every other one at ★3 or a Legenda): the button's own refusal.
    final h = w86()..unbindPusaka(Relic.voidEye);
    for (final r in h.leburTargets(Relic.voidEye)) {
      h.pusaka[r]!.stars = 3;
    }
    expect(h.whyNotLebur(Relic.voidEye), leburRefusals.noTarget);
    expect(leburRefusals.noTarget, 'No other ${Words.artifact} under ★3');
    h.pusaka[Relic.grail]!.stars = 2;
    h.gold = 0; // the gold isn't the button's: the picker shows each price
    expect(h.whyNotLebur(Relic.voidEye), isNull);
    h.lives = 0; // game over
    expect(h.whyNotLebur(Relic.voidEye, Relic.grail), assignRefusals.over);
  });

  test('the save: the fodder is gone and the target\'s star kept, with no new key; asahAt stays unwritten', () {
    final g = w86()..unbindPusaka(Relic.voidEye);
    final keys = g.toJson().keys.toSet();
    g.lebur(Relic.voidEye, Relic.grail);
    expect(g.toJson().keys.toSet(), keys);
    final r = reload(g);
    expect((r.pusaka.containsKey(Relic.voidEye), r.pusaka[Relic.grail]!.stars, r.gold, r.asahAt), (false, 2, g.gold, null));
    expect(r.gudang, isEmpty);
  });

  test('telemetry: the event is passed on, and the next wave\'s record has gold.leburSpent (version 7)', () {
    final g = w86()..unbindPusaka(Relic.voidEye);
    final kept = _Kept();
    TelemetryAdapter([kept], installId: 'i', session: 's', platform: 'test', now: () => DateTime.utc(2026, 10, 2)).attach(g);
    g.lebur(Relic.voidEye, Relic.dragonHeart);
    win(g);
    final events = [for (final r in kept.records.where((r) => r['rec'] == 'event')) r['event'] as Map<String, dynamic>];
    final e = events.singleWhere((e) => e['kind'] == 'pusakaLebur');
    expect((e['fodder'], e['fodderStars'], e['relic'], e['stars'], e['cost']), ('voidEye', 1, 'dragonHeart', 2, 60000));
    final w = kept.records.lastWhere((r) => r['rec'] == 'wave');
    final spent = w['gold'] as Map;
    expect((w['wave'], spent['leburSpent'], spent['asahSpent'], w['tv']), (87, 60000, 0, telemetryVersion));
    expect(telemetryVersion, greaterThanOrEqualTo(7));
    win(g);
    expect((kept.records.lastWhere((r) => r['rec'] == 'wave')['gold'] as Map)['leburSpent'], 0); // since then
  });

  test("every line Lebur shows is in the HUD's font (a '★' is drawn as the star icon, so it is left out)", () {
    final font = fontChars();
    final lines = <String>[
      ...[leburRefusals.notGudang, leburRefusals.midWave, leburRefusals.legend, leburRefusals.noTarget, leburRefusals.same],
      ...[leburRefusals.maxed, leburRefusals.rarity, leburRefusals.gold, leburRefusals.relics],
      Words.melt, Words.sure, Words.vault, '${Words.melt} into:', 'Tap again', '60k', '150k',
      for (final r in Relic.values)
        if (r.pusaka) ...[
          '${Words.melt} ${relicNames[r]} ★2 into:', '${Words.melt} ${relicNames[r]} into:', 'Tap again: ${relicNames[r]} ★1 is gone',
          '${relicNames[r]} ★3! -150k, ${relicNames[r]} melted',
          for (final stars in [1, 2, 3]) pusakaGist(r, stars),
          for (final type in [null, ...troopTypes.keys]) ...[
            if (type != null) '${troopTypeNames[type]} (13)',
            ...logLines(PusakaLebur(86, 0, fodder: r, fodderStars: 1, relic: r, stars: 3, type: type, cost: 150000)),
          ],
        ],
    ];
    for (final line in lines) {
      expect([for (final ch in line.replaceAll('★', '').runes) if (!font.contains(ch)) String.fromCharCode(ch)], isEmpty, reason: line);
    }
  });

  testWidgets('the Gudang\'s Melt opens the picker; a target melts in two taps and the pick moves to it; Cancel closes it; '
      'mid-wave the button is greyed and a tap says why', (tester) async {
    final b = await boot(tester);
    final g = b.state = w86().boardRules()..chests.clear(); // its catch-up chests' popup would take the taps
    g.unbindPusaka(Relic.voidEye);
    await frames(tester, 50);
    await openBag(tester, b);
    expect(b.leburButton, Rect.zero); // nothing picked
    await tapOn(tester, b.bagSlot(Relic.dragonHeart).center);
    expect(b.leburButton, Rect.zero); // a bound one has no Lebur
    await tapOn(tester, b.bagSlot(Relic.voidEye).center);
    expect((b.picked, b.leburOpen), (Relic.voidEye, null));
    expect(b.leburButton, isNot(Rect.zero));
    // Open: the facing page lists the four others, the Cancel over them.
    await tapOn(tester, b.leburButton.center);
    expect(b.leburOpen, Relic.voidEye);
    expect(b.leburBack, isNot(Rect.zero));
    expect([for (final (who, _, ok) in b.assignRows) (who, ok)],
        [(Relic.dragonHeart, true), (Relic.dawnStar, true), (Relic.godThunder, true), (Relic.grail, true)]);
    // Cancel closes it, Melt opens it again.
    await tapOn(tester, b.leburBack.center);
    expect((b.leburOpen, b.leburBack), (null, Rect.zero));
    await tapOn(tester, b.leburButton.center);
    expect(b.leburOpen, Relic.voidEye);
    // The first tap on a row arms it, nothing spent; the second melts.
    final gold = g.gold;
    await tapOn(tester, rowOf(b, Relic.dragonHeart).center);
    expect((b.leburArmed, g.pusaka[Relic.dragonHeart]!.stars, g.gold), (Relic.dragonHeart, 1, gold));
    await tapOn(tester, rowOf(b, Relic.dragonHeart).center);
    expect((b.leburArmed, b.leburOpen, g.pusaka[Relic.dragonHeart]!.stars, g.gold), (null, null, 2, gold - 60000));
    expect(g.pusaka.containsKey(Relic.voidEye), isFalse);
    expect((b.picked, b.message), (Relic.dragonHeart, 'Dragon Heart ★2! -60k, Void Eye melted'));
    expect(g.troops.where((u) => u.alive && u.type == 'knight_templar').map((u) => u.maxHp).toSet(), {g.fieldStats('knight_templar').hp});
    // A ★3 target's row is greyed, and a tap says why.
    g
      ..unbindPusaka(Relic.grail)
      ..pusaka[Relic.dawnStar]!.stars = 3;
    await tapOn(tester, b.bagSlot(Relic.grail).center);
    await tapOn(tester, b.leburButton.center);
    expect(b.assignRows.firstWhere((row) => row.$1 == Relic.dawnStar).$3, isFalse);
    await tapOn(tester, rowOf(b, Relic.dawnStar).center);
    expect((b.leburArmed, b.message, g.pusaka.containsKey(Relic.grail)), (null, leburRefusals.maxed, true));
    // Mid-wave: the picker closes, the button greys and says why.
    g.startWave(); // the book shuts for the wave
    await frames(tester, 40);
    await tapOn(tester, b.bookButton.center);
    await frames(tester, 40);
    await openBag(tester, b);
    await tapOn(tester, b.bagSlot(Relic.grail).center);
    expect((b.picked, b.leburOpen), (Relic.grail, null));
    await tapOn(tester, b.leburButton.center);
    expect((b.leburOpen, b.message, g.pusaka.containsKey(Relic.grail)), (null, leburRefusals.midWave, true));
    await frames(tester, 10); // the last tap's gesture timers run out
  });
}
