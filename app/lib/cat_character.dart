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
  final double turn;

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
    this.turn = 0,
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
      duration: const Duration(milliseconds: 780),
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
                      turn: widget.turn,
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
  final bool showWorkingPaw;
  final CatOutfit outfit;
  final double cleanliness;
  final double turn;
  const CatPainter({
    this.phase = 0,
    this.blink = 0,
    this.joy = 0,
    this.showWorkingPaw = true,
    this.outfit = const CatOutfit(),
    this.cleanliness = 100,
    this.turn = 0,
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
    hideWorkingPaw: !showWorkingPaw,
    turn: turn,
  ).paint(canvas, size);
  @override
  bool shouldRepaint(covariant CatPainter old) =>
      old.kind != kind ||
      old.outfit != outfit ||
      old.cleanliness != cleanliness ||
      old.phase != phase ||
      old.blink != blink ||
      old.joy != joy ||
      old.showWorkingPaw != showWorkingPaw ||
      old.turn != turn;
}

class MaruPainter extends CatPainter {
  const MaruPainter({
    super.phase,
    super.blink,
    super.joy,
    super.showWorkingPaw,
    super.outfit,
    super.cleanliness,
    super.turn,
  });
  @override
  CatKind get kind => CatKind.maru;
}

class LadyPainter extends CatPainter {
  const LadyPainter({
    super.phase,
    super.blink,
    super.joy,
    super.showWorkingPaw,
    super.outfit,
    super.cleanliness,
    super.turn,
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
  final double turn;
  const PackOpeningCatPainter({
    required this.cat,
    required this.progress,
    this.outfit = const CatOutfit(),
    this.cleanliness = 100,
    this.turn = 0,
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
    turn: turn,
  ).paint(canvas, size);

  @override
  bool shouldRepaint(PackOpeningCatPainter old) =>
      old.cat != cat ||
      old.progress != progress ||
      old.outfit != outfit ||
      old.cleanliness != cleanliness ||
      old.turn != turn;
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
  final double turn;

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
    this.turn = 0,
  });

  bool get maru => cat == CatKind.maru;

  // Authentic palettes grounded in Maru & Lady's real photos.
  Color get fur => maru ? const Color(0xff72695a) : const Color(0xfffdfaf4);
  Color get furLight =>
      maru ? const Color(0xff948873) : const Color(0xffffffff);
  Color get furShade =>
      maru ? const Color(0xff524a3f) : const Color(0xffe7decb);
  Color get furOutline =>
      maru ? const Color(0xff2c2924) : const Color(0xffcabaa6);
  Color get dark => maru ? const Color(0xff232623) : const Color(0xff323032);
  Color get chest => maru ? const Color(0xffe1d4b8) : const Color(0xfffffefb);
  Color get chestBright =>
      maru ? const Color(0xfff5efe2) : const Color(0xffffffff);
  Color get amber => maru ? const Color(0xffd0d978) : const Color(0xffd8ab56);
  Color get amberDeep =>
      maru ? const Color(0xff8fa344) : const Color(0xff9f6d2c);
  Color get caramel => const Color(0xffe2ae76);
  Color get ladyPink => const Color(0xffeb9ca8);
  Color get ladyMask => const Color(0xff323032);

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

  void shadedPath(
    Canvas c,
    Path p,
    Rect bounds, {
    required Color top,
    required Color mid,
    required Color bottom,
    Color? border,
    double borderWidth = 1.0,
  }) {
    c.drawPath(
      p,
      Paint()
        ..shader = LinearGradient(
          begin: const Alignment(-0.35, -0.9),
          end: const Alignment(0.4, 1.0),
          colors: [top, mid, bottom],
          stops: const [0.0, 0.58, 1.0],
        ).createShader(bounds),
    );
    if (border != null && borderWidth > 0) {
      path(c, p, border, style: PaintingStyle.stroke, width: borderWidth);
    }
  }

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

  Path _fluffyTailPath(bool leftSide) {
    final s = leftSide ? -1.0 : 1.0;
    // Plush, bushy plumed tail silhouette (matching Maru's dark brush tail
    // and Lady's fluffy ringed plume tail).
    return Path()
      ..moveTo(0, 8)
      ..cubicTo(s * 10, 6, s * 22, 0, s * 28, -11)
      ..cubicTo(s * 34, -22, s * 31, -35, s * 22, -37)
      ..cubicTo(s * 14, -38, s * 11, -29, s * 12, -20)
      ..cubicTo(s * 12, -10, s * 6, -1, s * 2, 7)
      ..close();
  }

  void _paintTail(
    Canvas canvas, {
    required double wave,
    required bool isBack,
    required double clampedTurn,
  }) {
    canvas.save();
    final tailOnLeft = maru;
    final anchorX = isBack
        ? 50.0 + clampedTurn.sign * 4.0
        : (tailOnLeft ? 28.0 : 72.0) - clampedTurn * 6.0;
    final anchorY = sleeping ? 78.0 : 75.0;
    canvas.translate(anchorX, anchorY);
    final wag =
        wave * (sleeping ? .05 : .26) +
        (active ? .12 : 0) +
        math.sin(pet * math.pi * 2) * .18;
    canvas.rotate(wag);

    final tail = _fluffyTailPath(tailOnLeft);
    if (maru) {
      // Maru's bushy dark charcoal-brown tabby tail.
      shadedPath(
        canvas,
        tail,
        const Rect.fromLTWH(-34, -38, 38, 46),
        top: const Color(0xff5e5548),
        mid: const Color(0xff3e3932),
        bottom: dark,
        border: dark,
        borderWidth: 1.0,
      );
      canvas.save();
      canvas.clipPath(tail);
      // Bushy dark tip and tabby rings.
      ellipse(canvas, -23, -31, 9, 8, dark);
      for (final y in [-24.0, -16.0, -8.0, -1.0]) {
        line(canvas, -32, y, -10, y + 4, dark, 3.8);
      }
      line(canvas, -22, -28, -17, -14, const Color(0x55b0a084), 1.4);
      canvas.restore();
    } else {
      // Lady's real fluffy white plumed tail with warm apricot base and smoky charcoal rings!
      shadedPath(
        canvas,
        tail,
        const Rect.fromLTWH(-4, -38, 38, 46),
        top: Colors.white,
        mid: fur,
        bottom: furShade,
        border: furOutline,
        borderWidth: 1.0,
      );
      canvas.save();
      canvas.clipPath(tail);
      // Warm peach-apricot patch at the tail base (seen in Lady's photos).
      ellipse(canvas, 9, 2, 8, 6.5, caramel);
      // Alternating smoky charcoal-grey rings and fluffy dark-grey tip.
      for (final y in [-33.0, -21.0, -9.0]) {
        line(
          canvas,
          8,
          y,
          33,
          y + 5.5,
          const Color(0xff4a4749).withValues(alpha: .88),
          6.2,
        );
      }
      // Fluffy white highlight along the plume.
      line(canvas, 17, -27, 21, -13, Colors.white.withValues(alpha: .75), 1.8);
      canvas.restore();
    }
    canvas.restore();
  }

  void _paintPaw(
    Canvas c,
    double x,
    double y, {
    required bool showPads,
    double rx = 11.5,
    double ry = 7.6,
  }) {
    // Contact shadow under the paw.
    ellipse(c, x, y + ry * .55, rx * .92, ry * .42, const Color(0x2223191d));

    final pawRect = Rect.fromCenter(
      center: Offset(x, y),
      width: rx * 2,
      height: ry * 2,
    );
    final pawPath = Path()..addOval(pawRect);

    if (maru) {
      // Maru's deep dark charcoal-brown paws with subtle taupe tabby cuffs.
      shadedPath(
        c,
        pawPath,
        pawRect,
        top: const Color(0xff464139),
        mid: dark,
        bottom: const Color(0xff181a18),
        border: const Color(0xff181a18),
        borderWidth: .9,
      );
      if (showPads) {
        // Dark slate-taupe paw pad and 4 toe beans.
        ellipse(c, x, y + 1.2, 4.2, 2.8, const Color(0xff6b5d56));
        for (final dx in [-5.2, -1.8, 1.8, 5.2]) {
          ellipse(
            c,
            x + dx,
            y - (dx.abs() > 3 ? 2.2 : 3.2),
            1.35,
            1.7,
            const Color(0xff84736b),
          );
        }
      } else {
        // Subtle taupe fur division lines between toes.
        for (final dx in [-3.8, 0.0, 3.8]) {
          line(
            c,
            x + dx,
            y + 1.5,
            x + dx - .4,
            y + 5.2,
            const Color(0xff877c68).withValues(alpha: .75),
            1.0,
          );
        }
      }
    } else {
      // Lady's snowy-white paws with delicate pink toe beans.
      shadedPath(
        c,
        pawPath,
        pawRect,
        top: Colors.white,
        mid: fur,
        bottom: furShade,
        border: furOutline,
        borderWidth: .95,
      );
      if (showPads) {
        final pad = Path()
          ..moveTo(x - 4.4, y + 1.2)
          ..quadraticBezierTo(x - 4.8, y - 2.6, x - 1.5, y - 1.6)
          ..quadraticBezierTo(x, y - 4.0, x + 1.5, y - 1.6)
          ..quadraticBezierTo(x + 4.8, y - 2.6, x + 4.4, y + 1.2)
          ..quadraticBezierTo(x, y + 4.8, x - 4.4, y + 1.2)
          ..close();
        path(c, pad, ladyPink);
        for (final dx in [-5.6, -1.9, 1.9, 5.6]) {
          ellipse(
            c,
            x + dx,
            y - (dx.abs() > 3.5 ? 3.2 : 4.6),
            1.45,
            1.85,
            const Color(0xfff3b8c0),
          );
        }
      } else {
        for (final dx in [-3.8, 0.2, 4.2]) {
          line(c, x + dx, y + 1.8, x + dx - .4, y + 5.2, furOutline, .85);
        }
      }
    }
  }

  Path _plushHeadSilhouette() {
    // Continuous feline head with soft, fluffy double-tufted cheek ruffs.
    // Lady has a slightly larger, rounder snowy-white crown & cheek silhouette.
    final topY = maru ? 20.0 : 18.0;
    final crownW = maru ? 15.0 : 17.2;
    final templeX = maru ? 76.0 : 78.2;
    final cheekTopX = maru ? 78.0 : 79.8;
    final botY = maru ? 66.0 : 67.2;
    return Path()
      ..moveTo(50, topY)
      ..cubicTo(50 + crownW, topY, templeX, 27.2, cheekTopX, 41)
      ..lineTo(83.5 + (maru ? 0 : 1.2), 44.5)
      ..lineTo(79.5 + (maru ? 0 : 1.0), 47.2)
      ..lineTo(84.5 + (maru ? 0 : 1.2), 51.5)
      ..quadraticBezierTo(79, 55.5, 81 + (maru ? 0 : .8), 58.5)
      ..cubicTo(74, 64.8, 62, botY, 50, botY)
      ..cubicTo(38, botY, 26, 64.8, 19 - (maru ? 0 : .8), 58.5)
      ..quadraticBezierTo(21, 55.5, 15.5 - (maru ? 0 : 1.2), 51.5)
      ..lineTo(20.5 - (maru ? 0 : 1.0), 47.2)
      ..lineTo(16.5 - (maru ? 0 : 1.2), 44.5)
      ..lineTo(100 - cheekTopX, 41)
      ..cubicTo(100 - templeX, 27.2, 50 - crownW, topY, 50, topY)
      ..close();
  }

  Path _plushTorsoSilhouette(bool sleepingPose) {
    if (sleepingPose) {
      return Path()
        ..addOval(
          Rect.fromCenter(center: const Offset(50, 76), width: 65, height: 40),
        );
    }
    // Pear-shaped seated feline torso with soft shoulders and round haunches.
    return Path()
      ..moveTo(33, 52)
      ..quadraticBezierTo(50, 48, 67, 52)
      ..cubicTo(76, 60, 80, 73, 77, 84)
      ..cubicTo(74, 93, 62, 96, 50, 96)
      ..cubicTo(38, 96, 26, 93, 23, 84)
      ..cubicTo(20, 73, 24, 60, 33, 52)
      ..close();
  }

  Path _fluffyChestMane(double dx) {
    return Path()
      ..moveTo(31 + dx * .4, 55)
      ..quadraticBezierTo(50 + dx * .5, 49, 69 + dx * .4, 55)
      ..lineTo(66 + dx * .5, 63.5)
      ..lineTo(61.5 + dx * .55, 61)
      ..lineTo(58 + dx * .6, 69.5)
      ..lineTo(53.5 + dx * .6, 66)
      ..lineTo(50 + dx * .65, 72.5)
      ..lineTo(46.5 + dx * .6, 66)
      ..lineTo(42 + dx * .6, 69.5)
      ..lineTo(38.5 + dx * .55, 61)
      ..lineTo(34 + dx * .5, 63.5)
      ..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 100, size.height / 100);

    final clampedTurn = turn.clamp(-1.0, 1.0);
    final isBack = clampedTurn.abs() > 0.65;
    final bodyShift = isBack
        ? -clampedTurn.sign * (1.0 - clampedTurn.abs()) * 16.0
        : clampedTurn * 10.0;
    final faceShift = isBack
        ? -clampedTurn.sign * (1.0 - clampedTurn.abs()) * 18.0
        : clampedTurn * 11.5;

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

    // Smooth continuous blink factor (0.0 = open, 1.0 = closed) instead of binary snap.
    final naturalBlinkWave =
        (phase > .91 && phase < .985)
        ? math.sin(((phase - .91) / .075) * math.pi)
        : 0.0;
    final munchSquint = munching
        ? ((math.sin(phase * math.pi * 8) - .35) / .65).clamp(0.0, .85)
        : 0.0;
    final blinkAmount = sleeping || forcedBlink
        ? 1.0
        : math.max(naturalBlinkWave, munchSquint);
    final happySquint =
        !sleeping && !crying && pet > 0.06
        ? math.sin(pet.clamp(0.0, 1.0) * math.pi)
        : 0.0;

    final gaze = (focus + (isBack ? 0 : clampedTurn * .45)).clamp(-1.0, 1.0);

    // Subtle independent ear twitching.
    final leftEarTwitch =
        math.sin(phase * math.pi * 2 + 0.6) * (sleeping ? .012 : .038) +
        math.sin(pet * math.pi * 2) * .06;
    final rightEarTwitch =
        math.cos(phase * math.pi * 2 - 0.4) * (sleeping ? .012 : .042) -
        math.sin(pet * math.pi * 2) * .06;

    if (showShadow) {
      ellipse(canvas, 50, 95, 34, 3.2, const Color(0x33413039));
      ellipse(canvas, 37, 94, 11, 1.6, const Color(0x28413039));
    }

    // If viewing from the front/3-4, the tail is painted behind the torso.
    if (!isBack) {
      _paintTail(
        canvas,
        wave: wave,
        isBack: false,
        clampedTurn: clampedTurn,
      );
    }

    canvas.save();
    // Breathing + happy pet squish/stretch around the planted feet.
    final petSquish = math.sin(pet * math.pi) * .032;
    canvas.translate(50, 94);
    canvas.scale(
      1 + breathe * .0018 + petSquish * .6,
      1 + breathe * .0065 - petSquish,
    );
    canvas.translate(-50, -94);

    final torso = _plushTorsoSilhouette(sleeping);
    final torsoBounds = const Rect.fromLTWH(20, 48, 60, 48);
    shadedPath(
      canvas,
      torso,
      torsoBounds,
      top: furLight,
      mid: fur,
      bottom: furShade,
      border: furOutline,
      borderWidth: 1.1,
    );

    // Body markings (clipped to torso).
    canvas.save();
    canvas.clipPath(torso);
    if (maru) {
      if (isBack) {
        // Maru's real mackerel-tabby back from Photos 4 & 5:
        // Dark dorsal spine stripe, dark shoulder mantle, and curved rib stripes.
        ellipse(canvas, 50, 60, 26, 12, dark.withValues(alpha: .88));
        line(canvas, 50 + bodyShift * .3, 50, 50 + bodyShift * .3, 94, dark, 5);
        for (final y in [58.0, 66.0, 74.0, 82.0, 89.0]) {
          for (final side in [-1.0, 1.0]) {
            path(
              canvas,
              Path()
                ..moveTo(50 + bodyShift * .3, y - 2)
                ..quadraticBezierTo(
                  50 + side * 16,
                  y - 1,
                  50 + side * 29,
                  y + 4,
                )
                ..quadraticBezierTo(
                  50 + side * 16,
                  y + 3,
                  50 + bodyShift * .3,
                  y + 2,
                )
                ..close(),
              dark,
            );
          }
        }
      } else {
        // Maru's front/side view: dark charcoal shoulder cape, warm cream-buff belly cloud,
        // and mackerel stripes wrapping around his sides.
        ellipse(
          canvas,
          50 - bodyShift * .3,
          62,
          29,
          13,
          dark.withValues(alpha: .72),
        );
        // Fluffy cream-buff belly cloud (seen when Maru stretches in Photo 1).
        ellipse(
          canvas,
          50 + bodyShift * .45,
          79,
          16.5,
          18.5,
          const Color(0xffcbbd9e),
        );
        ellipse(
          canvas,
          50 + bodyShift * .5,
          80,
          12.5,
          14.5,
          const Color(0xffdfd3b8),
        );
        for (final y in [58.0, 66.5, 75.0, 83.5]) {
          for (final side in [-1.0, 1.0]) {
            path(
              canvas,
              Path()
                ..moveTo(50 + side * 29, y - 2)
                ..quadraticBezierTo(
                  50 + side * 20 + bodyShift * .3,
                  y - 2,
                  50 + side * 12 + bodyShift * .4,
                  y + 4,
                )
                ..quadraticBezierTo(
                  50 + side * 22 + bodyShift * .3,
                  y + 3,
                  50 + side * 29,
                  y + 3,
                )
                ..close(),
              dark,
            );
          }
        }
        // Tabby necklace arcs across the chest/belly.
        for (final y in [73.0, 81.5, 89.5]) {
          path(
            canvas,
            Path()
              ..moveTo(41 + bodyShift * .4, y - 2)
              ..quadraticBezierTo(
                50 + bodyShift * .5,
                y + 4,
                59 + bodyShift * .4,
                y - 2,
              ),
            dark.withValues(alpha: .58),
            style: PaintingStyle.stroke,
            width: 1.5,
          );
        }
      }
    } else {
      // Lady's real calico body markings from Photos 3, 4, 6 & 7:
      // Pure snowy-white chest/belly, two large rounded dark charcoal-black saddle patches
      // on her back/flank, and a warm apricot-ginger spot between them and near the tail base!
      if (isBack) {
        // Upper dark saddle patch.
        path(
          canvas,
          Path()
            ..moveTo(35 + bodyShift * .3, 56)
            ..cubicTo(48, 52, 64, 55, 62, 67)
            ..cubicTo(59, 74, 38, 72, 34, 65)
            ..close(),
          ladyMask,
        );
        // Small warm apricot-ginger spot between the two black patches (Photo 7!).
        ellipse(canvas, 42 + bodyShift * .3, 73, 6.5, 4.5, caramel);
        // Lower large dark saddle patch on the back/rump.
        path(
          canvas,
          Path()
            ..moveTo(37 + bodyShift * .3, 75)
            ..cubicTo(54, 71, 69, 76, 65, 89)
            ..cubicTo(59, 95, 36, 93, 35, 83)
            ..close(),
          ladyMask,
        );
        // Warm peach-apricot touch near the right hip/tail base.
        ellipse(
          canvas,
          64 + bodyShift * .2,
          89,
          7,
          5,
          caramel.withValues(alpha: .85),
        );
      } else {
        final patchShift = -bodyShift * .55;
        // Right flank dark saddle patch peeking around the side.
        final p1 = Path()
          ..moveTo(64 + patchShift, 53)
          ..cubicTo(79, 54, 85, 64, 78, 77)
          ..quadraticBezierTo(68, 83, 63 + patchShift, 71)
          ..quadraticBezierTo(59 + patchShift, 62, 64 + patchShift, 53)
          ..close();
        // Left flank dark saddle patch peeking around the side.
        final p2 = Path()
          ..moveTo(23 + patchShift, 58)
          ..cubicTo(36 + patchShift, 55, 38 + patchShift, 67, 31 + patchShift, 75)
          ..quadraticBezierTo(21, 81, 19, 68)
          ..close();
        path(canvas, p1, ladyMask);
        path(canvas, p2, ladyMask.withValues(alpha: .92));
        // Warm apricot-ginger accent spots near the lower flank/hip.
        path(
          canvas,
          Path()
            ..moveTo(21 + patchShift, 77)
            ..quadraticBezierTo(33 + patchShift, 74, 34 + patchShift, 84)
            ..quadraticBezierTo(30, 94, 22, 87)
            ..close(),
          caramel.withValues(alpha: .88),
        );
        path(
          canvas,
          Path()
            ..moveTo(72 + patchShift, 77)
            ..quadraticBezierTo(80, 80, 75, 91)
            ..quadraticBezierTo(67, 89, 67 + patchShift, 82)
            ..close(),
          caramel.withValues(alpha: .78),
        );
        // Pure snowy-white breast/belly center.
        ellipse(canvas, 50 + bodyShift * .4, 76, 17.5, 20, chest);
      }
    }
    canvas.restore();

    // Fluffy chest ruff / mane (visible in front & 3/4 views).
    if (!isBack) {
      final mane = _fluffyChestMane(bodyShift);
      path(canvas, mane, chest);
      if (maru) {
        // Inner brighter cream-white chest tuft highlight for Maru's plush mane.
        canvas.save();
        canvas.scale(.78, .78);
        canvas.translate(14, 14);
        path(canvas, mane, chestBright.withValues(alpha: .75));
        canvas.restore();
      }
      path(
        canvas,
        mane,
        (maru ? dark : furOutline).withValues(alpha: .35),
        style: PaintingStyle.stroke,
        width: .85,
      );
    }

    paintCatBodyClothing(canvas, outfit, turn: clampedTurn);
    paintCatDirt(canvas, cleanliness, turn: clampedTurn);

    // Paws: in front/3-4 views, one foreleg reaches toward the current activity;
    // in back view, the haunches rest at the base and the tail wags in front.
    if (!isBack) {
      _paintPaw(
        canvas,
        37 + bodyShift * .25,
        86.5,
        showPads: !maru && sleeping,
      );
      if (!hideWorkingPaw) {
        canvas.save();
        canvas.translate(-reach * 9, -reach * 12);
        canvas.rotate(-reach * .15);
        _paintPaw(
          canvas,
          65 + bodyShift * .25,
          86.5,
          showPads: reach > .3 || (!maru && sleeping),
        );
        canvas.restore();
      }
    } else {
      // Back view: tail wags prominently over the lower back!
      _paintTail(
        canvas,
        wave: wave,
        isBack: true,
        clampedTurn: clampedTurn,
      );
    }

    // Soft cast shadow of the head onto the chest/collar.
    ellipse(
      canvas,
      50 + faceShift * .35,
      sleeping ? 67 : 61.5,
      20,
      4.8,
      const Color(0x241a1317),
    );

    // Independent head tilt follows a target, a petting tap, or a meal lean.
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
      gaze * .08 + math.sin(pet * math.pi) * .14 + (active ? wave * .035 : 0),
    );
    canvas.translate(-50, sleeping ? -51 : -45);

