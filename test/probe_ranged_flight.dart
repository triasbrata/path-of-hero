// Where the long range stand, and how long their shots fly (decisions-log 199, units-and-combat.md "Long range hold"):
// a probe, not part of the suite (no `_test.dart`). It plays whole waves and records every shot a shooter fires
// ([Game.shots]: arrows, orbs, a skeleton archer's bolts; a Hero's or a skill's special shots too, by their own speed)
// from the tick it is fired to the tick it lands, and samples twice a second where each shooter stands.
//
// What it plays (`--dart-define`s):
// - default: the owner's w89 save (the fixture), wave 90, with seeds `SEED_FROM`.. (`SEEDS`, default 3);
// - `STATES=<dir> WAVES=30,60`: saved between-wave states `<dir>/s<seed>-w<wave>.json` (the battle-cam dumps), each
//   seed and wave once.
// `VIEW_W` is the view's width (341: the Mac's 1266x713 window; 219: a 412x860 phone), `LABEL` names the lines.
//
// Lines, per shooter group (troop/monster, type, a Hero or the boss rank apart):
//   F label group n fire(px) med p90 | flight(s) med p90 | lost n   (fire: shooter to target when fired; lost: its
//                                                                     target fell before it landed)
//   P label group n centre(tiles) med p90 | target/reach med p90 | target(px) med p90 | screen med p10
//     (centre: |x - the fight's centre| in contact, [Game.meetX]; target: to its nearest foe; screen: its x across the
//      view, 0 the left edge)
//   S label group state n fire(px) med p90 | flight(s) med p90   (state when fired: stand, up (walking toward its
//                                                                   target), away (backing off), back (falling back)
//   W label seed wave secs fell livesLost flag marches (each march's cause and its time; `MAX_SECS` caps a wave, 300)
// It never touches the real save (flutter_test_config.dart's temp dir).
// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';

const _fixture = 'test/fixtures/save-20261002-2222-w89-sellbug.json';
const label = String.fromEnvironment('LABEL', defaultValue: 'x');
const statesDir = String.fromEnvironment('STATES');
const wavesArg = String.fromEnvironment('WAVES', defaultValue: '90');
const seedFrom = int.fromEnvironment('SEED_FROM', defaultValue: 1);
const seedCount = int.fromEnvironment('SEEDS', defaultValue: 3);
const viewW = int.fromEnvironment('VIEW_W', defaultValue: 341);
const maxSecs = int.fromEnvironment('MAX_SECS', defaultValue: 300);
const dt = 1 / 30;

class _Fly {
  final String group, state;
  final double fired, fireD;
  final double speed;
  int ticks = 0;
  double rem;
  _Fly(this.group, this.state, this.fired, this.fireD, this.speed, this.rem);
}

String _group(Unit u) {
  final who = u.side == Side.troop ? 'troop' : 'foe';
  final rank = u.side == Side.troop ? (u.hero ? '+hero' : '') : (u.tier == Tier.miniBoss || u.tier == Tier.boss ? '+boss' : '');
  return '$who:${u.type}$rank';
}

double _q(List<double> xs, double q) {
  if (xs.isEmpty) return double.nan;
  final s = [...xs]..sort();
  return s[min(s.length - 1, (q * (s.length - 1)).round())];
}

String _f(double v, [int d = 2]) => v.isNaN ? '-' : v.toStringAsFixed(d);

