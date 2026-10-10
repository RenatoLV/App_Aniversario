import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'mz_art_style.dart';
import 'mz_world_art.dart';

final _tombFace = Path()
  ..moveTo(18, 82)
  ..lineTo(18, 36)
  ..cubicTo(18, 0, 77, 0, 77, 36)
  ..lineTo(77, 82)
  ..close();
final _tombEdge = Path()
  ..moveTo(65, 13)
  ..quadraticBezierTo(86, 20, 86, 41)
  ..lineTo(86, 84)
  ..lineTo(77, 89)
  ..lineTo(77, 36)
  ..quadraticBezierTo(76, 21, 65, 13)
  ..close();

final _tombInscription = Path()
  // R, I, P are carved vector strokes, independent of installed fonts.
  ..moveTo(31, 47)
  ..lineTo(31, 29)
  ..lineTo(38, 29)
  ..cubicTo(47, 29, 47, 39, 38, 39)
  ..lineTo(31, 39)
  ..moveTo(38, 39)
  ..lineTo(44, 47)
  ..moveTo(50, 29)
  ..lineTo(56, 29)
  ..moveTo(53, 29)
  ..lineTo(53, 47)
  ..moveTo(50, 47)
  ..lineTo(56, 47)
  ..moveTo(63, 47)
  ..lineTo(63, 29)
  ..lineTo(69, 29)
  ..cubicTo(77, 29, 77, 39, 69, 39)
  ..lineTo(63, 39);

/// Upright stone headstone, distinct from the low decorative dunes.
/// All geometry stays inside the existing tomb footprint.
void mzPaintTomb(Canvas c, Rect footprint) {
  c.save();
  c.translate(footprint.left, footprint.top);
  c.scale(footprint.width / 100, footprint.height / 100);
  c.drawOval(
    const Rect.fromLTWH(10, 86, 83, 12),
    Paint()..color = const Color(0x384c4030),
  );
  mzArtBox(
    c,
    const Rect.fromLTWH(12, 83, 77, 11),
    const Color(0xff858d86),
    radius: 3,
  );
  mzArtShape(c, _tombEdge, const Color(0xff737c77), stroke: 2);
  mzArtShape(
    c,
    _tombFace,
    const Color(0xffb8beb3),
    stroke: 2.5,
    material: MzMaterial.wood,
  );
  mzArtLine(
    c,
    Path()
      ..moveTo(24, 77)
      ..lineTo(24, 36)
      ..cubicTo(24, 9, 70, 9, 70, 36),
    const Color(0xffe2e5d9),
    2,
  );
  mzArtLine(
    c,
    Path()
      ..moveTo(27, 78)
      ..lineTo(68, 78),
    const Color(0xff89948b),
    1.5,
  );
  c.save();
  // Fit the inscription inside the inner arch, centered on the stone face.
  c.translate(47.5, 38);
  c.scale(.8, .9);
  c.translate(-53, -38);
  c.save();
  c.translate(1, 1);
  mzArtLine(c, _tombInscription, const Color(0xffdfe3d8), 3);
  c.restore();
  mzArtLine(c, _tombInscription, const Color(0xff5b6860), 3);
  c.restore();
  final engraving = Paint()..color = const Color(0xff89958b);
  c.drawOval(const Rect.fromLTWH(42, 63, 13, 9), engraving);
  for (final toe in const [
    Rect.fromLTWH(37, 58, 5, 6),
    Rect.fromLTWH(43, 53, 5, 7),
    Rect.fromLTWH(50, 53, 5, 7),
    Rect.fromLTWH(56, 58, 5, 6),
  ]) {
    c.drawOval(toe, engraving);
  }
  mzArtLine(
    c,
    Path()
      ..moveTo(68, 62)
      ..lineTo(63, 67)
      ..lineTo(67, 71),
    const Color(0xff7b8980),
    1.2,
  );
  mzArtLine(
    c,
    Path()
      ..moveTo(17, 85)
      ..lineTo(82, 85),
    const Color(0xffd1d8c9),
    1.5,
  );
  c.restore();
}

/// Decorative service aisle; combat coordinates remain on the original lawn.
class MzServiceAisle {
  MzServiceAisle(this.lawn);
  final Rect lawn;
  double get houseSpan => lawn.left * .66;
  double get left => lawn.left * .65;
  double get right => lawn.left - 2;
  double get center => (left + right) / 2;
  double get robotSize => math.min((right - left) * .8, lawn.height / 5 * .78);

  Offset robotPosition(int row, double? travel) {
    // The simulation starts at -.8. Map that entry segment onto the aisle
    // so activation begins at the dock instead of jumping through the wall.
    final x = travel == null
        ? center
        : travel < 0
        ? ui.lerpDouble(center, lawn.left, ((travel + .8) / .8).clamp(0, 1))!
        : lawn.left + travel * lawn.width / 9;
    return Offset(x, lawn.top + (row + .5) * lawn.height / 5);
  }
}

