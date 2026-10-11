import 'package:flutter/painting.dart';

// The game's typeface (decisions-log 158 and 179; docs/ui-hud.md "The font"): Poh Sans, a Modified Version of Pixelify
// Sans by Stefie Justprince (the itch page's header font) under the SIL Open Font License 1.1. Pixelify Sans grows
// bolder by growing every pixel on its grid, so a one-pixel gap blurs shut at the HUD's sizes: "Cara Main" read "Oara
// Main", "Kocok" "Koook", "Bos" "Gos", "+5%" "+S%". Poh Sans is that font with its 2, 3, 5, 6, 9, B, C, G, S, Z, a, c
// and i redrawn so that every two letters and digits read apart, and nothing else changed: its kerning, its metrics and
// its other glyphs are Pixelify Sans's (tool/make_poh_sans.py writes it from google/fonts' file; CREDITS.md has both
// sha256). Every text the game draws takes its style from [hudStyle], so the family, the scale and the weights live
// here and in pubspec.yaml.

/// pubspec.yaml's font family.
const hudFont = 'PohSans';

/// The font's file (the tests load it themselves: a test has no bundled fonts) and its licence, which the Lisensi page
/// shows (lib/licences.dart): the OFL, after what was changed and from what.
const hudFontAsset = 'assets/fonts/PohSans.ttf', hudFontLicence = 'assets/fonts/OFL-PohSans.txt';

/// The drawn size per HUD size. The HUD's sizes were set for the old 5×9 face (Kenmi's CuteFantasy, until
/// decisions-log 158); Pixelify Sans is about 1.25× as wide at one size (its lower case 5 font pixels tall, the old one's
/// 3), so it draws at 0.8 × the size it is given and runs about as wide as the old face did: the layouts and the fit
/// helpers keep their numbers.
const hudFontScale = 0.8;

/// The font's pixel: its glyphs are drawn on a grid of 1000/11 units of its 1000-unit em, so one font pixel is
/// `drawn size / 11` (cap height 7 font pixels, x-height 5, descenders 2).
const hudFontGrid = 11.0;

/// The body text's weight, and the titles' (the itch page's pair). The font is variable (wght 400 to 700), and a
/// [FontWeight] sets its axis.
const hudBody = FontWeight.w500, hudBold = FontWeight.w700;

/// The style of a text the game draws at HUD size [size] (drawn at [hudFontScale] × it), in the body weight or, with
/// [bold], the titles'. Without the font's standard ligatures ([hudFeatures]).
TextStyle hudStyle(double size, {Color? color, Paint? foreground, double? height, bool bold = false}) => TextStyle(
    fontFamily: hudFont,
    fontSize: size * hudFontScale,
    fontWeight: bold ? hudBold : hudBody,
    fontFeatures: hudFeatures,
    color: color,
    foreground: foreground,
    height: height);

/// The font's standard ligatures off (decisions-log 172): its "fi", "fl" and "ff" are each one glyph one letter wide,
/// so the f and the i share five font pixels, and the gap between them, one pixel, blurs shut ("The fight" read "The
/// Aght" on the guide's card). Each letter is drawn on its own.
const hudFeatures = [FontFeature.disable('liga')];
