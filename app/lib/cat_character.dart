import 'dart:math' as math;
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'game_audio.dart';
import 'cat_care.dart';
import 'cat_clothing.dart';
export 'cat_care.dart';

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
  final double? mealProgress;
  final bool digging;
  final bool crying;
  final double packProgress;
  final VoidCallback? onPet;
  final CatOutfit? outfit;
  final double? cleanliness;
  final bool? sleeping;

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
    this.mealProgress,
    this.digging = false,
    this.crying = false,
    this.packProgress = 0,
    this.onPet,
    this.outfit,
    this.cleanliness,
    this.sleeping,
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
    if (widget.action != CatAction.idle ||
        widget.active ||
        widget.sleeping == true) {
      return;
    }
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
    GameAudio.instance.play(GameSfx.kitten);
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
    final resting =
        widget.sleeping ??
        CatCareScope.maybeOf(context)?.resting(widget.cat) ??
        false;
    return Transform.translate(
      offset: widget.movable ? _offset : Offset.zero,
      child: Semantics(
        button: true,
        label: resting
            ? '$name descansa con la luz apagada'
            : _sleeping
            ? '$name está durmiendo. Tócalo para despertarlo'
            : 'Acariciar a $name${widget.movable ? ', mantener pulsado para mover, tocar dos veces para dormir' : ''}',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: resting ? null : _wakeAndPet,
          onDoubleTap: widget.movable && !resting
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
          onLongPressStart: widget.movable && !resting
              ? (_) {
                  HapticFeedback.selectionClick();
                  _dragOrigin = _offset;
                  _wakeTimer?.cancel();
                  setState(() => _sleeping = false);
                  _scheduleNap();
                }
              : null,
          onLongPressMoveUpdate: widget.movable && !resting
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
                      outfit:
                          widget.outfit ??
                          CatCareScope.outfitOf(context, widget.cat),
                      cleanliness:
                          widget.cleanliness ??
                          CatCareScope.cleanlinessOf(context, widget.cat),
                      action: widget.action,
                      active: widget.active,
                      phase: widget.mealProgress ?? _idle.value,
                      pet: _pet.value,
                      focus: widget.focus,
                      sleeping: resting || _sleeping,
                      reaction: _reaction,
                      feeding: widget.feeding,
                      munching: widget.munching,
                      mealProgress: widget.mealProgress,
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
  final CatOutfit outfit;
  final double cleanliness;
  const CatPainter({
    this.phase = 0,
    this.blink = 0,
    this.joy = 0,
    this.outfit = const CatOutfit(),
    this.cleanliness = 100,
  });
  CatKind get kind;
  @override
  void paint(Canvas canvas, Size size) => _CatPainter(
    cat: kind,
    outfit: outfit,
    cleanliness: cleanliness,
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
      old.outfit != outfit ||
      old.cleanliness != cleanliness ||
      old.phase != phase ||
      old.blink != blink ||
      old.joy != joy;
}

class MaruPainter extends CatPainter {
  const MaruPainter({
    super.phase,
    super.blink,
    super.joy,
    super.outfit,
    super.cleanliness,
  });
  @override
  CatKind get kind => CatKind.maru;
}

class LadyPainter extends CatPainter {
  const LadyPainter({
    super.phase,
    super.blink,
    super.joy,
    super.outfit,
    super.cleanliness,
  });
  @override
  CatKind get kind => CatKind.lady;
}

/// The opening scene draws the working foreleg at the wrapper's actual grip.
class PackOpeningCatPainter extends CustomPainter {
  final CatKind cat;
  final double progress;
  final CatOutfit outfit;
  final double cleanliness;
  const PackOpeningCatPainter({
    required this.cat,
    required this.progress,
    this.outfit = const CatOutfit(),
    this.cleanliness = 100,
  });

  @override
  void paint(Canvas canvas, Size size) => _CatPainter(
    cat: cat,
    outfit: outfit,
    cleanliness: cleanliness,
    action: CatAction.pack,
    active: false,
    phase: (progress * 2) % 1,
    pet: ((progress - .76) / .24).clamp(0.0, 1.0),
    focus: 1,
    sleeping: false,
    reaction: 1,
    feeding: false,
    munching: false,
    digging: false,
    crying: false,
    packProgress: 0,
    showShadow: false,
    forcedBlink: progress > .45 && progress < .52,
    hideWorkingPaw: true,
  ).paint(canvas, size);

  @override
  bool shouldRepaint(PackOpeningCatPainter old) =>
      old.cat != cat ||
      old.progress != progress ||
      old.outfit != outfit ||
      old.cleanliness != cleanliness;
}

class _CatPainter extends CustomPainter {
  final CatKind cat;
  final CatOutfit outfit;
  final double cleanliness;
  final CatAction action;
  final bool active;
  final double phase, pet, focus;
  final bool sleeping;
  final int reaction;
  final bool feeding;
  final bool munching;
  final double? mealProgress;
  final bool digging;
  final bool crying;
  final double packProgress;
  final bool showShadow;
  final bool forcedBlink;
  final bool hideWorkingPaw;
  const _CatPainter({
    required this.cat,
    this.outfit = const CatOutfit(),
    this.cleanliness = 100,
    required this.action,
    required this.active,
    required this.phase,
    required this.pet,
    required this.focus,
    required this.sleeping,
    required this.reaction,
    required this.feeding,
    required this.munching,
    this.mealProgress,
    required this.digging,
    required this.crying,
    required this.packProgress,
    required this.showShadow,
    this.forcedBlink = false,
    this.hideWorkingPaw = false,
  });

  bool get maru => cat == CatKind.maru;
  Color get fur => maru ? const Color(0xff797565) : const Color(0xfffbf7ee);
  Color get dark => maru ? const Color(0xff2b302b) : const Color(0xff5e5148);
  Color get chest => maru ? const Color(0xffd2c3a5) : const Color(0xfffffdf8);
  Color get amber => maru ? const Color(0xffc8ce7d) : const Color(0xffc6a05c);
  Color get caramel => const Color(0xffe4bc86);
  Color get ladyPink => const Color(0xffe5a0a8);
  Color get ladyMask => const Color(0xff4b4745);

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

  void ladyPawDetails(Canvas c, double x, {bool pads = false}) {
    // White fur surrounds the pink skin; the sole shows when the paw turns up.
    if (pads) {
      final pad = Path()
        ..moveTo(x - 4.5, 87)
        ..quadraticBezierTo(x - 5, 83, x - 1.5, 84)
        ..quadraticBezierTo(x, 81.5, x + 1.5, 84)
        ..quadraticBezierTo(x + 5, 83, x + 4.5, 87)
        ..quadraticBezierTo(x, 91, x - 4.5, 87)
        ..close();
      path(c, pad, ladyPink);
      for (final dx in [-6.0, -2.0, 2.0, 6.0]) {
        ellipse(
          c,
          x + dx,
          dx.abs() > 4 ? 82.5 : 81,
          1.4,
          1.8,
          const Color(0xffedb4bb),
        );
      }
    } else {
      for (final dx in [-4.0, 1.0, 6.0]) {
        line(c, x + dx, 89, x + dx - .5, 91, const Color(0xffcfbfb1), .65);
      }
    }
  }

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
        : action == CatAction.collection && active
        ? math.sin(packProgress * math.pi).clamp(0.0, 1.0) * .9 +
              math.sin(pet * math.pi) * .8
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
    path(canvas, tail, maru ? fur : caramel);
    if (maru) {
      canvas.save();
      canvas.clipPath(tail);
      for (final y in [-31.0, -22.0, -13.0, -4.0]) {
        line(canvas, -30, y, -11, y + 4, dark, 4);
      }
      canvas.restore();
    } else {
      canvas.save();
      canvas.clipPath(tail);
      for (final y in [-30.0, -16.0, -2.0]) {
        line(canvas, 7, y, 29, y + 5, dark.withValues(alpha: .85), 7);
      }
      line(canvas, 16, -22, 19, -26, const Color(0xfff3dbb8), 1.3);
      canvas.restore();
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
      canvas.save();
      canvas.clipPath(
        Path()..addOval(
          Rect.fromCenter(
            center: Offset(50, sleeping ? 76 : 70),
            width: sleeping ? 64 : 56,
            height: sleeping ? 40 : 54,
          ),
        ),
      );
      ellipse(canvas, 50, 77, 16, 19, const Color(0xffb5a88b));
      for (final y in [57.0, 66.0, 75.0, 84.0]) {
        for (final side in [-1.0, 1.0]) {
          path(
            canvas,
            Path()
              ..moveTo(50 + side * 29, y - 2)
              ..quadraticBezierTo(50 + side * 21, y - 2, 50 + side * 14, y + 4)
              ..quadraticBezierTo(50 + side * 24, y + 3, 50 + side * 29, y + 3)
              ..close(),
            dark,
          );
        }
      }
      for (final y in [73.0, 82.0, 90.0]) {
        path(
          canvas,
          Path()
            ..moveTo(42, y - 2)
            ..quadraticBezierTo(50, y + 4, 58, y - 2),
          dark.withValues(alpha: .6),
          style: PaintingStyle.stroke,
          width: 1.5,
        );
      }
      canvas.restore();
      path(
        canvas,
        Path()
          ..moveTo(33, 56)
          ..quadraticBezierTo(50, 49, 67, 56)
          ..lineTo(64, 63)
          ..lineTo(60, 60)
          ..lineTo(57, 68)
          ..lineTo(53, 64)
          ..lineTo(49, 70)
          ..lineTo(46, 64)
          ..lineTo(42, 68)
          ..lineTo(39, 61)
          ..lineTo(35, 64)
          ..close(),
        chest,
      );
    } else {
      canvas.save();
      canvas.clipPath(
        Path()..addOval(
          Rect.fromCenter(
            center: Offset(50, sleeping ? 76 : 70),
            width: sleeping ? 64 : 56,
            height: sleeping ? 40 : 54,
          ),
        ),
      );
      final p1 = Path()
        ..moveTo(65, 52)
        ..cubicTo(79, 53, 86, 63, 78, 77)
        ..quadraticBezierTo(69, 84, 64, 72)
        ..quadraticBezierTo(60, 63, 65, 52)
        ..close();
      final p2 = Path()
        ..moveTo(23, 58)
        ..cubicTo(37, 55, 39, 67, 32, 75)
        ..quadraticBezierTo(22, 82, 20, 69)
        ..close();
      path(canvas, p1, dark);
      path(canvas, p2, dark.withValues(alpha: .9));
      path(
        canvas,
        Path()
          ..moveTo(22, 78)
          ..quadraticBezierTo(35, 74, 35, 85)
          ..quadraticBezierTo(31, 96, 23, 88)
          ..close(),
        caramel,
      );
      path(
        canvas,
        Path()
          ..moveTo(72, 77)
          ..quadraticBezierTo(80, 80, 75, 92)
          ..quadraticBezierTo(67, 90, 67, 83)
          ..close(),
        caramel.withValues(alpha: .75),
      );
      ellipse(canvas, 49, 76, 17, 20, chest);
      canvas.restore();
      path(
        canvas,
        Path()
          ..moveTo(34, 55)
          ..quadraticBezierTo(50, 50, 66, 55)
          ..lineTo(63, 63)
          ..lineTo(60, 61)
          ..lineTo(56, 68)
          ..lineTo(53, 65)
          ..lineTo(49, 70)
          ..lineTo(46, 65)
          ..lineTo(42, 68)
          ..lineTo(39, 62)
          ..lineTo(36, 65)
          ..close(),
        chest,
      );
    }

    paintCatBodyClothing(canvas, outfit);
    paintCatDirt(canvas, cleanliness);
    // One foreleg reaches toward the current activity.
    ellipse(canvas, 37, 86, 12, 8, maru ? dark : fur);
    if (maru) {
      for (final x in [33.0, 38.0, 43.0]) {
        line(canvas, x, 88, x - .6, 91, fur.withValues(alpha: .7), .9);
      }
    } else {
      ladyPawDetails(canvas, 37, pads: sleeping);
    }
    if (!hideWorkingPaw) {
      canvas.save();
      canvas.translate(-reach * 9, -reach * 12);
      canvas.rotate(-reach * .15);
      ellipse(canvas, 66, 86, 12, 8, maru ? dark : fur);
      if (maru) {
        for (final x in [62.0, 67.0, 72.0]) {
          line(canvas, x, 88, x - .6, 91, fur.withValues(alpha: .7), .9);
        }
      } else {
        ladyPawDetails(canvas, 66, pads: reach > .3 || sleeping);
      }
      if (reach > .3 && maru) {
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
    }

    // Independent head tilt follows a target or a petting tap.
    canvas.save();
    if (sleeping) canvas.translate(0, 8);
    if (mealProgress != null) {
      final t = mealProgress!.clamp(0.0, 1.0);
      final lean =
          Curves.easeInOut.transform((t / .2).clamp(0.0, 1.0)) *
          (1 - Curves.easeInOut.transform(((t - .8) / .2).clamp(0.0, 1.0)));
      final chew = math.sin(t * math.pi * 12);
      canvas.translate(0, lean * (8 + chew * .65));
    } else if (munching) {
      canvas.translate(0, 10 + math.sin(phase * math.pi * 8) * 2);
    }
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
    path(canvas, leftEar, maru ? const Color(0xff8d866d) : fur);
    path(canvas, rightEar, maru ? const Color(0xff8d866d) : fur);
    if (maru) {
      path(
        canvas,
        leftEar,
        dark.withValues(alpha: .7),
        style: PaintingStyle.stroke,
        width: 1,
      );
      path(
        canvas,
        rightEar,
        dark.withValues(alpha: .7),
        style: PaintingStyle.stroke,
        width: 1,
      );
    } else {
      path(
        canvas,
        leftEar,
        const Color(0xffdecbb6),
        style: PaintingStyle.stroke,
        width: .9,
      );
      path(
        canvas,
        rightEar,
        const Color(0xffdecbb6),
        style: PaintingStyle.stroke,
        width: .9,
      );
    }
    path(
      canvas,
      Path()
        ..moveTo(31, 31)
        ..lineTo(32, 14)
        ..lineTo(43, 30)
        ..close(),
      maru ? const Color(0xffc7b48e) : ladyPink,
    );
    path(
      canvas,
      Path()
        ..moveTo(59, 30)
        ..lineTo(70, 14)
        ..lineTo(71, 31)
        ..close(),
      maru ? const Color(0xffc7b48e) : ladyPink,
    );
    if (maru) {
      for (var n = 0; n < 4; n++) {
        line(canvas, 34 + n * 1.5, 29, 32 + n * .8, 18.0 + n, chest, .85);
        line(canvas, 67 - n * 1.5, 29, 70 - n * .8, 18.0 + n, chest, .85);
      }
      line(canvas, 30, 11, 29.4, 8.5, fur, 1);
      line(canvas, 71, 11, 71.8, 8.5, fur, 1);
    } else {
      for (var n = 0; n < 4; n++) {
        line(canvas, 34 + n * 1.4, 29, 32 + n * .8, 18.0 + n, chest, .65);
        line(canvas, 67 - n * 1.4, 29, 70 - n * .8, 18.0 + n, chest, .65);
      }
    }
    ellipse(canvas, 50, 43, 29, 23, fur);
    if (maru) {
      for (final side in [-1.0, 1.0]) {
        path(
          canvas,
          Path()
            ..moveTo(50 + side * 25, 43)
            ..lineTo(50 + side * 33, 47)
            ..lineTo(50 + side * 29, 48)
            ..lineTo(50 + side * 35, 53)
            ..lineTo(50 + side * 29, 54)
            ..lineTo(50 + side * 31, 58)
            ..lineTo(50 + side * 23, 60)
            ..close(),
          const Color(0xff9b947b),
        );
      }
    }
    ellipse(canvas, 25, 51, 9, 9, maru ? const Color(0xff9b947b) : fur);
    ellipse(canvas, 75, 51, 9, 9, maru ? const Color(0xff9b947b) : fur);
    if (maru) {
      // Tapered tabby markings follow the forehead and cheek contours.
      for (final side in [-1.0, 1.0]) {
        path(
          canvas,
          Path()
            ..moveTo(50 + side * 13, 23)
            ..quadraticBezierTo(50 + side * 15, 26, 50 + side * 8, 36)
            ..lineTo(50 + side * 3, 29)
            ..lineTo(50, 33)
            ..lineTo(50 + side * 2, 24)
            ..lineTo(50 + side * 8, 30)
            ..close(),
          dark,
        );
        for (var n = 0; n < 3; n++) {
          final y = 43.0 + n * 5;
          path(
            canvas,
            Path()
              ..moveTo(50 + side * 29, y - 3)
              ..quadraticBezierTo(50 + side * 24, y, 50 + side * 17, y + 1)
              ..quadraticBezierTo(50 + side * 23, y + 4, 50 + side * 28, y)
              ..close(),
            dark,
          );
        }
        path(
          canvas,
          Path()
            ..moveTo(50 + side * 5, 44)
            ..quadraticBezierTo(50 + side * 7, 50, 50 + side * 10, 52),
          dark,
          style: PaintingStyle.stroke,
          width: 1.8,
        );
      }
      path(
        canvas,
        Path()
          ..moveTo(46, 35)
          ..quadraticBezierTo(50, 32, 54, 35)
          ..lineTo(57, 52)
          ..quadraticBezierTo(50, 57, 43, 52)
          ..close(),
        const Color(0xffb99c6c),
      );
      ellipse(canvas, 50, 59, 10, 5, const Color(0xffece2c8));
      ellipse(canvas, 43, 54, 11, 8, chest);
      ellipse(canvas, 57, 54, 11, 8, chest);
      for (final x in [38.0, 62.0]) {
        ellipse(
          canvas,
          x,
          43,
          10,
          sleeping ? 5 : 10.5,
          const Color(0xffcbbb95),
        );
      }
      for (final side in [-1.0, 1.0]) {
        for (var n = 0; n < 3; n++) {
          ellipse(
            canvas,
            50 + side * (9 + n % 2 * 3),
            53 + n * 2,
            .6,
            .6,
            dark,
          );
        }
      }
    } else {
      // Lady's cream crown surrounds a dark mask on both eyes, split by a white blaze.
      canvas.save();
      canvas.clipPath(Path()..addOval(const Rect.fromLTWH(21, 20, 58, 46)));
      path(
        canvas,
        Path()
          ..moveTo(22, 35)
          ..quadraticBezierTo(24, 17, 48, 20)
          ..quadraticBezierTo(73, 16, 79, 35)
          ..lineTo(73, 44)
          ..quadraticBezierTo(64, 42, 61, 36)
          ..lineTo(41, 37)
          ..quadraticBezierTo(29, 43, 22, 35)
          ..close(),
        caramel,
      );
      final patch1 = Path()
        ..moveTo(37, 24)
        ..quadraticBezierTo(39, 22, 41, 24)
        ..quadraticBezierTo(44, 22.5, 47, 25)
        ..quadraticBezierTo(48, 33, 45, 37)
        ..quadraticBezierTo(46, 47, 40, 49)
        ..quadraticBezierTo(30, 50, 28, 44)
        ..quadraticBezierTo(30, 33, 37, 24)
        ..close();
      final patch2 = Path()
        ..moveTo(50, 24)
        ..quadraticBezierTo(53, 25, 56, 23)
        ..quadraticBezierTo(65, 24, 70, 37)
        ..quadraticBezierTo(73, 46, 63, 50)
        ..quadraticBezierTo(57, 49, 55, 52)
        ..lineTo(52, 49)
        ..quadraticBezierTo(55, 37, 50, 24)
        ..close();
      path(canvas, patch1, ladyMask);
      path(canvas, patch2, ladyMask);
      path(
        canvas,
        Path()
          ..moveTo(44, 25)
          ..quadraticBezierTo(48, 23, 53, 25)
          ..lineTo(54, 38)
          ..lineTo(45, 38)
          ..close(),
        ladyMask,
      );
      path(
        canvas,
        Path()
          ..moveTo(48, 29)
          ..lineTo(46, 34)
          ..lineTo(44, 36)
          ..lineTo(47, 38)
          ..quadraticBezierTo(46, 46, 42, 54)
          ..quadraticBezierTo(50, 59, 57, 54)
          ..quadraticBezierTo(53, 43, 51, 37)
          ..lineTo(50, 33)
          ..close(),
        chest,
      );
      canvas.restore();
      ellipse(canvas, 43, 55, 12, 8, chest);
      ellipse(canvas, 57, 55, 12, 8, chest);
      ellipse(canvas, 50, 60, 10, 4.5, chest);
    }
    paintCatDirt(canvas, cleanliness, head: true);
    for (final x in [38.0, 62.0]) {
      if (sleeping) {
        final lid = Path()
          ..moveTo(x - 7, 43)
          ..quadraticBezierTo(x, 49, x + 7, 43);
        path(
          canvas,
          lid,
          maru ? dark : const Color(0xffb19a87),
          style: PaintingStyle.stroke,
          width: 2.4,
        );
      } else {
        ellipse(canvas, x, 43, 8.5, blink ? .8 : 9, const Color(0xff282326));
      }
      if (!blink && !sleeping) {
        ellipse(canvas, x, 43, 7, 8, amber);
        ellipse(
          canvas,
          x + gaze * 2,
          crying ? 45 : 43,
          maru ? 4.1 : 3.4,
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
    if (maru) {
      path(
        canvas,
        Path()
          ..moveTo(45.4, 51.5)
          ..quadraticBezierTo(50, 50, 54.6, 51.5)
          ..lineTo(50, 56.4)
          ..close(),
        dark,
      );
      path(
        canvas,
        Path()
          ..moveTo(46.6, 51.8)
          ..quadraticBezierTo(50, 50.9, 53.4, 51.8)
          ..lineTo(50, 54.3)
          ..close(),
        const Color(0xffb9764e),
      );
    } else {
      path(
        canvas,
        Path()
          ..moveTo(45.5, 51.4)
          ..quadraticBezierTo(50, 49.8, 54.5, 51.4)
          ..quadraticBezierTo(53, 54.6, 50, 56.5)
          ..quadraticBezierTo(47, 54.6, 45.5, 51.4)
          ..close(),
        ladyPink,
      );
      line(canvas, 47.5, 51.5, 51, 51.2, const Color(0xffffdae0), .75);
    }
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
    if ((feeding || (munching && mealProgress == null)) && !sleeping) {
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
    if (maru) {
      for (final dy in [-4.0, 0.0, 4.0, 7.0]) {
        for (final side in [-1.0, 1.0]) {
          path(
            canvas,
            Path()
              ..moveTo(50 + side * 13, 55 + dy)
              ..quadraticBezierTo(
                50 + side * 25,
                54 + dy,
                50 + side * 41,
                52 + dy * 1.7,
              ),
            const Color(0xfff3ead6),
            style: PaintingStyle.stroke,
            width: .75,
          );
        }
      }
    } else {
      for (final dy in [-3.0, 1.0, 5.0]) {
        for (final side in [-1.0, 1.0]) {
          path(
            canvas,
            Path()
              ..moveTo(50 + side * 13, 55 + dy)
              ..quadraticBezierTo(
                50 + side * 26,
                54 + dy,
                50 + side * 39,
                52 + dy * 1.6,
              ),
            const Color(0xffc5b8a8),
            style: PaintingStyle.stroke,
            width: .7,
          );
        }
      }
    }
    paintCatHeadClothing(canvas, outfit);
    canvas.restore();
    canvas.restore();

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
      old.mealProgress != mealProgress ||
      old.digging != digging ||
      old.crying != crying ||
      old.packProgress != packProgress ||
      old.showShadow != showShadow ||
      old.hideWorkingPaw != hideWorkingPaw ||
      old.cat != cat ||
      old.outfit != outfit ||
      old.cleanliness != cleanliness;
}
