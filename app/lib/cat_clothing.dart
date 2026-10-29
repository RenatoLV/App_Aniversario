import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'cat_care.dart';

// Shared 100 × 100 anatomy: garments move with the cat's body/head transforms
// and adapt to horizontal rotation (`turn` in -1.0 .. 1.0, where |turn| > 0.65 is back view).
Paint _ink(Color color, [double? width]) => Paint()
  ..color = color
  ..style = width == null ? PaintingStyle.fill : PaintingStyle.stroke
  ..strokeWidth = width ?? 1
  ..strokeCap = StrokeCap.round
  ..strokeJoin = StrokeJoin.round;

Color _lighten(Color c, double amount) => Color.lerp(c, Colors.white, amount)!;
Color _darken(Color c, double amount) =>
    Color.lerp(c, const Color(0xff1a141c), amount)!;

Path _star(double x, double y, double r, {double innerFactor = .44}) {
  final p = Path();
  for (var i = 0; i < 10; i++) {
    final a = -math.pi / 2 + i * math.pi / 5;
    final radius = i.isEven ? r : r * innerFactor;
    final point = Offset(x + math.cos(a) * radius, y + math.sin(a) * radius);
    if (i == 0) {
      p.moveTo(point.dx, point.dy);
    } else {
      p.lineTo(point.dx, point.dy);
    }
  }
  return p..close();
}

Path _heart(double x, double y, double r) => Path()
  ..moveTo(x, y + r * 1.05)
  ..cubicTo(
    x - r * 1.95,
    y + r * .05,
    x - r * 1.05,
    y - r * 1.45,
    x,
    y - r * .48,
  )
  ..cubicTo(
    x + r * 1.05,
    y - r * 1.45,
    x + r * 1.95,
    y + r * .05,
    x,
    y + r * 1.05,
  )
  ..close();

void _flower(Canvas c, double x, double y, double r) {
  for (var i = 0; i < 5; i++) {
    final a = i * math.pi * 2 / 5;
    c.drawCircle(
      Offset(x + math.cos(a) * r * .64, y + math.sin(a) * r * .64),
      r * .5,
      _ink(const Color(0xfffff6df)),
    );
  }
  c.drawCircle(Offset(x, y), r * .36, _ink(const Color(0xffefbd54)));
  c.drawCircle(
    Offset(x - r * .1, y - r * .1),
    r * .12,
    _ink(const Color(0xfffff8e8)),
  );
}

void _bow(Canvas c, double x, double y, double r, Color color) {
  final dark = _darken(color, .22);
  final light = _lighten(color, .26);
  // Subtle drop shadow under the bow.
  c.drawOval(
    Rect.fromCenter(
      center: Offset(x, y + r * .22),
      width: r * 2.1,
      height: r * 1.1,
    ),
    _ink(const Color(0x24000000)),
  );
  for (final s in [-1.0, 1.0]) {
    final wing = Path()
      ..moveTo(x, y)
      ..cubicTo(
        x + s * r * .45,
        y - r * .85,
        x + s * r * 1.25,
        y - r * .78,
        x + s * r * 1.12,
        y,
      )
      ..cubicTo(
        x + s * r * 1.25,
        y + r * .78,
        x + s * r * .45,
        y + r * .85,
        x,
        y,
      )
      ..close();
    c.drawPath(wing, _ink(color));
    c.drawPath(wing, _ink(dark, .9));
    // Inner crease line for volume.
    c.drawLine(
      Offset(x + s * r * .2, y),
      Offset(x + s * r * .72, y - r * .16),
      _ink(dark.withValues(alpha: .45), .9),
    );
    c.drawLine(
      Offset(x + s * r * .2, y),
      Offset(x + s * r * .72, y + r * .16),
      _ink(light.withValues(alpha: .55), .8),
    );
  }
  c.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(x, y), width: r * .62, height: r * .72),
      Radius.circular(r * .24),
    ),
    _ink(light),
  );
  c.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(x, y), width: r * .62, height: r * .72),
      Radius.circular(r * .24),
    ),
    _ink(dark, .85),
  );
}

void _anchor(Canvas c, double x, double y, Color color) {
  final ink = _ink(color, 1.85);
  c.drawCircle(Offset(x, y - 6), 2.1, ink);
  c.drawLine(Offset(x, y - 3.8), Offset(x, y + 7), ink);
  c.drawLine(Offset(x - 4.2, y - 1), Offset(x + 4.2, y - 1), ink);
  c.drawPath(
    Path()
      ..moveTo(x - 7, y + 2)
      ..quadraticBezierTo(x - 5, y + 10, x, y + 7)
      ..quadraticBezierTo(x + 5, y + 10, x + 7, y + 2),
    ink,
  );
}

/// Renders a standalone miniature preview of a [CatClothing] item on a 100×100 logical canvas.
class ClothingPreviewIcon extends StatelessWidget {
  final CatClothing item;
  final double size;
  const ClothingPreviewIcon({super.key, required this.item, this.size = 44});

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: CustomPaint(painter: _ClothingPreviewPainter(item)),
  );
}

class _ClothingPreviewPainter extends CustomPainter {
  final CatClothing item;
  const _ClothingPreviewPainter(this.item);

  @override
  void paint(Canvas canvas, Size size) {
    paintCatClothingIcon(canvas, size, item);
  }

  @override
  bool shouldRepaint(covariant _ClothingPreviewPainter oldDelegate) =>
      oldDelegate.item.id != item.id;
}

void paintCatClothingIcon(Canvas canvas, Size size, CatClothing item) {
  canvas.save();
  canvas.scale(size.width / 100, size.height / 100);
  final outfit = const CatOutfit().withItem(item.slot, item.id);
  switch (item.slot) {
    case ClothingSlot.body:
      canvas.translate(50, 52);
      canvas.scale(1.48);
      canvas.translate(-50, -77);
      paintCatBodyClothing(canvas, outfit);
    case ClothingSlot.neck:
      canvas.translate(50, 52);
      canvas.scale(1.85);
      canvas.translate(-50, -69);
      paintCatBodyClothing(canvas, outfit);
    case ClothingSlot.head:
      canvas.translate(50, 56);
      canvas.scale(1.55);
      canvas.translate(-50, -21);
      paintCatHeadClothing(canvas, outfit);
    case ClothingSlot.eyes:
      canvas.translate(50, 52);
      canvas.scale(1.52);
      canvas.translate(-50, -43);
      paintCatHeadClothing(canvas, outfit);
  }
  canvas.restore();
}

