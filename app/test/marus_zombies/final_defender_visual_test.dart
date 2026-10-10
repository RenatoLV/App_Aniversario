import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nuestro_rincon/marus_zombies/mz_catalog.dart';
import 'package:nuestro_rincon/marus_zombies/mz_levels.dart';
import 'package:nuestro_rincon/marus_zombies/mz_models.dart';
import 'package:nuestro_rincon/marus_zombies/mz_painter.dart';
import 'package:nuestro_rincon/marus_zombies/mz_scenery.dart';
import 'package:nuestro_rincon/marus_zombies/mz_simulation.dart';
import 'package:nuestro_rincon/marus_zombies/mz_visual_feedback.dart';

const cats = [MzCat.boomerang, MzCat.spring, MzCat.lightning];
MzSimulation scene(MzCat cat, {bool targets = true}) {
  final s = MzSimulation(const MzLevel(8))..tuna = 3;
  s.defenders.add(MzDefender(s.nextId++, cat, 2, 2)..attack = .016);
  if (targets) {
    for (var i = 0; i < 3; i++) {
      s.spawn(MzEnemy.bucket, 2, x: 3.5 + i * .5);
      s.invaders.last.hp = 10000;
    }
  }
  return s;
}

void tick(MzSimulation s, MzVisualFeedback a, [double dt = 1 / 60]) {
  s.advance(dt);
  a.observe(s);
}

