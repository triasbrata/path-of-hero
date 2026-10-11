import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flame/game.dart' hide Game;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';
import 'package:tower_defense/main.dart';

import 'hero_skill_helpers.dart';
import 'hud_font.dart';

// The wizard's magic (decisions-log 313, units-and-combat.md "The wizard's magic", lib/wizard_fx.dart): its plain shot
// is the Tiny RPG pack's fireball and Arcane Blast its ice star, each landing with its sheet's hit frames; an awakened
// wizard's are tinted its level's colour; Arcane Blast's cast strip glows blue.

/// Every item [type]'s awakening recipe asks for, [level] times over: the type at awakening [level].
List<Item> recipe(String type, int level) => [
      for (final MapEntry(key: item, value: n) in awakenRecipe[type]!.entries)
        for (var i = 0; i < n * level; i++) item,
    ];

/// A wave on with nothing to spawn, a wizard at cell (2, 3) and an orc 40 before it that never moves, strikes or falls.
/// [arcane]: the wizard casts Arcane Blast at once and never shoots plainly; else no skills, and it shoots at once.
(Game, Unit, Unit) duel({bool arcane = false}) {
  final g = bareGame(Random(1))
    ..heroSkills = false
    ..monsterSkills = false
    ..skills = arcane;
  final w = placeNow(g, 'wizard', 2, 3);
  g
    ..startWave()
    ..queue.clear();
  w
    ..cd = arcane ? hold : 0
    ..mp = arcane ? w.stats.mp.toDouble() : 0;
  final foe = foeAt(g, 'orc', w.pos + const Point(40.0, 0))
    ..hp = 1e6
    ..cd = hold
    ..busyUntil = double.negativeInfinity // drawn standing, not rising
    ..stunUntil = 1e9; // and never walking off
  return (g, w, foe);
}

/// Ticks [g] until its shots have all landed (at most 5 s).
void land(Game g) {
  for (var i = 0; i < 100 && g.shots.isNotEmpty; i++) {
    g.tick(0.05);
  }
  expect(g.shots, isEmpty);
}

Future<(TdGame, Board)> boot(WidgetTester tester) async {
  tester.view
    ..physicalSize = const Size(1600, 947)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await loadHudFont(tester);
  final game = TdGame();
  await tester.pumpWidget(GameWidget(game: game));
  for (var i = 0; i < 3000 && !game.isLoaded; i++) {
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 20)));
    await tester.pump();
  }
  expect(game.isLoaded, isTrue);
  return (
    game,
    game.board
      ..welcome = null
      ..miniMapOpen = false
  );
}

/// [img]'s pixels, RGBA.
Future<List<int>> rgba(WidgetTester tester, ui.Image img) async =>
    (await tester.runAsync(() => img.toByteData(format: ui.ImageByteFormat.rawRgba)))!.buffer.asUint8List();

