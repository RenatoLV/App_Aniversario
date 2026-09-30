import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'cat_character.dart';
import 'leap.dart';
import 'store.dart';

class LeapScreen extends StatefulWidget {
  final GameStore store;
  const LeapScreen({super.key, required this.store});
  @override
  State<LeapScreen> createState() => _LeapScreenState();
}

class _LeapScreenState extends State<LeapScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  LeapGame _game = LeapGame();
  CatKind _cat = CatKind.maru;
  late final Ticker _physics;
  late final AnimationController _breath, _tail, _blink, _bounce, _joy;
  Timer? _blinkTimer;
  final _focus = FocusNode(), _captureKey = GlobalKey();
  final Map<int, double> _touches = {};
  bool _left = false,
      _right = false,
      _started = false,
      _paused = false,
      _capturing = false;
  Duration? _lastTick;
  double _height = 640;
  int _best = 0;
  double get _direction =>
      (_touches.values.fold(0.0, (a, b) => a + b) +
              (_left ? -1 : 0) +
              (_right ? 1 : 0))
          .clamp(-1.0, 1.0);
  bool get _running => _started && !_paused && !_game.over;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _best = widget.store.prefs.getInt('leap.best') ?? 0;
    _breath = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
    _tail = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1700),
    )..repeat(reverse: true);
    _blink = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _bounce = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _joy = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    );
    _physics = createTicker(_tick);
    _scheduleBlink();
  }

  void _scheduleBlink() {
    _blinkTimer = Timer(
      Duration(milliseconds: 2600 + math.Random().nextInt(3300)),
      () async {
        if (!mounted) return;
        await _blink.forward(from: 0);
        if (!mounted) return;
        await _blink.reverse();
        if (mounted) _scheduleBlink();
      },
    );
  }

  void _tick(Duration elapsed) {
    final previous = _lastTick;
    _lastTick = elapsed;
    if (previous == null || !_running) return;
    final coins = _game.coins, landings = _game.landings;
    _game.step(
      (elapsed - previous).inMicroseconds / 1000000,
      _direction,
      _height,
    );
    if (_game.coins > coins) {
      widget.store.collectLeapCoins(_game.coins - coins);
      _joy.forward(from: 0);
      HapticFeedback.selectionClick();
    }
    if (_game.landings > landings) {
      _bounce.forward(from: 0);
      HapticFeedback.lightImpact();
    }
    if (_game.over) {
      _physics.stop();
      _record();
      _touches.clear();
      _left = false;
      _right = false;
    }
    setState(() {});
  }

  Future<void> _record() async {
    if (_game.points <= _best) return;
    _best = _game.points;
    try {
      await widget.store.prefs.setInt('leap.best', _best);
    } catch (_) {
      /* The current score stays visible. */
    }
  }

  void _start() {
    setState(() {
      _game = LeapGame();
      _started = true;
      _paused = false;
      _touches.clear();
      _left = false;
      _right = false;
    });
    _lastTick = null;
    if (!_physics.isActive) _physics.start();
    _focus.requestFocus();
  }

  void _pause(bool pause) {
    if (!_started || _game.over) return;
    setState(() => _paused = pause);
    _touches.clear();
    _left = false;
    _right = false;
    if (pause) {
      _physics.stop();
      _record();
    } else {
      _lastTick = null;
      if (!_physics.isActive) _physics.start();
      _focus.requestFocus();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && _running) _pause(true);
  }

  Future<void> _camera() async {
    if (_capturing || !_started) return;
    final resume = _running;
    // Freeze the physics without covering the captured scene with the pause card.
    setState(() {
      _capturing = true;
      _paused = true;
    });
    _physics.stop();
    _touches.clear();
    _left = false;
    _right = false;
    try {
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      final boundary =
          _captureKey.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (!mounted || data == null) return;
      final Uint8List bytes = data.buffer.asUint8List();
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Tu salto galáctico'),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 520),
            child: Image.memory(bytes, fit: BoxFit.contain),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Volver al juego'),
            ),
          ],
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo capturar este salto.')),
        );
      }
    } finally {
      _capturing = false;
      if (mounted) {
        if (resume && !_game.over) {
          _pause(false);
        } else {
          setState(() => _paused = true);
        }
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _blinkTimer?.cancel();
    _physics.dispose();
    for (final controller in [_breath, _tail, _blink, _bounce, _joy]) {
      controller.dispose();
    }
    _focus.dispose();
    super.dispose();
  }

  Widget _control(int direction) => Listener(
    onPointerDown: (e) {
      if (_running) setState(() => _touches[e.pointer] = direction.toDouble());
    },
    onPointerUp: (e) => setState(() => _touches.remove(e.pointer)),
    onPointerCancel: (e) => setState(() => _touches.remove(e.pointer)),
    child: Semantics(
      label: direction < 0 ? 'Mover a la izquierda' : 'Mover a la derecha',
      button: true,
      child: Container(
        width: 72,
        height: 56,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .22),
          border: Border.all(color: Colors.white.withValues(alpha: .55)),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Icon(
          direction < 0
              ? Icons.arrow_back_rounded
              : Icons.arrow_forward_rounded,
          color: Colors.white,
          size: 38,
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => PopScope(
    onPopInvokedWithResult: (didPop, _) {
      if (didPop) _record();
    },
    child: Scaffold(
      backgroundColor: const Color(0xff102747),
      body: SafeArea(
        child: Focus(
          focusNode: _focus,
          autofocus: true,
          onKeyEvent: (_, event) {
            final down = event is KeyDownEvent || event is KeyRepeatEvent;
            if (event.logicalKey == LogicalKeyboardKey.arrowLeft ||
                event.logicalKey == LogicalKeyboardKey.keyA) {
              _left = down;
              return KeyEventResult.handled;
            }
            if (event.logicalKey == LogicalKeyboardKey.arrowRight ||
                event.logicalKey == LogicalKeyboardKey.keyD) {
              _right = down;
              return KeyEventResult.handled;
            }
            if (event is KeyDownEvent &&
                (event.logicalKey == LogicalKeyboardKey.space ||
                    event.logicalKey == LogicalKeyboardKey.escape)) {
              _pause(!_paused);
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: LayoutBuilder(
                builder: (context, c) {
                  final scale = c.maxWidth / LeapGame.width;
                  _height = c.maxHeight / scale;
                  final foot = (_height - (_game.y - _game.camera)) * scale;
                  final catSize = 60 * scale;
                  return RepaintBoundary(
                    key: _captureKey,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: Listener(
                            behavior: HitTestBehavior.opaque,
                            onPointerDown: (e) {
                              if (_running) {
                                setState(
                                  () => _touches[e.pointer] =
                                      e.localPosition.dx < c.maxWidth / 2
                                      ? -1
                                      : 1,
                                );
                              }
                            },
                            onPointerMove: (e) {
                              if (_touches.containsKey(e.pointer)) {
                                _touches[e.pointer] =
                                    e.localPosition.dx < c.maxWidth / 2
                                    ? -1
                                    : 1;
                              }
                            },
                            onPointerUp: (e) =>
                                setState(() => _touches.remove(e.pointer)),
                            onPointerCancel: (e) =>
                                setState(() => _touches.remove(e.pointer)),
                            child: CustomPaint(
                              painter: _LeapWorldPainter(_game, _cat),
                            ),
                          ),
                        ),
                        Positioned(
                          left: _game.x * scale - catSize / 2,
                          top: foot - catSize * .94,
                          child: IgnorePointer(
                            child: AnimatedBuilder(
                              animation: Listenable.merge([
                                _breath,
                                _tail,
                                _blink,
                                _bounce,
                                _joy,
                              ]),
                              builder: (context, _) {
                                final squash = _bounce.isAnimating
                                    ? TweenSequence<double>([
                                        TweenSequenceItem(
                                          tween: Tween(begin: .8, end: 1.16)
                                              .chain(
                                                CurveTween(
                                                  curve: Curves.easeOut,
                                                ),
                                              ),
                                          weight: 45,
                                        ),
                                        TweenSequenceItem(
                                          tween: Tween(begin: 1.16, end: 1.0)
                                              .chain(
                                                CurveTween(
                                                  curve: Curves.easeInOut,
                                                ),
                                              ),
                                          weight: 55,
                                        ),
                                      ]).transform(_bounce.value)
                                    : 1.0;
                                return Transform.rotate(
                                  angle: _game.vx / 230 * .12,
                                  child: Transform(
                                    alignment: Alignment.bottomCenter,
                                    transform: Matrix4.diagonal3Values(
                                      1 / squash,
                                      squash *
                                          (1 +
                                              math.sin(
                                                    _breath.value * math.pi * 2,
                                                  ) *
                                                  .008),
                                      1,
                                    ),
                                    child: CustomPaint(
                                      size: Size.square(catSize),
                                      painter: _cat == CatKind.maru
                                          ? MaruPainter(
                                              phase: _tail.value,
                                              blink: _blink.value,
                                              joy: _joy.value,
                                            )
                                          : LadyPainter(
                                              phase: _tail.value,
                                              blink: _blink.value,
                                              joy: _joy.value,
                                            ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        Positioned(
                          top: 8,
                          left: 8,
                          right: 8,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              IconButton(
                                onPressed: () => Navigator.pop(context),
                                icon: const Icon(
                                  Icons.arrow_back,
                                  color: Colors.white,
                                ),
                                tooltip: 'Volver',
                              ),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Puntos: ${_game.points}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 21,
                                          color: Colors.white,
                                          shadows: [
                                            Shadow(
                                              color: Color(0xff184e75),
                                              blurRadius: 3,
                                              offset: Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Text(
                                        '${_game.coins} monedas · récord $_best',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              IconButton(
                                onPressed: _started && !_capturing
                                    ? _camera
                                    : null,
                                tooltip: 'Capturar salto',
                                icon: const Icon(
                                  Icons.photo_camera_outlined,
                                  color: Colors.white,
                                ),
                              ),
                              IconButton(
                                onPressed: _started
                                    ? _game.over
                                          ? null
                                          : () => _pause(!_paused)
                                    : null,
                                tooltip: _paused ? 'Continuar' : 'Pausa',
                                icon: Icon(
                                  _paused
                                      ? Icons.play_arrow_rounded
                                      : Icons.pause_rounded,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Positioned(
                          bottom: 12,
                          left: 16,
                          right: 16,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _control(-1),
                              Flexible(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                  child: Text(
                                    _game.boosting
                                        ? '¡Cohete de bigotes!'
                                        : 'Mantén pulsado para moverte',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                              _control(1),
                            ],
                          ),
                        ),
                        if (!_started || _paused && !_capturing || _game.over)
                          Positioned.fill(
                            child: ColoredBox(
                              color: const Color(0x60101a3a),
                              child: Center(
                                child: SingleChildScrollView(
                                  padding: const EdgeInsets.all(20),
                                  child: Container(
                                    padding: const EdgeInsets.all(22),
                                    decoration: BoxDecoration(
                                      color: const Color(0xfffaf5ec),
                                      borderRadius: BorderRadius.circular(28),
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 2,
                                      ),
                                    ),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          !_started
                                              ? 'MARU & LADY'
                                              : _game.over
                                              ? '¡Un salto más!'
                                              : 'Un descansito',
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            fontSize: 24,
                                            fontWeight: FontWeight.w900,
                                            color: Color(0xff253c61),
                                          ),
                                        ),
                                        const Text(
                                          'GALACTIC LEAP',
                                          style: TextStyle(
                                            fontSize: 12,
                                            letterSpacing: 2,
                                            color: Color(0xff896787),
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                        if (!_started) ...[
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceEvenly,
                                            children: [
                                              for (final cat in CatKind.values)
                                                InkWell(
                                                  onTap: () => setState(
                                                    () => _cat = cat,
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(16),
                                                  child: Container(
                                                    padding:
                                                        const EdgeInsets.all(8),
                                                    decoration: BoxDecoration(
                                                      color: _cat == cat
                                                          ? const Color(
                                                              0xffe6d9f5,
                                                            )
                                                          : Colors.transparent,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            16,
                                                          ),
                                                    ),
                                                    child: Column(
                                                      children: [
                                                        CustomPaint(
                                                          size: const Size(
                                                            76,
                                                            76,
                                                          ),
                                                          painter:
                                                              cat ==
                                                                  CatKind.maru
                                                              ? const MaruPainter()
                                                              : const LadyPainter(),
                                                        ),
                                                        Text(
                                                          cat == CatKind.maru
                                                              ? 'Maru'
                                                              : 'Lady',
                                                          style:
                                                              const TextStyle(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                              ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                          const SizedBox(height: 12),
                                          const Text(
                                            'Salta del cielo al espacio. Mantén un lado de la pantalla o las flechas para dirigirte.\n\nRecoge monedas y cohetes; evita las nubes eléctricas.',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              fontSize: 13,
                                              height: 1.4,
                                              color: Color(0xff59657a),
                                            ),
                                          ),
                                        ] else if (_game.over) ...[
                                          Text(
                                            _game.endReason,
                                            textAlign: TextAlign.center,
                                          ),
                                          Text(
                                            '${_game.points} puntos · ${_game.coins} monedas',
                                            style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const Text(
                                            'Las monedas ya están guardadas para tus sobres.',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(fontSize: 12),
                                          ),
                                        ] else
                                          const Text(
                                            'Maru y Lady te esperan.\nEl juego también se pausa al salir de la app.',
                                            textAlign: TextAlign.center,
                                          ),
                                        const SizedBox(height: 18),
                                        FilledButton.icon(
                                          onPressed: !_started || _game.over
                                              ? _start
                                              : () => _pause(false),
                                          icon: const Icon(Icons.rocket_launch),
                                          label: Text(
                                            !_started
                                                ? '¡A saltar!'
                                                : _game.over
                                                ? 'Otra aventura'
                                                : 'Continuar',
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _LeapWorldPainter extends CustomPainter {
  final LeapGame game;
  final CatKind cat;
  _LeapWorldPainter(this.game, this.cat);
  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 360;
    final height = size.height / scale;
    final space = (game.points / 2300).clamp(0.0, 1.0);
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.lerp(
              const Color(0xff48c4eb),
              const Color(0xff100e36),
              space,
            )!,
            Color.lerp(
              const Color(0xffb0e9ef),
              const Color(0xff243566),
              space,
            )!,
          ],
        ).createShader(Offset.zero & size),
    );
    canvas.save();
    canvas.scale(scale);
    final p = Paint();
    for (var n = 0; n < 65; n++) {
      final x = (n * 71.37) % 360,
          y =
              ((n * 93.71 - game.camera * .15) % (height + 20) + height + 20) %
              (height + 20);
      p.color = Colors.white.withValues(
        alpha: (space * (.45 + math.sin(game.clock * 2 + n) * .25)).clamp(
          0.0,
          1.0,
        ),
      );
      canvas.drawCircle(Offset(x, y), n % 4 == 0 ? 1.7 : .8, p);
    }
    if (space > .15) {
      p.color = const Color(0xffceb8dd).withValues(alpha: space * .6);
      final planet = Offset(295, 150 + (game.camera * .05) % 100);
      canvas.drawCircle(planet, 26, p);
      p
        ..color = const Color(0xffe6c895).withValues(alpha: space * .7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5;
      canvas.save();
      canvas.translate(planet.dx, planet.dy);
      canvas.rotate(-.35);
      canvas.drawOval(const Rect.fromLTWH(-41, -11, 82, 22), p);
      canvas.restore();
      p.style = PaintingStyle.fill;
      final moon = Offset(35, height * .38);
      canvas.drawCircle(
        moon,
        21,
        Paint()..color = const Color(0xffb7d1ec).withValues(alpha: space * .45),
      );
      for (var i = 0; i < 4; i++) {
        canvas.drawCircle(
          moon + Offset(-8 + i * 5, i.isEven ? -7 : 8),
          3 + i * .7,
          Paint()
            ..color = const Color(0xff7387b3).withValues(alpha: space * .35),
        );
      }
    }
    final foot = height - (game.y - game.camera);
    if (cat == CatKind.lady && game.vy > 0) {
      const colors = [
        Color(0xffef86a1),
        Color(0xffffc078),
        Color(0xffffe98c),
        Color(0xff89dfb1),
        Color(0xff90d6ff),
        Color(0xffb7a0e9),
      ];
      for (var n = 0; n < 6; n++) {
        final path = Path()
          ..moveTo(game.x - 19 + n * 5, foot - 18)
          ..quadraticBezierTo(
            game.x - game.vx * .12 + n * 5,
            foot + 35,
            game.x - game.vx * .22 + n * 5,
            foot + 80,
          );
        canvas.drawPath(
          path,
          Paint()
            ..color = colors[n].withValues(alpha: .55)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 5
            ..strokeCap = StrokeCap.round,
        );
      }
    }
    if (game.boosting) {
      _rocket(canvas, Offset(game.x, foot + 3), game.clock, true);
    }
    for (final platform in game.platforms) {
      final y = height - (platform.y - game.camera);
      if (y < -40 || y > height + 40) continue;
      if (platform.kind == LeapPlatformKind.rock) {
        final left = platform.x - platform.width / 2,
            right = platform.x + platform.width / 2;
        final rock = Path()
          ..moveTo(left, y + 3)
          ..lineTo(right, y + 3)
          ..quadraticBezierTo(right + 1, y + 17, right - 10, y + 19)
          ..lineTo(platform.x + 9, y + 23)
          ..lineTo(platform.x - 9, y + 20)
          ..lineTo(left + 11, y + 23)
          ..quadraticBezierTo(left - 2, y + 16, left, y + 3)
          ..close();
        canvas.drawPath(rock, Paint()..color = const Color(0xff967355));
        canvas.drawPath(
          rock,
          Paint()
            ..color = const Color(0xff765c49)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.3,
        );
        for (var n = 0; n < 4; n++) {
          final px = left + 5 + n * platform.width / 4;
          canvas.drawPath(
            Path()
              ..moveTo(px, y + 5)
              ..lineTo(px - 2, y + 12)
              ..lineTo(px + 7, y + 19),
            Paint()
              ..color = const Color(0xff765c49)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1,
          );
          canvas.drawOval(
            Rect.fromLTWH(px + 3, y + 8, 12, 6),
            Paint()..color = const Color(0xffb38b61),
          );
        }
        final grass = Path()
          ..moveTo(left, y + 4)
          ..lineTo(left, y);
        for (var i = 0; i < 12; i++) {
          final px = left + i * platform.width / 12;
          grass
            ..lineTo(px + 2, y - (i % 3 + 1) * 2)
            ..lineTo(px + 5, y + 1);
        }
        grass
          ..lineTo(right, y)
          ..lineTo(right, y + 5)
          ..quadraticBezierTo(platform.x, y + 9, left, y + 4)
          ..close();
        canvas.drawPath(grass, Paint()..color = const Color(0xff80c798));
      } else {
        final storm = platform.kind == LeapPlatformKind.storm;
        final paint = Paint()
          ..color = storm ? const Color(0xff68748e) : Colors.white;
        final left = platform.x - platform.width / 2,
            right = platform.x + platform.width / 2;
        final path = Path()
          ..moveTo(left, y)
          ..lineTo(right, y)
          ..quadraticBezierTo(right + 2, y + 20, right - 15, y + 20)
          ..quadraticBezierTo(right - 25, y + 20, right - 28, y + 12)
          ..quadraticBezierTo(platform.x, y + 35, left + 25, y + 17)
          ..quadraticBezierTo(left + 3, y + 28, left, y)
          ..close();
        canvas.drawPath(
          path.shift(const Offset(0, 3)),
          Paint()
            ..color = storm ? const Color(0xff4e5b76) : const Color(0xffb7dcec),
        );
        canvas.drawPath(path, paint);
        if (storm) {
          canvas.drawPath(
            Path()
              ..moveTo(platform.x + 3, y + 8)
              ..lineTo(platform.x - 5, y + 24)
              ..lineTo(platform.x + 2, y + 24)
              ..lineTo(platform.x - 1, y + 35)
              ..lineTo(platform.x + 13, y + 18)
              ..lineTo(platform.x + 5, y + 18)
              ..close(),
            Paint()..color = const Color(0xffffdf82),
          );
        }
      }
      if (platform.motion > 0) {
        final tp = TextPainter(
          text: const TextSpan(
            text: '↔',
            style: TextStyle(fontSize: 12, color: Colors.white),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(platform.x - 6, y + 14));
      }
    }
    for (final pickup in game.pickups) {
      if (pickup.taken) continue;
      final at = Offset(pickup.x, height - (pickup.y - game.camera));
      if (at.dy < -30 || at.dy > height + 30) continue;
      if (pickup.kind == LeapPickupKind.rocket) {
        _rocket(canvas, at, game.clock, false);
      } else {
        final w = 4 + math.sin(game.clock * 3 + pickup.x).abs() * 5;
        canvas.drawOval(
          Rect.fromCenter(center: at, width: w * 2, height: 22),
          Paint()..color = const Color(0xffffcc51),
        );
        canvas.drawOval(
          Rect.fromCenter(center: at, width: w * 1.3, height: 16),
          Paint()
            ..color = const Color(0xffffed95)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
      }
    }
    canvas.restore();
  }

  void _rocket(Canvas canvas, Offset at, double t, bool mounted) {
    canvas.save();
    canvas.translate(at.dx, at.dy);
    if (!mounted) canvas.rotate(-.25);
    canvas.drawPath(
      Path()
        ..moveTo(-9, 8)
        ..lineTo(-15, 17)
        ..lineTo(-6, 15)
        ..close(),
      Paint()..color = const Color(0xffe88191),
    );
    canvas.drawPath(
      Path()
        ..moveTo(9, 8)
        ..lineTo(15, 17)
        ..lineTo(6, 15)
        ..close(),
      Paint()..color = const Color(0xffe88191),
    );
    canvas.drawPath(
      Path()
        ..moveTo(-5, 17)
        ..quadraticBezierTo(0, 32 + math.sin(t * 20) * 5, 5, 17)
        ..close(),
      Paint()..color = const Color(0xffffb552),
    );
    canvas.drawOval(
      const Rect.fromLTWH(-9, -13, 18, 32),
      Paint()..color = const Color(0xfff9eee9),
    );
    canvas.drawCircle(
      const Offset(0, 0),
      5,
      Paint()..color = const Color(0xff7bbede),
    );
    canvas.drawPath(
      Path()
        ..moveTo(-8, -8)
        ..quadraticBezierTo(0, -25, 8, -8)
        ..close(),
      Paint()..color = const Color(0xffe88191),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _LeapWorldPainter oldDelegate) => true;
}
