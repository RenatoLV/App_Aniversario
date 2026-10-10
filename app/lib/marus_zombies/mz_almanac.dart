import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'mz_catalog.dart';
import 'mz_character_art.dart';
import 'mz_levels.dart';
import 'mz_progress.dart';

/// Derived from the existing unlock function, not a second progression table.
int mzAlmanacRequirement(MzCat cat) {
  for (var completed = 0; completed <= mzCampaign.length; completed++) {
    if (mzUnlockedCats(completed).contains(cat)) return completed;
  }
  throw StateError('No unlock requirement for $cat');
}

class _Entry {
  const _Entry.cat(this.cat) : enemy = null, ancestral = false;
  const _Entry.enemy(this.enemy) : cat = null, ancestral = false;
  const _Entry.lion() : cat = null, enemy = null, ancestral = true;
  final MzCat? cat;
  final MzEnemy? enemy;
  final bool ancestral;
  String get id => cat != null
      ? 'cat-${cat!.name}'
      : enemy != null
      ? 'enemy-${enemy!.name}'
      : 'lion';
  String get name =>
      cat != null ? mzCats[cat]!.name : enemy?.label ?? 'Gran León · Maru';
  String get role => cat != null
      ? const [
          'Ataque de carril',
          'Productor de hierba',
          'Barrera resistente',
          'Ataque de hielo',
          'Trampa de contacto',
          'Explosión en área',
          'Ataque catapultado',
          'Ataque de ida y vuelta',
          'Empuje elástico',
          'Electricidad en cadena',
          'Haz continuo',
        ][cat!.index]
      : enemy?.role ?? 'Invocación ancestral';
  int get requirement => cat != null
      ? mzAlmanacRequirement(cat!)
      : ancestral
      ? 30
      : mzCampaign.firstWhere((l) => l.enemies.contains(enemy)).id;
  MzWorld get world => ancestral
      ? MzWorld.pirates
      : cat != null
      ? MzLevel(math.max(0, requirement - 1)).world
      : MzLevel(requirement).world;
  bool unlocked(MzProgress p) => cat != null
      ? mzUnlockedCats(p.highest).contains(cat)
      : !ancestral || p.lion;
  bool equipped(MzProgress p) =>
      cat != null && unlocked(p) && p.deck.contains(cat);
  int get campaignRequirement =>
      requirement == 0 ? 0 : mzCampaignNumber(requirement - 1);
  Color get accent => ancestral
      ? const Color(0xffd88a2e)
      : enemy != null
      ? const Color(0xff8a9aba)
      : const [
          Color(0xff6caa42),
          Color(0xffe9ac32),
          Color(0xffac854b),
          Color(0xff60bdd0),
          Color(0xffc49565),
          Color(0xffde765e),
          Color(0xffc3a342),
          Color(0xff58aeb1),
          Color(0xff93a950),
          Color(0xffc6ae48),
          Color(0xff54bba1),
        ][cat!.index];
  IconData get icon => ancestral
      ? Icons.auto_awesome
      : enemy != null
      ? switch (enemy!) {
          MzEnemy.pianist => Icons.music_note,
          MzEnemy.mecha || MzEnemy.shield || MzEnemy.boss => Icons.settings,
          MzEnemy.mummy || MzEnemy.pharaoh => Icons.account_balance,
          MzEnemy.corsair || MzEnemy.parrot || MzEnemy.cannon => Icons.sailing,
          _ => Icons.pets,
        }
      : switch (cat!) {
          MzCat.sunflower => Icons.wb_sunny,
          MzCat.ice => Icons.ac_unit,
          MzCat.lightning => Icons.bolt,
          MzCat.barrier => Icons.shield,
          MzCat.bomb => Icons.flare,
          _ => Icons.pets,
        };
}

final _defenders = [for (final cat in MzCat.values) _Entry.cat(cat)];
final _invaders = [for (final enemy in MzEnemy.values) _Entry.enemy(enemy)];
const _lion = _Entry.lion();
const _ink = Color(0xff302e28), _paper = Color(0xfffff1cc);

/// Read-only collection; team editing remains in the existing mission preparation.
class MzAlmanacScreen extends StatefulWidget {
  const MzAlmanacScreen({super.key, required this.progress, this.initialCat});
  final MzProgress progress;
  final MzCat? initialCat;
  static const seenKey = 'marusZombies.almanacSeen.v1';
  @override
  State<MzAlmanacScreen> createState() => _MzAlmanacScreenState();
}

