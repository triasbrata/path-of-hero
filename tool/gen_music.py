#!/usr/bin/env python3
"""Synthesizes the brave SNES-style background loops into assets/music/.

Pure standard library synthesis (plus ffmpeg to encode OGG Vorbis):
    python3 tool/gen_music.py              # into assets/music (never while the game runs)
    python3 tool/gen_music.py <out dir>    # somewhere else, e.g. to try it
ffmpeg's libvorbis is used where it is built in; else ffmpeg's own experimental Vorbis encoder (the
Homebrew ffmpeg has only that one), which takes stereo only. The .wav is made in a temp dir, and the .ogg
only lands in the output once it is whole.
One heroic tune in D minor, written out below as chords and melody, in two arrangements:
- battle.ogg (a wave is running): 144 BPM, pulse lead doubled by a brass octave below,
  dotted brass stabs, galloping bass, march snare with rolls into each phrase.
- idle.ogg (between waves): 100 BPM, the tune on a horn with held brass chords, a
  marching bass and timpani.
Each file loops seamlessly: note tails and the echo wrap around from the end to the start.
"""
import math
import random
import shutil
import struct
import subprocess
import sys
import tempfile
import wave
from pathlib import Path

RATE = 22050
BARS = 16
OUT = Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else Path(__file__).resolve().parent.parent / "assets" / "music"
# ffmpeg Vorbis encoders to try, in order: libvorbis, then ffmpeg's own (experimental, stereo only).
ENCODERS = [["-c:a", "libvorbis", "-q:a", "4"], ["-c:a", "vorbis", "-strict", "experimental", "-ac", "2", "-q:a", "4"]]
BEAT = N = 0  # set per arrangement by render()


def hz(midi):
    return 440 * 2 ** ((midi - 69) / 12)


def add(buf, start_beat, samples, gain):
    """Mixes samples in at a beat position, wrapping past the end (seamless loop)."""
    i0 = int(start_beat * BEAT * RATE)
    for k, s in enumerate(samples):
        buf[(i0 + k) % N] += s * gain


def voice(freq, beats, kind, attack=0.01, release=0.08, decay=0.0, vib=0.0, duty=0.5):
    """One note: kind = pulse | tri | sine. Held for `beats`, then released."""
    held = beats * BEAT
    n = int((held + release) * RATE)
    out, ph = [], 0.0
    for i in range(n):
        t = i / RATE
        f = freq * (1 + vib * math.sin(2 * math.pi * 5.5 * t) * min(1, t / 0.2))
        ph = (ph + f / RATE) % 1.0
        if kind == "pulse":
            s = 0.5 if ph < duty else -0.5
        elif kind == "tri":
            s = 4 * abs(ph - 0.5) - 1
        else:
            s = math.sin(2 * math.pi * ph)
        env = min(1.0, t / attack) * math.exp(-decay * t)
        if t > held:
            env *= max(0.0, 1 - (t - held) / release)
        out.append(s * env)
    return out


def drum(freq, dur, decay, slide=0.0):
    """Pitched thump (kick / timpani): sine that drops by `slide` of its pitch."""
    out, ph = [], 0.0
    for i in range(int(dur * RATE)):
        t = i / RATE
        ph += 2 * math.pi * freq * (1 - slide * min(1, t / dur)) / RATE
        out.append(math.sin(ph) * math.exp(-decay * t))
    return out


def snare(dur=0.14, decay=28):
    return [(random.uniform(-1, 1) * 0.7 + math.sin(2 * math.pi * 200 * i / RATE) * 0.5) * math.exp(-decay * i / RATE)
            for i in range(int(dur * RATE))]


def lowpass(buf, a):
    """One-pole low-pass run twice round the loop so the wrap point is seamless."""
    y = 0.0
    out = [0.0] * N
    for _ in range(2):
        for i in range(N):
            y += a * (buf[i] - y)
            out[i] = y
    return out


def echo(buf, delay_beats=0.75, feedback=0.3, mix=0.25):
    """SNES-style echo: feedback delay line, settled over a few loops for a seamless wrap."""
    d = int(delay_beats * BEAT * RATE)
    line = [0.0] * N
    for _ in range(4):
        for i in range(N):
            line[i] = buf[i] + feedback * line[i - d]  # i - d wraps to the loop's end
    return [buf[i] + mix * line[i - d] for i in range(N)]


# ---- the song ----
A4, Bb4, C5, Cs5, D5, E5, F5, G5, A5 = 69, 70, 72, 73, 74, 76, 77, 79, 81
F4, G4 = 65, 67
CHORDS = {  # voicing, bass root
    "Dm": ([50, 57, 62, 65], 38),
    "Bb": ([50, 53, 58, 62], 34),
    "F": ([53, 57, 60, 65], 41),
    "C": ([52, 55, 60, 64], 36),
    "A": ([52, 57, 61, 64], 33),
    "Gm": ([50, 55, 58, 62], 43),
}
PROGRESSION = [
    "Dm", "Bb", "F", "C", "Dm", "Bb", "C", "A",  # A
    "Bb", "C", "Dm", "Dm", "Gm", "Bb", "A", "A",  # B
]
R = None  # rest
MELODY = [  # (note, beats) per bar, 4 beats each
    [(D5, 1.5), (A4, .5), (D5, 1), (E5, 1)],
    [(F5, 2), (E5, 1), (D5, 1)],
    [(C5, 1.5), (A4, .5), (F4, 1), (A4, 1)],
    [(G4, 2), (C5, 2)],
    [(D5, 1.5), (A4, .5), (D5, 1), (F5, 1)],
    [(G5, 2), (F5, 1), (D5, 1)],
    [(E5, 1), (G5, 1), (E5, 1), (C5, 1)],
    [(Cs5, 3), (R, 1)],
    [(Bb4, 1), (D5, 1), (F5, 2)],
    [(E5, 1), (G5, 1), (E5, 1.5), (C5, .5)],
    [(A5, 2), (F5, 1), (D5, 1)],
    [(A4, 1.5), (D5, .5), (F5, 1), (A5, 1)],
    [(G5, 1.5), (F5, .5), (D5, 1), (Bb4, 1)],
    [(F5, 1.5), (D5, .5), (Bb4, 1), (D5, 1)],
    [(E5, 1), (Cs5, 1), (A4, 1), (E5, 1)],
    [(Cs5, 2), (A4, 1), (R, 1)],
]


