import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nuestro_rincon/football_game.dart';
import 'package:nuestro_rincon/football_screen.dart';
import 'package:nuestro_rincon/patio_weather.dart';
import 'package:nuestro_rincon/store.dart';

void main() {
  for (final size in [const Size(320, 568), const Size(844, 390)]) {
    testWidgets('Football aim, pause and 40-coin goals at $size', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = GameStore(prefs);
      final weather = PatioWeather(prefs);
      await tester.pumpWidget(
        MaterialApp(
          home: FootballScreen(store: store, weather: weather),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      final field = tester.getRect(find.byKey(const ValueKey('goal-field')));
      if (size.width > size.height) expect(field.height, greaterThan(300));
      final painter =
          tester
                  .widget<CustomPaint>(
                    find.byWidgetPredicate(
                      (w) => w is CustomPaint && w.painter is FootballPainter,
                    ),
                  )
                  .painter
              as FootballPainter;
      final game = painter.game;
      Offset at(Offset p) =>
          field.topLeft +
          Offset(p.dx / 400 * field.width, p.dy / 580 * field.height);
      final gesture = await tester.startGesture(
        at(FootballGame.origin + const Offset(12, 0)),
      );
      await tester.pump(const Duration(milliseconds: 60));
      await gesture.moveTo(at(const Offset(157, 250)));
      expect((game.aim! - const Offset(145, 250)).distance, lessThan(.001));
      await tester.pump(const Duration(milliseconds: 60));
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 16));
      final pause = find.byKey(const ValueKey('goal-pause'));
      await tester.tap(pause);
      await tester.pump();
      final frozen = game.ball;
      final frozenCloud = painter.clouds.value;
      for (var i = 0; i < 80; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(game.ball, frozen);
      expect(painter.clouds.value, frozenCloud);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(const Duration(milliseconds: 16));
      expect(
        game.ball,
        frozen,
      ); // Background/resume does not undo manual pause.
      final before = store.coins;
      await tester.tap(pause);
      for (var i = 0; i < 90; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(store.coins, before + 40);
      for (var i = 0; i < 100; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(store.coins, before + 40);
      expect(game.ready, isTrue);
      expect(
        find.text('Desliza hacia una esquina · +40 monedas por gol'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await store.save();
      weather.dispose();
      store.dispose();
    });
  }
}