class _MzAlmanacScreenState extends State<MzAlmanacScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _idle;
  final _scroll = ScrollController();
  final _detailScroll = ScrollController();
  _Entry _selected = _defenders.first;
  bool _enemies = false, _reduce = false;
  MzWorld? _world;
  final _newCards = <String>{};
  MzProgress get p => widget.progress;
  @override
  void initState() {
    super.initState();
    _idle = AnimationController(
      vsync: this,
      duration: const Duration(hours: 24),
    );
    final unlocked = [
      for (final e in [..._defenders, _lion])
        if (e.unlocked(p)) e.id,
    ];
    final seen = p.prefs.getStringList(MzAlmanacScreen.seenKey);
    // First visit establishes a baseline. Never claim existing cards are new.
    if (seen != null) {
      _newCards.addAll(unlocked.where((id) => !seen.contains(id)));
      if (_newCards.isNotEmpty) {
        _selected = [
          ..._defenders,
          _lion,
        ].firstWhere((e) => _newCards.contains(e.id));
      }
    }
    if (widget.initialCat != null) {
      _selected = _defenders.firstWhere((e) => e.cat == widget.initialCat);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(
          p.prefs.setStringList(
            MzAlmanacScreen.seenKey,
            {...?seen, ...unlocked}.toList(),
          ),
        );
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduce =
        p.reducedMotion ||
        MediaQuery.disableAnimationsOf(context) ||
        MediaQuery.accessibleNavigationOf(context);
    _animate();
  }

  void _animate() {
    if (_reduce || !_selected.unlocked(p)) {
      _idle.stop();
    } else if (!_idle.isAnimating) {
      _idle.repeat();
    }
  }

  void _select(_Entry e) {
    setState(() => _selected = e);
    _animate();
    if (_detailScroll.hasClients) _detailScroll.jumpTo(0);
    if ((MediaQuery.sizeOf(context).width < 760 ||
            MediaQuery.textScalerOf(context).scale(16) / 16 >= 1.6) &&
        _scroll.hasClients) {
      if (_reduce) {
        _scroll.jumpTo(0);
      } else {
        _scroll.animateTo(
          0,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
        );
      }
    }
  }

  @override
  void dispose() {
    _idle.dispose();
    _scroll.dispose();
    _detailScroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final team = p.deck
        .where((c) => mzUnlockedCats(p.highest).contains(c))
        .length;
    final entries = (_enemies ? _invaders : _defenders)
        .where((e) => _world == null || e.world == _world)
        .toList();
    final count = mzUnlockedCats(p.highest).length;
    final scale = MediaQuery.textScalerOf(context).scale(16) / 16;
    return Theme(
      data: Theme.of(context).copyWith(
        textTheme: Theme.of(context).textTheme.apply(fontFamily: 'Nunito'),
        primaryTextTheme: Theme.of(
          context,
        ).primaryTextTheme.apply(fontFamily: 'Nunito'),
      ),
      child: Scaffold(
        backgroundColor: const Color(0xff263e35),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1500),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 8, 4),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.menu_book_rounded,
                          color: Color(0xffffcf76),
                          size: 28,
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'Almanaque de los michis',
                            style: TextStyle(
                              fontFamily: 'Fredoka',
                              fontSize: 24,
                              color: _paper,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Cerrar almanaque',
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close_rounded, color: _paper),
                          constraints: const BoxConstraints(
                            minWidth: 48,
                            minHeight: 48,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    child: Row(
                      children: [
                        Expanded(child: _tab('Defensores · 11', false)),
                        const SizedBox(width: 10),
                        Expanded(child: _tab('Invasores · 15', true)),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 6,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _enemies
                              ? 'Bestiario · 15 fichas de consulta libre'
                              : 'Colección · $count/11 gatos     Equipo guardado · $team/6',
                          style: const TextStyle(
                            color: _paper,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (!_enemies)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Semantics(
                              label:
                                  'Colección de gatos: $count de 11 desbloqueados',
                              child: TweenAnimationBuilder<double>(
                                tween: Tween(
                                  begin:
                                      (count -
                                          _newCards
                                              .where(
                                                (id) => id.startsWith('cat-'),
                                              )
                                              .length) /
                                      11,
                                  end: count / 11,
                                ),
                                duration: Duration(
                                  milliseconds: _reduce ? 0 : 350,
                                ),
                                builder: (context, value, _) => ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: LinearProgressIndicator(
                                    value: value,
                                    minHeight: 8,
                                    color: const Color(0xffb9db69),
                                    backgroundColor: const Color(0xff152d25),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  SizedBox(
                    height: 48,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: [
                        for (final w in [null, ...mzWorldOrder])
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: FilterChip(
                              label: Text(w?.title ?? 'Todos los mundos'),
                              selected: _world == w,
                              backgroundColor: _paper,
                              selectedColor: const Color(0xffffcc77),
                              onSelected: (_) => setState(() => _world = w),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, c) {
                        final wide = c.maxWidth >= 760 && scale < 1.6;
                        final detail = AnimatedSwitcher(
                          duration: Duration(milliseconds: _reduce ? 0 : 220),
                          child: _detail(
                            _selected,
                            key: ValueKey('detail-${_selected.id}'),
                            compact: !wide,
                          ),
                        );
                        if (wide) {
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 6,
                                child: _collection(
                                  entries,
                                  c.maxWidth * .55,
                                  scale,
                                ),
                              ),
                              Expanded(
                                flex: 5,
                                child: SingleChildScrollView(
                                  controller: _detailScroll,
                                  key: const ValueKey('almanac-detail-scroll'),
                                  padding: const EdgeInsets.fromLTRB(
                                    4,
                                    12,
                                    18,
                                    24,
                                  ),
                                  child: detail,
                                ),
                              ),
                            ],
                          );
                        }
                        return CustomScrollView(
                          controller: _scroll,
                          slivers: [
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  14,
                                  12,
                                  14,
                                  20,
                                ),
                                child: detail,
                              ),
                            ),
                            ..._cards(entries, c.maxWidth, scale),
                          ],
                        );
                      },
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

  Widget _tab(String label, bool enemies) => Semantics(
    selected: _enemies == enemies,
    child: FilledButton.icon(
      key: ValueKey(enemies ? 'almanac-invaders' : 'almanac-defenders'),
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 48),
        backgroundColor: _enemies == enemies
            ? (enemies ? const Color(0xffaebcde) : const Color(0xffffc76b))
            : const Color(0xff476254),
        foregroundColor: _enemies == enemies ? _ink : _paper,
        side: BorderSide(
          color: _enemies == enemies
              ? const Color(0xfffce8ad)
              : const Color(0xff718572),
          width: 2,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onPressed: () {
        setState(() {
          _enemies = enemies;
          _world = null;
          _selected = enemies ? _invaders.first : _defenders.first;
        });
        _animate();
        if (_detailScroll.hasClients) _detailScroll.jumpTo(0);
        if (_scroll.hasClients) _scroll.jumpTo(0);
      },
      icon: Icon(enemies ? Icons.nightlight_round : Icons.local_florist),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.w900)),
    ),
  );
  Widget _collection(List<_Entry> entries, double width, double scale) =>
      CustomScrollView(slivers: _cards(entries, width, scale));
  List<Widget> _cards(List<_Entry> entries, double width, double scale) => [
    SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
        child: Text(
          _enemies ? 'CONOCE A LA HORDA' : 'TU COLECCIÓN',
          style: const TextStyle(
            color: _paper,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
          ),
        ),
      ),
    ),
    if (entries.isEmpty)
      const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No hay cartas que se obtengan en este mundo.',
            style: TextStyle(color: _paper),
          ),
        ),
      ),
    SliverPadding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 18),
      sliver: SliverGrid(
        delegate: SliverChildBuilderDelegate(
          (context, i) => _card(entries[i]),
          childCount: entries.length,
        ),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: math.max(1, ((width - 28) / 160).floor()),
          mainAxisExtent: 190 + 70 * math.max(0, scale - 1),
          crossAxisSpacing: 12,
          mainAxisSpacing: 14,
        ),
      ),
    ),
    if (!_enemies && (_world == null || _world == _lion.world))
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 24),
          child: Semantics(
            button: true,
            selected: _selected.ancestral,
            label:
                'Gran León Maru, ancestral. ${p.lion ? 'Desbloqueado' : 'Requiere 100 mentitas y completar Piratas'}',
            child: InkWell(
              key: const ValueKey('almanac-lion'),
              onTap: () => _select(_lion),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: _frame(_lion, selected: _selected.ancestral),
                child: Row(
                  children: [
                    const Icon(Icons.auto_awesome, color: _ink, size: 32),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Gran León · Maru\nAncestral · ${p.lion ? 'Desbloqueado' : '100 mentitas + completar Piratas'}',
                        style: const TextStyle(
                          color: _ink,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    Icon(p.lion ? Icons.check_circle : Icons.lock, color: _ink),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
  ];
  BoxDecoration _frame(_Entry e, {bool selected = false}) => BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: e.enemy != null
          ? const [Color(0xffbccbda), Color(0xff7188a1)]
          : e.ancestral
          ? const [Color(0xffffdf85), Color(0xffd8933e)]
          : const [Color(0xffe8b36b), Color(0xffb77643)],
    ),
    borderRadius: BorderRadius.circular(16),
    border: Border.all(
      color: selected
          ? const Color(0xffffe782)
          : e.enemy != null
          ? const Color(0xff374453)
          : const Color(0xff67412c),
      width: selected ? 3.5 : 2.5,
    ),
    boxShadow: const [
      BoxShadow(color: Color(0xff152c24), offset: Offset(0, 4)),
    ],
  );
  Widget _card(_Entry e) {
    final unlocked = e.unlocked(p),
        equipped = e.equipped(p),
        selected = e.id == _selected.id;
    final status = !unlocked
        ? 'Bloqueada'
        : equipped
        ? 'Equipada'
        : e.enemy != null
        ? 'Ficha disponible'
        : 'Disponible';
    return Semantics(
      button: true,
      selected: selected,
      onTap: () => _select(e),
      label:
          '${e.name}, ${e.role}, $status${!unlocked ? ', completa ${e.requirement} niveles' : ''}',
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: ValueKey('almanac-${e.id}'),
          onTap: () => _select(e),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: _frame(e, selected: selected),
            child: Column(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        RepaintBoundary(
                          child: CustomPaint(painter: _Backdrop(e)),
                        ),
                        RepaintBoundary(
                          key: ValueKey('almanac-static-${e.id}'),
                          child: CustomPaint(
                            painter: _Portrait(e, silhouette: !unlocked),
                          ),
                        ),
                        Positioned(
                          top: 4,
                          left: 4,
                          child: Icon(
                            e.icon,
                            color: e.enemy != null
                                ? const Color(0xffdfe7f3)
                                : const Color(0xff605330),
                            size: 18,
                          ),
                        ),
                        Positioned(
                          top: 4,
                          right: 4,
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              color: _paper,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              !unlocked
                                  ? Icons.lock
                                  : selected
                                  ? Icons.check_circle
                                  : equipped
                                  ? Icons.check
                                  : Icons.pets,
                              color: _ink,
                              size: 17,
                            ),
                          ),
                        ),
                        if (_newCards.contains(e.id))
                          const Positioned(
                            bottom: 4,
                            right: 4,
                            child: _Badge('¡Nueva!', Icons.auto_awesome),
                          ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    e.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'Fredoka',
                      fontWeight: FontWeight.w700,
                      color: _ink,
                      fontSize: 16,
                    ),
                  ),
                ),
                Text(
                  !unlocked ? 'Completa nivel ${e.requirement}' : status,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: _ink,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _detail(_Entry e, {Key? key, bool compact = false}) {
    final unlocked = e.unlocked(p);
    final portrait = RepaintBoundary(
      key: const ValueKey('almanac-active-portrait'),
      child: CustomPaint(
        painter: _Portrait(
          e,
          silhouette: !unlocked,
          phase: _reduce ? 0 : _idle.value * 86400 * .65,
        ),
      ),
    );
    return Container(
      key: key,
      decoration: _frame(e, selected: true),
      padding: const EdgeInsets.all(9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              height: compact ? 160 : 200,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  RepaintBoundary(
                    child: CustomPaint(painter: _Backdrop(e, large: true)),
                  ),
                  if (_reduce || !unlocked)
                    portrait
                  else
                    AnimatedBuilder(
                      animation: _idle,
                      builder: (context, _) => RepaintBoundary(
                        key: const ValueKey('almanac-active-portrait'),
                        child: CustomPaint(
                          painter: _Portrait(
                            e,
                            phase: _idle.value * 86400 * .65,
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    top: 12,
                    left: 12,
                    child: _Badge(
                      e.ancestral
                          ? 'ANCESTRAL'
                          : e.enemy != null
                          ? 'INVASOR'
                          : 'DEFENSOR',
                      e.icon,
                    ),
                  ),
                  Positioned(
                    bottom: 10,
                    right: 10,
                    child: _Badge(
                      !unlocked
                          ? 'Bloqueado'
                          : e.equipped(p)
                          ? 'En tu equipo'
                          : e.enemy != null
                          ? 'Bestiario'
                          : 'Desbloqueado',
                      !unlocked
                          ? Icons.lock
                          : e.equipped(p)
                          ? Icons.check_circle
                          : Icons.pets,
                    ),
                  ),
                  if (_newCards.contains(e.id))
                    Positioned(
                      top: 45,
                      left: 12,
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: 1),
                        duration: Duration(milliseconds: _reduce ? 0 : 450),
                        builder: (context, t, child) => Transform.scale(
                          scale: .85 + .15 * Curves.easeOutBack.transform(t),
                          child: child,
                        ),
                        child: const _Badge(
                          '¡Carta nueva!',
                          Icons.auto_awesome,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _paper,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  e.name,
                  key: const ValueKey('almanac-detail-name'),
                  style: const TextStyle(
                    fontFamily: 'Fredoka',
                    fontSize: 27,
                    fontWeight: FontWeight.w700,
                    color: _ink,
                  ),
                ),
                Text(
                  e.role,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: e.enemy != null
                        ? const Color(0xff475c77)
                        : const Color(0xff365f36),
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 12),
                if (compact && !unlocked && e.cat != null)
                  Text(
                    'Completa ${MzLevel(e.requirement - 1).title} · ${p.completedToward(e.requirement - 1)}/${e.campaignRequirement} misiones del recorrido',
                    style: const TextStyle(
                      color: _ink,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                if (compact)
                  ExpansionTile(
                    key: ValueKey('almanac-information-${e.id}'),
                    tilePadding: EdgeInsets.zero,
                    title: const Text(
                      'Estadísticas y cómo conseguir',
                      style: TextStyle(
                        color: _ink,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    children: [_information(e)],
                  )
                else
                  _information(e),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _information(_Entry e) {
    final unlocked = e.unlocked(p), spec = e.cat != null ? mzCats[e.cat] : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (spec != null) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Stat('Hierba', '${spec.cost}', Icons.eco),
              _Stat(
                'Recarga',
                '${spec.cooldown.toInt()} s',
                Icons.hourglass_bottom,
              ),
              _Stat('Resistencia', '${spec.hp.toInt()}', Icons.favorite),
              _Stat('Daño base', '${spec.damage.toInt()}', Icons.bolt),
              _Stat(
                'Intervalo',
                spec.interval == 0 ? '—' : '${spec.interval} s',
                Icons.timer,
              ),
            ],
          ),
          _section('Habilidad', spec.description),
          _section('Atún premium', spec.tuna),
        ] else if (e.enemy != null) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Stat('Vida', '${e.enemy!.health.toInt()}', Icons.favorite),
              _Stat(
                'Protección',
                '${e.enemy!.protection.toInt()}',
                Icons.shield,
              ),
              _Stat('Avance', '${e.enemy!.speed} cas/s', Icons.directions_walk),
            ],
          ),
          _section('Comportamiento', _enemyAbility(e.enemy!)),
        ] else
          _section(
            'Poder ancestral',
            'Rugido de 200 de daño. Triplica el daño de Lanzadores y Bumeranes durante 15 segundos. Una invocación por partida.',
          ),
        _section(
          'Cómo conseguir',
          e.enemy != null
              ? 'Ficha de consulta libre. Primera aparición: misión ${mzCampaignNumber(e.requirement)}, ${MzLevel(e.requirement).title}.'
              : e.ancestral
              ? 'Completa el mundo pirata y gasta 100 mentitas. En «Más aventuras», pulsa «Invocar» en Gran León Mítico. Es permanente y no ocupa una de las seis cartas. Obtienes 10 mentitas al terminar cada mundo por primera vez, 5 por cada desafío diario nuevo ganado y 5 por cada hito de cinco oleadas nuevas en supervivencia.'
              : e.requirement == 0
              ? 'Disponible desde el inicio de la campaña.'
              : 'Completa ${MzLevel(e.requirement - 1).title} (misión ${e.campaignRequirement}). Se desbloquea permanentemente, sin comprar la carta.',
        ),
        if (!unlocked && e.cat != null) ...[
          Text(
            '${p.completedToward(e.requirement - 1)}/${e.campaignRequirement} misiones del recorrido completadas',
            style: const TextStyle(color: _ink, fontWeight: FontWeight.w800),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: LinearProgressIndicator(
              value:
                  (p.completedToward(e.requirement - 1) / e.campaignRequirement)
                      .clamp(0, 1),
              minHeight: 8,
              color: e.accent,
              backgroundColor: const Color(0xffded1ad),
            ),
          ),
        ],
        if (e.ancestral && !p.lion) ...[
          _requirement(
            'Niveles de Patio, Egipto y Piratas',
            math.min(p.highest, 30),
            30,
          ),
          _requirement('Mentitas', math.min(p.mints, 100), 100),
          if (p.highest >= 30 && p.mints >= 100)
            const Text(
              '¡Requisitos cumplidos! Ya puedes desbloquearlo en Más aventuras.',
              style: TextStyle(
                color: Color(0xff365f36),
                fontWeight: FontWeight.w900,
              ),
            ),
        ],
        if (e.cat != null)
          _section(
            'Equipo y combate',
            '${e.equipped(p)
                ? 'Está en tu equipo guardado.'
                : unlocked
                ? 'Disponible para tu equipo.'
                : 'Aún no puedes equiparlo.'} Elige hasta seis cartas antes de la partida. La hierba paga cada colocación y la recarga es la espera entre colocaciones; ninguna desbloquea la carta.',
          ),
      ],
    );
  }

  Widget _section(String title, String body) => Padding(
    padding: const EdgeInsets.only(top: 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontFamily: 'Fredoka',
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: _ink,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          body,
          style: const TextStyle(color: _ink, fontSize: 14, height: 1.4),
        ),
      ],
    ),
  );
  Widget _requirement(String label, int have, int need) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Row(
      children: [
        Icon(
          have >= need ? Icons.check_circle : Icons.radio_button_unchecked,
          size: 18,
          color: _ink,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '$label: $have/$need',
            style: const TextStyle(color: _ink, fontWeight: FontWeight.w800),
          ),
        ),
      ],
    ),
  );
}

