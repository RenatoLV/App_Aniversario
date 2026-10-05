import 'dart:math' as math;
import 'package:flutter/foundation.dart';
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
  final double spacing, opacity, pawScale;
  final List<Color> colors;
  const PawPatternPainter({
    this.spacing = 118,
    this.opacity = .15,
    this.pawScale = 1,
    this.colors = const [Color(0xff93b4a1), Color(0xffc7aa89)],
  });
  @override
  void paint(Canvas canvas, Size size) {
    for (var row = 0; row * spacing < size.height + 50; row++) {
      for (var col = 0; col * spacing < size.width + 50; col++) {
        final x = col * spacing + (row.isEven ? .237 : .737) * spacing;
        final y = row * spacing + spacing * .305;
        final ink = Paint()
          ..color = colors[row % colors.length].withValues(alpha: opacity);
        canvas.save();
        canvas.translate(x, y);
        canvas.rotate((col + row).isEven ? -.38 : .32);
        canvas.scale(pawScale * ((col + row) % 3 == 0 ? 1.15 : .9));
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
  bool shouldRepaint(PawPatternPainter oldDelegate) =>
      oldDelegate.spacing != spacing ||
      oldDelegate.opacity != opacity ||
      oldDelegate.pawScale != pawScale ||
      !listEquals(oldDelegate.colors, colors);
}
