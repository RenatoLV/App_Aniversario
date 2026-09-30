import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nuestro_rincon/menu_swipe.dart';

void main() {
  testWidgets('Only fast, long header swipes navigate', (tester) async {
    final steps = <int>[];
    await tester.pumpWidget(
      MaterialApp(
        home: MenuSwipe(
          onStep: steps.add,
          child: const Scaffold(body: SizedBox.expand()),
        ),
      ),
    );
    await tester.flingFrom(const Offset(200, 140), const Offset(0, 240), 1800);
    expect(steps, [-1]);
    await tester.flingFrom(const Offset(200, 150), const Offset(0, -150), 1800);
    expect(steps, [-1, 1]);
    await tester.flingFrom(const Offset(200, 140), const Offset(0, 70), 1800);
    await tester.flingFrom(const Offset(200, 140), const Offset(0, 240), 300);
    await tester.flingFrom(const Offset(200, 300), const Offset(0, 240), 1800);
    await tester.flingFrom(
      const Offset(200, 140),
      const Offset(200, 200),
      1800,
    );
    expect(steps, [-1, 1]);
  });
}