String _enemyAbility(MzEnemy e) => switch (e) {
  MzEnemy.thief =>
    'Roba una burbuja de hierba de su carril cuando activa su acción especial.',
  MzEnemy.pianist =>
    'Su piano hace cambiar de carril a otros invasores cercanos cada 12 segundos.',
  MzEnemy.cannon =>
    'Marca una casilla con un defensor de su carril y dispara un hueso tras la advertencia.',
  MzEnemy.shield =>
    'Su acción especial refuerza la protección de invasores cercanos de su carril.',
  MzEnemy.parrot =>
    'Se lleva al defensor que alcanza; derrotarlo permite recuperar al gato.',
  MzEnemy.boss =>
    'Amenaza de tres fases: cambia de carril, convoca invasores y, con menos vida, añade pisotones anunciados.',
  MzEnemy.miner => 'Aparece detrás de las líneas defensoras.',
  MzEnemy.corsair => 'Entra al tablero balanceándose desde una cuerda.',
  _ =>
    'Avanza por su carril y muerde a los defensores que encuentra.${e.protection > 0 ? ' Su protección absorbe daño antes que su vida.' : ''}',
};

class _Badge extends StatelessWidget {
  const _Badge(this.label, this.icon);
  final String label;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: _paper,
      borderRadius: BorderRadius.circular(9),
      border: Border.all(color: const Color(0xffb1935d), width: 1.5),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: _ink),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            color: _ink,
            fontSize: 11,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    ),
  );
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value, this.icon);
  final String label, value;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(
      color: const Color(0xfffffbec),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: const Color(0xffd6bd82), width: 1.5),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: const Color(0xff665538)),
        const SizedBox(width: 7),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                color: _ink,
                fontSize: 17,
              ),
            ),
            Text(label, style: const TextStyle(color: _ink, fontSize: 11)),
          ],
        ),
      ],
    ),
  );
}

