"""Tests tool/telemetry_summary.py's Town lines (decisions-log 253, docs/telemetry.md "Reading it") on a made-up file in a
temp dir: a run with the Towns on (its rolls, a Town entered and left, buys and sells in its Shop, a relic and an item
crafted, two Enhance stones made and two Enhance steps, materials dropped and used, the Tavern's buy, reroll and
forgiven leak, decisions-log 268) and a run with them off (its store buy is the field's store, never a Town Shop's).
The records carry only the fields the game writes (lib/telemetry.dart, lib/game_events.dart).
Stdlib only, no flutter:  python3 tool/test_telemetry_summary.py
"""
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

TOOL = Path(__file__).resolve().parent / 'telemetry_summary.py'


def wave(n, game, end='won', **more):
    """A wave record of run (i1, s1, [game]) with the fields the per-wave table reads."""
    return {'tv': 11, 'rec': 'wave', 'install': 'i1', 'session': 's1', 'game': game, 'wave': n, 'end': end, 'secs': 30.0,
            'marched': None, 'start': {'army': {'soldier': 4}}, 'livesLost': 0, 'kills': 10,
            'spawns': {'slime': {'normal': 10}}, 'raised': {}, 'fallen': {}, 'heroesFallen': 0,
            'gold': {'earned': 100, 'storeSpent': 0}, **more}


def event(game, kind, wave_, **fields):
    return {'tv': 11, 'rec': 'event', 'install': 'i1', 'session': 's1', 'game': game,
            'event': {'v': 11, 'kind': kind, 'wave': wave_, 't': 1.0, **fields}}


def store(game, kind, wave_, loot, key, **fields):
    """A store event as the game writes it: `item` and `relic` (one set, or both null for a material, then `material`)."""
    names = {'item': None, 'relic': None, **({'material': key} if loot == 'material' else {loot: key})}
    return event(game, kind, wave_, **names, **fields)


def sample():
    on, off = 1, 2  # the games of the session: the Towns on, then off
    return [
        {'tv': 11, 'rec': 'session', 'install': 'i1', 'session': 's1', 'game': 0, 'app': 'dev', 'platform': 'macos', 'ev': 11},
        {'tv': 11, 'rec': 'game', 'install': 'i1', 'session': 's1', 'game': on, 'wave': 0, 'gold': 100, 'lives': 3, 'score': 0},
        wave(1, on, materials={'slimeGel': 3, 'batWing': 2}, crafted={}, materialsUsed={}, town={'blocked': True}),
        wave(2, on, materials={'slimeGel': 1}, crafted={}, materialsUsed={}, town={'chance': 0.5, 'hit': True, 'slot': 3}),
        event(on, 'townMarked', 2, slot=3, chance=0.5, rolls=1),
        event(on, 'townEntered', 2, slot=3, gold=1500, auto=False),
        store(on, 'storeBought', 2, 'item', 'potion', cost=2000),
        store(on, 'storeBought', 2, 'relic', 'fang', cost=12000),
        store(on, 'storeBought', 2, 'material', 'slimeGel', cost=40),
        store(on, 'storeSold', 2, 'item', 'potion', n=2, gain=2000),
        store(on, 'storeSold', 2, 'relic', 'thorns', n=1, gain=6000),
        store(on, 'storeSold', 2, 'material', 'batWing', n=3, gain=45),
        event(on, 'crafted', 2, relic='fang', materials={'batWing': 2, 'slimeGel': 2}, items={}, gold=300),
        event(on, 'itemCrafted', 2, item='sword', materials={'boneShard': 2, 'orcTooth': 2}, items={}, gold=20),
        event(on, 'stoneCrafted', 2, stone='mithril', materials={'boneShard': 3}, gold=50),
        event(on, 'stoneCrafted', 2, stone='mithril', materials={'boneShard': 3}, gold=50),
        event(on, 'itemEnhanced', 2, item='sword', plus=1, stone='mithril', gold=100),
        event(on, 'itemEnhanced', 2, item='sword', plus=2, stone='mithril', gold=200),
        event(on, 'tavernRerolled', 2, price=50, n=1, offers=['feast', 'ale', 'stew']),
        event(on, 'boostBought', 2, boost='feast', rarity='langka', price=100, waves=2, slot=0,
              effects={'dmg': 1.2, 'taken': 0.85}),
        event(on, 'townLeft', 2, slot=3, secs=30.5, auto=True, crafts={'fang': 1}, craftSpent=300,
              tavern={'offered': ['feast', 'ale', 'stew'], 'bought': ['feast'], 'rerolls': 1, 'spent': 150}),
        wave(3, on, end='lost', materials={'boneShard': 4}, crafted={'fang': 1, 'sword': 1},
             materialsUsed={'batWing': 2, 'slimeGel': 2, 'boneShard': 2, 'orcTooth': 2},
             gold={'earned': 100, 'storeSpent': 14040, 'storeEarned': 8045, 'craftSpent': 320, 'tavernSpent': 150},
             boostSaved=1),
        {'tv': 11, 'rec': 'game', 'install': 'i1', 'session': 's1', 'game': off, 'wave': 0, 'gold': 100, 'lives': 3, 'score': 0},
        store(off, 'storeBought', 15, 'item', 'potion', cost=2000),
        wave(15, off),
    ]


