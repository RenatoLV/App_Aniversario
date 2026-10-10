// Ground shadows remain fixed while the cutout character bobs above them.
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'mz_catalog.dart';
import 'mz_simulation.dart';
import 'mz_scenery.dart';
import 'mz_models.dart';
import 'mz_character_art.dart';
import 'mz_visual_feedback.dart';
import 'mz_art_style.dart';
import 'mz_combat_art.dart';

const mzInk = MzArt.ink;
const mzPalette = MzArt.accents;

class MzBoardGeometry {
  MzBoardGeometry(Size size)
    : board = Rect.fromLTWH(
        size.width * .145,
        size.height * .16,
        size.width * .785,
        size.height * .74,
      );
  final Rect board;
  double get cw => board.width / 9;
  double get ch => board.height / 5;
  Offset point(int row, double x) =>
      Offset(board.left + x * cw, board.top + (row + .5) * ch);
  (int, int)? cell(Offset p) {
    if (!board.contains(p)) return null;
    return (
      ((p.dy - board.top) / ch).floor().clamp(0, 4),
      ((p.dx - board.left) / cw).floor().clamp(0, 8),
    );
  }
}

void mzText(
  Canvas c,
  String text,
  Offset p,
  double size,
  Color color, {
  FontWeight weight = FontWeight.w800,
}) {
  final painter = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        fontFamily: 'Nunito',
        fontSize: size,
        fontWeight: weight,
        color: color,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  painter.paint(c, p - Offset(painter.width / 2, painter.height / 2));
}

Paint mzLitPaint(Color color, Rect bounds) {
  if (bounds.shortestSide < 16 || color.a < .99) return Paint()..color = color;
  return Paint()
    ..shader = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color.lerp(color, Colors.white, .16)!,
        color,
        Color.lerp(color, const Color(0xff273325), .17)!,
      ],
      stops: const [0, .55, 1],
    ).createShader(bounds);
}

void mzShape(Canvas c, Path p, Color color, [double stroke = 3.5]) {
  c.drawPath(p, mzLitPaint(color, p.getBounds()));
  c.drawPath(
    p,
    Paint()
      ..color = mzInk
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round,
  );
}

void mzOval(Canvas c, Rect r, Color color, [double stroke = 3.5]) {
  c.drawOval(r, stroke > 0 ? mzLitPaint(color, r) : (Paint()..color = color));
  if (stroke > 0) {
    c.drawOval(
      r,
      Paint()
        ..color = mzInk
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke,
    );
  }
}

void mzBox(Canvas c, Rect r, Color color, [double radius = 8]) {
  c.drawRRect(
    RRect.fromRectAndRadius(r, Radius.circular(radius)),
    mzLitPaint(color, r),
  );
  c.drawRRect(
    RRect.fromRectAndRadius(r, Radius.circular(radius)),
    Paint()
      ..color = mzInk
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5,
  );
}

/// Shared artwork facade used by battlefield, cards, previews and almanac.
void mzDrawCat(
  Canvas canvas,
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
}) => mzPaintCharacter(
  canvas,
  center,
  size,
  cat: cat,
  enemy: enemy,
  phase: phase,
  armor: armor,
  armed: armed,
  attack: attack,
  hurt: hurt,
  prepare: prepare,
  performance: performance,
  walking: walking,
);

class MzCatPortrait extends StatelessWidget {
  const MzCatPortrait(this.cat, {super.key, this.size = 64});
  final MzCat cat;
  final double size;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: CustomPaint(painter: _Portrait(cat)),
  );
}

class _Portrait extends CustomPainter {
  _Portrait(this.cat);
  final MzCat cat;
  @override
  void paint(Canvas c, Size s) => mzDrawCat(
    c,
    Offset(s.width / 2, s.height * .67),
    s.width * .78,
    cat: cat,
    armed: true,
  );
  @override
  bool shouldRepaint(_Portrait oldDelegate) => cat != oldDelegate.cat;
}

