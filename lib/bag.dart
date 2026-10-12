part of 'main.dart';

// The book's Bag tab (Tas; #87, the grid: decisions-log 187). The left page is the bag as a common game's inventory
// ([Board._bagGrid]): one cell per kind owned, every cell the same size, under category chips (All, Items, Relics,
// Artifacts) and turned by pages; a kind with none left has no cell. Tapping a cell picks it ([Board._picked]; again:
// puts it back) and the facing page says what it is and what the player can do with it, action first
// ([Board._assignPage], decisions-log 202): its heading, where a Pusaka is, a line or two on what it does, then a row
// per action ([BagAction]): an item gives to troops or to a Pusaka's Carve and sells; a small relic goes on a troop,
// comes off one and sells; a Pusaka goes on a type (or moves), comes off it, sharpens, carves, and in the Vault melts
// and sells. Sell, Sharpen, Carve and To Vault act from their rows' light tags; the others open their chooser on the
// page, under the heading, with a Back, listing who can take it under a troop filter, scrolled by the wheel or a drag:
// - an item: one row per troop TYPE (an item goes on the whole type): its sprite and stars, its name and how many
//   are on the field, the kind's taken/cap, the stat it raises and the price, now and after, and the progress
//   toward its next awakening; or one row per Pusaka that takes Carve: that kind into its bar (decisions-log 196);
// - a relic: one row per living TROOP (one relic each, a Hero two): its sprite and stars, its name and type, the
//   relics it holds in their slots, its HP, and an artefact's stats now and after; to take one off, the troops
//   wearing it;
// - a Pusaka: one row per type, what it would do there; a Vault one's Melt, one row per Pusaka it could go into.
// What each would do is [Game.assignPreview] (the field's popup says the same). A row that can take it is a
// button, on tap UP (a drag on the list scrolls it): it gives one ([Board._useItem] / [Board._useRelic]), and
// the pick and the chooser stay while the bag holds more, so the next row can be tapped at once (#86). One that can't
// is greyed with why, and a tap on it says so in the message window. The filter: "All" and a chip per troop type,
// several at once (none: all). Only the player changes it: another pick, a turned page or the book shutting keep
// it (not saved). An item or a relic dragged out of the bag onto a troop on the field is the shortcut past the
// list, which meanwhile shows its chooser and lights the row of the type (or troop) under the pointer, red when it
// can't. With nothing picked the facing page is the book's blank paper (decisions-log 241; the Army detail shows each
// troop's relics). On any troop
// row a tap on a held relic's slot picks that relic out ([_AssignList.armed]; again: lets go) and the row's last line
// becomes "Remove" and its name: the button takes it off, back into the bag ([Board._takeOff]); during a wave it is
// greyed with why ([Game.whyNotTakeOff]).
// The Bag sells nothing (decisions-log 230; the owner, 2026-10-04: "semua aktifitas shop hanya bisa di lakukan di town,
// di tas di remove, dan di reuse codenya ketika di kota"; its Sell rows, a game without the Towns', went in decisions-log
// 296): no Sell row for an item, a small relic, a material or a Vault Artifact, and a grey line under the rows says where
// it sells ([Words.soldInTown]). The Town's
// Shop tab is this code again (shop_page.dart, decisions-log 230 and 269): its Buy and Sell grids, its own pick
// ([Board._storePick]) and the facing page's Buy rows ([Board._shopActions]); with nothing picked the facing page is
// blank paper too (decisions-log 248).

/// A Bag cell's loot (decisions-log 255): its [kind] at its [plus], an enhanced item's stack (an [Item] at 1 to 5,
/// [Enhance.bagOf]) its own cell and its own pick; every other kind, and an item at +0, at 0. The boards' cells, marks and
/// picks are keyed by it.
typedef BagLoot = ({Enum kind, int plus});

/// Whether [loot] can be in hand ([Board._picked]), and so has a cell in the Bag: some left in the bag (an item's
/// enhanced stack at +[plus], decisions-log 255), or a Pusaka owned (bound or in the Gudang: its type rows bind, move or
/// unbind it; an oath's show what it gives each type).
bool _canHold(Game g, Enum loot, [int plus = 0]) => switch (loot) {
      final Item item when plus > 0 => g.bagOf(item, plus) > 0,
      final Relic r when r.pusaka => g.pusaka.containsKey(r),
      _ => plus == 0 && g.inBag(loot) > 0,
    };

/// The Bag's category chips (decisions-log 187), in their order on the page: Materials since the Towns (decisions-log
/// 221); Artifacts only while the Shop is open or a Pusaka is owned ([Board._artifactsShown]).
/// The Town's Shop's Buy names its sections by them ([shopBuySections], decisions-log 269).
enum BagCategory { all, items, relics, materials, artifacts }

/// The chips' words (English, ui-hud.md "In-game text"; the mechanic's word from [Words]).
const bagCategoryNames = {
  BagCategory.all: 'All',
  BagCategory.items: 'Items',
  BagCategory.relics: 'Relics',
  BagCategory.materials: Words.materials,
  BagCategory.artifacts: '${Words.artifact}s',
};

/// The kinds of [category] that have a cell in the Bag, in its fixed order (decisions-log 187): the items with some in
/// the bag in [Item] order (every item: [Relics.itemsInPlay], decisions-log 245), then the small relics in [Relic] order
/// (every small relic: [Relics.relicsInPlay], decisions-log 227), then the Towns' materials held in [Mat] order
/// (decisions-log 221: Common, Rare, Trophy, then the forge's stones, [Materials.matsInPlay]), then every Pusaka owned (bound, in
/// the Gudang, an oath), the rarest first and in [Relic.values] order within a rarity. Nothing but owning moves a cell:
/// counts, binding, stars and the Gudang never reorder them.
List<Enum> bagKinds(Game g, BagCategory category) {
  final all = category == BagCategory.all;
  return [
    if (all || category == BagCategory.items)
      for (final i in g.itemsInPlay)
        if ((g.inventory[i] ?? 0) > 0) i,
    if (all || category == BagCategory.relics)
      for (final r in g.relicsInPlay)
        if ((g.relicBag[r] ?? 0) > 0) r,
    if (all || category == BagCategory.materials)
      for (final m in g.matsInPlay)
        if ((g.materials[m] ?? 0) > 0) m,
    if (all || category == BagCategory.artifacts)
      for (final rarity in Rarity.values.reversed)
        for (final r in Relic.values)
          if (r.pusaka && r.rarity == rarity && g.pusaka.containsKey(r)) r,
  ];
}

/// The Bag's item cells (decisions-log 255): each item in [Item] order ([Relics.itemsInPlay]) at +0 while the bag holds
/// some ([Game.inventory]), then its enhanced stacks, lowest plus first ([Enhance.enhancedHeld]), each its own cell.
List<BagLoot> _itemLoot(Game g) {
  final stacks = g.enhancedHeld;
  return [
    for (final i in g.itemsInPlay) ...[
      if ((g.inventory[i] ?? 0) > 0) (kind: i, plus: 0),
      for (final (j, plus) in stacks)
        if (j == i) (kind: i, plus: plus),
    ],
  ];
}

/// The cells of [category] in the Bag, in [bagKinds]' order, with each item's enhanced stacks after it ([_itemLoot],
/// decisions-log 255; none without Enhance): an item held only enhanced has its stacks' cells alone.
List<BagLoot> bagLoot(Game g, BagCategory category) => [
      if (category == BagCategory.all || category == BagCategory.items) ..._itemLoot(g),
      for (final k in bagKinds(g, category))
        if (k is! Item) (kind: k, plus: 0),
    ];

/// Whether the store's shelf sells [kind] now (decisions-log 230): the materials that have dropped ([Game.matsSeen],
/// the forge's Shop, decisions-log 248) and the store's Artifacts while their shelf is open ([Store.shelfOpen]; on the
/// board they come from the Boss Chest alone); never an item or a small relic (the Smithy makes them, decisions-log 245).
bool onShopShelf(Game g, Enum kind) => switch (kind) {
      Relic(pusaka: true) => storeGoods.contains(kind) && g.shelfOpen,
      final Mat m => g.matsSeen.contains(m),
      _ => false,
    };

/// A Bag slot's size at [k] screen px per sprite px (the book's pixel scale) and its icon's place in it, square like the
/// slot ([Board._framePlain]): a phone's (k 1) 36x36 with the 32-px icon at (2, 2); from k 2 the slot grows with k
/// around the icon (32 px, 64 from k 4), the desk's 44x44 (the 22-px slot at 2x) with it at (6, 6). The icons stay
/// whole multiples of their 16- and 32-px art. A [small] slot (the Smithy's materials, decisions-log 235) is 22x22 below
/// k 2 with the 16-px art at (3, 3): every loot icon file is Kenmi's 16-px icon doubled, so drawn at 16 it is that icon
/// itself, not a shrink; from k 2 it is a Bag slot.
({Size size, Rect icon}) bagCellSize(double k, {bool small = false}) {
  if (k < 2 && small) return (size: const Size.square(22), icon: const Rect.fromLTWH(3, 3, 16, 16));
  if (k < 2) return (size: const Size.square(36), icon: const Rect.fromLTWH(2, 2, 32, 32));
  final side = 32.0 * (k / 2).floor();
  return (size: Size.square(side + 6 * k), icon: Rect.fromLTWH(3 * k, 3 * k, side, side));
}

/// The gaps between Bag slots at [k], across and down: 2 sprite px each way (2 on a phone, 4 on the desk), so the
/// slots' cut corners meet in a small diamond at every crossing, as the owner's picture.
(double, double) bagCellGaps(double k) => (2 * k, 2 * k);

/// A board of Bag slots in [area] at [k] ([bagCellSize], [small] as its): as many columns as its width takes, centred, its
/// left edge on a whole pixel. The board ([Board._bagBoard]) and the headings over it ([Board._gridHead]) both stand on
/// it, so a heading starts where the leftmost slot does (decisions-log 269).
({int cols, double left, double width}) _gridSpan(Rect area, double k, {bool small = false}) {
  final size = bagCellSize(k, small: small).size, gapX = bagCellGaps(k).$1;
  final cols = math.max(1, ((area.width + gapX) / (size.width + gapX)).floor()), width = cols * size.width + (cols - 1) * gapX;
  return (cols: cols, left: (area.center.dx - width / 2).roundToDouble(), width: width);
}

/// What a Bag cell shows besides its icon (decisions-log 187), for tests: the count (null: under 2, no capsule), a
/// Pusaka's stars (null: not one) and Carve steps (its badge's gold "+3"; 0: none), the type it is bound to (null: none,
/// in the Gudang), whether it is an oath, whether its mark is faded (asleep: none of its type lives), NEW, and the green
/// ▲ (an item a fielded type can awaken with); on the Town's Shop page a shelf cell's buy price in place of the count
/// (null: none, decisions-log 230). On the Smithy's pages (decisions-log 235): a relic's count from 1, its ▲ when it can
/// be crafted now and its icon [faded] when not; a material [short] for the picked relic (its count, from 1, in the red
/// capsule); and whether the cell is on the [lit] card (a pick, a kind dragged, the Smithy's relic and its materials).
/// An enhanced stack's [plus] (decisions-log 255: its "+3" tag at the top left; 0: none). On the Shop's Sell grid how many
/// of it are set to sell ([basket], decisions-log 269: in the green capsule in place of the count; null: none). On the
/// Smithy's Items board an item on the Wishlist, in its Materials one a wish's recipe takes ([wished], decisions-log 282:
/// the gold star at the top left).
typedef BagMarks = ({
  int? count,
  int? stars,
  int ukir,
  String? bound,
  bool oath,
  bool asleep,
  bool isNew,
  bool ready,
  int? price,
  bool faded,
  bool short,
  bool lit,
  int plus,
  int? basket,
  bool wished,
});

/// One section of a board in sections ([Board._sections]; decisions-log 269 and 277): its heading's words (none: no
/// heading, and no empty slot after its last cell: the Smithy's Relics and Enhance boards, decisions-log 283), its cells,
/// and the muted line in place of its rows while it has none.
typedef _Section = ({String title, List<BagLoot> loot, String note});

/// The Bag grid between frames (decisions-log 187); the Town's Shop has two of its own ([shop], decisions-log 230 and 269:
/// Buy's and Sell's, [sell]), and the Smithy four ([smithy], decisions-log 235, 254 and 255: its relics' board, its items' board, its Enhance board
/// ([enhance]) and its materials). Its cells are keyed by [BagLoot]: an enhanced stack is a cell of its own.
class _BagGrid {
  _BagGrid({this.shop = false, this.sell = false, this.smithy = false, this.enhance = false, this.category = BagCategory.all});

  final bool shop; // the Town's Shop page's grid ([Board._shopPages]): its kinds, prices and pick are the Shop's
  final bool sell; // the Shop's Sell grid (decisions-log 269): what the Shop buys, its counts and the basket's, no prices
  final bool smithy; // a Smithy page's ([Board._smithyPages]): no chips, no NEW, never dragged; its marks are the Smithy's
  final bool enhance; // the Smithy's Enhance board (decisions-log 255): its stones are what it makes, its items as the Bag's
  BagCategory category; // the chip on: only the player changes it (or a pick it would hide), for the session
  final pages = <BagCategory, int>{}; // the page shown per category, for the session (not saved)
  var seen = <Enum>{}; // the kinds owned when the player last left the Bag page (or a game came in): the others are NEW
  BagLoot? down; // the cell the last press went down on (null: none): a tap UP picks it only on the same one
  double wheelAt = double.negativeInfinity; // when the wheel last turned a page ([_bagWheelGap])
  // This frame: the kinds of the category and how many a page holds, the pages, the slots of the page's board in
  // reading order (a kind's or empty), the cells shown in order, the chips, the pager's two buttons (Rect.zero: one
  // page), the grid's area (the wheel turns its page), each cell's marks and the empty text's lines (none: some cell
  // shows).
  var loot = <BagLoot>[];
  int perPage = 1, pageCount = 1, perOne = 1, perPaged = 1; // and how many one page holds alone, and with the pager
  final slots = <Rect>[];
  final cells = <(BagLoot, Rect)>[];
  final chips = <BagCategory, Rect>{};
  Rect back = Rect.zero, on = Rect.zero, grid = Rect.zero;
  final marks = <BagLoot, BagMarks>{};
  final counts = <BagLoot, Rect>{}; // each count capsule drawn, by cell (tests: the Smithy's tucked ones, decisions-log 237)
  final empty = <String>[];
  Rect emptyCard = Rect.zero, emptyText = Rect.zero; // the empty text's card and what its icon and lines take (tests)
  final pageOf = <BagLoot, int>{}; // the page each cell is on where a page holds no fixed count (the Shop's Buy sections)

  int get page => pages[category] ?? 0;

  /// The Smithy's board drawn at the small slot this frame (decisions-log 254: a page too short for it at the Bag's slot
  /// and two rows of materials under it, [Board._smithyPages]).
  bool shrunk = false;

  /// Whether its slots are the small ones ([bagCellSize]): the Smithy's materials, and its board where [shrunk].
  bool get small => smithy && (category == BagCategory.materials || shrunk);

  void clear() {
    slots.clear();
    cells.clear();
    chips.clear();
    marks.clear();
    counts.clear();
    empty.clear();
    pageOf.clear();
    back = on = grid = emptyCard = emptyText = Rect.zero;
  }
}

/// A wheel turns the Bag's page at most once in this many seconds: a notch turns one, a trackpad's swipe no more than
/// a few.
const _bagWheelGap = 0.25;

/// ui_icons.png's 16-px icons on the Bag's cells: NEW's "!" and the smallest green up arrow (an item a fielded type can
/// awaken with).
const _icNew = Offset(192, 32), _icReady = Offset(32, 144);

/// ui_icons.png's smallest white triangles, their visible pixels (as [_icBackSmall]), pointing left and right: the
/// pager's arrow tags ([Board._arrowTag]).
const _icPageBack = Rect.fromLTWH(132, 180, 7, 10), _icPageOn = Rect.fromLTWH(181, 180, 7, 10);

/// The Bag's slots in other colours (decisions-log 187, its "B1 slots"): the slot's paper, rim and cut corners
/// ([_framePaper], [_frameRim], [_frameDark]) recoloured ([_recolour]), the same paint on the plain and the lit card. A
/// pick's: a lighter paper in the orange slot's orange rim and a dark orange; a Pusaka's: its rarity's rim and dark
/// ([_rarityFrame], the chest cards'), on paper a fifth of the way to the rim, so the rarity reads on a phone's 1-px rim.
final _bagPickPaint = _bagSlotPaint(const Color(0xFFFFE9C2), const Color(0xFFF77622), const Color(0xFFB4461E));
final _bagRarityPaints = {
  for (final MapEntry(key: r, value: (rim, dark)) in _rarityFrame.entries) r: _bagSlotPaint(Color.lerp(_framePaper, rim, 0.2)!, rim, dark),
};

Paint _bagSlotPaint(Color paper, Color rim, Color dark) => Paint()
  ..filterQuality = FilterQuality.none
  ..colorFilter = _recolour([(_framePaper, paper), (_frameRim, rim), (_frameDark, dark)]);

/// The padding inside the Bag's empty card, in sprite px: its rim and cut corners.
const _bagCardPad = 4.0;

/// The book's "what it becomes" blue: a stat, a price or a progress after the gift.
const _previewInk = Color(0xFF2A6FD6);

/// The stat each item raises, shown first on its type's row.
const _itemStat = {
  Item.sword: StatKind.dmg,
  Item.staff: StatKind.dmg,
  Item.shield: StatKind.def,
  Item.boots: StatKind.speed,
  Item.bow: StatKind.range,
  Item.gloves: StatKind.rate,
  Item.potion: StatKind.regen,
};

/// What the player can do with the Bag's pick (decisions-log 202): its facing page lists them, one row each, under what
/// it is ([Board._actionsFor]). A row with a chooser ([chooses]) opens it on the page, in place of the list, with a Back:
/// [giveTroops] an item's type rows, [giveArtifact] its Give rows (Carve), [equip] a small relic's troop rows, [takeOff]
/// the troops wearing it, [types] an Artifact's type rows (equip, move, To Vault; an oath's: what it gives each type),
/// [melt] a Vault Artifact's Melt picker. The others act on their row's tags: [toVault] (a bound Artifact), [sharpen] and [carve] (an Artifact); [smithy] (a material's: the relics
/// the Smithy crafts with it, decisions-log 221); [buy] (the Town's Shop page's, decisions-log 230).
enum BagAction {
  giveTroops,
  giveArtifact,
  equip,
  takeOff,
  types,
  toVault,
  sharpen,
  carve,
  melt,
  smithy,
  buy;

  /// Whether its row opens a chooser.
  bool get chooses => const {giveTroops, giveArtifact, equip, takeOff, types, melt}.contains(this);
}

/// ui_icons.png's smallest triangles, their visible pixels (as [_icThen]): the green one pointing right (an action row
/// that opens a chooser: the "›") and the white one pointing left (the chooser's "‹ Back").
const _icOpen = Rect.fromLTWH(181, 196, 7, 10), _icBackSmall = Rect.fromLTWH(132, 180, 7, 10);

/// ui_icons.png's icons on the action rows (Sharpen's is the full star, [_icStar]): the wrench (Carve), the green plus
/// (Melt) and the gift (an item's Give to an Artifact with none to show).
const _icCarve = Offset(48, 16), _icMelt = Offset(0, 48), _icGift = Offset(128, 16);

/// An action row's measures (decisions-log 202): its inset, its title's and its line's text sizes, its icon's side (16 px
/// on a phone, 32 on the desk: [bagHeadIcon]), its height (the title's line, then a line that holds a tag) and the
/// page's text scale.
typedef _ActLook = ({double inset, double titleFs, double lineFs, double icon, double h, double ts});

/// The Tas page's list between frames.
class _AssignList {
  final filter = <String>{}; // the troop types it shows (empty: all, "All"); only the player changes it
  double scroll = 0; // how far down, in px
  double? dragY; // a drag scrolling it: where it began (null: none)
  BagLoot? shownFor; // what it lists: another loot (another stack of an item, decisions-log 255) starts it at the top again
  Rect list = Rect.zero; // where its rows are this frame (Rect.zero: no list)
  final rows = <(Rect, Object, bool, VoidCallback)>[]; // each row shown: where (clipped), whose (a type or a Unit), whether it can take it, its tap
  final chips = <String?, Rect>{}; // the filter's chips this frame, by type (null: All)
  // Taps on a row that are not the row's (on tap UP too, before it): a relic slot's, a Remove button's. With the
  // slots shown, for tests: whose, which relic (null: an empty slot), where.
  final taps = <(Rect, VoidCallback)>[];
  final slots = <(Unit, Relic?, Rect)>[];
  (Unit, Relic)? armed; // the held relic whose slot was tapped: its row offers Remove (#91)
  Rect lepas = Rect.zero; // its Remove button this frame (Rect.zero: not shown)
  // The Pusaka (decisions-log 151): this frame, for tests, the note's OK and Undo (by 'ok' / 'batal') and the Army rows'
  // Pusaka badges (by type).
  final note = <String, Rect>{};
  final badges = <String, (Rect, bool)>{}; // and whether it sleeps
  // Asah (Sharpen, decisions-log 154): the Pusaka whose Sharpen was tapped once (null: none), and this frame its button;
  // Ukir's (Carve, decisions-log 196) the same.
  Relic? asahArmed, carveArmed;
  Rect asah = Rect.zero, carve = Rect.zero;
  // Lebur (Melt, decisions-log 164): the Gudang Pusaka whose target picker is open on the facing page (null: none) and
  // the target whose row was tapped once (null: none); this frame the Melt button and the picker's Cancel.
  Relic? lebur, leburArmed;
  Rect leburBtn = Rect.zero, leburBack = Rect.zero;
  // The page's parts this frame, for tests (decisions-log 187 and 202, [Board.bagDetail]): where each is by key ('page',
  // 'icon', 'name', 'count', 'where', 'desc', 'sharpen', 'sharpenCost', 'carve', 'carveBtn', 'carveBar', 'toVault' (its
  // tag), 'empty') and the words drawn ('name', 'count', 'where', 'desc', 'sharpen', 'sharpenCost', 'carve', 'carveBar',
  // 'next', 'meltArmed', 'empty', and each action row's 'title:<action>' and 'hint:<action>').
  final detail = <String, Rect>{};
  final texts = <String, String>{};
  // The pick's chooser (decisions-log 202): the action whose chooser the player opened ([Board._openChooser]) and the
  // pick it was opened for (another pick shows its action list again); and this frame the action rows shown (what,
  // where: clipped to the list, whether it can now), the chooser shown (null: none) and its Back.
  BagAction? open;
  BagLoot? openFor;
  final actions = <(BagAction, Rect, bool)>[];
  BagAction? shown;
  Rect back = Rect.zero;

