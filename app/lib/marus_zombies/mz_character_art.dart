import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'mz_art_style.dart';
import 'mz_catalog.dart';

part 'mz_enemy_art.dart';

enum _FacePersona {
  familiar,
  hunter,
  cushion,
  crooked,
  wrapped,
  showman,
  automaton,
}

/// Cutout illustrations in a 100 × 110 local canvas. Feet land at y=98.
/// The public anchor matches MzBoardGeometry.point; shadows never inherit bobbing.
void mzPaintCharacter(
  Canvas c,
  Offset center,
  double size, {
  MzCat? cat,
  MzEnemy? enemy,
  double phase = 0,
  bool armor = false,
  bool armed = false,
  double attack = 0,
  double hurt = 0,
  double prepare = 0,
  double performance = 0,
  bool walking = true,
}) {
  c.save();
  c.translate(center.dx - size / 2, center.dy - size * .79);
  c.scale(size / 100);
  final heavy =
      cat == MzCat.barrier ||
      enemy == MzEnemy.bucket ||
      enemy == MzEnemy.mecha ||
      enemy == MzEnemy.pianist ||
      enemy == MzEnemy.pharaoh ||
      enemy == MzEnemy.cannon;
  final shadow = Rect.fromCenter(
    center: const Offset(50, 98),
    width: heavy
        ? 84
        : cat == MzCat.mine
        ? 68
        : 60,
    height: heavy ? 12 : 8,
  );
  mzArtOval(
    c,
    shadow.inflate(2).translate(2, 1),
    const Color(0x17233623),
    stroke: 0,
  );
  mzArtOval(c, shadow, const Color(0x38233623), stroke: 0);
  // A brief event-driven recoil affects only the drawing, never the logical cell.
  c.translate(-attack * 3 + hurt * (enemy == null ? 3 : -3), 0);
  {
    c.translate(50, 98);
    final weight = heavy ? .35 : 1.0;
    c.scale(
      1 + (attack * .065 - prepare * .035 + hurt * .045) * weight,
      1 - (attack * .04 - prepare * .025 + hurt * .06) * weight,
    );
    c.translate(-50, -98);
  }
  if (enemy != null) {
    if (enemy == MzEnemy.boss) {
      _boss(c, phase, hurt);
    } else {
      c.translate(100, 0);
      c.scale(-1, 1); // Invaders face the home at the left.
      _invader(
        c,
        enemy,
        phase,
        armor,
        hurt,
        walking,
        attack: attack,
        performance: performance,
      );
    }
  } else {
    if (cat == MzCat.mine) c.translate(math.sin(phase * 22) * prepare, 0);
    _defender(
      c,
      cat ?? MzCat.launcher,
      phase,
      armor,
      armed,
      attack,
      hurt,
      prepare: prepare,
    );
  }
  c.restore();
}

MzMuse _muse(MzCat cat) => switch (cat) {
  MzCat.sunflower ||
  MzCat.barrier ||
  MzCat.mine ||
  MzCat.catapult ||
  MzCat.laser => MzMuse.maru,
  _ => MzMuse.lady,
};

/// Maru's mythical form appears only during the real summon effect.
void mzPaintAncestral(
  Canvas c,
  Offset center,
  double size,
  double opacity, {
  bool reducedMotion = false,
}) {
  c.saveLayer(
    Rect.fromCenter(center: center, width: size * 1.5, height: size * 1.8),
    Paint()..color = Colors.white.withValues(alpha: opacity.clamp(0.0, 1.0)),
  );
  c.translate(center.dx - size / 2, center.dy - size * .79);
  c.scale(size / 100);
  final fur = _fur(MzMuse.maru, MzArt.gold, .25);
  _tail(c, MzMuse.maru, fur, 0, low: true);
  _body(c, MzMuse.maru, fur, heavy: true);
  final mane = Path();
  for (var i = 0; i < 32; i++) {
    final a = i * math.pi / 16;
    final radius = i.isEven ? 46.0 : 38.0;
    final p = Offset(51 + math.cos(a) * radius, 48 + math.sin(a) * radius);
    if (i == 0) {
      mane.moveTo(p.dx, p.dy);
    } else {
      mane.lineTo(p.dx, p.dy);
    }
  }
  mane.close();
  c.save();
  c.translate(51, 48);
  c.rotate(reducedMotion ? 0 : math.sin((1 - opacity) * 9) * .018);
  c.translate(-51, -48);
  mzArtShape(c, mane, const Color(0xffd69a38), material: MzMaterial.fur);
  mzArtVolume(c, mane, strength: .8);
  c.restore();
  _face(
    c,
    MzMuse.maru,
    fur,
    0,
    determined: true,
    attack: reducedMotion ? 0 : (1 - opacity) * .7,
  );
  _paw(c, const Rect.fromLTWH(16, 85, 27, 13), fur);
  _paw(c, const Rect.fromLTWH(65, 85, 27, 13), fur);
  _spark(c, const Offset(50, 12), 7);
  c.restore();
}

Color _fur(MzMuse muse, Color accent, [double tint = .13]) => Color.lerp(
  muse == MzMuse.maru ? MzArt.maruFur : MzArt.ladyFur,
  accent,
  tint,
)!;

void _tail(
  Canvas c,
  MzMuse muse,
  Color fur,
  double phase, {
  bool low = false,
  bool ragged = false,
}) {
  c.save();
  c.translate(30, 79);
  c.rotate(math.sin(phase * 1.9) * .09);
  final path = Path()
    ..moveTo(3, 8)
    ..cubicTo(-23, 14, -32, low ? 4 : -26, -20, low ? -7 : -34)
    ..quadraticBezierTo(-11, low ? -12 : -40, -10, low ? -3 : -29)
    ..cubicTo(-21, low ? -1 : -20, -11, 4, 6, -3)
    ..close();
  mzArtShape(
    c,
    path,
    muse == MzMuse.lady ? MzArt.ladyCrown : fur,
    material: MzMaterial.fur,
    stroke: 2.6,
  );
  c.save();
  c.clipPath(path);
  for (var i = 0; i < 3; i++) {
    mzArtLine(
      c,
      Path()
        ..moveTo(-30, -25 + i * 12)
        ..lineTo(-7, -21 + i * 12),
      muse == MzMuse.maru ? MzArt.maruStripe : MzArt.ladyMask,
      ragged ? 4 : 5,
    );
  }
  c.restore();
  mzArtVolume(c, path, strength: .8);
  c.restore();
}

final _bodyShapes = <int, Path>{};