class _Portrait extends CustomPainter {
  const _Portrait(this.entry, {this.phase = 0, this.silhouette = false});
  final _Entry entry;
  final double phase;
  final bool silhouette;
  @override
  void paint(Canvas c, Size s) {
    final size =
        math.min(s.width * .84, s.height * .82) *
        (entry.enemy == MzEnemy.boss ? .88 : 1);
    if (silhouette) {
      c.saveLayer(
        Offset.zero & s,
        Paint()
          ..colorFilter = const ColorFilter.mode(
            Color(0xff4e5a4f),
            BlendMode.srcIn,
          ),
      );
    }
    if (entry.ancestral) {
      mzPaintAncestral(
        c,
        Offset(s.width * .5, s.height * .68 + math.sin(phase) * 1.5),
        size,
        1,
      );
    } else {
      mzPaintCharacter(
        c,
        Offset(s.width * .5, s.height * .68),
        size,
        cat: entry.cat,
        enemy: entry.enemy,
        armor: entry.enemy != null && entry.enemy!.protection > 0,
        armed: true,
        walking: false,
        phase: phase + (entry.cat?.index ?? entry.enemy?.index ?? 0) * .31,
      );
    }
    if (silhouette) c.restore();
  }

  @override
  bool shouldRepaint(_Portrait old) =>
      entry.id != old.entry.id ||
      phase != old.phase ||
      silhouette != old.silhouette;
}

