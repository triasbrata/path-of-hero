part of 'game.dart';

// The Wishlist (decisions-log 282; docs/loot-items-relics.md "The Wishlist"): the owner, 2026-10-09, wants the player to
// put the Smithy's products they mean to make on a list, per troop type, as a target. A wish only marks and orders: the
// Smithy shows a wished item first in its grade with a star and what it still lacks, the Army detail lists a type's
// wishes, the Bag's and the Shop's materials mark what they take. Nothing crafts or gives by itself (the owner's "Wishlist
// / target saja"): crafting and giving stay the player's. Set from the Smithy's item page and from each type's Army
// detail, one list ("Dua-duanya"). Items only: a small relic is worn by one troop, not a type, and the Enhance stones go
// on no type. Saved as `wishlist` while a wish stands.
//
// Quantities and whole sets (decisions-log 300; the owner: "user harusnya bisa whitelist semua item yang yang dibutuhkan
// untuk enhance 1 army type, misal knight butuh 5 item maka ke 5nya akan langsung di whitelist beserta quantitynya"): each
// wish is for the type to HOLD a count of the item ([wishGoal]); what it holds is read live ([wishCount]), so the count is
// exact whichever way an item is given. One tap wishes a type's whole next Awaken ([wishSet]: the Army detail's "Wishlist
// all"). A wish met shows done on the Army detail until the type's next Awaken drops it (the set ends there; a Cap's or a
// Ring's drops at once, [_wishGiven]); the Smithy's Wishlist tab lists only the open ones.
//
// Free lines (decisions-log 302; the owner: "header yang army itu bisa di ganti ke item/ relics yang lain yang bisa di
// buat"): a wish for no type, any product the Smithy makes, an item or a small relic ([canWishFree]), for the Bag to hold a
// count of it ([freeGoal]; put on with a count from its Smithy page or, decisions-log 303, its Bag page). Met, it drops
// off ([_wishSweep]: at the craft that meets it, and when the Town is left for one met another way); it is shown and
// counted only while open ([freeWishes]). The Smithy's Wishlist tab lists both.
//
// Made, not edited (decisions-log 303; the owner: "wishlist yang ada di tabs smithy itu seharusnya adalah tempat user untuk
// merealisasikan wishlistnya"): the Smithy's Wishlist tab lists one row a thing to make ([wishRows]: a type's open wish or
// an open free line), its recipe for what is still to make with what the Bag holds ([WishRow.parts], [wishRowShort]), and
// crafts and gives from there; it adds nothing. Wishes go on from the Army detail, the Bag and the Smithy's Items and
// Relics pages.

/// One row of the Smithy's Wishlist tab (decisions-log 303; the owner: "1 baris per barang"): a thing to make. [type]: the
/// troop type the wish is for (null: a free line, for the Bag); [kind]: the product (an item, or a free line's small
/// relic); [need]: how many are still wanted ("×2": what the type, or the Bag, still lacks of its goal); [make]: how many
/// of those are still to be crafted (a type's less what the Bag holds already, which the row gives; a free line's all of
/// them); [parts]: its recipe for [make] of them line by line as [Craft.itemCraftRows] (each material, then each item,
/// then the gold, null), what the Bag holds and what they take.
typedef WishRow = ({String? type, Enum kind, int need, int make, List<CraftRow> parts});

/// The Wishlist's rules (decisions-log 282, 300): who can wish for what, the wishes per type and how many each is to hold,
/// a type's whole set, and what they still lack.
extension Wishlist on Game {
  /// Whether [type] can wish for [item]: a troop type, an item the Smithy makes ([Craft.itemRecipe]) and one the type can
  /// ever take: a kind its Awaken counts ([Game.kindRecipe]) in any grade, or the Cap or the Ring ([outsideAwaken]), which
  /// every type takes.
  bool canWish(String type, Item item) {
    if (itemRecipe(item) == null || recipeOf(type).isEmpty) return false;
    return kindRecipe(type).containsKey(item.slot) || outsideAwaken.contains(item.slot);
  }

