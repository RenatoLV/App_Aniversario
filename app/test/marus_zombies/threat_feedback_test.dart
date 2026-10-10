import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nuestro_rincon/marus_zombies/mz_catalog.dart';
import 'package:nuestro_rincon/marus_zombies/mz_levels.dart';
import 'package:nuestro_rincon/marus_zombies/mz_painter.dart';
import 'package:nuestro_rincon/marus_zombies/mz_scenery.dart';
import 'package:nuestro_rincon/marus_zombies/mz_simulation.dart';
import 'package:nuestro_rincon/marus_zombies/mz_threat_feedback.dart';
import 'package:nuestro_rincon/marus_zombies/mz_threat_art.dart';

MzSimulation approaching(int id, MzEnemy kind, double lead) {
  final s = MzSimulation(MzLevel(id));
  final index = s.schedule.indexWhere((e) => e.kind == kind);
  s.time = s.schedule[index].time - lead;
  s.spawnIndex = index;
  return s;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('Patio 10 warning precedes the real final flags once, pause and x2', () {
    for (final speed in [1, 2]) {
      final s = approaching(9, MzEnemy.flag, 4.04), f = MzThreatFeedback();
      expect(f.observe(s), isEmpty);
      expect(s.invaders, isEmpty);
      s.advance(.1 * speed);
      expect(f.observe(s), [MzThreatKind.wave]);
      expect(s.invaders, isEmpty); // A warning creates no fake enemies.
      final start = f.waveStart;
      s.paused = true;
      s.advance(90);
      expect(f.observe(s), isEmpty);
      expect(f.waveStart, start);
      expect(f.announcement(s.time), '¡Se acerca una gran oleada!');
      s.paused = false;
      s.advance(4);
      expect(f.observe(s), isEmpty);
      expect(s.invaders.where((e) => e.kind == MzEnemy.flag).length, 5);
      expect(f.arrivals.length, 5);
      expect(f.observe(s), isEmpty);
      expect(f.arrivals.length, 5);
    }
  });
  test(
    'campaign 60 is stable ID 49; boss intro and HP follow the real invader',
    () {
      expect(mzCampaignNumber(49), 60);
      final s = approaching(49, MzEnemy.boss, .04), f = MzThreatFeedback();
      f.observe(s);
      expect(f.hasBoss, false);
      s.advance(.1);
      expect(f.observe(s), [MzThreatKind.boss]);
      expect(f.hasBoss, true);
      expect(f.bossMaximum, MzEnemy.boss.health);
      expect(f.bossHp, s.invaders.single.hp);
      expect(f.observe(s), isEmpty);
      s.hit(s.invaders.single, 1500, pierce: true);
      f.observe(s);
      expect(f.bossHp, MzEnemy.boss.health - 1500);
      s.advance(2.5);
      f.observe(s);
      expect(f.announcement(s.time), null);
      expect(f.hasBoss, true); // The HP bar outlives the intro.
      s.hit(s.invaders.single, 20000, pierce: true);
      f.observe(s);
      expect(f.hasBoss, false);
    },
  );
  test('resume does not replay notices or boss arrivals; restart resets', () {
    final s = approaching(49, MzEnemy.boss, .04);
    s.advance(.1);
    final restored = MzSimulation.fromJson(s.toJson())..paused = false;
    final f = MzThreatFeedback();
    expect(f.observe(restored), isEmpty);
    expect(f.hasBoss, true);
    expect(f.bossStart, null);
    expect(f.arrivals, isEmpty);
    final newRun = approaching(49, MzEnemy.boss, .04);
    f.observe(newRun);
    newRun.advance(.1);
    expect(f.observe(newRun), [MzThreatKind.boss]);
  });
  test('read-only observation never modifies checkpoints or RNG', () {
    final s = approaching(9, MzEnemy.flag, 4.04), f = MzThreatFeedback();
    final control = MzSimulation.fromJson(s.toJson())..paused = false;
    f.observe(s);
    for (var i = 0; i < 240; i++) {
      s.advance(2 / 60);
      f.observe(s);
      control.advance(2 / 60);
      expect(s.toJson(), control.toJson());
    }
  });
  test('early missions and survival never invent scheduled wave warnings', () {
    for (final level in [
      const MzLevel(0),
      const MzLevel(9, mode: MzMode.survival),
    ]) {
      final s = MzSimulation(level);
      final f = MzThreatFeedback(allWorlds: true)..observe(s);
      for (var i = 0; i < 120; i++) {
        s.advance(1);
        expect(f.observe(s), isNot(contains(MzThreatKind.wave)));
      }
    }
  });
  test(
    'danger is based on live positions; all worlds use real flag groups',
    () {
      for (final id in [9, 59, 19, 29, 39, 49]) {
        final s = approaching(id, MzEnemy.flag, 4.04);
        final f = MzThreatFeedback(allWorlds: true)..observe(s);
        s.advance(.1);
        expect(f.observe(s), [MzThreatKind.wave]);
        s.spawn(MzEnemy.common, 3, x: 1.49);
        f.observe(s);
        expect(f.dangerRows[3], true);
        s.invaders.last.hp = 0;
        f.observe(s);
        expect(f.dangerRows[3], false);
      }
    },
  );
  test(
    'header stays outside touch grid; reduced motion keeps information',
    () async {
      final s = approaching(49, MzEnemy.boss, .04), f = MzThreatFeedback();
      f.observe(s);
      s.advance(.1);
      f.observe(s);
      for (final size in [
        const Size(320, 640),
        const Size(844, 390),
        const Size(1440, 900),
      ]) {
        final board = MzBoardGeometry(size).board;
        for (final reduced in [true, false]) {
          final rec = ui.PictureRecorder();
          mzPaintThreatHeader(Canvas(rec), board, f, s.time, reduced);
          final pic = rec.endRecording();
          final image = await pic.toImage(
            size.width.toInt(),
            size.height.toInt(),
          );
          final data = (await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          ))!;
          var opaque = 0;
          for (var y = board.top.ceil(); y < board.bottom.floor(); y++) {
            for (var x = board.left.ceil(); x < board.right.floor(); x++) {
              opaque += data.getUint8((y * size.width.toInt() + x) * 4 + 3) > 0
                  ? 1
                  : 0;
            }
          }
          expect(opaque, 0, reason: '$size reduced=$reduced');
          final semantics = MzBoardPainter(s, threats: f).semanticsBuilder!(
            size,
          );
          expect(
            semantics.single.properties.label,
            contains(MzEnemy.boss.label),
          );
          image.dispose();
          pic.dispose();
        }
      }
    },
  );
  test(
    'capture pilot comparisons and profile added vector work',
    () async {
      for (final family in ['Nunito', 'Fredoka']) {
        await (FontLoader(family)..addFont(
              Future.value(
                ByteData.sublistView(
                  File('assets/fonts/$family.ttf').readAsBytesSync(),
                ),
              ),
            ))
            .load();
      }
      const size = Size(960, 540);
      final cache = MzSceneryCache();
      Directory('build/previews').createSync(recursive: true);
      for (final name in [
        'patio-wave',
        'patio-horde',
        'patio-danger',
        'boss-arrival',
        'boss-health',
      ]) {
        final boss = name.startsWith('boss');
        final s = approaching(
          boss ? 49 : 9,
          boss ? MzEnemy.boss : MzEnemy.flag,
          boss ? .04 : 4.04,
        );
        final f = MzThreatFeedback()..observe(s);
        s.advance(.1);
        f.observe(s);
        if (name == 'boss-health') {
          s.hit(s.invaders.single, 4200, pierce: true);
          s.advance(2.5);
          f.observe(s);
        } else {
          s.advance(.35);
          f.observe(s);
        }
        if (name == 'patio-horde') {
          s.advance(3.65);
          f.observe(s);
          s.advance(.12);
          f.observe(s);
        }
        if (name == 'patio-danger') {
          s.spawn(MzEnemy.common, 2, x: 1.2);
          f.observe(s);
        }
        for (final enabled in [false, true]) {
          final rec = ui.PictureRecorder();
          MzBoardPainter(
            s,
            scenery: cache,
            threats: enabled ? f : null,
          ).paint(Canvas(rec), size);
          final pic = rec.endRecording();
          final image = await pic.toImage(960, 540);
          final data = (await image.toByteData(
            format: ui.ImageByteFormat.png,
          ))!;
          File(
            'build/previews/mz-v37-$name-${enabled ? 'after' : 'before'}.png',
          ).writeAsBytesSync(data.buffer.asUint8List());
          image.dispose();
          pic.dispose();
        }
      }
      final s = approaching(49, MzEnemy.boss, .04),
          f = MzThreatFeedback()..observe(approaching(9, MzEnemy.flag, 4.04));
      f.observe(s);
      s.advance(.1);
      f.observe(s);
      for (var i = 0; i < 20; i++) {
        s.spawn(MzEnemy.common, i % 5, x: 7 + (i % 3) * .3);
      }
      f.observe(s);
      final values = <String, List<double>>{'baseline': [], 'enhanced': []};
      for (var round = 0; round < 6; round++) {
        for (final enabled in [false, true]) {
          final clock = Stopwatch()..start();
          for (var frame = 0; frame < 30; frame++) {
            final rec = ui.PictureRecorder();
            MzBoardPainter(
              s,
              scenery: cache,
              threats: enabled ? f : null,
            ).paint(Canvas(rec), size);
            rec.endRecording().dispose();
          }
          clock.stop();
          if (round > 0) {
            values[enabled ? 'enhanced' : 'baseline']!.add(
              clock.elapsedMicroseconds / 30000,
            );
          }
        }
      }
      File(
        'build/previews/mz-v37-profile.json',
      ).writeAsStringSync(jsonEncode(values));
      final sections =
          [
                ('patio-wave', 'Patio 10 · aviso previo'),
                ('patio-horde', 'Entrada real de las cinco banderas'),
                ('patio-danger', 'Amenaza cerca de la defensa'),
                ('boss-arrival', 'Cyber-Gatos 60 · entrada del jefe'),
                ('boss-health', 'Vida real tras recibir 4200 de daño'),
              ]
              .map(
                (e) =>
                    '''<section><h2>${e.$2}</h2><div class="pair">
        <figure><figcaption>Antes</figcaption><img src="mz-v37-${e.$1}-before.png"></figure>
        <figure><figcaption>V3.7</figcaption><img src="mz-v37-${e.$1}-after.png"></figure>
        </div></section>''',
              )
              .join();
      File('build/previews/mz-threats-v37.html').writeAsStringSync('''
        <!doctype html><html lang="es"><meta charset="utf-8">
        <meta name="viewport" content="width=device-width,initial-scale=1">
        <title>Marus vs Zombies · V3.7</title><style>
        body{background:#162d27;color:#fff1cc;font:16px system-ui;margin:24px}
        main{max-width:1500px;margin:auto}h2{font-size:20px}.pair{display:flex;gap:14px}
        figure{margin:0;flex:1;min-width:0}img{width:100%;border-radius:12px}
        figcaption{padding:8px}section{margin:28px 0}
        @media(max-width:650px){.pair{flex-direction:column}}
        </style><main><h1>Grandes oleadas y Dr. Maru Cat-trófico</h1>
        <p>Comparaciones Canvas del mismo estado de simulación a 960×540.
        Fixtures de prueba; no son grabaciones de una partida completa ni mediciones de FPS.</p>
        $sections</main></html>''');
      cache.dispose();
    },
    skip: !const bool.fromEnvironment('RENDER_THREATS'),
  );
}
