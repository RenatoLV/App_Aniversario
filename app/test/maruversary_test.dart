import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nuestro_rincon/cat_room.dart';
import 'package:nuestro_rincon/maruversary.dart';
import 'package:nuestro_rincon/store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('gift pays 1200 once, updates button and survives reopening', (
    t,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final store = GameStore(prefs);
    final original = store.coins;
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: MaruversaryWelcome(store: store)),
        ),
      ),
    );
    final button = find.byKey(const ValueKey('maruversary-claim-gift'));
    await t.ensureVisible(button);
    await t.tap(button);
    await store.claimMaruversaryGift();
    await store.claimMaruversaryGift();
    await t.pump();
    expect(store.coins, original + 1200);
    expect(store.maruversaryGiftClaimed, isTrue);
    expect(t.widget<FilledButton>(button).onPressed, isNull);
    final restored = GameStore(prefs);
    await restored.claimMaruversaryGift();
    expect(restored.coins, original + 1200);
    expect(restored.maruversaryGiftClaimed, isTrue);
    expect(restored.cloud.snapshot(), contains(GameStore.maruversaryGiftId));
    await t.pumpWidget(const SizedBox());
    restored.dispose();
    store.dispose();
  });

  testWidgets('menu replay restarts balloons while preserving the child', (
    t,
  ) async {
    var taps = 0;
    await t.pumpWidget(
      MaterialApp(
        home: MaruversaryEntrance(
          child: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () {
                  taps++;
                  MaruversaryEntrance.replay(context);
                },
                child: const Text('Cambiar menú'),
              ),
            ),
          ),
        ),
      ),
    );
    final balloons = find.byKey(
      const ValueKey('maruversary-entrance-balloons'),
    );
    await t.pump(const Duration(seconds: 8));
    expect(balloons, findsNothing);
    await t.tap(find.text('Cambiar menú'));
    await t.pump();
    expect(balloons, findsOneWidget);
    expect(
      (t.widget<CustomPaint>(balloons).painter as AnniversaryCelebrationPainter)
          .variant,
      1,
    );
    await t.pump(const Duration(seconds: 2));
    await t.tap(find.text('Cambiar menú'));
    await t.pump();
    await t.pump(const Duration(seconds: 6));
    expect(balloons, findsOneWidget);
    await t.pump(const Duration(seconds: 2));
    expect(balloons, findsNothing);
    expect(taps, 2);
    for (final variant in [3, 4, 5, 0]) {
      await t.tap(find.text('Cambiar menú'));
      await t.pump();
      expect(
        (t.widget<CustomPaint>(balloons).painter
                as AnniversaryCelebrationPainter)
            .variant,
        variant,
      );
      await t.pump(const Duration(seconds: 8));
      expect(balloons, findsNothing);
    }
    await t.pumpWidget(const SizedBox());
  });
  testWidgets('entrance balloons allow taps and finish without replaying', (
    t,
  ) async {
    var taps = 0;
    Widget app({bool reduced = false}) => MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduced),
        child: MaruversaryEntrance(
          child: Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => taps++,
                child: const Text('Entrar'),
              ),
            ),
          ),
        ),
      ),
    );
    await t.pumpWidget(app());
    final balloons = find.byKey(
      const ValueKey('maruversary-entrance-balloons'),
    );
    expect(balloons, findsOneWidget);
    await t.pump(const Duration(seconds: 2));
    await t.tap(find.text('Entrar'));
    expect(taps, 1);
    await t.pump(const Duration(seconds: 6));
    expect(balloons, findsNothing);
    await t.pumpWidget(app());
    expect(balloons, findsNothing);
    await t.pumpWidget(const SizedBox());
    await t.pumpWidget(app(reduced: true));
    expect(balloons, findsNothing);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
  });

  test(
    'every monthly 21, including year changes, uses local calendar date',
    () {
      for (var month = 1; month <= 12; month++) {
        expect(isMaruversary(DateTime(2026, month, 20, 23, 59)), false);
        expect(isMaruversary(DateTime(2026, month, 21)), true);
        expect(isMaruversary(DateTime(2026, month, 21, 23, 59)), true);
        expect(isMaruversary(DateTime(2026, month, 22)), false);
      }
      expect(isMaruversary(DateTime(2027, 1, 21)), true);
    },
  );

  testWidgets('welcome changes at midnight and when resuming the app', (
    t,
  ) async {
    var now = DateTime(2026, 10, 20, 23, 59, 59);
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MaruversaryDay(
            clock: () => now,
            builder: (_, celebrating) => celebrating
                ? const MaruversaryWelcome()
                : const SizedBox.shrink(),
          ),
        ),
      ),
    );
    expect(find.text('¡Feliz maruversario!'), findsNothing);
    now = DateTime(2026, 10, 21);
    await t.pump(const Duration(seconds: 1));
    expect(find.text('¡Feliz maruversario!'), findsOneWidget);
    await t.pump(const Duration(seconds: 6));
    expect(find.text('¡Feliz maruversario!'), findsOneWidget);
    now = DateTime(2026, 10, 22);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await t.pump();
    expect(find.text('¡Feliz maruversario!'), findsNothing);
    now = DateTime(2026, 11, 21);
    await t.pump(const Duration(minutes: 1));
    expect(find.text('¡Feliz maruversario!'), findsOneWidget);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('cake stays across cat activities and disappears on the 22nd', (
    t,
  ) async {
    var now = DateTime(2026, 10, 21, 23, 58);
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(body: CatRoom(clock: () => now)),
      ),
    );
    expect(find.byType(MaruversaryCake), findsOneWidget);
    final cakePosition = t.widget<Positioned>(
      find
          .ancestor(
            of: find.byType(MaruversaryCake),
            matching: find.byType(Positioned),
          )
          .first,
    );
    expect(cakePosition.bottom, 6);
    final layers = t
        .widget<Stack>(
          find
              .ancestor(
                of: find.byType(MaruversaryCake),
                matching: find.byType(Stack),
              )
              .first,
        )
        .children;
    expect(
      layers.indexOf(cakePosition),
      lessThan(layers.indexWhere((w) => w is AnimatedPositioned)),
    );
    for (var i = 0; i < 10; i++) {
      await t.pump(const Duration(seconds: 17));
      expect(find.byType(MaruversaryCake), findsOneWidget);
      expect(t.takeException(), isNull);
    }
    now = DateTime(2026, 10, 22);
    await t.pump(const Duration(minutes: 1));
    expect(find.byType(MaruversaryCake), findsNothing);
    await t.pumpWidget(const SizedBox());
  });

  for (final (width, height, scale) in [
    (390.0, 844.0, 1.0),
    (320.0, 640.0, 2.0),
    (844.0, 390.0, 1.0),
  ]) {
    testWidgets('celebration fits $width x $height at text scale $scale', (
      t,
    ) async {
      t.view.physicalSize = Size(width, height);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final capture = Platform.environment['CAPTURE_MARUVERSARY'] == '1';
      if (capture) {
        for (final (family, path) in [
          (
            'Roboto',
            'C:/src/flutter/bin/cache/artifacts/material_fonts/roboto-regular.ttf',
          ),
          (
            'MaterialIcons',
            'C:/src/flutter/bin/cache/artifacts/material_fonts/materialicons-regular.otf',
          ),
          ('Fredoka', 'assets/fonts/Fredoka.ttf'),
          ('Nunito', 'assets/fonts/Nunito.ttf'),
        ]) {
          await (FontLoader(family)..addFont(
                Future.value(
                  ByteData.sublistView(File(path).readAsBytesSync()),
                ),
              ))
              .load();
        }
      }
      final key = GlobalKey();
      SharedPreferences.setMockInitialValues({});
      final visualStore = GameStore(await SharedPreferences.getInstance());
      await t.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: Size(width, height),
              textScaler: TextScaler.linear(scale),
              disableAnimations: true,
            ),
            child: RepaintBoundary(
              key: key,
              child: Scaffold(
                backgroundColor: const Color(0xfffaf6ee),
                body: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    MaruversaryWelcome(store: visualStore),
                    CatRoom(
                      clock: () => DateTime(2026, 10, 21, 12),
                      onOpenPatio: () {},
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await t.pump(const Duration(milliseconds: 100));
      if (scale > 1) {
        await t.scrollUntilVisible(find.byType(MaruversaryCake), 200);
        await t.pump();
      }
      expect(find.byType(MaruversaryCake), findsOneWidget);
      expect(t.takeException(), isNull);
      if (capture && scale == 1) {
        await t.runAsync(() async {
          final boundary =
              key.currentContext!.findRenderObject() as RenderRepaintBoundary;
          final image = await boundary.toImage(pixelRatio: 2);
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          final file = File('build/qa/maruversary-${width.toInt()}.png');
          await file.parent.create(recursive: true);
          await file.writeAsBytes(data!.buffer.asUint8List());
          image.dispose();
        });
      }
      await t.pumpWidget(const SizedBox());
      visualStore.dispose();
    });
  }
}
