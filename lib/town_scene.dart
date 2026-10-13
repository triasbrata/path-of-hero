part of 'main.dart';

// The Town scene (decisions-log 224; docs/ui-hud.md "Town"): while a
// Town shows ([Game.inTown]) the Board draws it where the field was, and the field waits as it was left (its game ticks
// on; no wave starts). GandalfHardcore's free platformer set only (lib/town_art.dart, decisions-log 222): the parallax
// layers and the castle, the clouds, the ground ([_townStreet]), and along the street four places, left to right ([_TownLayout]): the
// troops' rest (the Large Tent and the pot over the campfire, its calm loop), the Smithy, the Tavern and the Shop. The
// three are buildings rebuilt cell by cell from town_house.png ([houseCells]: the owner's "harus di re-construct jangan
// langsung di pasang"; the owner's note of 2026-10-04: the middle building is the Tavern, the Shop and the Smithy are
// in buildings of their own, the tent only the troops' rest): the Smithy's the smallest house, on its ground floor the
// smith at his anvil (lib/town_smith.dart, decisions-log 265), on its left its wood corner (a stump with an axe, a log
// pile, the sawmill against the house) and on its right the furnace against its wall and the ore rock by it
// ([_townFps]; decisions-log 271), the Tavern one or two storeys (its balcony's props and the pot on its block from
// town_props.png), the Shop's the smallest house with its stalls before it (crates, the fruit table, barrels, a basket);
// the olive pine and beside it the clothes line between the Smithy and the Tavern. Each building has its sign ("Smithy",
// "Tavern", "Shop") on ui_ribbons.png's flat ribbon over its roof. On the street the army's living troops go about their errands
// (lib/town_life.dart, on [_TownLayout.spots]' anchors and the one lane); no other people or animals but the smith.
//
// It is laid out wider than the screen ([_TownLayout.full], decisions-log 271) at 2 screen px a world px (3 on a tall
// screen; 1 where 2 doesn't fit [_TownLayout.fit] across, as 915x412), and pans ([_townPan] s) so the open page's place
// sits in view: left of the book, or in the middle of the screen with the book shut (the Smithy for Smithy, the Shop for Shop, the tent for Army, the Tavern for Bag and Settings). The player pans it sideways too, to look
// around (decisions-log 264): a drag or a swipe on the scene, the wheel, a trackpad's swipe, between the Town's ends
// ([_townRoom]); the page's own pan takes over again when the page or the book changes. The book's tabs in a Town
// are Smithy, Tavern, Shop, Army, Bag and Settings ([_bookTabs]); a tap on a sign or its building opens its page, a tap
// on the tent the Army's (decisions-log 301), and a tap on the scene outside the book shuts it; a tap acts as the press
// comes up unmoved, so a drag never taps ([_townSlop]). Going in and out fades: [_townFade] s to the pause's dim, the other scene,
// [_townFade] s back.
/// The street's line, in the layers' 1024x346 world px: the ground's top edge (decisions-log 279, in place of 274's
/// grass, green and roots; the owner, 2026-10-08: "disceene townya perlu di perbaiki lagi untuk ground levelnya,
/// harusnya dengan sprite ini [his crop] dari Floor Tiles2.png, lalu di atasnya langsung bangungan dan tidak perlu di
/// tambahin semua tempat diberikan dekorasi rumput di atasnya"). The street is Floor Tiles2's grass top over its earth
/// ([townGroundTile], [_townStreet]) from this line down; every building and piece stands right on it, its bottom on
/// the line, and nothing is drawn over their feet. The smith and a troop inside stand on a building's floor, [townStep]
/// over it; the street's troops on the strip, their feet at their depth under it ([TownFolk.depth]).
const _townGround = 262;

/// The Smithy's and the Shop's buildings: the smallest house (n -1: eight columns of wall), one storey; the Tavern's,
/// n 1 (two column pairs wider), one or two storeys by the height ([_TownLayout.storeys]).
const _townSmallN = -1, _townTavernN = 1;

/// The Smithy's wood corner on its house's left (decisions-log 271: the owner, 2026-10-08, "posisi furnace di sebelah
/// kanan dan sawmill di sebelah kiri dari smithy"), left to right: each piece and its art's width with 3 px after it
/// (world px): the stump with its axe, the log pile, the sawmill (its art columns 4-60 of its 64) against the house.
const _townWood = [('stumpAxe', 24.0), ('logPile', 50.0), ('sawmill', 60.0)];

/// The widths along the street in world px: the tent; the Smithy's place: its wood corner ([_townWoodW], [_townWood]),
/// its house (148) and on its right the furnace against its wall ([_TownLayout.furnaceX], its art 34 past the house)
/// and the ore by it, 2 clear of the furnace's art, 53 wide with 3 after it (92 in all); the yard (decisions-log 253: the
/// pine's 50 and the clothes line's 106 side by side; each identity's pieces since 326, [_townYards]);
/// the Town's ends, the left one before the tent and the right one after the Shop's seen box (its cells, the eave tip's
/// clear end, go 6 past it); the least gap between two places.
const _townTentW = 96.0, _townWoodW = 134.0, _townSmithyW = _townWoodW + 148 + 92, _townYardW = 156.0,
    _townEdgeL = 2.0, _townEdgeR = 6.0, _townGap = 4.0;

/// How far under the screen's top the street runs (its share of the height): low, the owner's "ground levelnya di
/// turunkan".
const _townStreetDown = 0.92;

/// The Dungeon's door at the street's far end (decisions-log 336, 337; dungeon-design.md's mockup D), world px from its
/// place's left: a mossy rock mound of Floor Tiles2's moss-topped block, [_townDoorCols] cells of 32 wide and 3 tall
/// from [_townDoorMound], the portal at its foot in the middle, a boulder pile over each of its lower corners and a lit
/// standing torch in front of either side of the portal ([_TownLayout.pieces]), as the mockup lays them; [_townDoorW]
/// in all, its middle (the sign's) at [_townDoorMid].
const _townDoorW = 270.0, _townDoorMound = 38.0, _townDoorCols = 5, _townDoorMid = _townDoorMound + 16.0 * _townDoorCols;

/// The clouds' row 0 over the layers' row 0, in px (decisions-log 274): as on the field until decisions-log 287, where
/// battle_clouds.png's row 0 lay 13.2 world units under the band's top and the layers' [_bandTop] (0.8 world units: 4 px
/// at the layers' [_layerK]).
const _townCloudsUp = 4.0;

