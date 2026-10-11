part of 'main.dart';

// A monster's rank on its sprite (#58; the owner: "semua jenis monster bisa jadi tier enemy apapun tapi perlu
// di filter warnanya biar ada pembeda jenis monsternya"). Any type can hold any rank now, so the rank shows on
// the body: its HP bar colour ([_tierBar]: silver, gold, purple, orange) recolours the sprite part way
// ([_tierShare], so the type still reads) and outlines it 1 px (the outlines built at load, [_outlines], as
// awakening's). A normal monster is drawn as it is. Its ground shadow stays plain.

/// How far each rank recolours the body toward its colour: 0 the sprite as drawn, 1 all [_tint].
const _tierShare = {Tier.elite: 0.45, Tier.highElite: 0.45, Tier.miniBoss: 0.5, Tier.boss: 0.55};

/// [_tint] toward [c], [share] of the way from the sprite as drawn.
ColorFilter _partTint(Color c, double share) {
  const plain = <double>[1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0];
  final full = _tintMatrix(c);
  return ColorFilter.matrix([for (var i = 0; i < plain.length; i++) plain[i] + (full[i] - plain[i]) * share]);
}

/// Each rank's body paint and outline paint (none for [Tier.normal]).
final _tierPaints = {
  for (final MapEntry(key: tier, value: (color, _)) in _tierBar.entries)
    tier: Paint()
      ..filterQuality = FilterQuality.none
      ..colorFilter = _partTint(color, _tierShare[tier]!),
};
final _tierLines = {
  for (final MapEntry(key: tier, value: (color, _)) in _tierBar.entries)
    tier: Paint()
      ..filterQuality = FilterQuality.none
      ..colorFilter = _flat(color),
};
