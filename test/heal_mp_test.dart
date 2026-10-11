// Heals cost MP (decisions-log 297) and the troops cast as often as their MP, cooldown and a target allow
// (decisions-log 298): a troop healer's heal costs healMp, short of it no heal (a free smite on the undead in reach, or
// it waits) and "No MP" pops once; a skill of its that is ready and has a target comes first; the after-wave heals stay
// free; the words. The #10 skills' table and target rules are game_test.dart's; here the awakening and Hero skills'
// halved cooldowns and loosened thresholds. The screen's limits (one name pop a wave, the Hero cut-ins) are
// cut_in_test.dart's.
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';

import 'hero_skill_helpers.dart';

/// A wave with nothing left to spawn and a far, still slime keeping it on; a priest at (0, 3) and a knight that never
/// strikes at (2, 3) for each of [hurt] (its HP share), the next one a row lower. Only the #10 skills if [skills].
(Game, Unit, List<Unit>) infirmary(List<double> hurt, {bool skills = false}) {
  final g = bareGame()
    ..skills = skills
    ..heroSkills = false
    ..awakenSkills = false;
  final p = placeNow(g, 'priest', 0, 3);
  final ks = [for (var i = 0; i < hurt.length; i++) placeNow(g, 'knight', 2, 3 + i)..cd = hold];
  for (final (i, k) in ks.indexed) {
    k.hp = k.maxHp * hurt[i];
  }
  g
    ..startWave()
    ..queue.clear();
  foeAt(g, 'slime', const Point(400, 60));
  return (g, p, ks);
}