void _body(
  Canvas c,
  MzMuse muse,
  Color fur, {
  bool heavy = false,
  bool lean = false,
  bool zombie = false,
  bool refined = true,
}) {
  final transform = c.getTransform();
  final scale = math.sqrt(
    transform[0] * transform[0] + transform[1] * transform[1],
  );
  refined = refined && scale >= .45;
  final body = _bodyShapes.putIfAbsent(
    heavy
        ? 0
        : lean
        ? 1
        : 2,
    () => heavy
        ? (Path()
            ..moveTo(13, 85)
            ..cubicTo(6, 62, 31, 55, 51, 59)
            ..cubicTo(82, 50, 99, 74, 91, 91)
            ..quadraticBezierTo(58, 103, 17, 96)
            ..close())
        : lean
        ? (Path()
            ..moveTo(27, 91)
            ..quadraticBezierTo(25, 76, 46, 60)
            ..quadraticBezierTo(76, 51, 79, 73)
            ..lineTo(73, 94)
            ..quadraticBezierTo(47, 101, 27, 91)
            ..close())
        : (Path()
            ..moveTo(25, 91)
            ..cubicTo(15, 63, 28, 51, 52, 55)
            ..cubicTo(81, 52, 92, 71, 80, 93)
            ..quadraticBezierTo(52, 104, 25, 91)
            ..close()),
  );
  mzArtShape(c, body, fur, material: MzMaterial.fur);
  c.save();
  c.clipPath(body);
  final chest = muse == MzMuse.maru ? MzArt.maruChest : MzArt.ladyFur;
  mzArtShape(
    c,
    Path()
      ..moveTo(43, 58)
      ..quadraticBezierTo(69, 55, 76, 70)
      ..quadraticBezierTo(80, 88, 60, 97)
      ..quadraticBezierTo(39, 97, 39, 78)
      ..close(),
    zombie ? Color.lerp(chest, const Color(0xff8ea392), .4)! : chest,
    stroke: 0,
  );
  if (muse == MzMuse.maru) {
    for (var i = 0; i < 3; i++) {
      final y = 64.0 + i * 9;
      mzArtShape(
        c,
        Path()
          ..moveTo(16, y)
          ..quadraticBezierTo(32, y - 3, 40, y + 5)
          ..quadraticBezierTo(30, y + 3, 16, y + 6)
          ..close(),
        MzArt.maruStripe,
        stroke: 0,
      );
    }
  } else {
    mzArtShape(
      c,
      Path()
        ..moveTo(23, 62)
        ..quadraticBezierTo(42, 66, 38, 83)
        ..quadraticBezierTo(28, 91, 22, 89)
        ..close(),
      MzArt.ladyMask,
      stroke: 0,
    );
  }
  c.restore();
  if (refined) mzArtVolume(c, body);
}

void _paw(Canvas c, Rect footprint, Color color, {bool claws = false}) {
  c.save();
  c.translate(footprint.left, footprint.top);
  final rect = Offset.zero & footprint.size;
  mzArtOval(c, rect, color, material: MzMaterial.fur, stroke: 2.3);
  mzArtVolume(c, Path()..addOval(rect), strength: .65);
  for (var i = 1; i < 3; i++) {
    final x = rect.left + rect.width * i / 3;
    mzArtLine(
      c,
      Path()
        ..moveTo(x, rect.bottom - 5)
        ..lineTo(x - .7, rect.bottom - 2),
      claws ? MzArt.paper : MzArt.ink,
      .9,
    );
  }
  c.restore();
}

final _faceShapes = <String, Path>{};