    // --- EARS WITH INDEPENDENT TWITCH & LONG EAR TUFTS ---
    final earShift = faceShift * .35;
    // Left Ear
    canvas.save();
    canvas.translate(34 + earShift, 31);
    canvas.rotate(leftEarTwitch);
    canvas.translate(-(34 + earShift), -31);
    final leftEar = Path()
      ..moveTo(25 + earShift, 37)
      ..quadraticBezierTo(26 + earShift, 19, 29.5 + earShift, 8.5)
      ..quadraticBezierTo(39.5 + earShift, 15, 45.5 + earShift, 31)
      ..close();
    path(canvas, leftEar, maru ? const Color(0xff5a5245) : fur);
    path(
      canvas,
      leftEar,
      maru ? dark.withValues(alpha: .85) : furOutline,
      style: PaintingStyle.stroke,
      width: 1.05,
    );
    if (!isBack) {
      path(
        canvas,
        Path()
          ..moveTo(29.5 + earShift, 31.5)
          ..quadraticBezierTo(30 + earShift, 20, 31.5 + earShift, 13.5)
          ..quadraticBezierTo(38 + earShift, 19.5, 43 + earShift, 30)
          ..close(),
        maru ? const Color(0xffcca995) : ladyPink,
      );
      if (maru) {
        // Maru's signature long feathery white/cream ear furnishings curving outward!
        final leftTuft = Path()
          ..moveTo(35 + earShift, 28)
          ..quadraticBezierTo(26 + earShift, 18, 21.5 + earShift, 22.5)
          ..quadraticBezierTo(26.5 + earShift, 22, 31 + earShift, 26)
          ..quadraticBezierTo(24.5 + earShift, 24, 22.5 + earShift, 27.5)
          ..quadraticBezierTo(28.5 + earShift, 26.5, 36 + earShift, 30.5)
          ..close();
        path(canvas, leftTuft, chestBright);
        line(canvas, 29.5 + earShift, 9, 28.8 + earShift, 6.8, dark, 1.15);
      } else {
        for (var n = 0; n < 4; n++) {
          line(
            canvas,
            34 + earShift + n * 1.4,
            29,
            29.5 + earShift + n * .7,
            19.0 + n,
            Colors.white,
            .95,
          );
        }
      }
    } else if (!maru) {
      // Back of Lady's left ear has a touch of warm peach at the base.
      ellipse(
        canvas,
        35 + earShift,
        29,
        6,
        5,
        caramel.withValues(alpha: .75),
      );
    }
    canvas.restore();

