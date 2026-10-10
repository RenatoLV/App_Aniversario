import 'package:flutter/material.dart';
import 'mz_catalog.dart';
import 'mz_painter.dart';
import 'mz_art_style.dart';

/// Thick wooden frame, shared by the seed tray and resource badge.
BoxDecoration mzHudDecoration({bool badge = false}) => BoxDecoration(
  gradient: LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: badge
        ? const [Color(0xff367945), Color(0xff153b29)]
        : const [MzArt.woodLight, MzArt.woodDark],
  ),
  borderRadius: BorderRadius.circular(14),
  border: Border.all(color: MzArt.woodLight, width: 3),
  boxShadow: const [
    BoxShadow(color: Color(0xff44291d), offset: Offset(0, 5)),
    BoxShadow(color: Color(0x44000000), blurRadius: 7, offset: Offset(0, 7)),
  ],
);

BoxDecoration mzActionDecoration({
  bool pressed = false,
  bool active = false,
  bool enabled = true,
}) => BoxDecoration(
  gradient: LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: !enabled
        ? const [Color(0xffa1ab83), Color(0xff6b775b)]
        : active
        ? const [Color(0xffbcf16c), Color(0xff579a35)]
        : const [Color(0xffffdc78), Color(0xffe58a32)],
  ),
  borderRadius: BorderRadius.circular(13),
  border: Border.all(color: MzArt.frame, width: 2.5),
  boxShadow: [
    BoxShadow(
      color: const Color(0xff573522),
      offset: Offset(0, pressed ? 1 : 4),
    ),
    if (!pressed)
      const BoxShadow(
        color: Color(0x33000000),
        blurRadius: 5,
        offset: Offset(0, 6),
      ),
  ],
);

