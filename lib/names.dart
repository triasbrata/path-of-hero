import 'dart:math';

// Every troop's own name: a first and a last name ([troopName]). Short, fantasy, plain ASCII letters
// (the old pixel font had no accents; the game's font has them, but saved names stay as they are). 48 × 48 = 2304 names, far more than a full zone of troops. The wave's
// mini boss and boss get one of [bossNames] ([bossName]).

const firstNames = [
  'Aldo', 'Arlo', 'Bram', 'Brin', 'Cade', 'Cora', 'Dain', 'Dara', 'Edda', 'Elin', 'Finn', 'Fara', //
  'Garr', 'Gwen', 'Hugo', 'Hera', 'Ivor', 'Isla', 'Jory', 'Juna', 'Kael', 'Kira', 'Lars', 'Lina', //
  'Mael', 'Mira', 'Nils', 'Nora', 'Odo', 'Orla', 'Piet', 'Pia', 'Quin', 'Rhea', 'Rolf', 'Runa', //
  'Sten', 'Sela', 'Tove', 'Tarn', 'Ulf', 'Una', 'Vale', 'Vera', 'Wynn', 'Wren', 'Yuri', 'Zora', //
];

const lastNames = [
  'Ash', 'Birch', 'Brand', 'Briar', 'Crag', 'Crow', 'Dale', 'Drake', 'Dunn', 'Ember', 'Fell', 'Flint', //
  'Frost', 'Glen', 'Grey', 'Hale', 'Hart', 'Hawk', 'Holt', 'Iron', 'Kest', 'Lark', 'Marsh', 'Moor', //
  'Oak', 'Pike', 'Quill', 'Reed', 'Rook', 'Rowe', 'Rune', 'Sable', 'Shaw', 'Stone', 'Storm', 'Swift', //
  'Thorn', 'Vane', 'Voss', 'Ward', 'West', 'Wolfe', 'Wynd', 'Yew', 'Ashby', 'Bell', 'Cole', 'Gray', //
];

/// The wave's mini boss's and boss's own names (#67), on their boss bars with a title from their type
/// ("Morgath the Summoner", [bossTitles]). Plain ASCII, like the troops'.
const bossNames = [
  'Morgath', 'Vraxis', 'Grimdor', 'Skarn', 'Zulgor', 'Nerith', 'Malvok', 'Drevak', //
  'Karnok', 'Thorgul', 'Vesmir', 'Ghorza', 'Belzar', 'Rakthar', 'Xolmir', 'Ushra', //
  'Kragmor', 'Nazgra', 'Vorlag', 'Ulgrim', 'Zarkoth', 'Mordek', 'Sylgor', 'Dravok', //
  'Gorlax', 'Hexul', 'Ruvak', 'Skorva', 'Taltha', 'Vexa', 'Yurgol', 'Zhar', //
];

/// A boss's name drawn with [dice] that isn't in [taken] (the monsters' on the field), else the first free
/// one in list order (else a repeat).
String bossName(Random dice, Set<String> taken) {
  final name = bossNames[dice.nextInt(bossNames.length)];
  return taken.contains(name) ? bossNames.firstWhere((n) => !taken.contains(n), orElse: () => name) : name;
}

/// A first and a last name drawn with [dice] that isn't in [taken] (the living troops' names). Only with
/// nearly every name taken does it fall back to the first free one in list order (else a repeat).
String troopName(Random dice, Set<String> taken) {
  for (var i = 0; i < 100; i++) {
    final name = '${firstNames[dice.nextInt(firstNames.length)]} ${lastNames[dice.nextInt(lastNames.length)]}';
    if (!taken.contains(name)) return name;
  }
  for (final f in firstNames) {
    for (final l in lastNames) {
      if (!taken.contains('$f $l')) return '$f $l';
    }
  }
  return '${firstNames.first} ${lastNames.first}';
}