  /// The products [type] can wish for ([canWish]), in [Item] order: the Army detail's picker, by grade.
  List<Item> wishable(String type) => [for (final i in Item.values) if (canWish(type, i)) i];

  /// [type]'s wishes in the order they were added (none: empty), done ones too ([wishDone]).
  List<Item> wishesOf(String type) => [...?wishlist[type]?.keys];

  /// How many [item]s [type]'s wish is for it to HOLD (decisions-log 300; null: not on its wishes): a whole set's count
  /// ([wishSet]), else one more than it held when wished ([wish]).
  int? wishGoal(String type, Item item) => wishlist[type]?[item];

  /// [type]'s wish for [item] as (have, need): how many the type holds now ([Game.countOf], read live, so it stays exact
  /// whichever way an item is given), at most the need, and its goal ([wishGoal]); null: not on its wishes.
  (int, int)? wishCount(String type, Item item) => switch (wishGoal(type, item)) { final n? => (min(countOf(type, item), n), n), null => null };

  /// Whether [type] holds what its wish for [item] asks ([wishCount]): it shows done until the type's next Awaken drops
  /// it ([_wishGiven]).
  bool wishDone(String type, Item item) => switch (wishCount(type, item)) { (final have, final need) => have >= need, null => false };

  /// The types that wish for [item], done or not, in [troopTypes] order: the Smithy's "Wishlist: Knight, Archer" and its
  /// chips.
  List<String> wishersOf(Item item) => [for (final type in troopTypes.keys) if (wishlist[type]?.containsKey(item) ?? false) type];

  /// The types whose wish for [item] is still open (not [wishDone]), in [troopTypes] order: the Smithy's Give row.
  List<String> openWishersOf(Item item) => [for (final type in wishersOf(item)) if (!wishDone(type, item)) type];

  /// Whether some type's wish for [item] is still open ([openWishersOf]), or a free line's ([freeWishes]; decisions-log
  /// 302): its star on the Smithy's board, first in its grade.
  bool wished(Item item) =>
      troopTypes.keys.any((type) => wishlist[type]?.containsKey(item) == true && !wishDone(type, item)) || freeWished(item);

  /// Every item some type's open wish is for ([wished]), once each, in [Item] order.
  List<Item> get wishedItems => [for (final i in Item.values) if (wished(i)) i];

  /// Puts [item] on [type]'s wishes, last ([canWish]; once), to hold [goal] of it (none: one more than it holds now).
  /// False when it can't, or already is.
  bool wish(String type, Item item, [int? goal]) {
    if (!canWish(type, item) || wishGoal(type, item) != null) return false;
    (wishlist[type] ??= {})[item] = max(1, goal ?? countOf(type, item) + 1);
    return true;
  }

  /// Takes [item] off [type]'s wishes (the last one leaves no entry). False when it wasn't on them.
  bool unwish(String type, Item item) {
    final items = wishlist[type];
    if (items == null || items.remove(item) == null) return false;
    if (items.isEmpty) wishlist.remove(type);
    return true;
  }

  /// [item] off [type]'s wishes when it is on them, else on ([wish]): whether it is on them after.
  bool toggleWish(String type, Item item) => unwish(type, item) ? false : wish(type, item);

  /// [type]'s whole set (decisions-log 300; the owner: "user harusnya bisa whitelist semua item yang yang dibutuhkan untuk
  /// enhance 1 army type"): every item its next Awaken still lacks ([Game.awakenShort]) with how many the type is to hold
  /// ([Game.awakenNeeds] of that level: the grade set's count), in the set's order. Empty at the top, or for a type that
  /// can wish for none of it.
  Map<Item, int> wishSetOf(String type) {
    final short = awakenShort(type);
    if (short.isEmpty) return const {}; // at the top: no next level to ask for
    final needs = awakenNeeds(type, itemLevel(type) + 1);
    return {for (final MapEntry(key: item, value: n) in needs.entries) if (short.containsKey(item) && canWish(type, item)) item: n};
  }

