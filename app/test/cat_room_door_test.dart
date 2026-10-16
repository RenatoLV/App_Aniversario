import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nuestro_rincon/cat_room.dart';

void main() {
  for (final width in [320.0, 840.0, 1280.0]) {
    testWidgets('Patio door reaches floor and remains tappable at $width', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(Size(width, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var opened = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(12),
              child: CatRoom(onOpenPatio: () => opened++),
            ),
          ),
        ),
      );
      await tester.pump();
      final art = find.byKey(const ValueKey('home-patio-door-art'));
      final scene = find
          .ancestor(of: art, matching: find.byType(ClipRRect))
          .first;
      final doorRect = tester.getRect(art), sceneRect = tester.getRect(scene);
      expect(doorRect.bottom, closeTo(sceneRect.bottom - 38, .01));
      expect(doorRect.height, greaterThan(doorRect.width * 1.5));
      expect(sceneRect.contains(doorRect.topLeft), isTrue);
      // Cats can stand in front of the lower door; tap its visible upper panel.
      await tester.tapAt(doorRect.topCenter + const Offset(0, 20));
      await tester.pump(const Duration(milliseconds: 350));
      expect(opened, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
