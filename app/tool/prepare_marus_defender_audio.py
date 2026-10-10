"""V3.6 foley/magic candidates after rejecting the digital bank. Audition required."""
import argparse
import hashlib
import json
import subprocess
from prepare_marus_combat_audio import ASSETS, SOURCES, PREVIEWS, decode, write

# Fixed clip budgets; measured source spectra guide selection, not filenames.
CHOICES = [
    ('sun', 'v36/shimmer.flac', 500, 'Bell/chime source, brief production accent'),
    ('sun_tuna', 'v36/shimmer.flac', 800, 'Layered chime source for actual tuna activation'),
    ('ice_shot', 'v36/ice01.flac', 350, 'Ice spell source, shortened release'),
    ('ice_hit', 'v36/ice02.flac', 300, 'Separate ice damage source for contact'),
    ('freeze', 'v36/ice03.flac', 600, 'Longer ice spell source for actual freeze only'),
    ('catapult', 'v36/bow.ogg', 480, 'Bow/slingshot release with wooden prefix'),
    ('croquette', 'v36/soft-impact.ogg', 220, 'Foley soft impact instead of digital tone'),
    ('laser_start', 'v36/laser-small.ogg', 300, 'Modern sci-fi weapon source; excludes retro clips'),
    ('laser_beam', 'v36/engine.ogg', 600, 'Engine texture for one shared continuous channel'),
    ('laser_end', 'v36/field.ogg', 300, 'Sci-fi field texture with shortened fade'),
]
REJECTED = ['threeTone1', 'threeTone2', 'phaseJump5', 'powerUp2',
            'powerUp11', 'pepSound1', 'lowRandom', 'phaserUp4', 'laser3', 'phaserDown2']

def clip(source, length, ffmpeg, peak=.6):
    samples = list(decode(SOURCES / source, ffmpeg))
    threshold = max(map(abs, samples)) * .035
    first = next(i for i, x in enumerate(samples) if abs(x) > threshold)
    samples = samples[max(0, first - 110):]
    n = round(length * 22.05)
    samples = samples[:n] + [0.] * max(0, n - len(samples))
    gain = peak / max(max(map(abs, samples)), .001)
    return [v * gain for v in samples]

def main(ffmpeg):
    PREVIEWS.mkdir(parents=True, exist_ok=True)
    metadata, articles = [], []
    provenance = {x['file']: x for x in json.loads((SOURCES / 'v36/manifest.json').read_text(encoding='utf-8'))}
    rejected_dir = PREVIEWS / 'mz-rejected-digital'
    rejected_dir.mkdir(exist_ok=True)
    for choice_index, (event, source, duration, reason) in enumerate(CHOICES):
        rejected_path = rejected_dir / f'marus_{event}.wav'
        if not rejected_path.exists():
            rejected = clip(f'digital/{REJECTED[choice_index]}.ogg', duration, ffmpeg)
            if event == 'catapult':
                rejected = (clip('digital/phaserDown2.ogg', 90, ffmpeg, .35) + rejected)[:round(duration*22.05)]
            fade = round(22.05 * (40 if event == 'laser_beam' else 15))
            for i in range(fade):
                rejected[i] *= i / fade
                rejected[-1-i] *= i / fade
            write(rejected_path, rejected)
        samples = clip(source, duration, ffmpeg)
        sources = [source]
        if event == 'catapult':
            # Tension + release are one finite cue starting at the REAL launch.
            prefix = clip('v36/wood-light.ogg', 90, ffmpeg, .35)
            samples = (prefix + samples)[:round(duration * 22.05)]
            sources.append('v36/wood-light.ogg')
        if event == 'sun_tuna':
            original = samples[:]
            for offset in [3308, 6615]:
                for i in range(len(samples)-offset):
                    samples[offset+i] += original[i] * .25
            peak = max(map(abs, samples))
            samples = [v * .6 / peak for v in samples]
        fade = round(22.05 * (40 if event == 'laser_beam' else 15))
        for i in range(fade):
            samples[i] *= i / fade
            samples[-1-i] *= i / fade
        asset = f'marus_{event}.wav'
        write(ASSETS / asset, samples)
        variants = [asset]
        if event != 'laser_beam':
            for tag, factor in [('low', .97), ('high', 1.03)]:
                variant = f'marus_{event}_{tag}.wav'
                subprocess.run([ffmpeg, '-v', 'error', '-y', '-i', str(ASSETS / asset),
                    '-af', f'asetrate={22050 * factor},aresample=22050', str(ASSETS / variant)], check=True)
                variants.append(variant)
        metadata.append(dict(event=event, sources=sources, asset=asset, durationMs=duration,
            sha256=hashlib.sha256((ASSETS / asset).read_bytes()).hexdigest(),
            reason=reason, sourcesMetadata=[provenance[s] for s in sources], variants=variants,
            review='Provisional technical candidates; no listening performed.'))
        controls = ''.join(f'<p>{v}</p><audio controls preload="none" src="../../assets/audio/{v}"></audio>' for v in variants)
        originals = ''.join(f'<p>Original: {s}</p><audio controls preload="none" src="../../audio_sources/marus/{s}"></audio>' for s in sources)
        rejected = f'<p>Candidato digital rechazado:</p><audio controls preload="none" src="mz-rejected-digital/{asset}"></audio>'
        articles.append(f'<article><h2>{event}</h2>{controls}{originals}{rejected}</article>')
    (SOURCES / 'defender_selection_v36.json').write_text(json.dumps(metadata, indent=2), encoding='utf-8')
    html = '''<!doctype html><meta charset="utf-8"><title>Marus V3.6 · Audición</title>
    <style>body{font:18px system-ui;background:#18382b;color:#ffedba;padding:24px;max-width:950px;margin:auto}article{padding:20px;margin:16px 0;background:#285840;border:3px solid #b58949;border-radius:18px}audio{width:100%}a{color:#ffce75}</style>
    <h1>Defensores · candidatos V3.6</h1><p>Sin escucha verificada: valida carácter y volumen. Versiones base y ±3 % de tono; originales al final de cada sección. El haz comparte un solo bucle entre todos los Láser.</p>
    <p><a href="mz-combat-audio-v35.html">Comparación V3.5 conservada</a> · <a href="../../audio_sources/marus/audition.html">Banco completo</a></p>'''
    (PREVIEWS / 'mz-defender-audio-v36.html').write_text(html + ''.join(articles), encoding='utf-8')
    ledger = PREVIEWS / 'mz-defender-audio-ledger.json'
    if ledger.exists():
        compare(json.loads(ledger.read_text(encoding='utf-8')), ffmpeg)
    print(f'Prepared {len(metadata)} cues; V3.5 assets untouched.')

