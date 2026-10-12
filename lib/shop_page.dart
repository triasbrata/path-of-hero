part of 'main.dart';

// The Town's Shop pages (decisions-log 230 and 269; docs/ui-hud.md "The Town's Shop"; the rules: store.dart's [Store],
// loot-items-relics.md "The store"), the book's Shop tab in a Town, on the Bag's own code (bag.dart). The owner,
// 2026-10-08: "tabnya di bagi jadi 2 untuk ui shop ada ui untuk Buy dan sell. nah nanti untuk buy bisa dibuat terpisah
// antara item dan relic ... dan untuk di sold bisa langsung di gabung aja semua yang mau di jual, mirip seperti ui dari
// bags, tapi yang berbeda pada halaman halaman detailnya menampilkan jumlah item yang mau user jual, beserta totalan item
// lain yang di jual dan berapa gold yang akan di dapat user"; and then: "harusnya semua barang yang ada di bags bisa di
// jual kecuali masi di pakai sama trops, bahkan item artefak atau relic juga bisa di jual. dan pada bagian detail page ...
// bukan menampilkan seperti ketika item di akses di tab bag, melainkan ini adalah page baru yang harus kamu buat".
//
// The left page: "Shop", the Bag's segmented paper strip Buy | Sell ([ShopTab]; the Bag's and the Smithy's look, light
// controls), opening on Buy. Buy's board is a section per kind of goods ([shopBuySections]: Items, Relics, the store's
// Artifacts while their shelf is open, with the forge Materials), each its heading over the board's left edge as the
// Smithy's "Materials" ([Board._gridHead]; the owner: "uinya shop ketika buy mirip seperti smithy materials cuma text
// materialsnya di sejajarkan dengan posisi box yang paling kiri biar paddingnya tetap sama") and its cells as the Bag's
// slots, each its buy price in its capsule; a section the shelf has none of is left out, the next moving up (decisions-log
// 280, the owner: "ini di takeout saja kalau productnya tidak ada"), and with none at all one muted line says so. The
// facing page of a Buy pick is the Bag's with the Buy row ([Board._shopActions]). Sell's board is one grid of everything
// in the Bag that no troop or type is using, in the Bag's order ([shopSellLoot]): every item stack, small relic, material
// and Vault Artifact. A tap on a cell puts it in the sell basket at 1 ([_ShopView.basket]) and picks it. The facing page
// is a page of its own, the Sell Basket ([Board._shopSellPage]; reworked in decisions-log 278, the owner: "<section detail
// item> <space> <harga> * <+ jumlah - > = <sub total harga item> <----divider---> <list item yang mau dijual> <total coin
// yand didapat> <btn sell>"): the pick's detail, its price row "1500 x [-] 2 [+] [All] = 3000", the basket's lines (the
// book's printed line between them until decisions-log 305), and at the bottom one bevelled Sell for the whole basket,
// the gold it brings on it with the coin (decisions-log 306; the total left of it until then).

/// The Town's Shop's tabs (decisions-log 269), its strip's segments in order.
enum ShopTab { buy, sell }

/// The strip's words, in [ShopTab] order.
const shopTabNames = {ShopTab.buy: Words.buy, ShopTab.sell: Words.sell};

/// The Sell page's words (decisions-log 269 and 278): what its top says while the basket is empty, and the Sell grid's
/// empty card.
const shopTapToAdd = 'Tap items on the left to sell them.', shopNothingToSell = 'Nothing to sell yet.';

/// The Buy page's one muted line while the shelf has nothing at all (decisions-log 280), in place of its sections.
const shopNothingToBuy = 'Nothing to buy here yet.';

/// The most lines the Sell Basket page's detail gives a pick under its name (decisions-log 278): its kind line and what it
/// does ([Board._shopSellDetail]); the band is this tall whatever is picked, so the price row and the lines never move.
const shopDetailLines = 3;

/// Buy's sections, in their order on the page (decisions-log 269; the owner's "item [][][] relic [][][]"), by the Bag's
/// categories ([bagCategoryNames] their headings).
const shopBuyOrder = [BagCategory.items, BagCategory.relics, BagCategory.artifacts, BagCategory.materials];

/// What the shelf sells under Buy's [section] ([onShopShelf]), in its order: the store's Artifacts while their shelf is
/// open, and the forge's Shop's (decisions-log 248) materials that have dropped, in the order they first did
/// ([Game.matsSeen]), never an item or a small relic.
/// [BagCategory.all]: every section's, in order.
List<Enum> shopBuyKinds(Game g, BagCategory section) => switch (section) {
      BagCategory.items => [for (final i in droppedItems) if (onShopShelf(g, i)) i],
      BagCategory.relics => [for (final r in g.relicsInPlay) if (onShopShelf(g, r)) r],
      BagCategory.artifacts => [for (final k in storeGoods) if (k is Relic && k.pusaka && onShopShelf(g, k)) k],
      BagCategory.materials => [for (final m in g.matsSeen) if (onShopShelf(g, m)) m],
      BagCategory.all => [for (final s in shopBuyOrder) ...shopBuyKinds(g, s)],
    };

