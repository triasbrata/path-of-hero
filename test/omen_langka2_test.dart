// Shadow batch L-2B (decisions-log 206, lib/omen.dart; catalog-bayangan-v2 §3.1; docs/units-and-combat.md "Bayangan on
// the field", docs/loot-items-relics.md "Bayangan"): the next ten Langka kinds. Their rows (the Langka pool alone, in the
// pool's order among L-1B's; numbers, icons, the troop-side flag, needs), the cap at E8 and the HUD number equal to it,
// and with omens on one test a kind: Shieldbreak breaks a troop's shields sooner; Lingering stretches the monsters' buffs;
// Avenge and Eager give omen mights; Feed heals a monster of its blow; Healer Hunt and Straggler raise a monster's blow
// inside the dealt cap; Spell Tax raises every MP price a troop pays or is shown; Off Beat makes a Rare or Epic
// every-few-hits Fx wait longer, never Twin Fury's fury beat; Fade shrinks a troop's shields. With omens off none of it
// acts.
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';

import 'hero_skill_helpers.dart';

const shieldbreak = OmenKind.shieldbreak, lingering = OmenKind.lingering, avenge = OmenKind.avenge, feed = OmenKind.feed;
const eager = OmenKind.eager, healerHunt = OmenKind.healerHunt, spellTax = OmenKind.spellTax, offBeat = OmenKind.offBeat;
const fade = OmenKind.fade, straggler = OmenKind.straggler;

/// The batch, in the Langka pool's order.
const batch = [shieldbreak, lingering, avenge, feed, eager, healerHunt, spellTax, offBeat, fade, straggler];

/// Today's seven, whole in the Legenda pool until its cut-over (Langka's kept three: batch L-3; Epik's two: batch E-3).
const seven = [OmenKind.armor, OmenKind.haste, OmenKind.mend, OmenKind.thorns, OmenKind.wound, OmenKind.shield, OmenKind.guard];

/// [n] levels of [kind].
List<OmenKind> levels(OmenKind kind, int n) => List.filled(n, kind);

/// [kind] at its most levels: at the Beban factor 2 that is E8, past every kind's max.
List<OmenKind> top(OmenKind kind) => levels(kind, omenCap);

/// A [bareGame] with no skills of any kind (nor the monsters'), the enemy holding [omens] at the Beban [factor].
Game plain({List<OmenKind> omens = const [], double factor = 1}) => bareGame(Random(2))
  ..slots = Random(3)
  ..loot = Random(9)
  ..skills = false
  ..heroSkills = false
  ..awakenSkills = false
  ..monsterSkills = false
  ..omens.addAll(omens)
  ..omenFactor = factor;

/// What a blow took off [u]: [by] strikes it once now.
double blowOn(Game g, Unit u, Unit by) {
  final hp = u.hp;
  by
    ..busyUntil = double.negativeInfinity
    ..cd = 0;
  u.busyUntil = hold;
  g.tick(0.05);
  by.busyUntil = hold;
  return hp - u.hp;
}

/// A [troop] and a monster of [tier] beside it, both standing; the enemy holding [omens] at [factor].
(Game, Unit, Unit) duel({List<OmenKind> omens = const [], double factor = 1, String troop = 'knight', Tier tier = Tier.normal}) {
  final g = plain(omens: omens, factor: factor);
  final k = placeNow(g, troop, 2, 3)..busyUntil = hold;
  final o = foeAt(g, 'orc', k.pos + const Point(12, 0), tier);
  return (g, k, o);
}

/// The monster's blow on the troop of a fresh [duel], both [set] up so.
double foeBlow(
    {List<OmenKind> omens = const [],
    double factor = 1,
    String troop = 'knight',
    Tier tier = Tier.normal,
    void Function(Game, Unit k, Unit o)? set}) {
  final (g, k, o) = duel(omens: omens, factor: factor, troop: troop, tier: tier);
  set?.call(g, k, o);
  return blowOn(g, k, o);
}

/// A PNG's width and height, from its header.
(int, int) pngSize(File f) {
  final b = f.readAsBytesSync();
  int at(int i) => (b[i] << 24) | (b[i + 1] << 16) | (b[i + 2] << 8) | b[i + 3];
  return (at(16), at(20));
}

