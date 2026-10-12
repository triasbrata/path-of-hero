part of 'main.dart';

// The Town's Smithy pages (decisions-log 235; town-design rev 2 §7; docs/ui-hud.md "The Smithy"; its rules: town.dart's
// [Craft], decisions-log 233), the book's Smithy tab in a Town, on the Bag's own code (bag.dart; the owner: "pakai yang
// existing saja"). The left page: "Smithy", the small relics as the Bag's paper-card slots in tier order ([smithyRelics];
// [Board._bagCell] on [_SmithyView.board]): the green ▲ on one that can be crafted now, its count in the Bag from 1, its
// icon faded while it can't, the picked one on the lit card; they take the whole page (decisions-log 302: the materials'
// grid that stood under them left every tab: the recipe rows, the Bag's Materials and the Shop's Buy show them). No
// buttons on the left page. The right page is the picked relic's, action
// first: its heading, what it does and "Strong relic. Best on: …" in grey, then its Recipe, a row per material, item and
// the gold ("have / need", green or red; an item a fielded type still needs for its next Awaken says so in orange), the
// page's one bevelled button Craft ("Craft (1,000 gold)"; refused, the white button with why, a tap saying it again),
// "No limit: craft again while you have enough" in grey, and the light row "Equip on a troop" that opens the Bag with the
// relic picked and its troops listed. Under the heading it scrolls where it doesn't all fit (decisions-log 283, the
// landscape book shorter; page_scroll.dart): nothing is left out.
//
// The forge's Smithy (decisions-log 254; forge-design §11-13, mockups 12 and 15): the left page has, under "Smithy", the
// Bag's segmented strip Items | Relics | Enhance ([SmithyTab]; Enhance greyed until wave 30 is won, [Enhance.enhanceOpen],
// a tap on it saying so). The Items tab's board is every item at once by grade (decisions-log 277; the owner: "untuk items
// tidak perlu di buatkan tab grade langsung saja di tampilkan semua"): a section per grade, "Grade I" to "Grade III" over
// its items, every kind's ([Craft.smithyItems]), marked as the relics are, the sections paged together where they don't
// all fit ([Board._sections], the Shop's Buy board's); the facing page is the picked item's, its recipe
// ([Craft.itemCraftRows]: the Cap's and the Ring's grade below in it), Craft ([Craft.craftItem]) and the light row "Give
// to troops" that opens the Bag with the item picked and its types listed (where the cap's swap-outs happen,
// decisions-log 249). The Relics tab is the page above. A board the Bag's slot would page is drawn at the small slot (a
// phone's 20 relics), and where that still doesn't fit, the relics' and the Enhance tab's boards page as the Items board
// does (decisions-log 283: the shorter landscape book). Every room on the left page is counted from the page's unrounded
// top, only the drawing on whole pixels: the book bobs, and a room counted from a rounded top changes by a pixel from
// frame to frame (decisions-log 277: the materials' rows and pager blinked at the owner's 1600x947 window).
//
// The Enhance tab (decisions-log 255; forge-design §12, mockup 12): its board is the two stones first (Mithril, Starmetal:
// what this tab makes, marked as the relics are), then the Bag's items by grade, III first, each item at +0 and each of
// its enhanced stacks its own cell (the stack's icon in its level's colour, its "+3" tag; [smithyEnhanceLoot]). A stone's
// facing page is its recipe and Craft ([Enhance.craftStone]). An item's: its heading with "+3" in the level's ink, what
// one does now and at +0, in grey its grade, how many times it was enhanced and what a step adds, "Recipe to +4" with
// the step's stone and gold rows ([Enhance.enhanceRows]), the bevelled "Enhance to +4 (2,500 gold)" ([Enhance.enhance];
// refused, the white one with why: "Need 1 Starmetal", "Max: +5"), in grey what one does at +4, and the light row "Give
// to a type" that opens the Bag with that stack picked and its types listed ("Knight: in place of its +0": at a type's
// cap the lowest plus comes back to the Bag, [Game.swapOut]).
//
// The Wishlist (decisions-log 282; wishlist.dart): on the Items board an item some type wishes for carries the pack's gold
// star and comes first in its grade ([smithyItemOrder]); its facing page, while wished, says "Ready to craft" or what the
// Bag still lacks ([Wishlist.wishShort]), and has its free line (a count and "Add to wishlist"; no types' chips since
// decisions-log 303); its Give row gives it to its one wishing type in a tap or opens the Bag's chooser on the wished
// types. A material a wish's recipe takes carries the star in the Bag's Materials and the Shop's Buy (decisions-log 300).
// Nothing crafts or gives by itself.
//
// The Wishlist tab (decisions-log 300, 302, 303; the owner: "aku kepikiran whitelist ini dibuat jadi tab sendiri", then
// "wishlist yang ada di tabs smithy itu seharusnya adalah tempat user untuk merealisasikan wishlistnya"): the strip's first,
// where the Smithy first opens ([Board._smithyWishes]), where wishes are made, never added. A group per type that wishes
// (its sprite and name) and the free lines' ("For the Bag", a product wished for no type: [Wishlist.freeWishes]), each a
// row per thing to make ([Wishlist.wishRows]): the product, how many are still wanted, its recipe for them with what the
// Bag holds, "Ready" or what is short, Craft and a type's "Give to Knight" in the row, a ✕ that takes it off; a group's
// Remove takes them all off. A met wish is off the tab at once. Wishes go on from the Army detail, the Bag's item and relic
// pages and a product's page here ([_freeLine]); a wished item's Give row gives it to its one wishing type in one tap
// ([Board._wishGive]).

/// The Smithy's relics in its board's order (decisions-log 235): every small relic in play ([Relics.relicsInPlay]) by its
/// tier, Basic, Strong, Mighty ([Relics.relicTier]), in [Relic] order within one.
List<Relic> smithyRelics(Game g) => [
      for (final tier in RelicTier.values)
        for (final r in g.relicsInPlay)
          if (g.relicTier(r) == tier) r,
    ];

/// The Items board's [grade] section in order (decisions-log 277, 282): the grade's items ([Craft.smithyItems]), the ones on
/// the Wishlist first ([Wishlist.wished]), each part in [Item] order.
List<Item> smithyItemOrder(Game g, int grade) {
  final items = g.smithyItems(grade);
  return [...items.where(g.wished), ...items.where((i) => !g.wished(i))];
}

/// The Smithy's tabs (decisions-log 254; forge-design §11-13), its strip's segments in order: the
/// Wishlist (decisions-log 302: leftmost, where the Smithy first opens), the items by grade, the small relics, and Enhance
/// (decisions-log 255; greyed until [Enhance.enhanceOpen]).
enum SmithyTab { wishlist, items, relics, enhance }

/// The Enhance tab's board in order (decisions-log 255; forge-design §12): the stones ([craftedMats] with a recipe,
/// [Enhance.stoneRecipe]), then the items the Bag holds by grade, III first, in the Bag's order within a grade: each at
/// +0 while some is held, then its enhanced stacks, lowest plus first ([_itemLoot]).
List<BagLoot> smithyEnhanceLoot(Game g) {
  final items = _itemLoot(g);
  return [
    for (final m in craftedMats)
      if (g.stoneRecipe(m) != null) (kind: m, plus: 0),
    for (var grade = Words.gradeNumerals.length; grade >= 1; grade--)
      for (final l in items)
        if (l.kind case Item(grade: final n) when n == grade) l,
  ];
}

/// The colour of +[plus] (decisions-log 255; town.json `enhance.tints`, the awakenings' colours): an enhanced stack's
/// "+3" tag on its dark capsule.
Color _plusInk(Game g, int plus) {
  final tints = g.townRules.enhance.tints;
  return Color(tints[(plus - 1).clamp(0, tints.length - 1)]);
}

/// +[plus]'s ink on paper (forge-design §12: the awakenings' inks, [_awakeInk]): the heading's "+3".
Color _plusPaperInk(int plus) => _awakeInk[(plus - 1).clamp(0, _awakeInk.length - 1)];

/// A grade's heading on the Smithy's Items board and the start of an item's grade line: "Grade II" ([Words.grade]).
String gradeTitle(int grade) => '${Words.grade[0].toUpperCase()}${Words.grade.substring(1)} ${Words.gradeNumerals[grade - 1]}';

/// The strip's words, in [SmithyTab] order (the Bag's chips' for Items and Relics).
const smithyTabNames = {SmithyTab.wishlist: Words.wishlist, SmithyTab.items: 'Items', SmithyTab.relics: 'Relics', SmithyTab.enhance: Words.enhance};

/// What a tap on the greyed Enhance says ([Enhance.enhanceOpen] false): the refusal's "Opens after wave 30"
/// ([CraftWhy.closed]).
String enhanceLocked(Game g) => CraftRefusal(CraftWhy.closed, need: g.townRules.enhance.from).text;

/// The grey line under an item's effect on the Smithy (decisions-log 254): its grade and what it is for. An Awaken
/// kind's "Grade II: for Awaken 2 (Soldier 2, Knight 3)." with how many each fielded type takes ([Game.gradeSet]), or
/// "No type here takes it." for none; a Cap's or a Ring's
/// ([outsideAwaken]) that it isn't, and that a better grade swaps out the lowest at a type's cap.
String smithyGradeLine(Game g, Item item) {
  final grade = gradeTitle(item.grade);
  if (outsideAwaken.contains(item.slot)) return "$grade: not for ${Words.awaken}. At a type's cap a better grade swaps out the lowest.";
  final fielded = {for (final u in g.troops) if (u.alive) u.type};
  final takes = [
    for (final type in troopTypes.keys)
      if (fielded.contains(type))
        if (g.gradeSet(type, item.grade)[item] case final n?) '${troopTypeNames[type] ?? type} $n',
  ];
  final level = awakenName(item.grade);
  return takes.isEmpty ? '$grade: for $level. No type here takes it.' : '$grade: for $level (${takes.join(', ')}).';
}