/// The animations' frames a second (the furnace's, the sawmill's, the campfire's), the pan's seconds (a page's, a
/// fling's, the wheel's glide), each half of the fade's seconds, and the fade's darkest dim (the pause overlay's).
const _townFps = 8.0, _townPan = 0.4, _townFade = 0.35, _townDim = 0.35;

/// How far (screen px) a press on the Town's scene moves before it pans it; under that it is a tap (decisions-log 264).
/// A finger's drag starts only past Flutter's touch slop (18), so a touch tap may move up to that.
const _townSlop = 8.0;

/// The places a tap opens the book at, with their pages ([Board._townTap]): the three buildings by their signs or what
/// stands at them, the troops' rest (the tent and its campfire; decisions-log 301) on the Army, and the Dungeon's door
/// (its cave mouth, decisions-log 337) on its page.
const _townPages = [
  ('smithy', _Page.smithy),
  ('shop', _Page.store),
  ('tavern', _Page.tavern),
  ('tent', _Page.troops),
  ('dungeon', _Page.dungeon),
];

/// A season's backdrop (decisions-log 326): its parallax [layers] (1 the near pines .. 5 the sky), its [castle] and its
/// street's tile ([ground]): the Normal BG set in summer, the Autumn and the Winter sets after.
typedef _TownSeasonArt = ({List<String> layers, String castle, String ground});

/// Each [TownSeason]'s art, by the Town's identity ([Market.sceneIdentity]).
const townSeasonArt = <TownSeason, _TownSeasonArt>{
  TownSeason.summer: (layers: townLayers, castle: townCastle, ground: townGroundTile),
  TownSeason.autumn: (layers: townAutumnLayers, castle: townAutumnCastle, ground: townGroundAutumn),
  TownSeason.winter: (layers: townWinterLayers, castle: townWinterCastle, ground: townGroundWinter),
};

/// A season's parallax layers back to front: (file, how far it moves with the street; 0 never), the castle between 4
/// and 3.
List<(String, double)> _townParallax(_TownSeasonArt art) => [
      (art.layers[4], 0.0),
      (art.layers[3], 0.15),
      (art.castle, 0.2),
      (art.layers[2], 0.35),
      (art.layers[1], 0.6),
      (art.layers[0], 1.0),
    ];

/// Each identity's yard (decisions-log 326; [townYardCells]), back to front: (its name in the scene, its cell, its left
/// from the yard's in world px), side by side across the yard's [_townYardW]. Willowmere's willow, wider than the yard,
/// stands in the middle of it behind the rest, scenery (no place's: a tap there opens nothing, as on the yard).
const _townYards = <String, List<(String, String, double)>>{
  'millbrook': [
    ('flowerTree', 'flowerTree', 0),
    ('wheat', 'wheat', 88),
    ('wheat2', 'wheat', 107),
    ('sack', 'sack', 126),
    ('sheaf', 'sheaf', 144),
  ],
  'willowmere': [
    ('willow', 'willow', (_townYardW - 216) / 2),
    ('boat', 'boat', 6),
    ('potGreen', 'potGreen', 90),
    ('potOlive', 'potOlive', 116),
    ('potSmall', 'potSmall', 138),
  ],
  'ironvale': [('birch', 'birch', 0), ('oreGold', 'oreGold', 78), ('torch', 'torch', 140)],
  'ambergate': [
    ('smallTent', 'smallTent', 0),
    ('flowerTable', 'flowerTable', 66),
    ('sunflowers', 'sunflowers', 106),
    ('grapeBowl', 'grapeBowl', 138),
  ],
  'frostgate': [
    ('cypress', 'cypress', 0),
    ('urnFern', 'urnFern', 32),
    ('angel', 'angel', 62),
    ('urnRed', 'urnRed', 112),
    ('torch', 'torch', 145),
  ],
  'highspire': [
    ('torch', 'torch', 2),
    ('bust', 'bust', 16),
    ('alchemyTable', 'alchemyTable', 40),
    ('urn', 'urn', 70),
    ('gardenTree', 'gardenTree', 100),
  ],
};

/// The pieces of [_townYards] that are scenery, not the yard's.
const _townScenery = {'willow'};

/// The house's cells for a house [n] column pairs wider than the sheet's (0 or 1) and [storeys] tall (1 or 2): each
/// cell's name in [townHouseCells], its column and its row on a 16-px grid from the ridge (row 0); the porch row's cells
/// are 16x8 at the top of theirs. The design's house.py `house_cells`, the same rules (test/fixtures/town_house_cells.json
/// pins them): the ridge in columns 6+n and 7+n; the slopes, two cells a row (the roof strip's top and its underside),
/// down to the eave tips in row 5+n, the pure slope rows alternating so the last meets row 3's; the gable's bricks
/// between them (the walls' tops on the tips' row); with two storeys the balcony's beam (its joint once, mid) and the
/// wall under it; the ground floor's 4 rows (the left wall with the door, the back wall with the window 2x3 at its middle,
/// the right wall's pipe and block); the porch.
List<(String, int, int)> houseCells(int n, int storeys) {
  final out = <(String, int, int)>[];
  final ridgeL = 6 + n, ridgeR = 7 + n, tip = 5 + n, right = 10 + 2 * n;
  out.addAll([('apexL', ridgeL, 0), ('apexR', ridgeR, 0)]);
  for (var r = 1; r <= tip; r++) {
    final k = (tip - 3 - r).isEven ? 2 : 1;
    final (lo, li, ri, ro) = r < tip - 2
        ? ('slopeL${k}o', 'slopeL${k}i', 'slopeR${k}i', 'slopeR${k}o')
        : r == tip - 2
            ? ('slopeL3o', 'slopeL3i', 'slopeR3i', 'slopeR3o')
            : r == tip - 1
                ? ('eaveL1o', 'postL', 'postR', 'eaveR1o')
                : ('eaveL0', 'wallL5a', 'wallR5b', 'eaveR0');
    final lc = ridgeL - r, rc = ridgeR + r;
    out.addAll([(lo, lc, r), (li, lc + 1, r), (ri, rc - 1, r), (ro, rc, r)]);
    for (var c = lc + 2; c < rc - 1; c++) {
      out.add((r == tip && c == 3 ? 'wallL5b' : r == tip && c == right ? 'wallR5a' : 'gable', c, r));
    }
  }
  var row = tip + 1;
  if (storeys == 2) {
    final mid = (4 + right - 1) ~/ 2;
    out.addAll([
      ('creamL6', 2, row),
      ('beamL', 3, row),
      for (var c = 4; c < right; c++) (c == mid ? 'beamJoint' : 'beam', c, row),
      ('beamR', right, row),
      ('beamREnd', right + 1, row),
    ]);
    row++;
    out.addAll([
      ('creamL7a', 2, row),
      ('creamL7b', 3, row),
      for (var c = 4; c < right; c++) ('brick', c, row),
      ('creamR7a', right, row),
      ('creamR7b', right + 1, row),
    ]);
    row++;
  }
  final wc = math.max(4, (4 + right) ~/ 2 - 1); // the window's left column
  const leftWall = [('wallL8a', 'wallL8b'), ('wallL9', 'doorTop'), ('wallL10', 'doorMid'), ('wallL11', 'doorLow')];
  const rightWall = [('pipeTL', 'pipeTR'), ('pipeBL', 'pipeBR'), ('blockTL', 'blockTR'), ('blockBL', 'blockBR')];
  const window = [('winTL', 'winTR'), ('winBL', 'winBR'), ('sillL', 'sillR')];
  for (var i = 0; i < 4; i++) {
    out.addAll([(leftWall[i].$1, 2, row + i), (leftWall[i].$2, 3, row + i)]);
    for (var c = 4; c < right; c++) {
      final pane = i < 3 && (c == wc || c == wc + 1);
      out.add((pane ? (c == wc ? window[i].$1 : window[i].$2) : 'brickLow', c, row + i));
    }
    out.addAll([(rightWall[i].$1, right, row + i), (rightWall[i].$2, right + 1, row + i)]);
  }
  row += 4;
  out.addAll([
    ('baseL', 2, row),
    ('porchL', 3, row),
    for (var c = 4; c < right; c++) ('porch', c, row),
    ('baseRa', right, row),
    ('baseRb', right + 1, row),
  ]);
  return out;
}

