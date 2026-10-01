import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nuestro_rincon/home.dart';
import 'package:nuestro_rincon/store.dart';
import 'package:nuestro_rincon/collection_album.dart';
import 'package:nuestro_rincon/cat_character.dart';

void main() {
  for (final width in [320.0, 650.0]) {
    testWidgets('Both books paginate safely with cats at width $width', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(Size(width, 740));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      SharedPreferences.setMockInitialValues({});
      final store = GameStore(await SharedPreferences.getInstance());
      for (final volume in [
        anniversaryCollectionId,
        anniversaryCollectionV2Id,
      ]) {
        for (final id in cardsForCollection(volume).take(2)) {
          store.cards[id] = 1;
        }
      }
      await tester.pumpWidget(RinconApp(store: store));
      await tester.tap(find.text('Colección'));
      await tester.pump();
      for (var volume = 1; volume <= 2; volume++) {
        final ids = cardsForCollection(
          volume == 1 ? anniversaryCollectionId : anniversaryCollectionV2Id,
        );
        await tester.scrollUntilVisible(
          find.text('Momazos Vol. $volume'),
          120,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(find.text('Momazos Vol. $volume'));
        await tester.pump(const Duration(seconds: 1));
        expect(find.byType(CollectionAlbum), findsOneWidget);
        expect(find.text(cardNames[ids.first]), findsOneWidget);
        await tester.pump(const Duration(seconds: 4));
        final cats = tester
            .widgetList<CatActor>(find.byType(CatActor))
            .where((cat) => cat.action == CatAction.collection)
            .toList();
        expect(cats.map((cat) => cat.cat).toSet(), {
          CatKind.maru,
          CatKind.lady,
        });
        await tester.drag(
          find.byKey(const ValueKey('album-pages')),
          const Offset(-280, 0),
        );
        await tester.pump(const Duration(seconds: 1));
        expect(find.text('Carta 3'), findsOneWidget);
        expect(find.text(cardNames[ids[2]]), findsNothing);
        expect(find.text('Por descubrir'), findsWidgets);
        await tester.tap(find.text('Mis cartas'));
        await tester.pump(const Duration(seconds: 1));
        expect(find.text(cardNames[ids.first]), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.tap(find.byTooltip('Cerrar álbum'));
        await tester.pump(const Duration(seconds: 1));
        expect(find.byType(CollectionAlbum), findsNothing);
      }
      await tester.pumpWidget(const SizedBox());
    });
  }
  testWidgets('Owned filter explains an empty album', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CollectionAlbum(
            title: 'Momazos Vol. 2',
            teal: true,
            cardIds: const [1, 2],
            ownedIds: const {},
            onClose: () {},
            cardBuilder: (id, cats, active) => Text('Hidden $id'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Mis cartas'));
    await tester.pump(const Duration(seconds: 1));
    expect(find.textContaining('Aún no has descubierto'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
