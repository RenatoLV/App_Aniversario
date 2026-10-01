import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'cat_character.dart';

/// The printed face stays in 2D: perspective transforms can break glyphs on web.
class PackOpeningStage extends StatelessWidget {
  final Animation<double> animation;
  final int volume;
  final bool opening;
  final CatKind cat;

  const PackOpeningStage({
    super.key,
    required this.animation,
    required this.volume,
    required this.opening,
    required this.cat,
  });

  @override
  Widget build(BuildContext context) {
    final papu = volume == 1;
    final colors = papu
        ? const [Color(0xff30c5b0), Color(0xff185d84), Color(0xff203563)]
        : const [Color(0xffea78ae), Color(0xff8852bb), Color(0xff382c73)];
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      image: true,
      label:
          'Sobre Momazos volumen ${volume + 1}${opening ? ', abriendo' : ''}',
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: SizedBox(
            key: const ValueKey('pack-stage'),
            width: 340,
            height: 370,
            child: ClipRect(
              child: AnimatedBuilder(
                animation: animation,
                child: RepaintBoundary(
                  child: _PackFace(volume: volume, colors: colors),
                ),
                builder: (context, face) {
                  final t = opening ? animation.value : 0.0;
                  final tear = Curves.easeOutCubic.transform(
                    ((t - .5) / .22).clamp(0.0, 1.0),
                  );
                  final rise = Curves.easeOutCubic.transform(
                    ((t - .7) / .3).clamp(0.0, 1.0),
                  );
                  final pull = reducedMotion
                      ? 0.0
                      : t > .3 && t < .5
                      ? math.sin((t - .3) * math.pi * 30) * 2
                      : 0.0;
                  final sealOffset = Offset(
                    96 + pull - (reducedMotion ? 0 : tear * 14),
                    76 - tear * 47,
                  );
                  final sealAngle = reducedMotion ? 0.0 : -tear * .12;
                  return Stack(
                    children: [
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: RadialGradient(
                              colors: [
                                colors.first.withValues(
                                  alpha: .18 + tear * .08,
                                ),
                                colors.first.withValues(alpha: 0),
                              ],
                              radius: .7,
                            ),
                          ),
                        ),
                      ),
                      if (opening && !reducedMotion)
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _OpeningSparkles(t, colors.first),
                          ),
                        ),
                      Positioned(
                        left: 32,
                        top: 100,
                        child: Transform.rotate(
                          angle: -.09,
                          child: Container(
                            width: 174,
                            height: 232,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [colors.first, colors.last],
                              ),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: const Color(0xffefd8aa),
                                width: 1.5,
                              ),
                            ),
                            child: const Center(
                              child: PackPaw(
                                size: 48,
                                color: Color(0x55ffffff),
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (opening)
                        Positioned(
                          left: 148,
                          top: 97 - rise * 86,
                          child: Opacity(
                            opacity: rise,
                            child: Container(
                              key: const ValueKey('pack-rising-card'),
                              width: 112,
                              height: 154,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    const Color(0xffffeab3),
                                    colors.first,
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xfffff6dd),
                                  width: 3,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: colors.first.withValues(alpha: .2),
                                    blurRadius: 14,
                                  ),
                                ],
                              ),
                              child: const Align(
                                alignment: Alignment(0, -.6),
                                child: PackPaw(size: 36),
                              ),
                            ),
                          ),
                        ),
                      Positioned(
                        left: 96 + pull,
                        top: 76 + rise * 5,
                        width: 216,
                        height: 270,
                        child: face!,
                      ),
                      Positioned(
                        left: sealOffset.dx,
                        top: sealOffset.dy,
                        child: Opacity(
                          opacity: (1 - ((t - .74) / .12).clamp(0.0, 1.0)),
                          child: Transform.rotate(
                            alignment: Alignment.topLeft,
                            angle: sealAngle,
                            child: RepaintBoundary(
                              child: ClipPath(
                                clipper: const _SealClipper(),
                                child: Container(
                                  key: const ValueKey('pack-seal'),
                                  width: 216,
                                  height: 45,
                                  color: colors.last,
                                  alignment: Alignment.center,
                                  child: const Text(
                                    'SOBRE SORPRESA',
                                    style: TextStyle(
                                      color: Color(0xffffe8b1),
                                      fontSize: 10,
                                      letterSpacing: 2,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (opening)
                        Positioned.fill(
                          child: IgnorePointer(
                            child: CustomPaint(
                              key: const ValueKey('pack-opening-cat'),
                              painter: _OpeningCatChoreography(
                                cat: cat,
                                progress: t,
                                tear: tear,
                                sealOffset: sealOffset,
                                sealAngle: sealAngle,
                                reducedMotion: reducedMotion,
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OpeningCatChoreography extends CustomPainter {
  final CatKind cat;
  final double progress, tear, sealAngle;
  final Offset sealOffset;
  final bool reducedMotion;
  const _OpeningCatChoreography({
    required this.cat,
    required this.progress,
    required this.tear,
    required this.sealOffset,
    required this.sealAngle,
    required this.reducedMotion,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final t = progress;
    final arrival = Curves.easeOutCubic.transform((t / .2).clamp(0.0, 1.0));
    final reach = Curves.easeInOut.transform(((t - .15) / .15).clamp(0.0, 1.0));
    final release = Curves.easeInOut.transform(
      ((t - .76) / .16).clamp(0.0, 1.0),
    );
    final cheer = math.sin(((t - .76) / .24).clamp(0.0, 1.0) * math.pi);
    final origin = reducedMotion
        ? const Offset(22, 46)
        : Offset(
            4 + arrival * 22 - tear * 8,
            98 -
                arrival * 52 -
                math.sin(arrival * math.pi) * 16 -
                tear * 24 -
                cheer * 14,
          );
    canvas.save();
    canvas.translate(origin.dx, origin.dy);
    PackOpeningCatPainter(
      cat: cat,
      progress: reducedMotion ? 0 : t,
    ).paint(canvas, const Size.square(106));
    canvas.restore();

    final shoulder = origin + const Offset(68, 76);
    final restingPaw = origin + const Offset(70, 91);
    // This is the same transformed point on the seal, so the paw never slides
    // away from the strip while the cat is pulling it off.
    final grip =
        sealOffset +
        Offset(
          12 * math.cos(sealAngle) - 24 * math.sin(sealAngle),
          12 * math.sin(sealAngle) + 24 * math.cos(sealAngle),
        );
    final paw = Offset.lerp(
      Offset.lerp(restingPaw, grip, reach)!,
      origin + const Offset(80, 61),
      release,
    )!;
    final fur = cat == CatKind.maru
        ? const Color(0xff343230)
        : const Color(0xfffffdf7);
    final arm = Path()
      ..moveTo(shoulder.dx, shoulder.dy)
      ..quadraticBezierTo(shoulder.dx + 13, paw.dy + 13, paw.dx, paw.dy);
    canvas.drawPath(
      arm,
      Paint()
        ..color = const Color(0xff61564f)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 12
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawPath(
      arm,
      Paint()
        ..color = fur
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawOval(
      Rect.fromCenter(center: paw, width: 17, height: 13),
      Paint()..color = fur,
    );
    for (var i = 0; i < 3; i++) {
      canvas.drawCircle(
        paw + Offset(-5 + i * 4.5, -3),
        1.35,
        Paint()
          ..color = cat == CatKind.maru
              ? const Color(0xffa38e84)
              : const Color(0xffeab5c2),
      );
    }
    if (t > .3 && t < .5 && !reducedMotion) {
      final ink = Paint()
        ..color = const Color(0xffddbb73)
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round;
      for (var i = 0; i < 3; i++) {
        final start = grip + Offset(-8.0 + i * 7, -14);
        canvas.drawLine(start, start + Offset(-3.0 + i * 3, -5), ink);
      }
    }
  }

  @override
  bool shouldRepaint(_OpeningCatChoreography old) =>
      old.progress != progress ||
      old.cat != cat ||
      old.reducedMotion != reducedMotion;
}

class _PackFace extends StatelessWidget {
  final int volume;
  final List<Color> colors;
  const _PackFace({required this.volume, required this.colors});

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: colors,
      ),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xfff7dfab), width: 2),
      boxShadow: [
        BoxShadow(
          color: colors.last.withValues(alpha: .24),
          blurRadius: 16,
          offset: const Offset(0, 8),
        ),
      ],
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Stack(
        children: [
          const Positioned.fill(child: CustomPaint(painter: _WrapperPattern())),
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 55, 16, 16),
              child: Column(
                children: [
                  Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: .10),
                      border: Border.all(color: const Color(0x99ffe8b1)),
                    ),
                    child: const Center(
                      child: PackPaw(key: ValueKey('pack-emblem'), size: 43),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'MOMAZOS',
                    style: TextStyle(
                      fontSize: 23,
                      height: 1,
                      letterSpacing: 1.3,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 9),
                  Text(
                    'VOL. ${volume + 1 < 10 ? '0' : ''}${volume + 1}',
                    style: const TextStyle(
                      fontSize: 12,
                      letterSpacing: 3.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xffffe8b1),
                    ),
                  ),
                  const Spacer(),
                  const Divider(color: Color(0x55ffe8b1), height: 15),
                  Text(
                    volume == 1 ? 'EDICIÓN PAPU' : 'EDICIÓN ANIVERSARIO',
                    style: const TextStyle(
                      fontSize: 9,
                      letterSpacing: 1.1,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    '1 CARTA · 6 RAREZAS',
                    style: TextStyle(
                      fontSize: 8,
                      letterSpacing: 1.3,
                      color: Color(0xccffffff),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

/// Vector artwork avoids depending on a transformed icon-font glyph.
class PackPaw extends StatelessWidget {
  final double size;
  final Color color;
  const PackPaw({
    super.key,
    this.size = 44,
    this.color = const Color(0xffffedc6),
  });
  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: _PawPainter(color));
}

class _PawPainter extends CustomPainter {
  final Color color;
  const _PawPainter(this.color);
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 64, size.height / 64);
    final paint = Paint()..color = color;
    for (final oval in [
      const Rect.fromLTWH(3, 18, 13, 19),
      const Rect.fromLTWH(17, 5, 13, 21),
      const Rect.fromLTWH(34, 5, 13, 21),
      const Rect.fromLTWH(48, 18, 13, 19),
    ]) {
      canvas.drawOval(oval, paint);
    }
    canvas.drawPath(
      Path()
        ..moveTo(32, 29)
        ..cubicTo(24, 29, 19, 39, 13, 46)
        ..cubicTo(3, 61, 20, 62, 32, 55)
        ..cubicTo(44, 62, 61, 61, 51, 46)
        ..cubicTo(45, 39, 40, 29, 32, 29)
        ..close(),
      paint,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PawPainter oldDelegate) => oldDelegate.color != color;
}

class _WrapperPattern extends CustomPainter {
  const _WrapperPattern();
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x12ffffff)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (double x = -size.height; x < size.width; x += 22) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x + size.height, size.height),
        paint,
      );
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Offset.zero & size,
        const Radius.circular(18),
      ).deflate(7),
      paint..color = const Color(0x44ffe8b1),
    );
  }

  @override
  bool shouldRepaint(_WrapperPattern oldDelegate) => false;
}

class _SealClipper extends CustomClipper<Path> {
  const _SealClipper();
  @override
  Path getClip(Size size) {
    final path = Path()
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height - 5);
    for (var i = 18; i >= 0; i--) {
      path.lineTo(size.width * i / 18, size.height - (i.isEven ? 5 : 0));
    }
    return path..close();
  }

  @override
  bool shouldReclip(_SealClipper oldClipper) => false;
}

class _OpeningSparkles extends CustomPainter {
  final double progress;
  final Color color;
  const _OpeningSparkles(this.progress, this.color);
  @override
  void paint(Canvas canvas, Size size) {
    final burst = ((progress - .25) / .75).clamp(0.0, 1.0);
    final paint = Paint()
      ..color = Color.lerp(
        color,
        const Color(0xffe6b64c),
        .6,
      )!.withValues(alpha: math.sin(burst * math.pi) * .75)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 16; i++) {
      final angle = i * math.pi * 2 / 16;
      final radius = 95 + burst * 55 + (i % 3) * 8;
      final p = Offset(
        size.width / 2 + math.cos(angle) * radius,
        180 + math.sin(angle) * radius,
      );
      final extent = i.isEven ? 4.0 : 2.0;
      canvas.drawLine(p.translate(-extent, 0), p.translate(extent, 0), paint);
      canvas.drawLine(p.translate(0, -extent), p.translate(0, extent), paint);
    }
  }

  @override
  bool shouldRepaint(_OpeningSparkles oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}
