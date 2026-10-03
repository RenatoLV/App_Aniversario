import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nuestro_rincon/store.dart';
import 'package:nuestro_rincon/home.dart';
import 'package:nuestro_rincon/card_media.dart';
import 'package:nuestro_rincon/celestial_reveal.dart';
import 'package:nuestro_rincon/cat_character.dart';

class PackRoll implements Random {
  final int roll;
  int calls = 0;
  PackRoll(this.roll);
  @override
  int nextInt(int max) => calls++ == 0 ? roll : 0;
  @override
  bool nextBool() => false;
  @override
  double nextDouble() => 0;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('Catalog extends both existing packs with permanent, distinct IDs', () {
    expect(celestialCatalog.length, greaterThanOrEqualTo(27));
    expect(
      celestialCatalog.map((c) => c.id).toSet().length,
      celestialCatalog.length,
    );
    for (final c in celestialCatalog) {
      expect(c.id, greaterThanOrEqualTo(10000));
      expect(c.frames, greaterThan(1));
      expect(cardNames[c.id], c.name);
      expect(
        cardsForCollection(
          c.volume == 1 ? anniversaryCollectionId : anniversaryCollectionV2Id,
        ),
        contains(c.id),
      );
    }
    expect(
      anniversaryCollectionV2Cards.where((id) => !isCelestialCard(id)).length,
      90,
    );
    expect(CardRarity.legendary.index, 2);
    expect(CardRarity.mythic.index, 5);
    expect(CardRarity.celestial.index, 6);
  });
  for (final volume in [anniversaryCollectionId, anniversaryCollectionV2Id]) {
    test(
      'Exactly one of 100 probability buckets yields a GIF in $volume, including pity',
      () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        for (final pity in [0, 24]) {
          var celestialCount = 0;
          for (var roll = 0; roll < 100; roll++) {
            final store = GameStore(prefs)
              ..coins = 1000
              ..packsSinceLegendary = pity;
            final id = store.openPack(
              random: PackRoll(roll),
              opener: CatKind.lady,
              collectionId: volume,
            )!;
            if (isCelestialCard(id)) {
              celestialCount++;
              expect(store.lastOpenedRarity, CardRarity.celestial);
              expect(store.packsSinceLegendary, 0);
              expect(
                celestialCard(id)!.volume,
                volume == anniversaryCollectionId ? 1 : 2,
              );
            } else {
              expect(store.lastOpenedRarity, isNot(CardRarity.celestial));
            }
            expect(store.coins, 980);
            expect(store.cards, {id: 1});
            expect(
              store.cardVariants['$id:${store.lastOpenedRarity.name}:gold'],
              1,
            );
            await store.save();
            store.dispose();
            // Each iteration is an independent opening, not persisted previous prizes.
            await prefs.clear();
          }
          expect(celestialCount, 1);
        }
      },
    );
  }
  test(
    'Celestial copies, finish, volume and opener survive a reload',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = GameStore(prefs)..coins = 100;
      final id = store.openPack(
        random: PackRoll(0),
        opener: CatKind.maru,
        collectionId: anniversaryCollectionV2Id,
      )!;
      await store.save();
      final restored = GameStore(prefs);
      expect(restored.cards[id], 1);
      expect(restored.rarities[id], CardRarity.celestial);
      expect(restored.cardVariants['$id:celestial:gold'], 1);
      expect(restored.cardCollections[id], anniversaryCollectionV2Id);
      expect(restored.cardOpeners[id], CatKind.maru.index);
      expect(restored.coins, 80);
      store.dispose();
      restored.dispose();
    },
  );
  test(
    'Every bundled GIF decodes as multiple timed frames in the Flutter engine',
    () async {
      for (final card in celestialCatalog) {
        final bytes = await rootBundle.load(card.asset);
        final codec = await ui.instantiateImageCodec(
          bytes.buffer.asUint8List(),
        );
        expect(codec.frameCount, card.frames, reason: card.name);
        expect(codec.repetitionCount, -1, reason: card.name);
        final a = await codec.getNextFrame();
        final b = await codec.getNextFrame();
        expect(a.duration.inMilliseconds, greaterThan(0), reason: card.name);
        expect(b.duration.inMilliseconds, greaterThan(0), reason: card.name);
        a.image.dispose();
        b.image.dispose();
        codec.dispose();
      }
    },
  );
  for (final width in [320.0, 390.0]) {
    testWidgets(
      'Mystery, burst, GIF and cat reactions fit mobile width $width',
      (tester) async {
        await tester.binding.setSurfaceSize(Size(width, 640));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CardRevealDialog(
                cardId: celestialCatalog.first.id,
                copies: 1,
                total: 1,
                opener: CatKind.maru,
                rarity: CardRarity.celestial,
              ),
            ),
          ),
        );
        await tester.pump();
        expect(find.byKey(const ValueKey('celestial-mystery')), findsOneWidget);
        expect(find.byType(CardMedia), findsNothing);
        await tester.pump(const Duration(milliseconds: 3000));
        expect(find.byType(CelestialRevealDialog), findsOneWidget);
        await tester.pump(const Duration(milliseconds: 2000));
        expect(
          find.byKey(const ValueKey('celestial-revealed')),
          findsOneWidget,
        );
        expect(find.byType(CardMedia), findsOneWidget);
        expect(
          find.text('Maru: ${celestialCatalog.first.maru}'),
          findsOneWidget,
        );
        expect(
          find.text('Lady: ${celestialCatalog.first.lady}'),
          findsOneWidget,
        );
        expect(find.byType(CatActor), findsNWidgets(2));
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
  testWidgets('Reduced motion reveals the GIF immediately', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: CelestialRevealDialog(
            cardId: celestialCatalog.first.id,
            copies: 1,
            collectionId: anniversaryCollectionId,
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byKey(const ValueKey('celestial-mystery')), findsNothing);
    expect(find.byType(CardMedia), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'Collection finds a celestial and inspection keeps its GIF player',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      SharedPreferences.setMockInitialValues({});
      final c = celestialCatalog.first;
      final store = GameStore(await SharedPreferences.getInstance())
        ..cards = {c.id: 1}
        ..rarities = {c.id: CardRarity.celestial}
        ..cardVariants = {'${c.id}:celestial:normal': 1};
      await tester.pumpWidget(RinconApp(store: store));
      await tester.tap(find.text('Colección'));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.scrollUntilVisible(
        find.text('Celestial 1'),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      await Scrollable.ensureVisible(
        tester.element(find.text('Celestial 1')),
        alignment: .5,
      );
      await tester.pump();
      await tester.tap(find.text('Celestial 1'));
      await tester.pump();
      await tester.scrollUntilVisible(
        find.text(c.name),
        160,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.byType(CardMedia), findsWidgets);
      await Scrollable.ensureVisible(
        tester.element(find.text(c.name)),
        alignment: .5,
      );
      await tester.pump();
      await tester.tap(find.text(c.name));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Celestial · ${c.name}'), findsOneWidget);
      expect(find.byType(CardMedia), findsWidgets);
      expect(find.text('AR · Cámara 3D'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      store.dispose();
    },
  );
}
