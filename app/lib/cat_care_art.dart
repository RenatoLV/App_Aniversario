import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'cat_care.dart';

enum BathTool { soap, shower }

class FridgePainter extends CustomPainter {
  const FridgePainter();
  @override
  void paint(Canvas c, Size size) {
    c.save();
    c.scale(size.width / 80, size.height / 110);
    c.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(12, 4, 57, 98),
        const Radius.circular(9),
      ),
      _p(const Color(0xff9cbdb3)),
    );
    c.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(8, 1, 56, 98),
        const Radius.circular(9),
      ),
      _p(const Color(0xfff7fcf7)),
    );
    c.drawLine(
      const Offset(9, 33),
      const Offset(63, 33),
      _p(const Color(0xffb4d3cb), 2),
    );
    c.drawLine(
      const Offset(52, 14),
      const Offset(52, 24),
      _p(const Color(0xff7caaa0), 3),
    );
    c.drawLine(
      const Offset(52, 47),
      const Offset(52, 66),
      _p(const Color(0xff7caaa0), 3),
    );
    c.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(19, 46, 19, 18),
        const Radius.circular(3),
      ),
      _p(const Color(0xffead596)),
    );
    c.drawCircle(const Offset(29, 54), 4, _p(const Color(0xffe995a0)));
    for (var i = 0; i < 3; i++) {
      final a = i * math.pi / 3;
      c.drawLine(
        Offset(31 - math.cos(a) * 7, 18 - math.sin(a) * 7),
        Offset(31 + math.cos(a) * 7, 18 + math.sin(a) * 7),
        _p(const Color(0xff9bbecb), 1.5),
      );
    }
    c.drawLine(
      const Offset(17, 100),
      const Offset(17, 105),
      _p(const Color(0xff75978e), 4),
    );
    c.drawLine(
      const Offset(54, 100),
      const Offset(54, 105),
      _p(const Color(0xff75978e), 4),
    );
    c.restore();
  }

  @override
  bool shouldRepaint(FridgePainter old) => false;
}

class FoodIcon extends StatelessWidget {
  final CatFood food;
  final double size;
  const FoodIcon({super.key, required this.food, this.size = 40});
  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: FoodPainter(food));
}

class FoodPainter extends CustomPainter {
  final CatFood food;
  const FoodPainter(this.food);
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 100, size.height / 100);
    paintFood(canvas, food);
    canvas.restore();
  }

  @override
  bool shouldRepaint(FoodPainter old) => food != old.food;
}

Paint _p(Color color, [double? width]) => Paint()
  ..color = color
  ..style = width == null ? PaintingStyle.fill : PaintingStyle.stroke
  ..strokeWidth = width ?? 1
  ..strokeCap = StrokeCap.round
  ..strokeJoin = StrokeJoin.round;

