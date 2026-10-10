import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'mz_art_style.dart';

// All architecture is static, recorded into the existing scenery picture.
// Reference coordinates scale with the same board margins, never with combat.
const _sand = Color(0xffdcb978),
    _stone = Color(0xffa97e50),
    _wood = Color(0xff9c623c),
    _timber = Color(0xff573f35),
    _metal = Color(0xff455a73),
    _cyan = Color(0xff8de7e1);

void mzPaintWorldBackdrop(Canvas c, Size size, Rect board, int world) {
  final sky = switch (world) {
    1 => const Color(0xffedcf97),
    2 => const Color(0xff92d1e4),
    3 => const Color(0xffe3b991),
    5 => const Color(0xff1f2947),
    _ => const Color(0xff283f68),
  };
  c.drawRect(Offset.zero & size, Paint()..color = sky);
  final ground = Rect.fromLTRB(0, board.top * .7, size.width, size.height);
  c.drawRect(
    ground,
    Paint()
      ..color = switch (world) {
        1 => _sand,
        2 => const Color(0xff287e9f),
        3 => const Color(0xffcba070),
        5 => const Color(0xff394345),
        _ => const Color(0xff374b63),
      },
  );
  // The service aisle has exactly the existing footprint and dock positions.
  final left = board.left * .65, right = board.left - 2;
  final dock = switch (world) {
    1 => const Color(0xffd2b681),
    2 => const Color(0xffbe9062),
    3 => const Color(0xffbe9471),
    5 => const Color(0xff858b8b),
    _ => const Color(0xff748899),
  };
  for (var row = 0; row < 5; row++) {
    final rect = Rect.fromLTRB(
      left,
      board.top + row * board.height / 5 + 2,
      right,
      board.top + (row + 1) * board.height / 5 - 2,
    );
    mzArtBox(c, rect, dock, stroke: .8, radius: 2);
    c.drawLine(
      Offset(rect.left + 3, rect.bottom - 3),
      Offset(rect.right - 3, rect.bottom - 3),
      Paint()
        ..color = world == 4 ? _cyan : const Color(0xffe3c993)
        ..strokeWidth = 1.3,
    );
  }
  mzPaintWorldArchitecture(c, size, board, world);
}

/// Strict cutout: not one decorative pixel may enter a cell or a Roomba dock.
/// All props are behind entities; there is no world-specific foreground mask.
void mzPaintWorldArchitecture(Canvas c, Size size, Rect board, int world) {
  final exclusion = Path()
    ..fillType = PathFillType.evenOdd
    ..addRect(Offset.zero & size)
    ..addRect(
      Rect.fromLTRB(
        board.left * .65 - 1,
        board.top - 2,
        board.right + 2,
        board.bottom + 2,
      ),
    );
  c.save();
  c.clipPath(exclusion);
  c.scale(size.width / 1000, size.height / 600);
  final b = Rect.fromLTRB(
    board.left / size.width * 1000,
    board.top / size.height * 600,
    board.right / size.width * 1000,
    board.bottom / size.height * 600,
  );
  switch (world) {
    case 0:
      _patio(c, b);
    case 1:
      _egypt(c, b);
    case 2:
      _pirates(c, b);
    case 3:
      _west(c, b);
    case 4:
      _future(c, b);
    case 5:
      _cemetery(c, b);
  }
  c.restore();
}

void _box(
  Canvas c,
  double x,
  double y,
  double w,
  double h,
  Color color, {
  double radius = 3,
}) => mzArtBox(
  c,
  Rect.fromLTWH(x, y, w, h),
  color,
  radius: radius,
  stroke: 1.8,
  material: MzMaterial.wood,
);
void _line(
  Canvas c,
  double x,
  double y,
  double xx,
  double yy,
  Color color, [
  double width = 2,
]) => mzArtLine(
  c,
  Path()
    ..moveTo(x, y)
    ..lineTo(xx, yy),
  color,
  width,
);
void _poly(Canvas c, List<Offset> points, Color color, {double stroke = 1.8}) {
  final p = Path()..addPolygon(points, true);
  mzArtShape(c, p, color, stroke: stroke);
}