class _Backdrop extends CustomPainter {
  const _Backdrop(this.entry, {this.large = false});
  final _Entry entry;
  final bool large;
  @override
  void paint(Canvas c, Size s) {
    final dark = entry.enemy != null;
    c.drawRect(
      Offset.zero & s,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0, -.1),
          radius: 1.1,
          colors: dark
              ? const [Color(0xff647797), Color(0xff273e54)]
              : [
                  Color.lerp(entry.accent, _paper, .68)!,
                  Color.lerp(entry.accent, const Color(0xff496845), .3)!,
                ],
        ).createShader(Offset.zero & s),
    );
    // Acquisition/first-appearance motifs stay behind the shared character art.
    final motif = Paint()..color = const Color(0x24fff1cc);
    switch (entry.world) {
      case MzWorld.cemetery:
        c.drawCircle(Offset(s.width * .8, s.height * .2), s.height * .1, motif);
      case MzWorld.egypt:
        for (final x in [.08, .72]) {
          c.drawPath(
            Path()
              ..moveTo(s.width * x, s.height * .70)
              ..lineTo(s.width * (x + .16), s.height * .28)
              ..lineTo(s.width * (x + .34), s.height * .70)
              ..close(),
            motif,
          );
        }
      case MzWorld.pirates:
        for (var i = 0; i < 3; i++) {
          c.drawPath(
            Path()
              ..moveTo(0, s.height * (.48 + i * .12))
              ..quadraticBezierTo(
                s.width * .25,
                s.height * (.34 + i * .12),
                s.width * .5,
                s.height * (.48 + i * .12),
              )
              ..quadraticBezierTo(
                s.width * .75,
                s.height * (.62 + i * .12),
                s.width,
                s.height * (.48 + i * .12),
              )
              ..lineTo(s.width, s.height * (.51 + i * .12))
              ..lineTo(0, s.height * (.51 + i * .12))
              ..close(),
            motif,
          );
        }
      case MzWorld.west:
        for (var i = 0; i < 5; i++) {
          c.drawRect(
            Rect.fromLTWH(s.width * i / 5, s.height * .14, 3, s.height * .65),
            motif,
          );
        }
      case MzWorld.future:
        for (final x in [.13, .86]) {
          final path = Path();
          for (var i = 0; i < 6; i++) {
            final a = i * math.pi / 3,
                p = Offset(
                  s.width * x + math.cos(a) * s.height * .17,
                  s.height * .37 + math.sin(a) * s.height * .17,
                );
            if (i == 0) {
              path.moveTo(p.dx, p.dy);
            } else {
              path.lineTo(p.dx, p.dy);
            }
          }
          c.drawPath(path..close(), motif);
        }
      case MzWorld.patio:
        for (var i = 0; i < 7; i++) {
          final x = s.width * i / 6;
          c.drawPath(
            Path()
              ..moveTo(x - 6, s.height * .55)
              ..lineTo(x - 6, s.height * .41)
              ..lineTo(x, s.height * .35)
              ..lineTo(x + 6, s.height * .41)
              ..lineTo(x + 6, s.height * .55)
              ..close(),
            motif,
          );
        }
    }
    final origin = Offset(s.width * .5, s.height * .66);
    for (var i = 0; i < 12; i++) {
      final a = i * math.pi / 6;
      c.drawPath(
        Path()
          ..moveTo(origin.dx, origin.dy)
          ..lineTo(
            origin.dx + math.cos(a) * s.longestSide,
            origin.dy + math.sin(a) * s.longestSide,
          )
          ..lineTo(
            origin.dx + math.cos(a + .16) * s.longestSide,
            origin.dy + math.sin(a + .16) * s.longestSide,
          )
          ..close(),
        Paint()..color = const Color(0x0effffff),
      );
    }
    c.drawOval(
      Rect.fromCenter(
        center: Offset(s.width * .5, s.height * .82),
        width: s.width * .84,
        height: s.height * .19,
      ),
      Paint()
        ..color = dark
            ? const Color(0xff354853)
            : Color.lerp(entry.accent, const Color(0xfff6e6b0), .45)!,
    );
    for (var i = 0; i < 6; i++) {
      final x = s.width * (.07 + (i % 3) * .4),
          y = s.height * (.20 + (i ~/ 3) * .38);
      c.drawCircle(
        Offset(x, y),
        large ? 3 : 2,
        Paint()..color = const Color(0x60fff4cf),
      );
    }
    c.drawRRect(
      RRect.fromRectAndRadius(
        (Offset.zero & s).deflate(3),
        const Radius.circular(10),
      ),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0x70fff0bc),
    );
  }

  @override
  bool shouldRepaint(_Backdrop old) =>
      entry.id != old.entry.id || large != old.large;
}

