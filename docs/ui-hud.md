# UI and HUD

Purpose: the book HUD, the layouts (landscape only, the letterbox), buttons, bars and cursor, and which sprite rects they use.

Everything is drawn on the canvas by `Board` (lib/main.dart); there are no Flutter widgets except
the loading screen and the name panel's text field. The owner's rule: labels show just values (price, count). No how-to text in the UI,
except in the loot tooltips, which the owner asked for (below), and in the first-time guide's cards and pointers, also
the owner's ask (decisions-log 172, "Guide" below).

## Layouts

- **Landscape:** the field fills the screen.
  - After a win's cheer (and at the start), the open book floats in on the right; the troops stand
    on the left. `_bookT` eases 0 ↔ 1 by `_bookWanted`, and the book bobs, on the field with a shadow below it.
  - The shadow is pixel art (decisions-log 275), like the units' (`tiny_<type>_shadow.png`: one tone, stepped rows):
    `_bookShadow` draws an ellipse of whole book pixels, `ps` screen px each, its ends on the book's grid and its rows
    on whole screen px, hard edged (no anti-alias). It is 18 screen px tall to a whole book pixel (9 rows at `ps` 2,
    18 at 1) and `0.8 + bob / 120` of the book's width to a whole book pixel (`bob` from −6 up to 6 px down), so it is
    smaller while the book is up; its middle stays 26 px under the resting book's bottom (at most
    10 px above the screen's), on the ground, while the book bobs. Black at 0.25 of the slide's ease: it fades in with
    the book.
  - **The field's only** (decisions-log 304; the owner, 2026-10-09: "book di town di remove backgroundnya", the shadow
    under the book): over a Town's scene the book casts none (`_book` skips `_bookShadow` while `_townShown`), so the
    houses and the ground under it show plain. It goes with the scene: going into a Town the field keeps it while it
    dims, and the Town comes up without it; leaving, it is back once the field shows. Nothing else draws behind the
    book in a Town: the fade's dim and the pause's dim (pause.dart) cover the whole screen, not the book's place. Until
    then it was the same on the field and in a Town.
  - It is big (the owner: "lebih tinggi lagi dan lebih lebar lagi"): its room spans from 26% of the
    width to the right edge minus 6 px and 60 book pixels (the room the gold and wave ribbons had, decisions-log 285;
    kept so the book stays put: the field shows in it), from 6 px below the wave
    meter's band plus 20 book pixels (the tabs) down; it stands 0.75 as tall as wide, 24 / 40 px inside
    the room. Then, in landscape, it is cut to 0.8 of that height (`bookShort`, `_bookLandscape`; decisions-log 283, the
    owner, 2026-10-09: "Bar selebar layar di bawah buku", then "buku di buat lebih pendek lagi"): the same scale, width and
    place across (its covers, tabs and words keep their sizes), its top where it was, its bottom, as low as it bobs, a
    bar's height over the spawn bar at the most: two slots' height over its hotbar's bottom since decisions-log 287
    ("Spawn bar"), where the bar's height over 283's bar left it, always over the step's top. The same in a Town (no bar there), so it looks the same everywhere. 974×584 at 1600×947 (its
    pages' writing 440 px tall), 764×458 at 1266×713 (362; 764×573 before, 672×470 before that), 711×427 at 1164×777
    (331), 403×226 at 915×412 (178). A page whose part no longer fits pages
    or scrolls: the Bag's grid and the Smithy's boards page ("The Bag", "The Smithy"), the Army detail, the Smithy's and
    the Tavern's facing pages and the Tavern's list scroll (`lib/page_scroll.dart`, "A page's scroll" under "The book").
  - During a wave the book closes; a button in the top left row opens it mid-fight (`_bookOpened`), which pauses
    the game ("Pause").
- **Landscape only** (decisions-log 289; the owner, 2026-10-09: "game vertical di hapus saja, game force jadi
  horizontal"; of a view taller than wide: "Letterbox saja"). There is no portrait layout (decisions-log 284's book
  over the lanes, 260's phone rows and 286's two-line +Room went with it).
  - **The lock:** a phone turns the game sideways only. Android's activity asks `sensorLandscape`
    (AndroidManifest.xml), so it never opens upright, and `landscapeOnly` (main.dart) asks SystemChrome for
    landscapeLeft and landscapeRight before the first frame on Android and iOS (nothing on the desktop). The web app's
    manifest asks landscape too.
  - **The letterbox** (`lib/letterbox.dart`, `gameRoot` in main.dart): wherever the view is still taller than wide (a
    desktop window dragged tall, a phone's split screen, the web build on an upright phone) the landscape game shows
    across the view's full width in a rect 1.5 as wide as tall (`letterboxAspect`: the owner's tablet's 1164×777),
    centred, with plain black bars (`letterboxBar`) above and below, their edges on whole physical pixels
    (`letterboxFit`). The game is laid out at the rect's size, but never narrower than 915 px (`letterboxMinWidth`, the
    phone's landscape width): a narrower rect gets the game laid out at 915 px and that aspect and drawn scaled down,
    so the HUD keeps its landscape layout (915×610 at 0.45 on a 412×860 phone; 390×844: 915×610 at 0.43; a 700×900
    window: 915×610 at 0.77; a 1000×1400 one: 1000×667, unscaled). Everything the game draws (the Town, the welcome
    screen, the popups, the book, the log, the guide's cards, the pixel cursor) is inside the rect; nothing draws, takes
    a press or shows a tooltip in the bars (the mouse going into one leaves the game: no cursor, no tooltip). Flutter
    maps every tap, drag and hover through the box's offset and scale, and the wheel's delta is mapped too
    (`TdGame.onScroll`). A notch or a system bar counts only where it reaches into the rect (`letterboxInsets`). The
    widgets are the same in every shape of the view, so a window resized across the line relays out with the game going
    on. A view as wide as tall or wider is the game's own, unscaled, as before.
- **The HUD** (#80's re-layout, the owner: "gold, x2 dan pause di pindah ke kiri. wave level di pindahkan ke
  dalam wave meter", "map pindah ke kanan atas dan dia itu dropdown dari meter wave", "log di pindah ke kanan
  bawah"; decision 116), 10 px from the screen's edges (`_edge`; on a touch device inside its safe insets, "A touch
  device" below):
  - The top band is three fixed groups (decisions-log 220; the owner, 2026-10-04: "hud uang dan darah di jadikan 1
    container. pause dan start button jadi 1 dan toggle", then "auto button jangan di pindah pindah taruh di samping wave
    saja terus. sekalian di pindah posisi btn speed, jadi layoutnyaa seperti btn speed _ btn auto _ wave meter", "sama
    posisi map juga jangan pindah pindah" and "tombol start/pause ada di tengah"): nothing in it moves between waves, in
    a wave or paused, but the book button that comes in a wave at the left row's end.
  - **Top left:** one row (`_meterTop`, `_meterH` tall): the troop counter, then the hearts and the gold on one panel
    and, during a wave, the book button ("The top band" below).
  - **Top right:** x2, Auto ("Auto Wave") and the wave meter, always but at game over, the meter's minimap dropping down under it
    (in every state), and the boss bars under those.
  - **Top centre:** the Start/Pause toggle in every state: Start between waves, Pause in a wave, Resume while paused
    ("Start/Pause toggle" below).
  - **Bottom right:** the battle log's button, its panel opening upward.
  - The old battle bar (gold, wave, x2, the book button and pause at the top right during a wave) is gone.
- **A touch device** (Android, iOS; decisions-log 215; the owner, with a shot from an Android tablet: "ini kalau di mobile jadi
  numpuk seperti ini perlu di fix uinya untuk di kecilkan jika di android"). The desktop (macOS, Windows, Linux) takes
  none of it but the **Size** rule below (decisions-log 217: the same cap on every platform): no full screen, no insets.
  - **Full screen:** `_fullScreenOnPhone` (main.dart) asks for `SystemUiMode.immersiveSticky` at launch and whenever
    the app comes back to the front (`TdGame.lifecycleStateChange`, resumed). The status bar and the navigation or
    gesture bar hide; a swipe in from an edge shows them over the game for a moment. Android 15 and later draw every app
    edge to edge, so before this the status bar (the clock, the battery) lay over the troop counter and the wave meter,
    and the gesture bar over the field's bottom.
  - **Safe insets:** `_safe` (`_safeInsets`, read every frame) is what the screen keeps at each edge: the view's
    padding, which on Android is the system bars while they show and the display cutout's safe insets (a notch, a
    camera hole). The HUD keeps inside it: `_meterTop` adds its top; `_edgeL` and `_edgeR` (`_edge` plus that side's)
    place the counter, the minimap, the Shadows' chips and the boss bars when at the left, the
    wave meter, the log's button, the chest chip and the boss bars at the right; the log's button stands `_edgeB`
    above the field's bottom and the bottom inset; the off-view marker is inside the left inset;
    the boss chest's panel keeps the bigger side's on both sides (it is centred); the book's room is inside all four.
    In full screen on a screen without a cutout every inset is 0, so the layout is the desk's. Zero on the desktop.
  - **Size** (every platform, desktop windows too): the HUD's scale `_meterK` (the field's scale, whole, 2–4) is capped
    twice, and is 2 at least. (1) Its top band (`_meterH` = 20·k − 16) takes no more of the screen's height than the
    desk's (44 of 713 px, 6.2%): k ≤ ⌊(height · 44 / 713 + 16) / 20⌋. (2) The top band fits the width, no
    piece over another: k ≤ ⌊(width + 130) / 399⌋ (the band is 399·k − 130 px wide at its widest: the counter, the
    hearts-and-gold panel with 5 digits of gold and the book button, the toggle as "Start 5", x2, "Auto Wave" and the
    meter with the tide's badge and 3-digit counts, 2·k apart: 1067 px at k 3, 1466 at k 4, measured by
    test/probe_hud_merge_width.dart and test/probe_auto_names_shots.dart; `_rowWidthPerK`, `_rowWidthOff`; fitted to k 3
    and 4, the only ones it decides between, since k is 2 at least). With "Auto" for "Auto Wave" (until decisions-log
    290) it was 381·k − 115 (1028 at k 3, 1409 at k 4): a landscape window 1028–1066 px wide now has k 2 for 3, and one
    1409–1465 px wide k 3 for 4 where its height allows 4; 1600×947 and 1440×900 keep 3 (their height caps them at 3),
    and the sizes below keep theirs. Until decisions-log 217 the row of the
    counter, the hearts, gold, x2, pause, Start, Auto and the meter was 382·k − 180 px wide (962 at k 3, 1344 at k 4),
    so a landscape window 962–1027 px wide now has k 2 for 3, and one 1344–1408 px wide k 3 for 4 where its height
    allows 4. Before the cap a desktop window of 1164×777 had k 4
    and Start lay over pause, Auto over the wave meter and, in a wave, over the book button; so did 900×600–750 (k 3)
    and 900–1300 px wide at 800 px tall and more (k 4). test/hud_sweep_test.dart lays the HUD out at every window from
    900×400 to 2600×1500 (step 50), between waves, in a wave and in a Town ("Leave town", wider than "Start 5"), and
    asserts no two pieces overlap, that x2, Auto and the meter don't move and the toggle's middle doesn't as a wave
    starts, and, from k 3, every button is 40 px each way. What k sizes follows: the top band, the toggle and Auto
    (`_startH`), the wave meter,
    the minimap, the Shadows' chips, the boss bars, the off-view marker and the log's button. The book's `ps` and `ts`
    already follow the screen's size and are unchanged.
    - The owner's tablet (Xiaomi Pad 8: 3200×2136 at density 440, 1164×777 logical in landscape) had k 4: a 64-px band,
      8.2% of the height, and a top row too wide for the screen: between waves the start button lay over x2 and pause
      and Auto over the wave meter, in a wave Auto over the book button. Now k 3: 44 px, 5.7%, the desk's look, every
      piece in its place. Its book stayed 711×533 at `ps` 2 (61% × 69% of the screen; the desk's 764×573, 60% × 80%),
      10 px higher; the shorter landscape book (decisions-log 283) makes them 711×427 and 764×458.
    - Unchanged, on the desktop and on a phone: 1266×713 and 1280×720 (3), 915×412 (2), 1920×1080 and 2560×1440 (4:
      5.9%, 4.1%). A 12.9-inch tablet (1366×1024) gets 3 for 4; a desktop window of 1164×777 gets 3 for 4. The
      letterbox's 915×610 has 2.
    - Taps at k 3: the counter, x2, the book button, the toggle, Auto, the meter and the log's button are 44 px tall
      at least, and as wide or wider; x2, the book button and the toggle take presses k round them, the counter, the
      meter and the log 2·k. At k 2 (phones, the letterbox) x2 is 33×24, the toggle's Pause and Resume 36×32
      (the pause button was 36×24), Auto Wave 84×32 (102×44 at k 3), the log's button 24×24 (its press area 32×32).
- The book's pixel scale `ps` (whole screen px per sprite px) is the largest that keeps 300×200 px of
  book per step and whose room (tabs, the 60 book px on its right) still fits it, so a bigger book gets bigger pages
  rather than thicker covers.
- Page text and spacing scale with the page width: `ts` = the right page's writing width as it was before the
  book's padding (its printed paper less 14 book px) / 280, within 0.5–1.5, so the padding moved no word's size.
- **The book's padding** (decisions-log 198; the owner, 2026-10-03: "book ui di kasi padding 10px dan 5px", the CSS
  shorthand): every page writes inside its printed line (ui_book.png: the left page's at sprite x 16 and 112, the right
  one's at 127 and 223, both at y 10 and 127), less `bookPadY` = 10 book px at the top and the bottom and `bookPadX` =
  5 at the sides (`bookWriting`, main.dart; a book px is `ps` screen px: 10 / 5 at 915×412, 20 / 10 on the desk). The two constants are the owner's to tune. The pages keep no padding of their own: a page's title has its
  line on the writing's top edge (`_titleY`: the middle of its 22·ts line, 11·ts down) and what is under the title
  starts 29·ts down (`_underTitle`). Each page wrote 312×477 on the desk (1266×713), 165×392 on an upright phone (412×860, gone since decisions-log 289) and
  166×254 at 915×412 (before: 302×525 / 160×416 / 161×278, from 2 book px above the printed line at the top to the
  line at the bottom, 4 book px inside it on the outer side and 11 on the spine's, less a 4-px padding of each page's
  own). The gaps between rows, cells and
  strips are each page's own, unchanged but for the Army grid's (below). `Board.bookPages` is where the two pages write
  this frame.

## The font (`lib/hud_font.dart`, decisions-log 158 and 179)

- **Poh Sans**, a Modified Version of **Pixelify Sans** (Stefie Justprince, SIL Open Font License 1.1; the itch page's
  header font), for every text the game draws: `_text` and `_textWidth` on the canvas, the message window, the ribbons,
  the Licenses page's paragraphs and the name field. pubspec.yaml's family `PohSans` (`hudFont`), one file
  `assets/fonts/PohSans.ttf` (a variable font, wght 400-700) with its licence beside it (`OFL-PohSans.txt`; CREDITS.md
  "The font"). Before it: Pixelify Sans itself with PohDigits for its 5, B, C and G (decisions-log 158, 168), and until
  158 Kenmi's CuteFantasy 5×9, whose file has since been deleted from `assets/`.
- **Why a modified copy.** Pixelify Sans grows bolder by growing each pixel on a fixed grid (1000/11 units; a pixel 101
  units wide at 400, 110 at 500, 127 at 700), so a one-pixel gap is 80 units at wght 400, 65 at 500 and 34 at 700, and
  at the HUD's sizes it blurs shut, in both weights and worst in bold. Its C and c are its O and o with one pixel out
  ("Cara Main" read "Oara Main", "Kocok ulang" "Koook ulang"), its i is its l with one pixel out (the dot's gap), its B
  (`.###./#...#/#...#/#.##./#...#/#...#/.###.`) and G (`.###./#...#/#...#/#.#../#..##/#...#/.###.`) are an O with a mark
  ("Peti Bos" read "Peti Gos"), its 5 is its S with two pixels moved ("+5%" read "+S%"). PohDigits drew four of them
  from a second font, but a kern never crosses from one font to another, so every pair with a B, C or G lost Pixelify
  Sans's kern, and the lower case could not be fixed that way (Pixelify Sans kerns c with nearly every letter).
- **What Poh Sans changes:** 13 glyphs, redrawn on the font's own pixel grid (`tool/make_poh_sans.py`, rows top
  first):
  - C `.###./#...#/#..../#..../#..../#...#/.###.` (open over three rows) and c `.###./#...#/#..../#..../.###.` (two);
  - G the new C with a bar on its fifth row (`#.###`); B with a flat left side and a narrower top bowl
    (`###../#..#./#..#./####./#...#/#...#/####.`), neither an 8 nor a G;
  - i its dot one row higher, two rows clear of the stem (the dot on row 7, a row above the capitals);
  - a `.####./#...#./#...#./#...#./.#####`: a square top right and a flat foot (the font's was an o with a loose tail
    pixel);
  - 5 a flat top, a square top-left corner and a straight stem down to the middle bar (`#####/#..../####./....#/
    ....#/#...#/.###.`);
  - S, 2, 3, 6 and 9, which the font draws as its 8 with a pixel or two moved, so that in bold they ran into the 8
    and each other (S/8 and 3/8 1.8 apart at 700): the S without its terminals (`.###./#..../#..../.###./....#/....#/
    .###.`), the 2 with a flat foot (`...#..../#..../#####`), the 3 with a short middle bar (`..##.`), the 6 without its
    top terminal (`.###./#..../#..../####./...`), the 9 without its bottom one;
  - Z with a straight diagonal (`#####/....#/...#./..#../.#.../#..../#####`), not the 2 with square corners.

  Each keeps its advance and its left side bearing, and grows with the weight as the font's own glyphs do (its outline
  at 400 plus one gvar delta set to 700). The composites built on them follow (Ç, Ć, Ĝ, Ź, á, ä, ç, …). Everything else
  is Pixelify Sans's bytes: the other glyphs, GPOS (the kerning: "Bo" and "Ba" −20, "co" −30, "ct" −50 of 1000, all
  kept), GSUB, the metrics, the cmap. Its names are new (family "Poh Sans", PostScript `PohSans`; the OFL's Modified
  Version rule); fvar and STAT name only the weights (Regular, Medium, SemiBold, Bold), which stay.
- **Its tests:** test/poh_sans_test.dart pins the file's and the source's sha256 and runs the tool's `--check`, and checks
  that a text in Poh Sans is exactly as wide as in Pixelify Sans (every kern kept), as tall and on the same baseline, at
  400, 500 and 700, with the same pixels unless it holds a redrawn glyph. test/letter_shapes_test.dart draws each of
  A-Z, a-z and 0-9 alone at HUD sizes 12-30 and the three weights, and every two differ by 2 font pixels of ink or more
  (a letter and its own capital, and O and 0, aside); on Pixelify Sans the same check finds C/O, c/o, i/l, B/G, B/8,
  a/o, 6/8, 8/9, Z/2 and more under 2 (C/O, c/o and i/l 0.5 to 1.0), each with a glyph Poh Sans redraws.
- **Not redrawn:** the rest, every other pair 2 or more apart (1 and I, 2 and the new Z, S and the new 5). 0 and O are
  one outline (as l and | are), but a 0 stands among digits and an O among letters, so the 0 keeps no dot. F and f
  differ by one corner pixel, as a letter and its own capital may. The j is the font's: a small J with neither a dot nor
  a descender.
- **The source** is `tool/fonts/PixelifySans.ttf` (google/fonts' `PixelifySans[wght].ttf`, unmodified) with its licence;
  the game bundles neither. The old files (`assets/fonts/PixelifySans.ttf`, `PohDigits-Medium.ttf`, `PohDigits-Bold.ttf`,
  `OFL-PixelifySans.txt`, `OFL-PohDigits.txt`) are no longer bundled; they stay in `assets/` until the owner's game,
  which hot-reloads from the main checkout, is closed (dev-workflow.md "Traps"; itch-page.md, retired files).
- **No ligatures** (decisions-log 172): the font's standard ligatures (`liga`) draw "fi", "fl", "ff", "ffi" and "ffl"
  as one glyph each, one letter wide (586 units, where an f and an i are 808), so the f and the i share five font
  pixels and the gap between them is one pixel, which blurs shut: the guide's "The fight" read "The Aght", "at first" "at
  Arst". No redraw fits two letters and a gap of two pixels in five, so Poh Sans keeps them as they are and `hudStyle`
  turns them off (`hudFeatures`, `FontFeature.disable('liga')`): every letter is its own glyph, and the redrawn i is
  the one drawn.
- **One style:** every `TextStyle` in lib/ is `hudStyle(size, bold:)`, so what a layout measures is what is drawn.
- **Weights:** body 500 (`hudBody`), titles 700 (`hudBold`; `_text(…, bold: true)`, and `_textWidth(…, bold: true)`
  where a title is measured): the book's page titles (Army, Tas, Shop, Settings, Licenses), the Licenses page's
  package title and its headings, "VICTORY!", the welcome's "Path of Hero", the score screens' titles and "Pause"
  (`_title`), the ribbon titles (a new Hero's splash, the Boss Chest) and the tooltips' and the drop popup's titles.
  `fontWeight` sets the variable font's wght axis (Flutter 3.47; a synthetic bold would keep 400's widths).
- **Size: a HUD size is the old face's.** The text is drawn at `hudFontScale` 0.8 × the size the code gives. At one
  size Pixelify Sans is about 1.25× as wide as the old 5×9 face (the UI's strings 1.12-1.39× at 500) and its lower
  case 5 font pixels tall where the old one's was 3; at 0.8× it runs about as wide (0.9-1.1×), the lower case a little
  taller and the capitals a little lower than before. So every layout, fit helper (`_fit`, `_fitFirst`, the shrink
  loops) and pinned width keeps its numbers.
- **The font pixel** (`hudFontGrid`): the face is drawn on a grid of 1000/11 ≈ 90.5 of its 1000 units, so one font
  pixel is the drawn size / 11 = 0.8 × the HUD size / 11: HUD 11 → 0.8 px, 18 → 1.31 px, 22 → 1.6 px, VICTORY!'s 56 →
  4.07 px (logical px; 2× on a Retina Mac, about 2.6-3× on a phone). Capitals are 7 font pixels, the x-height 5,
  descenders 2.
- **Crispness, the rule: sizes are not snapped to whole screen pixels per font pixel.** The face is not a strict
  bitmap font: its strokes are wider than its grid (101 units at 400, 110 at 500, 127 at 700, on a 90.5 grid, so a
  stem and the gap beside it are 1.22 and 0.78 font pixels at 500) and every glyph sits about half a font pixel off
  the advance grid (left side bearing 50-60 units, advances k × 90.5 + 42). No size puts every edge on a pixel
  boundary, and a size snapped to whole device pixels per font pixel measured no sharper than one between (the
  sweep below), while snapping would move every text in steps of 5.5 logical px on a Retina Mac and break the layouts.
  What keeps small text readable instead is the HUD's floors (max(10, …), max(11, …)): HUD 10 draws a font pixel of
  0.73 logical px, 1.45 device px on a Retina Mac and 2.2 on a 3× phone.
  - The sweep (`test/probe_font_shots.dart`, `weights and the crispness sweep`): the share of a line's inked pixels
    that are only partly covered, by device pixels per font pixel. Rendered by Flutter at a device pixel ratio of 2, a
    whole-pixel origin (a quarter-pixel one gave the same within 0.02):

    | Device px per font px | 1.5 | 1.75 | **2.0** | 2.25 | 2.5 | 2.62 | 2.75 | **3.0** | 3.5 | **4.0** |
    |---|---|---|---|---|---|---|---|---|---|---|
    | 500 | 0.75 | 0.59 | 0.59 | 0.54 | 0.48 | 0.48 | 0.46 | 0.46 | 0.37 | 0.36 |
    | 700 | 0.63 | 0.57 | 0.50 | 0.49 | 0.44 | 0.44 | 0.40 | 0.38 | 0.33 | 0.29 |

    Softness only falls as the font pixel grows, with no dip at the whole ones (2.0 is no sharper than 2.25). The
    same sweep on the outlines alone (unhinted coverage) agreed. The same probe shows the axis at work: "Gelombang 12
    Pasukan Ksatria" at 22 px lays out 322.5 / 325.6 / 332.0 px wide at 400 / 500 / 700, as the font's advances say.

## Wave meter (`lib/wave_meter.dart`)

- **What:** crossed swords, the wave's number (between waves the coming one's: `Game.wave` + 1; the owner:
  "wave level di pindahkan ke dalam wave meter", #80), a bar that fills as the wave's monsters come on,
  "spawned/total" (`Game.waveSpawned` / `Game.waveTotal`: the wave's queue, mini boss, boss and queued
  escorts included; the boss's raised skeletons not) and a caret. Between waves the bar is empty and there
  is no count (the coming wave's size isn't known until it starts). In a Town it shows the Town's name, "In Millbrook",
  instead ("Towns on the HUD" below).
- **The tide** (#92, units-and-combat.md "The tide"): from the tide's first wave (the wave shown ≥
  `Game.shownTideFrom`: `tideStart`, earlier for an army over the cap, "Beban", decisions-log 162) the crowd's extra HP
  follows the number, "+35%" on wave 65 (`tidePercent`, whole percent; "+0%" on the first wave; the owner's 48 over 32
  on wave 87: "+69%" instead of "+23%"), in light blue (`_tideInk` 0xFF7FC8FF) at the number's size. From then the panel keeps room for
  "+999%" (it grows once, at that wave, and doesn't twitch after). Before it there is no badge and no room.
  - Its tooltip (tooltip.dart, `_Hint.tide`): over the whole meter while the badge shows (`Board.tideBadgeAt`),
    in the loot tooltips' frame with the meter's crossed swords: "Tide", then "Monster HP +35%" (green, as the
    tooltips' first line), "Monster attack +16%", "A monster every 0.77 s" (a dot decimal), "Not the boss or mini boss"
    (`tideInfo`; `Game.tideTip`). While the army is over the cap (Beban, `Game.shownOver`: between waves the coming
    wave's as the army stands now, in a wave its own, frozen) its lines count from the earlier wave ("A monster every"
    from `tideStart` while `overPace` is off), and a line follows: "12 over the cap: Tide +24 waves"
    (`overTip`: the troops over, the waves earlier its tide counts from). While the army is full at the cap
    (`Game.capPressed`, below) a last line follows: "Army full (36): make types stronger" (`capTip`). Every glyph is in
    Pixelify Sans, and at 915×412 the tooltip stays inside the screen (`Board.tooltipBox`,
    `test/cap_warning_hud_test.dart`). A press on the meter still drops the minimap.
  - `Board.tideBadge` is the badge drawn this frame ('' without), for `test/tide_hud_test.dart`.
- **When:** always, but at game over. Drawn in `render` after the field and "VICTORY!",
  before the minimap, the boss bars and the HUD (`_waveMeter`, an extension on `Board`).
- **Look:** on the dark `_panel` (the sky behind it is pale). The bar fills a whole
  sprite px at a time, red with a gold leading edge while monsters come; once the queue is empty it is all
  gold, the count turns gold too, and both stay so until the wave is won. The caret is the troop
  counter's: down while the map is folded, up while it is open.
- **Size:** `k` = `_scale` floored, clamped 2–4 screen px per sprite px (3 at 1266×713, 2 on a
  915×412 phone; on a touch device no more than keeps the band at the desk's share of the height, 3 on the owner's
  1164×777 tablet: "Layouts", "A touch device"). Bar 60 sprite px long; icon 16·(k−1) px; text 6·k; padding 2·k. The panel is
  `icon + 4k` tall (44 at k 3) and as wide as two digits of wave and the widest count ("total/total",
  "88/88" at least), so it doesn't twitch while counting or when a wave starts: 323×44 at 1266×713, 207×24
  on a phone. Between waves the count keeps room for the coming wave's too ("8/8" with as many 8s as the digits
  of the larger of the total and 2·(4 + 2·wave), two at least; `room`), so the meter, and x2 and Auto left of it, never move as a
  wave starts (decisions-log 220).
- **Where:** the top right, 10 px in, level with the troop counter (its middle at y 32, top at least 10: `_meterTop`;
  on a touch device both inside the safe insets). It stays there when the book opens ("meter
  wave jangan ikut terdorong"): the book's room starts 6 px under its band (`_meterBottom`) in every state.
- **Press:** a press on it (its panel and 2·k round it, `_MiniMap.button`) drops the minimap down or folds
  it (`_mapDown`, in `onTapDown` after the battle log's). The hand cursor shows over it. `Board.waveMeter`
  is where it is, for tests.

## Minimap (`lib/mini_map.dart`)

The owner (#80): "kita perlu buatkan map untuk melihatkan posisi pertarungan ada di mana dan garis akhir ada
dimana", then "map pindah ke kanan atas dan dia itu dropdown dari meter wave". With #79 the back line stays
put during a wave, so the fight can be far from it.

- **Open or folded:** a press on the wave meter; another folds it. Settings.json keeps which
  (`Settings.miniMap`, per device like Auto; folded on a first launch). It shows whenever the meter does,
  between waves too.
- **Where:** 2·k under the meter, as wide as it, 16·k + 4·k tall (323×60 at 1266×713, 207×40 on a phone).
  It never moves (decisions-log 220; the owner:
  "sama posisi map juga jangan pindah pindah"): while the book shows (between waves, or opened mid-wave)
  its tabs and top edge are right under the meter's band, so the map is drawn after the book (`_miniMapDraw`, called
  by `_hud`), over the book's top rim and the tabs under it. (Until then it went to the left, under the top row.)
  `Board.miniMap` / `miniMapOpen` for tests.
- **What** (on the dark `_panel`, a strip of the field's earth inside 2·k of padding), the field from
  `miniMapSpan`: from the back line (or the view's left edge, or the rearmost unit, when further back) to
  where the monsters come on (the view's right edge) or the foremost unit, when further on, a tile more each
  side; x scaled to the strip, y the field's 8 rows to its height:
  - the deploy zone (`Game.baseX`, `zoneCols` wide) lighter;
  - a dot per living unit, 1.5·k: troops green; monsters in their rank's HP colour (red, silver, gold);
    the mini boss and the boss 3·k, purple and orange, ringed dark, drawn last;
  - the battle line (`battleLine` = `Game.fightX`: the last fight the camera centred this wave, #85, held
    through lulls; none before the wave's first contact nor between waves) dashed gold;
  - the view (`Game.cam` .. `cam + viewW`) as a white frame;
  - the back line, a sprite pixel wide, red, on top.
- **Press:** it only tells: a press on it does nothing else (`_MiniMap.tapped`, like the troop list), and no
  unit is pointed at through it (`_covered`).

## Boss bars (`lib/boss_bar.dart`)

The owner (#67): "ketika muncul boss dan mini boss perlu dibuatkan bar darah khusus di guinya dan namanya
siapa jadi user tau mini boss dan boss yang dilawan ... di uinya itu setiap 1000HP akan ada muncul x1 jadi
kalau boss/mini boss hpnya 13000 maka <bar hp> x 13".

- **Who:** the wave's mini boss and boss (`Game.bossBarUnits`) from when they come onto the field
  (`entered`) until they die. A mini boss a necromancer raises gets none, so a late wave's summons don't
  pile up bars. Neither does an escort's high-elite necromancer (#90, from wave 50): it is a high elite, with no
  name, and the log names it like any other ("High Elite appears: Necromancer"). With both on the field (waves 15, 30…) two bars stack, the boss's on top.
- **What** (on the dark `_panel`, sizes in sprite px at `_meterK`, as the wave meter):
  - the pack's portrait frame (`ui_bars.png` (256, 6, 19×19)) with the monster's idle strip in it on a
    slate (`_bossBack`, so a dark monster stands out): its visible pixels as tall as the 13×13 inside (a
    wide one, the necromancer with its scythe, at most 1.4× the width, cropped at the sides), feet on
    the bottom, facing the troops;
  - its name and title (`bossBarName`, "Morgath the Summoner"; units-and-combat.md "Waves"), white, 6·k;
  - its rank (`tierNames`: Mini Bos, Bos) in its HP bar's colour (`_tierBar`), then its type
    (`monsterTypeNames`) in cream, 5·k;
  - its HP in layers of `bossBarLayer` 1000 (`bossLayers`): the wave meter's long empty bar
    (`_bossBarFrame`), 70 long; the current layer drains over the next one's colour, a whole sprite px
    at a time, and "×N" after it is the layers left (hp / 1000 rounded up: 13,000 HP shows ×13). The top
    layer holds what is over the whole thousands (13,500 HP: 14 layers, the top one 500), so a boss at
    full health shows a full bar. The count keeps room for the most layers it will show ("×200" for
    200,000 HP), so it doesn't twitch.
  - The layer colours (`_layerColor`): the last layer (×1) is the pack's red, so red means nearly dead;
    from ×2 up they cycle orange, gold, green, silver, purple (×7 orange again…; never blue, which means
    MP, #62), each 2 px over 1 px of its shade like the pack's strips. Under ×1 the bar is empty (black).
  - Its MP (the necromancers; other mini bosses have none) in the same bar under it, sharing its rim,
    cyan like a monster's MP on the field (`_monsterMp`).
  - While it winds up a skill its portrait flashes red, and a compact bar's name is red ("A monster's skill").
- **Where** (#80): under the wave meter at the top right, right-aligned with it (`_meterAt`), 6 px under it,
  or under the open minimap and the Shadows' chips ("Shadows" below); 4 px between two bars. Drawn after the wave meter and the minimap and before the HUD.
- **With the book open** (#74: option (b), the orchestrator's pick): the book's room starts
  right under the meter's band, so its tabs and top edge would cover the bars there. While it shows
  (`_bookT` > 0.01, i.e. opened by hand mid-wave, or while it slides), the bars are compact and go to the
  left (`_asideLeft`), at the troop counter's left edge, 4 px under the top row (under the open troop list
  and the Shadows' chips, which go there too; the open minimap stays under the meter), clear of the book (`Board._bossAside`, `bossBarsAside` for tests);
  a long name ("Mini Boss Grimdor the Stormrider") is cut with ".." (`_fit`) when it would come within 8 px
  left of the book. The book never moves for them; the bars come back under the meter when it shuts. There
  they are no top band for plates (`_plateTop`), and the off-view marker moves beside them. `Board._bossAt` is where they all are this frame
  (`Board.bossBars` for tests): a unit's plate stays under them, and the open battle log's top stays under
  them (#74).
- **Compact:** when two full bars would reach down past the field's top edge, where the units walk (a
  phone with the mini boss and the boss: 915×412; the Mac window with the minimap open),
  both are drawn compact (`_bossBarH`): no portrait, the rank (in its colour) and the name on one line over
  the bars, 1.5·k padding. The Mac window (1266×713) with the map folded keeps full bars (they end at y
  ~214, the field starts at ~237).
- **Dying:** its bar breaks away over `deathTime` 0.6 s: the bar flashes white, the panel shakes, then
  drops and fades out. It is drawn after the win too, until the body is gone.

## Start/Pause toggle (`lib/start_button.dart`)

The owner (#49): "button next wave di pindah jangan di ribbon, karna akan membuat seperti menyatu dengan
informasi koin dan wave dan harusnya hanya muncul di preparation battle saja, in battle harusnya tidak
muncul". It was the Mulai ribbon under Emas and Gelombang; then a button of its own; now (decisions-log 220; the
owner, 2026-10-04: "pause dan start button jadi 1 dan toggle", "tombol start/pause ada di tengah") one button with the
pause button (#93, which stood in the top left row), in the same place in every state.

- **What it does** (`_toggleOf`, `_Toggle`):
  - **Start** while a wave can start (`Game.canStartWave`: no wave on, not `over`, no Town due), cheering included,
    and in a Town, where it says "Leave town" ("Towns on the HUD" below): the pack's green button with the play sign
    and "Start" (`Words.start`).
  - **Pause** during a wave: the light button with the pause sign, square.
  - **Resume** while paused, whoever paused it (the toggle, Esc or P, the book, a phone going to the background), between
    waves too: the orange button with the play sign, square.
  - Not drawn after a game over, nor while a Town is due but not yet gone into.
- **Where:** the top centre, centred between the screen's safe insets in the top band (`_meterTop`,
  `_meterH`), which the book always stays below (`_meterBottom`), so it is the same with the book open or closed. It is
  the sky over the field there: clear of the deploy zone and the troops, of the top left row and of x2, Auto and the
  wave meter (top right). Where the screen is too narrow for its widest look there (a Start with Auto's seconds), it
  keeps that clear of x2 (2·k left of it), its middle the same in every state. Its press area is k bigger all round. 1266×713: Start 580..686 (with Auto on),
  Pause and Resume 611..655; 1164×777: 529..635 and 560..604; 915×412: 415..500 and 440..476.
- **Look:** the pack's buttons (`ui_buttons.png`, `_btnFrame` as `_button`): green for Start, light for Pause, orange
  for Resume; as tall as the band and at least 32 px (`_startH`). Start is as wide as its word: 94×44 at 1266×713, 76×32
  on a phone (915×412); with Auto on it keeps room for the digit ("Start 5": 106×44, 85×32), so it doesn't
  change width as the seconds come and go. Pause and Resume are square, 36 wide at least: 44×44 at 1266×713, 36×32 on a
  phone. The play sign is the pack's white arrow (`_startIcon`), as tall as the frame's inside allows in whole pixels
  (2× at 44 px, 1× at 32): before the word on Start, centred on Resume. "Start" in dark ink (0.42 of the height,
  14–28). The pause sign: `ui_icons.png`'s small white dash twice, stood up (turned a quarter), 2 sprite px apart,
  0.65 of the button's height.
- **Attention:** Start takes the pack's hover look (button_fx.dart: lighter, its face a sprite pixel lower) for 0.5 s
  of every 1.6 s on the screen clock (`_startBlink`, `_startLitFor`), so it bobs gently; every look keeps the hover
  look while the mouse is on it. Pressed, it is pushed in like every button.
- **Press:** what it showed is what it does: a press compares the state drawn with the state now and does nothing when
  they differ. Start (`_startPress`): closes a book opened by hand mid-battle (`_bookOpened`) and starts the wave (`Game.startWave`); in a Town it
  leaves the Town instead (`_leaveTown`) and starts no wave. Pause: the player's pause (`_pauseGame`). Resume:
  `_resume`. A press within `_toggleGuard` 0.35 s (screen clock) of a wave beginning does nothing, so a double tap on
  Start, or Auto starting the wave under a finger, never pauses it. While the Boss Chest's popup is open it takes every
  press, so the toggle under it starts nothing; and while a chest waits for its popup (a boss win's cheer), Start opens
  the chest instead of starting the wave, or with a new Hero's splash showing or waiting does nothing (the chest opens
  after the splash): no wave starts before the chest is taken or skipped (`_chestNow`, decisions-log 281). Keys: Esc and P pause and resume ("Pause" below); none starts a wave.
  `Board.toggleButton` is where it is drawn whatever it does (`Rect.zero` after a game over), `Board.startButton` the
  same while it is Start and `Board.pauseButton` while it is Pause or Resume (`Rect.zero` otherwise), for tests.
- **Auto** (#68; the owner: "tambahkan auto start wave dan ini di prioritaskan"): a button left of the wave meter, x2
  left of it, in every state (decisions-log 220; the owner: "auto button jangan di pindah pindah taruh di samping wave
  saja terus. sekalian di pindah posisi btn speed, jadi layoutnyaa seperti btn speed _ btn auto _ wave meter";
  `_speedAuto`, hud_row.dart): `_button` with the label "Auto Wave" (`Words.autoWave`), orange while on (the active
  look), as tall as the toggle (`_startH`) and as wide as its words with the button's margins (`_autoSize`): 2·k
  left of the meter, centred on the band (1600×947: 1155..1257; 1266×713: 821..923; 1164×777: 719..821; 915×412:
  608..692).
  - **Its name** (decisions-log 290; the owner, 2026-10-09: "auto yang di bawah sama auto yang di atas membingungkan
    karna sama sama tulisan auto", then his pick "Auto Wave + Auto Buy"): it said "Auto" until the spawn bar got an
    Auto of its own (decisions-log 283, "Spawn bar"), which now says "Auto Buy" (`Words.autoBuy`). Only the shown words
    changed: `Settings.autoStart`, the save and the telemetry keep their keys, and the look, the countdown, the hold and
    the lit state are as before. Every place it fits: 1600×947, 1266×713, 1164×777 and 915×412, with the countdown, the
    hold line, in a wave and in a Town's "Leave town" (test/auto_names_test.dart). So it can be turned on
  mid-wave, and it never moves: the wave meter keeps room for the coming wave's count between waves ("Wave meter").
  Not after a game over. Settings.json keeps it (`Settings.autoStart`, per device like the volumes; off by default).
  `Board.autoButton` is where it is.
  - While on, a won wave starts a countdown of `autoStartDelay` 5 s (`AutoStart`, lib/auto_start.dart),
    shown on the toggle's Start: "Start 5", "Start 4" … "Start 1". At 0 the next wave starts as a press on Start
    does (a book opened by hand closes). Real seconds: x2 doesn't hurry it.
  - Only a win starts one, or a wave lost to a wipe (played again, decisions-log 322; "An army wiped" below): never
    before the first wave, after a save is loaded or another game comes in,
    nor when Auto is turned on between waves (the next win does). Meanwhile the player can still press
    Start (the countdown ends), place troops and use items.
  - It stands still while paused, while `Board.holdAutoStart` is set (the Hero splash, #47, sets it), while a
    boss chest is due (one waits, its popup open or about to open; none can be put off: `_chestHolds` on `tick`'s
    `held:`, not through `holdAutoStart`, which the splash sets outright; "Boss Chest" below) and while the book is turned off Pasukan: on
    a Town's pages (the Shop: #63, the player is shopping), and on Tas and Settings (#93: giving items, the settings; the
    Army page is the book's own, where it runs; it runs on when the page is left), stops when Auto is turned off,
    and never runs after a game over.
  - **The Auto hold** (decisions-log 141; qa-1: Auto began w86 5 s after a wave that left 20 of 48): with the
    board's limits on it also stands still while fewer than 75% of the army's cap are alive (`Game.autoHeld`),
    and a line under the toggle says why: "Army 20/36 · Auto Wave waits" (a middle dot since the font has one, decisions-log 158),
    gold with a dark outline at 0.7 × the button's font, centred under it and kept on the screen (none in a Town).
    The countdown goes on once the player buys the army back to 75%, and Start starts
    the wave at once as ever. `Board.autoHeldLine` is where the line is (Rect.zero: none).

## Off-view marker (`lib/off_view.dart`)

- **What:** while living troops are out of sight left of the view (`Game.leftOfView`, camera-and-field.md),
  the owner's "para troops bisa saja off cam jika mereka tertinggal" (#56): an arrow pointing left and how
  many they are.
- **Look:** the dark `_panel`; in it the Start/Pause toggle's play sign flipped to point left
  (`ui_icons.png` (144, 176), visible 7×12) at k−1, and the count in white, 6·k (k = `_meterK`, padding
  2·k).
- **Place:** on the field's left edge (2·k in), level with the middle of those troops, kept inside the
  field. Drawn with the field, before the HUD, so the book and the HUD's panels cover it. `Board.offViewMarker`
  is its rect this frame (Rect.zero: none), for tests. It takes no press.
- **Clear of an open panel** (#74): where an open panel over the field's left edge would cover it (as last
  drawn: the troop counter's list; the Shadows' chips and the boss bars while the book puts them at the left), it
  moves beside the panel (still level with the troops).

## FPS readout (`lib/fps_readout.dart`, decisions-log 308)

- **What:** a dev readout for the owner's "apakah ini bermasalah di fps dari gamenya soalnya kita belum ada fps
  counternya": how many frames the last second drew and its slowest frame, "60 fps 17 ms", once a second
  (`FpsMeter`: each frame's dt as Flame gives it to `Board.update`, before the 0.1 s clamp and the speed; a second's
  count closes on the frame that passes 1 s). The ms turn the HP bar's red (`0xFFE43B44`) when the slowest frame
  took `fpsSlowMs` 34 ms or more (under 30 fps).
- **On and off:** Settings' "Show FPS: On / Off" (below), `Settings.showFps` in settings.json, off by default (an
  older settings.json without the key loads it off). Off, `Board.update` counts nothing and nothing is drawn; turning
  it off forgets the count, so on again shows nothing until a new second is in.
- **Look and place:** the off-view marker's dark `_panel`, the text in white at max(11, 4·k) px (k = `_meterK`),
  padding 2·k. At the field's bottom-left corner, `_edgeL` in from the left, its bottom 2·k over the spawn bar's step
  (`_hotGeom().stepTop`); in a Town, where there is no bar, `_edgeB` over the screen's bottom. Beside (right of)
  whatever is open there: the troop counter's list, the Shadows' chips and the boss bars while the book puts them at
  the left, the off-view marker. Drawn over everything but the cursor (after the tooltip), so a popup never hides it.
  It takes no press. `Board.fpsReadout` (its rect, Rect.zero while off or before the first second), `Board.fpsText`
  and `Board.fpsButton` are for tests; test/fps_readout_test.dart keeps it clear of the top band, the spawn bar, the
  book, the log's button and the open panels at 1600×947, 1266×713, 1164×777 and 915×412.

## Troop counter (`lib/troop_counter.dart`)

- **What:** how many troops are alive out of what the army may hold, "alive/cap" (`Game.troopCounts`:
  living troops by type, in `troopTypes`' order, the book's; a type with none is left out; the total is
  their sum; `Game.armyCap`: the capacity, at most 36 with the board's limits, decisions-log 141 and 260, 32 until
  then), in gold when the army is full, red when it is over the cap (a save from before it: "48/36"). Marching in counts, dying
  doesn't. `Board.troopCountText` is the text last drawn, for tests.
- **The list** (a press on the counter): the types alive, in the book's order, each with its sprite, name and count.
  With the type caps on (`Game.typeCapOf`, decisions-log 201) the count is against the type's cap, "3/8" (white under
  it, gold at it, red over it: a save from before the caps, "17/5"), and the column is as wide as "88/88"; without
  them "17", as before. `Board.troopListTypes` and `Board.troopListCounts` are what it showed. (Until decisions-log
  201 the list was the roster of 4 types, with a first line "4/4 types".)
- **When:** always, between waves and in battle, in both layouts. Drawn in `_hud` after the book
  (`_troopCounter`, an extension on `Board`, which then draws the hearts-and-gold panel and the book button),
  so the game-over shade covers it; at game over its list folds and it can't be pressed.
- **Look:** the dark `_panel` with the grey shield, the count (white) and a caret: the
  small white triangle, down while folded, up while open.
- **Size and place:** as big as the wave meter and level with it (`_meterK`, `_meterH`, `_meterTop`):
  shield 16·(k−1) px, text 6·k, padding 2·k, caret 10×7 sprite px at k−1. 10 px from the left
  (x 10..125, y 10..54 at 1266×713). It is
  as wide as "88/88" at least, so it doesn't twitch between 9 and 10. Its press area is the panel
  plus the padding all round (a phone's panel, at k 2, is only 24 tall).
- **The lives: hearts (`lib/lives.dart`, `_livesHearts`, drawn by `_hudRow`):** the owner's "ubah jadi
  bar nyawa saja di samping jumlah troops" (#40) made it a bar, which replaced the heart and number in the
  battle bar and the book's "Nyawa" line; then "untuk bar darah di kiri atas di ganti dengan icon heart
  tapi icon heartnya di bagi 2" (#65) made the bar hearts.
  - At the front of the hearts-and-gold panel ("The top band" below), beside the counter (2·k to its right): their part (`_livesAt`, `Board.livesBar`) is 2·k + the hearts + 2·k wide,
    as tall as the panel: 100 px with 3 hearts (#79; 160 with 5), 134..234 × 10..54 at 1266×713. (Until decisions-log 220 they had a dark `_panel` of their own, the gold another.)
  - Inside, a row of the pack's hearts (`ui_icons.png`), as big as the counter's shield (16·(k−1) a cell,
    their visible 14×14 pixels drawn), one sprite pixel apart. Each heart holds 2 lives (`hearts`): full
    (red), half (the left half red, the right dark: an odd count's last heart) or empty (dark, lives
    lost), left to right. `Game.startLives` 6 is 3 hearts (#79, the owner: "jadi 3 heart saja"; it was 10,
    5 hearts): 5 lives show 2½, 2 lives 1 and 2 empty. No number. A save from before #79 comes back with
    at most 6.
  - A life lost: the heart it went from (`heartsLost`; several with a bigger loss: an army wiped takes 2 lives, so a
    whole heart, or two halves from an odd count) pops, up to 1.3× from
    its centre and back over `_heartPop` 0.35 s, drawn over its neighbours (`_Lives` keeps last frame's
    lives to see it).
  - More lives than `startLives` (none today) would add hearts, making the panel longer.
- **The list:** a press on the counter drops it down under it (2·k below), on the same panel. One row
  per type there is, 12·k tall: the book's shadowless idle sprite (`book_<type>_idle`, its visible pixels
  `_idleBounds` fitted to a 11·k box, feet on its bottom, animated, outlined in its awakening
  colour `_awakeLine`), its name (`troopTypeNames`, cream) and its count (white, right-aligned), faint rim-
  coloured lines between rows. As wide as the longest name of all types and at least two digits, so it
  doesn't change width as types come and go. 1266×713: 9 rows reach y ~395 and x ~200, clear of the
  book (from x 329).
- **Input (`_TroopList`):** in `onTapDown`, after the message window and before `_hits`: a press on the
  counter opens or folds the list; a press anywhere else folds it and then does what it would (buys a
  row, turns a page, ...); a press on the open list does nothing else (its tap up and drag are dropped:
  `_TroopList.tapped`, like `_Message.tapped`). Not while the welcome screen is up. The hand cursor
  shows over the counter's press area (`_TroopList.button`), not over the list.

## The top band (`lib/hud_row.dart`)

The owner (#80): "gold, x2 dan pause di pindah ke kiri" (they were in the battle bar at the top right, with the wave
number, which went into the wave meter); then (decisions-log 220, 2026-10-04) "hud uang dan darah di jadikan 1
container" and "auto button jangan di pindah pindah taruh di samping wave saja terus. sekalian di pindah posisi btn
speed, jadi layoutnyaa seperti btn speed _ btn auto _ wave meter". `_hudRow` (drawn by `_troopCounter`) and
`_speedAuto` (drawn by `_hud`, with the toggle after it):

- **Order:** at the left the troop counter, the hearts-and-gold panel and, during a wave, the book button
  (the one that only comes mid-wave last, so nothing moves when it does); at the right x2, Auto and the wave meter; the
  Start/Pause toggle in the middle ("Start/Pause toggle" above). 2·k apart, x2 and the panel `_meterH` tall at
  `_meterTop`, Auto and the toggle `_startH` tall, centred on the band. 1266×713: the panel 134..318 (hearts
  134..234, gold 234..318), book 324..368, the toggle 580..686 (Start with Auto on) or 611..655, x2 770..815, Auto
  Wave 821..923, the meter 929..1256; 1164×777: panel 134..318, book 324..368, toggle 529..635 or 560..604, x2
  668..713, Auto Wave 719..821, meter 827..1154.
- **The hearts and the gold** (`_heartsGoldAt`, `Board.heartsGoldPanel`): one dark `_panel` (the HUD's panel art,
  9-sliced), as tall as the counter: first the hearts ("The lives" above; `Board.livesBar` is their part), then the
  coin (`_icCoin`, 16·(k−1)) and the gold in amber, 6·k, as wide as 4 digits at least, so it doesn't twitch (its part
  `_goldAt`, `Board.goldPanel`). The parts touch: the panel is the hearts' part and the gold's together. Neither part has
  a tooltip or takes a press, as before.
- **x2** (`_speedAt`, `Board.speedButton`): a `_button` labelled "x1" / "x2" (orange at 2), as wide as its
  word, 2·k left of Auto; a press switches `Board.speed`.
- **Auto Wave** (`_autoAt`, `Board.autoButton`): "Start/Pause toggle" above.
- **Book** (`_bookBtnAt`, `Board.bookButton`): the pack's red book icon; a press opens the book, which pauses a wave,
  or shuts it, which resumes the wave if the book paused it (`_bookOpened`, orange while open; "Pause" below).
  - During a wave: 2·k right of the panel.
- The buttons' press areas are k bigger all round (the next one's touches); none of them at game over (the
  panel stays).

## Battle log (`lib/battle_log.dart`)

The owner (#60): "perlu di tambahkan fitur log dimana user bisa liat hal hal penting seperti ada pasukan
yang mati, troops pakai skill, monster drop item, monster high level appear". It shows the game's events
(`Game.log`, lib/game_events.dart; architecture.md), drawn by `_hud` through `_battleLog`.

- **Button:** a pack button (`_button`: lit on hover, pushed in, orange while open) `_meterH` square at
  the bottom right of the field, 10 px in (#80, the owner: "log di pindah ke kanan bawah"; it
  was beside the hearts), with the pack's speech bubble (`ui_icons.png` (0, 16), 8·k). While closed, a red
  count of the unread (events since it was last open, `_BattleLog.seen` against `EventLog.total`, "99" at
  most) sits on its top left corner (the right one is at the screen's edge). Its press area is 2·k bigger
  all round.
- **Panel** (while open): the dark `_panel` over the button, opening upward from 2·k above it (and never over the spawn
  bar's controls as drawn where they run under it: the hotbar and its arrows, +Room, Auto Buy; at 1266×713 its bottom
  rests on Auto Buy's face, over the top k of its press area; decisions-log 283, 287; the step's own ground it may
  cover) and right-aligned with it: 25% of the width, 340 at most,
  and half the height, 330 at most. Its top stays 2·k under the pieces at the top right: the wave meter, the open minimap, the Shadows' chips and the boss bars (not while the book puts
  them at the left; #74's rule, so both show); it keeps room for the chips and a row, over them if it must. Between waves it
  covers the right page's corner of the book while open (the button is clear of the book), but never the book's
  buttons that sell (decisions-log 169; the owner's w89 report: in his 1266×713 window the open panel, 939-1256 ×
  323-653, hid the Shop card's "Sell all", then "Jual semua", whole): the book lists them as it draws them
  (`_keepFromLog` → `_logKeep`: the Shop card's Buy and Sell block, the Bag page's Sell tags), each over the book's whole bob so the
  panel's edge stays still, and one in the panel's lower half lifts its bottom above it (2·k clear), one in its upper
  half takes its top below it; the chips and a row stay. So with a Shop card shown the panel ends above Buy (323-548
  in the owner's window) and is whole again when the card goes; the Bag page's Sell row likewise while it shows
  (decisions-log 202: an action row, under the description).
  `Board.logButton` / `logPanel` are where they are, for tests.
  - On top, filter chips (pack buttons, the chosen one orange; their labels at 4.5·k, or a 4.8th of a chip's width
    when that is smaller, decisions-log 197, so "Monsters" and "Artifact" sit inside with room): All, Fallen (a
    fall), Skill (#10, Hero and awakening skills), Artifact (`Words.artifact`: a Grail save, a won wave's
    Pusaka report, decisions-log 149; a boss chest closed, "Boss Chest: Iron Banner ★1 (Rare) to Templar", its card's
    icon in its rarity's ink, decisions-log 152; an Asah, 154; a Lebur, "Melt: Void Eye into Dragon Heart ★2 on
    Templar (60k gold)", 164), Monsters (strong monsters and their skills), Other (a new Hero, a Hero called back
    ("Budi (Knight) is back (57k gold)", #92 part 3), an awakening, an Awaken 4-5 bought ("Knight: Awaken 4 (40k
    gold)", #92 part 2), a wave won or lost). A chip starts the list at the top again. A Loot chip (field drops) went
    in decisions-log 317: a board game drops no item or relic on the field, so it was always empty; the drops' event
    went in 321, when no game had them any more.
  - Under them the entries, newest on top, 9·k a row, faint lines between: the wave number (small,
    faded), the event's icon (6·k) and its line (`logLine`, cream, 5·k and 11 px at least, cut with ".."
    to the width). The Hero and monster skills keep their English titles.
  - An event may take more than one row (`logLines`, decisions-log 149): a fall that sent relics back to the bag, and
    a won wave's Pusaka report. Its later rows have no wave number and no line above them; a fall's second row is
    indented under the first.
  - With no entries yet: "Nothing yet".
  - It scrolls by the mouse wheel over it (`TdGame` is a `ScrollDetector`, `onScroll` → `_logWheel`) or a
    drag on it (`_BattleLog.dragY` in `onDragStart` / `onDragUpdate`); up goes on to older entries.
- **Lines and icons:**

  | Event | Line | Icon | Colour |
  |---|---|---|---|
  | `TroopFell` | "[Hero ]<name> (<type>) fell[ to <rank> <Monster>]" ("Budi (Soldier) fell to Mini Boss Orc Rider") | `ui_icons.png` dark heart (32, 0) | light red |
  | `TroopFell`'s 2nd row, when it held relics | "<relic>[, <relic>] back in the Bag" | its first relic's icon | pale gold (`_backInk`) |
  | `GrailSaved` | "Grail saves [Hero ]<name> (<type>)" | the Grail's (the trophy) | the Grail's cyan |
  | `PusakaReport`, a row each bound Pusaka | "Grail (Axeman): 7 saves, 6 lived", "Dragon Heart (Templar): 3 hits lived", "God's Thunder (Wizard): +12.3k damage", "Dawn Star (Priest): +5k damage & heal", "Iron Banner (Knight): +5k damage blocked", "Blood Fang (Lancer): +3.2k HP drained", "Mourning Bell (Priest): rang 3 times, +3.2k HP" ("rang once"), "Dragon Crown (Knight): 3 hits cut, +4.6k HP kept", "Void Eye (Archer): +4.2k damage" (a count of one is singular: "1 save", "1 hit") | the Pusaka's icon | the Pusaka's colour (Void Eye's violet, `_pusakaLogInk`) |
  | `PusakaReport`, a row each of the forge's nine small relics that did something (after the Pusaka's rows; decisions-log 250) | "Chill: slowed 12 times" ("slowed once"), "Weak Spot: marked 9 times, +812 damage", "Shark Tooth: +1.2k damage" (`relicCounter`: its own counter only, never a partner) | the relic's icon | pale gold |
  | `PusakaReport`'s last row, when relics came back | "Back to Bag: Fury ×2, Fang" (every kind, most first) | the relic most sent back | pale gold |
  | `PusakaAsah` (decisions-log 154), and its 2nd row | "Sharpen: Dragon Heart ★2 on Templar (60k gold)"; "Thorns 8, Fury 2 from the Bag" | the Pusaka's icon; the relic taken most | the Pusaka's colour; pale gold |
  | `PusakaLebur` (decisions-log 164) | "Melt: Void Eye into Dragon Heart ★2 on Templar (60k gold)" ("in Vault" for one there); a 2nd row like Sharpen's only while `leburRelics` is above 0 | the target's icon | the target's colour |
  | `SkillCast` (#10) | "<name> uses <skill>" | the MP bolt, blue | cream |
  | `HeroSkillCast` (#48) | "Hero <name>: <English title>" | the skill's mark (`_heroMarkIcon`) | the pops' gold |
  | `StrongFoe` | "<rank> appears: <Monster>" ("Mini Boss appears: Werebear") | the crossed swords (112, 16) | the rank's HP bar colour (`_tierBar`) |
  | `MonsterSkillCast` (#59) | "<rank> <Monster>: <title>" | the crossed swords | the rank's HP bar colour |
  | `HeroMade` | "<name> (<type>) is now a Hero!" | the crown (64, 16) | gold |
  | `HeroRecalled` (#92 part 3) | "<name> (<type>) is back (<price> gold)"; with a full army's swap a second row, "<troop> goes home (+<refund> gold)" (decisions-log 167) | the crown (64, 16) | gold |
  | `AwakenSkillCast` (#88) | "<name> uses <skill>" with the level's numeral ("Disarm II") | the full star (48, 0) in the level's colour | cream |
  | `Awakened` | "<type>: Awaken n", and " - <skill>" when the type has a built awakening skill ("Soldier: Awaken 2 - Disarm II") | the full star (48, 0) in the level's colour | the level's colour |
  | `WaveEnded` | "Wave n won" / "Lost at wave n" | the trophy (80, 16) / the dark star (80, 0) | green / light red |
  | `Wiped` (decisions-log 322) | "Army fell: -1 heart, wave n again" / "Army fell: no hearts left" | the dark heart (32, 0), as a fall's | light red |
  | `OmenGained` (decisions-log 191, only with the Shadows on) | "Monsters got Armor 2 (Boss Chest w90)" (a chest's), "Late Shadow: Wound 2" (the catch-up), "Carve: monsters got Haste 1" | the kind's icon ("Shadows" below) | cream |
  | `OmenEased` | "Shadow eased: Armor down to 1" | the kind's icon | cream |

  A monster and its rank are named as on its plate and the boss bars, the rank first (decisions-log 197):
  `tierNames` (Elite, High Elite, Mini Boss, Boss; a normal one has none in the log, `_foeName`) then
  `monsterTypeNames` ("orc_rider" → "Orc Rider", `_monsterName`): "High Elite Skeleton Archer".
- **Input (`_BattleLog`):** in `onTapDown`, after the Hero splash and the message window and before the
  troop counter: a press on the button opens or closes it (opening folds the counter's list, and opening
  the list closes the log: they take turns). A press on the open panel is its own: its chips are `_hits`,
  its tap up is dropped (`_BattleLog.tapped`). A press anywhere else leaves it open and goes on to the
  field, so it can be read during a wave. Gone after a game over.

## Spawn bar (`lib/spawn_bar.dart`, `lib/auto_replace.dart`; decisions-log 283, 287)

The owner (2026-10-09): "sama untuk spawn troops di keluarkan dari ui book di pindah ke bawah game saja, jadi book itu hanya
isinya detail dari army dan bags saja kalau di battle field". Troops are bought from a bar at the bottom of the battle
screen; the Army page keeps the troops' detail (below, "Army"), without Buy and without +Room. Its layout, the owner's:
"bar bawah seperti ini / <list troops> <space><number army> / <merge coulm list troops><space><expand slot><auto spawn
troops>", "Kanan diam, list troop geser", +Room "Pindah ke bar", auto spawn "Auto ganti yang gugur"; then "jumlah troops
cukup di atas saja ternyata, berarti yang di bar bawah cukup auto buy sama expand room" (the army's count stays the top
band's troop counter alone). Then a hotbar on a step (decisions-log 287; the owner, with the Cute Fantasy UI's premade
hotbar as the picture: "untuk sloot army-nya coba di pakaikan seperti ini [Image] tapi di sesuaikan tinggi dan lebarnya
dan di taruh di tengah saja. terus buat untuk battle groundnya itu pada bagian bawah seperti ini
`___/<menu spawn troops>\____` supaya battle jangan sampai di belakang dari action bar untuk spawn troops"; of where +Room
and Auto Buy go, "Di atas panggung"). So: the troop slots on a hotbar centred on the screen, paged where they don't all
fit; "+Room" left of it and "Auto Buy" ("Auto" until decisions-log 290) right of it; all of it on a raised step of
the field's own ground, whose top is under the lowest anything of the battle is drawn.

- **When:** on the battle field, between waves and in a wave, paused or not, the book open or shut (`_barShown`). Not in
  a Town (nor while the screen fades into one: the Town's book keeps its pages), not on the welcome screen, not after
  the game. Drawn in `_hud` after the book, before the top band.
- **The slots** (`_barCard`): one per troop type, all nine (the types the Army page lists), in `troopTypes` order, square,
  a gap (5 sprite px) apart on the hotbar ("The hotbar" below). Each is the hotbar's own inset slot (ui_hotbar.png's
  18×18 slot, 9-sliced l 2, t 3, r 2, b 1, at `hotbarPx` 2 screen px a sprite px): lighter under the mouse
  (`_lightTagPaint`), its face sunk a sprite px while pressed, greyed while refused (`_greyTagPaint`). In it, as big as
  the room allows over the price's line, the type's shadowless idle sprite (`book_<type>_idle`, `_barSprite`), animated
  and outlined in its awakening's colour; along its bottom the coin (`_icCoin`) and the price (`shortPrice` of
  `Game.priceOf`, `barPriceSize`: 0.24 × the slot's height) in cream outlined dark; astride its top edge at its right the
  count against the type's cap in the Bag's dark capsule ("3/10", `_rowCount` without its "x", `barCountSize`: 0.22 × the
  slot's height; red at the cap or while Oath of One bars the type; "13" without the caps; nothing with none alive and no
  caps), so it hides little of the sprite. Both never under the HUD's small floor of 11 px (the owner asked that they read
  at 1600×947: the price 13 px there, the count 12; 11 and 11 on 44- to 46-px slots).
  - **Buys** (`Board.spawnCardLook` 'buy'): the coin and the price in cream.
  - **Too poor** ('poor'): the coin faded (`_ghost`), the price grey; a tap does nothing and says nothing.
  - **Refused for anything else** ('refused': `Game.buyRefusal` other than the gold: the type at its cap, Oath of One,
    Oath of the Few's 24, the army full, no room): the slot greyed, the sprite faded under
    ui_icons.png's red forbidden sign (208, 80; 16 px, 32 from a 48-px sprite box), the coin faded and the price grey; a
    tap says why in the message window ("Priests full 5/5", "Army full 36/36", "No room").
- **A tap on a slot** (on tap UP, on the slot the press went down on: `_SpawnBar.down` in `onTapDown`, `_barTap` first
  in `onTapUp`) buys one of its type with the click: `_buyTroop` (troops_page.dart), the Army detail's Buy's own code
  until decisions-log 283: `Game.autoPlace` (the zone's first free cell; mid-wave the troop marches in), the gold, the
  count, the telemetry, every rule as before. Mid-wave too, and nothing pauses: the bar is on the field, not in the book.
  The Army page's pick doesn't change. A drag that begins on a slot is no tap: a swipe turns the strip's page, and
  carries no troop.
- **Its tooltip** (`_Hint.troop`, `Game.spawnTip`; hover, or a long press, which then buys nothing): the type's sprite and
  name over "Buy one: 50 gold.", "On the field: 3/10." and, while it can't be bought, why ("Not enough gold.",
  "Priests full 5/5").
- **The hotbar** (`_spawnBar`; Cute Fantasy UI's `UI_Premade.png` hotbar (108, 154, 120×28), the owner's picture, cut by
  tool/import_fx.py `hotbar` into `ui_hotbar.png`: the panel without its slots and one slot): the panel (11×28, 9-sliced
  3 all round) at `hotbarPx` 2 screen px a sprite px, round its slots with 5 sprite px (10 screen px) of tan at each
  side and between them, centred on the screen (`size.x / 2`), its bottom on the battle log button's (`_edgeB` over the
  screen's bottom). A slot `barCardShare` of the screen's height (the owner, 2026-10-09: "Lebih besar, ~56px": 56 in his
  1600×947 window), never under `barCardMin` 44 (the tap rule's): the panel 604×76 at 1600×947 (498..1102 × 861..937),
  496×64 at 1266×713 and 915×412, 514×66 at 1164×777.
- **Paging** (`_SpawnBar.first`, `per`; the owner, 2026-10-09, of a card cut under a small arrow tag: "masa kamu buat
  seperti ini emang itu bisa di click kalau kamu buat seperti itu?"): the hotbar holds all nine where each half of the
  screen has room for half of it and, beyond 2 gaps, its button: +Room's within `_edgeL` on the left, Auto Buy's clear
  of the battle log's button on the right (`_meterH` + 3·k from `_edgeR`). Where it doesn't (a landscape window too
  narrow for the nine: 568×320, an iPhone SE held sideways), it holds as many whole slots as fit with an arrow
  button a gap off each of its ends (`_barArrow`, `_SpawnBar.back` and `on`), +Room and Auto Buy outside the arrows: the
  light button of +Room and Auto Buy (`_button`, on tap down), level with the slots and as tall, `barArrowMin` (44) px
  wide, the pager's triangle on it (`_icPageBack`, `_icPageOn`, a whole multiple of its size near 0.4 of its height,
  twice at the least) inked as a button's words, greyed with the button while nothing more is that way (a tap then does
  nothing). Nothing is drawn over a slot or cut. A page turns by `per` slots, held to the first and the last (the last
  page shows the last `per` slots: `_barPage`), by an arrow, the wheel over the strip (`_SpawnBar.list`: the hotbar and
  its arrows; `_barWheel`, a page a notch, the Bag's gap between turns; down or right on, up or left back) or a swipe
  that begins on it (`_barDragStart`, `_barDragTo`: past `barSwipe` 32 px, once a swipe; the finger going left: on). No
  tap on an arrow buys. All nine fit at 1600×947, 1266×713, 1164×777, 915×412 and the letterbox's 915×610, beside
  "Auto Buy" too; 568×320 holds 2 a page. Upright phones paged the cards (decisions-log 283 and 286) until the
  portrait game went (decisions-log 289).
- **+Room and Auto Buy** on the step beside the hotbar (the owner: "Di atas panggung"), +Room left of it and Auto Buy
  right of it, each 2 gaps off it (their press areas k nearer), level with the slots and a slot tall: their words the
  top band's Auto Wave's size (`_barFont`: 0.42 × the slot's height, 14 to 28 px), each as wide as its words with the
  top band's Auto Wave's margins; their press areas k round (`Board.capacityButton`, `Board.autoReplaceButton`). At
  1600×947 +Room's press area 325..481 and Auto Buy's 1119..1244 (x), 868..930 (y); at 915×412 75..192 and 724..819.
  +Room's words are on one line (an upright phone's two-line +Room, decisions-log 286, went with the portrait game,
  289).
  - **"+Room"** (`_barRoom`), moved from the Army page's header (decisions-log 260; the owner: "Pindah ke bar"): the same
    button, price, rules, words and refusals: the light bevel with "+Room  40" (`Words.room`, two spaces, `shortPrice`
    of `Game.capacityCost`; "Room: max", `Words.roomMax`, at the most); a tap buys `capacityStep` more room for its price
    (`Game.buyCapacity`, the zone a column wider while it can); greyed while it can't, when a tap says why in the
    message window with the game's own numbers (`Game.whyNotCapacity`, decisions-log 292): too poor "Not enough gold
    (need 60)." (the next buy's price), at the most "Army room is at its most (36)." (`Words.roomAtMost`, the room it
    holds: the capacity, at most `maxCapacity`); nothing else greys it (`canBuyCapacity`; at game over there is no
    bar). Its tooltip under the mouse or a long press (`Game.roomTip`) says first what it does: "+Room: more army room
    (60 gold)." (`Words.moreRoom`). Sized for "+Room  8888", so it never moves as the price grows.
  - **"Auto Buy"** (`_barAuto`; `Words.autoBuy`, "Auto" until decisions-log 290, named apart from the top band's
    "Auto Wave"): the top band's Auto look (the light bevel, orange while on, its words); a tap (on tap down) turns
    `Game.autoReplace` on or off (`setAutoReplace`), mid-wave too; its tooltip (`_Hint.autoReplace`, `Game.autoTip`):
    "Auto Buy" over "Auto Buy: replace fallen troops." and "On: each one comes back as gold allows." or "Off.".
- **Auto, replace the fallen** (`lib/auto_replace.dart`; the owner: "Auto ganti yang gugur"). Off by default: a game
  without it plays as before. While on, every troop that falls (not a Hero: a Hero's is Recall's, "Hero Gugur") is
  bought back, the same type, through a buy's own rules (`buyRefusal`, `autoPlace`), in the order they fell:
  - mid-wave from a queue filled as they fall (`_autoFell`), once a tick (`_autoReplaceTick`): the first one the gold
    doesn't cover yet holds the queue until it does; one refused for anything else (its type at its cap, an oath, no
    room) is skipped, saying nothing;
  - at the win "Replace fallen"'s list (`toReplace`) leaves out those Auto bought back during the wave (`_autoWon`);
  - between waves it works through that list in the order they fell, each to its old spot as "Replace fallen" puts it
    (`_replaceOne`); the gold short, the rest wait behind it; one refused for more than the gold stays on the list (its
    greyed button says why);
  - at the next wave's start what is left on the list goes into the queue (`_autoWaveStart`); what of it the gold
    hasn't covered by the next win is let go, as the list's offer itself ends at a wave's start;
  - one brought back mid-wave (a Rising Pusaka, a priest Hero's Resurrection) is no longer down: its type's last entry
    of the wave leaves the queue (`_autoRose`, decisions-log 317), so Auto doesn't buy it a second time. One Auto
    already bought stays bought, and counts at the win like any other.
  Turning it off empties the queue. The save keeps it (`"autoReplace": true`, written only while on; a save without it
  loads off); the queue isn't saved (it is empty between waves).
- **The field under the bar** takes no press, hover or drag (`_onBar` in `_covered`, plates.dart: the step with its
  slopes, +Room's and Auto Buy's press areas): a tap on a slot pins no plate, a hover shows no unit's name, a drag moves
  no troop.
- **The step** (`_barStep`, `battle_step.png`; tool/import_battle_floor.py, from the floor's own pack, GandalfHardcore's
  FREE Platformer Assets; decisions-log 295): one piece of earth with the floor's, `___/<menu>\___`. Floor Tiles1's
  grass-topped cell runs along its flat top, and at each end its grass turns down a slope to the floor's low grass, 60
  floor px (12 world units) lower, where the floor's own front edge goes on: each column of a slope is that cell's
  column lowered to the ground's height there (a half cosine over 96 floor px: round shoulders, about 45° in its
  middle), the cell's earth under it. The pack has no diagonal ground tile; its one slope, Other Tiles1's rock pile, leans
  on a sheer cliff (the step's look until 295). The earth under the step, its slopes and the floor is one flat fill of
  the pack's earth colour, never cell by cell (cell by cell, the floor's smoothed paint showed a faint grid at the cells'
  edges). Drawn at the floor's own pixels (5 a world unit, `_layerK`, with the floor's paint), in the HUD after the book
  and before the hotbar, over the field. Its flat top runs a gap beyond the wider of +Room and Auto Buy each side,
  widened to a whole number of cells (half a cell each side at the most, so the grass runs on unbroken into both
  slopes), its slopes down to the low ground beyond, symmetric about the screen's middle, its earth to the screen's
  bottom; `_SpawnBar.area` (`spawnBarArea`) is all of it, the slopes' boxes included.
  Its top (`_HotGeom.stepTop`: 12 floor px of grass and roots over the hotbar's top) is the field's y `stepLip` 134: the
  scene is framed so ("Field size" in camera-and-field.md: the frame lifted, the lanes, the zone and the clamps
  unchanged), 2 world units under the lowest a unit's shadow reaches (132). At 1600×947 the step's top at y 849 (the
  lowest shadow's last row 839), its box 216..1384 (its flat top 311..1289; +Room's press area from 325, Auto Buy's to
  1244); 630 (623) and 170..1097 at 1266×713; 691 (683) and 90..1075 at 1164×777; 333 (329) and 29..888 at 915×412. A near-square window's slopes may run off the screen's sides (900×900).
  Beside the step the floor's front edge and Floor Tiles1's earth under it go on down to the screen's bottom (camera-and-
  field.md "Backdrop"); the battle log's button stands there, on the low ground at the right, over the slope's foot.
- **What it covers: nothing of the battle** (the owner: "supaya battle jangan sampai di belakang dari action bar"): no
  unit or foe (their shadows end 2 world units over the step), no shot (at most 8 under its place: the wizard's magic, units-and-combat.md), no loot pile
  or relic, no plate (a unit's sits over it) is ever drawn behind the bar, at every landscape size (test/bar_clear_test.dart;
  the w89 save's waves 90 and 91 with their boss, mini boss and 25 loot piles, test/probe_bar_clear.dart: none at
  1600×947, 1266×713, 1164×777 and 915×412). Only the ground's own marks reach under its top: a foe's wind-up ring or a
  skill's reach ring round a unit in the last lane (flattened to 0.45 of its reach under the unit's feet), as the floor's
  front edge stands in front of them.
- **The book** stands over it, shorter (`_bookLandscape`, "The book" under "Layouts": its bottom, as low as it bobs, two
  slots' height over the hotbar's bottom at the most, where 283's bar left it, so always over the step's top: a slot is
  taller than the hotbar's frame and the step's rise over it): 974×584 at 1600×947, 764×458 at 1266×713, 711×427 at
  1164×777 and 403×226 at 915×412 as before; 280×134 at 568×320. Nothing on the bar moves when the book opens or
  shuts.
- **Clear of the HUD** (test/spawn_bar_test.dart, and `pieces`' 'bar' in test/touch_hud_test.dart and
  test/hud_sweep_test.dart, every window from 900×400 to 2600×1500): the top band, the log button and its open panel,
  the book; the step too, but for its slope's foot under the log button, which is drawn over it.
- **The guide's P1** points at the first slot on the hotbar's page that buys now, else (one on another page can) at the
  arrow button toward it, else at the first slot on the page, whose tap says why ("Guide" below). Its picture of the
  bar (I1's gold rows, `_picGoldRows` in coach.dart) is two slots on a small hotbar.
- **For tests:** `Board.spawnBarCards` (each slot on the page, type), `spawnCard(type)` (Rect.zero: on another page),
  `spawnCardLook(type)`, `spawnBarArea` (the step), `spawnBarList` (the hotbar and its arrows), `spawnBarFirst`
  (settable), `spawnBarPerPage`, `spawnBarArrows` (back, on; Rect.zero: all the slots fit), `spawnBarPanel` (the
  hotbar), `capacityButton`, `autoReplaceButton`, `spawnBarRoomFace` (+Room's button as drawn), `spawnBarRoomWords` (its
  words and where). Shots: test/probe_hotbar_shots.dart (`SIZES`, `OUT`), test/probe_spawn_bar_shots.dart,
  test/probe_step_seam_shots.dart (the step's slopes).

## The Pusaka in battle (`lib/pusaka_look.dart`)

P2 "Bukti" (decisions-log 149; the design <agents>/reports/artefact-roguelike-design.md §3.8, §6 P2). The
owner, 2026-10-01: "sekarang user bener bener nga ada ngerasa apapun dari penggunaan artefaknya". The rules are
loot-items-relics.md "Pusaka"; this is how they are seen.

- **The ring:** under every living troop of a type with a Pusaka bound, drawn right after its shadow, before the
  skills' rings: a 1 px oval 20 × 8 (`_pusakaRingSize`, a little wider than the guard's 16 and the effects' 18, which
  sit inside it) round its feet, centred 1 above them, in the Pusaka's colour at 90%, steady (no pulse). Every troop of
  the type wears the same one, a Hero or an awakened troop too (theirs are the halo, and the coloured shadow and
  outline). In the sprites' pixels, as every ring on the field ("The field's rings in pixels"), in the Pusaka's colour
  at 90% (`_pusakaRingAlpha`); the guide's K6 picture draws it the same way (`_ringUnder`).
- **The icon:** left of the HP bar, 6 × 6 like a small relic's, past the ones the troop holds (6.5 left of the bar,
  13 behind one relic, 19.5 behind a Hero's two).
- **The colours** (`_pusakaColors`), kept off the awakening's blue, crimson, gold, violet and white and off the grass's
  green, so a ring never reads as an awakened troop's: Dragon Heart ember orange `#FF6A1F`, Dawn Star dawn pink
  `#FF7FD0`, God's Thunder lemon `#FFF04A` (its leaps' yellow), the Grail cyan `#3FE6FF`, Void Eye all but black
  `#1A0A2E` (in the log its mark's violet: the log's panel is dark). Book ink (`_pusakaInk`), for the build names:
  `#B8420A`, `#B0307E`, `#7A6800`, `#0A7C96`, `#3A1A5E`. The Legenda Dragon Crown (decisions-log 155) rings jade
  `#2FD6A0` (bluer than the grass, greener than the Grail; ink `#0B7A5A`), a first pass for the owner to tune; the
  oaths are the whole army's, so no ring or bar icon marks them (the Army page's title shows the oath). A Pusaka
  without an entry rings in cream.
- **Their heals:** batch E-3P's heals (Halo Lantern, Hearth, Heartbeat, Bright Spring) show the heal's sparkle (the
  `heal` impact, a priest's) on each troop they heal; Mercy Lily's bigger heal is the heal's own, Saint's Tear's
  cleanse the cleanse's. No new look.
- **Batch G-1P's Legenda** (decisions-log 231), no new art: Vengeance Mark's mark (`Status.pusakaMark`) is a rose ring
  `#FF5FA0` on the monster (`_effectRings`, beside Void Eye's violet); Mirror Shield's wave-long reflect shows the
  thorns mark over its troops, as Iron Skin's does; Ghost Step's miss shows the troop type's own hit burst on it; Ice
  Grip's hold is Impale's chartreuse dashed ring without the lance (`_impaleRing` draws the lance only for a lancer's
  pin), and on the boss its slow is a slow's; Martyr's Flame's and Wide Blows' extra hits show the type's hit burst on
  each monster (a burst's, a splash's).
- **Batch G-2's Legenda** (decisions-log 238), no new art: Guardian Chain's link is Shared Wounds' (the heart over each
  troop linked and the pale gold line at the feet to the troop taking the share); Soul Shelter's window is the Grail
  save's (the shield over each troop sheltered) with the holy flash on each as it comes on; Hex Blade's slime is Slime
  Hex's (the monster drawn as a slime until it turns back); Glory Seeker's might is a skill's (the sword over each troop
  of its type); Phoenix Plume's rise is Resurrection's (its gold summon circle and the holy flash where the troop rises,
  and the message "<name> rises again!"); Mana Font's MP shows the heal burst in MP blue (Mana Shield's) on each troop
  it reached; Rage Totem's and Phalanx's numbers show only in the damage.
- **Batch G-3's Legenda** (decisions-log 243), no new art: Vampire Kiss's heal shows the heal burst on the troop it
  heals; Wrath Psalm's smite the holy hit burst (a Priest's smite's) on each monster it strikes; Grave Seal shows nothing
  of its own (the heals that don't land).
- **Cheap at 32+ troops:** each frame `_PusakaLook.refresh` maps type → Pusaka once (before the units are drawn), so a
  troop finds its own in one lookup, and each ring is one draw of the one ring image in a paint made once per colour
  (`_pixelPaint`): no Paint per troop per frame.
- **The Grail's cut-in** (once a wave): the wave's first Grail save (`Game.grailFirst`, drained by `_grailNews` after
  the casts) shows for `grailCutTime` 1.6 s on the screen's clock: the tooltip frame's tan body at 2× (`_tipBody`,
  sliced 3/3/3/5, the foe banner's plate), centred under the top rows, the map and the boss bars (`_plateTop`), rising
  8 px as it fades in (the first 12%) and fading out over the last 25% (one layer, so its slices fade as one); in it
  the Grail's icon and "Grail saves Kael Drake!" ("Hero <name>" for a Hero; one builder, `_grailCutLine`, for the
  drawn text and `Board.grailCutIn`) in the tooltip ink (`_tipInk`),
  18·s (13 at least), cut to the screen. Until decisions-log 173 it was a dark plate drawn in code, edged in the
  Grail's cyan. Drawn over the field and under the HUD, after the "VICTORY!"
  popup. It pauses nothing and takes no press (no `_hits`, not in `_covered`). Later saves of the wave log a line but
  show none; another game coming in drops it. `Board.grailCutIn` is its text while it shows. Not behind Settings'
  "Hero spotlight" (that one is the Heroes').
- **Build names**, the "VICTORY!" line and the log's lines: "The book" (the troop row), "Unit plates", "Win popup" and
  "Battle log" above and below. Every string is in the HUD font's glyphs (it has "×", "·", "–" and "—" but no "★" or
  "→"), checked by `test/pusaka_bukti_test.dart` against the font's cmap.
- **"★" in the book's text** (decisions-log 151): the font has no star, so `_text` draws every "★" in a line as
  ui_icons.png's full star (`_starIcon`, `_starW` = 0.85 of the text size wide) between the text's pieces, and
  `_textWidth` counts it so; any HUD string can write a Pusaka's stars as "★2" (`_starGlyph`): the Bag slots and
  rows, the Army badge, the Shop's "Owned ★1", the tooltips' "On: Templar ★1", the chest's messages and log lines
  ("Iron Banner ★1!", "Boss Chest: Iron Banner ★1 (Rare) to Templar").

## The field's rings in pixels (`lib/pixel_shapes.dart`)

The owner, 2026-10-12: "ring putih atau kuning di bawah troops di buat jadi pixelated" (decisions-log 325), then every
other ring, the Hero's halo and the reach too (325b). No ring, halo or disc on the field is a smooth line any more:

- **How:** each shape is cells one world unit each, as a sprite's pixels. `TdGame.onLoad` builds every one once
  (`_buildPixelShapes`) as a white image with a clear pixel all round, into process-wide maps (`_ringImages`,
  `_dashImages`, `_haloImages`, `_discImages`). A draw is one `drawImage`, nearest and without anti-aliasing, flat in its
  colour (`_pixelPaint`: one paint per colour, made once, given its alpha at each draw; `_flat`), its top left a whole
  number of world units from the feet (or the cell) it is round, so at any zoom its steps fall on the sprites' pixels
  and a screen pixel is the colour or nothing. No Paint is made per unit per frame.
- **A ring** (`pixelRingCells`): each cell whose middle is inside the oval and one of whose four neighbours' is not, a
  stepped line one cell thick (the units' shadows' kind of edge), its box centred 1 above the feet (`_ringImageAt`; an
  odd height's half a unit higher, to stay on a whole unit). The sizes: the Pusaka's 20 × 8 (`_pusakaRingSize`), the
  guard's 16 × 7 (`_guardRingSize`, rows 5 above to 1 below the feet), Spear Wall's brace 18 × 8 (`_braceRingSize`) and
  the effects' one inside another 18 × 8, 14 × 6, 10 × 4, 6 × 2 (`_effectRingSizes`; a fifth and later takes the last;
  they were 18 × 8 shrinking by 3 × 1.2). Colours, alphas and pulses are as they were.
- **A dashed ring** (Impale's pin, Ice Grip's hold; `pixelDashCells`): the ring's cells whose angle round the oval falls
  in the first half of one of its `ringDashes` 10 shares, turning 0.8 rad/s as the arcs did, in `dashPhases` 8 steps
  through a dash and its gap (`_dashedRingAt`).
- **A Hero's halo** (`pixelHaloCells`): a disc of radius 14 ± 1.5 pulsing, drawn at the nearest whole radius (13-16,
  `haloRadii`), centred 11 above the feet, in `haloBands` 4 bands of white out from the middle, each the old gradient's
  alpha at the band's middle (0xDD in the middle, 0x88 at 60%, clear at the edge): about 0.80, 0.66, 0.50, 0.17.
- **A dragged troop's reach** (`pixelDiscCells`): while a troop is dragged over a cell it can go to, a filled disc of
  its type's range (whole units) round the cell's middle, white at 12% (`_discAt`); the cell's square is as before.
- **Tests:** `test/pixel_rings_test.dart`; the shots `test/probe_pixel_rings.dart` (testing.md "The field's rings in
  the sprites' pixels").

## A foe's skill banner (`lib/foe_cut_in.dart`)

A monster champion's skill gets a banner (the owner, 2026-10-02: "dan ketika champion musuh (< mini boss) skill juga
ada effectnya dan ada splash screennya"; decisions-log 170). Built from the packs' sheets only, after the owner's rule
of the same day ("effect buatanmu coba di ganti pakai asset yang ada karna jadi nga masuk sama gamenya"): every piece
is a sprite; only the text is drawn.

- **What feeds it:** `Game.monsterCasts` (a wind-up beginning, Reassemble and Split as they go off), drained in
  `_drainCasts` (skills.dart) → `_foeCast`. Only a caster ranked a high elite or above; the rank shown is
  `foeCutRank`: its own, or for a monster a skill brought in its maker's (`Unit.raisedBy`), so Split's slimes show
  their mini boss. A cancelled cast keeps its banner, like the log's line.
- **Which casts** (`FoeCutGate`, lib/cut_ins.dart, the owner's choice (a)): once per skill and rank a wave (the wave is
  `Game.wave`; a new one starts afresh). A high elite's: at most `foeCutPerWave` 4 a wave, `foeCutGap` 4 s apart on the
  screen's clock, and one turned away stays unseen, so a later cast of it may still show. A mini boss's and the boss's:
  always, and first in line.
- **The queue** (`Board._foeCuts`, a `CutIns` with its own time and line): one shows at a time for `foeCutTime` 1.4 s on
  the screen's clock; at most `foeCutWaiting` 2 wait; a mini boss's or the boss's goes before every high elite's
  waiting (`front`), and one more than 2 drops the oldest high elite's. Ticked in `update` after the Hero's; another
  game coming in clears it and the gate.
- **Look** (`_foeCutIn`, drawn after the Hero's cut-in band, so over the HUD and the dragged loot, under the Hero
  splash, the Boss Chest and the score screens). It pauses nothing and takes no press.
  - The plate: the tooltip frame's body (`_tipBody`, ui_tooltip.png, slices 3/3/3/5) at 2×, the Hero splash's and
    the Boss Chest's panel; as wide as its portrait, ribbon and line need, 360 at most (360·s on a desk) and 16 off the
    screen's edges.
  - At its left the book's paper card (ui_all.png's page frame `_framePlain`, (1021, 13, 22×22), the Tas page's rows'),
    19 sprite px square at 3× (2× when s < 0.9), and on it, inside its rim, the caster's own idle sprite
    (`tiny_<type>_idle.png`, as tall as the inside, feet on its bottom, facing left), recoloured and outlined in its
    rank's colour (`_tierPaints`, `_tierLines`, as on the field). Not the boss bars' portrait frame: its navy inside
    swallowed a mini boss's purple, and the boss bars' slate behind the portrait is drawn in code.
  - Beside it the red ribbon flag (ui_book_marks.png's closed red one, `_ribbonClosed(_ribRed)`, slices l 1 / r 10)
    at 2×, as long as its title: ui_icons.png's yellow "!" (192, 32) at 16·2, then the skill's English title, bold, in
    cream `#FFF1D6`, 18·s (13 at least; shrunk to 11 and then cut with ".." if the plate is too narrow: none is at
    1266×713 or 915×412). Under it "`<rank> <type>`" (`foeCutLine`: "High Elite Orc", "Mini Boss Slime") in the
    tooltip's ink, 14·s (11 at least).
  - Where: at `0.3·h + 106·s`, under the Hero cut-in's band (which ends at `0.3·h + 100·s`), at the right, or at the left when its
    caster stands under the right one (picked once as it comes in: `_unitRect` against the plate, 16 px round). It
    slides in from its own edge over the first 15% of its time and back out over the last (cubic eases).
- **The boss's moment** (`MonsterRank.moment`) gets a band instead (`_foeBand`): ui_all.png's red studded frame (681,
  248, 30×34; slices l 7, t 8, r 7, b 9, so the corner studs and the darker lip keep their pixels) at 2×, across the
  screen 8 px in from each side, as tall as its two lines need (104 px at 1266×713). It slides in from
  the right and out to the left. On it the boss's idle sprite 1.3× the band tall, standing on the frame's inside
  bottom at the right (12% of the width in), in its rank's colours, facing left; the band sits low
  enough that the boss's head starts at the banner's top, so it stays clear of the Hero band. The "!" and the title in cream outlined dark (30·s, 18 at least), and the rank line in cream under
  it (17·s, 12 at least).
- **Setting:** Settings' "Monster spotlight: On / Off" (`Settings.foeCutIns`, settings.json `foeCutIns`, on by
  default and when missing), above "Hero spotlight"; off drops the banner showing and those waiting, and casts while off
  make none. Field effects and the red title pop over the caster always show.
- For tests: `Board.foeCutIn` (the title and line as drawn, the title's size, whether it is the band, where it rests and
  its ribbon), `foeCutShowing`, `foeCutsWaiting`, `foeCutButton` (test/foe_cut_in_test.dart, test/cut_in_test.dart;
  shots: test/probe_foe_cut_shots.dart).

## Foe splash (`lib/foe_splash.dart`, `lib/monster_skill_texts.dart`)

A monster skill's first sighting gets a splash (champion-fx Part 4; the owner, 2026-10-02: "dan ketika champion musuh
(< mini boss) skill juga ada effectnya dan ada splash screennya"; decisions-log 174). Built from the packs' sheets
like the banner above.

- **When:** the first cast this device ever sees of each of the 42 monster skills (`Game.monsterCasts`: a wind-up
  beginning, Reassemble and Split as they go off), in `_foeCast` before its banner, which it replaces: that skill and
  rank shows no banner later in the wave, and it doesn't count against the high elites' 4. At most
  `foeSplashPerWave` 1 a wave; a boss's moment (`MonsterRank.moment`) always, outside that count.
- **Turned away** (it stays unseen, and the skill's next cast tries again): no seen set (a widget test's board),
  "Monster spotlight" off, a splash showing, a guide card, the Hero splash or the chest popup up, the game paused or over,
  the book on another page than Pasukan, a troop or loot being dragged, or the wave's one already shown.
- **Seen:** `foe.<skill>` keys (`foeSplashKey`: "foe.warShout") in the guide's seen set (`Settings.seen`,
  settings.json's `seen`), added and saved as it opens, so a new game never brings one back. A device's seen set from
  before (`seenFrom`, "Guide" below) holds none, so the owner's w86 save meets them one by one.
- **The freeze** (`_foeSplashHolds`, in `update` before the tick): while it shows `Game.tick` is skipped, and the time
  goes into the field's stopped clock (`_Pause.still`, unless the game is paused too); the Hero cut-ins, the foe
  banners (and a desk banner's side) and the Grail's plate wait with it (their `since` moved on by each frame's dt).
  It isn't the pause: no "Pause" title, no quieter music, `Game.paused` stays false. A Hero splash due mid-wave waits
  for it (`_heroNews`), and the guide's one-time cards wait for it (`_foeSplashBusy`, coach.dart).
- **Closes** after `foeSplashTime` 4 s on the screen's clock, on a tap anywhere, Esc or P (P doesn't pause), or when
  another game comes in. The press that closes it does nothing else: `_foeSplashDown` is second in `onTapDown`, after
  the guide card's, and `_foeSplash.tapped` stops its tap up and drag; the wheel and a right click do nothing,
  `_covered` (plates.dart) is true everywhere, and `_coachClear` empties the HUD's press and tooltip rects for the
  frame. Auto's `held:` has it too (a splash is mid-wave, so it never meets a countdown).
- **Look** (`_foeSplashCard`, drawn after the banner, so over the HUD, the Hero band and the banners, under the Hero
  splash, the Boss Chest, the score screens and the message window):
  - The screen dimmed 45% (popping in over `_heraldIn`) but round the caster: the Hero cut-in's spotlight
    (`_heroSpotlight`'s radial dim) over the whole screen, so the caster's red wind-up circle (skills.dart) shows.
  - The panel: the tooltip frame's body (`_tipBody`, 3×, 2× when s < 0.9), `min(360·f, w − 32)` wide, f = 1.2·s, popping
    in from 0.6× and fading over the last `_heraldOut` 0.3 s, with the splash's soft shadow.
  - Its head: the caster on the book's paper card (`_foePortrait`, the banner's, at 3×) beside the red ribbon flag
    (`_ribbonClosed(_ribRed)` at 2×) with ui_icons.png's yellow "!" and the skill's English title, bold, cream,
    18·f (13 at least; shrunk to 11, then cut), and "`<type> <rank>`" under it in the tooltip's ink, 14·f (11 at least).
  - Then what it does (`monsterSkillText`, dark ink, 15·f, 12 at least, wrapped to the panel: 2 lines at most), how to
    stop it (`monsterSkillHint`, the tooltip's ink, 14·f), the time left on the wave meter's long bar (ui_bars.png
    (1, 15, 30×5) at 2×, its red column `_meterRed` draining) and "Tap to continue" (the tooltip's ink at 60%).
  - Where: mid-height, centred at 72% of the width when the caster stands in the left half, else at 28%.
- **The words** (`lib/monster_skill_texts.dart`, pure Dart): one line a skill in very simple English with the item
  text's glossary ("In-game text" below; also "shield"), the caster "it": "Melee troops near it must fight it, and it
  takes 30% less damage." Every number comes from the skill's constant (`bulwarkK.cut`), and a line holds only numbers
  that are the same at every rank (a mini boss's stronger War Shout still "hits harder"). The hint: "Stun or shove it
  while it winds up." (a high elite or mini boss), "Shove it while it winds up." (the necromancer, never stunned),
  "Holy damage stops it." (Reassemble); none for a boss's cast (never stunned or shoved) or a skill that never winds
  up (Split, Frenzy, Thick Hide).
- For tests: `Board.foeSplash` (the cast, its title and size, rank line, text lines with their size and room, hint and
  panel; null: none) (test/foe_splash_test.dart; shots: test/probe_foe_splash_shots.dart).

## Boss Chest (`lib/chest_popup.dart`)

The boss's chest, on screen the "Boss Chest" (decisions-log 152; in English since decisions-log 197; its rules:
loot-items-relics.md "Peti Bos", the code's name). `_ChestView` holds it between frames.

- **When it opens** (`_chestNews`, in `update` after the Hero splash's news): a chest is due (`Game.chest`: one waits)
  between waves, once the win's cheering is over (`victoryTime`) and no new Hero's splash shows or waits: so after a boss
  win it is VICTORY!, then the splash, then the chest. It stays open until Take or Skip deals with it: **no Later**
  (decisions-log 281; the owner: "remove later button dari opsi chest boss jadi user wajib ambil"), so it can't be put
  off, and with more waiting the next opens on the frame after. A loaded game with chests waiting (an old save's
  catch-up ones, or chests a save from before 281 kept waiting with Later) opens at once. Opening a catch-up chest rolls
  its cards, and the game is saved, so a reload shows the same. Another game coming in starts it afresh; a wave on or a
  game over shuts it. **Start pressed while a chest waits** for its popup (the win's cheer; `_startPress` →
  `_chestNow`) opens it at once, the cheer cut short, and starts no wave; while a new Hero's splash shows or waits it
  does nothing (the splash would draw under the popup), and the chest opens after the splash as above. So no chest
  ever waits through a wave.
- **Auto:** while a chest is due the countdown stands still (`_chestHolds` on `tick`'s `held:`), until it is taken or
  skipped. A Town due after a boss wave is gone into only after that too (town_look.dart's `calm`).
- **Look:** like the Hero splash (`_heroSplash`): the screen dims (black, 65%) and the panel, the tooltip frame's body
  (`_tipBody`, 3×, 2× on a small screen), fades in over `_heraldIn`; sizes follow `_screenScale` (s), the text is f =
  1.2·s (1.35·s on a phone). Drawn right after the splash, before the score and message screens; the HUD under it takes
  no taps, drags or tooltips (`_hits` cleared, its own kept in `_ChestView.hits`; a press anywhere is the popup's,
  `_chestDown`, after the message window's).
  - Across the top edge the ribbon (`_ribbonTitle`) with the chest's title (`Chest.title`): "Boss Chest", or "Missed
    Chest 1/3" (`Words.bossChest`, `Words.missedChest`); none
    while a guide card sits over the popup (K5, K12, K25: "Guide" below), whose own ribbon would sit right under it.
  - **Three cards**, side by side (230·f wide at most, the panel no wider than the screen less the margins). All as tall as the tallest one's lines need. A card
    is the book's plain page card (lit under the mouse, `_rowCard`), the frame itself recoloured by its rarity
    (`_rarityFramePaints`, made once): a colour matrix (`_recolour`) takes ui_all.png's page frame's three colours
    (paper `#F6CA9F`, rim `#E69C69`, dark rim `#BF6F4A`) to the same paper and the rarity's rim and dark rim
    (`_rarityFrame`: Rare a light green `#8CC878` / `#4E8C46`, Epic purple `#B98CF0` / `#7E50C8`, Legendary gold
    `#F2C23C` / `#C8821E`, a Shard steel `#A4B2C6` / `#6A7A92`), so the pixel art's light and shadow stay. Until
    2026-10-02 a 2.5·f box in the rarity's ink was drawn over the plain frame; the owner had it out ("kotak ungu di
    takeout saja ... atau assetsnya yang kamu filter untuk mendapatkan warna yang berbeda"). No other page draws a
    rarity box over a frame (the Bag page's Pusaka slots and Vault chips use the grey and lit frames, the Shop its
    rows' frames; the log colours only its text). The rarity's ink (`_rarityInk`: Rare green `#3FA34D`, Epic violet
    `#9B4DFF`, Legendary orange `#FF9F1C`, a Shard steel `#8A9BB0`; no blue: blue means MP) is its name's and the
    glow's under the Pusaka's icon (56·f). Then: its name (18·f, shrunk to fit), the stars it will
    have (ui_icons.png's gold and dark stars, the one it gains glowing: the HUD font has no ★) with its rarity's name in
    its ink (`rarityNames`: Common, Rare, Epic, Legendary, from `Words`), what it does then (`relicEffect` at those
    stars, 13·f, wrapped), and where it goes ("New: for Knight" / "New: to Vault" for a new one, "On Knight" / "In
    Vault" for a star; "In-game text" below). A Legendary
    (decisions-log 155) has one star slot (`maxStars`), an oath "New: all troops, whole run", and Oath of One's card,
    while more than 2 types are alive (`typesAlive`), a red line "Waiting: keep only 2 types (now 3)", Oath of the
    Few's while more than 24 troops are (`armySize`, decisions-log 247) "Waiting: keep 24 troops or fewer (now 48)"
    (`oathWaitingOf`). A Serpihan's card has the gift box,
    "Shard", "One free Reroll, kept" and how many are held ("You have: 2").
  - **Pick, then Take** (decisions-log 281): a tap on a card picks it: it lifts 6·f and lights (`_frameLit`, recoloured
    the same way: its outer line in the dark rim's colour). A tap on another card moves the pick; a tap on the picked
    one again keeps it (no take: a double tap on a phone never takes a card unread); a press elsewhere on the popup,
    a near miss of Take between the buttons included, keeps it too. Skip's first press lets it go (as before). The
    button row's **Take** takes the picked card (`takeCard`): the message says "Iron Banner ★1!" (a Shard: "Shard +1:
    one free Reroll"; an oath: "Oath of One: Oath for all troops!", and under it the wait while Oath of One waits),
    the type's troops burst in gold (an oath's: every troop), and the game is saved. The next chest due opens on the
    next frame, nothing picked. Until 281 a first tap lifted a card with a green Take at its bottom and a second tap
    on it took it; the card no longer keeps that bottom band, so the cards are 4·f + 28·f shorter.
  - Under the cards a line: the hint at the left ("Tap a card to pick it", "Tap Take to get it"), the Shards held and
    the gold at the right in the store's gold ("Shard x2   Gold 1.2k").
  - **The buttons**, a third of the row each, side by side (32·f tall, labels shrunk to fit): Reroll with its price
    ("Reroll 2.5k"; "Free Reroll" with a Shard; greyed "Need 38k gold" when short, any other refusal its own words),
    Skip with its gold ("Skip +38k"; orange "Sure? +38k" after a first press, a second passes the chest over: "Chest
    skipped: +38k gold"), and **Take** where Later was: the popup's main action, the same `_button` as the row's others
    in the pack's green (`_btnGreen`, the old on-card Take's), greyed (`_btnWhite`, grey "Take") and taking no press
    until a card is picked; the hint above says what to do ("Tap a card to pick it"). The words are `Words.reroll`,
    `skip`, `take` and `sure`, which the guide's K5 quotes and draws.
- **The "Chest!" chip** (`_chestChip`, drawn by `_hud`): while a chest waits and the popup is shut, the pack's orange
  button with the gift box and "Chest!" ("Chest! x2" with two), as tall as the Start/Pause toggle, with a gold glow
  beating round it. Since no Later puts a chest off and Start opens a waiting chest (decisions-log 281), it shows only
  between waves while the popup can't yet: the win's cheer and a Hero splash before the chest opens; never mid-wave
  (`whyNotChest` set: none drawn). Centred under the toggle (and under its Auto hold line), 2·k down, in both layouts
  (decisions-log 220), kept on the screen. A tap does what Start then does (`_chestNow`). While the popup is open it
  takes every press, so the toggle under it starts no wave. The plates and the drop popup keep clear of it.
- **With the Shadows on** ("Shadows" below): the cards' marks, the hint, the reveal after a take and Skip's note.
- For tests: `Board.chestOpen`, `chestCards`, `chestPicked` (the card picked, null: none), `chestButtons` ('reroll',
  'skip', 'take': the row's, there greyed too) and `chestChip` (test/draft_hud_test.dart; shots:
  test/probe_chest_shots.dart).

## Shadows (`lib/omen_look.dart`, decisions-log 191)

The Shadows (code: Bayangan, `OmenKind`; their rules: loot-items-relics.md "Bayangan", what they do on the field:
units-and-combat.md "Bayangan on the field") seen: a Boss Chest's Artifact card hides a monster buff, revealed when it
is taken. **On in every build since decisions-log 319**; with `omensOn` off (`--dart-define=OMENS=false`, tests) nothing
of it shows: no marks, hint, reveal, chips, segment, ring, plate word or note, and every screen is as before them
(`test/probe_omen_off_shots.dart` with that define, byte for byte against a base from before them). The guide's K25
explains them over the first chest that hides one ("Guide" below). Every
picture is a cell of a sheet the game has: ui_icons.png's "?" (192, 48) and "!" (192, 32), cut to their inked columns
(`_markAsk` (196, 49, 8×14), `_markBang` (198, 33, 4×14)) and tinted `_monsterPop` (0xFFFF6B5E); each kind's
`OmenKind.icon` (Armor `item_shield.png`, Haste `item_gloves.png`, Mend `item_potion.png`, Spikes `relic_thorns.png`,
Wound ui_icons.png's half heart (16, 0), Barrier `relic_guard.png` in teal `tintTeal` 0xFF3FD0C0); Escort, which has
none, the wave's strongest monster (`poolOf(wave).last`'s idle frame, as its boss bar's portrait) in gold. The red glow
under an icon is the chest card's own (a circle in the ink at 0.3, as under a card's Artifact).

- **The card** (`_omenFace`, from `_chestCard`): "?" and the card's `omenMarks` "!" by its rarity (Rare 1, Epic 2,
  Legendary 3; the kind stays secret), 2 sprite px apart, in a row of their own,
  "Monsters:" then the marks (16·f tall), at the card's bottom (above the on-card Take until decisions-log 281), and
  the card grows by that row. Grey (`Board._greyscale`) when no
  kind has room for them (`omenPlace` empty: every kind full, "Monsters: full"). A Shard has none.
- **The hint** under the cards: on a chest with faces while the monsters hold no Shadow and none is owed, "Each card
  gives monsters a Shadow (! = how strong)"; with Skip armed from wave `omenFrom` 20, "Skip: next wave, the first 30% of
  monsters get +10% to all" (`Game.skipNote`), which the Skip's message repeats under its gold line.
- **The reveal** (`_Reveal`, on `_ChestView.reveal`): Take keeps a copy of the cards, their faces, their lines and the
  buttons' labels, and the popup stays up over it for `omenRevealFor` 1.2 s: the taken card lifted, the
  others' frames greyed, the buttons greyed with their labels as they were, and nothing takes a press. Each card's
  marks flip over (squashed across, `omenFlip` 0.3 s; the taken card's first, the others half a flip later) to the
  face's icon: the taken one's on the red glow with its kind and level ("Armor 3", in dark red 0xFFA0322D), the
  others' grey with "Dodged" (0xFF8E8A86); the label sits after the icon. `Sfx.magic` plays as it starts. The ribbon says what the monsters got (`Game.omenGotLine`:
  "Monsters got Armor 3"; an overflow's "Monsters got Armor 4, Haste 1"; "Monsters: full"). A press anywhere ends it
  sooner (`_chestDown`); then the take's message shows with a line more, "Monsters got Armor 3: Monsters take 15% less
  damage." (`Game.omenEffect`; an overflow's just "Monsters got ..."), and the next chest due opens on the next frame.
  While it shows, Auto's countdown waits (`_chestHolds`), and so do the guide's cards and pointer and the "Chest!" chip.
- **The chips** (`_omenChips`, `_OmenRow`): under the wave meter, right-aligned with it (6 px under it;
  under the open minimap, and under the "Chest!" chip where it shares their columns), on the dark `_panel`: one chip a kind the monsters
  hold, in `OmenKind` order, its icon (7·k, on a red 0.3 glow) and its level (5·k) after it, 11·k wide, k between
  (`_meterK`: 2 on a phone); then, while Skip's buff is owed (`skipBuffDue`) or on (`waveSkipBuff`, its one wave), a "!"
  chip. At most `omenKindsMax` 8 kinds and the "!": 9 chips (222 px at k 2), possible since the Langka pool holds more
  than 8 kinds (batch L-1B). While the book shows they go to the left under the top
  row (and the open troop list), as the boss bars do (`_asideLeft`; the map stays under the meter). The boss bars, the open
  battle log's top and a unit's plate stay under them; no unit is pointed at through them (`_covered`), and the
  off-view marker keeps clear of them. None at game over.
- **Their tooltip** (`_omenTip`, `_Hint.omens`): the pointer resting on them, or a tap (it stays `_omenTipFor` 6 s;
  another tap on them, or any other press, hides it). In the loot tooltips' frame, pointing up at them: "Monster
  Shadows" by a red "!", then a line a kind led by its icon ("Armor 2: Monsters take 10% less damage.", `Game.omenLine`
  from `OmenKind.hud` filled with its HUD numbers, `omenShown` (loot-items-relics.md "Bayangan": its percent, the very
  share its hook reads, Trickle's and Deathless's in seconds ("over 0.8s"), Unbowed's a count by level ("its first 2
  holds, stuns or hexes"), Vultures' rank word by level ("Silver and gold monsters"), Horde's, Adapt's and Spree's total
  at their 3 steps ("up to 18%"), at the shown factor: a wave's frozen one, between waves the army
  as it stands), the
  army over the cap ("Over the army cap (48/36): Shadows x1.33"), an old save's catch-up still to come ("Late Shadow: 6
  more, 2 each wave") and Skip's buff led by a "!" ("Skip: next wave, ..." / "Skip: this wave, ..."); each wrapped to at
  most 360 px (the screen less its margins on a phone). Where that box won't fit under the chips (the screen's bottom
  less 4 px), every line is wrapped again to at most 600 px, so it stays under them, wider and with fewer rows
  (decisions-log 291): at 915×412 with the most lines (8 kinds, the catch-up and Skip's) 17 rows at 360 rose over the
  chips (379×374); at 600 each line is one row (500×241). 1164×777, 1266×713 and 1600×947 have the room and keep 360.
- **Boss bars:** a Barrier (`Unit.shield`) is a teal segment (`_barrierFill`: `tintTeal` over 0xFF23877D) over the HP
  layers, its share of what it came on with (`omenK(OmenKind.shield)` of its max HP), draining from the first blow
  that breaks some; the HP layers show again as it goes (Renewal's shield is the same soak: the same segment, full
  while any is left when no Barrier is held); with Escort held a full bar's rank
  line ends "+2 escort" (`omenGuards`) in `_monsterPop`.
- **The field:** a monster with a Barrier wears Unholy Ward's teal soak ring (`Status.absorb`'s in `_effectRings`)
  until it breaks. The Escort's monsters are plain gold high elites. A troop under Sap's weaken shows it as it shows
  Roar's (a weaken a monster left on it: `_effectMarks`, `_effectRings`); no look of its own. The Epik kinds' buffs on
  a monster wear the ring of their status: Zeal's and Muster's mights War Shout's amber, Counterspell's absorb Unholy
  Ward's teal, Arrow Ward's shot ward Shield Up's steel grey; an enraged monster (Enrage, `Game.omenEnraged`: no status)
  wears the might's amber ring too (`_statusRings`). Batch E-2B's: Last Rage's might amber, Second Skin's absorb teal,
  Blood Moon's lifesteal Bloodrage's dark crimson, Close Ranks' guard the guard's pale ring (`_guardRing`), and
  Triumph's haste the mint of a monster's speed-up: `_effectRings` rings a haste only when it is a Shadow's
  (`Effect.omen`), so a monster skill's haste stays ringless. Bile Sacs shows the slime's own hit burst on each troop
  it hurts. Batch E-3B's: Heal Siphon shows the heal's sparkle on the monster it pays, Toll the necromancer's skull
  burst on the troop it costs, and under Trickle a troop's HP bar fills over the heal's time. Batch E-3's Bat Venom
  shows the bat's hit burst on the troop at each tick, its bleed as Pounce's shows. Batch G-1B's: a monster that shrugs
  off a pin, a stun or a hex under Unbowed flashes Hold Fast's steel shield and ring (`RingLook.brace`); the other nine
  show nothing of their own (their numbers are in the blows, the HP and the ranks). No new ring, colour or shape.
  Batch G-2B's: a monster that has killed a troop under Spree wears a red ring (the monsters' pop red, `_monsterPop`,
  in `_statusRings` after its status rings: the one new ring, in the rings' own style), Backlash's might War Shout's
  amber, Renewal's shield Unholy Ward's teal soak ring (as a Barrier's), Deathless's save the holy flash (the 'holy'
  hit burst) on the monster it keeps at 1 HP, and Side Swing the monster's own hit burst on the second troop it hits.
  Cover, Adapt, Warlord, Vultures and Mana Burn show nothing of their own (the blows, the targets and the MP bars).
  Batch G-3B's: Last Gasp shows the heal's sparkle on the boss or mini boss it heals; Spell Ward, Holy Ward, Hero Hunt,
  Oathbane, Rider Rush and Dusk show nothing of their own (the blows and the HP). No new ring, colour or shape.
  Batch G-3's Blight draws a troop under it olive while it lasts: the troop's own sprite under the recolour the
  monsters' ranks use (`_partTint`, tier_look.dart) at `tintOlive` 0.45 (`_blightPaint`, omen_look.dart); its icon is
  the slime hit sheet's splat (`fx_hit_slime.png` frame 6) in olive. No new ring, colour or shape.
- **Plates:** a monster's kinds end with the Shadows every monster has while they are held, "Armor" and "Spikes"
  (`Game.omenPlateKinds`).
- **The battle log** (its Musuh chip): `OmenGained` / `OmenEased` with the kind's icon: "Monsters got Armor 2 (Boss
  Chest w90)", "Late Shadow: Wound 2", "Carve: monsters got Haste 1", "Shadow eased: Armor down to 1"; and `OmenDusk`
  with Dusk's icon once a wave when Dusk falls: "Dusk: monsters (not bosses) deal 16% more" (its share then; short
  enough to show whole in the landscape panel).
- **An old save** owing a catch-up (`Game.omenCaughtUp`) says so once in the notes' window: "Monsters answer your
  Artifacts: 12 Shadows come, 2 each wave" (`Game.omenCatchUpNote`).
- For tests: `Board.chestRevealing`, `chestRevealLine`, `chestFaces` (each card's marks "?!!", or revealed "Armor 3" /
  "Dodged"), `chestHint`, `omenRow` and `omenChips` (`test/omen_ui_test.dart`; shots: `test/probe_omen_shots.dart`).

## Towns on the HUD (`lib/town_look.dart`, decisions-log 216)

The Towns' rules: loot-items-relics.md "Towns". The board has them since decisions-log 237, every game since 321 (the
TOWNS define went in 296, and `Game.towns`, the tests' way to the rules from before the Towns, in 321). The scene
drawn in a Town, its book and its taps are "Town" below.

- **Going in:** once a Town is due (`Game.townDue`) and nothing of the win is left on screen (the cheer's `victoryTime`,
  the Hero splash, the Boss Chest's popup or a chest due, a monster skill's splash, a guide card) the Board calls
  `Game.enterTown` and saves (a reload reopens the Town); never under the welcome screen. The book turns to the Smithy, and
  the scene fades in ("Town"). A save made in a Town comes back in it, and isn't gone into again.
- **"Leave town":** in a Town the Start/Pause toggle's Start is "Leave town" (`Words.leaveTown`): the same green
  button, place, height and blink as Start, as wide as its words (never a countdown's seconds there). A press leaves
  (`Game.leaveTown`) and saves; it starts no wave, the scene fades back to the field, and the button is Start again
  (paused in a Town it is Resume, as anywhere). The button reads it through town_look.dart's hooks (`_startShows`,
  `_startWord`, `_startMost`, the press `_leaveTown`), so whatever draws Start reads the same.
- **Auto in a Town** (decisions-log 328; the owner, 2026-10-12: "disable auto start kalau sampai kota"): no countdown runs
  in a Town, whatever Auto is: the button reads just "Leave town", and the Town stays until the player presses it
  (`_townTick` stops any countdown there). Auto Wave itself stays as it was set (it can be turned on or off in the Town
  too). Left by hand with Auto on, its countdown starts as after a win (`AutoStart.won`, `autoStartDelay` 5 s: "Start
  5" … "1"), holding through the fade back to the field and for whatever holds it on the field (the book on the Bag or
  Settings, the Auto hold `Game.autoHeld`: "Start/Pause toggle"), then the wave starts. (Before, Auto left a Town after town.json's `autoLeave` 5 s unless a press there
  stopped it; the key is gone, an older file's read as nothing.)
- **The wave meter in a Town** (the owner, 2026-10-04: "ketika di town wave metternya di ganti contentnya jadi semacam
  'in town' dan icon swordnya juga di ganti … intinya mau kasi tau ke user kalau ini lagi mode aman";
  `Board._inTownMeter`): the same panel at the same size (the tide badge's room kept, so the Town chip's place, the map
  and the boss bars don't move) shows a beer mug where the crossed swords are (`town_mug.png`, Kenmi's Cute Fantasy Icons
  Premium Food 3, its 16 px art at one screen px a pixel, as the swords), the Town's name, "In Millbrook" (`Words.inPlace`
  and its identity's name, decisions-log 326; "In town", `Words.inTown`, where that wouldn't fit), in the battle log's
  won green (0xFF9BE37A) where the wave's number is, and the coming wave at the right, before the caret: "next wave 7"
  (`Words.nextWave`, cream 0xFFFFF1D6; only "7" where that wouldn't fit). No bar, count or tide badge, and no tide
  tooltip; a press still drops the minimap. Once the Town is left it is the wave meter again. `Board.townMeterText`
  ("In Millbrook · next wave 7"; '' out of a Town) for tests.
- **The Town's name as it comes up** (decisions-log 326; `Board._townArrival`, town_look.dart): ui_ribbons.png's flat
  ribbon (the signs' `_ribbonTitle`) at 1.5 times the scene's scale (at the least the signs': as big as they are on a
  phone), under the HUD's band over the middle of the scene's room (left of the book when it is open), the identity's
  name on it ("Millbrook") and under it "Town 1 · Farming village" in cream with a dark outline; from the fade's middle
  for 3 s (`_townArrivalFor`), its last 0.5 s fading out. None for a game loaded in a Town, nor as it is left.
  `Board.townArrival` (its rect; Rect.zero when none) for tests.
- **The background save** (dev-workflow.md "App identity"): between waves now includes a due Town and the Town itself.

### The Town chip

- **When:** from the mark until the Town opens (`Game.townMarked`): between the two waves and during the wave before the
  Town (marked after wave 10 for slot 12: shown from wave 10's win through wave 11, gone once the Town opens). Not at game
  over.
- **Look:** ui_bars.png's dark capsule (82, 33, 12×6, the Bag counts', `_capsuleSrc`) 9-sliced 1 px, the Town's hammer
  (`town_mark.png`, Kenmi's Cute Fantasy Icons Premium Tools 351, its 16 px art at one screen px a pixel: 16 px, 32 from
  the meter's k 4) and cream words (0xFFFFF1D6) at max(11, 5·k): "Town after wave 11" (`Words.townAfter`). 20 px
  tall.
- **Where:** right-aligned with the wave meter (so inside the safe inset on a touch device), 6 px under it, and under what hangs there too: the open map, the Shadows' chips (the row's last) and the
  "Chest!" chip where it shares their columns. While the book shows the map and the Shadows' chips go to
  the left, and the chip stays under the meter, in the sky over the book's top right, clear of its tabs. The boss bars,
  the battle log's panel and the units' plates keep under it. `Board.townChip` and `Board.townChipLabel` for tests.
- **Tooltip** (`_Hint.town`, the loot tooltips' frame with the hammer): "Town after wave 11: Millbrook, a farming
  village" (the coming Town's identity, decisions-log 326), "Smithy: craft items and
  relics" (decisions-log 272), "Tavern: buy boosts" (decisions-log 268), and
  for a Town after wave `shopFrom` (the Shop open there; as shipped every Town, town.json's `shop.from` 1) "Shop: buy and
  sell" and what it pays well for, "Pays well for Boots, Potion, Gloves and Prayer Beads." (`Game.townTip`,
  `TownIdentity.wantsLine`).
- **The battle log** (Other chip): "Town after wave 11" when marked, "Town: Millbrook" when gone into (its identity,
  decisions-log 326; "Town" for an event without one), "Left town", each with the hammer.

### The Tavern in battle (`lib/tavern_look.dart`, decisions-log 268)

The boosts the Tavern sold (loot-items-relics.md "Towns: the Tavern"; its page: "The Tavern" below) on the field,
existing art only.

- **The chips** (`_boostChips`): one per boost running (`Game.boosts`, in the order bought), the Town chip's look
  (ui_bars.png's dark capsule, 9-sliced, its corners cut): the boost's own icon (`_boostIcon`, the Tavern page's: the
  mug for the Feast, the sword for Strong Ale, a Champion's Plate its type's sprite, …; 16 px from its art at one
  screen px a pixel, 32 from the meter's k 4) and the waves it has left in cream ("2"), all as wide as the widest, 4 px
  apart. Under the Town chip when one is marked, else where it would go (`_underMeter`: 6 px under the wave meter,
  under the open map, the Shadows' chips and the "Chest!" chip in their columns), in rows
  right-aligned with the meter, as many a row as its width takes. In a Town too (a boost bought there shows at once);
  none at game over. The boss bars, the battle log's panel and the units' plates keep under them (`_boostRowAt`).
  `Board.boostChips` for tests.
- **Tooltip** (`_Hint.boost`, the loot tooltips' frame with the boost's icon; `Tavern.boostTip`): "Feast: 2 waves left"
  ("1 wave left"), then what it does, an effect a line ("+20% damage", "15% less damage taken"), then who
  ("All troops", "Knights"; none for the Lucky Toast).
- **The troops' burst** (`_boostBursts`): as the field comes back from a Town (the fade's turn, `_townSync`), each living
  troop a boost bought there touches (`Tavern.boostTouches`: one with a troop effect, on every type or on its own; a
  boost with all its `tavern.waves` left) bursts once with the field's upgrade burst (`fx_upgrade.png`, a chest take's).
  `Board.fieldBursts` for tests.
- **The battle log** (its Other chip): "Feast: +20% damage, 15% less damage taken (2 waves)" at the buy, "Feast ended"
  when it runs out, each with the boost's own icon ("Watchman's Brew: no life lost" went with the Brew, decisions-log
  329).

### The Bag's Materials (decisions-log 221)

The materials' rules: loot-items-relics.md "Town and Smithy: materials". The Materials chip shows in every game, its
page "No materials yet." while none is held (decisions-log 296; until then a game without the Towns had no chip and a
Materials page left on went back to All).

- **A kill's materials lie on the field until the wave is won** (decisions-log 262, the owner: "Material jatuh dan tetap
  terlihat di tanah tempat monster mati sampai wave selesai, lalu terbang ke tas"; `_matPopsIn`, `_matLootDraw`,
  `_matPopsDraw`, `_matFlight` in town_look.dart). Only the look: the tally and the bag move as in loot-items-relics.md
  "Town and Smithy: materials".
  - **The hop:** each kind a kill drops (`Game.matPops`: where, which, how many; drained every frame like the gold pops)
    hops from where it fell onto the ground there: its own icon (`mat_<key>.png`) at the size the items' loot had (10 field
    units), growing in from 60%, up 16 field units at the hop's top and down onto its spot, `_matPopTime` 0.6 s on the
    game clock, drawn over the units while it hops (with the casts' names and Plunder's gold in `_castPops`). Several
    kinds of one kill land 8 field units apart.
  - **Lying:** then it lies there for the rest of the wave as the items' loot did until decisions-log 321: on the ground
    under the units, so they walk over it and the HP bars and the HUD stay over it, bobbing 2 units on the field's clock.
  - **Piles:** a drop within `_matPileReach` 24 field units of a pile of its kind joins that pile (it hops onto it).
    From 2 the pile's count shows at its bottom right in the Bag's count capsule ("x5", `shortCount`; 12 px on the desk,
    10 and tight on a phone), over every icon. Past `_matPileMost` 40 piles the oldest that has another pile of its kind
    hops into the nearest of them, so at most 40 icons lie (every kind once would be 30). Each count is the capsule
    recorded once per label and size (`_matCounts`), so no frame lays its text out. Measured on the w89 save with the
    Towns and the forge on, 40 s into wave 90: 51 materials of 14 kinds in 40 piles (the cap), 9 with a count; the
    board's frame recorded in 1.64, 2.33 and 1.23 ms with them against 1.09, 1.63 and 1.24 ms without, in three runs of
    the debug test VM: within its noise. In such a brawl most piles lie under the melee line or off the camera, as the items' loot did;
    they show where the line has moved on, and all of them in the flight.
  - **The tally:** the piles lying always hold the wave's tally (`Game.waveMaterials`), kind by kind: a kind whose
    tally is dropped or reset without a win takes its piles off the field, and another game (Play again, a save loaded)
    starts with none. On a lost game they lie on under the game-over screen, as the items' loot does.
  - **At a won wave they fly to the Bag:** the piles take off nearest the Bag first, `_matFlyWait` 0.2 s after the win
    and `_matFlyGap` 0.03 s apart (closer with many: the last at most `_matFlyGaps` 0.3 s after the first), so they
    stream in. Each flies `_matFlyTime` 0.5 s on an arc to the Bag tab's icon, shrinking to it and fading over its last
    20%, over the field and the "VICTORY!" line, under the HUD. The book is shut at the win, so the tab's bag icon
    (ui_icons.png) shows for the flight where the book's Bag tab stands once it opens (`_bookFit`'s rest), bumping 25%
    as each lands and fading 0.25 s after the last. The bag has them from the win, as before: the "VICTORY!" line lists
    them at once. All on the game clock (x2 halves it, a pause holds it).
  - For tests: `Board.matLoot` (each pile's material, count and whether it flies) and `Board.fieldFx` (the hops).
- **"VICTORY!"**: the loot line lists the wave's materials after the items and relics, each kind once with its count
  ("3x" and the icon), in `Mat.values` order, wrapping like the rest (`Board.victoryLoot` for tests).
- **The chip and cells:** the Materials chip lists the materials held, a cell each (the Bag's slot and capsule, the
  count from 2 up), in the game's order (Common, Rare, Trophy); one an open wish's recipe takes carries the Wishlist's
  gold star at the top left, right of a NEW "!" (decisions-log 300; "The Smithy" below). All 30 fit one page on the desk (6 columns, 5 of its 6
  rows on the shorter landscape book, decisions-log 283); 915×412 holds 12
  with the pager, so 30 take 3 pages (2 before the shorter book). All shows them
  after the small relics. A material is never dragged onto the field (it goes on no troop), and the drag with one in hand
  carries nothing.
- **Its facing page** (action first, as the others): the heading (its icon, its name, "x14"); what drops it
  (`Game.matSource`: "Common material. Slimes drop it."; a Rare part's "Rare material. High elite werewolves drop it, a
  werewolf mini boss 2, a boss 3."; a Trophy's "Trophy. Every mini boss drops one."), the type's name from the
  monsters' plates, and under it in grey (9E9080) what it is for, `matUseLine` "Used at the Smithy, in a Town. Sold at
  its Shop."; then one action row, **Craft at the Smithy** (`BagAction.smithy`, `_smithyRow`): the Town's hammer, the
  title, and its line the relics whose recipe takes it ("Fang, Fury", by `TownRules.recipesWith`), outside a Town
  followed by "Only in a Town" (`Words.onlyInTown`; where the line is short, "Only in a Town" alone). Outside a Town a tap
  on it says "Only in a Town" in the message window; in a Town the row is lit under the mouse with the green ▶ on its
  right, and a tap turns the book to the Smithy with the first of those relics picked (decisions-log 235). **No Sell
  row**: the Town's Shop buys materials, on its Sell tab ("The Town's Shop", decisions-log 230 and 269).
- **Tooltip** (a cell under the mouse): its name and icon, what drops it (in the effect's green) and `matUseLine`
  (`Game.matInfo`).

## Town (`lib/town_scene.dart`, decisions-log 224)

While the player is in a Town (`Game.inTown`; "Towns on the HUD" above) the Board draws the Town where the field was
(`_townScene`, render's first part, then `_overField`: the HUD, popups and cursor as on the field). The field stays as it
was left (its game ticks on, no wave starts) and none of its looks (units, plates, the off-view marker) show: the whole
screen counts as covered (`_covered`), so no unit is pointed at, pinned, dragged or given loot. The minimap folds.

- **The art:** GandalfHardcore's free platformer set (assets.md; `lib/town_art.dart` names every file and cell), but the
  Smithy's smith: the Mana Seed Character Base demo with Pixel Crawler's anvil (decisions-log 265; `lib/town_smith_art.dart`).
  No shape is drawn in code; the fade is a colour.
  - Back to front: the Normal BG layers `town_bg_5` (the sky, parallax 0), the clouds, `_4` (0.15), `town_castle.png`
    (0.2, one, not a row), `_3` (0.35), `_2` (0.6), `_1` (1.0: the near pines and the ground), each 1024×346 world px
    tiling sideways; over their top layer 5's top row stretched up; from the street down the ground (below).
  - The Town's identity (decisions-log 326; loot-items-relics.md "Towns: the market"; `Game.sceneIdentity`, the Town last
    gone into, so the scene keeps its look as it fades out) picks its season's set (`townSeasonArt`): summer the Normal
    BG above (Millbrook, Willowmere), autumn the pack's Autumn BG (`town_autumn_bg_1..5`, `town_autumn_castle`: an amber
    sky and autumn grass; Ironvale, Ambergate), winter its Winter BG (`town_winter_*`: snowy pines and mountains, a white
    castle; Frostgate, Highspire), each laid out and moving as the Normal one, and its street (`town_ground_autumn`,
    `town_ground_winter`: Floor Tiles2's same cell in its autumn and snowy bands). Its yard is its own (below). The
    houses, the tent, the Smithy's and the Shop's pieces stay the same in every Town.
  - The clouds (decisions-log 274; the owner, 2026-10-08: "pada scene town tambahkan awan"): the field's
    `battle_clouds.png` (3072×130 px, side by side) at k screen px a px like the layers, its row 0 4 px over the layers'
    (as on the field), panning at 0.07 of the street (the field's `_cloudK`) and drifting left 6 world px a second on
    the field's clock (it stops while paused); the mountains, the castle and the pines hide their lower parts
    (`Board.townClouds`).
  - The street's line: world y 262 (`townLane`), the ground's top edge, where everything stands.
  - The ground (decisions-log 279; the owner, 2026-10-08: "disceene townya perlu di perbaiki lagi untuk ground levelnya,
    harusnya dengan sprite ini [his crop] dari Floor Tiles2.png, lalu di atasnya langsung bangungan dan tidak perlu di
    tambahin semua tempat diberikan dekorasi rumput di atasnya"): drawn right after the layers, before anything that
    stands on it (`_townStreet`), across the screen (`Board.townGround`):
    - the strip, `town_ground.png` (Floor Tiles2.png's cell (1, 0), the green block's top edge: its grass over its dark
      earth, 32×14; assets.md), its top edge on the lane, tiled side by side and panning with the street, so it runs the
      Town's whole 1010 world px (`Board.townScene['street']`): its 32-px tile is the sheet's own repeat, so the copies
      meet without a seam;
    - the earth under it: the tile's last row (one colour, 19,17,22, the block's fill) stretched to the screen's bottom

    Every building and what stands at it (the houses' porches, the tent, the campfire, the Smithy's pieces, the Shop's
    stalls, the yard's pieces) stands right on the strip, its bottom on the lane, and nothing is drawn over
    their feet; the smith stands on his house's floor, the porch's top. The taps, the signs and the anchors are taken from
    what is drawn. Until decisions-log 279 (274's ground) the buildings stood 4 world px over the street with Tall
    Grass's strip (`town_grass.png`) over their feet, and under it 2.5 world px of town_bg_1's full green, Floor
    Tiles1's roots (`town_floor.png`) and its earth; both files were deleted in decisions-log 294.
    Until decisions-log 274 the grassy lip (`town_floor.png` whole, 64×14) tiled along y 254 behind the buildings, and
    town_bg_1's flat green filled the screen under the street (the owner's picture: 47 px of it at the desk).
  - Along it, left to right (the owner's note of 2026-10-04): the troops' rest, the Smithy, the Tavern (the middle
    building) and the Shop. The three are buildings rebuilt cell by cell from `town_house.png` (`houseCells(n, storeys)`,
    below); the tent is only the rest.
  - The rest: the Large Tent (`town_tent.png`) and before its right side the pot over the campfire
    (`town_campfire.png`, the first of its 8 loops, 5 frames at 8 fps), its 32 world px of art ending at the tent's
    right (decisions-log 271; until then 6 past it, where the Smithy's wood corner now starts). No sign; a tap on the
    tent or its campfire opens the book on the Army (decisions-log 301, "Taps" below).
  - The Smithy: the smallest house (n −1, one storey). On its ground floor, before its window, the smith hammering at
    his anvil (decisions-log 265; the owner, 2026-10-07: "di dalam bangunan di kasi 1 npc yang lagi nempa saja nanti aku
    coba carikan spritenya"; lib/town_smith.dart): `town_smith.png` at 1 world px a sprite px (the houses' own; 28 world
    px tall, under its door), facing right, his feet at the house's middle (`_TownLayout.mid('smithy')`, under its sign)
    on its floor (its porch's top, `townStep` 8 over the street's lane, decisions-log 274, 279), the anvil before him; his loop (`townSmithBeats`, 3 s: the hammer back, three blows of up,
    swing and strike on the anvil's horn, then a pause) on the field's clock like the furnace (it stops while paused).
    Drawn over the house, before the pieces outside it and the troops, at every size, panning with the street; no tap
    of his own (a tap on him is the house's: the Smithy's page), no rule, nothing a battle reads. Only he stands between
    its walls (decisions-log 253 kept them clear for him). Outside it (the owner: "smithy
    furnace dan sawmillnya jangan di taruh di dalam bangunan"; decisions-log 271, the owner, 2026-10-08: "posisi
    furnace di sebelah kanan dan sawmill di sebelah kiri dari smithy"), at every size:
    - on its left its wood corner (`_townWood`, left to right, each piece's art 3 world px after the last's): the stump
      with an axe (24), the log pile (50) and the sawmill (`town_smithy.png` row 1, its art columns 4-60 of its 64,
      animated like the furnace; 60), its art 3 clear of the house's left eave tip (its door further in);
    - on its right, against its right wall, the furnace (row 0, its art columns 10-53 of its 64; 6 frames of 64×64 at
      8 fps, the field's clock: it stops while paused), its art 34 world px past the house, and the blue ore rock
      (53×38) 2 past the furnace's art, short of the yard's first piece;
    - its door and its sign clear. Until decisions-log 271 the work yard stood past the furnace as the room allowed
      (the ore by the furnace, then the sawmill, the log pile and the stump), none of it at the desk or the tablet;
      until decisions-log 253 the sawmill stood before its window and the furnace before its right wall.
  - The Tavern: n 1, one or two storeys by the height (the layout, below), its props from `town_props.png`
    (`houseProps`): the table, a crate, the barrels and the stacked crates on the balcony beam (two storeys; n −1 has
    room for the table and the stacked crates only), the cauldron on the right block.
  - The Shop: the smallest house (n −1, one storey) with its stalls before its window and right wall, the door clear:
    the apple basket, the fruit-and-bread table, barrels and the stacked crates.
  - The yard (156 world px) between the Smithy and the Tavern, behind the houses: the identity's pieces side by side
    (`_townYards`, from `town_yards.png`, assets.md; decisions-log 326), left to right: Millbrook the flowering tree,
    two wheat sheaves standing, a sack and a sheaf; Willowmere a boat pulled up on the bank and three potted plants,
    under the weeping willow (216 wide, in the middle of the yard behind the rest, scenery: no place's); Ironvale a
    birch, the gold ore rock and a lit torch; Ambergate the small market tent, the flower table, sunflowers in a vase and
    a bowl of grapes; Frostgate a cypress, two urns on plinths either side of the angel statue and a torch; Highspire a
    torch, a bust, the alchemy table (a skull, potions), an urn on its plinth and a tree. The torch's flame moves (6
    frames at 8 fps, as the furnace). Until decisions-log 326 every Town's yard was the olive pine (`town_pine.png`) at
    its left and the clothes line right of it, side by side, so the pine's first tier showed whole (decisions-log 253).
  - The signs: "Smithy", "Tavern" and "Shop" (`Words.smithy`, `Words.tavern`, `Words.shop`) on ui_ribbons.png's flat
    ribbon (`_ribbonTitle`, the Hero splash's: 64×20 at 2 screen px a sprite px at least, the words bold), centred over
    their building, its bottom 4 sprite px over the roof's ridge, kept 4 px under the HUD's band (`_meterBottom`).
  - On the street the army's own troops go about their errands ("The troops' life", below); but the smith, no other people or
    animals.
- **The scale and the street:** k = 2 screen px per world px, 3 from 1038 px tall (the scene's height / 346, at least
  2); no more than lets 582 world px across (`_TownLayout.fit`: the least Town before it was laid out wider than the
  screen), 1 at the least: so 915×412 draws it at 1. The scene is the whole screen and the street lies 92% down (low:
  the owner's "ground levelnya di turunkan"). (An upright phone's scene ended at its docked book's top, the street over
  it, until decisions-log 289.)
- **The layout** (`_TownLayout`; decisions-log 271): 1010 world px (`_TownLayout.full`) at every size, wider than the
  screen, which shows part of it and pans (below). From 2 world px in from the left: the rest (96 wide); the Smithy's
  place (374: its wood corner 134, its house 148, then the furnace's art 34 past the house, 2 clear and the ore's 53
  with 3 after it); the yard (156: the pine's 50 and the line's 106); the Tavern (n 1: 212) and the Shop (148); 4
  between each two; and 6 after the Shop (its cells' clear eave tip goes 6 past its 148). A screen wider than 1010
  world px at its k would share out the rest between the gaps. The Tavern has two storeys when the screen has 240 world
  px from its top to the street (the two-storey house's 200 and the HUD's band), else one. Until decisions-log 271 the
  Town was laid out as wide as the screen (582 at the least, a phone's 640), sizing the Tavern's n, the yard and the
  Smithy's work yard by the room, so in landscape the whole Town showed with the book shut. So:
  | Screen | k | Tavern | Shows (world px) |
  |---|---|---|---|
  | 1266×713 (the desk) | 2 | n 1, two storeys | 633 of 1010; 188 left of the open book |
  | 1164×777 (the owner's tablet) | 2 | n 1, two storeys | 582; 163 left of the open book |
  | 915×412 | 1 | n 1, two storeys | 915; 446 left of the open book |
- **Anchors for the troops** (`_TownLayout.spots`; `Board.townSpot(name)` on the screen, each on `townLane`): 'guard'
  (the Town's left end), 'tent' (the rest's mouth), 'smithy' (before the furnace, outside the house), 'tavernDoor' (the Tavern's door),
  'talk' (before the Tavern's right side), 'shop' (before the fruit table). One lane: the troops walk it and pass
  through each other ("The troops' life").
- **The house, cell by cell** (the owner: "House tiles itu harus di re-construct jangan langsung di pasang"): 16×16 cells
  of House Tiles.png's left house (the porch row's 16×8) on a 16-px grid, (14+2n) columns: the ridge in columns 6+n and
  7+n, each slope row two cells (the roof strip's top and its underside) down to the eave tips in row 5+n, the pure
  slope rows alternating so the last meets row 3's, the gable's bricks between; with two storeys the balcony beam (its
  joint once, mid) and the wall under it; the ground floor's 4 rows (the left wall and the door, the back wall with the
  window 2×3 at its middle, the right wall's pipe and block); the porch. n −1 one storey 192×152 world px (the Smithy's
  and the Shop's), n −1 two storeys 192×184, n 0 one storey 224×168, n 0 two storeys 224×200, n 1 two storeys 256×216;
  a house looks (14+2n)·16 − 44 wide (`houseSeen`: its grid but the empty end columns and the eaves' clear tips). The
  porch ends on the street's lane (decisions-log 274; until then 4 world px under it). `test/fixtures/town_house_cells.json` (the design's house.py output) pins the
  cells and the props of n 0 and n 1; n −1 follows the same rules (the smallest whose roof keeps a pure slope row before
  row 3's).
- **The book in a Town:** the tabs are Smithy (the Town's hammer, `town_mark.png`), Tavern (the wave meter's beer mug,
  `town_mug.png`; the street's order; every Town has it since decisions-log 268), Shop (the coin stack; open in every Town as
  shipped, town.json's `shop.from` 1, decisions-log 253; a later `shop.from` greys it until the store opens, a tap saying
  "Opens after wave <from>"), then the field's own three in its order: Army (the crossed swords; decisions-log 301, the
  owner, 2026-10-09: "di town tab army harus di munculkan dan ketika user tenda maka akan ke tab army"), Bag and Settings
  (`_bookTabs`). Until decisions-log 301 a Town's book had no Army tab ("no buys or Release in a Town"). It opens on the
  Smithy when the Town is gone into, from the Army too (`_townSync`; a game that comes in in a Town, a save, the same),
  and a shut book opens there too (`_home`).
  The Army's page is the field's ("Army" under "The book"): the grid and the picked type's detail, its Awaken tags,
  Wishlist, Artifact, Heroes (with their Recall) and relics, and Release, which works there as between waves. Two things
  differ: no spawn bar in a Town (no troop is bought there, as before), so the detail's foot has no "Replace fallen"
  either (`_replaceWords`; the offer waits for the field, where it lasts until the next wave); and a wish tapped on its
  Wishlist turns to the Smithy's Items tab on it (`_wishGo`), where outside a Town it says where it is made. Nothing is
  given from the Army detail (giving is the Bag's, in a Town as on the field). The gold's red dot (`armyNudge`) is on
  the Army tab in a Town too.
  The Smithy's pages craft the relics and the items ("The Smithy" below); the Tavern's sell the boosts
  ("The Tavern" below); the Shop's is the Town's Shop on the Bag's code ("The Town's Shop" below).
  Outside a Town the field's book has no Shop tab (Army, Bag, Settings: the Shop is a Town's), and
  the Army detail recalls the fallen Heroes itself (its Heroes section, "Army").
- **Taps:** a sign or its building (the bounding box of its cells, or the art of what stands at it: the Smithy's
  wood corner, furnace and ore, the Shop's stalls; `_TownView.hits`) opens the book on its
  page: the Smithy's, the Shop's (before the store opens, never as shipped, the message says when it opens), the
  Tavern's its own; the troops' rest (the tent's art and its campfire's, no sign) the Army's (decisions-log 301; until
  then a tap there shut the book, as the bare scene does). The places and their pages are `_townPages`. A
  tap on the scene outside the book, under the HUD's band, shuts the book, its
  page's place in the middle of the screen (the pan, below); a sign, a building or the tent opens it again. The cursor
  is the hand over the signs, the buildings and the tent.
  - A tap on the scene acts as the press comes up, not as it goes down (decisions-log 264; until then on the press):
    `onTapDown` only keeps the press (`_townDown`, when nothing over the Town took it: a button, a tab, the book, the
    troop counter, the log, a popup), and it taps on the release (`_townTapUp`) if it never moved `_townSlop` (8 screen
    px; a finger's drag starts only past Flutter's 18-px touch slop, so a finger's tap may move up to that). Moved
    further it pans and taps nothing. A tap that opens a page pans to that page's place even when it is the open one.
    The HUD's and the book's buttons and tabs still act on the press, as everywhere.
- **The pan** (0.4 s, easing out): with the book open the scene moves so the open page's place (the Smithy
  for Smithy, the Shop for Shop, the tent for Army (decisions-log 301), the Tavern for Tavern, Bag and Settings) has its
  middle in the middle of the strip
  left of the book; with the book shut the place of the page it shut on (`_TownView.shutOn`: the shut book itself goes
  back to the Smithy's page) has its middle in the middle of the screen, the view kept between the Town's ends (so the
  Shop's stands at the right end; decisions-log 271: until then the whole Town showed, the view's left edge at 0).
  A Town opens on the Smithy, so its first look is the Smithy's house and furnace left of the book (at 915×412 its
  whole place). A
  place's middle (`_TownLayout.look`) is its house's, the Smithy's that of its house's walls and its furnace together;
  its sign stays over its house (`mid`). The scene
  comes in at its place (no pan when it appears). Where it heads is `_TownView.aim`: it pans again when that moves (the
  page or the book changes) or a tap opens a page (`_townReaim`).
- **The player's pan** (the owner, 2026-10-07: "di kota user bisa scolling kotanya untuk melihat keadaan sekitar";
  decisions-log 264): the player moves the view's left edge sideways to look around.
  - **How:** a drag or a swipe (a finger's or a mouse's) on the scene follows the pointer from where it passed
    `_townSlop` (no jump) and, let go, glides on as far as its speed carries it in 0.4 s (the page pan's ease-out cubic,
    its start as fast as the pointer: v·0.4/3); the mouse wheel over the scene pans by its sideways scroll, else its
    up-and-down one (down goes right), gliding 0.4 s, the notches adding up (`_townWheel`, from `TdGame.onScroll`); a
    trackpad's two-finger swipe (Flutter sends it as a pan/zoom, not a scroll) follows the fingers as a drag:
    `TdGame` registers a `HorizontalDragGestureRecognizer` for trackpads only (`supportedDevices`), so a mouse's or a
    finger's drag stays the Board's own (`_townSwipe`, `_townSwiped`, `_townLetGo`).
  - **Its room** (`_townRoom`, `Board.townRoom` for tests): from the Town's left end at the screen's left (the view's
    left edge 0) to its right end (the Shop's eave tip, the layout's last 6 world px) at the right of what shows: with
    the book open the book's left, else the screen's right; widened to take in the open page's own pan,
    should it stand past an end. Measured with the book open on the Smithy (world px, k; decisions-log 271): the desk
    1266×713 0 to 822 (k 2; the book's left at 376 px), the tablet 1164×777 0 to 846.7 (k 2), 915×412 0 to 563.7
    (k 1). With the book shut, 0 to 1010 less the
    screen's width / k: 377 at the desk, 428 at the tablet, 95 at 915×412. (Until decisions-log 271, with the Town as
    wide as the screen: the book open 0 to 445, 418.7, −22.4 to 468.7 and 434; shut, nothing to pan.)
  - **What never pans:** a gesture that begins on the book, on the HUD's band (`_meterBottom`: a press there is a tap
    only), on a button or a tab, the troop counter or its list, the battle log's button or open panel, a message, the
    boss chest's popup, a guide card or a foe splash; the Bag's item drag and its lists' scroll are the book's, as
    before. With loot in hand a drag from the scene pans (until decisions-log 264 it carried the loot's ghost, which a
    Town gives to nobody). The battle field never pans: its camera is the game's (camera-and-field.md).
  - **It holds** until the page's own pan moves (a page, a tab, the book shut or opened, a tap on a place); leaving the
    Town and coming back opens it where a Town opens (the scene's first frame snaps to the page's place).
- **The fade** (`_townFadeDim`): going in, the field dims to the pause overlay's dim (black at 35%) over 0.35 s, then the
  Town comes up out of it over 0.35 s; leaving, the same the other way. Auto's wave waits for the fade back. A game that
  comes in already in a Town (Continue, a save) shows it at once.
- **The guide holds:** no card or pointer in a Town (they need a wave that can start, `Game.canStartWave`, false while
  the Town is due).
- **The troops' life** (`lib/town_life.dart`, decisions-log 229; the owner, 2026-10-04: the troops stroll about the
  Town, pass through each other on its one lane, and each does something: some stand guard, some talk with bubbles over
  their heads, some look round the Shop or the Smithy, some chat inside the Tavern, the tent only their rest):
  - **Who:** every living troop of the army, its Heroes too; the fallen and the monsters not (`TownLife.sync` follows
    `Game.units` every frame, allocating nothing while the army is the same). Each Town starts afresh: the troops stand
    somewhere along the street and set out at once.
  - **How they look:** the field's own strips (`tiny_<type>_idle` / `_walk`; no new art) with no ground shadow under
    them, plain or awakened, walking, standing, talking or resting (decisions-log 270; the owner, 2026-10-08: the army in
    the Town uses the sprites without a shadow): the shadow strip `tiny_<type>_shadow.png` is never drawn there, and none of
    the strips the Town draws has a shadow baked in (the Soldier's is cleared at load, assets.md), 2 world px a
    sprite px (`townFolkK`), so 4 screen px at k 2: about the field's own size (the field's scale is 3.7 at 1266×713,
    4.05 at 1164×777, 2.15 at 915×412). Feet on the street's strip, 0 to 4 world px under its top edge, the lane
    (`TownFolk.depth`, rolled once; decisions-log 279), the lower drawn in front; they walk through each other. **The
    soles on the line** (decisions-log 292; the owner, 2026-10-09: a priest resting in the tent still looked a little up,
    its feet floating over the hem): each type's frame is drawn with its feet's last row (`townFeet`, town_life.dart)
    just over its line (`TownFolk.sx`/`sy`, `Board.townFolk`'s `feet`): the strip at its depth, the tent's hem, the
    Tavern's sill. `townFeet` is mapped from the idle strips, every frame, in the body's own columns 44-55 (the priest's
    and the wizard's staff, column 56, reach row 57; the swordsman's blade, from column 58, row 59; the Soldier's baked-in
    shadow, rows 55-59, is cleared at load): all nine stand on row 56. Until then the Town drew every troop with the
    frame's row 59 on its line (the field's `_feet`, where a field unit's shadow goes, rows 55-59), so every troop's soles ended 2
    sprite px, 4 world px (8 screen px at k 2), over its line: over the tent's bare canvas, over the sill, over the
    strip's edge at depth 0. The field keeps row 59: there each troop stands in its shadow's middle. Over the
    buildings and what stands before them and over the ground, under the signs; the HUD and the book over them. The life's clock stops while the game is paused
    (they stand still).
  - **Inside is higher** (decisions-log 274; the owner, 2026-10-08: "ketika animasi para army masuk bangunan harusnya
    ground levelnya lebi naik lagi sedikit jadi terlihat ada perbedaan tinggi antar yang lagi di dalam bangunan dan yang
    diluar bangunan"): one on a building's floor (`TownFolk.up`: in the Tavern's doorway, or resting in the tent's
    opening, −30 to 22 world px from 'tent', `townTentOpen`) stands on that place's floor over the lane
    (`TownFolk.floor`) with no depth, drawn before the street's troops (behind them); it steps up as it arrives and
    down as it sets out on its next errand. Each floor is its art's own (decisions-log 279; 4 for both until then, when
    the grass hid the porch): the Tavern's doorway `townStep` 8, the houses' porch, on the door's sill; the tent's
    opening `townTentStep` 4, the top of its canvas's darker hem (its last 4 rows; the tent has no floor drawn, and at 8
    a resting troop hovered over the bare canvas). Since decisions-log 292 the soles end on each floor ("The soles on the
    line", above): a resting troop's on the hem's top, 4 world px over a street troop's at depth 0 (until then 4 world
    px over the hem, on the bare canvas). The Smithy's and the Shop's browsers
    stand outside, on the street; the smith (his own sprite, town_smith.dart) stands on his house's floor, the porch's
    top, as before.
  - **Their errands** (`TownDo`), rolled when the last one ends on the life's own visual dice (`TownLife.dice`), never the
    game's: a run plays the same with the Town's scene shown or not. One draw picks by `townWeights`:
    | Errand | Share | Where, facing | Stay |
    |---|---|---|---|
    | stroll | 6/25 | a point along the street, between its ends (10 world px in) | 1-3 s, looking about |
    | guard | 2/25 | the 'guard' anchor (the Town's left end) facing out left; a second at the right end facing out right; no third | 8-16 s |
    | talk | 5/25 | with the nearest one strolling (none: a stroll): they meet before the Tavern's right side ('talk') when no other pair talks there, half the time, else halfway between them, 26 world px apart, facing each other | 3-6 lines of 1.6 s |
    | Shop, Smithy | 3/25 each | beside the 'shop' stall or the 'smithy' furnace, 18 then 34 world px either side, facing it; at most 4 | 4-9 s |
    | Tavern | 3/25 | up its doorstep into its doorway ('tavernDoor') for `townDoorway` (0.6 s), gone inside, then back in the doorway 0.6 s and down on the street (decisions-log 274; until then gone at the door at once); at most 8 | 6-14 s inside |
    | rest | 3/25 | in the tent's opening ('tent' +0, +16, −14 world px: on its floor) or by its fire (+56; the fire 38 right of 'tent'), facing the fire; at most 4 | 8-16 s |

    A full place rolls a stroll. They walk at 0.6 of their type's field speed, 2 world px a sprite px (22-34 world px a
    second), the walk strip at 0.6 of its 10 frames a second.
  - **Bubbles** (no words): ui_all.png's speech bubble (white: said) or its grey see-through one (a thought), at
    max(2, k) screen px a sprite px (the signs' least, to be read), the tail's tip just over the head, a 16-px icon
    inside. The head is the type's own (`townHeads`, town_life.dart; decisions-log 237, 253; its height over the line
    from `townFeet`'s row since 292, so the bubble follows the head down), mapped from its idle
    strip's six frames together: x the middle of the helmet, hood, hair or hat between its outer columns, the weapon
    held beside it left out (the lancer's lance, the axeman's axe, the wizard's staff, the archer's bow); y its crown's
    top, the first row 5 px wide (a plume or a hat's tip counts, a weapon's tip never). Not its bounds' top: a lancer's
    bubble sits on its helmet, not on its lance's tip, and an axeman's on its helmet, not on its axe's blade.
    | Type | Head columns (frame px) | Crown row | The tail at |
    |---|---|---|---|
    | soldier | 45-54 | 39 | (50, 39) |
    | knight | 41-54 (its plume 45-47 on top) | 39 | (48, 39) |
    | swordsman | 44-55 | 38 | (50, 38) |
    | archer | 45-54 (its bow 59-60 beside) | 40 | (50, 40) |
    | lancer | 43-54 (its lance 56-58 beside, 8 rows higher) | 27 (the plume) | (49, 27) |
    | priest | 44-55 | 37 | (50, 37) |
    | armored_axeman | 45-53 (its axe's shaft 54-56, blade to 62) | 38 | (49.5, 38) |
    | wizard | 43-54 (its staff's orb 55-59 beside) | 38 | (49, 38) |
    | knight_templar | 45-54 | 39 | (50, 39) |

    The feet stand at (50, 59) of the 100×100 frame. A talk: a bubble the first 75% of each line, over the one who
    began it on the even lines and over the other on the odd ones, one icon a line on the dice from ui_icons.png's heart, star, coin, sword,
    crown and trophy and the Town's beer mug (town_mug.png). A browser thinks of the coin stack (the Shop) or the
    Town's hammer (town_mark.png, the Smithy) from 0.6 to 2.4 s after arriving. While anyone is inside the Tavern, a
    bubble with the mug at its window (the tail on the window's top middle), the first 1.8 s of every 5.
  - **Taps** go through them: a troop takes none, so a sign, a building and the bare scene answer as without them.
  - **No cap:** most of the street shows at once (all of it until decisions-log 271), so any number stand at a place.
    (An upright phone showed one place at a time and let at most `townCrowd` 6 stand in each of its three views,
    decisions-log 237 and 274, until decisions-log 289.)
- **For tests:** `Board.townShown`, `townFade` (the dim now), `townCam` and `townK`, `townScene` (each piece and place by
  name, 'scene', 'street', 'smith'), `townSign('smithy' | 'tavern' | 'shop')`, `townBuilding(place)` (a building's cells as
  drawn, in order), `townBuildingShape(place)` ((n, storeys)), `townSpot(name)`, `townLane` and `bookPage` (the open
  page's name); the troops' life: `townLife` (its troops, clock and street), `townDice` (a test's own dice), `townFolk`
  (each troop as drawn: its unit, errand, feet on the screen or null inside, facing, bubble and its icon) and
  `townWindowBubble`; `townClouds` (the clouds' copies drawn) and `townGround` (the ground's 'strip' and 'earth' as
  drawn; 'street' in `townScene` is the strip).

### The Smithy (`lib/smithy_page.dart`, decisions-log 235)

The Town book's Smithy tab crafts the small relics (the rules: loot-items-relics.md "Town and Smithy: Craft") and the
items (decisions-log 254; the rules: loot-items-relics.md "The forge: items crafted, Awaken by grade"), on the Bag's own
code (the owner: "pakai yang existing saja": the Bag's slots, grid, pager, capsules, action rows and the book's one
bevelled button; no new look). Only in a Town. The rows below are its Relics tab's; the
forge's strip and its Items and Enhance tabs follow them.

- **The left page:** "Smithy", then the relics' board: every small relic in play (`smithyRelics`: by tier, Basic,
  Strong, Mighty, in `Relic` order within one) as the Bag's paper-card slots (`_bagCell` on `_SmithyView.board`, the Bag
  slot's size), as many columns as the page holds and the rows that take all 20, centred, no empty slot after the
  last, on the page under the strip (decisions-log 302: the materials' grid that stood under it left every tab, and
  the board took its room); where the Bag's slot would page it, the small slot ("A short page" under the forge's tabs
  below). A relic's marks: the green ▲ (ui_icons.png (32, 144), the Bag's) when it can be crafted now (`canCraft`), its
  count in the Bag in the dark capsule from 1, its icon at 40% when it can't be crafted, the Wishlist's gold star while a
  free line has it (decisions-log 302); the picked one on the lit card (the pick's cream and orange). The small slot
  (`bagCellSize(k, small: true)`): 22×22 below the desk's scale with the 16-px art at (3, 3) (every loot icon file is
  Kenmi's 16-px icon doubled, so drawn at 16 with nearest sampling it is that icon, not a shrink), the Bag's slot from k
  2. No buttons on the left page: a tap on a relic picks it (again: it stays); the cells are never dragged. Until
  decisions-log 302 "Materials" (bold) and how many kinds were held stood under the board over the materials as the
  Bag's grid at the small slot (`_bagBoard` on `_SmithyView.mats`, which now only keeps the pages' press and release),
  their counts tight and tucked into the slot's corner (decisions-log 237), the picked relic's on the lit card, a short
  one's count in the red capsule; the recipe rows, the Bag's Materials and the Shop's Buy show them now.
- **Steady while the book bobs** (decisions-log 277; the owner, 2026-10-08: "di bagian bawah ini ada ngebug, slot
  materialnya blinking gitu"): the open book bobs up and down by a fraction of a pixel each frame, so every room on the
  left page is counted from the board's unrounded top (under the title or the strip) and only the drawing stands on
  whole pixels: the board at the rounded top, every height under it (the board's rows, the 6·ts gap, the Wishlist tab's
  heading and shelves) whole pixels, and a pager as far from the drawn top as from the counted one (until decisions-log
  302 the materials' grid was counted from its unrounded top, which its own rounding landed right under its heading).
  Before, the board's top was rounded first and the materials' rows counted from it against the page's unrounded
  bottom: their room changed by a pixel as the book bobbed, and where a row fit to within that pixel it came and went
  with the pager (at the owner's 1600×947 window on the Items tab: 4 rows and the pager, then 5 rows without it, in 11 of
  62 frames; every 1600-wide window from 896 px tall, and 1266×520 on the Relics tab). The Bag's grid had had the same
  bug once ("Pages, not scrolling" under "The Bag"). test/forge_smithy_ui_test.dart holds the left page still over a
  whole bob at all four sizes, on the Wishlist, Items and Relics tabs; test/probe_smithy_blink.dart is the probe that found it (a frame every 64 ms over a bob,
  and window heights 400 to 1000 at 1266 and 1600 wide).
- **The right page** (action first, the Bag's facing page): the heading (`_detailHeading`: the icon, the name, "x1" the
  Bag holds); what it does (`relicEffect`, ink) and "Strong relic. Best on: Soldier, Knight, Axeman, Templar." in grey
  (`relicTierLine`, `relicBestLine`); "Recipe" (bold) and a row per line of it (`craftRows`: the materials, the item, the
  gold last), each an inset paper card (`_card`, it only tells): its icon (`bagHeadIcon`: 32 px on the desk, 16 at
  915×412; the gold's coin), its name, then in a smaller grey where it fits whole the monster it comes from
  (`matFrom`: "Werewolf", a Trophy's "Mini Boss" / "Boss"), for an item in orange (C0601A) what a fielded type still
  needs of it (`craftItemNeed`: "Soldier needs 1 for Awaken 1", "Soldier needs 1" where shorter: Craft reserves no item,
  the design's decision 11), and on the right "have / need" ("8 / 4", the gold's "4,090 / 1,000"), green (2E8B3A) when
  enough, red (B0302A) when short.
- **A forged ingredient is a link** (decisions-log 323; the owner, 2026-10-12: "jika material dari item yang mau di
  forge, adalah hasil forge ketika user click itu akan mengarah ke forge item tersebut"): a row of an item the Smithy
  makes (a relic's item, the Cap's and the Ring's grade below; every item has a recipe) has the action rows' green "›"
  (ui_icons.png's `_icOpen`) at its right, its "have / need" left of it, and its card lit (`_frameLit`) under the mouse
  and while pressed. Its tap (on tap up, so a drag over the page scrolls it; `_assign.taps`, cut to the view) opens that
  product's page as picking it on its board does (`_smithyLink`: the Items tab on the item, its board on its page); the
  page it came from goes on a trail (`_SmithyView.trail`), and the new page's "Recipe" line, a tag tall then, has the
  light tag **Back** (`Words.back` with ui_icons.png's small back arrow, the Bag chooser's) at its right: a tap goes back
  a step (`_smithyBack`: the Royal Ring → the Gem Ring → the Ring, then back twice). A pick on a board, a tab tapped on the
  strip or the book turned clears the trail (no Back then). A material's row only tells, as before.
- **Craft:** the page's one bevelled ui_buttons button (its main standalone action, the owner's button rule), the
  page's width, max(20, 32·ts) tall: the green one "Craft (1,000 gold)" ("Craft (1000)", "Craft" where shorter) while it
  can be crafted; else the white one with why (`CraftRefusal.text`: "Need 2 more Wolf Claw", "Need 1 Gloves", "Not enough
  gold"). A press crafts one (`craft`) and the message window says "Venom crafted!" (`craftedLine`); on the white one it
  says why again (`Sfx.error`, nothing changes). No limit: the page stays on the relic, so the next press crafts another.
- **Under it:** in grey "No limit: craft again while you have enough", then the light action row **Equip on a troop**
  (`BagAction.equip`, the Bag's action row look, lit under the mouse, the green ▶): the troops' crossed swords, its line
  "1 in Bag. Opens the Bag"; a tap turns the book to the Bag with the relic picked and its Equip chooser open (its troop
  rows). None in the Bag: greyed, its line "Craft one first" in red, and a tap says it.
- **A short page** (`_smithyRecipe`; decisions-log 283, the landscape book shorter): under the heading the page scrolls
  where its parts don't all fit (`_SmithyView.facing`, lib/page_scroll.dart: "A page's scroll" under "The book"): the
  wheel or a drag over it, the Bag's capsule scroll bar down its right (`_capsuleBar`), the lines then wrapped clear of
  it; a new pick or tab shows its top. Nothing is left out (until then the grey line went first, then the Equip row,
  then the rows drew closer and the lines above them fewer); every line is drawn clipped to the view, and what takes a
  tap or a hover (Craft, the rows, Equip, the Wishlist's chips) is cut to it. The recipe's icons are `bagHeadIcon`'s:
  32 px on the desk, 16 at 915×412.
  The sizes on each tab: the table under "The forge's strip" below (test/probe_smithy_fit.dart prints them). The
  forge-off build's relics-only page and its table went with it (decisions-log 296).
- **The pick:** the relic picked stays while the Smithy shows; the tab (or a shut book opening on it) picks the first it
  can craft, else the first. A material's "Craft at the Smithy" in a Town opens it (`_openSmithy`) on the Relics tab
  with the first relic whose recipe takes it. (The Shop's "Cheaper at the Smithy" for a small relic went with the
  forge-off build: the forge's Shop sells none, decisions-log 296.)
- **The forge's strip** (decisions-log 254; every Smithy): under "Smithy" the Bag's segmented chips (`_chips`,
  the Bag chips' look: one paper strip, the tab on lit in the pick's cream and orange, its word bold) read **Wishlist |
  Items | Relics | Enhance** (`SmithyTab`, `smithyTabNames`, `Words.wishlist`, `Words.enhance`; the Wishlist first since
  decisions-log 302). The tab is the player's for the session (not saved; the Wishlist at first: the Smithy first opens
  on it, then on the tab last shown; a material's "Craft at the Smithy" turns to Relics, a wish tapped on the Army
  detail to Items). **Enhance** is greyed (its word in grey, never lit) until wave 30 is won (town.json
  `enhance.from`; `Game.enhanceOpen`, lib/enhance.dart, the one place the rule lives), and a tap says "Opens after wave
  30" (`enhanceLocked`, the refusal's `CraftWhy.closed` words); once open it reads like the others and a tap turns to
  it (a game whose Enhance is closed shows Items in its place).
  - **Items** (decisions-log 277; the owner, 2026-10-08: "untuk items tidak perlu di buatkan tab grade langsung saja di
    tampilkan semua"): no grade strip. Right under the strip every item at once, a section per grade, Grade I, II and
    III top to bottom, each its heading ("Grade II", `gradeTitle`; `_gridHead`, its words from the board's leftmost slot,
    as the Shop's Buy sections) over its 14 items, every kind's in `Item` order (`Craft.smithyItems`: the twelve Awaken
    kinds, then the Cap and the Ring), as the relics' board's cells and marks (the ▲ while `canCraftItem`, the count from
    1, the icon at 40% while it can't, the pick on the lit card). It is the Shop's Buy board's code (`_sections`,
    `_sectionsLay`, on `_SmithyView.items`): a 6·ts gap between sections; where they don't all fit on the page under the
    strip (decisions-log 302: the whole page, no materials under it), the pages are laid in that room, and the board
    stands as tall as its tallest page with the Bag's pager under it (`_bagPager` on that board; the wheel over it too, a
    notch a page): a page ends between rows, never under a heading alone, and a grade
    going on to the next page starts it with its heading again. At the
    small slot (`_BagGrid.shrunk`; 22×22 below the desk's scale) where the Bag's slot would need the pager. The pick
    opens as before: the first item a fielded type's lowest needed grade (`Game.awakenShort`, a living troop of the type;
    none: grade I) can craft now, else that grade's first; the board opens on the pick's page, and after that the page
    is the player's (a page turn keeps the pick and its facing page). The book turned to another page and back: the
    first pick and its page again. Nothing under the board (decisions-log 302: the Wishlist has its own tab; the recipe
    rows say what an item takes, have / need). The facing page is the item's: its
    heading, what one does ("+28% attack for one troop type."), in grey its grade line (`smithyGradeLine`: "Grade II: for
    Awaken 2 (Soldier 2, Knight 3, Archer 2)." with each fielded type's count, "No type here takes it." for none; the
    Cap's and the Ring's "Grade II: not for Awaken. At a type's cap a better grade swaps out the lowest."), its Recipe
    rows (`itemCraftRows`: the materials, the Cap's or the Ring's grade below, the gold), Craft (`craftItem`, "Steel
    Sword crafted!"; refused with why, "Need 1 Leather Cap"), the grey "No limit" line and the light row **Give to
    troops** (`BagAction.giveTroops`): a tap turns the book to the Bag with the item picked and its types listed, where
    a full Cap or Ring swaps out its lowest (decisions-log 249); none in the Bag, "Craft one first". A wished item's
    Give row: the Wishlist's, below.
  - **The Wishlist** (decisions-log 282; the rules: loot-items-relics.md "The Wishlist"; lib/wishlist_look.dart): an
    item some type wishes for carries ui_icons.png's gold star ((48, 0), its 14×14 at (1, 1); the Bag cell's `wished`
    mark) at its cell's top left, the corner the Smithy's boards leave free (no NEW, no "+"), k−1 px in from the slot's
    corner, and on the 22-px slot tucked 2 px out into the gap (it takes the icon's corner only, 9×9, clear of the ▲ at the
    top right; the pack's own 16 px, since no smaller star reads); the board lists a grade's wished items
    first, then the rest (`smithyItemOrder`; the same sections and pages as before, nothing twice). Chosen over a
    "Wishlist" section on top: that would show an item twice or take it out of its grade and change the board's pages
    at 1600×947 and at 915×412. The pick opening the tab takes the board's order, so a wished item it can craft comes
    first. A relic a free line has (decisions-log 302) carries the star on the Relics board (in its order: relics keep
    their tiers). A material an open wish's recipe takes (`wishMats`) carries the same star, steady (drawn with the cell,
    no blink), in the Bag's Materials (right of a NEW "!", which keeps the corner) and the Shop's Buy (decisions-log 300),
    where the player looks for or buys it (the Smithy's Materials had it until decisions-log 302 took them out); its
    tooltip ends "Needed for your wishlist". A met wish's item and materials carry no star (only open wishes do). The item's
    or relic's facing page, under its grade line (a relic's under its tier line), while it is wished (some type's open
    wish for the item, or a free line): "Ready to craft" in green, else what the Bag lacks for one in red ("Missing: Orc
    Ear 0/1, gold"; names only, then "Missing: Orc Ear +2" where it doesn't fit; `_smithyWishStatus`), on a short page
    too (it scrolls). No "Wishlist: Knight, Archer" line and no chip per type since decisions-log 303 (the owner,
    2026-10-09: "list trops dan whitelist disini di takeout aja untuk page detail item yang mau di craft"): a wish put on
    here is a free line, and a type's own wish for one item goes on from the Army detail (its needs rows' "+", its
    Wishlist section's picker). The
    Give row of an item ONE type's open wish is for (decisions-log 300) gives it to that type in one tap, the book staying
    on the Smithy: "Give to Knight", its line "1 in Bag. Knight 1/3" ("1 in Bag" where short; `_wishGive`, through the
    Bag's own `_useItem`), and the message window says "Sword given to Knight (2/3)", or with the Awaken it brings
    "Knight: Awaken 1!"; greyed with why while the type can't take it ("Opens at Awaken 1", `itemRefusal`) or none is in
    the Bag, a tap saying it. Two types or more: its line says who for ("1 in Bag. For Knight, Archer"; "For Knight +1"
    where short) and its tap opens the Bag's chooser on them (the filter's chips set to them; All shows the rest).
    **Kept for a craft** (decisions-log 323; the owner: "jangan sampai item requirement untuk forge ini malah ada cta
    untuk give to troops karna ini di whitelist bukan untuk troops"): a product an ingredient wish holds for its parent's
    craft, made or still to make (`partHeldFor`), with no type's open wish for it, has no Give row on its Smithy page: in
    its place, in grey, "Needed for Royal Ring" ("Needed for Gem Ring +1" for two; `Words.neededFor`, `_keptFor`,
    `_keptLine`, `_smithyKept`), no tap. Once no parent needs it (the parent made, met or taken off) the Give row is
    back. The Bag's item page does the same (below, "The action list").
    **Its free line** (decisions-log 302, 303; `_freeLine`), under the status (or the grade line, the tier line):
    the link tags "-" and "+" with how many more it asks between them in bold ink ("×2": off the Wishlist what "Add" would
    ask, 1 at first, `_SmithyView.freeMore`; on it what is still to make, `wishFreeMore`; "-" greyed at one), and at the
    right "Add to wishlist" ("Add" where short; "Sweep ×2: on the wishlist") or while on "Remove" ("Sweep: off the
    wishlist"); it scrolls with the page. The Bag's item and relic pages have the same line (below). Not on the Enhance
    tab: its stones and steps are nothing a wish asks for (decisions-log 303).
  - **The Wishlist tab** (decisions-log 300, 302, 303; the owner, 2026-10-09: "wishlist yang ada di tabs smithy itu
    seharusnya adalah tempat user untuk merealisasikan wishlistnya jadi harusnya tidak ada perubahan wishlist di situ";
    `_smithyWishes`; the rules: loot-items-relics.md "The Wishlist"): the strip's first, where wishes are made and never
    added: no Add, no picker, no count to change (wishes go on from the Army detail, the Bag's pages and the Items and
    Relics tabs' pages). Under the strip "Wishlist" (bold; `_gridHead`'s height) and after it in grey how many the rows
    still want ("34 needed", where it fits). Then a **group** per type with open wishes (the troop types' order) and last
    the free lines' **For the Bag**, each under its heading (`_wishGroupHead`, 1.8 lines tall: the type's idle sprite in
    its awakening's outline as tall and its name, bold, or "For the Bag") with the light tag **Remove** at its right: a
    tap arms it ("Sure?" on the red capsule) and a second within 3 s (`_wishArmFor`) takes the group's wishes off
    ("Knight: wishlist cleared", "For the Bag: wishlist cleared"). Under it a **row** per thing to make
    (`Wishlist.wishRows`; the owner: "1 baris per barang", "ini satu whitelist 1 row, jangan di gabung"), an inset paper
    card the page's width (`_card`), 3·ts apart (`_WishSizes`, `_wishLay`, `_wishRowDraw`):
    - **The title line:** its product's icon (`bagHeadIcon`: 16 px on a phone, 32 on the desk; its tooltip the Bag
      cell's), the name and how many are still wanted in ink ("Sword ×2"), "for Knight" in grey where it fits whole, and
      at the right a small ✕ (ui_bars.png's outline capsule with ui_icons.png's red ✕, `_icUnwish`; `_crossTag`): a tap
      takes that one wish off ("Boots: off Knight's wishlist", "Steel Sword: off the wishlist").
    - **Its parts** under it, for all still to make (`WishRow.parts`: the recipe's rows times `make`; a type's wish
      counts what the Bag holds, a free line asks for its whole count): each its 16-px icon (the gold's coin) and
      "have/need" ("11/4"; the gold what it takes, "40"), green where the Bag has enough, red where short, their tooltips
      the Bag cell's (where a material drops); as many to a line as fit (`wishFlow`). None for a type's row the Bag
      already holds.
    - **Its status** at the right of the last line (the owner: "Ready" or "Short: Orc Tooth 1"): "Ready" in green
      (`Words.ready`) while the Bag pays for all still to make; else what it is short, red ("Short: Orc Tooth 1, 40
      gold", "Short: Orc Tooth 1 +1", "Short" where shorter; `wishRowShort`); a type's row with nothing left to make,
      "In Bag: 2" in green.
    - **Its tags** (the owner: "Craft + Give di baris"), on the title line by the ✕ where the name still fits whole
      beside them, else after the status: **Craft** while some are still to make (the item page's `_craftTap`: one, the
      same message; greyed with why while refused, a tap saying it), and for a type's wish while the Bag holds one
      **Give to Knight** ("Give" where short; the item page's one-tap `_wishGive`: "Shield given to Knight (1/3)", or the
      Awaken it brings; greyed with why while the type can't take it, a tap saying it).
    - **Its parts that the Smithy makes** (decisions-log 323): a tap on one (the Royal Ring's Gem Ring) opens its page on
      the Items tab as the recipe rows' link does (`_smithyLink`, on tap up through the Bag cells' `_bagTap`, so a long
      press still shows the tooltip), its icon on the small slot's lit card (`_frameLit`) under the mouse and while
      pressed; its page's Back returns to the tab on the spread it was on. A material's part only tells.
    - **Ingredients** (decisions-log 323; the owner on its row: "sama saja seperti whitelist biasa tapi jangan sampai ada
      tulisan untuk give to trops"): last, after "For the Bag", the group **Ingredients** (`Words.ingredients`, no sprite;
      its Remove takes every ingredient wish off, `unwishParts`, the wishes they were for staying: "Ingredients: wishlist
      cleared"), a row per product an ingredient wish still wants made (`WishRow.parents`): a row as any other, its icon,
      "Gem Ring ×1" and in grey the product it is for, "for Royal Ring" ("for Gem Ring +1" for two; never a troop), its
      parts, status, Craft and ✕ ("Gem Ring: off the wishlist", `unwishPart`: it and the ingredient wishes under it; the
      wish it was for stays). No Give: no tag, no words, no troop (it has no type, and `_wishTags` gives only a type's
      row a Give). Its Craft says only "Gem Ring crafted!"; the one made stays in the Bag for the parent's craft, its row
      gone once the Bag holds what the parents still need (the row's count is read live: rules in loot-items-relics.md
      "The Wishlist", "Ingredient wishes").
    A wish met (a type's held in full, a free line's crafted) drops off the tab; the Awaken a Give brings ends the type's
    set. The rows run down the left page and on down the right one from its top: the tab has no product page (the rows
    craft and give themselves, and the parts' tooltips say where a material drops). A heading never ends a page, and a
    group going on to the next page starts it with its heading again; past one spread the Bag's pager at the left page's
    foot (the wheel over either page a notch a spread). The rows a spread with the test's 17 (three types' grade-I sets,
    a Royal Helm, two free lines; test/smithy_wish_ui_test.dart pins them), left page + right page:
    | Screen | Rows a spread | Spreads |
    |---|---|---|
    | 1600×947 | 4 + 6, then 3 + 6 | 2 |
    | 1266×713 | 4 + 6, then 3 + 6 | 2 |
    | 1164×777 | 3 + 5, 3 + 6, then 2 | 3 |
    | 915×412 | 1 + 3 a spread, the last 1 + 2 | 5 |
    None wished: "No wishes yet." and "Add wishes from the Army page, the Bag or the Items tab." in grey (wrapped;
    `Words.noWishes`, `Words.addWishesFrom`). Until decisions-log 303 the tab had cards of cells per type and per free
    line, Add with its picker (sets, items, relics), a sprite's double tap and the right page a picked product's; the
    owner: "jadi ketika orang buka tab wishlist itu dia bisa liat apa saja yang mau dia buat, terus materialnya berapa,
    apakah component untuk materialnya sudah ada semua atau tidak".
  - **Relics:** the page above, every small relic in play (20 with the forge), paged where it must (below).
  - **Enhance** (decisions-log 255; the rules: loot-items-relics.md "The forge: Enhance"; forge-design §12, mockup 12):
    the board (`smithyEnhanceLoot`, on `_SmithyView.enhanceBoard`) is the two stones first, Mithril and Starmetal, what
    this tab makes, marked as the relics are (the ▲ while `canCraftStone`, the count from 1, the icon at 40% while it
    can't be made), then the items the Bag holds by grade, III first, in the Bag's order within a grade: each at +0
    while some is held, then each enhanced stack its own cell (the Bag's stack look above: the tint and the "+3" tag);
    an item's cell is the Bag's (its count from 2), without the Awaken ▲. The pick (`_SmithyView.enhancePick`, a stone
    or an item at its plus) is the one tapped, at first the first item that can go a step up now, else the first item,
    else Mithril; its next step's stone is on the lit card on the board. A stone's facing page is
    a relic's: its heading, "One for each Enhance step to +1, +2 or +3." (from `enhance.stone`), in grey "Made at the
    Smithy: no monster drops it.", its Recipe (`stoneCraftRows`; Starmetal's Mithril row says "Smithy" where a
    material's monster goes), Craft (`craftStone`, "Mithril crafted!"), the "No limit" line; no Equip row. An item's
    (`_enhanceLines`): its heading with the tinted icon and "+3" in the level's ink, what one does at its plus and, from
    +1, at +0 ("+41.6% attack for one troop type (+32% at +0)."), in grey "Grade III, enhanced 3 times. Each + adds 10%
    of its bonus, up to +5. It always works.", **Recipe** with "to +4" smaller and grey after it, the step's rows
    (`enhanceRows`: its stone, then the gold), the page's one bevelled button **Enhance** (`_enhanceButton`: the green
    "Enhance to +4 (2,500 gold)", "Enhance to +4 (2500)", "Enhance to +4" where shorter; else the white one with why,
    "Need 1 Starmetal", "Not enough gold"), in grey what one does a step up ("+44.8% attack at +4"), then the light row
    **Give to a type** (`_giveTypeRow`, the Give row's look): its line the first fielded type where it would take the
    place of a lower one at the cap ("Knight: in place of its +0", `swapOut`), else "1 in Bag. Opens the Bag"; a tap
    turns the book to the Bag with that stack picked and its types listed. A press on Enhance takes one up
    (`Enhance.enhance`; it always works), the page follows it to its new stack and the message window says "Royal Sword
    enhanced to +4!"; on the white one it says why again. At +5 there is no Recipe and no grey line: the white "Max: +5".
    The page scrolls as the others do.
  - **A short page:** a board the Bag's slot would page is drawn at the small slot (`_BagGrid.shrunk`; 22×22 below the
    desk's scale, the 16-px art; from k 2 the two are the same); where that is still too tall (the shorter landscape
    book, decisions-log 283), the Relics and the Enhance boards page as the Items board does: one untitled section
    (`_sectionsLay`: no heading, no empty slot) laid in the page's room under the strip, the board as tall as its tallest
    page with the Bag's pager under it (`_SmithyView.board`'s or `enhanceBoard`'s; the wheel over it a notch a page), the
    pick's page shown when it is picked (the tab tapped, the Shop's or a material's way in), after that the player's.
    Its counts tight and tucked to the slot's corner, and its ▲ likewise to the top right corner, a px out into the gap
    (the arrow's 10×10 over the icon's corner only). Each board takes the whole page under the strip since decisions-log
    302 (the owner: "materials di takeout dari semua tabs jadi list itemnya bisa lebih banyak"); before, the materials
    kept two rows of their small slot and their pager under it (one where that gave a paged board a second row,
    decisions-log 286). The rows a page and the pages (test/forge_smithy_ui_test.dart pins them):
    | Screen | Items: every grade's 42 | Relics: the 20 | Until decisions-log 302 (Items; Relics) |
    |---|---|---|---|
    | 1600×947 | 50 px, 6 columns, 4 rows a page, 3 pages | 50 px, 6 columns, 4 rows: all 20 on one page | 2 rows, 6 pages; 2 rows, 2 pages |
    | 1266×713 | 44 px, 6 columns, 4 rows a page, 3 pages | 44 px, 6 columns, 4 rows: one page | 2 rows, 6 pages; 2 rows, 2 pages |
    | 1164×777 | 44 px, 6 columns, 4 rows a page, 3 pages | 44 px, 6 columns, 4 rows: one page | 2 rows, 5 pages; 2 rows, 2 pages |
    | 915×412 | 22 px (small), 7 columns, 3 rows a page, 2 pages | 22 px (small), 7 columns, 3 rows: one page | 1 row, 6 pages; 3 rows, 1 page |
    The 42 items still can't all stand on a page: their nine rows and three headings are taller than the page under the
    strip. The Enhance tab's board takes the whole page the same way. The facing page scrolls on every landscape size on
    the Items tab (the Wishlist's status and its free line), and on the Relics tab from 1266×713 down.
- **Fit:** test/town_smithy_ui_test.dart at 1266×713, 1164×777 and 915×412, on the Relics tab: the board (walked by
  its pages) on the left page with no materials under it, the rows, Craft, the grey line and the Equip row on the
  right, each reached by the page's scroll. Test/forge_smithy_ui_test.dart at 1266×713, 1164×777, 915×412 and 1600×947:
  the strip (Wishlist first, the Smithy on it), no grade strip, every grade's 42 over the board's pages in `Item` order,
  each under its grade's heading (its words at the leftmost slot), the pager on the page, no materials and no Wishlist on
  the Items tab, the item's page and the Relics tab's 20 inside the book, the rows a page and the pages of the Items and
  Relics boards at each size (the table above), and the left page still over a whole bob on the Wishlist, Items and
  Relics tabs; the Items board's pager and wheel turning its pages, the pick kept; test/forge_enhance_ui_test.dart the
  Enhance tab at 1266×713, 1164×777 and 915×412: its board and a stack's page inside the book.
  test/smithy_wish_ui_test.dart: the Wishlist tab at the four sizes (the Smithy opening on it; no Add, no picker, no
  count, no materials, no product page; its groups and rows in order over the spreads, each inside its page under its
  heading, its parts' have/need, its status, Craft and Give as the rules say; the rows a spread, the table above; a look
  changing nothing), a row's Craft and Give at 1266×713 and 915×412 (refused greyed with why, the met wish dropping off,
  the Awaken ending the set, a free line's craft meeting it), the ✕ and the groups' two-tap Remove (lapsing after 3 s)
  at 1600×947 and 915×412 down to the empty hint, the item page's one-tap Give, a product's page's free line (no types'
  chips; "-" ×n "+", Add, its crafts counting down on the tab, the met one dropping it, Remove) and the Bag's item and
  relic pages' free line at 1266×713 and 915×412, the Army detail's needs rows' "+" and Wishlist all, the materials'
  star in the Bag and the Shop (a free relic's too); `wishFlow` by itself. test/smithy_chain_ui_test.dart (decisions-log
  323) at 1600×947 and 915×412: a recipe row's link from an item's page and a relic's, two steps on and Back twice, a
  material's row and a board pick (no Back); a Wishlist row's part's link and Back to the tab; the "Ingredients" rows
  ("for Royal Ring", parts, Craft, ✕; no Give tag nor words nor troop), "Needed for Royal Ring" on a kept product's page,
  an ingredient row's Craft, ✕ and the group's Remove leaving the parents.
- **For tests:** `Board.smithyPick`, `smithyCells` (the board in order), `smithyMarks(relic)` (`BagMarks`: `count`,
  `ready`, `faded`, `lit`), `smithyAt(key)` and `smithyText(key)` ('recipe', 'craft', 'noLimit', 'equip';
  'effect', 'tier'), `smithyRows` (`SmithyRow`: the kind, where, "have / need", short, the monster and the warning as
  drawn); while the Smithy shows, the Bag's grid getters (`bagCells`, `bagSlots`) find none (decisions-log 302), and
  `bagDetailText('name' | 'count' | 'title:equip' | 'hint:equip')`, `bagAction`.
  With the forge: `smithyTab`, `smithyItem`, `smithyItemCells` (the Items board's page shown), `smithyItemMarks(item)`,
  `smithyItemPage`, `smithyItemPages`, `smithyItemPager('back' | 'on')` (Rect.zero: one page), `smithySmallBoard`; the
  Wishlist's `smithyAt('wishMissing')` and `smithyText('wishMissing')` (a product's page's status), a cell's `wished`
  in `smithyItemMarks`, `smithyMarks` and `bagMarks`; the Wishlist tab's `smithyWishCells` (each row shown: its group,
  a type or "free"; its kind; its card), `smithyWishPage`, `smithyWishPages` (spreads), `smithyWishPager('back' |
  'on')`, `smithyAt('wishHead' | 'wishType:<group>' | 'wishOffAll:<group>' | 'wishRow:<key>' | 'wishOff:<key>' |
  'wishCraft:<key>' | 'wishGive:<key>')` and `smithyText('wishLines' | 'wishNeeded' | 'wishEmpty' | 'wishPage' |
  'wishPer' | 'wishType:<group>' | 'wishOffAll:<group>' | 'wishTitle:<key>' | 'wishParts:<key>' | 'wishStatus:<key>' |
  'wishCraft:<key>' | 'wishGive:<key>' | 'wishGiveWhy:<key>')` (a row's key its group and product, "knight:sword",
  "free:fang"; 'wishLines': every row, "knight:sword ×2|free:fang ×2"; 'wishPage': the spread's rows; 'wishPer': the
  rows each spread's pages hold, "4+6,3+6"; 'wishParts': "boneShard 6/4,orcTooth 4/4,gold 40"; 'wishCraft': why it is
  greyed, '' while it works; an ingredient row's group "parts", "parts:gemRing", and each row's part
  `smithyAt('wishPart:<key>:<part>')`, decisions-log 323); the links' `smithyAt('back')` and `smithyTrail` (the steps
  back), a kept product's `smithyAt('kept')` and `smithyText('kept')` ("Needed for Royal Ring"); a product's page's or a
  Bag page's free line `smithyAt('freeLess' | 'freeMore' |
  'freeAdd')`, `bagDetail(…)` and `smithyText('free' | 'freeAdd')`, `bagDetailText(…)` ("off ×1", "on ×2"); `set
  smithyTab` (a test's start on a tab);
  `smithyAt('tab:wishlist' | 'tab:items' | 'tab:relics' | 'tab:enhance' | 'grade:1' … | 'give')` ('grade:2': where Grade II's heading's
  words are on the page shown; Rect.zero: not on it), `smithyText('tabs' | 'grades' | 'locked')` ('grades': the headings
  on the page shown, "Grade I|Grade II"; 'locked': 'enhance' while greyed, '' once open); the Give row's
  `bagDetailText('title:giveTroops' | 'hint:giveTroops')`. The Enhance tab's: `smithyEnhancePick` (a `BagLoot`), `smithyEnhanceCells`,
  `smithyEnhanceMarks(kind, plus)`, `smithyAt('enhance' | 'next' | 'give')`, `smithyText('recipe' | 'enhance' | 'next' |
  'give')`.

### The Tavern (`lib/tavern_page.dart`, decisions-log 267)

The Town book's Tavern tab sells the boosts (the rules: loot-items-relics.md "Towns: the Tavern"; the owner, 2026-10-07:
"UI tavern di gabung saja di dalam book ui juga"), drawn from the book's own pieces (the page frames recoloured by
rarity as the Boss Chest's cards, the Bag's slots and capsules, the light tags, the one bevelled button and existing
icons; nothing new drawn). In every Town (since decisions-log 268; the Tavern-off build is gone, decisions-log 296).

- **The tab:** after the Smithy's, the wave meter's beer mug (`town_mug.png`, its 32-px file of the 16-px art). While
  the visit's offers haven't shown on the page (a new Town, a game loaded) it carries the red dot (`_tabDot`, the Bag's
  and the Army's; `storeAt('tavernDot')`); the page shown, it goes. The Tavern's sign and building open the page (the
  pan's place stays the Tavern); outside a Town, or in a game without the Tavern, the page shuts as the Smithy's does.
- **The left page:** "Tavern", then "Offers" (bold) and at the right in grey "New offers every Town" ("New every Town",
  none where shorter). The offers as **inset paper-card rows** the page's width, one per slot in its order (list rows
  look like slots, never like buttons: the owner's rule), max(32, `bagHeadIcon`) for the icon plus 7·ts over and under
  it: the page frame (`Board._framePlain`) recoloured by the offer's rarity with the Boss Chest's paints
  (`_rarityFramePaints`; a Common keeps the plain frame), the pick and the row under the mouse on the lit frame
  (`_frameLit`, the same recolour). In a row: the boost's icon, its name (bold, 15·ts), under it its rarity word in its
  ink (`_rarityInk`; a Common's grey) and in grey " · 2 waves · All troops" (" · Knights" for the Champion's Plate;
  " · All troops", nothing where shorter; a boost that touches no troop, the Lucky Toast, only its waves); on the right the coin and the price ("1,550"; red, B0302A, while the gold is short), or once bought "Sold"
  in grey with the icon faded (`_ghost`) and its words grey. A tap picks it (the facing page follows). Under them **Reroll**, a light tag
  (`_tag`, `_TagLook.go`; `.off` while the gold is short or every offer is sold, its press saying why: "Not enough gold",
  "Sold out") with the price in it ("Reroll 150"), and at the right in grey "Bought ones stay". Then "Active" (bold) with
  "waves left" (grey), and the boosts running as **Bag slots** (`bagCellSize`) in their rarity's colours (`_bagSlot` +
  `_bagRarityPaints`; a Common's the plain slot), the page's width a row, the icon in it and the waves left in the
  count's capsule (`_capsule`, bottom right), in as many rows as they take (`_tavernActiveCols`); a lone one's name and
  effect beside it ("Feast: +20% damage, 15% less damage taken"); none: "None yet." in grey. Under "Offers" all of it
  (the rows, Reroll, "Active" and its slots) scrolls where it doesn't fit (`_TavernView.list`, lib/page_scroll.dart:
  "A page's scroll" under "The book"; decisions-log 283, the landscape book shorter): the wheel or a drag over it, the
  Bag's capsule scroll bar down its right, the rows then clear of it; a new visit's offers show its top; what takes a
  tap is cut to the view (out of it: Rect.zero for tests).
- **The icons** (existing art only; ui_icons.png's 16-px cells by their top left): the Feast the Tavern's mug, Strong
  Ale the sword (`Item.sword`, the Army page's damage icon), Hearty Stew the heart (0, 0), Iron Broth the shield
  (`Item.shield`), Spiced Tea the gloves (`Item.gloves`, attack speed), Travel Rations the backpack (160, 32), Lucky
  Toast the coin (96, 0), Mage's Brew the bolt (144, 0), the Champion's Plate its troop type's idle sprite standing in
  the box (`book_<type>_idle`, `_idleBounds`), King's Banquet the crown (64, 16).
- **The right page (the pick's, action first):** the heading as the Bag's (`_detailHeading`'s band, 42·ts): the icon
  (`bagHeadIcon`: 16 px at 915×412, 32 on the desk), the name (20·ts) and at the right the rarity word in its ink (bold);
  what it does in ink (`boostDoes`: "Every troop: +20% damage, 15% less damage taken.", "Knights: +40% damage, +15%
  attack speed."); in grey "Rare boost. Lasts the next 2 waves."; "Effect" (bold) and a
  row per line of `boostEffectRows`, inset paper cards that only tell (the Smithy's recipe rows): the icon (the Army
  page's stat icons where it has one: the sword for "Damage", the shield for "Damage taken", the gloves for "Attack
  speed"; the heart for "Max HP", the bolt for "MP regen", the coin for "Kill gold"), the words and at the right the
  value in green (2E8B3A: "+20%", "-15%"), then "Troops" (the
  crossed swords: "All troops", "Knights") for a boost that touches troops, and "Waves" (ui_icons.png's sword: "2").
  Then the page's **one bevelled button, Buy** (the page's width, max(20, 32·ts) tall): green "Buy (1,550 gold)" ("Buy
  (1550)", "Buy" where shorter); else the white one with why ("Not enough gold", "Sold"; `boostRefusals`), a press
  saying it again (`Sfx.error`). A buy runs the boost at once, plays `Sfx.clear` and the message window says "Feast! 2
  waves". Under it in grey "No limit: buy any you can pay" ("No limit" where shorter; the owner: "Sebanyak gold cukup").
  While it doesn't all fit (the King's Banquet's six rows on a short page) it scrolls under the heading
  (`_TavernView.facing`, as the list; a new pick shows its top): nothing is left out (until decisions-log 283 the rows'
  icons went to 16 px, then the "No limit" line, then the rows drew closer and the lines above them fewer). The rows'
  icons are `bagHeadIcon`'s (32 px on the desk, 16 at 915×412); what it does wraps in up to 3 lines,
  the grey line in 2.
- **The reveal** (the gacha's moment, tavern-design §5): an offer not shown before in its slot (the visit's first look,
  a reroll's new ones) comes in one after another, 0.12 s apart, each over 0.25 s from 60% opacity and 4 px lower; an
  Epic's and a Legendary's bursts once over its icon with the field's upgrade burst (`fx_upgrade.png`, its 18 frames of
  64×64 at 15 fps, a quarter again the icon's size, clear of the name). Another visit's offers (another Town, another game) drop the pick: the
  page opens on the first offer not bought.
- **For tests:** `Board.tavernPick`, `tavernRows` (`TavernRow`: the slot, the kind, where, the price as shown, short,
  picked), `tavernEffects` (`TavernEffectRow`: where, what, how much), `tavernAt(key)` ('offers', 'reroll', 'stay',
  'active', 'none', 'active:<i>', 'icon', 'buy', 'noLimit') and `tavernText(key)` ('offers', 'reroll', 'stay', 'none',
  'active:<i>' (its waves left, then after a ':' a lone one's label), 'name', 'rarity', 'does', 'line', 'buy',
  'noLimit').

### The Town's Shop (`lib/shop_page.dart` on `lib/bag.dart`'s code; decisions-log 230 and 269)

All the Shop's buying and selling is done in a Town (the owner, 2026-10-04: "semua aktifitas shop
hanya bisa di lakukan di town, di tas di remove, dan di reuse codenya ketika di kota"). The rules: loot-items-relics.md
"The store". The field's own Shop page of a game without the Towns (the Toko) went in decisions-log 296: the book has no Shop tab
outside a Town.

- **The page** (`_shopPages`, `_ShopView`): a Town's Shop tab (open in every Town as shipped; grey before a later
  `shop.from`, a tap saying "Opens after wave <from>") shows "Shop" over the left page and under it the strip **Buy |
  Sell** (`ShopTab`; the owner, 2026-10-08: "tabnya di bagi jadi 2 untuk ui shop ada ui untuk Buy dan sell"): the Bag's
  segmented paper strip (`_chips`, the Bag's and the Smithy's look: light controls, no bevels), the tab on lit. It opens
  on Buy each time the book turns to it (`_ShopView.leave`). A tab tap puts the pick back; the sell basket stays. The
  left page holds the tab's board, the right page its facing page. The pick is `_storePick`, one for both tabs. The
  field's Bag keeps its own chips (All, Items, Relics, Materials, Artifacts).
- **Buy** (the owner: "untuk buy bisa dibuat terpisah antara item dan relic, misal item [][][] relic [][][]"; and "uinya
  shop ketika buy mirip seperti smithy materials cuma text materialsnya di sejajarkan dengan posisi box yang paling kiri
  biar paddingnya tetap sama"): a section per kind of goods the shelf has some of, top to bottom (`shopBuySections`,
  `shopBuyKinds`, `_shopBuyBoard`, on bag.dart's board in sections, `_sections` and `_sectionsLay`, which the Smithy's
  Items board shares since decisions-log 277):
  - **Items** (the seven grade-I kinds, `droppedItems`) and **Relics** (the small relics in play, `relicsInPlay`, in
    `Relic` order): none is on the forge's shelf (`onShopShelf`, decisions-log 248), so neither section shows.
    **Artifacts**: the store's Artifacts while their shelf is open (`shelfOpen`; never on the board, where they come from
    the Boss Chest), else no section. **Materials** (decisions-log 248): the materials that have dropped, in the order
    they first did (`Game.matsSeen`).
  - Each section is a small heading (bold, 13·ts; `_gridHead`), then its cells as the Bag's slots (`bagCellSize`, the
    Bag's gaps) in whole rows, the last row's spare slots empty, and a 6·ts gap before the next heading. The heading's
    words start exactly at the board's leftmost slot: the board and its headings stand on one span (`_gridSpan`: as many
    columns as the width takes, centred, the left edge on a whole pixel), so the padding is the slots' at every size. The
    Smithy's "Materials" heading is the same helper ("26 kinds" ends at the rightmost slot; before decisions-log 269 its
    words stood at the page's edge, a few pixels left of the first slot).
  - A section the shelf has none of is not drawn at all: no heading, no line, no gap, and the next section moves up
    (decisions-log 280; the owner, 2026-10-08, of Items and Relics saying "Made at the Smithy." over Materials: "ini di
    takeout saja kalau productnya tidak ada"). So Buy is Materials alone (the forge's shelf sells no item or small
    relic, decisions-log 248), after the store's Artifacts while their shelf is open. With nothing on the shelf at all
    (before any material has dropped, the Artifact shelf closed) the page shows one muted grey line, "Nothing to buy here yet." (`shopNothingToBuy`), at the board's
    top from its leftmost slot's edge, where a heading would start. Until then a section with none kept its heading over
    a muted line (Items and Relics "Made at the Smithy.", Materials "Materials come here once monsters drop them.").
  - **A cell** shows its buy price (`buyPrice`, `shortPrice`: "2000", "8000", "24k") in the count's dark capsule at the
    bottom right, never NEW (`BagMarks.price`). The cells are never dragged. A tap picks the kind (again: puts it back).
  - Where the sections don't all fit (915×412), the Bag's pager (`_bagPager`) and the wheel
    turn pages: a page ends between rows, never under a heading alone, and a section going on to the next page starts it
    with its heading again (`_BagGrid.pageOf`: each cell's page). The page turns to the pick. The pager stands whole
    pixels under the board's drawn top, so it keeps its place against the slots while the book bobs (decisions-log 277).
  - **The facing page:** nothing picked, the book's blank paper (decisions-log 248; the owner, 2026-10-04, of the Bag and
    the same for the Shop: "kalau belum ada item yang di pilih maka di sini cukup kosong"). A pick: the Bag's heading (its
    icon, name and how many the Bag holds) and what it is, then the Buy row (`_shopActions`):
    - **Buy** (`_buyRow`, `BagAction.buy`, on the action rows' look: `_actCard`, `_actTitle`, `_actLine`, `_rowTag`): the
      coin stack, "Buy", its light tag "Buy 2000" ("Buy 20k") and the line "2,000 gold, then 2,200" (now and the next;
      a material "65 gold, then 75", the market's 10% a buy, decisions-log 326; "65 gold each" where the next costs the
      same). A tap buys one (the heading's count, the coin
      and the gold tell it; no message). Refused (`whyNotBuy`) the tag is greyed, the line says why in red ("Not enough
      gold"; an Artifact owned, its tag "Buy" alone), and a tap says why.
- **Sell** (the owner: "untuk di sold bisa langsung di gabung aja semua yang mau di jual, mirip seperti ui dari bags",
  then "harusnya semua barang yang ada di bags bisa di jual kecuali masi di pakai sama trops, bahkan item artefak atau
  relic juga bisa di jual"): one grid as the Bag's (`_bagBoard` on `_ShopView.sell`, paged by its pager) of everything in
  the Bag that no troop or type is using, in the Bag's order (`shopSellLoot`): the items, each enhanced stack after its
  item (decisions-log 255), the small relics, the materials, and the Artifacts in the Vault. In use, and so never on it:
  an Artifact bound to a type, and an oath (always in effect); an item given to a type and a relic worn are not in the
  Bag. A cell shows its count from 2, no price; one in the sell basket shows its count to sell instead, on ui_bars.png's
  green capsule (the light tags' green, in their dark ink; `BagMarks.basket`), a Vault Artifact's at the top right
  since its stars keep the bottom right. Nothing to sell: the board's grey card
  "Nothing to sell yet." "Monsters drop materials." (decisions-log 292: no item drops). A tap on a cell puts it in the basket at 1 (when it wasn't in) and picks
  it (`_shopSellTap`): the Sell Basket's top shows it. A cell already in the basket is only picked again, its count kept
  (decisions-log 278; until then a tap on the picked cell let it go). The grid turns to the pick's page when the pick
  changes (a line tapped) and is the player's to turn after (`_ShopView.sellTurned`): with a pick always shown, following
  it every frame would hold a paged grid (915×412) on its page.
  The market's marks (decisions-log 326; loot-items-relics.md "Towns: the market"; `_shopSellArrows`): an item or small
  relic the Town wants and pays 2x or more for ("hot") shows ui_icons.png's green up arrow (16, 144), one sold so much
  its price is past half way to the floor ("flooded") the red down arrow (64, 160), at the cell's top right (an
  enhanced stack's level keeps the top left), half the cell wide, over the slot's corner (`Board.shopArrows`).
- **The Sell Basket** (the right page on Sell, a page of its own; the owner: "ini adalah page baru yang harus kamu buat.
  dimana user bisa melihat item apa saja yang sudah di masukkan ke dalam "basket sell" terus user bisa mengatur jumlah
  item yang dia jual pada selected item, dan user juga bisa liat total pendapatan dia dari hasil seluruh penjualan items";
  reworked in decisions-log 278, the owner: "page sell basket coba di rework lagi uxnya kuran nyaman. aku kepikirannya
  seperti ini <section detail item> <space> <harga> * <+ jumlah - > = <sub total harga item> <----divider---> <list item
  yang mau dijual> <total coin yand didapat> <btn sell>"; `_shopSellPage`), top to bottom:
  - **The pick's detail** (`_shopSellDetail`), a band of a fixed height (the heading's 42·ts and `shopDetailLines`, 3,
    lines), so the price row and the lines never move with the pick: the Bag's facing page heading (`_detailHeading`: the
    icon, 16 px at 915×412 and 32 on the desk, an enhanced stack's in its level's colour; the name, a stack's "+3" in its
    level's ink, an Artifact's in gold; on the right how many the Bag holds, "x12", or a Pusaka's stars), then under the
    name, beside the icon, at most 3 lines: the kind line (`_shopKindLine`: an item's grade, "Grade I
    item", grey; a small relic's tier, "Strong relic", in its tier's ink; after either the market's word, " · Hot in
    Millbrook" in green or " · Flooded: price falling" in red, `Words.hotIn`, `Words.flooded`, decisions-log 326; a Vault Artifact's rarity and where, "Rare · in
    Vault"; a material none, what drops it says what it is), a carved Artifact's "Carve +3 is lost" in red, then what it
    does (`_detailDesc`; without its closing sentence where all of it doesn't fit, the last line cut to fit). The pick
    is the cell or line last tapped (`_storePick`); while the basket has lines and none is picked (a tab switch, its line
    taken out) the last line added is. An empty basket: "Tap items on the left to sell them." in grey in its place
    (`shopTapToAdd`), and no price row.
  - **The price row** (`_shopPriceRow`) under the detail, indented to the detail's words (the owner's "<space>"): the
    coin and what one sells for (`shopSellPrice`: `sellPriceAt` at the stack's plus, else `sellPrice`; a Vault Artifact
    half its base price, its stars lost; a hot or flooded product's arrow before it), "x", the stepper as light tags, "-", the count (bold), "+", then "All" at its
    end (`_shopSetCount`: from 1 to what is held, `shopHeld`; "+" and "All" greyed there; "-" at 1 takes the line out of
    the basket), and at the row's right "= 3000", the subtotal in bold (`shopSubtotal`: an item's and a small relic's
    pieces each at their own step of the market, `marketSum`, so the subtotal is under n times the first's), ending where the lines' subtotals end. Where it
    doesn't all fit (a narrow page) the coin goes first, then the "=". The stepper reads - n + left to right (the
    owner's sketch writes "+ jumlah -"; read as the usual stepper).
  - **No divider** (decisions-log 305; the owner, 2026-10-09: "divider di sini di takeout"): the lines start under the
    price row's band as far as they end over the bar (2 gaps, max(3, 4·ts) each). Until then the book's printed line
    (ui_book.png's `_pageRule`, in its darker ink, at the book's pixel size) lay between them with 2 gaps over and
    under; its room went to the lines (14 px more at 915×412, 22 at 1600×947), and the rule's code with it.
  - **The lines** (`_shopLine`), one per stack in the basket in the order added, each one row on the Bag's inset paper
    slot (`_bagSlot` at the book's pixel scale; lit under the mouse; the pick's on the pick's orange card as its cell):
    the icon (16 px at 915×412, 32 on the desk), the name (its "+3" in its level's ink, an Artifact's in gold), "2 x 1500"
    in brown (the pieces' average for the Smithy's goods, decisions-log 326; a carved Artifact's "Carve +3 is lost" in red; "x2" where the name has no room, none where even that
    doesn't fit) and the subtotal in bold at the right. A tap on a line picks it. Where they don't all fit the wheel or a
    drag scrolls them, a capsule bar on the right; a line newly picked is brought into view. The detail, the price row
    and the bar stay put.
  - **The bottom bar** (`_shopSellBar`; the owner's "<total coin yand didapat> <btn sell>", then decisions-log 306,
    2026-10-09: "total coinnya di pindah ke button aja, dan di tabahin icon coin ... terus total di kiri di takeout"): the
    page's one bevelled button (its main standalone action, the owner's button rule) across the whole bar, as wide as the
    page's writing like the Smithy's Craft and the Tavern's Buy, max(20, 32·ts) tall. The green button reads "Sell", the
    coin (ui_icons.png's, the price row's) and the gold the whole basket brings (`shopBasketGold`, `shortPrice`), in the
    button's ink and words' size (max(10, 14·ts)), as one group in its middle: "Sell (coin) 12k"; without the coin, then
    "Sell" alone, where narrower (never at 915×412). A press sells the whole basket at once (`_shopSellAll`,
    `shopSellBasket`: each stack by `Store.sell`, an item's at its plus by `Enhance.sellAt`), empties it and says "Sold
    Sword x3: +3000 gold" (several stacks "Sold 6 pieces: +12k gold"). Greyed with the basket empty or the Shop refusing
    (the game over, outside a Town): "Sell" alone in grey, no coin and no 0, and a press says why ("Tap items on the left
    to sell them."). Until decisions-log 306 "Total" (grey), the coin and the gold stood at the bar's left and the
    button, 0.56 of the bar at its right, read "Sell (12k gold)". The page's gold is in the Shop's price words
    throughout (`shortPrice`), so 12,000 and 12k never mix on it.
  - **The basket** (`_ShopView.basket`): each stack's count, nothing sold until Sell. It is kept true to the Bag every
    frame (`shopBasketFit`: a count over what is held comes down to it, a stack held no more leaves), and it empties when
    the book turns away from the Shop, the Town is left, or another game comes in; a new Town or game also opens the
    Shop on Buy, nothing picked.
- **On the field** the Bag sells nothing (decisions-log 296): no Sell row for an item, a small relic, a material or a Vault
  Artifact, and under the rows a grey line "Sold at the Shop, in a Town." (`Words.soldInTown`, `_bagNote`) for an item,
  a small relic and a Vault Artifact (a material's own grey line says it). A buy or sell asked for outside a Town is
  refused "Only in a Town" (`StoreRefusal.town`).
- **Moved with it:** the fallen Heroes' Recall into the Army detail's Heroes section ("Army"), and the gold's red dot
  (`armyNudge`) onto the Army tab, whose detail's Next tag buys Awaken 4-5 and Forge ("Bookmarks"); in a Town too,
  where the book has the Army tab since decisions-log 301 (until then it had none, and so no dot). The Toko's pages (store_page.dart, ascend_page.dart's Awaken section, recall_page.dart)
  went in decisions-log 296.
- **Fit:** test/town_shop_ui_test.dart (the strip, Sell), test/forge_shop_ui_test.dart (Buy) and
  test/shop_tabs_ui_test.dart (the Sell Basket) at 1266×713, 1164×777 and 915×412: the strip, Buy's sections and
  headings over their leftmost slots (only those with goods: Materials alone, its heading over its leftmost slot and
  every cell's tap picking its own kind; the empty shelf's one line), the cells on the left
  page, the Buy rows, the Sell Basket's parts on the right page and the
  screen in their order (the detail, the price row under the name's words with its parts left to right, the lines as far
  under it as over Sell with no divider, Sell across the page with the coin and the total on it, no total beside it),
  a long basket scrolling under them at 915×412; the blank Buy page; the
  Smithy's heading at 1266×713 and 915×412.
- **For tests:** `Board.shopPick` / `shopPickAt`, `shopTab`, `shopTabAt(tab)`, `shopSections` (each heading and where its
  words are; only the sections drawn), `shopBasket`, `shopBasketLines` (each line, where, its "2 x 1500 = 3000"),
  `shopAt(key)` / `shopText(key)` (Buy's 'nothing': its line with nothing on the shelf; the Sell Basket's: 'detail', its 'kind', 'lost' (words only), 'desc' or 'empty'; the
  price row 'price' ("1500 x 2 = 3000"), 'unit', 'minus', 'count', 'plus', 'all', 'subtotal'; 'lines'; 'sell' (its
  words "Sell 12k", the coin between) and 'sellCoin' (the coin on it; none while greyed); the pick's heading is `bagDetail` / `bagDetailText` 'icon', 'name', 'count'); while the Shop shows, the Bag's getters read the tab's grid (`bagCells`, `bagLootCells`,
  `bagMarks(kind).price` / `.basket`, `bagPage`, `bagEmpty`) and Buy's facing page (`bagActions`, `bagDetail` /
  `bagDetailText` 'buy', 'hint:buy', 'smithy').

## Pause (`lib/pause.dart`)

The owner (#93): "butuh pause dan bisa buka tas untuk melakukan upgrade/ spawn pasukan jadi user bisa berfikir",
then "jadi popup jeda itu di remove aja di buat hover layar baru di atasnya ada tulisan "Pause" atau ketika buka tas
maka otomatis game jadi ke pause, kalau window tidak focus juga game tetap berjalan" (decision 130). The Jeda panel
(a crate with Lanjut, Pengaturan and Menu Utama) is gone.

- **State:** `Game.paused` (game.dart): `tick` does nothing, so nothing moves, fights, spawns, heals or
  counts down. Not saved; a loaded game starts unpaused. Units and bursts run on the game clock, so they
  stop with it; the field's own screen-clock animations (the materials' piles bobbing, the awakening glow and sparks) use
  `_fieldClock` (the screen clock minus the time spent paused, `_Pause.still`). The book, the troop
  counter's list and the cursor's sparks keep moving.
- **Pause and resume:** the Start/Pause toggle (its Pause in a wave, its Resume while paused; "Start/Pause toggle"
  above), Esc or P (`TdGame` is `KeyboardEvents`; key down only; `_togglePause`), and the book (below). Between waves
  the toggle is Start, so a pause there is Esc or P (or a phone going to the background); paused there, the toggle is
  Resume until the game runs again (decisions-log 220). Never on the welcome screen or after a game over. Esc first closes a
  foe skill's splash ("Foe splash" above; P closes it too, without pausing) or a new Hero's splash, then puts back the loot in hand ("Loot in hand" below), and only then pauses or resumes.
  **A tap on the field never resumes**: the player may be placing troops or giving loot.
- **The pause button is the Start/Pause toggle** (decisions-log 220; the owner: "pause dan start button jadi 1 dan
  toggle"): in a wave the light square with the pause sign (the small white dash of `ui_icons.png` twice, stood up,
  2 sprite px apart, 0.65 of the button's height), while paused the orange square with the play sign; a press pauses,
  or resumes while paused (whoever paused it). Its place, size and press area: "Start/Pause toggle" above. (Until then
  the pause button was a button of its own, in the top left row after x2: `_pauseButton`.)
- **The overlay (`_pauseOverlay`):** while paused, drawn after the field ("VICTORY!" and the cast names
  included) and before the HUD: the field dimmed (black 35%, all of it) and "Pause" (the owner's word) in the score screens' gold title (`_title`, 44·u,
  u as on the welcome screen), popping in from 0.6× over 0.12 s. `Board.pauseTitle` is where it was drawn
  (Rect.zero: not paused), for tests. Where (`_pauseTitleAt`, from last frame's HUD):
  - centred at the top of the field, 4 px under the top band (its rows, the toggle, x2, Auto, the wave
    meter and the "Chest!" chip under the toggle: the lowest of `_meterBottom`, the toggle's, Auto's and the chip's
    bottoms);
  - pushed down under the open minimap and the boss bars where they hang over the middle;
  - with the book showing, put beside the book's tabs where they would reach it (their row's rects 8 px bigger: the
    book bobs, the open tab is taller), left or right of the row, whichever keeps its middle nearer the screen's
    (decisions-log 301: at 915×412 the tabs stand 44 px apart, and right of a Town's six it would stand past 80% of the
    width; until then always right of them), and made smaller, 20 px at least, so it ends 4 px above
    the highest the book's top edge bobs (`_bookHigh`). 1266×713 keeps the full 44 px; 915×412 shrinks it.
  - The HUD is drawn over it and stays lit: the book, the buttons, the counter, the meter, the map, the boss
    bars, the log, the pinned plate.
- **Everything works while paused** (unlike the old panel, which blocked the HUD): the book opens and turns its
  pages, troops are bought (the spawn bar) and placed (they wait where they come in, and move to another cell of
  the zone between waves by a drag), items and relics are given from the Tas list and on the field, by tap and by
  drag (the drop popup shows), the tooltips, unit plates and the pinned plate show, the troop counter's list, the
  battle log and the minimap open, x2 and Auto switch. Nothing of the pause covers the field (`_covered`).
  The game's own rules still hold: the store deals between waves only (`storeMidWave`), so paused mid-wave its Buy
  and Sell stay grey ("Only between waves"), and so does taking a relic off (#91).
- **The book pauses a wave** (`_bookPauses`): a wave is on and the player opened the book by hand (the book button,
  `_bookOpened`, in the top left row), on any page, Army too.
  - Nothing else opens the book on the field: the shortcuts that turn it to the Bag (the Army detail's, its "Awaken
    from the Bag") are on its own open pages, the Smithy's links are in a Town (no wave), and the guide's pointers only
    point.
  - Between waves it pauses nothing (the book floats in after the cheer anyway). The auto start's countdown
    waits on Tas, the Shop and Settings instead ("Start/Pause toggle", Auto).
  - It is a change that acts (`_whilePaused`, each frame): when the rule turns on and the game isn't paused, the
    game pauses "by the book" (`_Pause.byBook`); when it turns off (the book shut, back on Pasukan, the wave
    started or won) it resumes, but only if the book paused it. Paused first by the player, it stays paused when
    the book shuts. Resumed by the toggle, Esc or P with the book open, the game runs with it open, and
    shutting it then changes nothing; opening it again (or turning to Tas again) pauses again.
  - Start shuts a hand-opened book, so a wave doesn't pause as it starts; so does any wave's beginning
    (the auto start's too, `Board.update`).
- **Settings** is a book tab like the others (so mid-wave the book's pause covers it). **Main Menu** (on it)
  shows the welcome screen; during a wave it first makes the pause the player's (`_menuPause`: paused, not by the
  book), so "Continue" always comes back to the game paused.
- **While paused:** the toggle is Resume, also between waves (no wave starts until the game runs and Start is
  pressed; until decisions-log 220 the start button was white then and took no press), and the auto start's
  countdown stands still; the music plays at 40% (`Sounds.duck`), at the set volume on the Settings page.
- **The window** (the desktop and the web: focus and hiding pause nothing; the owner: "kalau window tidak focus juga
  game tetap berjalan". A phone pauses, below):
  - Losing the focus (`AppLifecycleState.inactive`: another window is active, the game's still shows): frames go
    on, the game runs.
  - Hidden (`hidden`, `paused`): macOS says so when none of the app's windows shows (minimized, fully covered,
    another Space, Cmd-H; `handleDidChangeOcclusionState` in the engine's macOS FlutterEngine.mm). Flutter then
    draws no frames (`SchedulerBinding.handleAppLifecycleStateChanged` turns them off for hidden and paused), and
    Flame's loop is a Ticker on those frames, so the game would stand still. Instead `TdGame.lifecycleStateChange`
    starts a timer (`_runHidden`): 30 times a second it runs the game's `update` (no drawing), by the real time
    since its last run (the periodic timer's `tick` counts the periods gone by, a late one's too; 0.5 s at most per
    run, in steps of 0.1 s, the tick's own cap). x2, the pause and the auto start's countdown work as ever; the
    music and the sounds play on.
  - Never twice: while the timer runs, `TdGame.update` drops the frames' own updates; when frames come back
    (`inactive`, `resumed`) the timer stops and Flame's loop starts over (`pauseEngine` + `resumeEngine`), so its
    first frame doesn't count the hidden time again. Flame's own pause on hiding is off
    (`pauseWhenBackgrounded = false`). `TdGame.runsHidden` says whether the timer runs, for tests.
  - Saved on hiding: between waves, `hidden` or `paused` also saves the game (`Board._toBackground`, decisions-log
    133), since Android may end a backgrounded app without a word. Not mid-wave (a save holds no wave in progress),
    nor on the welcome screen. On a phone too.
- **A phone in the background pauses** (decisions-log 146; Android and iOS, the switch `pauseInBackgroundOnMobile`
  in main.dart, on). A backgrounded phone game that fought on would drain the battery, lose troops while the
  player is away, and let Auto start waves, until Android ends it.
  - The check: `_pausesInBackground` (main.dart) is the switch, not the web (a phone's browser says android too)
    and `defaultTargetPlatform` android or iOS. `TdGame` sets Flame's `pauseWhenBackgrounded` from it, once.
  - `hidden` or `paused`: the game pauses as the player's own pause (`_ownPause`: as by the toggle, so not
    "by the book"), mid-wave or between waves, where the auto start's countdown then waits. Flame stops its loop
    (`pauseEngine`) and no timer runs (`_runHidden` isn't called). Not on the welcome screen or after a game over,
    as any pause. Between waves it is also saved, as above.
  - Back (`inactive`, `resumed`): Flame starts its loop again, and the game stays paused under "Pause" until the
    toggle (Resume), Esc or P. A wave the book had paused stays paused too when the book shuts or turns back to
    Pasukan, as after Main Menu.
  - `inactive` alone (the notification shade, a call's banner: the game still shows) pauses nothing.
  - Off (`pauseInBackgroundOnMobile = false`), a phone works as the desktop: the timer runs the game in the
    background.
  - Tests: `flutter test` says android unless a test sets the platform (`TargetPlatformVariant`); the desktop's
    tests run as macOS (pause_test.dart, hud_test.dart).
  - App Nap: macOS can delay a hidden app's timers by seconds (playing sound usually keeps it awake, but not with
    the music muted), which would slow the game far below real time. `NSAppSleepDisabled` in
    `macos/Runner/Info.plist` keeps the app out of App Nap. (An Info.plist change needs a full rebuild.)
- **A phone in the background is silent** (decisions-log 147; Android and iOS, the switch `muteInBackgroundOnMobile`
  in main.dart, on). A phone app whose music plays on after the player has left is a bug players notice at once.
  - The check: `_mutesInBackground` is the switch and the same platform check as the pause's (`_onPhone`: not the
    web, `defaultTargetPlatform` android or iOS). Desktop and web are unchanged: a hidden window's game runs on and
    so do its music and sounds (#93, above).
  - `hidden`, `paused` (or `detached`): `TdGame.lifecycleStateChange` calls `Sounds.background(true)`, everywhere
    in the game, the welcome screen and a game over included. Every sound holds where it is: `SoLoudOutput.hold`
    pauses the loops that play (a paused voice keeps its place, and a cross-fade's fades wait with it) and sets
    SoLoud's global volume to 0, which quiets an effect still sounding; with no voice playing SoLoud stops the audio
    device after 500 ms by itself. No effect starts meanwhile (`Sounds.play` drops it), nor a loop (a cross-fade's
    new loop waits for the hold). Nothing is stopped or reloaded.
  - Back (`inactive`, `resumed`): `Sounds.background(false)`: the global volume back to 1 and the held loops go on
    where they were, though the game stays paused (above), so the music plays at 40% under "Pause" from the next
    frame. The player's volumes (Settings) were never touched: one at 0 stays silent.
  - `inactive` alone (the notification shade, a call's banner) holds nothing.
  - Off (`muteInBackgroundOnMobile = false`), a phone's sound plays on in the background (Flame's loop stopped, so
    the paused game's 40% isn't even applied until the player is back).
  - Tests: pause_test.dart puts a fake `SoundOutput` in `Sounds.output` (SoLoud's native library doesn't load in
    tests) and drives the real lifecycle messages.
- **Keys' focus:** `GameWidget(focusNode: _gameFocus)`. The name panel's text field takes the keyboard
  focus; a press on the game gives it back (`_pauseDown`, not while the name panel shows).

## Welcome screen (`lib/welcome.dart`)

- **When:** on launch, after the loading dial (and after every hot restart), and again through
  `Board.showWelcome()` (for a "Main Menu" button). While `Board.welcome` (a `Welcome`, lib/save.dart)
  is set, `Board.update` doesn't tick the game (it waits behind; idle music plays) and `render` draws
  `_welcome` (an extension on `Board`, `part of` main.dart) instead of the field.
- **Scene:** `_scenery` (the battle's backdrop: the sky and its drifting clouds, the forest band, the props line of
  trunks, trees, boulders and flowers at the horizon, the meadow; camera-and-field.md "Backdrop") fills the screen in
  both layouts (the band and field take its height), drifting at `_drift` 6 units/s; its clouds drift on the screen's
  clock too. `_squad` marches across lanes 5–7 at `_march` 14 units/s
  in the game's formation (priest | archer, wizard | lancer | knight, soldier), looping.
- **Panel:** the parchment (sprite rects below) centred at 38% of the height with a soft shadow; title
  "Path of Hero" (64, gold with a dark outline). Everything scales by `u` = min(1, w/600, h/540).
- **Buttons** (`_button`, 280×56; the panel is 402·u tall with "Continue", 312·u without):
  - "Continue" (green), only when there is a game to go back to (the save on launch; after
    `showWelcome`, the game in progress, or after a game over the save), with "Wave N" under it.
  - "New Game" (light; green when it is alone). Over a game to go back to, the first tap turns it
    into a red "Sure?" (`Words.sure`) for `Welcome.confirmTime` (3 s); a second tap starts `Game()` and deletes the
    save, like "Play again".
  - New Game on a device that hasn't seen the guide's intro opens it over the new game ("Guide" below).
  - The last row, 16·u under "New Game", split in two 224·u buttons 16·u apart, centred (a fourth button stacked
    would run off a 915×412 screen's top, where the panel already starts 3 px down): "Scoreboard" (light), the
    scoreboard (below), and "How to Play" (light), the guide's intro played over the welcome screen (its seven pages;
    closed, it is seen, so the next New Game opens none). Every card and topic is on Settings' How to Play page
    ("How to Play page" below). Their labels shrink to the button when they would not fit. Each button's key in `Board.welcomeButtons`
  (`_welcomeAt`) is an id that never changes with its words: 'Lanjutkan', 'Main Baru', 'Papan Skor', 'Cara Main'.
- **Input:** the buttons go in `_hits`, so the pixel cursor and click sparks work as in the game. A
  press that began on the welcome screen (`_welcomeTap`) stays there: its tap up and drag never reach
  the book that is drawn under it the next frame.

## Guide (`lib/guide_text.dart`, `lib/guide_rules.dart`, `lib/coach.dart`; decisions-log 172)

The owner (2026-10-02): "aku perlu ada introduction ke user pertamakali main, untuk menjelaskan semua mekanik game
ini". The first-time guide comes in four parts: its words, triggers and seen set; the renderer with the intro, the
pointers and the welcome screen's "How to Play" ("On the screen" below); Settings' "How to Play" page ("How to Play page",
under the book); and the one-time cards K0-K25 at their breaks. All four are in: the intro and the pointers show,
the page holds every page and card, and a one-time card opens at its break ("A one-time card opens" below).

### On the screen (`lib/coach.dart`, `_Coach`)

- **A card** (the intro's pages and the one-time cards): over the screen dimmed 65%, the Hero
  splash's panel (`_tipBody` of ui_tooltip.png 9-sliced at 3 or 2 px a sprite px, its shadow), the UI pack's ribbon
  (`_ribbonTitle`) with the page's title across its top, popping in over `_heraldIn` (0.35 s). Its lines (18 × the
  screen scale × 1.2, wrapped to 380·s) sit right of its picture; no timer.
  - **The intro** (I1-I7) has its counter ("3/7") over three buttons, "Skip" (closes it), "Back" (greyed on the
    first page, where a tap on it does nothing) and "Next" (green; "Play!" on the last page, which closes it).
    A one-time card says "Tap to continue" at its bottom (with "1/2" when it has more pages).
  - **Its picture**, from the game's own art (no shape drawn for it): I1 the squad (`tiny_<type>_walk.png`: Pendeta,
    Pemanah, Prajurit) facing two monsters (slime, orc) with the lives' hearts over them (two full, one half); I2 the
    gold on ui_book_marks.png's orange ribbon flag (the look of the book's old gold ribbon, decisions-log 285; the
    HUD's gold panel is drawn in code, so the picture keeps the sheet's flag) over two of the spawn bar's cards side by
    side, drawn by `_barCard` as the bar draws them, from a game of its own (gold for a Prajurit, its coin and price in
    ink; not for a Ksatria, its coin faded and its price grey; decisions-log 283); I3
    "Troop caps": the free Priest's cell at its cap ("x5/5" in red) beside the Archer's that still buys ("x0/8"), from
    a game of its own with 5 priests (`capsGame`, decisions-log 201); I4 six troops' book sprites and two more faded, over
    "+Room" with its price on the light bevel, as the spawn bar's button (decisions-log 283; the Army page header's from
    260); I5 a Ksatria
    attacking an orc, both with their field bars (`ui_bars.png`, the troop's HP over its blue MP) and the hit's burst
    (`fx_hit_knight.png`); I6 the Start button counting "Start 5" and the "Auto Wave" button lit; I7 the coins, a sword, a
    potion, ui_icons.png's big red ▶ and the Tas tab's bag. The one-time cards': K0 the sword, ▶ and three
    Prajurit; K1 three troops fallen (their death strips' last frames) over "Replace fallen"; K2 four orcs in the
    ranks' looks (`_tierPaints`, `_tierLines`: silver, gold, purple, orange) with their bars in those colours; K3 the
    healing necromancer casting at the back, its heal (`tiny_fx_heal.png`) on the orc in front, a Ksatria hitting
    it; K4 I4's room on its first page (getting ready), then the boss in its orange, two items and the chest icon; K5 three Boss Chest cards (a Rare, an Epic and a
    Legendary in the chest's recoloured frames, each icon on its glow over one star), then its three buttons (Reroll,
    Skip, Take, Take in the row's green: the chest's own `Words`; Later until decisions-log 281); K6 the
    Grail on the store's glow over three Ksatria with its ring under them; K7 a small relic, ▶, a Ksatria; K8 the
    Ksatria's item list over a plain Ksatria, ▶, the same in Bangkit 1's outline; K9 the Tas tab (the book's tan tab)
    with its red dot, ▶, a Ksatria in Bangkit 1's outline, ui_icons.png's green up arrow; K10 the Hero splash's
    portrait (this game's Hero, else the Pendeta); K11 the Shop tab, ▶, two materials (Orc Tooth, Wolf Claw), a coin (what a Town's Shop sells since the forge; an item and a relic until decisions-log 317); K12 two Legendary
    cards (Dragon Crown, Oath of One); K13 the same two rows as I3; K14 a fallen Hero faded with its crown,
    ▶, the Army tab, whose detail recalls it; K15 "36/36" (`armyMaxBoard`) over two full rows of troops; K16 the lives' hearts (full, full, empty: the
    heart a march not won costs; full, half, empty until decisions-log 329) over three monsters marching; K17 an orc drawn bigger wave by wave with red up arrows between; K18 this game's gold (short,
    "1812k") over the Army tab with its dot, ▶, a Ksatria in Bangkit 4's outline,
    the green up arrow; K19 the boss
    with three healing necromancers behind it; K20 a Pusaka, a relic and a coin, ▶, a star; K21 a Pusaka, ▶,
    another, the green plus and a star; K22 a potion and a staff, ▶, a Pusaka, the green plus (no star: Carve is never
    one); K23 the Tavern's ale mug (town_mug.png), ▶, the Smithy's hammer (`_townMark`), Sweep; K24 a Slime Gel and a
    Bat Wing, ▶, the hammer, Fang; K25's first page K5's three cards a little shorter, each with the Shadow's "?" and its
    red "!" marks under it as the popup shows them, its second three Shadow chips (Armor 2, Haste 1, Wound 3: their icons
    on the red glow, their levels, on the HUD's dark panel) as under the wave meter. Drawn in code there are only looks the game already draws so (the tabs' red
    dot, the ranks' bar fills, the Pusaka ring, the chest's and the store's glows, the Hero portrait's light). A
    picture draws as a still: nothing in it lights under the mouse or takes a press, and the rows' tooltips and chips
    it registers are dropped.
  - **Input:** a press anywhere goes to the card (`_coachDown`, first in `onTapDown`): on a button it acts, anywhere
    else it turns to the next page; Space, Enter or → go on, ← or Backspace go back, Esc (and Skip) closes it, P does
    nothing (`_coachKey`, first in `_pauseKey`: the game under it never pauses). Nothing under it reacts:
    `_coach.tapped` stops the tap up and the drag in `onTapUp` / `onDragStart`, a right click and the wheel do
    nothing, `_covered` (plates.dart) is true everywhere, and `_coachClear` empties the HUD's press and tooltip rects
    for the frame (the cursor's hand shows only on the card's buttons). On the welcome screen too.
  - **Auto** waits while a card shows (`_coach.showing` in `AutoStart.tick`'s `held:`; the owner's decision 4 a).
  - Closed (the last page, Skip, Esc), the card's key is seen and settings.json saved.
- **The intro opens** on "New Game" while the device's seen set lacks "intro" (`_introIfNew`), from the welcome
  screen's "How to Play" and from the How to Play page's "Replay guide" (whatever is seen). Watched either way, it is
  seen.
- **A one-time card opens** by itself at a break (`_coachNews`, after `_capNews` in `Board.update`): the card
  `guideNext` gives, once the board's own news is over, as the army cap's warning waits for it. That is between
  waves or in a Town (K23 there, decisions-log 237; none while a Town is due and not yet open), the won wave's "VICTORY!" over (`victoryTime`; not before this game's first win, so a save coming in shows its
  own notes first), no Hero splash showing or waiting, no foe skill splash showing (`_foeSplashBusy`, "Foe splash"
  above; it opens only mid-wave, and never while a card shows), no message up, not paused, nothing being dragged.
  - A boss chest due (`_chestHolds`: one waits, its popup open or about to) holds every card but K5 and K12
    (`GuideRule.atChest`), which open over its popup `_coachOverChest` (0.6 s) after it pops in, and only then. While
    one shows the chest under it takes no press, and its popup draws no ribbon (`_chestPopup`), so the card's is the
    one title on the screen; closed, the chest is as it was. Once it is taken or skipped (and the take's message
    closed) the break's card comes (no Later lets it come sooner since decisions-log 281).
  - One card a break (`_Coach.cardGame`, `cardWave`: none once one opened since the wave was won); the next one due
    waits for the next break. A new game (New Game, a load) has breaks of its own; the seen set stays.
  - While it shows Auto waits, so no wave starts under it; closed, its key is seen and never opens again.
- **A pointer** (P1-P5) between waves, once the intro is seen and the book is open, while no card, Hero splash or
  chest shows: the tooltip frame (`_tipFrame`, `_tipK` 2) with the cursor set's gold hand from ui_icons.png's cursor
  row (y 224, x 304; pressed at y 240) tapping every 0.4 s, its line(s) at 16 px beside it, and its tail aimed at what
  to press. It blocks nothing (no press rect) and hides while its target isn't drawn (`Rect.zero`, e.g. another page).
  - What it points at: P1 the spawn bar's first card on its page that can be bought now, else (one on another page
    can) the arrow button toward it, else the first card on the page, whose tap says why (`_p1Target`, decisions-log 283; the
    Army detail's Buy from 218 until then), P2 "Start" (`_startAt`), then
    with an item in the bag P3 the Tas tab, P4 (on the Tas page) the item's slot, P5 (an item picked) its "Give to
    troops" row, then in that chooser the first type's row that takes it (decisions-log 202).
  - Where (`_pointerAt`): above the target pointing down, else under it, right of it, left of it: the first place
    8 px (`_coachEdge`) inside the screen and clear of the target, its tail's tip 2-5 px off it as it bobs toward
    it (P1 tried right of its price first while the prices were on the rows, before decisions-log 218).
  - Each ends on its action (`_coachTick`, every frame): P1 the army grew, P2 a wave began (its number rose), P3 the
    Tas page open, P4 an item picked, P5 an item given to a type (`_useItem` → `_coachItemGiven`: P3-P5 and K0 seen,
    `itemPointersDone`). Not done in 2 breaks (`_pointerBreaks`: two waves begun), P1 and P2 are dropped as seen, and
    P3-P5 counted from their first break with an item in the bag (`dropItemPointers`; K0 then says it).
- **No seen set** (`Settings.seen` null: a widget test's board, which never runs `main()`): the guide is off, no intro
  on New Game and no pointers; "How to Play" still plays the intro, and nothing is saved.
- **For tests:** `Board.coachCard` (its key and page), `coachPanel` (with the ribbon), `coachButtons` ('skip', 'back',
  'next'), `coachPointer`, `coachPointerBox`, `coachPointerTarget`, `openGuide(key)`, `guideSeen` (get and set) and
  `welcomeButtons` (by label).
- **Shots:** test/probe_coach_shots.dart (the welcome screen with a save, I1-I7, P1, P3, P5 at 412×860, 915×412 and
  1266×713); test/probe_coach_cards_shots.dart (every page of K0-K22, K5 over its chest at a break and the chest after
  it, K12 over a chest with a Legenda, at the size its `SIZE` picks).

### Its words and triggers

- **The words** (`guideEn`, a `GuideText`, pure Dart). `guideFor()` builds it from the rules loaded
  (`loadedTownRules`): K8, K9 and "Items & Awaken" name the grades (rows below; decisions-log 249). Their words from
  before the forge went with the forge-off build and town.json's `awaken.byGrade` (decisions-log 296):
  - `intro`: 7 pages (`GuidePage`: a title, its lines) after a device's first "New Game", with the counter "3/7"
    (`counter`);
  - `pointers`: P1-P5's lines between the first waves (buy a troop, "Start", then the first item: "Bag", the item, a
    type's row);
  - `cards`: K0-K25's pages (K4, K5 and K25 two, the rest one). K4's first page says how to get ready for the boss (fill
    the room with troops, "+Room", a second Priest; decisions-log 176), its second what the boss leaves (with the forge
    on "Win it: rare materials", with it off "Win it: 2 items"; decisions-log 272);
  - `topics`: the "How to Play" page's 13 (`GuideTopic`; "Towns", decisions-log 237: K23, K24 and the wave meter's
    warning, "There, "Auto Wave" waits / until you tap "Leave town"." (decisions-log 328), "Tap the tent for "Army"."
    (decisions-log 301), and "The "Tavern" sells boosts / for
    the next 2 waves." (town.json's `tavern.waves`,
    decisions-log 268), and with the forge "A "Wishlist" marks items to make, / set in "Smithy" or "Army"."
    (decisions-log 282); by grade "Items & Awaken" adds "Awaken levels take grade I, / then II, then III. /
    The last level: two thirds.", the share town.json's `awaken.share` for the last level). Each repeats its intro
    pages and cards word for word
    (`pagesOf`), then its own lines, then the game's own item, relic or Pusaka texts read at run time (`GuideLive`);
  - `labels`: the guide's own buttons and words, "Back", "Skip", "Next", "Play!", "Tap to continue",
    "How to Play", "Replay guide", "Sure?" (`Words.back`, `skip`, `howTo` and `sure` among them).
- **Its style** (test/guide_text_test.dart):
  - Simple English with the item text's glossary ("In-game text" below: a Pusaka is "for a whole type, never lost", a
    Sumpah an "Oath", a ★ a "star" in words, since the guide's lines are plain text); the UI's names, quoted as
    on screen ("Start", "Army"; `Words` where lib/words.dart has them, so a quote and its button can't drift), and
    each is found in a string in lib/ or among the labels.
  - At most 4 lines a page (`guideMaxLines`) and 6 words a line (`guideMaxWords`; a quoted name is one word); the
    topics' own lines, any number of them, keep the 6 words.
  - Every number from its constant: no digit is written in the file outside a quoted name.
  - No aiming advice (troops pick their own monster), and every glyph is in Pixelify Sans.
  - I7's third line differs with a mouse: "Point at things to read more." for "Hold a thing to read more."
    (`GuidePage.mouse`, `linesFor(touch:)`).
- **When a card is due** (`guideRules`, a `GuideRule` per card: its key, its gate, `due(Game)`, a pure check
  rechecked at every break):

  | Card | Title | Due when | Gate |
  |---|---|---|---|
  | K0 | Items | an item waits in the bag and no type took one yet; only after P5 is seen (`after`) | 1 |
  | K1 | Troops fell | `toReplace` isn't empty ("Replace fallen") | 1 |
  | K2 | Next: a mini boss | wave 2 won (`miniBossEvery` − 1) | 2 |
  | K3 | Healer monster | wave 3 won (`necroHealerFrom` − 1) | 3 |
  | K4 | Next: the boss (2 pages) | wave 4 won (`bossEvery` − 1) | 4 |
  | K5 | Pick an Artifact (2 pages: the cards; "Reroll", "Skip", "Take") | a chest waits; over its popup | 5 |
  | K6 | Artifact | a Pusaka bound to a type (not an oath, not in the Gudang) | 5 |
  | K7 | Relic | a small relic in the bag (`relicsInPlay`: any of the 20) | 7 |
  | K8 | Item limits ("Fill its list: it can Awaken, / grade I, then II, then III.") | a fielded type at its cap for a kind in the bag (`Refusal.awakenFirst`) | 10 |
  | K9 | Awaken ("More HP, MP and a skill.", then "Its levels: grade I, II, III.") | `bagAwakens` (the Tas tab's dot) | 10 |
  | K10 | Hero | a Hero was made (alive or in `fallenHeroes`) | 10 |
  | K11 | Shop ("Every Town has a "Shop" now": "buy materials that dropped"; sell) | `storeOpen` (from `shopFrom`: the Shop open from wave 1 won as shipped) once a Town is marked (`townAt`: the break the chip comes, a wave before it; decisions-log 253) | 15 |
  | K12 | Legendary | the chest to open shows a Legendary (`Rarity.legenda`); over its popup | 20 |
  | K13 | Type full | a type at its cap (`typeFull`, decisions-log 201; never without the board's caps) | 1 |
  | K14 | Hero fell (""Army": pick its type, / then "Recall" brings it back") | `fallenHeroes` not empty and `storeOpen` | none |
  | K15 | Full army | `armySize` at `armyMax` (36; 32 until decisions-log 260) | none |
  | K16 | Too slow | `Game.stalled`: the last wave marched ("Monsters charge!"); set with `newMarch`, cleared at the next wave's start, not saved | 1 |
  | K17 | Tide | `tideRising` | 34 |
  | K18 | Spend gold ("Red dot on "Army": / a type can buy more power.") | `armyNudge` (the Army tab's dot, which it points at; the Toko's tab had it until decisions-log 296) | none |
  | K19 | Escorts | wave 49 won (`escortFrom` − 1) | 49 |
  | K20 | Sharpen (`Words.sharpen`; it quotes the button, decisions-log 187) | some Pusaka can Asah now (`whyNotAsah` null) | none |
  | K21 | Melt (`Words.melt`, likewise) | some Gudang Pusaka can melt (`whyNotLebur` null; the gold isn't asked) | none |
  | K22 | Carve (`Words.carve`; "New: spare items make an Artifact / a bit stronger. / "Bag": tap it, then "Carve". / Or pick an item: "Give".", decisions-log 196) | some Pusaka can take Carve now (`whyNotUkir` null: from wave 40, between waves, spare items) | none |
  | K23 | A Town! (""Smithy": craft items and relics. / "Tavern": buy boosts. / "Leave town" goes on.", decisions-log 237 and 272; the Tavern's line decisions-log 268) | in a Town (`inTown`); the only card there | none |
  | K24 | Materials ("Monsters drop materials. / They wait in "Bag". / In a Town, the "Smithy" / makes items and relics.") | a material held (after the first wave that drops one) | 1 |
  | K25 | Monster Shadows ("Each card hides a Shadow: / a buff for the monsters. / More "!": a stronger one. / "Take" shows what they got." and "Chips show the ones they hold. / Tap one to read them all. / A wave where many troops fall / takes the newest one away.", decisions-log 319) | the chest to open hides a Shadow (`omensOn`, from `omenFrom`); it sits over the popup | `omenFrom` 20 |

- **Which card** (`guideNext(g, seen)`): none mid-wave, while a Town is due and not yet open (`canStartWave` false), or
  before the intro is seen; else the first card not seen whose
  `after` is seen and that is due. A `passing` one (K2, K3, K4, K17, K19: its wave's notice, gone after this break)
  goes before the rest, so K1 (troops fell at wave 2) never pushes "Wave 3 has a mini boss" past wave 3; otherwise the
  list's order. With `chest` (the boss chest's popup open) only the `atChest` cards (K5, K12, K25, which sit over it), else
  only the others; in a Town only the `inTown` one (K23: the first Town's, over it, while Auto holds), elsewhere never
  it. One card a break, after the board's own news ("A one-time card opens" above).
- **The item pointers:** P3-P5 not done in two breaks are dropped (`dropItemPointers`: seen), and K0 then says it once
  an item waits; done (an item given to a type), `itemPointersDone` marks K0 seen with them.
- **The seen set** (`Settings.seen`, settings.json's `seen`: the keys "intro", "P1"-"P5", "K0"-"K25" shown on this
  device, and the foe splashes' `foe.<skill>`, "Foe splash" above). settings.json, not save.json, so "New Game"
  never clears it, and neither does "Replay guide" (it only plays the intro again: "How to Play page"). When
  settings.json has none, `main()` gives it one before the board starts (`seenFrom(savedWave())`):
  - no save.json (`savedWave()` null: none, or broken): empty, so the intro shows on the first "New Game";
  - with a save: the intro, P1-P5 and every card whose gate is at most the save's wave. The owner's wave-86 save keeps
    only K14, K15, K18, K20, K21 and K22 to see (his decision 3 a; K22 came after it); on it K15, K18, K20 and K22 are
    due.
  - A widget test's board never runs `main()`, so `seen` stays null there unless the test sets it.
- **A new card** (for a system to come): a key and its words in guide_text.dart, a rule anywhere in `guideRules`.

## The book (`_book`)

- **Sprite:** `ui_book.png`, the orange open book (240×144) from Cute Fantasy UI `Book_UI.png`.
  - 9-sliced with the sheet's own guide: x 31 / 96 / 143 / 208, y 31 / 112. The covers' edges and
    the spine stay fixed; the page middles stretch.
  - Drawn at a whole number of screen px per sprite px.
- **On the field three pages, one per tab** (`_page`: `_Page.troops` / `bag` / `settings`; `_open(page)`):
  Pasukan (the troops; titled "Army" since decisions-log 187; buying them is the spawn bar's since 283), Tas (the bag and who takes an item) and Settings
  (the field's Toko, the store titled "Shop" of a game without the Towns, went in decisions-log 296; a Town's book has
  its own tabs, `_Page.smithy` / `store` / `tavern`, "Town"); and two without a tab, Licenses (`_Page.licence`) and How to Play (`_Page.guide`), opened from
  Settings. The
  owner asked for the troops and the items apart ("ui dari troops dan item perlu dipisahkan") and chose
  "pilih item dulu".
- **A page's scroll** (`lib/page_scroll.dart`, `_PageScroll`; decisions-log 283, the landscape book shorter): a part of a
  page taller than its room scrolls in it, as the Army detail's body and the Tas list do: the Smithy's facing page
  (`_SmithyView.facing`), the Tavern's offers list and its facing page (`_TavernView.list`, `facing`). `_scrollBegin`
  holds the scroll in range (a new `of`, the pick or the visit, shows the top), clips the canvas to the view and gives
  the top to draw from; `_scrollEnd` cuts what the part added to the taps, tooltips and chooser rows to the view
  (`_cutTo`, `_inView`; out of it Rect.zero) and draws the Bag's capsule scroll bar (`_capsuleBar`) down its right while
  it scrolls, the part then drawn `_scrollBarRoom` narrower. The wheel over the view (`_pageScrollWheel`) and a drag
  that begins on it (`_pageScrollDragStart`, `_pageScrollDragBy`, `_pageScrollDragEnd`) scroll it. For tests:
  `Board.pageScrollView(part)`, `pageScrollContent(part)`, `pageScroll(part)`, `setPageScroll(part, y)` ('smithy',
  'tavernList', 'tavernFacing').
- **Army (`_Page.troops`; lib/troops_page.dart, decisions-log 187 and 218):** the troop types on the left page,
  the picked type on the right one (the owner, 2026-10-03: "untuk tas aku mau fokus di sisi kiri listnya dan detailnya
  di sisi kanan begitu juga dengan tab troops"), on a phone too (its two pages side by side). The layout since
  decisions-log 218 is the owner's of 2026-10-04: "button untuk buy dan release di taruh di detail kanan saja, dan di
  kiri di buat list troops yang bisa di panggil, dibuat menjadi 2 column jadi spritenya bisa lebih besar dan jangan
  sampai ada box in box", and "+Room" on the right "tapi harus ada pemisahnya" (in the left page's header from
  decisions-log 260, on the spawn bar since 283, which took Buy too). The words are English, from
  lib/words.dart where they are a mechanic's ("Army", "Buy", "+Room", "Replace fallen", "Release", the attributes).
  - **Title line (decisions-log 256, 260):** "Army" (22·ts bold) at the page's left edge, 12·ts in (the owner: "army di
    buat ke ujung kiri"). At the right edge, with the type caps on (decisions-log 201), the army alive against its
    cap, "24/36" (`armySize`/`armyCap`; max(10, 14·ts), red when over: "48/36";
    until then it was the roster's "3/4 types"). Left of that the oath taken (decisions-log 155): its icon
    (max(12, 18·ts)), faded while Oath of One or the Few waits (`oathWaits`), its hover the oath's tooltip
    (`_Hint.pusaka` with no type: `relicInfo` of `Game.oath`, its "Now:" line or "Waiting: keep only 2 types" /
    "Waiting: keep 24 troops or fewer").
  - **"+Room"**, the capacity buy, stood at the header's right edge from decisions-log 260 (the owner: "di tambahkan
    button di samping kanannya untuk expand quotanya", then "tombol header = beli kapasitas footer yang lama (+2,
    40+10n gold, lebarkan zona), dipindah ke header" and "dibuat pakai button yang sama jangan belang belang gini") until
    decisions-log 283 moved it to the spawn bar (the owner: "Pindah ke bar"; on its step left of the hotbar since
    decisions-log 287; `_barRoom`, where and how big:
    "Spawn bar" above). Its rules and look are as they were: the capacity buy that stood at the right of the detail's
    foot until 260, drawn by the same `_button` with the same words and ink: the light bevel (`_btnLight`) with "+Room  40" on it (`Words.room`, two spaces, `shortPrice` of
    `Game.capacityCost`), "Room: max" at the most (`Game.capacityMaxed`: one more `capacityStep` would pass
    `maxCapacity`, the board's 36 at every screen size, camera-and-field.md). A tap buys what the foot's did (`Game.buyCapacity`: `capacityStep` 2 more room for
    `capacityPrice` 40 + `capacityPriceRise` 10 per buy so far, the deploy zone a column wider until `maxZoneCols`;
    telemetry's `bought.capacity`), on tap DOWN (`_hits`) as in the foot, with the button's own press look. While it
    can't buy (`canBuyCapacity` false: short of gold, or at the most) the whole button is the footer's disabled one
    (`_btnWhite`, grey words), and a tap says why in the message window (`Game.whyNotCapacity`, since decisions-log 292
    with its numbers: "Not enough gold (need 40)." / "Army room is at its most (36)."; until then "Not enough gold." /
    "Room: max (36 troops)."); with the game over nothing. An army over its cap buys too, and the counter's red clears
    once the room takes it in. Hover or long-press: its tooltip (`_Hint.room`, `Game.roomTip`, the coin as its icon):
    "+Room" over "+Room: more army room (40 gold).", "Room 6 now, 8 after.", "The deploy zone gets 1 column wider."
    (while a buy still widens it) and "Not enough gold (need 40)." while short; at the most "+Room: more army room." and
    "Army room is at its most (36).". On a touch screen a long press on a +Room that can buy buys first (taps act on
    tap down), as Auto Buy turns on and off.
    `Board.capacityButton` is its press area on the bar; `armyTitle` and `armyCount` are the header's places for tests.
  - **The grid** (`_troopsGrid`): the nine types in `troopTypes` order, two columns of cells, from 2·ts under the
    title's band (`_underTitle`) to the page's bottom, 2 book px apart as the Bag's slots (2 on a phone, 4 on the
    desk), as tall as that allows on whole pixels inside it. The rows are counted from that unrounded top with a pixel
    kept for the rounding, so the cells keep their size while the book bobs (as the Bag's grid). Five rows hold all nine (the ninth alone in the left column). Where
    five rows would leave a cell's sprite box under `armyCellSpriteMin` (36 px) the grid shows as many rows as keep it,
    a page at a time, with the Bag's pager at the bottom (`_armyPager`: ◂ / ▸ arrow tags, `_arrowTag`, max(32, 42·ts)
    wide, "1/2" between them, max(20, 26·ts) tall; faded at the ends; a wheel notch over the grid turns a page at most
    every 0.25 s, `_armyWheel`). On the shorter landscape book (decisions-log 283) four rows a page, two pages: 188×85
    at 1600×947, 154×70 on the desk (1266×713), 140×64 on the owner's tablet (1164×777); at 915×412 two rows a page,
    81×67, three pages (153×85, 140×77 and three rows of 81×69 on two pages before it). (An upright tablet's and phone's one page, 123×108 and
    81×73, went with the portrait game, decisions-log 289.)
    The grid's page is kept across page turns of the book; the pick never changes with it. `Board.armyPage`,
    `armyPageCount`, `armyPager` (the two arrows' taps; Rect.zero on one page).
  - **A cell** (`_typeCell`, lib/troop_row.dart) is drawn from its rect alone, so the guide's pictures place cells too.
    No box in a box, no button on it (decisions-log 198's rule: light controls on a card, and no buy price or Release
    on a cell since 218). Everything at the book's pixel scale k (`ps`: 1 on a phone and at 915×412, 2 on the desk and
    the tablet).
    - The card is the Bag slot's paper card (`_bagSlot`: ui_all.png's page frame `_framePlain`, (1021, 13, 22×22), a
      1-sprite-px rim, its corners cut). Under the mouse the lit card (`_frameLit`, its rim 2 px); pressed, the lit card
      a sprite px lower with everything on it, as a Bag slot. The picked type's cell: the lit card in the Bag pick's
      cream and orange (`_bagPickPaint`), and it stays so. A type Oath of One bars (`Game.typeLocked`): the card
      recoloured a darker, greyer paper (`_rowLockedPaint`) and its sprite faded; a type at its cap keeps its card.
    - The idle sprite without its shadow (`book_<type>_idle`, made in `onLoad` by `_unshadowed`; its visible pixels,
      `_idleBounds`) standing directly on the card, no well or frame: as big as the card's inside (less 2·k) allows over
      the name's line, its feet on that line, outlined in its awakening colour.
    - Under it, one line (`armyCellBand`: max(10, 14·ts) × 1.3): the name at the left (max(10, 14·ts); cut with ".." to
      the room) and how many live at the right, small (max(10, 12·ts); `_rowCount`): "x13" in grey; with the type caps
      on against the type's cap (decisions-log 201), "x3/8" in grey, "x0/8" with none, red (`_blockedInk`) at the cap
      or over it ("x5/5", "x17/5") and while Oath of One bars the type. `Board.troopRowCount(type)` is its text and ink.
    - In the top corners, the size of the name's line: the crown at the right while a Hero of the type lives
      (`_heroMark`, its hover the Heroes), the bound Artifact's icon at the left (decisions-log 151), faded while it
      sleeps (`pusakaAsleep`: none of the type lives); its tooltip is the Artifact's (`_Hint.pusaka` → `relicInfo`).
      `Board.pusakaBadge(type)` / `pusakaBadgeAsleep(type)` are where and how it was drawn.
    - The awakening stars and the Forge are on the right page only (the header).
  - **Taps** (on tap UP, `_troopsTap`, in this order; nothing while the cells aren't drawn, e.g. under a splash or a
    card):
    1. The armed Release's confirm.
    2. Any other tap lets an armed Release go (and goes on).
    3. A button of the detail (below: Release, the tags), with the click sound.
    4. A cell: picks the type (`_ArmyPage.pick`), which the right page shows, its body back at the top; on the picked
       cell nothing. There is always a pick: for a game that comes in, the first type with a living troop, else the
       soldier, the grid turned to its page. It lasts across page turns and is not saved. `Board.troopPicked`,
       `Board.troopRow(type)` (the cell; Rect.zero on another page of the grid), `bookRows`.
    The pager's arrows and the foot's Replace fallen take their press on tap down (`_hits`).
  - x2 isn't on the book any more: it is in the top band, left of Auto and the wave meter (`Board.speedButton`,
    hud_row.dart).
  - **The right page: the picked type's detail** (`_troopDetail`, lib/troop_detail.dart): the header at the top, the
    foot at the bottom, the body between them. Words are max(10, 13·ts), a line max(13, 18·ts), a tag's line max(18,
    26·ts) tall, max(3, 5·ts) between sections. `Board.troopDetail(key)` is where a section ('heading', 'stats',
    'next', 'pusaka', 'heroes', 'relics'; cut to the body's view, Rect.zero when scrolled out of it) or a button
    ('upgrade', 'change', 'bag', 'shop'; the foot's as drawn, 'release', 'confirm', 'replace', and their press areas,
    'releaseTap', 'releaseConfirm', 'replaceTap') is this frame (Rect.zero: not shown), `troopDetailWords(key)` the
    words drawn there (a section's whether scrolled into view or not); `Board.releaseChip(type)` is the foot's Release
    while that type is the pick (else Rect.zero).
    1. **Header** (`_detailHeader`): the idle sprite standing on the paper, no frame and no dark well (the owner: "bingkai
       dan background hitam tempat sprite di takeout"), in a square at most 36% of the page wide and 20% of it tall
       ("harusnya tidak sampai setengah dari size ui booknya"), outlined in its awakening colour, the crown while a Hero
       of it lives. Beside it, one under another: the name (max(12, 20·ts) bold); how many live ("x13", "None on field"
       or "x0" where that doesn't fit; with the type caps on "x3/8", red at the cap: "x5/5"); the `maxAwaken` stars
       (`_awakeStars`, ui_icons.png: one per level reached in that level's colour, blue, crimson, gold, the rest empty
       and faint, glowing from level 3; `awakenTop` 5 once Bangkit 4 was bought, the 4th violet, the 5th white) and at
       Bangkit 5 its Forge "+n" after them (`_tempaMark`, ascend_page.dart; `_besideMark`), their hover the next
       awakening's recipe ("Awaken 4: buy on the Army page"; "Max: can't Awaken
       more", the Forge held and the next); and the
       build name ("Undying Templar", `buildNameOf`, decisions-log 149) in the Artifact's book ink (`_pusakaInk`), grey
       while it sleeps (`_buildNameLine`, pusaka_look.dart; `Board.rowBuildName(type)`), or, for a type Oath of One
       bars, why it can't join, in red (`Game.buyRefusal`).
    2. **The body**, between the header and the foot (`Board.troopDetailBody`), each section only when it has
       something to say. Where they are taller than the body (`troopDetailContent`) it scrolls (`troopDetailScroll`):
       the wheel over it, a drag on it; the Bag's capsule scroll bar down its right (`_capsuleBar`), the lines then
       clear of it; a new pick shows its top. Every line is drawn clipped to the body, and what takes a tap or a hover
       is cut to it. On the desk and the tablet a short body fits (the attributes and a few needs) and a long one (six
       needs, an Artifact, Heroes, relics) scrolls; on a phone and at 915×412 most scroll. The fit chosen for the
       small pages (decisions-log 218): the header and the foot never move, so Release and Replace fallen are always in reach,
       and the text keeps its size. Where the header would leave the body under `detailBodyMin` (60 px: the shorter
       landscape book at 915×412 under a two-line foot, decisions-log 283 and 288; with the foot one line the body
       there is 73 px under the header), the header goes into the body as its first section ('heading') and scrolls
       with it, the body then from the page's top to the foot.
       - **Attributes** (`_detailStats`): the type's 8 (`_rowStats`), two to a row as the owner drew them, each two
         lines: the icon, its short name and the value ("HP 140"; `Words.hp`, `mp`, `defence` "Def", `damage` "Dmg" (a
         healer's `heal` "Heal"), `range`, `speed`, `rate`, `regen`; max(10, 14·ts)), then under it what it means in a
         few words, grey (max(10, 11·ts); `Words.hpHelp` "Damage it can take", `mpHelp` "Fills up for skills" (a healer's
         `healerMpHelp` "Pays for heals and skills", decisions-log 297),
         `defenceHelp` "Less damage per hit", `damageHelp` "Damage per hit", `healHelp` "HP back per heal, 6 MP",
         `rangeHelp` "How far it reaches", `speedHelp` "How fast it walks", `rateHelp` "Seconds per attack" (a healer's
         "Seconds per heal"), `regenHelp` "HP back each second"; a shorter one where the column is narrow). HP (heart)
         and MP (bolt, tinted blue) only awakening raises; the others beside the icon of the item that raises them (the
         staff for the casters, `powerItem`), the item's taken/cap ("3/5", max(10, 11·ts), grey, red when no more fit:
         `!canUse`) at the cell's right where it fits. Rate never under the attack floor (`minAttackInterval`). Kinds
         outside the type's recipe are faded. Numbers from 100 up are whole, below one decimal. They are the field's
         ("Field stats" below). Hovers: `hpInfo`, `mpInfo`, the item's. `Board.troopRowStats(type)` is the eight as
         drawn.
       - **Awaken needs** (`_detailNext`): below Awaken 3, "Awaken 3 needs:", then one recipe item a row as the owner
         drew it, in columns: its icon and name, have/need ("2/3", green once enough; `awakenProgress`), and where it
         comes from today: "Done" (green) once held in full, "In Bag: 2" (green) while the Bag holds some it still needs,
         else the Smithy's line as by grade below ("Smithy: can make 3", "Smithy: needs Leather Strap"; the old recipe's
         "Drops from monsters" and "Drops, Shop 2.2k" went in decisions-log 296, the old recipe's rows in 321); its hover the item's. Then what it unlocks, "Next: Unlocks Disarm" or "Next:
         Disarm II" (`awakenSkillChange`), and while the bag holds that awakening (`bagLevel`) the green tag "Awaken 3
         from the Bag", which turns the book to the Bag with the first recipe item the type still needs picked
         (`_openBag`, main.dart), so a tap on its row there gives it: 2 taps (3 before). From Awaken 3: "Next: Awaken
         4" (at Awaken 5 "Next: Forge +5"; nothing once Forge is at its max) over the Awaken and Forge button as a tag
         (`_upgradeButton` with `tag`, ascend_page.dart): green "Awaken 4  40k" / "Forge +5  33k", or greyed with
         why, the step named first where it fits ("Awaken 4: Opens after wave 15", "Not enough gold", "Only between
         waves", "Already Forge +30 (Max)"), a tap then saying why. One tap buys, through `_ascend` / `_temper` and
         their refusals (the field's Toko had a row per type with the same button until decisions-log 296).
         - **By grade** (every game: decisions-log 249, 296 and 321;
           loot-items-relics.md "The forge: items crafted, Awaken by grade"), as the design's mockup drew it: first, for
           a level kept from a save before the grades (`Game.keptLevel`, decisions-log 272), a grey line "Awaken 3 (kept
           from old items)" (`Words.keptFromOld`; "Awaken 3 (kept)", `Words.kept`, where it doesn't fit), at every level;
           then "Awaken 2 needs (grade II):" (`gradeName`;
           "Awaken 2 needs:" where it doesn't fit) and at its right, with the Wishlist on and something left to awaken
           from items, the link tag **Wishlist all** (`Words.wishAll`, decisions-log 300): a tap puts every item the
           Awaken still lacks on the type's wishes with its count (`wishSet`; "Soldier: Awaken 1 set on the wishlist"),
           and once it is all on the tag reads **Remove set** (`Words.removeSet`), a tap taking the set off
           (`unwishSet`); `troopDetail('wishAll')`, `troopDetailWords('wishAll')`. Then a row per item of the grade set (`gradeSet`: its own icon and name,
           "Steel Sword 1/3"), and where from: "Done" (green, `Words.done`) once held in full, "In Bag: 1" (green),
           "Smithy: can make 3" (green, `Craft.canMake`: what the Bag's materials and gold pay for, in a Town or not;
           "Smithy: 3", "Smithy" where short), else "Smithy: needs Leather Strap" (grey, `Craft.whyNotMake`'s first
           line short: a material, the grade below for a Cap or a Ring, or "gold"; "Smithy: Leather Strap", "Smithy"
           where short); never "Drops". "Next" adds the grade the Awaken after it takes: "Next: Unlocks Unbroken. Awaken
           3 needs grade III." (just "Next: Unlocks Unbroken" where it doesn't fit; "Next: Awaken 2 needs grade II."
           without a skill change), none after grade III. An attribute's taken/cap counts the kind's three grades
           together (the caps of the grades open now: a knight at Awaken 1 with 3 Swords and 1 Steel Sword "4/6"), red
           when no grade of it fits. With **Wishlist all** shown, a row whose item the type still lacks and has no
           wish for carries a small "+" link tag at its right (decisions-log 303), where the row's where-from words
           still fit whole beside it (on a phone mostly not; there Wishlist all and the section below put it on): a tap
           puts that one item on the type's wishes with the set's count ("Sword ×3: on Knight's wishlist";
           `_wishOneTap`), and the "+" goes. `troopDetail('wishOne:<item>')` for tests.
       - **Wishlist** (decisions-log 282; lib/wishlist_look.dart; the rules: loot-items-relics.md "The Wishlist"):
         "Wishlist" and at its right a link tag "Add to wishlist" ("Add" where short),
         "Done" while the picker is open. Under it the type's wishes in the order put on, as the Bag's slots
         (`wishCell`: the Smithy's 22-px small slot on a phone, on the desk the same 16-px art in a 2-px slot, 28 px; 2
         sprite px apart, as many a row as fit), each with "have/need" on the type in the count capsule, tight and tucked
         (decisions-log 300; green and the icon faded once done), the green ▲ while open and the Bag pays for one
         (`canMake`, wherever the game is), its tooltip the item's over the type; none: "No items yet" in
         grey. A tap on a wish turns to the Smithy's Items tab on it in a Town (`_openSmithyItem`; the Town's book has
         the Army tab since decisions-log 301) and outside one says "Craft at the Smithy in a Town" over "Steel Sword: Ready
         to craft" or its first want ("Need 2 Wolf Claw"). The tag opens the picker under them: "Tap an item to add or
         remove it" in grey, then the type's products (`wishable`) by grade as the Smithy's sections, each grade's
         heading ("Grade II", bold) over its cells, a wished one on the pick's lit card with the gold star; a tap puts it
         on or takes it off ("Steel Sword: on Knight's wishlist"; a Royal Ring's or a Royal Helm's forged ingredients go
         on and off with it, decisions-log 323: the Smithy's "Ingredients", never this type's cells). While it is open
         each wish in the row carries the
         small red ✕ (ui_icons.png (180, 84), 7×8) in the ▲'s place, and a tap takes it off. The picker closes with
         Done, a turned page, or another type's pick (which shows its own closed). Light controls only (tags and
         cells), on tap UP as the detail's. `troopDetail('wishlist' | 'wishEdit' | 'wish:<item>' | 'pick:<item>')`,
         `troopDetailWords('wishlist' | 'wishEdit' | 'wishPicker' | 'wishReady')` for tests.
       - **Artifact:** its capsule (icon and "★2", faded while it sleeps; its hover the Artifact's tooltip), its name in
         its ink and **Change**, which turns the book to the Bag with it picked (its rows there move it or send it to
         the Vault); under them what it does (`pusakaGist`, " (asleep)" after it while it sleeps). Without one, while
         some Artifact is owned: "No Artifact" and **Bag**, which opens the Bag on its Artifacts chip. Nothing while
         none is owned.
       - **Heroes:** the crown and "Hero: Kael" ("Heroes: Kael, Mira"; on a wide page one Hero alone with its skill,
         "Hero: Kael - Shield Wall"), its hover the Heroes' tooltip. The type's fallen Heroes are recalled here (decisions-log 230: the Shop is a
         Town's; the Toko's Fallen Heroes side, a game without the Towns', went in decisions-log 296), between any waves,
         in a Town or not (`_recallLines`): a line per fallen Hero of the type, the last to fall first, at most 2
         (`recallShown`) and then "+1 more" in grey; each the crown faded, "Fallen: Aldric" and on the right the green
         tag "Recall 57k" (with the army or the type full the troop it sends home, decisions-log 167 and 201: "Recall
         57k, swap 1 Knight" where it fits whole). It always says Recall (decisions-log 237): the first that fits of the
         swap's words, "Recall 6000", "Recall 6k" (`kPrice`), "Recall"; the swap's refund and who goes home are the
         hover's (`recallInfo`: "<type> goes home (+<gold> gold)"). One tap (`recallHero`; the Hero's splash). Refused
         (`whyNotRecall`: before wave 15, mid-wave, the gold, no troop to swap) it is greyed with why and a tap says
         it; the line's hover the Hero's tooltip (`recallInfo`). `troopDetail('recall:<i>')` (i: its index in
         `fallenHeroes`) and `troopDetailWords('recall')` for tests.
       - **Relics:** "Relics:" and each small relic its living troops wear, icon and "x3", in `Relic` order; "Relics:
         none"; nothing while none of it lives. Each icon has the relic's tooltip (`_Hint.relic`: its
         tier and "Best on", decisions-log 227), without the Bag's "Tap, then pick a troop" (`tapLine`; nothing to tap
         here, decisions-log 237).
       Inside the body the buttons are **tags** (`_tag`, `_TagLook`; decisions-log 198, the owner: not every button a
       ui_buttons button, least of all on top of a section): the words on one of ui_bars.png's capsules (`capsuleSize`
       at the words' size: 13 px tall on a phone, 18 on the desk), at the right of their line; a shortcut to another
       page (Change, Bag, Shop) on the outline capsule (98, 33) in the book's ink, the dark one (82, 33) with cream
       under the mouse; a step (the next Awaken or Forge, "Awaken 3 from the Bag") on the green one (2, 65), lighter
       under the mouse, greyed when refused. Pressed, a tag sits a capsule px lower. A tag's tap is its line's whole
       height, from 3 px left of it to the line's right.
    3. **The foot** (`_detailFoot`, decisions-log 288; the owner, 2026-10-09: "tidak perlu ada divider dan button
       relasenya di buat jangan full width containernya tapi cukup sepanjang contentnya saja di kanan bawah"): one line
       on the page's bottom edge, no divider over it, its ui_buttons buttons max(24, 30·ts) tall, each as wide as its
       words (max(10, 13·ts)) with the button's own margins, its 4-sprite-px bevel and 6 px a side at its frame scale
       k = ⌊height / 16⌋ (1 to 3; `_footW`, the spawn bar's +Room and Auto rule). Each line is `detailTapMin` (44 px)
       tall at the least, its buttons on its bottom: a button's press area is the line's height and k wider each side
       (44 px each way at least, the tap rule's), so the body ends a gap over the top line's press area, and reaches
       the page's bottom when neither button shows. At 1600×947 the body is 276 px tall where it was 214 (62 px more:
       the old foot's 106 px, Release's row, the separator with its air and the army's row, are one 44-px line; a
       knight's "Awaken 1 needs" and two of its items come into view); 220 for 181 at 1266×713, 197 for 163 at 1164×777, and at 915×412
       the header stays over a 73-px body where it scrolled in a 111-px one.
       - At its right, while the type has troops alive with the type caps on (or its Release is armed: `_hasActions`),
         **Release** (Lepas jenis, `Game.releaseType`) at the page's bottom-right corner: the light ui_buttons button
         with "Release" (80×40 at 1600×947, 71×33 at 1266×713, 59×30 at 1164×777, 50×24 at 915×412;
         `Board.troopDetail('release')`, its press area `'releaseTap'`); greyed while it can't
         (`Game.whyNotRelease`: mid-wave, a Hero of the type lives), and a tap then says why ("A Hero can't be sent
         home", "Only between waves"). Its first tap arms it (`_Release.armed`): one red button stands in its place,
         grown leftwards from the same right edge as wide as its words (at least Release's width, the row's at the
         most, where its words need it; `'confirm'`, its press area `Board.releaseConfirm`), so a second tap on the
         same spot confirms. Its words (`_confirmWords`) are the longest that fit the row less 12·ts, as the old
         full-width row's: "Send Templar home?" over "13 go home, +12k gold" where the button is tall enough for two
         lines, else one: "Send Knight home? 1 goes home, +25 gold" (205 px wide at 1164×777, the row's 166 at
         915×412), "Send Templar home? +34.2k" where the rest doesn't fit (the w89 save's Templars at 915×412), "Sure? +12k"
         at the last ("No one goes home" for a type with none alive). A tap on it releases the type and says "Templar
         sent home: 13 troops, +12,000 gold" ("Templar sent home" when none was alive): 2 taps from the pick, 3 from another type (its cell first). Any
         other tap, a turned page, or the release becoming refused lets it go. `Board.releaseArmed`. **Buy** stood
         at its left from decisions-log 218 until 283 moved buying to the spawn bar (above, "Spawn bar").
       - At its left, between waves while the last won wave's fallen can be bought back (`Game.toReplace` not empty;
         never in a Town, decisions-log 301: no troop is bought there),
         **"Replace fallen (7)  12.5k"** (#92; the rules: units-and-combat.md "Ganti yang gugur"; `_replaceWords`):
         how many and what they cost now (`replaceCost`, `shortPrice`), on Release's line, "Replace (7)  12.5k" where
         only that fits beside it. Where neither fits beside Release, it goes on a line of
         its own over it, at the left, its words fitted to the row ("Replace (7)" at the last). While Release is
         armed it stays on the line where it can: its words, else its shorter ones, beside the confirm's longest words
         that still name the type and the gold ("Send Knight home? +25" beside "Replace fallen (1)  30" at 1600×947,
         1266×713 and 1164×777; "Send Templar home? +34.2k" beside "Replace (7)  36.9k" there on the w89 save); where
         none fit (915×412) it goes over the confirm, and the body left under the header is then under
         `detailBodyMin`, so the header scrolls with the body. A press buys them
         back (`Game.replaceFallen`); when some couldn't come back the message window says "Replaced 5 of 7 (not
         enough gold)" (the first refusal, lower case), or the refusal alone when none could. Greyed (the white
         button) when not one can be bought (`whyNotReplace`: "Not enough gold", "No room", "Army full 36/36",
         "Priests full 5/5"); a press then says why. Gone during a wave, after the game, and once everyone is back.
         (Not in the "VICTORY!" popup, as the design had it: the popup shows for `victoryTime` 2.4 s and fades, too
         short to press.) Taken on tap down (`_hits`). `Board.replaceButton` (`troopDetail('replace')`, its press area
         `'replaceTap'`) and `replaceLabel`. "+Room" (`buyCapacity`) stood at the row's right until decisions-log 260
         moved it to the left page's header, and 283 to the spawn bar (above).
       - The words' boxes as drawn, for the tests: `troopDetail('releaseWords')`, `'confirmWords'`, `'replaceWords'`.
       - Until decisions-log 288 the foot was three rows from the page's bottom up: the army's row (6% of the page's
         height, 20 to 32 px) with Replace fallen across it, kept whether it showed; the separator over it
         (ui_book.png's printed line `_pageRule`, later the Sell Basket's divider until 305, at the book's pixel size, twice the
         sections' gap above and under it; the owner, decisions-log 218: "harus ada pemisahnya"); and Release across
         the page's width over that.
  - **Field stats** (tas-fix, 2026-10-02): every "what you get" number in the book is what a
    troop of the type that isn't a Hero fights with now, `Game.fieldStats(type)` (pusaka.dart): `statsOf` (an oath's
    HP and damage in it, decisions-log 155) times `auraBoost` 1.15 while a Hero lives, its speed at most its walk cap
    (`Stats.walking`, decisions-log 311). That is the Army page's eight stats, their HP, MP and item tooltips, the Tas rows'
    previews (an item's `assignPreview`, a Pusaka's `pusakaPreview`) and the field's drop popup, so each says the
    same number as the troops' plates. The owner's wave-86 Templar: 927 HP with Dragon Heart and 580 without, on the
    Army page and in the Tas preview alike (it used to say the book's 806 / 504). No number without the aura
    (`statsOf`) is shown any more; the base shows only where a tooltip explains it: the HP cell's "HP maks 580
    (dasar 280)" is the field's number against the type's base (`troopTypes`), and while a Hero lives the HP and MP
    cells' tooltips end in "Aura Hero x1.15" (`Game.auraLine`), and an item cell's once the type took that kind in
    "With Hero aura: +15%" (`Game.itemAuraLine`, the item text's English). A
    Hero's own stats are its plate's.
    `Board.troopRowStats(type)` is the Army page's eight as drawn, `Board.tasRowStat(type)` a Tas Pusaka row's first
    change ("927", "580"), for `test/pusaka_tas_ui_test.dart`.
  - Stat colours: ink = the type's base (the aura alone doesn't count, or every stat would be green while a Hero
    lives), green = raised by what the type got (items, awakening, its Pusaka, an oath: `statsOf` against the base), red = a
    melee type whose own reach (`statsOf`, not the aura's, which ends with the Hero) is at its reach cap
    (`Stats.reachCap`: `meleeMaxRange` unless spears raised it), where a bow is refused; red too = a type whose walk is at
    its walk cap (decisions-log 311, `walkCap`: 6× its base, units-and-combat.md "The walk cap"), the number then the
    walk it gets, not its speed stat (`Board.troopStatInk(name)` is a value's ink, for tests). Nothing is dropped on an Army cell (the cells and the bag are on different pages); what an
    item would do to a type's price shows on the Tas page's list.
- **Tas, the Bag (`lib/bag.dart`, `_bagPages`; the grid: decisions-log 187):** the left page is the bag as a common
  game's inventory (the owner, 2026-10-03: "buat item grid yang sama setiap item. jika itemnya sudah terpakai semua atau
  tidak ada tidak perlu dibuatkan placeholder langsung hilang saja"). Its words are English ("In-game text" below; the
  mechanic's from `lib/words.dart`).
  - **Layout** (`_bagGrid`): "Bag" (`Words.bag`, 22·ts bold) at the top; under it (`_underTitle`), the category chips
    (`_bagChips`, max(20, 24·ts) tall): **All**, **Items**, **Relics**, **Materials** ("The Bag's
    Materials" below; "Mats", `Words.materialsShort`, where the words don't all fit) and, once the store is open (as
    shipped from wave 1 won) or any Pusaka is owned, **Artifacts**; only one on at a time, kept for the session (not saved). A light segmented control (the owner's
    button rule, decisions-log 198 "Bag chips"; no ui_buttons bevel): one paper strip across the page's writing, the
    Bag slot's card (`_framePlain`, `_bagSlot` at the book's k), cut into a segment per category with no gap between
    them, each its word on the paper in a soft brown (7A5238). The one on is lit as a picked slot (the lit card
    `_frameLit` in the pick's cream and orange, `_bagPickPaint`), its word bold in the book's ink; another lights under
    the mouse (the lit card) and sinks k while pressed; nothing lights while something is dragged. As wide as each other
    where every word fits (bold) at max(10, 13·ts) (the desk), else each its word plus max(8, 14·ts) and the room left
    shared out (the phone). A tap anywhere on a segment turns to that category (`_hits`, on tap down). Each segment's
    place (`Board.bagChip`, its tap area; `_chips`, so the Shop's and the Smithy's strips too) is on whole pixels as
    drawn (decisions-log 291): the strip's height exactly, where the book's bob once left an unrounded top a hair under
    it (19.99999999999998 for 20 at 915×412). Nothing on screen moved.
  - **The board** (`_bagSlot`; the owner, 2026-10-03, with a picture of a parchment page of empty slots: "grid
    barangnya ... jelek banget, masa gridnya pakai button. ini contoh grid item"): a slot at every place a page holds,
    empty ones too, so the page reads as a fixed grid of item slots, an inventory. Every slot the same size, square
    (`bagCellSize` at the book's pixel scale k: the phone's k 1 36×36 with the 32-px icon at (2, 2); the desk's k 2
    44×44, the 22-px slot at exactly 2×, the icon at (6, 6); from k 4 the icon 64; the Smithy's materials' small slot,
    `small: true`, 22×22 at k 1 with the 16-px art at (3, 3), "The Smithy"), 2·k apart across and down
    (`bagCellGaps`: 2 on a phone, 4 on the desk), so the slots' cut corners meet in a small diamond at each crossing,
    as in the picture. As many columns as the page's width holds (6 on the desk, 4 on a phone and at 915×412) and
    rows as its height holds, centred across, from under the title + the chips + max(4, 5.5·ts). `Board.bagSlots` lists
    them in reading order.
  - **The cells** (`_bagCell`): one per kind of the category the player owns (`bagKinds`), in the board's first slots
    in reading order; the slots past the last kind stay empty (the board itself, not placeholders: a kind with none
    left still has no cell). An item with some in the bag, a small relic with some in the bag, and every Pusaka owned
    (bound, in the Gudang, an oath's: one cell each). **A kind with none left has no cell** (no greyed "0" or "-"): the
    cells after it close up, the pages are counted again and the page shown is clamped. An unowned Pusaka has none
    either (the Shop's shelf still shows every good).
  - **Their order** (`bagKinds`, never by count, stars, binding or the Gudang, so binding, moving, unbinding, Asah and
    Ukir never move a cell): the items in `Item.values` order, the small relics in `droppedRelics` order, the Towns'
    materials in `Mat.values` order, then the Pusaka, the Legenda first, then the Epik, then
    the Langka, each in `Relic.values` order.
  - **Enhanced stacks** (decisions-log 255; loot-items-relics.md "The forge: Enhance"; forge-design §12,
    mockups 11 and 12): an item at +1 to +5 is its own cell, right after the item's +0 cell (an item held only enhanced
    has its stacks' cells alone), lowest plus first (`bagLoot`; the cells, their marks and the picks are keyed by
    `BagLoot`, `(kind, plus)`, every other kind at 0). Its icon is the item's under its level's colour,
    `ColorFilter.mode(tint, BlendMode.srcATop)` at town.json `enhance.tintAlpha` (0.45) over the art's own pixels
    (`_plusPaint`; `enhance.tints`: +1 blue 3D8BFF, +2 red E8203A, +3 gold FFC93C, +4 violet 8E44FF, +5 white F2F6FF, the
    awakenings' colours), as faded as the cell's paint (the Smithy's 40%, the ghost in hand); at the top left, where
    NEW's "!" goes (a stack is never NEW), "+3" in the counts' dark capsule, its digits in that colour
    (`_capsule(ink:)`; on a 22-px cell tight and tucked a px out as the counts are); its count from 2 as any cell's. A
    tap picks that stack (`_pickedAt`), its facing page its own: the heading "Royal Sword +3" (the plus in the level's ink
    on paper, `_awakeInk`), its count, what one does at it, and one row, **Give to troops**, whose type rows give it at
    its plus (`useItem(plus:)`; at a type's cap it takes the place of the lowest plus, which comes back to the Bag at
    its own); no Carve (it takes the +0 ones). Dragged out onto a troop, or in hand and tapped on one, it gives at its
    plus too (the drop popup's lines are its, `assignPreview(plus:)`). The Town's Shop buys a stack (its shelf has none):
    a cell of its own on the Sell tab, at its own price (`sellPriceAt`: the item's, plus its steps' gold at the Shop's
    item share and their stones' sell prices).
  - **A slot's look** (no button in the grid): the book's paper card, ui_all.png's 22-px page frame (1021, 13;
    `Board._framePlain`, the right page's row cards): the page's own paper F6CA9F inside a 1-sprite-px rim E69C69, its
    corners cut, the cut pixels BF6F4A; 9-sliced 5, on whole pixels, no seam. An item's and a small relic's cells are
    that slot with the icon in it. A Pusaka's is recoloured (`_bagRarityPaints`, `_recolour` through the card's three
    colours): the rim and the cut corners in its rarity's rim and dark (the chest cards' `_rarityFrame`: Langka
    8CC878/4E8C46, Epik B98CF0/7E50C8, Legenda F2C23C/C8821E), the paper a fifth of the way to the rim, so the rarity
    reads on a phone's 1-px rim. Under the mouse the lit card (1019, 107; `Board._frameLit`, the rows' hover: its rim 2
    px with notched corners), in the cell's colours; pressed, the lit card sunk a sprite px (k) with everything on it
    (`_look`); nothing lit while something is dragged. Picked or dragged: the lit card on a lighter paper FFE9C2 with
    the orange slot's orange rim F77622 and a dark orange B4461E at the corners (`_bagPickPaint`; a Pusaka's rarity
    gives way to it while picked, the facing page names it), never a Legenda's (gold 1-px rim on yellowed paper). Its
    icon, and its marks: at the top left NEW's "!" (ui_icons.png (192, 32)) in the counts' dark capsule, 10×16 (the bare "!" was too thin to
    read on an icon); at the top
    right an item's green ▲ (the smallest up arrow, (32, 144)) while a fielded type can awaken further from the bag and
    still takes that item toward it (`bagLevel` above `itemLevel`, the item in its recipe, short of the next level's
    count: the Tas tab's red dot, item by item); at the bottom right the count in the capsule from 2 up
    (`shortCount`: "1.2k" from 1000; max(10, 11·ts)), k in from the slot's corner, or a Pusaka's stars ("★2+3") in
    the same capsule there (a Pusaka has no count; at the top right it hid the head of the pack's diagonal weapons,
    Dawn Star's star, God's Thunder's hammer); at
    the top left, right of NEW's "!" while it shows, the type a Pusaka is bound to (its idle sprite's first frame in a
    14-px box on a phone, 18 on the desk, 2·k in from the slot's corner, in its awakening's line, faded while it
    sleeps: none of its type alive), an oath's crossed swords ((112, 16)), nothing in the Gudang (it was at the bottom
    left, where a carved Pusaka's wide "★2+3" now runs; the top left is the corner the diagonal weapons leave empty).
  - **NEW** marks a kind owned that wasn't when the player last left the Bag page (`_BagGrid.seen`: the kinds owned
    then; a kind gone is taken out of it, so one that comes back, a relic taken off a troop, is NEW again). A cell's NEW
    goes when it is picked, every one when the page is left (`_open`, the book shutting). It lives on the Board, not in
    the save: a game coming in (a load, a new game) starts with none.
  - **Pages, not scrolling**: a drag from an item's or a relic's cell carries it to the field, so the grid never
    drag-scrolls. A page holds the rows that fit above the note's strip (while it shows) and, past one page, above the
    pager: 36 on the desk (6 rows of 6), 30 with the pager or the note, 24 with both; 12 at 915×412 (3 rows of 4), 12 with the pager or the note, 8 with
    both (the shorter landscape book, decisions-log 283, took the desk's 7th and 8th rows and 915×412's 4th and 5th:
    it was 48 / 48 / 42 and 20 / 20 / 16; the book's padding, decisions-log 198, had taken the desk's 9th row and a
    phone's 9th with the pager: 54 / 48 / 42 and 36 / 36 / 32 before it). The rows are counted from the chips' unrounded bottom (the board itself starts on the whole pixel): the
    book bobs, and the rounded top's room changed by a pixel from frame to frame, so a page that fits a row to within
    half a pixel (915×412's sixth row) flickered between two sizes. The pager and the note's strip stand as far under the
    drawn top as the area's bottom is under the counted one, so they keep their place against the slots too (decisions-log
    277; before, they stood on the page's unrounded bottom and moved a pixel against the slots as the book bobbed). Today's catalog (12 Pusaka, 7 items, 4 small relics: 23 kinds at most) fits one page
    on the desk and a phone and takes two at 915×412; the planned 90-Pusaka catalog would take four on the desk. The
    pager (`_bagPager`, max(20, 26·ts) tall at the page's bottom, only past one page): ◂ and ▸ as small arrow tags
    (`_arrowTag`, the kit's link look; decisions-log 198 "Bag chips"): ui_bars.png's outline capsule, a tag's height at
    max(10, 13·ts) (`capsuleSize`) and twice as wide, with ui_icons.png's smallest white triangle in it ((132, 180) and
    (181, 180), 7×10), the dark capsule under the mouse, a sprite px lower while pressed; faded (`_ghost`) at the ends,
    where a tap does nothing. Each tag's tap is its place at the pager's end, max(32, 42·ts) wide and the pager's
    height (`bagPager`); "1/2" between them. A wheel notch over the grid turns a page (`_bagWheel`: at most one
    every 0.25 s, so a trackpad's swipe turns a few). Each category keeps its own page for the session.
  - **The held pick always has a cell in sight** (so its drop popup's cue, `bagSlot(picked)`, is never Rect.zero on
    the page): a chip, a pager tap or the wheel that would hide it puts it back first; a pick made otherwise (Lebur's
    target) turns the grid to its page, and to All when the chip hides it. A chip or a page turn also lets every armed
    button go (Sharpen, Carve, Melt's picker and its target, a held relic's Remove), as another pick does.
  - **Empty** (`_bagEmpty`, grey #9E9080, centred, max(10, 13·ts)): All with nothing owned, ui_icons.png's bag
    ((144, 32), 32 px) over "Your bag is empty." / "Monsters drop materials." / "Make items at the Smithy in a Town."
    (`Words.monstersDropMats` and `Words.makeItemsAtSmithy`, decisions-log 292: no item drops; a game without the Towns'
    "Monsters drop items." went in decisions-log 296; the long line goes on over two where it must); Items "No items yet."; Relics "No relics in
    the bag." and, with some worn, "N worn by troops."; Artifacts "No Artifacts yet." / "Boss Chests give them." and,
    while the Shop's shelf is open, "A Town's Shop sells some.". The board stands round it: the text is on the slot's art
    grown to a card (`_framePlain` at k) over as many whole rows of the board as it needs (with 4 sprite px inside),
    about a third of the way down, in place of those rows' slots, so the text never crosses a slot's rim.
  - **A tap on a cell** (on tap UP, so a drag out of it doesn't pick it) picks its kind → `_picked`, in hand ("Loot in
    hand and the drop popup" below); again puts it back; another switches. Only the kind the press went DOWN on
    (`_BagGrid.down`, read at tap down from the cells drawn): a cell that slid under the finger while it was down (a
    kind ran out, the cells closed up) is not picked. A cell only ever picks, never acts. A Pusaka picks through
    `_canHold` (owned). The pick stays after each gift while the bag holds more of it, so the next row (or troop on the
    field) can be tapped at once (#86's multi-assign); it goes when none is left (no neighbour is picked in its place:
    the grid has just moved under the finger), the page turns (`_open`) or the book shuts, and as the section below says
    (Esc, a right click, bare ground). Lebur moves it to its target. The cells register in `_slots` / `_relicSlots`
    (the tooltips, `bagSlot`, the drags, the coach's P4). A Pusaka isn't dragged out of its cell (it goes on a type, not
    on a troop); picked, a drag carries it like any loot in hand, and over a troop the drop popup says "Pusaka
    dipasang ke jenis, bukan ke satu pasukan" (`pusakaOnType`) and it stays in hand ("Loot in hand" below).
  - **The note** (`_noteStrip`, at the bottom of the left page over the pager): a save from before the Pusaka loads
    with them bound by default (loot-items-relics.md "Pusaka"). The message window says so once when the game comes in
    (`pusakaNotes`, marked shown like the limits' notes; "Message window" below; its last line "Put on for you: change
    or Undo in the Bag."), and while the suggestion stands (`pusakaSuggested`) this strip keeps it on the Bag page:
    "Suggested Artifacts are on" (shorter where it doesn't fit), **OK** (green: `dismissPusakaNote`, the suggestion
    stands) and **Undo** (`Words.undo`; `undoDefaultBinding`: every suggested one back to the Gudang, its first binding
    free again; "Suggestion undone: Artifacts to Vault"; greyed mid-wave, `whyNotUndoDefault`, and a tap says why). It
    goes once the player taps one, moves every suggested Pusaka, or starts a wave (Board.update: a wave begun keeps the
    suggestion).
  - **The facing page** (`_assignPage`; decisions-log 187 and 202: the owner, 2026-10-03, "untuk tas aku mau fokus di
    sisi kiri listnya dan detailnya di sisi kanan", then "di bagian atas di jelaskan item ini apa, beserta sedikit
    description, lalu opsi untuk item ini bisa di gunakan buat apa") says what the pick is, then what the player can do
    with it, action first, top to bottom: the heading, a few lines on what it is, then a row per action (the action
    list). A row that needs a who (a type, a troop, an Artifact) opens its **chooser** on the page; the others act from
    their own tags. Every part inside the page and apart (test/bag_detail_test.dart and test/bag_actions_test.dart at
    1266×713 and 915×412).
    - **The heading** (`_detailHeading`, the top 42·ts): its icon, 16 px on a phone and 32 on the desk (`bagHeadIcon`
      at the book's pixel scale: whole multiples of the 16- and 32-px art, so it stays crisp; no glow behind an
      artefact's), its name (max 20·ts; an artefact's, a Pusaka's in gold, `_storeGold`) and on the right the bag's
      count ("x86"; a Pusaka's stars, "★2", and its Carve steps in gold, "★2+3") in the book's capsule (`_capsule`,
      text max(10, 11·ts)).
    - **What it is** (`_detailLines`, max(10, 13·ts), a line max(14, 1.15·the text) tall): a Pusaka's where line
      (`_pusakaWhere`): its rarity in the rarity's dark ink (`_rarityFrame`; the `Words` rarities) then " · in Vault",
      or " · on Templar (13)" (" · on Wizard (asleep)" while none of its type lives); an oath's "Oath: all troops", or
      while Oath of One waits "Waiting: 5/2 types" in red (`oathWaitingRowOf`), the Few's "Waiting: 48/24 troops"; a small relic's tier line
      instead, "Strong relic" (`relicTierLine`; Basic in the page's ink, Strong a Rare's green, Mighty an Epic's violet:
      `_relicTierInk`, decisions-log 227). Then what it is, whole, word by word to
      the page's width (a bracket's words kept together; `_detailDesc`, `_descLines`, `_wrap`), never a word cut: in at
      most `bagDescLines` 3 lines on the desk and `bagDescLinesPhone` 4 on a phone (the book's pixel scale under 2, as
      the heading's icon); one that needs more drops its closing sentence (a Pusaka's "For a whole type, never lost.")
      and shows what it does whole (decisions-log 214). The action rows start under the lines, however many: an item's first effect line "for
      one troop type. Each type takes a few." (`itemEffect`: "+20% attack for one troop type. …"); a small relic's
      first effect line, who it suits (`relicBestLine`: "Best on: Knight, Templar, Lancer,
      Swordsman."), and `relicSlotsLine` ("Heals 10% of damage dealt. One relic per troop (Hero: 2)."); a Pusaka's
      first sentence at its stars and Carve (`relicEffect`, `firstSentence`: the card's lines that go on from the first,
      each starting with a small letter, a sign or a digit, joined to it: "When one dies, all troops within 2 tiles heal
      10% max HP", "With Fury: its x2 hit does x1.2 more") and `pusakaLine` ("For a whole type, never lost."); an
      oath's lines.
    - **The free line** (decisions-log 303; the owner, 2026-10-09: "penambahan wishlist itu dilakukan di tempat lain
      misalkan di page army,bags, dan smithy selain tab wishlist"): with the Wishlist on, an item's or a small relic's
      page the Smithy can craft (`canWishFree`; not a stack at a plus, not in the Shop) has the Smithy page's free line
      (`_freeLine`, max(20, 26·ts) tall, max(4, 6·ts) under the lines): "-" ×n "+" and "Add to wishlist", then
      "Remove"; the message window says when it goes on or off, and the Smithy's Wishlist tab lists it under "For the
      Bag". A material's page has none. `bagDetail('freeLess' | 'freeMore' | 'freeAdd')`, `bagDetailText('free' |
      'freeAdd')` for tests. Its "Add to wishlist" puts the product's forged ingredients on too (decisions-log 323, the
      Smithy's "Ingredients"). The Bag's pages list no recipe, so they have no ingredient to link (the Smithy's recipe
      rows and Wishlist rows do).
    - **Kept for a craft** (decisions-log 323; the orchestrator, on the owner's rule: no "Give to troops" for an item kept
      as an ingredient, the Bag's page too): an item's +0 page whose item an ingredient wish holds for its parent's craft,
      no type's open wish asking for it (`_keptFor`), has in its **Give to troops** row's place, in grey at the row's
      left, "Needed for Royal Ring" (`_keptLine`, no tap; `bagDetail('kept')`, `bagDetailText('kept')`); the rows under
      it as before (Carve's Give). Once no parent needs it, or a type's own wish asks for it, the row is back. An enhanced
      stack's page keeps its row (a recipe takes the +0 ones). Dragging the item out onto the field still gives it, as
      any drag does.
    - **The action list** (`_actionList`; `_actionsFor`, `BagAction`): max(4, 6·ts) under the lines (the free line's),
      a row per action,
      max(3, 4·ts) apart on whole pixels, the page's width; scrolled by the wheel or a drag, with the capsule bar
      (`_capsuleBar`), where they don't all fit (915×412 shows two or three; a new pick starts at the top).

      | Pick | Its rows, in order |
      |---|---|
      | An item | Give to troops, Give to an Artifact |
      | A small relic | Equip on a troop, Remove from a troop (while a troop wears one) |
      | A Pusaka in the Vault | Equip on a type, Sharpen, Carve, Melt |

      No row sells: the Bag sells nothing, the Town's Shop does ("The Town's Shop"; the Towns-off game's Sell rows went
      in decisions-log 296).
      | A bound Pusaka | Move to a type, Take it off, Sharpen, Carve |
      | An oath | Each type, Sharpen, Carve (both greyed: an oath has neither) |

      A row (`_actCard`, `_ActLook`) is the list rows' paper card (`_framePlain`), max(3, 4·ts) inset, 2·inset +
      1.3·title + 1.5·line tall: on its left the action's icon in a box the heading icon's size (`bagHeadIcon`;
      ghosted while it can't), then its title (max(11, 15·ts), grey while it can't) and under it one line (max(10,
      13·ts)) in the soft ink #8A6A4A, or why it can't in red (the shorter forms of `_shortWhy` where narrower). The
      icons are ui_icons.png's 16-px ones: the crossed swords (`_icSwords`) where it lists types or troops, the bag
      (144, 32) for Remove and Take it off, the star (48, 0) for Sharpen, the wrench (48,
      16) for Carve, the green plus (0, 48) for Melt; Give to an Artifact shows the first Pusaka the item would go into
      (the gift (128, 16) with none).
      - **A chooser's row** (`_chooserRow`: the row card, lit under the mouse and pushed in while pressed): on its right
        ui_icons.png's small green triangle "›" (`_icOpen`, (181, 196) 7×10, at round(title/10) screen px a sprite px;
        the white one `_icThen`, ghosted, while it can't). Its line says what the chooser holds (`_chooserInfo`): "3
        types can take it" ("No type can take it now"), "Carve: 4 can take it", "2 troops can wear it", "1 troop wears
        it", "Free: a whole type gets it" or "Costs 38k: a whole type gets it" (a Vault one), "Costs 38k" (a bound one),
        "What it gives each type" (an oath), "Into another Artifact: +1 star" (Melt); where narrower a shorter form ("Costs
        38k", "What each type gets", "Into another: +1 star", "+1 star"). Greyed with why: every row when
        the game is over; Give to an Artifact before Carve opens (wave 40), mid-wave, with no Pusaka that takes Carve
        ("No Artifact can take it") or none that takes this one now; Remove mid-wave (`whyNotTakeOff`); the type rows
        mid-wave (`bindMidWave` false); Melt (`whyNotLebur`). A tap opens its chooser (Melt: `_leburTap`), or says why.
      - **A tag's row** acts from the light tags on its right (`_rowTag` over the book's `_tag`, "Tags" below; the
        owner's rule: a row's buttons are light, never ui_buttons' bevels): ui_bars.png's full green capsule ((2, 65)
        12×6), the red one while armed (`_TagLook.armed`, (2, 33)), greyed by a colour filter while it can't, lighter
        under the mouse; 9-sliced, the full capsules' darker bottom row kept; text max(10, 13·ts) centred on the title's
        line; a sprite px lower while pressed. Its tap is the capsule 3 px wider to its left, from the row's top as far
        under the title's line, kept to the list, on tap UP (`_AssignList.taps`), so a tap on the row beside it does nothing. The
        title gives way where the tags need its room. The rows: **Sharpen**
        and **Carve** (below), and a bound Pusaka's **Take it off**: "To Vault" takes it off its type into the Vault at
        once, free (`_usePusaka` on its own type, "Dragon Heart to Vault"), its line "Templar loses it, free"
        (`whyNotUnbind` in red mid-wave). A greyed tag's tap says why.
    - **The chooser** (`_chooser`, `_openChooser`, `_chooserHead`, `_chooserList`), opened from its row, takes the page
      under the heading (the lines and rows give way). Its head, max(20, 26·ts) tall: on the left "‹ Back"
      (`Words.back`, max(10, 13·ts); a link tag: the book's capsule track (98, 33) with ui_icons.png's small white left
      triangle (132, 180), the dark capsule (82, 33) under the mouse), which closes it (`_chooserBack`: the action list
      again, from its top); beside it what it chooses for at the rows' title size (the row's title, cut to fit). Under it the filter's chips where it
      lists types or troops (Give to troops, Equip on a troop, the type rows), then its rows in a clipped list,
      scrolled as below:
      - Give to troops: an item's rows (below), one per type shown, the types the item is never for
        (`Refusal.notInRecipe`) after the others, greyed; a tap gives one, and the chooser stays for the next copy;
      - Give to an Artifact: the Give rows (Carve, below);
      - Equip on a troop: a relic's rows, one per living troop shown;
      - Remove from a troop: a relic's rows for the troops wearing it, each with Remove on its last line at once
        (`_relicRow(remove:)`); a tap takes it off (#91, below); with none worn any more the chooser closes;
      - Equip on a type, Move to a type, Each type: the Pusaka's type rows ("A Pusaka picked" below); a tap binds or
        moves it, or on its own type takes it to the Vault, and the chooser stays (its title now says where it goes);
      - Melt: Melt's picker (below).
      It stays while its action is still one of the pick's: another pick, or the action gone (the last Remove, a wave
      closing Melt), closes it. Opening one lets every armed tag go (`_bagLetGo`). While an item or a small relic is
      dragged out of the bag the page shows its chooser (Give to troops, Equip on a troop), so the row under the
      pointer lights as before ("Shortcut" below). The shortcuts open the Bag on their chooser (`_openBag(act:)`): the
      Army detail's "Change" on the Pusaka's types, "Awaken 3 from the Bag" on the item's Give to troops.
    - **The taps** (decisions-log 202: at most the old count and one more per action): an item on a type 3 (the cell,
      Give to troops, the row; then 1 a copy), a relic on a troop 3, a relic off from its pick 3 (from the overview's
      slot still 2), bind or move 3, To Vault 2, Give to an Artifact 3, Sharpen
      3, Carve 3, Melt 4, Back 1; the shortcuts still 2 (test/bag_grid_test.dart, test/bag_actions_test.dart).
    - **Carve** (Ukir, decisions-log 196; item-artefact-design U3 and U4; the rules: loot-items-relics.md "Ukir"): a
      Pusaka's **Carve row** (`_carveRow`) under Sharpen.
      - Its tag, "Carve", in two taps like Sharpen: the first arms it (red, "Carve -20": the items one tap takes,
        `ukirTake`), the second feeds it (`feedUkir`) and says what came of it: a new step "Grail of Immortality ★2+3: a
        bit stronger!", else its bar and the items, "Grail of Immortality: 100/135 (Potion 30)". Another pick, a chip, a
        page turn, a Sharpen tap or a wave lets it go. Taps: cell + Carve + Carve -N = 3.
      - Armed, its line says what the next step gives (`carveNext`: the first word of its effect lines that the step
        changes, now ▸ after, then the rest of the line, else up to its first comma, else none): "Next: 40% ▸ 42% HP,
        no damage for 3s" (narrower "Next: 40% ▸ 42% HP"; "Next: a bit stronger" when no number moves).
      - **The bar** (`_carveBar`), its line otherwise: its five steps as ui_bars.png's small green capsules at 1 screen
        px a sprite px, a sprite px apart (`_carvePips`, `_pipSrc`: taken full, the next filled in tenths of its bar,
        the rest the dark capsule; the art's own pips, no shape drawn), then the points on this step, "40/135". Where
        both don't fit side by side the points stand over the steps at max(10, 11·ts). Refused, why in red in their
        place, shorter where it doesn't fit (`_carveWhy`: "Between waves", "From wave 40", "Full", "More at wave 50",
        "No items"); an oath, or before wave 40, why alone with no steps. The tag is greyed then and a tap says why
        ("Carve opens at wave 40", "An Oath can't be carved", "Carve is full", "No points left: more at wave 50", "Not
        enough items", "Only between waves").
      - Its help on hover or a held finger (`_Hint.carve`, `carveInfo`): "Give spare items to this Artifact.", the
        role's kinds ("Potion and staff count 2."), "Other items count 1.", "Full bar: a bit stronger.", "180 points
        each boss, for all Artifacts.", "Points left now: 120" and, once carved, "Carve 3 of 5: not a star, a bit
        stronger." (`ukirGist`, also in the Pusaka's own tooltip, `relicInfo`).
      - **The badge:** a carved Pusaka's stars carry its steps in Carve's gold (`ukirInk`, `ukirMark`): "★2+3" on its
        Bag cell, in the heading, in its badge on the Bag's type rows and the Army detail
        (`_pusakaCapsule`), on the Shop's slot; the chest card of an owned one shows "+3" in the badge after its stars
        (the star-up keeps it) and its effect with it. `Board.carveBadges` lists them for tests.
      - **Melt** of a carved one: the armed target row says "Tap again: the higher Carve is kept" (`texts['meltArmed']`).
      - **The Give rows** (`_giveRows`, `_giveRow`; U4), an item's Give to an Artifact chooser: one row per owned
        Pusaka that takes Carve (not an oath), its role's first (they count the kind twice), each part in the Bag's
        order. A row: the Pusaka's icon, its name and "Give" (green), its badge ("★2+1"), its bar (the steps and
        "40/135"; "+5" at the last) and what one of this item counts there ("x2" or "x1"; on a narrow row, where it
        doesn't fit after the points, at the "Give" line's right end), and on the last line what a tap takes and does
        ("Uses 30: 40/135 ▸ 100/135", a step "Uses 30: +2 ▸ +3"; narrower the change alone, then "Uses 30") or why it
        can't in red. A tap gives that kind alone to that one at once (`feedUkir(relic, only: item)`), with the
        Carve's message. Taps: cell + Give to an Artifact + row = 3.
    - `Board.bagDetail(key)` (where: 'page', 'icon', 'name', 'count', 'where', 'desc', the rows 'sharpen' and 'carve',
      the tags 'carveBtn' and 'toVault', 'carveBar', 'empty') and `bagDetailText(key)` (the words: 'name', 'count',
      'where', 'desc', 'sharpen', 'carve', 'carveBar', 'next', 'meltArmed', 'empty', each row's 'title:<action>' and 'hint:<action>', the chooser's 'chooser') are for
      tests, with `bagActions` (each action row shown: what, where, whether it can now), `bagAction(act)`,
      `bagChooser`, `bagBack`, `carveArmed` and `carveWhyWords`.
  - **No Sell** (decisions-log 296): the Towns-off game's Sell rows (an item's "Sell +1000" and "Sell all", decisions-log
    169 and 202; a Vault Pusaka's "Sell +15k", 151) went with the Towns-off book; the Bag sells nothing, the Town's
    Shop's Sell side and its Sell Basket do (decisions-log 230 and 269). A bound Pusaka and an oath never sold.
  - **Nothing picked** (or none left of the pick; decisions-log 241, which amends #91's "Relics in use"): the facing page
    is the book's blank paper: no heading, count, chips, rows, hint or empty line (`_assignPage` returns at once; only
    `detail['page']` is set), at every size. Each troop's relics are in the Army detail, and a held relic comes off
    through its own cell's "Remove from a troop" or the pinned plate's Remove. "No troops." (`_detailEmpty`, grey #9E9080,
    centred, max(10, 13·ts)) stays for a chooser that lists troops when none lives or the filter hides every one.
  - **The filter:** "All" and a chip per troop type showing its sprite, each a light icon tag (`_filterTag`; the owner's
    button rule, decisions-log 198 "Bag chips"; no ui_buttons bevel): the Bag slot's paper card (`_framePlain`, at the
    right page's cards' scale, `_card`'s k), lit as a picked slot while on (the lit card in the pick's cream and orange,
    `_bagPickPaint`, "All" in bold), the lit card under the mouse, a sprite px lower while pressed; a type with none alive
    is faded for a relic. Its tap is the whole chip (`_hits`, on tap down). In one
    row where each type's chip is at least 0.9 of its height wide (the desk), else two rows of five (phones,
    915×412). Several at once: a type's chip adds it or takes it out, all nine is "All", "All" shows every type
    again (none chosen). It is **sticky** (`_AssignList.filter`): only the player changes it; another pick, a turned page,
    the book shutting and opening, a new game keep it. Not saved. A chip starts the list at the top again.
  - **A relic's rows:** one per living troop of the shown types, in the book's order and then the order they
    came in, 3 lines (4 on a narrow page, under 240 px: phones and 915×412):
    - its idle sprite (outlined in its awakening colour) with the stars under it (`_rowPortrait`, the troop
      row's look, Tempa's "+n" after them too), a Hero's crown on its top right;
    - its name, and on the right the relics it holds, in small grey relic slots in the order given: one slot, a
      Hero two (`Unit.relicSlots`; an empty slot for each free one);
    - its type's name (`troopTypeNames`) and the heart with its HP now/max;
    - a relic's stats now ▸ after in the preview blue, each after its stat's icon: none since the Pusaka (no small
      relic changes a stat, and a Pusaka is refused on one troop, `pusakaOnType`).
    - A troop that can't take it is greyed, the reason in red on the last line: "Already holds <relic>" (a
      troop's one slot taken, or a Hero holding that kind) or "Relic slots full" (a Hero's two taken).
    - **Remove** (#91; in the Remove chooser's rows, the nothing-picked page no longer lists them): a tap on a held relic's slot picks it out (`_AssignList.armed`; its slot lit; a tap again
      lets it go, another held slot moves it) and the row's last line becomes a light tag "Remove" (`Words.remove`;
      `_tag`'s green capsule, decisions-log 202: a row's buttons are never ui_buttons' bevels) and the relic's name.
      The tag takes it off into the bag (`Board._takeOff` → `Game.takeOff`, `Sfx.place`); the bag's count and the rows
      update. During a wave it is greyed with why in red (`takeOffRefusals`), and a tap on it says so in the message
      window (`Sfx.error`). Slot and tag act on tap
      UP, before the row (`_AssignList.taps`), so a tap on them never gives the pick; a turned page or the book
      shutting lets the relic go (`_open`). A small relic's Remove from a troop chooser lists the troops wearing it
      with the button on their last line at once, and a tap on the row takes it off (decisions-log 202).
  - **An item's rows:** one per troop type shown (an item goes on the whole type), 3 lines (4 on a narrow page):
    - the type's sprite and stars, a crown while it has a living Hero;
    - "<name> (<how many alive>)", and on the right the kind's taken/cap now ▸ after ("1/2 ▸ 2/2"; the cap
      doubles when the item completes an awakening);
    - the stats it changes now ▸ after as the troops fight (`fieldStats`, the Army page's numbers: "Field stats"
      above), the item's own first (an awakening it completes adds HP and MP), then on the right the coin and the
      price now ▸ after (`priceWith`);
    - the next awakening's progress: "Awaken n: have/need ▸ have/need", summed over the recipe, the "after" in
      the new level's ink when the item completes it, followed, when there is room, by the awakening skill it
      unlocks or raises in that ink ("Unlocks Disarm", "Disarm II"; `awakenSkillChange`, #88); its level's name
      ("Awaken 3", "Awaken 5 (Max)") once the items can raise it no more.
    - A type that can't take it is greyed, its reason in red instead of the stats and price (`refusalNames`:
      "Not for this type" not in its recipe, "Awaken first" at its cap until it awakens, "At max" at its cap for
      good, "Max range" a bow on a melee type at its reach cap, `meleeMaxRange` unless spears raised it), and its taken/cap alone.
  - **A Pusaka picked** (decisions-log 151; the design's §3.8, critique H1): the heading is its name in gold and
    its stars in the badge ("★1"); its type chooser (Equip on a type, Move to a type; an oath's Each type) lists one
    row per troop type shown, like an item's, 3 lines (4 on a narrow page), from `Game.pusakaPreview(relic, type)`
    (loot-items-relics.md "What a Tas row previews"):
    - the type's sprite and stars, a crown while it has a living Hero; "<name> (<alive>)";
    - what a tap does (`pusakaActionNames`): "Equip" (green: its first binding, free), "Move" with the coin and the
      price (a later binding: `rerollPrice`, "38k" at wave 86; the price red when the gold is short) or, on the type
      it is on, "To Vault" (free). Wide: right of the name; narrow: its own line;
    - the type's Pusaka now in its badge (`_pusakaCapsule`, its text the row's line size), or an empty grey slot. Wide: right of the stats' line;
      narrow: right of the name;
    - the stats it changes now ▸ after as the troops fight (the Hero's aura in, `fieldStats`: the Army page's
      numbers, "Field stats" above), the first with the count and the sum over them: "♥ 580 ▸ 927 x13 (+4,511)" (Dragon Heart onto the owner's 13 Templar at wave 86),
      a swap's loss too (Grail onto the Priest loses Dawn Star: "71.8 ▸ 55.2 x17 (-282)"); "x0 (asleep)" for a type
      with none alive. A Pusaka that changes no stat says what it does in a few words with the count (`pusakaGist`,
      "Hits 2 more, 40% (x9)": the count in brackets, so "Heals 15% of damage (x3)" reads as no multiplier);
    - the last line: why it can't, in red (`pusakaRefusals`: mid-wave "Only between waves"); else, when the HP
      changes, the next boss's blows a troop lives through from full HP now ▸ after, the after in green when it rises
      and red when it falls: "Boss hits lived (wave 90): 0 ▸ 1" ("Boss hits (w90)" where that doesn't fit); else the
      Pusaka the type loses ("Dawn Star to Vault").
    - **An oath picked** (any of the eight; decisions-log 155, 247): it binds nowhere, so every row of its Each type
      chooser reads "All
      troops" (`PusakaAction.sumpah`, not refused) and shows what the oath gives the type, without it ▸ with it
      ("♥ 504 ▸ 756 x2"), the boss's blows the same; while Oath of One or the Few waits its rows change nothing (the
      gist) and the last line says "Waiting: 5/2 types" or "Waiting: 48/24 troops" in red (`oathWaitingRowOf`, the
      types or troops alive now; short for a phone). A tap only says how it stands
      (`pusakaWhere`: "On: all troops ★1", or the wait). The where line says the same; an oath never sells.
    - A tap (on tap UP) binds, moves or unbinds it (`_usePusaka` → `bindPusaka` / `unbindPusaka`: the gold burst on
      the type's troops and `Sfx.magic`) and says so in the message window: "Dragon Heart now on Templar",
      "Dragon Heart moved to Templar -38k", "Dragon Heart to Vault". The pick stays, so the rows at once show
      where it went (its row now "To Vault", the others "Move"). A refused row says why. Three taps bind: the cell,
      the type row, then the row (decisions-log 202; two before).
    - Only between waves (`bindMidWave` false): during a wave the type row is greyed with "Only between waves" and a
      tap on it says so; a chooser left open greys every row likewise.
    - **Sharpen** (Asah; P6, decisions-log 154 and 202; the rules: loot-items-relics.md "Asah"): its row
      (`_sharpenRow`). On the right the tag "Sharpen ★2" (green; the star it gives, "Sharpen" alone with none to
      give), in two taps: the first arms it (red, "Sure?"), the second raises the Pusaka a star
      (`Game.asah`: the type's troops refit at once and burst in gold, `Sfx.clear`, as the chest's Ambil) and says
      what it took: "Dragon Heart ★2! -60k, Thorns 8, Fury 2". Another pick lets an armed one go; so does anything
      that refuses it. Its line says what it costs: the coin and the price ("60k"; red while the gold is short), then
      each small relic it would take as its icon and how many (`asahTake`: [thorns]8 [fury]2; "+ relics 7/10" in red
      while the bag holds too few; `_asahCost`); where the icons don't fit, "+ 10 relics" (`bagDetail('sharpenCost')`
      and its words, the price and the relics' names, for tests). While it can't for another reason the tag is greyed and the line says why in
      red (`asahRefusals`): "Only between waves", "Already sharpened this round: again after wave 90" (where that
      doesn't fit "Sharpened: again after wave 90", "Again after wave 90", "Again after w90"), "A Legendary can't be
      sharpened" ("Not for a Legendary" where narrower), "Already ★3". A tap on a greyed tag says the refusal (`whyNotAsah`) in the message window. It
      fits 1266×713 and 915×412 (test/asah_test.dart).
    - **Melt's picker** (Lebur; J3, decisions-log 164 and 202; the rules: loot-items-relics.md "Lebur"; `_leburPage`),
      a Vault Pusaka's Melt chooser, while it is open (`_AssignList.lebur`; its row's tap opens it): under the heading
      (the fodder's name and "★n"), in the lines' and rows' place, the chooser's head: "‹ Back" (the picker closes)
      and what goes, "Melt Void Eye ★1 into:" ("Melt Void Eye into:", "Melt into:" where that doesn't fit). Under it
      one row per Pusaka it could go into (`leburTargets`, in Relic order), scrolled like the type rows (wheel, drag,
      the bar), 3 lines (4 on a narrow page) (`_leburRow`):
      - its icon (faded while it can't; no glow);
      - its name and what a tap does: "Melt", the coin and the price (`leburPriceOf`, "60k"; red while the gold is
        short). Wide: right of the name; narrow: its own line;
      - its stars now ▸ after ("★1 ▸ ★2", the after in the preview blue) and where it is ("Templar (13)", "Vault");
      - the last line: what it does at the new star (`pusakaGist`, "+120% max HP"), or why it can't in red
        (`leburRefusals`: "A Legendary can't be melted", "Already ★3").
      - Two taps, like Sharpen's: the first arms the row (lit; "Sure?" in red, the last line "Tap again: Void Eye ★1
        is gone"), the second melts (`Game.lebur`: the target's troops refit at once and burst in gold, `Sfx.clear`) and
        says "Dragon Heart ★2! -60k, Void Eye melted". The picker closes and the pick moves to the target, so
        its page shows the new star. A refused row's tap says why. Another pick, a turned page or the book shutting
        close the picker. It fits 1266×713 and 915×412 (test/pusaka_tas_ui_test.dart).
    - The heading's count, the rows and the loot at the pointer ("★2", "Loot in hand" below) read the
      Pusaka's own state, not the bag: `_canHold` keeps an owned Pusaka in hand while the bag (`inBag`) counts a
      bound one 0.
  - Every row's words come from `Game.assignPreview(loot, type | unit)` (loot-items-relics.md), the same the
    field's popup (#86) shows, a Pusaka's from `Game.pusakaPreview`. "now ▸ after": now in ink, `ui_icons.png`'s
    smallest white right arrow (`_icThen`, its visible 7×10 from (181, 180); the font has none) at a whole number of
    screen px a sprite px about 0.6 of the text tall (`_change`), after in the
    book's preview blue (`_previewInk` 0xFF2A6FD6); numbers as the troop row writes them (two places where one
    wouldn't show the change). Text: names max(11, 15·ts), lines max(10, 13·ts).
  - **A row that can take it** is a button (`_rowCard`: lit under the mouse, pushed in while pressed), on tap
    UP: it gives one (`_useItem` / `_useRelic`), the row updates, the bag's count drops. A greyed row says its
    reason in the message window. Nothing to list (the filter hides every troop): "No troops.".
  - **Scrolling** like the battle log's: the wheel over the list (`onScroll` → `_assignWheel`; not where the
    open log lies over it) or a drag on it (`_AssignList.dragY`, by each move's `localDelta`); a drag is no tap,
    so it gives nothing. While it scrolls no row lights. A scroll bar down the list's right shows where it is when the
    rows are longer than the page: ui_bars.png's capsules turned upright (`_capsuleBar`, "The book's sprite kit"
    below), the rows ending left of it. A new pick starts at the top.
  - **Shortcut:** an item dragged out of the bag onto a troop on the FIELD (or picked, then a tap on the troop)
    goes to that troop's type (`_dropTarget`; the drop popup over the troop on the way, below), a relic to that
    troop, with the same refusals, which the popup says. While it is dragged the facing page shows its chooser (Give
    to troops, Equip on a troop; held, the chooser the player opened), and the row of the type (a relic: the troop, `_heldOver`) under the pointer is lit (`_frameLit`), or shaded
    red (`_refuse`) when it can't take it: the popup on the field says the same.
  - `Board.picked`, `bagSlot(kind)`, `assignRows` (whose: a type or a `Unit`; where; whether it can take it),
    `assignList`, `assignChip(type | null)` and `assignFilter` are what this frame shows, for
    `test/book_assign_test.dart`; `assignSlots` (whose, the relic or null, where), `takeOffArmed` and
    `takeOffButton` for `test/relic_slots_ui_test.dart`;
    `pusakaNoteButton('ok' | 'batal')`, `messageBox` and `tooltipShown` (the loot tooltip's title and lines as
    drawn) for `test/pusaka_tas_ui_test.dart`; the grid's `bagCells` (each cell shown, in order), `bagSlots` (the board's slots drawn, in order), `bagCategory`,
    `bagChip(category)`, `bagPage`, `bagPages`, `bagPager('back' | 'on')`, `bagMarks(kind)` (count, stars, bound type,
    oath, asleep, NEW, ▲; null: no cell) and `bagEmpty` (the empty text's lines) for `test/bag_grid_test.dart`; an
    enhanced stack's `bagLootCells` (each cell with its plus), `bagMarks(item, plus)` (`plus`: its tag), `bagStackSlot(item,
    plus)` and `pickedPlus` for `test/forge_enhance_ui_test.dart`.
- **Bookmarks (`_bookmarks`):** the pack's own page tabs (`ui_book_marks.png`, rects below),
  after the owner's reference pictures. Drawn at the book's pixel scale `ps`, in two passes around the
  book sprite: everything under it, then the open page's tab over it (`front`). They slide and bob with
  the book. Icons are 16 px at `ps`.
  - **Page tabs** on the top edge (`bookTabLeft`): the first 20 book px in from the book's left, then one every 22 book
    px, or every `bookTabTapMin` 44 screen px where that is more (decisions-log 301): book x 20, 42, 64, … on the desk,
    the tablet and 1600×947 (`ps` 2 and 3), 44 px apart at 915×412 (`ps` 1; 22 until then). A Town's six run past the
    left page there (the Bag's over the spine, the Settings' on the right page) and at 1600×947 (the Settings' over the
    spine's left end, short of its notch). Pasukan (crossed swords),
    Tas (the bag, `ui_icons.png` (144, 32); a red dot, dark-rimmed, on its icon's top right while a type with a living
    troop could awaken further from the bag's items, `bagAwakens`, #92 part 2: `_bagTabDot`) and Settings (gear); on
    Pasukan's the same red dot while gold piles up, at least 3 purses of the next wave, and a type with a living troop
    can buy its next Bangkit or Tempa level (`armyNudge`, decisions-log 163: `_armyTabDot`). Until decisions-log 296 a
    game without the Towns had a fourth, Toko, the Shop (the coin stack, grey until the store opened, `_lockedTab`),
    with that dot. A Town's tabs: "Town". The open page's tab is the tall paper
    one (its fill is the page's colour); its last two rows cover the cover's top line (sprite row 6) and
    the page's edge line, so it runs into the page. The others are the short tan one, 16 rows above the
    edge (two more behind the cover), and turn the page on tap. Under the mouse a shut tab comes those two
    rows out (button_fx.dart); it can't come higher without its bottom showing above the cover.
  - **No gold and wave ribbons** (decisions-log 285; the owner: "pita di buku untuk melihatkan gold dan wave di takeout
    saja"): until then an orange (coin + gold) and a red (sword + wave) ribbon hung out from under the right cover in
    landscape, and on a phone stood as two pills on the top edge right of the tabs. The top band's hearts-and-gold panel
    and wave meter show both. The 60 book px the landscape ribbons had stay right of the book (Layouts above).
  - Only the shut page tabs are tappable (`_hits`), each on its press area (`bookTabTap`, decisions-log 301; the tap
    rule's 44 px each way at least, as the Army detail's foot and the spawn bar): its part outside the book widened to
    44 px about its middle and made 44 px tall, down over the cover's edge as far as where the pages' writing starts
    (so it takes no press of a page's), then up. 1600×947: the tab itself, 60×48. The desk and the tablet: 40×32 tabs,
    44×44 press areas (2 px each side, 12 px down over the cover), touching but never over each other. 915×412: 20×16
    tabs, 44×44 press areas (12 px each side, 13 px over the tab, 15 under its bottom, to the writing's top), 17 px
    under the toggle's and Auto's bottoms as the book rests. Hover lifts a tab while the mouse is over its press area.
    `Board.bookTabTaps` for tests (`bookTabs` stays the tabs as drawn). The shut tabs are drawn clipped to the cover's
    top line, so the one over the spine's notch (sprite x 116-123, rows 6-8) shows nothing of its hidden rows there.
  - The book opens on Pasukan: `_open(_home)` whenever the book has closed (`_bookT` 0), and
    when "Main Menu" is pressed (in a Town on the Smithy).
  - The field's tabs are Pasukan, Tas and Settings (the Shop is a Town's), and a Town's are Smithy, Tavern, Shop,
    Pasukan, Tas and Settings ("Town"; Pasukan since decisions-log 301). The gold's red dot (`armyNudge`) is on
    Pasukan's tab, whose detail buys the Awaken and Forge levels (decisions-log 230), in a Town too.
- **No Shop page on the field** (decisions-log 296): the Toko, the Shop page of a game without the Towns
  (`lib/store_page.dart`'s goods in slots and the picked one's card with Buy / Sell; its "Awaken 4-5" section of a row
  per type and its "Fallen Heroes" section, ascend_page.dart and recall_page.dart), went with the Towns-off book and
  the TOWNS define; with the Towns on (every board game since decisions-log 237) the player never saw it. What it held
  is elsewhere: a Town's Shop ("The Town's Shop"), Awaken 4-5 and Forge on the Army detail's Next tag
  (`_upgradeButton`, "Army"), the fallen Heroes' Recall in the Army detail's Heroes section, the gold's red dot on the
  Army tab. `Board.storeAt('bagDot' | 'armyDot' | 'tavernDot')` is where a tab's dot is this frame, `Board.tempaMarks`
  each Tempa "+n" drawn (where, and its text) and `Board.heroSplash` the Hero splash's title while it shows, for tests.
- **Settings page (`_settingsPage`, `_Page.settings`):** replaces both pages' content. Like the other pages,
  mid-wave it is shown with the game paused by the book ("Pause").
  - Left page: "Settings", then "Music" (note icon) and "Sounds" (speaker icon). Each has a volume
    (`_volume`): − and + buttons (grey at 0 / 100) with the pack's bar between them in ten notches;
    tapping notch n sets n·10%. The row is `min(btnH, 32·ts + 8)` tall, so a phone page keeps the bar long
    (`Board.volumeRows`, for tests).
  - Left page, at its bottom (level with "Main Menu"): "How to Play", a plain button as wide as the page's writing
    (`Board.howToButton`) that opens the How to Play page. It sits under the volume bars, clear of them, at 1266×713,
    915×412 (test/guide_page_test.dart).
  - Left page, above "How to Play" (level with "Hero spotlight", the same 8·ts gap): "Show FPS: On / Off", a toggle
    as wide as the page, orange while on, its label 16·ts shrunk to fit (`Board.fpsButton`). A press flips
    `Settings.showFps` and saves it: the FPS readout (above). Under the volume bars at 1600×947, 1266×713, 1164×777
    and 915×412 (test/fps_readout_test.dart).
  - Every change calls `Sounds.volumes` (heard at once) and `saveSettings` (lib/settings.dart).
  - Right page: "Send game data" (#64) at the top, level with the Music row: a toggle as wide as the
    page, orange while on (`_button`'s active look), its label shrunk to fit; under it "Off" or "On:
    anonymous data". Off by default; a press flips `Settings.sendTelemetry`, saves it, and turns the
    telemetry's server copy (`_httpSink`) on or off. It gates only that: the local file is always written
    (telemetry.md). `Board.sendButton` is where it was drawn this frame, for tests.
  - Right page: "Main Menu" at the bottom: `showWelcome()`; during a wave the game waits paused, as the
    player's pause (`_menuPause`), so "Continue" comes back to it paused (`Board.menuButton`, for tests). Above it "Hero spotlight: On / Off", a
    toggle (orange while on) for a Hero's cast cut-in (`Settings.heroCutIns`); turning it off drops any
    cut-in showing or waiting. Above that "Monster spotlight: On / Off", the same for a foe champion's skill banner
    (`Settings.foeCutIns`, "A foe's skill banner"). Both labels are 16·ts, shrunk to the button's width. Above those
    "Licenses", a plain button (`Board.licenceButton`): it opens the Licenses page. The four sit under "Send game
    data"'s line at 1266×713 and 915×412 (`Board.sendNote`, `heroCutButton`, `foeCutButton`; test/foe_cut_in_test.dart).
- **Licenses page (`lib/licence_page.dart`, `_licencePages`, `_Page.licence`; decisions-log 137):** the game's
  licence, the credits and every package's licence, the way Flutter's `showLicensePage` shows them, but drawn in
  the book (the game has no MaterialApp, so Flutter's page can't open). It has no tab of its own: the Settings
  tab stays the open one, and the page holds the auto start and pauses a wave like Settings does.
  - **Left page:** "Licenses", then a column (`_Column`) of paragraphs from lib/licences.dart: the heading "Path of
    Hero", the licence in short (`licenceSummary`: source-available, build it for yourself, no sharing or selling,
    the name and icon reserved, the official builds on itch.io free or for a donation, the packs outside the
    licence), the heading "Kredit", one line per pack ("<role>: <pack>, oleh <author> (<link>)", `credits`), what was
    made for the game (`ownWork`) and the engine (`madeWith`). Under it "Back" (`Board.licenceBack`) turns back
    to Settings.
  - **Right page, the list:** "Packages", then one row per package in Flutter's `LicenseRegistry` (the build's NOTICES,
    plus the native libraries inside flutter_soloud that `registerLicences` adds, `nativeLicences`), sorted by name
    without case: the name (shrunk to fit) and, in grey on the right, how many licences it has. "Loading..." while
    the registry is read (once, on the page's first opening). The rows are cards like the Tas page's (`_rowCard`:
    lit under the mouse, pushed in while pressed); a tap UP opens one (a drag scrolls).
  - **Right page, a package:** its name as the title (shrunk to fit), its licences' paragraphs (indented as the
    text indents them, centred where Flutter's parser says so) with a faint rule between two licences, and "Semua
    paket" under them, back to the list.
  - Text: the game's font at max(10, 13·ts), headings 1.2× in the title weight, wrapped by `TextPainter` (one per
    paragraph, so the system font fills in the glyphs the game's font lacks). Both columns scroll with the wheel or a drag, with the
    Tas list's scroll bar (`_capsuleBar`). A package can have thousands of paragraphs (ICU: over 500 licences), so a column
    lays out what shows plus a page, then 60 more paragraphs a frame (`_Column.layOut`); the scroll bar grows
    until it is all laid out. Another package, a new width or text size lays it out again.
  - For tests: `Board.licenceShown`, `licenceLeft` / `licenceRight` (the paragraphs drawn this frame),
    `licenceRows` (each package row drawn: name, where), `licencePackage` (the open one), `licenceAll`,
    `licenceColumns` (test/licence_page_test.dart).
- **How to Play page (`lib/guide_page.dart`, `_guidePages`, `_Page.guide`; the guide's words: "Guide" above):** every
  page of the intro and every one-time card, word for word, with more, at any time. The Licenses page's twin: no tab of
  its own (the Settings tab stays the open one), it holds the auto start and pauses a wave like Settings, and it
  shares the Licenses page's columns (`_Column`, `_Para`), row list (`_rowList`), wheel, drag and tap UP
  (`_licenceWheel`, `_licenceDrag`, `_licenceTap` over `_columns`).
  - **Left page:** "How to Play", then the 12 topics (`guideEn.topics`), a row each like the Licenses page's packages
    (`_rowCard`; the open one in the lit card), scrolled where the page is shorter than the list (915×412); a tap UP
    opens one, its words from the top. Under them "Back" (`Board.howToBack`) turns back to Settings. The page
    opens on the topic open last (the first, "Goal", at launch).
  - **Right page:** the open topic's title (shrunk to fit), then a column of its words: each intro page and card it
    repeats (`pagesOf`) under its title in the title weight (a title once when a card's pages share it: K5's "Pick an Artifact"), its
    lines joined in one paragraph (they were broken for the card's width; I7's third line as the pointer is when the
    topic is laid out, a mouse's or a finger's); after a faint rule its own lines, a paragraph a sentence; after a rule
    the game's own texts it lists (`GuideLive`), read from the game as the tooltips read them: every item's
    (`itemEffect`, as the Shop's card), every small relic's (`relicEffect` and `relicSlotsLine`), or the Epic and
    Rare Pusaka's (`relicEffect` at one star, the name with its rarity: "Dragon Heart (Epic)"; the Legendary are left
    to be found). Each one's name in bold at the text's size, its lines indented under it; a line every one of them
    has ("For a whole type, up to a cap", "Cost: troop price +10%", "One relic per troop (Hero: 2)") is said once,
    before them. Text at max(10, 13·ts) like the Licenses page's, the same scroll bar.
  - **"Replay guide"** under the words (`Board.howToReplay`; its label shrunk to fit): plays the intro (I1-I7) again
    over the page, from its first page, and closed (Skip, Esc, "Play!") the page is there again. It leaves the seen
    set as it is: every card's words are on this page already, so bringing the one-time cards back would only stop
    Auto at the next breaks (a late save has several due at once), with no way to undo it. A press needs no "Sure?":
    Skip closes the intro.
  - The intro's last line ("More help: "How to Play".") names the page; the intro has no button to it: its footer's
    three buttons already fill a 412-wide phone's row, and the welcome screen's intro has no book to open.
  - For tests: `Board.howToButton`, `howToShown`, `howToTopic` (the open one's title), `howToTopics` (each row drawn:
    title, where), `howToText` (the paragraphs drawn this frame), `howToParas` (all of the open topic's, as laid out),
    `howToBack`, `howToReplay`, `howToColumns` (the list, the words) (test/guide_page_test.dart). Shots:
    test/probe_guide_page_shots.dart.

## The book's sprite kit (decisions-log 187)

The pieces the Bag and Troops pages' revamp (list on the left, detail on the right, one grid of same-size cells) is
built from, all cut from sheets already in assets/ (no new art, no shape drawn in code). The capsule and the scroll bar
are in use. The Bag's grid and the Army page's rows had these slots too, until the owner's picture of a slot board
turned the Bag's cells into the paper card's slots ("Tas, the Bag" above) and the Army rows followed (decisions-log
198: the paper card grown to a row; a cell of a two-column grid since 218, "Army" above); the slots are drawn now only by `Board.drawSlot`, for tests and
test/probe_book_kit_shots.dart.

- **Slots** (`_slotFrame(c, r, row, look, k, {paint})`, lib/button_fx.dart): `ui_all.png`'s square slots, one colour
  per row 48 px apart (`slotSrc`; `slotTan` 0 an item or a Pusaka, `slotWhite` 1 a small relic or a locked row, 2
  green, 3 blue, `slotOrange` 4 the one picked, 5 red, 6 purple), each look in its own column: normal x 10 (disabled
  too), lit x 202 (the mouse on it), pressed x 394. Normal and lit are 28×31: a 1-px outline 3F2832, a light rim
  (EAD4AA on the tan; 2 px wide on the lit), the face (E4A672) and a 6-px lip (B86F50). Pressed is 28×28, its face sunk
  into the lip: drawn 3·k lower so it ends on the normal one's bottom row (`slotRect`), and the call returns that 3·k
  for what sits on it.
  - 9-sliced exactly (`slotInsets`): the least insets that leave each row of the stretched middle one colour across
    and each column one colour down, so a slot keeps its pixel art at any size: normal l/t/r 3, b 6; lit 4, 4, 4, 7;
    pressed l 6, t 6, r 5, b 5 (its shade down the right). The same for every colour (test/book_kit_test.dart reads
    them off the sheet).
  - On whole pixels (`_whole`) at a whole k with no overlap between the pieces (`_nine`'s `seam` 0; elsewhere each
    piece reaches 0.5 px into the next against hairlines, and that half-covered pixel darkened a cut corner). The
    capsule and the scroll bar are drawn the same way.
- **A Pusaka's cell** (`_rarityCellPaints`, lib/chest_popup.dart): the tan slot with its rim in the rarity's rim colour
  and its lip in its dark, the chest cards' (`_rarityFrame`: Langka 8CC878/4E8C46, Epik B98CF0/7E50C8, Legenda
  F2C23C/C8821E), the face and the outline kept. `_recolour4` is an affine colour matrix (`ColorFilter.matrix` with
  its offset column, `recolourMatrix`) through the slot's four colours; `_recolour` (the chest cards') is linear
  through black and pins only three, so it would move the outline. The lit and pressed looks have the same four
  colours, so one paint per rarity serves all three. The matrix is steep (factors up to ~17): Impeller works it in
  half floats, which in a simulation lands within 2 of 255 of each target; the tests' Skia lands exact.
- **The capsule** (`_capsule(c, label, fs, at, {anchor, icon, faded, green, draw})`, lib/badge.dart): the book's badge,
  `ui_bars.png`'s dark capsule (82, 33, 12×6: a 1-px outline 181425 round a 3F2832 fill, corners cut), 9-sliced 1 px,
  on whole pixels, the label in cream FFF1D6. Its size is `capsuleSize`: fs·1.3 tall (13 px at the 10-px floor),
  `capsulePad` each side inside, with an icon (a Pusaka's) first a square of the inside's height and `capsuleGap`
  after it; its scale `capsuleK` stays 1 up to 27 px tall, so the outline is one pixel beside the book's text. Its
  text never goes under 10 px. It replaced `_countBadge` (the Shop's slots, the Tas heading's count) and `_pusakaPill`
  (`_pusakaCapsule`: the Army detail's and the Tas rows' Pusaka badge); faded, the capsule, icon and text are ghosted.
  With `green` it is the light tags' green capsule (2, 65, 12×6) with their dark ink 3B2210: a Sell cell's count in the
  Shop's basket (decisions-log 269).
- **The scroll bar** (`_capsuleBar(c, list, content, scroll)`, lib/bag.dart): the outline capsule (98, 33, 12×6) as
  the track down the list's right and the dark one as the thumb, both turned upright (drawn lying in a frame turned a
  quarter, on whole pixels), 6 px wide (`_capsuleBarW`), 9-sliced 1 px; the thumb as long as the share shown, 12 px at
  least. The Tas page's lists (the rows, Lebur's picker) and the Licenses and How to Play columns use it; rows end
  `_capsuleBarW` + 2·ts left of the list's edge. It replaced two code-drawn bars (a faint rounded track and thumb).
- For tests: `Board.drawSlot`, `scrollBars` (each bar's track this frame), `storeAt('badge:<kind>')` (a Shop slot's
  badge), `bagOpen` (the book drew the Tas page this frame: the Bag grid will give a kind with none left no slot, so
  `bagSlot` is no sign of the page). The shots: test/probe_book_kit_shots.dart (the Shop, the Tas page, the Army
  rows and the Licenses page at 1266×713 and 412×860, and kit.png, the slots' looks and the Pusaka cells).

## Words (`lib/words.dart`, decisions-log 187)

The words for the game's mechanics, places and shared buttons, and the three refusals several systems share, in one
class (`Words.artifact`, `Words.vault`, `Words.sure`, `Words.onlyBetweenWaves`, the rarities `Words.common` …), so a
later pick of a name is one line. A plain library with no imports; game.dart exports it, so main.dart and the tests
reach it. Display only: enum names, save keys, telemetry and test ids never read it. The defaults are the English
glossary's (Artifact, Awaken, Forge, Sharpen, Melt, Carve, Vault, Shadow, Boss Chest, Reroll …); the owner hasn't
picked the names yet. The awakening and Forge levels ("Awaken 3", "Forge +6"), the item picker's "Awaken first" and the
shared refusals draw from it, and so do the menus' and the HUD's buttons and headings (Start and its width probe,
Army, Settings, Scoreboard, How to Play, Back, Skip, Sure?, +Room (its tooltip's "more army room", "Room: max" and
"Army room is at its most", decisions-log 292), Replace fallen, the two Autos' Auto Wave and Auto Buy
(decisions-log 290) with the hold line and the guide's quotes of them, Tide in the wave meter, the army
cap's lines and the guide's quotes of them; the Towns' Town, Smithy, Leave town and "Town after wave"); the rest of the drawn text moves onto it as each area turns English ("In-game text"
below). test/words_test.dart checks that none is empty or has stray spaces and that no two are alike.

## In-game text (decisions-log 168, 190, 193, 195, 197 and 200)

The owner (2026-10-03): "semua in game text di rubah ke bahasa ingriss". Everything a player reads in the game is simple
English: the HUD, buttons, tabs, menus, headings, tooltips, refusals, messages, the battle log, the guide and the item
text. (Until then only the item text was, from the owner's 2026-10-02 "bahasa bayi english", over a screenshot of
Alliance's tooltip; the rest was Indonesian.) The change went area by area (six batches): the item text, the names (below), the Army page (its rows and the picked type's
detail, decisions-log 187), and with that detail the store's refusals and the Shop's Awaken and Forge buttons (their
labels, refusals and messages); and the menus, the HUD and the wave meter (decisions-log 193: the welcome screen, the
start button, the troop counter's list, the game over and the scoreboard, Settings, the Licenses and How to
Play pages' headings and buttons, the victory popup, the messages, the splashes' "Tap to continue", the guide's own
buttons, the wave meter's tooltip, the army cap's lines); and the Shop, Awaken, Forge, Recall and the awakening skills
(decisions-log 195: the Shop page's goods, card and buttons, the Awaken and Forge tooltips, the Fallen Heroes section, all three gone with the Toko in decisions-log 296,
the troop rows' stars tooltip, the awakening skills' lines, the guide's Shop words); and the Boss Chest, the
rarities, the battle log and the Artifact reports (decisions-log 197: the chest's popup, chip, messages and log lines,
the rarity names, every log line and chip, the "VICTORY!" popup's Artifact line, the Grail's cut-in, the guide's chest
and Artifact words); and last the Bag, the Artifacts and the troop tooltips (decisions-log 187 for the Bag's right
page, 200 for the rest: the HP and MP tooltips, the drop popup, the pinned plate's Remove, the Artifact refusals and
notes, the oath's wait). Since decisions-log 200 every string in lib/ is English but those below.

- **Stays as it is:** the legal texts on the Licenses page (the licence summary, the credits, the OFL texts:
  `lib/licences.dart`) until the owner says otherwise; personal names (`lib/names.dart`); save keys, enum names,
  telemetry fields and test ids (`Rarity.legenda`, `Tier.highElite`, `OmenKind.thorns`, the save's "pusaka", the
  store's 'tab:bangkit'), which never change with the words. What was English already stays: the Artifact names
  (Dragon Heart …), the Hero, awakening and monster skills, Templar, Orc, Hero, Auto (since decisions-log 290 "Auto
  Wave" and "Auto Buy", `Words`), HP, MP.
- **Style:** short common words, about 6 a line at most, present tense, no idioms. The effect comes first, its number
  in front as a change: "+25% attack", "-15% damage taken", "x2 damage every 3rd hit" (a multiplier only for one hit's
  damage; else +/-%). Every number comes from the rules' constants (`_pct`, `_nth`, `_count` in game.dart; thousands
  the English way, `thousands`: "4,511"; dot decimals).
- **Capitals and order:** a page, tab or mechanic used as a name is capitalised (Army, Bag, Shop, Vault, Awaken 3,
  Forge +6, Sharpen, Boss Chest); common nouns stay lower case (troop, type, wave, gold, monster, relic, item, star).
  The rank goes first ("High Elite Skeleton Archer", a foe banner's line), a build's epithet first ("Undying Templar"),
  and a boss bar reads "<name> the <title>" ("Morgath the Summoner").
- **One word for one thing.** The mechanic words, the places and the three refusals several systems share ("Only
  between waves", "Not enough gold", "Game over") are constants in `lib/words.dart` ("Words" above), which the buttons,
  the guide's quotes and the width probes read; the names are tables in game.dart (`troopTypeNames`, `itemNames`,
  `relicNames`, `monsterTypeNames`, `tierNames`, `bossTitles`) and the catalog's epithets (`Art.epithet`). The
  glossary (the code's name on the left; a later pick by the owner changes one line):

  | Code | On screen |
  |---|---|
  | Pusaka, Relik (the four small ones), Barang | Artifact, Relic, Item |
  | Bayangan (`OmenKind`) | Shadow; its kinds Armor, Haste, Mend, Spikes (`thorns`), Wound, Barrier (`shield`), Escort (`guard`) |
  | Bangkit, Tempa, Asah, Lebur, Ukir, Sumpah | Awaken ("Awaken 3", "Awaken 5 (Max)", "Not awakened"), Forge ("Forge +6"), Sharpen, Melt, Carve, Oath |
  | Pasang (the tide), Kapasitas, Batas, Serpihan | Tide, Room ("No room"), cap, Shard |
  | Toko, Tas, Gudang, Pasukan, Peti Bos, Kocok ulang | Shop, Bag, Vault, Army, Boss Chest, Reroll |
  | Hero Gugur, Panggil kembali, tukar | Fallen Heroes ("Fallen (2)"), Recall, swap ("Recall  57k, swap 1 Templar (+6k)") |
  | jeda (a skill's), detik, petak | cooldown ("MP 10, cooldown 22s"), s / seconds, tile(s) ("1 tile", "2.5 tiles") |
  | Biasa, Langka, Epik, Legenda (rarities) | Common, Rare, Epic, Legendary |
  | Biasa, Elit, Elit Tinggi, Mini Bos, Bos (ranks) | Normal, Elite, High Elite, Mini Boss, Boss |
  | the troop types | Soldier, Knight, Swordsman, Archer, Lancer, Priest, Axeman, Wizard, Templar |
  | the monsters | Slime, Bat, Skeleton, Orc, Skeleton Archer, Werewolf, Armored Skeleton, Orc Rider, Veteran Orc, Armored Orc, Greatsword Skeleton, Werebear, Necromancer, Necro Healer |
  | a plate's kinds | Undead, Healer, Summoner, Raised |
  | the boss titles (by type, as above) | Sticky, Nightwing, Ironbone, Crusher, Deadeye, Moonfang, Ironclad, Stormrider, Warlord, Steelwall, Gravesword, Rockclaw, Summoner (the necromancer), Dark Healer |
  | the items | Sword, Shield, Boots, Bow, Gloves, Potion, Staff |
  | the small relics | Fang, Thorns, Fury, Guard |
  | the build epithets (Dragon Heart … Dragon Crown) | Giant, Dawn, Storm, Undying, Void, Steel, Blood, War, Mourning, Crowned |
  | the drop popup's stats | HP, MP, Defense, Attack (a healer's: Heal), Range, Speed, Attack wait, Regen |
  | the item picker's refusals | Not for this type, Awaken first (by grade a closed grade names the Awaken: "Opens at Awaken 2"), At max, Max range |

  The words in the item text: troop; type (a troop type); HP and max HP; attack; damage; heal; hit; wave; boss;
  monster; tile; star (★); "this type" (an item over its row); "all troops" (an oath); "whole run". "Now:" marks a
  live line; "On: Templar ★1" where a Pusaka is bound, "In Vault ★2", "Not owned yet", "Asleep: no Soldier alive";
  "Cost:" an item's catch; "In bag: 3". US spelling (Armor, Defense, Artifact).
- **Where the item text is:** every line that tells about an item, a small relic or a Pusaka (Epik, Langka, Legenda,
  an oath): the loot tooltips (`itemInfo`, `relicInfo`, below), the chest's cards, the Town's Shop's card, the Tas page's
  Gudang strip and the picked one's line, a Pusaka row's few words (`pusakaGist`, Lebur's rows too) and Oath of One's
  wait on its rows, the Asah strip's cost, Lebur's strip and its armed line, and the drop popup's relic effect.
- **Checks:** test/english_text_test.dart (no Indonesian word in a string in lib/: its `pending` map of per-file
  counts went down to empty in decisions-log 200; the ids and the legal texts allowed), test/item_text_test.dart (every item tooltip
  fits a 412-px phone), test/guide_text_test.dart (the guide's rules); the shots of test/probe_english_shots.dart at
  412×860, 1266×713 and 915×412 (testing.md).
- **A tooltip's order:** (1) what it does (the green line); (2) a live line marked "Now:", only where it adds a number
  (Dragon Heart's HP over its type, Dawn Star's heal or damage a second, God's Thunder's share in crowds, the Grail's
  saves, an oath's bonus): a line that would repeat the effect is left out, so the Langka, Void Eye and Dragon Crown
  have none; (3) its catch or reach: "For a whole type, up to a cap" and "Cost: troop price +10%" (an item), "One relic
  per troop (Hero: 2)" (a small relic), "For a whole type, never lost" (`pusakaLine`), "Lasts the whole run"
  (`oathLine`); (4) where it is. No line twice, and an oath's "Oath" once (test/item_text_test.dart).
- Alliance, the screenshot's: "Oath: up to 6 types (not 4)" / "Each type alive: +5% HP and attack" / "Now: 5 types,
  +25%" / "Lasts the whole run" / "On: all troops ★1". Oath of One while it waits ends "Waiting: keep only 2 types"
  (`oathWaitingOf`) where its place would be, with no "Now:", Oath of the Few "Waiting: keep 24 troops or fewer". The
  fixed oaths (the Wall, Blood, the Vanguard, Kings, Spells) have no "Now:" line: their effect lines say it all.
- **It fits:** test/item_text_test.dart lays out every tooltip an item, a relic or a Pusaka can show (each Pusaka at
  each star, bound, asleep, in the Gudang, not owned; an item over every type's row) in Pixelify Sans: the widest, a
  potion over the Priest's row, is 250 px, where a 412-wide phone leaves 404.

## Loot tooltips (lib/tooltip.dart)

- **Where:** every bag slot (items and relics, from `_slots` / `_relicSlots`) and every item stat cell
  of a troop row (its item icon and value, registered by `_troopRow` into `_tip.rows` with the row's
  type); and a row's HP and MP cells and its stars (`_tip.hints`: `_Hint.hp` / `mp` / `awaken`), and its Pusaka's
  badge (`_Hint.pusaka`: the Pusaka's `relicInfo`, its icon in the title); and the wave meter once the tide is on
  (`_Hint.tide`, its target `_tideAt`, set by the meter; "Wave meter" above).
- **Words:** `Game.itemInfo(item, [type])` / `Game.relicInfo(relic)` / `hpInfo` / `mpInfo` /
  `awakenInfo` in lib/game.dart (numbers from the rules' own constants; loot-items-relics.md). Title
  with its icon (the loot's, the heart, the blue bolt, the star); then the effect (green), who gets it,
  the price step (items), "Tap, then pick a troop" (both), and the bag count (relics:
  also how many troops hold one). In a row it also says how many the type took against its cap and
  their total ("Now: 2/3 on this type, +56%"), or that the type can't take that kind. The loot's lines are the item
  text's simple English ("In-game text" above), and so are the HP, MP and stars' lines. The HP cell's: "Max HP 140
  (base 140)", "Only Awaken raises it", "Each level: +25% of base" (`awakenHp`), then the type's Pusaka that raises it
  ("Dragon Heart ★2: x2.2"); the MP cell's the same with "Max MP 80, regen 4/s". The stars' lines first tell its
  awakening skill (#88, `awakenLines`, no icon: "Awaken 1 unlocks Disarm" or "Skill: Disarm II", what it does, "MP 12,
  cooldown 20s", the next level's numbers), then what the next awakening needs, each line led by the recipe item's
  icon (16 px), "Sword 1/3". The MP cell's lines end with what spends the MP: a healer's "Each heal: 6 MP"
  (decisions-log 297), "For <#10 skill> (5 MP)", then "and Disarm II (12 MP)" once awakened. A row's numbers are the field's (the Hero's aura in, "Field stats" above), and
  while a Hero lives the HP and MP cells say so, "Hero aura x1.15", and an item cell the type took "With Hero aura:
  +15%".
- **Frame** (#38, the owner: "di UI pack ada tooltips, pakai itu"): the pack's tan pointer panel
  (`ui_tooltip.png`, rects below), at `_tipK` 2, drawn by `_tipFrame`. The title is dark brown (`_dark`),
  the effect line dark green (`_effectInk`), the rest brown ink (`_tipInk`).
- **Placement** (`_tipAt(target, w, h)`, on whole pixels, 4 px from the screen's edges): above what it
  tells about (the slot, the cell, the stars, the troop), its pointer down at the target's top middle,
  the tip just touching it. The box slides sideways to stay on the screen; the pointer stays over the
  target, along the straight part of the bottom edge. Where the box would run off the top, it goes
  beside the target instead, right of it (else left), with the side pointer on the facing edge at the
  target's middle. A unit's plate has a higher top (`floor`: `_plateTop`, #74): the lowest of the top
  rows (the troop counter, the hearts-and-gold panel and the book button; the toggle, x2, Auto and the "Chest!" chip;
  `_meterBottom`), the wave meter, the open minimap (under the meter in every state), the Town chip and the boss bars
  (not while the book puts them at the left), plus 4 px.
  So a unit in the top rows gets its plate beside it rather than over the wave meter, Auto, the map or a
  boss bar; beside it the box also stays below that line.
  - The book bobs; the tooltip is anchored to the target, so it bobs with it.
- **Mouse:** shows after the pointer rests `_hoverDelay` 0.25 s on it. Moving straight onto another one
  shows that at once.
- **Touch** (no hover): a finger held still `_pressDelay` 0.4 s shows it (placed the same way, so above
  the finger); lifting hides it and is then no tap, so a row isn't bought. A quick tap still buys;
  moving the finger (a drag) cancels it. Told apart by `TapDownEvent.deviceKind` (mouse or not).
- Hidden while anything is dragged (`dragAt`); the unit plates also while loot is in hand (the drop popup
  tells about the troop instead, below). Drawn after the HUD, before the cursor;
  always kept on the screen.
- `_mouse` follows drags too (`onDragUpdate`, at `_dragPos`, below): hover events stop while a button is down, and a stale
  `_mouse` put the cursor and the tooltip back at the drag's start after a drop.
- **Unit plates** (#55; lib/plates.dart). Off the loot, pointing at a unit on the field shows its plate in
  the tooltip frame, pointing at it: the target runs from the top of its bar to its feet (`_unitRect`).
  - **Which unit:** the one, troop or monster, within 12 units of the middle of its body (`_unitAt`, 7
    above its feet), so the right one in a crowded rank. The same delays, placement and touch rules
    apply (`_point`, `_tipAt`).
  - **A troop's plate** (`_nameplate`, tooltip.dart):
    - its name (`Unit.name`, after "Hero" for a Hero), dark brown 18;
    - under it, its type's name (`troopTypeNames`), ink 14; with a Pusaka bound to the type its build name instead
      ("Undying Templar", `buildNameOf`), in the Pusaka's ink (`_pusakaInk`; decisions-log 149);
    - for a Hero, a third line with its 2 rolled attributes (`_heroStats`, hero.dart) and a fourth with its
      own skill (`_heroSkillLine`);
    - a line for each relic it holds (#91): its icon (16) and name, ink 14.
    - **Pinned**, each relic's line ends in a small pack button "Remove" (`Words.remove`, its width measured from it;
      `_plateTaps`, `Board.plateTakeOff`): a tap
      on it takes that relic off into the bag (`Board._takeOff`) and the pin stays (`_plateTap`, before anything
      else a tap up does; not where the HUD covers the field). During a wave the buttons are greyed and "Only
      between waves" shows in red under the lines; a tap says it in the message window.
  - **A monster's plate** (`_monsterPlate`; its words from `monsterPlate` in game.dart):
    - its type's name (`monsterTypeNames`, e.g. "Necro Healer"; the widest "Greatsword Skeleton"), dark brown 18;
    - its rank (`tierNames`: Normal, Elite, High Elite, Mini Boss, Boss) in its HP bar's colour with a dark
      outline (`_tierColor`), then in ink what kind of monster it is, joined by commas: Undead (dark), Healer (a healer), Summoner (the summoner), Raised (raised by
      a necromancer);
    - the heart, then "HP now/max" (now rounded up).
  - **Pinned** (`Board._pinned`):
    - A tap on a unit (a click; touch: a tap) pins its plate. It shows at once, anchored to the unit so it
      follows it, and stays up.
    - A tap on another unit moves the pin; a tap on the same one keeps it.
    - It goes on a tap anywhere else, the unit's death or leaving the field (`_dropPin` each frame), a new
      game or game over.
    - A drag (moving a troop, an item, a relic) is no tap and leaves it. A tap on a button still does what
      the button does (and, being elsewhere, unpins).
    - It is drawn under the HUD (the book, the buttons and the counter stay over it), and not while its unit
      is out of the view or being dragged to a new spot, nor while loot is dragged or in
      hand (the drop popup, below; the pin stays). `Board.pinnedPlate` is where
      it was drawn this frame, for tests.
    - Pointing at other units still shows their plates meanwhile; pointing at the pinned one shows no
      second plate.
  - The cursor is the hand over a unit, since a tap there does something.
  - Not while the open book (`_bookArea`, set each frame by `_book`), a button (`_hits`), the troop counter
    or its list (`_troops.button` / `.list`), the battle log's button or open panel (`_log`), the wave meter
    or the open minimap (`_map`, #80), the boss bars (`_bossAt`) or the off-view marker (`_offViewAt`) (both
    #74) is over it, nor once the game is over (its screen and the scoreboard over it; troops can still be
    alive when the lives run out) (`_covered`). The tap that closes a new Hero's splash neither pins nor
    unpins.
  - Hovering (not pinned), the pointer is the anchor, not the unit: a unit that walks away from under the
    pointer loses its plate.

## Loot in hand and the drop popup (`lib/drop_popup.dart`)

The owner (#86): "ketika assign item ganti yellow ring dengan popup ketika user hover troops", "begitu juga red
ring", and "ketika item punya lebih dari 1 user bisa assign berkali kali tanpa harus klik item lagi terus klik
troops lagi" (decision 121).

- **In hand** (`Board._picked`, an `Item` or a `Relic`):
  - A tap on a bag slot with any left picks it (its slot lit); a tap on it again, or on an empty slot, puts it
    back. Relics too: a tap on one no longer says to drag it.
  - A drag out of a slot carries that loot. A drag started anywhere else while something is picked carries the
    picked one (not a troop to a new spot).
  - A drop on a troop on the field, or a tap on one, gives it: an item to the troop's whole type (`useItem`), a
    relic to that troop (`useRelic`). A refusal plays the error; the popup says why, so no message window
    (`_useItem` / `_useRelic` with `say: false`; the Tas list's taps still say it there).
  - It stays in hand after each one given while it can (`_canHold`: the bag holds more; a Pusaka, while it is
    owned, bound or not), and after a refusal; the Tas list stays open too. It goes, nothing given, when the bag
    runs out of it, on a tap on bare ground (the field where no
    troop is; it unpins as ever), a drop on nothing, Esc (before it would pause), a right click
    (`onSecondaryTapDown`), a page turn or the book closing (`_open`), another game coming in, or game over.
  - Which troop: `_dropTarget(p)`, the one nearest `p` within 12 units of its feet (`_troopNear`), none where
    the HUD covers the field (`_covered`: the book, a button, the counter and its list, the log, the meter and
    the map, the boss bars, the off-view marker; not the pause's overlay). A drop over the book no longer reaches a troop
    hidden under it.
- **At the pointer:** the loot, faded (`_ghost`, 14 world units across), and "x<n>" at its bottom right, how many
  the bag holds (cream with a dark outline, `_countSize` 18 px); a Pusaka its stars instead, "★2", as its Tas slot
  says, bound or in the Gudang (the bag counts a bound one 0: it said "x0" until tas-fix, 2026-10-02). With the mouse at the pointer; with a finger
  `_fingerLift` 28 px above it, so the finger doesn't hide it (Flame leaves a drag's device unknown, even a
  mouse's, so the press that began it tells: `_touch`). Held and not dragged, at the pointer's last place (`_handAt`: the mouse, or the
  finger's last press).
  - **Not over the open book while only held** (ghost-book, 2026-10-02; tas-fix's flag): picked but not dragged, with
    the pointer (the mouse, or the finger's last press, not the lifted spot) over the open book, its pages
    (`_bookArea`) or a tab on its top edge (`_overBook`), the loot and its count aren't drawn. There they covered the
    button about to be tapped: Sharpen's "Sure?", Sell, the Bag's rows. Its slot, lit while picked (an item's or a
    relic's bag slot, a Pusaka's slot and its Gudang chip), and the facing page's heading (its icon, name and count)
    say what is in hand. Nothing else changes: dragged, it is drawn over the book as ever; on the field it is drawn
    whether held or dragged; no troop under the book takes it anyway (`_covered`), so no popup was there to lose; taps
    are what they were. A finger near the book's top edge may lift it onto the field while hidden: the press decides.
- **The popup:** in the tooltip frame (`_tipFrame`), over the troop the loot would go to and no other. No troop
  is ringed any more (the amber ring round every troop of the type, red when it couldn't, and the relic's
  yellow one are gone). Its words come from `Game.assignPreview`, which the Tas lists share (#87):
  - **An item:** its icon and "Every <type> (<n>)", the living troops of the type, all of which take it; then
    each stat it changes, before and after ("Attack 20 → 25", `statName`; an awakening it completes adds
    HP and MP); the kind's taken/cap led by its icon ("Sword 0/3 → 1/3"); and led by a star the awakening
    it counts toward, the recipe's items summed ("Awaken 1: 0/10 → 1/10"), or, when it completes one,
    "Not awakened → Awaken 1" with the new level in its ink (`_awakeInk`), and under it the awakening skill it
    brings (`awakenSkillChange`, #88): "Unlocks Disarm" in the new level's ink, or "Disarm → Disarm II". The arrow
    is `ui_icons.png`'s small white one (`_icThen`, the Tas rows'; the font has none), the value after it in the
    effect green.
  - **Refused:** the reason in red (`_blockedInk`, `refusalNames`: "Not for this type", "Awaken first", "At max",
    "Max range") and nothing before → after; then the kind's count ("Sword 3/3"; none for a kind outside
    the recipe) and, for "Awaken first", how far the awakening is ("Awaken 1: 3/10").
  - **A relic:** its icon and the troop's name ("Hero <name>" for a Hero), its type's name under it, then the
    relic's effect lines (`relicEffect`, green) and any stat it changes (none since the Pusaka, decisions-log 138).
    On a troop that can't take it: its reason in red instead ("Already holds <relic>", "Relic slots full"). Over
    a Hero (#91), after its type: "Relic slots n/2" → n+1/2 (no after when refused), then each relic it holds led
    by its icon.
  - **Placement** (`_dropPlace`): placed as a plate (`_tipAt`), pointing at the troop and the loot at the pointer
    together, so it never covers the pointer. Tried in turn: above them, left of them, right of them, and below
    them (the pointer up; `_tipAt`'s `side`), each centred on the troop or lined up with one of its edges, and last
    beside it (right, then left) hanging from its bottom as low as the screen allows, only where it stays wholly beside
    it (under the shorter landscape book's edge, decisions-log 283, the room left there); the
    first that overlaps the HUD least wins (#74: the open book, the log's button and open panel, the boss bars,
    the wave meter and the open minimap, the troop counter and its list, the off-view marker, the Start/Pause
    toggle, x2 and Auto), the troop itself counting ten times; kept on the screen, under the top rows and the wave meter
    (`_rowsTop`). Not under a plate's floor (`_plateTop`, below the map and the boss bars too): the popup keeps
    clear of those by itself; where nothing near is clear of them all it takes the spot that covers least. Drawn over the HUD (placed clear of it), under the cut-ins, the Hero splash and the
    message window.
  - No delay: it follows the pointer from troop to troop. Touch has no hover: after a tap gives one, it stays
    over that troop (the finger's last press), telling about the next.
- While loot is dragged or in hand the pinned plate isn't drawn (the pin stays: `Board.pinned`) and pointing at
  a unit shows no plate, so the popup never stacks with one. The book's tooltips still show.
- **Drag positions** (`Board._dragPos`): where the drag began plus every update's delta. Flame 1.38's
  `DragUpdateEvent.localEndPosition` adds an update's delta to the pointer's new position again, so it ran one
  move ahead of the pointer (a fast drop could miss the troop under it). The dragged loot and troop, the drop,
  the popup and the battle log's drag-scroll all read `_dragPos`.
- For tests: `Board.picked`, `bagSlot(loot)`, `dropFor`, `dropPopup`, `dropLines` (a change written
  "now > after"), `heldGhost` and `heldCount` (the loot at the pointer and its count, "x3" / "★2"; Rect.zero and null:
  none drawn, nothing held or only held over the book), `heldCue` (the held loot's lit slot while it isn't drawn over
  the book; Rect.zero: not so).

## Sprite rects (all 9-slice via `_nine`)

| What | Source |
|---|---|
| Buttons | `ui_buttons.png` (`UI_Buttons.png`'s first three columns, `tool/import_fx.py buttons`): 32×16 cells, one colour per row 48 px apart: 0 light brown (normal), 1 white (disabled), 2 green (the start button, Next), 3 blue, 4 orange (active), 5 red ("Sure?"), 6 purple, 7 peach, 8 grey. Columns: normal (0), hover (32), pressed (64), each visible 30×14 from (1, 1) (`_btnSrc`); the two rows under each colour are the same looks with square and round ends. Slices l/r 4 (the cut corners), t/b 6 (rows 7–8 of the cell are the only straight ones in all three). `_button` draws the label in dark ink. Before the owner's three states they were `ui_all.png`'s 28×31 buttons (column 0 plain, 4 lit, 11 pushed in). |
| Spawn bar's hotbar and step (decisions-log 287) | `ui_hotbar.png` 30×28 (tool/import_fx.py `hotbar`, from `UI_Premade.png`'s flat hotbar (108, 154, 120×28), the owner's picture): the panel without its slots (0, 0, 11×28: the hotbar's columns 0-4, 23 and 115-119, a plain tan middle), slices 3 all round; one inset slot (12, 0, 18×18: its 5..22 square), slices l 2, t 3, r 2, b 1; both at `hotbarPx` 2. `battle_step.png` 352×76 (tool/import_battle_floor.py, decisions-log 295): one strip of ground, every column Floor Tiles1.png's grass-topped cell's (32, 0) lowered to the ground's height there: low ground (0, 0, 32: its grass 60 px down), the slope up (`_stepUp` 32, 0, 96×76), the step's top (128, 0, 96: `_stepTop` its middle cell 160, 0, 32×32), the slope down (`_stepDown` 224, 0, 96×76), low ground (320, 0, 32); `_stepEarth` (136, 24, 80×48) inside the top's earth, one flat colour, stretched over the earth under the step and under the floor; at the floor's 5 px a world unit, not sliced. |
| Welcome panel | `ui_all.png` (1064, 104, 32×32), the parchment with a dark rim and curled corners; slices 8, drawn at 4 screen px per sprite px (2 on phones). |
| Card / item slot | `ui_all.png` (1021, 13, 22×22). The Bag's slots (`_bagSlot`, slices 5, at the book's k; a Pusaka's and the pick's recoloured: "Tas, the Bag"); the Bag's category strip and a chooser's filter tags (`_bagChips`, `_filterTag`; the one on as the pick); the Army grid's cells (decisions-log 198, cells since 218: the sprite standing on the card, no well; a locked type's card greyer, the picked cell's as the Bag's pick). |
| Relic slot | `ui_all.png` (1165, 13, 22×22), grey. |
| Speech bubbles (the Town's troops, decisions-log 229) | `ui_all.png` (926, 62, 20×24), white with a dark rim, its tail's tip at (9.5, 24); the grey see-through one (926, 206, 20×24) for a thought. Not sliced: drawn whole at max(2, k), a 16-px icon at (2, 1) inside. The sheet mapped first with tool/sprite_map.py (each bubble its own island, its exact box). |
| Highlight (held / target) | `ui_all.png` (1019, 107, 26×26). A Bag slot, a category segment or a filter tag under the mouse, pressed or picked (on). |
| Book slots (decisions-log 187; the Troops rows' until 198, now only `Board.drawSlot`) | `ui_all.png` square slots, 7 colours 48 px apart from y 10 (`slotSrc`: tan, white, green, blue, orange, red, purple): normal (10, y, 28×31), lit (202, y, 28×31), pressed (394, y, 28×28, drawn 3·k lower). Slices: normal l/t/r 3, b 6; lit 4/4/4/7; pressed l 6, t 6, r 5, b 5 (`slotInsets`). A Pusaka's: the tan one through `_rarityCellPaints` ("The book's sprite kit"). |
| Badge (capsule) | `ui_bars.png` dark capsule (82, 33, 12×6), slices 1, at 1 screen px per sprite px up to 27 px tall (`_capsule`); cream text. |
| Tags (decisions-log 198 and 202) | `ui_bars.png`'s capsules as light controls on a row or a section: the green one (the full HP bar's, (2, 65, 12×6), slices l/t/r 1, b 2) for the Army detail's step and a Bag action row's tag (greyed through `_greyTagPaint`, lighter under the mouse through `_lightTagPaint`); the red one beside it ((2, 33), the same slices; `_redCapsule`, `_TagLook.armed`) for a Bag row's tag armed for its second tap ("Sure?"); the outline one (98, 33) for the Army detail's shortcuts and a Bag chooser's "‹ Back" (with ui_icons.png's small white left triangle (132, 180): `_tag`'s `icon`), the dark one (82, 33) under the mouse (`_tag`, the Bag rows' `_rowTag`); the outline one with ui_icons.png's smallest white triangles ((132, 180) and (181, 180), 7×10) for the Bag's and the Army grid's pager arrow tags (`_arrowTag`, the dark one under the mouse, faded at the ends). |
| Scroll bar | `ui_bars.png` outline capsule (98, 33, 12×6) for the track, the dark one (82, 33) for the thumb, both turned a quarter, 6 px wide, slices 1 (`_capsuleBar`). |
| Tooltip frame | `ui_tooltip.png` 42×26 (tool/import_fx.py `tooltip()`, from `UI_Frames.png`'s tan pointer panels, row 0). The body (0, 0, 24×26, `_tipBody`) is the bottom-pointer panel (sheet (780, 12)) with its pointer's columns of the lip filled from a plain column (786); slices l 3, t 3, r 3, b 5. The down pointer (24, 0, 9×10, `_tipDown`; sheet (790, 33)): its top 5 rows lie over the lip, the tip (column 4) hangs 5 below. The side pointer (33, 0, 9×13, `_tipSide`; the left-pointer panel's, sheet (726, 21)): its column 6 lies on the body's left edge, the tip at column 0, rows 5–7; flipped for the right edge. All at 2×. The other six colour rows of the sheet (48 px apart) are unused. |
| Crate | `ui_all.png` (915, 4, 42×41), the wooden crate (`_crate`); slices l 13 (keeps the posts' shadow on the bars unstretched), t 12, r 11, b 13; at 2×. The message window (the Jeda panel had it until #93, the tooltips before #38). |
| HP bar | `ui_bars.png` (UI_Bars.png): empty capsule (82, 33, 12×6; the book's badge too), fill strip 10×4 at (83, 58) green for troops, (83, 42) red for normal monsters, cut to the HP ratio. Elites, high elites, mini bosses and the boss are drawn the strips' way (colour over a quarter of shade) in silver (0xD9DEE8 over 0x8C94A3) / gold / purple / orange (`_tierBar`): no HP bar is blue, since blue means MP (the owner, #62: "ini yang warna biru darahnya diganti dengan warna yang lain karena warna biru sudah melambangkan MP"; elites had the pack's blue strip (83, 50)). Drawn at 0.75 (`barK`) above the head, its bottom 22 − 4.5 units above the unit (`unitBar`). A unit with MP has one box for both (next row). |
| HP + MP box | The owner (#52): "hp dan mp di buat jadi satu box yang sama tapi dari 100% tinggi box itu 65% adalah hp dan 35% adalah mp". A unit with MP (every troop: all types have MP, it fills with regen and drops on each skill cast, units-and-combat.md; and the necromancers) has ONE capsule, 12×8 at 0.75: its rim rows kept and its middle rows stretched (drawn in three pieces), so the inside is 10×6 (`barInnerMp`). The top 65% of the inside (`barHpShare`, 3.9 px) is the HP fill as above, the bottom 35% (2.1 px) the MP fill, both cut to what is left from the left. A troop's MP is the blue strip (83, 50, 10×4); a monster's is cyan (`_monsterMp`: the pack's cyan (44, 232, 245) over its blue as the shade, as in the long blue bar's lower strip (34, 11)), set apart from the elites' HP when that was blue (#45; silver since #62): an elite healing necromancer shows silver HP over cyan MP. A hand-drawn fill's shade is its bottom quarter (the strips' 1 px of 4). The box grows upwards from where a lone HP bar ends, so it stays clear of the head; the relic icon (left; a Hero's two side by side, #91) and the level pips (right) sit at its middle, the crown just above it. The layout is `unitBar` (tested in test/hud_test.dart). It was two capsules, HP over MP (#45). |
| Summon circles | `tiny_fx_summon.png`. A raised minion of a higher tier (`summon_<tier>` bursts) is drawn through awakening's `_tint` in its tier's colour (`_summonPaints`): elite silver, high elite gold, mini boss purple. Normal ones stay plain. The circle (32×13 visible from (36, 50) of each 100 px frame, its middle (52, 56.5)) is drawn by one helper, `_groundCircle` (hero_skill_fx.dart), centred on a spot on the ground at a scale: the bursting rings', the zones', the troops' and awakening skills' circles, and a monster skill's wind-up tell. A ring over a reach wider than twice the circle (and Singularity's well at every Bangkit) is laid round it in dashes of the ring's own pixels at the units' pixel size instead (`_reachRing`, `reachDashes`; a wind-up's end to end, `closeDashes`; decisions-log 177). The wind-up tell (`_windCircle`, centred on the caster's shadow, 1.5 above its feet): ramped to red (`_circleTint`), its frames run over the wind-up; an area's reach ringed by its outline frames (0, 1) flat red; the outline's outer row (frame 1's darkest pixels, `_windRim`) in the rank's colour. |
| Wind-up marks and lanes | `ui_icons.png`, visible pixels: the big ▼ red (51, 211, 10×9) over a troop a monster's skill will land on, green (51, 195, 10×9) over a monster it will shield (`_markRed`, `_markGreen`); the big red arrows left (99, 162, 10×12) and right (147, 162, 10×12) along a lane (`_laneLeft`, `_laneRight`). The rows: arrows white (y 128), green (144), red (160); triangles white (176), green (192), red (208); in each row up, down, left, right, three sizes each. |
| Champions' landings | Shield Up's shield: `ui_icons.png` (192, 0, 16×16), the grey shield (the troop counter's and Hold Fast's), at 0.75. Brutal Swing's crescent: `fx_hit_armored_axeman.png` (10 × 64 px), ramped by brightness to white with a deep red edge (`_cleaveTint`). Blade Dance's spin: `fx_hit_greatsword_skeleton.png` (14 × 64 px) three times, turned a third of a turn apart, 2.2 × its reach tall as Circle Slash's blade; the crescent as big as a big hit ("A monster's skill"). |
| The guide's hand and ▶ | `ui_icons.png`'s cursor row: the gold hand (304, 224, 16×16, its finger up; `_icHand`) and the same hand pressed (304, 240; `_icHandDown`), a pointer tapping between them every 0.4 s at 32 px; the big red ▶ (144, 208, `_icArrowRight`) in I7's picture (lib/coach.dart). |
| Holy burst | `tiny_fx_holy.png` (made in memory, assets.md): the heal fx in white and silver, on the feet of a dark monster a troop healer smites (`holy` bursts, units-and-combat.md). Never tinted by awakening: a tinted heal on a monster would look like healing it. An awakened healer's heal is a strong blue, crimson or gold and the plain one green, so the colourless holy burst never looks like a heal. |
| Book page rule (decisions-log 218, 278; unused since 305) | `ui_book.png` (128, 124, 95×4): the book's own printed line at the bottom of its right page, the dotted flourish over each end; was 9-sliced across (ends 13 px kept, `_pageRule`) at the book's pixel size (2 at least), its light orange E69C69 recoloured to the book's edge brown BF6F4A (`_pageRulePaint`). The Army detail's separator between Release and Replace fallen until its foot became one line (decisions-log 288), then the Sell Basket page's divider between its price row and its lines until the owner took it out (decisions-log 305); the code went with it, nothing draws it now. |
| Book button icon | `ui_icons.png` (192, 16, 16×16), the red book. |
| Lives (hearts) | `ui_icons.png` 16×16: full heart (0, 0), half (16, 0: left half red), empty (32, 0: dark); their visible pixels 14×14 from (1, 1). It was the `ui_bars.png` capsule with a red / dark strip segment per life (#40). |
| HP / MP / stars (troop rows) | `ui_icons.png` 16×16: heart (0, 0); lightning bolt (144, 0), tinted blue (`_mpPaint`) for MP; full star (48, 0) and empty star (80, 0). |
| Start/Pause toggle | `ui_buttons.png` as the buttons: green (row 2) for Start, light (row 0) for Pause, orange (row 4) for Resume. The play sign (Start, Resume): `ui_icons.png` (144, 176), the big white arrow pointing right, visible 7×12 from (5, 2); the green one at (144, 192) was the Mulai ribbon's. The pause sign: `ui_icons.png`'s small white dash (`_pauseDash`) twice, stood up. |
| Off-view marker | `ui_icons.png` (144, 176), the Start/Pause toggle's play sign, drawn flipped to point left. |
| Page tabs | `ui_book_marks.png` (Book_UI.png (588, 26, 816×74), tool/import_fx.py `BOOK_MARKS`): tan short (2, 4, 20×18) shut, paper tall (35, 50, 20×21) open; both open at the bottom. Also there, unused: tan tall (35, 2), grey short / tall (82, 4) / (115, 2), paper short (2, 52), light grey short / tall (82, 52) / (115, 50). |
| Ribbons | `ui_book_marks.png`, 7 colours 48 px apart (0 red, 1 blue, 2 green, 3 orange, 4 paper, 5 tan, 6 white): closed left end (162 + 48·c, 53, 28×18), sliced l 1 / r 10: the foe skill banner's red flag, the guide pictures' orange gold flag, the banner zone's flag. Unused: the open left end (164 + 48·c, 5, 22×18, sliced l 0 / r 10: the book's old gold and wave ribbons, decisions-log 285) and the 20-tall sets at (500 + 48·c, 4, 22×20) and (498 + 48·c, 52, 28×20). |
| Foe skill banner | The plate: the tooltip body (`_tipBody`) at 2×. The portrait: the page card `ui_all.png` (1021, 13, 22×22), slices 5. The title: `ui_book_marks.png`'s closed red ribbon (162, 53, 28×18; l 1 / r 10) with `ui_icons.png`'s yellow "!" (192, 32, 16×16, `_icAlert`). The boss's moment band: `ui_all.png`'s red frame with corner studs (681, 248, 30×34, `_redPlate`; slices l 7, t 8, r 7, b 9), the first panel of the sheet's red row (its panels come in 7 colour rows 48 px apart from y 8). |
| Hero splash | `ui_ribbons.png` (UI_Ribbons.png copied whole, 304×64: six tan ribbons, three arched and three flat). The flat small one (8, 1, 64×20, `_ribbon`), sliced l 24 / r 24 (`_ribbonEnd`), whole height; the band's inside x 16..47, y 3..14. The panel is the tooltip frame's body (`_tipBody`). |
| Icons (`_ic*`, `_uiIcon`) | `ui_icons.png`, 16×16 at: coin (96, 0), sword (16, 16), gear (32, 16), crossed swords (112, 16), note (144, 64), speaker (160, 64). The pack has no flag or banner; the sword stands for the wave. |
| Volume bar | `ui_bars.png`: the empty capsule (82, 33, 12×6) 9-sliced long (slices 1, `_nine(sheet:)`), the fill strip cut to the volume: (83, 50) blue for music, (83, 58) green for effects; a faint line between notches. |
| Wave meter bar | `ui_bars.png` long empty bar (1, 15, 30×5): black inside, checkered left end. Left 5 and right 1 columns kept, the middle stretched. Fill: 1-px columns of the strips, red (2, 7, 1×3) and gold (2, 11, 1×3), stretched over the inside (3 px tall, from x 5 of the bar to its last column but one). |
| Boss bar | `ui_bars.png`: the portrait frame (256, 6, 19×19; the left one of the pack's portrait-and-bars sets, its dark inside 13×13 from (3, 3)); the HP and MP bars are the wave meter's long empty bar (1, 15, 30×5), stretched the same way, the MP one 4 px lower so they share a rim. The fills are drawn by hand (`_layerColors`, `_monsterMp`). |
| Wave meter icon | `ui_icons.png` (112, 16, 16×16), the crossed swords. |
| Troop counter icon | `ui_icons.png` (192, 0, 16×16), the grey shield (the pack has no person or helmet icon). |
| Pause sign | `ui_icons.png` (129, 40, 14×5), the small white dash (its visible pixels), drawn twice turned a quarter. The pack has no pause icon. Longer dashes with a shade at (97, 38, 14×7) and (113, 39, 14×6). |
| Troop counter caret | `ui_icons.png` small white triangles, their visible pixels: down (83, 181, 10×7), up (35, 182, 10×7). The bigger ones are at (0 / 16 / 48 / 64, 176); green and red rows below. |

## Troops drawn moving (`lib/body_look.dart`, decisions-log 307, 310)

The owner (2026-10-09): "beberapakali aku liat para army di pindahnya tidak natural langsung kaya lompat gitu" and, with
Auto Buy, "harusnya animasi jalan ini kaya slide gitu". The game moves troops in steps the eye can't follow
(formation-and-navigation.md "How the moves look"); the Board draws each troop at a body of its own (`_Body`) that
follows the game's position, and never changes the game's positions (fights, the w89 identity).

- **Following** (`_bodiesStep`, once a frame after the tick): the body moves toward the troop's game position at the
  pace the game walks it at now plus max(`bodyRun` 3 × its type's base walk speed, the gap over `bodyCatch` 0.3 s), in
  at most `bodyFrame` (a 30 fps frame, × x2/x3) of game time a frame: a troop's own walk is followed exactly, and
  whatever else moved it (a 36-unit shove, a step aside, a monster's knockback or hook) plays out over a few frames,
  a frame cut short (Board.update's 0.1 s clamp) as a short catch-up instead of a jump. The base walk, not the
  troop's own (decisions-log 310): on 3 × its own walk a booted knight's (105) shove was drawn at 315 a second and the
  Hero knight's (275) at 825, so melee troops with boots still darted aside.
- **At once** (no glide): a new troop (bought, Auto-Bought, loaded) and one back from the dead start where the game
  has them; a move of its own or a throw (`_drawnExact`: a leap, Skyfall, Phantom Rush's dashes, a charge, a Lifeline
  lift: their own looks, `Unit.move`) is drawn exactly where the game has it; a troop moved to another cell between
  waves and the one it swaps with (`_bodiesPut`), or one moved while the game stood (paused, a splash), is put there;
  so is one `bodySnap` (10 tiles; 3 until 310) or more from its body, no move the eye could follow. A dying troop
  dies where it is drawn. Another game coming in starts every body afresh. Monsters have no body: they are drawn
  where the game has them.
- **Everything follows the body:** the render sees every troop at it (`_bodiesOn` / `_bodiesOff` round `render`), so
  its shadow, rings, guards and Holy Shield's bubble, bars, relic and Pusaka marks, cast labels, plates (hover and
  pinned), the Hero's spotlight and the off-view marker go with it; a tap, pointing and loot dropped on a troop find it
  there (`_unitAt`, `_troopNear` through `_at`). A troop's plain shot is drawn leaving its drawn body and closing onto
  the game's path by its target (`_shotFrom`); beams, line shots and special shots keep the game's positions.
- **Walking** (`_unit`): a troop whose body moved at `bodyWalkAt` (a quarter of its walk speed) or more plays its walk
  strip, and for `bodyWalkHold` 0.12 s after: before a skill strip, an attack, a flinch and idle. Dying, a heap of bones,
  a stun, rising, a skill's wind-up (`Unit.troopWind`: the troop stands for it), a brace and a carry keep their own; a
  troop attacking in place moves no body, so it attacks as before.
- **Its stride** (`_strideFrame`): the walk strip's frame comes from the body's own phase, advanced at 10 frames a second
  × its body's speed over its type's base walk speed (`troopTypes`), 1× to `bodyStride` 6× (3× until decisions-log
  310): a knight with boots (105 on the owner's save, base 24) or a troop catching up steps quicker instead of
  skating, and a change of pace never skips a frame. 6× is a strip frame every frame of a 60 fps screen, and no troop
  walks faster since decisions-log 311 (`bodyStride` is `walkMost`, units-and-combat.md "The walk cap"): the Hero
  knight's 275 (11.5× its base), which slid its feet about 2×, is 144. Only a body closing a gap on top of its walk
  goes faster. A monster's walk and a charge's gallop are as before.
- `Board.drawnAt(u)` and `Board.stripOf(u)` ("walk", "idle", "attack", "attack2", ...) are for tests
  (test/troop_motion_test.dart).

## Cursor and feedback

- **Buttons answer the pointer** (`lib/button_fx.dart`; the owner, #54: "ui button harusnya ada effect
  ketika di hover dan di click", then, showing the pack's three looks, "kalau button ini animationnya [3
  states] itu state biasa, di hover dan di press"). One rule, `buttonLook(rect, enabled, hover, press,
  now)`: disabled shows nothing; a press on it shows as `pressLook` says; else the mouse on it lights it.
  `Board._look` feeds it the mouse (`_mouse`, hover events only, so touch never hovers) and the last press
  (`_press`, a `ButtonPress`: where the pointer went down, when, and when it came up; cleared when the tap
  turns into a drag). Nothing lights while something is dragged.
  - The press, over time (`pressLook`): pushed in while held and `pressMin` 0.08 s at least (so a quick
    click shows too), then the hover look for `pressBack` 0.08 s, the face coming back up a pixel at a
    time; then normal, or lit if the mouse is still on it. Touch gets the same.
  - `_button` (every labelled button: welcome, scoreboard, Settings −/+ and Main Menu, x2, the
    book button, +Room, Auto, the name panel's OK, Back) and the Start/Pause toggle draw
    the pack's own three looks (`ui_buttons.png`, `_btnSrc`): normal; hover, lighter, its face 1 sprite px
    lower over a thin shade; pressed, darker, 2 px lower, no shade. All three end on the same bottom row.
    The label (and the pause sign, the book icon, the play sign) moves down with the face (`_btnFrame`
    returns how far: k or 2·k). Disabled buttons stay the white one's normal look.
  - The Start/Pause toggle: the same, its Start's pulse being the hover look.
  - A shut page tab: comes 2 rows further out under the mouse (it acts on the way down, so it is the open
    tab by the time it could look pressed).
  - The book's rows that act on a tap, a troop row (buys on the way up) and a Tas page's type row (gives the
    item): the lit card (`_frameLit`) under the mouse, and while pressed the lit card with its paper a shade
    darker (`_rowCard`). A row that can't act, a troop you can't afford or a type that can't take the item,
    shows neither.
  - Buttons still act on the way down (`onTapDown` runs `_hits`), the troop rows on the way up, as before;
    the pushed-in look lasts until the pointer comes up (and `pressMin` at least).
  - **Click:** every `_hits` press (buttons, tabs, the Start/Pause toggle, the Tas type rows, the volume notches)
    plays `Sfx.click`, a 45 ms soft wooden tock synthesised by `tool/gen_sfx.py` (at 0.35 of the effects
    volume). The troop rows keep their own sounds (placing, or the error buzz).
- **Cursor** (#72; the owner: "cursor juga ada animationnya ketika click"): the system cursor is hidden
  (`GameWidget(mouseCursor: SystemMouseCursors.none)`). `_cursor` draws the pack's pointer
  (`ui_icons.png` y 224, 16×16 cells, at 2×), desktop only (touch has no `_mouse`, so none shows):
  - the arrow (0, 224), hotspot (4, 2), the tip, which stays put in its press frames;
  - a click presses it (`cursorFrame`, from the same `_press`): its first press frame (16, 224, the tail
    tucked in) for `cursorStep` 0.05 s, then the second (32, 224, no tail) while the button is held (both
    at least), and back through the first for 0.05 s when it comes up;
  - the hand (48, 224), hotspot (6, 2), over anything tappable or draggable and while dragging (its hover
    state). The pack has no pressed hand, so it dips a sprite pixel for as long as the arrow would show a
    press frame (not while dragging).
- **Clicks:** show `ui_click.png` sparks (4 frames of 16px, 12 fps).
- **Loading:** `_Loading` shows `ui_loading.png` row 0 (16 frames of 16px) while `onLoad` runs.
- **On the field:** only the relic icon left of the bar (a Hero's second one just left of the first, #91), its type's
  Pusaka's icon left of those and its ring under its feet ("The Pusaka in battle"), and,
  for an awakened type, its level pips right of it. The owner found upgrade rows over every troop too crowded; they show on the cards.
- **Skills** (lib/skills.dart, a part of main.dart; the rules in units-and-combat.md):
  - Every troop shows its MP over its head in the bottom 35% of its HP bar's box (blue; the HP + MP box
    below): it fills as MP comes back and drops when the troop casts, and a troop healer's with each heal (6 MP,
    decisions-log 297).
  - A cast pops the skill's name ("Hold Fast", "Arrow Rain", ...) over the caster's bars: pale blue with
    the dark outline, 6 × the field's scale (16–26 px), rising 8 units and fading over its last 30% of
    `_popTime` 1.2 s (game clock: it waits while paused). Another game coming in (Ulang, a save) drops the
    last one's names, gold pops and hit bursts, which run on its clock (#74). A name that would cover one already drawn
    goes up above it. `Board.update` drains `Game.casts` into `_pops`; a caster that dies takes its name
    with it.
  - **Once a wave** (decisions-log 298: the troops cast every few seconds): a troop's #10 skill, its awakening skill and
    a Hero's own skill each pop their name on its first cast of a wave only (`FirstCasts`, lib/cut_ins.dart, keyed by
    the caster and the kind of pop; a new wave or another game starts it afresh). The skill's own look (its ring,
    beam or zone, below) shows on every cast. `Game.casts` and the other cast lists still get every cast.
  - **"No MP"** (`Words.noMp`, decisions-log 297): a troop healer a heal found short of MP (`Game.noMp`) pops "No MP"
    over its bars like a skill's name, in the MP bar's blue, lighter (`_noMpPop` #7FB8FF, `_PopKind.noMp`), once
    until it has the MP again (`Unit.dry`; units-and-combat.md "Healers").
  - A guarded unit stands in a ring at its feet (16 × 7 in the sprites' pixels: "The field's rings in pixels"),
    pulsing, fading out over the guard's last 0.5 s (`_guardRing`), in its guard's colour (`Unit.guardLook`, `_ringColors`): Hold Fast's steel blue, Holy
    Shield's white, a monster skill's own, else the pale blue (a Hero skill's guard).
  - A stunned monster (Crushing Blow) freezes on its hurt strip's first frame.
  - A cast plays its skill strip (decisions-log 299; which, and when: units-and-combat.md "Skill strips"):
    `_unit` draws `Unit.skillAnim`'s frame (`_skillStrip`, `skillStripFrame`) after dying, a heap of bones, a stun,
    rising and a troop's walk while its drawn body moves ("Troops drawn moving"; not during the wind-up), before an
    attack, a flinch, a brace and walking or idle; in the unit's rank or awakening colours and
    outline like its other strips. Not while a move carries it (a leap, a charge, a knockback: drawn as before) nor
    as a slime (Slime Hex). An attack that began with the skill (between its cast and its blow: Volley's arrows, a
    Brutal Swing, a blow in the cast's tick) doesn't replay the attack strip after it (`_skillSwing`); a later one does
    (Blade Dance's and Whirlwind's later cuts).
  - A skill's bigger hit (bursts ending in `_big`, `_bigFx`) is drawn `_bigScale` 1.4× as big. Arcane Blast's is its
    own: the ice star's flash and streak (below).
  - The attacks show their type's hit on each foe, Healing Prayer a `heal` on each troop it heals.
  - **Each troop skill's own look** (#81, decisions-log 117; what the cast leaves in the game and for how long:
    units-and-combat.md "Troop skills"). Each has a look and a colour of its own, none the Hero skills' gold
    nor the monsters' red, cut from the packs' sheets (decisions-log 173; until then they were drawn in code), each
    frame chosen by how far the look is through its time (`_sheetAt`) and drawn without smoothing in its colour
    (`_sheetPaint`: a `_tint`, or a `_dye` for a white sheet). The ground parts lie under the units (`_skillGround`,
    from `_groundRings`), the parts that stand up over them and over the hit bursts (`_skillsAbove`, so a sweep
    isn't lost under the bursts of the blows it deals):
    - **Hold Fast** (steel blue `_braceBlue` #7FB2E5): the ground circle's ring (`tiny_fx_summon.png` frame 1)
      closes in on the soldier's feet from twice its 12 radius and fades; `ui_icons.png`'s steel shield (192, 0) at
      half its pixels (8 units, as the Hero's crown) flashes before its body the way it faces, popping in from
      1.5× its size, faded out by the end (0.5 s). Its guard ring is steel blue for the 3 s the guard lasts.
    - **Circle Slash** (pale blue `_bladeGlow` #9FD8FF): `fx_hit_greatsword_skeleton.png`'s sweeping slash (14
      frames) at the knight's waist, a little ahead of it the way it faces, its frame 2.2 × its reach (20) tall,
      dyed pale blue (0.4 s).
    - **Rampage** (embers `_ember` #FF7A2E): an ember ring (the ground circle's) over 18 and `fx_hit_werebear.png`'s
      bits bursting off the swordsman's body in ember (0.5 s). While Rampage lasts (4 s) `fx_hit_orc.png`'s flames
      (its frames 1, 2, 3, 2 over and over, `_rageFlames`, at the hit bursts' size) rise behind its body from its
      feet in ember (`_rageGlow`), and its body has awakening's 1-unit outline in ember, flickering (`_rageLine`, over
      an awakened one's own); both fade out over the last 0.5 s.
    - **Arrow Rain** (`ZoneLook.volley`): the ground circle's ring (its front half, then the whole ring) over its
      targets' ground, tinted the troops' pale blue (`_troopPop` #BFE6FF, at 80%), and the archer's own arrows (in its awakening's colour) falling onto it one after another over
      the first half of its 0.8 s, then standing in the ground fading out (`_volleyArrows`; Bone Rain's
      `_fallingArrow`). Its two real arrows fly from the archer as ordinary shots.
    - **Piercing Thrust** (`BeamLook.thrust`; teal `_thrustGlow` #6FE8D8): `fx_hit_lancer.png`'s thrust streak at
      body height, its run across its 9 frames (`_thrustRun`, (3, 19) to (61, 46) of the 64 px frame) laid along the
      line from the lancer through its target to the end of its reach (`pierce.depth` past it), dyed teal (0.3 s,
      `_thrustBeam`).
    - **Healing Prayer** (mint `_mint` #8CFFB4): a mint ring over its reach round the most hurt troop; on each troop
      it heals the pack's heal (`tiny_fx_heal.png`, its 4 frames over 0.8 s, slower than a plain heal) in mint at its
      feet, fading over its second half.
    - **Crushing Blow** (dust `_dust` #C8A878): `fx_hit_armored_orc.png`'s ring of dust bits (from its 4th frame; the
      first three are a solid puff) bursts out over its reach on the ground round the axeman's feet, under the
      units, with the dust ring over it (0.8 s).
    - **Arcane Blast** (violet `_violet` #B46CFF, its ring): its shot is the Tiny RPG pack's spinning ice star
      (`tiny_fx_wizard_shards.png` frames 2-5 at the pack's 10 fps and size, 26×32 units, mirrored to face its
      flight); where it lands the star's white flash and a streak (frames 6-9, 0.4 s) and a violet ring over the
      splash (0.6 s). Its cast strip's staff glows in the star's blues (lib/wizard_fx.dart, decisions-log 313;
      units-and-combat.md "The wizard's magic").
    - **Holy Shield** (white `_holyWhite` #FFFAEB): a white ring over its reach (3 tiles, so in dashes at the units'
      pixel size: "Rings bursting out" below); round each troop it
      shields `fx_hit_knight_templar.png`'s ring (the templar's own hit, from its 3rd frame; the first two are a
      filled disc) in white, its frame 2.8 × 9 tall, fading over its second half (0.8 s). Its guard rings are white
      for the 4 s the guard lasts. A troop keeping a stronger guard (Hold Fast) gets none and keeps its steel-blue
      ring.
    - The `upgrade` burst (the items' sword-and-plus) no longer shows on a troop skill's caster.
  - **An awakening skill** (#88; units-and-combat.md "Awakening skills") pops like a #10 skill, in the same pale
    blue, its name with the level's numeral ("Disarm", "Disarm II", "Disarm III"; `Game.awakenCasts`, drained in
    `_drainCasts` as `_PopKind.awaken`). When a type awakens, each of its living troops pops the new name once. Its
    colours are all in one table, `awakenColors` (skills.dart: each skill's main colour and its second), apart from
    the #10 skills', the Hero skills' gold and the monsters' red: Disarm iron / white-hot, Unbroken deep cyan / pale
    cyan, Phantom Rush magenta, Spellbreaker cool silver / graphite, Impale chartreuse / steel, Lifeline mint /
    white, Skyfall ash / white-hot, Singularity indigo / white, Consecration rose / pale rose (a colour a const needs,
    such as a `_ringColors` entry, is a const of its own: `_iron`, `_rushMagenta`, `_ash`, `_impaleLime`, `_silver`,
    `_indigo`). A new `RingLook` needs its `_ringColors` entry (hero_skill_fx.dart), or the ground rings fail on it.
    The nine:
    Like the troops' skills' looks they are cut from the packs' sheets (decisions-log 173), each frame by how far the
    look is through its time (`_sheetAt`), drawn unsmoothed in its colour (`_sheetPaint`). A burst whose first frames
    are a solid shape over the body starts later in its strip (`first`), so the body stays seen.
    - **Disarm** (`RingLook.shards`, 0.5 s, `Ring.over` the foe; no ground ring): `fx_hit_skeleton.png`'s white
      shards in iron (`_iron` #4B5563, a `_tint`) burst from the foe's weapon arm (its side facing the soldier, at body
      height), at the hit bursts' size. The blow shows the soldier's big hit; the weaken it leaves is the purple weaken
      ring for its 6 s.
    - **Unbroken** (`RingLook.unchain`, 0.6 s, `Ring.over` the knight): a deep cyan ring (`_unbrokenCyan`
      #1FB8E0, the ground circle's) at its feet, and `fx_hit_armored_skeleton.png`'s ring of spikes (from its 4th
      frame) bursting round it at knee height, dyed cyan, its frame 2.4 × 14 tall. Each troop it heals shows the
      `heal` burst.
    - **Consecration** (`ZoneLook.consecrate`, its zone's 4–5 s; `_consecration`, drawn with its alpha in its
      paints, no layer): the ground circle over its radius, tinted rose (`_rose` #FF8FC4, `_roseTint`), drawing
      itself (its front half, then the whole ring) and then its star turning slowly (frames 2–6 at 5 a second,
      `_circleFrame`), and the pack's heal (`tiny_fx_heal.png`, its crosses rising off a ground arc) in rose on spots
      of its own on it, one for every 12 units of radius (2 at least), each 1.2 s on a spot and then on a new one,
      taking turns (`_zoneTurns`: the spots go round by the golden angle within 60% of the radius, the same every
      time); it comes in over 0.15 s and fades over its last 0.5 s. Each pulse shows the templar's hit on each foe
      on it, the `holy` burst on an undead one.
    - **Phantom Rush** (magenta `_rushMagenta` #FF4FD8): each dash leaves `fx_hit_soldier.png`'s slash (its first
      three frames, which slash the same way) laid at body height from where it set off to where it cuts, dyed
      magenta (`BeamLook.rush`, `_rushBeam` through `_streak`, 0.5 s). While it dashes, two afterimages of the
      swordsman in flat magenta (`_afterimages`, its walk strip through a `srcIn` filter) trail it at 0.3 and 0.6 of
      the dash behind, at 50% and 28% (none within 1.5 px of the body: the way home and a dash's end). From its first
      dash until it is home the swordsman is a phantom that no blow touches (units-and-combat.md, decisions-log 320),
      and its body shows it the whole time: its own frame at 55% (`_phantomBody`) under the same frame in flat magenta
      at 40% (`_phantomWash`, the afterimages' `_rushFilter`), so it reads as a see-through magenta ghost. Each cut
      slashes `fx_hit_swordsman.png`'s X (from its 4th frame) across the foe's body in magenta (`RingLook.crossCut`, `Ring.over` the foe, 0.3 s; no ground ring), with the swordsman's
      hit burst.
    - **Skyfall** (ash `_ash` #D8D2C4): while the axeman is in the air, its own ground shadow
      (`tiny_armored_axeman_shadow.png`) lies where it will land, darkening as it falls and growing with the radius it
      will hit (40% of it, then all) in whole scales up to twice its size: 15 units across, then 30 (`_landingShadows`,
      from its `Carry`; decisions-log 177: spread over the whole radius it was 3.2× the units' pixels). Landing (`RingLook.crater`, a `Ring` there, 0.8 s):
      Crushing Blow's ring of bits (`fx_hit_armored_orc.png` from its 4th frame) dyed ash bursts out over the radius
      on the ground, under the units, with the ash ring over it; the axeman's big hit shows there, its hit on each
      foe, and the plain guard ring for the guard's 3 s.
    - **Lifeline** (the priest's mint `_mint`, white): a mint ribbon from the priest to each troop it lifts, at body
      height and in the air with the troop, waving gently round a white core, white motes flowing along it to the
      priest (`BeamLook.tether`, `Beam.between`, `_tetherBeam`, 0.7 s; in over 0.1 s, out over its last 0.3 s). The
      troop hops there over its ground shadow like a leap. As it lands mended, the `heal` burst, and the pack's heal
      again in mint at its feet (`RingLook.bloom`, `Ring.over` it, 0.6 s).
    - **Impale** (chartreuse `_impaleLime` #D4FF3F, steel `_shaftSteel` #E8EEF2): the lunge is the lancer's own thrust
      streak (`fx_hit_lancer.png`, as Piercing Thrust's) laid at body height from the lancer to the foe, dyed
      chartreuse (`BeamLook.lunge`, `_lungeBeam`, 0.3 s), with the lancer's big hit on the foe. A break adds
      `fx_hit_skeleton.png`'s white shards at the sheet's own pixels (64 units) bursting off the foe's body, dyed
      chartreuse (`RingLook.shatter`, a `Ring` there, 0.5 s; no ground ring). A pinned foe shows
      its ring in chartreuse among the effect rings, dashed (ten dashes turning slowly), and the lance stuck slanting
      through it, its butt low on the lancer's side and its chartreuse head high on the other, drawn under the body
      so the body hides its middle (`_impaleRing`).
    - **Spellbreaker** (cool silver `_silver` #D6E4FF): the arrow is the archer's, 1.3× as long, recoloured silver
      (`ShotLook.silver`). Where it lands, a rune circle on the ground: the ground circle with its star
      (`tiny_fx_summon.png` frames 2–6, `_groundCircle`) over the spread it strips (at least 10 across at Bangkit 1),
      tinted silver, fading (`RingLook.dispel`, 0.5 s). The rings of the buffs it strips are gone on the same frame.
    - **Singularity** (indigo `_indigo` #5A4FCF, white): the well on the ground (`ZoneLook.singularity`,
      `_singularityWell`, drawn with its alpha in its paints, no layer), all at the units' pixel size (decisions-log
      177; the ground circle stretched over its radius was 2–3× the units' pixels and read as noise over the fight):
      - its radius: the ground circle's ring in indigo laid round it in dashes (`_reachRing`; its front half for the
        first 0.1 s), turning slowly (`_wellTurn`, 0.15 turns a second);
      - the pull: two more rings of dashes drawn in from the radius to the core, faster as they near it (the radius
        going as 1 − q² over `_wellPullTime`, 0.9 s), turning half a turn more on the way, fading in and out, taking
        turns (`_wellPulls`);
      - its core: the ground circle itself at its own size (32 units across, `_wellCore` its half), drawing itself
        and then its star churning fast (frames 2–6 at 20 a second, `_circleFrame`).
      It comes in over 0.15 s and goes in its last 0.2 s. As it closes, its ring of dashes collapses from the radius
      into the core, faster as it goes and turning, then `fx_hit_wizard.png`'s burst plays at the core over the last
      30%, dyed indigo (`RingLook.implode`, a `Ring`, 0.4 s), with the wizard's big hit at the core and its hit on
      each foe.
  - **A Hero's own skill** (#48; units-and-combat.md, "Hero skills"): its English title pops the same way
    but in the crown's gold (`_heroPop`) and `_heroPopScale` 1.25× as big (`Game.heroCasts`, drained with
    `casts` in `_drainCasts`, where #51's cut-in hooks in), with the gold `upgrade` burst on the Hero.
    - Its effects: a troop under one shows small 5-unit icons in a row just above its HP + MP box (above the
      crown for a Hero; `_statusMarks`, the map `_effectMarks`): gloves = faster, sword = more damage, bow =
      range, fang = lifesteal, thorns = reflect, potion = healing, guard = a block or veil (or a Pusaka's shield,
      its ward: Watch Shield, Bone Buckler), shield = a cap, MP bolt = mana shield, coin = Plunder, fury = holding
      its ground, heart = a link or Giant's Rage, sword on a knight = its duel. A monster under one shows coloured rings at its feet, one inside another, pulsing
      like a guard's (`_statusRings`, the map `_effectRings`; in the sprites' pixels, "The field's rings in pixels"): ice blue slowed, purple cursed, red marked,
      orange taunted (a duel's foe too), crimson bleeding; and a monster skill's: amber rallied (War Shout),
      steel grey shielded (Shield Up), mint sped up (`Status.swift`: Howl, Second Wind, Iron March), blue
      rending (Soul Rend), dark crimson lifestealing (Bloodrage), teal soaking (Unholy Ward); an awakening skill's:
      chartreuse pinned (Impale, `Status.impaled`, dashed, with its lance: above). Pale cream is a troop dazed by a
      Screech (`Status.daze`, no icon, so a ring).
    - Two units tied by an effect have a thin pulsing line between their feet, under every sprite
      (`_statusLines`, the map `_effectLines`): gold from a knight to its duel's foe, pale gold from a troop
      to the knight sharing its wounds.
    - A troop in Giant's Rage is drawn `giantRageK.size` 1.3× as big, grown from its feet (`_unit`; its bars
      and marks stay where they are).
    - Plunder's extra gold (`Game.goldPops`) floats up as "+N" after a coin, in gold, over `_popTime`.
  - **A monster's skill** (#59; units-and-combat.md, "Monster skills"): as it begins the wind-up its English
    title pops over it like a troop's, in red (`_monsterPop`, `_PopKind.monster`; `Game.monsterCasts`, drained
    in `_drainCasts`). Until the cast lands its **tell** shows (decisions-log 171; `windTells`, `WindTell`,
    lib/skills.dart), so the troops' holds have something to answer. Every part of it comes from the sheets in
    assets/ (the owner, 2026-10-02: "effect buatanmu coba di ganti pakai asset yang ada karna jadi nga masuk sama
    gamenya"); only a moment's red edges are drawn in code (below). It was a red ring drawn in code at its feet,
    tightening (`_windRing`). A high elite's and up also show a banner with its title and rank ("A foe's skill
    banner" above).
    - **The circle** (`_windTells`, `_windCircle`, on the ground under everyone, after the bursting rings):
      `tiny_fx_summon.png`, the circle the necromancers' minions rise in (and the frost field's), at its feet at the
      units' own scale (32 units across, 1 a sprite px). Its 7 frames run once over the wind-up (`_windDone`: the
      circle drawn, then filled in), recoloured by brightness onto a ramp through red (`_circleTint`, `_ramp`: the
      sheet's darker fill green at 55% of `_monsterPop`, its main green at all of it, so the pattern stays and reads
      red on the ground (chosen on the old tan road); Mass Mend's through the drain's green 4CE06A). Its alpha rises from 0.7 to 1
      (`windTellAlpha`). Once drawn, its outline's outer row (the outline frame's darkest pixels, `_windRim`) is in the
      caster's rank colour (`_tierBar`: gold, purple, orange), a mini boss's or boss's pulsing; Bulwark's in the
      taunt's orange FF8A30, Curse of Frailty's in the curse's dark 2B2233 (`_windColors`).
      - An area skill (`WindTell.area`) also rings its reach (`windReachOf`): the circle's outline frames only (the
        half drawn, then the whole) as wide as the reach, flat in its colour so it stands out on the ground, its outer
        row in the rank's colour. A reach over twice the circle's size (Howl, Earthshaker, Roar, Curse of Frailty and
        Last Rites 3 tiles, Death Nova 2.5) is ringed at the units' pixel size instead (`_reachRing`, decisions-log
        177): the ring's own pixels in 4-unit dashes laid end to end round it (`closeDashes`, `_windDashStep` 4), so it
        reads as one solid ring, a warning; the rank's outer row on the same dashes, the alpha ramp and the pulse as
        before. A reach under 1.4 times the circle (`_windRingFrom`: Brutal Swing's 14) gets the
        filled circle that wide instead. The area skills: War Shout, Brutal Swing (the monster's own reach), Bulwark,
        Blade Dance, Mass Mend, Curse of Frailty, Screech, Bone Shield, Ground Slam, Howl, Earthshaker, Roar, Death
        Nova, Last Rites.
    - **The marks** (`WindTell.target`, `_windMarks`, over everyone): `ui_icons.png`'s big red ▼ at 0.75 a sprite
      px (the bars' `barK`) over each troop the skill will land on, just above its bars (a Hero's crown), bobbing
      1.5 units: the ones
      `Game.windTargetsOf(u)` names, the landing's own target queries, read only and without dice, so drawing
      them changes nothing. Volley's arrows' troops (3; a mini boss's 5), Sticky Glob, Swoop, Pounce, Maul,
      Headbutt, Barbed Arrow, Bone Bash, Spear Throw, Soul Drain, Skull Crusher. Unholy Ward marks the monster it
      will shield with the green ▼.
    - **The lanes** (`WindTell.lane`, `_windLane`, over everyone, so the troops in the way don't hide them):
      `ui_icons.png`'s big red arrows along the skill's way, one every 12 units (`_laneStep`), 0.8 a sprite pixel and
      squashed to 0.6 of their height,
      lighting up one after another out from the monster: Trample's to the troop it will charge, Grave Wave's
      `graveWaveK.length` towards the troop its line runs at (none: towards the base).
    - **At its feet only** (`WindTell.self`): a skill on itself (Shield Up, Frenzy, Bloodrage, Soul Rend, Thick
      Hide, Iron March, Second Wind) or one that calls monsters in or covers its own ground (Slime Tide, Swarm,
      Grave Call, Rally, Bone Rain). Frenzy and Thick Hide have no wind-up, so theirs shows for a frame. Reassemble
      and Split never wind up: no tell (`WindTell.none`).
    - **A boss's moment** also flashes the field's edges red (`_momentVignette`): FF4A3D at 0.45, fading over
      `momentVignette.time` 0.4 s of game time, 12% of the field's shorter side deep, over the field and under
      the HUD (`Board._momentAt`, set in `_drainCasts`). A gradient drawn in code: no sheet holds a screen's edge.
    - **The boss bars** ("Boss bars" above): a winding mini boss's or boss's portrait flashes red (its idle frame
      again over it, flat in `_monsterPop`, pulsing 0.35 to 0.7, `_windFlash`); a compact bar's name turns red.
    - **The landing** (decisions-log 175): the five skills whose landing read weakest land with a look of their own,
      left in the game as a ring (`Game.rings`; how long: `landingLook`, monster_skills.dart) and cut from the sheets
      in assets/ like the troops' skills' looks (`_sheetAt`, `_sheetPaint`, unsmoothed). Brutal Swing's, Blade Dance's
      and Shield Up's stand over everyone and the hit bursts (`_skillsAbove`; nothing on the ground, `_skillGround`):
      - **Volley:** the skeleton archer's hit burst at it as it looses, and a red ring (the ground circle's ring,
        `RingLook.red`, radius `landingLook.mark` 16 as a Rally's, 0.6 s) under each troop its arrows go to
        (`Ring.over`, so it stays under a troop that moves). The arrows fly as ordinary arrows.
      - **Shield Up** (`RingLook.ward`, `Ring.over` each monster its ward covers, for the ward's 4 s):
        `ui_icons.png`'s steel shield (192, 0) at the bars' 0.75 a sprite px (`_windMarkK`: 12 units) before the
        armored skeleton's body the way it faces (at the troops), popping in from 1.5× its size over `_wardPop` 0.15 s,
        pulsing gently and fading over its last 0.5 s. It shows only while `Status.shotWard` is on the monster, and a
        second Shield Up on it replaces it (one shield, never two). Hold Fast's flash is the same shield, half the size,
        on a troop for 0.5 s.
      - **Brutal Swing** (`RingLook.cleave`, `Ring.over` the elite orc, `landingLook.cleave` 0.4 s):
        `fx_hit_armored_axeman.png`'s crescent (its 10 frames) sweeping at its waist half its reach ahead of it the way
        it faces, so over the troops it strikes, as big as the big hits it lands (`_bigScale` × 32 = 44.8 units),
        recoloured by brightness (`_cleaveTint`, `_ramp`): its dark outline deep red 9A0F18, its reds and oranges near
        white, so a white blade with a red edge. Each troop it strikes shows the type's big hit (`hit_elite_orc_big`:
        the `big` flag on `_skillBlow`, which only swaps the burst). Dyed the monsters' red, or drawn over the orc at
        Circle Slash's 2.2 × reach, it read as one more red burst among the elite orc's red claw marks.
      - **Bulwark:** the armored orc's big hit on it and an orange ring (`RingLook.orange`, the taunt's FF8A30)
        bursting out to its 2-tile reach (0.6 s); its guard ring in orange as before.
      - **Blade Dance** (`RingLook.spin`, `Ring.over` the greatsword skeleton, `landingLook.spin` 0.3 s each cut, so a
        mini boss's 4 cuts spin 4 times): its own slash (`fx_hit_greatsword_skeleton.png`, its 14 frames over the spin)
        three times round its body, a third of a turn apart and turning a third of a turn together, white as the sheet
        is, its frame 2.2 × its 1.5-tile reach tall (`_sweepK`, Circle Slash's rule: 53 units; `_bladeSpin`). A
        stunned or shoved one stops spinning with its cuts. Its blows show the plain hit, as before.
    - What else it does shows through the existing looks: the type's hit on each troop a blow lands on (Blade Dance's
      every cut with the attack strip again), War Shout's bigger burst on the orc, a red ring bursting out to its reach
      (`Game.rings`) and an amber ring (`Status.might`) under each monster it rallied, Shield Up's steel grey ring
      (`Status.shotWard`), Bulwark's guard ring on the armored orc in orange (`Unit.guardLook`), Mass Mend's `heal` on
      each monster.
    - Branch 2a's (units-and-combat.md, "Branch 2a"): Sticky Glob's glob (`ShotLook.glob`) and the troop's
      slow ring after it (a haste that slows shows no gloves over the troop, `_statusMarks`); Swoop's and
      Pounce's leap as a hop, the bat or werewolf walking in the air over its shadow, then the type's big hit
      on the troop; Trample's gallop (the walk strip at `chargeK.speed` 3× the rate) with the hooves' dust on
      each troop it passes, and a stunned troop frozen on its hurt strip's first frame.
    - Branch 2b's: Maul's big hit on the troop and its slide back; Curse of Frailty the necromancer's hit on
      each cursed troop and the `vulnerable` ring at its feet for 5 s.
    - A skeleton that reassembles (branch 2b) lies as a heap of bones for its 2 s: its death strip runs to the
      middle frame and back as it stands again (`_unit`, `reassembleK.down`), its bars still over it.
    - The mini bosses' skills and the boss's moments (branch 3, lib/boss_skills.dart) pop and wind up the same
      way, and show as:
      - a ring bursting out (`Game.rings`): pale for Screech (2 tiles), dust for Ground Slam (1.5), grey for
        Howl and dark for Roar (3 tiles, over `wideRingTime` 0.8 s), dark for Death Nova (2.5), brown for
        Earthshaker (3, 0.8 s), and a red one round each orc a Rally drives;
      - a guard ring in its skill's colour (`Unit.guardLook`): bone on the monster a Bone Shield covers, brown
        on a werebear's Thick Hide, steel on an Iron March;
      - the type's hit burst, big, on the troop it strikes (Headbutt, Bone Bash, Skull Crusher) or on itself
        (Ground Slam, Rally, Earthshaker, Death Nova), and the plain `hit_<type>` on each troop a blow lands on;
      - Split's, Swarm's and Grave Call's newcomers rise in the summon circle (`summon`, a tier's own colour
        for a raised elite or higher);
      - Barbed Arrow's arrow as an ordinary arrow (its bleed as a crimson ring), Spear Throw's `spear` shot,
        Grave Wave's `long` line shot, Soul Drain's green drain beam (`BeamLook.drain`), Slime Tide's slime
        puddle (`ZoneLook.slime`), Bone Rain's falling arrows (`ZoneLook.arrowRain`);
      - Frenzy's `upgrade` burst, Second Wind's and Unholy Ward's and Last Rites' `heal`.
    - The movement skills (units-and-combat.md, "Forced movement"; lib/hero_move_fx.dart):
      - a leap is a hop: the body, its bars and crown rise on an arc (`hopHeight` 10 at the middle,
        `Move.liftAt`) and walk in the air, while the shadow and the rings stay on the ground;
      - a charge gallops: the walk strip at `chargeK.speed` 3× the rate;
      - a knockback or a drag slides the unit; a stunned one freezes as under Crushing Blow;
      - Chain Hook's chain while it drags (`_chain`): 1.2-wide links from the axeman's hand to the
        monster's middle, dark and lighter by turns;
      - Spear Wall's brace: the lancer holds its attack strip at full thrust (its middle frame) between its
        blows, over a steady pale steel ring (`_braceRing`, `_braceColor`; 18 × 8 in the sprites' pixels) at its
        feet that fades out over its last 0.5 s;
      - their blows show the Hero type's big hit (Chain Hook the axeman's plain one, Spear Wall's the
        lancer's), and a charge's passing blows the `hit_orc_rider` dust.
    - Resurrection says "<name> rises again!" in the message window (`Game.risen`, drained in
      `_drainCasts`; not for one fallen again by then, so an army wiped keeps its own message, decisions-log 322), the
      one Hero skill that speaks; the troop rises in the gold summon circle
      (`awakeFx('summon', 3)`) with a `holy` burst, its death strip played backwards over `riseTime` (`_unit`:
      only `_summoners` have a summon strip).
    - A monster under Slime Hex is drawn with the slime's strips (`tiny_slime_*`), dying one too, with a
      `summon` puff as it turns and as it turns back.
- **Special shots and ground objects** (lib/hero_skill_fx.dart, a part of main.dart; the rules:
  units-and-combat.md, "Special shots and ground objects"). #48's Hero skills use them: Snipe `trail`,
  Crippling Shot `ice`, Piercing Shot `long`, Javelin `spear`, Axe Throw `spin`, Chain Lightning the beam,
  Frost Storm and War Banner their zones:
  - A shot or line shot is drawn by its `ShotLook` (`_specialShot`), from `tiny_arrow_<type>.png` (the
    archer's for a type without one), pointing the way it flies:
    - `plain`: the arrow as it is;
    - `trail`: 1.5× as big;
    - `ice`: tinted ice blue (#9BE3FF, awakening's `_tint`);
    - `long`: 1.6× as long;
    - `spear`: 1.6× as long, tinted steel grey (#6E7A88);
    - `spin`: frame 2 of the thrower's `fx_hit_<type>.png`, 22 units across, turning 3 times a second;
    - `glob` (#59, a slime's): no arrow but the slime's own hit burst's blob, `fx_hit_slime.png`'s first two frames
      by turns at the burst's 15 fps, at the hit bursts' size (`_burstSize` 32: about 13 × 12 units), facing the way
      it flies (decisions-log 173: the drawn blob went).

    All but `ice`, `spear` and `glob` keep an awakened type's colour (`_awakeFx`). A line shot is drawn 6 units above its path
    (`_lineShots`). No shot draws a trail (the white trails of `trail`, `long` and `silver` went with decisions-log 173).
  - The wizard's shot is the Tiny RPG pack's fireball (lib/wizard_fx.dart, decisions-log 313; units-and-combat.md
    "The wizard's magic"): `tiny_fx_wizard_fireball.png`'s frames 0-3 over and over at the pack's 10 fps, at 1 world
    unit a sprite px (about 22×15), its ball on the shot's place, mirrored to face its flight, never turned; where it
    lands its impact (frames 4-6: a dark ball, a burst, a fading puff) at the body. An awakened wizard's, shot and
    impact, in its level's colour (`_awakeFx`). Until then it was `fx_hit_wizard.png`'s 16 px orb dyed pale blue.
  - A chain's `Beam` is a jagged line at body height (6 up) through its points: each leg split every ~6
    units, the joints jittered up to 2.5 across it and re-jagged every 0.05 s. It is drawn as a pale-blue
    glow (#6CC8FF at 60%, 3.5 wide) under a 1.3-wide near-white core (#F4FBFF), fading out over its time (`_beams`).
    God's Thunder's leaps (the store's artefact, #63) are beams too, `BeamLook.thunder`: the same line in a
    yellow glow (#FFD84A) over a pale-yellow core (#FFFBE0), one from the monster hit to each it leapt to.
  - A drain's `Beam` (`BeamLook.drain`, #59, `_drainBeam`) waves gently instead: each leg a sine wave 1.4 units
    across at its middle (none at its ends) moving along it, a green glow (`_drainGlow` #4CE06A at 55%, 3.2
    wide) under a 1.1-wide pale core (`_drainCore` #D8FFD0), with four motes a leg flowing from its last point
    (the target) to its first (the caster). It fades in over 0.15 s and out over its last 0.3 s. A beam made
    `Beam.between` units is drawn where they stand now.
  - Zones lie on the ground under the units (`_groundZones`, after the loot), fading in and out over 0.4 s, their
    alpha in their paints (no layer). Each is the pack's ground circle (`tiny_fx_summon.png`, `_groundCircle`)
    spread over its radius (`_circleScale`), its front half for its first frame (0.1 s), then the whole ring
    (`_ringFrame`), or, where it says so, then its star (frames 2–6) over and over (`_circleFrame`).
    A ring alone (`slime`, `arrowRain`, `volley`) over a radius wider than twice the circle (over 32 units) keeps the
    units' pixel size instead (`_reachRing`, decisions-log 177): stretched further its pixels read as noise over the
    fight, so the circle's ring is laid round the radius in 20 dashes (`_dashes`), each the 4-px square (`_dashW`) of
    the ring's own pixels where it is at that point of the way round (its dark outline and the paler row inside it,
    the front's highlight at the front), on the frame's pixels, its outer edge pushed out to the radius, evenly
    spaced by arc length (`reachDashes`). The circles with their star (frost, Consecration) are at most twice the
    circle's size:
    - `frost`: the circle with its star turning (10 frames a second), tinted ice blue (`_iceTint`);
    - `banner`: a 26-unit brown pole with a red ribbon flag at its top (`ui_book_marks.png`'s closed red
      ribbon, 2/3 size);
    - `slime` (#59, Slime Tide's puddle): the ring tinted slime green (`_slimeTint`, #7CD64A), and bubbles in it:
      `fx_hit_slime.png`'s whole burst (the blob swelling, then splattering; `_slimeSplats`) at the hit bursts'
      size, one for every 12 units of radius (2 at least), each 1.1 s on a spot of its own within 60% of the radius
      and 4 above it, then on a new one, taking turns (`_zoneTurns`);
    - `arrowRain` (#59): the ring in dark red (#B03030 on the wind-up's brightness ramp, `_circleTint`: a `_tint`
      turned it brown on the old road), at 80%, and the skeleton archer's arrows
      falling into it (one for every 5 units of radius, 4 at least), drawn over the units (`_zoneSkies`,
      after the beams): each drops 40 units onto a spot of its own over 0.3 s, pointing down and slanted,
      then stands in the ground fading until it falls again on a new spot, 0.7 s in all, the arrows taking
      turns.
    - `volley` (#81, Arrow Rain's): "Skills" above. A zone this short fades in and out over a quarter of its
      time (`_zoneFadeOf`), not 0.4 s.

    What spreads on the ground in code (the spots of a zone's bubbles and heals, the arrows' spots) is `_groundFlat`
    0.45 as tall as it is wide, like the rings at the units' feet.
  - Rings bursting out (`Game.rings`, #59, `_groundRings`, on the ground after the zones): the pack's ground circle
    (`tiny_fx_summon.png`: frame 0, its front half, for the first 15% of its time, then frame 1, the whole ring)
    spread over its radius (`_circleScale`: 2 × radius / 32, as the wind-up's circle is; wider than twice the circle,
    as Holy Shield's 3 tiles, Howl's, Earthshaker's and Roar's 3 and Death Nova's 2.5, in dashes at the units' pixel
    size like a zone's: `_reachRing`), fading over its time,
    tinted (`_ringTints`, awakening's `_tint`) in its `RingLook`'s colour (`_ringColors`): pale #E8F4FF, grey
    #9AA0A6, dark #2B2233, dust #C8A878, red #FF4A3D, orange #FF8A30, bone #EDE3C8, brown #8B5A2B, steel
    #B0BEC5. The same colours tint a monster's guard ring (`Unit.guardLook`). The troops' skills' looks (#81:
    brace, slash, rage, prayer, pillar, crack, arcane, holy, dome) have their own shapes and colours ("Skills"
    above); a `Ring.over` a unit is drawn where the unit stands now.
  - What monsters' skills leave on a troop (#59) shows like on a monster: the coloured rings at its feet
    (`_statusRings`) for the effects with no icon over it (slowed, weakened, marked, taunted, bleeding; a
    buff like `might` keeps its icon), and a taunted troop's orange line to the monster that taunted it
    (`_statusLines`, `_effectLines`). A stunned troop freezes on its hurt strip's first frame, like a stunned
    monster.
- **Heroes** (lib/hero.dart, a part of main.dart; the rules: units-and-combat.md):
  - A white halo behind the body (`_heroHalo`: 4 stepped bands fainter outward in the sprites' pixels, "The field's
    rings in pixels"; radius 14 ± 1.5 pulsing by whole units on the field's clock, centred 11 units above the feet,
    hopping with the body). An awakening colours
    only the outline, the ground shadow and the sparks (blue / crimson / gold), so a Hero reads apart by
    the white light on the body and the crown.
  - The pack's gold crown (`_icCrown`, `ui_icons.png` (64, 16, 16×16)) 8 units big, just above the bars
    (the HP + MP box; `_heroCrown`).
  - The same crown on the top right corner of the type's sprite box in the book's troop row and in the
    troop counter's list while that type has a living Hero (`_heroMark`, `Game.hasHero`).
  - A Hero's 2 rolled attributes (`Unit.heroStats`) show as the book row's stat icons, each followed by
    "x3" in the effect green ("x2" under Oath of Kings: `_heroX`, `heroBoostNow`; `_heroStats`; `_heroStatIcon`):
    - HP is the heart, MP the blue bolt;
    - any other is the icon of the item that raises it: power the sword (the staff for a caster),
      defence the shield, rate the gloves, speed the boots, range the bow.
  - Where the attributes show:
    - the nameplate's third line, and its own skill (`Unit.heroSkill`) on a fourth: the skill's mark
      and its title in a dark gold (`_heroSkillInk`, readable on the tan; `_heroSkillLine`);
    - hovering the book row's crown (`_Hint.hero`, registered by `_heroMark` with the row's clip):
      a tooltip "Hero" with the crown, then each living Hero of that type, its name, its 2 attributes
      and its skill (`_heroTip`), pointing at the crown. The troop counter's crown has no tooltip.
  - A Hero skill's mark (`HeroMark`, `_heroMarkIcon` in skills.dart): an item's or a relic's icon, or
    `ui_icons.png`'s heart, MP bolt or coin.
  - When one is made: the upgrade burst on it and the win jingle (`Sfx.clear`) over the wave's, and a
    splash screen (lib/hero_splash.dart; issue #47). A loaded game's Heroes get none, old ones rolling
    their attributes on load included.
    - `Game.heroMade` lists the troops just crowned, and `Game.heroRecalled` the Heroes just called back on
      the Army detail (Hero Gugur, #92 part 3: the same splash, between waves, under "<name> is back!"); `update` drains both
      into `_Herald` (`_heroNews`, `_Herald.back` marks the called back), which shows them one at a time. It closes after `_heraldFor` 4 s on the screen's clock, on a press
      anywhere (`_heraldDown`: the press is used up, its tap up and drag dropped), on Esc / P, or at once
      if its troop leaves the game (a new game, or it fell and is gone).
    - **When:** a Hero is made when its wave is won, so the splash opens between waves: once the win's
      cheering is over (`victoryTime`: after the "VICTORY!" popup, as the book floats in), or at once if
      the next wave has already started. It pauses nothing.
    - The Auto countdown waits from the win until the last splash closes: `_heroNews` keeps
      `Board.holdAutoStart` set while one shows or is waiting for the cheering to end.
    - **Look:** the screen dims (black, 65%), and a panel in the tooltip frame's body (`_tipBody` at 3×, 2×
      on a small screen) pops in over `_heraldIn` 0.35 s (scaled from 0.6, `easeOutBack`). Everything
      fades out over its last `_heraldOut` 0.3 s (a `saveLayer`). Sizes follow `_screenScale` (s); the
      text is f = 1.2·s. The panel is as wide as its content. Drawn after the HUD and
      the dragged loot, before the score and message screens, so it is over the open book (and the pause's
      "Pause") too. Like the score screens, the HUD under it takes no taps, drags or tooltips.
      - Across the panel's top edge, half over it, the title "<name> (<type>) is now a Hero!" (`Unit.name`,
        `troopTypeNames`; for a Hero called back (Hero Gugur), `Game.heroRecalled`, "<name> is back!",
        `_heraldTitle`) in `_dark` on the pack's flat small ribbon at 4× (3× on a small screen)
        (`_ribbonTitle`: `ui_ribbons.png`, `_ribbon` 64×20 at (8, 1), 3-sliced, its 24 px ends kept and
        the plain band stretched to the title; text 6.5·k on the band's inside, rows 3..14, shrunk to fit
        the screen).
      - The portrait (`_heroPortrait`, 220·s square): `fx_hit_knight.png`'s gold sun ring
        bursting behind it once over `_heroBurstTime` 0.6 s (all 7 frames, at a whole number of screen px a sprite
        px, its frame about 1.2 × the box wide), ten gold rays turning slowly and a white-gold glow (both drawn in
        code: no sheet has rays or a soft glow), the idle sprite without its shadow
        (`book_<type>_idle`, `_idleBounds` filling the box under the crown, outlined in its awakening
        colour), and the pack's crown over its head.
      - Beside it, its lines (`_heroLines`): the 2 rolled attributes
        (`_heroStats` at 1.6·f); then its own skill's mark (22·f) and its English
        title in dark gold (`_heroSkillInk`, 20·f), and what it does wrapped to 360·s
        (`_wrap`, 15·f, `_tipInk`).
      - "Tap to continue" at the bottom, 14·f in faded ink.
    - **The skill:** the lines read the Hero's own skill (`Unit.heroSkill`, rolled as it is crowned):
      its mark (`_heroMarkIcon`), its English `title` in the nameplate's dark gold (`_heroSkillInk`)
      and its `desc`. Every Hero has one: all 45 are built (decisions-log 93), and a Hero loaded from an older
      save without one rolls it then (`_rollHeroSkill`).
    - Under the dimming, `fx_hit_knight_templar.png`'s gold ring widening out of the Hero on the field again and
      again (its frames 3–5, the solid rings, at `_heroRingFps` 6; the ones before are filled and would hide it, the
      last are fading dots the dim swallows; at the hit bursts' size; `_heroRing`), so it is clear which troop it is.
    - For a Hero's skill cut-in (#51): `_ribbonTitle`, `_heroPortrait` and `_heroLines` draw into any rect.
  - **When a Hero casts its own skill** (issue #51, lib/hero_cast.dart): a cut-in of `cutInTime` 1 s.
    - **At most one per Hero every `heroCutEvery` 20 s, and none within `heroCutGap` 3 s of another** (decisions-log
      298, the owner's "Dibatasi": the Heroes cast far more often): `HeroCutGate` (lib/cut_ins.dart, screen clock)
      admits a cast before it is queued; a cast it turns away still happens, without its cut-in.
    - `Game.heroCasts` (drained in `_drainCasts`, skills.dart) feeds `Board._cutIns`, a `CutIns` queue
      (lib/cut_ins.dart, pure Dart, ticked on the screen's clock in `update`): one shows at a time; at most
      `cutInWaiting` 3 wait and a fourth drops the oldest waiting; a Hero casting again while its cut-in
      waits takes that one's place; the one showing always runs its time. Another game coming in clears it.
    - It pauses nothing and takes no press: the game and the taps go on under it.
    - **Band** (`_heroCutIn`, after the HUD and the dragged loot, under the Hero splash and the pause and
      score screens): `ui_all.png`'s gold studded frame (`_goldPlate` (681, 200) 30×34, the pack's gold row of
      panels, the boss's moment band's red one's sibling; sliced l 7, t 8, r 7, b 9, at 2×) across the screen 8 px
      in from its sides, at 30% of the screen's height, laid out like the moment band:
      `_heroBandH` = its borders + 6·s padding + the title's line (30·s, 18 at least, × 1.2) + the name's
      (17·s, 12 at least, × 1.3) + 6·s. It slides in from the left over the first `_cutSlide` 15% of its time and
      out to the right over the last (cubic eases). On it: the Hero's portrait (`_heroPortrait`, the splash's:
      burst, rays, glow, sprite, crown; the sprite plays the Hero's skill strip once from its entry frame, then its idle:
      decisions-log 299) 150·s tall, standing on its inside's bottom at 16% of the width; then the skill's mark (`_heroMarkIcon`) and its English `title` in cream (`_foeInk`, outlined
      `_dark`), and "Hero <name>" under them in `_dark`, both cut to the band. Until decisions-log 173 it was a dark
      strip with gold edges drawn in code. A foe's banner rests 6·s under it (`_foeTop`).
    - **Spotlight** (`_heroSpotlight`, over the field, under the pops and the HUD): the field dims round
      the Hero, clear within 24 field units of its body, black 45% from four times that out, rising and
      falling with the band.
    - Off in Settings ("Hero spotlight", `Settings.heroCutIns`, on by default).
  - The "VICTORY!" popup's fallen line names a fallen Hero "Hero <name> (<type>)".
- **Awakening** (lib/awakening.dart, a part of main.dart): level 1 / 2 / 3 = blue / crimson / gold
  (`_awakeColors`; `_awakeInk` for text on the page). An awakened troop keeps its own colours; only what
  is round it takes the level's colour (the owner's call, #34).
  - **Outline:** a 1 px outline round the body. `onLoad` builds one per troop strip in memory
    (`_outlined`, into `_outlines` by strip name): white on every clear pixel with a visible one left,
    right, above or below it, frame by frame. `_frame(…, line:)` draws it under the body with
    `_linePaints` (`ColorFilter.mode(colour, srcIn)`), so it costs one extra `drawImageRect` per troop.
    It shows in every animation, dying too.
  - **Shadow:** the ground shadow is drawn flat in the colour (`_awakeShadow`, keeping its alpha),
    pulsing a little. So that the Soldier's can change too, its strips have their baked-in shadow cleared
    at load (`_unshadowed`, as the book always did; assets.md). That also leaves its drag ghost without a
    shadow, like every troop's.
  - **Sparks:** 3 + level 1.2-unit sparks rise and fade in front of a living awakened troop
    (`_auraSparks`), out of step per troop (`Unit.id`). They and the shadow's pulse run on the field's
    clock (`_fieldClock`), so they stop while the game is paused.
  - **Hits and shots:** bursts named `<fx>_awake<level>` (`awakeFx`, split by `_awakeOf`) draw the plain
    `<fx>` strip recoloured toward the colour (`_awakeFxPaints`, a `ColorFilter.matrix` `_tint` that
    keeps a fifth of each pixel's colour and maps its brightness onto the level colour) and 1.2× as big:
    hits, heals and the awakening moment (`upgrade_awake<level>`, 53 units). An awakened archer's arrows
    are recoloured the same way, and so are the wizard's fireball and ice star and their hits.
  - **Elsewhere:** the dragged troop's ghost, the book row's sprite, the Tas page's type list and the troop
    counter's sprites get the outline too (faded, `_lineGhosts`, on a ghost). The level shows right of the bar as 1–3 pips
    of the level colour, dark-rimmed (`_levelPips`).
- **Monster ranks on the body** (lib/tier_look.dart, a part of main.dart; #58, the owner: "semua jenis monster
  bisa jadi tier enemy apapun tapi perlu di filter warnanya biar ada pembeda jenis monsternya"). Any type can
  hold any rank, so the rank shows on the sprite, in its HP bar's colour (`_tierBar`): elite silver, high
  elite gold, mini boss purple, boss orange. A normal monster is drawn as it is.
  - **Recolour:** the body is drawn through `_partTint(colour, share)`: awakening's `_tint` matrix
    (brightness onto the colour) blended with the plain sprite, `_tierShare` of the way (elite and high
    elite 0.45, mini boss 0.5, boss 0.55), so the type's own colours still read under it.
  - **Outline:** a 1 px outline in the colour (`_tierLines`, flat), from the same `_outlines` as the
    troops': `onLoad` builds one per monster strip too (every type's, the necromancer's summoning and the
    healer's cast).
  - In every animation (walking, attacking, hurt, dying, casting, cheering at game over); a raised minion
    shows its rank the same way. The ground shadow stays plain, and the HP bar keeps its colour.
- **Win popup** (`_victory`): "VICTORY!", the wave, the gold bonus and the loot: the materials the wave dropped, each
  kind once in `Mat` order, "Nx" (20, white with the dark outline) before its 32 px icon, centred ("The Bag's
  Materials"). No item or relic drops, so none is counted (decisions-log 321: until then a game without the Towns
  counted its items and relics first, `lootCounts`).
  - The materials lie on the field until the win and fly to the Bag (decisions-log 262, "The Bag's Materials"). Until
    decisions-log 321 a game without the Towns' items and relics lay there too, bobbing, a relic glinting in the Hero
    gold.
  - Round it, sparks twinkle: `ui_click.png`'s small x and its bigger x (the click's first two frames, in the steps
    `_sparkSteps` 0, 1, 1, 1, 0, then dark for one, at `_sparkFps` 12 a second) at 14 spots going slowly round an
    ellipse, each on a clock of its own, gold (dyed) and white by turns, 4 screen px a sprite px. Until decisions-log 173 they
    were plus shapes drawn in code.
  - When the wave won opened the Shop (`shopJustOpened`: the wave won is a later `shop.from`; never while `shopFrom` is
    1, as shipped, where the Shop was never shut: decisions-log 253), a gold line "Towns have a Shop now!" (`shopInTowns`,
    decisions-log 237; a game without the Towns' "The Shop is open!" went in decisions-log 296) led by the coin stack comes before the loot (#63). A boss wave that brought a chest has a gold "Boss Chest: pick 1 of 3!" (`draftCards`) led by the gift
    box beside it.
  - When it is the last wave before the tide's first (`Game.tideRising`: wave 34 in a new game; #92), a light
    blue line (`_tideInk`) comes next: the wave meter's crossed swords, "The Tide rises!" and "Monsters get stronger
    every wave" (`tideNews`; wrapped onto two lines where the screen is narrow). An entry of `_popupRows` may have
    no picture for that.
  - Under the gold bonus, the Pusaka's one line (decisions-log 149; the design's critique M4: the popup lasts
    `victoryTime`, so one line), pale gold with the dark outline: the wave's best counter and the small relics back in
    the bag, "Artifact: Grail 6 saved · Back to Bag: Fury ×2" (`pusakaWinLine` from `Game.lastPusaka`; "4 hits lived",
    "+5k blocked", "+3.2k HP", "+12.3k" by the Artifact's kind; either
    part alone; none with neither). 18 px, a pixel smaller at a time down to 12 until it fits `winLineMaxW` 361 px (and
    the screen less 40), else cut with ".."; the rows under it move down 34 px. The whole report is in the battle log.
  - Under the loot, the troops that fell in the wave (`Game.lastFallen`), after a red "Fallen:": each by
    its book sprite in grey (`_greyscale`) and "Name (Type)" (`troopTypeNames`) while `fallenNamesMax`
    3 or fewer fell, else each type once as "Nx" + its grey sprite (`fallenCounts`, the book's order).
    No line when nobody fell.
  - Both lines wrap at the screen's width less 40 px (`_popupRows`, 40 px per line).
  - The popup is centred on the field at 40% of its height, but rises (to 40 px from the top at most)
    while its lines would run past the field's bottom.
- **Message window (`lib/message.dart`, `Board.showMessage(text, {time})`):** cream lines, one per `\n` (20·u, u as on the
  welcome screen; a line too wide for the screen, 8 px inside it either side, breaks at its spaces: in a window too narrow for it, 568×320, a
  Shadow's take line, "Monsters got Off Beat 1: Rare and Epic Artifacts that work every few hits need 1 more hit.", is
  three) in
  the wooden crate (`_crate`, same slices, at 2×; dark, so it reads over the field
  and over the book's pages; it points at nothing, so it kept the crate when the tooltips moved to the
  pack's pointer frame), centred at 30% of the field's height, popping in over 0.12 s,
  with a soft shadow. It closes on the next press (a press
  on it does nothing else: its tap up and drag are dropped, `_Message.tapped`) or after
  `time` (`_messageTime` 2 s; a one-time note `_noteTime` 8 s). Drawn after the HUD, before the tooltip and cursor.
  The limits' one-time notes (`Game.limitNotes`, decisions-log 141) show there when a save over them comes in, in
  up to six lines (with Beban's "Army cap 36. Each troop over it:" / "Tide +2 waves", `overNote`, for an
  army alive over the cap, decisions-log 162; it fits 915×412 8 px or more inside the screen), after the tide's "The Tide rises! Monsters get stronger every wave" when the same save also catches up
  with the tide (`Game.tideCaughtUp`, #92): one window, so neither hides the other. A save from before the Pusaka adds
  their note's three lines after those (`pusakaNotes`, decisions-log 151: "Your Artifacts now work for a whole type,
  / troops bought later too, and are never lost. / Put on for you: change or Undo in the Bag."); the Bag page keeps
  its OK and Undo ("Tas, the Bag" above). The window can lie over the book's tabs: the press that
  closes it does nothing else. Used for a relic refused by
  a troop that holds one ("Already holds <relic>", e.g. "Already holds Fang": `holdsRelic`, #87; a Hero's
  "Relic slots full"), a greyed row of the Tas page's list (its reason), a Remove refused ("Only between
  waves", #91), a greyed Sell's reason (the Shop's card and the Bag page's Sell row) and the Bag page's Sell all
  ("Sold Sword x86: +86,000 gold", decisions-log 169), and
  for "Monsters charge!" / "Win in 60 s or lose a heart." when a stalled wave's monsters start charging the back line
  (`Game.newMarch`, drained in `update`; `marchNote`, lib/wipe.dart; units-and-combat.md, "Stalled waves"; "Monsters
  broke through!" until decisions-log 329). Also "The Tide rises! Monsters get stronger
  every wave" once when a save from before the tide comes in with it already on (`Game.tideCaughtUp`, drained in
  `update`, #92), and "Replace fallen"'s refusals and partial buys (above).
- **The army cap's warning** (decisions-log 161; qa-4's finding: on the owner's w63 save the army held with no
  losses until it was down at the cap, then the tide took it in 2-3 waves, and nothing had said so). Two lines in the
  message window, for `_noteTime` 8 s: "Army full: cap 36 - Tide +87%" / "Make types stronger in the Army page (Awaken)"
  (`capWarningText`: the cap, then the coming wave's tide as the meter's badge shows it; the Army page's detail buys it,
  decisions-log 237; a game without the Towns said "in the Shop" until 321).
  - **When** (`Game.capWarning`, asked by `_capNews` in `update` every frame): between waves, while `Game.capPressed`
    holds (the board's `armyMax` on and the capacity at it; the army as it stood in the wave, the living and the
    wave's `fallen`, at the cap or over it, so the owner's 48 counts; the coming wave past the tide's first, its
    "+0%"; and a fielded type below Bangkit 5, so the Army detail has a level to sell), at most once every `capWarnEvery` 5
    waves (`Game.capWarnedAt`, not saved: a loaded game may say it once more).
  - **It waits** until a won wave's "VICTORY!" popup is over (`victoryTime` after the win; never before the game's
    first win since it came in, so a loaded save's notes stand alone and the warning follows its next win), and while
    the Hero splash shows, a boss chest is due (`_chestHolds`) or another message is up; then it shows.
  - Its words fit a phone: at 915×412 the window stands 8 px or more inside the screen
    (`test/cap_warning_hud_test.dart`).
- **A lost wave** (lib/wipe.dart, decisions-log 322, 329; units-and-combat.md "An army wiped, and the other lost
  waves"): the heart lost pops as the wave is lost (the last troop falls, a monster reaches the line with no troop
  standing, the march runs out); the monsters left hop for joy where they stood (the game-over hop, `Game.swept`, drawn with the
  units) for `wipeCheer` 2.4 s, then each goes in a summon circle (`tiny_fx_summon.png`, the necromancer's). `update`
  sees `Game.wipedAt` change (`_savedWipe`) and, unless the game is over, saves the game at once (the heart lost stays
  lost), starts Auto Wave's countdown as a win does, and says in the message window for `_noteTime` 8 s: "Your army
  fell! -1 heart." / "Wave N again." (`Game.wipeNote`; "No troops! -1 heart." for a wave begun with none, "Too slow! -1
  heart." for a march not won in time). The battle log's line: "Army fell: -1 heart, wave N again" ("No troops: ...",
  "Too slow: ..."; at the last heart "...: no hearts left"). Between waves the army's fallen are on "Replace fallen" and
  Auto Buy buys them back as the gold allows; the Auto hold waits for the army as after any wave.
- **Game over** (`_gameOver`, lib/scoreboard.dart): a light dim (the monsters cheer through it), "GAME OVER  -
  Wave N" (36·u, white), "Score N" (30·u, gold, dark outline) and two buttons side by side, 44·u tall:
  "Scoreboard" (180·u) and "Play again" (140·u; a fresh game, the save deleted). u as on the welcome screen.
  Hidden while the name panel or the board covers it.

## Scoreboard (`lib/scoreboard.dart`)

The score's rules and storage: [scoreboard.md](scoreboard.md). State: `Board._score` (`_Scores`).

- **When the game ends** (`Board.update` sees `over`; `_gameEnded`, once per `Game`): the entry
  (`ScoreEntry.of`) is submitted at once under the player's name. The first time, there is no name yet,
  so the name panel asks for it first.
- **Name panel** (`_namePanel`, layout from `_nameLayout` so canvas and field line up): the parchment,
  440×230·u centred at 30% of the height (clear of a phone's keyboard), title "Name" (44·u, gold), the
  field box (`_framePlain`, 320×52·u) and a green "OK" (160×48·u). OK or Enter keeps the name
  (`cleanName`, player.json) and submits. It is asked once; nothing changes it later.
  - The field is a Flutter `TextField` in a Flame overlay (`_NameField`, `'name'` in `main()`'s
    `overlayBuilderMap`), added and removed in a microtask (`update` also runs inside GameWidget's build).
    Overlays sit above the game's input, so a press on the field stays there and one elsewhere reaches
    the canvas (the OK button).
  - Hint "Player" (the default name, `ScoreEntry.defaultName`; entries saved before the English text keep "Pemain"), the game's font at 26·u in ink, centred, at most 12 characters.
  - There is no MaterialApp, so the field brings its own `Material` (transparent), `Localizations` (en)
    and `DefaultTextEditingShortcuts`. It has no selection handles or context menu
    (`enableInteractiveSelection: false`, `contextMenuBuilder: null`): those need an `Overlay`, which
    only an app has.
  - Over the field the system text cursor shows, and the pixel cursor hides (`_mouse = null` on enter)
    until the mouse moves on the canvas again.
- **Scoreboard** (`_scoreBoard`, from the game-over and welcome screens): the parchment 520×500·u,
  centred, title "Scoreboard"; a header "Name  Score  Wave" (faded; nothing over the rank column) over a thin line; the best 10
  (rank, name, score in dark gold, wave); "Back" (200×48·u) closes it.
  - The player's last entry (`_Scores.mine`) is lit (`_frameLit` behind its row, a light cream band inside it); when it isn't in the
    top 10 it shows under them with rank "-".
  - "Loading..." until the list comes (it waits for the last submit first); "No scores yet" when empty.
  - When the server can't be reached: `showMessage('Server not available')` and the list is this
    device's (the same message when a submit only reached this device). "Score not saved" when not
    even the file could be written.
- The name panel and the board dim the screen (45%) and drop every other tap target, the book's and the
  tooltips' included (`_scoreScreens`, drawn after the HUD, before the message window and the cursor).
