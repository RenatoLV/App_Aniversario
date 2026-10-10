part of 'mz_character_art.dart';

// Four individual cutouts. Other invaders keep their existing V3 construction.
bool _featuredInvader(
  Canvas c,
  MzEnemy kind,
  double phase,
  bool armor,
  double hurt,
  bool walking,
  double attack,
  double performance,
) {
  switch (kind) {
    case MzEnemy.bucket:
      _gordota(c, phase, armor, hurt, walking, attack);
    case MzEnemy.mummy:
      _marumomia(c, phase, hurt, walking, attack);
    case MzEnemy.pianist:
      _pianotron(c, phase, hurt, walking, attack, performance);
    case MzEnemy.mecha:
      _locotron(c, phase, hurt, walking, attack);
    default:
      return false;
  }
  return true;
}

bool _enemyDetails(Canvas c) {
  final t = c.getTransform();
  return math.sqrt(t[0] * t[0] + t[1] * t[1]) >= .45;
}

Color _enemyFur(MzMuse muse) => Color.lerp(
  muse == MzMuse.lady ? MzArt.ladyFur : MzArt.maruFur,
  const Color(0xff80a187),
  .30,
)!;

final _gordotaApron = Path()
  ..moveTo(18, 67)
  ..quadraticBezierTo(51, 59, 87, 68)
  ..lineTo(89, 88)
  ..quadraticBezierTo(51, 104, 16, 89)
  ..close();
final _bucketShell = Path()
  ..moveTo(20, 26)
  ..lineTo(24, 3)
  ..quadraticBezierTo(51, -2, 80, 4)
  ..lineTo(86, 27)
  ..quadraticBezierTo(55, 35, 20, 26)
  ..close();

void _gordota(
  Canvas c,
  double phase,
  bool armor,
  double hurt,
  bool walking,
  double attack,
) {
  final fur = _enemyFur(MzMuse.lady), detail = _enemyDetails(c);
  final step = walking ? math.sin(phase * 3.2) : 0.0;
  _tail(c, MzMuse.lady, fur, phase * .65, low: true, ragged: true);
  c.save();
  c.translate(50, 97);
  c.rotate(step * .022);
  c.scale(1.04, 1 - hurt * .035);
  c.translate(-50, -97);
  _body(c, MzMuse.lady, fur, heavy: true, zombie: true);
  mzArtShape(c, _gordotaApron, const Color(0xff846b86), stroke: 2);
  if (detail) {
    mzArtVolume(c, _gordotaApron, strength: .6);
    mzArtLine(
      c,
      Path()
        ..moveTo(31, 78)
        ..quadraticBezierTo(51, 89, 74, 77),
      const Color(0xffb19aaf),
      1.4,
    );
  }
  _paw(
    c,
    Rect.fromLTWH(11, 88 + math.max(0, step) * 1.4, 30, 11),
    MzArt.ladyFur,
  );
  _paw(
    c,
    Rect.fromLTWH(65, 88 + math.max(0, -step) * 1.4, 29, 11),
    MzArt.ladyFur,
  );
  // The neck contact is stationary relative to the torso, beneath the large head.
  mzArtOval(
    c,
    const Rect.fromLTWH(22, 63, 65, 12),
    const Color(0x3049534c),
    stroke: 0,
  );
  c.save();
  c.translate(-6, 8);
  c.scale(1.12, .94);
  _face(
    c,
    MzMuse.lady,
    fur,
    phase,
    zombie: true,
    persona: _FacePersona.cushion,
    hurt: hurt,
    attack: attack,
  );
  if (armor) {
    c.save();
    c.translate(52, 26);
    c.rotate(-step * .055 + attack * .03);
    c.translate(-52, -26);
    mzArtLine(
      c,
      Path()
        ..moveTo(24, 20)
        ..cubicTo(2, 12, 6, 43, 26, 43),
      const Color(0xff657873),
      3,
    );
    mzArtShape(
      c,
      _bucketShell,
      const Color(0xff8ea7a5),
      material: MzMaterial.metal,
      stroke: 2.5,
    );
    mzArtOval(
      c,
      const Rect.fromLTWH(24, -1, 56, 9),
      const Color(0xffdce5d5),
      stroke: 1.4,
    );
    mzArtLine(
      c,
      Path()
        ..moveTo(22, 26)
        ..quadraticBezierTo(50, 33, 85, 27),
      const Color(0xffd0dcd1),
      3,
    );
    if (detail) {
      mzArtLine(
        c,
        Path()
          ..moveTo(30, 5)
          ..lineTo(27, 22),
        const Color(0xffe2e9df),
        2,
      );
      mzArtLine(
        c,
        Path()
          ..moveTo(64, 9)
          ..lineTo(58, 14)
          ..lineTo(65, 18),
        const Color(0xff8f674c),
        2,
      );
      mzArtOval(
        c,
        const Rect.fromLTWH(37, 17, 8, 5),
        const Color(0xffa17c5d),
        stroke: 0,
      );
    }
    c.restore();
  }
  c.restore();
  c.restore();
}