/// Cached scenery avoids rebuilding static grass and props on every combat tick.
/// Two pictures preserve the existing background/entity/foreground paint order.
class MzSceneryCache {
  /// Diagnostics only: two scene pictures at most, regardless of navigation.
  int get pictureCount => (_back == null ? 0 : 1) + (_front == null ? 0 : 1);
  ui.Picture? _back, _front;
  Size? _size;
  Rect? _board;
  int? _world;
  void _prepare(Size size, Rect board, int world) {
    if (_size == size && _board == board && _world == world) return;
    dispose();
    _size = size;
    _board = board;
    _world = world;
    final back = ui.PictureRecorder(), front = ui.PictureRecorder();
    final bc = Canvas(back)..clipRect(Offset.zero & size);
    mzPaintGarden(bc, size, board, world);
    if (world == 0) {
      mzPaintLawn(bc, board);
    } else {
      mzPaintWorldGround(bc, board, world);
    }
    mzPaintAmbientLight(bc, size, board, world);
    _back = back.endRecording();
    final fc = Canvas(front)..clipRect(Offset.zero & size);
    if (world == 0) {
      mzPaintHedges(fc, size, board);
    }
    _front = front.endRecording();
  }

  void background(Canvas c, Size size, Rect board, int world) {
    _prepare(size, board, world);
    c.drawPicture(_back!);
  }

  void foreground(Canvas c, Size size, Rect board, int world) {
    _prepare(size, board, world);
    c.drawPicture(_front!);
  }

  void dispose() {
    _back?.dispose();
    _front?.dispose();
    _back = null;
    _front = null;
    _size = null;
    _board = null;
    _world = null;
  }
}

void mzPaintGarden(Canvas c, Size size, Rect lawn, int world) {
  if (world != 0) {
    mzPaintWorldBackdrop(c, size, lawn, world);
    return;
  }
  final full = Offset.zero & size;
  c.drawRect(
    full,
    Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: world == 4
            ? const [Color(0xff667d9e), Color(0xffcad7e3)]
            : const [Color(0xff64b7d6), Color(0xffcee8d6)],
      ).createShader(full),
  );
  _distance(c, size, lawn);
  final earth = Rect.fromLTRB(0, lawn.top * .7, size.width, size.height);
  c.drawRect(
    earth,
    Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: world == 4
            ? const [Color(0xff8d9ba4), Color(0xff617381)]
            : const [Color(0xffb18b5e), Color(0xffd9b887)],
      ).createShader(earth),
  );
  _fence(c, size, lawn);
  _house(c, size, lawn);
  _path(c, size, lawn);
  mzPaintWorldArchitecture(c, size, lawn, world);
  // Soil extrusion lies outside the unchanged logical cells.
  mzArtShape(
    c,
    Path()
      ..moveTo(lawn.left - 3, lawn.bottom)
      ..lineTo(lawn.right + 3, lawn.bottom)
      ..lineTo(lawn.right + 2, lawn.bottom + 8)
      ..quadraticBezierTo(
        lawn.center.dx,
        lawn.bottom + 12,
        lawn.left - 2,
        lawn.bottom + 7,
      )
      ..close(),
    MzArt.earth,
    stroke: 0,
  );
  c.drawRRect(
    RRect.fromRectAndRadius(
      lawn.inflate(3).translate(2, 4),
      const Radius.circular(5),
    ),
    Paint()..color = const Color(0x443c5031),
  );
  c.drawRRect(
    RRect.fromRectAndRadius(lawn.inflate(1.5), const Radius.circular(4)),
    Paint()..color = MzArt.grassDark,
  );
}

void _distance(Canvas c, Size size, Rect lawn) {
  for (var i = 0; i < 3; i++) {
    final x = size.width * (.25 + i * .29), y = lawn.top * (.13 + i % 2 * .02);
    // Keep the entire cloud below the canvas edge and above the tallest picket.
    final w = math.min(size.width * (.055 + i * .006), lawn.top * .48),
        h = lawn.top * .115;
    mzArtShape(
      c,
      Path()
        ..moveTo(x - w, y + h * .4)
        ..cubicTo(
          x - w * 1.15,
          y - h * .2,
          x - w * .5,
          y - h * .6,
          x - w * .25,
          y - h * .15,
        )
        ..cubicTo(
          x - w * .12,
          y - h,
          x + w * .6,
          y - h * .8,
          x + w * .65,
          y - h * .1,
        )
        ..cubicTo(
          x + w * 1.1,
          y - h * .2,
          x + w * 1.1,
          y + h * .5,
          x + w * .55,
          y + h * .6,
        )
        ..quadraticBezierTo(x, y + h * .75, x - w, y + h * .4)
        ..close(),
      const Color(0xe8f5ffff),
      stroke: 0,
    );
  }
  for (var i = 0; i < 11; i++) {
    final x = i * size.width / 10, y = lawn.top * (.84 + i % 3 * .05);
    _bush(
      c,
      Offset(x, y),
      size.width * (.042 + i * 7 % 5 * .004),
      lawn.top * .56,
      i.isEven ? const Color(0xff639c5d) : const Color(0xff80ad68),
      i,
    );
  }
}

