import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nuestro_rincon/marus_zombies/mz_catalog.dart';
import 'package:nuestro_rincon/marus_zombies/mz_levels.dart';
import 'package:nuestro_rincon/marus_zombies/mz_models.dart';
import 'package:nuestro_rincon/marus_zombies/mz_painter.dart';
import 'package:nuestro_rincon/marus_zombies/mz_scenery.dart';
import 'package:nuestro_rincon/marus_zombies/mz_progress.dart';
import 'package:nuestro_rincon/marus_zombies/mz_game_screen.dart';
import 'package:nuestro_rincon/marus_zombies/mz_simulation.dart';
import 'package:nuestro_rincon/marus_zombies/mz_threat_feedback.dart';
import 'package:nuestro_rincon/marus_zombies/mz_visual_feedback.dart';
import 'package:nuestro_rincon/marus_zombies/mz_world_transition.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    if (!const bool.fromEnvironment('RENDER_V4')) return;
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
    for (final entry in {
      'Roboto': 'roboto-regular.ttf',
      'MaterialIcons': 'materialicons-regular.otf',
    }.entries) {
      await (FontLoader(entry.key)..addFont(
            Future.value(
              ByteData.sublistView(
                File(
                  'C:/src/flutter/bin/cache/artifacts/material_fonts/${entry.value}',
                ).readAsBytesSync(),
              ),
            ),
          ))
          .load();
    }
  });
  test(
    'audit all 60 schedules, mechanics and restored deterministic observations',
    () {
      expect(mzCampaign.length, 60);
      for (final level in mzCampaign) {
        final s = MzSimulation(level), control = MzSimulation(level);
        final art = MzVisualFeedback()..observe(s);
        final threats = MzThreatFeedback(allWorlds: true)..observe(s);
        expect(s.roombas.length, 5);
        expect(s.tombs.isNotEmpty, level.world == MzWorld.cemetery);
        expect(s.bridges.isNotEmpty, level.world == MzWorld.pirates);
        expect(s.carts.isNotEmpty, level.world == MzWorld.west);
        expect(level.boss, level.id == 49);
        for (var i = 1; i < s.schedule.length; i++) {
          expect(
            s.schedule[i].time,
            greaterThanOrEqualTo(s.schedule[i - 1].time),
          );
        }
        expect(
          s.schedule.every((spawn) => level.rows.contains(spawn.row)),
          true,
        );
        for (var i = 0; i < 60; i++) {
          s.advance(.5);
          control.advance(.5);
          art.observe(s);
          threats.observe(s);
          expect(s.toJson(), control.toJson());
        }
        final restored = MzSimulation.fromJson(s.toJson())..paused = false;
        final snapshot = restored.toJson();
        MzVisualFeedback().observe(restored);
        MzThreatFeedback(allWorlds: true).observe(restored);
        expect(restored.toJson(), snapshot);
        expect(snapshot, s.toJson());
      }
    },
  );
  test(
    'complete full campaign once, repeat rewards and preserve historic unlocks',
    () async {
      SharedPreferences.setMockInitialValues({});
      final p = MzProgress(await SharedPreferences.getInstance());
      for (final level in mzCampaign) {
        expect(p.levelUnlocked(level), true, reason: level.title);
        await p.complete(MzSimulation(level)..won = true);
        final before = [p.cookies, p.mints, p.campaignCompleted, p.highest];
        await p.complete(MzSimulation(level)..won = true);
        expect([p.cookies, p.mints, p.campaignCompleted, p.highest], before);
      }
      expect(p.campaignCompleted, 60);
      expect(p.highest, 50);
      expect(p.cemeteryHighest, 10);
      expect(p.pendingWorlds.toSet().length, 6);
      expect(mzUnlockedCats(p.highest).length, 11);
    },
  );
  test(
    'pickup touch target is 48px minimum and chooses closest real resource',
    () {
      final s = MzSimulation(const MzLevel(8));
      const size = Size(320, 180);
      final g = MzBoardGeometry(size);
      s.pickups.addAll([MzPickup(100, 2, 3), MzPickup(101, 2, 3.8)]);
      final center = g.point(2, 3).translate(0, -g.ch * .14);
      expect(mzPickupAt(s, size, center)!.id, 100);
      expect(mzPickupAt(s, size, center.translate(0, 23))!.id, 100);
      expect(mzPickupAt(s, size, center.translate(0, 25)), isNull);
      expect(s.pickups.length, 2); // Hit testing never collects or mutates.
    },
  );
  test(
    'boss equipment reacts only to real special resets, damage and defeat',
    () {
      final s = MzSimulation(const MzLevel(49));
      s.spawn(MzEnemy.boss, 2, x: 8);
      final boss = s.invaders.single..special = .016;
      final art = MzVisualFeedback()..observe(s);
      final control = MzSimulation.fromJson(s.toJson())..paused = false;
      s.advance(1 / 60);
      control.advance(1 / 60);
      art.observe(s);
      expect(art.performance(boss.id, s.time), greaterThan(0));
      expect(s.bossAdds, 2);
      expect(s.toJson(), control.toJson());
      s.hit(boss, 100, pierce: true);
      art.observe(s);
      expect(art.hurt(boss.id, s.time), greaterThan(0));
      s.hit(boss, 20000, pierce: true);
      s.advance(1 / 60);
      art.observe(s);
      expect(
        art.events.any((e) => e.type == 'defeat' && e.enemy == MzEnemy.boss),
        true,
      );
      final restored = MzSimulation.fromJson(s.toJson());
      expect((MzVisualFeedback()..observe(restored)).events, isEmpty);
    },
  );
  test(
    'saturated fixture with all eleven defenders preserves simulation and RNG',
    () {
      final s = MzSimulation(const MzLevel(49))..tuna = 20;
      for (var i = 0; i < 80; i++) {
        s.spawn(MzEnemy.bucket, i % 5, x: 5 + i % 4);
      }
      s.spawn(MzEnemy.boss, 2, x: 8);
      for (var i = 0; i < 11; i++) {
        s.defenders.add(MzDefender(s.nextId++, MzCat.values[i], i % 5, i ~/ 5));
      }
      final control = MzSimulation.fromJson(s.toJson())..paused = false;
      final visuals = MzVisualFeedback()..observe(s);
      final threats = MzThreatFeedback(allWorlds: true)..observe(s);
      for (final d in s.defenders.toList()) {
        visuals.capturePower(s);
        expect(s.feed(d.row, d.col), control.feed(d.row, d.col));
        visuals.observe(s);
        threats.observe(s);
        expect(s.toJson(), control.toJson());
      }
      for (var i = 0; i < 240; i++) {
        s.advance(2 / 60);
        control.advance(2 / 60);
        visuals.observe(s);
        threats.observe(s);
        expect(s.toJson(), control.toJson());
        expect(visuals.events.length, lessThanOrEqualTo(32));
        expect(threats.arrivals.length, lessThanOrEqualTo(8));
      }
    },
  );
  testWidgets(
    'six world transitions fit compact, landscape and desktop with reduced motion',
    (t) async {
      for (final size in [
        const Size(320, 568),
        const Size(640, 320),
        const Size(1440, 900),
      ]) {
        t.view.physicalSize = size;
        t.view.devicePixelRatio = 1;
        for (var i = 0; i < mzWorldOrder.length; i++) {
          var continued = false;
          await t.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: MzWorldTransition(
                  key: ValueKey('$size-$i'),
                  from: mzWorldOrder[i],
                  to: i == 5 ? null : mzWorldOrder[i + 1],
                  reducedMotion: true,
                  onContinue: () => continued = true,
                ),
              ),
            ),
          );
          await t.pump();
          expect(t.takeException(), isNull);
          await t.tap(find.text('Omitir'));
          expect(continued, true);
        }
      }
      t.view.resetPhysicalSize();
      t.view.resetDevicePixelRatio();
    },
  );
  testWidgets(
    'first saved world clear transitions to cemetery, replay does not',
    (t) async {
      t.view.physicalSize = const Size(960, 540);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      for (final replay in [false, true]) {
        SharedPreferences.setMockInitialValues({
          MzProgress.key: jsonEncode({
            'stars': {for (var i = 0; i < (replay ? 10 : 9); i++) '$i': 3},
            'reduced': true,
          }),
        });
        final p = MzProgress(await SharedPreferences.getInstance());
        final sim = MzSimulation(const MzLevel(9))..won = true;
        await t.pumpWidget(
          MaterialApp(
            home: MzGameScreen(key: ValueKey(replay), sim: sim, progress: p),
          ),
        );
        await t.pump();
        await t.tap(find.text('Reintentar guardado'));
        await t.pump();
        await t.pump(const Duration(seconds: 2));
        if (find.text('Continuar').evaluate().isNotEmpty) {
          await t.tap(find.text('Continuar'));
          await t.pump();
          await t.pump(const Duration(milliseconds: 300));
          await t.pump();
        }
        await t.tap(find.text('Siguiente nivel'));
        await t.pump();
        await t.pump(const Duration(milliseconds: 300));
        await t.pump();
        expect(
          find.byType(MzWorldTransition),
          replay ? findsNothing : findsOneWidget,
        );
        if (!replay) {
          await t.tap(find.text('Omitir'));
          await t.pump();
          await t.pump(const Duration(milliseconds: 300));
          await t.pump();
        }
        expect(p.resume()!.level.id, 50);
        expect(p.stars['9'], 3);
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox());
      }
    },
  );
  testWidgets('compact real combat HUD remains visible and overflow free', (
    t,
  ) async {
    for (final size in [
      const Size(320, 568),
      const Size(640, 320),
      const Size(844, 390),
    ]) {
      t.view.physicalSize = size;
      t.view.devicePixelRatio = 1;
      SharedPreferences.setMockInitialValues({});
      final p = MzProgress(await SharedPreferences.getInstance());
      await t.pumpWidget(
        MaterialApp(
          home: MzGameScreen(sim: MzSimulation(const MzLevel(8)), progress: p),
        ),
      );
      await t.pump();
      expect(find.byKey(const ValueKey('mz-board')), findsOneWidget);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    }
    t.view.resetPhysicalSize();
    t.view.resetDevicePixelRatio();
  });
  testWidgets(
    'V4 captures and CPU profile without compiling',
    (t) async {
      await t.runAsync(() async {
        Directory('build/previews').createSync(recursive: true);
        final s = MzSimulation(const MzLevel(49));
        final art = MzVisualFeedback()..observe(s),
            threats = MzThreatFeedback(allWorlds: true)..observe(s);
        s.spawn(MzEnemy.boss, 2, x: 8);
        art.observe(s);
        threats.observe(s);
        final cache = MzSceneryCache();
        for (var frame = 0; frame < 4; frame++) {
          if (frame == 1) {
            s.invaders.first.special = .016;
          }
          if (frame == 2) {
            s.hit(s.invaders.first, 1000, pierce: true);
          }
          if (frame == 3) {
            s.hit(s.invaders.first, 20000, pierce: true);
          }
          if (frame > 0) {
            s.advance(1 / 60);
            art.observe(s);
            threats.observe(s);
          }
          for (final refined in [false, true]) {
            final rec = ui.PictureRecorder();
            MzBoardPainter(
              s,
              visuals: art,
              threats: threats,
              scenery: cache,
              refinedBoss: refined,
            ).paint(Canvas(rec), const Size(960, 540));
            final picture = rec.endRecording(),
                image = await picture.toImage(960, 540);
            final bytes = (await image.toByteData(
              format: ui.ImageByteFormat.png,
            ))!;
            File(
              'build/previews/mz-v40-boss-${refined ? 'after' : 'before'}-$frame.png',
            ).writeAsBytesSync(bytes.buffer.asUint8List());
            image.dispose();
            picture.dispose();
          }
        }
        final stress = MzSimulation(const MzLevel(49))..tuna = 20;
        for (var i = 0; i < 80; i++) {
          stress.spawn(MzEnemy.bucket, i % 5, x: 5 + i % 4);
        }
        stress.spawn(MzEnemy.boss, 2, x: 8);
        for (var i = 0; i < 11; i++) {
          stress.defenders.add(
            MzDefender(stress.nextId++, MzCat.values[i], i % 5, i ~/ 5),
          );
        }
        final feedback = MzVisualFeedback()..observe(stress);
        for (final d in stress.defenders.toList()) {
          feedback.capturePower(stress);
          stress.feed(d.row, d.col);
          feedback.observe(stress);
        }
        for (var i = 0; i < 48; i++) {
          stress.advance(1 / 60);
          feedback.observe(stress);
        }
        final measures = <String, List<double>>{'baseline': [], 'refined': []};
        for (var round = 0; round < 6; round++) {
          for (final refined in round.isEven ? [false, true] : [true, false]) {
            final clock = Stopwatch()..start();
            for (var j = 0; j < 30; j++) {
              final rec = ui.PictureRecorder();
              MzBoardPainter(
                stress,
                visuals: feedback,
                scenery: cache,
                refinedBoss: refined,
              ).paint(Canvas(rec), const Size(960, 540));
              rec.endRecording().dispose();
            }
            clock.stop();
            if (round > 0) {
              measures[refined ? 'refined' : 'baseline']!.add(
                clock.elapsedMicroseconds / 30000,
              );
            }
          }
        }
        File(
          'build/previews/mz-v40-profile.json',
        ).writeAsStringSync(jsonEncode(measures));
        cache.dispose();
      });
      t.view.physicalSize = const Size(960, 540);
      t.view.devicePixelRatio = 1;
      for (var i = 0; i < 6; i++) {
        await t.pumpWidget(
          MaterialApp(
            home: RepaintBoundary(
              key: const ValueKey('capture'),
              child: Scaffold(
                body: MzWorldTransition(
                  key: ValueKey(i),
                  from: mzWorldOrder[i],
                  to: i == 5 ? null : mzWorldOrder[i + 1],
                  reducedMotion: false,
                  onContinue: () {},
                ),
              ),
            ),
          ),
        );
        await t.pump();
        await t.pump(const Duration(milliseconds: 1200));
        await t.runAsync(() async {
          final boundary = t.renderObject<RenderRepaintBoundary>(
            find.byKey(const ValueKey('capture')),
          );
          final image = await boundary.toImage();
          final bytes = (await image.toByteData(
            format: ui.ImageByteFormat.png,
          ))!;
          File(
            'build/previews/mz-v40-transition-$i.png',
          ).writeAsBytesSync(bytes.buffer.asUint8List());
          image.dispose();
        });
      }
      await t.pumpWidget(const SizedBox());
      t.view.resetPhysicalSize();
      t.view.resetDevicePixelRatio();
    },
    skip: !const bool.fromEnvironment('RENDER_V4'),
  );
}
