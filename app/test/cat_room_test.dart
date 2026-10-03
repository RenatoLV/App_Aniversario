import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nuestro_rincon/cat_room.dart';
import 'package:nuestro_rincon/cat_character.dart';

void main() {
  testWidgets('Room runs all routines automatically and cats enter the tray', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(393, 852));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: CatRoom(clock: () => DateTime(2026, 10, 3, 12)),
          ),
        ),
      ),
    );
    expect(find.byType(ActionChip), findsNothing);
    expect(find.byType(Image), findsOneWidget);
    final routines = <String>{};
    final thoughts = <String>{};
    var sawFeeding = false;
    var sawDigging = false;
    var sawFood = false;
    CatKind? lastDigger;
    var diggingSamples = 0;
    await tester.tapAt(tester.getCenter(find.byType(CatActor).first));
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('♥\nprrr…'), findsOneWidget);
    for (var turn = 0; turn < 180; turn++) {
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 300));
      for (final text in tester.widgetList<Text>(find.byType(Text))) {
        if (text.data != null) {
          routines.add(text.data!);
          if (text.data!.startsWith('🐟') ||
              text.data!.startsWith('💛') ||
              text.data!.startsWith('🌸') ||
              text.data!.startsWith('🌈')) {
            thoughts.add(text.data!);
          }
        }
      }
      var hasDigger = false;
      for (final cat in tester.widgetList<CatActor>(find.byType(CatActor))) {
        sawFeeding |= cat.feeding;
        sawFood |= cat.munching;
        if (cat.munching) {
          expect(
            tester.widget<Text>(find.text('ñam ñam ñam')).style!.fontWeight,
            FontWeight.w900,
          );
        }
        if (cat.digging) {
          hasDigger = true;
          sawDigging = true;
          diggingSamples = lastDigger == cat.cat ? diggingSamples + 1 : 1;
          lastDigger = cat.cat;
          if (diggingSamples >= 3) {
            final bounds = tester.getRect(find.byWidget(cat));
            expect(
              (bounds.center.dx - 393 / 2).abs(),
              lessThan(20),
              reason: '$bounds, size ${cat.size}',
            );
          }
        }
      }
      if (!hasDigger) {
        lastDigger = null;
        diggingSamples = 0;
      }
      expect(tester.takeException(), isNull);
    }
    expect(sawFeeding, isTrue);
    expect(sawDigging, isTrue);
    expect(sawFood, isTrue);
    expect(routines, contains('Dos bigotitos, mil pensamientos'));
    expect(routines, contains('¡Atrapa el ovillo, Lady!'));
    expect(routines, contains('Un ratito mirando las nubes'));
    await tester.pumpWidget(const SizedBox());
  });
}
