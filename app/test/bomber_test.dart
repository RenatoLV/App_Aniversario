import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nuestro_rincon/bomber/bomber_simulation.dart';
import 'package:nuestro_rincon/bomber/bomber_screen.dart';

void main() {
  test('four arena boards agree with the server deterministic sample', () {
    final layouts = <String>{};
    for (var i = 0; i < 4; i++) {
      final b = makeBomberBoard(42, mapId: i);
      layouts.add('${b['walls']} ${b['crates']}');
      expect(objectMap(b['walls']).containsKey('1_11'), false);
      expect(objectMap(b['crates']).containsKey('1_10'), false);
    }
    expect(layouts.length, 4);
    expect(bomberHash(42, 3, 7), 1943568628);
  });
  test('diagonal movement is normalized and cannot cross solid cells', () {
    final sim = BomberSimulation.training(now: 0)..now = 4000;
    final before = sim.local;
    sim.move('maru', const Offset(1, -1), .1);
    expect((sim.local - before).distance, lessThanOrEqualTo(.26001));
    for (var i = 0; i < 100; i++) {
      sim.move('maru', const Offset(-1, 0), .02);
    }
    expect(sim.local.dx, greaterThanOrEqualTo(1.22));
    sim.dispose();
  });
  test('a bomb lets its owner escape but prevents walking back onto it', () {
    final sim = BomberSimulation.training(now: 0)..now = 4000;
    expect(sim.place('maru'), true);
    for (var i = 0; i < 25; i++) {
      sim.move('maru', const Offset(1, 0), .02);
    }
    expect(sim.local.dx, greaterThan(2));
    for (var i = 0; i < 25; i++) {
      sim.move('maru', const Offset(-1, 0), .02);
    }
    expect(sim.local.dx, greaterThanOrEqualTo(2.22));
    sim.dispose();
  });
  test('AI breaks a crate and moves out of its own explosion', () {
    final sim = BomberSimulation.training(now: 0);
    final start = sim.positions['lady']!;
    var placed = 0;
    sim.onEffect = (e) {
      if (e == 'place') placed++;
    };
    for (var t = 3000; t <= 10000 && !sim.finished; t += 20) {
      sim.tick(.02, t);
    }
    expect(placed, greaterThan(0));
    expect(sim.positions['lady'], isNot(start));
    expect(sim.alive('lady'), true);
    sim.dispose();
  });
  test('box expiration exits the current crate without teleporting', () {
    final sim = BomberSimulation.training(now: 0)..now = 3990;
    sim.state['board'] = sim.board..['crates'] = {'1_11': true};
    sim.state['players'] = sim.players
      ..['maru'] = {...sim.stats('maru'), 'boxUntil': 4000};
    sim.input = const Offset(1, 0);
    var before = sim.local;
    for (var t = 4010; t < 4800; t += 20) {
      sim.tick(.02, t);
      expect((sim.local - before).distance, lessThanOrEqualTo(.06));
      before = sim.local;
    }
    expect(sim.local.dx, greaterThan(2.22));
    sim.dispose();
  });
  testWidgets('small phone allows simultaneous joystick and bomb touches', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final sim = BomberSimulation.training(
      now: DateTime.now().millisecondsSinceEpoch - 4000,
    );
    await tester.pumpWidget(MaterialApp(home: BomberGameScreen(sim: sim)));
    final joystick = find.byKey(const ValueKey('bomber-joystick'));
    final drag = await tester.startGesture(
      tester.getCenter(joystick),
      pointer: 1,
    );
    await drag.moveBy(const Offset(32, 0));
    await tester.pump(const Duration(milliseconds: 20));
    expect(sim.input.dx, greaterThan(.5));
    final tap = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('bomber-bomb'))),
      pointer: 2,
    );
    await tester.pump();
    expect(sim.bombs.length, 1);
    expect(sim.input.dx, greaterThan(.5));
    await tap.up();
    await drag.cancel();
    expect(sim.input, Offset.zero);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
