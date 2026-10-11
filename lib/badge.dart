part of 'main.dart';

// The book's badge and its short numbers (decisions-log 187): ui_bars.png's capsule ([Board._capsule], [capsuleSize]),
// a count's and a price's short words ([shortCount], [shortPrice], [kPrice]); and the Shop's coin stack, gold ink and an
// Artifact's glow. The Bag, the Town's Shop (shop_page.dart), the Smithy, the chest's popup and the coach share them.
// Until decisions-log 296 this was store_page.dart, which also drew the book's Toko (the Shop of a game without the
// Towns: its goods in slots and the picked one's card); the Toko went with the Towns-off book.

/// The Shop's icon (a Town's Shop tab, Sell and Buy rows): ui_icons.png's coin stack.
const _icCoins = Offset(208, 48);

/// The store's gold ink (the Artifacts' names), and the glow behind an Artifact's icon.
const _storeGold = Color(0xFFB07A10), _artefactGlow = Color(0x66FFD54F);

/// ui_bars.png's capsules, 12x6 with a 1-px outline (181425) and their corners cut (decisions-log 187): the dark one,
/// filled 3F2832 (the book's badges, [Board._capsule]; a scroll bar's thumb; the units' HP bar), and the outline one,
/// empty inside (a scroll bar's track, [Board._capsuleBar]).
const _capsuleSrc = Rect.fromLTWH(82, 33, 12, 6), _capsuleTrack = Rect.fromLTWH(98, 33, 12, 6);

/// A list's scroll bar's width ([Board._capsuleBar]): the capsule's 6 px, at 1 screen px per sprite px.
const _capsuleBarW = 6.0;

/// A badge's size ([Board._capsule]) for a label [textW] px wide at text size [fs]: fs·1.3 tall (rounded), which holds
/// the text's line inside the outline; as wide as the label with [capsulePad] each side, and with an [icon] first a
/// square as tall as the inside and [capsuleGap] after it; the width rounded up to a whole pixel. For tests.
Size capsuleSize(double textW, double fs, {bool icon = false}) {
  final h = (fs * 1.3).roundToDouble(), k = capsuleK(h);
  return Size((2 * capsulePad(fs, k) + textW + (icon ? h - 2 * k + capsuleGap(fs) : 0)).ceilToDouble(), h);
}

/// A badge [h] px tall draws its capsule at this many screen px per sprite px: 1 up to 27 px tall, so its outline stays
/// one pixel beside the book's text.
double capsuleK(double h) => math.max(1.0, (h / 14).floorToDouble());

/// The room between a badge's outline and its label (or icon), each side, at text size [fs] and capsule scale [k].
double capsulePad(double fs, double k) => k + (fs * 0.25).roundToDouble();

/// The room between a badge's icon and its label at text size [fs].
double capsuleGap(double fs) => (fs * 0.15).roundToDouble();

/// A count as a slot's badge shows it ([Board._capsule]), so it fits a phone's slot at 10 px: up to 999 as is, then
/// "1.2k" (1234, cut, not rounded: a badge never shows more than there is), "12k", "123k".
String shortCount(int n) => n < 1000 ? '$n' : n < 10000 ? '${n ~/ 1000}.${n % 1000 ~/ 100}k' : '${n ~/ 1000}k';

/// A price as a slot shows it: 1000 as is, 12000 as "12k", 22500 as "22.5k", 150000 as "150k".
String shortPrice(int n) => n < 10000 ? '$n' : kPrice(n);

/// A price in thousands from 1000 on, for a tag short of room (the Army detail's "Recall 6k", decisions-log 237): 999 as
/// is, 6000 as "6k", 6500 as "6.5k", 22500 as "22.5k", 150000 as "150k".
String kPrice(int n) {
  if (n < 1000) return '$n';
  final k = n / 1000;
  return '${k >= 100 || k == k.roundToDouble() ? k.round() : k.toStringAsFixed(1)}k';
}

extension on Board {
  /// The book's badge (decisions-log 187): ui_bars.png's dark capsule ([_capsuleSrc]) 9-sliced 1 px at [capsuleK], with
  /// [label] in cream at text size [fs] ("x86", "★2"), then [tail] in Carve's gold ([ukirInk]: a Pusaka's Carve steps,
  /// "+3", decisions-log 196), and before them [icon]'s icon (a Pusaka's), all faded while [faded] (an asleep Pusaka's);
  /// [red] on the red capsule (the Smithy's material short of the picked recipe, decisions-log 235); [label] in [ink] where
  /// given (an enhanced stack's "+3" in its level's colour, decisions-log 255); [green] on the green capsule in the light
  /// tags' dark ink (a count set to sell in the Shop's basket, decisions-log 269). Its size is [capsuleSize]; [anchor] says
  /// which of its points is at [at] (top right: a slot's corner). Returns where it is; with [draw] false it only measures.
  Rect _capsule(Canvas c, String label, double fs, Offset at,
      {Anchor anchor = Anchor.topRight,
      Enum? icon,
      bool faded = false,
      bool draw = true,
      String? tail,
      bool red = false,
      bool green = false,
      bool tight = false,
      Color? ink}) {
    // [tight]: a small slot's count (the Smithy's 22-px materials, decisions-log 237): one row over the text and one
    // pixel beside it inside the outline, so a 2-digit count leaves most of a 16-px icon to read.
    final lw = _textWidth(label, fs), tw = lw + (tail == null ? 0 : _textWidth(tail, fs));
    final size = tight ? Size((tw + 2 * (capsuleK(fs + 1) + 1)).ceilToDouble(), fs + 1) : capsuleSize(tw, fs, icon: icon != null);
    final k = capsuleK(size.height), pad = tight ? k + 1 : capsulePad(fs, k);
    final box = Rect.fromLTWH((at.dx - anchor.x * size.width).roundToDouble(), (at.dy - anchor.y * size.height).roundToDouble(), size.width,
        size.height); // on whole pixels: a 1-px outline stays one pixel
    if (!draw) return box;
    // Its corners stay cut; [red] (the Smithy's material short of a recipe) is ui_bars.png's red capsule, its shade 2 rows.
    _nine(c, red ? _redCapsule : (green ? _greenCapsule : _capsuleSrc), box, k,
        l: 1, t: 1, r: 1, b: red || green ? 2 : 1, sheet: 'ui_bars.png', paint: faded ? _ghost : null, seam: 0);
    var x = box.left + pad;
    if (icon != null) {
      final side = box.height - 2 * k;
      _icon(c, icon, Rect.fromLTWH(x, box.top + k, side, side), faded ? _ghost : null);
      x += side + capsuleGap(fs);
    }
    final cream = green ? const Color(0xFF3B2210) : const Color(0xFFFFF1D6);
    final color = faded ? (ink ?? cream).withValues(alpha: 0.6) : ink ?? cream;
    _text(c, label, Offset(x, box.center.dy), size: fs, color: color);
    if (tail != null) {
      _text(c, tail, Offset(x + lw, box.center.dy), size: fs, color: faded ? ukirInk.withValues(alpha: 0.6) : ukirInk);
      _carveBadges.add((box, '$label$tail'));
    }
    return box;
  }
}