void _face(
  Canvas c,
  MzMuse muse,
  Color fur,
  double phase, {
  bool sleepy = false,
  bool determined = false,
  bool zombie = false,
  bool dog = false,
  bool ice = false,
  double hurt = 0,
  double attack = 0,
  double prepare = 0,
  bool refined = true,
  _FacePersona persona = _FacePersona.familiar,
}) {
  final transform = c.getTransform();
  refined =
      refined &&
      math.sqrt(transform[0] * transform[0] + transform[1] * transform[1]) >=
          .45;
  final blink = !zombie && phase > 0 && (phase % 5.3) > 5.12;
  final expression = mzExpression(
    sleepy: sleepy,
    focused: determined || prepare > .1,
    zombie: zombie,
    attack: attack,
    hurt: hurt,
  );
  // Organic cheek tufts and tapered ears share the protagonists' actual anatomy.
  final head = _faceShapes.putIfAbsent(
    'head-${persona.name}',
    () =>
        persona == _FacePersona.cushion
              ? (Path()
                  ..moveTo(20, 36)
                  ..cubicTo(17, 22, 38, 18, 53, 21)
                  ..cubicTo(79, 18, 92, 31, 85, 48)
                  ..quadraticBezierTo(95, 61, 70, 70)
                  ..quadraticBezierTo(43, 77, 19, 62)
                  ..quadraticBezierTo(10, 53, 20, 36)
                  ..close())
              : persona == _FacePersona.hunter
              ? (Path()
                  ..moveTo(25, 37)
                  ..cubicTo(20, 24, 39, 17, 56, 21)
                  ..cubicTo(77, 20, 87, 34, 80, 46)
                  ..lineTo(88, 49)
                  ..quadraticBezierTo(82, 60, 68, 65)
                  ..quadraticBezierTo(40, 69, 23, 57)
                  ..lineTo(16, 47)
                  ..lineTo(25, 45)
                  ..close())
              : Path()
          ..moveTo(23, 38)
          ..cubicTo(17, 21, 36, 18, 53, 20)
          ..cubicTo(76, 17, 88, 31, 83, 46)
          ..lineTo(88, 50)
          ..lineTo(81, 51)
          ..lineTo(83, 56)
          ..quadraticBezierTo(70, 71, 47, 67)
          ..quadraticBezierTo(22, 65, 18, 51)
          ..lineTo(13, 47)
          ..lineTo(21, 45)
          ..close(),
  );
  final earLeft = _faceShapes.putIfAbsent(
    'earLeft',
    () => Path()
      ..moveTo(23, 36)
      ..quadraticBezierTo(20, 23, 25, 8)
      ..quadraticBezierTo(39, 15, 43, 28)
      ..close(),
  );
  final earRight = _faceShapes.putIfAbsent(
    'earRight',
    () => Path()
      ..moveTo(59, 27)
      ..quadraticBezierTo(66, 14, 79, 7)
      ..quadraticBezierTo(86, 25, 78, 38)
      ..close(),
  );
  if (dog) {
    mzArtShape(
      c,
      Path()
        ..moveTo(26, 24)
        ..quadraticBezierTo(8, 19, 14, 50)
        ..quadraticBezierTo(25, 57, 32, 35)
        ..close(),
      Color.lerp(fur, MzArt.ink, .2)!,
    );
    mzArtShape(
      c,
      Path()
        ..moveTo(71, 23)
        ..quadraticBezierTo(95, 18, 91, 51)
        ..quadraticBezierTo(79, 57, 73, 36)
        ..close(),
      Color.lerp(fur, MzArt.ink, .2)!,
    );
  } else {
    mzArtShape(c, earLeft, fur, material: MzMaterial.fur);
    mzArtShape(c, earRight, fur, material: MzMaterial.fur);
    mzArtShape(
      c,
      Path()
        ..moveTo(27, 27)
        ..lineTo(28, 15)
        ..lineTo(36, 27)
        ..close(),
      muse == MzMuse.maru ? MzArt.maruChest : MzArt.pink,
      stroke: .9,
    );
    mzArtShape(
      c,
      Path()
        ..moveTo(66, 27)
        ..lineTo(76, 15)
        ..lineTo(77, 31)
        ..close(),
      muse == MzMuse.maru ? MzArt.maruChest : MzArt.pink,
      stroke: .9,
    );
  }
  mzArtShape(c, head, fur, material: ice ? MzMaterial.ice : MzMaterial.fur);
  c.save();
  c.clipPath(head);
  if (muse == MzMuse.maru) {
    for (final side in [-1.0, 1.0]) {
      mzArtShape(
        c,
        Path()
          ..moveTo(51 + side * 8, 22)
          ..lineTo(51 + side * 15, 24)
          ..lineTo(51 + side * 10, 35)
          ..lineTo(51 + side * 4, 30)
          ..lineTo(51, 35)
          ..lineTo(51 + side * 2, 23)
          ..close(),
        MzArt.maruStripe,
        stroke: 0,
      );
      for (var i = 0; i < (refined ? 2 : 1); i++) {
        final y = 44.0 + i * 7;
        mzArtShape(
          c,
          Path()
            ..moveTo(51 + side * 29, y - 3)
            ..quadraticBezierTo(51 + side * 22, y, 51 + side * 18, y + 2)
            ..lineTo(51 + side * 29, y + 3)
            ..close(),
          MzArt.maruStripe,
          stroke: 0,
        );
      }
    }
  } else {
    mzArtShape(
      c,
      Path()
        ..moveTo(20, 33)
        ..quadraticBezierTo(28, 14, 52, 21)
        ..quadraticBezierTo(76, 14, 84, 33)
        ..lineTo(76, 42)
        ..lineTo(30, 43)
        ..close(),
      zombie ? const Color(0xffb89b79) : MzArt.ladyCrown,
      stroke: 0,
    );
    for (final rect in [
      const Rect.fromLTWH(25, 29, 23, 24),
      const Rect.fromLTWH(53, 28, 26, 26),
    ]) {
      mzArtOval(c, rect, MzArt.ladyMask, stroke: 0);
    }
    mzArtShape(
      c,
      Path()
        ..moveTo(50, 28)
        ..lineTo(46, 41)
        ..lineTo(43, 56)
        ..quadraticBezierTo(53, 63, 61, 55)
        ..lineTo(55, 40)
        ..close(),
      MzArt.ladyFur,
      stroke: 0,
    );
  }
  c.restore();
  if (refined) {
    mzArtVolume(c, head);
    for (final x in [29.0, 76.0]) {
      mzArtOval(
        c,
        Rect.fromLTWH(x - 5, 49, 12, 6),
        (zombie ? const Color(0xff72836b) : MzArt.pink).withValues(alpha: .24),
        stroke: 0,
      );
    }
    mzArtLine(
      c,
      Path()
        ..moveTo(27, 24)
        ..quadraticBezierTo(35, 20, 45, 22),
      MzArt.rim.withValues(alpha: .5),
      1.5,
    );
  }
  final muzzle = zombie
      ? const Color(0xffc4cbb0)
      : muse == MzMuse.maru
      ? MzArt.maruChest
      : MzArt.ladyFur;
  mzArtOval(c, const Rect.fromLTWH(41, 49, 22, 16), muzzle, stroke: 0);
  mzArtOval(
    c,
    Rect.fromLTWH(57, dog ? 48 : 49, dog ? 25 : 22, dog ? 18 : 16),
    muzzle,
    stroke: 0,
  );
  // Eyes have independent sizes and gaze; enemies keep their asymmetry.
  for (var i = 0; i < 2; i++) {
    final x = i == 0 ? 37.0 : 68.0;
    final y =
        (i == 0 ? 42.0 : 40.5) +
        (persona == _FacePersona.crooked || persona == _FacePersona.showman
            ? (i == 0 ? 2 : -2)
            : persona == _FacePersona.automaton
            ? (i == 0 ? -1 : 2)
            : 0);
    if (blink || expression == MzExpression.hurt) {
      mzArtLine(
        c,
        Path()
          ..moveTo(x - 6, y)
          ..quadraticBezierTo(x, y + 3, x + 6, y),
        MzArt.ink,
        2,
      );
      continue;
    }
    final rect = Rect.fromCenter(
      center: Offset(x, y),
      width: zombie ? 19 : 14,
      height: zombie
          ? (persona == _FacePersona.automaton
                ? (i == 0 ? 17 : 13)
                : persona == _FacePersona.wrapped
                ? (i == 0 ? 24 : 17)
                : (i == 0 ? 20 : 23))
          : sleepy
          ? 9
          : 16 - prepare.clamp(0, 1) * 4,
    );
    mzArtOval(
      c,
      rect,
      zombie ? const Color(0xffe5ddbb) : MzArt.ink,
      stroke: 1.2,
    );
    if (!zombie) {
      mzArtOval(
        c,
        rect.deflate(1.8),
        muse == MzMuse.maru ? MzArt.maruEyes : MzArt.ladyEyes,
        stroke: 0,
      );
    }
    mzArtOval(
      c,
      Rect.fromCenter(
        center: Offset(
          x +
              (zombie && refined ? (i == 0 ? -2 : 3) : 2.0) +
              (prepare + attack) * 1.5,
          y +
              (zombie
                  ? (persona == _FacePersona.crooked && i == 1 ? -1 : 3)
                  : 0),
        ),
        width: zombie ? 5 : 4.5,
        height: zombie
            ? 5
            : sleepy
            ? 7
            : 11,
      ),
      MzArt.ink,
      stroke: 0,
    );
    if (!zombie) {
      mzArtOval(
        c,
        Rect.fromLTWH(x - 2, y - 5, 3.5, 3.5),
        Colors.white,
        stroke: 0,
      );
    }
    if ((persona == _FacePersona.crooked && i == 0) ||
        (persona == _FacePersona.cushion && zombie) ||
        (persona == _FacePersona.showman && i == 1)) {
      c.save();
      c.clipPath(Path()..addOval(rect));
      c.drawRect(Rect.fromLTWH(x - 11, y - 13, 22, 10), Paint()..color = fur);
      c.restore();
      mzArtLine(
        c,
        Path()
          ..moveTo(x - 8, y - 3)
          ..lineTo(x + 8, y - 3),
        MzArt.ink,
        1.5,
      );
    }
    if ((determined && persona != _FacePersona.cushion) ||
        zombie ||
        expression == MzExpression.attacking) {
      mzArtLine(
        c,
        Path()
          ..moveTo(x - 8, y - 11 + (i == 0 ? -1 : 2))
          ..quadraticBezierTo(x, y - 9, x + 6, y - 11),
        MzArt.ink,
        1.7,
      );
    }
  }
  mzArtShape(
    c,
    Path()
      ..moveTo(54, 51)
      ..quadraticBezierTo(60, 49, 65, 51)
      ..lineTo(60, 57)
      ..close(),
    dog
        ? MzArt.ink
        : zombie
        ? const Color(0xff677354)
        : MzArt.pink,
    stroke: 1.2,
  );
  if (zombie) {
    c.save();
    if (refined) c.translate(0, math.sin(phase * 3.3) * .5 + attack * 2);
    mzArtShape(
      c,
      Path()
        ..moveTo(46, 58)
        ..quadraticBezierTo(57, 57, 71, 59)
        ..quadraticBezierTo(67, 69, 51, 68)
        ..close(),
      const Color(0xff38372e),
      stroke: 1.5,
    );
    for (final x in [51.0, 65.0]) {
      mzArtShape(
        c,
        Path()
          ..moveTo(x, 59)
          ..lineTo(x + 4, 59)
          ..lineTo(x + 1, 64)
          ..close(),
        MzArt.paper,
        stroke: .5,
      );
    }
    c.restore();
    mzArtLine(
      c,
      Path()
        ..moveTo(76, 26)
        ..lineTo(72, 31)
        ..lineTo(78, 34),
      const Color(0xff697660),
      1.3,
    );
  } else if (refined && expression == MzExpression.attacking && !sleepy) {
    mzArtOval(
      c,
      const Rect.fromLTWH(54, 57, 14, 9),
      const Color(0xff65443f),
      stroke: 1.3,
    );
    mzArtOval(c, const Rect.fromLTWH(58, 62, 7, 3), MzArt.pink, stroke: 0);
  } else {
    mzArtLine(
      c,
      Path()
        ..moveTo(60, 57)
        ..lineTo(60, 60)
        ..quadraticBezierTo(52, 66, 47, 60)
        ..moveTo(60, 60)
        ..quadraticBezierTo(65, 65, 71, 59),
      MzArt.ink,
      1.5,
    );
  }
  for (var i = 0; i < (refined ? 2 : 1); i++) {
    final y = 55.0 + i * 5;
    mzArtLine(
      c,
      Path()
        ..moveTo(33, y)
        ..quadraticBezierTo(22, y - 3, 15, y - 1),
      muse == MzMuse.maru ? MzArt.paper : const Color(0xff938879),
      1,
    );
    mzArtLine(
      c,
      Path()
        ..moveTo(78, y)
        ..lineTo(91, y + i * 2 - 1),
      muse == MzMuse.maru ? MzArt.paper : const Color(0xff938879),
      1,
    );
  }
}

