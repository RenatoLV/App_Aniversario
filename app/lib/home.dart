import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'game.dart';
import 'store.dart';
import 'cat_character.dart';
import 'backend.dart';

const ink = Color(0xff293f39),
    cream = Color(0xfffaf6ee),
    green = Color(0xff31594c);
const tileColors = [
  Color(0xfff3e8ff),
  Color(0xffff6482),
  Color(0xffffbd3c),
  Color(0xff38df8b),
  Color(0xff32c8ff),
  Color(0xffbd7cff),
  Color(0xffff7b36),
  Color(0xfff5e94f),
];
Color cardColor(int id) => tileColors[1 + id % (tileColors.length - 1)];
Color rarityColor(CardRarity rarity) => switch (rarity) {
  CardRarity.common => const Color(0xffbee7fa),
  CardRarity.epic => const Color(0xffbf67ff),
  CardRarity.legendary => const Color(0xffffd55e),
};

class RinconApp extends StatelessWidget {
  final GameStore store;
  const RinconApp({super.key, required this.store});
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Maruversario',
    theme: ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: cream,
      colorScheme: ColorScheme.fromSeed(seedColor: green, surface: cream),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontSize: 36,
          fontWeight: FontWeight.w800,
          color: ink,
          letterSpacing: -1.4,
        ),
        headlineSmall: TextStyle(fontWeight: FontWeight.w700, color: ink),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: cream,
        foregroundColor: ink,
        centerTitle: false,
      ),
    ),
    home: RinconHome(store: store),
  );
}

class RinconHome extends StatefulWidget {
  final GameStore store;
  const RinconHome({super.key, required this.store});
  @override
  State<RinconHome> createState() => _RinconHomeState();
}

