import 'dart:math' as math;

enum LeapPlatformKind { cloud, rock, airplane, storm }

enum LeapPickupKind { coin, rocket, ufo, umbrella }

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
  final bool trampoline;
  double x;
  bool facingRight = true;
  double? vanishingAt;
  double? springAt;
  LeapPlatform(
    this.id,
    this.baseX,
    this.y,
    this.width,
    this.kind, {
    this.motion = 0,
    this.trampoline = false,
  }) : x = baseX;
}

class LeapPickup {
  final double x, y;
  final LeapPickupKind kind;
  final int value;
  bool taken = false;
  LeapPickup(this.x, this.y, this.kind, {this.value = 1});
}

/// World units equal logical pixels at a width of 360. Positive Y is upwards.
class LeapGame {
  static const width = 360.0, catWidth = 46.0, catHeight = 52.0;
  static const gravity = 950.0, jumpSpeed = 480.0;
  static const abductionDuration = 3.2;
  static const springSpeed = 650.0, umbrellaDuration = 8.0;
  static const stageStretch =
      3.2; // Twice the former scenery duration; physics unchanged.
  static const meadowHeight = 1600.0 * stageStretch;
  static const neighborhoodHeight = 3200.0 * stageStretch;
  static const cityHeight = 5200.0 * stageStretch;
  static const skyscraperHeight = 7600.0 * stageStretch;
  static const upperSkyHeight = 10000.0 * stageStretch;
  static const spaceHeight = 13200.0 * stageStretch;
  static const heavenHeight = 18000.0 * stageStretch;
  final math.Random random;
  final List<LeapPlatform> platforms = [];
  final List<LeapPickup> pickups = [];
  double x = 180, y = 80, vx = 0, vy = jumpSpeed;
  double camera = 0, maxHeight = 80, clock = 0, rocketTime = 0, alienTime = 0;
  double umbrellaTime = 0;
  double abductionTime = 0, ufoDepartureTime = 0, ufoX = 0, ufoY = 0;
  double _abductionFromX = 0, _abductionFromY = 0;
  LeapPlatform? _abductionTarget;
  double _top = 80, _pathX = 180;
  double _nextPowerHeight = 1040;
  int _powerSequence = 0;
  double _routeDirection = 1;
  int _sameDirectionSteps = 0;
  int _nextId = 1, coins = 0, rockets = 0, ufos = 0, landings = 0;
  int umbrellas = 0, springJumps = 0;
  int _rewardedZone = 0;
  static int zoneReward(LeapWorldZone zone) =>
      zone == LeapWorldZone.heaven ? 200 : zone.index * 30;
  bool over = false;
  String endReason = '';
  LeapGame({math.Random? random}) : random = random ?? math.Random() {
    platforms.add(LeapPlatform(0, 180, 80, 120, LeapPlatformKind.rock));
    generate(900);
  }
  int get points => math.max(0, (maxHeight - 80).floor());
  bool get boosting => rocketTime > 0;
  bool get abducting => _abductionTarget != null;
  double get abductionProgress =>
      (abductionTime / abductionDuration).clamp(0.0, 1.0);
  bool get alien => abducting || alienTime > 0;
  bool get umbrellaOpen =>
      umbrellaTime > 0 && vy < 0 && !abducting && !boosting;

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
      final difficulty = (_top / (9000 * stageStretch)).clamp(0.0, 1.0);
      // Taller, irregular steps stay below the ~121-unit jump apex.
      final gap =
          90 + difficulty * 5 + random.nextDouble() * (18 + difficulty * 3);
      _top += gap;
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
      final landingTime =
          (jumpSpeed + math.sqrt(jumpSpeed * jumpSpeed - 2 * gravity * gap)) /
          gravity;
      // Leave room for reversing velocity and two platforms moving apart.
      final horizontalTravel = math.min(
        65 + random.nextDouble() * (40 + difficulty * 8),
        230 * landingTime - 56,
      );
      var nextX = _pathX + direction * horizontalTravel;
      if (nextX < 54 || nextX > 306) {
        _routeDirection = -direction;
        _sameDirectionSteps = 1;
        nextX = _pathX + _routeDirection * horizontalTravel;
      }
      _pathX = nextX.clamp(54.0, 306.0);
      // One shared schedule halves the former combined rocket/UFO density,
      // including umbrellas rather than adding a third independent stream.
      final powerup = _top >= _nextPowerHeight
          ? const [
              LeapPickupKind.rocket,
              LeapPickupKind.umbrella,
              LeapPickupKind.ufo,
            ][_powerSequence % 3]
          : null;
      // Powers sit above a stationary, reachable platform. Their spacing is
      // bounded, independent of the longer scenery stages.
      final moving =
          powerup == null &&
          _top > 650 &&
          random.nextDouble() < .28 + difficulty * .16;
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
        powerup != null
            ? 82
            : kind == LeapPlatformKind.airplane
            ? 76 + random.nextDouble() * 20
            : 60 + random.nextDouble() * 28 - difficulty * 8,
        kind,
        motion: moving ? 12 + random.nextDouble() * (6 + difficulty * 4) : 0,
        trampoline:
            powerup == null &&
            !moving &&
            _top > 500 &&
            random.nextDouble() < .07,
      );
      platforms.add(platform);
      if (powerup == null && random.nextDouble() < .55) {
        final roll = random.nextDouble();
        pickups.add(
          LeapPickup(
            _pathX,
            _top + 30,
            LeapPickupKind.coin,
            value: roll < .15
                ? 10
                : roll < .45
                ? 5
                : 1,
          ),
        );
      }
      if (powerup != null) {
        pickups.add(LeapPickup(_pathX, _top + 42, powerup));
        _powerSequence++;
        _nextPowerHeight = _top + 1200 + random.nextDouble() * 350;
      }
      // Storms are optional hazards beside, never in place of the reachable route.
      if (_top > 700 && random.nextDouble() < .18) {
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
    umbrellaTime = math.max(0, umbrellaTime - dt);
    if (ufoDepartureTime > 0) {
      ufoDepartureTime = math.max(0, ufoDepartureTime - dt);
      ufoX += dt * 100;
      ufoY += dt * 420;
    }
    for (final p in platforms) {
      final oldX = p.x;
      p.x = (p.baseX + math.sin(clock * 1.5 + p.id) * p.motion).clamp(
        p.width / 2,
        width - p.width / 2,
      );
      if ((p.x - oldX).abs() > .0001) p.facingRight = p.x > oldX;
    }
    if (abducting) {
      _advanceAbduction(dt);
      _updateWorld(viewportHeight);
      return;
    }
    vx += (direction * 230 - vx) * math.min(1, dt * 12);
    x = (x + vx * dt) % width;
    final previousY = y;
    if (boosting) {
      rocketTime = math.max(0, rocketTime - dt);
      vy = 760;
    } else {
      vy -= gravity * dt;
      if (umbrellaTime > 0 && vy < 0) vy = math.max(vy, -135);
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
          vy = p.trampoline ? springSpeed : jumpSpeed;
          if (p.trampoline) {
            springJumps++;
            p.springAt = clock;
          }
          landings++;
          if (p.kind == LeapPlatformKind.cloud) p.vanishingAt = clock;
          break;
        }
      }
    }
    var collectedUfo = false;
    for (final pickup in pickups) {
      if (!pickup.taken &&
          (x - pickup.x).abs() < 27 &&
          (y + catHeight * .5 - pickup.y).abs() < 32) {
        pickup.taken = true;
        switch (pickup.kind) {
          case LeapPickupKind.coin:
            coins += pickup.value;
          case LeapPickupKind.rocket:
            rockets++;
            rocketTime = 2.4;
            vy = 760;
          case LeapPickupKind.ufo:
            ufos++;
            collectedUfo = true;
          case LeapPickupKind.umbrella:
            umbrellas++;
            umbrellaTime = umbrellaDuration;
        }
      }
    }
    if (collectedUfo) _beginAbduction();
    _updateWorld(viewportHeight);
  }

  void _updateWorld(double viewportHeight) {
    maxHeight = math.max(maxHeight, y);
    while (_rewardedZone < zone.index) {
      _rewardedZone++;
      coins += zoneReward(LeapWorldZone.values[_rewardedZone]);
    }
    // Keep the gameplay camera locked to the cat's scroll threshold. A lagged
    // camera can leave the generated platforms outside the viewport during a
    // jump, making the game look like it changed to an empty map.
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

  void _beginAbduction() {
    final from = y;
    generate(from + 950);
    final candidates =
        platforms
            .where(
              (platform) =>
                  platform.y >= from + 520 &&
                  platform.y <= from + 850 &&
                  platform.kind != LeapPlatformKind.storm &&
                  platform.vanishingAt == null,
            )
            .toList()
          ..sort((a, b) {
            final aSafe = a.kind == LeapPlatformKind.cloud ? 1 : 0;
            final bSafe = b.kind == LeapPlatformKind.cloud ? 1 : 0;
            final safety = aSafe.compareTo(bSafe);
            return safety != 0 ? safety : a.y.compareTo(b.y);
          });
    if (candidates.isEmpty) return;
    _abductionTarget = candidates.first;
    _abductionFromX = x;
    _abductionFromY = y;
    abductionTime = 0;
    ufoDepartureTime = 0;
    ufoX = x;
    ufoY = y + 150;
    rocketTime = 0;
    umbrellaTime = 0;
    vx = vy = 0;
  }

  void _advanceAbduction(double dt) {
    final target = _abductionTarget!;
    abductionTime = math.min(abductionDuration, abductionTime + dt);
    final t = abductionProgress;
    double smooth(double value) {
      final v = value.clamp(0.0, 1.0);
      return v * v * (3 - 2 * v);
    }

    final capture = smooth(t / .2);
    final travel = smooth((t - .2) / .6);
    final release = smooth((t - .8) / .2);
    x = _abductionFromX + (target.x - _abductionFromX) * travel;
    y = t < .2
        ? _abductionFromY + capture * 50
        : t < .8
        ? _abductionFromY + 50 + (target.y + 65 - _abductionFromY - 50) * travel
        : target.y + 65 * (1 - release);
    ufoX = x;
    ufoY = t < .8 ? y + 90 + (1 - capture) * 60 : target.y + 155;
    // During the beam ride, steering, gravity, pickups and hazards are suspended.
    // The destination keeps moving normally; the ship follows its live position.
    vx = vy = 0;
    if (abductionTime >= abductionDuration) {
      y = target.y;
      x = target.x;
      vy = target.trampoline ? springSpeed : jumpSpeed;
      if (target.trampoline) {
        springJumps++;
        target.springAt = clock;
      }
      landings++;
      if (target.kind == LeapPlatformKind.cloud) target.vanishingAt = clock;
      _abductionTarget = null;
      alienTime = 2.2;
      ufoDepartureTime = .65;
    }
  }
}