void _fence(Canvas c, Size size, Rect lawn) {
  final foot = lawn.top - 5, top = lawn.top * .43;
  for (final y in [top + (foot - top) * .32, top + (foot - top) * .75]) {
    c.drawLine(
      Offset(0, y + 2),
      Offset(size.width, y + 2),
      Paint()
        ..color = const Color(0xff87977c)
        ..strokeWidth = 4,
    );
    c.drawLine(
      Offset(0, y),
      Offset(size.width, y),
      Paint()
        ..color = const Color(0xffd4d1b0)
        ..strokeWidth = 3,
    );
  }
  final w = size.width / 26;
  for (var i = 0; i < 25; i++) {
    final x = i * size.width / 24, tilt = (i * 7 % 5 - 2) * w * .055;
    final y = top - i * 13 % 5 * lawn.top * .04;
    final face = Path()
      ..moveTo(x, foot)
      ..lineTo(x + tilt, y + w * .25)
      ..lineTo(x + w * .35 + tilt, y)
      ..lineTo(x + w * .76 + tilt, y + w * .25)
      ..lineTo(x + w * .85, foot)
      ..close();
    mzArtShape(
      c,
      face,
      i.isEven ? const Color(0xffe5dfbd) : const Color(0xffdad8b8),
      stroke: 1,
      material: MzMaterial.wood,
    );
    mzArtShape(
      c,
      Path()
        ..moveTo(x + w * .76 + tilt, y + w * .25)
        ..lineTo(x + w * .9 + tilt, y + w * .3)
        ..lineTo(x + w, foot + 1)
        ..lineTo(x + w * .85, foot)
        ..close(),
      const Color(0xffa9b094),
      stroke: 0,
    );
    mzArtLine(
      c,
      Path()
        ..moveTo(x + w * .17, y + w * .33)
        ..lineTo(x + w * .17 - tilt, foot - 5),
      const Color(0xfff2eccd),
      1.3,
    );
    if (i % 3 == 1) {
      mzArtLine(
        c,
        Path()
          ..moveTo(x + w * .58, y + w * .35)
          ..quadraticBezierTo(
            x + w * .45,
            (y + foot) / 2,
            x + w * .65,
            foot - 4,
          ),
        const Color(0xffb7b79c),
        .7,
      );
      mzArtOval(
        c,
        Rect.fromCenter(
          center: Offset(x + w * .52, foot - 5),
          width: w * .13,
          height: w * .05,
        ),
        const Color(0xffadb195),
        stroke: 0,
      );
    }
  }
}

