import 'dart:async' as async; // Flame has a Timer of its own
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart' hide Game;
import 'package:flutter/foundation.dart'
    show LicenseEntry, LicenseParagraph, LicenseRegistry, defaultTargetPlatform, kIsWeb;
import 'package:flutter/gestures.dart' show HorizontalDragGestureRecognizer;
import 'package:flutter/material.dart' hide PointerMoveEvent;
import 'package:flutter/services.dart';

import 'auto_start.dart';
import 'cut_ins.dart';
import 'game.dart';
import 'guide_rules.dart';
import 'guide_text.dart';
import 'hud_font.dart';
import 'letterbox.dart';
import 'licences.dart';
import 'monster_skill_texts.dart';
import 'save.dart';
import 'scores.dart';
import 'settings.dart';
import 'sounds.dart';
import 'telemetry.dart';
import 'town_art.dart';
import 'town_smith_art.dart';

part 'awakening.dart';
part 'troop_row.dart';
part 'troops_page.dart';
part 'troop_detail.dart';
part 'wishlist_look.dart';
part 'welcome.dart';
part 'tooltip.dart';
part 'message.dart';
part 'bag.dart';
part 'boss_bar.dart';
part 'wave_meter.dart';
part 'troop_counter.dart';
part 'lives.dart';
part 'scoreboard.dart';
part 'pause.dart';
part 'hero.dart';
part 'hero_splash.dart';
part 'hero_cast.dart';
part 'skills.dart';
part 'plates.dart';
part 'hero_skill_fx.dart';
part 'battle_log.dart';
part 'hero_move_fx.dart';
part 'start_button.dart';
part 'button_fx.dart';
part 'off_view.dart';
part 'tier_look.dart';
part 'badge.dart';
part 'shop_page.dart';
part 'ascend_page.dart';
part 'mini_map.dart';
part 'hud_row.dart';
part 'drop_popup.dart';
part 'licence_page.dart';
part 'guide_page.dart';
part 'pusaka_look.dart';
part 'chest_popup.dart';
part 'omen_look.dart';
part 'foe_cut_in.dart';
part 'foe_splash.dart';
part 'coach.dart';
part 'town_look.dart';
part 'town_scene.dart';
part 'smithy_page.dart';
part 'tavern_page.dart';
part 'tavern_look.dart';
part 'town_life.dart';
part 'town_smith.dart';
part 'spawn_bar.dart';
part 'page_scroll.dart';
part 'fps_readout.dart';
part 'body_look.dart';
part 'pixel_shapes.dart';
part 'wizard_fx.dart';
part 'wipe_ask.dart';
part 'pocket_look.dart';

/// The player's volumes (settings.json), set on the book's Settings page; a new game keeps them.
final _settings = loadSettings();

/// The telemetry (#64, lib/telemetry.dart, docs/telemetry.md): the game being played writes its records to
/// telemetry.jsonl beside the save always, and to the server only while "Send game data" is on
/// (Settings) and the build has one ([telemetryServer]).
final _httpSink = HttpSink(telemetryServer, enabled: _settings.sendTelemetry);
final _telemetry = TelemetryAdapter([FileSink(dataFile('telemetry.jsonl')), _httpSink], installId: installIdOf(_settings));

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await landscapeOnly(); // a phone's game turns sideways only (decisions-log 289), before its first frame
  _fullScreenOnPhone(); // the status and navigation bars hide on a phone (decisions-log 215)
  await initDataDir(); // the phone's files dir (save.dart), before _settings reads settings.json
  if (_settings.seen == null) saveSettings(_settings..seen = seenFrom(savedWave())); // the guide's seen set, once (guide_rules.dart)
  Sounds.volumes(_settings.music / 100, _settings.sfx / 100); // before the music starts
  Sounds.init();
  registerLicences(); // the native libraries Flutter's NOTICES misses (licences.dart): the Licenses page lists them
  // The troops' fall-back brain (#50, lib/retreat.dart), before the game starts; its defaults stay when the
  // file is missing or unreadable. Not in onLoad, which a widget test's TdGame runs too: the defaults are the
  // shipped file (game_test.dart checks), and reading an asset there slowed every test boot.
  try {
    retreatBrain = RetreatBrain.parse(await rootBundle.loadString('assets/ai/retreat.json'));
  } catch (_) {}
  // The Towns' numbers (lib/town.dart, the owner's tuning file), likewise: the defaults stay without the file, and they
  // are the shipped file (test/town_test.dart checks).
  try {
    loadedTownRules = TownRules.parse(await rootBundle.loadString('assets/config/town.json'));
    for (final s in loadedTownRules.skipped) {
      debugPrint('town.json: left out $s'); // a name the game doesn't know, or a bad count
    }
  } catch (_) {}
  autoTryAgain = false; // the player chooses after a wipe: Try again or Give up (wipe_ask.dart)
  runApp(gameRoot(TdGame()));
}

/// The app's widgets: [game] in its letterbox (letterbox.dart, decisions-log 289: a view taller than wide shows the
/// landscape game across its width between dark bars). The pixel cursor hides when the pointer leaves the game's box.
Widget gameRoot(TdGame game) => Letterbox(
      onExit: (_) => game.board._mouse = null,
      child: GameWidget(
        game: game,
        mouseCursor: SystemMouseCursors.none, // the game draws its own pixel cursor
        loadingBuilder: (_) => const _Loading(),
        focusNode: _gameFocus, // Esc / P (pause.dart)
        overlayBuilderMap: {_nameOverlay: (_, TdGame g) => _NameField(g.board)},
      ),
    );