void _oval(Canvas c, double x, double y, double w, double h, Color color) =>
    mzArtOval(c, Rect.fromLTWH(x, y, w, h), color, stroke: 1.4);
void _sign(Canvas c, String text, Rect r, Color color, {double font = 13}) {
  _box(c, r.left, r.top, r.width, r.height, color);
  final p = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        fontFamily: 'Fredoka',
        fontSize: font,
        fontWeight: FontWeight.w700,
        color: const Color(0xffffe4a0),
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout(maxWidth: r.width - 6);
  p.paint(c, Offset(r.center.dx - p.width / 2, r.center.dy - p.height / 2));
}

void _barrel(Canvas c, double x, double y, {Color color = _wood}) {
  _oval(c, x - 3, y + 40, 38, 8, const Color(0x5546372b));
  _box(c, x, y, 32, 43, color, radius: 9);
  for (var i = 1; i < 4; i++) {
    _line(c, x + i * 7, y + 3, x + i * 7, y + 40, const Color(0xff684d38), .8);
  }
  _box(c, x - 1, y + 7, 34, 5, _metal);
  _box(c, x - 1, y + 31, 34, 5, _metal);
  _oval(c, x + 2, y - 2, 28, 8, const Color(0xffc49966));
}

void _paw(Canvas c, Offset p, double scale, Color color) {
  c.drawOval(
    Rect.fromCenter(center: p, width: 12 * scale, height: 9 * scale),
    Paint()..color = color,
  );
  for (var i = 0; i < 3; i++) {
    c.drawOval(
      Rect.fromCenter(
        center: p + Offset((i - 1) * 7 * scale, -8 * scale),
        width: 5 * scale,
        height: 6 * scale,
      ),
      Paint()..color = color,
    );
  }
}

void _patio(Canvas c, Rect b) {
  // A rounded tree canopy and warm fence vines frame the familiar house.
  _line(c, 979, 47, 980, 138, const Color(0xff876847), 9);
  _line(c, 979, 72, 961, 44, const Color(0xff876847), 5);
  _oval(c, 937, 10, 49, 55, const Color(0xff54874b));
  _oval(c, 964, 4, 53, 59, const Color(0xff63954f));
  _oval(c, 951, 3, 41, 43, const Color(0xff80ac62));
  for (var i = 0; i < 6; i++) {
    final x = b.left + 120 + i * 103.0;
    _line(c, x, b.top - 17, x + 28, b.top - 13, const Color(0xff5a8e4e), 1.5);
    _oval(c, x + 9, b.top - 23, 12, 6, const Color(0xff7ca65b));
  }
  // Flower boxes attached to the existing house, not a replacement facade.
  _box(c, 6, 260, 53, 14, const Color(0xffaa6440));
  for (var i = 0; i < 5; i++) {
    final x = 12 + i * 9.0;
    _line(c, x, 260, x + 2, 242, const Color(0xff407a47), 2);
    for (var j = 0; j < 5; j++) {
      final a = j * math.pi * 2 / 5;
      _oval(
        c,
        x + math.cos(a) * 4,
        239 + math.sin(a) * 4,
        5,
        5,
        i.isEven ? const Color(0xffe6a55b) : const Color(0xffd98e98),
      );
    }
  }
  _line(c, 20, 305, 20, 326, _timber, 2);
  _oval(c, 6, 324, 31, 13, const Color(0xffa97850));
  for (var i = 0; i < 3; i++) {
    _oval(c, 8 + i * 7, 319, 12, 12, const Color(0xff5b8f4d));
  }
  for (var i = 0; i < 7; i++) {
    final x = b.left + 80 + i * 89.0;
    final y = b.bottom + 27;
    _oval(c, x, y, 20, 6, const Color(0xff4c7543));
    _line(c, x + 10, y + 2, x + 10, y - 9, const Color(0xff4c7543), 2);
    _oval(
      c,
      x + 6,
      y - 12,
      9,
      9,
      i.isEven ? const Color(0xffefc465) : const Color(0xffd8979b),
    );
  }
  // Corner trellis keeps the silhouette of the original garden.
  for (var x = 945.0; x < 1000; x += 18) {
    _line(c, x, 20, x, 85, const Color(0xff7b664b), 3);
  }
  _line(c, 940, 45, 1000, 45, const Color(0xffb89b6d), 4);
  for (var i = 0; i < 5; i++) {
    _oval(c, 944 + i * 10, 25 + (i % 2) * 15, 14, 10, const Color(0xff59894c));
  }
}

