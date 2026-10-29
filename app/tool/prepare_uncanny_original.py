"""Export the supplied original Godot project without recreating its artwork/maps.
Usage: python tool/prepare_uncanny_original.py --source PATH --godot GODOT_EXE
The source directory is read-only; all import/export work uses .tools/uncanny-original.
"""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import struct

ROOT = Path(__file__).resolve().parents[2]
APP = ROOT / 'app'

def sha(path):
    return hashlib.file_digest(path.open('rb'), 'sha256').hexdigest()

def run_godot(arguments):
    # Godot can return exit code zero despite GDScript parse errors.
    result = subprocess.run(arguments, stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT, text=True, encoding='utf-8', errors='replace')
    print(result.stdout, flush=True)
    result.check_returncode()
    if 'SCRIPT ERROR:' in result.stdout or 'Failed to load script' in result.stdout:
        raise RuntimeError('Godot reported a script error; do not publish this pack')

def prepare(source, godot):
    stage = ROOT / '.tools/uncanny-original'
    if source.resolve() == stage.resolve():
        raise ValueError('Source must be separate from the build directory')
    version = subprocess.check_output([godot, '--headless', '--version'], text=True).strip()
    if not version.startswith('4.4.1.'):
        raise ValueError('The supplied original uses Godot 4.4.1; use the matching editor')
    shutil.copytree(source, stage, dirs_exist_ok=True,
        ignore=shutil.ignore_patterns('.godot', 'uncanny-cat-golf-source.zip'))
    project = stage / 'project.godot'
    config = project.read_text(encoding='utf-8')
    config = config.replace('config/custom_user_dir_name="Uncanny Cat Golf"',
                            'config/custom_user_dir_name="Anivermaru Uncanny Cat Golf"')
    config = config.replace('run/main_scene="uid://blipbbly572f5"',
                            'run/main_scene="res://uncanny/mobile_landscape.tscn"')
    config = config.replace('window/stretch/mode="canvas_items"',
        'window/stretch/mode="canvas_items"\nwindow/stretch/aspect="expand"\nwindow/handheld/orientation=4')
    config += '\n[input_devices]\npointing/emulate_mouse_from_touch=true\n'
    project.write_text(config, encoding='utf-8')
    for path in (APP / 'tool/uncanny_mobile').iterdir():
        if path.suffix in {'.gd', '.tscn'}:
            shutil.copy2(path, stage / path.name)
    (stage / 'uncanny').mkdir(exist_ok=True)
    for name in ('mobile_landscape.gd', 'mobile_landscape.tscn'):
        shutil.copy2(APP / 'android/app/src/main/assets/uncanny' / name,
                     stage / 'uncanny' / name)
    # Keep the original content, but avoid nested parallel resource loads on
    # mobile's smaller worker pool (shared scene dependencies can deadlock).
    world = stage / 'assetsNEW/scenes/utils/world.gd'
    data = world.read_text(encoding='utf-8')
    start = data.index('\tload_task = WorkerThreadPool.add_group_task(')
    end = data.index('\tfor file in level_files:', start)
    data = data[:start] + '\tfor i in level_files.size():\n\t\tlevels[i] = load(path.path_join(level_files[i]))\n' + data[end:]
    world.write_text(data, encoding='utf-8')
    master = stage / 'assetsNEW/scenes/master.gd'
    data = master.read_text(encoding='utf-8')
    start = data.index('func load_scenes() -> void:')
    end = data.index('## Switches from the current base scene', start)
    data = data[:start] + 'func load_scenes() -> void:\n\tfor i in game_scene_paths.size():\n\t\tvar path := game_scene_paths[i]\n\t\tif not path.is_empty() and packed_game_scenes[i] == null:\n\t\t\tpacked_game_scenes[i] = load(path)\n\n' + data[end:]
    master.write_text(data, encoding='utf-8')
    # Area2D menu buttons originally require a desktop hover before the click.
    # Hit-test the current pointer on the same physics tick as the first tap.
    buttons = stage / 'assetsNEW/scenes/menu_objects/buttons'
    for name in ('fake_button.gd', 'ps_mode_button.gd'):
        path = buttons / name
        data = path.read_text(encoding='utf-8').replace(
            'if mouse_on:', 'if _mobile_pointer_inside():')
        if name == 'fake_button.gd':
            data += '''
func _mobile_pointer_inside() -> bool:
\tvar query := PhysicsPointQueryParameters2D.new()
\tquery.position = get_global_mouse_position()
\tquery.collide_with_areas = true
\tquery.collide_with_bodies = false
\tquery.collision_mask = collision_layer
\tfor hit in get_world_2d().direct_space_state.intersect_point(query):
\t\tif hit.collider == self:
\t\t\treturn true
\treturn false
'''
        path.write_text(data, encoding='utf-8')
    # Godot serializes @tool exports before their scene node references exist.
    standup = stage / 'assetsNEW/scenes/game/minigames/bingball/objects/standup.gd'
    text = standup.read_text(encoding='utf-8').replace(
        'get(): return pressed_sound_player.stream',
        'get(): return pressed_sound_player.stream if is_instance_valid(pressed_sound_player) else null')
    standup.write_text(text, encoding='utf-8')
    (stage / 'export_presets.cfg').write_text('''[preset.0]
name="Anivermaru Android Pack"
platform="Android"
runnable=true
export_filter="all_resources"
include_filter="*.csv, *.json, *.zip"
exclude_filter="uncanny-cat-golf-source.zip"
export_path=""
script_export_mode=2
[preset.0.options]
architectures/arm64-v8a=true
architectures/armeabi-v7a=false
''', encoding='utf-8')
    pack = APP / 'android/app/src/main/assets/uncanny/uncanny-mobile.pck'
    pack.parent.mkdir(parents=True, exist_ok=True)
    run_godot([godot, '--headless', '--path', str(stage), '--editor', '--import'])
    run_godot([godot, '--headless', '--path', str(stage), '--export-pack',
        'Anivermaru Android Pack', str(pack)])
    # Verify the archive index, not just a successful exporter exit code.
    with pack.open('rb') as stream:
        magic, revision = struct.unpack('<II', stream.read(8))
        if magic != 0x43504447 or revision != 2:
            raise ValueError('Unexpected Godot pack format')
        stream.seek(96)
        entry_count = struct.unpack('<I', stream.read(4))[0]
        entries = set()
        for _ in range(entry_count):
            size = struct.unpack('<I', stream.read(4))[0]
            entries.add(stream.read(size).rstrip(b'\0').decode('utf-8'))
            stream.read(36)
    scripts = list(source.rglob('*.gd'))
    scenes = list(source.rglob('*.tscn'))
    for path in scripts + scenes:
        name = path.relative_to(source).as_posix()
        if name not in entries and name + '.remap' not in entries:
            raise ValueError(f'Original component omitted from pack: {name}')
    preserved = []
    for path in sorted((source / 'assetsNEW').rglob('*')):
        if path.is_file() and path.suffix.lower() in {'.png', '.jpg', '.webp', '.ogg', '.wav', '.mp3', '.tscn', '.glb', '.obj'}:
            relative = path.relative_to(source)
            digest = sha(path)
            if digest != sha(stage / relative):
                raise ValueError(f'Original asset changed: {relative}')
            preserved.append({'path': relative.as_posix(), 'sha256': digest})
    manifest = {'engine': '4.4.1.stable', 'originalVersion': '1.0.3b',
        'file': pack.name, 'bytes': pack.stat().st_size, 'sha256': sha(pack),
        'url': 'https://github.com/RenatoLV/App_Aniversario/releases/download/uncanny-original-1.0.3b-mobile1/uncanny-mobile.pck',
        'credit': 'https://slappyhappy2000.itch.io/uncanny-cat-golf'}
    (APP / 'tool/uncanny_pack.json').write_text(json.dumps(manifest, indent=2)+'\n', encoding='utf-8')
    (APP / 'docs/uncanny-preserved-assets.json').write_text(json.dumps(preserved, indent=2)+'\n', encoding='utf-8')
    report = {'packEntries': entry_count, 'sourceScripts': len(scripts),
        'sourceScenes': len(scenes), 'missingScriptsOrScenes': [],
        'preservedArtAudioModelScenes': len(preserved)}
    (APP / 'docs/uncanny-package-verification.json').write_text(json.dumps(report, indent=2)+'\n', encoding='utf-8')
    print(f'Preserved {len(preserved)} original art/audio/model/scene files byte for byte; pack: {manifest["sha256"]}')

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--source', type=Path, required=True)
    parser.add_argument('--godot', required=True)
    args = parser.parse_args()
    prepare(args.source, str(Path(args.godot).resolve()))
