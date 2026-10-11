// The Smithy's smith (decisions-log 265; docs/assets.md "Packs -> files"): the Mana Seed Character Base demo's
// paper doll with its mace for a hammer, at Pixel Crawler's anvil, cut into assets/images by tool/import_smith.py,
// which writes this file from the same tables. Never edit it by hand: `python3 tool/import_smith.py --check` fails
// while it differs. Sizes are in sprite px, drawn at 1 world px a sprite px (the house's).

/// The smith hammering at his anvil, facing right: [townSmithFrames] frames of [townSmithW]x[townSmithH] in a row
/// (backswing 0, raised 1, swing 2, strike 3, rest 4), the anvil in each.
const townSmith = 'town_smith.png';
const townSmithW = 55, townSmithH = 32, townSmithFrames = 5;

/// Where his feet stand in a frame: the middle of his body, on the row under his feet (the anvil's foot is on it
/// too).
const townSmithFeet = (x: 20, y: 32);

/// The loop, each frame in turn for its ms (the pack's own timing): the backswing, three blows (the hammer up, the
/// swing, the strike on the horn), the pause; [townSmithLoopMs] in all.
const townSmithBeats = [
  (frame: 0, ms: 160), // backswing
  (frame: 1, ms: 400), // raised
  (frame: 2, ms: 80), // swing
  (frame: 3, ms: 200), // strike
  (frame: 1, ms: 400), // raised
  (frame: 2, ms: 80), // swing
  (frame: 3, ms: 200), // strike
  (frame: 1, ms: 400), // raised
  (frame: 2, ms: 80), // swing
  (frame: 3, ms: 200), // strike
  (frame: 4, ms: 800), // rest
];
const townSmithLoopMs = 3000;
