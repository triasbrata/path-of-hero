// The Town scene's art (decisions-log 222; docs/assets.md "Packs -> files"): GandalfHardcore's FREE Platformer
// Assets, cut into assets/images by tool/import_town.py, which writes this file from the same tables. Never edit
// it by hand: `python3 tool/import_town.py --check` fails while it differs. Sizes are in sprite px.

/// A cell of an atlas: its rect in the file.
typedef TownCell = ({int x, int y, int w, int h});

/// The Normal BG parallax layers, 1 (the near pines and the ground) to 5 (the sky, opaque), each
/// [townLayerW]x[townLayerH], tiling sideways; the castle goes between layers 4 and 3.
const townLayers = ['town_bg_1.png', 'town_bg_2.png', 'town_bg_3.png', 'town_bg_4.png', 'town_bg_5.png'];
const townCastle = 'town_castle.png';
const townLayerW = 1024, townLayerH = 346;

/// The street (decisions-log 279): Floor Tiles2's grass top over its dark earth, [townGroundW]x[townGroundH], one
/// tile of its 32-px repeat, tiled along the street; its last row is the earth's one colour.
const townGroundTile = 'town_ground.png';
const townGroundW = 32, townGroundH = 14;

/// The house's 64 cells ([townHouseCells]), 8 a row of 16x16 (128x128): the scene rebuilds the
/// house from them cell by cell.
const townHouse = 'town_house.png';

/// Each house cell's rect in [townHouse], in the atlas's order (the porch row's are 16x8).
const townHouseCells = <String, TownCell>{
  'apexL': (x: 0, y: 0, w: 16, h: 16),
  'apexR': (x: 16, y: 0, w: 16, h: 16),
  'slopeL1o': (x: 32, y: 0, w: 16, h: 16),
  'slopeL1i': (x: 48, y: 0, w: 16, h: 16),
  'slopeR1i': (x: 64, y: 0, w: 16, h: 16),
  'slopeR1o': (x: 80, y: 0, w: 16, h: 16),
  'slopeL2o': (x: 96, y: 0, w: 16, h: 16),
  'slopeL2i': (x: 112, y: 0, w: 16, h: 16),
  'slopeR2i': (x: 0, y: 16, w: 16, h: 16),
  'slopeR2o': (x: 16, y: 16, w: 16, h: 16),
  'gable': (x: 32, y: 16, w: 16, h: 16),
  'slopeL3o': (x: 48, y: 16, w: 16, h: 16),
  'slopeL3i': (x: 64, y: 16, w: 16, h: 16),
  'slopeR3i': (x: 80, y: 16, w: 16, h: 16),
  'slopeR3o': (x: 96, y: 16, w: 16, h: 16),
  'eaveL1o': (x: 112, y: 16, w: 16, h: 16),
  'postL': (x: 0, y: 32, w: 16, h: 16),
  'postR': (x: 16, y: 32, w: 16, h: 16),
  'eaveR1o': (x: 32, y: 32, w: 16, h: 16),
  'eaveL0': (x: 48, y: 32, w: 16, h: 16),
  'wallL5a': (x: 64, y: 32, w: 16, h: 16),
  'wallR5b': (x: 80, y: 32, w: 16, h: 16),
  'eaveR0': (x: 96, y: 32, w: 16, h: 16),
  'wallL5b': (x: 112, y: 32, w: 16, h: 16),
  'wallR5a': (x: 0, y: 48, w: 16, h: 16),
  'wallL8a': (x: 16, y: 48, w: 16, h: 16),
  'wallL8b': (x: 32, y: 48, w: 16, h: 16),
  'brickLow': (x: 48, y: 48, w: 16, h: 16),
  'winTL': (x: 64, y: 48, w: 16, h: 16),
  'winTR': (x: 80, y: 48, w: 16, h: 16),
  'pipeTL': (x: 96, y: 48, w: 16, h: 16),
  'pipeTR': (x: 112, y: 48, w: 16, h: 16),
  'wallL9': (x: 0, y: 64, w: 16, h: 16),
  'doorTop': (x: 16, y: 64, w: 16, h: 16),
  'winBL': (x: 32, y: 64, w: 16, h: 16),
  'winBR': (x: 48, y: 64, w: 16, h: 16),
  'pipeBL': (x: 64, y: 64, w: 16, h: 16),
  'pipeBR': (x: 80, y: 64, w: 16, h: 16),
  'wallL10': (x: 96, y: 64, w: 16, h: 16),
  'doorMid': (x: 112, y: 64, w: 16, h: 16),
  'sillL': (x: 0, y: 80, w: 16, h: 16),
  'sillR': (x: 16, y: 80, w: 16, h: 16),
  'blockTL': (x: 32, y: 80, w: 16, h: 16),
  'blockTR': (x: 48, y: 80, w: 16, h: 16),
  'wallL11': (x: 64, y: 80, w: 16, h: 16),
  'doorLow': (x: 80, y: 80, w: 16, h: 16),
  'blockBL': (x: 96, y: 80, w: 16, h: 16),
  'blockBR': (x: 112, y: 80, w: 16, h: 16),
  'baseL': (x: 0, y: 96, w: 16, h: 8),
  'porchL': (x: 16, y: 96, w: 16, h: 8),
  'porch': (x: 32, y: 96, w: 16, h: 8),
  'baseRa': (x: 48, y: 96, w: 16, h: 8),
  'baseRb': (x: 64, y: 96, w: 16, h: 8),
  'creamL6': (x: 80, y: 96, w: 16, h: 16),
  'beamL': (x: 96, y: 96, w: 16, h: 16),
  'beam': (x: 112, y: 96, w: 16, h: 16),
  'beamJoint': (x: 0, y: 112, w: 16, h: 16),
  'beamR': (x: 16, y: 112, w: 16, h: 16),
  'beamREnd': (x: 32, y: 112, w: 16, h: 16),
  'creamL7a': (x: 48, y: 112, w: 16, h: 16),
  'creamL7b': (x: 64, y: 112, w: 16, h: 16),
  'brick': (x: 80, y: 112, w: 16, h: 16),
  'creamR7a': (x: 96, y: 112, w: 16, h: 16),
  'creamR7b': (x: 112, y: 112, w: 16, h: 16),
};

