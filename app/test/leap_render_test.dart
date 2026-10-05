import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nuestro_rincon/cat_character.dart';
import 'package:nuestro_rincon/leap_screen.dart';
import 'package:nuestro_rincon/store.dart';

void main() {
  testWidgets('Leap keeps moving between slower HUD rebuilds', (tester) async {
    tester.view.physicalSize = const Size(390, 850);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final store = GameStore(await SharedPreferences.getInstance());
    await tester.pumpWidget(MaterialApp(home: LeapScreen(store: store)));
    await tester.tap(find.text('¡A saltar!'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    LeapWorldPainter paint() => tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((w) => w.painter)
        .whereType<LeapWorldPainter>()
        .single;
    final world = paint(), clock = paint().game.clock;
    final cat = find.byWidgetPredicate(
      (w) => w is CustomPaint && w.painter is MaruPainter,
    );
    final position = tester.getTopLeft(cat);
    await tester.pump(const Duration(milliseconds: 16));
    expect(paint().game.clock, greaterThan(clock));
    expect(identical(world, paint()), isTrue);
    expect(tester.getTopLeft(cat), isNot(position));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