void main() {
  tearDown(() => omensOn = false);

  group('the rows', () {
    test("the ten sit in the Langka pool alone, in the pool's order among L-1B's after today's three that stay; their "
        "numbers, titles, troop-side flag, needs and icons (an existing sheet's cell, each unique)", () {
      // Today's three that stay in it since the Langka cut-over (batch L-3), then the batches' kinds.
      const pool = [
        OmenKind.haste, OmenKind.thorns, OmenKind.wound, OmenKind.brace, OmenKind.stubborn, OmenKind.sunder, shieldbreak, //
        OmenKind.unshaken, OmenKind.quickSpells, OmenKind.thrift, lingering, avenge, feed, OmenKind.bearHide, eager, healerHunt,
        OmenKind.hardShell, spellTax, offBeat, OmenKind.deflect, fade, OmenKind.defiant, straggler,
      ];
      // Their order among the Langka pool's (later batches' kinds go in between: omen_cutover_test.dart pins it whole).
      expect(omenPool(Rarity.langka).where(pool.contains), pool);
      expect(omenPool(Rarity.epik).take(2), [OmenKind.armor, OmenKind.mend], reason: 'the Epik cut-over (omen_epik_cutover_test.dart)');
      expect(omenPool(Rarity.legenda).take(2), [OmenKind.shield, OmenKind.guard],
          reason: "Barrier and Escort first since the Legenda cut-over (omen_legenda_cutover_test.dart); G-1B's kinds follow");
      expect(omenOrder, OmenKind.values);
      for (final k in batch) {
        expect(k.tiers, {Rarity.langka}, reason: '$k');
        expect(k.live, isTrue, reason: '$k');
      }
      expect({for (final k in batch) k: k.k}, {
        shieldbreak: (perE: 0.12, max: 0.6),
        lingering: (perE: 0.1, max: 0.5),
        avenge: (perE: 0.04, max: 0.2),
        feed: (perE: 0.02, max: 0.15),
        eager: (perE: 0.05, max: 0.3),
        healerHunt: (perE: 0.04, max: 0.25),
        spellTax: (perE: 0.05, max: 0.3),
        offBeat: (perE: 0.0, max: 0.0),
        fade: (perE: 0.02, max: 0.08),
        straggler: (perE: 0.06, max: 0.3),
      });
      expect([for (final k in batch) k.title],
          ['Shieldbreak', 'Lingering', 'Avenge', 'Feed', 'Eager', 'Healer Hunt', 'Spell Tax', 'Off Beat', 'Fade', 'Straggler']);
      expect([omenAvengeTime, omenAvengeReach, omenEagerTime, omenStragglerTiles], [3, tile, 5, 2]);
      expect(offBeat.byL, [1, 1, 2, 2]);
      expect([for (final k in batch) if (k.troopSide) k], [spellTax, offBeat, fade]);
      expect({for (final k in batch) if (k.needs.isNotEmpty) k: k.needs}, {
        shieldbreak: {OmenNeed.troopShield},
        healerHunt: {OmenNeed.healer},
        spellTax: {OmenNeed.mpSkill},
        offBeat: {OmenNeed.everyFx},
        fade: {OmenNeed.troopShield},
      });
      for (final k in batch) {
        for (final n in k.needs) {
          expect(n.built, isTrue, reason: '$k needs $n');
        }
      }
      expect({for (final k in batch) k: (k.icon!.sheet, k.icon!.x, k.icon!.y, k.icon!.size, k.icon!.tint)}, {
        shieldbreak: ('fx_hit_elite_orc.png', 128, 0, 64, null),
        lingering: ('fx_hit_wizard.png', 144, 0, 48, null),
        avenge: ('fx_hit_armored_skeleton.png', 48, 0, 48, tintRed),
        feed: ('relic_fang.png', 0, 0, 32, tintRed),
        eager: ('fx_hit_knight.png', 96, 0, 48, tintRed),
        healerHunt: ('item_staff.png', 0, 0, 32, tintRed),
        spellTax: ('ui_icons.png', 176, 0, 16, null),
        offBeat: ('relic_warDrum.png', 0, 0, 32, tintViolet),
        fade: ('ui_icons.png', 208, 0, 16, tintViolet),
        straggler: ('relic_fury.png', 0, 0, 32, tintOrange),
      });
      final seen = <(String, int, int, int?)>{};
      for (final k in OmenKind.values) {
        final icon = k.icon;
        if (icon == null) continue;
        final f = File('assets/images/${icon.sheet}');
        expect(f.existsSync(), isTrue, reason: '$k');
        final (w, h) = pngSize(f);
        expect(icon.x + icon.size <= w && icon.y + icon.size <= h, isTrue, reason: '$k: inside its sheet');
        expect(seen.add((icon.sheet, icon.x, icon.y, icon.tint)), isTrue, reason: '$k: its own (sheet, cell, tint)');
      }
    });

    test('needs: Shieldbreak and Fade act on an army with a troop shield source, Healer Hunt with a healer, Spell Tax '
        'with an MP skill, Off Beat with a Rare or Epic every-few-hits Fx (not Twin Fury\'s); the other five always', () {
      final g = bareGame(Random(1))..heroSkills = true;
      final always = {lingering, avenge, feed, eager, straggler};
      for (final kind in batch) {
        expect(omenCanAct(kind, g.omenMet), always.contains(kind), reason: 'no army: $kind');
      }
      final k = placeNow(g, 'knight', 2, 3);
      expect(omenCanAct(spellTax, g.omenMet), isTrue, reason: 'Circle Slash costs MP');
      for (final kind in [shieldbreak, fade, healerHunt, offBeat]) {
        expect(omenCanAct(kind, g.omenMet), isFalse, reason: '$kind');
      }
      g.givePusaka(Relic.twinFury, type: 'knight');
      expect(omenCanAct(offBeat, g.omenMet), isFalse, reason: "Twin Fury's beat is the fury's");
      g.givePusaka(Relic.warDrum, type: 'knight');
      expect(omenCanAct(offBeat, g.omenMet), isTrue, reason: "War Drum's every 3rd");
      final p = placeNow(g, 'priest', 1, 3);
      expect(omenCanAct(healerHunt, g.omenMet), isTrue);
      expect(omenCanAct(shieldbreak, g.omenMet), isFalse);
      p
        ..hero = true
        ..heroSkill = HeroSkill.lightVeil;
      expect(omenCanAct(shieldbreak, g.omenMet), isTrue, reason: 'Veil of Light: a troop absorb');
      expect(omenCanAct(fade, g.omenMet), isTrue);
      expect(k.alive, isTrue);
    });
  });

  group('the HUD numbers', () {
    setUp(() => omensOn = true);

    test('at E8 each shows its capped share (its max), the one its hooks read; Off Beat counts by L, not the factor; '
        'every line short and in English', () {
      final g = plain(omens: [for (final k in batch) ...top(k)], factor: 2);
      foeAt(g, 'orc', const Point(300, 60)); // a wave on: the HUD shows its frozen factor
      expect(g.omenShownFactor, 2);
      for (final k in batch.where((k) => k != offBeat)) {
        final v = omenShown(k, omenCap, 8);
        expect(v.x, min(k.k.max, k.k.perE * 8), reason: '$k');
        expect(v.x, k.k.max, reason: '$k: E8 is past its max');
        expect(g.omenK(k), v.x, reason: '$k: the hooks read the same');
        expect(g.omenShownK(k), v.x, reason: '$k');
        expect(g.omenEffect(k), contains('${omenPercent(v.x)}%'), reason: '$k');
      }
      for (var l = 1; l <= omenCap; l++) {
        expect(omenShown(offBeat, l, l * 2.0).n, offBeat.byL[l - 1], reason: 'L$l');
      }
      expect(g.omenOffBeat, 2);
      g.omenFactor = 1;
      expect(g.omenOffBeat, 2, reason: 'a count goes by L');
      g.omenFactor = 2;
      expect(g.omenEffect(offBeat), 'Rare and Epic Artifacts that work every few hits need 2 more hits.');
      expect(g.omenEffect(shieldbreak), 'Monster hits do 60% more to troop shields.');
      expect(g.omenEffect(lingering), 'Monster buffs last 50% longer.');
      expect(g.omenEffect(avenge), 'When a monster dies, monsters next to it deal 20% more damage for 3s.');
      expect(g.omenEffect(feed), 'Monsters heal 15% of the damage they deal. Not the boss or mini boss.');
      expect(g.omenEffect(eager), 'New monsters deal 30% more damage for 5s.');
      expect(g.omenEffect(healerHunt), 'Monsters deal 25% more damage to ${troopTypePlurals['priest']}.');
      expect(g.omenEffect(spellTax), 'Troop skills cost 30% more MP.');
      expect(g.omenEffect(fade), 'Troop shields shrink by 8% each second.');
      expect(g.omenEffect(straggler), 'A monster alone (none within 2 tiles) deals 30% more. Not bosses.');
      final one = plain(omens: [offBeat]);
      expect(one.omenEffect(offBeat), 'Rare and Epic Artifacts that work every few hits need 1 more hit.');
      for (final k in batch) {
        final line = g.omenLine(k);
        expect(line.length, lessThanOrEqualTo(80), reason: line);
        expect(line.codeUnits.every((c) => c < 128), isTrue, reason: line);
      }
    });
  });

  group('on', () {
    setUp(() => omensOn = true);

    test("Shieldbreak: a monster's blow does × (1 + share) to a troop's ward, absorb and Mana Shield, at most 60% more; "
        'past a shield the rest lands as it was; a blow with no monster behind it, or on a monster\'s shield, never', () {
      final shields = <String, (void Function(Game, Unit), double Function(Game, Unit))>{
        'a ward': ((g, k) => g.giveWard(k, 100), (g, k) => k.ward),
        'an absorb': ((g, k) => g.addEffect(k, Status.absorb, 100, k: 50), (g, k) => g.effectOn(k, Status.absorb)?.k ?? 0),
        'Mana Shield': (
          (g, k) {
            g.addEffect(k, Status.manaShield, 100);
            k.mp = 20; // its max: a blow at +60% still fits
          },
          (g, k) => k.mp
        ),
      };
      final blow = foeBlow();
      expect(blow, greaterThan(0));
      for (final MapEntry(key: what, value: (give, pool)) in shields.entries) {
        (double, double) hit({List<OmenKind> omens = const [], double factor = 1, double? small}) {
          final (g, k, o) = duel(omens: omens, factor: factor);
          give(g, k);
          if (small != null) {
            if (what == 'a ward') k.ward = small;
            if (what == 'an absorb') g.effectOn(k, Status.absorb)!.k = small;
            if (what == 'Mana Shield') k.mp = small;
          }
          final before = pool(g, k), lost = blowOn(g, k, o);
          return (lost, before - pool(g, k));
        }

        final (hp0, lost0) = hit();
        expect(hp0, 0, reason: '$what holds the whole blow');
        for (final (n, factor, up) in [(1, 1.0, 0.12), (4, 1.0, 0.48), (4, 2.0, 0.6)]) {
          final (hp, lost) = hit(omens: levels(shieldbreak, n), factor: factor);
          expect(hp, 0, reason: '$what L$n ×$factor');
          expect(lost - lost0, closeTo(blow * up, 1e-9), reason: '$what L$n ×$factor: the shield takes more');
        }
        final (hpSmall0, _) = hit(small: 1);
        final (hpSmall, lostSmall) = hit(omens: top(shieldbreak), factor: 2, small: 1);
        if (what != 'Mana Shield') {
          // (Mana Shield's MP comes back a little in the tick: only the ward and the absorb are measured whole.)
          expect(hpSmall0, closeTo(blow - 1, 1e-9), reason: what);
          expect(lostSmall, closeTo(1, 1e-9), reason: '$what: broken');
          expect(hpSmall, closeTo(blow - 1 / 1.6, 1e-9), reason: '$what: the blow past it lands as it was');
        } else {
          expect(hpSmall, greaterThan(hpSmall0), reason: 'Mana Shield: the MP runs out sooner');
        }
      }
      // A bleed's tick (no attacker) on a ward, and a troop's blow on a monster's absorb: one for one.
      final (g, k, o) = duel(omens: top(shieldbreak), factor: 2);
      g.giveWard(k, 100);
      final ward = k.ward;
      g.addEffect(k, Status.bleed, 1.5, k: 3, n: 1, bad: true);
      g.tick(1.0);
      expect(k.ward, closeTo(ward - hitTaken(3, k.stats.def), 1e-9), reason: 'a bleed: no monster behind it');
      g.addEffect(o, Status.absorb, 100, k: 100);
      final before = g.effectOn(o, Status.absorb)!.k;
      blowOn(g, o, k);
      final (b, bk, bo) = duel();
      b.addEffect(bo, Status.absorb, 100, k: 100);
      blowOn(b, bo, bk);
      expect(before - g.effectOn(o, Status.absorb)!.k, closeTo(100 - b.effectOn(bo, Status.absorb)!.k, 1e-9),
          reason: "a monster's shield");
    });

    test("Lingering: a buff a monster gives a monster (a kind Spellbreaker strips) lasts × (1 + share), at most 50% "
        "longer; a troop's, a Shadow's own, another kind, or one on a troop, never", () {
      final (g, k, o) = duel(omens: top(lingering), factor: 2);
      Unit fresh() => foeAt(g, 'orc', o.pos + const Point(40, 0));
      final shout = fresh();
      g.addEffect(shout, Status.might, 4, k: 1.3, by: o); // a War Shout
      expect(g.effectOn(shout, Status.might)!.until, closeTo(g.t + 6, 1e-9));
      final frenzy = fresh();
      g.addEffect(frenzy, Status.haste, 4, k: 0.7); // its own (Frenzy)
      expect(g.effectOn(frenzy, Status.haste)!.until, closeTo(g.t + 6, 1e-9));
      final ward = fresh();
      g.addEffect(ward, Status.absorb, 4, k: 30); // Unholy Ward's
      expect(g.effectOn(ward, Status.absorb)!.until, closeTo(g.t + 6, 1e-9));
      final troops = fresh();
      g.addEffect(troops, Status.might, 4, k: 1.3, by: k);
      expect(g.effectOn(troops, Status.might)!.until, closeTo(g.t + 4, 1e-9), reason: "a troop's");
      final shadow = fresh();
      g.addEffect(shadow, Status.might, 4, k: 1.3, omen: true);
      expect(g.effectOn(shadow, Status.might)!.until, closeTo(g.t + 4, 1e-9), reason: "a Shadow's own");
      final other = fresh();
      g.addEffect(other, Status.heal, 4, k: 2);
      expect(g.effectOn(other, Status.heal)!.until, closeTo(g.t + 4, 1e-9), reason: 'not a kind it strips');
      g.addEffect(k, Status.haste, 4, k: 0.7, by: o, bad: true);
      expect(g.effectOn(k, Status.haste)!.until, closeTo(g.t + 4, 1e-9), reason: 'on a troop');
      final (l1, _, lo) = duel(omens: levels(lingering, 1));
      l1.addEffect(lo, Status.might, 4, k: 1.3);
      expect(l1.effectOn(lo, Status.might)!.until, closeTo(l1.t + 4.4, 1e-9), reason: 'L1: 10% longer');
    });

    test('Avenge: a monster that dies gives the monsters within a tile of it an omen might of 1 + share for 3 s, at most '
        '+20%; one further, none; a stronger might stays; Lingering doesn\'t stretch it', () {
      for (final (omens, factor, k) in [(levels(avenge, 1), 1.0, 0.04), (top(avenge), 1.0, 0.16), (top(avenge), 2.0, 0.2)]) {
        final (g, kn, o) = duel(omens: [...omens, ...top(lingering)], factor: factor);
        final near = foeAt(g, 'orc', o.pos + const Point(0, 10)), far = foeAt(g, 'orc', o.pos + const Point(0, 20));
        final strong = foeAt(g, 'orc', o.pos + const Point(0, -10));
        g.addEffect(strong, Status.might, 100, k: 1.5, by: o); // a War Shout's, stronger
        o.hp = 1;
        blowOn(g, o, kn);
        expect(o.alive, isFalse);
        final m = g.effectOn(near, Status.might)!;
        expect(m.k, closeTo(1 + k, 1e-12), reason: '+$k');
        expect(m.until, closeTo(g.t + omenAvengeTime, 1e-9), reason: 'Lingering leaves a Shadow\'s own');
        expect(m.omen, isTrue);
        expect(g.effectOn(far, Status.might), isNull, reason: 'past a tile');
        expect(g.effectOn(strong, Status.might)!.k, 1.5, reason: 'the stronger stays');
      }
      // Its might in a blow: × 1 + share, inside the dealt cap.
      final base = foeBlow();
      expect(foeBlow(omens: top(avenge), factor: 2, set: (g, k, o) => g.addEffect(o, Status.might, 3, k: 1.2, omen: true)),
          closeTo(base * 1.2, 1e-9));
    });

    test("Feed: a monster's blow on a troop heals it share of the HP the blow took, at most 15%; not the boss or a mini "
        'boss', () {
      (double, double) fed({List<OmenKind> omens = const [], double factor = 1, Tier tier = Tier.normal}) {
        final (g, k, o) = duel(omens: omens, factor: factor, tier: tier);
        o.hp = 10;
        final lost = blowOn(g, k, o);
        return (lost, o.hp - 10);
      }

      final (blow, none) = fed();
      expect((blow > 0, none), (true, 0));
      for (final (n, factor, k) in [(1, 1.0, 0.02), (4, 1.0, 0.08), (4, 2.0, 0.15)]) {
        final (lost, gained) = fed(omens: levels(feed, n), factor: factor);
        expect(lost, blow);
        expect(gained, closeTo(blow * k, 1e-9), reason: 'L$n ×$factor');
      }
      for (final tier in [Tier.miniBoss, Tier.boss]) {
        expect(fed(omens: top(feed), factor: 2, tier: tier).$2, 0, reason: tier.name);
      }
      expect(fed(omens: top(feed), factor: 2, tier: Tier.highElite).$2, greaterThan(0));
    });

    test('Eager: a monster the wave brings comes on with an omen might of 1 + share for 5 s, at most +30%; one a '
        'necromancer raises, never', () {
      for (final (omens, factor, k) in [(levels(eager, 1), 1.0, 0.05), (top(eager), 2.0, 0.3)]) {
        final g = plain(omens: omens, factor: factor);
        for (final tier in Tier.values) {
          final u = g.monster('orc', tier, const Point(250, 60));
          final m = g.effectOn(u, Status.might)!;
          expect(m.k, closeTo(1 + k, 1e-12), reason: tier.name);
          expect(m.until, closeTo(g.t + omenEagerTime, 1e-9), reason: tier.name);
          expect(m.omen, isTrue, reason: tier.name);
        }
      }
      final g = plain(omens: top(eager), factor: 2);
      final necro = g.monster(boss, Tier.boss, const Point(250, 60))..summonCd = 0;
      g.units.add(necro..mp = necro.stats.mp.toDouble());
      g.tick(0.05);
      expect(g.minionsOf(necro), isNotEmpty);
      expect([for (final m in g.minionsOf(necro)) g.effectOn(m, Status.might)], everyElement(isNull));
      expect(plain(omens: top(OmenKind.armor)).monster('orc', Tier.normal, const Point(250, 60)).effects, isEmpty, reason: 'without it');
    });

    test("Healer Hunt: a monster's blow on a priest × (1 + share), at most 25%; on any other troop never", () {
      final priest = foeBlow(troop: 'priest'), knight = foeBlow();
      for (final (n, factor, k) in [(1, 1.0, 0.04), (4, 1.0, 0.16), (4, 2.0, 0.25)]) {
        expect(foeBlow(omens: levels(healerHunt, n), factor: factor, troop: 'priest'), closeTo(priest * (1 + k), 1e-9));
      }
      expect(foeBlow(omens: top(healerHunt), factor: 2), knight, reason: 'a knight');
    });

    test("Straggler: a monster's blow × (1 + share) while no other monster stands within 2 tiles of it, at most 30%; "
        'with one near, never; nor the boss or a mini boss', () {
      final base = foeBlow();
      void near(Game g, Unit k, Unit o) => foeAt(g, 'orc', o.pos + const Point(0, 20)); // 20 px: within 2 tiles
      void far(Game g, Unit k, Unit o) => foeAt(g, 'orc', o.pos + const Point(0, 40));
      for (final (n, factor, k) in [(1, 1.0, 0.06), (4, 1.0, 0.24), (4, 2.0, 0.3)]) {
        expect(foeBlow(omens: levels(straggler, n), factor: factor), closeTo(base * (1 + k), 1e-9), reason: 'L$n ×$factor');
        expect(foeBlow(omens: levels(straggler, n), factor: factor, set: far), closeTo(base * (1 + k), 1e-9));
        expect(foeBlow(omens: levels(straggler, n), factor: factor, set: near), closeTo(base, 1e-9), reason: 'one near');
      }
      for (final tier in [Tier.miniBoss, Tier.boss]) {
        expect(foeBlow(omens: top(straggler), factor: 2, tier: tier), foeBlow(tier: tier), reason: tier.name);
      }
    });

    test('the dealt cap: Healer Hunt, Straggler, Defiant and an omen might multiply, and stop at 1.6 together', () {
      final base = foeBlow(troop: 'priest');
      expect(foeBlow(omens: [...levels(healerHunt, 2), ...levels(straggler, 2)], troop: 'priest'),
          closeTo(base * 1.08 * 1.12, 1e-9), reason: 'under it: the product');
      expect(
          foeBlow(
              omens: [...top(healerHunt), ...top(straggler), ...top(eager)],
              factor: 2,
              troop: 'priest',
              set: (g, k, o) => g.addEffect(o, Status.might, 100, k: 1.3, omen: true)),
          closeTo(base * omenDealtMost, 1e-9),
          reason: '1.3 × 1.25 × 1.3: the cap');
    });

    test('Spell Tax (troop-side): every MP price a troop pays is × (1 + share), at most 30%, never past its max MP; a '
        'Hero short of it waits, its tooltips show it', () {
      final (g, k, _) = duel(omens: top(spellTax), factor: 2);
      expect(g.skillCost(k, 10), closeTo(13, 1e-9));
      expect(g.skillCost(k, 18), 20, reason: "the knight's max MP");
      expect(g.skillCost(k, 25), 25, reason: 'a price past it already stays');
      expect(plain(omens: levels(spellTax, 1)).skillCost(k, 10), closeTo(10.5, 1e-9));
      expect(plain().skillCost(k, 15), 15);

      // A Hero's Shield Bash (15 MP): short of the taxed price it waits; with it, it casts and pays it.
      (Game, Unit) bash(double mp, {List<OmenKind> omens = const []}) {
        final (s, h) = heroCaster(HeroSkill.shieldBash);
        s
          ..omens.addAll(omens)
          ..omenFactor = 2;
        foeAt(s, 'orc', h.pos + Point(h.stats.range, 0), Tier.highElite);
        h.mp = mp;
        s.tick(0.05);
        return (s, h);
      }

      final (s0, h0) = bash(15);
      expect(h0.heroSkillAt, s0.t, reason: 'without it: 15 MP casts');
      final (s1, h1) = bash(15, omens: top(spellTax));
      expect(h1.heroSkillAt, isNot(s1.t), reason: 'taxed to 19.5: it waits');
      final (s2, h2) = bash(19.5, omens: top(spellTax));
      expect(h2.heroSkillAt, s2.t);
      expect(h2.mp, lessThan(0.1), reason: 'it paid 19.5');

      // The book's tooltips: the price the troops pay (between waves at the factor the next wave freezes: here 1).
      final b = plain(omens: top(spellTax));
      placeNow(b, 'archer', 2, 3);
      expect(b.waveActive, isFalse);
      expect(b.mpInfo('archer').$2, contains('For Arrow Rain (9 MP)'), reason: '7.5 × 1.2');
      expect(plain().mpInfo('archer').$2, contains('For Arrow Rain (7.5 MP)'));
      expect(awakenLines('soldier', 3, price: (base) => b.skillPrice('soldier', base)), contains('MP 16.8, cooldown 9s')); // awakenCdK (decisions-log 298)
      expect(awakenLines('soldier', 3), contains('MP 14, cooldown 9s'));
    });

    test('Off Beat (troop-side): a Rare or Epic every-few-hits Fx needs n more hits, n by L (1, 1, 2, 2); War Drum\'s '
        'every 3rd becomes every 4th or 5th; Twin Fury on the fury\'s beat never moves', () {
      List<int> procs(List<OmenKind> omens, {double factor = 1, bool twin = false}) {
        final (g, k, o) = duel(omens: omens, factor: factor);
        o.hp = 1e9;
        if (twin) {
          g.givePusaka(Relic.twinFury, type: 'knight');
          g.relicBag[Relic.fury] = 1;
          expect(g.useRelic(Relic.fury, k), isTrue);
        } else {
          g.givePusaka(Relic.warDrum, type: 'knight');
        }
        k.blows = 0;
        final hits = [for (var i = 0; i < 12; i++) blowOn(g, o, k)];
        final low = hits.reduce(min);
        return [for (final (i, h) in hits.indexed) if (h > low + 1e-9) i + 1];
      }

      expect(procs(const []), [3, 6, 9, 12]);
      expect(procs(levels(offBeat, 1)), [4, 8, 12]);
      expect(procs(levels(offBeat, 2), factor: 2), [4, 8, 12], reason: 'L2 at ×2: still +1 (by L)');
      expect(procs(levels(offBeat, 3)), [5, 10]);
      expect(procs(top(offBeat), factor: 2), [5, 10], reason: 'at most +2');
      expect(procs(top(offBeat), factor: 2, twin: true), procs(const [], twin: true));
      expect(procs(const [], twin: true), [3, 6, 9, 12]);
    });

    test('Fade (troop-side): a troop\'s ward and absorb lose share of what is left each second, at most 8%, a stunned '
        "one's too; Mana Shield's MP and a monster's absorb never", () {
      for (final (omens, factor, k) in [(levels(fade, 1), 1.0, 0.02), (top(fade), 2.0, 0.08)]) {
        final (g, kn, o) = duel(omens: omens, factor: factor);
        g
          ..giveWard(kn, 100)
          ..addEffect(kn, Status.absorb, 100, k: 50)
          ..addEffect(o, Status.absorb, 100, k: 50);
        kn.stunUntil = 1e9;
        final ward = kn.ward;
        runFor(g, 1);
        final keep = pow(1 - k * 0.05, 20);
        expect(kn.ward, closeTo(ward * keep, 1e-9), reason: '-$k a second');
        expect(g.effectOn(kn, Status.absorb)!.k, closeTo(50 * keep, 1e-9));
        expect(g.effectOn(o, Status.absorb)!.k, 50, reason: "a monster's");
      }
      final (g, kn, _) = duel(omens: top(fade), factor: 2);
      g.addEffect(kn, Status.manaShield, 100);
      kn.mp = 10;
      final (b, bk, _) = duel();
      b.addEffect(bk, Status.manaShield, 100);
      bk.mp = 10;
      runFor(g, 1);
      runFor(b, 1);
      expect(kn.mp, bk.mp, reason: "Mana Shield's MP");
    });
  });

  group('off', () {
    setUp(() => omensOn = false);

    test('with every kind of the batch at its most, nothing acts: blows both ways, shields, buff times, spawns, MP prices '
        'and every-few-hits Fx land as with none', () {
      final all = [for (final k in batch) ...top(k)];
      void prep(Game g, Unit k, Unit o) {
        g.giveWard(k, 2);
        foeAt(g, 'orc', o.pos + const Point(0, 40));
      }

      expect(foeBlow(omens: all, factor: 2, troop: 'priest', set: prep), foeBlow(troop: 'priest', set: prep));
      final (g, k, o) = duel(omens: all, factor: 2);
      final (b, bk, bo) = duel();
      for (final (game, kn, orc) in [(g, k, o), (b, bk, bo)]) {
        game
          ..giveWard(kn, 100)
          ..givePusaka(Relic.warDrum, type: 'knight');
        orc.hp = 10;
      }
      expect(blowOn(g, k, o), blowOn(b, bk, bo));
      expect((k.ward, o.hp), (bk.ward, bo.hp), reason: 'Shieldbreak, Fade, Feed');
      runFor(g, 1);
      runFor(b, 1);
      expect(k.ward, bk.ward);
      g.addEffect(o, Status.might, 4, k: 1.3);
      expect(g.effectOn(o, Status.might)!.until, g.t + 4, reason: 'Lingering');
      expect(g.monster('orc', Tier.normal, const Point(250, 60)).effects, isEmpty, reason: 'Eager');
      expect(g.skillCost(k, 15), 15, reason: 'Spell Tax');
      expect(g.omenOffBeat, 0);
      o.hp = bo.hp = 1e9;
      k.blows = bk.blows = 0;
      expect([for (var i = 0; i < 6; i++) blowOn(g, o, k)], [for (var i = 0; i < 6; i++) blowOn(b, bo, bk)], reason: 'Off Beat');
      final near = foeAt(g, 'orc', o.pos + const Point(0, 10));
      o.hp = 1;
      blowOn(g, o, k);
      expect(g.effectOn(near, Status.might), isNull, reason: 'Avenge');
    });
  });
}
