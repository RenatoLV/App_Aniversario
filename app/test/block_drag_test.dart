import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nuestro_rincon/home.dart';
import 'package:nuestro_rincon/store.dart';
import 'package:nuestro_rincon/game.dart';

void main() {
  testWidgets('Dragging places the first block in the cell under the finger', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final store = GameStore(await SharedPreferences.getInstance());
    store.game.tray = [1, 2, 3];
    await tester.pumpWidget(MaterialApp(home: BlockScreen(store: store)));
    await tester.pump();
    final source = find.byType(Draggable<int>).first;
    final target = find.byType(DragTarget<int>).at(35);
    final destination = tester.getCenter(target);
    final gesture = await tester.startGesture(tester.getCenter(source));
    await gesture.moveBy(const Offset(0, -25));
    await tester.pump();
    await gesture.moveTo(destination);
    await tester.pump();
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 1200));
    for (final cell in BlockGame.shapes[1]) {
      expect(store.game.board[(4 + cell.y) * 8 + 3 + cell.x], greaterThan(0));
    }
    expect(store.game.board[19], 0);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
