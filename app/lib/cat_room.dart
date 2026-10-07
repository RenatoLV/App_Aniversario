import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'cat_character.dart';
import 'game_audio.dart';
import 'house_day_cycle.dart';
import 'patio_art.dart';

enum _RoomMoment { cuddle, churu, litter, thoughts, yarn, window, food, cards }

/// A small autonomous room. All props and movements share its coordinates.
class CatRoom extends StatefulWidget {
  final List<int> ownedCards;
  final Widget Function(int)? cardBuilder;
  final VoidCallback? onOpenCare;
  final VoidCallback? onOpenPatio;
  final DateTime Function()? clock;
  const CatRoom({
    super.key,
    this.ownedCards = const [],
    this.cardBuilder,
    this.onOpenCare,
    this.onOpenPatio,
    this.clock,
  });
  @override
  State<CatRoom> createState() => _CatRoomState();
}

class _CatRoomState extends State<CatRoom> with TickerProviderStateMixin {
  late final AnimationController _life;
  late final AnimationController _purr;
  CatKind? _purring;
  final _random = math.Random();
  final List<_RoomMoment> _queue = [];
  Timer? _sceneTimer, _detailTimer;
  _RoomMoment _moment = _RoomMoment.cuddle;
  bool _maruTurn = true;
  int _thought = 0;
  final Map<CatKind, int> _heldCards = {};
  late final AnimationController _drawCards;
  late final AnimationController _hop;
  Timer? _hopTimer;
  CatKind? _hopping, _dragging;
  double _hopHeight = 24;
  final Map<CatKind, Offset> _positions = {};
  Offset _dragStart = Offset.zero;

  void _scheduleHop() {
    _hopTimer = Timer(Duration(seconds: 7 + _random.nextInt(12)), () {
      if (!mounted) return;
      if (_dragging == null &&
          _moment != _RoomMoment.litter &&
          _moment != _RoomMoment.food) {
        setState(() {
          _hopping = CatKind.values[_random.nextInt(CatKind.values.length)];
          _hopHeight = 18 + _random.nextDouble() * 24;
        });
        _hop.forward(from: 0);
      }
      _scheduleHop();
    });
  }

  void _pickCards() {
    _heldCards.clear();
    final pool = widget.ownedCards.toList()..shuffle(_random);
    if (pool.isEmpty) return;
    for (final cat in CatKind.values) {
      _heldCards[cat] = pool[cat.index % pool.length];
    }
    _drawCards.forward(from: 0);
  }

  final _maruThoughts = const [
    '🐟 ¿Y si aparece un atún?',
    '💛 Lady es mi lugar feliz',
    '📦 Esa caja es mi castillo',
    '☁️ La nube parece un pez',
    '😴 Cinco minutitos más…',
    '🥢 ¿Quedará otro churú?',
    '🐾 Hoy cuido a mi Lady',
    '🧶 Ese ovillo me desafía',
    '🌙 Soñé con mil premios',
    '🏡 Aquí estoy calentito',
    '🎵 Miau es mi canción',
    '✨ Soy un tigre chiquito',
  ];
  final _ladyThoughts = const [
    '🌸 Hoy me siento bonita',
    '💞 Maru, ven a mi ladito',
    '🦋 ¿A dónde irá esa mariposa?',
    '🛋️ Este sillón es mío',
    '☀️ Me encanta el solcito',
    '🍗 Un premio y una caricia',
    '🌿 Los árboles están bailando',
    '💤 Una siesta con Maru',
    '🎀 Tengo mis bigotes listos',
    '🌈 Quiero atrapar el arcoíris',
    '🐾 Hagamos travesuras juntos',
    '💛 Qué rico estar en casa',
  ];