class _RinconHomeState extends State<RinconHome>
    with SingleTickerProviderStateMixin {
  int page = 0;
  late final AnimationController _packAnimation;
  bool _openingPack = false;
  Map<String, dynamic>? _cloudMember;
  List<Map<String, dynamic>> _cloudScores = [];
  String? _cloudError;
  bool _cloudBusy = false;
  GameStore get s => widget.store;
  CatKind get _packCat => s.totalCards.isEven ? CatKind.lady : CatKind.maru;
  String get _packCatName => _packCat == CatKind.lady ? 'Lady' : 'Maru';

  @override
  void initState() {
    super.initState();
    _packAnimation = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3100),
    );
    _refreshCloud();
  }

  Future<void> _refreshCloud() async {
    if (!Backend.configured) return;
    try {
      final member = await Backend.membership();
      if (member != null) {
        await s.connectCloud(member['space_id'] as String);
      }
      final scores = member == null
          ? <Map<String, dynamic>>[]
          : await Backend.highscores();
      if (mounted) {
        setState(() {
          _cloudMember = member;
          _cloudScores = scores;
          _cloudError = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _cloudError = 'No pudimos conectar con Supabase.');
      }
    }
  }

  Future<void> _activateCloud() async {
    var nickname = '';
    var code = '';
    final submitted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Conectar este dispositivo'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Solo tendrás que usar tu código privado una vez. Después la app recordará este dispositivo.',
            ),
            const SizedBox(height: 12),
            TextField(
              onChanged: (value) => nickname = value,
              decoration: const InputDecoration(
                labelText: 'Tu nombre',
                hintText: 'Maru o Lady',
              ),
            ),
            TextField(
              onChanged: (value) => code = value,
              decoration: const InputDecoration(
                labelText: 'Código de activación',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Conectar'),
          ),
        ],
      ),
    );
    if (submitted != true) return;
    setState(() {
      _cloudBusy = true;
      _cloudError = null;
    });
    try {
      await Backend.activate(code, nickname);
      if (s.best > 0) await Backend.submitHighscore('blocks-v1', s.best);
      await _refreshCloud();
    } catch (_) {
      if (mounted) {
        setState(
          () => _cloudError = 'No se pudo activar. Revisa el código y que Supabase permita acceso anónimo.',
        );
      }
    } finally {
      if (mounted) setState(() => _cloudBusy = false);
    }
  }

  @override
  void dispose() {
    _packAnimation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: s,
    builder: (context, _) => Scaffold(
      appBar: AppBar(
        title: const _MaruversarioTitle(),
        actions: [
          Chip(
            avatar: const Icon(Icons.toll, size: 18),
            label: Text('${s.coins}'),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (s.saveError != null)
              MaterialBanner(
                content: Text(s.saveError!),
                actions: [
                  TextButton(
                    onPressed: s.save,
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 650),
                  child: [home(), packs(), collection(), notes()][page],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: page,
        onDestinationSelected: (i) => setState(() => page = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.cottage_outlined),
            selectedIcon: Icon(Icons.cottage),
            label: 'Inicio',
          ),
          NavigationDestination(
            icon: Icon(Icons.auto_awesome),
            label: 'Sobres',
          ),
          NavigationDestination(
            icon: Icon(Icons.style_outlined),
            label: 'Colección',
          ),
          NavigationDestination(
            icon: Icon(Icons.edit_note),
            label: 'Nuestro bloc',
          ),
        ],
      ),
    ),
  );

  Widget home() => ListView(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
    children: [
      const Text(
        'JUEGUITOS DE ANIVERSARIO CON COLECCIONABLES CHISTOSOS MUAK',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
          color: green,
        ),
      ),
      const SizedBox(height: 12),
      const _CatPlayScene(),
      if (Backend.configured) ...[
        const SizedBox(height: 18),
        Card(
          child: ListTile(
            leading: Icon(
              _cloudMember == null ? Icons.cloud_outlined : Icons.cloud_done,
              color: green,
            ),
            title: Text(
              _cloudMember == null
                  ? 'Conectar nuestro espacio'
                  : 'Conectado como ${_cloudMember!['nickname']}',
            ),
            subtitle: Text(
              _cloudError ??
                  (_cloudMember == null
                      ? 'Activación única, sin correo ni contraseña.'
                      : '${_cloudScores.length} récords compartidos · espacio privado'),
            ),
            trailing: _cloudBusy
                ? const CircularProgressIndicator()
                : (_cloudMember == null
                      ? const Icon(Icons.chevron_right)
                      : null),
            onTap: _cloudMember == null && !_cloudBusy ? _activateCloud : null,
          ),
        ),
        if (_cloudScores.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Text(
              _cloudScores
                  .where((row) => row['game'] == 'blocks-v1')
                  .map((row) => '${row['nickname']}: ${row['score']} puntos')
                  .join('   ·   '),
              style: const TextStyle(color: green, fontWeight: FontWeight.w700),
            ),
          ),
      ],
      const SizedBox(height: 24),
      Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: green,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'EL PLAN DE HOY',
                  style: TextStyle(
                    color: Color(0xffd9e4c4),
                    letterSpacing: 2,
                    fontSize: 10,
                  ),
                ),
                Icon(Icons.pets, color: Color(0xffe7c778), size: 42),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Bloques & bigotes',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Completa líneas. Gana moneditas.\nRécord local: ${s.best} puntos.',
              style: const TextStyle(color: Color(0xffe0e6dc), height: 1.5),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xffedd8a6),
                foregroundColor: ink,
              ),
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => BlockScreen(store: s),
                  ),
                );
                if (_cloudMember != null) {
                  try {
                    await Backend.submitHighscore('blocks-v1', s.best);
                    await _refreshCloud();
                  } catch (_) {
                    if (mounted) {
                      setState(
                        () => _cloudError = 'El récord está guardado aquí; falta sincronizarlo.',
                      );
                    }
                  }
                }
              },
              icon: const Icon(Icons.play_arrow),
              label: Text(
                s.game.score > 0 ? 'Continuar partida' : 'Vamos a jugar',
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 24),
      Wrap(
        spacing: 12,
        runSpacing: 8,
        children: [
          const Text(
            'Pequeñas alegrías',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: ink,
            ),
          ),
          Text(
            '${s.cards.length}/${cardNames.length} cartas',
            style: const TextStyle(color: green),
          ),
        ],
      ),
      const SizedBox(height: 12),
      Card(
        child: ListTile(
          contentPadding: const EdgeInsets.all(16),
          leading: const Icon(Icons.card_giftcard, color: green, size: 32),
          title: const Text('Una sorpresa para ti'),
          subtitle: const Text(
            'Abre tu primer sobre con las monedas de bienvenida.',
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => setState(() => page = 1),
        ),
      ),
      const SizedBox(height: 20),
      const Text(
        'LO QUE VIENE',
        style: TextStyle(fontSize: 10, letterSpacing: 2, color: green),
      ),
      const ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(Icons.favorite_border),
        title: Text('Flechitas de aniversario'),
        subtitle: Text('En preparación · mapas con formas especiales'),
        trailing: Icon(Icons.lock_outline, size: 18),
      ),
      const ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(Icons.grid_view),
        title: Text('Memoria de nosotros'),
        subtitle: Text('En preparación · parejas de recuerdos'),
        trailing: Icon(Icons.lock_outline, size: 18),
      ),
      const SizedBox(height: 12),
      const Text(
        'Tus partidas y cartas siguen guardándose en este dispositivo.\nEl espacio compartido se activa con un código privado.',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 11, color: Color(0xff748177), height: 1.6),
      ),
    ],
  );

  Future<void> _openPack() async {
    if (_openingPack || s.coins < 20) return;
    final opener = _packCat;
    setState(() => _openingPack = true);
    HapticFeedback.mediumImpact();
    await _packAnimation.forward(from: 0);
    final id = s.openPack();
    _packAnimation.reset();
    if (!mounted) return;
    setState(() => _openingPack = false);
    if (id == null) return;
    HapticFeedback.heavyImpact();
    await showDialog<void>(
      context: context,
      barrierColor: const Color(0xee120a31),
      builder: (context) => CardRevealDialog(
        cardId: id,
        copies: s.cards[id]!,
        total: s.totalCards,
        opener: opener,
        rarity: s.lastOpenedRarity,
      ),
    );
  }

  Widget packs() => ListView(
    padding: const EdgeInsets.all(24),
    children: [
      const Text(
        'Un poquito\nde sorpresa.',
        style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800, color: ink),
      ),
      const SizedBox(height: 8),
      const Text('Cada sobre guarda una carta para tu colección.'),
      const SizedBox(height: 14),
      _CatPair(
        compact: true,
        caption: 'Turno de $_packCatName · ¡a abrir!',
        action: CatAction.pack,
      ),
      const SizedBox(height: 32),
      Center(
        child: AnimatedBuilder(
          animation: _packAnimation,
          builder: (context, _) {
            final t = _packAnimation.value;
            final flare = Curves.easeOut.transform((t * 1.4).clamp(0.0, 1.0));
            final tear = ((t - .42) / .38).clamp(0.0, 1.0);
            return Transform.translate(
              offset: Offset(math.sin(t * math.pi * 12) * 8 * (1 - t), 0),
              child: Transform.scale(
                scale: 1 + math.sin(t * math.pi) * .09,
                child: SizedBox(
                  width: 250,
                  height: 286,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 216 + flare * 70,
                        height: 216 + flare * 70,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xff41d9ff)
                              .withValues(alpha: .32 * (1 - flare)),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xffa842ff)
                                  .withValues(alpha: .6 * (1 - flare)),
                              blurRadius: 56 + t * 30,
                              spreadRadius: 8 + t * 12,
                            ),
                          ],
                        ),
                      ),
                      Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.identity()
                          ..setEntry(3, 2, .0015)
                          ..rotateY(
                            t > .55
                                ? (t - .55) * math.pi * .72
                                : math.sin(t * math.pi * 2) * .12,
                          )
                          ..rotateZ(math.sin(t * math.pi * 4) * .035),
                        child: Container(
                          width: 202,
                          height: 258,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Color(0xffffd46b),
                                Color(0xffff6bb6),
                                Color(0xff8152ff),
                                Color(0xff372780),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: const Color(0xfffff0bb),
                              width: 2.4,
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x995b23bd),
                                blurRadius: 28,
                                offset: Offset(0, 15),
                              ),
                              BoxShadow(
                                color: Color(0x88fff7d5),
                                blurRadius: 12,
                                spreadRadius: -4,
                              ),
                            ],
                          ),
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Positioned.fill(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(22),
                                  child: CustomPaint(
                                    painter: HoloPatternPainter(progress: t),
                                  ),
                                ),
                              ),
                              Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.pets,
                                      size: 61,
                                      color: Colors.white,
                                    ),
                                    const SizedBox(height: 15),
                                    const Text(
                                      'COSITAS\nNUESTRAS',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 23,
                                        height: 1,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 2.5,
                                        color: Colors.white,
                                        shadows: [
                                          Shadow(
                                            color: Color(0xff48217b),
                                            blurRadius: 8,
                                            offset: Offset(0, 3),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xfffff3c7),
                                        borderRadius: BorderRadius.circular(30),
                                      ),
                                      child: const Text(
                                        '✨  EDICIÓN BRILLIBRILLI  ✨',
                                        style: TextStyle(
                                          fontSize: 8,
                                          fontWeight: FontWeight.w900,
                                          color: Color(0xff57278d),
                                          letterSpacing: 1,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Positioned(
                                left: 7,
                                right: 7,
                                top: 43,
                                child: Container(
                                  height: 4 + tear * 5,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xff56f8ff),
                                        Colors.white,
                                        Color(0xff5689ff),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Color(0xff53d9ff),
                                        blurRadius: 15,
                                        spreadRadius: 3,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              Positioned(
                                top: 0,
                                left: 0,
                                right: 0,
                                child: Opacity(
                                  opacity:
                                      (1 - ((t - .83) / .17).clamp(0.0, 1.0))
                                          .clamp(0.0, 1.0),
                                  child: Transform.translate(
                                    offset: Offset(
                                      (_packCat == CatKind.lady ? -1 : 1) *
                                          tear *
                                          25,
                                      -tear * 78,
                                    ),
                                    child: Transform.rotate(
                                      angle:
                                          (_packCat == CatKind.lady
                                              ? -.28
                                              : .28) *
                                          tear,
                                      child: ClipPath(
                                        clipper: _TornSealClipper(),
                                        child: Container(
                                          height: 52,
                                          decoration: const BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [
                                                Color(0xff3a2daf),
                                                Color(0xff3ea9f5),
                                                Color(0xffa954df),
                                              ],
                                            ),
                                          ),
                                          child: const Center(
                                            child: Text(
                                              '✦  COSITAS NUESTRAS  ✦',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w900,
                                                color: Colors.white,
                                                letterSpacing: 1,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              if (_openingPack)
                                Positioned.fill(
                                  child: IgnorePointer(
                                    child: CustomPaint(
                                      painter: PackSparklePainter(progress: t),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      if (_openingPack)
                        Positioned(
                          bottom: 0,
                          child: Opacity(
                            opacity: (1 - t).clamp(0.0, 1.0),
                            child: const Text(
                              '¡ABRIENDO!',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 19,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 2,
                                shadows: [
                                  Shadow(
                                    color: Color(0xffca4cff),
                                    blurRadius: 18,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      if (_openingPack)
                        Positioned(
                          right: _packCat == CatKind.lady
                              ? -5 + tear * 12
                              : null,
                          left: _packCat == CatKind.maru
                              ? -12 + tear * 12
                              : null,
                          top:
                              -46 +
                              Curves.easeInOut.transform(
                                    (t / .35).clamp(0.0, 1.0),
                                  ) *
                                  55,
                          child: Opacity(
                            opacity:
                                ((t / .12).clamp(0.0, 1.0) *
                                (1 - ((t - .8) / .2).clamp(0.0, 1.0))),
                            child: CatActor(
                              cat: _packCat,
                              size: 118,
                              action: CatAction.pack,
                              active: true,
                              packProgress: t,
                              showLabel: false,
                            ),
                          ),
                        ),
                      if (_openingPack && t > .25 && t < .78)
                        Positioned(
                          top: 37,
                          right: _packCat == CatKind.maru ? 18 : null,
                          left: _packCat == CatKind.lady ? 18 : null,
                          child: Opacity(
                            opacity: math
                                .sin((t - .25) / .53 * math.pi)
                                .clamp(0.0, 1.0),
                            child: Transform.rotate(
                              angle: _packCat == CatKind.maru ? -.3 : .3,
                              child: const Text(
                                '✦  ╱╱  ✦',
                                style: TextStyle(
                                  color: Color(0xffffe88b),
                                  fontSize: 25,
                                  fontWeight: FontWeight.w900,
                                  shadows: [
                                    Shadow(color: Colors.white, blurRadius: 12),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      if (_openingPack && t > .72)
                        Positioned(
                          top: 58 - ((t - .72) / .28) * 92,
                          child: Opacity(
                            opacity: ((t - .72) / .12).clamp(0.0, 1.0),
                            child: Transform.rotate(
                              angle: (1 - t) * .45,
                              child: Container(
                                width: 96,
                                height: 126,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xffffe577),
                                      Color(0xffff88d1),
                                      Color(0xff8e66ff),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(13),
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 3,
                                  ),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0xffffe577),
                                      blurRadius: 24,
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.pets,
                                  color: Colors.white,
                                  size: 42,
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
      const SizedBox(height: 28),
      FilledButton.icon(
        onPressed: s.coins < 20 || _openingPack ? null : _openPack,
        icon: Icon(_openingPack ? Icons.auto_awesome : Icons.card_giftcard),
        label: Text(
          _openingPack
              ? '¡Brillando tu sorpresa…!'
              : 'Abrir sobre · 20 monedas',
        ),
      ),
      const SizedBox(height: 16),
      Text(
        s.coins < 20
            ? 'Te faltan ${20 - s.coins} monedas. ¡Consíguelas jugando!'
            : '${cardNames.length - sampleCardCount} memes · misma probabilidad para todos.\nLas repetidas se conservan en tu colección.',
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 12, height: 1.6),
      ),
    ],
  );
  Widget collection() {
    final order = List<int>.generate(cardNames.length, (i) => i)
      ..sort((a, b) {
        final owned =
            (s.cards.containsKey(b) ? 1 : 0) - (s.cards.containsKey(a) ? 1 : 0);
        if (owned != 0) return owned;
        final quality =
            (s.rarities[b] ?? CardRarity.common).index -
            (s.rarities[a] ?? CardRarity.common).index;
        if (quality != 0) return quality;
        final sample =
            (a < sampleCardCount ? 1 : 0) - (b < sampleCardCount ? 1 : 0);
        return sample != 0 ? sample : a.compareTo(b);
      });
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Text(
          'Nuestros tesoros',
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w800,
            color: ink,
          ),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              '${s.cards.length} de ${cardNames.length} recuerdos descubiertos',
            ),
            _CollectionBadge(label: '+1', unlocked: s.totalCards >= 1),
            _CollectionBadge(label: '+6', unlocked: s.totalCards >= 6),
            _CollectionBadge(label: '+9', unlocked: s.totalCards >= 9),
          ],
        ),
        const SizedBox(height: 12),
        const _CatPair(
          compact: true,
          caption: 'Maru y Lady vigilan la colección.',
          action: CatAction.collection,
        ),
        const SizedBox(height: 24),
        LayoutBuilder(
          builder: (context, constraints) => GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: cardNames.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: constraints.maxWidth >= 1050
                  ? 5
                  : constraints.maxWidth >= 740
                  ? 4
                  : constraints.maxWidth >= 520
                  ? 3
                  : 2,
              childAspectRatio: .73,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemBuilder: (context, displayIndex) {
              final i = order[displayIndex];
              final unlocked = s.cards.containsKey(i);
              return InkWell(
                onTap: unlocked
                    ? () => showDialog<void>(
                        context: context,
                        builder: (_) => _InspectCardDialog(
                          cardId: i,
                          copies: s.cards[i]!,
                          rarity: s.rarities[i] ?? CardRarity.common,
                        ),
                      )
                    : null,
                borderRadius: BorderRadius.circular(20),
                child: _RarityFrame(
                  rarity: unlocked
                      ? s.rarities[i] ?? CardRarity.common
                      : CardRarity.common,
                  locked: !unlocked,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: unlocked
                              ? _CardArt(cardId: i)
                              : const Center(
                                  child: Text(
                                    '?',
                                    style: TextStyle(
                                      fontSize: 46,
                                      color: green,
                                    ),
                                  ),
                                ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          unlocked ? cardNames[i] : 'Por descubrir',
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: unlocked ? Colors.white : ink,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          unlocked
                              ? '${(s.rarities[i] ?? CardRarity.common).label.toUpperCase()}  ·  ×${s.cards[i]}'
                              : 'Abre un sobre',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: unlocked
                                ? rarityColor(
                                    s.rarities[i] ?? CardRarity.common,
                                  )
                                : ink,
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
      ],
    );
  }

  Future<void> editNote([PocketNote? note]) async {
    var draft = note?.text ?? '';
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(note == null ? 'Déjale algo bonito' : 'Editar nota'),
        content: TextFormField(
          initialValue: draft,
          onChanged: (value) => draft = value,
          maxLength: 300,
          maxLines: 4,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Hoy me acordé de ti porque…',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, draft.trim()),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) {
      PocketNote edited;
      if (note == null) {
        edited = PocketNote(
          result,
          .08 + (s.notes.length % 3) * .12,
          .05 + (s.notes.length % 4) * .18,
        );
        s.notes.add(edited);
      } else {
        note.text = result;
        edited = note;
      }
      s.saveNote(edited);
    }
  }

  Widget notes() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Nuestro bloc',
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w800,
                color: ink,
              ),
            ),
            Text(
              _cloudMember == null
                  ? 'Arrastra las notas. Tócalas para editar.\nConecta el espacio para compartirlas.'
                  : 'Arrastra las notas. Tócalas para editar.\nLos cambios se comparten entre ambos dispositivos.',
              style: const TextStyle(fontSize: 12, height: 1.5),
            ),
            const SizedBox(height: 8),
            const LaserMouse(),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => editNote(),
              icon: const Icon(Icons.add),
              label: const Text('Una notita'),
            ),
          ],
        ),
      ),
      Expanded(
        child: LayoutBuilder(
          builder: (context, c) {
            final maxX = (c.maxWidth - 170).clamp(0.0, double.infinity);
            final maxY = (c.maxHeight - 160).clamp(0.0, double.infinity);
            return Container(
              color: const Color(0xffeae8dc),
              child: Stack(
                children: [
                  if (s.notes.isEmpty)
                    const Center(
                      child: Text(
                        'Aquí empieza nuestro pequeño mural ♡',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  for (final n in s.notes)
                    Positioned(
                      left: n.x * maxX,
                      top: n.y * maxY,
                      child: GestureDetector(
                        onTap: () => editNote(n),
                        onPanUpdate: (d) => setState(() {
                          n.x = maxX == 0
                              ? 0
                              : (n.x + d.delta.dx / maxX).clamp(0.0, 1.0);
                          n.y = maxY == 0
                              ? 0
                              : (n.y + d.delta.dy / maxY).clamp(0.0, 1.0);
                        }),
                        onPanEnd: (_) => s.saveNote(n),
                        child: Container(
                          width: 170,
                          height: 160,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xffffe8ac),
                            borderRadius: BorderRadius.circular(4),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x18000000),
                                blurRadius: 8,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.favorite,
                                size: 15,
                                color: Color(0xffb77661),
                              ),
                              const SizedBox(height: 10),
                              Expanded(
                                child: Text(
                                  n.text,
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 5,
                                  style: const TextStyle(
                                    color: ink,
                                    fontSize: 14,
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
            );
          },
        ),
      ),
    ],
  );
}

class BlockScreen extends StatefulWidget {
  final GameStore store;
  const BlockScreen({super.key, required this.store});
  @override
  State<BlockScreen> createState() => _BlockScreenState();
}

class _BlockScreenState extends State<BlockScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _juice;
  Timer? _comboTimer;
  bool _showCombo = false;
  bool _gameOverShown = false;
  CatKind _clearCat = CatKind.lady;
  int? _hover;
  GameStore get store => widget.store;

  @override
  void initState() {
    super.initState();
    _juice = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && store.game.over) _showGameOver();
    });
  }

  @override
  void dispose() {
    _comboTimer?.cancel();
    _juice.dispose();
    super.dispose();
  }

  void _place(int x, int y) {
    if (!store.place(x, y)) {
      HapticFeedback.lightImpact();
      return;
    }
    _juice.forward(from: 0);
    if (store.game.lastClearedCount > 0) {
      _clearCat = _clearCat == CatKind.lady ? CatKind.maru : CatKind.lady;
      HapticFeedback.heavyImpact();
      _comboTimer?.cancel();
      setState(() => _showCombo = true);
      _comboTimer = Timer(const Duration(milliseconds: 1450), () {
        if (mounted) setState(() => _showCombo = false);
      });
    } else {
      HapticFeedback.selectionClick();
      setState(() => _showCombo = false);
    }
    if (store.game.over) {
      Future.delayed(
        Duration(milliseconds: store.game.lastClearedCount > 0 ? 1180 : 350),
        () {
          if (mounted && store.game.over) _showGameOver();
        },
      );
    }
  }

  Future<void> _showGameOver() async {
    if (_gameOverShown || !mounted) return;
    _gameOverShown = true;
    HapticFeedback.mediumImpact();
    final choice = await showDialog<int>(
      context: context,
      barrierColor: const Color(0xee130b2a),
      builder: (dialogContext) => _GameOverDialog(
        score: store.game.score,
        best: store.best,
        coins: store.coins,
        onAgain: () => Navigator.pop(dialogContext, 1),
        onHome: () => Navigator.pop(dialogContext, 2),
      ),
    );
    if (!mounted) return;
    if (choice == 1) {
      store.newGame();
      setState(() => _gameOverShown = false);
    } else if (choice == 2) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: store,
    builder: (context, _) {
      final g = store.game;
      return Scaffold(
        backgroundColor: const Color(0xff211342),
        appBar: AppBar(
          title: const Text(
            'BLOQUES & BIGOTES',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              letterSpacing: 1.4,
              color: Colors.white,
            ),
          ),
          backgroundColor: const Color(0xff38206c),
          foregroundColor: Colors.white,
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'PUNTUACIÓN',
                            style: TextStyle(
                              color: Color(0xffc1a9ff),
                              fontWeight: FontWeight.w800,
                              fontSize: 10,
                              letterSpacing: 2,
                            ),
                          ),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 220),
                            transitionBuilder: (child, animation) =>
                                ScaleTransition(scale: animation, child: child),
                            child: Text(
                              '${g.score}',
                              key: ValueKey(g.score),
                              style: const TextStyle(
                                fontSize: 34,
                                height: 1.2,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                shadows: [
                                  Shadow(
                                    color: Color(0xffa947ff),
                                    blurRadius: 16,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '🪙 ${store.coins}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: Color(0xffffdf7c),
                              fontSize: 17,
                            ),
                          ),
                          Text(
                            'RÉCORD  ${store.best}',
                            style: const TextStyle(
                              color: Color(0xffc1a9ff),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  _CatPair(
                    compact: true,
                    caption: '¡Zarpazo listo!',
                    action: CatAction.blocks,
                    active: _showCombo,
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 13,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xff342057),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xff644493)),
                    ),
                    child: Row(
                      children: [
                        const Text('🐾', style: TextStyle(fontSize: 20)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            g.selected == null
                                ? 'Arrastra una pieza al tablero o elígela y toca dónde colocarla.'
                                : '¡Esa pieza! Arrástrala o toca una casilla para hacerla encajar.',
                            style: const TextStyle(
                              color: Color(0xfff0e8ff),
                              fontSize: 12,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  AnimatedBuilder(
                    animation: _juice,
                    builder: (context, child) {
                      final t = _juice.value;
                      return Transform.translate(
                        offset: Offset(
                          math.sin(t * math.pi * 10) *
                              (1 - t) *
                              (g.lastClearedCount > 0 ? 7 : 3),
                          0,
                        ),
                        child: child,
                      );
                    },
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0xff5840a3),
                              Color(0xff26305f),
                              Color(0xff17456c),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: const Color(0xff8d73ff),
                            width: 2,
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x994d22c8),
                              blurRadius: 22,
                              offset: Offset(0, 9),
                            ),
                            BoxShadow(
                              color: Color(0x5545ddff),
                              blurRadius: 15,
                              spreadRadius: -4,
                            ),
                          ],
                        ),
                        child: Stack(
                          children: [
                            GridView.builder(
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: 64,
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 8,
                                    crossAxisSpacing: 3,
                                    mainAxisSpacing: 3,
                                  ),
                              itemBuilder: (context, i) {
                                final x = i % 8,
                                    y = i ~/ 8,
                                    selected = g.selected;
                                final canGhost =
                                    _hover != null &&
                                    selected != null &&
                                    g.tray[selected] != null &&
                                    g.fits(
                                      g.tray[selected]!,
                                      _hover! % 8,
                                      _hover! ~/ 8,
                                    );
                                final ghost =
                                    canGhost &&
                                    BlockGame.shapes[g.tray[selected]!].any(
                                      (c) =>
                                          _hover! % 8 + c.x == x &&
                                          _hover! ~/ 8 + c.y == y,
                                    );
                                return DragTarget<int>(
                                  onWillAcceptWithDetails: (details) {
                                    final slot = details.data;
                                    if (slot < 0 ||
                                        slot >= 3 ||
                                        g.tray[slot] == null) {
                                      return false;
                                    }
                                    store.selectPiece(slot);
                                    setState(() => _hover = i);
                                    return g.fits(g.tray[slot]!, x, y);
                                  },
                                  onLeave: (_) {
                                    if (_hover == i) {
                                      setState(() => _hover = null);
                                    }
                                  },
                                  onAcceptWithDetails: (details) {
                                    store.selectPiece(details.data);
                                    _place(x, y);
                                    setState(() => _hover = null);
                                  },
                                  builder: (context, candidates, rejected) => Semantics(
                                    label:
                                        'Casilla ${x + 1}, ${y + 1}${g.board[i] > 0 ? ', ocupada' : ''}',
                                    button: true,
                                    child: GestureDetector(
                                      onTap: () => _place(x, y),
                                      child: AnimatedContainer(
                                        key: ValueKey(
                                          'tile-$i-${g.board[i]}-${ghost ? 1 : 0}',
                                        ),
                                        duration: const Duration(
                                          milliseconds: 155,
                                        ),
                                        curve: Curves.easeOutBack,
                                        decoration: BoxDecoration(
                                          gradient: ghost
                                              ? const LinearGradient(
                                                  begin: Alignment.topLeft,
                                                  end: Alignment.bottomRight,
                                                  colors: [
                                                    Color(0xff92fff4),
                                                    Color(0xff32d9ff),
                                                    Color(0xff536cff),
                                                  ],
                                                )
                                              : g.board[i] > 0
                                              ? _gemGradient(g.board[i])
                                              : const LinearGradient(
                                                  begin: Alignment.topLeft,
                                                  end: Alignment.bottomRight,
                                                  colors: [
                                                    Color(0xff292249),
                                                    Color(0xff302650),
                                                  ],
                                                ),
                                          borderRadius: BorderRadius.circular(
                                            5,
                                          ),
                                          border: Border(
                                            top: BorderSide(
                                              color: ghost
                                                  ? Colors.white
                                                  : g.board[i] > 0
                                                  ? Colors.white.withValues(
                                                      alpha: .84,
                                                    )
                                                  : const Color(0xff473a71),
                                              width: ghost ? 2 : 1.2,
                                            ),
                                            left: BorderSide(
                                              color: ghost
                                                  ? Colors.white
                                                  : g.board[i] > 0
                                                  ? Colors.white.withValues(
                                                      alpha: .60,
                                                    )
                                                  : const Color(0xff413461),
                                              width: ghost ? 2 : 1,
                                            ),
                                            bottom: BorderSide(
                                              color: g.board[i] > 0
                                                  ? Colors.black.withValues(
                                                      alpha: .24,
                                                    )
                                                  : Colors.black.withValues(
                                                      alpha: .16,
                                                    ),
                                              width: 2,
                                            ),
                                            right: BorderSide(
                                              color: g.board[i] > 0
                                                  ? Colors.black.withValues(
                                                      alpha: .19,
                                                    )
                                                  : Colors.black.withValues(
                                                      alpha: .10,
                                                    ),
                                              width: 1.5,
                                            ),
                                          ),
                                          boxShadow: ghost || g.board[i] > 0
                                              ? [
                                                  BoxShadow(
                                                    color:
                                                        (ghost
                                                                ? const Color(
                                                                    0xff3affeb,
                                                                  )
                                                                : tileColors[g
                                                                      .board[i]])
                                                            .withValues(
                                                              alpha: .42,
                                                            ),
                                                    blurRadius: ghost ? 12 : 7,
                                                    spreadRadius: ghost ? 1 : 0,
                                                    offset: const Offset(0, 2),
                                                  ),
                                                ]
                                              : null,
                                        ),
                                        child: g.board[i] > 0
                                            ? Center(
                                                child: Icon(
                                                  Icons.pets,
                                                  size: 13,
                                                  color: Colors.white
                                                      .withValues(alpha: .48),
                                                ),
                                              )
                                            : ghost
                                            ? const Center(
                                                child: Icon(
                                                  Icons.pets,
                                                  size: 13,
                                                  color: Color(0xff294078),
                                                ),
                                              )
                                            : null,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                            Positioned.fill(
                              child: IgnorePointer(
                                child: AnimatedBuilder(
                                  animation: _juice,
                                  builder: (context, _) => CustomPaint(
                                    painter: _ClearingTilesPainter(
                                      progress: _juice.value,
                                      tiles: g.lastClearedTiles,
                                      rows: g.lastClearedRows,
                                      columns: g.lastClearedColumns,
                                    ),
                                    foregroundPainter: BoardSparkPainter(
                                      progress: _juice.value,
                                      seed: g.score,
                                      active:
                                          _juice.value > 0 && _juice.value < 1,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            if (g.lastClearedCount > 0)
                              Positioned.fill(
                                child: IgnorePointer(
                                  child: AnimatedBuilder(
                                    animation: _juice,
                                    builder: (context, _) {
                                      final t = _juice.value;
                                      final swipe = ((t - .15) / .51).clamp(
                                        0.0,
                                        1.0,
                                      );
                                      final opacity =
                                          (t / .13).clamp(0.0, 1.0) *
                                          (1 -
                                              ((t - .78) / .22).clamp(
                                                0.0,
                                                1.0,
                                              ));
                                      return LayoutBuilder(
                                        builder: (context, c) {
                                          final catSize = (c.maxWidth / 5)
                                              .clamp(68.0, 90.0);
                                          final row =
                                              g.lastClearedRows.isNotEmpty
                                              ? g.lastClearedRows.first
                                              : null;
                                          final col =
                                              g.lastClearedColumns.isNotEmpty
                                              ? g.lastClearedColumns.first
                                              : null;
                                          final left = row != null
                                              ? swipe * (c.maxWidth + catSize) -
                                                    catSize
                                              : (col! + .5) * c.maxWidth / 8 -
                                                    catSize * .5;
                                          final top = row != null
                                              ? (row + .5) * c.maxHeight / 8 -
                                                    catSize * .55
                                              : swipe *
                                                        (c.maxHeight +
                                                            catSize) -
                                                    catSize;
                                          return Stack(
                                            children: [
                                              Positioned(
                                                left: left,
                                                top: top,
                                                child: Opacity(
                                                  opacity: opacity.clamp(
                                                    0.0,
                                                    1.0,
                                                  ),
                                                  child: CatActor(
                                                    cat: _clearCat,
                                                    size: catSize,
                                                    action: CatAction.blocks,
                                                    active: true,
                                                    showLabel: false,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          );
                                        },
                                      );
                                    },
                                  ),
                                ),
                              ),
                            if (_showCombo)
                              Positioned(
                                top: 9,
                                left: 0,
                                right: 0,
                                child: Center(
                                  child: _ComboBanner(
                                    lines: g.lastClearedCount,
                                    combo: g.combo,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 13),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var t = 0; t < 3; t++)
                        Expanded(
                          child: Center(
                            child: SizedBox(
                              width: 92,
                              height: 82,
                              child: g.tray[t] == null
                                  ? const Center(
                                      child: Icon(
                                        Icons.check_circle,
                                        color: Color(0xff46e2ae),
                                        size: 25,
                                      ),
                                    )
                                  : Draggable<int>(
                                      data: t,
                                      onDragStarted: () => store.selectPiece(t),
                                      onDraggableCanceled: (_, _) =>
                                          setState(() => _hover = null),
                                      onDragEnd: (_) =>
                                          setState(() => _hover = null),
                                      feedback: Material(
                                        color: Colors.transparent,
                                        child: _PiecePreview(
                                          shape: g.tray[t]!,
                                          width: 70,
                                          height: 62,
                                          elevated: true,
                                        ),
                                      ),
                                      childWhenDragging: Opacity(
                                        opacity: .24,
                                        child: _pieceCard(g, t),
                                      ),
                                      child: _pieceCard(g, t),
                                    ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  if (g.over)
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xff452261),
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: const Color(0xffffb94e)),
                      ),
                      child: const Text(
                        '¡Buen intento, michi! No quedan movimientos. Tus monedas y tu récord se guardaron.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          height: 1.45,
                        ),
                      ),
                    ),
                  Center(
                    child: TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xff54e7f3),
                      ),
                      onPressed: () async {
                        if (g.score > 0 && !g.over) {
                          final yes = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('¿Empezar otra partida?'),
                              content: const Text(
                                'Conservas monedas y récord. Se vaciará este tablero.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, false),
                                  child: const Text('Seguir jugando'),
                                ),
                                FilledButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text('Nueva partida'),
                                ),
                              ],
                            ),
                          );
                          if (yes != true) return;
                        }
                        store.newGame();
                      },
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('NUEVA PARTIDA'),
                    ),
                  ),
                  const Text(
                    'ARRASTRA · ENCAJA · HAZ COMBO',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xffae9bd6),
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );

  Widget _pieceCard(BlockGame game, int index) {
    final shape = game.tray[index]!;
    final selected = game.selected == index;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 170),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: selected
              ? [const Color(0xffffda7a), const Color(0xffff9d41)]
              : [const Color(0xff39265e), const Color(0xff29224a)],
        ),
        border: Border.all(
          color: selected ? const Color(0xfffff1a2) : const Color(0xff7157a5),
          width: selected ? 2.5 : 1.3,
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          if (selected)
            const BoxShadow(
              color: Color(0xbbffbd44),
              blurRadius: 17,
              spreadRadius: 1,
            ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: Center(
              child: _PiecePreview(shape: shape, width: 62, height: 48),
            ),
          ),
          Text(
            'PIEZA ${index + 1}',
            style: TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
              color: selected
                  ? const Color(0xff492c54)
                  : const Color(0xffe9dcff),
            ),
          ),
        ],
      ),
    );
  }
}

LinearGradient _gemGradient(int value) {
  final c = tileColors[value];
  return LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color.lerp(c, Colors.white, .46)!,
      c,
      Color.lerp(c, Colors.black, .29)!,
    ],
  );
}

class _PiecePreview extends StatelessWidget {
  final int shape;
  final double width, height;
  final bool elevated;
  const _PiecePreview({
    required this.shape,
    required this.width,
    required this.height,
    this.elevated = false,
  });
  @override
  Widget build(BuildContext context) {
    final cells = BlockGame.shapes[shape];
    final maxX = cells.map((c) => c.x).reduce(math.max) + 1;
    final maxY = cells.map((c) => c.y).reduce(math.max) + 1;
    final side = math.min(width / maxX, height / maxY);
    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        alignment: Alignment.center,
        children: [
          for (final cell in cells)
            Positioned(
              left: (width - maxX * side) / 2 + cell.x * side,
              top: (height - maxY * side) / 2 + cell.y * side,
              child: Container(
                width: side - 2.5,
                height: side - 2.5,
                decoration: BoxDecoration(
                  gradient: _gemGradient(shape + 1),
                  borderRadius: BorderRadius.circular(math.max(3, side * .14)),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: .7),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: tileColors[shape + 1].withValues(
                        alpha: elevated ? .8 : .35,
                      ),
                      blurRadius: elevated ? 15 : 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _GameOverDialog extends StatelessWidget {
  final int score, best, coins;
  final VoidCallback onAgain, onHome;
  const _GameOverDialog({
    required this.score,
    required this.best,
    required this.coins,
    required this.onAgain,
    required this.onHome,
  });

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: Colors.transparent,
    insetPadding: const EdgeInsets.all(16),
    child: TweenAnimationBuilder<double>(
      tween: Tween(begin: .7, end: 1),
      duration: const Duration(milliseconds: 550),
      curve: Curves.elasticOut,
      builder: (context, value, child) =>
          Transform.scale(scale: value, child: child),
      child: Container(
        width: 350,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xff4a267d), Color(0xff241344)],
          ),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: const Color(0xffffda76), width: 2),
          boxShadow: const [
            BoxShadow(
              color: Color(0x997729c8),
              blurRadius: 36,
              spreadRadius: 4,
            ),
          ],
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'FIN DE PARTIDA',
                style: TextStyle(
                  color: Color(0xffffe78d),
                  fontSize: 25,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.3,
                ),
              ),
              const SizedBox(height: 5),
              const Text(
                'Maru y Lady te esperan para otra ronda',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xffe1d5f7), fontSize: 12),
              ),
              const SizedBox(height: 5),
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CatActor(
                    cat: CatKind.maru,
                    size: 88,
                    action: CatAction.blocks,
                    active: true,
                    showLabel: false,
                  ),
                  SizedBox(width: 18),
                  Icon(Icons.favorite, color: Color(0xffff91bd), size: 24),
                  SizedBox(width: 18),
                  CatActor(
                    cat: CatKind.lady,
                    size: 88,
                    action: CatAction.blocks,
                    active: true,
                    showLabel: false,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 13),
                decoration: BoxDecoration(
                  color: const Color(0xff291853),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xff8d72cd)),
                ),
                child: Column(
                  children: [
                    const Text(
                      'TUS PUNTOS',
                      style: TextStyle(
                        color: Color(0xffd5c7f5),
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                      ),
                    ),
                    Text(
                      '$score',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 53,
                        fontWeight: FontWeight.w900,
                        height: 1.05,
                      ),
                    ),
                    Text(
                      score >= best ? '✦ ¡NUEVO RÉCORD! ✦' : 'RÉCORD  $best',
                      style: const TextStyle(
                        color: Color(0xffffd56c),
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '🪙 $coins monedas guardadas',
                style: const TextStyle(
                  color: Color(0xffffe9ac),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xffffd96b),
                    foregroundColor: const Color(0xff3e225f),
                  ),
                  onPressed: onAgain,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text(
                    'OTRA PARTIDA',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
              TextButton(
                onPressed: onHome,
                child: const Text(
                  'Volver al rincón',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _ComboBanner extends StatelessWidget {
  final int lines, combo;
  const _ComboBanner({required this.lines, required this.combo});

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: .45, end: 1),
    duration: const Duration(milliseconds: 430),
    curve: Curves.elasticOut,
    builder: (context, value, child) =>
        Transform.scale(scale: value, child: child),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 19, vertical: 9),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xfffff37a), Color(0xffffa329), Color(0xffff579b)],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: const [
          BoxShadow(color: Color(0xbbff8b37), blurRadius: 20, spreadRadius: 2),
          BoxShadow(
            color: Color(0xdd2a1246),
            blurRadius: 4,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Text(
        combo > 1
            ? '¡COMBO x$combo! · $lines LÍNEAS'
            : '¡ZARPAZO! · $lines ${lines == 1 ? 'LÍNEA' : 'LÍNEAS'}',
        style: const TextStyle(
          color: Color(0xff491447),
          fontWeight: FontWeight.w900,
          fontSize: 15,
          letterSpacing: 1,
          shadows: [Shadow(color: Color(0x88ffffff), blurRadius: 5)],
        ),
      ),
    ),
  );
}

class _ClearingTilesPainter extends CustomPainter {
  final double progress;
  final Map<int, int> tiles;
  final List<int> rows, columns;
  const _ClearingTilesPainter({
    required this.progress,
    required this.tiles,
    required this.rows,
    required this.columns,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (tiles.isEmpty || progress >= 1) return;
    final cell = (size.width - 21) / 8;
    final step = cell + 3;
    final burst = ((progress - .42) / .58).clamp(0.0, 1.0);
    for (final tile in tiles.entries) {
      final x = tile.key % 8, y = tile.key ~/ 8;
      final rect = Rect.fromLTWH(x * step, y * step, cell, cell);
      final color = tileColors[tile.value];
      if (burst < .25) {
        final opacity = (1 - burst * 4).clamp(0.0, 1.0);
        final block = Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color.lerp(color, Colors.white, .38)!.withValues(alpha: opacity),
              color.withValues(alpha: opacity),
            ],
          ).createShader(rect);
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(5)),
          block,
        );
        canvas.drawLine(
          rect.topLeft.translate(3, 2),
          rect.topRight.translate(-3, 2),
          Paint()
            ..color = Colors.white.withValues(alpha: opacity * .8)
            ..strokeWidth = 2,
        );
        if (progress > .24) {
          final crack = Paint()
            ..color = Colors.white.withValues(alpha: (progress - .24) * 3)
            ..strokeWidth = 1.5;
          canvas.drawLine(rect.topCenter, rect.center.translate(-3, 2), crack);
          canvas.drawLine(
            rect.center.translate(-3, 2),
            rect.bottomRight.translate(-4, -2),
            crack,
          );
        }
      }
      if (burst > 0) {
        for (var shard = 0; shard < 4; shard++) {
          final angle = (tile.key * .7 + shard * math.pi / 2);
          final center = rect.center.translate(
            math.cos(angle) * burst * 28,
            math.sin(angle) * burst * 31,
          );
          final scale = (1 - burst) * cell * .28;
          final triangle = Path()
            ..moveTo(center.dx, center.dy - scale)
            ..lineTo(center.dx + scale, center.dy + scale)
            ..lineTo(center.dx - scale, center.dy + scale * .4)
            ..close();
          canvas.drawPath(
            triangle,
            Paint()..color = color.withValues(alpha: 1 - burst),
          );
        }
      }
    }
    final scan = ((progress - .16) / .48).clamp(0.0, 1.0);
    if (scan > 0 && scan < 1) {
      final glow = Paint()
        ..color = const Color(0xff4be7ff).withValues(alpha: 1 - scan * .3)
        ..strokeWidth = 12
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
      final core = Paint()
        ..color = Colors.white.withValues(alpha: 1 - scan * .3)
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round;
      for (final row in rows) {
        final y = (row + .5) * step;
        final end = Offset(size.width * scan, y);
        canvas.drawLine(Offset(0, y), end, glow);
        canvas.drawLine(Offset(0, y), end, core);
      }
      for (final column in columns) {
        final x = (column + .5) * step;
        final end = Offset(x, size.height * scan);
        canvas.drawLine(Offset(x, 0), end, glow);
        canvas.drawLine(Offset(x, 0), end, core);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ClearingTilesPainter old) =>
      old.progress != progress ||
      old.tiles != tiles ||
      old.rows != rows ||
      old.columns != columns;
}

class BoardSparkPainter extends CustomPainter {
  final double progress;
  final int seed;
  final bool active;
  const BoardSparkPainter({
    required this.progress,
    required this.seed,
    required this.active,
  });
  @override
  void paint(Canvas canvas, Size size) {
    if (!active) return;
    final rng = math.Random(seed);
    for (var i = 0; i < 34; i++) {
      final x = rng.nextDouble() * size.width;
      final startY = rng.nextDouble() * size.height;
      final y = startY - progress * (32 + rng.nextDouble() * 110);
      final radius = (1 + rng.nextDouble() * 3.8) * (1 - progress * .6);
      final colors = [
        const Color(0xffffe95c),
        const Color(0xff4ff8ff),
        const Color(0xffff7fe8),
        Colors.white,
      ];
      final p = Paint()
        ..color = colors[i % colors.length].withValues(
          alpha: (1 - progress).clamp(0.0, 1.0),
        );
      canvas.drawCircle(Offset(x, y), radius, p);
    }
  }

  @override
  bool shouldRepaint(covariant BoardSparkPainter old) =>
      old.progress != progress || old.active != active || old.seed != seed;
}

class HoloPatternPainter extends CustomPainter {
  final double progress;
  const HoloPatternPainter({required this.progress});
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = Colors.white.withValues(alpha: .22);
    for (var i = 0; i < 14; i++) {
      final x = ((i * 47.0 + progress * 240) % (size.width + 50)) - 25;
      final y = (i * 83.0) % size.height;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(.64);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, 0, i % 3 == 0 ? 3 : 1.4, 27),
          const Radius.circular(3),
        ),
        p,
      );
      canvas.restore();
    }
    final shine = Paint()
      ..shader = LinearGradient(
        begin: Alignment(-1.4 + progress * 3, -.9),
        end: Alignment(-.7 + progress * 3, .9),
        colors: [
          Colors.transparent,
          Colors.white.withValues(alpha: .34),
          Colors.transparent,
        ],
        stops: const [0, .5, 1],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, shine);
  }

  @override
  bool shouldRepaint(covariant HoloPatternPainter old) =>
      old.progress != progress;
}

class PackSparklePainter extends CustomPainter {
  final double progress;
  const PackSparklePainter({required this.progress});
  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(29);
    for (var i = 0; i < 27; i++) {
      final angle = rng.nextDouble() * math.pi * 2;
      final distance = 24 + progress * (92 + rng.nextDouble() * 100);
      final center = Offset(
        size.width / 2 + math.cos(angle) * distance,
        size.height / 2 + math.sin(angle) * distance,
      );
      final radius = (2 + rng.nextDouble() * 5) * (1 - progress * .45);
      final p = Paint()
        ..color =
            (i % 3 == 0
                    ? const Color(0xffffef7a)
                    : i.isEven
                    ? const Color(0xff75f7ff)
                    : const Color(0xffff95e5))
                .withValues(alpha: (1 - progress * .75).clamp(0.0, 1.0))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
      canvas.drawCircle(center, radius, p);
      canvas.drawLine(
        center.translate(-radius * 1.8, 0),
        center.translate(radius * 1.8, 0),
        p,
      );
      canvas.drawLine(
        center.translate(0, -radius * 1.8),
        center.translate(0, radius * 1.8),
        p,
      );
    }
  }

  @override
  bool shouldRepaint(covariant PackSparklePainter old) =>
      old.progress != progress;
}

class _TornSealClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final teeth = (size.width / 11).ceil();
    final edge = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, 43);
    for (var i = teeth; i >= 0; i--) {
      edge.lineTo(size.width * i / teeth, i.isEven ? 43 : 51);
    }
    return edge..close();
  }

  @override
  bool shouldReclip(covariant _TornSealClipper oldClipper) => false;
}

class _CollectionBadge extends StatelessWidget {
  final String label;
  final bool unlocked;
  const _CollectionBadge({required this.label, required this.unlocked});
  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 300),
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: unlocked ? const Color(0xffffe585) : const Color(0xffebe8e0),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(
        color: unlocked ? const Color(0xffffae45) : const Color(0xffd8d4c9),
      ),
    ),
    child: Text(
      unlocked ? '$label ✨' : label,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w900,
        color: unlocked ? const Color(0xff603584) : const Color(0xff948d9e),
      ),
    ),
  );
}

class _RarityFrame extends StatefulWidget {
  final CardRarity rarity;
  final bool locked;
  final bool forceShine;
  final Widget child;
  const _RarityFrame({
    required this.rarity,
    required this.child,
    this.locked = false,
    this.forceShine = false,
  });

  @override
  State<_RarityFrame> createState() => _RarityFrameState();
}

class _RarityFrameState extends State<_RarityFrame>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shine;
  @override
  void initState() {
    super.initState();
    _shine = AnimationController(
      vsync: this,
      duration: Duration(
        milliseconds: widget.rarity == CardRarity.legendary ? 2200 : 3500,
      ),
    );
    if ((widget.rarity != CardRarity.common || widget.forceShine) &&
        !widget.locked) {
      _shine.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant _RarityFrame oldWidget) {
    super.didUpdateWidget(oldWidget);
    final shouldShine =
        (widget.rarity != CardRarity.common || widget.forceShine) &&
        !widget.locked;
    if (shouldShine && !_shine.isAnimating) _shine.repeat();
    if (!shouldShine && _shine.isAnimating) _shine.stop();
  }

  @override
  void dispose() {
    _shine.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _shine,
    builder: (context, _) {
      final rare =
          (widget.rarity != CardRarity.common || widget.forceShine) &&
          !widget.locked;
      final glow = rarityColor(widget.rarity);
      return Container(
        decoration: BoxDecoration(
          gradient: widget.locked
              ? const LinearGradient(
                  colors: [Color(0xffeae9e1), Color(0xffe1dfd9)],
                )
              : widget.rarity == CardRarity.common
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xff344b68),
                    Color(0xff1d2944),
                    Color(0xff34556b),
                  ],
                )
              : LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color.lerp(glow, const Color(0xff261940), .45)!,
                    const Color(0xff261940),
                    Color.lerp(glow, const Color(0xff261940), .68)!,
                  ],
                ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: rare ? glow : const Color(0xffd4d3cf),
            width: widget.rarity == CardRarity.legendary && !widget.locked
                ? 3
                : 1.5,
          ),
          boxShadow: rare
              ? [
                  BoxShadow(
                    color: glow.withValues(
                      alpha: .22 + .16 * math.sin(_shine.value * math.pi).abs(),
                    ),
                    blurRadius: 14,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Stack(
            children: [
              widget.child,
              if (rare)
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: _CardShinePainter(
                        _shine.value,
                        glow,
                        widget.rarity == CardRarity.legendary ? .27 : .13,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    },
  );
}

class _CardShinePainter extends CustomPainter {
  final double progress, strength;
  final Color color;
  _CardShinePainter(this.progress, this.color, this.strength);
  @override
  void paint(Canvas canvas, Size size) {
    final x = (progress * 1.7 - .35) * size.width;
    final path = Path()
      ..moveTo(x - 30, 0)
      ..lineTo(x + 32, 0)
      ..lineTo(x - 20, size.height)
      ..lineTo(x - 82, size.height)
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          colors: [
            Colors.transparent,
            color.withValues(alpha: strength),
            Colors.white.withValues(alpha: strength * .55),
            Colors.transparent,
          ],
        ).createShader(Rect.fromLTWH(x - 82, 0, 114, size.height)),
    );
  }

  @override
  bool shouldRepaint(covariant _CardShinePainter old) =>
      progress != old.progress;
}

class _CardArt extends StatelessWidget {
  final int cardId;
  const _CardArt({required this.cardId});

  @override
  Widget build(BuildContext context) {
    final asset = cardAsset(cardId);
    if (asset == null) {
      return Center(
        child: Text(cardIcons[cardId], style: const TextStyle(fontSize: 62)),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: double.infinity,
        color: const Color(0xff281a43),
        child: Image.asset(
          asset,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.medium,
          errorBuilder: (_, _, _) => const Center(
            child: Icon(Icons.broken_image, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

class _InspectCardDialog extends StatefulWidget {
  final int cardId;
  final int copies;
  final CardRarity rarity;
  const _InspectCardDialog({
    required this.cardId,
    required this.copies,
    required this.rarity,
  });

  @override
  State<_InspectCardDialog> createState() => _InspectCardDialogState();
}

class _InspectCardDialogState extends State<_InspectCardDialog>
    with SingleTickerProviderStateMixin {
  double _turn = 0;
  double _tilt = 0;
  late final AnimationController _auto;
  Timer? _idle;
  double _spinBase = 0;

  @override
  void initState() {
    super.initState();
    _auto =
        AnimationController(vsync: this, duration: const Duration(seconds: 6))
          ..addListener(
            () => setState(() {
              _turn = _spinBase + _auto.value * math.pi * 2;
              _tilt = .16 * math.sin(_auto.value * math.pi * 2);
            }),
          );
    _scheduleSpin();
  }

  void _scheduleSpin() {
    _idle?.cancel();
    _idle = Timer(const Duration(seconds: 5), () {
      if (!mounted) return;
      _spinBase = _turn;
      _auto.repeat();
    });
  }

  void _touch() {
    _pauseSpin();
    _scheduleSpin();
  }

  void _pauseSpin() {
    _idle?.cancel();
    _auto.stop();
  }

  @override
  void dispose() {
    _idle?.cancel();
    _auto.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final front = math.cos(_turn) >= 0;
    final card = Container(
      width: 270,
      height: 355,
      decoration: BoxDecoration(
        gradient: front
            ? LinearGradient(
                colors: [
                  Color.lerp(cardColor(widget.cardId), Colors.white, .48)!,
                  cardColor(widget.cardId),
                  const Color(0xff49317b),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : const LinearGradient(
                colors: [Color(0xff563394), Color(0xff211246)],
              ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: rarityColor(widget.rarity), width: 4),
        boxShadow: [
          BoxShadow(
            color: rarityColor(widget.rarity).withValues(alpha: .6),
            blurRadius: 30,
          ),
        ],
      ),
      child: front
          ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                    child: _CardArt(cardId: widget.cardId),
                  ),
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Text(
                    cardNames[widget.cardId],
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                      shadows: [
                        Shadow(color: Color(0xff321453), blurRadius: 8),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'COSITAS NUESTRAS · VOL. 01',
                  style: TextStyle(
                    color: Color(0xfffff0bf),
                    fontSize: 10,
                    letterSpacing: 1,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '×${widget.copies}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
              ],
            )
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.pets, color: Color(0xffffe79b), size: 92),
                SizedBox(height: 22),
                Text(
                  'MARU & LADY',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Un recuerdo para guardar',
                  style: TextStyle(color: Color(0xffffe79b), fontSize: 13),
                ),
              ],
            ),
    );
    return Dialog(
      backgroundColor: const Color(0xff21183e),
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 16, 12, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${widget.rarity.label} · Tu carta',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white),
                    tooltip: 'Cerrar',
                  ),
                ],
              ),
              const SizedBox(height: 10),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onHorizontalDragStart: (_) => _pauseSpin(),
                onHorizontalDragEnd: (_) => _scheduleSpin(),
                onVerticalDragStart: (_) => _pauseSpin(),
                onVerticalDragEnd: (_) => _scheduleSpin(),
                onHorizontalDragUpdate: (details) =>
                    setState(() => _turn += details.delta.dx * .015),
                onVerticalDragUpdate: (details) => setState(
                  () => _tilt = (_tilt - details.delta.dy * .007).clamp(
                    -.35,
                    .35,
                  ),
                ),
                child: Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, .0012)
                    ..rotateX(_tilt)
                    ..rotateY(front ? _turn : _turn + math.pi),
                  child: _RarityFrame(
                    rarity: widget.rarity,
                    forceShine: _auto.isAnimating,
                    child: card,
                  ),
                ),
              ),
              const SizedBox(height: 40),
              const Text(
                'Desliza a los lados para girarla 360°',
                style: TextStyle(color: Color(0xffffe79b), fontSize: 12),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: () {
                      _touch();
                      setState(() => _turn -= math.pi / 2);
                    },
                    icon: const Icon(Icons.rotate_left, color: Colors.white),
                    tooltip: 'Girar a la izquierda',
                  ),
                  IconButton(
                    onPressed: () {
                      _touch();
                      setState(() => _turn += math.pi / 2);
                    },
                    icon: const Icon(Icons.rotate_right, color: Colors.white),
                    tooltip: 'Girar a la derecha',
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

class CardRevealDialog extends StatefulWidget {
  final int cardId, copies, total;
  final CatKind opener;
  final CardRarity rarity;
  const CardRevealDialog({
    super.key,
    required this.cardId,
    required this.copies,
    required this.total,
    required this.opener,
    required this.rarity,
  });

  @override
  State<CardRevealDialog> createState() => _CardRevealDialogState();
}

class _CardRevealDialogState extends State<CardRevealDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _foil;
  double _pointerX = 0;
  double _pointerY = 0;

  void _tiltCard(Offset position) {
    setState(() {
      _pointerY = ((position.dx - 105) / 105).clamp(-1.0, 1.0) * .24;
      _pointerX = ((132 - position.dy) / 132).clamp(-1.0, 1.0) * .20;
    });
  }

  void _resetTilt() => setState(() {
    _pointerX = 0;
    _pointerY = 0;
  });
  int get cardId => widget.cardId;
  int get copies => widget.copies;
  int get total => widget.total;

  @override
  void initState() {
    super.initState();
    _foil = AnimationController(
      vsync: this,
      duration: Duration(
        milliseconds: widget.rarity == CardRarity.legendary ? 850 : 1850,
      ),
    )..repeat();
  }

  @override
  void dispose() {
    _foil.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final milestone = total == 1 || total == 6 || total == 9 ? '+$total' : '+1';
    final bonus = total == 6 || total == 9;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(18),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: -math.pi / 2, end: 0),
        duration: const Duration(milliseconds: 720),
        curve: Curves.easeOutBack,
        builder: (context, angle, child) {
          final turn = angle.abs() < .15 ? 0.0 : angle;
          return Transform(
            transform: Matrix4.identity()
              ..setEntry(3, 2, .0015)
              ..rotateY(turn),
            alignment: Alignment.center,
            child: child,
          );
        },
        child: Container(
          width: 340,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xff49277c), Color(0xff201447)],
            ),
            borderRadius: BorderRadius.circular(27),
            border: Border.all(color: const Color(0xffffdf78), width: 2),
            boxShadow: const [
              BoxShadow(
                color: Color(0xbb9f39ff),
                blurRadius: 35,
                spreadRadius: 3,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.rarity == CardRarity.legendary
                    ? '✦ ¡LEGENDARIA! ✦'
                    : widget.rarity == CardRarity.epic
                    ? '✦ ¡ÉPICA! ✦'
                    : '¡NUEVA CARTA!',
                style: TextStyle(
                  color: rarityColor(widget.rarity),
                  fontWeight: FontWeight.w900,
                  fontSize: 19,
                  letterSpacing: 2,
                  shadows: [Shadow(color: Color(0xfffc57e5), blurRadius: 12)],
                ),
              ),
              const SizedBox(height: 5),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CatActor(
                    cat: widget.opener,
                    size: 54,
                    action: CatAction.pack,
                    active: true,
                    showLabel: false,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'La abrió ${widget.opener == CatKind.lady ? 'Lady' : 'Maru'}',
                    style: const TextStyle(
                      color: Color(0xffffedbe),
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              MouseRegion(
                onHover: (event) => _tiltCard(event.localPosition),
                onExit: (_) => _resetTilt(),
                child: Listener(
                  onPointerMove: (event) => _tiltCard(event.localPosition),
                  onPointerUp: (_) => _resetTilt(),
                  child: AnimatedBuilder(
                    animation: _foil,
                    builder: (context, child) {
                      final orbit = _foil.value * math.pi * 2;
                      return Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.identity()
                          ..setEntry(3, 2, .0018)
                          ..rotateX(_pointerX + math.sin(orbit) * .075)
                          ..rotateY(_pointerY + math.cos(orbit) * .12)
                          ..rotateZ(math.sin(orbit + .8) * .025),
                        child: child,
                      );
                    },
                    child: _RarityFrame(
                      rarity: widget.rarity,
                      child: Container(
                        width: 210,
                        height: 265,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color.lerp(cardColor(cardId), Colors.white, .48)!,
                              cardColor(cardId),
                              const Color(0xff49317b),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: rarityColor(widget.rarity),
                            width: 3,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: cardColor(cardId).withValues(alpha: .65),
                              blurRadius: 25,
                              spreadRadius: 1,
                            ),
                            const BoxShadow(
                              color: Color(0xff21123e),
                              blurRadius: 9,
                              offset: Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: AnimatedBuilder(
                                animation: _foil,
                                builder: (context, _) => CustomPaint(
                                  painter: HoloPatternPainter(
                                    progress: _foil.value,
                                  ),
                                ),
                              ),
                            ),
                            Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    height: 172,
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                      ),
                                      child: _CardArt(cardId: cardId),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                    ),
                                    child: Text(
                                      cardNames[cardId],
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w900,
                                        shadows: [
                                          Shadow(
                                            color: Color(0xff321453),
                                            blurRadius: 8,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  const Text(
                                    'COSITAS NUESTRAS · VOL. 01',
                                    style: TextStyle(
                                      color: Color(0xfffff0bf),
                                      fontSize: 8,
                                      letterSpacing: 1.2,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Positioned(
                              right: 9,
                              top: 9,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 9,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xff3a206d),
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                child: Text(
                                  '×$copies',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
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
              ),
              const SizedBox(height: 17),
              Text(
                '$milestone CARTA${total == 1 ? '' : 'S'} ${total == 6 || total == 9 ? 'EN LA COLECCIÓN' : 'A LA COLECCIÓN'}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xffffefb0),
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  letterSpacing: .7,
                  shadows: [Shadow(color: Color(0xffff72d6), blurRadius: 11)],
                ),
              ),
              if (bonus)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    total == 6
                        ? '¡Colección en marcha! Ya juntaste 6 cartas.'
                        : '¡Increíble! Ya llevas 9 cartas en total.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xffddd2ff),
                      fontSize: 12,
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xffffdc70),
                  foregroundColor: const Color(0xff452278),
                ),
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.auto_awesome),
                label: const Text(
                  'A LA COLECCIÓN',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MaruversarioTitle extends StatefulWidget {
  const _MaruversarioTitle();

  @override
  State<_MaruversarioTitle> createState() => _MaruversarioTitleState();
}

class _MaruversarioTitleState extends State<_MaruversarioTitle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, child) {
      final bob = math.sin(_controller.value * math.pi) * 4;
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Transform.translate(
            offset: Offset(0, -bob),
            child: const Text('🎈', style: TextStyle(fontSize: 22)),
          ),
          const SizedBox(width: 5),
          const Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                'Maruversario',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20),
              ),
            ),
          ),
          const SizedBox(width: 5),
          Transform.translate(
            offset: Offset(0, bob - 4),
            child: const Text('🎈', style: TextStyle(fontSize: 22)),
          ),
        ],
      );
    },
  );
}

enum _CatMoment { together, churu, litter, thoughts }

class _CatPlayScene extends StatefulWidget {
  const _CatPlayScene();

  @override
  State<_CatPlayScene> createState() => _CatPlaySceneState();
}

class _CatPlaySceneState extends State<_CatPlayScene> {
  Timer? _sceneTimer;
  Timer? _detailTimer;
  _CatMoment _moment = _CatMoment.together;
  int _turn = 0;
  bool _maruEats = true;
  bool _maruDigs = true;
  int _thoughtTurn = 0;

  @override
  void initState() {
    super.initState();
    _sceneTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      if (!mounted) return;
      setState(() {
        _turn++;
        _moment = _CatMoment.values[_turn % _CatMoment.values.length];
      });
    });
    _detailTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (mounted &&
          (_moment == _CatMoment.churu ||
              _moment == _CatMoment.thoughts ||
              _moment == _CatMoment.litter)) {
        setState(() {
          _maruEats = !_maruEats;
          _maruDigs = !_maruDigs;
          _thoughtTurn++;
        });
      }
    });
  }

  @override
  void dispose() {
    _sceneTimer?.cancel();
    _detailTimer?.cancel();
    super.dispose();
  }

  void _show(_CatMoment moment) => setState(() => _moment = moment);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(12, 18, 12, 16),
    decoration: BoxDecoration(
      color: const Color(0xfffffdf8),
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: const Color(0xffe7dfcf)),
    ),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final actorSize = math.min(205.0, (constraints.maxWidth - 16) / 2);
        final sceneHeight = (MediaQuery.sizeOf(context).height * .47).clamp(
          340.0,
          480.0,
        );
        final churu = _moment == _CatMoment.churu;
        final litter = _moment == _CatMoment.litter;
        final thoughts = _moment == _CatMoment.thoughts;
        return Column(
          children: [
            Container(
              height: 32,
              alignment: Alignment.center,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Text(
                  switch (_moment) {
                    _CatMoment.together => '🐾 Maru y Lady se hacen compañía',
                    _CatMoment.churu => '🥰 ¡Churu para compartir!',
                    _CatMoment.litter =>
                      _maruDigs
                          ? '🧹 Maru escarba, Lady espera su turno'
                          : '🧹 Lady escarba, Maru vigila',
                    _CatMoment.thoughts => '💭 ¿Qué estarán pensando?',
                  },
                  key: ValueKey(_moment),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: green,
                  ),
                ),
              ),
            ),
            Stack(
              alignment: Alignment.bottomCenter,
              children: [
                SizedBox(width: double.infinity, height: sceneHeight),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: const Color(0xfff3ecde),
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
                Positioned(
                  top: 12,
                  left: 18,
                  child: Text(
                    '🪴',
                    style: TextStyle(fontSize: actorSize * .24),
                  ),
                ),
                Positioned(
                  top: 10,
                  right: 16,
                  child: Text(
                    '🖼️',
                    style: TextStyle(fontSize: actorSize * .23),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 28,
                    decoration: const BoxDecoration(
                      color: Color(0xffe4d4bd),
                      borderRadius: BorderRadius.vertical(
                        bottom: Radius.circular(20),
                      ),
                    ),
                  ),
                ),
                if (thoughts)
                  Positioned(
                    top: 54,
                    left: 14,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 450),
                      child: _ThoughtBubble(
                        key: ValueKey('maru-$_thoughtTurn'),
                        thought: _thoughtTurn.isEven
                            ? '🐟  ¡un pescadito!'
                            : '💛  Lady y yo',
                        color: const Color(0xffe9f3ff),
                      ),
                    ),
                  ),
                if (thoughts)
                  Positioned(
                    top: 88,
                    right: 14,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 450),
                      child: _ThoughtBubble(
                        key: ValueKey('lady-$_thoughtTurn'),
                        thought: _thoughtTurn.isEven
                            ? '🧶  ¡a jugar!'
                            : '🐾  ¿Dónde está Maru?',
                        color: const Color(0xffffe9f0),
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 42, 4, 18),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      AnimatedSlide(
                        offset: Offset(litter && _maruDigs ? .16 : 0, 0),
                        duration: const Duration(milliseconds: 550),
                        curve: Curves.easeInOut,
                        child: CatActor(
                          cat: CatKind.maru,
                          size: actorSize,
                          active:
                              churu ||
                              litter ||
                              (_moment == _CatMoment.together),
                          feeding: churu && _maruEats,
                          digging: litter && _maruDigs,
                          focus: 1,
                          movable: true,
                          onPet: () => _show(_CatMoment.together),
                        ),
                      ),
                      AnimatedSlide(
                        offset: Offset(litter && !_maruDigs ? -.16 : 0, 0),
                        duration: const Duration(milliseconds: 550),
                        curve: Curves.easeInOut,
                        child: CatActor(
                          cat: CatKind.lady,
                          size: actorSize,
                          active:
                              churu ||
                              litter ||
                              (_moment == _CatMoment.together),
                          feeding: churu && !_maruEats,
                          digging: litter && !_maruDigs,
                          focus: -1,
                          movable: true,
                          onPet: () => _show(_CatMoment.together),
                        ),
                      ),
                    ],
                  ),
                ),
                if (litter)
                  Positioned(
                    bottom: 7,
                    child: Column(
                      children: [
                        AnimatedSlide(
                          offset: Offset(_maruDigs ? -.25 : .25, 0),
                          duration: const Duration(milliseconds: 500),
                          child: const Text(
                            '✦  ·  ✦',
                            style: TextStyle(
                              color: Color(0xffa28266),
                              fontSize: 22,
                            ),
                          ),
                        ),
                        Container(
                          width: 118,
                          height: 40,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: const Color(0xffb49bca),
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(9),
                              bottom: Radius.circular(17),
                            ),
                            border: Border.all(
                              color: const Color(0xff806898),
                              width: 3,
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x44000000),
                                blurRadius: 6,
                                offset: Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Container(
                            width: 99,
                            height: 16,
                            decoration: BoxDecoration(
                              color: const Color(0xffd6c1a2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Center(
                              child: Text(
                                '·  ·  ·  ·',
                                style: TextStyle(
                                  color: Color(0xff8d7257),
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 6,
              runSpacing: 4,
              children: [
                for (final (moment, icon, label) in [
                  (_CatMoment.together, '🐾', 'Juntos'),
                  (_CatMoment.churu, '🥢', 'Churu'),
                  (_CatMoment.litter, '🧹', 'Baño'),
                  (_CatMoment.thoughts, '💭', 'Pensamientos'),
                ])
                  ActionChip(
                    avatar: Text(icon),
                    label: Text(label),
                    onPressed: () => _show(moment),
                  ),
              ],
            ),
            const SizedBox(height: 3),
            const Text(
              'Acarícialos · arrástralos · dos toques para dormir (despiertan solos)',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: Color(0xff69776d)),
            ),
          ],
        );
      },
    ),
  );
}

class _ThoughtBubble extends StatelessWidget {
  final String thought;
  final Color color;
  const _ThoughtBubble({super.key, required this.thought, required this.color});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xffd8d2cf)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x19000000),
              blurRadius: 6,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Text(
          thought,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: ink,
          ),
        ),
      ),
      const Padding(
        padding: EdgeInsets.only(left: 20, top: 3),
        child: Text(
          '◦',
          style: TextStyle(fontSize: 20, height: .7, color: green),
        ),
      ),
      const Padding(
        padding: EdgeInsets.only(left: 11),
        child: Text(
          '·',
          style: TextStyle(fontSize: 22, height: .6, color: green),
        ),
      ),
    ],
  );
}