  void clear() {
    list = Rect.zero;
    rows.clear();
    chips.clear();
    taps.clear();
    slots.clear();
    lepas = asah = carve = leburBtn = leburBack = back = Rect.zero;
    note.clear();
    badges.clear();
    detail.clear();
    texts.clear();
    actions.clear();
    shown = null;
  }
}

extension on Board {
  /// The Bag pages: the grid on the left ([_bagGrid]); on the right who can take what is being dragged out of the bag,
  /// else the pick; none picked (or none left), the blank paper ([_assignPage]). [target] is the troop type
  /// the item being dragged onto the field would go to; [ps] the book's pixel scale (the cells' sprite scale).
  void _bagPages(Canvas c, Game g, Rect left, Rect right, double ts, double ps, String? target) {
    _bagShown = true;
    _bagGrid(c, g, left, ts, ps);
    if (_assign.asahArmed != null && _assign.asahArmed != _picked) _assign.asahArmed = null; // another pick lets a Sharpen go
    if (_assign.carveArmed != null && _assign.carveArmed != _picked) _assign.carveArmed = null; // and a Carve
    if (_assign.lebur != null && _assign.lebur != _picked) _assign.lebur = null; // and a Melt's picker
    if (_assign.lebur == null) _assign.leburArmed = null;
    final BagLoot? loot = switch ((_itemDrag, _relicDrag)) {
      (final Item i, _) => (kind: i, plus: _dragPlus),
      (_, final Relic r) => (kind: r, plus: 0),
      _ => _pickedAt,
    };
    _assignPage(c, g, loot, right, ts, ps, target);
  }

  /// Whether the book shows the Town's Shop on the Bag's code this frame (decisions-log 230).
  bool get _shopShown => _page == _Page.store;

  /// The grid the book shows: the Shop's tab's on its page ([_shopShown], shop_page.dart), the Smithy's materials on its
  /// page (smithy_page.dart), else the Bag's.
  _BagGrid get _grid => _shopShown ? _shop.grid : (_page == _Page.smithy ? _smithy.mats : _bag);

  /// Whether the shown cells stay where they are (never dragged out onto a troop): the Shop's goods on a shelf, the
  /// Smithy's relics and materials.
  bool get _cellsStay => _shopShown || _page == _Page.smithy;

  /// The shown grid's pick: the Shop's ([_storePick]: any kind on its shelf, held or not) or the Bag's loot in hand
  /// ([_picked]), at its plus (an enhanced stack's, decisions-log 255).
  BagLoot? get _pick => _shopShown ? _storePickAt : _pickedAt;
  set _pick(BagLoot? loot) {
    if (_shopShown) {
      _storePickAt = loot;
    } else {
      _pickedAt = loot;
    }
  }

  /// The cells of [category] on grid [b]: the Shop's Buy or Sell ([shopBuyLoot], [shopSellLoot]) or the Bag's ([bagLoot]).
  List<BagLoot> _gridLoot(Game g, _BagGrid b, BagCategory category) =>
      b.shop ? (b.sell ? shopSellLoot(g) : shopBuyLoot(g)) : bagLoot(g, category);

  /// Whether the Bag shows the Artifacts chip (and the Pusaka in All): the Shop is open or a Pusaka is owned.
  bool _artifactsShown(Game g) => g.storeOpen || g.pusaka.isNotEmpty;

  /// The left page (decisions-log 187): "Bag", the category chips ([_bagChips]), then the page's board ([_bagBoard]): a
  /// slot at every place a page holds, and in them a cell for each kind of the chip ([bagKinds]), a page at a time; the
  /// slots past the last kind stay empty, the board itself (the owner's picture, decisions-log 187's "B1 slots"). The
  /// held pick always has a cell in sight: a pick the chip hides turns it to All, and the page turns to it (a chip or a
  /// page turn the player makes puts it back first, [_bagChipTap], [_bagTurn]).
  void _bagGrid(Canvas c, Game g, Rect left, double ts, double ps) {
    const ink = Color(0xFF4A2C17);
    final b = _grid;
    _text(c, Words.bag, Offset(left.center.dx, _titleY(left, ts)), size: 22 * ts, color: ink, anchor: Anchor.center, bold: true);
    final area = Rect.fromLTRB(left.left, _underTitle(left, ts), left.right, left.bottom);
    if (b.category == BagCategory.artifacts && !_artifactsShown(g)) b.category = BagCategory.all;
    final held = _pick;
    if (held != null && _canHold(g, held.kind, held.plus) && !_gridLoot(g, b, b.category).contains(held)) b.category = BagCategory.all;
    final below = _bagChips(c, g, area, ts, ps) + math.max(4.0, 5.5 * ts);
    _bagBoard(c, g, Rect.fromLTRB(area.left, below, area.right, area.bottom), held, ts, ps);
  }

  /// The shown grid's board ([_grid]) in [area] (its top unrounded, see below): a slot at every place a page holds
  /// ([_bagSlot]), all the same size ([bagCellSize] at [ps]; the Smithy's materials small), and in them a cell for each
  /// kind of its category ([_gridKinds]; [_bagCell]) in reading order, a page at a time; the slots past the last kind
  /// stay empty. At the bottom the save's suggestion strip while it stands (the Bag's alone, [_noteStrip]) and under it,
  /// past one page, the pager ([_bagPager]), both moved with the board's rounding so they keep their place against the
  /// slots while the book bobs. The page turns to [held] (the pick) when it has a cell. No cell: what would fill it, on a
  /// card over whole rows of the board ([_bagEmpty]).
  void _bagBoard(Canvas c, Game g, Rect area, BagLoot? held, double ts, double ps) {
    final b = _grid, below = area.top, top = below.roundToDouble(); // whole pixels: the icons stay crisp

    // How many a page holds: the rows that fit above the note's strip (while it stands), and with more than a page
    // above the pager's band too. Counted from the unrounded top: the book bobs, so the rounded one's room changes by a
    // pixel from frame to frame, and a page that fits a row to within half a pixel would flicker between two sizes.
    final kinds = b.loot = _gridLoot(g, b, b.category), size = bagCellSize(ps, small: b.small).size;
    final (gapX, gapY) = bagCellGaps(ps);
    final (band, bandGap) = _pagerBand(ts, ps);
    final note = !b.shop && !b.smithy && g.pusakaSuggested;
    final (:cols, left: x0, width: gridW) = _gridSpan(area, ps, small: b.small);
    int rows(double h) => math.max(1, ((h + gapY) / (size.height + gapY) + 1e-9).floor()); // an exact fit fits, float noise or not
    final free = area.bottom - below - (note ? band + bandGap : 0);
    b
      ..perOne = cols * rows(free)
      ..perPaged = cols * rows(free - band - bandGap);
    final paged = kinds.length > b.perOne, per = b.perPage = paged ? b.perPaged : b.perOne;
    final pages = b.pageCount = math.max(1, (kinds.length + per - 1) ~/ per), at = held == null ? -1 : kinds.indexOf(held);
    final page = at >= 0 ? at ~/ per : b.page.clamp(0, pages - 1); // the pick stays in sight
    b
      ..pages[b.category] = page
      ..grid = Rect.fromLTRB(area.left, top, area.right, area.bottom);

    final shown = kinds.skip(page * per).take(per).toList(), rowsShown = per ~/ cols;
    // No kind: the empty text's card covers whole rows of the board, about a third of the way down.
    var card = (from: rowsShown, to: rowsShown);
    if (kinds.isEmpty) {
      final need = _bagEmptyHeight(g, ts, gridW - 2 * _bagCardPad * ps) + 2 * _bagCardPad * ps;
      final m = ((need + gapY) / (size.height + gapY)).ceil().clamp(1, rowsShown);
      final from = (rowsShown - m) ~/ 3;
      card = (from: from, to: from + m);
      _bagEmpty(c, g, Rect.fromLTWH(x0, top + from * (size.height + gapY), gridW, m * size.height + (m - 1) * gapY), ts, ps);
    }
    for (var i = 0; i < per; i++) {
      final row = i ~/ cols, r = Offset(x0 + (i % cols) * (size.width + gapX), top + row * (size.height + gapY)) & size;
      if (row >= card.from && row < card.to) continue;
      b.slots.add(r);
      if (i < shown.length) {
        _bagCell(c, g, shown[i].kind, r, ps, ts, plus: shown[i].plus);
      } else {
        _bagSlot(c, r, ps);
      }
    }
    var y = area.bottom + top - below; // the bottom as far from the drawn top as from the counted one
    if (paged) {
      _bagPager(c, Rect.fromLTRB(area.left, y - band, area.right, y), ts);
      y -= band + bandGap;
    }
    if (note) _noteStrip(c, g, Rect.fromLTRB(area.left, y - band, area.right, y), ts);
  }

  /// A section heading's height over a board at text scale [ts] ([_gridHead]).
  double _gridHeadHeight(double ts) => (math.max(10.0, 13 * ts) * 1.5).roundToDouble();

  /// A section's heading from [top] over a board of the Bag's slots in [area] ([_gridSpan] at [k], [small] as its slots;
  /// decisions-log 269, the owner: "text materialsnya di sejajarkan dengan posisi box yang paling kiri biar paddingnya
  /// tetap sama"): [title] bold from the board's left edge, the leftmost slot's, and [aside] in grey ending at its right
  /// edge, so the words keep the slots' padding at every size. The Smithy's "Materials", the Shop's Buy sections.
  /// Returns its band (the board's width, [_gridHeadHeight] tall) and where its title's words are.
  ({Rect band, Rect title}) _gridHead(Canvas c, Rect area, double top, String title, double ts, double k, {String? aside, bool small = false}) {
    const ink = Color(0xFF4A2C17), grey = Color(0xFF9E9080);
    final fs = math.max(10.0, 13 * ts), h = _gridHeadHeight(ts), span = _gridSpan(area, k, small: small), cy = top + h / 2;
    final right = span.left + span.width, asideW = aside == null ? 0.0 : _textWidth(aside, fs) + 6 * ts;
    final shown = _fit(title, fs, span.width - asideW);
    _text(c, shown, Offset(span.left, cy), size: fs, color: ink, bold: true);
    if (aside != null) _text(c, aside, Offset(right, cy), size: fs, color: grey, anchor: Anchor.centerRight);
    return (band: Rect.fromLTRB(span.left, top, right, top + h), title: Rect.fromLTWH(span.left, top, _textWidth(shown, fs, bold: true), h));
  }

  /// [secs] laid out as a board in sections in [area] ([_sections]; decisions-log 269 and 277), its slots small where
  /// [small] ([bagCellSize]): the columns ([_gridSpan]), the slot's size, each section's muted note in lines ([fs] at
  /// [noteH] each, its rows' place while it has no cells), and the pages: each piece on a page (a section's heading, row
  /// -1, or one of its rows: cells, or its note's lines) and its top on the page. A page ends between rows, never under
  /// a heading alone, and a section going on to the next page starts it with its heading again; past one page they are
  /// laid above the pager's band. [height]: what one page takes, whole pixels (with more than one the area's height, its
  /// pager at the bottom); [tallest]: the tallest page's pieces, the pager's band not counted. Counted from the area's
  /// unrounded top: the book bobs, so a room counted from a rounded top would change by a pixel from frame to frame
  /// (decisions-log 277: the Smithy's materials blinked).
  ({
    int cols,
    Size size,
    double fs,
    double noteH,
    List<List<String>> notes,
    List<List<({int sec, int row, double y})>> pages,
    double height,
    double tallest,
  }) _sectionsLay(Rect area, List<_Section> secs, double ts, double ps, {bool small = false}) {
    final size = bagCellSize(ps, small: small).size, gapY = bagCellGaps(ps).$2;
    final (band, bandGap) = _pagerBand(ts, ps);
    final span = _gridSpan(area, ps, small: small), cols = span.cols, headH = _gridHeadHeight(ts), sep = math.max(4.0, (6 * ts).roundToDouble());
    final fs = math.max(10.0, 13 * ts), noteH = (fs * 1.4).roundToDouble();
    final notes = [for (final s in secs) s.loot.isEmpty ? _wrap(s.note, fs, span.width, 2) : const <String>[]];

    List<List<({int sec, int row, double y})>> lay(double room) {
      final pages = [<({int sec, int row, double y})>[]];
      var y = 0.0;
      for (final (i, s) in secs.indexed) {
        final rows = s.loot.isEmpty ? 1 : (s.loot.length + cols - 1) ~/ cols, h = s.loot.isEmpty ? notes[i].length * noteH : size.height;
        final headed = s.title.isNotEmpty;
        for (var r = 0; r < rows; r++) {
          var page = pages.last, head = r == 0;
          var at = head ? (page.isEmpty ? 0.0 : y + sep) : y + gapY;
          if (page.isNotEmpty && at + (head && headed ? headH : 0) + h > room + 1e-9) {
            pages.add(page = []);
            head = true;
            at = 0;
          }
          if (head && headed) {
            page.add((sec: i, row: -1, y: at));
            at += headH;
          }
          page.add((sec: i, row: r, y: at));
          y = at + h;
        }
      }
      return pages;
    }

    var pages = lay(area.height);
    if (pages.length > 1) pages = lay(area.height - band - bandGap);
    double tall(List<({int sec, int row, double y})> page) =>
        page.isEmpty ? 0.0 : page.last.y + (secs[page.last.sec].loot.isEmpty ? notes[page.last.sec].length * noteH : size.height);
    final tallest = pages.map(tall).fold(0.0, math.max);
    final height = pages.length > 1 ? (area.height + 1e-6).floorToDouble() : tallest; // float noise: the same every frame
    return (cols: cols, size: size, fs: fs, noteH: noteH, notes: notes, pages: pages, height: height, tallest: tallest);
  }

  /// A board in sections in [area] on grid [b] (decisions-log 269 and 277; its top unrounded, as [_bagBoard]'s): the
  /// Shop's Buy, the Smithy's Items. Each section its heading over the board's left edge ([_gridHead]), then its cells as
  /// the Bag's slots ([_bagCell] on [b], [b]'s slot: [_BagGrid.small]) in whole rows, the last row's spare slots empty; a
  /// section with no cells its muted note in place of its rows; a gap between sections ([_sectionsLay]). Where they don't
  /// all fit, the Bag's pager ([_bagPager] on [b]) at the area's bottom turns pages. The page turns to [held] when it has
  /// a cell, else stays the grid's. Returns each heading drawn (its section and where its words are), each note drawn
  /// (its section and its words), and the board's height on the page.
  ({List<(int, Rect)> heads, Map<int, String> notes, double height}) _sections(Canvas c, Game g, Rect area, _BagGrid b, List<_Section> secs,
      BagLoot? held, double ts, double ps) {
    const grey = Color(0xFF9E9080);
    final lay = _sectionsLay(area, secs, ts, ps, small: b.small);
    final (:cols, :size, :fs, :noteH, :notes, :pages, height: _, tallest: _) = lay;
    final top = area.top.roundToDouble(), gapX = bagCellGaps(ps).$1, span = _gridSpan(area, ps, small: b.small);
    b.loot = [for (final s in secs) ...s.loot];
    for (final (p, page) in pages.indexed) {
      for (final piece in page) {
        if (piece.row >= 0) {
          for (final l in secs[piece.sec].loot.skip(piece.row * cols).take(cols)) {
            b.pageOf[l] = p;
          }
        }
      }
    }
    final page = b.pageOf[held] ?? b.page.clamp(0, pages.length - 1); // the pick stays in sight
    b
      ..pageCount = pages.length
      ..pages[b.category] = page
      ..perPage = b.perOne = b.perPaged = [for (final l in b.loot) if (b.pageOf[l] == page) l].length
      ..grid = Rect.fromLTRB(area.left, top, area.right, top + lay.height);

    final heads = <(int, Rect)>[], said = <int, String>{};
    for (final piece in pages[page]) {
      final s = secs[piece.sec], y = top + piece.y;
      if (piece.row < 0) {
        heads.add((piece.sec, _gridHead(c, area, y, s.title, ts, ps, small: b.small).title));
      } else if (s.loot.isEmpty) {
        for (final (i, line) in notes[piece.sec].indexed) {
          _text(c, line, Offset(span.left, y + (i + 0.5) * noteH), size: fs, color: grey);
        }
        said[piece.sec] = notes[piece.sec].join(' ');
      } else {
        for (var col = 0; col < cols; col++) {
          final i = piece.row * cols + col, r = Offset(span.left + col * (size.width + gapX), y) & size;
          b.slots.add(r);
          if (i < s.loot.length) {
            _bagCell(c, g, s.loot[i].kind, r, ps, ts, on: b, plus: s.loot[i].plus);
          } else if (s.title.isNotEmpty) {
            _bagSlot(c, r, ps);
          }
        }
      }
    }
    if (pages.length > 1) {
      // At the board's bottom, whole pixels under its drawn top: it keeps its place against the slots while the book bobs.
      final bottom = top + lay.height;
      _bagPager(c, Rect.fromLTRB(area.left, bottom - _pagerBand(ts, ps).$1, area.right, bottom), ts, on: b);
    }
    return (heads: heads, notes: said, height: lay.height);
  }

  /// The category chips across the top of [area] as one segmented control (decisions-log 198's "Bag chips": a light
  /// control, not ui_buttons' bevels): one paper strip, the Bag slot's card ([Board._framePlain]) at [k] screen px per
  /// sprite px, cut into a segment per category, All, Items, Relics, Materials ("Mats" where the words don't
  /// all fit) and, while it shows ([_artifactsShown]), Artifacts, each its word on the paper. The one on is lit as a picked slot (the lit card in the pick's cream and orange, [_bagPickPaint]) with its word
  /// bold; another lights under the mouse as a slot does and sinks a sprite px while pressed. As wide as each other where
  /// every word fits, else each as wide as its word and the room left shared out ([_chips]). A tap turns to that
  /// category ([_bagChipTap]). Returns the strip's bottom.
  double _bagChips(Canvas c, Game g, Rect area, double ts, double k) {
    final b = _grid;
    final cats = [
      BagCategory.all,
      BagCategory.items,
      BagCategory.relics,
      BagCategory.materials,
      if (_artifactsShown(g)) BagCategory.artifacts,
    ];
    final names = [for (final cat in cats) bagCategoryNames[cat]!];
    final at = _chips(c, area, ts, k, names,
        shorter: [for (final cat in cats) cat == BagCategory.materials ? Words.materialsShort : bagCategoryNames[cat]!],
        on: cats.indexOf(b.category),
        tap: (i) => _bagChipTap(cats[i]));
    for (final (i, cat) in cats.indexed) {
      b.chips[cat] = at[i];
    }
    return area.top + _chipsHeight(ts);
  }

  /// A segmented strip's height at text scale [ts] ([_chips]).
  double _chipsHeight(double ts) => math.max(20.0, 24 * ts).roundToDouble();

  /// The pager's band at the bottom of a board at text scale [ts] ([_bagPager]), and the gap above it at [k] ([_bagBoard]).
  (double, double) _pagerBand(double ts, double k) => (math.max(20.0, 26 * ts).roundToDouble(), math.max(bagCellGaps(k).$2, (4 * ts).roundToDouble()));

  /// One segmented control across the top of [area] ([_bagChips]' look, decisions-log 198's "Bag chips"; the Smithy's
  /// strips, decisions-log 254): a paper strip, the Bag slot's card ([Board._framePlain]) at [k] screen px per sprite px,
  /// cut into a segment per [words], each its word on the paper ([shorter]'s where [words] don't all fit). Segment [on]
  /// is lit as a picked slot (the lit card in the pick's cream and orange, [_bagPickPaint]) with its word bold; another
  /// lights under the mouse as a slot does and sinks a sprite px while pressed; segment [locked] is greyed (its word in
  /// the page's grey, never lit), its tap still landing (to say when it opens). As wide as each other where every word
  /// fits, else each as wide as its word and the room left shared out. A tap on segment i calls [tap] with i. Returns
  /// the segments' places, in [words]' order, on whole pixels as drawn (decisions-log 291: the strip's height exactly,
  /// where the book's bob left an unrounded top a hair under it).
  List<Rect> _chips(Canvas c, Rect area, double ts, double k, List<String> words,
      {List<String>? shorter, int on = -1, int locked = -1, required void Function(int i) tap}) {
    const ink = Color(0xFF4A2C17), soft = Color(0xFF7A5238), grey = Color(0xFF9E9080);
    final h = _chipsHeight(ts), pad = math.max(8.0, 14 * ts), n = words.length;
    final strip = _whole(Rect.fromLTWH(area.left, area.top, area.width, h)), room = area.width, even = room / n;
    _bagSlot(c, strip, k);
    var fs = math.max(10.0, 13 * ts), names = words;
    List<double> widths() => [for (final name in names) _textWidth(name, fs, bold: true) + pad];
    var wide = widths();
    if (wide.fold(0.0, (a, w) => a + w) > room && shorter != null) {
      names = shorter;
      wide = widths();
    }
    final need = wide.fold(0.0, (a, w) => a + w);
    if (need > room) fs *= room / need; // a page too narrow for them all at the text floor (none the game knows)
    final spare = math.max(0.0, room - need) / n, fitsEven = wide.every((w) => w <= even);
    final at = <Rect>[];
    var x = area.left;
    for (final (i, name) in names.indexed) {
      final w = fitsEven ? even : (need > room ? wide[i] * room / need : wide[i] + spare);
      final r = Rect.fromLTRB(x.roundToDouble(), strip.top, (x + w).roundToDouble(), strip.bottom);
      final lit = i == on, look = lit || i == locked ? ButtonLook.normal : _look(r);
      final seg = r.translate(0, look == ButtonLook.pressed ? k : 0);
      if (lit || look == ButtonLook.hover || look == ButtonLook.pressed) _bagSlot(c, seg, k, frame: Board._frameLit, paint: lit ? _bagPickPaint : null);
      _text(c, name, seg.center, size: fs, color: i == locked ? grey : (lit ? ink : soft), anchor: Anchor.center, bold: lit);
      _hits.add((r, () => tap(i)));
      at.add(r);
      x += w;
    }
    return at;
  }

