part of 'game.dart';

// The Pusaka engine (catalog step 0b, decisions-log 178; docs/loot-items-relics.md "The Pusaka catalog and its
// engine"): it runs every row of [pusakaCatalog] the same way, so a new Pusaka is a row of Fx, not new code. Each type's
// bound Fx are kept by trigger in its book ([FxEngine._bookOf]), rebuilt after any change to the Pusaka owned (a
// binding, a star, one owned or lost: [_pusakaEdits]), so a hook does one lookup, not one per Pusaka. Each trigger is
// dispatched at one place in the fight (game.dart, draft.dart, the skills' casts); the effects are today's rules,
// number for number. Extra damage (a leap) runs only the `dealt` effects, never another proc ([Game._fxDepth]). Nothing
// draws a die. At its end the catalog's shared hooks (step 0f, decisions-log 182) that the data batches' rules read:
// the near counts, the once-an-HP-threshold flags and the duration scaler.

/// Counts every change to a Pusaka owned ([OwnedPusaka]'s type, stars and Ukir steps, [Game.pusaka]'s entries), so a
/// [Game]'s books are rebuilt before their next read ([FxEngine._bookOfType]). One count for every game: a change in one
/// only rebuilds the others' books once.
int _pusakaEdits = 0;

/// [Game.pusaka]: a map that counts its changes ([_pusakaEdits]).
class _PusakaMap extends MapBase<Relic, OwnedPusaka> {
  final _m = <Relic, OwnedPusaka>{};

  @override
  OwnedPusaka? operator [](Object? key) => _m[key];

  @override
  void operator []=(Relic key, OwnedPusaka value) {
    _m[key] = value;
    _pusakaEdits++;
  }

  @override
  OwnedPusaka? remove(Object? key) {
    _pusakaEdits++;
    return _m.remove(key);
  }

  @override
  void clear() {
    _m.clear();
    _pusakaEdits++;
  }

  @override
  Iterable<Relic> get keys => _m.keys;

  @override
  Iterable<OwnedPusaka> get values => _m.values;

  @override
  Iterable<MapEntry<Relic, OwnedPusaka>> get entries => _m.entries;

  @override
  bool containsKey(Object? key) => _m.containsKey(key);

  @override
  int get length => _m.length;

  @override
  bool get isEmpty => _m.isEmpty;

  @override
  bool get isNotEmpty => _m.isNotEmpty;
}

/// Fx [index] of Pusaka [relic], bound to a type at [stars] and [ukir] steps: its numbers there, read once through the
/// accessor ([pusakaAt]: [k], [boss] on the boss; [pusakaCountAt]: [count], by the stars alone) when the book is built,
/// and its own cooldown [cd] ([Fx.cd]; a strip's or a cleanse's is its [k], [Fx.cdByStars]: Spell Cutter's, Salt
/// Charm's, Pure Water's, by stars).
class FxBound {
  FxBound(this.relic, this.stars, this.index, this.fx, {this.ukir = 0})
      : k = fx.k.isEmpty ? 0 : pusakaAt(relic, stars, fx: index, ukir: ukir),
        boss = fx.k.isEmpty ? 0 : pusakaAt(relic, stars, boss: true, fx: index, ukir: ukir),
        count = fx.count.isEmpty ? 0 : pusakaCountAt(relic, stars, fx: index),
        cd = fx.cdByStars ? pusakaAt(relic, stars, fx: index, ukir: ukir) : fx.cd;

  final Relic relic;
  final int stars, index, ukir;
  final Fx fx;
  final double k, boss;
  final int count;
  final double cd;
}

/// A type's bound Fx, by trigger, in [Game.pusaka]'s order.
class FxBook {
  final _on = List.generate(Trig.values.length, (_) => <FxBound>[], growable: false);

  /// The Fx [t] sets off.
  List<FxBound> operator [](Trig t) => _on[t.index];
}

/// The engine: the books, and each trigger's dispatch.
extension FxEngine on Game {
  /// Troop [u]'s type's book; null for a monster, or a type with no Pusaka.
  FxBook? _bookOf(Unit u) => u.side == Side.troop ? _bookOfType(u.type) : null;

  /// [type]'s book, rebuilt first when a Pusaka changed since ([_rebook]); null: none bound to it.
  FxBook? _bookOfType(String type) {
    if (_bookAt != _pusakaEdits) _rebook();
    return _books[type];
  }

  /// Every type's book anew from [Game.pusaka]: each bound Pusaka's Fx at its stars and Ukir steps.
  void _rebook() {
    _books.clear();
    for (final MapEntry(key: r, value: p) in pusaka.entries) {
      final type = p.type, art = pusakaCatalog[r];
      if (type == null || art == null || art.fx.isEmpty) continue;
      final book = _books[type] ??= FxBook();
      for (var i = 0; i < art.fx.length; i++) {
        final fx = art.fx[i];
        book[fx.on].add(FxBound(r, p.stars, i, fx, ukir: p.ukir));
      }
    }
    _bookAt = _pusakaEdits;
  }

  /// Whether [b]'s condition holds now, for its holder [u] (the troop of the type) and the [foe] in play (the monster it
  /// hits, or the one hitting it; null: none), as the trigger finds them: [u]'s or the foe's HP under or over [Fx.ifK] of
  /// its max HP, [Fx.ifK] or more other troops within [Fx.ifR] of [u] ([alliesNearOf]), or the first of its type this
  /// wave (the first ask that passes uses it up, [Game._fxFirsts]); batch L-1P's: the foe is the boss or a mini boss, the
  /// foe holds a shield ([shielded]), [u] fights up close ([Stats.melee]), [u] wears the small relic [Fx.ifRelic]; batch
  /// L-2P's: the foe hitting [u] fights up close; batch L-3's: a `heals` Fx's heal went [past] the troop's full HP; batch
  /// E-1P's: the foe is a monster healer, the foe is held ([foeHeld]), [Fx.ifK] or more troop types are alive
  /// ([typesAliveNow]), the foe hitting [u] shoots, [u] is a Hero; batch G-1P's: [Fx.ifK] or fewer troops of [u]'s type
  /// are alive ([Game.aliveOf], [u] among them), [u] is no Hero; batch G-2's: the foe is a high elite, a mini boss or the
  /// boss (by rank). The others ([fxIfsBuilt]) come with their batches: pusaka_catalog_test.dart fails a row with one
  /// before it gets here.
  bool _fxWhen(FxBound b, Unit u, Unit? foe, {double past = 0}) {
    final fx = b.fx;
    return switch (fx.when) {
      null => true,
      If.hpBelow => u.hp < u.maxHp * fx.ifK,
      If.hpAbove => u.hp > u.maxHp * fx.ifK,
      If.foeHpBelow => foe != null && foe.hp < foe.maxHp * fx.ifK,
      If.foeHpAbove => foe != null && foe.hp > foe.maxHp * fx.ifK,
      If.alliesNear => alliesNearOf(u, fx.ifR) >= fx.ifK,
      If.firstOfTypeThisWave => _fxFirsts.add((b.relic, b.index)),
      If.vsBoss => foe != null && (foe.tier == Tier.boss || foe.tier == Tier.miniBoss),
      If.foeShielded => foe != null && shielded(foe),
      If.melee => u.stats.melee,
      If.holds => u.holds(fx.ifRelic!),
      If.attackerMelee => foe != null && foe.stats.melee,
      If.healPastFull => past > 0,
      If.foeHealer => foe != null && foe.side == Side.enemy && foe.stats.heals,
      If.foeHeld => foe != null && foeHeld(foe),
      If.typesAlive => typesAliveNow >= fx.ifK,
      If.attackerRanged => foe != null && foe.stats.shotSpeed > 0,
      If.hero => u.hero,
      If.fewOfType => aliveOf(u.type) <= fx.ifK,
      If.notHero => !u.hero,
      If.foeHighElite => foe != null && foe.tier.index >= Tier.highElite.index,
      _ => throw _unbuilt(fx),
    };
  }

  // Always: the stat fold.

  /// [Game.statsOf]: [type]'s stats [s] with its Pusaka's `always` stats (Dragon Heart's HP and regen, Dawn Star's
  /// attack or heal; Living Moss's regen, a share of its max HP a second, and its attack or heal down; Hawk Feather's
  /// range ×, a melee type's no farther than its reach cap ([Stats.reachCap]) as a bow's; Stone Coat's defence + and walk speed ×;
  /// Moonwell's MP regen × and max HP ×; Wide Blows' splash +, Vow of Silence's max HP and attack ×). Relic Altar's and Vow
  /// of Silence's other `always` Fx are read where the relics work ([_relicK]) and where skills are cast ([_fxSilent]).
  Stats _pusakaStats(String type, Stats s) {
    final book = _bookOfType(type);
    if (book == null) return s;
    for (final b in book[Trig.always]) {
      s = switch (b.fx) {
        Fx(eff: Eff.stat, stat: Stat.hp) => s._with(hp: (s.hp * b.k).round(), regen: s.regen + s.hp * b.k * b.fx.regen),
        Fx(eff: Eff.stat, stat: Stat.dmg) => s._with(dmg: s.dmg * b.k),
        Fx(eff: Eff.stat, stat: Stat.regen) => s._with(regen: s.regen + s.hp * b.k),
        Fx(eff: Eff.stat, stat: Stat.range) => s._with(range: s.melee ? max(s.range, min(s.range * b.k, s.reachCap)) : s.range * b.k),
        Fx(eff: Eff.stat, stat: Stat.def) => s._with(def: s.def + b.k),
        Fx(eff: Eff.stat, stat: Stat.speed) => s._with(speed: s.speed * b.k),
        Fx(eff: Eff.stat, stat: Stat.mpRegen) => s._with(mpRegen: s.mpRegen * b.k),
        Fx(eff: Eff.stat, stat: Stat.splash) => s._with(splash: s.splash + b.k),
        Fx(eff: Eff.stat, stat: Stat.hpDmg) => s._with(hp: (s.hp * b.k).round(), dmg: s.dmg * b.k),
        Fx(eff: Eff.relicK || Eff.skillGate) => s,
        _ => throw _unbuilt(b.fx),
      };
    }
    return s;
  }

