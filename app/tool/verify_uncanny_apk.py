"""Check the actual release APK, including classes reached only through Godot JNI.

Usage: python tool/verify_uncanny_apk.py build/app/outputs/flutter-apk/app-release.apk
This deliberately runs after R8; launcher widget tests cannot catch JNI stripping.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
import struct
import zipfile


def dex_classes(data):
    def uint(offset):
        return struct.unpack_from('<I', data, offset)[0]

    strings_offset = uint(60)
    types_offset = uint(68)
    count, offset = uint(96), uint(100)
    classes = set()
    for index in range(count):
        type_index = uint(offset + index * 32)
        string_index = uint(types_offset + type_index * 4)
        start = uint(strings_offset + string_index * 4)
        while data[start] & 128:
            start += 1
        start += 1  # skip the final UTF-16-length byte
        classes.add(data[start:data.index(b'\0', start)].decode('utf-8'))
    return classes


def dex_methods(data):
    def uint(offset):
        return struct.unpack_from('<I', data, offset)[0]

    def string(index):
        start = uint(uint(60) + index * 4)
        while data[start] & 128:
            start += 1
        start += 1
        return data[start:data.index(b'\0', start)].decode('utf-8', errors='replace')

    def uleb(offset):
        value, shift = 0, 0
        while True:
            byte = data[offset]
            offset += 1
            value |= (byte & 127) << shift
            if byte < 128:
                return value, offset
            shift += 7

    methods = set()
    for index in range(uint(96)):
        offset = uint(100) + index * 32
        owner = string(uint(uint(68) + uint(offset) * 4))
        position = uint(offset + 24)
        if not position:
            continue
        counts = []
        for _ in range(4):
            count, position = uleb(position)
            counts.append(count)
        for _ in range(counts[0] + counts[1]):
            _, position = uleb(position)
            _, position = uleb(position)
        for count in counts[2:]:
            method = 0
            for _ in range(count):
                delta, position = uleb(position)
                method += delta
                _, position = uleb(position)
                _, position = uleb(position)
                methods.add((owner, string(uint(uint(92) + method * 8 + 4))))
    return methods


def verify(path):
    with zipfile.ZipFile(path) as apk:
        classes = set()
        methods = set()
        for name in apk.namelist():
            if re.fullmatch(r'classes\d*\.dex', name):
                classes.update(dex_classes(apk.read(name)))
                methods.update(dex_methods(apk.read(name)))
        engine = apk.read('lib/arm64-v8a/libgodot_android.so')
        required = set(re.findall(rb'org/godotengine/[A-Za-z0-9_/$]+', engine))
        # Legacy optional lookup strings remain in the native binary, but these
        # classes are absent even in the unmodified Godot 4.4.1 Maven AAR.
        required -= {b'org/godotengine/godot/input/InputManagerCompat',
                     b'org/godotengine/godot/input/InputManagerV16'}
        missing = sorted(name.decode() for name in required
                         if 'L' + name.decode() + ';' not in classes)
        callbacks = ('restart', 'forceQuit', 'setKeepScreenOn', 'getRenderView',
                     'onGodotSetupCompleted', 'onGodotMainLoopStarted',
                     'onGodotTerminating', 'alert')
        missing_callbacks = [name for name in callbacks
                             if ('Lorg/godotengine/godot/Godot;', name) not in methods]
        if missing or missing_callbacks:
            raise ValueError('Godot JNI classes missing or renamed by R8: ' + ', '.join(missing)
                             + '; missing callbacks: ' + ', '.join(missing_callbacks))
        abis = {name.split('/')[1] for name in apk.namelist()
                if name.startswith('lib/') and name.endswith('.so')}
        if abis != {'arm64-v8a'}:
            raise ValueError(f'Expected ARM64-only release, found {sorted(abis)}')
        manifest = json.loads((Path(__file__).parent / 'uncanny_pack.json').read_text())
        pack = apk.getinfo('assets/uncanny/uncanny-mobile.pck')
        digest = hashlib.sha256()
        with apk.open(pack) as stream:
            while chunk := stream.read(1024 * 1024):
                digest.update(chunk)
        if pack.file_size != manifest['bytes'] or digest.hexdigest() != manifest['sha256']:
            raise ValueError('Original game pack does not match the verified manifest')
        if pack.compress_type != zipfile.ZIP_STORED:
            raise ValueError('Godot pack must remain uncompressed for random access')
        for name in ('mobile_landscape.gd', 'mobile_landscape.tscn'):
            source = Path(__file__).parents[1] / 'android/app/src/main/assets/uncanny' / name
            if apk.read('assets/uncanny/' + name) != source.read_bytes():
                raise ValueError('Missing or stale landscape entry point: ' + name)
        print(json.dumps({'apkBytes': Path(path).stat().st_size,
                          'packBytes': pack.file_size, 'abis': sorted(abis),
                          'nativeGodotClassesVerified': len(required),
                          'startupCallbacksVerified': len(callbacks)}, indent=2))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('apk', type=Path)
    verify(parser.parse_args().apk)