    // Right Ear
    canvas.save();
    canvas.translate(66 + earShift, 31);
    canvas.rotate(rightEarTwitch);
    canvas.translate(-(66 + earShift), -31);
    final rightEar = Path()
      ..moveTo(54.5 + earShift, 31)
      ..quadraticBezierTo(60.5 + earShift, 15, 70.5 + earShift, 8.5)
      ..quadraticBezierTo(74 + earShift, 19, 75 + earShift, 37)
      ..close();
    path(canvas, rightEar, maru ? const Color(0xff5a5245) : fur);
    path(
      canvas,
      rightEar,
      maru ? dark.withValues(alpha: .85) : furOutline,
      style: PaintingStyle.stroke,
      width: 1.05,
    );
    if (!isBack) {
      path(
        canvas,
        Path()
          ..moveTo(57 + earShift, 30)
          ..quadraticBezierTo(62 + earShift, 19.5, 68.5 + earShift, 13.5)
          ..quadraticBezierTo(70 + earShift, 20, 70.5 + earShift, 31.5)
          ..close(),
        maru ? const Color(0xffcca995) : ladyPink,
      );
      if (maru) {
        // Maru's signature long feathery white/cream ear furnishings curving outward!
        final rightTuft = Path()
          ..moveTo(65 + earShift, 28)
          ..quadraticBezierTo(74 + earShift, 18, 78.5 + earShift, 22.5)
          ..quadraticBezierTo(73.5 + earShift, 22, 69 + earShift, 26)
          ..quadraticBezierTo(75.5 + earShift, 24, 77.5 + earShift, 27.5)
          ..quadraticBezierTo(71.5 + earShift, 26.5, 64 + earShift, 30.5)
          ..close();
        path(canvas, rightTuft, chestBright);
        line(canvas, 70.5 + earShift, 9, 71.2 + earShift, 6.8, dark, 1.15);
      } else {
        for (var n = 0; n < 4; n++) {
          line(
            canvas,
            66 + earShift - n * 1.4,
            29,
            70.5 + earShift - n * .7,
            19.0 + n,
            Colors.white,
            .95,
          );
        }
      }
    }
    canvas.restore();

