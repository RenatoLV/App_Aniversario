import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nuestro_rincon/store.dart';
import 'package:nuestro_rincon/uncanny_golf/ucg_screen.dart';

void main() {
  const channel = MethodChannel('anivermaru/uncanny_golf');
  testWidgets('Original game launches through Android and reports errors', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    SharedPreferences.setMockInitialValues({});
    final store = GameStore(await SharedPreferences.getInstance());
    var launches = 0;
    var fail = false;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      expect(call.method, 'launch');
      launches++;
      if (fail) {
        throw PlatformException(
          code: 'unavailable',
          message: 'No se pudo abrir el juego original.',
        );
      }
      return null;
    });
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      ),
    );
    for (final size in [
      const Size(320, 568),
      const Size(390, 844),
      const Size(740, 360),
    ]) {
      await tester.binding.setSurfaceSize(size);
      await tester.pumpWidget(
        MaterialApp(home: UncannyGolfScreen(store: store)),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(
        find.byKey(const Key('ucg-launch-original')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.byKey(const Key('ucg-launch-original')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('ucg-launch-original')));
      await tester.pump();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    }
    expect(launches, 3);
    fail = true;
    await tester.pumpWidget(MaterialApp(home: UncannyGolfScreen(store: store)));
    await tester.scrollUntilVisible(
      find.byKey(const Key('ucg-launch-original')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.byKey(const Key('ucg-launch-original')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('ucg-launch-original')));
    await tester.pump();
    expect(find.text('No se pudo abrir el juego original.'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('ucg-launch-original')))
          .onPressed,
      isNotNull,
    );
    await tester.pumpWidget(const SizedBox());
    debugDefaultTargetPlatformOverride = null;
  });
}
