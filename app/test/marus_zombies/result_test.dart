import 'dart:io';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nuestro_rincon/marus_zombies/mz_game_screen.dart';
import 'package:nuestro_rincon/marus_zombies/mz_levels.dart';
import 'package:nuestro_rincon/marus_zombies/mz_progress.dart';
import 'package:nuestro_rincon/marus_zombies/mz_simulation.dart';
import 'package:nuestro_rincon/marus_zombies/mz_result.dart';
import 'package:nuestro_rincon/marus_zombies/mz_catalog.dart';
import 'package:nuestro_rincon/marus_zombies/mz_almanac.dart';

void main() {
  setUpAll(() async {
    for (final n in ['Nunito', 'Fredoka']) {
      await (FontLoader(n)..addFont(
            Future.value(
              ByteData.sublistView(
                File('assets/fonts/$n.ttf').readAsBytesSync(),
              ),
            ),
          ))
          .load();
    }
    if (const bool.fromEnvironment('RENDER_MZ')) {
      for (final e in {
        'Roboto': 'roboto-regular.ttf',
        'MaterialIcons': 'materialicons-regular.otf',
      }.entries) {
        await (FontLoader(e.key)..addFont(
              Future.value(
                ByteData.sublistView(
                  File(
                    'C:/src/flutter/bin/cache/artifacts/material_fonts/${e.value}',
                  ).readAsBytesSync(),
                ),
              ),
            ))
            .load();
      }
    }
  });
  for (final won in [true, false]) {
    testWidgets('result capture $won', (t) async {
      t.view.physicalSize = Size(
        const int.fromEnvironment('RESULT_WIDTH', defaultValue: 960).toDouble(),
        const int.fromEnvironment(
          'RESULT_HEIGHT',
          defaultValue: 540,
        ).toDouble(),
      );
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({
        MzProgress.key: jsonEncode({
          'stars': {'0': 3},
        }),
      });
      final p = MzProgress(await SharedPreferences.getInstance());
      final s = MzSimulation(const MzLevel(1))
        ..won = won
        ..lost = !won;
      await t.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(fontFamily: 'Nunito'),
          home: RepaintBoundary(
            key: const ValueKey('capture'),
            child: MzGameScreen(sim: s, progress: p),
          ),
        ),
      );
      await t.pump();
      await t.tap(find.text('Reintentar guardado'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 1700));
      expect(t.takeException(), isNull);
      if (const bool.fromEnvironment('RENDER_MZ')) {
        await t.runAsync(() async {
          final b = t.renderObject<RenderRepaintBoundary>(
            find.byKey(const ValueKey('capture')),
          );
          final im = await b.toImage();
          final d = await im.toByteData(format: ui.ImageByteFormat.png);
          await File(
            'build/previews/mz-result-${const String.fromEnvironment('RESULT_STAGE', defaultValue: 'after')}-${won ? 'win' : 'loss'}-${t.view.physicalSize.width.toInt()}.png',
          ).writeAsBytes(d!.buffer.asUint8List());
          im.dispose();
        });
      }
      if (won &&
          const String.fromEnvironment('RESULT_STAGE', defaultValue: 'after') !=
              'before') {
        expect(find.text('¡Nueva carta desbloqueada!'), findsOneWidget);
        expect(
          p.prefs.getStringList(MzAlmanacScreen.seenKey),
          contains('cat-barrier'),
        );
        await t.tap(find.byKey(const ValueKey('reveal-card')));
        await t.pump(const Duration(milliseconds: 400));
        await t.ensureVisible(find.text('Ver en el almanaque'));
        await t.tap(find.text('Ver en el almanaque'));
        await t.pump();
        await t.pump(const Duration(milliseconds: 400));
        expect(find.byType(MzAlmanacScreen), findsOneWidget);
        expect(
          t
              .widget<Text>(find.byKey(const ValueKey('almanac-detail-name')))
              .data,
          mzCats[MzCat.barrier]!.name,
        );
        Navigator.of(t.element(find.byType(MzAlmanacScreen))).pop();
        await t.pump();
        await t.pump(const Duration(milliseconds: 400));
        expect(find.byType(MzResultPanel), findsOneWidget);
        final seen = p.prefs.getStringList(MzAlmanacScreen.seenKey)!;
        expect(seen.toSet().length, seen.length);
        await t.tap(find.text('Siguiente nivel'));
        await t.pump();
        await t.pump(const Duration(milliseconds: 50));
        expect(find.byType(MzResultPanel), findsNothing);
        expect(find.text('Patio de Maru · 3'), findsOneWidget);
      }
      if (!won &&
          const String.fromEnvironment('RESULT_STAGE', defaultValue: 'after') !=
              'before') {
        expect(find.text('¡Nueva carta desbloqueada!'), findsNothing);
        await t.tap(find.text('Reintentar nivel'));
        await t.pump();
        await t.pump(const Duration(milliseconds: 50));
        expect(find.byType(MzResultPanel), findsNothing);
        expect(find.text('Patio de Maru · 2'), findsOneWidget);
      }
      await t.pumpWidget(const SizedBox());
    });
  }
  test(
    'receipt follows real rewards, repeat victories and survival loss',
    () async {
      SharedPreferences.setMockInitialValues({
        MzProgress.key: jsonEncode({
          'stars': {for (var i = 0; i < 9; i++) '$i': 3},
        }),
      });
      final p = MzProgress(await SharedPreferences.getInstance());
      final s = MzSimulation(const MzLevel(9))..won = true;
      var r = MzResultReceipt(p, s);
      await p.complete(s);
      r.resolve(p, s);
      expect(r.cookies, 150);
      expect(r.mints, 10);
      expect(r.newCards, [MzCat.boomerang]);
      expect(r.starsAdded, 3);
      r = MzResultReceipt(p, s);
      await p.complete(s);
      r.resolve(p, s);
      expect(r.cookies, 0);
      expect(r.mints, 0);
      expect(r.newCards, isEmpty);
      expect(r.starsAdded, 0);
      final loss = MzSimulation(const MzLevel(0, mode: MzMode.survival))
        ..lost = true
        ..wave = 10;
      r = MzResultReceipt(p, loss);
      await p.complete(loss);
      r.resolve(p, loss);
      expect(r.cookies, 200);
      expect(r.mints, 10);
      expect(r.newCards, isEmpty);
      final challenge = MzSimulation(
        const MzLevel(0, mode: MzMode.challenge, seed: 44),
      )..won = true;
      r = MzResultReceipt(p, challenge);
      await p.complete(challenge);
      r.resolve(p, challenge);
      expect(r.cookies, 100);
      expect(r.mints, 5);
      expect(r.newCards, isEmpty);
    },
  );
  testWidgets('result CPU profile', (t) async {
    t.view.physicalSize = const Size(960, 540);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    final active = <double>[], settled = <double>[];
    for (var round = 0; round < 5; round++) {
      SharedPreferences.setMockInitialValues({
        MzProgress.key: jsonEncode({
          'stars': {'0': 3},
        }),
      });
      final p = MzProgress(await SharedPreferences.getInstance());
      final s = MzSimulation(const MzLevel(1))..won = true;
      await t.pumpWidget(
        MaterialApp(
          theme: ThemeData(fontFamily: 'Nunito'),
          home: MzGameScreen(sim: s, progress: p),
        ),
      );
      await t.pump();
      await t.tap(find.text('Reintentar guardado'));
      await t.pump();
      for (var i = 0; i < 5; i++) {
        await t.pump(const Duration(milliseconds: 16));
      }
      var watch = Stopwatch()..start();
      for (var i = 0; i < 50; i++) {
        await t.pump(const Duration(milliseconds: 16));
      }
      watch.stop();
      active.add(watch.elapsedMicroseconds / 50000);
      await t.pump(const Duration(seconds: 2));
      watch = Stopwatch()..start();
      for (var i = 0; i < 50; i++) {
        await t.pump(const Duration(milliseconds: 16));
      }
      watch.stop();
      settled.add(watch.elapsedMicroseconds / 50000);
      await t.pumpWidget(const SizedBox());
    }
    active.sort();
    settled.sort();
    final data = {
      'activeMedianMs': active[2],
      'settledMedianMs': settled[2],
      'activeBatchesMs': active,
      'settledBatchesMs': settled,
    };
    await t.runAsync(() async {
      await File(
        'build/previews/mz-result-profile-${const String.fromEnvironment('RESULT_STAGE', defaultValue: 'after')}.json',
      ).writeAsString(jsonEncode(data));
    });
  }, skip: !const bool.fromEnvironment('PROFILE_RESULT'));
  for (final size in [
    const Size(320, 640),
    const Size(844, 390),
    const Size(1440, 900),
  ]) {
    testWidgets('result responsive $size with reduced motion and large text', (
      t,
    ) async {
      t.view.physicalSize = size;
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      final p = MzProgress(await SharedPreferences.getInstance());
      final s = MzSimulation(const MzLevel(0))..won = true;
      final r = MzResultReceipt(p, s);
      await p.complete(s);
      r.resolve(p, s);
      var left = false;
      await t.pumpWidget(
        MaterialApp(
          theme: ThemeData(fontFamily: 'Nunito'),
          home: MediaQuery(
            data: MediaQueryData(
              size: size,
              textScaler: TextScaler.linear(1.8),
            ),
            child: MzResultPanel(
              sim: s,
              receipt: r,
              reducedMotion: true,
              saving: false,
              completed: true,
              onRetry: () {},
              onLeave: () {
                left = true;
              },
              onSave: () {},
              onAlmanac: (_) {},
            ),
          ),
        ),
      );
      await t.pump();
      expect(t.takeException(), isNull);
      final art = t
          .widget<CustomPaint>(find.byKey(const ValueKey('result-celebration')))
          .painter;
      await t.pump(const Duration(seconds: 2));
      expect(
        identical(
          art,
          t
              .widget<CustomPaint>(
                find.byKey(const ValueKey('result-celebration')),
              )
              .painter,
        ),
        true,
      );
      expect(find.text('Volver al mapa').hitTestable(), findsOneWidget);
      await t.tap(find.text('Volver al mapa'));
      expect(left, true);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    });
  }
}
