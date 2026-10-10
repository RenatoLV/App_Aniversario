"""Original loop for Marus vs Zombies. Standard library only; no sampled audio."""
from pathlib import Path
import math
import struct
import wave

rate = 22050
beat = .375
notes = [64, 67, 69, 67, 64, 62, 60, 62, 64, 67, 72, 69, 67, 64, 62, 60,
         65, 69, 72, 69, 65, 64, 62, 64, 67, 71, 74, 71, 67, 65, 64, 62]
chords = [(48, 52, 55), (45, 48, 52), (41, 45, 48), (43, 47, 50)]
length = len(notes) * beat * 2
target = Path(__file__).resolve().parents[1] / 'assets/audio/music/marus/garden-patrol.wav'
target.parent.mkdir(parents=True, exist_ok=True)
data = bytearray()
for i in range(round(length * rate)):
    t = i / rate
    n = int(t / beat)
    u = t % beat
    f = 440 * 2 ** ((notes[n % len(notes)] - 69) / 12)
    melody = .18 * math.exp(-u * 10) * (math.sin(math.tau * f * u) + .25 * math.sin(math.tau * f * 2 * u))
    chord = chords[(n // 8) % 4]
    bass_f = 440 * 2 ** ((chord[0] - 81) / 12)
    bass = .11 * math.exp(-u * 5) * math.sin(math.tau * bass_f * u)
    arp_f = 440 * 2 ** ((chord[n % 3] - 57) / 12)
    arp = .06 * math.exp(-u * 12) * math.sin(math.tau * arp_f * u)
    tick = .025 * math.exp(-u * 80) * math.sin(math.tau * 1800 * u)
    fade = min(1, t / .015, (length - t) / .03)
    data.extend(struct.pack('<h', int((melody + bass + arp + tick) * fade * 32767)))
with wave.open(str(target), 'wb') as out:
    out.setparams((1, 2, rate, 0, 'NONE', 'not compressed'))
    out.writeframes(data)
print(f'Created original {length:g}s garden loop: {target.name}')
