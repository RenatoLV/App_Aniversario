import 'dart:math' as math;
import 'dart:async';
import 'package:flutter/material.dart';
import 'art/lucky_cabinet_art.dart';
import 'art/lucky_cabinet_geometry.dart';
import 'art/lucky_symbol_art.dart';
import 'lucky_palace_theme.dart';
import 'lucky_demo.dart';
import 'lucky_responsive_layout.dart';
import 'lucky_console_controls.dart';
import 'lucky_machine_audio.dart';
import 'scratch/scratch_screen.dart';
import 'scratch/scratch_local_repository.dart';
import 'scratch/scratch_engine.dart';
import 'engine/lucky_engine.dart';
import 'data/lucky_models.dart';
import 'data/lucky_database.dart';
import 'data/local_lucky_repository.dart';
import '../game_audio.dart';
import '../store.dart';
import 'lucky_prize_screen.dart';

enum LuckyPlayMode { local, online, motor, demo }

/// One cabinet driven by confirmed receipts; original visual labs stay available.
class LuckyPalaceScreen extends StatefulWidget {
  const LuckyPalaceScreen({
    super.key,
    this.initialMode = LuckyPlayMode.local,
    this.engine,
    this.random,
    this.onRound,
    this.localRepository,
    this.connectSandbox,
    this.store,
    this.enableDeveloperTools = false,
  });
  final LuckyPlayMode initialMode;
  final GameStore? store;
  final bool enableDeveloperTools;
  final LuckyEngine? engine;
  final LuckyRandom? random;
  final ValueChanged<LuckyRound>? onRound;
  final LuckyRoundRepository? localRepository;
  final Future<LuckyRoundRepository> Function()? connectSandbox;
  @override
  State<LuckyPalaceScreen> createState() => _LuckyPalaceScreenState();
}