void _egypt(Canvas c, Rect b) {
  // Pyramids and dunes replace the garden's horizon.
  for (var i = 0; i < 3; i++) {
    final x = 250 + i * 260.0, y = b.top - 6, w = 90 - i * 8.0;
    _poly(
      c,
      [Offset(x - w, y), Offset(x, y - 73 + i * 9), Offset(x + w, y)],
      const Color(0xffc39859),
      stroke: 0,
    );
    _poly(
      c,
      [Offset(x, y - 73 + i * 9), Offset(x + w, y), Offset(x + 12, y)],
      const Color(0xffa97e49),
      stroke: 0,
    );
    _line(
      c,
      x - w * .55,
      y - 18,
      x + w * .5,
      y - 18,
      const Color(0xffdab679),
      1,
    );
  }
  _box(c, b.left, b.top - 27, b.width, 26, _sand);
  for (var x = b.left; x < b.right; x += 52) {
    _line(c, x, b.top - 27, x, b.top - 2, _stone, 1);
    _box(c, x + 12, b.top - 40, 28, 14, _sand);
  }
  // Temple gateway, layered lintel, columns and carved cat medallion.
  _box(c, -8, 90, 96, 457, const Color(0xffb59159));
  for (var y = 125.0; y < 550; y += 49) {
    _line(c, 0, y, 88, y, _stone, 1);
  }
  for (final x in [5.0, 68.0]) {
    _box(c, x, 135, 19, 406, const Color(0xffebce91));
    _box(c, x - 3, 128, 25, 13, _sand);
    _box(c, x - 3, 528, 25, 15, _sand);
    _line(c, x + 5, 147, x + 5, 525, const Color(0xfff2dfb1), 2);
  }
  _box(c, -8, 88, 101, 34, _sand);
  _box(c, -8, 78, 101, 12, const Color(0xff8c6960));
  _box(c, 27, 364, 38, 165, const Color(0xff725546), radius: 15);
  _box(c, 31, 370, 7, 151, const Color(0xffc29960));
  _oval(c, 29, 209, 36, 39, const Color(0xff638e9c));
  _paw(c, const Offset(47, 228), 1.4, const Color(0xffefd896));
  _poly(c, const [
    Offset(27, 274),
    Offset(48, 258),
    Offset(68, 274),
    Offset(48, 294),
  ], const Color(0xffbc7d50));
  for (var i = 0; i < 3; i++) {
    _line(c, 39, 307 + i * 12, 58, 307 + i * 12, const Color(0xff846747), 2);
  }
  _palm(c, 969, 270, 132);
  _palm(c, 981, 535, 120);
  for (var i = 0; i < 8; i++) {
    _oval(
      c,
      b.left + 40 + i * 100,
      b.bottom + 25,
      36,
      8,
      const Color(0xffcba367),
    );
  }
  _box(c, 360, b.bottom + 18, 68, 20, const Color(0xffb88e56));
  _paw(c, Offset(395, b.bottom + 30), .9, const Color(0xffe6cd95));
}

void _palm(Canvas c, double x, double y, double h) {
  _poly(c, [
    Offset(x - 6, y),
    Offset(x + 7, y),
    Offset(x - 4, y - h),
    Offset(x - 10, y - h),
  ], const Color(0xff99734b));
  for (var i = 0; i < 6; i++) {
    _line(
      c,
      x - 6,
      y - i * h / 6,
      x + 5,
      y - i * h / 6 - 3,
      const Color(0xff695f3c),
      1.5,
    );
  }
  for (var i = 0; i < 5; i++) {
    final d = (i - 2) * 18.0;
    final p = Path()
      ..moveTo(x - 6, y - h)
      ..quadraticBezierTo(x + d, y - h - 30, x + d * 1.5, y - h + 14)
      ..quadraticBezierTo(x + d * .7, y - h - 8, x - 6, y - h)
      ..close();
    mzArtShape(
      c,
      p,
      i.isEven ? const Color(0xff5b8c55) : const Color(0xff779957),
      stroke: 1.5,
    );
  }
}