/// One row of the Smithy's recipe as drawn (for tests): its [kind] (a [Mat], an [Item]; null: the gold), where, its
/// "have / need", whether it is short, the monster a material comes from as shown ('' where it doesn't fit) and an item's
/// warning as shown ('' none).
typedef SmithyRow = ({Enum? kind, Rect at, String count, bool short, String from, String warn});

/// The Smithy's pages between frames.
class _SmithyView {
  Relic? pick; // the relic whose recipe the facing page shows (null: none yet: [Board._smithyPick] picks one)
  BagLoot? enhancePick; // the Enhance tab's stone or item stack (null: none yet: [Board._smithyEnhancePick] picks one)
  SmithyTab tab = SmithyTab.wishlist; // the strip's tab on: the Wishlist at first (decisions-log 302), then the player's, for the session
  Item? item; // the item whose recipe the Items tab's facing page shows (null: none yet: [Board._smithyItem] picks one)
  bool toItem = true; // the Items board turns to the pick's page once it is laid out (the pick new: none yet)
  bool toBoard = true; // the Relics or Enhance board turns to the pick's page the same (the pick or the tab new)
  final board = _BagGrid(smithy: true, category: BagCategory.relics); // the relics' board, paged by its pager where they don't fit
  final items = _BagGrid(smithy: true, category: BagCategory.items); // the Items tab's board: every grade's, paged by its pager
  final enhanceBoard = _BagGrid(smithy: true, enhance: true, category: BagCategory.items); // the Enhance tab's, paged the same
  // The pages' taps' grid ([Board._grid]: a cell's press and release, [_BagGrid.down]); the materials it drew under the
  // boards left every tab (decisions-log 302: the recipe rows, the Bag's Materials and the Shop's Buy show them).
  final mats = _BagGrid(smithy: true, category: BagCategory.materials);
  // The Wishlist tab (decisions-log 300, 302, 303; [Board._smithyWishes]): its spread (the pager's grid), and the group
  // whose Remove was tapped once (a type, or "free") and when. Per product how many more a free line's "Add" would ask
  // (1 at first; its Smithy and Bag pages, [Board._freeLine]).
  final wishes = _BagGrid(smithy: true, category: BagCategory.items);
  ({String type, double at})? wishArmed;
  final freeMore = <Enum, int>{};
  // This frame, for tests: each row on the tab's spread, its group (a type, or "free"), its product and where; each group
  // heading drawn (its group and where; a group going on to the next page has it there again).
  final wishCells = <(String, Enum, Rect)>[];
  final wishHeads = <(String, Rect)>[];
  // This frame, for tests: where each part of the pages is by key ('kinds', 'recipe', 'craft', 'noLimit', 'equip',
  // 'give'; the Enhance tab's 'enhance' and 'next'; the strip's segments 'tab:items', 'tab:relics', 'tab:enhance'; the
  // Items board's grade headings drawn, where their words are, 'grade:1' to 'grade:3'), the words drawn by key ('kinds',
  // 'effect', 'tier', 'recipe', 'craft', 'noLimit', 'enhance', 'next', 'give'; the strip's 'tabs', its words joined by
  // '|', and 'locked', the greyed tab's name; the Items board's 'grades', the headings drawn on its page joined by '|'),
  // and the recipe's rows.
  final at = <String, Rect>{};
  final texts = <String, String>{};
  final rows = <SmithyRow>[];
  final facing = _PageScroll(); // the facing page under its heading ([Board._smithyRecipe]): it scrolls past its room

  /// The book turned to another page ([Board._open]): the picks go, and the Items board's page with them (it opens on the
  /// next pick's); the tab stays.
  void unpick() {
    pick = null;
    item = null;
    toItem = toBoard = true;
    enhancePick = null;
    wishArmed = null;
    freeMore.clear();
  }

  void clear() {
    board.clear();
    items.clear();
    enhanceBoard.clear();
    mats.clear();
    wishes.clear();
    wishCells.clear();
    wishHeads.clear();
    at.clear();
    texts.clear();
    rows.clear();
    facing.clear();
  }
}

/// A relic the Smithy can't craft now: its icon at 40% (decisions-log 235).
final _smithyFaded = Paint()
  ..filterQuality = FilterQuality.none
  ..color = const Color(0x66FFFFFF);

/// How long the Wishlist tab's group Remove stays armed after a tap (s; decisions-log 300, 303): a second tap in it takes
/// the group's wishes off. Meanwhile it reads "Sure?" on the red capsule.
const _wishArmFor = 3.0;

/// The Wishlist tab's group of free lines (decisions-log 303): its key where a type's name stands ([WishRow.type] null).
const _wishFree = 'free';

/// [row]'s key on the Wishlist tab (decisions-log 303): its group (a type, or [_wishFree]) and its product's name,
/// "knight:sword", "free:sweep".
String _wishKey(WishRow row) => '${row.type ?? _wishFree}:${row.kind.name}';

/// The Wishlist tab's sizes at text scale [ts] (decisions-log 303): its words (never under 10 px), a line, a group's
/// heading (its sprite as tall), a row's padding inside its card and the gap under it, the gap between parts and the one
/// after an icon.
class _WishSizes {
  _WishSizes(double ts)
      : fs = math.max(10.0, 13 * ts),
        line = (math.max(10.0, 13 * ts) * 1.4).roundToDouble(),
        group = (math.max(10.0, 13 * ts) * 1.8).roundToDouble(),
        pad = math.max(3.0, (4 * ts).roundToDouble()),
        gap = math.max(2.0, (3 * ts).roundToDouble()),
        partGap = math.max(6.0, (8 * ts).roundToDouble()),
        iconGap = math.max(4.0, (6 * ts).roundToDouble());

  final double fs, line, group, pad, gap, partGap, iconGap;
}

/// One row's layout on the Wishlist tab ([Board._wishLay]; decisions-log 303): its card's height, its icon's side, where
/// its title's words start and where the lines under it start (from the card's inside left); its parts (each its kind,
/// the gold null; its words, "11/4" or the gold's "40"; whether the Bag has enough) and each part's line (1: the first
/// under the title) and x; its tags ('craft' or 'give', the words, the width), up on the title line by the ✕ or else
/// after the status; the line the status stands on at the right and where that line's free room starts.
class _WishLay {
  _WishLay(this.h, this.icon, this.textX, this.x2, this.parts, this.at, this.tags, this.tagsUp, this.endLine, this.endX);

  final double h, icon, textX, x2, endX;
  final List<(Enum?, String, bool)> parts;
  final List<(int, double)> at;
  final List<(String, String, double)> tags;
  final bool tagsUp;
  final int endLine;
}

/// A row's lines under its title on the Wishlist tab (decisions-log 303), from [x2] to [w] (inside its card, from its
/// left): its parts one after another ([partW] each, [gap] apart), as many to a line as fit; then its end ([endW]: the
/// status, and the tags where the title line had no room for them) at the right of the last line where it fits, else on
/// a line of its own. Each part's line (1: the first under the title) and x; the end's line and where its line's free
/// room starts; how many lines in all with the title's.
({List<(int, double)> at, int endLine, double endX, int lines}) wishFlow(List<double> partW, double endW, double x2, double w, double gap) {
  var line = 1, x = x2;
  final at = <(int, double)>[];
  for (final pw in partW) {
    if (x > x2 && x + pw > w + 0.5) {
      line++;
      x = x2;
    }
    at.add((line, x));
    x += pw + gap;
  }
  final own = at.isNotEmpty && x + endW > w + 0.5;
  final endLine = own ? line + 1 : line;
  return (at: at, endLine: endLine, endX: own || at.isEmpty ? x2 : x, lines: 1 + endLine);
}

/// The Wishlist tab's small remove tag's width at text [fs] ([Board._crossTag]): a tag's height and a third more.
double _crossW(double fs) => (capsuleSize(0, fs).height * 1.3).roundToDouble();

/// The recipe rows' inks: enough (green), and an item a fielded type still needs (orange; short is [_blockedInk]).
const _haveInk = Color(0xFF2E8B3A), _warnInk = Color(0xFFC0601A);

extension on Board {
  /// The relic the Smithy shows: the one picked, else the first on its board it can craft now, else its first
  /// ([smithyRelics]); once shown it stays until another is picked or the book turns to another page ([Board._open]).
  Relic _smithyPick(Game g) {
    final relics = smithyRelics(g);
    return _smithy.pick ??= relics.firstWhere(g.canCraft, orElse: () => relics.first);
  }

  /// Turns the book to the Smithy with [relic] picked (null: its first craftable, [_smithyPick]), on the Relics tab with
  /// the forge (decisions-log 254): a material's "Craft at the Smithy" in a Town (bag.dart).
  void _openSmithy([Relic? relic]) {
    _open(_Page.smithy);
    _smithy
      ..pick = relic
      ..toBoard = true;
    if (relic != null) _smithy.tab = SmithyTab.relics;
  }

