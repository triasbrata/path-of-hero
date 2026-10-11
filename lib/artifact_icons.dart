part of 'game.dart';

// The Artifacts' (Pusaka) icons (decisions-log 194, docs/loot-items-relics.md "The icons"): one atlas,
// assets/images/artifact_icons.png, single icons of Kenmi's "Cute Fantasy Icons Premium", a 32 px cell each (the
// pack's 16 px art doubled, as the loot icons), [artifactIconCols] a row, in [artifactIconKinds]' order.
// tool/import_fx.py (ARTIFACTS) writes it from the bought pack; test/pusaka_catalog_test.dart checks the two orders
// agree. Every kind of the catalog has its cell now, built or not, so a data batch's row says `artifactIcon('<kind>')`.
// Each its own icon, none an item's or a small relic's look; the rarity shows by the frame, so none is tinted.

/// The atlas's cells a row.
const artifactIconCols = 10;

/// The atlas's kinds, cell by cell: the catalog's 30 Langka, 30 Epik and 30 Legenda (catalog-design §3), a built one
/// by its [Relic]'s name, the others by their catalog constant's stem (`titanBaneK`: 'titanBane').
const artifactIconKinds = [
  // Langka
  'ironBanner', 'bloodFang', 'warDrum', 'mourningBell', 'titanBane', 'finishingBlade', 'firstCut', 'shellCracker',
  'momentum', 'twinFury', 'bleedingEdge', 'shatterShard', 'painCrystal', 'steadyStance', 'turtleShell', 'watchShield',
  'boneBuckler', 'dullingMail', 'challengeLetter', 'riposte', 'saltCharm', 'wolfFeast', 'fullCup', 'hiddenFlask',
  'livingMoss', 'pureWater', 'manaLeech', 'lootersPouch', 'spellCutter', 'snareCord',
  // Epik
  'grail', 'dragonHeart', 'voidEye', 'godThunder', 'dawnStar', 'healerBane', 'bullyClub', 'emberBrand', 'funeralPyre',
  'unityRing', 'runeGauntlet', 'hawkFeather', 'nullStone', 'fallenFlag', 'manaHymn', 'witherroot', 'aegisSeal',
  'arrowCatcher', 'wardensHorn', 'stoneCoat', 'anchor', 'heroCloak', 'saintTear', 'braveSong', 'haloLantern', 'hearth',
  'heartbeat', 'mercyLily', 'brightSpring', 'moonwell',
  // Legenda
  'dragonCrown', 'oathOfOne', 'alliance', 'fewOath', 'wallOath', 'bloodOath', 'vanguardOath', 'kingsOath', 'spellOath',
  'loneWolf', 'martyrFlame', 'wideBlows', 'champion', 'rageTotem', 'vengeance', 'mirror', 'guardianChain', 'ghostStep',
  'phalanx', 'vampireKiss', 'wrathPsalm', 'phoenix', 'soulShelter', 'manaFont', 'iceGrip', 'graveSeal', 'relicAltar',
  'hexBlade', 'vowSilence', 'glorySeeker',
];

/// [kind]'s cell of the atlas; throws on a kind the atlas doesn't hold.
IconRef artifactIcon(String kind) {
  final i = artifactIconKinds.indexOf(kind);
  if (i < 0) throw ArgumentError.value(kind, 'kind', 'not in artifact_icons.png');
  return IconRef('artifact_icons.png', x: i % artifactIconCols * 32, y: i ~/ artifactIconCols * 32);
}
