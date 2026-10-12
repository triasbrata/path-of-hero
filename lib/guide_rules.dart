// When the first-time guide's one-time cards show (their words: lib/guide_text.dart; docs/ui-hud.md "Guide"): each card
// K0-K25 is due by a pure check on the Game, rechecked at every break, and once shown it is in the device's seen set
// (`Settings.seen`, settings.json, so "New Game" never brings one back). A device that had a save before the guide
// (the owner's wave-86 game) starts with every card a game that far has met marked seen ([seenFrom]). Pure Dart.
//
// A new card is a rule here (its key, its gate, its check) and its words in guide_text.dart: the list's order breaks
// ties, so it can go anywhere.

import 'game.dart';

/// The intro's key in the seen set (all its pages: skipped or read, it is seen).
const guideIntro = 'intro';

/// The pointers' keys, in their order: buy a troop (P1), start the wave (P2), then the first item: the Tas tab (P3),
/// the item (P4), a type's row (P5). Each is seen when done, or dropped when not done in two breaks ([dropItemPointers]).
const guidePointers = ['P1', 'P2', 'P3', 'P4', 'P5'];

/// A one-time card's rule: its [key], its [gate] (a save that has fought this many waves has met it: [seenFrom]; null,
/// never), and when it is [due]. A card shows only once [after] is seen (K0 waits for the item pointers to be dropped). A
/// [passing] card's moment goes with this break and never comes back (a wave's notice before it comes), so it goes
/// before the others ([guideNext]). An [atChest] card sits over the boss chest's popup (K5, K12, K25): it shows only while
/// that is open, and no other card does then. An [inTown] card shows in a Town (K23, decisions-log 237): only there,
/// and no other card does there.
class GuideRule {
  const GuideRule(this.key, this.gate, this.due, {this.after, this.passing = false, this.atChest = false, this.inTown = false});

  final String key;
  final int? gate;
  final bool Function(Game g) due;
  final String? after;
  final bool passing;
  final bool atChest;
  final bool inTown;
}

/// The cards' rules, K0-K25, in the order that breaks ties.
final guideRules = <GuideRule>[
  // Items: an item waits in the bag and none was ever given, after the item pointers were dropped (P3-P5).
  GuideRule('K0', 1, (g) => g.inventory.values.any((n) => n > 0) && g.upgrades.values.every((l) => l.isEmpty), after: 'P5'),
  // Troops fell: "Ganti yang gugur" can buy them back.
  GuideRule('K1', 1, (g) => g.toReplace.isNotEmpty),
  // The next wave's mini boss, healer monster and boss, each after the wave before it.
  GuideRule('K2', miniBossEvery - 1, (g) => g.wave == miniBossEvery - 1, passing: true),
  GuideRule('K3', necroHealerFrom - 1, (g) => g.wave == necroHealerFrom - 1, passing: true),
  GuideRule('K4', bossEvery - 1, (g) => g.wave == bossEvery - 1, passing: true),
  // Peti Bos: a chest waits (the card sits over it).
  GuideRule('K5', bossEvery, (g) => g.chests.isNotEmpty, atChest: true),
  // A Pusaka bound to a type.
  GuideRule('K6', bossEvery, (g) => g.pusaka.entries.any((e) => !e.key.oath && e.value.type != null)),
  // A small relic in the bag (with the Towns on, any of the Smithy's: [Relics.relicsInPlay]).
  GuideRule('K7', 7, (g) => g.relicsInPlay.any((r) => (g.relicBag[r] ?? 0) > 0)),
  // Item limits: a fielded type at its cap for a kind in the bag, until it awakens ([Refusal.awakenFirst]).
  GuideRule('K8', 10,
      (g) => _fielded(g).any((type) => g.inventory.entries.any((e) => e.value > 0 && g.whyNot(e.key, type) == Refusal.awakenFirst))),
  // Bangkit: the Tas tab's dot ([Ascend.bagAwakens]).
  GuideRule('K9', 10, (g) => g.bagAwakens),
  // Hero: one was made (after its splash).
  GuideRule('K10', heroEvery, (g) => g.troops.any((u) => u.hero) || g.fallenHeroes.isNotEmpty),
  // The Shop: open since [Store.shopFrom]'s win, a Town's Shop, open in every Town, so its card waits for a Town marked
  // ([Game.townAt]: "Every Town has a Shop now" with one on its way, decisions-log 253; the field's Toko, a game without
  // the Towns', went in decisions-log 296).
  GuideRule('K11', storeFrom, (g) => g.storeOpen && g.townAt != null),
  // Legenda: the chest to open shows one (the card sits over it).
  GuideRule('K12', legendFrom, (g) => g.chest?.cards?.any((r) => r?.rarity == Rarity.legenda) ?? false, atChest: true),
  // A type at its cap (decisions-log 201): buy other types.
  GuideRule('K13', 1, (g) => troopTypes.keys.any(g.typeFull)),
  // A fallen Hero waits to be recalled: in its type's Army detail.
  GuideRule('K14', null, (g) => g.fallenHeroes.isNotEmpty && g.armyBuysOpen),
  // The army at the most alive ([Game.armyMax]).
  GuideRule('K15', null, (g) => switch (g.armyMax) { final cap? => g.armySize >= cap, _ => false }),
  // The last wave stalled and its monsters marched ([Game.stalled]).
  GuideRule('K16', 1, (g) => g.stalled),
  // Pasang: the tide comes in with the next wave ([Game.tideRising]).
  GuideRule('K17', tideFrom - 1, (g) => g.tideRising, passing: true),
  // Gold waits for an Awaken or a Forge: the Toko tab's dot, with the Towns on the Army tab's ([Tempa.tokoNudge]).
  GuideRule('K18', null, (g) => g.tokoNudge),
  // The bosses' escorts come with the next wave.
  GuideRule('K19', escortFrom - 1, (g) => g.wave == escortFrom - 1, passing: true),
  // Some Pusaka can gain a star by Asah now.
  GuideRule('K20', null, (g) => g.pusaka.keys.any((r) => g.whyNotAsah(r) == null)),
  // Some Pusaka in the Gudang can be melted (Lebur) into another.
  GuideRule('K21', null, (g) => g.pusaka.keys.any((r) => g.whyNotLebur(r) == null)),
  // Some Pusaka can take Carve (Ukir) now: from wave 40, spare items in the bag (decisions-log 196).
  GuideRule('K22', null, (g) => g.pusaka.keys.any((r) => g.whyNotUkir(r) == null)),
  // The Towns (decisions-log 237): the first Town (the card shows in it), and materials in the bag after the first wave
  // that drops one.
  GuideRule('K23', null, (g) => g.inTown, inTown: true),
  GuideRule('K24', 1, (g) => g.towns && g.materials.isNotEmpty),
  // The Shadows (decisions-log 319): the first chest whose cards hide one (from [omenFrom]); the card sits over it.
  GuideRule('K25', omenFrom, (g) => omensOn && (g.chest?.omens?.any((k) => k != null) ?? false), atChest: true),
];