void paintFood(Canvas c, CatFood food) {
  final color = food.color;
  const light = Color(0xffffefd2), outline = Color(0xff765944);
  void bowl(Color fill) {
    c.drawPath(
      Path()
        ..moveTo(12, 54)
        ..quadraticBezierTo(19, 91, 50, 89)
        ..quadraticBezierTo(81, 91, 88, 54)
        ..close(),
      _p(fill),
    );
    c.drawOval(const Rect.fromLTWH(12, 44, 76, 24), _p(light));
    c.drawCircle(const Offset(50, 76), 4, _p(const Color(0xfffff4e2)));
  }

  switch (food) {
    case CatFood.kibble:
      bowl(const Color(0xffdba1a6));
      for (var i = 0; i < 14; i++) {
        c.drawOval(
          Rect.fromCenter(
            center: Offset(24 + (i % 5) * 13.0, 48 + (i ~/ 5) * 5.0),
            width: 9,
            height: 6,
          ),
          _p(i.isEven ? color : outline),
        );
      }
    case CatFood.fish:
      c.drawPath(
        Path()
          ..moveTo(30, 51)
          ..lineTo(9, 32)
          ..lineTo(9, 70)
          ..close(),
        _p(const Color(0xff8bc1ce)),
      );
      c.drawOval(const Rect.fromLTWH(23, 29, 64, 42), _p(color));
      c.drawPath(
        Path()
          ..moveTo(45, 30)
          ..lineTo(58, 16)
          ..lineTo(66, 31)
          ..close(),
        _p(const Color(0xff91c5d4)),
      );
      c.drawCircle(const Offset(74, 44), 4, _p(outline));
      for (var x = 39.0; x < 68; x += 10) {
        c.drawArc(Rect.fromLTWH(x, 40, 13, 16), -1, 2, false, _p(light, 2));
      }
    case CatFood.churu:
      c.save();
      c.translate(50, 50);
      c.rotate(-.28);
      c.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(-15, -38, 30, 76),
          const Radius.circular(5),
        ),
        _p(color),
      );
      c.drawRect(const Rect.fromLTWH(-15, -32, 30, 7), _p(light));
      c.drawRect(
        const Rect.fromLTWH(-15, 27, 30, 6),
        _p(const Color(0xffb15b80)),
      );
      c.drawCircle(const Offset(0, 4), 8, _p(light));
      for (final x in [-8.0, 0.0, 8.0]) {
        c.drawCircle(Offset(x, -6), 3, _p(light));
      }
      c.drawOval(
        const Rect.fromLTWH(-6, -46, 12, 16),
        _p(const Color(0xffdfc399)),
      );
      c.restore();
    case CatFood.tuna:
      c.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(19, 34, 62, 48),
          const Radius.circular(6),
        ),
        _p(color),
      );
      c.drawOval(
        const Rect.fromLTWH(18, 24, 64, 23),
        _p(const Color(0xffc4d0cd)),
      );
      c.drawOval(
        const Rect.fromLTWH(24, 28, 52, 16),
        _p(const Color(0xffd1a99b)),
      );
      for (var x = 30.0; x < 75; x += 9) {
        c.drawLine(Offset(x, 30), Offset(x - 4, 40), _p(light, 2));
      }
      c.drawRect(const Rect.fromLTWH(19, 54, 62, 17), _p(light));
      c.drawOval(const Rect.fromLTWH(42, 57, 18, 10), _p(color));
    case CatFood.salmon:
      c.drawOval(
        const Rect.fromLTWH(10, 70, 80, 15),
        _p(const Color(0xffc8dfdb)),
      );
      c.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(18, 33, 67, 42),
          const Radius.circular(12),
        ),
        _p(color),
      );
      for (var x = 30.0; x < 80; x += 14) {
        c.drawPath(
          Path()
            ..moveTo(x, 35)
            ..lineTo(x - 6, 52)
            ..lineTo(x + 1, 71),
          _p(light, 3),
        );
      }
    case CatFood.chicken:
      c.save();
      c.translate(50, 50);
      c.rotate(-.55);
      c.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(5, -6, 32, 12),
          const Radius.circular(5),
        ),
        _p(light),
      );
      c.drawCircle(const Offset(35, -5), 6, _p(light));
      c.drawCircle(const Offset(35, 5), 6, _p(light));
      c.drawOval(const Rect.fromLTWH(-38, -24, 55, 49), _p(color));
      c.drawOval(
        const Rect.fromLTWH(-29, -17, 32, 12),
        _p(const Color(0xffebc593)),
      );
      c.restore();
    case CatFood.shrimp:
      c.drawArc(
        const Rect.fromLTWH(20, 18, 58, 64),
        -math.pi * .7,
        math.pi * 1.65,
        false,
        _p(color, 20),
      );
      for (var i = 0; i < 5; i++) {
        final a = -math.pi * .65 + i * .55;
        c.drawLine(
          Offset(49 + math.cos(a) * 19, 50 + math.sin(a) * 22),
          Offset(49 + math.cos(a) * 35, 50 + math.sin(a) * 39),
          _p(light, 2),
        );
      }
      c.drawPath(
        Path()
          ..moveTo(30, 76)
          ..lineTo(8, 74)
          ..lineTo(15, 94)
          ..close(),
        _p(const Color(0xffd77370)),
      );
      c.drawCircle(const Offset(65, 28), 2.4, _p(outline));
    case CatFood.egg:
      c.drawOval(const Rect.fromLTWH(20, 12, 60, 78), _p(light));
      c.drawOval(const Rect.fromLTWH(29, 33, 42, 47), _p(Colors.white));
      c.drawCircle(const Offset(50, 57), 15, _p(color));
      c.drawCircle(const Offset(45, 52), 4, _p(const Color(0xffffdf86)));
    case CatFood.pumpkin:
      for (final x in [23.0, 37.0, 51.0]) {
        c.drawOval(
          Rect.fromLTWH(x, 28, 30, 55),
          _p(x == 37 ? color : const Color(0xffcc8d42)),
        );
      }
      c.drawPath(
        Path()
          ..moveTo(46, 32)
          ..quadraticBezierTo(42, 17, 58, 17)
          ..lineTo(60, 23)
          ..quadraticBezierTo(50, 21, 54, 32)
          ..close(),
        _p(const Color(0xff79a16c)),
      );
      c.drawOval(
        const Rect.fromLTWH(55, 68, 29, 18),
        _p(const Color(0xffffd191)),
      );
    case CatFood.broth:
      bowl(color);
      c.drawOval(
        const Rect.fromLTWH(19, 48, 62, 16),
        _p(const Color(0xffd5b878)),
      );
      for (final x in [33.0, 51.0, 68.0]) {
        c.drawPath(
          Path()
            ..moveTo(x, 41)
            ..cubicTo(x - 9, 31, x + 8, 23, x, 13),
          _p(const Color(0xffc4ddd4), 3),
        );
      }
      for (final p in [const Offset(35, 52), const Offset(58, 56)]) {
        c.drawCircle(p, 3, _p(const Color(0xff72a785)));
      }
  }
}