void _pirates(Canvas c, Rect b) {
  // Ocean remains visible on the starboard edge and below the deck.
  for (var i = 0; i < 28; i++) {
    final y = 100 + i * 19.0;
    final x = i.isEven ? 945.0 : 956.0;
    mzArtLine(
      c,
      Path()
        ..moveTo(x, y)
        ..quadraticBezierTo(x + 12, y - 5, x + 22, y)
        ..quadraticBezierTo(x + 31, y + 5, x + 47, y),
      const Color(0xff84c9d6),
      2,
    );
  }
  for (var i = 0; i < 18; i++) {
    _line(
      c,
      b.left + i * 47,
      b.bottom + 30,
      b.left + i * 47 + 23,
      b.bottom + 28,
      const Color(0xff69b6ce),
      2,
    );
  }
  _box(c, b.left, b.top - 20, b.width, 20, _wood);
  for (var x = b.left + 10; x < b.right; x += 72) {
    _box(c, x, b.top - 36, 8, 35, _timber);
  }
  _line(c, b.left, b.top - 35, b.right, b.top - 35, const Color(0xffdab082), 6);
  // Stern cabin, portholes, planks, wheel and sail.
  _poly(c, const [
    Offset(0, 83),
    Offset(86, 100),
    Offset(90, 539),
    Offset(0, 587),
  ], _wood);
  for (var y = 125.0; y < 540; y += 32) {
    _line(c, 0, y, 89, y, _timber, 1.1);
  }
  _box(c, -3, 88, 94, 15, const Color(0xffdbc293));
  for (final y in [180.0, 290.0]) {
    _oval(c, 24, y, 42, 42, const Color(0xffcdac64));
    _oval(c, 31, y + 7, 28, 28, const Color(0xff3c768a));
    _line(c, 34, y + 19, 49, y + 10, const Color(0xffafe5e8), 2);
  }
  _box(c, 24, 407, 49, 118, _timber, radius: 17);
  _box(c, 31, 415, 35, 101, const Color(0xffb38250), radius: 15);
  _oval(c, 53, 463, 6, 7, const Color(0xffecc671));
  _box(c, 28, 0, 9, 108, _timber);
  _poly(c, const [
    Offset(39, 6),
    Offset(87, 62),
    Offset(39, 74),
  ], const Color(0xfff7e4b7));
  for (final x in [410.0, 770.0]) {
    _box(c, x, 0, 9, b.top - 23, _timber);
    _poly(c, [
      Offset(x + 14, 4),
      Offset(x + 119, 53),
      Offset(x + 14, 62),
    ], const Color(0xfff1dfb2));
    _line(c, x + 5, 8, x - 44, b.top - 27, const Color(0xffb39b77), 1.5);
  }
  _poly(c, const [
    Offset(774, 2),
    Offset(837, 2),
    Offset(826, 23),
    Offset(774, 18),
  ], const Color(0xff85494e));
  _paw(c, const Offset(798, 12), .8, const Color(0xfff5dfb4));
  _barrel(c, 225, b.bottom + 8);
  _barrel(c, 849, b.bottom + 9);
  _oval(c, 19, 346, 45, 45, const Color(0xffc59152));
  _oval(c, 29, 356, 25, 25, _wood);
  for (var i = 0; i < 8; i++) {
    final a = i * math.pi / 4;
    _line(
      c,
      41,
      369,
      41 + math.cos(a) * 29,
      369 + math.sin(a) * 29,
      _timber,
      4,
    );
  }
  // Deck extrusion and coiled rope, outside all cells.
  _box(c, b.left, b.bottom + 3, b.width, 13, _timber);
  _oval(c, 509, b.bottom + 25, 44, 18, const Color(0xffcdb991));
  _oval(c, 518, b.bottom + 29, 25, 8, _wood);
}

