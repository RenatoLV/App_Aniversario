import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nuestro_rincon/cat_character.dart';

void main() {
  testWidgets('Maru naps, wakes when petted and can be moved', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: CatActor(cat: CatKind.maru, size: 140, movable: true),
          ),
        ),
      ),
    );
    final sleeping = find.byWidgetPredicate(
      (widget) => widget is Semantics &&
          (widget.properties.label?.contains('está durmiendo') ?? false),
    );
    expect(sleeping, findsNothing);

    await tester.pump(const Duration(seconds: 12));
    await tester.pump();
    expect(sleeping, findsOneWidget);

    await tester.pump(const Duration(seconds: 8));
    await tester.pump();
    expect(sleeping, findsNothing);

    await tester.pump(const Duration(seconds: 12));
    await tester.pump();
    expect(sleeping, findsOneWidget);

    await tester.tap(find.byType(CatActor));
    await tester.pump(const Duration(milliseconds: 400));
    expect(sleeping, findsNothing);

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(CatActor)),
    );
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.moveBy(const Offset(18, 12));
    await tester.pump();
    await gesture.up();
    final transform = tester.widget<Transform>(
      find
          .descendant(
            of: find.byType(CatActor),
            matching: find.byType(Transform),
          )
          .first,
    );
    expect(transform.transform.getTranslation().x, greaterThan(0));
    expect(transform.transform.getTranslation().y, greaterThan(0));
  });
}
