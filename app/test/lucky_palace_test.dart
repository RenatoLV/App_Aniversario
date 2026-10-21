import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nuestro_rincon/lucky_palace/lucky_palace_screen.dart';
import 'package:nuestro_rincon/lucky_palace/art/lucky_symbol_art.dart';
import 'package:nuestro_rincon/lucky_palace/lucky_demo.dart';

const _capture = String.fromEnvironment('LUCKY_CAPTURE');
const _art = ValueKey('lucky-capture');

Future<void> _snapshot(WidgetTester tester, String name) async {
  if (_capture.isEmpty) return;
  final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(_art));
  await tester.runAsync(() async {
    final image = await boundary.toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final folder = Directory(_capture);
    folder.createSync(recursive: true);
    File(
      '${folder.path}/$name.png',
    ).writeAsBytesSync(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    for (final family in ['Fredoka', 'Nunito']) {
      await (FontLoader(
        family,
      )..addFont(rootBundle.load('assets/fonts/$family.ttf'))).load();
    }
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  for (final entry in [
    (const Size(360, 640), 1.0, 'small'),
    (const Size(390, 844), 1.0, 'portrait'),
    (const Size(844, 390), 1.0, 'landscape'),
    (const Size(1440, 900), 1.0, 'desktop'),
    (const Size(360, 640), 2.0, 'large-text'),
    (const Size(844, 390), 2.0, 'landscape-large-text'),
  ]) {
    testWidgets('artwork and gallery fit ${entry.$3}', (tester) async {
      tester.view.physicalSize = entry.$1;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(entry.$2),
              disableAnimations: true,
            ),
            child: child!,
          ),
          home: const RepaintBoundary(
            key: _art,
            child: LuckyPalaceScreen(
              enableDeveloperTools: true,
              initialMode: LuckyPlayMode.demo,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final explore = find.text('Explorar símbolos');
      expect(explore, findsOneWidget);
      expect(
        tester.getRect(explore).bottom,
        lessThanOrEqualTo(entry.$1.height),
      );
      await _snapshot(tester, 'cabinet-${entry.$3}');
      final spin = find.byKey(const ValueKey('lucky-spin'));
      expect(
        tester.getRect(spin).bottom,
        lessThanOrEqualTo(entry.$1.height - 48),
      );
      expect(tester.getSize(spin).height, greaterThanOrEqualTo(68));
      await tester.tap(spin);
      await tester.pumpAndSettle();
      expect(find.text('DEMO · Sin premio'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(explore);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(LuckySymbolArt), findsWidgets);
      await _snapshot(tester, 'symbols-${entry.$3}');
      final fish = find.byKey(const ValueKey('lucky-symbol-fish'));
      await tester.ensureVisible(fish);
      await tester.tap(fish);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is LuckySymbolArt &&
              widget.symbol == LuckySymbol.fish &&
              widget.size == 128,
        ),
        findsOneWidget,
      );
      expect(find.text('32 dp'), findsOneWidget);
      final ivory = find.byKey(const ValueKey('lucky-background-Marfil'));
      await tester.ensureVisible(ivory);
      await tester.tap(ivory);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final actualCell = find.byKey(const ValueKey('lucky-background-Casilla'));
      await tester.tap(actualCell);
      await tester.pumpAndSettle();
      expect(find.textContaining('Casilla actual'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await _snapshot(tester, 'cell-${entry.$3}');
      await tester.tap(find.text('Volver al gabinete'));
      await tester.pumpAndSettle();
      expect(explore, findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  test('fixed strips arrive continuously at each declared example', () {
    for (final demo in LuckyDemo.values) {
      final done = LuckyDemoFrame(started: true, demo: demo, seconds: 6.2);
      for (var col = 0; col < 5; col++) {
        double last = 0;
        for (var tick = 0; tick <= 620; tick++) {
          final p = LuckyDemoFrame(
            started: true,
            demo: demo,
            seconds: tick / 100,
          ).reelPosition(col);
          expect(p, greaterThanOrEqualTo(last - 1e-9));
          last = p;
        }
        expect(last, closeTo(last.roundToDouble(), 1e-9));
        for (var row = 0; row < 3; row++) {
          expect(
            done.symbolAt(col, last.round() + row),
            done.result[row * 5 + col],
          );
        }
      }
      expect(done.pull, 0);
      expect(done.pose, LuckyPose.idle);
      final next = LuckyDemoFrame(previous: done.result, started: true);
      for (var col = 0; col < 5; col++) {
        for (var row = 0; row < 3; row++) {
          expect(next.symbolAt(col, row), done.result[row * 5 + col]);
        }
      }
    }
  });
  for (final choice in LuckyDemo.values) {
    testWidgets('sequence ${choice.name}, skip, lever and interruption', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        const MaterialApp(
          home: RepaintBoundary(
            key: _art,
            child: LuckyPalaceScreen(
              enableDeveloperTools: true,
              initialMode: LuckyPlayMode.demo,
            ),
          ),
        ),
      );
      await tester.ensureVisible(find.byKey(ValueKey('demo-${choice.name}')));
      await tester.tap(find.byKey(ValueKey('demo-${choice.name}')));
      await tester.tap(find.byKey(const ValueKey('lucky-spin')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      await _snapshot(tester, '${choice.name}-anticipation');
      await tester.pump(const Duration(milliseconds: 850));
      await _snapshot(tester, '${choice.name}-spin');
      await tester.pump(const Duration(milliseconds: 2300));
      await _snapshot(tester, '${choice.name}-stop');
      await tester.pump(const Duration(milliseconds: 850));
      await _snapshot(tester, '${choice.name}-celebrate');
      await tester.pumpAndSettle();
      expect(
        find.text(
          choice.amount == 0 ? 'DEMO · Sin premio' : 'DEMO · +${choice.amount}',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await _snapshot(tester, '${choice.name}-recover');
      // Dragging below threshold recovers; a full pull triggers the same clock.
      final lever = find.byKey(const ValueKey('lucky-lever'));
      await tester.drag(lever, const Offset(0, 12));
      await tester.pumpAndSettle();
      expect(find.text('OMITIR'), findsNothing);
      await tester.drag(lever, const Offset(0, 90));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('OMITIR'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('lucky-spin')));
      await tester.pumpAndSettle();
      expect(find.text('GIRAR'), findsOneWidget);
      // Entering the gallery completes presentation and restores hosts.
      await tester.tap(find.byKey(const ValueKey('lucky-spin')));
      await tester.pump(const Duration(milliseconds: 120));
      await tester.tap(find.text('Explorar símbolos'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Volver al gabinete'));
      await tester.pumpAndSettle();
      expect(find.text('GIRAR'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('workshop preserves normal navigator back behavior', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => const LuckyPalaceScreen(
                    enableDeveloperTools: true,
                    initialMode: LuckyPlayMode.demo,
                  ),
                ),
              ),
              child: const Text('Abrir taller'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Abrir taller'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Volver'));
    await tester.pumpAndSettle();
    expect(find.text('Abrir taller'), findsOneWidget);
  });

  testWidgets('lifecycle pauses clock and reduced motion finishes safely', (
    tester,
  ) async {
    var reduced = false;
    late StateSetter update;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
              child: const LuckyPalaceScreen(
                enableDeveloperTools: true,
                initialMode: LuckyPlayMode.demo,
              ),
            );
          },
        ),
      ),
    );
    await tester.ensureVisible(find.byKey(const ValueKey('demo-big')));
    await tester.tap(find.byKey(const ValueKey('demo-big')));
    await tester.tap(find.byKey(const ValueKey('lucky-spin')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(seconds: 20));
    expect(find.text('DEMO · Girando…'), findsOneWidget);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('OMITIR'), findsOneWidget);
    update(() => reduced = true);
    await tester.pumpAndSettle();
    expect(find.text('DEMO · +5000'), findsOneWidget);
    expect(find.text('GIRAR'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('lucky-spin')));
    await tester.pumpAndSettle();
    expect(find.text('OMITIR'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