final _mummyBands = List<Path>.generate(5, (i) {
  final y = 61 + i * 6.0;
  return Path()
    ..moveTo(34, y)
    ..quadraticBezierTo(52, y + 5, 76, y - 1)
    ..lineTo(75, y + 7)
    ..quadraticBezierTo(54, y + 12, 33, y + 6)
    ..close();
});
final _mummyBrow = Path()
  ..moveTo(23, 24)
  ..quadraticBezierTo(49, 16, 80, 23)
  ..lineTo(80, 29)
  ..quadraticBezierTo(53, 23, 24, 31)
  ..close();
final _mummyEyeWrap = Path()
  ..moveTo(61, 31)
  ..lineTo(80, 33)
  ..lineTo(78, 51)
  ..lineTo(69, 55)
  ..close();
void _linen(Canvas c, Path band, bool detail) {
  mzArtShape(c, band, const Color(0xffe4d5ae), stroke: detail ? 1.1 : .7);
  if (detail) mzArtVolume(c, band, strength: .65);
}

void _marumomia(
  Canvas c,
  double phase,
  double hurt,
  bool walking,
  double attack,
) {
  final fur = _enemyFur(MzMuse.maru), detail = _enemyDetails(c);
  final step = walking ? math.sin(phase * 4.4) : 0.0;
  c.save();
  c.translate(50, 98);
  c.rotate(-.08 + step * .018);
  c.translate(-50, -98);
  _tail(c, MzMuse.maru, fur, phase * .8, low: true, ragged: true);
  c.save();
  c.translate(50, 98);
  c.scale(.73, 1.15);
  c.translate(-50, -98);
  _body(c, MzMuse.maru, fur, lean: true, zombie: true);
  c.restore();
  for (var i = 0; i < _mummyBands.length; i++) {
    if (!detail && i.isOdd) continue;
    _linen(c, _mummyBands[i], detail);
  }
  _paw(c, Rect.fromLTWH(31, 88 + step * 1.8, 20, 10), fur);
  _paw(c, Rect.fromLTWH(63, 88 - step * 1.8, 19, 10), fur);
  // One reaching arm and a loose, moving ribbon change the silhouette.
  mzArtShape(
    c,
    Path()
      ..moveTo(70, 65)
      ..quadraticBezierTo(85, 53, 94, 63)
      ..lineTo(94, 69)
      ..lineTo(73, 76)
      ..close(),
    const Color(0xffd1c09b),
    stroke: 1.6,
  );
  _paw(c, Rect.fromLTWH(87 - attack * 2, 60, 12, 10), fur);
  final flutter = walking ? math.sin(phase * 4.4 - .8) * 3 : 0.0;
  _linen(
    c,
    Path()
      ..moveTo(35, 69)
      ..quadraticBezierTo(23, 72, 18 + flutter, 87)
      ..lineTo(12 + flutter, 84)
      ..quadraticBezierTo(16, 64, 35, 62)
      ..close(),
    detail,
  );
  c.save();
  c.translate(9, -3);
  c.scale(.84, 1.04);
  c.translate(52, 52);
  c.rotate(step * .025 - attack * .04);
  c.translate(-52, -52);
  _face(
    c,
    MzMuse.maru,
    fur,
    phase,
    zombie: true,
    persona: _FacePersona.wrapped,
    hurt: hurt,
    attack: attack,
  );
  _linen(c, _mummyBrow, detail);
  _linen(c, _mummyEyeWrap, detail);
  if (detail) {
    mzArtLine(
      c,
      Path()
        ..moveTo(69, 36)
        ..lineTo(75, 39)
        ..moveTo(70, 43)
        ..lineTo(77, 46),
      const Color(0xffae9b78),
      .9,
    );
  }
  c.restore();
  c.restore();
}

final _pianoSide = Path()
  ..moveTo(8, 70)
  ..lineTo(18, 62)
  ..lineTo(93, 63)
  ..lineTo(93, 88)
  ..lineTo(86, 99)
  ..lineTo(8, 94)
  ..close();
final _pianoTop = Path()
  ..moveTo(8, 70)
  ..lineTo(18, 62)
  ..lineTo(93, 63)
  ..lineTo(86, 72)
  ..close();
final _pianistJacket = Path()
  ..moveTo(30, 60)
  ..lineTo(48, 64)
  ..lineTo(67, 58)
  ..lineTo(78, 86)
  ..lineTo(50, 95)
  ..lineTo(25, 84)
  ..close();