    // --- PLUSH HEAD SILHOUETTE WITH FLUFFY CHEEK RUFFS ---
    final headShape = _plushHeadSilhouette();
    shadedPath(
      canvas,
      headShape,
      const Rect.fromLTWH(15, 20, 70, 47),
      top: furLight,
      mid: fur,
      bottom: furShade,
      border: furOutline,
      borderWidth: 1.1,
    );

    if (isBack) {
      // Back of the head markings when rotated > 0.65.
      canvas.save();
      canvas.clipPath(headShape);
      if (maru) {
        // Dark tabby crown stripes running down the back of Maru's head & neck.
        for (final dx in [-9.0, 0.0, 9.0]) {
          line(
            canvas,
            50 + dx + faceShift * .3,
            21,
            50 + dx * 1.2 + faceShift * .3,
            62,
            dark,
            3.6,
          );
        }
      } else {
        // Back of Lady's head: warm peach-apricot patch behind her right ear/nape
        // and the top edge of her dark crown patch (from Photo 7!).
        ellipse(canvas, 37 + faceShift * .3, 35, 16, 13, caramel);
        ellipse(canvas, 55 + faceShift * .3, 27, 13, 9, ladyMask);
      }
      canvas.restore();
      paintCatHeadClothing(canvas, outfit, turn: clampedTurn);
      canvas.restore();
      canvas.restore();
      return;
    }

