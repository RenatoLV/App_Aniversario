import 'package:flutter/material.dart';
import 'mz_catalog.dart';

/// Local artwork is 100 × 110. Exterior / interior / face strokes are distinct.
abstract final class MzArt {
  static const ink = Color(0xff30382f);
  static const outer = 3.0, inner = 1.8, detail = 1.2;
  static const paper = Color(0xfffff3d5), gold = Color(0xffffc452);
  static const woodLight = Color(0xffe9b967), wood = Color(0xffb7793f);
  static const woodDark = Color(0xff704326), frame = Color(0xff47291d);
  static const grass = Color(0xff58a442), grassLight = Color(0xff79bb4e);
  static const grassDark = Color(0xff3b8538), earth = Color(0xff795638);
  // Maru and Lady's markings come from cat_character.dart, with thematic accents.
  static const maruFur = Color(0xff797565), maruStripe = Color(0xff2b302b);
  static const maruChest = Color(0xffd2c3a5), maruEyes = Color(0xffc8ce7d);
  static const ladyFur = Color(0xfffbf7ee), ladyMask = Color(0xff4b4745);
  static const ladyCrown = Color(0xffe4bc86), ladyEyes = Color(0xffc6a05c);
  static const pink = Color(0xffe5a0a8);
  static const contact = Color(0xff465267), rim = Color(0xffffefd1);
  static const anticipationSeconds = .18;
  static const attackSeconds = .24, hurtSeconds = .20;
  static const maxVisualEvents = 32, maxTrailSamples = 5, maxTrails = 48;
  static const accents = [
    Color(0xff66ac41),
    Color(0xfff3b941),
    Color(0xffb98651),
    Color(0xff73cde8),
    Color(0xffc89d61),
    Color(0xffe75e56),
    Color(0xffdaac62),
    Color(0xffdeb94f),
    Color(0xff9b89c5),
    Color(0xffffd25b),
    Color(0xff67c6c9),
  ];
  static Color accent(MzCat cat) => accents[cat.index];
}

enum MzMuse { maru, lady }

enum MzMaterial { flat, fur, metal, ice, wood }

enum MzExpression { neutral, content, focused, attacking, hurt, dazed }

MzExpression mzExpression({
  bool sleepy = false,
  bool focused = false,
  bool zombie = false,
  double attack = 0,
  double hurt = 0,
}) => hurt > .15
    ? MzExpression.hurt
    : attack > .2
    ? MzExpression.attacking
    : zombie
    ? MzExpression.dazed
    : sleepy
    ? MzExpression.content
    : focused
    ? MzExpression.focused
    : MzExpression.neutral;

// Bound-sized geometry is reused by the head, body, tail and paws.
final _volumeGeometry = <Rect, (Path, Path, Path)>{};

/// Cel shading follows the same upper-left light on every material/character.
/// Clipping keeps markings intact; no blur or offscreen compositing is needed.
void mzArtVolume(Canvas c, Path silhouette, {double strength = 1}) {
  final b = silhouette.getBounds();
  final paths = _volumeGeometry.putIfAbsent(b, () {
    // A mixed battlefield now has more than 64 layered silhouettes. Keep a
    // bounded working set rather than rebuilding it on every character pass.
    if (_volumeGeometry.length >= 256) _volumeGeometry.clear();
    final x = b.left, y = b.top, w = b.width, h = b.height;
    return (
      Path()
        ..moveTo(x + w * .83, y - 1)
        ..cubicTo(
          x + w * .9,
          y + h * .5,
          x + w * .56,
          y + h * .74,
          x - 1,
          y + h * .73,
        )
        ..lineTo(x - 1, b.bottom + 1)
        ..lineTo(b.right + 1, b.bottom + 1)
        ..lineTo(b.right + 1, y - 1)
        ..close(),
      Path()
        ..moveTo(x - 1, y + h * .92)
        ..quadraticBezierTo(x + w * .55, y + h * .75, b.right + 1, y + h * .83)
        ..lineTo(b.right + 1, b.bottom + 1)
        ..lineTo(x - 1, b.bottom + 1)
        ..close(),
      Path()
        ..moveTo(x + w * .12, y + h * .35)
        ..cubicTo(
          x + w * .2,
          y + h * .06,
          x + w * .52,
          y + h * .01,
          x + w * .67,
          y + h * .14,
        )
        ..cubicTo(
          x + w * .4,
          y + h * .1,
          x + w * .22,
          y + h * .2,
          x + w * .12,
          y + h * .35,
        )
        ..close(),
    );
  });
  c.save();
  c.clipPath(silhouette);
  c.drawPath(
    paths.$1,
    Paint()..color = MzArt.contact.withValues(alpha: .15 * strength),
  );
  c.drawPath(
    paths.$2,
    Paint()..color = MzArt.contact.withValues(alpha: .10 * strength),
  );
  c.drawPath(
    paths.$3,
    Paint()..color = MzArt.rim.withValues(alpha: .30 * strength),
  );
  c.restore();
}

