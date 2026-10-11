part of 'game.dart';

// "Tempa", Bangkit 6+ (late-economy J2, decisions-log 163; docs/loot-items-relics.md "Tempa"): past Bangkit 5 a type
// keeps buying levels with gold, on its Army detail's button (lib/ascend_page.dart), between waves. Each one multiplies
// the type's HP and damage (a healer's heal) once more ([tempaHp], [tempaDmg]; [Game.statsOf]), and costs a share of a
// late wave's gold ([purse]) that rises a level ([tempaRise]), so the late game's gold always has a use (the owner,
// decision 2 a). A dot on the Army tab (the Toko's until decisions-log 296) says when gold piles up and something there can be bought ([Tempa.tokoNudge],
// decision 4 a).

/// A wave's purse: about what wave [w] pays in kill gold late in a run, [purseK] × (4 + 2w) × (1 + [killGoldGrowth])^(w − 1),
/// rounded to [purseRound]: wave 87 166k, 100 358k, 105 479k (0.87-1.0 of the formula's kill gold). Tempa's prices and
/// the Army tab's dot are counted in purses.
const purseK = 14, purseRound = 1000;

int purse(int w) => (purseRaw(w) / purseRound).round() * purseRound;

/// [purse] before its rounding (the Tavern's prices, tavern.dart, round it their own way).
double purseRaw(int w) => purseK * (4 + 2 * w) * pow(1 + killGoldGrowth, max(0, w - 1)).toDouble();

/// Tempa: a type at [tempaFrom] (Bangkit 5) buys levels up to [tempaMax] (a guard: there is no end by design). Each
/// multiplies its HP by 1 + [tempaHp] and its damage (a heal) by 1 + [tempaDmg], compounding; its skills stay as they
/// are, and its troop price is multiplied by [tempaTroopPrice] a level (1: no dearer). Level n + 1 costs [tempaK] of the
/// wave's [purse] × [tempaRise]^n, rounded to [tempaRound] (at least that).
const tempaFrom = awakenTop, tempaMax = 30, tempaHp = 0.05, tempaDmg = 0.05, tempaTroopPrice = 1.0;
const tempaK = 0.2, tempaRise = 1.2, tempaRound = 1000;

/// The Army tab's dot shows while the gold is at least this many purses of the next wave ([Tempa.tokoNudge]).
const nudgePurses = 3;

/// What Tempa level [n] + 1 costs after wave [w]: [tempaK] × [purse] × [tempaRise]^[n], rounded to [tempaRound], at
/// least [tempaRound]. Wave 87: 33k, 40k, 48k, 57k, 69k; wave 100: 72k, 86k, 103k, 124k.
int tempaPrice(int w, int n) => max(1, (tempaK * purse(w) * pow(tempaRise, n) / tempaRound).round()) * tempaRound;

/// Why a type can't buy its next Tempa level, after the store's own refusals ([StoreRefusal]): it isn't at Bangkit 5
/// yet, it is at [tempaMax], or the gold is short.
final tempaRefusals = (
  first: 'Needs ${Words.awaken} $tempaFrom first',
  maxed: 'Already ${tempaName(tempaMax)} (Max)',
  gold: storeRefusalNames[StoreRefusal.gold]!,
);

/// Tempa [n] in words: "Forge +3".
String tempaName(int n) => '${Words.forge} +$n';

/// Tempa's rules (the Army detail's button calls them, and [Game.statsOf] reads [tempaOf]), and the Army tab's dot.
extension Tempa on Game {
  /// The Tempa levels that count for [type]: those bought ([tempa]), while it is at [tempaFrom].
  int tempaOf(String type) => awakenLevel(type) >= tempaFrom ? (tempa[type] ?? 0) : 0;

  /// What [type]'s next Tempa level costs now ([tempaPrice] after this [wave]), or null at [tempaMax].
  int? tempaPriceOf(String type) {
    final n = tempa[type] ?? 0;
    return n < tempaMax ? tempaPrice(wave, n) : null;
  }

  /// Why [type] can't buy its next Tempa level now, in the UI's words, or null when it can: the store's refusal first
  /// ([Store._armyClosed]: before wave [storeFrom] is won, mid-wave, the game over), then [tempaRefusals] in their order.
  String? whyNotTempa(String type) {
    if (_armyClosed case final why?) return storeRefusalNames[why]!;
    if (awakenLevel(type) < tempaFrom) return tempaRefusals.first;
    final price = tempaPriceOf(type);
    if (price == null) return tempaRefusals.maxed;
    return gold < price ? tempaRefusals.gold : null;
  }

  /// Buys [type]'s next Tempa level for [tempaPriceOf]: every living troop of it is refitted ([_refit]: the HP it gains
  /// comes with it) and bursts in Bangkit 5's colour, and it is logged ([Tempered]). False (and nothing changes but the
  /// error sound) when [whyNotTempa] refuses.
  bool temper(String type) {
    if (whyNotTempa(type) != null) {
      sfx.add(Sfx.error);
      return false;
    }
    final cost = tempaPriceOf(type)!;
    gold -= cost;
    final n = (tempa[type] ?? 0) + 1;
    tempa[type] = n;
    for (final u in troops) {
      if (!u.alive || u.type != type) continue;
      _refit(u);
      impacts.add((u.pos, awakeFx('upgrade', tempaFrom)));
    }
    sfx
      ..add(Sfx.magic)
      ..add(Sfx.clear);
    _emit(Tempered(wave, t, type: type, level: n, cost: cost));
    return true;
  }

  /// What [type]'s HP and damage are multiplied by at Tempa [n] (its own, [tempaOf], by default).
  (double hp, double dmg) tempaFactors(String type, [int? n]) {
    final k = n ?? tempaOf(type);
    return (pow(1 + tempaHp, k).toDouble(), pow(1 + tempaDmg, k).toDouble());
  }

  /// What [type]'s next Tempa level gives, for the Bangkit row's tooltip at Bangkit 5: its name, then its lines.
  (String, List<String>) tempaInfo(String type) {
    final n = tempa[type] ?? 0, heals = troopTypes[type]!.heals;
    final (hp, dmg) = tempaFactors(type, n);
    return (tempaName(min(n + 1, tempaMax)), [
      'HP +${(tempaHp * 100).round()}%, ${heals ? 'heal' : 'attack'} +${(tempaDmg * 100).round()}%',
      'Stacks each level (max +$tempaMax)',
      allOfType,
      'Skills stay the same',
      troopPriceLine(tempaTroopPrice),
      if (n > 0) 'Now: HP ${_times(hp)}, ${heals ? 'heal' : 'attack'} ${_times(dmg)}',
      if (tempaPriceOf(type) case final price?) priceLine(price) else 'Max: ${tempaName(tempaMax)}',
    ]);
  }

  /// Gold piles up and the Army has something for it: the gold is at least [nudgePurses] × [purse] of the next wave,
  /// and some type with a living troop can buy its next Bangkit or Tempa level now. The Army tab's dot (named for the
  /// Toko, whose tab had it until decisions-log 296).
  bool get tokoNudge {
    if (gold < nudgePurses * purse(wave + 1)) return false;
    return {for (final u in troops) if (u.alive) u.type}.any((type) => whyNotAscend(type) == null || whyNotTempa(type) == null);
  }
}