  /// Whether [type]'s whole set is on its wishes ([wishSetOf]), each to hold at least the set's count.
  bool setWished(String type) {
    final set = wishSetOf(type);
    return set.isNotEmpty && set.entries.every((e) => (wishGoal(type, e.key) ?? 0) >= e.value);
  }

  /// Puts [type]'s whole set on its wishes ([wishSetOf]): an item not on them goes on last, one already on keeps its place
  /// and holds at least the set's count. False when there is no set.
  bool wishSet(String type) {
    final set = wishSetOf(type);
    if (set.isEmpty) return false;
    for (final MapEntry(key: item, value: n) in set.entries) {
      final goals = wishlist[type] ??= {};
      goals[item] = max(n, goals[item] ?? 0);
    }
    return true;
  }

  /// Takes [type]'s whole set off its wishes ([wishSetOf]); its other wishes stay. False when none of it was on them.
  bool unwishSet(String type) => [for (final item in wishSetOf(type).keys) unwish(type, item)].contains(true);

  /// Takes every wish of [type] off (the Smithy's Wishlist tab, its group's Remove tapped twice). False when it had none.
  bool unwishAll(String type) => wishlist.remove(type) != null;

  /// After [item] went on [type] ([Game.useItem]; decisions-log 300): with the Awaken it brought ([awakened]) every done
  /// wish of the type drops off (the set ends; no roll-on to the next Awaken); else a done wish for a kind no Awaken
  /// counts (the Cap, the Ring, [outsideAwaken]) drops off at once. An Awaken item's done wish stays, shown done, until
  /// then.
  void _wishGiven(String type, Item item, {required bool awakened}) {
    if (wishlist[type] == null) return;
    for (final i in [if (awakened) ...wishesOf(type) else if (outsideAwaken.contains(item.slot)) item]) {
      if (wishDone(type, i)) unwish(type, i);
    }
  }

  /// Whether [kind] can be a free line (decisions-log 302): a product the Smithy makes, an item with a recipe
  /// ([Craft.itemRecipe]) or a small relic in play with one ([Relics.relicsInPlay], [Craft.craftRecipe]).
  bool canWishFree(Enum kind) => switch (kind) {
        final Item i => itemRecipe(i) != null,
        final Relic r => relicsInPlay.contains(r) && craftRecipe(r) != null,
        _ => false,
      };

  /// How many [kind]s its free line is for the Bag to hold (null: none).
  int? freeGoal(Enum kind) => wishFree[kind];

  /// [kind]'s free line as (have, need): how many the Bag holds now ([Store.inBag], read live), at most the need, and its
  /// goal ([freeGoal]); null: none.
  (int, int)? freeCount(Enum kind) => switch (freeGoal(kind)) { final n? => (min(inBag(kind), n), n), null => null };

  /// Whether the Bag holds what [kind]'s free line asks ([freeCount]): it drops off ([_wishSweep]) and until then counts
  /// as none.
  bool freeDone(Enum kind) => switch (freeCount(kind)) { (final have, final need) => have >= need, null => false };

  /// The free lines still open, in the order put on: the Smithy's Wishlist tab.
  List<Enum> get freeWishes => [for (final k in wishFree.keys) if (!freeDone(k)) k];

  /// Whether [kind] has a free line still open ([freeWishes]): an item's star and order on the Smithy's Items board, a
  /// relic's star on its Relics board.
  bool freeWished(Enum kind) => wishFree.containsKey(kind) && !freeDone(kind);

