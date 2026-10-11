// The item text (decisions-log 168, ui-hud.md "In-game text"): what an item, a small relic and a Pusaka say, in simple
// English from the rules' own numbers. Every tooltip: its lines in the HUD's font, no line twice, an oath's "Oath" once,
// and its frame no wider than 412 px (a phone held upright, until decisions-log 289; kept as the tooltips' most). No Indonesian word in it: test/english_text_test.dart reads every
// string in lib/.
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';
import 'package:tower_defense/hud_font.dart';

import 'hud_font.dart';

/// The owner's wave-86 save (a copy): five types with the five Epik bound by default, a Hero alive.
Game w86() => Game.fromJson(jsonDecode(File('test/fixtures/save-20261001-2005-pre-awaken.json').readAsStringSync()) as Map<String, dynamic>,
    Random(1), Random(2), Random(3))
  ..boardRules()
  ..chests.clear();

/// Every tooltip an item, a small relic or a Pusaka shows, by name: in the bag, over each troop row (an item), and
/// each Pusaka at each of its stars, bound, asleep, in the Vault and not owned; the oaths taken and waiting.
Map<String, (String, List<String>)> tooltips() {
  final out = <String, (String, List<String>)>{};
  final g = w86();
  for (final item in Item.values) {
    out['$item'] = g.itemInfo(item);
    for (final type in troopTypes.keys) {
      out['$item on $type'] = g.itemInfo(item, type);
    }
  }
  for (final r in Relic.values.where((r) => !r.pusaka)) {
    out['$r'] = g.relicInfo(r);
    out['$r, Towns on'] = (w86()..towns = true).relicInfo(r); // its tier and who it suits (decisions-log 227)
  }
  for (final r in Relic.values.where((r) => r.pusaka && !r.oath)) {
    final fresh = Game();
    out['$r not owned'] = fresh.relicInfo(r);
    for (var stars = 1; stars <= maxStars(r); stars++) {
      final bound = w86()..givePusaka(r, type: 'knight_templar', stars: stars);
      out['$r ★$stars on the templar'] = bound.relicInfo(r);
      out['$r ★$stars asleep'] = (w86()..givePusaka(r, type: 'soldier', stars: stars)).relicInfo(r);
      out['$r ★$stars in the Vault'] = (w86()..givePusaka(r, stars: stars)).relicInfo(r);
    }
  }
  out['alliance'] = (w86()..givePusaka(Relic.alliance)).relicInfo(Relic.alliance);
  out['oath of one, waiting'] = (w86()..givePusaka(Relic.oathOfOne)).relicInfo(Relic.oathOfOne);
  out['oath of one, at work'] = (Game()..boardRules()..givePusaka(Relic.oathOfOne)).relicInfo(Relic.oathOfOne);
  return out;
}

void main() {
  test('the item text: from the rules, no line twice, an oath says "Oath" once', () {
    final tips = tooltips();
    final font = fontChars();
    for (final MapEntry(key: name, value: (title, lines)) in tips.entries) {
      expect(lines, isNotEmpty, reason: name);
      expect(lines.toSet().length, lines.length, reason: '$name: a line twice: $lines');
      for (final l in [title, ...lines]) {
        expect([for (final c in l.replaceAll('★', '').runes) if (!font.contains(c)) String.fromCharCode(c)], isEmpty,
            reason: '$name: "$l" has a glyph the font lacks');
      }
      if (name.contains('oath') || name == 'alliance') {
        expect(lines.where((l) => l.contains('Oath')).length, 1, reason: '$name: $lines');
      }
    }
    // The example the owner's screenshot asked for: what it does, the live sum marked as now, its catch, where it is.
    expect(tips['alliance']!.$2, [
      'Oath: up to ${allianceK.most} types count',
      'Each type alive: +${(allianceK.perType * 100).round()}% HP and attack',
      'Now: 5 types, +25%',
      oathLine,
      'On: all troops ★1',
    ]);
    expect(tips['oath of one, waiting']!.$2.last, oathWaiting);
    expect(tips['oath of one, at work']!.$2, contains('Now: all troops, +${((oathOneK.k - 1) * 100).round()}%'));
    // Every number from the constants: a change of one shows.
    expect(tips['${Relic.ironBanner} ★3 on the templar']!.$2.first, '-${(ironBannerK[2] * 100).round()}% damage taken');
    expect(tips['${Relic.warDrum} ★2 on the templar']!.$2.first, 'x${warDrumK.hit[1]} damage every 3rd hit');
    expect(tips['${Relic.fury}']!.$2.first, 'x$furyHit damage every 3rd hit');
    expect(tips['${Relic.dragonHeart} ★1 asleep']!.$2, containsAll(['Asleep: no ${troopTypeNames['soldier']} alive', 'On: ${troopTypeNames['soldier']} ★1 (asleep)']));
    expect(tips['${Relic.dragonHeart} ★1 in the Vault']!.$2.last, 'In ${Words.vault} ★1');
    expect(tips['${Relic.dragonHeart} not owned']!.$2.last, 'Not owned yet');
  });

  testWidgets('every item tooltip is narrow: its frame no wider than 412 px less the 4 px margins', (tester) async {
    await loadHudFont(tester);
    double width(String s, double size, {bool bold = false}) =>
        (TextPainter(text: TextSpan(text: s, style: hudStyle(size, bold: bold)), textDirection: TextDirection.ltr)..layout()).width;
    // tooltip.dart: the title 18 bold after a 24 px icon and 6 px, the lines 14; the frame's insets 11 a side; a '★' is
    // drawn as an icon about as wide as a digit.
    const inset = 11.0, room = 412.0 - 2 * 4;
    var widest = ('', 0.0);
    for (final MapEntry(key: name, value: (title, lines)) in tooltips().entries) {
      final w = [24 + 6 + width(title, 18, bold: true), for (final l in lines) width(l.replaceAll('★', '0'), 14)].reduce(max) + 2 * inset;
      if (w > widest.$2) widest = (name, w);
      expect(w, lessThanOrEqualTo(room), reason: '$name: $w px');
    }
    // ignore: avoid_print
    print('widest item tooltip: ${widest.$1}, ${widest.$2.round()} px');
  });
}