void _pianotron(
  Canvas c,
  double phase,
  double hurt,
  bool walking,
  double attack,
  double performance,
) {
  final fur = _enemyFur(MzMuse.maru), detail = _enemyDetails(c);
  final step = walking ? math.sin(phase * 4.8) : 0.0;
  final playing = math.max(attack, performance);
  _tail(c, MzMuse.maru, fur, phase * .7, low: true, ragged: true);
  c.save();
  c.translate(50, 98);
  c.rotate(.065 + step * .015);
  c.translate(-50, -98);
  c.save();
  c.translate(-7, 1);
  c.scale(.95, 1.02);
  _body(c, MzMuse.maru, fur, lean: true, zombie: true);
  c.restore();
  mzArtShape(c, _pianistJacket, const Color(0xff68536f), stroke: 2);
  mzArtShape(
    c,
    Path()
      ..moveTo(38, 61)
      ..lineTo(48, 69)
      ..lineTo(44, 80)
      ..lineTo(31, 65)
      ..close(),
    const Color(0xffb799a2),
    stroke: .8,
  );
  _paw(c, Rect.fromLTWH(23, 91 + step, 22, 9), fur);
  _paw(c, Rect.fromLTWH(67, 90 - step, 22, 10), fur);
  c.save();
  c.translate(48, 56);
  c.rotate(-.12 - playing * .055);
  c.translate(-48, -56);
  c.translate(-7, -1);
  c.scale(.96, .97);
  _face(
    c,
    MzMuse.maru,
    fur,
    phase,
    zombie: true,
    persona: _FacePersona.showman,
    attack: attack,
    hurt: hurt,
  );
  // Tilted tall hat and ribbon belong to this performer, not every invader.
  c.save();
  c.translate(50, 24);
  c.rotate(-.08 + playing * .035);
  c.translate(-50, -24);
  mzArtBox(
    c,
    const Rect.fromLTWH(33, 0, 36, 25),
    const Color(0xff79546c),
    radius: 5,
  );
  mzArtBox(
    c,
    const Rect.fromLTWH(33, 17, 36, 6),
    const Color(0xffcfaa63),
    radius: 1,
    stroke: 0,
  );
  mzArtBox(
    c,
    const Rect.fromLTWH(20, 23, 64, 5),
    const Color(0xff513f59),
    radius: 3,
  );
  c.restore();
  c.restore();
  c.save();
  c.translate(50, 93);
  c.rotate(-step * .012);
  c.translate(-50, -93);
  mzArtShape(
    c,
    _pianoSide,
    const Color(0xff684637),
    material: MzMaterial.wood,
    stroke: 2,
  );
  mzArtShape(
    c,
    _pianoTop,
    const Color(0xffb18253),
    material: MzMaterial.wood,
    stroke: 1.4,
  );
  mzArtBox(
    c,
    const Rect.fromLTWH(15, 72, 71, 17),
    const Color(0xff332e32),
    radius: 2,
    stroke: 0,
  );
  final keys = detail ? 10 : 7;
  final w = 66 / keys;
  for (var i = 0; i < keys; i++) {
    final pressed = playing > 0 && (i == 2 || i == keys - 3);
    mzArtBox(
      c,
      Rect.fromLTWH(
        18 + i * w,
        74 + (pressed ? playing * 2 : 0),
        w - .6,
        12 - (pressed ? playing * 2 : 0),
      ),
      pressed ? const Color(0xffd9c591) : MzArt.paper,
      radius: .5,
      stroke: 0,
    );
    if (i < keys - 1 && i % 3 != 2) {
      mzArtBox(
        c,
        Rect.fromLTWH(18 + (i + 1) * w - 1.4, 74, 2.8, 6),
        MzArt.ink,
        radius: .5,
        stroke: 0,
      );
    }
  }
  if (detail) {
    mzArtLine(
      c,
      Path()
        ..moveTo(18, 91)
        ..lineTo(83, 91),
      const Color(0xffc6a46d),
      1.2,
    );
    mzArtOval(c, const Rect.fromLTWH(76, 65, 7, 4), MzArt.gold, stroke: .7);
  }
  // Keys and paws only press during observed melee or a real musical special.
  _paw(c, Rect.fromLTWH(29, 66 + playing * 7, 17, 9), MzArt.maruChest);
  _paw(c, Rect.fromLTWH(61, 67 + playing * 6, 17, 9), MzArt.maruChest);
  c.restore();
  c.restore();
}

final _mechaBreast = Path()
  ..moveTo(29, 58)
  ..lineTo(77, 59)
  ..lineTo(84, 80)
  ..lineTo(71, 91)
  ..lineTo(33, 90)
  ..lineTo(23, 77)
  ..close();
