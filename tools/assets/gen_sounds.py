#!/usr/bin/env python3
"""Synthesizes the TEMPORARY sound effects of Dragon Ball: Infinite Legacy.

Writes Ogg Vorbis files to dbil/mods/dbil_core/sounds. Sound names are mapped
to gameplay meanings in dbil_core/config/theme.lua (theme.sounds), so real
sound design can replace these files without code changes.

Usage: python3 tools/assets/gen_sounds.py   (requires numpy and `oggenc`)
"""
import os
import subprocess
import tempfile
import wave

import numpy as np

RATE = 22050
OUT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "dbil", "mods", "dbil_core", "sounds"))
RNG = np.random.default_rng(7)


def t_axis(duration):
    return np.linspace(0, duration, int(RATE * duration), endpoint=False)


def envelope(n, attack=0.005, release=0.2, curve=3.0):
    t = np.linspace(0, 1, n)
    a = max(1, int(attack * RATE))
    env = np.ones(n)
    env[:a] = np.linspace(0, 1, a)
    env *= (1 - t) ** curve if release else 1
    return env


def lowpass(x, alpha):
    y = np.zeros_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc += alpha * (v - acc)
        y[i] = acc
    return y


def noise(n):
    return RNG.uniform(-1, 1, n)


def sweep(f0, f1, duration, shape="sine"):
    t = t_axis(duration)
    f = np.linspace(f0, f1, len(t))
    phase = 2 * np.pi * np.cumsum(f) / RATE
    if shape == "square":
        return np.sign(np.sin(phase))
    return np.sin(phase)


def normalize(x, peak=0.85):
    m = np.max(np.abs(x)) or 1
    return x / m * peak


def save(name, x):
    os.makedirs(OUT, exist_ok=True)
    data = (normalize(x) * 32767).astype(np.int16)
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tmp:
        wav_path = tmp.name
    with wave.open(wav_path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(data.tobytes())
    ogg_path = os.path.join(OUT, name + ".ogg")
    subprocess.run(["oggenc", "-Q", "-q", "3", "-o", ogg_path, wav_path], check=True)
    os.unlink(wav_path)
    print("wrote", ogg_path)


def punch(duration, body_freq, crack):
    n = int(RATE * duration)
    thump = sweep(body_freq, body_freq * 0.4, duration) * envelope(n, 0.002, 1, 4)
    hit = lowpass(noise(n), 0.35) * envelope(n, 0.001, 1, 10) * crack
    return thump + hit


def main():
    save("dbil_punch_light", punch(0.12, 180, 0.9))
    save("dbil_punch_heavy", punch(0.28, 120, 1.4) + 0.4 * punch(0.28, 70, 0.3))
    n = int(RATE * 0.22)
    swing = lowpass(noise(n), 0.12) * np.sin(np.linspace(0, np.pi, n)) ** 2
    save("dbil_swing", swing)
    n = int(RATE * 0.2)
    block = (sweep(900, 600, 0.2) * 0.5 + lowpass(noise(n), 0.5)) * envelope(n, 0.001, 1, 6)
    save("dbil_block", block)
    n = int(RATE * 0.3)
    dash = lowpass(noise(n), 0.2) * np.sin(np.linspace(0, np.pi, n)) ** 1.5 + 0.3 * sweep(300, 900, 0.3) * envelope(n, 0.01, 1, 2)
    save("dbil_dash", dash)
    n = int(RATE * 0.35)
    fire = (sweep(1400, 300, 0.35) * 0.7 + lowpass(noise(n), 0.3) * 0.5) * envelope(n, 0.003, 1, 2.5)
    save("dbil_ki_fire", fire)
    # Charging hum: rising tone with buzz, loops reasonably.
    dur = 1.2
    n = int(RATE * dur)
    hum = (sweep(110, 220, dur) * 0.6 + sweep(220, 440, dur, "square") * 0.15
           + lowpass(noise(n), 0.08) * 0.6) * np.minimum(1, np.linspace(0, 4, n)) * np.linspace(1, 0.6, n)
    save("dbil_ki_charge", hum)
    dur = 0.9
    n = int(RATE * dur)
    boom = (lowpass(noise(n), 0.08) * 1.2 + sweep(90, 30, dur) * 0.8) * envelope(n, 0.002, 1, 2.2)
    save("dbil_explosion", boom)
    dur = 0.5
    n = int(RATE * dur)
    whoosh = lowpass(noise(n), 0.1) * np.sin(np.linspace(0, np.pi, n)) + 0.3 * sweep(200, 600, dur)
    save("dbil_flight", whoosh * np.linspace(1, 0.3, n))
    # Level up: short ascending arpeggio.
    notes = [523.25, 659.25, 783.99, 1046.5]
    parts = []
    for f in notes:
        n = int(RATE * 0.12)
        tt = t_axis(0.12)
        parts.append((np.sin(2 * np.pi * f * tt) + 0.3 * np.sin(4 * np.pi * f * tt)) * envelope(n, 0.005, 1, 1.5))
    tail = int(RATE * 0.3)
    tt = t_axis(0.3)
    parts.append(np.sin(2 * np.pi * 1046.5 * tt) * envelope(tail, 0.005, 1, 2))
    save("dbil_level_up", np.concatenate(parts))


if __name__ == "__main__":
    main()