/// Buy's sections on the page now (decisions-log 280; the owner, 2026-10-08: "ini di takeout saja kalau productnya tidak
/// ada"): each of [shopBuyOrder] the shelf has some of, so a section with nothing to buy takes no room and the next moves
/// up. With the forge's Shop the items and small relics are made at the Smithy (decisions-log 248): Materials once one has
/// dropped, and the store's Artifacts while their shelf is open. None: the page says [shopNothingToBuy].
List<BagCategory> shopBuySections(Game g) => [for (final s in shopBuyOrder) if (shopBuyKinds(g, s).isNotEmpty) s];

/// Buy's cells, every section's in order ([shopBuyKinds]); never an enhanced stack.
List<BagLoot> shopBuyLoot(Game g) => [for (final k in shopBuyKinds(g, BagCategory.all)) (kind: k, plus: 0)];

/// Sell's cells (decisions-log 269; the owner: "semua barang yang ada di bags bisa di jual kecuali masi di pakai sama
/// trops"): everything in the Bag that no troop or type is using, in the Bag's order ([bagLoot]): the items, each enhanced
/// stack after its item (decisions-log 255), the small relics, the materials, and the Artifacts waiting in the Vault (a
/// bound one is in use, and an oath always is: [Store.inBag]). An item given to a type or a relic worn is not in the Bag.
List<BagLoot> shopSellLoot(Game g) => [for (final l in bagLoot(g, BagCategory.all)) if (shopHeld(g, l) > 0) l];

/// How many of [loot] the Shop can buy from the Bag: an item's at its plus ([Enhance.bagOf]), else [Store.inBag] (a
/// Pusaka 1 while it waits in the Vault).
int shopHeld(Game g, BagLoot loot) => switch (loot.kind) { final Item i => g.bagOf(i, loot.plus), final kind => g.inBag(kind) };

/// What one [loot] sells for: [Enhance.sellPriceAt] at its plus, else [Store.sellPrice] (a Vault Artifact half its base
/// price, its stars lost: decisions-log 151).
int shopSellPrice(Game g, BagLoot loot) => switch (loot.kind) { final Item i => g.sellPriceAt(i, loot.plus), final kind => g.sellPrice(kind) };

/// The basket kept true to the Bag: a stack held no more leaves it, a count over what is held comes down to it.
void shopBasketFit(Game g, Map<BagLoot, int> basket) {
  for (final loot in [...basket.keys]) {
    final held = shopHeld(g, loot);
    if (held <= 0) {
      basket.remove(loot);
    } else if (basket[loot]! > held) {
      basket[loot] = held;
    }
  }
}

/// What [n] of [loot] sell for together: the Smithy's goods each piece at its own step of the market ([Market.marketSum],
/// decisions-log 326), the rest [n] times [shopSellPrice].
int shopSubtotal(Game g, BagLoot loot, int n) =>
    g.marketed(loot.kind) ? g.marketSum(loot.kind, loot.plus, n) : n * shopSellPrice(g, loot);

/// How many pieces [basket] holds, and the gold they sell for ([shopSubtotal] a stack).
int shopBasketPieces(Map<BagLoot, int> basket) => basket.values.fold(0, (n, v) => n + v);
int shopBasketGold(Game g, Map<BagLoot, int> basket) => [for (final MapEntry(key: l, value: n) in basket.entries) shopSubtotal(g, l, n)].fold(0, (s, v) => s + v);

/// Sells every stack in [basket] at its count ([Store.sell], an item's at its plus [Enhance.sellAt]), in its order: the
/// pieces sold and the gold they brought. The rules are the Shop's own; the basket only adds them up.
({int pieces, int gold}) shopSellBasket(Game g, Map<BagLoot, int> basket) {
  var pieces = 0;
  final before = g.gold;
  for (final MapEntry(key: loot, value: n) in basket.entries) {
    pieces += switch (loot.kind) { final Item i => g.sellAt(i, loot.plus, n), final kind => g.sell(kind, n) };
  }
  return (pieces: pieces, gold: g.gold - before);
}

/// The Town's Shop's pages between frames.
class _ShopView {
  ShopTab tab = ShopTab.buy; // the strip's tab on: Buy each time the Shop opens ([leave])
  final buy = _BagGrid(shop: true); // Buy's board: its sections' cells, page and pager
  final sell = _BagGrid(shop: true, sell: true); // Sell's grid
  // The sell basket (decisions-log 269): each stack set to sell and how many, in the order set. Nothing sells until its
  // Sell is pressed; leaving the Shop, the Town or the game empties it, and a new Town or game opens on Buy ([game],
  // [townAt]).
  final basket = <BagLoot, int>{};
  BagLoot? sellTurned; // the pick the Sell grid last turned its page to ([Board._shopPages])
  Game? game;
  int? townAt;
  // This frame, for tests: the strip's segments, Buy's section headings (where their words are), where each part of the
  // pages is by key (Buy's 'nothing', its line with nothing on the shelf, decisions-log 280; the Sell Basket page's,
  // decisions-log 278: 'detail' its top band, there 'kind', 'desc' or with the basket empty 'empty'; the price row
  // 'price', its 'unit', 'minus', 'count', 'plus', 'all' and 'subtotal'; 'lines'; the bottom bar's 'sell' and the coin on
  // it 'sellCoin', decisions-log 306) and its words ('nothing', 'kind', 'lost', 'desc', 'empty', 'price' as "1500 x 2 =
  // 3000", 'count', 'subtotal', 'sell' as "Sell 3000", the coin between), and the basket's lines as drawn (each its "2 x
  // 1500 = 3000").
  final tabs = <ShopTab, Rect>{};
  final heads = <(BagCategory, Rect)>[];
  final at = <String, Rect>{};
  final texts = <String, String>{};
  final lines = <(BagLoot, Rect, String)>[];
  final arrows = <BagLoot, (MarketWord, Rect)>{}; // the Sell grid's market arrows drawn (decisions-log 326)