void paintCatBodyClothing(
  Canvas canvas,
  CatOutfit outfit, {
  double turn = 0,
}) {
  final isBack = turn.abs() > 0.65;
  final shift = isBack
      ? -turn.sign * (1.0 - turn.abs()) * 18
      : turn * 11.0;

  final item = clothingById(outfit.body);
  if (item != null) {
    final light = _lighten(item.color, .22);
    final dark = _darken(item.color, .22);
    final outline = _darken(item.color, .36);
    final shirt = Path()
      ..moveTo(33, 59.5)
      ..quadraticBezierTo(50 + shift * .25, isBack ? 61.5 : 66.5, 67, 59.5)
      ..quadraticBezierTo(75.5, 62, 79.5, 70.5)
      ..quadraticBezierTo(78.5, 75.5, 72.5, 77)
      ..quadraticBezierTo(75.5, 85, 69.5, 92)
      ..quadraticBezierTo(50, 97.5, 30.5, 92)
      ..quadraticBezierTo(24.5, 85, 27.5, 77)
      ..quadraticBezierTo(21.5, 75.5, 20.5, 70.5)
      ..quadraticBezierTo(24.5, 62, 33, 59.5)
      ..close();

    // Soft cast shadow under bottom hem.
    canvas.drawPath(
      shirt.shift(const Offset(0, 1.4)),
      _ink(const Color(0x221b1318)),
    );

    canvas.drawPath(
      shirt,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment(-0.6 + turn * .4, -0.9),
          end: const Alignment(0.7, 1.0),
          colors: [light, item.color, dark],
          stops: const [0.0, 0.55, 1.0],
        ).createShader(const Rect.fromLTWH(20, 59, 60, 39)),
    );

    canvas.save();
    canvas.clipPath(shirt);
    canvas.translate(shift * .55, 0);
    const cream = Color(0xfffff0d6), gold = Color(0xffffd677);

    switch (item.id) {
      case 'casino_confetti':
        for (var i = 0; i < 18; i++) {
          final x = 26.0 + (i * 13 % 48), y = 68.0 + (i * 7 % 24);
          if (i % 3 == 0) {
            canvas.drawPath(_star(x, y, 2.5), _ink(gold));
          } else {
            canvas.drawLine(
              Offset(x, y),
              Offset(x + 1.9, y + 2.8),
              _ink(i.isEven ? cream : const Color(0xffef9fbe), 1.4),
            );
          }
        }
        if (!isBack) {
          _bow(canvas, 50, 68.5, 6.8, const Color(0xffef9fbe));
          canvas.drawPath(_heart(50, 82.5, 4.8), _ink(gold));
        } else {
          canvas.drawPath(_star(50, 77, 6.5), _ink(gold));
        }
      case 'casino_suit':
        if (!isBack) {
          // Crisp cream dress shirt placket inside the royal jacket.
          canvas.drawPath(
            Path()
              ..moveTo(41, 61)
              ..lineTo(50, 81)
              ..lineTo(59, 61)
              ..close(),
            _ink(cream),
          );
          // Tailored gold lapels with depth.
          canvas.drawPath(
            Path()
              ..moveTo(33, 61)
              ..lineTo(50, 83)
              ..lineTo(67, 61)
              ..lineTo(58.5, 64.5)
              ..lineTo(50, 76)
              ..lineTo(41.5, 64.5)
              ..close(),
            _ink(gold),
          );
          _bow(canvas, 50, 68.5, 5.8, const Color(0xff24836d));
          for (final y in [82.5, 88.5]) {
            canvas.drawCircle(Offset(50, y), 1.5, _ink(gold));
          }
          canvas.drawPath(_star(62.5, 78, 3.1), _ink(gold));
        } else {
          // Tailcoat back seam and golden waist buttons.
          canvas.drawLine(
            const Offset(50, 62),
            const Offset(50, 95),
            _ink(dark, 1.4),
          );
          canvas.drawPath(
            Path()
              ..moveTo(36, 79)
              ..quadraticBezierTo(50, 82, 64, 79),
            _ink(gold, 1.6),
          );
          for (final x in [45.5, 54.5]) {
            canvas.drawCircle(Offset(x, 80.5), 1.5, _ink(gold));
          }
        }
      case 'shirt_stripes':
        for (var y = 69.5; y < 93; y += 5.5) {
          canvas.drawPath(
            Path()
              ..moveTo(18, y)
              ..quadraticBezierTo(50, y + 2.2, 82, y),
            _ink(cream, 2.7),
          );
        }
      case 'shirt_star':
        canvas.drawPath(_star(50, 78, 9), _ink(_darken(gold, .15)));
        canvas.drawPath(_star(50, 77.5, 8.2), _ink(gold));
        canvas.drawCircle(
          const Offset(47.5, 75),
          1.4,
          _ink(const Color(0xfffff9e6)),
        );
      case 'shirt_check':
        for (var y = 64; y < 96; y += 7) {
          for (var x = 20; x < 81; x += 7) {
            if (((x - 20) + (y - 64)) ~/ 7 % 2 == 0) {
              canvas.drawRect(
                Rect.fromLTWH(x.toDouble(), y.toDouble(), 7, 7),
                _ink(cream.withValues(alpha: .9)),
              );
            }
          }
        }
      case 'shirt_sunset':
        canvas.drawCircle(
          const Offset(50, 76),
          8.8,
          _ink(const Color(0xffffb36b)),
        );
        canvas.drawCircle(const Offset(50, 76), 7.4, _ink(gold));
        for (var y = 79.0; y < 93; y += 3.8) {
          canvas.drawLine(
            Offset(22, y),
            Offset(78, y),
            _ink(const Color(0xffab6697), 2.1),
          );
        }
      case 'shirt_space':
        canvas.drawCircle(
          const Offset(50, 78),
          6.4,
          _ink(const Color(0xffbda3dd)),
        );
        canvas.drawCircle(
          const Offset(48, 76),
          2.2,
          _ink(const Color(0xffd9c8f0)),
        );
        canvas.save();
        canvas.translate(50, 78);
        canvas.rotate(-.38);
        canvas.drawOval(
          const Rect.fromLTWH(-11, -3.2, 22, 6.4),
          _ink(gold, 1.7),
        );
        canvas.restore();
        for (final p in [
          const Offset(34, 71),
          const Offset(67, 81),
          const Offset(38, 87),
        ]) {
          canvas.drawPath(_star(p.dx, p.dy, 2.2), _ink(cream));
        }
      case 'shirt_flower':
        for (final p in [
          const Offset(38, 74),
          const Offset(60, 74),
          const Offset(49, 86),
        ]) {
          _flower(canvas, p.dx, p.dy, 4.3);
        }
      case 'shirt_hoodie':
        if (!isBack) {
          // Cozy hood collar folds & drawstrings.
          canvas.drawPath(
            Path()
              ..moveTo(35, 63)
              ..quadraticBezierTo(42, 72, 50, 68.5)
              ..quadraticBezierTo(58, 72, 65, 63),
            _ink(const Color(0xffd6e6c8), 2.4),
          );
          for (final x in [44.5, 55.5]) {
            canvas.drawLine(
              Offset(x, 70.5),
              Offset(x, 79.5),
              _ink(cream, 1.45),
            );
            canvas.drawCircle(Offset(x, 80), 1.2, _ink(gold));
          }
          // Kangaroo pocket with stitched edges.
          final pocket = RRect.fromRectAndRadius(
            const Rect.fromLTWH(38, 80, 24, 9.5),
            const Radius.circular(3.5),
          );
          canvas.drawRRect(pocket, _ink(const Color(0xff5e8c73)));
          canvas.drawRRect(pocket, _ink(const Color(0xff476e59), .9));
          canvas.drawLine(
            const Offset(41.5, 81),
            const Offset(44.5, 87.5),
            _ink(cream, 1.1),
          );
          canvas.drawLine(
            const Offset(58.5, 81),
            const Offset(55.5, 87.5),
            _ink(cream, 1.1),
          );
        } else {
          // Rounded cozy hood resting on the upper back.
          final hood = Path()
            ..moveTo(34, 61)
            ..cubicTo(32, 78, 68, 78, 66, 61)
            ..close();
          canvas.drawPath(hood, _ink(_darken(item.color, .14)));
          canvas.drawPath(hood, _ink(const Color(0xffd6e6c8), 1.5));
          canvas.drawLine(
            const Offset(50, 62),
            const Offset(50, 74),
            _ink(_darken(item.color, .26), 1.1),
          );
        }
      case 'shirt_tux':
        if (!isBack) {
          canvas.drawPath(
            Path()
              ..moveTo(39, 62)
              ..lineTo(50, 88)
              ..lineTo(61, 62)
              ..close(),
            _ink(cream),
          );
          // Lapels.
          canvas.drawPath(
            Path()
              ..moveTo(35, 62)
              ..lineTo(44, 79)
              ..lineTo(40, 63)
              ..moveTo(65, 62)
              ..lineTo(56, 79)
              ..lineTo(60, 63),
            _ink(_darken(item.color, .28), 2.2),
          );
          _bow(canvas, 50, 70, 5.8, const Color(0xffb96d7e));
          for (final y in [77.0, 82.5]) {
            canvas.drawCircle(Offset(50, y), 1.3, _ink(item.color));
          }
        } else {
          canvas.drawLine(
            const Offset(50, 62),
            const Offset(50, 95),
            _ink(_darken(item.color, .28), 1.4),
          );
        }
      case 'shirt_sailor':
        if (!isBack) {
          canvas.drawPath(
            Path()
              ..moveTo(33, 62.5)
              ..lineTo(43, 73.5)
              ..lineTo(50, 68)
              ..lineTo(57, 73.5)
              ..lineTo(67, 62.5),
            _ink(cream, 3.2),
          );
          _bow(canvas, 50, 71, 4.6, const Color(0xffd95b66));
          _anchor(canvas, 50, 82, gold);
        } else {
          // Classic rectangular sailor back collar flap with white stripes.
          final flap = RRect.fromRectAndRadius(
            const Rect.fromLTWH(34, 61, 32, 15),
            const Radius.circular(2.5),
          );
          canvas.drawRRect(flap, _ink(_darken(item.color, .12)));
          canvas.drawRRect(flap, _ink(cream, 2));
          _anchor(canvas, 50, 84, gold);
        }
      case 'shirt_denim':
        canvas.drawLine(
          const Offset(50, 64),
          const Offset(50, 95),
          _ink(cream, 1.2),
        );
        canvas.drawLine(
          const Offset(47.5, 64),
          const Offset(47.5, 95),
          _ink(gold, .85),
        );
        if (!isBack) {
          for (final x in [36.5, 57.5]) {
            final pocket = RRect.fromRectAndRadius(
              Rect.fromLTWH(x, 73, 9.5, 9.5),
              const Radius.circular(2),
            );
            canvas.drawRRect(pocket, _ink(const Color(0xff637b94)));
            canvas.drawRRect(pocket, _ink(gold, .75));
            canvas.drawLine(
              Offset(x + 1, 75.2),
              Offset(x + 8.5, 75.2),
              _ink(gold, .9),
            );
          }
          for (final y in [71.5, 79.5, 87.5]) {
            canvas.drawCircle(Offset(50, y), 1.2, _ink(gold));
          }
        }
      case 'shirt_paw':
        canvas.drawOval(const Rect.fromLTWH(44.5, 78, 11, 8.5), _ink(cream));
        for (final x in [42.5, 46.8, 53.2, 57.5]) {
          canvas.drawOval(
            Rect.fromCenter(
              center: Offset(x, x == 42.5 || x == 57.5 ? 76.8 : 72.8),
              width: 4.2,
              height: 5.2,
            ),
            _ink(cream),
          );
        }
      case 'shirt_strawberry':
        for (final at in [
          const Offset(37, 74),
          const Offset(60, 75),
          const Offset(50, 86.5),
        ]) {
          canvas.drawPath(
            _heart(at.dx, at.dy, 3.8),
            _ink(const Color(0xffd2536f)),
          );
          canvas.drawLine(
            at + const Offset(-2.2, -2.2),
            at + const Offset(2.2, -2.2),
            _ink(const Color(0xff5b9b72), 2.2),
          );
          canvas.drawCircle(at + const Offset(-0.8, 0.5), .65, _ink(cream));
          canvas.drawCircle(at + const Offset(1.0, 1.4), .65, _ink(cream));
        }
      case 'shirt_dragon':
        canvas.drawPath(
          Path()
            ..moveTo(44, 86)
            ..quadraticBezierTo(60, 87, 59, 77)
            ..lineTo(65, 73)
            ..lineTo(57, 72)
            ..lineTo(58, 68)
            ..lineTo(50, 75)
            ..quadraticBezierTo(42, 78, 44, 86)
            ..close(),
          _ink(gold),
        );
        canvas.drawPath(
          Path()
            ..moveTo(47, 80)
            ..lineTo(38, 70)
            ..lineTo(36, 80)
            ..lineTo(41, 79)
            ..close(),
          _ink(const Color(0xffe76b64)),
        );
        canvas.drawCircle(
          const Offset(59, 75),
          1.1,
          _ink(const Color(0xff424750)),
        );
      case 'shirt_galaxy':
        for (var i = 0; i < 15; i++) {
          final angle = i * .78, r = 1.0 + i * .52;
          canvas.drawCircle(
            Offset(50 + math.cos(angle) * r, 80 + math.sin(angle) * r),
            1.7,
            _ink(
              Color.lerp(
                const Color(0xff7de0dd),
                const Color(0xffd987d5),
                i / 14,
              )!,
            ),
          );
        }
        for (final at in [
          const Offset(34, 72),
          const Offset(65, 84),
          const Offset(38, 91),
        ]) {
          canvas.drawPath(_star(at.dx, at.dy, 2.2), _ink(cream));
        }
      case 'shirt_honey':
        for (var y = 70.0; y < 93; y += 7.5) {
          canvas.drawLine(
            Offset(20, y),
            Offset(80, y),
            _ink(const Color(0xff59483e), 3.8),
          );
        }
        canvas.drawOval(
          const Rect.fromLTWH(43.5, 73.5, 5.5, 4.2),
          _ink(const Color(0xd8ffffff)),
        );
        canvas.drawOval(
          const Rect.fromLTWH(51, 73.5, 5.5, 4.2),
          _ink(const Color(0xd8ffffff)),
        );
        canvas.drawOval(const Rect.fromLTWH(45.5, 76.8, 9, 6.4), _ink(gold));
        canvas.drawLine(
          const Offset(50, 77.5),
          const Offset(50, 82.5),
          _ink(const Color(0xff59483e), 1.6),
        );
    }
    canvas.restore();

    // Ribbed crew-neck trim, sleeve seams, bottom hem highlight, and head shadow.
    canvas.save();
    canvas.clipPath(shirt);
    // Subtle shadow cast by the cat's head onto the upper neckline.
    canvas.drawPath(
      Path()
        ..moveTo(31, 58)
        ..quadraticBezierTo(50 + shift * .25, isBack ? 64 : 70.5, 69, 58)
        ..lineTo(69, 55)
        ..lineTo(31, 55)
        ..close(),
      _ink(const Color(0x24171115)),
    );
    // Ribbed collar band.
    canvas.drawPath(
      Path()
        ..moveTo(34, 60.5)
        ..quadraticBezierTo(50 + shift * .25, isBack ? 63.5 : 68.5, 66, 60.5),
      _ink(_lighten(item.color, .34), 2.4),
    );
    canvas.drawPath(
      Path()
        ..moveTo(34, 62.2)
        ..quadraticBezierTo(50 + shift * .25, isBack ? 65.2 : 70.2, 66, 62.2),
      _ink(dark.withValues(alpha: .45), .9),
    );
    // Raglan sleeve seams & cuff trim.
    canvas.drawPath(
      Path()
        ..moveTo(34, 62)
        ..quadraticBezierTo(30, 70, 27.5, 77)
        ..moveTo(66, 62)
        ..quadraticBezierTo(70, 70, 72.5, 77),
      _ink(dark.withValues(alpha: .42), 1.15),
    );
    canvas.drawPath(
      Path()
        ..moveTo(21, 71.5)
        ..quadraticBezierTo(24.5, 74.5, 28, 76.2)
        ..moveTo(79, 71.5)
        ..quadraticBezierTo(75.5, 74.5, 72, 76.2),
      _ink(_lighten(item.color, .30), 1.8),
    );
    // Bottom ribbed hem highlight.
    canvas.drawPath(
      Path()
        ..moveTo(30.5, 89)
        ..quadraticBezierTo(50, 95.2, 69.5, 89),
      _ink(const Color(0x66ffffff), 1.4),
    );
    canvas.restore();

    canvas.drawPath(shirt, _ink(outline, 1.25));
  }

  final neck = clothingById(outfit.neck);
  if (neck == null) return;
  final neckShift = shift * .45;

  if (neck.id.startsWith('bandana')) {
    if (isBack) {
      // Tied bandana knot at the back of the neck.
      final strap = Path()
        ..moveTo(31, 61.5)
        ..quadraticBezierTo(50, 65.5, 69, 61.5);
      canvas.drawPath(strap, _ink(_darken(neck.color, .22), 5.2));
      canvas.drawPath(strap, _ink(neck.color, 3.8));
      // Knot & two fluttering tail ends.
      canvas.drawPath(
        Path()
          ..moveTo(50, 64)
          ..lineTo(43, 73)
          ..lineTo(47.5, 74.5)
          ..close()
          ..moveTo(50, 64)
          ..lineTo(57, 73)
          ..lineTo(52.5, 74.5)
          ..close(),
        _ink(neck.color),
      );
      canvas.drawCircle(
        const Offset(50, 64),
        3.2,
        _ink(_lighten(neck.color, .18)),
      );
      canvas.drawCircle(
        const Offset(50, 64),
        3.2,
        _ink(_darken(neck.color, .28), 1),
      );
      return;
    }

    final scarf = Path()
      ..moveTo(29.5, 62.5)
      ..quadraticBezierTo(50 + neckShift * .5, 68.5, 70.5, 62.5)
      ..quadraticBezierTo(63, 72.5, 50 + neckShift, 81.5)
      ..quadraticBezierTo(37, 72.5, 29.5, 62.5)
      ..close();
    // Drop shadow on chest fur.
    canvas.drawPath(
      scarf.shift(const Offset(0, 1.6)),
      _ink(const Color(0x28181216)),
    );
    canvas.drawPath(
      scarf,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_lighten(neck.color, .16), neck.color, _darken(neck.color, .16)],
        ).createShader(const Rect.fromLTWH(29, 62, 42, 20)),
    );
    canvas.save();
    canvas.clipPath(scarf);
    canvas.translate(neckShift * .7, 0);
    // Dashed inner border stitch.
    canvas.drawPath(
      Path()
        ..moveTo(33, 64.5)
        ..lineTo(50, 78.5)
        ..lineTo(67, 64.5),
      _ink(_lighten(neck.color, .42).withValues(alpha: .65), 1.0),
    );
    if (neck.id == 'bandana_sakura') {
      _flower(canvas, 43, 70.5, 3.2);
      _flower(canvas, 56, 72.5, 2.7);
    } else if (neck.id == 'bandana_blue') {
      for (final x in [42.0, 50.0, 58.0]) {
        canvas.drawPath(_star(x, 70, 2.3), _ink(const Color(0xffe9ecdc)));
      }
    } else if (neck.id == 'bandana_green') {
      canvas.drawPath(
        Path()
          ..moveTo(46, 74)
          ..quadraticBezierTo(43, 65, 55, 68)
          ..quadraticBezierTo(58, 77, 46, 74),
        _ink(const Color(0xffbdd6a4)),
      );
      canvas.drawLine(
        const Offset(46, 74),
        const Offset(55, 68),
        _ink(const Color(0xff406b51), 1.1),
      );
    } else if (neck.id == 'bandana_pirate') {
      canvas.drawCircle(
        const Offset(50, 70.5),
        3.4,
        _ink(const Color(0xfff8edd7)),
      );
      canvas.drawCircle(const Offset(48.9, 70.3), .85, _ink(neck.color));
      canvas.drawCircle(const Offset(51.1, 70.3), .85, _ink(neck.color));
      canvas.drawLine(
        const Offset(46, 75.5),
        const Offset(54, 72.2),
        _ink(const Color(0xfff8edd7), 1.3),
      );
      canvas.drawLine(
        const Offset(46, 72.2),
        const Offset(54, 75.5),
        _ink(const Color(0xfff8edd7), 1.3),
      );
    } else {
      canvas.drawCircle(
        const Offset(50, 70.5),
        1.7,
        _ink(const Color(0xffffe5c0)),
      );
    }
    canvas.restore();
    canvas.drawPath(scarf, _ink(_darken(neck.color, .28), 1.15));
    return;
  }

  // Collar strap with shadow, border, and metallic ring.
  const collarRect = Rect.fromLTWH(29.5, 56.5, 41, 14.5);
  canvas.drawArc(
    collarRect.shift(const Offset(0, 1.3)),
    0,
    math.pi,
    false,
    _ink(const Color(0x28181216), 5.2),
  );
  canvas.drawArc(
    collarRect,
    0,
    math.pi,
    false,
    _ink(_darken(neck.color, .28), 5.4),
  );
  canvas.drawArc(collarRect, 0, math.pi, false, _ink(neck.color, 3.8));
  canvas.drawArc(
    collarRect.deflate(0.6),
    0.15,
    math.pi - 0.3,
    false,
    _ink(_lighten(neck.color, .28), 1.0),
  );

  const gold = Color(0xffffd46a);
  const goldDark = Color(0xffa67926);
  if (isBack) {
    // Golden buckle on the back of the collar.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(47, 67.5, 6, 4.5),
        const Radius.circular(1.4),
      ),
      _ink(gold, 1.5),
    );
    return;
  }

  final cx = 50.0 + neckShift;
  // Small golden connector ring at the bottom of the collar.
  canvas.drawCircle(Offset(cx, 69.5), 1.6, _ink(goldDark));
  canvas.drawCircle(Offset(cx, 69.5), 1.1, _ink(gold));

  switch (neck.id) {
    case 'casino_love':
      for (var i = 0; i < 9; i++) {
        final a = i * math.pi / 8;
        final px = 50 + 18.2 * math.cos(a), py = 63 + 6.2 * math.sin(a);
        canvas.drawCircle(Offset(px, py), 2.3, _ink(const Color(0xffcbbba8)));
        canvas.drawCircle(Offset(px, py), 2.0, _ink(const Color(0xfffff5e8)));
      }
      canvas.drawPath(_heart(cx, 74, 5.8), _ink(goldDark));
      canvas.drawPath(_heart(cx, 73.8, 5.4), _ink(gold));
      canvas.drawPath(_heart(cx, 73.8, 3.7), _ink(neck.color));
      canvas.drawCircle(Offset(cx - 1.6, 72), 1.0, _ink(Colors.white));
    case 'casino_charm':
      canvas.drawCircle(Offset(cx, 74.2), 6.0, _ink(goldDark));
      canvas.drawCircle(Offset(cx, 74), 5.5, _ink(gold));
      canvas.drawOval(
        Rect.fromLTWH(cx - 2.5, 73, 5, 4),
        _ink(const Color(0xff24836d)),
      );
      for (final p in [
        Offset(cx - 3.5, 71.5),
        Offset(cx - 1, 70),
        Offset(cx + 2, 70),
        Offset(cx + 4, 72),
      ]) {
        canvas.drawCircle(p, 1.15, _ink(const Color(0xff24836d)));
      }
    case 'collar_fish':
      canvas.drawOval(Rect.fromLTWH(cx - 6, 70, 10, 6), _ink(goldDark));
      canvas.drawOval(Rect.fromLTWH(cx - 5.8, 69.8, 9.6, 5.6), _ink(gold));
      canvas.drawPath(
        Path()
          ..moveTo(cx + 2, 72.8)
          ..lineTo(cx + 8, 69)
          ..lineTo(cx + 8, 76.8)
          ..close(),
        _ink(gold),
      );
      canvas.drawCircle(Offset(cx - 3.5, 72), .8, _ink(neck.color));
    case 'collar_pearl':
      for (var i = 0; i < 9; i++) {
        final a = i * math.pi / 8;
        final px = 50 + 18.2 * math.cos(a), py = 63 + 6.2 * math.sin(a);
        canvas.drawCircle(Offset(px, py), 2.5, _ink(const Color(0xffcbbba8)));
        canvas.drawCircle(Offset(px, py), 2.1, _ink(const Color(0xfffff6ea)));
      }
      canvas.drawCircle(Offset(cx, 73.2), 3.4, _ink(goldDark));
      canvas.drawCircle(Offset(cx, 73), 3.0, _ink(gold));
    case 'collar_ribbon':
      canvas.drawPath(
        Path()
          ..moveTo(cx - 3, 72)
          ..lineTo(cx - 6.5, 82.5)
          ..lineTo(cx - 1.5, 79.5)
          ..lineTo(cx + 2, 82.5)
          ..lineTo(cx + 3.5, 72)
          ..close(),
        _ink(_darken(neck.color, .14)),
      );
      _bow(canvas, cx, 71.2, 8.2, neck.color);
    case 'collar_cosmos':
      canvas.drawCircle(
        Offset(cx, 73.2),
        5.2,
        _ink(const Color(0xff6b529c)),
      );
      canvas.drawCircle(
        Offset(cx, 73),
        4.8,
        _ink(const Color(0xffa88bdd)),
      );
      canvas.drawOval(
        Rect.fromLTWH(cx - 8.2, 71, 16.4, 4.2),
        _ink(gold, 1.5),
      );
    case 'collar_heart':
      canvas.drawPath(_heart(cx, 72.5, 4.5), _ink(goldDark));
      canvas.drawPath(_heart(cx, 72.2, 4.1), _ink(gold));
      canvas.drawCircle(
        Offset(cx - 1.4, 70.8),
        .9,
        _ink(const Color(0xfffffaea)),
      );
    case 'collar_bell':
      canvas.drawCircle(Offset(cx, 72.4), 4.4, _ink(goldDark));
      canvas.drawCircle(Offset(cx, 72.2), 4.0, _ink(gold));
      canvas.drawLine(
        Offset(cx - 2.4, 73.8),
        Offset(cx + 2.4, 73.8),
        _ink(goldDark, 1.3),
      );
      canvas.drawCircle(Offset(cx, 74.6), 1.1, _ink(goldDark));
      canvas.drawCircle(
        Offset(cx - 1.3, 70.6),
        1.0,
        _ink(const Color(0xfffffaea)),
      );
    case 'collar_star':
      canvas.drawPath(_star(cx, 73.2, 5.5), _ink(goldDark));
      canvas.drawPath(_star(cx, 73, 5.0), _ink(gold));
    case 'collar_moon':
      canvas.drawPath(
        Path()
          ..moveTo(cx + 3, 68)
          ..cubicTo(cx - 8, 67, cx - 7, 79, cx + 4, 76)
          ..cubicTo(cx - 2, 76, cx - 3, 71, cx + 3, 68)
          ..close(),
        _ink(const Color(0xffe2d8f1)),
      );
    case 'collar_bow':
      _bow(canvas, cx, 71.8, 8.0, neck.color);
    case 'collar_flower':
      _flower(canvas, cx, 73, 5.2);
  }
}

