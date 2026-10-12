// Shared by the tests that put a troop type at an Awaken level from its items (decisions-log 321: the old item recipe
// went with the Towns-off rules, so every test builds a level by the game's own rule).
import 'package:tower_defense/game.dart';

/// The items [type] holds at Awaken [level] by the game's own rule ([Game.awakenNeeds]: every grade set up to it,
/// decisions-log 249), in [g] (past the level it kept, [Game.keptLevel]) or in a fresh game: the type at Awaken [level].
List<Item> awakenItems(String type, int level, [Game? g]) => [
      for (final MapEntry(key: item, value: n) in (g ?? Game()).awakenNeeds(type, level).entries) ...List.filled(n, item),
    ];