void _petals(Canvas c, double phase) {
  for (var i = 0; i < 12; i++) {
    c.save();
    c.translate(51, 53);
    c.rotate(i * math.pi / 6 + math.sin(phase) * .015);
    mzArtShape(
      c,
      Path()
        ..moveTo(-6, -23)
        ..cubicTo(-13, -43, 9, -44, 7, -26)
        ..quadraticBezierTo(1, -19, -6, -23)
        ..close(),
      i.isEven ? const Color(0xffffdc68) : const Color(0xffeeb13c),
      stroke: 1.6,
    );
    c.restore();
  }
}

void _defender(
  Canvas c,
  MzCat kind,
  double phase,
  bool armor,
  bool armed,
  double attack,
  double hurt, {
  double prepare = 0,
}) {
  if (kind == MzCat.bomb) {
    // The cherry pair is represented by both protagonists, not one recoloured cat.
    for (var i = 0; i < 2; i++) {
      c.save();
      c.translate(i == 0 ? 1 : 39, i == 0 ? 28 : 22);
      c.scale(.62);
      _cat(
        c,
        i == 0 ? MzMuse.maru : MzMuse.lady,
        kind,
        phase + i,
        attack: attack,
        hurt: hurt,
        prepare: prepare,
      );
      c.restore();
    }
    mzArtLine(
      c,
      Path()
        ..moveTo(41, 42)
        ..quadraticBezierTo(44, 19, 53, 11),
      MzArt.ink,
      2.5,
    );
    _spark(c, const Offset(53, 11), 5);
    return;
  }
  if (kind == MzCat.mine) {
    _box(c, armed);
    c.save();
    c.translate(10, armed ? 13 : 33);
    c.scale(.78);
    _face(
      c,
      MzMuse.maru,
      _fur(MzMuse.maru, MzArt.accent(kind)),
      phase,
      sleepy: !armed,
      hurt: hurt,
      prepare: prepare,
    );
    c.restore();
    _boxFront(c);
    mzArtLine(
      c,
      Path()
        ..moveTo(50, 18)
        ..lineTo(50, 9),
      MzArt.ink,
      2,
    );
    mzArtOval(
      c,
      const Rect.fromLTWH(46, 3, 9, 9),
      armed ? const Color(0xfff17453) : const Color(0xffaa9673),
      stroke: 1.3,
    );
    return;
  }
  if (kind == MzCat.catapult) {
    mzArtBox(c, const Rect.fromLTWH(18, 92, 69, 8), MzArt.woodDark, radius: 3);
    mzArtBox(
      c,
      const Rect.fromLTWH(43, 64, 18, 30),
      MzArt.woodLight,
      radius: 3,
    );
    for (var y = 67.0; y < 92; y += 5) {
      mzArtLine(
        c,
        Path()
          ..moveTo(44, y)
          ..lineTo(59, y + 2),
        MzArt.woodDark,
        1.5,
      );
    }
    c.save();
    c.translate(5, -12);
    c.scale(.9);
    _cat(
      c,
      _muse(kind),
      kind,
      phase,
      attack: attack,
      hurt: hurt,
      prepare: prepare,
    );
    c.restore();
    _catapultArm(c, attack - prepare * .55);
    return;
  }
  if (kind == MzCat.spring) {
    mzArtOval(
      c,
      const Rect.fromLTWH(24, 90, 54, 9),
      const Color(0xffa4a8b2),
      material: MzMaterial.metal,
    );
    final lift = -attack * 6 + prepare * 3;
    final coil = Path()..moveTo(30, 73 + lift);
    for (var i = 0; i < 4; i++) {
      coil
        ..lineTo(71, 75.0 + i * 5 + lift * (1 - i / 4))
        ..lineTo(30, 78.0 + i * 5 + lift * (1 - i / 4));
    }
    mzArtLine(c, coil, MzArt.ink, 4);
    mzArtLine(c, coil, const Color(0xffd9e0dc), 2);
    c.save();
    c.translate(9, -9 + lift);
    c.scale(.84);
    _cat(
      c,
      _muse(kind),
      kind,
      phase,
      attack: attack,
      hurt: hurt,
      prepare: prepare,
    );
    c.restore();
    return;
  }
  _cat(
    c,
    _muse(kind),
    kind,
    phase,
    armor: armor,
    attack: attack,
    hurt: hurt,
    prepare: prepare,
  );
}