  /// A tap on category [cat]'s chip: the grid shows it from its last page. A chip that would hide the pick puts it back
  /// first, and every armed button lets go ([_bagLetGo]).
  void _bagChipTap(BagCategory cat) {
    final b = _grid;
    if (cat == b.category) return;
    if (_pick case final held? when !_gridLoot(state, b, cat).contains(held)) _pick = null;
    b.category = cat;
    _bagLetGo();
  }

  /// The pager in [r] (more than a page) of grid [on] (the shown grid, [_grid], unless given: the Smithy's Items board,
  /// decisions-log 277): a small arrow tag at each end ([_arrowTag]: ◂ on the left, ▸ on the right), faded at the ends (a
  /// tap does nothing), and "1/2" between them. A tap on a tag's place, max(32, 42·ts) wide and the pager's height, turns
  /// a page ([_bagTurn]).
  void _bagPager(Canvas c, Rect r, double ts, {_BagGrid? on}) {
    const ink = Color(0xFF4A2C17);
    final b = on ?? _grid, w = math.max(32.0, (42 * ts).roundToDouble()), fs = math.max(10.0, 13 * ts);
    final back = b.back = Rect.fromLTWH(r.left, r.top, w, r.height), next = b.on = Rect.fromLTWH(r.right - w, r.top, w, r.height);
    for (final (btn, by, icon) in [(back, -1, _icPageBack), (next, 1, _icPageOn)]) {
      _arrowTag(c, btn, icon, fs, by < 0 ? b.page > 0 : b.page < b.pageCount - 1, () => _bagTurn(by, on: b));
    }
    _text(c, '${b.page + 1}/${b.pageCount}', r.center, size: fs, color: ink, anchor: Anchor.center);
  }

  /// A small arrow tag in [btn] (decisions-log 198's "Bag chips"; the kit's link look, [_TagLook.link]): ui_bars.png's
  /// outline capsule with [icon] (one of ui_icons.png's smallest white triangles) in its middle, the dark capsule under
  /// the mouse, a sprite px lower while pressed; as tall as a tag at [fs] ([capsuleSize]) and twice as wide, centred in
  /// [btn]. While it [can]'t, the capsule and the arrow are faded and it takes no tap; else its tap [fn] is the whole
  /// [btn] ([_hits]).
  void _arrowTag(Canvas c, Rect btn, Rect icon, double fs, bool can, VoidCallback fn) {
    final h = capsuleSize(0, fs).height, kk = capsuleK(h), look = _look(btn, enabled: can);
    final cap = _whole(Rect.fromCenter(center: btn.center, width: 2 * h, height: h)).translate(0, look == ButtonLook.pressed ? kk : 0);
    final paint = can ? _px : _ghost;
    _nine(c, look == ButtonLook.hover ? _capsuleSrc : _capsuleTrack, cap, kk, l: 1, t: 1, r: 1, b: 1, sheet: 'ui_bars.png', seam: 0, paint: paint);
    c.drawImageRect(_img('ui_icons.png'), icon, _whole(Rect.fromCenter(center: cap.center, width: icon.width, height: icon.height)), paint);
    if (can) _hits.add((btn, fn));
  }

  /// Turns grid [on]'s page (the shown grid's, [_grid], unless given) [by] (1: on, -1: back), within its pages. On the
  /// shown grid a turn that would hide the pick puts it back first, and every armed button lets go ([_bagLetGo]); the
  /// Smithy's Items board keeps its pick (its facing page shows it whatever the page).
  void _bagTurn(int by, {_BagGrid? on}) {
    final b = on ?? _grid, to = (b.page + by).clamp(0, b.pageCount - 1);
    if (to == b.page) return;
    if (_pick case final held? when identical(b, _grid) && b.loot.contains(held) && (b.pageOf[held] ?? b.loot.indexOf(held) ~/ b.perPage) != to) {
      _pick = null;
    }
    b.pages[b.category] = to;
    _bagLetGo();
  }

  /// The wheel ([dy]) over grid [on] (the shown grid, [_grid], unless given): a page on (down) or back (up), at most once
  /// in [_bagWheelGap] s.
  void _bagWheel(double dy, {_BagGrid? on}) {
    final b = on ?? _grid;
    if (dy == 0 || b.pageCount < 2 || _clock - b.wheelAt < _bagWheelGap) return;
    b.wheelAt = _clock;
    _bagTurn(dy > 0 ? 1 : -1, on: b);
  }

  /// A chip or a page turned: the buttons armed for a second tap let go (a Sharpen, a Carve, a Melt's picker and its
  /// target, a held relic's Remove), as another pick does.
  void _bagLetGo() => _assign
    ..asahArmed = null
    ..carveArmed = null
    ..lebur = null
    ..leburArmed = null
    ..armed = null;

  /// An empty slot of the Bag's board over [r] at [k] screen px per sprite px: the book's paper card ([Board._framePlain],
  /// ui_all.png's 22-px page frame: the page's paper inside a 1-px rim, its corners cut), as the owner's picture.
  void _bagSlot(Canvas c, Rect r, double k, {Rect frame = Board._framePlain, Paint? paint}) =>
      _nine(c, frame, _whole(r), k, paint: paint, seam: k == k.roundToDouble() ? 0 : 0.5);

  /// [kind]'s cell over [r] at [k] screen px per sprite px (decisions-log 187, its "B1 slots"): the board's slot
  /// ([_bagSlot]) with the kind in it, a Pusaka's in its rarity's colours ([_bagRarityPaints]); picked or dragged, the lit
  /// card ([Board._frameLit], its rim 2 px) in the pick's orange on a lighter paper ([_bagPickPaint]); under the mouse the
  /// lit card, and pressed the lit card sunk a sprite px ([_look]). Its icon, and its marks: NEW's "!" in a dark capsule
  /// at the top left (a kind owned since the player last left the page, [_BagGrid.seen]); at the top right an item's
  /// green ▲ (a fielded type can awaken further with it: [Ascend.bagLevel]); at the bottom right the count from 2 up
  /// ([shortCount]) or a Pusaka's stars ("★2+3": its Carve steps in gold); at the top left (right of NEW's "!") the type
  /// a Pusaka is bound to (its sprite in its awakening's line, faded while it sleeps) or an oath's crossed swords: the
  /// corners the pack's diagonal weapons leave empty. On the Town's Shop page (decisions-log 230) no NEW; on its Buy grid a
  /// shelf cell's buy price ([Store.buyPrice], [shortPrice]: "2000", "8000", "24k") in the count's capsule, on its Sell
  /// grid a stack set to sell its count in the basket in the green capsule in place of its count (a Vault Artifact's at the
  /// top right, its stars keeping their corner; decisions-log 269: [_ShopView.basket]). On a Smithy page
  /// ([_BagGrid.smithy], decisions-log 235) a relic's count from 1, its green ▲ when it can be crafted now ([Craft.canCraft])
  /// and its icon faded to 40% when not, and so an item on the forge's Items tab ([Craft.canCraftItem], decisions-log 254);
  /// the pick shown ([_smithyShownAt]) and its recipe's materials on the lit card, a material it is short of with its count
  /// (from 1) in the red capsule; no NEW. The cell is [on]'s (the shown grid, [_grid], unless given). An item's enhanced
  /// stack at +[plus] (decisions-log 255; forge-design §12): its icon in the level's colour ([_plusPaint]), its "+3" tag
  /// at the top left (the dark capsule, the digits in that colour, [EnhanceRules.tints]), its count as any cell's, never
  /// NEW. On the Smithy's Enhance board ([_BagGrid.enhance]) a stone is what it makes (its ▲, count from 1, faded while it
  /// can't be made, [Enhance.canCraftStone]) and an item as the Bag's, without its ▲. On the Smithy's Items board an item on
/// the Wishlist ([Wishlist.wished]) and in its Materials one a wish's recipe takes ([Wishlist.wishMats]) carry the pack's
/// gold star at the top left (decisions-log 282; on a 22-px slot tucked 2 px out, clear of the ▲). Registered for the tooltips, taps
  /// and drags ([_slots] with its plus, [_relicSlots], [_matSlots]; the Shop's and the Smithy's cells are never dragged,
  /// [_cellsStay]).
  void _bagCell(Canvas c, Game g, Enum kind, Rect r, double k, double ts, {_BagGrid? on, int plus = 0}) {
    final b = on ?? _grid, relic = kind is Relic ? kind : null, own = relic != null && relic.pusaka ? g.pusaka[relic] : null;
    final cell = (kind: kind, plus: plus), pick = b.smithy ? _smithyShownAt(g) : null, need = pick == null ? null : _smithyMats(g, pick);
    final held = b.smithy
        ? cell == pick || plus == 0 && (need?.containsKey(kind) ?? false)
        : _pick == cell || _itemDrag == kind && _dragPlus == plus || _relicDrag == kind;
    final look = _look(r), sink = look == ButtonLook.pressed ? k : 0.0;
    _bagSlot(c, r.translate(0, sink), k,
        frame: held || look == ButtonLook.hover || look == ButtonLook.pressed ? Board._frameLit : Board._framePlain,
        paint: held ? _bagPickPaint : (relic != null && relic.pusaka ? _bagRarityPaints[relic.rarity] : null));
    // What a Smithy board makes: a relic or an item (the Items tab's), on the Enhance board a stone.
    final fs = math.max(10.0, 11 * ts), mark = k < 2 ? 14.0 : 18.0, made = b.smithy && (b.enhance ? kind is Mat : kind is! Mat);
    final craftable = made && switch (kind) { final Item item => g.canCraftItem(item), final Mat stone => g.canCraftStone(stone), _ => g.canCraft(relic!) };
    final faded = made && !craftable;
    _icon(c, kind, _whole(bagCellSize(k, small: b.small).icon.shift(r.topLeft + Offset(0, sink))), faded ? _smithyFaded : null, plus);

    final n = own == null ? (kind is Item ? g.bagOf(kind, plus) : g.inBag(kind)) : 0;
    final isNew = plus == 0 && !b.shop && !b.smithy && !b.seen.contains(kind);
    final price = plus == 0 && b.shop && !b.sell && own == null && onShopShelf(g, kind) ? g.buyPrice(kind) : null; // an Artifact owned is sold out
    final basket = b.sell ? _shop.basket[cell] : null;
    final short = kind is Mat && n < (need?[kind] ?? 0);
    final ready = made ? craftable : kind is Item && !b.enhance && _bagReady(g, kind), asleep = relic != null && g.pusakaAsleep(relic);
    final counted = n >= 2 || n >= 1 && (short || made); // the Smithy's relics and items, and a short material, from 1
    // The Wishlist's star (decisions-log 282, 300, 302): an item on the Smithy's Items board, a relic a free line has on its
    // Relics board, a material its open wishes take in the Bag's Materials and the Shop's Buy.
    final wished = !b.enhance &&
        !b.sell &&
        switch (kind) { final Item i => b.smithy && g.wished(i), final Relic r => b.smithy && g.freeWished(r), final Mat m => g.wishMats.contains(m), _ => false };
    if (isNew) {
      // The "!" (4x14 of its 16-px icon, at x 6) in a dark capsule 10x16 like the counts', so it reads on any icon.
      final box = Rect.fromLTWH(r.left + k, r.top + k + sink, 10, 16);
      _nine(c, _capsuleSrc, box, 1, l: 1, t: 1, r: 1, b: 1, sheet: 'ui_bars.png', seam: 0);
      _uiIcon(c, _icNew, Rect.fromLTWH(box.left - 3, box.top, 16, 16));
    }
    if (plus > 0) {
      // An enhanced stack's "+3" where NEW's "!" goes (a stack is never NEW): on a 22-px cell tight and tucked out into
      // the gap, as the counts are.
      final tuck = b.small && k < 2;
      _capsule(c, '+$plus', fs, tuck ? Offset(r.left - 1, r.top - 1 + sink) : Offset(r.left + k, r.top + k + sink),
          anchor: Anchor.topLeft, ink: _plusInk(g, plus), tight: tuck);
    }
    if (ready) {
      // On a 22-px cell (the Smithy's board drawn small, decisions-log 254) the ▲'s 10x10 (at (3, 4) of its 16) tucked to
      // the slot's top right corner, a px out into the gap, as the count is to the bottom right: most of the icon reads.
      final tuck = b.small && k < 2;
      _uiIcon(c, _icReady, Rect.fromLTWH(r.right - (tuck ? 11 : 16 + k - 1), r.top + (tuck ? -5 : k) + sink, 16, 16));
    }
    if (wished) {
      // The Wishlist's star (decisions-log 282; ui_icons.png (48, 0), its 14x14 at (1, 1)) at the top left, the corner the
      // Smithy leaves free (no NEW, no "+"); on a 22-px slot tucked 2 px out into the gap, so it takes the icon's corner
      // only (9x9 of its 16) and stands clear of the ▲ at the top right. The pack's own 16 px: no smaller star reads. In the
      // Bag a NEW material's "!" keeps the corner: the star goes right of it.
      final tuck = b.small && k < 2;
      _uiIcon(c, _icStar, Rect.fromLTWH(r.left + (tuck ? -3 : k - 1) + (isNew ? 10 : 0), r.top + (tuck ? -3 : k - 1) + sink, 16, 16));
    }
    // A Pusaka's stars at the bottom right (no count there: one of each), clear of its icon's head, top right on the
    // pack's diagonal weapons; its type at the top left, the corner they leave empty.
    if (own != null) {
      _capsule(c, '$_starGlyph${own.stars}', fs, Offset(r.right - k, r.bottom - k + sink), anchor: Anchor.bottomRight, tail: ukirMark(own.ukir));
    }
    if (price != null) {
      _capsule(c, shortPrice(price), fs, Offset(r.right - k, r.bottom - k + sink), anchor: Anchor.bottomRight);
    } else if (basket != null) {
      // A Pusaka's stars keep the bottom right corner: its count to sell goes to the top right.
      b.counts[cell] = own != null
          ? _capsule(c, shortCount(basket), fs, Offset(r.right - k, r.top + k + sink), green: true)
          : _capsule(c, shortCount(basket), fs, Offset(r.right - k, r.bottom - k + sink), anchor: Anchor.bottomRight, green: true);
    } else if (counted) {
      // The Smithy's 22-px material cells: the count's capsule tight and tucked into the slot's corner, half a gap out,
      // so a 2-digit count leaves the 16-px icon readable (decisions-log 237).
      final tuck = b.small && k < 2;
      b.counts[cell] = _capsule(
          c, shortCount(n), fs, tuck ? Offset(r.right + 1, r.bottom + 1 + sink) : Offset(r.right - k, r.bottom - k + sink),
          anchor: Anchor.bottomRight, red: short, tight: tuck);
    }
    final box = Rect.fromLTWH(r.left + 2 * k + (isNew ? 10 : 0), r.top + 2 * k + sink, mark, mark); // right of NEW's "!"
    if (own?.type case final type?) {
      final bounds = _idleBounds[type]!, s = math.min(box.width / bounds.width, box.height / bounds.height);
      c.save();
      c.translate(box.center.dx, box.bottom);
      c.scale(s);
      _frame(c, 'book_${type}_idle', 0, Offset.zero, anchor: Offset(bounds.center.dx, bounds.bottom), paint: asleep ? _ghost : _px,
          line: _awakeLine(g.awakenLevel(type), ghost: asleep));
      c.restore();
    } else if (own != null && relic!.oath) {
      _uiIcon(c, Board._icSwords, box);
    }
    b
      ..cells.add((cell, r))
      ..marks[cell] = (
        count: counted && price == null && basket == null ? n : null,
        stars: own?.stars,
        ukir: own?.ukir ?? 0,
        bound: own?.type,
        oath: own != null && relic!.oath,
        asleep: asleep,
        isNew: isNew,
        ready: ready,
        price: price,
        faded: faded,
        short: short,
        lit: held,
        plus: plus,
        basket: basket,
        wished: wished,
      );
    switch (kind) {
      case final Item item:
        _slots.add((r, item, plus));
      case final Relic relic:
        _relicSlots.add((r, relic));
      case final Mat m:
        _matSlots.add((r, m));
    }
  }

  /// Whether some fielded type (one with a living troop) can awaken further from the bag ([Ascend.bagLevel]) and still
  /// takes [item] toward it: in its recipe, short of the next level's count. The Bag tab's red dot, item by item.
  bool _bagReady(Game g, Item item) {
    for (final type in {for (final u in g.troops) if (u.alive) u.type}) {
      if (g.bagLevel(type) > g.itemLevel(type) && g.awakenShort(type).containsKey(item)) return true;
    }
    return false;
  }

  /// What the Bag would hold, when no cell shows: All's bag icon and "Your bag is empty.", or the category's own line;
  /// Relics counts those worn, Artifacts says where they come from. The Town's Shop's Sell grid (decisions-log 269): that
  /// the Bag holds nothing it buys. What drops (decisions-log 292): monsters drop no item, only materials, and the Smithy
  /// makes the items (decisions-log 246), so "Monsters drop materials." and All's "Make items at the Smithy in a Town.".
  List<String> _bagEmptyLines(Game g) {
    const drops = '${Words.monstersDropMats}.';
    if (_grid.shop) return [shopNothingToSell, drops];
    final worn = g.troops.where((u) => u.alive).fold(0, (n, u) => n + u.relics.length);
    return switch (_grid.category) {
      BagCategory.all => ['Your bag is empty.', drops, '${Words.makeItemsAtSmithy}.'],
      BagCategory.items => ['No items yet.'],
      BagCategory.relics => ['No relics in the bag.', if (worn > 0) '$worn worn by troops.'],
      BagCategory.materials => ['No ${Words.materials.toLowerCase()} yet.', 'Monsters drop them.'],
      BagCategory.artifacts => [
          'No ${Words.artifact}s yet.',
          '${Words.bossChest}s give them.',
          if (g.storeOpen && g.shelfOpen) 'A ${Words.town}\'s ${Words.shop} sells some.',
        ],
    };
  }

  /// [_bagEmpty]'s text size, line height and icon side (0: none, a category's lines alone; the Bag's All alone has its
  /// bag) at [ts].
  ({double fs, double lineH, double icon}) _bagEmptyType(double ts) {
    final fs = math.max(10.0, 13 * ts);
    return (fs: fs, lineH: (fs * 1.4).roundToDouble(), icon: _grid.category == BagCategory.all && !_grid.shop ? 32.0 : 0.0);
  }

  /// [_bagEmptyLines] as drawn [width] wide at [fs]: a line too long for it goes on over a few.
  List<String> _bagEmptyShown(Game g, double fs, double width) => [for (final line in _bagEmptyLines(g)) ..._wrap(line, fs, width, 3)];

  /// How tall [_bagEmpty]'s icon and lines stand at [ts], its lines [width] wide.
  double _bagEmptyHeight(Game g, double ts, double width) {
    final (:fs, :lineH, :icon) = _bagEmptyType(ts);
    return (icon > 0 ? icon + lineH / 2 : 0) + _bagEmptyShown(g, fs, width).length * lineH;
  }

  /// [_bagEmptyLines] centred in grey on a card over [r] (whole rows of the board, in place of their slots): the board's
  /// slot art grown ([Board._framePlain], at [k] screen px per sprite px), so the text never crosses a slot's rim.
  void _bagEmpty(Canvas c, Game g, Rect r, double ts, double k) {
    const grey = Color(0xFF9E9080);
    final (:fs, :lineH, :icon) = _bagEmptyType(ts);
    final width = r.width - 2 * _bagCardPad * k;
    _bagSlot(c, r, k);
    var y = (r.center.dy - _bagEmptyHeight(g, ts, width) / 2).roundToDouble();
    final top = y;
    if (icon > 0) {
      _uiIcon(c, Board._icBag, _whole(Rect.fromLTWH(r.center.dx - icon / 2, y, icon, icon)));
      y += icon + lineH / 2;
    }
    for (final line in _bagEmptyShown(g, fs, width)) {
      final shown = _fit(line, fs, width);
      _text(c, shown, Offset(r.center.dx, y + lineH / 2), size: fs, color: grey, anchor: Anchor.center);
      _grid.empty.add(shown);
      y += lineH;
    }
    _grid
      ..emptyCard = r
      ..emptyText = Rect.fromLTRB(r.left + _bagCardPad * k, top, r.right - _bagCardPad * k, y);
  }

  /// The Bag's cells this frame ([_slots], [_relicSlots], [_matSlots]): where, and whose (an item's at its plus, an
  /// enhanced stack's, decisions-log 255; every other at 0).
  List<(Rect, BagLoot)> get _bagCellsNow => [
        for (final (r, i, plus) in _slots) (r, (kind: i, plus: plus)),
        for (final (r, x) in _relicSlots) (r, (kind: x, plus: 0)),
        for (final (r, m) in _matSlots) (r, (kind: m, plus: 0)),
      ];

  /// The Bag cell under [p] this frame (null: none).
  BagLoot? _bagLootAt(Offset p) => [for (final (r, cell) in _bagCellsNow) if (r.contains(p)) cell].firstOrNull;

  /// Where [cell]'s Bag cell is this frame (Rect.zero: not shown).
  Rect _bagSlotOf(BagLoot cell) => [for (final (r, c) in _bagCellsNow) if (c == cell) r].firstOrNull ?? Rect.zero;