  /// Turns the book to the Smithy's Items tab with [item] picked and its board on its page (decisions-log 282: a wish
  /// tapped on the Army detail, in a Town).
  void _openSmithyItem(Item item) {
    _open(_Page.smithy);
    _smithy
      ..tab = SmithyTab.items
      ..item = item
      ..toItem = true;
  }

  /// The Smithy's tab shown: the player's (Enhance only while open, else Items: a save from before wave 30 come in).
  SmithyTab _smithyTab(Game g) => _smithy.tab == SmithyTab.enhance && !g.enhanceOpen ? SmithyTab.items : _smithy.tab;

  /// The pick the shown tab's facing page is for: the Items tab's item ([_smithyItem]), the Enhance tab's stone or item
  /// at its plus ([_smithyEnhancePick]), else the relic ([_smithyPick]). Its cell and its recipe's materials are on the
  /// lit card ([_bagCell]).
  BagLoot _smithyShownAt(Game g) => switch (_smithyTab(g)) {
        SmithyTab.wishlist => (kind: _smithyItem(g), plus: 0), // no facing page there (decisions-log 303): the Items tab's
        SmithyTab.items => (kind: _smithyItem(g), plus: 0),
        SmithyTab.relics => (kind: _smithyPick(g), plus: 0),
        SmithyTab.enhance => _smithyEnhancePick(g),
      };

  /// The materials [pick]'s recipe takes (a relic's [Craft.craftRecipe], an item's [Craft.itemRecipe], a stone's
  /// [Enhance.stoneRecipe]; on the Enhance tab an item's next step's stone, [Enhance.enhanceCost]; none without one).
  Map<Mat, int> _smithyMats(Game g, BagLoot pick) =>
      switch (pick.kind) {
        Item() when _smithyTab(g) == SmithyTab.enhance => switch (g.enhanceCost(pick.plus)) { (:final stone, gold: _) => {stone: 1}, null => null },
        final Item i => g.itemRecipe(i)?.materials,
        final Relic r => g.craftRecipe(r)?.materials,
        final Mat stone => g.stoneRecipe(stone)?.materials,
        _ => null,
      } ??
      const {};

  /// The Enhance tab's pick (decisions-log 255): the one picked while its cell is on the board ([smithyEnhanceLoot]),
  /// else the first item it can take a step up now ([Enhance.canEnhance]), else its first item, else its first stone;
  /// once shown it stays as [_smithyPick]'s relic does. A step up moves it to the new stack ([_enhanceTap]).
  BagLoot _smithyEnhancePick(Game g) {
    final board = smithyEnhanceLoot(g);
    if (_smithy.enhancePick case final pick? when board.contains(pick)) return pick;
    final items = [for (final l in board) if (l.kind is Item) l];
    bool can(BagLoot l) => switch (l.kind) { final Item item => g.canEnhance(item, l.plus), _ => false };
    return _smithy.enhancePick = items.firstWhere(can, orElse: () => items.firstOrNull ?? board.firstOrNull ?? (kind: craftedMats.first, plus: 0));
  }

  /// The item the Items tab shows: the one picked, else in the lowest grade a fielded type (a living troop of it) still
  /// needs for its next Awaken ([Game.awakenShort]; none: grade I) the first it can craft now, else that grade's first,
  /// in the board's order (a wished one first, [smithyItemOrder]); once shown it stays as [_smithyPick]'s relic does, and
  /// the board opens on its page.
  Item _smithyItem(Game g) {
    if (_smithy.item case final item?) return item;
    final needed = [
      for (final type in {for (final u in g.troops) if (u.alive) u.type})
        for (final item in g.awakenShort(type).keys) item.grade,
    ];
    final items = smithyItemOrder(g, needed.isEmpty ? 1 : needed.reduce(math.min));
    return _smithy.item = items.firstWhere(g.canCraftItem, orElse: () => items.first);
  }

  /// A tap on the strip's [tab]: it turns to it; Enhance greyed says when it opens ([enhanceLocked]).
  void _smithyTabTap(SmithyTab tab) {
    if (tab != SmithyTab.enhance || state.enhanceOpen) {
      _smithy
        ..tab = tab
        ..toBoard = true;
    } else {
      showMessage(enhanceLocked(state));
    }
  }

  /// The Smithy's two pages in a Town: on [left] under the strip ([_smithyStrips]) the tab's board, the whole page
  /// (decisions-log 302: no tab keeps the materials' grid; the recipe rows, the Bag's Materials and the Shop's Buy show
  /// them): the Wishlist's lines ([_smithyWishes]), the Items tab's every grade at once ([_sections]), the relics' or the
  /// Enhance tab's; on [right] the pick's recipe and Craft ([_smithyRecipe]). [ts] is the page's text scale, [ps] the
  /// book's pixel scale (the cells' sprite scale). Every room on the page is counted from the board's unrounded top and
  /// only the drawing stands on whole pixels: the book bobs, and a room counted from a rounded top changes by a pixel from
  /// frame to frame (decisions-log 277: a row that fits to within a pixel came and went).
  void _smithyPages(Canvas c, Game g, Rect left, Rect right, double ts, double ps) {
    const ink = Color(0xFF4A2C17);
    final v = _smithy, tab = _smithyTab(g);
    _text(c, Words.smithy, Offset(left.center.dx, _titleY(left, ts)), size: 22 * ts, color: ink, anchor: Anchor.center, bold: true);
    // The board's top as counted (unrounded); every height under it is whole pixels.
    final at = _smithyStrips(c, g, left, _underTitle(left, ts), ts, ps);
    final (band, bandGap) = _pagerBand(ts, ps);
    final area = Rect.fromLTRB(left.left, at, left.right, math.max(at, left.bottom));
    // The Wishlist tab's rows take both pages (decisions-log 303).
    if (tab == SmithyTab.wishlist) return _smithyWishes(c, g, area, right, ts, ps);
    final pick = _smithyShownAt(g);

    // The board in [secs] on the page: at the small slot where the Bag's would page it (a phone's 20 relics); paged as
    // tall as its tallest page and its pager (the same pages). It opens on the pick's page; the pager and the wheel turn
    // it, the pick stays.
    ({double height, List<(int, Rect)> heads}) board(_BagGrid b, List<_Section> secs, BagLoot? held) {
      b.shrunk = _sectionsLay(area, secs, ts, ps).pages.length > 1;
      final lay = _sectionsLay(area, secs, ts, ps, small: b.small);
      final shown = lay.pages.length > 1 ? Rect.fromLTWH(area.left, at, area.width, lay.tallest + bandGap + band) : area;
      final (:heads, notes: _, :height) = _sections(c, g, shown, b, secs, held, ts, ps);
      return (height: height, heads: heads);
    }

    if (tab == SmithyTab.items) {
      // Every grade's items at once (decisions-log 277), a section per grade under its heading.
      final item = _smithyItem(g);
      final secs = [
        for (var n = 1; n <= Words.gradeNumerals.length; n++) (title: gradeTitle(n), loot: [for (final i in smithyItemOrder(g, n)) (kind: i, plus: 0)], note: ''),
      ];
      final (height: _, :heads) = board(v.items, secs, v.toItem ? (kind: item, plus: 0) : null);
      v.toItem = false;
      for (final (i, r) in heads) {
        v.at['grade:${i + 1}'] = r;
      }
      v.texts['grades'] = [for (final (i, _) in heads) secs[i].title].join('|');
    } else {
      // The relics' or the Enhance tab's board: as many columns as the page takes and the rows that hold them, centred,
      // no empty slot after the last (a section with no heading, [_sections]). The Enhance tab's: the stones, then the
      // items held and their stacks.
      final secs = [(title: '', loot: tab == SmithyTab.relics ? [for (final r in smithyRelics(g)) (kind: r, plus: 0)] : smithyEnhanceLoot(g), note: '')];
      board(tab == SmithyTab.relics ? v.board : v.enhanceBoard, secs, v.toBoard ? pick : null);
      v.toBoard = false;
    }
    _smithyRecipe(c, g, pick, right, ts, ps);
  }