/// The Smithy: the furnace (row [townFurnaceRow]) and the sawmill (row [townSawmillRow]),
/// [townSmithyFrames] frames of [townSmithyFrame]x[townSmithyFrame] each.
const townSmithy = 'town_smithy.png';
const townSmithyFrame = 64, townSmithyFrames = 6, townFurnaceRow = 0, townSawmillRow = 1;

/// The pot over the campfire: [townCampfireFrames] frames of [townCampfireFrame]x[townCampfireFrame] a row,
/// [townCampfireLoops] rows (loops of the flame).
const townCampfire = 'town_campfire.png';
const townCampfireFrame = 32, townCampfireFrames = 5, townCampfireLoops = 8;

/// The troops' rest, the Large Tent (96x121), the blue ore rock (53x38) and the olive
/// pine (50x128: its cone and first tier over a tall trunk), each drawn whole.
const townTent = 'town_tent.png', townOre = 'town_ore.png', townPine = 'town_pine.png';

/// The props ([townPropCells]), 128x114.
const townProps = 'town_props.png';

/// Each prop's rect in [townProps].
const townPropCells = <String, TownCell>{
  'clothesLine': (x: 0, y: 0, w: 106, h: 62),
  'crates2': (x: 0, y: 63, w: 27, h: 32),
  'fruitTable': (x: 28, y: 63, w: 39, h: 30),
  'logPile': (x: 68, y: 63, w: 47, h: 21),
  'stumpAxe': (x: 107, y: 0, w: 21, h: 21),
  'barrels': (x: 0, y: 96, w: 29, h: 18),
  'crate': (x: 30, y: 96, w: 27, h: 16),
  'basket': (x: 58, y: 96, w: 17, h: 15),
  'cauldron': (x: 76, y: 96, w: 18, h: 15),
  'table': (x: 95, y: 96, w: 18, h: 11),
};

/// Every file of the Town scene.
const townImages = [
  ...townLayers,
  townCastle,
  townGroundTile,
  townHouse,
  townSmithy,
  townCampfire,
  townTent,
  townOre,
  townPine,
  townProps,
];