  /// A tap UP at [p] on a Bag cell picks its kind (the one in hand: puts it back), and its NEW goes. Only when the press
  /// went down on the same kind ([_BagGrid.down]): a cell that slid under the finger while it was down (a kind ran out
  /// and the cells closed up) is not picked. A cell only ever picks, never acts. On the Town's Shop page it picks the
  /// Shop's kind ([_storePick]), held or not; on its Sell grid it also goes in the basket at 1 ([_shopSellTap]); on the
  /// Smithy's a relic's picks its recipe ([_SmithyView.pick]; again: it
  /// stays, the facing page always shows one), an item's likewise ([_SmithyView.item], decisions-log 254), on the Enhance
  /// board a stone or an item's stack ([_SmithyView.enhance], decisions-log 255), a material's does nothing (its tooltip
  /// says what it is). An enhanced stack's cell picks that stack (decisions-log 255).
  void _bagTap(Offset p) {
    final b = _grid, cell = _bagLootAt(p), down = b.down;
    b.down = null;
    if (cell == null || cell != down) return;
    final (:kind, :plus) = cell;
    if (b.smithy) {
      // The Wishlist tab's parts tell (their tooltips; decisions-log 303), and one the Smithy makes opens its page
      // (decisions-log 323, [_smithyLink]).
      if (_smithyTab(state) == SmithyTab.wishlist) {
        if (_smithy.links.any((l) => l.$2 == kind && l.$1.contains(p))) _smithyLink(kind);
        return;
      }
      _smithy.trail.clear(); // a pick on a board: no Back to a link's page
      if (_smithyTab(state) == SmithyTab.enhance) {
        // The Enhance board's stone or stack (the materials' grid under it picks nothing).
        if (_smithy.enhanceBoard.cells.any((c) => c.$1 == cell && c.$2.contains(p))) _smithy.enhancePick = cell;
        return;
      }
      switch (kind) {
        case final Relic relic:
          _smithy.pick = relic;
        case final Item item:
          // The board turns to it (a wish picked in the Wishlist block, decisions-log 300).
          _smithy
            ..item = item
            ..toItem = true;
      }
      return;
    }
    b.seen.add(kind);
    if (b.sell) return _shopSellTap(cell); // the Shop's Sell: into the basket (shop_page.dart)
    if (b.shop) {
      _storePickAt = _storePickAt == cell ? null : cell;
      return;
    }
    _pickedAt = _pickedAt == cell || !_canHold(state, kind, plus) ? null : cell;
  }

  /// The player leaves the Bag page (another tab, the book shut): every kind owned now is no longer NEW.
  void _bagLeft() => _bag.seen = {...bagKinds(state, BagCategory.all)};

  /// The wheel over the list scrolls it (not where the open battle log lies over it: that is the log's); over the Bag's
  /// grid it turns its page ([_bagWheel]), and over a Smithy board that board's (decisions-log 277: the Items tab's; 283:
  /// the Relics and Enhance tabs' too; 300: the Items tab's Wishlist block).
  void _assignWheel(Offset p, double dy) {
    if (_log.open && _log.panel.contains(p)) return;
    if (_assign.list.contains(p)) _assign.scroll += dy;
    if (_grid.grid.contains(p)) _bagWheel(dy);
    if (_page != _Page.smithy) return;
    for (final board in [_smithy.items, _smithy.board, _smithy.enhanceBoard, _smithy.wishes]) {
      if (board.grid.contains(p)) _bagWheel(dy, on: board);
    }
  }

  /// A filter chip: All shows every type again; a type's adds it to what is shown, or takes it out (all of
  /// them is All).
  void _filterTap(String? type) {
    final f = _assign.filter;
    if (type == null) {
      f.clear();
    } else if (!f.remove(type)) {
      f.add(type);
      if (f.length == troopTypes.length) f.clear();
    }
    _assign.scroll = 0;
  }

  // The Pusaka on the Tas page (decisions-log 151; their rules: lib/pusaka.dart), and a Pusaka's Asah (154). Each owned
  // one has a cell in the Bag's grid (decisions-log 187); its facing page binds, moves or unbinds it.

  /// [kind]'s name as the book says it: an item's, a relic's (a Pusaka's), a material's.
  String _lootName(Enum kind) => switch (kind) { final Relic r => relicNames[r]!, final Item i => itemNames[i]!, final Mat m => m.label, _ => kind.name };

  /// [kind]'s Buy row on the Town's Shop page ([BagAction.buy], decisions-log 230): the coin stack, "Buy", its light tag
  /// "Buy 20k" ([Store.buy] at [Store.buyPrice]; a tap buys one: the coin and the heading's count tell it, as the Sell
  /// row's Sell) and its line what one costs now and the next ("20,000 gold, then 24,000"; "65 gold each" where the next
  /// costs the same, the forge's materials, decisions-log 248). Refused ([Store.whyNotBuy]) the tag is greyed, the line
  /// says why in red ("Not enough gold"; an Artifact owned or off the shelf, its tag "Buy" alone) and a tap says why.
  void _buyRow(Canvas c, Game g, Enum kind, Rect r, _ActLook m) {
    final a = _assign, why = g.whyNotBuy(kind), price = g.buyPrice(kind), next = g.buyPrice(kind, 1), end = r.right - m.inset;
    final (:x, :y1, :y2) = _actCard(c, BagAction.buy, r, m, why == null, (box, paint) => _uiIcon(c, _icCoins, box, paint));
    final priced = !const {StoreRefusal.owned, StoreRefusal.shelf, StoreRefusal.notSold}.contains(why);
    final label = priced ? '${Words.buy} ${shortPrice(price)}' : Words.buy;
    final tag = _rowTag(c, r, end, y1, label, m.lineFs, why == null ? _TagLook.go : _TagLook.off, () => _buyLoot(kind));
    _actTitle(c, BagAction.buy, Words.buy, x, y1, tag.cap.left - 6 * m.ts, m, why == null);
    final now = '${thousands(price)} gold';
    _actLine(c, BagAction.buy, why == null ? null : g.storeWhy(why), next == price ? '$now each' : '$now, then ${thousands(next)}', x, y2, end, m,
        shorter: [now]);
    a
      ..detail['buy'] = tag.hit
      ..texts['buy'] = label;
    _keepFromLog(tag.cap); // the open battle log keeps clear of it (battle_log.dart)
  }

  /// A tap on the Shop's Buy for [kind]: one into the bag ([Store.buy]). Refused: the error and why.
  void _buyLoot(Enum kind) {
    final g = state;
    if (g.whyNotBuy(kind) case final why?) {
      g.buy(kind); // the error
      return showMessage(g.storeWhy(why));
    }
    g.buy(kind);
  }

  /// The save's suggestion strip in [r] ([pusakaNoteStrip]) at the bottom of the Bag's left page, while it stands
  /// ([Pusaka.pusakaSuggested]): OK keeps it ([Pusaka.dismissPusakaNote]), Undo sends every suggested Pusaka back to the
  /// Gudang, its first binding free again ([Pusaka.undoDefaultBinding]; mid-wave a tap says why). Starting a wave keeps
  /// it too (Board.update).
  void _noteStrip(Canvas c, Game g, Rect r, double ts) {
    const ink = Color(0xFF4A2C17);
    final fs = math.max(10.0, 13 * ts), h = r.height, k = (h / 16).floorToDouble().clamp(1.0, 3.0);
    var x = r.right;
    for (final (key, label, fn) in [('batal', Words.undo, _undoPusakaSuggestion), ('ok', 'OK', () => state.dismissPusakaNote())]) {
      final w = _textWidth(label, fs) + 14 * ts, btn = Rect.fromLTWH(x - w, r.top, w, h), enabled = key == 'ok' || g.whyNotUndoDefault == null;
      final sink = _btnFrame(c, btn, enabled ? (key == 'ok' ? Board._btnGreen : Board._btnLight) : Board._btnWhite, _look(btn, enabled: enabled), k);
      _text(c, label, btn.center + Offset(0, sink - k), size: fs, anchor: Anchor.center,
          color: enabled ? const Color(0xFF3B2210) : const Color(0xFF8E8A86));
      _assign
        ..note[key] = btn
        ..taps.add((btn, fn));
      x = btn.left - 4 * ts;
    }
    _text(c, _fitFirst([pusakaNoteStrip, 'Suggested ${Words.artifact}s', 'Suggested'], fs, x - 2 * ts - r.left), Offset(r.left, r.center.dy), size: fs, color: ink);
  }

  /// The note's Undo: the suggested Pusaka back to the Gudang ([Pusaka.undoDefaultBinding]); refused (mid-wave), why.
  void _undoPusakaSuggestion() {
    final g = state;
    if (g.whyNotUndoDefault case final why?) return showMessage(why);
    if (g.undoDefaultBinding()) showMessage('Suggestion undone: ${Words.artifact}s to ${Words.vault}');
  }

  /// A tap on troop [type]'s row with Pusaka [relic] picked ([Pusaka.pusakaPreview]): binds it there, moves it there
  /// (for its price) or, on the type it is on, takes it back to the Gudang; and says so ("Dragon Heart now on Templar").
  /// Refused: why. The pick stays, so the rows show where it went.
  void _usePusaka(Relic relic, String type) {
    final g = state, p = g.pusakaPreview(relic, type), name = relicNames[relic]!, to = troopTypeNames[type]!;
    if (p.why != null) return showMessage(p.why!);
    if (p.action == PusakaAction.sumpah) return showMessage(g.pusakaWhere(relic)); // an oath binds nowhere
    final done = p.action == PusakaAction.lepas ? g.unbindPusaka(relic) : g.bindPusaka(relic, type);
    if (!done) return;
    showMessage(switch (p.action) {
      PusakaAction.lepas => '$name to ${Words.vault}',
      PusakaAction.pasang => '$name now on $to',
      PusakaAction.pindah => '$name moved to $to -${shortPrice(p.price)}',
      PusakaAction.sumpah => g.pusakaWhere(relic),
    });
  }

  /// Artifact [relic]'s Sharpen row ([BagAction.sharpen]; Asah, P6, decisions-log 154 and 202): its tag "Sharpen ★n" (the
  /// star it gives) in two taps like the Vault's Sell (the first arms it, "Sure?" in red); its line what it costs, the coin
  /// and the price, then the small relics it takes from the bag ([_asahCost]), the price in red while the gold is short
  /// and "relics 7/10" in red while the bag holds too few. While it can't for another reason (mid-wave, already this boss
  /// interval, a Legendary, ★3) the tag is greyed and the line says why in red ("Sharpened: again after wave 90"). A
  /// greyed tag's tap says why.
  void _sharpenRow(Canvas c, Game g, Relic relic, Rect r, _ActLook m) {
    final a = _assign, why = g.whyNotAsah(relic), price = g.asahPriceOf(relic), end = r.right - m.inset;
    if (why != null) a.asahArmed = null; // a wave began, or the gold went: the first tap again
    final armed = a.asahArmed == relic;
    final label = armed ? Words.sure : (price == null ? Words.sharpen : '${Words.sharpen} $_starGlyph${(g.pusaka[relic]?.stars ?? 0) + 1}');
    final (:x, :y1, :y2) = _actCard(c, BagAction.sharpen, r, m, why == null, (box, paint) => _uiIcon(c, _icStar, box, paint));
    final tag = _rowTag(c, r, end, y1, label, m.lineFs, why != null ? _TagLook.off : (armed ? _TagLook.armed : _TagLook.go), () => _asahTap(relic));
    _actTitle(c, BagAction.sharpen, Words.sharpen, x, y1, tag.cap.left - 6 * m.ts, m, why == null);
    _asahCost(c, g, relic, Offset(x, y2), end - x, m.lineFs, m.ts);
    a
      ..asah = tag.hit
      ..detail['sharpen'] = r
      ..texts['sharpen'] = label
      ..texts['hint:${BagAction.sharpen.name}'] = a.texts['sharpenCost'] ?? '';
  }

  /// Sharpen's line for [relic] at [at] (its left end, mid-height) in [room] px: why it can't in red, the longest of its
  /// forms that fits; else what it costs, the coin and the price (red while the gold is short), then each small relic it
  /// takes from the bag ([Asah.asahTake]) as its icon and how many, or "+ relics 7/10" in red while the bag holds too
  /// few; where the icons don't fit, "+ 10 relics". Returns its width, null when it doesn't fit (with [whole] the icons'
  /// form only; drawn, the last form cut). [draw] false only measures. Sets `sharpenCost`: its rect and its words.
  double? _asahCost(Canvas c, Game g, Relic relic, Offset at, double room, double fs, double ts, {bool whole = false, bool draw = true}) {
    const ink = Color(0xFF4A2C17);
    final why = g.whyNotAsah(relic), price = g.asahPriceOf(relic);
    void said(double w, String words) {
      if (draw) {
        _assign
          ..detail['sharpenCost'] = Rect.fromLTWH(at.dx, at.dy - fs * 0.7, w, fs * 1.4)
          ..texts['sharpenCost'] = words;
      }
    }

    if (price == null || (why != null && why != asahRefusals.gold && why != asahRefusals.relics)) {
      // Already this boss interval: when the next comes, in as many words as fit.
      final n = g.asahAgainAt;
      final words = why == asahRefusals.once
          ? ['$why: again after wave $n', 'Sharpened: again after wave $n', 'Again after wave $n', 'Again after w$n']
          : (why == asahRefusals.legend ? [why!, 'Not for a ${Words.legendary}'] : [why ?? '']);
      final fit = words.where((t) => _textWidth(t, fs) <= room).firstOrNull, t = fit ?? _fit(words.last, fs, room);
      if (draw) _text(c, t, at, size: fs, color: _blockedInk);
      said(_textWidth(t, fs), t);
      return fit == null ? null : _textWidth(t, fs);
    }
    final coin = fs * 1.1, icon = fs * 1.3, sp = 4 * ts, cost = shortPrice(price), take = g.asahTake;
    final relicsShort = g.asahRelicsInBag < asahRelics, head = coin + 2 * ts + _textWidth(cost, fs);
    final few = relicsShort ? ' + relics ${g.asahRelicsInBag}/$asahRelics' : ' + ${take.values.fold(0, (n, v) => n + v)} relics';
    final icons = relicsShort ? null : head + take.values.fold(0.0, (w, n) => w + sp + icon + ts + _textWidth('$n', fs));
    final w = icons != null && icons <= room ? icons : (!whole || relicsShort) && head + _textWidth(few, fs) <= room ? head + _textWidth(few, fs) : null;
    if (!draw) return w;
    _uiIcon(c, Board._icCoin, Rect.fromLTWH(at.dx, at.dy - coin / 2, coin, coin));
    var x = at.dx + coin + 2 * ts;
    _text(c, cost, Offset(x, at.dy), size: fs, color: g.gold < price ? _blockedInk : ink);
    x += _textWidth(cost, fs);
    if (icons != null && w == icons) {
      for (final MapEntry(key: kind, value: n) in take.entries) {
        _icon(c, kind, Rect.fromLTWH(x + sp, at.dy - icon / 2, icon, icon));
        x += sp + icon + ts;
        _text(c, '$n', Offset(x, at.dy), size: fs, color: ink);
        x += _textWidth('$n', fs);
      }
      said(x - at.dx, '$cost ${asahTakeLine(take)}');
    } else {
      final t = w == null ? _fit(few, fs, at.dx + room - x) : few;
      _text(c, t, Offset(x, at.dy), size: fs, color: relicsShort ? _blockedInk : ink);
      said(x + _textWidth(t, fs) - at.dx, '$cost$t');
    }
    return w;
  }

  /// A tap on Pusaka [relic]'s Sharpen: the first arms it, the second raises it a star ([Asah.asah]) and says so, with
  /// what it took ("Dragon Heart ★2! -60k, Thorns 8, Fury 2"). Refused: the error and why.
  void _asahTap(Relic relic) {
    final g = state, a = _assign..carveArmed = null; // one thing at a time
    if (g.whyNotAsah(relic) case final why?) {
      a.asahArmed = null;
      g.asah(relic); // the error
      return showMessage(why);
    }
    if (a.asahArmed != relic) {
      a.asahArmed = relic;
      return;
    }
    a.asahArmed = null;
    final cost = g.asahPriceOf(relic)!, taken = g.asahTake;
    if (g.asah(relic)) showMessage('${relicNames[relic]} $_starGlyph${g.pusaka[relic]!.stars}! -${shortPrice(cost)}, ${asahTakeLine(taken)}');
  }

  // Lebur (Melt; J3, decisions-log 164; the rules: pusaka.dart's [Lebur]): a Pusaka in the Gudang melted into another
  // owned one, which gains a star. Its facing page has the row ([BagAction.melt]); the facing page becomes the picker.

  /// A tap on the Gudang's Melt for [relic]: opens its target picker on the facing page ([_leburPage]), or closes it.
  /// Refused (mid-wave, a Legenda, no Pusaka that could take a star: [Lebur.whyNotLebur]): the error and why.
  void _leburTap(Relic relic) {
    final g = state, a = _assign;
    a
      ..leburArmed = null
      ..scroll = 0;
    if (g.whyNotLebur(relic) case final why?) {
      a.lebur = null;
      g.sfx.add(Sfx.error);
      return showMessage(why);
    }
    a.lebur = a.lebur == relic ? null : relic;
  }

  /// The facing page while [fodder]'s Melt picker is open ([_AssignList.lebur], its chooser [BagAction.melt]), in [area]
  /// under its heading: the chooser's head ([_chooserHead]: "‹ Back", which closes it, and "Melt Grail ★1 into:"), then a
  /// row for every Artifact it could go into ([Lebur.leburTargets]: [_leburRow]), scrolled like the type rows.
  void _leburPage(Canvas c, Game g, Relic fodder, Rect area, double ts) {
    final a = _assign, name = relicNames[fodder]!, stars = '$_starGlyph${g.pusaka[fodder]?.stars ?? 1}';
    final top = _chooserHead(c, area, ['${Words.melt} $name $stars into:', '${Words.melt} $name into:', '${Words.melt} into:'], ts);
    a.leburBack = a.back;
    final list = Rect.fromLTRB(area.left, top, area.right, area.bottom);
    a.list = list;
    final targets = g.leburTargets(fodder);
    final (look, rowH) = _rowMeasures(list, ts);
    final rowGap = math.max(3.0, 4 * ts), barW = _capsuleBarW;
    final content = targets.length * (rowH + rowGap) - rowGap, scrolls = content > list.height;
    a.scroll = a.scroll.clamp(0.0, math.max(0.0, content - list.height));
    c.save();
    c.clipRect(list);
    for (final (i, target) in targets.indexed) {
      final r = Rect.fromLTWH(list.left, list.top + i * (rowH + rowGap) - a.scroll, list.width - (scrolls ? barW + 2 * ts : 0), rowH);
      if (r.bottom <= list.top || r.top >= list.bottom) continue;
      final ok = g.whyNotLebur(fodder, target) == null;
      if (a.leburArmed == target && ok) {
        _card(c, r, Board._frameLit);
      } else if (a.dragY != null) {
        _card(c, r, Board._framePlain); // scrolling: no row lights or sinks
      } else {
        _rowCard(c, r, Board._framePlain, enabled: ok);
      }
      _leburRow(c, g, fodder, target, r, look);
      a.rows.add((r.intersect(list), target, ok, () => _leburRowTap(fodder, target)));
    }
    c.restore();
    if (scrolls) _capsuleBar(c, list, content, a.scroll);
  }

  /// [target]'s row in the Melt picker for [fodder], in [r]: its icon (ghosted when it can't take it); its name, and what
  /// a tap does, "Melt" with the coin and the price ([Lebur.leburPriceOf], red while the gold is short; armed "Sure?" in
  /// red); its stars now ▸ after ("★1 ▸ ★2") and where it is ("Templar (13)", "Vault"); and on the last line what it
  /// does at the new star ([pusakaGist]), armed what is lost ("Tap again: Grail ★1 is gone"; a carved one's "Tap again:
  /// the higher Carve is kept"), or why it can't, in red (a Legenda, "Already ★3"). Wide: the action right of the name;
  /// narrow (4 lines): on its own line.
  void _leburRow(Canvas c, Game g, Relic fodder, Relic target, Rect r, _RowLook look) {
    const ink = Color(0xFF4A2C17), grey = Color(0xFF9E9080);
    final (:inset, :nameFs, :lineFs, :narrow, :ts) = look;
    final why = g.whyNotLebur(fodder, target), ok = why == null, short = why == leburRefusals.gold, armed = ok && _assign.leburArmed == target;
    final p = g.pusaka[target]!, price = g.leburPriceOf(target);
    final side = math.min(r.height - 2 * inset, r.width * 0.25), box = Rect.fromLTWH(r.left + inset, r.center.dy - side / 2, side, side);
    _icon(c, target, box.deflate(side * 0.12), ok || short ? _px : _ghost);
    final x = box.right + 4 * ts, end = r.right - inset - 2 * ts, lines = _rowLines(r, look);

    // What a tap does: its word, then the coin and the price.
    final word = armed ? Words.sure : Words.melt, coin = lineFs * 1.1, cost = price == null ? '' : shortPrice(price);
    final actionW = _textWidth(word, lineFs) + (price == null ? 0 : 4 * ts + coin + 2 * ts + _textWidth(cost, lineFs));
    void action(Offset at) {
      _text(c, word, at, size: lineFs, color: armed ? _blockedInk : (ok || short ? ink : grey));
      if (price == null) return;
      final cx = at.dx + _textWidth(word, lineFs) + 4 * ts;
      _uiIcon(c, Board._icCoin, Rect.fromLTWH(cx, at.dy - coin / 2, coin, coin), ok || short ? _px : _ghost);
      _text(c, cost, Offset(cx + coin + 2 * ts, at.dy), size: lineFs, color: short ? _blockedInk : (ok ? ink : grey));
    }

    _text(c, _fit(relicNames[target]!, nameFs, (narrow ? end : end - actionW - 6 * ts) - x), Offset(x, lines[0]), size: nameFs,
        color: ok || short ? ink : grey);
    if (narrow) {
      action(Offset(x, lines[2]));
    } else {
      action(Offset(end - actionW, lines[0]));
    }

    // The stars now ▸ after, then where it is.
    final now = '$_starGlyph${p.stars}', at = Offset(x, lines[1]);
    final starsW = price == null
        ? _textWidth(now, lineFs)
        : _change(c, now, '$_starGlyph${math.min(starMax, p.stars + leburStars)}', at, lineFs, to: ok || short ? _previewInk : grey);
    if (price == null) _text(c, now, at, size: lineFs, color: grey);
    final type = p.type, alive = type == null ? 0 : g.troops.where((u) => u.alive && u.type == type).length;
    final where = type == null ? Words.vault : '${troopTypeNames[type] ?? type} ($alive)', wx = x + starsW + 6 * ts;
    _text(c, _fit(where, lineFs, end - wx), Offset(wx, at.dy), size: lineFs, color: ok || short ? ink : grey);

    // The last line: why not, what an armed one loses, or what it does at the new star.
    final last = Offset(x, lines.last), fodderName = relicNames[fodder]!, lost = '$_starGlyph${g.pusaka[fodder]?.stars ?? 1}';
    if (why case final why? when !short) {
      _text(c, _fit(why, lineFs, end - x), last, size: lineFs, color: _blockedInk);
    } else if (armed) {
      // A carved one melted in: its Carve goes too, unless the higher (decisions-log 196).
      final carved = (g.pusaka[fodder]?.ukir ?? 0) > 0;
      final said = [
        if (carved) ...['Tap again: the higher ${Words.carve} is kept', 'The higher ${Words.carve} is kept', 'Higher ${Words.carve} kept'],
        'Tap again: $fodderName $lost is gone', '$fodderName $lost is gone', 'Tap again',
      ];
      final shown = _fitFirst(said, lineFs, end - x);
      _text(c, shown, last, size: lineFs, color: _blockedInk);
      _assign.texts['meltArmed'] = shown;
    } else {
      final gist = pusakaGist(target, math.min(starMax, p.stars + leburStars), ukir: g.leburUkir(fodder, target));
      _text(c, _fit(gist, lineFs, end - x), last, size: lineFs, color: ok ? ink : grey);
    }
  }

