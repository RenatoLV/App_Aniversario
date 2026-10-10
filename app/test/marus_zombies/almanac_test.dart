import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nuestro_rincon/store.dart';
import 'package:nuestro_rincon/marus_zombies/mz_screen.dart';
import 'package:nuestro_rincon/marus_zombies/mz_almanac.dart';
import 'package:nuestro_rincon/marus_zombies/mz_catalog.dart';
import 'package:nuestro_rincon/marus_zombies/mz_progress.dart';

void main() {
  test('unlock requirements preserve the exact campaign boundaries', () {
    const thresholds = [0, 1, 2, 3, 4, 5, 6, 10, 20, 30, 40];
    for (final c in MzCat.values) {
      final n = mzAlmanacRequirement(c);
      expect(n, thresholds[c.index]);
      expect(mzUnlockedCats(n), contains(c));
      if (n > 0) expect(mzUnlockedCats(n - 1), isNot(contains(c)));
    }
  });
  testWidgets(
    'all 26 entries are selectable and only the active portrait changes on idle',
    (tester) async {
      final semantics = tester.ensureSemantics();
      var disposed = false;
      addTearDown(() {
        if (!disposed) semantics.dispose();
      });
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({
        MzProgress.key: jsonEncode({
          'stars': {for (var i = 0; i < 50; i++) '$i': 1},
          'deck': [0, 1, 2, 3, 4, 5],
        }),
      });
      final p = MzProgress(await SharedPreferences.getInstance());
      await tester.pumpWidget(MaterialApp(home: MzAlmanacScreen(progress: p)));
      await tester.pump(const Duration(milliseconds: 500));
      expect(
        tester
            .getSemantics(find.byKey(const ValueKey('almanac-cat-launcher')))
            .getSemanticsData()
            .hasAction(ui.SemanticsAction.tap),
        true,
      );
      final staticPaint = find.descendant(
        of: find.byKey(const ValueKey('almanac-static-cat-launcher')),
        matching: find.byType(CustomPaint),
      );
      final activePaint = find.descendant(
        of: find.byKey(const ValueKey('almanac-active-portrait')),
        matching: find.byType(CustomPaint),
      );
      final thumb = tester.widget<CustomPaint>(staticPaint).painter!;
      final hero = tester.widget<CustomPaint>(activePaint).painter!;
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        identical(thumb, tester.widget<CustomPaint>(staticPaint).painter),
        true,
      );
      expect(
        tester.widget<CustomPaint>(activePaint).painter!.shouldRepaint(hero),
        true,
      );
      for (final c in MzCat.values) {
        await selectCard(tester, 'cat-${c.name}');
        expect(
          tester
              .widget<Text>(find.byKey(const ValueKey('almanac-detail-name')))
              .data,
          mzCats[c]!.name,
        );
      }
      await tester.tap(find.byKey(const ValueKey('almanac-invaders')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      for (final e in MzEnemy.values) {
        await selectCard(tester, 'enemy-${e.name}');
        expect(
          tester
              .widget<Text>(find.byKey(const ValueKey('almanac-detail-name')))
              .data,
          e.label,
        );
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      semantics.dispose();
      disposed = true;
    },
  );
  testWidgets(
    'collection separates locked, equipped, available and ancestral cards',
    (tester) async {
      tester.view.physicalSize = const Size(960, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({
        MzProgress.key: jsonEncode({
          'stars': {for (var i = 0; i < 10; i++) '$i': 1},
          'deck': [0, 1, 2, 3, 4, 5],
          'mints': 65,
        }),
      });
      final p = MzProgress(await SharedPreferences.getInstance());
      final saved = p.prefs.getString(MzProgress.key);
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          home: MzAlmanacScreen(progress: p),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));
      expect(
        find.text('Colección · 8/11 gatos     Equipo guardado · 6/6'),
        findsOneWidget,
      );
      await selectCard(tester, 'cat-boomerang');
      expect(find.text('Bumerán').first, findsOneWidget);
      expect(
        find.textContaining('Completa Patio de Maru · 10 (misión 10)'),
        findsOneWidget,
      );
      expect(find.textContaining('Disponible para tu equipo.'), findsOneWidget);
      await captureState(tester, 'available');
      await selectCard(tester, 'cat-laser');
      expect(
        find.textContaining(
          'Completa Saloon de los Gatos Callejeros · 10 (misión 50)',
        ),
        findsOneWidget,
      );
      expect(
        find.text('10/50 misiones del recorrido completadas'),
        findsOneWidget,
      );
      expect(find.textContaining('Aún no puedes equiparlo.'), findsOneWidget);
      await captureState(tester, 'locked');
      await tester.ensureVisible(find.text('Cómo conseguir'));
      await tester.pump(const Duration(milliseconds: 400));
      await captureState(tester, 'locked-how');
      await selectCard(tester, 'lion');
      expect(find.text('Niveles de Patio, Egipto y Piratas: 10/30'), findsOneWidget);
      expect(find.text('Mentitas: 65/100'), findsOneWidget);
      expect(find.textContaining('gasta 100 mentitas'), findsOneWidget);
      await captureState(tester, 'ancestral');
      await tester.tap(find.byKey(const ValueKey('almanac-invaders')));
      await tester.pump(const Duration(milliseconds: 400));
      await selectCard(tester, 'enemy-pianist');
      expect(
        find.textContaining('Primera aparición: misión 41'),
        findsOneWidget,
      );
      expect(find.textContaining('cada 12 segundos'), findsOneWidget);
      await captureState(tester, 'invaders');
      expect(p.prefs.getString(MzProgress.key), saved);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'world filter describes acquisition and does not hide missing cards',
    (tester) async {
      tester.view.physicalSize = const Size(960, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      final p = MzProgress(await SharedPreferences.getInstance());
      await tester.pumpWidget(MaterialApp(home: MzAlmanacScreen(progress: p)));
      await tester.tap(
        find.widgetWithText(FilterChip, 'Reino del Gato Faraón'),
      );
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byKey(const ValueKey('almanac-cat-spring')), findsOneWidget);
      expect(find.byKey(const ValueKey('almanac-cat-boomerang')), findsNothing);
      await selectCard(tester, 'cat-spring');
      expect(
        find.textContaining('Completa Reino del Gato Faraón · 10 (misión 30)'),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'new-card celebration is acknowledged once without changing saved progress',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        MzProgress.key: jsonEncode({
          'stars': {'0': 1},
        }),
        MzAlmanacScreen.seenKey: ['cat-launcher'],
      });
      final p = MzProgress(await SharedPreferences.getInstance());
      final saved = p.prefs.getString(MzProgress.key);
      await tester.pumpWidget(MaterialApp(home: MzAlmanacScreen(progress: p)));
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('¡Carta nueva!'), findsOneWidget);
      expect(find.text('Girasol').first, findsOneWidget);
      await captureState(tester, 'new-card');
      expect(
        p.prefs.getStringList(MzAlmanacScreen.seenKey),
        contains('cat-sunflower'),
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(MaterialApp(home: MzAlmanacScreen(progress: p)));
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('¡Carta nueva!'), findsNothing);
      expect(p.prefs.getString(MzProgress.key), saved);
      await tester.pumpWidget(const SizedBox());
    },
  );
  for (final size in [const Size(320, 640), const Size(844, 390)]) {
    testWidgets(
      'collection fits $size with 180 percent text and reduced motion',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        SharedPreferences.setMockInitialValues({
          MzProgress.key: jsonEncode({'reduced': true}),
        });
        final p = MzProgress(await SharedPreferences.getInstance());
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(
                size: size,
                textScaler: const TextScaler.linear(1.8),
                disableAnimations: true,
              ),
              child: MzAlmanacScreen(progress: p),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await selectCard(tester, 'cat-laser');
        expect(tester.takeException(), isNull);
        await tester.pumpAndSettle();
        await captureState(tester, 'accessible-${size.width.toInt()}');
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
  setUpAll(() async {
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
    if (!const bool.fromEnvironment('RENDER_MZ')) return;
    await (FontLoader('Roboto')..addFont(
          Future.value(
            ByteData.sublistView(
              File(
                'C:/src/flutter/bin/cache/artifacts/material_fonts/roboto-regular.ttf',
              ).readAsBytesSync(),
            ),
          ),
        ))
        .load();
    await (FontLoader('MaterialIcons')..addFont(
          Future.value(
            ByteData.sublistView(
              File(
                'C:/src/flutter/bin/cache/artifacts/material_fonts/materialicons-regular.otf',
              ).readAsBytesSync(),
            ),
          ),
        ))
        .load();
  });
  for (final size in [
    const Size(390, 844),
    const Size(960, 540),
    const Size(1440, 900),
  ]) {
    testWidgets('almanac opens and closes at $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({
        if (const bool.fromEnvironment('REDUCED_ALMANAC'))
          MzProgress.key: jsonEncode({'reduced': true}),
      });
      final store = GameStore(await SharedPreferences.getInstance());
      await tester.pumpWidget(
        RepaintBoundary(
          key: const ValueKey('almanac-capture'),
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            home: MarusZombiesScreen(store: store),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Almanaque'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Almanaque de los michis'), findsOneWidget);
      expect(tester.takeException(), isNull);
      if (const bool.fromEnvironment('RENDER_MZ')) {
        await tester.runAsync(() async {
          final image = await tester
              .renderObject<RenderRepaintBoundary>(
                find.byKey(const ValueKey('almanac-capture')),
              )
              .toImage(pixelRatio: 2);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          File(
              'build/previews/mz-almanac-${const String.fromEnvironment('ART_PHASE', defaultValue: 'after')}-${size.width.toInt()}.png',
            )
            ..parent.createSync(recursive: true)
            ..writeAsBytesSync(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
      if (size.width == 960 && const bool.fromEnvironment('PROFILE_ALMANAC')) {
        for (var i = 0; i < 20; i++) {
          await tester.pump(const Duration(milliseconds: 16));
        }
        final samples = <double>[];
        for (var batch = 0; batch < 5; batch++) {
          final watch = Stopwatch()..start();
          for (var i = 0; i < 50; i++) {
            await tester.pump(const Duration(milliseconds: 16));
          }
          watch.stop();
          samples.add(watch.elapsedMicroseconds / 50000);
        }
        samples.sort();
        final data = {
          'medianPumpMs': samples[2],
          'samplesMs': samples,
          'scope': 'Flutter widget-test pump CPU; excludes real GPU/device FPS',
        };
        File(
            'build/previews/mz-almanac-profile-${const String.fromEnvironment('ART_PHASE', defaultValue: 'after')}.json',
          )
          ..parent.createSync(recursive: true)
          ..writeAsStringSync(jsonEncode(data));
      }
      Navigator.of(tester.element(find.text('Almanaque de los michis'))).pop();
      await tester.pumpAndSettle();
      expect(find.byTooltip('Almanaque'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      store.dispose();
    });
  }
}

Future<void> selectCard(WidgetTester tester, String id) async {
  final f = find.byKey(ValueKey('almanac-$id'));
  final scroll = find
      .descendant(
        of: find.byType(CustomScrollView).first,
        matching: find.byType(Scrollable),
      )
      .first;
  await tester.scrollUntilVisible(f, 180, scrollable: scroll);
  await tester.ensureVisible(f);
  await tester.pump();
  await tester.tap(f);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 450));
}

Future<void> captureState(WidgetTester tester, String name) async {
  if (!const bool.fromEnvironment('RENDER_MZ')) return;
  await tester.runAsync(() async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byType(RepaintBoundary).first,
    );
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    File('build/previews/mz-almanac-$name.png')
      ..parent.createSync(recursive: true)
      ..writeAsBytesSync(bytes!.buffer.asUint8List());
    image.dispose();
  });
}
