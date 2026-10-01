import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nuestro_rincon/home.dart';
import 'package:nuestro_rincon/store.dart';
import 'package:nuestro_rincon/cat_character.dart';

void main() {
  testWidgets(
    'Collection never duplicates Maru or Lady across play cycles and inspection',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      final store = GameStore(await SharedPreferences.getInstance())
        ..cards = {for (var i = 6; i < 14; i++) i: 1}
        ..cardOpeners = {6: CatKind.maru.index};
      await tester.pumpWidget(RinconApp(store: store));
      await tester.tap(find.text('Colección'));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.scrollUntilVisible(
        find.text(cardNames[6]),
        180,
        scrollable: find.byType(Scrollable).first,
      );
      await Scrollable.ensureVisible(
        tester.element(find.text(cardNames[6])),
        alignment: .4,
      );
      await tester.pump();
      var sawBoth = false;
      void checkCats() {
        final cats = tester
            .widgetList<CatActor>(find.byType(CatActor, skipOffstage: false))
            .where((cat) => cat.action == CatAction.collection)
            .toList();
        expect(cats.length, lessThanOrEqualTo(2));
        for (final kind in CatKind.values) {
          expect(
            cats.where((cat) => cat.cat == kind).length,
            lessThanOrEqualTo(1),
          );
        }
        sawBoth |= cats.length == 2;
      }

      for (var frame = 0; frame < 22; frame++) {
        await tester.pump(const Duration(seconds: 2));
        checkCats();
        expect(tester.takeException(), isNull);
      }
      expect(sawBoth, isTrue);
      await Scrollable.ensureVisible(
        tester.element(find.text(cardNames[6])),
        alignment: .5,
      );
      await tester.pump();
      await tester.tap(find.text(cardNames[6]));
      await tester.pump(const Duration(milliseconds: 400));
      checkCats();
      expect(find.text('AR · Cámara 3D'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('Cerrar'));
      await tester.pump(const Duration(milliseconds: 400));
      checkCats();
      await tester.pumpWidget(const SizedBox());
    },
  );
  test('Legendary guarantee and variants survive reload', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final store = GameStore(prefs)
      ..coins = 1000
      ..packsSinceLegendary = 24;
    store.openPack(opener: CatKind.maru);
    expect(store.lastOpenedRarity, CardRarity.legendary);
    expect(store.packsSinceLegendary, 0);
    for (var i = 0; i < 12; i++) {
      store.openPack(opener: CatKind.lady);
    }
    await store.save();
    final restored = GameStore(prefs);
    expect(restored.cardVariants, store.cardVariants);
    expect(restored.packsSinceLegendary, store.packsSinceLegendary);
    expect(restored.cardVariants.values.fold<int>(0, (a, b) => a + b), 13);
  });
  test(
    'Volume packs use separate catalogs and preserve ownership on reload',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = GameStore(prefs)..coins = 400;
      expect(anniversaryCollectionV2Cards.length, 90);
      expect(
        anniversaryCollectionCards.toSet().intersection(
          anniversaryCollectionV2Cards.toSet(),
        ),
        isEmpty,
      );
      for (final volume in [
        anniversaryCollectionId,
        anniversaryCollectionV2Id,
      ]) {
        for (var attempt = 0; attempt < 5; attempt++) {
          final id = store.openPack(
            opener: CatKind.lady,
            collectionId: volume,
          )!;
          expect(cardsForCollection(volume), contains(id));
          expect(store.cardCollections[id], volume);
        }
      }
      await store.save();
      expect(GameStore(prefs).cardCollections, store.cardCollections);
    },
  );
  testWidgets('Collection volume shows owned progress and hidden slots', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final store = GameStore(prefs)..cards = {sampleCardCount: 1};

    await tester.pumpWidget(RinconApp(store: store));
    await tester.tap(find.text('Colección'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Momazos Vol. 1'));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('1/${anniversaryCollectionCards.length}'), findsOneWidget);
    expect(find.text('Carta 1'), findsOneWidget);
    expect(find.text('Carta 2'), findsOneWidget);
    expect(find.text('?'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Collection rarity filter renders only matching cards', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final store = GameStore(prefs)
      ..cards = {6: 1}
      ..rarities = {6: CardRarity.legendary}
      ..cardOpeners = {6: CatKind.maru.index}
      ..cardCollections = {6: anniversaryCollectionId};

    await tester.pumpWidget(RinconApp(store: store));
    await tester.tap(find.text('Colección'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.scrollUntilVisible(
      find.text('Legendaria 1'),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    await Scrollable.ensureVisible(
      tester.element(find.text('Legendaria 1')),
      alignment: .5,
    );
    await tester.pump();
    await tester.tap(find.text('Legendaria 1'));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('1 resultados'), findsOneWidget);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -700));
    await tester.pump();
    expect(find.text(cardNames[6]), findsOneWidget);
    await tester.tap(find.text(cardNames[6]));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Legendaria · ${cardNames[6]}'), findsOneWidget);
    expect(find.text('La abrió Maru'), findsWidgets);
    expect(find.text('AR · Cámara 3D'), findsOneWidget);
    await tester.tap(find.byTooltip('Girar a la derecha'));
    await tester.pump();
    await tester.tap(find.byTooltip('Girar a la derecha'));
    await tester.pump();
    expect(find.text(anniversaryCollectionEdition), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Purchase and note survive reload at mobile size', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final store = GameStore(prefs);
    await tester.pumpWidget(RinconApp(store: store));
    await tester.tap(find.text('Sobres'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.scrollUntilVisible(
      find.text('Abrir sobre · 20 monedas'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Abrir sobre · 20 monedas'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 4));
    await tester.pump(const Duration(milliseconds: 800));
    expect(store.coins, 10);
    expect(store.cards.length, 1);
    await tester.tap(find.text('A LA COLECCIÓN'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Nuestro bloc'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Una notita'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.enterText(find.byType(TextField), 'Te quiero');
    await tester.tap(find.text('Guardar'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Te quiero'), findsOneWidget);
    store.notes.single.imageBase64 = 'dGVzdA==';
    store.notes.single.mediaKind = 'drawing';
    store.notes.single.scale = .46;
    await store.save();
    final restored = GameStore(prefs);
    expect(restored.coins, 10);
    expect(restored.cards, store.cards);
    expect(restored.cardOpeners, store.cardOpeners);
    expect(restored.cardOpeners.values.single, CatKind.lady.index);
    expect(restored.cardCollections, store.cardCollections);
    expect(restored.cardCollections.values.single, anniversaryCollectionId);
    expect(restored.notes.single.text, 'Te quiero');
    expect(restored.notes.single.imageBase64, 'dGVzdA==');
    expect(restored.notes.single.mediaKind, 'drawing');
    expect(restored.notes.single.scale, .46);
    expect(tester.takeException(), isNull);
  });
}
