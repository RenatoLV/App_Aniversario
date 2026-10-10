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
  MzCat.boomerang => MzArt.gold,
  MzCat.catapult => const Color(0xffffb16a),
  MzCat.sunflower => const Color(0xffffd564),
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
  Offset Function(int, double) point, {
  bool enhancedPowers = true,
  bool secondStage = true,
  bool finalDefenders = true,
}) {
  if (p.fish && finalDefenders) {
    final path = Path();
    Offset? previous;
    var count = 0;
    // Reuse the bounded sample list instead of allocating a filtered copy.
    for (final sample in visuals.trail(p.id)) {
      if (time - sample.time > .15) continue;
      final b = point(p.row, sample.x).translate(0, -ch * .07);
      if (previous == null) {
        path.moveTo(b.dx, b.dy);
      } else {
        path.quadraticBezierTo(previous.dx, previous.dy, b.dx, b.dy);
      }
      previous = b;
      count++;
    }
    if (count > 1) {
      final powered = visuals.poweredShot(p.id);
      for (final layer in [
        (powered ? .07 : .045, const Color(0x55e6ad42)),
        (.018, const Color(0xfffff1b3)),
      ]) {
        c.drawPath(
          path,
          Paint()
            ..color = layer.$2
            ..style = PaintingStyle.stroke
            ..strokeWidth = cw * layer.$1
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round,
        );
      }
    }
    return;
  }
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
    if (secondStage && visuals.burstShot(p.id)) {
      c.drawLine(
        pos,
        pos.translate(-cw * .10 * fade, 0),
        Paint()
          ..color = const Color(0xffe3ffa9).withValues(alpha: fade * .8)
          ..strokeWidth = cw * .028 * fade
          ..strokeCap = StrokeCap.round,
      );
      i++;
      continue;
    }
    if (p.ice ||
        p.fish ||
        (enhancedPowers && p.arc && visuals.poweredShot(p.id))) {
      _spark(
        c,
        pos.translate(0, (i.isEven ? -1 : 1) * cw * .025),
        cw * (p.arc ? .065 : .045) * fade,
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
  Offset Function(int, double) point, {
  bool enhancedPowers = true,
}) {
  for (final e in visuals.events) {
    if (e.type == 'tuna') continue; // One aura per live cat, below its cutout.
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
        : e.type == 'iceHit' || e.type == 'freezeHit'
        ? const Color(0xffc4f8ff)
        : e.type == 'harvest' || e.type == 'croquetteHit'
        ? MzArt.gold
        : MzArt.paper;
    final center = pos.translate(0, e.type == 'plant' ? ch * .1 : -ch * .25);
    if (e.type.endsWith('Hit') || e.type == 'hit') {
      _spark(
        c,
        center,
        cw * (enhancedPowers && e.type == 'croquetteHit' ? .29 : .18) * fade,
        color.withValues(alpha: fade),
      );
      c.drawCircle(
        center,
        cw * (.08 + t * .16),
        Paint()
          ..color = color.withValues(alpha: fade * .7)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }
    if (enhancedPowers && e.type == 'freezeHit') {
      mzPaintFrozenCrown(c, center, cw * (.8 + t * .3), ch * .6, opacity: fade);
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
  Offset pos, {
  bool refinedBoss = true,
}) {
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
    refinedBoss: refinedBoss,
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
  bool powered = false,
  double? powerX,
  bool bombBurst = false,
  bool finalDefenders = true,
}) {
  final pos = point(f.row, f.x);
  if (f.type == 'laser') {
    final from = pos.translate(0, -ch * .1),
        end = point(f.row, 9.6).translate(0, -ch * .1);
    final boost = powered
        ? point(f.row, powerX ?? f.x).translate(0, -ch * .1)
        : from;
    if (powered && boost.dx > from.dx) {
      for (final layer in [
        (cw * .10, const Color(0x335cffe0)),
        (cw * .045, const Color(0xcc62eeda)),
        (cw * .018, const Color(0xfff0fff2)),
      ]) {
        c.drawLine(
          from,
          boost,
          Paint()
            ..color = layer.$2
            ..strokeWidth = layer.$1
            ..strokeCap = StrokeCap.round,
        );
      }
    }
    for (final layer in [
      (cw * (powered ? .19 : .10), Color(powered ? 0x3869ffe5 : 0x335cffe0)),
      (cw * (powered ? .075 : .045), const Color(0xcc62eeda)),
      (cw * (powered ? .032 : .018), const Color(0xfff0fff2)),
    ]) {
      c.drawLine(
        boost,
        end,
        Paint()
          ..color = layer.$2
          ..strokeWidth = layer.$1
          ..strokeCap = StrokeCap.round,
      );
    }
    if (!reducedMotion) {
      _spark(c, from, cw * (.09 + .02 * math.sin(time * 11)), MzArt.paper);
      if (powered) {
        // Energy markers live on the real beam; no extra projectile is drawn.
        for (var i = 1; i <= 3; i++) {
          final t = (time * .6 + i / 4) % 1;
          _spark(
            c,
            Offset.lerp(boost, end, t)!,
            cw * .045,
            const Color(0xffcaffed),
          );
        }
      }
    }
    return;
  }
  if (f.type == 'electric') {
    if (finalDefenders) {
      final life = (f.ttl / .35).clamp(0.0, 1.0);
      c.drawOval(
        Rect.fromCenter(center: pos, width: cw * .5, height: ch * .46),
        Paint()
          ..color = const Color(0xffffdf72).withValues(alpha: life * .12)
          ..style = PaintingStyle.stroke
          ..strokeWidth = cw * .025,
      );
      if (!reducedMotion) {
        _spark(
          c,
          pos.translate(cw * .18, -ch * .2),
          cw * .065 * life,
          MzArt.paper,
        );
      }
    }
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
  if (boom && bombBurst) {
    c.drawOval(
      Rect.fromCenter(
        center: pos,
        width: cw * (.4 + t * 2.2),
        height: ch * (.2 + t),
      ),
      Paint()
        ..color = const Color(0xfff6b579).withValues(alpha: fade * .75)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    _spark(
      c,
      pos.translate(0, -ch * .12),
      cw * .64 * fade,
      const Color(0xffffdb8d).withValues(alpha: fade * .9),
    );
    if (!reducedMotion) {
      for (var i = 0; i < 6; i++) {
        final angle = i * math.pi / 3;
        final center =
            pos +
            Offset(math.cos(angle) * cw, math.sin(angle) * ch * .6) *
                (.12 + t * .65);
        c.drawOval(
          Rect.fromCenter(
            center: center,
            width: cw * (.18 + fade * .17),
            height: ch * (.12 + fade * .13),
          ),
          Paint()
            ..color =
                (i.isEven ? const Color(0xffffc7ad) : const Color(0xffffe4b0))
                    .withValues(alpha: fade * .75),
        );
        _spark(
          c,
          center,
          cw * .045 * fade,
          const Color(0xffbb6457).withValues(alpha: fade),
          rotation: angle,
        );
      }
    }
    return;
  }
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

/// Shared power pulse with distinct silhouettes, bounded to six ornaments.
void mzPaintTunaAura(
  Canvas c,
  Offset pos,
  MzCat cat,
  double energy,
  double cw,
  double ch, {
  bool reducedMotion = false,
  bool secondStage = true,
  bool protected = false,
}) {
  final color = secondStage
      ? switch (cat) {
          MzCat.barrier => const Color(0xffc3dfed),
          MzCat.mine => const Color(0xffffc781),
          _ => _family(cat),
        }
      : _family(cat);
  final t = reducedMotion ? .35 : 1 - energy;
  final center = pos.translate(0, -ch * .20);
  c.drawOval(
    Rect.fromCenter(center: center, width: cw * 1.42, height: ch * 1.42),
    Paint()
      ..shader =
          RadialGradient(
            colors: [
              color.withValues(alpha: energy * .28),
              color.withValues(alpha: 0),
            ],
          ).createShader(
            Rect.fromCenter(
              center: center,
              width: cw * 1.42,
              height: ch * 1.42,
            ),
          ),
  );
  c.drawOval(
    Rect.fromCenter(
      center: pos.translate(0, ch * .16),
      width: cw * (1 + t * .5),
      height: ch * (.2 + t * .25),
    ),
    Paint()
      ..color = color.withValues(alpha: energy * .8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5,
  );
  for (var i = 0; i < 6; i++) {
    final angle = i * math.pi / 3 + (cat == MzCat.laser ? math.pi / 6 : 0);
    final p =
        center +
        Offset(
          math.cos(angle) * cw * (.53 + t * .18),
          math.sin(angle) * ch * (.49 + t * .18),
        );
    if (secondStage && cat == MzCat.barrier && protected) {
      c.save();
      c.translate(p.dx, p.dy);
      final s = cw * .065;
      c.drawPath(
        Path()
          ..moveTo(-s, -s)
          ..lineTo(s, -s)
          ..lineTo(s * .8, s * .5)
          ..lineTo(0, s)
          ..lineTo(-s * .8, s * .5)
          ..close(),
        Paint()..color = color.withValues(alpha: energy),
      );
      c.restore();
    } else if (secondStage && cat == MzCat.mine) {
      c.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: p, width: cw * .10, height: ch * .075),
          const Radius.circular(2),
        ),
        Paint()..color = color.withValues(alpha: energy),
      );
    } else if (cat == MzCat.ice) {
      _crystal(
        c,
        p,
        cw * .07 * (reducedMotion ? 1 : energy),
        color.withValues(alpha: energy),
        angle,
      );
    } else if (cat == MzCat.laser) {
      c.drawLine(
        p,
        p + Offset(-math.sin(angle), math.cos(angle)) * cw * .08,
        Paint()
          ..color = color.withValues(alpha: energy)
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round,
      );
    } else if (cat == MzCat.catapult) {
      c.save();
      c.translate(p.dx, p.dy);
      c.rotate(.4);
      c.scale(cw * .065 * (reducedMotion ? 1 : energy));
      c.drawPath(_chip, Paint()..color = color.withValues(alpha: energy));
      c.restore();
    } else {
      _spark(
        c,
        p,
        cw * .065 * (reducedMotion ? 1 : energy),
        color.withValues(alpha: energy),
      );
    }
  }
}

void _crystal(Canvas c, Offset pos, double size, Color color, double angle) {
  c.save();
  c.translate(pos.dx, pos.dy);
  c.rotate(angle);
  final path = Path()
    ..moveTo(0, -size * 1.8)
    ..lineTo(size * .7, -size * .5)
    ..lineTo(size * .5, size)
    ..lineTo(-size * .5, size)
    ..lineTo(-size * .7, -size * .5)
    ..close();
  c.drawPath(path, Paint()..color = color);
  c.drawLine(
    Offset(0, -size * 1.4),
    Offset(0, size * .7),
    Paint()
      ..color = const Color(0xfff3ffff).withValues(alpha: color.a)
      ..strokeWidth = math.max(1, size * .16),
  );
  c.restore();
}

/// Only called for invaders whose actual frozenUntil exceeds simulation time.
void mzPaintFrozenCrown(
  Canvas c,
  Offset pos,
  double cw,
  double ch, {
  double opacity = 1,
}) {
  c.drawOval(
    Rect.fromCenter(
      center: pos.translate(0, ch * .15),
      width: cw * .8,
      height: ch * .2,
    ),
    Paint()..color = const Color(0xff7abfd7).withValues(alpha: opacity * .4),
  );
  for (var i = 0; i < 3; i++) {
    _crystal(
      c,
      pos.translate((i - 1) * cw * .25, ch * .09),
      cw * (i == 1 ? .08 : .10),
      const Color(0xffacf0ff).withValues(alpha: opacity * .85),
      (i - 1) * .24,
    );
  }
}

/// Birth decoration and bounce apply to this real pickup, at its clickable center.
void mzPaintTunaResource(
  Canvas c,
  Offset pos,
  double cw,
  double age,
  int id, {
  bool reducedMotion = false,
}) {
  final progress = (age / .7).clamp(0.0, 1.0), fade = 1 - progress;
  final t = reducedMotion ? .35 : progress;
  c.drawCircle(
    pos,
    cw * (.2 + t * .12),
    Paint()
      ..color = MzArt.gold.withValues(alpha: fade * .75)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2,
  );
  if (!reducedMotion) {
    _spark(
      c,
      pos.translate(cw * .19, -cw * .14),
      cw * .065 * fade,
      MzArt.paper,
    );
    final scale = 1 + math.sin(t * math.pi * 2 + (id % 3) * .4) * .18 * fade;
    c.translate(pos.dx, pos.dy);
    c.scale(scale);
    c.translate(-pos.dx, -pos.dy);
  }
}
