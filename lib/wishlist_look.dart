part of 'main.dart';

// The Wishlist on the book (decisions-log 282; its rules: wishlist.dart; docs/ui-hud.md "The Smithy" and "Army"). The owner,
// 2026-10-09: the player puts the Smithy's products they mean to make on a list per troop type, as a target ("Wishlist /
// target saja": nothing crafts or gives by itself), from the Smithy's item page and from each type's Army detail, one
// list ("Dua-duanya").
// - The Smithy's item page (smithy_page.dart): while wished "Ready to craft" or what the Bag lacks. Until decisions-log 303
//   it had "Wishlist: Knight, Archer" and a chip per type that can take the item, a tap putting it on or off that type's
//   list; the owner took them out ("list trops dan whitelist disini di takeout aja"): a type's wishes go on from the Army
//   detail (its Wishlist section's picker, "Wishlist all", the "+" on a needs row).
// - The Army detail's section ([_detailWishlist]): "Wishlist" and its Add tag over the type's wishes as the Bag's slots (the
//   ▲ while the Bag pays for one; "have/need" on the type, decisions-log 300); a tap goes to the Smithy on it in a Town ([_wishGo]), outside one says "Craft at the
//   Smithy in a Town" and what it lacks. The tag opens the picker under them: the products the type can use, by grade, as
//   the Smithy's sections, each wished one lit with the gold star; a tap puts one on or off. While it is open the wishes
//   carry the small red ✕ and a tap takes one off; "Done" closes it.
// - A type's whole next Awaken (decisions-log 300, [_wishAllTap]): the Army detail's "Wishlist all" by its needs; one item
//   of it with its count, the "+" on its needs row where it fits (decisions-log 303, [_wishOneTap]).
// - Free lines (decisions-log 302): any item or relic the Smithy makes, for the Bag to hold a count of it, from its Smithy
//   page or (decisions-log 303) its Bag page ([_freeLine]: "-" ×1 "+" and "Add to wishlist", then "Remove").
// - The Smithy's Wishlist tab (decisions-log 303, smithy_page.dart) adds none: it makes them, and takes one or a group off.

/// The Army detail's Wishlist between frames (decisions-log 282): the type whose picker is open (null: none; another
/// type picked shows its own closed).
class _WishView {
  String? editing;
}

/// ui_icons.png's small red ✕ (its 7x8 at (4, 4) of the (176, 80) cell): a wish a tap takes off, while the Army detail's
/// picker is open.
const _icUnwish = Rect.fromLTWH(180, 84, 7, 8);

/// The paper slot's scale and side of the Army detail's Wishlist cells at the book's pixel scale [ps]: the Smithy's
/// small slot on a phone (22 px, its 16-px art at (3, 3)), and on the desk the same 16-px art in a 2-px slot (28 px), so a
/// type's 21 products stand in a few rows.
({double k, double side}) wishCell(double ps) {
  final k = ps >= 2 ? 2.0 : 1.0;
  return (k: k, side: 16 + 6 * k);
}

extension on Board {
  /// [type]'s idle sprite standing in [box] (the Bag chooser's filter chips', [_filterChips]): its awakening's outline.
  void _typeIcon(Canvas c, Game g, String type, Rect box) {
    final b = _idleBounds[type]!, s = math.min(box.width / b.width, box.height / b.height);
    c.save();
    c.translate(box.center.dx, box.bottom);
    c.scale(s);
    _frame(c, 'book_${type}_idle', 0, Offset.zero, anchor: Offset(b.center.dx, b.bottom), line: _awakeLine(g.awakenLevel(type)));
    c.restore();
  }

  /// A tap on [item] in [type]'s picker or on its ✕ (the Army detail): on that type's
  /// Wishlist or off it ([Wishlist.toggleWish]), and the message window says so ("Steel Sword: on Knight's wishlist").
  void _wishTap(String type, Item item) {
    final on = state.toggleWish(type, item), name = troopTypeNames[type] ?? type;
    showMessage('${itemNames[item]}: ${on ? 'on' : 'off'} $name\'s ${Words.wishlist.toLowerCase()}');
  }

  /// [type]'s whole next Awaken on its wishes, each with its count ([Wishlist.wishSet]; decisions-log 300), or off once it
  /// is on ([Wishlist.unwishSet]): the Army detail's "Wishlist all" / "Remove set". The message window says which
  /// ("Knight: Awaken 2 set on the wishlist"), or "Knight: nothing left to awaken".
  void _wishAllTap(String type) {
    final g = state, name = troopTypeNames[type] ?? type, level = awakenName(g.itemLevel(type) + 1), list = Words.wishlist.toLowerCase();
    if (g.setWished(type)) {
      g.unwishSet(type);
      return showMessage('$name: $level set off the $list');
    }
    showMessage(g.wishSet(type) ? '$name: $level set on the $list' : '$name: nothing left to awaken');
  }