def summary(records):
    with tempfile.TemporaryDirectory() as d:
        path = Path(d) / 'telemetry.jsonl'
        path.write_text(''.join(json.dumps(r) + '\n' for r in records), encoding='utf-8')
        return subprocess.run([sys.executable, str(TOOL), str(path)], capture_output=True, text=True, check=True).stdout


class TownLines(unittest.TestCase):
    def test_a_run_with_the_towns_on(self):
        out = summary(sample()).splitlines()
        line = {l.split(':')[0]: l for l in out if ':' in l}
        self.assertEqual(line['towns'], 'towns: 1 entered, 1 left by Auto, 30.5 s inside, 1500 gold brought in '
                                        '(each on average); first at wave 3 x1')
        self.assertEqual(line['town rolls after won waves'], 'town rolls after won waves: 1 rolled, 1 hit; none 1 times '
                                                             '(too soon after a Town), none 0 times (a Town already marked)')
        # The Towns-off run's potion was the field's store: not a Town Shop's.
        self.assertEqual(line['bought in a Town Shop'], 'bought in a Town Shop: 3 for 14040 gold: items 1 for 2000 '
                                                        '(potion 1); relics 1 for 12000 (fang 1); materials 1 for 40 (slimeGel 1)')
        self.assertEqual(line['sold to a Town Shop'], 'sold to a Town Shop: 6 for 8045 gold: items 2 for 2000 (potion 2); '
                                                      'relics bought back 1 for 6000 (thorns 1); materials 3 for 45 (batWing 3)')
        self.assertEqual(line['crafted'], 'crafted: 1 relics for 300 gold: fang 1')
        self.assertEqual(line['crafted items'], 'crafted items: 1 for 20 gold: sword 1')
        self.assertEqual(line['stones made'], 'stones made: 2 for 100 gold: mithril 2')
        self.assertEqual(line['items enhanced'], 'items enhanced: 2 steps for 300 gold and mithril 2; the step reached: '
                                                 '+1 1, +2 1')
        self.assertEqual(line['materials'], 'materials: 10 dropped, 8 used in crafts, 3 sold to a Shop, 1 bought from one; '
                                            'most dropped: boneShard 4, slimeGel 4, batWing 2')
        # The Tavern (decisions-log 268): the visit's buy and reroll, by the wave won before the Town, and Watchman's leak.
        self.assertEqual(line['tavern'], 'tavern: 1 visits, 1 boosts bought (1.00 a visit), 1 rerolls for 50 gold, 150 '
                                         'gold in all; 1 leaks forgiven')
        self.assertEqual(line['tavern by Town (wave won before it'], 'tavern by Town (wave won before it: visits, bought, '
                                                                     'gold): 2: 1, 1, 150')
        self.assertEqual(line['tavern kinds (bought / offered)'], 'tavern kinds (bought / offered): ale 0/1, feast 1/1, '
                                                                  'stew 0/1')
        # The per-wave table's store and Town columns: the Town before wave 3, its buys and crafts in wave 3's record.
        row3 = next(l for l in out if l.split()[:1] == ['3'])
        self.assertEqual(row3.split()[11:16], ['14040', '1', '4.0', '2.00', '320'])

    def test_no_towns_no_town_lines(self):
        off = [r for r in sample() if r.get('game') != 1]
        out = summary(off)
        for word in ('towns:', 'town rolls', 'Town Shop', 'crafted', 'stones made', 'enhanced', 'materials:', 'tavern'):
            self.assertNotIn(word, out)


if __name__ == '__main__':
    unittest.main()
