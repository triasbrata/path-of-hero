part of 'game.dart';

// The Dungeon's floors (decisions-log 336, 337; docs/dungeon-design.md section 6): a floor is a row of rooms left to
// right, each from a hand-made template picked and mirrored by the floor's dice (the trip's seed and the floor's
// number), with its band, its blockers, its props and its monsters. The party arrives at the left end by the save
// point; the stairs (the portal) are at the right end. M1 builds floor 1 in the Mossy Halls look.

/// The floor band's top edge in world y: where the back wall meets the floor (the moss line). Rooms differ in how deep
/// their band goes below it ([Room.depth]); every y the units stand on is inside the field's 0..[fieldH], so the shared
/// helpers' clamps hold.
const bandTop = 8.0;

/// A room's kind (the design's templates; M1 builds these five, the pool and the supply nook come with M3).
enum RoomKind { hall, corridor, cavern, oreVein, graves }

/// A piece standing in a room: [kind] names its art ([dungeonProps] in dungeon_art.dart), its feet at ([x], [y]); a
/// [solid] one blocks the cells of its foot box ([w] × [h] around its feet, h upward). [wall]: on the back wall, behind
/// the band (slabs, pillars, torches): never blocks.
class Prop {
  const Prop(this.kind, this.x, this.y, {this.w = 0, this.h = 0, this.solid = false, this.wall = false, this.flip = false});
  final String kind;
  final double x, y, w, h;
  final bool solid, wall, flip;
}

/// One room of a floor: its [kind], its span [x0]..[x1], its band's [depth] under [bandTop], its [props] and the
/// monsters it holds ([monsters]: type and rank, rolled with the floor).
class Room {
  Room(this.index, this.kind, this.x0, this.x1, this.depth, this.props, this.monsters);
  final int index;
  final RoomKind kind;
  final double x0, x1, depth;
  final List<Prop> props;
  final List<(String, Tier)> monsters;
  double get width => x1 - x0;
  double get bottom => bandTop + depth;
  double get midY => bandTop + depth / 2;
}

/// A generated floor: its [number], [rooms] left to right, [width], the walk grid, the arrival save point and the
/// portal (the stairs down).
class DungeonFloor {
  DungeonFloor(this.number, this.rooms, this.grid, this.savePoint, this.portal) : width = rooms.last.x1;
  final int number;
  final List<Room> rooms;
  final WalkGrid grid;
  final Point<double> savePoint, portal;
  final double width;

  /// The room holding world x [x] (the nearest end's outside the floor).
  Room roomAt(double x) => rooms.firstWhere((r) => x < r.x1, orElse: () => rooms.last);
}

/// A floor's depth wave (the design's section 5): its monsters are the field's at wave 3 + 4 × (floor − 1).
int depthWave(int floor) => 3 + 4 * (floor - 1);

/// How many rooms a floor of M1 has, at least and at most (the arrival room counted).
const floorRooms = (4, 6);

/// The arrival room's length and where its save point stands from its left.
const arrivalLength = 360.0, savePointX = 56.0;

/// The portal's centre from the floor's right end.
const portalInset = 44.0;

/// The dice a floor is made with: from the trip's seed and the floor's number, so the same pair makes the same floor.
Random floorDice(int seed, int floor) => Random((seed * 7919 + floor * 104729) & 0x3fffffff);

/// Makes floor [floor] of a dungeon of [seed]: [floorRooms] rooms, the first the arrival hall with the save point and no
/// monsters, the others drawn from the templates, the last ending in the portal.
DungeonFloor makeFloor(int seed, int floor) {
  final dice = floorDice(seed, floor);
  final n = floorRooms.$1 + dice.nextInt(floorRooms.$2 - floorRooms.$1 + 1);
  final rooms = <Room>[];
  var x = 0.0;
  for (var i = 0; i < n; i++) {
    final kind = i == 0 ? RoomKind.hall : _roomKinds[dice.nextInt(_roomKinds.length)];
    final room = _room(dice, i, kind, x, floor, arrival: i == 0, last: i == n - 1);
    rooms.add(room);
    x = room.x1;
  }
  final grid = WalkGrid((x / navCell).ceil(), (fieldH / navCell).floor());
  for (final r in rooms) {
    grid.mark(r.x0, bandTop + 2, r.x1, r.bottom - 2);
  }
  // Each room opens its own band; where a narrow room meets a deep one the deep one's lower cells end at the wall.
  for (final r in rooms) {
    for (final p in r.props) {
      if (p.solid) grid.mark(p.x - p.w / 2, p.y - p.h, p.x + p.w / 2, p.y + 2, blocked: true);
    }
  }
  final save = Point(savePointX, rooms.first.midY), portal = Point(x - portalInset, rooms.last.midY);
  return DungeonFloor(floor, rooms, grid, save, portal);
}

