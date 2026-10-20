import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../cat_character.dart';
import '../lucky_palace_theme.dart';
import 'lucky_symbol_art.dart';
import 'lucky_cabinet_geometry.dart';
import '../lucky_demo.dart';

/// Static cabinet and animated foreground have separate repaint boundaries.
class LuckyCabinetArt extends StatelessWidget {
  const LuckyCabinetArt({
    super.key,
    required this.portrait,
    required this.spinButton,
    required this.frame,
    required this.onPull,
    required this.onRelease,
    required this.onLeverTap,
    this.integrated = false,
  });
  final bool portrait;
  final bool integrated;
  final Widget spinButton;
  final LuckyDemoFrame frame;
  final ValueChanged<double> onPull;
  final VoidCallback onRelease, onLeverTap;

  Rect _buttonRect(LuckyCabinetGeometry geometry, Size size) {
    final base = geometry.button(size);
    if (integrated) {
      final diameter = geometry
          .project(geometry.spin, size)
          .height
          .clamp(68.0, 86.0);
      final top = math.max(
        base.center.dy - diameter / 2,
        geometry.project(geometry.board, size).bottom + 6,
      );
      return Rect.fromLTWH(
        base.center.dx - diameter / 2,
        top,
        diameter,
        diameter,
      );
    }
    final top = math.max(
      base.top,
      geometry.project(geometry.board, size).bottom + 6,
    );
    return Rect.fromLTWH(base.left, top, base.width, base.height);
  }

  @override
  Widget build(BuildContext context) => Semantics(
    image: true,
    label:
        'Maru Lucky 777. Gabinete ilustrado de cinco rodillos y tres filas, '
        'con Maru y Lady como anfitriones. ${frame.referenceCost == null ? 'Muestra de arte sin apuestas.' : 'Juego con fichas del casino.'}',
    child: RepaintBoundary(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.biggest;
          final geometry = LuckyCabinetGeometry(portrait);
          return Stack(
            children: [
              Positioned.fromRect(
                rect: geometry.project(Offset.zero & geometry.design, size),
                child: const IgnorePointer(
                  child: SizedBox(key: ValueKey('lucky-art-bounds')),
                ),
              ),
              Positioned.fromRect(
                rect: geometry.project(geometry.board, size),
                child: const IgnorePointer(
                  child: SizedBox(key: ValueKey('lucky-reels-bounds')),
                ),
              ),
              Positioned.fill(
                child: integrated
                    ? (portrait
                          ? const RepaintBoundary(
                              child: CustomPaint(
                                painter: LuckyCabinetPainter(
                                  portrait: true,
                                  foreground: false,
                                  room: false,
                                ),
                              ),
                            )
                          : const RepaintBoundary(
                              child: CustomPaint(
                                painter: LuckyCabinetPainter(
                                  portrait: false,
                                  foreground: false,
                                  room: false,
                                ),
                              ),
                            ))
                    : portrait
                    ? const RepaintBoundary(
                        child: CustomPaint(
                          painter: LuckyCabinetPainter(
                            portrait: true,
                            foreground: false,
                          ),
                        ),
                      )
                    : const RepaintBoundary(
                        child: CustomPaint(
                          painter: LuckyCabinetPainter(
                            portrait: false,
                            foreground: false,
                          ),
                        ),
                      ),
              ),
              Positioned.fill(
                child: RepaintBoundary(
                  child: CustomPaint(
                    painter: LuckyCabinetPainter(
                      portrait: portrait,
                      frame: frame,
                    ),
                  ),
                ),
              ),
              Positioned.fromRect(
                rect: geometry.leverHit(size),
                child: Semantics(
                  button: true,
                  label: 'Accionar palanca',
                  onTap: onLeverTap,
                  child: GestureDetector(
                    key: const ValueKey('lucky-lever'),
                    excludeFromSemantics: true,
                    behavior: HitTestBehavior.opaque,
                    onTap: onLeverTap,
                    onVerticalDragUpdate: (details) =>
                        onPull(details.delta.dy / (90 * geometry.scale(size))),
                    onVerticalDragEnd: (_) => onRelease(),
                    onVerticalDragCancel: onRelease,
                  ),
                ),
              ),
              Positioned.fromRect(
                rect: _buttonRect(geometry, size),
                child: spinButton,
              ),
            ],
          );
        },
      ),
    ),
  );
}

