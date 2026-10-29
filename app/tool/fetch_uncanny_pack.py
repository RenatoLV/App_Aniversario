"""Fetch the exact original-game export pinned by the repository manifest."""
import hashlib
import json
from pathlib import Path
import urllib.request

app = Path(__file__).resolve().parents[1]
spec = json.loads((app / 'tool/uncanny_pack.json').read_text(encoding='utf-8'))
target = app / 'android/app/src/main/assets/uncanny' / spec['file']

def verified(path):
    if not path.is_file() or path.stat().st_size != spec['bytes']:
        return False
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest() == spec['sha256']

if not verified(target):
    target.parent.mkdir(parents=True, exist_ok=True)
    pending = target.with_suffix('.download')
    urllib.request.urlretrieve(spec['url'], pending)
    if not verified(pending):
        raise RuntimeError('Original Godot package checksum mismatch; refusing to build')
    pending.replace(target)
print(f'Original Uncanny Cat Golf package verified: {spec["sha256"]}')
