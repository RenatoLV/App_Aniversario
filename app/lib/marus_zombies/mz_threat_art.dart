import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'mz_threat_feedback.dart';
import 'mz_catalog.dart';

const _ink = Color(0xff292c30);

void _paw(Canvas c, Offset p, double size, Color color) {
  final paint = Paint()..color = color;
  c.drawOval(
    Rect.fromCenter(center: p, width: size, height: size * .65),
    paint,
  );
  for (var i = 0; i < 4; i++) {
    c.drawOval(
      Rect.fromCenter(
        center: p.translate(
          (i - 1.5) * size * .29,
          -size * (.5 + (i == 1 || i == 2 ? .12 : 0)),
        ),
        width: size * .26,
        height: size * .36,
      ),
      paint,
    );
  }
}

void _caption(Canvas c, String label, Rect box, Color fill, double opacity) {
  final font = math.max(
    8.0,
    math.min(23.0, math.min(box.width / 21, box.height * .7)),
  );
  final lines = box.height >= font * 2.5 ? 2 : 1;
  final stroke = TextPainter(
    text: TextSpan(
      text: label,
      style: TextStyle(
        fontFamily: 'Fredoka',
        fontSize: font,
        fontWeight: FontWeight.w700,
        foreground: Paint()
          ..color = _ink.withValues(alpha: opacity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1.5, font * .13),
      ),
    ),
    textDirection: TextDirection.ltr,
    maxLines: lines,
    ellipsis: '…',
  )..layout(maxWidth: box.width);
  final text = TextPainter(
    text: TextSpan(
      text: label,
      style: TextStyle(
        fontFamily: 'Fredoka',
        fontSize: font,
        fontWeight: FontWeight.w700,
        color: fill.withValues(alpha: opacity),
      ),
    ),
    textDirection: TextDirection.ltr,
    maxLines: lines,
    ellipsis: '…',
  )..layout(maxWidth: box.width);
  final pos = box.center - Offset(text.width / 2, text.height / 2);
  stroke.paint(c, pos);
  text.paint(c, pos);
}

