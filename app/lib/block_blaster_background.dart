import 'package:flutter/material.dart';

import 'paw_background.dart';

/// A fixed arcade wallpaper behind the scrolling board and controls.
class BlockBlasterBackground extends StatelessWidget {
  final Widget child;
  const BlockBlasterBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      const Positioned.fill(
        child: IgnorePointer(
          child: RepaintBoundary(
            child: CustomPaint(painter: _BlockBlasterWallpaper()),
          ),
        ),
      ),
      SafeArea(child: child),
    ],
  );
}

class _BlockBlasterWallpaper extends CustomPainter {
  const _BlockBlasterWallpaper();

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xff38205c), Color(0xff22173e), Color(0xff172c43)],
          stops: [0, .52, 1],
        ).createShader(bounds),
    );
    for (final glow in [
      (center: const Alignment(-1.15, -.55), color: const Color(0xff9964d8)),
      (center: const Alignment(1.1, .6), color: const Color(0xff53b4ad)),
    ]) {
      canvas.drawRect(
        bounds,
        Paint()
          ..shader = RadialGradient(
            center: glow.center,
            radius: .95,
            colors: [
              glow.color.withValues(alpha: .22),
              glow.color.withValues(alpha: 0),
            ],
          ).createShader(bounds),
      );
    }
    const PawPatternPainter(
      spacing: 88,
      pawScale: 1.05,
      opacity: .18,
      colors: [Color(0xffc8a9ec), Color(0xfff3b9d0), Color(0xff8bcac1)],
    ).paint(canvas, size);
    // Sparse little glints fill the gaps between the paired pawprints.
    final ink = Paint()..color = const Color(0xffe2d2ff).withValues(alpha: .16);
    for (var row = 0; row * 88 < size.height; row++) {
      for (var col = 0; col * 88 < size.width; col++) {
        final x = col * 88 + (row.isEven ? 63.0 : 20.0);
        final y = row * 88 + 68.0;
        canvas.drawCircle(Offset(x, y), (row + col).isEven ? 1.4 : 2.1, ink);
        if ((row + col) % 4 == 0) {
          canvas.drawPath(
            Path()
              ..moveTo(x + 12, y - 5)
              ..quadraticBezierTo(x + 12, y, x + 17, y)
              ..quadraticBezierTo(x + 12, y, x + 12, y + 5)
              ..quadraticBezierTo(x + 12, y, x + 7, y)
              ..quadraticBezierTo(x + 12, y, x + 12, y - 5),
            ink,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(_BlockBlasterWallpaper oldDelegate) => false;
}