  /// The Wishlist tab (decisions-log 300, 302, 303; the owner, 2026-10-09: "wishlist yang ada di tabs smithy itu
  /// seharusnya adalah tempat user untuk merealisasikan wishlistnya jadi harusnya tidak ada perubahan wishlist di situ"):
  /// where the wishes are made, never added, on both pages of the book. In [area] under the strip (its top unrounded: the
  /// book bobs, decisions-log 277): "Wishlist" (bold) and in grey how many the rows still want ("11 needed", where it
  /// fits); then a group per type with open wishes ([troopTypes] order) and the free lines' last, each its heading
  /// ([_wishGroupHead]: the type's sprite and name, or "For the Bag"; its Remove) over its rows, one row a thing to make
  /// ([Wishlist.wishRows], [_wishRowDraw]; the owner: "1 baris per barang", "ini satu whitelist 1 row, jangan di gabung"),
  /// the page's whole width, a few px apart: down the left page, then on down the [right] page from its top (no product
  /// page here: the rows craft and give themselves, and their parts' tooltips say where a material drops). A heading never
  /// ends a page, and a group going on to the next page starts it with its heading again; past one spread the Bag's pager
  /// at the left page's foot (the wheel over either page). None: "No wishes yet." and where to put them on, in grey.
  void _smithyWishes(Canvas c, Game g, Rect area, Rect right, double ts, double ps) {
    const ink = Color(0xFF4A2C17), grey = Color(0xFF9E9080);
    final v = _smithy, w = v.wishes, s = _WishSizes(ts), fs = s.fs, headH = _gridHeadHeight(ts);
    final x0 = area.left.roundToDouble(), x1 = area.right.floorToDouble(), top = area.top.roundToDouble();
    final rx0 = right.left.roundToDouble(), rx1 = right.right.floorToDouble();
    final rows = g.wishRows, needed = rows.fold(0, (a, r) => a + r.need);
    final titleW = _textWidth(Words.wishlist, fs, bold: true), count = '$needed needed', cx = x0 + titleW + 6 * ts;
    _text(c, Words.wishlist, Offset(x0, top + headH / 2), size: fs, color: ink, bold: true);
    v.at['wishHead'] = Rect.fromLTWH(x0, top, titleW, headH);
    if (needed > 0 && cx + _textWidth(count, fs) <= x1) {
      _text(c, count, Offset(cx, top + headH / 2), size: fs, color: grey);
      v.texts['wishNeeded'] = count;
    }
    v.texts['wishLines'] = [for (final r in rows) '${_wishKey(r)} ×${r.need}'].join('|');
    final (band, bandGap) = _pagerBand(ts, ps);
    final rowsAt = area.top + headH, from = rowsAt.roundToDouble(), room = area.bottom - rowsAt;
    // [count] spreads: the spread shown, the wheel over the rows' room on both pages ([_BagGrid.grid]) and the pager at the
    // left page's foot past one, as far from the drawn top as from the counted one so it keeps its place against the rows
    // while the book bobs (as the Bag's board's, decisions-log 277).
    int pager(int count) {
      w.pageCount = math.max(1, count);
      final page = w.pages[w.category] = w.page.clamp(0, w.pageCount - 1);
      w.grid = Rect.fromLTRB(area.left, rowsAt, right.right, math.max(area.bottom, right.bottom));
      final y = area.bottom + from - rowsAt;
      if (w.pageCount > 1) _bagPager(c, Rect.fromLTRB(area.left, y - band, area.right, y), ts, on: w);
      return page;
    }

    if (rows.isEmpty) {
      // None wished: where wishes are put on (this tab adds none).
      final lines = ['${Words.noWishes}.', ...this._wrap('${Words.addWishesFrom}.', fs, x1 - x0, 3)]; // the Bag's (bag.dart)
      final shown = [for (final (i, line) in lines.indexed) if ((i + 1) * s.line <= room + 0.5) line];
      for (final (i, line) in shown.indexed) {
        _text(c, line, Offset((x0 + x1) / 2, from + (i + 0.5) * s.line), size: fs, color: grey, anchor: Anchor.center);
      }
      v.texts['wishEmpty'] = shown.join('\n');
      pager(1);
      return;
    }

    // The pieces top to bottom: a group's heading (no row), or a row with the gap under it; laid at the narrower page's
    // width, so each stands on either page.
    final lays = [for (final r in rows) _wishLay(g, r, math.min(x1 - x0, rx1 - rx0), s, ps)];
    final pieces = <(String, int?, double)>[];
    for (final (i, r) in rows.indexed) {
      final group = r.type ?? _wishFree;
      if (pieces.isEmpty || pieces.last.$1 != group) pieces.add((group, null, s.group));
      pieces.add((group, i, lays[i].h + s.gap));
    }
    // The columns: the left page's (even) and the right page's (odd), [left] and [right] tall in turn.
    List<List<int>> paged(double left, double right) {
      final out = <List<int>>[[]];
      var used = 0.0;
      for (final (i, p) in pieces.indexed) {
        if (out.last.isNotEmpty && used + p.$3 > (out.length.isOdd ? left : right) + 1e-9) {
          final carry = pieces[out.last.last].$2 == null && out.last.length > 1
              ? [out.last.removeLast()] // a heading never ends a page
              : [if (p.$2 != null) pieces.lastIndexWhere((q) => q.$2 == null, i)]; // a group going on: its heading again
          out.add(carry);
          used = carry.fold(0.0, (a, j) => a + pieces[j].$3);
        }
        out.last.add(i);
        used += p.$3;
      }
      return out;
    }

    // The right page's room half a px short: its rows are drawn from the left page's rounded top (below), up to a px off.
    final rRoom = right.bottom - right.top - 0.5;
    var cols = paged(room, rRoom);
    if (cols.length > 2) cols = paged(room - band - bandGap, rRoom);
    final page = pager((cols.length + 1) ~/ 2), shown = <String>[];
    for (final side in [0, 1]) {
      if (2 * page + side >= cols.length) break;
      final (cx0, cx1) = side == 0 ? (x0, x1) : (rx0, rx1);
      // The right page's top as far from the left's drawn top as from its counted one: both pages keep their places
      // against each other while the book bobs (decisions-log 277).
      var y = side == 0 ? from : from + (right.top - rowsAt).roundToDouble();
      for (final i in cols[2 * page + side]) {
        final (group, row, h) = pieces[i];
        if (row == null) {
          _wishGroupHead(c, g, group, Rect.fromLTWH(cx0, y, cx1 - cx0, s.group), s);
        } else {
          _wishRowDraw(c, g, rows[row], lays[row], Rect.fromLTWH(cx0, y, cx1 - cx0, lays[row].h), s);
          shown.add(_wishKey(rows[row]));
        }
        y += h;
      }
    }
    int rowsIn(List<int> col) => col.where((i) => pieces[i].$2 != null).length;
    v.texts
      ..['wishPage'] = shown.join('|')
      ..['wishPer'] = [for (var k = 0; k < cols.length; k += 2) '${rowsIn(cols[k])}+${k + 1 < cols.length ? rowsIn(cols[k + 1]) : 0}'].join(',');
  }

  /// [group]'s heading on the Wishlist tab in [r] (decisions-log 303): a type's idle sprite in its awakening's outline
  /// ([_typeIcon]) and its name, or the free lines' "For the Bag", bold; at the right the light tag Remove, which a first
  /// tap arms ("Sure?" on the red capsule, for [_wishArmFor] s) and a second takes the group's wishes off ([_wishOffAll]).
  void _wishGroupHead(Canvas c, Game g, String group, Rect r, _WishSizes s) {
    const ink = Color(0xFF4A2C17);
    final v = _smithy, free = group == _wishFree;
    final armed = v.wishArmed?.type == group && _clock - v.wishArmed!.at < _wishArmFor;
    final hit = _tag(c, r, () => _wishOffAll(group), armed ? Words.sure : Words.remove, s.fs, look: armed ? _TagLook.armed : _TagLook.link);
    var x = r.left;
    if (!free) {
      _typeIcon(c, g, group, Rect.fromLTWH(r.left, r.top + 1, r.height - 2, r.height - 2));
      x += r.height - 2 + s.iconGap / 2;
    }
    final name = _fit(free ? Words.forBag : troopTypeNames[group] ?? group, s.fs, hit.left - 4 - x);
    _text(c, name, Offset(x, r.center.dy), size: s.fs, color: ink, bold: true);
    final head = Rect.fromLTRB(r.left, r.top, hit.left, r.bottom);
    // The keys keep the group's first heading on the spread (its taps work on each).
    v.wishHeads.add((group, head));
    v
      ..at.putIfAbsent('wishType:$group', () => head)
      ..at.putIfAbsent('wishOffAll:$group', () => hit)
      ..texts['wishType:$group'] = name
      ..texts['wishOffAll:$group'] = armed ? Words.sure : Words.remove;
  }

  /// [row]'s layout on the Wishlist tab, its card [w] wide ([_WishLay]; decisions-log 303): its icon ([bagHeadIcon]: 16
  /// px on a phone, 32 on the desk), its title's words after it, the lines under the title from the inside left where the
  /// icon is a line tall, else under the title's words; its tags ([_wishTags]) on the title line by the ✕ where the name
  /// still fits whole beside them, else after the status; its parts (none with nothing to make) and their flow
  /// ([wishFlow]), the status's shortest form at the end; the card the padding round its lines, at least the icon tall.
  _WishLay _wishLay(Game g, WishRow row, double w, _WishSizes s, double ps) {
    final icon = bagHeadIcon(ps), inner = w - 2 * s.pad, textX = icon + s.iconGap, x2 = icon > s.line ? textX : 0.0;
    final parts = [
      if (row.make > 0)
        for (final p in row.parts) (p.kind, p.kind == null ? shortPrice(p.need) : '${shortCount(p.have)}/${p.need}', p.have >= p.need),
    ];
    double wide(List<(String, String, double)> tags) => tags.fold(0.0, (a, t) => a + t.$3) + 4.0 * math.max(0, tags.length - 1);
    final up = inner - textX - _textWidth('${_lootName(row.kind)} ×${row.need}', s.fs) - 2 * s.iconGap - _crossW(s.fs) - 3;
    final statusMin = _textWidth(_wishStatus(g, row).$1.last, s.fs);
    var tags = _wishTags(g, row, s.fs, up);
    final tagsUp = wide(tags) <= up;
    if (!tagsUp) tags = _wishTags(g, row, s.fs, inner - x2 - statusMin - s.iconGap);
    final endW = statusMin + (tagsUp || tags.isEmpty ? 0 : s.iconGap + wide(tags));
    final flow = wishFlow([for (final p in parts) 18 + _textWidth(p.$2, s.fs)], endW, x2, inner, s.partGap);
    return _WishLay(2 * s.pad + math.max(icon, flow.lines * s.line), icon, textX, x2, parts, flow.at, tags, tagsUp, flow.endLine, flow.endX);
  }

