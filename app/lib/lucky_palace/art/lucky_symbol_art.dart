import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../cat_character.dart';
import '../lucky_palace_theme.dart';

import '../engine/lucky_symbol.dart';
export '../engine/lucky_symbol.dart';

/// Static geometry, shared by the symbol sheet and the machine.
abstract final class LuckyDrawing {
  static Paint fill(Color color) => Paint()
    ..isAntiAlias = true
    ..color = color;

  static Paint stroke(Color color, double width) => fill(color)
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  static void shape(Canvas c, Path path, Color color, {double width = 3}) {
    c.drawPath(path, fill(color));
    c.drawPath(path, stroke(LuckyPalette.ink, width));
  }

  static void line(Canvas c, Offset a, Offset b, Color color, double width) =>
      c.drawLine(a, b, stroke(color, width));

  static void text(
    Canvas c,
    String text,
    Offset center,
    double size, {
    Color color = LuckyPalette.cream,
    Color? outline,
    double width = 3,
  }) {
    TextPainter painter(TextStyle style) => TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout();
    if (outline != null) {
      final p = painter(
        LuckyPalette.text(
          size,
          title: true,
        ).copyWith(foreground: stroke(outline, width), color: null),
      );
      p.paint(c, center - Offset(p.width / 2, p.height / 2));
      p.dispose();
    }
    final p = painter(LuckyPalette.text(size, title: true, color: color));
    p.paint(c, center - Offset(p.width / 2, p.height / 2));
    p.dispose();
  }

  static void star(Canvas c, Offset center, double radius, Color color) {
    final p = Path();
    for (var i = 0; i < 8; i++) {
      final angle = -math.pi / 2 + i * math.pi / 4;
      final r = i.isEven ? radius : radius * .26;
      final point = center + Offset(math.cos(angle), math.sin(angle)) * r;
      if (i == 0) {
        p.moveTo(point.dx, point.dy);
      } else {
        p.lineTo(point.dx, point.dy);
      }
    }
    c.drawPath(p..close(), fill(color));
  }

  static void paw(Canvas c, Offset center, double scale, Color color) {
    c.save();
    c.translate(center.dx, center.dy);
    c.scale(scale);
    final pad = Path()
      ..moveTo(-18, 14)
      ..cubicTo(-28, 4, -12, -11, -6, -7)
      ..quadraticBezierTo(0, -15, 6, -7)
      ..cubicTo(12, -11, 28, 4, 18, 14)
      ..quadraticBezierTo(0, 22, -18, 14);
    c.drawPath(pad, fill(color));
    for (var i = 0; i < 4; i++) {
      final x = (i - 1.5) * 14;
      c.drawOval(
        Rect.fromCenter(
          center: Offset(x, i == 0 || i == 3 ? -13 : -23),
          width: 13,
          height: 18,
        ),
        fill(color),
      );
    }
    c.restore();
  }
}

class LuckySymbolArt extends StatelessWidget {
  const LuckySymbolArt({super.key, required this.symbol, this.size = 64});
  final LuckySymbol symbol;
  final double size;

  @override
  Widget build(BuildContext context) => Semantics(
    image: true,
    label: symbol.label,
    child: RepaintBoundary(
      child: CustomPaint(
        size: Size.square(size),
        painter: LuckySymbolPainter(symbol),
      ),
    ),
  );
}