  /// A tap on [target]'s row in [fodder]'s Melt picker: the first arms it, the second melts [fodder] into it
  /// ([Lebur.lebur]) and says so ("Dragon Heart ★2! -60k, Grail melted"); the picker closes and the pick moves to
  /// [target], so its page shows the new star. Refused: the error and why.
  void _leburRowTap(Relic fodder, Relic target) {
    final g = state, a = _assign;
    if (g.whyNotLebur(fodder, target) case final why?) {
      a.leburArmed = null;
      g.lebur(fodder, target); // the error
      return showMessage(why);
    }
    if (a.leburArmed != target) {
      a.leburArmed = target;
      return;
    }
    final cost = g.leburPriceOf(target)!;
    a
      ..lebur = null
      ..leburArmed = null
      ..scroll = 0;
    if (!g.lebur(fodder, target)) return;
    _picked = target;
    showMessage('${relicNames[target]} $_starGlyph${g.pusaka[target]!.stars}! -${shortPrice(cost)}, ${relicNames[fodder]} melted');
  }

  /// Pusaka [relic]'s badge with its right middle at [at], its text [fs]: its icon and "★n" in the book's capsule
  /// ([_capsule], decisions-log 187), its Carve steps after them in gold ("★2+3", decisions-log 196), faded while it
  /// sleeps ([Pusaka.pusakaAsleep]: none of its type lives). Returns where it is; with [draw] false it only measures.
  Rect _pusakaCapsule(Canvas c, Game g, Relic relic, Offset at, double fs, {bool draw = true}) => _capsule(
      c, '$_starGlyph${g.pusaka[relic]?.stars ?? 1}', fs, at,
      anchor: Anchor.centerRight, icon: relic, faded: g.pusakaAsleep(relic), draw: draw, tail: ukirMark(g.pusaka[relic]?.ukir ?? 0));

  /// The facing page for [loot] (decisions-log 187 and 202; ui-hud.md "Tas"), top to bottom: the heading
  /// ([_detailHeading]); what it is ([_detailLines]: where an Artifact is, what it does, in a line or two); with the
  /// Wishlist an item's or a small relic's free line ([_freeLine], decisions-log 303; not on the Shop's page); then what
  /// the player can do with it, a row each ([_actionList]). A row's chooser ([BagAction.chooses]) takes the page under the
  /// heading ([_chooser]) with a Back: the filter's chips where it lists troops or types, then the rows of who can take
  /// it ([_chooserList]); a Vault Artifact's Melt picker likewise ([_leburPage]). An item or a small relic dragged out of
  /// the bag shows its chooser while the drag lasts. [target]: the type an item dragged onto the field would go to. With
  /// no [pick], nothing: the book's blank paper (decisions-log 241). An enhanced stack's page (decisions-log 255) is its
  /// item's at its plus: its heading's "+3", what one does at it, and the types it goes to.
  void _assignPage(Canvas c, Game g, BagLoot? pick, Rect right, double ts, double ps, String? target) {
    final a = _assign;
    if (a.shownFor != pick) {
      a
        ..shownFor = pick
        ..scroll = 0;
      if (a.openFor != pick) a.open = null; // another pick: its own action list (a shortcut opens the new one's)
    }
    final area = right;
    a.detail['page'] = right;
    if (pick == null) return;
    final (kind: loot, :plus) = pick;
    final head = _detailHeading(c, g, loot, area, ts, ps, plus: plus), under = Rect.fromLTRB(area.left, head, area.right, area.bottom);
    final chooser = a.shown = _chooser(g, pick);
    if (chooser == null) {
      final gap = math.max(4.0, (6 * ts).roundToDouble());
      var top = _detailLines(c, g, loot, area, head, ts, ps, plus: plus) + gap;
      if (!_shopShown && plus == 0 && g.canWishFree(loot)) {
        // Its free line (decisions-log 303; the owner: "penambahan wishlist itu dilakukan di tempat lain misalkan di page
        // army,bags"): "-" ×n "+" and "Add to wishlist", then "Remove", as on its Smithy page.
        final h = math.max(20.0, (26 * ts).roundToDouble());
        _freeLine(c, g, loot, Rect.fromLTWH(area.left, top.roundToDouble(), area.width, h), math.max(10.0, 13 * ts), at: a.detail, texts: a.texts);
        top += h + gap;
      }
      return _actionList(c, g, pick, Rect.fromLTRB(area.left, top, area.right, area.bottom), ts, ps);
    }
    if (chooser == BagAction.melt) return _leburPage(c, g, loot as Relic, under, ts);
    final top = _chooserHead(c, under, [_actTitleOf(g, loot, chooser)], ts);
    _chooserList(c, g, loot, chooser, Rect.fromLTRB(area.left, top, area.right, area.bottom), ts, target, plus: plus);
  }

  /// The chooser [loot]'s page shows this frame (null: its action list): the one being dragged's ([BagAction.giveTroops]
  /// for an item, [BagAction.equip] for a small relic), a Vault Artifact's open Melt picker (closed once it can't: a wave
  /// began), or the one the player opened for it ([_openChooser]) while it is still one of its actions (Remove's closes
  /// with the last one worn taken off, a type chooser's when it goes from the Vault to a type and back stays).
  BagAction? _chooser(Game g, BagLoot pick) {
    final a = _assign, loot = pick.kind;
    if (_shopShown) return null; // the Shop's rows act on their tags
    if (loot == _itemDrag) return BagAction.giveTroops;
    if (loot == _relicDrag && loot is Relic && !loot.pusaka) return BagAction.equip;
    if (loot is Relic && a.lebur == loot) {
      if (g.whyNotLebur(loot) == null) return BagAction.melt;
      a.lebur = null; // a wave began: the picker closes
    }
    final open = a.openFor == pick && a.open != BagAction.melt ? a.open : null;
    if (open == null || _actionsFor(g, loot, pick.plus).contains(open)) return open;
    a.open = null;
    return null;
  }

  /// [act]'s chooser for [loot] (an enhanced stack's at +[plus], decisions-log 255) opens on its page, from the top; the
  /// tags armed for a second tap let go ([_bagLetGo]).
  void _openChooser(Enum loot, BagAction act, [int plus = 0]) {
    _bagLetGo();
    _assign
      ..open = act
      ..openFor = (kind: loot, plus: plus)
      ..scroll = 0;
  }

  /// The chooser's Back: the pick's action list again, from its top; an open Melt picker closes, its armed row with it.
  void _chooserBack() => _assign
    ..open = null
    ..lebur = null
    ..leburArmed = null
    ..scroll = 0;

  /// What the player can do with [loot], in its rows' order (decisions-log 202): an item gives to troops or to an
  /// Artifact (Carve's Give) and sells; a small relic goes on a troop, comes off the troops wearing it (while some do)
  /// and one in the Vault melts; an oath shows what it gives each type, its Sharpen and Carve greyed with why. The Bag
  /// sells nothing (decisions-log 230: the Town's Shop does); on the Shop's page, its own rows ([_shopActions]). An
  /// enhanced stack ([plus], decisions-log 255) gives to troops alone: Carve takes the +0 ones.
  List<BagAction> _actionsFor(Game g, Enum loot, [int plus = 0]) {
    if (_shopShown) return _shopActions(g, loot, plus);
    return switch (loot) {
      Item() when plus > 0 => const [BagAction.giveTroops],
      Item() => const [BagAction.giveTroops, BagAction.giveArtifact],
      Mat() => const [BagAction.smithy],
      final Relic r when !r.pusaka => [BagAction.equip, if (g.relicsHeld(r) > 0) BagAction.takeOff],
      Relic(oath: true) => const [BagAction.types, BagAction.sharpen, BagAction.carve],
      final Relic r when g.pusaka[r]?.type != null => const [BagAction.types, BagAction.toVault, BagAction.sharpen, BagAction.carve],
      _ => const [BagAction.types, BagAction.sharpen, BagAction.carve, BagAction.melt],
    };
  }

  /// [loot]'s rows on the Town's Shop's Buy page (decisions-log 230 and 269): Buy while the shelf sells it
  /// ([onShopShelf]; the forge's Shop no small relic, so no "Cheaper at the Smithy" row, decisions-log 248 and 296).
  /// Selling is the Sell tab's (shop_page.dart).
  List<BagAction> _shopActions(Game g, Enum loot, [int plus = 0]) => [if (plus == 0 && onShopShelf(g, loot)) BagAction.buy];

  /// The grey line under [loot]'s rows in the Bag (decisions-log 230): where what the Bag doesn't sell is sold, for an
  /// item, a small relic and a Vault Artifact (a material's own line says it, [matUseLine]); null for the rest and on the
  /// Shop's page.
  String? _bagNote(Game g, Enum loot) {
    if (_shopShown) return null;
    final sold = switch (loot) {
      Item() => true,
      final Relic r when !r.pusaka => true,
      final Relic r => !r.oath && g.pusaka[r]?.type == null,
      _ => false,
    };
    return sold ? Words.soldInTown : null;
  }

  /// [act]'s title for [loot], on its row and on its chooser's head.
  String _actTitleOf(Game g, Enum loot, BagAction act) => switch (act) {
        BagAction.giveTroops => '${Words.give} to troops',
        BagAction.giveArtifact => '${Words.give} to an ${Words.artifact}',
        BagAction.equip => '${Words.equip} on a troop',
        BagAction.takeOff => '${Words.remove} from a troop',
        BagAction.types when loot is Relic && loot.oath => 'Each type',
        BagAction.types => g.pusaka[loot]?.type == null ? '${Words.equip} on a type' : '${Words.move} to a type',
        BagAction.toVault => 'Take it off',
        BagAction.sharpen => Words.sharpen,
        BagAction.carve => Words.carve,
        BagAction.melt => Words.melt,
        BagAction.smithy => 'Craft at the ${Words.smithy}',
        BagAction.buy => Words.buy,
      };

  /// An action row's measures ([_ActLook]) at the page's text scale [ts] and pixel scale [ps].
  _ActLook _actLook(double ts, double ps) {
    final lineFs = math.max(10.0, 13 * ts), titleFs = math.max(11.0, 15 * ts), inset = math.max(3.0, 4 * ts);
    return (inset: inset, titleFs: titleFs, lineFs: lineFs, icon: bagHeadIcon(ps), h: (2 * inset + titleFs * 1.3 + lineFs * 1.5).roundToDouble(), ts: ts);
  }

  /// [loot]'s action list in [list] (decisions-log 202): a row per thing the player can do with it ([_actionsFor]), a few
  /// px apart, on whole pixels, scrolled by the wheel or a drag when they don't all fit; under them the grey line that
  /// says where it sells ([_bagNote], decisions-log 230). An enhanced stack's ([pick]'s plus) at it.
  void _actionList(Canvas c, Game g, BagLoot pick, Rect list, double ts, double ps) {
    const grey = Color(0xFF9E9080);
    final (kind: loot, :plus) = pick;
    final a = _assign, m = _actLook(ts, ps), gap = math.max(3.0, (4 * ts).roundToDouble()), acts = _actionsFor(g, loot, plus);
    a.list = list;
    final noteFs = m.lineFs, noteH = (noteFs * 1.4).roundToDouble(), note = _bagNote(g, loot);
    final notes = note == null ? const <String>[] : _wrap(note, noteFs, list.width - 2 * m.inset, 2);
    final rows = acts.length * (m.h + gap) - gap, content = rows + (notes.isEmpty ? 0 : gap + notes.length * noteH), scrolls = content > list.height;
    a.scroll = a.scroll.clamp(0.0, math.max(0.0, content - list.height));
    c.save();
    c.clipRect(list);
    for (final (i, act) in acts.indexed) {
      final r = Rect.fromLTWH(list.left, (list.top + i * (m.h + gap) - a.scroll).roundToDouble(), list.width - (scrolls ? _capsuleBarW + 2 * ts : 0), m.h);
      if (r.bottom <= list.top || r.top >= list.bottom) continue;
      switch (act) {
        case BagAction.sharpen:
          _sharpenRow(c, g, loot as Relic, r, m);
        case BagAction.carve:
          _carveRow(c, g, loot as Relic, r, m);
        case BagAction.toVault:
          _toVaultRow(c, g, loot as Relic, r, m);
        case BagAction.buy:
          _buyRow(c, g, loot, r, m);
        case BagAction.smithy:
          _smithyRow(c, g, loot as Mat, r, m);
        default:
          _chooserRow(c, g, loot, act, r, m, plus);
      }
    }
    if (notes.isNotEmpty) {
      final top = (list.top + rows + gap - a.scroll).roundToDouble();
      for (final (i, line) in notes.indexed) {
        _text(c, line, Offset(list.left + m.inset, top + (i + 0.5) * noteH), size: noteFs, color: grey);
      }
      a
        ..detail['note'] = Rect.fromLTWH(list.left + m.inset, top, list.width - 2 * m.inset, notes.length * noteH).intersect(list)
        ..texts['note'] = notes.join('\n');
    }
    c.restore();
    if (scrolls) _capsuleBar(c, list, content, a.scroll);
  }

  /// [act]'s row card in [r] and its icon ([icon] draws it in its box: 16 px on a phone, 32 on the desk; faded while it
  /// can't, not [ok]): the list rows' paper card ([Board._framePlain]), lit under the mouse and pushed in while pressed
  /// where the whole row is the tap ([lit]: a chooser's row). Kept for tests ([_AssignList.actions]). Returns where its
  /// words start and its two lines' middles.
  ({double x, double y1, double y2}) _actCard(Canvas c, BagAction act, Rect r, _ActLook m, bool ok, void Function(Rect box, Paint paint) icon,
      {bool lit = false}) {
    if (lit && _assign.dragY == null) {
      _rowCard(c, r, Board._framePlain, enabled: ok); // lit under the mouse, pushed in while pressed
    } else {
      _card(c, r, Board._framePlain);
    }
    final box = _whole(Rect.fromLTWH(r.left + m.inset + m.ts, r.center.dy - m.icon / 2, m.icon, m.icon));
    icon(box, ok ? _px : _ghost);
    _assign.actions.add((act, r.intersect(_assign.list), ok));
    final top = r.top + m.inset;
    return (x: box.right + 6 * m.ts, y1: top + m.titleFs * 0.65, y2: top + m.titleFs * 1.3 + m.lineFs * 0.75);
  }

  /// [act]'s title at ([x], [y]) up to [end], grey while it can't ([ok] false): cut to fit ([cut]: a chooser's row), else
  /// left out where it doesn't fit whole (its tags say it). For tests, `'title:<act>'`.
  void _actTitle(Canvas c, BagAction act, String title, double x, double y, double end, _ActLook m, bool ok, {bool cut = false}) {
    const ink = Color(0xFF4A2C17), grey = Color(0xFF9E9080);
    final shown = cut ? _fit(title, m.titleFs, end - x) : (_textWidth(title, m.titleFs) <= end - x ? title : '');
    if (shown.isNotEmpty) _text(c, shown, Offset(x, y), size: m.titleFs, color: ok ? ink : grey);
    _assign.texts['title:${act.name}'] = shown;
  }

  /// [act]'s second line from ([x], [y]) up to [end]: why it can't in red (the longest of its forms that fits,
  /// [_shortWhy]), else [hint] in the page's soft ink (or the first of its [shorter] forms that fits). For tests, `'hint:<act>'`.
  void _actLine(Canvas c, BagAction act, String? why, String hint, double x, double y, double end, _ActLook m,
      {List<String> shorter = const []}) {
    const soft = Color(0xFF8A6A4A);
    final shown = _fitFirst(why == null ? [hint, ...shorter] : [why, ...?_shortWhy[why]], m.lineFs, end - x);
    _text(c, shown, Offset(x, y), size: m.lineFs, color: why == null ? soft : _blockedInk);
    _assign.texts['hint:${act.name}'] = shown;
  }

  /// [act]'s row for [loot] where it opens a chooser (decisions-log 202): its icon, its title ([_actTitleOf]) and a line
  /// on what the chooser holds ("3 types can take it", [_chooserInfo]) or why it can't now in red, and on the right the
  /// green "›" (white and faded while it can't). A tap opens the chooser on the page ([_openChooser]; Melt's picker:
  /// [_leburTap]), or says why. An enhanced stack's at its [plus] (decisions-log 255).
  void _chooserRow(Canvas c, Game g, Enum loot, BagAction act, Rect r, _ActLook m, [int plus = 0]) {
    final (:why, hint: hints, :icon) = _chooserInfo(c, g, loot, act, plus);
    final a = _assign, ok = why == null;
    final (:x, :y1, :y2) = _actCard(c, act, r, m, ok, icon, lit: true);
    final k = math.max(1.0, (m.titleFs / 10).roundToDouble()), w = _icOpen.width * k, h = _icOpen.height * k;
    final open = _whole(Rect.fromLTWH(r.right - m.inset - m.ts - w, r.center.dy - h / 2, w, h));
    c.drawImageRect(_img('ui_icons.png'), ok ? _icOpen : _icThen, open, ok ? _px : _ghost);
    _actTitle(c, act, _actTitleOf(g, loot, act), x, y1, open.left - 6 * m.ts, m, ok, cut: true);
    _actLine(c, act, why, hints.first, x, y2, open.left - 6 * m.ts, m, shorter: hints.sublist(1));
    final at = r.intersect(a.list);
    a.rows.add((at, act, ok, () => act == BagAction.melt ? _leburTap(loot as Relic) : (why == null ? _openChooser(loot, act, plus) : showMessage(why))));
    if (act == BagAction.melt) a.leburBtn = at;
  }

  /// What [act]'s chooser row for [loot] says ([_chooserRow]): why it can't open now (null: it can), its line, and its
  /// icon, drawn in a box with a paint: the troops' crossed swords where it lists troops or types, the first Artifact an
  /// item would go into (the gift with none), the bag for Remove, the green plus for Melt. An item's enhanced stack's types
  /// at its [plus] (decisions-log 255).
  ({String? why, List<String> hint, void Function(Rect box, Paint paint) icon}) _chooserInfo(Canvas c, Game g, Enum loot, BagAction act,
      [int plus = 0]) {
    void troops(Rect box, Paint paint) => _uiIcon(c, Board._icSwords, box, paint);
    String count(int n, String one, String many) => n == 1 ? '1 $one' : '$n $many';
    final over = g.over ? assignRefusals.over : null;
    switch (act) {
      case BagAction.giveTroops:
        final n = troopTypes.keys.where((type) => g.assignPreview(loot, type, plus: plus).why == null).length;
        return (why: over, hint: [n == 0 ? 'No type can take it now' : count(n, 'type can take it', 'types can take it')], icon: troops);
      case BagAction.giveArtifact:
        final item = loot as Item, rows = _giveRows(g, item), n = rows.where((r) => g.whyNotUkir(r, only: item) == null).length;
        final why = over ??
            (!ukirMidWave && g.waveActive
                ? ukirRefusals.midWave
                : g.wave < ukirFrom
                    ? ukirRefusals.from
                    : rows.isEmpty
                        ? 'No ${Words.artifact} can take it'
                        : (n == 0 ? g.whyNotUkir(rows.first, only: item) : null));
        return (
          why: why,
          hint: ['${Words.carve}: ${count(n, 'can take it', 'can take it')}'],
          icon: rows.isEmpty ? (box, paint) => _uiIcon(c, _icGift, box, paint) : (box, paint) => _icon(c, rows.first, box, paint),
        );
      case BagAction.equip:
        final n = g.troops.where((u) => u.alive && g.assignPreview(loot, u).why == null).length;
        return (why: over, hint: [n == 0 ? 'No troop can wear it now' : count(n, 'troop can wear it', 'troops can wear it')], icon: troops);
      case BagAction.takeOff:
        final why = over ?? g.troops.where((u) => u.alive && u.holds(loot as Relic)).map((u) => g.whyNotTakeOff(loot as Relic, u)).firstOrNull;
        return (why: why, hint: [count(g.relicsHeld(loot as Relic), 'troop wears it', 'troops wear it')], icon: (box, paint) => _uiIcon(c, Board._icBag, box, paint));
      case BagAction.types:
        final relic = loot as Relic, price = g.bindPrice(relic), bound = g.pusaka[relic]?.type != null;
        if (relic.oath) return (why: null, hint: ['What it gives each type', 'What each type gets'], icon: troops);
        final why = over ?? (!bindMidWave && g.waveActive ? pusakaRefusals.midWave : null);
        final cost = price == 0 ? 'Free' : 'Costs ${shortPrice(price)}';
        return (why: why, hint: [if (!bound) '$cost: a whole type gets it', cost], icon: troops);
      default:
        return (
          why: g.whyNotLebur(loot as Relic),
          hint: ['Into another ${Words.artifact}: +$leburStars star', 'Into another: +$leburStars star', '+$leburStars star'],
          icon: (box, paint) => _uiIcon(c, _icMelt, box, paint),
        );
    }
  }

