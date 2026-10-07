import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'house_day_cycle.dart';
import 'patio_weather.dart';

class PatioDoorPainter extends CustomPainter {
  const PatioDoorPainter({
    this.light = const HouseLight(1, 0, HousePeriod.day),
  });
  final HouseLight light;
  @override
  void paint(Canvas c, Size size) {
    c.save();
    c.scale(size.width / 80, size.height / 120);
    final frame = RRect.fromRectAndRadius(
      const Rect.fromLTWH(1, 1, 78, 118),
      const Radius.circular(9),
    );
    c.drawRRect(frame, Paint()..color = const Color(0xffcaa77d));
    c.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(7, 7, 66, 108),
        const Radius.circular(5),
      ),
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xff789b83), Color(0xff456d58)],
        ).createShader(const Rect.fromLTWH(7, 7, 66, 108)),
    );
    final glass = RRect.fromRectAndRadius(
      const Rect.fromLTWH(17, 17, 46, 49),
      const Radius.circular(16),
    );
    c.drawRRect(glass, Paint()..color = light.skyTop);
    c.save();
    c.clipRRect(glass);
    c.drawOval(
      const Rect.fromLTWH(0, 47, 85, 42),
      Paint()
        ..color = light.tint(const Color(0xff80ba76), const Color(0xff355f4c)),
    );
    c.drawCircle(
      const Offset(49, 30),
      8,
      Paint()
        ..color = light.tint(const Color(0xffffe69c), const Color(0xffeee4c5)),
    );
    c.restore();
    c.drawLine(
      const Offset(40, 17),
      const Offset(40, 65),
      Paint()
        ..color = const Color(0xffe4d9b9)
        ..strokeWidth = 3,
    );
    c.drawLine(
      const Offset(17, 42),
      const Offset(63, 42),
      Paint()
        ..color = const Color(0xffe4d9b9)
        ..strokeWidth = 3,
    );
    c.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(18, 78, 44, 24),
        const Radius.circular(4),
      ),
      Paint()..color = const Color(0xff365a46),
    );
    c.drawCircle(
      const Offset(63, 75),
      4,
      Paint()..color = const Color(0xfff6d489),
    );
    c.restore();
  }

  @override
  bool shouldRepaint(covariant PatioDoorPainter old) => old.light != light;
}