void _cat(
  Canvas c,
  MzMuse muse,
  MzCat kind,
  double phase, {
  bool armor = false,
  double attack = 0,
  double hurt = 0,
  double prepare = 0,
}) {
  final accent = MzArt.accent(kind), heavy = kind == MzCat.barrier;
  final lean = kind == MzCat.launcher || kind == MzCat.boomerang;
  final fur = _fur(
    muse,
    accent,
    kind == MzCat.ice
        ? .38
        : kind == MzCat.sunflower
        ? .4
        : heavy
        ? .3
        : .22,
  );
  final bob = math.sin(phase * (heavy ? 1.5 : 2.3)) * (heavy ? .35 : .7);
  _tail(c, muse, fur, phase, low: heavy);
  c.save();
  c.translate(50, 97);
  c.scale(1, 1 + bob * .009);
  c.translate(-50, -97);
  _body(c, muse, fur, heavy: heavy || kind == MzCat.sunflower, lean: lean);
  if (kind == MzCat.sunflower) _petals(c, phase + prepare * .6 - attack * .3);
  if (kind == MzCat.lightning) {
    mzArtShape(
      c,
      Path()
        ..moveTo(26, 40)
        ..lineTo(17, 35)
        ..lineTo(21, 50)
        ..lineTo(12, 54)
        ..lineTo(23, 63)
        ..close(),
      accent,
      stroke: 1.6,
    );
  }
  _paw(c, Rect.fromLTWH(heavy ? 15 : 25, 85, heavy ? 27 : 22, 13), fur);
  _paw(c, Rect.fromLTWH(heavy ? 65 : 62, 86, heavy ? 27 : 23, 12), fur);
  // Heads are actually proportioned by role; the barrier is low and broad.
  c.save();
  {
    c.translate(52, 59);
    c.rotate(
      math.sin(phase * 1.4) * (heavy ? .007 : .022) -
          prepare * .07 +
          attack * .06,
    );
    c.translate(-52, -59);
  }
  if (heavy) {
    c.translate(-6, 27);
    c.scale(1.10, .75);
  }
  if (kind == MzCat.sunflower) {
    c.translate(-1, -1);
    c.scale(1.025, 1.015);
  }
  if (lean) {
    c.translate(kind == MzCat.launcher ? 10 : 7, 8);
    c.scale(kind == MzCat.launcher ? .91 : .95, .96);
  }
  if (kind == MzCat.ice) {
    mzArtShape(
      c,
      Path()
        ..moveTo(23, 24)
        ..lineTo(17, 35)
        ..lineTo(10, 42)
        ..lineTo(19, 46)
        ..lineTo(12, 51)
        ..lineTo(22, 57)
        ..close(),
      fur,
      material: MzMaterial.fur,
      stroke: 2,
    );
  }
  _face(
    c,
    muse,
    fur,
    phase,
    sleepy: kind == MzCat.sunflower || heavy,
    determined: lean || heavy || kind == MzCat.laser,
    ice: kind == MzCat.ice,
    hurt: hurt,
    attack: attack,
    prepare: prepare,
    persona: heavy
        ? _FacePersona.cushion
        : kind == MzCat.launcher
        ? _FacePersona.hunter
        : _FacePersona.familiar,
  );
  if (kind == MzCat.launcher || kind == MzCat.boomerang) {
    mzArtShape(
      c,
      Path()
        ..moveTo(37, 20)
        ..cubicTo(35, 4, 55, 1, 65, 8)
        ..quadraticBezierTo(55, 20, 37, 20)
        ..close(),
      accent,
      stroke: 1.6,
    );
    mzArtLine(
      c,
      Path()
        ..moveTo(40, 17)
        ..quadraticBezierTo(49, 10, 59, 9),
      const Color(0xffd6e79f),
      1.2,
    );
  }
  if (armor) {
    mzArtShape(
      c,
      Path()
        ..moveTo(19, 27)
        ..lineTo(23, 12)
        ..lineTo(75, 9)
        ..lineTo(86, 28)
        ..close(),
      const Color(0xffa9b8bb),
      material: MzMaterial.metal,
    );
    mzArtBox(
      c,
      const Rect.fromLTWH(39, 8, 24, 5),
      const Color(0xffdbe8e4),
      radius: 2,
    );
  }
  c.restore();
  if (kind == MzCat.ice) {
    mzArtShape(
      c,
      Path()
        ..moveTo(23, 62)
        ..quadraticBezierTo(54, 72, 81, 63)
        ..lineTo(79, 73)
        ..quadraticBezierTo(51, 80, 25, 72)
        ..close(),
      const Color(0xff4c88ae),
      stroke: 1.7,
    );
    c.save();
    c.translate(69, 71);
    c.rotate(math.sin(phase * 2.4) * .07 + attack * .12);
    c.translate(-69, -71);
    mzArtShape(
      c,
      Path()
        ..moveTo(64, 72)
        ..lineTo(77, 70)
        ..lineTo(83, 92)
        ..lineTo(70, 93)
        ..close(),
      const Color(0xff71b8d3),
      stroke: 1.4,
    );
    mzArtLine(
      c,
      Path()
        ..moveTo(72, 87)
        ..lineTo(79, 85),
      MzArt.paper,
      1.6,
    );
    c.restore();
  } else if (kind == MzCat.laser) {
    mzArtBox(
      c,
      const Rect.fromLTWH(30, 65, 47, 21),
      const Color(0xff7d9997),
      radius: 8,
      material: MzMaterial.metal,
    );
    mzArtBox(
      c,
      const Rect.fromLTWH(69, 44, 27, 11),
      const Color(0xff58928d),
      material: MzMaterial.metal,
    );
    mzArtOval(
      c,
      const Rect.fromLTWH(87, 44, 8, 11),
      const Color(0xffaefff3),
      material: MzMaterial.ice,
    );
    mzArtBox(
      c,
      const Rect.fromLTWH(34, 34, 42, 7),
      const Color(0x9969ead8),
      radius: 3,
    );
  } else if (!heavy) {
    mzArtShape(
      c,
      Path()
        ..moveTo(33, 66)
        ..quadraticBezierTo(53, 75, 73, 66)
        ..lineTo(68, 74)
        ..quadraticBezierTo(50, 82, 35, 73)
        ..close(),
      accent,
      stroke: 1.4,
    );
    mzArtOval(c, const Rect.fromLTWH(48, 74, 9, 9), MzArt.gold, stroke: 1);
  }
  if (kind == MzCat.launcher) {
    _yarn(
      c,
      Offset(84 - attack * 4 - prepare * 4, 72 - prepare * 3),
      11,
      accent,
    );
    _paw(
      c,
      Rect.fromLTWH(70 - prepare * 3, 79 - prepare * 2 + attack * 2, 20, 10),
      MzArt.ladyFur,
    );
  } else if (kind == MzCat.boomerang) {
    _fish(
      c,
      Offset(82 - prepare * 5, 70 - prepare * 3),
      21,
      const Color(0xffe9c56b),
    );
    _paw(c, const Rect.fromLTWH(68, 78, 22, 10), MzArt.ladyFur);
  } else if (kind == MzCat.lightning) {
    _bolt(c, const Offset(53, 79), 12);
    mzArtShape(
      c,
      Path()
        ..moveTo(42, 23)
        ..lineTo(47, 4)
        ..lineTo(55, 17)
        ..lineTo(65, 8)
        ..lineTo(62, 27)
        ..close(),
      accent,
      stroke: 1.6,
    );
  } else if (kind == MzCat.bomb) {
    mzArtShape(
      c,
      Path()
        ..moveTo(21, 31)
        ..lineTo(12, 29)
        ..lineTo(18, 40)
        ..lineTo(9, 48)
        ..lineTo(21, 53)
        ..close(),
      accent,
      stroke: 2,
    );
  }
  if (heavy) {
    mzArtLine(
      c,
      Path()
        ..moveTo(40, 87)
        ..quadraticBezierTo(55, 93, 72, 87),
      MzArt.maruStripe,
      1.5,
    );
    if (armor) {
      mzArtBox(
        c,
        const Rect.fromLTWH(25, 74, 53, 17),
        const Color(0xffa6b5b2),
        radius: 7,
        material: MzMaterial.metal,
      );
    }
  }
  c.restore();
}

void _box(Canvas c, bool armed) {
  mzArtShape(
    c,
    Path()
      ..moveTo(15, 63)
      ..lineTo(49, 52)
      ..lineTo(88, 65)
      ..lineTo(87, 96)
      ..lineTo(15, 96)
      ..close(),
    MzArt.woodDark,
    stroke: 2.5,
  );
  mzArtShape(
    c,
    Path()
      ..moveTo(15, 63)
      ..lineTo(3, armed ? 50 : 67)
      ..lineTo(38, armed ? 41 : 59)
      ..lineTo(49, 52)
      ..close(),
    MzArt.woodLight,
    stroke: 1.7,
  );
  mzArtShape(
    c,
    Path()
      ..moveTo(49, 52)
      ..lineTo(77, armed ? 39 : 57)
      ..lineTo(99, armed ? 51 : 68)
      ..lineTo(88, 65)
      ..close(),
    MzArt.woodLight,
    stroke: 1.7,
  );
}

void _boxFront(Canvas c) {
  mzArtShape(
    c,
    Path()
      ..moveTo(15, 71)
      ..lineTo(48, 82)
      ..lineTo(88, 71)
      ..lineTo(87, 96)
      ..lineTo(49, 103)
      ..lineTo(15, 95)
      ..close(),
    MzArt.wood,
    stroke: 2.5,
  );
  mzArtLine(
    c,
    Path()
      ..moveTo(49, 82)
      ..lineTo(49, 100),
    MzArt.woodDark,
    1.4,
  );
  mzArtBox(
    c,
    const Rect.fromLTWH(28, 81, 8, 15),
    MzArt.paper,
    radius: 1,
    stroke: 0,
  );
}

void _catapultArm(Canvas c, double attack) {
  c.save();
  c.translate(54, 70);
  c.rotate(-.35 + attack * .65);
  mzArtBox(
    c,
    const Rect.fromLTWH(-4, -47, 8, 48),
    MzArt.wood,
    radius: 3,
    material: MzMaterial.wood,
  );
  mzArtOval(
    c,
    const Rect.fromLTWH(-13, -56, 27, 15),
    MzArt.woodDark,
    stroke: 2,
  );
  _yarn(c, const Offset(0, -53), 9, const Color(0xffdfac57));
  c.restore();
  mzArtOval(
    c,
    const Rect.fromLTWH(47, 66, 14, 13),
    MzArt.gold,
    material: MzMaterial.metal,
  );
}