  /// A bound Artifact's To Vault row ([BagAction.toVault]): its tag "To Vault" takes it off its type into the Vault, free,
  /// at once ([_usePusaka] on its own type, as that type's row in its chooser does); its line which type loses it, or
  /// why it can't now in red. A greyed tag's tap says why.
  void _toVaultRow(Canvas c, Game g, Relic relic, Rect r, _ActLook m) {
    final type = g.pusaka[relic]!.type!, why = g.whyNotUnbind(relic), end = r.right - m.inset;
    final (:x, :y1, :y2) = _actCard(c, BagAction.toVault, r, m, why == null, (box, paint) => _uiIcon(c, Board._icBag, box, paint));
    final tag = _rowTag(c, r, end, y1, Words.toVault, m.lineFs, why == null ? _TagLook.go : _TagLook.off, () => _usePusaka(relic, type));
    _actTitle(c, BagAction.toVault, _actTitleOf(g, relic, BagAction.toVault), x, y1, tag.cap.left - 6 * m.ts, m, why == null);
    _actLine(c, BagAction.toVault, why, '${troopTypeNames[type] ?? type} loses it, free', x, y2, end, m);
    _assign.detail['toVault'] = tag.hit;
  }

  /// A material's Smithy row ([BagAction.smithy], decisions-log 221): the Town's hammer, "Craft at the Smithy" and the
  /// relics whose recipe takes it ("Fang, Thorns, Guard"), and outside a Town "Only in a Town" after them; a tap there
  /// says so. In a Town (decisions-log 235) the whole row is a tap (lit under the mouse, the green "›" on the right) that
  /// turns the book to the Smithy with the first of those relics picked ([_openSmithy]).
  void _smithyRow(Canvas c, Game g, Mat mat, Rect r, _ActLook m) {
    final away = !g.inTown, keys = g.townRules.recipesWith(mat);
    final names = [for (final k in keys) townRelicName(k)], relics = names.isEmpty ? 'No recipe takes it' : names.join(', ');
    final (:x, :y1, :y2) = _actCard(c, BagAction.smithy, r, m, true, (box, paint) => _townMark(c, box), lit: !away);
    var end = r.right - m.inset;
    if (!away) {
      final k = math.max(1.0, (m.titleFs / 10).roundToDouble()), w = _icOpen.width * k, h = _icOpen.height * k;
      final open = _whole(Rect.fromLTWH(r.right - m.inset - m.ts - w, r.center.dy - h / 2, w, h));
      c.drawImageRect(_img('ui_icons.png'), _icOpen, open, _px);
      end = open.left - 6 * m.ts;
    }
    _actTitle(c, BagAction.smithy, _actTitleOf(g, mat, BagAction.smithy), x, y1, end, m, true, cut: true);
    _actLine(c, BagAction.smithy, null, away ? '$relics. ${Words.onlyInTown}' : relics, x, y2, end, m,
        shorter: [if (away) Words.onlyInTown, relics]);
    final at = r.intersect(_assign.list);
    if (away) return _assign.taps.add((at, () => showMessage(Words.onlyInTown)));
    final first = keys.map((k) => Relic.values.asNameMap()[k]).nonNulls.firstOrNull;
    _assign.rows.add((at, BagAction.smithy, true, () => _openSmithy(first)));
  }

  /// A light tag ([_tag], [_TagLook]; decisions-log 198 and 202: a row's buttons are light, never ui_buttons' bevels) on
  /// Bag action row [r]: [label] at [fs] on its capsule, its right at [end], centred on the title's line [y]. Its tap
  /// ([fn], on tap UP: [_AssignList.taps]) is the capsule 3 px wider to its left, from the row's top as far under [y],
  /// kept to the list. Returns the capsule and the tap.
  ({Rect cap, Rect hit}) _rowTag(Canvas c, Rect r, double end, double y, String label, double fs, _TagLook look, VoidCallback fn) {
    final btn = Rect.fromLTRB(r.left, r.top, end, 2 * y - r.top);
    final hit = _tag(c, btn, fn, label, fs, look: look, into: []).intersect(_assign.list);
    if (!hit.isEmpty) _assign.taps.add((hit, fn));
    return (cap: _tagAt(btn, label, fs).capsule, hit: hit);
  }

  /// A chooser's head at [area]'s top (decisions-log 202): "‹ Back" on the left, a link tag ([_TagLook.link]) that closes
  /// it ([_chooserBack]; [_AssignList.back]), and beside it what it chooses for, the first of [titles] that fits. Returns
  /// where what it chooses from starts.
  double _chooserHead(Canvas c, Rect area, List<String> titles, double ts) {
    const ink = Color(0xFF4A2C17);
    final fs = math.max(10.0, 13 * ts), h = math.max(20.0, (26 * ts).roundToDouble()), band = Rect.fromLTWH(area.left, area.top, area.width, h);
    final w = capsuleSize(_textWidth(Words.back, fs) + _icBackSmall.width + capsuleGap(fs), fs).width;
    final btn = Rect.fromLTWH(area.left, band.top, w + 3, band.height); // its tap from the page's left
    _assign.back = _tag(c, btn, _chooserBack, Words.back, fs, look: _TagLook.link, into: _assign.taps, icon: _icBackSmall);
    final cap = _tagAt(btn, Words.back, fs, icon: _icBackSmall).capsule;
    final titleFs = math.max(11.0, 15 * ts), x = cap.right + 6 * ts, shown = _fitFirst(titles, titleFs, area.right - x);
    _text(c, shown, Offset(x, band.center.dy), size: titleFs, color: ink, bold: true);
    _assign.texts['chooser'] = shown;
    return band.bottom + 2 * math.max(2.0, 3 * ts);
  }

  /// The filter's chips in [area]'s top for [loot]'s chooser: All, then a chip per type with
  /// its sprite, faded for a relic while none of it lives; in one row where they fit, else two of five. Each a light icon
  /// tag ([_filterTag]; decisions-log 198's "Bag chips"), lit while on. A tap turns one on or off ([_filterTap]).
  /// Returns their bottom.
  double _filterChips(Canvas c, Game g, Enum loot, Rect area, double ts) {
    final a = _assign, types = troopTypes.keys.toList(), alive = g.troopCounts;
    final chipH = math.max(20.0, 24 * ts).roundToDouble(), gap = math.max(2.0, 3 * ts), w = area.width, top = area.top;
    final every = bagCategoryNames[BagCategory.all]!, chipFs = math.max(10.0, 13 * ts), allW = _textWidth(every, chipFs) + 14 * ts;
    final oneW = (w - allW - gap * types.length) / types.length, cells = <(String?, Rect)>[];
    if (oneW >= chipH * 0.9) {
      cells.add((null, Rect.fromLTWH(area.left, top, allW, chipH)));
      for (final (i, type) in types.indexed) {
        cells.add((type, Rect.fromLTWH(area.left + allW + gap + i * (oneW + gap), top, oneW, chipH)));
      }
    } else {
      final cw = (w - gap * 4) / 5;
      for (final (i, type) in [null, ...types].indexed) {
        cells.add((type, Rect.fromLTWH(area.left + (i % 5) * (cw + gap), top + (i ~/ 5) * (chipH + gap), cw, chipH)));
      }
    }
    for (final (type, r) in cells) {
      a.chips[type] = r;
      final on = type == null ? a.filter.isEmpty : a.filter.contains(type), tag = _filterTag(c, r, on);
      _hits.add((r, () => _filterTap(type)));
      if (type == null) {
        final size = math.min(chipFs, chipFs * (r.width - 6 * ts) / _textWidth(every, chipFs, bold: true));
        _text(c, every, tag.center, size: size, color: const Color(0xFF4A2C17), anchor: Anchor.center, bold: on);
        continue;
      }
      // The type's sprite on the tag, sinking with it; faded for a relic when none of it is alive.
      final box = tag.deflate(math.max(3.0, tag.height * 0.14)), b = _idleBounds[type]!, s = math.min(box.width / b.width, box.height / b.height);
      c.save();
      c.translate(box.center.dx, box.bottom);
      c.scale(s);
      _frame(c, 'book_${type}_idle', 0, Offset.zero, anchor: Offset(b.center.dx, b.bottom),
          paint: loot is! Item && (alive[type] ?? 0) == 0 ? _ghost : _px, line: _awakeLine(g.awakenLevel(type)));
      c.restore();
    }
    return cells.last.$2.bottom;
  }

  /// A filter chip's tag over [r] (decisions-log 198's "Bag chips": a light control, not ui_buttons' bevels), the Bag
  /// slot's paper card ([Board._framePlain]) at the right page's cards' scale ([_card]); while [on] lit as a picked slot
  /// (the lit card in the pick's cream and orange, [_bagPickPaint]), as the category strip's segment; under the mouse
  /// the lit card; a sprite px lower while pressed. Returns where its face is, for what sits on it.
  Rect _filterTag(Canvas c, Rect r, bool on) {
    final cell = _whole(r), k = math.max(1.0, (cell.shortestSide / 24).floorToDouble()), look = _look(r);
    final at = look == ButtonLook.pressed ? cell.translate(0, k) : cell;
    _bagSlot(c, at, k, frame: on || look == ButtonLook.hover || look == ButtonLook.pressed ? Board._frameLit : Board._framePlain, paint: on ? _bagPickPaint : null);
    return at;
  }

  /// What [act]'s chooser for [loot] chooses from, in [area] (decisions-log 202): the filter's chips where it lists troops or types ([_filterChips]), then its rows, scrolled by the wheel or a
  /// drag: [BagAction.giveTroops] a row per type shown ([_itemRow]; a type the item is never for after the others,
  /// greyed); [BagAction.giveArtifact] a Give row per Artifact that takes Carve ([_giveRows], [_giveRow]);
  /// [BagAction.equip] a row per living troop shown ([_relicRow]); [BagAction.takeOff] a row per troop wearing it, its
  /// Remove on the last line ([_takeOffLine]); [BagAction.types] a row per type shown ([_pusakaRow]). Three lines each, four on a narrow (phone) page. A row that can take it is a tap; one that
  /// can't is greyed with why, and a tap says so. Under the pointer on the field: the type an item goes to ([target]), the
  /// troop a relic dragged or in hand goes to (drop_popup.dart), lit (red when it can't). An item's enhanced stack gives
  /// at its [plus] (decisions-log 255).
  void _chooserList(Canvas c, Game g, Enum loot, BagAction act, Rect area, double ts, String? target, {int plus = 0}) {
    final a = _assign, types = troopTypes.keys.toList(), gap = math.max(2.0, 3 * ts);
    final chips = act == BagAction.giveTroops || act == BagAction.equip || act == BagAction.types;
    final list = Rect.fromLTRB(area.left, chips ? _filterChips(c, g, loot, area, ts) + 2 * gap : area.top, area.right, area.bottom);
    a.list = list;
    bool shown(String type) => a.filter.isEmpty || a.filter.contains(type);
    final byType = [...g.troops]..sort((x, y) => x.type == y.type ? x.id.compareTo(y.id) : types.indexOf(x.type).compareTo(types.indexOf(y.type)));
    final whose = <Object>[
      ...switch (act) {
        BagAction.giveTroops => [
            for (final never in [false, true])
              for (final type in types)
                if (shown(type) && (g.whyNot(loot as Item, type) == Refusal.notInRecipe) == never) type,
          ],
        BagAction.equip => [for (final u in byType) if (u.alive && shown(u.type)) u],
        BagAction.takeOff => [for (final u in byType) if (u.alive && u.holds(loot as Relic)) u],
        BagAction.types => [for (final type in types) if (shown(type)) type],
        BagAction.giveArtifact => _giveRows(g, loot as Item),
        _ => const <Object>[],
      },
    ];
    if (a.armed case (final u, final r) when !u.alive || !u.holds(r)) a.armed = null; // it came off, or its troop fell
    final (look, rowH) = _rowMeasures(list, ts);
    final rowGap = math.max(3.0, 4 * ts), content = whose.length * (rowH + rowGap) - rowGap, scrolls = content > list.height;
    a.scroll = a.scroll.clamp(0.0, math.max(0.0, content - list.height));
    if (whose.isEmpty) return _detailEmpty(c, list, ts);
    final Object? over = loot is Item ? target : (loot == _held ? _heldOver : null);
    final alive = g.troopCounts, pusaka = loot is Relic && loot.pusaka;
    c.save();
    c.clipRect(list);
    for (final (i, who) in whose.indexed) {
      final r = Rect.fromLTWH(list.left, list.top + i * (rowH + rowGap) - a.scroll, list.width - (scrolls ? _capsuleBarW + 2 * ts : 0), rowH);
      if (r.bottom <= list.top || r.top >= list.bottom) continue;
      // What a tap does: a Remove, a Give into an Artifact, a Pusaka's preview on the type (pusaka.dart), else the gift's
      // ([Game.assignPreview]).
      final remove = act == BagAction.takeOff ? loot as Relic : null, give = who is Relic ? who : null;
      final pp = pusaka ? g.pusakaPreview(loot, who as String) : null;
      final p = pusaka || remove != null || give != null ? null : g.assignPreview(loot, who, plus: plus);
      final why = remove != null
          ? g.whyNotTakeOff(remove, who as Unit)
          : give != null
              ? g.whyNotUkir(give, only: loot as Item)
              : pp == null
                  ? p!.why
                  : pp.why;
      final ok = why == null;
      if (who == over && ok) {
        _card(c, r, Board._frameLit);
      } else if (a.dragY != null) {
        _card(c, r, Board._framePlain); // scrolling: no row lights or sinks
      } else {
        _rowCard(c, r, Board._framePlain, enabled: ok); // lit under the mouse, pushed in while pressed
      }
      if (who == over && !ok) _refuse(c, r, ts);
      if (give != null) {
        _giveRow(c, g, loot as Item, give, r, look);
      } else if (pp != null) {
        _pusakaRow(c, g, loot as Relic, who as String, pp, r, look);
      } else if (who case final Unit u) {
        _relicRow(c, g, u, p, r, look, remove: remove);
      } else {
        _itemRow(c, g, loot as Item, who as String, alive[who] ?? 0, p!, r, look);
      }
      a.rows.add((
        r.intersect(list),
        who,
        ok,
        () {
          if (remove != null) {
            _takeOff(remove, who as Unit); // refused: why
          } else if (give != null) {
            _giveTap(loot as Item, give);
          } else if (!ok) {
            showMessage(why);
          } else if (pusaka) {
            _usePusaka(loot, who as String);
          } else if (who case final Unit u) {
            _useRelic(loot as Relic, u);
          } else {
            _useItem(loot as Item, who as String, plus: plus);
          }
        }
      ));
    }
    c.restore();
    if (scrolls) _capsuleBar(c, list, content, a.scroll);
  }

  /// The facing page's heading in [area]'s top band (42·ts tall; decisions-log 187): [loot]'s icon, 16 px on a phone and
  /// 32 on the desk ([bagHeadIcon] at the book's pixel scale [ps]: whole multiples of the art, so it stays crisp), its
  /// name (an artefact's, a Pusaka's, in gold) and on the right the bag's count in the book's capsule ("x86"; a Pusaka's
  /// stars and Carve steps, "★2+3"). An item's enhanced stack (+[plus], decisions-log 255; forge-design §12): its icon in
  /// the level's colour ([_plusPaint]), its name and then "+3" in the level's ink on paper ([_plusPaperInk]), its stack's
  /// count. Returns the band's bottom.
  double _detailHeading(Canvas c, Game g, Enum loot, Rect area, double ts, double ps, {int plus = 0}) {
    const ink = Color(0xFF4A2C17);
    // A Pusaka owned shows its stars; the Shop's shelf Artifact not owned, its count (0) as the goods (decisions-log 230).
    final a = _assign, artefact = loot is Relic && (loot.store || loot.pusaka), pusaka = loot is Relic && loot.pusaka && g.pusaka.containsKey(loot);
    final cy = area.top + (24 * ts).roundToDouble(), side = bagHeadIcon(ps);
    final icon = _whole(Rect.fromLTWH(area.left, cy - side / 2, side, side));
    _icon(c, loot, icon, null, plus);
    final count = pusaka ? '$_starGlyph${g.pusaka[loot]?.stars ?? 0}' : 'x${loot is Item ? g.bagOf(loot, plus) : g.inBag(loot)}';
    final tail = pusaka ? ukirMark(g.pusaka[loot]?.ukir ?? 0) : null;
    final countAt = _capsule(c, count, math.max(10.0, 11 * ts), Offset(area.right, cy), anchor: Anchor.centerRight, tail: tail);
    final name = switch (loot) { final Relic r => relicNames[r]!, final Item i => itemNames[i]!, final Mat m => m.label, _ => '' };
    final nameX = icon.right + 6 * ts, nameFs = 20 * ts, end = countAt.left - 6 * ts;
    // The plus after the name, whole: the name gives way first.
    final up = plus > 0 ? ' +$plus' : '', upW = _textWidth(up, nameFs), shown = _fit(name, nameFs, end - nameX - upW);
    _text(c, shown, Offset(nameX, cy), size: nameFs, color: artefact ? _storeGold : ink);
    final nameW = _textWidth(shown, nameFs);
    if (up.isNotEmpty) _text(c, up, Offset(nameX + nameW, cy), size: nameFs, color: _plusPaperInk(plus));
    a.detail
      ..['icon'] = icon
      ..['count'] = countAt
      ..['name'] = Rect.fromLTWH(nameX, cy - nameFs * 0.65, nameW + upW, nameFs * 1.3);
    a.texts
      ..['name'] = '$shown$up'
      ..['count'] = '$count${tail ?? ''}';
    return area.top + (42 * ts).roundToDouble();
  }

  /// The lines under [loot]'s heading from [top] (decisions-log 202): an Artifact's where ([_pusakaWhere]: "Epic · in
  /// Vault", "Epic · on Templar (13)"), then what it is, whole, in a few lines to [area]'s width ([_descLines]; the
  /// action rows start under them; an enhanced stack's at its [plus]). Returns the lines' bottom.
  double _detailLines(Canvas c, Game g, Enum loot, Rect area, double top, double ts, double ps, {int plus = 0}) {
    const ink = Color(0xFF4A2C17);
    final fs = math.max(10.0, 13 * ts), lineH = math.max(14.0, (fs * 1.15).roundToDouble());
    var y = top;
    if (loot is Relic && loot.pusaka && g.pusaka.containsKey(loot)) {
      // Its parts one after another, the last cut to the room left.
      var x = area.left;
      final parts = _pusakaWhere(g, loot), shown = StringBuffer();
      for (final (i, (text, color)) in parts.indexed) {
        final t = i == parts.length - 1 ? _fit(text, fs, area.right - x) : text;
        _text(c, t, Offset(x, y + lineH / 2), size: fs, color: color);
        x += _textWidth(t, fs);
        shown.write(t);
      }
      _assign
        ..detail['where'] = Rect.fromLTRB(area.left, y, x, y + lineH)
        ..texts['where'] = '$shown';
      y += lineH;
    } else if (loot is Relic) {
      // A small relic's tier (decisions-log 227): "Strong relic", in its tier's ink.
      final tier = _fit(g.relicTierLine(loot), fs, area.width);
      _text(c, tier, Offset(area.left, y + lineH / 2), size: fs, color: _relicTierInk[g.relicTier(loot)] ?? ink);
      _assign
        ..detail['tier'] = Rect.fromLTWH(area.left, y, _textWidth(tier, fs), lineH)
        ..texts['tier'] = tier;
      y += lineH;
    }
    final lines = _descLines(g, loot, fs, area.width, ps < 2 ? bagDescLinesPhone : bagDescLines, plus: plus);
    for (final (i, line) in lines.indexed) {
      _text(c, line, Offset(area.left, y + (i + 0.5) * lineH), size: fs, color: ink);
    }
    _assign
      ..detail['desc'] = Rect.fromLTWH(area.left, y, lines.fold(0.0, (w, l) => math.max(w, _textWidth(l, fs))), lines.length * lineH)
      ..texts['desc'] = lines.join('\n');
    y += lines.length * lineH;
    if (loot is Mat) {
      // What a material is for, in grey under what drops it (decisions-log 221).
      const grey = Color(0xFF9E9080);
      final use = _wrap(matUseLine, fs, area.width, 2);
      for (final (i, line) in use.indexed) {
        _text(c, line, Offset(area.left, y + (i + 0.5) * lineH), size: fs, color: grey);
      }
      _assign.texts['use'] = use.join('\n');
      y += use.length * lineH;
    }
    return y;
  }

  /// What [loot] is, in a sentence or two of plain words (decisions-log 202): an item's first effect line for one troop
  /// type, and that each type takes a few ([Game.itemEffect]); a small relic's ([Game.relicEffect]), who it suits ([Relics.relicBestLine], decisions-log 227), and that a troop wears one ([relicSlotsLine]); an Artifact's first sentence ([firstSentence]) at its stars and Carve, and that it is
  /// for a whole type ([pusakaLine]); an oath's two lines. Without [tail], none of the closing sentences after what it
  /// does ([_descLines]). An item's enhanced stack: what one does at its [plus] (decisions-log 255).
  String _detailDesc(Game g, Enum loot, {bool tail = true, int plus = 0}) => switch (loot) {
        final Item i => '${g.itemEffect(i, null, plus).first} for one troop type.${tail ? ' Each type takes a few.' : ''}',
        Relic(oath: true) => '${g.relicEffect(loot).join('. ')}.',
        Relic(pusaka: true) => '${firstSentence(g.relicEffect(loot))}.${tail ? ' $pusakaLine.' : ''}',
        final Relic r => '${g.relicEffect(r).first}. ${g.relicBestLine(r)}.${tail ? ' $relicSlotsLine.' : ''}',
        final Mat m => g.matSource(m),
        _ => '',
      };

  /// [loot]'s description ([_detailDesc]) in lines of at most [w] px at [fs], never a word of it cut (decisions-log 214):
  /// all of it in at most [most] lines, or else what it does without the closing sentence (an Artifact's "For a whole
  /// type, never lost.", [pusakaLine]), whole however many lines that takes.
  List<String> _descLines(Game g, Enum loot, double fs, double w, int most, {int plus = 0}) {
    final all = _wrap(_detailDesc(g, loot, plus: plus), fs, w, 1 << 20);
    return all.length <= most ? all : _wrap(_detailDesc(g, loot, tail: false, plus: plus), fs, w, 1 << 20);
  }