void _west(Canvas c, Rect b) {
  // Distant mesas and an unmistakable timber water tower.
  _poly(
    c,
    [
      Offset(580, b.top - 18),
      Offset(620, 35),
      const Offset(701, 35),
      Offset(748, b.top - 18),
    ],
    const Color(0xffb18372),
    stroke: 0,
  );
  for (var i = 0; i < 5; i++) {
    final x = 190 + i * 98.0;
    _box(
      c,
      x,
      b.top - 50 - (i % 2) * 12,
      72,
      49 + (i % 2) * 12,
      const Color(0xffb18a67),
    );
    _box(c, x + 18, b.top - 36, 14, 22, const Color(0xff775d50));
  }
  _box(c, 828, 18, 64, 32, const Color(0xffad7b55));
  _oval(c, 827, 10, 66, 15, const Color(0xffc3976a));
  for (final x in [836.0, 884.0]) {
    _line(c, x, 49, x, b.top - 5, _timber, 5);
  }
  _line(c, 836, 50, 884, b.top - 8, _timber, 2);
  _line(c, 884, 50, 836, b.top - 8, _timber, 2);
  // Saloon with false front and batwing doors, replacing the original house.
  _box(c, -9, 75, 101, 475, const Color(0xffa46f4e));
  for (var y = 100.0; y < 550; y += 24) {
    _line(c, 0, y, 92, y, _timber, 1);
  }
  _box(c, -8, 59, 102, 22, _timber);
  _poly(c, const [
    Offset(-7, 60),
    Offset(15, 37),
    Offset(70, 37),
    Offset(91, 60),
  ], const Color(0xffb98459));
  _sign(
    c,
    'SALOON',
    const Rect.fromLTWH(2, 113, 84, 31),
    const Color(0xff624b3c),
    font: 15,
  );
  for (final x in [2.0, 76.0]) {
    _box(c, x, 150, 10, 398, const Color(0xffdbc393));
  }
  _box(c, 19, 175, 45, 79, const Color(0xff594741));
  for (final x in [23.0, 45.0]) {
    _box(c, x, 180, 18, 64, const Color(0xff8babb0));
  }
  _box(c, 18, 359, 50, 174, _timber, radius: 12);
  for (final x in [20.0, 45.0]) {
    _poly(c, [
      Offset(x, 411),
      Offset(x + 20, 399),
      Offset(x + 20, 493),
      Offset(x, 507),
    ], const Color(0xffc49b66));
    for (var i = 0; i < 3; i++) {
      _line(c, x + 4, 430 + i * 18, x + 16, 426 + i * 18, _timber, 1);
    }
  }
  _sign(
    c,
    'MARU',
    const Rect.fromLTWH(10, 291, 61, 29),
    const Color(0xff824d42),
    font: 14,
  );
  for (var x = b.left; x < b.right; x += 104) {
    _box(c, x, b.top - 18, 8, 20, _timber);
  }
  _line(c, b.left, b.top - 13, b.right, b.top - 13, const Color(0xffb79267), 4);
  _cactus(c, 971, 290, 130);
  _cactus(c, 982, 510, 104);
  _barrel(c, 240, b.bottom + 8);
  _barrel(c, 829, b.bottom + 8);
  for (final y in [360.0, 550.0]) {
    _oval(c, 947, y, 38, 36, const Color(0xffc9ac7d));
    for (var i = 0; i < 5; i++) {
      _line(
        c,
        953 + i * 5,
        y + 4,
        976 - i * 4,
        y + 29,
        const Color(0xff947652),
        1,
      );
    }
  }
  for (var i = 0; i < 18; i++) {
    _oval(
      c,
      b.left + i * 44,
      b.bottom + 36 + (i % 3) * 3,
      10,
      3,
      const Color(0xffddbe96),
    );
  }
}

