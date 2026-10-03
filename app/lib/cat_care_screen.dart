import 'dart:math' as math;
import 'dart:async';
import 'package:flutter/material.dart';
import 'cat_character.dart';
import 'store.dart';
import 'game_audio.dart';
import 'cat_care_art.dart';
import 'bath_foam.dart';

enum _CareRoom { food, bath, wardrobe }

class CatCareScreen extends StatefulWidget {
  final GameStore store;
  const CatCareScreen({super.key, required this.store});
  @override
  State<CatCareScreen> createState() => _CatCareScreenState();
}

class _CatCareScreenState extends State<CatCareScreen>
    with SingleTickerProviderStateMixin {
  CatKind _cat = CatKind.maru;
  _CareRoom _room = _CareRoom.food;
  CatFood _food = CatFood.kibble;
  bool _busy = false;
  String _message = 'Un ratito de cariño para tus compañeros';
  late final AnimationController _action;
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
  CatCare get care => widget.store.catCare;
  String get name => _cat == CatKind.maru ? 'Maru' : 'Lady';

  @override
  void initState() {
    super.initState();
    _action = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
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
          body: SafeArea(
            child: SingleChildScrollView(
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
                        _stage(),
                        const SizedBox(height: 12),
                        AnimatedSize(
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
                        const SizedBox(height: 18),
                        SegmentedButton<_CareRoom>(
                          style: SegmentedButton.styleFrom(
                            textStyle: Theme.of(
                              context,
                            ).textTheme.labelLarge!.copyWith(fontSize: 12),
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                          ),
                          segments: const [
                            ButtonSegment(
                              value: _CareRoom.food,
                              label: Text('Comida'),
                              icon: Icon(Icons.restaurant_rounded),
                            ),
                            ButtonSegment(
                              value: _CareRoom.bath,
                              label: Text('Baño'),
                              icon: Icon(Icons.bathtub_rounded),
                            ),
                            ButtonSegment(
                              value: _CareRoom.wardrobe,
                              label: Text('Ropa'),
                              icon: Icon(Icons.checkroom_rounded),
                            ),
                          ],
                          selected: {_room},
                          onSelectionChanged: _busy
                              ? null
                              : (values) => setState(() {
                                  _room = values.first;
                                  _hand = null;
                                  if (_room == _CareRoom.bath) {
                                    _action.repeat();
                                  } else {
                                    _action.stop();
                                  }
                                  _message = switch (_room) {
                                    _CareRoom.food =>
                                      'Elige su comida o arrástrala hasta $name',
                                    _CareRoom.bath =>
                                      'Jabón para hacer espuma, regadera para enjuagar',
                                    _CareRoom.wardrobe =>
                                      'Combina accesorios. Se verán también en todos los juegos.',
                                  };
                                }),
                        ),
                        const SizedBox(height: 20),
                        switch (_room) {
                          _CareRoom.food => _foodTray(),
                          _CareRoom.bath => _bathControls(),
                          _CareRoom.wardrobe => _wardrobe(),
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
        );
      },
    ),
  );

  Widget _stage() => LayoutBuilder(
    builder: (context, constraints) {
      final size = math.min(210.0, constraints.maxWidth * .63);
      return Container(
        height: size + 60,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: const Color(0xffe8decf)),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: _room == _CareRoom.bath
                ? const [Color(0xffe2f5f3), Color(0xffc4e6ea)]
                : const [Color(0xfff5ecdd), Color(0xffe8d6bd)],
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned(
                top: 18,
                left: 18,
                child: Text(
                  name,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Color(0xff435d4c),
                  ),
                ),
              ),
              Positioned(
                right: 18,
                top: 16,
                child: Icon(
                  _room == _CareRoom.bath
                      ? Icons.water_drop_outlined
                      : Icons.wb_sunny_outlined,
                  color: const Color(0xffbda685),
                  size: 30,
                ),
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                height: 38,
                child: ColoredBox(
                  color:
                      (_room == _CareRoom.bath
                              ? const Color(0xff89c7cf)
                              : const Color(0xffbc9f7d))
                          .withValues(alpha: .3),
                ),
              ),
              AnimatedBuilder(
                animation: _action,
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
                            offset: _mealMovement(_action.value),
                            child: CatActor(
                              key: ValueKey('care-cat-${_cat.name}'),
                              cat: _cat,
                              size: size,
                              active: true,
                              showLabel: false,
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
                    const CustomPaint(
                      size: Size(54, 72),
                      painter: FridgePainter(),
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
                      child: LayoutBuilder(
                        builder: (context, constraints) => GridView.count(
                          crossAxisCount: constraints.maxWidth > 500 ? 5 : 3,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                          childAspectRatio: .7,
                          children: [
                            for (final food in CatFood.values)
                              Draggable<CatFood>(
                                data: food,
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
                                                    final bought = await widget
                                                        .store
                                                        .buyCatFood(food);
                                                    if (mounted) {
                                                      setState(
                                                        () => _message = bought
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
        'Elige un alimento o arrástralo del refri hasta el gato.',
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

  Widget _wardrobe() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        'El armario de $name',
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 6),
      const Text(
        '40 prendas · 10 de cada categoría · toca de nuevo para quitar',
        style: TextStyle(fontSize: 12, color: Color(0xff6b8075)),
      ),
      const SizedBox(height: 12),
      for (final slot in ClothingSlot.values) ...[
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
            for (final item in catWardrobe.where((i) => i.slot == slot))
              ActionChip(
                key: ValueKey('wear-${item.id}'),
                avatar: Icon(
                  care.outfit(_cat).at(slot) == item.id
                      ? Icons.check_circle
                      : item.icon,
                  color: care.outfit(_cat).at(slot) == item.id
                      ? const Color(0xff18775d)
                      : item.color,
                  size: 20,
                ),
                label: Text(item.name),
                backgroundColor: care.outfit(_cat).at(slot) == item.id
                    ? const Color(0xffdcefe5)
                    : Colors.white,
                onPressed: () async {
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
        onPressed: () => care.undress(_cat),
        icon: const Icon(Icons.restart_alt_rounded),
        label: const Text('Sin ropa ni accesorios'),
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
