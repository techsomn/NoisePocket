"""Render original, fixed, offline effects in three pitch-stable tempos.

Noise textures have fixed seeds. Nothing is randomized or pitch-shifted when a
pad is tapped. Commercial reuse of these original effects is permitted without
attribution.
"""

from pathlib import Path
import wave

import numpy as np
from scipy.signal import butter, sosfilt

RATE = 44_100
OUT = Path(__file__).resolve().parents[1] / "assets" / "sounds"
OUT.mkdir(parents=True, exist_ok=True)
TEMPOS = {"_slow": .75, "": 1., "_fast": 1.4}


def clock(length, tempo):
    t = np.arange(round(length * RATE / tempo), dtype=np.float64) / RATE
    return t, t * tempo


def phase(frequency):
    """Integrate Hz over real seconds, so event tempo cannot shift pitch."""
    return 2 * np.pi * np.cumsum(frequency) / RATE


def envelope(local, length, attack=.012, release=.15):
    return np.clip(local / attack, 0, 1) * np.clip((length - local) / release, 0, 1)


def noise(length, seed, low=None, high=None):
    raw = np.random.default_rng(seed).standard_normal(length)
    if low and high:
        sos = butter(2, [low, high], btype="bandpass", fs=RATE, output="sos")
    elif low:
        sos = butter(2, low, btype="highpass", fs=RATE, output="sos")
    else:
        sos = butter(2, high, btype="lowpass", fs=RATE, output="sos")
    return sosfilt(sos, raw)


def echo(data, seconds, amount):
    delay = round(seconds * RATE)
    result = data.copy()
    result[delay:] += amount * data[:-delay]
    return result