    // --- FRONT & 3/4 FACIAL MARKINGS ---
    canvas.save();
    canvas.clipPath(headShape);
    if (maru) {
      // Soft lighter cheek ruff highlights on Maru's outer cheeks.
      for (final side in [-1.0, 1.0]) {
        ellipse(
          canvas,
          50 + side * 26 + faceShift * .4,
          52,
          10,
          9,
          const Color(0xff9e927a),
        );
      }
      // Classic tabby "M" forehead marking (outer legs low above brows, two high peaks,
      // and a central downward dip in the middle so it clearly reads as an "M").
      path(
        canvas,
        Path()
          ..moveTo(50 + faceShift - 12.2, 34.5)
          ..quadraticBezierTo(
            50 + faceShift - 9.8,
            27.5,
            50 + faceShift - 6.2,
            23.5,
          )
          ..lineTo(50 + faceShift, 30.8)
          ..lineTo(50 + faceShift + 6.2, 23.5)
          ..quadraticBezierTo(
            50 + faceShift + 9.8,
            27.5,
            50 + faceShift + 12.2,
            34.5,
          ),
        dark,
        style: PaintingStyle.stroke,
        width: 2.35,
      );
      // Subtle vertical tabby crown lines above the "M" peaks.
      for (final side in [-1.0, 1.0]) {
        line(
          canvas,
          50 + faceShift + side * 6.2,
          23.5,
          50 + faceShift + side * 7.8,
          20.5,
          dark.withValues(alpha: .75),
          1.4,
        );
        for (var n = 0; n < 3; n++) {
          final y = 43.5 + n * 4.8;
          path(
            canvas,
            Path()
              ..moveTo(50 + faceShift * .6 + side * 29, y - 2.5)
              ..quadraticBezierTo(
                50 + faceShift * .8 + side * 23,
                y,
                50 + faceShift + side * 16.5,
                y + 1,
              )
              ..quadraticBezierTo(
                50 + faceShift * .8 + side * 23,
                y + 3.5,
                50 + faceShift * .6 + side * 28,
                y,
              )
              ..close(),
            dark,
          );
        }
        // Dark tear-duct / nose-bridge contour lines.
        path(
          canvas,
          Path()
            ..moveTo(50 + faceShift + side * 5.2, 43.5)
            ..quadraticBezierTo(
              50 + faceShift + side * 7,
              49.5,
              50 + faceShift + side * 10,
              52,
            ),
          dark,
          style: PaintingStyle.stroke,
          width: 1.8,
        );
      }
      // Pale cream "spectacles" around Maru's eyes (very clear in Photos 2 & 5!).
      for (final baseX in [38.0, 62.0]) {
        ellipse(
          canvas,
          baseX + faceShift,
          43.2,
          10.8,
          sleeping ? 5.5 : 11.2,
          const Color(0xffd7caa8),
        );
      }
      // Warm golden-ochre nose bridge (`#c29b68`).
      path(
        canvas,
        Path()
          ..moveTo(45.8 + faceShift, 35)
          ..quadraticBezierTo(50 + faceShift, 32, 54.2 + faceShift, 35)
          ..lineTo(56.8 + faceShift, 52)
          ..quadraticBezierTo(50 + faceShift, 57, 43.2 + faceShift, 52)
          ..close(),
        const Color(0xffc29b68),
      );
      // Bright snowy-white chin (`mentón blanco nieve` from Maru's photos!).
      ellipse(canvas, 50 + faceShift, 60.2, 10.8, 5.4, chestBright);
      // Plump cream peanut whisker pads.
      ellipse(canvas, 43 + faceShift, 54.2, 10.8, 7.6, chest);
      ellipse(canvas, 57 + faceShift, 54.2, 10.8, 7.6, chest);
      for (final side in [-1.0, 1.0]) {
        for (var n = 0; n < 3; n++) {
          ellipse(
            canvas,
            50 + faceShift + side * (8.8 + n % 2 * 2.8),
            53.2 + n * 1.9,
            .65,
            .65,
            dark,
          );
        }
      }
    } else {
      // Lady's real asymmetrical calico face from her close-up portrait photo:
      // Bright snowy-white base across the crown, muzzle & cheeks.
      ellipse(canvas, 50 + faceShift * .3, 38, 29, 21, Colors.white);

      // 1) Warm peach-apricot patches at the ear bases AND on her right cheek
      // (viewer's right, directly below/beside her right eye, as seen in her photo!).
      // Upper-left ear base peach-apricot patch:
      path(
        canvas,
        Path()
          ..moveTo(20 + faceShift * .6, 34)
          ..quadraticBezierTo(23 + faceShift * .7, 19, 39 + faceShift, 20.0)
          ..quadraticBezierTo(36 + faceShift, 28, 30 + faceShift, 35)
          ..close(),
        caramel,
      );
      // Upper-right ear base apricot touch:
      path(
        canvas,
        Path()
          ..moveTo(60 + faceShift, 20.5)
          ..quadraticBezierTo(70 + faceShift * .8, 21, 74 + faceShift * .7, 30)
          ..quadraticBezierTo(67 + faceShift, 31, 60 + faceShift, 25)
          ..close(),
        caramel.withValues(alpha: .78),
      );
      // Viewer's right cheek warm peach-apricot patch (below the right eye):
      final rightCheekPeachRect = Rect.fromCenter(
        center: Offset(68.5 + faceShift * .75, 49.0),
        width: 19,
        height: 13.5,
      );
      canvas.drawOval(
        rightCheekPeachRect,
        Paint()
          ..shader = RadialGradient(
            colors: [
              caramel.withValues(alpha: .88),
              caramel.withValues(alpha: .52),
              caramel.withValues(alpha: 0.0),
            ],
            stops: const [0.0, 0.62, 1.0],
          ).createShader(rightCheekPeachRect),
      );
      // Subtle smoky-taupe smudge on viewer's left cheek (below the left eye):
      final leftCheekSmudgeRect = Rect.fromCenter(
        center: Offset(30.5 + faceShift * .75, 49.0),
        width: 12,
        height: 10,
      );
      canvas.drawOval(
        leftCheekSmudgeRect,
        Paint()
          ..shader = RadialGradient(
            colors: [
              const Color(0xff7d7678).withValues(alpha: .42),
              const Color(0xff7d7678).withValues(alpha: 0.0),
            ],
          ).createShader(leftCheekSmudgeRect),
      );

      // 2) Soft smoky-charcoal upper crown bridge at the very top of the forehead,
      // diffused with white and warm peach-cream in the center!
      final crownBridgeRect = Rect.fromCenter(
        center: Offset(49.5 + faceShift, 23.0),
        width: 28,
        height: 11,
      );
      canvas.drawOval(
        crownBridgeRect,
        Paint()
          ..shader = RadialGradient(
            colors: [
              const Color(0xff524d51).withValues(alpha: .78),
              const Color(0xff524d51).withValues(alpha: .38),
              Colors.white.withValues(alpha: 0.0),
            ],
            stops: const [0.0, 0.65, 1.0],
          ).createShader(crownBridgeRect),
      );

      // Left dark charcoal brow & upper-eyelid patch (hugs the left eye/brow):
      final leftBrowBounds = Rect.fromLTWH(26 + faceShift, 22, 21, 24);
      final leftBrowPatch = Path()
        ..moveTo(27.5 + faceShift, 41.0)
        ..cubicTo(
          27.5 + faceShift,
          31.5,
          33.5 + faceShift,
          23.5,
          44.0 + faceShift,
          23.0,
        )
        ..quadraticBezierTo(45.5 + faceShift, 31.0, 42.5 + faceShift, 41.5)
        ..cubicTo(
          38.0 + faceShift,
          45.5,
          29.5 + faceShift,
          45.0,
          27.5 + faceShift,
          41.0,
        )
        ..close();
      canvas.drawPath(
        leftBrowPatch,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              ladyMask.withValues(alpha: .92),
              ladyMask.withValues(alpha: .80),
              ladyMask.withValues(alpha: .28),
            ],
            stops: const [0.0, 0.68, 1.0],
          ).createShader(leftBrowBounds),
      );

      // Right dark charcoal brow & upper-eyelid patch (sweeps diagonally over the right eye):
      final rightBrowBounds = Rect.fromLTWH(52 + faceShift, 21, 21, 25);
      final rightBrowPatch = Path()
        ..moveTo(53.5 + faceShift, 23.0)
        ..cubicTo(
          62.5 + faceShift,
          21.5,
          71.5 + faceShift,
          28.0,
          72.0 + faceShift,
          39.0,
        )
        ..cubicTo(
          71.5 + faceShift,
          44.8,
          63.5 + faceShift,
          46.0,
          55.0 + faceShift,
          41.5,
        )
        ..quadraticBezierTo(52.0 + faceShift, 32.5, 53.5 + faceShift, 23.0)
        ..close();
      canvas.drawPath(
        rightBrowPatch,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.centerRight,
            end: Alignment.centerLeft,
            colors: [
              ladyMask.withValues(alpha: .94),
              ladyMask.withValues(alpha: .82),
              ladyMask.withValues(alpha: .25),
            ],
            stops: const [0.0, 0.68, 1.0],
          ).createShader(rightBrowBounds),
      );

      // 3) Warm peach-apricot-cream streak on the left side of the center forehead blaze
      // (between the left dark brow and the white center nose bridge, as in the photo!).
      final centerPeachStreak = Path()
        ..moveTo(42.0 + faceShift, 37.5)
        ..quadraticBezierTo(42.5 + faceShift, 26.5, 47.2 + faceShift, 23.5)
        ..quadraticBezierTo(50.0 + faceShift, 28.5, 48.5 + faceShift, 39.5)
        ..close();
      path(canvas, centerPeachStreak, const Color(0xffebb985).withValues(alpha: .88));

      // 4) Snowy-white flame diffusion rising from the nose bridge into the center forehead!
      final foreheadDiffusionRect = Rect.fromCenter(
        center: Offset(50.5 + faceShift, 34.0),
        width: 22,
        height: 25,
      );
      canvas.drawOval(
        foreheadDiffusionRect,
        Paint()
          ..shader = RadialGradient(
            colors: [
              Colors.white,
              Colors.white.withValues(alpha: .94),
              Colors.white.withValues(alpha: .52),
              Colors.white.withValues(alpha: 0.0),
            ],
            stops: const [0.0, 0.44, 0.76, 1.0],
          ).createShader(foreheadDiffusionRect),
      );

      // Snowy-white muzzle & tapered nose blaze rising between the eyes into the forehead.
      path(
        canvas,
        Path()
          ..moveTo(49.5 + faceShift, 24.5)
          ..quadraticBezierTo(51.5 + faceShift, 24.5, 53.2 + faceShift, 31.5)
          ..quadraticBezierTo(55.5 + faceShift, 43.0, 59 + faceShift, 53.5)
          ..quadraticBezierTo(50 + faceShift, 59.5, 41 + faceShift, 53.5)
          ..quadraticBezierTo(45.5 + faceShift, 43.0, 47.8 + faceShift, 31.5)
          ..close(),
        Colors.white,
      );
      ellipse(canvas, 43 + faceShift, 55, 11.8, 7.8, chest);
      ellipse(canvas, 57 + faceShift, 55, 11.8, 7.8, chest);
      ellipse(canvas, 50 + faceShift, 60, 10.2, 4.6, chest);
    }
    canvas.restore();

    paintCatDirt(canvas, cleanliness, head: true, turn: clampedTurn);

    // Subtle permanent rosy-peach cheek warmth + stronger blush when petted!
    for (final side in [-1.0, 1.0]) {
      ellipse(
        canvas,
        50 + faceShift + side * 20.2,
        50.8,
        5.8,
        3.2,
        const Color(
          0xffff8da6,
        ).withValues(alpha: .13 + .25 * happySquint),
      );
    }

    // --- TENDER, EXPRESSIVE KAWAII EYES, SMOOTH BLINK & HAPPY SQUINT ---
    for (final baseX in [38.0, 62.0]) {
      final x = baseX + faceShift;
      final isLeftEye = baseX < 50;
      if (sleeping || blinkAmount > 0.88) {
        final lid = Path()
          ..moveTo(x - 7.5, 43.2)
          ..quadraticBezierTo(x, 49.2, x + 7.5, 43.2);
        path(
          canvas,
          lid,
          maru ? dark : const Color(0xff7d6b61),
          style: PaintingStyle.stroke,
          width: 2.4,
        );
      } else if (happySquint > 0.42) {
        // Sweet happy curved eyes (^ ^) when being petted!
        final happyArc = Path()
          ..moveTo(x - 7.5, 45.2)
          ..quadraticBezierTo(x, 36.8, x + 7.5, 45.2);
        path(
          canvas,
          happyArc,
          maru ? dark : const Color(0xff3d3335),
          style: PaintingStyle.stroke,
          width: 2.6,
        );
      } else {
        final openRatio = (1.0 - blinkAmount).clamp(0.12, 1.0);
        const eyeY = 43.4;
        // Soft, round espresso-brown eye socket for a warm, tender expression.
        ellipse(
          canvas,
          x,
          eyeY,
          9.2,
          9.5 * openRatio,
          const Color(0xff2c2123),
        );
        // Luminous radial iris (warm honey-amber for Lady, bright lime-amber for Maru).
        final irisRect = Rect.fromCenter(
          center: Offset(x, eyeY),
          width: 15.8,
          height: 16.8 * openRatio,
        );
        canvas.drawOval(
          irisRect,
          Paint()
            ..shader = RadialGradient(
              center: const Alignment(0.0, 0.25),
              radius: 0.85,
              colors: [
                maru ? const Color(0xffe5ee8c) : const Color(0xfff4c971),
                amber,
                amberDeep,
              ],
              stops: const [0.0, 0.55, 1.0],
            ).createShader(irisRect),
        );
        // Big, round, affectionate dilated pupil ("ojos tiernos").
        final pupilX = x + gaze * 1.8;
        final pupilY = (crying ? 44.8 : eyeY) + 0.15;
        ellipse(
          canvas,
          pupilX,
          pupilY,
          crying ? 4.8 : 5.75,
          (crying ? 5.4 : 6.35) * openRatio,
          const Color(0xff1e1518),
        );
        // Glowing lower iris crescent rim underneath the pupil for extra warmth.
        if (openRatio > 0.5) {
          path(
            canvas,
            Path()
              ..moveTo(x - 4.8, eyeY + 4.4 * openRatio)
              ..quadraticBezierTo(
                x,
                eyeY + 7.4 * openRatio,
                x + 4.8,
                eyeY + 4.4 * openRatio,
              ),
            (maru ? const Color(0xfff1f9a5) : const Color(0xffffdf96))
                .withValues(alpha: .72),
            style: PaintingStyle.stroke,
            width: 1.4,
          );
        }
        // Triple kawaii specular catchlights (big glossy upper-left oval + lower-right
        // round sparkle + tiny upper-right starlight dot).
        if (openRatio > 0.45) {
          canvas.save();
          canvas.translate(pupilX - 2.4, eyeY - 3.3 * openRatio);
          canvas.rotate(-0.35);
          ellipse(canvas, 0, 0, 2.75, 2.15, Colors.white);
          canvas.restore();
          ellipse(
            canvas,
            pupilX + 2.5,
            eyeY + 2.7 * openRatio,
            1.35,
            1.35,
            Colors.white.withValues(alpha: .94),
          );
          ellipse(
            canvas,
            pupilX + 2.6,
            eyeY - 2.4 * openRatio,
            0.7,
            0.7,
            Colors.white.withValues(alpha: .85),
          );
        }
        // Soft, gentle upper lash line with a cute tiny outer flick.
        final outerDir = isLeftEye ? -1.0 : 1.0;
        path(
          canvas,
          Path()
            ..moveTo(x - 8.8, eyeY - 1.2 * openRatio)
            ..quadraticBezierTo(
              x,
              eyeY - 9.8 * openRatio,
              x + 8.8,
              eyeY - 1.2 * openRatio,
            ),
          const Color(0xff261c1e),
          style: PaintingStyle.stroke,
          width: 1.5,
        );
        line(
          canvas,
          x + outerDir * 8.4,
          eyeY - 1.4 * openRatio,
          x + outerDir * 10.2,
          eyeY - 2.8 * openRatio,
          const Color(0xff261c1e),
          1.35,
        );
      }

      if (crying && !sleeping) {
        final brow = Path()
          ..moveTo(x - 7, 32 + (baseX < 50 ? 3 : 0))
          ..quadraticBezierTo(x, 28, x + 7, 32 + (baseX > 50 ? 3 : 0));
        path(canvas, brow, dark, style: PaintingStyle.stroke, width: 2.3);
        final fall = (phase * 2 + (baseX > 50 ? .45 : 0)) % 1;
        final tearY = 52 + fall * 22;
        final tear = Path()
          ..moveTo(x, tearY - 5)
          ..quadraticBezierTo(x - 5, tearY + 2, x, tearY + 6)
          ..quadraticBezierTo(x + 5, tearY + 2, x, tearY - 5)
          ..close();
        path(canvas, tear, const Color(0xff5bc8ff).withValues(alpha: .85));
      }
    }

    // --- NOSE, MOUTH & WHISKERS ---
    final nx = 50.0 + faceShift;
    if (maru) {
      // Maru's terracotta-rose nose outlined in dark charcoal-brown.
      path(
        canvas,
        Path()
          ..moveTo(nx - 4.7, 51.3)
          ..quadraticBezierTo(nx, 49.8, nx + 4.7, 51.3)
          ..quadraticBezierTo(nx + 2.5, 54.6, nx, 56.4)
          ..quadraticBezierTo(nx - 2.5, 54.6, nx - 4.7, 51.3)
          ..close(),
        dark,
      );
      path(
        canvas,
        Path()
          ..moveTo(nx - 3.4, 51.7)
          ..quadraticBezierTo(nx, 50.7, nx + 3.4, 51.7)
          ..lineTo(nx, 54.5)
          ..close(),
        const Color(0xffc8785a),
      );
      line(canvas, nx - 1.5, 51.7, nx + 1.2, 51.5, const Color(0xffe6a98e), .7);
    } else {
      // Lady's sweet rose-pink nose with soft highlight.
      path(
        canvas,
        Path()
          ..moveTo(nx - 4.5, 51.3)
          ..quadraticBezierTo(nx, 49.7, nx + 4.5, 51.3)
          ..quadraticBezierTo(nx + 2.8, 54.5, nx, 56.4)
          ..quadraticBezierTo(nx - 2.8, 54.5, nx - 4.5, 51.3)
          ..close(),
        ladyPink,
      );
      line(canvas, nx - 2.2, 51.4, nx + 1.2, 51.1, const Color(0xffffdae0), .8);
    }

    final mouthColor = maru ? dark : const Color(0xff84787c);
    line(canvas, nx, 56, nx, 59.8, mouthColor, 1.45);
    if (crying && !sleeping) {
      final sadMouth = Path()
        ..moveTo(nx - 8, 65)
        ..quadraticBezierTo(nx, 57, nx + 8, 65);
      path(
        canvas,
        sadMouth,
        mouthColor,
        style: PaintingStyle.stroke,
        width: 2,
      );
    } else {
      // Curved feline 'w' mouth that lifts into a wider smile when petted!
      final smileLift = happySquint * 1.4;
      path(
        canvas,
        Path()
          ..moveTo(nx - 5.5, 61.2 - smileLift)
          ..quadraticBezierTo(nx - 2.5, 62.5, nx, 59.8)
          ..quadraticBezierTo(nx + 2.5, 62.5, nx + 5.5, 61.2 - smileLift),
        mouthColor,
        style: PaintingStyle.stroke,
        width: 1.35,
      );
    }

    if ((feeding || (munching && mealProgress == null)) && !sleeping) {
      final lick = (math.sin(phase * math.pi * 8) + 1) / 2;
      ellipse(
        canvas,
        nx,
        63 + lick * 2,
        2.3,
        3 + lick * 2,
        const Color(0xffed8ca3),
      );
    }

    // Long, graceful arched whiskers with subtle breathing/petting motion.
    final whiskerLift = happySquint * 2.2 + (munching ? math.sin(phase * math.pi * 8) * 1.2 : 0.0);
    if (maru) {
      for (final dy in [-4.0, 0.0, 4.0, 7.0]) {
        for (final side in [-1.0, 1.0]) {
          path(
            canvas,
            Path()
              ..moveTo(nx + side * 12.5, 54.8 + dy)
              ..quadraticBezierTo(
                nx + side * 26,
                53.2 + dy - whiskerLift * .4,
                nx + side * 42,
                51.8 + dy * 1.65 - whiskerLift,
              ),
            const Color(0xfff7f1e1),
            style: PaintingStyle.stroke,
            width: .85,
          );
        }
      }
    } else {
      for (final dy in [-3.0, 1.0, 5.0]) {
        for (final side in [-1.0, 1.0]) {
          path(
            canvas,
            Path()
              ..moveTo(nx + side * 12.5, 54.8 + dy)
              ..quadraticBezierTo(
                nx + side * 26,
                53.5 + dy - whiskerLift * .4,
                nx + side * 40,
                51.8 + dy * 1.55 - whiskerLift,
              ),
            const Color(0xffcabdb0),
            style: PaintingStyle.stroke,
            width: .78,
          );
        }
      }
    }

    paintCatHeadClothing(canvas, outfit, turn: clampedTurn);
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
      old.cat != cat ||
      old.outfit != outfit ||
      old.cleanliness != cleanliness ||
      old.showShadow != showShadow ||
      old.forcedBlink != forcedBlink ||
      old.hideWorkingPaw != hideWorkingPaw ||
      old.turn != turn;
}
