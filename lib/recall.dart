part of 'game.dart';

// "Hero Gugur", recalling a fallen Hero (#92 part 3, decisions-log 150; docs/units-and-combat.md "Hero Gugur"): a Hero
// that falls is kept in [Game.fallenHeroes] with its name, type, rolled attributes and own skill, and between waves its
// type's Army detail (lib/troop_detail.dart `_recallLines`, decisions-log 230; the field's Toko had a "Hero Gugur"
// section until decisions-log 296) calls it back for about one wave's income: the same Hero, nothing
// rolled again. Heroes falling at wave 66 was a loss the owner cared about, and late gold had nothing to buy (the owner:
// "iya bener duitnya itu aku bingung di buat untuk apa"). Every number the owner may change is a constant below.

/// What a recall costs at wave 1, before [killGoldGrowth] (the kill gold's own growth, so the price stays about one
/// wave's income): 57k at wave 65, 80k at 72, 118k at 80, 313k at 100.
const heroRecallK = 2500;

/// The recall's price is rounded to this many gold.
const heroRecallRound = 1000;

/// What a recall costs after wave [wave] is won: [heroRecallK] × (1 + [killGoldGrowth])^(wave − 1), rounded to
/// [heroRecallRound] (at least that).
int heroRecallPrice(int wave) =>
    max(heroRecallRound, (heroRecallK * pow(1 + killGoldGrowth, max(0, wave - 1)) / heroRecallRound).round() * heroRecallRound);

/// Why a fallen Hero can't come back, besides the store's (closed: [StoreRefusal]) and a troop buy's own
/// ([Game.buyRefusal]: the type's cap, the army, the gold): [heroMax] Heroes live already.
const recallRefusals = (heroes: 'Already $heroMax Heroes');

// The swap (decisions-log 167, qa-4's FINDING: under the army cap "Pasukan penuh" refused every recall, since a plain
// troop bought back fills the fallen Hero's place first): with the army full, or since decisions-log 201 the Hero's type
// at its cap, a recall sends one troop of the Hero's type that isn't a Hero home ([Recall.recallSwapOf]), and the Hero
// takes its place, so the army's and the type's counts stay.

/// What the troop a full army's recall sends home pays back: this share of its type's [Game.priceOf], as Lepas jenis
/// pays ([releaseRefund]).
const recallSwapRefund = releaseRefund;

/// Why a full army can't take a fallen Hero of [type] back, after the army's own refusal ("Army full", or
/// [buyRefusals].full, "No room", without the board's limits): no troop of its type that isn't a Hero to send home for it.
String recallNoSwap(String type) => 'no ${troopTypeNames[type] ?? type} to swap';

/// What the Hero Gugur section's card says of every recall: the Hero is the same, its relics stayed in the bag (they
/// went back when it fell).
const recallLines = ['Comes back with the same stats and skill', 'Its relics stay in the ${Words.bag}'];

/// A fallen Hero as "Hero Gugur" keeps it ([Game.fallenHeroes]): its [name], [type], rolled attributes ([stats], each
/// ×[heroBoost]) and own [skill], and the wave it fell in ([fell]).
final class FallenHero {
  FallenHero({required this.name, required this.type, required List<HeroStat> stats, this.skill, required this.fell})
      : stats = List.unmodifiable(stats);

  /// Hero [u] as it fell in wave [fell].
  FallenHero.of(Unit u, int fell) : this(name: u.name, type: u.type, stats: u.heroStats, skill: u.heroSkill, fell: fell);

  final String name, type;
  final List<HeroStat> stats;
  final HeroSkill? skill;
  final int fell;

  Map<String, Object> toJson() => {
        'name': name,
        'type': type,
        'stats': [for (final s in stats) s.name],
        if (skill case final s?) 'skill': s.name,
        'fell': fell,
      };

  /// [j] as [toJson] wrote it, or null for a type this build doesn't know; an attribute or skill it doesn't know is
  /// left out (a recall then rolls it the way a loaded Hero does).
  static FallenHero? fromJson(Map j) {
    final type = j['type'];
    if (type is! String || !troopTypes.containsKey(type)) return null;
    return FallenHero(
      name: j['name'] as String? ?? '',
      type: type,
      stats: [for (final s in (j['stats'] as List?) ?? const []) ?HeroStat.values.asNameMap()[s]],
      skill: HeroSkill.values.asNameMap()[j['skill']],
      fell: j['fell'] as int? ?? 0,
    );
  }
}

/// The Hero Gugur rules (the Army detail's Recall tags call them).
extension Recall on Game {
  /// What recalling a Hero costs now ([heroRecallPrice] of the last wave played).
  int get recallPrice => heroRecallPrice(wave);

