import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nuestro_rincon/store.dart';
import 'package:nuestro_rincon/lucky_palace/lucky_palace_screen.dart';
import 'package:nuestro_rincon/lucky_palace/art/lucky_cabinet_art.dart';
import 'package:nuestro_rincon/lucky_palace/engine/lucky_engine.dart';

class StopsRandom implements LuckyRandom {
  StopsRandom(this.stops);
  final List<int> stops;
  int calls = 0;
  @override
  int nextInt(int max) => stops[calls++ % stops.length];
}

const capture = String.fromEnvironment('LUCKY_CAPTURE');
const boundaryKey = ValueKey('motor-capture');
Future<void> snapshot(WidgetTester tester, String name) async {
  if (capture.isEmpty) return;
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(boundaryKey),
  );
  await tester.runAsync(() async {
    final img = await boundary.toImage();
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    Directory(capture).createSync(recursive: true);
    File('$capture/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
    img.dispose();
  });
}

void checkFinalCells(WidgetTester tester, LuckyRound round) {
  final painter = tester
      .widgetList<CustomPaint>(find.byType(CustomPaint))
      .map((w) => w.painter)
      .whereType<LuckyCabinetPainter>()
      .firstWhere((p) => p.foreground);
  expect(painter.frame.round, same(round));
  for (var c = 0; c < 5; c++) {
    for (var r = 0; r < 3; r++) {
      expect(
        painter.frame.symbolAt(c, painter.frame.travel(c) + r),
        round.grid[r * 5 + c],
      );
      expect(
        painter.frame.winningCell(c, r),
        round.evaluation.wins.any((w) => c < w.count && w.line.rows[c] == r),
      );
    }
  }
}

Future<void> mount(WidgetTester tester, Widget child) =>
    tester.pumpWidget(RepaintBoundary(key: boundaryKey, child: child));

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
    (const Size(844, 390), 1.0, 'landscape'),
    (const Size(1440, 900), 1.0, 'desktop'),
    (const Size(360, 640), 2.0, 'large-text'),
  ]) {
    testWidgets('motor layout and real lines ${entry.$3}', (tester) async {
      tester.view.physicalSize = entry.$1;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final rng = StopsRandom([6, 11, 8, 5, 13]), rounds = <LuckyRound>[];
      await mount(
        tester,
        MaterialApp(
          debugShowCheckedModeBanner: false,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(entry.$2),
              disableAnimations: true,
            ),
            child: child!,
          ),
          home: LuckyPalaceScreen(
            enableDeveloperTools: true,
            random: rng,
            onRound: rounds.add,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await snapshot(tester, 'motor-${entry.$3}-before');
      await tester.tap(find.byKey(const ValueKey('lucky-spin')));
      await tester.pumpAndSettle();
      expect(rounds.length, 1);
      expect(rng.calls, 5);
      expect(rounds.single.evaluation.total, 3080);
      expect(find.text('MOTOR · PRUEBA · +3080'), findsOneWidget);
      checkFinalCells(tester, rounds.single);
      expect(tester.takeException(), isNull);
      await snapshot(tester, 'motor-${entry.$3}-result');
      await tester.tap(find.byKey(const ValueKey('lucky-paytable')));
      await tester.pumpAndSettle();
      expect(find.text('Tabla candidata · créditos de prueba'), findsOneWidget);
      expect(
        find.text('${LuckyRules.candidate.payouts[LuckySymbol.wild]![5]! * 5}'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await snapshot(tester, 'paytable-${entry.$3}');
      await tester.tap(find.text('Cerrar'));
      await tester.pumpAndSettle();
      expect(rng.calls, 5);
    });
  }
  testWidgets('free spins, demo isolation and no economic or saved mutations', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final store = GameStore(prefs)..coins = 4321;
    store.cards[6] = 2;
    final beforePrefs = {
          for (final key in prefs.getKeys()) key: prefs.get(key),
        },
        beforeCards = Map.of(store.cards),
        care = jsonEncode(store.catCare.toJson());
    // First spin has five Scatter-bearing columns, then twelve quiet rounds.
    final rng = StopsRandom([14, 6, 3, 9, 10, ...List.filled(60, 0)]),
        rounds = <LuckyRound>[];
    await mount(
      tester,
      MaterialApp(
        debugShowCheckedModeBanner: false,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: LuckyPalaceScreen(
          enableDeveloperTools: true,
          random: rng,
          onRound: rounds.add,
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('lucky-spin')));
    await tester.pumpAndSettle();
    expect(rounds.single.after.remaining, 12);
    expect(find.text('Gratis: 12'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('lucky-mode-demo')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('lucky-spin')));
    await tester.pumpAndSettle();
    expect(rng.calls, 5);
    expect(rounds.length, 1);
    await tester.ensureVisible(find.byKey(const ValueKey('lucky-mode-motor')));
    await tester.tap(find.byKey(const ValueKey('lucky-mode-motor')));
    await tester.pumpAndSettle();
    for (var i = 0; i < 12; i++) {
      expect(find.text('GIRAR GRATIS'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('lucky-spin')));
      await tester.pumpAndSettle();
    }
    expect(rounds.length, 13);
    expect(
      rounds.skip(1).every((r) => r.freeSpin && r.simulatedCost == 0),
      isTrue,
    );
    expect(rounds.last.after.remaining, 0);
    expect(find.text('GIRAR'), findsOneWidget);
    expect(store.coins, 4321);
    expect(store.cards, beforeCards);
    expect(jsonEncode(store.catCare.toJson()), care);
    expect({
      for (final key in prefs.getKeys()) key: prefs.get(key),
    }, beforePrefs);
    expect(tester.takeException(), isNull);
    store.dispose();
  });
  testWidgets('motor skip/gallery/pause do not reroll or advance RNG', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final rng = StopsRandom([6, 11, 8, 5, 13]), rounds = <LuckyRound>[];
    await mount(
      tester,
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: LuckyPalaceScreen(
          enableDeveloperTools: true,
          random: rng,
          onRound: rounds.add,
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('lucky-spin')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1100));
    await snapshot(tester, 'motor-spin');
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(seconds: 10));
    expect(rng.calls, 5);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 3150));
    await snapshot(tester, 'motor-celebration');
    await tester.tap(find.byKey(const ValueKey('lucky-spin')));
    await tester.pumpAndSettle();
    expect(rounds.length, 1);
    expect(rng.calls, 5);
    checkFinalCells(tester, rounds.single);
    await tester.tap(find.byKey(const ValueKey('lucky-spin')));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('Explorar símbolos'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Volver al gabinete'));
    await tester.pumpAndSettle();
    expect(rounds.length, 2);
    expect(rng.calls, 10);
    checkFinalCells(tester, rounds.last);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Scatter receipt and free-spin counter reveal actual bonus', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final rounds = <LuckyRound>[];
    await mount(
      tester,
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: LuckyPalaceScreen(
          enableDeveloperTools: true,
          random: StopsRandom([14, 6, 3, 9, 10]),
          onRound: rounds.add,
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('lucky-spin')));
    await tester.pumpAndSettle();
    expect(rounds.single.evaluation.scatterColumns.length, 5);
    expect(find.text('Gratis: 12'), findsOneWidget);
    await snapshot(tester, 'motor-scatter-free-spins');
  });
}