class LuckySymbolPainter extends CustomPainter {
  const LuckySymbolPainter(this.symbol, {this.opticalSize});
  final LuckySymbol symbol;
  final double? opticalSize;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    final scale = math.min(size.width, size.height) / 128;
    canvas.translate(
      (size.width - 128 * scale) / 2,
      (size.height - 128 * scale) / 2,
    );
    canvas.scale(scale);
    paintSymbol(
      canvas,
      symbol,
      compact: (opticalSize ?? size.shortestSide) <= 40,
    );
    canvas.restore();
  }

  static void paintSymbol(
    Canvas c,
    LuckySymbol symbol, {
    bool compact = false,
  }) {
    const ink = LuckyPalette.ink;
    c.drawOval(
      const Rect.fromLTWH(25, 104, 78, 10),
      LuckyDrawing.fill(const Color(0x22442237)),
    );
    switch (symbol) {
      case LuckySymbol.yarn:
        final tail = Path()
          ..moveTo(84, 89)
          ..cubicTo(129, 72, 116, 119, 89, 111)
          ..quadraticBezierTo(78, 106, 70, 113);
        c.drawPath(tail, LuckyDrawing.stroke(ink, 8));
        c.drawPath(tail, LuckyDrawing.stroke(const Color(0xff55beb6), 4));
        const r = Rect.fromLTWH(21, 20, 85, 85);
        c.drawOval(
          r,
          Paint()
            ..shader = const RadialGradient(
              center: Alignment(-.4, -.5),
              colors: [Color(0xffbcfff0), Color(0xff3ba99f), Color(0xff247a87)],
            ).createShader(r),
        );
        c.drawOval(r, LuckyDrawing.stroke(ink, 3.5));
        c.save();
        c.clipPath(Path()..addOval(r));
        for (var i = 0; i < 5; i++) {
          final x = 8.0 + i * 16;
          c.drawPath(
            Path()
              ..moveTo(x, 12)
              ..cubicTo(x + 57, 32, x - 12, 79, x + 62, 114),
            LuckyDrawing.stroke(const Color(0xff247a87), 3),
          );
        }
        for (var i = 0; i < 3; i++) {
          final y = 38.0 + i * 19;
          c.drawPath(
            Path()
              ..moveTo(9, y)
              ..quadraticBezierTo(65, y + 39, 115, y - 6),
            LuckyDrawing.stroke(const Color(0xff89e3cd), 2),
          );
        }
        c.restore();
      case LuckySymbol.fish:
        final fish = Path()
          ..moveTo(91, 48)
          ..cubicTo(62, 8, 17, 30, 17, 63)
          ..cubicTo(17, 96, 65, 107, 91, 76)
          ..lineTo(112, 91)
          ..quadraticBezierTo(106, 65, 114, 36)
          ..close();
        c.drawPath(
          fish.shift(const Offset(0, 4)),
          LuckyDrawing.fill(const Color(0xff9e3a59)),
        );
        c.drawPath(
          fish,
          Paint()
            ..shader = const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xffffd7ab), Color(0xfff48681), Color(0xffc94f72)],
            ).createShader(const Rect.fromLTWH(15, 22, 100, 80)),
        );
        c.drawPath(fish, LuckyDrawing.stroke(ink, 3.5));
        c.drawCircle(
          const Offset(41, 54),
          10,
          LuckyDrawing.fill(LuckyPalette.cream),
        );
        c.drawCircle(const Offset(44, 54), 5, LuckyDrawing.fill(ink));
        c.drawCircle(
          const Offset(45, 51),
          1.8,
          LuckyDrawing.fill(Colors.white),
        );
        c.drawPath(
          Path()
            ..moveTo(64, 48)
            ..quadraticBezierTo(77, 63, 64, 79),
          LuckyDrawing.stroke(const Color(0xffa74162), 2.5),
        );
        LuckyDrawing.line(
          c,
          const Offset(29, 78),
          const Offset(36, 81),
          ink,
          2,
        );
      case LuckySymbol.churu:
        c.save();
        c.translate(64, 64);
        c.rotate(.58);
        final tube = Path()
          ..moveTo(-22, -43)
          ..lineTo(22, -43)
          ..lineTo(18, 44)
          ..lineTo(10, 49)
          ..lineTo(4, 44)
          ..lineTo(-3, 49)
          ..lineTo(-9, 44)
          ..lineTo(-18, 49)
          ..close();
        c.drawPath(
          tube,
          Paint()
            ..shader = LuckyPalette.goldGradient.createShader(
              const Rect.fromLTWH(-22, -43, 44, 92),
            ),
        );
        c.drawPath(tube, LuckyDrawing.stroke(ink, 3.5));
        c.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(-23, -52, 46, 14),
            const Radius.circular(4),
          ),
          LuckyDrawing.fill(const Color(0xffc85570)),
        );
        LuckyDrawing.line(
          c,
          const Offset(-13, -39),
          const Offset(-13, 34),
          LuckyPalette.goldLight,
          3,
        );
        LuckyDrawing.paw(c, const Offset(0, -4), .48, const Color(0xff9b3852));
        if (!compact) {
          LuckyDrawing.text(c, 'CHURU', const Offset(0, 29), 11, color: ink);
        }
        c.restore();
      case LuckySymbol.bell:
        c.save();
        c.translate(64, 67);
        c.rotate(-.18);
        c.drawOval(
          const Rect.fromLTWH(-12, -53, 24, 25),
          LuckyDrawing.stroke(ink, 8),
        );
        c.drawOval(
          const Rect.fromLTWH(-12, -53, 24, 25),
          LuckyDrawing.stroke(LuckyPalette.gold, 4),
        );
        final bell = Path()
          ..moveTo(-35, 18)
          ..cubicTo(-37, -45, 37, -45, 35, 18)
          ..quadraticBezierTo(47, 28, 39, 32)
          ..quadraticBezierTo(0, 47, -39, 32)
          ..quadraticBezierTo(-47, 28, -35, 18);
        c.drawPath(
          bell,
          Paint()
            ..shader = LuckyPalette.goldGradient.createShader(
              const Rect.fromLTWH(-40, -35, 80, 80),
            ),
        );
        c.drawPath(bell, LuckyDrawing.stroke(ink, 3.5));
        c.drawCircle(const Offset(0, 10), 8, LuckyDrawing.fill(ink));
        LuckyDrawing.line(c, const Offset(0, 10), const Offset(0, 35), ink, 5);
        c.drawOval(
          const Rect.fromLTWH(-23, -19, 12, 22),
          LuckyDrawing.fill(LuckyPalette.goldLight),
        );
        c.restore();
      case LuckySymbol.maru:
      case LuckySymbol.lady:
        final isMaru = symbol == LuckySymbol.maru;
        final r = RRect.fromRectAndRadius(
          const Rect.fromLTWH(12, 12, 104, 104),
          const Radius.circular(34),
        );
        c.drawRRect(r.shift(const Offset(0, 3)), LuckyDrawing.fill(ink));
        c.drawRRect(
          r,
          Paint()..shader = LuckyPalette.goldGradient.createShader(r.outerRect),
        );
        final inner = r.deflate(5);
        c.drawRRect(
          inner,
          LuckyDrawing.fill(
            isMaru ? const Color(0xff693650) : const Color(0xfff3b5ba),
          ),
        );
        c.save();
        c.clipRRect(inner);
        final painter = isMaru
            ? const MaruPainter(joy: .1)
            : const LadyPainter(joy: .1);
        painter.paint(c, const Size(128, 128));
        c.restore();
      case LuckySymbol.seven:
        final p = Path()
          ..moveTo(27, 22)
          ..lineTo(103, 22)
          ..lineTo(103, 41)
          ..quadraticBezierTo(70, 72, 65, 108)
          ..lineTo(36, 108)
          ..quadraticBezierTo(42, 70, 74, 45)
          ..lineTo(27, 45)
          ..close();
        c.drawPath(p.shift(const Offset(3, 4)), LuckyDrawing.stroke(ink, 10));
        c.drawPath(p, LuckyDrawing.stroke(LuckyPalette.gold, 10));
        c.drawPath(
          p,
          Paint()
            ..shader = const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xffff9fa7), Color(0xffc33262), Color(0xff8b244e)],
            ).createShader(const Rect.fromLTWH(25, 20, 80, 90)),
        );
        c.drawPath(p, LuckyDrawing.stroke(ink, 2));
        LuckyDrawing.line(
          c,
          const Offset(34, 29),
          const Offset(90, 29),
          const Color(0xffffd0ae),
          3,
        );
      case LuckySymbol.wild:
        final plaque = Path()
          ..moveTo(64, 10)
          ..lineTo(110, 34)
          ..lineTo(110, 86)
          ..lineTo(64, 117)
          ..lineTo(18, 86)
          ..lineTo(18, 34)
          ..close();
        c.drawPath(
          plaque,
          Paint()
            ..shader = LuckyPalette.goldGradient.createShader(
              const Rect.fromLTWH(18, 10, 92, 107),
            ),
        );
        c.drawPath(plaque, LuckyDrawing.stroke(ink, 3.5));
        c.drawPath(plaque, LuckyDrawing.stroke(LuckyPalette.goldLight, 1));
        LuckyDrawing.paw(
          c,
          const Offset(64, 61),
          1.05,
          const Color(0xff9c532a),
        );
        LuckyDrawing.paw(c, const Offset(63, 58), 1.0, LuckyPalette.goldLight);
        if (!compact) {
          LuckyDrawing.text(
            c,
            'WILD',
            const Offset(64, 98),
            20,
            color: LuckyPalette.cream,
            outline: LuckyPalette.goldDark,
          );
        }
      case LuckySymbol.scatter:
        c.save();
        c.translate(64, 64);
        c.rotate(-.23);
        final ticket = Path()
          ..moveTo(-48, -34)
          ..lineTo(48, -34)
          ..lineTo(48, -13)
          ..quadraticBezierTo(30, 0, 48, 13)
          ..lineTo(48, 34)
          ..lineTo(-48, 34)
          ..lineTo(-48, 13)
          ..quadraticBezierTo(-30, 0, -48, -13)
          ..close();
        c.drawPath(ticket.shift(const Offset(0, 4)), LuckyDrawing.fill(ink));
        c.drawPath(
          ticket,
          Paint()
            ..shader = const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xffc3adff), Color(0xff8550bd), Color(0xff522e89)],
            ).createShader(const Rect.fromLTWH(-48, -34, 96, 68)),
        );
        c.drawPath(ticket, LuckyDrawing.stroke(LuckyPalette.gold, 4));
        LuckyDrawing.star(c, const Offset(-10, -7), 20, LuckyPalette.goldLight);
        for (var y = -23.0; y < 25; y += 8) {
          LuckyDrawing.line(
            c,
            Offset(26, y),
            Offset(26, y + 3),
            LuckyPalette.cream,
            2,
          );
        }
        if (!compact) LuckyDrawing.text(c, 'SCATTER', const Offset(-6, 22), 12);
        c.restore();
    }
  }

  @override
  bool shouldRepaint(LuckySymbolPainter oldDelegate) =>
      oldDelegate.symbol != symbol || oldDelegate.opticalSize != opticalSize;
}
