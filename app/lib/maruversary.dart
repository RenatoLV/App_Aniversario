import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'store.dart';

bool isMaruversary(DateTime localDate) => localDate.day == 21;

/// Rechecks local dates at midnight, after clock changes and on app resume.
class MaruversaryDay extends StatefulWidget {
  const MaruversaryDay({super.key, required this.builder, this.clock});
  final Widget Function(BuildContext, bool) builder;
  final DateTime Function()? clock;

  @override
  State<MaruversaryDay> createState() => _MaruversaryDayState();
}

class _MaruversaryDayState extends State<MaruversaryDay>
    with WidgetsBindingObserver {
  Timer? _timer;
  late bool _celebrating;
  DateTime get _now => (widget.clock ?? DateTime.now)();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _celebrating = isMaruversary(_now);
    _schedule();
  }

  void _schedule() {
    _timer?.cancel();
    final now = _now;
    final untilMidnight = DateTime(
      now.year,
      now.month,
      now.day + 1,
    ).difference(now);
    _timer = Timer(
      untilMidnight < const Duration(minutes: 1)
          ? untilMidnight
          : const Duration(minutes: 1),
      _refresh,
    );
  }

  void _refresh() {
    final celebrating = isMaruversary(_now);
    if (celebrating != _celebrating) {
      setState(() => _celebrating = celebrating);
    }
    _schedule();
  }

  @override
  void didUpdateWidget(covariant MaruversaryDay oldWidget) {
    super.didUpdateWidget(oldWidget);
    _refresh();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _celebrating);
}

class MaruversaryWelcome extends StatefulWidget {
  const MaruversaryWelcome({super.key, this.store});
  final GameStore? store;

  @override
  State<MaruversaryWelcome> createState() => _MaruversaryWelcomeState();
}

class _MaruversaryWelcomeState extends State<MaruversaryWelcome>
    with SingleTickerProviderStateMixin {
  late final AnimationController _arrival = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 5),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _arrival.value = 1;
    } else if (!_arrival.isAnimating && !_arrival.isCompleted) {
      _arrival.forward();
    }
  }

  @override
  void dispose() {
    _arrival.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    child: Container(
      key: const ValueKey('maruversary-welcome'),
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xfffff1e3), Color(0xffffe5ee), Color(0xffeee6ff)],
        ),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0xffe9bb9b)),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 66,
            width: double.infinity,
            child: AnimatedBuilder(
              animation: _arrival,
              builder: (context, _) =>
                  CustomPaint(painter: _WelcomePartyPainter(_arrival.value)),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xfffff5d9),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: const Color(0xffdcb57c)),
            ),
            child: const Text(
              'NUESTRO PRIMER AÑO',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
                color: Color(0xff91602d),
              ),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            '¡Feliz maruversario!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Fredoka',
              fontSize: 29,
              fontWeight: FontWeight.w600,
              color: Color(0xff813c5b),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Te quiero mi maruzonita, eres la monita más linda de mi corazón. Que sean muchos añitos.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Nunito',
              fontSize: 14,
              height: 1.4,
              color: Color(0xff714b62),
            ),
          ),
          if (widget.store != null) ...[
            const SizedBox(height: 16),
            ListenableBuilder(
              listenable: widget.store!,
              builder: (context, _) => FilledButton.icon(
                key: const ValueKey('maruversary-claim-gift'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xff813c5b),
                  foregroundColor: const Color(0xfffff5d9),
                  minimumSize: const Size(48, 48),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                ),
                onPressed: widget.store!.maruversaryGiftClaimed
                    ? null
                    : widget.store!.claimMaruversaryGift,
                icon: Icon(
                  widget.store!.maruversaryGiftClaimed
                      ? Icons.check_circle_rounded
                      : Icons.card_giftcard_rounded,
                ),
                label: Text(
                  widget.store!.maruversaryGiftClaimed
                      ? 'Regalo reclamado · 1200 monedas'
                      : 'Reclamar 1200 monedas',
                ),
              ),
            ),
            const SizedBox(height: 5),
            const Text(
              'Un regalito por nuestro primer año · se reclama una sola vez',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 11,
                color: Color(0xff714b62),
              ),
            ),
          ],
        ],
      ),
    ),
  );
}

/// A finite entrance above the whole app; gestures reach the screen underneath.
class MaruversaryEntrance extends StatefulWidget {
  static void replay(BuildContext context) =>
      context.findAncestorStateOfType<_MaruversaryEntranceState>()?._replay();
  const MaruversaryEntrance({
    super.key,
    required this.child,
    this.enabled = true,
  });
  final Widget child;
  final bool enabled;