def compare(records, ffmpeg):
    cache, sections = {}, []
    for name, events in records.items():
        stages = {}
        for stage in ['digital', 'foley']:
            mix = [0.] * (22050 * 5)
            for index, event in enumerate(events):
                start = round(event['ms'] * 22.05)
                if 'beam' in event:
                    if not event['beam']: continue
                    asset, gain = 'marus_laser_beam.wav', .8 * .12
                    stop = next((e['ms'] for e in events[index+1:] if e.get('beam') is False), 5000)
                    length = min(len(mix)-start, round((stop-event['ms']) * 22.05))
                else:
                    asset, gain = event['asset'], event['gain']
                    stop = next((e['ms'] for e in events[index+1:] if e.get('slot') == event['slot'] or
                        (event['slot'] == 3 and e.get('beam') is True)), 5000)
                    length = min(len(mix)-start, round((stop-event['ms']) * 22.05))
                path = ASSETS / asset if stage == 'foley' else PREVIEWS / 'mz-rejected-digital' / asset.replace('_low.wav','.wav').replace('_high.wav','.wav')
                if path not in cache: cache[path] = decode(path, ffmpeg)
                samples = cache[path]
                if 'beam' not in event: length = min(length, len(samples))
                for i in range(max(0, length)): mix[start+i] += samples[i % len(samples)] * gain
            stages[stage] = mix
        gain = min(1, .95 / max(.001, max(max(map(abs, m)) for m in stages.values())))
        for stage, samples in stages.items():
            write(PREVIEWS / f'mz-v36-{name}-{stage}.wav', [v*gain for v in samples])
        sections.append(f'<article><h2>{name}</h2><p>Digital rechazado</p><audio controls preload="none" src="mz-v36-{name}-digital.wav"></audio><p>Nuevo candidato</p><audio controls preload="none" src="mz-v36-{name}-foley.wav"></audio></article>')
    path = PREVIEWS / 'mz-defender-audio-v36.html'
    with path.open('a',encoding='utf-8') as output:
        output.write('<h1>Combates normales y atún</h1><p>5 segundos por clip, eventos reales registrados en pruebas. Misma ganancia, sin música para evaluar los efectos. Mezcla offline; no grabación del dispositivo.</p>' + ''.join(sections))

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--ffmpeg', required=True)
    main(parser.parse_args().ffmpeg)
