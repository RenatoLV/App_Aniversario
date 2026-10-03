import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'cat_character.dart';
import 'alien_cat.dart';
import 'leap.dart';
import 'game_result.dart';
import 'store.dart';
import 'game_audio.dart';

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
  String _trail = 'rainbow';
  final Set<String> _ownedTrails = {'rainbow'};
  late final Ticker _physics;
  late final AnimationController _breath,
      _tail,
      _blink,
      _bounce,
      _joy,
      _fall,
      _rocketFlash;
  Timer? _blinkTimer;
  final _focus = FocusNode(), _captureKey = GlobalKey();
  final Map<int, double> _touches = {};
  final Map<int, Offset> _dragOrigins = {};
  StreamSubscription<dynamic>? _tiltSubscription;
  bool _tiltEnabled = false;
  double _tiltDirection = 0;
  double? _tiltNeutral;

  Future<void> _toggleTilt() async {
    if (_tiltEnabled) {
      await _tiltSubscription?.cancel();
      _tiltSubscription = null;
      if (mounted) {
        setState(() {
          _tiltEnabled = false;
          _tiltDirection = 0;
        });
      }
      return;
    }
    _tiltNeutral = null;
    setState(() => _tiltEnabled = true);
    _tiltSubscription = const EventChannel('anivermaru/tilt')
        .receiveBroadcastStream()
        .listen(
          (value) {
            if (!_tiltEnabled) return;
            final x = (value as num).toDouble();
            _tiltNeutral ??= x;
            final delta = -(x - _tiltNeutral!);
            final target = delta.abs() < .45
                ? 0.0
                : (delta / 3.6).clamp(-1.0, 1.0);
            _tiltDirection += (target - _tiltDirection) * .18;
          },
          onError: (Object error) {
            _tiltSubscription?.cancel();
            _tiltSubscription = null;
            if (!mounted) return;
            setState(() {
              _tiltEnabled = false;
              _tiltDirection = 0;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'La inclinación requiere el APK en un teléfono con sensor. Las flechas siguen disponibles.',
                ),
              ),
            );
          },
        );
  }

  bool _left = false,
      _right = false,
      _started = false,
      _paused = false,
      _capturing = false;
  Duration? _lastTick;
  double _height = 640;
  int _best = 0;
  LeapWorldZone _lastZone = LeapWorldZone.underground;
  double _zoneMessageUntil = 0;
  double get _direction =>
      (_tiltDirection +
              _touches.values.fold(0.0, (a, b) => a + b) +
              (_left ? -1 : 0) +
              (_right ? 1 : 0))
          .clamp(-1.0, 1.0);
  bool get _running => _started && !_paused && !_game.over;

  String _zoneName(LeapWorldZone zone) => switch (zone) {
    LeapWorldZone.underground => 'Profundidades de la Coquimbo',
    LeapWorldZone.meadow => 'Subida luminosa',
    LeapWorldZone.neighborhood => 'Las compañias',
    LeapWorldZone.city => 'Ciudad gatuna',
    LeapWorldZone.skyscrapers => 'Cima de Santiago',
    LeapWorldZone.upperSky => 'Cielo estrellado',
    LeapWorldZone.space => 'Universo',
    LeapWorldZone.heaven => 'Cielo',
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _best = widget.store.prefs.getInt('leap.best') ?? 0;
    _trail = widget.store.prefs.getString('leap.trail') ?? 'rainbow';
    _ownedTrails.addAll(
      widget.store.prefs.getStringList('leap.trails') ?? const [],
    );
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
    _fall = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _rocketFlash = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
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
    final coins = _game.coins,
        rockets = _game.rockets,
        ufos = _game.ufos,
        landings = _game.landings,
        umbrellas = _game.umbrellas,
        springs = _game.springJumps;
    _game.step(
      (elapsed - previous).inMicroseconds / 1000000,
      _direction,
      _height,
    );
    if (_game.coins > coins) {
      GameAudio.instance.play(GameSfx.coin);
      widget.store.collectLeapCoins(_game.coins - coins);
      _joy.forward(from: 0);
      HapticFeedback.selectionClick();
    }
    if (_game.rockets > rockets) {
      GameAudio.instance.play(GameSfx.rocket);
      _rocketFlash.forward(from: 0);
      HapticFeedback.heavyImpact();
    }
    if (_game.ufos > ufos) {
      GameAudio.instance.stopEffect(GameSfx.rocket);
      GameAudio.instance.play(GameSfx.abduction);
      HapticFeedback.heavyImpact();
    }
    if (_game.umbrellas > umbrellas) GameAudio.instance.play(GameSfx.paper);
    if (_game.landings > landings) {
      GameAudio.instance.play(
        _game.springJumps > springs ? GameSfx.spring : GameSfx.jump,
      );
      _bounce.forward(from: 0);
      HapticFeedback.lightImpact();
    }
    if (_game.zone != _lastZone) {
      _lastZone = _game.zone;
      _zoneMessageUntil = _game.clock + 2.8;
      HapticFeedback.mediumImpact();
    }
    if (_game.over) {
      _physics.stop();
      _fall.forward(from: 0);
      _record();
      _touches.clear();
      _dragOrigins.clear();
      _left = false;
      _right = false;
    }
    setState(() {});
  }

  Future<void> _record() async {
    if (_started) {
      await widget.store.prefs.setString(
        'leap.last',
        jsonEncode({
          'points': _game.points,
          'coins': _game.coins,
          'zone': _game.zone.name,
          'finished': _game.over,
          'recordedAt': DateTime.now().toUtc().toIso8601String(),
        }),
      );
    }
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
      _lastZone = LeapWorldZone.underground;
      _zoneMessageUntil = 2.8;
      _fall.reset();
      _rocketFlash.reset();
      _touches.clear();
      _dragOrigins.clear();
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
    GameAudio.instance.pauseGame(pause);
    _touches.clear();
    _dragOrigins.clear();
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

  Future<void> _openTrailShop() async {
    const trails = [
      (
        'none',
        'Sin estela',
        'El salto limpio, sin rastro detrás del gato',
        0,
        Icons.block_rounded,
      ),
      (
        'rainbow',
        'Arcoíris',
        'La estela clásica de Lady',
        0,
        Icons.auto_awesome,
      ),
      (
        'starlight',
        'Polvo estelar',
        'Destellos violetas y azules',
        600,
        Icons.star_rounded,
      ),
      (
        'bubble',
        'Burbujas',
        'Pompas turquesa con brillo',
        1200,
        Icons.bubble_chart_rounded,
      ),
      (
        'flame',
        'Llamas dulces',
        'Chispas cálidas al saltar',
        2000,
        Icons.local_fire_department_rounded,
      ),
      (
        'aurora',
        'Aurora boreal',
        'Cintas luminosas verdes y violetas',
        3500,
        Icons.waves_rounded,
      ),
      (
        'hearts',
        'Corazones cósmicos',
        'Corazones rosas que flotan al saltar',
        5000,
        Icons.favorite_rounded,
      ),
      (
        'comet',
        'Cometa dorado',
        'Una cola dorada con estrellas fugaces',
        7500,
        Icons.bolt_rounded,
      ),
      (
        'galaxy',
        'Galaxia',
        'Una espiral de estrellas y polvo cósmico',
        10000,
        Icons.nights_stay_rounded,
      ),
    ];
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 18),
          children: [
            const Text(
              'Tienda de estelas',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
            ),
            const Text('Equipa una estela para verla detrás de Maru o Lady.'),
            const SizedBox(height: 10),
            for (final trail in trails)
              ListTile(
                leading: Icon(trail.$5, color: const Color(0xff7045c7)),
                title: Text(trail.$2),
                subtitle: Text(trail.$3),
                trailing: _trail == trail.$1
                    ? const Chip(label: Text('EQUIPADA'))
                    : _ownedTrails.contains(trail.$1)
                    ? OutlinedButton(
                        onPressed: () async {
                          await widget.store.prefs.setString(
                            'leap.trail',
                            trail.$1,
                          );
                          if (mounted) setState(() => _trail = trail.$1);
                          if (context.mounted) Navigator.pop(context);
                        },
                        child: const Text('Equipar'),
                      )
                    : FilledButton(
                        onPressed: widget.store.coins < trail.$4
                            ? null
                            : () async {
                                if (trail.$4 > 0) {
                                  widget.store.coins -= trail.$4;
                                }
                                _ownedTrails.add(trail.$1);
                                await widget.store.prefs.setStringList(
                                  'leap.trails',
                                  _ownedTrails.toList(),
                                );
                                await widget.store.prefs.setString(
                                  'leap.trail',
                                  trail.$1,
                                );
                                await widget.store.save();
                                if (mounted) setState(() => _trail = trail.$1);
                                if (context.mounted) Navigator.pop(context);
                              },
                        child: Text(
                          trail.$4 == 0 ? 'Equipar' : '${trail.$4} 🪙',
                        ),
                      ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _tiltNeutral = null;
    _tiltDirection = 0;
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
    _dragOrigins.clear();
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
    _tiltSubscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _blinkTimer?.cancel();
    _physics.dispose();
    for (final controller in [
      _breath,
      _tail,
      _blink,
      _bounce,
      _joy,
      _fall,
      _rocketFlash,
    ]) {
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

  Widget _fallingCat() => SizedBox(
    width: 110,
    height: 105,
    child: AnimatedBuilder(
      animation: _fall,
      builder: (context, _) {
        final fall = Curves.easeIn.transform(_fall.value);
        final wobble =
            math.sin(_fall.value * math.pi * 4) * (1 - _fall.value) * .18;
        return Stack(
          alignment: Alignment.topCenter,
          children: [
            Positioned(
              top: 78,
              child: Opacity(
                opacity: fall * .35,
                child: Transform.scale(
                  scaleX: .45 + fall * .55,
                  child: Container(
                    width: 65,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: Color(0xff253c61),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            ),
            Transform.translate(
              offset: Offset(0, -24 + fall * 52),
              child: Transform.rotate(
                angle: wobble + fall * .72,
                child: Transform.scale(
                  scale: 1 - fall * .08,
                  child: SizedBox.square(
                    dimension: 76,
                    child: Stack(
                      children: [
                        CustomPaint(
                          size: const Size(76, 76),
                          painter: _cat == CatKind.maru
                              ? MaruPainter(
                                  outfit: widget.store.catCare.outfit(_cat),
                                  cleanliness: widget.store.catCare
                                      .needs(_cat)
                                      .clean
                                      .toDouble(),
                                  phase: _tail.value,
                                  blink: _blink.value,
                                )
                              : LadyPainter(
                                  outfit: widget.store.catCare.outfit(_cat),
                                  cleanliness: widget.store.catCare
                                      .needs(_cat)
                                      .clean
                                      .toDouble(),
                                  phase: _tail.value,
                                  blink: _blink.value,
                                ),
                        ),
                        if (_fall.value > .38)
                          CustomPaint(
                            size: const Size(76, 76),
                            painter: _CryingFacePainter(
                              progress: ((_fall.value - .38) / .62).clamp(
                                0.0,
                                1.0,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
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
                    child: ClipRect(
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: Listener(
                              behavior: HitTestBehavior.opaque,
                              onPointerDown: (e) {
                                if (_running) {
                                  _dragOrigins[e.pointer] = e.localPosition;
                                  setState(
                                    () => _touches[e.pointer] =
                                        e.localPosition.dx < c.maxWidth / 2
                                        ? -1
                                        : 1,
                                  );
                                }
                              },
                              onPointerMove: (e) {
                                final origin = _dragOrigins[e.pointer];
                                if (_running && origin != null) {
                                  final dx = e.localPosition.dx - origin.dx;
                                  if (dx.abs() > 8) {
                                    _touches[e.pointer] = (dx / (60 * scale))
                                        .clamp(-1.0, 1.0);
                                  }
                                }
                              },
                              onPointerUp: (e) => setState(() {
                                _touches.remove(e.pointer);
                                _dragOrigins.remove(e.pointer);
                              }),
                              onPointerCancel: (e) => setState(() {
                                _touches.remove(e.pointer);
                                _dragOrigins.remove(e.pointer);
                              }),
                              child: CustomPaint(
                                painter: LeapWorldPainter(
                                  _game,
                                  _cat,
                                  trail: _trail,
                                ),
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
                                    angle: _game.abducting
                                        ? math.sin(_game.clock * 3) * .055
                                        : _game.vx / 230 * .12,
                                    child: Transform(
                                      alignment: Alignment.bottomCenter,
                                      transform: Matrix4.diagonal3Values(
                                        (1 / squash) *
                                            (_game.abducting ? .85 : 1),
                                        squash *
                                            (_game.abducting ? .85 : 1) *
                                            (1 +
                                                math.sin(
                                                      _breath.value *
                                                          math.pi *
                                                          2,
                                                    ) *
                                                    .008),
                                        1,
                                      ),
                                      child: SizedBox.square(
                                        dimension: catSize,
                                        child: CustomPaint(
                                          size: Size.square(catSize),
                                          painter: _game.alien
                                              ? AlienCatPainter(
                                                  outfit: widget.store.catCare
                                                      .outfit(_cat),
                                                  cleanliness: widget
                                                      .store
                                                      .catCare
                                                      .needs(_cat)
                                                      .clean
                                                      .toDouble(),
                                                  cat: _cat,
                                                  phase: _tail.value,
                                                  blink: _blink.value,
                                                )
                                              : _cat == CatKind.maru
                                              ? MaruPainter(
                                                  outfit: widget.store.catCare
                                                      .outfit(_cat),
                                                  cleanliness: widget
                                                      .store
                                                      .catCare
                                                      .needs(_cat)
                                                      .clean
                                                      .toDouble(),
                                                  phase: _tail.value,
                                                  blink: _blink.value,
                                                  joy: _joy.value,
                                                )
                                              : LadyPainter(
                                                  outfit: widget.store.catCare
                                                      .outfit(_cat),
                                                  cleanliness: widget
                                                      .store
                                                      .catCare
                                                      .needs(_cat)
                                                      .clean
                                                      .toDouble(),
                                                  phase: _tail.value,
                                                  blink: _blink.value,
                                                  joy: _joy.value,
                                                ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                          Positioned(
                            top: 105,
                            left: 0,
                            right: 0,
                            child: IgnorePointer(
                              child: AnimatedBuilder(
                                animation: _rocketFlash,
                                builder: (context, _) {
                                  final opacity = math
                                      .sin(_rocketFlash.value * math.pi)
                                      .clamp(0.0, 1.0);
                                  return Opacity(
                                    opacity: opacity,
                                    child: Center(
                                      child: Transform.scale(
                                        scale: .82 + _rocketFlash.value * .18,
                                        child: Container(
                                          width: 132,
                                          height: 132,
                                          clipBehavior: Clip.antiAlias,
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(
                                              24,
                                            ),
                                            border: Border.all(
                                              color: Colors.white.withValues(
                                                alpha: .82,
                                              ),
                                              width: 3,
                                            ),
                                            boxShadow: const [
                                              BoxShadow(
                                                color: Color(0x88000000),
                                                blurRadius: 18,
                                                offset: Offset(0, 7),
                                              ),
                                            ],
                                          ),
                                          child: Image.asset(
                                            'assets/gato_cohete.png',
                                            fit: BoxFit.cover,
                                          ),
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
                                AudioSettingsButton(
                                  color: Colors.white,
                                  onOpen: _running ? () => _pause(true) : null,
                                  onClose: _running
                                      ? () => _pause(false)
                                      : null,
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
                            top: 84,
                            left: 34,
                            right: 34,
                            child: IgnorePointer(
                              child: AnimatedOpacity(
                                opacity:
                                    _running && _game.clock < _zoneMessageUntil
                                    ? 1
                                    : 0,
                                duration: const Duration(milliseconds: 350),
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xff17234d,
                                    ).withValues(alpha: .88),
                                    borderRadius: BorderRadius.circular(22),
                                    border: Border.all(
                                      color: Colors.white.withValues(
                                        alpha: .45,
                                      ),
                                    ),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Color(0x55000000),
                                        blurRadius: 12,
                                        offset: Offset(0, 5),
                                      ),
                                    ],
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 18,
                                      vertical: 10,
                                    ),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Text(
                                          'NUEVA ZONA',
                                          style: TextStyle(
                                            color: Color(0xffffd776),
                                            fontSize: 10,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 2.1,
                                          ),
                                        ),
                                        Text(
                                          _zoneName(_lastZone),
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 19,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
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
                                    child: TextButton.icon(
                                      onPressed: _toggleTilt,
                                      icon: Icon(
                                        Icons.screen_rotation,
                                        color: _tiltEnabled
                                            ? Colors.lightGreenAccent
                                            : Colors.white,
                                      ),
                                      label: Text(
                                        _tiltEnabled
                                            ? 'Inclinación ON'
                                            : 'Inclinación OFF',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                _control(1),
                              ],
                            ),
                          ),
                          if (_running &&
                              (_game.boosting ||
                                  _game.alien ||
                                  _game.umbrellaTime > 0))
                            Positioned(
                              bottom: 86,
                              left: 24,
                              right: 24,
                              child: IgnorePointer(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xdd142844),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: _game.boosting
                                          ? const Color(0xffffcf70)
                                          : const Color(0xff8cded7),
                                    ),
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        _game.boosting
                                            ? '🚀 Cohete · ${_game.rocketTime.toStringAsFixed(1)} s'
                                            : _game.abducting
                                            ? _game.abductionProgress < .2
                                                  ? '🛸 ¡Nos abducen!'
                                                  : _game.abductionProgress < .8
                                                  ? '🛸 Subiendo con la nave'
                                                  : '🛸 Bajando a la plataforma'
                                            : _game.umbrellaTime > 0
                                            ? '☂️ Paraguas · ${_game.umbrellaTime.ceil()} s'
                                            : '👽 ¡De vuelta en las nubes!',
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      if (_game.boosting ||
                                          _game.alien ||
                                          _game.umbrellaTime > 0) ...[
                                        const SizedBox(height: 5),
                                        LinearProgressIndicator(
                                          value: _game.boosting
                                              ? (_game.rocketTime / 2.4).clamp(
                                                  0.0,
                                                  1.0,
                                                )
                                              : _game.abducting
                                              ? 1 - _game.abductionProgress
                                              : _game.umbrellaTime > 0
                                              ? _game.umbrellaTime /
                                                    LeapGame.umbrellaDuration
                                              : (_game.alienTime / 2.2).clamp(
                                                  0.0,
                                                  1.0,
                                                ),
                                          color: _game.boosting
                                              ? const Color(0xffffcf70)
                                              : const Color(0xff8cded7),
                                          backgroundColor: Colors.white12,
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          if (!_started || _paused && !_capturing || _game.over)
                            Positioned.fill(
                              child: ColoredBox(
                                color: const Color(0x60101a3a),
                                child: Center(
                                  child: SingleChildScrollView(
                                    padding: const EdgeInsets.all(20),
                                    child: _game.over
                                        ? GameResultCard(
                                            game: ResultTheme.leap,
                                            title: '¡Un salto más!',
                                            detail:
                                                'Ascenso Maruzon · Aventura vertical',
                                            stat:
                                                '${_game.points} puntos · ${_game.coins} monedas',
                                            caption:
                                                '${_game.endReason}\nTus monedas ya están guardadas.',
                                            again: 'Otra subida',
                                            onAgain: _start,
                                            onHome: () {
                                              _record();
                                              Navigator.pop(context);
                                            },
                                          )
                                        : Container(
                                            padding: const EdgeInsets.all(22),
                                            decoration: BoxDecoration(
                                              color: const Color(0xfffaf5ec),
                                              borderRadius:
                                                  BorderRadius.circular(28),
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
                                                      ? 'ASCENSO MARUZON'
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
                                                  'AVENTURA VERTICAL',
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
                                                        MainAxisAlignment
                                                            .spaceEvenly,
                                                    children: [
                                                      for (final cat
                                                          in CatKind.values)
                                                        InkWell(
                                                          onTap: () => setState(
                                                            () => _cat = cat,
                                                          ),
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                16,
                                                              ),
                                                          child: Container(
                                                            padding:
                                                                const EdgeInsets.all(
                                                                  8,
                                                                ),
                                                            decoration: BoxDecoration(
                                                              color: _cat == cat
                                                                  ? const Color(
                                                                      0xffe6d9f5,
                                                                    )
                                                                  : Colors
                                                                        .transparent,
                                                              borderRadius:
                                                                  BorderRadius.circular(
                                                                    16,
                                                                  ),
                                                            ),
                                                            child: Column(
                                                              children: [
                                                                CustomPaint(
                                                                  size:
                                                                      const Size(
                                                                        76,
                                                                        76,
                                                                      ),
                                                                  painter:
                                                                      cat ==
                                                                          CatKind
                                                                              .maru
                                                                      ? MaruPainter(
                                                                          outfit: widget
                                                                              .store
                                                                              .catCare
                                                                              .outfit(
                                                                                cat,
                                                                              ),
                                                                          cleanliness: widget
                                                                              .store
                                                                              .catCare
                                                                              .needs(
                                                                                cat,
                                                                              )
                                                                              .clean
                                                                              .toDouble(),
                                                                        )
                                                                      : LadyPainter(
                                                                          outfit: widget
                                                                              .store
                                                                              .catCare
                                                                              .outfit(
                                                                                cat,
                                                                              ),
                                                                          cleanliness: widget
                                                                              .store
                                                                              .catCare
                                                                              .needs(
                                                                                cat,
                                                                              )
                                                                              .clean
                                                                              .toDouble(),
                                                                        ),
                                                                ),
                                                                Text(
                                                                  cat ==
                                                                          CatKind
                                                                              .maru
                                                                      ? 'Maru'
                                                                      : 'Lady',
                                                                  style: const TextStyle(
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
                                                  OutlinedButton.icon(
                                                    onPressed: _openTrailShop,
                                                    icon: const Icon(
                                                      Icons.storefront_rounded,
                                                    ),
                                                    label: Text(
                                                      'Tienda de estelas · ${widget.store.coins} 🪙',
                                                    ),
                                                  ),
                                                  const SizedBox(height: 8),
                                                  const Text(
                                                    'Arrastra el dedo a izquierda o derecha para dirigir el salto. También puedes mantener un lado o usar las flechas.\n\n🚀 Cohete: impulso de 2,4 s.\n🛸 OVNI: la nave te recoge y te lleva arriba.\n☂️ Paraguas: caída lenta durante 8 s.\nLos trampolines dorados te impulsan más alto.\nEvita las nubes eléctricas.',
                                                    textAlign: TextAlign.center,
                                                    style: TextStyle(
                                                      fontSize: 13,
                                                      height: 1.4,
                                                      color: Color(0xff59657a),
                                                    ),
                                                  ),
                                                ] else if (_game.over) ...[
                                                  _fallingCat(),
                                                  Text(
                                                    _game.endReason,
                                                    textAlign: TextAlign.center,
                                                  ),
                                                  Text(
                                                    '${_game.points} puntos · ${_game.coins} monedas',
                                                    style: const TextStyle(
                                                      fontSize: 18,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                  const Text(
                                                    'Las monedas ya están guardadas para tus sobres.',
                                                    textAlign: TextAlign.center,
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ] else
                                                  const Text(
                                                    'Maru y Lady te esperan.\nEl juego también se pausa al salir de la app.',
                                                    textAlign: TextAlign.center,
                                                  ),
                                                const SizedBox(height: 18),
                                                if (_game.over)
                                                  Wrap(
                                                    alignment:
                                                        WrapAlignment.center,
                                                    spacing: 10,
                                                    runSpacing: 8,
                                                    children: [
                                                      OutlinedButton.icon(
                                                        onPressed: () {
                                                          _record();
                                                          Navigator.pop(
                                                            context,
                                                          );
                                                        },
                                                        icon: const Icon(
                                                          Icons
                                                              .arrow_back_rounded,
                                                        ),
                                                        label: const Text(
                                                          'Volver',
                                                        ),
                                                      ),
                                                      FilledButton.icon(
                                                        onPressed: _start,
                                                        icon: const Icon(
                                                          Icons.rocket_launch,
                                                        ),
                                                        label: const Text(
                                                          'Otra subida',
                                                        ),
                                                      ),
                                                    ],
                                                  )
                                                else
                                                  FilledButton.icon(
                                                    onPressed: !_started
                                                        ? _start
                                                        : () => _pause(false),
                                                    icon: const Icon(
                                                      Icons.rocket_launch,
                                                    ),
                                                    label: Text(
                                                      !_started
                                                          ? '¡A saltar!'
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

class LeapWorldPainter extends CustomPainter {
  final LeapGame game;
  final CatKind cat;
  final String trail;
  LeapWorldPainter(this.game, this.cat, {this.trail = 'rainbow'});

  void _zoneHazard(
    Canvas canvas,
    Offset at,
    double width,
    LeapWorldZone zone,
    int seed,
  ) {
    final space = zone == LeapWorldZone.space;
    final portal =
        zone == LeapWorldZone.upperSky || zone == LeapWorldZone.heaven;
    final color = space
        ? const Color(0xffff5368)
        : portal
        ? const Color(0xffff793d)
        : zone == LeapWorldZone.underground
        ? const Color(0xffbd83ff)
        : const Color(0xfff59b57);
    canvas.save();
    canvas.translate(at.dx, at.dy);
    final bounds = Rect.fromLTWH(-width / 2, -23, width, 30);
    canvas.drawOval(
      bounds.inflate(5),
      Paint()
        ..color = color.withValues(
          alpha: .18 + math.sin(game.clock * 6 + seed) * .06,
        )
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    if (space) {
      canvas.drawPath(
        Path()
          ..moveTo(-width / 2, 5)
          ..lineTo(-width * .22, -10)
          ..quadraticBezierTo(0, -25, width * .22, -10)
          ..lineTo(width / 2, 5)
          ..quadraticBezierTo(0, 17, -width / 2, 5)
          ..close(),
        Paint()..color = const Color(0xffa72d46),
      );
      canvas.drawOval(
        Rect.fromLTWH(-16, -20, 32, 19),
        Paint()..color = const Color(0xff99ffcf),
      );
      for (var i = 0; i < 5; i++) {
        canvas.drawCircle(
          Offset(-width * .35 + i * width * .175, 3),
          2.5,
          Paint()
            ..color = color.withValues(
              alpha: .6 + math.sin(game.clock * 9 + i) * .35,
            ),
        );
      }
    } else if (portal) {
      canvas.drawOval(bounds, Paint()..color = const Color(0xff270e3e));
      for (var i = 0; i < 3; i++) {
        canvas.drawOval(
          bounds.deflate(i * 3),
          Paint()
            ..color = color.withValues(alpha: .8 - i * .2)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
      }
    } else if (zone == LeapWorldZone.city ||
        zone == LeapWorldZone.neighborhood) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(bounds, const Radius.circular(4)),
        Paint()..color = const Color(0xff3c465b),
      );
      final sparks = Path()..moveTo(-width / 2, -8);
      for (var i = 1; i <= 10; i++) {
        sparks.lineTo(
          -width / 2 + width * i / 10,
          -8 + math.sin(game.clock * 15 + i * 3) * 8,
        );
      }
      canvas.drawPath(
        sparks,
        Paint()
          ..color = const Color(0xffffdd75)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    } else {
      // Jagged stone ledge supports the crystals; no cloud beneath the spikes.
      final rock = Path()
        ..moveTo(-width / 2, 4)
        ..lineTo(width / 2, 4)
        ..lineTo(width / 2 - 4, 13)
        ..lineTo(width * .23, 18)
        ..lineTo(-width * .17, 20)
        ..lineTo(-width / 2 + 6, 14)
        ..close();
      canvas.drawPath(
        rock,
        Paint()
          ..shader = LinearGradient(
            colors: zone == LeapWorldZone.underground
                ? const [Color(0xff716184), Color(0xff3e354b)]
                : const [Color(0xffb18a64), Color(0xff655345)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ).createShader(Rect.fromLTWH(-width / 2, 4, width, 16)),
      );
      canvas.drawPath(
        Path()
          ..moveTo(-width * .32, 8)
          ..lineTo(-width * .12, 12)
          ..lineTo(-width * .05, 19)
          ..moveTo(width * .29, 6)
          ..lineTo(width * .17, 13)
          ..lineTo(width * .3, 16),
        Paint()
          ..color = const Color(0xff302b3d).withValues(alpha: .45)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );
      for (var i = 0; i < 5; i++) {
        final x = -width / 2 + i * width / 5;
        final peak = -15.0 - (i % 2) * 9;
        canvas.drawPath(
          Path()
            ..moveTo(x, 6)
            ..lineTo(x + width / 10, peak)
            ..lineTo(x + width / 5, 6)
            ..close(),
          Paint()..color = Color.lerp(color, const Color(0xff422c55), i / 7)!,
        );
        canvas.drawLine(
          Offset(x + width / 10, peak + 4),
          Offset(x + width / 10, 3),
          Paint()
            ..color = Colors.white.withValues(alpha: .4)
            ..strokeWidth = 1,
        );
      }
    }
    for (var i = 0; i < 8; i++) {
      final t = (game.clock * .9 + i / 8) % 1;
      final angle = i * math.pi / 4 + game.clock * .5;
      final point = Offset(
        math.cos(angle) * width * (.25 + t * .3),
        -5 + math.sin(angle) * (10 + t * 14),
      );
      canvas.drawCircle(
        point,
        1.5 * (1 - t),
        Paint()..color = color.withValues(alpha: 1 - t),
      );
    }
    canvas.restore();
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    final scale = size.width / 360;
    final height = size.height / scale;
    final altitude = game.camera + height * .42;
    final scenicAltitude = altitude / LeapGame.stageStretch;
    final dusk = ((scenicAltitude - 6400) / 4000).clamp(0.0, 1.0);
    final space = ((scenicAltitude - 11200) / 2000).clamp(0.0, 1.0);
    final heaven = ((altitude - LeapGame.heavenHeight + 300) / 900).clamp(
      0.0,
      1.0,
    );
    final underground = ((LeapGame.meadowHeight - altitude) / 900).clamp(
      0.0,
      1.0,
    );
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.lerp(
              Color.lerp(
                const Color(0xff342b3e),
                const Color(0xff48c4eb),
                1 - underground,
              )!,
              const Color(0xff171640),
              math.max(dusk * .82, space),
            )!,
            Color.lerp(
              Color.lerp(
                const Color(0xff5d493d),
                const Color(0xffb0e9ef),
                1 - underground,
              )!,
              const Color(0xff243566),
              math.max(dusk * .68, space),
            )!,
          ],
        ).createShader(Offset.zero & size),
    );
    canvas.save();
    canvas.scale(scale);
    if (heaven > 0) {
      canvas.drawRect(
        Rect.fromLTWH(0, 0, 360, height),
        Paint()..color = const Color(0xfffff3d0).withValues(alpha: heaven),
      );
      _heavenBackdrop(canvas, height, heaven);
    }
    final p = Paint();
    _journeyBackdrop(canvas, height, scenicAltitude);
    _landscapeDetails(canvas, height, altitude);
    for (var n = 0; n < 65; n++) {
      final x = (n * 71.37) % 360,
          y =
              ((n * 93.71 - game.camera * .15) % (height + 20) + height + 20) %
              (height + 20);
      p.color = Colors.white.withValues(
        alpha:
            (space * (1 - heaven) * (.45 + math.sin(game.clock * 2 + n) * .25))
                .clamp(0.0, 1.0),
      );
      canvas.drawCircle(Offset(x, y), n % 4 == 0 ? 1.7 : .8, p);
    }
    if (space > .15 && heaven < .1) {
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
    if (game.abducting) {
      final ship = Offset(game.ufoX, height - (game.ufoY - game.camera));
      final pulse = .34 + math.sin(game.clock * 10) * .045;
      final beam = Path()
        ..moveTo(ship.dx - 15, ship.dy + 9)
        ..lineTo(game.x - 33, foot + 5)
        ..quadraticBezierTo(game.x, foot + 15, game.x + 33, foot + 5)
        ..lineTo(ship.dx + 15, ship.dy + 9)
        ..close();
      canvas.drawPath(
        beam,
        Paint()
          ..shader =
              LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xffcaffbd).withValues(alpha: pulse + .15),
                  const Color(0xff72f4ca).withValues(alpha: .08),
                ],
              ).createShader(
                Rect.fromLTRB(ship.dx - 33, ship.dy, ship.dx + 33, foot + 15),
              ),
      );
      for (var i = 0; i < 4; i++) {
        final flow = (game.clock * .9 + i / 4) % 1;
        final ringY = foot - (foot - ship.dy - 16) * flow;
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(game.x, ringY),
            width: 57 - flow * 29,
            height: 9 - flow * 4,
          ),
          Paint()
            ..color = const Color(
              0xffd1ffc2,
            ).withValues(alpha: math.sin(flow * math.pi) * .42)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.3,
        );
      }
    }
    if (game.umbrellaOpen) {
      _umbrella(canvas, Offset(game.x, foot - 77), game.clock);
    }
    if (trail != 'none' && game.vy > 0 && !game.boosting) {
      final colors = trail == 'aurora'
          ? [
              const Color(0xff5affca),
              const Color(0xff77baff),
              const Color(0xffcd83ff),
            ]
          : trail == 'hearts'
          ? [
              const Color(0xffff6baf),
              const Color(0xffffb4da),
              const Color(0xffff86bb),
            ]
          : trail == 'comet'
          ? [
              const Color(0xffffd354),
              const Color(0xffffefae),
              const Color(0xffffa64d),
            ]
          : trail == 'galaxy'
          ? [
              const Color(0xff926bff),
              const Color(0xff5ddfff),
              const Color(0xffff8cdd),
            ]
          : trail == 'starlight'
          ? [
              const Color(0xffa98cff),
              const Color(0xff55d7ff),
              const Color(0xffd4b4ff),
            ]
          : trail == 'bubble'
          ? [
              const Color(0xff72f4e4),
              const Color(0xff8ce7ff),
              const Color(0xffb7fff1),
            ]
          : trail == 'flame'
          ? [
              const Color(0xffff6b61),
              const Color(0xffffb347),
              const Color(0xffffe07a),
            ]
          : [
              Color(0xffef86a1),
              Color(0xffffc078),
              Color(0xffffe98c),
              Color(0xff89dfb1),
              Color(0xff90d6ff),
              Color(0xffb7a0e9),
            ];
      final count = trail == 'rainbow' ? 6 : 3;
      final trailOffset = game.vx.abs() < 1
          ? 0.0
          : -game.vx.sign * math.min(game.vx.abs() * .08, 22);
      for (var n = 0; n < count; n++) {
        final path = Path()
          // Keep the trail behind the cat's feet. Starting above the foot
          // made it appear to pass through the character during jumps.
          ..moveTo(game.x - (count - 1) * 2.5 + n * 5, foot - 8)
          ..quadraticBezierTo(
            game.x + trailOffset - 14 + n * 5,
            foot + 28,
            game.x + trailOffset - 14 + n * 5,
            foot + 64,
          );
        if (trail == 'rainbow' || trail == 'aurora' || trail == 'comet') {
          canvas.drawPath(
            path,
            Paint()
              ..shader = LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  colors[n % colors.length].withValues(alpha: .7),
                  colors[n % colors.length].withValues(alpha: 0),
                ],
              ).createShader(Rect.fromLTWH(game.x - 40, foot - 8, 80, 72))
              ..style = PaintingStyle.stroke
              ..strokeWidth = trail == 'bubble' ? 7 : 5
              ..strokeCap = StrokeCap.round,
          );
        }
        if (trail == 'bubble') {
          canvas.drawCircle(
            Offset(
              game.x - game.vx * .18 + n * 7,
              foot + 35 + math.sin(game.clock * 3 + n) * 8,
            ),
            4 + (n % 2) * 3,
            Paint()..color = colors[n % colors.length].withValues(alpha: .42),
          );
        }
      }
      for (var n = 0; n < 14 && trail != 'rainbow'; n++) {
        final age = (game.clock * 1.4 + n / 14) % 1;
        final spread = math.sin(n * 2.4 + game.clock * 2) * (4 + age * 17);
        final at = Offset(
          game.x + trailOffset * age + spread,
          foot - 6 + age * 78,
        );
        final radius = (1 - age) * 4 + .5;
        final ink = Paint()
          ..color = colors[n % colors.length].withValues(alpha: (1 - age) * .8);
        if (trail == 'bubble') {
          ink
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2;
          canvas.drawCircle(at, radius + 2, ink);
        } else if (trail == 'hearts') {
          canvas.drawPath(
            Path()
              ..moveTo(at.dx, at.dy + radius)
              ..cubicTo(
                at.dx - radius * 2,
                at.dy,
                at.dx - radius,
                at.dy - radius * 2,
                at.dx,
                at.dy - radius * .5,
              )
              ..cubicTo(
                at.dx + radius,
                at.dy - radius * 2,
                at.dx + radius * 2,
                at.dy,
                at.dx,
                at.dy + radius,
              )
              ..close(),
            ink,
          );
        } else if (trail == 'flame') {
          canvas.drawOval(
            Rect.fromCenter(center: at, width: radius * 2, height: radius * 4),
            ink,
          );
        } else {
          final star = Path();
          for (var point = 0; point < 8; point++) {
            final angle = point * math.pi / 4;
            final r = point.isEven ? radius * 1.6 : radius * .4;
            final x = at.dx + math.cos(angle) * r,
                y = at.dy + math.sin(angle) * r;
            if (point == 0) {
              star.moveTo(x, y);
            } else {
              star.lineTo(x, y);
            }
          }
          canvas.drawPath(star..close(), ink);
        }
      }
    }
    if (game.boosting) {
      _fireTrail(canvas, Offset(game.x, foot + 4), game.clock);
    }
    for (final platform in game.platforms) {
      final vanish = platform.vanishingAt == null
          ? 0.0
          : ((game.clock - platform.vanishingAt!) / .65).clamp(0.0, 1.0);
      final opacity = 1 - vanish;
      final y = height - (platform.y - game.camera) + vanish * 14;
      if (y < -40 || y > height + 40) continue;
      if (platform.kind == LeapPlatformKind.storm &&
          game.zoneAt(platform.y) != LeapWorldZone.skyscrapers) {
        _zoneHazard(
          canvas,
          Offset(platform.x, y),
          platform.width,
          game.zoneAt(platform.y),
          platform.id,
        );
      } else if (platform.kind == LeapPlatformKind.rock) {
        final subterranean = platform.y < LeapGame.meadowHeight;
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
        canvas.drawPath(
          rock,
          Paint()
            ..color = subterranean
                ? const Color(0xff626571)
                : const Color(0xff967355),
        );
        canvas.drawPath(
          rock,
          Paint()
            ..color = subterranean
                ? const Color(0xff3f414c)
                : const Color(0xff765c49)
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
            Paint()
              ..color = subterranean
                  ? const Color(0xff858895)
                  : const Color(0xffb38b61),
          );
        }
        if (!subterranean) {
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
        }
      } else if (platform.kind == LeapPlatformKind.airplane) {
        canvas.save();
        canvas.translate(platform.x, y + 2);
        canvas.scale(platform.facingRight ? 1 : -1, 1);
        if (game.zoneAt(platform.y) == LeapWorldZone.space) {
          _satellitePlatform(canvas, platform.width);
        } else {
          _airplanePlatform(canvas, Offset.zero, platform.width);
        }
        canvas.restore();
      } else {
        final storm = platform.kind == LeapPlatformKind.storm;
        final paint = Paint()
          ..color = (storm ? const Color(0xff68748e) : Colors.white).withValues(
            alpha: opacity,
          );
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
        if (storm) {
          final pulse = .58 + math.sin(game.clock * 9 + platform.id) * .22;
          canvas.drawPath(
            path,
            Paint()
              ..color = const Color(0xff77ddff).withValues(alpha: pulse)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 9
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
          );
          canvas.drawPath(
            path,
            Paint()
              ..color = const Color(0xffb8f3ff).withValues(alpha: pulse)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2.2,
          );
        }
        canvas.drawPath(
          path.shift(const Offset(0, 3)),
          Paint()
            ..color =
                (storm ? const Color(0xff4e5b76) : const Color(0xffb7dcec))
                    .withValues(alpha: opacity),
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
          for (var i = 0; i < 7; i++) {
            final phase = (game.clock * 2.6 + i * .19 + platform.id * .07) % 1;
            if (phase > .68) continue;
            final angle = i / 7 * math.pi * 2 + game.clock * .25;
            final center = Offset(
              platform.x + math.cos(angle) * (platform.width * .62),
              y + 13 + math.sin(angle) * 29,
            );
            final direction = Offset(math.cos(angle), math.sin(angle));
            final side = Offset(-direction.dy, direction.dx);
            final spark = Path()
              ..moveTo(
                center.dx - direction.dx * 7,
                center.dy - direction.dy * 7,
              )
              ..lineTo(center.dx + side.dx * 3, center.dy + side.dy * 3)
              ..lineTo(
                center.dx + direction.dx * 8,
                center.dy + direction.dy * 8,
              );
            canvas.drawPath(
              spark,
              Paint()
                ..color = const Color(0xffd9fbff).withValues(alpha: 1 - phase)
                ..style = PaintingStyle.stroke
                ..strokeWidth = 1.8
                ..strokeCap = StrokeCap.round,
            );
            canvas.drawCircle(
              center,
              2.4 * (1 - phase),
              Paint()
                ..color = const Color(0xffffef82).withValues(alpha: 1 - phase),
            );
          }
        }
        if (!storm && vanish > 0) {
          for (var i = 0; i < 6; i++) {
            final drift = vanish * (18 + i * 3);
            canvas.drawCircle(
              Offset(
                platform.x - 24 + i * 10 + (i.isEven ? -drift : drift) * .35,
                y + 10 - drift,
              ),
              3.5 * opacity,
              Paint()..color = Colors.white.withValues(alpha: opacity * .7),
            );
          }
        }
      }
      if (platform.trampoline) {
        final bounce = platform.springAt == null
            ? 0.0
            : (1 - (game.clock - platform.springAt!) / .35).clamp(0.0, 1.0);
        final springWidth = math.min(38.0, platform.width * .65);
        final springPaint = Paint()
          ..color = const Color(0xffb8e6df)
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke;
        for (final dx in [-springWidth * .3, springWidth * .3]) {
          final zig = Path()..moveTo(platform.x + dx, y + 3);
          for (var n = 0; n < 4; n++) {
            zig.lineTo(
              platform.x + dx + (n.isEven ? -3 : 3),
              y - 1 - n * (2 + bounce * 2),
            );
          }
          canvas.drawPath(zig, springPaint);
        }
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset(platform.x, y - 8 - bounce * 6),
              width: springWidth,
              height: 7,
            ),
            const Radius.circular(4),
          ),
          Paint()..color = const Color(0xfff6bb59),
        );
        canvas.drawLine(
          Offset(platform.x - 8, y - 9 - bounce * 6),
          Offset(platform.x + 8, y - 9 - bounce * 6),
          Paint()
            ..color = const Color(0xffffedaa)
            ..strokeWidth = 2,
        );
      }
      if (platform.motion > 0 && platform.kind != LeapPlatformKind.airplane) {
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
      if (pickup.kind != LeapPickupKind.coin) {
        final color = pickup.kind == LeapPickupKind.rocket
            ? const Color(0xffffd478)
            : const Color(0xff98ffe0);
        canvas.drawCircle(at, 25, Paint()..color = const Color(0xaa173450));
        canvas.drawCircle(
          at,
          27 + math.sin(game.clock * 3) * 2,
          Paint()
            ..color = color
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
      }
      switch (pickup.kind) {
        case LeapPickupKind.rocket:
          _rocket(canvas, at, game.clock);
        case LeapPickupKind.ufo:
          _ufo(canvas, at, game.clock);
        case LeapPickupKind.umbrella:
          canvas.save();
          canvas.translate(at.dx, at.dy - 6);
          canvas.scale(.58);
          _umbrella(canvas, Offset.zero, game.clock);
          canvas.restore();
        case LeapPickupKind.coin:
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
    if (game.abducting || game.ufoDepartureTime > 0) {
      canvas.save();
      canvas.translate(game.ufoX, height - (game.ufoY - game.camera));
      canvas.scale(1.75);
      _ufo(canvas, Offset.zero, game.clock);
      canvas.restore();
    }
    canvas.restore();
    canvas.restore();
  }

  double _bandAlpha(double altitude, double start, double end) {
    const feather = 1000.0;
    final fadeIn = ((altitude - start) / feather).clamp(0.0, 1.0);
    final fadeOut = ((end - altitude) / feather).clamp(0.0, 1.0);
    final t = math.min(fadeIn, fadeOut);
    return t * t * (3 - 2 * t);
  }

  void _journeyBackdrop(Canvas canvas, double height, double altitude) {
    final cave = _bandAlpha(altitude, -700, 2250);
    if (cave > 0) {
      final wallPaint = Paint()
        ..color = const Color(0xff281f31).withValues(alpha: cave * .72);
      canvas.drawPath(
        Path()
          ..moveTo(0, 0)
          ..lineTo(38, 0)
          ..lineTo(25, 48)
          ..lineTo(45, 92)
          ..lineTo(22, 145)
          ..lineTo(42, 210)
          ..lineTo(0, 250)
          ..close(),
        wallPaint,
      );
      canvas.drawPath(
        Path()
          ..moveTo(360, 0)
          ..lineTo(322, 0)
          ..lineTo(338, 58)
          ..lineTo(316, 112)
          ..lineTo(341, 174)
          ..lineTo(320, 232)
          ..lineTo(360, 270)
          ..close(),
        wallPaint,
      );
      for (var i = 0; i < 8; i++) {
        final x = i.isEven ? 18.0 : 340.0;
        final y = (i * 89.0 - game.camera * .11) % (height + 50);
        final crystal = Path()
          ..moveTo(x - 6, y + 10)
          ..lineTo(x, y - 13)
          ..lineTo(x + 7, y + 10)
          ..close();
        canvas.drawPath(
          crystal,
          Paint()
            ..color = const Color(0xff8ce3d0).withValues(alpha: cave * .65),
        );
      }
      _caveSkeleton(canvas, Offset(85, height * .28), cave, false);
      _caveSkeleton(canvas, Offset(274, height * .68), cave * .8, true);
    }

    final meadow = _bandAlpha(altitude, 900, 3700);
    if (meadow > 0) {
      final base = height - 24 + ((altitude - 900) / 2800).clamp(0.0, 1.0) * 65;
      canvas.drawRect(
        Rect.fromLTWH(0, base, 360, height - base),
        Paint()..color = const Color(0xff64b86c).withValues(alpha: meadow),
      );
      for (var i = 0; i < 5; i++) {
        final x = 18.0 + i * 82;
        canvas.drawRect(
          Rect.fromLTWH(x, base - 24 - (i % 2) * 9, 5, 26),
          Paint()..color = const Color(0xff7b5a3e).withValues(alpha: meadow),
        );
        canvas.drawCircle(
          Offset(x + 2, base - 29 - (i % 2) * 9),
          15,
          Paint()..color = const Color(0xff48a95b).withValues(alpha: meadow),
        );
      }
    }

    final neighborhood = _bandAlpha(altitude, 2450, 5700);
    if (neighborhood > 0) {
      final base = height - 8 + ((altitude - 2450) / 3250).clamp(0.0, 1.0) * 90;
      const roofs = [42.0, 58.0, 37.0, 66.0, 49.0, 61.0];
      for (var i = 0; i < roofs.length; i++) {
        final x = -8.0 + i * 66;
        final h = roofs[i];
        final wall = Rect.fromLTWH(x, base - h, 58, h);
        canvas.drawRect(
          wall,
          Paint()
            ..color = const Color(0xffe7b27d).withValues(alpha: neighborhood),
        );
        final roof = Path()
          ..moveTo(x - 4, base - h)
          ..lineTo(x + 29, base - h - 22)
          ..lineTo(x + 62, base - h)
          ..close();
        canvas.drawPath(
          roof,
          Paint()
            ..color = const Color(0xffd75f62).withValues(alpha: neighborhood),
        );
        canvas.drawRect(
          Rect.fromLTWH(x + 23, base - 23, 13, 23),
          Paint()
            ..color = const Color(0xff765775).withValues(alpha: neighborhood),
        );
      }
    }

    final city = _bandAlpha(
      altitude,
      (LeapGame.cityHeight / LeapGame.stageStretch) - 750,
      (LeapGame.skyscraperHeight / LeapGame.stageStretch),
    );
    if (city > 0) {
      final base = height + ((altitude - 4450) / 3150).clamp(0.0, 1.0) * 120;
      const heights = [105.0, 165.0, 128.0, 205.0, 145.0, 185.0, 116.0];
      for (var i = 0; i < heights.length; i++) {
        final x = -18.0 + i * 58;
        final h = heights[i];
        final color = Color.lerp(
          const Color(0xff52759a),
          const Color(0xff30385f),
          i / heights.length,
        )!.withValues(alpha: city * .9);
        canvas.drawRect(
          Rect.fromLTWH(x, base - h, 52, h),
          Paint()..color = color,
        );
        for (var row = 0; row < (h / 24).floor(); row++) {
          for (var col = 0; col < 3; col++) {
            canvas.drawRect(
              Rect.fromLTWH(x + 8 + col * 14, base - h + 12 + row * 22, 6, 8),
              Paint()
                ..color = const Color(0xffffdc83).withValues(
                  alpha: city * (row.isEven == col.isEven ? .8 : .28),
                ),
            );
          }
        }
      }
    }

    final towers = _bandAlpha(
      altitude,
      (LeapGame.skyscraperHeight / LeapGame.stageStretch) - 850,
      (LeapGame.upperSkyHeight / LeapGame.stageStretch),
    );
    if (towers > 0) {
      final base = height + ((altitude - 6750) / 3250).clamp(0.0, 1.0) * 155;
      const heights = [250.0, 360.0, 290.0, 430.0, 325.0];
      for (var i = 0; i < heights.length; i++) {
        final x = -30.0 + i * 92;
        final h = heights[i];
        final body = RRect.fromRectAndRadius(
          Rect.fromLTWH(x, base - h, 76, h),
          const Radius.circular(5),
        );
        canvas.drawRRect(
          body,
          Paint()
            ..color = const Color(0xff252c54).withValues(alpha: towers * .82),
        );
        canvas.drawRect(
          Rect.fromLTWH(x + 35, base - h - 28, 5, 28),
          Paint()..color = const Color(0xffd65e78).withValues(alpha: towers),
        );
        for (var row = 0; row < (h / 28).floor(); row++) {
          canvas.drawRect(
            Rect.fromLTWH(x + 11, base - h + 14 + row * 27, 54, 5),
            Paint()
              ..color = const Color(0xff7fcde1).withValues(alpha: towers * .58),
          );
        }
      }
    }

    final highSky = _bandAlpha(
      altitude,
      (LeapGame.upperSkyHeight / LeapGame.stageStretch) - 800,
      (LeapGame.spaceHeight / LeapGame.stageStretch) + 700,
    );
    if (highSky > 0) {
      for (var i = 0; i < 9; i++) {
        final x = (i * 79.0 + game.camera * .025) % 430 - 35;
        final y = (i * 97.0 - game.camera * .08) % (height + 90);
        canvas.drawOval(
          Rect.fromCenter(center: Offset(x, y), width: 70, height: 18),
          Paint()..color = Colors.white.withValues(alpha: highSky * .22),
        );
      }
    }
  }

  // A bounded set of vector details: no image loading or random work per frame.
  void _landscapeDetails(Canvas canvas, double height, double altitude) {
    final boundary = <double>[
      0,
      LeapGame.meadowHeight,
      LeapGame.neighborhoodHeight,
      LeapGame.cityHeight,
      LeapGame.skyscraperHeight,
      LeapGame.upperSkyHeight,
      LeapGame.spaceHeight,
      LeapGame.heavenHeight,
    ];
    final zone = game.zoneAt(altitude);
    final zoneStart = boundary[zone.index];
    final zoneEnd = zone.index == 7
        ? double.infinity
        : boundary[zone.index + 1];
    final blendIn = zone.index == 0
        ? 1.0
        : ((altitude - zoneStart) / 700).clamp(0.0, 1.0);
    final blendOut = ((zoneEnd - altitude) / 700).clamp(0.0, 1.0);
    final alpha = math.min(blendIn, blendOut);
    canvas.saveLayer(
      Rect.fromLTWH(0, 0, 360, height),
      Paint()
        ..color = Colors.white.withValues(
          alpha: alpha * alpha * (3 - 2 * alpha),
        ),
    );
    final paint = Paint()..strokeWidth = 1.5;
    for (var i = 0; i < 12; i++) {
      final x = 18.0 + (i * 83.0) % 324;
      final y = (i * 137.0 - game.camera * .12) % (height + 80) - 40;
      final at = Offset(x, y);
      switch (zone) {
        case LeapWorldZone.underground:
          paint.color = const Color(0xffc596bd).withValues(alpha: .22);
          canvas.drawOval(
            Rect.fromCenter(center: at, width: 23, height: 10),
            paint,
          );
          canvas.drawLine(
            at + const Offset(-9, 8),
            at + const Offset(5, 13),
            paint,
          );
        case LeapWorldZone.meadow:
          paint.color = const Color(0xff488e69).withValues(alpha: .25);
          canvas.drawLine(at, at + const Offset(0, 15), paint);
          for (var petal = 0; petal < 5; petal++) {
            final angle = petal * math.pi * 2 / 5;
            paint.color = const Color(0xffffdaa1).withValues(alpha: .45);
            canvas.drawCircle(
              at + Offset(math.cos(angle) * 4, math.sin(angle) * 4),
              3,
              paint,
            );
          }
        case LeapWorldZone.neighborhood:
        case LeapWorldZone.city:
          paint.color = const Color(0xffe9f5ee).withValues(alpha: .35);
          final bird = Path()
            ..moveTo(x - 8, y + 3)
            ..quadraticBezierTo(x - 4, y - 3, x, y)
            ..quadraticBezierTo(x + 4, y - 3, x + 8, y + 3);
          paint.style = PaintingStyle.stroke;
          canvas.drawPath(bird, paint);
          paint.style = PaintingStyle.fill;
        case LeapWorldZone.skyscrapers:
        case LeapWorldZone.upperSky:
          paint.color = const Color(0xffeef8ff).withValues(alpha: .18);
          canvas.drawOval(
            Rect.fromCenter(center: at, width: 46, height: 9),
            paint,
          );
          canvas.drawOval(
            Rect.fromCenter(
              center: at + const Offset(13, -5),
              width: 30,
              height: 11,
            ),
            paint,
          );
        case LeapWorldZone.space:
          paint.color = const Color(0xffcbb0ed).withValues(alpha: .13);
          canvas.drawOval(
            Rect.fromCenter(center: at, width: 64, height: 23),
            paint,
          );
          paint.color = const Color(0xffffe4a8).withValues(alpha: .55);
          canvas.drawLine(
            at - const Offset(3, 0),
            at + const Offset(3, 0),
            paint,
          );
          canvas.drawLine(
            at - const Offset(0, 3),
            at + const Offset(0, 3),
            paint,
          );
        case LeapWorldZone.heaven:
          paint.color = const Color(0xffcfab54).withValues(alpha: .3);
          canvas.drawCircle(at, 4, paint);
          canvas.drawLine(
            at + const Offset(-8, 0),
            at + const Offset(8, 0),
            paint,
          );
          canvas.drawLine(
            at + const Offset(0, -8),
            at + const Offset(0, 8),
            paint,
          );
      }
    }
    canvas.restore();
  }

  void _caveSkeleton(Canvas canvas, Offset at, double alpha, bool flipped) {
    canvas.save();
    canvas.translate(at.dx, at.dy);
    if (flipped) canvas.scale(-1, 1);
    final bone = Paint()
      ..color = const Color(0xffd9c9a5).withValues(alpha: alpha * .7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    canvas.drawOval(const Rect.fromLTWH(-34, -13, 21, 19), bone);
    canvas.drawCircle(const Offset(-28, -6), 2, bone);
    canvas.drawLine(const Offset(-13, -4), const Offset(31, -4), bone);
    for (var i = 0; i < 5; i++) {
      final x = -5.0 + i * 8;
      canvas.drawLine(Offset(x, -4), Offset(x - 6, -14), bone);
      canvas.drawLine(Offset(x, -4), Offset(x - 6, 7), bone);
    }
    canvas.drawPath(
      Path()
        ..moveTo(31, -4)
        ..lineTo(43, -15)
        ..lineTo(42, 7)
        ..close(),
      bone,
    );
    canvas.restore();
  }

  void _heavenBackdrop(Canvas canvas, double height, double opacity) {
    final cloud = Paint()..color = Colors.white.withValues(alpha: opacity * .8);
    for (var i = 0; i < 12; i++) {
      final cy = (i * 113 - game.camera * .18) % (height + 120) - 40;
      final cx = (i * 83.0) % 360;
      canvas.drawOval(
        Rect.fromCenter(center: Offset(cx, cy), width: 145, height: 44),
        cloud,
      );
      canvas.drawCircle(Offset(cx - 25, cy - 13), 27, cloud);
      canvas.drawCircle(Offset(cx + 20, cy - 19), 32, cloud);
    }
    final gateY = height - (LeapGame.heavenHeight + 300 - game.camera);
    if (gateY < -240 || gateY > height + 240) return;
    final gate = Rect.fromLTWH(116, gateY - 180, 128, 180);
    final arch = RRect.fromRectAndCorners(
      gate,
      topLeft: const Radius.circular(64),
      topRight: const Radius.circular(64),
    );
    canvas.drawRRect(
      arch,
      Paint()
        ..color = const Color(0xffffdf72)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
    );
    canvas.drawRRect(
      arch,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xffffefb0), Color(0xffe5aa28), Color(0xffffe992)],
        ).createShader(gate),
    );
    canvas.drawRRect(arch.deflate(7), Paint()..color = const Color(0xfffffff4));
    final gold = Paint()
      ..color = const Color(0xffc98e20)
      ..strokeWidth = 3;
    for (var i = 0; i < 7; i++) {
      final gx = 130 + i * 17.0;
      canvas.drawLine(Offset(gx, gateY - 122), Offset(gx, gateY - 8), gold);
    }
    canvas.drawLine(Offset(180, gateY - 160), Offset(180, gateY), gold);
    final label = TextPainter(
      text: const TextSpan(
        text: 'CIELO',
        style: TextStyle(
          color: Color(0xffad7818),
          fontSize: 25,
          fontWeight: FontWeight.w900,
          letterSpacing: 4,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    label.paint(canvas, Offset(180 - label.width / 2, gateY - 222));
    for (var i = 0; i < 5; i++) {
      canvas.drawCircle(Offset(106 + i * 37.0, gateY + 8), 30, cloud);
    }
  }

  void _satellitePlatform(Canvas canvas, double width) {
    final metal = Paint()..color = const Color(0xffd5dee9);
    final seam = Paint()
      ..color = const Color(0xff8eabc3)
      ..strokeWidth = 1;
    final half = width / 2;
    // Solar arrays stay inside the platform width, with their top at the landing plane.
    for (final side in [-1.0, 1.0]) {
      final panel = Rect.fromLTWH(side < 0 ? -half : 17, 0, half - 17, 22);
      canvas.drawRect(panel.inflate(1), metal);
      canvas.drawRect(panel, Paint()..color = const Color(0xff326fb5));
      for (var i = 1; i < 4; i++) {
        final x = panel.left + panel.width * i / 4;
        canvas.drawLine(Offset(x, 0), Offset(x, 22), seam);
      }
      canvas.drawLine(Offset(panel.left, 11), Offset(panel.right, 11), seam);
      canvas.drawLine(
        Offset(side * 12, 11),
        Offset(side * 19, 11),
        metal..strokeWidth = 3,
      );
    }
    final body = RRect.fromRectAndRadius(
      const Rect.fromLTWH(-13, 0, 26, 23),
      const Radius.circular(5),
    );
    canvas.drawRRect(
      body,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xfff0f4f8), Color(0xffa1b4c9)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(body.outerRect),
    );
    canvas.drawLine(const Offset(-9, 7), const Offset(9, 7), seam);
    canvas.drawLine(const Offset(-9, 17), const Offset(9, 17), seam);
    canvas.drawLine(const Offset(0, 0), const Offset(0, -7), seam);
    canvas.drawArc(
      const Rect.fromLTWH(-9, -15, 18, 12),
      0,
      math.pi,
      true,
      metal,
    );
    canvas.drawLine(const Offset(0, -9), const Offset(5, -19), seam);
    canvas.drawCircle(
      const Offset(5, -19),
      1.8,
      Paint()..color = const Color(0xffedfaff),
    );
    canvas.drawCircle(
      const Offset(7, 12),
      2,
      Paint()..color = const Color(0xff80efb9),
    );
  }

  void _airplanePlatform(Canvas canvas, Offset at, double width) {
    canvas.save();
    canvas.translate(at.dx, at.dy);
    final half = width / 2;
    final outline = Paint()
      ..color = const Color(0xff294867)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeJoin = StrokeJoin.round;
    // Speed streaks replace the old square movement badge.
    for (var i = 0; i < 3; i++) {
      canvas.drawLine(
        Offset(-half - 17 - i * 5, 5 + i * 5),
        Offset(-half - 4, 5 + i * 5),
        Paint()
          ..color = Colors.white.withValues(alpha: .22 + i * .08)
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round,
      );
    }
    final body = Path()
      ..moveTo(-half + 5, 0)
      ..quadraticBezierTo(-half - 1, 9, -half + 12, 15)
      ..quadraticBezierTo(0, 20, half - 16, 14)
      ..quadraticBezierTo(half - 4, 11, half + 5, 3)
      ..quadraticBezierTo(half + 7, 0, half - 1, 0)
      ..close();
    canvas.drawPath(body, Paint()..color = const Color(0xfff8fbfd));
    canvas.drawPath(body, outline);
    canvas.drawPath(
      Path()
        ..moveTo(-half + 9, 13)
        ..quadraticBezierTo(2, 21, half - 14, 12),
      Paint()
        ..color = const Color(0xffe97989)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    final wing = Path()
      ..moveTo(-8, 12)
      ..lineTo(-29, 34)
      ..lineTo(-7, 32)
      ..lineTo(17, 13)
      ..close();
    canvas.drawPath(wing, Paint()..color = const Color(0xffbed9e8));
    canvas.drawPath(wing, outline);
    final farWing = Path()
      ..moveTo(-3, 3)
      ..lineTo(15, -12)
      ..lineTo(28, -10)
      ..lineTo(14, 4)
      ..close();
    canvas.drawPath(farWing, Paint()..color = const Color(0xffd9e8ef));
    canvas.drawPath(farWing, outline);
    final tail = Path()
      ..moveTo(-half + 8, 3)
      ..lineTo(-half + 15, -16)
      ..lineTo(-half + 28, 3)
      ..close();
    canvas.drawPath(tail, Paint()..color = const Color(0xffe88191));
    canvas.drawPath(tail, outline);
    // Cockpit and cabin windows.
    final cockpit = Path()
      ..moveTo(half - 15, 3)
      ..quadraticBezierTo(half - 7, 3, half - 3, 5)
      ..quadraticBezierTo(half - 10, 10, half - 18, 10)
      ..close();
    canvas.drawPath(cockpit, Paint()..color = const Color(0xff4d91b0));
    for (var i = 0; i < 4; i++) {
      canvas.drawCircle(
        Offset(-20 + i * 10, 7),
        2.1,
        Paint()..color = const Color(0xff397f9f),
      );
    }
    // Two small engine pods make the silhouette read as an aircraft.
    for (final x in [-15.0, 11.0]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x - 5, 23, 13, 8),
          const Radius.circular(4),
        ),
        Paint()..color = const Color(0xff607f96),
      );
      canvas.drawCircle(
        Offset(x - 4, 27),
        3,
        Paint()..color = const Color(0xff263e57),
      );
    }
    canvas.restore();
  }

  void _fireTrail(Canvas canvas, Offset at, double t) {
    canvas.save();
    canvas.translate(at.dx, at.dy);
    final sway = math.sin(t * 18) * 5;
    final outer = Path()
      ..moveTo(-17, -3)
      ..quadraticBezierTo(-24 + sway, 32, -8, 78)
      ..quadraticBezierTo(0 + sway, 62, 8, 78)
      ..quadraticBezierTo(24 + sway, 32, 17, -3)
      ..close();
    canvas.drawPath(
      outer,
      Paint()..color = const Color(0xffff5b45).withValues(alpha: .82),
    );
    final middle = Path()
      ..moveTo(-11, -2)
      ..quadraticBezierTo(-12 - sway, 30, 0, 64)
      ..quadraticBezierTo(14 - sway, 30, 11, -2)
      ..close();
    canvas.drawPath(
      middle,
      Paint()..color = const Color(0xffffb13b).withValues(alpha: .92),
    );
    final core = Path()
      ..moveTo(-5, -1)
      ..quadraticBezierTo(-6 + sway * .4, 23, 0, 47)
      ..quadraticBezierTo(7 + sway * .4, 23, 5, -1)
      ..close();
    canvas.drawPath(core, Paint()..color = const Color(0xfffff3a0));
    for (var i = 0; i < 7; i++) {
      final phase = (t * 2.7 + i * .17) % 1;
      canvas.drawCircle(
        Offset(math.sin(i * 2.4 + t * 9) * (8 + phase * 13), 20 + phase * 70),
        2.8 * (1 - phase),
        Paint()..color = const Color(0xffffd25a).withValues(alpha: 1 - phase),
      );
    }
    canvas.restore();
  }

  void _umbrella(Canvas canvas, Offset at, double t) {
    canvas.save();
    canvas.translate(at.dx, at.dy);
    canvas.rotate(math.sin(t * 3) * .045);
    final stick = Paint()
      ..color = const Color(0xffeee4bc)
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawPath(
      Path()
        ..moveTo(0, -21)
        ..lineTo(0, 40)
        ..quadraticBezierTo(0, 48, 8, 44),
      stick,
    );
    final canopy = Path()
      ..moveTo(-34, 0)
      ..cubicTo(-29, -36, 29, -36, 34, 0)
      ..quadraticBezierTo(24, -8, 17, 0)
      ..quadraticBezierTo(9, -8, 0, 0)
      ..quadraticBezierTo(-9, -8, -17, 0)
      ..quadraticBezierTo(-24, -8, -34, 0)
      ..close();
    canvas.drawPath(
      canopy,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xffe88ba6), Color(0xffcfa4f5), Color(0xff80d7d0)],
        ).createShader(const Rect.fromLTWH(-34, -28, 68, 28)),
    );
    final seams = Paint()
      ..color = const Color(0xbbfff0cf)
      ..strokeWidth = 1.1
      ..style = PaintingStyle.stroke;
    canvas.drawPath(canopy, seams);
    for (final x in [-17.0, 0.0, 17.0]) {
      canvas.drawPath(
        Path()
          ..moveTo(0, -27)
          ..quadraticBezierTo(x, -19, x, 0),
        seams,
      );
    }
    canvas.drawCircle(
      const Offset(0, -28),
      2.5,
      Paint()..color = const Color(0xffffdfa4),
    );
    canvas.restore();
  }

  void _ufo(Canvas canvas, Offset at, double t) {
    canvas.save();
    canvas.translate(at.dx, at.dy + math.sin(t * 4) * 3);
    canvas.drawOval(
      const Rect.fromLTWH(-14, -13, 28, 20),
      Paint()..color = const Color(0xffa8e9ee),
    );
    canvas.drawOval(
      const Rect.fromLTWH(-23, -2, 46, 15),
      Paint()..color = const Color(0xff8e91a9),
    );
    canvas.drawOval(
      const Rect.fromLTWH(-19, 1, 38, 9),
      Paint()..color = const Color(0xffc8ccd8),
    );
    for (var i = 0; i < 5; i++) {
      final glow = .6 + math.sin(t * 8 + i) * .3;
      canvas.drawCircle(
        Offset(-13 + i * 6.5, 7),
        2.2,
        Paint()..color = const Color(0xff8cff72).withValues(alpha: glow),
      );
    }
    canvas.drawCircle(
      const Offset(0, -5),
      5,
      Paint()..color = const Color(0xff63d956),
    );
    canvas.drawOval(
      const Rect.fromLTWH(-4, -7, 3, 5),
      Paint()..color = const Color(0xff15243c),
    );
    canvas.drawOval(
      const Rect.fromLTWH(1, -7, 3, 5),
      Paint()..color = const Color(0xff15243c),
    );
    canvas.restore();
  }

  void _rocket(Canvas canvas, Offset at, double t) {
    canvas.save();
    canvas.translate(at.dx, at.dy);
    canvas.rotate(-.25);
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
  bool shouldRepaint(covariant LeapWorldPainter oldDelegate) => true;
}

class _CryingFacePainter extends CustomPainter {
  final double progress;
  const _CryingFacePainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final ink = Paint()
      ..color = const Color(0xff34263f)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    for (final x in [.40, .61]) {
      canvas.drawArc(
        Rect.fromCenter(
          center: Offset(size.width * x, size.height * .36),
          width: 11,
          height: 7,
        ),
        .15,
        math.pi - .3,
        false,
        ink,
      );
      final tearTop = size.height * .40;
      final tearLength = 9 + progress * 15;
      final tear = Path()
        ..moveTo(size.width * x, tearTop)
        ..quadraticBezierTo(
          size.width * x - 5,
          tearTop + tearLength * .65,
          size.width * x,
          tearTop + tearLength,
        )
        ..quadraticBezierTo(
          size.width * x + 5,
          tearTop + tearLength * .65,
          size.width * x,
          tearTop,
        )
        ..close();
      canvas.drawPath(
        tear,
        Paint()
          ..color = const Color(0xff65d5ff).withValues(alpha: progress * .9),
      );
      canvas.drawCircle(
        Offset(size.width * x - 1.3, tearTop + tearLength * .52),
        1.5,
        Paint()..color = Colors.white.withValues(alpha: progress * .8),
      );
    }
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(size.width * .505, size.height * .57),
        width: 14,
        height: 10,
      ),
      math.pi + .2,
      math.pi - .4,
      false,
      ink,
    );
  }

  @override
  bool shouldRepaint(covariant _CryingFacePainter oldDelegate) =>
      oldDelegate.progress != progress;
}
