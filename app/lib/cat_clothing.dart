import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'cat_care.dart';

// All coordinates use the character's 100 × 100 anatomy and its own transforms.
void paintCatBodyClothing(Canvas canvas, CatOutfit outfit) {
  final item = clothingById(outfit.body);
  if (item != null) {
    final shirt = Path()
      ..moveTo(35, 62)
      ..quadraticBezierTo(50, 69, 65, 62)
      ..lineTo(78, 69)
      ..lineTo(71, 78)
      ..lineTo(69, 87)
      ..quadraticBezierTo(50, 94, 31, 87)
      ..lineTo(29, 78)
      ..lineTo(22, 69)
      ..close();
    canvas.drawPath(shirt, Paint()..color = item.color);
    canvas.save();
    canvas.clipPath(shirt);
    if (item.id == 'shirt_stripes') {
      for (var y = 71.0; y < 92; y += 6) {
        canvas.drawLine(
          Offset(22, y),
          Offset(78, y),
          Paint()
            ..color = const Color(0xfff8f2da)
            ..strokeWidth = 2.8,
        );
      }
    } else {
      final star = Path();
      for (var i = 0; i < 10; i++) {
        final angle = -math.pi / 2 + i * math.pi / 5, r = i.isEven ? 8.0 : 3.5;
        final x = 50 + math.cos(angle) * r, y = 78 + math.sin(angle) * r;
        if (i == 0) {
          star.moveTo(x, y);
        } else {
          star.lineTo(x, y);
        }
      }
      canvas.drawPath(star..close(), Paint()..color = const Color(0xffffd677));
    }
    canvas.restore();
    canvas.drawPath(
      shirt,
      Paint()
        ..color = Colors.black.withValues(alpha: .18)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }
  final neck = clothingById(outfit.neck);
  if (neck != null) {
    if (neck.id == 'bandana') {
      canvas.drawPath(
        Path()
          ..moveTo(30, 64)
          ..quadraticBezierTo(50, 70, 70, 64)
          ..lineTo(51, 80)
          ..close(),
        Paint()..color = neck.color,
      );
      canvas.drawCircle(
        const Offset(51, 70),
        1.4,
        Paint()..color = const Color(0xffffe5c0),
      );
    } else {
      canvas.drawArc(
        const Rect.fromLTWH(30, 57, 40, 14),
        0,
        math.pi,
        false,
        Paint()
          ..color = neck.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4,
      );
      final charm = Paint()..color = const Color(0xffffd46a);
      if (neck.id == 'collar_heart') {
        canvas.drawPath(
          Path()
            ..moveTo(50, 77)
            ..cubicTo(38, 70, 44, 65, 50, 70)
            ..cubicTo(56, 65, 62, 70, 50, 77)
            ..close(),
          charm,
        );
      } else {
        canvas.drawCircle(const Offset(50, 72), 4, charm);
        canvas.drawLine(
          const Offset(48, 74),
          const Offset(52, 74),
          Paint()
            ..color = const Color(0xff9c7628)
            ..strokeWidth = 1.2,
        );
      }
    }
  }
}

void paintCatHeadClothing(
  Canvas canvas,
  CatOutfit outfit, {
  bool alien = false,
}) {
  final hat = clothingById(outfit.head);
  if (hat != null) {
    canvas.save();
    if (alien) {
      canvas.translate(50, 0);
      canvas.scale(.78);
      canvas.translate(-50, -1);
    }
    if (hat.id == 'beanie') {
      canvas.drawPath(
        Path()
          ..moveTo(31, 26)
          ..quadraticBezierTo(32, 8, 50, 9)
          ..quadraticBezierTo(68, 8, 69, 26)
          ..close(),
        Paint()..color = hat.color,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(29, 23, 42, 7),
          const Radius.circular(3),
        ),
        Paint()..color = const Color(0xffc4b4ec),
      );
      canvas.drawCircle(
        const Offset(50, 9),
        4.5,
        Paint()..color = const Color(0xffe0d4f8),
      );
      for (var x = 38.0; x < 68; x += 6) {
        canvas.drawLine(
          Offset(x, 15),
          Offset(x, 22),
          Paint()
            ..color = Colors.white.withValues(alpha: .22)
            ..strokeWidth = 1,
        );
      }
    } else {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(34, 13, 32, 16),
          const Radius.circular(6),
        ),
        Paint()..color = hat.color,
      );
      canvas.drawRect(
        const Rect.fromLTWH(34, 23, 32, 4),
        Paint()..color = const Color(0xff846742),
      );
      canvas.drawOval(
        const Rect.fromLTWH(24, 25, 52, 8),
        Paint()..color = const Color(0xffddc18b),
      );
    }
    canvas.restore();
  }
  if (outfit.eyes == 'glasses') {
    final y = alien ? 33.0 : 43.0;
    final ink = Paint()
      ..color = const Color(0xff41617f)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.3;
    for (final x in [38.0, 62.0]) {
      canvas.drawCircle(
        Offset(x, y),
        10,
        Paint()..color = const Color(0x255fcdea),
      );
      canvas.drawCircle(Offset(x, y), 10, ink);
      canvas.drawLine(
        Offset(x - 4, y - 5),
        Offset(x + 2, y - 7),
        Paint()
          ..color = const Color(0x99ffffff)
          ..strokeWidth = 1.3,
      );
    }
    canvas.drawLine(Offset(48, y), Offset(52, y), ink);
    canvas.drawLine(Offset(28, y - 1), Offset(22, y - 4), ink);
    canvas.drawLine(Offset(72, y - 1), Offset(78, y - 4), ink);
  }
}