  @override
  State<MaruversaryEntrance> createState() => _MaruversaryEntranceState();
}

class _MaruversaryEntranceState extends State<MaruversaryEntrance>
    with SingleTickerProviderStateMixin {
  int _variant = 0;
  void _replay() {
    if (!widget.enabled || MediaQuery.disableAnimationsOf(context)) return;
    setState(() {
      _variant = (_variant + 1) % 6;
      _balloons.forward(from: 0);
    });
  }

  late final AnimationController _balloons =
      AnimationController(vsync: this, duration: const Duration(seconds: 7))
        ..addStatusListener((status) {
          if (status == AnimationStatus.completed && mounted) setState(() {});
        });

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!widget.enabled || MediaQuery.disableAnimationsOf(context)) {
      _balloons.value = 1;
    } else if (!_balloons.isAnimating && !_balloons.isCompleted) {
      _balloons.forward();
    }
  }

  @override
  void didUpdateWidget(covariant MaruversaryEntrance oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enabled != widget.enabled) {
      if (widget.enabled && !MediaQuery.disableAnimationsOf(context)) {
        _balloons.forward(from: 0);
      } else {
        _balloons.value = 1;
      }
    }
  }

  @override
  void dispose() {
    _balloons.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      widget.child,
      if (!_balloons.isCompleted)
        Positioned.fill(
          child: IgnorePointer(
            child: ExcludeSemantics(
              child: AnimatedBuilder(
                animation: _balloons,
                builder: (context, _) => CustomPaint(
                  key: const ValueKey('maruversary-entrance-balloons'),
                  painter: AnniversaryCelebrationPainter(
                    _balloons.value,
                    variant: _variant,
                  ),
                ),
              ),
            ),
          ),
        ),
    ],
  );
}