  // Attack and landed: a normal attack (game.dart's [_strike], a shot landing, a healer's smite).

  /// What troop [u]'s next normal attack on [foe] (a blow, a shot, a healer's smite) is multiplied by: its `attack` Fx
  /// and the fury ([_attackK]) and the oath's (Oath of Spells' cost, [Pusaka._oathBlowK]), then a kill's one charge,
  /// spent by it (Momentum's, [Unit.charge]). [base]: the attack before them, for the counters.
  double _blowK(Unit u, double base, Unit foe) {
    final k = _attackK(u, base, foe) * (u.side == Side.troop ? _oathBlowK : 1.0), charge = u.charge;
    if (charge == null) return k;
    u.charge = null;
    _tally(charge.relic)
      ..uses += 1
      ..worth += base * k * (charge.k - 1); // the extra it adds, before the target's defence
    return k * charge.k;
  }

  /// [_blowK]'s first part: a worn fury's [furyHit] on every [furyEvery]th, and its type's `attack` power on every
  /// [Fx.every]th (War Drum; Shell Cracker on a shielded foe; Twin Fury on the fury's own beat), on one blow counter
  /// ([Unit.blows], counted only with either). An `attack` status (Snare Cord's slow, Challenge Letter's taunt, Bleeding
  /// Edge's bleed of the attack so far) goes on [foe] as it attacks ([_fxFoeStatus]), a shot's flight aside; an `attack`
  /// MP comes to [u] ([_fxMp]: Mana Leech), and an `attack` strip takes a good effect off [foe] ([_fxStrip]: Spell
  /// Cutter). An `always` range Fx counts the attack when [foe] stands past the reach [u] had without it ([_fxReach]:
  /// Hawk Feather). An `attack` taunt on the monsters near [u] calls them onto it ([_fxHorn]: Warden's Horn), an
  /// `attack` mark puts a one-hit mark on [foe] that another type spends ([_fxMark]: Ember Brand), and an `attack` heal
  /// heals the troops near [u] ([_fxHealNear]: Heartbeat). An `attack` hold pins [foe] (Ice Grip's, [_fxFoeStatus]). A
  /// power under 1 (Champion's Mantle's on the others) is a trade: it counts nothing. Relic Altar makes the fury's extra
  /// bigger ([_relicK]). An `attack` link on the troops near [u] has it take a share of their blows ([_fxChain]:
  /// Guardian Chain), and an `attack` hex turns [foe] into a slime ([_fxFoeStatus]: Hex Blade).
  double _attackK(Unit u, double base, Unit foe) {
    final fury = u.holds(Relic.fury), book = pusaka.isEmpty ? null : _bookOf(u), procs = book?[Trig.attack];
    if (book != null) _fxReach(book, u, foe);
    if (!fury && (procs == null || procs.isEmpty)) return 1;
    final n = ++u.blows, beat = fury && n % furyEvery == 0, relicK = beat ? _relicK(u) : 1.0;
    var k = beat ? 1 + (furyHit - 1) * relicK : 1.0; // its extra stronger under Relic Altar, weaker under the Bayangan Rust (omen.dart)
    if (beat) _fxAltar(u, base * (furyHit - 1) * relicK);
    for (final b in procs ?? const <FxBound>[]) {
      final every = _everyOf(b);
      if (every > 1 && n % every != 0) continue;
      if (!_fxWhen(b, u, foe)) continue;
      switch (b.fx.eff) {
        case Eff.power:
          if (b.k > 1) {
            final tally = _tally(b.relic); // a trade (k under 1: Champion's Mantle's on the others) counts nothing
            tally.uses++;
            tally.worth += base * k * (b.k - 1); // the extra it adds, before the target's defence
          }
          k *= b.k;
        case Eff.status when b.fx.to == To.nearFoes:
          _fxHorn(b, u);
        case Eff.status when b.fx.to == To.nearTroops:
          _fxChain(b, u);
        case Eff.status:
          if (!_fxFoeStatus(b, u, foe, hit: base * k)) continue;
          final tally = _tally(b.relic)..uses += 1; // the times it took hold
          if (b.fx.status == Status.bleed) tally.worth += base * k * b.k; // the bleed it adds, before the target's defence
        case Eff.mp:
          _fxMp(b, u);
        case Eff.strip:
          if (_fxStrip(b, u, foe)) _tally(b.relic).uses++;
        case Eff.mark:
          _fxMark(b, u, foe);
        case Eff.heal:
          if (u.alive) _fxHealNear(b, u.pos, (o) => o.maxHp * b.k);
        default:
          throw _unbuilt(b.fx);
      }
    }
    return k;
  }

  /// [b]'s heal on each living troop within [Fx.r] of [at] (its holder among them) below its heal ceiling ([healCeil]:
  /// the Bayangan Scar's, or full), [amount] of it through the heal funnel, the heal's sparkle on it (Heartbeat's every few
  /// hits, Bright Spring's after a skill). Its counter: the times it healed one, and the HP it gave.
  void _fxHealNear(FxBound b, Point<double> at, double Function(Unit o) amount) {
    PusakaTally? tally;
    for (final o in _alliesNear(at, b.fx.r)) {
      if (o.hp >= healCeil(o)) continue;
      _healTroop(o, amount(o), HealSrc.pusaka);
      tally ??= _tally(b.relic)..uses += 1; // one use a heal, however many it reached
      tally.worth += _healGained; // what it gave (heal.dart)
      impacts.add((o.pos, 'heal'));
    }
  }

  /// [b]'s taunt from troop [u] on the monsters near it (Warden's Horn): every one within [Fx.r] of [u] that a taunt may
  /// hold ([_tauntable]) and that its number reaches (none on the boss: its [FxBound.boss] is 0) fights [u] for
  /// [FxBound.k] s, through the duration scaler ([_fxFoeStatus]); at most once every [FxBound.cd] s a troop, the cooldown
  /// starting only when one stood near ([_fxGate]). Its counter: the monsters it taunted.
  void _fxHorn(FxBound b, Unit u) {
    final near = [for (final o in _foesNear(u.pos, b.fx.r)) if (_tauntable(o) && (o.tier == Tier.boss ? b.boss : b.k) > 0) o];
    if (near.isEmpty || !_fxGate(b, u)) return;
    for (final o in near) {
      if (_fxFoeStatus(b, u, o)) _tally(b.relic).uses++;
    }
  }

  /// [b]'s link from troop [u] on the troops near it (Guardian Chain): each living troop of another type within [Fx.r] of
  /// [u] passes [FxBound.k] of every blow on it to [u] for [Fx.time] s ([Status.link], Shared Wounds'; [u] takes that
  /// share through its own defence, [HeroSkills._beforeDefence]); a stronger link on one stays ([HeroSkills.addEffect]).
  /// Never [u]'s own type: each of its troops holds the chain. Its counter: the troops it linked, and what it took for
  /// them ([_fxLinked]).
  void _fxChain(FxBound b, Unit u) {
    if (!u.alive) return;
    for (final o in _alliesNear(u.pos, b.fx.r)) {
      if (o.type == u.type) continue;
      addEffect(o, Status.link, b.fx.time, k: b.k, by: u);
      if (effectOn(o, Status.link)?.by == u) _tally(b.relic).uses++;
    }
  }

  /// Troop [by] took [took] of a blow on troop [o] through a link ([HeroSkills._beforeDefence]): the counter of its
  /// type's `attack` link Fx (Guardian Chain's) when the link is its own (its share; Shared Wounds' is a Hero's skill).
  void _fxLinked(Unit by, Effect link, double took) {
    if (pusaka.isEmpty || by.side != Side.troop || took <= 0) return;
    for (final b in _bookOf(by)?[Trig.attack] ?? const <FxBound>[]) {
      if (b.fx.status == Status.link && b.k == link.k) _tally(b.relic).worth += took;
    }
  }

  /// A cap at 0 from fallen troop [by] ([Status.cap], Soul Shelter's) kept [kept] of a blow off a troop
  /// ([HeroSkills._afterDefence]): its counter.
  void _fxSheltered(Unit by, double kept) {
    if (pusaka.isEmpty || by.side != Side.troop || kept <= 0) return;
    for (final b in _bookOf(by)?[Trig.fell] ?? const <FxBound>[]) {
      if (b.fx.status == Status.cap) _tally(b.relic).worth += kept;
    }
  }

  /// [b]'s one-hit mark (Ember Brand) from troop [by] on monster [foe] ([Unit.emberMark]): [FxBound.k] for [Fx.time] s,
  /// shorter under the Bayangan Mark Ward ([Omens._omenMarkWard]), a new one over an old. The next direct blow on it from
  /// a troop of another type spends it ([_fxEmber]).
  void _fxMark(FxBound b, Unit by, Unit foe) {
    if (foe.side != Side.enemy || !foe.alive) return;
    foe.emberMark = (relic: b.relic, from: by.type, k: b.k, until: t + scaledEffectTime(b.fx.time, _omenMarkWard(foe)));
  }