  /// A tap on the "+" of [item]'s row in [type]'s Awaken needs on the Army detail (decisions-log 303): the item on the
  /// type's wishes to hold [goal] (the grade set's count, [Wishlist.wish]), and the message window says so ("Sword ×3: on
  /// Knight's wishlist").
  void _wishOneTap(String type, Item item, int goal) {
    if (!state.wish(type, item, goal)) return;
    showMessage('${itemNames[item]} ×$goal: on ${troopTypeNames[type] ?? type}\'s ${Words.wishlist.toLowerCase()}');
  }

  /// [kind]'s free line in [r] on its Smithy page (decisions-log 302; the owner: "header yang army itu bisa di ganti ke
  /// item/ relics yang lain yang bisa di buat") or its Bag page (decisions-log 303), the Bag's link tags in [fs]: "-" and
  /// "+" with how many more it asks between them ("×2": on the Wishlist what is still to make, [Wishlist.wishFreeMore];
  /// off it what "Add" would ask, 1 at first, [_SmithyView.freeMore]; "-" greyed at one), and at the right "Add to
  /// wishlist" ("Add" where short) or while on "Remove". The message window says when it goes on or off. Its parts by key
  /// in [at] ('freeLess', 'freeMore', 'freeAdd') and its words in [texts] ('free': "off ×1", "on ×2"; 'freeAdd'), for
  /// tests.
  void _freeLine(Canvas c, Game g, Enum kind, Rect r, double fs, {required Map<String, Rect> at, required Map<String, String> texts}) {
    const ink = Color(0xFF4A2C17);
    final v = _smithy, on = g.freeWished(kind), name = _lootName(kind), list = Words.wishlist.toLowerCase();
    final more = switch (on ? g.freeCount(kind) : null) { (final have, final need) => need - have, null => v.freeMore[kind] ?? 1 };
    var x = r.left;
    Rect step(String label, bool live, VoidCallback fn) {
      final hit = _tag(c, Rect.fromLTWH(x, r.top, capsuleSize(_textWidth(label, fs), fs).width + 3, r.height), () {
        if (live) fn();
      }, label, fs,
          look: live ? _TagLook.link : _TagLook.off);
      x = hit.right + 4;
      return hit;
    }

    void by(int n) => on ? g.wishFreeMore(kind, n) : v.freeMore[kind] = (more + n).clamp(1, 99);
    at['freeLess'] = step('-', more > 1, () => by(-1));
    final said = '×$more';
    _text(c, said, Offset(x, r.center.dy), size: fs, color: ink, bold: true);
    x += _textWidth(said, fs, bold: true) + 4;
    at['freeMore'] = step('+', more < 99, () => by(1));
    void add() {
      if (!g.wishFreeAdd(kind, more)) return;
      v.freeMore.remove(kind); // met and off again, it asks one at first
      showMessage('$name ×$more: on the $list');
    }

    void off() {
      if (g.unwishFree(kind)) showMessage('$name: off the $list');
    }

    final label = on ? Words.remove : _fitFirst([Words.addToWishlist, Words.add], fs, r.right - x - 8);
    at['freeAdd'] = _tag(c, Rect.fromLTRB(x, r.top, r.right, r.bottom), on ? off : add, label, fs);
    texts
      ..['free'] = '${on ? 'on' : 'off'} ×$more'
      ..['freeAdd'] = label;
  }

  /// A wish tapped on the Army detail: in a Town the Smithy's Items tab on [item] ([_openSmithyItem]); outside one the
  /// message window says where it is made and whether the Bag pays for one: "Craft at the Smithy in a Town" over
  /// "Steel Sword: Ready to craft" or its first want ("Need 2 more Wolf Claw", [Craft.whyNotMake]).
  void _wishGo(Item item) {
    final g = state;
    if (g.inTown) return _openSmithyItem(item);
    final why = g.whyNotMake(item);
    showMessage('${Words.craftInTown}\n${itemNames[item]}: ${why == null ? Words.readyToCraft : why.text}');
  }