  /// The tab's grid.
  _BagGrid get grid => tab == ShopTab.buy ? buy : sell;

  /// The book turned away from the Shop ([Board._open]): it opens on Buy again, the basket empty.
  void leave() {
    tab = ShopTab.buy;
    basket.clear();
  }

  void clear() {
    buy.clear();
    sell.clear();
    tabs.clear();
    heads.clear();
    at.clear();
    texts.clear();
    lines.clear();
  }
}

extension on Board {
  /// The Town's Shop pages (decisions-log 230 and 269): on [left] "Shop", the strip Buy | Sell ([_chips]) and the tab's
  /// board (Buy's sections, [_shopBuyBoard]; Sell's grid, [_bagBoard]); on [right] a Buy pick's facing page
  /// ([_assignPage]: the Buy row; nothing picked, the book's blank paper, decisions-log 248) or the Sell Basket page
  /// ([_shopSellPage]). A pick sold out, or no longer on the tab's board, goes. [ts] is the page's text scale, [ps] the
  /// book's pixel scale.
  void _shopPages(Canvas c, Game g, Rect left, Rect right, double ts, double ps) {
    const ink = Color(0xFF4A2C17);
    final v = _shop;
    if (!identical(v.game, g) || v.townAt != g.townAt || !g.inTown) {
      // Another game or another Town: the Shop on Buy, nothing picked, its basket empty.
      _storePickAt = null;
      v
        ..tab = ShopTab.buy
        ..basket.clear()
        ..game = g
        ..townAt = g.townAt;
    }
    shopBasketFit(g, v.basket);
    _text(c, Words.shop, Offset(left.center.dx, _titleY(left, ts)), size: 22 * ts, color: ink, anchor: Anchor.center, bold: true);
    final top = _underTitle(left, ts), tabs = ShopTab.values;
    final at = _chips(c, Rect.fromLTRB(left.left, top, left.right, left.bottom), ts, ps, [for (final t in tabs) shopTabNames[t]!],
        on: v.tab.index, tap: (i) => _shopTabTap(tabs[i]));
    for (final (i, t) in tabs.indexed) {
      v.tabs[t] = at[i];
    }
    final area = Rect.fromLTRB(left.left, top + _chipsHeight(ts) + math.max(4.0, 5.5 * ts), left.right, left.bottom);
    // A pick sold out goes, as the Bag's does; on Sell the pick is always a line of the basket, the last added while none
    // is picked (decisions-log 278: the page's top shows it).
    if (_storePickAt case final held? when !_gridLoot(g, v.grid, BagCategory.all).contains(held) || v.tab == ShopTab.sell && !v.basket.containsKey(held)) {
      _storePickAt = null;
    }
    if (v.tab == ShopTab.sell && _storePickAt == null && v.basket.isNotEmpty) _storePickAt = v.basket.keys.last;
    final pick = _storePickAt;
    if (v.tab == ShopTab.buy) {
      _shopBuyBoard(c, g, area, pick, ts, ps);
      return _assignPage(c, g, pick, right, ts, ps, null);
    }
    // The Sell grid turns to the pick's page when the pick changes (a line tapped) and is the player's to turn after: on
    // Sell there is always a pick while the basket has lines (decisions-log 278), and following it every frame would hold
    // the grid on its page.
    final turnTo = pick == v.sellTurned ? null : pick;
    v.sellTurned = pick;
    _bagBoard(c, g, area, turnTo, ts, ps);
    _shopSellArrows(c, g);
    _shopSellPage(c, g, pick, right, ts, ps);
  }

  /// A tap on [tab]'s segment: the board shows it; the pick goes back and every armed button lets go ([_bagLetGo]). The
  /// basket stays.
  void _shopTabTap(ShopTab tab) {
    final v = _shop;
    if (tab == v.tab) return;
    v.tab = tab;
    _storePickAt = null;
    _bagLetGo();
    _assign.scroll = 0;
  }