  /// Troop [u] attacks [foe]: its [book]'s `always` range Fx (Hawk Feather) counts it ([PusakaTally.uses]) when [foe]
  /// stands farther than [u]'s reach without it (its range ÷ [FxBound.k]): an attack it makes from past its old reach.
  void _fxReach(FxBook book, Unit u, Unit foe) {
    for (final b in book[Trig.always]) {
      if (b.fx.stat == Stat.range && u.pos.distanceTo(foe.pos) > u.stats.range / b.k) _tally(b.relic).uses++;
    }
  }

  /// [b]'s status ([Fx.status]) from troop [by] on monster [foe], at [FxBound.k] (the boss: [FxBound.boss]) for
  /// [Fx.time] s; a taunt, which has no strength, for its k s, and only on a monster a taunt may hold ([_tauntable]); a
  /// bleed k of [hit] over [Fx.time] s, a tick a second (as Deep Wound's), unless a stronger bleed runs on [foe]; a hold,
  /// which has no strength, for its k s at [fxHoldWalk] (Ice Grip's [Status.impaled]: never over a pin that lasts longer,
  /// and the Bayangan Unbowed may shrug it off), on the boss and a mini boss a slow of [FxBound.boss] for [Fx.time] s
  /// instead. A hex, which has no strength, turns [foe] into a slime for its k s as Slime Hex does ([_hexInto]): never the
  /// boss, a mini boss or a monster Slime Hex passes over ([_fxHexable]), at most once every [FxBound.cd] s a troop
  /// ([_fxGate]; the Bayangan Unbowed's shrug spends it too). Its time goes through the duration scaler (the Bayangan
  /// Unshaken, [addEffect]). Whether it went on.
  bool _fxFoeStatus(FxBound b, Unit by, Unit foe, {double hit = 0}) {
    if (foe.side != Side.enemy || !foe.alive) return false;
    final k = foe.tier == Tier.boss ? b.boss : b.k;
    switch (b.fx.status!) {
      case Status.taunt:
        if (k <= 0 || !_tauntable(foe)) return false; // none on the boss (Warden's Horn's)
        addEffect(foe, Status.taunt, k, by: by);
      case Status.bleed:
        final ticks = b.fx.time.round(), tick = hit * k / ticks;
        if (tick <= 0 || effectK(foe, Status.bleed) > tick) return false; // a stronger one runs on
        addEffect(foe, Status.bleed, b.fx.time + 0.5, k: tick, by: by, n: ticks);
      case Status.impaled when foe.tier == Tier.boss || foe.tier == Tier.miniBoss:
        addEffect(foe, Status.slow, b.fx.time, k: b.boss, by: by); // the bosses: slowed, not held
      case Status.impaled:
        final pin = foe.effects[Status.impaled];
        if (pin != null && pin.until >= t + b.k) return false; // a longer pin runs on (Impale's)
        addEffect(foe, Status.impaled, b.k, k: fxHoldWalk, by: by);
        if (identical(foe.effects[Status.impaled], pin)) return false; // shrugged off (Unbowed, omen.dart)
      case Status.hex:
        if (!_fxHexable(foe) || !_fxGate(b, by)) return false;
        if (_omenShrug(foe)) return false; // shrugged off (Unbowed, omen.dart): the cooldown is spent
        _hexInto(foe, b.k, by);
      case final s:
        addEffect(foe, s, b.fx.time, k: k, by: by);
    }
    return true;
  }

  /// Whether an `attack` hex (Hex Blade's) may turn monster [foe] into a slime: not the boss nor a mini boss (by rank),
  /// nor one Slime Hex never picks ([HeroSkills._hexableType]), nor one a slime already (hexed, or born one).
  bool _fxHexable(Unit foe) =>
      foe.tier != Tier.boss &&
      foe.tier != Tier.miniBoss &&
      foe.type != slimeHexK.form &&
      _hexableType(foe) &&
      !foe.effects.containsKey(Status.hex);

  /// How many hits [b]'s Fx waits between its procs ([Fx.every]; 0 or 1: every hit): its own, and under the Bayangan Off
  /// Beat a Rare or Epic Artifact's every-few-hits Fx waits [Omens.omenOffBeat] more (never a Legendary one's, nor Twin
  /// Fury's beat, which is the worn fury's, [Fx.furyBeat]). Every hit-count gate reads it: [_attackK]'s (Bleeding Edge,
  /// Mana Leech and Spell Cutter's too) and [_fxNth]'s (Shatter Shard's landed hits, Riposte's hits taken).
  int _everyOf(FxBound b) {
    final every = b.fx.every;
    if (every <= 1 || b.fx.furyBeat || b.relic.rarity == Rarity.legenda) return every;
    return every + omenOffBeat;
  }

  /// Whether this one of [b]'s triggers on troop [u] is its every-Nth ([_everyOf]; one with none: each): it counts it on
  /// [Unit.fxN], the count of a `landed` or `hurtBy` Fx's every (Shatter Shard's hits landed, Riposte's taken; a type holds
  /// one Pusaka, so one Fx counts on it).
  bool _fxNth(FxBound b, Unit u) {
    final every = _everyOf(b);
    return every <= 1 || ++u.fxN % every == 0;
  }

  /// [b]'s own cooldown ([FxBound.cd]: [Fx.cd], a strip's k) on its holder [u] ([Unit.fxReady]): true when none is
  /// running, and the next one then runs that long from now; false while one runs. An Fx without one is always ready.
  /// Dulling Mail's (batch L-1P) was the first; batch L-2P's Shatter Shard, Pain Crystal and Spell Cutter wait here too.
  /// The Bayangan Drag stretches a Rare or Epic one's here ([Omens.omenDrag]).
  bool _fxGate(FxBound b, Unit u) {
    if (b.cd <= 0) return true;
    if (t < u.fxReady) return false;
    u.fxReady = t + b.cd * omenDrag(b.relic);
    return true;
  }

  /// [b]'s own cooldown for its whole type ([Game._fxTypeReady]: a fall's, whose troop is gone: Soul Shelter's, batch
  /// G-2): as [_fxGate], one clock for every troop of the type; a wave's start sets it ready.
  bool _fxTypeGate(FxBound b) {
    if (b.cd <= 0) return true;
    if (t < (_fxTypeReady[b.relic] ?? double.negativeInfinity)) return false;
    _fxTypeReady[b.relic] = t + b.cd * omenDrag(b.relic);
    return true;
  }

  /// [b]'s MP to troop [u]: [FxBound.k] of its max MP, never past it (Mana Leech, Pain Crystal). Its counter: the MP that
  /// landed.
  void _fxMp(FxBound b, Unit u) {
    final most = u.stats.mp.toDouble(), before = u.mp;
    u.mp = min(most, u.mp + most * b.k);
    _tally(b.relic)
      ..uses += 1
      ..worth += u.mp - before;
  }

  /// [b]'s strip from troop [u] on monster [foe] (Spell Cutter): its one good effect with the most time left, of the kinds
  /// Spellbreaker strips that no troop gave ([_stripsOff]), or its guard ([Unit.guardUntil]), comes off; where
  /// Spellbreaker only halves ([_halvesOnly]: the boss, a mini boss, a buff the boss rank gave) half of what is left goes,
  /// once. Its cooldown ([_fxGate]) starts only when there is one to take. Spellbreaker's silver rune ring marks it, and
  /// the Bayangan Renewal's shield comes on [foe] once ([Omens._omenRenewal]). Whether it took one.
  bool _fxStrip(FxBound b, Unit u, Unit foe) {
    if (foe.side != Side.enemy || !foe.alive) return false;
    Status? best;
    var left = 0.0;
    for (final MapEntry(key: s, value: e) in foe.effects.entries) {
      if (_stripsOff(foe, s, e) && e.until - t > left) (best, left) = (s, e.until - t);
    }
    final guard = foe.guardUntil - t > left && !(foe.guardHalved == foe.guardUntil && _halvesOnly(foe));
    if ((best == null && !guard) || !_fxGate(b, u)) return false;
    if (guard) {
      if (!_halvesOnly(foe)) {
        foe.guardUntil = t;
      } else {
        foe.guardUntil = foe.guardHalved = t + (foe.guardUntil - t) / 2;
      }
    } else {
      final e = foe.effects[best]!;
      if (!_halvesOnly(foe, e)) {
        foe.effects.remove(best);
      } else {
        e
          ..until = t + (e.until - t) / 2
          ..halved = true;
      }
    }
    rings.add(Ring(foe.pos, radius: spellbreakerK.mark, since: t, look: RingLook.dispel, duration: spellbreakerK.ring));
    _omenRenewal(foe); // Renewal: a shield once on a monster that lost one (omen.dart)
    return true;
  }

  /// A normal attack's blow or shot of troop [by] of [dmg] landed on [target]: its type's `landed` Fx (God's Thunder's
  /// leaps; Shatter Shard's burst on its every-Nth landed hit, [_fxNth], when a monster stands near and its cooldown is
  /// over).
  void _fxLanded(Unit by, Unit target, double dmg) {
    if (pusaka.isEmpty) return;
    final book = _bookOf(by);
    if (book == null) return;
    for (final b in book[Trig.landed]) {
      if (!_fxWhen(b, by, target)) continue;
      switch (b.fx.eff) {
        case Eff.leap:
          _leap(b, by, target, dmg);
        case Eff.burst:
          if (!_fxNth(b, by)) continue;
          final near = [for (final o in _foesNear(target.pos, b.fx.r)) if (o != target) o];
          if (near.isEmpty || !_fxGate(b, by)) continue;
          _burst(b, by, near, dmg);
        default:
          throw _unbuilt(b.fx);
      }
    }
  }