/// One meal prop, paced bites and a gentle approach/finish, without flying food.
class FeedingScenePainter extends CustomPainter {
  final CatFood food;
  final double phase;
  const FeedingScenePainter({required this.food, required this.phase});
  @override
  void paint(Canvas c, Size size) {
    c.save();
    c.scale(size.width / 100, size.height / 100);
    final t = phase.clamp(0.0, 1.0);
    final approach = Curves.easeInOut.transform((t / .2).clamp(0.0, 1.0));
    final finish = Curves.easeInOut.transform(((t - .8) / .2).clamp(0.0, 1.0));
    final eating = approach * (1 - finish);
    final cycle = ((t - .2) / .6).clamp(0.0, 1.0) * 3;
    final bite = math.sin((cycle % 1) * math.pi);
    final liquid = food == CatFood.churu || food == CatFood.broth;
    void prop(Offset at, double span, {double rotation = 0}) {
      c.save();
      c.translate(at.dx, at.dy);
      c.rotate(rotation);
      c.scale(span / 100);
      c.translate(-50, -50);
      paintFood(c, food);
      c.restore();
    }

    if (food == CatFood.churu) {
      // A single tube held beside the muzzle; its tip follows the lean.
      prop(Offset(60, 80 - eating * 4), 32, rotation: -.55);
      if (t > .2 && t < .8) {
        c.drawOval(
          Rect.fromCenter(
            center: Offset(52, 67 + bite),
            width: 3.2,
            height: 2 + bite * 2,
          ),
          _p(const Color(0xffed8ca3)),
        );
      }
    } else {
      final bowl =
          food == CatFood.kibble ||
          food == CatFood.tuna ||
          food == CatFood.broth;
      if (!bowl) {
        c.drawOval(
          const Rect.fromLTWH(32, 88, 36, 8),
          _p(const Color(0xffb8ceca)),
        );
        c.drawOval(
          const Rect.fromLTWH(34, 88, 32, 5),
          _p(const Color(0xffedf4e8)),
        );
      }
      final span = food == CatFood.broth ? 32.0 : 28.0;
      // Food stays on its dish and diminishes after each bite.
      final remaining = 1 - .16 * cycle.floor().clamp(0, 3);
      prop(
        Offset(50, food == CatFood.broth ? 87 : 89),
        bowl ? span : span * remaining,
        rotation: food == CatFood.fish ? -.12 : 0,
      );
      if (t > .2 && t < .8) {
        if (liquid) {
          c.drawOval(
            Rect.fromCenter(
              center: Offset(50, 69 + bite),
              width: 3,
              height: 2 + bite * 2,
            ),
            _p(const Color(0xffed8ca3)),
          );
        } else {
          // A small morsel, rather than an entire fish or plate, meets the mouth.
          final lift = Curves.easeInOut.transform((bite * 1.3).clamp(0.0, 1.0));
          final x = food == CatFood.chicken || food == CatFood.salmon
              ? 54.0
              : 47.0;
          final color = switch (food) {
            CatFood.egg => const Color(0xffffda73),
            CatFood.tuna => const Color(0xffc79489),
            CatFood.chicken => const Color(0xffe3b382),
            _ => food.color,
          };
          c.drawOval(
            Rect.fromCenter(
              center: Offset(x + (50 - x) * lift, 84 - 15 * lift),
              width: 3.5 * (1 - lift * .5),
              height: 2.5 * (1 - lift * .5),
            ),
            _p(color),
          );
        }
      }
      if (food == CatFood.broth) {
        for (var i = 0; i < 2; i++) {
          final steam = (t * 1.5 + i * .5) % 1;
          c.drawPath(
            Path()
              ..moveTo(42 + i * 13.0, 80 - steam * 10)
              ..quadraticBezierTo(
                39 + i * 13.0,
                76 - steam * 10,
                43 + i * 13.0,
                72 - steam * 10,
              ),
            _p(const Color(0xfff8f1dc).withValues(alpha: (1 - steam) * .6), .8),
          );
        }
      }
    }
    c.restore();
  }

