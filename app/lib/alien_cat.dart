import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'cat_character.dart';
import 'cat_clothing.dart';

/// A complete alien silhouette, rather than eyes layered over the normal cat.
class AlienCatPainter extends CustomPainter {
  final CatKind cat;
  final double phase, blink;
  final CatOutfit outfit;
  final double cleanliness;

  const AlienCatPainter({
    required this.cat,
    this.phase = 0,
    this.blink = 0,
    this.outfit = const CatOutfit(),
    this.cleanliness = 100,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 100, size.height / 100);
    final lady = cat == CatKind.lady;
    final light = lady ? const Color(0xffc4eca1) : const Color(0xffb0e783);
    final green = lady ? const Color(0xff6bb84e) : const Color(0xff56aa37);
    const dark = Color(0xff235d31);
    final outline = Paint()
      ..color = const Color(0xff33623e)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;

    void skin(Path path, Rect bounds, {bool head = false}) {
      canvas.drawPath(
        path,
        Paint()
          ..shader = RadialGradient(
            center: head
                ? const Alignment(.35, -.65)
                : const Alignment(.4, -.4),
            radius: 1.05,
            colors: [light, green, dark],
            stops: const [0, .52, 1],
          ).createShader(bounds),
      );
      canvas.drawPath(path, outline);
    }

    // Slim neck, tucked paws and a curled tail keep the cat recognisable.
    final sway = math.sin(phase * math.pi * 2) * 3;
    final tail = Path()
      ..moveTo(36, 87)
      ..cubicTo(14, 94, 7, 76, 15 + sway, 66)
      ..cubicTo(19 + sway, 60, 24, 64, 20, 70)
      ..cubicTo(15, 81, 24, 85, 37, 79)
      ..close();
    skin(tail, const Rect.fromLTWH(9, 62, 30, 30));
    final body = Path()
      ..moveTo(40, 54)
      ..cubicTo(43, 68, 28, 74, 29, 86)
      ..cubicTo(29, 98, 70, 98, 72, 87)
      ..cubicTo(74, 74, 58, 69, 60, 54)
      ..close();
    skin(body, const Rect.fromLTWH(28, 54, 45, 42));
    canvas.save();
    canvas.translate(50, 0);
    canvas.scale(.8, 1);
    canvas.translate(-50, 0);
    paintCatBodyClothing(canvas, outfit);
    paintCatDirt(canvas, cleanliness);
    canvas.restore();
    canvas.drawPath(
      Path()
        ..moveTo(46, 62)
        ..quadraticBezierTo(43, 81, 41, 89)
        ..quadraticBezierTo(50, 93, 59, 89)
        ..quadraticBezierTo(54, 73, 55, 62)
        ..close(),
      Paint()..color = light.withValues(alpha: .24),
    );
    for (final x in [36.0, 54.0]) {
      final paw = Path()..addOval(Rect.fromLTWH(x, 85, 14, 10));
      skin(paw, Rect.fromLTWH(x, 85, 14, 10));
      for (var i = 1; i < 3; i++) {
        canvas.drawLine(
          Offset(x + 4 + i * 3, 91),
          Offset(x + 4 + i * 3, 93),
          outline..color = dark.withValues(alpha: .45),
        );
      }
    }
    outline.color = const Color(0xff33623e);

    // Small swept-back ears, a broad cranium and the long feline muzzle.
    final head = Path()
      ..moveTo(20, 25)
      ..quadraticBezierTo(15, 14, 17, 4)
      ..quadraticBezierTo(24, 6, 31, 13)
      ..cubicTo(42, 6, 60, 6, 70, 13)
      ..quadraticBezierTo(79, 5, 84, 4)
      ..quadraticBezierTo(86, 16, 80, 27)
      ..cubicTo(82, 43, 70, 50, 65, 59)
      ..cubicTo(60, 69, 42, 71, 35, 60)
      ..cubicTo(30, 51, 18, 43, 20, 25)
      ..close();
    skin(head, const Rect.fromLTWH(16, 7, 69, 63), head: true);
    for (final mirror in [false, true]) {
      canvas.save();
      if (mirror) {
        canvas.translate(100, 0);
        canvas.scale(-1, 1);
      }
      canvas.drawPath(
        Path()
          ..moveTo(20, 9)
          ..quadraticBezierTo(20, 17, 24, 22)
          ..lineTo(28, 15)
          ..close(),
        Paint()..color = dark.withValues(alpha: .55),
      );
      // Almond eyes slope upward at the outer corners, like the reference.
      canvas.save();
      canvas.translate(33, 32);
      canvas.scale(1, (1 - blink * .9).clamp(.1, 1.0));
      canvas.translate(-33, -32);
      final eye = Path()
        ..moveTo(22, 25)
        ..cubicTo(30, 23, 41, 28, 44, 36)
        ..cubicTo(34, 41, 22, 37, 22, 25)
        ..close();
      canvas.drawPath(
        eye,
        Paint()
          ..color = const Color(0xff244731)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.3),
      );
      canvas.drawPath(
        eye,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xff142820), Color(0xff010604), Color(0xff07110d)],
          ).createShader(const Rect.fromLTWH(22, 24, 22, 16)),
      );
      canvas.drawOval(
        const Rect.fromLTWH(24, 26, 2.6, 5.2),
        Paint()
          ..color = const Color(
            0xffe1ffe2,
          ).withValues(alpha: mirror ? .9 : .55),
      );
      canvas.drawCircle(
        const Offset(28, 28),
        .75,
        Paint()..color = const Color(0x88eaffeb),
      );
      canvas.restore();
      canvas.restore();
    }

    // A pale bridge leads to a tiny triangular cat nose, not a human mouth.
    canvas.drawPath(
      Path()
        ..moveTo(49, 19)
        ..cubicTo(45, 33, 46, 40, 43, 48)
        ..quadraticBezierTo(50, 54, 57, 48)
        ..cubicTo(53, 41, 53, 29, 52, 19)
        ..close(),
      Paint()
        ..shader = LinearGradient(
          colors: [
            dark.withValues(alpha: .03),
            light.withValues(alpha: .68),
            dark.withValues(alpha: .12),
          ],
        ).createShader(const Rect.fromLTWH(43, 20, 14, 33)),
    );
    canvas.drawPath(
      Path()
        ..moveTo(45, 51)
        ..quadraticBezierTo(50, 49, 55, 51)
        ..lineTo(50, 55)
        ..close(),
      Paint()..color = const Color(0xff2d7039),
    );
    canvas.drawPath(
      Path()
        ..moveTo(50, 55)
        ..lineTo(50, 58)
        ..quadraticBezierTo(46, 61, 42, 58)
        ..moveTo(50, 58)
        ..quadraticBezierTo(54, 61, 58, 58),
      outline
        ..color = dark.withValues(alpha: .8)
        ..strokeWidth = .9,
    );
    final whiskers = Paint()
      ..color = const Color(0xffd3ebbb).withValues(alpha: .75)
      ..strokeWidth = .7
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    for (var i = 0; i < 3; i++) {
      final y = 51.0 + i * 3;
      canvas.drawPath(
        Path()
          ..moveTo(37, y)
          ..quadraticBezierTo(25, y - 2, 12, 47.0 + i * 7),
        whiskers,
      );
      canvas.drawPath(
        Path()
          ..moveTo(63, y)
          ..quadraticBezierTo(75, y - 2, 88, 47.0 + i * 7),
        whiskers,
      );
    }
    paintCatDirt(canvas, cleanliness, head: true);
    paintCatHeadClothing(canvas, outfit, alien: true);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant AlienCatPainter oldDelegate) =>
      cat != oldDelegate.cat ||
      phase != oldDelegate.phase ||
      blink != oldDelegate.blink ||
      outfit != oldDelegate.outfit ||
      cleanliness != oldDelegate.cleanliness;
}