class _LuckyPalaceScreenState extends State<LuckyPalaceScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController clock;
  late final LuckyEngine engine;
  late final LuckyRandom random;
  late LuckyPlayMode mode;
  LuckyBonusState bonus = const LuckyBonusState();
  LuckyRound? round, previousRound;
  LuckyDemo demo = LuckyDemo.none;
  LuckyDemo choice = LuckyDemo.none;
  List<LuckySymbol> previous = LuckyDemoFrame.initial;
  bool started = false;
  double drag = 0;
  double initialPull = 0;
  bool resumeAfterPause = false;
  LuckyRoundRepository? localRepository, remoteRepository, presentingRepository;
  LuckyDatabase? ownedDatabase;
  final requests = <LuckyRoundRepository>{};
  final acknowledgements = <LuckyRoundRepository>{};
  final wallets = <LuckyRoundRepository, LuckyWalletSnapshot>{};
  final problems = <LuckyRoundRepository, String>{};
  LuckyRoundReceipt? receipt, recovered;
  LuckyRoundReceipt? displayedReceipt, priorDisplayedReceipt;
  String? storageError;
  Timer? networkProbe;
  bool probing = false, backgrounded = false, userPaused = false;
  bool audioPausedByUs = false, soundDialogPaused = false;
  final machineSound = LuckyMachineAudio();
  (bool, bool, bool)? clockPhase;
  final ruleCache = <String, LuckyRules>{};
  bool get presentationActive => started && clock.value < 1;
  bool get visualSettled =>
      started && clock.value * LuckyDemoFrame.duration >= 3.35;
  LuckyRound? get lastResult =>
      started && !visualSettled ? previousRound : round;
  bool get financial =>
      mode == LuckyPlayMode.local || mode == LuckyPlayMode.online;
  LuckyRoundRepository? get repository => mode == LuckyPlayMode.local
      ? localRepository
      : mode == LuckyPlayMode.online
      ? remoteRepository
      : null;
  LuckyWalletSnapshot? get wallet => wallets[repository];
  LuckyRules get payRules => financial
      ? ruleCache.putIfAbsent(
          wallet?.configId ?? 'reference25',
          () => luckyRules(wallet?.configId ?? 'reference25'),
        )
      : engine.rules;
  bool get waiting =>
      repository == null ||
      requests.contains(repository) ||
      acknowledgements.contains(repository);
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    engine = widget.engine ?? LuckyEngine();
    random = widget.random ?? LuckySeededRandom(20261019);
    mode = widget.initialMode;
    if (mode == LuckyPlayMode.local &&
        (widget.engine != null || widget.random != null)) {
      mode = LuckyPlayMode.motor;
    }
    clock =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 6200),
        )..addListener(() {
          if (!backgrounded && !userPaused) {
            for (final cue in machineSound.advance(
              clock.value * LuckyDemoFrame.duration,
            )) {
              GameAudio.instance.play(cue);
            }
          }
          // HUD/controls change only on phase boundaries. The art owns frame ticks.
          final phase = (
            clock.isAnimating,
            clock.value >= 3.35 / LuckyDemoFrame.duration,
            clock.isCompleted,
          );
          if (clockPhase != phase) {
            clockPhase = phase;
            if (mounted) setState(() {});
          }
        });
    clock.addStatusListener((status) {
      if (status == AnimationStatus.completed) machineSound.cancel();
      if (status == AnimationStatus.completed &&
          receipt != null &&
          presentingRepository != null) {
        unawaited(
          _ack(presentingRepository!, receipt!.id, LuckyPresentation.seen),
        );
      }
    });
    if (mode == LuckyPlayMode.local) unawaited(_initializeLocal());
  }

  Future<void> _initializeLocal() async {
    storageError = null;
    try {
      if (widget.localRepository != null) {
        localRepository = widget.localRepository;
      } else {
        ownedDatabase = LuckyDatabase(await openLuckyDatabase());
        localRepository = LocalLuckyRoundRepository(
          ownedDatabase!,
          configId: 'rewards25v2',
        );
      }
      await _load(localRepository!);
    } catch (e) {
      if (mounted) {
        setState(
          () => storageError =
              'No se pudo abrir el historial. Se conserva sin borrar: $e',
        );
      }
    }
  }

  Future<void> _load(LuckyRoundRepository repo) async {
    if (requests.contains(repo) || acknowledgements.contains(repo)) return;
    requests.add(repo);
    if (mounted) setState(() {});
    try {
      final result = await repo.recover();
      wallets[repo] = await repo.refresh();
      problems.remove(repo);
      if (mounted && repository == repo && !presentationActive) {
        recovered = result?.presentation == LuckyPresentation.pending
            ? result
            : null;
        bonus = wallets[repo]!.bonus;
      }
    } catch (e) {
      problems[repo] = e is LuckyDeclined
          ? '$e'
          : repo.origin == LuckyOrigin.sandbox
          ? 'Comprobando resultado… Puedes jugar con fichas locales.'
          : 'No se confirmó el almacenamiento: $e';
    } finally {
      requests.remove(repo);
      if (mounted) setState(() {});
    }
  }

  Future<void> _online() async {
    if (widget.connectSandbox == null) {
      if (mounted) {
        setState(
          () => storageError =
              'Online disponible en la versión debug aislada. Local funciona sin conexión.',
        );
      }
      return;
    }
    try {
      remoteRepository = await widget.connectSandbox!();
      if (!mounted || presentationActive) return;
      setState(() {
        mode = LuckyPlayMode.online;
        recovered = null;
        receipt = null;
        round = null;
        displayedReceipt = priorDisplayedReceipt = null;
        started = false;
      });
      await _load(remoteRepository!);
      networkProbe ??= Timer.periodic(
        const Duration(seconds: 12),
        (_) => unawaited(_probe()),
      );
    } catch (e) {
      if (mounted) {
        setState(
          () => storageError = 'Sandbox no disponible; puedes seguir local. $e',
        );
      }
    }
  }

  Future<void> _probe() async {
    final repo = remoteRepository;
    if (repo == null || probing || backgrounded || requests.contains(repo)) {
      return;
    }
    probing = true;
    try {
      // Actual authenticated service availability, never Wi-Fi heuristics.
      wallets[repo] = await repo.refresh();
      if (repository == repo && !presentationActive && recovered == null) {
        await _load(repo);
      } else {
        problems.remove(repo);
      }
    } catch (_) {
      problems[repo] = 'Online sin confirmar · Local sigue disponible';
    } finally {
      probing = false;
      if (mounted) setState(() {});
    }
  }

  void _present(LuckyRoundReceipt result, LuckyRoundRepository repo) {
    if (!mounted || repository != repo) return;
    if (backgrounded) {
      setState(() {
        recovered = result;
        bonus = result.round.after;
      });
      return;
    }
    userPaused = false;
    setState(() {
      previous = started ? frame.result : previous;
      previousRound = round;
      priorDisplayedReceipt = displayedReceipt;
      displayedReceipt = result;
      round = result.round;
      receipt = result;
      presentingRepository = repo;
      bonus = result.round.after;
      recovered = null;
      started = true;
      initialPull = drag;
      drag = 0;
    });
    widget.onRound?.call(result.round);
    _beginMachineAudio();
    if (MediaQuery.disableAnimationsOf(context)) {
      clock.value = 0;
      clock.value = 1;
    } else {
      clock.forward(from: 0);
    }
  }

  Future<void> _ack(
    LuckyRoundRepository repo,
    String id,
    LuckyPresentation state,
  ) async {
    if (acknowledgements.contains(repo)) return;
    acknowledgements.add(repo);
    var confirmed = false;
    try {
      await repo.acknowledge(id, state);
      confirmed = true;
      problems.remove(repo);
      if (receipt?.id == id) {
        receipt = null;
        presentingRepository = null;
      }
    } catch (_) {
      problems[repo] =
          'Presentación pendiente de confirmar. Recuperar no vuelve a premiar.';
    } finally {
      acknowledgements.remove(repo);
      if (mounted) setState(() {});
    }
    if (confirmed &&
        mounted &&
        repository == repo &&
        repo.origin == LuckyOrigin.sandbox &&
        !backgrounded &&
        !presentationActive) {
      await _load(repo);
    }
  }

  Future<void> _playReceipt() async {
    final repo = repository;
    if (repo == null ||
        requests.contains(repo) ||
        acknowledgements.contains(repo) ||
        recovered != null) {
      return;
    }
    requests.add(repo);
    setState(() {});
    try {
      final intent = await repo.prepare(); // Durable outbox before any RPC.
      final result = await repo.execute(intent);
      wallets[repo] = await repo.refresh();
      problems.remove(repo);
      requests.remove(repo);
      if (mounted && repository == repo) _present(result, repo);
    } catch (e) {
      problems[repo] = e is LuckyDeclined
          ? '$e'
          : repo.origin == LuckyOrigin.sandbox
          ? 'Comprobando resultado… Puedes continuar en Local.'
          : 'No se confirmó la escritura. $e';
    } finally {
      requests.remove(repo);
      if (mounted) setState(() {});
    }
  }

  Future<void> _refill() async {
    final repo = repository;
    if (repo is! LocalLuckyRoundRepository || waiting) return;
    requests.add(repo);
    setState(() {});
    try {
      await repo.refill();
      requests.remove(repo);
      await _load(repo);
    } catch (error) {
      problems[repo] = 'No se confirmó la recarga. $error';
    } finally {
      requests.remove(repo);
      if (mounted) setState(() {});
    }
  }

  Future<void> _selectMode(LuckyPlayMode value) async {
    if (presentationActive && financial) return;
    if (clock.isAnimating) skip();
    if (value == LuckyPlayMode.online) {
      await _online();
      return;
    }
    setState(() {
      mode = value;
      recovered = null;
      receipt = null;
      presentingRepository = null;
      round = null;
      displayedReceipt = priorDisplayedReceipt = null;
      started = false;
      storageError = null;
    });
    if (value == LuckyPlayMode.local) {
      if (localRepository == null) {
        await _initializeLocal();
      } else {
        await _load(localRepository!);
      }
    }
  }

  LuckyDemoFrame get frame => LuckyDemoFrame(
    seconds: clock.value * LuckyDemoFrame.duration,
    demo: demo,
    round: round,
    previousRound: previousRound,
    referenceCost: financial
        ? (bonus.remaining > 0 ? 0 : payRules.wager)
        : null,
    previous: previous,
    drag: drag,
    initialPull: initialPull,
    started: started,
    reduced: MediaQuery.disableAnimationsOf(context),
  );
  void start([LuckyDemo? example]) {
    if (presentationActive || backgrounded || userPaused) return;
    if (financial) {
      unawaited(_playReceipt());
      return;
    }
    final last = started ? frame.result : previous;
    final oldRound = round;
    final next = mode == LuckyPlayMode.motor
        ? engine.spin(random, bonus: bonus)
        : null;
    setState(() {
      previous = last;
      previousRound = oldRound;
      round = next;
      if (next != null) bonus = next.after;
      demo = example ?? choice;
      started = true;
      initialPull = drag;
      drag = 0;
    });
    if (next != null) widget.onRound?.call(next);
    _beginMachineAudio();
    if (MediaQuery.disableAnimationsOf(context)) {
      clock.value = 1;
    } else {
      clock.forward(from: 0);
    }
  }

  void _togglePause() {
    if (!presentationActive || backgrounded) return;
    setState(() {
      userPaused = !userPaused;
      if (userPaused) {
        clock.stop();
      } else if (MediaQuery.disableAnimationsOf(context)) {
        clock.value = 1;
      } else {
        clock.forward();
      }
    });
    audioPausedByUs = userPaused;
    GameAudio.instance.pauseGame(userPaused);
    if (userPaused) {
      _silenceMachineAudio();
    } else {
      _resumeMachineAudio();
    }
  }

  void _beginMachineAudio() {
    _silenceMachineAudio();
    final actualReward = round != null
        ? round!.evaluation.total > round!.simulatedCost
        : frame.hasReward;
    for (final cue in machineSound.begin(
      hasReward: actualReward,
      reduced: MediaQuery.disableAnimationsOf(context),
    )) {
      GameAudio.instance.play(cue);
    }
  }

  void _silenceMachineAudio() {
    for (final cue in LuckyMachineAudio.effects) {
      GameAudio.instance.stopEffect(cue);
    }
  }

  void _resumeMachineAudio() {
    final cue = machineSound.resumeAt(clock.value * LuckyDemoFrame.duration);
    if (cue != null) GameAudio.instance.play(cue.$1, position: cue.$2);
  }

  void skip() {
    machineSound.cancel();
    _silenceMachineAudio();
    userPaused = false;
    resumeAfterPause = false;
    if (audioPausedByUs) {
      GameAudio.instance.pauseGame(false);
      audioPausedByUs = false;
    }
    final repo = presentingRepository, id = receipt?.id;
    if (repo != null && id != null) {
      receipt = null;
      presentingRepository = null;
      unawaited(_ack(repo, id, LuckyPresentation.skipped));
    }
    clock.stop();
    setState(() {
      clock.value = 1;
      drag = 0;
    });
  }

  void pull(double delta) {
    if (!presentationActive && (!financial || !waiting) && !backgrounded) {
      setState(() => drag = (drag + delta).clamp(0.0, 1.0));
    }
  }

  void release() {
    if (drag >= .5) {
      start();
    } else {
      setState(() => drag = 0);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    backgrounded = state != AppLifecycleState.resumed;
    if (state != AppLifecycleState.resumed) {
      _silenceMachineAudio();
      resumeAfterPause = resumeAfterPause || clock.isAnimating;
      clock.stop();
      if (drag != 0) setState(() => drag = 0);
    } else if (resumeAfterPause && !userPaused) {
      resumeAfterPause = false;
      clock.forward();
      _resumeMachineAudio();
    }
    if (!backgrounded) unawaited(_probe());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context) && clock.isAnimating) {
      machineSound.cancel();
      _silenceMachineAudio();
      clock.stop();
      clock.value = 1;
    }
  }

  @override
  void dispose() {
    machineSound.cancel();
    _silenceMachineAudio();
    WidgetsBinding.instance.removeObserver(this);
    clock.dispose();
    networkProbe?.cancel();
    if (audioPausedByUs) GameAudio.instance.pauseGame(false);
    // A late confirmed request stays in its repository; it never needs this widget.
    // Do not close a shared database while a financial transaction is in flight.
    super.dispose();
  }

  bool gallery = false;
  bool detailsOpen = false;
  void _toggleGallery() {
    if (clock.isAnimating) skip();
    setState(() => gallery = !gallery);
  }

  void _dismissDetails() {
    if (detailsOpen) Navigator.pop(context);
  }

  LuckySymbol selected = LuckySymbol.maru;
  String background = 'Oscuro';
  double cellSize = 48;

  @override
  Widget build(BuildContext context) => Theme(
    data: Theme.of(context).copyWith(
      brightness: Brightness.dark,
      textTheme: Theme.of(context).textTheme.apply(
        fontFamily: 'Nunito',
        bodyColor: LuckyPalette.cream,
        displayColor: LuckyPalette.cream,
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
      ),
      colorScheme: const ColorScheme.dark(
        primary: LuckyPalette.goldLight,
        surface: LuckyPalette.night,
      ),
    ),
    child: Scaffold(
      backgroundColor: LuckyPalette.night,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (financial) return _responsive(constraints);
            final horizontal =
                constraints.maxWidth > 700 &&
                constraints.maxHeight < constraints.maxWidth * .7;
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 4, 12, 2),
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: 'Volver',
                        onPressed: () => Navigator.maybePop(context),
                        color: LuckyPalette.goldLight,
                        icon: const Icon(Icons.arrow_back_rounded),
                        constraints: const BoxConstraints(
                          minHeight: 48,
                          minWidth: 48,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: FittedBox(
                          alignment: Alignment.centerLeft,
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'LUCKY PALACE',
                            style: LuckyPalette.text(18, title: true),
                            maxLines: 1,
                          ),
                        ),
                      ),
                      if (!financial)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xff30203c),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xff72516a)),
                          ),
                          child: Text(
                            (mode == LuckyPlayMode.motor || financial)
                                ? 'Gratis: ${(!frame.settled && round != null) ? round!.before.remaining : bonus.remaining}'
                                : 'Demo fija',
                            style: LuckyPalette.text(
                              12,
                              color: LuckyPalette.goldLight,
                            ),
                          ),
                        ),
                      if (financial)
                        IconButton(
                          key: const ValueKey('lucky-paytable'),
                          tooltip: 'Tabla de pagos',
                          onPressed: _paytable,
                          icon: const Icon(
                            Icons.info_outline_rounded,
                            color: LuckyPalette.goldLight,
                          ),
                        ),
                      if (financial && widget.enableDeveloperTools)
                        PopupMenuButton<LuckyPlayMode>(
                          key: const ValueKey('lucky-options'),
                          tooltip: 'Opciones',
                          enabled: !presentationActive,
                          icon: const Icon(
                            Icons.more_vert_rounded,
                            color: LuckyPalette.goldLight,
                          ),
                          onSelected: (value) => unawaited(_selectMode(value)),
                          itemBuilder: (_) => [
                            for (final item in LuckyPlayMode.values)
                              PopupMenuItem(
                                value: item,
                                key: ValueKey('lucky-mode-${item.name}'),
                                child: Text(switch (item) {
                                  LuckyPlayMode.local => 'Jugar con fichas',
                                  LuckyPlayMode.online => 'Prueba de servidor',
                                  LuckyPlayMode.motor =>
                                    'Laboratorio del motor',
                                  LuckyPlayMode.demo =>
                                    'Demostraciones visuales',
                                }),
                              ),
                          ],
                        ),
                    ],
                  ),
                ),
                if (financial)
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight:
                          constraints.maxHeight * (horizontal ? .32 : .35),
                    ),
                    child: SingleChildScrollView(
                      key: const ValueKey('lucky-hud-scroll'),
                      child: _walletBar(),
                    ),
                  ),
                Expanded(child: gallery ? _gallery() : _machine(!horizontal)),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 2, 12, 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (horizontal && !gallery) Expanded(child: _status()),
                      if (financial)
                        IconButton(
                          key: const ValueKey('lucky-history'),
                          tooltip: 'Historial',
                          constraints: const BoxConstraints(
                            minWidth: 48,
                            minHeight: 48,
                          ),
                          onPressed: repository == null
                              ? null
                              : () => unawaited(_history()),
                          icon: const Icon(
                            Icons.history,
                            color: LuckyPalette.goldLight,
                          ),
                        ),
                      IconButton(
                        key: const ValueKey('lucky-pause'),
                        tooltip: userPaused ? 'Reanudar' : 'Pausar',
                        constraints: const BoxConstraints(
                          minWidth: 48,
                          minHeight: 48,
                        ),
                        onPressed: presentationActive ? _togglePause : null,
                        icon: Icon(
                          userPaused
                              ? Icons.play_arrow_rounded
                              : Icons.pause_rounded,
                          color: LuckyPalette.goldLight,
                        ),
                      ),
                      AudioSettingsButton(
                        color: LuckyPalette.goldLight,
                        onOpen: () {
                          if (presentationActive && !userPaused) {
                            _togglePause();
                            soundDialogPaused = true;
                          }
                        },
                        onClose: () {
                          if (soundDialogPaused) {
                            soundDialogPaused = false;
                            if (mounted && userPaused) _togglePause();
                          }
                        },
                      ),
                      if (widget.enableDeveloperTools)
                        Flexible(
                          child: TextButton.icon(
                            style: TextButton.styleFrom(
                              minimumSize: const Size(48, 48),
                              foregroundColor: LuckyPalette.goldLight,
                            ),
                            icon: Icon(
                              gallery
                                  ? Icons.arrow_back_rounded
                                  : Icons.grid_view_rounded,
                            ),
                            onPressed: () {
                              if (clock.isAnimating) skip();
                              setState(() => gallery = !gallery);
                            },
                            label: Text(
                              gallery
                                  ? 'Volver al gabinete'
                                  : financial &&
                                        MediaQuery.textScalerOf(
                                              context,
                                            ).scale(15) >
                                            20
                                  ? 'Símbolos'
                                  : 'Explorar símbolos',
                              textAlign: TextAlign.center,
                              style: LuckyPalette.text(15),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    ),
  );

  Future<void> _openScratch() async {
    final resume = clock.isAnimating;
    clock.stop();
    _silenceMachineAudio();
    final local = localRepository;
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: '/lucky-palace/scratch'),
        builder: (_) => ScratchScreen(
          store: widget.store,
          repository: local is LocalLuckyRoundRepository
              ? ScratchLocalRepository(
                  local.storage,
                  rulesVersion: ScratchRules.enhancedVersion,
                )
              : null,
        ),
      ),
    );
    if (!mounted) return;
    if (local != null) {
      try {
        wallets[local] = await local.refresh();
        if (mode == LuckyPlayMode.local) bonus = wallets[local]!.bonus;
      } catch (e) {
        problems[local] = 'No se pudo actualizar el saldo: $e';
      }
    }
    if (!mounted) return;
    setState(() {});
    if (resume && !userPaused && !backgrounded) {
      clock.forward();
      _resumeMachineAudio();
    }
  }

  Future<void> _openPrizes() async {
    final local = localRepository;
    if (widget.store == null || local is! LocalLuckyRoundRepository) return;
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: '/lucky-palace/prizes'),
        builder: (_) =>
            LuckyPrizeScreen(storage: local.storage, store: widget.store!),
      ),
    );
    if (mounted) await _load(local);
  }

  Widget _status() => FittedBox(
    fit: BoxFit.scaleDown,
    child: Semantics(
      liveRegion: !clock.isAnimating,
      child: Text(
        financial
            ? ((problems[repository] != null || storageError != null)
                  ? 'Revisa el aviso de recuperación'
                  : (userPaused
                        ? 'Partida en pausa'
                        : waiting
                        ? 'Confirmando…'
                        : presentationActive && !visualSettled
                        ? 'Girando…'
                        : receipt != null
                        ? 'Premio ${receipt!.gross} · Neto ${receipt!.net >= 0 ? '+' : ''}${receipt!.net}'
                        : '¡Buena suerte!'))
            : mode == LuckyPlayMode.motor && !started
            ? 'MOTOR · Sin monedas reales'
            : frame.status,
        key: const ValueKey('lucky-status'),
        style: LuckyPalette.text(
          17,
          title: true,
          color: LuckyPalette.goldLight,
        ),
      ),
    ),
  );

  List<Widget> _recoveryActions() {
    return <Widget>[
      if (recovered != null) ...[
        TextButton(
          key: const ValueKey('lucky-present-pending'),
          onPressed: () {
            _dismissDetails();
            _present(recovered!, repository!);
          },
          child: const Text('Ver pendiente'),
        ),
        TextButton(
          key: const ValueKey('lucky-skip-pending'),
          onPressed: () {
            final r = recovered!;
            _dismissDetails();
            setState(() {
              displayedReceipt = r;
              round = r.round;
              previousRound = null;
              started = true;
              recovered = null;
              clock.value = 1;
            });
            unawaited(_ack(repository!, r.id, LuckyPresentation.skipped));
          },
          child: const Text('Omitir pendiente'),
        ),
      ],
      if (repository is LocalLuckyRoundRepository &&
          wallet != null &&
          wallet!.balance < luckyRules(wallet!.configId).wager &&
          bonus.remaining == 0)
        TextButton(
          key: const ValueKey('lucky-refill'),
          onPressed: waiting
              ? null
              : () {
                  _dismissDetails();
                  unawaited(_refill());
                },
          child: const Text('Recargar gratis +500'),
        ),
      if (problems.containsKey(repository))
        TextButton(
          key: const ValueKey('lucky-recover'),
          onPressed: () {
            _dismissDetails();
            unawaited(_load(repository!));
          },
          child: const Text('Recuperar'),
        ),
      if (mode == LuckyPlayMode.local &&
          ownedDatabase != null &&
          problems.containsKey(repository))
        TextButton(
          onPressed: waiting
              ? null
              : () {
                  _dismissDetails();
                  unawaited(_initializeLocal());
                },
          child: const Text('Reabrir historial'),
        ),
      if (storageError != null && localRepository == null)
        TextButton(
          onPressed: () {
            _dismissDetails();
            unawaited(_initializeLocal());
          },
          child: const Text('Reintentar almacenamiento'),
        ),
    ];
  }

  // Complete information lives in an accessible, independently scrollable panel.
  Widget _walletBar() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        'Fichas: ${wallet?.balance ?? '—'}',
        key: const ValueKey('lucky-wallet'),
        style: LuckyPalette.text(18, title: true),
      ),
      Text(
        'Giros gratis restantes: ${bonus.remaining}',
        style: LuckyPalette.text(16),
      ),
      Text(
        bonus.remaining > 0
            ? 'Siguiente giro: gratis. Coste 0.'
            : 'Siguiente giro: coste ${payRules.wager}.',
        key: const ValueKey('lucky-next-cost'),
        style: LuckyPalette.text(16),
      ),
      if (lastResult case final r?) ...[
        const Divider(),
        Text('Último giro', style: LuckyPalette.text(20, title: true)),
        Text(
          'Premio bruto: ${r.evaluation.total}',
          style: LuckyPalette.text(16),
        ),
        Text('Coste cobrado: ${r.simulatedCost}', style: LuckyPalette.text(16)),
        Text(
          'Neto: ${r.evaluation.total - r.simulatedCost}',
          style: LuckyPalette.text(16),
        ),
        Text(
          'Giros gratis concedidos: ${r.grantedSpins}',
          style: LuckyPalette.text(16),
        ),
        if ((presentationActive && !visualSettled
                ? priorDisplayedReceipt
                : displayedReceipt)
            case final receipt?) ...[
          Text(
            'Confirmación económica: confirmada',
            style: LuckyPalette.text(16),
          ),
          Text(
            'Procedencia: ${receipt.origin == LuckyOrigin.local ? 'fichas del dispositivo' : 'laboratorio de servidor'}',
            style: LuckyPalette.text(16),
          ),
          SelectableText('Recibo: ${receipt.id}', style: LuckyPalette.text(14)),
        ],
      ] else
        Text(
          'Todavía no hay un giro presentado.',
          style: LuckyPalette.text(16),
        ),
      if (problems[repository] != null || storageError != null) ...[
        const Divider(),
        Text(
          problems[repository] ?? storageError!,
          key: const ValueKey('lucky-recovery-message'),
          style: LuckyPalette.text(16),
        ),
      ],
      ..._recoveryActions(),
    ],
  );

  Future<void> _details() async {
    detailsOpen = true;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      sheetAnimationStyle: MediaQuery.disableAnimationsOf(context)
          ? AnimationStyle.noAnimation
          : null,
      useSafeArea: true,
      backgroundColor: LuckyPalette.night,
      builder: (sheetContext) => FractionallySizedBox(
        heightFactor: .85,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: _walletBar(),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(sheetContext),
              child: Text(
                'Cerrar',
                style: LuckyPalette.text(16, color: LuckyPalette.goldLight),
              ),
            ),
          ],
        ),
      ),
    );

    detailsOpen = false;
  }

  Widget _responsive(BoxConstraints constraints) {
    final policy = LuckyLayoutPolicy.of(
      constraints,
      MediaQuery.textScalerOf(context),
    );
    return Stack(
      children: [
        const Positioned.fill(
          child: RepaintBoundary(
            child: CustomPaint(painter: LuckyRoomPainter()),
          ),
        ),
        LuckyResponsiveLayout(
          policy: policy,
          header: _responsiveHeader(policy),
          hud: _compactSummary(policy),
          sidebar: _sideSummary(policy.compact),
          cabinet: TweenAnimationBuilder<double>(
            tween: Tween(begin: .98, end: 1),
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 320),
            builder: (context, scale, child) =>
                Transform.scale(scale: scale, child: child),
            child: AnimatedSwitcher(
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 220),
              child: KeyedSubtree(
                key: ValueKey(gallery ? 'symbols-gallery' : 'cabinet-play'),
                child: gallery ? _gallery() : _machine(!policy.landscape),
              ),
            ),
          ),
          actions: _responsiveActions(policy),
        ),
      ],
    );
  }

  Widget _sideSummary(bool compact) => Padding(
    padding: const EdgeInsets.all(12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Fichas: ${wallet?.balance ?? '—'}',
          key: const ValueKey('lucky-wallet'),
          style: LuckyPalette.text(18, title: true),
        ),
        const SizedBox(height: 12),
        Text(
          'Gratis: ${bonus.remaining}',
          key: const ValueKey('lucky-free-count'),
          style: LuckyPalette.text(16, title: true),
        ),
        const SizedBox(height: 12),
        TextButton.icon(
          key: const ValueKey('lucky-details'),
          onPressed: () => unawaited(_details()),
          icon: const Icon(Icons.receipt_long_rounded),
          label: Semantics(
            liveRegion: true,
            label: _summaryResult,
            excludeSemantics: true,
            child: Text(
              compact ? 'Último giro' : _summaryResult,
              key: const ValueKey('lucky-net'),
              style: LuckyPalette.text(14),
            ),
          ),
        ),
        Semantics(
          liveRegion: true,
          child: Text(
            userPaused
                ? 'Partida en pausa'
                : waiting
                ? 'Confirmando…'
                : presentationActive && !visualSettled
                ? 'Girando…'
                : '',
            key: const ValueKey('lucky-status'),
            style: LuckyPalette.text(14),
          ),
        ),
        if (problems[repository] != null || storageError != null)
          Text(
            problems[repository] ?? storageError!,
            key: const ValueKey('lucky-recovery-message'),
            style: LuckyPalette.text(14),
          ),
        ..._recoveryActions(),
      ],
    ),
  );

  Widget _responsiveHeader(LuckyLayoutPolicy policy) => Row(
    children: [
      IconButton(
        tooltip: 'Volver',
        onPressed: () => Navigator.maybePop(context),
        icon: const Icon(Icons.arrow_back_rounded),
      ),
      Expanded(
        child: policy.landscape
            ? Semantics(
                header: true,
                label: 'Lucky Palace',
                excludeSemantics: true,
                child: Text(
                  policy.compact ? 'LUCKY' : 'LUCKY PALACE',
                  style: LuckyPalette.text(16, title: true),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Flexible(
                    child: LuckyResourceValue(
                      key: const ValueKey('lucky-wallet'),
                      label: 'Fichas',
                      value: '${wallet?.balance ?? '—'}',
                      icon: Icons.toll_rounded,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: LuckyResourceValue(
                      key: const ValueKey('lucky-free-count'),
                      label: 'Giros gratis',
                      value: '${bonus.remaining}',
                      icon: Icons.confirmation_number_outlined,
                    ),
                  ),
                ],
              ),
      ),
      IconButton(
        key: const ValueKey('lucky-paytable'),
        tooltip: 'Tabla de pagos',
        onPressed: _paytable,
        icon: const Icon(Icons.info_outline_rounded),
      ),
      if (widget.enableDeveloperTools)
        PopupMenuButton<LuckyPlayMode>(
          key: const ValueKey('lucky-options'),
          tooltip: 'Opciones',
          icon: const Icon(
            Icons.more_vert_rounded,
            color: LuckyPalette.goldLight,
          ),
          enabled: !presentationActive,
          onSelected: (v) => unawaited(_selectMode(v)),
          itemBuilder: (_) => [
            for (final item in LuckyPlayMode.values)
              PopupMenuItem(
                value: item,
                key: ValueKey('lucky-mode-${item.name}'),
                child: Text(switch (item) {
                  LuckyPlayMode.local => 'Jugar con fichas',
                  LuckyPlayMode.online => 'Prueba de servidor',
                  LuckyPlayMode.motor => 'Laboratorio del motor',
                  LuckyPlayMode.demo => 'Demostraciones visuales',
                }),
              ),
          ],
        ),
    ],
  );

  String get _summaryResult => lastResult == null
      ? 'Último giro'
      : 'Último: premio ${lastResult!.evaluation.total} · neto ${lastResult!.evaluation.total - lastResult!.simulatedCost}';

  Widget _compactSummary(LuckyLayoutPolicy policy) {
    final problem = problems[repository] != null || storageError != null;
    final pending = recovered != null;
    final refill =
        !presentationActive &&
        wallet != null &&
        wallet!.balance < payRules.wager &&
        bonus.remaining == 0;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        children: [
          SizedBox(
            height: 48,
            width: double.infinity,
            child: TextButton.icon(
              key: const ValueKey('lucky-details'),
              onPressed: () => unawaited(_details()),
              icon: Icon(
                problem
                    ? Icons.warning_amber_rounded
                    : pending
                    ? Icons.restore_rounded
                    : refill
                    ? Icons.add_circle_outline
                    : Icons.receipt_long_rounded,
                size: 20,
              ),
              label: Semantics(
                liveRegion: true,
                label: problem
                    ? 'Revisar aviso de guardado o recuperación'
                    : userPaused
                    ? 'Partida en pausa'
                    : waiting
                    ? 'Guardando'
                    : presentationActive && !visualSettled
                    ? 'Girando'
                    : _summaryResult,
                excludeSemantics: true,
                child: Text(
                  problem
                      ? 'Revisar aviso'
                      : pending
                      ? 'Ver pendiente'
                      : refill
                      ? 'Recargar fichas'
                      : userPaused
                      ? 'Pausa'
                      : waiting
                      ? 'Guardando'
                      : presentationActive && !visualSettled
                      ? 'Girando…'
                      : policy.compact
                      ? 'Último giro'
                      : _summaryResult,
                  key: ValueKey(
                    userPaused ||
                            waiting ||
                            presentationActive && !visualSettled
                        ? 'lucky-status'
                        : 'lucky-net',
                  ),
                  style: LuckyPalette.text(13),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _responsiveActions(LuckyLayoutPolicy policy) => Row(
    children: [
      IconButton(
        key: const ValueKey('lucky-history'),
        tooltip: 'Historial',
        onPressed: repository == null ? null : () => unawaited(_history()),
        icon: const Icon(Icons.history),
      ),
      IconButton(
        key: const ValueKey('lucky-pause'),
        tooltip: userPaused ? 'Reanudar' : 'Pausar',
        onPressed: presentationActive ? _togglePause : null,
        icon: Icon(userPaused ? Icons.play_arrow_rounded : Icons.pause_rounded),
      ),
      AudioSettingsButton(
        color: LuckyPalette.goldLight,
        onOpen: () {
          if (presentationActive && !userPaused) {
            _togglePause();
            soundDialogPaused = true;
          }
        },
        onClose: () {
          if (soundDialogPaused) {
            soundDialogPaused = false;
            if (mounted && userPaused) _togglePause();
          }
        },
      ),
      IconButton(
        key: const ValueKey('lucky-scratch'),
        tooltip: 'Raspes de Maru y Lady',
        onPressed: () => unawaited(_openScratch()),
        icon: const Icon(Icons.confirmation_number_outlined),
      ),
      Expanded(
        child: widget.enableDeveloperTools
            ? Semantics(
                label: gallery ? 'Volver al gabinete' : 'Explorar símbolos',
                onTap: _toggleGallery,
                excludeSemantics: true,
                button: true,
                child: TextButton.icon(
                  key: const ValueKey('lucky-symbols'),
                  onPressed: () {
                    if (clock.isAnimating) skip();
                    setState(() => gallery = !gallery);
                  },
                  icon: Icon(
                    gallery ? Icons.casino_outlined : Icons.grid_view_rounded,
                  ),
                  label: Text(
                    gallery ? 'Gabinete' : 'Símbolos',
                    style: LuckyPalette.text(15),
                  ),
                ),
              )
            : TextButton.icon(
                key: const ValueKey('lucky-prizes'),
                onPressed:
                    widget.store == null ||
                        localRepository is! LocalLuckyRoundRepository ||
                        presentationActive ||
                        waiting
                    ? null
                    : _openPrizes,
                icon: const Icon(Icons.card_giftcard_rounded),
                label: const Text('Premios'),
              ),
      ),
    ],
  );

  Future<void> _history() async {
    final repo = repository!;
    try {
      final rows = await repo.history();
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(
            'Historial · ${repo.origin == LuckyOrigin.local ? 'Fichas locales' : 'Sintéticas V2'}',
          ),
          content: SizedBox(
            width: 520,
            height: MediaQuery.sizeOf(context).height * .55,
            child: rows.isEmpty
                ? const Text('Aún no hay rondas confirmadas.')
                : ListView(
                    children: [
                      for (final r in rows)
                        ListTile(
                          title: Text('Premio ${r.gross} · Neto ${r.net}'),
                          subtitle: Text(
                            'Coste ${r.cost} · Saldo ${r.balance}\n${r.round.rules.rulesVersion}\n${r.id}',
                          ),
                          isThreeLine: true,
                        ),
                    ],
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cerrar',
                style: LuckyPalette.text(16, color: LuckyPalette.goldLight),
              ),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => problems[repo] = 'Historial no disponible: $e');
      }
    }
  }

  String get _spinLabel => recovered != null
      ? 'Ver resultado pendiente'
      : userPaused
      ? 'Reanudar'
      : presentationActive
      ? 'Omitir animación'
      : waiting
      ? 'Confirmando giro'
      : bonus.remaining > 0
      ? 'Girar gratis'
      : 'Girar';
  bool get _spinEnabled =>
      !backgrounded &&
      (presentationActive || !financial || (!waiting && wallet != null));
  void _activateSpin() {
    if (financial && recovered != null) {
      unawaited(_details());
    } else if (userPaused) {
      _togglePause();
    } else if (presentationActive) {
      skip();
    } else {
      start();
    }
  }

  Widget _machine(bool portrait) => Column(
    children: [
      if (!financial && widget.enableDeveloperTools)
        SizedBox(
          height: 48,
          child: Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      for (final item in LuckyPlayMode.values)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            key: ValueKey('lucky-mode-${item.name}'),
                            label: Text(switch (item) {
                              LuckyPlayMode.local => 'Local',
                              LuckyPlayMode.online => 'Online · sandbox',
                              LuckyPlayMode.motor => 'Motor · prueba',
                              LuckyPlayMode.demo => 'Demo fija',
                            }),
                            selected: mode == item,
                            selectedColor: LuckyPalette.goldLight,
                            backgroundColor: const Color(0xff35233d),
                            labelStyle: LuckyPalette.text(
                              13,
                              color: mode == item
                                  ? LuckyPalette.ink
                                  : LuckyPalette.cream,
                            ),
                            onSelected: financial && clock.isAnimating
                                ? null
                                : (_) => unawaited(_selectMode(item)),
                          ),
                        ),
                      if (mode == LuckyPlayMode.demo)
                        for (final choice in LuckyDemo.values)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              key: ValueKey('demo-${choice.name}'),
                              label: Text(choice.label),
                              selected: this.choice == choice,
                              onSelected: clock.isAnimating
                                  ? null
                                  : (_) => setState(() => this.choice = choice),
                              selectedColor: LuckyPalette.goldLight,
                              color: WidgetStatePropertyAll(
                                this.choice == choice
                                    ? LuckyPalette.goldLight
                                    : const Color(0xff35233d),
                              ),
                              backgroundColor: const Color(0xff35233d),
                              labelStyle: LuckyPalette.text(
                                13,
                                color: this.choice == choice
                                    ? LuckyPalette.ink
                                    : LuckyPalette.cream,
                              ),
                            ),
                          ),
                    ],
                  ),
                ),
              ),
              IconButton(
                key: const ValueKey('lucky-paytable'),
                tooltip: 'Tabla de pagos candidata',
                onPressed: _paytable,
                icon: const Icon(
                  Icons.info_outline_rounded,
                  color: LuckyPalette.goldLight,
                ),
              ),
            ],
          ),
        ),
      Expanded(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final geometry = LuckyCabinetGeometry(portrait);
            final size = constraints.biggest;
            cellSize = geometry.symbolSize(size);
            // The full 5x3 window and console share the same fitted viewport.
            return AnimatedBuilder(
              animation: clock,
              child: financial
                  ? LuckySpinControl(
                      key: const ValueKey('lucky-spin'),
                      label: _spinLabel,
                      icon: userPaused
                          ? Icons.play_arrow_rounded
                          : presentationActive
                          ? Icons.stop_rounded
                          : waiting
                          ? Icons.hourglass_top_rounded
                          : recovered != null
                          ? Icons.restore_rounded
                          : Icons.refresh_rounded,
                      enabled: _spinEnabled,
                      onPressed: _activateSpin,
                    )
                  : LuckyArtButton(
                      key: const ValueKey('lucky-spin'),
                      label: userPaused
                          ? 'CONTINUAR'
                          : presentationActive
                          ? 'OMITIR'
                          : bonus.remaining > 0
                          ? 'GIRAR GRATIS'
                          : 'GIRAR',
                      onPressed: _activateSpin,
                      enabled: _spinEnabled,
                    ),
              builder: (context, button) => LuckyCabinetArt(
                portrait: portrait,
                integrated: financial,

                frame: frame,
                onPull: pull,
                onRelease: release,
                onLeverTap: start,
                spinButton: button!,
              ),
            );
          },
        ),
      ),
      if (portrait && !financial)
        SizedBox(height: 32, child: Center(child: _status())),
    ],
  );

  Future<void> _paytable() => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: LuckyPalette.night,
      title: Text(
        widget.enableDeveloperTools
            ? 'Tabla candidata · créditos de prueba'
            : 'Tabla de premios · fichas del casino',
        style: LuckyPalette.text(22, title: true),
      ),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${payRules.wager} créditos por ronda: ${payRules.lineStake} por cada una de las cinco líneas. Sin gasto ni abonos de monedas reales.',
                style: LuckyPalette.text(15),
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingTextStyle: LuckyPalette.text(
                    14,
                    color: LuckyPalette.goldLight,
                  ),
                  dataTextStyle: LuckyPalette.text(14),
                  columnSpacing: 10,
                  horizontalMargin: 0,
                  columns: const [
                    DataColumn(label: Text('Símbolo')),
                    DataColumn(label: Text('3')),
                    DataColumn(label: Text('4')),
                    DataColumn(label: Text('5')),
                  ],
                  rows: [
                    for (final entry in payRules.payouts.entries)
                      DataRow(
                        cells: [
                          DataCell(
                            Row(
                              children: [
                                LuckySymbolArt(symbol: entry.key, size: 24),
                                const SizedBox(width: 4),
                                Text(
                                  entry.key == LuckySymbol.seven
                                      ? 'Siete'
                                      : entry.key == LuckySymbol.wild
                                      ? 'Wild'
                                      : entry.key.label,
                                ),
                              ],
                            ),
                          ),
                          for (final count in [3, 4, 5])
                            DataCell(
                              Text(
                                '${(entry.value[count] ?? 0) * payRules.lineStake}',
                              ),
                            ),
                        ],
                      ),
                  ],
                ),
              ),
              Text(
                'Las líneas pagan desde el primer rodillo: superior, central, inferior, V e inversa. Se suman las líneas premiadas. Wild sustituye a los símbolos de línea, nunca a Scatter. Una línea paga solo su mejor combinación; en empate se prefiere longitud y luego el orden del catálogo.',
                style: LuckyPalette.text(14),
              ),
              const SizedBox(height: 8),
              Text(
                'Scatter cuenta rodillos distintos, aunque aparezca varias veces en el mismo rodillo. ${payRules.scatterAwards.entries.map((e) => '${e.key} rodillos: ${e.value} Free Spins').join(' · ')}. No paga créditos directamente. Los retriggers usan la misma regla y el bonus concede como máximo ${payRules.maxBonusSpins} giros en total. Se conserva la apuesta de referencia.',
                style: LuckyPalette.text(14),
              ),
              const SizedBox(height: 8),
              Text(
                widget.enableDeveloperTools
                    ? 'Reglas: ${payRules.rulesVersion} · ${payRules.catalogVersion}.'
                    : 'Usa tus fichas en Premios para canjear monedas y prendas exclusivas. Cada premio se obtiene una sola vez. Los giros de pago y los raspes revelados cuentan para desbloquearlos. Si quedan menos de 25 fichas y no tienes giros gratis pendientes, puedes recargar 500 gratis.',
                style: LuckyPalette.text(13, color: LuckyPalette.goldLight),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Cerrar',
            style: LuckyPalette.text(15, color: LuckyPalette.goldLight),
          ),
        ),
      ],
    ),
  );

  Widget _gallery() => LayoutBuilder(
    builder: (context, constraints) {
      final columns = constraints.maxWidth >= 700 ? 3 : 2;
      final gridWidth = math.min(960.0, constraints.maxWidth - 36);
      final cardWidth = (gridWidth - (columns - 1) * 10) / columns;
      final light = background != 'Oscuro';
      final foreground = light ? LuckyPalette.ink : LuckyPalette.cream;
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
        child: Column(
          children: [
            Text(
              'Galería de símbolos',
              textAlign: TextAlign.center,
              style: LuckyPalette.text(
                23,
                title: true,
                color: LuckyPalette.goldLight,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              alignment: WrapAlignment.center,
              children: [
                for (final name in ['Oscuro', 'Marfil', 'Casilla'])
                  ChoiceChip(
                    key: ValueKey('lucky-background-$name'),
                    label: Text(name),
                    selected: background == name,
                    onSelected: (_) => setState(() => background = name),
                    selectedColor: LuckyPalette.goldLight,
                    backgroundColor: const Color(0xff35233d),
                    checkmarkColor: LuckyPalette.ink,
                    labelStyle: LuckyPalette.text(
                      14,
                      color: background == name
                          ? LuckyPalette.ink
                          : LuckyPalette.cream,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: math.min(960, constraints.maxWidth),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: light ? LuckyPalette.cream : const Color(0xff2a1b35),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xff8c655d), width: 2),
              ),
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                alignment: WrapAlignment.center,
                spacing: 22,
                runSpacing: 10,
                children: [
                  if (background == 'Casilla')
                    Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Color(0xffaa7867),
                                LuckyPalette.cream,
                                Color(0xfffffbed),
                                LuckyPalette.cream,
                                Color(0xffad7c68),
                              ],
                              stops: [0, .16, .44, .82, 1],
                            ),
                          ),
                          child: LuckySymbolArt(
                            symbol: selected,
                            size: cellSize,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Casilla actual · ${cellSize.round()} dp',
                          style: LuckyPalette.text(12, color: foreground),
                        ),
                      ],
                    )
                  else
                    LuckySymbolArt(symbol: selected, size: 128),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        selected.label,
                        style: LuckyPalette.text(
                          20,
                          title: true,
                          color: foreground,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          for (final size in [32.0, 48.0, 64.0])
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                              ),
                              child: Column(
                                children: [
                                  LuckySymbolArt(symbol: selected, size: size),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${size.toInt()} dp',
                                    style: LuckyPalette.text(
                                      11,
                                      color: foreground,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: gridWidth,
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final symbol in LuckySymbol.values)
                    SizedBox(
                      width: cardWidth,
                      height: MediaQuery.textScalerOf(context).scale(35) + 104,
                      child: _symbolCard(symbol),
                    ),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );

  Widget _symbolCard(LuckySymbol symbol) {
    final active = symbol == selected;
    return Semantics(
      button: true,
      selected: active,
      label: 'Seleccionar ${symbol.label}',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: ValueKey('lucky-symbol-${symbol.name}'),
          borderRadius: BorderRadius.circular(18),
          onTap: () => setState(() => selected = symbol),
          child: Ink(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: active
                    ? const [Color(0xff6a3c59), Color(0xff352139)]
                    : const [Color(0xff30263e), Color(0xff211a30)],
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: active
                    ? LuckyPalette.goldLight
                    : const Color(0xff584356),
                width: active ? 2.5 : 1,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                children: [
                  LuckySymbolArt(symbol: symbol, size: 80),
                  const SizedBox(height: 4),
                  Expanded(
                    child: Center(
                      child: Text(
                        symbol.label,
                        textAlign: TextAlign.center,
                        style: LuckyPalette.text(
                          12,
                          color: active
                              ? LuckyPalette.goldLight
                              : LuckyPalette.cream,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A real tactile control, rather than text painted into the cabinet.
class LuckyArtButton extends StatefulWidget {
  const LuckyArtButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.enabled = true,
    this.adaptive = false,
    this.semanticLabel,
  });
  final String label;
  final VoidCallback onPressed;
  final bool enabled;
  final bool adaptive;
  final String? semanticLabel;
  @override
  State<LuckyArtButton> createState() => _LuckyArtButtonState();
}

class _LuckyArtButtonState extends State<LuckyArtButton> {
  bool pressed = false;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    enabled: widget.enabled,
    label: widget.semanticLabel ?? widget.label,
    onTap: widget.enabled ? widget.onPressed : null,
    excludeSemantics: true,
    child: Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: const Color(0xff643522),
              offset: Offset(0, pressed ? 2 : 6),
            ),
          ],
        ),
        child: Transform.translate(
          offset: Offset(0, pressed ? 4 : 0),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xffffefac),
                  Color(0xffffd46d),
                  Color(0xffe9a947),
                ],
              ),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: LuckyPalette.goldLight, width: 2),
            ),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(20),
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onHighlightChanged: (value) => setState(() => pressed = value),
                onTap: widget.enabled ? widget.onPressed : null,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 68),
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      child: widget.adaptive
                          ? Text(
                              widget.label,
                              textAlign: TextAlign.center,
                              style: LuckyPalette.text(
                                18,
                                title: true,
                                color: const Color(0xff592b30),
                              ),
                            )
                          : FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                widget.label,
                                textAlign: TextAlign.center,
                                style: LuckyPalette.text(
                                  25,
                                  title: true,
                                  color: const Color(0xff592b30),
                                ),
                              ),
                            ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
