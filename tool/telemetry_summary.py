"""Per-wave difficulty from the telemetry's JSONL (#64, docs/telemetry.md).

Reads the `wave` records (every game and install in the files) and prints, per wave number: how many runs
reached it and how many won it, the army it started with and the troops lost (loss% = fallen / army at the
start: the "too easy or not" number), the Heroes lost, lives lost, the time to clear, how often it stalled
and the monsters marched, the gold earned, and the spawn mix per run (monster type, with its ranks: n normal,
e elite, h high elite, m mini boss, b boss; the necromancer's raised minions apart), and the gold spent in the
store (#63). With the Towns on (decisions-log 216, 221, 233, 237) also, per wave: how many runs had a Town just before
it, the materials it dropped per run, and the relics (and the forge's items) crafted at a Smithy before it per run and
their gold (a Town comes between waves, so its crafts land in the next wave's record). Then the Towns in all
(decisions-log 253): the visits (Auto's leaves, the seconds inside, the gold brought in, each run's first), the Town
rolls after won waves, what the Towns' Shops sold and bought back (items, small relics, materials), the relics and the
items crafted, Enhance's stones made and its steps (decisions-log 255), the materials dropped, used, sold and
bought, and the Tavern (decisions-log 268): its buys per Town (by the wave won before it), the kinds bought against
offered, the rerolls, its gold, and the leaks Watchman's Brew forgave. Then how the games ended.

Stdlib only:
  python3 tool/telemetry_summary.py                   # the macOS app's files (and ~/.local/share's)
  python3 tool/telemetry_summary.py a.jsonl b.jsonl   # given files, e.g. what a server collected
  python3 tool/telemetry_summary.py --app 1.2.0       # one build's records only
"""
import json
import sys
from collections import Counter, defaultdict
from pathlib import Path

# The macOS app's folder, in its sandbox container: the new bundle id's, or before its first launch (and the
# owner's one-time copy, decisions-log 133) the old one's. Never both: the copy holds the old records too.
MAC_APP = [Path.home() / f'Library/Containers/{i}/Data/.local/share/tower_defense'
           for i in ('cloud.brata.poh', 'com.example.towerDefense')]
DIRS = [next((d for d in MAC_APP if d.exists()), MAC_APP[0]), Path.home() / '.local/share/tower_defense']
TIERS = {'normal': 'n', 'elite': 'e', 'highElite': 'h', 'miniBoss': 'm', 'boss': 'b'}


def default_files():
    """telemetry.jsonl and its rotated copies, oldest first, in every folder the game writes to."""
    out = []
    for d in DIRS:
        base = d / 'telemetry.jsonl'
        out += [p for p in [base.with_name(f'telemetry.jsonl.{i}') for i in (2, 1)] + [base] if p.exists()]
    return out


def records(paths, app=None):
    """The records in [paths], skipping broken lines; with [app], only that build's sessions."""
    builds = {}  # session -> app
    for path in paths:
        for line in Path(path).read_text(encoding='utf-8').splitlines():
            try:
                r = json.loads(line)
            except ValueError:
                continue
            if r.get('rec') == 'session':
                builds[r.get('session')] = r.get('app')
            if app is None or builds.get(r.get('session')) == app:
                yield r


def run_of(r):
    """The run a record belongs to: one game of one session of one install."""
    return r.get('install'), r.get('session'), r.get('game')


# The events only a game with the Towns on sends (decisions-log 216, 233, 249, 255, 268).
TOWN_EVENTS = {'townMarked', 'townEntered', 'townLeft', 'crafted', 'itemCrafted', 'stoneCrafted', 'itemEnhanced',
               'boostBought', 'tavernRerolled'}
LOOTS = ('item', 'relic', 'material')


def loot_of(e):
    """A store event's loot as (`item`, `relic` or `material`, its key): the one of its three keys that is set."""
    return next(((k, e[k]) for k in ('material', 'relic', 'item') if e.get(k)), ('item', '?'))


def tally(counts, top=None):
    """'fang 4, thorns 2': the keys most first (then by name), at most [top] of them."""
    return ', '.join(f'{k} {n}' for k, n in sorted(counts.items(), key=lambda x: (-x[1], x[0]))[:top])


def shop_line(what, loot, gold, words):
    """A Town Shop's line, [what] the player did there: how many and the gold in all, then each kind of loot ([words]
    names it) with its own count and gold, and its keys."""
    total = sum(sum(c.values()) for c in loot.values())
    if not total:
        return f'{what}: none'
    parts = [f'{words[k]} {sum(loot[k].values())} for {gold[k]} ({tally(loot[k])})' for k in LOOTS if loot[k]]
    return f'{what}: {total} for {sum(gold.values())} gold: ' + '; '.join(parts)


def mix(spawns, runs):
    """Monsters per run by type, most first, with their ranks: 'orc 4.5 (n3.5 e1.0)'."""
    totals = sorted(((sum(t.values()), k, t) for k, t in spawns.items()), key=lambda x: (-x[0], x[1]))
    parts = []
    for n, kind, tiers in totals:
        ranks = ' '.join(f'{TIERS.get(t, t)}{c / runs:.1f}' for t, c in tiers.items())
        parts.append(f'{kind} {n / runs:.1f} ({ranks})')
    return ', '.join(parts)