  /// Buy's board in [area] (decisions-log 269 and 280; its top unrounded, as [_bagBoard]'s): a section per
  /// [shopBuySections] (only those the shelf has some of) on the board in sections ([_sections]): its heading over the
  /// board's left edge ([_gridHead]), then its cells as the Bag's slots (each its buy price); where they don't all fit,
  /// the Bag's pager turns pages. The page turns to [held] (the pick). With nothing on the shelf at all, one muted line
  /// ([shopNothingToBuy]) at the board's top from its leftmost slot's edge, where a heading would start.
  void _shopBuyBoard(Canvas c, Game g, Rect area, BagLoot? held, double ts, double ps) {
    const grey = Color(0xFF9E9080);
    final v = _shop, cats = shopBuySections(g);
    final secs = [for (final s in cats) (title: bagCategoryNames[s]!, loot: [for (final k in shopBuyKinds(g, s)) (kind: k, plus: 0)], note: '')];
    final (:heads, notes: _, height: _) = _sections(c, g, area, v.buy, secs, held, ts, ps);
    v.heads.addAll([for (final (i, r) in heads) (cats[i], r)]);
    if (cats.isNotEmpty) return;
    final fs = math.max(10.0, 13 * ts), lineH = (fs * 1.4).roundToDouble(), span = _gridSpan(area, ps, small: v.buy.small);
    final shown = this._wrap(shopNothingToBuy, fs, span.width, 2), top = area.top.roundToDouble();
    for (final (i, line) in shown.indexed) {
      _text(c, line, Offset(span.left, top + (i + 0.5) * lineH), size: fs, color: grey);
    }
    v
      ..at['nothing'] = Rect.fromLTWH(span.left, top, shown.map((l) => _textWidth(l, fs)).fold(0.0, math.max), shown.length * lineH)
      ..texts['nothing'] = shown.join(' ');
  }

  /// A tap on Sell's cell [loot] (decisions-log 269 and 278): it goes in the basket at 1 if it wasn't in, and is picked,
  /// so the Sell Basket page's top shows it; one already in is only picked, its count kept.
  void _shopSellTap(BagLoot loot) {
    _storePickAt = loot;
    _shop.basket.putIfAbsent(loot, () => 1);
  }

  /// Sets [loot]'s count in the basket to [n], kept to what is held; at 0 its line leaves (and, picked, the pick: the
  /// page's top then shows the last line, [_shopPages]).
  void _shopSetCount(BagLoot loot, int n) {
    final to = n.clamp(0, shopHeld(state, loot));
    if (to > 0) {
      _shop.basket[loot] = to;
      return;
    }
    _shop.basket.remove(loot);
    if (_storePickAt == loot) _storePickAt = null;
  }

  /// The Sell Basket page in [right] (decisions-log 269 and 278; the owner, 2026-10-08: "`<section detail item>`
  /// `<space>` `<harga>` * `<+ jumlah - >` = `<sub total harga item>` `<----divider--->` `<list item yang mau dijual>`
  /// `<total coin yand didapat>` `<btn sell>`"), top to bottom:
  /// - the pick's detail ([_shopSellDetail]: its heading as the Bag's, its kind line and what it does), or with the basket
  ///   empty what to do ([shopTapToAdd]); a band of a fixed height, so nothing under it moves with the pick;
  /// - the pick's price row ([_shopPriceRow]), indented to the detail's words (the owner's "`<space>`"): "1500 x [-] 2 [+]
  ///   [All] = 3000";
  /// - the basket's lines in the order added ([_shopLine]), the pick's lit; scrolled by the wheel or a drag where they don't
  ///   all fit, the pick brought into view when it changes; a tap on one picks it. No divider over them (decisions-log
  ///   305; the owner, 2026-10-09: "divider di sini di takeout"): the book's printed line and its air went, their room to
  ///   the lines;
  /// - the bottom bar ([_shopSellBar]): Sell with the gold the basket brings.
  void _shopSellPage(Canvas c, Game g, BagLoot? pick, Rect right, double ts, double ps) {
    const grey = Color(0xFF9E9080);
    final a = _assign, v = _shop, fs = math.max(10.0, 13 * ts), lineH = math.max(14.0, (fs * 1.15).roundToDouble());
    final gap = math.max(3.0, (4 * ts).roundToDouble()), top = right.top.roundToDouble(), x0 = right.left.roundToDouble(), x1 = right.right.roundToDouble();
    a.detail['page'] = right;

    // The fixed parts: the detail's band and the price row's; at the bottom the bar; the lines between, as far from the
    // price row as from the bar.
    final detail = Rect.fromLTRB(x0, top, x1, top + (42 * ts).roundToDouble() + shopDetailLines * lineH);
    final row = Rect.fromLTWH(x0, detail.bottom + gap, x1 - x0, math.max(lineH + 4, (fs * 1.9).roundToDouble()));
    final barH = math.max(20.0, (32 * ts).roundToDouble()), bar = Rect.fromLTRB(x0, (right.bottom - barH).roundToDouble(), x1, right.bottom.roundToDouble());
    final list = Rect.fromLTRB(x0, row.bottom + 2 * gap, x1, bar.top - 2 * gap);
    final pad = _shopLinePad(ps); // a line's padding: the price row's subtotal ends where the lines' do

    // 1, 2. The pick and its price row; nothing in the basket, what to do (with lines in it, there is always a pick).
    if (pick != null && v.basket[pick] != null) {
      final indent = _shopSellDetail(c, g, pick, detail, fs, lineH, ts, ps);
      _shopPriceRow(c, g, pick, v.basket[pick]!, Rect.fromLTRB(indent, row.top, x1 - pad, row.bottom), fs, ts);
    } else {
      final hint = this._wrap(shopTapToAdd, fs, detail.width, 2), y = (top + 24 * ts - lineH / 2).roundToDouble();
      for (final (i, line) in hint.indexed) {
        _text(c, line, Offset(x0, y + (i + 0.5) * lineH), size: fs, color: grey);
      }
      v
        ..at['empty'] = Rect.fromLTWH(x0, y, hint.fold(0.0, (w, l) => math.max(w, _textWidth(l, fs))), hint.length * lineH)
        ..texts['empty'] = shopTapToAdd;
    }
    v.at['detail'] = detail;

    // 3. The basket's lines.
    final keys = [...v.basket.keys], lineRowH = _shopLineHeight(ps), lineGap = math.max(2.0, (3 * ts).roundToDouble());
    final content = keys.isEmpty ? 0.0 : keys.length * (lineRowH + lineGap) - lineGap, scrolls = content > list.height;
    if (a.shownFor != pick) {
      // Another pick: its line comes into view.
      a.shownFor = pick;
      final i = pick == null ? -1 : keys.indexOf(pick);
      if (i >= 0) {
        final at = i * (lineRowH + lineGap);
        if (at < a.scroll) a.scroll = at;
        if (at + lineRowH > a.scroll + list.height) a.scroll = at + lineRowH - list.height;
      }
    }
    a
      ..list = list
      ..scroll = a.scroll.clamp(0.0, math.max(0.0, content - list.height));
    c.save();
    c.clipRect(list);
    for (final (i, loot) in keys.indexed) {
      final r = Rect.fromLTWH(list.left, (list.top + i * (lineRowH + lineGap) - a.scroll).roundToDouble(),
          list.width - (scrolls ? _capsuleBarW + 2 * ts : 0), lineRowH);
      if (r.bottom <= list.top || r.top >= list.bottom) continue;
      _shopLine(c, g, loot, v.basket[loot]!, r, fs, ts, ps, loot == pick);
    }
    c.restore();
    if (scrolls) _capsuleBar(c, list, content, a.scroll);
    v.at['lines'] = list;

    // 4. Sell, with the total on it.
    _shopSellBar(c, g, bar, ts);
  }