/// The house's grid in sprite px, (width, height): 14+2n columns of 16; its rows of 16 and the porch's 8.
(int, int) houseSize(int n, int storeys) => ((14 + 2 * n) * 16, (6 + n + (storeys == 2 ? 2 : 0) + 4) * 16 + 8);

/// How wide a house of [n] looks along the street: its grid but the empty end columns and the eaves' clear tips (n -1:
/// 148, n 0: 180, n 1: 212); it shows from 22 px into its grid.
double houseSeen(int n) => houseSize(n, 1).$1 - 44.0;

/// The props on the house ([townPropCells]' names): with two storeys the table, a crate, the barrels and the stacked
/// crates standing on the balcony beam's top board; the cauldron on the right block's top. Each (name, x, bottom y) in
/// house px (house.py's `house_props`). The smallest house (n -1, which house.py doesn't build) has room on its
/// balcony for the table and the stacked crates only (the crate and the barrels would stand out over the eave).
List<(String, int, int)> houseProps(int n, int storeys) {
  final tip = 5 + n, right = 10 + 2 * n, beam = (tip + 1) * 16 + 1;
  return [
    if (storeys == 2) ...[
      ('table', 4 * 16 + 4, beam),
      if (n >= 0) ...[('crate', 7 * 16 + 2, beam), ('barrels', 7 * 16 + 30, beam)],
      ('crates2', (right - 2) * 16 + 4, beam),
    ],
    ('cauldron', right * 16 + 7, (tip + 1 + (storeys == 2 ? 2 : 0) + 2) * 16 + 1),
  ];
}

/// A piece of the scene: its [name], the [place] it belongs to ('tent', 'smithy', 'tavern', 'shop', 'yard'; null: scenery), the [file]
/// and its first frame [src] (an animation's next frames are beside it, [frames] of them), its left [x] in world px
/// (its frame's bottom row on the street's line, [_townGround]), and its frame's empty columns at the left and the
/// right ([blank]: its place's box and taps take its art alone, so the furnace standing over the next house's foot
/// takes no tap of that house's); [up]: how far its bottom stands over the street (the door's mound's upper cells).
typedef _TownPiece = ({
  String name,
  String? place,
  String file,
  TownCell src,
  int frames,
  double x,
  (int, int) blank,
  double up,
});

/// Where the Town's places stand, laid out [viewW] world px wide (the view's width, [full] at the least: decisions-log
/// 271) with [above] world px from the view's top to the street: from the left end the tent, the Smithy (its wood
/// corner, its house, its furnace and the ore), the yard (the pine and the clothes line), the Tavern, the Shop and the
/// Dungeon's door (decisions-log 337), the room past [full] shared out between them. The Smithy and the Shop are the
/// smallest one-storey house; the Tavern n 1, two storeys from 240 above the street (its 200 and the HUD's band), else
/// one.
class _TownLayout {
  _TownLayout(double view, double above, [this.identity = 'millbrook']) : viewW = math.max(view, full) {
    storeys = above >= houseSize(0, 2).$2 + 40 ? 2 : 1;
    final gap = _townGap + (viewW - full) / 5;
    var x = _townEdgeL;
    for (final (place, w) in [
      ('tent', _townTentW),
      ('smithy', _townSmithyW),
      ('yard', _townYardW),
      ('tavern', houseSeen(n)),
      ('shop', houseSeen(_townSmallN)),
      ('dungeon', _townDoorW),
    ]) {
      left[place] = x;
      width[place] = w;
      x += w + gap;
    }
  }

  /// The least width the Town is laid out at, in world px (1284): its ends, the tent, the Smithy's place, the yard, the
  /// n 1 Tavern, the Shop, the Dungeon's door and the least gaps (1010 before the door, decisions-log 337). Wider than a
  /// screen at k 2: the player pans (decisions-log 264, 271).
  static final full = _townEdgeL + _townTentW + _townSmithyW + _townYardW + houseSeen(_townTavernN) +
      houseSeen(_townSmallN) + _townDoorW + _townEdgeR + 5 * _townGap;

  /// The scale's rule: no more screen px a world px than lets this many world px across (582: the least
  /// Town before it was laid out wider than the screen, decisions-log 253, 271), so the desk and the tablet draw at 2
  /// and 915x412 at 1.
  static const fit = 582.0;

  final double viewW;

  /// The Town's identity's key ([TownIdentity.key]): its yard's pieces ([_townYards]).
  final String identity;
  final int n = _townTavernN;
  late final int storeys;
  final left = <String, double>{}, width = <String, double>{}; // each place's (and the yard's) span, world px

  /// The Smithy's house's seen left (world px): past its wood corner.
  double get smithyHouse => left['smithy']! + _townWoodW;