class MzBoardPainter extends CustomPainter {
  MzBoardPainter(
    this.sim, {
    this.selected,
    this.focusCell,
    this.reducedMotion = false,
    this.scenery,
    this.visuals,
  });
  final MzSimulation sim;
  final MzCat? selected;
  final (int, int)? focusCell;
  final bool reducedMotion;
  final MzSceneryCache? scenery;
  final MzVisualFeedback? visuals;
  @override
  void paint(Canvas c, Size size) {
    c.save();
    c.clipRect(Offset.zero & size);
    final g = MzBoardGeometry(size), b = g.board;
    if (scenery != null) {
      scenery!.background(c, size, b, sim.level.world.index);
    } else {
      mzPaintGarden(c, size, b, sim.level.world.index);
      if (sim.level.world == MzWorld.patio) {
        mzDrawGrass(c, b);
      } else {
        mzPaintWorldGround(c, b, sim.level.world.index);
      }
      mzPaintAmbientLight(c, size, b, sim.level.world.index);
    }
    // Hedges frame the garden behind incoming units, including the large boss.
    if (scenery != null) {
      scenery!.foreground(c, size, b, sim.level.world.index);
    } else if (sim.level.world == MzWorld.patio) {
      mzPaintHedges(c, size, b);
    }
    for (var r = 0; r < 5; r++) {
      for (var col = 0; col < 9; col++) {
        final rect = Rect.fromLTWH(
          b.left + col * g.cw,
          b.top + r * g.ch,
          g.cw,
          g.ch,
        );
        final terrain = sim.level.world;
        var ground = terrain == MzWorld.egypt || terrain == MzWorld.west
            ? const Color(0xffdcc28b)
            : terrain == MzWorld.pirates
            ? const Color(0xffbd9567)
            : terrain == MzWorld.future
            ? const Color(0xff566a7b)
            : const Color(0xff429939);
        if ((r + col).isOdd) ground = Color.lerp(ground, Colors.white, .065)!;
        if (!sim.level.rows.contains(r)) ground = const Color(0xff9aaf7f);
        if (!sim.level.rows.contains(r)) {
          c.drawRect(rect, Paint()..color = ground);
        }
        if (sim.water(r, col)) {
          c.drawRect(rect, Paint()..color = const Color(0xff5b9faf));
          for (var i = 0; i < 3; i++) {
            final y = rect.top + (i + .5) * rect.height / 3;
            c.drawPath(
              Path()
                ..moveTo(rect.left + 5, y)
                ..quadraticBezierTo(rect.center.dx, y + 5, rect.right - 5, y),
              Paint()
                ..color = const Color(0xffb4e2df)
                ..strokeWidth = 2
                ..style = PaintingStyle.stroke,
            );
          }
        } else if (sim.bridges.contains(r * 9 + col)) {
          for (var i = 0; i < 5; i++) {
            final y = rect.top + i * rect.height / 5;
            c.drawRect(
              Rect.fromLTWH(
                rect.left + 3,
                y + 1,
                rect.width - 6,
                rect.height / 5 - 2,
              ),
              Paint()..color = const Color(0xffe5c397),
            );
          }
        }
        if (sim.level.world == MzWorld.west && col == 1) {
          for (final x in [rect.left + g.cw * .2, rect.right - g.cw * .2]) {
            c.drawLine(
              Offset(x, rect.top),
              Offset(x, rect.bottom),
              Paint()
                ..color = const Color(0xff7b7063)
                ..strokeWidth = 3,
            );
          }
          if (sim.carts.contains(r * 9 + col)) {
            mzBox(c, rect.deflate(g.cw * .12), const Color(0xffa99a82), 5);
          }
        }
        final node = sim.node(r, col);
        if (node >= 0) {
          final color = const [
            Color(0xff8de2d5),
            Color(0xffffd675),
            Color(0xffd7a8f4),
          ][node];
          c.drawRRect(
            RRect.fromRectAndRadius(rect.deflate(5), const Radius.circular(5)),
            Paint()..color = color.withValues(alpha: .22),
          );
          final center = rect.center, radius = g.cw * .13;
          final stroke = Paint()
            ..color = color
            ..strokeWidth = 2
            ..style = PaintingStyle.stroke;
          if (node == 0) {
            c.drawCircle(center, radius, stroke);
          } else {
            final mark = Path()..moveTo(center.dx, center.dy - radius);
            if (node == 1) {
              mark
                ..lineTo(center.dx + radius, center.dy + radius)
                ..lineTo(center.dx - radius, center.dy + radius);
            } else {
              mark
                ..lineTo(center.dx + radius, center.dy)
                ..lineTo(center.dx, center.dy + radius)
                ..lineTo(center.dx - radius, center.dy);
            }
            mark.close();
            c.drawPath(mark, stroke);
          }
        }
        if (sim.tombs.containsKey(r * 9 + col)) {
          final stone = rect.deflate(g.cw * .16);
          mzPaintTomb(c, stone);
        }
      }
      final moving = sim.roombaX[r] >= -.8 && sim.roombaX[r] < 11;
      if (sim.roombas[r] || (sim.roombaX[r] >= -.8 && sim.roombaX[r] < 11)) {
        final aisle = MzServiceAisle(b);
        _roomba(
          c,
          aisle.robotPosition(r, moving ? sim.roombaX[r] : null),
          aisle.robotSize,
        );
      }
    }
    if (focusCell != null) {
      final (r, col) = focusCell!;
      final rect = Rect.fromLTWH(
        b.left + col * g.cw,
        b.top + r * g.ch,
        g.cw,
        g.ch,
      );
      final valid =
          sim.validCell(r, col) &&
          (selected == null ||
              sim.free(r, col) &&
                  sim.catnip >= mzCats[selected]!.cost &&
                  (sim.cooldowns[selected] ?? 0) <= sim.time);
      c.drawRRect(
        RRect.fromRectAndRadius(rect.deflate(2), const Radius.circular(6)),
        Paint()
          ..color = valid ? const Color(0x557eebaa) : const Color(0x66d56657),
      );
      c.drawRRect(
        RRect.fromRectAndRadius(rect.deflate(3), const Radius.circular(6)),
        Paint()
          ..color = valid ? const Color(0xffe5f8bf) : const Color(0xffffd2aa)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
      if (!valid) {
        final p = rect.bottomRight - Offset(g.cw * .17, g.ch * .17),
            d = math.min(g.cw, g.ch) * .07;
        c.drawPath(
          Path()
            ..moveTo(p.dx - d, p.dy - d)
            ..lineTo(p.dx + d, p.dy + d)
            ..moveTo(p.dx + d, p.dy - d)
            ..lineTo(p.dx - d, p.dy + d),
          Paint()
            ..color = MzArt.paper
            ..strokeWidth = 3
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round,
        );
      }
      if (selected != null && valid) {
        c.saveLayer(rect, Paint()..color = const Color(0x66ffffff));
        mzDrawCat(
          c,
          g.point(r, col + .5),
          math.min(g.cw * .9, g.ch * .9),
          cat: selected,
        );
        c.restore();
      }
    }
    final phase = reducedMotion ? 0.0 : sim.time;
    final entities =
        <(int, double, MzDefender?, MzInvader?, MzVisualEvent?)>[
          for (final d in sim.defenders) (d.row, d.col + .5, d, null, null),
          for (final e in sim.invaders) (e.row, e.x, null, e, null),
          if (!reducedMotion && visuals != null)
            for (final e in visuals!.events.where((e) => e.type == 'defeat'))
              (e.row, e.x, null, null, e),
        ]..sort((a, b) {
          final row = a.$1.compareTo(b.$1);
          return row == 0 ? a.$2.compareTo(b.$2) : row;
        });
    for (final entity in entities) {
      if (entity.$5 != null) {
        mzPaintDefeatedCutout(
          c,
          entity.$5!,
          sim.time,
          g.cw,
          g.ch,
          g.point(entity.$1, entity.$2),
        );
        continue;
      }
      final d = entity.$3;
      if (d != null) {
        final pos = g.point(d.row, d.col + .5);
        mzDrawCat(
          c,
          pos,
          math.min(g.cw * .97, g.ch * 1.65),
          cat: d.kind,
          phase: reducedMotion ? 0 : phase + d.id * .31,
          attack: reducedMotion ? 0 : visuals?.attack(d.id, sim.time) ?? 0,
          hurt: reducedMotion ? 0 : visuals?.hurt(d.id, sim.time) ?? 0,
          prepare: reducedMotion ? 0 : visuals?.prepare(d, sim) ?? 0,
          armor: d.armor > 0,
          armed: d.armed,
        );
        if (d.hp < mzCats[d.kind]!.hp || d.armor > 0) {
          _health(
            c,
            pos.translate(0, -g.ch * .47),
            g.cw * .6,
            d.hp / mzCats[d.kind]!.hp,
            d.armor > 0,
          );
        }
      } else {
        final e = entity.$4!;
        final pos = g.point(e.row, e.x);
        if (e.kind == MzEnemy.boss) {
          mzDrawCat(
            c,
            pos,
            g.cw * 1.55,
            enemy: MzEnemy.boss,
            phase: phase,
            hurt: reducedMotion ? 0 : visuals?.hurt(e.id, sim.time) ?? 0,
          );
          _health(
            c,
            pos.translate(0, -g.ch * .8),
            g.cw * 1.5,
            e.hp / 12000,
            false,
          );
        } else {
          mzDrawCat(
            c,
            pos,
            math.min(g.cw * .94, g.ch * 1.6),
            enemy: e.kind,
            performance: reducedMotion || e.frozenUntil > sim.time
                ? 0
                : visuals?.performance(e.id, sim.time) ?? 0,
            phase: reducedMotion || e.frozenUntil > sim.time
                ? 0
                : phase + e.id * .31,
            attack: reducedMotion ? 0 : visuals?.attack(e.id, sim.time) ?? 0,
            hurt: reducedMotion ? 0 : visuals?.hurt(e.id, sim.time) ?? 0,
            walking:
                e.frozenUntil <= sim.time && (visuals?.walking(e.id) ?? true),
            armor: e.armor > 0,
          );
        }
        if (e.shiny) {
          c.drawCircle(
            pos.translate(0, -g.ch * .35),
            5,
            Paint()..color = const Color(0xffd3ff98),
          );
        }
        if (e.slowUntil > sim.time || e.frozenUntil > sim.time) {
          c.drawCircle(
            pos,
            g.cw * .35,
            Paint()..color = const Color(0x5569d8ef),
          );
        }
        if (e.captive != null) {
          mzText(
            c,
            '¡Miau!',
            pos.translate(0, -g.ch * .45),
            g.cw * .15,
            Colors.white,
          );
        }
      }
    }
    for (final p in sim.projectiles) {
      final pos = g
          .point(p.row, p.x)
          .translate(0, p.arc ? -g.ch * .25 : -g.ch * .07);
      if (!reducedMotion && visuals != null) {
        mzPaintProjectileTrail(c, p, visuals!, sim.time, g.cw, g.ch, g.point);
      }
      _projectile(c, pos, g.cw * .1, p);
    }
    for (final w in sim.warnings) {
      final pos = g.point(w.row, w.col + .5);
      c.drawCircle(pos, g.cw * .35, Paint()..color = const Color(0x99ed7163));
      mzText(c, '!', pos, g.cw * .6, Colors.white);
    }
    // Continuous lasers emit several short-lived effects; paint one per lane.
    final beams = <int, MzEffect>{};
    for (final f in sim.effects) {
      if (f.type == 'laser' &&
          (beams[f.row] == null || f.x < beams[f.row]!.x)) {
        beams[f.row] = f;
      }
    }
    for (final f in beams.values) {
      mzPaintCombatEffect(
        c,
        f,
        sim.time,
        g.cw,
        g.ch,
        g.point,
        reducedMotion: reducedMotion,
      );
    }
    for (final f in sim.effects) {
      if (f.type == 'laser') continue;
      mzPaintCombatEffect(
        c,
        f,
        sim.time,
        g.cw,
        g.ch,
        g.point,
        reducedMotion: reducedMotion,
      );
    }
    if (!reducedMotion && visuals != null) {
      mzPaintVisualEvents(c, visuals!, sim.time, g.cw, g.ch, g.point);
    }
    for (final p in sim.pickups) {
      final pos = g.point(p.row, p.x).translate(0, -g.ch * .14);
      c.drawCircle(pos, g.cw * .23, Paint()..color = const Color(0x66fff7a6));
      if (p.tuna) {
        mzBox(
          c,
          Rect.fromCenter(center: pos, width: g.cw * .3, height: g.cw * .22),
          const Color(0xffb7e68e),
          4,
        );
        mzText(c, '><>', pos, g.cw * .11, mzInk);
      } else {
        mzPaintCatnip(c, pos, g.cw * .36);
      }
    }
    final drift = reducedMotion ? 0.0 : math.sin(sim.time * .5) * 2;
    for (final side in sim.level.world == MzWorld.patio ? [0, 1] : <int>[]) {
      c.save();
      c.translate(side == 0 ? 0 : size.width, size.height);
      if (side == 1) c.scale(-1, 1);
      final leaves = Paint()
        ..color = const Color(0xcc3d7947)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.3);
      c.drawOval(Rect.fromLTWH(-10 + drift, -32, 48, 18), leaves);
      c.drawOval(Rect.fromLTWH(-6, -56 + drift, 23, 42), leaves);
      c.restore();
    }
    c.restore();
  }

