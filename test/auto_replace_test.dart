// Auto, replace the fallen (decisions-log 283; lib/auto_replace.dart; docs/ui-hud.md "Spawn bar"): off by default and
// then nothing changes; on, each troop that falls (not a Hero) is bought back, its type, through a buy's own rules, in the
// order they fell: mid-wave the queue's head waits for the gold and holds those behind it, one refused for anything else
// is skipped; at the win "Replace fallen"'s list leaves out those Auto bought back; between waves Auto works through
// that list, each back to its old spot; at the next wave's start what is left goes into the queue; the save keeps it
// (its key only while on). The spawn bar's button and tooltip: spawn_bar_test.dart.
import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';

import 'hero_skill_helpers.dart';
import 'recall_test.dart' show idle, strike;

/// A game without the free healer, a 6-column zone, gold to spare and the skills off (a cast could guard a troop or move
/// it off).
Game calm() => bareGame()
  ..skills = false
  ..heroSkills = false
  ..awakenSkills = false;

/// The next wave begun with nothing to spawn, an orc at the field's far end that never acts on its own keeping it going.
void begin(Game g) {
  g
    ..startWave()
    ..queue.clear();
  foeAt(g, 'orc', const Point(cols * tile - 8, tile * 1.5));
}

/// [u] (at 1 HP) falls to an orc next to it, now.
void fell(Game g, Unit u) {
  u.hp = 1;
  final orc = foeAt(g, 'orc', u.pos + const Point(12, 0));
  for (var i = 0; i < 10 && u.alive; i++) {
    strike(g, [orc]);
  }
  expect(u.alive, isFalse, reason: '${u.type} fell');
  orc.gone = true;
}

/// How many [type] troops live.
int alive(Game g, String type) => g.troops.where((u) => u.alive && u.type == type).length;