def save(name, data):
    data = np.asarray(data, dtype=np.float64)
    data -= data.mean()
    data = np.tanh(data * 1.2)  # Soften transients without digital clipping.
    peak = np.max(np.abs(data))
    if peak:
        data *= .82 / peak
    edge = min(round(.006 * RATE), len(data) // 2)
    data[:edge] *= np.linspace(0, 1, edge)
    data[-edge:] *= np.linspace(1, 0, edge)
    with wave.open(str(OUT / f"{name}.wav"), "wb") as wav:
        wav.setnchannels(1)
        wav.setsampwidth(2)
        wav.setframerate(RATE)
        wav.writeframes(np.round(data * 32767).astype("<i2").tobytes())


def air_horn(tempo):
    t, u = clock(1.48, tempo)
    drift = 7 * np.exp(-u * 16)
    a = phase(349 + drift + 1.7 * np.sin(2 * np.pi * 5.1 * t))
    b = phase(440 + drift + 1.4 * np.sin(2 * np.pi * 4.7 * t))
    brass = sum((np.sin(k * a) + .74 * np.sin(k * b)) / k ** 1.25
                for k in range(1, 9))
    grit = noise(len(t), 4101, low=350, high=2800)
    bursts = np.zeros_like(t)
    for start, length in [(.025, .62), (.72, .74)]:
        local = u - start
        bursts += np.where((local >= 0) & (local < length),
                           envelope(local, length, .028, .14), 0)
    body = bursts * (.42 * brass + .1 * grit)
    return echo(sosfilt(butter(2, 3400, fs=RATE, output="sos"), body), .055, .13)


def fart(tempo):
    """Fluttering midrange raspberry, audible even on a tiny phone speaker."""
    t, u = clock(1.26, tempo)
    frequency = 155 - 54 * np.clip(u / 1.26, 0, 1)
    frequency += 11 * np.sin(2 * np.pi * 4.5 * u) * np.exp(-u * 1.2)
    p = phase(frequency)
    harmonics = sum(np.sin(k * p + .14 * np.sin(2 * np.pi * 19 * u)) / k ** .85
                    for k in range(1, 10))
    flutter = .46 + .54 * (.5 + .5 * np.sin(2 * np.pi * (19 * u + 4 * u * u))) ** 3
    rasp = noise(len(t), 4102, low=260, high=1900)
    pop = noise(len(t), 4103, low=330, high=2200)
    bursts = np.zeros_like(t)
    for start, length, strength in [(0, .69, 1.), (.74, .47, .86)]:
        local = u - start
        bursts += strength * np.where((local >= 0) & (local < length),
                                       envelope(local, length, .013, .18), 0)
    clicks = np.zeros_like(t)
    for start in [.012, .75]:
        local = u - start
        clicks += np.where((local >= 0) & (local < .055),
                           np.exp(-np.maximum(local, 0) / .017), 0)
    body = bursts * (.72 * harmonics * flutter + .53 * rasp * (.5 + flutter))
    body += .07 * pop * clicks
    body = sosfilt(butter(2, 90, btype="highpass", fs=RATE, output="sos"), body)
    return np.tanh(body * 2.4)


def sad_trombone(tempo):
    t, u = clock(2.1, tempo)
    result = np.zeros_like(t)
    notes = [(.02, .34, 233), (.42, .35, 207), (.84, .35, 185), (1.25, .79, 139)]
    for start, length, tone in notes:
        local = u - start
        mask = (local >= 0) & (local < length)
        v = local[mask]
        f = tone * (1 - .055 * np.clip(v / length, 0, 1))
        f *= 1 + .006 * np.sin(2 * np.pi * 4.8 * t[mask])
        p = phase(f)
        brass = sum(np.sin(k * p) / k ** 1.2 for k in range(1, 8))
        wah = .76 + .24 * np.sin(2 * np.pi * 2.9 * v)
        result[mask] = .44 * brass * wah * envelope(v, length, .018, .09)
    return echo(sosfilt(butter(2, 2900, fs=RATE, output="sos"), result), .072, .16)


def ba_dum_tss(tempo):
    t, u = clock(1.35, tempo)
    result = np.zeros_like(t)
    for start, initial, final, length in [(.025, 162, 75, .24), (.33, 146, 72, .27)]:
        local = u - start
        mask = (local >= 0) & (local < length)
        v = local[mask]
        f = final + (initial - final) * np.exp(-v / .044)
        p = phase(f)
        result[mask] += .78 * (np.sin(p) + .28 * np.sin(2 * p)) * np.exp(-v / .12)
        result[mask] += .045 * np.sin(2 * np.pi * 790 * t[mask]) * np.exp(-v / .012)
    snare = noise(len(t), 4104, low=350, high=3600)
    cymbal = noise(len(t), 4105, low=1800, high=6800)
    local = u - .66
    mask = local >= 0
    result[mask] += .85 * snare[mask] * np.exp(-local[mask] / .17)
    result[mask] += .7 * cymbal[mask] * np.exp(-local[mask] / .35)
    return np.tanh(result * 1.55) * envelope(u, 1.35, .003, .11)


def crickets(tempo):
    t, u = clock(2.12, tempo)
    chirps = np.zeros_like(t)
    for start in [.08, .56, 1.07, 1.57]:
        for beat in range(4):
            local = u - start - beat * .063
            mask = (local >= 0) & (local < .052)
            v = local[mask]
            carrier = np.sin(2 * np.pi * (1960 * t[mask] + 110 * v * v))
            carrier += .23 * np.sin(2 * np.pi * 2440 * t[mask])
            chirps[mask] += .47 * carrier * np.sin(np.pi * v / .052) ** 2
    bed = noise(len(t), 4106, low=600, high=3000)
    bed *= .019 * (.55 + .45 * np.sin(2 * np.pi * .6 * u))
    return echo(chirps * envelope(u, 2.12, .01, .13) + bed, .029, .13)


def laser(tempo):
    t, u = clock(1.15, tempo)
    zaps = np.zeros_like(t)
    fizz = noise(len(t), 4107, low=750, high=4400)
    for start in [.04, .49]:
        local = u - start
        mask = (local >= 0) & (local < .34)
        v = local[mask]
        f = 245 + 810 * np.exp(-v / .09)
        p = phase(f)
        attack = np.exp(-v / .145) * np.clip(v / .004, 0, 1)
        zaps[mask] += (.62 * np.sin(p) + .25 * np.sin(2 * p)) * attack
        zaps[mask] += .18 * fizz[mask] * np.exp(-v / .075)
    return echo(zaps * envelope(u, 1.15, .004, .12), .075, .16)


EFFECTS = {
    "air_horn": air_horn,
    "fart": fart,
    "sad_trombone": sad_trombone,
    "ba_dum_tss": ba_dum_tss,
    "crickets": crickets,
    "laser": laser,
}

if __name__ == "__main__":
    for name, effect in EFFECTS.items():
        for suffix, tempo in TEMPOS.items():
            save(name + suffix, effect(tempo))
    print(f"Wrote {len(EFFECTS) * len(TEMPOS)} fixed WAV recordings to {OUT}")
