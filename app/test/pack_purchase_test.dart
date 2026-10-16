import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nuestro_rincon/cat_character.dart';
import 'package:nuestro_rincon/home.dart';
import 'package:nuestro_rincon/celestial_reveal.dart';
import 'package:nuestro_rincon/store.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MixedRolls implements Random {
  int calls = 0;
  @override
  int nextInt(int max) {
    final slot = calls++;
    return slot % 3 == 0 && (slot ~/ 3).isOdd ? 99 : 0;
  }

  @override
  bool nextBool() => false;
  @override
  double nextDouble() => 0;
}

class _MixedBatchStore extends GameStore {
  _MixedBatchStore(super.prefs);
  @override
  List<PackResult> openTenPacks({
    Random? random,
    required CatKind opener,
    String collectionId = anniversaryCollectionId,
    DateTime? now,
  }) => super.openTenPacks(
    random: _MixedRolls(),
    opener: opener,
    collectionId: collectionId,
    now: now,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final collection in [
    anniversaryCollectionId,
    anniversaryCollectionV2Id,
  ]) {
    test('Ten packs match ten individual purchases in $collection', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final batch = GameStore(prefs)..coins = 5000;
      final single = GameStore(prefs)..coins = 5000;
      final day = DateTime(2026, 10, 16);
      final generator = Random(72);
      expect(batch.tenPackPriceAt(day), 425);
      final results = batch.openTenPacks(
        opener: CatKind.lady,
        random: Random(72),
        now: day,
        collectionId: collection,
      );
      expect(results.length, 10);
      for (var i = 0; i < 10; i++) {
        expect(
          results[i].cardId,
          single.openPack(
            opener: i.isEven ? CatKind.lady : CatKind.maru,
            random: generator,
            now: day,
            collectionId: collection,
          ),
        );
        expect(results[i].rarity, single.lastOpenedRarity);
        expect(results[i].finish, single.lastOpenedFinish);
      }
      expect(batch.coins, 4575);
      expect(batch.cards, single.cards);
      expect(batch.cardVariants, single.cardVariants);
      expect(batch.cardOpeners, single.cardOpeners);
      expect(batch.packsSinceLegendary, single.packsSinceLegendary);
      expect(batch.tenPackPriceAt(day), 700);
      expect(batch.tenPackPriceAt(DateTime(2026, 10, 17)), 425);
      await single.save();
      await batch.save();
      final restored = GameStore(prefs);
      expect(restored.cards, batch.cards);
      expect(restored.cardVariants, batch.cardVariants);
      expect(restored.coins, batch.coins);
      restored.dispose();
      batch.dispose();
      single.dispose();
    });

    test(
      'Celestial purchase costs exactly 5000 and persists in $collection',
      () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final store = GameStore(prefs)
          ..coins = 5000
          ..packsSinceLegendary = 24
          ..lastDiscountPackDay = '2026-10-16'
          ..dailyPacksOpened = 4;
        final id = store.openCelestialPack(
          opener: CatKind.maru,
          random: Random(5),
          collectionId: collection,
        )!;
        expect(isCelestialCard(id), isTrue);
        expect(cardsForCollection(collection), contains(id));
        expect(store.coins, 0);
        expect(store.totalCards, 1);
        expect(store.packsSinceLegendary, 24);
        expect(store.dailyPacksOpened, 4);
        expect(store.packPriceAt(DateTime(2026, 10, 16)), 40);
        expect(store.lastOpenedRarity, CardRarity.celestial);
        await store.save();
        final restored = GameStore(prefs);
        expect(restored.coins, 0);
        expect(restored.cards[id], 1);
        expect(restored.rarities[id], CardRarity.celestial);
        expect(restored.cardCollections[id], collection);
        expect(restored.cardOpeners[id], CatKind.maru.index);
        expect(restored.cardVariants, store.cardVariants);
        restored.dispose();
        store.dispose();
      },
    );
  }

  test('Failed purchases never charge or partially open packs', () async {
    SharedPreferences.setMockInitialValues({});
    final store = GameStore(await SharedPreferences.getInstance())..coins = 424;
    final day = DateTime(2026, 10, 16);
    expect(store.openTenPacks(opener: CatKind.maru, now: day), isEmpty);
    expect(store.coins, 424);
    expect(store.totalCards, 0);
    store.coins = 4999;
    expect(store.openCelestialPack(opener: CatKind.lady), isNull);
    expect(store.coins, 4999);
    store.coins = 5000;
    expect(
      store.openTenPacks(opener: CatKind.maru, collectionId: 'missing'),
      isEmpty,
    );
    expect(
      store.openCelestialPack(opener: CatKind.maru, collectionId: 'missing'),
      isNull,
    );
    expect(store.coins, 5000);
    expect(store.totalCards, 0);
    expect(store.dailyPacksOpened, 0);
    store.dispose();
  });

  for (final celestial in [false, true]) {
    testWidgets(
      'Purchase button opens ${celestial ? 'a celestial' : 'ten cards'} once',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final store = (celestial ? GameStore(prefs) : _MixedBatchStore(prefs))
          ..coins = 5000;
        await tester.pumpWidget(RinconApp(store: store));
        await tester.tap(find.text('Sobres'));
        await tester.pump();
        final button = find.byKey(
          ValueKey(celestial ? 'open-celestial-pack' : 'open-ten-packs'),
        );
        await tester.scrollUntilVisible(
          button,
          220,
          scrollable: find.byType(Scrollable).first,
        );
        await Scrollable.ensureVisible(tester.element(button), alignment: .5);
        await tester.pump();
        await tester.tap(button);
        await tester.pump();
        expect(tester.widget<FilledButton>(button).onPressed, isNull);
        await tester.tap(button);
        await tester.pump(const Duration(milliseconds: 3200));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(store.coins, celestial ? 0 : 4575);
        expect(store.totalCards, celestial ? 1 : 10);
        if (celestial) {
          expect(store.cards.keys.every(isCelestialCard), isTrue);
        } else {
          for (var i = 1; i <= 10; i++) {
            expect(find.byKey(ValueKey('pack-reveal-$i')), findsOneWidget);
            if (i.isOdd) {
              expect(find.byType(CelestialRevealDialog), findsOneWidget);
              await tester.pump(const Duration(seconds: 7));
              final next = find.byKey(const ValueKey('celestial-continue'));
              await tester.ensureVisible(next);
              await tester.tap(next);
            } else {
              final next = find.text('SIGUIENTE · $i/10');
              await tester.ensureVisible(next);
              await tester.tap(next);
            }
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 500));
            expect(store.totalCards, 10);
          }
          expect(find.text('¡Tus 10 cartas!'), findsOneWidget);
          final summaryItem = find
              .descendant(
                of: find.byType(BottomSheet),
                matching: find.byType(ListTile),
              )
              .first;
          await tester.tap(summaryItem);
          await tester.pump();
          expect(find.byType(CardRevealDialog), findsOneWidget);
          expect(store.totalCards, 10);
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await store.save();
        store.dispose();
      },
    );
  }
}