void paintCatHeadClothing(
  Canvas canvas,
  CatOutfit outfit, {
  bool alien = false,
  double turn = 0,
}) {
  final isBack = turn.abs() > 0.65;
  final headShift = isBack
      ? -turn.sign * (1.0 - turn.abs()) * 14
      : turn * 9.0;

  final hat = clothingById(outfit.head);
  if (hat != null) {
    canvas.save();
    if (alien) {
      canvas.translate(50, 0);
      canvas.scale(.78);
      canvas.translate(-50, -1);
    }
    canvas.translate(headShift * .45, 0);
    final fill = _ink(hat.color);
    final light = _lighten(hat.color, .24);
    final dark = _darken(hat.color, .24);
    final outline = _darken(hat.color, .38);

    // Forehead contact shadow for seated hats (except halo).
    if (hat.id != 'halo' && hat.id != 'bow') {
      canvas.drawOval(
        const Rect.fromLTWH(28, 25.5, 44, 5.5),
        _ink(const Color(0x26151014)),
      );
    }

    switch (hat.id) {
      case 'casino_crown':
        final crown = Path()
          ..moveTo(30.5, 29)
          ..lineTo(27.5, 11.5)
          ..lineTo(39.5, 20.5)
          ..lineTo(50, 5.5)
          ..lineTo(60.5, 20.5)
          ..lineTo(72.5, 11.5)
          ..lineTo(69.5, 29)
          ..close();
        canvas.drawPath(
          crown,
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [_lighten(hat.color, .3), hat.color, _darken(hat.color, .2)],
            ).createShader(const Rect.fromLTWH(27, 5, 46, 25)),
        );
        canvas.drawPath(crown, _ink(const Color(0xff8e5d21), 1.2));
        final band = RRect.fromRectAndRadius(
          const Rect.fromLTWH(30.5, 24.5, 39, 7),
          const Radius.circular(2.5),
        );
        canvas.drawRRect(band, _ink(const Color(0xffab7532)));
        canvas.drawRRect(band, _ink(const Color(0xff784f1d), 1.0));
        for (final x in [38.0, 50.0, 62.0]) {
          canvas.drawPath(
            _star(x, 28, x == 50 ? 4.2 : 2.7),
            _ink(const Color(0xff48d3a8)),
          );
        }
        for (final p in [
          const Offset(27.5, 11.5),
          const Offset(50, 5.5),
          const Offset(72.5, 11.5),
        ]) {
          canvas.drawCircle(p, 2.3, _ink(const Color(0xff8e5d21)));
          canvas.drawCircle(p, 1.9, _ink(const Color(0xfffff3c4)));
        }
      case 'bucket':
        final dome = Path()
          ..moveTo(34.5, 12)
          ..quadraticBezierTo(50, 7.5, 65.5, 12)
          ..lineTo(70.5, 28)
          ..lineTo(29.5, 28)
          ..close();
        canvas.drawPath(dome, fill);
        canvas.drawPath(dome, _ink(outline, 1.1));
        canvas.drawOval(const Rect.fromLTWH(23.5, 24.5, 53, 9.5), _ink(dark));
        canvas.drawOval(const Rect.fromLTWH(23.5, 24, 53, 9), fill);
        canvas.drawOval(
          const Rect.fromLTWH(23.5, 24, 53, 9),
          _ink(outline, 1.1),
        );
        canvas.drawLine(
          const Offset(33.5, 22.8),
          const Offset(66.5, 22.8),
          _ink(const Color(0x88ffffff), 2.2),
        );
      case 'frog':
        canvas.drawOval(const Rect.fromLTWH(27.5, 14.5, 45, 19.5), fill);
        canvas.drawOval(
          const Rect.fromLTWH(27.5, 14.5, 45, 19.5),
          _ink(outline, 1.1),
        );
        for (final x in [37.0, 63.0]) {
          canvas.drawCircle(Offset(x, 14.5), 6.4, fill);
          canvas.drawCircle(Offset(x, 14.5), 6.4, _ink(outline, 1.0));
          if (!isBack) {
            canvas.drawCircle(Offset(x, 14), 3.8, _ink(Colors.white));
            canvas.drawCircle(
              Offset(x, 14),
              2.0,
              _ink(const Color(0xff2c3a31)),
            );
            canvas.drawCircle(Offset(x - .8, 13.1), .75, _ink(Colors.white));
          }
        }
        if (!isBack) {
          for (final x in [34.5, 65.5]) {
            canvas.drawOval(
              Rect.fromCenter(center: Offset(x, 23.5), width: 5, height: 2.8),
              _ink(const Color(0x77f28ca0)),
            );
          }
          canvas.drawArc(
            const Rect.fromLTWH(43, 21.5, 14, 6),
            0,
            math.pi,
            false,
            _ink(const Color(0xff3e664a), 1.4),
          );
        }
      case 'halo':
        canvas.drawOval(
          const Rect.fromLTWH(29.5, 5.5, 41, 9.5),
          _ink(const Color(0x55fff0b8), 8),
        );
        canvas.drawOval(
          const Rect.fromLTWH(29.5, 5.5, 41, 9.5),
          _ink(_darken(hat.color, .18), 3.4),
        );
        canvas.drawOval(
          const Rect.fromLTWH(29.5, 5.5, 41, 9.5),
          _ink(hat.color, 2.2),
        );
        canvas.drawPath(_star(74, 15.5, 3.2), _ink(hat.color));
      case 'astronaut':
        canvas.drawPath(
          Path()..addOval(const Rect.fromLTWH(18.5, 8.5, 63, 61.5)),
          _ink(const Color(0x247addeb)),
        );
        canvas.drawOval(
          const Rect.fromLTWH(18.5, 8.5, 63, 61.5),
          _ink(hat.color, 3.2),
        );
        canvas.drawPath(
          Path()
            ..moveTo(28, 23)
            ..quadraticBezierTo(34, 14, 44, 13),
          _ink(const Color(0xccffffff), 2.4),
        );
        for (final x in [16.5, 77.5]) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(x, 37, 6, 14),
              const Radius.circular(2.2),
            ),
            fill,
          );
        }
        canvas.drawArc(
          const Rect.fromLTWH(26.5, 48, 47, 23),
          0,
          math.pi,
          false,
          _ink(hat.color, 5.2),
        );
      case 'hood_winter':
        canvas.drawArc(
          const Rect.fromLTWH(22.5, 13.5, 55, 53.5),
          math.pi,
          math.pi,
          false,
          _ink(outline, 10.6),
        );
        canvas.drawArc(
          const Rect.fromLTWH(22.5, 13.5, 55, 53.5),
          math.pi,
          math.pi,
          false,
          _ink(hat.color, 8.8),
        );
        for (final x in [28.5, 71.5]) {
          canvas.drawCircle(Offset(x, 34), 8.2, fill);
          canvas.drawCircle(Offset(x, 34), 5.6, _ink(const Color(0xffffefdb)));
        }
        canvas.drawArc(
          const Rect.fromLTWH(27.5, 51, 45, 16),
          0,
          math.pi,
          false,
          _ink(hat.color, 5.2),
        );
      case 'beanie':
        final dome = Path()
          ..moveTo(30.5, 26)
          ..quadraticBezierTo(31.5, 7.5, 50, 8.5)
          ..quadraticBezierTo(68.5, 7.5, 69.5, 26)
          ..close();
        canvas.drawPath(
          dome,
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [light, hat.color, dark],
            ).createShader(const Rect.fromLTWH(30, 8, 40, 20)),
        );
        canvas.drawPath(dome, _ink(outline, 1.1));
        for (var x = 37.0; x < 65; x += 6) {
          canvas.drawLine(
            Offset(x, 12.5),
            Offset(x, 22.5),
            _ink(const Color(0x55ffffff), 1.2),
          );
        }
        final cuff = RRect.fromRectAndRadius(
          const Rect.fromLTWH(28.5, 22.5, 43, 7.5),
          const Radius.circular(3.5),
        );
        canvas.drawRRect(cuff, _ink(const Color(0xffc4b4ec)));
        canvas.drawRRect(cuff, _ink(outline, 1.0));
        for (var x = 33.0; x < 68; x += 5) {
          canvas.drawLine(
            Offset(x, 23.5),
            Offset(x, 29),
            _ink(const Color(0x444b3b75), 1.0),
          );
        }
        canvas.drawCircle(
          const Offset(50, 8.5),
          5.0,
          _ink(const Color(0xffe0d4f8)),
        );
        canvas.drawCircle(const Offset(50, 8.5), 5.0, _ink(outline, .9));
      case 'explorer':
        canvas.drawOval(
          const Rect.fromLTWH(23.5, 24.5, 53, 8.5),
          _ink(const Color(0xffddc18b)),
        );
        canvas.drawOval(
          const Rect.fromLTWH(23.5, 24.5, 53, 8.5),
          _ink(outline, 1.0),
        );
        final crown = RRect.fromRectAndRadius(
          const Rect.fromLTWH(33.5, 12.5, 33, 15.5),
          const Radius.circular(6.5),
        );
        canvas.drawRRect(crown, fill);
        canvas.drawRRect(crown, _ink(outline, 1.1));
        canvas.drawRect(
          const Rect.fromLTWH(33.5, 22.5, 33, 4.2),
          _ink(const Color(0xff846742)),
        );
      case 'cap':
        final cap = Path()
          ..moveTo(30.5, 27.5)
          ..quadraticBezierTo(29, 9.5, 50, 10.5)
          ..quadraticBezierTo(69.5, 10.5, 70.5, 27.5)
          ..close();
        canvas.drawPath(cap, fill);
        canvas.drawPath(cap, _ink(outline, 1.1));
        if (!isBack) {
          canvas.drawOval(
            const Rect.fromLTWH(45, 24.5, 34, 8.2),
            _ink(const Color(0xffb9635c)),
          );
          canvas.drawOval(
            const Rect.fromLTWH(45, 24.5, 34, 8.2),
            _ink(outline, 1.0),
          );
          canvas.drawPath(_star(39, 21.5, 3.2), _ink(const Color(0xffffe3b4)));
        }
        canvas.drawLine(
          const Offset(50, 11.5),
          const Offset(50.5, 26.5),
          _ink(const Color(0xfff1bdad), 1.1),
        );
      case 'bow':
        _bow(canvas, 61, 19.5, 12, hat.color);
        for (final p in [
          const Offset(53, 16),
          const Offset(70, 21.5),
          const Offset(52.5, 22.5),
        ]) {
          canvas.drawCircle(p, 1.45, _ink(Colors.white));
        }
      case 'crown':
        final crown = Path()
          ..moveTo(31.5, 29)
          ..lineTo(28.5, 12)
          ..lineTo(40, 20)
          ..lineTo(50, 6.5)
          ..lineTo(60, 20)
          ..lineTo(71.5, 12)
          ..lineTo(68.5, 29)
          ..close();
        canvas.drawPath(
          crown,
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [_lighten(hat.color, .28), hat.color, _darken(hat.color, .18)],
            ).createShader(const Rect.fromLTWH(28, 6, 44, 24)),
        );
        canvas.drawPath(crown, _ink(const Color(0xff9c7221), 1.15));
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(31.5, 24.5, 37, 6.2),
            const Radius.circular(2.2),
          ),
          _ink(const Color(0xffffd56b)),
        );
        for (final x in [39.0, 50.0, 61.0]) {
          canvas.drawCircle(Offset(x, 27.4), 2.0, _ink(const Color(0xffbd6588)));
          canvas.drawCircle(
            Offset(x - .5, 26.9),
            .65,
            _ink(const Color(0xffffd6e7)),
          );
        }
      case 'wizard':
        final cone = Path()
          ..moveTo(30, 28)
          ..lineTo(53, 3.5)
          ..quadraticBezierTo(61.5, 18.5, 68.5, 28)
          ..close();
        canvas.drawPath(cone, fill);
        canvas.drawPath(cone, _ink(outline, 1.1));
        canvas.drawOval(
          const Rect.fromLTWH(24.5, 25.5, 51, 7.5),
          _ink(const Color(0xff5d5490)),
        );
        canvas.drawOval(
          const Rect.fromLTWH(24.5, 25.5, 51, 7.5),
          _ink(outline, 1.0),
        );
        canvas.drawPath(_star(52, 18.8, 3.7), _ink(const Color(0xffffdc83)));
        canvas.drawCircle(
          const Offset(45.5, 23.8),
          1.4,
          _ink(const Color(0xffffdc83)),
        );
      case 'sailor':
        canvas.drawOval(const Rect.fromLTWH(30.5, 12.5, 39, 16), fill);
        canvas.drawOval(
          const Rect.fromLTWH(30.5, 12.5, 39, 16),
          _ink(const Color(0xff9aaab8), 1.1),
        );
        final band = RRect.fromRectAndRadius(
          const Rect.fromLTWH(29.5, 23.5, 41, 7.2),
          const Radius.circular(2.2),
        );
        canvas.drawRRect(band, _ink(const Color(0xff5b7799)));
        canvas.drawPath(_star(50, 27, 2.3), _ink(const Color(0xffe7cb75)));
      case 'chef':
        for (final x in [36.0, 50.0, 64.0]) {
          canvas.drawCircle(Offset(x, 13), 9.2, fill);
          canvas.drawCircle(
            Offset(x, 13),
            9.2,
            _ink(const Color(0xffcfbc9e), 1.0),
          );
        }
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(33.5, 15.5, 33, 15),
            const Radius.circular(3),
          ),
          fill,
        );
        canvas.drawLine(
          const Offset(34.5, 27),
          const Offset(65.5, 27),
          _ink(const Color(0xffcfbc9e), 1.2),
        );
      case 'party':
        final cone = Path()
          ..moveTo(33.5, 29.5)
          ..lineTo(50.5, 4.5)
          ..lineTo(66.5, 29.5)
          ..close();
        canvas.drawPath(cone, fill);
        canvas.save();
        canvas.clipPath(cone);
        for (var y = 10.0; y < 32; y += 7) {
          canvas.drawLine(
            Offset(32, y + 3),
            Offset(69, y - 3),
            _ink(const Color(0xffffd16e), 3.1),
          );
        }
        canvas.restore();
        canvas.drawPath(cone, _ink(outline, 1.1));
        canvas.drawCircle(
          const Offset(50.5, 4.5),
          3.4,
          _ink(const Color(0xffe58da4)),
        );
      case 'beret':
        canvas.drawOval(const Rect.fromLTWH(27.5, 10.5, 47.5, 18.5), fill);
        canvas.drawOval(
          const Rect.fromLTWH(27.5, 10.5, 47.5, 18.5),
          _ink(outline, 1.1),
        );
        canvas.drawLine(
          const Offset(52, 11.5),
          const Offset(54.5, 6.5),
          _ink(hat.color, 3),
        );
        canvas.drawArc(
          const Rect.fromLTWH(31.5, 18, 38, 11.5),
          0,
          math.pi,
          false,
          _ink(const Color(0xff88445d), 3.2),
        );
    }
    canvas.restore();
  }

  final glasses = clothingById(outfit.eyes);
  if (glasses == null) return;
  final y = alien ? 33.0 : 43.0;

  if (isBack) {
    // From behind, ski goggles show an elastic strap; other glasses stay on the front face.
    if (glasses.id == 'glasses_ski' || glasses.id == 'glasses_cyber') {
      canvas.drawPath(
        Path()
          ..moveTo(22, y - 1)
          ..quadraticBezierTo(50, y + 2, 78, y - 1),
        _ink(_darken(glasses.color, .22), 4.2),
      );
    }
    return;
  }

  canvas.save();
  canvas.translate(headShift * .65, 0);

  final strokeWidth = glasses.id == 'glasses_pixel' ? 2.8 : 2.3;
  final frameShadow = _ink(const Color(0x28140f14), strokeWidth + 1.0);
  final frameOuter = _ink(_darken(glasses.color, .26), strokeWidth + .8);
  final frame = _ink(glasses.color, strokeWidth);
  if (glasses.id == 'glasses_rainbow') {
    frame.shader = const LinearGradient(
      colors: [
        Color(0xffde7794),
        Color(0xffe9bd62),
        Color(0xff75b3a1),
        Color(0xff9b80c6),
      ],
    ).createShader(Rect.fromLTWH(22, y - 10, 56, 20));
  }

  // Temples (patillas) reaching cleanly toward the ear bases.
  if (glasses.id != 'glasses_monocle') {
    canvas.drawLine(Offset(27.5, y - 1), Offset(21.5, y - 4.5), frameOuter);
    canvas.drawLine(Offset(72.5, y - 1), Offset(78.5, y - 4.5), frameOuter);
    canvas.drawLine(Offset(27.5, y - 1), Offset(21.5, y - 4.5), frame);
    canvas.drawLine(Offset(72.5, y - 1), Offset(78.5, y - 4.5), frame);
  }

  // Continuous wrap-around visors for cyber & ski goggles.
  if (glasses.id == 'glasses_cyber' || glasses.id == 'glasses_ski') {
    final visor = glasses.id == 'glasses_ski'
        ? (Path()
            ..moveTo(25, y - 8.5)
            ..quadraticBezierTo(50, y - 10, 75, y - 8.5)
            ..quadraticBezierTo(78, y, 74, y + 7.5)
            ..quadraticBezierTo(56, y + 8.5, 50, y + 3.5)
            ..quadraticBezierTo(44, y + 8.5, 26, y + 7.5)
            ..quadraticBezierTo(22, y, 25, y - 8.5)
            ..close())
        : (Path()
            ..moveTo(24.5, y - 6.5)
            ..lineTo(75.5, y - 6.5)
            ..lineTo(71.5, y + 6.5)
            ..lineTo(53.5, y + 6.5)
            ..lineTo(50, y + 2.5)
            ..lineTo(46.5, y + 6.5)
            ..lineTo(28.5, y + 6.5)
            ..close());
    canvas.drawPath(visor.shift(const Offset(0, 1.3)), frameShadow);
    canvas.drawPath(
      visor,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: glasses.id == 'glasses_cyber'
              ? [
                  const Color(0x665ef2ff),
                  glasses.color.withValues(alpha: .38),
                  const Color(0x66ff6ec7),
                ]
              : [
                  const Color(0x55ffffff),
                  glasses.color.withValues(alpha: .32),
                  _darken(glasses.color, .2).withValues(alpha: .42),
                ],
        ).createShader(Rect.fromLTWH(24, y - 10, 52, 18)),
    );
    // Glossy diagonal visor reflection.
    canvas.save();
    canvas.clipPath(visor);
    for (final x in [36.0, 60.0]) {
      canvas.drawLine(
        Offset(x - 6, y + 6),
        Offset(x + 4, y - 7),
        _ink(const Color(0x88ffffff), 2.6),
      );
    }
    canvas.restore();
    canvas.drawPath(visor, frameOuter);
    canvas.drawPath(visor, frame);
    canvas.restore();
    return;
  }

  for (final x in [38.0, 62.0]) {
    if (glasses.id == 'glasses_monocle' && x == 38) continue;
    // Star/heart/flower frames use a slightly wider inner ratio so spikes
    // frame the eye silhouette cleanly instead of slicing across the pupil!
    final lens = switch (glasses.id) {
      'glasses_flower' => _flowerLens(x, y),
      'glasses_cloud' =>
        Path()
          ..addRRect(
            RRect.fromRectAndRadius(
              Rect.fromCenter(center: Offset(x, y), width: 21, height: 14.5),
              const Radius.circular(7),
            ),
          ),
      'glasses_heart' => _heart(x, y - 1.2, 9.6),
      'glasses_star' || 'casino_starlight' => _star(
        x,
        y,
        12.4,
        innerFactor: .64,
      ),
      'glasses_cat' =>
        Path()
          ..moveTo(x - 11, y - 6.5)
          ..lineTo(x - 12.5, y - 11)
          ..lineTo(x - 6, y - 8.5)
          ..quadraticBezierTo(x, y - 9, x + 6, y - 8.5)
          ..lineTo(x + 12.5, y - 11)
          ..lineTo(x + 11, y - 6.5)
          ..quadraticBezierTo(x + 11, y + 8.5, x, y + 8.5)
          ..quadraticBezierTo(x - 11, y + 8.5, x - 11, y - 6.5)
          ..close(),
      'glasses_square' =>
        Path()..addRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset(x, y), width: 20.5, height: 17),
            const Radius.circular(3.5),
          ),
        ),
      'glasses_pixel' => Path()..addRect(Rect.fromLTWH(x - 10, y - 7, 20, 14)),
      'glasses_sport' =>
        Path()
          ..moveTo(x - 11.5, y - 5.5)
          ..lineTo(x + 11.5, y - 6.5)
          ..lineTo(x + 8.5, y + 7)
          ..lineTo(x - 6.5, y + 6)
          ..close(),
      'glasses_aviator' =>
        Path()
          ..moveTo(x - 9.5, y - 7)
          ..quadraticBezierTo(x + 12, y - 9.5, x + 9.5, y + 2.5)
          ..quadraticBezierTo(x + 1.5, y + 14.5, x - 8.5, y + 4.5)
          ..close(),
      'glasses_tiny' =>
        Path()..addOval(
          Rect.fromCenter(center: Offset(x, y + 2), width: 17.5, height: 11),
        ),
      _ => Path()..addOval(Rect.fromCircle(center: Offset(x, y), radius: 10.2)),
    };

    // Subtle drop shadow of the frame on the face.
    canvas.drawPath(lens.shift(const Offset(0, 1.2)), frameShadow);

    // Tinted glass fill.
    canvas.drawPath(
      lens,
      _ink(
        glasses.color.withValues(
          alpha: glasses.id == 'glasses_pixel' ? .55 : .18,
        ),
      ),
    );

    // Glossy diagonal lens reflection clipped inside the lens.
    canvas.save();
    canvas.clipPath(lens);
    if (glasses.id == 'glasses_pixel') {
      canvas.drawRect(
        Rect.fromLTWH(x - 7, y - 4.5, 3.2, 3.2),
        _ink(Colors.white),
      );
      canvas.drawRect(
        Rect.fromLTWH(x - 3.8, y - 1.3, 3.2, 3.2),
        _ink(Colors.white),
      );
    } else {
      canvas.drawLine(
        Offset(x - 6, y - 3),
        Offset(x + 1, y - 7.5),
        _ink(const Color(0xaaffffff), 1.8),
      );
      canvas.drawLine(
        Offset(x - 3, y + .5),
        Offset(x + 3.5, y - 4),
        _ink(const Color(0x66ffffff), 1.0),
      );
    }
    canvas.restore();

    canvas.drawPath(lens, frameOuter);
    canvas.drawPath(lens, frame);

    if (glasses.id == 'casino_starlight') {
      canvas.drawCircle(
        Offset(x, y - 11.8),
        1.9,
        _ink(const Color(0xffb93668)),
      );
      canvas.drawCircle(
        Offset(x - .4, y - 12.2),
        .6,
        _ink(const Color(0xffffdbe8)),
      );
      canvas.drawPath(
        _star(x + 9.2, y + 8.2, 2.5),
        _ink(const Color(0xfffff3d9)),
      );
    }
  }

  if (glasses.id == 'glasses_monocle') {
    canvas.drawPath(
      Path()
        ..moveTo(71.5, y + 5)
        ..quadraticBezierTo(79.5, y + 23.5, 70, y + 29),
      _ink(glasses.color, 1.35),
    );
    canvas.restore();
    return;
  }

  // Curved anatomical nose bridge (plus pilot top bar for aviator).
  final bridge = Path()
    ..moveTo(47.6, y - .5)
    ..quadraticBezierTo(50, y - 2.6, 52.4, y - .5);
  canvas.drawPath(bridge, frameOuter);
  canvas.drawPath(bridge, frame);
  if (glasses.id == 'glasses_aviator') {
    canvas.drawLine(Offset(45, y - 6.2), Offset(55, y - 6.2), frame);
  }
  canvas.restore();
}

