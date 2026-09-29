import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nuestro_rincon/home.dart';
import 'package:nuestro_rincon/store.dart';

void main() {
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
      ..rarities = {6: CardRarity.legendary};

    await tester.pumpWidget(RinconApp(store: store));
    await tester.tap(find.text('Colección'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Legendaria 1'));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text(cardNames[6]), findsOneWidget);
    expect(find.text('1 resultados'), findsOneWidget);
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
    await store.save();
    final restored = GameStore(prefs);
    expect(restored.coins, 10);
    expect(restored.cards, store.cards);
    expect(restored.notes.single.text, 'Te quiero');
    expect(tester.takeException(), isNull);
  });
}
