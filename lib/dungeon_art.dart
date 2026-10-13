// The Dungeon's cave art (decisions-log 336, 337; docs/assets.md "Packs -> files"): GandalfHardcore's FREE
// Platformer Assets, cut into assets/images by tool/import_dungeon.py, which writes this file from the same tables.
// Never edit it by hand: `python3 tool/import_dungeon.py --check` fails while it differs. Sizes are in sprite px.

/// A cell of an atlas: its rect in the file.
typedef DungeonCell = ({int x, int y, int w, int h});

/// The cave's pieces ([dungeonTileCells]), 256x169: the fill, the moss lip, the ledge, the stalactites, the
/// floor band's earth, the back wall's slab and pillar.
const dungeonTiles = 'dungeon_tiles.png';

/// Each piece's rect in [dungeonTiles].
const dungeonTileCells = <String, DungeonCell>{
  'pillar': (x: 0, y: 0, w: 32, h: 128),
  'slab': (x: 33, y: 0, w: 160, h: 95),
  'stalactites': (x: 0, y: 129, w: 64, h: 40),
  'ledge': (x: 194, y: 0, w: 32, h: 32),
  'moss': (x: 65, y: 129, w: 32, h: 14),
  'earth': (x: 227, y: 0, w: 8, h: 8),
  'fill': (x: 236, y: 0, w: 8, h: 8),
};

/// The props ([dungeonPropCells]), 256x99: an animation's next frames beside its first, [dungeonPropFrames]
/// of them.
const dungeonProps = 'dungeon_props.png';

/// Each prop's (first frame's) rect in [dungeonProps].
const dungeonPropCells = <String, DungeonCell>{
  'boulder': (x: 0, y: 0, w: 88, h: 40),
  'ore0': (x: 89, y: 0, w: 53, h: 38),
  'ore1': (x: 143, y: 0, w: 53, h: 38),
  'ore2': (x: 197, y: 0, w: 53, h: 38),
  'ore3': (x: 0, y: 41, w: 53, h: 38),
  'torch': (x: 54, y: 41, w: 12, h: 31),
  'cross': (x: 127, y: 41, w: 21, h: 27),
  'grave0': (x: 149, y: 41, w: 23, h: 24),
  'grave1': (x: 173, y: 41, w: 21, h: 24),
  'grave2': (x: 195, y: 41, w: 22, h: 21),
  'rocks': (x: 0, y: 80, w: 52, h: 19),
  'rock': (x: 218, y: 41, w: 30, h: 15),
  'pebbles': (x: 53, y: 80, w: 19, h: 5),
};

/// The props' frames, an animation's (the others one).
const dungeonPropFrames = <String, int>{'torch': 6};

/// The stairs down: the Portal sheet, [dungeonPortalFrames] frames of [dungeonPortalFrame]x[dungeonPortalFrame] in a row.
const dungeonPortal = 'dungeon_portal.png';
const dungeonPortalFrame = 64, dungeonPortalFrames = 10;

/// Every file of the Dungeon's cave.
const dungeonImages = [dungeonTiles, dungeonProps, dungeonPortal];