  /// Why [f] can't come back now, in the UI's words, or null when it can, through the one buy gate: the store's
  /// refusal first ([Store._armyClosed]: before wave [storeFrom] is won, mid-wave, the game over), then [Game.buyRefusal]
  /// as for a troop of its type at [recallPrice] with the Hero check: a [full] army or a type at its cap
  /// ([Game.typeFull]) needs a troop of its type to swap ([recallSwapOf]; none: "Army full: no Templar to swap", or
  /// "No room: …" without the board's limits; a full type with none: "Templars full 10/10"); Oath of One may bar its
  /// type ([Game.typeLocked]); fewer than [heroMax] Heroes alive ([recallRefusals]); then the gold ("Not enough gold",
  /// against the whole price: the swap's refund comes after).
  String? whyNotRecall(FallenHero f) {
    if (_armyClosed case final why?) return storeRefusalNames[why]!;
    final swap = full || typeFull(f.type);
    if (swap && recallSwapOf(f) == null) {
      if (full && !typeLocked(f.type)) {
        final why = armySize < armyCap ? fewOathBar : (armyMax != null && armyCap == armyMax ? '${Words.army} full' : buyRefusals.full);
        return '$why: ${recallNoSwap(f.type)}'; // at Oath of the Few's size under the cap ([Game.armyLocked]): its words
      }
      return buyRefusal(f.type, price: recallPrice, hero: true);
    }
    return buyRefusal(f.type, price: recallPrice, hero: true, swap: swap);
  }

  /// The troop a recall of [f] sends home now, or null: the army has room and [f]'s type is under its cap (nobody goes),
  /// or the army holds no troop of [f]'s type that isn't a Hero. With the army [full] (at the cap, or over it: a save's
  /// 48) or the type full ([Game.typeFull], decisions-log 201), the one of them with the lowest HP share (one still
  /// waiting for the after-wave heal, [healQueue], counts as whole, as the save keeps it), of equals the first placed
  /// (the lowest [Unit.id]).
  Unit? recallSwapOf(FallenHero f) {
    if (!full && !typeFull(f.type)) return null;
    final plain = [for (final u in troops) if (u.alive && !u.hero && u.type == f.type) u];
    double share(Unit u) => healQueue.contains(u) ? 1 : u.hp / u.maxHp;
    int weaker(Unit a, Unit b) => switch (share(a).compareTo(share(b))) { 0 => a.id.compareTo(b.id), final d => d };
    return (plain..sort(weaker)).firstOrNull;
  }

  /// What the troop a full army's recall of a [type] Hero sends home pays back: [recallSwapRefund] of [priceOf].
  int recallSwapRefundOf(String type) => (priceOf(type) * recallSwapRefund).round();

  /// "Panggil kembali": [f] comes back for [recallPrice], as the same Hero (its name, attributes and skill as it
  /// fell; one this build no longer knows is rolled the way a loaded Hero's is), with its type's stats as they are
  /// now (its items, Bangkit and Pusaka) and both relic slots empty. With the army [full] or its type at its cap it
  /// swaps: the troop [recallSwapOf] names goes home first (not fallen, its relics back to the bag, as Lepas jenis sends
  /// them) for [recallSwapRefundOf], and the Hero takes its cell, so the army's and the type's counts stay; else it
  /// marches in to the cell [autoPlace] would give a troop. The army lines up again, everyone's aura is refitted, and
  /// the UI shows its splash ([heroRecalled]); logged as [HeroRecalled]. False (and nothing changes but the error sound)
  /// when [whyNotRecall] refuses or no cell is free.
  bool recallHero(FallenHero f) {
    final swap = recallSwapOf(f), cell = swap?.cell ?? _autoCell;
    if (!fallenHeroes.contains(f) || whyNotRecall(f) != null || cell == null) {
      sfx.add(Sfx.error);
      return false;
    }
    final (c, r) = cell;
    final cost = recallPrice, refund = swap == null ? 0 : recallSwapRefundOf(f.type);
    gold -= cost;
    if (swap != null) {
      _sendHome([swap]);
      gold += refund;
    }
    final u = _newTroop(f.type, Point(c * tile + tile / 2, r * tile + tile / 2), f.name) // its own name: no name dice drawn
      ..hero = true
      ..heroStats = [...f.stats]
      ..heroSkill = f.skill;
    units.add(u);
    if (u.heroStats.isEmpty) _rollHeroStats(u);
    _rerollOutOfPool(u);
    if (u.heroSkill == null) _rollHeroSkill(u);
    _marchIn(u);
    _fallIn(u);
    _refitTroops(); // its own x3, and everyone else's aura
    fallenHeroes.remove(f);
    heroRecalled.add(u);
    _emit(HeroRecalled(wave, t,
        name: u.name, type: u.type, stats: u.heroStats, skill: u.heroSkill, fell: f.fell, cost: cost, swapped: swap?.name, refund: refund));
    sfx
      ..add(Sfx.place)
      ..add(Sfx.clear);
    return true;
  }

  /// What the Hero Gugur section's tooltip says of [f]: its name, then its type and the wave it fell in, its
  /// attributes and skill, [recallLines], the troop a full army or type sends home for it ([recallSwapOf]: "Army full:
  /// …", else "Knights full: …") and the price.
  (String, List<String>) recallInfo(FallenHero f) => (f.name, [
        '${troopTypeNames[f.type] ?? f.type}, fell in wave ${f.fell}',
        if (f.skill case final s?) 'Skill: ${s.title}',
        ...recallLines,
        if (recallSwapOf(f) case final u?)
          '${full ? '${Words.army} full' : '${troopTypePlurals[f.type] ?? f.type} full'}: ${u.name} goes home '
              '(+${thousands(recallSwapRefundOf(f.type))} gold)',
        priceLine(recallPrice),
      ]);
}
