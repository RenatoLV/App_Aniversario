import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import '../game_audio.dart';
import 'mz_catalog.dart';
import 'mz_levels.dart';
import 'mz_painter.dart';
import 'mz_progress.dart';
import 'mz_simulation.dart';
import 'mz_widgets.dart';
import 'mz_scenery.dart';
import 'mz_visual_feedback.dart';
import 'mz_combat_audio.dart';
import 'mz_result.dart';
import 'mz_card_reveal.dart';
import 'mz_almanac.dart';

class MzGameScreen extends StatefulWidget {
  const MzGameScreen({super.key, required this.sim, required this.progress});
  final MzSimulation sim;
  final MzProgress progress;
  @override
  State<MzGameScreen> createState() => _MzGameScreenState();
}

class _MzGameScreenState extends State<MzGameScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late MzSimulation sim;
  late final Ticker ticker;
  final focus = FocusNode();
  final stageKey = GlobalKey(),
      boardKey = GlobalKey(),
      counterKey = GlobalKey();
  final flights = <_MzFlight>[];
  final scenery = MzSceneryCache();
  final visuals = MzVisualFeedback();
  final combatAudio = MzCombatAudio();
  MzCat? dragging;
  double speed = 1;
  Duration? last;
  MzCat? selected;
  MzPower? power;
  String tool = '';
  bool expandedPowers = false;
  (int, int) cursor = (2, 0);
  (int, int)? preview;
  int? cartRow;
  bool saving = false, completed = false, leaving = false;
  String? saveError;
  MzResultReceipt? receipt;
  bool revealsHandled = false;
  double nextSave = 10;
  bool get wide =>
      MediaQuery.sizeOf(context).width > MediaQuery.sizeOf(context).height;

  String get guidance {
    if (sim.noticeUntil > sim.time &&
        sim.notice != 'Selecciona un gato y toca una casilla.') {
      return sim.notice.replaceAll('Dr. Cat-trófico', MzEnemy.boss.label);
    }
    if (dragging != null) return 'Suelta el gato en la casilla iluminada.';
    if (tool == 'shovel') return 'Pala: toca el gato que quieres retirar.';
    if (tool == 'tuna') return 'Atún: toca un gato para potenciarlo.';
    if (tool == 'human') return '${power!.label}: toca el área de la horda.';
    if (selected != null) {
      return '${mzCats[selected]!.name}: toca una casilla libre.';
    }
    return 'Arrastra un gato al césped o toca carta y casilla.';
  }

  @override
  void initState() {
    super.initState();
    sim = widget.sim;
    _selectMusic();
    visuals.observe(sim);
    ticker = createTicker(_frame)..start();
    WidgetsBinding.instance.addObserver(this);
  }

  void _selectMusic() {
    GameAudio.instance.enter(
      sim.level.world == MzWorld.patio
          ? 'marus-zombies-patio'
          : 'marus-zombies',
    );
  }

  void _frame(Duration elapsed) {
    final previous = last;
    last = elapsed;
    if (previous == null || saving || sim.paused || sim.ended) return;
    final dt = (elapsed - previous).inMicroseconds / 1000000;
    if (dt > .25) {
      _pause();
      return;
    }
    final lives = sim.roombas.where((v) => v).length;
    final previousKills = sim.kills;
    final beforeEffects = sim.effects.toSet();
    combatAudio.capture(sim);
    sim.advance(math.min(dt, 5 * MzSimulation.step) * speed);
    final audioEvents = combatAudio.events(sim);
    GameAudio.instance.updateCombatLaser(combatAudio.laserActive);
    GameAudio.instance.playCombat(audioEvents);
    visuals.observe(sim);
    if (sim.effects.any(
      (f) => f.type == 'boom' && !beforeEffects.contains(f),
    )) {
      HapticFeedback.lightImpact();
    }
    for (final flight in flights) {
      flight.age += dt;
    }
    flights.removeWhere((f) => f.age >= .6);
    if (sim.roombas.where((v) => v).length < lives) {
      GameAudio.instance.play(GameSfx.rocket);
    } else if (sim.kills > previousKills && sim.level.world != MzWorld.patio) {
      GameAudio.instance.play(GameSfx.clear);
    }
    if (sim.ended) {
      unawaited(_finish());
    } else if (sim.time >= nextSave) {
      nextSave = sim.time + 10;
      unawaited(_save());
    }
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _pause();
    last = null;
  }

  @override
  void dispose() {
    GameAudio.instance.stopCombat();
    ticker.dispose();
    scenery.dispose();
    focus.dispose();
    WidgetsBinding.instance.removeObserver(this);
    GameAudio.instance.pauseGame(false);
    GameAudio.instance.enter('marus-zombies');
    super.dispose();
  }

  Future<bool> _save({int spent = 0}) async {
    if (saving) return false;
    setState(() => saving = true);
    try {
      await widget.progress.checkpoint(sim, spent: spent);
      saveError = null;
      return true;
    } catch (e) {
      sim.paused = true;
      saveError = '$e';
      return false;
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> _finish() async {
    if (completed || saving) return;
    setState(() => saving = true);
    try {
      receipt ??= MzResultReceipt(widget.progress, sim);
      await widget.progress.complete(sim);
      receipt!.resolve(widget.progress, sim);
      completed = true;
      saveError = null;
      if (!sim.won || receipt!.newCards.isEmpty) {
        GameAudio.instance.play(sim.won ? GameSfx.reveal : GameSfx.paper);
      }
    } catch (e) {
      saveError = '$e';
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  void _pause() {
    if (!mounted || leaving || sim.ended) return;
    setState(() => sim.paused = true);
    GameAudio.instance.pauseGame(true);
    if (!saving) unawaited(_save());
  }

  void _resume() {
    if (saving) return;
    setState(() => sim.paused = false);
    last = null;
    GameAudio.instance.pauseGame(false);
  }

  Future<void> _leave() async {
    if (saving || leaving) return;
    if (sim.ended) {
      if (!completed) {
        await _finish();
        if (!completed) return;
      }
    } else {
      sim.paused = true;
      if (!await _save()) return;
    }
    if (!mounted) return;
    setState(() => leaving = true);
    Navigator.pop(context);
  }

  Future<void> _restart({bool next = false}) async {
    if (saving || !completed) return;
    final level = next ? mzNextLevel(sim.level)! : sim.level;
    final deck = sim.deck.where(level.allowed.contains).toList();
    if (next) {
      final newest = level.allowed.last;
      if (!deck.contains(newest)) {
        if (deck.length == 6) deck.removeLast();
        deck.add(newest);
      }
    }
    setState(() {
      sim = MzSimulation(level, deck: deck)
        ..autoCollect = widget.progress.autoCollect;
      _selectMusic();
      completed = false;
      GameAudio.instance.stopCombat();
      combatAudio.reset();
      receipt = null;
      revealsHandled = false;
      selected = null;
      power = null;
      tool = '';
      preview = null;
      cartRow = null;
      nextSave = 10;
      visuals.reset();
      visuals.observe(sim);
    });
    last = null;
    await _save();
  }

  void _choose(MzCat cat) {
    if (saving || sim.paused || sim.ended) return;
    setState(() {
      selected = cat;
      tool = '';
      power = null;
      preview = null;
      cartRow = null;
    });
    focus.requestFocus();
  }

  void _chooseTool(String value, [MzPower? p]) {
    if (saving || sim.paused || sim.ended) return;
    setState(() {
      tool = tool == value && power == p ? '' : value;
      power = p;
      selected = null;
      preview = null;
      cartRow = null;
    });
    focus.requestFocus();
  }

  Future<void> _paid(bool Function() action, int price) async {
    if (saving ||
        widget.progress.cookies < price ||
        sim.level.mode == MzMode.challenge) {
      sim.say('No tienes suficientes galletitas.');
      setState(() {});
      return;
    }
    final before = sim.toJson();
    if (!action()) {
      setState(() {});
      return;
    }
    if (!await _save(spent: price)) {
      sim = MzSimulation.fromJson(before)..paused = true;
      visuals.reset();
      visuals.observe(sim);
    } else {
      GameAudio.instance.play(GameSfx.reveal);
      setState(() {
        tool = '';
        power = null;
      });
    }
  }

  void _cell(int row, int col, {bool confirm = false}) {
    if (saving || sim.paused || sim.ended) return;
    cursor = (row, col);
    if (tool == 'human' && power != null) {
      unawaited(_paid(() => sim.human(power!, row, col + .5), power!.cost));
      return;
    }
    if (tool == 'cart') {
      if (cartRow == null) {
        if (col == 1 && sim.carts.contains(row * 9 + 1)) {
          setState(() => cartRow = row);
          sim.say('Toca otra casilla de la vía.');
        }
      } else {
        sim.moveCart(cartRow!, row);
        setState(() => cartRow = null);
      }
      return;
    }
    final narrow = MediaQuery.sizeOf(context).width < 600;
    if (narrow && !confirm && tool != 'tuna') {
      setState(() => preview = (row, col));
      return;
    }
    var success = false;
    var specificTunaSound = false;
    if (tool == 'shovel') {
      success = sim.remove(row, col);
    } else if (tool == 'tuna') {
      combatAudio.capture(sim);
      success = sim.feed(row, col);
      final cues = combatAudio.events(sim);
      specificTunaSound = cues.isNotEmpty;
      GameAudio.instance.playCombat(cues);
      if (success && cues.isNotEmpty) visuals.observe(sim);
    } else if (selected != null) {
      success = sim.place(selected!, row, col);
    }
    if (success) {
      HapticFeedback.lightImpact();
      if (tool != 'tuna') {
        GameAudio.instance.play(GameSfx.place);
      } else if (!specificTunaSound) {
        GameAudio.instance.play(GameSfx.reveal);
      }
    }
    setState(() => preview = null);
  }

  void _tap(Offset position, Size size) {
    if (saving || sim.paused || sim.ended) return;
    final g = MzBoardGeometry(size);
    for (final p in sim.pickups.reversed.toList()) {
      final center = g.point(p.row, p.x).translate(0, -g.ch * .14);
      if ((center - position).distance < math.max(14, g.cw * .25)) {
        if (sim.collect(p.id)) {
          if (!p.tuna && sim.level.world == MzWorld.patio) {
            GameAudio.instance.playCombat([GameSfx.marusHarvest]);
          } else {
            GameAudio.instance.play(GameSfx.coin);
          }
          if (!p.tuna && !widget.progress.reducedMotion) _fly(center);
        }
        setState(() {});
        return;
      }
    }
    final cell = g.cell(position);
    if (cell != null) _cell(cell.$1, cell.$2);
    focus.requestFocus();
  }

  void _fly(Offset local) {
    final board = boardKey.currentContext?.findRenderObject() as RenderBox?;
    final stage = stageKey.currentContext?.findRenderObject() as RenderBox?;
    final counter = counterKey.currentContext?.findRenderObject() as RenderBox?;
    if (board == null || stage == null || counter == null) return;
    flights.add(
      _MzFlight(
        stage.globalToLocal(board.localToGlobal(local)),
        stage.globalToLocal(
          counter.localToGlobal(counter.size.center(Offset.zero)),
        ),
      ),
    );
  }

  void _dragMove(Offset global) {
    final box = boardKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final cell = MzBoardGeometry(box.size).cell(box.globalToLocal(global));
    if (cell != preview) setState(() => preview = cell);
  }

  void _drop(MzCat cat, Offset global) {
    final box = boardKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || saving || sim.paused || sim.ended) return;
    final cell = MzBoardGeometry(box.size).cell(box.globalToLocal(global));
    if (cell != null && sim.place(cat, cell.$1, cell.$2)) {
      HapticFeedback.lightImpact();
      GameAudio.instance.play(GameSfx.place);
    }
    setState(() {
      preview = null;
      dragging = null;
    });
  }

  KeyEventResult _key(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.escape) {
      if (sim.paused) {
        _resume();
      } else if (selected != null || tool.isNotEmpty || preview != null) {
        setState(() {
          selected = null;
          tool = '';
          preview = null;
          power = null;
        });
      } else {
        _pause();
      }
      return KeyEventResult.handled;
    }
    if (saving || sim.paused || sim.ended) return KeyEventResult.ignored;
    final number = [
      LogicalKeyboardKey.digit1,
      LogicalKeyboardKey.digit2,
      LogicalKeyboardKey.digit3,
      LogicalKeyboardKey.digit4,
      LogicalKeyboardKey.digit5,
      LogicalKeyboardKey.digit6,
    ].indexOf(key);
    if (number >= 0 && number < sim.deck.length) {
      _choose(sim.deck[number]);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter) {
      _cell(cursor.$1, cursor.$2, confirm: true);
      return KeyEventResult.handled;
    }
    if ([
      LogicalKeyboardKey.arrowLeft,
      LogicalKeyboardKey.arrowRight,
      LogicalKeyboardKey.arrowUp,
      LogicalKeyboardKey.arrowDown,
    ].contains(key)) {
      setState(
        () => cursor = (
          (cursor.$1 +
                  (key == LogicalKeyboardKey.arrowDown
                      ? 1
                      : key == LogicalKeyboardKey.arrowUp
                      ? -1
                      : 0))
              .clamp(0, 4),
          (cursor.$2 +
                  (key == LogicalKeyboardKey.arrowRight
                      ? 1
                      : key == LogicalKeyboardKey.arrowLeft
                      ? -1
                      : 0))
              .clamp(0, 8),
        ),
      );
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: leaving,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop) _pause();
    },
    child: Scaffold(
      backgroundColor: const Color(0xff273f32),
      body: SafeArea(
        minimum: const EdgeInsets.symmetric(horizontal: 44, vertical: 8),
        child: Focus(
          focusNode: focus,
          autofocus: true,
          onKeyEvent: _key,
          child: Stack(
            key: stageKey,
            children: [
              Row(
                children: [
                  if (wide) SizedBox(width: 76, child: _cards()),
                  Expanded(
                    child: Column(
                      children: [
                        if (wide)
                          SizedBox(
                            height: 54,
                            child: Row(
                              children: [
                                _compactResourceCounter(),
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                    ),
                                    child: Text(
                                      guidance,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontFamily: 'Nunito',
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xffe4efce),
                                      ),
                                    ),
                                  ),
                                ),
                                _systemButtons(),
                              ],
                            ),
                          )
                        else ...[
                          Row(
                            children: [
                              Expanded(child: _resourceCounter()),
                              _systemButtons(),
                            ],
                          ),
                          SizedBox(height: 96, child: _cards()),
                        ],
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  sim.level.mode == MzMode.survival
                                      ? 'Supervivencia · oleada ${sim.wave}'
                                      : sim.level.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 12,
                                    color: Color(0xfff9e4b3),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              SizedBox(
                                width: wide ? 110 : 42,
                                child: LinearProgressIndicator(
                                  value: sim.progress,
                                  minHeight: 6,
                                  borderRadius: BorderRadius.circular(4),
                                  color: const Color(0xff548d46),
                                  backgroundColor: const Color(0xffcbd6ab),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final size = Size(
                                constraints.maxWidth,
                                constraints.maxHeight,
                              );
                              return DragTarget<MzCat>(
                                onWillAcceptWithDetails: (_) =>
                                    !saving && !sim.paused && !sim.ended,
                                onMove: (details) => _dragMove(details.offset),
                                onLeave: (_) => setState(() => preview = null),
                                onAcceptWithDetails: (details) =>
                                    _drop(details.data, details.offset),
                                builder: (context, candidates, rejected) =>
                                    GestureDetector(
                                      key: const ValueKey('mz-board'),
                                      onTapUp: (details) =>
                                          _tap(details.localPosition, size),
                                      onSecondaryTap: () => setState(() {
                                        selected = null;
                                        tool = '';
                                        preview = null;
                                        power = null;
                                      }),
                                      child: RepaintBoundary(
                                        key: boardKey,
                                        child: Semantics(
                                          label:
                                              'Jardín de cinco filas y nueve columnas. Arrastra un gato hasta una casilla.',
                                          child: CustomPaint(
                                            size: size,
                                            painter: MzBoardPainter(
                                              sim,
                                              scenery: scenery,
                                              visuals: visuals,
                                              selected: dragging ?? selected,
                                              focusCell: preview ?? cursor,
                                              reducedMotion:
                                                  widget.progress.reducedMotion,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                              );
                            },
                          ),
                        ),
                        if (preview != null &&
                            dragging == null &&
                            !sim.paused &&
                            !sim.ended)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Wrap(
                              alignment: WrapAlignment.end,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 6,
                              children: [
                                Text(
                                  'Fila ${preview!.$1 + 1} · casilla ${preview!.$2 + 1}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                TextButton(
                                  onPressed: () =>
                                      setState(() => preview = null),
                                  child: const Text('Cancelar'),
                                ),
                                FilledButton(
                                  onPressed: () => _cell(
                                    preview!.$1,
                                    preview!.$2,
                                    confirm: true,
                                  ),
                                  child: Text(
                                    tool == 'shovel' ? 'Retirar' : 'Colocar',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (!wide)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Text(
                              guidance,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Color(0xffd6e8bd),
                              ),
                            ),
                          ),
                        SizedBox(
                          height: 72,
                          child: Row(
                            children: [
                              Expanded(
                                child: ListView(
                                  scrollDirection: Axis.horizontal,
                                  reverse: true,
                                  children: [
                                    _tool(
                                      'Atún ${sim.tuna}/3',
                                      Icons.set_meal_outlined,
                                      tool == 'tuna',
                                      () => _chooseTool('tuna'),
                                    ),
                                    _tool(
                                      'Pala',
                                      Icons.yard_outlined,
                                      tool == 'shovel',
                                      () => _chooseTool('shovel'),
                                    ),
                                    if (sim.level.world == MzWorld.west)
                                      _tool(
                                        'Carrito',
                                        Icons.shopping_cart_outlined,
                                        tool == 'cart',
                                        () => _chooseTool('cart'),
                                      ),
                                    if (sim.level.mode != MzMode.challenge)
                                      _tool(
                                        'Poderes',
                                        Icons.auto_awesome,
                                        expandedPowers,
                                        () => setState(
                                          () =>
                                              expandedPowers = !expandedPowers,
                                        ),
                                      ),
                                    if (expandedPowers &&
                                        sim.level.mode != MzMode.challenge) ...[
                                      for (final p in MzPower.values)
                                        _tool(
                                          '${p.label} ${p.cost}',
                                          p == MzPower.spray
                                              ? Icons.water_drop_outlined
                                              : p == MzPower.pointer
                                              ? Icons.ads_click
                                              : Icons.back_hand_outlined,
                                          power == p && tool == 'human',
                                          widget.progress.cookies >= p.cost &&
                                                  sim.time >= sim.humanUntil
                                              ? () => _chooseTool('human', p)
                                              : null,
                                        ),
                                      _tool(
                                        'Atún +1 · 75',
                                        Icons.add_circle_outline,
                                        false,
                                        !sim.boughtTuna &&
                                                sim.tuna < 3 &&
                                                widget.progress.cookies >= 75
                                            ? () => _paid(sim.buyTuna, 75)
                                            : null,
                                      ),
                                    ],
                                    if (widget.progress.lion &&
                                        sim.level.mode != MzMode.challenge)
                                      _tool(
                                        'Gran León',
                                        Icons.auto_awesome,
                                        false,
                                        !sim.lionUsed
                                            ? () {
                                                sim.summonLion();
                                                HapticFeedback.lightImpact();
                                                setState(() {});
                                              }
                                            : null,
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              for (final flight in flights)
                Positioned(
                  left: flight.position.dx - 12,
                  top: flight.position.dy - 12,
                  child: IgnorePointer(
                    child: Opacity(
                      opacity: (1 - flight.age / .6).clamp(0, 1),
                      child: const MzToolIcon(Icons.grass),
                    ),
                  ),
                ),
              if (sim.paused || sim.ended) Positioned.fill(child: _overlay()),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _compactResourceCounter() => Container(
    key: counterKey,
    width: 116,
    height: 44,
    margin: const EdgeInsets.only(left: 8, bottom: 5),
    padding: const EdgeInsets.symmetric(horizontal: 8),
    decoration: mzHudDecoration(badge: true),
    child: Row(
      children: [
        const MzToolIcon(Icons.grass),
        const SizedBox(width: 6),
        Expanded(
          child: MzOutlinedText(
            '${sim.catnip}',
            color: const Color(0xffffe38c),
            textKey: const ValueKey('mz-catnip'),
          ),
        ),
      ],
    ),
  );
  Widget _resourceCounter() => SizedBox(
    key: counterKey,
    width: 90,
    child: Center(child: MzResourceBadge(value: sim.catnip)),
  );
  Widget _systemButtons() => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      _systemAction(
        'Pausa y menú',
        const MzToolIcon(Icons.home_outlined),
        saving ? null : _pause,
      ),
      _systemAction(
        'Pausar',
        const MzToolIcon(Icons.pause_circle_outline),
        saving ? null : _pause,
      ),
      _systemAction(
        'Velocidad x${speed.toInt()}',
        Text(
          'x${speed.toInt()}',
          style: const TextStyle(fontFamily: 'Fredoka', fontSize: 18),
        ),
        saving || sim.paused || sim.ended
            ? null
            : () => setState(() => speed = speed == 1 ? 2 : 1),
        key: const ValueKey('mz-speed'),
      ),
    ],
  );
  Widget _systemAction(
    String label,
    Widget child,
    VoidCallback? onTap, {
    Key? key,
  }) => Padding(
    padding: const EdgeInsets.only(left: 3, bottom: 5),
    child: SizedBox(
      width: 48,
      height: 48,
      child: MzActionButton(
        key: key,
        label: label,
        onTap: onTap,
        dimension: 48,
        child: Center(child: child),
      ),
    ),
  );
  Widget _cards() => Container(
    decoration: BoxDecoration(
      gradient: mzHudDecoration().gradient,
      border: mzHudDecoration().border,
      boxShadow: mzHudDecoration().boxShadow,
      borderRadius: BorderRadius.circular(14),
    ),
    child: ListView(
      scrollDirection: wide ? Axis.vertical : Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      children: [for (final cat in sim.deck) _card(cat)],
    ),
  );
  Widget _card(MzCat cat) {
    final spec = mzCats[cat]!;
    final remaining = math.max(0.0, (sim.cooldowns[cat] ?? 0) - sim.time);
    final card = MzSeedCard(
      cat: cat,
      remaining: remaining,
      selected: selected == cat,
      affordable: sim.catnip >= spec.cost,
      reducedMotion: widget.progress.reducedMotion,
    );
    return Draggable<MzCat>(
      affinity: wide ? Axis.horizontal : Axis.vertical,
      data: cat,
      maxSimultaneousDrags:
          saving || sim.paused || sim.ended || dragging != null ? 0 : 1,
      dragAnchorStrategy: pointerDragAnchorStrategy,
      feedback: Transform.translate(
        offset: const Offset(-42, -85),
        child: Material(
          color: Colors.transparent,
          child: Opacity(opacity: .8, child: MzCatPortrait(cat, size: 90)),
        ),
      ),
      childWhenDragging: Opacity(opacity: .35, child: card),
      onDragStarted: () => setState(() {
        dragging = cat;
        selected = cat;
        tool = '';
        power = null;
      }),
      onDragEnd: (_) {
        if (mounted) {
          setState(() {
            dragging = null;
            preview = null;
          });
        }
      },
      child: Tooltip(
        message: '${spec.name}: ${spec.cost} de hierba. ${spec.description}',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            key: ValueKey('mz-card-${cat.name}'),
            onTap: () => _choose(cat),
            child: card,
          ),
        ),
      ),
    );
  }

  Widget _tool(String label, IconData icon, bool active, VoidCallback? onTap) =>
      Padding(
        padding: const EdgeInsets.only(left: 6, bottom: 5),
        child: MzActionButton(
          label: label,
          active: active,
          onTap: saving || sim.paused || sim.ended ? null : onTap,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [MzToolIcon(icon), Text(label)],
          ),
        ),
      );
  Widget _overlay() =>
      sim.ended &&
          sim.won &&
          completed &&
          !revealsHandled &&
          (receipt?.newCards.isNotEmpty ?? false)
      ? MzCardReveal(
          receipt: receipt!,
          progress: widget.progress,
          onContinue: () => setState(() => revealsHandled = true),
          onAlmanac: (cat) {
            setState(() => revealsHandled = true);
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) =>
                    MzAlmanacScreen(progress: widget.progress, initialCat: cat),
              ),
            );
          },
        )
      : sim.ended
      ? MzResultPanel(
          sim: sim,
          receipt: receipt,
          showNewCards: false,
          reducedMotion: widget.progress.reducedMotion,
          saving: saving,
          completed: completed,
          error: saveError,
          onRetry: _restart,
          onLeave: _leave,
          onSave: _finish,
          onNext:
              completed &&
                  sim.won &&
                  sim.level.mode == MzMode.campaign &&
                  mzNextLevel(sim.level) != null
              ? () => _restart(next: true)
              : null,
          onAlmanac: (cat) => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) =>
                  MzAlmanacScreen(progress: widget.progress, initialCat: cat),
            ),
          ),
        )
      : ColoredBox(
          color: const Color(0xb323362c),
          child: LayoutBuilder(
            builder: (context, bounds) => Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 430,
                  maxHeight: math.max(80, bounds.maxHeight - 16),
                ),
                child: Card(
                  color: const Color(0xfffff6df),
                  margin: const EdgeInsets.all(8),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          sim.won
                              ? Icons.emoji_events_outlined
                              : sim.lost
                              ? Icons.home_outlined
                              : Icons.pause_circle_outline,
                          size: 42,
                          color: const Color(0xff59834b),
                        ),
                        Text(
                          sim.won
                              ? '¡El jardín está a salvo!'
                              : sim.lost
                              ? 'La horda llegó a casa'
                              : 'Una pausa para tus michis',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontFamily: 'Fredoka',
                            fontSize: 24,
                          ),
                        ),
                        if (sim.won)
                          Text(
                            List.generate(
                              3,
                              (i) => i < sim.stars ? '★' : '☆',
                            ).join(),
                            style: const TextStyle(
                              color: Color(0xffb69235),
                              fontSize: 36,
                            ),
                          ),
                        const SizedBox(height: 8),
                        Text(
                          sim.ended
                              ? '${sim.kills} invasores derrotados · ${sim.losses} gatos perdidos'
                              : 'La partida se guarda para continuar después.',
                          textAlign: TextAlign.center,
                        ),
                        if (saveError != null)
                          Text(
                            saveError!,
                            style: const TextStyle(color: Colors.red),
                          ),
                        const SizedBox(height: 12),
                        if (saving)
                          const CircularProgressIndicator()
                        else ...[
                          if (!sim.ended)
                            FilledButton(
                              onPressed: saveError == null
                                  ? _resume
                                  : () async {
                                      if (await _save()) _resume();
                                    },
                              child: const Text('Continuar'),
                            ),
                          if (sim.ended && !completed)
                            FilledButton(
                              onPressed: _finish,
                              child: const Text('Reintentar guardado'),
                            ),
                          if (sim.ended && completed) ...[
                            if (sim.won &&
                                sim.level.mode == MzMode.campaign &&
                                sim.level.id < 49)
                              FilledButton(
                                onPressed: () => _restart(next: true),
                                child: const Text('Siguiente nivel'),
                              ),
                            OutlinedButton(
                              onPressed: _restart,
                              child: Text(
                                sim.won ? 'Jugar otra vez' : 'Reintentar nivel',
                              ),
                            ),
                          ],
                          TextButton(
                            onPressed: _leave,
                            child: Text(
                              sim.ended
                                  ? 'Volver al mapa'
                                  : 'Guardar y volver al mapa',
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
}

class _MzFlight {
  _MzFlight(this.start, this.end);
  final Offset start, end;
  double age = 0;
  Offset get position {
    final t = (age / .6).clamp(0.0, 1.0);
    return Offset.lerp(start, end, Curves.easeInOutCubic.transform(t))! +
        Offset(0, -40 * 4 * t * (1 - t));
  }
}