class _CatPair extends StatelessWidget {
  final bool compact;
  final String? caption;
  final CatAction action;
  final bool active;
  const _CatPair({
    this.compact = false,
    this.caption,
    this.action = CatAction.idle,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.symmetric(
      horizontal: compact ? 10 : 12,
      vertical: compact ? 6 : 18,
    ),
    decoration: BoxDecoration(
      color: const Color(0xfffffdf8),
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: const Color(0xffe7dfcf)),
    ),
    child: compact
        ? Row(
            children: [
              CatActor(
                cat: CatKind.maru,
                size: 62,
                action: action,
                active: active,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      caption ?? 'Maru & Lady',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: ink,
                      ),
                    ),
                    const SizedBox(height: 3),
                    const Text(
                      'Tócalos y mira qué hacen 🐾',
                      style: TextStyle(fontSize: 10, color: Color(0xff69776d)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              CatActor(
                cat: CatKind.lady,
                size: 62,
                action: action,
                active: active,
              ),
            ],
          )
        : LayoutBuilder(
            builder: (context, constraints) {
              final actorSize = math.min(
                185.0,
                (constraints.maxWidth - 30) / 2,
              );
              return Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      CatActor(
                        cat: CatKind.maru,
                        size: actorSize,
                        action: action,
                        active: active,
                        movable: action == CatAction.idle,
                      ),
                      const Icon(
                        Icons.favorite,
                        color: Color(0xffef8eaa),
                        size: 27,
                      ),
                      CatActor(
                        cat: CatKind.lady,
                        size: actorSize,
                        action: action,
                        active: active,
                        movable: action == CatAction.idle,
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    caption ?? 'Maru & Lady',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: ink,
                    ),
                  ),
                  Text(
                    action == CatAction.idle
                        ? 'Tócalos para acariciar · mantén pulsado y arrastra · dos toques para dormir'
                        : 'Tócalos y mira qué hacen 🐾',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, color: Color(0xff69776d)),
                  ),
                ],
              );
            },
          ),
  );
}

