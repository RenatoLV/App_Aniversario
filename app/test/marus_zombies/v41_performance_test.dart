import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nuestro_rincon/marus_zombies/mz_art_style.dart';
import 'package:nuestro_rincon/marus_zombies/mz_catalog.dart';
import 'package:nuestro_rincon/marus_zombies/mz_combat_audio.dart';
import 'package:nuestro_rincon/marus_zombies/mz_levels.dart';
import 'package:nuestro_rincon/marus_zombies/mz_models.dart';
import 'package:nuestro_rincon/marus_zombies/mz_painter.dart';
import 'package:nuestro_rincon/marus_zombies/mz_scenery.dart';
import 'package:nuestro_rincon/marus_zombies/mz_simulation.dart';
import 'package:nuestro_rincon/marus_zombies/mz_threat_feedback.dart';
import 'package:nuestro_rincon/marus_zombies/mz_visual_feedback.dart';
import 'support/gameplay_probe.dart';

MzSimulation load(bool extreme) {
  if (!extreme) {
    final probe = GameplayProbe(const MzLevel(49), 'reference');
    while (!probe.sim.ended && probe.sim.time < 295) {
      probe.tick();
    }
    return probe.sim;
  }
  // Explicitly synthetic, exceeds a legal deck. Never used for balance claims.
  final s = MzSimulation(const MzLevel(49))..tuna = 3;
  for (final cat in MzCat.values) {
    s.defenders.add(MzDefender(s.nextId++, cat, cat.index % 5, cat.index ~/ 5));
  }
  for (var i = 0; i < 80; i++) {
    s.spawn(MzEnemy.bucket, i % 5, x: 5.8 + (i ~/ 5) * .15);
  }
  s.spawn(MzEnemy.boss, 2, x: 8.5);
  s.feed(1, 0);
  s.advance(.1);
  return s;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'bounded observers and scene pictures across repeated real and extreme loads',
    () {
      final cache = MzSceneryCache();
      for (var run = 0; run < 6; run++) {
        final s = load(run.isEven),
            control = MzSimulation.fromJson(load(run.isEven).toJson())
              ..paused = false;
        final art = MzVisualFeedback()..observe(s),
            threats = MzThreatFeedback(allWorlds: true)..observe(s);
        final audio = MzCombatAudio();
        for (var i = 0; i < 120; i++) {
          audio.capture(s);
          s.advance(1 / 60);
          control.advance(1 / 60);
          art.observe(s);
          threats.observe(s);
          audio.events(s);
          expect(s.toJson(), control.toJson());
          expect(art.events.length, lessThanOrEqualTo(MzArt.maxVisualEvents));
          expect(art.trailCount, lessThanOrEqualTo(MzArt.maxTrails));
          expect(
            art.trailSamples,
            lessThanOrEqualTo(MzArt.maxTrails * MzArt.maxTrailSamples),
          );
          expect(
            art.trackedActors,
            s.defenders.length + s.invaders.where((e) => e.alive).length,
          );
          expect(threats.arrivals.length, lessThanOrEqualTo(8));
        }
        final r = ui.PictureRecorder();
        MzBoardPainter(
          s,
          scenery: cache,
          visuals: art,
        ).paint(Canvas(r), Size(960 + run * 2, 540));
        r.endRecording().dispose();
        expect(cache.pictureCount, 2);
        art.reset();
        audio.reset();
        threats.reset();
        cache.dispose();
        expect(art.trackedActors, 0);
        expect(art.trailCount, 0);
        expect(art.events, isEmpty);
        expect(cache.pictureCount, 0);
      }
    },
  );
  test(
    'CPU profiles differentiate playable six-card load and synthetic overload',
    () {
      final result = <String, Object>{
        'scope':
            'CPU Canvas/Picture recording and read-only observers; no GPU, FPS, native audio or Android measurement',
        'phase': const String.fromEnvironment(
          'PROFILE_PHASE',
          defaultValue: 'after',
        ),
      };
      for (final extreme in [false, true]) {
        final s = load(extreme), art = MzVisualFeedback()..observe(s);
        final threats = MzThreatFeedback(allWorlds: true)..observe(s),
            audio = MzCombatAudio();
        final cache = MzSceneryCache();
        final painter = MzBoardPainter(
          s,
          scenery: cache,
          visuals: art,
          threats: threats,
        );
        void paint() {
          final r = ui.PictureRecorder();
          painter.paint(Canvas(r), const Size(960, 540));
          r.endRecording().dispose();
        }

        for (var i = 0; i < 20; i++) {
          paint();
        }
        final paints = <double>[];
        for (var batch = 0; batch < 5; batch++) {
          final clock = Stopwatch()..start();
          for (var i = 0; i < 30; i++) {
            paint();
          }
          paints.add(clock.elapsedMicroseconds / 30000);
        }
        final observerSamples = <double>[];
        var maxEvents = 0, maxTrails = 0, maxActors = 0;
        final control = MzSimulation.fromJson(s.toJson())..paused = false;
        for (var i = 0; i < 600; i++) {
          final clock = Stopwatch()..start();
          audio.capture(s);
          clock.stop();
          s.advance(1 / 60);
          control.advance(1 / 60);
          clock.start();
          art.observe(s);
          threats.observe(s);
          audio.events(s);
          clock.stop();
          observerSamples.add(clock.elapsedMicroseconds / 1000);
          if (art.events.length > maxEvents) maxEvents = art.events.length;
          if (art.trailCount > maxTrails) maxTrails = art.trailCount;
          if (art.trackedActors > maxActors) maxActors = art.trackedActors;
        }
        expect(s.toJson(), control.toJson());
        paints.sort();
        observerSamples.sort();
        result[extreme ? 'synthetic' : 'legal'] = {
          'paintMedianMs': paints[2],
          'paintSamplesMs': paints,
          'observerMedianMs': observerSamples[300],
          'observerP95Ms': observerSamples[570],
          'maxEvents': maxEvents,
          'maxTrails': maxTrails,
          'maxActors': maxActors,
          'scenePictures': cache.pictureCount,
          'deck': s.deck.map((c) => c.name).toList(),
          'fixtureDefenders': painter.sim.defenders.length,
        };
        cache.dispose();
      }
      final file = File('build/previews/mz-v41-profile-${result['phase']}.json')
        ..parent.createSync(recursive: true);
      file.writeAsStringSync(
        const JsonEncoder.withIndent('  ').convert(result),
      );
      // ignore: avoid_print
      print(jsonEncode(result));
    },
    skip: !const bool.fromEnvironment('PROFILE_V41'),
  );
}
