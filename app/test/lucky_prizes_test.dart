import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nuestro_rincon/cat_care.dart';
import 'package:nuestro_rincon/store.dart';
import 'package:nuestro_rincon/lucky_palace/data/lucky_database.dart';
import 'package:nuestro_rincon/lucky_palace/data/lucky_prize_repository.dart';
import 'package:nuestro_rincon/lucky_palace/data/local_lucky_repository.dart';
import 'package:nuestro_rincon/lucky_palace/data/local_lucky_wallet.dart';
import 'package:nuestro_rincon/lucky_palace/lucky_palace_screen.dart';
import 'package:nuestro_rincon/lucky_palace/lucky_prize_screen.dart';
import 'package:nuestro_rincon/lucky_palace/lucky_prizes.dart';
import 'package:nuestro_rincon/lucky_palace/scratch/scratch_engine.dart';
import 'package:nuestro_rincon/lucky_palace/scratch/scratch_local_repository.dart';
import 'package:nuestro_rincon/lucky_palace/scratch/scratch_mask.dart';
import 'lucky_repository_test.dart' show FixedStops;

Future<void> playTickets(LuckyDatabase storage, int count) async {
  final scratch = ScratchLocalRepository(
    storage,
    random: FixedStops([5]),
    rulesVersion: ScratchRules.enhancedVersion,
  );
  for (var i = 0; i < count; i++) {
    final id = await scratch.prepare('patita_suerte', 'prize-ticket-$i');
    await scratch.execute(id);
    await scratch.saveVisual(id, ScratchMask(), reveal: true);
  }
}

