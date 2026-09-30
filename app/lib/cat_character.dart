import 'dart:math' as math;
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum CatKind { maru, lady }

enum CatAction { idle, pack, blocks, collection, notes }

/// A small animated character built entirely from paths. No bitmap assets are used.
class CatActor extends StatefulWidget {
  final CatKind cat;
  final double size;
  final CatAction action;
  final bool active;
  final double focus;
  final bool showLabel;
  final bool showShadow;
  final bool movable;
  final bool feeding;
  final bool munching;
  final bool digging;
  final bool crying;
  final double packProgress;
  final VoidCallback? onPet;

  const CatActor({
    super.key,
    required this.cat,
    required this.size,
    this.action = CatAction.idle,
    this.active = false,
    this.focus = 0,
    this.showLabel = true,
    this.showShadow = true,
    this.movable = false,
    this.feeding = false,
    this.munching = false,
    this.digging = false,
    this.crying = false,
    this.packProgress = 0,
    this.onPet,
  });

  @override
  State<CatActor> createState() => _CatActorState();
}

class _CatActorState extends State<CatActor> with TickerProviderStateMixin {
  late final AnimationController _idle;
  late final AnimationController _pet;
  Timer? _napTimer;
  Timer? _wakeTimer;
  bool _sleeping = false;
  int _reaction = 0;
  Offset _offset = Offset.zero;
  Offset _dragOrigin = Offset.zero;

  void _scheduleNap() {
    _napTimer?.cancel();
    if (widget.action != CatAction.idle || widget.active) return;
    _napTimer = Timer(
      Duration(seconds: widget.cat == CatKind.maru ? 11 : 14),
      () {
        if (mounted) _goToSleep();
      },
    );
  }

  void _goToSleep() {
    _napTimer?.cancel();
    _wakeTimer?.cancel();
    setState(() => _sleeping = true);
    _wakeTimer = Timer(const Duration(seconds: 7), () {
      if (!mounted) return;
      setState(() => _sleeping = false);
      _scheduleNap();
    });
  }

  void _wakeAndPet() {
    HapticFeedback.lightImpact();
    _wakeTimer?.cancel();
    setState(() {
      _sleeping = false;
      _reaction = (_reaction + 1) % 3;
    });
    _pet.forward(from: 0);
    _scheduleNap();
    widget.onPet?.call();
  }