/// The resource emblem is shared by pickups, the counter and collection flights.
void mzPaintCatnip(Canvas c, Offset center, double diameter) {
  c.save();
  c.translate(center.dx - diameter / 2, center.dy - diameter / 2);
  c.scale(diameter / 40);
  mzArtOval(
    c,
    const Rect.fromLTWH(2, 2, 36, 36),
    MzArt.gold,
    stroke: 1.8,
    material: MzMaterial.metal,
  );
  mzArtOval(
    c,
    const Rect.fromLTWH(5, 5, 30, 30),
    const Color(0xffffe995),
    stroke: 0,
  );
  mzArtShape(
    c,
    Path()
      ..moveTo(12, 28)
      ..cubicTo(5, 12, 21, 10, 30, 9)
      ..cubicTo(32, 24, 24, 33, 12, 28)
      ..close(),
    const Color(0xff60a94c),
    stroke: 1.5,
  );
  mzArtLine(
    c,
    Path()
      ..moveTo(10, 31)
      ..lineTo(26, 14)
      ..moveTo(16, 25)
      ..lineTo(16, 17)
      ..moveTo(20, 21)
      ..lineTo(27, 21),
    const Color(0xffd6ef91),
    1.8,
  );
  c.restore();
}

final _materialPaints = <(Color, Rect, MzMaterial), Paint>{};

Paint mzArtFill(Color color, Rect bounds, MzMaterial material) {
  if (material == MzMaterial.flat || bounds.shortestSide < 5 || color.a < .99) {
    return Paint()..color = color;
  }
  final key = (color, bounds, material);
  final cached = _materialPaints[key];
  if (cached != null) return cached;
  final paint = Paint()..color = color;
  if (_materialPaints.length >= 512) {
    _materialPaints.remove(_materialPaints.keys.first);
  }
  final light = Color.lerp(
    color,
    Colors.white,
    material == MzMaterial.ice ? .45 : .2,
  )!;
  final shade = Color.lerp(color, MzArt.ink, .22)!;
  if (material == MzMaterial.fur) {
    paint.shader = RadialGradient(
      center: const Alignment(-.5, -.6),
      radius: 1.25,
      colors: [light, color, shade],
      stops: const [0, .58, 1],
    ).createShader(bounds);
  } else {
    paint.shader = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: material == MzMaterial.metal
          ? [shade, light, color, light, shade]
          : [light, color, shade],
      stops: material == MzMaterial.metal ? const [0, .2, .35, .55, 1] : null,
    ).createShader(bounds);
  }
  _materialPaints[key] = paint;
  return paint;
}

void mzArtShape(
  Canvas c,
  Path path,
  Color color, {
  double stroke = MzArt.outer,
  MzMaterial material = MzMaterial.flat,
}) {
  c.drawPath(path, mzArtFill(color, path.getBounds(), material));
  if (stroke > 0) {
    c.drawPath(
      path,
      Paint()
        ..color = MzArt.ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
  }
}

void mzArtOval(
  Canvas c,
  Rect bounds,
  Color color, {
  double stroke = MzArt.inner,
  MzMaterial material = MzMaterial.flat,
}) {
  c.drawOval(bounds, mzArtFill(color, bounds, material));
  if (stroke > 0) {
    c.drawOval(
      bounds,
      Paint()
        ..color = MzArt.ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke,
    );
  }
}

void mzArtLine(
  Canvas c,
  Path path,
  Color color, [
  double width = MzArt.detail,
]) {
  c.drawPath(
    path,
    Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round,
  );
}

void mzArtBox(
  Canvas c,
  Rect bounds,
  Color color, {
  double radius = 4,
  double stroke = MzArt.inner,
  MzMaterial material = MzMaterial.flat,
}) => mzArtShape(
  c,
  Path()..addRRect(RRect.fromRectAndRadius(bounds, Radius.circular(radius))),
  color,
  stroke: stroke,
  material: material,
);