class AnniversaryCelebrationPainter extends CustomPainter {
  const AnniversaryCelebrationPainter(this.progress, {this.variant = 0});
  final double progress;
  final int variant;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || progress >= 1 || size.isEmpty) return;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    const colors = [
      Color(0xffe8bd74),
      Color(0xffe99bb8),
      Color(0xffb6a1d9),
      Color(0xfff4d69b),
    ];
    if (variant != 0 && variant != 2) {
      _paintShower(canvas, size, colors);
      canvas.restore();
      return;
    }
    for (var i = 0; i < 18; i++) {
      final flight = ((progress - (i % 6) * .035) / .80).clamp(0.0, 1.0);
      if (flight == 0 || flight == 1) continue;
      final radius = (size.width * .07).clamp(22.0, 48.0) + (i % 3) * 4;
      final x =
          size.width * ((i * 7 % 19 + .5) / 19) +
          math.sin(flight * math.pi * 3 + i) * 22;
      final y = size.height + radius * 3 - flight * (size.height + radius * 7);
      final rect = Rect.fromCenter(
        center: Offset(x, y),
        width: radius * 1.6,
        height: radius * 2,
      );
      final color = colors[i % colors.length];
      if (variant == 2) {
        for (final side in [-1.0, 1.0]) {
          canvas.drawPath(
            Path()
              ..moveTo(x + side * radius * .7, y - radius * .25)
              ..lineTo(x + side * radius * .85, y - radius * 1.25)
              ..lineTo(x + side * radius * .12, y - radius * .8)
              ..close(),
            Paint()..color = color,
          );
          canvas.drawPath(
            Path()
              ..moveTo(x + side * radius * .62, y - radius * .58)
              ..lineTo(x + side * radius * .72, y - radius * 1.03)
              ..lineTo(x + side * radius * .35, y - radius * .75)
              ..close(),
            Paint()..color = const Color(0xfff8d6df),
          );
        }
      }
      canvas.drawPath(
        Path()
          ..moveTo(x, y + radius)
          ..cubicTo(
            x - 18,
            y + radius * 1.7,
            x + 18,
            y + radius * 2.1,
            x - 3,
            y + radius * 2.8,
          ),
        Paint()
          ..color = const Color(0xffb7929e)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.1,
      );
      canvas.drawOval(
        rect,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(-.4, -.5),
            radius: 1.2,
            colors: [
              Color.lerp(color, Colors.white, .35)!,
              color,
              Color.lerp(color, const Color(0xff813c5b), .18)!,
            ],
          ).createShader(rect),
      );
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(x - radius * .34, y - radius * .4),
          width: radius * .24,
          height: radius * .55,
        ),
        Paint()..color = const Color(0x88ffffff),
      );
      canvas.drawPath(
        Path()
          ..moveTo(x, y + radius - 1)
          ..lineTo(x - 4, y + radius + 7)
          ..lineTo(x + 4, y + radius + 7)
          ..close(),
        Paint()..color = color,
      );
      if (variant == 2) {
        final ink = Paint()
          ..color = const Color(0xff76556d)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8
          ..strokeCap = StrokeCap.round;
        for (final side in [-1.0, 1.0]) {
          canvas.drawArc(
            Rect.fromCenter(
              center: Offset(x + side * radius * .28, y),
              width: radius * .22,
              height: radius * .18,
            ),
            math.pi,
            math.pi,
            false,
            ink,
          );
          for (var n = 0; n < 2; n++) {
            canvas.drawLine(
              Offset(x + side * radius * .38, y + radius * .18),
              Offset(x + side * radius * .7, y + radius * (.08 + n * .18)),
              ink,
            );
          }
        }
        _heart(
          canvas,
          Offset(x, y + radius * .16),
          radius * .18,
          const Color(0xffb96986),
        );
      } else if (i % 3 == 0) {
        final label = TextPainter(
          text: TextSpan(
            text: '1',
            style: TextStyle(
              fontFamily: 'Fredoka',
              fontSize: radius * 1.1,
              color: const Color(0xfffffaeb),
              fontWeight: FontWeight.w600,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        label.paint(canvas, Offset(x - label.width / 2, y - label.height / 2));
        label.dispose();
      } else {
        _heart(canvas, Offset(x, y + 2), radius * .5, const Color(0x99fff9ed));
      }
    }
    for (var i = 0; i < 36; i++) {
      final t = ((progress - (i % 5) * .025) / .9).clamp(0.0, 1.0);
      if (t == 0 || t == 1) continue;
      final x = size.width * ((i * 11 % 37) / 37) + math.sin(i + t * 9) * 18;
      final y = -20 + t * (size.height + 40);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(i + t * 8);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(-2, -4, 4, 8),
          const Radius.circular(1),
        ),
        Paint()..color = colors[i % 4].withValues(alpha: .8),
      );
      canvas.restore();
    }
    canvas.restore();
  }

  void _paintShower(Canvas c, Size size, List<Color> colors) {
    for (var i = 0; i < 32; i++) {
      final t = ((progress - i % 8 * .035) / .73).clamp(0.0, 1.0);
      if (t == 0 || t == 1) continue;
      final alpha = (math.sin(t * math.pi) * .85).clamp(0.0, 1.0);
      final color = colors[i % colors.length].withValues(alpha: alpha);
      final r = (size.width * .035).clamp(10.0, 22.0);
      final x = size.width * ((i * 11 % 33 + .5) / 33);
      final y = size.height * (1.1 - t * 1.3);
      c.save();
      c.translate(x + math.sin(t * 5 + i) * 22, y);
      c.rotate(math.sin(i + t * 3) * .45);
      final ink = Paint()..color = color;
      if (variant == 1) {
        // Paired, alternating pawprints climbing through the screen.
        c.drawOval(
          Rect.fromCenter(center: Offset(0, r * .22), width: r, height: r * .8),
          ink,
        );
        for (var toe = 0; toe < 4; toe++) {
          final a = math.pi + toe * math.pi / 3;
          c.drawOval(
            Rect.fromCenter(
              center: Offset(
                math.cos(a) * r * .62,
                math.sin(a) * r * .65 - r * .25,
              ),
              width: r * .35,
              height: r * .45,
            ),
            ink,
          );
        }
      } else if (variant == 3) {
        _heart(c, Offset.zero, r * 1.7, color);
        _heart(
          c,
          Offset(r, -r),
          r * .55,
          Colors.white.withValues(alpha: alpha),
        );
      } else if (variant == 4) {
        final trail = Paint()
          ..color = color.withValues(alpha: alpha * .4)
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round;
        c.drawLine(Offset(-r * 2, r * 3), Offset.zero, trail);
        final path = Path();
        for (var n = 0; n < 10; n++) {
          final a = n * math.pi / 5 - math.pi / 2;
          final radius = n.isEven ? r : r * .4;
          final p = Offset(math.cos(a), math.sin(a)) * radius;
          if (n == 0) {
            path.moveTo(p.dx, p.dy);
          } else {
            path.lineTo(p.dx, p.dy);
          }
        }
        c.drawPath(path..close(), ink);
      } else {
        final ribbon = Path()..moveTo(-r, -r * 2);
        for (var n = 0; n < 4; n++) {
          final yy = -r * 2 + n * r;
          ribbon.cubicTo(r * 2, yy, -r * 2, yy + r, r, yy + r);
        }
        c.drawPath(
          ribbon,
          ink
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3,
        );
        c.drawCircle(Offset(r * 1.8, -r), 2.5, Paint()..color = color);
      }
      c.restore();
    }
  }

  @override
  bool shouldRepaint(covariant AnniversaryCelebrationPainter oldDelegate) =>
      progress != oldDelegate.progress || variant != oldDelegate.variant;
}

