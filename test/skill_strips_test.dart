// The skill strips (decisions-log 299, lib/skill_strips.dart): which of the Tiny RPG pack's attack 2 / attack 3 strips
// each skill plays, its files, how its frames run up to the blow and after it, who starts one (a troop's #10 skill, a
// Hero's, a monster's wind-up, the blow on its land) and that the board draws every one, the Hero cut-in's too.
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flame/game.dart' hide Game;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';
import 'package:tower_defense/main.dart';

import 'hero_skill_helpers.dart';

/// A PNG's (width, height), from its IHDR.
(int, int) pngSize(String path) {
  final b = ByteData.sublistView(File(path).readAsBytesSync());
  return (b.getUint32(16), b.getUint32(20));
}

/// The frames of `tiny_<type>_<anim>.png` (the necro healer's: the boss's, recoloured in memory).
int framesOf(String type, String anim) {
  final (w, h) = pngSize('assets/images/tiny_${type == necroHealer ? boss : type}_$anim.png');
  return w ~/ h;
}

/// A sturdy monster of [type] at [at] that never moves or fights on its own.
Unit sturdy(Game g, String type, Point<double> at, [Tier tier = Tier.normal]) => foeAt(g, type, at, tier)..hp = 1e5;

void main() {
  test('each troop type\'s #10 skill and its Hero skills play the strips decisions-log 299 picked; Earthquake and Snipe '
      'their own', () {
    String row(SkillStrip? s) => s == null ? '-' : '${s.anim} ${s.entry}>${s.strike}';
    expect({for (final k in troopTypes.keys) k: (row(troopSkillStrips[k]), row(heroSkillStrips[k]))}, {
      'soldier': ('attack2 0>3', 'attack2 0>3'), // Hold Fast; its attack 3 is a bow shot
      'knight': ('attack2 0>3', 'attack3 4>7'), // Circle Slash
      'swordsman': ('attack3 2>5', 'attack2 0>3'), // Rampage
      'archer': ('attack2 6>9', 'attack2 6>9'), // Arrow Rain
      'lancer': ('attack2 0>2', 'attack3 1>4'), // Piercing Thrust
      'priest': ('attack2 1>4', 'attack2 1>4'), // Healing Prayer: the pack's Attack
      'armored_axeman': ('attack3 4>7', 'attack2 1>4'), // Crushing Blow
      'wizard': ('attack2 1>4', 'attack2 1>4'), // Arcane Blast
      'knight_templar': ('attack2 2>5', 'attack3 4>7'), // Holy Shield
    });
    for (final s in HeroSkill.values) {
      final own = switch (s) {
        HeroSkill.quake => 'attack3 4>7',
        HeroSkill.snipe => 'attack2 4>9',
        _ => row(heroSkillStrips[s.type]),
      };
      expect(row(heroSkillStrip(s)), own, reason: s.name);
    }
  });

  test('every monster skill that is cast plays a strip of its type, the skeleton archer its own attack strip; the passive '
      'ones, Shield Up and Mass Mend none', () {
    final none = {
      MonsterSkill.reassemble, MonsterSkill.split, MonsterSkill.frenzy, MonsterSkill.thickHide, // passive
      MonsterSkill.shieldUp, // a guard: the armored skeleton has no strip for it
      MonsterSkill.massMend, // the healing necromancer's own cast strip, as before
    };
    for (final s in MonsterSkill.values) {
      expect(monsterSkillStrips.containsKey(s), !none.contains(s), reason: s.title);
    }
    for (final s in [MonsterSkill.volley, MonsterSkill.barbedArrow, MonsterSkill.boneRain]) {
      expect(monsterSkillStrips[s]!.anim, 'attack', reason: s.title);
    }
    expect(monsterSkillStrips[MonsterSkill.boneShield]!.anim, 'block');
    expect(monsterSkillStrips[MonsterSkill.skullCrusher]!.anim, 'attack3');
    expect(monsterSkillStrips[MonsterSkill.pounce]!.strike, 7);
  });

  test('every strip is a file of whole 100 px frames (the necro healer\'s the boss\'s), its entry and blow inside it', () {
    final all = [
      for (final MapEntry(:key, :value) in troopSkillStrips.entries) (key, value),
      for (final MapEntry(:key, :value) in heroSkillStrips.entries) (key, value),
      for (final s in [HeroSkill.quake, HeroSkill.snipe]) (s.type, heroSkillStrip(s)!),
      for (final MapEntry(:key, :value) in monsterSkillStrips.entries) (key.type, value),
    ];
    for (final (type, s) in all) {
      final (w, h) = pngSize('assets/images/tiny_${type == necroHealer ? boss : type}_${s.anim}.png');
      expect((h, w % h), (100, 0), reason: '$type ${s.anim}');
      expect(s.entry <= s.strike && s.strike < w ~/ h, isTrue, reason: '$type ${s.anim} ${s.entry}>${s.strike} of ${w ~/ h}');
    }
    // The files the board loads: every (type, anim) above but the existing attack strips and the made necro healer's.
    expect(skillStripFiles().where((f) => f.$1 != necroHealer).length, 31);
  });

  test('a strip\'s frames run at 10 fps from its entry to its blow at strikeAt, then play out; a longer wind-up holds '
      'an earlier frame, a shorter one starts later', () {
    const knight = SkillStrip('attack3', 4, 7); // 11 frames
    final cast = (strip: knight, from: 10.0, strikeAt: 10.3);
    expect([for (final dt in [-0.01, 0.0, 0.1, 0.2, 0.3, 0.45, 0.6, 0.7]) skillStripFrame(cast, 11, 10 + dt)], [null, 4, 5, 6, 7, 8, 10, null]);
    // A monster's 0.8 s wind-up for a blow on frame 4: frame 0 held 0.4 s, then 0..4, the blow on the land.
    final wind = (strip: const SkillStrip('attack2', 0, 4), from: 0.0, strikeAt: 0.8);
    expect([for (final t in [0.0, 0.3, 0.4, 0.55, 0.79, 0.8, 1.05]) skillStripFrame(wind, 13, t)], [0, 0, 0, 1, 3, 4, 6]);
    // A 0.4 s wind-up for a blow on frame 7: it starts on frame 3.
    final short = (strip: const SkillStrip('attack2', 0, 7), from: 0.0, strikeAt: 0.4);
    expect([for (final t in [0.0, 0.2, 0.4]) skillStripFrame(short, 13, t)], [3, 5, 7]);
  });

  test('a troop\'s #10 cast and a Hero\'s start their strips (Snipe\'s blow on its aim\'s end); a monster\'s starts with '
      'its wind-up, its blow on the land, and a cancelled wind-up stops it', () {
    // The knight's Circle Slash: three foes within its reach.
    final g = bareGame(Random(1))
      ..heroSkills = false
      ..monsterSkills = false;
    final k = placeNow(g, 'knight', 2, 3);
    g
      ..startWave()
      ..queue.clear();
    k
      ..cd = hold
      ..mp = k.stats.mp.toDouble();
    for (final d in const [Point(12.0, -6.0), Point(12.0, 7.0), Point(-12.0, 3.0)]) {
      sturdy(g, 'orc', k.pos + d);
    }
    for (var i = 0; i < 10 && k.skillAnim == null; i++) {
      g.tick(0.05);
    }
    expect(k.skillAnim?.strip, troopSkillStrips['knight']);
    expect(k.skillAnim!.from, k.skillAt);
    expect(k.skillAnim!.strikeAt, closeTo(k.skillAt + 0.3, 1e-9));

    // A Hero's Cleave (a sturdy foe in reach) and Snipe.
    for (final (skill, lead) in [(HeroSkill.cleave, 0.3), (HeroSkill.snipe, snipeK.aim)]) {
      final (g, h) = heroCaster(skill, Random(2));
      g.monsterSkills = false;
      sturdy(g, 'orc', h.pos + Point(skill == HeroSkill.snipe ? 120.0 : 12.0, 0.0), Tier.elite);
      for (var i = 0; i < 40 && h.skillAnim == null; i++) {
        g.tick(0.05);
      }
      expect(h.skillAnim?.strip, heroSkillStrip(skill), reason: skill.name);
      expect(h.skillAnim!.strikeAt - h.skillAnim!.from, closeTo(lead, 1e-9), reason: skill.name);
    }

    // An elite orc's Brutal Swing (two troops in its range): the strip from the wind-up, the blow on the land.
    final m = bareGame(Random(3))
      ..skills = false
      ..heroSkills = false;
    m
      ..startWave()
      ..queue.clear();
    final orc = m.monster('elite_orc', Tier.highElite, const Point(250.0, 60.0))
      ..entered = true
      ..cd = hold;
    m.units.add(orc);
    for (final d in const [Point(-10.0, 0.0), Point(-8.0, 6.0)]) {
      m.units.add(Unit(Side.troop, 'soldier', troopTypes['soldier']!, orc.pos + d)
        ..entered = true
        ..busyUntil = hold
        ..hp = 1e5);
    }
    for (var i = 0; i < 200 && orc.winding == null; i++) {
      m.tick(0.05);
    }
    expect(orc.winding, MonsterSkill.brutalSwing);
    expect(orc.skillAnim?.strip, monsterSkillStrips[MonsterSkill.brutalSwing]);
    expect((orc.skillAnim!.from, orc.skillAnim!.strikeAt), (orc.castAt, orc.windUntil));
    // A stun mid-wind-up cancels it, and the strip with it.
    orc.stunUntil = m.t + 1;
    m.tick(0.05);
    expect((orc.winding, orc.skillAnim), (null, null));
  });

  group('the troops\' wind-ups (Game.skillWinds, the board\'s): ', () {
    /// A knight with full MP that never strikes on its own, three sturdy foes within Circle Slash's reach, the wind-ups on
    /// (only the #10 skills), ticked until it casts.
    (Game, Unit, List<Unit>) knightCasting() {
      final g = bareGame(Random(1))
        ..heroSkills = false
        ..monsterSkills = false
        ..skillWinds = true;
      final k = placeNow(g, 'knight', 2, 3);
      g
        ..startWave()
        ..queue.clear();
      k
        ..cd = hold
        ..mp = k.stats.mp.toDouble();
      final foes = [for (final d in const [Point(12.0, -6.0), Point(12.0, 7.0), Point(-12.0, 3.0)]) sturdy(g, 'orc', k.pos + d)];
      for (var i = 0; i < 10 && k.troopWind == null; i++) {
        g.tick(0.05);
      }
      expect(k.troopWind, isNotNull, reason: 'it began Circle Slash');
      return (g, k, foes);
    }

    test('a #10 skill pays as it begins and lands on its strip\'s blow, 0.3 s on; the troop stands and doesn\'t attack '
        'meanwhile', () {
      expect((Game().skillWinds, Game().boardRules().skillWinds), (false, true));
      final (g, k, foes) = knightCasting();
      final from = k.skillAt, mp = k.mp, at = k.pos;
      expect(mp, k.stats.mp - g.skillCost(k, troopSkills['knight']!.cost));
      expect(k.troopWind!.until, closeTo(from + 0.3, 1e-9));
      expect(k.skillAnim!.strikeAt, k.troopWind!.until);
      k.cd = 0; // it would strike now, but it is winding up
      runFor(g, 0.2);
      expect([for (final o in foes) o.hp], everyElement(1e5), reason: 'nothing landed yet');
      expect((k.attackedAt < from, k.pos, k.moving), (true, at, false));
      runFor(g, 0.15);
      expect(k.troopWind, isNull);
      expect([for (final o in foes) o.hp < 1e5], everyElement(isTrue), reason: 'the slash landed on its blow');
    });

    test('a stun cancels it: nothing lands, nothing is refunded, its strip stops', () {
      final (g, k, foes) = knightCasting();
      final mp = k.mp;
      k.stunUntil = g.t + 1;
      g.tick(0.05);
      expect((k.troopWind, k.skillAnim), (null, null));
      runFor(g, 0.5);
      expect([for (final o in foes) o.hp], everyElement(1e5));
      expect(k.mp, greaterThanOrEqualTo(mp)); // only its regen since
      expect(k.skillAt, lessThan(g.t - 0.5)); // its cooldown runs from the cast
    });

    test('with no foe left in reach on its blow it fizzles: nothing lands and its strip stops', () {
      final (g, k, foes) = knightCasting();
      for (final o in foes) {
        o.pos = const Point(900.0, 60.0);
      }
      runFor(g, 0.35);
      expect((k.troopWind, k.skillAnim), (null, null));
      expect([for (final o in foes) o.hp], everyElement(1e5));
    });

    test('a Hero\'s Cleave winds up too; Snipe (its own aim) and a move land at the cast', () {
      for (final (skill, winds) in [(HeroSkill.cleave, true), (HeroSkill.snipe, false), (HeroSkill.shieldBash, false)]) {
        final (g, h) = heroCaster(skill, Random(2));
        g
          ..monsterSkills = false
          ..skillWinds = true;
        final foe = sturdy(g, 'orc', h.pos + Point(skill == HeroSkill.snipe ? 120.0 : 12.0, 0.0), Tier.elite);
        for (var i = 0; i < 40 && h.skillAnim == null; i++) {
          g.tick(0.05);
        }
        expect(h.skillAnim, isNotNull, reason: skill.name);
        expect(h.troopWind != null, winds, reason: skill.name);
        expect(instantHeroSkills.contains(skill), !winds);
        if (winds) {
          expect(foe.hp, 1e5, reason: 'Cleave before its blow');
          runFor(g, 0.35);
          expect(foe.hp, lessThan(1e5), reason: 'Cleave on its blow');
        }
      }
    });
  });

  testWidgets('the board draws every skill strip, before its blow and after it, at every troop and monster that plays '
      'one, and a Hero cut-in\'s portrait playing its strip', (tester) async {
    tester.view
      ..physicalSize = const Size(1266, 713)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final game = TdGame();
    await tester.pumpWidget(GameWidget(game: game));
    for (var i = 0; i < 3000 && !game.isLoaded; i++) {
      await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 20)));
      await tester.pump();
    }
    expect(game.isLoaded, isTrue);
    final b = game.board..welcome = null;
    final g = bareGame(Random(1))
      ..skills = false
      ..heroSkills = false
      ..monsterSkills = false;
    g
      ..startWave()
      ..queue.clear();
    final strips = [
      for (final MapEntry(:key, :value) in troopSkillStrips.entries) (key, Side.troop, value),
      for (final MapEntry(:key, :value) in heroSkillStrips.entries) (key, Side.troop, value),
      for (final s in [HeroSkill.quake, HeroSkill.snipe]) (s.type, Side.troop, heroSkillStrip(s)!),
      for (final MapEntry(:key, :value) in monsterSkillStrips.entries) (key.type, Side.enemy, value),
    ];
    final units = <(Unit, SkillStrip)>[];
    for (final (i, (type, side, strip)) in strips.indexed) {
      final at = Point(60.0 + (i % 12) * 26, 30.0 + (i ~/ 12) * 22);
      final u = side == Side.troop
          ? (Unit(Side.troop, type, troopTypes[type]!, at)
            ..entered = true
            ..busyUntil = double.negativeInfinity
            ..cd = hold)
          : g.monster(type, Tier.highElite, at)
        ..entered = true
        ..cd = hold
        ..summonCd = hold;
      g.units.add(u);
      units.add((u, strip));
    }
    b.state = g;
    for (final from in [g.t, g.t - 0.25, g.t - 0.6]) {
      // Just begun, between its entry and its blow, and after the blow.
      for (final (u, strip) in units) {
        u.skillAnim = (strip: strip, from: from, strikeAt: from + 0.3);
      }
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(tester.takeException(), isNull, reason: 'from ${g.t - from} s ago');
    }
    // A Hero's cast: its cut-in's portrait plays its strip once, then idles.
    final hero = units.firstWhere((e) => e.$1.side == Side.troop).$1
      ..hero = true
      ..heroSkill = HeroSkill.warCry;
    g.heroCasts.add((hero, HeroSkill.warCry));
    for (var i = 0; i < 70; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(tester.takeException(), isNull);
  });
}