void _yarn(Canvas c, Offset p, double radius, Color color) {
  c.save();
  c.translate(p.dx, p.dy);
  mzArtOval(
    c,
    Rect.fromCircle(center: Offset.zero, radius: radius),
    color,
    material: MzMaterial.fur,
  );
  for (var i = -1; i < 2; i++) {
    mzArtLine(
      c,
      Path()
        ..moveTo(-radius * .8, i * 4)
        ..quadraticBezierTo(0, -radius * .9 + i * 3, radius * .8, i * 4),
      Color.lerp(color, MzArt.ink, .3)!,
      1.1,
    );
  }
  c.restore();
}

void _fish(Canvas c, Offset p, double width, Color color) {
  c.save();
  c.translate(p.dx, p.dy);
  mzArtShape(
    c,
    Path()
      ..moveTo(-width * .45, 0)
      ..quadraticBezierTo(width * .1, -width * .5, width * .4, 0)
      ..quadraticBezierTo(width * .1, width * .5, -width * .45, 0)
      ..lineTo(-width * .65, -width * .25)
      ..lineTo(-width * .65, width * .25)
      ..close(),
    color,
    stroke: 1.3,
  );
  mzArtOval(
    c,
    Rect.fromCircle(center: Offset(width * .18, -1), radius: 1.6),
    MzArt.ink,
    stroke: 0,
  );
  c.restore();
}

void _bolt(Canvas c, Offset p, double radius) => mzArtShape(
  c,
  Path()
    ..moveTo(p.dx + 1, p.dy - radius)
    ..lineTo(p.dx - radius * .7, p.dy + 1)
    ..lineTo(p.dx - 1, p.dy + 1)
    ..lineTo(p.dx - 3, p.dy + radius)
    ..lineTo(p.dx + radius * .7, p.dy - 2)
    ..lineTo(p.dx + 2, p.dy - 2)
    ..close(),
  const Color(0xffffe581),
  stroke: 1.2,
);
void _spark(Canvas c, Offset p, double radius) {
  for (var i = 0; i < 5; i++) {
    final a = i * math.pi * 2 / 5;
    mzArtLine(
      c,
      Path()
        ..moveTo(
          p.dx + math.cos(a) * radius * .6,
          p.dy + math.sin(a) * radius * .6,
        )
        ..lineTo(
          p.dx + math.cos(a) * radius * 1.4,
          p.dy + math.sin(a) * radius * 1.4,
        ),
      const Color(0xfff5bd48),
      1.6,
    );
  }
}

void _invader(
  Canvas c,
  MzEnemy kind,
  double phase,
  bool armor,
  double hurt,
  bool walking, {
  double attack = 0,
  double performance = 0,
}) {
  if (_featuredInvader(
    c,
    kind,
    phase,
    armor,
    hurt,
    walking,
    attack,
    performance,
  )) {
    return;
  }
  final dog = [
    MzEnemy.cone,
    MzEnemy.pharaoh,
    MzEnemy.cannon,
    MzEnemy.shield,
  ].contains(kind);
  final muse =
      [
        MzEnemy.bucket,
        MzEnemy.thief,
        MzEnemy.corsair,
        MzEnemy.parrot,
        MzEnemy.miner,
      ].contains(kind)
      ? MzMuse.lady
      : MzMuse.maru;
  final robot = kind == MzEnemy.mecha || kind == MzEnemy.shield;
  final fur = Color.lerp(
    muse == MzMuse.maru ? MzArt.maruFur : MzArt.ladyFur,
    robot ? const Color(0xff718e8e) : const Color(0xff80a187),
    .42,
  )!;
  final walk = walking ? math.sin(phase * 5.5) : 0.0;
  // Zombimaru slouches even at rest; the gait is visual and uses game time.
  if (kind == MzEnemy.common) {
    c.translate(50, 98);
    c.rotate(-.055 + walk * .018);
    c.translate(-50, -98);
  }
  _tail(c, muse, fur, phase, low: kind == MzEnemy.thief, ragged: true);
  if (kind == MzEnemy.parrot) {
    for (final side in [-1.0, 1.0]) {
      c.save();
      c.translate(50, 62);
      c.scale(side, 1);
      c.rotate(walk * .13);
      mzArtShape(
        c,
        Path()
          ..moveTo(15, 5)
          ..quadraticBezierTo(43, -31, 48, -9)
          ..lineTo(41, -5)
          ..lineTo(46, 3)
          ..lineTo(36, 5)
          ..lineTo(38, 13)
          ..quadraticBezierTo(19, 23, 15, 5)
          ..close(),
        const Color(0xff7291a2),
        stroke: 2,
      );
      c.restore();
    }
  }
  c.save();
  c.translate(0, kind == MzEnemy.parrot ? -7 + walk * 2 : 0);
  final slender = [
    MzEnemy.common,
    MzEnemy.flag,
    MzEnemy.mummy,
    MzEnemy.miner,
  ].contains(kind);
  c.save();
  if (slender) {
    c.translate(10, -1);
    c.scale(.85, 1.02);
  }
  _body(
    c,
    muse,
    fur,
    heavy:
        kind == MzEnemy.pharaoh ||
        kind == MzEnemy.cannon ||
        kind == MzEnemy.bucket,
    lean: kind == MzEnemy.thief || slender,
    zombie: true,
  );
  c.restore();
  // Torn clothes separate the invasion palette from the lawn.
  if (!robot) {
    mzArtShape(
      c,
      Path()
        ..moveTo(29, 62)
        ..lineTo(45, 58)
        ..lineTo(53, 67)
        ..lineTo(63, 57)
        ..lineTo(79, 64)
        ..lineTo(83, 85)
        ..lineTo(74, 81)
        ..lineTo(66, 90)
        ..lineTo(53, 86)
        ..lineTo(39, 91)
        ..lineTo(30, 85)
        ..close(),
      kind == MzEnemy.thief
          ? const Color(0xff6d527a)
          : kind == MzEnemy.mummy || kind == MzEnemy.pharaoh
          ? const Color(0xffb9ac82)
          : const Color(0xff746178),
      stroke: 2,
    );
    mzArtLine(
      c,
      Path()
        ..moveTo(46, 68)
        ..lineTo(50, 80)
        ..lineTo(55, 71),
      const Color(0xffad93a0),
      1.3,
    );
  } else {
    mzArtBox(
      c,
      const Rect.fromLTWH(25, 63, 57, 28),
      const Color(0xff789793),
      radius: 8,
      material: MzMaterial.metal,
    );
    _bolt(c, const Offset(56, 77), 9);
  }
  _paw(c, Rect.fromLTWH(25, 86 + walk * 1.5, 23, 11), fur, claws: true);
  _paw(c, Rect.fromLTWH(65, 86 - walk * 1.5, 24, 12), fur, claws: true);
  c.save();
  c.translate(52, 54);
  if (kind == MzEnemy.thief) c.translate(0, 3);
  c.rotate(
    (walking ? walk : 0) * (robot ? .02 : .055) +
        (kind == MzEnemy.common ? .10 : .025) -
        attack * .035,
  );
  c.translate(-52, -54);
  _face(
    c,
    muse,
    fur,
    phase,
    zombie: true,
    dog: dog,
    hurt: hurt,
    attack: attack,
    persona: kind == MzEnemy.common
        ? _FacePersona.crooked
        : _FacePersona.familiar,
  );
  _enemyHeadGear(c, kind, armor);
  c.restore();
  if (slender && kind != MzEnemy.mummy) {
    mzArtShape(
      c,
      Path()
        ..moveTo(65, 71)
        ..quadraticBezierTo(73, 64, 85, 69)
        ..lineTo(88, 76)
        ..lineTo(80, 80)
        ..lineTo(67, 80)
        ..close(),
      const Color(0xff746178),
      stroke: 1.7,
    );
    _paw(c, Rect.fromLTWH(82, 69 + walk, 14, 10), fur, claws: true);
  }
  _enemyEquipment(c, kind, armor, walk);
  c.restore();
}