class LaserMouse extends StatefulWidget {
  const LaserMouse({super.key});
  @override
  State<LaserMouse> createState() => _LaserMouseState();
}

class _LaserMouseState extends State<LaserMouse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _run;
  @override
  void initState() {
    super.initState();
    _run = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1750),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _run.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _run,
    builder: (context, _) => Row(
      children: [
        CatActor(
          cat: CatKind.lady,
          size: 76,
          action: CatAction.notes,
          active: _run.value < .35,
          focus: 1,
        ),
        const SizedBox(width: 4),
        Expanded(
          child: LayoutBuilder(
            builder: (context, c) {
              final travel = (c.maxWidth - 24).clamp(0.0, double.infinity);
              return SizedBox(
                height: 84,
                child: Stack(
                  children: [
                    Positioned(
                      left: 0,
                      right: 0,
                      top: 48,
                      child: Container(
                        height: 1,
                        color: const Color(0x557a5964),
                      ),
                    ),
                    Positioned(
                      left: travel * _run.value,
                      top: 32 + math.sin(_run.value * math.pi * 2) * 7,
                      child: const Icon(
                        Icons.mouse,
                        size: 19,
                        color: Color(0xff76635e),
                      ),
                    ),
                    Positioned(
                      left: travel * _run.value + 14,
                      top: 40,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xffff4d65),
                          boxShadow: [
                            BoxShadow(
                              color: Color(0xffff4d65),
                              blurRadius: 9,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(width: 4),
        CatActor(
          cat: CatKind.maru,
          size: 76,
          action: CatAction.notes,
          active: _run.value > .65,
          focus: -1,
        ),
      ],
    ),
  );
}
