"""Generate six original, offline, mono PCM sound effects. Public use granted with this project."""
from pathlib import Path
import wave
import numpy as np
from scipy.signal import butter, sosfilt

RATE = 44100
OUT = Path(__file__).resolve().parents[1] / 'assets' / 'sounds'
OUT.mkdir(parents=True, exist_ok=True)
rng = np.random.default_rng(20260923)

def t_of(seconds):
    return np.arange(round(RATE * seconds), dtype=np.float64) / RATE

def env(t, attack=0.015, release=0.12):
    return np.minimum(1, t / attack) * np.minimum(1, (t[-1] - t) / release).clip(0, 1)

def write(name, sound):
    sound = np.asarray(sound)
    sound = np.tanh(sound * 1.35)
    sound *= min(.94 / max(np.max(np.abs(sound)), .001), 1)
    with wave.open(str(OUT / (name + '.wav')), 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes((sound * 32767).astype('<i2').tobytes())

def brass(frequency, duration, fall=0):
    t = t_of(duration)
    f = frequency * (1 - fall * t / duration) * (1 + .006 * np.sin(2*np.pi*5.4*t))
    phase = 2*np.pi*np.cumsum(f)/RATE
    partials = sum(np.sin(k*phase + .08*k)* (1/k**.85) for k in range(1, 10))
    return partials * env(t, .032, .14) * (.85 + .15*np.sin(2*np.pi*16*t))

# Air horn: twin detuned reeds, pitch kick, and turbulent breath.
t = t_of(1.65)
phase_a = 2*np.pi*np.cumsum(365 + 12*np.exp(-t*12))/RATE
phase_b = 2*np.pi*np.cumsum(371 + 9*np.exp(-t*11))/RATE
horn = sum((np.sin(k*phase_a)+np.sin(k*phase_b))/(k**.8) for k in range(1,8))
noise = sosfilt(butter(2, [800, 4300], btype='band', fs=RATE, output='sos'), rng.normal(size=t.size))
write('air_horn', env(t, .035, .25)*(.36*horn + .11*noise))

# Fart: uneven low sputter with downward pitch and airy crackle.
t = t_of(1.18)
f = 145 - 80*(t/t[-1]) + 14*np.sin(2*np.pi*12*t)*np.exp(-t)
phase = 2*np.pi*np.cumsum(f)/RATE
sputter = np.clip(np.sin(phase) + .42*np.sin(2*phase) + .24*rng.normal(size=t.size), -1, 1)
gating = .58+.42*np.sign(np.sin(2*np.pi*(19-11*t/t[-1])*t))
write('fart', sputter*gating*env(t,.012,.21)*.8)

# Sad trombone: four clearly pitched, descending wah notes.
notes = [brass(f,d,fall=.075) for f,d in [(294,.42),(247,.45),(196,.47),(147,.83)]]
sad = np.concatenate([np.concatenate([n,np.zeros(round(RATE*.075))]) for n in notes])
write('sad_trombone', sad*.47)

# Ba dum tss: two synthesized toms and a wide cymbal hiss.
length = 1.25
t = t_of(length)
def drum(at, f, decay, amplitude):
    tau = np.maximum(t-at,0)
    phase = 2*np.pi*(f*tau-110*tau*tau)
    return (t>=at)*amplitude*np.sin(phase)*np.exp(-tau/decay)
roll = drum(.02, 135, .13, .85)+drum(.30, 110, .17, 1.0)
noise = rng.normal(size=t.size)
cymbal = sosfilt(butter(3, 2400, btype='highpass', fs=RATE, output='sos'), noise)
tau=np.maximum(t-.57,0)
roll += (t>=.57)*cymbal*.34*np.exp(-tau/.25)
write('ba_dum_tss', roll)

# Crickets: three alternating two-tone insect pulses.
t = t_of(2.05)
chirps = np.zeros_like(t)
for offset in [0,.7,1.37]:
    for i in range(6):
        start=offset+i*.075
        loc=t-start
        mask=(loc>=0)&(loc<.055)
        window=np.sin(np.pi*np.clip(loc/.055,0,1))**2
        chirps += mask*window*(np.sin(2*np.pi*(3650*loc+550*loc**2)) +.38*np.sin(2*np.pi*4200*loc))
write('crickets', chirps*.57)

# Pew pew: two quick descending synth laser sweeps with a tiny echo.
t=t_of(.97)
pew=np.zeros_like(t)
for start in [.045,.38]:
    loc=t-start
    mask=(loc>=0)&(loc<.27)
    tau=np.maximum(loc,0)
    p=2*np.pi*(1450*.07*(1-np.exp(-tau/.07)) + 190*tau)
    pew += mask*np.sin(p)*np.exp(-tau/.073)
    pew += .28*mask*np.sin(p*1.5)*np.exp(-tau/.09)
write('laser', pew)
print('Created:', ', '.join(p.name for p in OUT.glob('*.wav')))
