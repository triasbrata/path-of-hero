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
//
// Ingredient wishes (decisions-log 323; the owner, 2026-10-12: "kalau user whitelist item yang item untuk forgenya ada item
// yang perlu di forge dulu maka item itu juga akan langsung ke whitelist"): a wish put on (a type's, a set's, a free
// line) puts on with it a wish for each product its recipe takes that the Smithy makes, and theirs in turn ([WishPart],
// [_wishChain]): the Royal Ring's Gem Ring and the Gem Ring's Ring. Each is for its parent's craft, never for a troop
// ("jangan sampai item requirement untuk forge ini malah ada cta untuk give to troops"): its row on the tab has no Give
// and names the product it is for ([partNeeds]). What it asks is read live, the recipe's count for each of its parent
// still to make, less what the Bag holds; the same product for two parents adds up. It goes when its parent goes, by a
// tap or met ("Ikut terhapus", [_wishPrune]); a wish the player put on for the same product stays apart.

/// One row of the Smithy's Wishlist tab (decisions-log 303; the owner: "1 baris per barang"): a thing to make. [type]: the
/// troop type the wish is for (null: a free line, for the Bag); [kind]: the product (an item, or a free line's small
/// relic); [need]: how many are still wanted ("×2": what the type, or the Bag, still lacks of its goal); [make]: how many
/// of those are still to be crafted (a type's less what the Bag holds already, which the row gives; a free line's all of
/// them); [parts]: its recipe for [make] of them line by line as [Craft.itemCraftRows] (each material, then each item,
/// then the gold, null), what the Bag holds and what they take; [parents]: an ingredient row's products whose recipes
/// take it (decisions-log 323: "for Royal Ring"; its [type] null), none for a type's wish or a free line.
typedef WishRow = ({String? type, Enum kind, int need, int make, List<CraftRow> parts, List<Enum> parents});

/// An ingredient wish (decisions-log 323): a product the Smithy makes ([Wishlist.canWishFree]) that a wished product's
/// recipe takes, wished for that craft and never for a troop. It goes on with the wish it is for, and theirs in turn
/// ([Wishlist._wishChain]), and off with it ([Wishlist._wishPrune]). [type]: whose wish the chain hangs from (null: a free
/// line's); [root]: that wish's product; [chain]: the ingredients from the root's recipe down to this one, each in the
/// recipe of the one before (never empty; the last is [kind]). The Royal Ring wished for the knight: (knight, Royal Ring,
/// [Gem Ring]) and (knight, Royal Ring, [Gem Ring, Ring]).
class WishPart {
  WishPart(this.type, this.root, Iterable<Enum> chain)
      : chain = List.unmodifiable(chain),
        _key = [type ?? _freeKey, root.name, for (final k in chain) k.name].join('/');

  final String? type;
  final Enum root;
  final List<Enum> chain;
  final String _key;

  /// A free line's place for a type's name ([names]): no troop type has it.
  static const _freeKey = 'free';

  /// The product wished.
  Enum get kind => chain.last;

  /// The product whose recipe takes it: the one before it in [chain], else [root].
  Enum get parentKind => chain.length > 1 ? chain[chain.length - 2] : root;

  /// The ingredient wish it is for (null: the [root]'s wish).
  WishPart? get parent => chain.length > 1 ? WishPart(type, root, chain.take(chain.length - 1)) : null;

  /// Its save form ([Wishlist._wishJson]): the type (a free line's "free"), the root's name, then the chain's.
  List<String> get names => _key.split('/');

  @override
  bool operator ==(Object other) => other is WishPart && other._key == _key;

  @override
  int get hashCode => _key.hashCode;

