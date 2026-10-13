// The words of the game's mechanics, places and shared buttons as the player reads them (decisions-log 187; docs/ui-hud.md
// "Words"): a plain library, no imports, so a later pick of a name (the owner's: Hone for Sharpen, Legend for Legendary,
// Storage for Vault) is one line here. The defaults are the English glossary's; the owner hasn't picked yet. game.dart
// exports it, so main.dart, guide_text.dart and the tests reach it.

/// The game's mechanic words and the refusals several systems share, one place (ui-hud.md "In-game text"). Display
/// only: enum names, save keys, telemetry and test ids never read these.
abstract final class Words {
  static const army = 'Army', bag = 'Bag', shop = 'Shop', vault = 'Vault', settings = 'Settings',
      howTo = 'How to Play', scoreboard = 'Scoreboard';
  static const start = 'Start', room = '+Room', replaceFallen = 'Replace fallen', recall = 'Recall';

  /// "+Room" (the spawn bar's capacity buy, decisions-log 292): what it does (its tooltip's first line, "+Room: more army
  /// room (110 gold)."), its button at the most, and what a tap on it then says ("Army room is at its most (36).").
  static const moreRoom = 'more army room', roomMax = 'Room: max', roomAtMost = 'Army room is at its most';

  /// The two Autos, each named for what it does (decisions-log 290; the owner, 2026-10-09: "auto yang di bawah sama auto
  /// yang di atas membingungkan karna sama sama tulisan auto"): the top band's starts the next wave after a countdown
  /// (auto_start.dart), the spawn bar's buys the fallen back (auto_replace.dart).
  static const autoWave = 'Auto Wave', autoBuy = 'Auto Buy';
  static const awaken = 'Awaken', forge = 'Forge', sharpen = 'Sharpen', melt = 'Melt', carve = 'Carve', give = 'Give';
  static const artifact = 'Artifact', relic = 'Relic', oath = 'Oath', shadow = 'Shadow', shard = 'Shard', tide = 'Tide';
  static const bossChest = 'Boss Chest', missedChest = 'Missed Chest', reroll = 'Reroll', skip = 'Skip', take = 'Take';
  static const equip = 'Equip', move = 'Move', toVault = 'To Vault', remove = 'Remove', release = 'Release',
      sell = 'Sell', buy = 'Buy';
  static const sure = 'Sure?', back = 'Back', undo = 'Undo';
  static const onlyBetweenWaves = 'Only between waves', notEnoughGold = 'Not enough gold', gameOver = 'Game over';

  /// Over a troop healer whose heal found it short of MP (decisions-log 297; [Game.noMp]).
  static const noMp = 'No MP';

  /// A troop's attributes as the Army page's detail names them (decisions-log 218): the short names, and what each one
  /// means in a few words, the longest first (a narrow page takes the first that fits). A healer's power is its heal.
  static const hp = 'HP', mp = 'MP', defence = 'Def', damage = 'Dmg', heal = 'Heal', range = 'Range', speed = 'Speed',
      rate = 'Rate', regen = 'Regen', mpRegen = 'MP regen';

  /// Train (decisions-log 334, train.dart): a troop type whose items are all +5 buys levels of its attributes, on its Army
  /// detail; a level is "Lv 3".
  static const train = 'Train', lv = 'Lv';
  /// A healer's MP pays for its heals too, 6 MP each ([healMp], decisions-log 297): [healerMpHelp], and its heal's help
  /// names the cost.
  static const hpHelp = ['Damage it can take', 'Its life'], mpHelp = ['Fills up for skills', 'For skills'],
      healerMpHelp = ['Pays for heals and skills', 'Heals, skills'],
      defenceHelp = ['Less damage per hit', 'Blocks damage'], damageHelp = ['Damage per hit', 'Per hit'],
      healHelp = ['HP back per heal, 6 MP', 'Per heal, 6 MP'], rangeHelp = ['How far it reaches', 'Reach'],
      speedHelp = ['How fast it walks', 'Walk speed'], rateHelp = ['Seconds per attack', 'Attack pause'],
      healRateHelp = ['Seconds per heal', 'Heal pause'], regenHelp = ['HP back each second', 'HP per second'];