/// Collectible presentation shares the almanac's portraits, world and real specs.
class MzCollectibleCard extends StatelessWidget {
  const MzCollectibleCard({
    super.key,
    required this.cat,
    this.expanded = false,
  });
  final MzCat cat;
  final bool expanded;
  @override
  Widget build(BuildContext context) {
    final e = _Entry.cat(cat), spec = mzCats[cat]!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xffbd8548), Color(0xff70452c)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: const Color(0xff402b20), width: 4),
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x880b1714),
            offset: Offset(0, 9),
            blurRadius: 12,
          ),
        ],
      ),
      child: Container(
        decoration: BoxDecoration(
          color: _paper,
          border: Border.all(color: const Color(0xffedc785), width: 3),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: expanded ? 185 : 155,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(10),
                    ),
                    child: CustomPaint(painter: _Backdrop(e, large: true)),
                  ),
                  CustomPaint(painter: _Portrait(e)),
                  Positioned(
                    top: 8,
                    left: 10,
                    child: Icon(e.icon, color: _ink),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    spec.name,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'Fredoka',
                      fontSize: 25,
                      fontWeight: FontWeight.w700,
                      color: _ink,
                    ),
                  ),
                  Text(
                    e.role,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: _ink,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (expanded) ...[
                    const SizedBox(height: 10),
                    Text(
                      const [
                        'Lady nunca pierde de vista su carril.',
                        'Maru comparte su alegría y su hierba con el equipo.',
                        'Maru prefiere quedarse cómodo y proteger a sus amigos.',
                        'Lady mantiene la calma incluso en plena ventisca.',
                        'Un michi travieso que espera dentro de su caja.',
                        'Dos pequeños cómplices con energía de sobra.',
                        'Maru se toma muy en serio sus juguetes.',
                        'Lady siempre encuentra el camino de vuelta.',
                        'Un michi inquieto que no puede quedarse quieto.',
                        'Lady tiene una personalidad electrizante.',
                        'Maru mira al futuro con sus gafas tecnológicas.',
                      ][cat.index],
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: _ink),
                    ),
                    const Divider(color: Color(0xffbd8548)),
                    Text(
                      spec.description,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: _ink,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: [
                        _Stat('Hierba', '${spec.cost}', Icons.eco),
                        _Stat(
                          'Recarga',
                          '${spec.cooldown.toInt()} s',
                          Icons.hourglass_bottom,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Atún premium: ${spec.tuna}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: _ink),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      e.world.title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: _ink,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Text(
                      'Carta permanente. La hierba se paga al colocarla; la recarga corresponde a cada uso.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: _ink, fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
