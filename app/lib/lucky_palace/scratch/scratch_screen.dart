import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../game_audio.dart';
import '../art/lucky_cabinet_art.dart';
import '../data/lucky_database.dart';
import '../data/lucky_models.dart';
import '../data/local_lucky_repository.dart';
import '../lucky_console_controls.dart';
import '../lucky_palace_theme.dart';
import 'scratch_catalog.dart';
import 'scratch_engine.dart';
import 'scratch_mask.dart';
import 'scratch_models.dart';
import 'scratch_local_repository.dart';
import 'scratch_ticket_widget.dart';

enum ScratchPhase {
  catalog,
  preparing,
  covered,
  scratching,
  revealReady,
  revealed,
  recovering,
  storageError,
}

class ScratchScreen extends StatefulWidget {
  const ScratchScreen({super.key, this.repository});
  final ScratchLocalRepository? repository;
  @override
  State<ScratchScreen> createState() => _ScratchScreenState();
}

class _ScratchScreenState extends State<ScratchScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  ScratchLocalRepository? repo;
  ScratchReceipt? ticket;
  ScratchMask mask = ScratchMask();
  final progress = ValueNotifier<double>(0);
  late final AnimationController reaction;
  ScratchTheme theme = ScratchTheme.all.first;
  ScratchPhase phase = ScratchPhase.recovering;
  bool catalog = true,
      busy = true,
      dirty = false,
      wantReveal = false,
      active = true,
      historyView = false,
      touched = false,
      allowPop = false;
  int? balance;
  String? error;
  Timer? saveTimer;
  Future<bool>? saving;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    reaction = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    unawaited(_initialize());
  }

  Future<void> _initialize() async {
    final unsavedId = dirty ? ticket?.id : null;
    final unsavedMask = dirty ? mask.copy() : null;
    final unsavedReveal = wantReveal;
    if (mounted) {
      setState(() {
        busy = true;
        error = null;
        phase = ScratchPhase.recovering;
      });
    }
    try {
      repo =
          widget.repository ??
          ScratchLocalRepository(LuckyDatabase(await openLuckyDatabase()));
      final recovered = await repo!.recover();
      final b = await repo!.balance();
      if (!mounted) return;
      setState(() {
        balance = b;
        busy = false;
        if (recovered != null) {
          _show(recovered);
          if (recovered.id == unsavedId && unsavedMask != null) {
            mask.merge(unsavedMask);
            progress.value = mask.coverage;
            dirty = true;
            wantReveal = wantReveal || unsavedReveal;
          }
          catalog = false;
        } else {
          catalog = true;
          phase = ScratchPhase.catalog;
        }
      });
      if (dirty) await _flush();
    } catch (e) {
      _fail(e);
    }
  }

  void _fail(Object e) {
    if (mounted) {
      setState(() {
        error = 'No se confirmó el guardado. El historial se conserva. $e';
        phase = ScratchPhase.storageError;
        busy = false;
      });
    }
  }

  void _show(ScratchReceipt value, {bool fromHistory = false}) {
    ticket = value;
    theme = value.theme;
    mask = value.mask.copy();
    progress.value = mask.coverage;
    dirty = false;
    wantReveal = value.revealed;
    historyView = fromHistory;
    touched = false;
    phase = value.revealed ? ScratchPhase.revealed : ScratchPhase.covered;
  }

  Future<void> _open() async {
    if (busy || repo == null || error != null) return;
    if (ticket != null && !ticket!.revealed) {
      setState(() {
        catalog = false;
        theme = ticket!.theme;
      });
      return;
    }
    setState(() {
      busy = true;
      phase = ScratchPhase.preparing;
    });
    try {
      final id = luckyId();
      await repo!.prepare(theme.id, id);
      final receipt = await repo!.execute(id);
      final b = await repo!.balance();
      if (!mounted) return;
      setState(() {
        _show(receipt);
        balance = b;
        catalog = false;
        busy = false;
      });
      if (active) {
        GameAudio.instance.play(GameSfx.paper);
        _react();
      }
    } catch (e) {
      _fail(e);
    }
  }

  void _react() {
    if (!MediaQuery.disableAnimationsOf(context) && active) {
      reaction.forward(from: 0);
    }
  }

  void _onStart() {
    if (!touched) {
      touched = true;
      _react();
      if (!MediaQuery.disableAnimationsOf(context)) {
        HapticFeedback.selectionClick();
      }
    }
  }

  void _changed() {
    if (ticket == null || ticket!.revealed) return;
    dirty = true;
    progress.value = mask.coverage;
    if (phase == ScratchPhase.covered) {
      setState(() => phase = ScratchPhase.scratching);
    }
    if (mask.coverage >= ScratchRules.autoReveal && !wantReveal) {
      wantReveal = true;
      setState(() {
        busy = true;
        phase = ScratchPhase.revealReady;
      });
      unawaited(_flush());
    } else {
      saveTimer ??= Timer(const Duration(milliseconds: 300), () {
        saveTimer = null;
        unawaited(_flush());
      });
    }
  }

  Future<bool> _persist(String id, ScratchMask snapshot, bool reveal) async {
    try {
      final result = await repo!.saveVisual(id, snapshot, reveal: reveal);
      if (!mounted) return true;
      if (ticket?.id == id) {
        final discovered = !ticket!.revealed && result.revealed;
        mask.merge(result.mask);
        setState(() {
          ticket = ScratchReceipt(
            result.data,
            mask: mask,
            revealed: result.revealed,
          );
          busy = false;
          if (result.revealed) phase = ScratchPhase.revealed;
        });
        if (discovered && active) {
          GameAudio.instance.play(
            result.gross > 0 ? GameSfx.reveal : GameSfx.place,
          );
          _react();
          if (!MediaQuery.disableAnimationsOf(context)) {
            HapticFeedback.lightImpact();
          }
        }
      }
      return true;
    } catch (e) {
      dirty = true;
      _fail(e);
      return false;
    }
  }

  Future<bool> _flush() async {
    saveTimer?.cancel();
    saveTimer = null;
    if (saving != null) {
      final ok = await saving!;
      if (!ok) return false;
      return _flush();
    }
    if (!dirty || ticket == null) return true;
    dirty = false;
    final job = _persist(ticket!.id, mask.copy(), wantReveal);
    saving = job;
    final ok = await job;
    saving = null;
    if (ok && dirty) return _flush();
    return ok;
  }

  Future<void> _reveal() async {
    if (busy || ticket == null || ticket!.revealed || error != null) return;
    wantReveal = true;
    dirty = true;
    setState(() {
      busy = true;
      phase = ScratchPhase.revealReady;
    });
    await _flush();
  }

  Future<void> _catalog() async {
    if (!await _flush()) return;
    try {
      final current = await repo?.recover();
      final b = await repo?.balance();
      if (mounted) {
        setState(() {
          if (current != null) _show(current);
          if (b != null) balance = b;
          catalog = true;
          historyView = false;
          phase = ScratchPhase.catalog;
        });
      }
    } catch (e) {
      _fail(e);
    }
  }

  Future<void> _back() async {
    if (!await _flush()) {
      if (mounted) await _details();
      return;
    }
    if (!mounted) return;
    if (!catalog) {
      await _catalog();
      return;
    }
    setState(() => allowPop = true);
    Navigator.pop(context);
  }

  Future<void> _refill() async {
    if (repo == null || busy) return;
    setState(() => busy = true);
    try {
      await LocalLuckyRoundRepository(repo!.storage).refill();
      final b = await repo!.balance();
      if (mounted) {
        setState(() {
          balance = b;
          busy = false;
        });
      }
    } catch (e) {
      _fail(e);
    }
  }

  Future<void> _details() => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: LuckyPalette.night,
    sheetAnimationStyle: MediaQuery.disableAnimationsOf(context)
        ? AnimationStyle.noAnimation
        : null,
    builder: (ctx) => FractionallySizedBox(
      heightFactor: .85,
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(theme.title, style: LuckyPalette.text(22, title: true)),
                  const SizedBox(height: 12),
                  Text(
                    'Busca tres o más símbolos iguales en cualquier posición. Cada tipo que aparezca tres veces paga una vez. Los premios de tipos distintos se suman.',
                    style: LuckyPalette.text(16),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Boleto: ${ScratchRules.cost} fichas del casino. Tabla candidata de laboratorio. No entrega monedas generales, cartas ni ropa.',
                    style: LuckyPalette.text(16),
                  ),
                  for (var i = 0; i < 6; i++)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Image.asset(
                            '$scratchAssetRoot/symbols/png/${theme.symbols[i]}_128.png',
                            width: 40,
                            height: 40,
                            excludeFromSemantics: true,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              '${scratchSymbolNames[theme.symbols[i]]} · 3 o más: ${ScratchRules.payouts[i]} fichas',
                              style: LuckyPalette.text(16),
                            ),
                          ),
                        ],
                      ),
                    ),
                  Text(
                    'Rasca con un pincel de 36 dp. Al descubrir el 60% se revela el resto. Revelar todo no cobra ni vuelve a conceder premios. El resultado se guarda antes de mostrar el boleto.',
                    style: LuckyPalette.text(16),
                  ),
                  if (ticket != null) ...[
                    const Divider(),
                    Text(
                      'Coste cobrado: ${ticket!.cost}',
                      style: LuckyPalette.text(16),
                    ),
                    if (ticket!.revealed) ...[
                      Text(
                        'Premio bruto: ${ticket!.gross} · Neto: ${ticket!.net}',
                        style: LuckyPalette.text(16),
                      ),
                      Text(
                        'Símbolos: ${ticket!.outcome.cells.map((i) => scratchSymbolNames[ticket!.theme.symbols[i]]).join(', ')}',
                        style: LuckyPalette.text(16),
                      ),
                    ] else
                      Text(
                        'Resultado confirmado, todavía cubierto.',
                        style: LuckyPalette.text(16),
                      ),
                    SelectableText(
                      'Recibo: ${ticket!.id}\n${ScratchRules.version}',
                      style: LuckyPalette.text(14),
                    ),
                  ],
                  Text(
                    'Saldo exacto: ${balance ?? '—'} fichas',
                    style: LuckyPalette.text(16),
                  ),
                  if (error != null)
                    Text(
                      error!,
                      key: const ValueKey('scratch-error'),
                      style: LuckyPalette.text(16),
                    ),
                  if (balance != null && balance! < ScratchRules.cost) ...[
                    Text(
                      'Si quedan giros gratis de Lucky 777, puedes volver a jugarlos. La recarga gratuita conserva las condiciones existentes del casino.',
                      style: LuckyPalette.text(16),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        unawaited(_refill());
                      },
                      child: const Text('Recargar fichas gratis'),
                    ),
                  ],
                ],
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    ),
  );
  Future<void> _history() async {
    if (repo == null) return;
    if (!await _flush()) return;
    try {
      final rows = await repo!.history();
      if (!mounted) return;
      final selected = await showDialog<ScratchReceipt>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Historial de raspes'),
          content: SizedBox(
            width: 520,
            height: MediaQuery.sizeOf(context).height * .55,
            child: rows.isEmpty
                ? const Text('Aún no hay boletos.')
                : ListView(
                    children: [
                      for (final r in rows)
                        ListTile(
                          title: Text(r.theme.title),
                          subtitle: Text(
                            r.revealed
                                ? 'Premio ${r.gross} · Coste ${r.cost} · Neto ${r.net}'
                                : 'Boleto pendiente de revelar',
                          ),
                          onTap: () => Navigator.pop(ctx, r),
                        ),
                    ],
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      );
      if (selected != null && mounted) {
        setState(() {
          _show(selected, fromHistory: true);
          catalog = false;
        });
      }
    } catch (e) {
      _fail(e);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    active = state == AppLifecycleState.resumed;
    if (!active) {
      reaction.stop();
      unawaited(_flush());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    saveTimer?.cancel();
    if (dirty) unawaited(_flush());
    reaction.dispose();
    progress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: ThemeData(
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: LuckyPalette.goldLight,
        surface: LuckyPalette.night,
      ),
      textTheme: Theme.of(context).textTheme.apply(
        fontFamily: 'Nunito',
        bodyColor: LuckyPalette.cream,
        displayColor: LuckyPalette.cream,
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(48, 48),
          foregroundColor: LuckyPalette.goldLight,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
      ),
    ),
    child: PopScope(
      canPop: allowPop,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) unawaited(_back());
      },
      child: Scaffold(
        backgroundColor: LuckyPalette.night,
        body: SafeArea(
          child: Stack(
            children: [
              const Positioned.fill(
                child: RepaintBoundary(
                  child: CustomPaint(painter: LuckyRoomPainter()),
                ),
              ),
              LayoutBuilder(
                builder: (context, c) {
                  final side = c.maxWidth > c.maxHeight;
                  final ticketWidget = TweenAnimationBuilder<double>(
                    key: ValueKey('entry-${ticket?.id ?? theme.id}'),
                    tween: Tween(begin: .97, end: 1),
                    duration: MediaQuery.disableAnimationsOf(context)
                        ? Duration.zero
                        : const Duration(milliseconds: 300),
                    builder: (context, v, child) =>
                        Transform.scale(scale: v, child: child),
                    child: ScratchTicketWidget(
                      key: ValueKey('${theme.id}-${ticket?.id ?? 'cover'}'),
                      theme: theme,
                      receipt: catalog ? null : ticket,
                      mask: mask,
                      enabled: !catalog && !busy && error == null && active,
                      onChanged: _changed,
                      onGestureEnd: () => unawaited(_flush()),
                      onStart: _onStart,
                      reaction: reaction,
                    ),
                  );
                  return side
                      ? Row(
                          children: [
                            SizedBox(
                              width:
                                  MediaQuery.textScalerOf(context).scale(14) >
                                      22
                                  ? 260
                                  : 220,
                              child: Padding(
                                padding: const EdgeInsets.all(8),
                                child: Column(
                                  children: [
                                    _header(side: true),
                                    const SizedBox(height: 8),
                                    _wallet(),
                                    Expanded(
                                      child: catalog
                                          ? SingleChildScrollView(
                                              child: _themes(vertical: true),
                                            )
                                          : const SizedBox.shrink(),
                                    ),
                                    _status(compact: true),
                                    _primary(),
                                  ],
                                ),
                              ),
                            ),
                            Expanded(child: ticketWidget),
                          ],
                        )
                      : Column(
                          children: [
                            SizedBox(height: 56, child: _header()),
                            if (catalog) SizedBox(height: 56, child: _themes()),
                            Expanded(child: ticketWidget),
                            SizedBox(height: 48, child: _status()),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                              child: _primary(),
                            ),
                          ],
                        );
                },
              ),
            ],
          ),
        ),
      ),
    ),
  );
  Widget _wallet() => LuckyResourceValue(
    key: const ValueKey('scratch-wallet'),
    label: 'Fichas del casino',
    value: '${balance ?? '—'}',
    icon: Icons.toll_rounded,
  );
  Widget _header({bool side = false}) => Row(
    children: [
      IconButton(
        key: const ValueKey('scratch-back'),
        tooltip: catalog ? 'Volver a Lucky Palace' : 'Ver temáticas',
        onPressed: busy ? null : () => unawaited(_back()),
        icon: const Icon(Icons.arrow_back_rounded),
      ),
      if (!side) Expanded(child: _wallet()),
      IconButton(
        key: const ValueKey('scratch-history'),
        tooltip: 'Historial de raspes',
        onPressed: busy ? null : () => unawaited(_history()),
        icon: const Icon(Icons.history),
      ),
      IconButton(
        key: const ValueKey('scratch-help'),
        tooltip: 'Reglas y detalles',
        onPressed: () => unawaited(_details()),
        icon: const Icon(Icons.info_outline_rounded),
      ),
      const AudioSettingsButton(color: LuckyPalette.goldLight),
    ],
  );
  Widget _themes({bool vertical = false}) {
    final choices = [
      for (final t in ScratchTheme.all)
        Tooltip(
          message: t.title,
          child: Semantics(
            label: t.title,
            selected: t == theme,
            child: OutlinedButton(
              key: ValueKey('scratch-theme-${t.id}'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(54, 48),
                padding: const EdgeInsets.all(4),
                side: BorderSide(
                  color: t == theme ? Color(t.accent) : const Color(0x887f5b71),
                  width: t == theme ? 2 : 1,
                ),
              ),
              onPressed: busy
                  ? null
                  : () {
                      setState(() => theme = t);
                    },
              child: vertical
                  ? Row(
                      children: [
                        Image.asset(
                          t.asset('cover_preview'),
                          width: 28,
                          height: 42,
                          cacheWidth: 56,
                          excludeFromSemantics: true,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(t.title, style: LuckyPalette.text(14)),
                        ),
                      ],
                    )
                  : Image.asset(
                      t.asset('cover_preview'),
                      width: 28,
                      height: 40,
                      cacheWidth: 56,
                      excludeFromSemantics: true,
                    ),
            ),
          ),
        ),
    ];
    return vertical
        ? Column(
            children: [
              for (final child in choices)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: child,
                ),
            ],
          )
        : SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                for (final child in choices)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: child,
                  ),
              ],
            ),
          );
  }

  Widget _status({bool compact = false}) => ValueListenableBuilder<double>(
    valueListenable: progress,
    builder: (context, v, _) => Center(
      child: TextButton(
        onPressed: () => unawaited(_details()),
        child: Text(
          error != null
              ? 'Revisar aviso'
              : busy
              ? 'Guardando…'
              : catalog
              ? 'Elige tu boleto'
              : ticket?.revealed == true
              ? compact
                    ? 'Ver resultado'
                    : 'Premio ${ticket!.gross} · Neto ${ticket!.net >= 0 ? '+' : ''}${ticket!.net}'
              : 'Rasca · ${(v * 100).floor()}%',
          key: const ValueKey('scratch-status'),
          style: LuckyPalette.text(14),
        ),
      ),
    ),
  );
  Widget _primary() => SizedBox(
    width: double.infinity,
    child: FilledButton(
      key: const ValueKey('scratch-primary'),
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 64),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        backgroundColor: Color(theme.accent),
        foregroundColor: LuckyPalette.ink,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      ),
      onPressed: busy
          ? null
          : error != null
          ? () => unawaited(_initialize())
          : historyView
          ? () => unawaited(_catalog())
          : catalog
          ? () => unawaited(_open())
          : ticket?.revealed == true
          ? () => unawaited(_catalog())
          : () => unawaited(_reveal()),
      child: Text(
        error != null
            ? 'REINTENTAR'
            : busy
            ? 'GUARDANDO'
            : historyView
            ? 'VOLVER'
            : catalog
            ? (ticket != null && !ticket!.revealed
                  ? 'CONTINUAR BOLETO'
                  : 'ABRIR · ${ScratchRules.cost} FICHAS')
            : ticket?.revealed == true
            ? 'OTRO BOLETO'
            : 'REVELAR TODO',
        textAlign: TextAlign.center,
        style: LuckyPalette.text(14, title: true, color: LuckyPalette.ink),
      ),
    ),
  );
}