  void _health(Canvas c, Offset p, double w, double value, bool armor) {
    final rect = Rect.fromCenter(center: p, width: w, height: 5);
    c.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(3)),
      Paint()..color = mzInk,
    );
    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(rect.left, rect.top, w * value.clamp(0, 1), 5),
        const Radius.circular(3),
      ),
      Paint()
        ..color = armor ? const Color(0xff8fdce2) : const Color(0xffd4ee82),
    );
  }

  void _roomba(Canvas c, Offset p, double s) {
    c.drawOval(
      Rect.fromCenter(
        center: p.translate(s * .035, s * .23),
        width: s * 1.08,
        height: s * .32,
      ),
      Paint()..color = const Color(0x35465335),
    );
    mzOval(
      c,
      Rect.fromCenter(
        center: p.translate(0, s * .1),
        width: s,
        height: s * .45,
      ),
      MzArt.ladyMask,
      2,
    );
    mzOval(
      c,
      Rect.fromCenter(center: p, width: s, height: s * .43),
      MzArt.ladyFur,
      2,
    );
    c.drawCircle(p, s * .09, Paint()..color = const Color(0xff80c888));
    mzShape(
      c,
      Path()
        ..moveTo(p.dx - s * .35, p.dy)
        ..lineTo(p.dx - s * .36, p.dy - s * .35)
        ..lineTo(p.dx - s * .12, p.dy - s * .13)
        ..close(),
      MzArt.maruFur,
      1.5,
    );
    mzShape(
      c,
      Path()
        ..moveTo(p.dx + s * .12, p.dy - s * .13)
        ..lineTo(p.dx + s * .36, p.dy - s * .35)
        ..lineTo(p.dx + s * .35, p.dy)
        ..close(),
      MzArt.maruFur,
      1.5,
    );
  }

  void _projectile(Canvas c, Offset p, double radius, MzProjectile shot) {
    if (shot.fish) {
      c.save();
      c.translate(p.dx, p.dy);
      if (!reducedMotion) c.rotate(sim.time * 9);
      c.scale(shot.returning ? -1 : 1, 1);
      mzArtShape(
        c,
        Path()
          ..moveTo(-radius, 0)
          ..quadraticBezierTo(radius * .3, -radius, radius, 0)
          ..quadraticBezierTo(radius * .3, radius, -radius, 0)
          ..lineTo(-radius * 1.6, -radius * .7)
          ..lineTo(-radius * 1.6, radius * .7)
          ..close(),
        MzArt.gold,
        stroke: 1,
      );
      mzArtOval(
        c,
        Rect.fromCircle(center: Offset(radius * .5, 0), radius: radius * .14),
        MzArt.ink,
        stroke: 0,
      );
      c.restore();
      return;
    }
    c.save();
    c.translate(p.dx, p.dy);
    final color = shot.ice
        ? const Color(0xffa1efff)
        : shot.arc
        ? const Color(0xffb78351)
        : const Color(0xff81b94b);
    mzArtOval(
      c,
      Rect.fromCircle(center: Offset.zero, radius: radius),
      color,
      stroke: 1,
      material: shot.ice ? MzMaterial.ice : MzMaterial.fur,
    );
    if (!shot.ice && !shot.arc) {
      for (var i = -1; i <= 1; i++) {
        mzArtLine(
          c,
          Path()
            ..moveTo(-radius * .7, i * radius * .3)
            ..quadraticBezierTo(
              0,
              -radius * .7 + i * radius * .3,
              radius * .7,
              i * radius * .3,
            ),
          const Color(0xff4b803b),
          .7,
        );
      }
    }
    c.restore();
  }

  @override
  // The simulation is mutable. Comparing delegate identity would skip real
  // placements, removals and damage at the same game time; scenery is cached.
  bool shouldRepaint(MzBoardPainter oldDelegate) => true;
}

void mzDrawGroundShadow(Canvas canvas, Rect footprint) {
  canvas.drawOval(footprint, Paint()..color = const Color(0x55000000));
}

/// Borderless alternating terrain; reusable for any 5 by 9 lawn.
void mzDrawGrass(Canvas canvas, Rect board, {int rows = 5, int columns = 9}) =>
    mzPaintLawn(canvas, board, rows: rows, columns: columns);