final _mechaHelmet = Path()
  ..moveTo(20, 29)
  ..lineTo(23, 12)
  ..lineTo(43, 8)
  ..lineTo(69, 11)
  ..lineTo(84, 30)
  ..lineTo(75, 32)
  ..lineTo(65, 24)
  ..lineTo(36, 24)
  ..lineTo(29, 34)
  ..close();
void _metalPanel(Canvas c, Rect box, Color color, bool detail) {
  mzArtBox(c, box, color, radius: 4, material: MzMaterial.metal, stroke: 1.8);
  if (detail) {
    mzArtLine(
      c,
      Path()
        ..moveTo(box.left + 3, box.top + 4)
        ..lineTo(box.left + 3, box.top + 2)
        ..lineTo(box.right - 4, box.top + 2),
      const Color(0xffd0e4dc),
      1.2,
    );
  }
}

void _joint(Canvas c, Offset p, bool detail) {
  mzArtOval(
    c,
    Rect.fromCircle(center: p, radius: 5),
    const Color(0xff3c514e),
    stroke: 1.2,
  );
  if (detail) {
    mzArtOval(
      c,
      Rect.fromCircle(center: p, radius: 2.5),
      const Color(0xffb8cebd),
      stroke: .7,
    );
  }
}

void _locotron(
  Canvas c,
  double phase,
  double hurt,
  bool walking,
  double attack,
) {
  final fur = _enemyFur(MzMuse.maru), detail = _enemyDetails(c);
  final step = walking ? math.sin(phase * 3.6).clamp(-.7, .7) / .7 : 0.0;
  _tail(c, MzMuse.maru, fur, phase * .25, low: true, ragged: true);
  c.save();
  c.translate(50, 98);
  c.rotate(step * .012);
  c.translate(-50, -98);
  _body(c, MzMuse.maru, fur, zombie: true);
  // Broad shoulders, separate actuators and planted boots give a mechanical silhouette.
  for (final side in [-1.0, 1.0]) {
    final x = side < 0 ? 18.0 : 78.0;
    final lift = math.max(0, step * side) * 2.5;
    _joint(c, Offset(x + 5, 80), detail);
    _metalPanel(
      c,
      Rect.fromLTWH(x - 1, 76, 14, 15),
      const Color(0xff718e85),
      detail,
    );
    _metalPanel(
      c,
      Rect.fromLTWH(side < 0 ? 17 : 65, 89 - lift, 28, 11 + lift),
      const Color(0xff849c90),
      detail,
    );

    _metalPanel(
      c,
      Rect.fromLTWH(x - 5, 58 + step * side, 24, 18),
      const Color(0xff9ab4ac),
      detail,
    );
  }

  mzArtShape(
    c,
    _mechaBreast,
    const Color(0xff71988e),
    material: MzMaterial.metal,
    stroke: 2.3,
  );
  if (detail) mzArtVolume(c, _mechaBreast, strength: .65);
  // The cream chest remains a visible window between plates.
  mzArtShape(
    c,
    Path()
      ..moveTo(42, 61)
      ..lineTo(63, 62)
      ..lineTo(57, 79)
      ..lineTo(48, 80)
      ..close(),
    MzArt.maruChest,
    stroke: 1,
  );
  _bolt(c, const Offset(53, 72), 7);
  if (detail) {
    for (var i = 0; i < 3; i++) {
      mzArtLine(
        c,
        Path()
          ..moveTo(65, 72 + i * 4.0)
          ..lineTo(75, 72 + i * 4.0),
        const Color(0xff345d54),
        1.8,
      );
    }
  }

  mzArtOval(
    c,
    const Rect.fromLTWH(26, 57, 56, 9),
    const Color(0x30424f49),
    stroke: 0,
  );
  c.save();
  c.translate(52, 57);
  c.rotate(-.035 - step * .008 - attack * .025);
  c.translate(-52, -57);
  c.translate(3, 2);
  c.scale(.95, .95);
  _face(
    c,
    MzMuse.maru,
    fur,
    phase * .55,
    zombie: true,
    persona: _FacePersona.automaton,
    hurt: hurt,
    attack: attack,
  );

  mzArtShape(
    c,
    _mechaHelmet,
    const Color(0xff89aca4),
    material: MzMaterial.metal,
    stroke: 2,
  );
  _metalPanel(
    c,
    const Rect.fromLTWH(16, 34, 10, 20),
    const Color(0xff77938a),
    detail,
  );
  _metalPanel(
    c,
    const Rect.fromLTWH(79, 33, 10, 18),
    const Color(0xff77938a),
    detail,
  );
  _joint(c, const Offset(21, 43), detail);
  _joint(c, const Offset(84, 42), detail);

  // The visor stays above the pupils; forehead stripes and eyes remain visible.
  mzArtLine(
    c,
    Path()
      ..moveTo(31, 35)
      ..lineTo(74, 35),
    const Color(0xff7acbbb),
    2.5,
  );
  c.restore();
  c.restore();
}