  /// The furnace's frame's left (world px): its art (columns 10-53 of its 64) outside the Smithy, against its right wall
  /// (its house's walls end 10 px inside its seen box).
  double get furnaceX => smithyHouse + houseSeen(_townSmallN) - 20;

  /// The buildings: (place, n, storeys, its grid's left in world px, whether its props go on it).
  List<(String, int, int, double, bool)> get buildings => [
        ('smithy', _townSmallN, 1, smithyHouse - 22, false),
        ('tavern', n, storeys, left['tavern']! - 22, true),
        ('shop', _townSmallN, 1, left['shop']! - 22, false),
      ];

  /// Every piece but the buildings' cells, back to front (the buildings go after the first [behindHouses]).
  List<_TownPiece> get pieces {
    _TownPiece piece(String name, String? place, String file, TownCell src, double x,
            {int frames = 1, (int, int) blank = (0, 0), double up = 0}) =>
        (name: name, place: place, file: file, src: src, frames: frames, x: x, blank: blank, up: up);
    _TownPiece prop(String name, String? place, double x) => piece(name, place, townProps, townPropCells[name]!, x);
    _TownPiece whole(String name, String place, String file, int w, int h, double x) =>
        piece(name, place, file, (x: 0, y: 0, w: w, h: h), x);
    const f = townSmithyFrame, fire = townCampfireFrame;
    final tent = left['tent']!, shx = left['shop']!, wood = <_TownPiece>[];
    var x = left['smithy']!; // the wood corner's first art at the Smithy's place's left
    for (final (name, w) in _townWood) {
      wood.add(name == 'sawmill'
          ? piece('sawmill', 'smithy', townSmithy, (x: 0, y: townSawmillRow * f, w: f, h: f), x - 4,
              frames: townSmithyFrames, blank: (4, 3)) // its art: columns 4-60
          : prop(name, 'smithy', x));
      x += w;
    }
    return [
      // The yard: the identity's pieces side by side, left to right (decisions-log 326).
      for (final (name, cell, x) in yard)
        piece(name, _townScenery.contains(name) ? null : 'yard', townYards, townYardCells[cell]!, left['yard']! + x,
            frames: townYardFrames[cell] ?? 1),
      // The Smithy's, all outside its house (its ground floor the smith's, town_smith.dart; decisions-log 271): on its
      // left the wood corner, each piece's art 3 px after the last's, the sawmill's 3 px before the house; on its right
      // the furnace against its wall and the ore rock by it, its art 2 px past the furnace's.
      ...wood,
      piece('furnace', 'smithy', townSmithy, (x: 0, y: townFurnaceRow * f, w: f, h: f), furnaceX,
          frames: townSmithyFrames, blank: (10, 10)),
      whole('ore', 'smithy', townOre, 53, 38, furnaceX + 56),
      // The Shop's stalls before its window and its right wall; its door stays clear.
      prop('basket', 'shop', shx + 44),
      prop('fruitTable', 'shop', shx + 52),
      prop('barrels', 'shop', shx + 94),
      prop('crates2', 'shop', shx + 118),
      // The troops' rest: the tent, the pot over the campfire before its right side, its 32 px of art ending at the
      // tent's (decisions-log 271; at +70 until then, 6 past it, where the wood corner now starts).
      whole('tent', 'tent', townTent, 96, 121, tent),
      piece('campfire', 'tent', townCampfire, (x: 0, y: 0, w: fire, h: fire), tent + _townTentW - fire,
          frames: townCampfireFrames),
      ...door,
    ];
  }

  /// The Dungeon's door ([_townDoorW]): the mound's cells (its top row the block's moss-topped corners and top, the two
  /// under it its sides and fill), the portal at its foot, the boulder piles over its lower corners and the two standing
  /// torches, back to front.
  List<_TownPiece> get door {
    final x0 = left['dungeon']!, block = dungeonTileCells['block']!, f = dungeonPortalFrame;
    _TownPiece prop(String name, String kind, double x) {
      final s = dungeonPropCells[kind]!;
      return (name: name, place: 'dungeon', file: dungeonProps, src: (x: s.x, y: s.y, w: s.w, h: s.h), frames: dungeonPropFrames[kind] ?? 1,
          x: x, blank: (0, 0), up: 0.0);
    }

    return [
      for (var row = 0; row < 3; row++)
        for (var i = 0; i < _townDoorCols; i++)
          (
            name: 'mound$row$i',
            place: 'dungeon',
            file: dungeonTiles,
            src: (x: block.x + 32 * (i == 0 ? 0 : i == _townDoorCols - 1 ? 2 : 1), y: block.y + 32 * (row == 0 ? 0 : 1), w: 32, h: 32),
            frames: 1,
            x: x0 + _townDoorMound + 32.0 * i,
            blank: (0, 0),
            up: 32.0 * (2 - row),
          ),
      (name: 'portal', place: 'dungeon', file: dungeonPortal, src: (x: 0, y: 0, w: f, h: f), frames: dungeonPortalFrames,
          x: x0 + _townDoorMid - f / 2, blank: (0, 0), up: 0.0),
      prop('boulderL', 'boulder', x0),
      prop('boulderR', 'boulder', x0 + _townDoorW - 88),
      prop('torchL', 'standTorch', x0 + _townDoorMid - 35),
      prop('torchR', 'standTorch', x0 + _townDoorMid + 45),
    ];
  }

  /// The identity's yard ([_townYards]; Millbrook's for a key it doesn't know).
  List<(String, String, double)> get yard => _townYards[identity] ?? _townYards['millbrook']!;

  /// How many of [pieces] stand behind the buildings: the yard's.
  int get behindHouses => yard.length;

  /// The middle of [place] along the street, in world px: what a sign hangs over. A building's is its house's (the
  /// Smithy's wood corner stands on its left, its furnace and the ore on its right).
  double mid(String place) => switch (place) {
        'smithy' => smithyHouse + houseSeen(_townSmallN) / 2,
        'shop' => left[place]! + houseSeen(_townSmallN) / 2,
        'tavern' => left[place]! + houseSeen(n) / 2,
        'dungeon' => left[place]! + _townDoorMid,
        _ => left[place]! + width[place]! / 2,
      };

  /// What a pan centres for [place], in world px: its [mid], the Smithy's its house's walls and its furnace together,
  /// so a narrow screen shows both.
  double look(String place) => place == 'smithy' ? (smithyHouse + 10 + furnaceX + 54) / 2 : mid(place);

