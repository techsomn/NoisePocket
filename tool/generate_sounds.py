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
    phone = sosfilt(butter(2, [250, 6000], btype="bandpass", fs=RATE,
                            output="sos"), data)
    phone_rms = np.sqrt(np.mean(phone * phone))
    if phone_rms > .31:
        data *= .31 / phone_rms
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


def applause(tempo):
    t, u = clock(1.88, tempo)
    claps = np.zeros_like(t)
    texture = noise(len(t), 6201, low=350, high=5500)
    times = [.08, .17, .27, .35, .43, .54, .63, .72, .80, .89,
             1.00, 1.08, 1.18, 1.28, 1.37, 1.48, 1.60]
    for i, start in enumerate(times):
        v = u - start
        mask = (v >= 0) & (v < .10)
        claps[mask] += (.57 + .14 * (i % 3)) * texture[mask] * np.exp(-v[mask] / .024)
    wash = noise(len(t), 6202, low=500, high=3400)
    return echo((claps + .075 * wash * envelope(u, 1.88, .12, .36)), .047, .15)


def boo(tempo):
    t, u = clock(1.56, tempo)
    voices = np.zeros_like(t)
    for fundamental, offset in [(164, 0), (187, .03), (213, .06)]:
        p = phase(fundamental + 5 * np.sin(2 * np.pi * (3.2 + offset) * t + offset))
        voices += (np.sin(p) + .32 * np.sin(2 * p) + .12 * np.sin(3 * p)) / 3
    breath = noise(len(t), 6203, low=280, high=1800)
    wobble = .83 + .17 * np.sin(2 * np.pi * 4.1 * u)
    return echo((.84 * voices * wobble + .18 * breath)
                * envelope(u, 1.56, .13, .35), .071, .12)


def whistle(tempo):
    t, u = clock(1.16, tempo)
    result = np.zeros_like(t)
    breath = noise(len(t), 6204, low=600, high=3000)
    for start, length, low, high in [(.05, .43, 700, 880), (.56, .48, 820, 730)]:
        v = u - start
        mask = (v >= 0) & (v < length)
        f = low + (high - low) * np.sin(np.pi * np.clip(v[mask] / length, 0, 1) / 2)
        p = phase(f + 7 * np.sin(2 * np.pi * 5 * t[mask]))
        result[mask] += (.74 * np.sin(p) + .08 * np.sin(2 * p)
                         + .075 * breath[mask]) * envelope(v[mask], length, .045, .095)
    return result


def boing(tempo):
    t, u = clock(1.0, tempo)
    f = 135 + 410 * np.exp(-u / .17)
    p = phase(f + 13 * np.sin(2 * np.pi * 8.5 * u) * np.exp(-u * 3.5))
    spring = np.sin(p) + .36 * np.sin(2 * p) + .15 * np.sin(3 * p)
    spring *= np.exp(-u / .31) * np.clip(u / .005, 0, 1)
    return echo(spring, .115, .31) * envelope(u, 1., .004, .13)


def squeak(tempo):
    t, u = clock(1.15, tempo)
    result = np.zeros_like(t)
    air = noise(len(t), 6205, low=400, high=1900)
    for start, length, pitch in [(.04, .40, 510), (.57, .46, 555)]:
        v = u - start
        mask = (v >= 0) & (v < length)
        f = pitch + 230 * np.sin(np.pi * v[mask] / length)
        p = phase(f)
        result[mask] += (.62 * np.sin(p) + .28 * np.sin(2 * p)
                         + .075 * air[mask]) * envelope(v[mask], length, .01, .10)
    return result


def pop(tempo):
    t, u = clock(.68, tempo)
    out = np.zeros_like(t)
    snap = noise(len(t), 6206, low=210, high=4500)
    for start, size in [(.025, 1.), (.31, .46)]:
        v = u - start
        mask = (v >= 0) & (v < .19)
        local = v[mask]
        f = 145 + 140 * np.exp(-local / .026)
        p = phase(f)
        out[mask] += size * (.45 * np.sin(p) + .8 * snap[mask]) * np.exp(-local / .037)
    return echo(out, .046, .12) * envelope(u, .68, .003, .07)


def record_scratch(tempo):
    t, u = clock(1.12, tempo)
    result = np.zeros_like(t)
    grit = noise(len(t), 6207, low=300, high=4100)
    for start, length, direction in [(.04, .34, 1), (.41, .30, -1), (.75, .30, 1)]:
        v = u - start
        mask = (v >= 0) & (v < length)
        local = v[mask]
        f = 290 + 420 * (local / length if direction == 1 else 1 - local / length)
        p = phase(f)
        pulses = .62 + .38 * np.sin(2 * np.pi * 31 * t[mask]) ** 2
        result[mask] += (.29 * np.sin(p) + .65 * grit[mask]) * pulses * envelope(local, length, .014, .08)
    return np.tanh(result * 1.8)