void _house(Canvas c, Size size, Rect lawn) {
  final l = MzServiceAisle(lawn).houseSpan, h = size.height;
  if (l <= 0 || h <= 0) return;
  // The facade and its return have separate planes. Props follow the facade slope.
  mzArtShape(
    c,
    Path()
      ..moveTo(0, h * .67)
      ..lineTo(l * .72, h * .647)
      ..lineTo(l * .79, h * .70)
      ..lineTo(0, h * .735)
      ..close(),
    const Color(0x33775e40),
    stroke: 0,
  );
  final wall = Path()
    ..moveTo(0, h * .22)
    ..lineTo(l * .66, lawn.top * .7)
    ..lineTo(l * .6, h * .659)
    ..lineTo(0, h * .68)
    ..close();
  mzArtShape(c, wall, const Color(0xffefdfbb), stroke: 1.7);
  // Warm plaster and cool lower-wall bounce preserve the doorway's proportions.
  mzArtVolume(c, wall, strength: .65);
  mzArtShape(
    c,
    Path()
      ..moveTo(l * .66, lawn.top * .7)
      ..lineTo(l * .83, lawn.top * .8)
      ..lineTo(l * .72, h * .647)
      ..lineTo(l * .6, h * .659)
      ..close(),
    const Color(0xffbeaf89),
    stroke: 1.2,
  );
  c.save();
  c.clipPath(wall);
  mzArtShape(
    c,
    Path()
      ..moveTo(0, h * .22)
      ..lineTo(l * .66, lawn.top * .7)
      ..lineTo(l * .65, lawn.top * .7 + l * .09)
      ..lineTo(0, h * .22 + l * .09)
      ..close(),
    const Color(0x33836b45),
    stroke: 0,
  );
  final slope = -h * .035 / l;
  c.skew(0, slope);
  // These dimensions preserve a doorway's proportions even on a short landscape.
  final doorWidth = l * .34;
  final doorHeight = math.min(doorWidth * 1.95, h * .48);
  final door = Rect.fromLTWH(
    l * .045,
    h * .68 - doorHeight,
    doorWidth,
    doorHeight,
  );
  final windowWidth = l * .26, windowHeight = windowWidth * 1.18;
  final window = Rect.fromLTWH(
    l * .075,
    math.min(h * .28, door.top - windowHeight - l * .07),
    windowWidth,
    windowHeight,
  );
  // Sill, recessed glass and a darker shutter make the window read as architecture.
  mzArtBox(
    c,
    window.inflate(3).translate(1, 2),
    const Color(0x33746243),
    radius: 2,
    stroke: 0,
  );
  mzArtBox(c, window.inflate(2), MzArt.woodLight, radius: 2, stroke: 1.2);
  mzArtBox(c, window, const Color(0xff7cb8c4), radius: 1, stroke: 1);
  c.save();
  c.clipRect(window);
  mzArtShape(
    c,
    Path()
      ..moveTo(window.left, window.bottom)
      ..lineTo(window.left, window.top + window.height * .35)
      ..lineTo(window.right, window.top)
      ..lineTo(window.right, window.top + window.height * .28)
      ..close(),
    const Color(0x99e2f3e5),
    stroke: 0,
  );
  c.restore();
  mzArtLine(
    c,
    Path()
      ..moveTo(window.center.dx, window.top)
      ..lineTo(window.center.dx, window.bottom)
      ..moveTo(window.left, window.center.dy)
      ..lineTo(window.right, window.center.dy),
    MzArt.paper,
    1.7,
  );
  mzArtBox(
    c,
    Rect.fromLTWH(window.left - 4, window.bottom + 1, window.width + 8, 3),
    const Color(0xffcebb91),
    radius: 1,
    stroke: 1,
  );
  // Arch above, straight threshold below: never a capsule rounded at both ends.
  Path doorway(Rect r) => Path()
    ..moveTo(r.left, r.bottom)
    ..lineTo(r.left, r.top + r.width * .48)
    ..cubicTo(
      r.left,
      r.top - r.width * .07,
      r.right,
      r.top - r.width * .07,
      r.right,
      r.top + r.width * .48,
    )
    ..lineTo(r.right, r.bottom)
    ..close();
  mzArtShape(
    c,
    doorway(door.inflate(3).translate(1.5, 1.5)),
    const Color(0x4471593b),
    stroke: 0,
  );
  mzArtShape(
    c,
    doorway(door.inflate(3)),
    MzArt.woodLight,
    stroke: 1.5,
    material: MzMaterial.wood,
  );
  mzArtShape(c, doorway(door), const Color(0xff65472d), stroke: 1.1);
  final inner = door.deflate(1.7);
  mzArtShape(
    c,
    doorway(inner),
    const Color(0xffb77b43),
    stroke: 0,
    material: MzMaterial.wood,
  );
  c.save();
  c.clipPath(doorway(inner));
  for (var i = 1; i < 4; i++) {
    final x = inner.left + inner.width * i / 4;
    mzArtLine(
      c,
      Path()
        ..moveTo(x, inner.top + 3)
        ..lineTo(x, inner.bottom),
      const Color(0x66724829),
      .7,
    );
  }
  // Two inset wooden panels, hinge plates and a latch remain readable at small sizes.
  final panelTop = inner.top + inner.width * .68;
  final panelHeight = math.max(2.0, (inner.bottom - panelTop - 5) * .43);
  for (var i = 0; i < 2; i++) {
    mzArtBox(
      c,
      Rect.fromLTWH(
        inner.left + 4,
        panelTop + i * (panelHeight + 2),
        math.max(2.0, inner.width - 8),
        panelHeight,
      ),
      const Color(0xffa86d3c),
      radius: 1,
      stroke: .7,
    );
  }
  for (final y in [
    door.top + door.width * .7,
    door.bottom - door.width * .25,
  ]) {
    mzArtBox(
      c,
      Rect.fromLTWH(door.left + 1, y, door.width * .15, 2.3),
      MzArt.ladyMask,
      radius: .5,
      stroke: 0,
    );
  }
  final latch = Offset(
    door.right - door.width * .17,
    door.top + door.height * .61,
  );
  mzArtOval(
    c,
    Rect.fromCenter(center: latch, width: 3.8, height: 6),
    MzArt.woodDark,
    stroke: .6,
  );
  mzArtOval(
    c,
    Rect.fromCircle(center: latch.translate(.3, -.5), radius: 1.7),
    MzArt.gold,
    stroke: .6,
    material: MzMaterial.metal,
  );
  // A small paw medallion belongs to Maru and Lady's house.
  final paw = Offset(door.center.dx, door.top + door.width * .39);
  mzArtOval(
    c,
    Rect.fromCenter(
      center: paw,
      width: door.width * .27,
      height: door.width * .22,
    ),
    MzArt.maruChest,
    stroke: .5,
  );
  for (final dx in [-.12, 0.0, .12]) {
    mzArtOval(
      c,
      Rect.fromCircle(
        center: paw.translate(
          door.width * dx,
          -door.width * (.13 - dx.abs() * .2),
        ),
        radius: door.width * .055,
      ),
      MzArt.maruChest,
      stroke: .4,
    );
  }
  c.restore();
  c.restore();
  // A projecting stoop joins the door to the path, clear of the Roomba lane.
  final left = door.left - 3, right = door.right + 4;
  final y0 = door.bottom + slope * left, y1 = door.bottom + slope * right;
  final depth = math.min(7.0, l * .06);
  mzArtShape(
    c,
    Path()
      ..moveTo(left, y0 + 2)
      ..lineTo(right, y1 + 2)
      ..lineTo(right + depth, y1 + depth + 4)
      ..lineTo(left - 1, y0 + depth + 4)
      ..close(),
    const Color(0x335e4a31),
    stroke: 0,
  );
  mzArtShape(
    c,
    Path()
      ..moveTo(left, y0)
      ..lineTo(right, y1)
      ..lineTo(right + depth, y1 + depth)
      ..lineTo(left - 1, y0 + depth)
      ..close(),
    const Color(0xffd8c8a2),
    stroke: .9,
  );
  mzArtShape(
    c,
    Path()
      ..moveTo(left - 1, y0 + depth)
      ..lineTo(right + depth, y1 + depth)
      ..lineTo(right + depth, y1 + depth + 3)
      ..lineTo(left - 1, y0 + depth + 3)
      ..close(),
    const Color(0xff9b8b6d),
    stroke: .7,
  );
  final a = Offset.zero,
      b = Offset(l * .57, 0),
      d = Offset(0, h * .24),
      e = Offset(l * .95, lawn.top * .76);
  Offset uv(double u, double v) =>
      Offset.lerp(Offset.lerp(a, b, u)!, Offset.lerp(d, e, u)!, v)!;
  final roof = Path()
    ..moveTo(a.dx, a.dy)
    ..lineTo(b.dx, b.dy)
    ..lineTo(e.dx, e.dy)
    ..lineTo(d.dx, d.dy)
    ..close();
  mzArtShape(c, roof, const Color(0xffa6523b), stroke: 1.5);
  c.save();
  c.clipPath(roof);
  for (var r = 0; r < 6; r++) {
    for (var col = -1; col < 6; col++) {
      final u = (col + (r.isOdd ? .5 : 0)) / 5;
      final p0 = uv(u, r / 6),
          p1 = uv(u + .2, r / 6),
          p2 = uv(u + .2, (r + 1) / 6),
          p3 = uv(u, (r + 1) / 6);
      final tile = Path()
        ..moveTo(p0.dx, p0.dy)
        ..lineTo(p1.dx, p1.dy)
        ..lineTo(p2.dx, p2.dy)
        ..lineTo(p3.dx, p3.dy)
        ..close();
      mzArtShape(
        c,
        tile,
        (r + col).isEven ? const Color(0xffc97b53) : const Color(0xffbc6545),
        stroke: .6,
      );
      mzArtLine(
        c,
        Path()
          ..moveTo(p3.dx, p3.dy)
          ..lineTo(p2.dx, p2.dy),
        const Color(0xffe8aa78),
        1,
      );
      mzArtLine(
        c,
        Path()
          ..moveTo(p0.dx, p0.dy + 1)
          ..lineTo(p1.dx, p1.dy + 1),
        const Color(0x665b4337),
        1.5,
      );
    }
  }
  c.restore();
  mzArtLine(
    c,
    Path()
      ..moveTo(d.dx, d.dy)
      ..lineTo(e.dx, e.dy),
    const Color(0xfff0c08d),
    3,
  );
}

