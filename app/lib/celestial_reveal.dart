import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'cat_character.dart';
import 'card_media.dart';
import 'store.dart';
import 'game_audio.dart';

class CelestialRevealDialog extends StatefulWidget {
  final int cardId, copies;
  final String collectionId;
  const CelestialRevealDialog({
    super.key,
    required this.cardId,
    required this.copies,
    required this.collectionId,
  });
  @override
  State<CelestialRevealDialog> createState() => _CelestialRevealDialogState();
}

class _CelestialRevealDialogState extends State<CelestialRevealDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _reveal = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 6400),
  );
  bool _started = false, _burstSound = false;
  @override
  void initState() {
    super.initState();
    _reveal.addListener(() {
      if (!_burstSound && _reveal.value >= .46) {
        _burstSound = true;
        GameAudio.instance.play(GameSfx.reveal);
        HapticFeedback.heavyImpact();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      if (MediaQuery.disableAnimationsOf(context)) {
        _reveal.value = 1;
      } else {
        _reveal.forward();
      }
    }
  }

  @override
  void dispose() {
    _reveal.dispose();
    super.dispose();
  }

  double _part(double t, double start, double span) =>
      ((t - start) / span).clamp(0.0, 1.0);
  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: const Color(0xff171a36),
    insetPadding: const EdgeInsets.all(16),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(28),
      side: const BorderSide(color: Color(0xffa0fff2), width: 2),
    ),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 410),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: AnimatedBuilder(
            animation: _reveal,
            builder: (context, _) {
              final t = _reveal.value;
              final reduced = MediaQuery.disableAnimationsOf(context);
              final revealed = t >= .56;
              final arrival = Curves.easeOutCubic.transform(_part(t, .56, .16));
              final card = celestialCard(widget.cardId)!;
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    revealed
                        ? '¡CELESTIAL!'
                        : 'Algo brilla entre las estrellas…',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xffb4fff3),
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      letterSpacing: .7,
                    ),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    'Una sorpresa de 1 entre 100',
                    style: TextStyle(color: Color(0xffe8d7a0), fontSize: 12),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 285,
                    child: LayoutBuilder(
                      builder: (context, c) => Stack(
                        alignment: Alignment.center,
                        clipBehavior: Clip.hardEdge,
                        children: [
                          Positioned.fill(
                            child: IgnorePointer(
                              child: CustomPaint(
                                painter: CelestialBurstPainter(reduced ? 1 : t),
                              ),
                            ),
                          ),
                          if (t < .56)
                            Opacity(
                              opacity: 1 - _part(t, .42, .14),
                              child: ImageFiltered(
                                imageFilter: ui.ImageFilter.blur(
                                  sigmaX: _part(t, .23, .25) * 9,
                                  sigmaY: _part(t, .23, .25) * 9,
                                ),
                                child: Transform.scale(
                                  scale:
                                      1 +
                                      (reduced
                                          ? 0
                                          : math.sin(t * math.pi * 9) * .025),
                                  child: Container(
                                    key: const ValueKey('celestial-mystery'),
                                    width: 174,
                                    height: 238,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(22),
                                      gradient: const LinearGradient(
                                        colors: [
                                          Color(0xff253c66),
                                          Color(0xff563982),
                                        ],
                                      ),
                                      border: Border.all(
                                        color: const Color(0xffb7fff0),
                                        width: 3,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xff83ecff)
                                              .withValues(
                                                alpha:
                                                    .25 +
                                                    _part(t, .2, .25) * .5,
                                              ),
                                          blurRadius: 28,
                                        ),
                                      ],
                                    ),
                                    child: const Center(
                                      child: Text(
                                        '?',
                                        style: TextStyle(
                                          fontSize: 96,
                                          fontWeight: FontWeight.w900,
                                          color: Color(0xffffe7a1),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          if (revealed)
                            Transform.scale(
                              scale: reduced ? 1 : .6 + arrival * .4,
                              child: Container(
                                key: const ValueKey('celestial-revealed'),
                                width: math.min(205, c.maxWidth * .75),
                                height: 254,
                                padding: const EdgeInsets.all(9),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(20),
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xffa8ffe8),
                                      Color(0xff3d78a1),
                                      Color(0xff715aa5),
                                    ],
                                  ),
                                  border: Border.all(
                                    color: const Color(0xffffe29b),
                                    width: 3,
                                  ),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0x7785fff0),
                                      blurRadius: 22,
                                    ),
                                  ],
                                ),
                                child: Column(
                                  children: [
                                    Expanded(
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(10),
                                        child: ColoredBox(
                                          color: const Color(0xff171a36),
                                          child: CardMedia(
                                            cardId: widget.cardId,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      card.name,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    const Text(
                                      '✦ CELESTIAL ✦',
                                      style: TextStyle(
                                        color: Color(0xffffe29b),
                                        fontSize: 9,
                                        letterSpacing: 1.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          if (revealed) ...[
                            Positioned(
                              bottom: 0,
                              left: -42 * (1 - arrival),
                              child: CatActor(
                                cat: CatKind.maru,
                                size: 69,
                                action: CatAction.pack,
                                active: true,
                                showLabel: false,
                              ),
                            ),
                            Positioned(
                              bottom: 0,
                              right: -42 * (1 - arrival),
                              child: CatActor(
                                cat: CatKind.lady,
                                size: 69,
                                action: CatAction.pack,
                                active: true,
                                showLabel: false,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  if (revealed) ...[
                    _Reaction(name: 'Maru', text: card.maru),
                    const SizedBox(height: 5),
                    _Reaction(name: 'Lady', text: card.lady),
                    const SizedBox(height: 10),
                    Text(
                      'VOL. ${card.volume} · ×${widget.copies} · Guardada en tu colección',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xffd3def2),
                        fontSize: 11,
                      ),
                    ),
                  ] else
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        'Maru y Lady sienten una energía especial…',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xffd3def2),
                          fontSize: 12,
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      key: const ValueKey('celestial-continue'),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xffb4fff3),
                        foregroundColor: const Color(0xff172640),
                      ),
                      onPressed: revealed
                          ? () => Navigator.pop(context)
                          : () => _reveal.value = 1,
                      icon: Icon(
                        revealed
                            ? Icons.collections_bookmark_rounded
                            : Icons.auto_awesome_rounded,
                      ),
                      label: Text(revealed ? '¡ME LA LLEVO!' : 'Revelar ahora'),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    ),
  );
}

class _Reaction extends StatelessWidget {
  final String name, text;
  const _Reaction({required this.name, required this.text});
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(
      color: const Color(0xff29314f),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(
      '$name: $text',
      style: const TextStyle(color: Color(0xffffecc5), fontSize: 12),
      textAlign: TextAlign.center,
    ),
  );
}

class CelestialBurstPainter extends CustomPainter {
  final double t;
  const CelestialBurstPainter(this.t);
  @override
  void paint(Canvas c, Size s) {
    final center = Offset(s.width / 2, s.height / 2);
    final burst = ((t - .45) / .22).clamp(0.0, 1.0);
    final fade = 1 - ((t - .67) / .22).clamp(0.0, 1.0);
    final palette = [
      const Color(0xffa0fff2),
      const Color(0xffffdc92),
      const Color(0xffc1a5ff),
    ];
    for (var i = 0; i < 38; i++) {
      final angle = i * 2.39996;
      final direction = Offset(math.cos(angle), math.sin(angle));
      final r = burst * (s.width * .45 + (i % 5) * 16);
      final p = Paint()
        ..color = palette[i % 3].withValues(alpha: burst * fade * .8)
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round;
      if (burst > 0 && fade > 0) {
        c.drawLine(
          center + direction * r,
          center + direction * (r + 9 + i % 6),
          p,
        );
      }
      final star = Offset(
        s.width * ((i * 37 % 97) / 100),
        s.height * ((i * 23 % 91) / 100),
      );
      final glow = .15 + .25 * (.5 + .5 * math.sin(t * math.pi * 4 + i));
      c.drawCircle(
        star,
        i % 3 == 0 ? 1.7 : .9,
        Paint()..color = palette[i % 3].withValues(alpha: glow),
      );
    }
    if (burst > 0 && fade > 0) {
      c.drawCircle(
        center,
        20 + burst * s.width * .7,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = const Color(0xffd7fff4).withValues(alpha: fade * .65),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CelestialBurstPainter old) => old.t != t;
}