  /// The next step's anchors along the street (world px; everyone stands on the street, [_townGround]): 'guard' at the
  /// Town's left end, 'tent' at the tent's mouth (the rest), 'smithy' before the furnace (outside the house),
  /// 'tavernDoor' at the Tavern's door, 'talk' before the Tavern's right side, 'shop' before the fruit table.
  Map<String, double> get spots => {
        'guard': left['tent']! + 12,
        'tent': left['tent']! + 48,
        'smithy': furnaceX + 32,
        'tavernDoor': left['tavern']! - 22 + 3 * 16 + 8,
        'talk': left['tavern']! + houseSeen(n) - 36,
        'shop': left['shop']! + 72,
      };
}

/// The Town scene between frames ([Board._town]).
class _TownView {
  Game? game; // the game last seen: another one (a new game, a save) shows its own scene at once, no fade
  bool target = false; // whether that game was in a Town last frame
  bool shown = false; // the Town shows instead of the field (in a fade, the old scene until its middle)
  double fadeAt = double.negativeInfinity; // when the last fade began, on the screen clock
  bool book = true; // the book open in the Town (a tap on the scene shuts it, a sign or a place opens it)
  String shutOn = 'smithy'; // the place of the page the book was on when it shut: a shut book's view centres it
  double camFrom = 0, camTo = 0, panAt = double.negativeInfinity; // the view's left edge (world px): the pan's ends, its start
  double aim = 0; // where the page's own pan last headed ([Board._townCamTo]): the player's pan holds until it moves
  bool snap = true; // the next pan's end is taken at once: the scene just came
  // The player's pan (decisions-log 264): a press on the scene nothing else took, its tap waiting for it to come up
  // unmoved ([Board._townTap]); whether its drag goes on, and has taken hold (moved [_townSlop]: it pans, no tap); a
  // trackpad's swipe that began over the scene.
  Offset? press;
  bool dragging = false, held = false, swiping = false;
  double k = 2; // screen px per world px this frame
  Rect strip = Rect.zero; // the scene's own room on the screen: the whole of it
  double lane = 0; // the street's line on the screen (where feet stand)
  final at = <String, Rect>{}; // the pieces and the places drawn this frame, by name, and 'scene', 'street'
  final hits = <String, List<Rect>>{}; // each place's tap boxes this frame: its house's and each of its pieces' art
  final signs = <String, Rect>{}; // the signs drawn this frame: 'smithy', 'tavern', 'shop'
  final buildings = <String, List<(String, Rect)>>{}; // each building's cells drawn this frame, in order
  final shapes = <String, (int, int)>{}; // each building drawn: (n, storeys)
  final spots = <String, Offset>{}; // the anchors on the screen this frame ([_TownLayout.spots])
  final clouds = <Rect>[]; // the clouds' copies drawn this frame ([Board._townClouds])
  final ground = <String, Rect>{}; // the ground drawn this frame: 'strip' and 'earth' under it ([_townStreet])
  Rect window = Rect.zero; // the Tavern's window's bubble this frame (town_life.dart; Rect.zero: none)

  void clear() {
    at.clear();
    hits.clear();
    signs.clear();
    buildings.clear();
    shapes.clear();
    spots.clear();
    clouds.clear();
    ground.clear();
    lane = 0;
    window = Rect.zero;
  }
}

extension _TownScene on Board {
  /// Whether the Town shows instead of the field this frame.
  bool get _townShown => _town.shown;

  /// Whether the fade between the field and a Town runs: Auto's wave waits for it.
  bool get _townFading => _clock - _town.fadeAt < 2 * _townFade;

  /// The page a shut book opens on: the Smithy in a Town, else the Army.
  _Page get _home => state.inTown ? _Page.smithy : _Page.troops;

  /// The book's tabs, left to right, as (icon, page): the field's Army, Bag and Settings (the owner's order; the Shop is
  /// a Town's, decisions-log 224, and the field's Toko went in decisions-log 296); in a Town Smithy (a null icon: the Town's
  /// hammer), the Tavern (its mug: decisions-log 267, as the street's order), Shop, the Dungeon (the portal: decisions-log
  /// 337, its door at the street's far end), then the field's own three in its
  /// order: Army (decisions-log 301; the owner, 2026-10-09: "di town tab army harus di munculkan"; the tent opens it,
  /// [_townTap]), Bag and Settings.
  List<(Offset?, _Page)> _bookTabs(Game g) => g.inTown
      ? [
          (null, _Page.smithy),
          (null, _Page.tavern),
          (_icCoins, _Page.store),
          (null, _Page.dungeon),
          (Board._icSwords, _Page.troops),
          (Board._icBag, _Page.bag),
          (Board._icGear, _Page.settings),
        ]
      : [
          (Board._icSwords, _Page.troops),
          (Board._icBag, _Page.bag),
          (Board._icGear, _Page.settings),
        ];

  /// The Town's turn in the Board's update, after a Town was gone into or left ([_townTick]): a change of [Game.inTown]
  /// starts the fade (another game shows its own scene at once); the book's pages follow (a Town gone into, or a game
  /// that comes in in one, opens on the Smithy from the Army, whose tab it has since decisions-log 301; the field has no
  /// Smithy, Tavern or Shop); and the pan heads for the open page's place. As the field comes back from a Town the troops
  /// its boosts touch burst ([_boostBursts]).
  void _townSync(Game g) {
    final v = _town;
    var came = false; // a Town gone into this frame, or a game that comes in in one
    if (!identical(g, v.game)) {
      v
        ..game = g
        ..target = g.inTown
        ..fadeAt = double.negativeInfinity
        ..book = true;
      came = g.inTown;
    } else if (g.inTown != v.target) {
      v
        ..target = g.inTown
        ..fadeAt = _clock;
      if (g.inTown) v.book = came = true;
    }
    final was = v.shown;
    v.shown = _clock - v.fadeAt < _townFade ? !v.target : v.target;
    if (came && _page == _Page.troops) _open(_Page.smithy);
    if (!g.inTown && (_page == _Page.smithy || _page == _Page.tavern || _page == _Page.store || _page == _Page.dungeon)) _open(_Page.troops);
    if (!v.shown) {
      if (was && v.fadeAt.isFinite) _boostBursts(g); // the field back from a Town: its boosts' troops burst (tavern_look.dart)
      return v.clear();
    }
    if (!was) {
      v
        ..snap = true
        ..press = null // a press from before it showed is not its tap, nor its pan
        ..dragging = v.held = v.swiping = false;
      _pinned = null; // no plate over the Town (plates.dart)
      _townLife.reset(); // its troops come in afresh (town_life.dart)
    }
    final to = _townCamTo();
    if (v.snap) {
      v
        ..camFrom = v.camTo = v.aim = to
        ..panAt = double.negativeInfinity
        ..snap = false;
    } else if (to != v.aim) {
      _townReaim();
    }
  }

