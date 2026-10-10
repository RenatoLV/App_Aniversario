import 'package:flutter/material.dart';
import '../store.dart';
import '../game_audio.dart';
import 'mz_catalog.dart';
import 'mz_levels.dart';
import 'mz_progress.dart';
import 'mz_simulation.dart';
import 'mz_game_screen.dart';
import 'mz_widgets.dart';
import 'mz_art_style.dart';
import 'mz_menu_art.dart';
import 'mz_almanac.dart';

const mzCream = Color(0xfffff6df), mzGreen = Color(0xff385d45);

class MarusZombiesScreen extends StatefulWidget {
  const MarusZombiesScreen({super.key, required this.store});
  final GameStore store;
  @override
  State<MarusZombiesScreen> createState() => _MarusZombiesScreenState();
}

class _MarusZombiesScreenState extends State<MarusZombiesScreen> {
  late final MzProgress progress;
  late final bool previousRestore;
  int world = 0;
  bool busy = false;
  String? error;
  @override
  void initState() {
    super.initState();
    progress = MzProgress(widget.store.prefs);
    previousRestore = widget.store.cloud.allowRestore;
    widget.store.cloud.allowRestore = false;
    world = progress.highest == 10 && progress.cemeteryHighest < 10
        ? MzWorld.cemetery.index
        : (progress.highest ~/ 10).clamp(0, 4);
    GameAudio.instance.enter('marus-zombies');
    WidgetsBinding.instance.addPostFrameCallback((_) => _recover());
  }

  Future<void> _recover() async {
    try {
      await progress.recoverIncompatible();
      await _rewardWorlds();
      if (mounted) setState(() => error = progress.recovery);
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    }
  }

  Future<void> _rewardWorlds() async {
    for (final w in progress.pendingWorlds.toList()) {
      await widget.store.rewardGameCoins(
        'mz:world:$w:first-clear',
        w == MzWorld.cemetery.index ? 200 : 150 + w * 50,
      );
      await widget.store.save();
      if (widget.store.saveError != null) {
        throw StateError(widget.store.saveError!);
      }
      await progress.acknowledgeWorld(w);
    }
  }

  @override
  void dispose() {
    widget.store.cloud.allowRestore = previousRestore;
    GameAudio.instance.enter('menu');
    super.dispose();
  }

