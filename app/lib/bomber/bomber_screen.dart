import 'dart:async';
import 'dart:math' as math;
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import '../backend.dart';
import '../bloc_people.dart';
import '../cat_care.dart';
import '../store.dart';
import '../game_audio.dart';
import 'bomber_config.dart';
import 'bomber_network.dart';
import 'bomber_painter.dart';
import 'bomber_simulation.dart';

class BomberScreen extends StatefulWidget {
  const BomberScreen({super.key, required this.store});
  final GameStore store;
  @override
  State<BomberScreen> createState() => _BomberScreenState();
}

class _BomberScreenState extends State<BomberScreen> {
  int mapId = 0;
  BomberCat cat = BomberCat.maru;
  bool busy = false;
  String error = '', search = '';
  Map<String, dynamic> get outfit => cat == BomberCat.maru
      ? widget.store.catCare.outfit(CatKind.maru).toJson()
      : cat == BomberCat.lady
      ? widget.store.catCare.outfit(CatKind.lady).toJson()
      : {};
  Future<void> online(String action, {String? target, String? room}) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      // The server reads the saved wardrobe; finish any recent outfit change
      // before asking it to create the room's immutable character appearance.
      await widget.store.save();
      await widget.store.cloud.sync();
      if (!mounted) return;
      final result = await BomberNetwork.request(
        action,
        room: room,
        extra: {'cat': cat.name, 'mapId': mapId, 'target': ?target},
      );
      final id = result['room'] as String;
      if (!mounted) {
        unawaited(BomberNetwork.request('leave', room: id));
        return;
      }
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => BomberGameScreen(
            store: widget.store,
            sim: BomberSimulation.network(Backend.uid!),
            room: id,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final arena = bomberArenas[mapId];
    return Scaffold(
      backgroundColor: arena.background,
      appBar: AppBar(
        backgroundColor: arena.background,
        foregroundColor: Colors.white,
        title: const Text('Bomber Miau'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              const Text(
                'Patitas, bombas y una gran escapada',
                style: TextStyle(
                  fontSize: 24,
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Rompe cajas, recoge poderes y escapa de la explosión. Gana el último gatito en pie.',
                style: TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 22),
              const Text(
                'ELIGE TU GATITO',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  for (final c in BomberCat.values)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: busy ? null : () => setState(() => cat = c),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: cat == c
                                  ? arena.accent.withValues(alpha: .22)
                                  : Colors.white.withValues(alpha: .06),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: cat == c ? arena.accent : Colors.white24,
                                width: cat == c ? 2 : 1,
                              ),
                            ),
                            child: Column(
                              children: [
                                AspectRatio(
                                  aspectRatio: 1,
                                  child: CustomPaint(
                                    painter: BomberKittenPainter(
                                      c,
                                      outfit: c == BomberCat.maru
                                          ? widget.store.catCare.outfit(
                                              CatKind.maru,
                                            )
                                          : c == BomberCat.lady
                                          ? widget.store.catCare.outfit(
                                              CatKind.lady,
                                            )
                                          : const CatOutfit(),
                                    ),
                                  ),
                                ),
                                Text(
                                  c.label,
                                  style: TextStyle(
                                    color: cat == c
                                        ? arena.accent
                                        : Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              const Text(
                'Los cuatro tienen las mismas habilidades. Maru y Lady llevan tu ropa.',
                style: TextStyle(color: Colors.white60, fontSize: 12),
              ),
              const SizedBox(height: 20),
              const Text(
                'ELIGE UNA ARENA',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (var i = 0; i < 4; i++)
                    LayoutBuilder(
                      builder: (context, constraints) => SizedBox(
                        width:
                            (math.min(
                                  600.0,
                                  MediaQuery.sizeOf(context).width - 40,
                                ) -
                                10) /
                            2,
                        child: InkWell(
                          onTap: busy ? null : () => setState(() => mapId = i),
                          borderRadius: BorderRadius.circular(18),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: bomberArenas[i].floor.withValues(
                                alpha: .25,
                              ),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: mapId == i
                                    ? bomberArenas[i].accent
                                    : Colors.white24,
                                width: mapId == i ? 2 : 1,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  height: 66,
                                  child: CustomPaint(
                                    size: const Size(double.infinity, 66),
                                    painter: _ArenaThumbnail(i),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  bomberArenas[i].name,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  bomberArenas[i].subtitle,
                                  style: const TextStyle(
                                    color: Colors.white60,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 22),
              FilledButton.icon(
                onPressed: busy
                    ? null
                    : () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => BomberGameScreen(
                              store: widget.store,
                              sim: BomberSimulation.training(
                                mapId: mapId,
                                cat: cat,
                                outfit: outfit,
                                seed:
                                    DateTime.now().millisecondsSinceEpoch &
                                    0x7fffffff,
                              ),
                            ),
                          ),
                        );
                      },
                icon: const Icon(Icons.smart_toy_outlined),
                label: const Padding(
                  padding: EdgeInsets.all(13),
                  child: Text('Jugar contra la IA'),
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white38),
                ),
                onPressed: busy || Backend.uid == null
                    ? null
                    : () => online('find'),
                icon: busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.wifi_rounded),
                label: const Padding(
                  padding: EdgeInsets.all(13),
                  child: Text('Buscar rival en esta arena'),
                ),
              ),
              if (Backend.uid == null)
                const Padding(
                  padding: EdgeInsets.all(10),
                  child: Text(
                    'Conecta Google en Inicio para buscar e invitar jugadores.',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
              if (error.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Text(
                    error,
                    style: const TextStyle(color: Color(0xffffc1ba)),
                  ),
                ),
              const SizedBox(height: 18),
              ExpansionTile(
                iconColor: Colors.white,
                collapsedIconColor: Colors.white,
                title: const Text(
                  'Los seis poderes',
                  style: TextStyle(color: Colors.white),
                ),
                children: [
                  for (final p in KittenPower.values)
                    ListTile(
                      leading: Icon(p.glyph, color: arena.accent, size: 24),
                      title: Text(
                        p.label,
                        style: const TextStyle(color: Colors.white),
                      ),
                      subtitle: Text(
                        p.effect,
                        style: const TextStyle(color: Colors.white60),
                      ),
                    ),
                ],
              ),
              if (Backend.uid != null) ...[
                StreamBuilder<DatabaseEvent>(
                  stream: FirebaseDatabase.instance
                      .ref('bomberInvites/${Backend.uid}')
                      .onValue,
                  builder: (context, s) {
                    if (s.hasError) {
                      return const Text(
                        'No se pudieron cargar las invitaciones.',
                        style: TextStyle(color: Colors.white70),
                      );
                    }
                    final invites = objectMap(s.data?.snapshot.value).entries
                        .where(
                          (e) =>
                              valueNum(objectMap(e.value)['until']) >
                              DateTime.now().millisecondsSinceEpoch,
                        );
                    return Column(
                      children: [
                        for (final e in invites)
                          Card(
                            child: ListTile(
                              leading: const Icon(Icons.mail_outline),
                              title: Text(
                                '${objectMap(e.value)['name']} te invita',
                              ),
                              subtitle: Text(
                                bomberArenas[valueNum(
                                      objectMap(e.value)['mapId'],
                                    ).toInt().clamp(0, 3)]
                                    .name,
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    tooltip: 'Rechazar invitación',
                                    icon: const Icon(Icons.close),
                                    onPressed: busy
                                        ? null
                                        : () async {
                                            try {
                                              await BomberNetwork.request(
                                                'decline',
                                                room: e.key,
                                              );
                                            } catch (_) {
                                              if (mounted) {
                                                setState(
                                                  () => error =
                                                      'No se pudo rechazar. Intenta de nuevo.',
                                                );
                                              }
                                            }
                                          },
                                  ),
                                  FilledButton(
                                    onPressed: busy
                                        ? null
                                        : () => online('accept', room: e.key),
                                    child: const Text('Jugar'),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Buscar jugador por nombre',
                    labelStyle: const TextStyle(color: Colors.white70),
                    prefixIcon: const Icon(
                      Icons.person_search,
                      color: Colors.white70,
                    ),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: .07),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  onChanged: (v) => setState(() => search = v),
                ),
                const SizedBox(height: 8),
                StreamBuilder(
                  stream: BlocPeople.people(search),
                  builder: (context, s) {
                    if (s.hasError) {
                      return const Text(
                        'No se pudo consultar la lista de jugadores.',
                        style: TextStyle(color: Colors.white70),
                      );
                    }
                    if (!s.hasData) return const LinearProgressIndicator();
                    final users = s.data!.docs
                        .where((d) => d.id != Backend.uid)
                        .toList();
                    if (users.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.all(12),
                        child: Text(
                          'No hay jugadores con ese nombre.',
                          style: TextStyle(color: Colors.white60),
                        ),
                      );
                    }
                    return Column(
                      children: [
                        for (final u in users)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: CircleAvatar(
                              backgroundColor: arena.accent,
                              child: const Icon(Icons.pets),
                            ),
                            title: Text(
                              u.data()['name'] as String? ?? 'Gatito',
                              style: const TextStyle(color: Colors.white),
                            ),
                            subtitle: const Text(
                              'Usuario de la app',
                              style: TextStyle(color: Colors.white54),
                            ),
                            trailing: TextButton(
                              onPressed: busy
                                  ? null
                                  : () => online('invite', target: u.id),
                              child: Text(
                                'Invitar',
                                style: TextStyle(color: arena.accent),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ArenaThumbnail extends CustomPainter {
  const _ArenaThumbnail(this.mapId);
  final int mapId;
  @override
  void paint(Canvas c, Size size) {
    final a = bomberArenas[mapId],
        board = makeBomberBoard(42, mapId: mapId),
        cell = math.min(size.width / 11, size.height / 5),
        left = (size.width - cell * 11) / 2;
    c.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(9)),
      Paint()..color = a.floor,
    );
    for (var y = 4; y < 9; y++) {
      for (var x = 0; x < 11; x++) {
        final k = cellKey(x, y),
            wall = objectMap(board['walls']).containsKey(k),
            crate = objectMap(board['crates']).containsKey(k);
        if (!wall && !crate) continue;
        final r = Rect.fromLTWH(
          left + x * cell,
          (y - 4) * cell + 2,
          cell - 2,
          cell - 3,
        );
        c.drawRRect(
          RRect.fromRectAndRadius(r, const Radius.circular(3)),
          Paint()
            ..color = Color.lerp(wall ? a.wall : a.crate, Colors.black, .35)!,
        );
        c.drawRRect(
          RRect.fromRectAndRadius(
            r.shift(const Offset(0, -3)),
            const Radius.circular(3),
          ),
          Paint()..color = wall ? a.wall : a.crate,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_ArenaThumbnail old) => old.mapId != mapId;
}

class BomberGameScreen extends StatefulWidget {
  const BomberGameScreen({
    super.key,
    required this.sim,
    required this.store,
    this.room,
  });
  final GameStore store;
  final BomberSimulation sim;
  final String? room;
  @override
  State<BomberGameScreen> createState() => _BomberGameScreenState();
}

class _BomberGameScreenState extends State<BomberGameScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final Ticker ticker;
  BomberNetwork? network;
  final focus = FocusNode();
  Duration last = Duration.zero;
  late int localTime;
  int hudAt = 0;
  bool paused = false, bombBusy = false, readySent = false;
  String message = '';
  int _paidCoins = 0;
  bool _paidWin = false;
  late final String _rewardId;
  final keys = <LogicalKeyboardKey>{};
  BomberSimulation get sim => widget.sim;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    localTime = DateTime.now().millisecondsSinceEpoch;
    _rewardId = widget.room ?? 'training:$localTime';
    sim.now = localTime;
    sim.onEffect = (effect) => GameAudio.instance.play(switch (effect) {
      'explosion' => GameSfx.clear,
      'power' => GameSfx.coin,
      'hit' => GameSfx.kitten,
      _ => GameSfx.place,
    });
    if (widget.room != null) {
      network = BomberNetwork(widget.room!, sim)..start();
    }
    ticker = createTicker((elapsed) {
      final dt = math.min(
        .05,
        math.max(0.0, (elapsed - last).inMicroseconds / 1000000),
      );
      last = elapsed;
      if (paused) return;
      localTime += (dt * 1000).round();
      sim.tick(
        dt,
        sim.online
            ? DateTime.now().millisecondsSinceEpoch + sim.clockOffset
            : localTime,
      );
      if (sim.online && sim.status == 'ready' && !readySent) {
        readySent = true;
        BomberNetwork.request('ready', room: widget.room).catchError((e) {
          if (mounted) {
            setState(
              () =>
                  message = 'No se pudo confirmar la partida. Vuelve al menú.',
            );
          }
          return <String, dynamic>{};
        });
      }
      if (localTime - hudAt > 180 || sim.finished) {
        while (_paidCoins < sim.coins) {
          _paidCoins += 5;
          unawaited(
            widget.store.rewardGameCoins(
              'bomber:$_rewardId:${sim.localId}:coin:$_paidCoins',
              5,
            ),
          );
        }
        if (!_paidWin &&
            sim.finished &&
            objectMap(sim.state['result'])['winner'] == sim.localId) {
          _paidWin = true;
          unawaited(
            widget.store
                .rewardGameCoins('bomber:$_rewardId:${sim.localId}:win', 150)
                .then((_) async {
                  for (final count in [5, 10]) {
                    if (widget.store.bomberWins >= count) {
                      await widget.store.unlockAchievement('bomber:$count');
                    }
                  }
                }),
          );
        }
        hudAt = localTime;
        if (mounted) setState(() {});
        if (sim.finished) ticker.stop();
      }
    })..start();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    sim.input = Offset.zero;
    keys.clear();
    paused = state != AppLifecycleState.resumed && !sim.online;
  }

  bool _leaving = false, _exitCompleted = false;

  Future<void> _exit() async {
    if (_leaving) return;
    setState(() {
      _leaving = true;
      message = 'Cerrando la partida…';
    });
    sim.input = Offset.zero;
    keys.clear();
    ticker.stop();
    if (network != null) {
      try {
        // Release the server assignment before the menu can start another match.
        await BomberNetwork.request('leave', room: widget.room);
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _leaving = false;
          message = 'No se pudo cerrar la sala. Intenta salir de nuevo.';
        });
        ticker.start();
        return;
      }
      await network!.close();
    }
    if (!mounted) return;
    setState(() => _exitCompleted = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.pop(context);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    ticker.dispose();
    focus.dispose();
    if (network != null) {
      unawaited(network!.close());
      if (!_exitCompleted && !sim.finished) {
        unawaited(
          BomberNetwork.request(
            'leave',
            room: widget.room,
          ).catchError((_) => <String, dynamic>{}),
        );
      }
    }
    sim.dispose();
    super.dispose();
  }

  Future<void> bomb() async {
    if (paused || bombBusy || !sim.canBomb(sim.localId) || sim.finished) return;
    HapticFeedback.lightImpact();
    if (network == null) {
      sim.place(sim.localId);
      return;
    }
    bombBusy = true;
    try {
      await network!.bomb();
    } catch (e) {
      if (mounted) {
        setState(() => message = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      bombBusy = false;
    }
  }

  void keyboard(KeyEvent event) {
    final key = event.logicalKey;
    if (event is KeyUpEvent) {
      keys.remove(key);
    } else {
      keys.add(key);
    }
    if (key == LogicalKeyboardKey.space && event is KeyDownEvent) {
      bomb();
      return;
    }
    bool held(LogicalKeyboardKey a, LogicalKeyboardKey b) =>
        keys.contains(a) || keys.contains(b);
    sim.input = Offset(
      (held(LogicalKeyboardKey.arrowRight, LogicalKeyboardKey.keyD) ? 1 : 0) -
          (held(LogicalKeyboardKey.arrowLeft, LogicalKeyboardKey.keyA) ? 1 : 0)
              .toDouble(),
      (held(LogicalKeyboardKey.arrowDown, LogicalKeyboardKey.keyS) ? 1 : 0) -
          (held(LogicalKeyboardKey.arrowUp, LogicalKeyboardKey.keyW) ? 1 : 0)
              .toDouble(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final arena =
            bomberArenas[valueNum(sim.board['mapId']).toInt().clamp(0, 3)],
        stats = sim.stats(sim.localId),
        result = objectMap(sim.state['result']),
        winner = result['winner'],
        won = winner == sim.localId,
        draw = winner == 'draw';
    final rival = objectMap(sim.members[sim.rival]);
    return PopScope(
      canPop: _exitCompleted,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) unawaited(_exit());
      },
      child: KeyboardListener(
        focusNode: focus,
        autofocus: true,
        onKeyEvent: keyboard,
        child: Scaffold(
          backgroundColor: arena.background,
          appBar: AppBar(
            backgroundColor: arena.background,
            foregroundColor: Colors.white,
            title: Text(arena.name, style: const TextStyle(fontSize: 17)),
            actions: [
              IconButton(
                tooltip: 'Cómo jugar',
                icon: const Icon(Icons.help_outline),
                onPressed: () async {
                  sim.input = Offset.zero;
                  if (!sim.online) paused = true;
                  await showDialog<void>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Escapa antes del ¡pum!'),
                      content: const Text(
                        'Desliza en el control izquierdo para moverte. Recoge monedas de 5 en los caminos libres; ganar entrega 150 monedas. Usa la bomba a la derecha y corre: explota en 2,8 segundos. Las paredes frenan el fuego, las cajas esconden seis poderes. En computadora: flechas o WASD y espacio.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Listo'),
                        ),
                      ],
                    ),
                  );
                  if (mounted) paused = false;
                },
              ),
            ],
          ),
          body: SafeArea(
            top: false,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.pets, color: Colors.white70, size: 18),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          sim.online
                              ? (rival['name'] == null
                                    ? 'Buscando rival…'
                                    : 'vs. ${rival['name']}')
                              : 'vs. Michi IA',
                          style: const TextStyle(color: Colors.white70),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '${sim.remaining ~/ 60}:${(sim.remaining % 60).toString().padLeft(2, '0')}',
                        style: TextStyle(
                          color: arena.accent,
                          fontSize: 23,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 14,
                    runSpacing: 4,
                    children: [
                      Text(
                        '🪙 ${sim.coins}',
                        style: const TextStyle(color: Color(0xffffd45c)),
                      ),
                      Text(
                        'Bombas ${stats['maxBombs'] ?? 1}',
                        style: const TextStyle(color: Colors.white),
                      ),
                      Text(
                        'Alcance ${stats['range'] ?? 2}',
                        style: const TextStyle(color: Colors.white),
                      ),
                      Text(
                        '${valueNum(stats['speed'], 1).toStringAsFixed(2)}×',
                        style: const TextStyle(color: Colors.white),
                      ),
                      if (stats['paw'] == true)
                        const Icon(Icons.pets, color: Colors.white, size: 18),
                      if (valueNum(stats['shieldUntil']) > sim.now)
                        const Text(
                          'Escudo',
                          style: TextStyle(color: Colors.white),
                        ),
                      if (valueNum(stats['boxUntil']) > sim.now)
                        const Text(
                          'Fantasma',
                          style: TextStyle(color: Colors.white),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final width = math.min(
                        constraints.maxWidth - 20,
                        constraints.maxHeight * sim.columns / sim.rows,
                      );
                      return Center(
                        child: SizedBox(
                          width: width,
                          height: width * sim.rows / sim.columns,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                CustomPaint(painter: BomberBoardPainter(sim)),
                                if (sim.state.isEmpty ||
                                    sim.status == 'waiting' ||
                                    sim.status == 'ready' ||
                                    sim.status == 'settling' ||
                                    sim.countdown > 0)
                                  Container(
                                    color: arena.background.withValues(
                                      alpha: .7,
                                    ),
                                    child: Center(
                                      child: Padding(
                                        padding: const EdgeInsets.all(20),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(
                                              Icons.pets,
                                              color: Colors.white,
                                              size: 40,
                                            ),
                                            const SizedBox(height: 12),
                                            Text(
                                              sim.countdown > 0 &&
                                                      sim.status == 'playing'
                                                  ? '${sim.countdown}'
                                                  : sim.status == 'waiting'
                                                  ? 'Esperando a otro gatito…'
                                                  : sim.status == 'settling'
                                                  ? 'Resolviendo la explosión…'
                                                  : 'Preparando la arena…',
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                fontSize: sim.countdown > 0
                                                    ? 50
                                                    : 22,
                                                color: arena.accent,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            if (sim.status == 'waiting')
                                              const Padding(
                                                padding: EdgeInsets.only(
                                                  top: 12,
                                                ),
                                                child: Text(
                                                  'La búsqueda dura hasta un minuto. Puedes cancelar con la flecha de volver.',
                                                  textAlign: TextAlign.center,
                                                  style: TextStyle(
                                                    color: Colors.white70,
                                                    fontSize: 13,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                if (sim.finished)
                                  Container(
                                    color: arena.background.withValues(
                                      alpha: .85,
                                    ),
                                    child: Center(
                                      child: Padding(
                                        padding: const EdgeInsets.all(22),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              draw
                                                  ? Icons.handshake_rounded
                                                  : won
                                                  ? Icons.emoji_events_rounded
                                                  : Icons.favorite_rounded,
                                              size: 62,
                                              color: arena.accent,
                                            ),
                                            const SizedBox(height: 14),
                                            Text(
                                              draw
                                                  ? '¡Empate de patitas!'
                                                  : won
                                                  ? '¡Miau victoria! +150 monedas'
                                                  : '¡Una escapada más!',
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                color: arena.accent,
                                                fontSize: 25,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                            const SizedBox(height: 12),
                                            const Text(
                                              'Cada bomba enseña un camino nuevo.',
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                color: Colors.white70,
                                              ),
                                            ),
                                            const SizedBox(height: 22),
                                            FilledButton.icon(
                                              onPressed: _leaving
                                                  ? null
                                                  : _exit,
                                              icon: const Icon(Icons.pets),
                                              label: const Text(
                                                'Elegir otra arena',
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                if (network != null)
                  ValueListenableBuilder(
                    valueListenable: network!.connection,
                    builder: (context, value, _) => value.isEmpty
                        ? const SizedBox(height: 4)
                        : Padding(
                            padding: const EdgeInsets.all(4),
                            child: Text(
                              value,
                              style: const TextStyle(
                                color: Colors.amber,
                                fontSize: 12,
                              ),
                            ),
                          ),
                  ),
                if (message.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      message,
                      style: const TextStyle(color: Colors.amber, fontSize: 12),
                    ),
                  ),
                if (!sim.finished)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        BomberJoystick(
                          onChanged: (v) => sim.input = v,
                          color: arena.accent,
                        ),
                        Expanded(
                          child: Column(
                            children: [
                              Text(
                                'Escapa del fuego',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: arena.accent,
                                  fontSize: 11,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                '2,8 segundos',
                                style: TextStyle(
                                  color: Colors.white54,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Semantics(
                          button: true,
                          label: 'Colocar bomba',
                          child: Listener(
                            onPointerDown: (_) => bomb(),
                            child: Container(
                              key: const ValueKey('bomber-bomb'),
                              width: 88,
                              height: 88,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: sim.canBomb(sim.localId)
                                      ? [
                                          arena.accent,
                                          Color.lerp(
                                            arena.accent,
                                            Colors.orange,
                                            .5,
                                          )!,
                                        ]
                                      : [
                                          Colors.blueGrey,
                                          Colors.blueGrey.shade700,
                                        ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: arena.accent.withValues(alpha: .14),
                                    blurRadius: 20,
                                    offset: const Offset(0, 5),
                                  ),
                                ],
                                border: Border.all(
                                  color: Colors.white30,
                                  width: 3,
                                ),
                              ),
                              child: const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 34,
                                    height: 34,
                                    child: CustomPaint(
                                      painter: BomberBombSymbol(),
                                    ),
                                  ),
                                  Text(
                                    'BOMBA',
                                    style: TextStyle(
                                      color: Color(0xff293341),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class BomberJoystick extends StatefulWidget {
  const BomberJoystick({
    super.key,
    required this.onChanged,
    required this.color,
  });
  final ValueChanged<Offset> onChanged;
  final Color color;
  @override
  State<BomberJoystick> createState() => _BomberJoystickState();
}

class _BomberJoystickState extends State<BomberJoystick>
    with WidgetsBindingObserver {
  int? pointer;
  Offset origin = const Offset(60, 60), knob = Offset.zero;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && pointer != null) end(pointer!);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void update(Offset at) {
    final delta = at - origin;
    setState(
      () => knob = delta.distance > 36 ? delta / delta.distance * 36 : delta,
    );
    widget.onChanged(knob.distance < 5 ? Offset.zero : knob / 36);
  }

  void end(int id) {
    if (pointer != id) return;
    pointer = null;
    setState(() => knob = Offset.zero);
    widget.onChanged(Offset.zero);
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Control de movimiento',
    child: Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (e) {
        if (pointer != null) return;
        pointer = e.pointer;
        origin = Offset(
          e.localPosition.dx.clamp(42.0, 78.0),
          e.localPosition.dy.clamp(42.0, 78.0),
        );
        update(e.localPosition);
      },
      onPointerMove: (e) {
        if (e.pointer == pointer) update(e.localPosition);
      },
      onPointerUp: (e) => end(e.pointer),
      onPointerCancel: (e) => end(e.pointer),
      child: SizedBox(
        key: const ValueKey('bomber-joystick'),
        width: 120,
        height: 120,
        child: Stack(
          children: [
            Positioned(
              left: origin.dx - 44,
              top: origin.dy - 44,
              child: Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: .07),
                  border: Border.all(color: Colors.white24, width: 2),
                ),
                child: const Icon(
                  Icons.open_with_rounded,
                  color: Colors.white24,
                  size: 56,
                ),
              ),
            ),
            Positioned(
              left: origin.dx + knob.dx - 22,
              top: origin.dy + knob.dy - 22,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.color,
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 6,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.pets,
                  color: Color(0xff31423f),
                  size: 25,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