  /// The top of the Sell Basket page in [area] (decisions-log 278): [pick]'s heading as the Bag's facing page shows it
  /// ([_detailHeading]: its icon, its name with an enhanced stack's "+3", how many the Bag holds or a Pusaka's stars),
  /// and under the name, beside the icon, [shopDetailLines] lines at most: its kind line ([_shopKindLine]: an item's
  /// grade, a small relic's tier, an Artifact's rarity and where it is), a carved Artifact's "Carve +3 is lost" in red,
  /// then what it does ([Board._detailDesc]; without its closing sentence where all of it doesn't fit, the last line cut
  /// to fit). [fs] is the words' size, [lineH] a line's height. Returns the words' left edge, the price row's indent.
  double _shopSellDetail(Canvas c, Game g, BagLoot pick, Rect area, double fs, double lineH, double ts, double ps) {
    const ink = Color(0xFF4A2C17);
    final (:kind, :plus) = pick;
    final v = _shop;
    var y = _detailHeading(c, g, kind, area, ts, ps, plus: plus);
    final x = _assign.detail['name']!.left.roundToDouble(), w = area.right - x, said = <String>[];

    // The kind line, its parts one after another, the last cut to the room left.
    final parts = _shopKindLine(g, kind, plus);
    if (parts.isNotEmpty) {
      var at = x;
      final shown = StringBuffer();
      for (final (i, (text, color)) in parts.indexed) {
        final t = i == parts.length - 1 ? _fit(text, fs, area.right - at) : text;
        _text(c, t, Offset(at, y + lineH / 2), size: fs, color: color);
        at += _textWidth(t, fs);
        shown.write(t);
      }
      v
        ..at['kind'] = Rect.fromLTRB(x, y, at, y + lineH)
        ..texts['kind'] = '$shown';
      said.add('$shown');
      y += lineH;
    }
    final carved = kind is Relic ? g.pusaka[kind]?.ukir ?? 0 : 0;
    if (carved > 0) {
      final lost = _fit('${Words.carve} +$carved is lost', fs, w);
      _text(c, lost, Offset(x, y + lineH / 2), size: fs, color: _blockedInk);
      v.texts['lost'] = lost;
      said.add(lost);
      y += lineH;
    }

    // What it does: all of it where it fits, else without its closing sentence, cut to the lines left.
    final room = shopDetailLines - said.length;
    var desc = this._wrap(_detailDesc(g, kind, plus: plus), fs, w, 1 << 20);
    if (desc.length > room) desc = this._wrap(_detailDesc(g, kind, tail: false, plus: plus), fs, w, room);
    for (final (i, line) in desc.indexed) {
      _text(c, line, Offset(x, y + (i + 0.5) * lineH), size: fs, color: ink);
    }
    v
      ..at['desc'] = Rect.fromLTWH(x, y, desc.fold(0.0, (m, l) => math.max(m, _textWidth(l, fs))), desc.length * lineH)
      ..texts['desc'] = desc.join('\n');
    return x;
  }

