import 'dart:math' as math;
import 'package:flutter/material.dart';

/// One coordinate contract for illustration, grip anchors and touch controls.
class LuckyCabinetGeometry {
  const LuckyCabinetGeometry(this.portrait);
  final bool portrait;
  Size get design => portrait ? const Size(460, 585) : const Size(1000, 420);
  Rect get board => portrait
      ? const Rect.fromLTWH(22, 205, 400, 245)
      : const Rect.fromLTWH(200, 75, 590, 175);
  Rect get maru => portrait
      ? const Rect.fromLTWH(8, 72, 145, 145)
      : const Rect.fromLTWH(8, 75, 176, 176);
  Rect get lady => portrait
      ? const Rect.fromLTWH(307, 72, 145, 145)
      : const Rect.fromLTWH(815, 75, 176, 176);
  Offset get grip => portrait ? const Offset(145, 177) : const Offset(187, 175);
  Offset get pivot =>
      portrait ? const Offset(180, 200) : const Offset(199, 240);
  Offset get ladyRest =>
      portrait ? const Offset(403, 205) : const Offset(947, 246);
  Offset leverGrip(double pull) {
    final arm = grip - pivot;
    final angle = -pull * 1.25;
    return pivot +
        Offset(
          arm.dx * math.cos(angle) - arm.dy * math.sin(angle),
          arm.dx * math.sin(angle) + arm.dy * math.cos(angle),
        );
  }

  Rect leverHit(Size size) {
    final rect = project(
      Rect.fromCenter(
        center: grip + const Offset(10, 12),
        width: 84,
        height: 132,
      ),
      size,
    );
    return Rect.fromCenter(
      center: rect.center,
      width: math.max(48, rect.width),
      height: math.max(48, rect.height),
    );
  }

  Rect get console => portrait
      ? const Rect.fromLTWH(12, 450, 430, 85)
      : const Rect.fromLTWH(175, 250, 650, 120);
  Rect get spin => portrait
      ? const Rect.fromLTWH(163, 455, 138, 74)
      : const Rect.fromLTWH(410, 260, 180, 100);

  double scale(Size size) =>
      math.min(size.width / design.width, size.height / design.height);
  Offset origin(Size size) {
    final s = scale(size);
    return Offset(
      (size.width - design.width * s) / 2,
      (size.height - design.height * s) / 2,
    );
  }

  Rect project(Rect rect, Size size) {
    final s = scale(size);
    return (rect.topLeft * s + origin(size)) & (rect.size * s);
  }

  Rect button(Size size) {
    final r = project(spin, size);
    return Rect.fromCenter(
      center: r.center,
      width: math.max(114, r.width),
      height: math.max(74, r.height),
    );
  }

  double symbolSize(Size size) =>
      math.min(board.width / 760 * 123.6, board.height / 420 * 102.6) *
      scale(size);
}