  /// [row]'s tags on the Wishlist tab (decisions-log 303; the owner: "Craft + Give di baris"): Craft while some are still
  /// to make, then for a type's wish Give while the Bag holds one ("Give to Knight", "Give" where the two don't fit in
  /// [room]); each its key, its words and its width at [fs] ([capsuleSize]).
  List<(String, String, double)> _wishTags(Game g, WishRow row, double fs, double room) {
    double wide(String label) => capsuleSize(_textWidth(label, fs), fs).width;
    final craft = row.make > 0 ? Words.craft : null;
    var give = switch (row.type) { final type? when g.inBag(row.kind) > 0 => '${Words.give} to ${troopTypeNames[type] ?? type}', _ => null };
    if (give != null && (craft == null ? 0 : wide(craft) + 4) + wide(give) > room) give = Words.give;
    return [if (craft != null) ('craft', craft, wide(craft)), if (give != null) ('give', give, wide(give))];
  }

  /// [row]'s status on the Wishlist tab (decisions-log 303; the owner: "Ready" or "Short: Orc Tooth 1"), its forms longest
  /// first and its ink: a type's with nothing to make, the Bag holding them ("In Bag: 2"), green; "Ready" while the Bag
  /// pays for all still to make, green; else what it is short for them ([Wishlist.wishRowShort]: "Short: Orc Tooth 1,
  /// 40 gold", "Short: Orc Tooth 1 +1", "Short"), red.
  (List<String>, Color) _wishStatus(Game g, WishRow row) {
    if (row.make == 0) {
      final n = g.inBag(row.kind);
      return (['In ${Words.bag}: $n', 'In ${Words.bag}'], _haveInk);
    }
    final short = g.wishRowShort(row);
    if (short.isEmpty) return (const [Words.ready], _haveInk);
    String said((Enum?, int) p) => switch (p.$1) { final k? => '${_lootName(k)} ${p.$2}', null => '${shortPrice(p.$2)} gold' };
    final first = '${Words.short}: ${said(short.first)}';
    return (
      [
        if (short.length > 1) ...['${Words.short}: ${short.map(said).join(', ')}', '$first +${short.length - 1}'] else first,
        Words.short,
      ],
      _blockedInk
    );
  }

  /// [row]'s card on the Wishlist tab in [r] as [lay] lays it (decisions-log 303; the owner: "Sword ×2 · for Knight", then
  /// its materials with have/need and "Ready" or what is short), an inset paper card: its product's icon (its tooltip the
  /// Bag cell's); the title line, its name and how many are still wanted in ink ("Sword ×2"), "for Knight" in grey where it
  /// fits whole, its tags and the small ✕ at the right ([_crossTag]: a tap takes the wish off, [_wishOff]); under it the
  /// parts, each its 16-px icon (the gold's coin) and "have/need" for all still to make (the gold what it takes), green
  /// where the Bag has enough, red where short, their tooltips the Bag cell's; at the right of the last line the status
  /// ([_wishStatus], the longest form that fits) and, where the title had no room, the tags. The tags are the kit's green
  /// capsule, greyed while refused (a tap then says why): Craft ([_craftTap], the item page's), and for a type's wish while
  /// the Bag holds one "Give to Knight" ([_wishGive], the item page's one-tap Give).
  void _wishRowDraw(Canvas c, Game g, WishRow row, _WishLay lay, Rect r, _WishSizes s) {
    const ink = Color(0xFF4A2C17), grey = Color(0xFF9E9080);
    final v = _smithy, key = _wishKey(row);
    _card(c, r, Board._framePlain);
    final left = r.left + s.pad, right = r.right - s.pad, line1 = r.top + s.pad;
    // The icon at the title's middle where it is a line tall (a phone's 16 px), else from the top (the desk's 32 px).
    final icon = _whole(Rect.fromLTWH(left, lay.icon <= s.line ? line1 + (s.line - lay.icon) / 2 : line1, lay.icon, lay.icon));
    _icon(c, row.kind, icon);
    _wishSlot(icon, row.kind); // its tooltip
    final off = _crossTag(c, Rect.fromLTRB(left, line1, right, line1 + s.line), () => _wishOff(row), s.fs);
    final tagsW = lay.tags.fold(0.0, (a, t) => a + t.$3) + 4.0 * math.max(0, lay.tags.length - 1);

    // The tags, from [x] on the line [top].
    void tags(double x, double top) {
      for (final (what, label, tw) in lay.tags) {
        final btn = Rect.fromLTWH(x.roundToDouble(), top, tw, s.line);
        if (what == 'craft') {
          final why = _smithyWhyNot(g, row.kind);
          v
            ..at['wishCraft:$key'] = _tag(c, btn, () => _craftTap(row.kind), label, s.fs, look: why == null ? _TagLook.go : _TagLook.off)
            ..texts['wishCraft:$key'] = why?.text ?? '';
        } else {
          final type = row.type!, item = row.kind as Item, refusal = g.whyNot(item, type);
          final no = g.over ? Words.gameOver : (refusal == null ? null : g.itemRefusal(item, type, refusal));
          v
            ..at['wishGive:$key'] = _tag(c, btn, () => no == null ? _wishGive(item, type) : showMessage(no), label, s.fs,
                look: no == null ? _TagLook.go : _TagLook.off)
            ..texts['wishGive:$key'] = label
            ..texts['wishGiveWhy:$key'] = no ?? '';
        }
        x += tw + 4;
      }
    }

    // The title: the name and how many, "for Knight" where it fits whole, then the tags up here by the ✕.
    final upTo = lay.tagsUp && lay.tags.isNotEmpty ? off.left - 3 - tagsW : off.left;
    if (lay.tagsUp) tags(upTo, line1);
    final tx = left + lay.textX, nameRoom = upTo - s.iconGap - tx, y1 = line1 + s.line / 2;
    final name = '${_lootName(row.kind)} ×${row.need}', forType = switch (row.type) { final t? => 'for ${troopTypeNames[t] ?? t}', null => '' };
    final shownName = _fit(name, s.fs, nameRoom);
    _text(c, shownName, Offset(tx, y1), size: s.fs, color: ink);
    final forX = tx + _textWidth(shownName, s.fs) + s.iconGap / 2, withFor = forType.isNotEmpty && forX + _textWidth(forType, s.fs) <= tx + nameRoom;
    if (withFor) _text(c, forType, Offset(forX, y1), size: s.fs, color: grey);

    // The parts under it.
    for (final (i, (kind, words, ok)) in lay.parts.indexed) {
      final (n, x) = lay.at[i];
      final cy = line1 + (n + 0.5) * s.line, box = _whole(Rect.fromLTWH(left + x, cy - 8, 16, 16));
      kind == null ? _uiIcon(c, Board._icCoin, box) : _icon(c, kind, box);
      _text(c, words, Offset(box.right + 2, cy), size: s.fs, color: ok ? _haveInk : _blockedInk);
      if (kind != null) _wishSlot(box.inflate(1), kind); // its tooltip
    }
    // The end of the last line: the status, then the tags that had no room up there.
    final endTop = line1 + lay.endLine * s.line, statusEnd = lay.tagsUp ? right : right - tagsW - s.iconGap;
    if (!lay.tagsUp) tags(right - tagsW, endTop);
    final (forms, statusInk) = _wishStatus(g, row);
    final status = _fitFirst(forms, s.fs, statusEnd - (left + lay.endX));
    _text(c, status, Offset(statusEnd, endTop + s.line / 2), size: s.fs, color: statusInk, anchor: Anchor.centerRight);
    v
      ..at['wishRow:$key'] = r
      ..at['wishOff:$key'] = off
      ..texts['wishTitle:$key'] = withFor ? '$shownName $forType' : shownName
      ..texts['wishStatus:$key'] = status
      ..texts['wishParts:$key'] = [for (final (k, words, _) in lay.parts) '${k?.name ?? 'gold'} $words'].join(',')
      ..wishCells.add((row.type ?? _wishFree, row.kind, r));
  }

  /// The Wishlist tab's small remove tag at [line]'s right (decisions-log 303; the kit's link look, [_TagLook.link]):
  /// ui_bars.png's outline capsule (the dark one under the mouse, a sprite px lower while pressed) as tall as a tag at
  /// [fs] and a third wider ([_crossW]), ui_icons.png's small red ✕ ([_icUnwish]) in its middle. Its tap [fn] from 3 px
  /// left of it to [line]'s right, the line's height ([_hits]); returns where that is.
  Rect _crossTag(Canvas c, Rect line, VoidCallback fn, double fs) {
    final h = capsuleSize(0, fs).height, kk = capsuleK(h), cw = _crossW(fs);
    final at = _whole(Rect.fromLTWH(line.right - cw, line.center.dy - h / 2, cw, h)), hit = Rect.fromLTRB(at.left - 3, line.top, line.right, line.bottom);
    final look = _look(hit), cap = at.translate(0, look == ButtonLook.pressed ? kk : 0);
    _nine(c, look == ButtonLook.hover ? _capsuleSrc : _capsuleTrack, cap, kk, l: 1, t: 1, r: 1, b: 1, sheet: 'ui_bars.png', seam: 0);
    c.drawImageRect(_img('ui_icons.png'), _icUnwish, _whole(Rect.fromCenter(center: cap.center, width: _icUnwish.width, height: _icUnwish.height)), _px);
    _hits.add((hit, fn));
    return hit;
  }

