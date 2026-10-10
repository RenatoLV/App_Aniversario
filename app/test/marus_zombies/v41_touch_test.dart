import 'dart:io';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nuestro_rincon/marus_zombies/mz_catalog.dart';
import 'package:nuestro_rincon/marus_zombies/mz_game_screen.dart';
import 'package:nuestro_rincon/marus_zombies/mz_field_guide.dart';
import 'package:nuestro_rincon/marus_zombies/mz_levels.dart';
import 'package:nuestro_rincon/marus_zombies/mz_models.dart';
import 'package:nuestro_rincon/marus_zombies/mz_painter.dart';
import 'package:nuestro_rincon/marus_zombies/mz_progress.dart';
import 'package:nuestro_rincon/marus_zombies/mz_simulation.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    if (!const bool.fromEnvironment('RENDER_V41')) return;
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
  Future<MzProgress> mount(WidgetTester t, MzSimulation s, Size size) async {
    t.view.physicalSize = size;
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final p = MzProgress(await SharedPreferences.getInstance());
    await t.pumpWidget(
      RepaintBoundary(
        key: const ValueKey('capture-v41'),
        child: MaterialApp(
          home: MzGameScreen(sim: s, progress: p),
        ),
      ),
    );
    await t.pump();
    return p;
  }

  Offset point(WidgetTester t, double x, [int row = 2]) {
    final b = find.byKey(const ValueKey('mz-board'));
    return t.getTopLeft(b) + MzBoardGeometry(t.getSize(b)).point(row, x);
  }

  Future<void> capture(WidgetTester t, String name) async {
    if (!const bool.fromEnvironment('RENDER_V41')) return;
    await t.runAsync(() async {
      final image = await t
          .renderObject<RenderRepaintBoundary>(
            find.byKey(const ValueKey('capture-v41')),
          )
          .toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('build/previews/mz-v41-$name.png')
        ..parent.createSync(recursive: true);
      file.writeAsBytesSync(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  testWidgets(
    'explicit tuna targets the cat instead of an overlapping pickup',
    (t) async {
      final s = MzSimulation(const MzLevel(8))..tuna = 1;
      s.defenders.add(MzDefender(100, MzCat.launcher, 2, 2));
      s.pickups.add(MzPickup(101, 2, 2.5));
      await mount(t, s, const Size(844, 390));
      await t.tap(find.byTooltip('Atún 1/3'));
      await t.pump();
      await t.tapAt(point(t, 2.5));
      await t.pump();
      expect(s.tuna, 0);
      expect(s.at(2, 2)!.burstLeft, 60);
      expect(s.pickups.any((p) => p.id == 101), true);
      await t.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'portrait tuna and shovel require confirmation and cancel is harmless',
    (t) async {
      final s = MzSimulation(const MzLevel(8))..tuna = 1;
      s.defenders.add(MzDefender(100, MzCat.launcher, 2, 2));
      s.pickups.add(MzPickup(101, 2, 2.5));
      await mount(t, s, const Size(320, 568));
      await t.tap(find.byTooltip('Atún 1/3'));
      await t.pump();
      await t.tapAt(point(t, 2.5));
      await t.pump();
      expect(s.tuna, 1);
      expect(find.text('Potenciar'), findsOneWidget);
      await capture(t, 'tuna-confirm');
      await t.tap(find.text('Cancelar'));
      await t.pump();
      expect(s.tuna, 1);
      await t.tapAt(point(t, 2.5));
      await t.pump();
      await t.tap(find.text('Potenciar'));
      await t.pump();
      expect(s.tuna, 0);
      await t.tap(find.byTooltip('Pala'));
      await t.pump();
      await t.tapAt(point(t, 2.5));
      await t.pump();
      expect(s.at(2, 2), isNotNull);
      await t.tap(find.text('Retirar'));
      await t.pump();
      expect(s.at(2, 2), isNull);
      expect(s.pickups.any((p) => p.id == 101), true);
      await t.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'nearest resources do not overlap tools and empty taps do not offer placement',
    (t) async {
      final s = MzSimulation(const MzLevel(8));
      s.defenders.add(MzDefender(100, MzCat.launcher, 2, 2));
      s.pickups.addAll([MzPickup(101, 2, 2.5), MzPickup(102, 2, 2.8)]);
      await mount(t, s, const Size(844, 390));
      final b = find.byKey(const ValueKey('mz-board'));
      final g = MzBoardGeometry(t.getSize(b)), origin = t.getTopLeft(b);
      final balance = s.catnip;
      await t.tapAt(origin + g.point(2, 2.8).translate(0, -g.ch * .14));
      await t.pump();
      expect(s.pickups.map((p) => p.id), [101]);
      expect(s.catnip, balance + 25);
      await t.tapAt(origin + g.point(2, 2.5).translate(0, -g.ch * .14));
      await t.pump();
      expect(s.pickups, isEmpty);
      expect(s.catnip, balance + 50);
      await t.tapAt(point(t, 7.5));
      await t.pump();
      expect(find.text('Colocar'), findsNothing);
      await t.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'failed tuna and cancelled/outside drag spend nothing; pause blocks touches',
    (t) async {
      final s = MzSimulation(const MzLevel(8))..tuna = 1;
      s.defenders.add(MzDefender(100, MzCat.bomb, 2, 2)..age = -.5);
      final p = await mount(t, s, const Size(844, 390));
      await t.tap(find.byTooltip('Atún 1/3'));
      await t.pump();
      await t.tapAt(point(t, 2.5));
      await t.pump();
      expect(s.tuna, 1);
      expect(s.notice, contains('explota solo'));
      final balance = s.catnip, count = s.defenders.length;
      final card = find.byKey(const ValueKey('mz-card-launcher'));
      final gesture = await t.startGesture(t.getCenter(card));
      await gesture.moveBy(const Offset(30, 0));
      await t.pump();
      await gesture.cancel();
      await t.pump();
      expect(s.catnip, balance);
      expect(s.defenders.length, count);
      final outside = await t.startGesture(t.getCenter(card));
      await outside.moveBy(const Offset(30, 0));
      await t.pump();
      await outside.moveTo(const Offset(5, 5));
      await outside.up();
      await t.pump();
      expect(s.catnip, balance);
      expect(s.defenders.length, count);
      await t.tap(find.byTooltip('Pausar'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 30));
      final checkpoint = p.resume()!.toJson();
      await t.tapAt(point(t, 5.5));
      await t.pump();
      expect(p.resume()!.toJson(), checkpoint);
      expect(s.catnip, balance);
      await t.ensureVisible(find.text('Continuar'));
      await t.tap(find.text('Continuar'));
      await t.pump();
      expect(s.paused, false);
      await t.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'capture overlapping-resource interaction and optional help',
    (t) async {
      final creation = <double>[];
      final clock = Stopwatch()..start();
      final s = MzSimulation(const MzLevel(8))..tuna = 1;
      s.defenders.add(MzDefender(100, MzCat.launcher, 2, 2));
      s.pickups.add(MzPickup(101, 2, 2.5));
      await mount(t, s, const Size(844, 390));
      creation.add(clock.elapsedMicroseconds / 1000);
      await t.tap(find.byTooltip('Atún 1/3'));
      await t.pump();
      await t.tapAt(point(t, 2.5));
      await t.pump();
      await capture(
        t,
        '${const String.fromEnvironment('CAPTURE_PHASE', defaultValue: 'after')}-interaction',
      );
      await t.tap(find.byTooltip('Pausar'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 30));
      final help = find.text('Cómo jugar');
      if (help.evaluate().isNotEmpty) {
        await t.ensureVisible(help);
        await t.tap(help);
        await t.pump();
        await t.pump(const Duration(milliseconds: 300));
        await capture(t, 'help');
      }
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
      for (var i = 0; i < 4; i++) {
        clock
          ..reset()
          ..start();
        await mount(t, MzSimulation(const MzLevel(8)), const Size(844, 390));
        creation.add(clock.elapsedMicroseconds / 1000);
        await t.pumpWidget(const SizedBox());
      }
      final file = File(
        'build/previews/mz-v41-ui-${const String.fromEnvironment('CAPTURE_PHASE', defaultValue: 'after')}.json',
      );
      file.writeAsStringSync(
        jsonEncode({
          'creationWallMs': creation,
          'scope':
              'Debug WidgetTester wall-time to create a screen and pump; five separate mounts, excludes physical-device/native audio measurement',
        }),
      );
    },
    skip: !const bool.fromEnvironment('RENDER_V41'),
  );

  for (final size in [
    const Size(320, 568),
    const Size(360, 800),
    const Size(390, 844),
    const Size(640, 360),
    const Size(844, 390),
    const Size(1280, 800),
  ]) {
    testWidgets('finger actions, orientation, pause and enlarged text at $size', (
      t,
    ) async {
      final s = MzSimulation(const MzLevel(8))..catnip = 500;
      final p = await mount(t, s, size);
      await p.configure(reduced: true);
      // Apply enlarged text through the application's MediaQuery, not a painter mock.
      await t.pumpWidget(
        RepaintBoundary(
          key: const ValueKey('capture-v41'),
          child: MaterialApp(
            builder: (c, child) => MediaQuery(
              data: MediaQuery.of(
                c,
              ).copyWith(textScaler: const TextScaler.linear(1.5)),
              child: child!,
            ),
            home: MzGameScreen(sim: s, progress: p),
          ),
        ),
      );
      await t.pump();
      final pause = find.byTooltip('Pausar');
      expect(t.getSize(pause).width, greaterThanOrEqualTo(48));
      expect(t.getSize(pause).height, greaterThanOrEqualTo(48));
      await t.tap(find.byKey(const ValueKey('mz-card-launcher')));
      await t.pump();
      await t.tapAt(point(t, 1.5));
      await t.pump();
      if (size.width < 600) {
        await t.tap(find.text('Colocar'));
        await t.pump();
      }
      expect(s.at(2, 1)?.kind, MzCat.launcher);
      final count = s.defenders.length, balance = s.catnip;
      await t.tapAt(point(t, 1.5));
      await t.pump();
      if (size.width < 600) {
        await t.tap(find.text('Colocar'));
        await t.pump();
      }
      expect(s.defenders.length, count);
      expect(s.catnip, balance);
      await t.tap(find.byKey(const ValueKey('mz-speed')));
      await t.pump();
      expect(find.text('x2'), findsOneWidget);
      await t.tap(pause);
      await t.pump();
      await t.pump(const Duration(milliseconds: 30));
      final time = s.time;
      await t.pump(const Duration(seconds: 2));
      expect(s.time, time);
      expect(p.resume(), isNotNull);
      await t.ensureVisible(find.text('Continuar'));
      await t.tap(find.text('Continuar'));
      await t.pump();
      expect(s.paused, false);
      t.view.physicalSize = Size(size.height, size.width);
      await t.pump();
      expect(t.takeException(), isNull);
      await capture(t, 'hud-${size.width.toInt()}');
      await t.pumpWidget(const SizedBox());
    });
  }

  testWidgets(
    'optional world help expands and collapses with large text and compact layouts',
    (t) async {
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetDevicePixelRatio);
      addTearDown(t.view.resetPhysicalSize);
      for (final size in [const Size(320, 568), const Size(640, 360)]) {
        t.view.physicalSize = size;
        for (final id in [0, 50, 10, 20, 30, 40]) {
          final level = MzLevel(id);
          await t.pumpWidget(
            MaterialApp(
              builder: (c, child) => MediaQuery(
                data: MediaQuery.of(
                  c,
                ).copyWith(textScaler: const TextScaler.linear(1.5)),
                child: child!,
              ),
              home: Scaffold(
                body: SingleChildScrollView(child: MzFieldGuide(level: level)),
              ),
            ),
          );
          await t.pump();
          await t.tap(find.text('Cómo jugar'));
          await t.pump();
          await t.pump(const Duration(milliseconds: 300));
          expect(find.text(level.world.rule), findsOneWidget);
          await t.ensureVisible(find.text(level.world.rule));
          await t.pump();
          await t.ensureVisible(find.text('Cómo jugar'));
          await t.tap(find.text('Cómo jugar'));
          await t.pump();
          await t.pump(const Duration(milliseconds: 300));
          expect(find.text(level.world.rule), findsNothing);
          expect(t.takeException(), isNull);
          await t.pumpWidget(const SizedBox());
        }
      }
    },
  );
}
