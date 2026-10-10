import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nuestro_rincon/marus_zombies/mz_art_style.dart';
import 'package:nuestro_rincon/marus_zombies/mz_catalog.dart';
import 'package:nuestro_rincon/marus_zombies/mz_levels.dart';
import 'package:nuestro_rincon/marus_zombies/mz_models.dart';
import 'package:nuestro_rincon/marus_zombies/mz_painter.dart';
import 'package:nuestro_rincon/marus_zombies/mz_scenery.dart';
import 'package:nuestro_rincon/marus_zombies/mz_simulation.dart';
import 'package:nuestro_rincon/marus_zombies/mz_visual_feedback.dart';

const units = [MzCat.launcher, MzCat.barrier, MzCat.mine, MzCat.bomb];
MzSimulation scene(MzCat cat, {bool targets = true}) {
  final s = MzSimulation(const MzLevel(8))..tuna = 3;
  s.defenders.add(MzDefender(s.nextId++, cat, 2, 2)..attack = 20);
  if (cat == MzCat.barrier) s.defenders.single.hp = 700;
  if (targets) {
    for (var i = 0; i < 3; i++) {
      s.spawn(MzEnemy.bucket, i + 1, x: cat == MzCat.bomb ? 3 : 6);
      s.invaders.last.hp = 10000;
    }
  }
  return s;
}

bool feed(MzSimulation s, MzVisualFeedback art) {
  art.capturePower(s);
  final ok = s.feed(2, 2);
  art.observe(s);
  return ok;
}

