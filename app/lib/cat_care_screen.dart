import 'paw_background.dart';
import 'dart:math' as math;
import 'dart:async';
import 'package:flutter/material.dart';
import 'cat_character.dart';
import 'cat_clothing.dart';
import 'store.dart';
import 'game_audio.dart';
import 'cat_care_art.dart';
import 'bath_foam.dart';
import 'house_day_cycle.dart';
import 'cat_bedroom.dart';
import 'care_space_art.dart';

enum _CareRoom { food, bath, wardrobe, bedroom }

class CatCareScreen extends StatefulWidget {
  final GameStore store;
  final DateTime Function()? clock;
  const CatCareScreen({super.key, required this.store, this.clock});
  @override
  State<CatCareScreen> createState() => _CatCareScreenState();
}

class _CatCareScreenState extends State<CatCareScreen>
    with TickerProviderStateMixin {
  CatKind _cat = CatKind.maru;
  _CareRoom _room = _CareRoom.food;
  CatFood _food = CatFood.kibble;
  bool _busy = false;
  String _message = 'Un ratito de cariño para tus compañeros';
  late final AnimationController _action, _dress;
  final _stageKey = GlobalKey();
  CatOutfit? _previousOutfit;
  double _scrub = 0;
  double _rinse = 0;
  BathTool _tool = BathTool.soap;
  Offset? _hand;
  double _soapAngle = 0;
  final _foam = BathFoam();
  double _bathSize = 200;
  Duration? _lastWaterTick;
  bool _fridgeOpen = false;
  bool _bathFinishedDuringDrag = false;
  late final Timer _needsRefresh;
  Offset? _lastScrub;

  // Interactive 360° wardrobe turntable and real-time stage try-on state.
  double _wardrobeTurn = 0;
  ClothingSlot? _wardrobeFilter;
  bool _onlyOwnedFilter = false;
  final Map<CatKind, CatOutfit> _liveTryOutfits = {};
  CatClothing? _liveTryItem;

  CatCare get care => widget.store.catCare;
  String get name => _cat == CatKind.maru ? 'Maru' : 'Lady';

  CatOutfit _displayedWardrobeOutfit(CatKind cat) =>
      _liveTryOutfits[cat] ?? care.outfit(cat);

  void _tryOnStage(CatClothing item) {
    setState(() {
      final base = _liveTryOutfits[_cat] ?? care.outfit(_cat);
      final alreadyTrying = base.at(item.slot) == item.id && _liveTryItem?.id == item.id;
      if (alreadyTrying) {
        _liveTryOutfits.remove(_cat);
        _liveTryItem = null;
        _message = 'Volviste al conjunto guardado de $name.';
      } else {
        _previousOutfit = _displayedWardrobeOutfit(_cat);
        _liveTryOutfits[_cat] = base.withItem(item.slot, item.id);
        _liveTryItem = item;
        _dress.forward(from: 0);
        _message = item.casinoExclusive
            ? 'Probando ${item.name} en vivo · Gira a $name para verlo desde todos los ángulos.'
            : 'Probando ${item.name} en vivo (${item.price} 🪙) · Gira a $name en la tarima.';
      }
    });
    _showStage();
  }

  void _clearStageTry() {
    setState(() {
      _liveTryOutfits.clear();
      _liveTryItem = null;
      _wardrobeTurn = 0;
      _message = 'Conjunto guardado de $name.';
    });
  }

  void _showStage() {
    final context = _stageKey.currentContext;
    if (context != null) {
      Scrollable.ensureVisible(
        context,
        alignment: .15,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _action = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    );
    _dress = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _action.addListener(() {
      final stamp = _action.lastElapsedDuration ?? Duration.zero;
      final previous = _lastWaterTick;
      _lastWaterTick = stamp;
      if (_room == _CareRoom.bath &&
          !_busy &&
          _tool == BathTool.shower &&
          _hand != null &&
          _foam.deposited > 0 &&
          previous != null) {
        final seconds = (stamp - previous).inMicroseconds / 1000000;
        _applyTool(seconds.clamp(0.0, .1) / 3.5);
      }
    });
    _needsRefresh = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _action.dispose();
    _dress.dispose();
    _needsRefresh.cancel();
    super.dispose();
  }

  Future<void> _feed([CatFood? food]) async {
    if (_busy) return;
    final target = _cat, meal = food ?? _food;
    setState(() {
      _busy = true;
      _food = meal;
      _fridgeOpen = false;
      _message = '$name: ${meal.reaction}';
    });
    if (!await care.takeFood(meal)) {
      if (mounted) {
        setState(() {
          _busy = false;
          _message =
              'No queda ${meal.label.toLowerCase()}. Compra más en el refri.';
        });
      }
      return;
    }
    if (!mounted) return;
    GameAudio.instance.play(GameSfx.kitten);
    try {
      await _action.forward(from: 0).orCancel;
    } on TickerCanceled {
      return;
    }
    await care.feed(target, meal);
    if (mounted) {
      setState(() {
        _busy = false;
        _message =
            '¡Barriguita contenta! Puedes seguir jugando o vestir a $name.';
      });
    }
  }

  Future<void> _finishBath() async {
    if (_busy) return;
    final target = _cat;
    _bathFinishedDuringDrag = true;
    setState(() {
      _busy = true;
      _message = '¡Fuera espuma y manchitas!';
    });
    await care.bathe(target);
    if (mounted) {
      setState(() {
        _busy = false;
        _scrub = 0;
        _foam.clear();
        _rinse = 0;
        _hand = null;
        _message = '¡$name quedó limpio y esponjoso!';
      });
    }
    GameAudio.instance.play(GameSfx.kitten);
  }

  void _rub(DragUpdateDetails details, double catSize) {
    _bathSize = catSize;
    if (_busy || _bathFinishedDuringDrag) return;
    final distance = _lastScrub == null
        ? 0.0
        : (details.localPosition - _lastScrub!).distance;
    final previous = _lastScrub ?? details.localPosition;
    _lastScrub = details.localPosition;
    _soapAngle += distance / catSize * 7;
    _hand = Offset(
      details.localPosition.dx.clamp(0, catSize),
      details.localPosition.dy.clamp(0, catSize),
    );
    if (distance > 0) {
      final steps = (distance / (catSize * .035)).ceil().clamp(1, 20);
      for (var i = 1; i <= steps; i++) {
        _hand = Offset.lerp(previous, details.localPosition, i / steps);
        _applyTool(distance / (catSize * 2.5 * steps));
      }
      _hand = details.localPosition;
    } else {
      _applyTool(distance / (catSize * 2.5));
    }
  }

  void _applyTool(double amount) {
    if (_busy) return;
    setState(() {
      if (_tool == BathTool.soap) {
        if (_hand != null) _foam.soap(_hand! / _bathSize, amount);
        _scrub = (_scrub + amount).clamp(0.0, 1.0);
        _message = _scrub >= .8
            ? '¡Qué espuma! Ahora usa la regadera para enjuagar.'
            : 'Pasa el jabón por el pelaje de $name';
      } else if (_foam.deposited > 0) {
        if (_hand != null) _foam.water(_hand! / _bathSize, amount * 2);
        _rinse = _foam.progress;
        _message = 'Enjuaga a $name hasta quitar toda la espuma y el lodo';
      } else {
        _message = 'Primero frota con el jabón para hacer espuma';
      }
    });
    if (_foam.finished && _tool == BathTool.shower) _finishBath();
  }

  void _selectTool(BathTool tool) {
    if (_busy) return;
    setState(() {
      _tool = tool;
      _hand = null;
      _message = tool == BathTool.soap
          ? 'Frota el jabón sobre el gato. También puedes tocar su pelaje.'
          : 'Mantén la regadera sobre el gato: el agua quitará la espuma';
    });
  }

  Offset _mealMovement(double t) {
    if (!_busy || _room != _CareRoom.food) return Offset.zero;
    // Stay seated: breathing and tiny chewing shifts settle at both endpoints.
    final envelope = math.sin(t * math.pi);
    final gentle = math.sin(t * math.pi * 6) * envelope;
    final sway = switch (_food) {
      CatFood.churu || CatFood.broth => .35,
      CatFood.chicken || CatFood.shrimp => .8,
      _ => .5,
    };
    return Offset(gentle * sway, envelope * .7);
  }

  Widget _roomButtons() => LayoutBuilder(
    builder: (context, bounds) => Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final room in _CareRoom.values)
          SizedBox(
            width: bounds.maxWidth < 520
                ? (bounds.maxWidth - 8) / 2
                : (bounds.maxWidth - 24) / 4,
            child: ChoiceChip(
              key: ValueKey('care-room-${room.name}'),
              avatar: Icon(switch (room) {
                _CareRoom.food => Icons.restaurant_rounded,
                _CareRoom.bath => Icons.bathtub_rounded,
                _CareRoom.wardrobe => Icons.checkroom_rounded,
                _CareRoom.bedroom => Icons.bedtime_rounded,
              }, size: 18),
              label: Text(
                switch (room) {
                  _CareRoom.food => 'Comida',
                  _CareRoom.bath => 'Baño',
                  _CareRoom.wardrobe => 'Ropa',
                  _CareRoom.bedroom => 'Dormitorio',
                },
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              selected: _room == room,
              onSelected: _busy
                  ? null
                  : (_) => setState(() {
                      _room = room;
                      _dress.reset();
                      _hand = null;
                      _lastWaterTick = null;
                      if (room != _CareRoom.wardrobe) {
                        _wardrobeTurn = 0;
                        _liveTryOutfits.clear();
                        _liveTryItem = null;
                      }
                      if (room == _CareRoom.bath) {
                        _action.repeat();
                      } else {
                        _action.stop();
                      }
                      _message = switch (room) {
                        _CareRoom.food =>
                          'Elige su comida o arrástrala hasta $name',
                        _CareRoom.bath =>
                          'Jabón para hacer espuma, regadera para enjuagar',
                        _CareRoom.wardrobe =>
                          'Combina accesorios y desliza sobre $name para girarlo en 360°.',
                        _CareRoom.bedroom =>
                          'Su camita, sus colores y una carta favorita en la pared.',
                      };
                    }),
            ),
          ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => CatCareScope(
    care: care,
    child: AnimatedBuilder(
      animation: care,
      builder: (context, _) {
        final needs = care.needs(_cat);
        return Scaffold(
          backgroundColor: const Color(0xfffaf6ed),
          appBar: AppBar(
            title: const Text('La casita'),
            actions: const [AudioSettingsButton()],
          ),
          body: PawBackground(
            child: SafeArea(
              child: _CareScroll(
                header: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 8),
                  child: _roomButtons(),
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
                      child: Column(
                        children: [
                          const Text(
                            'Comida, cuidados y un estilo propio',
                            style: TextStyle(color: Color(0xff63796d)),
                          ),
                          const SizedBox(height: 16),
                          SegmentedButton<CatKind>(
                            segments: const [
                              ButtonSegment(
                                value: CatKind.maru,
                                label: Text('Maru'),
                                icon: Icon(Icons.pets),
                              ),
                              ButtonSegment(
                                value: CatKind.lady,
                                label: Text('Lady'),
                                icon: Icon(Icons.pets),
                              ),
                            ],
                            selected: {_cat},
                            onSelectionChanged: _busy
                                ? null
                                : (values) => setState(() {
                                    _dress.reset();
                                    _cat = values.first;
                                    _scrub = 0;
                                    _foam.clear();
                                    _rinse = 0;
                                    _hand = null;
                                    _message = 'Ahora cuidamos a $name';
                                  }),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              _Need(
                                label: 'Comida',
                                value: needs.food,
                                icon: Icons.restaurant_rounded,
                                color: const Color(0xffdba855),
                              ),
                              const SizedBox(width: 8),
                              _Need(
                                label: 'Limpieza',
                                value: needs.clean,
                                icon: Icons.water_drop_rounded,
                                color: const Color(0xff63aebf),
                              ),
                              const SizedBox(width: 8),
                              _Need(
                                label: 'Cariño',
                                value: needs.happy,
                                icon: Icons.favorite_rounded,
                                color: const Color(0xffce839e),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          if (_room == _CareRoom.bedroom)
                            CatBedroomScene(
                              store: widget.store,
                              cat: _cat,
                              clock: widget.clock,
                            )
                          else
                            _stage(),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: AnimatedSize(
                              duration: const Duration(milliseconds: 250),
                              child: Text(
                                _message,
                                key: ValueKey(_message),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Color(0xff4c6457),
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          switch (_room) {
                            _CareRoom.food => _foodTray(),
                            _CareRoom.bath => _bathControls(),
                            _CareRoom.wardrobe => _wardrobe(),
                            _CareRoom.bedroom => CatBedroomControls(
                              store: widget.store,
                              cat: _cat,
                            ),
                          },
                          if (widget.store.saveError != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: Text(widget.store.saveError!),
                            ),
                        ],
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
  );

  Widget _stage() => HouseDayCycle(
    clock: widget.clock,
    builder: (context, light) => LayoutBuilder(
      builder: (context, constraints) {
        final size = math.min(240.0, constraints.maxWidth * .63);
        return Container(
          key: _stageKey,
          height: math.max(310.0, size + 94),
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: light.tint(
                const Color(0xffe8decf),
                const Color(0xff777187),
              ),
            ),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: _room == _CareRoom.bath
                  ? [
                      light.tint(
                        const Color(0xffe2f5f3),
                        const Color(0xff263b4e),
                      ),
                      light.tint(
                        const Color(0xffc4e6ea),
                        const Color(0xff39556a),
                      ),
                    ]
                  : [light.wallTop, light.wallBottom],
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned.fill(
                  child: IgnorePointer(
                    child: RepaintBoundary(
                      child: CustomPaint(
                        painter: CareSpacePainter(switch (_room) {
                          _CareRoom.bath => CareSpace.bath,
                          _CareRoom.wardrobe => CareSpace.wardrobe,
                          _ => CareSpace.kitchen,
                        }, light),
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(painter: HouseLampPainter(light)),
                  ),
                ),
                Positioned(
                  top: 18,
                  left: 18,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        name,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: light.text,
                        ),
                      ),
                      if (_room == _CareRoom.wardrobe &&
                          _liveTryOutfits.containsKey(_cat)) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xff24836d),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'Probador en vivo',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Positioned(
                  right: 18,
                  top: 16,
                  child: HouseTimeBadge(light: light),
                ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  height: 38,
                  child: ColoredBox(
                    color:
                        (_room == _CareRoom.bath
                                ? light.tint(
                                    const Color(0xff89c7cf),
                                    const Color(0xff376377),
                                  )
                                : light.floor)
                            .withValues(alpha: .3),
                  ),
                ),
                AnimatedBuilder(
                  animation: Listenable.merge([_action, _dress]),
                  builder: (context, _) => DragTarget<BathTool>(
                    onWillAcceptWithDetails: (_) =>
                        !_busy && _room == _CareRoom.bath,
                    onAcceptWithDetails: (details) {
                      _selectTool(details.data);
                      _bathSize = size;
                      _hand = Offset(size * .5, size * .55);
                      _applyTool(.18);
                    },
                    builder: (context, tools, rejectedTools) => DragTarget<CatFood>(
                      onWillAcceptWithDetails: (_) =>
                          !_busy && _room == _CareRoom.food,
                      onAcceptWithDetails: (details) => _feed(details.data),
                      builder: (context, candidates, rejected) => GestureDetector(
                        key: const ValueKey('care-pelaje'),
                        onHorizontalDragUpdate:
                            _room == _CareRoom.wardrobe && !_busy
                            ? (d) => setState(() {
                                _wardrobeTurn =
                                    (_wardrobeTurn + d.delta.dx / (size * .55))
                                        .clamp(-1.0, 1.0);
                              })
                            : null,
                        onPanStart: _room == _CareRoom.bath && !_busy
                            ? (d) {
                                _bathFinishedDuringDrag = false;
                                _lastScrub = d.localPosition;
                                setState(() {
                                  _bathSize = size;
                                  _hand = d.localPosition;
                                });
                              }
                            : null,
                        onPanUpdate: _room == _CareRoom.bath
                            ? (d) => _rub(d, size)
                            : null,
                        onPanEnd: _room == _CareRoom.bath
                            ? (_) => setState(() {
                                _lastScrub = null;
                                _hand = null;
                                _bathFinishedDuringDrag = false;
                              })
                            : null,
                        onPanCancel: _room == _CareRoom.bath
                            ? () => setState(() {
                                _lastScrub = null;
                                _hand = null;
                                _bathFinishedDuringDrag = false;
                              })
                            : null,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Transform.translate(
                              offset:
                                  _mealMovement(_action.value) +
                                  Offset(
                                    0,
                                    _room == _CareRoom.wardrobe
                                        ? -math.sin(_dress.value * math.pi) * 5
                                        : 0,
                                  ),
                              child: CatActor(
                                key: ValueKey('care-cat-${_cat.name}'),
                                cat: _cat,
                                size: size,
                                active: true,
                                showLabel: false,
                                turn: _room == _CareRoom.wardrobe
                                    ? _wardrobeTurn
                                    : 0,
                                outfit:
                                    _room == _CareRoom.wardrobe &&
                                        _dress.isAnimating &&
                                        _dress.value < .46
                                    ? _previousOutfit
                                    : _room == _CareRoom.wardrobe
                                    ? _displayedWardrobeOutfit(_cat)
                                    : care.outfit(_cat),
                                cleanliness:
                                    care.needs(_cat).clean +
                                    (100 - care.needs(_cat).clean) *
                                        (_room == _CareRoom.bath ? _rinse : 0),
                                // The meal scene owns food props; legacy feeding draws a churú.
                                feeding: false,
                                mealProgress: _busy && _room == _CareRoom.food
                                    ? _action.value
                                    : null,
                                munching:
                                    _busy &&
                                    _room == _CareRoom.food &&
                                    _food != CatFood.churu &&
                                    _food != CatFood.broth,
                                onPet: () {
                                  if (!_busy) {
                                    if (_room == _CareRoom.bath) {
                                      _bathSize = size;
                                      _hand = Offset(size * .5, size * .55);
                                      _applyTool(.2);
                                    } else {
                                      care.pet(_cat);
                                    }
                                  }
                                },
                              ),
                            ),
                            if (_room == _CareRoom.wardrobe &&
                                _dress.isAnimating)
                              IgnorePointer(
                                child: CustomPaint(
                                  size: Size.square(size),
                                  painter: DressingSparklesPainter(
                                    _dress.value,
                                  ),
                                ),
                              ),
                            if (_room == _CareRoom.bath)
                              IgnorePointer(
                                child: CustomPaint(
                                  size: Size.square(size),
                                  painter: BathScenePainter(
                                    foam: _scrub,
                                    rinse: _rinse,
                                    phase: _action.value,
                                    tool: _tool,
                                    hand: _hand,
                                    soapAngle: _soapAngle,
                                    patches: _foam.patches,
                                  ),
                                ),
                              ),
                            if (_busy && _room == _CareRoom.food)
                              IgnorePointer(
                                child: Transform.translate(
                                  offset: _mealMovement(_action.value),
                                  child: CustomPaint(
                                    size: Size.square(size),
                                    painter: FeedingScenePainter(
                                      food: _food,
                                      phase: _action.value,
                                    ),
                                  ),
                                ),
                              ),
                            if (candidates.isNotEmpty)
                              IgnorePointer(
                                child: Container(
                                  width: size,
                                  height: size,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(26),
                                    border: Border.all(
                                      color: const Color(0xff15846b),
                                      width: 3,
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
                if (_room == _CareRoom.wardrobe)
                  Positioned(
                    bottom: 6,
                    child: _TurntableBar(
                      turn: _wardrobeTurn,
                      onChanged: (next) => setState(() => _wardrobeTurn = next),
                    ),
                  ),
                if (_room == _CareRoom.food)
                  Positioned(
                    bottom: 6,
                    child: IgnorePointer(
                      child: _busy
                          ? const SizedBox.shrink()
                          : FoodIcon(food: _food, size: 34),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    ),
  );

  Widget _foodTray() => Column(
    children: [
      Text(
        'Monedas: ${widget.store.coins} · En el refri: ${care.stock(_food)} ${_food.label.toLowerCase()}',
      ),
      const SizedBox(height: 8),
      FilledButton.icon(
        key: const ValueKey('care-feed'),
        onPressed: _busy || care.stock(_food) == 0 ? null : () => _feed(),
        icon: const Icon(Icons.restaurant_rounded),
        label: Text(_busy ? 'Comiendo…' : 'Dar ${_food.label.toLowerCase()}'),
      ),
      const SizedBox(height: 14),
      Container(
        decoration: BoxDecoration(
          color: const Color(0xffe3f0eb),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xffb6cfc7)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            InkWell(
              key: const ValueKey('care-fridge'),
              onTap: _busy
                  ? null
                  : () => setState(() => _fridgeOpen = !_fridgeOpen),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    TweenAnimationBuilder<double>(
                      tween: Tween(end: _fridgeOpen ? 1 : 0),
                      duration: const Duration(milliseconds: 480),
                      curve: Curves.easeInOutCubic,
                      builder: (context, opening, _) => CustomPaint(
                        size: const Size(70, 96),
                        painter: FridgePainter(open: opening),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _fridgeOpen
                                ? 'El refri está abierto'
                                : 'Abre el refri',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            '10 alimentos · cada uno con su animación',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xff58786c),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'En el plato: ${_food.label}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    Icon(_fridgeOpen ? Icons.expand_less : Icons.expand_more),
                  ],
                ),
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 280),
              alignment: Alignment.topCenter,
              child: !_fridgeOpen
                  ? const SizedBox(width: double.infinity)
                  : Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            for (final food in CatFood.values)
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: SizedBox(
                                  width: 110,
                                  height: 148,
                                  child: LongPressDraggable<CatFood>(
                                    data: food,
                                    delay: const Duration(milliseconds: 180),
                                    onDragStarted: _showStage,
                                    maxSimultaneousDrags:
                                        _busy || care.stock(food) == 0 ? 0 : 1,
                                    feedback: Material(
                                      color: Colors.transparent,
                                      child: FoodIcon(food: food, size: 64),
                                    ),
                                    child: Material(
                                      color: _food == food
                                          ? const Color(0xffcce6d9)
                                          : const Color(0xfffffcf4),
                                      borderRadius: BorderRadius.circular(15),
                                      child: InkWell(
                                        key: ValueKey('food-${food.name}'),
                                        borderRadius: BorderRadius.circular(15),
                                        onTap: _busy
                                            ? null
                                            : () => setState(() {
                                                _food = food;
                                                _fridgeOpen = false;
                                                _message =
                                                    '${food.label}: ${food.reaction}';
                                              }),
                                        child: Padding(
                                          padding: const EdgeInsets.all(6),
                                          child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              FoodIcon(food: food, size: 34),
                                              const SizedBox(height: 4),
                                              Text(
                                                food.label,
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                                maxLines: 1,
                                              ),
                                              Text(
                                                'Guardados: ${care.stock(food)} · +${food.nutrition}',
                                                style: const TextStyle(
                                                  fontSize: 9,
                                                  color: Color(0xff708376),
                                                ),
                                              ),
                                              TextButton(
                                                key: ValueKey(
                                                  'buy-food-${food.name}',
                                                ),
                                                onPressed: _busy
                                                    ? null
                                                    : () async {
                                                        final bought =
                                                            await widget.store
                                                                .buyCatFood(
                                                                  food,
                                                                );
                                                        if (mounted) {
                                                          setState(
                                                            () => _message =
                                                                bought
                                                                ? '${food.label} guardado en el refri'
                                                                : 'Necesitas ${food.price} monedas para comprar ${food.label.toLowerCase()}',
                                                          );
                                                        }
                                                      },
                                                child: Text(
                                                  'Comprar ${food.price} 🪙',
                                                  style: const TextStyle(
                                                    fontSize: 10,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
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
      const SizedBox(height: 8),
      const Text(
        'Desliza para elegir. Mantén un alimento y arrástralo hacia el gato, o tócalo y dale de comer.',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 12, color: Color(0xff6e8276)),
      ),
    ],
  );

  Widget _bathControls() => Column(
    children: [
      Row(
        children: [
          for (final tool in BathTool.values)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Draggable<BathTool>(
                  data: tool,
                  maxSimultaneousDrags: _busy ? 0 : 1,
                  feedback: Material(
                    color: Colors.transparent,
                    child: BathPropIcon(tool: tool, size: 70),
                  ),
                  child: OutlinedButton(
                    key: ValueKey('bath-${tool.name}'),
                    onPressed: _busy ? null : () => _selectTool(tool),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: _tool == tool
                          ? const Color(0xffd4eae5)
                          : Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      side: BorderSide(
                        color: _tool == tool
                            ? const Color(0xff418677)
                            : const Color(0xffb8cfcd),
                        width: _tool == tool ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        BathPropIcon(tool: tool, size: 44),
                        Text(tool == BathTool.soap ? 'Jabón' : 'Regadera'),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      const SizedBox(height: 16),
      Text(
        _tool == BathTool.soap
            ? 'Frota donde quieras hacer espuma'
            : 'Dirige el agua hacia la espuma',
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 8),
      LinearProgressIndicator(
        value: _scrub < .8 ? _scrub : _rinse,
        minHeight: 8,
        borderRadius: BorderRadius.circular(8),
        color: _scrub < .8 ? const Color(0xffdf9bb9) : const Color(0xff65b8c7),
      ),
      const SizedBox(height: 12),
      const Text(
        'Gira y frota el jabón sobre el pelaje. Después mantén la regadera sobre el gato para enjuagarlo.',
        textAlign: TextAlign.center,
        style: TextStyle(color: Color(0xff657f75)),
      ),
    ],
  );

  Widget _wardrobe() {
    final activeTryItem = _liveTryItem;
    final visibleSlots = _wardrobeFilter == null
        ? ClothingSlot.values
        : [_wardrobeFilter!];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (activeTryItem != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: const Color(0xffe7f5ef),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xff84c5ae), width: 1.5),
            ),
            child: Wrap(
              spacing: 10,
              runSpacing: 8,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ClothingPreviewIcon(item: activeTryItem, size: 32),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Probando en vivo: ${activeTryItem.name}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: Color(0xff1f5747),
                        ),
                      ),
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!care.ownsClothing(activeTryItem) &&
                        !activeTryItem.casinoExclusive)
                      FilledButton.tonalIcon(
                        onPressed: () async {
                          if (!await widget.store.buyCatClothing(
                            activeTryItem,
                          )) {
                            if (mounted) {
                              setState(
                                () => _message =
                                    'Necesitas ${activeTryItem.price} monedas para esta prenda.',
                              );
                            }
                            return;
                          }
                          _previousOutfit = care.outfit(_cat);
                          _liveTryOutfits.remove(_cat);
                          _liveTryItem = null;
                          _dress.forward(from: 0);
                          await care.equip(_cat, activeTryItem);
                          if (mounted) {
                            setState(
                              () => _message =
                                  '¡${activeTryItem.name} comprada y equipada!',
                            );
                          }
                        },
                        icon: const Icon(Icons.shopping_bag_rounded, size: 16),
                        label: Text('Comprar ${activeTryItem.price} 🪙'),
                      ),
                    const SizedBox(width: 6),
                    TextButton.icon(
                      onPressed: _clearStageTry,
                      icon: const Icon(Icons.close_rounded, size: 16),
                      label: const Text('Quitar prueba'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'El armario de $name',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${catWardrobe.length} prendas · ${care.clothesOwned} tuyas · ${widget.store.coins} monedas',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xff6b8075),
                    ),
                  ),
                ],
              ),
            ),
            FilterChip(
              selected: _onlyOwnedFilter,
              label: const Text('Solo tuyas'),
              onSelected: (v) => setState(() => _onlyOwnedFilter = v),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            ChoiceChip(
              label: const Text('Todas'),
              selected: _wardrobeFilter == null,
              onSelected: (_) => setState(() => _wardrobeFilter = null),
            ),
            for (final slot in ClothingSlot.values)
              ChoiceChip(
                label: Text(switch (slot) {
                  ClothingSlot.neck => 'Collares y pañuelos',
                  ClothingSlot.head => 'Gorros',
                  ClothingSlot.eyes => 'Lentes',
                  ClothingSlot.body => 'Poleras',
                }),
                selected: _wardrobeFilter == slot,
                onSelected: (_) => setState(
                  () => _wardrobeFilter = _wardrobeFilter == slot ? null : slot,
                ),
              ),
          ],
        ),
        const SizedBox(height: 14),
        for (final slot in visibleSlots) ...[
          Text(switch (slot) {
            ClothingSlot.neck => 'Collares y pañuelos',
            ClothingSlot.head => 'Gorros',
            ClothingSlot.eyes => 'Lentes',
            ClothingSlot.body => 'Poleras',
          }, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final item in catWardrobe.where(
                (i) =>
                    i.slot == slot &&
                    (!_onlyOwnedFilter || care.ownsClothing(i)),
              ))
                ActionChip(
                  key: ValueKey('wear-${item.id}'),
                  avatar: care.outfit(_cat).at(slot) == item.id
                      ? const Icon(
                          Icons.check_circle,
                          color: Color(0xff18775d),
                          size: 20,
                        )
                      : ClothingPreviewIcon(item: item, size: 22),
                  label: Text(
                    care.ownsClothing(item)
                        ? item.name
                        : item.casinoExclusive
                        ? '${item.name} · Premio de Lucky Palace'
                        : '${item.name} · ${item.price} 🪙',
                  ),
                  backgroundColor: care.outfit(_cat).at(slot) == item.id
                      ? const Color(0xffdcefe5)
                      : _displayedWardrobeOutfit(_cat).at(slot) == item.id
                      ? const Color(0xffedf7f2)
                      : Colors.white,
                  onPressed: () async {
                    if (!care.ownsClothing(item)) {
                      if (item.casinoExclusive) {
                        _tryOnStage(item);
                        setState(
                          () => _message =
                              'Probando ${item.name} en vivo · Consíguela en Premios de Lucky Palace.',
                        );
                        return;
                      }
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (context) => _ClothingPurchaseDialog(
                          item: item,
                          cat: _cat,
                          outfits: {
                            for (final cat in CatKind.values)
                              cat: care.outfit(cat),
                          },
                          onTryOnStage: () => _tryOnStage(item),
                        ),
                      );
                      if (confirmed != true) return;
                      if (!await widget.store.buyCatClothing(item)) {
                        if (mounted) {
                          setState(
                            () => _message =
                                'Necesitas ${item.price} monedas para esta prenda.',
                          );
                        }
                        return;
                      }
                    }
                    _liveTryOutfits.remove(_cat);
                    _liveTryItem = null;
                    _previousOutfit = care.outfit(_cat);
                    _showStage();
                    _dress.forward(from: 0);
                    await care.equip(_cat, item);
                    if (mounted) {
                      setState(
                        () => _message =
                            'El estilo de $name se guarda para todos los juegos.',
                      );
                    }
                  },
                ),
            ],
          ),
          const SizedBox(height: 14),
        ],
        TextButton.icon(
          key: const ValueKey('care-undress'),
          onPressed: () {
            _liveTryOutfits.remove(_cat);
            _liveTryItem = null;
            _previousOutfit = care.outfit(_cat);
            _showStage();
            _dress.forward(from: 0);
            care.undress(_cat);
          },
          icon: const Icon(Icons.restart_alt_rounded),
          label: const Text('Sin ropa ni accesorios'),
        ),
      ],
    );
  }
}

/// Interactive 360° turntable bar rendered on the wardrobe & showroom stages.
class _TurntableBar extends StatelessWidget {
  final double turn;
  final ValueChanged<double> onChanged;
  static const bool darkTheme = false;
  const _TurntableBar({
    required this.turn,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final bg = darkTheme ? const Color(0xd8251a30) : const Color(0xe6fffdf8);
    final fg = darkTheme ? const Color(0xffffe7b3) : const Color(0xff355246);
    final activeBg = darkTheme
        ? const Color(0xff523868)
        : const Color(0xffd4ece1);

    Widget angleButton(String label, double target, bool selected) => InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => onChanged(target),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? activeBg : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            color: fg,
          ),
        ),
      ),
    );

    final isBack = turn.abs() > 0.65;
    final isProfile = !isBack && turn.abs() >= 0.25;
    final isFront = !isBack && !isProfile;

    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: darkTheme
                ? const Color(0xff806240)
                : const Color(0xffc9dcd3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () {
                final next = turn - 0.45;
                onChanged(next < -1.0 ? 1.0 : next.clamp(-1.0, 1.0));
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                child: Icon(Icons.rotate_left_rounded, size: 17, color: fg),
              ),
            ),
            angleButton('Frente', 0.0, isFront),
            angleButton('Perfil', 0.48, isProfile),
            angleButton('Espalda', 1.0, isBack),
            InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () {
                final next = turn + 0.45;
                onChanged(next > 1.0 ? -1.0 : next.clamp(-1.0, 1.0));
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                child: Icon(Icons.rotate_right_rounded, size: 17, color: fg),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CareScroll extends StatelessWidget {
  final Widget header, child;
  const _CareScroll({required this.header, required this.child});
  @override
  Widget build(BuildContext context) => Column(
    children: [
      header,
      Expanded(child: SingleChildScrollView(child: child)),
    ],
  );
}

/// Preview outfits are local to this dialog; they never reach CatCare or storage.
class _ClothingPurchaseDialog extends StatefulWidget {
  final CatClothing item;
  final CatKind cat;
  final Map<CatKind, CatOutfit> outfits;
  final VoidCallback? onTryOnStage;
  const _ClothingPurchaseDialog({
    required this.item,
    required this.cat,
    required this.outfits,
    this.onTryOnStage,
  });
  @override
  State<_ClothingPurchaseDialog> createState() =>
      _ClothingPurchaseDialogState();
}

class _ClothingPurchaseDialogState extends State<_ClothingPurchaseDialog> {
  bool _trying = false;
  late CatKind _cat = widget.cat;
  double _turn = 0;

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Row(
      children: [
        ClothingPreviewIcon(item: widget.item, size: 34),
        const SizedBox(width: 10),
        Expanded(child: Text(widget.item.name)),
      ],
    ),
    scrollable: true,
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_trying) ...[
          GestureDetector(
            onHorizontalDragUpdate: (d) => setState(() {
              _turn = (_turn + d.delta.dx / 90).clamp(-1.0, 1.0);
            }),
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xfff5ecdd),
                borderRadius: BorderRadius.circular(22),
              ),
              padding: const EdgeInsets.fromLTRB(8, 12, 8, 12),
              child: Column(
                children: [
                  Center(
                    child: CatActor(
                      key: const ValueKey('clothing-preview-cat'),
                      cat: _cat,
                      size: 160,
                      active: true,
                      showLabel: false,
                      turn: _turn,
                      outfit: widget.outfits[_cat]!.withItem(
                        widget.item.slot,
                        widget.item.id,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  _TurntableBar(
                    turn: _turn,
                    onChanged: (next) => setState(() => _turn = next),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          SegmentedButton<CatKind>(
            segments: const [
              ButtonSegment(value: CatKind.maru, label: Text('Maru')),
              ButtonSegment(value: CatKind.lady, label: Text('Lady')),
            ],
            selected: {_cat},
            onSelectionChanged: (value) => setState(() => _cat = value.first),
          ),
          const SizedBox(height: 10),
          const Text(
            'Solo una prueba: desliza para girar. No se guarda ni gasta monedas.',
            style: TextStyle(fontSize: 12),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
        ],
        Text(
          'Comprar por ${widget.item.price} monedas. La prenda queda para Maru y Lady.',
        ),
        if (widget.onTryOnStage != null) ...[
          const SizedBox(height: 6),
          TextButton.icon(
            onPressed: () {
              widget.onTryOnStage!();
              Navigator.pop(context, false);
            },
            icon: const Icon(Icons.threesixty_rounded, size: 18),
            label: const Text('Probar en la tarima principal'),
          ),
        ],
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context, false),
        child: const Text('Cancelar'),
      ),
      TextButton.icon(
        key: const ValueKey('clothing-try'),
        onPressed: () => setState(() => _trying = !_trying),
        icon: Icon(
          _trying ? Icons.visibility_off_outlined : Icons.visibility_outlined,
        ),
        label: Text(_trying ? 'Quitar prueba' : 'Probar'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, true),
        child: const Text('Comprar'),
      ),
    ],
  );
}

class _Need extends StatelessWidget {
  final String label;
  final int value;
  final IconData icon;
  final Color color;
  const _Need({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });
  @override
  Widget build(BuildContext context) => Expanded(
    child: Semantics(
      label: '$label: $value de 100',
      child: Container(
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 21),
            const SizedBox(height: 5),
            Text(label, style: const TextStyle(fontSize: 11)),
            const SizedBox(height: 6),
            LinearProgressIndicator(
              value: value / 100,
              color: color,
              backgroundColor: color.withValues(alpha: .15),
              minHeight: 5,
              borderRadius: BorderRadius.circular(5),
            ),
            const SizedBox(height: 3),
            Text(
              '$value%',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    ),
  );
}