void _cactus(Canvas c, double x, double y, double h) {
  _box(c, x - 7, y - h, 17, h, const Color(0xff6d8b62), radius: 8);
  _box(c, x - 23, y - h * .64, 16, 12, const Color(0xff6d8b62), radius: 5);
  _box(c, x - 26, y - h * .8, 9, h * .27, const Color(0xff6d8b62), radius: 5);
  _box(c, x + 7, y - h * .45, 17, 10, const Color(0xff6d8b62), radius: 5);
  _box(c, x + 20, y - h * .68, 8, h * .3, const Color(0xff6d8b62), radius: 5);
  _line(c, x - 1, y - h + 9, x - 1, y - 7, const Color(0xffa1b88a), 1.5);
}

void _future(Canvas c, Rect b) {
  // Angular city silhouettes, antennae and cyan window arrays.
  for (var i = 0; i < 9; i++) {
    final x = 177 + i * 84.0, h = 43 + (i * 29 % 53).toDouble();
    _poly(c, [
      Offset(x, b.top - 5),
      Offset(x, b.top - h),
      Offset(x + 16, b.top - h - 10),
      Offset(x + 50, b.top - h),
      Offset(x + 50, b.top - 5),
    ], const Color(0xff486281));
    for (var j = 0; j < 3; j++) {
      _box(
        c,
        x + 11,
        b.top - h + 9 + j * 15,
        26,
        4,
        j.isEven ? _cyan : const Color(0xffa7a1cf),
      );
    }
    _line(c, x + 25, b.top - h - 9, x + 25, b.top - h - 19, _cyan, 1.5);
  }
  _box(c, b.left, b.top - 16, b.width, 16, _metal);
  _line(c, b.left, b.top - 9, b.right, b.top - 9, _cyan, 3);
  // Robotic hangar, articulated door, status lights and holographic cat emblem.
  _poly(c, const [
    Offset(0, 48),
    Offset(68, 48),
    Offset(91, 82),
    Offset(91, 555),
    Offset(0, 585),
  ], _metal);
  for (var y = 123.0; y < 550; y += 75) {
    _box(c, 5, y, 80, 57, const Color(0xff536c80));
    _line(c, 9, y + 4, 63, y + 4, const Color(0xff98b5c0), 1.5);
  }
  _poly(c, const [
    Offset(6, 34),
    Offset(58, 34),
    Offset(81, 59),
    Offset(2, 65),
  ], const Color(0xff758a9d));
  _box(c, 20, 377, 53, 156, const Color(0xff1b344d), radius: 12);
  for (var i = 0; i < 6; i++) {
    _box(c, 26, 387 + i * 22, 41, 16, const Color(0xff6e8591));
  }
  _line(c, 21, 381, 21, 529, _cyan, 3);
  _line(c, 73, 381, 73, 529, _cyan, 3);
  _oval(c, 21, 187, 47, 51, const Color(0xff446b82));
  _paw(c, const Offset(45, 219), 1.65, _cyan);
  _line(c, 14, 244, 79, 244, _cyan, 2);
  _line(c, 32, 244, 24, 224, _cyan, 1);
  _line(c, 62, 244, 71, 224, _cyan, 1);
  _box(c, 27, 281, 44, 51, const Color(0xff223f59));
  for (var i = 0; i < 3; i++) {
    _box(c, 34, 290 + i * 13, 30, 5, i == 1 ? const Color(0xffd2b868) : _cyan);
  }
  for (final y in [166.0, 380.0]) {
    _box(c, 953, y, 33, 132, const Color(0xff516b85));
    _poly(c, [
      Offset(953, y),
      Offset(970, y - 18),
      Offset(986, y),
    ], const Color(0xff7e92a0));
    _line(c, 960, y + 12, 960, y + 112, _cyan, 2);
    _oval(c, 966, y + 18, 14, 14, const Color(0xffa9a0d1));
  }
  // Perimeter cables and fixed projected panels, safely outside cell boundaries.
  _box(c, b.left, b.bottom + 4, b.width, 16, const Color(0xff4c6074));
  for (var i = 0; i < 9; i++) {
    _box(c, b.left + i * b.width / 9 + 10, b.bottom + 8, 37, 4, _cyan);
  }
  _box(c, 445, b.bottom + 31, 96, 20, const Color(0xff647294));
  _paw(c, Offset(493, b.bottom + 40), 1, _cyan);
}