Future<void> ready(WidgetTester t) async {
  for (var i = 0; i < 12; i++) {
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await t.pump(const Duration(milliseconds: 30));
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'locked prizes reject; sealed tickets do not count; confirmed plays do',
    () async {
      final db = await databaseFactoryMemory.openDatabase('prize-progress');
      addTearDown(db.close);
      final storage = LuckyDatabase(db),
          prizes = LuckyPrizeRepository(LuckyDatabase(db), 'guest');
      expect((await prizes.progress()).games, 0);
      await expectLater(prizes.redeem('welcome'), throwsStateError);
      expect((await prizes.progress()).balance, 500);
      final scratch = ScratchLocalRepository(storage, random: FixedStops([5]));
      final id = await scratch.prepare('patita_suerte', 'sealed');
      await scratch.execute(id);
      expect((await prizes.progress()).games, 0);
      await scratch.saveVisual(id, ScratchMask(), reveal: true);
      await scratch.execute(id);
      expect((await prizes.progress()).games, 1);
      await storage.transaction((tx) async {
        await luckyRecords.record('local.receipt.paid').put(tx, {'cost': 25});
        await luckyRecords.record('local.receipt.free').put(tx, {'cost': 0});
      });
      expect((await prizes.progress()).games, 2);
    },
  );

  test(
    'duplicate redemption debits once; interrupted delivery and restored game pay once',
    () async {
      final db = await databaseFactoryMemory.openDatabase('prize-idempotent');
      addTearDown(db.close);
      final storage = LuckyDatabase(db);
      await playTickets(storage, 5);
      final repo = LuckyPrizeRepository(storage, 'guest');
      final before = (await repo.progress()).balance;
      await Future.wait([repo.redeem('welcome'), repo.redeem('welcome')]);
      expect((await repo.progress()).balance, before - 75);
      final reopened = LuckyPrizeRepository(storage, 'guest');
      expect((await reopened.progress()).claimed, {'welcome'});
      await reopened.redeem('welcome');
      final prefs = await SharedPreferences.getInstance();
      final store = GameStore(prefs);
      await store.deliverCasinoPrize('welcome');
      await store.deliverCasinoPrize('welcome');
      expect(store.coins, 230);
      final restored = GameStore(prefs);
      await restored.deliverCasinoPrize('welcome');
      expect(restored.coins, 230);
      expect((await reopened.progress()).balance, before - 75);
      expect(
        restored.cloud.snapshot(),
        contains(luckyPrize('welcome').claimId),
      );
      expect(
        (await LuckyPrizeRepository(
          storage,
          'another-account',
        ).progress()).claimed,
        isEmpty,
      );
      store.dispose();
      restored.dispose();
    },
  );

  test(
    'all exclusive garments persist and cannot be bought from ordinary shop',
    () async {
      final db = await databaseFactoryMemory.openDatabase('prize-wardrobe');
      addTearDown(db.close);
      final storage = LuckyDatabase(db);
      await playTickets(storage, 75);
      final repo = LuckyPrizeRepository(storage, 'guest');
      final prefs = await SharedPreferences.getInstance();
      final store = GameStore(prefs);
      for (final prize in luckyPrizes) {
        if (prize.clothingId != null) {
          expect(
            await store.buyCatClothing(clothingById(prize.clothingId)!),
            false,
          );
        }
        await repo.redeem(prize.id);
        await store.deliverCasinoPrize(prize.id);
      }
      expect(store.coins, 3430);
      final restored = GameStore(prefs);
      for (final prize in luckyPrizes) {
        expect(restored.ownsCasinoPrize(prize.id), true);
        if (prize.clothingId != null) {
          final item = clothingById(prize.clothingId)!;
          expect(restored.catCare.ownsClothing(item), true);
          for (final cat in CatKind.values) {
            await restored.catCare.equip(cat, item);
            expect(restored.catCare.outfit(cat).at(item.slot), item.id);
          }
        }
      }
      store.dispose();
      restored.dispose();
    },
  );

  test(
    'insufficient chips and failed storage cannot leave partial redemptions',
    () async {
      final db = await databaseFactoryMemory.openDatabase('prize-failure');
      final storage = LuckyDatabase(db);
      await playTickets(storage, 5);
      await storage.transaction((tx) async {
        final wallet = await LocalLuckyWallet.read(tx);
        await LocalLuckyWallet.record.put(tx, {...wallet, 'balance': 50});
      });
      final repo = LuckyPrizeRepository(storage, 'guest');
      await expectLater(repo.redeem('welcome'), throwsStateError);
      expect((await repo.progress()).balance, 50);
      expect((await repo.progress()).claimed, isEmpty);
      await storage.transaction((tx) async {
        final wallet = await LocalLuckyWallet.read(tx);
        await LocalLuckyWallet.record.put(tx, {...wallet, 'balance': 500});
      });
      final interrupted = LuckyPrizeRepository(
        LuckyDatabase(
          db,
          beforeCommit: () async => throw StateError('Interrupted commit'),
        ),
        'guest',
      );
      await expectLater(interrupted.redeem('welcome'), throwsStateError);
      expect((await repo.progress()).balance, 500);
      expect((await repo.progress()).claimed, isEmpty);
      await db.close();
    },
  );

  testWidgets(
    'public casino has prizes, no dev menu; can redeem from gameplay',
    (t) async {
      final db = (await t.runAsync(
        () => databaseFactoryMemory.openDatabase('prize-public-ui'),
      ))!;
      final storage = LuckyDatabase(db);
      await t.runAsync(() => playTickets(storage, 5));
      final prefs = await SharedPreferences.getInstance();
      final store = GameStore(prefs);
      await t.pumpWidget(
        MaterialApp(
          home: LuckyPalaceScreen(
            store: store,
            localRepository: LocalLuckyRoundRepository(storage),
          ),
        ),
      );
      await ready(t);
      expect(find.byKey(const ValueKey('lucky-options')), findsNothing);
      expect(find.byKey(const ValueKey('lucky-symbols')), findsNothing);
      expect(find.text('Explorar símbolos'), findsNothing);
      await t.tap(find.byKey(const ValueKey('lucky-prizes')));
      await ready(t);
      expect(find.byType(LuckyPrizeScreen), findsOneWidget);
      final gift = find.byKey(const ValueKey('prize-welcome'));
      await t.ensureVisible(gift);
      await t.tap(gift);
      await ready(t);
      expect(store.coins, 230);
      expect(t.widget<FilledButton>(gift).onPressed, isNull);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
      store.dispose();
      await t.runAsync(db.close);
    },
  );

  for (final scale in [1.0, 2.0]) {
    testWidgets('prize wardrobe previews fit mobile at text scale $scale', (
      t,
    ) async {
      t.view.physicalSize = const Size(390, 844);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      if (Platform.environment['CAPTURE_CASINO_PRIZES'] == '1') {
        for (final family in ['Fredoka', 'Nunito']) {
          await (FontLoader(
            family,
          )..addFont(rootBundle.load('assets/fonts/$family.ttf'))).load();
        }
        await (FontLoader(
          'Roboto',
        )..addFont(rootBundle.load('assets/fonts/Nunito.ttf'))).load();
        await (FontLoader(
          'MaterialIcons',
        )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
      }
      final db = (await t.runAsync(
        () => databaseFactoryMemory.openDatabase('prize-preview-$scale'),
      ))!;
      final storage = LuckyDatabase(db);
      await t.runAsync(() => playTickets(storage, 20));
      final store = GameStore(await SharedPreferences.getInstance());
      final key = GlobalKey();
      await t.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: RepaintBoundary(
            key: key,
            child: LuckyPrizeScreen(storage: storage, store: store),
          ),
        ),
      );
      await ready(t);
      for (final prize in luckyPrizes) {
        await t.scrollUntilVisible(
          find.byKey(ValueKey('prize-${prize.id}')),
          220,
        );
        await t.pump();
        expect(t.takeException(), isNull);
      }
      if (Platform.environment['CAPTURE_CASINO_PRIZES'] == '1' && scale == 1) {
        await t.scrollUntilVisible(
          find.byKey(const ValueKey('prize-charm')),
          -250,
        );
        await t.pump();
        await t.runAsync(() async {
          final image =
              await (key.currentContext!.findRenderObject()
                      as RenderRepaintBoundary)
                  .toImage(pixelRatio: 2);
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          final file = File('build/qa/casino-prizes.png');
          await file.parent.create(recursive: true);
          await file.writeAsBytes(data!.buffer.asUint8List());
          image.dispose();
        });
      }
      await t.pumpWidget(const SizedBox());
      store.dispose();
      await t.runAsync(db.close);
    });
  }
}
