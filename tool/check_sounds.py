"""Check every bundled WAV, tempo, and approximate phone-speaker audibility."""

from pathlib import Path
import wave

import numpy as np
from scipy.signal import butter, sosfilt

SOUNDS = (
    "air_horn", "fart", "sad_trombone", "ba_dum_tss", "crickets", "laser",
    "applause", "boo", "whistle", "boing", "squeak", "pop",
    "record_scratch", "whoosh", "splash", "coin", "power_up",
    "error_buzz", "robot_beep", "game_over", "doorbell", "knock",
    "camera", "thunder", "ghost", "snore",
)
TEMPOS = (("_slow", .75), ("", 1.), ("_fast", 1.4))
ROOT = Path(__file__).resolve().parents[1] / "assets" / "sounds"
PHONE_BAND = butter(2, [250, 6000], btype="bandpass", fs=44100, output="sos")
PITCH_WINDOWS = {
    "air_horn": (270, 450, 1.00, 1.28),
    "fart": (100, 900, .78, 1.00),
    "sad_trombone": (105, 220, 1.57, 1.95),
    "crickets": (1550, 2450, 1.84, 2.02),
    "laser": (220, 1200, .84, .99),
}


def read(path):
    with wave.open(str(path)) as wav:
        assert (wav.getnchannels(), wav.getsampwidth(), wav.getframerate()) == (1, 2, 44100), path
        data = np.frombuffer(wav.readframes(wav.getnframes()), dtype="<i2") / 32768.
    assert data.size > 20_000, path
    assert .45 < np.max(np.abs(data)) < .85, path
    assert np.sqrt(np.mean(data * data)) > .06, path
    assert np.max(np.abs(data[:12])) < .02, path
    assert np.max(np.abs(data[-12:])) < .02, path
    return data


def main_pitch(data, tempo, limits):
    low, high, begin, end = limits
    clip = data[round(begin * 44100 / tempo):round(end * 44100 / tempo)]
    spectrum = np.abs(np.fft.rfft(clip * np.hanning(len(clip))))
    bins = np.fft.rfftfreq(len(clip), 1 / 44100)
    region = np.where((bins >= low) & (bins <= high))[0]
    return bins[region[np.argmax(spectrum[region])]]


def main():
    for name in SOUNDS:
        lengths = []
        pitches = []
        for suffix, tempo in TEMPOS:
            data = read(ROOT / f"{name}{suffix}.wav")
            lengths.append(len(data))
            if name in PITCH_WINDOWS:
                pitches.append(main_pitch(data, tempo, PITCH_WINDOWS[name]))
            if not suffix:
                phone = sosfilt(PHONE_BAND, data)
                phone_rms = np.sqrt(np.mean(phone * phone))
                windows = [phone[i:i + 4410] for i in range(0, len(phone) - 4410, 4410)]
                loudest_tenth = max(np.sqrt(np.mean(w * w)) for w in windows)
                assert phone_rms > (.15 if name == "fart" else .065), name
                assert loudest_tenth > .105, name
                print(f"{name:16} {len(data)/44100:.2f}s, phone-band RMS {phone_rms:.3f}")
        assert lengths[0] > lengths[1] > lengths[2], name
        assert abs(lengths[0] / lengths[1] - 1/.75) < .002, name
        assert abs(lengths[2] / lengths[1] - 1/1.4) < .002, name
        if pitches:
            assert max(pitches) - min(pitches) < 25, (name, pitches)
    assert {p.name for p in ROOT.glob("*.wav")} == {
        f"{name}{suffix}.wav" for name in SOUNDS for suffix, _ in TEMPOS
    }
    print("All 78 recordings for 26 sounds passed.")


if __name__ == "__main__":
    main()
