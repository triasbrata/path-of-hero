import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/cut_ins.dart';
import 'package:tower_defense/settings.dart';

// A Hero's cast cut-in (#51): the queue of what shows when (lib/cut_ins.dart), and its setting. How it
// looks is lib/hero_cast.dart (the probes' shots). The same queue holds a monster champion's skill banners, with
// their own time, line and gate (FoeCutGate); how those look and what feeds them: test/foe_cut_in_test.dart.

/// Casts as (Hero, which cast), the same Hero merging.
CutIns<(String, int)> queue() => CutIns(key: (c) => c.$1);

void main() {
  test('a cut-in shows at once for cutInTime, then the next one waiting, then none', () {
    final q = queue()..add(('ana', 1), 10);
    expect((q.showing, q.since), (('ana', 1), 10.0));
    q.add(('budi', 1), 10.2);
    expect(q.waiting, [('budi', 1)]);
    q.tick(10 + cutInTime - 0.01);
    expect(q.showing, ('ana', 1)); // not yet
    q.tick(10 + cutInTime);
    expect((q.showing, q.since, q.waiting.isEmpty), (('budi', 1), 10 + cutInTime, true));
    q.tick(10 + 2 * cutInTime);
    expect(q.showing, isNull);
    q.add(('cici', 1), 30);
    expect((q.showing, q.since), (('cici', 1), 30.0)); // at once again
  });

  test('at most cutInWaiting wait: one more drops the oldest waiting, never the one showing', () {
    final q = queue()..add(('a', 1), 0);
    for (final h in ['b', 'c', 'd', 'e']) {
      q.add((h, 1), 0.1);
    }
    expect(cutInWaiting, 3);
    expect(q.showing, ('a', 1));
    expect(q.waiting, [('c', 1), ('d', 1), ('e', 1)]);
  });

  test('a Hero casting again while its cut-in waits takes its place; its own showing one runs its time', () {
    final q = queue()
      ..add(('a', 1), 0)
      ..add(('b', 1), 0.1)
      ..add(('c', 1), 0.2)
      ..add(('b', 2), 0.3); // b again: in b's place, not at the back
    expect(q.waiting, [('b', 2), ('c', 1)]);
    q.add(('a', 2), 0.4); // a again while its own shows: it waits like any other
    expect(q.showing, ('a', 1));
    expect(q.waiting, [('b', 2), ('c', 1), ('a', 2)]);
    q.tick(0.5);
    expect(q.showing, ('a', 1));
  });

  test('progress runs from 0 to 1 over cutInTime; clear drops the one showing and those waiting', () {
    final q = queue();
    expect(q.progress(5), isNull);
    q
      ..add(('a', 1), 5)
      ..add(('b', 1), 5);
    expect((q.progress(5), q.progress(5 + cutInTime / 2), q.progress(5 + 2 * cutInTime)), (0.0, 0.5, 1.0));
    q.clear();
    expect((q.showing, q.waiting.isEmpty, q.progress(5)), (null, true, null));
  });

  test('settings.json keeps whether a Hero\'s cast shows its cut-in; on when missing or broken', () {
    final dir = Directory.systemTemp.createTempSync('td_cutins'), file = File('${dir.path}/settings.json');
    addTearDown(() => dir.deleteSync(recursive: true));
    expect(loadSettings(file).heroCutIns, isTrue); // no file
    saveSettings(Settings(heroCutIns: false), file);
    expect(loadSettings(file).heroCutIns, isFalse);
    for (final text in ['{"music": 50}', '{"heroCutIns": "no"}', 'not json']) {
      file.writeAsStringSync(text);
      expect(loadSettings(file).heroCutIns, isTrue, reason: text);
    }
  });

  test('a queue with its own time and line: front ones go before the plain ones waiting, in the order they came', () {
    // Casts as (skill, front); a front one is a mini boss's banner.
    final q = CutIns<(String, bool)>(key: (c) => c.$1, time: foeCutTime, most: foeCutWaiting, front: (c) => c.$2)
      ..add(('a', false), 0)
      ..add(('b', false), 0.1)
      ..add(('M', true), 0.2);
    expect(q.showing, ('a', false)); // the one showing runs on
    expect(q.waiting, [('M', true), ('b', false)]);
    q.add(('N', true), 0.3); // after the front one already waiting; the oldest plain one drops for it
    expect(q.waiting, [('M', true), ('N', true)]);
    q.add(('c', false), 0.4); // a plain one past the line drops itself: every one waiting is front
    expect(q.waiting, [('M', true), ('N', true)]);
    q.tick(foeCutTime - 0.01);
    expect(q.showing, ('a', false)); // foeCutTime, not cutInTime
    q.tick(foeCutTime);
    expect((q.showing, q.since), (('M', true), foeCutTime));
    expect(q.progress(foeCutTime * 1.5), closeTo(0.5, 1e-9));
  });

  test('a queue without a front flag keeps the old line: the oldest waiting drops', () {
    final q = CutIns<(String, int)>(key: (c) => c.$1, most: 2)
      ..add(('a', 1), 0)
      ..add(('b', 1), 0)
      ..add(('c', 1), 0)
      ..add(('d', 1), 0);
    expect(q.time, cutInTime);
    expect(q.waiting, [('c', 1), ('d', 1)]);
  });

  test('a foe\'s banner: once per key a wave; a high elite\'s at most foeCutPerWave a wave and foeCutGap apart', () {
    final gate = FoeCutGate();
    expect((foeCutTime, foeCutWaiting, foeCutPerWave, foeCutGap), (1.4, 2, 4, 4.0));
    bool elite(Object key, double now, [int wave = 7]) => gate.admit(key, big: false, wave: wave, now: now);
    expect(elite('volley', 10), isTrue);
    expect(elite('volley', 30), isFalse); // that key again this wave
    expect(elite('maul', 10 + foeCutGap - 0.01), isFalse); // too soon after the last one; it stays unseen
    expect(elite('maul', 10 + foeCutGap), isTrue); // so a later cast of it shows
    expect(elite('swoop', 20), isTrue);
    expect(elite('pounce', 30), isTrue);
    expect(gate.shownIn(7), foeCutPerWave);
    expect(elite('trample', 60), isFalse); // the wave's four are out
    // A mini boss's or the boss's: always (each key once), whatever the high elites took.
    expect(gate.admit('headbutt', big: true, wave: 7, now: 60), isTrue);
    expect(gate.admit('roar', big: true, wave: 7, now: 60), isTrue);
    expect(gate.admit('headbutt', big: true, wave: 7, now: 90), isFalse);
    expect(gate.shownIn(7), foeCutPerWave); // they don't count against the cap
    // The next wave starts afresh: the cap, the gap and the keys.
    expect((gate.shownIn(8), elite('volley', 61, 8), elite('trample', 61, 8)), (0, true, false));
    expect(gate.admit('headbutt', big: true, wave: 8, now: 61), isTrue);
    gate.clear(); // another game came in
    expect((gate.shownIn(8), elite('volley', 62, 8)), (0, true));
  });

  test('settings.json keeps whether a foe champion\'s skill shows its banner; on when missing or broken', () {
    final dir = Directory.systemTemp.createTempSync('td_foecuts'), file = File('${dir.path}/settings.json');
    addTearDown(() => dir.deleteSync(recursive: true));
    expect((Settings().foeCutIns, loadSettings(file).foeCutIns), (true, true)); // no file
    saveSettings(Settings(foeCutIns: false), file);
    expect((loadSettings(file).foeCutIns, loadSettings(file).heroCutIns), (false, true)); // the Heroes' stays on
    saveSettings(Settings(heroCutIns: false), file);
    expect((loadSettings(file).foeCutIns, loadSettings(file).heroCutIns), (true, false));
    for (final text in ['{"music": 50}', '{"foeCutIns": "no"}', '{"foeCutIns": null}', 'not json']) {
      file.writeAsStringSync(text);
      expect(loadSettings(file).foeCutIns, isTrue, reason: text);
    }
  });

  test('HeroCutGate (decisions-log 298): a Hero\'s cut-in at most every heroCutEvery s, none within heroCutGap s of another', () {
    expect((heroCutEvery, heroCutGap), (20.0, 3.0));
    final gate = HeroCutGate();
    expect(gate.admit('ana', 0), isTrue);
    expect(gate.admit('budi', 2.9), isFalse); // too soon after ana's
    expect(gate.admit('budi', 3), isTrue);
    expect(gate.admit('ana', 10), isFalse); // ana's own: not yet 20 s
    expect(gate.admit('ana', 20), isTrue);
    expect(gate.admit('cici', 22), isFalse); // ana's 2 s ago
    gate.clear();
    expect(gate.admit('ana', 21), isTrue); // a new game: afresh
  });

  test('FirstCasts (decisions-log 298): a skill\'s name pops on its caster\'s first cast of a wave only', () {
    final names = FirstCasts();
    expect([names.first(('ana', 'troop'), 1), names.first(('ana', 'troop'), 1), names.first(('ana', 'hero'), 1), names.first(('budi', 'troop'), 1)],
        [true, false, true, true]);
    expect(names.first(('ana', 'troop'), 2), isTrue); // a new wave
    expect(names.first(('ana', 'troop'), 2), isFalse);
    names.clear();
    expect(names.first(('ana', 'troop'), 2), isTrue);
  });
}