void main() {
  test('off by default: a troop that falls is not bought back, mid-wave or after; the save has no key', () {
    final g = calm();
    final k = idle(g, 'knight', 1, 1);
    idle(g, 'soldier', 1, 3);
    expect(g.autoReplace, isFalse);
    expect(g.toJson().containsKey('autoReplace'), isFalse);
    begin(g);
    final gold = g.gold;
    fell(g, k);
    for (var i = 0; i < 5; i++) {
      g.tick(0.05);
    }
    expect((alive(g, 'knight'), g.gold), (0, gold), reason: 'nothing bought');
  });

  test('on: the fallen bought back mid-wave, each its type, for its price, onto the field (autoPlace), in the order they '
      'fell: the head waits for the gold and holds those behind it', () {
    final g = calm();
    final k = idle(g, 'knight', 1, 1), s = idle(g, 'soldier', 1, 3);
    idle(g, 'archer', 0, 5); // left standing
    g.setAutoReplace(true);
    begin(g);
    g.gold = 0;
    fell(g, k); // first the knight (50), then the soldier (30)
    fell(g, s);
    final (pk, ps) = (g.priceOf('knight'), g.priceOf('soldier'));
    expect(pk, greaterThan(ps));
    expect((alive(g, 'knight'), alive(g, 'soldier')), (0, 0));
    // The soldier's price: the knight, first, still waits, and the soldier behind it.
    g.gold = ps;
    g.tick(0.05);
    expect((alive(g, 'knight'), alive(g, 'soldier'), g.gold), (0, 0, ps), reason: 'the head waits, holding the rest');
    // The knight's: it comes back, the soldier still waits.
    g.gold = pk;
    g.tick(0.05);
    expect((alive(g, 'knight'), alive(g, 'soldier'), g.gold), (1, 0, 0), reason: 'the knight back, first');
    final back = g.troops.lastWhere((u) => u.type == 'knight');
    final (c, r) = ((back.post.x / tile).floor(), (back.post.y / tile).floor());
    expect(g.inZone(c, r), isTrue, reason: 'sent to a cell of the zone');
    g.gold = ps;
    g.tick(0.05);
    expect((alive(g, 'soldier'), g.gold, g.waveActive), (1, 0, true), reason: 'then the soldier, mid-wave');
  });

  test('on: one refused for more than the gold (no room) is skipped, saying nothing; a Hero is never bought back', () {
    final g = calm();
    final k = idle(g, 'knight', 1, 1);
    final h = idle(g, 'soldier', 1, 3)..hero = true;
    idle(g, 'archer', 0, 5); // left standing
    g.setAutoReplace(true);
    begin(g);
    final cap = g.capacity;
    g.gold = 0;
    fell(g, k);
    g.capacity = g.armySize; // no room
    g.gold = 100000;
    expect(g.buyRefusal('knight'), isNot(buyRefusals.gold));
    final sfx = g.sfx.length;
    g.tick(0.05);
    expect(alive(g, 'knight'), 0, reason: 'refused: skipped');
    expect(g.sfx.skip(sfx), isNot(contains(Sfx.error)), reason: 'saying nothing');
    g.capacity = cap;
    g.tick(0.05);
    expect((alive(g, 'knight'), g.gold), (0, 100000), reason: 'skipped for good: room again buys nothing');
    fell(g, h);
    g.tick(0.05);
    expect((alive(g, 'soldier'), g.gold), (0, 100000), reason: 'a Hero is Recall\'s');
  });

  test('at the win the list leaves out those Auto bought back; between waves Auto works through it, each to its old spot, '
      'waiting for the gold; at the next wave\'s start what is left goes into the queue', () {
    final g = calm();
    final k = idle(g, 'knight', 1, 1), s = idle(g, 'soldier', 2, 3);
    idle(g, 'archer', 0, 5); // left standing
    g.setAutoReplace(true);
    begin(g);
    fell(g, k); // bought back at once (the gold covers it)
    expect(alive(g, 'knight'), 1);
    g.gold = 0;
    fell(g, s); // waits
    // Auto off for the win (its queue goes), so the list stays to look at.
    g.setAutoReplace(false);
    for (final e in g.enemies) {
      e.gone = true;
    }
    g.tick(0.05);
    expect((g.waveActive, g.over), (false, false), reason: 'won');
    expect(g.toReplace.map((f) => f.type), ['soldier'], reason: 'the knight Auto bought back is not offered again');
    final post = g.toReplace.single.post, cell = ((post.x / tile).floor(), (post.y / tile).floor());
    // On between waves: the gold short, it waits; then back to its old spot.
    g
      ..gold = 0
      ..setAutoReplace(true);
    g.tick(0.05);
    expect((alive(g, 'soldier'), g.toReplace.length), (0, 1), reason: 'waits for the gold');
    g.gold = g.priceOf('soldier');
    g.tick(0.05);
    expect((alive(g, 'soldier'), g.toReplace.isEmpty, g.gold), (1, true, 0), reason: 'bought back between waves');
    final again = g.troops.lastWhere((u) => u.type == 'soldier');
    expect(((again.post.x / tile).floor(), (again.post.y / tile).floor()), cell, reason: 'to its old spot');
    // Left on the list at a wave's start: into the queue, bought mid-wave once the gold covers it.
    g.toReplace.add((type: 'knight', post: Point(1 * tile + tile / 2, 4 * tile + tile / 2)));
    g.gold = 0;
    final knights = alive(g, 'knight');
    begin(g);
    expect(g.toReplace, isEmpty, reason: 'the list clears at the start');
    g.tick(0.05);
    expect(alive(g, 'knight'), knights, reason: 'waits for the gold');
    g.gold = g.priceOf('knight');
    g.tick(0.05);
    expect((alive(g, 'knight'), g.waveActive), (knights + 1, true), reason: 'carried into the wave, bought mid-wave');
  });

  test('a troop brought back (Resurrection) is not bought back as well: its entry leaves the queue (decisions-log 317)', () {
    final (g, h) = heroCaster(HeroSkill.revive);
    foeAt(g, 'orc', const Point(cols * tile - 8, tile * 1.5)); // keeps the wave on
    final s = idle(g, 'soldier', 4, 3)..hp = 1;
    g
      ..setAutoReplace(true)
      ..gold = 0; // Auto can't buy it yet: it waits in the queue
    final orc = foeAt(g, 'orc', s.pos + const Point(12, 0));
    strike(g, [orc]);
    expect(s.alive, isFalse);
    orc.gone = true;
    g.tick(0.05);
    expect((h.heroSkillAt, g.fallen.length, g.risen.length), (g.t, 0, 1), reason: 'the priest brought it back');
    g.gold = 10000;
    runFor(g, 1);
    expect((alive(g, 'soldier'), g.gold), (1, 10000), reason: 'the risen soldier alone: none bought');
  });

  test('the save keeps it: the key only while on, read back; off when a save lacks it', () {
    final g = Game()..setAutoReplace(true);
    final j = jsonDecode(jsonEncode(g.toJson())) as Map<String, dynamic>;
    expect(j['autoReplace'], isTrue);
    expect(Game.fromJson(j).autoReplace, isTrue);
    g.setAutoReplace(false);
    final off = jsonDecode(jsonEncode(g.toJson())) as Map<String, dynamic>;
    expect(off.containsKey('autoReplace'), isFalse);
    expect(Game.fromJson(off).autoReplace, isFalse);
    expect(Game.fromJson(j..remove('autoReplace')).autoReplace, isFalse, reason: 'a save from before it');
  });

  test('the tooltip: what it does, and whether it is on', () {
    final g = Game();
    expect(g.autoTip.$1, 'Auto Buy');
    expect(g.autoTip.$2, ['Auto Buy: replace fallen troops.', 'Off.']);
    g.setAutoReplace(true);
    expect(g.autoTip.$2, ['Auto Buy: replace fallen troops.', 'On: each one comes back as gold allows.']);
  });
}
