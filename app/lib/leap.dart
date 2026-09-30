import 'dart:math' as math;

enum LeapPlatformKind { cloud, rock, airplane, storm }

enum LeapPickupKind { coin, rocket, ufo }

enum LeapWorldZone {
  underground,
  meadow,
  neighborhood,
  city,
  skyscrapers,
  upperSky,
  space,
  heaven,
}

class LeapPlatform {
  final int id;
  final double baseX, y, width;
  final LeapPlatformKind kind;
  final double motion;
  double x;
  bool facingRight = true;
  double? vanishingAt;
  LeapPlatform(
    this.id,
    this.baseX,
    this.y,
    this.width,
    this.kind, {
    this.motion = 0,
  }) : x = baseX;
}

class LeapPickup {
  final double x, y;
  final LeapPickupKind kind;
  bool taken = false;
  LeapPickup(this.x, this.y, this.kind);
}

/// World units equal logical pixels at a width of 360. Positive Y is upwards.
class LeapGame {
  static const width = 360.0, catWidth = 46.0, catHeight = 52.0;
  static const gravity = 950.0, jumpSpeed = 480.0;
  static const meadowHeight = 1600.0;
  static const neighborhoodHeight = 3200.0;
  static const cityHeight = 5200.0;
  static const skyscraperHeight = 7600.0;
  static const upperSkyHeight = 10000.0;
  static const spaceHeight = 13200.0;
  static const heavenHeight = 18000.0;
  final math.Random random;
  final List<LeapPlatform> platforms = [];
  final List<LeapPickup> pickups = [];
  double x = 180, y = 80, vx = 0, vy = jumpSpeed;
  double camera = 0, maxHeight = 80, clock = 0, rocketTime = 0, alienTime = 0;
  double _top = 80, _pathX = 180;
  double _routeDirection = 1;
  int _sameDirectionSteps = 0;
  int _nextId = 1, coins = 0, rockets = 0, ufos = 0, landings = 0;
  bool over = false;
  String endReason = '';
  LeapGame({math.Random? random}) : random = random ?? math.Random() {
    platforms.add(LeapPlatform(0, 180, 80, 120, LeapPlatformKind.rock));
    generate(900);
  }
  int get points => math.max(0, (maxHeight - 80).floor());
  bool get boosting => rocketTime > 0;
  bool get alien => alienTime > 0;

  LeapWorldZone zoneAt(double height) {
    if (height < meadowHeight) return LeapWorldZone.underground;
    if (height < neighborhoodHeight) return LeapWorldZone.meadow;
    if (height < cityHeight) return LeapWorldZone.neighborhood;
    if (height < skyscraperHeight) return LeapWorldZone.city;
    if (height < upperSkyHeight) return LeapWorldZone.skyscrapers;
    if (height < spaceHeight) return LeapWorldZone.upperSky;
    if (height < heavenHeight) return LeapWorldZone.space;
    return LeapWorldZone.heaven;
  }

  LeapWorldZone get zone => zoneAt(maxHeight);

  void generate(double ceiling) {
    while (_top < ceiling) {
      final difficulty = (_top / 9000).clamp(0.0, 1.0);
      // A full jump rises about 121 units. These gaps demand more steering while
      // keeping every platform on the generated route physically reachable.
      _top += 75 + random.nextDouble() * (20 + difficulty * 20);
      var direction = random.nextBool() ? 1.0 : -1.0;
      if (_pathX < 105) {
        direction = 1;
      } else if (_pathX > 255) {
        direction = -1;
      } else if (_sameDirectionSteps >= 2) {
        direction = -_routeDirection;
      } else if (random.nextDouble() < .48) {
        direction = -_routeDirection;
      }
      _sameDirectionSteps = direction == _routeDirection
          ? _sameDirectionSteps + 1
          : 1;
      _routeDirection = direction;
      final horizontalTravel =
          42 + random.nextDouble() * (48 + difficulty * 15);
      var nextX = _pathX + direction * horizontalTravel;
      if (nextX < 42 || nextX > 318) {
        _routeDirection = -direction;
        _sameDirectionSteps = 1;
        nextX = _pathX + _routeDirection * horizontalTravel;
      }
      _pathX = nextX.clamp(42.0, 318.0);
      final moving = _top > 850 && random.nextDouble() < .22;
      final zone = zoneAt(_top);
      final cloudChance = switch (zone) {
        LeapWorldZone.underground => 0,
        LeapWorldZone.meadow => .08,
        LeapWorldZone.neighborhood => .18,
        LeapWorldZone.city => .35,
        LeapWorldZone.skyscrapers => .55,
        LeapWorldZone.upperSky ||
        LeapWorldZone.space ||
        LeapWorldZone.heaven => .82,
      };
      final skyTraffic =
          zone == LeapWorldZone.skyscrapers ||
          zone == LeapWorldZone.upperSky ||
          zone == LeapWorldZone.space ||
          zone == LeapWorldZone.heaven;
      final kind = skyTraffic && moving
          ? LeapPlatformKind.airplane
          : skyTraffic
          ? LeapPlatformKind.cloud
          : random.nextDouble() < cloudChance
          ? LeapPlatformKind.cloud
          : LeapPlatformKind.rock;
      final platform = LeapPlatform(
        _nextId++,
        _pathX,
        _top,
        kind == LeapPlatformKind.airplane ? 96 : 86 - difficulty * 20,
        kind,
        motion: moving ? 12 + difficulty * 10 : 0,
      );
      platforms.add(platform);
      if (random.nextDouble() < .55) {
        pickups.add(LeapPickup(_pathX, _top + 30, LeapPickupKind.coin));
      }
      if (_top > 500 && random.nextDouble() < .05) {
        pickups.add(LeapPickup(_pathX, _top + 52, LeapPickupKind.rocket));
      }
      if (_top > cityHeight && random.nextDouble() < .018) {
        pickups.add(LeapPickup(_pathX, _top + 48, LeapPickupKind.ufo));
      }
      // Storms are optional hazards beside, never in place of the reachable route.
      if (!skyTraffic && _top > 700 && random.nextDouble() < .18) {
        final hazardX = _pathX < 180 ? 305.0 : 55.0;
        if ((hazardX - _pathX).abs() > 120) {
          platforms.add(
            LeapPlatform(
              _nextId++,
              hazardX,
              _top + 18,
              60,
              LeapPlatformKind.storm,
            ),
          );
        }
      }
    }
  }