def main(argv):
    app = None
    if '--app' in argv:
        i = argv.index('--app')
        app = argv[i + 1]
        argv = argv[:i] + argv[i + 2:]
    paths = argv or default_files()
    if not paths:
        sys.exit('no telemetry file found; give one: python3 tool/telemetry_summary.py <file.jsonl>')

    recs = list(records(paths, app))
    # The runs with the Towns on: a Town's event or a wave record with a Town's field. Their store events are a Town's
    # Shop (outside a Town it refuses every buy and sell, decisions-log 230).
    town_runs = {run_of(r) for r in recs
                 if r.get('rec') == 'wave' and ('town' in r or 'materials' in r)
                 or r.get('rec') == 'event' and r.get('event', {}).get('kind') in TOWN_EVENTS}
    waves = defaultdict(list)
    ends = Counter()
    towns_before = Counter()  # wave -> runs with a Town just before it (a won wave's `town` slot)
    entered, crafted, craft_gold, auto_left = 0, Counter(), 0, 0
    first_town = {}  # run -> the slot of its first Town entered
    inside, brought = [], []  # each Town left: its seconds inside; each Town entered: the gold brought in
    rolls = Counter()  # what the Town roll after a won wave did: rolled, hit, blocked, marked
    items_made, items_gold = Counter(), 0  # the forge's items crafted, and their gold
    stones, stones_gold = Counter(), 0  # Enhance's stones made, and their gold
    steps, steps_stones, steps_gold = Counter(), Counter(), 0  # Enhance's steps: by the step reached, the stones, the gold
    bought, bought_gold = {k: Counter() for k in LOOTS}, Counter()  # a Town's Shop: loot -> key -> how many; its gold
    sold, sold_gold = {k: Counter() for k in LOOTS}, Counter()
    dropped, used = Counter(), Counter()  # materials: dropped in waves, taken by crafts
    # The Tavern (a Town left's `tavern`): visits, buys and gold by the wave won before the Town, the kinds offered and
    # bought, the rerolls and their gold; the leaks Watchman's Brew forgave (a wave's `boostSaved`).
    tavern_visits, tavern_buys, tavern_gold = Counter(), Counter(), Counter()
    offered, bought_kinds, rerolls, reroll_gold, saved = Counter(), Counter(), 0, 0, 0
    for r in recs:
        if r.get('rec') == 'wave':
            waves[r['wave']].append(r)
            if r['end'] != 'won':
                ends[(r['end'], r['wave'])] += 1
            town = r.get('town')
            if isinstance(town, dict):
                if town.get('hit'):
                    towns_before[town['slot']] += 1
                rolls.update(['blocked'] if town.get('blocked') else ['marked'] if 'marked' in town
                             else ['rolled'] + (['hit'] if town.get('hit') else []))
            dropped.update(r.get('materials') or {})
            used.update(r.get('materialsUsed') or {})
            saved += r.get('boostSaved', 0)
        elif r.get('rec') == 'event':
            e = r.get('event', {})
            run = run_of(r)
            if e.get('kind') == 'townEntered':
                entered += 1
                first_town.setdefault(run, e.get('slot'))
                brought.append(e.get('gold', 0))
            elif e.get('kind') == 'townLeft':
                auto_left += bool(e.get('auto'))
                inside.append(e.get('secs', 0))
                tav = e.get('tavern')
                if isinstance(tav, dict):
                    w = e.get('wave', 0)
                    tavern_visits[w] += 1
                    tavern_buys[w] += len(tav.get('bought', []))
                    tavern_gold[w] += tav.get('spent', 0)
                    offered.update(tav.get('offered', []))
                    bought_kinds.update(tav.get('bought', []))
            elif e.get('kind') == 'tavernRerolled':
                rerolls += 1
                reroll_gold += e.get('price', 0)
            elif e.get('kind') == 'crafted':
                crafted[e.get('relic')] += 1
                craft_gold += e.get('gold', 0)
            elif e.get('kind') == 'itemCrafted':
                items_made[e.get('item')] += 1
                items_gold += e.get('gold', 0)
            elif e.get('kind') == 'stoneCrafted':
                stones[e.get('stone')] += 1
                stones_gold += e.get('gold', 0)
            elif e.get('kind') == 'itemEnhanced':
                steps[f'+{e.get("plus")}'] += 1
                steps_stones[e.get('stone')] += 1
                steps_gold += e.get('gold', 0)
            elif e.get('kind') in ('storeBought', 'storeSold') and run in town_runs:
                loot, key = loot_of(e)
                if e['kind'] == 'storeBought':
                    bought[loot][key] += 1
                    bought_gold[loot] += e.get('cost', 0)
                else:
                    sold[loot][key] += e.get('n', 1)
                    sold_gold[loot] += e.get('gain', 0)
    towns = any('town' in r or 'materials' in r for rs in waves.values() for r in rs)

    print(f'{"wave":>4} {"runs":>4} {"won":>4} {"army":>5} {"fell":>5} {"loss%":>5} {"hero":>4} {"lives":>5} '
          f'{"secs":>6} {"march":>5} {"gold+":>6} {"store":>6}'
          + (f' {"town":>4} {"mats":>5} {"craft":>5} {"craft$":>6}' if towns else '') + '  spawns per run')
    for wave in sorted(waves):
        rs = waves[wave]
        n = len(rs)
        won = sum(r['end'] == 'won' for r in rs)
        army = sum(sum(r['start']['army'].values()) for r in rs) / n
        fell = sum(sum(r['fallen'].values()) for r in rs) / n
        heroes = sum(r['heroesFallen'] for r in rs) / n
        lives = sum(r['livesLost'] for r in rs) / n
        secs = sum(r['secs'] for r in rs) / n
        marched = sum(r['marched'] is not None for r in rs)
        gold = sum(r['gold']['earned'] for r in rs) / n
        store = sum(r['gold'].get('storeSpent', 0) for r in rs) / n
        spawns, raised = defaultdict(Counter), defaultdict(Counter)
        for r in rs:
            for into, got in ((spawns, r['spawns']), (raised, r['raised'])):
                for kind, tiers in got.items():
                    into[kind].update(tiers)
        loss = 100 * fell / army if army else 0
        line = (f'{wave:>4} {n:>4} {won:>4} {army:>5.1f} {fell:>5.1f} {loss:>5.0f} {heroes:>4.1f} {lives:>5.1f} '
                f'{secs:>6.1f} {marched:>5} {gold:>6.0f} {store:>6.0f}')
        if towns:
            mats = sum(sum(r.get('materials', {}).values()) for r in rs) / n
            made = sum(sum(r.get('crafted', {}).values()) for r in rs) / n
            spent = sum(r['gold'].get('craftSpent', 0) for r in rs) / n
            line += f' {towns_before[wave]:>4} {mats:>5.1f} {made:>5.2f} {spent:>6.0f}'
        line += f'  {mix(spawns, n)}'
        if raised:
            line += f'; raised {mix(raised, n)}'
        print(line)
    if towns:
        stay = f', {sum(inside) / len(inside):.1f} s inside' if inside else ''
        gold_in = f', {sum(brought) / len(brought):.0f} gold brought in' if brought else ''
        print(f'\ntowns: {entered} entered, {auto_left} left by Auto{stay}{gold_in} (each on average); first at wave '
              + (', '.join(f'{w} x{c}' for w, c in sorted(Counter(first_town.values()).items())) or 'none'))
        print(f'town rolls after won waves: {rolls["rolled"]} rolled, {rolls["hit"]} hit; none {rolls["blocked"]} times '
              f'(too soon after a Town), none {rolls["marked"]} times (a Town already marked)')
        print(shop_line('bought in a Town Shop', bought, bought_gold, {'item': 'items', 'relic': 'relics', 'material': 'materials'}))
        print(shop_line('sold to a Town Shop', sold, sold_gold,
                        {'item': 'items', 'relic': 'relics bought back', 'material': 'materials'}))
        print(f'crafted: {sum(crafted.values())} relics for {craft_gold} gold'
              + (': ' + ', '.join(f'{k} {c}' for k, c in crafted.most_common()) if crafted else ''))
        if items_made:
            print(f'crafted items: {sum(items_made.values())} for {items_gold} gold: {tally(items_made)}')
        if stones:
            print(f'stones made: {sum(stones.values())} for {stones_gold} gold: {tally(stones)}')
        if steps:
            print(f'items enhanced: {sum(steps.values())} steps for {steps_gold} gold and {tally(steps_stones)}; '
                  f'the step reached: {", ".join(f"{k} {n}" for k, n in sorted(steps.items()))}')
        print(f'materials: {sum(dropped.values())} dropped, {sum(used.values())} used in crafts, '
              f'{sum(sold["material"].values())} sold to a Shop, {sum(bought["material"].values())} bought from one'
              + (f'; most dropped: {tally(dropped, 6)}' if dropped else ''))
        if tavern_visits:
            visits, buys = sum(tavern_visits.values()), sum(tavern_buys.values())
            print(f'tavern: {visits} visits, {buys} boosts bought ({buys / visits:.2f} a visit), {rerolls} rerolls for '
                  f'{reroll_gold} gold, {sum(tavern_gold.values())} gold in all; {saved} leaks forgiven')
            print('tavern by Town (wave won before it: visits, bought, gold): '
                  + ', '.join(f'{w}: {tavern_visits[w]}, {tavern_buys[w]}, {tavern_gold[w]}' for w in sorted(tavern_visits)))
            print('tavern kinds (bought / offered): '
                  + ', '.join(f'{k} {bought_kinds[k]}/{n}' for k, n in sorted(offered.items(), key=lambda x: (-x[1], x[0]))))
    if ends:
        print('\nended: ' + ', '.join(f'{how} at wave {w} x{c}' for (how, w), c in sorted(ends.items(), key=lambda x: x[0][1])))


if __name__ == '__main__':
    main(sys.argv[1:])
