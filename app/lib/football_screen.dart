import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'cat_character.dart';
import 'football_game.dart';
import 'game_audio.dart';
import 'house_day_cycle.dart';
import 'patio_art.dart';
import 'patio_weather_bar.dart';
import 'patio_weather.dart';
import 'store.dart';

class FootballScreen extends StatefulWidget {
  const FootballScreen({
    super.key,
    required this.store,
    required this.weather,
    this.clock,
  });
  final GameStore store;
  final PatioWeather weather;
  final DateTime Function()? clock;
  @override
  State<FootballScreen> createState() => _FootballScreenState();
}

class _FootballScreenState extends State<FootballScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late final FootballGame game;
  late final Ticker ticker;
  late final AnimationController breeze;
  late final String session;
  Duration _last = Duration.zero, _downAt = Duration.zero;
  int? _pointer;
  Offset _start = Offset.zero, _end = Offset.zero;
  CatKind keeper = CatKind.maru;
  bool _paused = false;
  String _message = 'Desliza el balón hacia la portería';
  @override
  void initState() {
    super.initState();
    session =
        '${DateTime.now().microsecondsSinceEpoch}:${math.Random().nextInt(1 << 32)}';
    game = FootballGame(onResult: _result);
    breeze = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
    ticker = createTicker((elapsed) {
      final dt = _last == Duration.zero
          ? 0.0
          : (elapsed - _last).inMicroseconds / 1000000;
      _last = elapsed;
      if (!_paused) game.tick(dt.clamp(0.0, .05));
    })..start();
    WidgetsBinding.instance.addObserver(this);
  }

  void _result(FootballResult result, int streak, int attempt) {
    if (result == FootballResult.goal) {
      unawaited(
        widget.store.recordFootballGoal('goal:$session:$attempt', streak),
      );
      HapticFeedback.lightImpact();
      GameAudio.instance.play(GameSfx.coin);
    } else {
      GameAudio.instance.play(GameSfx.place);
    }
    if (mounted) {
      setState(
        () => _message = switch (result) {
          FootballResult.goal => '¡Gol! +30 monedas',
          FootballResult.save =>
            '¡${keeper == CatKind.maru ? 'Maru' : 'Lady'} atajó! Intenta a una esquina',
          FootballResult.weak => 'Un poco más de fuerza en el próximo tiro',
          FootballResult.wide =>
            game.touchedPost
                ? '¡Al poste! Prueba otra vez'
                : '¡Por poquito! Tira otra vez',
        },
      );
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _paused = state != AppLifecycleState.resumed;
    _last = Duration.zero;
    _pointer = null;
    game.cancelAim();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    ticker.dispose();
    breeze.dispose();
    game.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => HouseDayCycle(
    clock: widget.clock,
    builder: (context, light) => Scaffold(
      appBar: AppBar(
        title: const Text('Fútbol de patitas'),
        actions: [
          AnimatedBuilder(
            animation: widget.store,
            builder: (context, _) => Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 14),
                child: Row(
                  children: [
                    const Icon(
                      Icons.monetization_on_rounded,
                      color: Color(0xffbe903d),
                      size: 20,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '${widget.store.coins}',
                      key: const ValueKey('goal-coins'),
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: PatioWeatherBar(weather: widget.weather, light: light),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      '${game.goals} ${game.goals == 1 ? 'gol' : 'goles'}',
                      key: const ValueKey('goal-score'),
                      style: const TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: Text(
                      'Racha: ${game.streak} · Récord: ${widget.store.footballBestStreak}',
                      textAlign: TextAlign.right,
                      maxLines: 2,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Text('Portero: ', style: TextStyle(fontSize: 12)),
                  for (final cat in CatKind.values)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        key: ValueKey('goal-keeper-${cat.name}'),
                        label: Text(cat == CatKind.maru ? 'Maru' : 'Lady'),
                        selected: keeper == cat,
                        onSelected: (_) {
                          if (game.ready && _pointer == null) {
                            setState(() => keeper = cat);
                          }
                        },
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, bounds) {
                  final width = math.min(
                    bounds.maxWidth - 24,
                    bounds.maxHeight * FootballGame.width / FootballGame.height,
                  );
                  final height =
                      width * FootballGame.height / FootballGame.width;
                  Offset position(Offset local) => Offset(
                    local.dx * FootballGame.width / width,
                    local.dy * FootballGame.height / height,
                  );
                  return Center(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: SizedBox(
                        width: width,
                        height: height,
                        child: Semantics(
                          label:
                              'Balón de fútbol: toca el balón, desliza hacia la portería y suelta para tirar',
                          child: Listener(
                            key: const ValueKey('goal-field'),
                            behavior: HitTestBehavior.opaque,
                            onPointerDown: (event) {
                              if (_paused ||
                                  _pointer != null ||
                                  !game.ready ||
                                  (position(event.localPosition) - game.ball)
                                          .distance >
                                      math.max(
                                        FootballGame.radius + 12,
                                        26 * FootballGame.width / width,
                                      )) {
                                return;
                              }
                              _pointer = event.pointer;
                              _start = _end = position(event.localPosition);
                              _downAt = event.timeStamp;
                              game.point(_end);
                            },
                            onPointerMove: (event) {
                              if (_pointer != event.pointer) return;
                              _end = position(event.localPosition);
                              game.point(_end);
                            },
                            onPointerCancel: (event) {
                              if (_pointer == event.pointer) {
                                _pointer = null;
                                game.cancelAim();
                              }
                            },
                            onPointerUp: (event) {
                              if (_pointer != event.pointer) return;
                              _pointer = null;
                              if (_paused) {
                                game.cancelAim();
                                return;
                              }
                              _end = position(event.localPosition);
                              if (game.shoot(
                                _start,
                                _end,
                                (event.timeStamp - _downAt).inMicroseconds /
                                    1000000,
                              )) {
                                GameAudio.instance.play(GameSfx.jump);
                                setState(() => _message = '');
                              }
                            },
                            child: RepaintBoundary(
                              child: CustomPaint(
                                painter: FootballPainter(
                                  game: game,
                                  light: light,
                                  weather: widget.weather,
                                  breeze: breeze,
                                  keeper: keeper,
                                  outfit: widget.store.catCare.outfit(keeper),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            SizedBox(
              height: 40,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    _message,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: game.result == FootballResult.goal
                          ? const Color(0xff44865d)
                          : const Color(0xff63776c),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class FootballPainter extends CustomPainter {
  FootballPainter({
    required this.game,
    required this.light,
    required this.weather,
    required this.breeze,
    required this.keeper,
    required this.outfit,
  }) : super(repaint: Listenable.merge([game, weather, breeze]));
  final FootballGame game;
  final HouseLight light;
  final PatioWeather weather;
  final Animation<double> breeze;
  final CatKind keeper;
  final CatOutfit outfit;
  @override
  void paint(Canvas c, Size size) {
    PatioBackdrop(
      light: light,
      conditions: weather.conditions,
      phase: breeze.value,
      field: true,
    ).paint(c, size);
    c.save();
    c.scale(size.width / FootballGame.width, size.height / FootballGame.height);
    final goal = Path()
      ..moveTo(64, 140)
      ..lineTo(83, 70)
      ..lineTo(317, 70)
      ..lineTo(336, 140)
      ..close();
    c.drawPath(
      goal,
      Paint()
        ..color = light
            .tint(const Color(0xffcde3c5), const Color(0xff345f58))
            .withValues(alpha: .8),
    );
    c.save();
    c.clipPath(goal);
    final net = Paint()
      ..color = light
          .tint(const Color(0xff699c73), const Color(0xff75a18a))
          .withValues(alpha: .65)
      ..strokeWidth = 1;
    for (var x = 64.0; x < 338; x += 14) {
      c.drawLine(Offset(x, 65), Offset(x, 145), net);
    }
    for (var y = 76.0; y < 144; y += 13) {
      c.drawLine(Offset(55, y), Offset(345, y), net);
    }
    c.restore();
    c.drawPath(
      goal,
      Paint()
        ..color = light.tint(const Color(0xfffcf8df), const Color(0xffd7dfdd))
        ..strokeWidth = 7
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round,
    );
    c.drawOval(
      Rect.fromCenter(center: Offset(game.keeperX, 230), width: 72, height: 13),
      Paint()..color = const Color(0x24324135),
    );
    c.save();
    c.translate(game.keeperX - 55, FootballGame.keeperY - 76);
    final CatPainter painter = keeper == CatKind.maru
        ? MaruPainter(
            phase: breeze.value,
            joy: game.result == FootballResult.save ? 1 : 0,
            outfit: outfit,
          )
        : LadyPainter(
            phase: breeze.value,
            joy: game.result == FootballResult.save ? 1 : 0,
            outfit: outfit,
          );
    painter.paint(c, const Size(110, 110));
    c.restore();
    if (game.aim != null && (game.aim! - game.ball).distance > 5) {
      final delta = game.aim! - game.ball;
      final length = math.min(delta.distance, 170.0);
      final dir = delta / delta.distance;
      final p = Paint()
        ..color = const Color(0xfffcf3c5).withValues(alpha: .7)
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round;
      for (var n = 28.0; n < length; n += 17) {
        c.drawLine(game.ball + dir * n, game.ball + dir * (n + 7), p);
      }
      final end = game.ball + dir * length;
      final side = Offset(-dir.dy, dir.dx);
      c.drawLine(end, end - dir * 12 + side * 8, p);
      c.drawLine(end, end - dir * 12 - side * 8, p);
    }
    c.drawOval(
      Rect.fromCenter(
        center: game.ball + const Offset(2, 19),
        width: 33,
        height: 10,
      ),
      Paint()..color = const Color(0x30304636),
    );
    c.save();
    c.translate(game.ball.dx, game.ball.dy);
    c.rotate(game.rotation);
    const ballRect = Rect.fromLTWH(-18, -18, 36, 36);
    c.drawCircle(
      Offset.zero,
      18,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-.4, -.5),
          colors: [Color(0xffffffff), Color(0xffccd8d5)],
        ).createShader(ballRect),
    );
    c.save();
    c.clipPath(Path()..addOval(ballRect));
    void patch(Offset center, double radius) {
      final path = Path();
      for (var i = 0; i < 5; i++) {
        final a = -math.pi / 2 + i * math.pi * 2 / 5;
        final p = center + Offset(math.cos(a), math.sin(a)) * radius;
        if (i == 0) {
          path.moveTo(p.dx, p.dy);
        } else {
          path.lineTo(p.dx, p.dy);
        }
      }
      path.close();
      c.drawPath(path, Paint()..color = const Color(0xff34443e));
    }

    patch(const Offset(-2, -1), 6.8);
    for (var i = 0; i < 5; i++) {
      final a = i * math.pi * 2 / 5;
      patch(Offset(math.cos(a), math.sin(a)) * 18, 6);
      c.drawLine(
        Offset(math.cos(a), math.sin(a)) * 6,
        Offset(math.cos(a), math.sin(a)) * 17,
        Paint()
          ..color = const Color(0xff6b7b74)
          ..strokeWidth = .8,
      );
    }
    c.restore();
    c.drawCircle(
      Offset.zero,
      18,
      Paint()
        ..color = const Color(0xffdae7da)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    c.restore();
    if (game.result == FootballResult.goal) {
      final p = Paint();
      for (var i = 0; i < 16; i++) {
        final angle = i * math.pi * 2 / 16;
        final distance = 28 + ((game.age * 100 + i * 17) % 70);
        final at =
            const Offset(200, 115) +
            Offset(math.cos(angle), math.sin(angle)) * distance;
        p.color = [
          const Color(0xffffdf87),
          const Color(0xfff2a9b5),
          const Color(0xffb4e5cd),
        ][i % 3];
        c.drawCircle(at, 3, p);
      }
    }
    c.restore();
  }

  @override
  bool shouldRepaint(covariant FootballPainter old) =>
      old.game != game ||
      old.light != light ||
      old.keeper != keeper ||
      old.outfit != outfit;
}