  /// The Towns (decisions-log 216): a Town between two waves, its Smithy and its Tavern, the button that leaves it, the
  /// wave meter's chip ("Town after wave 12") and the meter in a Town ("In town", "next wave 7").
  static const town = 'Town', smithy = 'Smithy', tavern = 'Tavern', leaveTown = 'Leave town', townAfter = 'Town after wave';
  static const inTown = 'In town', inPlace = 'In', nextWave = 'next wave';

  /// The market's words (decisions-log 326, market.dart): on the Sell page a kind the Town wants ("Hot in Millbrook") and
  /// a product sold so much its price falls; the Town chip's tooltip, what the next Town pays well for.
  static const hotIn = 'Hot in', flooded = 'Flooded: price falling', paysWellFor = 'Pays well for';

  /// The Smithy's Craft (decisions-log 233): its button, and what is said once a relic is made ("Sweep crafted!"); what
  /// the Smithy's page lists under a relic (decisions-log 235); and the forge's late step, its strip's third tab
  /// (decisions-log 254), and what is said once an item goes a step up ("Royal Sword enhanced to +4!", decisions-log 255).
  static const craft = 'Craft', crafted = 'crafted', recipe = 'Recipe', enhance = 'Enhance', enhanced = 'enhanced';

  /// The Towns' materials (decisions-log 221): what monsters drop for the Smithy (the Bag's chip, "Mats" where the word
  /// doesn't fit), the third grade (a mini boss's or the boss's always-drop), what the Smithy needs, and each material's
  /// name by its save key ([Mat], game.dart), in the game's order.
  static const materials = 'Materials', materialsShort = 'Mats', trophy = 'Trophy', onlyInTown = 'Only in a Town';

  /// What drops where the Smithy makes the items (decisions-log 246, 292): the empty Bag's and
  /// the Shop's empty Sell grid's lines ("Monsters drop materials.", "Make items at the Smithy in a Town.").
  static const monstersDropMats = 'Monsters drop materials', makeItemsAtSmithy = 'Make items at the $smithy in a $town';

  /// What a forge stone is instead of a monster's drop (decisions-log 245: Mithril and Starmetal, made for Enhance).
  static const madeAtSmithy = 'Made at the $smithy';

  /// The forge's item grades (decisions-log 249: "grade II"), and the Army detail's where-from words for an item the
  /// Smithy makes ("Smithy: can make 3", "Smithy: needs Wolf Claw") and for one a type already holds in full ("Done").
  static const grade = 'grade', gradeNumerals = ['I', 'II', 'III'], canMake = 'can make', needs = 'needs', done = 'Done';

  /// An Awaken level a type kept from a save before the grades (decisions-log 272), as the Army detail says it, the
  /// longest that fits: "Awaken 3 (kept from old items)", "Awaken 3 (kept)".
  static const keptFromOld = 'kept from old items', kept = 'kept';

  /// The Wishlist (decisions-log 282): its name, the Army detail's tag that opens its picker and the picker's heading, what
  /// an item's type chip on the Smithy says, the mark of a wish the Bag pays for, what a wish tapped outside a Town says,
  /// and a material's tooltip line.
  static const wishlist = 'Wishlist', addToWishlist = 'Add to wishlist', readyToCraft = 'Ready to craft',
      craftInTown = 'Craft at the $smithy in a $town', neededForWishlist = 'Needed for your wishlist';

  /// A product's page's short "Add to wishlist" (until decisions-log 303 also the Wishlist tab's picker's tag); a type's
  /// whole next Awaken on the Wishlist (decisions-log 300): the Army detail's tag by "Awaken 2 needs" that puts it on or
  /// takes it off.
  static const add = 'Add', wishAll = 'Wishlist all', removeSet = 'Remove set';

  /// The Smithy's Wishlist tab (decisions-log 303: where wishes are made, not added): a row's status ("Ready", or
  /// "Short: Orc Tooth 1"), the free lines' group, and the empty tab's two lines, where wishes are put on.
  static const ready = 'Ready', short = 'Short', forBag = 'For the $bag', noWishes = 'No wishes yet',
      addWishesFrom = 'Add wishes from the $army page, the $bag or the Items tab';