void _path(Canvas c, Size size, Rect lawn) {
  final aisle = MzServiceAisle(lawn);
  for (var r = 0; r < 5; r++) {
    final y = lawn.top + r * lawn.height / 5;
    mzArtShape(
      c,
      Path()
        ..moveTo(aisle.left, y + 2)
        ..lineTo(aisle.right, y)
        ..lineTo(aisle.right, y + lawn.height / 5 - 3)
        ..lineTo(aisle.left, y + lawn.height / 5 + 2)
        ..close(),
      r.isEven ? const Color(0xffd7d0ac) : const Color(0xffd2cba5),
      stroke: .7,
    );
  }
  final y = lawn.bottom + (size.height - lawn.bottom) * .58;
  for (var i = 0; i < 14; i++) {
    final x = lawn.left + i * lawn.width / 14;
    mzArtShape(
      c,
      Path()
        ..moveTo(x, y + 1)
        ..lineTo(x + lawn.width / 14 - 3, y)
        ..lineTo(x + lawn.width / 14 - 2, size.height)
        ..lineTo(x - 1, size.height)
        ..close(),
      const Color(0xffdcd5b2),
      stroke: .7,
    );
  }
  for (var i = 0; i < 19; i++) {
    final x = lawn.left + (i * 137 % 997) / 1000 * lawn.width;
    mzArtOval(
      c,
      Rect.fromLTWH(
        x,
        i.isEven ? lawn.top - 4 : lawn.bottom + 12,
        3 + i % 3.0,
        2,
      ),
      const Color(0xffa78b63),
      stroke: 0,
    );
  }
}

