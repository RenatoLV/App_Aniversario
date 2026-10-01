"""Reproducible, original foley/chimes for the small cat games (no dependencies)."""
from pathlib import Path
import math
import random
import struct
import wave

ROOT = Path(__file__).resolve().parents[1] / 'assets' / 'audio'
RATE = 22050
rng = random.Random(2910)


def render(name, duration, sample):
    values = [sample(i / RATE, i) for i in range(round(duration * RATE))]
    peak = max(abs(v) for v in values) or 1
    data = bytearray()
    for i, value in enumerate(values):
        fade = min(1, i / 180, (len(values) - i - 1) / 350)
        data.extend(struct.pack('<h', round(value / peak * .76 * fade * 32767)))
    with wave.open(str(ROOT / name), 'wb') as output:
        output.setparams((1, 2, RATE, 0, 'NONE', 'not compressed'))
        output.writeframes(data)


def bell(t, start, freq, decay=7):
    if t < start:
        return 0
    a = t - start
    return math.exp(-a * decay) * (math.sin(a * freq * math.tau) + .2 * math.sin(a * freq * 2.76 * math.tau))


render('place.wav', .16, lambda t, _: math.exp(-t * 34) * (math.sin(math.tau * 330 * t) + .32 * math.sin(math.tau * 810 * t)))
render('coin.wav', .32, lambda t, _: bell(t, 0, 880, 15) + .45 * bell(t, .065, 1320, 17))
render('jump.wav', .2, lambda t, _: math.sin(math.tau * (230 * t + 450 * t * t)) * math.sin(math.pi * t / .2) ** 2)
render('spring.wav', .65, lambda t, _: math.sin(math.tau * (145 * t + 430 * t * t) + 1.2 * math.sin(t * 50)) * math.exp(-t * 6))
render('clear.wav', .55, lambda t, _: sum(bell(t, i * .07, f, 11) for i, f in enumerate([523.25, 659.25, 783.99])))
render('reveal.wav', 1.05, lambda t, _: sum(.65 * bell(t, i * .085, f, 5) for i, f in enumerate([523.25, 783.99, 1046.5, 1318.5])))
noise = 0.0


def paper(t, _):
    global noise
    white = rng.uniform(-1, 1)
    noise = noise * .65 + white * .35
    rasp = white - noise
    tug = math.sin(math.pi * t / .58) ** 2
    grains = .18 + .82 * abs(math.sin(t * 65 + math.sin(t * 21))) ** 6
    return rasp * tug * grains


render('paper.wav', .58, paper)
render('rocket.wav', 1.5, lambda t, _: (rng.uniform(-1, 1) * .32 + math.sin(math.tau * (90 * t + 150 * t * t)) * .16) * math.sin(math.pi * t / 1.5) ** .7)
render('abduction.wav', 3.2, lambda t, _: math.sin(math.pi * t / 3.2) ** .65 * (.45 * math.sin(math.tau * (170 * t + 40 * t * t) + 1.1 * math.sin(t * 21)) + .16 * math.sin(math.tau * (340 * t + 80 * t * t))) + .12 * bell(t, 2.7, 659.25, 9))
print('Generated', len(list(ROOT.glob('*.wav'))), 'original effects')
