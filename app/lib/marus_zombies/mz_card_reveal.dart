import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../game_audio.dart';
import 'mz_almanac.dart';
import 'mz_catalog.dart';
import 'mz_progress.dart';
import 'mz_result.dart';

/// A presentation queue only: rewards have already been committed.
class MzCardReveal extends StatefulWidget {
  const MzCardReveal({
    super.key,
    required this.receipt,
    required this.progress,
    required this.onContinue,
    required this.onAlmanac,
  });
  final MzResultReceipt receipt;
  final MzProgress progress;
  final VoidCallback onContinue;
  final ValueChanged<MzCat> onAlmanac;
  @override
  State<MzCardReveal> createState() => _MzCardRevealState();
}

class _MzCardRevealState extends State<MzCardReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _turn = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1150),
  );
  int _index = 0;
  bool _expanded = false, _discovered = false;
  MzCat get cat => widget.receipt.newCards[_index];
  bool get reduce =>
      widget.progress.reducedMotion ||
      MediaQuery.disableAnimationsOf(context) ||
      MediaQuery.accessibleNavigationOf(context);
  @override
  void initState() {
    super.initState();
    GameAudio.instance.play(GameSfx.marusCardVictory);
    _turn.addStatusListener((s) {
      if (s == AnimationStatus.completed) {
        // Wait until a front-facing frame was actually presented.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _turn.isCompleted) _acknowledge();
        });
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (reduce) {
      _turn.value = 1;
    } else if (_turn.value == 0) {
      _turn.forward();
    }
  }

  void _acknowledge() {
    if (_discovered) return;
    _discovered = true;
    final seen =
        widget.progress.prefs.getStringList(MzAlmanacScreen.seenKey) ??
        [
          ...widget.receipt.catsBefore.map((c) => 'cat-${c.name}'),
          if (widget.progress.lion) 'lion',
        ];
    final ids = {...seen, 'cat-${cat.name}'};
    unawaited(
      widget.progress.prefs.setStringList(
        MzAlmanacScreen.seenKey,
        ids.toList(),
      ),
    );
  }

  void _continue() {
    GameAudio.instance.stopEffect(GameSfx.marusCardVictory);
    // Preserve pending discovery even when this is the first almanac visit.
    if (!_discovered &&
        widget.progress.prefs.getStringList(MzAlmanacScreen.seenKey) == null) {
      unawaited(
        widget.progress.prefs.setStringList(MzAlmanacScreen.seenKey, [
          ...widget.receipt.catsBefore.map((c) => 'cat-${c.name}'),
          if (widget.progress.lion) 'lion',
        ]),
      );
    }
    if (_index + 1 == widget.receipt.newCards.length) {
      widget.onContinue();
      return;
    }
    setState(() {
      _index++;
      _expanded = false;
      _discovered = false;
    });
    _turn.reset();
    if (reduce) {
      _turn.value = 1;
    } else {
      _turn.forward();
    }
  }

  @override
  void dispose() {
    GameAudio.instance.stopEffect(GameSfx.marusCardVictory);
    _turn.dispose();
    super.dispose();
  }

  Widget _card() {
    final frontFace = RepaintBoundary(
      child: MzCollectibleCard(
        key: const ValueKey('reveal-front'),
        cat: cat,
        expanded: _expanded,
      ),
    );
    final backFace = RepaintBoundary(
      child: Container(
        key: const ValueKey('reveal-back'),
        width: double.infinity,
        height: 290,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xff366552), Color(0xff19392f)],
          ),
          border: Border.all(color: const Color(0xffd69e54), width: 9),
          borderRadius: BorderRadius.circular(22),
          boxShadow: const [
            BoxShadow(color: Color(0x997be9ad), blurRadius: 20),
          ],
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.pets, size: 85, color: Color(0xffffd68c)),
            Text(
              'MARUS',
              style: TextStyle(
                fontFamily: 'Fredoka',
                color: Color(0xffffd68c),
                fontSize: 29,
              ),
            ),
            Text('VS ZOMBIES', style: TextStyle(color: Color(0xffffe6b3))),
          ],
        ),
      ),
    );
    return AnimatedBuilder(
      animation: _turn,
      builder: (context, _) {
        final t = _turn.value, front = t >= .5;
        final angle = math.pi * Curves.easeInOutCubic.transform(t);
        final face = front ? frontFace : backFace;
        return Transform.scale(
          scale: reduce || _expanded
              ? 1
              : .5 + .5 * Curves.easeOutBack.transform(t),
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, .0015)
              ..rotateY(_expanded ? 0 : angle),
            child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..rotateY(front && !_expanded ? math.pi : 0),
              child: Semantics(
                button: true,
                label: front
                    ? 'Conocer a ${mzCats[cat]!.name}'
                    : 'Revelar carta',
                child: GestureDetector(
                  key: const ValueKey('reveal-card'),
                  onTap: () {
                    if (!_turn.isCompleted) {
                      _turn.value = 1;
                      return;
                    }
                    _acknowledge();
                    setState(() => _expanded = true);
                  },
                  child: AnimatedSize(
                    duration: Duration(milliseconds: reduce ? 0 : 320),
                    curve: Curves.easeOutCubic,
                    child: face,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) => Material(
    type: MaterialType.transparency,
    child: ColoredBox(
      color: const Color(0xb31a2926),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Semantics(
                liveRegion: true,
                child: const Text(
                  '¡Nueva carta desbloqueada!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Fredoka',
                    color: Color(0xffffdb88),
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                child: Center(
                  child: AnimatedContainer(
                    duration: Duration(milliseconds: reduce ? 0 : 320),
                    curve: Curves.easeOutCubic,
                    constraints: BoxConstraints(
                      maxWidth: _expanded ? 430 : 280,
                    ),
                    child: _card(),
                  ),
                ),
              ),
            ),
            if (!_expanded)
              const Text(
                'Toca la carta para conocer a tu nuevo michi',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white),
              ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 12,
                runSpacing: 8,
                children: [
                  FilledButton(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(140, 48),
                      backgroundColor: const Color(0xff986233),
                    ),
                    onPressed: _continue,
                    child: const Text('Continuar'),
                  ),
                  if (_expanded)
                    FilledButton(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(160, 48),
                      ),
                      onPressed: () {
                        GameAudio.instance.stopEffect(GameSfx.marusCardVictory);
                        _acknowledge();
                        widget.onAlmanac(cat);
                      },
                      child: const Text('Ver en el almanaque'),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
