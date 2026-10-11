part of 'game.dart';

// A troop's cleanse (catalog step 0g, decisions-log 184; docs/units-and-combat.md "Cleanse and noHeal"): what monsters
// put on a troop ends at once, and what a troop, a Pusaka or the troop itself put on it stays. A monster's effect on a
// troop is marked when it is put on ([Effect.bad], from the monster skills' `addEffect(..., bad: true)`); its stun
// ([HeroMoves.stunTroop]) and a Soul Drain's beam on it ([BossSkills._drain]) are a monster's by what they are. Nothing
// cleanses yet: the catalog's `cleanse` Fx (Salt Charm, Pure Water, Saint's Tear) call [Cleanse.cleanse], and the troop
// debuffs of the Bayangan (Sap, Bat Venom, Blight) come only with them (catalog-design §2.5). Its other half, the
// monsters' noHeal, is heal.dart's ([Heal._healMonster]).

/// One bad thing a monster put on a troop: until when it lasts, its [Status] (null: a stun or a drain), and how it ends.
typedef _Bad = ({double until, Status? s, void Function() end});

/// The cleanse.
extension Cleanse on Game {
  /// What monsters put on troop [u] that still lasts, in the order found: each bad effect ([Effect.bad]), a monster's
  /// stun ([Unit.stunUntil]; a troop is stunned by nothing else) and each Soul Drain on it (its beam, the drain's state).
  List<_Bad> _badOn(Unit u) => [
        for (final MapEntry(key: s, value: e) in u.effects.entries)
          if (e.bad && t < e.until) (until: e.until, s: s, end: () => u.effects.remove(s)),
        if (t < u.stunUntil) (until: u.stunUntil, s: null, end: () => u.stunUntil = t),
        for (final b in beams)
          if (b.look == BeamLook.drain && b.follow?.last == u) (until: b.until, s: null, end: () => beams.remove(b)),
      ];

  /// How many bad things monsters put on troop [u] last now ([cleanse] would end them): for a rule that asks first.
  int badOn(Unit u) => u.side == Side.troop ? _badOn(u).length : 0;

  /// A troop's cleanse: [most] of the bad things monsters put on troop [u] end now (null: all), those with the most time
  /// left first (alike: as found): a bad effect ([Effect.bad]: a curse, a daze, a slow, a bleed, a taunt...), a monster's
  /// stun (it still can't be stunned again until [Unit.stunImmuneUntil]), a Soul Drain on it. What a troop, a Pusaka or
  /// [u] itself put on it always stays, and so does a slime's puddle (Slime Tide slows it again while it stands in it).
  /// A stat effect ending refits it. How many ended.
  int cleanse(Unit u, {int? most}) {
    assert(u.side == Side.troop, 'a cleanse on a monster');
    if (!u.alive) return 0;
    final bad = _badOn(u).indexed.toList()
      ..sort((a, b) => a.$2.until != b.$2.until ? b.$2.until.compareTo(a.$2.until) : a.$1.compareTo(b.$1));
    final gone = [for (final (_, x) in bad.take(most ?? bad.length)) x];
    for (final x in gone) {
      x.end();
    }
    if (gone.any((x) => x.s?.stat ?? false)) _refit(u);
    return gone.length;
  }
}
