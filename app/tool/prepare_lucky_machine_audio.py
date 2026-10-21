"""Rebuild the casino's CC0 foley candidates; no Flutter dependencies.
Requires an ffmpeg executable and Python/numpy. Does not certify timbre by ear.
"""
import argparse
import hashlib
import json
import subprocess
import urllib.request
import wave
from pathlib import Path
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
SOURCES = ROOT / 'audio_sources/lucky_palace'
ASSETS = ROOT / 'assets/audio'
URLS = {
    'ratchet': ('https://freesound.org/people/ryansitz/sounds/505698/',
                'https://cdn.freesound.org/previews/505/505698_5800259-hq.mp3', 'ryansitz', 'Revolver Spin'),
    'coins': ('https://freesound.org/people/jack126guy/sounds/361346/',
              'https://cdn.freesound.org/previews/361/361346_5506271-hq.mp3', 'jack126guy', 'slot machine payout.wav'),
}

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--ffmpeg', required=True)
    options = parser.parse_args()
    SOURCES.mkdir(parents=True, exist_ok=True)
    rate = 44100
    audio, credits = {}, []
    for name, (page, download, author, title) in URLS.items():
        source = SOURCES / f'{name}.mp3'
        if not source.exists():
            source.write_bytes(urllib.request.urlopen(download, timeout=30).read())
        snapshot = ROOT / f'build/lucky-audio-sources/{505698 if name == "ratchet" else 361346}.html'
        snapshot.parent.mkdir(parents=True, exist_ok=True)
        if not snapshot.exists():
            snapshot.write_bytes(urllib.request.urlopen(page, timeout=30).read())
        if b'Creative Commons 0' not in snapshot.read_bytes():
            raise RuntimeError('Source license could not be confirmed')
        decoded = subprocess.run([options.ffmpeg, '-v', 'error', '-i', str(source),
            '-af', 'highpass=f=100,lowpass=f=9500,acompressor=threshold=0.025:ratio=4:attack=2:release=90', '-f', 'f32le', '-ac', '1', '-ar', str(rate), 'pipe:1'],
            capture_output=True, check=True).stdout
        audio[name] = np.frombuffer(decoded, dtype='<f4').copy()
        credits.append(dict(name=name, title=title, author=author, page=page, download=download,
            license='CC0-1.0', licenseUrl='https://creativecommons.org/publicdomain/zero/1.0/',
            file=source.name, sha256=hashlib.sha256(source.read_bytes()).hexdigest(),
            sourceFormat='Public HQ MP3 preview of the CC0 recording; not the original WAV'))
    def write(file, values, fade=.03):
        values = values.astype(np.float64).copy()
        values -= values.mean()
        rms = max(.0001, float(np.sqrt(np.mean(values**2))))
        values *= .13 / rms
        values = .78 * np.tanh(values / .78)  # Smooth transient ceiling, no hard clipping.
        n = min(round(rate * fade), len(values) // 2)
        values[:n] *= np.linspace(0, 1, n)
        values[-n:] *= np.linspace(1, 0, n)
        pcm = np.rint(np.clip(values, -.99, .99) * 32767).astype('<i2')
        with wave.open(str(ASSETS / file), 'wb') as out:
            out.setparams((1, 2, rate, 0, 'NONE', 'not compressed'))
            out.writeframes(pcm.tobytes())
        return dict(file=file, seconds=len(values)/rate, rate=rate, channels=1,
            peak=float(np.abs(values).max()), rms=float(np.sqrt(np.mean(values**2))),
            sha256=hashlib.sha256((ASSETS / file).read_bytes()).hexdigest())
    ratchet = audio['ratchet']
    # Preserve recorded mechanical texture rather than synthesizing 8-bit notes.
    # Use the continuous ratchet portion, excluding handling gaps at the tail.
    segment = ratchet[round(.12 * rate):round(1.34 * rate)].copy()
    fade = round(.045 * rate)
    segment[:fade] *= np.linspace(0, 1, fade)
    segment[-fade:] *= np.linspace(1, 0, fade)
    spin = np.zeros(round(2.94 * rate))
    for offset in range(0, len(spin), len(segment) - fade):
        end = min(len(spin), offset + len(segment))
        spin[offset:end] += segment[:end-offset]
    # A short transient from the same recording for each real reel landing.
    window = round(.14 * rate)
    attack = int(np.argmax(np.abs(ratchet[:rate])))
    start = max(0, attack - round(.012 * rate))
    stop = ratchet[start:start + window]
    payout = audio['coins'][:round(1.9 * rate)]
    files = [write('casino_spin.wav', spin), write('casino_stop.wav', stop, .008),
             write('casino_payout.wav', payout, .08)]
    manifest = dict(sources=credits, processing='mono 44.1kHz PCM16; 100Hz high-pass, 9.5kHz low-pass, 4:1 compression, RMS normalization, soft limiting and fades; continuous ratchet section crossfaded, extracted ratchet transient',
        files=files, audit='Technical checks only. Timbre/listening approval pending user audition.')
    (SOURCES / 'sources.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding='utf-8')
    (ASSETS / 'casino_sfx_sources.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding='utf-8')
    preview = ROOT / 'build/previews/lucky-machine-audio'
    preview.mkdir(parents=True, exist_ok=True)
    for file in ['paper.wav', 'casino_spin.wav', 'casino_stop.wav', 'casino_payout.wav']:
        (preview / file).write_bytes((ASSETS / file).read_bytes())
    mixed = np.zeros(round(5.6 * rate))
    def mix(v, seconds, gain):
        i = round(seconds * rate); end = min(len(mixed), i+len(v)); mixed[i:end] += v[:end-i]*gain
    def read(file):
        with wave.open(str(ASSETS / file), 'rb') as f: return np.frombuffer(f.readframes(f.getnframes()),dtype='<i2').astype(float)/32767
    mix(read('casino_spin.wav'), 0, .48)
    for i in range(5): mix(read('casino_stop.wav'), 2+i*.22, .288)
    mix(read('casino_payout.wav'), 3.35, .40)
    # Export an example of the sequence, independent of the player's wallet.
    pcm = np.rint(np.clip(mixed, -.99, .99)*32767).astype('<i2')
    with wave.open(str(preview / 'sequence.wav'), 'wb') as f:
        f.setparams((1,2,rate,0,'NONE','not compressed')); f.writeframes(pcm.tobytes())
    cards = ''.join(f'<section><h2>{label}</h2><audio controls preload="none" src="{file}"></audio></section>' for file,label in [
        ('paper.wav','Anterior: papel'), ('casino_spin.wav','Nuevo: mecanismo y rodillos'),
        ('casino_stop.wav','Parada de rodillo'), ('casino_payout.wav','Pago: monedas reales'), ('sequence.wav','Secuencia de ejemplo con premio')])
    (preview / 'index.html').write_text('<!doctype html><html lang="es"><meta charset="utf-8"><meta name="viewport" content="width=device-width"><title>Lucky 777 · SFX</title><style>body{background:#21152f;color:#ffe7b0;font:18px system-ui;max-width:750px;margin:30px auto;padding:16px}section{border:1px solid #a77a52;border-radius:16px;padding:16px;margin:12px 0}audio{width:100%}</style><h1>Lucky 777 · comparación de SFX</h1><p>Grabaciones CC0 procesadas. La calidad de timbre queda pendiente de tu escucha. Volumen inicial moderado.</p>'+cards+'<script>document.querySelectorAll("audio").forEach(a=>{a.volume=.7;a.onplay=()=>document.querySelectorAll("audio").forEach(b=>{if(a!==b)b.pause()})})</script></html>', encoding='utf-8')
    print(json.dumps(files, indent=2))

if __name__ == '__main__': main()