void mzPaintLawn(Canvas c, Rect lawn, {int rows = 5, int columns = 9}) {
  c.drawRect(
    lawn,
    Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xff6bad48), MzArt.grass, Color(0xff49963d)],
      ).createShader(lawn),
  );
  final cw = lawn.width / columns, ch = lawn.height / rows;
  // Large quiet shapes break up repetition without obscuring the placement grid.
  for (var zone = 0; zone < 4; zone++) {
    final x = lawn.left + lawn.width * (.08 + zone * .25);
    final patch = Path()
      ..moveTo(x, lawn.top)
      ..cubicTo(
        x + cw * 1.1,
        lawn.top + ch * .6,
        x - cw * .25,
        lawn.top + ch * 2.9,
        x + cw * .9,
        lawn.bottom,
      )
      ..lineTo(x + cw * 2.3, lawn.bottom)
      ..cubicTo(
        x + cw * 1.5,
        lawn.top + ch * 3.2,
        x + cw * 2.8,
        lawn.top + ch,
        x + cw * 1.6,
        lawn.top,
      )
      ..close();
    c.save();
    c.clipRect(lawn);
    c.drawPath(
      patch,
      Paint()
        ..color = zone.isEven
            ? const Color(0x0fffefb7)
            : const Color(0x07314f39),
    );
    c.restore();
  }
  for (var row = 0; row < rows; row++) {
    for (var col = 0; col < columns; col++) {
      final cell = Rect.fromLTWH(
        lawn.left + col * cw,
        lawn.top + row * ch,
        cw + .2,
        ch + .2,
      );
      if ((row + col).isOdd) {
        c.drawRect(cell, Paint()..color = const Color(0x08fff2ae));
      }
      final patch = Rect.fromCenter(
        center: cell.center.translate(cw * .1, -ch * .1),
        width: cw * .9,
        height: ch * .65,
      );
      c.drawOval(
        patch,
        Paint()
          ..shader = RadialGradient(
            colors: [const Color(0x119cce69), MzArt.grass.withValues(alpha: 0)],
          ).createShader(patch),
      );
      for (var i = 0; i < 3 + (row * 11 + col * 7) % 5; i++) {
        final seed = row * 193 + col * 71 + i * 131;
        final x = cell.left + (seed * 17 % 89 + 5) / 100 * cw,
            y = cell.top + (seed * 31 % 87 + 5) / 100 * ch;
        final r = math.min(4.5, ch * (.045 + seed % 3 * .018));
        mzArtShape(
          c,
          Path()
            ..moveTo(x - 3, y)
            ..quadraticBezierTo(x - 4, y - r, x - 3, y - r * 1.3)
            ..lineTo(x - .8, y - r * .3)
            ..lineTo(x + 2, y - r * 1.5)
            ..lineTo(x + 1.5, y)
            ..close(),
          i.isEven ? const Color(0x556fae4f) : const Color(0x44388037),
          stroke: 0,
        );
        if (i == 2 && (row * 3 + col) % 7 == 0) {
          mzArtOval(
            c,
            Rect.fromCircle(center: Offset(x, y - 2), radius: 1.2),
            const Color(0xffd6d18b),
            stroke: 0,
          );
        }
      }
      if ((row * 13 + col * 7) % 9 == 0) {
        final p = cell.center.translate(cw * .23, ch * .25);
        for (final side in [-1.0, 1.0]) {
          c.drawOval(
            Rect.fromCenter(
              center: p.translate(side * 2, -2),
              width: 4,
              height: 3,
            ),
            Paint()..color = const Color(0x667eb45b),
          );
          c.drawOval(
            Rect.fromCenter(
              center: p.translate(side * 2, 1),
              width: 4,
              height: 3,
            ),
            Paint()..color = const Color(0x554b923a),
          );
        }
      }
    }
  }
  for (var i = 0; i < 62; i++) {
    final x = lawn.left + i * lawn.width / 61;
    mzArtShape(
      c,
      Path()
        ..moveTo(x - 2, lawn.bottom - 1)
        ..lineTo(x, lawn.bottom + 3 + i % 3)
        ..lineTo(x + 2, lawn.bottom - 1)
        ..close(),
      MzArt.grassDark,
      stroke: 0,
    );
    if (i.isEven) {
      mzArtShape(
        c,
        Path()
          ..moveTo(x - 2, lawn.top + 1)
          ..lineTo(x, lawn.top - 2 - i % 3)
          ..lineTo(x + 3, lawn.top + 1)
          ..close(),
        const Color(0xff67a846),
        stroke: 0,
      );
    }
  }
  final shade = Rect.fromLTWH(
    lawn.left,
    lawn.top,
    lawn.width,
    lawn.height * .13,
  );
  c.drawRect(
    shade,
    Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0x22325832), Color(0x00325832)],
      ).createShader(shade),
  );
}

