import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'mz_art_style.dart';
import 'mz_catalog.dart';
import 'mz_character_art.dart';
import 'mz_menu_art.dart';

/// Presentation after a persisted first world victory. No progress is written.
class MzWorldTransition extends StatefulWidget {
  const MzWorldTransition({
    super.key,
    required this.from,
    this.to,
    required this.reducedMotion,
    required this.onContinue,
  });
  final MzWorld from;
  final MzWorld? to;
  final bool reducedMotion;
  final VoidCallback onContinue;
  @override
  State<MzWorldTransition> createState() => _MzWorldTransitionState();
}

class _MzWorldTransitionState extends State<MzWorldTransition>
    with SingleTickerProviderStateMixin {
  late final controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  );
  bool get reduced =>
      widget.reducedMotion ||
      MediaQuery.disableAnimationsOf(context) ||
      MediaQuery.accessibleNavigationOf(context);
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (reduced) {
      controller.stop();
      controller.value = 1;
    } else if (controller.value == 0) {
      controller.forward();
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: MzArt.paper,
    insetPadding: const EdgeInsets.all(12),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(24),
      side: const BorderSide(color: MzArt.woodDark, width: 5),
    ),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 660),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.to == null
                        ? '¡Campaña completada!'
                        : '¡Mundo completado!',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'Fredoka',
                      fontWeight: FontWeight.w700,
                      fontSize: 26,
                      color: MzArt.woodDark,
                    ),
                  ),
                  Text(widget.from.title, textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: SizedBox(
                      height: 180,
                      child: AnimatedBuilder(
                        animation: controller,
                        builder: (context, _) {
                          final t = Curves.easeInOut.transform(
                            controller.value,
                          );
                          return Stack(
                            fit: StackFit.expand,
                            children: [
                              MzWorldPostcard(widget.from.index, height: 180),
                              if (widget.to != null)
                                Opacity(
                                  opacity: t,
                                  child: MzWorldPostcard(
                                    widget.to!.index,
                                    height: 180,
                                  ),
                                ),
                              RepaintBoundary(
                                child: CustomPaint(
                                  painter: _TransitionHeroes(
                                    reduced ? 1 : t,
                                    reduced,
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.to == null
                        ? 'Maru y Lady han defendido los seis mundos.'
                        : 'Próxima aventura: ${widget.to!.title}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                    ),
                  ),
                  const Text(
                    'Tus recompensas ya están guardadas.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 12,
              runSpacing: 8,
              children: [
                TextButton(
                  onPressed: widget.onContinue,
                  style: TextButton.styleFrom(minimumSize: const Size(96, 48)),
                  child: const Text('Omitir'),
                ),
                FilledButton(
                  onPressed: widget.onContinue,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(120, 48),
                    backgroundColor: MzArt.woodDark,
                  ),
                  child: const Text('Continuar'),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _TransitionHeroes extends CustomPainter {
  const _TransitionHeroes(this.t, this.reduced);
  final double t;
  final bool reduced;
  @override
  void paint(Canvas c, Size size) {
    final bounce = reduced ? 0.0 : math.sin(t * math.pi * 3) * (1 - t) * 12;
    for (var i = 0; i < 2; i++) {
      mzPaintCharacter(
        c,
        Offset(size.width * (.38 + i * .25), size.height * .73 - bounce),
        math.min(100, size.width * .28),
        cat: i == 0 ? MzCat.sunflower : MzCat.launcher,
        phase: reduced ? 0 : t * 3 + i,
      );
    }
    for (var i = 0; i < 5; i++) {
      c.drawCircle(
        Offset(size.width * (.12 + i * .19), size.height * (.13 + i % 2 * .12)),
        3 + (reduced ? 0 : math.sin(t * math.pi)),
        Paint()..color = MzArt.gold,
      );
    }
  }

  @override
  bool shouldRepaint(_TransitionHeroes old) =>
      old.t != t || old.reduced != reduced;
}
