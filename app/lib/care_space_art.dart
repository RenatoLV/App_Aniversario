import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'house_day_cycle.dart';

enum CareSpace { kitchen, bath, wardrobe }

class CareSpacePainter extends CustomPainter {
  final CareSpace space;
  final HouseLight light;
  const CareSpacePainter(this.space, this.light);
  @override
  void paint(Canvas c, Size size) {
    c.save();
    c.scale(size.width / 400, size.height / 330);
    Paint ink(Color color, [double? width]) => Paint()
      ..color = color
      ..style = width == null ? PaintingStyle.fill : PaintingStyle.stroke
      ..strokeWidth = width ?? 1
      ..strokeCap = StrokeCap.round;
    void box(Rect at, Color color, [double radius = 8]) => c.drawRRect(
      RRect.fromRectAndRadius(at, Radius.circular(radius)),
      ink(color),
    );
    final wood = light.tint(const Color(0xffc7a17d), const Color(0xff625764));
    c.drawRect(const Rect.fromLTWH(0, 259, 400, 71), ink(wood));
    for (var y = 276.0; y < 330; y += 18) {
      c.drawLine(
        Offset(0, y),
        Offset(400, y),
        ink(const Color(0xffa48367).withValues(alpha: .3), 1),
      );
    }
    if (space == CareSpace.bath) {
      for (var x = 0.0; x < 400; x += 40) {
        for (var y = 65.0; y < 259; y += 40) {
          box(
            Rect.fromLTWH(x + 2, y + 2, 36, 36),
            light.tint(const Color(0xffeffaf4), const Color(0xff354c5a)),
            4,
          );
        }
      }
      box(const Rect.fromLTWH(19, 109, 67, 97), const Color(0xffb5d5d5), 19);
      box(
        const Rect.fromLTWH(25, 115, 55, 82),
        light.tint(const Color(0xffdceff2), const Color(0xff557b90)),
        16,
      );
      box(const Rect.fromLTWH(304, 153, 77, 10), wood, 4);
      box(const Rect.fromLTWH(310, 129, 21, 23), const Color(0xffe5a6b4), 5);
      box(const Rect.fromLTWH(338, 119, 17, 33), const Color(0xff86bfb8), 5);
      box(const Rect.fromLTWH(350, 177, 25, 55), const Color(0xfff3ebdb), 6);
      c.drawLine(const Offset(350, 174), const Offset(379, 174), ink(wood, 4));
      c.drawOval(
        const Rect.fromLTWH(105, 264, 198, 37),
        ink(const Color(0xff8bbabc)),
      );
    } else if (space == CareSpace.kitchen) {
      box(
        const Rect.fromLTWH(22, 90, 68, 79),
        light.tint(const Color(0xfffdf4dd), const Color(0xff576475)),
        10,
      );
      box(
        const Rect.fromLTWH(28, 96, 56, 62),
        light.tint(const Color(0xffbce2e8), const Color(0xff364e72)),
        7,
      );
      c.drawLine(
        const Offset(56, 96),
        const Offset(56, 158),
        ink(const Color(0xfffff0d7), 3),
      );
      c.drawLine(
        const Offset(28, 128),
        const Offset(84, 128),
        ink(const Color(0xfffff0d7), 3),
      );
      box(
        const Rect.fromLTWH(296, 184, 95, 75),
        light.tint(const Color(0xff98bdae), const Color(0xff4a676a)),
        8,
      );
      box(const Rect.fromLTWH(290, 174, 110, 15), const Color(0xffead6b3), 5);
      c.drawLine(
        const Offset(342, 194),
        const Offset(342, 251),
        ink(const Color(0xff71988b), 1),
      );
      box(const Rect.fromLTWH(304, 200, 19, 5), const Color(0xffd5ae6d), 2);
      box(const Rect.fromLTWH(357, 200, 19, 5), const Color(0xffd5ae6d), 2);
      c.drawOval(
        const Rect.fromLTWH(32, 236, 62, 14),
        ink(const Color(0xffdb9fad)),
      );
      c.drawOval(
        const Rect.fromLTWH(37, 234, 52, 9),
        ink(const Color(0xfff6dbbf)),
      );
      box(const Rect.fromLTWH(313, 139, 19, 35), const Color(0xfff3e6c6), 6);
      box(const Rect.fromLTWH(347, 146, 24, 28), const Color(0xffd59885), 7);
      c.drawLine(
        const Offset(359, 146),
        const Offset(359, 121),
        ink(const Color(0xff689c7c), 3),
      );
      c.drawOval(
        const Rect.fromLTWH(345, 120, 17, 11),
        ink(const Color(0xff8fb69a)),
      );
    } else {
      box(const Rect.fromLTWH(294, 87, 87, 172), wood, 11);
      box(
        const Rect.fromLTWH(301, 94, 34, 155),
        light.tint(const Color(0xfff1e2c7), const Color(0xff766d7c)),
        5,
      );
      box(
        const Rect.fromLTWH(341, 94, 33, 155),
        light.tint(const Color(0xffe6d2b8), const Color(0xff6b6176)),
        5,
      );
      c.drawCircle(const Offset(329, 175), 2.5, ink(const Color(0xff9d7c55)));
      c.drawCircle(const Offset(347, 175), 2.5, ink(const Color(0xff9d7c55)));
      box(const Rect.fromLTWH(22, 90, 62, 142), const Color(0xffd7b99a), 24);
      box(
        const Rect.fromLTWH(29, 97, 48, 126),
        light.tint(const Color(0xffd9edf0), const Color(0xff698196)),
        19,
      );
      c.drawLine(
        const Offset(37, 109),
        const Offset(67, 137),
        ink(Colors.white.withValues(alpha: .4), 3),
      );
      box(const Rect.fromLTWH(30, 252, 59, 16), const Color(0xffc998a6), 8);
      c.drawOval(
        const Rect.fromLTWH(122, 262, 157, 42),
        ink(light.tint(const Color(0xffd8bfde), const Color(0xff796f94))),
      );
    }
    c.restore();
  }

  @override
  bool shouldRepaint(CareSpacePainter old) =>
      old.space != space || old.light != light;
}

class DressingSparklesPainter extends CustomPainter {
  final double progress;
  const DressingSparklesPainter(this.progress);
  @override
  void paint(Canvas c, Size size) {
    final alpha = math.sin(progress * math.pi);
    final ink = Paint()
      ..color = const Color(0xffffd477).withValues(alpha: alpha)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 8; i++) {
      final angle = i * math.pi / 4;
      final radius = size.width * (.28 + progress * .12);
      final at = Offset(
        size.width / 2 + math.cos(angle) * radius,
        size.height * .49 + math.sin(angle) * radius,
      );
      final span = 3 + alpha * 3;
      c.drawLine(at - Offset(span, 0), at + Offset(span, 0), ink);
      c.drawLine(at - Offset(0, span), at + Offset(0, span), ink);
    }
  }

  @override
  bool shouldRepaint(DressingSparklesPainter old) => progress != old.progress;
}