  /// Puts [kind] on the free lines, last ([canWishFree]; once), for the Bag to hold [more] more than it holds now (at
  /// least one). False when it can't, or an open line has it.
  bool wishFreeAdd(Enum kind, [int more = 1]) {
    if (!canWishFree(kind) || freeWished(kind)) return false;
    wishFree.remove(kind); // a met line not yet swept goes, the new one last
    wishFree[kind] = inBag(kind) + max(1, more);
    return true;
  }

  /// [kind]'s free line asking [by] more (fewer, when negative), never under one more than the Bag holds: the − and +
  /// of its Smithy page. Its goal after (null: none).
  int? wishFreeMore(Enum kind, int by) {
    final goal = freeGoal(kind);
    if (goal == null) return null;
    return wishFree[kind] = max(inBag(kind) + 1, goal + by);
  }

  /// Takes [kind]'s free line off. False when it had none.
  bool unwishFree(Enum kind) => wishFree.remove(kind) != null;

  /// [kind]'s free line off when it has one, else on for one more ([wishFreeAdd]). Whether it is on after.
  bool toggleFree(Enum kind) => freeWished(kind) ? !unwishFree(kind) : wishFreeAdd(kind);

  /// Takes every free line off (the Wishlist tab's group "For the Bag", its Remove tapped twice; decisions-log 303). False
  /// when none was open.
  bool unwishFreeAll() {
    final had = freeWishes.isNotEmpty;
    wishFree.clear();
    return had;
  }

  /// The Smithy's Wishlist tab's rows (decisions-log 303): each type's open wishes (a met one, [wishDone], is off the tab
  /// at once) in [troopTypes] order, each type's in the order put on; then the open free lines ([freeWishes]) in theirs.
  List<WishRow> get wishRows => [
        for (final type in troopTypes.keys)
          for (final item in wishesOf(type))
            if (wishCount(type, item) case (final have, final goal) when have < goal) _wishRow(type, item, goal - have),
        for (final kind in freeWishes)
          if (freeCount(kind) case (final have, final goal)) _wishRow(null, kind, goal - have),
      ];

  /// [kind]'s row for [type] (null: its free line), [need] still wanted ([WishRow]).
  WishRow _wishRow(String? type, Enum kind, int need) {
    final make = type == null ? need : max(0, need - inBag(kind));
    final rows = switch (kind) { final Item i => itemCraftRows(i), final Relic r => craftRows(r), _ => const <CraftRow>[] };
    return (type: type, kind: kind, need: need, make: make, parts: [for (final r in rows) (kind: r.kind, have: r.have, need: r.need * make)]);
  }

  /// What [row]'s recipe still lacks for its [WishRow.make] ([WishRow.parts] short): each part (the gold: null) and how
  /// many it is short, in the recipe's order; empty while the Bag pays for all of them.
  List<(Enum?, int)> wishRowShort(WishRow row) => [for (final p in row.parts) if (p.have < p.need) (p.kind, p.need - p.have)];

  /// What [kind]'s recipe takes besides its gold: an item's ([Craft.itemRecipe]) or a relic's ([Craft.craftRecipe]); null
  /// for anything else, or none.
  ({Map<Mat, int> materials, Map<Item, int> items})? _productRecipe(Enum kind) => switch (kind) {
        final Item i => switch (itemRecipe(i)) { final r? => (materials: r.materials, items: r.items), null => null },
        final Relic relic => switch (craftRecipe(relic)) { final r? => (materials: r.materials, items: r.items), null => null },
        _ => null,
      };

  /// What [kind]'s recipe takes, each material then each item, as the file lists them (not its gold): its free line's
  /// cells on the Smithy's Wishlist tab (decisions-log 302).
  List<Enum> freeParts(Enum kind) => switch (_productRecipe(kind)) { final r? => [...r.materials.keys, ...r.items.keys], null => const [] };

