// The words' one table (lib/words.dart, decisions-log 187; docs/ui-hud.md "Words"): every word there, none empty, none
// with stray spaces, no two the same (one word for one thing), and the table reached through game.dart; the Army
// detail's attribute helps (decisions-log 218), the longest first.
import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';

void main() {
  test('every word is in the table, none empty, none with stray spaces, no two alike', () {
    const words = {
      'army': Words.army,
      'bag': Words.bag,
      'shop': Words.shop,
      'vault': Words.vault,
      'settings': Words.settings,
      'howTo': Words.howTo,
      'scoreboard': Words.scoreboard,
      'start': Words.start,
      'room': Words.room,
      'moreRoom': Words.moreRoom,
      'roomMax': Words.roomMax,
      'roomAtMost': Words.roomAtMost,
      'replaceFallen': Words.replaceFallen,
      'recall': Words.recall,
      'autoWave': Words.autoWave,
      'autoBuy': Words.autoBuy,
      'awaken': Words.awaken,
      'forge': Words.forge,
      'sharpen': Words.sharpen,
      'melt': Words.melt,
      'carve': Words.carve,
      'give': Words.give,
      'artifact': Words.artifact,
      'relic': Words.relic,
      'oath': Words.oath,
      'shadow': Words.shadow,
      'shard': Words.shard,
      'tide': Words.tide,
      'bossChest': Words.bossChest,
      'missedChest': Words.missedChest,
      'reroll': Words.reroll,
      'skip': Words.skip,
      'take': Words.take,
      'equip': Words.equip,
      'move': Words.move,
      'toVault': Words.toVault,
      'remove': Words.remove,
      'release': Words.release,
      'sell': Words.sell,
      'buy': Words.buy,
      'sure': Words.sure,
      'back': Words.back,
      'cancel': Words.cancel,
      'undo': Words.undo,
      'onlyBetweenWaves': Words.onlyBetweenWaves,
      'notEnoughGold': Words.notEnoughGold,
      'gameOver': Words.gameOver,
      'hp': Words.hp,
      'mp': Words.mp,
      'defence': Words.defence,
      'damage': Words.damage,
      'heal': Words.heal,
      'range': Words.range,
      'speed': Words.speed,
      'rate': Words.rate,
      'regen': Words.regen,
      'town': Words.town,
      'smithy': Words.smithy,
      'tavern': Words.tavern,
      'leaveTown': Words.leaveTown,
      'townAfter': Words.townAfter,
      'inTown': Words.inTown,
      'inPlace': Words.inPlace,
      'hotIn': Words.hotIn,
      'flooded': Words.flooded,
      'paysWellFor': Words.paysWellFor,
      'nextWave': Words.nextWave,
      'onlyInTown': Words.onlyInTown,
      'monstersDropMats': Words.monstersDropMats,
      'makeItemsAtSmithy': Words.makeItemsAtSmithy,
      'soldInTown': Words.soldInTown,
      'craft': Words.craft,
      'crafted': Words.crafted,
      'recipe': Words.recipe,
      'enhance': Words.enhance,
      'common': Words.common,
      'rare': Words.rare,
      'epic': Words.epic,
      'legendary': Words.legendary,
      'boost': Words.boost,
      'sold': Words.sold,
      'soldOut': Words.soldOut,
      'wishlist': Words.wishlist,
      'addToWishlist': Words.addToWishlist,
      'onWishlist': Words.onWishlist,
      'readyToCraft': Words.readyToCraft,
      'craftInTown': Words.craftInTown,
      'neededForWishlist': Words.neededForWishlist,
      'add': Words.add,
      'wishAll': Words.wishAll,
      'removeSet': Words.removeSet,
      'ready': Words.ready,
      'short': Words.short,
      'forBag': Words.forBag,
      'noWishes': Words.noWishes,
      'addWishesFrom': Words.addWishesFrom,
      'ingredients': Words.ingredients,
      'neededFor': Words.neededFor,
    };
    for (final MapEntry(:key, :value) in words.entries) {
      expect(value.trim(), isNotEmpty, reason: key);
      expect(value, value.trim(), reason: '$key: no stray spaces');
      expect(value.contains('  '), isFalse, reason: '$key: no double space');
    }
    expect(words.values.toSet(), hasLength(words.length), reason: 'one word for one thing');
  });

  test('+Room\'s words (decisions-log 292): its tooltip says what it does, its button and its refusal at the most', () {
    expect((Words.room, Words.moreRoom, Words.roomMax, Words.roomAtMost),
        ('+Room', 'more army room', 'Room: max', 'Army room is at its most'));
  });

  test('the two Autos are named apart (decisions-log 290): the top band\'s "Auto Wave", the spawn bar\'s "Auto Buy"', () {
    expect((Words.autoWave, Words.autoBuy), ('Auto Wave', 'Auto Buy'));
  });

  test('each attribute\'s help (the Army detail, decisions-log 218): a few words, the longest first', () {
    const helps = {
      'hpHelp': Words.hpHelp,
      'mpHelp': Words.mpHelp,
      'healerMpHelp': Words.healerMpHelp,
      'defenceHelp': Words.defenceHelp,
      'damageHelp': Words.damageHelp,
      'healHelp': Words.healHelp,
      'rangeHelp': Words.rangeHelp,
      'speedHelp': Words.speedHelp,
      'rateHelp': Words.rateHelp,
      'healRateHelp': Words.healRateHelp,
      'regenHelp': Words.regenHelp,
    };
    for (final MapEntry(:key, :value) in helps.entries) {
      expect(value, isNotEmpty, reason: key);
      for (final (i, w) in value.indexed) {
        expect((w.trim().isNotEmpty, w == w.trim(), w.contains('  ')), (true, true, false), reason: '$key $i');
        if (i > 0) expect(w.length, lessThan(value[i - 1].length), reason: '$key: the longest first');
      }
    }
  });
}
