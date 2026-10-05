"""Lossless asset optimization, accepting only verified, smaller outputs.

Requires Pillow with WebP support. Run from app/ with:
    python tool/optimize_assets.py
The report records exact decoded animation timelines before and after.
"""
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
import hashlib
import json
import struct
import zlib

from PIL import Image, ImageSequence

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / 'assets'
BACKUP = ROOT / 'build' / 'asset-originals'
BACKUP.mkdir(parents=True, exist_ok=True)


def timeline(file):
    digest = hashlib.sha256()
    with Image.open(file) as image:
        loop = image.info.get('loop')
        frames = image.n_frames
        dimensions = image.size
        for frame in ImageSequence.Iterator(image):
            rgba = frame.convert('RGBA')
            # Fully transparent RGB is invisible and codecs may normalize it.
            rgba.paste((0, 0, 0, 0), mask=rgba.getchannel('A').point(lambda a: 255 if a == 0 else 0))
            digest.update(rgba.tobytes())
            digest.update(struct.pack('<I', frame.info.get('duration', 0)))
        return dimensions, frames, loop, digest.hexdigest()


def animation(file):
    output = BACKUP / file.with_suffix('.webp').name
    with Image.open(file) as source:
        loop = source.info.get('loop')
        frames, durations = [], []
        for frame in ImageSequence.Iterator(source):
            frames.append(frame.convert('RGBA'))
            durations.append(frame.info.get('duration', 0))
        # Zero-delay GIFs have decoder-specific timing; preserve their originals.
        if not frames or min(durations) < 10 or loop is None:
            return None
        frames[0].save(output, save_all=True, append_images=frames[1:],
                       duration=durations, loop=loop, lossless=True,
                       quality=100, method=4, exact=True)
        for frame in frames:
            frame.close()
    if output.stat().st_size >= file.stat().st_size:
        return None
    before = timeline(file)
    after = timeline(output)
    if before != after:
        print('Kept original; animation differs:', file.name, flush=True)
        return None
    original = file.read_bytes()
    replacement = output.read_bytes()
    (BACKUP / file.name).write_bytes(original)
    target = file.with_suffix('.webp')
    target.write_bytes(replacement)
    file.unlink()
    print(f'{file.name}: {len(original)} -> {len(replacement)} bytes, identical timeline', flush=True)
    return dict(source=file.relative_to(ROOT).as_posix(), asset=target.relative_to(ROOT).as_posix(),
                beforeBytes=len(original), afterBytes=len(replacement),
                originalSha256=hashlib.sha256(original).hexdigest(),
                assetSha256=hashlib.sha256(replacement).hexdigest(),
                width=before[0][0], height=before[0][1], frames=before[1],
                loop=before[2], decodedTimelineSha256=before[3])


def png(file):
    original = file.read_bytes()
    position = 8
    chunks = []
    while position < len(original):
        length = struct.unpack('>I', original[position:position + 4])[0]
        kind = original[position + 4:position + 8]
        chunks.append((kind, original[position:position + length + 12]))
        position += length + 12
    if any(kind == b'acTL' for kind, _ in chunks):
        return None
    compressed = b''.join(chunk[8:-4] for kind, chunk in chunks if kind == b'IDAT')
    raw = zlib.decompress(compressed)
    encoded = zlib.compress(raw, 9)
    if len(encoded) >= len(compressed):
        return None
    assert zlib.decompress(encoded) == raw
    idat = b'IDAT' + encoded
    chunk = struct.pack('>I', len(encoded)) + idat + struct.pack('>I', zlib.crc32(idat))
    result = bytearray(original[:8])
    written = False
    for kind, previous in chunks:
        if kind != b'IDAT':
            result.extend(previous)
        elif not written:
            result.extend(chunk)
            written = True
    if len(result) >= len(original):
        return None
    (BACKUP / file.name).write_bytes(original)
    file.write_bytes(result)
    return dict(source=file.relative_to(ROOT).as_posix(), asset=file.relative_to(ROOT).as_posix(),
                beforeBytes=len(original), afterBytes=len(result),
                originalSha256=hashlib.sha256(original).hexdigest(),
                assetSha256=hashlib.sha256(result).hexdigest(),
                inflatedPixelsSha256=hashlib.sha256(raw).hexdigest())


if __name__ == '__main__':
    report_path = ROOT / 'tool' / 'asset_optimization_report.json'
    previous = json.loads(report_path.read_text(encoding='utf-8')) if report_path.exists() else []
    verified = {entry['asset']: entry for entry in previous
                if (ROOT / entry['asset']).is_file()
                and hashlib.sha256((ROOT / entry['asset']).read_bytes()).hexdigest() == entry['assetSha256']}
    files = sorted((ASSETS / 'celestials').glob('*.gif'))
    # Two encoders bound memory while preserving all original-resolution frames.
    with ThreadPoolExecutor(max_workers=2) as pool:
        report = [entry for entry in pool.map(animation, files) if entry]
    report.extend(entry for file in ASSETS.rglob('*.png') if (entry := png(file)))
    for entry in report:
        if entry['source'] != entry['asset']:
            catalog = ROOT / 'lib' / 'celestial_cards.dart'
            catalog.write_text(catalog.read_text(encoding='utf-8').replace(entry['source'], entry['asset']), encoding='utf-8')
    for entry in report:
        original = verified.get(entry['asset'])
        if original:
            entry.update(beforeBytes=original['beforeBytes'], originalSha256=original['originalSha256'])
        verified[entry['asset']] = entry
    total_report = sorted(verified.values(), key=lambda entry: entry['asset'])
    catalog_path = ROOT / 'tool' / 'celestial_catalog.json'
    catalog = json.loads(catalog_path.read_text(encoding='utf-8'))
    for card in catalog:
        replacement = next((entry for entry in total_report if entry['source'] == card['asset']), None)
        if replacement:
            card['asset'] = replacement['asset']
    catalog_path.write_text(json.dumps(catalog, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    report_path.write_text(json.dumps(total_report, indent=2) + '\n', encoding='utf-8')
    print('Saved bytes:', sum(entry['beforeBytes'] - entry['afterBytes'] for entry in total_report), flush=True)