  /// A tap on [row]'s ✕ (decisions-log 303): its wish off, a type's ([Wishlist.unwish]: "Sword: off Knight's wishlist")
  /// or the free line ([Wishlist.unwishFree]: "Sweep: off the wishlist").
  void _wishOff(WishRow row) {
    final g = state, name = _lootName(row.kind), list = Words.wishlist.toLowerCase();
    if (row.type case final type?) {
      g.unwish(type, row.kind as Item);
      return showMessage('$name: off ${troopTypeNames[type] ?? type}\'s $list');
    }
    g.unwishFree(row.kind);
    showMessage('$name: off the $list');
  }

  /// A tap on [group]'s Remove on the Wishlist tab (decisions-log 300, 303): the first arms it ("Sure?" for [_wishArmFor]
  /// s), a second while armed takes all its wishes off ([Wishlist.unwishAll], the free lines' [Wishlist.unwishFreeAll]):
  /// "Knight: wishlist cleared".
  void _wishOffAll(String group) {
    final v = _smithy, free = group == _wishFree, name = free ? Words.forBag : troopTypeNames[group] ?? group;
    if (v.wishArmed case (type: final armed, :final at) when armed == group && _clock - at < _wishArmFor) {
      v.wishArmed = null;
      free ? state.unwishFreeAll() : state.unwishAll(group);
      return showMessage('$name: ${Words.wishlist.toLowerCase()} cleared');
    }
    v.wishArmed = (type: group, at: _clock);
  }

  /// [kind]'s cell pressed at [r] as a Bag cell this frame: its tooltip, and its press and release ([_bagTap]). The Wishlist
  /// tab presses each cell to the middles of the gaps round it (its pitch: 24x24 for the 22-px cell, 48x48 for the head),
  /// so no tap between two lands on neither.
  void _wishSlot(Rect r, Enum kind) {
    switch (kind) {
      case final Item i:
        _slots.add((r, i, 0));
      case final Relic relic:
        _relicSlots.add((r, relic));
      case final Mat m:
        _matSlots.add((r, m));
    }
  }

  /// The forge's strip from [top] on [left] (decisions-log 254; forge-design §11-13, mockups 12 and 15), the Bag's
  /// segmented chips ([_chips]): Items | Relics | Enhance, the tab on lit, Enhance greyed until [Enhance.enhanceOpen]
  /// ([_smithyTabTap]). Returns where the board goes (unrounded).
  double _smithyStrips(Canvas c, Game g, Rect left, double top, double ts, double ps) {
    final v = _smithy, gap = math.max(4.0, 5.5 * ts), open = g.enhanceOpen, tabs = SmithyTab.values, tab = _smithyTab(g);
    final words = [for (final t in tabs) smithyTabNames[t]!];
    final at = _chips(c, Rect.fromLTRB(left.left, top, left.right, left.bottom), ts, ps, words,
        on: tab.index, locked: open ? -1 : SmithyTab.enhance.index, tap: (i) => _smithyTabTap(tabs[i]));
    for (final (i, t) in tabs.indexed) {
      v.at['tab:${t.name}'] = at[i];
    }
    v.texts
      ..['tabs'] = words.join('|')
      ..['locked'] = open ? '' : SmithyTab.enhance.name;
    return top + _chipsHeight(ts) + gap;
  }

  /// The facing page for [at] (a relic, the Items tab's item, the Enhance tab's stone or item at its plus) in [right],
  /// from the top: its heading ([_detailHeading]: icon, name, how many the Bag holds; an enhanced stack's tinted, its
  /// "+3" in ink), what it does, in grey a relic's "Strong relic. Best on: …", an item's grade line ([smithyGradeLine]) or
  /// on the Enhance tab its grade and steps ([_enhanceLines]), "Recipe" (on the Enhance tab "to +4" after it) and a row
  /// per line of it ([_recipeRow]; at +5 none), Craft ([_craftButton]; an item on the Enhance tab Enhance,
  /// [_enhanceButton]), the grey "No limit" line (on the Enhance tab what one does a step up) and the Equip row (an
  /// item's Give row, [_equipRow]; on the Enhance tab [_giveTypeRow], a stone none). Under its grade or tier line, while
  /// wished, the Wishlist's status ([_smithyWishStatus]), and on the Items and Relics tabs its free line ([_freeLine];
  /// decisions-log 282, 302, 303: no types' chips since 303). Under the heading they scroll where they
  /// don't all fit (decisions-log 283: the landscape book shorter), as the Army detail's body does: the wheel or a drag
  /// over them, the Bag's scroll bar down their right ([_capsuleBar]), the lines clear of it; what takes a tap or a hover
  /// is cut to the view. Nothing is left out (until then the page shed its grey line, the Wishlist's "Missing" line and
  /// the Equip row, then drew the rows closer and fewer lines above them).
  void _smithyRecipe(Canvas c, Game g, BagLoot at, Rect right, double ts, double ps) {
    const ink = Color(0xFF4A2C17), grey = Color(0xFF9E9080);
    final (kind: pick, :plus) = at;
    final v = _smithy, a = _assign, item = _smithyTab(g) == SmithyTab.enhance && pick is Item ? pick : null;
    a.detail['page'] = right;
    final head = _detailHeading(c, g, pick, right, ts, ps, plus: plus);
    final fs = math.max(10.0, 13 * ts), lineH = math.max(14.0, (fs * 1.15).roundToDouble());
    final gap = math.max(4.0, (6 * ts).roundToDouble()), rowGap = math.max(2.0, (4 * ts).roundToDouble());
    final btnH = math.max(20.0, (32 * ts).roundToDouble()), act = _actLook(ts, ps);
    final recipe = switch (pick) {
          Item() when item != null => g.enhanceRows(plus),
          final Item i => g.itemCraftRows(i),
          final Mat stone => g.stoneCraftRows(stone),
          _ => g.craftRows(pick as Relic),
        },
        n = recipe.length;
    final (effectText, tierText) = switch (pick) {
      final Item i when item != null => _enhanceLines(g, i, plus),
      final Item i => ('${g.itemEffect(i).first} for one troop type.', smithyGradeLine(g, i)),
      final Mat stone => _stoneLines(g, stone),
      _ => _relicLines(g, pick as Relic),
    };
    // Under the button: Craft's "No limit", or what an item does a step up (none at the top).
    final top = item != null && plus >= g.plusMost;
    final greys = item == null
        ? const ['No limit: craft again while you have enough', 'No limit: craft again', 'No limit']
        : [if (!top) '${g.itemEffect(item, null, plus + 1).first} at +${plus + 1}'];
    // The Wishlist (decisions-log 282, 303): while the product is wished (a type's open wish for an item, or a free line),
    // "Ready to craft" or what the Bag lacks ([_smithyWishStatus]); then on the Items and Relics tabs its free line, the
    // − n + and "Add to wishlist" ([_freeLine]; not on the Wishlist tab, which adds no wish). No types' chips and no
    // "Wishlist: Knight, Archer" (the owner: "list trops dan whitelist disini di takeout aja untuk page detail item yang mau
    // di craft"): a type's wishes go on from the Army detail.
    final wished = item == null && switch (pick) { final Item i => g.wished(i), final Relic r => g.freeWished(r), _ => false };
    final chipH = math.max(20.0, (26 * ts).roundToDouble());
    final free = _smithyTab(g) != SmithyTab.wishlist && item == null && pick is! Mat && g.canWishFree(pick);

    // A row: its icon (the action rows' [bagHeadIcon]: 16 px on a phone, 32 on the desk), a few px over and under it.
    final icon = bagHeadIcon(ps), rowH = math.max(icon + 4, (fs * 1.4 + 12 * ts).roundToDouble());
    final (noLimit, equip) = (greys.isNotEmpty, pick is! Mat);
    // No recipe (an item at +5): no "Recipe" line and no rows.
    final none = item != null && n == 0;
    double tall(List<String> effect, List<String> tier) =>
        (none
            ? (effect.length + tier.length) * lineH + gap + btnH
            : (effect.length + tier.length) * lineH + gap + lineH + n * rowH + (n - 1) * rowGap + gap + btnH) +
        (noLimit ? lineH : 0) +
        (equip ? gap + act.h : 0) +
        (wished ? gap + lineH : 0) +
        (free ? gap + chipH : 0);
    (List<String>, List<String>) wrapped(double w) =>
        (this._wrap(effectText, fs, w, ps < 2 ? bagDescLinesPhone : bagDescLines), this._wrap(tierText, fs, w, 2)); // the Bag's (bag.dart)

    // Under the heading the view (page_scroll.dart): a new pick shows its top; past its room it scrolls, its lines then
    // clear of the bar. Every line is drawn, clipped to it; what takes a tap or a hover is cut to it.
    final view = Rect.fromLTRB(right.left, head, right.right, right.bottom);
    var (effect, tier) = wrapped(right.width);
    final scrolls = tall(effect, tier) > view.height;
    final w = scrolls ? right.width - _scrollBarRoom(ts) : right.width, x1 = right.left + w;
    if (scrolls) (effect, tier) = wrapped(w);
    var (y, marks) = _scrollBegin(c, v.facing, view, tall(effect, tier), (tab: _smithyTab(g), kind: pick, plus: plus));
    for (final (lines, color, key) in [(effect, ink, 'effect'), (tier, grey, 'tier')]) {
      for (final (i, line) in lines.indexed) {
        _text(c, line, Offset(right.left, y + (i + 0.5) * lineH), size: fs, color: color);
      }
      v.texts[key] = lines.join('\n');
      y += lines.length * lineH;
    }
    if (wished) {
      y += gap;
      _smithyWishStatus(c, g, pick, Rect.fromLTWH(right.left, y, w, lineH), fs);
      y += lineH;
    }
    if (free) {
      y += gap;
      _freeLine(c, g, pick, Rect.fromLTWH(right.left, y.roundToDouble(), w, chipH), fs, at: v.at, texts: v.texts);
      y += chipH;
    }
    y += gap;
    if (!none) {
      _text(c, Words.recipe, Offset(right.left, y + lineH / 2), size: fs, color: ink, bold: true);
      var said = Words.recipe;
      if (item != null) {
        // The step it is for, smaller and grey after it: "Recipe  to +4".
        final to = 'to +${plus + 1}', small = math.max(10.0, 11 * ts), x = right.left + _textWidth(Words.recipe, fs, bold: true) + 6 * ts;
        if (x + _textWidth(to, small) <= x1) {
          _text(c, to, Offset(x, y + lineH / 2), size: small, color: grey);
          said = '${Words.recipe} $to';
        }
      }
      v
        ..at['recipe'] = Rect.fromLTWH(right.left, y, w, lineH)
        ..texts['recipe'] = said;
      y += lineH;
      for (final row in recipe) {
        _recipeRow(c, g, row, Rect.fromLTWH(right.left, y.roundToDouble(), w, rowH), icon, fs, ts);
        y += rowH + rowGap;
      }
      y += gap - rowGap;
    }
    final btn = Rect.fromLTWH(right.left, y.roundToDouble(), w, btnH);
    item == null ? _craftButton(c, g, pick, btn, ts) : _enhanceButton(c, g, item, plus, btn, ts);
    y += btnH;
    if (noLimit) {
      final said = _fitFirst(greys, fs, w), key = item == null ? 'noLimit' : 'next';
      _text(c, said, Offset(right.left + w / 2, y + lineH / 2), size: fs, color: grey, anchor: Anchor.center);
      v
        ..at[key] = Rect.fromLTWH(right.left, y, w, lineH)
        ..texts[key] = said;
      y += lineH;
    }
    if (equip) {
      final row = Rect.fromLTWH(right.left, (y + gap).roundToDouble(), w, act.h);
      item == null ? _equipRow(c, g, pick, row, act) : _giveTypeRow(c, g, item, plus, row, act);
    }
    _scrollEnd(c, v.facing, marks);
    for (final key in ['recipe', 'craft', 'enhance', 'noLimit', 'next', 'equip', 'give', 'wishlist', 'wishMissing', 'freeLess', 'freeMore', 'freeAdd']) {
      if (v.at[key] case final r?) v.at[key] = _inView(r, view);
    }
    for (final (i, r) in v.rows.indexed) {
      v.rows[i] = (kind: r.kind, at: _inView(r.at, view), count: r.count, short: r.short, from: r.from, warn: r.warn);
    }
  }