/// The troop types with a troop alive.
Set<String> _fielded(Game g) => {for (final u in g.troops) if (u.alive) u.type};

/// The card due at this break, or null: between waves only ([Game.canStartWave]) or in a Town ([Game.inTown]), and once
/// the intro is seen, the first rule not in [seen] whose [GuideRule.after] is, and that is [GuideRule.due]: a
/// [GuideRule.passing] one before the rest, else in [guideRules]' order. With [chest] (the boss chest's popup open) only
/// the [GuideRule.atChest] ones, else only the others; in a Town only the [GuideRule.inTown] ones, else only the others.
/// The board shows one card a break, after its own news (the "VICTORY!" popup, a Hero's splash, a chest:
/// lib/coach.dart's `_coachNews`).
String? guideNext(Game g, Set<String> seen, {bool chest = false}) {
  if (!(g.canStartWave || g.inTown) || !seen.contains(guideIntro)) return null;
  GuideRule? first;
  for (final r in guideRules) {
    if (r.atChest != chest || r.inTown != g.inTown || seen.contains(r.key) || (r.after != null && !seen.contains(r.after)) || !r.due(g)) {
      continue;
    }
    if (r.passing) return r.key;
    first ??= r;
  }
  return first?.key;
}

/// The item pointers (P3-P5) dropped, not done in two breaks: they are seen, and K0 says it once an item waits.
void dropItemPointers(Set<String> seen) => seen.addAll(guidePointers.sublist(2));

/// The item pointers done (P5's item given to a type): they are seen, and so is K0, which says the same.
void itemPointersDone(Set<String> seen) => seen.addAll([...guidePointers.sublist(2), 'K0']);

/// The seen set of a device that has none yet (settings.json without one: from before the guide, or new): empty with no
/// save ([savedWave] null), else the intro, the pointers and every card whose [GuideRule.gate] is at most the save's
/// wave. main() gives it once, before the board starts; after that the set only grows ("Ulang panduan" only replays the
/// intro). The owner's wave-86 save keeps only K14, K15, K18, K20, K21 and K22 to see (his decision 3 a; K22 came later).
Set<String> seenFrom(int? savedWave) => savedWave == null
    ? {}
    : {
        guideIntro,
        ...guidePointers,
        for (final r in guideRules)
          if (r.gate case final w? when w <= savedWave) r.key,
      };
