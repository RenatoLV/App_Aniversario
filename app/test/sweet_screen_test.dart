import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nuestro_rincon/store.dart';
import 'package:nuestro_rincon/sweet_screen.dart';
import 'package:nuestro_rincon/match3.dart';

void main() {
  Future<SharedPreferences> openBoard(
    WidgetTester tester,
    SweetGame game,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 740));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    SharedPreferences.setMockInitialValues({
      'sweet.v1': jsonEncode(game.toJson()),
    });
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      MaterialApp(home: SweetScreen(store: GameStore(prefs))),
    );
    await tester.pump();
    return prefs;
  }

  for (final direction in [
    const Offset(1, 0),
    const Offset(-1, 0),
    const Offset(0, 1),
    const Offset(0, -1),
  ]) {
    testWidgets(
      'A short $direction swipe exchanges one neighbor without taps',
      (tester) async {
        final game = SweetGame(seed: 12345);
        final origin = List.generate(81, (i) => i).firstWhere((i) {
          final x = i % 9 + direction.dx.toInt(),
              y = i ~/ 9 + direction.dy.toInt();
          return x >= 0 &&
              x < 9 &&
              y >= 0 &&
              y < 9 &&
              game.validSwap(i, y * 9 + x);
        });
        final target = origin + direction.dx.toInt() + 9 * direction.dy.toInt();
        final prefs = await openBoard(tester, game);
        final expected = SweetGame.fromJson(game.toJson())
          ..move(origin, target);
        final finger = await tester.startGesture(
          tester.getCenter(find.byKey(ValueKey('sweet-tile-$origin'))),
        );
        await finger.moveBy(direction * 22);
        await tester.pump();
        await tester.pump();
        var saved =
            jsonDecode(prefs.getString('sweet.v1')!) as Map<String, dynamic>;
        expect(saved['moves'], 25);
        expect(saved['cells'], expected.toJson()['cells']);
        // Holding and moving farther must not spend another turn.
        await finger.moveBy(direction * 60);
        await finger.up();
        await tester.pump();
        saved =
            jsonDecode(prefs.getString('sweet.v1')!) as Map<String, dynamic>;
        expect(saved['moves'], 25);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 1));
      },
    );
  }

  testWidgets('Rejected swipe returns pieces and keeps its explanation', (
    tester,
  ) async {
    final game = SweetGame(seed: 12345);
    final origin = List.generate(
      80,
      (i) => i,
    ).firstWhere((i) => i % 9 < 8 && !game.validSwap(i, i + 1));
    final prefs = await openBoard(tester, game);
    final finger = await tester.startGesture(
      tester.getCenter(find.byKey(ValueKey('sweet-tile-$origin'))),
    );
    await finger.moveBy(const Offset(22, 0));
    await finger.up();
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    final saved =
        jsonDecode(prefs.getString('sweet.v1')!) as Map<String, dynamic>;
    expect(saved['moves'], 26);
    expect(saved['cells'], game.toJson()['cells']);
    expect(
      find.text('Sin combinación: conservas el movimiento.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'Tiny, diagonal, cancelled and outward edge drags spend no turn',
    (tester) async {
      final game = SweetGame(seed: 12345);
      final prefs = await openBoard(tester, game);
      final center = tester.getCenter(
        find.byKey(const ValueKey('sweet-tile-40')),
      );
      for (final delta in [const Offset(5, 0), const Offset(22, 22)]) {
        final finger = await tester.startGesture(center);
        await finger.moveBy(delta);
        await finger.up();
        await tester.pump();
      }
      final cancelled = await tester.startGesture(center);
      await cancelled.moveBy(const Offset(4, 0));
      await cancelled.cancel();
      final edge = await tester.startGesture(
        tester.getCenter(find.byKey(const ValueKey('sweet-tile-0'))),
      );
      await edge.moveBy(const Offset(-22, 0));
      await edge.up();
      await tester.pump();
      expect(jsonDecode(prefs.getString('sweet.v1')!), game.toJson());
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('Free switch also works with one swipe', (tester) async {
    final game = SweetGame(seed: 12345);
    final origin = List.generate(
      80,
      (i) => i,
    ).firstWhere((i) => i % 9 < 8 && !game.validSwap(i, i + 1));
    final prefs = await openBoard(tester, game);
    await tester.tap(find.text('🔄 2'));
    await tester.pump();
    await tester.dragFrom(
      tester.getCenter(find.byKey(ValueKey('sweet-tile-$origin'))),
      const Offset(22, 0),
    );
    await tester.pump();
    await tester.pump();
    final saved =
        jsonDecode(prefs.getString('sweet.v1')!) as Map<String, dynamic>;
    expect(saved['switches'], 1);
    expect(saved['moves'], 26);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });
  testWidgets('Board and tools fit mobile portrait without overflow', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final store = GameStore(await SharedPreferences.getInstance());
    addTearDown(() => tester.binding.setSurfaceSize(null));
    for (final size in [const Size(393, 852), const Size(360, 740)]) {
      await tester.binding.setSurfaceSize(size);
      await tester.pumpWidget(MaterialApp(home: SweetScreen(store: store)));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(GridView), findsOneWidget);
      final grid = tester.getRect(find.byType(GridView));
      expect(grid.left, greaterThanOrEqualTo(0));
      expect(grid.right, lessThanOrEqualTo(size.width));
      expect(find.text('+5 (1)'), findsOneWidget);
      expect(tester.getRect(find.text('+5 (1)')).bottom, lessThan(size.height));
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('+5 (1)'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('🐾 31 movimientos'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await store.prefs.remove('sweet.v1');
    }
  });
}
