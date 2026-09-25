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
    t, u = clock(1.62, tempo)
    drift = np.zeros_like(t)
    for start in [.02, .43, .83]:
        local = u - start
        drift += np.where(local >= 0, 12 * np.exp(-np.maximum(local, 0) * 21), 0)
    a = phase(315 + drift + 2.2 * np.sin(2 * np.pi * 5.0 * t))
    b = phase(396 + drift + 1.6 * np.sin(2 * np.pi * 4.6 * t))
    brass = sum((np.sin(k * a) + .83 * np.sin(k * b)) / k ** 1.17
                for k in range(1, 10))
    grit = noise(len(t), 5101, low=420, high=3100)
    bursts = np.zeros_like(t)
    for start, length, gain in [(.02, .34, .90), (.43, .33, .94), (.83, .75, 1.0)]:
        local = u - start
        bursts += gain * np.where((local >= 0) & (local < length),
                                  envelope(local, length, .018, .10), 0)
    body = bursts * (.46 * brass + .14 * grit)
    return echo(sosfilt(butter(2, 3200, fs=RATE, output="sos"), body), .052, .13)


def fart(tempo):
    """Fluttering midrange raspberry, audible even on a tiny phone speaker."""
    t, u = clock(1.48, tempo)
    frequency = 162 - 59 * np.clip(u / 1.48, 0, 1)
    frequency += 13 * np.sin(2 * np.pi * 5.4 * u) * np.exp(-u * 1.1)
    p = phase(frequency)
    harmonics = sum(np.sin(k * p + .2 * np.sin(2 * np.pi * 17 * u)) / k ** .83
                    for k in range(1, 11))
    flutter = .43 + .57 * (.5 + .5 * np.sin(2 * np.pi * (17 * u + 5 * u * u))) ** 3
    rasp = noise(len(t), 5102, low=270, high=2200)
    pop = noise(len(t), 5103, low=350, high=2500)
    bursts = np.zeros_like(t)
    for start, length, strength in [(0, .56, .83), (.61, .58, 1.), (1.23, .19, .45)]:
        local = u - start
        bursts += strength * np.where((local >= 0) & (local < length),
                                       envelope(local, length, .008, .12), 0)
    clicks = np.zeros_like(t)
    for start in [.01, .61, 1.23]:
        local = u - start
        clicks += np.where((local >= 0) & (local < .045),
                           np.exp(-np.maximum(local, 0) / .013), 0)
    body = bursts * (.76 * harmonics * flutter + .55 * rasp * (.5 + flutter))
    body += .08 * pop * clicks
    body = sosfilt(butter(2, 90, btype="highpass", fs=RATE, output="sos"), body)
    return np.tanh(body * 2.1)


def sad_trombone(tempo):
    t, u = clock(2.28, tempo)
    result = np.zeros_like(t)
    breath = noise(len(t), 5104, low=250, high=2300)
    notes = [(.02, .37, 247), (.44, .39, 220), (.88, .40, 196), (1.34, .87, 147)]
    for start, length, tone in notes:
        local = u - start
        mask = (local >= 0) & (local < length)
        v = local[mask]
        f = tone * (1 - .075 * np.clip(v / length, 0, 1) ** 2)
        f *= 1 + .005 * np.sin(2 * np.pi * 5.2 * t[mask])
        p = phase(f)
        brass = sum(np.sin(k * p) / k ** 1.26 for k in range(1, 9))
        wah = .73 + .27 * np.sin(2 * np.pi * 2.7 * v)
        result[mask] = (.44 * brass * wah + .07 * breath[mask]) * envelope(v, length, .024, .11)
    return echo(sosfilt(butter(2, 2800, fs=RATE, output="sos"), result), .079, .14)


def ba_dum_tss(tempo):
    t, u = clock(1.46, tempo)
    result = np.zeros_like(t)
    for start, initial, final, length in [(.025, 169, 81, .25), (.32, 152, 77, .29)]:
        local = u - start
        mask = (local >= 0) & (local < length)
        v = local[mask]
        f = final + (initial - final) * np.exp(-v / .044)
        p = phase(f)
        result[mask] += .8 * (np.sin(p) + .34 * np.sin(2 * p)) * np.exp(-v / .13)
        result[mask] += .052 * np.sin(2 * np.pi * 790 * t[mask]) * np.exp(-v / .013)
    snare = noise(len(t), 5105, low=420, high=3900)
    cymbal = noise(len(t), 5106, low=1700, high=7000)
    local = u - .65
    mask = local >= 0
    result[mask] += .9 * snare[mask] * np.exp(-local[mask] / .18)
    result[mask] += .77 * cymbal[mask] * np.exp(-local[mask] / .39)
    return np.tanh(result * 1.5) * envelope(u, 1.46, .003, .12)


def crickets(tempo):
    t, u = clock(2.36, tempo)
    chirps = np.zeros_like(t)
    for start, count in [(.23, 3), (.73, 4), (1.24, 3), (1.77, 4)]:
        for beat in range(count):
            local = u - start - beat * .07
            mask = (local >= 0) & (local < .055)
            v = local[mask]
            carrier = np.sin(2 * np.pi * (1850 * t[mask] + 135 * v * v))
            carrier += .27 * np.sin(2 * np.pi * 2290 * t[mask])
            chirps[mask] += .52 * carrier * np.sin(np.pi * v / .055) ** 2
    bed = noise(len(t), 5107, low=850, high=3500)
    bed *= .018 * (.5 + .5 * np.sin(2 * np.pi * .7 * u))
    return echo(chirps * envelope(u, 2.36, .01, .19) + bed, .031, .12)


def laser(tempo):
    t, u = clock(1.31, tempo)
    zaps = np.zeros_like(t)
    fizz = noise(len(t), 5108, low=900, high=5000)
    for start, strength in [(.04, .88), (.42, .97), (.80, 1.)]:
        local = u - start
        mask = (local >= 0) & (local < .31)
        v = local[mask]
        f = 255 + 820 * np.exp(-v / .075)
        p = phase(f)
        attack = np.exp(-v / .135) * np.clip(v / .004, 0, 1)
        zaps[mask] += strength * (.64 * np.sin(p) + .27 * np.sin(2 * p)) * attack
        zaps[mask] += strength * .19 * fizz[mask] * np.exp(-v / .075)
    return echo(zaps * envelope(u, 1.31, .004, .16), .071, .16)


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
