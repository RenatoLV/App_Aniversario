import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nuestro_rincon/marus_zombies/mz_painter.dart';
import 'package:nuestro_rincon/marus_zombies/mz_scenery.dart';
import 'package:nuestro_rincon/marus_zombies/mz_world_art.dart';
import 'package:nuestro_rincon/marus_zombies/mz_catalog.dart';
import 'package:nuestro_rincon/marus_zombies/mz_levels.dart';
import 'package:nuestro_rincon/marus_zombies/mz_models.dart';
import 'package:nuestro_rincon/marus_zombies/mz_simulation.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'architecture cannot paint over cells or robot docks at any viewport',
    () async {
      for (final size in [
        const Size(960, 540),
        const Size(844, 390),
        const Size(320, 640),
        const Size(1440, 900),
      ]) {
        final board = MzBoardGeometry(size).board;
        for (var world = 0; world < MzWorld.values.length; world++) {
          final rec = ui.PictureRecorder();
          mzPaintWorldArchitecture(Canvas(rec), size, board, world);
          final pic = rec.endRecording();
          final im = await pic.toImage(size.width.toInt(), size.height.toInt());
          final data = await im.toByteData(format: ui.ImageByteFormat.rawRgba);
          var intrusions = 0;
          for (var y = board.top.ceil(); y < board.bottom.floor(); y++) {
            for (
              var x = (board.left * .65).ceil();
              x < board.right.floor();
              x++
            ) {
              if (data!.getUint8((y * size.width.toInt() + x) * 4 + 3) != 0) {
                intrusions++;
              }
            }
          }
          expect(intrusions, 0, reason: 'world $world at $size');
          im.dispose();
          pic.dispose();
        }
      }
    },
  );
  test(
    'cached and uncached scenes agree without changing the simulation',
    () async {
      const size = Size(640, 360);
      final cache = MzSceneryCache();
      for (final world in MzWorld.values) {
        final s = MzSimulation(MzLevel(world.index * 10 + 9));
        s.defenders.add(MzDefender(100, MzCat.launcher, 4, 8));
        s.spawn(s.level.enemies.last, 0, x: 9.1);
        final before = jsonEncode(s.toJson());
        final images = <ui.Image>[];
        for (final cached in [false, true]) {
          final rec = ui.PictureRecorder();
          MzBoardPainter(
            s,
            scenery: cached ? cache : null,
            reducedMotion: true,
          ).paint(Canvas(rec), size);
          final pic = rec.endRecording();
          images.add(await pic.toImage(640, 360));
          pic.dispose();
        }
        final a = (await images[0].toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!.buffer.asUint8List();
        final b = (await images[1].toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!.buffer.asUint8List();
        var maxDifference = 0;
        for (var i = 0; i < a.length; i++) {
          final d = (a[i] - b[i]).abs();
          if (d > maxDifference) maxDifference = d;
        }
        expect(maxDifference, lessThanOrEqualTo(1), reason: world.name);
        expect(jsonEncode(s.toJson()), before);
        for (final im in images) {
          im.dispose();
        }
      }
      cache.dispose();
    },
  );
  test('all 45 touch cells and five service docks keep their coordinates', () {
    for (final size in [
      const Size(320, 640),
      const Size(844, 390),
      const Size(1440, 900),
    ]) {
      final g = MzBoardGeometry(size),
          aisle = MzServiceAisle(MzBoardGeometry(size).board);
      for (var row = 0; row < 5; row++) {
        final p = aisle.robotPosition(row, null);
        expect(p.dx - aisle.robotSize / 2, greaterThan(aisle.houseSpan));
        expect(p.dx + aisle.robotSize / 2, lessThan(g.board.left));
        for (var col = 0; col < 9; col++) {
          expect(g.cell(g.point(row, col + .5)), (row, col));
        }
      }
    }
  });
  test(
    'scenery CPU profile: recording and cached replay',
    () {
      const size = Size(960, 540);
      final board = MzBoardGeometry(size).board;
      final results = <String, dynamic>{};
      for (var world = 0; world < MzWorld.values.length; world++) {
        final cold = <double>[], warm = <double>[];
        for (var batch = 0; batch < 7; batch++) {
          final cache = MzSceneryCache();
          var rec = ui.PictureRecorder();
          var c = Canvas(rec);
          var sw = Stopwatch()..start();
          cache.background(c, size, board, world);
          cache.foreground(c, size, board, world);
          sw.stop();
          cold.add(sw.elapsedMicroseconds / 1000);
          rec.endRecording().dispose();
          sw = Stopwatch()..start();
          for (var i = 0; i < 100; i++) {
            rec = ui.PictureRecorder();
            c = Canvas(rec);
            cache.background(c, size, board, world);
            cache.foreground(c, size, board, world);
            rec.endRecording().dispose();
          }
          sw.stop();
          warm.add(sw.elapsedMicroseconds / 100000);
          cache.dispose();
        }
        cold.sort();
        warm.sort();
        results['$world'] = {
          'coldMedianMs': cold[3],
          'cachedMedianMs': warm[3],
        };
      }
      final f = File(
        'build/previews/mz-worlds-profile-${const String.fromEnvironment('WORLD_STAGE', defaultValue: 'after')}.json',
      )..parent.createSync(recursive: true);
      f.writeAsStringSync(jsonEncode(results));
    },
    skip: !const bool.fromEnvironment('PROFILE_WORLDS'),
  );
}
