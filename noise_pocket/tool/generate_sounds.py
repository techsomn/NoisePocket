"""Render original, fixed offline effects in three pitch-stable tempos.

Each file is synthesized once and bundled with the app. No playback-time
randomization or playback-rate pitch shifting is used. Noise textures use
fixed seeds so rerunning this script reproduces identical WAV bytes.
Commercial reuse of these original effects is granted without attribution.
"""

from pathlib import Path
import wave

import numpy as np
from scipy.signal import butter, sosfilt

RATE = 44_100
OUT = Path(__file__).resolve().parents[1] / "assets" / "sounds"
OUT.mkdir(parents=True, exist_ok=True)
TEMPOS = {"_slow": 0.75, "": 1.0, "_fast": 1.4}


def timeline(length, tempo):
    t = np.arange(round(RATE * length / tempo), dtype=np.float64) / RATE
    return t, t * tempo


def fade(u, end, attack=0.012, release=0.12):
    return np.clip(u / attack, 0, 1) * np.clip((end - u) / release, 0, 1)


def filtered_noise(size, seed, lo=None, hi=None):
    noise = np.random.default_rng(seed).standard_normal(size)
    if lo and hi:
        filt = butter(2, [lo, hi], btype="bandpass", fs=RATE, output="sos")
    elif hi:
        filt = butter(2, hi, btype="lowpass", fs=RATE, output="sos")
    else:
        filt = butter(2, lo, btype="highpass", fs=RATE, output="sos")
    return sosfilt(filt, noise)


def phase_from_frequency(f):
    return 2 * np.pi * np.cumsum(f) / RATE


