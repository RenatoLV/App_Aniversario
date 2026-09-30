import 'dart:math' as math;

enum LeapPlatformKind { cloud, rock, storm }

enum LeapPickupKind { coin, rocket }

class LeapPlatform {
  final int id;
  final double baseX, y, width;
  final LeapPlatformKind kind;
  final double motion;
  double x;
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
  final math.Random random;
  final List<LeapPlatform> platforms = [];
  final List<LeapPickup> pickups = [];
  double x = 180, y = 80, vx = 0, vy = jumpSpeed;
  double camera = 0, maxHeight = 80, clock = 0, rocketTime = 0;
  double _top = 80, _pathX = 180;
  int _nextId = 1, coins = 0, landings = 0;
  bool over = false;
  String endReason = '';
  LeapGame({math.Random? random}) : random = random ?? math.Random() {
    platforms.add(LeapPlatform(0, 180, 80, 120, LeapPlatformKind.rock));
    generate(900);
  }
  int get points => math.max(0, (maxHeight - 80).floor());
  bool get boosting => rocketTime > 0;

  void generate(double ceiling) {
    while (_top < ceiling) {
      final difficulty = (_top / 5000).clamp(0.0, 1.0);
      _top += 54 + random.nextDouble() * (22 + difficulty * 17);
      _pathX = (_pathX + (random.nextDouble() * 2 - 1) * (90 + difficulty * 25))
          .clamp(42.0, 318.0);
      final moving = _top > 850 && random.nextDouble() < .22;
      final platform = LeapPlatform(
        _nextId++,
        _pathX,
        _top,
        86 - difficulty * 20,
        random.nextBool() ? LeapPlatformKind.cloud : LeapPlatformKind.rock,
        motion: moving ? 12 + difficulty * 10 : 0,
      );
      platforms.add(platform);
      if (random.nextDouble() < .55) {
        pickups.add(LeapPickup(_pathX, _top + 30, LeapPickupKind.coin));
      }
      if (_top > 500 && random.nextDouble() < .05) {
        pickups.add(LeapPickup(_pathX, _top + 52, LeapPickupKind.rocket));
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
    for (final p in platforms) {
      p.x = (p.baseX + math.sin(clock * 1.5 + p.id) * p.motion).clamp(
        p.width / 2,
        width - p.width / 2,
      );
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
    if (vy < 0) {
      for (final p in platforms) {
        if (previousY >= p.y &&
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
          break;
        }
      }
    }
    for (final pickup in pickups) {
      if (!pickup.taken &&
          (x - pickup.x).abs() < 27 &&
          (y + catHeight * .5 - pickup.y).abs() < 32) {
        pickup.taken = true;
        if (pickup.kind == LeapPickupKind.coin) {
          coins++;
        } else {
          rocketTime = 2.4;
          vy = 760;
        }
      }
    }
    maxHeight = math.max(maxHeight, y);
    camera = math.max(camera, y - viewportHeight * .57);
    generate(camera + viewportHeight + 180);
    platforms.removeWhere((p) => p.y < camera - 150);
    pickups.removeWhere((p) => p.y < camera - 150);
    if (y < camera - 85) {
      over = true;
      endReason = '¡Nos faltó una nubecita!';
    }
  }
}