class MzOutlinedText extends StatelessWidget {
  const MzOutlinedText(
    this.text, {
    super.key,
    this.fontSize = 24,
    this.color = Colors.white,
    this.textKey,
  });
  final String text;
  final double fontSize;
  final Color color;
  final Key? textKey;
  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontFamily: 'Fredoka',
      fontSize: fontSize,
      fontWeight: FontWeight.w900,
      height: 1.05,
    );
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Stack(
        children: [
          Text(
            text,
            style: style.copyWith(
              foreground: Paint()
                ..color = Colors.black
                ..style = PaintingStyle.stroke
                ..strokeWidth = 3,
            ),
          ),
          Text(
            text,
            key: textKey,
            style: style.copyWith(
              color: color,
              shadows: const [
                Shadow(color: Colors.black, offset: Offset(0, 2)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class MzResourceBadge extends StatelessWidget {
  const MzResourceBadge({super.key, required this.value});
  final int value;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.fromLTRB(0, 4, 7, 8),
    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 6),
    decoration: mzHudDecoration(badge: true),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const MzToolIcon(Icons.grass),
        MzOutlinedText(
          '$value',
          color: const Color(0xffffe38c),
          textKey: const ValueKey('mz-catnip'),
        ),
      ],
    ),
  );
}

class MzSeedCard extends StatelessWidget {
  const MzSeedCard({
    super.key,
    required this.cat,
    this.remaining = 0,
    this.selected = false,
    this.affordable = true,
    this.reducedMotion = false,
  });
  final MzCat cat;
  final double remaining;
  final bool selected, affordable, reducedMotion;
  @override
  Widget build(BuildContext context) => AnimatedScale(
    scale: selected ? 1.025 : 1,
    duration: Duration(
      milliseconds: reducedMotion || MediaQuery.disableAnimationsOf(context)
          ? 0
          : 120,
    ),
    curve: Curves.easeOutBack,
    child: _buildCard(),
  );

  Widget _buildCard() {
    final spec = mzCats[cat]!;
    return Container(
      width: 60,
      height: 80,
      margin: const EdgeInsets.only(right: 6, bottom: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: selected ? const Color(0xffffef83) : MzArt.frame,
          width: 3,
        ),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [MzArt.woodLight, MzArt.wood],
        ),
        boxShadow: [
          const BoxShadow(color: Color(0xff442719), offset: Offset(0, 3)),
          if (selected)
            const BoxShadow(color: Color(0xaaffec71), blurRadius: 8),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Stack(
          children: [
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.all(1),
                child: Column(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(4),
                          ),
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              MzArt.paper,
                              Color.lerp(MzArt.paper, MzArt.accent(cat), .32)!,
                            ],
                          ),
                        ),
                        child: Center(
                          child: RepaintBoundary(
                            child: MzCatPortrait(cat, size: 48),
                          ),
                        ),
                      ),
                    ),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        vertical: 1,
                        horizontal: 1,
                      ),
                      decoration: const BoxDecoration(
                        color: MzArt.paper,
                        border: Border(
                          top: BorderSide(color: MzArt.woodDark, width: 1.5),
                        ),
                      ),
                      child: Column(
                        children: [
                          FittedBox(
                            child: Text(
                              spec.name,
                              maxLines: 1,
                              style: const TextStyle(
                                fontFamily: 'Nunito',
                                fontSize: 8,
                                fontWeight: FontWeight.w900,
                                color: MzArt.frame,
                              ),
                            ),
                          ),
                          MzOutlinedText(
                            '${spec.cost}',
                            fontSize: 13,
                            color: affordable
                                ? const Color(0xffe9ff9c)
                                : const Color(0xffffb090),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (!affordable)
              const Positioned.fill(
                child: ColoredBox(color: Color(0x330c2119)),
              ),
            if (remaining > 0) ...[
              Positioned.fill(
                child: CustomPaint(
                  painter: MzCooldownPainter(
                    (remaining / spec.cooldown).clamp(0.0, 1.0),
                  ),
                ),
              ),
              Positioned.fill(
                child: Center(
                  child: MzOutlinedText('${remaining.ceil()}', fontSize: 28),
                ),
              ),
            ],
            if (selected && remaining <= 0)
              const Positioned(
                top: 1,
                right: 1,
                child: Icon(
                  Icons.check_circle,
                  color: Color(0xff3d713b),
                  size: 14,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Remaining time fills from the bottom; the illustration is revealed as it drains.
class MzCooldownPainter extends CustomPainter {
  const MzCooldownPainter(this.fraction);
  final double fraction;
  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height * (1 - fraction);
    canvas.drawRect(
      Rect.fromLTRB(0, y, size.width, size.height),
      Paint()..color = const Color(0xbb071812),
    );
    canvas.drawLine(
      Offset(0, y),
      Offset(size.width, y),
      Paint()
        ..color = const Color(0xffffe79c)
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(MzCooldownPainter oldDelegate) =>
      fraction != oldDelegate.fraction;
}

class MzActionButton extends StatefulWidget {
  const MzActionButton({
    super.key,
    required this.child,
    required this.onTap,
    required this.label,
    this.active = false,
    this.dimension = 64,
  });
  final Widget child;
  final VoidCallback? onTap;
  final String label;
  final bool active;
  final double dimension;
  @override
  State<MzActionButton> createState() => _MzActionButtonState();
}

class _MzActionButtonState extends State<MzActionButton> {
  bool pressed = false;
  void depress(bool value) => setState(() => pressed = value);
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    enabled: widget.onTap != null,
    label: widget.label,
    child: Tooltip(
      message: widget.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: widget.onTap == null ? null : (_) => depress(true),
        onTapUp: widget.onTap == null ? null : (_) => depress(false),
        onTapCancel: () => depress(false),
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 80),
          transform: Matrix4.translationValues(0, pressed ? 4 : 0, 0),
          constraints: BoxConstraints(
            minWidth: widget.dimension,
            minHeight: widget.dimension,
          ),
          padding: const EdgeInsets.all(3),
          decoration: mzActionDecoration(
            pressed: pressed,
            active: widget.active,
            enabled: widget.onTap != null,
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0x99fff1bc), width: 1),
            ),
            child: IconTheme(
              data: const IconThemeData(color: Color(0xff402b20)),
              child: DefaultTextStyle(
                style: const TextStyle(
                  fontFamily: 'Nunito',
                  color: Color(0xff402b20),
                  fontWeight: FontWeight.w900,
                  fontSize: 10,
                ),
                child: widget.child,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// Illustrated inventory tools, using the same outline and lighting as the cats.
class MzToolIcon extends StatelessWidget {
  const MzToolIcon(this.icon, {super.key});
  final IconData icon;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 30,
    height: 30,
    child: CustomPaint(painter: _ToolArt(icon)),
  );
}

class _ToolArt extends CustomPainter {
  const _ToolArt(this.icon);
  final IconData icon;
  @override
  void paint(Canvas c, Size size) {
    c.save();
    c.scale(size.width / 40, size.height / 40);
    if (icon == Icons.grass) {
      mzPaintCatnip(c, const Offset(20, 20), 36);
    } else if (icon == Icons.home_outlined) {
      mzArtBox(
        c,
        const Rect.fromLTWH(9, 17, 23, 18),
        MzArt.woodLight,
        radius: 2,
      );
      mzArtShape(
        c,
        Path()
          ..moveTo(4, 19)
          ..lineTo(20, 4)
          ..lineTo(36, 19)
          ..lineTo(32, 22)
          ..lineTo(20, 11)
          ..lineTo(8, 22)
          ..close(),
        const Color(0xffbc674b),
        stroke: 2,
      );
      mzArtBox(
        c,
        const Rect.fromLTWH(16, 23, 8, 12),
        MzArt.woodDark,
        radius: 3,
        stroke: 1.4,
      );
    } else if (icon == Icons.pause_circle_outline) {
      mzArtOval(c, const Rect.fromLTWH(4, 4, 32, 32), MzArt.paper, stroke: 2.4);
      for (final x in [13.0, 23.0]) {
        mzArtBox(
          c,
          Rect.fromLTWH(x, 11, 4, 18),
          MzArt.woodDark,
          radius: 1,
          stroke: 0,
        );
      }
    } else if (icon == Icons.ads_click) {
      mzArtLine(
        c,
        Path()
          ..moveTo(25, 16)
          ..lineTo(35, 6),
        const Color(0xffef7153),
        2,
      );
      mzArtOval(
        c,
        const Rect.fromLTWH(32, 2, 6, 6),
        const Color(0xffff5c50),
        stroke: 0,
      );
      c.save();
      c.translate(20, 20);
      c.rotate(.65);
      c.translate(-20, -20);
      mzArtBox(
        c,
        const Rect.fromLTWH(13, 8, 14, 27),
        MzArt.ladyMask,
        radius: 4,
        material: MzMaterial.metal,
      );
      mzArtBox(
        c,
        const Rect.fromLTWH(13, 8, 14, 6),
        const Color(0xffe8b570),
        radius: 2,
      );
      mzArtOval(c, const Rect.fromLTWH(17, 20, 6, 6), MzArt.pink, stroke: 1);
      c.restore();
    } else if (icon == Icons.water_drop_outlined) {
      mzArtBox(
        c,
        const Rect.fromLTWH(9, 14, 21, 23),
        const Color(0xff8ed2df),
        radius: 6,
        material: MzMaterial.ice,
      );
      mzArtShape(
        c,
        Path()
          ..moveTo(13, 15)
          ..lineTo(13, 5)
          ..lineTo(31, 5)
          ..lineTo(35, 10)
          ..lineTo(25, 10)
          ..lineTo(22, 16)
          ..close(),
        MzArt.ladyCrown,
        stroke: 2,
      );
      mzArtLine(
        c,
        Path()
          ..moveTo(24, 11)
          ..quadraticBezierTo(29, 19, 32, 16),
        MzArt.ink,
        2,
      );
      mzArtOval(c, const Rect.fromLTWH(15, 22, 8, 10), MzArt.paper, stroke: 1);
    } else if (icon == Icons.back_hand_outlined) {
      for (final p in [
        const Offset(10, 12),
        const Offset(20, 8),
        const Offset(30, 12),
      ]) {
        mzArtOval(
          c,
          Rect.fromCenter(center: p, width: 9, height: 12),
          MzArt.maruFur,
          material: MzMaterial.fur,
          stroke: 1.5,
        );
      }
      mzArtOval(
        c,
        const Rect.fromLTWH(7, 19, 26, 17),
        MzArt.maruFur,
        material: MzMaterial.fur,
        stroke: 2,
      );
      mzArtOval(c, const Rect.fromLTWH(14, 22, 12, 10), MzArt.pink, stroke: 1);
    } else if (icon == Icons.set_meal_outlined ||
        icon == Icons.add_circle_outline) {
      mzBox(c, const Rect.fromLTWH(5, 12, 30, 20), const Color(0xffb8d7cb), 4);
      mzOval(c, const Rect.fromLTWH(5, 6, 30, 12), const Color(0xffeff6de), 2);
      mzBox(c, const Rect.fromLTWH(5, 18, 30, 10), const Color(0xff58a79d), 1);
      mzShape(
        c,
        Path()
          ..moveTo(13, 23)
          ..quadraticBezierTo(21, 16, 25, 23)
          ..quadraticBezierTo(21, 29, 13, 23)
          ..lineTo(9, 19)
          ..lineTo(9, 27)
          ..close(),
        const Color(0xffffdf82),
        1,
      );
    } else if (icon == Icons.yard_outlined) {
      c.save();
      c.translate(20, 20);
      c.rotate(.4);
      c.translate(-20, -20);
      mzBox(c, const Rect.fromLTWH(17, 9, 6, 20), const Color(0xffb2753c), 2);
      mzBox(c, const Rect.fromLTWH(13, 3, 14, 9), const Color(0xffefa556), 3);
      mzShape(
        c,
        Path()
          ..moveTo(12, 25)
          ..lineTo(28, 25)
          ..lineTo(28, 33)
          ..quadraticBezierTo(20, 41, 12, 33)
          ..close(),
        const Color(0xffcedee2),
        2,
      );
      c.restore();
    } else if (icon == Icons.auto_awesome) {
      mzShape(
        c,
        Path()
          ..moveTo(20, 3)
          ..lineTo(24, 14)
          ..lineTo(36, 16)
          ..lineTo(27, 24)
          ..lineTo(30, 36)
          ..lineTo(20, 29)
          ..lineTo(10, 36)
          ..lineTo(13, 24)
          ..lineTo(4, 16)
          ..lineTo(16, 14)
          ..close(),
        const Color(0xffffe67b),
        2,
      );
    } else {
      final painter = TextPainter(
        text: TextSpan(
          text: String.fromCharCode(icon.codePoint),
          style: TextStyle(
            fontFamily: icon.fontFamily,
            package: icon.fontPackage,
            fontSize: 32,
            color: const Color(0xff402b20),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      painter.paint(c, const Offset(4, 3));
    }
    c.restore();
  }

  @override
  bool shouldRepaint(_ToolArt oldDelegate) => icon != oldDelegate.icon;
}