/// Vector art stays sharp on phones and needs no network or external assets.
class MaruversaryCake extends StatelessWidget {
  const MaruversaryCake({super.key});

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Torta de maruversario de Maru y Lady con una vela número 1',
    image: true,
    child: const CustomPaint(painter: _CakePainter()),
  );
}

void _heart(Canvas canvas, Offset center, double size, Color color) {
  canvas.save();
  canvas.translate(center.dx, center.dy);
  canvas.scale(size / 20);
  canvas.drawPath(
    Path()
      ..moveTo(0, 8)
      ..cubicTo(-19, -3, -7, -16, 0, -7)
      ..cubicTo(7, -16, 19, -3, 0, 8)
      ..close(),
    Paint()..color = color,
  );
  canvas.restore();
}

class _CakePainter extends CustomPainter {
  const _CakePainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 180, size.height / 180);
    final paint = Paint();
    void oval(Rect rect, Color color) =>
        canvas.drawOval(rect, paint..color = color);
    void tier(Rect rect, Color top, Color bottom) {
      paint.shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [top, bottom],
      ).createShader(rect);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(12)),
        paint,
      );
      paint.shader = null;
    }

    // Porcelain plate, gilded pedestal, and soft shadow.
    oval(const Rect.fromLTWH(12, 165, 156, 12), const Color(0x224c2443));
    tier(
      const Rect.fromLTWH(83, 147, 14, 23),
      const Color(0xffffe7b2),
      const Color(0xffc68c54),
    );
    oval(const Rect.fromLTWH(61, 163, 58, 10), const Color(0xffdcb57c));
    oval(const Rect.fromLTWH(11, 137, 158, 22), const Color(0xffd0a46d));
    oval(const Rect.fromLTWH(12, 134, 156, 20), const Color(0xfffff5e6));
    // Two strawberry-and-cream tiers.
    tier(
      const Rect.fromLTWH(26, 96, 128, 45),
      const Color(0xffffcfdd),
      const Color(0xffd9799d),
    );
    oval(const Rect.fromLTWH(26, 88, 128, 23), const Color(0xfffff2df));
    for (var i = 0; i < 10; i++) {
      final x = 29.0 + i * 12.5;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, 99, 11, i.isEven ? 16 : 10),
          const Radius.circular(6),
        ),
        paint..color = const Color(0xfffff2df),
      );
    }
    tier(
      const Rect.fromLTWH(47, 63, 86, 37),
      const Color(0xfffff9eb),
      const Color(0xfff4d5b7),
    );
    oval(const Rect.fromLTWH(47, 55, 86, 20), const Color(0xfffffcf1));
    for (var i = 0; i < 7; i++) {
      final x = 51.0 + i * 12;
      oval(Rect.fromLTWH(x, 59, 8, 6), const Color(0xffffd1df));
      oval(Rect.fromLTWH(x, 94, 8, 7), const Color(0xfffff5e6));
    }
    for (final x in [45.0, 66.0, 90.0, 114.0, 135.0]) {
      oval(
        Rect.fromCenter(center: Offset(x, 137), width: 10, height: 7),
        const Color(0xfffff5e6),
      );
    }
    _heart(canvas, const Offset(90, 83), 18, const Color(0xffd57698));
    for (final x in [53.0, 127.0]) {
      _heart(canvas, Offset(x, 123), 12, const Color(0xfffff0e5));
    }
    // Strawberries with seeds and mint leaves.
    for (final x in [58.0, 121.0]) {
      _heart(canvas, Offset(x, 57), 13, const Color(0xffdd5473));
      oval(Rect.fromLTWH(x - 4, 46, 8, 4), const Color(0xff648f72));
      for (var i = 0; i < 3; i++) {
        oval(
          Rect.fromLTWH(x - 4 + i * 3, 53 + (i % 2) * 3, 1.5, 2),
          const Color(0xffffdfae),
        );
      }
    }
    // A real number-shaped candle, independent of installed fonts.
    final one = Path()
      ..moveTo(78, 31)
      ..lineTo(88, 24)
      ..lineTo(97, 24)
      ..lineTo(97, 54)
      ..lineTo(103, 54)
      ..lineTo(103, 61)
      ..lineTo(79, 61)
      ..lineTo(79, 54)
      ..lineTo(86, 54)
      ..lineTo(86, 35)
      ..lineTo(82, 38)
      ..close();
    canvas.drawPath(one, paint..color = const Color(0xffcc8f49));
    canvas.drawPath(
      one,
      Paint()
        ..color = const Color(0xffffdd8d)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8,
    );
    canvas.drawLine(
      const Offset(92, 25),
      const Offset(92, 19),
      Paint()
        ..color = const Color(0xff785851)
        ..strokeWidth = 2,
    );
    canvas.drawPath(
      Path()
        ..moveTo(92, 5)
        ..cubicTo(79, 18, 88, 23, 93, 20)
        ..cubicTo(102, 16, 94, 10, 92, 5),
      paint..color = const Color(0xffffad5c),
    );
    oval(const Rect.fromLTWH(89, 13, 5, 7), const Color(0xffffedb5));
    _heart(canvas, const Offset(29, 67), 10, const Color(0xffe5a0b9));
    _heart(canvas, const Offset(151, 51), 13, const Color(0xffe5a0b9));
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _CakePainter oldDelegate) => false;
}