  /// [text] in lines of at most [w] px at [fs], word by word (a bracket's words as one: "(Hero: 2)"), at most [most] of
  /// them, the last cut to fit ([_fit]).
  List<String> _wrap(String text, double fs, double w, int most) {
    final words = <String>[], lines = <String>[];
    for (final word in text.split(' ')) {
      if (words.isNotEmpty && words.last.contains('(') && !words.last.contains(')')) {
        words.last = '${words.last} $word';
      } else {
        words.add(word);
      }
    }
    var i = 0;
    while (i < words.length && lines.length < most - 1) {
      var line = words[i++];
      while (i < words.length && _textWidth('$line ${words[i]}', fs) <= w) {
        line = '$line ${words[i++]}';
      }
      lines.add(_fit(line, fs, w));
    }
    if (i < words.length) lines.add(_fit(words.sublist(i).join(' '), fs, w));
    return lines;
  }

  /// Where Pusaka [r] is, as the facing page's where line says it, in parts and their inks: its rarity in the rarity's
  /// dark ([_rarityFrame]), then " · in Vault", or " · on Templar (13)" (" (asleep)" while none of its type lives); an
  /// oath's "Oath: all troops", or while Oath of One or the Few waits, why ([_oathWaitingRow], red).
  List<(String, Color)> _pusakaWhere(Game g, Relic r) {
    const ink = Color(0xFF4A2C17);
    if (r.oath) {
      return [r == g.oath && g.oathWaits ? (_oathWaitingRow(g, r), _blockedInk) : ('${Words.oath}: all troops', ink)];
    }
    final rarity = (_rarityWords[r.rarity]!, _rarityFrame[r.rarity]?.$2 ?? ink), type = g.pusaka[r]?.type;
    if (type == null) return [rarity, (' · in ${Words.vault}', ink)];
    final n = g.troops.where((u) => u.alive && u.type == type).length;
    return [rarity, (' · on ${troopTypeNames[type] ?? type} ${g.pusakaAsleep(r) ? '(asleep)' : '($n)'}', ink)];
  }

  // Ukir (Carve; item-artefact-design U3 and U4, decisions-log 196; the rules: pusaka.dart's [Ukir]): spare items into a
  // Pusaka's Carve bar, five steps a share of a star each. A Pusaka's facing page has its Carve row ([_carveRow]); an
  // item's "Give to an Artifact" chooser has its Give rows ([_giveRows]), that kind alone into the one picked.

  /// Artifact [relic]'s Carve row ([BagAction.carve]; Ukir U3, decisions-log 196 and 202): its tag "Carve" in two taps
  /// like Sharpen (the first arms it: "Carve -20", the items one tap takes, in red; [_carveTap]); its line the bar
  /// ([_carveBar]: its steps and the points on this one, or why not in red), and while it is armed what the next step
  /// gives ([_carveNextLine]). A greyed tag's tap says why.
  void _carveRow(Canvas c, Game g, Relic relic, Rect r, _ActLook m) {
    final a = _assign, why = g.whyNotUkir(relic), end = r.right - m.inset;
    if (why != null) a.carveArmed = null; // a wave began, the budget or the items went: the first tap again
    final armed = a.carveArmed == relic;
    final label = armed ? '${Words.carve} -${g.ukirTake(relic).items.values.fold(0, (n, v) => n + v)}' : Words.carve;
    final (:x, :y1, :y2) = _actCard(c, BagAction.carve, r, m, why == null, (box, paint) => _uiIcon(c, _icCarve, box, paint));
    final tag = _rowTag(c, r, end, y1, label, m.lineFs, why != null ? _TagLook.off : (armed ? _TagLook.armed : _TagLook.go), () => _carveTap(relic));
    _actTitle(c, BagAction.carve, Words.carve, x, y1, tag.cap.left - 6 * m.ts, m, why == null);
    final line = Rect.fromLTRB(x, y2 - m.lineFs * 0.75, end, y2 + m.lineFs * 0.75);
    if (armed) {
      _carveNextLine(c, g, relic, line, m.lineFs);
    } else {
      _carveBar(c, g, relic, why, line, m.ts);
    }
    a
      ..carve = tag.hit
      ..detail['carve'] = r
      ..detail['carveBtn'] = tag.hit
      ..texts['carve'] = label
      ..texts['hint:${BagAction.carve.name}'] = (armed ? a.texts['next'] : a.texts['carveBar']) ?? '';
  }

  /// Pusaka [relic]'s Carve bar in [box], from its left: its steps ([_carvePips]) and the points on this one ("30/90"),
  /// or why it can't now in red ([why], shorter while it doesn't fit: [_carveWhy]); side by side where they fit, else the
  /// words over the steps in a smaller size. An oath, or before Carve opens, why alone. Under the pointer its help
  /// ([_Hint.carve]: [Ukir.carveInfo]). For tests, where it is and its words ('carveBar').
  void _carveBar(Canvas c, Game g, Relic relic, String? why, Rect box, double ts) {
    const ink = Color(0xFF4A2C17);
    final p = g.pusaka[relic]!, fs = math.max(10.0, 13 * ts), small = math.max(10.0, 11 * ts), color = why == null ? ink : _blockedInk;
    final words = why == null ? ['${p.feed}/${ukirCost[p.ukir]}'] : _carveWhy(g, why);
    var at = Rect.zero, shown = '';
    if (relic.oath || g.wave < ukirFrom) {
      shown = _fitFirst(words, fs, box.width);
      _text(c, shown, Offset(box.left, box.center.dy), size: fs, color: color);
      at = Rect.fromLTWH(box.left, box.center.dy - fs * 0.6, _textWidth(shown, fs), fs * 1.2);
    } else {
      final pw = _carvePips(c, p, Offset.zero, draw: false), gap = (4 * ts).roundToDouble(), x = box.left.roundToDouble();
      if (pw + gap + _textWidth(words.first, fs) <= box.width) {
        shown = words.first;
        _carvePips(c, p, Offset(x, box.center.dy));
        _text(c, shown, Offset(x + pw + gap, box.center.dy), size: fs, color: color);
        at = Rect.fromLTWH(x, box.center.dy - fs * 0.6, pw + gap + _textWidth(shown, fs), fs * 1.2);
      } else {
        // The words over the steps, the two centred in the strip together.
        shown = _fitFirst(words, small, box.width);
        final lineH = (small * 1.15).roundToDouble(), top = (box.center.dy - (lineH + 2 + 6) / 2).roundToDouble();
        _text(c, shown, Offset(x, top + lineH / 2), size: small, color: color);
        _carvePips(c, p, Offset(x, top + lineH + 2 + 3));
        at = Rect.fromLTWH(x, top, math.max(pw, _textWidth(shown, small)), lineH + 2 + 6);
      }
    }
    _tip.hints.add((at, _Hint.carve, relic.name));
    _assign
      ..detail['carveBar'] = at
      ..texts['carveBar'] = shown;
  }

  /// Carve's steps for [p] from [at] (their left middle): one small capsule each ([_pipSrc]) at 1 screen px a sprite px,
  /// a sprite px apart, on whole pixels: the steps taken full, the next as full as its bar ([OwnedPusaka.feed] of its
  /// cost, in tenths: one at least once fed, never full), the rest dark. The art's own pips (ui_bars.png), not a shape
  /// drawn here. Returns their width; with [draw] false it only measures.
  double _carvePips(Canvas c, OwnedPusaka p, Offset at, {bool draw = true}) {
    const w = 12.0, gap = 1.0;
    final n = ukirCost.length;
    if (draw) {
      final x = at.dx.roundToDouble(), y = (at.dy - 3).roundToDouble();
      for (var i = 0; i < n; i++) {
        final tenths = i < p.ukir ? 10 : (i > p.ukir || p.feed == 0 ? 0 : (10 * p.feed / ukirCost[i]).floor().clamp(1, 9));
        c.drawImageRect(_img('ui_bars.png'), _pipSrc(tenths), Rect.fromLTWH(x + i * (w + gap), y, w, 6), _px);
      }
    }
    return n * w + (n - 1) * gap;
  }

  /// [why] Carve can't now, then shorter ways to say it, longest first (a half strip's room is small).
  List<String> _carveWhy(Game g, String why) => [
        why,
        ...switch (why) {
          _ when why == ukirRefusals.midWave => ['Between waves', 'Later'],
          _ when why == ukirRefusals.from => ['From wave $ukirFrom', 'w$ukirFrom'],
          _ when why == ukirRefusals.oath => ['Not for an ${Words.oath}', 'No'],
          _ when why == ukirRefusals.full => ['Full'],
          _ when why == ukirRefusals.items => ['No items'],
          _ when why.startsWith(ukirRefusals.budget) => ['More at wave ${g.ukirAgainAt}', 'Wave ${g.ukirAgainAt}', 'w${g.ukirAgainAt}'],
          _ => const <String>[],
        },
      ];

  /// What Pusaka [relic]'s next Carve step gives ([Ukir.carveNext]), from [box]'s left middle at [fs]: "Next: 40% ▸ 42%
  /// HP left", the rest cut to fit ("Next: 42%" where the change doesn't); "Next: a bit stronger" when no number moves.
  /// For tests, its words ('next').
  void _carveNextLine(Canvas c, Game g, Relic relic, Rect box, double fs) {
    const ink = Color(0xFF4A2C17), lead = 'Next: ';
    final at = Offset(box.left, box.center.dy), n = g.carveNext(relic), x = at.dx + _textWidth(lead, fs);
    final w = n == null ? 0.0 : _change(c, n.now, n.after, Offset.zero, fs, draw: false);
    String said;
    if (n == null || x + w > box.right) {
      said = _fit(n == null ? '${lead}a bit stronger' : '$lead${n.after}', fs, box.width);
      _text(c, said, at, size: fs, color: ink);
    } else {
      _text(c, lead, at, size: fs, color: ink);
      _change(c, n.now, n.after, Offset(x, at.dy), fs);
      // The rest whole, else up to its first comma ("HP"), else none.
      final room = box.right - x - w, rest = [' ${n.rest}', ' ${n.rest.split(',').first}', '']
          .firstWhere((t) => n.rest.isNotEmpty && _textWidth(t, fs) <= room || t.isEmpty);
      _text(c, rest, Offset(x + w, at.dy), size: fs, color: ink);
      said = '$lead${n.now} ▸ ${n.after}$rest';
    }
    _assign.texts['next'] = said;
  }

  /// A tap on Pusaka [relic]'s Carve: the first arms it, the second feeds it ([Ukir.feedUkir]) and says what came of it
  /// ([_carveSaid]). Refused: the error and why.
  void _carveTap(Relic relic) {
    final g = state, a = _assign..asahArmed = null; // one thing at a time
    if (g.whyNotUkir(relic) case final why?) {
      a.carveArmed = null;
      g.feedUkir(relic); // the error
      return showMessage(why);
    }
    if (a.carveArmed != relic) {
      a.carveArmed = relic;
      return;
    }
    a.carveArmed = null;
    final step = g.pusaka[relic]!.ukir, take = g.ukirTake(relic);
    if (g.feedUkir(relic)) showMessage(_carveSaid(g, relic, step, take.items));
  }

  /// What a Carve or a Give did to Pusaka [relic] ([step]: its steps before; [items]: what went in): a new step, "Grail of
  /// Immortality ★2+3: a bit stronger!"; else its bar and the items, "Grail of Immortality: 70/90 (Potion 12, Staff 8)".
  String _carveSaid(Game g, Relic relic, int step, Map<Item, int> items) {
    final p = g.pusaka[relic]!, name = relicNames[relic]!;
    if (p.ukir > step) return '$name $_starGlyph${p.stars}+${p.ukir}: a bit stronger!';
    return '$name: ${p.feed}/${ukirCost[p.ukir]} (${[for (final MapEntry(:key, :value) in items.entries) '${itemNames[key]} $value'].join(', ')})';
  }

  /// The Pusaka [item] can be given to in its Give rows (U4), in their order: every one owned that takes Carve (not an
  /// oath: [Art.role]), the ones of its role first ([roleItems]: they count it twice), each part in the Bag's order
  /// ([bagKinds]). One that can't take it now is still listed, greyed with why.
  List<Relic> _giveRows(Game g, Item item) {
    final all = [for (final k in bagKinds(g, BagCategory.artifacts)) if (pusakaCatalog[k as Relic]?.role != null) k];
    bool mine(Relic r) => roleItems[pusakaCatalog[r]!.role]!.contains(item);
    return [...all.where(mine), ...all.where((r) => !mine(r))];
  }

  /// [relic]'s Give row for [item] in [r] (U4): its icon (ghosted when it can't take it); its name and what a tap does,
  /// "Give" (green); its badge ("★2+1", [_capsule]); its Carve bar ([_carvePips], "30/90") and what one of [item] counts
  /// there ("x2": [ukirMatch] for its role's kind, else [ukirAny]); and on the last line what a tap takes and does ("Uses
  /// 20: 30/90 ▸ 70/90"; a new step "Uses 30: +1 ▸ +2"), or why it can't in red ([Ukir.whyNotUkir] for that kind alone).
  /// Wide: the action right of the name, the badge on the bar's line; narrow (4 lines): the badge on the name's, the
  /// action on its own.
  void _giveRow(Canvas c, Game g, Item item, Relic relic, Rect r, _RowLook look) {
    const ink = Color(0xFF4A2C17), grey = Color(0xFF9E9080), green = Color(0xFF2E8B3A);
    final (:inset, :nameFs, :lineFs, :narrow, :ts) = look;
    final p = g.pusaka[relic]!, why = g.whyNotUkir(relic, only: item), ok = why == null;
    final side = math.min(r.height - 2 * inset, r.width * 0.25), box = Rect.fromLTWH(r.left + inset, r.center.dy - side / 2, side, side);
    _icon(c, relic, box.deflate(side * 0.12), ok ? _px : _ghost);
    final x = box.right + 4 * ts, end = r.right - inset - 2 * ts, lines = _rowLines(r, look);
    final word = Words.give, wordW = _textWidth(word, lineFs);
    final badge = _capsule(c, '$_starGlyph${p.stars}', lineFs, Offset.zero, anchor: Anchor.centerRight, tail: ukirMark(p.ukir), draw: false);
    void action(Offset at) => _text(c, word, at, size: lineFs, color: ok ? green : grey);
    void pill(Offset rightMid) => _capsule(c, '$_starGlyph${p.stars}', lineFs, rightMid, anchor: Anchor.centerRight, tail: ukirMark(p.ukir));

    final nameRight = narrow ? end - badge.width - 6 * ts : end - wordW - 6 * ts;
    _text(c, _fit(relicNames[relic]!, nameFs, nameRight - x), Offset(x, lines[0]), size: nameFs, color: ok ? ink : grey);
    if (narrow) {
      pill(Offset(end, lines[0]));
      action(Offset(x, lines[2]));
    } else {
      action(Offset(end - wordW, lines[0]));
      pill(Offset(end, lines[1]));
    }

    // The bar: its steps, "30/90" (at its last step "+5"), and what one counts.
    final barEnd = narrow ? end : end - badge.width - 6 * ts, at = Offset(x, lines[1]);
    final pw = _carvePips(c, p, at), full = p.ukir >= ukirCost.length;
    final each = 'x${roleItems[pusakaCatalog[relic]!.role]!.contains(item) ? ukirMatch : ukirAny}';
    final bar = full ? ukirMark(p.ukir)! : '${p.feed}/${ukirCost[p.ukir]}', tx = x + pw + 4 * ts;
    final said = _fitFirst(['$bar · $each', bar], lineFs, barEnd - tx);
    _text(c, said, Offset(tx, at.dy), size: lineFs, color: ok ? ink : grey);
    if (narrow && said == bar) _text(c, each, Offset(end, lines[2]), size: lineFs, color: ok ? ink : grey, anchor: Anchor.centerRight);

    // The last line: why not, or what a tap takes and does.
    final last = Offset(x, lines.last);
    if (why != null) {
      _text(c, _fitFirst(_carveWhy(g, why), lineFs, end - x), last, size: lineFs, color: _blockedInk);
      return;
    }
    final (:items, :points) = g.ukirTake(relic, only: item);
    final used = 'Uses ${items.values.fold(0, (n, v) => n + v)}', step = p.feed + points >= ukirCost[p.ukir];
    final (now, after) = step ? ('+${p.ukir}', '+${p.ukir + 1}') : ('${p.feed}/${ukirCost[p.ukir]}', '${p.feed + points}/${ukirCost[p.ukir]}');
    final w = _change(c, now, after, Offset.zero, lineFs, draw: false);
    // "Uses 30: 40/135 ▸ 100/135", else the change alone, else "Uses 30".
    final lead = [for (final t in ['$used: ', '']) if (x + _textWidth(t, lineFs) + w <= end) t].firstOrNull;
    if (lead == null) return _text(c, _fit(used, lineFs, end - x), last, size: lineFs, color: ink);
    _text(c, lead, last, size: lineFs, color: ink);
    _change(c, now, after, last.translate(_textWidth(lead, lineFs), 0), lineFs);
  }

  /// A tap on [relic]'s Give row for [item]: that kind alone into its Carve bar ([Ukir.feedUkir]), at once (no second
  /// tap: the row says what it takes), and what came of it ([_carveSaid]). Refused: the error and why.
  void _giveTap(Item item, Relic relic) {
    final g = state;
    if (g.whyNotUkir(relic, only: item) case final why?) {
      g.feedUkir(relic, only: item); // the error
      return showMessage(why);
    }
    final step = g.pusaka[relic]!.ukir, take = g.ukirTake(relic, only: item);
    if (g.feedUkir(relic, only: item)) showMessage(_carveSaid(g, relic, step, take.items));
  }

  /// The facing page's list [list] when it has no row, "No troops." centred in grey (none of the types the filter shows).
  void _detailEmpty(Canvas c, Rect list, double ts) {
    const grey = Color(0xFF9E9080);
    final fs = math.max(10.0, 13 * ts), lineH = (fs * 1.4).roundToDouble(), lines = ['No troops.'];
    var y = list.top + lineH / 2;
    final shown = [for (final line in lines) _fit(line, fs, list.width)];
    for (final line in shown) {
      _text(c, line, Offset(list.center.dx, y + lineH / 2), size: fs, color: grey, anchor: Anchor.center);
      y += lineH;
    }
    _assign
      ..detail['empty'] = Rect.fromLTRB(list.left, list.top + lineH / 2, list.right, y)
      ..texts['empty'] = shown.join('\n');
  }

  /// The list rows' measures in [list] ([_RowLook]) and a row's height: three lines, four on a narrow (phone) page,
  /// under 240 px.
  (_RowLook, double) _rowMeasures(Rect list, double ts) {
    final narrow = list.width < 240, lineFs = math.max(10.0, 13 * ts), nameFs = math.max(11.0, 15 * ts), inset = math.max(3.0, 4 * ts);
    final rowH = (2 * inset + nameFs * 1.3 + (narrow ? 3 : 2) * lineFs * 1.3).roundToDouble();
    return ((inset: inset, nameFs: nameFs, lineFs: lineFs, narrow: narrow, ts: ts), rowH);
  }

  /// [list]'s scroll bar for [content] px of rows scrolled [scroll] px down (decisions-log 187): ui_bars.png's capsules
  /// turned upright, [_capsuleBarW] wide and 9-sliced 1 px, the outline one ([_capsuleTrack]) down the list's right as
  /// the track and the dark one ([_capsuleSrc]) as the thumb, as long as the share shown and where the scroll is; on
  /// whole pixels. The Licences page's lists have the same (licence_page.dart).
  void _capsuleBar(Canvas c, Rect list, double content, double scroll) {
    const w = _capsuleBarW;
    final x = (list.right - w).roundToDouble(), top = list.top.roundToDouble(), len = list.height.roundToDouble();
    final h = math.max(2 * w, (len * list.height / content).roundToDouble());
    final y = top + ((len - h) * (scroll / (content - list.height)).clamp(0.0, 1.0)).roundToDouble();
    // A capsule [long] px from [from] down: drawn lying (12x6) in a frame turned a quarter clockwise, its left end at the
    // top. A quarter turn on whole pixels moves every pixel exactly.
    void upright(Rect src, double from, double long) {
      c.save();
      c.translate(x + w, from);
      c.rotate(math.pi / 2);
      _nine(c, src, Rect.fromLTWH(0, 0, long, w), 1, l: 1, t: 1, r: 1, b: 1, sheet: 'ui_bars.png', seam: 0); // its corners stay cut
      c.restore();
    }

    upright(_capsuleTrack, top, len);
    upright(_capsuleSrc, y, h);
    _capsuleBars.add(Rect.fromLTWH(x, top, w, len));
  }

  /// A relic's row for troop [u] in [r]: its sprite and stars (a Hero's crown), its name and the relics it holds
  /// (a slot each, a Hero two; empty ones for none), its type and HP, then why it can't take it, or the stats an
  /// artefact changes; with no preview [p] (nothing picked), the relics' names. A held relic's slot is a tap
  /// ([_AssignList.armed]): then the last line is its Remove, as it is for [remove] (the Remove chooser's, decisions-log
  /// 202).
  void _relicRow(Canvas c, Game g, Unit u, AssignPreview? p, Rect r, _RowLook look, {Relic? remove}) {
    const ink = Color(0xFF4A2C17), grey = Color(0xFF9E9080);
    final (:inset, :nameFs, :lineFs, :narrow, :ts) = look;
    final ok = p == null || p.why == null, a = _assign, clip = a.list;
    final box = _rowPortrait(c, g, u.type, r, look, ghost: !ok, crown: u.hero);
    final x = box.right + 4 * ts, end = r.right - inset - 2 * ts, lines = _rowLines(r, look);
    // The relics it holds, in small slots on the right of its name, in the order given: a tap on a held one picks
    // it out for Remove (lit), again lets it go.
    final side = nameFs * 1.3, slotGap = 3 * ts, n = u.relicSlots, slotsLeft = end - n * side - (n - 1) * slotGap;
    for (var i = 0; i < n; i++) {
      final slot = Rect.fromLTWH(slotsLeft + i * (side + slotGap), lines[0] - side / 2, side, side);
      final held = i < u.relics.length ? u.relics[i] : null, on = held != null && a.armed == (u, held);
      _card(c, slot, on ? Board._frameLit : Board._frameGrey);
      if (held != null) _icon(c, held, slot.deflate(slot.width * 0.14));
      if (!slot.overlaps(clip)) continue;
      a.slots.add((u, held, slot.intersect(clip)));
      if (held != null) a.taps.add((slot.intersect(clip), () => a.armed = on ? null : (u, held)));
    }
    _text(c, _fit(u.name, nameFs, slotsLeft - 4 * ts - x), Offset(x, lines[0]), size: nameFs, color: ok ? ink : grey);
    final hp = '${math.max(0.0, u.hp).ceil()}/${u.maxHp}', heart = lineFs * 1.1, hpW = heart + 2 * ts + _textWidth(hp, lineFs);
    final hpAt = narrow ? Offset(x, lines[2]) : Offset(end - hpW, lines[1]);
    _text(c, _fit(troopTypeNames[u.type]!, lineFs, (narrow ? end : hpAt.dx - 6 * ts) - x), Offset(x, lines[1]), size: lineFs, color: ok ? ink : grey);
    c.drawImageRect(_img('ui_icons.png'), _heartIcon, Rect.fromLTWH(hpAt.dx, hpAt.dy - heart / 2, heart, heart), ok ? _px : _ghost);
    _text(c, hp, Offset(hpAt.dx + heart + 2 * ts, hpAt.dy), size: lineFs, color: ok ? ink : grey);
    final last = Offset(x, lines.last);
    if (a.armed case (final armedU, final relic) when armedU == u) {
      _takeOffLine(c, g, u, relic, last, end, look);
    } else if (remove != null) {
      _takeOffLine(c, g, u, remove, last, end, look);
    } else if (p == null) {
      _text(c, _fit(u.relics.map((r) => relicNames[r]!).join(', '), lineFs, end - x), last, size: lineFs, color: ink);
    } else if (!ok) {
      _text(c, _fit(p.why!, lineFs, end - x), last, size: lineFs, color: _blockedInk);
    } else {
      _statChanges(c, p.stats, u.type, last, end, look);
    }
  }

