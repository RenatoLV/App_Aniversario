import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'cat_character.dart';
import 'store.dart';
import 'game_audio.dart';

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
  Offset? _lastScrub;
  CatCare get care => widget.store.catCare;
  String get name => _cat == CatKind.maru ? 'Maru' : 'Lady';

  @override
  void initState() {
    super.initState();
    _action = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
  }

  @override
  void dispose() {
    _action.dispose();
    super.dispose();
  }

  Future<void> _feed([CatFood? food]) async {
    if (_busy) return;
    final target = _cat, meal = food ?? _food;
    setState(() {
      _busy = true;
      _food = meal;
      _message = '¡Ñam ñam! $name disfruta su ${meal.label.toLowerCase()}';
    });
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

  Future<void> _bath() async {
    if (_busy) return;
    final target = _cat;
    setState(() {
      _busy = true;
      _message = 'Agüita tibia, burbujas y mucho cuidado…';
    });
    try {
      await _action.forward(from: 0).orCancel;
    } on TickerCanceled {
      return;
    }
    await care.bathe(target);
    if (mounted) {
      setState(() {
        _busy = false;
        _scrub = 0;
        _message = '¡$name quedó limpio y esponjoso!';
      });
    }
    GameAudio.instance.play(GameSfx.kitten);
  }

  void _rub(DragUpdateDetails details, double catSize) {
    if (_busy) return;
    final distance = _lastScrub == null
        ? 0.0
        : (details.localPosition - _lastScrub!).distance;
    _lastScrub = details.localPosition;
    setState(
      () => _scrub = (_scrub + distance / (catSize * 3)).clamp(0.0, 1.0),
    );
    if (_scrub >= 1) _bath();
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
                        AnimatedSwitcher(
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
                            textStyle: Theme.of(context).textTheme.labelLarge!
                                .copyWith(fontSize: 12),
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
                                  _scrub = 0;
                                  _message = switch (_room) {
                                    _CareRoom.food =>
                                      'Elige su comida o arrástrala hasta $name',
                                    _CareRoom.bath =>
                                      'Frota sobre $name para enjabonarlo, o usa el botón de baño',
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
                builder: (context, _) => DragTarget<CatFood>(
                  onWillAcceptWithDetails: (_) =>
                      !_busy && _room == _CareRoom.food,
                  onAcceptWithDetails: (details) => _feed(details.data),
                  builder: (context, candidates, rejected) => GestureDetector(
                    onPanStart: _room == _CareRoom.bath
                        ? (d) => _lastScrub = d.localPosition
                        : null,
                    onPanUpdate: _room == _CareRoom.bath
                        ? (d) => _rub(d, size)
                        : null,
                    onPanEnd: (_) => _lastScrub = null,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CatActor(
                          key: ValueKey('care-cat-${_cat.name}'),
                          cat: _cat,
                          size: size,
                          active: true,
                          showLabel: false,
                          munching: _busy && _room == _CareRoom.food,
                          onPet: () {
                            if (!_busy) care.pet(_cat);
                          },
                        ),
                        if (_room == _CareRoom.bath && (_busy || _scrub > 0))
                          IgnorePointer(
                            child: CustomPaint(
                              size: Size.square(size),
                              painter: _CareEffects(
                                bath: true,
                                phase: _busy ? _action.value : _scrub,
                              ),
                            ),
                          ),
                        if (_busy && _room == _CareRoom.food)
                          IgnorePointer(
                            child: CustomPaint(
                              size: Size.square(size),
                              painter: _CareEffects(
                                bath: false,
                                phase: _action.value,
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
              if (_room == _CareRoom.food)
                Positioned(
                  bottom: 6,
                  child: IgnorePointer(
                    child: Text(
                      _food.emoji,
                      style: const TextStyle(fontSize: 34),
                    ),
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
      Row(
        children: [
          for (final food in CatFood.values)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Draggable<CatFood>(
                  data: food,
                  maxSimultaneousDrags: _busy ? 0 : 1,
                  feedback: Material(
                    color: Colors.transparent,
                    child: Text(
                      food.emoji,
                      style: const TextStyle(fontSize: 44),
                    ),
                  ),
                  child: ChoiceChip(
                    label: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(food.emoji, style: const TextStyle(fontSize: 25)),
                        Text(food.label, style: const TextStyle(fontSize: 11)),
                      ],
                    ),
                    selected: food == _food,
                    onSelected: _busy
                        ? null
                        : (_) => setState(() => _food = food),
                    showCheckmark: false,
                  ),
                ),
              ),
            ),
        ],
      ),
      const SizedBox(height: 14),
      FilledButton.icon(
        key: const ValueKey('care-feed'),
        onPressed: _busy ? null : () => _feed(),
        icon: const Icon(Icons.restaurant_rounded),
        label: Text(_busy ? 'Comiendo…' : 'Dar ${_food.label.toLowerCase()}'),
      ),
      const SizedBox(height: 8),
      const Text(
        'Comida disponible para Maru y Lady.',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 12, color: Color(0xff6e8276)),
      ),
    ],
  );

  Widget _bathControls() => Column(
    children: [
      if (_scrub > 0 && !_busy)
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: LinearProgressIndicator(
            value: _scrub,
            minHeight: 8,
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      FilledButton.icon(
        key: const ValueKey('care-bathe'),
        onPressed: _busy ? null : _bath,
        icon: const Icon(Icons.shower_rounded),
        label: Text(_busy ? 'Bañando…' : 'Dar un baño'),
      ),
      const SizedBox(height: 12),
      const Text(
        'También puedes frotar con el dedo sobre el gato para hacer espuma.',
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
        '8 prendas iniciales · toca de nuevo una prenda para quitarla',
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

class _CareEffects extends CustomPainter {
  final bool bath;
  final double phase;
  _CareEffects({required this.bath, required this.phase});
  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < (bath ? 18 : 10); i++) {
      final t = (phase + i * .137) % 1;
      final x = size.width * (.17 + ((i * .23) % .68));
      final y = size.height * (bath ? .9 - t * .7 : .66 + t * .2);
      final radius = bath ? size.width * (.016 + (i % 4) * .009) : 2.5;
      final color = bath ? const Color(0xffe9feff) : const Color(0xffbe884f);
      canvas.drawCircle(
        Offset(x, y),
        radius,
        Paint()
          ..color = color.withValues(
            alpha: bath ? .75 : math.sin(t * math.pi).abs(),
          ),
      );
      if (bath) {
        canvas.drawCircle(
          Offset(x - radius * .3, y - radius * .3),
          radius * .24,
          Paint()..color = Colors.white,
        );
      }
    }
    if (bath && phase > .5) {
      final ink = Paint()
        ..color = const Color(0xff62bdd5).withValues(alpha: .55)
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round;
      for (var i = 0; i < 6; i++) {
        final x = size.width * (.2 + i * .12),
            y = (phase * 2 % 1) * size.height * .6;
        canvas.drawLine(Offset(x, y), Offset(x, y + 12), ink);
      }
    }
  }

  @override
  bool shouldRepaint(_CareEffects old) =>
      bath != old.bath || phase != old.phase;
}