  /// The Wishlist's status on the Smithy's page for [kind] in [r] (decisions-log 282, 303), while it is wished (a type's
  /// open wish for an item, or a free line): "Ready to craft" in green, else what the Bag lacks for one in red
  /// ([Wishlist.wishShort], a relic's [Craft.craftRows] short: "Missing: Wolf Claw 1/2, gold", shorter in steps).
  void _smithyWishStatus(Canvas c, Game g, Enum kind, Rect r, double fs) {
    final short = switch (kind) { final Item i => g.wishShort(i), final Relic relic => [for (final row in g.craftRows(relic)) if (row.have < row.need) row], _ => const <CraftRow>[] };
    String name(CraftRow s) => switch (s.kind) { final Mat m => m.label, final Item i => itemNames[i]!, _ => 'gold' };
    String count(CraftRow s) => s.kind == null ? 'gold' : '${name(s)} ${s.have}/${s.need}';
    final text = short.isEmpty
        ? Words.readyToCraft
        : _fitFirst([
            'Missing: ${short.map(count).join(', ')}',
            'Missing: ${short.map(name).join(', ')}',
            'Missing: ${name(short.first)}${short.length > 1 ? ' +${short.length - 1}' : ''}',
          ], fs, r.width);
    _text(c, text, Offset(r.left, r.center.dy), size: fs, color: short.isEmpty ? _haveInk : _blockedInk);
    _smithy
      ..at['wishMissing'] = r
      ..texts['wishMissing'] = text;
  }

  /// The Army detail's Wishlist section for [type] between [x0] and [x1] (decisions-log 282), with the Wishlist on
  /// ([Wishlist.wishOn]) and some product the type can use ([Wishlist.wishable]): "Wishlist" and at the right its tag,
  /// "Add to wishlist" ("Add" where short; [Words.done] while the picker is open); its wishes as the Bag's slots
  /// ([_wishCells]), or "No items yet" in grey; while the picker is open, "Tap an item to add or remove it" in grey and
  /// the type's products by grade ([_wishPicker]). Its taps on tap UP ([_Detail.hits]), as the detail's.
  List<_DetailLine> _detailWishlist(Canvas c, Game g, String type, double x0, double x1, _DetailSizes s, double ps) {
    const ink = Color(0xFF4A2C17), grey = Color(0xFF9E9080);
    if (!g.wishOn) return const [];
    final products = g.wishable(type);
    if (products.isEmpty) return const [];
    final open = _wish.editing == type, wishes = g.wishesOf(type), w = x1 - x0, ts = s.ts;
    final out = <_DetailLine>[
      (
        h: s.button,
        draw: (top) {
          final btn = Rect.fromLTRB(x0, top, x1, top + s.button);
          final label = open ? Words.done : _fitFirst([Words.addToWishlist, 'Add'], s.small, w * 0.55);
          void tap() => _wish.editing = open ? null : type;
          final hit = _tag(c, btn, tap, label, s.small, into: _detail.hits);
          _detail.at['wishEdit'] = _inView(hit, _detail.body);
          (_detail.words['wishEdit'] ??= []).add(label);
          _say(c, 'wishlist', _fit(Words.wishlist, s.small, hit.left - x0 - 4 * ts), Offset(x0, btn.center.dy), s.small, ink);
        },
      ),
    ];
    if (wishes.isEmpty) {
      out.add((h: s.line, draw: (top) => _say(c, 'wishlist', _fit('No items yet', s.small, w), Offset(x0, top + s.line / 2), s.small, grey)));
    } else {
      out.addAll(_wishCells(c, g, type, wishes, x0, x1, s, ps, unwish: open));
    }
    if (!open) return out;
    final hint = _fitFirst(['Tap an item to add or remove it', 'Tap to add or remove'], s.small, w);
    out.add((h: s.line, draw: (top) => _say(c, 'wishlist', hint, Offset(x0, top + s.line / 2), s.small, grey)));
    out.addAll(_wishPicker(c, g, type, products, x0, x1, s, ps));
    return out;
  }

  /// [items] as rows of the Bag's slots between [x0] and [x1] ([wishCell] at [ps], 2 sprite px apart; as many a row as
  /// fit), each a line of the detail: [cell] draws each in its rect.
  List<_DetailLine> _wishRows(List<Item> items, double x0, double x1, double ps, void Function(Item item, Rect r) cell) {
    final (:k, :side) = wishCell(ps);
    final gap = 2 * k, cols = math.max(1, ((x1 - x0 + gap) / (side + gap)).floor());
    final rows = (items.length + cols - 1) ~/ cols;
    return [
      for (var row = 0; row < rows; row++)
        (
          h: side + (row < rows - 1 ? gap : 0),
          draw: (top) {
            for (var i = row * cols; i < math.min(items.length, (row + 1) * cols); i++) {
              cell(items[i], Rect.fromLTWH((x0 + (i - row * cols) * (side + gap)).roundToDouble(), top, side, side));
            }
          },
        ),
    ];
  }

