import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nuestro_rincon/home.dart';
import 'package:nuestro_rincon/store.dart';

void main() {
  testWidgets('Collection builds visible cards lazily and still scrolls', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final store = GameStore(await SharedPreferences.getInstance());
    await tester.pumpWidget(RinconApp(store: store));
    await tester.pump();
    final cards = find.byWidgetPredicate(
      (widget) => widget.runtimeType.toString() == '_CollectionCatPlay',
    );
    expect(cards, findsNothing);
    await tester.tap(find.text('Colección'));
    await tester.pump();
    expect(find.byType(CustomScrollView), findsOneWidget);
    expect(cards.evaluate().length, lessThan(30));
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -1800));
    await tester.pump();
    expect(find.byType(SliverGrid), findsOneWidget);
    expect(cards.evaluate().length, greaterThan(0));
    expect(cards.evaluate().length, lessThan(30));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