/// Ground FX painted before entities; all cues refer to actual invader arrivals.
void mzPaintThreatGround(
  Canvas c,
  Rect board,
  MzThreatFeedback threats,
  double time,
  bool reducedMotion, {
  bool refinedBoss = true,
}) {
  final cw = board.width / 9, ch = board.height / 5;
  Offset point(int row, double x) =>
      Offset(board.left + x * cw, board.top + (row + .5) * ch);
  for (var row = 0; row < 5; row++) {
    if (!threats.dangerRows[row]) continue;
    final alpha = reducedMotion ? .7 : .55 + math.sin(time * 5).abs() * .2;
    // Outside the grid: neither cats nor touch targets are covered.
    c.drawLine(
      Offset(board.left - 3, board.top + row * ch + 4),
      Offset(board.left - 3, board.top + (row + 1) * ch - 4),
      Paint()
        ..color = const Color(0xffe56549).withValues(alpha: alpha)
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round,
    );
    _paw(
      c,
      Offset(board.left - cw * .055, board.top + row * ch + ch * .15),
      math.min(9, cw * .12),
      const Color(0xfff7bc62),
    );
  }
  if (reducedMotion) return;
  for (final arrival in threats.arrivals) {
    final t = ((time - arrival.start) / .55).clamp(0.0, 1.0);
    // Spawn coordinates may start off-screen. Project only the dust onto the
    // entry edge so the foreground hedge cannot hide the entire arrival cue.
    final pos = point(
      arrival.row,
      arrival.x.clamp(0.0, 8.9),
    ).translate(0, ch * .26);
    final color = const Color(0xffdfcca2).withValues(alpha: (1 - t) * .42);
    for (var i = 0; i < 5; i++) {
      final dx = (i - 2) * cw * (.025 + t * .045);
      c.drawOval(
        Rect.fromCenter(
          center: pos.translate(
            dx,
            -math.sin(t * math.pi) * ch * (.05 + (i % 3) * .035),
          ),
          width: cw * (.08 + .07 * t),
          height: ch * (.07 + (i % 3) * .025),
        ),
        Paint()..color = color,
      );
    }
  }
  final start = threats.bossStart;
  if (!threats.hasBoss ||
      start == null ||
      time - start >= MzThreatFeedback.bossDuration) {
    return;
  }
  final t = ((time - start) / MzThreatFeedback.bossDuration).clamp(0.0, 1.0);
  final pos = point(threats.bossRow, threats.bossX).translate(0, ch * .27);
  c.drawOval(
    Rect.fromCenter(center: pos, width: cw * 1.8, height: ch * .5),
    Paint()
      ..color =
          (refinedBoss ? const Color(0xffffbd66) : const Color(0xff75f4ed))
              .withValues(alpha: (1 - t) * .22),
  );
  for (var i = 0; i < 3; i++) {
    c.drawOval(
      Rect.fromCenter(
        center: pos,
        width: cw * (1.2 + t * .7 + i * .15),
        height: ch * (.28 + i * .09),
      ),
      Paint()
        ..color =
            (refinedBoss ? const Color(0xffffd390) : const Color(0xff87fcf2))
                .withValues(alpha: (1 - t) * .5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }
}

/// Compact header occupies only the existing sky strip, outside all 45 cells.
void mzPaintThreatHeader(
  Canvas c,
  Rect board,
  MzThreatFeedback threats,
  double time,
  bool reducedMotion,
) {
  final label = threats.announcement(time);
  if (label == null && !threats.hasBoss) return;
  final boss = threats.hasBoss;
  final width = board.width * (boss ? .74 : .88);
  final height = math.min(66.0, board.top - 8).clamp(18.0, 66.0);
  final rect = Rect.fromLTWH(
    board.center.dx - width / 2,
    board.top - height - 5,
    width,
    height,
  );
  final start = boss ? threats.bossStart : threats.waveStart;
  final age = start == null ? 3.0 : math.max(0.0, time - start);
  final opacity = reducedMotion || boss
      ? 1.0
      : math
            .min(
              1.0,
              math.min(age / .2, (MzThreatFeedback.waveDuration - age) / .3),
            )
            .clamp(0.0, 1.0);
  c.save();
  if (!reducedMotion && label != null) {
    final enter = 1 - (age / .35).clamp(0.0, 1.0);
    c.translate(
      math.sin(age * 19) * (boss ? 1.5 : 2) * (1 - age / 3).clamp(0.0, 1.0),
      math.max(-rect.top + 2, -enter * height * .35),
    );
  }
  final rounded = RRect.fromRectAndRadius(rect, const Radius.circular(12));
  c.drawRRect(
    rounded.shift(const Offset(0, 4)),
    Paint()..color = _ink.withValues(alpha: .5 * opacity),
  );
  c.drawRRect(
    rounded,
    Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: boss
            ? [
                const Color(0xff293d57).withValues(alpha: opacity),
                const Color(0xff152634).withValues(alpha: opacity),
              ]
            : [
                const Color(0xffdb754a).withValues(alpha: opacity),
                const Color(0xff913c39).withValues(alpha: opacity),
              ],
      ).createShader(rect),
  );
  c.drawRRect(
    rounded.deflate(2),
    Paint()
      ..color = (boss ? const Color(0xffffbc66) : const Color(0xffffd183))
          .withValues(alpha: opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5,
  );
  final pawSize = math.min(15.0, height * .25);
  for (final x in [rect.left + height * .4, rect.right - height * .4]) {
    _paw(
      c,
      Offset(x, rect.top + height * (boss ? .36 : .55)),
      pawSize,
      const Color(0xffe0eab2).withValues(alpha: opacity),
    );
  }
  final textBox = Rect.fromLTWH(
    rect.left + height * .8,
    rect.top + 3,
    width - height * 1.6,
    boss ? height * .48 : height - 6,
  );
  _caption(
    c,
    boss ? MzEnemy.boss.label : label!,
    textBox,
    boss ? const Color(0xffbcfff4) : const Color(0xffffefb1),
    opacity,
  );
  if (boss) {
    final track = Rect.fromLTWH(
      rect.left + 14,
      rect.top + height * .58,
      width - 28,
      math.max(7.0, height * .18),
    );
    c.drawRRect(
      RRect.fromRectAndRadius(track, const Radius.circular(5)),
      Paint()..color = const Color(0xff0c1822),
    );
    final ratio = (threats.bossHp / threats.bossMaximum).clamp(0.0, 1.0);
    if (ratio > 0) {
      c.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            track.left,
            track.top,
            track.width * ratio,
            track.height,
          ),
          const Radius.circular(5),
        ),
        Paint()
          ..shader = const LinearGradient(
            colors: [Color(0xff8ff4dc), Color(0xff2ec4c0)],
          ).createShader(track),
      );
    }
    if (height < 32) {
      c.restore();
      return;
    }
    final text = TextPainter(
      text: TextSpan(
        text: '${threats.bossHp.ceil()} / ${threats.bossMaximum.ceil()}',
        style: TextStyle(
          fontFamily: 'Nunito',
          fontWeight: FontWeight.w900,
          fontSize: math.max(8.0, height * .15),
          color: Colors.white,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    text.paint(c, Offset(rect.center.dx - text.width / 2, track.bottom + 1));
  }
  c.restore();
}