void _cemetery(Canvas c, Rect b) {
  // Moonlight, ironwork and cypresses distinguish this night from the robot city.
  _oval(c, 738, 9, 44, 44, const Color(0xffebdfb5));
  _oval(c, 730, 4, 36, 37, const Color(0xff1f2947));
  for (var i = 0; i < 14; i++) {
    final x = 160 + i * 57.0, y = 9 + (i * 19 % 39).toDouble();
    _line(c, x - 2, y, x + 2, y, const Color(0xffadbccc), 1);
    _line(c, x, y - 2, x, y + 2, const Color(0xffadbccc), 1);
  }
  for (final x in [216.0, 424.0, 851.0, 973.0]) {
    _line(c, x, b.top - 4, x, b.top - 67, const Color(0xff39494b), 5);
    _poly(c, [
      Offset(x - 23, b.top - 5),
      Offset(x - 17, b.top - 43),
      Offset(x - 9, b.top - 70),
      Offset(x, b.top - 93),
      Offset(x + 11, b.top - 64),
      Offset(x + 23, b.top - 5),
    ], const Color(0xff344653));
    _line(c, x - 3, b.top - 62, x - 8, b.top - 23, const Color(0xff546467), 1);
  }
  for (var x = b.left + 7; x < b.right; x += 22) {
    _line(c, x, b.top - 32, x, b.top - 2, const Color(0xff65717a), 2.5);
    _poly(c, [
      Offset(x - 3, b.top - 30),
      Offset(x, b.top - 39),
      Offset(x + 3, b.top - 30),
    ], const Color(0xff8b9396));
  }
  _line(c, b.left, b.top - 13, b.right, b.top - 13, const Color(0xff77828b), 3);
  _line(c, b.left, b.top - 3, b.right, b.top - 3, const Color(0xff4c5966), 4);
  // Chapel-like caretaker gate, warm lanterns and a recognizable paw rosette.
  _box(c, -7, 107, 99, 445, const Color(0xff5b6071));
  for (var y = 140.0; y < 549; y += 44) {
    _line(c, 0, y, 91, y, const Color(0xff414957), 1.1);
  }
  _poly(c, const [
    Offset(-8, 112),
    Offset(42, 48),
    Offset(94, 112),
  ], const Color(0xff454857));
  _line(c, 7, 103, 42, 61, const Color(0xff79828b), 3);
  _box(c, 16, 366, 58, 171, const Color(0xff303947), radius: 22);
  _box(c, 23, 379, 44, 154, const Color(0xff70615b), radius: 17);
  _line(c, 44, 385, 44, 530, const Color(0xff363d44), 2);
  _oval(c, 54, 464, 5, 7, const Color(0xffd7bc73));
  _oval(c, 24, 188, 43, 49, const Color(0xff98979b));
  _oval(c, 29, 194, 33, 35, const Color(0xff415367));
  _paw(c, const Offset(46, 217), 1.2, const Color(0xffb6bec0));
  for (final y in [302.0, 506.0]) {
    _box(c, 77, y, 12, 24, const Color(0xff555a66));
    _box(c, 80, y + 5, 6, 13, const Color(0xffe1be79));
  }
  // Ghostly wisps are static and confined to the outside rim, without filters.
  for (var i = 0; i < 6; i++) {
    final x = b.left + 26 + i * 132.0;
    _oval(c, x, b.bottom + 24, 100, 9, const Color(0x426f8290));
    _line(
      c,
      x + 17,
      b.bottom + 42,
      x + 66,
      b.bottom + 39,
      const Color(0x507c8b95),
      2,
    );
  }
  for (final y in [237.0, 421.0]) {
    _line(c, 970, y - 67, 970, y + 75, const Color(0xff657480), 6);
    _oval(c, 952, y - 73, 36, 44, const Color(0xff858c97));
    _oval(c, 958, y - 66, 24, 30, const Color(0xffd4bd86));
    _box(c, 951, y - 30, 38, 6, const Color(0xff454f60));
  }
}