// Fixed organic smudges, faded gradually by cleanliness and by the rinse gesture.
void paintCatDirt(
  Canvas canvas,
  double cleanliness, {
  bool head = false,
  double turn = 0,
}) {
  final dirt = ((75 - cleanliness) / 60).clamp(0.0, 1.0);
  if (dirt == 0) return;
  final spots = head
      ? const [(27.0, 53.0, 4.5), (69.0, 54.0, 5.0), (52.0, 29.0, 3.0)]
      : const [
          (33.0, 76.0, 5.0),
          (61.0, 84.0, 6.0),
          (48.0, 69.0, 3.5),
          (45.0, 87.0, 3.0),
        ];
  final dx = turn.abs() > 0.65 ? 0.0 : turn * 6.0;
  for (var i = 0; i < spots.length; i++) {
    final (rawX, y, r) = spots[i];
    final x = rawX + dx;
    final alpha = (dirt * 1.5 - i * .13).clamp(0.0, .85);
    final path = Path();
    for (var n = 0; n < 12; n++) {
      final a = n * math.pi / 6,
          radius = r * (.8 + .22 * math.sin(n * 2.7 + i));
      final px = x + math.cos(a) * radius, py = y + math.sin(a) * radius;
      if (n == 0) {
        path.moveTo(px, py);
      } else {
        path.lineTo(px, py);
      }
    }
    canvas.drawPath(
      path..close(),
      _ink(const Color(0xff93704c).withValues(alpha: alpha)),
    );
    canvas.drawCircle(
      Offset(x - r * .3, y - r * .25),
      r * .3,
      _ink(const Color(0xffc2a071).withValues(alpha: alpha * .8)),
    );
    canvas.drawCircle(
      Offset(x + r + 1, y + 2),
      .9,
      _ink(const Color(0xff805d40).withValues(alpha: alpha)),
    );
  }
}

Path _flowerLens(double x, double y) {
  final path = Path();
  for (var i = 0; i <= 48; i++) {
    final a = i * math.pi / 24, r = 10.6 + math.cos(a * 6) * 1.7;
    final at = Offset(x + math.cos(a) * r, y + math.sin(a) * r);
    if (i == 0) {
      path.moveTo(at.dx, at.dy);
    } else {
      path.lineTo(at.dx, at.dy);
    }
  }
  return path..close();
}