  /// A relic's lines on the facing page: what it does, and its tier and who it suits ("Strong relic. Best on: …").
  (String, String) _relicLines(Game g, Relic relic) {
    final best = g.relicBestLine(relic);
    return ('${g.relicEffect(relic).first}.', '${g.relicTierLine(relic)}.${best == null ? '' : ' $best.'}');
  }

  /// A stone's lines on the Enhance tab (decisions-log 255): the steps it is for ("One for each Enhance step to +1, +2 or
  /// +3.", town.json `enhance.stone`), and that only the Smithy makes it ([Words.madeAtSmithy]).
  (String, String) _stoneLines(Game g, Mat stone) {
    final e = g.townRules.enhance, steps = [for (final (i, m) in e.stone.indexed) if (m == stone) '+${i + 1}'];
    final to = steps.length < 2 ? steps.join() : '${steps.take(steps.length - 1).join(', ')} or ${steps.last}';
    return (steps.isEmpty ? '${Words.enhance} takes it.' : 'One for each ${Words.enhance} step to $to.', '${Words.madeAtSmithy}: no monster drops it.');
  }

  /// An item's lines on the Enhance tab (decisions-log 255; forge-design §12): what one does at +[plus] and, enhanced, at
  /// +0 ("+41.6% attack for one troop type (+32% at +0)."); in grey its grade, how many steps it took, what a step adds
  /// and up to where (town.json `enhance.per`, `enhance.most`), and that it always works.
  (String, String) _enhanceLines(Game g, Item item, int plus) {
    final now = g.itemEffect(item, null, plus).first, base = g.itemEffect(item).first.split(' ').first;
    final grade = gradeTitle(item.grade);
    final steps = plus == 0 ? '' : ', ${Words.enhanced} $plus time${plus == 1 ? '' : 's'}';
    final per = (g.townRules.enhance.per * 100).toStringAsFixed(0);
    return (
      '$now for one troop type${plus == 0 ? '' : ' ($base at +0)'}.',
      '$grade$steps. Each + adds $per% of its bonus, up to +${g.plusMost}. It always works.',
    );
  }

  /// One line of the recipe in [r] (an inset paper card: it only tells): its icon ([icon] px: Kenmi's 16-px art, or the
  /// gold's coin), its name, then in a smaller grey a material's monster ([Materials.matFrom]) or in orange what a
  /// fielded type still needs of an item ([Craft.craftItemNeed]: "Knight needs 1 for Awaken 2"), each where it fits, and
  /// on the right "have / need" (the gold's "4,450 / 1,000"), green when enough, red when short.
  void _recipeRow(Canvas c, Game g, CraftRow row, Rect r, double icon, double fs, double ts) {
    const ink = Color(0xFF4A2C17), grey = Color(0xFF9E9080);
    final (:kind, :have, :need) = row;
    final short = have < need, pad = math.max(3.0, (5 * ts).roundToDouble());
    _card(c, r, Board._framePlain);
    final box = _whole(Rect.fromLTWH(r.left + pad, r.center.dy - icon / 2, icon, icon));
    kind == null ? _uiIcon(c, Board._icCoin, box) : _icon(c, kind, box);
    final count = kind == null ? '${thousands(have)} / ${thousands(need)}' : '$have / $need', end = r.right - pad;
    _text(c, count, Offset(end, r.center.dy), size: fs, color: short ? _blockedInk : _haveInk, anchor: Anchor.centerRight);
    final x = box.right + 6 * ts, room = end - _textWidth(count, fs) - 6 * ts;
    final name = _fit(switch (kind) { final Mat m => m.label, final Item i => itemNames[i]!, _ => 'Gold' }, fs, room - x);
    _text(c, name, Offset(x, r.center.dy), size: fs, color: ink);
    final small = math.max(10.0, 11 * ts), after = x + _textWidth(name, fs) + 6 * ts;
    var (from, warn) = ('', '');
    if (kind is Mat) {
      final who = kind.crafted ? Words.smithy : g.matFrom(kind); // a stone: made at the Smithy (decisions-log 255)
      if (who.isNotEmpty && _textWidth(who, small) <= room - after) from = who;
      if (from.isNotEmpty) _text(c, from, Offset(after, r.center.dy), size: small, color: grey);
    } else if (kind is Item) {
      if (g.craftItemNeed(kind) case (:final type, need: final more, :final level)) {
        final who = troopTypeNames[type] ?? type;
        warn = _fitFirst(['$who needs $more for ${awakenName(level)}', '$who needs $more', '$who: $more'], small, room - after);
        _text(c, warn, Offset(after, r.center.dy), size: small, color: _warnInk);
      }
    }
    _smithy.rows.add((kind: kind, at: r, count: count, short: short, from: from, warn: warn));
  }

  /// Why the Smithy won't craft [kind] now (an item's [Craft.whyNotCraftItem], a stone's [Enhance.whyNotCraftStone], a
  /// relic's [Craft.whyNotCraft]), or null.
  CraftRefusal? _smithyWhyNot(Game g, Enum kind) => switch (kind) {
        final Item item => g.whyNotCraftItem(item),
        final Mat stone => g.whyNotCraftStone(stone),
        _ => g.whyNotCraft(kind as Relic),
      };

  /// Craft in [r], the page's one bevelled button (its main standalone action; the owner's button rule): the green one,
  /// "Craft (1,000 gold)", while [kind] (a relic, an item) can be crafted ([_smithyWhyNot]); else the white one with why
  /// ("Need 2 more Iron Scrap", "Need 1 Leather Cap"). A press crafts it ([_craftTap]) or says why again.
  void _craftButton(Canvas c, Game g, Enum kind, Rect r, double ts) {
    final gold =
        switch (kind) { final Item item => g.itemRecipe(item)?.gold, final Mat stone => g.stoneRecipe(stone)?.gold, _ => g.craftRecipe(kind as Relic)?.gold } ?? 0;
    final why = _smithyWhyNot(g, kind), fs = math.max(10.0, 14 * ts), room = r.width - 12 * ts;
    final label = why == null
        ? _fitFirst(['${Words.craft} (${thousands(gold)} gold)', '${Words.craft} (${shortPrice(gold)})', Words.craft], fs, room)
        : _fit(why.text, fs, room);
    _button(c, r, () => _craftTap(kind), label: label, size: fs, enabled: why == null, row: Board._btnGreen);
    if (why != null) _hits.add((r, () => _craftTap(kind))); // the white one's press says why again
    _smithy
      ..at['craft'] = r
      ..texts['craft'] = label;
  }

