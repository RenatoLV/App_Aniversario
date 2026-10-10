import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'mz_art_style.dart';
import 'mz_catalog.dart';
import 'mz_character_art.dart';
import 'mz_models.dart';
import 'mz_visual_feedback.dart';

final _star = Path()
  ..moveTo(0, -1)
  ..lineTo(.25, -.25)
  ..lineTo(1, 0)
  ..lineTo(.25, .25)
  ..lineTo(0, 1)
  ..lineTo(-.25, .25)
  ..lineTo(-1, 0)
  ..lineTo(-.25, -.25)
  ..close();
final _chip = Path()
  ..moveTo(-1, 0)
  ..lineTo(0, -.6)
  ..lineTo(1, 0)
  ..lineTo(0, .6)
  ..close();

void _spark(
  Canvas c,
  Offset p,
  double radius,
  Color color, {
  double rotation = 0,
}) {
  c.save();
  c.translate(p.dx, p.dy);
  c.rotate(rotation);
  c.scale(radius);
  c.drawPath(_star, Paint()..color = color);
  c.restore();
}

Color _family(MzCat? cat) => switch (cat) {
  MzCat.ice => const Color(0xffa7efff),
  MzCat.lightning => const Color(0xffffdf72),
  MzCat.laser => const Color(0xff9bfff0),
  MzCat.boomerang || MzCat.catapult => MzArt.gold,
  _ => const Color(0xffc0e77e),
};

/// Trails sample actual projectile positions; no visual paths predict a hit.
void mzPaintProjectileTrail(
  Canvas c,
  MzProjectile p,
  MzVisualFeedback visuals,
  double time,
  double cw,
  double ch,
  Offset Function(int, double) point,
) {
  var i = 0;
  for (final sample in visuals.trail(p.id)) {
    final age = time - sample.time;
    if (age > .15 || age < .012) continue;
    final pos = point(
      p.row,
      sample.x,
    ).translate(0, p.arc ? -ch * .25 : -ch * .07);
    final fade = (1 - age / .15).clamp(0.0, 1.0);
    final color = p.ice
        ? const Color(0xffb3f6ff)
        : p.fish || p.arc
        ? const Color(0xffefd498)
        : const Color(0xffc2e387);
    if (p.ice || p.fish) {
      _spark(
        c,
        pos.translate(0, (i.isEven ? -1 : 1) * cw * .025),
        cw * .045 * fade,
        color.withValues(alpha: fade * .7),
        rotation: time * 2,
      );
    } else {
      c.drawOval(
        Rect.fromCenter(
          center: pos,
          width: cw * .10 * fade,
          height: cw * .055 * fade,
        ),
        Paint()..color = color.withValues(alpha: fade * .5),
      );
    }
    i++;
  }
}