  /// [kind]'s kind line on the Sell Basket page, in parts and their inks (decisions-log 278): an item's grade ("Grade II
  /// item", grey); a small relic's tier ("Strong relic", in its tier's ink, [Relics.relicTierLine]);
  /// a Pusaka's rarity and where it is ([_pusakaWhere]: "Epic · in Vault"); a material none (what drops it says what it
  /// is, [Town.matSource]).
  List<(String, Color)> _shopKindLine(Game g, Enum kind, [int plus = 0]) {
    const ink = Color(0xFF4A2C17), grey = Color(0xFF9E9080);
    final word = _marketWord(g, kind, plus);
    return switch (kind) {
      final Item i => [('${gradeName(i.grade).substring(0, 1).toUpperCase()}${gradeName(i.grade).substring(1)} item', grey), ...word],
      final Relic r when r.pusaka && g.pusaka.containsKey(r) => _pusakaWhere(g, r),
      final Relic r when !r.pusaka => [(g.relicTierLine(r), _relicTierInk[g.relicTier(r)] ?? ink), ...word],
      _ => const [],
    };
  }

  /// The market's word after the kind line (decisions-log 326, [Market.marketWord]): " · Hot in Millbrook" in green, or
  /// " · Flooded: price falling" in red; none else.
  List<(String, Color)> _marketWord(Game g, Enum kind, int plus) => switch (g.marketWord(kind, plus)) {
        MarketWord.hot => [(' · ', const Color(0xFF9E9080)), ('${Words.hotIn} ${g.townIdentity.name}', _haveInk)],
        MarketWord.flooded => [(' · ', const Color(0xFF9E9080)), (Words.flooded, _blockedInk)],
        null => const [],
      };

  /// The Sell grid's market marks (decisions-log 326): a hot or flooded product's cell shows its arrow ([_marketArrow]) at
  /// its top right, half the cell wide, over the slot's corner (an enhanced stack's "+2" keeps the top left; only a Vault
  /// Artifact, never marked, puts its basket count there).
  void _shopSellArrows(Canvas c, Game g) {
    final v = _shop..arrows.clear();
    for (final (loot, r) in v.sell.cells) {
      final word = g.marketWord(loot.kind, loot.plus), arrow = _marketArrow(g, loot.kind, loot.plus);
      if (word == null || arrow == null) continue;
      final a = math.max(16.0, (r.width / 2).roundToDouble());
      final to = Rect.fromLTWH((r.right - a + a / 8).roundToDouble(), (r.top - a / 8).roundToDouble(), a, a);
      _uiIcon(c, arrow, to);
      v.arrows[loot] = (word, to);
    }
  }

  /// The market's arrow for [kind] at +[plus] ([Market.marketWord]): ui_icons.png's middle green up arrow (16, 144) when
  /// hot, its middle red down arrow (64, 160) when flooded (mapped: each in its own 16-px cell, decisions-log 326).
  Offset? _marketArrow(Game g, Enum kind, int plus) => switch (g.marketWord(kind, plus)) {
        MarketWord.hot => const Offset(16, 144),
        MarketWord.flooded => const Offset(64, 160),
        null => null,
      };

  /// The price row of [loot] ([n] of it in the basket) in [row] (decisions-log 278; the owner's "`<harga>` * `<+ jumlah - >` =
  /// `<sub total harga item>`"), left to right: the coin and what one sells for ([shopSellPrice], [shortPrice]), "x", the
  /// stepper as light tags, "-", the count, "+", then "All" at its end ([_shopSetCount]: "-" at 1 takes the line out, "+"
  /// and "All" greyed at what is held, [shopHeld]); at the row's right "= " and the subtotal (one times [n]) in bold.
  /// Where it doesn't all fit (a phone's page), the coin goes first, then the "=".
  void _shopPriceRow(Canvas c, Game g, BagLoot loot, int n, Rect row, double fs, double ts) {
    const ink = Color(0xFF4A2C17), soft = Color(0xFF8A6A4A);
    final a = _assign, v = _shop, each = shopSellPrice(g, loot), held = shopHeld(g, loot), cy = row.center.dy;
    final sp = math.max(3.0, (4 * ts).roundToDouble()), coin = (fs * 1.1).roundToDouble(), all = bagCategoryNames[BagCategory.all]!;
    final unit = shortPrice(each), sub = shortPrice(shopSubtotal(g, loot, n)), count = '$n';
    final arrow = _marketArrow(g, loot.kind, loot.plus);
    double capW(String label) => capsuleSize(_textWidth(label, fs), fs).width;
    final unitW = _textWidth(unit, fs), xW = _textWidth('x', fs), countW = _textWidth(count, fs, bold: true);
    final subW = _textWidth(sub, fs, bold: true), eqW = _textWidth('=', fs);
    final bare = unitW + sp + xW + sp + capW(' - ') + sp + countW + sp + capW(' + ') + sp + capW(all) + sp + subW +
        (arrow == null ? 0 : coin + ts);
    final withCoin = bare + eqW + sp + coin + 2 * ts <= row.width, withEq = bare + eqW + sp <= row.width;

    var x = row.left;
    if (withCoin) {
      _uiIcon(c, Board._icCoin, Rect.fromLTWH(x, (cy - coin / 2).roundToDouble(), coin, coin));
      x += coin + 2 * ts;
    }
    if (arrow != null) {
      // The market's arrow before the price (decisions-log 326): hot or flooded.
      _uiIcon(c, arrow, Rect.fromLTWH(x, (cy - coin / 2).roundToDouble(), coin, coin));
      v.at['arrow'] = Rect.fromLTWH(x, (cy - coin / 2).roundToDouble(), coin, coin);
      x += coin + ts;
    }
    _text(c, unit, Offset(x, cy), size: fs, color: ink);
    v.at['unit'] = Rect.fromLTRB(row.left, row.top, x + unitW, row.bottom);
    x += unitW + sp;
    _text(c, 'x', Offset(x, cy), size: fs, color: soft);
    x += xW + sp;

    // A light tag from x (its tap 3 px wider on its left, the row's height), then the room after it.
    Rect tag(String label, bool can, VoidCallback fn) {
      final btn = Rect.fromLTRB(x, row.top, x + capW(label), row.bottom);
      x = btn.right + sp;
      return _tag(c, btn, fn, label, fs, look: can ? _TagLook.go : _TagLook.off, into: a.taps);
    }

    final less = tag(' - ', true, () => _shopSetCount(loot, n - 1));
    _text(c, count, Offset(x, cy), size: fs, color: ink, bold: true);
    v.at['count'] = Rect.fromLTWH(x, cy - fs * 0.65, countW, fs * 1.3);
    x += countW + sp;
    final more = tag(' + ', n < held, () => _shopSetCount(loot, n + 1));
    final most = tag(all, n < held, () => _shopSetCount(loot, held));
    _text(c, sub, Offset(row.right, cy), size: fs, color: ink, anchor: Anchor.centerRight, bold: true);
    if (withEq) _text(c, '=', Offset(row.right - subW - sp, cy), size: fs, color: soft, anchor: Anchor.centerRight);
    v.at
      ..['price'] = row
      ..['minus'] = less
      ..['plus'] = more
      ..['all'] = most
      ..['subtotal'] = Rect.fromLTWH(row.right - subW, cy - fs * 0.65, subW, fs * 1.3);
    v.texts
      ..['price'] = '$unit x $count = $sub'
      ..['count'] = count
      ..['subtotal'] = sub;
    _keepFromLog(row); // the open battle log keeps clear of the stepper (battle_log.dart)
  }

