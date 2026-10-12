// The Town's life (decisions-log 229; lib/town_life.dart; ui-hud.md "Town", "Town life"): the troops' errands on a
// scripted visual dice ([TownLife] alone: each errand reachable at its place, facing its way, for its stay; the places
// and their caps; the Tavern's guests up its doorstep, gone inside and back out at its door (decisions-log 274);
// two-person talks meeting and facing each other, a bubble over one head then the other; the troops = the living army),
// the game's own dice never touched; and on
// booted TdGames with the Towns on at the desk (1266x713), the owner's tablet (1164x777) and a phone (915x412):
// the living army on the street's lane, walking, no tap taken by a troop, the life still while paused and afresh at
// every Town, the talk's and the Tavern window's bubbles drawn where they belong.
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';
import 'package:tower_defense/main.dart';

import 'town_hud_test.dart' show boot, frames;
import 'town_scene_test.dart' show bare, intoTown, settle, wheel;

/// A visual dice of a test's own: [queue]'s draws first, then [fallback] (the life only ever asks [nextDouble]).
class ScriptDice implements Random {
  ScriptDice([this.fallback = 0.0]);

  final queue = <double>[];
  double fallback;

  @override
  double nextDouble() => queue.isEmpty ? fallback : queue.removeAt(0);

  @override
  int nextInt(int max) => (nextDouble() * max).floor();

  @override
  bool nextBool() => nextDouble() < 0.5;
}

/// A street like the desk's (world px): its length and its anchors.
const street = 633.0;
const anchors = {'guard': 18.0, 'tent': 54.0, 'smithy': 236.0, 'tavernDoor': 330.0, 'talk': 470.0, 'shop': 580.0};

/// The dice draw that puts a troop at [x] along [street] ([TownLife.step]'s placing).
double at(double x) => (x - townEdge) / (street - 2 * townEdge);

/// A troop of [type] on the field.
Unit troop([String type = 'soldier']) => Unit(Side.troop, type, troopTypes[type]!, const Point(8, 8));

/// A life on [dice] along [street], with [units] synced (each one's depth 0 and head start 0 drawn first).
TownLife life(ScriptDice dice, List<Unit> units) {
  dice.queue.insertAll(0, [for (final _ in units) ...[0.0, 0.0]]);
  return TownLife(dice)
    ..stage(street, anchors)
    ..sync(units);
}

/// Steps [l] in 0.05 s steps until [done] (at most [most] s); the seconds it took.
double until(TownLife l, bool Function() done, {double most = 60}) {
  final t0 = l.t;
  while (!done()) {
    l.step(0.05);
    if (l.t - t0 > most) fail('not done within $most s');
  }
  return l.t - t0;
}