class _WelcomePartyPainter extends CustomPainter {
  const _WelcomePartyPainter(this.progress);
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final colors = [
      const Color(0xffe99bb8),
      const Color(0xffb6a1d9),
      const Color(0xffe8bd74),
    ];
    final sway = math.sin(progress * math.pi * 4) * (1 - progress) * 5;
    for (var i = 0; i < 6; i++) {
      final x = size.width * (i < 3 ? .10 + i * .10 : .70 + (i - 3) * .10);
      final y = 22.0 + (i % 2) * 7 + sway * (i.isEven ? 1 : -1);
      canvas.drawPath(
        Path()
          ..moveTo(x, y + 13)
          ..quadraticBezierTo(x - 7, y + 23, x + 2, 62),
        Paint()
          ..color = const Color(0xffb7929e)
          ..style = PaintingStyle.stroke
          ..strokeWidth = .9,
      );
      canvas.drawOval(
        Rect.fromCenter(center: Offset(x, y), width: 24, height: 30),
        Paint()..color = colors[i % 3],
      );
      canvas.drawOval(
        Rect.fromLTWH(x - 7, y - 10, 5, 9),
        Paint()..color = const Color(0x88ffffff),
      );
      canvas.drawPath(
        Path()
          ..moveTo(x, y + 13)
          ..lineTo(x - 3, y + 17)
          ..lineTo(x + 3, y + 17)
          ..close(),
        Paint()..color = colors[i % 3],
      );
    }
    // Lipstick kisses and little hearts float between the balloons.
    for (final (fraction, angle) in [(.45, -.2), (.56, .2)]) {
      canvas.save();
      canvas.translate(size.width * fraction, 32 - sway);
      canvas.rotate(angle);
      canvas.drawPath(
        Path()
          ..moveTo(-12, 0)
          ..cubicTo(-5, -10, -2, -6, 0, -4)
          ..cubicTo(2, -6, 5, -10, 12, 0)
          ..quadraticBezierTo(0, 14, -12, 0)
          ..close(),
        Paint()..color = const Color(0xffc96085),
      );
      canvas.drawPath(
        Path()
          ..moveTo(-10, 0)
          ..quadraticBezierTo(0, 4, 10, 0),
        Paint()
          ..color = const Color(0xffffdce8)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );
      canvas.restore();
    }
    _heart(canvas, Offset(size.width * .50, 11), 9, const Color(0xffd78fab));
    _heart(canvas, Offset(size.width * .50, 55), 7, const Color(0xffb6a1d9));
  }

  @override
  bool shouldRepaint(covariant _WelcomePartyPainter oldDelegate) =>
      progress != oldDelegate.progress;
}
