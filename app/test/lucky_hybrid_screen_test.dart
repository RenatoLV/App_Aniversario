import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:nuestro_rincon/lucky_palace/data/lucky_database.dart';
import 'package:nuestro_rincon/lucky_palace/data/local_lucky_repository.dart';
import 'package:nuestro_rincon/lucky_palace/data/remote_lucky_repository.dart';
import 'package:nuestro_rincon/lucky_palace/lucky_palace_screen.dart';
import 'package:nuestro_rincon/lucky_palace/art/lucky_cabinet_art.dart';
import 'package:nuestro_rincon/lucky_palace/engine/lucky_engine.dart';
import 'lucky_repository_test.dart' show FixedStops, SandboxFixture;
import 'lucky_motor_screen_test.dart' show checkFinalCells;

const capture = String.fromEnvironment('LUCKY_CAPTURE');
const boundary = ValueKey('hybrid-capture');
void confirmedCells(WidgetTester tester, LuckyRound expected) {
  final actual = tester
      .widgetList<CustomPaint>(find.byType(CustomPaint))
      .map((w) => w.painter)
      .whereType<LuckyCabinetPainter>()
      .firstWhere((p) => p.foreground)
      .frame
      .round!;
  expect(actual.toJson(), expected.toJson());
  checkFinalCells(tester, actual);
}

Future<void> snapshot(WidgetTester tester, String name) async {
  if (capture.isEmpty) return;
  await tester.runAsync(() async {
    final img = await tester
        .renderObject<RenderRepaintBoundary>(find.byKey(boundary))
        .toImage();
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    Directory(capture).createSync(recursive: true);
    File('$capture/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
    img.dispose();
  });
}

void main() {
  testWidgets(
    'close mid animation, reduced motion recovery, large text and skip never repay',
    (tester) async {
      tester.view.physicalSize = const Size(390, 750);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final db = (await tester.runAsync(
        () => databaseFactoryMemory.openDatabase('interrupted-widget'),
      ))!;
      final local = LocalLuckyRoundRepository(
        LuckyDatabase(db),
        random: FixedStops([0]),
      );
      Widget app(bool reduced) => MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: const TextScaler.linear(2),
            disableAnimations: reduced,
          ),
          child: child!,
        ),
        home: LuckyPalaceScreen(
          enableDeveloperTools: true,
          localRepository: local,
        ),
      );
      await tester.pumpWidget(app(false));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('lucky-mode-online')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('lucky-spin')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pumpWidget(const SizedBox());
      expect((await tester.runAsync(local.history))!.length, 1);
      await tester.pumpWidget(app(true));
      await tester.pumpAndSettle();
      if (find
          .byKey(const ValueKey('lucky-present-pending'))
          .evaluate()
          .isEmpty) {
        await tester.tap(find.byKey(const ValueKey('lucky-details')));
        await tester.pumpAndSettle();
      }
      await tester.ensureVisible(
        find.byKey(const ValueKey('lucky-present-pending')),
      );
      await tester.tap(find.byKey(const ValueKey('lucky-present-pending')));
      await tester.pumpAndSettle();
      expect((await tester.runAsync(local.history))!.length, 1);
      expect((await tester.runAsync(local.refresh))!.balance, 475);
      expect(await tester.runAsync(local.recover), null);
      expect(tester.takeException(), null);
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(db.close);
    },
  );
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
  for (final size in [
    const Size(360, 640),
    const Size(844, 390),
    const Size(1440, 900),
  ]) {
    testWidgets('offline full play and recovery ${size.width}', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final db = (await tester.runAsync(
        () => databaseFactoryMemory.openDatabase('widget-${size.width}'),
      ))!;
      final local = LocalLuckyRoundRepository(
        LuckyDatabase(db),
        random: FixedStops([14, 6, 3, 9, 10]),
      );
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            home: LuckyPalaceScreen(
              enableDeveloperTools: true,
              localRepository: local,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('lucky-wallet')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('lucky-spin')));
      await tester.pumpAndSettle();
      final receipt = (await tester.runAsync(local.history))!.single;
      confirmedCells(tester, receipt.round);
      expect((await tester.runAsync(local.refresh))!.bonus.remaining, 12);
      final cabinet = tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .map((w) => w.painter)
          .whereType<LuckyCabinetPainter>()
          .firstWhere((p) => p.foreground);
      expect(cabinet.frame.referenceCost, 0);
      expect(tester.takeException(), null);
      await snapshot(tester, 'local-${size.width.toInt()}');
      await tester.pumpWidget(const SizedBox());
      // Mounting another controller does not erase wallet/bonus or replay seen receipts.
      await tester.pumpWidget(
        MaterialApp(
          home: LuckyPalaceScreen(
            enableDeveloperTools: true,
            localRepository: local,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byTooltip('Girar gratis'), findsOneWidget);
      expect(await tester.runAsync(local.recover), null);
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(db.close);
    });
  }
  testWidgets(
    'online uncertain can switch local, reconnect exact receipt; animation locks origin',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final db = (await tester.runAsync(
        () => databaseFactoryMemory.openDatabase('hybrid-transition'),
      ))!;
      final local = LocalLuckyRoundRepository(
        LuckyDatabase(db),
        random: FixedStops([0]),
      );
      final server = SandboxFixture()..loseReply = true;
      final remote = RemoteLuckyRoundRepository(
        storage: LuckyDatabase(db),
        ownerUid: 'alice',
        call: server.call,
      );
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: MaterialApp(
            home: LuckyPalaceScreen(
              enableDeveloperTools: true,
              localRepository: local,
              connectSandbox: () async => remote,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('lucky-options')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('lucky-mode-online')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('lucky-spin')));
      await tester.pumpAndSettle();
      expect(server.charges, 1);
      expect(find.textContaining('Comprobando resultado'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('lucky-options')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('lucky-mode-local')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('lucky-wallet')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('lucky-spin')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        tester
            .widget<PopupMenuButton<LuckyPlayMode>>(
              find.byKey(const ValueKey('lucky-options')),
            )
            .enabled,
        false,
      );
      await tester.pump();
      expect(find.byKey(const ValueKey('lucky-wallet')), findsOneWidget);
      await tester.pumpAndSettle();
      expect((await tester.runAsync(local.refresh))!.balance, 475);
      await tester.tap(find.byKey(const ValueKey('lucky-options')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('lucky-mode-online')));
      await tester.pumpAndSettle();
      expect(find.text('Ver pendiente'), findsOneWidget);
      await tester.tap(find.text('Ver pendiente'));
      await tester.pumpAndSettle();
      final r = (await tester.runAsync(remote.history))!.single;
      confirmedCells(tester, r.round);
      expect(server.charges, 1);
      await snapshot(tester, 'online-recovered');
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(db.close);
    },
  );
}