  /// The pan heads for the open page's place ([_townCamTo]) from where the view is now: the page or the book changed,
  /// or a tap opened a page (decisions-log 264: a pan by the player holds until then).
  void _townReaim() {
    final v = _town, to = _townCamTo();
    v
      ..aim = to
      ..camFrom = _townCam
      ..camTo = to
      ..panAt = _clock;
  }

  /// The view's left edge now, in world px: on its way ([_townPan] s, easing out) to [_townCamTo].
  double get _townCam {
    final v = _town, p = ((_clock - v.panAt) / _townPan).clamp(0.0, 1.0);
    return v.camFrom + (v.camTo - v.camFrom) * (1 - math.pow(1 - p, 3));
  }

  /// Where the view's left edge goes: with the book open the open page's place's ([_townPlace]) middle sits in the middle
  /// of the strip left of the book, and with it shut the place of the page
  /// it shut on ([_TownView.shutOn]: the shut book goes back to the Smithy's page, [_home]) in the middle of the screen,
  /// the view kept between the Town's ends (a screen as wide as the Town or wider shows it all: decisions-log 271; until
  /// then a shut book showed the whole Town, which fitted).
  double _townCamTo() {
    final f = _townFrame(), place = _townPlace(_page), screen = size.x / f.k;
    if (!_town.book) {
      return (f.layout.look(_town.shutOn) - screen / 2).clamp(0.0, math.max(0.0, f.layout.viewW - screen));
    }
    return f.layout.look(place) - _bookFit().rest.left / 2 / f.k;
  }

  /// The place a pan to [page] shows: the Smithy for Smithy, the Shop for Shop, the tent (the troops' rest) for Army
  /// (decisions-log 301), the door for the Dungeon (decisions-log 337), the Tavern for the rest.
  String _townPlace(_Page page) => switch (page) {
        _Page.smithy => 'smithy',
        _Page.store => 'shop',
        _Page.troops => 'tent',
        _Page.dungeon => 'dungeon',
        _ => 'tavern',
      };

  /// The scene's frame on this screen: its [strip] (the whole screen), [k] screen px per world px (2, or 3 from about
  /// 1040 px tall; no more than lets [_TownLayout.fit] across, 1 at the least), the layers' [top] on the screen (the
  /// street [_townStreetDown] of the way down) and the [layout] (as wide as the screen, [_TownLayout.full] at the least).
  ({Rect strip, double k, double top, _TownLayout layout}) _townFrame() {
    final strip = Offset.zero & Size(size.x, size.y);
    final tall = math.max(2.0, (strip.height / townLayerH).floorToDouble());
    final k = math.max(1.0, math.min(tall, (size.x / _TownLayout.fit).floorToDouble()));
    final street = (strip.height * _townStreetDown).roundToDouble();
    return (
      strip: strip,
      k: k,
      top: street - _townGround * k,
      layout: _TownLayout(size.x / k, street / k, state.sceneIdentity.key),
    );
  }

  /// Draws the Town where the field was, from [_townCam] (render's first part while [_townShown]), and records where
  /// everything is ([townScene], [townSign], [townBuilding], [townSpot], [townLane]).
  void _townScene(Canvas c, Game g) {
    final v = _town..clear(), f = _townFrame(), k = f.k, L = f.layout, cam = _townCam, top = f.top;
    v
      ..k = k
      ..strip = f.strip
      ..lane = top + _townGround * k;
    v.at['scene'] = f.strip;
    final lw = townLayerW.toDouble(), lh = townLayerH.toDouble(), w = lw * k;
    final art = townSeasonArt[g.sceneIdentity.season]!; // the Town's season's (decisions-log 326)
    // The sky over the layers' top: layer 5's top row stretched up (its own colour); from the street down the ground
    // ([_townStreet]) to the view's bottom.
    if (top > 0) c.drawImageRect(_img(art.layers[4]), Rect.fromLTWH(0, 0, lw, 1), Rect.fromLTRB(0, 0, size.x, top + 1), _px);
    for (final (file, par) in _townParallax(art)) {
      final img = _img(file), src = Rect.fromLTWH(0, 0, lw, lh), shift = (cam * par * k).roundToDouble();
      if (file == art.castle) {
        c.drawImageRect(img, src, Rect.fromLTWH(-shift, top, w, lh * k), _px); // one castle, not a row of them
        continue;
      }
      for (var x = -(shift % w); x < size.x; x += w) {
        c.drawImageRect(img, src, Rect.fromLTWH(x, top, w, lh * k), _px);
      }
      if (file == art.layers.last) _townClouds(c, cam, top, k); // over the sky, under the mountains
    }
    // The ground, then the buildings and the pieces standing on it, their bottoms on the street's line.
    final ox = -(cam * k).roundToDouble();
    _townStreet(c, ox, k, art.ground);
    final frame = (_fieldClock * _townFps).floor(), pieces = L.pieces;
    void put(_TownPiece p) {
      final s = p.src, n = frame % p.frames;
      final to = Rect.fromLTWH(ox + (p.x * k).roundToDouble(), top + (_townGround - s.h - p.up) * k, s.w * k, s.h * k);
      c.drawImageRect(_img(p.file), Rect.fromLTWH((s.x + n * s.w).toDouble(), s.y.toDouble(), s.w.toDouble(), s.h.toDouble()), to, _px);
      v.at[p.name] = to;
      if (p.place case final place?) {
        final art = Rect.fromLTRB(to.left + p.blank.$1 * k, to.top, to.right - p.blank.$2 * k, to.bottom);
        v.at[place] = v.at[place]?.expandToInclude(art) ?? art;
        (v.hits[place] ??= []).add(art);
      }
    }

    pieces.take(L.behindHouses).forEach(put);
    for (final (place, n, storeys, x, props) in L.buildings) {
      final at = Offset(ox + (x * k).roundToDouble(), top + (_townGround - houseSize(n, storeys).$2) * k);
      _townHouse(c, place, n, storeys, props, at, k);
    }
    _townSmith(c, L, ox, top - townStep * k, k); // the smith at his anvil, on the Smithy's floor (town_smith.dart)
    pieces.skip(L.behindHouses).forEach(put);
    _townFolk(c, L, ox, k, up: true); // the troops inside (the Tavern's doorway, the tent's opening): behind
    _townFolk(c, L, ox, k, up: false); // the troops on the street and their bubbles (town_life.dart)
    // The signs over their buildings' roofs, kept under the HUD's rows; at 2 screen px a sprite px at least, to be read.
    final sk = math.max(2.0, k);
    for (final (place, word) in [('smithy', Words.smithy), ('tavern', Words.tavern), ('shop', Words.shop), ('dungeon', Words.dungeon)]) {
      final roof = (v.buildings[place]?.first.$2 ?? v.at[place]!).top, y = math.max(roof - 24 * sk, _meterBottom + 4);
      v.signs[place] = _ribbonTitle(c, word, Offset(ox + (L.mid(place) * k).roundToDouble(), y + 10 * sk), sk, 64 * sk);
    }
    _townArrival(c, g, sk); // the Town's name as it comes up (town_look.dart)
    for (final MapEntry(key: name, value: x) in L.spots.entries) {
      v.spots[name] = Offset(ox + (x * k).roundToDouble(), v.lane);
    }
  }

