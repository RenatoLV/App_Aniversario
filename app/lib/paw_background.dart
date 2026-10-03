import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Quiet, non-interactive wallpaper underneath the menu content.
class PawBackground extends StatelessWidget {
  final Widget child;
  const PawBackground({super.key, required this.child});
  @override
  Widget build(BuildContext context) => Stack(
    children: [
      const Positioned.fill(
        child: IgnorePointer(
          child: RepaintBoundary(
            child: CustomPaint(painter: PawPatternPainter()),
          ),
        ),
      ),
      child,
    ],
  );
}

class PawPatternPainter extends CustomPainter {
  const PawPatternPainter();
  @override
  void paint(Canvas canvas, Size size) {
    for (var row = 0; row * 118 < size.height + 50; row++) {
      for (var col = 0; col * 118 < size.width + 50; col++) {
        final x = col * 118.0 + (row.isEven ? 28 : 87);
        final y = row * 118.0 + 36;
        final ink = Paint()
          ..color =
              (row.isEven ? const Color(0xff93b4a1) : const Color(0xffc7aa89))
                  .withValues(alpha: .15);
        canvas.save();
        canvas.translate(x, y);
        canvas.rotate((col + row).isEven ? -.38 : .32);
        canvas.scale((col + row) % 3 == 0 ? 1.15 : .9);
        canvas.drawPath(
          Path()
            ..moveTo(-10, 9)
            ..cubicTo(-12, 3, -5, 1, -4, -3)
            ..cubicTo(-2, -7, 2, -7, 4, -3)
            ..cubicTo(5, 1, 12, 3, 10, 9)
            ..cubicTo(8, 13, 4, 10, 0, 10)
            ..cubicTo(-4, 10, -8, 13, -10, 9)
            ..close(),
          ink,
        );
        for (var toe = 0; toe < 4; toe++) {
          final angle = -.9 + toe * .6;
          canvas.save();
          canvas.translate(math.sin(angle) * 12, -8 - math.cos(angle) * 5);
          canvas.rotate(angle * .4);
          canvas.drawOval(const Rect.fromLTWH(-3, -4, 6, 8), ink);
          canvas.restore();
        }
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(PawPatternPainter oldDelegate) => false;
}
