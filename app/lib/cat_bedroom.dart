import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'cat_character.dart';
import 'card_media.dart';
import 'store.dart';
import 'house_day_cycle.dart';
import 'paw_background.dart';

Color bedroomColor(String palette) => switch (palette) {
  'rose' => const Color(0xffd791a5),
  'lavender' => const Color(0xffa296cd),
  'sunset' => const Color(0xffdda967),
  _ => const Color(0xff83ad98),
};

class CatBedroomScene extends StatelessWidget {
  final GameStore store;
  final CatKind cat;
  final DateTime Function()? clock;
  const CatBedroomScene({
    super.key,
    required this.store,
    required this.cat,
    this.clock,
  });

  @override
  Widget build(BuildContext context) {
    final room = store.catCare.bedroom(cat);
    final name = cat == CatKind.maru ? 'Maru' : 'Lady';
    final poster = room.poster;
    return HouseDayCycle(
      clock: clock,
      builder: (context, light) => LayoutBuilder(
        builder: (context, bounds) {
          final width = bounds.maxWidth;
          final height = (width * .85).clamp(310.0, 430.0);
          final catSize = math.min(224.0, width * .56);
          return ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: SizedBox(
              height: height,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: RepaintBoundary(
                      child: CustomPaint(painter: _BedroomPainter(room, light)),
                    ),
                  ),
                  Positioned(
                    left: 18,
                    top: 18,
                    child: Text(
                      'El dormitorio de $name',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                        color: light.text,
                      ),
                    ),
                  ),
                  Positioned(
                    left: width * .09,
                    top: height * .23,
                    width: width * .21,
                    height: height * .30,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: const Color(0xfffff5dd),
                        border: Border.all(
                          color: const Color(0xffae886a),
                          width: 5,
                        ),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x26382b28),
                            blurRadius: 8,
                            offset: Offset(2, 4),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: poster != null && (store.cards[poster] ?? 0) > 0
                            ? CardMedia(cardId: poster, thumbnail: true)
                            : const Icon(
                                Icons.pets_rounded,
                                color: Color(0xffbb8c78),
                                size: 38,
                              ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: (width - catSize) / 2,
                    bottom: height * .085,
                    child: RepaintBoundary(
                      child: CatActor(
                        cat: cat,
                        size: catSize,
                        showLabel: false,
                        showShadow: false,
                        movable: true,
                        onPet: () => store.catCare.pet(cat),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class CatBedroomControls extends StatelessWidget {
  final GameStore store;
  final CatKind cat;
  const CatBedroomControls({super.key, required this.store, required this.cat});

  @override
  Widget build(BuildContext context) {
    final care = store.catCare, room = care.bedroom(cat);
    void choose(CatBedroom next) => care.decorateBedroom(cat, next);
    Widget options(
      String label,
      Map<String, String> values,
      String selected,
      ValueChanged<String> onSelect,
    ) => Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 7),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              for (final option in values.entries)
                ChoiceChip(
                  key: ValueKey('room-${option.key}'),
                  label: Text(option.value),
                  selected: selected == option.key,
                  onSelected: (_) => onSelect(option.key),
                ),
            ],
          ),
        ],
      ),
    );
    final cards =
        store.cards.entries.where((e) => e.value > 0).map((e) => e.key).toList()
          ..sort();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Un rincón a su gusto',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        const Text(
          'La decoración se guarda por separado para Maru y Lady.',
          style: TextStyle(color: Color(0xff63796d)),
        ),
        const SizedBox(height: 16),
        options(
          'Colores del dormitorio',
          {
            'forest': 'Bosque',
            'rose': 'Rosita',
            'lavender': 'Lavanda',
            'sunset': 'Atardecer',
          },
          room.palette,
          (v) => choose(room.copyWith(palette: v)),
        ),
        options(
          'Camita',
          {'basket': 'Canastita', 'cloud': 'Nube suave', 'star': 'Estrellitas'},
          room.bed,
          (v) => choose(room.copyWith(bed: v)),
        ),
        options(
          'Alfombra',
          {'round': 'Redondita', 'paw': 'Patitas', 'none': 'Sin alfombra'},
          room.rug,
          (v) => choose(room.copyWith(rug: v)),
        ),
        options(
          'Un detalle especial',
          {'plant': 'Plantita', 'books': 'Libritos', 'toys': 'Juguetes'},
          room.decoration,
          (v) => choose(room.copyWith(decoration: v)),
        ),
        SwitchListTile(
          key: const ValueKey('room-lamp'),
          contentPadding: EdgeInsets.zero,
          title: const Text('Lamparita encendida'),
          value: room.lamp,
          onChanged: (v) => choose(room.copyWith(lamp: v)),
        ),
        const SizedBox(height: 10),
        const Text(
          'Póster de tu colección',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 126,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: cards.length + 1,
            itemBuilder: (context, i) {
              final id = i == 0 ? null : cards[i - 1];
              return Padding(
                padding: const EdgeInsets.only(right: 10),
                child: SizedBox(
                  width: 86,
                  child: Material(
                    color: room.poster == id
                        ? const Color(0xffdcefe5)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      key: ValueKey('room-poster-${id ?? 'paw'}'),
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => choose(
                        room.copyWith(poster: id, clearPoster: id == null),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Column(
                          children: [
                            Expanded(
                              child: id == null
                                  ? const Icon(
                                      Icons.pets_rounded,
                                      color: Color(0xffba9387),
                                    )
                                  : CardMedia(cardId: id, thumbnail: true),
                            ),
                            const SizedBox(height: 7),
                            Text(
                              id == null ? 'Patitas' : cardName(id),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        if (cards.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text('Al conseguir cartas podrás usarlas como póster.'),
          ),
      ],
    );
  }
}

class _BedroomPainter extends CustomPainter {
  final CatBedroom room;
  final HouseLight light;
  const _BedroomPainter(this.room, this.light);

  @override
  void paint(Canvas c, Size size) {
    c.save();
    c.scale(size.width / 400, size.height / 340);
    final accent = bedroomColor(room.palette);
    final wall = light.tint(
      Color.lerp(accent, const Color(0xfffff8eb), .82)!,
      const Color(0xff303249),
    );
    final bounds = const Rect.fromLTWH(0, 0, 400, 340);
    c.drawRect(
      bounds,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [wall, Color.lerp(wall, accent, .2)!],
        ).createShader(bounds),
    );
    const PawPatternPainter(
      spacing: 90,
      opacity: .08,
      pawScale: .8,
    ).paint(c, const Size(400, 250));
    Paint ink(Color color, [double? width]) => Paint()
      ..color = color
      ..style = width == null ? PaintingStyle.fill : PaintingStyle.stroke
      ..strokeWidth = width ?? 1
      ..strokeCap = StrokeCap.round;
    void box(Rect at, Color color, [double radius = 10]) => c.drawRRect(
      RRect.fromRectAndRadius(at, Radius.circular(radius)),
      ink(color),
    );
    final floor = light.tint(const Color(0xffcda984), const Color(0xff665965));
    c.drawRect(const Rect.fromLTWH(0, 250, 400, 90), ink(floor));
    for (var y = 264.0; y < 340; y += 23) {
      c.drawLine(
        Offset(0, y),
        Offset(400, y),
        ink(const Color(0xff987962).withValues(alpha: .3), 1),
      );
    }
    for (var x = 25.0; x < 400; x += 72) {
      c.drawLine(
        Offset(x, 250),
        Offset(x - 18, 340),
        ink(const Color(0xff987962).withValues(alpha: .25), 1),
      );
    }
    box(const Rect.fromLTWH(270, 62, 98, 128), const Color(0xfff4e4cd), 14);
    box(
      const Rect.fromLTWH(278, 70, 82, 110),
      light.tint(const Color(0xffb8dfea), const Color(0xff303b63)),
      9,
    );
    c.drawLine(
      const Offset(318, 70),
      const Offset(318, 181),
      ink(const Color(0xfff4e4cd), 4),
    );
    c.drawLine(
      const Offset(278, 123),
      const Offset(360, 123),
      ink(const Color(0xfff4e4cd), 4),
    );
    c.drawCircle(
      const Offset(340, 87),
      9,
      ink(light.night > .5 ? const Color(0xffffeed3) : const Color(0xffffd776)),
    );
    if (light.night > .5) {
      for (final point in [
        const Offset(290, 95),
        const Offset(306, 83),
        const Offset(336, 145),
        const Offset(294, 164),
      ]) {
        c.drawCircle(point, 1.5, ink(const Color(0xfffff4d6)));
      }
    }
    for (final x in [263.0, 359.0]) {
      box(Rect.fromLTWH(x, 58, 13, 137), accent, 5);
    }
    if (room.rug != 'none') {
      c.drawOval(
        const Rect.fromLTWH(74, 269, 252, 59),
        ink(Color.lerp(accent, Colors.white, .4)!),
      );
      c.drawOval(
        const Rect.fromLTWH(83, 275, 234, 44),
        ink(accent.withValues(alpha: .3), 1.5),
      );
      if (room.rug == 'paw') {
        const PawPatternPainter(spacing: 70, opacity: .25, pawScale: .55).paint(
          c
            ..save()
            ..translate(84, 279),
          const Size(215, 25),
        );
      }
      if (room.rug == 'paw') c.restore();
    }
    final bed = const Rect.fromLTWH(116, 244, 174, 65);
    if (room.bed == 'basket') {
      box(bed, const Color(0xffb68c63), 24);
      for (var y = 254.0; y < 305; y += 9) {
        c.drawLine(
          Offset(122, y),
          Offset(284, y),
          ink(const Color(0xffd2ad80), 2),
        );
      }
      c.drawOval(
        const Rect.fromLTWH(127, 239, 153, 48),
        ink(Color.lerp(accent, Colors.white, .52)!),
      );
    } else {
      box(
        bed,
        Color.lerp(accent, Colors.white, .48)!,
        room.bed == 'cloud' ? 32 : 22,
      );
      c.drawOval(
        const Rect.fromLTWH(129, 245, 147, 44),
        ink(accent.withValues(alpha: .65)),
      );
      if (room.bed == 'cloud') {
        for (var i = 0; i < 5; i++) {
          c.drawCircle(
            Offset(136 + i * 30.0, 294),
            14,
            ink(Color.lerp(accent, Colors.white, .55)!),
          );
        }
      }
      if (room.bed == 'star') {
        for (var i = 0; i < 6; i++) {
          final x = 134 + i * 26.0;
          c.drawCircle(Offset(x, 296), 3, ink(const Color(0xffffedb4)));
          c.drawLine(
            Offset(x - 5, 296),
            Offset(x + 5, 296),
            ink(const Color(0xffffedb4), 1),
          );
          c.drawLine(
            Offset(x, 291),
            Offset(x, 301),
            ink(const Color(0xffffedb4), 1),
          );
        }
      }
    }
    box(const Rect.fromLTWH(322, 224, 61, 58), const Color(0xffa27b63), 9);
    box(const Rect.fromLTWH(317, 216, 71, 14), const Color(0xffd1b094), 5);
    if (room.decoration == 'plant') {
      box(const Rect.fromLTWH(28, 252, 41, 40), const Color(0xffd7967c), 10);
      for (var i = 0; i < 5; i++) {
        final x = 33 + i * 8.0, y = 209 + (i % 2) * 15.0;
        c.drawLine(
          const Offset(49, 256),
          Offset(x, y),
          ink(const Color(0xff57826b), 3),
        );
        c.drawOval(
          Rect.fromCenter(center: Offset(x, y), width: 17, height: 31),
          ink(const Color(0xff7fa68c)),
        );
      }
    } else if (room.decoration == 'books') {
      for (var i = 0; i < 4; i++) {
        box(
          Rect.fromLTWH(22, 278 - i * 11.0, 57 - i * 3.0, 9),
          [
            accent,
            const Color(0xffb5ccce),
            const Color(0xffe3bd79),
            const Color(0xff8798b7),
          ][i],
          3,
        );
      }
    } else {
      c.drawCircle(const Offset(48, 279), 16, ink(accent));
      c.drawArc(
        const Rect.fromLTWH(32, 263, 32, 32),
        0,
        math.pi,
        false,
        ink(const Color(0xffffe2c2), 2),
      );
      c.drawOval(
        const Rect.fromLTWH(73, 280, 27, 16),
        ink(const Color(0xffaaa0bd)),
      );
      c.drawLine(
        const Offset(99, 287),
        const Offset(112, 279),
        ink(const Color(0xffaaa0bd), 2),
      );
    }
    c.drawLine(
      const Offset(352, 214),
      const Offset(352, 181),
      ink(const Color(0xff9e7d66), 4),
    );
    box(const Rect.fromLTWH(338, 173, 28, 13), const Color(0xffc6a484), 5);
    c.drawPath(
      Path()
        ..moveTo(328, 177)
        ..lineTo(338, 148)
        ..lineTo(365, 148)
        ..lineTo(377, 177)
        ..close(),
      ink(room.lamp ? const Color(0xffffd894) : accent),
    );
    if (room.lamp) {
      c.drawCircle(
        const Offset(352, 177),
        57,
        Paint()
          ..shader = RadialGradient(
            colors: [
              const Color(0xffffce7a).withValues(alpha: .24),
              const Color(0xffffce7a).withValues(alpha: 0),
            ],
          ).createShader(Rect.fromCircle(center: Offset(352, 177), radius: 57)),
      );
    }
    c.restore();
  }

  @override
  bool shouldRepaint(_BedroomPainter old) =>
      room != old.room || light != old.light;
}
