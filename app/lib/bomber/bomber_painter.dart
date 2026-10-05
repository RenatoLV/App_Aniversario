import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../cat_character.dart';
import 'bomber_config.dart';
import 'bomber_simulation.dart';

class BomberKittenPainter extends CustomPainter {
  const BomberKittenPainter(
    this.cat, {
    this.phase = 0,
    this.outfit = const CatOutfit(),
  });
  final BomberCat cat;
  final double phase;
  final CatOutfit outfit;
  @override
  void paint(Canvas c, Size size) {
    if (cat == BomberCat.maru || cat == BomberCat.lady) {
      (cat == BomberCat.maru
              ? MaruPainter(phase: phase, outfit: outfit)
              : LadyPainter(phase: phase, outfit: outfit))
          .paint(c, size);
      return;
    }
    c.save();
    c.scale(size.width / 100, size.height / 100);
    final fur = cat == BomberCat.milo
            ? const Color(0xffe7a552)
            : const Color(0xffe3e9ef),
        ink = Paint()..color = const Color(0xff384456),
        body = Paint()..color = fur;
    c.drawOval(
      Rect.fromCenter(center: const Offset(53, 73), width: 53, height: 42),
      body,
    );
    c.drawArc(
      const Rect.fromLTWH(62, 52, 29, 36),
      -.2,
      2.7,
      false,
      Paint()
        ..color = fur
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10
        ..strokeCap = StrokeCap.round,
    );
    final ears = Path()
      ..moveTo(22, 45)
      ..lineTo(22, 11)
      ..lineTo(44, 30)
      ..moveTo(58, 30)
      ..lineTo(80, 11)
      ..lineTo(78, 46);
    c.drawPath(ears, body);
    c.drawPath(
      Path()
        ..moveTo(27, 33)
        ..lineTo(27, 19)
        ..lineTo(40, 32)
        ..moveTo(62, 32)
        ..lineTo(75, 19)
        ..lineTo(74, 34),
      Paint()..color = const Color(0xffde98ab),
    );
    c.drawOval(const Rect.fromLTWH(20, 27, 61, 50), body);
    if (cat == BomberCat.milo) {
      final stripe = Paint()
        ..color = const Color(0xffae6b38)
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round;
      for (final x in [41.0, 51.0, 61.0]) {
        c.drawLine(Offset(x, 30), Offset(x - 2, 39), stripe);
      }
    }
    for (final x in [37.0, 65.0]) {
      c.drawOval(
        Rect.fromCenter(center: Offset(x, 50), width: 16, height: 21),
        Paint()
          ..color = cat == BomberCat.milo
              ? const Color(0xff6c9567)
              : const Color(0xff78b9d2),
      );
      c.drawOval(
        Rect.fromCenter(center: Offset(x, 51), width: 6, height: 17),
        ink,
      );
      c.drawCircle(Offset(x - 3, 45), 3, Paint()..color = Colors.white);
    }
    c.drawOval(
      const Rect.fromLTWH(43, 61, 14, 7),
      Paint()..color = const Color(0xffdc88a1),
    );
    c.drawPath(
      Path()
        ..moveTo(50, 67)
        ..lineTo(50, 72)
        ..moveTo(43, 73)
        ..quadraticBezierTo(50, 77, 57, 73),
      ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    c.drawOval(const Rect.fromLTWH(29, 83, 21, 11), body);
    c.drawOval(const Rect.fromLTWH(57, 83, 21, 11), body);
    final whisker = Paint()
      ..color = Colors.white
      ..strokeWidth = 1.5;
    for (final y in [59.0, 65.0]) {
      c.drawLine(Offset(12, y - 4), Offset(34, y), whisker);
      c.drawLine(Offset(68, y), Offset(91, y - 3), whisker);
    }
    c.restore();
  }

  @override
  bool shouldRepaint(BomberKittenPainter old) =>
      cat != old.cat || outfit != old.outfit || phase != old.phase;
}

class BomberBombSymbol extends CustomPainter {
  const BomberBombSymbol();
  @override
  void paint(Canvas c, Size s) {
    final d = s.shortestSide, center = Offset(d * .45, d * .6);
    c.drawCircle(center, d * .34, Paint()..color = const Color(0xff252e42));
    c.drawCircle(
      center - Offset(d * .12, d * .12),
      d * .075,
      Paint()..color = Colors.white54,
    );
    final fuse = Path()
      ..moveTo(d * .57, d * .29)
      ..quadraticBezierTo(d * .63, d * .09, d * .82, d * .14);
    c.drawPath(
      fuse,
      Paint()
        ..color = const Color(0xff744b31)
        ..strokeWidth = d * .09
        ..style = PaintingStyle.stroke,
    );
    c.drawCircle(
      Offset(d * .82, d * .14),
      d * .08,
      Paint()..color = const Color(0xffff7b3d),
    );
  }

