part of 'main.dart';

// The wizard's magic (decisions-log 313; docs/units-and-combat.md "The wizard's magic"). The owner: "particle yang di
// keluarkan sama mage perlu pakai dari dari sheet [Wizard_Attack02_Effect.png] [Wizard_Attack01_Effect.png] kalau mau
// di rubah tinggal di filter saja warnanya". Its shots are the Tiny RPG pack's own magic sheets
// (tool/import_tiny_skills.py), 100x100 frames facing right at the pack's 100 ms a frame, drawn at 1 world unit a
// sprite px like the characters: the plain shot the fireball, Arcane Blast the ice star. Where it lands the shot's
// burst ([shotHitFx]: `fireball`, `shards`) plays the sheet's hit frames. An awakened wizard's are tinted its level's
// colour ([_awakeFx]), as every troop's shots and bursts are; otherwise they keep the sheets' own colours. A Hero
// wizard's are the same. Arcane Blast's cast strip has its staff's glow in the star's blues ([_staffBlue]).

/// One of the wizard's magic sheets: its file; the point of a frame drawn on the shot's or its burst's place (frame px:
/// the fireball's ball; 8 px under the star's middle), so neither reaches further under the shot than the old orb did,
/// 8, and the step under the field stays clear of them (spawn_bar.dart's [stepLip]); the frames its shot shows once as it
/// sets off ([lead]), then over and over while it flies ([loop]); and those its burst plays where it lands ([hit]).
enum WizardMagic {
  /// tiny_fx_wizard_fireball.png (the pack's Wizard_Attack02_Effect): frames 0-3 the ball with its tail, flying right;
  /// 4-6 its impact, a dark ball, a burst, a fading puff. The plain shot.
  fireball('tiny_fx_wizard_fireball.png', Offset(55, 51), [], [0, 1, 2, 3], [4, 5, 6]),

  /// tiny_fx_wizard_shards.png (the pack's Wizard_Attack01_Effect): frames 0-1 ice shards gathering, 2-5 the spinning
  /// star, 6 its white flash, 7-9 a streak. Arcane Blast: the star flies, then flashes and streaks where it lands. The
  /// gathering shards are left out: 60x73 px at the pack's size, they covered the wizard and the units round it, and from
  /// the lowest lane they reached under the step.
  shards('tiny_fx_wizard_shards.png', Offset(53, 58), [], [2, 3, 4, 5], [6, 7, 8, 9]);

  const WizardMagic(this.sheet, this.anchor, this.lead, this.loop, this.hit);

  final String sheet;
  final Offset anchor;
  final List<int> lead, loop, hit;

  /// The frame its shot shows [age] s after it set off.
  int flightFrame(double age) {
    final f = math.max(0, (age * magicFps).floor());
    return f < lead.length ? lead[f] : loop[(f - lead.length) % loop.length];
  }

  /// The frame its burst shows [age] s after the shot landed; past the last, the last.
  int hitFrame(double age) => hit[math.min(hit.length - 1, math.max(0, (age * magicFps).floor()))];

  /// How long its burst plays (s).
  double get hitTime => hit.length / magicFps;

  /// The sheet of a burst named [fx] (without its awakening level: [_awakeOf]), or null for any other burst.
  static WizardMagic? ofBurst(String fx) => _byName[fx];
  static final _byName = WizardMagic.values.asNameMap();
}

/// The pack's frame rate for its magic: 100 ms a frame (its .aseprite's), in flight and where it lands.
const magicFps = 10.0;

/// When the field first drew each shot in flight (game clock): its age picks its frame ([WizardMagic.flightFrame]).
final _shotSeen = Expando<double>();

/// The wizard's attack 2 strip (Arcane Blast's cast; its awakening skill's and a Hero wizard's skills' too) with its
/// staff's glow in the star's blues: the pack drew that glow orange for its fireball, which here is the plain shot's
/// (decisions-log 313). Its two oranges and their highlight appear nowhere else in the wizard's strips, so only the
/// glow changes. Built once at load ([_recoloured]).
const _staffBlue = {0xFFC9512E: 0xFF086EC7, 0xFFEF6E10: 0xFF43B4DF, 0xFFDB955A: 0xFF7DDDE1};
Color _arcaneStaff(Color c) => switch (_staffBlue[c.toARGB32()]) { final b? => Color(b), null => c };

extension on Board {
  /// A wizard's shot [sh] in flight at [at] (its drawn place, [_shotFrom]): the fireball, or Arcane Blast's star
  /// ([Shot.big]), facing the way it flies, in its awakening [level]'s tint. Mirrored, never turned: a turned sprite's
  /// pixels tilt off the art's grid, and the fireball's tail, turned up a steep shot, swung 17 under the shot (behind the
  /// step from the lowest lane); mirrored it keeps the pack's pixels and the old orb's 8.
  void _magicShot(Canvas c, Game g, Shot sh, Offset at, int level) {
    final magic = sh.big ? WizardMagic.shards : WizardMagic.fireball;
    final f = magic.flightFrame(g.t - (_shotSeen[sh] ??= g.t));
    _magicFrame(c, magic, f, at, _awakeFx(level), flip: sh.aim.x < sh.pos.x);
  }

  /// Frame [f] of [magic]'s sheet with its [WizardMagic.anchor] on [at], mirrored with [flip].
  void _magicFrame(Canvas c, WizardMagic magic, int f, Offset at, Paint paint, {bool flip = false}) {
    _frame(c, magic.sheet, f, at, anchor: magic.anchor, flip: flip, paint: paint);
    _magicDrawn.add((magic, f, paint == _px ? 0 : _awakeFxPaints.indexOf(paint) + 1));
  }
}