  @override
  void initState() {
    super.initState();
    _idle = AnimationController(
      vsync: this,
      duration: Duration(
        milliseconds: widget.cat == CatKind.maru ? 3300 : 2900,
      ),
    )..repeat();
    _pet = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    );
    _scheduleNap();
  }

  @override
  void didUpdateWidget(CatActor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.action != widget.action ||
        oldWidget.active != widget.active) {
      if (widget.active || widget.action != CatAction.idle) {
        _napTimer?.cancel();
        _wakeTimer?.cancel();
        _sleeping = false;
      } else {
        _scheduleNap();
      }
    }
  }

  @override
  void dispose() {
    _napTimer?.cancel();
    _wakeTimer?.cancel();
    _idle.dispose();
    _pet.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.cat == CatKind.maru ? 'Maru' : 'Lady';
    return Transform.translate(
      offset: widget.movable ? _offset : Offset.zero,
      child: Semantics(
        button: true,
        label: _sleeping
            ? '$name está durmiendo. Tócalo para despertarlo'
            : 'Acariciar a $name${widget.movable ? ', mantener pulsado para mover, tocar dos veces para dormir' : ''}',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _wakeAndPet,
          onDoubleTap: widget.movable
              ? () {
                  if (_sleeping) {
                    _wakeTimer?.cancel();
                    setState(() => _sleeping = false);
                    _scheduleNap();
                  } else {
                    _goToSleep();
                  }
                }
              : null,
          onLongPressStart: widget.movable
              ? (_) {
                  HapticFeedback.selectionClick();
                  _dragOrigin = _offset;
                  _wakeTimer?.cancel();
                  setState(() => _sleeping = false);
                  _scheduleNap();
                }
              : null,
          onLongPressMoveUpdate: widget.movable
              ? (details) {
                  final limit = widget.size * .18;
                  setState(() {
                    _offset = Offset(
                      (_dragOrigin.dx + details.offsetFromOrigin.dx).clamp(
                        -limit,
                        limit,
                      ),
                      (_dragOrigin.dy + details.offsetFromOrigin.dy).clamp(
                        -limit,
                        limit,
                      ),
                    );
                  });
                }
              : null,
          onLongPressEnd: widget.movable ? (_) => _scheduleNap() : null,
          child: AnimatedBuilder(
            animation: Listenable.merge([_idle, _pet]),
            builder: (context, _) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: widget.size,
                  height: widget.size,
                  child: CustomPaint(
                    painter: _CatPainter(
                      cat: widget.cat,
                      action: widget.action,
                      active: widget.active,
                      phase: _idle.value,
                      pet: _pet.value,
                      focus: widget.focus,
                      sleeping: _sleeping,
                      reaction: _reaction,
                      feeding: widget.feeding,
                      munching: widget.munching,
                      digging: widget.digging,
                      crying: widget.crying,
                      packProgress: widget.packProgress,
                      showShadow: widget.showShadow,
                    ),
                  ),
                ),
                if (widget.showLabel)
                  Text(
                    name,
                    style: TextStyle(
                      fontSize: widget.size < 70 ? 10 : 12,
                      fontWeight: FontWeight.w800,
                      color: widget.cat == CatKind.maru
                          ? const Color(0xff5b493b)
                          : const Color(0xffa45663),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Shared anatomy for games: preserves Maru's stripes and Lady's patches.
abstract class CatPainter extends CustomPainter {
  final double phase, blink, joy;
  const CatPainter({this.phase = 0, this.blink = 0, this.joy = 0});
  CatKind get kind;
  @override
  void paint(Canvas canvas, Size size) => _CatPainter(
    cat: kind,
    action: CatAction.blocks,
    active: true,
    phase: phase,
    pet: joy,
    focus: 0,
    sleeping: false,
    reaction: 1,
    feeding: false,
    munching: false,
    digging: false,
    crying: false,
    packProgress: 0,
    showShadow: false,
    forcedBlink: blink > .35,
  ).paint(canvas, size);
  @override
  bool shouldRepaint(covariant CatPainter old) =>
      old.kind != kind ||
      old.phase != phase ||
      old.blink != blink ||
      old.joy != joy;
}

class MaruPainter extends CatPainter {
  const MaruPainter({super.phase, super.blink, super.joy});
  @override
  CatKind get kind => CatKind.maru;
}

class LadyPainter extends CatPainter {
  const LadyPainter({super.phase, super.blink, super.joy});
  @override
  CatKind get kind => CatKind.lady;
}

class _CatPainter extends CustomPainter {
  final CatKind cat;
  final CatAction action;
  final bool active;
  final double phase, pet, focus;
  final bool sleeping;
  final int reaction;
  final bool feeding;
  final bool munching;
  final bool digging;
  final bool crying;
  final double packProgress;
  final bool showShadow;
  final bool forcedBlink;
  const _CatPainter({
    required this.cat,
    required this.action,
    required this.active,
    required this.phase,
    required this.pet,
    required this.focus,
    required this.sleeping,
    required this.reaction,
    required this.feeding,
    required this.munching,
    required this.digging,
    required this.crying,
    required this.packProgress,
    required this.showShadow,
    this.forcedBlink = false,
  });

  bool get maru => cat == CatKind.maru;
  Color get fur => maru ? const Color(0xff484441) : const Color(0xfffffdf7);
  Color get dark => maru ? const Color(0xff292827) : const Color(0xff444248);
  Color get chest => maru ? const Color(0xffa39687) : const Color(0xffffffff);
  Color get amber => maru ? const Color(0xfff4bb42) : const Color(0xffe1b458);
  Color get caramel => const Color(0xffc89875);

  void ellipse(
    Canvas c,
    double x,
    double y,
    double rx,
    double ry,
    Color color,
  ) => c.drawOval(
    Rect.fromCenter(center: Offset(x, y), width: rx * 2, height: ry * 2),
    Paint()..color = color,
  );

  void path(
    Canvas c,
    Path path,
    Color color, {
    PaintingStyle style = PaintingStyle.fill,
    double width = 1,
  }) => c.drawPath(
    path,
    Paint()
      ..color = color
      ..style = style
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round,
  );

  void line(
    Canvas c,
    double x1,
    double y1,
    double x2,
    double y2,
    Color color,
    double width,
  ) => c.drawLine(
    Offset(x1, y1),
    Offset(x2, y2),
    Paint()
      ..color = color
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round,
  );

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 100, size.height / 100);
    final wave = math.sin(phase * math.pi * 2);
    final breathe = math.sin(phase * math.pi * 2) * (sleeping ? 1.8 : 1.2);
    final pulse = active ? (math.sin(phase * math.pi * 4) + 1) * .5 : 0.0;
    final packSwipe =
        action == CatAction.pack && packProgress > .2 && packProgress < .76
        ? math.sin((packProgress - .2) * math.pi * 10).abs() * .8
        : 0.0;
    final dig = digging ? (math.sin(phase * math.pi * 8) + 1) * .42 : 0.0;
    final reach = feeding || munching
        ? .18 + .08 * math.sin(phase * math.pi * 8)
        : sleeping
        ? 0.0
        : (active ? .55 + pulse * .45 : 0.0) +
              math.sin(pet * math.pi) * .8 +
              packSwipe +
              dig;
    final blink =
        sleeping ||
        forcedBlink ||
        (munching && math.sin(phase * math.pi * 8) > .65) ||
        (phase > .93 && phase < .965);
    final gaze = focus.clamp(-1.0, 1.0);

    if (showShadow) {
      ellipse(canvas, 50, 95, 34, 3, const Color(0x33413039));
      ellipse(canvas, 37, 94, 11, 1.5, const Color(0x33413039));
    }

    // Tail pivots behind the body, so wagging does not slide its markings.
    canvas.save();
    canvas.translate(maru ? 28 : 72, 74);
    canvas.rotate(wave * (sleeping ? .06 : .30) + (active ? .13 : 0));
    final tail = Path()
      ..moveTo(0, 7)
      ..cubicTo(maru ? -19 : 19, 1, maru ? -32 : 32, -11, maru ? -25 : 25, -28)
      ..cubicTo(
        maru ? -19 : 19,
        -38,
        maru ? -15 : 15,
        -26,
        maru ? -16 : 16,
        -19,
      )
      ..cubicTo(maru ? -16 : 16, -7, maru ? -7 : 7, 1, 4, 7)
      ..close();
    path(canvas, tail, maru ? dark : const Color(0xffddd6cc));
    if (maru) {
      for (final y in [-24.0, -16.0, -8.0]) {
        line(canvas, -23, y, -16, y + 2, const Color(0xff6c625c), 2.5);
      }
    } else {
      ellipse(canvas, 22, -23, 4, 5, caramel);
      ellipse(canvas, 15, -9, 4, 5, dark);
    }
    canvas.restore();

    canvas.save();
    // Breathing expands the torso around the planted foot instead of lifting it.
    canvas.translate(50, 94);
    canvas.scale(1 + breathe * .0015, 1 + breathe * .006);
    canvas.translate(-50, -94);
    ellipse(
      canvas,
      50,
      sleeping ? 76 : 70,
      sleeping ? 32 : 28,
      sleeping ? 20 : 27,
      fur,
    );
    if (maru) {
      ellipse(canvas, 50, 75, 16, 20, const Color(0xff776e66));
      for (final y in [58.0, 69.0, 80.0]) {
        line(canvas, 25, y, 34, y + 3, dark, 3);
        line(canvas, 75, y, 66, y + 3, dark, 3);
      }
    } else {
      final p1 = Path()
        ..moveTo(62, 51)
        ..quadraticBezierTo(85, 59, 76, 78)
        ..quadraticBezierTo(63, 77, 61, 65)
        ..close();
      final p2 = Path()
        ..moveTo(24, 73)
        ..quadraticBezierTo(32, 76, 33, 87)
        ..lineTo(25, 88)
        ..close();
      path(canvas, p1, dark);
      path(canvas, p2, caramel);
      ellipse(canvas, 49, 76, 15, 19, chest);
    }

    // One foreleg reaches toward the current activity.
    ellipse(canvas, 37, 86, 12, 8, maru ? dark : fur);
    canvas.save();
    canvas.translate(-reach * 9, -reach * 12);
    canvas.rotate(-reach * .15);
    ellipse(canvas, 66, 86, 12, 8, maru ? dark : fur);
    if (reach > .3) {
      for (final x in [61.0, 66.0, 71.0]) {
        ellipse(
          canvas,
          x,
          83,
          1.1,
          1.2,
          maru ? const Color(0xff908078) : const Color(0xffe7bac4),
        );
      }
    }
    canvas.restore();

    // Independent head tilt follows a target or a petting tap.
    canvas.save();
    if (sleeping) canvas.translate(0, 8);
    if (munching) canvas.translate(0, 10 + math.sin(phase * math.pi * 8) * 2);
    canvas.translate(50, sleeping ? 51 : 45);
    canvas.rotate(
      gaze * .08 + math.sin(pet * math.pi) * .13 + (active ? wave * .035 : 0),
    );
    canvas.translate(-50, sleeping ? -51 : -45);
    final leftEar = Path()
      ..moveTo(26, 37)
      ..lineTo(30, 9)
      ..quadraticBezierTo(39, 16, 45, 31)
      ..close();
    final rightEar = Path()
      ..moveTo(55, 31)
      ..quadraticBezierTo(64, 16, 72, 9)
      ..lineTo(76, 37)
      ..close();
    path(canvas, leftEar, maru ? dark : const Color(0xff49474b));
    path(canvas, rightEar, maru ? dark : const Color(0xffded4cb));
    path(
      canvas,
      Path()
        ..moveTo(31, 31)
        ..lineTo(33, 17)
        ..lineTo(41, 30)
        ..close(),
      maru ? caramel : const Color(0xffeeb7c4),
    );
    path(
      canvas,
      Path()
        ..moveTo(59, 30)
        ..lineTo(69, 17)
        ..lineTo(71, 31)
        ..close(),
      maru ? caramel : const Color(0xffeeb7c4),
    );
    if (maru) {
      line(canvas, 30, 10, 29, 5, dark, 2);
      line(canvas, 71, 10, 72, 5, dark, 2);
    }
    ellipse(canvas, 50, 43, 29, 23, fur);
    ellipse(canvas, 25, 51, 9, 9, maru ? const Color(0xff706861) : fur);
    ellipse(canvas, 75, 51, 9, 9, maru ? const Color(0xff706861) : fur);
    if (maru) {
      final m = Path()
        ..moveTo(36, 25)
        ..lineTo(42, 35)
        ..lineTo(49, 26)
        ..lineTo(56, 35)
        ..lineTo(63, 25);
      path(canvas, m, dark, style: PaintingStyle.stroke, width: 3);
      line(canvas, 27, 42, 34, 45, dark, 2.4);
      line(canvas, 73, 42, 66, 45, dark, 2.4);
      ellipse(canvas, 50, 52, 18, 11, const Color(0xffafa397));
    } else {
      final patch1 = Path()
        ..moveTo(25, 31)
        ..quadraticBezierTo(38, 19, 49, 27)
        ..quadraticBezierTo(45, 37, 39, 42)
        ..lineTo(28, 44)
        ..close();
      final patch2 = Path()
        ..moveTo(51, 26)
        ..quadraticBezierTo(64, 18, 71, 29)
        ..lineTo(68, 40)
        ..quadraticBezierTo(58, 38, 51, 26)
        ..close();
      path(canvas, patch1, dark);
      path(canvas, patch2, caramel);
      ellipse(canvas, 50, 52, 17, 11, const Color(0xffffffff));
    }
    for (final x in [38.0, 62.0]) {
      if (sleeping) {
        final lid = Path()
          ..moveTo(x - 7, 43)
          ..quadraticBezierTo(x, 49, x + 7, 43);
        path(canvas, lid, dark, style: PaintingStyle.stroke, width: 2.4);
      } else {
        ellipse(canvas, x, 43, 8.5, blink ? .8 : 9, const Color(0xff282326));
      }
      if (!blink && !sleeping) {
        ellipse(canvas, x, 43, 7, 8, amber);
        ellipse(
          canvas,
          x + gaze * 2,
          crying ? 45 : 43,
          2.3,
          crying ? 5 : 7,
          const Color(0xff211b17),
        );
        ellipse(canvas, x - 2, 39, 2, 2, Colors.white);
      }
      if (crying && !sleeping) {
        final brow = Path()
          ..moveTo(x - 7, 32 + (x < 50 ? 3 : 0))
          ..quadraticBezierTo(x, 28, x + 7, 32 + (x > 50 ? 3 : 0));
        path(canvas, brow, dark, style: PaintingStyle.stroke, width: 2.3);
        final fall = (phase * 2 + (x > 50 ? .45 : 0)) % 1;
        final tearY = 52 + fall * 22;
        final tear = Path()
          ..moveTo(x, tearY - 5)
          ..quadraticBezierTo(x - 5, tearY + 2, x, tearY + 6)
          ..quadraticBezierTo(x + 5, tearY + 2, x, tearY - 5)
          ..close();
        path(canvas, tear, const Color(0xff5bc8ff).withValues(alpha: .85));
      }
    }
    ellipse(
      canvas,
      50,
      53,
      5,
      3,
      maru ? const Color(0xff7e5b55) : const Color(0xffeaa6b3),
    );
    line(canvas, 50, 56, 50, 60, maru ? dark : const Color(0xff8b8588), 1.5);
    if (crying && !sleeping) {
      final sadMouth = Path()
        ..moveTo(42, 65)
        ..quadraticBezierTo(50, 57, 58, 65);
      path(
        canvas,
        sadMouth,
        maru ? dark : const Color(0xff8b8588),
        style: PaintingStyle.stroke,
        width: 2,
      );
    } else {
      line(canvas, 50, 60, 45, 62, maru ? dark : const Color(0xff8b8588), 1.3);
      line(canvas, 50, 60, 55, 62, maru ? dark : const Color(0xff8b8588), 1.3);
    }
    if ((feeding || munching) && !sleeping) {
      final lick = (math.sin(phase * math.pi * 8) + 1) / 2;
      ellipse(
        canvas,
        50,
        63 + lick * 2,
        2.2,
        3 + lick * 2,
        const Color(0xffed8ca3),
      );
    }
    for (final dy in [-3.0, 1.0, 5.0]) {
      line(
        canvas,
        36,
        55 + dy,
        13,
        51 + dy * 1.2,
        maru ? const Color(0xffe8ded3) : const Color(0xffb5abb1),
        1,
      );
      line(
        canvas,
        64,
        55 + dy,
        87,
        51 + dy * 1.2,
        maru ? const Color(0xffe8ded3) : const Color(0xffb5abb1),
        1,
      );
    }
    canvas.restore();
    canvas.restore();

    if (feeding && !sleeping) {
      // The treat tip meets the mouth; a paw holds the diagonal packet.
      final sway = math.sin(phase * math.pi * 8) * .5;
      canvas.save();
      canvas.translate(50, 63);
      canvas.rotate(maru ? -.24 : .24);
      canvas.translate(-50, -63);
      final tube = Path()
        ..moveTo(48, 65 + sway)
        ..lineTo(52, 65 + sway)
        ..lineTo(54, 84 + sway)
        ..lineTo(46, 84 + sway)
        ..close();
      path(canvas, tube, const Color(0xffff82aa));
      line(canvas, 48, 69 + sway, 52, 69 + sway, const Color(0xffb84d75), 1.3);
      ellipse(canvas, 50, 64 + sway, 1.6, 1, const Color(0xffead8a7));
      line(canvas, 48, 76 + sway, 52, 76 + sway, Colors.white, 1.5);
      ellipse(canvas, 46, 79, 4, 5, maru ? dark : const Color(0xfffffdf5));
      canvas.restore();
    }

    if (sleeping) {
      final drift = math.sin(phase * math.pi * 2) * 2;
      for (final i in [0, 1, 2]) {
        final x = 74.0 + i * 7;
        final y = 21.0 - i * 8 + drift;
        final span = 5.0 + i * 2;
        line(canvas, x, y, x + span, y, const Color(0xff8b83ba), 2.2);
        line(canvas, x + span, y, x, y + span, const Color(0xff8b83ba), 2.2);
        line(
          canvas,
          x,
          y + span,
          x + span,
          y + span,
          const Color(0xff8b83ba),
          2.2,
        );
      }
    }
    if (pet > 0 && pet < 1) {
      final rise = Curves.easeOut.transform(pet);
      if (reaction == 1) {
        final heart = Path()
          ..moveTo(73, 21 - rise * 13)
          ..cubicTo(62, 13 - rise * 13, 67, 5 - rise * 13, 74, 11 - rise * 13)
          ..cubicTo(82, 5 - rise * 13, 87, 13 - rise * 13, 73, 21 - rise * 13);
        path(canvas, heart, const Color(0xffff6f9c).withValues(alpha: 1 - pet));
      } else if (reaction == 2) {
        for (final i in [0, 1, 2]) {
          final x = 72.0 + i * 6;
          final y = 24.0 - rise * 12 - i * 5;
          ellipse(
            canvas,
            x,
            y,
            2.1,
            2.1,
            const Color(0xffffd16b).withValues(alpha: 1 - pet),
          );
        }
      } else {
        for (final side in [-1.0, 1.0]) {
          final x = 50 + side * 31;
          line(
            canvas,
            x,
            49 - rise * 3,
            x + side * 7,
            44 - rise * 4,
            const Color(0xffda8ba0).withValues(alpha: 1 - pet),
            2.2,
          );
        }
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _CatPainter old) =>
      old.phase != phase ||
      old.pet != pet ||
      old.sleeping != sleeping ||
      old.reaction != reaction ||
      old.active != active ||
      old.focus != focus ||
      old.action != action ||
      old.feeding != feeding ||
      old.munching != munching ||
      old.digging != digging ||
      old.crying != crying ||
      old.packProgress != packProgress ||
      old.showShadow != showShadow ||
      old.cat != cat;
}