  /// A basket line's height at the book's pixel scale [ps]: its icon ([bagHeadIcon]: 16 px on a phone, 32 on the desk)
  /// and its padding ([_shopLinePad]) over and under it, as the Bag's slots hold theirs.
  double _shopLineHeight(double ps) => bagHeadIcon(ps) + 2 * _shopLinePad(ps);
  double _shopLinePad(double ps) => ps < 2 ? 3 : 3 * ps;

  /// [loot]'s line in the basket in [r] ([n] of it set to sell; decisions-log 278): the Bag's inset paper slot
  /// ([_bagSlot] at the book's pixel scale [ps]), lit under the mouse, the pick's on the pick's orange card as its cell;
  /// one row: its icon (an enhanced stack's in its level's colour), its name (the stack's "+3" in its level's ink, an
  /// Artifact's in gold), "2 x 1500" in brown (a carved Artifact's "Carve +3 is lost" in red; "x2" where a name has no
  /// room; none where even that doesn't fit) and the subtotal in bold at the right. A tap on it picks it.
  void _shopLine(Canvas c, Game g, BagLoot loot, int n, Rect r, double fs, double ts, double ps, bool picked) {
    const ink = Color(0xFF4A2C17), soft = Color(0xFF8A6A4A);
    final (:kind, :plus) = loot;
    final a = _assign, v = _shop, hit = r.intersect(a.list), look = _look(hit), lit = picked || look == ButtonLook.hover || look == ButtonLook.pressed;
    _bagSlot(c, r, ps, frame: lit ? Board._frameLit : Board._framePlain, paint: picked ? _bagPickPaint : null);
    final pad = _shopLinePad(ps), side = bagHeadIcon(ps), sp = math.max(4.0, (6 * ts).roundToDouble()), cy = r.center.dy;
    final box = _whole(Rect.fromLTWH(r.left + pad, cy - side / 2, side, side));
    _icon(c, kind, box, null, plus);
    // The Smithy's goods fall in price piece by piece (decisions-log 326): the line says their average, the subtotal the sum.
    final total = shopSubtotal(g, loot, n), each = n > 0 ? (total / n).round() : shopSellPrice(g, loot);
    final sub = shortPrice(total), end = r.right - pad, subW = _textWidth(sub, fs, bold: true);
    _text(c, sub, Offset(end, cy), size: fs, color: ink, anchor: Anchor.centerRight, bold: true);

    // Between the name and the subtotal: "2 x 1500" (or a carved Artifact's loss) where a name of a few letters still fits.
    final x = box.right + sp, name = _lootName(kind), up = plus > 0 ? ' +$plus' : '', upW = _textWidth(up, fs), midEnd = end - subW - sp;
    final carved = kind is Relic ? g.pusaka[kind]?.ukir ?? 0 : 0;
    final mids = carved > 0 ? ['${Words.carve} +$carved is lost', '${Words.carve} +$carved lost'] : ['$n x ${shortPrice(each)}', 'x$n'];
    final mid = [for (final t in mids) if (midEnd - _textWidth(t, fs) - sp - x - upW >= 4 * fs) t].firstOrNull;
    if (mid != null) _text(c, mid, Offset(midEnd, cy), size: fs, color: carved > 0 ? _blockedInk : soft, anchor: Anchor.centerRight);
    final shown = _fit(name, fs, (mid == null ? midEnd : midEnd - _textWidth(mid, fs) - sp) - x - upW);
    _text(c, shown, Offset(x, cy), size: fs, color: kind is Relic && kind.pusaka ? _storeGold : ink);
    if (up.isNotEmpty) _text(c, up, Offset(x + _textWidth(shown, fs), cy), size: fs, color: _plusPaperInk(plus));
    if (!hit.isEmpty) a.taps.add((hit, () => _storePickAt = loot));
    v.lines.add((loot, hit, '$n x ${shortPrice(each)} = $sub'));
  }