  /// A press on Craft for [kind]: one into the Bag ([Craft.craft], an item's [Craft.craftItem]) and the message window
  /// says so ([craftedLine]: "Sweep crafted!", "Steel Sword crafted!"). Refused: the error and why ([CraftRefusal.text]).
  void _craftTap(Enum kind) {
    final g = state;
    bool make() => switch (kind) { final Item item => g.craftItem(item), final Mat stone => g.craftStone(stone), _ => g.craft(kind as Relic) };
    if (_smithyWhyNot(g, kind) case final why?) {
      make(); // the error
      return showMessage(why.text);
    }
    if (make()) showMessage(kind is Relic ? craftedLine(kind) : '${_lootName(kind)} ${Words.crafted}!');
  }

  /// A relic's "Equip on a troop" ([BagAction.equip]), an item's "Give to troops" ([BagAction.giveTroops]), in [r] (the
  /// Bag's action row look, [m]): the troops' crossed swords, its title, how many the Bag holds and that it opens the Bag
  /// ("1 in Bag. Opens the Bag"), the green "›"; the whole row a tap (lit under the mouse) that turns the book to the
  /// Bag with [kind] picked and its chooser open, its troops (an item's types: where a full Cap or Ring swaps out its
  /// lowest, decisions-log 249) listed ([Board._openBag]). None in the Bag (or the game over): greyed with why in red,
  /// and a tap says it. An item on the Wishlist (decisions-log 282): its line names the types that wish for it ("1 in Bag.
  /// For Knight"), and the chooser opens on them (its filter's chips, [_AssignList.filter]: All shows the rest).
  void _equipRow(Canvas c, Game g, Enum kind, Rect r, _ActLook m) {
    final act = kind is Item ? BagAction.giveTroops : BagAction.equip;
    final a = _assign, n = g.inBag(kind), why = g.over ? Words.gameOver : (n == 0 ? 'Craft one first' : null);
    a.list = r; // the row's look and tap are the Bag's action rows' (bag.dart)
    final (:x, :y1, :y2) = _actCard(c, act, r, m, why == null, (box, paint) => _uiIcon(c, Board._icSwords, box, paint), lit: true);
    final k = math.max(1.0, (m.titleFs / 10).roundToDouble()), w = _icOpen.width * k, h = _icOpen.height * k;
    final open = _whole(Rect.fromLTWH(r.right - m.inset - m.ts - w, r.center.dy - h / 2, w, h));
    c.drawImageRect(_img('ui_icons.png'), why == null ? _icOpen : _icThen, open, why == null ? _px : _ghost);
    final end = open.left - 6 * m.ts, held = '$n in ${Words.bag}';
    final wishers = kind is Item ? g.openWishersOf(kind) : const <String>[], names = [for (final t in wishers) troopTypeNames[t] ?? t];
    if (kind is Item && wishers.length == 1) {
      // One type's open wish (decisions-log 300): "Give to Knight", one tap, the book stays on the Smithy.
      final type = wishers.first, refusal = g.whyNot(kind, type);
      final (have, need) = g.wishCount(type, kind)!;
      final no = why ?? (refusal == null ? null : g.itemRefusal(kind, type, refusal));
      _actTitle(c, act, '${Words.give} to ${names.first}', x, y1, end, m, no == null, cut: true);
      _actLine(c, act, no, '$held. ${names.first} $have/$need', x, y2, end, m, shorter: [held]);
      a.rows.add((r, act, no == null, () => no == null ? _wishGive(kind, type) : showMessage(no)));
      _smithy.at['give'] = r;
      return;
    }
    _actTitle(c, act, _actTitleOf(g, kind, act), x, y1, end, m, why == null, cut: true);
    _actLine(c, act, why, wishers.isEmpty ? '$held. Opens the ${Words.bag}' : '$held. For ${names.join(', ')}', x, y2, end, m,
        shorter: [if (wishers.isNotEmpty) '$held. For ${names.first}${names.length > 1 ? ' +${names.length - 1}' : ''}', held]);
    void give() {
      _openBag(pick: kind, act: act);
      // The wished types first, as the chooser's filter (all of them is All).
      if (wishers.isNotEmpty && wishers.length < troopTypes.length) {
        _assign.filter
          ..clear()
          ..addAll(wishers);
      }
    }

    a.rows.add((r, act, why == null, () => why == null ? give() : showMessage(why)));
    _smithy.at[kind is Item ? 'give' : 'equip'] = r;
  }

  /// The Give row's one tap for [item] to the one [type] whose wish is open (decisions-log 300): one from the Bag onto the
  /// type ([Board._useItem]; refused, it says why), and the message window says how far the wish is ("Sword given to
  /// Knight (2/3)"), or the Awaken it brought ("Knight: Awaken 2!").
  void _wishGive(Item item, String type) {
    final g = state, was = g.awakenLevel(type);
    if (!_useItem(item, type)) return;
    final name = troopTypeNames[type] ?? type, level = g.awakenLevel(type);
    showMessage(level > was
        ? '$name: ${awakenName(level)}!'
        : switch (g.wishCount(type, item)) {
            (final have, final need) => '${itemNames[item]} given to $name ($have/$need)',
            null => '${itemNames[item]} given to $name',
          });
  }

  /// Enhance in [r] (decisions-log 255), the Enhance tab's one bevelled button: the green one, "Enhance to +4 (2,500 gold)"
  /// ("Enhance to +4 (2.5k)", "Enhance to +4" where it doesn't fit), while [item] at +[plus] can go a step up
  /// ([Enhance.whyNotEnhance]); else the white one with why ("Need 1 Starmetal", "Max: +5"). A press takes it up
  /// ([_enhanceTap]) or says why again.
  void _enhanceButton(Canvas c, Game g, Item item, int plus, Rect r, double ts) {
    final why = g.whyNotEnhance(item, plus), fs = math.max(10.0, 14 * ts), room = r.width - 12 * ts, to = '${Words.enhance} to +${plus + 1}';
    final gold = g.enhanceCost(plus)?.gold ?? 0;
    final label = why == null ? _fitFirst(['$to (${thousands(gold)} gold)', '$to (${shortPrice(gold)})', to, Words.enhance], fs, room) : _fit(why.text, fs, room);
    _button(c, r, () => _enhanceTap(item, plus), label: label, size: fs, enabled: why == null, row: Board._btnGreen);
    if (why != null) _hits.add((r, () => _enhanceTap(item, plus))); // the white one's press says why again
    _smithy
      ..at['enhance'] = r
      ..texts['enhance'] = label;
  }

  /// A press on Enhance for [item] at +[plus]: one goes a step up ([Enhance.enhance]), the page follows it to its new
  /// stack, and the message window says so ("Royal Sword enhanced to +4!"). Refused: the error and why.
  void _enhanceTap(Item item, int plus) {
    final g = state;
    if (g.whyNotEnhance(item, plus) case final why?) {
      g.enhance(item, plus); // the error
      return showMessage(why.text);
    }
    if (!g.enhance(item, plus)) return;
    _smithy.enhancePick = (kind: item, plus: plus + 1);
    showMessage('${itemNames[item]} ${Words.enhanced} to +${plus + 1}!');
  }

  /// The Enhance tab's "Give to a type" ([BagAction.giveTroops]) in [r] (the Bag's action row look, [m]; decisions-log
  /// 255): the troops' crossed swords, its title, the first fielded type where it would take the place of a lower one at
  /// the cap ("Knight: in place of its +0", [Game.swapOut]) or else how many the Bag holds and that it opens the Bag, the
  /// green "›"; the whole row a tap that turns the book to the Bag with [item]'s stack at +[plus] picked and its types
  /// listed ([Board._openBag]). None left (or the game over): greyed with why in red, and a tap says it.
  void _giveTypeRow(Canvas c, Game g, Item item, int plus, Rect r, _ActLook m) {
    const act = BagAction.giveTroops;
    final a = _assign, n = g.bagOf(item, plus), why = g.over ? Words.gameOver : (n == 0 ? 'None left' : null);
    a.list = r; // the row's look and tap are the Bag's action rows' (bag.dart)
    final (:x, :y1, :y2) = _actCard(c, act, r, m, why == null, (box, paint) => _uiIcon(c, Board._icSwords, box, paint), lit: true);
    final k = math.max(1.0, (m.titleFs / 10).roundToDouble()), w = _icOpen.width * k, h = _icOpen.height * k;
    final open = _whole(Rect.fromLTWH(r.right - m.inset - m.ts - w, r.center.dy - h / 2, w, h));
    c.drawImageRect(_img('ui_icons.png'), why == null ? _icOpen : _icThen, open, why == null ? _px : _ghost);
    final end = open.left - 6 * m.ts, held = '$n in ${Words.bag}', title = '${Words.give} to a type';
    // Where it swaps: the first living type (in the army's order) that takes it in place of a lower one.
    final fielded = {for (final u in g.troops) if (u.alive) u.type};
    final swap = [
      for (final type in troopTypes.keys)
        if (fielded.contains(type) && g.canUse(item, type, plus: plus))
          if (g.swapOut(type, item, plus) case final out?)
            '${troopTypeNames[type] ?? type}: in place of its ${out == item ? '+${g.plusesOn(type, out).last}' : itemLabel(out, g.plusesOn(type, out).last)}',
    ].firstOrNull;
    _actTitle(c, act, title, x, y1, end, m, why == null, cut: true);
    _actLine(c, act, why, swap ?? '$held. Opens the ${Words.bag}', x, y2, end, m, shorter: [if (swap != null) '$held. Opens the ${Words.bag}', held]);
    a.rows.add((r, act, why == null, () => why == null ? _openBag(pick: item, plus: plus, act: act) : showMessage(why)));
    _smithy
      ..at['give'] = r
      ..texts['give'] = a.texts['hint:${act.name}'] ?? '';
  }
}
