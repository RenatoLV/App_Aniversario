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

/// Opt-in CPU command-recording probe, not an FPS or GPU benchmark.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'record the same populated vector battlefield',
    () {
      final sim = MzSimulation(const MzLevel(8));
      for (var row = 0; row < 5; row++) {
        for (var col = 0; col < 5; col++) {
          sim.defenders.add(
            MzDefender(
              100 + row * 9 + col,
              MzCat.values[(row + col) % MzCat.values.length],
              row,
              col,
            ),
          );
        }
        for (var col = 0; col < 6; col++) {
          sim.spawn(
            const bool.fromEnvironment('FOCUS_MZ_ENEMIES')
                ? const [
                    MzEnemy.bucket,
                    MzEnemy.mummy,
                    MzEnemy.pianist,
                    MzEnemy.mecha,
                  ][(row + col) % 4]
                : MzEnemy.values[(row + col) % 14],
            row,
            x: 5 + col * .6,
          );
        }
      }
      final cache = MzSceneryCache();
      final painter = MzBoardPainter(sim, scenery: cache);
      void record() {
        final recorder = ui.PictureRecorder();
        painter.paint(Canvas(recorder), const Size(960, 540));
        recorder.endRecording().dispose();
      }

      for (var i = 0; i < 50; i++) {
        record();
      }
      final samples = <double>[];
      for (var batch = 0; batch < 7; batch++) {
        final timer = Stopwatch()..start();
        for (var i = 0; i < 100; i++) {
          record();
        }
        timer.stop();
        samples.add(timer.elapsedMicroseconds / 100000);
      }
      samples.sort();
      final result = {
        'phase': const String.fromEnvironment(
          'ART_PHASE',
          defaultValue: 'after',
        ),
        'size': '960x540',
        'defenders': 25,
        'invaders': 30,
        'focusedEnemies': const bool.fromEnvironment('FOCUS_MZ_ENEMIES'),
        'medianCpuRecordingMs': samples[3],
        'samplesMs': samples,
        'scope':
            'Flutter test CPU vector command recording; excludes GPU raster and device FPS',
      };
      final file = File('build/previews/mz-render-${result['phase']}.json')
        ..parent.createSync(recursive: true);
      file.writeAsStringSync(
        const JsonEncoder.withIndent('  ').convert(result),
      );
      cache.dispose();
      // ignore: avoid_print
      print(jsonEncode(result));
    },
    skip: !const bool.fromEnvironment('PROFILE_MZ'),
  );
}