  Future<void> _open(MzSimulation sim) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await progress.checkpoint(sim);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          settings: const RouteSettings(name: '/marus-zombies/play'),
          builder: (_) => MzGameScreen(sim: sim, progress: progress),
        ),
      );
      await _rewardWorlds();
      await widget.store.cloud.sync();
    } catch (e) {
      error = '$e';
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _prepare(MzLevel level) async {
    if (busy) return;
    if (progress.run != null) {
      final discard = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Hay una partida suspendida'),
          content: const Text(
            'Comenzar esta misión reemplazará esa partida. Las galletitas ya usadas se conservan como gastos.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Volver'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Nueva partida'),
            ),
          ],
        ),
      );
      if (discard != true || !mounted) return;
    }
    final choices = level.allowed;
    final chosen = progress.deck.where(choices.contains).take(6).toList();
    for (final cat in choices) {
      if (chosen.length >= 6) break;
      if (!chosen.contains(cat)) chosen.add(cat);
    }
    final deck = await showDialog<List<MzCat>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          backgroundColor: mzCream,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: MzArt.wood, width: 3),
          ),
          title: Text(
            level.title,
            style: const TextStyle(
              fontFamily: 'Fredoka',
              fontWeight: FontWeight.w700,
              color: mzGreen,
            ),
          ),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  MzWorldPostcard(
                    level.world.index,
                    height: MediaQuery.sizeOf(context).height < 500 ? 28 : 56,
                  ),
                  const SizedBox(height: 12),
                  Text('Tu equipo · ${chosen.length}/6'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final cat in choices)
                        Semantics(
                          button: true,
                          selected: chosen.contains(cat),
                          label:
                              '${mzCats[cat]!.name}, ${mzCats[cat]!.cost} de hierba',
                          child: InkWell(
                            key: ValueKey('mz-deck-${cat.name}'),
                            onTap: () => update(() {
                              if (chosen.contains(cat)) {
                                chosen.remove(cat);
                              } else if (chosen.length < 6) {
                                chosen.add(cat);
                              }
                            }),
                            child: SizedBox(
                              width: MediaQuery.sizeOf(context).height < 500
                                  ? 66
                                  : 84,
                              height: MediaQuery.sizeOf(context).height < 500
                                  ? 84
                                  : 112,
                              child: FittedBox(
                                child: MzSeedCard(
                                  cat: cat,
                                  selected: chosen.contains(cat),
                                  reducedMotion: progress.reducedMotion,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(level.world.rule),
                  const SizedBox(height: 12),
                  Text(
                    'Enemigos: ${level.enemies.map((e) => e.label).join(', ')}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 10),
                  for (final objective in [
                    'Gana',
                    'Conserva las Roombas',
                    level.objective,
                  ])
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          color: Color(0xff99702c),
                          size: 20,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            objective,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 14),
                  const SizedBox(height: 12),
                  const Text(
                    'Toca una tarjeta y una casilla. La hierba amarilla se recoge tocándola. Cada Roomba salva una fila una sola vez.',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: mzGreen,
                minimumSize: const Size(48, 48),
              ),
              onPressed: () => Navigator.pop(context),
              child: const Text('Volver'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: mzGreen,
                foregroundColor: mzCream,
                minimumSize: const Size(48, 48),
                side: const BorderSide(color: MzArt.wood, width: 2),
              ),
              onPressed: chosen.isEmpty
                  ? null
                  : () => Navigator.pop(context, [...chosen]),
              child: const Text('¡Defender el jardín!'),
            ),
          ],
        ),
      ),
    );
    if (deck == null || !mounted) return;
    try {
      await progress.abandon();
      if (level.mode != MzMode.challenge) await progress.configure(deck: deck);
      await _open(
        MzSimulation(level, deck: deck)..autoCollect = progress.autoCollect,
      );
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    }
  }

  void _almanac() {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        settings: const RouteSettings(name: '/marus-zombies/almanac'),
        builder: (_) => MzAlmanacScreen(progress: progress),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        colorScheme: ColorScheme.fromSeed(seedColor: mzGreen, surface: mzCream),
        chipTheme: ChipThemeData(
          backgroundColor: MzArt.paper,
          selectedColor: const Color(0xffd9e9b5),
          disabledColor: const Color(0xffe0d9c9),
          side: const BorderSide(color: MzArt.wood, width: 2),
          labelStyle: const TextStyle(
            fontFamily: 'Nunito',
            color: mzGreen,
            fontWeight: FontWeight.w800,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        ),
      ),
      child: Scaffold(
        backgroundColor: mzCream,
        appBar: AppBar(
          backgroundColor: mzCream,
          title: const Text('Marus vs Zombies'),
          actions: [
            IconButton(
              tooltip: 'Almanaque',
              onPressed: _almanac,
              icon: const Icon(Icons.menu_book_rounded),
            ),
          ],
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 980),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: mzHudDecoration(badge: true),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'UN JARDÍN. MUCHOS MICHIS.',
                        style: TextStyle(
                          color: Color(0xffd2e5a8),
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '¡Que nadie toque\nla casa de Maru!',
                        style: TextStyle(
                          fontFamily: 'Fredoka',
                          fontSize: 34,
                          height: 1.08,
                          color: mzCream,
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Recluta gatos, recoge hierba gatera y detén la horda. Cinco mundos de aventuras desde el patio.',
                        style: TextStyle(color: Color(0xffe1ebcb)),
                      ),
                      const SizedBox(height: 12),
                      MzWorldPostcard(world, height: 82, heroes: true),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    Chip(
                      avatar: const Icon(Icons.cookie_outlined),
                      label: Text('${progress.cookies} galletitas'),
                    ),
                    Chip(
                      avatar: const Icon(Icons.spa_outlined),
                      label: Text('${progress.mints} mentitas'),
                    ),
                    Chip(
                      label: Text(
                        '${progress.stars.values.fold<int>(0, (sum, value) => sum + (value as int))} estrellas',
                      ),
                    ),
                  ],
                ),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Text(
                      error!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                if (progress.run != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: FilledButton.icon(
                      key: const ValueKey('mz-resume'),
                      onPressed: busy
                          ? null
                          : () {
                              final sim = progress.resume();
                              if (sim != null) _open(sim);
                            },
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: const Text('Retomar partida suspendida'),
                    ),
                  ),
                const SizedBox(height: 14),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final w in mzWorldOrder)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            avatar: Icon(
                              !progress.worldUnlocked(w)
                                  ? Icons.lock_rounded
                                  : mzWorldIcons[w.index],
                              size: 20,
                            ),
                            label: Text(
                              '${mzWorldOrder.indexOf(w) + 1}. ${w.title}',
                            ),
                            selected: world == w.index,
                            onSelected: !progress.worldUnlocked(w) || busy
                                ? null
                                : (_) => setState(() => world = w.index),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  MzWorld.values[world].rule,
                  style: const TextStyle(color: mzGreen),
                ),
                const SizedBox(height: 16),
                LayoutBuilder(
                  builder: (context, constraints) => Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      for (final level in mzLevelsForWorld(
                        MzWorld.values[world],
                      ))
                        SizedBox(
                          width: (constraints.maxWidth - 24) / 3,
                          child: _levelTile(level.id),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Más aventuras',
                  style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.wb_sunny_outlined, color: mzGreen),
                  title: const Text('Desafío del día'),
                  subtitle: const Text(
                    'Equipo prestado. Sin poderes de pago. +100 galletitas y 5 mentitas por primera victoria.',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: busy
                      ? null
                      : () {
                          final now = DateTime.now();
                          final seed =
                              now.year * 10000 + now.month * 100 + now.day;
                          _prepare(
                            MzLevel(
                              world * 10 + 7,
                              mode: MzMode.challenge,
                              seed: seed,
                            ),
                          );
                        },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.all_inclusive, color: mzGreen),
                  title: const Text('Supervivencia'),
                  subtitle: Text(
                    'Récord: ${progress.survivalBest} oleadas. Premios por cada cinco oleadas nuevas.',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: busy
                      ? null
                      : () => _prepare(
                          MzLevel(world * 10 + 9, mode: MzMode.survival),
                        ),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.auto_awesome, color: mzGreen),
                  title: const Text('Gran León Mítico'),
                  subtitle: Text(
                    progress.lion
                        ? 'Desbloqueado · una invocación por partida.'
                        : '100 mentitas · completa el mundo pirata para invocarlo.',
                  ),
                  trailing: progress.lion
                      ? const Icon(Icons.check)
                      : TextButton(
                          onPressed:
                              progress.mints >= 100 &&
                                  progress.highest >= 30 &&
                                  !busy
                              ? () async {
                                  await progress.unlockLion();
                                  if (mounted) setState(() {});
                                }
                              : null,
                          child: const Text('Invocar'),
                        ),
                ),
                const Divider(),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Recoger hierba automáticamente'),
                  value: progress.autoCollect,
                  onChanged: (v) async {
                    await progress.configure(auto: v);
                    if (mounted) setState(() {});
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Reducir movimiento y destellos'),
                  value: progress.reducedMotion,
                  onChanged: (v) async {
                    await progress.configure(reduced: v);
                    if (mounted) setState(() {});
                  },
                ),
                const SizedBox(height: 12),
                const Text(
                  'Todo el progreso se guarda en este dispositivo. Si inicias sesión, se sincroniza con tu cuenta.',
                  style: TextStyle(fontSize: 12, color: mzGreen),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _levelTile(int id) {
    final unlocked = progress.levelUnlocked(MzLevel(id)),
        stars = progress.stars['$id'] as int? ?? 0;
    return Container(
      decoration: mzHudDecoration(badge: unlocked),
      child: InkWell(
        key: ValueKey('mz-level-$id'),
        borderRadius: BorderRadius.circular(14),
        onTap: unlocked && !busy ? () => _prepare(MzLevel(id)) : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 5),
          child: Column(
            children: [
              Icon(
                unlocked
                    ? (id % 10 == 9 ? Icons.flag_rounded : Icons.grass_rounded)
                    : Icons.lock_outline,
                color: unlocked ? MzArt.gold : MzArt.paper,
              ),
              const SizedBox(height: 5),
              Text(
                'Nivel ${id % 10 + 1}',
                style: const TextStyle(
                  fontFamily: 'Fredoka',
                  fontWeight: FontWeight.w900,
                  color: MzArt.paper,
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < 3; i++)
                    Icon(
                      i < stars
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      size: 22,
                      color: MzArt.gold,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