  /// The Remove line for [relic] on troop [u]'s row, from [at] (the line's left middle) up to [end]: a light tag
  /// ([_tag], green) that takes it off ([Board._takeOff]), then the relic's name; greyed with why in red while it can't come off
  /// ([Game.whyNotTakeOff]: during a wave), and a tap on it says so.
  void _takeOffLine(Canvas c, Game g, Unit u, Relic relic, Offset at, double end, _RowLook look) {
    const ink = Color(0xFF4A2C17);
    final (:lineFs, :ts, inset: _, nameFs: _, narrow: _) = look;
    final why = g.whyNotTakeOff(relic, u), h = math.max(16.0, lineFs * 1.5), w = capsuleSize(_textWidth(Words.remove, lineFs), lineFs).width;
    // A light tag (decisions-log 198 and 202: a row's buttons are never ui_buttons' bevels), greyed while it can't.
    final btn = Rect.fromLTWH(at.dx, at.dy - h / 2, w, h);
    final hit = _tag(c, btn, () => _takeOff(relic, u), Words.remove, lineFs, look: why == null ? _TagLook.go : _TagLook.off, into: []);
    final textAt = Offset(btn.right + 4 * ts, at.dy);
    _text(c, _fit(why ?? relicNames[relic]!, lineFs, end - textAt.dx), textAt, size: lineFs, color: why == null ? ink : _blockedInk);
    if (hit.overlaps(_assign.list)) {
      _assign.lepas = hit.intersect(_assign.list);
      _assign.taps.add((_assign.lepas, () => _takeOff(relic, u))); // refused: the error and why
    }
  }

  /// An item's row for troop [type] (with [n] of it alive) in [r]: its sprite and stars, its name and count, the
  /// kind's taken/cap now and after, the stats the item changes (or why it can't take it), its price now and
  /// after, and the progress toward its next awakening now and after (in the new level's ink when the item
  /// completes it).
  void _itemRow(Canvas c, Game g, Item item, String type, int n, AssignPreview p, Rect r, _RowLook look) {
    const ink = Color(0xFF4A2C17), grey = Color(0xFF9E9080);
    final (:inset, :nameFs, :lineFs, :narrow, :ts) = look;
    final ok = p.why == null;
    final box = _rowPortrait(c, g, type, r, look, ghost: !ok, crown: g.hasHero(type));
    final x = box.right + 4 * ts, end = r.right - inset - 2 * ts, lines = _rowLines(r, look);
    // The kind's taken/cap, top right: now and after, or just now when it can't take one.
    final ((taken, cap), (taken2, cap2)) = p.count!;
    final countW = ok ? _change(c, '$taken/$cap', '$taken2/$cap2', Offset.zero, lineFs, draw: false) : _textWidth('$taken/$cap', lineFs);
    final countAt = narrow ? Offset(end, lines[2]) : Offset(end, lines[0]);
    // The price, now and after, after a coin: on the stats' line (its own on a narrow page).
    final (price, price2) = p.price!;
    final coin = lineFs * 1.1, priceW = coin + 2 * ts + _change(c, '$price', '$price2', Offset.zero, lineFs, draw: false);
    final priceAt = narrow ? Offset(x, lines[2]) : Offset(end - priceW, lines[1]);
    final fits = !narrow || priceAt.dx + priceW + 6 * ts + countW <= end; // the count, beside the price on a narrow page
    final nameEnd = narrow || !fits ? end : countAt.dx - countW - 6 * ts;
    _text(c, _fit('${troopTypeNames[type]} ($n)', nameFs, nameEnd - x), Offset(x, lines[0]), size: nameFs, color: ok ? ink : grey);
    if (fits) {
      if (ok) {
        _change(c, '$taken/$cap', '$taken2/$cap2', countAt, lineFs, right: true);
      } else {
        _text(c, '$taken/$cap', countAt, size: lineFs, color: grey, anchor: Anchor.centerRight);
      }
    }
    if (!ok) {
      _text(c, _fit(p.why!, lineFs, end - x), Offset(x, lines[1]), size: lineFs, color: _blockedInk);
    } else {
      _uiIcon(c, Board._icCoin, Rect.fromLTWH(priceAt.dx, priceAt.dy - coin / 2, coin, coin));
      _change(c, '$price', '$price2', Offset(priceAt.dx + coin + 2 * ts, priceAt.dy), lineFs);
      final own = _itemStat[itemOf(item.slot, 1)]; // a grade's kind's (decisions-log 249)
      _statChanges(c, [...p.stats]..sort((a, b) => (a.$1 == own ? 0 : 1).compareTo(b.$1 == own ? 0 : 1)), type, Offset(x, lines[1]),
          narrow ? end : priceAt.dx - 6 * ts, look);
    }
    // The next awakening: "Bangkit n: have/need" now and after; at the last level its name alone.
    final level = g.awakenLevel(type), last = Offset(x, lines.last);
    if (p.step case ((final have, final need), (final have2, _))?) {
      final label = '${awakenName(level + 1)}: ', lw = _textWidth(label, lineFs), up = p.awaken!.$2 > level;
      _text(c, label, last, size: lineFs, color: ok ? ink : grey);
      if (ok && have2 != have) {
        final w = _change(c, '$have/$need', '$have2/$need', last.translate(lw, 0), lineFs, to: up ? _awakeInk[p.awaken!.$2 - 1] : _previewInk);
        // Its awakening skill unlocked or raised (#88), after it while there is room: "Membuka Disarm", "Disarm II".
        final skill = up ? awakenSkillChange(type, level, p.awaken!.$2) : null, at = last.translate(lw + w + 3 * ts, 0);
        if (skill != null && end - at.dx > 8 * ts) _text(c, _fit(skill.$2 ?? skill.$1, lineFs, end - at.dx), at, size: lineFs, color: _awakeInk[p.awaken!.$2 - 1]);
      } else {
        _text(c, '$have/$need', last.translate(lw, 0), size: lineFs, color: ok ? ink : grey);
      }
    } else {
      _text(c, awakenName(level), last, size: lineFs, color: ok ? ink : grey);
    }
  }

  /// A Pusaka's row for troop [type] in [r] ([PusakaPreview] [p] for [relic]): its sprite and stars, its name and
  /// how many are alive ("Templar (13)"), what a tap does ("Equip", "Move", the coin and its price, "To Vault"; why it can't in red on
  /// the last line, a short purse in red on the price) and the type's Pusaka now in its badge ([_pusakaCapsule]; an empty
  /// slot for none); the stats it changes now ▸ after with the count and their sum after the first ("x13 (+4,511)"), or for one that changes
  /// none its effect in a few words ([pusakaGist]); and on the last line the next boss's blows a troop lives through
  /// now ▸ after ([bossBlowsLabel], when the HP changes), else the Pusaka the type loses to the Gudang. An oath's row
  /// ([PusakaAction.sumpah]) shows the type without the oath ▸ with it, and while Oath of One waits, why. Wide: the
  /// action on the name's line, the badge on the stats'; narrow (4 lines): the badge on the name's, the action on its
  /// own.
  void _pusakaRow(Canvas c, Game g, Relic relic, String type, PusakaPreview p, Rect r, _RowLook look) {
    const ink = Color(0xFF4A2C17), grey = Color(0xFF9E9080), green = Color(0xFF2E8B3A);
    final (:inset, :nameFs, :lineFs, :narrow, :ts) = look;
    final ok = p.why == null, short = p.why == pusakaRefusals.gold, n = p.alive;
    final box = _rowPortrait(c, g, type, r, look, ghost: !ok, crown: g.hasHero(type));
    final x = box.right + 4 * ts, end = r.right - inset - 2 * ts, lines = _rowLines(r, look);

    // What a tap does: its words, and a Move's coin and price.
    final word = pusakaActionNames[p.action]!, coin = lineFs * 1.1, price = shortPrice(p.price);
    final actionW = _textWidth(word, lineFs) + (p.action == PusakaAction.pindah ? 4 * ts + coin + 2 * ts + _textWidth(price, lineFs) : 0);
    void action(Offset at) {
      final wordInk = !ok && !short ? grey : (p.action == PusakaAction.pasang ? green : ink);
      _text(c, word, at, size: lineFs, color: wordInk);
      if (p.action != PusakaAction.pindah) return;
      final cx = at.dx + _textWidth(word, lineFs) + 4 * ts;
      _uiIcon(c, Board._icCoin, Rect.fromLTWH(cx, at.dy - coin / 2, coin, coin), ok || short ? _px : _ghost);
      _text(c, price, Offset(cx + coin + 2 * ts, at.dy), size: lineFs, color: short ? _blockedInk : (ok ? ink : grey));
    }

    // The type's Pusaka now: its badge, or an empty slot.
    final held = g.pusakaOf(type), pillH = capsuleSize(0, lineFs).height;
    final pillW = held == null ? pillH : _pusakaCapsule(c, g, held, Offset.zero, lineFs, draw: false).width;
    void badge(Offset rightMid) {
      if (held != null) {
        _pusakaCapsule(c, g, held, rightMid, lineFs);
      } else {
        _card(c, Rect.fromLTWH(rightMid.dx - pillH, rightMid.dy - pillH / 2, pillH, pillH), Board._frameGrey);
      }
    }

    final nameRight = narrow ? end - pillW - 6 * ts : end - actionW - 6 * ts;
    _text(c, _fit('${troopTypeNames[type]} ($n)', nameFs, nameRight - x), Offset(x, lines[0]), size: nameFs, color: ok ? ink : grey);
    if (narrow) {
      badge(Offset(end, lines[0]));
      action(Offset(x, lines[2]));
    } else {
      action(Offset(end - actionW, lines[0]));
      badge(Offset(end, lines[1]));
    }

    // The change: the first stat now ▸ after with the type's count and sum, then the others while they fit; or the
    // Pusaka's effect in a few words with the count.
    final changeEnd = narrow ? end : end - pillW - 6 * ts, at = Offset(x, lines[1]);
    if (p.stats.isEmpty) {
      _text(c, _fit('${pusakaGist(relic, g.pusaka[relic]?.stars ?? 1, ukir: g.pusaka[relic]?.ukir ?? 0)} (x$n)', lineFs, changeEnd - x), at,
          size: lineFs, color: ok ? ink : grey);
    } else {
      final (kind, now, after) = p.stats.first;
      final icon = lineFs * 1.1, a = _statText(now), b = _statText(after), sum = n * (after - now);
      _tasStatTexts[type] = (a, b); // the field's numbers, as the Pasukan row's ([Game.fieldStats])
      _statIcon(c, kind, type, Rect.fromLTWH(at.dx, at.dy - icon / 2, icon, icon));
      final w = _change(c, a, b, Offset(at.dx + icon + 2 * ts, at.dy), lineFs);
      final tail = n == 0 ? ' x0 (asleep)' : ' x$n (${sum >= 0 ? '+' : ''}${thousands(sum.round())})', tx = at.dx + icon + 2 * ts + w;
      _text(c, _fit(tail, lineFs, changeEnd - tx), Offset(tx, at.dy), size: lineFs, color: ok ? ink : grey);
      final rest = tx + _textWidth(tail, lineFs) + 6 * ts;
      if (p.stats.length > 1 && rest < changeEnd) _statChanges(c, p.stats.sublist(1), type, Offset(rest, at.dy), changeEnd, look);
    }

    // The last line: why it can't, the boss's blows, or what the type loses (an oath's: that it waits).
    final last = Offset(x, lines.last);
    if (p.action == PusakaAction.sumpah && relic == g.oath && g.oathWaits) {
      _text(c, _fit(_oathWaitingRow(g, relic), lineFs, end - x), last, size: lineFs, color: _blockedInk);
    } else if (!ok && !short) {
      _text(c, _fit(p.why!, lineFs, end - x), last, size: lineFs, color: _blockedInk);
    } else if (p.blows case (final was, final now)?) {
      final cw = _change(c, '$was', '$now', Offset.zero, lineFs, draw: false), room = end - x - cw - 4 * ts;
      final full = '${bossBlowsLabel(p.bossWave)}:';
      final label = _fit(_textWidth(full, lineFs) <= room ? full : '${bossBlowsLabel(p.bossWave, short: true)}:', lineFs, room);
      _text(c, label, last, size: lineFs, color: ink);
      _change(c, '$was', '$now', Offset(x + _textWidth(label, lineFs) + 4 * ts, last.dy), lineFs,
          to: now > was ? green : (now < was ? _blockedInk : _previewInk));
    } else if (held != null && held != relic && p.action != PusakaAction.lepas && p.action != PusakaAction.sumpah) {
      _text(c, _fit('${relicNames[held]} to ${Words.vault}', lineFs, end - x), last, size: lineFs, color: ink);
    }
  }

  /// The middle of each of a row's lines, top to bottom: the name's, then the smaller ones (three lines, four on
  /// a narrow page).
  List<double> _rowLines(Rect r, _RowLook look) {
    final top = r.top + look.inset, lineH = look.lineFs * 1.3;
    return [top + look.nameFs * 0.65, for (var i = 0; i < (look.narrow ? 3 : 2); i++) top + look.nameFs * 1.3 + lineH * (i + 0.5)];
  }

  /// [type]'s idle sprite on the left of row [r] with its awakening stars under it; ghosted for a row that can't take
  /// it, and the crown on its top right for a Hero ([crown]). Returns the box.
  Rect _rowPortrait(Canvas c, Game g, String type, Rect r, _RowLook look, {bool ghost = false, bool crown = false}) {
    final h = r.height - 2 * look.inset, box = Rect.fromLTWH(r.left + look.inset, r.top + look.inset, math.min(h * 0.8, r.width * 0.25), h);
    final level = g.awakenLevel(type), star = math.min(box.width / 3.4, box.height * 0.18);
    final tempa = g.tempaOf(type); // at Bangkit 5, "+n" after the stars (ascend_page.dart)
    final (stars, room) = _besideMark(Rect.fromCenter(center: Offset(box.center.dx, box.bottom - star / 2), width: star * 3.2, height: star), box.width, tempa);
    final b = _idleBounds[type]!, bottom = stars.top - 1, k = math.min(box.width / b.width, (bottom - box.top) / b.height);
    c.save();
    c.translate(box.center.dx, bottom);
    c.scale(k);
    _frame(c, 'book_${type}_idle', (_clock * _fps).floor(), Offset.zero, anchor: Offset(b.center.dx, b.bottom),
        paint: ghost ? _ghost : _px, line: _awakeLine(level, ghost: ghost));
    c.restore();
    _awakeStars(c, stars, level);
    _tempaMark(c, tempa, stars, room);
    if (crown) {
      final s = box.width * 0.4;
      _uiIcon(c, _icCrown, Rect.fromLTWH(box.right - s * 0.8, box.top, s, s));
    }
    return box;
  }

  /// The stats a gift changes, from [at] (the line's left middle) up to [end]: each one's icon and "now ▸
  /// after" (the preview blue), as many as fit.
  void _statChanges(Canvas c, List<(StatKind, num, num)> stats, String type, Offset at, double end, _RowLook look) {
    final (:lineFs, :ts, inset: _, nameFs: _, narrow: _) = look;
    final icon = lineFs * 1.1;
    var x = at.dx;
    for (final (kind, now, after) in stats) {
      var (a, b) = (_statText(now), _statText(after));
      if (a == b) (a, b) = (now.toStringAsFixed(2), after.toStringAsFixed(2)); // a small change: more places
      final w = icon + 2 * ts + _change(c, a, b, Offset.zero, lineFs, draw: false);
      if (x + w > end) break;
      _statIcon(c, kind, type, Rect.fromLTWH(x, at.dy - icon / 2, icon, icon));
      _change(c, a, b, Offset(x + icon + 2 * ts, at.dy), lineFs);
      x += w + 6 * ts;
    }
  }

  /// A stat's icon, as a troop row shows it: the heart, the blue bolt, or the icon of the item that raises it (the
  /// staff for a caster's power).
  void _statIcon(Canvas c, StatKind k, String type, Rect to) => switch (k) {
        StatKind.hp => c.drawImageRect(_img('ui_icons.png'), _heartIcon, to, _px),
        StatKind.mp => c.drawImageRect(_img('ui_icons.png'), _boltIcon, to, _mpPaint),
        StatKind.def => _icon(c, Item.shield, to),
        StatKind.dmg => _icon(c, powerItem(type), to),
        StatKind.range => _icon(c, Item.bow, to),
        StatKind.speed => _icon(c, Item.boots, to),
        StatKind.rate => _icon(c, Item.gloves, to),
        StatKind.regen => _icon(c, Item.potion, to),
      };

  /// "now ▸ after" from [at] (its left middle; its right with [right]): now in ink, ui_icons.png's small white
  /// right arrow ([_icThen], the font has none) at a whole number of screen px a sprite px about 0.6 of the text tall,
  /// after in [to]. Returns its width; with [draw] false it only measures.
  double _change(Canvas c, String now, String after, Offset at, double size,
      {Color to = _previewInk, bool right = false, bool draw = true}) {
    const ink = Color(0xFF4A2C17);
    final k = math.max(1.0, (size * 0.6 / _icThen.height).roundToDouble()), aw = _icThen.width * k;
    final gap = size * 0.25, nowW = _textWidth(now, size);
    final w = nowW + gap + aw + gap + _textWidth(after, size);
    if (!draw) return w;
    final x = right ? at.dx - w : at.dx, ax = (x + nowW + gap).roundToDouble();
    _text(c, now, Offset(x, at.dy), size: size, color: ink);
    c.drawImageRect(_img('ui_icons.png'), _icThen, Rect.fromLTWH(ax, (at.dy - _icThen.height * k / 2).roundToDouble(), aw, _icThen.height * k), _px);
    _text(c, after, Offset(ax + aw + gap, at.dy), size: size, color: to);
    return w;
  }
}

/// ui_icons.png's smallest white right arrow, its visible pixels: "now ▸ after" ([Board._change]).
const _icThen = Rect.fromLTWH(181, 180, 7, 10);

/// A list row's measures ([Board._assignPage]): its inset, its name's and its lines' text sizes, whether the page
/// is narrow (a phone's: four lines), and the page's text scale.
typedef _RowLook = ({double inset, double nameFs, double lineFs, bool narrow, double ts});

/// A stat as a troop row shows it: whole from 100 up (and whole numbers), else one decimal.
String _statText(num v) => v is int || v >= 100 || v == v.roundToDouble() ? '${v.round()}' : v.toStringAsFixed(1);

/// The Bag's facing page's heading icon at the book's pixel scale [ps] (decisions-log 187): 16 px on a phone (ps 1),
/// 32 on the desk (ps 2), whole multiples of the 16- and 32-px art so it stays crisp.
double bagHeadIcon(double ps) => ps < 2 ? 16 : 32.0 * (ps / 2).floor();

/// The most lines the Bag's facing page gives what a pick is ([Board._descLines], decisions-log 214): 3 on the desk, 4 on
/// a phone (the book's pixel scale under 2, as [bagHeadIcon]); a longer one drops its closing sentence, never a word of
/// what it does. The action rows start under them.
const bagDescLines = 3, bagDescLinesPhone = 4;

/// ui_bars.png's small green capsule filled [n] tenths of its inside (10: full; 0: the dark one, [_capsuleSrc]): its two
/// rows of five fills, the full one first. Carve's steps ([Board._carvePips], decisions-log 196).
Rect _pipSrc(int n) => n <= 0 ? _capsuleSrc : Rect.fromLTWH(2 + 16.0 * ((10 - n) % 5), n > 5 ? 65 : 73, 12, 6);

/// Carve's gold (decisions-log 196): a Pusaka's Carve steps after its stars in the book's badges ("★2+3": the "+3",
/// [Board._capsule]), so they never read as a star.
const ukirInk = Color(0xFFFFB627);

/// A small relic's tier line's ink on the facing page (decisions-log 227): Basic the page's own, Strong a Rare's green and
/// Mighty an Epic's violet ([_rarityFrame]'s darks).
final _relicTierInk = {RelicTier.strong: _rarityFrame[Rarity.langka]!.$2, RelicTier.mighty: _rarityFrame[Rarity.epik]!.$2};

/// The rarities in the facing page's where line ("Epic · in Vault"), the [Words] (draft.dart's [rarityNames] are the
/// chest's).
/// The waiting oath [r]'s Bag row ([oathWaitingRowOf]): the types alive against Oath of One's, the troops alive against
/// Oath of the Few's.
String _oathWaitingRow(Game g, Relic r) => oathWaitingRowOf(r, r == Relic.fewOath ? g.armySize : g.typesAlive);

const _rarityWords = {Rarity.biasa: Words.common, Rarity.langka: Words.rare, Rarity.epik: Words.epic, Rarity.legenda: Words.legendary};