  /// [b]'s burst (Shatter Shard): each monster of [near] takes [FxBound.k] of [dmg] from [by], with [by]'s own hit burst
  /// on it. Extra damage: only `dealt` runs in it ([Game._fxDepth]).
  void _burst(FxBound b, Unit by, List<Unit> near, double dmg) {
    final tally = _tally(b.relic)..uses += 1;
    _fxDepth++;
    try {
      for (final o in near) {
        impacts.add((o.pos, _fxOf(by, 'hit_${by.type}')));
        tally.worth += _hurt(o, dmg * b.k, Hit.extra, by);
      }
    } finally {
      _fxDepth--;
    }
  }

  /// [b]'s leaps (God's Thunder): from [target] to the [FxBound.count] nearest other monsters within [Fx.r], each
  /// taking [FxBound.k] of [dmg] from [by], each a yellow [Beam] ([BeamLook.thunder], as long as a chain's) with the
  /// wizard's spark, at most [godThunderK].beamsPerSec drawn a second over the field. Extra damage: only `dealt` runs
  /// in it ([Game._fxDepth]).
  void _leap(FxBound b, Unit by, Unit target, double dmg) {
    for (final o in _foesNear(target.pos, b.fx.r).where((o) => o != target).take(b.count).toList()) {
      _thunderLooks.removeWhere((at) => t - at >= 1);
      if (_thunderLooks.length < godThunderK.beamsPerSec) {
        _thunderLooks.add(t);
        beams.add(Beam([target.pos, o.pos], since: t, duration: chainBeamTime, look: BeamLook.thunder));
        impacts.add((o.pos, 'hit_wizard'));
      }
      _fxDepth++;
      try {
        _tally(b.relic).worth += _hurt(o, dmg * b.k, Hit.extra, by);
      } finally {
        _fxDepth--;
      }
    }
  }

  // Inside a blow ([Game._hurt]).

  /// Troop [by]'s blow of [dmg] on monster [u], before its defence (every blow of its own, a skill's or a bleed's too;
  /// never extra damage, [Game._fxDepth]): [book]'s `pierce` Fx, a power while its condition holds (Titan Bane on the
  /// boss and a mini boss, Finishing Blade under a share of HP, First Cut over one, the HP before the blow). Its counter:
  /// the blows and the damage it added before the monster's defence. The new [dmg].
  double _fxPierce(FxBook book, Unit by, Unit u, double dmg) {
    for (final b in book[Trig.pierce]) {
      if (!_fxWhen(b, by, u)) continue;
      switch (b.fx.eff) {
        case Eff.power:
          _tally(b.relic)
            ..uses += 1
            ..worth += dmg * (b.k - 1);
          dmg *= b.k;
        default:
          throw _unbuilt(b.fx);
      }
    }
    return dmg;
  }

  /// Troop [by]'s blow of [dmg] on monster [u], before its defence: [u]'s one-hit mark ([Unit.emberMark], Ember Brand's)
  /// while it runs, from a troop of another type than the one that marked it, on a direct blow (a normal attack, a smite
  /// or a skill's; never extra damage, a hit back or a bleed): the blow does ×its k and spends it. A mark run out goes.
  /// Its counter: the marks spent and the damage they added before the monster's defence. The new [dmg].
  double _fxEmber(Unit u, Unit by, double dmg, Hit src) {
    final m = u.emberMark!;
    if (t >= m.until) {
      u.emberMark = null;
      return dmg;
    }
    if (by.type == m.from || !const {Hit.normal, Hit.smite, Hit.skill}.contains(src)) return dmg;
    u.emberMark = null;
    _tally(m.relic)
      ..uses += 1
      ..worth += dmg * (m.k - 1);
    return dmg * m.k;
  }

  /// Troop [u] takes [dmg] from [by] after its defence: its [book]'s `struck` Fx (Iron Banner's cut, weaker under the
  /// Bayangan Sunder, [Omens._omenSunder]; a `cleanse` of itself, Salt Charm's: while a monster's bad effect is on it, at
  /// most once every [FxBound.cd] s, the cooldown starting only when there was one to end; MP to itself, [_fxMp], at most
  /// once every [Fx.cd] s: Pain Crystal). A cut under 0 is more damage taken (Vengeance Mark's trade): no Sunder on it,
  /// nothing counted. A block: every [Fx.every]th blow of a monster on it ([_fxNth]; not a bleed's tick) does nothing
  /// (Ghost Step's; its counter the blows' damage), and the new [dmg] is null. A `struck` heal waits for the blow to land
  /// ([_fxStruckAfter]). A [bare] blow (the Bayangan Executioner's, [Omens._omenBare]) meets no cut and no block (a block's
  /// count still goes on); the other rows still act. The new [dmg].
  double? _fxStruck(FxBook book, Unit u, Unit? by, double dmg, Hit src, {bool bare = false}) {
    for (final b in book[Trig.struck]) {
      if (b.fx.eff == Eff.heal || !_fxWhen(b, u, by)) continue;
      switch (b.fx.eff) {
        case Eff.cut:
          if (bare && b.k > 0) continue;
          final cut = dmg * b.k * (b.k > 0 ? _omenSunder(u) : 1);
          if (cut > 0) _tally(b.relic).worth += cut; // the damage it kept off
          dmg -= cut;
        case Eff.status when b.fx.status == Status.block:
          if (by?.side != Side.enemy || src == Hit.bleed || !_fxNth(b, u) || bare) continue;
          _tally(b.relic)
            ..uses += 1
            ..worth += dmg; // the blow it kept off
          impacts.add((u.pos, 'hit_${u.type}'));
          return null;
        case Eff.cleanse:
          if (badOn(u) == 0 || !_fxGate(b, u)) continue; // nothing to end: no cooldown either
          _tally(b.relic).uses += cleanse(u, most: b.count > 0 ? b.count : null); // its [Fx.count] by stars (none: all)
        case Eff.mp:
          if (dmg > 0 && _fxGate(b, u)) _fxMp(b, u);
        default:
          throw _unbuilt(b.fx);
      }
    }
    return dmg;
  }

  /// Troop [u] lived through a blow from [by] ([Game._hurt], its HP already down): its [book]'s `struck` heal, Hidden
  /// Flask's: once a wave ([belowOnce], on its Fx's own bit), when the blow left it under [Fx.ifK] of its max HP, it
  /// heals [FxBound.k] of its max HP through the heal funnel, with the heal's sparkle. A blow that fells it heals nothing.
  void _fxStruckAfter(FxBook book, Unit u, Unit? by) {
    for (final b in book[Trig.struck]) {
      if (b.fx.eff != Eff.heal || !_fxWhen(b, u, by) || !belowOnce(u, b.fx.ifK, b.index)) continue;
      _healTroop(u, u.maxHp * b.k, HealSrc.pusaka);
      _tally(b.relic)
        ..uses += 1
        ..worth += _healGained; // what it gave (heal.dart)
      impacts.add((u.pos, 'heal'));
    }
  }

  /// Troop [u] takes [dmg] from [by] after every other cut (its defence, the guards, a mark or a curse, a Grail save's or
  /// Bastion's [Status.cap], what a veil soaks): its [book]'s `capped` Fx. Dragon Crown's cap: no blow takes more than
  /// [FxBound.k] of its max HP; its own check, not a [Status.cap] (critique M3): a cap effect ends with the wave, and a
  /// Grail save's would replace it. Its counter: the blows it cut ([PusakaTally.uses]) and the HP that kept
  /// ([PusakaTally.worth]). The new [dmg].
  double _fxCapped(FxBook book, Unit u, Unit? by, double dmg) {
    for (final b in book[Trig.capped]) {
      if (!_fxWhen(b, u, by)) continue;
      switch (b.fx.eff) {
        case Eff.cap:
          final most = u.maxHp * b.k;
          if (dmg <= most) continue;
          final tally = _tally(b.relic);
          tally
            ..uses += 1
            ..worth += max(0.0, min(dmg, u.hp) - most); // the HP the cut kept
          dmg = most;
        default:
          throw _unbuilt(b.fx);
      }
    }
    return dmg;
  }

  /// The Pusaka's counters of a blow on [u] (of HP it had: [hpBefore]) that took [dealt], from [by] ([ub], [bb]: their
  /// books): an `always` HP Fx's blows lived through (the blow took its troop past the HP its base would have had, and
  /// it lived: Dragon Heart), an `always` attack Fx's extra damage (Dawn Star; Vow of Silence's with its HP), and a mark's
  /// bonus (every troop's hit on
  /// a monster a [fxMarks] Pusaka marked: Void Eye), before a new mark.
  void _fxCounters(Unit u, Unit? by, FxBook? ub, FxBook? bb, double dealt, double hpBefore) {
    if (dealt <= 0) return;
    if (u.side == Side.troop) {
      if (ub == null || u.hp <= 0) return;
      for (final b in ub[Trig.always]) {
        if (b.fx.stat != Stat.hp || b.k <= 1) continue; // a trade's max HP down (Moonwell's) lives through nothing
        final extra = u.maxHp * (1 - 1 / b.k);
        if (hpBefore > extra && u.hp <= extra) _tally(b.relic).worth++;
      }
      return;
    }
    if (by == null || by.side != Side.troop) return;
    for (final b in bb?[Trig.always] ?? const <FxBound>[]) {
      if ((b.fx.stat == Stat.dmg || b.fx.stat == Stat.hpDmg) && b.k > 1) _tally(b.relic).worth += dealt * (1 - 1 / b.k); // a trade (k under 1) adds none
    }
    if (u.effects.isEmpty) return;
    for (final (status, relic) in fxMarks) {
      if (!pusaka.containsKey(relic)) continue;
      final k = effectK(u, status);
      if (k > 1) _tally(relic).worth += dealt * (1 - 1 / k);
    }
  }