/// A phone's game is landscape only (decisions-log 289; the owner, 2026-10-09: "game vertical di hapus saja, game force
/// jadi horizontal"): on Android and iOS it turns to either side and never upright. Android's activity asks the same in
/// AndroidManifest.xml (`sensorLandscape`), so the app never opens upright before this runs. Nothing on the desktop or
/// the web, whose view taller than wide is letterboxed instead (letterbox.dart).
Future<void> landscapeOnly() async {
  if (_onPhone) await SystemChrome.setPreferredOrientations(const [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
}

/// The pack's loading dial (ui_loading.png, 16 frames of 16px) while the images load.
class _Loading extends StatefulWidget {
  const _Loading();

  @override
  State<_Loading> createState() => _LoadingState();
}

class _LoadingState extends State<_Loading> {
  static const _size = 64.0;
  int _f = 0;
  late final _timer = async.Timer.periodic(const Duration(milliseconds: 70), (_) => setState(() => _f = (_f + 1) % 16));

  @override
  void initState() {
    super.initState();
    _timer;
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ColoredBox(
        color: const Color(0xFF1B2A1B),
        child: Center(
          child: SizedBox.square(
            dimension: _size,
            child: ClipRect(
              child: OverflowBox(
                alignment: Alignment.topLeft,
                maxWidth: _size * 16,
                maxHeight: _size * 4,
                child: Transform.translate(
                  offset: Offset(-_f * _size, 0),
                  child: Image.asset('assets/images/ui_loading.png',
                      width: _size * 16, height: _size * 4, filterQuality: FilterQuality.none),
                ),
              ),
            ),
          ),
        ),
      );
}

// Tiny RPG Character pack: every animation is a strip of 100x100 frames facing right, with the
// character's feet (shadow) on row 59. Copied as assets/images/tiny_<character>_<anim>.png.
const _anims = ['idle', 'walk', 'attack', 'hurt', 'death'];
const _feet = Offset(50, 59);
/// Opacity of a unit's plain ground shadow (decisions-log 240), and the factor an awakened troop's coloured shadow keeps
/// of its old 0.8-1.0 pulse; the colour must still read at a glance.
const unitShadowAlpha = 0.45, awakenShadowAlpha = 0.65;
const _fps = 10.0, _hurtTime = 0.3;
const _arrows = {'archer', 'skeleton_archer'}; // tiny_arrow_<who>.png, 32x32 pointing right
// Bursts: tiny_fx_<name>.png ones (summon circles, heals, a troop healer's smite) sit on the feet at [_fps];
// fx_<name>.png ones (hit_<attacker> from tool/import_fx.py, upgrade) are centred on the body at 15 fps,
// drawn ~32 units big. The smite's tiny_fx_holy.png is the heal recoloured in memory ([_holyTint]).
const _feetFx = {'summon', 'heal', 'holy'};
const _fxFps = 15.0, _burstSize = 32.0; // a fx_<name>.png frame is drawn [_burstSize] world units tall

/// The sparks of the "VICTORY!" popup: ui_click.png's small x and its bigger x twinkling (frames 0, 1, 1, 1, 0), then
/// dark for one (-1), [_sparkFps] steps a second.
const _sparkFps = 12.0, _sparkSteps = [0, 1, 1, 1, 0, -1];
const _summoners = {boss, minion}; // tiny_<key>_summon.png: casting / rising from the ground
// Healers with a tiny_<key>_cast.png strip, played for a heal; their attack strip is then a real attack
// (the healing necromancer's scythe swing, Unit.swung). Other healers heal with their attack strip.
const _casters = {necroHealer};

/// The skill strips type [k] has besides [_anims] (skill_strips.dart's [skillStripFiles], decisions-log 299).
Iterable<String> _skillAnims(String k) => {for (final (t, a) in skillStripFiles()) if (t == k && !_anims.contains(a)) a};
// HP bar fill (colour, shade) for the ranks the pack has no strip for, and the elites': silver, since blue
// means MP (the owner, #62). So the ranks read red (the pack's strip), silver, gold, purple, orange.
const _tierBar = {
  Tier.elite: (Color(0xFFD9DEE8), Color(0xFF8C94A3)),
  Tier.highElite: (Color(0xFFF2C12E), Color(0xFFB07A12)),
  Tier.miniBoss: (Color(0xFFA24BD8), Color(0xFF65278F)),
  Tier.boss: (Color(0xFFFF8A24), Color(0xFFB2520C)),
};
// A monster's MP fill: the pack's cyan over its blue, as in the long blue bar's lower strip (34, 11) (troops
// fill theirs with the blue strip). It was set apart from the elites' blue HP, silver since #62.
const _monsterMp = (Color(0xFF2CE8F5), Color(0xFF0095E9));

/// A unit's bar: the pack's HP capsule (ui_bars.png (82, 33, 12x6), a 1 px rim round 10x4) at [barK] world
/// units per sprite px, over its head.
const barK = 0.75;

/// With MP the capsule is one taller box, [barInnerMp] sprite px inside, split: HP on top, [barHpShare] of
/// it, MP under it (the owner, #52: "65% adalah hp dan 35% adalah mp").
const barInnerMp = 6.0, barHpShare = 0.65;

/// Where the bar of a unit at ([x], [y]) goes, in world units: the [box] (the capsule, its rim included),
/// and the full [hp] and [mp] fills inside it, to cut to what is left ([mp] null without MP: the plain HP
/// capsule, its whole inside HP). With MP the box grows upwards: its bottom stays where a lone HP bar's is,
/// clear of the head.
({Rect box, Rect hp, Rect? mp}) unitBar(double x, double y, {required bool mp}) {
  const k = barK, w = 12 * k, bottom = -22 + 6 * k; // a lone bar: 22 above the unit, 6 px tall
  final inner = mp ? barInnerMp : 4.0;
  final box = Rect.fromLTRB(x - w / 2, y + bottom - (inner + 2) * k, x + w / 2, y + bottom);
  final hp = Rect.fromLTWH(box.left + k, box.top + k, 10 * k, (mp ? inner * barHpShare : inner) * k);
  return (box: box, hp: hp, mp: mp ? Rect.fromLTRB(hp.left, hp.bottom, hp.right, box.bottom - k) : null);
}
// A raised minion's summon circle (a `summon_<tier>` burst) in its tier's HP bar colour; normal ones
// keep the plain circle.
final _summonPaints = {
  for (final (tier, color) in [
    (Tier.elite, _tierBar[Tier.elite]!.$1),
    (Tier.highElite, _tierBar[Tier.highElite]!.$1),
    (Tier.miniBoss, _tierBar[Tier.miniBoss]!.$1),
  ])
    'summon_${tier.name}': Paint()
      ..filterQuality = FilterQuality.none
      ..colorFilter = _tint(color),
};

// The scene: the band ([backdropH] world units), then the field ([fieldH]), both GandalfHardcore's FREE Platformer Assets
// (decisions-log 228, amending 16; 244).
const backdropH = 64.0;

// The band: the pack's Normal BG layers, the Town's own files ([townLayers], [townLayerW]x[townLayerH] px each), far to
// near: the sky (5, opaque), the mountains (4), the far, middle and near pines (3, 2, 1), each tiling sideways at
// [_parallax] of the camera. Their row 0 is [_bandTop] under the band's top, at [_layerK] world units a px (5 px a
// unit): layer 1's pines' skirts end on its flat ground at rows 230-263 (band y 60-66.6, round the field's top, the
// horizon), and its ground runs on to its last row (y 83.2), under the floor.
const _layerK = 0.2;
const _bandTop = 14.0;
const _parallax = [0.05, 0.1, 0.2, 0.3, 0.45]; // far to near: layers 5 .. 1
// The sky's top row, which repeats from [_skyAbove] world units above the band down to [_bandTop] (whatever a screen
// may show there), and the welcome screen lays under its whole scene.
const _sky = Color(0xFF80C2CE), _skyAbove = 1000.0;

// The clouds: battle_clouds.png (tool/import_battle_floor.py), [battleCloudsW]x[battleCloudsH] px at the layers' scale,
// row 0 at the screen's top ([fieldFoot] under the band's), between the sky and the mountains (which hide their lower
// parts). They drift left
// [_cloudDrift] world units a second on the field's clock and move at [_cloudK] of the camera, wrapping round.
const battleCloudsW = 3072, battleCloudsH = 130;
const _cloudK = 0.07, _cloudDrift = 1.2;

// The props line at the horizon: battle_props.png, [battlePropsW]x[battlePropsH] px at the layers' scale, row 0 at the
// band's top: Pine forest's big trunks (running up off the screen), its pines and a log, Tree1 and Tree2, Decor's
// boulders, bushes and ferns, standing just under the field's top, in front of layer 1 and behind everything on the
// field. It moves at [_propsK] of the camera, between layer 1 and the field; the floor's grass and ground line hide its
// feet.
const battlePropsW = 2048, battlePropsH = 330;
const _propsK = 0.7;

// The floor: battle_floor.png, [battleFloorW]x[battleFloorH] px at the layers' scale, its row 0 at band y [_floorTop],
// its last [fieldFoot] under the field's bottom. It moves with the field and repeats sideways. Its first rows are clear
// but for the ground line (flower tufts, ferns, small bushes and rocks along the horizon) and the first rows' blade
// tips; opaque from the horizon down: the lanes' meadow, and a grass top over earth along the front, its grass lip at
// field y [frontLip].
const battleFloorW = 1024, battleFloorH = 786;
const _floorTop = 56.0;

// The front edge under the field (decisions-log 263; the owner: a bottom padding, no troop or monster any lower): its
// grass lip at field y [frontLip], 6 under the lowest a unit's shadow reaches (a unit stands at y fieldH - 2 at the
// lowest, its feet 5 under it), and its earth down to [fieldFoot] under the field's bottom. The Board frames the scene
// that much higher ([Board._origin]) so the screen shows it: what leaves the screen's top is only the sky's stretched
// row over the layers ([_bandTop]). The scale, and with it the view's width, is the field's as before.
const frontLip = 146.0, fieldFoot = 21.2;

/// Copies of a picture [w] world units wide and [h] tall, its row 0 at [top], moved [offset] left (modulo [w]): side by
/// side from at or left of the view's left edge to past its right one ([viewW] wide), each 0.5 wider than a repeat, so
/// neighbours overlap without a seam.
List<Rect> _repeats(double offset, double viewW, double w, double top, double h) =>
    [for (var x = -(offset % w); x < viewW; x += w) Rect.fromLTWH(x, top, w + 0.5, h)];

/// The band's layers as drawn with the camera's left edge at [cam] and a view [viewW] wide (world units; x from the
/// view's left edge, y from the band's top): far to near, each file and its copies ([_repeats]) over the whole view.
List<({String image, List<Rect> copies})> backdropLayers(double cam, double viewW) => [
      for (final (i, image) in townLayers.reversed.indexed)
        (image: image, copies: _repeats(cam * _parallax[i], viewW, townLayerW * _layerK, _bandTop, townLayerH * _layerK)),
    ];

/// The clouds' copies (battle_clouds.png) as drawn from [cam], [viewW] wide, at [clock] seconds of drift, in
/// [backdropLayers]' units, their row 0 at band y [top]: the screen's top (the welcome screen's [fieldFoot]; the field's
/// as its framing has it, decisions-log 287).
List<Rect> cloudCopies(double cam, double viewW, double clock, [double top = fieldFoot]) =>
    _repeats(cam * _cloudK + clock * _cloudDrift, viewW, battleCloudsW * _layerK, top, battleCloudsH * _layerK);

/// The props line's copies (battle_props.png) as drawn from [cam], [viewW] wide, in [backdropLayers]' units.
List<Rect> propsCopies(double cam, double viewW) =>
    _repeats(cam * _propsK, viewW, battlePropsW * _layerK, 0, battlePropsH * _layerK);

/// The floor's copies (battle_floor.png) as drawn from [cam], [viewW] wide, in [backdropLayers]' units: moving with the
/// field, from band y [_floorTop] to [fieldFoot] under the field's bottom.
List<Rect> floorCopies(double cam, double viewW) =>
    _repeats(cam, viewW, battleFloorW * _layerK, _floorTop, battleFloorH * _layerK);

/// Visible pixels of each troop's book sprite (`book_<type>_idle`, union over its frames, in frame coords), so the book row can fit them uncropped;
/// and of each monster's idle strip, for the boss bars' portraits (boss_bar.dart).
final _idleBounds = <String, Rect>{};

bool _derivedBuilt = false; // [TdGame.onLoad] has built the derived images

/// [idle] with every pixel of [shadow]'s colour cleared: the book's sprites, and the Soldier's strips. Only the
/// pack's Soldier has its shadow baked into its strips (see assets.md); no body uses the shadow colour.
Future<ui.Image> _unshadowed(ui.Image idle, ui.Image shadow) async {
  final px = (await idle.toByteData(format: ui.ImageByteFormat.rawRgba))!;
  final sh = (await shadow.toByteData(format: ui.ImageByteFormat.rawRgba))!;
  final ink = {for (var i = 0; i < sh.lengthInBytes; i += 4) if (sh.getUint8(i + 3) != 0) sh.getUint32(i)};
  for (var i = 0; i < px.lengthInBytes; i += 4) {
    if (ink.contains(px.getUint32(i))) px.setUint32(i, 0);
  }
  final done = async.Completer<ui.Image>();
  ui.decodeImageFromPixels(px.buffer.asUint8List(px.offsetInBytes, px.lengthInBytes), idle.width, idle.height,
      ui.PixelFormat.rgba8888, done.complete);
  return done.future;
}

/// [src] with the colour of every visible pixel passed through [tint] (worked out once per colour).
Future<ui.Image> _recoloured(ui.Image src, Color Function(Color) tint) async {
  final px = (await src.toByteData(format: ui.ImageByteFormat.rawRgba))!, done = <int, int>{};
  for (var i = 0; i < px.lengthInBytes; i += 4) {
    final rgba = px.getUint32(i);
    if (rgba & 0xFF == 0) continue;
    px.setUint32(i, done[rgba] ??= () {
      final argb = tint(Color((rgba & 0xFF) << 24 | rgba >>> 8)).toARGB32();
      return (argb & 0xFFFFFF) << 8 | argb >>> 24;
    }());
  }
  final out = async.Completer<ui.Image>();
  ui.decodeImageFromPixels(px.buffer.asUint8List(px.offsetInBytes, px.lengthInBytes), src.width, src.height,
      ui.PixelFormat.rgba8888, out.complete);
  return out.future;
}

/// The healing necromancer's colours on the boss's strips: the navy robe turns teal, the grey-green hood
/// lining and spell gold, the red eyes pale green; the rest (scythe, bone, outline) stays.
Color _necroHealerTint(Color c) {
  final hsl = HSLColor.fromColor(c);
  final (h, s, l) = (hsl.hue, hsl.saturation, hsl.lightness);
  Color to(double hue, double sat, double light) => HSLColor.fromAHSL(hsl.alpha, hue, sat, light).toColor();
  if (h >= 205 && h <= 270 && s >= 0.05) return to(168, (s * 3.2).clamp(0.35, 0.7), (l * 1.35 + 0.1).clamp(0, 0.8));
  if (h >= 80 && h <= 140 && s >= 0.08) return to(46, (s * 3.5).clamp(0.45, 0.85), (l * 1.3 + 0.18).clamp(0, 0.85));
  if ((h >= 340 || h <= 12) && s >= 0.8 && l >= 0.4) return to(120, 0.9, 0.7);
  return c;
}

/// A troop healer's smite on a dark monster: the heal burst's two greens as white light, the darker one
/// silver and the lighter one white. Always these colours, at every awakening: an awakened healer's heal
/// is tinted a strong blue, crimson or gold ([_awakeColors]) and the plain one is green, so a colourless
/// burst never looks like a heal.
Color _holyTint(Color c) =>
    (HSLColor.fromColor(c).lightness < 0.68 ? const Color(0xFFC4CCD8) : const Color(0xFFFFFFFF)).withValues(alpha: c.a);

Future<Rect> _opaqueBounds(ui.Image img) async {
  final px = (await img.toByteData(format: ui.ImageByteFormat.rawRgba))!, fs = img.height;
  var (l, t, r, b) = (fs, fs, 0, 0);
  for (var y = 0; y < img.height; y++) {
    for (var x = 0; x < img.width; x++) {
      if (px.getUint8((y * img.width + x) * 4 + 3) == 0) continue;
      final fx = x % fs;
      (l, t, r, b) = (math.min(l, fx), math.min(t, y), math.max(r, fx + 1), math.max(b, y + 1));
    }
  }
  return Rect.fromLTRB(l.toDouble(), t.toDouble(), r.toDouble(), b.toDouble());
}

/// The book's padding (decisions-log 198; the owner: "book ui di kasi padding 10px dan 5px", the CSS shorthand): between
/// each page's printed line and what is written on it, [bookPadY] at the top and the bottom, [bookPadX] at the sides, in
/// the book's pixels (a phone's screen px; on a bigger book times its pixel scale, as the book's own art). Every page
/// writes inside it ([bookWriting]).
const bookPadY = 10.0, bookPadX = 5.0;

/// Where a page writes: its [paper] (inside the printed line) less the book's padding, at [ps] screen px per book px.
Rect bookWriting(Rect paper, double ps) =>
    Rect.fromLTRB(paper.left + bookPadX * ps, paper.top + bookPadY * ps, paper.right - bookPadX * ps, paper.bottom - bookPadY * ps);

/// The least a shut page tab of the book takes a press each way ([bookTabTap]): the tap rule's 44 px, as the Army
/// detail's foot ([detailTapMin]) and the spawn bar's cards (decisions-log 301).
const bookTabTapMin = 44.0;

/// The [i]th page tab's left from the book's left edge at its pixel scale [ps]: 20 book px in, then one every 22 book px,
/// or every [bookTabTapMin] px where that is more (a book at 1 screen px a book px, as at 915x412; decisions-log 301), so
/// each tab's press area is the tap rule's and none lies over the next.
double bookTabLeft(int i, double ps) => 20 * ps + i * math.max(22 * ps, bookTabTapMin);

/// A shut page tab's press area for its part outside the book [hit] (decisions-log 301): [bookTabTapMin] each way at
/// least, about the tab's middle across, and down over the cover's edge as far as [low] (where the pages' writing
/// starts: it takes no press of a page's), then up for the rest.
Rect bookTabTap(Rect hit, double low) {
  final w = math.max(hit.width, bookTabTapMin), h = math.max(hit.height, bookTabTapMin);
  final bottom = math.max(hit.bottom, math.min(low, hit.top + h));
  return Rect.fromLTRB(hit.center.dx - w / 2, bottom - h, hit.center.dx + w / 2, bottom);
}

/// Whether a phone's game pauses when it goes to the background (decisions-log 146): on Android and iOS the app
/// hidden or in the background pauses the game, as the Start/Pause toggle does, and it stays paused when the player comes
/// back. Off, a phone's game goes on in the background as a desktop's hidden window does (#93), until the phone ends
/// it.
const pauseInBackgroundOnMobile = true;

/// Whether a phone's sound goes quiet in the background (decisions-log 147): on Android and iOS the app hidden or in
/// the background holds the music and the effects where they are ([Sounds.background]), and coming back lets them go
/// on, the music where it was, at the player's own volumes, while the game stays paused. Off, a phone's sound plays on
/// in the background, as a desktop's hidden window's does (#93).
const muteInBackgroundOnMobile = true;

/// Whether this app runs on a phone (the switches above): Android or iOS; not the desktop, nor the web, whose browser
/// may be a phone's ([defaultTargetPlatform] then says android). Tests set `debugDefaultTargetPlatformOverride` (a
/// `TargetPlatformVariant`): without it `flutter test` says android.
bool get _onPhone => !kIsWeb && const {TargetPlatform.android, TargetPlatform.iOS}.contains(defaultTargetPlatform);

/// Whether going to the background pauses this game ([pauseInBackgroundOnMobile]).
bool get _pausesInBackground => pauseInBackgroundOnMobile && _onPhone;

/// Whether going to the background quiets this game's sound ([muteInBackgroundOnMobile]).
bool get _mutesInBackground => muteInBackgroundOnMobile && _onPhone;

/// A phone's game runs full screen (decisions-log 215): on Android and iOS the status bar and the navigation or gesture
/// bar hide, and a swipe in from the screen's edge shows them over the game for a moment
/// ([SystemUiMode.immersiveSticky]). Asked at launch and again whenever the app comes back to the front. The desktop's
/// window stays as it is.
void _fullScreenOnPhone() {
  if (_onPhone) async.unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky));
}

/// What a phone's screen keeps from the game at each edge, in logical px: its display cutout (a notch, a camera hole) or
/// rounded edge, and the system bars while they show (the view's padding; Android adds the cutout's safe insets). The
/// HUD keeps inside it (decisions-log 215); in a letterbox only what reaches into the game's box, in its px
/// ([letterboxInsets]). Zero on the desktop, so its layout is the same at every window size.
EdgeInsets _safeInsets() {
  final view = WidgetsBinding.instance.platformDispatcher.implicitView;
  if (!_onPhone || view == null) return EdgeInsets.zero;
  final dpr = view.devicePixelRatio;
  return letterboxInsets(view.physicalSize / dpr, dpr, EdgeInsets.fromViewPadding(view.viewPadding, dpr));
}

class TdGame extends FlameGame with KeyboardEvents, ScrollDetector {
  TdGame() {
    // A phone's game pauses in the background (decisions-log 146); a desktop's hidden window goes on (pause.dart).
    pauseWhenBackgrounded = _pausesInBackground;
  }

  final board = Board();
  async.Timer? _behind; // runs the game while the window is hidden and Flutter draws no frames (pause.dart)
  bool _behindStep = false; // one of its updates is on: the frames' own are dropped while it runs

  /// Whether a timer runs the game, the window being hidden (pause.dart). For tests.
  bool get runsHidden => _behind != null;

  /// The window hid or showed again, or the app went to the background (pause.dart). On a phone
  /// ([pauseWhenBackgrounded], decisions-log 146) the game pauses as the player's own pause, and Flame stops its loop
  /// until the app comes back; elsewhere, hidden, a timer runs the game, since Flutter draws no frames (#93). Hidden or
  /// in the background, the game is also saved between waves ([Board._toBackground]). On a phone the sound holds
  /// meanwhile, on the welcome screen too, and goes on when the app shows again ([_mutesInBackground], decisions-log
  /// 147). Back in front, a phone's system bars hide again ([_fullScreenOnPhone], decisions-log 215).
  @override
  void lifecycleStateChange(AppLifecycleState state) {
    super.lifecycleStateChange(state);
    if (state == AppLifecycleState.resumed) _fullScreenOnPhone();
    final away = state == AppLifecycleState.hidden || state == AppLifecycleState.paused;
    if (!pauseWhenBackgrounded) {
      _runHidden(state);
    } else if (away) {
      // Mid-wave or between waves (the auto start's countdown then waits): nothing is fought or started while the
      // player is away, and the game stays paused when they come back, even if the book had paused it.
      board._ownPause();
    }
    if (away) board._toBackground();
    // Detached (the engine runs on, its view gone) holds the sound too.
    if (_mutesInBackground) Sounds.background(away || state == AppLifecycleState.detached);
  }

  /// A frame's update; dropped while the timer runs the game (pause.dart), so no frame counts twice.
  @override
  void update(double dt) {
    if (_behind != null && !_behindStep) return;
    super.update(dt);
  }

  @override
  void onDispose() {
    _stopBehind(restart: false);
    super.onDispose();
  }

  /// The mouse wheel: over the open battle log it scrolls it (battle_log.dart), over the Tas page's list that and over
  /// its grid it turns a page (bag.dart), over the Army page's grid a page and over its detail's body that
  /// (troops_page.dart), over the Smithy's facing page or a Tavern page that (page_scroll.dart), over the spawn bar's
  /// cards a page of them (spawn_bar.dart), over a Lisensi or Cara Main page its column (licence_page.dart), over a
  /// Town's scene it pans it sideways (town_scene.dart); under a guide card or a foe skill's splash nothing.
  /// The wheel's turn is in the screen's px: in a letterbox (letterbox.dart) it is mapped through the box's scale as its
  /// place is, so a turn moves a list as far on the screen as anywhere else.
  @override
  void onScroll(PointerScrollInfo info) {
    if (board._coach.showing || board._foeSplashBusy) return; // nothing under a guide card (coach.dart) or a foe splash scrolls
    final at = info.eventPosition.widget.toOffset();
    final d = (convertGlobalToLocalCoordinate(info.scrollDelta.global) - convertGlobalToLocalCoordinate(Vector2.zero())).toOffset();
    board
      .._logWheel(at, d.dy)
      .._assignWheel(at, d.dy)
      .._armyWheel(at, d.dy)
      .._pageScrollWheel(at, d.dy)
      .._barWheel(at, d)
      .._licenceWheel(at, d.dy)
      .._townWheel(at, d);
  }

  @override
  KeyEventResult onKeyEvent(KeyEvent event, Set<LogicalKeyboardKey> keysPressed) =>
      event is KeyDownEvent && (board._pauseKey(event.logicalKey) || board._pocketKey(event.logicalKey)) ? KeyEventResult.handled : KeyEventResult.ignored;

  @override
  Future<void> onLoad() async {
    await images.loadAll([
      'battle_floor.png',
      'battle_props.png',
      'battle_clouds.png',
      for (final k in [...troopTypes.keys, ...enemyTypes.keys, boss])
        for (final a in [..._anims, 'shadow']) 'tiny_${k}_$a.png',
      for (final k in _arrows) 'tiny_arrow_$k.png',
      for (final k in _feetFx)
        if (k != 'holy') 'tiny_fx_$k.png',
      for (final m in WizardMagic.values) m.sheet, // the wizard's magic (wizard_fx.dart)
      for (final k in _summoners) 'tiny_${k}_summon.png',
      for (final (k, a) in skillStripFiles()) // the skill strips (skill_strips.dart); the necro healer's are made below
        if (k != necroHealer) 'tiny_${k}_$a.png',
      for (final k in [...troopTypes.keys, ...enemyTypes.keys, boss])
        if (!(troopTypes[k]?.heals ?? false)) 'fx_hit_$k.png',
      'fx_upgrade.png',
      for (final i in Item.values) 'item_${i.name}.png',
      for (final m in Mat.values) 'mat_${m.name}.png', // the Towns' materials (town.dart)
      for (final k in PocketKind.values) 'pocket_${k.name}.png', // the pocket items (pocket.dart)
      // Every relic's and every Shadow's icon sheet (pusaka_catalog.dart's [relicIcon], omen.dart's [OmenKind.icon]:
      // Off Beat's War Drum, no relic's icon since the Artifacts' atlas; ui_icons.png is below).
      for (final sheet in {for (final r in Relic.values) relicIcon(r).sheet, for (final k in OmenKind.values) ?k.icon?.sheet})
        if (sheet != 'ui_icons.png') sheet,
      'ui_book.png',
      'ui_book_marks.png',
      'ui_bars.png',
      'ui_all.png',
      'ui_buttons.png',
      'ui_icons.png',
      'ui_click.png',
      'ui_tooltip.png',
      'ui_ribbons.png',
      'ui_hotbar.png', // the spawn bar's hotbar (spawn_bar.dart)
      'battle_step.png', // the step under it (spawn_bar.dart)
      'town_mark.png', // the Towns' hammer (town_look.dart)
      'town_mug.png', // the wave meter's beer mug in a Town (town_look.dart)
      ...townImages, // the Town scene (town_scene.dart); its layers are the battle's band too (_scenery)
      townSmith, // the Town's smith in the Smithy (town_smith.dart)
    ]);
    // The images derived from the sheets (unshadowed, outlined, recoloured) live in process-wide caches
    // ([Flame.images], [_outlines], [_idleBounds]): built once, so a second game in one process (a widget test
    // boots one per test) skips ~6 s of pixel work.
    if (!_derivedBuilt) {
      for (final k in troopTypes.keys) {
        final shadow = images.fromCache('tiny_${k}_shadow.png');
        for (final a in [..._anims, ..._skillAnims(k)]) {
          final strip = 'tiny_${k}_$a.png';
          // The Soldier's strips have its shadow baked in (assets.md): cleared, so it has one shadow like
          // everyone, the one drawn under it (which takes an awakening colour), and none under its drag ghost
          // (test/sprites_test.dart).
          if (k == 'soldier') images.add(strip, await _unshadowed(images.fromCache(strip), shadow));
          // The wizard's attack 2 glows in Arcane Blast's blues, not the pack's orange (wizard_fx.dart).
          if (k == 'wizard' && a == 'attack2') images.add(strip, await _recoloured(images.fromCache(strip), _arcaneStaff));
          _outlines[strip] = await _outlined(images.fromCache(strip)); // awakening's outline (awakening.dart)
        }
        final idle = await _unshadowed(images.fromCache('tiny_${k}_idle.png'), shadow);
        images.add('book_${k}_idle', idle); // in memory only; the field keeps drawing tiny_<k>_idle.png
        _outlines['book_${k}_idle'] = await _outlined(idle);
        _idleBounds[k] = await _opaqueBounds(idle);
      }
      // The monsters' too, for the boss bars' portraits (boss_bar.dart).
      for (final k in [...enemyTypes.keys, boss]) {
        _idleBounds[k] = await _opaqueBounds(images.fromCache('tiny_${k}_idle.png'));
      }
      // The healing necromancer is the boss recoloured, in memory only (there are no tiny_necro_healer_*
      // files): it casts its heals with the boss's summoning strip and swings the boss's scythe. Its shadow
      // is a clone of the boss's (a handle of its own: the cache disposes each name's image once).
      for (final a in [..._anims, 'cast', 'shadow', ..._skillAnims(necroHealer)]) {
        final from = images.fromCache('tiny_${boss}_${a == 'cast' ? 'summon' : a}.png');
        images.add('tiny_${necroHealer}_$a.png', a == 'shadow' ? from.clone() : await _recoloured(from, _necroHealerTint));
      }
      images.add('tiny_fx_holy.png', await _recoloured(images.fromCache('tiny_fx_heal.png'), _holyTint));
      // The field's rings, the Hero's halo and the reach, in the sprites' pixels (pixel_shapes.dart).
      await _buildPixelShapes();
      // Every monster strip's outline too, drawn in its rank's colour (tier_look.dart).
      for (final k in [...enemyTypes.keys, boss, necroHealer]) {
        for (final a in [..._anims, if (_summoners.contains(k)) 'summon', if (_casters.contains(k)) 'cast', ..._skillAnims(k)]) {
          _outlines['tiny_${k}_$a.png'] = await _outlined(images.fromCache('tiny_${k}_$a.png'));
        }
      }
      _derivedBuilt = true;
    }
    add(board);
    // A trackpad's two-finger swipe comes as a pan, not a scroll (Flutter's trackpad gestures): sideways over a Town's
    // scene it pans it (town_scene.dart, decisions-log 264). Trackpads only, so a mouse's or a finger's drag stays the
    // Board's own.
    gestureDetectors.register<HorizontalDragGestureRecognizer>(
      () => HorizontalDragGestureRecognizer(supportedDevices: {ui.PointerDeviceKind.trackpad}),
      (r) => r
        ..onStart = ((d) => board._townSwipe(d.localPosition))
        ..onUpdate = ((d) => board._townSwiped(d.delta.dx))
        ..onEnd = ((d) => board._townLetGo(d.velocity.pixelsPerSecond, swipe: true))
        ..onCancel = (() => board._townLetGo(Offset.zero, swipe: true)),
    );
  }
}

/// The book's pages, one per tab on its top edge, in the tabs' order: Pasukan (the troops), Tas (the bag) and Settings;
/// and Licenses (licence_page.dart) and How to Play (guide_page.dart), opened from Settings, whose tab stays the open
/// one. In a Town the Smithy, the Tavern and the Shop ([store]: the Town's, shop_page.dart) in place of the Army
/// (town_scene.dart's [_bookTabs]; tavern_page.dart). The field's Toko (a game without the Towns) went in decisions-log
/// 296.
enum _Page { troops, bag, store, settings, licence, guide, smithy, tavern }

class Board extends PositionComponent
    with HasGameReference<TdGame>, TapCallbacks, SecondaryTapCallbacks, DragCallbacks, PointerMoveCallbacks {
  // The field fills the screen and the book floats over its right side between waves (landscape only, decisions-log
  // 289: a view taller than wide letterboxes the game, letterbox.dart).
  double _bookT = 0; // 0 closed .. 1 open, eased after [_bookWanted]
  bool _bookOpened = false; // opened by hand mid-battle (the book button)
  bool _waveWas = false; // a wave on last frame: one beginning shuts a hand-opened book
  var _page = _Page.troops; // the book's open tab (bookmark)
  // The loot in hand (#86), an Item or a Relic: picked in the bag with a tap, or kept after a drop while the bag
  // holds more. The facing page lists who takes it (bag.dart); a tap on a troop on the field gives it
  // (drop_popup.dart). It stays picked after each one given until the bag runs out of it or it is put back. An enhanced
  // item's stack (decisions-log 255) is picked at its plus ([_pickPlus]); everything else at 0.
  BagLoot? _pickedAt;
  BagLoot? _storePickAt; // the goods picked in the Town's Shop: the facing page is its rows (bag.dart, shop_page.dart)
  Enum? get _picked => _pickedAt?.kind;
  set _picked(Enum? kind) => _pickedAt = kind == null ? null : (kind: kind, plus: 0);
  int get _pickPlus => _pickedAt?.plus ?? 0;
  Enum? get _storePick => _storePickAt?.kind;
  set _storePick(Enum? kind) => _storePickAt = kind == null ? null : (kind: kind, plus: 0);
  // The game being played, picked on the welcome screen. Every game the board starts or loads plays with the owner's
  // limits on ([Game.boardRules]: 36 troops, a cap per troop type, the Auto hold; decisions-log 141, 201, 260).
  var state = Game().boardRules();
  Welcome? welcome = Welcome(launchSave()); // the welcome screen while it shows (on launch, [showWelcome]); a save from before the Towns is gone
  bool _welcomeTap = false; // the last press began on the welcome screen: its tap up and drag stay there
  final _welcomeAt = <String, Rect>{}; // its buttons this frame, by label (welcome.dart)
  double get camX => state.cam; // the game moves the camera (it keeps the battle mid-screen)
  int speed = 1;
  double _clock = 0, _savedWin = double.negativeInfinity, _savedWipe = double.negativeInfinity;
  String? dragging; // the type of [_relocating]
  Unit? _relocating; // troop on the field being dragged to a new spot before the wave
  Vector2? dragAt;
  Offset _dragPos = Offset.zero; // where the pointer is in the drag going on ([onDragUpdate])
  Item? _itemDrag; // item being dragged from the inventory onto a troop
  int _dragPlus = 0; // and its plus: an enhanced stack's (decisions-log 255)
  Relic? _relicDrag; // relic being dragged from the bag onto one troop
  Offset? _mouse; // where the mouse hovers, for the cursor
  Offset? _handAt; // the pointer's last place, mouse or finger: the loot in hand is drawn there (drop_popup.dart)
  bool _touch = false; // the last press or drag was a finger's, not the mouse's
  ButtonPress? _press; // the last press: the button it went down on shows pushed in, and the pointer presses (button_fx.dart)
  final _tip = _Tips(); // the loot tooltip (tooltip.dart)
  Unit? _pinned; // the unit whose plate stays up over it (plates.dart)
  Rect _pinnedAt = Rect.zero; // its plate, where it was drawn this frame
  final _plateTaps = <(Rect, VoidCallback)>[]; // its Lepas buttons this frame, one per relic its troop holds (#91)
  final _drop = _DropShown(); // the drop popup over the troop the loot in hand would go to (drop_popup.dart)
  final _msg = _Message(); // the message window (message.dart)
  final _lifeState = _Lives(); // the hearts' pop (lives.dart)
  final _herald = _Herald(); // a new Hero's splash screen (hero_splash.dart)
  final _coach = _Coach(); // the first-time guide: its cards and pointers (coach.dart)
  final _chest = _ChestView(); // the boss chest's popup and its "Peti!" chip (chest_popup.dart)
  final _wipeAsk = _WipeAskView(); // after a wipe: Try again or Give up (wipe_ask.dart)
  final _omenRow = _OmenRow(); // the Shadows' chips under the wave meter (omen_look.dart)
  final _troops = _TroopList(); // the troop counter's list (troop_counter.dart)
  final _release = _Release(); // Release on the Army page's detail: armed, its confirm (troop_row.dart)
  final _army = _ArmyPage(); // the Army page: the type picked, the grid's page and pager (troops_page.dart)
  final _detail = _Detail(); // the Army page's right page: the picked type's sections and buttons (troop_detail.dart)
  final _wish = _WishView(); // the Army detail's Wishlist: whose picker is open (wishlist_look.dart, decisions-log 282)
  final _bar = _SpawnBar(); // the spawn bar at the bottom of the battle screen: its scroll and cards (spawn_bar.dart)
  final _pocket = _PocketBar(); // the pocket bar at the field's right edge: its slots (pocket_look.dart)
  final _log = _BattleLog(); // the battle log (battle_log.dart)
  final _assign = _AssignList(); // the Tas page's list: who takes the picked loot, its filter and scroll (bag.dart)
  final _bag = _BagGrid(); // the Bag's grid: its category, page, NEW marks and cells (bag.dart)
  final _shop = _ShopView(); // the Town's Shop: its Buy and Sell boards, tab and sell basket (shop_page.dart, decisions-log 230 and 269)
  final _smithy = _SmithyView(); // the Town's Smithy pages: the relic picked, its two grids (smithy_page.dart, decisions-log 235)
  final _tavernPage = _TavernView(); // the Town's Tavern pages: the offer picked, the offers seen (tavern_page.dart, decisions-log 267)
  final _score = _Scores(); // the scoreboard (scoreboard.dart)
  final _pause = _Pause(); // the pause, what the book has to do with it, and its overlay (pause.dart)
  final _lic = _LicenceView(); // the Lisensi page: the packages read, the one open, both columns' scroll (licence_page.dart)
  final _guide = _GuideView(); // the Cara Main page: the open topic, both columns' scroll (guide_page.dart)
  final _town = _TownView(); // the Town scene: shown or fading, its pan, where its pieces were drawn (town_scene.dart)
  final _townLife = TownLife(); // the troops in a Town, on its own visual dice (town_life.dart)
  EdgeInsets _safe = EdgeInsets.zero; // what a phone's screen keeps at its edges this frame ([_safeInsets]; zero on the desktop)
  Rect _bookArea = Rect.zero; // the open book on the screen this frame: troops under it show no nameplate
  (Rect, Rect) _pagesAt = (Rect.zero, Rect.zero); // where the open book's two pages write this frame ([bookWriting])
  double _bookHigh = 0; // the open book's top at the top of its bob: "Pause" keeps above it (pause.dart)
  double _bookBob = 0, _bookBobK = 0; // how far the book bobs down this frame, and at most (the open battle log's [_logKeep])
  final _bookShadowRows = <Rect>[]; // the book's shadow's rows as drawn this frame ([_bookShadow])
  final _bookShadowPaint = Paint()..isAntiAlias = false; // and its paint, its alpha set each frame
  final _logKeep = <Rect>[]; // the book's buttons the open battle log keeps clear of this frame, without the bob (battle_log.dart)
  Rect _toggleAt = Rect.zero; // the Start/Pause toggle as drawn this frame (start_button.dart)
  Rect _startAt = Rect.zero; // the toggle this frame while it starts a wave (start_button.dart)
  final _toggle = _ToggleState(); // what the toggle did last frame, and when a wave last began under it
  Rect _meterAt = Rect.zero; // the wave meter's panel this frame (wave_meter.dart; none at game over)
  Rect _townChipAt = Rect.zero; // the wave meter's Town chip this frame (town_look.dart; none without a Town marked)
  Rect _weakChipAt = Rect.zero; // its "Weakened foes" chip under the boosts' (wipe_ask.dart; none while foes are themselves)
  final _boostChipsAt = <Rect>[]; // the boosts' chips under it this frame, in [Game.boosts]' order (tavern_look.dart)
  Rect _boostRowAt = Rect.zero; // all of them (none: Rect.zero), what the log, the boss bars and the plates keep clear of
  String _townMeterText = ''; // the wave meter's words in a Town this frame (town_look.dart; '' out of one)
  Rect _townArrivalAt = Rect.zero; // the Town's name's ribbon this frame (town_look.dart; Rect.zero: none)
  Rect _tideAt = Rect.zero; // the wave meter while it shows the tide's badge (zero: before the tide), its tooltip's target
  String _tideLabel = '';
  Rect _replaceAt = Rect.zero; // "Replace fallen" on the Army page this frame (zero: not shown)
  late final _map = _MiniMap(_settings.miniMap); // the minimap under it (mini_map.dart)
  Rect _heartsGoldAt = Rect.zero; // the hearts' and the gold's panel, last drawn (hud_row.dart)
  Rect _livesAt = Rect.zero, _goldAt = Rect.zero; // its hearts' part and its gold's (hud_row.dart, lives.dart)
  Rect _speedAt = Rect.zero, _autoAt = Rect.zero; // x2 and Auto, left of the wave meter, this frame (hud_row.dart)
  Rect _pauseAt = Rect.zero; // the toggle this frame while it pauses or resumes (start_button.dart)
  Rect _autoHeldAt = Rect.zero; // the toggle's Auto hold line this frame (start_button.dart)
  Rect _offViewAt = Rect.zero; // the marker for troops left of the view this frame (off_view.dart)
  final _fpsMeter = FpsMeter(); // the frames of the last second, while "Show FPS" is on (fps_readout.dart)
  Rect _fpsAt = Rect.zero, _fpsButtonAt = Rect.zero; // the readout and Settings' "Show FPS" this frame
  final _bodies = <Unit, _Body>{}; // where each troop is drawn (body_look.dart)
  Game? _bodiesFor; // the game they are of
  double _bodiesT = 0; // its clock at the last step
  final _strips = <Unit, String>{}; // the strip each troop was drawn with this frame ("walk", "idle", "attack", ...)
  final _textPaints = <(String, double, Color, bool), TextPaint>{}; // [_textPaint]'s, one per text and look
  static const _textPaintsMost = 2000;
  final _magicDrawn = <(WizardMagic, int, int)>[]; // the wizard's magic drawn this frame (wizard_fx.dart; for tests)
  Rect _storeTabAt = Rect.zero; // the shut Shop tab this frame (a Town's)
  final _tabAt = <_Page, Rect>{}; // every page tab this frame, shut or open (for tests)
  final _tabTapAt = <_Page, Rect>{}; // where each shut tab takes a press this frame ([bookTabTap]; for tests)
  final _storeAt = <Object, Rect>{}; // the Tas and Army tabs' dots ('bagDot', 'armyDot') and a Town's Tavern tab's ('tavernDot') this frame
  Rect _sendAt = Rect.zero, _menuAt = Rect.zero; // "Kirim data permainan" and "Menu Utama" this frame (the Pengaturan page)
  final _volumeAt = <Rect>[]; // its volume rows this frame, Musik and Efek (- the bar +)
  Rect _sendNoteAt = Rect.zero, _heroCutAt = Rect.zero; // the line under the former, and "Sorotan Hero" (the same page)
  Rect _bossAt = Rect.zero; // the boss bars this frame, all of them (boss_bar.dart); a plate and the log keep clear
  bool _bossAside = false; // they are at the left, compact, the book being open in landscape (boss_bar.dart)
  Rect _bookBtnAt = Rect.zero; // the top left row's book button this frame (landscape, during a wave)
  Game? _autoFor; // the game the auto start's countdown belongs to
  final _cutIns = CutIns<(Unit, HeroSkill)>(key: (c) => c.$1); // a Hero's cast cut-ins (hero_cast.dart)
  final _heroCutGate = HeroCutGate(); // which Hero casts get a cut-in (cut_ins.dart, decisions-log 298)
  final _firstCasts = FirstCasts(); // which casts pop their skill's name: a troop's first of each skill a wave (cut_ins.dart)
  // A monster champion's skill banners (foe_cut_in.dart): one per skill and rank, a mini boss's and the boss's first.
  final _foeCuts = CutIns<FoeCut>(
      key: (c) => (c.$2, c.$3), time: foeCutTime, most: foeCutWaiting, front: (c) => c.$3.index >= Tier.miniBoss.index);
  final _foeLook = _FoeCutLook(); // which casts get one, and where it was drawn (foe_cut_in.dart)
  final _foeSplash = _FoeSplash(); // a monster skill's first-sighting splash, the field frozen under it (foe_splash.dart)
  final _pusakaLook = _PusakaLook(); // the bound types this frame and the Grail's cut-in (pusaka_look.dart)
  final _hits = <(Rect, VoidCallback)>[];
  final _cards = <(Rect, String)>[]; // the Army page's type cells this frame (troop_row.dart)
  final _rowStatTexts = <String, List<String>>{}; // the Army page's picked type's eight stats as drawn this frame (troops_page.dart)
  final _tempaMarks = <(Rect, String)>[]; // each Tempa "+n" after a type's stars this frame: where, and its text (ascend_page.dart)
  final _carveBadges = <(Rect, String)>[]; // each badge with Carve's gold "+n" drawn this frame: where, and its words (badge.dart)
  final _tasStatTexts = <String, (String, String)>{}; // each Tas Pusaka row's first change, now and after, as drawn, by type (bag.dart)
  final _slots = <(Rect, Item, int)>[]; // the Bag's item cells this frame and each one's plus (0; an enhanced stack's 1 to 5)
  final _relicSlots = <(Rect, Relic)>[];
  final _matSlots = <(Rect, Mat)>[]; // the Bag's material cells this frame (bag.dart; the Towns, town.dart)
  final _pocketCells = <(Rect, PocketKind)>[]; // and its pocket items' (bag.dart; decisions-log 332)
  final _capsuleBars = <Rect>[]; // each list's scroll bar drawn this frame, its track (bag.dart's [_capsuleBar])
  bool _bagShown = false; // the book drew the Tas page this frame ([bagOpen])
  final _bursts = <(Offset, String, double)>[]; // where, which effect, started at
  final _pops = <(Unit, String, double, _PopKind)>[]; // skill names over their casters: who, which, started at, whose (skills.dart)
  final _goldPops = <(math.Point<double>, int, double)>[]; // Plunder's extra kill gold: where, how much, started at (skills.dart)
  final _matPops = <_MatHop>[]; // a material dropped, hopping onto its pile (town_look.dart)
  final _matLoot = <_MatPile>[]; // the materials lying on the field until the wave is won, then flying to the Bag (town_look.dart)
  double _momentAt = double.negativeInfinity; // when a boss's moment last began winding up (game clock; skills.dart)
  final _clicks = <(Offset, double)>[]; // click sparks: where, started at (screen, [_clock])
  final _px = Paint()..filterQuality = FilterQuality.none;
  final _plusPaints = <(int, double, double), Paint>{}; // an enhanced item's icon paints by tint, its alpha and fade ([_plusPaint])
  /// A unit's plain ground shadow (the field's; the Town draws none, decisions-log 270): the sprite's own shadow drawn this opaque, so it blends into the grass.
  final _shadowPaint = Paint()
    ..filterQuality = FilterQuality.none
    ..color = Colors.white.withValues(alpha: unitShadowAlpha);
  final _bg = Paint()..filterQuality = FilterQuality.medium; // the backdrops are drawn scaled down: smooth them
  final _ghost = Paint()
    ..filterQuality = FilterQuality.none
    ..color = const Color(0x99FFFFFF);

  // The field's scale: the screen's height over the scene's, or a little less on a short screen ([_HotGeom.scale],
  // spawn_bar.dart: the first lane's bars under the top band; decisions-log 287). Its width always spans the whole screen
  // (more columns show on wider screens). The scene is framed so the field's y [stepLip] lies on the spawn bar's step
  // ([_HotGeom.stepTop]): nothing on the field is ever drawn behind the bar (decisions-log 287; until then [fieldFoot]
  // higher, decisions-log 263). A Town changes neither: the field keeps its scale and its view while a Town shows.
  double get _scale => _hotGeom().scale;
  Offset get _origin => Offset(0, _hotGeom().stepTop - (backdropH + stepLip) * _scale);

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    this.size = size;
  }

  /// Where the Start/Pause toggle is this frame while it starts a wave: Rect.zero while it doesn't (it pauses or
  /// resumes, or after a game over). Its press area is k bigger all round. For tests.
  Rect get startButton => _startAt;

  /// The Start/Pause toggle as drawn this frame, whatever it does (Rect.zero: after a game over). For tests.
  Rect get toggleButton => _toggleAt;

  /// The boss chest's popup this frame (chest_popup.dart): whether it shows, its cards, the card picked (null: none), its
  /// buttons by name ('reroll', 'skip', 'take': Ambil, there greyed until a card is picked), the "Peti!" chip and the
  /// popup's ribbon (Rect.zero: not shown). For tests.
  bool get chestOpen => _chest.open;
  List<Rect> get chestCards => _chest.cards;
  int? get chestPicked => _chest.armed;
  Map<String, Rect> get chestButtons => _chest.buttons;
  Rect get chestChip => _chest.chip;
  Rect get chestRibbon => _chest.ribbon;

  /// A take's Shadow being revealed over the chest's popup (omen_look.dart): whether it shows, and its ribbon's line
  /// (null: none). The Shadows' chips under the wave meter this frame: the row (Rect.zero: none) and each chip with its
  /// kind (null: Lewati's skip buff). For tests.
  bool get chestRevealing => _chest.reveal != null;
  String? get chestRevealLine => _chest.reveal?.got;
  List<String> get chestFaces => [..._chest.faces]; // each card's Shadow: "?!!" hidden, "Armor 2" / "Dodged" revealed
  String get chestHint => _chest.hint; // the line under the chest's cards this frame
  Rect get omenRow => _omenRow.at;
  List<(Rect, OmenKind?)> get omenChips => [..._omenRow.chips];

  /// The unit whose plate is pinned over it (plates.dart), or null. For tests.
  Unit? get pinned => _pinned;

  /// The unit whose plate shows under the pointer now, or null. For tests.
  Unit? get hovered => _tip.shown ? switch (_tip.on?.$1) { final Unit u => u, _ => null } : null;

  /// World point [x] (along the road) and [y] (from the top of the field) on the screen.
  Offset toScreen(double x, double y) => _origin + Offset(x - camX, y + backdropH) * _scale;

  /// Where the Auto button is this frame, left of the wave meter (Rect.zero: not shown). For tests.
  Rect get autoButton => _autoAt;

  /// Where the marker for troops left of the view is this frame (Rect.zero: none shows). For tests.
  Rect get offViewMarker => _offViewAt;

  /// The FPS readout (fps_readout.dart): where it is this frame (Rect.zero: off, or no second counted yet), what it says
  /// (null before the first second), and Settings' "Show FPS" this frame (Rect.zero: the page doesn't show). For tests.
  Rect get fpsReadout => _fpsAt;
  String? get fpsText => _fpsMeter.text;
  Rect get fpsButton => _fpsButtonAt;

  /// Where troop [u] is drawn (body_look.dart; its game position while it has no body yet), and the strip it was drawn
  /// with this frame, its kind only: "walk", "idle", "attack", "cast", "hurt", "death", "attack2", ... (null: not
  /// drawn). For tests.
  math.Point<double> drawnAt(Unit u) => _at(u);
  String? stripOf(Unit u) => _strips[u];

  /// The wizard's magic drawn this frame (wizard_fx.dart), its shots in flight and their bursts: which sheet, which
  /// frame, and the awakening level whose colour tints it (0: the sheet's own colours; Bangkit 4 and 5 tint as 3).
  /// For tests.
  List<(WizardMagic, int, int)> get magicDrawn => List.unmodifiable(_magicDrawn);
  /// Where a Town's Shop tab takes a press this frame (Rect.zero: the book is shut, not in a Town, or open on the Shop).
  /// For tests.
  Rect get storeTab => _storeTabAt;

  /// The book's page tabs this frame, left to right: each page's name (`troops`, `bag`, `store`, `settings`) and
  /// its tab's part outside the book (none: the book is shut). For tests.
  List<(String, Rect)> get bookTabs =>
      [for (final e in _tabAt.entries.toList()..sort((a, b) => a.value.left.compareTo(b.value.left))) (e.key.name, e.value)];

  /// Where each shut page tab takes a press this frame ([bookTabTap]: the tap rule's 44 px each way at least), left to
  /// right by page name; the open one takes none. For tests.
  List<(String, Rect)> get bookTabTaps =>
      [for (final e in _tabTapAt.entries.toList()..sort((a, b) => a.value.left.compareTo(b.value.left))) (e.key.name, e.value)];

  /// The message window's line while it shows (null: none). For tests.
  String? get message => _msg.text;

  /// The Hero splash's title while it shows (null: none; hero_splash.dart). For tests.
  String? get heroSplash => switch (_herald.who) { final u? => _heraldTitle(u), _ => null };

  /// The first-time guide (coach.dart): the card showing, its key (`intro`, or a card's) and its page (0 first; null:
  /// none); its panel with the ribbon (Rect.zero: none); the intro's buttons by name ('skip', 'back', 'next'); the
  /// pointer showing (P1-P5; null: none), its box and what it points at (Rect.zero: none). For tests.
  (String, int)? get coachCard => switch (_coach.key) { final k? => (k, _coach.page), _ => null };
  Rect get coachPanel => _coach.panel;
  Map<String, Rect> get coachButtons => {..._coach.buttons};
  String? get coachPointer => _coach.pointer;
  Rect get coachPointerBox => _coach.pointerBox;
  Rect get coachPointerTarget => _coach.pointerTarget;

  /// Opens the guide's card [key] (`intro`, or a card's) from its first page, as the board does when it is due. For
  /// tests.
  void openGuide(String key) => _coachOpen(key);

  /// This device's seen set of the guide (settings.json; null: the guide is off, as in a widget test until it sets
  /// one). For tests.
  Set<String>? get guideSeen => _settings.seen;
  set guideSeen(Set<String>? seen) => _settings.seen = seen;

  /// The welcome screen's buttons this frame by id ('Lanjutkan', 'Main Baru', 'Papan Skor', 'Cara Main': ids that never
  /// change with the words, welcome.dart; none: it doesn't show). For tests.
  Map<String, Rect> get welcomeButtons => welcome == null ? const {} : {..._welcomeAt};

  /// The Grail's cut-in showing ("Grail menyelamatkan Kael Drake!"), or null; and the "VICTORY!" Pusaka line with its
  /// font and width at that font, or null (pusaka_look.dart). For tests.
  String? get grailCutIn => _grailCutText;

  /// The build name troop [type]'s Pasukan row drew this frame and where (null: none; pusaka_look.dart). For tests.
  (String, Rect)? rowBuildName(String type) => _pusakaLook.rows[type];
  ({String text, double size, double width})? get winPusakaLine => switch (_winLine(state, size.x - 40)) {
        (final t, final fs) => (text: t, size: fs, width: _textWidth(t, fs)),
        null => null,
      };

  /// Whether the book is turned to a Town's Shop. For tests.
  bool get storeShown => _page == _Page.store;

  /// The Town's Shop page's pick (decisions-log 230; null: none), with its plus (an enhanced stack's). Its tab's grid is
  /// [bagCells] and the rest of the Bag's getters while the Shop shows, a Buy pick's facing page [bagDetail] /
  /// [bagDetailText] ('buy', 'smithy', 'empty') and [bagActions]. For tests.
  Enum? get shopPick => _storePick;
  BagLoot? get shopPickAt => _storePickAt;

  /// The Town's Shop's Buy | Sell (shop_page.dart, decisions-log 269): the tab on and each segment (Rect.zero: not shown);
  /// Buy's section headings this page, each with where its words are (only the sections with goods, decisions-log 280);
  /// the sell basket (each stack and its count, in the order added; a copy) and its lines as drawn (each with its
  /// "2 x 1500 = 3000"); and the pages' parts by key and their words ([_ShopView.at]: Buy's 'nothing', its line with
  /// nothing on the shelf, decisions-log 280; the Sell Basket page's, decisions-log 278: its detail, price row, divider,
  /// lines and bottom bar). For tests.
  ShopTab get shopTab => _shop.tab;
  Rect shopTabAt(ShopTab tab) => _shop.tabs[tab] ?? Rect.zero;
  List<(BagCategory, Rect)> get shopSections => [..._shop.heads];
  Map<BagLoot, int> get shopBasket => {..._shop.basket};
  List<(BagLoot, Rect, String)> get shopBasketLines => [..._shop.lines];
  Rect shopAt(String key) => _shop.at[key] ?? Rect.zero;
  String? shopText(String key) => _shop.texts[key];
  Rect shopCountAt(BagLoot loot) => _shop.sell.counts[loot] ?? Rect.zero; // a Sell cell's count capsule (none: Rect.zero)
  Map<BagLoot, (MarketWord, Rect)> get shopArrows => {..._shop.arrows}; // the Sell grid's market arrows (decisions-log 326)

  /// The Smithy's pages this frame (smithy_page.dart, decisions-log 235): the relic picked (null: none yet), its board's
  /// cells in order and what [relic]'s shows ([BagMarks]: its count from 1, the ▲, faded, lit; null: no cell); where a part
  /// is by [key] ('kinds', 'recipe', 'craft', 'noLimit', 'equip'; Rect.zero: not shown) and the words drawn ('kinds',
  /// 'effect', 'tier', 'craft', 'noLimit'; null: not shown); and the recipe's rows. Its materials' grid is [bagCells] and
  /// the rest of the Bag's grid getters while the Smithy shows, its heading [bagDetail] / [bagDetailText] ('name',
  /// 'count') and its Equip row [bagAction] ([BagAction.equip]) with its words. With the forge (decisions-log 254): the
  /// tab on, the Items tab's item picked (null: none yet), its board's cells shown in order and what [item]'s shows, its
  /// page, pages and pager ('back', 'on'; Rect.zero: one page; decisions-log 277), and whether a board is drawn at the
  /// small slot; the strip's segments by key ('tab:items'), the Items board's grade headings drawn ('grade:2': where its
  /// words are), their words ('tabs', 'grades', 'locked') and an item's Give row ('give', [BagAction.giveTroops]). The
  /// Enhance tab's (decisions-log 255): its pick (a stone, or an item at its plus; null: none yet), its board's cells in
  /// order (the stones, then the items and their stacks) and what each shows, its Enhance button ('enhance', its words
  /// 'enhance') and the grey line under it ('next'), its Give row ('give'). For tests.
  Relic? get smithyPick => _smithy.pick;
  List<(Relic, Rect)> get smithyCells => [for (final (cell, r) in _smithy.board.cells) (cell.kind as Relic, r)];
  BagMarks? smithyMarks(Relic relic) => _smithy.board.marks[(kind: relic, plus: 0)];
  SmithyTab get smithyTab => _smithy.tab;
  set smithyTab(SmithyTab tab) => _smithy.tab = tab; // a test's start on a tab (a player taps its segment, 'tab:<name>')
  Item? get smithyItem => _smithy.item;
  List<(Item, Rect)> get smithyItemCells => [for (final (cell, r) in _smithy.items.cells) if (cell.kind case final Item i) (i, r)];
  List<(PocketKind, Rect)> get smithyPocketCells => [for (final (cell, r) in _smithy.items.cells) if (cell.kind case final PocketKind p) (p, r)];
  PocketKind? get smithyPocket => _smithy.pocket;
  BagMarks? smithyItemMarks(Item item) => _smithy.items.marks[(kind: item, plus: 0)];
  int get smithyItemPage => _smithy.items.page;
  int get smithyItemPages => _smithy.items.pageCount;
  Rect smithyItemPager(String which) => which == 'back' ? _smithy.items.back : _smithy.items.on;
  // The Wishlist tab (decisions-log 300, 302, 303): each row on the spread shown (its group: a type, or "free"; its
  // product; where), its spread, how many, its pager (Rect.zero: one spread). Its parts by [smithyAt] key: 'wishHead' (its
  // title's words), 'wishType:<group>' (a group heading's sprite and name; its first on the spread), 'wishOffAll:<group>' (its Remove),
  // 'wishRow:<group>:<product>' (a row's card), 'wishOff:…' (its ✕), 'wishCraft:…' and 'wishGive:…' (its tags). Its words
  // by [smithyText]: 'wishLines' (every row over the spreads, "knight:sword ×2|free:sweep ×1"), 'wishPage' (the rows on the
  // spread shown, by key), 'wishPer' (each spread's rows, left page + right page: "1+4,2+3"), 'wishNeeded', 'wishEmpty',
  // 'wishType:<group>', 'wishOffAll:<group>' ("Remove", armed "Sure?"), and per row 'wishTitle:…' ("Sword ×2 for Knight"),
  // 'wishParts:…' ("boneShard 11/4,orcTooth 3/4,gold 40"), 'wishStatus:…', 'wishCraft:…' (why it is refused; '' when it
  // can), 'wishGive:…' (its words) and 'wishGiveWhy:…'; a product's page's status 'wishMissing' and free line 'freeLess',
  // 'freeMore', 'freeAdd' (rects) and 'free' ("off ×1", "on ×2"), 'freeAdd' (words). The ingredient wishes (decisions-log
  // 323): their group "parts" ('wishRow:parts:gemRing'), each row's part by 'wishPart:<row key>:<part>' (where its icon is,
  // a tap there opening a forgeable one's page), a product page's Back after a link ('back') and how many steps back
  // there are ([smithyTrail]), and in its Give row's place 'kept' (where, and its words: "Needed for Royal Ring").
  int get smithyTrail => _smithy.trail.length;
  List<(String, Enum, Rect)> get smithyWishCells => [..._smithy.wishCells];
  List<(String, Rect)> get smithyWishHeads => [..._smithy.wishHeads]; // each group heading drawn: its group, where
  int get smithyWishPage => _smithy.wishes.page;
  int get smithyWishPages => _smithy.wishes.pageCount;
  Rect smithyWishPager(String which) => which == 'back' ? _smithy.wishes.back : _smithy.wishes.on;
  // The Relics or the Enhance tab's board, whichever shows: its page, how many, its pager (decisions-log 283: paged where
  // they don't all fit on the page).
  int get smithyBoardPage => _smithyBoardShown.page;
  int get smithyBoardPages => _smithyBoardShown.pageCount;
  Rect smithyBoardPager(String which) => which == 'back' ? _smithyBoardShown.back : _smithyBoardShown.on;
  _BagGrid get _smithyBoardShown => _smithyTab(state) == SmithyTab.enhance ? _smithy.enhanceBoard : _smithy.board;
  BagLoot? get smithyEnhancePick => _smithy.enhancePick;
  List<(BagLoot, Rect)> get smithyEnhanceCells => [..._smithy.enhanceBoard.cells];
  BagMarks? smithyEnhanceMarks(Enum kind, [int plus = 0]) => _smithy.enhanceBoard.marks[(kind: kind, plus: plus)];
  bool get smithySmallBoard => _smithy.board.shrunk || _smithy.items.shrunk || _smithy.enhanceBoard.shrunk;
  Rect smithyAt(String key) => _smithy.at[key] ?? Rect.zero;
  String? smithyText(String key) => _smithy.texts[key];
  List<SmithyRow> get smithyRows => [..._smithy.rows];

  /// A book page's part that scrolls where it doesn't fit (decisions-log 283, page_scroll.dart) by name: 'smithy' (the
  /// Smithy's facing page under its heading), 'tavernList' (the Tavern's left page under "Offers"), 'tavernFacing' (its
  /// right page under the heading): where it shows this frame (Rect.zero: not drawn), how tall what it holds is, and how
  /// far it is scrolled (settable; held in range as it draws). For tests.
  Rect pageScrollView(String part) => _pageScrollOf(part).view;
  double pageScrollContent(String part) => _pageScrollOf(part).content;
  double pageScroll(String part) => _pageScrollOf(part).scroll;
  void setPageScroll(String part, double v) => _pageScrollOf(part).scroll = v;
  _PageScroll _pageScrollOf(String part) => switch (part) {
        'smithy' => _smithy.facing,
        'tavernList' => _tavernPage.list,
        'tavernFacing' => _tavernPage.facing,
        _ => throw ArgumentError.value(part, 'part'),
      };

  /// The Tavern's pages this frame (tavern_page.dart, decisions-log 267): the offer's slot the facing page shows (null:
  /// none yet), the offers' rows and the Effect's as drawn, where each part is by key and the words drawn by key
  /// ([_TavernView.at]), and whether its tab carries the dot (offers not seen on its page yet). For tests.
  int? get tavernPick => _tavernPage.pick;
  List<TavernRow> get tavernRows => [..._tavernPage.rows];
  List<TavernEffectRow> get tavernEffects => [..._tavernPage.effects];
  Rect tavernAt(String key) => _tavernPage.at[key] ?? Rect.zero;
  String? tavernText(String key) => _tavernPage.texts[key];

  /// Where a tab's dot is this frame: the Tas tab's 'bagDot', the Army tab's 'armyDot' (ascend_page.dart) and a Town's
  /// Tavern tab's 'tavernDot' (tavern_page.dart) (Rect.zero: not shown). For tests.
  Rect storeAt(Object what) => _storeAt[what] ?? Rect.zero;

  /// Each Tempa "+n" drawn after a type's stars this frame (ascend_page.dart): where, and its text. For tests.
  List<(Rect, String)> get tempaMarks => [..._tempaMarks];

  /// Each badge drawn this frame with a Pusaka's Carve steps in gold after its label (badge.dart's `_capsule`,
  /// decisions-log 196): where, and its words ("★2+3"; the chest card's "+3"). For tests.
  List<(Rect, String)> get carveBadges => [..._carveBadges];

  /// The spawn bar this frame (spawn_bar.dart): its cards (each whole, which type) in order, troop [type]'s card
  /// (Rect.zero: on another page of the strip) and how it was drawn ('buy', 'poor': the gold short, 'refused': the
  /// forbidden sign; '': not drawn), the whole bar (Rect.zero: not shown), the cards' strip, the first card its page
  /// shows (settable; held in range as it draws) and how many a page shows, its arrow buttons (back, on; Rect.zero: all
  /// the cards fit), the still block at its right, and its "Auto" (the press area; "+Room" is [capacityButton]). For
  /// tests.
  List<(Rect, String)> get spawnBarCards => [..._bar.cards];
  Rect spawnCard(String type) => _barCardRect(type);
  String spawnCardLook(String type) => _bar.looks[type] ?? '';
  Rect get spawnBarArea => _bar.area;
  Rect get spawnBarList => _bar.list;
  int get spawnBarFirst => _bar.first;
  set spawnBarFirst(int v) => _bar.first = v;
  int get spawnBarPerPage => _bar.per;
  (Rect, Rect) get spawnBarArrows => (_bar.back, _bar.on);
  Rect get spawnBarPanel => _bar.panel;
  Rect get autoReplaceButton => _bar.auto;
  Rect get spawnBarRoomFace => _bar.roomFace; // +Room's button as drawn ([capacityButton] is its press area)
  List<(String, Rect)> get spawnBarRoomWords => [..._bar.roomWords]; // its words and where

  /// The pocket bar (decisions-log 332, pocket_look.dart) as placed this frame: its panel (Rect.zero: not shown), its four
  /// slots, and the running pocket boosts' chips under the wave meter. For tests.
  Rect get pocketBar => _pocket.at;
  List<Rect> get pocketSlots => [..._pocket.cells];
  List<Rect> get pocketChips => [..._pocket.chips];

  /// Where the Army page's cell for troop [type] is this frame (Rect.zero: not shown, e.g. on another page of the
  /// grid), what its cell says after the name ("x5/5" and its ink, troop_row.dart), the type its right page shows
  /// (troops_page.dart), and that type's eight stats as the detail has them (HP, MP, defence, attack, reach, speed, attack
  /// pause, regen; empty: not shown). For tests.
  Rect troopRow(String type) => _cards.where((c) => c.$2 == type).firstOrNull?.$1 ?? Rect.zero;
  (String, Color) troopRowCount(String type) => _rowCount(state, type);
  String get troopPicked => _troopPick;
  List<String> troopRowStats(String type) => [...?_rowStatTexts[type]];

  /// The Army grid's page shown, how many pages it has, and its pager's arrows this frame (Rect.zero: one page, or
  /// another page of the book; troops_page.dart). For tests.
  int get armyPage => _army.page;
  int get armyPageCount => _army.pageCount;
  (Rect, Rect) get armyPager => (_army.back, _army.on);

  /// The Army detail's body this frame (between its header and its foot; Rect.zero: not shown), how tall its sections
  /// are, and how far it is scrolled (troop_detail.dart). For tests.
  Rect get troopDetailBody => _detail.body;
  double get troopDetailContent => _detail.content;
  double get troopDetailScroll => _detail.scroll;
  set troopDetailScroll(double v) => _detail.scroll = v;

  /// The picked type's detail on the Army page's right page this frame (troop_detail.dart): where a section is
  /// ('heading', 'stats', 'next', 'pusaka', 'heroes', 'relics'; Rect.zero: nothing to say, or scrolled out of the
  /// body's view) or a button ('upgrade', 'change', 'bag', 'shop'; the foot's as drawn, 'release', 'confirm' (the armed
  /// Release's), 'replace', their press areas, 'releaseTap', 'releaseConfirm', 'replaceTap', and their words' boxes,
  /// 'releaseWords', 'confirmWords', 'replaceWords'; Rect.zero: not shown),
  /// and the words drawn in each (a button's: its label; a section's whether scrolled into view or not). For tests.
  Rect troopDetail(String key) => key == 'releaseConfirm' ? _release.confirm : _detail.at[key] ?? Rect.zero;
  List<String> troopDetailWords(String key) => [...?_detail.words[key]];

  /// The ink of the picked type's attribute [name] (its short name, [Words.speed] …) as drawn this frame: green raised,
  /// red at its ceiling (null: not drawn). For tests.
  Color? troopStatInk(String name) => _detail.inks[name];

  /// The first stat a Tas row for troop [type] previews with a Pusaka picked, now and after as drawn ("927", "580"),
  /// this frame (null: none shown, or it changes no stat). For tests.
  (String, String)? tasRowStat(String type) => _tasStatTexts[type];

  /// Draws a slot of the book's sprite kit on [c] as the pages will (decisions-log 187): colour [row] ([slotSrc]) over [r]
  /// in [look] at [k] screen px per sprite px ([_slotFrame]); with [rarity], the tan slot recoloured as that rarity's
  /// Pusaka cell ([_rarityCellPaints]). Returns how far its face moved down. For tests and the kit's shot probe.
  double drawSlot(Canvas c, Rect r, int row, ButtonLook look, double k, {Rarity? rarity}) =>
      _slotFrame(c, r, row, look, k, paint: rarity == null ? null : _rarityCellPaints[rarity]);

  /// Each list's scroll bar on the book this frame (the Tas page's, the Licences and How to play pages'): its track, the
  /// turned capsule down the list's right (bag.dart's [_capsuleBar]). For tests.
  List<Rect> get scrollBars => [..._capsuleBars];

  /// Whether the book showed the Tas page (Bag) this frame, whatever the bag holds. For tests: the Bag grid (decisions-log
  /// 187) gives a kind with none left no slot, so [bagSlot] is no sign of the page.
  bool get bagOpen => _bagShown;

  /// The bag's pick (an Item or a Relic, null: none), and where the bag's slot for [loot] is this frame
  /// (Rect.zero: not shown). For tests.
  Enum? get picked => _picked;
  Rect bagSlot(Enum loot) => _bagSlotOf((kind: loot, plus: 0));

  /// The pick's plus (an enhanced stack's, decisions-log 255; 0: none, or any other loot), and where the Bag's cell for
  /// [item] at +[plus] is this frame (Rect.zero: not shown). For tests.
  int get pickedPlus => _pickPlus;
  Rect bagStackSlot(Item item, int plus) => _bagSlotOf((kind: item, plus: plus));

  /// The Bag's grid this frame (bag.dart, decisions-log 187): each cell shown, in order; every slot of the page's board in
  /// reading order, a kind's or empty (none under the empty text's card); the category on and each chip (Rect.zero: not
  /// shown); the page shown (from 0), how many there are and how many cells a page holds (alone, and above the pager;
  /// the note's strip, while it shows, taken off both); the pager's 'back' and 'on' buttons (Rect.zero: a single page);
  /// what [loot]'s cell shows (null: no cell shows); and the empty text's lines (none: a cell shows). For tests.
  /// On the Town's Shop page, its grid's (decisions-log 230).
  List<(Enum, Rect)> get bagCells => [for (final (cell, r) in _grid.cells) (cell.kind, r)];
  List<Rect> get bagSlots => [..._grid.slots];
  BagCategory get bagCategory => _grid.category;
  Rect bagChip(BagCategory category) => _grid.chips[category] ?? Rect.zero;
  int get bagPage => _grid.page;
  int get bagPages => _grid.pageCount;
  (int, int) get bagPageSizes => (_grid.perOne, _grid.perPaged); // the cells a page holds alone, and with the pager
  Rect bagPager(String which) => which == 'back' ? _grid.back : _grid.on;
  BagMarks? bagMarks(Enum loot, [int plus = 0]) => _grid.marks[(kind: loot, plus: plus)];

  /// The grid's cells this frame as [bagCells], each with its plus (an enhanced stack's, decisions-log 255). For tests.
  List<(BagLoot, Rect)> get bagLootCells => [..._grid.cells];
  List<String> get bagEmpty => [..._grid.empty];
  (Rect, Rect) get bagEmptyCard => (_grid.emptyCard, _grid.emptyText); // its card, and its icon and lines (Rect.zero: none)

  /// The "VICTORY!" popup's loot line this frame, each kind and its count in order (none: no popup). For tests.
  List<(Enum, int)> get victoryLoot => _victoryLoot;
  List<(Enum, int)> _victoryLoot = const [];

  /// The Tas page's list this frame (bag.dart): each row shown (whose: a troop type or a Unit; where, clipped to
  /// the list; whether it can take the pick), where the rows are (Rect.zero: no list), each filter chip (null:
  /// Semua; Rect.zero: not shown) and the types the filter shows (empty: all). For tests.
  List<(Object, Rect, bool)> get assignRows => [for (final (r, who, ok, _) in _assign.rows) (who, r, ok)];

  /// The relic slots on the Tas page's rows this frame (#91): whose, the relic in it (null: empty), where (clipped
  /// to the list); the held relic picked out for Lepas (null: none); and where its Lepas button is (Rect.zero: none
  /// shows). For tests.
  List<(Unit, Relic?, Rect)> get assignSlots => [..._assign.slots];
  (Unit, Relic)? get takeOffArmed => _assign.armed;
  Rect get takeOffButton => _assign.lepas;
  Rect get assignList => _assign.list;
  double get assignScroll => _assign.scroll; // how far the list is scrolled (px)
  Rect assignChip(String? type) => _assign.chips[type] ?? Rect.zero;
  Set<String> get assignFilter => {..._assign.filter};

  /// The Pusaka on the book this frame (bag.dart, decisions-log 151): the note's 'ok' and 'batal' (Undo; Rect.zero: not
  /// shown), and troop [type]'s badge on its Pasukan row (Rect.zero: none) and whether it is drawn asleep (faded: none of
  /// the type lives). For tests.
  Rect pusakaNoteButton(String key) => _assign.note[key] ?? Rect.zero;
  Rect pusakaBadge(String type) => _assign.badges[type]?.$1 ?? Rect.zero;

  /// The Asah button on a Pusaka's facing page this frame (Rect.zero: none shows; bag.dart, decisions-log 154) and the
  /// Pusaka whose Asah was tapped once (null: none). For tests.
  Rect get asahButton => _assign.asah;
  Relic? get asahArmed => _assign.asahArmed;

  /// The Pusaka whose Carve was tapped once on its facing page this frame (bag.dart, decisions-log 196; null: none). Its
  /// button, strip, bar and words: [bagDetail] / [bagDetailText] ('carveBtn', 'carve', 'carveBar', 'next'); its Give
  /// rows are [assignRows], each by its Pusaka. For tests.
  Relic? get carveArmed => _assign.carveArmed;

  /// How the Carve bar says refusal [why], longest first (bag.dart's `_carveWhy`). For tests.
  List<String> carveWhyWords(String why) => _carveWhy(state, why);

  /// Lebur on the Tas page this frame (bag.dart, decisions-log 164): its button on a Gudang Pusaka's facing page
  /// (Rect.zero: none shows), the Gudang Pusaka whose target picker is open (null: none), the target whose row was
  /// tapped once (null: none) and the picker's Batal (Rect.zero: not open). The picker's rows are [assignRows], each by
  /// its Pusaka. For tests.
  Rect get leburButton => _assign.leburBtn;
  Relic? get leburOpen => _assign.lebur;
  Relic? get leburArmed => _assign.leburArmed;
  Rect get leburBack => _assign.leburBack;

  /// The Bag's facing page this frame (bag.dart, decisions-log 187 and 202): where each part is by [key] ('page': the
  /// page itself, 'icon', 'name', 'count', 'where', 'desc', the action rows 'sharpen' and 'carve', the tags 'carveBtn'
  /// and 'toVault', 'carveBar', 'empty'; Rect.zero: not shown), and the words of 'name', 'count', 'where', 'desc' (its
  /// lines, '\n' between), the tags 'sharpen' and 'carve', Carve's bar 'carveBar' and armed 'next', and 'empty' (its
  /// lines; null: not shown). For tests (the Bag sells nothing, decisions-log 296).
  Rect bagDetail(String key) => _assign.detail[key] ?? Rect.zero;
  String? bagDetailText(String key) => _assign.texts[key];

  /// The Bag's facing page's action list this frame (bag.dart, decisions-log 202): each action row shown (what, where:
  /// clipped to the list, whether it can now); [act]'s row (Rect.zero: not shown); the chooser shown (null: none, the
  /// action list or nothing picked) and its Back (Rect.zero: no chooser). Their words: [bagDetailText]'s
  /// `'title:<action>'`, `'hint:<action>'` and 'chooser'. For tests.
  List<(BagAction, Rect, bool)> get bagActions => [..._assign.actions];
  Rect bagAction(BagAction act) => _assign.actions.where((a) => a.$1 == act).firstOrNull?.$2 ?? Rect.zero;
  BagAction? get bagChooser => _assign.shown;
  Rect get bagBack => _assign.back;

  /// Where the message window is while it shows (Rect.zero: none; message.dart). For tests.
  Rect get messageBox => _msg.text == null ? Rect.zero : _msg.at;

  /// The loot tooltip showing this frame, its title and lines (null: none; tooltip.dart). For tests.
  (String, List<String>)? get tooltipShown => _tip.drawn;

  /// Where that tooltip's frame is (Rect.zero: none). For tests.
  Rect get tooltipBox => _tip.drawn == null ? Rect.zero : _tip.box;

  /// The troop rows' item cells drawn this frame, each with a tooltip: where, which item, whose row. For tests.
  List<(Rect, Item, String)> get itemCells => [..._tip.rows];
  bool pusakaBadgeAsleep(String type) => _assign.badges[type]?.$2 ?? false;

  /// Where "Send game data" and "Main Menu" are this frame (Rect.zero: the Settings page doesn't show). For
  /// tests.
  Rect get sendButton => _sendAt;
  Rect get menuButton => _menuAt;

  /// The rest of the Settings page this frame (Rect.zero: not shown): the line under "Send game data", and
  /// the "Hero spotlight" and "Monster spotlight" toggles. For tests.
  Rect get sendNote => _sendNoteAt;
  Rect get heroCutButton => _heroCutAt;
  Rect get foeCutButton => _foeLook.button;

  /// A monster champion's skill banner (foe_cut_in.dart) showing this frame: its title and line as drawn, the
  /// title's size, whether it is the moment's band, where it rests (its slide aside) and its ribbon (the band's: the
  /// title); null: none. And the banners waiting, next first. For tests.
  ({String title, String line, double titleSize, bool band, Rect at, Rect ribbon})? get foeCutIn =>
      _foeCuts.showing == null || _foeLook.at.isEmpty
          ? null
          : (
              title: _foeLook.title,
              line: _foeLook.line,
              titleSize: _foeLook.titleSize,
              band: _foeCuts.showing!.$2.rank == MonsterRank.moment,
              at: _foeLook.at,
              ribbon: _foeLook.ribbon,
            );
  List<FoeCut> get foeCutsWaiting => [..._foeCuts.waiting];
  FoeCut? get foeCutShowing => _foeCuts.showing;

  /// A monster skill's first-sighting splash showing (foe_splash.dart): the cast (its caster, skill and rank), and as
  /// drawn this frame its title and title size, its rank line, its text's lines, their size and the room they had, its
  /// hint (null: none) and its panel (Rect.zero: not drawn yet); null: none. For tests.
  ({
    FoeCut cast,
    String title,
    double titleSize,
    String line,
    List<String> lines,
    double textSize,
    double textRoom,
    String? hint,
    Rect panel,
  })? get foeSplash => switch (_foeSplash.showing) {
        final cast? => (
            cast: cast,
            title: _foeSplash.title,
            titleSize: _foeSplash.titleSize,
            line: _foeSplash.line,
            lines: _foeSplash.lines,
            textSize: _foeSplash.textSize,
            textRoom: _foeSplash.textRoom,
            hint: _foeSplash.hint,
            panel: _foeSplash.panel,
          ),
        null => null,
      };

  /// The Licenses page (licence_page.dart): Settings' "Licenses" button, and whether the page shows; this frame,
  /// the paragraphs drawn on its left page (the game's licence and the credits) and on its right one (the open
  /// package's licences), the package rows drawn (each name and where) and the open package (null: the list);
  /// "Kembali" and "Semua paket" (Rect.zero: not shown); and where the left and the right page's columns are. For
  /// tests.
  Rect get licenceButton => _lic.button;
  bool get licenceShown => _page == _Page.licence;
  List<String> get licenceLeft => [..._lic.left.shown];
  List<String> get licenceRight => [if (_lic.open != null) ..._lic.right.shown];
  List<(String, Rect)> get licenceRows => [for (final (r, name) in _lic.rows) (name, r)];
  String? get licencePackage => _lic.open;
  Rect get licenceBack => _lic.back;
  Rect get licenceAll => _lic.all;
  List<Rect> get licenceColumns => [_lic.left.list, _lic.right.list];

  /// The How to Play page (guide_page.dart): Settings' "How to Play" button, and whether the page shows; the open topic's
  /// title; this frame, the topics' rows drawn (each title and where), the paragraphs drawn on the right page, "Kembali"
  /// and "Ulang panduan" (Rect.zero: not shown), and where the left page's list and the right page's column are. And
  /// the Settings page's volume rows this frame (Music, Sounds). For tests.
  Rect get howToButton => _guide.button;
  bool get howToShown => _page == _Page.guide;
  String get howToTopic => guideEn.topics[_guide.topic].title;
  List<(String, Rect)> get howToTopics => [for (final (r, i) in _guide.rows) (guideEn.topics[i].title, r)];
  List<String> get howToText => [..._guide.text.shown];
  List<String> get howToParas => [for (final (p, _, _) in _guide.text._laid) if (!p.rule) p.text]; // all, as laid out so far
  Rect get howToBack => _guide.back;
  Rect get howToReplay => _guide.replay;
  List<Rect> get howToColumns => [_guide.topics.list, _guide.text.list];
  List<Rect> get volumeRows => [..._volumeAt];

  /// Where the boss bars are this frame, all of them (Rect.zero: none), and whether they are at the left,
  /// compact, the book being open (landscape). For tests.
  Rect get bossBars => _bossAt;
  bool get bossBarsAside => _bossAside;

  /// Where the book button is this frame (Rect.zero: none, as between waves),
  /// and the open book (Rect.zero: shut). For tests.
  Rect get bookButton => _bookBtnAt;
  Rect get bookArea => _bookArea;

  /// Whether the player opened the book by its button (it may still be sliding in), as the button's lit state shows.
  /// For tests.
  bool get bookOpened => _bookOpened;

  /// The open book's shadow this frame ([_bookShadow], decisions-log 275): its rows as drawn, top to bottom (none while
  /// the book is shut, nor over a Town's scene: decisions-log 304), and its paint (black, 0.25 of the book's slide in; no
  /// anti-alias). For tests.
  ({List<Rect> rows, Paint paint}) get bookShadow =>
      (rows: _bookArea.isEmpty ? const <Rect>[] : [..._bookShadowRows], paint: _bookShadowPaint);

  /// Pusaka [r]'s ring under the feet at [ground] (world units in [c]), drawn as the field draws it ([_ringUnder],
  /// decisions-log 325). For tests.
  void paintPusakaRing(Canvas c, Offset ground, Relic r) => _ringUnder(c, ground, r);

  /// A Hero's halo of whole radius [r] round [middle], and a dragged troop's reach [range] round [middle] at [alpha], drawn
  /// as the field draws them (pixel_shapes.dart, decisions-log 325). For tests.
  void paintHeroHalo(Canvas c, Offset middle, int r) => _haloAt(c, middle, r);
  void paintReachDisc(Canvas c, Offset middle, double range, double alpha) => _discAt(c, middle, range, alpha);

  /// Where the open book's left and right pages write this frame: inside each page's printed line, less the book's
  /// padding ([bookWriting]; Rect.zero: the book is shut). For tests.
  (Rect, Rect) get bookPages => _pagesAt;

  /// Where the battle log's button is, and its panel while open (Rect.zero: closed). For tests.
  Rect get logButton => _log.button;
  Rect get logPanel => _log.panel;

  /// Where the troop counter takes a press and its open list (Rect.zero: folded) are this frame. For tests.
  Rect get troopCounter => _troops.button;
  Rect get troopList => _troops.list;

  /// The troop counter's "alive/cap" ("48/36"), the types its open list shows and each one's count ("17/5" with the
  /// type caps on, else "17"), as last drawn. For tests.
  String get troopCountText => _troops.count;
  List<String> get troopListTypes => _troops.types;
  List<String> get troopListCounts => _troops.counts;

  /// Where type [type]'s Release is this frame: the detail's, while [type] is the one picked and it shows (Rect.zero:
  /// another type is picked, or none shows; troop_detail.dart), the type whose Release waits for its second tap (null:
  /// none) and where its confirm button is on the right page (Rect.zero: none), and where the toggle's Auto hold line is
  /// (Rect.zero: none). For tests.
  Rect releaseChip(String type) => _cards.isNotEmpty && type == _army.pick ? _detail.at['release'] ?? Rect.zero : Rect.zero;
  String? get releaseArmed => _release.armed;
  Rect get releaseConfirm => _release.confirm;
  Rect get autoHeldLine => _autoHeldAt;

  /// The Army page's header as last drawn (troops_page.dart): the title's place and the "alive/cap" counter's (Rect.zero:
  /// the caps are off). For tests.
  Rect get armyTitle => _army.title;
  Rect get armyCount => _army.count;

  /// The top band this frame (Rect.zero: not drawn): the hearts-and-gold panel, its hearts' part and its gold's part;
  /// x2; the Start/Pause toggle while it pauses or resumes ([startButton] while it starts). For tests.
  Rect get livesBar => _livesAt;
  Rect get goldPanel => _goldAt;
  Rect get heartsGoldPanel => _heartsGoldAt;
  Rect get speedButton => _speedAt;
  Rect get pauseButton => _pauseAt;

  /// The HUD's screen px per sprite px (wave_meter.dart's [_meterK]) and what a phone's screen kept at its edges last
  /// frame ([_safeInsets]). For tests.
  double get hudScale => _meterK;
  EdgeInsets get safeInsets => _safe;

  /// Where the wave meter is this frame (Rect.zero: not drawn), the minimap under it (Rect.zero: folded), and
  /// whether it is open. For tests.
  Rect get waveMeter => _meterAt;

  /// The wave meter's Town chip as last drawn ([Board._townChip]; empty without a Town marked), and its words. For tests.
  Rect get townChip => _townChipAt;

  /// The boosts' chips under the wave meter as last drawn, in [Game.boosts]' order (tavern_look.dart; none: empty). For
  /// tests.
  List<Rect> get boostChips => [..._boostChipsAt];

  /// The "Weakened foes" chip as last drawn (wipe_ask.dart; empty while the monsters are themselves). For tests.
  Rect get weakChip => _weakChipAt;

  /// After a wipe, the "Try again / Give up" dialog as last drawn (wipe_ask.dart; empty while it doesn't show): its
  /// panel, its ribbon and its buttons by name ('tryAgain', 'giveUp'). For tests.
  Rect get wipeAskPanel => _wipeAsk.panel;
  Rect get wipeAskRibbon => _wipeAsk.ribbon;
  Map<String, Rect> get wipeAskButtons => {..._wipeAsk.buttons};
  String get townChipLabel => _townChipLabel(state);

  /// The wave meter's words in a Town as last drawn ("In town", "next wave 7": [Board._inTownMeter]; '' out of one). For
  /// tests.
  String get townMeterText => _townMeterText;

  /// The Town's name's ribbon as the Town comes up, this frame (Rect.zero: none; town_look.dart).
  Rect get townArrival => _townArrivalAt;

  /// The Town scene (town_scene.dart): whether it shows instead of the field this frame; the fade's dim (0: none); the
  /// view's left edge in world px and the screen px per world px; where each piece and place was drawn this frame by
  /// name ('scene', 'street', the places 'tent', 'smithy', 'tavern', 'shop' (a building's: its cells; the Smithy's and
  /// the Shop's with what stands before them), 'yard' (the pine and the clothes line), and 'sawmill', 'furnace',
  /// 'logPile', 'ore', 'stumpAxe', 'pine', 'clothesLine', 'campfire', 'tent', 'crates2', 'fruitTable', 'barrels',
  /// 'basket'; none: not drawn); a sign ('smithy', 'tavern', 'shop'; Rect.zero: not drawn); a building's cells as
  /// drawn, in order ('smithy', 'tavern', 'shop'), and its (n, storeys). For tests.
  bool get townShown => _town.shown;
  String get bookPage => _page.name; // the book's open page: 'troops', 'bag', 'store', 'settings', 'smithy', …
  double get townFade => _townDimNow;
  double get townCam => _townCam;
  double get townK => _town.k;

  /// How far the player may pan the Town now (the view's left edge, world px: its least and most; decisions-log 264).
  /// For tests.
  (double, double) get townRoom => _townRoom();
  Map<String, Rect> get townScene => {..._town.at};
  Rect townSign(String place) => _town.signs[place] ?? Rect.zero;
  List<(String, Rect)> townBuilding(String place) => [...?_town.buildings[place]];
  (int, int)? townBuildingShape(String place) => _town.shapes[place];

  /// The Town's anchors for its troops this frame, on the screen (town_scene.dart's `_TownLayout.spots`; Offset.zero:
  /// no Town drawn): 'guard' (the Town's left end), 'tent' (the rest), 'smithy' (before the furnace), 'tavernDoor',
  /// 'talk' (before the Tavern's right side), 'shop' (before the fruit table); each on [townLane], the street's line
  /// where feet stand (one lane: the troops walk it and pass through each other).
  Offset townSpot(String name) => _town.spots[name] ?? Offset.zero;
  double get townLane => _town.lane;

  /// The Town's life (town_life.dart): its troops, their errands and its clock, and [townDice] to give it a dice of a
  /// test's own. Each troop as drawn this frame ([townFolk]): its unit, its errand ([TownDo]'s name), its feet on the
  /// screen (null: inside the Tavern, or not placed yet), its facing (1: right), its bubble (Rect.zero: none) with the
  /// icon's name ([TownIcon]) and whether it is a thought (grey). The Tavern's window's bubble (Rect.zero: none). For
  /// tests.
  TownLife get townLife => _townLife;
  set townDice(math.Random dice) => _townLife.dice = dice;
  List<({Unit unit, String doing, Offset? feet, int dir, Rect bubble, String? icon, bool thought})> get townFolk => [
        for (final f in _townLife.folk)
          (
            unit: f.unit,
            doing: f.doing.name,
            feet: f.shown ? Offset(f.sx, f.sy) : null,
            dir: f.dir,
            bubble: f.bw > 0 ? Rect.fromLTWH(f.bx, f.by, f.bw, f.bh) : Rect.zero,
            icon: f.bw > 0 ? f.said?.name : null,
            thought: f.bw > 0 && f.thought,
          ),
      ];
  Rect get townWindowBubble => _town.window;

  /// The Town's clouds this frame (decisions-log 274): each copy of battle_clouds.png as drawn, left to right (none: no
  /// Town drawn). For tests.
  List<Rect> get townClouds => [..._town.clouds];

  /// The Town's ground this frame (decisions-log 279; town_scene.dart's `_townStreet`): on the screen, 'strip' (the
  /// street, town_ground.png tiled from the street's line) and 'earth' under it to the view's bottom (none: no Town
  /// drawn). For tests.
  Map<String, Rect> get townGround => {..._town.ground};

  /// The wave meter's tide badge this frame ("+35%"; '' before the tide, #92), and where its tooltip shows (the
  /// meter; Rect.zero before the tide). For tests.
  String get tideBadge => _tideLabel;
  Rect get tideBadgeAt => _tideAt;

  /// Where "Replace fallen" was drawn on the Army page this frame (Rect.zero: not shown), and its label. For tests.
  Rect get replaceButton => _replaceAt;
  String replaceLabel = '';

  /// The Army page's type cells this frame (none: another page), and the spawn bar's "+Room" (its press area; the Army
  /// header's from decisions-log 260 until 283). For tests.
  List<Rect> get bookRows => [for (final (r, _) in _cards) r];
  Rect get capacityButton => _bar.room;
  Rect get miniMap => _map.at;
  bool get miniMapOpen => _map.open;
  set miniMapOpen(bool v) => _map.open = v; // (not saved)

  /// Where "Pause" was drawn this frame (Rect.zero: not paused). For tests.
  Rect get pauseTitle => _pause.title;

  /// Where the pinned plate was drawn this frame (Rect.zero: none shows), and its Lepas buttons (#91), one per
  /// relic its troop holds. For tests.
  Rect get pinnedPlate => _pinnedAt;
  List<Rect> get plateTakeOff => [for (final (r, _) in _plateTaps) r];

  /// The drop popup this frame (drop_popup.dart): the troop it tells about (null: none shows), where it was
  /// drawn, and its lines as text (a change as "now > after"). For tests.
  Unit? get dropFor => _drop.on;
  Rect get dropPopup => _drop.at;
  List<String> get dropLines => _drop.lines;

  /// The loot held as drawn at the pointer this frame, and the count by it ("x3"; a Pusaka's stars, "★1") (Rect.zero,
  /// null: none drawn: nothing held, or held over the open book); and while it isn't drawn there over the book, its
  /// slot, lit (Rect.zero: not so). For tests.
  Rect get heldGhost => _drop.ghost;
  String? get heldCount => _drop.count;
  Rect get heldCue => _drop.cue;

  /// Whether something covers the field at [p] (plates.dart `_covered`): no unit there is pointed at or pinned.
  /// For tests.
  bool coveredAt(Offset p) => _covered(p);

  /// How many bursts, cast names and gold pops the field is drawing. For tests.
  int get fieldFx => _bursts.length + _pops.length + _goldPops.length + _matPops.length;

  /// The bursts playing on the field this frame: where, and which ('upgrade', a skill's, …). For tests.
  List<(Offset, String)> get fieldBursts => [for (final (at, who, _) in _bursts) (at, who)];

  /// The materials lying on the field (town_look.dart): each pile's material, count and whether it flies to the Bag.
  /// For tests.
  List<(Mat, int, bool)> get matLoot => [for (final p in _matLoot) (p.mat, p.n, p.fly != null)];

  /// Turns the book to its Settings page, as its gear tab does. For tests.
  void showSettings() => _open(_Page.settings);

  /// The auto start (auto_start.dart): on or off as settings.json keeps it, and its countdown after a win.
  final autoStart = AutoStart(on: _settings.autoStart);

  /// Set while the Hero splash shows (#47): the auto start's countdown waits for it.
  bool holdAutoStart = false;

  /// Shows the welcome screen again, as on launch (for a "Main Menu" button). The game waits behind
  /// it; "Continue" goes back into it, or after a game over into the last save.
  void showWelcome() => welcome = Welcome(state.over ? loadGame() : state);

  /// The window hid or the app went to the background, where Android may end it without a word (decisions-log
  /// 133). On the desktop the game goes on (#93, pause.dart), on a phone it pauses (decisions-log 146), and between
  /// waves it is saved, so what was bought or put on since the last won wave stays. Not mid-wave (a save holds no
  /// wave in progress: loading it would skip that wave, so the last won wave's save stands), after a game over, or
  /// on the welcome screen (on launch [state] is a fresh game, not the save). The telemetry's buffered records are
  /// written too.
  void _toBackground() {
    // A due Town is between waves too, and so is a wipe's choice waiting (wipe.dart)
    if (welcome == null && (state.canStartWave || state.townDue || state.wipeAsk)) saveGame(state);
    async.unawaited(_telemetry.flush());
  }

  /// One [item] from the bag onto troop [type] (the bag's picker, or given on the field); a refusal says why,
  /// unless not [say] (the field's drop popup says it already, drop_popup.dart). True when it went on. An enhanced one
  /// from its stack at +[plus] (decisions-log 255).
  bool _useItem(Item item, String type, {bool say = true, int plus = 0}) {
    final why = state.whyNot(item, type, plus: plus);
    if (state.useItem(item, type, plus: plus)) {
      _coachItemGiven(); // the guide's item pointers are done (coach.dart)
      return true;
    }
    if (why != null && say) showMessage(state.itemRefusal(item, type, why)); // "Opens at Awaken 2" by grade (decisions-log 252)
    return false;
  }

  /// One [relic] from the bag onto troop [u] (the bag's list, or given on the field); a refusal says why
  /// ([Game.assignPreview]), unless not [say] (as [_useItem]). True when it went on.
  bool _useRelic(Relic relic, Unit u, {bool say = true}) {
    final why = state.assignPreview(relic, u).why;
    if (state.useRelic(relic, u)) return true;
    if (why != null && say) showMessage(why);
    return false;
  }

  /// Takes [relic] off troop [u] back into the bag (a Lepas button: the Tas list's, the pinned plate's; #91); a
  /// refusal says why ([Game.whyNotTakeOff]). True when it came off.
  bool _takeOff(Relic relic, Unit u) {
    final why = state.whyNotTakeOff(relic, u);
    if (state.takeOff(relic, u)) {
      _assign.armed = null;
      return true;
    }
    if (why != null) showMessage(why);
    return false;
  }

  /// Turns the book to [page] (a tab on its top edge); a picked item (or the store's goods) is put back, and a
  /// relic picked out for Lepas let go.
  void _open(_Page page) {
    if (_page == _Page.bag && page != _Page.bag) _bagLeft(); // its NEW marks go (bag.dart)
    if (_page == _Page.store && page != _Page.store) _shop.leave(); // it opens on Buy again, its basket empty (shop_page.dart)
    _page = page;
    _picked = null;
    _storePick = null;
    _smithy.unpick();
    _tavernPage.pick = null;
    _assign.armed = null;
    _release.armed = null;
    _wish.editing = null; // the Army detail's Wishlist picker closes (wishlist_look.dart)
  }

  /// Turns the book to the Bag with [pick] in hand (an item, a small relic or an owned Pusaka; nothing when it can't be
  /// held, [_canHold]; an item's enhanced stack at [plus], the Smithy's Enhance, decisions-log 255), its NEW gone as a
  /// tap on its cell would ([_BagGrid.seen]) and with [act] its chooser open (decisions-log 202), or else on
  /// [category]'s chip: the Army page's detail shortcuts (troop_detail.dart) and the Shop's "Awaken 2 from the Bag"
  /// ([_upgradeButton]). The grid turns its chip and page to a held pick by itself ([_bagGrid]).
  void _openBag({Enum? pick, int plus = 0, BagCategory? category, BagAction? act}) {
    _open(_Page.bag);
    if (pick != null && _canHold(state, pick, plus)) {
      _pickedAt = (kind: pick, plus: plus);
      _bag.seen.add(pick);
      if (act != null) _openChooser(pick, act, plus);
    } else if (category != null) {
      _bag.category = category;
    }
  }

  /// The army cap's warning ([Game.capWarning], decisions-log 161) in the message window for [_noteTime], between waves
  /// once a won wave's "VICTORY!" popup is over and nothing else is up: no Hero splash, no boss chest due, no other
  /// message. Not before this game's first win: a save coming in has its own notes in that window.
  void _capNews(Game g) {
    if (_msg.text != null || _herald.who != null || _herald.next.isNotEmpty || _chestHolds(g)) return;
    if (g.victoryAt == double.negativeInfinity || g.t - g.victoryAt < victoryTime) return;
    if (g.capWarning() case final warning?) showMessage(warning, time: _noteTime);
  }

  /// Shows [text] in a small window over the field (message.dart) until the next press or for [time] s (2 by
  /// default), e.g. why something was refused; a line per `\n`.
  void showMessage(String text, {double time = _messageTime}) => _msg
    ..text = text
    ..since = _clock
    ..time = time;

  @override
  void update(double dt) {
    final g = state;
    _fpsFrame(dt); // fps_readout.dart, while "Show FPS" is on
    _clock += dt;
    _whilePaused(dt); // pause.dart
    if (welcome != null) return Sounds.scene(Music.idle); // nothing moves behind the welcome screen
    g.viewW = size.x / _scale;
    // A foe skill's first-sighting splash freezes the field (foe_splash.dart): no tick while it shows.
    if (!_foeSplashHolds(g, dt)) g.tick(math.min(dt, 0.1) * speed);
    _bodiesStep(g); // where each troop is drawn, and its stride (body_look.dart)
    _dropPin(); // plates.dart
    if (_pickedAt case (:final kind, :final plus)? when g.over || !_canHold(g, kind, plus)) _picked = null; // used up, or the game ended
    _bag.seen.removeWhere((kind) => !_canHold(g, kind)); // a kind gone: back, it is NEW again (bag.dart)
    if (g.over) _gameEnded(g); // its score goes to the board, once
    // A wave beginning shuts a hand-opened book, however it began (Start and Auto shut it first anyway): a wave starts
    // with the book shut.
    if (g.waveActive && !_waveWas) _bookOpened = false;
    _waveWas = g.waveActive;
    _bookT = (_bookT + (_bookWanted ? 1 : -1) * dt * 3).clamp(0.0, 1.0);
    if (_bookT == 0) _open(_home); // a closed book opens on the troops (in a Town on the Smithy, town_scene.dart)
    if (!identical(g, _autoFor)) {
      _autoFor = g; // another game came in (a new one, a save): no countdown or cut-in carries over
      autoStart.cancel();
      // A save from before the limits keeps its army and its types: it says so, once ([Game.limitNotes]); with the
      // tide's news for the same save ([Game.tideCaughtUp], below) in one window, the tide first.
      // So does a save from before the Pusaka, whose artefacts became Pusaka bound by default ([Game.pusakaNotes]);
      // the Tas page keeps the suggestion's OK and Batal until the player picks one or starts a wave (below).
      // A save from before the Shadows owes the monsters some for its Artifacts ([Game.omenCaughtUp], omen.dart): one
      // line more.
      final notes = [...g.limitNotes(), ...g.pusakaNotes(), if (omensOn && g.omenCaughtUp) g.omenCatchUpNote];
      g.omenCaughtUp = false;
      if (notes.isNotEmpty) {
        showMessage([if (g.tideCaughtUp) '${tideNews.$1} ${tideNews.$2}', ...notes].join('\n'), time: _noteTime);
        g.tideCaughtUp = false;
      }
      _cutIns.clear();
      _heroCutGate.clear();
      _firstCasts.clear();
      _foeCuts.clear(); // nor a foe's banner, and the new game's waves start afresh (foe_cut_in.dart)
      _foeLook.gate.clear();
      _foeSplashClose(); // nor a foe skill's splash (foe_splash.dart)
      _pusakaLook.cutName = null; // nor the Grail's
      // Nor the last game's bursts and cast names: they run on its clock, so on the new one's (from 0) they
      // would stay up until it caught up (#74).
      _bursts.clear();
      _pops.clear();
      _goldPops.clear();
      _matPops.clear();
      _matLoot.clear(); // and its materials lying on the field: they were its tally
      _picked = null; // nor the loot in hand
      _bag.seen = {...bagKinds(g, BagCategory.all)}; // nor NEW on what it holds (bag.dart)
      _telemetry.attach(g); // and the telemetry listens to it
    }
    if (g.victoryAt != _savedWin) {
      _savedWin = g.victoryAt;
      if (g.victoryAt > double.negativeInfinity) {
        saveGame(g); // auto-save after every won wave
        autoStart.won();
      }
    }
    if (g.wipedAt != _savedWipe) {
      _savedWipe = g.wipedAt;
      // The army fell and the wave is played again (wipe.dart): saved at once, so the heart lost stays lost, said in
      // the message window, and Auto Wave counts down as after a win.
      if (g.wipedOut && !g.over) {
        saveGame(g);
        autoStart.won();
        if (!g.wipeAsk) showMessage(g.wipeNote, time: _noteTime); // else the dialog says it (wipe_ask.dart)
      }
    }
    // The auto start: its countdown stops once a wave is on (Start pressed early) or the game is over; it
    // stands still while paused, the Hero splash or a guide card shows (coach.dart), the book is turned off Army (to Tas or
    // Settings: the player is busy there, #63, #93), the army is below 75% of its cap ([Game.autoHeld],
    // decisions-log 141: a line under the Start/Pause toggle says so) or a boss chest is due (one waits, its popup open or
    // about to: chest_popup.dart, decisions-log 152, 281), and at 0 starts the wave as Start does.
    if (g.waveActive && g.pusakaSuggested) g.dismissPusakaNote(); // a wave begun keeps the save's Pusaka as suggested
    if (_townTick(g, dt)) {
      // In a Town: no countdown (decisions-log 328); it is left by hand (town_look.dart).
    } else if (!g.canStartWave) {
      autoStart.cancel();
    } else if (autoStart.tick(math.min(dt, 0.1), held: g.paused || holdAutoStart || _coach.showing || _foeSplashBusy || _page != _Page.troops || g.autoHeld || _chestHolds(g) || _townFading)) {
      _bookOpened = false;
      g.startWave();
    }
    _townSync(g); // the Town's fade, its book's pages and its pan (town_scene.dart); Auto's wave waits for the fade back
    _townLifeTick(g, dt); // and its troops' errands (town_life.dart)
    g.sfx
      ..forEach(Sounds.play)
      ..clear();
    _heroNews(g); // a new Hero's splash (hero_splash.dart)
    _chestNews(g); // then the boss's chest (chest_popup.dart)
    _capNews(g); // then the army cap's warning
    _coachNews(g); // then the guide's one-time card due at this break (coach.dart)
    _coachTick(g); // the guide's pointers: done, or dropped (coach.dart)
    if (g.newMarch) {
      g.newMarch = false;
      showMessage(marchNote); // the wave stalled: its monsters charge the troops ([Game.marching], wipe.dart)
    }
    if (g.tideCaughtUp) {
      g.tideCaughtUp = false;
      showMessage('${tideNews.$1} ${tideNews.$2}'); // a save from before the tide loaded with it on (#92)
    }
    for (final (p, who) in g.impacts) {
      _bursts.add((Offset(p.x, p.y), who, g.t));
    }
    g.impacts.clear();
    _drainCasts(g); // skills.dart
    _grailNews(g); // pusaka_look.dart: the wave's first Grail save's cut-in
    _cutIns.tick(_clock); // hero_cast.dart
    _foeCuts.tick(_clock); // foe_cut_in.dart
    _bursts.removeWhere((b) {
      if (WizardMagic.ofBurst(_plainFx(b.$2)) case final magic?) return g.t - b.$3 >= magic.hitTime; // wizard_fx.dart
      final (img, fps) = _burstStrip(b.$2);
      return (g.t - b.$3) * fps >= _frames(img);
    });
    Sounds.scene(g.waveActive ? Music.battle : Music.idle);
  }

  /// Screen point → battlefield coordinates (x in world units, y from the top of the field).
  Offset _toWorld(Vector2 p) {
    final o = _origin, s = _scale;
    return Offset((p.x - o.dx) / s + camX, (p.y - o.dy) / s - backdropH);
  }
  (int, int)? _cellAt(Vector2 p) {
    if (_townShown) return null; // the Town covers the field (town_scene.dart)
    final w = _toWorld(p);
    if (w.dx < camX || w.dx >= camX + state.viewW || w.dy < 0 || w.dy >= fieldH) return null;
    return ((w.dx / tile).floor(), (w.dy / tile).floor());
  }

  @override
  void onTapDown(TapDownEvent event) {
    final p = event.localPosition.toOffset();
    _town.press = null; // a new press: the last one's Town tap is gone (town_scene.dart)
    _bar.down = null; // and the spawn bar's card it went down on (spawn_bar.dart)
    _pocket.down = null; // and the pocket bar's slot (pocket_look.dart)
    _clicks.add((p, _clock));
    _press = (at: p, down: _clock, up: null);
    _grid.down = _bagLootAt(p); // the Bag cell (or the Town's Shop's) under it, for its tap up (bag.dart)
    _handAt = p;
    _touch = event.deviceKind != ui.PointerDeviceKind.mouse;
    _tip.down(event);
    _welcomeTap = welcome != null;
    _pauseDown(); // pause.dart
    if (_coachDown(p)) return; // a guide card took it: its button, or on to its next page (coach.dart)
    if (_foeSplashDown()) return; // it closed a foe skill's splash (foe_splash.dart)
    if (_heraldDown()) return; // it closed a new Hero's splash (hero_splash.dart)
    if (_msg.down(p)) return; // it closed the message window
    if (_chestDown(p)) return; // the boss chest's popup took it (chest_popup.dart)
    if (_wipeAskDown(p)) return; // or the wipe's dialog: Try again or Give up (wipe_ask.dart)
    if (!_welcomeTap && _omenDown(p)) return; // it showed or hid the Shadows' tooltip (omen_look.dart)
    if (!_welcomeTap && _logDown(p)) return; // it opened or closed the battle log (battle_log.dart)
    if (!_welcomeTap && _mapDown(p)) return; // it opened or folded the minimap, or hit it (mini_map.dart)
    if (!_welcomeTap && _troops.down(p)) {
      if (_troops.open) _log.open = false; // the list and the log take turns
      return; // it opened or folded the troop counter's list, or hit it
    }
    _bar.down = _barShown ? _barCardAt(p) : null; // a card of the spawn bar: its tap up buys (spawn_bar.dart)
    _pocket.down = _log.tapped ? null : _pocketSlotAt(p); // a pocket slot not under the open log: its tap up uses it (pocket_look.dart)
    for (final (rect, fn) in _hits) {
      if (rect.contains(p)) {
        Sounds.play(Sfx.click); // every button, tab and book row that acts on a press
        return fn();
      }
    }
    // A press on a Town's scene: as it comes up unmoved a sign or place opens its page, the bare scene shuts the book;
    // dragged, it pans the Town (town_scene.dart).
    if (!_welcomeTap) _townDown(p);
  }

  // On tap up, not down: a drag out of a bag slot must not pick it too.
  @override
  void onTapUp(TapUpEvent event) {
    if (_press case final press?) _press = (at: press.at, down: press.down, up: _clock); // it comes back up
    if (_tip.up()) return; // a long press that showed a tooltip is no tap
    _townTapUp(); // a press on a Town's scene came up unmoved: its tap (town_scene.dart)
    if (_chest.tapped || _wipeAsk.tapped) return; // the press was the chest popup's (chest_popup.dart) or the wipe dialog's
    if (_coach.tapped) return; // or a guide card's (coach.dart): nothing under it reacts
    if (_foeSplash.tapped) return; // or it closed a foe skill's splash (foe_splash.dart)
    final p = event.localPosition.toOffset();
    if (!_welcomeTap && !_herald.tapped && !_msg.tapped && _barTap(p)) return; // the spawn bar: a card buys one (spawn_bar.dart)
    if (!_welcomeTap && !_herald.tapped && !_msg.tapped && !_log.tapped && _pocketTap(p)) return; // the pocket bar: a slot uses one (pocket_look.dart)
    if (_plateTap(p)) return; // a Lepas on the pinned plate: that relic comes off, and the pin stays (plates.dart)
    if (_handTap(p)) return; // loot in hand given to the troop under it, and nothing pinned (drop_popup.dart)
    // On a unit it pins its plate, anywhere else it unpins (plates.dart); not the tap that closed a new Hero's
    // splash, which is all that tap did.
    if (!_herald.tapped) _pinTap(p);
    if (_welcomeTap) return; // it pressed a welcome button: the book under it now wasn't there
    // It closed the Hero's splash or the message window over it, or hit the troop counter, the log or the map.
    if (_herald.tapped || _msg.tapped || _troops.tapped || _log.tapped || _map.tapped || _omenRow.tapped) return;
    if (_licenceTap(p)) return; // a package on the Lisensi page's list: its licences (licence_page.dart); or a Cara Main topic
    // A relic's slot on a row of the Tas page's list, or its Lepas button, does that alone (#91); else a row gives
    // it the pick, or says why it can't (bag.dart).
    for (final (rect, fn) in [..._assign.taps]) {
      if (rect.contains(p)) return fn();
    }
    for (final (rect, _, _, fn) in _assign.rows) {
      if (rect.contains(p)) fn();
    }
    // The Army page: Release's confirm, a button of the detail (Release, its tags), a cell (picks it); any other
    // tap lets an armed Release go (troops_page.dart).
    if (_troopsTap(p)) return;
    // In the Bag, a tap on a cell picks its kind: it is in hand ([_picked]); on the one in hand it puts it back. Only
    // the kind the press went down on (bag.dart).
    _bagTap(p);
  }

  /// A right click puts the loot in hand back, a drag's too (drop_popup.dart); not under a guide card (coach.dart) or a
  /// foe skill's splash (foe_splash.dart).
  @override
  void onSecondaryTapDown(SecondaryTapDownEvent event) {
    if (!_coach.showing && !_foeSplashBusy) _putBack();
  }

  @override
  void onTapCancel(TapCancelEvent event) {
    _press = null;
    _tip.up(); // e.g. the finger moved: a drag
  }

  @override
  void onPointerMove(PointerMoveEvent event) {
    _mouse = _handAt = event.localPosition.toOffset();
    _touch = false;
  }

  @override
  void onDragStart(DragStartEvent event) {
    super.onDragStart(event);
    final p = _dragPos = event.localPosition.toOffset();
    _handAt = p;
    // Flame leaves a drag's kind unknown (a mouse's too): then the press that began it ([onTapDown]) told.
    if (event.deviceKind != ui.PointerDeviceKind.unknown) _touch = event.deviceKind != ui.PointerDeviceKind.mouse;
    // It began on the chest popup (chest_popup.dart), a guide card (coach.dart) or a foe skill's splash (foe_splash.dart).
    if (_chest.tapped || _coach.tapped || _foeSplash.tapped || _wipeAsk.tapped) return;
    if (welcome == null && _log.open && _log.panel.contains(p)) {
      _log.dragY = p.dy; // a drag on the battle log scrolls it (battle_log.dart)
      return;
    }
    if (welcome != null || _welcomeTap || _herald.tapped || _msg.tapped || _troops.tapped || _map.tapped) {
      return;
    }
    if (_barDragStart(p)) return; // a drag on the spawn bar's cards is its: a swipe turns their page (spawn_bar.dart)
    if (_townGrab()) return; // a drag on a Town's scene pans it, past a small move (town_scene.dart)
    if (_pageScrollDragStart(p)) return; // a drag on a book page's part taller than its room scrolls it (page_scroll.dart)
    if (_assign.list.contains(p)) {
      _assign.dragY = p.dy; // a drag on the Tas page's list scrolls it (bag.dart)
      return;
    }
    if (_detail.body.contains(p) && _detail.content > _detail.body.height) {
      _detail.dragY = p.dy; // a drag on the Army detail's body scrolls it, when it is taller than its room (troop_detail.dart)
      return;
    }
    if (_licenceDrag(p)) return; // a drag on a Licenses or How to Play page's column scrolls it (licence_page.dart)
    // The Town's Shop's cells are goods on a shelf, never dragged (bag.dart, decisions-log 230), nor the Smithy's (235).
    for (final (rect, item, plus) in _cellsStay ? const <(Rect, Item, int)>[] : _slots) {
      if (rect.contains(p) && state.bagOf(item, plus) > 0 && !state.over) {
        _itemDrag = item;
        _dragPlus = plus; // an enhanced stack's (decisions-log 255)
        dragAt = event.localPosition.clone();
        return;
      }
    }
    for (final (rect, relic) in _cellsStay ? const <(Rect, Relic)>[] : _relicSlots) {
      if (rect.contains(p) && (state.relicBag[relic] ?? 0) > 0 && !state.over) {
        _relicDrag = relic;
        dragAt = event.localPosition.clone();
        return;
      }
    }
    // Anywhere else, with loot in hand, the drag carries it (not a troop to a new spot); a material never goes on one.
    if (_picked case final loot? when !state.over && loot is! Mat && loot is! PocketKind) {
      _itemDrag = loot is Item ? loot : null;
      _relicDrag = loot is Relic ? loot : null;
      _dragPlus = _pickPlus;
      dragAt = event.localPosition.clone();
      return;
    }
    if (dragging == null && !state.waveActive && !state.over && !_onBar(p)) {
      if (_cellAt(event.localPosition) case (final c, final r)) {
        _relocating = state.troopAt(c, r);
        dragging = _relocating?.type;
        dragAt = event.localPosition.clone();
      }
    }
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    super.onDragUpdate(event);
    // Where the pointer is now: where the drag began plus every move since. Flame's localEndPosition adds the
    // move to where the pointer already is, so it runs one move ahead (a drop could miss the troop under it).
    final p = _dragPos += event.localDelta.toOffset();
    if (_mouse != null) _mouse = p; // no hover events while a button is down
    if (_log.dragY case final y?) {
      _log
        ..scroll += y - p.dy // up: on to older ones
        ..dragY = p.dy;
    }
    if (_assign.dragY != null) _assign.scroll -= event.localDelta.y; // up: on down the list
    _barDragTo(p); // a swipe on the spawn bar's cards turns their page (spawn_bar.dart)
    if (_detail.dragY != null) _detail.scroll -= event.localDelta.y; // the same (troop_detail.dart)
    _pageScrollDragBy(event.localDelta.y); // the same (page_scroll.dart)
    for (final col in _columns) {
      if (col.dragY != null) col.scroll -= event.localDelta.y; // licence_page.dart
    }
    if (dragging != null || _itemDrag != null || _relicDrag != null) dragAt = Vector2(p.dx, p.dy);
    _townDrag(p, event.localDelta.toOffset()); // town_scene.dart
    _handAt = p;
  }

  /// The living troop closest to a screen point, if one is within reach of it: measured from where it
  /// stands, or from [lift] units above (the middle of its body, to point at one in a crowded rank).
  Unit? _troopNear(Vector2 p, {double lift = 0}) {
    final w = _toWorld(p);
    Unit? best;
    var bestD = 12.0;
    for (final u in state.troops) {
      final at = _at(u), d = (Offset(at.x, at.y - lift) - w).distance; // where it is drawn (body_look.dart)
      if (u.alive && d < bestD) (best, bestD) = (u, d);
    }
    return best;
  }

  @override
  void onDragEnd(DragEndEvent event) {
    super.onDragEnd(event);
    if (_townLetGo(event.velocity.toOffset())) return; // a Town's pan glides on; one that never moved is a tap (town_scene.dart)
    final at = dragAt, unit = _relocating, item = _itemDrag, relic = _relicDrag;
    _log.dragY = _assign.dragY = _detail.dragY = _bar.dragX = null;
    _pageScrollDragEnd();
    for (final col in _columns) {
      col.dragY = null;
    }
    dragging = null;
    dragAt = null;
    _relocating = null;
    _itemDrag = null;
    _relicDrag = null;
    if ((item ?? relic) case final loot? when at != null) return _dropLoot(loot, at.toOffset(), item == null ? 0 : _dragPlus); // drop_popup.dart
    if (unit == null || at == null) return;
    if (_cellAt(at) case (final c, final r)) {
      final other = state.troopAt(c, r);
      if (state.move(unit, c, r)) _bodiesPut([unit, ?other]); // drawn there at once (body_look.dart)
    }
  }

  ui.Image _img(String n) => game.images.fromCache(n);

  /// An [Item], [Relic], [Mat] or [PocketKind] icon: a relic's is its [relicIcon], a cell of a sheet (a store artefact's a
  /// ui_icons.png icon), tinted as it says unless [paint] is given; a material's its `mat_<name>.png`, a pocket item's its
  /// `pocket_<name>.png`. An item at +[plus] (an enhanced one, decisions-log 255) in its level's colour ([_plusPaint]), as
  /// faded as [paint] is.
  void _icon(Canvas c, Enum loot, Rect to, [Paint? paint, int plus = 0]) {
    if (loot is Mat) return c.drawImageRect(_img('mat_${loot.name}.png'), const Rect.fromLTWH(0, 0, 32, 32), to, paint ?? _px);
    if (loot is PocketKind) return c.drawImageRect(_img('pocket_${loot.name}.png'), const Rect.fromLTWH(0, 0, 32, 32), to, paint ?? _px);
    if (loot is Relic) {
      final icon = relicIcon(loot), src = Rect.fromLTWH(icon.x.toDouble(), icon.y.toDouble(), icon.size.toDouble(), icon.size.toDouble());
      c.drawImageRect(_img(icon.sheet), src, to, paint ?? switch (icon.tint) { null => _px, final tint => _iconTints[tint] ??= _tintedPaint(Color(tint)) });
      return;
    }
    c.drawImageRect(_img('item_${loot.name}.png'), const Rect.fromLTWH(0, 0, 32, 32), to, plus > 0 ? _plusPaint(plus, paint) : paint ?? _px);
  }

  /// An enhanced item's icon paint (decisions-log 255; forge-design §12, mockup 11): `ColorFilter.mode(tint, srcATop)`,
  /// the level's colour (town.json `enhance.tints`: +1 blue, +2 red, +3 gold, +4 violet, +5 white, the awakenings')
  /// over the art's own pixels at `enhance.tintAlpha` (0.45), so the item still reads; as faded as [over] is (its
  /// alpha: the Smithy's 40%, the ghost in hand), else whole.
  Paint _plusPaint(int plus, [Paint? over]) {
    final e = state.townRules.enhance, alpha = over?.color.a ?? 1.0, tint = e.tints[(plus - 1).clamp(0, e.tints.length - 1)];
    return _plusPaints[(tint, e.tintAlpha, alpha)] ??= Paint()
      ..filterQuality = FilterQuality.none
      ..color = Colors.white.withValues(alpha: alpha)
      ..colorFilter = ColorFilter.mode(Color(tint).withValues(alpha: e.tintAlpha), BlendMode.srcATop);
  }

  /// [relic]'s icon's rect in [r]: a small icon (a 16 px cell, the store artefacts') [inset] in (its callers pass a
  /// tenth) on a card or a glow, any other the whole of [r].
  static Rect _iconIn(Relic relic, Rect r, double inset) => relicIcon(relic).size == 16 ? r.deflate(inset) : r;

  (String, double) _burstStrip(String who) {
    final fx = _plainFx(who);
    return _feetFx.contains(fx) ? ('tiny_fx_$fx.png', _fps) : ('fx_$fx.png', _fxFps);
  }

  /// The burst [who] draws: without its awakening level ([awakeFx]), a skill's `_big` or minion tier
  /// (`summon_<tier>`).
  String _plainFx(String who) {
    final (fx, _) = _awakeOf(who);
    if (fx.endsWith(_bigFx)) return fx.substring(0, fx.length - _bigFx.length); // a skill's bigger hit (skills.dart)
    return _summonPaints.containsKey(fx) ? 'summon' : fx;
  }
  int _frames(String n) {
    final i = _img(n);
    return i.width ~/ i.height;
  }

  /// Draws frame [f] of a strip with [anchor] (in frame pixels) on [at]; with [line], the strip's
  /// awakening outline ([_outlines]) in that paint round it.
  void _frame(Canvas c, String name, int f, Offset at, {bool flip = false, Offset anchor = _feet, Paint? paint, Paint? line}) {
    final img = _img(name), fs = img.height.toDouble();
    final src = Rect.fromLTWH((f % (img.width ~/ fs)) * fs, 0, fs, fs), to = Rect.fromLTWH(-anchor.dx, -anchor.dy, fs, fs);
    c.save();
    c.translate(at.dx, at.dy);
    if (flip) c.scale(-1, 1);
    if (_outlines[name] case final outline? when line != null) c.drawImageRect(outline, src, to, line);
    c.drawImageRect(img, src, to, paint ?? _px);
    c.restore();
  }

  /// The scene seen from [cam] (in world units, [viewW] wide), its clouds [clock] seconds on: the parallax band above
  /// the field, the props line at the horizon and the floor over the field. Also the welcome screen's backdrop.
  void _scenery(Canvas c, double cam, double viewW, double clock, {double cloudTop = fieldFoot}) {
    void draw(String name, List<Rect> copies) {
      final img = _img(name), src = Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble());
      for (final to in copies) {
        c.drawImageRect(img, src, to, _bg);
      }
    }

    // Parallax ([backdropLayers]): each layer repeats sideways and scrolls at its own fraction of the camera. Above the
    // layers the sky's top row, stretched; the clouds ([cloudCopies]) over the sky, under the mountains.
    c.drawImageRect(_img(townLayers.last), const Rect.fromLTWH(0, 0, townLayerW + 0.0, 1), Rect.fromLTRB(0, -_skyAbove, viewW, _bandTop + 0.5), _bg);
    for (final (i, (:image, :copies)) in backdropLayers(cam, viewW).indexed) {
      draw(image, copies);
      if (i == 0) draw('battle_clouds.png', cloudCopies(cam, viewW, clock, cloudTop));
    }
    draw('battle_props.png', propsCopies(cam, viewW)); // the props line, in front of the pines
    draw('battle_floor.png', floorCopies(cam, viewW)); // the floor, with the field
  }

  /// Under the floor's last row (its front edge's, [fieldFoot] under the field's bottom), Floor Tiles1's earth on down to
  /// [bottom] (band units), [viewW] wide (decisions-log 287: the scene framed onto the spawn bar's step leaves more of the
  /// screen under the floor than the floor holds): battle_step.png's earth, one flat colour, as one fill (decisions-log
  /// 295: cell by cell, the floor's smoothed paint left a faint grid of seams in it).
  void _underFloor(Canvas c, double viewW, double bottom) {
    c.drawImageRect(_img('battle_step.png'), _stepEarth, Rect.fromLTRB(0, backdropH + fieldH + fieldFoot - 0.2, viewW, bottom), _bg);
  }

  /// The frame: the field and over it the HUD, every troop seen at its drawn body (body_look.dart).
  @override
  void render(Canvas c) {
    _strips.clear();
    _magicDrawn.clear();
    _bodiesOn();
    try {
      _render(c);
    } finally {
      _bodiesOff();
    }
  }

  void _render(Canvas c) {
    _safe = _safeInsets(); // this frame's (wave_meter.dart's [_edgeL]): the bars may have come or gone
    if (welcome case final w?) return _welcome(c, w);
    final g = state, s = _scale, o = _origin;
    c.drawRect(Offset.zero & Size(size.x, size.y), Paint()..color = const Color(0xFF1B2A1B));
    if (_townShown) {
      _townScene(c, g); // the Town where the field was, none of the field's looks over it (town_scene.dart)
      return _overField(c, g);
    }
    c.save();
    c.translate(o.dx, o.dy);
    c.scale(s);
    // The screen's bottom in the band's units: the floor's earth runs on down to it (decisions-log 287); the clouds from
    // the screen's top.
    final screenBottom = (size.y - o.dy) / s;
    c.clipRect(Rect.fromLTRB(0, 0, g.viewW, screenBottom));
    _scenery(c, camX, g.viewW, _fieldClock, cloudTop: math.max(0.0, -o.dy / s));
    _underFloor(c, g.viewW, screenBottom);

    c.save();
    c.translate(-camX, backdropH);
    _zones(c, g);

    final cell = dragAt == null ? null : _cellAt(dragAt!);
    if (dragging != null && cell != null) {
      final ok = _relocating != null ? g.inZone(cell.$1, cell.$2) : g.canPlace(cell.$1, cell.$2), center = Offset(cell.$1 * tile + tile / 2, cell.$2 * tile + tile / 2);
      c.drawRect(Rect.fromCenter(center: center, width: tile, height: tile),
          Paint()..color = (ok ? Colors.white : Colors.red).withValues(alpha: 0.35));
      if (ok) _discAt(c, center, troopTypes[dragging]!.range, 0.12); // its reach, in the sprites' pixels (pixel_shapes.dart)
    }

    _matLootDraw(c, g); // town_look.dart: the materials lying where they fell, until the wave is won
    _groundZones(c, g); // hero_skill_fx.dart
    _groundRings(c, g); // hero_skill_fx.dart: a monster skill's rings bursting out
    _windTells(c, g); // skills.dart: a monster winding up its skill, its circle (and a lane's arrows) on the ground
    _landingShadows(c, g); // skills.dart: where a Skyfall comes down (#88)

    _statusLines(c, g); // skills.dart: a duel's or Shared Wounds' line, under the sprites
    _pusakaLook.refresh(g); // which type holds which Pusaka, for the rings and the bars (pusaka_look.dart)
    // Draw back-to-front so lower sprites overlap higher ones.
    final drawables = [for (final u in g.units) (u.pos.y, u), for (final u in g.swept) (u.pos.y, u)]..sort((a, b) => a.$1.compareTo(b.$1));
    for (final (_, u) in drawables) {
      if (u != _relocating) _unit(c, g, u);
    }

    for (final sh in g.shots) {
      final who = sh.from.type, at = _shotFrom(sh.from, sh.pos, sh.aim), level = g.awakenLevel(who); // from its drawn body (body_look.dart)
      if (sh.look != ShotLook.plain) {
        _specialShot(c, g, sh.look, who, at, math.atan2(sh.aim.y - sh.pos.y, sh.aim.x - sh.pos.x)); // a Hero skill's
      } else if (_arrows.contains(who)) {
        c.save();
        c.translate(at.dx, at.dy);
        c.rotate(math.atan2(sh.aim.y - sh.pos.y, sh.aim.x - sh.pos.x));
        c.drawImageRect(_img('tiny_arrow_$who.png'), const Rect.fromLTWH(0, 0, 32, 32),
            Rect.fromCenter(center: Offset.zero, width: 32, height: 32), _awakeFx(level));
        c.restore();
      } else if (who == 'wizard') {
        _magicShot(c, g, sh, at, level); // the pack's fireball, or Arcane Blast's ice star (wizard_fx.dart)
      }
    }
    _lineShots(c, g); // hero_skill_fx.dart
    _beams(c, g);
    _zoneSkies(c, g); // what falls on a zone (Bone Rain's arrows, Arrow Rain's)

    for (final (at, who, t0) in _bursts) {
      final (img, fps) = _burstStrip(who);
      final (named, level) = _awakeOf(who);
      final fx = _plainFx(who);
      final paint = _summonPaints[named] ?? (named == 'upgrade' ? _awakeMark(level) : _awakeFx(level)); // the awakening's own in its colour
      final f = ((g.t - t0) * fps).floor();
      if (WizardMagic.ofBurst(fx) case final magic?) {
        // A wizard's shot landing: its sheet's hit frames on the body, at the pack's size (wizard_fx.dart).
        _magicFrame(c, magic, magic.hitFrame(g.t - t0), at - const Offset(0, 4), paint);
        continue;
      }
      if (_feetFx.contains(fx)) {
        _frame(c, img, f, at + const Offset(0, 5), paint: paint);
        continue;
      }
      final fs = _img(img).height.toDouble();
      c.save();
      c.translate(at.dx, at.dy - 4);
      c.scale((fx == 'upgrade' ? 44 : _burstSize) * (level > 0 ? 1.2 : 1) * (named.endsWith(_bigFx) ? _bigScale : 1) / fs); // an awakened troop's bursts are bigger
      _frame(c, img, f, Offset.zero, anchor: Offset(fs / 2, fs / 2), paint: paint);
      c.restore();
    }
    _skillsAbove(c, g); // skills.dart: the troop skills' looks that stand up (a shield, a blade, a column, a dome)
    _windMarks(c, g); // skills.dart: a winding monster's targets, marked

    // The troop being dragged follows the pointer, snapping onto the cell under it.
    if (dragging case final type? when dragAt != null) {
      final w = _toWorld(dragAt!);
      final at = cell != null ? Offset(cell.$1 * tile + tile / 2, cell.$2 * tile + tile / 2 + 5) : w + const Offset(0, 8);
      _frame(c, 'tiny_${type}_idle.png', (_clock * _fps).floor(), at, paint: _ghost, line: _awakeLine(g.awakenLevel(type), ghost: true));
    }
    // Loot dragged or in hand rings no troop: the one it would go to gets the drop popup (#86, drop_popup.dart).
    _heroRing(c); // a new Hero, while its splash shows (hero_splash.dart)
    c.restore();
    c.restore();

    _heroSpotlight(c); // a Hero's cast: the field dims round it (hero_cast.dart)
    _momentVignette(c, g, (o & Size(g.viewW * s, (backdropH + fieldH + fieldFoot) * s)).intersect(Offset.zero & Size(size.x, size.y))); // skills.dart: a boss's moment
    _offViewMarker(c, g); // off_view.dart
    _castPops(c, g, o, s); // skills.dart
    _victory(c, g, o, s);
    _matFlight(c, g, o, s); // town_look.dart: a won wave's materials fly to the Bag
    _grailCutIn(c); // pusaka_look.dart: over the field, under the HUD
    _overField(c, g);
  }

  /// What is drawn over the field, or over a Town's scene (town_scene.dart): the fade between them, the pause's dim, the
  /// HUD, the popups and the cursor.
  void _overField(Canvas c, Game g) {
    _townFadeDim(c); // town_scene.dart: going into a Town or out of one
    _pauseOverlay(c); // pause.dart: the field dimmed and "Pause", under the HUD
    _meterAt = _map.button = _tideAt = Rect.zero;
    _tideLabel = _townMeterText = '';
    if (!g.over) _waveMeter(c, g); // the top right (wave_meter.dart)
    _miniMap(c, g); // under it while open (mini_map.dart)
    _pocketPlace(g); // the pocket bar's place at the right edge, which what hangs under them keeps clear of (pocket_look.dart)
    _omenChips(c, g); // the Shadows' chips under them (omen_look.dart)
    if (!_asideLeft) _townChip(c, g); // the Town chip under those (town_look.dart; with the book showing, after it)
    if (!_asideLeft) _boostChips(c, g); // the boosts' chips under it (tavern_look.dart; likewise)
    if (!_asideLeft) _weakChip(c, g); // the weakened foes' chip under those (wipe_ask.dart; likewise)
    _pinnedPlate(c); // plates.dart: under the HUD
    _bossAt = Rect.zero;
    _bossAside = false;
    if (!g.over) _bossBars(c, g); // boss_bar.dart: also after the win, while the last one's bar breaks away
    _hud(c, _held is Item ? _heldOver?.type : null); // the Tas page lights the row of the type an item would go to
    _dropPopup(c); // drop_popup.dart: over the troop the loot would go to, and the loot at the pointer with its count
    _coachPointer(c); // the guide's pointer between waves, over the book (coach.dart)
    _heroCutIn(c); // a Hero's cast: its band across the screen (hero_cast.dart)
    _foeCutIn(c); // a monster champion's skill: its banner (foe_cut_in.dart)
    _foeSplashCard(c); // a monster skill's first sighting: the field frozen under its splash (foe_splash.dart)
    _heroSplash(c, g); // over the book too (hero_splash.dart)
    _chestPopup(c, g); // the boss's chest, after the splash (chest_popup.dart)
    _wipeAskDialog(c, g); // after a wipe: Try again or Give up (wipe_ask.dart)
    _scoreScreens(c);
    _messageBox(c);
    _coachCard(c); // a guide card over everything (coach.dart)
    _tooltip(c);
    _fpsReadout(c); // fps_readout.dart: over it all but the cursor, while "Show FPS" is on
    _cursor(c);
  }

  /// The pack's pixel cursor (ui_icons.png): an arrow that presses when it clicks (its two press frames,
  /// [cursorFrame], #72), a hand over anything that can be tapped or dragged (it has no press frames: it dips
  /// a sprite pixel while the press shows), and a little burst of sparks (ui_click.png) where it clicks.
  void _cursor(Canvas c) {
    const k = 2.0, clickFps = 12.0;
    _clicks.removeWhere((cl) => (_clock - cl.$2) * clickFps >= 4);
    for (final (at, t0) in _clicks) {
      c.drawImageRect(_img('ui_click.png'), Rect.fromLTWH(((_clock - t0) * clickFps).floor() * 16.0, 0, 16, 16),
          Rect.fromCenter(center: at, width: 16 * k, height: 16 * k), _px);
    }
    final p = dragAt?.toOffset() ?? _mouse;
    if (p == null) return;
    final over = [..._hits.map((h) => h.$1), ..._cards.map((h) => h.$1), ..._slots.map((h) => h.$1), ..._relicSlots.map((h) => h.$1), ..._matSlots.map((h) => h.$1), ..._pocketCells.map((h) => h.$1),
      ..._assign.rows.map((h) => h.$1), ..._assign.taps.map((h) => h.$1), ..._plateTaps.map((h) => h.$1), ..._bar.cards.map((h) => h.$1), if (_pocketLive) ..._pocket.cells, if (_cards.isNotEmpty) _release.confirm,
      if (welcome == null) ...[_troops.button, _map.button, ..._townTaps]];
    final hand = dragAt != null || over.any((r) => r.contains(p)) || (welcome == null && _unitAt(p) != null), // a unit: a tap pins its plate
        frame = cursorFrame(_press, _clock);
    final (src, hot) = hand
        ? (const Rect.fromLTWH(48, 224, 16, 16), Offset(6, frame > 0 && dragAt == null ? 1 : 2))
        : (Rect.fromLTWH(16.0 * frame, 224, 16, 16), const Offset(4, 2));
    c.drawImageRect(_img('ui_icons.png'), src, (p - hot * k) & const Size(16 * k, 16 * k), _px);
  }

  /// The skill strip [u] plays now ([Unit.skillAnim], skill_strips.dart; decisions-log 299), as `tiny_<type>`'s [k]: its
  /// file and frame. None while a move carries it (its leap or charge is drawn as before), while it is a slime (Slime
  /// Hex), and once the strip has played out.
  (String, int)? _skillStrip(Game g, Unit u, String k) {
    final a = u.skillAnim;
    if (a == null || u.move != null || u.effects.containsKey(Status.hex)) return null;
    final name = '${k}_${a.strip.anim}.png', f = skillStripFrame(a, _frames(name), g.t);
    return f == null ? null : (name, f);
  }

  /// Whether [u]'s last attack began with its skill (between the cast and the blow: a skill that swings, a Volley's
  /// arrows, a blow in the cast's tick): its skill strip shows that swing, so the attack strip doesn't replay after it.
  bool _skillSwing(Unit u) => switch (u.skillAnim) { final a? => u.attackedAt >= a.from && u.attackedAt <= a.strikeAt, null => false };

  /// Death, then summoning / rising, an attack in progress, a flinch when hit, walking, or idle.
  /// Right after a won wave the troops hop for joy.
  void _unit(Canvas c, Game g, Unit u) {
    // A hexed monster (Slime Hex) is drawn as a slime, dying one too.
    final k = 'tiny_${u.effects.containsKey(Status.hex) ? slimeHexK.form : u.type}', flip = u.dir < 0, cheer = g.t - g.victoryAt;
    final ground = Offset(u.pos.x, u.pos.y + 5), level = u.side == Side.troop ? g.awakenLevel(u.type) : 0;
    var feet = ground;
    // The shadow stays on the ground while the body hops; an awakened troop's is in its level's colour,
    // and so is the outline round its body.
    _frame(c, '${k}_shadow.png', 0, feet, flip: flip, paint: level > 0 ? _awakeShadow(u, level) : _shadowPaint);
    _pusakaRing(c, u, ground); // pusaka_look.dart: its type's Pusaka, under its feet
    // A troop's awakening outline, or a monster's rank: its body recoloured and outlined (tier_look.dart).
    // A troop under the Bayangan Blight: its body part way olive (omen_look.dart).
    final line = u.side == Side.enemy ? _tierLines[u.tier] : _rageLine(g, u) ?? _awakeLine(level),
        body = u.side == Side.enemy ? _tierPaints[u.tier] : (g.blighted(u) ? _blightPaint : null);
    _guardRing(c, g, u, ground); // skills.dart
    _statusRings(c, g, u, ground); // skills.dart: the effects' rings (a monster's, a troop's with no icon)
    _braceRing(c, g, u, ground); // hero_move_fx.dart: Spear Wall
    _chain(c, u); // hero_move_fx.dart: Chain Hook pulling it
    _afterimages(c, g, u, k, flip); // skills.dart: a Phantom Rush dash's afterimages (#88)
    if ((g.over || g.swept.contains(u)) && u.side == Side.enemy && u.alive) {
      // The monsters won: they hop for joy like the troops after a won wave (on the screen clock, since
      // the game clock has stopped), or a moment before a wipe's sweep takes them (wipe.dart).
      _frame(c, '${k}_idle.png', (_clock * _fps).floor(), feet - Offset(0, math.sin(_clock * 10 + u.pos.y).abs() * 4),
          flip: flip, paint: body, line: line);
      return;
    }
    if (u.side == Side.troop && u.alive && cheer < victoryTime) {
      feet -= Offset(0, (math.sin(cheer * 10 + u.pos.y)).abs() * 4);
    }
    // A leap's hop (hero_moves.dart): the body and its bars rise off the ground, walking in the air.
    final lift = u.alive ? u.move?.liftAt(g.t) ?? 0.0 : 0.0;
    feet -= Offset(0, lift);
    if (u.hero && u.alive) _heroHalo(c, u, feet); // hero.dart
    _rageGlow(c, g, u, feet); // skills.dart: Rampage's aura, behind the body
    final act = _casters.contains(u.type) && !u.swung ? '${k}_cast.png' : '${k}_attack.png', atkLen = _frames(act) / _fps;
    // Squeeze the attack into the attack interval so quick attackers keep up with their hits; a healer's
    // cast into the time it stands still for it ([healCast]).
    final since = (g.t - u.attackedAt) * math.max(1.0, atkLen / (u.stats.heals ? math.min(u.stats.rate, healCast) : g.attackEvery(u)));
    final grow = u.effects.isNotEmpty && g.under(u, Status.giant); // Giant's Rage: the body drawn bigger
    if (grow) {
      c.save();
      c.translate(feet.dx, feet.dy);
      c.scale(giantRageK.size);
      c.translate(-feet.dx, -feet.dy);
    }
    final (String, int) look; // the strip and its frame
    if (u.dying >= 0) {
      final n = _frames('${k}_death.png');
      look = ('${k}_death.png', math.min(n - 1, (u.dying / deathTime * n).floor()));
    } else if (g.t < u.downUntil) {
      // A heap of bones (Reassemble): its death strip to the middle frame, then back as it stands again.
      final n = _frames('${k}_death.png'), p = 1 - (u.downUntil - g.t) / reassembleK.down;
      look = ('${k}_death.png', ((n - 1) / 2 * (1 - (2 * p - 1).abs())).round());
    } else if (g.t < u.stunUntil) {
      look = ('${k}_hurt.png', 0); // stunned (Crushing Blow): frozen mid-flinch
    } else if (g.t < u.busyUntil) {
      // Summoning or rising ([_summoners]' own strip); a troop brought back by Resurrection has none, so it
      // rises by its death strip played backwards.
      final rise = _summoners.contains(u.type) ? '${k}_summon.png' : '${k}_death.png', n = _frames(rise);
      final f = ((g.t - u.busyFrom) / (u.busyUntil - u.busyFrom) * n).floor().clamp(0, n - 1);
      look = (rise, _summoners.contains(u.type) ? f : n - 1 - f);
    } else if (u.troopWind == null && u.move == null && !g.braced(u) && _bodyWalks(g, u)) {
      // Its drawn body moves (body_look.dart): it walks, over the idle, flinch and attack strips and a skill strip's tail,
      // its stride as quick as it goes.
      look = ('${k}_walk.png', _strideFrame(g, u));
    } else if (_skillStrip(g, u, k) case (final strip, final f)) {
      look = (strip, f); // a skill's strip (skill_strips.dart)
    } else if (since < atkLen && !_skillSwing(u)) {
      look = (act, (since * _fps).floor());
    } else if (g.t - u.hurtAt < _hurtTime) {
      look = ('${k}_hurt.png', ((g.t - u.hurtAt) / _hurtTime * _frames('${k}_hurt.png')).floor());
    } else if (g.braced(u)) {
      // Spear Wall's brace (hero_moves.dart): the attack strip held at full thrust, its middle frame.
      look = ('${k}_attack.png', (_frames('${k}_attack.png') - 1) ~/ 2);
    } else if (u.moving && u.move == null) {
      look = ('${k}_walk.png', _strideFrame(g, u)); // walking: a troop's stride by its body's pace (body_look.dart)
    } else {
      // A charge gallops: its walk strip at [chargeK].speed × the rate.
      final pace = u.move is Charge ? chargeK.speed : 1.0;
      look = ('${k}_${u.moving || lift > 0 ? 'walk' : 'idle'}.png', (g.t * _fps * pace).floor());
    }
    // A phantom (Phantom Rush's dash and its way home, decisions-log 320): its body see-through and washed in the rush's
    // magenta, its afterimages' colour, the whole time no blow lands on it (skills.dart).
    final ghost = u.alive && u.move != null && isPhantom(u);
    _frame(c, look.$1, look.$2, feet, flip: flip, paint: ghost ? _phantomBody : body, line: line);
    if (ghost) _frame(c, look.$1, look.$2, feet, flip: flip, paint: _phantomWash);
    if (u.side == Side.troop) _strips[u] = look.$1.substring(k.length + 1, look.$1.length - 4); // for tests
    if (grow) c.restore();
    if (level > 0 && u.alive) _auraSparks(c, u, level, ground);
    if (u.alive) {
      // The bar ([unitBar]) from ui_bars.png: the empty capsule and 10x4 fill strips (green troops, red
      // monsters, ...) cut to what is left. A unit with MP (every troop, the necromancers) has one taller
      // box, HP over MP.
      const k = barK;
      final hasMp = u.stats.mp > 0, bar = unitBar(u.pos.x, u.pos.y - lift, mp: hasMp), box = bar.box;
      final bars = _img('ui_bars.png');
      // The pack's strips drawn by hand (colour over a quarter of shade, as the strips' 3 px over 1 px), for the
      // fills it has no strip for.
      void strip(Rect to, (Color, Color) colors) {
        final shade = to.bottom - to.height / 4;
        c.drawRect(Rect.fromLTRB(to.left, to.top, to.right, shade), Paint()..color = colors.$1);
        c.drawRect(Rect.fromLTRB(to.left, shade, to.right, to.bottom), Paint()..color = colors.$2);
      }

      // The capsule: its rim rows kept, its middle rows stretched to the box (a hair under the rims, so no seam
      // shows between them).
      c.drawImageRect(bars, const Rect.fromLTWH(82, 34, 12, 4), Rect.fromLTRB(box.left, box.top + k - 0.05, box.right, box.bottom - k + 0.05), _px);
      c.drawImageRect(bars, const Rect.fromLTWH(82, 33, 12, 1), Rect.fromLTWH(box.left, box.top, box.width, k), _px);
      c.drawImageRect(bars, const Rect.fromLTWH(82, 37, 12, 1), Rect.fromLTWH(box.left, box.bottom - k, box.width, k), _px);
      final fill = (u.hp / u.maxHp).clamp(0.0, 1.0), to = Rect.fromLTWH(bar.hp.left, bar.hp.top, bar.hp.width * fill, bar.hp.height);
      // Monster rank by colour: the pack's red strip, then silver / gold / purple / orange ([_tierBar]).
      switch (u.side == Side.troop ? null : u.tier) {
        case null || Tier.normal:
          c.drawImageRect(bars, Rect.fromLTWH(83, u.side == Side.troop ? 58.0 : 42.0, 10 * fill, 4), to, _px);
        case final t:
          strip(to, _tierBar[t]!);
      }
      // MP: under the HP in the same box, the pack's blue strip cut to the MP left; a monster's in cyan
      // ([_monsterMp]).
      if (bar.mp case final full?) {
        final mp = (u.mp / u.stats.mp).clamp(0.0, 1.0), mpTo = Rect.fromLTWH(full.left, full.top, full.width * mp, full.height);
        if (u.side == Side.troop) {
          c.drawImageRect(bars, Rect.fromLTWH(83, 50, 10 * mp, 4), mpTo, _px);
        } else {
          strip(mpTo, _monsterMp);
        }
      }
      // (A type's upgrades show on its card in the book; over every troop they only crowd the field.)
      for (final (i, r) in u.relics.indexed) {
        _icon(c, r, Rect.fromLTWH(box.left - 6.5 - 6.5 * i, box.center.dy - 3, 6, 6)); // just left of the bar; a Hero's second further left
      }
      _pusakaBarIcon(c, u, box); // its type's Pusaka, left of those (pusaka_look.dart)
      if (u.hero) _heroCrown(c, u, box.top); // just above it
      _statusMarks(c, g, u, Offset(u.pos.x, box.top - (u.hero ? 9 : 1))); // skills.dart: a Hero skill's marks, above them
      if (level > 0) _levelPips(c, Offset(box.right + 1, box.center.dy), level); // just right of it
    }
  }

  /// The deploy zone, shown only while a troop is being dragged to a new spot in it.
  void _zones(Canvas c, Game g) {
    if (dragging == null) return;
    c.drawRect(Rect.fromLTWH(g.baseX, 0, g.zoneCols * tile, fieldH), Paint()..color = Colors.white.withValues(alpha: 0.14));
  }

  /// One line of text in the game's font (hud_font.dart) at HUD size [size], in the body weight or, with [bold], the
  /// titles'.
  void _text(Canvas c, String t, Offset at,
      {double size = 18, Color color = Colors.white, Anchor anchor = Anchor.centerLeft, Color? outline, bool bold = false}) {
    if (t.contains(_starGlyph)) return _starText(c, t, at, size: size, color: color, anchor: anchor, outline: outline, bold: bold);
    if (outline != null) {
      final paint = _textPaint(t, size, outline, bold); // the five passes share one layout
      for (final d in const [Offset(-2, 0), Offset(2, 0), Offset(0, -2), Offset(0, 2), Offset(2, 2)]) {
        paint.render(c, t, Vector2(at.dx + d.dx, at.dy + d.dy), anchor: anchor);
      }
    }
    _textPaint(t, size, color, bold).render(c, t, Vector2(at.dx, at.dy), anchor: anchor);
  }

  /// The [TextPaint] for [t] in the game's font at [size], [color] and [bold] (decisions-log 317). Flame's keeps the
  /// layouts of the last few texts it drew, so one kept per text and look lays a label out once instead of every frame
  /// (an outlined one took six layouts a frame: five outline passes and the fill). A fading colour (alpha under 1, the
  /// cast pops) changes every frame: its paint is new each call, its outline passes still sharing it. The kept ones go
  /// past [_textPaintsMost], and when the fonts change ([_fontsChanged]: a layout made before the game's font loaded
  /// would keep the fallback's).
  TextPaint _textPaint(String t, double size, Color color, bool bold) {
    if (color.a < 1) return TextPaint(style: hudStyle(size, color: color, bold: bold));
    final key = (t, size, color, bold);
    if (_textPaints[key] case final paint?) return paint;
    if (_textPaints.length >= _textPaintsMost) _textPaints.clear();
    return _textPaints[key] = TextPaint(style: hudStyle(size, color: color, bold: bold));
  }

  @override
  void onMount() {
    super.onMount();
    PaintingBinding.instance.systemFonts.addListener(_fontsChanged);
  }

  @override
  void onRemove() {
    PaintingBinding.instance.systemFonts.removeListener(_fontsChanged);
    super.onRemove();
  }

  /// A font was loaded (the game's own, or a test's): the kept layouts may be the fallback font's ([_textPaint]).
  void _fontsChanged() => _textPaints.clear();

  /// [_text] for a line with a [_starGlyph] in it, which the game's font lacks (the Pusaka's stars): each one is drawn
  /// as ui_icons.png's full star ([_starIcon]), [_starW] wide, between the text's pieces.
  void _starText(Canvas c, String t, Offset at,
      {required double size, required Color color, required Anchor anchor, Color? outline, bool bold = false}) {
    final h = TextPaint(style: hudStyle(size, bold: bold)).getLineMetrics('0').height, s = _starW(size);
    var x = at.dx - anchor.x * _textWidth(t, size, bold: bold);
    final top = at.dy - anchor.y * h;
    for (final (i, piece) in t.split(_starGlyph).indexed) {
      if (i > 0) {
        c.drawImageRect(_img('ui_icons.png'), _starIcon, Rect.fromLTWH(x, top + (h - s) / 2, s, s), _px);
        x += s;
      }
      if (piece.isEmpty) continue;
      _text(c, piece, Offset(x, top), size: size, color: color, anchor: Anchor.topLeft, outline: outline, bold: bold);
      x += _textWidth(piece, size, bold: bold);
    }
  }

  void _panel(Canvas c, Rect r) {
    final rr = RRect.fromRectAndRadius(r, const Radius.circular(10));
    c.drawRRect(rr, Paint()..color = const Color(0xFF3B2716));
    c.drawRRect(rr,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = const Color(0xFF8A5E34));
  }

  /// "VICTORY!" pops in over the field with twinkling stars, then fades: the wave, the gold bonus, the Pusaka's one line
  /// ([pusakaWinLine]), "Towns have a Shop now!" when that wave opened the store ([shopInTowns]), "Peti Bos: pilih 1 dari 3!" when it brought a
  /// chest, the loot, and the troops that fell in the wave.
  void _victory(Canvas c, Game g, Offset o, double s) {
    final p = g.t - g.victoryAt;
    _victoryLoot = const [];
    if (p < 0 || p > victoryTime || g.over) return;
    final fade = p > victoryTime - 0.4 ? (victoryTime - p) / 0.4 : 1.0;
    final pop = p < 0.3 ? 1 + 0.25 * math.sin(p / 0.3 * math.pi) * (p / 0.3) : 1.0; // grow in with a little overshoot
    final gold = Color.fromRGBO(255, 214, 90, fade), dark = Color.fromRGBO(60, 30, 10, fade * 0.9);
    final white = Color.fromRGBO(255, 255, 255, fade), maxW = size.x - 40;
    final loot = Paint()
      ..filterQuality = FilterQuality.none
      ..color = white;
    final grey = Paint()
      ..filterQuality = FilterQuality.none
      ..color = white
      ..colorFilter = _greyscale;
    void sprite(String type, Rect r) {
      final b = _idleBounds[type]!, k = math.min(r.width / b.width, r.height / b.height);
      c.save();
      c.translate(r.center.dx, r.bottom);
      c.scale(k);
      _frame(c, 'book_${type}_idle', 0, Offset.zero, anchor: Offset(b.center.dx, b.bottom), paint: grey);
      c.restore();
    }

    // The loot: the materials the wave dropped (town.dart), each once in their order, its count before its icon ("3x");
    // no item or relic drops (decisions-log 321). The troops that fell: by name while few did ("Aldo Ash (Knight)"),
    // else each type once with its count; sprites greyed.
    final won = <MapEntry<Enum, int>>[
      for (final m in Mat.values) if (g.lastMaterials[m] case final n?) MapEntry(m, n),
    ];
    _victoryLoot = [for (final e in won) (e.key, e.value)];
    final lootLine = [for (final e in won) ('${e.value}x', (Rect r) => _icon(c, e.key, r, loot), '')];
    // Wave [Store.shopFrom] won: a Town's Shop opens (shop_page.dart; none from wave 1, [Store.shopJustOpened]); a boss
    // wave's: its chest waits (chest_popup.dart).
    final storeLine = [
      if (g.shopJustOpened) ('', (Rect r) => _uiIcon(c, _icCoins, r, loot), shopInTowns),
      if (g.chests.any((ch) => ch.kind == ChestKind.boss && ch.wave == g.wave))
        ('', (Rect r) => _uiIcon(c, _icChest, r, loot), '${Words.bossChest}: pick 1 of $draftCards!'),
    ];
    // The win before the tide's first wave (#92): "The Tide rises!" led by the wave meter's swords, then what it means.
    final tideLine = [
      if (g.tideRising) ...[('', (Rect r) => _uiIcon(c, _icSwords, r, loot), tideNews.$1), ('', null, tideNews.$2)],
    ];
    final tideInk = _tideInk.withValues(alpha: fade);
    final fell = g.lastFallen;
    final fellLine = [
      if (fell.length <= fallenNamesMax)
        for (final u in fell) ('', (Rect r) => sprite(u.type, r), '${u.hero ? 'Hero ' : ''}${u.name} (${troopTypeNames[u.type]})')
      else
        for (final MapEntry(key: type, value: n) in fallenCounts(fell).entries) ('${n}x', (Rect r) => sprite(type, r), ''),
    ];
    final fellLabel = ('Fallen:', Color.fromRGBO(255, 138, 138, fade));
    // Centred on the field at 40% of its height, raised while its lines would run off the field's bottom.
    // The Pusaka's one line under the gold (decisions-log 149, pusaka_look.dart): the wave's best counter and the relics
    // back in the bag; the rows under it move down.
    final win = _winLine(g, maxW), rows = win == null ? 108.0 : 142.0;
    final lootAt = _popupRows(c, tideLine, _popupRows(c, storeLine, rows, maxW, gold, dark, draw: false), maxW, tideInk, dark, draw: false);
    final end = _popupRows(c, fellLine, _popupRows(c, lootLine, lootAt, maxW, white, dark, draw: false), maxW, white, dark,
        label: fellLabel, draw: false);
    final middle = math.max(40.0, math.min(o.dy + (backdropH + fieldH * 0.4) * s, size.y - 8 - (end - 20)));
    final center = Offset(o.dx + g.viewW * s / 2, middle);

    // Sparks twinkling round it: ui_click.png's x ([_sparkSteps]) at 14 spots going slowly round, each on a clock of
    // its own, gold and white by turns, 4 screen px a sprite px.
    final goldSpark = Paint()
      ..filterQuality = FilterQuality.none
      ..colorFilter = _dye(gold.withValues(alpha: 1))
      ..color = white;
    for (var i = 0; i < 14; i++) {
      final a = i / 14 * 2 * math.pi + p * 0.8, r = 120 + 14 * math.sin(p * 4 + i);
      final at = center + Offset(math.cos(a) * r * 1.6, math.sin(a) * r * 0.6);
      final f = _sparkSteps[(p * _sparkFps + i * 2.7).floor() % _sparkSteps.length];
      if (f < 0) continue;
      c.drawImageRect(_img('ui_click.png'), Rect.fromLTWH(f * 16.0, 0, 16, 16), Rect.fromCenter(center: at, width: 64, height: 64),
          i.isEven ? goldSpark : loot);
    }

    c.save();
    c.translate(center.dx, center.dy);
    c.scale(math.min(1.0, p / 0.3) * pop);
    _text(c, 'VICTORY!', Offset.zero, size: 56, color: gold, anchor: Anchor.center, outline: dark, bold: true);
    _text(c, 'Wave ${g.wave}', const Offset(0, 44), size: 20, color: white, anchor: Anchor.center, outline: dark);
    _text(c, '+${g.lastBonus} Gold', const Offset(0, 72), size: 22, color: gold, anchor: Anchor.center, outline: dark);
    if (win case (final line, final fs)) {
      _text(c, line, const Offset(0, 106), size: fs, color: Color.fromRGBO(255, 233, 168, fade), anchor: Anchor.center, outline: dark);
    }
    _popupRows(c, tideLine, _popupRows(c, storeLine, rows, maxW, gold, dark), maxW, tideInk, dark);
    _popupRows(c, fellLine, _popupRows(c, lootLine, lootAt, maxW, white, dark), maxW, white, dark, label: fellLabel);
    c.restore();
  }

  /// The store's tab while it is locked: its icon grey.
  static final _lockedTab = Paint()
    ..filterQuality = FilterQuality.none
    ..colorFilter = _greyscale;

  /// A fallen troop's sprite in the "VICTORY!" popup: grey, a little dark.
  static const _greyscale = ColorFilter.matrix(<double>[
    0.17, 0.57, 0.06, 0, 0, //
    0.17, 0.57, 0.06, 0, 0, //
    0.17, 0.57, 0.06, 0, 0, //
    0, 0, 0, 1, 0, //
  ]);

  /// Centred lines in the "VICTORY!" popup (20 px text, white with a dark [outline]), wrapped at [maxW]: an
  /// optional [label] (its text and colour), then each entry: its lead text, a 32 px picture (drawn into
  /// the rect it is given; none when null) and its tail text, 14 px apart. The first line's middle is at [y]; returns
  /// where the next line's goes (still [y] when there is no entry). With [draw] false it only measures.
  double _popupRows(Canvas c, List<(String, void Function(Rect)?, String)> entries, double y, double maxW, Color ink,
      Color outline, {(String, Color)? label, bool draw = true}) {
    if (entries.isEmpty) return y;
    const font = 20.0, pic = 32.0, gap = 14.0, lineH = 40.0;
    final metrics = TextPaint(style: hudStyle(font));
    double w(String s) => s.isEmpty ? 0 : metrics.getLineMetrics(s).width + 4; // with its 4 px to the picture
    final parts = <(double, void Function(double x, double y))>[ // width, and how to draw it from its left
      if (label case (final text, final color))
        (w(text) - 4, (x, y) => _text(c, text, Offset(x, y), size: font, color: color, outline: outline)),
      for (final (lead, picture, tail) in entries)
        (w(lead) + (picture == null ? -4 : pic) + w(tail), (x, y) {
          final p = picture == null ? -4 : pic; // without a picture the tail starts where it would
          if (lead.isNotEmpty) _text(c, lead, Offset(x, y), size: font, color: ink, outline: outline);
          picture?.call(Rect.fromLTWH(x + w(lead), y - pic / 2, pic, pic));
          if (tail.isNotEmpty) _text(c, tail, Offset(x + w(lead) + p + 4, y), size: font, color: ink, outline: outline);
        }),
    ];
    final lines = [<(double, void Function(double, double))>[]];
    var width = 0.0;
    for (final part in parts) {
      if (lines.last.isNotEmpty && width + gap + part.$1 > maxW) {
        lines.add([]);
        width = 0;
      }
      width += (lines.last.isEmpty ? 0 : gap) + part.$1;
      lines.last.add(part);
    }
    for (final line in lines) {
      var x = -(line.fold(0.0, (a, p) => a + p.$1) + gap * (line.length - 1)) / 2;
      for (final (pw, drawAt) in line) {
        if (draw) drawAt(x, y);
        x += pw + gap;
      }
      y += lineH;
    }
    return y;
  }

  // The buttons' colours: rows of ui_buttons.png, 48 px apart (0 light brown, 1 white, 2 green, 3 blue,
  // 4 orange, 5 red, 6 purple, 7 peach, 8 grey; button_fx.dart). ui_all.png (the top of Cute Fantasy UI's
  // UI_ALL.png): the page frames.
  static const _btnLight = 0, _btnWhite = 1, _btnGreen = 2, _btnOrange = 4, _btnRed = 5;
  static const _framePlain = Rect.fromLTWH(1021, 13, 22, 22), _frameGrey = Rect.fromLTWH(1165, 13, 22, 22);
  static const _frameLit = Rect.fromLTWH(1019, 107, 26, 26);
  // ui_icons.png's 16x16 icons, by their top left.
  static const _icCoin = Offset(96, 0), _icSword = Offset(16, 16), _icGear = Offset(32, 16),
      _icSwords = Offset(112, 16), _icNote = Offset(144, 64), _icSpeaker = Offset(160, 64),
      _icBag = Offset(144, 32);
  // ui_book_marks.png (Book_UI.png's bookmarks, tool/import_fx.py): page tabs 20 wide, open at the bottom (tan
  // short, paper tall), and ribbon flags 18 tall with a notched right end, 48 px apart by colour.
  static const _tabTan = Rect.fromLTWH(2, 4, 20, 18), _tabPaper = Rect.fromLTWH(35, 50, 20, 21);
  static const _ribRed = 0, _ribOrange = 3;
  static Rect _ribbonClosed(int colour) => Rect.fromLTWH(162 + 48.0 * colour, 53, 28, 18); // closed left end (1 px)

  void _uiIcon(Canvas c, Offset icon, Rect to, [Paint? paint]) => c.drawImageRect(_img('ui_icons.png'), icon & const Size(16, 16), to, paint ?? _px);

  /// [src] of ui_all.png (or [sheet]) stretched over [to] by 9-slice: corners [l],[t],[r],[b] sprite
  /// pixels, drawn [k] screen pixels per sprite pixel, with [paint] (a recoloured frame's) or the plain one. Each piece
  /// reaches [seam] px into the next, so no hairline shows between them at fractional edges; on whole pixels at a whole
  /// [k] none is needed, and 0 keeps a cut corner clear (the overlap's half-covered pixel would darken it).
  void _nine(Canvas c, Rect src, Rect to, double k,
      {double l = 5, double t = 5, double r = 5, double b = 5, String sheet = 'ui_all.png', Paint? paint, double seam = 0.5}) {
    final img = _img(sheet);
    final sx = [src.left, src.left + l, src.right - r, src.right], sy = [src.top, src.top + t, src.bottom - b, src.bottom];
    final dx = [to.left, to.left + l * k, to.right - r * k, to.right], dy = [to.top, to.top + t * k, to.bottom - b * k, to.bottom];
    for (var i = 0; i < 3; i++) {
      for (var j = 0; j < 3; j++) {
        if (sx[i] == sx[i + 1] || sy[j] == sy[j + 1]) continue; // a zero slice: the piece stretches whole that way
        c.drawImageRect(img, Rect.fromLTRB(sx[i], sy[j], sx[i + 1], sy[j + 1]), Rect.fromLTRB(dx[i], dy[j], dx[i + 1] + seam, dy[j + 1] + seam), paint ?? _px);
      }
    }
  }

  /// A 9-patch button (light brown, orange while [active], grey when not [enabled], or colour [row])
  /// with its [label] inked on it: lit under the mouse, pushed in while pressed (button_fx.dart). Its tap goes in
  /// [into], [_hits] (on tap down) unless given (the Army page's detail takes its own on tap up). Returns how far its
  /// face moved down, for an icon drawn on it.
  double _button(Canvas c, Rect r, VoidCallback fn,
      {String label = '', double size = 18, bool active = false, bool enabled = true, int row = _btnLight, List<(Rect, VoidCallback)>? into}) {
    final k = (r.height / 16).floorToDouble().clamp(1.0, 3.0);
    final use = !enabled ? _btnWhite : active ? _btnOrange : row;
    final sink = _btnFrame(c, r, use, _look(r, enabled: enabled), k);
    if (label.isNotEmpty) {
      _text(c, label, r.center + Offset(0, sink - k), size: size, anchor: Anchor.center, // a touch up: the bottom is the button's edge
          color: enabled ? const Color(0xFF3B2210) : const Color(0xFF8E8A86));
    }
    if (enabled) (into ?? _hits).add((r, fn));
    return sink;
  }

  /// Between waves (after the cheering) the book floats in on the right; in battle it closes, and a button in
  /// the top left row opens it mid-fight. [target] is the troop type an item being dragged would go to.
  void _hud(Canvas c, [String? target]) {
    final g = state;
    _hits.clear();
    _sendAt = _menuAt = _sendNoteAt = _heroCutAt = _foeLook.button = _fpsButtonAt = Rect.zero;
    _cards.clear();
    _rowStatTexts.clear();
    _tasStatTexts.clear();
    _release.clear();
    _army.clear();
    _detail.clear();
    _slots.clear();
    _relicSlots.clear();
    _matSlots.clear();
    _pocketCells.clear();
    _capsuleBars.clear();
    _bagShown = false;
    _tip.rows.clear();
    _tip.hints.clear();
    _bookArea = _storeTabAt = _bookBtnAt = _heartsGoldAt = _livesAt = _goldAt = Rect.zero;
    _pagesAt = (Rect.zero, Rect.zero);
    _tabAt.clear();
    _tabTapAt.clear();
    _storeAt.clear();
    _logKeep.clear();
    _tempaMarks.clear();
    _carveBadges.clear();
    _assign.clear();
    _bag.clear();
    _shop.clear();
    _smithy.clear();
    _tavernPage.clear();
    _lic.clear();
    _guide.clear();
    _volumeAt.clear();
    if (_bookT > 0.01) _book(c, g, target);
    _spawnBar(c, g); // the bottom of the battle screen: a card per troop type, a tap buys one (spawn_bar.dart)
    if (_asideLeft) {
      // The open map and the Town chip stay under the wave meter, over the book's top edge (mini_map.dart, town_look.dart).
      _miniMapDraw(c, g);
      _townChip(c, g);
      _boostChips(c, g);
      _weakChip(c, g);
    }
    _pocketBar(c, g); // the pocket bar at the field's right edge, under the open log (pocket_look.dart)
    // The top left: the troop counter, always, the hearts and the gold on one panel, the book button in a wave
    // (troop_counter.dart, hud_row.dart); the top right: x2 and Auto left of the wave meter (hud_row.dart); the top
    // centre: the Start/Pause toggle (start_button.dart).
    _troopCounter(c, g);
    _speedAuto(c, g);
    _startToggle(c, g);
    _chestChip(c, g); // a chest waiting for its popup: the "Chest!" chip under the toggle (chest_popup.dart)
    _battleLog(c, g); // the bottom right (battle_log.dart)

    if (g.over) _gameOver(c, g); // scoreboard.dart
  }

  /// Where a page's title (22·[ts] tall) has its middle on the page's writing [page]: its line on the writing's top edge,
  /// under the book's padding; and where the page's writing under the title starts (7·[ts] below the title's line).
  double _titleY(Rect page, double ts) => page.top + 11 * ts;
  double _underTitle(Rect page, double ts) => page.top + 29 * ts;

  /// Whether the book should be open: between waves once the cheering is over, or when opened mid-battle.
  bool get _bookWanted {
    final g = state;
    if (g.over) return false;
    if (g.inTown) return _town.book; // a tap on the Town shuts it, a sign opens it (town_scene.dart)
    return g.waveActive ? _bookOpened : g.t - g.victoryAt >= victoryTime;
  }

  /// The book's size and place with nothing moving it: [ps] screen px per book px, the [room] it is fitted in, its width
  /// [bw] and height [bh], and where it stands at [rest] (before its bob and its slide in). The Town's scene keeps clear
  /// of it (town_scene.dart). [_bookLandscape] makes it shorter (decisions-log 283).
  ({double ps, Rect room, double bw, double bh, Rect rest}) _bookFit() {
    // Height / width, and the room kept free around it.
    const aspect = 0.75, marginW = 24.0, marginH = 40.0;
    (double, double) fit(Rect room) {
      final bw = math.min(room.width - marginW, (room.height - marginH) / aspect);
      return (bw, math.min(room.height - marginH, bw * aspect));
    }

    // The book's pixel scale ([ps] screen px per sprite px) keeps 300x200 px of book per step, so a bigger
    // book gets bigger pages rather than thicker covers. The room leaves the tabs (19 book px) room above
    // it, and 60 on its right (the gold and wave ribbons' until decisions-log 285, kept so the book stays put): the
    // largest scale whose room still fits it.
    // It also starts below the wave meter's band, so the meter never moves for it. It keeps inside what a phone's screen
    // keeps at its edges ([_safe], decisions-log 215). [rest]: where the book rests between bobs ([_bookLandscape]): at
    // its room's right, 8 px up from its middle.
    double pixel((double, double) b) => math.max(1, math.min(b.$1 / 300, b.$2 / 200).floor()).toDouble();
    final s = _safe;
    Rect roomAt(double ps) => Rect.fromLTRB(size.x * 0.26, _meterBottom + 6 + 20 * ps, size.x - s.right - 6 - 60 * ps, size.y - s.bottom);
    var p = 4.0;
    while (p > 1 && pixel(fit(roomAt(p))) < p) {
      p--;
    }
    final room = roomAt(p);
    final (bw, bh) = fit(room);
    return _bookLandscape(p, room, bw, bh); // decisions-log 283: shorter, over the spawn bar (spawn_bar.dart)
  }

  /// The open book's shadow on the ground (decisions-log 275; the owner, 2026-10-08: "shadow dari ui book perlu di buat
  /// ulang supaya style pixelatednya tetap di pertahankan"): a pixel-art ellipse in the book's own pixels, [ps] screen px
  /// each, like the units' shadows (`tiny_<type>_shadow.png`: one tone, stepped rows, the widest in the middle). [w] book px
  /// wide (to a whole one) and 18 screen px tall (to a whole book px, 2 at the least), its middle under [book]'s at [y]:
  /// across on the book's grid, down on whole screen px; black at 0.25 of the slide's ease [e], hard edged. Drawn rows:
  /// no sheet has a shadow this wide and flat that a whole-number scale keeps square (the units' widest is 25x5). Adds
  /// to [_bookShadowRows], which [_book] empties each frame. The field's only: a Town's scene has none (decisions-log 304).
  void _bookShadow(Canvas c, Rect book, double ps, double w, double y, double e) {
    final cols = math.max(2, w.round()), rows = math.max(2, (18 / ps).round());
    final left = book.left + ((book.width / ps - cols) / 2).round() * ps, top = (y - rows * ps / 2).roundToDouble();
    _bookShadowPaint.color = Colors.black.withValues(alpha: 0.25 * e);
    for (var j = 0; j < rows; j++) {
      final t = (j + 0.5) / rows * 2 - 1; // the row's middle: -1 the top, 1 the bottom
      final inset = ((cols - cols * math.sqrt(1 - t * t)) / 2).round(); // whole book px in from each end
      final row = Rect.fromLTRB((left + inset * ps).roundToDouble(), top + j * ps,
          (left + (cols - inset) * ps).roundToDouble(), top + (j + 1) * ps);
      _bookShadowRows.add(row);
      c.drawRect(row, _bookShadowPaint);
    }
  }

  /// The open book on its tab's pages: Pasukan (the troop rows), Tas (bag.dart) or Settings. [target]
  /// is the troop type an item dragged onto the field would go to; the Tas page lights its row.
  void _book(Canvas c, Game g, String? target) {
    final e = 1 - math.pow(1 - _bookT, 3).toDouble(); // ease out
    final (:ps, :bw, :bh, :rest, room: _) = _bookFit();
    final slide = Offset((1 - e) * size.x * 0.6, 0);
    const bobK = 6.0;
    final bob = math.sin(_clock * 1.6) * bobK;
    final book = rest.shift(Offset(0, bob) + slide);
    _bookArea = book;
    _bookHigh = rest.top - bobK + slide.dy;
    _bookBob = bob;
    _bookBobK = bobK;

    // Shadow on the ground below, smaller while the book bobs up, in the book's pixels ([_bookShadow]); on the field only:
    // none over a Town's scene (decisions-log 304, the owner: "book di town di remove backgroundnya").
    _bookShadowRows.clear();
    if (!_townShown) {
      final shadowY = math.min(rest.bottom + 26, size.y - 10) + slide.dy;
      _bookShadow(c, book, ps, bw / ps * (0.8 + bob / 120), shadowY, e);
    }
    // The book sprite (ui_book.png), 9-sliced so the covers' edges and the spine keep their pixels and
    // only the middle of each page stretches; a whole number of screen pixels per sprite pixel.
    double stretch(List<double> cuts, double size, List<bool> fixed) {
      var fixedLen = 0.0, free = 0;
      for (var i = 0; i < fixed.length; i++) {
        fixed[i] ? fixedLen += (cuts[i + 1] - cuts[i]) * ps : free++;
      }
      return (size - fixedLen) / free; // screen length of each stretching piece
    }

    // Sprite x / y → screen, piece by piece.
    List<double> place(List<double> cuts, List<bool> fixed, double start, double size) {
      final each = stretch(cuts, size, fixed);
      final out = [start];
      for (var i = 0; i < fixed.length; i++) {
        out.add(out.last + (fixed[i] ? (cuts[i + 1] - cuts[i]) * ps : each));
      }
      return out;
    }

    const xCuts = <double>[0, 31, 96, 143, 208, 240], yCuts = <double>[0, 31, 112, 144];
    const xFixed = [true, false, true, false, true], yFixed = [true, false, true];
    final xs = place(xCuts, xFixed, book.left, bw), ys = place(yCuts, yFixed, book.top, bh);
    _bookmarks(c, g, xs, ys, ps); // under the book
    final sheet = _img('ui_book.png');
    for (var i = 0; i < 5; i++) {
      for (var j = 0; j < 3; j++) {
        c.drawImageRect(sheet, Rect.fromLTRB(xCuts[i], yCuts[j], xCuts[i + 1], yCuts[j + 1]),
            Rect.fromLTRB(xs[i], ys[j], xs[i + 1] + 0.5, ys[j + 1] + 0.5), _px);
      }
    }
    _bookmarks(c, g, xs, ys, ps, front: true); // the open page's tab, over the cover's edge
    // Where the pages' writing goes: the paper inside each page's printed line (ui_book.png: the left page's line at
    // sprite x 16 and 112, the right one's at 127 and 223, both at y 10 and 127), less the book's padding ([bookPadY],
    // [bookPadX]).
    final left = bookWriting(Rect.fromLTRB(xs[0] + 17 * ps, ys[0] + 11 * ps, xs[2] + 16 * ps, ys[3] - 17 * ps), ps);
    final right = bookWriting(Rect.fromLTRB(xs[3] - 15 * ps, ys[0] + 11 * ps, xs[5] - 17 * ps, ys[3] - 17 * ps), ps);
    _pagesAt = (left, right);

    // Text and spacing follow the page's size: the width the right page's writing had before the padding (decisions-log
    // 198), so the words kept their sizes.
    final ts = ((xs[5] - xs[3] - 16 * ps) / 280).clamp(0.5, 1.5);
    final btnH = math.min(40.0, bh * 0.1);
    if (_page == _Page.store && !g.storeOpen) _open(_home); // another game came in, before its store opened
    switch (_page) {
      case _Page.smithy:
        return _smithyPages(c, g, left, right, ts, ps); // a Town's (smithy_page.dart)
      case _Page.tavern:
        return _tavernPages(c, g, left, right, ts, ps); // a Town's with the Tavern on (tavern_page.dart)
      case _Page.settings:
        return _settingsPage(c, left, right, ts, btnH);
      case _Page.licence:
        return _licencePages(c, left, right, ts, btnH); // licence_page.dart
      case _Page.guide:
        return _guidePages(c, left, right, ts, btnH); // guide_page.dart
      case _Page.bag:
        return _bagPages(c, g, left, right, ts, ps, target);
      case _Page.store:
        return _shopPages(c, g, left, right, ts, ps); // the Town's Shop on the Bag's code (bag.dart, shop_page.dart, decisions-log 230)
      case _Page.troops:
    }
    _troopsPages(c, g, left, right, ts, ps); // the Army page (troops_page.dart)
  }

  /// The bookmarks (ui_book_marks.png), in the book's pixels ([ps] screen px each; [xs], [ys]: its slices).
  /// Page tabs on the top edge over the left page: Pasukan (crossed swords), Tas (the bag) and Pengaturan (gear); in a
  /// Town the Smithy, the Tavern and the Shop (the coin stack; greyed until the Shop opens, and a tap then only says when
  /// it does) first (town_scene.dart). The open page's is the tall paper one, drawn in [front] of the book so it runs
  /// into its page;
  /// the others are the short tan one behind the cover, buttons. No gold and wave ribbons since decisions-log 285: the
  /// HUD's gold panel and wave meter show both.
  void _bookmarks(Canvas c, Game g, List<double> xs, List<double> ys, double ps, {bool front = false}) {
    final edge = ys[0] + 6 * ps; // the cover's top line (sprite row 6)
    final marks = _img('ui_book_marks.png');
    // Pasukan, Tas, Settings (the owner's order), or a Town's (town_scene.dart); the Shop tab's lock and refusal go with
    // it.
    final tabs = _bookTabs(g);
    final shown = _page == _Page.licence || _page == _Page.guide ? _Page.settings : _page; // Licenses and How to Play are Settings'
    // The shut tabs behind the cover end at its top line: where a tab stands over the spine's notch (sprite x 116-123,
    // rows 6-8; at 915x412 a Town's Bag tab, decisions-log 301) its hidden rows don't show through it.
    if (!front) {
      c
        ..save()
        ..clipRect(Rect.fromLTRB(0, 0, size.x, edge));
    }
    for (final (i, (icon, page)) in tabs.indexed) {
      final open = shown == page, x = xs[0] + bookTabLeft(i, ps), locked = page == _Page.store && !g.storeOpen;
      if (open != front) continue;
      // The open tab's last two rows cover the cover's line and the page's edge line; the shut one sinks
      // two rows behind the cover, and comes those two rows out under the mouse (button_fx.dart). A shut one takes a
      // press the tap rule's size at least, down to where the pages' writing starts ([bookTabTap], decisions-log 301).
      final src = open ? _tabPaper : _tabTan, hit = _tabAt[page] = Rect.fromLTRB(x, edge - 16 * ps, x + src.width * ps, edge);
      final tap = bookTabTap(hit, ys[0] + (11 + bookPadY) * ps);
      if (!open) _tabTapAt[page] = tap;
      final top = open ? edge + (2 - src.height) * ps : hit.top - (_look(tap) == ButtonLook.hover ? 2 * ps : 0);
      c.drawImageRect(marks, src, Rect.fromLTWH(x, top, src.width * ps, src.height * ps), _px);
      final mark = Rect.fromLTWH(x + 2 * ps, top + (open ? 2 : 1) * ps, 16 * ps, 16 * ps);
      if (page == _Page.tavern) {
        c.drawImageRect(_img('town_mug.png'), _townMarkSrc, mark, _px); // a Town's Tavern: the wave meter's mug
        if (_tavernUnseen(g)) _tabDot(c, mark, ps, 'tavernDot'); // its offers not seen yet (tavern_page.dart)
      } else {
        icon == null ? _townMark(c, mark) : _uiIcon(c, icon, mark, locked ? _lockedTab : null); // a Town's Smithy: its hammer
      }
      if (page == _Page.bag) _bagTabDot(c, g, Rect.fromLTWH(x + 2 * ps, top + (open ? 2 : 1) * ps, 16 * ps, 16 * ps), ps); // ascend_page.dart
      // The Army's dot (gold piles up for an Awaken or a Forge, ascend_page.dart): its detail buys them (decisions-log
      // 230).
      if (page == _Page.troops) _armyTabDot(c, g, Rect.fromLTWH(x + 2 * ps, top + (open ? 2 : 1) * ps, 16 * ps, 16 * ps), ps);
      if (!open) _hits.add((tap, locked ? () => showMessage(g.storeWhy(StoreRefusal.locked)) : () => _open(page)));
      if (!open && page == _Page.store) _storeTabAt = hit;
    }
    if (!front) c.restore();
  }

  /// The Settings page: the music and sound volumes on the left page, at its bottom "How to Play" (the guide's page,
  /// guide_page.dart); on the right one "Send game data" (the telemetry to the server, #64: off by default,
  /// orange while on), and at the bottom "Licenses" (licence_page.dart), "Monster spotlight", "Hero spotlight" and "Main
  /// Menu" (the welcome screen). Every change sounds at once and is saved (settings.json).
  void _settingsPage(Canvas c, Rect left, Rect right, double ts, double btnH) {
    const ink = Color(0xFF4A2C17);
    _text(c, Words.settings, Offset(left.center.dx, _titleY(left, ts)), size: 22 * ts, color: ink, anchor: Anchor.center, bold: true);
    void apply(void Function() change) {
      change();
      Sounds.volumes(_settings.music / 100, _settings.sfx / 100);
      saveSettings(_settings);
    }

    final rows = [
      ('Music', _icNote, 50.0, _settings.music, (int v) => apply(() => _settings.music = v)),
      ('Sounds', _icSpeaker, 58.0, _settings.sfx, (int v) => apply(() => _settings.sfx = v)),
    ];
    final rowH = math.min(btnH, 32 * ts + 8); // a narrow (phone) page keeps the bar long enough
    for (final (i, (label, icon, strip, value, to)) in rows.indexed) {
      final top = _underTitle(left, ts) + (23 + i * 80) * ts;
      _uiIcon(c, icon, Rect.fromLTWH(left.left, top, 24 * ts, 24 * ts));
      _text(c, label, Offset(left.left + 30 * ts, top + 12 * ts), size: 18 * ts, color: ink);
      final row = Rect.fromLTRB(left.left, top + 32 * ts, left.right, top + 32 * ts + rowH);
      _volumeAt.add(row);
      _volume(c, row, value, strip, to);
    }
    // At the left page's bottom, level with "Main Menu": the guide's page (guide_page.dart).
    final howTo = guideEn.labels.howTo;
    _button(c, _guide.button = Rect.fromLTRB(left.left, left.bottom - btnH, left.right, left.bottom), _openGuidePage, label: howTo, size: 18 * ts);
    // Above it, level with "Hero spotlight": the dev FPS readout (fps_readout.dart), on or off, orange while on.
    final fpsOn = _settings.showFps, fpsLabel = 'Show FPS: ${fpsOn ? 'On' : 'Off'}', fpsGap = 8 * ts;
    _button(c, _fpsButtonAt = Rect.fromLTRB(left.left, left.bottom - 2 * btnH - fpsGap, left.right, left.bottom - btnH - fpsGap), _fpsToggle,
        active: fpsOn, label: fpsLabel, size: math.min(16 * ts, 16 * ts * (left.width - 16 * ts) / _textWidth(fpsLabel, 16 * ts)));
    // "Send game data", level with the music's line: only the server's copy (_httpSink); the local file is written either
    // way.
    final send = Rect.fromLTWH(right.left, _underTitle(right, ts) + 23 * ts, right.width, btnH);
    double fit(String s, double size) => math.min(size, size * (send.width - 16 * ts) / _textWidth(s, size));
    const sendLabel = 'Send game data';
    _sendAt = send;
    _button(c, send, () => apply(() => _httpSink.enabled = _settings.sendTelemetry = !_settings.sendTelemetry),
        active: _settings.sendTelemetry, label: sendLabel, size: fit(sendLabel, 18 * ts));
    final note = _settings.sendTelemetry ? 'On: anonymous data' : 'Off', noteSize = fit(note, 14 * ts);
    final noteAt = Offset(send.center.dx, send.bottom + 14 * ts);
    _text(c, note, noteAt, size: noteSize, color: ink, anchor: Anchor.center);
    _sendNoteAt = Rect.fromCenter(center: noteAt, width: _textWidth(note, noteSize), height: noteSize * 1.3);
    final menu = Rect.fromLTRB(right.left, right.bottom - btnH, right.right, right.bottom);
    // A Hero's cast cut-in (hero_cast.dart), on or off; off drops any showing or waiting.
    final cutIns = _settings.heroCutIns, gap = 8 * ts, heroLabel = 'Hero spotlight: ${cutIns ? 'On' : 'Off'}';
    _button(c, _heroCutAt = Rect.fromLTRB(menu.left, menu.top - gap - btnH, menu.right, menu.top - gap), () {
      apply(() => _settings.heroCutIns = !cutIns);
      if (cutIns) _cutIns.clear();
    }, active: cutIns, label: heroLabel, size: fit(heroLabel, 16 * ts));
    // Above it a monster champion's skill banner (foe_cut_in.dart), the same way.
    final foeCuts = _settings.foeCutIns, foeLabel = 'Monster spotlight: ${foeCuts ? 'On' : 'Off'}';
    _button(c, _foeLook.button = Rect.fromLTRB(menu.left, menu.top - 2 * (gap + btnH), menu.right, menu.top - 2 * gap - btnH), () {
      apply(() => _settings.foeCutIns = !foeCuts);
      if (foeCuts) _foeCuts.clear();
    }, active: foeCuts, label: foeLabel, size: fit(foeLabel, 16 * ts));
    // Above that "Licenses": the game's licence, the credits and the package licences (licence_page.dart).
    _button(c, _lic.button = Rect.fromLTRB(menu.left, menu.top - 3 * (gap + btnH), menu.right, menu.top - 3 * gap - 2 * btnH), _openLicences,
        label: 'Licenses', size: 18 * ts);
    _menuAt = menu;
    _button(c, menu, () {
      _open(_home); // back from the welcome screen on the troops (in a Town on the Smithy)
      _menuPause(); // pause.dart: mid-wave, "Continue" comes back to the game paused
      showWelcome();
    }, label: 'Main Menu', size: 18 * ts);
  }

  /// A volume in [row]: - and + at its ends, between them the pack's bar (ui_bars.png's empty capsule,
  /// 9-sliced, with the fill strip at y [strip] cut to [value]%) in ten notches; tapping notch n sets n·10%.
  void _volume(Canvas c, Rect row, int value, double strip, void Function(int) to) {
    final b = row.height, k = (b * 0.5 / 6).floorToDouble().clamp(1.0, 4.0), gap = b * 0.2;
    _button(c, Rect.fromLTWH(row.left, row.top, b, b), () => to(Settings.nudge(value, -1)), label: '-', size: b * 0.6, enabled: value > 0);
    _button(c, Rect.fromLTWH(row.right - b, row.top, b, b), () => to(Settings.nudge(value, 1)), label: '+', size: b * 0.6, enabled: value < 100);
    final bar = Rect.fromLTRB(row.left + b + gap, row.center.dy - 3 * k, row.right - b - gap, row.center.dy + 3 * k);
    _nine(c, const Rect.fromLTWH(82, 33, 12, 6), bar, k, l: 1, t: 1, r: 1, b: 1, sheet: 'ui_bars.png');
    final inner = bar.deflate(k);
    c.drawImageRect(_img('ui_bars.png'), Rect.fromLTWH(83, strip, 10, 4), Rect.fromLTWH(inner.left, inner.top, inner.width * value / 100, inner.height), _px);
    const n = 100 ~/ Settings.step;
    for (var i = 0; i < n; i++) {
      final at = inner.left + inner.width * i / n;
      if (i > 0) c.drawRect(Rect.fromLTWH(at - k / 2, inner.top, k, inner.height), Paint()..color = const Color(0x55000000)); // notch line
      _hits.add((Rect.fromLTWH(at, row.top, inner.width / n, row.height), () => to((i + 1) * Settings.step)));
    }
  }

  /// A card or slot on a page: one of the rounded page frames of ui_all.png, 9-sliced; [paint] recolours it (a chest
  /// card's rarity, chest_popup.dart).
  void _card(Canvas c, Rect r, Rect frame, [Paint? paint]) =>
      _nine(c, frame, r, math.max(1.0, (r.shortestSide / 24).floorToDouble()), paint: paint);
}
