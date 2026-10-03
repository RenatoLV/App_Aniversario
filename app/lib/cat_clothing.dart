import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'cat_care.dart';

// Shared 100 × 100 anatomy: garments move with the cat's body/head transforms.
Paint _ink(Color color, [double? width]) => Paint()
  ..color = color
  ..style = width == null ? PaintingStyle.fill : PaintingStyle.stroke
  ..strokeWidth = width ?? 1
  ..strokeCap = StrokeCap.round
  ..strokeJoin = StrokeJoin.round;
Path _star(double x, double y, double r) {
  final p = Path();
  for (var i = 0; i < 10; i++) {
    final a = -math.pi / 2 + i * math.pi / 5, radius = i.isEven ? r : r * .44;
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
  ..moveTo(x, y + r)
  ..cubicTo(x - r * 2, y, x - r, y - r * 1.5, x, y - r * .5)
  ..cubicTo(x + r, y - r * 1.5, x + r * 2, y, x, y + r)
  ..close();
void _flower(Canvas c, double x, double y, double r) {
  for (var i = 0; i < 5; i++) {
    final a = i * math.pi * 2 / 5;
    c.drawCircle(
      Offset(x + math.cos(a) * r * .65, y + math.sin(a) * r * .65),
      r * .5,
      _ink(const Color(0xfffff6df)),
    );
  }
  c.drawCircle(Offset(x, y), r * .35, _ink(const Color(0xffefbd54)));
}

void _bow(Canvas c, double x, double y, double r, Color color) {
  c.drawPath(
    Path()
      ..moveTo(x, y)
      ..lineTo(x - r, y - r * .7)
      ..quadraticBezierTo(x - r * 1.2, y, x - r, y + r * .7)
      ..close(),
    _ink(color),
  );
  c.drawPath(
    Path()
      ..moveTo(x, y)
      ..lineTo(x + r, y - r * .7)
      ..quadraticBezierTo(x + r * 1.2, y, x + r, y + r * .7)
      ..close(),
    _ink(color),
  );
  c.drawCircle(
    Offset(x, y),
    r * .3,
    _ink(Color.lerp(color, Colors.white, .3)!),
  );
}

void _anchor(Canvas c, double x, double y, Color color) {
  final ink = _ink(color, 1.8);
  c.drawCircle(Offset(x, y - 6), 2, ink);
  c.drawLine(Offset(x, y - 4), Offset(x, y + 7), ink);
  c.drawLine(Offset(x - 4, y - 1), Offset(x + 4, y - 1), ink);
  c.drawPath(
    Path()
      ..moveTo(x - 7, y + 2)
      ..quadraticBezierTo(x - 5, y + 10, x, y + 7)
      ..quadraticBezierTo(x + 5, y + 10, x + 7, y + 2),
    ink,
  );
}

void paintCatBodyClothing(Canvas canvas, CatOutfit outfit) {
  final item = clothingById(outfit.body);
  if (item != null) {
    final shirt = Path()
      ..moveTo(35, 61)
      ..quadraticBezierTo(50, 68, 65, 61)
      ..quadraticBezierTo(74, 63, 78, 71)
      ..quadraticBezierTo(77, 75, 72, 77)
      ..quadraticBezierTo(75, 85, 69, 92)
      ..quadraticBezierTo(50, 98, 31, 92)
      ..quadraticBezierTo(25, 85, 28, 77)
      ..quadraticBezierTo(23, 75, 22, 71)
      ..quadraticBezierTo(26, 63, 35, 61)
      ..close();
    canvas.drawPath(
      shirt,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(item.color, Colors.white, .18)!,
            item.color,
            Color.lerp(item.color, Colors.black, .16)!,
          ],
        ).createShader(const Rect.fromLTWH(22, 62, 56, 35)),
    );
    canvas.save();
    canvas.clipPath(shirt);
    const cream = Color(0xfffff0d6), gold = Color(0xffffd677);
    switch (item.id) {
      case 'shirt_stripes':
        for (var y = 71.0; y < 92; y += 6) {
          canvas.drawLine(Offset(22, y), Offset(78, y), _ink(cream, 2.8));
        }
      case 'shirt_star':
        canvas.drawPath(_star(50, 78, 8), _ink(gold));
      case 'shirt_check':
        for (var y = 66; y < 96; y += 7) {
          for (var x = 22; x < 79; x += 7) {
            if (((x - 22) + (y - 66)) ~/ 7 % 2 == 0) {
              canvas.drawRect(
                Rect.fromLTWH(x.toDouble(), y.toDouble(), 7, 7),
                _ink(cream),
              );
            }
          }
        }
      case 'shirt_sunset':
        canvas.drawCircle(const Offset(50, 76), 8, _ink(gold));
        for (var y = 79.0; y < 93; y += 4) {
          canvas.drawLine(
            Offset(25, y),
            Offset(76, y),
            _ink(const Color(0xffab6697), 2),
          );
        }
      case 'shirt_space':
        canvas.drawCircle(
          const Offset(50, 78),
          6,
          _ink(const Color(0xffbda3dd)),
        );
        canvas.save();
        canvas.translate(50, 78);
        canvas.rotate(-.4);
        canvas.drawOval(const Rect.fromLTWH(-10, -3, 20, 6), _ink(gold, 1.5));
        canvas.restore();
        for (final p in [
          const Offset(34, 71),
          const Offset(67, 81),
          const Offset(38, 87),
        ]) {
          canvas.drawPath(_star(p.dx, p.dy, 2), _ink(cream));
        }
      case 'shirt_flower':
        for (final p in [
          const Offset(38, 74),
          const Offset(60, 74),
          const Offset(48, 86),
        ]) {
          _flower(canvas, p.dx, p.dy, 4);
        }
      case 'shirt_hoodie':
        canvas.drawPath(
          Path()
            ..moveTo(36, 65)
            ..lineTo(44, 73)
            ..lineTo(50, 69)
            ..lineTo(56, 73)
            ..lineTo(64, 65),
          _ink(const Color(0xffd6e6c8), 2),
        );
        canvas.drawLine(
          const Offset(44, 73),
          const Offset(44, 79),
          _ink(cream, 1.2),
        );
        canvas.drawLine(
          const Offset(56, 73),
          const Offset(56, 79),
          _ink(cream, 1.2),
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(39, 80, 22, 9),
            const Radius.circular(3),
          ),
          _ink(const Color(0xff5e8c73)),
        );
        canvas.drawLine(
          const Offset(42, 81),
          const Offset(45, 86),
          _ink(cream, 1),
        );
        canvas.drawLine(
          const Offset(58, 81),
          const Offset(55, 86),
          _ink(cream, 1),
        );
      case 'shirt_tux':
        canvas.drawPath(
          Path()
            ..moveTo(40, 64)
            ..lineTo(50, 88)
            ..lineTo(60, 64)
            ..close(),
          _ink(cream),
        );
        _bow(canvas, 50, 71, 6, const Color(0xffb96d7e));
        for (final y in [77.0, 82.0]) {
          canvas.drawCircle(Offset(50, y), 1.2, _ink(item.color));
        }
      case 'shirt_sailor':
        canvas.drawPath(
          Path()
            ..moveTo(34, 64)
            ..lineTo(43, 73)
            ..lineTo(50, 68)
            ..lineTo(57, 73)
            ..lineTo(66, 64),
          _ink(cream, 3),
        );
        _anchor(canvas, 50, 81, gold);
      case 'shirt_denim':
        canvas.drawLine(
          const Offset(50, 68),
          const Offset(50, 94),
          _ink(cream, 1),
        );
        for (final x in [37.0, 58.0]) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(x, 73, 9, 9),
              const Radius.circular(2),
            ),
            _ink(const Color(0xff637b94)),
          );
          canvas.drawLine(Offset(x + 1, 75), Offset(x + 8, 75), _ink(gold, .8));
        }
        for (final y in [72.0, 80.0, 88.0]) {
          canvas.drawCircle(Offset(50, y), 1, _ink(gold));
        }
      case 'shirt_paw':
        canvas.drawOval(const Rect.fromLTWH(45, 78, 10, 8), _ink(cream));
        for (final x in [43.0, 47.0, 53.0, 57.0]) {
          canvas.drawOval(
            Rect.fromCenter(
              center: Offset(x, x == 43 || x == 57 ? 77 : 73),
              width: 4,
              height: 5,
            ),
            _ink(cream),
          );
        }
      case 'shirt_strawberry':
        for (final at in [
          const Offset(37, 74),
          const Offset(60, 75),
          const Offset(50, 87),
        ]) {
          canvas.drawPath(
            _heart(at.dx, at.dy, 3.5),
            _ink(const Color(0xffd2536f)),
          );
          canvas.drawLine(
            at + const Offset(-2, -2),
            at + const Offset(2, -2),
            _ink(const Color(0xff5b9b72), 2),
          );
          canvas.drawCircle(at, .6, _ink(cream));
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
          1,
          _ink(const Color(0xff424750)),
        );
      case 'shirt_galaxy':
        for (var i = 0; i < 14; i++) {
          final angle = i * .8, r = 1.0 + i * .5;
          canvas.drawCircle(
            Offset(50 + math.cos(angle) * r, 80 + math.sin(angle) * r),
            1.6,
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
          canvas.drawPath(_star(at.dx, at.dy, 2), _ink(cream));
        }
      case 'shirt_honey':
        for (var y = 70.0; y < 93; y += 8) {
          canvas.drawLine(
            Offset(22, y),
            Offset(78, y),
            _ink(const Color(0xff635349), 4),
          );
        }
        canvas.drawOval(
          const Rect.fromLTWH(44, 74, 5, 4),
          _ink(const Color(0xbbffffff)),
        );
        canvas.drawOval(
          const Rect.fromLTWH(51, 74, 5, 4),
          _ink(const Color(0xbbffffff)),
        );
        canvas.drawOval(const Rect.fromLTWH(46, 77, 8, 6), _ink(gold));
        canvas.drawLine(
          const Offset(50, 78),
          const Offset(50, 82),
          _ink(const Color(0xff635349), 1.6),
        );
    }
    canvas.drawPath(
      Path()
        ..moveTo(31, 88)
        ..quadraticBezierTo(50, 96, 69, 88),
      _ink(const Color(0x55ffffff), 1.2),
    );
    canvas.drawPath(
      Path()
        ..moveTo(28, 70)
        ..lineTo(33, 74)
        ..moveTo(72, 70)
        ..lineTo(67, 74),
      _ink(const Color(0x66000000), 1),
    );
    canvas.drawPath(
      Path()
        ..moveTo(36, 63)
        ..quadraticBezierTo(50, 72, 64, 63),
      _ink(const Color(0x77ffffff), 2),
    );
    canvas.drawPath(
      Path()
        ..moveTo(31, 79)
        ..quadraticBezierTo(34, 85, 33, 89)
        ..moveTo(69, 79)
        ..quadraticBezierTo(66, 85, 67, 89),
      _ink(const Color(0x22000000), 1),
    );
    canvas.restore();
    canvas.drawPath(shirt, _ink(const Color(0x33000000), 1));
  }
  final neck = clothingById(outfit.neck);
  if (neck == null) return;
  if (neck.id.startsWith('bandana')) {
    final scarf = Path()
      ..moveTo(30, 64)
      ..quadraticBezierTo(50, 70, 70, 64)
      ..lineTo(51, 80)
      ..close();
    canvas.drawPath(scarf, _ink(neck.color));
    canvas.save();
    canvas.clipPath(scarf);
    if (neck.id == 'bandana_sakura') {
      _flower(canvas, 43, 71, 3);
      _flower(canvas, 56, 73, 2.5);
    } else if (neck.id == 'bandana_blue') {
      for (final x in [42.0, 50.0, 58.0]) {
        canvas.drawPath(_star(x, 70, 2), _ink(const Color(0xffe9ecdc)));
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
        _ink(const Color(0xff406b51), 1),
      );
    } else if (neck.id == 'bandana_pirate') {
      canvas.drawCircle(
        const Offset(51, 70),
        3.2,
        _ink(const Color(0xfff8edd7)),
      );
      canvas.drawCircle(const Offset(50, 70), .8, _ink(neck.color));
      canvas.drawCircle(const Offset(52, 70), .8, _ink(neck.color));
      canvas.drawLine(
        const Offset(47, 75),
        const Offset(55, 72),
        _ink(const Color(0xfff8edd7), 1.2),
      );
      canvas.drawLine(
        const Offset(47, 72),
        const Offset(55, 75),
        _ink(const Color(0xfff8edd7), 1.2),
      );
    } else {
      canvas.drawCircle(
        const Offset(51, 70),
        1.4,
        _ink(const Color(0xffffe5c0)),
      );
    }
    canvas.restore();
    return;
  }
  canvas.drawArc(
    const Rect.fromLTWH(30, 57, 40, 14),
    0,
    math.pi,
    false,
    _ink(neck.color, 4),
  );
  const gold = Color(0xffffd46a);
  switch (neck.id) {
    case 'collar_fish':
      canvas.drawOval(const Rect.fromLTWH(44, 70, 10, 6), _ink(gold));
      canvas.drawPath(
        Path()
          ..moveTo(52, 73)
          ..lineTo(58, 69)
          ..lineTo(58, 77)
          ..close(),
        _ink(gold),
      );
      canvas.drawCircle(const Offset(46, 72), .7, _ink(neck.color));
    case 'collar_pearl':
      for (var i = 0; i < 9; i++) {
        final a = i * math.pi / 8;
        canvas.drawCircle(
          Offset(50 + 18 * math.cos(a), 63 + 6 * math.sin(a)),
          2.2,
          _ink(const Color(0xfffff3e3)),
        );
      }
      canvas.drawCircle(const Offset(50, 73), 3, _ink(gold));
    case 'collar_ribbon':
      _bow(canvas, 50, 71, 8, neck.color);
      canvas.drawPath(
        Path()
          ..moveTo(47, 72)
          ..lineTo(44, 82)
          ..lineTo(49, 79)
          ..lineTo(52, 82)
          ..lineTo(53, 72)
          ..close(),
        _ink(neck.color),
      );
    case 'collar_cosmos':
      canvas.drawCircle(const Offset(50, 73), 5, _ink(const Color(0xffa88bdd)));
      canvas.drawOval(const Rect.fromLTWH(42, 71, 16, 4), _ink(gold, 1.4));
    case 'collar_heart':
      canvas.drawPath(_heart(50, 72, 4), _ink(gold));
    case 'collar_bell':
      canvas.drawCircle(const Offset(50, 72), 4, _ink(gold));
      canvas.drawLine(
        const Offset(48, 74),
        const Offset(52, 74),
        _ink(const Color(0xff9c7628), 1.2),
      );
    case 'collar_star':
      canvas.drawPath(_star(50, 73, 5), _ink(gold));
    case 'collar_moon':
      canvas.drawPath(
        Path()
          ..moveTo(53, 68)
          ..cubicTo(42, 67, 43, 79, 54, 76)
          ..cubicTo(48, 76, 47, 71, 53, 68)
          ..close(),
        _ink(const Color(0xffe2d8f1)),
      );
    case 'collar_bow':
      _bow(canvas, 50, 72, 8, neck.color);
    case 'collar_flower':
      _flower(canvas, 50, 73, 5);
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
    final fill = _ink(hat.color);
    switch (hat.id) {
      case 'bucket':
        canvas.drawPath(
          Path()
            ..moveTo(35, 12)
            ..quadraticBezierTo(50, 8, 65, 12)
            ..lineTo(70, 29)
            ..lineTo(30, 29)
            ..close(),
          fill,
        );
        canvas.drawOval(const Rect.fromLTWH(24, 25, 52, 9), fill);
        canvas.drawLine(
          const Offset(34, 23),
          const Offset(66, 23),
          _ink(const Color(0x66ffffff), 2),
        );
      case 'frog':
        canvas.drawOval(const Rect.fromLTWH(28, 15, 44, 19), fill);
        for (final x in [37.0, 63.0]) {
          canvas.drawCircle(Offset(x, 15), 6, fill);
          canvas.drawCircle(Offset(x, 14), 3.5, _ink(Colors.white));
          canvas.drawCircle(Offset(x, 14), 1.8, _ink(const Color(0xff37453c)));
        }
        canvas.drawArc(
          const Rect.fromLTWH(43, 22, 14, 6),
          0,
          math.pi,
          false,
          _ink(const Color(0xff4a7557), 1.2),
        );
      case 'halo':
        canvas.drawOval(
          const Rect.fromLTWH(30, 6, 40, 9),
          _ink(const Color(0x55fff0b8), 8),
        );
        canvas.drawOval(
          const Rect.fromLTWH(30, 6, 40, 9),
          _ink(hat.color, 2.5),
        );
        canvas.drawPath(_star(74, 16, 3), _ink(hat.color));
      case 'astronaut':
        canvas.drawPath(
          Path()..addOval(const Rect.fromLTWH(19, 9, 62, 61)),
          _ink(const Color(0x227addeb)),
        );
        canvas.drawOval(const Rect.fromLTWH(19, 9, 62, 61), _ink(hat.color, 3));
        canvas.drawLine(
          const Offset(30, 21),
          const Offset(39, 15),
          _ink(const Color(0xbbffffff), 2),
        );
        for (final x in [17.0, 77.0]) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(x, 37, 6, 14),
              const Radius.circular(2),
            ),
            fill,
          );
        }
        canvas.drawArc(
          const Rect.fromLTWH(27, 48, 46, 23),
          0,
          math.pi,
          false,
          _ink(hat.color, 5),
        );
      case 'hood_winter':
        canvas.drawArc(
          const Rect.fromLTWH(23, 14, 54, 53),
          math.pi,
          math.pi,
          false,
          _ink(hat.color, 9),
        );
        for (final x in [29.0, 71.0]) {
          canvas.drawCircle(Offset(x, 34), 8, fill);
          canvas.drawCircle(Offset(x, 34), 5.5, _ink(const Color(0xffffefdb)));
        }
        canvas.drawArc(
          const Rect.fromLTWH(28, 51, 44, 16),
          0,
          math.pi,
          false,
          _ink(hat.color, 5),
        );
      case 'beanie':
        canvas.drawPath(
          Path()
            ..moveTo(31, 26)
            ..quadraticBezierTo(32, 8, 50, 9)
            ..quadraticBezierTo(68, 8, 69, 26)
            ..close(),
          fill,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(29, 23, 42, 7),
            const Radius.circular(3),
          ),
          _ink(const Color(0xffc4b4ec)),
        );
        canvas.drawCircle(
          const Offset(50, 9),
          4.5,
          _ink(const Color(0xffe0d4f8)),
        );
        for (var x = 38.0; x < 68; x += 6) {
          canvas.drawLine(
            Offset(x, 15),
            Offset(x, 22),
            _ink(const Color(0x55ffffff), 1),
          );
        }
      case 'explorer':
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(34, 13, 32, 16),
            const Radius.circular(6),
          ),
          fill,
        );
        canvas.drawRect(
          const Rect.fromLTWH(34, 23, 32, 4),
          _ink(const Color(0xff846742)),
        );
        canvas.drawOval(
          const Rect.fromLTWH(24, 25, 52, 8),
          _ink(const Color(0xffddc18b)),
        );
      case 'cap':
        canvas.drawPath(
          Path()
            ..moveTo(31, 28)
            ..quadraticBezierTo(29, 10, 50, 11)
            ..quadraticBezierTo(69, 11, 70, 28)
            ..close(),
          fill,
        );
        canvas.drawOval(
          const Rect.fromLTWH(46, 25, 33, 8),
          _ink(const Color(0xffb9635c)),
        );
        canvas.drawLine(
          const Offset(50, 13),
          const Offset(51, 26),
          _ink(const Color(0xfff1bdad), 1),
        );
        canvas.drawPath(_star(39, 22, 3), _ink(const Color(0xffffe3b4)));
      case 'bow':
        _bow(canvas, 61, 20, 12, hat.color);
        for (final p in [
          const Offset(53, 16),
          const Offset(71, 22),
          const Offset(52, 23),
        ]) {
          canvas.drawCircle(p, 1.4, _ink(Colors.white));
        }
      case 'crown':
        canvas.drawPath(
          Path()
            ..moveTo(32, 29)
            ..lineTo(29, 12)
            ..lineTo(40, 20)
            ..lineTo(50, 7)
            ..lineTo(60, 20)
            ..lineTo(71, 12)
            ..lineTo(68, 29)
            ..close(),
          fill,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(32, 25, 36, 6),
            const Radius.circular(2),
          ),
          _ink(const Color(0xffffd56b)),
        );
        for (final x in [39.0, 50.0, 61.0]) {
          canvas.drawCircle(Offset(x, 27), 1.8, _ink(const Color(0xffbd6588)));
        }
      case 'wizard':
        canvas.drawPath(
          Path()
            ..moveTo(30, 28)
            ..lineTo(53, 4)
            ..quadraticBezierTo(61, 19, 68, 28)
            ..close(),
          fill,
        );
        canvas.drawOval(
          const Rect.fromLTWH(25, 26, 50, 7),
          _ink(const Color(0xff5d5490)),
        );
        canvas.drawPath(_star(52, 19, 3.5), _ink(const Color(0xffffdc83)));
        canvas.drawCircle(
          const Offset(46, 24),
          1.3,
          _ink(const Color(0xffffdc83)),
        );
      case 'sailor':
        canvas.drawOval(const Rect.fromLTWH(31, 13, 39, 16), fill);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(30, 24, 40, 7),
            const Radius.circular(2),
          ),
          _ink(const Color(0xff5b7799)),
        );
        canvas.drawPath(_star(50, 27, 2), _ink(const Color(0xffe7cb75)));
      case 'chef':
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(34, 16, 33, 15),
            const Radius.circular(3),
          ),
          fill,
        );
        for (final x in [36.0, 49.0, 63.0]) {
          canvas.drawCircle(Offset(x, 13), 9, fill);
        }
        canvas.drawLine(
          const Offset(35, 27),
          const Offset(66, 27),
          _ink(const Color(0xffcfbc9e), 1),
        );
      case 'party':
        final cone = Path()
          ..moveTo(34, 30)
          ..lineTo(51, 5)
          ..lineTo(66, 30)
          ..close();
        canvas.drawPath(cone, fill);
        canvas.save();
        canvas.clipPath(cone);
        for (var y = 10.0; y < 32; y += 7) {
          canvas.drawLine(
            Offset(32, y + 3),
            Offset(69, y - 3),
            _ink(const Color(0xffffd16e), 3),
          );
        }
        canvas.restore();
        canvas.drawCircle(
          const Offset(51, 5),
          3,
          _ink(const Color(0xffe58da4)),
        );
      case 'beret':
        canvas.drawOval(const Rect.fromLTWH(28, 11, 47, 18), fill);
        canvas.drawLine(
          const Offset(52, 12),
          const Offset(54, 7),
          _ink(hat.color, 3),
        );
        canvas.drawArc(
          const Rect.fromLTWH(32, 18, 37, 12),
          0,
          math.pi,
          false,
          _ink(const Color(0xff88445d), 3),
        );
    }
    canvas.restore();
  }
  final glasses = clothingById(outfit.eyes);
  if (glasses == null) return;
  final y = alien ? 33.0 : 43.0;
  final frame = _ink(glasses.color, glasses.id == 'glasses_pixel' ? 3 : 2.3);
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
  for (final x in [38.0, 62.0]) {
    if (glasses.id == 'glasses_monocle' && x == 38) continue;
    final lens = switch (glasses.id) {
      'glasses_flower' => _flowerLens(x, y),
      'glasses_cloud' =>
        Path()
          ..addOval(Rect.fromLTWH(x - 11, y - 4, 22, 12))
          ..addOval(Rect.fromLTWH(x - 7, y - 9, 11, 12))
          ..addOval(Rect.fromLTWH(x + 1, y - 8, 9, 11)),
      'glasses_ski' =>
        Path()..addRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(x - 12, y - 8, 24, 16),
            const Radius.circular(5),
          ),
        ),
      'glasses_cyber' =>
        Path()
          ..moveTo(x - 11, y - 6)
          ..lineTo(x + 10, y - 6)
          ..lineTo(x + 6, y + 7)
          ..lineTo(x - 7, y + 7)
          ..close(),
      'glasses_heart' => _heart(x, y - 1, 8),
      'glasses_star' => _star(x, y, 11),
      'glasses_cat' =>
        Path()
          ..moveTo(x - 11, y - 8)
          ..lineTo(x + 11, y - 11)
          ..quadraticBezierTo(x + 11, y + 9, x, y + 9)
          ..quadraticBezierTo(x - 9, y + 8, x - 11, y - 8)
          ..close(),
      'glasses_square' =>
        Path()..addRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset(x, y), width: 20, height: 17),
            const Radius.circular(3),
          ),
        ),
      'glasses_pixel' => Path()..addRect(Rect.fromLTWH(x - 10, y - 7, 20, 14)),
      'glasses_sport' =>
        Path()
          ..moveTo(x - 11, y - 5)
          ..lineTo(x + 11, y - 6)
          ..lineTo(x + 8, y + 7)
          ..lineTo(x - 6, y + 6)
          ..close(),
      'glasses_aviator' =>
        Path()
          ..moveTo(x - 9, y - 7)
          ..quadraticBezierTo(x + 12, y - 10, x + 9, y + 3)
          ..quadraticBezierTo(x + 1, y + 16, x - 8, y + 5)
          ..close(),
      'glasses_tiny' =>
        Path()..addOval(
          Rect.fromCenter(center: Offset(x, y + 2), width: 17, height: 11),
        ),
      _ => Path()..addOval(Rect.fromCircle(center: Offset(x, y), radius: 10)),
    };
    canvas.drawPath(
      lens,
      _ink(
        glasses.color.withValues(
          alpha: glasses.id == 'glasses_pixel' ? .48 : .16,
        ),
      ),
    );
    canvas.drawPath(lens, frame);
    canvas.drawLine(
      Offset(x - 4, y - 5),
      Offset(x + 2, y - 7),
      _ink(const Color(0x99ffffff), 1.3),
    );
  }
  if (glasses.id == 'glasses_monocle') {
    canvas.drawPath(
      Path()
        ..moveTo(71, y + 5)
        ..quadraticBezierTo(79, y + 24, 70, y + 29),
      _ink(glasses.color, 1.2),
    );
    return;
  }
  canvas.drawLine(Offset(48, y), Offset(52, y), frame);
  canvas.drawLine(Offset(28, y - 1), Offset(22, y - 4), frame);
  canvas.drawLine(Offset(72, y - 1), Offset(78, y - 4), frame);
}

// Fixed organic smudges, faded gradually by cleanliness and by the rinse gesture.
void paintCatDirt(Canvas canvas, double cleanliness, {bool head = false}) {
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
  for (var i = 0; i < spots.length; i++) {
    final (x, y, r) = spots[i];
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
    final a = i * math.pi / 24, r = 10 + math.cos(a * 6) * 1.8;
    final at = Offset(x + math.cos(a) * r, y + math.sin(a) * r);
    if (i == 0) {
      path.moveTo(at.dx, at.dy);
    } else {
      path.lineTo(at.dx, at.dy);
    }
  }
  return path..close();
}