class LuckyCabinetPainter extends CustomPainter {
  const LuckyCabinetPainter({
    required this.portrait,
    this.foreground = true,
    this.room = true,
    this.frame = const LuckyDemoFrame(),
  });
  final bool portrait, foreground, room;
  final LuckyDemoFrame frame;

  static const symbols = [
    LuckySymbol.wild,
    LuckySymbol.churu,
    LuckySymbol.seven,
    LuckySymbol.lady,
    LuckySymbol.bell,
    LuckySymbol.fish,
    LuckySymbol.maru,
    LuckySymbol.yarn,
    LuckySymbol.scatter,
    LuckySymbol.seven,
    LuckySymbol.bell,
    LuckySymbol.scatter,
    LuckySymbol.fish,
    LuckySymbol.churu,
    LuckySymbol.yarn,
  ];

  @override
  void paint(Canvas c, Size size) {
    final geometry = LuckyCabinetGeometry(portrait);
    final design = geometry.design;
    final scale = geometry.scale(size);
    if (!foreground && room) _room(c, size);
    c.save();
    c.translate(
      (size.width - design.width * scale) / 2,
      (size.height - design.height * scale) / 2,
    );
    c.scale(scale);
    if (!foreground) {
      _pedestal(c, geometry.console);
      // Rear metal spine makes the sign part of the same cabinet.
      final sign = portrait
          ? const Rect.fromLTWH(100, 4, 260, 78)
          : const Rect.fromLTWH(320, 0, 360, 66);
      for (final x in [sign.left + 28, sign.right - 28]) {
        final support = Rect.fromLTRB(
          x,
          sign.bottom - 9,
          x + 12,
          geometry.board.top + 5,
        );
        c.drawRect(
          support,
          Paint()..shader = LuckyPalette.goldGradient.createShader(support),
        );
        LuckyDrawing.line(
          c,
          support.topLeft,
          support.bottomLeft,
          LuckyPalette.goldLight,
          2,
        );
      }
      _marquee(c, sign);
      _cabinet(c, geometry.board, scale);
      _console(c, geometry.console);
      c.restore();
      return;
    }
    _host(c, geometry.maru, true);
    _host(c, geometry.lady, false);
    final grip = geometry.leverGrip(frame.pull);
    _lever(c, geometry.pivot, grip);
    _cabinet(c, geometry.board, scale);
    final rest = geometry.ladyRest;
    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: rest + const Offset(0, 5),
          width: 48,
          height: 12,
        ),
        const Radius.circular(5),
      ),
      LuckyDrawing.fill(LuckyPalette.goldDark),
    );
    LuckyDrawing.line(
      c,
      rest - const Offset(24, 1),
      rest + const Offset(24, -1),
      LuckyPalette.goldLight,
      3,
    );
    _arm(c, geometry.maru, grip, true);
    _arm(c, geometry.lady, geometry.ladyRest, false);
    _cost(c, geometry.console);
    _prize(c, geometry.console);
    if (frame.settled && frame.amount > 0) _celebration(c, geometry);
    c.restore();
  }

  void _celebration(Canvas c, LuckyCabinetGeometry g) {
    final energy = frame.celebration;
    if (energy <= 0) return;
    final count = frame.bigWin ? 18 : 5;
    for (var i = 0; i < count; i++) {
      final t = ((frame.seconds - 3.35) * .72 + i / count) % 1;
      final x = g.board.left + (i * 137 % 397) / 397 * g.board.width;
      final y = g.board.top - 16 + t * g.board.height;
      c.save();
      c.translate(x, y);
      c.scale(.45 + .55 * math.cos(t * math.pi * 4).abs(), 1);
      c.drawCircle(Offset.zero, 6, LuckyDrawing.fill(LuckyPalette.gold));
      c.drawCircle(
        Offset.zero,
        4,
        LuckyDrawing.stroke(LuckyPalette.goldLight, 1.5),
      );
      c.restore();
    }
  }

  void _pedestal(Canvas c, Rect console) {
    final r = Rect.fromLTWH(
      console.left + 12,
      console.bottom - 4,
      console.width - 24,
      45,
    );
    c.drawOval(
      Rect.fromLTWH(console.left - 8, r.bottom - 7, console.width + 45, 25),
      LuckyDrawing.fill(const Color(0x66000000)),
    );
    c.drawRRect(
      RRect.fromRectAndRadius(r, const Radius.circular(13)),
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xff241c2e), Color(0xff653249), Color(0xff251e2e)],
        ).createShader(r),
    );
    final tray = Rect.fromLTWH(
      r.left + r.width * .22,
      r.top + 8,
      r.width * .56,
      24,
    );
    c.drawRRect(
      RRect.fromRectAndRadius(tray, const Radius.circular(8)),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xff110e1d), Color(0xff392c3d), Color(0xff9a6961)],
        ).createShader(tray),
    );
    LuckyDrawing.line(
      c,
      tray.bottomLeft,
      tray.bottomRight,
      LuckyPalette.gold,
      3,
    );
    LuckyDrawing.line(
      c,
      Offset(r.left + 12, r.bottom - 2),
      Offset(r.right - 12, r.bottom - 2),
      LuckyPalette.goldDark,
      5,
    );
  }

  void _console(Canvas c, Rect r) {
    final plane = Path()
      ..moveTo(r.left + 14, r.top)
      ..lineTo(r.right - 20, r.top)
      ..lineTo(r.right, r.bottom)
      ..quadraticBezierTo(r.center.dx, r.bottom + 10, r.left, r.bottom)
      ..close();
    c.drawPath(
      plane.shift(const Offset(0, 9)),
      LuckyDrawing.fill(LuckyPalette.goldDark),
    );
    c.drawPath(
      plane,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xffd47994), Color(0xff802848), Color(0xff431d36)],
        ).createShader(r),
    );
    c.drawPath(plane, LuckyDrawing.stroke(LuckyPalette.gold, 3));
    LuckyDrawing.line(
      c,
      r.topLeft + const Offset(22, 3),
      r.topRight - const Offset(25, -3),
      LuckyPalette.goldLight,
      2,
    );
  }

  void _cost(Canvas c, Rect r) {
    final w = r.width * .24;
    _plaque(
      c,
      Rect.fromCenter(
        center: Offset(r.left + w * .62, r.center.dy),
        width: w,
        height: r.height * .55,
      ),
      frame.referenceCost == null ? 'MODO' : 'COSTE',
      frame.referenceCost == null
          ? 'TALLER'
          : frame.referenceCost == 0
          ? 'GRATIS'
          : '${frame.referenceCost}',
    );
  }

  void _prize(Canvas c, Rect r) {
    final w = r.width * .24;
    _plaque(
      c,
      Rect.fromCenter(
        center: Offset(r.right - w * .62, r.center.dy),
        width: w,
        height: r.height * .55,
      ),
      frame.referenceCost != null
          ? 'PREMIO'
          : frame.round == null
          ? 'PREMIO DEMO'
          : 'CRÉDITOS',
      frame.settled ? '+${frame.shownAmount}' : '—',
    );
  }

  void _arm(Canvas c, Rect cat, Offset grip, bool maru) {
    final shoulder = cat.topLeft + Offset(cat.width * .65, cat.height * .65);
    final wrist = grip - const Offset(0, 4);
    final elbow = Offset(shoulder.dx + (maru ? 11 : -3), shoulder.dy + 12);
    final width = cat.width * .075;
    final limb = Path()
      ..moveTo(shoulder.dx - width * .5, shoulder.dy - width * .6)
      ..quadraticBezierTo(
        elbow.dx + width,
        elbow.dy - 5,
        wrist.dx + width * .35,
        wrist.dy - width * .4,
      )
      ..quadraticBezierTo(
        wrist.dx + width * .8,
        wrist.dy + width * .45,
        wrist.dx - width * .35,
        wrist.dy + width * .5,
      )
      ..quadraticBezierTo(
        elbow.dx - width,
        elbow.dy + width,
        shoulder.dx - width * .65,
        shoulder.dy + width,
      )
      ..close();
    final fur = maru ? const Color(0xff9a9581) : const Color(0xfffbf7ee);
    c.drawPath(
      limb,
      Paint()
        ..shader = LinearGradient(
          colors: [
            fur,
            maru ? const Color(0xff696858) : const Color(0xffd9cfc3),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(limb.getBounds()),
    );
    c.drawPath(limb, LuckyDrawing.stroke(const Color(0xff30382f), 2));
    final paw = Rect.fromCenter(
      center: wrist,
      width: width * 1.35,
      height: width * .9,
    );
    c.drawOval(
      paw.shift(const Offset(0, 2)),
      LuckyDrawing.fill(const Color(0x4430382f)),
    );
    c.drawOval(paw, LuckyDrawing.fill(fur));
    c.drawOval(paw, LuckyDrawing.stroke(const Color(0xff30382f), 1.5));
    for (final dx in [-2.0, 2.0]) {
      LuckyDrawing.line(
        c,
        wrist + Offset(dx, 0),
        wrist + Offset(dx, 3),
        maru ? const Color(0xff4b5145) : const Color(0xffbda89c),
        .8,
      );
    }
  }

  void _room(Canvas c, Size size) {
    final all = Offset.zero & size;
    c.drawRect(
      all,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(0, -.2),
          radius: .95,
          colors: [Color(0xff3b2355), LuckyPalette.night],
        ).createShader(all),
    );
    // Broad theatrical beams, intentionally quiet behind the illustrations.
    for (var i = 0; i < 4; i++) {
      final x = size.width * (i / 3);
      final p = Path()
        ..moveTo(x, 0)
        ..lineTo(size.width * .5 + (i - 1.5) * 70, size.height * .84)
        ..lineTo(size.width * .5 + (i - 1.5) * 145, size.height * .84)
        ..close();
      c.drawPath(
        p,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              i.isEven ? const Color(0x2263e0d3) : const Color(0x22ef7ea8),
              Colors.transparent,
            ],
          ).createShader(all),
      );
    }
    for (final right in [false, true]) {
      c.save();
      if (right) {
        c.translate(size.width, 0);
        c.scale(-1, 1);
      }
      final curtain = Path()
        ..moveTo(0, 0)
        ..lineTo(size.width * .16, 0)
        ..cubicTo(
          size.width * .14,
          size.height * .3,
          size.width * .02,
          size.height * .38,
          size.width * .065,
          size.height,
        )
        ..lineTo(0, size.height)
        ..close();
      c.drawPath(
        curtain,
        Paint()
          ..shader = const LinearGradient(
            colors: [Color(0xff22152d), Color(0xff562449), Color(0xff2b1635)],
          ).createShader(Rect.fromLTWH(0, 0, size.width * .16, size.height)),
      );
      c.restore();
    }
    final floor = Rect.fromLTWH(
      0,
      size.height * .87,
      size.width,
      size.height * .13,
    );
    c.drawRect(
      floor,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xff3e1e42), Color(0xff191329)],
        ).createShader(floor),
    );
    for (var i = 0; i < 14; i++) {
      final x = ((i * 137 + 43) % 997) / 997 * size.width;
      final y = ((i * 83 + 31) % 431) / 431 * size.height * .84;
      LuckyDrawing.star(
        c,
        Offset(x, y),
        i % 3 == 0 ? 5 : 2,
        i.isEven ? const Color(0x99ffe6a0) : const Color(0x7763e0d3),
      );
    }
  }

  void _marquee(Canvas c, Rect rect) {
    c.save();
    c.translate(rect.left, rect.top);
    c.scale(rect.width / 360, rect.height / 112);
    final p = Path()
      ..moveTo(10, 93)
      ..lineTo(13, 22)
      ..quadraticBezierTo(12, -4, 50, 14)
      ..lineTo(73, 23)
      ..quadraticBezierTo(180, 0, 287, 23)
      ..lineTo(310, 14)
      ..quadraticBezierTo(348, -4, 347, 22)
      ..lineTo(350, 93)
      ..quadraticBezierTo(180, 122, 10, 93);
    c.drawPath(
      p.shift(const Offset(0, 6)),
      LuckyDrawing.fill(LuckyPalette.ink),
    );
    c.drawPath(
      p,
      Paint()
        ..shader = LuckyPalette.goldGradient.createShader(
          const Rect.fromLTWH(0, 0, 360, 112),
        ),
    );
    c.drawPath(p, LuckyDrawing.stroke(LuckyPalette.goldDark, 3));
    c.save();
    c.translate(180, 56);
    c.scale(.94, .84);
    c.translate(-180, -56);
    c.drawPath(
      p,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xffc14678), Color(0xff721f4b), Color(0xff431c3c)],
        ).createShader(const Rect.fromLTWH(0, 0, 360, 112)),
    );
    c.restore();
    for (var i = 0; i < 15; i++) {
      c.drawCircle(
        Offset(28 + i * 21.7, 26 + math.sin(i / 14 * math.pi) * -9),
        2.6,
        LuckyDrawing.fill(LuckyPalette.goldLight),
      );
    }
    LuckyDrawing.text(
      c,
      'MARU',
      const Offset(180, 41),
      29,
      color: LuckyPalette.goldLight,
      outline: LuckyPalette.ink,
      width: 5,
    );
    LuckyDrawing.text(
      c,
      'LUCKY 777',
      const Offset(180, 79),
      39,
      color: LuckyPalette.goldLight,
      outline: const Color(0xff702240),
      width: 5,
    );
    c.restore();
  }

  void _host(Canvas c, Rect rect, bool maru) {
    if (!portrait) {
      for (final x in [rect.left + 33, rect.right - 42]) {
        final leg = Rect.fromLTWH(x, rect.bottom - 8, 12, 112);
        c.drawRRect(
          RRect.fromRectAndRadius(leg, const Radius.circular(4)),
          Paint()
            ..shader = const LinearGradient(
              colors: [Color(0xffb67c43), Color(0xff422638)],
            ).createShader(leg),
        );
      }
    }
    final shelf = Rect.fromLTWH(
      rect.left + 16,
      rect.bottom - 12,
      rect.width - 28,
      14,
    );
    c.drawRRect(
      RRect.fromRectAndRadius(shelf, const Radius.circular(5)),
      LuckyDrawing.fill(LuckyPalette.goldDark),
    );
    LuckyDrawing.line(
      c,
      shelf.topLeft,
      shelf.topRight,
      LuckyPalette.goldLight,
      3,
    );
    c.drawOval(
      Rect.fromLTWH(
        rect.left + rect.width * .14,
        rect.bottom - 12,
        rect.width * .72,
        16,
      ),
      LuckyDrawing.fill(const Color(0x66000000)),
    );
    c.save();
    final bounce = frame.hasReward
        ? frame.celebration *
              math.sin((frame.seconds - 3.35) * 13).abs() *
              (frame.bigWin ? 5 : 2)
        : 0.0;
    c.translate(rect.left, rect.top - bounce);
    final painter = maru
        ? MaruPainter(
            phase: .16 + frame.pull * .08,
            joy: frame.hasReward ? frame.celebration * .45 : 0,
            blink:
                frame.started &&
                    !frame.hasReward &&
                    frame.seconds > 3.35 &&
                    frame.seconds < 3.7
                ? 1
                : 0,
            showWorkingPaw: false,
            outfit: CatOutfit(body: 'shirt_tux', neck: 'collar_ribbon'),
          )
        : LadyPainter(
            phase: .35 + frame.celebration * .08,
            joy: frame.hasReward ? frame.celebration * .6 : 0,
            blink:
                frame.started &&
                    !frame.hasReward &&
                    frame.seconds > 3.4 &&
                    frame.seconds < 3.8
                ? 1
                : 0,
            showWorkingPaw: false,
            outfit: CatOutfit(head: 'crown', neck: 'collar_pearl'),
          );
    painter.paint(c, rect.size);
    c.restore();
  }

  void _plaque(Canvas c, Rect rect, String first, String second) {
    final border = RRect.fromRectAndRadius(rect, const Radius.circular(13));
    c.drawRRect(
      border,
      Paint()..shader = LuckyPalette.goldGradient.createShader(rect),
    );
    c.drawRRect(border.deflate(3), LuckyDrawing.fill(LuckyPalette.night));
    LuckyDrawing.text(
      c,
      first,
      rect.center - const Offset(0, 9),
      portrait ? 13 : 17,
      color: LuckyPalette.goldLight,
    );
    LuckyDrawing.text(
      c,
      second,
      rect.center + const Offset(0, 11),
      portrait ? 18 : 23,
      color: LuckyPalette.mint,
    );
  }

  void _lever(Canvas c, Offset base, Offset end) {
    c.drawCircle(base, 21, LuckyDrawing.fill(LuckyPalette.goldDark));
    c.drawCircle(
      base - const Offset(0, 3),
      17,
      LuckyDrawing.fill(LuckyPalette.gold),
    );
    LuckyDrawing.line(c, base, end, LuckyPalette.ink, 12);
    LuckyDrawing.line(c, base, end, LuckyPalette.gold, 7);
    final r = Rect.fromCircle(center: end, radius: 18);
    c.drawCircle(
      end,
      18,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-.4, -.5),
          colors: [
            LuckyPalette.goldLight,
            LuckyPalette.gold,
            LuckyPalette.goldDark,
          ],
        ).createShader(r),
    );
    c.drawCircle(end, 18, LuckyDrawing.stroke(LuckyPalette.ink, 2));
  }

  void _cabinet(Canvas c, Rect rect, double viewportScale) {
    c.save();
    c.translate(rect.left, rect.top);
    c.scale(rect.width / 760, rect.height / 420);
    const faceRect = Rect.fromLTWH(0, 0, 760, 420);
    final outer = RRect.fromRectAndRadius(faceRect, const Radius.circular(36));
    if (!foreground) {
      // Extruded right side and lower lip remain visible beyond the face.
      c.drawRRect(
        outer.shift(const Offset(25, 28)),
        LuckyDrawing.fill(const Color(0xff251a2c)),
      );
      final side = Path()
        ..moveTo(728, 9)
        ..lineTo(780, 40)
        ..lineTo(784, 405)
        ..quadraticBezierTo(784, 445, 733, 443)
        ..lineTo(718, 401)
        ..close();
      c.drawPath(
        side,
        Paint()
          ..shader = const LinearGradient(
            colors: [Color(0xffd49b4e), Color(0xff5f283e), Color(0xff321a2c)],
          ).createShader(const Rect.fromLTWH(718, 9, 66, 434)),
      );
      LuckyDrawing.line(
        c,
        const Offset(775, 55),
        const Offset(778, 401),
        const Color(0xffbb7951),
        3,
      );
      c.drawRRect(
        outer.shift(const Offset(0, 12)),
        LuckyDrawing.fill(const Color(0xff392033)),
      );
      c.drawRRect(
        outer,
        Paint()..shader = LuckyPalette.goldGradient.createShader(faceRect),
      );
      c.drawRRect(outer.deflate(6), LuckyDrawing.fill(LuckyPalette.enamel));
      c.drawRRect(
        outer.deflate(10),
        LuckyDrawing.stroke(const Color(0xfff7a5b0), 2),
      );
    }
    const innerRect = Rect.fromLTWH(28, 28, 704, 348);
    final bezel = RRect.fromRectAndRadius(innerRect, const Radius.circular(20));
    if (!foreground) {
      c.drawRRect(
        bezel,
        Paint()..shader = LuckyPalette.goldGradient.createShader(innerRect),
      );
    }
    final window = bezel.deflate(8);
    if (!foreground) c.drawRRect(window, LuckyDrawing.fill(LuckyPalette.cream));
    c.save();
    c.clipRRect(window);
    final cellW = window.width / 5;
    final cellH = window.height / 3;
    for (var column = 0; column < 5; column++) {
      final strip = Rect.fromLTWH(
        window.left + column * cellW,
        window.top,
        cellW,
        window.height,
      );
      if (!foreground) {
        c.drawRect(
          strip,
          Paint()
            ..shader = const LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                Color(0xffaa7867),
                Color(0xfffff0d4),
                Color(0xfffffbed),
                Color(0xfffff0d4),
                Color(0xffad7c68),
              ],
              stops: [0, .16, .44, .82, 1],
            ).createShader(strip),
        );
      }
      if (!foreground && column > 0) {
        LuckyDrawing.line(
          c,
          strip.topLeft,
          strip.bottomLeft,
          const Color(0xffae7a62),
          2,
        );
        LuckyDrawing.line(
          c,
          strip.topLeft + const Offset(3, 0),
          strip.bottomLeft + const Offset(3, 0),
          const Color(0xfffff8db),
          2,
        );
      }
      if (foreground) {
        final pos = frame.reelPosition(column);
        final base = pos.floor();
        final fraction = pos - base;
        c.save();
        c.clipRect(strip);
        for (var row = -1; row <= 3; row++) {
          final center = Offset(
            strip.center.dx,
            window.top + (row + .5 - fraction) * cellH,
          );
          final aspect = (rect.width / 760) / (rect.height / 420);
          final symbolSize = math.min(cellW - 14, (cellH - 8) / aspect);
          final depth =
              (1 - .16 * ((center.dy - window.center.dy) / cellH).abs()).clamp(
                .65,
                1.0,
              );
          final winner = frame.settled && frame.winningCell(column, row);
          final pulse = winner
              ? 1 + frame.celebration * .08 * math.sin(frame.seconds * 12).abs()
              : 1.0;
          c.save();
          c.translate(center.dx, center.dy);
          final landingTime = frame.seconds - (2 + column * .22);
          final landing =
              frame.started &&
                  !frame.reduced &&
                  landingTime >= 0 &&
                  landingTime < .26
              ? math.sin(landingTime / .26 * math.pi) * .045
              : 0.0;
          c.scale(
            pulse * (1 + landing),
            depth * aspect * pulse * (1 - landing),
          );
          c.translate(-symbolSize / 2, -symbolSize / 2);
          LuckySymbolPainter(
            frame.symbolAt(column, base + row),
            opticalSize: symbolSize * (rect.width / 760) * viewportScale,
          ).paint(c, Size.square(symbolSize));
          c.restore();
        }
        c.restore();
      }
      if (foreground) {
        // Cylindrical roll-off above the printed symbols, under the glass.
        c.drawRect(
          strip,
          Paint()
            ..shader = const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0x99522d36),
                Color(0x00522d36),
                Color(0x00ffffff),
                Color(0x00522d36),
                Color(0xaa522d36),
              ],
              stops: [0, .16, .5, .84, 1],
            ).createShader(strip),
        );
      }
    }
    if (foreground) {
      c.drawPath(
        Path()
          ..moveTo(window.left + 2, window.top)
          ..lineTo(window.left + 86, window.top)
          ..lineTo(window.left + 222, window.bottom)
          ..lineTo(window.left + 198, window.bottom)
          ..close(),
        LuckyDrawing.fill(const Color(0x28ffffff)),
      );
    }
    if (foreground && frame.settled && frame.amount > 0) {
      const colors = [
        LuckyPalette.gold,
        LuckyPalette.mint,
        LuckyPalette.pink,
        Color(0xffbda5ff),
        Color(0xffffb67a),
      ];
      for (var i = 0; i < frame.wins.length; i++) {
        final win = frame.wins[i];
        final path = Path();
        for (var col = 0; col < win.count; col++) {
          final point = Offset(
            window.left + (col + .5) * cellW,
            window.top + (win.line.rows[col] + .5) * cellH,
          );
          if (col == 0) {
            path.moveTo(point.dx, point.dy);
          } else {
            path.lineTo(point.dx, point.dy);
          }
          c.drawCircle(
            point,
            6,
            LuckyDrawing.stroke(colors[i % colors.length], 2),
          );
        }
        c.drawPath(
          path,
          LuckyDrawing.stroke(
            colors[i % colors.length].withValues(alpha: .72),
            3,
          ),
        );
      }
    }
    c.restore();
    // Off, lit and highlighted bulbs with bounded radial light on the metal.
    for (var i = 0; i < 27; i++) {
      final x = 27.0 + i * 27.2;
      for (final y in [16.0, 388.0]) {
        c.drawCircle(
          Offset(x, y + 1),
          5,
          LuckyDrawing.fill(const Color(0xff62213d)),
        );
        _bulb(
          c,
          Offset(x, y),
          (i + (frame.celebration > 0 ? (frame.seconds * 12).floor() : 0)) % 5,
        );
      }
    }
    for (var i = 0; i < 11; i++) {
      for (final x in [15.0, 745.0]) {
        _bulb(c, Offset(x, 42 + i * 31), i % 5);
      }
    }
    LuckyDrawing.line(
      c,
      const Offset(264, 405),
      const Offset(355, 405),
      LuckyPalette.gold,
      1.5,
    );
    LuckyDrawing.paw(c, const Offset(380, 406), .24, LuckyPalette.goldLight);
    LuckyDrawing.line(
      c,
      const Offset(405, 405),
      const Offset(496, 405),
      LuckyPalette.gold,
      1.5,
    );
    c.restore();
  }

  void _bulb(Canvas c, Offset point, int level) {
    if (level == 0) {
      c.drawCircle(point, 3.3, LuckyDrawing.fill(const Color(0xff965c4c)));
      return;
    }
    if (level == 2 || level == 3) {
      c.drawCircle(
        point,
        11,
        Paint()
          ..shader = const RadialGradient(
            colors: [Color(0x99ffedaf), Color(0x00ffedaf)],
          ).createShader(Rect.fromCircle(center: point, radius: 11)),
      );
    }
    c.drawCircle(
      point,
      3.5,
      LuckyDrawing.fill(
        level == 3 ? const Color(0xfffffff0) : LuckyPalette.gold,
      ),
    );
    c.drawCircle(
      point - const Offset(.8, .8),
      1.1,
      LuckyDrawing.fill(LuckyPalette.goldLight),
    );
  }

  @override
  bool shouldRepaint(LuckyCabinetPainter oldDelegate) =>
      oldDelegate.portrait != portrait ||
      oldDelegate.foreground != foreground ||
      oldDelegate.room != room ||
      (foreground && oldDelegate.frame != frame);
}

/// One continuous room under game and controls; no rectangular scene behind the cabinet.
class LuckyRoomPainter extends CustomPainter {
  const LuckyRoomPainter();
  @override
  void paint(Canvas canvas, Size size) =>
      const LuckyCabinetPainter(portrait: true)._room(canvas, size);
  @override
  bool shouldRepaint(covariant LuckyRoomPainter oldDelegate) => false;
}