void _enemyHeadGear(Canvas c, MzEnemy kind, bool armor) {
  if (kind == MzEnemy.bucket && armor) {
    mzArtShape(
      c,
      Path()
        ..moveTo(22, 30)
        ..lineTo(24, 4)
        ..lineTo(76, 4)
        ..lineTo(82, 31)
        ..quadraticBezierTo(50, 35, 22, 30)
        ..close(),
      const Color(0xff9ea9a1),
      material: MzMaterial.metal,
    );
    mzArtOval(
      c,
      const Rect.fromLTWH(24, 0, 52, 10),
      const Color(0xffdce1cc),
      stroke: 1.5,
    );
    mzArtLine(
      c,
      Path()
        ..moveTo(33, 12)
        ..lineTo(40, 16)
        ..lineTo(34, 21)
        ..moveTo(64, 22)
        ..lineTo(70, 26),
      const Color(0xff9b7150),
      2.3,
    );
  } else if (kind == MzEnemy.mummy || kind == MzEnemy.pharaoh) {
    if (kind == MzEnemy.pharaoh) {
      mzArtShape(
        c,
        Path()
          ..moveTo(23, 27)
          ..lineTo(29, 10)
          ..lineTo(70, 7)
          ..lineTo(86, 25)
          ..lineTo(94, 68)
          ..lineTo(77, 68)
          ..lineTo(69, 28)
          ..lineTo(40, 28)
          ..lineTo(28, 68)
          ..lineTo(11, 64)
          ..close(),
        MzArt.gold,
        stroke: 2,
      );
      for (var i = 0; i < 4; i++) {
        mzArtLine(
          c,
          Path()
            ..moveTo(16 + i * 2, 35 + i * 8)
            ..lineTo(29 + i * 2, 35 + i * 8)
            ..moveTo(78, 36 + i * 8)
            ..lineTo(87.0 + i, 36.0 + i * 8),
          const Color(0xff547e8c),
          3,
        );
      }
    } else {
      mzArtShape(
        c,
        Path()
          ..moveTo(23, 23)
          ..lineTo(81, 26)
          ..lineTo(82, 32)
          ..lineTo(23, 29)
          ..close(),
        const Color(0xffeee0ba),
        stroke: 1,
      );
      mzArtShape(
        c,
        Path()
          ..moveTo(25, 55)
          ..lineTo(82, 53)
          ..lineTo(78, 60)
          ..lineTo(30, 64)
          ..close(),
        const Color(0xffeee0ba),
        stroke: 1,
      );
    }
  } else if (kind == MzEnemy.corsair) {
    mzArtShape(
      c,
      Path()
        ..moveTo(17, 27)
        ..lineTo(31, 5)
        ..lineTo(50, 12)
        ..lineTo(73, 4)
        ..lineTo(88, 27)
        ..quadraticBezierTo(51, 37, 17, 27)
        ..close(),
      const Color(0xff4c4c65),
      stroke: 2.5,
    );
    _fish(c, const Offset(53, 21), 16, MzArt.paper);
    mzArtOval(c, const Rect.fromLTWH(28, 33, 18, 15), const Color(0xff34352f));
  } else if (kind == MzEnemy.miner) {
    mzArtShape(
      c,
      Path()
        ..moveTo(24, 27)
        ..quadraticBezierTo(21, 4, 53, 5)
        ..quadraticBezierTo(81, 4, 84, 28)
        ..close(),
      MzArt.gold,
      material: MzMaterial.metal,
    );
    mzArtBox(
      c,
      const Rect.fromLTWH(19, 26, 69, 6),
      const Color(0xffaa8444),
      radius: 2,
    );
    mzArtOval(
      c,
      const Rect.fromLTWH(56, 12, 16, 15),
      MzArt.paper,
      material: MzMaterial.metal,
    );
  } else if (kind == MzEnemy.thief) {
    mzArtShape(
      c,
      Path()
        ..moveTo(18, 35)
        ..quadraticBezierTo(14, 7, 47, 3)
        ..quadraticBezierTo(79, 5, 85, 37)
        ..lineTo(78, 39)
        ..quadraticBezierTo(73, 20, 47, 22)
        ..quadraticBezierTo(30, 22, 26, 41)
        ..close(),
      const Color(0xff756080),
      stroke: 2,
    );
  } else if (kind == MzEnemy.mecha || kind == MzEnemy.shield) {
    mzArtShape(
      c,
      Path()
        ..moveTo(22, 30)
        ..lineTo(27, 7)
        ..lineTo(72, 8)
        ..lineTo(85, 33)
        ..lineTo(78, 37)
        ..lineTo(68, 26)
        ..lineTo(36, 27)
        ..lineTo(30, 36)
        ..close(),
      const Color(0xff8babaa),
      material: MzMaterial.metal,
    );
    mzArtBox(
      c,
      const Rect.fromLTWH(32, 37, 42, 7),
      const Color(0x887be3ce),
      radius: 2,
    );
  } else if (kind == MzEnemy.pianist) {
    mzArtBox(
      c,
      const Rect.fromLTWH(32, 4, 40, 20),
      const Color(0xff82556c),
      radius: 5,
    );
    mzArtBox(
      c,
      const Rect.fromLTWH(19, 21, 65, 5),
      const Color(0xff633f55),
      radius: 3,
    );
  }
}