  @override
  bool shouldRepaint(FeedingScenePainter old) =>
      food != old.food || phase != old.phase;
}

class BathPropIcon extends StatelessWidget {
  final BathTool tool;
  final double size;
  const BathPropIcon({super.key, required this.tool, this.size = 48});
  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: BathPropPainter(tool));
}

class BathPropPainter extends CustomPainter {
  final BathTool tool;
  const BathPropPainter(this.tool);
  @override
  void paint(Canvas c, Size size) {
    c.save();
    c.scale(size.width / 100, size.height / 100);
    if (tool == BathTool.soap) {
      c.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(14, 35, 72, 43),
          const Radius.circular(14),
        ),
        _p(const Color(0xffd887ab)),
      );
      c.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(14, 27, 72, 43),
          const Radius.circular(14),
        ),
        _p(const Color(0xffefb7cf)),
      );
      c.drawOval(
        const Rect.fromLTWH(32, 36, 36, 23),
        _p(const Color(0xfff8d5e2)),
      );
      for (final p in [
        const Offset(21, 19),
        const Offset(74, 18),
        const Offset(84, 31),
      ]) {
        c.drawCircle(p, 7, _p(const Color(0xffe4f7f6)));
        c.drawCircle(p - const Offset(2, 2), 2, _p(Colors.white));
      }
    } else {
      c.drawPath(
        Path()
          ..moveTo(75, 83)
          ..lineTo(59, 44)
          ..quadraticBezierTo(51, 21, 33, 27),
        _p(const Color(0xff7298a8), 12),
      );
      c.save();
      c.translate(32, 29);
      c.rotate(-.35);
      c.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(-21, -5, 42, 15),
          const Radius.circular(5),
        ),
        _p(const Color(0xffadcbd0)),
      );
      c.drawLine(
        const Offset(-19, 9),
        const Offset(19, 9),
        _p(const Color(0xff557d91), 3),
      );
      c.restore();
      for (var i = 0; i < 4; i++) {
        final x = 14 + i * 9.0;
        c.drawLine(
          Offset(x, 44),
          Offset(x - 4, 63),
          _p(const Color(0xff73c8db), 3),
        );
      }
    }
    c.restore();
  }

  @override
  bool shouldRepaint(BathPropPainter old) => tool != old.tool;
}

class BathScenePainter extends CustomPainter {
  final double foam, rinse, phase;
  final BathTool tool;
  final Offset? hand;
  const BathScenePainter({
    required this.foam,
    required this.rinse,
    required this.phase,
    required this.tool,
    this.hand,
  });
  @override
  void paint(Canvas c, Size size) {
    final bubbles = foam * (1 - rinse);
    for (var i = 0; i < 24; i++) {
      final t = (phase + i * .137) % 1;
      final x = size.width * (.22 + (i * .23 % .56)),
          y = size.height * (.82 - t * .45);
      final radius = size.width * (.018 + (i % 4) * .009);
      c.drawCircle(
        Offset(x, y),
        radius,
        _p(
          const Color(
            0xfff2ffff,
          ).withValues(alpha: (bubbles * 1.3).clamp(0.0, .92)),
        ),
      );
      c.drawCircle(
        Offset(x - radius * .3, y - radius * .3),
        radius * .23,
        _p(Colors.white.withValues(alpha: bubbles)),
      );
    }
    if (hand != null) {
      c.save();
      c.translate(hand!.dx - 23, hand!.dy - 23);
      BathPropPainter(tool).paint(c, const Size.square(46));
      c.restore();
      if (tool == BathTool.shower) {
        final ink = _p(const Color(0xff5ebfd7).withValues(alpha: .8), 2);
        for (var i = 0; i < 6; i++) {
          final x = hand!.dx - 21 + i * 7,
              y =
                  hand!.dy +
                  12 +
                  ((phase * 2 + i * .13) % 1) * size.height * .25;
          c.drawLine(Offset(x, y), Offset(x - 4, y + 13), ink);
        }
      }
    }
  }

  @override
  bool shouldRepaint(BathScenePainter old) =>
      foam != old.foam ||
      rinse != old.rinse ||
      phase != old.phase ||
      tool != old.tool ||
      hand != old.hand;
}
