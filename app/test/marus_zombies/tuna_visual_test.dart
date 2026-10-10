import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nuestro_rincon/game_audio.dart';
import 'package:nuestro_rincon/marus_zombies/mz_art_style.dart';
import 'package:nuestro_rincon/marus_zombies/mz_catalog.dart';
import 'package:nuestro_rincon/marus_zombies/mz_combat_audio.dart';
import 'package:nuestro_rincon/marus_zombies/mz_combat_art.dart';
import 'package:nuestro_rincon/marus_zombies/mz_levels.dart';
import 'package:nuestro_rincon/marus_zombies/mz_models.dart';
import 'package:nuestro_rincon/marus_zombies/mz_painter.dart';
import 'package:nuestro_rincon/marus_zombies/mz_scenery.dart';
import 'package:nuestro_rincon/marus_zombies/mz_simulation.dart';
import 'package:nuestro_rincon/marus_zombies/mz_visual_feedback.dart';

const cats = [MzCat.sunflower, MzCat.ice, MzCat.catapult, MzCat.laser];
MzSimulation fixture(MzCat cat, {bool special = true}) {
  final s = MzSimulation(const MzLevel(8))..tuna = 3;
  s.defenders.add(MzDefender(s.nextId++, cat, 2, 2)..attack = special ? 20 : 0);
  for (var i = 0; i < 6; i++) {
    s.spawn(MzEnemy.bucket, i % 3 + 1, x: 4 + (i ~/ 3) * 2);
    s.invaders.last.hp = 10000;
  }
  return s;
}

void activate(MzSimulation s, MzVisualFeedback art) {
  art.capturePower(s);
  expect(s.feed(2, 2), true);
  art.observe(s);
}