def whoosh(tempo):
    t, u = clock(1.23, tempo)
    rise = np.sin(np.pi * np.clip(u / 1.23, 0, 1)) ** 2
    low = noise(len(t), 6208, low=180, high=1200)
    mid = noise(len(t), 6209, low=650, high=3400)
    high = noise(len(t), 6210, low=2200, high=7200)
    sweep = np.clip(u / .85, 0, 1)
    out = rise * (.38 * low * (1 - .65 * sweep) + .4 * mid
                  + .31 * high * sweep)
    out += .08 * np.sin(2 * np.pi * 125 * t) * rise
    return echo(out, .061, .09)


def splash(tempo):
    t, u = clock(1.42, tempo)
    result = np.zeros_like(t)
    water = noise(len(t), 6211, low=280, high=6000)
    v = u - .06
    mask = v >= 0
    result[mask] += .72 * water[mask] * np.exp(-v[mask] / .26)
    for i, start in enumerate([.21, .34, .50, .68, .87, 1.06]):
        local = u - start
        mask = (local >= 0) & (local < .22)
        p = phase(650 - 90 * i - 310 * local[mask])
        result[mask] += (.34 * np.sin(p) + .11 * water[mask]) * np.exp(-local[mask] / .08)
    return echo(result * envelope(u, 1.42, .006, .23), .083, .15)


def coin(tempo):
    t, u = clock(.98, tempo)
    result = np.zeros_like(t)
    for start, fundamental, gain in [(.03, 988, 1.), (.23, 1319, .85)]:
        v = u - start
        mask = v >= 0
        p = 2 * np.pi * fundamental * t[mask]
        result[mask] += gain * (.62 * np.sin(p) + .23 * np.sin(1.51 * p)
                                + .15 * np.sin(2.03 * p)) * np.exp(-v[mask] / .24)
    return echo(result * envelope(u, .98, .004, .19), .086, .21)


def power_up(tempo):
    t, u = clock(1.32, tempo)
    result = np.zeros_like(t)
    for start, pitch in [(.03, 330), (.26, 440), (.49, 554), (.72, 659)]:
        v = u - start
        mask = (v >= 0) & (v < .36)
        p = 2 * np.pi * pitch * t[mask]
        result[mask] += (.62 * np.sin(p) + .19 * np.sin(2 * p)) * envelope(v[mask], .36, .01, .17)
    v = u - .96
    mask = v >= 0
    result[mask] += .26 * np.sin(2 * np.pi * 880 * t[mask]) * np.exp(-v[mask] / .15)
    return echo(result * envelope(u, 1.32, .004, .19), .079, .16)


def error_buzz(tempo):
    t, u = clock(.92, tempo)
    out = np.zeros_like(t)
    for start, pitch, length in [(.035, 230, .28), (.43, 196, .35)]:
        v = u - start
        mask = (v >= 0) & (v < length)
        p = 2 * np.pi * pitch * t[mask]
        buzz = np.sin(p) + .55 * np.sin(3 * p) + .29 * np.sin(5 * p)
        out[mask] += .61 * buzz * envelope(v[mask], length, .004, .05)
    return np.tanh(out * 1.7) * envelope(u, .92, .003, .12)


def robot_beep(tempo):
    t, u = clock(1.16, tempo)
    out = np.zeros_like(t)
    for start, pitch in [(.03, 470), (.27, 680), (.52, 540), (.78, 755)]:
        v = u - start
        mask = (v >= 0) & (v < .19)
        p = 2 * np.pi * pitch * t[mask]
        out[mask] += (.68 * np.sin(p) + .27 * np.sin(2 * p)
                      + .09 * np.sin(4 * p)) * envelope(v[mask], .19, .006, .035)
    return echo(out, .063, .11)


def game_over(tempo):
    t, u = clock(1.68, tempo)
    out = np.zeros_like(t)
    for start, pitch, length in [(.03, 494, .30), (.37, 392, .32),
                                 (.76, 294, .36), (1.19, 196, .42)]:
        v = u - start
        mask = (v >= 0) & (v < length)
        p = 2 * np.pi * pitch * t[mask]
        synth = np.sin(p) + .28 * np.sin(2 * p) + .14 * np.sin(3 * p)
        out[mask] += .54 * synth * envelope(v[mask], length, .008, .13)
    return echo(out * envelope(u, 1.68, .005, .12), .087, .14)


def doorbell(tempo):
    t, u = clock(1.72, tempo)
    out = np.zeros_like(t)
    for start, pitch in [(.04, 784), (.72, 523)]:
        v = u - start
        mask = v >= 0
        p = 2 * np.pi * pitch * t[mask]
        chime = .6 * np.sin(p) + .27 * np.sin(1.498 * p) + .14 * np.sin(2.012 * p)
        out[mask] += chime * np.exp(-v[mask] / .42) * np.clip(v[mask] / .008, 0, 1)
    return echo(out * envelope(u, 1.72, .004, .2), .11, .23)