bool feed(MzSimulation s, MzVisualFeedback a) {
  a.capturePower(s);
  final ok = s.feed(2, 2);
  a.observe(s);
  return ok;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('fish normal and tuna follow real outbound and inbound hits', () {
    for (final powered in [false, true]) {
      final s = scene(MzCat.boomerang), a = MzVisualFeedback()..observe(s);
      s.defenders.single.attack = powered ? 20 : .016;
      if (powered) expect(feed(s, a), true);
      tick(s, a);
      expect(s.projectiles.length, powered ? 3 : 1);
      expect(s.projectiles.every((p) => p.damage == (powered ? 40 : 20)), true);
      expect(s.projectiles.every((p) => a.poweredShot(p.id) == powered), true);
      var returned = false;
      final outbound = <int>{}, inbound = <int>{};
      for (var i = 0; i < 65; i++) {
        tick(s, a);
        for (final p in s.projectiles) {
          returned |= p.returning;
          outbound.addAll(p.outboundHits);
          inbound.addAll(p.inboundHits);
          expect(a.trail(p.id).length, lessThanOrEqualTo(5));
        }
      }
      expect(returned, true);
      expect(outbound.length, 3);
      expect(inbound.length, 3);
    }
  });
  test('spring displacement is real, boss immunity remains intact', () {
    final s = scene(MzCat.spring), a = MzVisualFeedback()..observe(s);
    final first = s.invaders.first, x = first.x;
    tick(s, a);
    expect(first.x, closeTo(x + 1.5 - .17 / 60, .02));
    expect(a.attack(s.defenders.single.id, s.time), greaterThan(0));
    final special = scene(MzCat.spring);
    special.spawn(MzEnemy.boss, 2, x: 4);
    final boss = special.invaders.last, bossX = boss.x;
    final positions = special.invaders.map((e) => e.x).toList();
    final art = MzVisualFeedback()..observe(special);
    expect(feed(special, art), true);
    for (var i = 0; i < 3; i++) {
      expect(special.invaders[i].x, positions[i] + 3);
    }
    expect(boss.x, bossX);
  });
  test(
    'lightning visuals correspond to actual target effects, never extra links',
    () {
      for (final powered in [false, true]) {
        final s = scene(MzCat.lightning);
        for (var i = 0; i < 7; i++) {
          s.spawn(MzEnemy.bucket, i % 5, x: 4);
          s.invaders.last.hp = 10000;
        }
        final a = MzVisualFeedback()..observe(s);
        if (powered) {
          expect(feed(s, a), true);
        } else {
          tick(s, a);
        }
        expect(
          s.effects.where((f) => f.type == 'electric').length,
          powered ? 8 : 3,
        );
        expect(s.effects.where(a.lightningEffect).length, powered ? 8 : 3);
        final restored = MzSimulation.fromJson(s.toJson());
        final fresh = MzVisualFeedback()..observe(restored);
        expect(restored.effects.where(fresh.lightningEffect), isEmpty);
        expect(s.projectiles, isEmpty);
      }
    },
  );
  test('failed, empty, paused and restored powers create no fake actions', () {
    for (final cat in cats) {
      final s = scene(cat, targets: false), a = MzVisualFeedback()..observe(s);
      s.tuna = 0;
      expect(feed(s, a), false);
      expect(a.power(s.defenders.single.id, s.time), 0);
      s.tuna = 3;
      s.paused = true;
      expect(feed(s, a), false);
      s.paused = false;
      tick(s, a);
      expect(a.attack(s.defenders.single.id, s.time), 0);
      expect(feed(s, a), true);
      expect(s.projectiles.length, cat == MzCat.boomerang ? 3 : 0);
      expect(s.effects.where((f) => f.type == 'electric'), isEmpty);
      final restored = MzSimulation.fromJson(s.toJson());
      final json = restored.toJson();
      final fresh = MzVisualFeedback()..observe(restored);
      expect(fresh.events, isEmpty);
      expect(fresh.power(restored.defenders.single.id, restored.time), 0);
      expect(restored.toJson(), json);
      s.paused = true;
      final time = s.time;
      tick(s, a);
      expect(s.time, time);
    }
  });
  test(
    'normal, simultaneous powers and x2 observers preserve checkpoints and RNG',
    () {
      for (final powered in [false, true]) {
        final s = scene(MzCat.boomerang);
        s.defenders.add(MzDefender(s.nextId++, MzCat.spring, 1, 2));
        s.defenders.add(MzDefender(s.nextId++, MzCat.lightning, 3, 2));
        for (var i = 0; i < 80; i++) {
          s.spawn(MzEnemy.bucket, i % 5, x: 4 + i % 4);
        }
        final control = MzSimulation.fromJson(s.toJson())..paused = false;
        final a = MzVisualFeedback()..observe(s);
        if (powered) {
          for (final row in [2, 1, 3]) {
            a.capturePower(s);
            expect(s.feed(row, 2), control.feed(row, 2));
            a.observe(s);
          }
        }
        for (var i = 0; i < 150; i++) {
          s.advance(2 / 60);
          control.advance(2 / 60);
          a.observe(s);
          expect(s.toJson(), control.toJson());
          expect(a.events.length, lessThanOrEqualTo(32));
        }
      }
    },
  );
  test(
    'render final defenders at 32px, responsive boards and reduced motion',
    () {
      for (final cat in cats) {
        final s = scene(cat), a = MzVisualFeedback()..observe(s);
        feed(s, a);
        for (final reduced in [true, false]) {
          for (final size in [
            const Size(320, 640),
            const Size(844, 390),
            const Size(1440, 900),
          ]) {
            final rec = ui.PictureRecorder();
            MzBoardPainter(
              s,
              visuals: a,
              reducedMotion: reduced,
            ).paint(Canvas(rec), size);
            rec.endRecording().dispose();
          }
        }
        final rec = ui.PictureRecorder();
        mzDrawCat(Canvas(rec), const Offset(16, 25), 32, cat: cat);
        rec.endRecording().dispose();
      }
    },
  );
  test(
    'V391 equivalent captures and CPU profile',
    () async {
      Directory('build/previews').createSync(recursive: true);
      final cache = MzSceneryCache();
      final thumbRec = ui.PictureRecorder(), thumbCanvas = Canvas(thumbRec);
      thumbCanvas.drawColor(const Color(0xffeddcb2), BlendMode.src);
      for (var row = 0; row < cats.length; row++) {
        final s = scene(cats[row]), a = MzVisualFeedback()..observe(s);
        feed(s, a);
        for (var column = 0; column < 3; column++) {
          final size = [32.0, 64.0, 128.0][column];
          for (var active = 0; active < 2; active++) {
            mzDrawCat(
              thumbCanvas,
              Offset(
                [30.0, 160.0, 370.0][column] + active * (size + 18),
                115 + row * 145.0,
              ),
              size,
              cat: cats[row],
              power: active == 1 ? a.power(s.defenders.single.id, s.time) : 0,
            );
          }
        }
      }
      final thumbs = thumbRec.endRecording(),
          thumbImage = await thumbs.toImage(660, 460);
      final thumbData = (await thumbImage.toByteData(
        format: ui.ImageByteFormat.png,
      ))!;
      File(
        'build/previews/mz-v391-thumbnails.png',
      ).writeAsBytesSync(thumbData.buffer.asUint8List());
      thumbImage.dispose();
      thumbs.dispose();
      const times = [0.0, .0333333333, .2, .5, 1.2];
      for (final cat in cats) {
        for (final powered in [false, true]) {
          final s = scene(cat), a = MzVisualFeedback()..observe(s);
          if (powered) {
            s.defenders.single.attack = 20;
            feed(s, a);
          }
          for (var frame = 0; frame < times.length; frame++) {
            while (s.time < times[frame] - .0001) {
              tick(s, a);
            }
            for (final enabled in [false, true]) {
              final rec = ui.PictureRecorder();
              MzBoardPainter(
                s,
                visuals: a,
                scenery: cache,
                finalDefenderPowers: enabled,
              ).paint(Canvas(rec), const Size(960, 540));
              final picture = rec.endRecording(),
                  img = await picture.toImage(960, 540);
              final data = (await img.toByteData(
                format: ui.ImageByteFormat.png,
              ))!;
              File(
                'build/previews/mz-v391-${cat.name}-${powered ? 'tuna' : 'normal'}-${enabled ? 'after' : 'before'}-$frame.png',
              ).writeAsBytesSync(data.buffer.asUint8List());
              img.dispose();
              picture.dispose();
            }
          }
        }
      }
      final s = scene(MzCat.lightning);
      s.defenders.add(MzDefender(s.nextId++, MzCat.spring, 1, 2));
      s.defenders.add(MzDefender(s.nextId++, MzCat.boomerang, 3, 2));
      for (var i = 0; i < 80; i++) {
        s.spawn(MzEnemy.bucket, i % 5, x: 4 + i % 4);
      }
      final a = MzVisualFeedback()..observe(s);
      for (final row in [2, 1, 3]) {
        a.capturePower(s);
        s.feed(row, 2);
        a.observe(s);
      }
      tick(s, a, .033333333);
      final profile = <String, List<double>>{'baseline': [], 'enhanced': []};
      for (var round = 0; round < 6; round++) {
        // Alternate order to avoid always measuring the new version second.
        for (final enabled in round.isEven ? [false, true] : [true, false]) {
          final clock = Stopwatch()..start();
          for (var i = 0; i < 30; i++) {
            final rec = ui.PictureRecorder();
            MzBoardPainter(
              s,
              visuals: a,
              scenery: cache,
              finalDefenderPowers: enabled,
            ).paint(Canvas(rec), const Size(960, 540));
            rec.endRecording().dispose();
          }
          clock.stop();
          if (round > 0) {
            profile[enabled ? 'enhanced' : 'baseline']!.add(
              clock.elapsedMicroseconds / 30000,
            );
          }
        }
      }
      File(
        'build/previews/mz-v391-profile.json',
      ).writeAsStringSync(jsonEncode(profile));
      File('build/previews/mz-final-defenders-v391.html').writeAsStringSync(
        '''<!doctype html><html lang="es"><meta charset="utf-8"><title>Marus V3.9.1</title><style>body{background:#172c23;color:#ffedc0;font:18px system-ui;margin:24px}select,button,input{font:inherit;margin:8px}section{display:flex;gap:16px}figure{margin:0;width:50%}img{width:100%}@media(max-width:600px){section{display:block}figure{width:100%}}</style><h1>Los últimos tres defensores · V3.9.1</h1><select id="cat"><option value="boomerang">Bumerán</option><option value="spring">Resorte</option><option value="lightning">Relámpago</option></select><select id="mode"><option value="normal">Ataque normal</option><option value="tuna">Atún</option></select><button id="play">Reproducir</button><input type="range" id="frame" min="0" max="4" value="2" aria-label="Fotograma"><output id="time"></output><section><figure><figcaption>Antes · V3.8/V3.9 conservadas</figcaption><img id="before" alt="Antes"></figure><figure><figcaption>Después · V3.9.1</figcaption><img id="after" alt="Después"></figure></section><p>60 capturas Canvas a 960×540 del mismo estado real. Fotogramas discretos, no vídeo ni medición de FPS. Bumerán regresa cuando su proyectil real lo hace. Las descargas corresponden a impactos reales, sin conexiones hipotéticas.</p><script>const cat=document.getElementById('cat'),mode=document.getElementById('mode'),frame=document.getElementById('frame');function show(){for(const side of ['before','after'])document.getElementById(side).src='mz-v391-'+cat.value+'-'+mode.value+'-'+side+'-'+frame.value+'.png';document.getElementById('time').textContent=[0,.033,.2,.5,1.2][frame.value]+' s'}for(const e of [cat,mode,frame])e.oninput=show;let timer;document.getElementById('play').onclick=()=>{clearInterval(timer);frame.value=0;show();timer=setInterval(()=>{frame.value=Number(frame.value)+1;show();if(frame.value==='4')clearInterval(timer)},400)};show();</script></html>''',
      );
      cache.dispose();
    },
    skip: !const bool.fromEnvironment('RENDER_FINAL_DEFENDERS'),
  );
}
