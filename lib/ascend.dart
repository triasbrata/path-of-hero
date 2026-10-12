part of 'game.dart';

// "Bangkit 4-5", Kebangkitan Emas (#92 part 2, decisions-log 143; docs/loot-items-relics.md "Bangkit 4-5"): a troop
// type at Bangkit 3 buys Bangkit 4, then 5, with gold, between waves, on its Army detail's button
// (lib/ascend_page.dart's `_upgradeButton`; the field's Toko had a Bangkit section too until decisions-log 296). What a level does is [maxAscend]'s constants in game.dart ([Game.statsOf],
// [AwakenSkill.cooldownAt]); its price and the rules are here. So is the bag's hint ([Ascend.bagLevel]): at wave 71 the
// owner's archers, priests and templars were 1-3 items short of Bangkit 3 with 29-48 of each in the bag, and nothing
// said so.

/// What Bangkit 4 and Bangkit 5 cost, per troop type (decision 6 b: five types to Bangkit 5 cost 1.75M).
const ascendPrice = [100000, 250000];

/// Why a type can't buy its next level, after the store's own refusals ([StoreRefusal]: before wave [storeFrom] is
/// won, mid-wave, the game over): it isn't at Bangkit 3 yet, it is at [awakenTop], or the gold is short.
final ascendRefusals = (
  first: 'Needs ${Words.awaken} $maxAwaken first',
  maxed: 'Already ${awakenName(awakenTop)}',
  gold: storeRefusalNames[StoreRefusal.gold]!,
);

/// The Shop's tab for the levels it sells, "Awaken 4-5" (lib/recall_page.dart; the guide's K18 quotes it).
const awakenTab = '${Words.awaken} ${maxAwaken + 1}-$awakenTop';

/// The bag's hint on a type below Bangkit 3 whose next awakening the bag holds ([Ascend.bagLevel]).
String bagAwakensTo(int level) => '${Words.awaken} $level from the ${Words.bag}';

/// A multiplier in the book's words, with a dot decimal: 1.25 → "x1.25", 2.0 → "x2".
String _times(double k) => 'x${k.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '')}';

/// What a level bought in the Shop gives a type, the Awaken and Forge tooltips' words (ascendInfo, tempaInfo).
const allOfType = 'All troops of this type, now and later';

/// What a level bought does to [type]'s troop price ([ascendTroopPrice], [tempaTroopPrice]), in the tooltips' words.
String troopPriceLine(double k) => k == 1 ? 'Troop price stays the same' : 'Troop price ${_times(k)}';

/// A price in the Shop's tooltips: "Price: 100,000 gold".
String priceLine(int price) => 'Price: ${thousands(price)} gold';

/// Bangkit 4 and 5's rules (the Army detail's button calls them), and the bag's hint.
extension Ascend on Game {
  /// What [type]'s next bought level costs ([ascendPrice]: Bangkit 4's first), or null once it has both.
  int? ascendPriceOf(String type) {
    final n = ascended[type] ?? 0;
    return n < maxAscend ? ascendPrice[n] : null;
  }

  /// Why [type] can't buy its next level now, in the UI's words, or null when it can: the store's refusal first
  /// ([Store._armyClosed]: before wave [storeFrom] is won, mid-wave, the game over), then [ascendRefusals] in their order.
  String? whyNotAscend(String type) {
    if (_armyClosed case final why?) return storeRefusalNames[why]!;
    final level = awakenLevel(type);
    if (level < maxAwaken) return ascendRefusals.first;
    if (level >= awakenTop) return ascendRefusals.maxed;
    return gold < ascendPriceOf(type)! ? ascendRefusals.gold : null;
  }

  /// Buys [type]'s next level for [ascendPriceOf]: every living troop of it is refitted ([_refit]: the HP and MP it
  /// gains come with it) and bursts in the new level's colour, and it is logged ([Ascended]). False (and nothing
  /// changes but the error sound) when [whyNotAscend] refuses.
  bool ascend(String type) {
    if (whyNotAscend(type) != null) {
      sfx.add(Sfx.error);
      return false;
    }
    final cost = ascendPriceOf(type)!;
    gold -= cost;
    ascended[type] = (ascended[type] ?? 0) + 1;
    final level = awakenLevel(type);
    for (final u in troops) {
      if (!u.alive || u.type != type) continue;
      _refit(u);
      impacts.add((u.pos, awakeFx('upgrade', level)));
    }
    sfx
      ..add(Sfx.magic)
      ..add(Sfx.clear);
    _emit(Ascended(wave, t, type: type, level: level, cost: cost));
    return true;
  }

  /// The highest awakening [type] could reach (up to [maxAwaken]) with the bag's items on top of its own: the grade sets
  /// after its level that (taken + in the bag) hold in a row ([Game.gradeSet], decisions-log 249). Counts only: two types
  /// may count the same items. (No recipe asks a melee type for the bows that would take it to [meleeMaxRange]: the
  /// soldier's three reach 20.7 of 27.2.)
  int bagLevel(String type) {
    final level = itemLevel(type);
    if (recipeOf(type).isEmpty || level >= maxAwaken) return level;
    int have(Item item) => countOf(type, item) + (inventory[item] ?? 0);
    var l = level;
    while (l < maxAwaken && gradeSet(type, l + 1).entries.every((e) => have(e.key) >= e.value)) {
      l++;
    }
    return l;
  }

  /// Some fielded type (one with a living troop) can awaken further from the bag ([bagLevel]): the Tas tab's dot.
  bool get bagAwakens => {for (final u in troops) if (u.alive) u.type}.any((type) => bagLevel(type) > itemLevel(type));

  /// What [type]'s next bought level gives (from below Bangkit 3, Bangkit 4; at the top, Bangkit 5), for the
  /// Bangkit section's tooltip: its name, then its lines.
  (String, List<String>) ascendInfo(String type) {
    final next = (awakenLevel(type) + 1).clamp(maxAwaken + 1, awakenTop), heals = troopTypes[type]!.heals;
    return (awakenName(next), [
      '+${(awakenHp * 100).round()}% base HP and MP',
      '${heals ? 'Heal' : 'Attack'} ${_times(ascendPower)}',
      allOfType,
      if (awakenSkillOf(type) != null) '${Words.awaken} skill: cooldown ${_pct(ascendSkillCd)}',
      troopPriceLine(ascendTroopPrice),
      if (ascendPriceOf(type) case final price?) priceLine(price),
    ]);
  }
}
