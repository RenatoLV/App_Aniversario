import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'cat_character.dart';
import 'match3.dart';
import 'store.dart';
import 'game_audio.dart';
import 'game_result.dart';

const _sweetColors = [
  Color(0xffff749d),
  Color(0xffffa95e),
  Color(0xffffd36c),
  Color(0xff65d3b0),
  Color(0xff72caff),
  Color(0xffb999ff),
];

class SweetScreen extends StatefulWidget {
  final GameStore store;
  const SweetScreen({super.key, required this.store});
  @override
  State<SweetScreen> createState() => _SweetScreenState();
}

class _SweetScreenState extends State<SweetScreen>
    with SingleTickerProviderStateMixin {
  late SweetGame _game;
  late SweetFrame _frame;
  late AnimationController _cats;
  bool _busy = false;
  bool _resultShown = false;
  int? _selected;
  String _booster = '';
  Offset? _dragStart;
  String? _powerAction;
  int? _powerTarget;
  @override
  void initState() {
    super.initState();
    _cats = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _game = SweetGame(seed: DateTime.now().millisecondsSinceEpoch & 0xffffffff);
    try {
      final raw = widget.store.prefs.getString('sweet.v1');
      if (raw != null) {
        _game = SweetGame.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      }
    } catch (_) {
      /* Keep the new board if a saved board is damaged. */
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_game.won || _game.lost) _showResult();
    });
    _frame = SweetFrame(
      _game,
      _game.won
          ? SweetPhase.victory
          : _game.lost
          ? SweetPhase.defeat
          : SweetPhase.input,
      'Desliza una ficha hacia su vecina para combinar 3.',
    );
  }

  @override
  void dispose() {
    _cats.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    try {
      for (var i = 1; i <= _game.explosions; i++) {
        await widget.store.rewardGameCoins('sweet:${_game.id}:blast:$i', 5);
      }
      if (_game.won) {
        await widget.store.rewardGameCoins('sweet:${_game.id}:win', 100);
      }
      for (final level in [5, 10]) {
        if (_game.level >= level) {
          await widget.store.unlockAchievement('sweet:$level');
        }
      }
      if (_game.score > (widget.store.prefs.getInt('sweet.best') ?? 0)) {
        await widget.store.prefs.setInt('sweet.best', _game.score);
      }
      final ok = await widget.store.prefs.setString(
        'sweet.v1',
        jsonEncode(_game.toJson()),
      );
      if (!ok) throw StateError('save');
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo guardar la partida.')),
        );
      }
    }
  }

  Future<void> _play(int a, int b) async {
    if (_busy || _game.won || _game.lost) return;
    if (!_game.cells[a].movable || !_game.cells[b].movable) {
      setState(
        () => _frame = SweetFrame(
          _game,
          SweetPhase.input,
          'Esa ficha está bloqueada. Prueba otra dirección.',
        ),
      );
      return;
    }
    GameAudio.instance.play(GameSfx.place);
    if (_booster == 'switch') {
      _powerAction = 'switch';
      _powerTarget = b;
      _cats.duration = const Duration(milliseconds: 720);
      _cats.forward(from: 0);
    }
    final moved = _game.move(a, b, free: _booster == 'switch');
    if (moved) _booster = '';
    _selected = null;
    await _replay(
      caption: moved ? null : 'Sin combinación: conservas el movimiento.',
    );
  }

  Future<void> _replay({String? caption}) async {
    setState(() => _busy = true);
    await _save();
    for (final frame in _game.frames) {
      if (!mounted) return;
      setState(() => _frame = frame);
      if (frame.phase == SweetPhase.clear ||
          frame.phase == SweetPhase.enchant) {
        GameAudio.instance.play(
          frame.phase == SweetPhase.enchant ? GameSfx.reveal : GameSfx.clear,
        );
        HapticFeedback.lightImpact();
        _cats.duration = Duration(
          milliseconds: frame.phase == SweetPhase.enchant ? 450 : 360,
        );
        _cats.forward(from: 0);
      }
      await Future<void>.delayed(
        Duration(
          milliseconds: switch (frame.phase) {
            SweetPhase.clear => 360,
            SweetPhase.enchant => 450,
            SweetPhase.swap || SweetPhase.input => 300,
            SweetPhase.gravity => 220,
            SweetPhase.spawn => 220,
            SweetPhase.victory => 500,
            _ => 60,
          },
        ),
      );
    }
    if (!mounted) return;
    if (_game.won) GameAudio.instance.play(GameSfx.kitten);
    setState(() {
      _busy = false;
      _frame = SweetFrame(
        _game,
        _game.won
            ? SweetPhase.victory
            : _game.lost
            ? SweetPhase.defeat
            : SweetPhase.input,
        _game.won
            ? '¡Nivel superado! +100 monedas 🐾'
            : _game.lost
            ? '¡Maru y Lady creen en ti! Inténtalo otra vez.'
            : caption ?? 'Desliza una ficha hacia su vecina para combinar 3.',
      );
    });
    if (_game.won || _game.lost) _showResult();
    if (mounted && _powerAction != null) {
      await Future<void>.delayed(const Duration(milliseconds: 180));
      if (mounted) {
        setState(() {
          _powerAction = null;
          _powerTarget = null;
        });
      }
    }
  }

  Future<void> _showResult() async {
    if (_resultShown || !mounted) return;
    _resultShown = true;
    final next = await showGameResult(
      context,
      game: ResultTheme.sweet,
      victory: _game.won,
      title: _game.won ? '¡Dulce victoria!' : '¡Una combinación más!',
      detail: 'Candy Churu Cat · Nivel ${_game.level}',
      stat: '${_game.score} puntos',
      caption: _game.won
          ? '¡Gelatinas despejadas! +100 monedas. Recuperas un poder de cada tipo para el siguiente nivel.'
          : 'Quedan ${_game.jellyLeft} gelatinas. Tus poderes restantes se conservan al reintentar.',
      again: _game.won ? 'Siguiente nivel' : 'Reintentar',
    );
    if (!mounted) return;
    if (next == true) {
      await _restart(next: _game.won);
    } else {
      Navigator.pop(context);
    }
  }

  void _tap(int i) {
    if (_busy || _game.won || _game.lost) return;
    if (_booster == 'hammer') {
      if (_game.hammer(i)) {
        _booster = '';
        _selected = null;
        _powerAction = 'hammer';
        _powerTarget = i;
        _cats.duration = const Duration(milliseconds: 760);
        _cats.forward(from: 0);
        _replay();
      }
      return;
    }
    if (!_game.cells[i].movable) return;
    if (_selected != null && _game.adjacent(_selected!, i)) {
      _play(_selected!, i);
    } else {
      setState(() => _selected = _selected == i ? null : i);
    }
  }

  void _swipe(int i, Offset end) {
    if (_dragStart == null ||
        _busy ||
        _game.won ||
        _game.lost ||
        _booster == 'hammer') {
      return;
    }
    final delta = end - _dragStart!;
    if (delta.distance < 12) return;
    // Wait for a clear axis instead of guessing on a diagonal gesture.
    if (math.max(delta.dx.abs(), delta.dy.abs()) <
        math.min(delta.dx.abs(), delta.dy.abs()) * 1.25) {
      return;
    }
    _dragStart = null; // At most one adjacent swap per continuous drag.
    final x = i % 9, y = i ~/ 9;
    final dx = delta.dx.abs() > delta.dy.abs() ? delta.dx.sign.toInt() : 0;
    final dy = dx == 0 ? delta.dy.sign.toInt() : 0;
    if (x + dx < 0 || x + dx > 8 || y + dy < 0 || y + dy > 8) return;
    _play(i, (y + dy) * 9 + x + dx);
  }

  Future<void> _restart({bool next = false}) async {
    if (_busy) return;
    if (!next && !_game.lost && !_game.won) {
      final yes = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('¿Reiniciar este nivel?'),
          content: const Text(
            'Comenzarás con un tablero nuevo y los potenciadores del nivel.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Seguir jugando'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Reiniciar'),
            ),
          ],
        ),
      );
      if (yes != true || !mounted) return;
    }
    setState(() {
      _game = SweetGame(
        level: _game.level + (next ? 1 : 0),
        seed: DateTime.now().millisecondsSinceEpoch & 0xffffffff,
        hammers: _game.hammers + (next ? 1 : 0),
        switches: _game.switches + (next ? 1 : 0),
        extraMoves: _game.extraMoves + (next ? 1 : 0),
      );
      _resultShown = false;
      _selected = null;
      _booster = '';
      _powerAction = null;
      _powerTarget = null;
      _frame = SweetFrame(
        _game,
        SweetPhase.input,
        '¡Nuevos premios para nuestros bigotes!',
      );
    });
    await _save();
  }

  void _help() => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Candy Churu Cat'),
      content: const SingleChildScrollView(
        child: Text(
          'Desliza un premio a una casilla vecina o toca dos casillas. Combina 3 del mismo tipo para limpiar gelatina. Un intercambio sin combinación vuelve atrás sin gastar turno.\n\n'
          '4 en línea: premio rayado que limpia una fila o columna.\n5 en L/T: regalo envuelto, dos explosiones.\n5 en línea: ovillo mágico que elimina un color.\n\n'
          'Combina dos especiales: rayados forman una cruz; rayado y envuelto limpian 3 filas y columnas; dos envueltos explotan dos veces en 5×5. Ovillo y rayado convierten un color en rayados; ovillo y envuelto activan regalos y otro color; dos ovillos limpian todo.\n\n'
          'Nivel 2: glaseado y lazos. Nivel 3: doble gelatina y chocolate que crece si no lo eliminas. Nivel 4: huecos. Combina junto al glaseado o chocolate; combina un premio atrapado para liberar su lazo.\n\n'
          'Cada explosión de dulces da 5 monedas y completar un nivel da 100. Llegar a los niveles 5 y 10 desbloquea logros de premio único.\n\nCada nivel trae 3 martillos, 2 cambios libres y un +5. El martillo y el cambio libre no gastan turno. Limpia toda la gelatina para ganar y convertir los movimientos sobrantes en una fiesta de rayados.',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('¡A jugar!'),
        ),
      ],
    ),
  );

  Offset _tileOrigin(int i) {
    if ((_frame.phase == SweetPhase.swap || _frame.phase == SweetPhase.input) &&
        _frame.affected.length == 2 &&
        _frame.affected.contains(i)) {
      final other = _frame.affected.firstWhere((n) => n != i);
      return Offset(
        (other % 9 - i % 9).toDouble(),
        (other ~/ 9 - i ~/ 9).toDouble(),
      );
    }
    return Offset(
      0,
      _frame.phase == SweetPhase.spawn
          ? -.5
          : _frame.phase == SweetPhase.gravity
          ? -.2
          : 0,
    );
  }

  @override
  Widget build(BuildContext context) {
    final jelly = _frame.cells.fold(0, (n, c) => n + c.jelly);
    final ended = !_busy && (_game.won || _game.lost);
    return Scaffold(
      backgroundColor: const Color(0xfffff5ed),
      appBar: AppBar(
        backgroundColor: const Color(0xfffff5ed),
        title: const Text('Candy Churu Cat'),
        actions: [
          const AudioSettingsButton(),
          IconButton(onPressed: _help, icon: const Icon(Icons.help_outline)),
          IconButton(
            onPressed: _busy ? null : () => _restart(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: CustomPaint(
        painter: _SweetBackground(),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: LayoutBuilder(
                builder: (context, c) {
                  final boardSize = math.min(
                    c.maxWidth - 24,
                    math.max(220.0, c.maxHeight - 290),
                  );
                  return ListView(
                    padding: const EdgeInsets.all(12),
                    children: [
                      Row(
                        children: [
                          CatActor(
                            cat: CatKind.maru,
                            size: 64,
                            action: CatAction.blocks,
                            active: _busy || _game.won,
                            showLabel: false,
                          ),
                          Expanded(
                            child: Column(
                              children: [
                                Text(
                                  'NIVEL ${_game.level}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    letterSpacing: 2,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xff936278),
                                  ),
                                ),
                                const Text(
                                  'Una fiesta de patitas',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 18,
                                  ),
                                ),
                                Text(
                                  '${_frame.score} puntos',
                                  style: const TextStyle(
                                    color: Color(0xff805c74),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          CatActor(
                            cat: CatKind.lady,
                            size: 64,
                            action: CatAction.blocks,
                            active: _busy || _game.won,
                            showLabel: false,
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Expanded(child: _stat('🍮', '$jelly', 'gelatinas')),
                          const SizedBox(width: 8),
                          Expanded(child: _movementStat()),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Center(
                        child: SizedBox(
                          width: boardSize,
                          height: boardSize,
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(5),
                                decoration: BoxDecoration(
                                  color: const Color(0xff573f66),
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0x30573f66),
                                      blurRadius: 14,
                                      offset: Offset(0, 6),
                                    ),
                                  ],
                                ),
                                child: MediaQuery(
                                  data: MediaQuery.of(context).copyWith(
                                    // Small tiles need a shorter drag threshold than page scrolling.
                                    gestureSettings:
                                        const DeviceGestureSettings(
                                          touchSlop: 6,
                                        ),
                                  ),
                                  child: GridView.builder(
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    itemCount: 81,
                                    gridDelegate:
                                        const SliverGridDelegateWithFixedCrossAxisCount(
                                          crossAxisCount: 9,
                                          crossAxisSpacing: 2,
                                          mainAxisSpacing: 2,
                                        ),
                                    itemBuilder: (context, i) {
                                      final cell = _frame.cells[i];
                                      final clearing =
                                          _frame.phase == SweetPhase.clear &&
                                          _frame.affected.contains(i);
                                      return Semantics(
                                        label:
                                            'Fila ${i ~/ 9 + 1}, columna ${i % 9 + 1}, ${cell.hole
                                                ? 'hueco'
                                                : cell.chocolate
                                                ? 'chocolate'
                                                : cell.frosting > 0
                                                ? 'glaseado'
                                                : _sweetNames[cell.color.clamp(0, 6)]}',
                                        button: !cell.hole,
                                        child: GestureDetector(
                                          key: ValueKey('sweet-tile-$i'),
                                          behavior: HitTestBehavior.opaque,
                                          dragStartBehavior:
                                              DragStartBehavior.down,
                                          onTap: () => _tap(i),
                                          onPanStart: (d) => _dragStart =
                                              !_busy &&
                                                  !_game.won &&
                                                  !_game.lost &&
                                                  _booster != 'hammer'
                                              ? d.globalPosition
                                              : null,
                                          onPanEnd: (_) => _dragStart = null,
                                          onPanCancel: () => _dragStart = null,
                                          onPanUpdate: (d) =>
                                              _swipe(i, d.globalPosition),
                                          child: AnimatedScale(
                                            scale: clearing ? .72 : 1,
                                            duration: const Duration(
                                              milliseconds: 250,
                                            ),
                                            child: AnimatedContainer(
                                              duration: const Duration(
                                                milliseconds: 200,
                                              ),
                                              decoration: BoxDecoration(
                                                color: cell.hole
                                                    ? Colors.transparent
                                                    : clearing
                                                    ? const Color(0xffffefaa)
                                                    : cell.jelly > 0
                                                    ? const Color(0xffae78c9)
                                                    : const Color(0xff74577e),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                border: Border.all(
                                                  color: _selected == i
                                                      ? Colors.white
                                                      : cell.jelly == 2
                                                      ? const Color(0xffffb1f4)
                                                      : Colors.transparent,
                                                  width: 2,
                                                ),
                                              ),
                                              child: TweenAnimationBuilder<Offset>(
                                                key: ValueKey(
                                                  '${_frame.phase}-$i-${cell.color}',
                                                ),
                                                tween: Tween<Offset>(
                                                  begin: _tileOrigin(i),
                                                  end: Offset.zero,
                                                ),
                                                duration: const Duration(
                                                  milliseconds: 300,
                                                ),
                                                curve: Curves.easeOutCubic,
                                                builder: (context, t, child) {
                                                  // Move by the real grid step so the
                                                  // candy tracks the neighbouring cell
                                                  // even when the board has spacing.
                                                  final step =
                                                      (boardSize - 8) / 9;
                                                  return Transform.translate(
                                                    offset: Offset(
                                                      t.dx * step,
                                                      t.dy * step,
                                                    ),
                                                    child: child,
                                                  );
                                                },
                                                child: CustomPaint(
                                                  painter: _SweetPainter(cell),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                              if (_powerAction != null && _powerTarget != null)
                                Positioned.fill(
                                  child: IgnorePointer(
                                    child: AnimatedBuilder(
                                      animation: _cats,
                                      builder: (context, _) {
                                        final t = Curves.easeOutCubic.transform(
                                          _cats.value,
                                        );
                                        final target = _powerTarget!;
                                        final cell = boardSize / 9;
                                        final center = Offset(
                                          (target % 9 + .5) * cell,
                                          (target ~/ 9 + .5) * cell,
                                        );
                                        final hammer = _powerAction == 'hammer';
                                        final start = hammer
                                            ? Offset(
                                                center.dx - cell * 1.7,
                                                center.dy - cell * 1.5,
                                              )
                                            : Offset(
                                                center.dx - cell * 2.2,
                                                center.dy,
                                              );
                                        final end = hammer
                                            ? Offset(
                                                center.dx - cell * .25,
                                                center.dy - cell * .85,
                                              )
                                            : Offset(
                                                center.dx + cell * .8,
                                                center.dy,
                                              );
                                        final pos = Offset.lerp(start, end, t)!;
                                        return Stack(
                                          children: [
                                            Positioned(
                                              left: pos.dx - 29,
                                              top: pos.dy - 29,
                                              child: Transform.rotate(
                                                angle: hammer
                                                    ? -.55 +
                                                          math.sin(
                                                                t * math.pi * 4,
                                                              ) *
                                                              .65
                                                    : math.sin(
                                                            t * math.pi * 2,
                                                          ) *
                                                          .12,
                                                child: CatActor(
                                                  cat: hammer
                                                      ? CatKind.maru
                                                      : CatKind.lady,
                                                  size: 58,
                                                  action: CatAction.blocks,
                                                  active: true,
                                                  showLabel: false,
                                                ),
                                              ),
                                            ),
                                            if (hammer && t > .58)
                                              Positioned(
                                                left: center.dx - 18,
                                                top: center.dy - 18,
                                                child: Transform.scale(
                                                  scale: (t - .58) / .42,
                                                  child: const Text(
                                                    '✦',
                                                    style: TextStyle(
                                                      fontSize: 38,
                                                      color: Color(0xffffe36f),
                                                      shadows: [
                                                        Shadow(
                                                          color: Colors.white,
                                                          blurRadius: 12,
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ),
                                          ],
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              if (_frame.phase == SweetPhase.clear ||
                                  _frame.phase == SweetPhase.enchant)
                                Positioned.fill(
                                  child: IgnorePointer(
                                    child: AnimatedBuilder(
                                      animation: _cats,
                                      builder: (context, _) {
                                        final t = _cats.value;
                                        return Stack(
                                          children: [
                                            Positioned.fill(
                                              child: CustomPaint(
                                                painter: _SweetBurstPainter(
                                                  _frame,
                                                  t,
                                                ),
                                              ),
                                            ),
                                            for (final target
                                                in _frame.celebrations.isEmpty
                                                    ? [40]
                                                    : _frame.celebrations)
                                              for (final cat in CatKind.values)
                                                Positioned(
                                                  left: _catPosition(
                                                    cat,
                                                    target,
                                                    boardSize,
                                                    t,
                                                  ).dx,
                                                  top: _catPosition(
                                                    cat,
                                                    target,
                                                    boardSize,
                                                    t,
                                                  ).dy,
                                                  child: Transform.rotate(
                                                    angle:
                                                        math.sin(
                                                          t * math.pi * 2,
                                                        ) *
                                                        (_frame.effect ==
                                                                SweetEffect
                                                                    .wrapped
                                                            ? 2
                                                            : .25) *
                                                        (cat == CatKind.maru
                                                            ? 1
                                                            : -1),
                                                    child: CatActor(
                                                      cat: cat,
                                                      size: 58,
                                                      action: CatAction.blocks,
                                                      active: true,
                                                      showLabel: false,
                                                    ),
                                                  ),
                                                ),
                                            if (_frame.chain > 1)
                                              Center(
                                                child: Text(
                                                  '×${_frame.chain} ✨',
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 36,
                                                    fontWeight: FontWeight.w900,
                                                    shadows: [
                                                      Shadow(
                                                        color: Colors.purple,
                                                        blurRadius: 12,
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                          ],
                                        );
                                      },
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(
                        height: 48,
                        child: Center(
                          child: Text(
                            _booster == 'hammer'
                                ? 'Toca una casilla con el martillo'
                                : _booster == 'switch'
                                ? 'Desliza una ficha para un cambio libre'
                                : _frame.caption,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xff69476d),
                            ),
                          ),
                        ),
                      ),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _tool(
                            '🔨',
                            '${_game.hammers}',
                            'hammer',
                            _game.hammers,
                          ),
                          _tool(
                            '🔄',
                            '${_game.switches}',
                            'switch',
                            _game.switches,
                          ),
                          OutlinedButton(
                            onPressed:
                                _busy || _game.won || _game.extraMoves == 0
                                ? null
                                : () {
                                    _game.addMoves();
                                    setState(
                                      () => _frame = SweetFrame(
                                        _game,
                                        SweetPhase.input,
                                        '¡Cinco patitas extra!',
                                      ),
                                    );
                                    _save();
                                  },
                            child: Text('+5 (${_game.extraMoves})'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (ended)
                        FilledButton.icon(
                          onPressed: () => _restart(next: _game.won),
                          icon: Icon(
                            _game.won ? Icons.arrow_forward : Icons.refresh,
                          ),
                          label: Text(
                            _game.won
                                ? 'Siguiente nivel'
                                : 'Intentarlo de nuevo',
                          ),
                        ),
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text(
                          '3 iguales · 4 rayado · L/T regalo · 5 ovillo mágico',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xff805c74),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Offset _catPosition(CatKind cat, int target, double board, double t) {
    final side = cat == CatKind.maru ? -1.0 : 1.0;
    final center = Offset(
      (target % 9 + .5) * board / 9,
      (target ~/ 9 + .5) * board / 9,
    );
    if (_frame.effect == SweetEffect.bomb ||
        _frame.effect == SweetEffect.fusion) {
      final orbit = t * math.pi * 2 + (side < 0 ? 0 : math.pi);
      final radius = board * .2 * math.sin(t * math.pi);
      return Offset(
        (center.dx + math.cos(orbit) * radius - 29).clamp(-10.0, board - 48),
        (center.dy + math.sin(orbit) * radius - 29).clamp(-10.0, board - 48),
      );
    }
    if (_frame.effect == SweetEffect.wrapped) {
      return Offset(
        (center.dx + side * board * .24 * (1 - t) - 29).clamp(
          -10.0,
          board - 48,
        ),
        (center.dy - 29 - math.sin(t * math.pi) * 75).clamp(-15.0, board - 48),
      );
    }
    final x = side < 0 ? t * (board + 58) - 58 : board - t * (board + 58);
    return Offset(
      x,
      (center.dy - 29 - math.sin(t * math.pi) * (_frame.chain > 1 ? 50 : 18))
          .clamp(-10.0, board - 48),
    );
  }

  Widget _stat(String icon, String value, String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Text(
      '$icon $value $label',
      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
    ),
  );

  Widget _movementStat() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
    ),
    child: FittedBox(
      fit: BoxFit.scaleDown,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 360),
        transitionBuilder: (child, animation) => ScaleTransition(
          scale: CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
          child: child,
        ),
        child: Text(
          '🐾 ${_frame.moves} movimientos',
          key: ValueKey(_frame.moves),
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
        ),
      ),
    ),
  );
  Widget _tool(
    String icon,
    String count,
    String type,
    int remaining,
  ) => Tooltip(
    message: type == 'hammer'
        ? 'Martillo: toca una casilla para romperla sin gastar un movimiento'
        : 'Cambio libre: desliza dos fichas vecinas aunque no formen combinación',
    child: OutlinedButton(
      style: OutlinedButton.styleFrom(
        backgroundColor: _booster == type ? const Color(0xffffdba8) : null,
      ),
      onPressed: _busy || _game.won || _game.lost || remaining <= 0
          ? null
          : () => setState(() {
              _booster = _booster == type ? '' : type;
              _selected = null;
            }),
      child: AnimatedScale(
        scale: _booster == type ? 1.08 : 1,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutBack,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Text('$icon $count'),
            ),
            if (_booster == type)
              Positioned(
                right: -12,
                top: -25,
                child: IgnorePointer(
                  child: CatActor(
                    cat: type == 'hammer' ? CatKind.maru : CatKind.lady,
                    size: 28,
                    action: CatAction.blocks,
                    active: true,
                    showLabel: false,
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

const _sweetNames = [
  'patita rosa',
  'pez naranja',
  'campana amarilla',
  'leche verde',
  'ovillo azul',
  'pluma violeta',
  'ovillo mágico',
];

/// Original vector tokens: recognizable by silhouette as well as color.
class _SweetPainter extends CustomPainter {
  final SweetCell cell;
  _SweetPainter(this.cell);
  @override
  void paint(Canvas canvas, Size size) {
    if (cell.hole) return;
    canvas.save();
    canvas.scale(size.width / 40, size.height / 40);
    if (cell.special != SweetSpecial.none) {
      canvas.drawCircle(
        const Offset(20, 20),
        18,
        Paint()
          ..color = const Color(0xffffe18c).withValues(alpha: .5)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
      canvas.drawCircle(
        const Offset(20, 20),
        18,
        Paint()
          ..color = cell.special == SweetSpecial.bomb
              ? const Color(0xfff4cfff)
              : const Color(0xffffe8a3)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8,
      );
    }
    final p = Paint()
      ..color = cell.chocolate
          ? const Color(0xff754333)
          : cell.frosting > 0
          ? const Color(0xffffead3)
          : cell.color < 0
          ? Colors.transparent
          : cell.color == 6
          ? const Color(0xff473454)
          : _sweetColors[cell.color];
    void oval(double x, double y, double w, double h) =>
        canvas.drawOval(Rect.fromLTWH(x, y, w, h), p);
    if (cell.chocolate || cell.frosting > 0) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(4, 4, 32, 32),
          const Radius.circular(6),
        ),
        p,
      );
      p
        ..color = cell.chocolate ? const Color(0xffa86a4c) : Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(8, 8, 24, 24),
          const Radius.circular(4),
        ),
        p,
      );
      if (cell.frosting > 1) {
        canvas.drawLine(const Offset(9, 20), const Offset(31, 20), p);
      }
    } else if (cell.color >= 0) {
      switch (cell.color) {
        case 0:
          oval(10, 19, 21, 16);
          oval(5, 11, 7, 10);
          oval(14, 5, 7, 11);
          oval(24, 7, 7, 10);
          oval(31, 15, 6, 9);
        case 1:
          oval(9, 11, 24, 19);
          canvas.drawPath(
            Path()
              ..moveTo(12, 20)
              ..lineTo(3, 10)
              ..lineTo(3, 30)
              ..close(),
            p,
          );
          p.color = Colors.white;
          oval(26, 15, 3, 3);
        case 2:
          canvas.drawPath(
            Path()
              ..moveTo(8, 29)
              ..quadraticBezierTo(11, 23, 11, 16)
              ..quadraticBezierTo(20, 2, 29, 16)
              ..quadraticBezierTo(29, 23, 33, 29)
              ..close(),
            p,
          );
          oval(17, 30, 8, 6);
        case 3:
          canvas.drawPath(
            Path()
              ..moveTo(12, 5)
              ..lineTo(27, 5)
              ..lineTo(31, 13)
              ..lineTo(31, 34)
              ..lineTo(9, 34)
              ..lineTo(9, 13)
              ..close(),
            p,
          );
          p.color = Colors.white.withValues(alpha: .75);
          oval(14, 19, 12, 10);
        case 4:
          oval(5, 6, 29, 29);
          p
            ..color = Colors.white.withValues(alpha: .65)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2;
          for (var y = 12.0; y < 32; y += 6) {
            canvas.drawArc(
              Rect.fromLTWH(8, y - 7, 22, 14),
              0,
              math.pi,
              false,
              p,
            );
          }
        case 5:
          canvas.drawPath(
            Path()
              ..moveTo(8, 33)
              ..quadraticBezierTo(5, 10, 29, 5)
              ..quadraticBezierTo(40, 22, 8, 33)
              ..close(),
            p,
          );
          p
            ..color = Colors.white.withValues(alpha: .6)
            ..strokeWidth = 2;
          canvas.drawLine(const Offset(7, 35), const Offset(28, 11), p);
        default:
          oval(4, 4, 32, 32);
          for (var n = 0; n < 8; n++) {
            p.color = _sweetColors[n % 6];
            oval(18 + math.cos(n) * 11, 18 + math.sin(n) * 11, 4, 4);
          }
      }
      p
        ..style = PaintingStyle.stroke
        ..color = Colors.white
        ..strokeWidth = 2;
      if (cell.special == SweetSpecial.row ||
          cell.special == SweetSpecial.column) {
        p
          ..color = const Color(0xfffff2a1)
          ..strokeWidth = 3;
        for (var n = 12.0; n <= 28; n += 8) {
          canvas.drawLine(
            cell.special == SweetSpecial.row ? Offset(7, n) : Offset(n, 7),
            cell.special == SweetSpecial.row ? Offset(33, n) : Offset(n, 33),
            p,
          );
        }
      } else if (cell.special == SweetSpecial.wrapped) {
        p
          ..color = const Color(0xffffe38e)
          ..strokeWidth = 3;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(4, 4, 32, 32),
            const Radius.circular(6),
          ),
          p,
        );
        canvas.drawLine(const Offset(20, 4), const Offset(20, 36), p);
        canvas.drawLine(const Offset(4, 20), const Offset(36, 20), p);
        canvas.drawOval(const Rect.fromLTWH(9, 3, 11, 7), p);
        canvas.drawOval(const Rect.fromLTWH(20, 3, 11, 7), p);
      }
      if (cell.locked) {
        p
          ..color = const Color(0xff39273c)
          ..strokeWidth = 4;
        canvas.drawLine(const Offset(5, 5), const Offset(35, 35), p);
        canvas.drawLine(const Offset(35, 5), const Offset(5, 35), p);
        canvas.drawCircle(const Offset(20, 20), 6, p);
      }
    }
    if (cell.jelly > 0 && !cell.hole) {
      final jellyPaint = Paint()
        ..color = const Color(0xffffc9f5).withValues(alpha: .42)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(2.5, 2.5, 35, 35),
          const Radius.circular(8),
        ),
        jellyPaint,
      );
      jellyPaint
        ..color = Colors.white.withValues(alpha: .34)
        ..style = PaintingStyle.fill;
      canvas.drawOval(const Rect.fromLTWH(8, 7, 8, 3), jellyPaint);
      if (cell.jelly > 1) {
        jellyPaint.color = const Color(0xffffefff).withValues(alpha: .55);
        canvas.drawOval(const Rect.fromLTWH(25, 29, 7, 3), jellyPaint);
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _SweetPainter oldDelegate) => true;
}

void _paintPaw(Canvas canvas, Offset center, double scale, Color color) {
  final p = Paint()..color = color;
  canvas.save();
  canvas.translate(center.dx, center.dy);
  canvas.scale(scale);
  canvas.drawOval(const Rect.fromLTWH(-5, -1, 10, 8), p);
  for (final offset in [
    const Offset(-6, -4),
    const Offset(-2, -7),
    const Offset(3, -7),
    const Offset(7, -3),
  ]) {
    canvas.drawOval(Rect.fromCenter(center: offset, width: 4, height: 5), p);
  }
  canvas.restore();
}

class _SweetBackground extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xfffff3e7), Color(0xffffedf5), Color(0xffe7f6f1)],
        ).createShader(Offset.zero & size),
    );
    for (var y = 55.0; y < size.height; y += 130) {
      for (final x in [18.0, size.width - 18]) {
        _paintPaw(
          canvas,
          Offset(x, y),
          1.5,
          const Color(0xffc795b4).withValues(alpha: .1),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SweetBackground oldDelegate) => false;
}

class _SweetBurstPainter extends CustomPainter {
  final SweetFrame frame;
  final double t;
  _SweetBurstPainter(this.frame, this.t);
  @override
  void paint(Canvas canvas, Size size) {
    final unit = (size.width - 10) / 9;
    Offset center(int i) =>
        Offset(5 + (i % 9 + .5) * unit, 5 + (i ~/ 9 + .5) * unit);
    final special = frame.effect != SweetEffect.match;
    final alpha = math.sin(t * math.pi).clamp(0.0, 1.0);
    final beam = Paint()
      ..color = const Color(0xffffefad).withValues(alpha: alpha * .8)
      ..strokeWidth = unit * .25
      ..strokeCap = StrokeCap.round;
    for (final i in frame.affected) {
      final c = frame.cells[i];
      final at = center(i);
      if (c.special == SweetSpecial.row || c.special == SweetSpecial.column) {
        if (c.special == SweetSpecial.row) {
          canvas.drawLine(Offset(0, at.dy), Offset(size.width, at.dy), beam);
        } else {
          canvas.drawLine(Offset(at.dx, 0), Offset(at.dx, size.height), beam);
        }
      }
      if (frame.phase == SweetPhase.clear ||
          frame.phase == SweetPhase.enchant) {
        for (var n = 0; n < (special ? 6 : 3); n++) {
          final angle = n * math.pi / 3 + i;
          final radius = unit * (.3 + t * (special ? 1.8 : 1));
          final point = at + Offset(math.cos(angle), math.sin(angle)) * radius;
          canvas.drawCircle(
            point,
            (special ? 3.0 : 2.0) * (1 - t),
            Paint()..color = _sweetColors[(i + n) % 6].withValues(alpha: 1 - t),
          );
        }
      }
    }
    for (final i in frame.celebrations) {
      final at = center(i);
      if (special) {
        canvas.drawCircle(
          at,
          unit * (.5 + t * 2),
          Paint()
            ..color = const Color(0xffffe895).withValues(alpha: 1 - t)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 4 * (1 - t),
        );
        if (frame.effect == SweetEffect.bomb ||
            frame.effect == SweetEffect.fusion) {
          for (var n = 0; n < 6; n++) {
            final angle = n * math.pi / 3 + t * math.pi * 2;
            canvas.drawLine(
              at,
              at +
                  Offset(math.cos(angle), math.sin(angle)) * unit * (1 + t * 2),
              Paint()
                ..color = _sweetColors[n].withValues(alpha: alpha)
                ..strokeWidth = 3,
            );
          }
        }
      }
      _paintPaw(
        canvas,
        at + Offset(0, -t * unit * 2),
        1 + t,
        const Color(0xfffff4d3).withValues(alpha: 1 - t),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SweetBurstPainter oldDelegate) => true;
}