void main() {
  test('ranged flight', () {
    final fire = <String, List<double>>{}, flight = <String, List<double>>{}, lost = <String, int>{};
    final byState = <String, List<double>>{}, fireByState = <String, List<double>>{};
    final centre = <String, List<double>>{}, ratio = <String, List<double>>{}, near = <String, List<double>>{};
    final screen = <String, List<double>>{};
    final waves = [for (final w in wavesArg.split(',')) int.parse(w.trim())];
    for (var seed = seedFrom; seed < seedFrom + seedCount; seed++) {
      for (final wave in waves) {
        final path = statesDir.isEmpty ? _fixture : '$statesDir/s$seed-w$wave.json';
        final f = File(path);
        if (!f.existsSync()) continue;
        final save = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
        final k = statesDir.isEmpty ? seed : seed * 1000 + wave * 10;
        final g = Game.fromJson(save, Random(k), Random(k + 100), Random(k + 300))
          ..loot = Random(k + 200)
          ..slots = Random(k + 400);
        for (var i = 0; i < 30 * 10; i++) {
          g.viewW = viewW.toDouble();
          g.tick(dt);
        }
        final lives = g.lives, fell0 = g.fallen.length;
        final marches = <String>[], t0 = g.t;
        g.listeners.add((e) {
          if (e is Marched) marches.add('${e.why.name}@${(e.t - t0).toStringAsFixed(0)}');
        });
        g.startWave();
        final flying = <Shot, _Fly>{};
        var t = 0.0, sampleAt = 0.0;
        while (g.waveActive && !g.over && t < maxSecs) {
          g.viewW = viewW.toDouble();
          for (final MapEntry(key: s, value: r) in flying.entries) {
            r.rem = s.target.alive ? s.pos.distanceTo(s.target.pos) : -1;
          }
          g.tick(dt);
          t += dt;
          final now = g.shots.toSet();
          for (final MapEntry(key: s, value: r) in flying.entries.toList()) {
            if (now.contains(s)) {
              r.ticks++;
              continue;
            }
            flying.remove(s);
            // Landed: it was within a step (and the target's own step) of its target; else its target fell first.
            if (r.rem >= 0 && r.rem <= r.speed * dt + 4) {
              (fire[r.group] ??= []).add(r.fireD);
              (flight[r.group] ??= []).add((r.ticks + 1) * dt);
              (byState['${r.group} ${r.state}'] ??= []).add((r.ticks + 1) * dt);
              (fireByState['${r.group} ${r.state}'] ??= []).add(r.fireD);
            } else {
              lost[r.group] = (lost[r.group] ?? 0) + 1;
            }
          }
          for (final s in now) {
            if (flying.containsKey(s)) continue;
            final speed = s.speed ?? s.from.stats.shotSpeed;
            final u = s.from;
            final state = u.retreating ? 'back' : (u.moving ? (u.dir * (s.target.pos.x - u.pos.x) > 0 && u.heading.x * (s.target.pos.x - u.pos.x) > 0 ? 'up' : 'away') : 'stand');
            flying[s] = _Fly(_group(s.from), state, t, s.from.pos.distanceTo(s.target.pos), speed, s.pos.distanceTo(s.target.pos));
          }
          if (t >= sampleAt) {
            sampleAt += 0.5;
            final mid = g.meetX;
            for (final u in g.units) {
              if (!u.alive || u.stats.shotSpeed <= 0 || (u.side == Side.troop && !u.entered)) continue;
              if (u.side == Side.enemy && u.pos.x > g.cam + g.viewW) continue; // not on screen yet
              Unit? foe;
              var d = double.infinity;
              for (final o in g.units) {
                if (o.side == u.side || !o.alive) continue;
                final e = o.pos.distanceTo(u.pos);
                if (e < d) (foe, d) = (o, e);
              }
              if (foe == null) continue;
              final grp = _group(u);
              (ratio[grp] ??= []).add(d / u.stats.range);
              (near[grp] ??= []).add(d);
              (screen[grp] ??= []).add((u.pos.x - g.cam) / g.viewW);
              if (mid != null && g.meetMode == MeetMode.contact) (centre[grp] ??= []).add((u.pos.x - mid).abs() / tile);
            }
          }
        }
        final flag = g.over ? 'OVER' : (g.waveActive ? 'STALL' : 'ok');
        print('W $label $seed ${g.wave} ${t.toStringAsFixed(1)} ${g.fallen.length - fell0} ${lives - g.lives} $flag ${marches.join(',')}');
      }
    }
    final groups = {...fire.keys, ...centre.keys, ...ratio.keys, ...lost.keys}.toList()..sort();
    for (final grp in groups) {
      final fi = fire[grp] ?? [], fl = flight[grp] ?? [];
      print('F $label $grp n ${fi.length} fire ${_f(_q(fi, .5), 0)} ${_f(_q(fi, .9), 0)} | flight ${_f(_q(fl, .5))} '
          '${_f(_q(fl, .9))} | lost ${lost[grp] ?? 0}');
      final c = centre[grp] ?? [], r = ratio[grp] ?? [], n = near[grp] ?? [], sc = screen[grp] ?? [];
      print('P $label $grp n ${r.length} centre ${_f(_q(c, .5), 1)} ${_f(_q(c, .9), 1)} | target/reach ${_f(_q(r, .5))} '
          '${_f(_q(r, .9))} | target ${_f(_q(n, .5), 0)} ${_f(_q(n, .9), 0)} | screen ${_f(_q(sc, .5))} ${_f(_q(sc, .1))}');
    }
    for (final k in byState.keys.toList()..sort()) {
      final fl = byState[k]!, fi = fireByState[k]!;
      print('S $label $k n ${fl.length} fire ${_f(_q(fi, .5), 0)} ${_f(_q(fi, .9), 0)} | flight ${_f(_q(fl, .5))} ${_f(_q(fl, .9))}');
    }
  });
}