  void step(double dt, double direction, double viewportHeight) {
    if (over || dt <= 0) return;
    // Bound each step so a slow frame cannot tunnel through a platform.
    var remaining = math.min(dt, .1);
    while (remaining > 0 && !over) {
      final delta = math.min(remaining, 1 / 120);
      remaining -= delta;
      _advance(delta, direction.clamp(-1.0, 1.0), viewportHeight);
    }
  }

  void _advance(double dt, double direction, double viewportHeight) {
    clock += dt;
    alienTime = math.max(0, alienTime - dt);
    for (final p in platforms) {
      final oldX = p.x;
      p.x = (p.baseX + math.sin(clock * 1.5 + p.id) * p.motion).clamp(
        p.width / 2,
        width - p.width / 2,
      );
      if ((p.x - oldX).abs() > .0001) p.facingRight = p.x > oldX;
    }
    vx += (direction * 230 - vx) * math.min(1, dt * 12);
    x = (x + vx * dt).clamp(catWidth / 2, width - catWidth / 2);
    final previousY = y;
    if (boosting) {
      rocketTime = math.max(0, rocketTime - dt);
      vy = 760;
    } else {
      vy -= gravity * dt;
    }
    y += vy * dt;
    // Storms hurt on contact from either direction, including rocket ascent.
    for (final p in platforms.where((p) => p.kind == LeapPlatformKind.storm)) {
      final bottom = math.min(previousY, y);
      final top = math.max(previousY, y) + catHeight;
      if (bottom <= p.y + 6 &&
          top >= p.y - 24 &&
          (x - p.x).abs() < p.width / 2 + catWidth * .28) {
        over = true;
        rocketTime = 0;
        endReason = '¡Una nube eléctrica!';
        return;
      }
    }
    if (vy < 0) {
      for (final p in platforms) {
        if (p.vanishingAt == null &&
            previousY >= p.y &&
            y <= p.y &&
            (x - p.x).abs() < p.width / 2 + catWidth * .28) {
          if (p.kind == LeapPlatformKind.storm) {
            over = true;
            endReason = '¡Una nube eléctrica!';
            break;
          }
          y = p.y;
          vy = jumpSpeed;
          landings++;
          if (p.kind == LeapPlatformKind.cloud) p.vanishingAt = clock;
          break;
        }
      }
    }
    var teleport = false;
    for (final pickup in pickups) {
      if (!pickup.taken &&
          (x - pickup.x).abs() < 27 &&
          (y + catHeight * .5 - pickup.y).abs() < 32) {
        pickup.taken = true;
        switch (pickup.kind) {
          case LeapPickupKind.coin:
            coins++;
          case LeapPickupKind.rocket:
            rockets++;
            rocketTime = 2.4;
            vy = 760;
          case LeapPickupKind.ufo:
            ufos++;
            teleport = true;
        }
      }
    }
    if (teleport) _alienTeleport(viewportHeight);
    maxHeight = math.max(maxHeight, y);
    camera = math.max(camera, y - viewportHeight * .57);
    generate(camera + viewportHeight + 180);
    platforms.removeWhere(
      (p) =>
          p.y < camera - 150 ||
          (p.vanishingAt != null && clock - p.vanishingAt! > .65),
    );
    pickups.removeWhere((p) => p.y < camera - 150);
    if (y < camera - 85) {
      over = true;
      endReason = '¡Nos faltó una nubecita!';
    }
  }

  void _alienTeleport(double viewportHeight) {
    final from = y;
    generate(from + 950);
    final candidates =
        platforms
            .where(
              (platform) =>
                  platform.y >= from + 520 &&
                  platform.y <= from + 850 &&
                  platform.kind != LeapPlatformKind.storm,
            )
            .toList()
          ..sort((a, b) {
            final aSafe = a.kind == LeapPlatformKind.cloud ? 1 : 0;
            final bSafe = b.kind == LeapPlatformKind.cloud ? 1 : 0;
            final safety = aSafe.compareTo(bSafe);
            return safety != 0 ? safety : a.y.compareTo(b.y);
          });
    if (candidates.isEmpty) return;
    final target = candidates.first;
    x = target.x;
    y = target.y;
    vy = jumpSpeed;
    maxHeight = math.max(maxHeight, y);
    camera = math.max(camera, y - viewportHeight * .57);
    alienTime = 2.2;
  }
}