void main() {
  test('a troop healer pays healMp for each heal it gives in a wave; short of it, no heal, and "No MP" pops once until it has the MP again', () {
    expect(healMp, 6.0);
    final (g, p, [k]) = infirmary([0.3]);
    p.mp = 20;
    final hp = k.hp;
    g.tick(0.05);
    expect(k.hp, greaterThan(hp)); // healed
    expect(p.mp, closeTo(20 + p.stats.mpRegen * 0.05 - healMp, 1e-9));
    expect(p.dry, isFalse);
    expect(g.noMp, isEmpty);

    p
      ..mp = healMp - 0.5
      ..cd = 0
      ..attackedAt = double.negativeInfinity; // past its heal's cast (healCast)
    final dryHp = k.hp;
    g.tick(0.05);
    expect((k.hp, p.dry), (dryHp, true)); // no heal
    expect(g.noMp, [p]); // "No MP"
    g.tick(0.05);
    expect(g.noMp, [p]); // once, while it stays short
    var ticks = 0;
    while (k.hp == dryHp && ticks++ < 40) {
      g.tick(0.05);
    }
    expect(k.hp, greaterThan(dryHp)); // the MP came back (its regen): it heals again
    expect((p.dry, g.noMp.length), (false, 1));
    p
      ..mp = 0
      ..cd = 0
      ..attackedAt = double.negativeInfinity;
    g.tick(0.05);
    expect(g.noMp, [p, p]); // a new dry spell pops again
  });

  test('short of MP a priest smites the undead in its reach for free; the after-wave heal needs no MP', () {
    final (g, p, [k]) = infirmary([0.3]);
    final skeleton = foeAt(g, 'skeleton', p.pos + Point(p.stats.range / 2, -tile));
    p.mp = 0;
    g.tick(0.05);
    expect(skeleton.hp, lessThan(skeleton.maxHp)); // smitten
    expect(p.mp, closeTo(p.stats.mpRegen * 0.05, 1e-9)); // for nothing
    expect(g.noMp, [p]);

    // The wave won with the priest at 0 MP: the hurt knight still gets all its HP back.
    for (final m in g.enemies) {
      m.gone = true;
    }
    for (var i = 0; i < 400 && k.hp < k.maxHp; i++) {
      p.mp = 0;
      g.tick(0.05);
    }
    expect(g.waveActive, isFalse);
    expect(k.hp, k.maxHp);
  });

  test('skill first (decisions-log 297): a priest whose prayer is ready and has its crowd holds its heals for the prayer\'s MP; on cooldown, its heals use the rest', () {
    final prayerCost = troopSkills['priest']!.cost;
    expect(prayerCost, 15);
    final (g, p, ks) = infirmary([0.5, 0.5], skills: true); // two hurt side by side: the prayer wants them
    p.mp = prayerCost - 1; // a heal would leave too little for the prayer
    final hps = [for (final k in ks) k.hp];
    g.tick(0.05);
    expect([for (final k in ks) k.hp], hps); // it waits
    expect(p.skillAt, double.negativeInfinity);
    expect(g.noMp, isEmpty); // not dry: saving up
    var ticks = 0;
    while (p.skillAt < 0 && ticks++ < 40) {
      g.tick(0.05);
    }
    expect(p.skillAt, g.t); // its MP came back: it prays
    for (final (i, k) in ks.indexed) {
      expect(k.hp, greaterThan(hps[i]));
    }

    final (h, hp, [hk, _]) = infirmary([0.5, 0.5], skills: true);
    hp
      ..mp = prayerCost - 1
      ..skillAt = h.t; // the prayer just cast: on cooldown
    final before = hk.hp;
    h.tick(0.05);
    expect(hk.hp, greaterThan(before)); // a heal from what is left
    expect(hp.mp, closeTo(prayerCost - 1 + hp.stats.mpRegen * 0.05 - healMp, 1e-9));
  });

  test('the words (decisions-log 297): a healer\'s MP pays for heals and skills, its heal names the cost; "No MP"; the MP tooltip\'s heal line for a healer only', () {
    expect(Words.healerMpHelp, ['Pays for heals and skills', 'Heals, skills']);
    expect(Words.healHelp, ['HP back per heal, ${healMp.round()} MP', 'Per heal, ${healMp.round()} MP']);
    expect(Words.noMp, 'No MP');
    final g = Game();
    expect(g.mpInfo('priest').$2, contains('Each heal: ${healMp.round()} MP'));
    expect(g.mpInfo('knight').$2.any((l) => l.startsWith('Each heal')), isFalse);
  });

  test('awakening skills (decisions-log 298): awakenCdK of their cooldowns; a target is enough (crowds 1, the caster\'s HP gates and a foe\'s worth gone)', () {
    expect(awakenCdK, 0.5);
    for (final s in AwakenSkill.values) {
      for (final level in [1, 2, 3]) {
        expect(s.cooldownAt(level), s.cooldown[level - 1] * awakenCdK, reason: '${s.name} $level');
      }
    }
    expect((singularityK.crowd, consecrationK.crowd, phantomRushK.crowd, skyfallK.crowd), (1, 1, 1, 1));
    expect((disarmK.worth, unbrokenK.low, unbrokenK.hindered), (0.0, 1.0, 1.0));
    expect((lifelineK.below, skyfallK.above), (0.5, 0.5)); // a dying troop's rescue; the axeman's own safety: kept

    // Consecration with a lone foe on its ground.
    final g = bareGame();
    final tp = placeNow(g, 'knight_templar', 2, 3)..cd = hold;
    g
      ..startWave()
      ..queue.clear();
    expect(g.wantsAwakenSkill(tp, AwakenSkill.consecration, 1), isFalse);
    foeAt(g, 'orc', tp.pos + Point(consecrationK.radius[0] / 2, 0));
    expect(g.wantsAwakenSkill(tp, AwakenSkill.consecration, 1), isTrue);
  });

  test('Hero skills (decisions-log 298): heroCdK of their cooldowns (Resurrection still once a wave); a lone target is enough', () {
    expect(heroCdK, 0.5);
    expect((HeroSkill.revive.cooldown * heroCdK).isInfinite, isTrue);
    expect([warCryK.crowd, plunderK.crowd, bloodlustK.crowd, blessingK.crowd, holyNovaK.crowd, manaGiftK.crowd, ironSkinK.crowd, quakeK.crowd,
        exorcismK.crowd, whirlwindK.crowd, giantRageK.crowd, holyTauntK.crowd, bastionK.crowd, bannerK.crowd, pierceShotK.crowd, axeThrowK.crowd,
        axeThrowK.few, chainLightningK.crowd, frostStormK.crowd, sweepK.crowd, spearWallK.crowd], everyElement(1));
    expect([bloodlustK.below, blessingK.hurt, lastStandK.below, giantRageK.below, holyTauntK.below, bastionK.below, shieldBashK.below], everyElement(1.0));
    expect((deepWoundK.worth, executeK.below, sacrificeK.above, rescueLeapK.above, deathLeapK.above), (0.0, 0.25, 0.6, 0.4, 0.4)); // a target's and a Hero's safety: kept

    // Judgement again after half its cooldown, MP aside.
    final (g, h) = heroCaster(HeroSkill.judgement);
    foeAt(g, 'skeleton', h.pos + Point(h.stats.range / 2, 0)).hp = 1e9;
    g.tick(0.05);
    final first = h.heroSkillAt;
    expect(first, g.t);
    while (h.heroSkillAt == first && g.t - first < HeroSkill.judgement.cooldown) {
      h.mp = h.stats.mp.toDouble();
      g.tick(0.05);
    }
    expect(h.heroSkillAt - first, inInclusiveRange(HeroSkill.judgement.cooldown * heroCdK, HeroSkill.judgement.cooldown * heroCdK + 0.05));

    // War Cry for itself alone, fighting; Chain Lightning on one foe in reach.
    final (w, wh) = heroCaster(HeroSkill.warCry);
    foeAt(w, 'orc', const Point(400, 60));
    wh.attackedAt = w.t;
    w.tick(0.05);
    expect(wh.heroSkillAt, w.t);
    final (c, ch) = heroCaster(HeroSkill.chainLightning);
    foeAt(c, 'orc', ch.pos + Point(ch.stats.range / 2, 0));
    c.tick(0.05);
    expect(ch.heroSkillAt, c.t);
  });
}