def knock(tempo):
    t, u = clock(1.1, tempo)
    out = np.zeros_like(t)
    wood = noise(len(t), 6212, low=350, high=3300)
    for start, gain in [(.06, .9), (.36, 1.), (.68, .87)]:
        v = u - start
        mask = (v >= 0) & (v < .19)
        local = v[mask]
        p = phase(105 + 130 * np.exp(-local / .018))
        out[mask] += gain * (.6 * np.sin(p) + 1.1 * wood[mask]) * np.exp(-local / .055)
    return echo(np.tanh(out * 1.8) * envelope(u, 1.1, .004, .11), .067, .17)


def camera(tempo):
    t, u = clock(.86, tempo)
    out = np.zeros_like(t)
    click = noise(len(t), 6213, low=450, high=6500)
    motor = noise(len(t), 6214, low=250, high=2200)
    for start, gain in [(.045, .9), (.17, 1.), (.33, .6)]:
        v = u - start
        mask = (v >= 0) & (v < .08)
        out[mask] += gain * click[mask] * np.exp(-v[mask] / .012)
    v = u - .18
    mask = (v >= 0) & (v < .38)
    out[mask] += .26 * motor[mask] * envelope(v[mask], .38, .012, .1)
    return echo(out * envelope(u, .86, .003, .1), .039, .13)


def thunder(tempo):
    t, u = clock(2.42, tempo)
    low = noise(len(t), 6215, low=80, high=850)
    mid = noise(len(t), 6216, low=220, high=3000)
    crack = noise(len(t), 6217, low=650, high=6900)
    roll = .28 + .72 * np.exp(-u / 1.25)
    roll *= .8 + .2 * np.sin(2 * np.pi * 5.1 * u) ** 2
    out = (.65 * low + .39 * mid) * roll
    for start, strength in [(.08, .8), (.73, .48)]:
        v = u - start
        mask = (v >= 0) & (v < .22)
        out[mask] += strength * crack[mask] * np.exp(-v[mask] / .048)
    return np.tanh(out * 1.8) * envelope(u, 2.42, .008, .36)


def ghost(tempo):
    t, u = clock(1.96, tempo)
    a = phase(262 + 9 * np.sin(2 * np.pi * 1.6 * u))
    b = phase(350 + 7 * np.sin(2 * np.pi * 1.3 * u + .4))
    breath = noise(len(t), 6218, low=280, high=2600)
    formant = .68 * np.sin(a) + .29 * np.sin(2 * a)
    formant += .47 * np.sin(b) + .17 * np.sin(3 * b)
    swell = np.sin(np.pi * np.clip(u / 1.96, 0, 1)) ** 1.4
    return echo((formant * (.78 + .22 * np.sin(2 * np.pi * 3.4 * u))
                 + .15 * breath) * swell, .132, .28)


def snore(tempo):
    t, u = clock(2.28, tempo)
    f = 132 + 16 * np.sin(2 * np.pi * 2.8 * u)
    p = phase(f)
    nasal = sum(np.sin(k * p) / k ** .9 for k in range(1, 8))
    breath = noise(len(t), 6219, low=250, high=1900)
    cycles = np.zeros_like(t)
    for start, length in [(.08, .82), (1.12, .92)]:
        v = u - start
        cycles += np.where((v >= 0) & (v < length),
                           envelope(v, length, .16, .24), 0)
    flutter = .65 + .35 * np.sin(2 * np.pi * 11 * u) ** 2
    return echo((.6 * nasal * flutter + .38 * breath) * cycles, .075, .1)


EFFECTS = {
    "air_horn": air_horn,
    "fart": fart,
    "sad_trombone": sad_trombone,
    "ba_dum_tss": ba_dum_tss,
    "crickets": crickets,
    "laser": laser,
    "applause": applause,
    "boo": boo,
    "whistle": whistle,
    "boing": boing,
    "squeak": squeak,
    "pop": pop,
    "record_scratch": record_scratch,
    "whoosh": whoosh,
    "splash": splash,
    "coin": coin,
    "power_up": power_up,
    "error_buzz": error_buzz,
    "robot_beep": robot_beep,
    "game_over": game_over,
    "doorbell": doorbell,
    "knock": knock,
    "camera": camera,
    "thunder": thunder,
    "ghost": ghost,
    "snore": snore,
}

if __name__ == "__main__":
    for name, effect in EFFECTS.items():
        for suffix, tempo in TEMPOS.items():
            save(name + suffix, effect(tempo))
    print(f"Wrote {len(EFFECTS) * len(TEMPOS)} fixed WAV recordings to {OUT}")
