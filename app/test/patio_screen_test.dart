import 'dart:convert';
import 'dart:ui' as ui;
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:nuestro_rincon/home.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nuestro_rincon/cat_character.dart';
import 'package:nuestro_rincon/cat_bedroom.dart';
import 'package:nuestro_rincon/football_game.dart';
import 'package:nuestro_rincon/football_screen.dart';
import 'package:nuestro_rincon/patio_screen.dart';
import 'package:nuestro_rincon/patio_weather.dart';
import 'package:nuestro_rincon/store.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    if (!const bool.fromEnvironment('RENDER_PATIO')) return;
    final root = Platform.environment['FLUTTER_ROOT'] ?? 'C:/src/flutter';
    for (final entry in {
      'Roboto': 'roboto-regular.ttf',
      'MaterialIcons': 'materialicons-regular.otf',
    }.entries) {
      final loader = FontLoader(entry.key)
        ..addFont(
          Future.value(
            ByteData.sublistView(
              File(
                '$root/bin/cache/artifacts/material_fonts/${entry.value}',
              ).readAsBytesSync(),
            ),
          ),
        );
      await loader.load();
    }
  });
  Future<({GameStore store, PatioWeather weather})> fixture() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final store = GameStore(prefs);
    final weather = PatioWeather(
      prefs,
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'current': {
              'weather_code': 2,
              'temperature_2m': 17,
              'wind_speed_10m': 8,
            },
          }),
          200,
        ),
      ),
    );
    await weather.refresh();
    return (store: store, weather: weather);
  }

  Future<void> capture(WidgetTester tester, String name) async {
    if (!const bool.fromEnvironment('RENDER_PATIO')) return;
    await tester.runAsync(() async {
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const ValueKey('preview')),
      );
      final image = await boundary.toImage(pixelRatio: 2);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('build/previews/$name.png');
      file.parent.createSync(recursive: true);
      file.writeAsBytesSync(png!.buffer.asUint8List());
      image.dispose();
    });
  }

  testWidgets('Patio game card opens Marus vs Zombies campaign', (
    tester,
  ) async {
    final f = await fixture();
    await tester.pumpWidget(
      MaterialApp(
        home: PatioScreen(store: f.store, weather: f.weather),
      ),
    );
    await tester.pump();
    final entry = find.byKey(const ValueKey('patio-marus-zombies'));
    await tester.scrollUntilVisible(entry, 240);
    await tester.tap(entry);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Marus vs Zombies'), findsOneWidget);
    expect(find.text('¡Que nadie toque\nla casa de Maru!'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    f.weather.dispose();
    f.store.dispose();
  });

  for (final width in [320.0, 390.0]) {
    testWidgets(
      'Patio and touch football fit a $width phone and goals pay only once',
      (tester) async {
        tester.view.physicalSize = Size(width, width == 320 ? 568 : 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final f = await fixture();
        await tester.pumpWidget(
          RepaintBoundary(
            key: const ValueKey('preview'),
            child: MaterialApp(
              home: PatioScreen(
                store: f.store,
                weather: f.weather,
                clock: () => DateTime(2026, 10, 7, 18),
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 1200));
        await capture(tester, 'patio-${width.toInt()}');
        await Scrollable.ensureVisible(
          tester.element(find.byKey(const ValueKey('patio-football'))),
        );
        await tester.pump();
        await tester.tap(find.byKey(const ValueKey('patio-football')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.byType(FootballScreen), findsOneWidget);
        expect(tester.takeException(), isNull);
        final field = tester.getRect(find.byKey(const ValueKey('goal-field')));
        Offset at(Offset world) =>
            field.topLeft +
            Offset(
              world.dx / FootballGame.width * field.width,
              world.dy / FootballGame.height * field.height,
            );
        final before = f.store.coins;
        final gesture = await tester.startGesture(at(FootballGame.origin));
        await tester.pump(const Duration(milliseconds: 60));
        await gesture.moveTo(at(const Offset(145, 250)));
        await tester.pump(const Duration(milliseconds: 60));
        await gesture.up();
        for (var n = 0; n < 60; n++) {
          await tester.pump(const Duration(milliseconds: 16));
        }
        expect(f.store.coins, before + 30);
        expect(find.text('1 gol'), findsOneWidget);
        await capture(tester, 'goal-${width.toInt()}');
        for (var n = 0; n < 100; n++) {
          await tester.pump(const Duration(milliseconds: 16));
        }
        expect(f.store.coins, before + 30);
        final cancelled = await tester.startGesture(at(FootballGame.origin));
        await tester.pump(const Duration(milliseconds: 60));
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        await cancelled.moveTo(at(const Offset(145, 250)));
        await cancelled.up();
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        for (var n = 0; n < 60; n++) {
          await tester.pump(const Duration(milliseconds: 16));
        }
        expect(f.store.coins, before + 30);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await f.store.save();
        f.store.dispose();
        f.weather.dispose();
      },
    );
  }
  testWidgets(
    'Main menu door opens the patio once; daylight scenes update on resume',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final f = await fixture();
      await tester.pumpWidget(
        RepaintBoundary(
          key: const ValueKey('preview'),
          child: RinconApp(store: f.store),
        ),
      );
      final door = find.byKey(const ValueKey('home-patio-door'));
      await Scrollable.ensureVisible(tester.element(door));
      await tester.pump();
      await capture(tester, 'home-patio-door');
      await tester.tap(door);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(PatioScreen), findsOneWidget);
      expect(find.byType(FootballScreen), findsNothing);
      await tester.pumpWidget(const SizedBox());
      var hour = 12;
      await tester.pumpWidget(
        RepaintBoundary(
          key: const ValueKey('preview'),
          child: MaterialApp(
            home: PatioScreen(
              store: f.store,
              weather: f.weather,
              clock: () => DateTime(2026, 10, 7, hour),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 1200));
      await capture(tester, 'patio-day');
      hour = 22;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1000));
      await capture(tester, 'patio-night');
      expect(find.textContaining('Noche'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await f.store.save();
      f.store.dispose();
      f.weather.dispose();
    },
  );
  testWidgets('Bedroom light visibly sleeps and wakes the cat', (tester) async {
    final f = await fixture();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AnimatedBuilder(
            animation: f.store.catCare,
            builder: (context, _) =>
                CatBedroomScene(store: f.store, cat: CatKind.maru),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('bedroom-light-toggle')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    expect(f.store.catCare.resting(CatKind.maru), isTrue);
    expect(tester.widget<CatActor>(find.byType(CatActor)).sleeping, isTrue);
    expect(find.text('Encender luz'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('bedroom-light-toggle')));
    await tester.pump();
    expect(f.store.catCare.resting(CatKind.maru), isFalse);
    await tester.pumpWidget(const SizedBox());
    await f.store.save();
    f.store.dispose();
    f.weather.dispose();
  });
}