/// Bounded sparks, landing rings and brief defeated cutouts are presentation only.
void mzPaintVisualEvents(
  Canvas c,
  MzVisualFeedback visuals,
  double time,
  double cw,
  double ch,
  Offset Function(int, double) point,
) {
  for (final e in visuals.events) {
    final t = e.progress(time), fade = 1 - t;
    final pos = point(e.row, e.x);
    if (e.type == 'defeat') {
      // The cutout itself is depth sorted with live units by the board painter.
    } else if (e.type == 'plant') {
      c.drawOval(
        Rect.fromCenter(
          center: pos.translate(0, ch * .12),
          width: cw * (.35 + t * .65),
          height: ch * (.12 + t * .12),
        ),
        Paint()
          ..color = MzArt.paper.withValues(alpha: fade * .7)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    } else if (e.type == 'shot') {
      if (e.cat != MzCat.spring && e.cat != MzCat.sunflower) {
        _spark(
          c,
          pos.translate(0, -ch * .10),
          cw * .12 * fade,
          _family(e.cat).withValues(alpha: fade),
        );
      }
      continue;
    }
    final color = e.type == 'metalHit'
        ? MzArt.gold
        : e.type == 'iceHit'
        ? const Color(0xffc4f8ff)
        : e.type == 'harvest'
        ? MzArt.gold
        : MzArt.paper;
    final center = pos.translate(0, e.type == 'plant' ? ch * .1 : -ch * .25);
    if (e.type.endsWith('Hit') || e.type == 'hit') {
      _spark(c, center, cw * .18 * fade, color.withValues(alpha: fade));
      c.drawCircle(
        center,
        cw * (.08 + t * .16),
        Paint()
          ..color = color.withValues(alpha: fade * .7)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }
    for (var i = 0; i < 4; i++) {
      final a = i * math.pi / 2 + (e.seed % 7) * .5;
      final p =
          center + Offset(math.cos(a) * cw, math.sin(a) * ch) * (.08 + t * .3);
      c.save();
      c.translate(p.dx, p.dy - ch * math.sin(t * math.pi) * .10);
      c.rotate(a + t * 2);
      c.scale(cw * .035 * fade);
      c.drawPath(_chip, Paint()..color = color.withValues(alpha: fade));
      c.restore();
    }
  }
}

void mzPaintDefeatedCutout(
  Canvas c,
  MzVisualEvent e,
  double time,
  double cw,
  double ch,
  Offset pos,
) {
  final t = e.progress(time), fade = 1 - t;
  if (fade <= .1) return;
  final size = e.enemy == MzEnemy.boss
      ? cw * 1.55
      : math.min(cw * .95, ch * 1.6);
  c.saveLayer(
    Rect.fromCenter(
      center: pos.translate(0, -ch * .4),
      width: cw * 2.3,
      height: ch * 2.7,
    ),
    Paint()..color = Colors.white.withValues(alpha: fade),
  );
  c.translate(pos.dx, pos.dy);
  c.rotate(t * (e.enemy == null ? -.18 : .22));
  c.scale(1 - t * .12, 1 - t * .18);
  c.translate(-pos.dx, -pos.dy);
  mzPaintCharacter(
    c,
    pos,
    size,
    cat: e.cat,
    enemy: e.enemy,
    armor: e.armor,
    armed: e.armed,
    hurt: .7,
    walking: false,
  );
  c.restore();
}

/// Enhance only effects which the simulation actually emitted.
void mzPaintCombatEffect(
  Canvas c,
  MzEffect f,
  double time,
  double cw,
  double ch,
  Offset Function(int, double) point, {
  bool reducedMotion = false,
}) {
  final pos = point(f.row, f.x);
  if (f.type == 'laser') {
    final from = pos.translate(0, -ch * .1),
        end = point(f.row, 9.6).translate(0, -ch * .1);
    for (final layer in [
      (cw * .10, const Color(0x335cffe0)),
      (cw * .045, const Color(0xcc62eeda)),
      (cw * .018, const Color(0xfff0fff2)),
    ]) {
      c.drawLine(
        from,
        end,
        Paint()
          ..color = layer.$2
          ..strokeWidth = layer.$1
          ..strokeCap = StrokeCap.round,
      );
    }
    if (!reducedMotion) {
      _spark(c, from, cw * (.09 + .02 * math.sin(time * 11)), MzArt.paper);
    }
    return;
  }
  if (f.type == 'electric') {
    final radius = cw * .32;
    final path = Path()
      ..moveTo(pos.dx - radius, pos.dy - ch * .32)
      ..lineTo(pos.dx - radius * .25, pos.dy - ch * .12)
      ..lineTo(pos.dx - radius * .5, pos.dy + ch * .02)
      ..lineTo(pos.dx + radius * .65, pos.dy - ch * .02)
      ..lineTo(pos.dx + radius * .3, pos.dy + ch * .15)
      ..lineTo(pos.dx + radius, pos.dy + ch * .30);
    for (final layer in [
      (6.0, const Color(0x447dbaff)),
      (2.5, const Color(0xffffdd79)),
      (1.0, const Color(0xfffffff0)),
    ]) {
      c.drawPath(
        path,
        Paint()
          ..color = layer.$2
          ..strokeWidth = layer.$1
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }
    return;
  }
  if (f.type == 'lion') {
    final life = (f.ttl / 1.5).clamp(0.0, 1.0);
    c.drawOval(
      Rect.fromCenter(
        center: pos,
        width: cw * (reducedMotion ? 2.5 : 3 - life),
        height: ch * .8,
      ),
      Paint()
        ..color = MzArt.gold.withValues(alpha: life * .22)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    if (f.row == 2) {
      mzPaintAncestral(
        c,
        pos,
        math.min(cw * 1.4, ch * 2),
        life,
        reducedMotion: reducedMotion,
      );
    }
    return;
  }
  final boom = f.type == 'boom', poof = f.type == 'poof';
  final duration = boom ? .8 : .5;
  final t = reducedMotion ? .45 : (1 - f.ttl / duration).clamp(0.0, 1.0);
  final fade = (f.ttl / duration).clamp(0.0, 1.0);
  if (boom || poof) {
    if (boom) {
      c.drawOval(
        Rect.fromCenter(
          center: pos,
          width: cw * (.4 + t * 2.2),
          height: ch * (.2 + t * 1.0),
        ),
        Paint()
          ..color = MzArt.gold.withValues(alpha: fade * .65)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2 + fade * 3,
      );
      if (!reducedMotion) {
        _spark(
          c,
          pos.translate(0, -ch * .14),
          cw * .48 * fade,
          const Color(0xffffefb3).withValues(alpha: fade * .8),
        );
      }
    }
    if (!reducedMotion) {
      for (var i = 0; i < 6; i++) {
        final a = i * math.pi / 3;
        final p =
            pos +
            Offset(math.cos(a) * cw, math.sin(a) * ch * .6) *
                t *
                (boom ? .7 : .3);
        c.drawCircle(
          p.translate(0, -ch * t * .25),
          cw * (.07 + fade * .12),
          Paint()
            ..color =
                (poof
                        ? MzArt.paper
                        : i.isEven
                        ? MzArt.gold
                        : const Color(0xffe99460))
                    .withValues(alpha: fade * .6),
        );
      }
    }
    return;
  }
  final warm = f.type == 'sun',
      color = warm ? MzArt.gold : const Color(0xffcbf39c);
  c.drawOval(
    Rect.fromCenter(
      center: pos.translate(0, -ch * .15),
      width: cw * .65,
      height: ch * .65,
    ),
    Paint()..color = color.withValues(alpha: fade * .18),
  );
  if (!reducedMotion) {
    for (var i = 0; i < 4; i++) {
      final a = i * math.pi / 2 + time * .3;
      _spark(
        c,
        pos + Offset(math.cos(a) * cw, math.sin(a) * ch) * (.18 + t * .18),
        cw * .065 * fade,
        color.withValues(alpha: fade),
      );
    }
  }
}
