import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'mz_catalog.dart';
import 'mz_character_art.dart';
import 'mz_progress.dart';
import 'mz_simulation.dart';
import 'mz_levels.dart';

/// Read-only receipt derived from the existing completion transaction.
class MzResultReceipt {
  MzResultReceipt(MzProgress p, MzSimulation s)
    : cookiesBefore = p.cookies,
      mintsBefore = p.mints,
      highestBefore = p.campaignCompleted,
      starsBefore = (p.stars['${s.level.id}'] as int?) ?? 0,
      catsBefore = mzUnlockedCats(p.highest).toSet();
  final int cookiesBefore, mintsBefore, highestBefore, starsBefore;
  final Set<MzCat> catsBefore;
  int cookies = 0, mints = 0, starsAdded = 0, highestAfter = 0;
  List<MzCat> newCards = [];
  void resolve(MzProgress p, MzSimulation s) {
    cookies = math.max(0, p.cookies - cookiesBefore);
    mints = math.max(0, p.mints - mintsBefore);
    highestAfter = p.campaignCompleted;
    starsAdded = math.max(
      0,
      ((p.stars['${s.level.id}'] as int?) ?? 0) - starsBefore,
    );
    newCards = mzUnlockedCats(
      p.highest,
    ).where((c) => !catsBefore.contains(c)).toList();
  }
}

class MzResultPanel extends StatefulWidget {
  const MzResultPanel({
    super.key,
    required this.sim,
    required this.receipt,
    required this.reducedMotion,
    required this.saving,
    required this.completed,
    required this.onRetry,
    required this.onLeave,
    required this.onSave,
    required this.onAlmanac,
    this.onNext,
    this.error,
    this.showNewCards = true,
  });
  final MzSimulation sim;
  final MzResultReceipt? receipt;
  final bool reducedMotion, saving, completed;
  final VoidCallback onRetry, onLeave, onSave;
  final VoidCallback? onNext;
  final ValueChanged<MzCat> onAlmanac;
  final String? error;
  final bool showNewCards;
  @override
  State<MzResultPanel> createState() => _MzResultPanelState();
}