  @override
  void initState() {
    super.initState();
    _hop = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    );
    _scheduleHop();
    _drawCards = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );
    if (widget.ownedCards.isNotEmpty) {
      _moment = _RoomMoment.cards;
      _pickCards();
    }
    _purr = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _life = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
    _schedule();
    _detailTimer = Timer.periodic(const Duration(seconds: 6), (_) {
      if (!mounted) return;
      setState(() {
        if (_dragging == null) _maruTurn = _random.nextBool();
        _thought = (_thought + 1 + _random.nextInt(11)) % 12;
      });
    });
  }

  void _schedule() {
    _sceneTimer?.cancel();
    _sceneTimer = Timer(Duration(seconds: 13 + _random.nextInt(5)), () {
      if (!mounted) return;
      if (_dragging != null) {
        _schedule();
        return;
      }
      if (_queue.isEmpty) {
        _queue.addAll(
          _RoomMoment.values
              .where(
                (m) =>
                    m != _moment &&
                    (m != _RoomMoment.cards || widget.ownedCards.isNotEmpty),
              )
              .toList()
            ..shuffle(_random),
        );
      }
      setState(() {
        _queue.removeWhere((m) => m == _moment);
        _moment = _queue.removeAt(0);
        _maruTurn = _random.nextBool();
        if (_moment == _RoomMoment.cards) _pickCards();
      });
      _schedule();
    });
  }

  @override
  void didUpdateWidget(covariant CatRoom oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.ownedCards.isEmpty && widget.ownedCards.isNotEmpty) {
      _moment = _RoomMoment.cards;
      _pickCards();
    }
  }

  @override
  void dispose() {
    _sceneTimer?.cancel();
    _detailTimer?.cancel();
    _life.dispose();
    _purr.dispose();
    _drawCards.dispose();
    _hopTimer?.cancel();
    _hop.dispose();
    super.dispose();
  }

  void _pet(CatKind cat) {
    CatCareScope.maybeOf(context)?.pet(cat);
    GameAudio.instance.play(GameSfx.kitten);
    setState(() => _purring = cat);
    _purr.forward(from: 0);
  }

  Widget _openable(Widget child) => GestureDetector(
    onDoubleTap: widget.onOpenCare,
    behavior: HitTestBehavior.opaque,
    child: child,
  );

  @override
  Widget build(BuildContext context) => HouseDayCycle(
    clock: widget.clock,
    builder: (context, light) => _room(light),
  );

  Widget _room(HouseLight light) => _openable(
    Container(
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 10),
      decoration: BoxDecoration(
        color: const Color(0xfffffdf8),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xffe7dfcf)),
      ),
      child: LayoutBuilder(
        builder: (context, c) {
          final width = c.maxWidth;
          final doorWidth = math.min(72.0, width * .20);
          // Leave room for the active cat in the middle and its companion at the side.
          final catSize = math.min(148.0, width * .30);
          final height = (width * .4 + 165).clamp(285.0, 380.0);
          final litter = _moment == _RoomMoment.litter;
          final meal = _moment == _RoomMoment.food;
          final churu = _moment == _RoomMoment.churu;
          final thoughts = _moment == _RoomMoment.thoughts;
          final yarn = _moment == _RoomMoment.yarn;
          final cards = _moment == _RoomMoment.cards;
          final caption = switch (_moment) {
            _RoomMoment.cards => '¡Mira los tesoros que encontramos!',
            _RoomMoment.cuddle => 'Maru y Lady, juntitos en casa',
            _RoomMoment.churu =>
              _maruTurn
                  ? 'Maru saborea su churú'
                  : 'Un poquito de churú para Lady',
            _RoomMoment.litter =>
              _maruTurn ? 'Maru acomoda la arena' : 'Lady deja todo ordenadito',
            _RoomMoment.thoughts => 'Dos bigotitos, mil pensamientos',
            _RoomMoment.yarn => '¡Atrapa el ovillo, Lady!',
            _RoomMoment.window =>
              light.daylight < .5
                  ? 'Un ratito mirando las estrellas'
                  : 'Un ratito mirando las nubes',
            _RoomMoment.food =>
              _maruTurn
                  ? 'Maru disfruta su comidita'
                  : 'Lady disfruta su comidita',
          };
          return Column(
            children: [
              SizedBox(
                height: 32,
                child: Center(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 450),
                    child: Text(
                      caption,
                      key: ValueKey(caption),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Color(0xff31594c),
                      ),
                    ),
                  ),
                ),
              ),
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: SizedBox(
                  height: height,
                  width: width,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned.fill(
                        child: CustomPaint(painter: _RoomBackdrop(light)),
                      ),
                      Positioned.fill(
                        child: IgnorePointer(
                          child: CustomPaint(painter: HouseLampPainter(light)),
                        ),
                      ),
                      Positioned(
                        top: 17,
                        left: 16,
                        child: Container(
                          width: width * .26,
                          height: width * .24,
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: const Color(0xffaa886d),
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x18000000),
                                blurRadius: 6,
                                offset: Offset(0, 3),
                              ),
                            ],
                          ),
                          child: AnimatedBuilder(
                            animation: _life,
                            builder: (context, _) => CustomPaint(
                              painter: _WindowLandscape(_life.value, light),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 17,
                        right: 16,
                        child: Container(
                          width: width * .24,
                          height: width * .24,
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: const Color(0xffc58e50),
                            borderRadius: BorderRadius.circular(5),
                            border: Border.all(
                              color: const Color(0xffefca8c),
                              width: 3,
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x24000000),
                                blurRadius: 5,
                                offset: Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Image.asset(
                            'assets/cuadro.jpg',
                            fit: BoxFit.cover,
                            semanticLabel:
                                'Nuestro cuadro: dos monitos besándose frente a un corazón',
                          ),
                        ),
                      ),
                      if (widget.onOpenPatio != null)
                        Positioned(
                          top: 27 + width * .24,
                          right: 16 + (width * .24 - doorWidth) / 2,
                          width: doorWidth,
                          height: doorWidth * 1.5 + 18,
                          child: Semantics(
                            button: true,
                            label: 'Abrir la puerta al patio',
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                key: const ValueKey('home-patio-door'),
                                borderRadius: BorderRadius.circular(12),
                                onTap: widget.onOpenPatio,
                                child: Column(
                                  children: [
                                    Expanded(
                                      child: CustomPaint(
                                        painter: PatioDoorPainter(light: light),
                                        child: SizedBox.expand(),
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      'Patio',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: light.text,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        )
                      else
                        Positioned(
                          top: 28,
                          left: width * .43,
                          child: const Text(
                            '🪴',
                            style: TextStyle(fontSize: 32),
                          ),
                        ),
                      Positioned(
                        top: 4,
                        left: width * .43,
                        child: HouseTimeBadge(light: light),
                      ),
                      if (thoughts) ...[
                        Positioned(
                          top: width * .24 + 35,
                          left: 8,
                          child: _RoomThought(
                            text: _maruThoughts[_thought],
                            width: width * .47,
                            color: const Color(0xffe8f2ff),
                          ),
                        ),
                        Positioned(
                          top: width * .24 + 60,
                          right: 8,
                          child: _RoomThought(
                            text: _ladyThoughts[(_thought + 3) % 12],
                            width: width * .47,
                            color: const Color(0xffffe6ef),
                          ),
                        ),
                      ],
                      if (litter)
                        Positioned(
                          bottom: 9,
                          left: width / 2 - catSize * .39,
                          child: CustomPaint(
                            size: Size(catSize * .78, 54),
                            painter: _LitterTray(false),
                          ),
                        ),
                      Positioned.fill(
                        child: IgnorePointer(
                          child: AnimatedBuilder(
                            animation: _life,
                            builder: (context, _) => CustomPaint(
                              painter: _FloorShadows(
                                catSize,
                                _moment,
                                _maruTurn,
                                _life.value,
                              ),
                            ),
                          ),
                        ),
                      ),
                      for (final cat in CatKind.values)
                        AnimatedPositioned(
                          key: ValueKey(cat),
                          duration: const Duration(milliseconds: 1100),
                          curve: Curves.easeInOutCubic,
                          left:
                              (litter || meal) &&
                                  (cat == CatKind.maru) == _maruTurn
                              ? width / 2 - catSize * .44
                              : cat == CatKind.maru
                              ? 5
                              : width - catSize - 5,
                          bottom:
                              (litter || meal) &&
                                  (cat == CatKind.maru) == _maruTurn
                              ? 14
                              : 16 - (thoughts ? catSize * .82 : catSize) * .06,
                          child: AnimatedBuilder(
                            animation: Listenable.merge([_life, _hop]),
                            builder: (context, _) {
                              final resting =
                                  CatCareScope.maybeOf(context)?.resting(cat) ??
                                  false;
                              final t = _life.value;
                              final side = cat == CatKind.maru ? 1.0 : -1.0;
                              final digs =
                                  litter && (cat == CatKind.maru) == _maruTurn;
                              final eats =
                                  churu && (cat == CatKind.maru) == _maruTurn;
                              final munches =
                                  meal && (cat == CatKind.maru) == _maruTurn;
                              final jump = yarn && !resting
                                  ? math.sin(t * math.pi * 4).abs() * 9
                                  : 0.0;
                              final cuddle =
                                  !resting && _moment == _RoomMoment.cuddle
                                  ? math.sin(t * math.pi) * 8 * side
                                  : 0.0;
                              final baseX =
                                  (litter || meal) &&
                                      (cat == CatKind.maru) == _maruTurn
                                  ? width / 2 - catSize * .44
                                  : cat == CatKind.maru
                                  ? 5.0
                                  : width - catSize - 5;
                              final position = _positions[cat] ?? Offset.zero;
                              final hop =
                                  !resting &&
                                      _hopping == cat &&
                                      _dragging != cat
                                  ? math.sin(_hop.value * math.pi) * _hopHeight
                                  : 0.0;
                              return GestureDetector(
                                onLongPressStart: (_) {
                                  _dragStart = position;
                                  setState(() => _dragging = cat);
                                },
                                onLongPressMoveUpdate: (details) => setState(
                                  () {
                                    _positions[cat] = Offset(
                                      (_dragStart.dx +
                                              details.offsetFromOrigin.dx)
                                          .clamp(
                                            -baseX,
                                            width - catSize - baseX,
                                          ),
                                      (_dragStart.dy +
                                              details.offsetFromOrigin.dy)
                                          .clamp(-(height - catSize - 24), 0.0),
                                    );
                                  },
                                ),
                                onLongPressEnd: (_) =>
                                    setState(() => _dragging = null),
                                onLongPressCancel: () =>
                                    setState(() => _dragging = null),
                                child: Transform.translate(
                                  offset:
                                      position +
                                      Offset(
                                        cuddle,
                                        -jump -
                                            hop -
                                            (_dragging == cat ? 5 : 0),
                                      ),
                                  child: Transform.rotate(
                                    angle: eats
                                        ? math.sin(t * math.pi * 8) * .025
                                        : digs
                                        ? math.sin(t * math.pi * 12) * .035
                                        : 0,
                                    child: Stack(
                                      clipBehavior: Clip.none,
                                      children: [
                                        CatActor(
                                          cat: cat,
                                          size: digs || munches
                                              ? catSize * .88
                                              : thoughts
                                              ? catSize * .82
                                              : catSize,
                                          action: cards
                                              ? CatAction.collection
                                              : digs || eats || munches || yarn
                                              ? CatAction.blocks
                                              : CatAction.idle,
                                          active:
                                              cards ||
                                              digs ||
                                              eats ||
                                              munches ||
                                              yarn,
                                          munching: munches,
                                          feeding: eats,
                                          digging: digs,
                                          focus: _moment == _RoomMoment.window
                                              ? -.6
                                              : side * .4,
                                          movable: false,
                                          showLabel: false,
                                          showShadow: false,
                                          onPet: () => _pet(cat),
                                        ),
                                        if (cards &&
                                            _heldCards.containsKey(cat))
                                          Positioned(
                                            left:
                                                catSize *
                                                (cat == CatKind.maru
                                                    ? .54
                                                    : .17),
                                            top: catSize * .52,
                                            child: IgnorePointer(
                                              child: AnimatedBuilder(
                                                animation: _drawCards,
                                                builder: (context, child) {
                                                  final progress = Curves
                                                      .easeOutCubic
                                                      .transform(
                                                        ((_drawCards.value -
                                                                    cat.index *
                                                                        .2) /
                                                                .8)
                                                            .clamp(0.0, 1.0),
                                                      );
                                                  return Opacity(
                                                    opacity: progress,
                                                    child: Transform.translate(
                                                      offset: Offset(
                                                        side *
                                                            (1 - progress) *
                                                            25,
                                                        (1 - progress) *
                                                            catSize *
                                                            .4,
                                                      ),
                                                      child: Transform.rotate(
                                                        angle:
                                                            side *
                                                            (-.15 +
                                                                (1 - progress) *
                                                                    .65),
                                                        child: child,
                                                      ),
                                                    ),
                                                  );
                                                },
                                                child: Stack(
                                                  children: [
                                                    Container(
                                                      width: catSize * .3,
                                                      height: catSize * .4,
                                                      padding:
                                                          const EdgeInsets.all(
                                                            3,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        gradient:
                                                            const LinearGradient(
                                                              colors: [
                                                                Color(
                                                                  0xffdca6ff,
                                                                ),
                                                                Color(
                                                                  0xff6940a6,
                                                                ),
                                                              ],
                                                            ),
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              6,
                                                            ),
                                                        border: Border.all(
                                                          color: Colors.white,
                                                          width: 1.5,
                                                        ),
                                                        boxShadow: const [
                                                          BoxShadow(
                                                            color: Color(
                                                              0x33000000,
                                                            ),
                                                            blurRadius: 5,
                                                            offset: Offset(
                                                              0,
                                                              3,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                      child: ClipRRect(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              3,
                                                            ),
                                                        child:
                                                            widget.cardBuilder
                                                                ?.call(
                                                                  _heldCards[cat]!,
                                                                ) ??
                                                            const Icon(
                                                              Icons.pets,
                                                            ),
                                                      ),
                                                    ),
                                                    Positioned(
                                                      right: cat == CatKind.maru
                                                          ? null
                                                          : 0,
                                                      left: cat == CatKind.maru
                                                          ? 0
                                                          : null,
                                                      bottom: 8,
                                                      child: Container(
                                                        width: catSize * .1,
                                                        height: catSize * .08,
                                                        decoration: BoxDecoration(
                                                          color:
                                                              cat ==
                                                                  CatKind.maru
                                                              ? const Color(
                                                                  0xff777269,
                                                                )
                                                              : const Color(
                                                                  0xfffff9ef,
                                                                ),
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                10,
                                                              ),
                                                          border: Border.all(
                                                            color: const Color(
                                                              0xff887d73,
                                                            ),
                                                            width: .8,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        if (_purring == cat)
                                          Positioned(
                                            top: -6,
                                            right: 5,
                                            child: IgnorePointer(
                                              child: AnimatedBuilder(
                                                animation: _purr,
                                                builder: (context, _) => Opacity(
                                                  opacity: (1 - _purr.value)
                                                      .clamp(0.0, 1.0),
                                                  child: Transform.translate(
                                                    offset: Offset(
                                                      0,
                                                      -_purr.value * 30,
                                                    ),
                                                    child: Transform.scale(
                                                      scale:
                                                          1 +
                                                          math.sin(
                                                                _purr.value *
                                                                    math.pi *
                                                                    4,
                                                              ) *
                                                              .12,
                                                      child: const Text(
                                                        '♥\nprrr…',
                                                        textAlign:
                                                            TextAlign.center,
                                                        style: TextStyle(
                                                          fontSize: 22,
                                                          height: 1.1,
                                                          color: Color(
                                                            0xffdb759b,
                                                          ),
                                                          fontWeight:
                                                              FontWeight.w800,
                                                        ),
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
                              );
                            },
                          ),
                        ),
                      if (litter) ...[
                        Positioned(
                          bottom: 9,
                          left: width / 2 - catSize * .39,
                          child: IgnorePointer(
                            child: CustomPaint(
                              size: Size(catSize * .78, 54),
                              painter: _LitterTray(true),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 40,
                          left: width / 2 - catSize * .35,
                          child: IgnorePointer(
                            child: AnimatedBuilder(
                              animation: _life,
                              builder: (context, _) => CustomPaint(
                                size: Size(catSize * .7, 50),
                                painter: _SandSparkles(_life.value),
                              ),
                            ),
                          ),
                        ),
                      ],
                      if (meal) ...[
                        Positioned(
                          bottom: 9,
                          left: width / 2 - catSize * .33,
                          child: IgnorePointer(
                            child: CustomPaint(
                              size: Size(catSize * .66, 44),
                              painter: _FoodBowl(),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: catSize * .87,
                          left: width * .25,
                          width: width * .5,
                          child: IgnorePointer(
                            child: AnimatedBuilder(
                              animation: _life,
                              builder: (context, _) => Transform.translate(
                                offset: Offset(
                                  0,
                                  math.sin(_life.value * math.pi * 6) * 3,
                                ),
                                child: const Text(
                                  'ñam ñam ñam',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 16,
                                    color: Color(0xff785442),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                      if (churu)
                        Positioned(
                          bottom: catSize * .9,
                          left: width * .4,
                          child: IgnorePointer(
                            child: AnimatedBuilder(
                              animation: _life,
                              builder: (context, _) => Opacity(
                                opacity: math.sin(_life.value * math.pi).abs(),
                                child: Transform.translate(
                                  offset: Offset(
                                    _maruTurn ? -width * .15 : width * .15,
                                    -_life.value * 20,
                                  ),
                                  child: const Text(
                                    '♡  ♡',
                                    style: TextStyle(
                                      color: Color(0xffdb8eaa),
                                      fontSize: 22,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      if (yarn)
                        Positioned(
                          bottom: 21,
                          left: width * .4,
                          child: AnimatedBuilder(
                            animation: _life,
                            builder: (context, _) => Transform.translate(
                              offset: Offset(
                                math.sin(_life.value * math.pi * 2) *
                                    width *
                                    .14,
                                0,
                              ),
                              child: Transform.rotate(
                                angle: _life.value * math.pi * 4,
                                child: const Text(
                                  '🧶',
                                  style: TextStyle(fontSize: 29),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 7),
              Text(
                widget.onOpenCare == null
                    ? 'Tócalos para darles cariño · mantén pulsado y arrastra para moverlos'
                    : 'Dos toques en la casita para cuidar y vestir a tus gatos',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 10, color: Color(0xff69776d)),
              ),
            ],
          );
        },
      ),
    ),
  );
}

class _RoomThought extends StatelessWidget {
  final String text;
  final double width;
  final Color color;
  const _RoomThought({
    required this.text,
    required this.width,
    required this.color,
  });
  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    child: AnimatedSwitcher(
      duration: const Duration(milliseconds: 600),
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: Tween<double>(begin: .9, end: 1).animate(animation),
          child: child,
        ),
      ),
      child: Column(
        key: ValueKey(text),
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x15000000),
                  blurRadius: 8,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11,
                height: 1.3,
                fontWeight: FontWeight.w600,
                color: Color(0xff48574c),
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(left: 20),
              child: Text('●  •', style: TextStyle(color: color, fontSize: 13)),
            ),
          ),
        ],
      ),
    ),
  );
}

class _RoomBackdrop extends CustomPainter {
  final HouseLight light;
  _RoomBackdrop(this.light);
  @override
  void paint(Canvas c, Size s) {
    c.drawRect(
      Offset.zero & s,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [light.wallTop, light.wallBottom],
        ).createShader(Offset.zero & s),
    );
    final p = Paint()..color = light.floor;
    c.drawRect(Rect.fromLTWH(0, s.height - 38, s.width, 38), p);
    p
      ..color = const Color(0xffcda984).withValues(alpha: .35)
      ..strokeWidth = 1;
    for (var x = 0.0; x < s.width; x += 60) {
      c.drawLine(Offset(x, s.height - 38), Offset(x - 15, s.height), p);
    }
    c.drawOval(
      Rect.fromCenter(
        center: Offset(s.width / 2, s.height - 27),
        width: s.width * .75,
        height: 24,
      ),
      Paint()..color = const Color(0xffc7aaa1).withValues(alpha: .3),
    );
  }

  @override
  bool shouldRepaint(covariant _RoomBackdrop oldDelegate) =>
      oldDelegate.light != light;
}

class _WindowLandscape extends CustomPainter {
  final double t;
  final HouseLight light;
  _WindowLandscape(this.t, this.light);
  @override
  void paint(Canvas c, Size s) {
    c.save();
    c.clipRect(Offset.zero & s);
    c.drawRect(
      Offset.zero & s,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [light.skyTop, light.skyBottom],
        ).createShader(Offset.zero & s),
    );
    for (var n = 0; n < 11; n++) {
      final star = Offset(
        s.width * (.08 + ((n * 37) % 87) / 100),
        s.height * (.07 + ((n * 19) % 43) / 100),
      );
      // Keep a few distant stars steady; the rest shimmer at different rates.
      // Whole cycles keep the six-second animation loop seamless.
      final phase = n * 2.399;
      final shimmer =
          .5 +
          .5 *
              (.65 * math.sin(t * math.pi * 2 * (1 + n % 3) + phase) +
                  .35 * math.sin(t * math.pi * 2 * (3 + n % 2) + phase * 1.7));
      final brightness = n % 3 == 0 ? .72 : .3 + .7 * shimmer;
      final alpha = light.night * brightness;
      final radius = (n.isEven ? 1.1 : .7) * (.85 + brightness * .3);
      c.drawCircle(
        star,
        radius * 2.4,
        Paint()
          ..color = const Color(0xffc7dcff).withValues(alpha: alpha * .16)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.2),
      );
      final p = Paint()
        ..color = const Color(0xfffff0ce).withValues(alpha: alpha);
      c.drawCircle(star, radius, p);
      if (n % 3 != 0 && n.isEven) {
        final ray = radius * 2;
        final sparkle = Paint()
          ..color = const Color(0xffeef5ff).withValues(
            alpha: light.night * ((brightness - .65) / .35).clamp(0.0, 1.0),
          )
          ..strokeWidth = .6;
        c.drawLine(star - Offset(ray, 0), star + Offset(ray, 0), sparkle);
        c.drawLine(star - Offset(0, ray), star + Offset(0, ray), sparkle);
      }
    }
    final orb = Offset(s.width * .74, s.height * .23);
    c.drawCircle(
      orb,
      s.width * .085,
      Paint()
        ..color = const Color(0xffffd783).withValues(alpha: light.daylight),
    );
    c.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addOval(Rect.fromCircle(center: orb, radius: s.width * .09)),
        Path()..addOval(
          Rect.fromCircle(
            center: orb + Offset(s.width * .035, -s.width * .026),
            radius: s.width * .085,
          ),
        ),
      ),
      Paint()..color = const Color(0xfff9eed6).withValues(alpha: light.night),
    );
    // Staggered clouds travel upward and fade before looping invisibly.
    for (var n = 0; n < 4; n++) {
      final phase = (t + n * .25) % 1;
      final fadeIn = (phase / .18).clamp(0.0, 1.0);
      final fadeOut = ((1 - phase) / .25).clamp(0.0, 1.0);
      final cloud = Paint()
        ..color = Colors.white.withValues(
          alpha: .85 * fadeIn * fadeOut * light.daylight,
        );
      final x = s.width * (-.22 + phase * 1.44);
      final y = s.height * (.16 + (n % 3) * .12);
      final radius = s.width * (n.isEven ? .065 : .085);
      c.drawOval(
        Rect.fromCenter(
          center: Offset(x, y),
          width: radius * 4.3,
          height: radius * 1.6,
        ),
        cloud,
      );
      c.drawCircle(
        Offset(x - radius * .7, y - radius * .35),
        radius * .8,
        cloud,
      );
      c.drawCircle(Offset(x + radius * .35, y - radius * .55), radius, cloud);
    }
    c.drawPath(
      Path()
        ..moveTo(0, s.height * .65)
        ..quadraticBezierTo(
          s.width * .4,
          s.height * .25,
          s.width,
          s.height * .7,
        )
        ..lineTo(s.width, s.height)
        ..lineTo(0, s.height)
        ..close(),
      Paint()
        ..color = light.tint(const Color(0xff81b99a), const Color(0xff35465e)),
    );
    for (var n = 0; n < 5; n++) {
      final dx = s.width * n / 4;
      c.drawPath(
        Path()
          ..moveTo(dx, s.height * .43)
          ..lineTo(dx - 9, s.height * .83)
          ..lineTo(dx + 9, s.height * .83)
          ..close(),
        Paint()
          ..color = light.tint(
            const Color(0xff39765b),
            const Color(0xff253349),
          ),
      );
    }
    final frame = Paint()
      ..color = const Color(0xfff6eee2)
      ..strokeWidth = 3;
    c.drawLine(Offset(s.width / 2, 0), Offset(s.width / 2, s.height), frame);
    c.drawLine(
      Offset(0, s.height * .48),
      Offset(s.width, s.height * .48),
      frame,
    );
    c.restore();
  }

  @override
  bool shouldRepaint(covariant _WindowLandscape old) =>
      old.t != t || old.light != light;
}

class _LitterTray extends CustomPainter {
  final bool front;
  _LitterTray(this.front);
  @override
  void paint(Canvas c, Size s) {
    final p = Paint()
      ..color = front ? const Color(0xffa78abc) : const Color(0xffbea5cc);
    final rect = front
        ? Rect.fromLTWH(0, 29, s.width, 25)
        : Rect.fromLTWH(0, 8, s.width, 43);
    c.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(12)), p);
    if (!front) {
      c.drawOval(
        Rect.fromLTWH(5, 5, s.width - 10, 30),
        Paint()..color = const Color(0xffe3ca9c),
      );
      for (var n = 0; n < 12; n++) {
        c.drawCircle(
          Offset(10 + n * (s.width - 20) / 12, 17 + (n % 3) * 4),
          1,
          Paint()..color = const Color(0xffb79970),
        );
      }
    } else {
      c.drawLine(
        Offset(8, 31),
        Offset(s.width - 8, 31),
        Paint()
          ..color = const Color(0xffdac3e4)
          ..strokeWidth = 3,
      );
      c.drawOval(
        Rect.fromCenter(center: Offset(s.width / 2, 42), width: 13, height: 7),
        Paint()..color = const Color(0xffe4d1ed),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _LitterTray old) => old.front != front;
}

class _FloorShadows extends CustomPainter {
  final double catSize, t;
  final _RoomMoment moment;
  final bool maruTurn;
  _FloorShadows(this.catSize, this.moment, this.maruTurn, this.t);
  @override
  void paint(Canvas canvas, Size size) {
    for (final cat in CatKind.values) {
      if ((moment == _RoomMoment.litter || moment == _RoomMoment.food) &&
          (cat == CatKind.maru) == maruTurn) {
        continue;
      }
      final actor = moment == _RoomMoment.thoughts ? catSize * .82 : catSize;
      final side = cat == CatKind.maru ? 1.0 : -1.0;
      final cuddle = moment == _RoomMoment.cuddle
          ? math.sin(t * math.pi) * 8 * side
          : 0.0;
      final x =
          (cat == CatKind.maru ? 5 : size.width - catSize - 5) +
          actor / 2 +
          cuddle;
      final jumping = moment == _RoomMoment.yarn
          ? math.sin(t * math.pi * 4).abs()
          : 0.0;
      final shadow = Paint()
        ..color = const Color(
          0xff72543e,
        ).withValues(alpha: .16 - jumping * .05);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(x, size.height - 15),
          width: actor * (.64 - jumping * .08),
          height: actor * .035,
        ),
        shadow,
      );
      if (jumping < .2) {
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(x - actor * .13, size.height - 16),
            width: actor * .2,
            height: 2,
          ),
          Paint()..color = const Color(0xff72543e).withValues(alpha: .12),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _FloorShadows old) => true;
}

class _FoodBowl extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final bowl = Path()
      ..moveTo(3, 16)
      ..lineTo(size.width - 3, 16)
      ..quadraticBezierTo(size.width - 8, 42, size.width - 20, 42)
      ..lineTo(20, 42)
      ..quadraticBezierTo(8, 42, 3, 16)
      ..close();
    canvas.drawPath(bowl, Paint()..color = const Color(0xffdc999a));
    canvas.drawOval(
      Rect.fromLTWH(3, 6, size.width - 6, 22),
      Paint()..color = const Color(0xfff5d6bd),
    );
    canvas.drawOval(
      Rect.fromLTWH(9, 10, size.width - 18, 13),
      Paint()..color = const Color(0xffa77a52),
    );
    for (var n = 0; n < 14; n++) {
      canvas.drawCircle(
        Offset(13 + (n % 7) * (size.width - 26) / 7, 14 + (n ~/ 7) * 5),
        2.2,
        Paint()
          ..color = n.isEven
              ? const Color(0xffd9a969)
              : const Color(0xff795137),
      );
    }
    canvas.drawOval(
      Rect.fromCenter(center: Offset(size.width / 2, 34), width: 12, height: 6),
      Paint()..color = const Color(0xffffe3dc),
    );
  }

  @override
  bool shouldRepaint(covariant _FoodBowl oldDelegate) => false;
}

class _SandSparkles extends CustomPainter {
  final double t;
  _SandSparkles(this.t);
  @override
  void paint(Canvas c, Size s) {
    for (var n = 0; n < 8; n++) {
      final phase = (t * 4 + n / 8) % 1;
      c.drawCircle(
        Offset(
          s.width / 2 + (n.isEven ? -1 : 1) * phase * (15 + n * 3),
          s.height - phase * 35,
        ),
        1.4,
        Paint()..color = const Color(0xffb79970).withValues(alpha: 1 - phase),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SandSparkles old) => old.t != t;
}
