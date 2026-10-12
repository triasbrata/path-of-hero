// Shared by the tests that play the game's own rules (decisions-log 321: every game has the Towns, a plain Game() too,
// and the rules from before them went): a troop type at an Awaken level from its items, and a game no Town comes to.
import 'package:tower_defense/game.dart';

/// The items [type] holds at Awaken [level] by the game's own rule ([Game.awakenNeeds]: every grade set up to it,
/// decisions-log 249), in [g] (past the level it kept, [Game.keptLevel]) or in a fresh game: the type at Awaken [level].
List<Item> awakenItems(String type, int level, [Game? g]) => [
      for (final MapEntry(key: item, value: n) in (g ?? Game()).awakenNeeds(type, level).entries) ...List.filled(n, item),
    ];

/// Town rules whose every roll misses ([TownSchedule]): no Town ever comes, so a test of the waves between them plays
/// on without one (a Town's own tests: town_test.dart).
final noTowns = TownRules.patch({
  'schedule': {'chanceStart': 0.0, 'chanceStep': 0.0, 'chanceCap': 0.0},
});
