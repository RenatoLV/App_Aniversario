import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nuestro_rincon/house_day_cycle.dart';
import 'package:nuestro_rincon/cat_room.dart';

Future<void> capture(WidgetTester tester, GlobalKey key, String name) async {
  if (Platform.environment['CAPTURE_HOUSE_CYCLE'] != '1') return;
  await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('build/qa/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(data!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  setUpAll(() async {
    if (Platform.environment['CAPTURE_HOUSE_CYCLE'] != '1') return;
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

  test('Local day cycle crosses sunrise, sunset and midnight smoothly', () {
    HouseLight at(int hour, [int minute = 0]) =>
        HouseLight.at(DateTime(2026, 10, 3, hour, minute));
    expect(at(0).period, HousePeriod.night);
    expect(at(5, 29).period, HousePeriod.night);
    expect(at(5, 30).period, HousePeriod.dawn);
    expect(at(6, 15).daylight, closeTo(.5, .001));
    expect(at(7).period, HousePeriod.day);
    expect(at(12).daylight, 1);
    expect(at(17).period, HousePeriod.dusk);
    expect(at(18).daylight, closeTo(.5, .001));
    expect(at(19).period, HousePeriod.night);
    expect(at(23, 59).wallTop, at(0).wallTop);
    for (final boundary in [330, 420, 1020, 1140]) {
      final before = at((boundary - 1) ~/ 60, (boundary - 1) % 60);
      final after = at(boundary ~/ 60, boundary % 60);
      expect((before.daylight - after.daylight).abs(), lessThan(.002));
    }
  });

  testWidgets(
    'Open house follows time and rechecks after returning to the app',
    (tester) async {
      var now = DateTime(2026, 10, 3, 16, 59);
      HouseLight? rendered;
      await tester.pumpWidget(
        MaterialApp(
          home: HouseDayCycle(
            clock: () => now,
            builder: (context, light) {
              rendered = light;
              return Text(light.label);
            },
          ),
        ),
      );
      expect(find.text('Día'), findsOneWidget);
      now = DateTime(2026, 10, 3, 18);
      await tester.pump(const Duration(minutes: 1));
      // The previous light transitions rather than switching abruptly.
      await tester.pump(const Duration(milliseconds: 450));
      expect(rendered!.daylight, greaterThan(.5));
      expect(rendered!.daylight, lessThan(1));
      await tester.pump(const Duration(milliseconds: 500));
      expect(rendered!.daylight, closeTo(.5, .001));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      now = DateTime(2026, 10, 4, 1);
      await tester.pump(const Duration(hours: 4));
      expect(find.text('Atardecer'), findsOneWidget);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Noche'), findsOneWidget);
      expect(rendered!.daylight, 0);
      // A phone timezone/manual clock change is also picked up while open.
      now = DateTime(2026, 10, 4, 10);
      await tester.pump(const Duration(minutes: 1));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Día'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('Both cats stay visible in day and night house scenes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var now = DateTime(2026, 10, 3, 12);
    final boundary = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: MaterialApp(
          home: Scaffold(
            backgroundColor: const Color(0xfffaf7ef),
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: CatRoom(clock: () => now),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Día'), findsOneWidget);
    await capture(tester, boundary, 'casita-dia');
    now = DateTime(2026, 10, 3, 23);
    await tester.pump(const Duration(minutes: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Noche'), findsOneWidget);
    await capture(tester, boundary, 'casita-noche');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