/// The kinds a room after the arrival hall is drawn from (a hall twice as likely).
const _roomKinds = [RoomKind.hall, RoomKind.hall, RoomKind.corridor, RoomKind.cavern, RoomKind.oreVein, RoomKind.graves];

/// One room of [kind] from [x]: its length, depth and props by the template, mirrored by the dice; its monsters (none
/// in the [arrival] room) by the floor's depth wave.
Room _room(Random dice, int index, RoomKind kind, double x, int floor, {bool arrival = false, bool last = false}) {
  double span(double lo, double hi) => lo + dice.nextDouble() * (hi - lo);
  final length = arrival
      ? arrivalLength
      : switch (kind) {
          RoomKind.hall => span(420, 600),
          RoomKind.corridor => span(300, 360),
          RoomKind.cavern => span(480, 640),
          RoomKind.oreVein => span(420, 560),
          RoomKind.graves => span(420, 580),
        }.roundToDouble();
  final depth = switch (kind) {
    RoomKind.corridor => 48.0,
    RoomKind.oreVein => 96.0,
    _ => 104.0,
  };
  final mirror = dice.nextBool();
  final props = <Prop>[];
  final bottom = bandTop + depth;
  double at(double share) => x + (mirror ? 1 - share : share) * length;
  // The back wall: a slab or a pillar every ~180 units, a torch between them.
  for (var s = 0.12; s < 0.95; s += 0.36) {
    props.add(Prop(dice.nextBool() ? 'slab' : 'pillar', at(s).roundToDouble(), bandTop, wall: true));
    props.add(Prop('torch', at(s + 0.18).roundToDouble(), bandTop, wall: true));
  }
  switch (kind) {
    case RoomKind.hall:
      if (!arrival) props.add(Prop('rocks', at(span(0.3, 0.7)).roundToDouble(), bottom - 10));
      props.add(Prop('pebbles', at(span(0.1, 0.9)).roundToDouble(), bandTop + depth * 0.6));
    case RoomKind.corridor:
      props.add(Prop('pebbles', at(span(0.2, 0.8)).roundToDouble(), bandTop + depth * 0.7));
    case RoomKind.cavern:
      // Boulders to walk round: two or three, each in a third of the band's depth, the way past them always open.
      final count = 2 + dice.nextInt(2);
      for (var i = 0; i < count; i++) {
        final share = (i + 1) / (count + 1) + (dice.nextDouble() - 0.5) * 0.1;
        final y = bandTop + depth * (dice.nextBool() ? 0.38 : 0.78);
        props.add(Prop('boulder', at(share).roundToDouble(), y.roundToDouble(), w: 72, h: 20, solid: true, flip: dice.nextBool()));
      }
    case RoomKind.oreVein:
      final count = 2 + dice.nextInt(3);
      for (var i = 0; i < count; i++) {
        final share = (i + 0.5) / count;
        props.add(Prop('ore${dice.nextInt(4)}', at(share).roundToDouble(), bandTop + 10, w: 44, h: 12, solid: true));
      }
    case RoomKind.graves:
      final count = 3 + dice.nextInt(3);
      for (var i = 0; i < count; i++) {
        final share = 0.15 + 0.7 * i / max(1, count - 1);
        final y = bandTop + depth * (0.25 + 0.5 * dice.nextDouble());
        props.add(Prop(_graves[dice.nextInt(_graves.length)], at(share).roundToDouble(), y.roundToDouble(), w: 16, h: 8, solid: true));
      }
  }
  final monsters = arrival ? const <(String, Tier)>[] : roomMonsters(dice, floor);
  return Room(index, kind, x, x + length, depth, props, monsters);
}

const _graves = ['grave0', 'grave1', 'grave2', 'cross'];

/// A room's monsters on [floor] (the design's section 5): 3-4 on floors 1-4, 4-6 deeper; each type from the field's
/// pool at the floor's depth wave ([poolOf]), each rank by depth: elite 5% + 2% a floor (at most 40%), high elite from
/// floor 4 at 2% + 1% a floor (at most 20%).
List<(String, Tier)> roomMonsters(Random dice, int floor) {
  final pool = poolOf(depthWave(floor));
  final n = floor <= 4 ? 3 + dice.nextInt(2) : 4 + dice.nextInt(3);
  final elite = min(0.4, 0.05 + 0.02 * floor), high = floor >= 4 ? min(0.2, 0.02 + 0.01 * floor) : 0.0;
  return [
    for (var i = 0; i < n; i++)
      (
        pool[dice.nextInt(pool.length)],
        switch (dice.nextDouble()) {
          final r when r < high => Tier.highElite,
          final r when r < high + elite => Tier.elite,
          _ => Tier.normal,
        }
      ),
  ];
}