  /// The Sell Basket page's bottom bar in [bar] (decisions-log 278 and 306; the owner's "`<total coin yand didapat>` `<btn
  /// sell>`", then, 2026-10-09: "total coinnya di pindah ke button aja, dan di tabahin icon coin ... terus total di kiri di
  /// takeout"): the page's one bevelled button across the bar (its main standalone action, the owner's button rule; as
  /// wide as the Smithy's Craft and the Tavern's Buy), the green "Sell", the coin and the gold the whole basket brings
  /// ([shopBasketGold], [shortPrice]) in the middle of it: "Sell (coin) 12k" (without the coin, then "Sell" alone where
  /// narrower). A press sells the whole basket ([_shopSellAll]). Greyed with the basket empty or the Shop refusing
  /// ([_shopSellWhy]): "Sell" alone (no coin, no 0), a press then saying why. No total beside it (until decisions-log 306
  /// "Total (coin) 40" stood at the bar's left and the button read "Sell (40 gold)").
  void _shopSellBar(Canvas c, Game g, Rect bar, double ts) {
    final v = _shop, gold = shopBasketGold(g, v.basket), why = _shopSellWhy(g), amount = shortPrice(gold), sell = Words.sell;
    final fs = math.max(10.0, 14 * ts), sp = math.max(3.0, (4 * ts).roundToDouble()), coin = (fs * 1.1).roundToDouble(), room = bar.width - 12 * ts;
    final sellW = _textWidth(sell, fs), amountW = _textWidth(amount, fs);
    final withCoin = why == null && sellW + sp + coin + 2 * ts + amountW <= room, bare = why == null && !withCoin && sellW + sp + amountW <= room;
    final sink = _button(c, bar, _shopSellAll, enabled: why == null, row: Board._btnGreen);
    if (why != null) _hits.add((bar, () => showMessage(why))); // the greyed one's press says why

    // The words and the coin as one group in the button's middle, a touch up as [_button] puts its label.
    final k = (bar.height / 16).floorToDouble().clamp(1.0, 3.0), cy = bar.center.dy + sink - k;
    final ink = why == null ? const Color(0xFF3B2210) : const Color(0xFF8E8A86);
    final label = withCoin || bare ? '$sell $amount' : _fit(sell, fs, room);
    final width = withCoin ? sellW + sp + coin + 2 * ts + amountW : _textWidth(label, fs);
    var x = (bar.center.dx - width / 2).roundToDouble();
    if (withCoin) {
      _text(c, sell, Offset(x, cy), size: fs, color: ink);
      x += sellW + sp;
      v.at['sellCoin'] = Rect.fromLTWH(x, (cy - coin / 2).roundToDouble(), coin, coin);
      _uiIcon(c, Board._icCoin, v.at['sellCoin']!);
      _text(c, amount, Offset(x + coin + 2 * ts, cy), size: fs, color: ink);
    } else {
      _text(c, label, Offset(x, cy), size: fs, color: ink);
    }
    v.at['sell'] = bar;
    v.texts['sell'] = label;
  }

  /// Why the basket can't be sold now (null: it can): it is empty ("Tap items on the left to sell them."), or the Shop's
  /// refusal for a stack in it ([Store.whyNotSell], [Enhance.whyNotSellAt]: outside a Town, the game over).
  String? _shopSellWhy(Game g) {
    if (_shop.basket.isEmpty) return shopTapToAdd;
    for (final (:kind, :plus) in _shop.basket.keys) {
      if ((kind is Item ? g.whyNotSellAt(kind, plus) : g.whyNotSell(kind)) case final why?) return g.storeWhy(why);
    }
    return null;
  }

  /// A press on Sell: every stack in the basket sold at its count ([shopSellBasket]), the basket emptied and the pick
  /// gone, and the message window says what and for how much ("Sold Sword x3: +3000 gold"; several stacks "Sold 6 pieces:
  /// +12k gold"). Refused: why.
  void _shopSellAll() {
    final g = state, v = _shop;
    shopBasketFit(g, v.basket);
    if (_shopSellWhy(g) case final why?) return showMessage(why);
    final one = v.basket.length == 1 ? v.basket.keys.single : null;
    final (:pieces, :gold) = shopSellBasket(g, v.basket);
    v.basket.clear();
    _storePickAt = null;
    final what = switch (one?.kind) {
      final Item item => '${itemLabel(item, one!.plus)}${pieces > 1 ? ' x$pieces' : ''}',
      final Enum kind => '${_lootName(kind)}${pieces > 1 ? ' x$pieces' : ''}',
      null => '$pieces pieces',
    };
    if (pieces > 0) showMessage('Sold $what: +${shortPrice(gold)} gold');
  }
}