def render(name, bpm, battle):
    """Plays the song in one arrangement and writes assets/music/<name>.ogg."""
    global BEAT, N
    BEAT = 60 / bpm
    N = int(round(BARS * 4 * BEAT * RATE))
    random.seed(7)
    lead, brass, bass, drums = ([0.0] * N for _ in range(4))
    for bar, chord in enumerate(PROGRESSION):
        b0 = bar * 4
        notes, root = CHORDS[chord]
        phrase_end = bar % 8 == 7
        if battle:
            # brass: dotted heroic stabs (1, the "and" of 2, 4)
            for at, length, g in ((0, 1.2, 0.07), (1.5, 0.4, 0.05), (3, 0.8, 0.06)):
                for m in notes:
                    add(brass, b0 + at, voice(hz(m), length, "pulse", attack=0.01, release=0.08, decay=1.2, duty=0.5), g)
            # bass: galloping root / root / octave
            for e in range(4):
                for at, step in ((0, 0), (0.5, 0), (0.75, 12)):
                    add(bass, b0 + e + at, voice(hz(root + step), 0.22, "tri", attack=0.003, release=0.04), 0.28)
            # drums: kick on 1 and 3, snare on 2 and 4, a roll into every new phrase
            for at in (0, 2):
                add(drums, b0 + at, drum(95, 0.25, 14, slide=0.5), 0.55)
            for at in (1, 3):
                add(drums, b0 + at, snare(), 0.16)
            if phrase_end:
                for k in range(8):
                    add(drums, b0 + 2 + k / 4, snare(0.08, 40), 0.06 + 0.012 * k)
            for e in range(8):
                hit = [random.uniform(-1, 1) * math.exp(-70 * i / RATE) for i in range(int(0.04 * RATE))]
                add(drums, b0 + e / 2, hit, 0.04 if e % 2 else 0.025)
        else:
            # brass: held chord swelling in, re-struck on 3
            for at, length in ((0, 1.8), (2, 1.8)):
                for m in notes:
                    add(brass, b0 + at, voice(hz(m), length, "pulse", attack=0.08, release=0.25, decay=0.4, duty=0.5), 0.045)
            # bass: marching root and fifth
            for at, step in ((0, 0), (1, 7), (2, 0), (3, 7)):
                add(bass, b0 + at, voice(hz(root + step), 0.8, "tri", attack=0.005, release=0.1), 0.24)
            # timpani on 1 and 3, a light march snare, a roll into each phrase
            for at in (0, 2):
                add(drums, b0 + at, drum(hz(root + 12), 0.6, 5), 0.35)
            for at in (1, 2.75, 3):
                add(drums, b0 + at, snare(0.1, 35), 0.07)
            if phrase_end:
                for k in range(6):
                    add(drums, b0 + 2.5 + k / 4, snare(0.08, 40), 0.03 + 0.01 * k)
        # lead: the same melody; bright pulse (+ brass octave) in battle, a horn between waves
        at = b0
        for m, length in MELODY[bar]:
            if m is not None:
                if battle:
                    add(lead, at, voice(hz(m), length * 0.85, "pulse", attack=0.008, release=0.07, vib=0.004, duty=0.25), 0.16)
                    add(lead, at, voice(hz(m - 12), length * 0.85, "pulse", attack=0.02, release=0.08, duty=0.5), 0.07)
                else:
                    add(lead, at, voice(hz(m - 12), length * 0.95, "pulse", attack=0.05, release=0.2, vib=0.006, duty=0.5), 0.13)
            at += length

    dry = [l + b for l, b in zip(lead, brass)]
    wet = echo(dry, feedback=0.28, mix=0.22) if battle else echo(dry, feedback=0.35, mix=0.3)
    mix = lowpass([w + b + d for w, b, d in zip(wet, bass, drums)], 0.38 if battle else 0.3)  # warm like the SNES DSP
    peak = max(abs(s) for s in mix)

    with tempfile.TemporaryDirectory() as tmp:
        wav, ogg = Path(tmp) / f"{name}.wav", Path(tmp) / f"{name}.ogg"
        with wave.open(str(wav), "wb") as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(RATE)
            w.writeframes(b"".join(struct.pack("<h", int(s / peak * 0.85 * 32767)) for s in mix))
        errors = []
        for args in ENCODERS:
            run = subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", str(wav), *args, str(ogg)], capture_output=True, text=True)
            if run.returncode == 0:
                break
            errors.append(run.stderr.strip())
        else:
            sys.exit(f"ffmpeg has no Vorbis encoder that worked for {name}.ogg:\n" + "\n".join(errors))
        OUT.mkdir(parents=True, exist_ok=True)
        shutil.move(str(ogg), str(OUT / f"{name}.ogg"))
    print(f"wrote {OUT / name}.ogg ({N / RATE:.1f} s loop, {args[1]})")


render("battle", 144, battle=True)
render("idle", 100, battle=False)