  /// Troop [by] took [dealt] off [u]: its [book]'s `dealt` Fx (Blood Fang's heal of [dealt]'s share, Void Eye's mark
  /// on a monster, [Status.voidMark], apart from Hunter's Mark's [Status.vulnerable]; Witherroot's weaken on a living
  /// monster ([_fxFoeStatus], the boss's [FxBound.boss]), counted when it had no weaken before, not when it refreshes one;
  /// a `noHeal` on a living monster for [FxBound.k] s (a noHeal has no strength: its k is its time, which Carve moves;
  /// Grave Seal's, batch G-3): [Status.noHeal] from [by], put on before a killing blow's Reassemble asks, a new one over
  /// an old; its counter the monsters it sealed fresh, and the HP of the heals the seals stopped ([_fxSealed]). The
  /// heal of [FxBound.k] of [dealt] on the most hurt other living troop within [Fx.r] of [by] ([_fxMostHurt], Vampire
  /// Kiss's, batch G-3), through the heal funnel, the heal's sparkle on it; its counter the HP it gave.
  void _fxDealt(FxBook book, Unit by, Unit u, double dealt) {
    for (final b in book[Trig.dealt]) {
      if (!_fxWhen(b, by, u)) continue;
      switch (b.fx) {
        case Fx(eff: Eff.heal, to: To.self):
          if (dealt <= 0) continue;
          _healTroop(by, dealt * b.k, HealSrc.pusaka);
          _tally(b.relic).worth += _healGained; // what it gave (heal.dart)
        case Fx(eff: Eff.heal, to: To.mostHurtNear):
          if (dealt <= 0) continue;
          final o = _fxMostHurt(by, b.fx.r);
          if (o == null) continue;
          _healTroop(o, dealt * b.k, HealSrc.pusaka);
          if (_healGained <= 0) continue;
          _tally(b.relic)
            ..uses += 1
            ..worth += _healGained; // what it gave (heal.dart)
          impacts.add((o.pos, 'heal'));
        case Fx(eff: Eff.status, to: To.foeHit, status: Status.weaken):
          final fresh = u.side == Side.enemy && effectOn(u, Status.weaken) == null;
          if (_fxFoeStatus(b, by, u) && fresh) _tally(b.relic).uses++;
        case Fx(eff: Eff.status, to: To.foeHit, :final status?):
          if (u.side == Side.enemy && u.alive) addEffect(u, status, b.fx.time, k: u.tier == Tier.boss ? b.boss : b.k);
        case Fx(eff: Eff.noHeal, to: To.foeHit):
          if (u.side != Side.enemy || !u.alive) continue;
          if (!under(u, Status.noHeal)) _tally(b.relic).uses++; // a monster sealed fresh
          addEffect(u, Status.noHeal, b.k, by: by);
        default:
          throw _unbuilt(b.fx);
      }
    }
  }

  /// The most hurt living troop within [r] of troop [u], not [u] (the lowest share of its max HP; alike, the nearest),
  /// below its heal ceiling ([healCeil]: the Bayangan Scar's, or full): a `dealt` heal's (Vampire Kiss's). Null: none.
  Unit? _fxMostHurt(Unit u, double r) {
    Unit? worst;
    for (final o in _alliesNear(u.pos, r)) {
      if (o == u || o.hp >= healCeil(o)) continue;
      final share = o.hp / o.maxHp, was = worst == null ? 2.0 : worst.hp / worst.maxHp;
      if (share < was || (share == was && o.pos.distanceTo(u.pos) < worst!.pos.distanceTo(u.pos))) worst = o;
    }
    return worst;
  }

  /// A heal of [lost] HP that monster [u] didn't get under a troop's [Status.noHeal] ([Heal._healMonster]): the counter
  /// of the `dealt` noHeal Fx (Grave Seal's) of the troop type that sealed it.
  void _fxSealed(Unit u, double lost) {
    final by = effectOn(u, Status.noHeal)?.by;
    if (lost <= 0 || by == null || by.side != Side.troop) return;
    for (final b in _bookOf(by)?[Trig.dealt] ?? const <FxBound>[]) {
      if (b.fx.eff == Eff.noHeal) _tally(b.relic).worth += lost;
    }
  }

  /// Troop [u] took [dealt] from [by] (null: no attacker, a bleed's or a reflect's): its [book]'s `hurtBy` Fx. A status
  /// on a living monster attacker that took HP off it (Dulling Mail's weaken, [_fxFoeStatus]), at most once every
  /// [Fx.cd] s a troop ([_fxGate]); on its every-Nth such blow ([_fxNth]) a hit back of [FxBound.k] of [u]'s attack
  /// (Riposte's, on a monster that fights up close): a [Hit.hitBack] with no attacker, so nothing answers it. A strip
  /// of that monster (Null Stone's): its good effects and its guard come off as Spellbreaker's arrow takes them
  /// ([AwakenSkills._strip]: the boss and a mini boss lose half of what is left, once), at most once every [FxBound.cd]
  /// s a troop, the cooldown starting only when it held one ([_fxStrippable]); Spellbreaker's silver rune ring marks it.
  void _fxHurtBy(FxBook book, Unit u, Unit? by, double dealt) {
    for (final b in book[Trig.hurtBy]) {
      if (!_fxWhen(b, u, by)) continue;
      switch (b.fx) {
        case Fx(eff: Eff.status, to: To.attacker):
          if (by == null || by.side != Side.enemy || !by.alive || dealt <= 0 || !_fxGate(b, u)) continue;
          if (_fxFoeStatus(b, u, by)) _tally(b.relic).uses++;
        case Fx(eff: Eff.burst, to: To.attacker):
          if (by == null || by.side != Side.enemy || !by.alive || dealt <= 0 || !_fxNth(b, u) || !_fxGate(b, u)) continue;
          impacts.add((by.pos, _fxOf(u, 'hit_${u.type}')));
          final tally = _tally(b.relic)..uses += 1;
          tally.worth += _hurt(by, u.stats.dmg * b.k, Hit.hitBack);
        case Fx(eff: Eff.strip, to: To.attacker):
          if (by == null || by.side != Side.enemy || !by.alive || dealt <= 0 || !_fxStrippable(by) || !_fxGate(b, u)) continue;
          _strip(by);
          rings.add(Ring(by.pos, radius: spellbreakerK.mark, since: t, look: RingLook.dispel, duration: spellbreakerK.ring));
          _tally(b.relic).uses++;
        default:
          throw _unbuilt(b.fx);
      }
    }
  }

  /// Troop [u] took a killing blow (from [by]): its [book]'s `lethal` Fx. The Grail's save: the first this wave ([Unit.fxOnce])
  /// leaves it at [FxBound.k] of its max HP, and no blow hurts it for [Fx.time] s (the cap on one blow at 0, Bastion's
  /// status). The save is kept once it lives [keptAfter] s more ([Pusaka._watchGrail]).
  void _fxLethal(FxBook book, Unit u, Unit? by) {
    for (final b in book[Trig.lethal]) {
      if (!_fxWhen(b, u, by)) continue;
      switch (b.fx.eff) {
        case Eff.save:
          if (u.fxOnce) continue;
          u
            ..fxOnce = true
            ..hp = 0; // the save lifts it from nothing (heal.dart: never under Wound)
          _healTroop(u, max(1.0, u.maxHp * b.k), HealSrc.grail);
          addEffect(u, Status.cap, b.fx.time, k: 0);
          impacts.add((u.pos, 'holy'));
          sfx.add(Sfx.clear);
          if (++_tally(b.relic).uses == 1) grailFirst = u; // the wave's first: its cut-in (pusaka_look.dart)
          _grailWatch.add((u, t, b.relic));
          _emit(GrailSaved(wave, t, name: u.name, type: u.type, hero: u.hero));
        default:
          throw _unbuilt(b.fx);
      }
    }
  }

  /// Troop [u] fell (to [by]): its [book]'s `fell` Fx. Mourning Bell: every other troop within [Fx.r] of it heals [FxBound.k] of
  /// its max HP. Fallen Flag: every other living troop within [Fx.r] of it deals ×[FxBound.k] for [Fx.time] s (a might
  /// from the fallen one; a stronger might already on one stays, [HeroSkills.addEffect]); its counter: the troops it
  /// gave one. Martyr's Flame: every monster within [Fx.r] of it takes [FxBound.k] of its max HP, from it ([_burst]:
  /// extra damage, through each one's defence). Soul Shelter: every living troop within [Fx.r] of it takes no damage for
  /// [FxBound.k] s (a [Status.cap] at 0 from it, the Grail save's window; a longer one on a troop stays), at most once
  /// every [FxBound.cd] s for the type ([_fxTypeGate], starting only when one stood near); its counter: the troops it
  /// sheltered and what the window kept off ([_fxSheltered]). Phoenix Plume: once a wave the type's first to fall
  /// ([If.firstOfTypeThisWave]) rises again [Fx.time] s later ([_fxRise]); a Hero, or a troop brought back before
  /// ([Unit.revived]), is passed over before the condition asks, so the once is kept for the next.
  void _fxFell(FxBook book, Unit u, Unit? by) {
    for (final b in book[Trig.fell]) {
      if (b.fx.eff == Eff.revive && (u.hero || u.revived)) continue; // never a Hero, nor twice (Resurrection's rule)
      if (!_fxWhen(b, u, by)) continue;
      switch (b.fx) {
        case Fx(eff: Eff.heal, to: To.nearTroops):
          _tally(b.relic).uses++;
          for (final o in _alliesNear(u.pos, b.fx.r)) {
            if (o == u || o.hp >= healCeil(o)) continue; // at its heal ceiling: Scar's (omen.dart)
            _healTroop(o, o.maxHp * b.k, HealSrc.pusaka);
            _tally(b.relic).worth += _healGained; // what it gave (heal.dart)
            impacts.add((o.pos, 'heal'));
          }
        case Fx(eff: Eff.status, to: To.nearTroops, status: Status.might):
          for (final o in _alliesNear(u.pos, b.fx.r)) {
            if (o == u) continue;
            addEffect(o, Status.might, b.fx.time, k: b.k, by: u);
            if (effectOn(o, Status.might)?.by == u) _tally(b.relic).uses++;
          }
        case Fx(eff: Eff.burst, to: To.nearFoes):
          final near = _foesNear(u.pos, b.fx.r);
          if (near.isNotEmpty) _burst(b, u, near, u.maxHp.toDouble());
        case Fx(eff: Eff.status, to: To.nearTroops, status: Status.cap):
          final near = _alliesNear(u.pos, b.fx.r);
          if (near.isEmpty || !_fxTypeGate(b)) continue;
          for (final o in near) {
            if (effectOn(o, Status.cap) case final e? when e.k <= 0 && e.until >= t + b.k) continue; // a longer window (the Grail's)
            addEffect(o, Status.cap, b.k, k: 0, by: u);
            impacts.add((o.pos, 'holy'));
            _tally(b.relic).uses++;
          }
        case Fx(eff: Eff.revive, to: To.self):
          _risesDue++; // the army isn't wiped while it is due (wipe.dart)
          later(b.fx.time, () {
            _risesDue--;
            _fxRise(b, u);
          }); // a wave's end drops it ([HeroSkills.later])
        default:
          throw _unbuilt(b.fx);
      }
    }
  }

