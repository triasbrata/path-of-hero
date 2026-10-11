#!/usr/bin/env python3
"""Synthesizes the game's sound effects into assets/sfx/*.wav (22.05 kHz, 16-bit mono).

Pure standard library, so the sounds can be tweaked here and regenerated:
    python3 tool/gen_sfx.py
File names must match the `Sfx` enum in lib/game.dart.
"""
import math
import random
import struct
import wave
from pathlib import Path

RATE = 22050
OUT = Path(__file__).resolve().parent.parent / "assets" / "sfx"


def note(freq, dur, shape="sine", attack=0.005, decay=6.0, vol=1.0, slide=None, partials=((1, 1.0),)):
    """One note. decay: exponential fade rate per second. slide: end frequency (glide)."""
    n = int(dur * RATE)
    out, phase = [], [0.0] * len(partials)
    for i in range(n):
        t = i / RATE
        f = freq if slide is None else freq + (slide - freq) * (i / n)
        env = min(1.0, t / attack) * math.exp(-decay * t) * min(1.0, (n - i) / (0.004 * RATE))
        s = 0.0
        for k, (mult, amp) in enumerate(partials):
            phase[k] += 2 * math.pi * f * mult / RATE
            p = phase[k]
            if shape == "sine":
                s += amp * math.sin(p)
            elif shape == "square":
                s += amp * (0.6 if math.sin(p) >= 0 else -0.6)
            elif shape == "tri":
                s += amp * (2 / math.pi) * math.asin(math.sin(p))
        out.append(s * env * vol)
    return out


def noise(dur, vol=1.0, decay=30.0, smooth=0.5, attack=0.0):
    """Filtered noise burst (one-pole low-pass; smooth 0..1, higher = duller)."""
    out, y = [], 0.0
    for i in range(int(dur * RATE)):
        t = i / RATE
        y = smooth * y + (1 - smooth) * random.uniform(-1, 1)
        out.append(y * vol * math.exp(-decay * t) * (min(1.0, t / attack) if attack else 1))
    return out


def rest(dur):
    return [0.0] * int(dur * RATE)


def mix(*tracks):
    n = max(len(t) for t in tracks)
    return [sum(t[i] for t in tracks if i < len(t)) for i in range(n)]


def seq(*parts):
    return [s for p in parts for s in p]


def save(name, samples, peak=0.8):
    top = max(1e-9, max(abs(s) for s in samples))
    OUT.mkdir(parents=True, exist_ok=True)
    with wave.open(str(OUT / f"{name}.wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", int(s / top * peak * 32767)) for s in samples))


D5, F5, A5, D6 = 587.3, 698.5, 880.0, 1174.7
bell = ((1, 1.0), (2.0, 0.35), (2.76, 0.2))
brass = ((1, 1.0), (2, 0.5), (3, 0.3))

random.seed(1)
SOUNDS = {
    # troop placed: boots landing + armour ring
    "place": mix(noise(0.06, vol=0.8, decay=50, smooth=0.4), note(140, 0.14, decay=22),
                 note(1400, 0.2, decay=18, vol=0.25, partials=bell)),
    # knight: sword swish then a clang
    "sword": seq(noise(0.06, vol=0.7, decay=25, smooth=0.1, attack=0.03),
                 note(1800, 0.08, decay=45, vol=0.4, partials=((1, 1.0), (1.47, 0.6)))),
    # rogue: quick dagger flick
    "dagger": noise(0.05, vol=0.6, decay=70, smooth=0.05, attack=0.01),
    # wizard: rising sparkle
    "magic": mix(note(600, 0.22, "tri", decay=9, slide=1500), note(1200, 0.22, decay=12, vol=0.3, slide=2600)),
    # a monster strikes: dull thump
    "hit": mix(noise(0.07, vol=0.7, decay=45, smooth=0.6), note(110, 0.1, decay=30, vol=0.8)),
    # a troop falls: armour clatter sliding down
    "fall": seq(noise(0.05, vol=0.6, decay=40, smooth=0.2), note(520, 0.3, "tri", decay=6, slide=180)),
    # monster down: poof + coin
    "kill": seq(noise(0.05, vol=0.6, decay=50, smooth=0.6), note(1318.5, 0.04, decay=30, partials=bell),
                note(1760, 0.12, decay=22, partials=bell)),
    # a monster got through: low warning thud
    "leak": seq(note(180, 0.14, "square", decay=10, vol=0.6), note(120, 0.25, "square", decay=8, vol=0.6)),
    # wave starts: war horn call
    "wave": seq(note(293.7, 0.18, "square", attack=0.02, decay=2, vol=0.5, partials=brass),
                note(440, 0.18, "square", attack=0.02, decay=2, vol=0.5, partials=brass),
                note(587.3, 0.5, "square", attack=0.02, decay=2.5, vol=0.5, partials=brass)),
    # wave cleared: short victory fanfare
    "clear": seq(*(note(f, 0.1, "tri", decay=6) for f in (D5, F5, A5)),
                 mix(note(D6, 0.7, "tri", decay=3), note(A5, 0.7, "tri", decay=3, vol=0.6))),
    # can't place / not enough gold: low double buzz
    "error": seq(note(150, 0.08, "square", decay=8, vol=0.5), rest(0.04), note(150, 0.1, "square", decay=8, vol=0.5)),
    # defeat: slow descending minor line
    "lose": seq(note(392, 0.3, "tri", decay=3), note(311.1, 0.3, "tri", decay=3), note(293.7, 0.8, "tri", decay=2)),
    # a UI button pressed: a short soft wooden tock (last, so the sounds above keep their random draws)
    "click": mix(noise(0.018, vol=0.5, decay=220, smooth=0.25), note(1250, 0.045, decay=70, vol=0.5, partials=((1, 1.0), (2.4, 0.3)))),
}

for name, samples in SOUNDS.items():
    save(name, samples)
print(f"wrote {len(SOUNDS)} sounds to {OUT}")