class PatioBackdrop extends CustomPainter {
  PatioBackdrop({
    required this.light,
    this.conditions,
    this.phase = 0,
    this.field = false,
    super.repaint,
  });
  final HouseLight light;
  final PatioConditions? conditions;
  final double phase;
  final bool field;
  @override
  void paint(Canvas c, Size size) {
    c.save();
    c.scale(size.width / 400, size.height / 580);
    final sky = conditions?.sky ?? PatioSky.clear;
    final wet = sky == PatioSky.rain || sky == PatioSky.storm;
    final cloudy = sky != PatioSky.clear;
    final haze = conditions?.code == 1
        ? .15
        : conditions?.code == 2
        ? .25
        : .38;
    final top = cloudy
        ? Color.lerp(light.skyTop, const Color(0xff6c7f8b), haze)!
        : light.skyTop;
    const bounds = Rect.fromLTWH(0, 0, 400, 580);
    c.drawRect(
      bounds,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [top, light.skyBottom],
        ).createShader(const Rect.fromLTWH(0, 0, 400, 210)),
    );
    for (var i = 0; i < 24; i++) {
      final twinkle = i % 4 == 0
          ? 1.0
          : .55 + .45 * math.sin(phase * math.pi * 2 + i * 1.7).abs();
      c.drawCircle(
        Offset(15 + (i * 67 % 365).toDouble(), 14 + (i * 43 % 108).toDouble()),
        i % 3 == 0 ? 1.8 : 1.1,
        Paint()
          ..color = const Color(
            0xffffefc5,
          ).withValues(alpha: light.night * twinkle * (cloudy ? .18 : .9)),
      );
    }
    final sun = Offset(310, 56 + light.warmth * 44);
    c.drawCircle(
      sun,
      42,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xffffdf8c).withValues(alpha: light.daylight * .25),
            Colors.transparent,
          ],
        ).createShader(Rect.fromCircle(center: sun, radius: 42)),
    );
    c.drawCircle(
      sun,
      22,
      Paint()
        ..color = const Color(
          0xffffe4a3,
        ).withValues(alpha: light.daylight * (cloudy ? .4 : 1)),
    );
    c.drawCircle(
      const Offset(314, 55),
      18,
      Paint()..color = const Color(0xffffefd0).withValues(alpha: light.night),
    );
    c.drawCircle(
      const Offset(321, 49),
      17,
      Paint()..color = top.withValues(alpha: light.night),
    );
    for (var i = 0; i < (cloudy ? 6 : 3); i++) {
      final x = ((i * 103 + phase * 22) % 470) - 30;
      final y = 35 + (i * 27 % 67).toDouble();
      final paint = Paint()
        ..color = light
            .tint(const Color(0xfff3f5ed), const Color(0xff798197))
            .withValues(alpha: cloudy ? .76 : .55);
      c.drawOval(
        Rect.fromCenter(center: Offset(x, y), width: 74, height: 21),
        paint,
      );
      c.drawCircle(Offset(x - 13, y - 6), 15, paint);
      c.drawCircle(Offset(x + 9, y - 9), 19, paint);
    }
    c.save();
    if (field) c.translate(0, -80);
    final farHill = Path()
      ..moveTo(0, 170)
      ..quadraticBezierTo(100, 95, 240, 165)
      ..quadraticBezierTo(340, 110, 400, 153)
      ..lineTo(400, 240)
      ..lineTo(0, 240)
      ..close();
    c.drawPath(
      farHill,
      Paint()
        ..color = light.tint(const Color(0xff8cb798), const Color(0xff354f54)),
    );
    for (final x in [22.0, 365.0]) {
      final sway =
          math.sin(phase * math.pi * 2 + x) *
          (conditions?.wind ?? 6).clamp(2, 22) *
          .12;
      c.drawLine(
        Offset(x, 190),
        Offset(x + sway, 120),
        Paint()
          ..color = light.tint(const Color(0xff886b4e), const Color(0xff45403b))
          ..strokeWidth = 12,
      );
      for (var j = 0; j < 3; j++) {
        c.drawOval(
          Rect.fromCenter(
            center: Offset(x + sway + (j - 1) * 13, 110 + j % 2 * 16),
            width: 66,
            height: 65,
          ),
          Paint()
            ..color = light.tint(
              Color.lerp(
                const Color(0xff689b68),
                const Color(0xff91b775),
                j / 3,
              )!,
              const Color(0xff294b45),
            ),
        );
      }
    }
    for (var i = 0; i < 24; i++) {
      final x = i * 18.0 - 8;
      c.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, 163, 12, 46),
          const Radius.circular(4),
        ),
        Paint()
          ..color = light.tint(
            const Color(0xffdec7a2),
            const Color(0xff6b6567),
          ),
      );
    }
    for (final y in [178.0, 196.0]) {
      c.drawLine(
        Offset(0, y),
        Offset(400, y),
        Paint()
          ..color = light.tint(const Color(0xffc5aa84), const Color(0xff57535a))
          ..strokeWidth = 5,
      );
    }
    c.restore();
    final groundY = field ? 127.0 : 207.0;
    final ground = light.tint(
      const Color(0xff80b676),
      const Color(0xff254b44),
      const Color(0xffb19a69),
    );
    c.drawRect(
      Rect.fromLTWH(0, groundY, 400, 580 - groundY),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            ground,
            light.tint(const Color(0xffb0cb87), const Color(0xff35624c)),
          ],
        ).createShader(Rect.fromLTWH(0, groundY, 400, 580 - groundY)),
    );
    if (field) {
      for (var i = 0; i < 6; i++) {
        c.drawRect(
          Rect.fromLTWH(18, 214 + i * 57, 364, 28),
          Paint()..color = Colors.white.withValues(alpha: .035),
        );
      }
      final line = Paint()
        ..color = const Color(0xffe8efdb).withValues(alpha: .4)
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;
      c.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(22, 146, 356, 404),
          const Radius.circular(8),
        ),
        line,
      );
      c.drawCircle(const Offset(200, 385), 61, line);
      c.drawLine(const Offset(22, 385), const Offset(378, 385), line);
      c.drawRect(const Rect.fromLTWH(110, 146, 180, 100), line);
    } else {
      for (var i = 0; i < 6; i++) {
        c.drawOval(
          Rect.fromCenter(
            center: Offset(203 + math.sin(i * .7) * 20, 220 + i * 56),
            width: 45 + i * 10,
            height: 22 + i * 4,
          ),
          Paint()
            ..color = light.tint(
              const Color(0xffe6d5b5),
              const Color(0xff77807a),
            ),
        );
      }
    }
    for (var i = 0; i < 64; i++) {
      final x = (i * 73 % 392).toDouble(), y = 225 + (i * 59 % 350).toDouble();
      final sway = math.sin(phase * math.pi * 2 + i) * 3;
      c.drawPath(
        Path()
          ..moveTo(x - 3, y)
          ..quadraticBezierTo(x - 4 + sway, y - 7, x - 1, y - 10)
          ..moveTo(x, y)
          ..quadraticBezierTo(x + 5 + sway, y - 8, x + 7, y - 8),
        Paint()
          ..color = light.tint(const Color(0xff5b985f), const Color(0xff386f58))
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );
    }
    for (var i = 0; i < 16; i++) {
      final x = i.isEven ? 12 + i * 2.0 : 388 - i * 2.0;
      final y = 255 + i * 19.0;
      c.drawLine(
        Offset(x, y),
        Offset(x, y - 9),
        Paint()
          ..color = ground
          ..strokeWidth = 2,
      );
      c.drawCircle(
        Offset(x, y - 12),
        4,
        Paint()
          ..color = light.tint(
            i % 3 == 0 ? const Color(0xffffcbd6) : const Color(0xfffce8a7),
            const Color(0xffaa8fa7),
          ),
      );
      c.drawCircle(
        Offset(x, y - 12),
        1.5,
        Paint()..color = const Color(0xffd9a95c),
      );
    }
    for (final x in [38.0, 362.0]) {
      c.drawLine(
        Offset(x, 265),
        Offset(x, 235),
        Paint()
          ..color = const Color(0xff626656)
          ..strokeWidth = 3,
      );
      c.drawCircle(
        Offset(x, 232),
        30,
        Paint()
          ..shader = RadialGradient(
            colors: [
              const Color(0xffffde95).withValues(alpha: light.night * .27),
              Colors.transparent,
            ],
          ).createShader(Rect.fromCircle(center: Offset(x, 232), radius: 30)),
      );
      c.drawCircle(
        Offset(x, 232),
        6,
        Paint()
          ..color = light.tint(
            const Color(0xffe2d8ad),
            const Color(0xffffe1a1),
          ),
      );
    }
    if (sky == PatioSky.fog) {
      c.drawRect(
        const Rect.fromLTWH(0, 120, 400, 240),
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0x0099b1b5), Color(0x6699b1b5), Color(0x0099b1b5)],
          ).createShader(const Rect.fromLTWH(0, 120, 400, 240)),
      );
    }
    if (wet || sky == PatioSky.snow) {
      for (var i = 0; i < 32; i++) {
        final x = ((i * 89 + phase * 80) % 420) - 10;
        final y = (i * 71 + phase * (wet ? 1150 : 220)) % 580;
        final p = Paint()
          ..color = const Color(0xffcce8ed).withValues(alpha: wet ? .43 : .8)
          ..strokeWidth = 1.3;
        if (wet) {
          c.drawLine(Offset(x, y), Offset(x - 5, y + 13), p);
        } else {
          c.drawCircle(Offset(x, y), 2, p);
        }
      }
    }
    c.restore();
  }

  @override
  bool shouldRepaint(covariant PatioBackdrop old) =>
      light != old.light ||
      conditions != old.conditions ||
      phase != old.phase ||
      field != old.field;
}