  /// [b]'s rise (Phoenix Plume) of fallen troop [dead], [Fx.time] s after its fall, by Resurrection's way
  /// ([HeroSkills._castHeroSkill]): a new troop of its type, name and post where it fell, at [FxBound.k] of its max HP,
  /// no MP, never brought back again ([Unit.revived]), rising as a raised minion does; it leaves [fallen] and the UI names
  /// it ([Game.risen]). Nothing while the wave isn't on, the game is over, it was brought back already (Resurrection), or
  /// its type may take no troop now ([Game.typeRefusal]). Its counter: the troops back.
  void _fxRise(FxBound b, Unit dead) {
    if (over || !waveActive || !fallen.contains(dead) || typeRefusal(dead.type) != null) return;
    final r = _newTroop(dead.type, dead.pos, dead.name);
    r
      ..post = dead.post
      ..hp = r.maxHp * b.k
      ..mp = 0
      ..revived = true
      ..busyFrom = t
      ..busyUntil = t + riseTime; // it rises like a raised minion
    raised.add(r); // joins after the update loop
    fallen.remove(dead);
    _autoRose(dead); // Auto no longer buys it back (auto_replace.dart)
    risen.add(r);
    impacts
      ..add((r.pos, awakeFx('summon', maxAwaken))) // Resurrection's gold summon circle
      ..add((r.pos, 'holy'));
    sfx.add(Sfx.magic);
    _tally(b.relic)
      ..uses += 1
      ..worth += 1;
  }

  /// Troop [by] killed monster [u]: its [book]'s `kill` Fx. A charge of power on its next normal attack (Momentum's,
  /// [Unit.charge]: a stronger one kept), a shield ([Heal.giveWard]: Bone Buckler's [FxBound.k] of its max HP, up to
  /// [FxBound.count] kills' worth), [u]'s gold × [FxBound.k] ([_fxGold]: Looter's Pouch), a heal of [FxBound.k] of its
  /// max HP through the heal funnel (Wolf Feast's); a burst of [FxBound.k] of the killing [blow] (as it was before [u]'s
  /// defence) on every other monster within [Fx.r] of [u], at most once every [Fx.cd] s a troop, the cooldown starting
  /// only when one stood near ([_burst]: Funeral Pyre's; extra damage, so the kills in it set off no `kill` Fx); a might
  /// of [FxBound.k] for [Fx.time] s on every living troop of its type when [u] is a high elite, a mini boss or the boss
  /// (Glory Seeker's; a stronger might already on one stays), its counter the kills that gave one.
  void _fxKill(FxBook book, Unit by, Unit u, double blow) {
    for (final b in book[Trig.kill]) {
      if (!_fxWhen(b, by, u)) continue;
      switch (b.fx.eff) {
        case Eff.power:
          if ((by.charge?.k ?? 0) < b.k) by.charge = (relic: b.relic, k: b.k);
        case Eff.ward:
          if (!by.alive) continue;
          giveWard(by, by.maxHp * b.k, most: b.k * max(1, b.count), from: b.relic);
          _tally(b.relic).uses++;
        case Eff.gold:
          _fxGold(b, u);
        case Eff.heal:
          if (!by.alive) continue;
          _healTroop(by, by.maxHp * b.k, HealSrc.pusaka);
          _tally(b.relic)
            ..uses += 1
            ..worth += _healGained; // what it gave (heal.dart: Wound and Scar take theirs, a Trickle heal counts in full)
        case Eff.burst:
          final near = [for (final o in _foesNear(u.pos, b.fx.r)) if (o != u) o];
          if (near.isEmpty || blow <= 0 || !_fxGate(b, by)) continue;
          _burst(b, by, near, blow);
        case Eff.status when b.fx.to == To.type && b.fx.status == Status.might:
          var gave = false;
          for (final o in troops) {
            if (!o.alive || o.type != by.type) continue;
            addEffect(o, Status.might, b.fx.time, k: b.k, by: by);
            gave |= effectOn(o, Status.might)?.by == by;
          }
          if (gave) _tally(b.relic).uses++;
        default:
          throw _unbuilt(b.fx);
      }
    }
  }

  /// [b]'s gold for monster [dead] killed (Looter's Pouch): [FxBound.k] − 1 of what it paid (its gold after the Bayangan
  /// Thrift, [Omens._omenGold]), whole coins as they add up ([Game._goldBits]), each floated by the UI as Plunder's is
  /// ([goldPops]). Its counter: the coins paid.
  void _fxGold(FxBound b, Unit dead) {
    if (dead.stats.cost <= 0) return; // raised skeletons pay nothing
    _goldBits += _omenGold(dead.stats.cost) * (b.k - 1);
    final coins = _goldBits.floor();
    if (coins <= 0) return;
    _goldBits -= coins;
    gold += coins;
    goldPops.add((dead.pos, coins));
    _tally(b.relic)
      ..uses += 1
      ..worth += coins;
  }

  /// Troop [u]'s ward soaked [lost] of a blow ([Heal._wardSoak]): the counter of the Pusaka whose shield it is, the last
  /// to give it ([Unit.wardFrom]: its own type's Watch Shield or Bone Buckler, or a healer's Full Cup): the damage it kept
  /// off.
  void _fxWardSoaked(Unit u, double lost) {
    if (u.wardFrom case final r? when pusaka.containsKey(r)) _tally(r).worth += lost;
  }

  /// Troop [u]'s MP regen gave it [gain] MP ([Game.tick]): the counter of its type's `always` MP regen Fx (Moonwell's),
  /// the part its × added ([gain] × (1 − 1 / k)).
  void _fxMpRegen(Unit u, double gain) {
    for (final b in _bookOf(u)?[Trig.always] ?? const <FxBound>[]) {
      if (b.fx.stat == Stat.mpRegen && b.k > 1) _tally(b.relic).worth += gain * (1 - 1 / b.k);
    }
  }

  /// A blow of [raw] on troop [u] came through its defence as [taken] ([Game._hurt]): the counter of its [book]'s
  /// `always` defence Fx (Stone Coat's): what its [FxBound.k] defence kept off that blow.
  void _fxDefence(FxBook book, Unit u, double raw, double taken) {
    for (final b in book[Trig.always]) {
      if (b.fx.stat == Stat.def) _tally(b.relic).worth += hitTaken(raw, max(0.0, u.stats.def - b.k)) - taken;
    }
  }

  /// Troop [u]'s regen gave it [gain] HP ([Game.tick]): the counter of its type's `always` regen Fx (Living Moss's), by
  /// that Fx's share of [u]'s whole regen.
  void _fxRegen(Unit u, double gain) {
    for (final b in _bookOf(u)?[Trig.always] ?? const <FxBound>[]) {
      if (b.fx.stat == Stat.regen) _tally(b.relic).worth += gain * min(1.0, u.maxHp * b.k / u.stats.regen);
    }
  }

  // Outside a blow.