void tick(MzSimulation s, MzVisualFeedback art, [double dt = 1 / 60]) {
  s.advance(dt);
  art.observe(s);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'launcher tags real burst projectiles, keeps 60 shots with and without targets',
    () {
      for (final targets in [false, true]) {
        final s = scene(MzCat.launcher, targets: targets),
            art = MzVisualFeedback()..observe(s);
        expect(feed(s, art), true);
        expect(s.projectiles, isEmpty);
        expect(s.defenders.single.burstLeft, 60);
        expect(feed(s, art), false);
        final ids = <int>{};
        for (var i = 0; i < 60; i++) {
          tick(s, art);
          ids.addAll(
            s.projectiles.where((p) => art.burstShot(p.id)).map((p) => p.id),
          );
        }
        expect(ids.length, 60);
        expect(s.defenders.single.burstLeft, 0);
      }
    },
  );
  test(
    'Wuaton repairs and equips exactly the real armor; presentation never creates immunity',
    () {
      final s = scene(MzCat.barrier), art = MzVisualFeedback()..observe(s);
      expect(feed(s, art), true);
      final d = s.defenders.single;
      expect(d.hp, 3000);
      expect(d.armor, 6000);
      final snapshot = s.toJson();
      art.observe(s);
      expect(s.toJson(), snapshot);
      s.hurt(d, 6100);
      art.observe(s);
      expect(d.armor, 0);
      expect(d.hp, 2900);
    },
  );
  test(
    'mine birth tags only the two real armed copies and is silent on restore',
    () {
      final s = scene(MzCat.mine), art = MzVisualFeedback()..observe(s);
      final source = s.defenders.single.id;
      expect(feed(s, art), true);
      expect(s.defenders.length, 3);
      expect(s.defenders.every((d) => d.armed), true);
      expect(art.copyPulse(source, s.time), 0);
      expect(
        s.defenders.where((d) => art.copyPulse(d.id, s.time) > 0).length,
        2,
      );
      expect(art.events.where((e) => e.type == 'tuna').length, 1);
      final restored = MzSimulation.fromJson(s.toJson())..paused = false;
      final fresh = MzVisualFeedback()..observe(restored);
      expect(
        restored.defenders.every(
          (d) => fresh.copyPulse(d.id, restored.time) == 0,
        ),
        true,
      );
      expect(fresh.events, isEmpty);
    },
  );
  test(
    'full or almost full board yields zero or one real copy, never fake landings',
    () {
      for (final free in [0, 1]) {
        final s = scene(MzCat.mine, targets: false);
        for (var r = 0; r < 5; r++) {
          for (var c = 0; c < 9; c++) {
            if (r == 2 && c == 2 || free == 1 && r == 0 && c == 0) continue;
            s.defenders.add(MzDefender(s.nextId++, MzCat.barrier, r, c));
          }
        }
        final art = MzVisualFeedback()..observe(s), tuna = s.tuna;
        expect(feed(s, art), free > 0);
        expect(
          s.defenders.where((d) => art.copyPulse(d.id, s.time) > 0).length,
          free,
        );
        expect(s.tuna, tuna - free);
      }
    },
  );
  test(
    'bomb rejects tuna, prepares before its real automatic blast, never on shovel removal',
    () {
      for (final targets in [false, true]) {
        final s = scene(MzCat.bomb, targets: targets),
            art = MzVisualFeedback()..observe(s);
        expect(feed(s, art), false);
        expect(s.tuna, 3);
        tick(s, art, .65);
        expect(art.prepare(s.defenders.single, s), greaterThan(0));
        expect(s.effects.where((f) => art.bombExplosion(f)), isEmpty);
        tick(s, art, .15);
        expect(s.defenders, isEmpty);
        expect(s.effects.where((f) => art.bombExplosion(f)).length, 1);
        final restored = MzSimulation.fromJson(s.toJson())..paused = false;
        final fresh = MzVisualFeedback()..observe(restored);
        expect(restored.effects.where(fresh.bombExplosion), isEmpty);
      }
      final s = scene(MzCat.bomb), art = MzVisualFeedback()..observe(s);
      s.remove(2, 2);
      tick(s, art);
      expect(s.effects.where(art.bombExplosion), isEmpty);
    },
  );
  test('all four actions preserve RNG and checkpoints, including pause/x2', () {
    for (final cat in units) {
      final s = scene(cat),
          control = MzSimulation.fromJson(s.toJson())..paused = false;
      final art = MzVisualFeedback()..observe(s);
      expect(feed(s, art), control.feed(2, 2));
      for (var i = 0; i < 90; i++) {
        if (i == 5) {
          s.paused = control.paused = true;
        }
        if (i == 9) {
          s.paused = control.paused = false;
        }
        tick(s, art, 2 / 60);
        control.advance(2 / 60);
        expect(s.toJson(), control.toJson());
        expect(art.events.length, lessThanOrEqualTo(MzArt.maxVisualEvents));
      }
    }
  });
  test(
    'simultaneous linked powers and multiple bombs remain real and bounded',
    () {
      final s = MzSimulation(const MzLevel(49))..tuna = 3;
      s.defenders.addAll([
        MzDefender(s.nextId++, MzCat.launcher, 0, 1),
        MzDefender(s.nextId++, MzCat.barrier, 4, 3),
        MzDefender(s.nextId++, MzCat.mine, 2, 5),
      ]);
      for (var i = 0; i < 80; i++) {
        s.spawn(MzEnemy.bucket, i % 5, x: 7);
      }
      final control = MzSimulation.fromJson(s.toJson())..paused = false;
      final art = MzVisualFeedback()..observe(s);
      art.capturePower(s);
      s.feed(0, 1);
      control.feed(0, 1);
      art.observe(s);
      expect(art.events.where((e) => e.type == 'tuna').length, 3);
      for (var i = 0; i < 120; i++) {
        tick(s, art, 2 / 60);
        control.advance(2 / 60);
        expect(s.toJson(), control.toJson());
      }
      final bombs = scene(MzCat.bomb);
      for (var i = 0; i < 4; i++) {
        bombs.defenders.add(MzDefender(bombs.nextId++, MzCat.bomb, i, 4));
      }
      final feedback = MzVisualFeedback()..observe(bombs);
      for (var i = 0; i < 49; i++) {
        tick(bombs, feedback);
      }
      expect(bombs.effects.where(feedback.bombExplosion).length, 5);
      expect(feedback.events.length, lessThanOrEqualTo(MzArt.maxVisualEvents));
    },
  );
  test(
    'failed requests and restored states do not replay any of the four powers',
    () {
      for (final cat in units) {
        final s = scene(cat), art = MzVisualFeedback()..observe(s);
        s.tuna = 0;
        expect(feed(s, art), false);
        expect(art.events.where((e) => e.type == 'tuna'), isEmpty);
        s.tuna = 3;
        s.paused = true;
        expect(feed(s, art), false);
        expect(art.events.where((e) => e.type == 'tuna'), isEmpty);
        s.paused = false;
        expect(feed(s, art), cat != MzCat.bomb);
        tick(s, art, .1);
        final restored = MzSimulation.fromJson(s.toJson())..paused = false;
        final fresh = MzVisualFeedback()..observe(restored);
        expect(fresh.events, isEmpty);
        expect(
          restored.defenders.every(
            (d) =>
                fresh.power(d.id, restored.time) == 0 &&
                fresh.copyPulse(d.id, restored.time) == 0,
          ),
          true,
        );
        expect(restored.toJson(), s.toJson());
      }
    },
  );
  test(
    'render sequences and CPU comparison',
    () async {
      for (final font in ['Nunito', 'Fredoka']) {
        await (FontLoader(font)..addFont(
              Future.value(
                ByteData.sublistView(
                  File('assets/fonts/$font.ttf').readAsBytesSync(),
                ),
              ),
            ))
            .load();
      }
      Directory('build/previews').createSync(recursive: true);
      final cache = MzSceneryCache();
      for (final cat in units) {
        final s = scene(cat), art = MzVisualFeedback()..observe(s);
        if (cat != MzCat.bomb) feed(s, art);
        for (var frame = 0; frame < 5; frame++) {
          final at = [0.0, .2, .65, .85, 1.05][frame];
          while (s.time < at - .0001) {
            tick(s, art);
          }
          for (final enabled in [false, true]) {
            final recorder = ui.PictureRecorder();
            MzBoardPainter(
              s,
              visuals: art,
              scenery: cache,
              secondStagePowers: enabled,
            ).paint(Canvas(recorder), const Size(960, 540));
            final picture = recorder.endRecording(),
                image = await picture.toImage(960, 540);
            final bytes = (await image.toByteData(
              format: ui.ImageByteFormat.png,
            ))!;
            File(
              'build/previews/mz-v39-${cat.name}-${enabled ? 'after' : 'before'}-$frame.png',
            ).writeAsBytesSync(bytes.buffer.asUint8List());
            image.dispose();
            picture.dispose();
          }
        }
      }
      final s = scene(MzCat.launcher);
      for (var i = 0; i < 80; i++) {
        s.spawn(MzEnemy.bucket, i % 5, x: 7);
      }
      final art = MzVisualFeedback()..observe(s);
      feed(s, art);
      for (var i = 0; i < 24; i++) {
        tick(s, art);
      }
      final times = <String, List<double>>{'baseline': [], 'enhanced': []};
      for (var round = 0; round < 6; round++) {
        for (final enabled in [false, true]) {
          final clock = Stopwatch()..start();
          for (var frame = 0; frame < 30; frame++) {
            final rec = ui.PictureRecorder();
            MzBoardPainter(
              s,
              visuals: art,
              scenery: cache,
              secondStagePowers: enabled,
            ).paint(Canvas(rec), const Size(960, 540));
            rec.endRecording().dispose();
          }
          clock.stop();
          if (round > 0) {
            times[enabled ? 'enhanced' : 'baseline']!.add(
              clock.elapsedMicroseconds / 30000,
            );
          }
        }
      }
      File(
        'build/previews/mz-v39-profile.json',
      ).writeAsStringSync(jsonEncode(times));
      File('build/previews/mz-specials-v39.html').writeAsStringSync('''
<!doctype html><html lang="es"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Marus vs Zombies · Poderes V3.9</title><style>
body{background:#182e29;color:#fff1cf;font:16px system-ui;margin:24px}main{max-width:1500px;margin:auto}
nav{display:flex;gap:16px;flex-wrap:wrap;align-items:center}select,button{font:inherit;padding:12px;border-radius:10px;background:#fff1cf;color:#182e29}
.pair{display:flex;gap:16px}figure{flex:1;min-width:0;margin:16px 0}img{width:100%;border-radius:14px}figcaption{padding:8px}
input{width:100%;margin:22px 0}@media(max-width:700px){.pair{flex-direction:column}}</style>
<main><h1>Poderes especiales · Segunda etapa V3.9</h1><p>Estados equivalentes del motor, con la segunda etapa visual desactivada/activada. V3.8 se conserva en ambas columnas.</p>
<nav><label>Personaje <select id="cat"><option value="launcher">Lanzador</option><option value="barrier">Maru Wuatón</option><option value="mine">Caja sorpresa</option><option value="bomb">Gatitos bomba</option></select></label>
<button id="play">Reproducir secuencia</button><output id="time"></output></nav>
<p id="note"></p><input id="frame" aria-label="Fotograma" type="range" min="0" max="4" value="1" step="1">
<div class="pair"><figure><figcaption>Sin V3.9</figcaption><img id="before" alt="Estado equivalente sin segunda etapa visual"></figure>
<figure><figcaption>Con V3.9</figcaption><img id="after" alt="Estado equivalente con segunda etapa visual"></figure></div>
<p>40 capturas Canvas a 960×540. No son vídeos a tiempo real ni mediciones de FPS. No se reproduce sonido en este comparador; el juego conserva los sonidos existentes.</p></main>
<script>
const cat=document.getElementById('cat'),frame=document.getElementById('frame');
function show(){for(const side of ['before','after'])document.getElementById(side).src='mz-v39-'+cat.value+'-'+side+'-'+frame.value+'.png';document.getElementById('time').textContent=[0,.2,.65,.85,1.05][frame.value]+' s';document.getElementById('note').textContent=cat.value==='bomb'?'Gatitos bomba no acepta atún: la secuencia representa su explosión automática real a los 0,8 s.':'La secuencia comienza con una activación real de atún.';}
for(const control of [cat,frame])control.addEventListener('input',show);
let timer=null;document.getElementById('play').onclick=()=>{if(timer){clearInterval(timer);timer=null;return;}frame.value=0;show();timer=setInterval(()=>{frame.value=(Number(frame.value)+1)%5;show();if(frame.value==='4'){clearInterval(timer);timer=null;}},350);};show();
</script></html>''');
      for (final cat in units) {
        final sim = scene(cat), visuals = MzVisualFeedback()..observe(sim);
        if (cat != MzCat.bomb) feed(sim, visuals);
        for (final size in [
          const Size(320, 640),
          const Size(844, 390),
          const Size(1440, 900),
        ]) {
          for (final reduced in [false, true]) {
            final rec = ui.PictureRecorder();
            MzBoardPainter(
              sim,
              visuals: visuals,
              reducedMotion: reduced,
            ).paint(Canvas(rec), size);
            rec.endRecording().dispose();
          }
        }
      }
      cache.dispose();
    },
    skip: !const bool.fromEnvironment('RENDER_SPECIALS'),
  );
}
