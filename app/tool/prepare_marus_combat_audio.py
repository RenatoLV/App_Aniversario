"""Local CC0 source processing and equivalent-event comparison (no downloads).

Python standard library + existing ffmpeg CLI; neither is a game dependency.
Use --prepare to rebuild assets, --comparison to render the Flutter-test ledger.
"""
import argparse
import array
import hashlib
import json
import shutil
import subprocess
import sys
import wave
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCES = ROOT / "audio_sources/marus"
ASSETS = ROOT / "assets/audio"
PREVIEWS = ROOT / "build/previews"
CHOICES = [
    ("launcher", "digital/pepSound3.ogg", .72),
    ("harvest", "digital/highUp.ogg", .72),
    ("bite", "zombies/zombie-24.wav", .62),
    ("armor", "digital/powerUp5.ogg", .68),
    ("defeat", "zombies/zombie-8.wav", .65),
]


def decode(path, ffmpeg):
    result = subprocess.run([ffmpeg, "-v", "error", "-i", str(path), "-f",
                             "f32le", "-ac", "1", "-ar", "22050", "pipe:1"],
                            capture_output=True, check=True)
    samples = array.array("f")
    samples.frombytes(result.stdout)
    if sys.byteorder != "little":
        samples.byteswap()
    return samples


def write(path, samples):
    pcm = array.array("h", (round(max(-1, min(1, v)) * 32767) for v in samples))
    if sys.byteorder != "little":
        pcm.byteswap()
    with wave.open(str(path), "wb") as output:
        output.setparams((1, 2, 22050, 0, "NONE", "not compressed"))
        output.writeframes(pcm.tobytes())


def prepare(ffmpeg):
    manifest = []
    for event, source, peak in CHOICES:
        samples = decode(SOURCES / source, ffmpeg)
        threshold = max(.004, max(map(abs, samples)) * .035)
        active = [i for i, v in enumerate(samples) if abs(v) > threshold]
        start, end = max(0, active[0] - 110), min(len(samples), active[-1] + 221)
        samples = samples[start:end]
        gain = peak / max(map(abs, samples))
        samples = [v * gain for v in samples]
        fade = min(110, len(samples) // 4)
        for i in range(fade):
            samples[i] *= i / (fade - 1)
            samples[-fade + i] *= 1 - i / (fade - 1)
        asset = f"marus_{event}.wav"
        path = ASSETS / asset
        write(path, samples)
        variants = []
        for tag, factor in [("low", .97), ("high", 1.03)]:
            variant = ASSETS / f"marus_{event}_{tag}.wav"
            subprocess.run([ffmpeg, "-v", "error", "-y", "-i", str(path),
                            "-af", f"asetrate={22050 * factor},aresample=22050",
                            "-ac", "1", "-c:a", "pcm_s16le", str(variant)], check=True)
            variants.append({"asset": variant.name, "pitchFactor": factor,
                             "sha256": hashlib.sha256(variant.read_bytes()).hexdigest()})
        manifest.append({"event": event, "source": source, "asset": asset,
                         "durationMs": round(len(samples) / 22.05), "peak": peak,
                         "trimStartMs": round(start / 22.05), "bytes": path.stat().st_size,
                         "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
                         "license": "CC0-1.0", "variants": variants,
                         "review": "Technical selection authorized by user. No listening performed."})
    (SOURCES / "patio_selection_v35.json").write_text(json.dumps(manifest, indent=2), encoding="utf-8")


def comparison(ffmpeg):
    ledger = json.loads((PREVIEWS / "mz-combat-audio-ledger.json").read_text())
    frames = round(ledger["durationMs"] * 22.05)
    music = decode(ASSETS / "music/marus/garden-patrol.wav", ffmpeg)
    music = list(music[:frames]) + [0.] * max(0, frames - len(music))
    cache, mixes = {}, {}
    for stage in ["before", "after"]:
        mix = [v * .3 for v in music]
        cues = ledger[stage]
        for index, cue in enumerate(cues):
            file = cue["asset"]
            if file not in cache:
                cache[file] = decode(ASSETS / file, ffmpeg)
            start = round(cue["ms"] * 22.05)
            end = min(frames, start + len(cache[file]))
            # A reused/preempted voice cuts its previous tail, just like the pool.
            next_voice = next((c for c in cues[index + 1:] if c["slot"] == cue["slot"]), None)
            if next_voice:
                end = min(end, round(next_voice["ms"] * 22.05))
            for i in range(max(0, end - start)):
                mix[start + i] += cache[file][i] * cue["gain"]
        mixes[stage] = mix
    peak = max(max(map(abs, mix)) for mix in mixes.values())
    gain = min(1, .95 / max(peak, .001))
    for stage, mix in mixes.items():
        write(PREVIEWS / f"mz-combat-audio-{stage}.wav", [v * gain for v in mix])
    print(f"Comparison: 20 s, identical music, common master {gain:.3f}, "
          f"{len(ledger['before'])}/{len(ledger['after'])} accepted effects.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--ffmpeg", default=shutil.which("ffmpeg"))
    parser.add_argument("--prepare", action="store_true")
    parser.add_argument("--comparison", action="store_true")
    options = parser.parse_args()
    if not options.ffmpeg:
        parser.error("An existing ffmpeg executable is required; pass --ffmpeg.")
    if options.prepare:
        prepare(options.ffmpeg)
    if options.comparison:
        comparison(options.ffmpeg)
