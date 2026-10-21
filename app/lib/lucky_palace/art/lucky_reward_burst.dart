import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../lucky_palace_theme.dart';
import 'lucky_symbol_art.dart';

/// Finite, deterministic presentation of an already confirmed reward.
/// No random generator, timers, layers, input interception or economic writes.
abstract final class LuckyRewardBurst {
  static void paint(
    Canvas c,
    Rect bounds, {
    required double progress,
    required Color accent,
    required int amount,
    required String heading,
    bool grand = false,
  }) {
    if (progress <= 0 || progress >= 1 || bounds.isEmpty) return;
    final t = progress.clamp(0.0, 1.0);
    final fade = (1 - ((t - .66) / .34).clamp(0.0, 1.0));
    final expansion = 1 - math.pow(1 - t, 3).toDouble();
    final center = bounds.center;
    final radius = bounds.shortestSide * .43;
    c.save();
    c.clipRect(bounds);
    if (grand) {
      final burst = Path();
      for (var i = 0; i < 24; i++) {
        final angle = i * math.pi / 12 - .08;
        final reach = (i.isEven ? 1.0 : .72) * (.8 + expansion * .25);
        final p =
            center +
            Offset(
              math.cos(angle) * bounds.width * .46 * reach,
              math.sin(angle) * bounds.height * .4 * reach,
            );
        if (i == 0) {
          burst.moveTo(p.dx, p.dy);
        } else {
          burst.lineTo(p.dx, p.dy);
        }
      }
      burst.close();
      c.drawPath(
        burst,
        LuckyDrawing.fill(accent.withValues(alpha: .62 * (1 - t) * fade)),
      );
    }
    c.drawCircle(
      center,
      radius * (1 + expansion * .6),
      Paint()
        ..shader =
            RadialGradient(
              colors: [
                accent.withValues(alpha: .25 * fade),
                accent.withValues(alpha: 0),
              ],
            ).createShader(
              Rect.fromCircle(
                center: center,
                radius: radius * (1 + expansion * .6),
              ),
            ),
    );
    for (var i = 0; i < 12; i++) {
      final angle = i * math.pi / 6 + t * .18;
      final inner =
          center + Offset(math.cos(angle), math.sin(angle)) * radius * .25;
      final outer =
          center +
          Offset(math.cos(angle), math.sin(angle)) * radius * (1 + expansion);
      final ray = Path()
        ..moveTo(inner.dx, inner.dy)
        ..lineTo(outer.dx - math.sin(angle) * 7, outer.dy + math.cos(angle) * 7)
        ..lineTo(outer.dx + math.sin(angle) * 7, outer.dy - math.cos(angle) * 7)
        ..close();
      c.drawPath(ray, LuckyDrawing.fill(accent.withValues(alpha: .14 * fade)));
    }
    c.drawCircle(
      center,
      radius * (expansion + .12),
      LuckyDrawing.stroke(
        accent.withValues(alpha: (1 - t) * .65),
        3 * (1 - t) + 1,
      ),
    );
    // Two rising fountains and orbiting glints frame the confirmed payout.
    for (var i = 0; i < (grand ? 24 : 12); i++) {
      final age = (t - (i % 6) * .035).clamp(0.0, 1.0);
      if (age == 0) continue;
      final side = i.isEven ? -1.0 : 1.0;
      final p = Offset(
        center.dx + side * bounds.width * (.44 - age * .25),
        bounds.bottom - bounds.height * (age * 2 - age * age * 1.5),
      );
      final ink = LuckyPalette.goldLight.withValues(alpha: fade * .8);
      c.drawLine(
        p + Offset(side * 5, 12),
        p,
        LuckyDrawing.stroke(ink.withValues(alpha: fade * .3), 2),
      );
      LuckyDrawing.star(c, p, 3 + (i % 3).toDouble(), ink);
    }
    final count = grand ? 44 : 26;
    for (var i = 0; i < count; i++) {
      final angle = i * 2.399963 + .4;
      final speed = .6 + (i * 7 % 13) / 13;
      final point =
          center +
          Offset(
            math.cos(angle) * radius * speed * expansion * 1.8,
            math.sin(angle) * radius * speed * expansion * 1.25 +
                radius * t * t * .9,
          );
      c.save();
      c.translate(point.dx, point.dy);
      c.rotate(angle + t * (i.isEven ? 4 : -4));
      if (i % 5 == 4) {
        final paw = LuckyDrawing.fill(
          LuckyPalette.goldLight.withValues(alpha: fade),
        );
        c.drawOval(const Rect.fromLTWH(-3, 0, 6, 5), paw);
        for (var toe = 0; toe < 4; toe++) {
          final a = math.pi + toe * math.pi / 3;
          c.drawCircle(
            Offset(math.cos(a) * 4.5, math.sin(a) * 4 - 1),
            1.5,
            paw,
          );
        }
      } else if (i % 3 == 0) {
        c.scale(.45 + .55 * math.cos(t * 9 + i).abs(), 1);
        c.drawCircle(
          Offset.zero,
          5.5,
          LuckyDrawing.fill(LuckyPalette.gold.withValues(alpha: fade)),
        );
        c.drawCircle(
          Offset.zero,
          3.8,
          LuckyDrawing.stroke(
            LuckyPalette.goldLight.withValues(alpha: fade),
            1,
          ),
        );
      } else {
        final color = [
          accent,
          LuckyPalette.mint,
          const Color(0xfff58ab1),
          LuckyPalette.goldLight,
        ][i % 4];
        if (i.isEven) {
          LuckyDrawing.star(c, Offset.zero, 5.5, color.withValues(alpha: fade));
        } else {
          c.drawRRect(
            RRect.fromRectAndRadius(
              const Rect.fromLTWH(-2, -5, 4, 10),
              const Radius.circular(1),
            ),
            LuckyDrawing.fill(color.withValues(alpha: fade)),
          );
        }
      }
      c.restore();
    }
    // An elastic plaque expands locally, without shaking the board or controls.
    final arrival = (t / .2).clamp(0.0, 1.0);
    final bounce = 1 + math.sin(arrival * math.pi) * .13;
    c.translate(center.dx, center.dy);
    c.scale((.72 + .28 * arrival) * bounce);
    final plaque = Rect.fromCenter(
      center: Offset.zero,
      width: bounds.width * .72,
      height: bounds.height * .39,
    );
    final shape = RRect.fromRectAndRadius(plaque, const Radius.circular(18));
    c.drawRRect(
      shape.shift(const Offset(0, 5)),
      LuckyDrawing.fill(const Color(0xff33132f).withValues(alpha: .7 * fade)),
    );
    c.drawRRect(
      shape,
      LuckyDrawing.fill(LuckyPalette.gold.withValues(alpha: fade)),
    );
    c.drawRRect(
      shape.deflate(3),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xffb53772).withValues(alpha: fade),
            const Color(0xff421e49).withValues(alpha: fade),
          ],
        ).createShader(plaque),
    );
    final font = math.min(bounds.height * .1, bounds.width * .055);
    LuckyDrawing.text(
      c,
      heading,
      Offset(0, -font * .95),
      font * .78,
      color: LuckyPalette.goldLight.withValues(alpha: fade),
    );
    LuckyDrawing.text(
      c,
      '+$amount',
      Offset(0, font * .5),
      font * 1.7,
      color: LuckyPalette.cream.withValues(alpha: fade),
      outline: LuckyPalette.ink.withValues(alpha: fade),
      width: 2,
    );
    c.restore();
  }
}