  /// The street (decisions-log 279): [tile] ([townGroundTile], or the Town's season's: decisions-log 326) at [k] screen
  /// px a px, its top edge on the street's line
  /// ([_TownView.lane]), side by side across the view and moving with the street ([ox]: its left on the screen), so it
  /// runs the Town's whole width as it pans ('street' in [townScene]; 'strip' in [townGround]); under it the tile's
  /// last row, the earth's one colour, down to the view's bottom ('earth').
  void _townStreet(Canvas c, double ox, double k, String tile) {
    final v = _town, img = _img(tile), w = townGroundW * k;
    final strip = Rect.fromLTWH(0, v.lane, size.x, townGroundH * k);
    final src = Rect.fromLTWH(0, 0, townGroundW.toDouble(), townGroundH.toDouble());
    for (var x = ox % w - w; x < size.x; x += w) {
      c.drawImageRect(img, src, Rect.fromLTWH(x, strip.top, w, strip.height), _px);
    }
    final earth = Rect.fromLTRB(0, strip.bottom, size.x, math.max(strip.bottom, size.y));
    c.drawImageRect(img, Rect.fromLTWH(0, townGroundH - 1.0, townGroundW.toDouble(), 1), earth, _px);
    v.at['street'] = strip;
    v.ground.addAll({'strip': strip, 'earth': earth});
  }

  /// The clouds over the Town's sky (decisions-log 274; the owner, 2026-10-08: "pada scene town tambahkan awan"): the
  /// field's battle_clouds.png ([cloudCopies]), at [k] screen px a px like the layers, its row 0 [_townCloudsUp] over
  /// theirs ([top] on the screen), between the sky and the mountains (they and the pines hide the clouds' lower parts).
  /// They drift left [_cloudDrift] world units ([_cloudDrift] / [_layerK] px) a second on the field's clock, as on the
  /// field, and move at [_cloudK] of the Town's pan ([cam], world px), wrapping round.
  void _townClouds(Canvas c, double cam, double top, double k) {
    final img = _img('battle_clouds.png'), w = battleCloudsW * k;
    final src = Rect.fromLTWH(0, 0, battleCloudsW.toDouble(), battleCloudsH.toDouble());
    final shift = ((cam * _cloudK + _fieldClock * _cloudDrift / _layerK) * k).roundToDouble();
    for (var x = -(shift % w); x < size.x; x += w) {
      final to = Rect.fromLTWH(x, top - _townCloudsUp * k, w, battleCloudsH * k);
      c.drawImageRect(img, src, to, _px);
      _town.clouds.add(to);
    }
  }

  /// [place]'s building rebuilt cell by cell ([houseCells]) from town_house.png, a house of [n] and [storeys], its
  /// grid's top left at [at], [k] screen px a sprite px; with [props] its props from town_props.png ([houseProps]).
  void _townHouse(Canvas c, String place, int n, int storeys, bool props, Offset at, double k) {
    final v = _town, atlas = _img(townHouse), cells = v.buildings[place] = [];
    v.shapes[place] = (n, storeys);
    for (final (name, col, row) in houseCells(n, storeys)) {
      final s = townHouseCells[name]!;
      final to = Rect.fromLTWH(at.dx + col * 16 * k, at.dy + row * 16 * k, s.w * k, s.h * k);
      c.drawImageRect(atlas, Rect.fromLTWH(s.x.toDouble(), s.y.toDouble(), s.w.toDouble(), s.h.toDouble()), to, _px);
      cells.add((name, to));
      v.at[place] = v.at[place]?.expandToInclude(to) ?? to;
    }
    (v.hits[place] ??= []).add(cells.map((c) => c.$2).reduce((a, b) => a.expandToInclude(b)));
    if (!props) return;
    final sheet = _img(townProps);
    for (final (name, x, bottom) in houseProps(n, storeys)) {
      final s = townPropCells[name]!;
      c.drawImageRect(sheet, Rect.fromLTWH(s.x.toDouble(), s.y.toDouble(), s.w.toDouble(), s.h.toDouble()),
          Rect.fromLTWH(at.dx + x * k, at.dy + (bottom - s.h) * k, s.w * k, s.h * k), _px);
    }
  }

  /// The fade's dim this frame (0: none): up to [_townDim] over [_townFade] s on the old scene, then down on the new one.
  double get _townDimNow {
    final t = _clock - _town.fadeAt;
    if (t < 0 || t >= 2 * _townFade) return 0;
    return _townDim * (t < _townFade ? t / _townFade : (2 * _townFade - t) / _townFade);
  }

  /// The fade's dim over the scene showing, under the HUD.
  void _townFadeDim(Canvas c) {
    final a = _townDimNow;
    if (a <= 0) return;
    c.drawRect(Rect.fromLTWH(0, 0, size.x, size.y), Paint()..color = Colors.black.withValues(alpha: a));
  }

  /// How far the player may pan the Town (decisions-log 264): the view's left edge from the Town's left end at the
  /// screen's left to its right end at the right of what shows of it (with the book open the book's left, else the
  /// screen's), in world px; never so tight that the open page's own pan ([_town.aim]) falls outside it. A
  /// screen as wide as the Town or wider shows it all with the book shut, so nothing moves there.
  (double, double) _townRoom() {
    final f = _townFrame(), aim = _town.aim, shows = (_town.book ? _bookFit().rest.left : size.x) / f.k;
    return (math.min(0.0, aim), math.max(f.layout.viewW - shows, aim));
  }