  /// [part] for [kind]'s free line as (have, need): what the rest of the line takes of it (the recipe's count for each one
  /// still to make, [freeCount]) and what the Bag holds, at most that.
  (int, int) freeNeed(Enum kind, Enum part) {
    final r = _productRecipe(kind);
    final (have, need) = freeCount(kind) ?? (0, 0);
    final per = switch (part) { final Mat m => r?.materials[m], final Item i => r?.items[i], _ => null } ?? 0;
    final n = per * (need - have);
    return (min(inBag(part), n), n);
  }

  /// Every free line the Bag now meets drops off ([freeDone]; decisions-log 302): after each craft ([Craft.craft],
  /// [Craft.craftItem]) and when the Town is left ([Town.leaveTown]: one met by a chest's relic).
  void _wishSweep() => wishFree.removeWhere((k, _) => freeDone(k));

  /// What the Bag still lacks for one [item] ([Craft.itemCraftRows] short): each material and item short with what it
  /// has and needs, then the gold. Empty: the Bag pays for one ([Craft.canMake]), wherever the game is.
  List<CraftRow> wishShort(Item item) => [for (final r in itemCraftRows(item)) if (r.have < r.need) r];

  /// The materials the open wishes' recipes take ([wishedItems], [Craft.itemRecipe]; a free relic's, [Craft.craftRecipe],
  /// decisions-log 302): the Bag's and the Shop's materials mark them, "Needed for your wishlist" (decisions-log 300).
  Set<Mat> get wishMats => {
        for (final i in wishedItems) ...?itemRecipe(i)?.materials.keys,
        for (final k in freeWishes)
          if (k is Relic) ...?craftRecipe(k)?.materials.keys,
      };

  // The save.

  /// The save's `wishlist` (type → its wishes by name, in order, each with how many the type is to hold; decisions-log
  /// 300), and under `free` the open free lines (product name → how many the Bag is to hold, in order; decisions-log 302:
  /// no item and no relic share a name), only with some wish (a save without it: none).
  Map<String, Object> get _wishJson {
    final free = freeWishes;
    if (wishlist.isEmpty && free.isEmpty) return const {};
    return {
      'wishlist': {
        for (final MapEntry(key: type, value: goals) in wishlist.entries) type: {for (final MapEntry(key: i, value: n) in goals.entries) i.name: n},
        if (free.isNotEmpty) 'free': {for (final k in free) k.name: wishFree[k]!},
      },
    };
  }

  /// [j]'s `wishlist` (a save without it: none): each type's wishes with their goals; a save from
  /// before the goals (decisions-log 282: a list of names) wishes each for one more than the type holds, as it was wished.
  /// A type that isn't a troop type, an item name this build doesn't know and a goal under 1 are skipped, an item twice
  /// kept once; under `free` the free lines (decisions-log 302), an item's or a relic's name each, skipped the same.
  /// Read after the types' items ([Game.upgrades]).
  void _loadWishes(Map<String, dynamic> j) {
    final wishes = (j['wishlist'] as Map?) ?? const {};
    if (wishes['free'] case final Map free) {
      final items = Item.values.asNameMap(), relics = Relic.values.asNameMap();
      for (final MapEntry(key: name, value: n) in free.entries) {
        if ((items[name] ?? relics[name], n) case (final Enum k?, final int n) when n > 0) wishFree[k] = n;
      }
    }
    for (final MapEntry(:key, :value) in wishes.entries) {
      if (key is! String || !troopTypes.containsKey(key)) continue;
      final goals = <Item, int>{}, names = Item.values.asNameMap();
      switch (value) {
        case final List old:
          for (final name in old) {
            if (names[name] case final i? when !goals.containsKey(i)) goals[i] = countOf(key, i) + 1;
          }
        case final Map now:
          for (final MapEntry(key: name, value: n) in now.entries) {
            if ((names[name], n) case (final i?, final int n) when n > 0) goals[i] = n;
          }
      }
      if (goals.isNotEmpty) wishlist[key] = goals;
    }
  }
}