void _enemyEquipment(Canvas c, MzEnemy kind, bool armor, double walk) {
  if (kind == MzEnemy.cone && armor) {
    mzArtShape(
      c,
      Path()
        ..moveTo(20, 35)
        ..lineTo(91, 30)
        ..lineTo(84, 71)
        ..lineTo(34, 74)
        ..close(),
      const Color(0x668fdfe4),
      stroke: 2,
    );
    mzArtOval(
      c,
      const Rect.fromLTWH(37, 57, 38, 11),
      const Color(0x66e8fcf5),
      stroke: 1.3,
    );
  } else if (kind == MzEnemy.flag) {
    mzArtLine(
      c,
      Path()
        ..moveTo(13, 98)
        ..lineTo(7, 9),
      MzArt.woodDark,
      3,
    );
    mzArtShape(
      c,
      Path()
        ..moveTo(7, 10)
        ..quadraticBezierTo(27, 2 + walk * 3, 41, 12 + walk * 4)
        ..lineTo(40, 35 + walk * 3)
        ..quadraticBezierTo(23, 27 - walk * 2, 8, 34)
        ..close(),
      const Color(0xffbc625d),
      stroke: 1.5,
    );
    _fish(c, Offset(24, 22 + walk * 1.5), 22, MzArt.paper);
  } else if (kind == MzEnemy.thief) {
    mzArtShape(
      c,
      Path()
        ..moveTo(10, 65)
        ..quadraticBezierTo(-4, 89, 13, 96)
        ..quadraticBezierTo(33, 98, 30, 77)
        ..lineTo(22, 64)
        ..close(),
      const Color(0xffb9a27d),
      stroke: 2,
    );
    mzArtLine(
      c,
      Path()
        ..moveTo(10, 70)
        ..lineTo(25, 70),
      MzArt.woodDark,
      1.5,
    );
    _leaf(c, const Offset(15, 83), 10);
  } else if (kind == MzEnemy.pharaoh && armor) {
    mzArtShape(
      c,
      Path()
        ..moveTo(67, 45)
        ..lineTo(88, 45)
        ..lineTo(97, 61)
        ..lineTo(93, 99)
        ..lineTo(63, 99)
        ..lineTo(59, 60)
        ..close(),
      const Color(0xffd8b252),
      material: MzMaterial.metal,
    );
    mzArtLine(
      c,
      Path()
        ..moveTo(66, 68)
        ..lineTo(89, 68)
        ..moveTo(66, 80)
        ..lineTo(90, 80),
      const Color(0xff587d88),
      3,
    );
  } else if (kind == MzEnemy.cannon) {
    mzArtOval(c, const Rect.fromLTWH(22, 80, 19, 19), MzArt.woodDark);
    mzArtOval(c, const Rect.fromLTWH(63, 80, 19, 19), MzArt.woodDark);
    mzArtBox(c, const Rect.fromLTWH(28, 72, 49, 14), MzArt.wood, radius: 3);
    mzArtShape(
      c,
      Path()
        ..moveTo(40, 59)
        ..lineTo(91, 53)
        ..lineTo(98, 72)
        ..lineTo(45, 78)
        ..close(),
      const Color(0xff859792),
      material: MzMaterial.metal,
    );
    mzArtOval(
      c,
      const Rect.fromLTWH(89, 52, 12, 22),
      const Color(0xff36443f),
      stroke: 2,
    );
  } else if (kind == MzEnemy.pianist) {
    mzArtBox(
      c,
      const Rect.fromLTWH(13, 73, 78, 21),
      const Color(0xff745241),
      radius: 3,
    );
    mzArtBox(
      c,
      const Rect.fromLTWH(17, 75, 70, 11),
      MzArt.paper,
      radius: 1,
      stroke: 1,
    );
    for (var i = 0; i < 9; i++) {
      mzArtLine(
        c,
        Path()
          ..moveTo(19 + i * 8.0, 76)
          ..lineTo(19 + i * 8.0, 85),
        MzArt.ink,
        .8,
      );
      if (i % 3 != 0) {
        mzArtBox(
          c,
          Rect.fromLTWH(24 + i * 7.0, 75, 3, 6),
          MzArt.ink,
          radius: 0,
          stroke: 0,
        );
      }
    }
    _paw(c, Rect.fromLTWH(33, 69 + walk, 18, 9), MzArt.maruChest);
  } else if (kind == MzEnemy.miner) {
    mzArtLine(
      c,
      Path()
        ..moveTo(75, 97)
        ..lineTo(89, 58),
      MzArt.woodDark,
      4,
    );
    mzArtShape(
      c,
      Path()
        ..moveTo(76, 58)
        ..quadraticBezierTo(87, 46, 103, 56)
        ..lineTo(94, 56)
        ..lineTo(91, 64)
        ..lineTo(87, 56)
        ..close(),
      const Color(0xffa9b8af),
      material: MzMaterial.metal,
      stroke: 1.5,
    );
  } else if (kind == MzEnemy.mummy) {
    for (var i = 0; i < 4; i++) {
      mzArtLine(
        c,
        Path()
          ..moveTo(30, 66 + i * 6.0)
          ..lineTo(80, 71 + i * 6.0),
        const Color(0xffe6d7b2),
        3.5,
      );
    }
  }
  if (kind == MzEnemy.shield && armor) {
    final hex = Path();
    for (var i = 0; i < 6; i++) {
      final a = i * math.pi / 3;
      final p = Offset(55 + math.cos(a) * 49, 53 + math.sin(a) * 48);
      if (i == 0) {
        hex.moveTo(p.dx, p.dy);
      } else {
        hex.lineTo(p.dx, p.dy);
      }
    }
    hex.close();
    mzArtShape(c, hex, const Color(0x225cf4db), stroke: 0);
    mzArtLine(c, hex, const Color(0xff85ddd1), 2);
  }
}

void _leaf(Canvas c, Offset p, double radius) => mzArtShape(
  c,
  Path()
    ..moveTo(p.dx - radius, p.dy + radius * .5)
    ..quadraticBezierTo(
      p.dx - radius,
      p.dy - radius,
      p.dx + radius,
      p.dy - radius * .5,
    )
    ..quadraticBezierTo(
      p.dx + radius,
      p.dy + radius,
      p.dx - radius,
      p.dy + radius * .5,
    )
    ..close(),
  const Color(0xff78b650),
  stroke: 1.2,
);

void _boss(Canvas c, double phase, double hurt) {
  // Bulldog chassis and the small Maru scientist share the same material rules.
  mzArtShape(
    c,
    Path()
      ..moveTo(15, 49)
      ..lineTo(12, 88)
      ..lineTo(27, 96)
      ..lineTo(80, 97)
      ..lineTo(91, 82)
      ..lineTo(86, 45)
      ..close(),
    const Color(0xff718b88),
    material: MzMaterial.metal,
  );
  for (final x in [15.0, 70.0]) {
    mzArtBox(
      c,
      Rect.fromLTWH(x, 88, 19, 13),
      const Color(0xff4b6463),
      radius: 4,
      material: MzMaterial.metal,
    );
  }
  mzArtBox(
    c,
    const Rect.fromLTWH(12, 24, 76, 49),
    const Color(0xffaab9a9),
    radius: 18,
    material: MzMaterial.metal,
    stroke: 3,
  );
  mzArtOval(c, const Rect.fromLTWH(4, 22, 15, 35), const Color(0xff657b74));
  mzArtOval(c, const Rect.fromLTWH(82, 22, 15, 35), const Color(0xff657b74));
  for (final x in [12.0, 88.0]) {
    c.save();
    c.translate(x, 42);
    c.rotate(phase * (x < 50 ? 1 : -1));
    mzArtOval(
      c,
      const Rect.fromLTWH(-4, -4, 8, 8),
      const Color(0xffd1c99c),
      stroke: 1,
    );
    mzArtLine(
      c,
      Path()
        ..moveTo(-4, 0)
        ..lineTo(4, 0)
        ..moveTo(0, -4)
        ..lineTo(0, 4),
      const Color(0xff485c54),
      1,
    );
    c.restore();
  }
  for (final x in [25.0, 61.0]) {
    mzArtBox(
      c,
      Rect.fromLTWH(x, 35, 16, 13),
      const Color(0xfff4db87),
      radius: 4,
      material: MzMaterial.ice,
    );
  }
  mzArtBox(
    c,
    const Rect.fromLTWH(28, 50, 44, 20),
    const Color(0xff61766b),
    radius: 8,
  );
  mzArtOval(c, const Rect.fromLTWH(43, 48, 17, 10), const Color(0xff384b43));
  mzArtLine(
    c,
    Path()
      ..moveTo(38, 61)
      ..lineTo(65, 61),
    MzArt.ink,
    2,
  );
  for (final x in [37.0, 61.0]) {
    mzArtShape(
      c,
      Path()
        ..moveTo(x, 61)
        ..lineTo(x + 4, 61)
        ..lineTo(x + 2, 66)
        ..close(),
      MzArt.paper,
      stroke: .8,
    );
  }
  mzArtBox(
    c,
    const Rect.fromLTWH(33, 72, 35, 13),
    const Color(0xff4f8178),
    radius: 4,
  );
  for (var i = 0; i < 4; i++) {
    mzArtLine(
      c,
      Path()
        ..moveTo(39 + i * 7.0, 75)
        ..lineTo(39 + i * 7.0, 82),
      const Color(0xffa7d8c3),
      2,
    );
  }
  c.save();
  c.translate(27, -4);
  c.scale(.43);
  _body(c, MzMuse.maru, MzArt.maruFur, zombie: true);
  mzArtBox(c, const Rect.fromLTWH(30, 59, 49, 28), MzArt.paper, radius: 7);
  _face(
    c,
    MzMuse.maru,
    const Color(0xff9baa91),
    phase,
    zombie: true,
    hurt: hurt,
  );
  mzArtOval(c, const Rect.fromLTWH(29, 33, 20, 16), const Color(0x556fcbd2));
  mzArtOval(c, const Rect.fromLTWH(57, 32, 22, 17), const Color(0x556fcbd2));
  c.restore();
}
