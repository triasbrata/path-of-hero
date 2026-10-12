// The hit-source tag (catalog step 0f, decisions-log 182; docs/units-and-combat.md "Damage"): every blow names where it
// comes from, [Hit]. A static scan of lib/: every `_hurt(...)` call carries a tag as its third argument, every `Shot(...)`
// and `_holyHurt(...)` one too, and the blows that aren't a skill's are exactly the sites below (a new one is a choice,
// made here). The tag changes nothing yet: the w89 identity probe (test/probe_pusaka_w89_identity.dart) is the same.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';

/// One call of a function in lib/: its file, line and top-level arguments.
typedef Call = ({String file, int line, List<String> args});

final _tags = {for (final h in Hit.values) 'Hit.${h.name}'};

/// Every call of [name] in lib/'s Dart files: not a declaration (`double _hurt(`, the constructor `Shot(this.from`),
/// nor in a `//` comment, nor a longer name ending in it (`LineShot(`).
List<Call> calls(String name) {
  final out = <Call>[];
  final files = Directory('lib').listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart')).toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  for (final f in files) {
    final code = f.readAsStringSync();
    for (var at = code.indexOf('$name('); at >= 0; at = code.indexOf('$name(', at + 1)) {
      final lineStart = code.lastIndexOf('\n', at) + 1, before = code.substring(lineStart, at);
      if (before.contains('//')) continue; // a comment
      if (at > 0 && RegExp(r'[\w.$]').hasMatch(code[at - 1])) continue; // another name
      if (RegExp(r'\b(double|void|bool|int|List<\w+>)\s+$').hasMatch(before)) continue; // its declaration
      final args = _args(code, at + name.length);
      if (args.firstOrNull?.startsWith('this.') ?? false) continue; // a constructor
      out.add((file: f.path, line: '\n'.allMatches(code.substring(0, at)).length + 1, args: args));
    }
  }
  return out;
}

/// The top-level arguments of the call whose `(` is at [open] in [code]: split at the commas outside brackets, strings
/// and `//` comments, each trimmed.
List<String> _args(String code, int open) {
  final args = <String>[];
  var depth = 0, from = open + 1;
  String? quote;
  for (var i = open; i < code.length; i++) {
    final c = code[i];
    if (quote != null) {
      if (c == '\\') {
        i++;
      } else if (c == quote) {
        quote = null;
      }
      continue;
    }
    if (c == '/' && code.startsWith('//', i)) {
      i = code.indexOf('\n', i); // a comment to the line's end
    } else if (c == "'" || c == '"') {
      quote = c;
    } else if ('([{'.contains(c)) {
      depth++;
    } else if (')]}'.contains(c)) {
      if (--depth == 0) {
        final last = code.substring(from, i).trim();
        if (last.isNotEmpty) args.add(last);
        return args;
      }
    } else if (c == ',' && depth == 1) {
      args.add(code.substring(from, i).trim());
      from = i + 1;
    }
  }
  fail('no closing bracket for the call at $open');
}

/// Whether [arg] is a tag: a [Hit] value, the blow's own `src` passed on, or a choice between those.
bool isTag(String arg) {
  if (arg == 'src' || arg == 's.src') return true;
  final named = RegExp(r'Hit\.\w+').allMatches(arg).map((m) => m[0]!).toList();
  return named.isNotEmpty && named.every(_tags.contains);
}

void main() {
  test('every _hurt call carries a tag: its third argument names a Hit (or passes its blow\'s own on)', () {
    final hurts = calls('_hurt');
    expect(hurts.length, greaterThanOrEqualTo(35), reason: 'the scan found the calls');
    for (final c in hurts) {
      expect(c.args.length, inInclusiveRange(3, 5), reason: '${c.file}:${c.line} ${c.args}');
      expect(isTag(c.args[2]), isTrue, reason: '${c.file}:${c.line}: "${c.args[2]}" is no tag');
    }
  });

  test('every shot and holy blow carries one too: Shot(from, target, pos, tag, ...), _holyHurt(o, dmg, by, tag)', () {
    final shots = calls('Shot'), holy = calls('_holyHurt');
    expect(shots.length, greaterThanOrEqualTo(4));
    expect(holy.length, greaterThanOrEqualTo(3));
    for (final c in shots) {
      expect(isTag(c.args[3]), isTrue, reason: '${c.file}:${c.line}: "${c.args[3]}"');
    }
    for (final c in holy) {
      expect(isTag(c.args[3]), isTrue, reason: '${c.file}:${c.line}: "${c.args[3]}"');
    }
    expect([for (final c in holy) c.args[3]], unorderedEquals(['Hit.smite', 'Hit.skill', 'Hit.skill']),
        reason: "the healer's smite, Holy Nova and Judgement");
  });

  test('the blows that are not a skill\'s are exactly these: a normal attack, its splash past the target, the smite (a '
      "healer's, Wrath Psalm's), a leap, a burst, what is sent back, a bleed, a relic's own blow", () {
    final other = [
      for (final c in calls('_hurt'))
        if (c.args[2] != 'Hit.skill') '${c.file.split('/').last}: ${c.args[0]} ${c.args[2]}',
    ];
    expect(other, unorderedEquals([
      // A normal blow and its splash past the target (_strike), a shot landing on its target or the unit on the spot
      // its target went from (its own tag; a normal shot's splash past it extra), the necromancer's scythe.
      'game.dart: o o == foe ? Hit.normal : Hit.extra',
      'game.dart: foe Hit.normal',
      'game.dart: o o == on || s.src != Hit.normal ? s.src : Hit.extra',
      'game.dart: on s.src',
      'game.dart: near Hit.normal',
      // Sent back: worn thorns, a reflect, a Parry's answer, a Bayangan's Thorns, Riposte's (a `hurtBy` burst); and the
      // Bayangan Toll's share of a killer troop's HP, a blow from no one like Thorns'.
      'game.dart: by Hit.hitBack',
      'hero_skills.dart: by Hit.hitBack',
      'hero_skills.dart: by Hit.hitBack',
      'omen.dart: by Hit.hitBack',
      'omen.dart: by Hit.hitBack',
      'pusaka_engine.dart: by Hit.hitBack',
      // A bleed's tick (Venom's poison too: relics.dart puts a bleed on, decisions-log 227); a linked ally's share keeps
      // the blow's own source; the holy blow passes its own on.
      'hero_skills.dart: u Hit.bleed',
      'hero_skills.dart: e.by! src',
      'monster_skill_signatures.dart: o src',
      // God's Thunder's leap; Shatter Shard's burst on the monsters near the target (`_burst`); the Bayangan Bile Sacs'
      // burst on the troops next to a slime that dies, and Side Swing's share of a melee monster's blow on the troop next
      // to the one it hit (from no one, so it never swings on).
      'pusaka_engine.dart: o Hit.extra',
      'pusaka_engine.dart: o Hit.extra',
      'omen.dart: o Hit.extra',
      'omen.dart: next Hit.extra',
      // Wrath Psalm's smite on the monsters next to the troop a healer of its type healed: holy light, a healer's.
      'pusaka_engine.dart: m Hit.smite',
      // A small relic's own blow: Sweep's on the monster next to the target (relics.dart, decisions-log 227); never a
      // normal hit, so it never sweeps or poisons again.
      'relics.dart: next Hit.relic',
    ]));
    expect([for (final c in calls('Shot')) c.args[3]], unorderedEquals(['Hit.normal', 'Hit.skill', 'Hit.skill', 'Hit.skill']),
        reason: "a fighter's shot; Arrow Rain's, Arcane Blast's and a monster's Volley are skills' (Shot.special: always)");
  });
}
