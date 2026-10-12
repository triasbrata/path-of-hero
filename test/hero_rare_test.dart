// Heroes' own skills (#48, branch 3): the priest's Resurrection and the wizard's Slime Hex.
// docs/units-and-combat.md, "Hero skills".
import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';

import 'hero_skill_helpers.dart';

void main() {
  /// A troop of [type] at cell ([c], [r]) that never strikes (nor heals) on its own.
  Unit idle(Game g, String type, int c, int r) => placeNow(g, type, c, r)..cd = hold;

  /// Monsters [ms] strike their nearest foes once, now (they must be in reach): one tick.
  void strike(Game g, List<Unit> ms) {
    for (final m in ms) {
      m
        ..busyUntil = double.negativeInfinity
        ..cd = 0;
    }
    g.tick(0.05);
    for (final m in ms) {
      m.busyUntil = hold;
    }
  }

  group('Resurrection', () {
    test('once a wave, the troop that fell last in reach rises where it fell (not past a tile ahead of the priest), at 30% HP and no MP', () {
      final (g, h) = heroCaster(HeroSkill.revive);
      final a = idle(g, 'soldier', 4, 2)..hp = 1;
      final b = idle(g, 'knight', 4, 4)
        ..hp = 1
        ..relics.add(Relic.guard);
      strike(g, [foeAt(g, 'orc', a.pos + const Point(12, 0)), foeAt(g, 'orc', b.pos + const Point(12, 0))]);
      expect(g.fallen, [a, b]);
      expect(h.heroSkillAt, double.negativeInfinity, reason: 'the priest acted before they fell');
      final priestAt = h.pos; // it casts before it moves
      g.tick(0.05);
      expect(h.heroSkillAt, g.t);
      final r = g.troops.last;
      expect((r.type, r.name, r.relics.firstOrNull, r.revived, r.hero), ('knight', b.name, null, true, false));
      expect((r.hp, r.mp), (r.maxHp * reviveK.hp, 0));
      expect(r.pos, Point(min(b.pos.x, priestAt.x + reviveK.ahead), b.pos.y));
      expect((r.post, r.busyUntil), (b.post, g.t + riseTime)); // it rises, then fights from its own spot
      expect(g.fallen, [a]); // off the win popup's list
      expect(g.risen, [r]); // "<name> rises again!"
      expect(g.relicBag[Relic.guard], 1); // its relic stayed in the bag

      runFor(g, 2);
      expect(g.fallen, [a], reason: 'once a wave');
      expect(g.armySize, 2);
    });

    test('never a Hero, one revived before, one that fell out of reach, nor while the army is full', () {
      bool revives(void Function(Game g, Unit t) setUp) {
        final (g, h) = heroCaster(HeroSkill.revive);
        final t = idle(g, 'soldier', 4, 3)..hp = 1;
        setUp(g, t);
        strike(g, [foeAt(g, 'orc', t.pos + const Point(12, 0))]);
        expect(t.alive, isFalse);
        g.tick(0.05);
        return h.heroSkillAt == g.t;
      }

      expect(revives((g, t) {}), isTrue);
      expect(revives((g, t) => t.hero = true), isFalse, reason: 'a Hero');
      expect(revives((g, t) => t.revived = true), isFalse, reason: 'revived before');
      expect(
          revives((g, t) {
            t.pos += const Point(100, 0);
            g.addEffect(t, Status.holdGround, 5); // so it doesn't back off towards the priest before the blow
          }),
          isFalse,
          reason: 'out of reach');
      expect(revives((g, t) => g.capacity = 1), isFalse, reason: 'only the priest is left, and it is full');
    });

    test('a troop brought back is saved as revived, so it never comes back twice', () {
      final g = bareGame();
      final s = placeNow(g, 'soldier', 2, 3)..revived = true, k = placeNow(g, 'knight', 3, 3);
      final back = Game.fromJson(jsonDecode(jsonEncode(g.toJson())) as Map<String, dynamic>);
      expect([for (final u in back.troops) (u.name, u.revived)], [(s.name, true), (k.name, false)]);
    });
  });

  group('Slime Hex', () {
    test('the elite in range that hits hardest is a slime for 5 s, keeping its share of HP, its gold and its rank; then back', () {
      final (g, h) = heroCaster(HeroSkill.slimeHex);
      foeAt(g, 'werebear', h.pos + const Point(60, 0)); // a normal one: never
      g.tick(0.05);
      expect(h.heroSkillAt, double.negativeInfinity);
      final weak = foeAt(g, 'orc', h.pos + const Point(60, 20), Tier.elite);
      final strong = foeAt(g, 'elite_orc', h.pos + const Point(60, -20), Tier.highElite);
      final own = strong.stats, ownHp = strong.maxHp;
      strong.hp = ownHp / 2;
      g.tick(0.05);
      expect(h.heroSkillAt, g.t);
      expect(g.under(weak, Status.hex), isFalse);
      final slime = enemyStats(slimeHexK.form, Tier.normal, g.wave);
      expect((strong.stats.hp, strong.maxHp, strong.stats.dmg, strong.stats.speed), (slime.hp, slime.hp, slime.dmg, slime.speed));
      expect((strong.stats.cost, strong.tier), (own.cost, Tier.highElite)); // its own gold and rank
      expect(strong.hp, closeTo(slime.hp / 2, 1e-9));

      strong.hp = slime.hp / 4; // hurt as a slime
      runFor(g, slimeHexK.time + 0.1);
      expect(g.under(strong, Status.hex), isFalse);
      expect((strong.stats, strong.maxHp), (own, ownHp));
      expect(strong.hp, closeTo(ownHp / 4, 1e-9)); // back with the share it had left
    });

    test('the slime has the wave\'s tide, from the game\'s tideStart', () {
      final (g, h) = heroCaster(HeroSkill.slimeHex);
      g
        ..wave = 87
        ..tideStart = 18;
      final elite = foeAt(g, 'elite_orc', h.pos + const Point(60, 0), Tier.elite);
      g.tick(0.05);
      expect(g.under(elite, Status.hex), isTrue);
      expect(elite.stats.hp, enemyStats(slimeHexK.form, Tier.normal, 87, tideStart: 18).hp);
      expect(elite.stats.hp, greaterThan(enemyStats(slimeHexK.form, Tier.normal, 87, tideStart: 66).hp));
    });

    test('killed as a slime it pays its own gold and score, and dies a slime', () {
      final (g, h) = heroCaster(HeroSkill.slimeHex);
      final elite = foeAt(g, 'elite_orc', h.pos + const Point(60, 0), Tier.elite);
      foeAt(g, 'orc', const Point(300, 10)); // keeps the wave on
      g.tick(0.05);
      expect(g.under(elite, Status.hex), isTrue);
      final s = placeNow(g, 'soldier', 4, 3)..pos = elite.pos - const Point(12, 0);
      elite.hp = 1;
      final (gold, score) = (g.gold, g.score);
      g.tick(0.05);
      expect(elite.alive, isFalse);
      expect((g.gold - gold, g.score - score), (enemyStats('elite_orc', Tier.elite, g.wave).cost, killScore[Tier.elite]));
      expect(elite.effects.containsKey(Status.hex), isTrue); // drawn dying as a slime
      expect(s.alive, isTrue);
    });

    test('never the boss, a mini boss, a necromancer or a healing necromancer; never during a march', () {
      final (g, h) = heroCaster(HeroSkill.slimeHex);
      foeAt(g, boss, h.pos + const Point(60, 0), Tier.boss);
      foeAt(g, 'orc', h.pos + const Point(60, 20), Tier.miniBoss);
      foeAt(g, boss, h.pos + const Point(60, -20), Tier.elite);
      foeAt(g, necroHealer, h.pos + const Point(40, 30), Tier.elite);
      g.tick(0.05);
      expect(h.heroSkillAt, double.negativeInfinity);
      final elite = foeAt(g, 'orc', h.pos + const Point(40, -30), Tier.elite);
      g.marching = true;
      g.tick(0.05);
      expect(h.heroSkillAt, double.negativeInfinity, reason: 'it holds a monster');
      g.marching = false;
      g.tick(0.05);
      expect(g.under(elite, Status.hex), isTrue);
    });
  });
}
