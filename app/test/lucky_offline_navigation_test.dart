import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nuestro_rincon/home.dart';
import 'package:nuestro_rincon/store.dart';
import 'package:nuestro_rincon/backend.dart';
import 'package:nuestro_rincon/wordle.dart';
import 'package:nuestro_rincon/lucky_palace/lucky_palace_screen.dart';
import 'package:nuestro_rincon/lucky_palace/data/lucky_database.dart';
import 'package:nuestro_rincon/lucky_palace/data/local_lucky_repository.dart';
import 'package:nuestro_rincon/lucky_palace/scratch/scratch_screen.dart';
import 'package:nuestro_rincon/lucky_palace/scratch/scratch_engine.dart';
import 'package:nuestro_rincon/lucky_palace/scratch/scratch_local_repository.dart';

Future<void> storageEvents(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump(const Duration(milliseconds: 20));
  }
}

void main() {
  testWidgets(
    'normal Anivermaru navigation works without Firebase; persistent casino does not change GameStore',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final dir = Directory.systemTemp.createTempSync('lucky-normal-route-');
      const channel = MethodChannel('plugins.flutter.io/path_provider');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (_) async => dir.path);
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = GameStore(prefs)..coins = 1234;
      final cards = {...store.cards}, care = jsonEncode(store.catCare.toJson());
      expect(Backend.configured, false);
      // Open the native adapter in the real event loop; fake widget clocks cannot
      // drive the database factory's OS I/O startup. The route still uses the
      // production factory and the real durable file, not an injected repository.
      await tester.runAsync(() async {
        final db = await openLuckyDatabase();
        await LocalLuckyRoundRepository(LuckyDatabase(db)).refresh();
      });
      await tester.pumpWidget(RinconApp(store: store));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.scrollUntilVisible(
        find.text('Lucky Palace'),
        500,
        maxScrolls: 30,
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Lucky Palace'));
      await tester.pump(const Duration(milliseconds: 500));
      // File I/O must get real event-loop time in a fake-async widget test.
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 150));
      });
      await tester.pump();
      await storageEvents(tester);
      expect(find.byType(LuckyPalaceScreen), findsOneWidget);
      expect(
        find.text('Fichas: 500'),
        findsOneWidget,
        reason: tester
            .widget<Text>(find.byKey(const ValueKey('lucky-status')))
            .data,
      );
      await tester.tap(find.byKey(const ValueKey('lucky-spin')));
      await tester.pump();
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 150));
      });
      await tester.pump();
      await storageEvents(tester);
      await tester.tap(find.byTooltip('Volver'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 450));
      expect(find.byType(LuckyPalaceScreen), findsNothing);
      await tester.scrollUntilVisible(
        find.text('Lucky Palace'),
        500,
        maxScrolls: 30,
      );
      await tester.pump(const Duration(milliseconds: 250));
      await tester.tap(find.text('Lucky Palace'));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 150));
      });
      await tester.pump();
      await storageEvents(tester);
      expect(find.text('Ver pendiente'), findsOneWidget);
      if (find.byKey(const ValueKey('lucky-skip-pending')).evaluate().isEmpty) {
        await tester.tap(find.byKey(const ValueKey('lucky-details')));
        await tester.pumpAndSettle();
      }
      await tester.ensureVisible(
        find.byKey(const ValueKey('lucky-skip-pending')),
      );
      await tester.tap(find.byKey(const ValueKey('lucky-skip-pending')));
      await tester.pump();
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pump();
      await storageEvents(tester);
      await tester.tap(find.byTooltip('Volver'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 450));
      await tester.scrollUntilVisible(
        find.text('Patita de la Suerte'),
        500,
        maxScrolls: 30,
      );
      await tester.ensureVisible(find.text('Patita de la Suerte'));
      await tester.tap(find.text('Patita de la Suerte'));
      await tester.pump(const Duration(milliseconds: 450));
      await storageEvents(tester);
      expect(find.byType(ScratchScreen), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('scratch-primary')));
      for (var i = 0; i < 12; i++) {
        await storageEvents(tester);
        if (find
            .byKey(const ValueKey('scratch-surface'))
            .evaluate()
            .isNotEmpty) {
          break;
        }
      }
      expect(find.byKey(const ValueKey('scratch-surface')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('scratch-back')));
      await storageEvents(tester);
      await tester.pump(const Duration(milliseconds: 450));
      await tester.tap(find.byKey(const ValueKey('scratch-back')));
      await storageEvents(tester);
      await tester.pump(const Duration(milliseconds: 450));
      expect(find.byType(ScratchScreen), findsNothing);
      await tester.scrollUntilVisible(
        find.text('Wordlady'),
        -500,
        maxScrolls: 30,
      );
      await tester.pump(const Duration(milliseconds: 200));
      await Scrollable.ensureVisible(
        tester.element(find.text('Wordlady')),
        alignment: .5,
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Wordlady'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 450));
      expect(find.byType(WordleScreen), findsOneWidget);
      expect(store.coins, 1234);
      expect(store.cards, cards);
      expect(jsonEncode(store.catCare.toJson()), care);
      expect(tester.takeException(), null);
      await tester.pumpWidget(const SizedBox());
      await storageEvents(tester);
      store.dispose();
      await tester.runAsync(() async {
        final db = await openLuckyDatabase();
        final repo = LocalLuckyRoundRepository(LuckyDatabase(db));
        expect((await repo.refresh()).configId, 'rewards25v2');
        final scratch = ScratchLocalRepository(LuckyDatabase(db));
        final receipt = (await scratch.recover())!;
        expect(receipt.rulesVersion, ScratchRules.enhancedVersion);
        expect(await scratch.balance(), receipt.balance);
        expect((await repo.history()).length, 1);
        expect(await repo.recover(), null);
        await db.close();
        dir.deleteSync(recursive: true);
      });
    },
  );
}