/// Shared directional light ties grass, sand, timber and holograms to one scene.
void mzPaintAmbientLight(Canvas c, Size size, Rect lawn, int world) {
  final shadow = world == 4 ? const Color(0x282c3151) : const Color(0x22334b40);
  c.save();
  c.clipRect(lawn);
  c.drawPath(
    Path()
      ..moveTo(lawn.left, lawn.top)
      ..lineTo(lawn.left + lawn.width * .12, lawn.top)
      ..quadraticBezierTo(
        lawn.left + lawn.width * .08,
        lawn.center.dy,
        lawn.left + lawn.width * .02,
        lawn.bottom,
      )
      ..lineTo(lawn.left, lawn.bottom)
      ..close(),
    Paint()
      ..shader = LinearGradient(
        colors: [shadow, shadow.withValues(alpha: 0)],
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      ).createShader(lawn),
  );
  for (var i = 0; i < 15; i++) {
    final x = lawn.left + i * lawn.width / 14;
    c.drawPath(
      Path()
        ..moveTo(x - 4, lawn.top)
        ..lineTo(x + 6, lawn.top)
        ..lineTo(x + lawn.width * .025, lawn.top + lawn.height * .08)
        ..lineTo(x + lawn.width * .011, lawn.top + lawn.height * .08)
        ..close(),
      Paint()..color = shadow.withValues(alpha: .065),
    );
  }
  final edge = Rect.fromLTWH(
    lawn.right - lawn.width * .07,
    lawn.top,
    lawn.width * .07,
    lawn.height,
  );
  c.drawRect(
    edge,
    Paint()
      ..shader = LinearGradient(
        colors: [shadow.withValues(alpha: 0), shadow],
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      ).createShader(edge),
  );
  c.restore();
  // Pebbles, dry leaves and grass tufts transition the lawn into its earth rim.
  for (var i = 0; i < 27; i++) {
    final x = lawn.left + (i * 137 % 997) / 1000 * lawn.width;
    final y = i.isEven
        ? lawn.top - 3 - (i % 3) * 2
        : lawn.bottom + 5 + (i % 4) * 2;
    final r = math.min(3.0, lawn.height / 100);
    c.drawOval(
      Rect.fromCenter(center: Offset(x + 1, y + 1), width: r * 2.4, height: r),
      Paint()..color = const Color(0x335e573d),
    );
    c.drawOval(
      Rect.fromCenter(center: Offset(x, y), width: r * 2, height: r * .9),
      Paint()
        ..color = i % 3 == 0
            ? const Color(0xffbd9e70)
            : const Color(0xffd9bd8b),
    );
  }
}

/// World surfaces are decorative. Water, bridges, rails and nodes remain dynamic.
void mzPaintWorldGround(Canvas c, Rect board, int world) {
  final base = switch (world) {
    1 => const Color(0xffd6b775),
    2 => const Color(0xffa87b4d),
    3 => const Color(0xffba9362),
    5 => const Color(0xff3e5755),
    _ => const Color(0xff3c5364),
  };
  c.drawRect(board, Paint()..color = base);
  final cw = board.width / 9, ch = board.height / 5;
  for (var row = 0; row < 5; row++) {
    for (var col = 0; col < 9; col++) {
      final cell = Rect.fromLTWH(
        board.left + col * cw,
        board.top + row * ch,
        cw,
        ch,
      );
      if ((row + col).isOdd) {
        c.drawRect(cell, Paint()..color = const Color(0x08fff2c5));
      }
      if (world == 2) {
        for (var i = 0; i < 3; i++) {
          final plank = Rect.fromLTWH(
            cell.left,
            cell.top + i * ch / 3,
            cw,
            ch / 3,
          );
          c.drawRect(
            plank.deflate(.4),
            Paint()
              ..color = Color.lerp(
                base,
                MzArt.woodLight,
                ((col * 7 + row * 3 + i) % 4) * .08,
              )!,
          );
          mzArtLine(
            c,
            Path()
              ..moveTo(plank.left + 2, plank.top + 2)
              ..quadraticBezierTo(
                plank.center.dx,
                plank.top + 4,
                plank.right - 2,
                plank.top + 2,
              ),
            const Color(0x55724e2e),
            .6,
          );
          mzArtOval(
            c,
            Rect.fromCircle(
              center: plank.bottomRight.translate(-3, -3),
              radius: .65,
            ),
            MzArt.woodDark,
            stroke: 0,
          );
        }
      } else if (world == 4) {
        final panel = cell.deflate(2);
        c.drawRRect(
          RRect.fromRectAndRadius(panel, const Radius.circular(3)),
          Paint()
            ..shader = const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xff536f7e), Color(0xff3c5364)],
            ).createShader(panel),
        );
        mzArtLine(
          c,
          Path()
            ..moveTo(panel.left + 2, panel.top + 4)
            ..lineTo(panel.left + 2, panel.top + 2)
            ..lineTo(panel.left + 8, panel.top + 2),
          const Color(0x7769cac4),
          1,
        );
      } else {
        if (world == 1 && (row * 7 + col * 3) % 4 == 0) {
          // Low dunes are decorative: no outline, upright slab or grave symbol.
          final dune = Path()
            ..moveTo(cell.left, cell.bottom - ch * .16)
            ..quadraticBezierTo(
              cell.center.dx,
              cell.top + ch * .28,
              cell.right,
              cell.bottom - ch * .23,
            )
            ..lineTo(cell.right, cell.bottom)
            ..lineTo(cell.left, cell.bottom)
            ..close();
          c.drawPath(dune, Paint()..color = const Color(0x15fff0b4));
          c.drawPath(
            Path()
              ..moveTo(cell.left + cw * .1, cell.bottom - ch * .19)
              ..quadraticBezierTo(
                cell.center.dx,
                cell.top + ch * .43,
                cell.right - cw * .1,
                cell.bottom - ch * .26,
              ),
            Paint()
              ..color = const Color(0x22fff1c1)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1,
          );
        }
        for (var i = 0; i < 3; i++) {
          final seed = (row * 31 + col * 17 + i * 23) % 100;
          final p = Offset(
            cell.left + (seed / 100) * cw,
            cell.top + ((seed * 7 % 100) / 100) * ch,
          );
          mzArtOval(
            c,
            Rect.fromCenter(center: p, width: cw * .07, height: ch * .04),
            i.isEven ? const Color(0x44865e37) : const Color(0x55ffe0a3),
            stroke: 0,
          );
          if (world == 1) {
            mzArtLine(
              c,
              Path()
                ..moveTo(p.dx - cw * .12, p.dy + 3)
                ..quadraticBezierTo(p.dx, p.dy, p.dx + cw * .1, p.dy + 2),
              const Color(0x2287643a),
              .7,
            );
          }
        }
      }
    }
  }
  c.drawRect(
    Rect.fromLTWH(board.left, board.top, board.width, board.height * .12),
    Paint()
      ..shader =
          const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0x33303c30), Color(0x00303c30)],
          ).createShader(
            Rect.fromLTWH(
              board.left,
              board.top,
              board.width,
              board.height * .12,
            ),
          ),
  );
}