  @override
  String toString() => _key;
}

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

  /// Whether some type's wish for [item] is still open ([openWishersOf]), a free line's ([freeWishes]; decisions-log 302)
  /// or an ingredient wish's ([partWished]; decisions-log 323): its star on the Smithy's board, first in its grade.
  bool wished(Item item) =>
      troopTypes.keys.any((type) => wishlist[type]?.containsKey(item) == true && !wishDone(type, item)) || freeWished(item) || partWished(item);

  /// Every item some type's open wish is for ([wished]), once each, in [Item] order.
  List<Item> get wishedItems => [for (final i in Item.values) if (wished(i)) i];

  /// Puts [item] on [type]'s wishes, last ([canWish]; once), to hold [goal] of it (none: one more than it holds now), and
  /// its ingredients with it ([_wishChain]; decisions-log 323). False when it can't, or already is.
  bool wish(String type, Item item, [int? goal]) {
    if (!canWish(type, item) || wishGoal(type, item) != null) return false;
    (wishlist[type] ??= {})[item] = max(1, goal ?? countOf(type, item) + 1);
    _wishChain(type, item);
    return true;
  }

  /// Takes [item] off [type]'s wishes (the last one leaves no entry), and the ingredient wishes it put on ([_wishPrune]).
  /// False when it wasn't on them.
  bool unwish(String type, Item item) {
    final items = wishlist[type];
    if (items == null || items.remove(item) == null) return false;
    if (items.isEmpty) wishlist.remove(type);
    _wishPrune();
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
  /// and holds at least the set's count; each with its ingredients ([_wishChain]). False when there is no set.
  bool wishSet(String type) {
    final set = wishSetOf(type);
    if (set.isEmpty) return false;
    for (final MapEntry(key: item, value: n) in set.entries) {
      final goals = wishlist[type] ??= {};
      goals[item] = max(n, goals[item] ?? 0);
      _wishChain(type, item);
    }
    return true;
  }

  /// Takes [type]'s whole set off its wishes ([wishSetOf]); its other wishes stay. False when none of it was on them.
  bool unwishSet(String type) => [for (final item in wishSetOf(type).keys) unwish(type, item)].contains(true);

  /// Takes every wish of [type] off (the Smithy's Wishlist tab, its group's Remove tapped twice), their ingredient wishes
  /// with them. False when it had none.
  bool unwishAll(String type) {
    if (wishlist.remove(type) == null) return false;
    _wishPrune();
    return true;
  }

  /// After [item] went on [type] ([Game.useItem]; decisions-log 300): with the Awaken it brought ([awakened]) every done
  /// wish of the type drops off (the set ends; no roll-on to the next Awaken); else a done wish for a kind no Awaken
  /// counts (the Cap, the Ring, [outsideAwaken]) drops off at once. An Awaken item's done wish stays, shown done, until
  /// then.
  /// A met wish's ingredient wishes go at once ([_wishPrune]; decisions-log 323), whether or not the wish waits for its
  /// Awaken.
  void _wishGiven(String type, Item item, {required bool awakened}) {
    if (wishlist[type] == null) return;
    for (final i in [if (awakened) ...wishesOf(type) else if (outsideAwaken.contains(item.slot)) item]) {
      if (wishDone(type, i)) unwish(type, i);
    }
    _wishPrune();
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
  /// least one), and its ingredients with it ([_wishChain]; decisions-log 323). False when it can't, or an open line has
  /// it.
  bool wishFreeAdd(Enum kind, [int more = 1]) {
    if (!canWishFree(kind) || freeWished(kind)) return false;
    wishFree.remove(kind); // a met line not yet swept goes, the new one last
    wishFree[kind] = inBag(kind) + max(1, more);
    _wishChain(null, kind);
    return true;
  }

  /// [kind]'s free line asking [by] more (fewer, when negative), never under one more than the Bag holds: the − and +
  /// of its Smithy page. Its goal after (null: none).
  int? wishFreeMore(Enum kind, int by) {
    final goal = freeGoal(kind);
    if (goal == null) return null;
    return wishFree[kind] = max(inBag(kind) + 1, goal + by);
  }

  /// Takes [kind]'s free line off, and the ingredient wishes it put on ([_wishPrune]). False when it had none.
  bool unwishFree(Enum kind) {
    if (wishFree.remove(kind) == null) return false;
    _wishPrune();
    return true;
  }

  /// [kind]'s free line off when it has one, else on for one more ([wishFreeAdd]). Whether it is on after.
  bool toggleFree(Enum kind) => freeWished(kind) ? !unwishFree(kind) : wishFreeAdd(kind);

  /// Takes every free line off (the Wishlist tab's group "For the Bag", its Remove tapped twice; decisions-log 303). False
  /// when none was open.
  bool unwishFreeAll() {
    final had = freeWishes.isNotEmpty;
    wishFree.clear();
    _wishPrune();
    return had;
  }

  /// The Smithy's Wishlist tab's rows (decisions-log 303): each type's open wishes (a met one, [wishDone], is off the tab
  /// at once) in [troopTypes] order, each type's in the order put on; then the open free lines ([freeWishes]) in theirs;
  /// then a row per product an ingredient wish still wants ([partNeeds]; decisions-log 323), in the order first put on.
  List<WishRow> get wishRows => [
        for (final type in troopTypes.keys)
          for (final item in wishesOf(type))
            if (wishCount(type, item) case (final have, final goal) when have < goal) _wishRow(type, item, goal - have),
        for (final kind in freeWishes)
          if (freeCount(kind) case (final have, final goal)) _wishRow(null, kind, goal - have),
        for (final MapEntry(key: kind, value: (:need, :parents)) in partNeeds.entries)
          if (need > 0) _wishRow(null, kind, need, parents),
      ];

  /// [kind]'s row for [type] (null: its free line, or with [parents] its ingredient wishes'), [need] still wanted
  /// ([WishRow]).
  WishRow _wishRow(String? type, Enum kind, int need, [List<Enum> parents = const []]) {
    final make = type == null ? need : max(0, need - inBag(kind));
    final rows = switch (kind) { final Item i => itemCraftRows(i), final Relic r => craftRows(r), _ => const <CraftRow>[] };
    return (
      type: type,
      kind: kind,
      need: need,
      make: make,
      parts: [for (final r in rows) (kind: r.kind, have: r.have, need: r.need * make)],
      parents: parents,
    );
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
  /// Their ingredient wishes go with them ([_wishPrune]; decisions-log 323).
  void _wishSweep() {
    final had = wishFree.length;
    wishFree.removeWhere((k, _) => freeDone(k));
    if (wishFree.length < had) _wishPrune();
  }

  /// What the Bag still lacks for one [item] ([Craft.itemCraftRows] short): each material and item short with what it
  /// has and needs, then the gold. Empty: the Bag pays for one ([Craft.canMake]), wherever the game is.
  List<CraftRow> wishShort(Item item) => [for (final r in itemCraftRows(item)) if (r.have < r.need) r];

  /// The materials the open wishes' recipes take ([wishedItems], [Craft.itemRecipe]; a free or an ingredient relic's,
  /// [Craft.craftRecipe], decisions-log 302, 323): the Bag's and the Shop's materials mark them, "Needed for your
  /// wishlist" (decisions-log 300).
  Set<Mat> get wishMats => {
        for (final i in wishedItems) ...?itemRecipe(i)?.materials.keys,
        for (final k in [...freeWishes, ...partWishes])
          if (k is Relic) ...?craftRecipe(k)?.materials.keys,
      };

  // Ingredient wishes (decisions-log 323).

  /// How many [part]s one [kind]'s recipe takes ([_productRecipe]'s items; 0: none).
  int _takes(Enum kind, Enum part) => switch (part) { final Item i => _productRecipe(kind)?.items[i] ?? 0, _ => 0 };

  /// Puts on, for [type]'s wish for [root] (null: [root]'s free line), an ingredient wish ([WishPart]) for every product
  /// its recipe takes that the Smithy makes ([canWishFree]), then theirs, each under the one whose recipe takes it (the
  /// owner: "maka item itu juga akan langsung ke whitelist"). One already on keeps its place. A product never goes under
  /// itself (a recipe that takes what it makes: no loop).
  void _wishChain(String? type, Enum root) {
    void down(List<Enum> chain) {
      for (final part in [...?_productRecipe(chain.isEmpty ? root : chain.last)?.items.keys]) {
        if (!canWishFree(part) || part == root || chain.contains(part)) continue;
        final next = [...chain, part];
        wishParts.add(WishPart(type, root, next));
        down(next);
      }
    }

    down(const []);
  }

  /// Whether the wish [part] hangs from still stands: its parent ingredient wish among [kept], else its root, a type's
  /// wish not yet met ([wishDone]: a met one's ingredients go at once, the owner's "Ikut terhapus") or a free line.
  bool _partStands(WishPart part, Set<WishPart> kept) => switch ((part.parent, part.type, part.root)) {
        (final parent?, _, _) => kept.contains(parent),
        (null, final type?, final Item item) => wishGoal(type, item) != null && !wishDone(type, item),
        (null, null, final kind) => wishFree.containsKey(kind),
        _ => false,
      };

  /// Takes off every ingredient wish whose parent went (decisions-log 323): its root wish taken off or met, or the
  /// ingredient wish it was under. [wishParts] keeps a parent before its own, so one pass in order sees each parent first.
  void _wishPrune() {
    if (wishParts.isEmpty) return;
    final kept = <WishPart>{};
    for (final p in wishParts) {
      if (_partStands(p, kept)) kept.add(p);
    }
    if (kept.length == wishParts.length) return;
    wishParts
      ..clear()
      ..addAll(kept);
  }

  /// How many of its product [type]'s wish for [root] (null: [root]'s free line) still has to craft: what an ingredient
  /// right under it is for. A type's: what it still lacks less what the Bag holds ([WishRow.make]); a free line's: what
  /// the Bag still lacks. 0 when met or gone.
  int _rootMake(String? type, Enum root) => switch ((type, root)) {
        (final type?, final Item item) => switch (wishCount(type, item)) { (final have, final need) => max(0, need - have - inBag(item)), null => 0 },
        (null, _) => switch (freeCount(root)) { (final have, final need) => need - have, null => 0 },
        _ => 0,
      };

  /// Each ingredient wish's share (decisions-log 323): [need], how many its parent's crafts still take (the recipe's count
  /// for each of the parent still to make: none once the parent is made), and [make], how many of those are still to
  /// craft: the Bag's of its product go to the wishes for it in order, the ones nearer their root first, so a parent's
  /// count is known before its own. Read live, as a type's counts are.
  Map<WishPart, ({int need, int make})> get _partShares {
    final out = <WishPart, ({int need, int make})>{}, left = <Enum, int>{};
    final deepest = wishParts.fold(0, (a, p) => max(a, p.chain.length));
    for (var depth = 1; depth <= deepest; depth++) {
      for (final p in wishParts) {
        if (p.chain.length != depth) continue;
        final over = switch (p.parent) { final q? => out[q]?.make ?? 0, null => _rootMake(p.type, p.root) };
        final need = _takes(p.parentKind, p.kind) * over, held = min(need, left[p.kind] ??= inBag(p.kind));
        left[p.kind] = left[p.kind]! - held;
        out[p] = (need: need, make: need - held);
      }
    }
    return out;
  }

  /// Each product an ingredient wish is for (decisions-log 323), in the order first put on: [need], how many its parents'
  /// crafts still want made (their [_partShares]' make added up: two parents' counts add up, the Bag's counted once), and
  /// [parents], the products whose crafts still take one, made or not, in order (the row's "for Royal Ring"; none: no
  /// parent needs it now, and the Bag's are no longer kept for it, [partHeld]).
  Map<Enum, ({int need, List<Enum> parents})> get partNeeds {
    if (wishParts.isEmpty) return const {};
    final shares = _partShares, out = <Enum, ({int need, List<Enum> parents})>{};
    for (final p in wishParts) {
      final (:need, :make) = shares[p]!;
      final was = out[p.kind], parents = [...?was?.parents];
      if (need > 0 && !parents.contains(p.parentKind)) parents.add(p.parentKind);
      out[p.kind] = (need: (was?.need ?? 0) + make, parents: parents);
    }
    return out;
  }

  /// The products an ingredient wish still wants made ([partNeeds]), in the order first put on.
  List<Enum> get partWishes => [for (final MapEntry(:key, :value) in partNeeds.entries) if (value.need > 0) key];

  /// Whether an ingredient wish still wants [kind] made ([partNeeds]): it is wished as an open wish is (the Items board's
  /// star and order, the product page's status).
  bool partWished(Enum kind) => (partNeeds[kind]?.need ?? 0) > 0;

  /// The products an ingredient wish holds [kind] for (decisions-log 323), made or still to make ([partNeeds]' parents;
  /// none: no ingredient wish needs it now): the product page's Give row gives way to "Needed for Royal Ring" while no
  /// type's open wish asks for it.
  List<Enum> partHeldFor(Enum kind) => partNeeds[kind]?.parents ?? const [];

  /// Takes every ingredient wish for [kind] off, and those under them (an ingredient row's ✕; decisions-log 323): the
  /// wishes they are for stay, and so does the player's own wish for [kind]. False when none was on.
  bool unwishPart(Enum kind) {
    final had = wishParts.length;
    wishParts.removeWhere((p) => p.kind == kind);
    if (wishParts.length == had) return false;
    _wishPrune();
    return true;
  }

  /// Takes every ingredient wish off (the Wishlist tab's group "Ingredients", its Remove tapped twice). False when none
  /// still wanted a craft.
  bool unwishParts() {
    final had = partWishes.isNotEmpty;
    wishParts.clear();
    return had;
  }

  // The save.

  /// The save's `wishlist` (type → its wishes by name, in order, each with how many the type is to hold; decisions-log
  /// 300), under `free` the open free lines (product name → how many the Bag is to hold, in order; decisions-log 302:
  /// no item and no relic share a name), and under `parts` the ingredient wishes of those (decisions-log 323), each its
  /// [WishPart.names] (["knight", "royalRing", "gemRing", "ring"]), a parent before its own: always there with a wish, so
  /// a save without it is one from before them. Only with some wish (a save without it: none).
  Map<String, Object> get _wishJson {
    final free = freeWishes;
    if (wishlist.isEmpty && free.isEmpty) return const {};
    return {
      'wishlist': {
        for (final MapEntry(key: type, value: goals) in wishlist.entries) type: {for (final MapEntry(key: i, value: n) in goals.entries) i.name: n},
        if (free.isNotEmpty) 'free': {for (final k in free) k.name: wishFree[k]!},
        'parts': [
          for (final p in wishParts)
            if (p.type != null || free.contains(p.root)) p.names,
        ],
      },
    };
  }

  /// [j]'s `wishlist` (a save without it: none): each type's wishes with their goals; a save from
  /// before the goals (decisions-log 282: a list of names) wishes each for one more than the type holds, as it was wished.
  /// A type that isn't a troop type, an item name this build doesn't know and a goal under 1 are skipped, an item twice
  /// kept once; under `free` the free lines (decisions-log 302), an item's or a relic's name each, skipped the same; under
  /// `parts` the ingredient wishes (decisions-log 323), one whose wish isn't there (nor its parent), with a name this
  /// build doesn't know or that its parent's recipe doesn't take skipped. A save from before them (no `parts`) puts on
  /// its wishes' ingredients as a wish put on now does ([_wishChain]). Read after the types' items ([Game.upgrades]).
  void _loadWishes(Map<String, dynamic> j) {
    final wishes = (j['wishlist'] as Map?) ?? const {};
    final items = Item.values.asNameMap(), relics = Relic.values.asNameMap();
    if (wishes['free'] case final Map free) {
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
    if (wishes['parts'] case final List parts) {
      for (final names in parts) {
        if (names case [final String type, final String root, ...final List chain] when chain.isNotEmpty) {
          final kinds = [for (final n in chain) n is String ? items[n] ?? relics[n] : null];
          final owner = type == WishPart._freeKey ? null : type, from = owner == null ? items[root] ?? relics[root] : items[root];
          if (from == null || kinds.contains(null) || (owner != null && !troopTypes.containsKey(owner))) continue;
          final part = WishPart(owner, from, kinds.cast<Enum>());
          if (_takes(part.parentKind, part.kind) > 0 && _partStands(part, wishParts)) wishParts.add(part);
        }
      }
    } else {
      for (final MapEntry(key: type, value: goals) in wishlist.entries) {
        for (final item in goals.keys) {
          _wishChain(type, item);
        }
      }
      for (final kind in wishFree.keys) {
        _wishChain(null, kind);
      }
      _wishPrune(); // a met wish's: none
    }
  }
}
