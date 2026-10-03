import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:nuestro_rincon/leap.dart';

void main() {
  test('Varied platforms leave enough flight time for taller, wider jumps', () {
    for (var seed = 0; seed < 30; seed++) {
      final game = LeapGame(random: math.Random(seed))..generate(30000);
      final route = game.platforms
          .where((p) => p.kind != LeapPlatformKind.storm)
          .toList();
      expect(route.map((p) => p.width.round()).toSet().length, greaterThan(15));
      expect(
        route.where((p) => p.motion > 0).length,
        greaterThan(route.length * .2),
      );
      for (var i = 1; i < route.length; i++) {
        final from = route[i - 1], to = route[i];
        final gap = to.y - from.y;
        expect(gap, inInclusiveRange(90, 116));
        final time =
            (LeapGame.jumpSpeed +
                math.sqrt(
                  LeapGame.jumpSpeed * LeapGame.jumpSpeed -
                      2 * LeapGame.gravity * gap,
                )) /
            LeapGame.gravity;
        final worstTravel =
            (to.baseX - from.baseX).abs() + from.motion + to.motion;
        final travelAfterReversal = 230 * time - 460 / 12;
        expect(
          worstTravel,
          lessThan(
            travelAfterReversal + to.width / 2 + LeapGame.catWidth * .28,
          ),
        );
        expect(to.baseX - to.width / 2, greaterThanOrEqualTo(0));
        expect(to.baseX + to.width / 2, lessThanOrEqualTo(LeapGame.width));
      }
    }
  });
  test('Shared power schedule halves total frequency, including umbrellas', () {
    for (var seed = 0; seed < 30; seed++) {
      final game = LeapGame(random: math.Random(seed));
      game.generate(30000);
      final allPowers = game.pickups
          .where((p) => p.kind != LeapPickupKind.coin)
          .toList();
      expect(allPowers.length, inInclusiveRange(19, 23));
      for (var i = 1; i < allPowers.length; i++) {
        expect(
          allPowers[i].y - allPowers[i - 1].y,
          inInclusiveRange(1200, 1670),
        );
      }
      for (final kind in [
        LeapPickupKind.rocket,
        LeapPickupKind.umbrella,
        LeapPickupKind.ufo,
      ]) {
        final powers = game.pickups.where((p) => p.kind == kind).toList();
        expect(
          powers.first.y,
          lessThan(
            kind == LeapPickupKind.rocket
                ? 1200
                : kind == LeapPickupKind.umbrella
                ? 2900
                : 4600,
          ),
        );
        for (var i = 1; i < powers.length; i++) {
          expect(powers[i].y - powers[i - 1].y, lessThan(5100));
        }
        for (final power in powers) {
          final base = game.platforms.singleWhere(
            (p) => (p.y - (power.y - 42)).abs() < .0001,
          );
          expect(base.kind, isNot(LeapPlatformKind.storm));
          expect(base.motion, 0);
          expect(power.x, base.x);
          expect(
            game.pickups.where((p) => p != power && (p.y - power.y).abs() < 20),
            isEmpty,
          );
        }
      }
    }
  });
  test('Collecting a rocket activates and then expires its impulse', () {
    final game = LeapGame(random: math.Random(2));
    game.pickups
      ..clear()
      ..add(LeapPickup(180, 106, LeapPickupKind.rocket));
    game.step(.01, 0, 640);
    expect(game.rockets, 1);
    expect(game.boosting, isTrue);
    expect(game.vy, 760);
    game.pickups.clear();
    game.platforms.removeWhere((p) => p.kind == LeapPlatformKind.storm);
    game.rocketTime = .01;
    game.step(.02, 0, 640);
    expect(game.boosting, isFalse);
  });
  test('All stages are twice as long as the previous extended journey', () {
    final boundaries = [
      LeapGame.meadowHeight,
      LeapGame.neighborhoodHeight,
      LeapGame.cityHeight,
      LeapGame.skyscraperHeight,
      LeapGame.upperSkyHeight,
      LeapGame.spaceHeight,
      LeapGame.heavenHeight,
    ];
    const previous = [1600, 3200, 5200, 7600, 10000, 13200, 18000];
    for (var i = 0; i < boundaries.length; i++) {
      expect(boundaries[i], previous[i] * 3.2);
    }
  });
  test('Umbrellas cap descent, preserve ascent and expire', () {
    final game = LeapGame(random: math.Random(3));
    game.platforms.clear();
    game.pickups
      ..clear()
      ..add(LeapPickup(180, 526, LeapPickupKind.umbrella));
    game
      ..y = 500
      ..vy = -200;
    game.step(.05, 0, 640);
    expect(game.umbrellas, 1);
    expect(game.umbrellaOpen, isTrue);
    expect(game.vy, -135);
    game.vy = 400;
    game.step(.05, 0, 640);
    expect(game.umbrellaOpen, isFalse);
    expect(game.vy, closeTo(400 - LeapGame.gravity * .05, .001));
    game
      ..vy = -135
      ..umbrellaTime = .01;
    game.step(.04, 0, 640);
    expect(game.umbrellaTime, 0);
    expect(game.vy, lessThan(-135));
  });

  test('A trampoline launches higher and still consumes a cloud normally', () {
    final game = LeapGame(random: math.Random(3));
    final spring = LeapPlatform(
      9000,
      180,
      80,
      100,
      LeapPlatformKind.cloud,
      trampoline: true,
    );
    game.platforms
      ..clear()
      ..add(spring);
    game.pickups.clear();
    game
      ..x = 180
      ..y = 86
      ..vy = -100;
    game.step(.08, 0, 640);
    expect(game.springJumps, 1);
    expect(game.vy, greaterThan(LeapGame.jumpSpeed));
    expect(spring.springAt, isNotNull);
    expect(spring.vanishingAt, isNotNull);
    for (var i = 0; i < 5; i++) {
      game.step(.1, 0, 640);
    }
    expect(game.y, greaterThan(80 + 150));
  });
  test('Crossing either side wraps without losing horizontal speed', () {
    final game = LeapGame()
      ..x = LeapGame.width - 1
      ..vx = 230;
    game.step(.02, 1, 640);
    expect(game.x, lessThan(10));
    expect(game.vx, greaterThan(200));
    game
      ..x = 1
      ..vx = -230;
    game.step(.02, -1, 640);
    expect(game.x, greaterThan(LeapGame.width - 10));
    expect(game.vx, lessThan(-200));
  });
  test('Rocket ascent still collides with electric clouds', () {
    final game = LeapGame();
    game.platforms
      ..clear()
      ..add(LeapPlatform(999, 180, 140, 80, LeapPlatformKind.storm));
    game
      ..x = 180
      ..y = 80
      ..rocketTime = 2;
    game.step(.1, 0, 640);
    expect(game.over, isTrue);
    expect(game.endReason, '¡Una nube eléctrica!');
    expect(game.boosting, isFalse);
  });
  test('Moving airplanes turn to face their actual travel direction', () {
    final game = LeapGame();
    final plane = LeapPlatform(
      0,
      180,
      400,
      96,
      LeapPlatformKind.airplane,
      motion: 20,
    );
    game.platforms
      ..clear()
      ..add(plane);
    game.step(.01, 0, 640);
    expect(plane.facingRight, isTrue);
    game.clock = math.pi / 1.5;
    plane.x = plane.baseX;
    game.step(.01, 0, 640);
    expect(plane.facingRight, isFalse);
  });
  test('Heaven extends the route after the universe', () {
    final game = LeapGame();
    expect(game.zoneAt(LeapGame.heavenHeight - 1), LeapWorldZone.space);
    expect(game.zoneAt(LeapGame.heavenHeight), LeapWorldZone.heaven);
    game.generate(LeapGame.heavenHeight + 1000);
    expect(game.platforms.any((p) => p.y > LeapGame.heavenHeight), isTrue);
  });
  test('Galactic Leap crosses every landscape before reaching space', () {
    final game = LeapGame();

    expect(game.zoneAt(0), LeapWorldZone.underground);
    expect(game.zoneAt(LeapGame.meadowHeight), LeapWorldZone.meadow);
    expect(
      game.zoneAt(LeapGame.neighborhoodHeight),
      LeapWorldZone.neighborhood,
    );
    expect(game.zoneAt(LeapGame.cityHeight), LeapWorldZone.city);
    expect(game.zoneAt(LeapGame.skyscraperHeight), LeapWorldZone.skyscrapers);
    expect(game.zoneAt(LeapGame.upperSkyHeight), LeapWorldZone.upperSky);
    expect(game.zoneAt(LeapGame.spaceHeight - 1), LeapWorldZone.upperSky);
    expect(game.zoneAt(LeapGame.spaceHeight), LeapWorldZone.space);
  });

  test('A cloud vanishes shortly after the cat lands on it', () {
    final game = LeapGame();
    game.platforms
      ..clear()
      ..add(LeapPlatform(999, 180, 80, 100, LeapPlatformKind.cloud));
    game
      ..x = 180
      ..y = 86
      ..vy = -100;

    game.step(.08, 0, 640);
    expect(game.platforms.single.vanishingAt, isNotNull);

    for (var i = 0; i < 7; i++) {
      game.step(.1, 0, 640);
    }
    expect(game.platforms.where((platform) => platform.id == 999), isEmpty);
  });

  test('The high-altitude route contains only clouds and airplanes', () {
    final game = LeapGame(random: math.Random(4));
    game.generate(LeapGame.spaceHeight + 800);

    final sky = game.platforms.where(
      (platform) => platform.y >= LeapGame.skyscraperHeight,
    );
    expect(sky, isNotEmpty);
    expect(
      sky.every(
        (platform) =>
            platform.kind == LeapPlatformKind.cloud ||
            platform.kind == LeapPlatformKind.airplane,
      ),
      isTrue,
    );
  });

  test(
    'A UFO visibly carries the cat up and releases it onto a safe platform',
    () {
      final game = LeapGame(random: math.Random(8));
      game.pickups.add(LeapPickup(180, 106, LeapPickupKind.ufo));

      game.step(.01, 0, 640);

      expect(game.ufos, 1);
      expect(game.alien, isTrue);
      expect(game.abducting, isTrue);
      expect(game.y, lessThan(100));
      final initialCamera = game.camera;
      var frames = 0;
      while (game.abducting && frames < 450) {
        final previousY = game.y;
        final previousCamera = game.camera;
        game.step(1 / 120, 1, 640);
        expect((game.y - previousY).abs(), lessThan(8));
        expect((game.camera - previousCamera).abs(), lessThan(8));
        expect(game.over, isFalse);
        frames++;
      }
      expect(frames, greaterThan(350));
      expect(game.abducting, isFalse);
      expect(game.camera, greaterThan(initialCamera));
      expect(game.y, greaterThanOrEqualTo(600));
      expect(game.landings, 1);
      expect(game.vy, greaterThan(0));
      expect(game.ufoDepartureTime, greaterThan(0));
      expect(
        game.platforms.any(
          (platform) =>
              (platform.y - game.y).abs() < 10 &&
              platform.kind != LeapPlatformKind.storm,
        ),
        isTrue,
      );
    },
  );

  test(
    'Abduction follows moving landing platforms and protects the passenger',
    () {
      final game = LeapGame(random: math.Random(8));
      game.generate(1100);
      final target = LeapPlatform(
        5000,
        245,
        760,
        90,
        LeapPlatformKind.cloud,
        motion: 20,
      );
      game.platforms
        ..clear()
        ..add(target)
        ..add(LeapPlatform(5001, 180, 300, 360, LeapPlatformKind.storm));
      game.pickups
        ..clear()
        ..add(LeapPickup(180, 106, LeapPickupKind.ufo));
      game.step(.01, 0, 640);
      final startY = game.y;
      final startTime = game.abductionTime;
      game.step(0, -1, 640);
      expect(game.y, startY);
      expect(game.abductionTime, startTime);
      for (var frame = 0; frame < 450 && game.abducting; frame++) {
        game.step(1 / 120, -1, 640);
      }
      expect(game.abducting, isFalse);
      expect(game.over, isFalse);
      expect(game.x, closeTo(target.x, 1));
      expect(game.y, closeTo(target.y, 5));
      expect(target.vanishingAt, isNotNull);
      game.step(.1, -1, 640);
      expect(game.vx, lessThan(0));
    },
  );

  test('The route keeps making meaningful horizontal direction changes', () {
    final game = LeapGame(random: math.Random(14));
    game.generate(6000);
    final route =
        game.platforms
            .where((platform) => platform.kind != LeapPlatformKind.storm)
            .toList()
          ..sort((a, b) => a.y.compareTo(b.y));
    final deltas = <double>[
      for (var i = 1; i < route.length; i++)
        route[i].baseX - route[i - 1].baseX,
    ];
    final directionChanges = <int>[
      for (var i = 1; i < deltas.length; i++)
        if (deltas[i].sign != deltas[i - 1].sign) i,
    ];

    expect(deltas.every((delta) => delta.abs() >= 35), isTrue);
    expect(directionChanges.length, greaterThan(deltas.length * .3));
  });
}