void _bush(Canvas c, Offset p, double rx, double ry, Color color, int seed) {
  final outline = Path()
    ..moveTo(p.dx - rx, p.dy + ry * .2)
    ..cubicTo(
      p.dx - rx * 1.1,
      p.dy - ry * .5,
      p.dx - rx * .66,
      p.dy - ry * .7,
      p.dx - rx * .42,
      p.dy - ry * .6,
    )
    ..cubicTo(
      p.dx - rx * .5,
      p.dy - ry * 1.1,
      p.dx + rx * .16,
      p.dy - ry,
      p.dx + rx * .26,
      p.dy - ry * .64,
    )
    ..cubicTo(
      p.dx + rx * .8,
      p.dy - ry * .96,
      p.dx + rx,
      p.dy - ry * .45,
      p.dx + rx * .8,
      p.dy - ry * .14,
    )
    ..cubicTo(
      p.dx + rx * 1.17,
      p.dy + ry * .15,
      p.dx + rx * .8,
      p.dy + ry * .8,
      p.dx + rx * .15,
      p.dy + ry * .75,
    )
    ..quadraticBezierTo(
      p.dx - rx * .66,
      p.dy + ry * .8,
      p.dx - rx,
      p.dy + ry * .2,
    )
    ..close();
  mzArtShape(c, outline, color, stroke: 0, material: MzMaterial.fur);
  c.save();
  c.clipPath(outline);
  for (var i = 0; i < 9; i++) {
    final x = p.dx + ((i * 37 + seed * 13) % 100 / 100 - .5) * rx * 1.7;
    final y = p.dy + ((i * 29 + seed * 7) % 100 / 100 - .6) * ry * 1.4;
    mzArtShape(
      c,
      Path()
        ..moveTo(x - rx * .12, y)
        ..quadraticBezierTo(x, y - ry * .2, x + rx * .14, y)
        ..quadraticBezierTo(x, y + ry * .12, x - rx * .12, y)
        ..close(),
      i.isEven
          ? Color.lerp(color, MzArt.grassLight, .28)!
          : color.withValues(alpha: .55),
      stroke: 0,
    );
  }
  mzArtVolume(c, outline, strength: .8);
  for (var i = 0; i < 4; i++) {
    final x = p.dx - rx * .6 + i * rx * .35,
        y = p.dy - ry * (.45 + i % 2 * .15);
    mzArtLine(
      c,
      Path()
        ..moveTo(x - rx * .1, y)
        ..quadraticBezierTo(x, y - ry * .1, x + rx * .12, y),
      const Color(0x558bba67),
      math.max(1, rx * .035),
    );
  }
  c.restore();
}

void mzPaintHedges(Canvas c, Size size, Rect lawn) {
  final margin = size.width - lawn.right;
  c.drawRect(
    Rect.fromLTWH(lawn.right - 3, lawn.top, 5, lawn.height),
    Paint()..color = const Color(0x22334d2c),
  );
  c.save();
  c.clipRect(Rect.fromLTRB(lawn.right + 1, 0, size.width, size.height));
  for (var i = 0; i < 8; i++) {
    final y = lawn.top + (i - .1) * lawn.height / 7;
    final x = lawn.right + margin * (.77 + (i % 3 - 1) * .025);
    _bush(
      c,
      Offset(x, y),
      margin * (.76 + i * 7 % 4 * .035),
      lawn.height * (.09 + i % 3 * .007),
      i.isEven ? const Color(0xff3b793a) : const Color(0xff45853d),
      i + 19,
    );
  }
  c.restore();
}
