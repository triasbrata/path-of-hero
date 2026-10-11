// The Epik Artifact's own price (decisions-log 213; loot-items-relics.md "Pusaka"): a new Epik (batch E-1P's ten) is
// worth `epikPrice`, a Langka `langkaPrice`, a Legenda `legendaPrice`, today's five Epik their Shop price; the Vault
// sells one back for `sellShare` of it, and an old save's copy past ★3 pays back `copyRefund` of it. The Bag's Sell tag
// shows it: bag_detail_test.dart.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';

import 'pusaka_test.dart' show plain;

void main() {
  test('epikPrice sits between the Langka and the Legenda', () {
    expect(epikPrice, 25000);
    expect(epikPrice, greaterThan(langkaPrice));
    expect(epikPrice, lessThan(legendaPrice));
  });

  test('basePrice by rarity: a new Epik epikPrice, a Langka langkaPrice, a Legenda legendaPrice, the Shop five their own', () {
    final g = Game();
    expect(g.basePrice(Relic.hawkFeather), epikPrice);
    expect(g.basePrice(Relic.witherroot), epikPrice);
    expect(g.basePrice(Relic.ironBanner), langkaPrice);
    expect(g.basePrice(Relic.dragonCrown), legendaPrice);
    expect(g.basePrice(Relic.grail), artefactPrice[Relic.grail]);
    for (final r in Relic.values.where((r) => r.pusaka)) {
      final want = r.store ? artefactPrice[r] : switch (r.rarity) {
        Rarity.epik => epikPrice,
        Rarity.langka => langkaPrice,
        Rarity.legenda => legendaPrice,
        Rarity.biasa => null,
      };
      expect(g.basePrice(r), want, reason: '$r');
    }
  });

  test('the Vault sells an Epik for sellShare of epikPrice, a Langka still 8,000, a Legenda unchanged', () {
    final g = Game()..wave = storeFrom;
    for (final (r, price) in [(Relic.hawkFeather, epikPrice), (Relic.ironBanner, langkaPrice), (Relic.dragonCrown, legendaPrice)]) {
      g.givePusaka(r);
      final gold = g.gold;
      expect(g.sellPrice(r), (price * sellShare).round(), reason: '$r');
      expect(g.sell(r), 1, reason: '$r');
      expect(g.gold - gold, (price * sellShare).round(), reason: '$r');
    }
    expect((epikPrice * sellShare).round(), 12500);
    expect((langkaPrice * sellShare).round(), 8000);
  });

  test('an old save\'s Epik copy past ★3 refunds copyRefund of epikPrice', () {
    final g = plain();
    g.gold = 0;
    final j = jsonDecode(jsonEncode(g.toJson()..remove('pusaka')..remove('notes'))) as Map<String, dynamic>
      ..['relicBag'] = {'hawkFeather': 5, 'ironBanner': 5};
    final h = Game.fromJson(j);
    // ★1 from the first, ★3 after two more, the last two past it.
    expect(h.gold, 2 * (epikPrice * copyRefund).round() + 2 * (langkaPrice * copyRefund).round());
  });
}