def save(name, data):
    data = np.asarray(data, dtype=np.float64)
    data -= data.mean()
    # Soft saturation retains dynamics without digital clipping.
    data = np.tanh(data * 1.15)
    peak = np.max(np.abs(data))
    if peak:
        data *= 0.78 / peak
    edge = min(round(RATE * .008), len(data) // 2)
    if edge:
        data[:edge] *= np.linspace(0, 1, edge)
        data[-edge:] *= np.linspace(1, 0, edge)
    with wave.open(str(OUT / f"{name}.wav"), "wb") as audio:
        audio.setnchannels(1)
        audio.setsampwidth(2)
        audio.setframerate(RATE)
        audio.writeframes(np.round(data * 32767).astype("<i2").tobytes())


def air_horn(tempo):
    t, u = timeline(1.56, tempo)
    phase_a = phase_from_frequency(330 + 9 * np.exp(-u * 18))
    phase_b = phase_from_frequency(415 + 11 * np.exp(-u * 15))
    brass = sum(
        (np.sin(k * phase_a) + .8 * np.sin(k * phase_b)) / k ** 1.4
        for k in range(1, 7)
    )
    breath = filtered_noise(len(t), 2101, lo=300, hi=1900)
    bursts = (
        np.clip((u - .02) / .05, 0, 1) * np.clip((.73 - u) / .16, 0, 1)
        + np.clip((u - .78) / .05, 0, 1) * np.clip((1.56 - u) / .24, 0, 1)
    )
    mixed = bursts * (.38 * brass + .055 * breath)
    return sosfilt(butter(2, 2650, fs=RATE, output="sos"), mixed)


def fart(tempo):
    t, u = timeline(1.25, tempo)
    frequency = 112 - 49 * np.clip(u / 1.25, 0, 1)
    frequency += 5 * np.sin(2 * np.pi * 7.5 * u) * np.exp(-u * 2)
    phase = phase_from_frequency(frequency)
    buzz = np.sin(phase) + .28 * np.sin(2 * phase) + .08 * np.sin(3 * phase)
    pulses = .5 + .5 * np.sin(2 * np.pi * (15 * u + 2.5 * u * u))
    sputter = (.32 + .68 * pulses ** 3) * buzz
    breath = filtered_noise(len(t), 2102, hi=420)
    return fade(u, 1.25, .018, .27) * (.65 * sputter + .07 * breath)


def sad_trombone(tempo):
    t, u = timeline(2.12, tempo)
    notes = [(0.00, .33, 220), (.39, .37, 196), (.82, .38, 174), (1.26, .82, 131)]
    music = np.zeros_like(t)
    for start, duration, fundamental in notes:
        local = u - start
        mask = (local >= 0) & (local < duration)
        v = local[mask]
        f = fundamental * (1 - .035 * v / duration)
        f *= 1 + .003 * np.sin(2 * np.pi * 4.3 * t[mask])
        phase = phase_from_frequency(f)
        brass = sum(np.sin(k * phase) / k ** 1.55 for k in range(1, 7))
        wah = .79 + .21 * np.sin(2 * np.pi * 2.6 * v)
        music[mask] = .41 * brass * wah * fade(v, duration, .022, .105)
    # A quiet room reflection keeps the notes from sounding completely dry.
    delay = round(.065 * RATE)
    music[delay:] += .11 * music[:-delay].copy()
    return sosfilt(butter(2, 2350, fs=RATE, output="sos"), music)


def ba_dum_tss(tempo):
    t, u = timeline(1.27, tempo)
    mixed = np.zeros_like(t)
    for start, start_hz, end_hz, decay, gain in [
        (.02, 150, 80, .15, .70),
        (.30, 130, 65, .17, .85),
    ]:
        local = u - start
        mask = local >= 0
        v = local[mask]
        # Integrate in real seconds: tempo alters timing, not the kick's pitch.
        frequency = end_hz + (start_hz - end_hz) * np.exp(-v / .055)
        phase = phase_from_frequency(frequency)
        mixed[mask] += (
            gain * np.sin(phase) * np.exp(-v / decay)
            * np.clip(v / .006, 0, 1)
        )
    snare = filtered_noise(len(t), 2103, lo=400, hi=2400)
    cymbal = filtered_noise(len(t), 2104, lo=1700, hi=4600)
    tail = u - .58
    mask = tail >= 0
    mixed[mask] += .18 * snare[mask] * np.exp(-tail[mask] / .14)
    mixed[mask] += .19 * cymbal[mask] * np.exp(-tail[mask] / .25)
    return mixed * fade(u, 1.27, .004, .13)


def crickets(tempo):
    t, u = timeline(2.15, tempo)
    chirps = np.zeros_like(t)
    for group in [.08, .58, 1.12, 1.64]:
        for beat in range(4):
            local = u - group - beat * .061
            mask = (local >= 0) & (local < .045)
            v = local[mask]
            carrier = np.sin(2 * np.pi * (1950 * t[mask] + 160 * v * v))
            tremolo = np.sin(np.pi * v / .045) ** 2
            chirps[mask] += .5 * carrier * tremolo
    return chirps * fade(u, 2.15, .015, .22)


def laser(tempo):
    t, u = timeline(1.05, tempo)
    zaps = np.zeros_like(t)
    for start in [.04, .45]:
        local = u - start
        mask = (local >= 0) & (local < .33)
        v = local[mask]
        f = 180 + 720 * np.exp(-v / .078)
        phase = phase_from_frequency(f)
        zaps[mask] += .62 * np.sin(phase) * np.exp(-v / .15)
        zaps[mask] += .14 * np.sin(2 * phase) * np.exp(-v / .11)
    delay = round(.095 * RATE)
    zaps[delay:] += .13 * zaps[:-delay].copy()
    return zaps * fade(u, 1.05, .009, .18)


EFFECTS = {
    "air_horn": air_horn,
    "fart": fart,
    "sad_trombone": sad_trombone,
    "ba_dum_tss": ba_dum_tss,
    "crickets": crickets,
    "laser": laser,
}

if __name__ == "__main__":
    for name, renderer in EFFECTS.items():
        for suffix, tempo in TEMPOS.items():
            save(name + suffix, renderer(tempo))
    print(f"Created {len(EFFECTS) * len(TEMPOS)} fixed, pitch-stable WAV files in {OUT}")
