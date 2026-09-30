import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nuestro_rincon/store.dart';
import 'package:nuestro_rincon/sweet_screen.dart';

void main() {
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