  /// A heal of troop healer [u] of [heal] gave [o] [gain] HP and [past] past its full HP ([Heal._healTroop]): the counter
  /// of its `always` attack Fx (Dawn Star's: what landed past the base heal), and its `heals` Fx: a shield on [o] of
  /// [FxBound.k] of the heal past full, up to [Fx.cap] of its max HP (Full Cup's, [Heal.giveWard]); a cleanse of [o],
  /// while a monster's bad effect is on it, at most once every [FxBound.cd] s a healer, the cooldown starting only when
  /// there was one to end (Pure Water's); [FxBound.k] of [o]'s max MP to it ([_fxMp]: Mana Hymn's, while it lacks some);
  /// a might of [FxBound.k] on [o] for [Fx.time] s (Brave Song's; a stronger might already on it stays); [FxBound.k] of
  /// [heal] to each of the [FxBound.count] troops nearest [o] within [Fx.r] of it that lack HP, through the heal funnel
  /// (Halo Lantern's; no chain: their heals set off no `heals` Fx); a smite of [FxBound.k] of [heal] on each monster
  /// within [Fx.r] of [o] (Wrath Psalm's, batch G-3, [_fxPsalm]), at most once every [FxBound.cd] s a healer, the
  /// cooldown starting only when one stood near. A heal that gave neither (one on a troop at its heal ceiling, the
  /// Bayangan Scar's; one the Bayangan Blight stopped) runs none. A `heals` Fx on itself (Mercy Lily's) is the heal a
  /// troop gets, never one it gives ([_fxLily]).
  void _fxHealed(Unit u, Unit o, double gain, double heal, double past) {
    final book = _bookOf(u);
    if (book == null || (gain <= 0 && past <= 0)) return;
    if (gain > 0) {
      for (final b in book[Trig.always]) {
        if (b.fx.stat == Stat.dmg || b.fx.stat == Stat.hpDmg) _tally(b.relic).worth += max(0.0, gain - heal / b.k);
      }
    }
    for (final b in book[Trig.heals]) {
      if (b.fx.to == To.self || !_fxWhen(b, u, o, past: past)) continue; // a heal got (Mercy Lily's): the funnel's
      switch (b.fx) {
        case Fx(eff: Eff.ward, to: To.healed):
          if (o.alive && giveWard(o, past * b.k, most: b.fx.cap, from: b.relic) > 0) _tally(b.relic).uses++;
        case Fx(eff: Eff.cleanse, to: To.healed):
          if (badOn(o) == 0 || !_fxGate(b, u)) continue; // nothing to end: no cooldown either
          _tally(b.relic).uses += cleanse(o, most: b.count > 0 ? b.count : null);
        case Fx(eff: Eff.mp, to: To.healed):
          if (o.alive && o.mp < o.stats.mp) _fxMp(b, o);
        case Fx(eff: Eff.status, to: To.healed, status: Status.might):
          if (!o.alive) continue;
          addEffect(o, Status.might, b.fx.time, k: b.k, by: u);
          if (effectOn(o, Status.might)?.by == u) _tally(b.relic).uses++;
        case Fx(eff: Eff.heal, to: To.nearTroops):
          final near = [for (final n in _alliesNear(o.pos, b.fx.r)) if (n != o && n.hp < healCeil(n)) n]
            ..sort((a, c) => a.pos.distanceTo(o.pos).compareTo(c.pos.distanceTo(o.pos)));
          if (heal <= 0 || near.isEmpty) continue;
          final tally = _tally(b.relic)..uses += 1;
          for (final n in near.take(max(1, b.count))) {
            _healTroop(n, heal * b.k, HealSrc.pusaka);
            tally.worth += _healGained; // what it gave (heal.dart)
            impacts.add((n.pos, 'heal'));
          }
        case Fx(eff: Eff.burst, to: To.nearFoes):
          final near = _foesNear(o.pos, b.fx.r);
          if (heal <= 0 || near.isEmpty || !_fxGate(b, u)) continue;
          _fxPsalm(b, u, near, heal * b.k);
        default:
          throw _unbuilt(b.fx);
      }
    }
  }

  /// [b]'s smite (Wrath Psalm) from troop healer [by]: each monster of [near] takes [dmg] as a healer's holy light
  /// ([Hit.smite], as [Game._smite]'s: it ends a heap of bones; the Bayangan Holy Ward cuts it on a skeleton), the holy
  /// flash on it. Extra damage: only `dealt` runs in it ([Game._fxDepth]). Its counter: the heals that smote, and the
  /// damage.
  void _fxPsalm(FxBound b, Unit by, List<Unit> near, double dmg) {
    final tally = _tally(b.relic)..uses += 1;
    _fxDepth++;
    _holy = true; // holy light, as [MonsterSkillSignatures._holyHurt]
    try {
      for (final m in near) {
        impacts.add((m.pos, 'holy'));
        tally.worth += _hurt(m, dmg, Hit.smite, by);
      }
    } finally {
      _holy = false;
      _fxDepth--;
    }
  }

  /// A heal from [src] is about to land on troop [u] ([Heal._healTroop], before Wound): its type's `heals` Fx on itself
  /// (Mercy Lily's) while [u] is under [Fx.ifK] of its max HP (before the heal), or always (Rage Totem's trade, a k under
  /// 1), which makes the heal ×[FxBound.k]; null for none, and never on the Grail's save or the after-wave heal. The
  /// funnel counts what a k over 1 added.
  FxBound? _fxLily(Unit u, HealSrc src) {
    if (src == HealSrc.grail || src == HealSrc.queue) return null;
    for (final b in _bookOf(u)?[Trig.heals] ?? const <FxBound>[]) {
      if (b.fx.to == To.self && b.fx.eff == Eff.heal && _fxWhen(b, u, null)) return b;
    }
    return null;
  }

  /// Troop [u] cast a skill (its own, its awakening's or a Hero's): its type's `cast` Fx. A might on [u] of [FxBound.k]
  /// for [Fx.time] s (Rune Gauntlet's; a stronger might already on it stays, [HeroSkills.addEffect]). Its counter: the
  /// mights it gave. A shield of [FxBound.k] of its max HP, up to that much ([Heal.giveWard], never past [wardMax]:
  /// Aegis Seal's); its counter: the casts it shielded, and what the shield soaks ([_fxWardSoaked]). A heal of
  /// [FxBound.k] of each one's max HP on it and the troops within [Fx.r] ([_fxHealNear]: Bright Spring's). A cleanse of it
  /// and the troops within [Fx.r] (Saint's Tear's: every bad effect a monster put on them, or [FxBound.count]), at most
  /// once every [FxBound.cd] s, the cooldown starting only when one of them had one to end; its counter: the bad effects
  /// it ended. [FxBound.k] of each other troop's max MP to it within [Fx.r] (Mana Font's, [_fxMp]: one that has MP to
  /// fill and casts, so not under Vow of Silence); its counter: the MP it gave.
  void _fxCast(Unit u) {
    if (pusaka.isEmpty) return;
    for (final b in _bookOf(u)?[Trig.cast] ?? const <FxBound>[]) {
      if (!_fxWhen(b, u, null)) continue;
      switch (b.fx) {
        case Fx(eff: Eff.status, to: To.self, status: Status.might):
          if (!u.alive) continue;
          addEffect(u, Status.might, b.fx.time, k: b.k, by: u);
          _tally(b.relic).uses++;
        case Fx(eff: Eff.ward, to: To.self):
          if (u.alive && giveWard(u, u.maxHp * b.k, most: b.k, from: b.relic) > 0) _tally(b.relic).uses++;
        case Fx(eff: Eff.heal, to: To.nearTroops):
          if (u.alive) _fxHealNear(b, u.pos, (o) => o.maxHp * b.k);
        case Fx(eff: Eff.mp, to: To.nearTroops):
          if (!u.alive) continue;
          for (final o in _alliesNear(u.pos, b.fx.r)) {
            if (o == u || o.stats.mp <= 0 || o.mp >= o.stats.mp || _silent(o.type)) continue;
            _fxMp(b, o);
            impacts.add((o.pos, awakeFx('heal', 1))); // the heal burst in MP blue (Mana Shield's)
          }
        case Fx(eff: Eff.cleanse, to: To.nearTroops):
          final bad = [for (final o in _alliesNear(u.pos, b.fx.r)) if (badOn(o) > 0) o];
          if (!u.alive || bad.isEmpty || !_fxGate(b, u)) continue; // nothing to end: no cooldown either
          final tally = _tally(b.relic);
          for (final o in bad) {
            tally.uses += cleanse(o, most: b.count > 0 ? b.count : null);
          }
        default:
          throw _unbuilt(b.fx);
      }
    }
  }

  /// A wave starts ([Game.startWave]) or is won ([Game.tick]'s win, [end]): each living troop's `waveStart` or
  /// `waveEnd` Fx: a shield of [FxBound.k] of its max HP at the start ([Heal.giveWard]: Watch Shield's; the wave's end
  /// clears it); a stand against the monsters' shoves for the whole wave ([Status.noShove] given by the troop itself, so
  /// it never ends before the wave does and another troop still moves it, [Game._firm]: Anchor's; its counter, the shoves
  /// it stood, [_fxStood]); a reflect of [FxBound.k] of every up-close blow for the whole wave, given by the troop itself
  /// (Mirror Shield's; its counter what it sent back, [_fxMirrored]; back after a stronger one ends, [_fxReflectBack]); at
  /// the end a heal up to [FxBound.k] of its max HP (never past full) through the heal funnel,
  /// a heal between waves (Hearth's; its counter: the troops it healed and the HP it gave). A troop bought mid-wave misses
  /// the start.
  void _fxWave({bool end = false}) {
    if (pusaka.isEmpty) return;
    for (final u in troops) {
      if (!u.alive) continue;
      for (final b in _bookOf(u)?[end ? Trig.waveEnd : Trig.waveStart] ?? const <FxBound>[]) {
        if (!_fxWhen(b, u, null)) continue;
        switch (b.fx.eff) {
          case Eff.ward when !end:
            giveWard(u, u.maxHp * b.k, most: b.k, from: b.relic);
            _tally(b.relic).uses++;
          case Eff.status when !end && b.fx.status == Status.noShove:
            addEffect(u, Status.noShove, double.infinity, by: u); // the wave's end ends it ([HeroSkills._endEffects])
          case Eff.status when !end && b.fx.status == Status.reflect:
            addEffect(u, Status.reflect, double.infinity, k: b.k, by: u); // Mirror Shield's: the wave's end ends it
          case Eff.heal when end:
            final to = u.maxHp * min(1.0, b.k);
            if (u.hp >= to) continue;
            _healTroop(u, to - u.hp, HealSrc.pusaka); // between waves: no Wound, nor any other in-wave Bayangan
            _tally(b.relic)
              ..uses += 1
              ..worth += _healGained; // what it gave (heal.dart)
            impacts.add((u.pos, 'heal'));
          default:
            throw _unbuilt(b.fx);
        }
      }
    }
  }