  /// The player's pan puts the view's left edge at [cam] world px, kept in [_townRoom]: at once (a drag), or with
  /// [glide] easing there over [_townPan] s from where it is (a fling, the wheel).
  void _townPanTo(double cam, {bool glide = false}) {
    final (lo, hi) = _townRoom();
    final to = cam.clamp(lo, hi);
    _town
      ..camFrom = glide ? _townCam : to
      ..camTo = to
      ..panAt = glide ? _clock : double.negativeInfinity;
  }

  /// Whether [p] is on the Town's own scene for the wheel or a trackpad's swipe to pan: it shows, under the HUD's band
  /// and outside the book, the battle log's open panel, the troop counter and its open list, a message and the boss
  /// chest's popup.
  bool _townPans(Offset p) {
    final v = _town;
    if (!v.shown || !state.inTown || welcome != null || !v.strip.contains(p) || p.dy < _meterBottom) return false;
    if (_chest.open || _chest.reveal != null || (_msg.text != null && _msg.at.contains(p))) return false;
    return ![_bookArea, _troops.button, _log.button, if (_log.open) _log.panel, if (_troops.open) _troops.list]
        .any((r) => r.contains(p));
  }

  /// A press that nothing over the Town took ([Board.onTapDown]): on its scene outside the book it waits, its tap
  /// ([_townTap]) for it to come up unmoved ([_townTapUp], [_townLetGo]); a drag from it under the HUD's band pans.
  void _townDown(Offset p) {
    final v = _town;
    if (v.shown && state.inTown && welcome == null && v.strip.contains(p) && !_bookArea.contains(p) && !_log.tapped) {
      v.press = p;
    }
  }

  /// The press came up without a drag: its tap ([_townTap]); a page it opened is panned to, even the open one.
  void _townTapUp() {
    final p = _town.press;
    _town.press = null;
    if (p != null && _townTap(p)) _townReaim();
  }

  /// A drag began ([Board.onDragStart]): true when it is the Town's, from a press on its scene under the HUD's band (a
  /// press over the band is a tap only: the HUD never pans the Town).
  bool _townGrab() {
    final v = _town, p = v.press;
    if (p == null || p.dy < _meterBottom) return false;
    v
      ..dragging = true
      ..held = false;
    return true;
  }

  /// The Town's drag moved to [p] by [delta] screen px: once [_townSlop] from the press it has taken hold (no tap then),
  /// and the scene follows the pointer from where it passed the slop (no jump).
  void _townDrag(Offset p, Offset delta) {
    final v = _town, from = v.press;
    if (!v.dragging || from == null) return;
    if (v.held) return _townPanTo(_townCam - delta.dx / v.k);
    final moved = p - from;
    if (moved.distance < _townSlop) return;
    v.held = true;
    _townPanTo(_townCam - moved.dx * (1 - _townSlop / moved.distance) / v.k);
  }

  /// The Town's drag (or with [swipe] a trackpad's swipe) ended at [velocity] screen px a second: a pan glides on as far
  /// as that speed carries it in [_townPan] s, easing out (its start as fast as the pointer); a drag that never took
  /// hold is a tap. True when it was the Town's.
  bool _townLetGo(Offset velocity, {bool swipe = false}) {
    final v = _town;
    if (!(swipe ? v.swiping : v.dragging)) return false;
    final pans = swipe || v.held;
    if (swipe) {
      v.swiping = false;
    } else {
      v.dragging = v.held = false;
    }
    if (!pans) {
      _townTapUp();
      return true;
    }
    if (!swipe) v.press = null;
    _townPanTo(_townCam - velocity.dx / v.k * _townPan / 3, glide: true);
    return true;
  }

  /// The wheel ([TdGame.onScroll]) or a trackpad's scroll by [d] screen px over the Town's scene ([_townPans]): it
  /// pans sideways by its sideways part, else its up-and-down one (a plain wheel: down goes right), gliding like a
  /// page's pan, the notches adding up.
  void _townWheel(Offset p, Offset d) {
    final by = d.dx.abs() > d.dy.abs() ? d.dx : d.dy;
    if (by == 0 || !_townPans(p)) return;
    _townPanTo(_town.camTo + by / _town.k, glide: true);
  }

  /// A trackpad's two-finger swipe began at [p] ([TdGame]'s trackpad drag: Flutter sends it as a pan, not a scroll):
  /// over the Town's scene it pans it until it ends ([_townLetGo]).
  void _townSwipe(Offset p) {
    _town.swiping = _townPans(p);
  }

  /// The trackpad's swipe moved [dx] screen px: the scene follows the fingers, as a drag.
  void _townSwiped(double dx) {
    if (_town.swiping) _townPanTo(_townCam - dx / _town.k);
  }

  /// A tap on the Town that nothing over it took: a sign or its place opens the book on its page (the Shop's before it
  /// opens says when it does), the troops' rest (the tent and its campfire, no sign) the Army's (decisions-log 301; the
  /// owner, 2026-10-09: "ketika user tenda maka akan ke tab army"; until then it shut the book as the bare scene does);
  /// anywhere else under the HUD's band and outside the book shuts the book. True when it did something. It acts as the
  /// press comes up unmoved ([_townTapUp]): a drag pans instead (decisions-log 264).
  bool _townTap(Offset p) {
    final v = _town, g = state;
    if (!v.shown || !g.inTown || welcome != null || !v.strip.contains(p) || _bookArea.contains(p)) return false;
    for (final (place, page) in _townPages) {
      if (!(v.signs[place]?.contains(p) ?? false) && !(v.hits[place]?.any((r) => r.contains(p)) ?? false)) continue;
      Sounds.play(Sfx.click);
      if (page == _Page.store && !g.storeOpen) {
        showMessage(g.storeWhy(StoreRefusal.locked));
        return true;
      }
      v.book = true;
      _open(page);
      return true;
    }
    if (!v.book || p.dy < _meterBottom) return false;
    v
      ..book = false
      ..shutOn = _townPlace(_page);
    return true;
  }

  /// Where a press acts on the Town this frame (the signs and the places, the tent's too): the cursor's hand.
  List<Rect> get _townTaps => !_town.shown || !state.inTown
      ? const []
      : [..._town.signs.values, for (final (place, _) in _townPages) ...?_town.hits[place]];
}
