import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nuestro_rincon/cat_character.dart';
import 'package:nuestro_rincon/home.dart';
import 'package:nuestro_rincon/pack_opening.dart';
import 'package:nuestro_rincon/store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('Both wrappers stay legible and contained throughout opening', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    for (final width in [320.0, 760.0]) {
      await tester.binding.setSurfaceSize(Size(width, 700));
      for (final volume in [0, 1]) {
        for (final t in [0.0, .15, .35, .55, .75, .95, 1.0]) {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: Padding(
                  padding: const EdgeInsets.all(24),
                  child: PackOpeningStage(
                    animation: AlwaysStoppedAnimation(t),
                    volume: volume,
                    opening: t > 0,
                    cat: volume == 0 ? CatKind.maru : CatKind.lady,
                  ),
                ),
              ),
            ),
          );
          await tester.pump();
          expect(
            tester.takeException(),
            isNull,
            reason: 'width=$width volume=$volume t=$t',
          );
          final stage = tester.getRect(
            find.byKey(const ValueKey('pack-stage')),
          );
          final emblem = tester.getRect(
            find.byKey(const ValueKey('pack-emblem')),
          );
          final title = tester.getRect(find.text('MOMAZOS'));
          expect(
            stage.contains(emblem.topLeft) &&
                stage.contains(emblem.bottomRight),
            isTrue,
          );
          expect(
            stage.contains(title.topLeft) && stage.contains(title.bottomRight),
            isTrue,
          );
          // Printed text and the paw must never inherit a perspective matrix.
          for (final transform in tester.widgetList<Transform>(
            find.ancestor(
              of: find.text('MOMAZOS'),
              matching: find.byType(Transform),
            ),
          )) {
            expect(transform.transform.entry(3, 2), 0);
          }
        }
      }
    }
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Opening locks the chosen volume and awards exactly one card', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final store = GameStore(await SharedPreferences.getInstance());
    final coins = store.coins;
    final cards = store.totalCards;
    await tester.pumpWidget(RinconApp(store: store));
    await tester.tap(find.text('Sobres'));
    await tester.pump();
    final carousel = find.byType(PageView);
    await tester.ensureVisible(carousel);
    await tester.drag(carousel, const Offset(-500, 0));
    await tester.pump(const Duration(seconds: 2));
    expect(
      tester.widget<PackOpeningStage>(find.byType(PackOpeningStage)).volume,
      1,
    );
    await tester.scrollUntilVisible(
      find.text('Abrir sobre · 20 monedas'),
      160,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();
    await Scrollable.ensureVisible(
      tester.element(find.text('Abrir sobre · 20 monedas')),
      alignment: .5,
    );
    await tester.pump();
    await tester.tap(find.text('Abrir sobre · 20 monedas'));
    await tester.pump();
    expect(
      tester.widget<PackOpeningStage>(find.byType(PackOpeningStage)).volume,
      1,
    );
    expect(
      tester
          .widget<FilledButton>(
            find.ancestor(
              of: find.text('¡Brillando tu sorpresa…!'),
              matching: find.byWidgetPredicate(
                (widget) => widget is FilledButton,
              ),
            ),
          )
          .onPressed,
      isNull,
    );
    await tester.pump(const Duration(milliseconds: 1600));
    expect(store.coins, coins);
    await tester.pump(const Duration(milliseconds: 1600));
    expect(store.coins, coins - 20);
    expect(store.totalCards, cards + 1);
    final reveal = tester.widget<CardRevealDialog>(
      find.byType(CardRevealDialog),
    );
    expect(reveal.collectionId, anniversaryCollectionV2Id);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
