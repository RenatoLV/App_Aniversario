import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

enum FootballResult { goal, save, wide, weak }

/// Fixed court coordinates and small physics steps keep touch and collision
/// behavior identical on a small phone, a tablet and a slow frame.
class FootballGame extends ChangeNotifier {
  static const width = 400.0, height = 580.0, radius = 18.0;
  static const origin = Offset(200, 516);
  static const goalY = 140.0, leftPost = 64.0, rightPost = 336.0;
  static const keeperY = 190.0;
  Offset ball = origin, velocity = Offset.zero;
  Offset? aim;
  double keeperX = 200, age = 0, rotation = 0, _resultAge = 0;
  int goals = 0, streak = 0, attempts = 0;
  bool flying = false, touchedPost = false;
  FootballResult? result;
  final void Function(FootballResult, int, int)? onResult;
  FootballGame({this.onResult});
  double get keeperSpeed => (100 + goals * 5).clamp(100, 170).toDouble();
  double get reactionDelay => (.24 - goals * .012).clamp(.12, .24);
  Rect get keeper =>
      Rect.fromCenter(center: Offset(keeperX, keeperY), width: 68, height: 60);
  bool get ready => !flying && result == null;

  void point(Offset? end) {
    if (!ready) return;
    aim = end;
    notifyListeners();
  }

  bool shoot(Offset start, Offset end, double seconds) {
    aim = null;
    final swipe = end - start;
    if (!ready ||
        !swipe.dx.isFinite ||
        !swipe.dy.isFinite ||
        !seconds.isFinite ||
        swipe.distance < 12) {
      notifyListeners();
      return false;
    }
    var impulse = swipe / seconds.clamp(.06, 5) * 1.25;
    if (impulse.distance > 1250) impulse = impulse / impulse.distance * 1250;
    velocity = impulse;
    flying = true;
    attempts++;
    age = 0;
    touchedPost = false;
    notifyListeners();
    return true;
  }

  void tick(double dt) {
    if (!flying || !dt.isFinite || dt <= 0) return;
    var remaining = math.min(dt, .1);
    while (remaining > .000001) {
      final step = math.min(remaining, 1 / 120);
      remaining -= step;
      _step(step);
      if (!flying) break;
    }
    notifyListeners();
  }

  void _step(double dt) {
    age += dt;
    if (result != null) {
      _resultAge += dt;
      if (_resultAge >= 1.25) {
        _reset();
        return;
      }
    }
    if (result == null && age >= reactionDelay && velocity.dy < -20) {
      final travel = ((keeperY - ball.dy) / velocity.dy).clamp(0.0, 1.0);
      final target = (ball.dx + velocity.dx * travel * .7).clamp(100.0, 300.0);
      keeperX += (target - keeperX).clamp(-keeperSpeed * dt, keeperSpeed * dt);
    }
    final old = ball;
    ball += velocity * dt;
    rotation += velocity.dx * dt / radius;
    velocity *= math.exp(-.48 * dt);
    for (final x in [leftPost, rightPost]) {
      final delta = ball - Offset(x, goalY), distance = delta.distance;
      if (distance < radius + 7) {
        final normal = distance > .0001 ? delta / distance : const Offset(0, 1);
        ball = Offset(x, goalY) + normal * (radius + 7);
        final dot = velocity.dx * normal.dx + velocity.dy * normal.dy;
        if (dot < 0) velocity -= normal * (1.8 * dot);
        touchedPost = true;
      }
    }
    if (result == null &&
        velocity.dy < 0 &&
        (ball -
                    Offset(
                      ball.dx.clamp(keeper.left, keeper.right),
                      ball.dy.clamp(keeper.top, keeper.bottom),
                    ))
                .distance <=
            radius) {
      ball = Offset(ball.dx, keeper.bottom + radius);
      velocity = Offset(
        velocity.dx + (ball.dx - keeperX) * 3,
        velocity.dy.abs() * .65,
      );
      _finish(FootballResult.save);
    }
    if (result == null && old.dy > goalY && ball.dy <= goalY) {
      // Interpolate the line crossing instead of scoring from a later frame.
      final t = (old.dy - goalY) / (old.dy - ball.dy);
      final crossingX = old.dx + (ball.dx - old.dx) * t;
      if (crossingX > leftPost + radius + 7 &&
          crossingX < rightPost - radius - 7) {
        ball = Offset(crossingX, goalY - 14);
        velocity = Offset.zero;
        _finish(FootballResult.goal);
      }
    }
    if (ball.dx < radius || ball.dx > width - radius) {
      ball = Offset(ball.dx.clamp(radius, width - radius), ball.dy);
      velocity = Offset(-velocity.dx * .6, velocity.dy);
    }
    if (result == null &&
        (ball.dy < goalY - 70 ||
            ball.dy > height + radius ||
            age > 4.5 ||
            velocity.distance < 35)) {
      _finish(
        velocity.distance < 35 ? FootballResult.weak : FootballResult.wide,
      );
    }
  }

  void _finish(FootballResult outcome) {
    if (result != null) return;
    result = outcome;
    _resultAge = 0;
    if (outcome == FootballResult.goal) {
      goals++;
      streak++;
    } else {
      streak = 0;
    }
    onResult?.call(outcome, streak, attempts);
  }

  void _reset() {
    ball = origin;
    velocity = Offset.zero;
    flying = false;
    result = null;
    aim = null;
    age = 0;
    keeperX = 200;
  }

  void cancelAim() {
    aim = null;
    notifyListeners();
  }
}
