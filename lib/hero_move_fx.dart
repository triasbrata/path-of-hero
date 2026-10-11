part of 'main.dart';

// How the movement Hero skills look (#48 branch 2a; the rules in game.dart's hero_moves.dart, the looks in
// docs/ui-hud.md "Skills"). A leap's hop, a charge's gallop and Spear Wall's held thrust are drawn with the
// unit ([Board._unit]); here are Chain Hook's chain and Spear Wall's ring.

/// Spear Wall's ring at a braced troop's feet: a pale steel.
const _braceColor = Color(0xFFC8D2DC);

extension on Board {
  /// A braced troop's ring at its feet, steady where a guard's pulses, fading out over its last half second.
  void _braceRing(Canvas c, Game g, Unit u, Offset ground) {
    final until = u.brace?.until;
    if (until == null || !u.alive || !g.braced(u)) return;
    final a = math.min(1.0, (until - g.t) / 0.5) * 0.8;
    c.drawOval(Rect.fromCenter(center: ground - const Offset(0, 1), width: 18, height: 8), Paint()
      ..color = _braceColor.withValues(alpha: a)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4);
  }

  /// The chain from the Hero pulling [u] ([Carry.by], Chain Hook) to it while it is dragged: dark links, a
  /// lighter one every other, from the puller's hand to the middle of its body.
  void _chain(Canvas c, Unit u) {
    final by = switch (u.move) { Carry(by: final by?) => by, _ => null };
    if (by == null || !u.alive) return;
    final from = Offset(by.pos.x + 4 * by.dir, by.pos.y - 6), to = Offset(u.pos.x, u.pos.y - 7);
    final len = (to - from).distance, n = math.max(1, (len / 3).floor());
    for (var i = 0; i < n; i++) {
      c.drawLine(Offset.lerp(from, to, i / n)!, Offset.lerp(from, to, (i + 0.7) / n)!, Paint()
        ..color = i.isEven ? const Color(0xFF2A2A30) : const Color(0xFF7A7A86)
        ..strokeWidth = 1.2);
    }
  }
}
