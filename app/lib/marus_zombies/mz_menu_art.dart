import 'package:flutter/material.dart';
import 'mz_scene_layers.dart';
import 'mz_art_style.dart';
import 'mz_character_art.dart';
import 'mz_catalog.dart';

const mzWorldColors = [
  Color(0xff385d45),
  Color(0xff79552e),
  Color(0xff285b70),
  Color(0xff80523c),
  Color(0xff354760),
  Color(0xff333c58),
];
const mzWorldIcons = [
  Icons.grass_rounded,
  Icons.pets_rounded,
  Icons.sailing_rounded,
  Icons.train_rounded,
  Icons.bolt_rounded,
  Icons.nights_stay_rounded,
];

/// Static vector postcard using the same surface renderer as the battlefield.
class MzWorldPostcard extends StatelessWidget {
  const MzWorldPostcard(
    this.world, {
    super.key,
    this.height = 90,
    this.heroes = false,
  });
  final int world;
  final double height;
  final bool heroes;
  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(painter: _WorldPostcard(world, heroes)),
      ),
    ),
  );
}

class _WorldPostcard extends CustomPainter {
  const _WorldPostcard(this.world, this.heroes);
  final int world;
  final bool heroes;
  @override
  void paint(Canvas c, Size s) {
    c.drawRect(Offset.zero & s, Paint()..color = mzWorldColors[world]);
    final ground = Rect.fromLTWH(0, s.height * .36, s.width, s.height * .64);
    if (world == 0) {
      mzPaintLawn(c, ground);
    } else {
      mzPaintWorldGround(c, ground, world);
    }
    final p = Paint()..color = MzArt.paper.withValues(alpha: .42);
    final y = s.height * .38;
    if (world == 1) {
      for (var i = 0; i < 3; i++) {
        final x = s.width * (.16 + i * .32), h = s.height * (.25 + i % 2 * .1);
        c.drawPath(
          Path()
            ..moveTo(x - h, y)
            ..lineTo(x, y - h)
            ..lineTo(x + h, y)
            ..close(),
          p,
        );
      }
    } else {
      final icon = mzWorldIcons[world];
      final text = TextPainter(
        text: TextSpan(
          text: String.fromCharCode(icon.codePoint),
          style: TextStyle(
            fontFamily: icon.fontFamily,
            fontSize: s.height * .38,
            color: MzArt.paper,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      text.paint(c, Offset(s.width * .76, 0));
    }
    c.drawLine(
      Offset(0, y),
      Offset(s.width, y),
      Paint()
        ..color = MzArt.gold
        ..strokeWidth = 2,
    );
    if (heroes) {
      const cats = [MzCat.launcher, MzCat.sunflower, MzCat.ice, MzCat.barrier];
      for (var i = 0; i < cats.length; i++) {
        mzPaintCharacter(
          c,
          Offset(s.width * (.12 + i * .19), s.height * .78),
          (s.height * .86).clamp(0, s.width / 5),
          cat: cats[i],
        );
      }
    }
  }

  @override
  bool shouldRepaint(_WorldPostcard old) =>
      world != old.world || heroes != old.heroes;
}