void tick(MzSimulation s, MzVisualFeedback art, [double dt = 1 / 60]) {
  s.advance(dt);
  art.observe(s);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'only a successful feed creates one power pulse; pause/x2 and expiry',
    () {
      for (final cat in cats) {
        final s = fixture(cat), art = MzVisualFeedback();
        art.reset();
        art.observe(s);
        expect(art.power(s.defenders.single.id, s.time), 0);
        s.paused = true;
        art.capturePower(s);
        expect(s.feed(2, 2), false);
        art.observe(s);
        expect(art.events.where((e) => e.type == 'tuna'), isEmpty);
        s.paused = false;
        activate(s, art);
        expect(art.events.where((e) => e.type == 'tuna').length, 1);
        final pulse = art.power(s.defenders.single.id, s.time);
        art.observe(s);
        expect(art.events.where((e) => e.type == 'tuna').length, 1);
        s.paused = true;
        tick(s, art, 2);
        expect(art.power(s.defenders.single.id, s.time), pulse);
        s.paused = false;
        tick(s, art, 2 / 60);
        expect(art.power(s.defenders.single.id, s.time), lessThan(pulse));
        tick(s, art, 1);
        expect(art.power(s.defenders.single.id, s.time), 0);
        art.reset();
        expect(art.events, isEmpty);
      }
    },
  );
  test(
    'sunflower decorates exactly fifteen new real resources, never collection',
    () {
      final s = fixture(MzCat.sunflower), art = MzVisualFeedback();
      art.reset();
      s.pickups.add(MzPickup(s.nextId++, 2, 2.5));
      final old = s.pickups.single.id;
      art.observe(s);
      activate(s, art);
      expect(art.resourceBirth(old), null);
      expect(
        s.pickups.where((p) => art.resourceBirth(p.id) != null).length,
        15,
      );
      final p = s.pickups.last;
      expect(s.collect(p.id), true);
      art.observe(s);
      expect(art.resourceBirth(p.id), null);
      final restored = MzSimulation.fromJson(s.toJson())..paused = false;
      final fresh = MzVisualFeedback()..observe(restored);
      expect(fresh.events.where((e) => e.type == 'tuna'), isEmpty);
      expect(
        restored.pickups.every((p) => fresh.resourceBirth(p.id) == null),
        true,
      );
    },
  );
  test(
    'freeze reactions only mark real living nonimmune targets in the correct lane',
    () {
      final s = fixture(MzCat.ice);
      final immune = s.invaders.firstWhere((e) => e.row == 2)..immuneUntil = 10;
      final art = MzVisualFeedback()..observe(s);
      activate(s, art);
      final ids = art.events
          .where((e) => e.type == 'freezeHit')
          .map((e) => e.seed)
          .toSet();
      final frozen = s.invaders
          .where((e) => e.frozenUntil > s.time)
          .map((e) => e.id)
          .toSet();
      expect(ids, frozen);
      expect(ids, isNot(contains(immune.id)));
      expect(ids.length, 1);
      art.observe(s);
      expect(art.events.where((e) => e.type == 'freezeHit').length, 1);
    },
  );
  test('catapult tracks the real burst and contact, not vanished targets', () {
    final s = fixture(MzCat.catapult), art = MzVisualFeedback();
    art.reset();
    art.observe(s);
    activate(s, art);
    expect(s.projectiles.length, 6);
    expect(s.projectiles.every((p) => art.poweredShot(p.id)), true);
    var impacts = false;
    for (var i = 0; i < 80; i++) {
      tick(s, art);
      impacts |= art.events.any((e) => e.type == 'croquetteHit');
    }
    expect(impacts, true);
    final lost = fixture(MzCat.catapult), visual = MzVisualFeedback();
    visual.reset();
    visual.observe(lost);
    activate(lost, visual);
    lost.invaders.clear();
    tick(lost, visual);
    expect(visual.events.where((e) => e.type == 'croquetteHit'), isEmpty);
  });
  test(
    'visual and V3.6 cues share the same feed transaction, no idle audio',
    () {
      final expected = [
        GameSfx.marusSunTuna,
        GameSfx.marusFreeze,
        GameSfx.marusCatapult,
        GameSfx.marusLaserStart,
      ];
      for (var i = 0; i < cats.length; i++) {
        final s = fixture(cats[i]),
            art = MzVisualFeedback(),
            audio = MzCombatAudio();
        art.reset();
        art.observe(s);
        art.capturePower(s);
        audio.capture(s);
        expect(s.feed(2, 2), true);
        art.observe(s);
        expect(art.power(s.defenders.single.id, s.time), 1);
        expect(audio.events(s), contains(expected[i]));
        expect(audio.events(s), isEmpty);
      }
    },
  );
  test(
    'linked simultaneous powers stay bounded and preserve the full checkpoint',
    () {
      final s = MzSimulation(const MzLevel(49))..tuna = 3;
      // Same actual holographic node: (row + col) % 3 == 1.
      s.defenders.addAll([
        MzDefender(s.nextId++, MzCat.sunflower, 0, 1),
        MzDefender(s.nextId++, MzCat.ice, 4, 3),
        MzDefender(s.nextId++, MzCat.catapult, 2, 5),
      ]);
      for (var i = 0; i < 80; i++) {
        s.spawn(MzEnemy.bucket, i % 5, x: 6 + (i % 3) * .3);
        s.invaders.last.hp = 10000;
      }
      final control = MzSimulation.fromJson(s.toJson())..paused = false;
      final art = MzVisualFeedback()..observe(s);
      art.capturePower(s);
      expect(s.feed(0, 1), true);
      expect(control.feed(0, 1), true);
      art.observe(s);
      expect(art.events.where((e) => e.type == 'tuna').length, 3);
      for (var i = 0; i < 180; i++) {
        tick(s, art, 2 / 60);
        control.advance(2 / 60);
        expect(s.toJson(), control.toJson());
        expect(art.events.length, lessThanOrEqualTo(MzArt.maxVisualEvents));
        expect(
          s.projectiles.every(
            (p) => art.trail(p.id).length <= MzArt.maxTrailSamples,
          ),
          true,
        );
      }
    },
  );

  test(
    'laser boosting starts at the powered source; idle creates no fake beam',
    () async {
      final s = fixture(MzCat.laser);
      s.defenders.add(MzDefender(s.nextId++, MzCat.laser, 2, 5));
      s.spawn(MzEnemy.bucket, 2, x: 8);
      final art = MzVisualFeedback()..observe(s);
      art.capturePower(s);
      expect(s.feed(2, 5), true);
      art.observe(s);
      tick(s, art);
      expect(s.defenders.first.powerUntil, 0);
      expect(s.defenders.last.powerUntil, greaterThan(s.time));
      final beam = s.effects.firstWhere((f) => f.type == 'laser' && f.x < 3);
      Future<ByteData> raster(bool boosted) async {
        final recorder = ui.PictureRecorder();
        mzPaintCombatEffect(
          Canvas(recorder),
          beam,
          s.time,
          40,
          40,
          (row, x) => Offset(x * 40, (row + .5) * 40),
          reducedMotion: true,
          powered: boosted,
          powerX: boosted ? 5.8 : null,
        );
        final pic = recorder.endRecording(),
            image = await pic.toImage(400, 200);
        final data = (await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!;
        image.dispose();
        pic.dispose();
        return data;
      }

      final normal = await raster(false), enhanced = await raster(true);
      expect(
        normal.getUint32((96 * 400 + 150) * 4),
        enhanced.getUint32((96 * 400 + 150) * 4),
      );
      expect(
        normal.getUint32((98 * 400 + 280) * 4),
        isNot(enhanced.getUint32((98 * 400 + 280) * 4)),
      );
      s.invaders.clear();
      tick(s, art, .2);
      expect(s.effects.where((f) => f.type == 'laser'), isEmpty);
    },
  );
  test(
    'power presentation respects reduced motion and all board aspect ratios',
    () {
      for (final cat in cats) {
        final s = fixture(cat), art = MzVisualFeedback()..observe(s);
        activate(s, art);
        tick(s, art, .12);
        s.paused = true;
        final snapshot = s.toJson(),
            pulse = art.power(s.defenders.single.id, s.time);
        for (final size in [
          const Size(320, 640),
          const Size(844, 390),
          const Size(1440, 900),
        ]) {
          for (final reduced in [false, true]) {
            final rec = ui.PictureRecorder();
            MzBoardPainter(
              s,
              visuals: art,
              reducedMotion: reduced,
            ).paint(Canvas(rec), size);
            rec.endRecording().dispose();
            tick(s, art, 2);
            expect(s.toJson(), snapshot);
            expect(art.power(s.defenders.single.id, s.time), pulse);
          }
        }
      }
    },
  );
  test(
    'capture four normal/power sequences and saturated render profile',
    () async {
      for (final name in ['Nunito', 'Fredoka']) {
        await (FontLoader(name)..addFont(
              Future.value(
                ByteData.sublistView(
                  File('assets/fonts/$name.ttf').readAsBytesSync(),
                ),
              ),
            ))
            .load();
      }
      Directory('build/previews').createSync(recursive: true);
      const size = Size(960, 540);
      final cache = MzSceneryCache();
      for (final cat in cats) {
        for (final special in [false, true]) {
          final s = fixture(cat, special: special), art = MzVisualFeedback();
          art.reset();
          art.observe(s);
          if (special) {
            activate(s, art);
          } else {
            tick(s, art);
          }
          var last = 0.0;
          for (var frame = 0; frame < 4; frame++) {
            final at = [0.0, .12, .32, .65][frame];
            while (s.time < last + at - .0001) {
              tick(s, art);
            }
            // Relative time is counted from the transaction, not wall clock.
            if (frame == 0) last = s.time;
            if (special) {
              expect(art.power(s.defenders.single.id, s.time), greaterThan(.1));
            }
            for (final enhanced in [false, true]) {
              final rec = ui.PictureRecorder();
              MzBoardPainter(
                s,
                scenery: cache,
                visuals: art,
                enhancedPowers: enhanced,
              ).paint(Canvas(rec), size);
              final pic = rec.endRecording(),
                  image = await pic.toImage(960, 540);
              final bytes = (await image.toByteData(
                format: ui.ImageByteFormat.png,
              ))!;
              File(
                'build/previews/mz-v38-${cat.name}-${special ? 'tuna' : 'normal'}-${enhanced ? 'after' : 'before'}-$frame.png',
              ).writeAsBytesSync(bytes.buffer.asUint8List());
              image.dispose();
              pic.dispose();
            }
          }
        }
      }
      final saturated = fixture(MzCat.catapult);
      for (var i = 0; i < 80; i++) {
        saturated.spawn(MzEnemy.bucket, i % 5, x: 5 + (i % 3));
      }
      final art = MzVisualFeedback()..observe(saturated);
      activate(saturated, art);
      tick(saturated, art, .12);
      final profile = <String, List<double>>{'baseline': [], 'enhanced': []};
      for (var round = 0; round < 6; round++) {
        for (final enhanced in [false, true]) {
          final clock = Stopwatch()..start();
          for (var frame = 0; frame < 30; frame++) {
            final recorder = ui.PictureRecorder();
            MzBoardPainter(
              saturated,
              scenery: cache,
              visuals: art,
              enhancedPowers: enhanced,
            ).paint(Canvas(recorder), size);
            recorder.endRecording().dispose();
          }
          clock.stop();
          if (round > 0) {
            profile[enhanced ? 'enhanced' : 'baseline']!.add(
              clock.elapsedMicroseconds / 30000,
            );
          }
        }
      }
      File(
        'build/previews/mz-v38-profile.json',
      ).writeAsStringSync(jsonEncode(profile));
      final observation = <String, List<double>>{'control': [], 'observed': []};
      for (var round = 0; round < 6; round++) {
        for (final enabled in [false, true]) {
          final s = fixture(MzCat.catapult);
          for (var i = 0; i < 80; i++) {
            s.spawn(MzEnemy.bucket, i % 5, x: 7);
          }
          final visual = MzVisualFeedback();
          if (enabled) visual.observe(s);
          final clock = Stopwatch()..start();
          if (enabled) visual.capturePower(s);
          s.feed(2, 2);
          if (enabled) visual.observe(s);
          for (var step = 0; step < 120; step++) {
            s.advance(1 / 60);
            if (enabled) visual.observe(s);
          }
          clock.stop();
          if (round > 0) {
            observation[enabled ? 'observed' : 'control']!.add(
              clock.elapsedMicroseconds / 120000,
            );
          }
        }
      }
      File(
        'build/previews/mz-v38-observer-profile.json',
      ).writeAsStringSync(jsonEncode(observation));
      File('build/previews/mz-tuna-v38.html').writeAsStringSync('''
<!doctype html><html lang="es"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Marus vs Zombies · Atún V3.8</title><style>
body{background:#182e29;color:#fff1cf;font:16px system-ui;margin:24px}main{max-width:1500px;margin:auto}
nav{display:flex;gap:16px;flex-wrap:wrap;align-items:center}select,button{font:inherit;padding:12px;border-radius:10px;background:#fff1cf;color:#182e29}
.pair{display:flex;gap:16px}figure{flex:1;min-width:0;margin:16px 0}img{width:100%;border-radius:14px}figcaption{padding:8px}
input{width:100%;margin:22px 0}@media(max-width:700px){.pair{flex-direction:column}}</style>
<main><h1>Habilidades de atún · V3.8</h1><p>Secuencias Canvas de estados reales equivalentes.
La columna anterior desactiva la nueva presentación. Cuatro fotogramas por acción; no son vídeos a tiempo real ni pruebas de FPS.</p>
<nav><label>Personaje <select id="cat"><option value="sunflower">Girasol</option><option value="ice">Siberiano</option><option value="catapult">Catapulta</option><option value="laser">Láser</option></select></label>
<label>Acción <select id="mode"><option value="tuna">Atún</option><option value="normal">Ataque normal</option></select></label>
<button id="play">Reproducir secuencia</button><output id="time"></output></nav>
<input id="frame" aria-label="Fotograma de la secuencia" type="range" min="0" max="3" value="1" step="1">
<div class="pair"><figure><figcaption>Presentación anterior</figcaption><img id="before" alt="Presentación anterior del combate"></figure>
<figure><figcaption>V3.8</figcaption><img id="after" alt="Presentación mejorada del mismo combate"></figure></div>
<p>El poder utiliza el mismo sonido aprobado de V3.6. Esta comparación visual no reproduce audio.</p></main>
<script>
const cat=document.getElementById('cat'),mode=document.getElementById('mode'),frame=document.getElementById('frame');
function show(){for(const side of ['before','after'])document.getElementById(side).src='mz-v38-'+cat.value+'-'+mode.value+'-'+side+'-'+frame.value+'.png';document.getElementById('time').textContent=[0,.12,.32,.65][frame.value]+' s tras la acción';}
for(const control of [cat,mode,frame])control.addEventListener('input',show);
let timer=null;document.getElementById('play').onclick=()=>{if(timer){clearInterval(timer);timer=null;return;}frame.value=0;show();timer=setInterval(()=>{frame.value=(Number(frame.value)+1)%4;show();if(frame.value==='3'){clearInterval(timer);timer=null;}},350);};show();
</script></html>''');
      cache.dispose();
    },
    skip: !const bool.fromEnvironment('RENDER_TUNA'),
  );
}