  /// One Wishlist cell of [item] for [type] in [r] (the Bag's slot, [wishCell]'s scale): the paper card, lit under the
  /// mouse and sunk while pressed, or with [lit] the pick's lit card ([_bagPickPaint]); its 16-px icon; with [star] the
  /// gold star at the top left (as the Smithy's), with [ready] the green ▲ at the top right, with [unwish] the small red
  /// ✕ there instead, each tucked to its corner as on the Smithy's 22-px slots; with [count] (have, need) its capsule at
  /// the bottom right in [fs], green and the icon faded once done (decisions-log 300). Its tooltip is the item's over [type] ([_Tips.rows]), its tap [fn] on tap UP. Returns the rect as
  /// cut to the body's view.
  Rect _wishCell(Canvas c, Item item, String type, Rect r, double ps, VoidCallback fn,
      {bool lit = false, bool star = false, bool ready = false, bool unwish = false, (int, int)? count, double fs = 10}) {
    final (:k, side: _) = wishCell(ps);
    final look = _look(r), sink = look == ButtonLook.pressed ? k : 0.0;
    final at = r.translate(0, sink), done = count != null && count.$1 >= count.$2;
    _bagSlot(c, at, k,
        frame: lit || look == ButtonLook.hover || look == ButtonLook.pressed ? Board._frameLit : Board._framePlain, paint: lit ? _bagPickPaint : null);
    _icon(c, item, Rect.fromLTWH(at.left + 3 * k, at.top + 3 * k, 16, 16), done ? _smithyFaded : null);
    // How far the wish is (decisions-log 300): "have/need" on the type, tight and tucked as the Smithy's 22-px counts;
    // green once done.
    if (count case (final have, final need)) {
      _capsule(c, '$have/$need', fs, Offset(at.right + 1, at.bottom + 1), anchor: Anchor.bottomRight, green: done, tight: true);
    }
    // The marks tucked out to the corners as on the Smithy's 22-px slots (its art is 16 px at every scale here): the star's
    // 14x14 takes the icon's top left corner only, the ▲'s 10x10 its top right, the ✕ the slot's own corner.
    if (star) _uiIcon(c, _icStar, Rect.fromLTWH(at.left - 3, at.top - 3, 16, 16));
    if (unwish) {
      c.drawImageRect(_img('ui_icons.png'), _icUnwish, Rect.fromLTWH(at.right - _icUnwish.width, at.top, _icUnwish.width, _icUnwish.height), _px);
    } else if (ready) {
      _uiIcon(c, _icReady, Rect.fromLTWH(at.right - 11, at.top - 5, 16, 16));
    }
    _tip.rows.add((r, item, type));
    _detail.hits.add((r, fn));
    return _inView(r, _detail.body);
  }

  /// [type]'s wishes as rows of cells ([_wishRows], [_wishCell]), in the order put on, each with "have/need" on the type
  /// (decisions-log 300; green and faded once done): the ▲ while still open and the Bag pays for one
  /// ([Craft.canMake]: "Ready to craft" wherever the game is), a tap going to the Smithy ([_wishGo]); with [unwish] (the
  /// picker open) the red ✕ in its place, a tap taking it off ([_wishTap]). For tests: `wish:<item>` where each is,
  /// `wishReady` the names of those marked ready.
  List<_DetailLine> _wishCells(Canvas c, Game g, String type, List<Item> wishes, double x0, double x1, _DetailSizes s, double ps,
      {required bool unwish}) {
    return _wishRows(wishes, x0, x1, ps, (item, r) {
      final count = g.wishCount(type, item), ready = !g.wishDone(type, item) && g.canMake(item) > 0;
      _detail.at['wish:${item.name}'] = _wishCell(c, item, type, r, ps, unwish ? () => _wishTap(type, item) : () => _wishGo(item),
          ready: ready, unwish: unwish, count: count, fs: math.max(10.0, 11 * s.ts));
      if (ready) (_detail.words['wishReady'] ??= []).add(itemNames[item]!);
    });
  }

  /// The picker of [type]'s [products] (decisions-log 282), by grade as the Smithy's Items sections (277): each grade's
  /// heading ("Grade II", [gradeTitle]; one heading-less group where Awaken doesn't go by grade) over its cells, a wished
  /// one lit with the gold star; a tap puts it on or takes it off ([_wishTap]). For tests: `pick:<item>` where each is.
  List<_DetailLine> _wishPicker(Canvas c, Game g, String type, List<Item> products, double x0, double x1, _DetailSizes s, double ps) {
    const ink = Color(0xFF4A2C17);
    final out = <_DetailLine>[];
    for (var n = 1; n <= Words.gradeNumerals.length; n++) {
      final items = [for (final i in products) if (i.grade == n) i];
      if (items.isEmpty) continue;
      if (g.byGrade) {
        final title = gradeTitle(n);
        out.add((h: s.line, draw: (top) => _say(c, 'wishPicker', title, Offset(x0, top + s.line / 2), s.small, ink, bold: true)));
      }
      out.addAll(_wishRows(items, x0, x1, ps, (item, r) {
        final on = g.wishesOf(type).contains(item);
        _detail.at['pick:${item.name}'] = _wishCell(c, item, type, r, ps, () => _wishTap(type, item), lit: on, star: on);
      }));
    }
    return out;
  }
}
