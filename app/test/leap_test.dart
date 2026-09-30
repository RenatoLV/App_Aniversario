import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:nuestro_rincon/leap.dart';

void main() {
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

  test('A UFO teleports the cat onto a safe platform far above', () {
    final game = LeapGame(random: math.Random(8));
    game.pickups.add(LeapPickup(180, 106, LeapPickupKind.ufo));

    game.step(.01, 0, 640);

    expect(game.ufos, 1);
    expect(game.alien, isTrue);
    expect(game.y, greaterThanOrEqualTo(600));
    expect(
      game.platforms.any(
        (platform) =>
            (platform.y - game.y).abs() < 10 &&
            platform.kind != LeapPlatformKind.storm,
      ),
      isTrue,
    );
  });

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