  /// Ingredient wishes (decisions-log 323): the Wishlist tab's group of the products a wish's recipe takes (each row "for
  /// Royal Ring", never a troop), and what a product's page says in its Give row's place while one is kept for that
  /// craft ("Needed for Royal Ring").
  static const ingredients = 'Ingredients', neededFor = 'Needed for';

  /// The Town's Shop (decisions-log 230): what the Bag's facing page says under a kind it can't sell.
  static const soldInTown = 'Sold at the $shop, in a $town.';

  /// The pocket items (decisions-log 332, pocket.dart): the Bag's chip and the Smithy's section, the Bag page's rows that
  /// put one in the bar or take it out, and why a slot can't be used ([Pockets.whyNotUsePocket]: "Ready in 12 s").
  static const pocket = 'Pocket', putInPocket = 'Put in pocket', takeOut = 'Take out', inPocket = 'In pocket',
      pocketEmpty = 'Empty: put one in from the $bag', noneLeft = 'None left: craft more at the $smithy',
      onlyInWave = 'Only in a wave', notInTown = 'Not in a $town', paused = 'Paused', readyIn = 'Ready in',
      noOneHurt = 'No one is hurt', noOneNeedsMp = 'No one needs MP', noMonster = 'No monster on the field',
      pocketFull = 'Pocket full: take one out first', inSlot = 'In slot', intoSlot = 'Into slot';
  static const materialNames = {
    'slimeGel': 'Slime Gel', 'batWing': 'Bat Wing', 'boneShard': 'Bone Shard', 'orcTooth': 'Orc Tooth', //
    'boneArrow': 'Bone Arrow', 'wolfClaw': 'Wolf Claw', 'rustyPlate': 'Rusty Plate', 'leatherStrap': 'Leather Strap',
    'orcEar': 'Orc Ear', 'ironScrap': 'Iron Scrap', 'bigBone': 'Big Bone', 'bearFur': 'Bear Fur', 'tealCloth': 'Teal Cloth',
    'slimeCore': 'Slime Core', 'batFang': 'Bat Fang', 'skull': 'Skull', 'orcTusk': 'Orc Tusk', 'boneBow': 'Bone Bow',
    'wolfFang': 'Wolf Fang', 'crackedSkull': 'Cracked Skull', 'wargFang': 'Warg Fang', 'orcHeart': 'Orc Heart',
    'ironTusk': 'Iron Tusk', 'graveSteel': 'Grave Steel', 'bearClaw': 'Bear Claw', 'tealGem': 'Teal Gem',
    'darkGem': 'Dark Gem', 'evilEye': 'Evil Eye', 'soulOrb': 'Soul Orb', 'lichOrb': 'Lich Orb',
    'mithril': 'Mithril', 'starmetal': 'Starmetal', // the forge's stones (decisions-log 245)
  };

  /// The small relics' tiers by their save key (decisions-log 227; town.json `recipes.<relic>.tier`): today's four Basic,
  /// the Smithy's new ones Strong or Mighty; and the hint of who a relic suits ("Best on: Knight, Templar").
  static const relicTiers = {'basic': 'Basic', 'strong': 'Strong', 'mighty': 'Mighty'};
  static const bestOn = 'Best on';

  /// The rarities, commonest first (an Artifact's: Rare, Epic, Legendary).
  static const common = 'Common', rare = 'Rare', epic = 'Epic', legendary = 'Legendary';

  /// The Tavern's (decisions-log 266): what it sells, an offer bought, and every offer bought (no reroll left to make);
  /// a boost's longest length (decisions-log 331), as the offer and the running boost say it, and where that is too long.
  static const boost = 'Boost', sold = 'Sold', soldOut = 'Sold out', untilNextTown = 'Until next $town', untilTown = 'Until $town';

  /// After a wipe (decisions-log 333, wipe.dart): the dialog's title and its two answers, and the monsters weakened until
  /// the next Town (the wave meter's chip, short where it is too long).
  static const armyFell = 'Your army fell!', tryAgain = 'Try again', giveUp = 'Give up';
  static const weakenedFoes = 'Weakened foes', weakened = 'Weakened';
}