void main() {
  test('pick and drawFor: each errand has its share of a draw, in townWeights; a draw in its middle picks it', () {
    final total = townWeights.reduce((a, b) => a + b);
    expect(total, 25);
    for (final what in TownDo.values) {
      expect(TownLife.pick(TownLife.drawFor(what)), what);
    }
    expect([TownLife.pick(0), TownLife.pick(0.9999)], [TownDo.stroll, TownDo.rest]);
    var seen = <TownDo, int>{};
    for (var i = 0; i < total; i++) {
      final what = TownLife.pick((i + 0.5) / total);
      seen[what] = (seen[what] ?? 0) + 1;
    }
    expect([for (final what in TownDo.values) seen[what]], townWeights);
  });

  test('each errand on a scripted dice: placed, set out, there at its place facing its way, for the stay the dice says; '
      'the Tavern takes it inside and lets it out at its door; then the next roll', () {
    // what, where it ends up, its facing there (0: the way it walked).
    final cases = [
      (TownDo.guard, anchors['guard']!, -1),
      (TownDo.shop, anchors['shop']! + townBrowse[0], 1),
      (TownDo.smithy, anchors['smithy']! + townBrowse[0], 1),
      (TownDo.tavern, anchors['tavernDoor']!, 0),
      (TownDo.rest, anchors['tent']! + townRest[0], 1),
      (TownDo.stroll, townEdge + 0.25 * (street - 2 * townEdge), 0),
    ];
    for (final (what, where, facing) in cases) {
      final dice = ScriptDice(), u = troop(), l = life(dice, [u]), f = l.folk.single;
      expect(f.x.isNaN, isTrue, reason: 'placed at the first step');
      dice.queue.addAll([at(300), 0.9, TownLife.drawFor(what), if (what == TownDo.stroll) 0.25, 0.5]);
      l.step(0.05);
      expect((f.doing, f.walking, f.dir), (what, true, where < 300 ? -1 : 1), reason: '$what: on its way');
      final walked = until(l, () => !f.walking);
      expect(walked, closeTo((f.x - 300).abs() / f.speed, 0.1), reason: '$what: walked at its pace');
      expect(f.speed, troopTypes['soldier']!.speed * townPace * townFolkK);
      expect(f.x, where, reason: '$what: at its place');
      if (facing != 0) expect(f.dir, facing, reason: '$what: facing');
      final (lo, hi) = townStay[what]!;
      final doorway = what == TownDo.tavern ? 2 * townDoorway : 0.0;
      expect(f.until - f.from, closeTo(lo + 0.5 * (hi - lo) + doorway, 1e-9),
          reason: "$what: the stay the dice said (a Tavern guest's doorway on the way in and out too)");
      // On a building's floor (decisions-log 274): the Tavern's doorway, the tent's opening; drawn on arriving.
      expect(f.up, what == TownDo.tavern || what == TownDo.rest, reason: '$what: stepped up?');
      expect((f.inside, l.inTavern), (false, 0), reason: '$what: not inside yet');
      if (what == TownDo.tavern) {
        // In its doorway townDoorway s, then inside; while inside the window shows its bubble the first townWindowFor s
        // of every townWindowEvery.
        until(l, () => f.inside, most: townDoorway + 0.1);
        expect(l.t - f.from, closeTo(townDoorway, 0.06), reason: 'inside after its doorway');
        expect(l.inTavern, 1);
        final shows = <bool>[];
        while (l.t < f.until - townDoorway - 0.1) {
          shows.add(l.windowBubble);
          expect(l.windowBubble, l.t % townWindowEvery < townWindowFor);
          l.step(0.05);
        }
        expect(shows.toSet(), {true, false});
        // Out into its doorway again for its last townDoorway s, still up there.
        until(l, () => !f.inside, most: 0.2);
        expect((f.up, f.doing, l.inTavern, l.windowBubble), (true, TownDo.tavern, 0, false), reason: 'in its doorway');
        expect(f.until - l.t, closeTo(townDoorway, 0.06));
      }
      // The stay over: the next roll (the fallback 0: a stroll), out of the Tavern at its door, down on the street.
      until(l, () => f.doing != what || f.walking, most: hi + 2);
      expect((f.doing, f.inside, f.up, l.inTavern, l.windowBubble), (TownDo.stroll, false, false, 0, false),
          reason: '$what: then');
      if (what == TownDo.tavern) expect(f.x, anchors['tavernDoor'], reason: 'out at the door');
    }
  });

  test("the places' caps and slots: two guards (the left end facing out left, the right end facing out right), four "
      'browsers either side of the stall facing it, four resting round the fire; one more strolls instead', () {
    for (final (what, wants) in [
      (TownDo.guard, [(anchors['guard']!, -1), (street - anchors['guard']!, 1)]),
      (TownDo.shop, [for (final d in townBrowse) (anchors['shop']! + d, d < 0 ? 1 : -1)]),
      (TownDo.smithy, [for (final d in townBrowse) (anchors['smithy']! + d, d < 0 ? 1 : -1)]),
      (TownDo.rest, [for (final d in townRest) (anchors['tent']! + d, d < townFire ? 1 : -1)]),
    ]) {
      final n = wants.length + 1, dice = ScriptDice(), units = [for (var i = 0; i < n; i++) troop()], l = life(dice, units);
      for (var i = 0; i < n; i++) {
        dice.queue.addAll([at(300), 0.9, TownLife.drawFor(what), if (i == n - 1) 0.5]); // the last: a stroll's goal
      }
      l.step(0.05);
      expect(townMost[what], wants.length);
      final last = l.folk.last;
      expect(last.doing, TownDo.stroll, reason: '$what full: one more strolls');
      final there = l.folk.take(wants.length).toList();
      until(l, () => there.every((f) => !f.walking));
      expect([for (final f in there) (f.x, f.dir)], wants, reason: '$what');
      expect([for (final f in there) f.slot], [for (var i = 0; i < wants.length; i++) i]);
    }
  });

  test('a talk: the roller takes the nearest one strolling, they meet halfway (or before the Tavern) and face each '
      'other; a bubble over the roller on the even lines, over the other on the odd ones, an icon a line; then both '
      'roll again; alone it strolls', () {
    for (final atSpot in [false, true]) {
      final dice = ScriptDice(), a = troop('knight'), b = troop('priest'), far = troop('wizard');
      final l = life(dice, [a, b, far]);
      final (fa, fb, ff) = (l.folk[0], l.folk[1], l.folk[2]);
      dice.queue.addAll([
        at(200), 0.1, TownLife.drawFor(TownDo.stroll), at(210), // a strolls on
        at(260), 0.9, TownLife.drawFor(TownDo.talk), atSpot ? 0.2 : 0.9, // b talks: with a (the nearest), where?
        at(600), 0.9, TownLife.drawFor(TownDo.guard), // far guards (not strolling: never taken)
      ]);
      l.step(0.05);
      expect((fb.doing, fa.doing, ff.doing), (TownDo.talk, TownDo.talk, TownDo.guard));
      expect((identical(fb.mate, fa), identical(fa.mate, fb), fb.lead, fa.lead), (true, true, true, false));
      final meet = atSpot ? anchors['talk']! : (fa.goal + fb.goal) / 2;
      expect(fb.goal - fa.goal, closeTo(townTalkGap, 1e-9));
      if (atSpot) expect(meet, anchors['talk']);
      if (!atSpot) expect(meet, closeTo((200 + 0.05 * fa.speed + 260) / 2, 1e-6)); // halfway, as they were then
      dice.queue.add(0.0); // the talk's lines: the fewest, 3
      dice.queue.addAll([0.0, 2.5 / townTopics.length, 0.0]); // its lines' icons: heart, coin, heart
      until(l, () => !fa.walking && !fb.walking);
      expect((fa.dir, fb.dir), (1, -1), reason: 'face each other');
      final start = fa.from, end = fa.until;
      expect((fb.from, fb.until), (start, end));
      expect(end - start, closeTo(townTalkLines.$1 * townLine, 1e-9));
      // Line by line: who says what.
      final heard = <(String?, String?)>[];
      while (l.t < end - 0.05) {
        l.step(0.05);
        final now = (fb.said?.name, fa.said?.name);
        if (heard.isEmpty || heard.last != now) heard.add(now);
        expect(fa.said != null && fb.said != null, isFalse, reason: 'one bubble at a time');
      }
      expect(heard, [('heart', null), (null, null), (null, 'coin'), (null, null), ('heart', null), (null, null)],
          reason: 'the roller, then the other, then the roller');
      until(l, () => fa.doing != TownDo.talk && fb.doing != TownDo.talk, most: 1);
      expect((fa.mate, fb.mate, fa.said, fb.said), (null, null, null, null));
    }
    // Alone (no one strolling): a talk becomes a stroll.
    final dice = ScriptDice(), l = life(dice, [troop()]);
    dice.queue.addAll([at(300), 0.9, TownLife.drawFor(TownDo.talk), 0.5]);
    l.step(0.05);
    expect((l.folk.single.doing, l.folk.single.mate), (TownDo.stroll, null));
  });

  test("a browser thinks of the coins (the Shop) or the hammer (the Smithy) for a moment after arriving: a grey thought",
      () {
    for (final (what, icon) in [(TownDo.shop, TownIcon.coins), (TownDo.smithy, TownIcon.hammer)]) {
      final dice = ScriptDice(), l = life(dice, [troop()]), f = l.folk.single;
      dice.queue.addAll([at(anchors[what.name]! - 18), 0.9, TownLife.drawFor(what), 0.99]);
      l.step(0.05);
      until(l, () => !f.walking);
      final t0 = f.from;
      final seen = <(double, TownIcon?)>[];
      while (l.t < t0 + 3) {
        l.step(0.05);
        seen.add((l.t - t0, f.said));
      }
      for (final (since, said) in seen) {
        expect(said, since >= townThink.$1 && since < townThink.$2 ? icon : null, reason: '$what at +$since');
      }
      expect(f.thought, isTrue);
    }
  });

  test("the troops are the living army: Heroes in; the fallen, the gone and the monsters out; one joining or falling "
      "follows at the next sync, and a talk's mate rolls again", () {
    final g = Game(Random(1), Random(2));
    final hero = troop('knight')..hero = true, plain = troop('archer'), fallen = troop('soldier')..dying = 0.2;
    final gone = troop('wizard')..gone = true;
    g.units
      ..clear() // the game's own first troop: out of the way, so the draws below are each one's
      ..addAll([hero, plain, fallen, gone, g.monster('slime', Tier.normal, const Point(300, 60))]);
    final dice = ScriptDice(), l = TownLife(dice)
      ..stage(street, anchors)
      ..sync(g.units);
    expect({for (final f in l.folk) f.unit}, {hero, plain});
    dice.queue.addAll([at(200), 0.1, TownLife.drawFor(TownDo.stroll), at(210), at(260), 0.9, TownLife.drawFor(TownDo.talk), 0.9]);
    l.step(0.05);
    final fh = l.folk.firstWhere((f) => f.unit == hero);
    expect(fh.doing, TownDo.talk);
    // The archer falls mid-talk: it leaves, the Hero rolls again (the fallback: a stroll).
    plain.dying = 0;
    l.sync(g.units);
    expect([for (final f in l.folk) f.unit], [hero]);
    l.step(0.05);
    expect((fh.doing, fh.mate), (TownDo.stroll, null));
    // A new troop joins: placed at the next step.
    final fresh = troop('lancer');
    g.units.add(fresh);
    l.sync(g.units);
    expect({for (final f in l.folk) f.unit}, {hero, fresh});
    l.step(0.05);
    expect(l.folk.every((f) => !f.x.isNaN), isTrue);
    // Unchanged: nothing redone.
    final before = [...l.folk];
    l.sync(g.units);
    expect(l.folk, before);
  });

  test("the Town's life never touches the game's dice: twin games play the same after one's troops lived 120 s in a "
      'Town', () {
    Game twin() {
      final g = Game(Random(5), Random(6))
        ..loot = Random(7)
        ..slots = Random(8)
        ..draft = Random(9)
        ..matDice = Random(10) // every game has the Towns (decisions-log 321): their dice too
        ..townDice = Random(11)
        ..tavernDice = Random(12)
        ..gold = 4000
        ..wave = 3;
      for (final type in ['knight', 'archer', 'priest', 'wizard', 'soldier', 'lancer']) {
        g.autoPlace(type);
      }
      return g;
    }

    final a = twin(), b = twin();
    final l = TownLife(Random(11))
      ..stage(street, anchors)
      ..sync(a.units);
    for (var i = 0; i < 2400; i++) {
      l
        ..sync(a.units)
        ..step(0.05);
    }
    expect(l.folk, hasLength(a.troops.length));
    expect(jsonEncode(a.toJson()), jsonEncode(b.toJson()));
    for (final g in [a, b]) {
      g.startWave();
      for (var i = 0; i < 600; i++) {
        g.viewW = 341;
        g.tick(1 / 30);
      }
    }
    expect(jsonEncode(a.toJson()), jsonEncode(b.toJson()), reason: 'the same wave, the same dice');
  });

  for (final size in const [Size(1266, 713), Size(1164, 777), Size(915, 412)]) {
    final tag = '${size.width.round()}x${size.height.round()}';
    testWidgets('the Town at $tag: the living army on the street\'s lane (a Hero in, the fallen out), walking about; no '
        'troop takes a tap; still while paused; afresh at the next Town', (tester) async {
      final b = await boot(tester, size)..townDice = Random(4);
      b.autoStart.set(false);
      final g = await intoTown(tester, b);
      final hero = troop('knight')..hero = true, fallen = troop('soldier')..dying = 0.2;
      final army = [hero, for (final type in ['archer', 'priest', 'wizard', 'soldier', 'lancer']) troop(type)];
      final own = g.troops.where((u) => u.alive).toList(); // the game's own first troop
      g.units.addAll([...army, fallen]);
      await settle(tester, b);
      final k = b.townK, lane = b.townLane;
      var folk = b.townFolk;
      expect({for (final f in folk) f.unit}, {...own, ...army}, reason: 'the living army, its Hero too');
      // In the tent's opening (its floor, townTentStep) or the Tavern's doorway (the porch, townStep).
      final inside = {for (final f in b.townLife.folk) if (f.up) f.unit: f.floor};
      for (final f in folk.where((f) => f.feet != null)) {
        if (inside[f.unit] case final floor?) {
          expect(f.feet!.dy - lane, -floor * k, reason: 'inside: on its floor over the lane');
        } else {
          expect(f.feet!.dy - lane, inInclusiveRange(0, 4 * k), reason: 'on the lane, a little lower at most');
        }
        expect(f.feet!.dx, f.feet!.dx.roundToDouble(), reason: 'on whole screen px');
      }
      final xs = [for (final f in b.townLife.folk) f.x];
      await frames(tester, 120); // ~2 s
      expect([for (var i = 0; i < xs.length; i++) b.townLife.folk[i].x != xs[i]].contains(true), isTrue, reason: 'walking');
      expect(b.townLife.folk.every((f) => f.x >= townEdge && f.x <= b.townLife.width - townEdge), isTrue);

      // Paused: the life stands still; resumed, it goes on.
      g.paused = true;
      final t0 = b.townLife.t;
      await frames(tester, 30);
      expect(b.townLife.t, t0);
      g.paused = false;
      await frames(tester, 10);
      expect(b.townLife.t, greaterThan(t0));

      // No tap is a troop's: every troop stands on a building, a tap on one's body opens that building's page. From the
      // shut book (its page's place in the middle, the rest a pan away: the wheel brings the building in, decisions-log
      // 271): the Tavern opens its page, then the Smithy the Smithy's.
      Future<void> through(String place, String page) async {
        final building = b.townScene[place]!, mid = b.townCam + building.center.dx / k;
        for (final f in b.townLife.folk) {
          f
            ..doing = TownDo.stroll
            ..mate = null
            ..inside = false
            ..goal = double.nan
            ..until = double.infinity
            ..x = mid;
        }
        await frames(tester, 2);
        final feet = b.townFolk.first.feet!, body = feet - Offset(0, 10 * k * townFolkK);
        expect(building.contains(body), isTrue, reason: '$place: the troops stand over it');
        expect(b.bookPage != page || b.bookArea == Rect.zero, isTrue, reason: 'the tap has a page to turn or a book to open');
        await tester.tapAt(body);
        await frames(tester, 30);
        expect(b.bookPage, page, reason: '$place opened through the troops');
      }

      for (final (place, page) in [('tavern', 'tavern'), ('smithy', 'smithy')]) {
        await tester.tapAt(bare(b, size)); // the book shuts
        await frames(tester, 40);
        expect(b.bookArea, Rect.zero);
        await wheel(tester, bare(b, size), b.townScene[place]!.center.dx - size.width / 2);
        await through(place, page);
        expect(b.bookArea, isNot(Rect.zero), reason: 'the book opened on it');
      }

      // Leave, and the next Town starts afresh.
      await tester.tapAt(b.startButton.center);
      for (var i = 0; i < 120 && b.townShown; i++) {
        await frames(tester, 1);
      }
      expect(b.townShown, isFalse);
      final t1 = b.townLife.t;
      await frames(tester, 30);
      expect(b.townLife.t, t1, reason: 'no life on the field');
    });
  }

  testWidgets("the bubbles at 1266x713: a talk's over the speaker's head (its tail at the head), the roller's then the "
      "other's; the Tavern window's while one is inside, its tail on the window", (tester) async {
    final b = await boot(tester);
    b.autoStart.set(false);
    final dice = ScriptDice();
    b.townDice = dice;
    final g = await intoTown(tester, b);
    await settle(tester, b);
    final x = b.townLife.width / 2;
    double draw(double world) => (world - townEdge) / (b.townLife.width - 2 * townEdge);
    dice.queue.addAll([
      0, 0, 0, 0, 0, 0, // the depth and head start of each
      draw(x), 0.1, TownLife.drawFor(TownDo.stroll), draw(x + 4), // a strolls on
      draw(x + 30), 0.9, TownLife.drawFor(TownDo.talk), 0.9, // b talks with a, halfway
      draw(x + 200), 0.9, TownLife.drawFor(TownDo.tavern), // c goes into the Tavern
      0.99, // the talk's lines (its second one stands first): 6; then the fallback (every topic a heart, the Tavern 6 s)
    ]);
    final a = troop('knight'), bb = troop('priest'), c = troop('soldier');
    g.units
      ..removeWhere((u) => u.side == Side.troop) // the game's own first troop: out of the way of the scripted draws
      ..addAll([a, bb, c]);
    var saw = <String>{};
    var window = false;
    for (var i = 0; i < 1200 && (saw.length < 2 || !window); i++) {
      await frames(tester, 1);
      for (final f in b.townFolk) {
        if (f.bubble == Rect.zero) continue;
        expect(f.icon, 'heart'); // the fallback's topic: the first
        expect(f.thought, isFalse);
        final feet = f.feet!, k = b.townK;
        expect(f.bubble.size, Size(20 * k, 24 * k), reason: 'ui_all.png 20x24 at max(2, k)');
        expect(f.bubble.bottom, lessThan(feet.dy - 16 * k * townFolkK), reason: 'over the head');
        expect(f.bubble.bottom, greaterThan(feet.dy - 30 * k * townFolkK), reason: 'just over it');
        expect((f.bubble.left + townBubbleTip.dx * k - feet.dx).abs(), lessThan(6 * k * townFolkK), reason: 'its tail at the head');
        saw.add(f.unit == bb ? 'roller' : 'other');
      }
      if (b.townWindowBubble != Rect.zero) {
        window = true;
        final win = b.townBuilding('tavern').firstWhere((c) => c.$1 == 'winTL').$2;
        expect(b.townWindowBubble.left + townBubbleTip.dx * 2, closeTo(win.right, 1));
        expect(b.townWindowBubble.bottom, closeTo(win.top + 2 * b.townK, 1));
        expect(b.townLife.inTavern, 1);
        expect(b.townFolk.firstWhere((f) => f.unit == c).feet, isNull, reason: 'inside: not drawn');
      }
    }
    expect(saw, {'roller', 'other'});
    expect(window, isTrue);
  });

  // The heads as mapped from the idle strips (ui-hud.md "Bubbles", decisions-log 253): each type's own columns (first,
  // last) and crown row in its 100x100 frames, the weapon held beside it left out.
  const heads = {
    'soldier': (45, 54, 39),
    'knight': (41, 54, 39),
    'swordsman': (44, 55, 38),
    'archer': (45, 54, 40),
    'lancer': (43, 54, 27),
    'priest': (44, 55, 37),
    'armored_axeman': (45, 53, 38), // its axe's shaft 54-56 and blade to 62 beside it: not its head
    'wizard': (43, 54, 38),
    'knight_templar': (45, 54, 39),
  };
  test('every troop type has its head mapped, its tail in the middle of its columns', () {
    expect(townHeads.keys.toSet(), troopTypes.keys.toSet());
    for (final MapEntry(key: type, value: (l, r, crown)) in heads.entries) {
      expect(townHeads[type], Offset((l + r + 1) / 2, crown.toDouble()), reason: type);
    }
  });

  for (final size in const [Size(1266, 713), Size(915, 412)]) {
    final tag = '${size.width.round()}x${size.height.round()}';
    testWidgets("every troop type's talk bubble at $tag: its tail's tip over the middle of its head's own columns (the "
        'weapon beside it left out: an axeman\'s over its helmet, not its axe) and just over its crown', (tester) async {
      final b = await boot(tester, size);
      b.autoStart.set(false);
      final g = await intoTown(tester, b);
      await settle(tester, b);
      // Every type in five talking pairs across the view, the lancer twice: (soldier, knight), (swordsman, archer),
      // (lancer, priest), (armored_axeman, wizard), (knight_templar, lancer); the first line, then the second.
      final types = troopTypes.keys.toList(), units = [for (final t in [...types, 'lancer']) troop(t)];
      g.units
        ..removeWhere((u) => u.side == Side.troop)
        ..addAll(units);
      await frames(tester, 2);
      final life = b.townLife, k = b.townK, s = k * townFolkK, bk = max(2.0, k);
      final step = (size.width / k - 40) / (units.length ~/ 2);
      TownFolk folkOf(Unit u) => life.folk.firstWhere((f) => identical(f.unit, u));
      void talk(double since) {
        for (var p = 0; p < units.length ~/ 2; p++) {
          final x = b.townCam + 20 + step * (p + 0.5), a = folkOf(units[2 * p]), c = folkOf(units[2 * p + 1]);
          for (final (f, mate, at, dir) in [(a, c, x - townTalkGap / 2, 1), (c, a, x + townTalkGap / 2, -1)]) {
            f
              ..doing = TownDo.talk
              ..x = at
              ..goal = double.nan
              ..dir = dir
              ..inside = false
              ..thought = false
              ..mate = mate
              ..lead = identical(f, a)
              ..line = -1
              ..from = life.t - since
              ..until = life.t + 100;
          }
        }
      }

      final seen = <String>{};
      for (final since in [0.3, 1.9]) {
        talk(since);
        await frames(tester, 2);
        for (final f in b.townFolk) {
          if (f.bubble == Rect.zero) continue;
          final (l, r, crown) = heads[f.unit.type]!;
          final feet = f.feet!;
          final tip = Offset(f.bubble.left + townBubbleTip.dx * bk, f.bubble.bottom);
          final a = feet.dx + f.dir * (l - 50) * s, c = feet.dx + f.dir * (r + 1 - 50) * s;
          expect((tip.dx - (a + c) / 2).abs(), lessThanOrEqualTo((c - a).abs() / 4 + 1),
              reason: '${f.unit.type}: the tail at ${tip.dx} over the middle of its head, $a..$c');
          // Its soles on its line (decisions-log 292): its feet's last row 56, so its crown (57 - crown) sprite px over it.
          expect(tip.dy, closeTo(feet.dy - (57 - crown) * s - bk, 1.01), reason: '${f.unit.type}: just over its crown');
          seen.add(f.unit.type);
        }
      }
      expect(seen, types.toSet(), reason: 'every type spoke');
    });
  }
}