void main() {
  test('a wizard\'s plain shot lands as the fireball and Arcane Blast\'s as the shards (an awakened one\'s with its level); '
      'every other shot keeps its hit_<type> burst', () {
    final (g, w, foe) = duel();
    g.tick(0.05);
    final shot = g.shots.single;
    expect((shot.from, shot.big, shotHitFx(shot)), (w, false, 'fireball'));
    land(g);
    expect(g.impacts.map((i) => i.$2), contains('fireball'));
    expect(g.impacts.map((i) => i.$2), isNot(contains('hit_wizard')));

    final (a, aw, _) = duel(arcane: true);
    a.tick(0.05);
    expect(aw.skillAt, a.t);
    expect((a.shots.single.big, shotHitFx(a.shots.single)), (true, 'shards'));
    land(a);
    expect(a.impacts.map((i) => i.$2), contains('shards'));
    expect(a.impacts.map((i) => i.$2), isNot(contains('hit_wizard_big')));

    final (h, _, _) = duel();
    h.upgrades['wizard'] = recipe('wizard', 2);
    expect(h.awakenLevel('wizard'), 2);
    h.tick(0.05);
    land(h);
    expect(h.impacts.map((i) => i.$2), contains('fireball_awake2'));

    // Any other shooter's, and a wizard's shot of another look (a Hero skill's), keep their type's hit.
    final archer = placeNow(g, 'archer', 2, 5);
    expect(shotHitFx(Shot(archer, foe, archer.pos, Hit.normal)), 'hit_archer');
    expect(shotHitFx(Shot(archer, foe, archer.pos, Hit.skill, null, null, true)), 'hit_archer_big');
    expect(shotHitFx(Shot.special(w, foe, w.pos, dmg: 1, speed: 100, look: ShotLook.ice)), 'hit_wizard');
    expect(shotHitFx(Shot.special(w, foe, w.pos, dmg: 1, speed: 100, look: ShotLook.ice, big: true)), 'hit_wizard_big');
    // The names are the sheets': the field draws them so.
    expect({for (final m in WizardMagic.values) m.name}, {'fireball', 'shards'});
    expect((WizardMagic.ofBurst('fireball'), WizardMagic.ofBurst('shards'), WizardMagic.ofBurst('hit_wizard')),
        (WizardMagic.fireball, WizardMagic.shards, null));
  });

  test('the sheets\' frames at the pack\'s 100 ms: the fireball flies on 0-3 over and over and lands on 4-6; the star '
      'flies on 2-5 and lands on 6-9 (its gathering shards, 0-1, unused); every frame on the 100 px grid', () {
    expect(magicFps, 10);
    const f = WizardMagic.fireball, s = WizardMagic.shards;
    expect((f.sheet, s.sheet), ('tiny_fx_wizard_fireball.png', 'tiny_fx_wizard_shards.png'));
    expect([for (var i = 0; i < 10; i++) f.flightFrame(i * 0.1 + 0.05)], [0, 1, 2, 3, 0, 1, 2, 3, 0, 1]);
    expect([for (var i = 0; i < 5; i++) f.hitFrame(i * 0.1 + 0.05)], [4, 5, 6, 6, 6]);
    expect(f.hitTime, closeTo(0.3, 1e-9));
    expect([for (var i = 0; i < 6; i++) s.flightFrame(i * 0.1 + 0.05)], [2, 3, 4, 5, 2, 3]);
    expect([for (var i = 0; i < 5; i++) s.hitFrame(i * 0.1 + 0.05)], [6, 7, 8, 9, 9]);
    expect(s.hitTime, closeTo(0.4, 1e-9));
    expect((f.flightFrame(0), s.flightFrame(0), f.flightFrame(-1)), (0, 2, 0));
    // The ball's middle on the shot, the star's 8 over it: neither reaches more than 8 under the shot (spawn_bar.dart's
    // stepLip).
    expect((f.anchor, s.anchor), (const Offset(55, 51), const Offset(53, 58)));
  });

  test('both sheets are in the manifest at 100 px frames with every frame the field plays, so the public repo\'s '
      'placeholders (drawn from it) have them too', () {
    final files = (jsonDecode(File('tool/asset_manifest.json').readAsStringSync())['files'] as List).cast<Map<String, dynamic>>();
    for (final m in WizardMagic.values) {
      final e = files.singleWhere((e) => e['path'] == 'assets/images/${m.sheet}', orElse: () => fail('${m.sheet} not in the manifest'));
      expect((e['kind'], e['height']), ('burst', 100), reason: m.name);
      expect(e['frame'], [100, 100], reason: m.name);
      expect(e['frames'] as int, greaterThan([...m.lead, ...m.loop, ...m.hit].reduce(max)), reason: m.name);
    }
    final f = files.singleWhere((e) => e['path'] == 'assets/images/tiny_fx_wizard_fireball.png');
    final s = files.singleWhere((e) => e['path'] == 'assets/images/tiny_fx_wizard_shards.png');
    expect((f['frames'], s['frames']), (7, 10));
  });

  testWidgets('drawn: the fireball in flight then its impact, Arcane Blast\'s star then its flash and streak, each gone '
      'after its last frame; an awakened wizard\'s in its level\'s tint (Bangkit 4 in 3\'s); a Hero\'s the same', (tester) async {
    final (_, b) = await boot(tester);

    /// What [g] draws of the wizard's magic over [n] frames of 16 ms: the flight frames and the hit frames seen, and
    /// the tints.
    Future<(Set<int>, Set<int>, Set<int>, Set<WizardMagic>)> watch(Game g, [int n = 60]) async {
      b.state = g;
      final flight = <int>{}, hits = <int>{}, tints = <int>{}, sheets = <WizardMagic>{};
      for (var i = 0; i < n; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        for (final (m, f, tint) in b.magicDrawn) {
          sheets.add(m);
          tints.add(tint);
          (m.hit.contains(f) ? hits : flight).add(f);
        }
      }
      expect(tester.takeException(), isNull);
      return (flight, hits, tints, sheets);
    }

    final (g, _, _) = duel();
    final (flight, hits, tints, sheets) = await watch(g);
    expect(sheets, {WizardMagic.fireball});
    expect(flight, containsAll([0, 1]));
    expect(flight.difference({0, 1, 2, 3}), isEmpty);
    expect(hits, {4, 5, 6});
    expect(tints, {0});
    expect(b.fieldBursts.where((x) => x.$2.startsWith('fireball')), isEmpty, reason: 'the impact is gone after its 0.3 s');

    final (a, _, _) = duel(arcane: true);
    final (aFlight, aHits, aTints, aSheets) = await watch(a);
    expect(aSheets, {WizardMagic.shards});
    expect(aFlight, contains(2));
    expect(aFlight.difference({2, 3, 4, 5}), isEmpty);
    expect(aHits, {6, 7, 8, 9});
    expect(aTints, {0});

    for (final (level, ascended, tint) in [(2, 0, 2), (3, 1, 3)]) {
      final (h, _, _) = duel();
      h.upgrades['wizard'] = recipe('wizard', level);
      if (ascended > 0) h.ascended['wizard'] = ascended;
      expect(h.awakenLevel('wizard'), level + ascended);
      final (hFlight, hHits, hTints, _) = await watch(h);
      expect(hFlight, isNotEmpty, reason: 'Awaken ${level + ascended}');
      expect(hHits, {4, 5, 6}, reason: 'Awaken ${level + ascended}');
      expect(hTints, {tint}, reason: 'Awaken ${level + ascended}');
    }

    final (hero, hw, _) = duel();
    hw.hero = true;
    final (_, heroHits, heroTints, heroSheets) = await watch(hero);
    expect(heroSheets, {WizardMagic.fireball});
    expect(heroHits, {4, 5, 6});
    expect(heroTints, {0});
  });

  testWidgets('the attack 2 strip (Arcane Blast\'s cast) glows in the star\'s blues: only its two oranges and their '
      'highlight change; the attack strip (the plain shot\'s) keeps its orange', (tester) async {
    final (game, _) = await boot(tester);
    const blue = {0xFFC9512E: 0xFF086EC7, 0xFFEF6E10: 0xFF43B4DF, 0xFFDB955A: 0xFF7DDDE1};
    final file = (await tester.runAsync(() async {
      final codec = await ui.instantiateImageCodec(File('assets/images/tiny_wizard_attack2.png').readAsBytesSync());
      return (await codec.getNextFrame()).image;
    }))!;
    final was = await rgba(tester, file), now = await rgba(tester, game.images.fromCache('tiny_wizard_attack2.png'));
    expect(now.length, was.length);
    int argb(List<int> px, int i) => px[i + 3] << 24 | px[i] << 16 | px[i + 1] << 8 | px[i + 2];
    var changed = 0;
    for (var i = 0; i < was.length; i += 4) {
      final from = argb(was, i), to = argb(now, i);
      if (was[i + 3] == 0) continue;
      expect(to, blue[from] ?? from, reason: 'pixel ${i ~/ 4}');
      if (blue.containsKey(from)) changed++;
    }
    expect(changed, greaterThan(100), reason: 'the glow is there to change');
    final attack = await rgba(tester, game.images.fromCache('tiny_wizard_attack.png'));
    expect([for (var i = 0; i < attack.length; i += 4) argb(attack, i)], contains(0xFFC9512E));
  }, tags: 'art'); // the pack's own colours: a placeholder strip has none of them
}