  @override
  bool shouldRepaint(BomberBombSymbol old) => false;
}

class BomberBoardPainter extends CustomPainter {
  BomberBoardPainter(this.sim) : super(repaint: sim);
  final BomberSimulation sim;
  @override
  void paint(Canvas c, Size size) {
    if (sim.state.isEmpty) return;
    final cell = size.width / sim.columns, h = size.height / sim.rows;
    final arena =
        bomberArenas[(valueNum(sim.board['mapId']).toInt()).clamp(0, 3)];
    void text(
      String value,
      Offset center,
      double font, {
      Color color = Colors.white,
    }) {
      final t = TextPainter(
        text: TextSpan(
          text: value,
          style: TextStyle(
            fontSize: font,
            color: color,
            fontWeight: FontWeight.w800,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      t.paint(c, center - Offset(t.width / 2, t.height / 2));
    }

    void block(Rect rect, Color color, {bool crate = false}) {
      final base = RRect.fromRectAndRadius(
            rect.deflate(cell * .07),
            Radius.circular(cell * .12),
          ),
          top = base.shift(Offset(0, -h * .16));
      c.drawRRect(
        base.shift(Offset(0, h * .08)),
        Paint()..color = Colors.black.withValues(alpha: .22),
      );
      c.drawRRect(base, Paint()..color = Color.lerp(color, Colors.black, .3)!);
      c.drawRRect(top, Paint()..color = color);
      c.drawLine(
        top.outerRect.topLeft + Offset(cell * .12, h * .07),
        top.outerRect.topRight + Offset(-cell * .12, h * .07),
        Paint()
          ..color = Colors.white.withValues(alpha: .27)
          ..strokeWidth = 2,
      );
      if (crate) {
        final r = top.outerRect.deflate(cell * .16),
            p = Paint()
              ..color = Colors.black.withValues(alpha: .19)
              ..strokeWidth = cell * .06;
        c.drawLine(r.topLeft, r.bottomRight, p);
        c.drawLine(r.topRight, r.bottomLeft, p);
        c.drawCircle(
          top.outerRect.center,
          cell * .085,
          Paint()..color = arena.accent,
        );
      }
    }

    final walls = objectMap(sim.board['walls']),
        crates = objectMap(sim.board['crates']);
    for (var y = 0; y < sim.rows; y++) {
      for (var x = 0; x < sim.columns; x++) {
        final rect = Rect.fromLTWH(x * cell, y * h, cell, h), k = cellKey(x, y);
        c.drawRect(
          rect,
          Paint()
            ..color = Color.lerp(
              arena.floor,
              Colors.white,
              (x + y).isEven ? .045 : 0,
            )!,
        );
        c.drawRect(
          rect.deflate(.5),
          Paint()
            ..color = Colors.white.withValues(alpha: .05)
            ..style = PaintingStyle.stroke,
        );
        if (walls.containsKey(k)) {
          block(rect, arena.wall);
        } else if (crates.containsKey(k)) {
          block(rect, arena.crate, crate: true);
        }
        if (!walls.containsKey(k) &&
            !crates.containsKey(k) &&
            bomberHash(4, x, y) % 17 == 0) {
          final p = Paint()..color = Colors.white.withValues(alpha: .09),
              o = rect.center;
          c.drawOval(
            Rect.fromCenter(center: o, width: cell * .18, height: h * .13),
            p,
          );
          for (var i = 0; i < 3; i++) {
            c.drawCircle(
              o + Offset((i - 1) * cell * .09, -h * .13),
              cell * .04,
              p,
            );
          }
        }
      }
    }
    for (final key in sim.coinCells) {
      final xy = key.split('_').map(int.parse).toList();
      final center = Offset((xy[0] + .5) * cell, (xy[1] + .5) * h);
      c.drawCircle(center, cell * .3, Paint()..color = const Color(0xffffcd45));
      c.drawCircle(
        center,
        cell * .24,
        Paint()
          ..color = const Color(0xfffff0a1)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
      final label = TextPainter(
        text: TextSpan(
          text: '5',
          style: TextStyle(
            color: const Color(0xff714400),
            fontSize: cell * .38,
            fontWeight: FontWeight.w900,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      label.paint(c, center - Offset(label.width / 2, label.height / 2));
    }
    for (final item in sim.powers.values) {
      final v = objectMap(item),
          center = Offset(
            (valueNum(v['x']) + .5) * cell,
            (valueNum(v['y']) + .5) * h,
          );
      c.drawCircle(
        center,
        cell * .36,
        Paint()..color = Colors.white.withValues(alpha: .85),
      );
      final power = KittenPower.values
          .where((p) => p.name == v['type'])
          .firstOrNull;
      if (power != null) {
        final icon = TextPainter(
          text: TextSpan(
            text: String.fromCharCode(power.glyph.codePoint),
            style: TextStyle(
              fontFamily: power.glyph.fontFamily,
              fontSize: cell * .5,
              color: arena.background,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        icon.paint(c, center - Offset(icon.width / 2, icon.height / 2));
      }
    }
    for (final item in sim.bombs.values) {
      final b = objectMap(item),
          center = Offset(
            (valueNum(b['x']) + .5) * cell,
            (valueNum(b['y']) + .53) * h,
          ),
          pulse = 1 + .07 * math.sin(sim.now / 90);
      c.drawOval(
        Rect.fromCenter(
          center: center + Offset(0, h * .17),
          width: cell * .65,
          height: h * .22,
        ),
        Paint()..color = Colors.black.withValues(alpha: .28),
      );
      c.drawCircle(
        center,
        cell * .3 * pulse,
        Paint()
          ..shader = const RadialGradient(
            colors: [Color(0xff6b608c), Color(0xff20243f)],
          ).createShader(Rect.fromCircle(center: center, radius: cell * .3)),
      );
      c.drawArc(
        Rect.fromCenter(
          center: center - Offset(0, h * .3),
          width: cell * .23,
          height: h * .3,
        ),
        math.pi,
        math.pi * .6,
        false,
        Paint()
          ..color = arena.accent
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
      c.drawCircle(
        center + Offset(cell * .12, -h * .41),
        cell * .07,
        Paint()
          ..color = Color.lerp(
            Colors.amber,
            Colors.white,
            (pulse - 1).abs() * 10,
          )!,
      );
      final left = math.max(
        0,
        ((valueNum(b['explodeAt']) - sim.now) / 1000).ceil(),
      );
      text('$left', center, cell * .26);
    }
    for (final item in sim.events.values) {
      final e = objectMap(item);
      if (valueNum(e['until']) <= sim.now) continue;
      final fade = ((valueNum(e['until']) - sim.now) / BomberConfig.fire).clamp(
        0.0,
        1.0,
      );
      // A tile remains visibly dangerous until its damage window closes.
      final dangerAlpha = .65 + fade * .35;
      for (final k in (e['cells'] as List? ?? [])) {
        final xy = (k as String).split('_').map(int.parse).toList(),
            r = Rect.fromLTWH(
              xy[0] * cell,
              xy[1] * h,
              cell,
              h,
            ).deflate(cell * .06);
        c.drawRRect(
          RRect.fromRectAndRadius(r, Radius.circular(cell * .23)),
          Paint()..color = Colors.orange.withValues(alpha: dangerAlpha * .85),
        );
        c.drawOval(
          r.deflate(cell * .17),
          Paint()..color = Colors.yellowAccent.withValues(alpha: dangerAlpha),
        );
        text(
          '✦',
          r.center,
          cell * .5,
          color: Colors.white.withValues(alpha: dangerAlpha),
        );
      }
    }
    final cats = sim.positions.entries.toList()
      ..sort((a, b) => a.value.dy.compareTo(b.value.dy));
    for (final entry in cats) {
      if (!sim.alive(entry.key)) continue;
      final member = objectMap(sim.members[entry.key]),
          kind =
              BomberCat.values
                  .where((v) => v.name == member['cat'])
                  .firstOrNull ??
              BomberCat.maru,
          pos = Offset(entry.value.dx * cell, entry.value.dy * h),
          p = sim.stats(entry.key);
      final local = entry.key == sim.localId;
      c.drawOval(
        Rect.fromCenter(
          center: pos + Offset(0, h * .14),
          width: cell * .85,
          height: h * .34,
        ),
        Paint()
          ..color = (local ? arena.accent : Colors.black).withValues(
            alpha: .38,
          ),
      );
      if (local) {
        c.drawOval(
          Rect.fromCenter(
            center: pos + Offset(0, h * .14),
            width: cell * .9,
            height: h * .35,
          ),
          Paint()
            ..color = arena.accent
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
      }
      if (valueNum(p['shieldUntil']) > sim.now ||
          p['paw'] == true ||
          valueNum(p['immuneUntil']) > sim.now) {
        c.drawCircle(
          pos - Offset(0, h * .3),
          cell * .61,
          Paint()
            ..color = arena.accent.withValues(alpha: .45)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3,
        );
      }
      final bounce = (sim.velocities[entry.key]?.distance ?? 0) > .1
          ? math.sin(sim.now / 80) * h * .035
          : 0.0;
      c.save();
      c.translate(pos.dx - cell * .58, pos.dy - h * .91 + bounce);
      BomberKittenPainter(
        kind,
        phase: (sim.now % 2200) / 2200,
        outfit: CatOutfit.fromJson(member['outfit']),
      ).paint(c, Size(cell * 1.16, h * 1.16));
      c.restore();
    }
  }

  @override
  bool shouldRepaint(BomberBoardPainter old) => old.sim != sim;
}