  /// A monster's shove or drag didn't move troop [o] ([HeroMoves.knockBack], [HeroMoves.drag]): the counter of its type's
  /// wave-long stand (Anchor's `waveStart` noShove, given by the troop itself), when that is what held it.
  void _fxStood(Unit o) {
    if (pusaka.isEmpty || o.side != Side.troop || _held(o) || effectOn(o, Status.noShove)?.by != o) return;
    for (final b in _bookOf(o)?[Trig.waveStart] ?? const <FxBound>[]) {
      if (b.fx.status == Status.noShove) _tally(b.relic).uses++;
    }
  }

  /// What troop [u]'s worn small relics do ×, at the four sites the Bayangan Rust weakens (fang's heal, thorns' hit back,
  /// guard's cut in [Game._hurt]; fury's extra in [_attackK]): its type's `always` relicK Fx (Relic Altar's [FxBound.k])
  /// times Rust's share ([Omens._omenRust]); exactly Rust's without one.
  double _relicK(Unit u) {
    var k = _omenRust(u);
    if (pusaka.isEmpty || u.side != Side.troop) return k;
    for (final b in _bookOf(u)?[Trig.always] ?? const <FxBound>[]) {
      if (b.fx.eff == Eff.relicK) k *= b.k;
    }
    return k;
  }

  /// A worn small relic of troop [u] did [done] (HP healed, damage sent back or kept off, damage added) at a [_relicK]
  /// site: Relic Altar's counter, its part of it (× 1 − 1 / k).
  void _fxAltar(Unit u, double done) {
    if (pusaka.isEmpty || done <= 0) return;
    for (final b in _bookOf(u)?[Trig.always] ?? const <FxBound>[]) {
      if (b.fx.eff == Eff.relicK && b.k > 1) {
        _tally(b.relic)
          ..uses += 1
          ..worth += done * (1 - 1 / b.k);
      }
    }
  }

  /// Whether troop [u]'s type never uses a skill ([_silent]): [Game._trySkill] asks it first, so no Hero skill, #10 skill
  /// or awakening skill of the type is cast, and none spends MP.
  bool _fxSilent(Unit u) => u.side == Side.troop && _silent(u.type);

  /// Whether troop [type] holds an `always` skillGate Fx (Vow of Silence's): it never uses a skill ([_fxSilent]), and the
  /// Shadows' needs read none of its skills ([Omens.omenMet]).
  bool _silent(String type) => pusaka.isNotEmpty && (_bookOfType(type)?[Trig.always].any((b) => b.fx.eff == Eff.skillGate) ?? false);

  /// Troop [by]'s normal attack on [target] with a splash of [reach] px took [dealt] off [o], another monster near it
  /// ([Game._strike], a shot landing): the counter of its type's `always` splash Fx (Wide Blows'), when [o] stood past the
  /// splash [by] had without it.
  void _fxSplash(Unit by, Unit target, Unit o, double dealt, double reach) {
    if (pusaka.isEmpty || dealt <= 0) return;
    for (final b in _bookOf(by)?[Trig.always] ?? const <FxBound>[]) {
      if (b.fx.stat == Stat.splash && o.pos.distanceTo(target.pos) > reach - b.k) {
        _tally(b.relic)
          ..uses += 1
          ..worth += dealt;
      }
    }
  }

  /// Troop [u]'s own wave-long reflect (Mirror Shield's) sent [back] at a monster ([HeroSkills._answer]): its counter.
  void _fxMirrored(Unit u, double back) {
    for (final b in _bookOf(u)?[Trig.waveStart] ?? const <FxBound>[]) {
      if (b.fx.status == Status.reflect) {
        _tally(b.relic)
          ..uses += 1
          ..worth += back;
      }
    }
  }

  /// A reflect on troop [u] ran out ([HeroSkills._tickEffects]): a stronger one (Iron Skin's) had taken the slot from its
  /// type's wave-long one (Mirror Shield's), which comes back for the rest of the wave.
  void _fxReflectBack(Unit u) {
    if (pusaka.isEmpty || !waveActive || !u.alive || u.side != Side.troop) return;
    for (final b in _bookOf(u)?[Trig.waveStart] ?? const <FxBound>[]) {
      if (b.fx.eff == Eff.status && b.fx.status == Status.reflect) addEffect(u, Status.reflect, double.infinity, k: b.k, by: u);
    }
  }

  /// Whether monster [u] holds something a strip takes (Null Stone's): a good effect Spellbreaker strips that no troop
  /// gave ([_stripsOff]), or a guard not halved already where only half goes ([_halvesOnly]).
  bool _fxStrippable(Unit u) =>
      u.effects.entries.any((e) => _stripsOff(u, e.key, e.value)) || (t < u.guardUntil && !(u.guardHalved == u.guardUntil && _halvesOnly(u)));

  // The catalog's shared hooks (catalog step 0f, decisions-log 182): what the data batches' rules read. None changes a
  // fight by itself.

  /// How many other living units of [u]'s side stand on the field within [r] (px) of it: troops for a troop, monsters for
  /// a monster ([If.alliesNear]; Cover's "another enemy next to it"). Counted at most once a tick for a reach: a second
  /// ask in the same tick at the same reach reads the count ([Unit.alliesTick]), as the units stood at the first.
  int alliesNearOf(Unit u, double r) {
    if (u.alliesTick == _ticks && u.alliesR == r) return u.alliesN;
    var n = 0;
    for (final o in units) {
      if (o.side == u.side && o != u && o.alive && o.entered && o.pos.distanceTo(u.pos) <= r) n++;
    }
    u
      ..alliesTick = _ticks
      ..alliesR = r
      ..alliesN = n;
    return n;
  }

  /// How many living units of the other side stand on the field within [r] (px) of [u], counted as [alliesNearOf] is
  /// ([Unit.foesTick]).
  int foesNearOf(Unit u, double r) {
    if (u.foesTick == _ticks && u.foesR == r) return u.foesN;
    var n = 0;
    for (final o in units) {
      if (o.side != u.side && o.alive && o.entered && o.pos.distanceTo(u.pos) <= r) n++;
    }
    u
      ..foesTick = _ticks
      ..foesR = r
      ..foesN = n;
    return n;
  }

  /// Whether living [u] is now at or under [share] of its max HP for the first time for [flag] (a bit, 0 to 62, its
  /// rule's own: a Bayangan kind's on a monster, a Pusaka Fx's on a troop): true once, then false while [Unit.belowHp]
  /// keeps the bit (a monster's for good, a troop's until the next wave starts). A blow that kills it uses none. For
  /// Second Skin, Last Rage, Last Gasp and Hidden Flask (batch L-3: [FxEngine._fxStruckAfter], its Fx's index the bit).
  bool belowOnce(Unit u, double share, int flag) {
    final bit = 1 << flag;
    if ((u.belowHp & bit) != 0 || !u.alive || u.hp <= 0 || u.hp > u.maxHp * share) return false;
    u.belowHp |= bit;
    return true;
  }

  /// How long [s] put on [u] by [by] for [time] s lasts ([omen]: a Bayangan's): the duration scaler
  /// ([HeroSkills.addEffect], its one place). The product of the catalog's rules that make an effect end sooner or later
  /// ([scaledEffectTime]): Unshaken's ([Omens._omenUnshaken]), Lingering's ([Omens._omenLinger]) and Mark Ward's
  /// ([Omens._omenMarkWard]). 1 while none acts, so every time is as given.
  double _effectTime(Unit u, Status s, double time, Unit? by, {bool omen = false}) =>
      scaledEffectTime(time, _omenUnshaken(u, s) * _omenLinger(u, s, by, omen: omen) * _omenMarkWard(u, s));

  /// Whether monster [u] holds a shield now: an absorb ([Status.absorb], a skill's or a Bayangan's), a shot ward
  /// ([Status.shotWard]), a Barrier ([Unit.shield]) or a live guard ([Unit.guardUntil], any). Hard Shell's test
  /// ([Omens._omenTaken]), and the `foeShielded` condition's when its Pusaka comes (Shell Cracker).
  bool shielded(Unit u) =>
      u.shield > 0 || t < u.guardUntil || (u.effects.isNotEmpty && (under(u, Status.absorb) || under(u, Status.shotWard)));

  /// Whether monster [u] is held now: a slow ([Status.slow]), a hold (Impale's pin, [Status.impaled]) or a stun
  /// ([Unit.stunUntil]). Hunker's test ([Omens._omenTaken]), and the `foeHeld` condition's when its Pusaka comes (Bully's
  /// Club, which also counts a hex).
  bool held(Unit u) => t < u.stunUntil || (u.effects.isNotEmpty && (under(u, Status.slow) || under(u, Status.impaled)));

  /// The `foeHeld` condition (Bully's Club): monster [u] is [held], or hexed into a slime ([Status.hex]).
  bool foeHeld(Unit u) => held(u) || (u.effects.isNotEmpty && under(u, Status.hex));

  /// How many troop types have a troop alive ([Pusaka.typesAlive]), counted at most once a tick ([Game._typesTick]): the
  /// `typesAlive` condition's (Unity Ring), asked at each of its type's attacks.
  int get typesAliveNow {
    if (_typesTick != _ticks) {
      _typesTick = _ticks;
      _typesN = typesAlive;
    }
    return _typesN;
  }
}

/// The shortest an effect the duration scaler shortens lasts, s (catalog-design §2.3): unless its own time is shorter.
const effectTimeFloor = 0.3;

/// An effect's [time] (s) under the duration scaler's [k]: [time] × [k], at 1 [time] itself, to the bit; a shortened
/// one lasts at least [effectTimeFloor], or its own [time] when that is shorter.
double scaledEffectTime(double time, double k) => k == 1 ? time : max(time * k, min(time, effectTimeFloor));