class _MzResultPanelState extends State<MzResultPanel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _reveal = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );
  bool get reduce =>
      widget.reducedMotion ||
      MediaQuery.disableAnimationsOf(context) ||
      MediaQuery.accessibleNavigationOf(context);
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (reduce) {
      _reveal.stop();
      _reveal.value = 1;
    } else if (_reveal.value == 0) {
      _reveal.forward();
    }
  }

  @override
  void didUpdateWidget(covariant MzResultPanel old) {
    super.didUpdateWidget(old);
    if (reduce) {
      _reveal.stop();
      _reveal.value = 1;
    }
  }

  @override
  void dispose() {
    _reveal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.sim, r = widget.receipt;
    final win = s.won;
    final gold = win ? const Color(0xffffca65) : const Color(0xffa1bed0);
    return ColoredBox(
      color: const Color(0xd51c302b),
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, b) => Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 800,
                maxHeight: math.max(80, b.maxHeight - 20),
              ),
              child: Container(
                margin: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xfffff6db), Color(0xffead6ac)],
                  ),
                  border: Border.all(color: const Color(0xff785137), width: 5),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0xff101e19),
                      offset: Offset(0, 8),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 8,
                              ),
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: win
                                      ? const [
                                          Color(0xff42664a),
                                          Color(0xff264735),
                                        ]
                                      : const [
                                          Color(0xff667b8c),
                                          Color(0xff3c4e61),
                                        ],
                                ),
                                border: Border.all(color: gold, width: 3),
                                borderRadius: BorderRadius.circular(18),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x554c3526),
                                    offset: Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Semantics(
                                liveRegion: true,
                                header: true,
                                child: Text(
                                  win
                                      ? '¡Victoria, michis!'
                                      : 'Esta vez ganó la horda',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontFamily: 'Fredoka',
                                    fontWeight: FontWeight.w700,
                                    fontSize: 28,
                                    color: const Color(0xffffefc5),
                                  ),
                                ),
                              ),
                            ),
                            Text(
                              s.level.title,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                color: Color(0xff79583f),
                              ),
                            ),
                            const SizedBox(height: 10),
                            LayoutBuilder(
                              builder: (context, b) {
                                final art = RepaintBoundary(
                                  child: CustomPaint(
                                    key: const ValueKey('result-celebration'),
                                    size: Size(
                                      b.maxWidth > 610 ? 240 : b.maxWidth,
                                      b.maxWidth > 610 ? 140 : 150,
                                    ),
                                    painter: _ResultArt(win, _reveal, !reduce),
                                  ),
                                );
                                final summary = Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (win)
                                      Semantics(
                                        label: '${s.stars} de 3 estrellas',
                                        child: RepaintBoundary(
                                          child: CustomPaint(
                                            size: const Size(144, 48),
                                            painter: _ResultStars(
                                              s.stars,
                                              _reveal,
                                              !reduce,
                                            ),
                                          ),
                                        ),
                                      ),
                                    Text(
                                      win
                                          ? 'El jardín está a salvo.'
                                          : 'Los invasores alcanzaron la casa.',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 17,
                                      ),
                                    ),
                                    Text(
                                      '${s.kills} invasores derrotados · ${s.losses} gatos perdidos',
                                      textAlign: TextAlign.center,
                                    ),
                                    if (s.level.mode == MzMode.survival)
                                      Text(
                                        'Oleada alcanzada: ${s.wave}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    if (widget.completed && r != null) ...[
                                      const SizedBox(height: 10),
                                      Wrap(
                                        alignment: WrapAlignment.center,
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: [
                                          if (r.cookies > 0)
                                            _reward(
                                              Icons.cookie_rounded,
                                              '+${r.cookies}',
                                              'Galletitas',
                                            ),
                                          if (r.mints > 0)
                                            _reward(
                                              Icons.spa_rounded,
                                              '+${r.mints}',
                                              'Mentitas',
                                            ),
                                          if (s.level.mode == MzMode.campaign &&
                                              r.starsAdded > 0)
                                            _reward(
                                              Icons.star_rounded,
                                              '+${r.starsAdded}',
                                              'Estrellas nuevas',
                                            ),
                                        ],
                                      ),
                                      if (r.cookies == 0 &&
                                          r.mints == 0 &&
                                          r.starsAdded == 0)
                                        const Text(
                                          'Sin recompensas nuevas en esta partida.',
                                          textAlign: TextAlign.center,
                                        ),
                                      if (s.level.mode == MzMode.campaign &&
                                          r.highestAfter > r.highestBefore)
                                        Text(
                                          'Campaña: ${r.highestAfter}/${mzCampaign.length} niveles completados',
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                    ],
                                  ],
                                );
                                return b.maxWidth > 610
                                    ? Row(
                                        children: [
                                          art,
                                          const SizedBox(width: 16),
                                          Expanded(child: summary),
                                        ],
                                      )
                                    : Column(children: [art, summary]);
                              },
                            ),
                            if (widget.completed && r != null)
                              for (final c
                                  in widget.showNewCards
                                      ? r.newCards
                                      : <MzCat>[])
                                Container(
                                  key: ValueKey('result-new-${c.name}'),
                                  margin: const EdgeInsets.only(top: 10),
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xffffe8a5),
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(
                                      color: const Color(0xffb77c2c),
                                      width: 3,
                                    ),
                                  ),
                                  child: Wrap(
                                    alignment: WrapAlignment.center,
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    spacing: 14,
                                    runSpacing: 8,
                                    children: [
                                      SizedBox(
                                        width: 80,
                                        height: 80,
                                        child: CustomPaint(
                                          painter: _CardArt(c),
                                        ),
                                      ),
                                      Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Text(
                                            '¡Nueva carta desbloqueada!',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              fontFamily: 'Fredoka',
                                              fontSize: 19,
                                            ),
                                          ),
                                          Text(
                                            mzCats[c]!.name,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                          TextButton(
                                            style: TextButton.styleFrom(
                                              foregroundColor: const Color(
                                                0xff31513a,
                                              ),
                                              minimumSize: const Size(160, 48),
                                              textStyle: const TextStyle(
                                                fontFamily: 'Nunito',
                                                fontWeight: FontWeight.w900,
                                              ),
                                            ),
                                            onPressed: () =>
                                                widget.onAlmanac(c),
                                            child: const Text(
                                              'Ver en el almanaque',
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                            if (widget.error != null)
                              Padding(
                                padding: const EdgeInsets.all(8),
                                child: Text(
                                  widget.error!,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Color(0xff9c3029),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
                      child: _actions(gold, win),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _actions(Color gold, bool win) => widget.saving
      ? Semantics(
          label: 'Guardando resultado',
          child: const CircularProgressIndicator(),
        )
      : Wrap(
          alignment: WrapAlignment.center,
          spacing: 10,
          runSpacing: 10,
          children: [
            if (!widget.completed)
              _button('Reintentar guardado', widget.onSave, gold),
            if (widget.completed && widget.onNext != null)
              _button('Siguiente nivel', widget.onNext!, gold),
            if (widget.completed)
              _button(
                win ? 'Jugar otra vez' : 'Reintentar nivel',
                widget.onRetry,
                gold,
              ),
            _button('Volver al mapa', widget.onLeave, const Color(0xffc6dab5)),
          ],
        );

  Widget _reward(IconData symbol, String value, String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: const Color(0xff355940),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xffbf974e), width: 2),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(symbol, color: const Color(0xffffefc3), size: 20),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            '$value $label',
            style: const TextStyle(
              color: Color(0xffffefc3),
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    ),
  );
  Widget _button(String text, VoidCallback tap, Color color) => Container(
    decoration: BoxDecoration(
      color: const Color(0xff795238),
      borderRadius: BorderRadius.circular(14),
      boxShadow: const [
        BoxShadow(color: Color(0xff573e2d), offset: Offset(0, 4)),
      ],
    ),
    padding: const EdgeInsets.only(bottom: 3),
    child: FilledButton(
      style: FilledButton.styleFrom(
        backgroundColor: color,
        foregroundColor: const Color(0xff332e23),
        minimumSize: const Size(140, 48),
        textStyle: const TextStyle(
          fontFamily: 'Nunito',
          fontWeight: FontWeight.w900,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onPressed: tap,
      child: Text(text, textAlign: TextAlign.center),
    ),
  );
}

class _CardArt extends CustomPainter {
  const _CardArt(this.cat);
  final MzCat cat;
  @override
  void paint(Canvas c, Size s) => mzPaintCharacter(
    c,
    Offset(s.width / 2, s.height * .72),
    s.shortestSide * .83,
    cat: cat,
    walking: false,
    armed: true,
  );
  @override
  bool shouldRepaint(_CardArt old) => cat != old.cat;
}

class _ResultArt extends CustomPainter {
  _ResultArt(this.win, this.reveal, this.animate)
    : super(repaint: animate ? reveal : null);
  final bool win, animate;
  final Animation<double> reveal;
  double get t => animate ? reveal.value : 1;
  @override
  void paint(Canvas c, Size s) {
    final center = Offset(s.width / 2, s.height * .55);
    c.drawOval(
      Rect.fromCenter(center: center, width: 220, height: 125),
      Paint()
        ..shader =
            RadialGradient(
              colors: [
                win ? const Color(0xffffdc7b) : const Color(0xffb1c8d1),
                const Color(0x00ffefab),
              ],
            ).createShader(
              Rect.fromCenter(center: center, width: 220, height: 125),
            ),
    );
    if (win && animate && t < 1) {
      for (var i = 0; i < 12; i++) {
        final a = i * math.pi / 6;
        final p = center + Offset(math.cos(a), math.sin(a)) * 90 * t;
        c.drawCircle(
          p,
          2.5 * (1 - t),
          Paint()
            ..color = i.isEven
                ? const Color(0xffcf9337)
                : const Color(0xff75a255),
        );
      }
    }
    final bounce = animate ? math.sin(t * math.pi * 4) * (1 - t) * 7 : 0.0;
    mzPaintCharacter(
      c,
      Offset(center.dx - 50, s.height - 34 - bounce),
      100,
      cat: win ? MzCat.sunflower : MzCat.barrier,
      walking: false,
      phase: animate ? t * 2 : 0,
      hurt: win ? 0 : .3,
    );
    mzPaintCharacter(
      c,
      Offset(center.dx + 47, s.height - 34 + bounce),
      94,
      cat: MzCat.launcher,
      walking: false,
      phase: animate ? t * 2 + 1 : 0,
      hurt: win ? 0 : .3,
    );
    final tp = TextPainter(
      text: TextSpan(
        text: win
            ? 'Maru y Lady celebran contigo'
            : 'Maru y Lady volverán a intentarlo',
        style: const TextStyle(
          fontFamily: 'Nunito',
          color: Color(0xff4a5140),
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: s.width);
    tp.paint(c, Offset((s.width - tp.width) / 2, s.height - 16));
  }

  @override
  bool shouldRepaint(_ResultArt old) =>
      win != old.win || animate != old.animate;
}

class _ResultStars extends CustomPainter {
  _ResultStars(this.stars, this.reveal, this.animate)
    : super(repaint: animate ? reveal : null);
  final int stars;
  final Animation<double> reveal;
  final bool animate;
  static final Path shape = _star();
  static Path _star() {
    final p = Path();
    for (var i = 0; i < 10; i++) {
      final a = -math.pi / 2 + i * math.pi / 5, r = i.isEven ? 19.0 : 9.0;
      final x = math.cos(a) * r, y = math.sin(a) * r;
      if (i == 0) {
        p.moveTo(x, y);
      } else {
        p.lineTo(x, y);
      }
    }
    return p..close();
  }

  @override
  void paint(Canvas c, Size s) {
    for (var i = 0; i < 3; i++) {
      final t = animate ? ((reveal.value - i * .14) / .5).clamp(0.0, 1.0) : 1.0;
      c.save();
      c.translate(s.width * (i + .5) / 3, s.height / 2);
      c.scale(.65 + .35 * Curves.easeOutBack.transform(t));
      c.drawPath(
        shape,
        Paint()
          ..color = i < stars
              ? const Color(0xffdda035)
              : const Color(0xff9a907a)
          ..style = i < stars ? PaintingStyle.fill : PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeJoin = StrokeJoin.round,
      );
      if (i < stars) {
        c.drawPath(
          shape,
          Paint()
            ..color = const Color(0xffb97c25)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.3
            ..strokeJoin = StrokeJoin.round,
        );
      }
      c.restore();
    }
  }

  @override
  bool shouldRepaint(_ResultStars old) =>
      stars != old.stars || animate != old.animate;
}
