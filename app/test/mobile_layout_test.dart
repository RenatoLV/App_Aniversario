import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nuestro_rincon/home.dart';
import 'package:nuestro_rincon/leap_screen.dart';
import 'package:nuestro_rincon/store.dart';

void main() {
  testWidgets('Pack titles fit narrow phones and preserve chosen volume', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 740));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    SharedPreferences.setMockInitialValues({});
    final store = GameStore(await SharedPreferences.getInstance());
    await tester.pumpWidget(RinconApp(store: store));
    await tester.tap(find.text('Sobres'));
    await tester.pump();
    await tester.scrollUntilVisible(
      find.byType(PageView),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.drag(find.byType(PageView), const Offset(-240, 0));
    await tester.pump(const Duration(seconds: 2));
    expect(tester.takeException(), isNull);
    expect(find.text('MOMAZOS VOL. 2'), findsOneWidget);
    await tester.pump(const Duration(seconds: 12));
    expect(tester.widget<PageView>(find.byType(PageView)).controller!.page, 1);
    await tester.tap(find.text('Inicio'));
    await tester.pump();
    await tester.tap(find.text('Sobres'));
    await tester.pump();
    await tester.scrollUntilVisible(
      find.byType(PageView),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    expect(tester.widget<PageView>(find.byType(PageView)).controller!.page, 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('Ascenso controls and intro fit narrow and landscape screens', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final store = GameStore(await SharedPreferences.getInstance());
    addTearDown(() => tester.binding.setSurfaceSize(null));
    for (final size in [const Size(320, 640), const Size(740, 360)]) {
      await tester.binding.setSurfaceSize(size);
      await tester.pumpWidget(MaterialApp(home: LeapScreen(store: store)));
      await tester.pump();
      await tester.ensureVisible(find.text('¡A saltar!'));
      await tester.tap(find.text('¡A saltar!'));
      await tester.pump();
      expect(
        find.text('Busca los poderes: 🚀 impulso · 🛸 salto'),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    }
  });
}
