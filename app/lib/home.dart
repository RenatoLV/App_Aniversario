import 'bloc_drawing.dart';
import 'bloc_board.dart';
import 'bloc_people.dart';
import 'paw_background.dart';
import 'block_blaster_background.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import 'game.dart';
import 'store.dart';
import 'cat_character.dart';
import 'backend.dart';
import 'wordle.dart';
import 'game_result.dart';
import 'brand_title.dart';
import 'card_trades.dart';
import 'sweet_screen.dart';
import 'cat_room.dart';
import 'leap_screen.dart';
import 'card_palette.dart';
import 'card_ar.dart';
import 'card_ar_photo_review.dart';
import 'game_leaderboard.dart';
import 'menu_swipe.dart';
import 'collection_album.dart';
import 'pack_opening.dart';
import 'game_audio.dart';
import 'app_updates.dart';
import 'cat_care_screen.dart';
import 'card_media.dart';
import 'celestial_reveal.dart';
import 'bomber/bomber_screen.dart';

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
  CardRarity.uncommon => const Color(0xff83e4ae),
  CardRarity.rare => const Color(0xff5fafff),
  CardRarity.mythic => const Color(0xffff83be),
  CardRarity.celestial => const Color(0xffa0fff2),
};

enum _CollectionSort { rarity, name, copies }

class CoinIcon extends StatelessWidget {
  final double size;
  const CoinIcon({super.key, this.size = 20});

  @override
  Widget build(BuildContext context) => Image.asset(
    'assets/moneda.gif',
    width: size,
    height: size,
    fit: BoxFit.contain,
    filterQuality: FilterQuality.high,
    cacheWidth: (size * MediaQuery.devicePixelRatioOf(context)).ceil(),
  );
}

class RinconApp extends StatelessWidget {
  final GameStore store;
  const RinconApp({super.key, required this.store});
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Anivermaru',
    navigatorObservers: [GameAudioRouteObserver()],
    builder: (context, child) => CatCareScope(
      care: store.catCare,
      child: Listener(
        onPointerDown: (_) => GameAudio.instance.unlock(),
        child: child!,
      ),
    ),
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
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  Timer? _cloudRetry;
  bool _refreshingCloud = false;
  final _blocKey = GlobalKey<BlocBoardState>();
  int page = 0;
  String _collectionQuery = '';
  final TextEditingController _collectionSearch = TextEditingController();
  CardRarity? _collectionRarity;
  _CollectionSort _collectionSort = _CollectionSort.rarity;
  bool _collectionOwnedOnly = false;
  String? _selectedCollection;
  late final AnimationController _packAnimation;
  int _packSoundFlags = 0;
  late final PageController _packCarousel;
  int _selectedPackVolume = 0;
  bool _openingPack = false;
  bool _gameRouteOpen = false;
  Map<String, dynamic>? _cloudMember;
  List<Map<String, dynamic>> _cloudScores = [];
  String? _cloudError;
  bool _cloudBusy = false;
  StreamSubscription<List<Map<String, dynamic>>>? _scoreSubscription;
  Timer? _collectionPlayTimer;
  int _collectionShuffle = 0;
  bool _inspectingCollection = false;
  GameStore get s => widget.store;
  CatKind get _packCat => s.totalCards.isEven ? CatKind.lady : CatKind.maru;
  String get _packCatName => _packCat == CatKind.lady ? 'Lady' : 'Maru';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _cloudRetry = Timer.periodic(const Duration(seconds: 12), (_) {
      if (Backend.uid != null &&
          (_cloudMember == null || _cloudError != null)) {
        unawaited(_refreshCloud());
      }
    });
    _packAnimation = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3100),
    )..addListener(_packSoundTick);
    _packCarousel = PageController(viewportFraction: .82);
    _refreshCloud();
    _collectionPlayTimer = Timer.periodic(const Duration(seconds: 28), (_) {
      if (mounted && page == 2 && ModalRoute.of(context)?.isCurrent == true) {
        setState(() => _collectionShuffle++);
      }
    });
  }

  Future<void> _refreshCloud() async {
    if (!Backend.configured || _refreshingCloud || !mounted) return;
    _refreshingCloud = true;
    try {
      // A remembered login and room must work even on a fully offline launch.
      await s.cloud.start();
      final uid = Backend.uid;
      final cached = uid == null
          ? null
          : s.prefs.getString('firebase.membership.$uid') ??
                (s.prefs.getString('firebase.owner') == uid &&
                        s.prefs.getString('firebase.noteSpace') != null
                    ? jsonEncode({
                        'user_id': uid,
                        'space_id': s.prefs.getString('firebase.noteSpace'),
                        'nickname':
                            Backend.auth.currentUser?.displayName ?? 'Jugador',
                      })
                    : null);
      if (cached != null && _cloudMember == null) {
        final member = jsonDecode(cached) as Map<String, dynamic>;
        if (member['user_id'] == uid && member['space_id'] is String) {
          await s.connectCloud(member['space_id'] as String);
          if (mounted) setState(() => _cloudMember = member);
          _watchScores();
        }
      }
      final member = await Backend.membership();
      if (member != null) {
        await s.prefs.setString(
          'firebase.membership.${member['user_id']}',
          jsonEncode(member),
        );
        await s.connectCloud(member['space_id'] as String);
        _watchScores();
      }
      if (mounted) {
        setState(() {
          _cloudMember = member;
          if (member == null) _cloudScores = [];
          _cloudError = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _cloudError =
              'No pudimos sincronizar con Firebase. El guardado local se conserva.',
        );
      }
    } finally {
      _refreshingCloud = false;
    }
  }

  void _watchScores() {
    if (_scoreSubscription != null) return;
    _scoreSubscription = Backend.watchHighscores().listen(
      (scores) {
        if (mounted) setState(() => _cloudScores = scores);
      },
      onError: (_) {
        _scoreSubscription?.cancel();
        _scoreSubscription = null;
      },
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_refreshCloud());
      unawaited(s.cloud.sync());
      unawaited(s.retryNotes());
    }
  }

  Future<void> _activateCloud() async {
    setState(() {
      _cloudBusy = true;
      _cloudError = null;
    });
    try {
      await Backend.activate('', '', chooseNickname: _chooseNickname);
      await _refreshCloud();
    } catch (error) {
      if (mounted) {
        setState(() => _cloudError = Backend.loginErrorMessage(error));
      }
    } finally {
      if (mounted) setState(() => _cloudBusy = false);
    }
  }

  Future<String?> _chooseNickname() async {
    if (!mounted) return null;
    final controller = TextEditingController(
      text: _cloudMember?['nickname'] as String? ?? '',
    );
    final form = GlobalKey<FormState>();
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Tu nombre de usuario'),
        content: Form(
          key: form,
          child: TextFormField(
            controller: controller,
            autofocus: true,
            maxLength: 24,
            decoration: const InputDecoration(
              labelText: '¿Cómo quieres aparecer?',
              helperText: 'Se usará en tu perfil y en los récords.',
            ),
            validator: (value) => (value?.trim().length ?? 0) < 2
                ? 'Escribe al menos 2 caracteres.'
                : null,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate()) {
                Navigator.pop(context, controller.text.trim());
              }
            },
            child: const Text('Guardar nombre'),
          ),
        ],
      ),
    );
    // The closing dialog can still reference its controller during its transition.
    Future<void>.delayed(const Duration(seconds: 1), controller.dispose);
    return result;
  }

  Future<void> _editNickname() async {
    final name = await _chooseNickname();
    if (name == null) return;
    try {
      await Backend.updateNickname(name);
      await _refreshCloud();
    } catch (_) {
      if (mounted) {
        setState(
          () =>
              _cloudError = 'No pudimos guardar el nombre. Revisa la conexión.',
        );
      }
    }
  }

  Future<void> _joinSpace() async {
    var invitation = '';
    final join = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Compartir nuestro bloc'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Comparte este código solo con quien quieras invitar. Podrá ver y editar el mural.',
            ),
            const SizedBox(height: 12),
            SelectableText(Backend.space ?? ''),
            TextButton.icon(
              onPressed: () =>
                  Clipboard.setData(ClipboardData(text: Backend.space ?? '')),
              icon: const Icon(Icons.copy),
              label: const Text('Copiar mi código'),
            ),
            TextField(
              onChanged: (value) => invitation = value,
              decoration: const InputDecoration(
                labelText: 'O pega el código de otra persona',
              ),
            ),
            const Text(
              'Al unirte verás su mural. Conservaremos una copia local del mural anterior.',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cerrar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Unirme'),
          ),
        ],
      ),
    );
    if (join != true) return;
    try {
      await Backend.joinSpace(invitation);
      await _refreshCloud();
    } catch (_) {
      if (mounted) {
        setState(
          () => _cloudError =
              'No pudimos unirnos. Revisa el código y la conexión.',
        );
      }
    }
  }

  Future<void> _play(Widget screen) async {
    if (_gameRouteOpen) return;
    _gameRouteOpen = true;
    s.cloud.allowRestore = false;
    try {
      await Navigator.push(
        context,
        MaterialPageRoute<void>(
          settings: RouteSettings(
            name: screen is LeapScreen
                ? '/leap'
                : screen is SweetScreen
                ? '/sweet'
                : screen is WordleScreen
                ? '/wordle'
                : screen is BomberScreen
                ? '/bomber'
                : '/blocks',
          ),
          builder: (_) => screen,
        ),
      );
    } finally {
      _gameRouteOpen = false;
      s.cloud.allowRestore = true;
      await s.cloud.sync();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cloudRetry?.cancel();
    _scoreSubscription?.cancel();
    _collectionPlayTimer?.cancel();
    _packAnimation.dispose();
    _packCarousel.dispose();
    _collectionSearch.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: s,
    builder: (context, _) => MenuSwipe(
      onStep: (step) => setState(() => page = (page + step).clamp(0, 3)),
      child: Scaffold(
        appBar: AppBar(
          title: FittedBox(
            fit: BoxFit.scaleDown,
            child: BrandTitle(prefs: s.prefs),
          ),
          actions: [
            IconButton(
              tooltip: 'Logros y recompensas',
              icon: const Icon(Icons.emoji_events_rounded),
              onPressed: () => showDialog<void>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Logros · premio único'),
                  content: SizedBox(
                    width: 360,
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Los premios se suman automáticamente al monedero una sola vez.',
                          ),
                          for (final entry
                              in GameStore.achievementRewards.entries)
                            ListTile(
                              leading: Icon(
                                s.achievementUnlocked(entry.key)
                                    ? Icons.check_circle
                                    : Icons.emoji_events_outlined,
                              ),
                              title: Text(entry.value.$1),
                              subtitle: Text(
                                '+${entry.value.$2} monedas · ${s.achievementUnlocked(entry.key) ? 'Conseguido' : 'Pendiente'}',
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Listo'),
                    ),
                  ],
                ),
              ),
            ),
            const AudioSettingsButton(),
            const AppUpdateButton(),
            Chip(avatar: const CoinIcon(size: 20), label: Text('${s.coins}')),
            const SizedBox(width: 16),
          ],
        ),
        body: PawBackground(
          child: SafeArea(
            child: Column(
              children: [
                if (s.saveError != null || s.noteSyncError != null)
                  MaterialBanner(
                    content: Text((s.saveError ?? s.noteSyncError)!),
                    actions: [
                      TextButton(
                        onPressed: s.retrySavedData,
                        child: const Text('Reintentar'),
                      ),
                    ],
                  ),
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 650),
                      child: switch (page) {
                        0 => home(),
                        1 => packs(),
                        2 => collection(),
                        _ => notes(),
                      },
                    ),
                  ),
                ),
              ],
            ),
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
    ),
  );

  Widget _leaderboardButton(String gameId, String title, Color color) =>
      TextButton.icon(
        style: TextButton.styleFrom(foregroundColor: color),
        onPressed: () => showDialog<void>(
          context: context,
          builder: (_) => GameLeaderboardDialog(
            gameId: gameId,
            title: title,
            spaceId: _cloudMember?['space_id'] as String?,
            initialScores: _cloudScores,
          ),
        ),
        icon: const Icon(Icons.leaderboard_outlined),
        label: const Text('Ver clasificación'),
      );

  Future<void> _shareBloc() async {
    if (_cloudMember == null) await _activateCloud();
    if (mounted && _cloudMember != null) {
      final joined = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => BlocPeopleSheet(onCode: _joinSpace),
      );
      if (joined == true) await _refreshCloud();
    }
  }

  Widget _gameSpotlight({
    required String gameId,
    bool showLeaderboard = true,
    required String eyebrow,
    required String title,
    required String description,
    required IconData icon,
    required List<Color> colors,
    required Color accent,
    required VoidCallback onTap,
  }) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(26),
      child: Ink(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: colors,
          ),
          borderRadius: BorderRadius.circular(26),
          boxShadow: [
            BoxShadow(
              color: colors.first.withValues(alpha: .25),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              right: -14,
              bottom: -24,
              child: Icon(
                icon,
                size: 118,
                color: Colors.white.withValues(alpha: .09),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .16),
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: .22),
                        ),
                      ),
                      child: Icon(icon, color: accent, size: 29),
                    ),
                    const Spacer(),
                    Text(
                      eyebrow,
                      style: TextStyle(
                        color: accent,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.6,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 25,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -.4,
                  ),
                ),
                const SizedBox(height: 7),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 410),
                  child: Text(
                    description,
                    style: const TextStyle(
                      color: Color(0xfff4eff8),
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(height: 17),
                if (showLeaderboard) _leaderboardButton(gameId, title, accent),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 15,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.play_arrow_rounded, color: ink, size: 19),
                      SizedBox(width: 5),
                      Text(
                        'JUGAR',
                        style: TextStyle(
                          color: ink,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );

  Widget home() => ListView(
    key: const PageStorageKey('home-scroll'),
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
      CatRoom(
        onOpenCare: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => CatCareScreen(store: s)),
        ),
        ownedCards: s.cards.keys.toList(),
        cardBuilder: (id) => _CardArt(cardId: id, thumbnail: true),
      ),
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
                  ? 'Continuar con Google'
                  : 'Conectado como ${_cloudMember!['nickname']}',
            ),
            subtitle: Text(
              _cloudError ??
                  (_cloudMember == null
                      ? 'Guarda tu progreso en tu cuenta.'
                      : 'Tu cuenta y progreso sincronizado.'),
            ),
            trailing: _cloudBusy
                ? const CircularProgressIndicator()
                : (_cloudMember == null
                      ? const Icon(Icons.chevron_right)
                      : null),
            onTap: _cloudMember == null && !_cloudBusy ? _activateCloud : null,
          ),
        ),
        if (_cloudMember != null)
          ListenableBuilder(
            listenable: s.cloud,
            builder: (context, _) => Column(
              children: [
                Text(s.cloud.status, textAlign: TextAlign.center),
                TextButton.icon(
                  onPressed: _editNickname,
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Cambiar nombre de usuario'),
                ),
                if (s.pendingNoteCount > 0)
                  Text(
                    '${s.pendingNoteCount} nota(s) pendiente(s) de sincronizar',
                    textAlign: TextAlign.center,
                  ),
                Text(
                  Backend.auth.currentUser?.email ?? '',
                  style: const TextStyle(fontSize: 12),
                ),
                TextButton(
                  onPressed: _cloudBusy
                      ? null
                      : () async {
                          setState(() => _cloudBusy = true);
                          try {
                            await s.disconnectCloud();
                            await _scoreSubscription?.cancel();
                            _scoreSubscription = null;
                            if (mounted) {
                              setState(() {
                                _cloudMember = null;
                                _cloudScores = [];
                              });
                            }
                          } finally {
                            if (mounted) setState(() => _cloudBusy = false);
                          }
                        },
                  child: const Text('Cerrar sesión'),
                ),
                if (s.cloud.conflict != null)
                  Wrap(
                    spacing: 8,
                    children: [
                      TextButton(
                        onPressed: () async {
                          await s.cloud.resolve(keepLocal: true);
                        },
                        child: const Text('Conservar este dispositivo'),
                      ),
                      TextButton(
                        onPressed: () async {
                          await s.cloud.resolve(keepLocal: false);
                        },
                        child: const Text('Recuperar el de mi cuenta'),
                      ),
                    ],
                  ),
              ],
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
              'Block Blaster Maru Editions',
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
            _leaderboardButton(
              'blocks-v1',
              'Block Blaster Maru Editions',
              const Color(0xffffdc83),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xffedd8a6),
                foregroundColor: ink,
              ),
              onPressed: () async {
                await _play(BlockScreen(store: s));
                if (_cloudMember != null) {
                  try {
                    await Backend.submitHighscore('blocks-v1', s.best);
                    await _refreshCloud();
                  } catch (_) {
                    if (mounted) {
                      setState(
                        () => _cloudError =
                            'El récord está guardado aquí; falta sincronizarlo.',
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
      _gameSpotlight(
        gameId: 'wordlady',
        eyebrow: 'RETO DE PALABRAS',
        title: 'Wordlady',
        description:
            'Nuestro Wordle en español. Cinco letras, seis intentos y Lady como compañera.',
        icon: Icons.spellcheck_rounded,
        colors: const [Color(0xff5b3b8c), Color(0xff8b65bd)],
        accent: const Color(0xffffdc83),
        onTap: () => _play(WordleScreen(store: s)),
      ),
      const SizedBox(height: 24),
      _gameSpotlight(
        gameId: 'candy-churu-cat',
        eyebrow: 'DULCE DESAFÍO',
        title: 'Candy Churu Cat',
        description:
            'Combina premios, crea especiales y limpia gelatinas junto a Maru y Lady.',
        icon: Icons.cake_rounded,
        colors: const [Color(0xffb94975), Color(0xffef779d)],
        accent: const Color(0xffffe48d),
        onTap: () => _play(SweetScreen(store: s)),
      ),
      const SizedBox(height: 24),
      _gameSpotlight(
        gameId: 'ascenso-maruzon',
        eyebrow: 'AVENTURA VERTICAL',
        title: 'Ascenso Maruzon',
        description:
            'Sube desde las profundidades hasta el espacio, recoge monedas y domina los cielos.',
        icon: Icons.rocket_launch_rounded,
        colors: const [Color(0xff244b80), Color(0xff477fba)],
        accent: const Color(0xff9ee8ff),
        onTap: () => _play(LeapScreen(store: s)),
      ),
      const SizedBox(height: 24),
      _gameSpotlight(
        gameId: 'bomber-miau',
        showLeaderboard: false,
        eyebrow: 'DUELO DE PATITAS',
        title: 'Bomber Miau',
        description:
            'Cuatro arenas, seis poderes y cuatro gatos. Desafía a la IA o invita a otro jugador.',
        icon: Icons.local_fire_department_rounded,
        colors: const [Color(0xff345e68), Color(0xff6c78a8)],
        accent: const Color(0xffffd989),
        onTap: () => _play(BomberScreen(store: s)),
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

  void _selectPackVolume(int index) {
    if (!mounted || _openingPack || index < 0 || index > 1) return;
    setState(() => _selectedPackVolume = index);
    if (_packCarousel.hasClients) {
      _packCarousel.animateToPage(
        index,
        duration: const Duration(milliseconds: 1100),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  void _packSoundTick() {
    if (!_openingPack || page != 1) return;
    for (final cue in [
      (0, .48, GameSfx.paper),
      (1, .72, GameSfx.reveal),
      (2, .8, GameSfx.kitten),
    ]) {
      if (_packAnimation.value >= cue.$2 &&
          _packSoundFlags & (1 << cue.$1) == 0) {
        _packSoundFlags |= 1 << cue.$1;
        GameAudio.instance.play(cue.$3);
      }
    }
  }

  Future<void> _openPack() async {
    if (_openingPack || s.coins < s.packPrice) return;
    final opener = _packCat;
    final selectedVolume = _selectedPackVolume;
    _packSoundFlags = 0;
    GameAudio.instance.play(GameSfx.kitten);
    setState(() => _openingPack = true);
    HapticFeedback.mediumImpact();
    await _packAnimation.forward(from: 0);
    final collectionId = selectedVolume == 0
        ? anniversaryCollectionId
        : anniversaryCollectionV2Id;
    final id = s.openPack(opener: opener, collectionId: collectionId);
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
        collectionId: collectionId,
        finish: s.lastOpenedFinish,
      ),
    );
  }

  Widget packs() => ListView(
    key: const PageStorageKey("packs-scroll"),
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
      const SizedBox(height: 22),
      SizedBox(
        height: 176,
        child: Stack(
          alignment: Alignment.center,
          children: [
            PageView.builder(
              key: const PageStorageKey("pack-volumes"),
              physics: _openingPack
                  ? const NeverScrollableScrollPhysics()
                  : null,
              controller: _packCarousel,
              itemCount: 2,
              onPageChanged: (index) {
                if (!_openingPack) setState(() => _selectedPackVolume = index);
              },
              itemBuilder: (context, index) {
                final selected = index == _selectedPackVolume;
                final colors = index == 0
                    ? const [Color(0xffff6bb6), Color(0xff6f43dc)]
                    : const [Color(0xff2cc7b5), Color(0xff3154b7)];
                return Semantics(
                  button: true,
                  selected: selected,
                  label: 'Elegir Momazos volumen ${index + 1}',
                  child: GestureDetector(
                    onTap: () => _selectPackVolume(index),
                    child: AnimatedRotation(
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.easeOutBack,
                      turns: selected ? 0 : (index == 0 ? -.012 : .012),
                      child: AnimatedScale(
                        duration: const Duration(milliseconds: 360),
                        curve: Curves.easeOutBack,
                        scale: selected ? 1 : .88,
                        child: Container(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 5,
                          ),
                          padding: const EdgeInsets.all(17),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: colors),
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(
                              color: selected
                                  ? const Color(0xffffe991)
                                  : Colors.white.withValues(alpha: .35),
                              width: selected ? 3 : 1,
                            ),
                            boxShadow: selected
                                ? [
                                    BoxShadow(
                                      color: colors.first.withValues(
                                        alpha: .32,
                                      ),
                                      blurRadius: 18,
                                      offset: const Offset(0, 8),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 42,
                                height: 52,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: .16),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Icon(
                                  Icons.card_giftcard_rounded,
                                  color: Colors.white,
                                  size: 34,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        'MOMAZOS VOL. ${index + 1}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 17,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 5),
                                    Text(
                                      index == 0
                                          ? 'EDICIÓN ANIVERSARIO'
                                          : 'EDICIÓN PAPU',
                                      style: TextStyle(
                                        color: Color(0xffffefae),
                                        fontSize: 9,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 1.1,
                                      ),
                                    ),
                                    const SizedBox(height: 7),
                                    Text(
                                      selected
                                          ? 'SELECCIONADO'
                                          : 'DESLIZA PARA ELEGIR',
                                      style: TextStyle(
                                        color: Colors.white.withValues(
                                          alpha: .8,
                                        ),
                                        fontSize: 8,
                                        fontWeight: FontWeight.bold,
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
                  ),
                );
              },
            ),
            Positioned(
              left: 0,
              child: _PackCarouselArrow(
                icon: Icons.chevron_left_rounded,
                label: 'Ver volumen anterior',
                onPressed: () =>
                    _selectPackVolume((_selectedPackVolume - 1).clamp(0, 1)),
              ),
            ),
            Positioned(
              right: 0,
              child: _PackCarouselArrow(
                icon: Icons.chevron_right_rounded,
                label: 'Ver volumen siguiente',
                onPressed: () =>
                    _selectPackVolume((_selectedPackVolume + 1).clamp(0, 1)),
              ),
            ),
          ],
        ),
      ),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(
          2,
          (index) => AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            width: index == _selectedPackVolume ? 22 : 7,
            height: 7,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              color: index == _selectedPackVolume
                  ? const Color(0xff7045c7)
                  : const Color(0xffc8c1d4),
              borderRadius: BorderRadius.circular(9),
            ),
          ),
        ),
      ),
      const SizedBox(height: 24),
      PackOpeningStage(
        animation: _packAnimation,
        volume: _selectedPackVolume,
        opening: _openingPack,
        cat: _packCat,
      ),
      const SizedBox(height: 28),
      FilledButton.icon(
        onPressed: s.coins < s.packPrice || _openingPack ? null : _openPack,
        icon: Icon(_openingPack ? Icons.auto_awesome : Icons.card_giftcard),
        label: Text(
          _openingPack
              ? '¡Brillando tu sorpresa…!'
              : 'Abrir sobre · ${s.packPrice} monedas',
        ),
      ),
      const SizedBox(height: 16),
      Text(
        s.packPrice == 20
            ? 'Tu primer sobre del día: 20 monedas'
            : 'Cada sobre sube 5 monedas · máximo 70 · mañana vuelve a 20',
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 12, color: green),
      ),
      Text(
        'Legendaria o superior en ${25 - s.packsSinceLegendary} aperturas como máximo.\n7 rarezas · Celestial: 1% por sobre\nClásica, Foil plateada y Foil dorada',
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
      ),
      Text(
        s.coins < s.packPrice
            ? 'Te faltan ${s.packPrice - s.coins} monedas. ¡Consíguelas jugando!'
            : '${cardsForCollection(_selectedPackVolume == 0 ? anniversaryCollectionId : anniversaryCollectionV2Id).length} cartas · las celestiales tienen un 1% por sobre.\nLas repetidas se conservan en tu colección.',
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 12, height: 1.6),
      ),
    ],
  );
  Future<void> _viewCardVariants(int id) async {
    final variants = s.variantsFor(id);
    String? selected;
    if (variants.length > 1) {
      selected = await showModalBottomSheet<String>(
        context: context,
        showDragHandle: true,
        builder: (context) => SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              ListTile(
                title: Text(cardName(id)),
                subtitle: const Text('Elige una variante para verla'),
              ),
              for (final key in variants)
                ListTile(
                  title: Text(
                    '${CardRarity.values.byName(key.split(':')[1]).label} · ${CardFinish.values.byName(key.split(':')[2]).label}',
                  ),
                  trailing: Text('×${s.cardVariants[key]}'),
                  onTap: () => Navigator.pop(context, key),
                ),
            ],
          ),
        ),
      );
      if (selected == null || !mounted) return;
    } else if (variants.isNotEmpty) {
      selected = variants.first;
    }
    if (!mounted) return;
    setState(() => _inspectingCollection = true);
    Uint8List? arPhoto;
    try {
      arPhoto = await showDialog<Uint8List>(
        context: context,
        builder: (_) => _InspectCardDialog(
          cardId: id,
          copies: selected == null ? s.cards[id]! : s.cardVariants[selected]!,
          rarity: selected == null
              ? s.rarities[id] ?? CardRarity.common
              : CardRarity.values.byName(selected.split(':')[1]),
          finish: selected == null
              ? CardFinish.normal
              : CardFinish.values.byName(selected.split(':')[2]),
          opener: s.cardOpeners[id] == null
              ? null
              : CatKind.values[s.cardOpeners[id]!],
          collectionId: s.cardCollections[id] ?? anniversaryCollectionId,
          variantKeys: variants,
          variantCopies: s.cardVariants,
          selectedKey: selected,
        ),
      );
    } finally {
      if (mounted) setState(() => _inspectingCollection = false);
    }
    if (arPhoto == null || !mounted) return;
    final note = _newMediaNote(
      'Carta AR · ${cardNames[id]}',
      base64Encode(arPhoto),
      'photo',
    );
    setState(() => s.notes.add(note));
    try {
      await s.saveNote(note, waitForSync: false);
      _blocKey.currentState?.focus(note);
      if (mounted) {
        setState(() => page = 3);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Foto AR guardada en Nuestro bloc.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No pudimos guardar la foto. Revisa el espacio disponible y vuelve a intentar.',
            ),
          ),
        );
      }
    }
  }

  Widget _collectionCard(int i, List<int> playfulOwned, {bool animate = true}) {
    final unlocked = s.cards.containsKey(i);
    return _CollectionCatPlay(
      key: ValueKey('cat-card-$i'),
      cardId: i,
      enabled:
          !_inspectingCollection && animate && playfulOwned.take(2).contains(i),
      cat: playfulOwned.isNotEmpty && i == playfulOwned.first
          ? CatKind.maru
          : CatKind.lady,
      routine: (_collectionShuffle + i) % 3,
      delay: playfulOwned.isNotEmpty && i == playfulOwned.first ? 0 : 1,
      child: InkWell(
        onTap: unlocked ? () => _viewCardVariants(i) : null,
        borderRadius: BorderRadius.circular(20),
        child: _RarityFrame(
          rarity: unlocked
              ? s.rarities[i] ?? CardRarity.common
              : CardRarity.common,
          locked: !unlocked,
          child: _PaletteSurface(
            cardId: i,
            enabled: unlocked,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: unlocked
                        ? _CardArt(cardId: i, thumbnail: true)
                        : const Center(
                            child: Text(
                              '?',
                              style: TextStyle(fontSize: 46, color: green),
                            ),
                          ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    unlocked ? cardName(i) : 'Por descubrir',
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
                        ? '${(s.rarities[i] ?? CardRarity.common).label.toUpperCase()}  ·  ×${s.cards[i]} · ${s.variantsFor(i).length} variantes'
                        : 'Abre un sobre',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: unlocked
                          ? rarityColor(s.rarities[i] ?? CardRarity.common)
                          : ink,
                    ),
                  ),
                  if (unlocked) ...[
                    const SizedBox(height: 4),
                    Text(
                      s.cardOpeners[i] == null
                          ? 'Descubierta por Maru & Lady'
                          : 'La abrió ${CatKind.values[s.cardOpeners[i]!] == CatKind.maru ? 'Maru' : 'Lady'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xffffedbe),
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget collection() {
    if (_selectedCollection != null) {
      final ids = cardsForCollection(_selectedCollection!);
      return CollectionAlbum(
        key: ValueKey(_selectedCollection),
        title: _selectedCollection == anniversaryCollectionV2Id
            ? 'Momazos Vol. 2'
            : 'Momazos Vol. 1',
        teal: _selectedCollection == anniversaryCollectionV2Id,
        cardIds: ids,
        ownedIds: s.cards.keys.toSet(),
        onClose: () => setState(() => _selectedCollection = null),
        cardBuilder: (id, companions, active) =>
            _collectionCard(id, companions, animate: active),
      );
    }
    final query = _collectionQuery.trim().toLowerCase();
    final volumeSelected = _selectedCollection != null;
    final rarityCounts = {
      for (final rarity in CardRarity.values)
        rarity: s.cards.keys
            .where((id) => (s.rarities[id] ?? CardRarity.common) == rarity)
            .length,
    };
    final order = cardNames.keys.toList()
      ..removeWhere((i) {
        final owned = s.cards.containsKey(i);
        if (_selectedCollection != null &&
            !cardsForCollection(_selectedCollection!).contains(i)) {
          return true;
        }
        if (_collectionOwnedOnly && !owned) return true;
        if (_collectionRarity != null &&
            (!owned ||
                (s.rarities[i] ?? CardRarity.common) != _collectionRarity)) {
          return true;
        }
        return query.isNotEmpty &&
            (!owned || !cardName(i).toLowerCase().contains(query));
      })
      ..sort((a, b) {
        final owned =
            (s.cards.containsKey(b) ? 1 : 0) - (s.cards.containsKey(a) ? 1 : 0);
        if (owned != 0) return owned;
        return switch (_collectionSort) {
          _CollectionSort.rarity =>
            (s.rarities[b] ?? CardRarity.common).rank.compareTo(
              (s.rarities[a] ?? CardRarity.common).rank,
            ),
          _CollectionSort.name => cardName(
            a,
          ).toLowerCase().compareTo(cardName(b).toLowerCase()),
          _CollectionSort.copies => (s.cards[b] ?? 0).compareTo(
            s.cards[a] ?? 0,
          ),
        };
      });
    final playfulOwned = order.where(s.cards.containsKey).toList();
    if (_collectionShuffle > 0 && playfulOwned.length > 1) {
      final a = _collectionShuffle % playfulOwned.length;
      final b = (a + 1) % playfulOwned.length;
      final positionA = order.indexOf(playfulOwned[a]);
      final positionB = order.indexOf(playfulOwned[b]);
      order[positionA] = playfulOwned[b];
      order[positionB] = playfulOwned[a];
    }
    return CustomScrollView(
      key: const PageStorageKey("collection-scroll"),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
          sliver: SliverList.list(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    if (Backend.uid == null) await _activateCloud();
                    if (Backend.uid == null || !mounted) return;
                    await Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => CardTradeScreen(store: s),
                      ),
                    );
                  },
                  icon: const Icon(Icons.swap_horiz_rounded),
                  label: const Text('Intercambiar cartas'),
                ),
              ),
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
              for (final volumeId in [
                anniversaryCollectionId,
                anniversaryCollectionV2Id,
              ])
                Builder(
                  builder: (context) {
                    final volumeCards = cardsForCollection(volumeId);
                    final volumeOwned = volumeCards
                        .where(s.cards.containsKey)
                        .length;
                    final volumeSelected = _selectedCollection == volumeId;
                    final isV2 = volumeId == anniversaryCollectionV2Id;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: InkWell(
                        onTap: () => setState(() {
                          _selectedCollection = volumeSelected
                              ? null
                              : volumeId;
                          if (!volumeSelected) {
                            _collectionOwnedOnly = false;
                            _collectionRarity = null;
                            _collectionQuery = '';
                            _collectionSearch.clear();
                          }
                        }),
                        borderRadius: BorderRadius.circular(22),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: volumeSelected
                                  ? const [Color(0xff3b8eea), Color(0xffcb61ed)]
                                  : isV2
                                  ? const [Color(0xff147d78), Color(0xff274b9e)]
                                  : const [
                                      Color(0xff39236d),
                                      Color(0xff7040aa),
                                    ],
                            ),
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(
                              color: volumeSelected
                                  ? const Color(0xffffdf78)
                                  : const Color(0xffb9e8f5),
                              width: volumeSelected ? 2.5 : 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(
                                  0xff8f4ddb,
                                ).withValues(alpha: volumeSelected ? .35 : .16),
                                blurRadius: 18,
                                offset: const Offset(0, 7),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 66,
                                height: 82,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Color(0xff3c91ee),
                                      Color(0xffdf6de2),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(13),
                                  border: Border.all(
                                    color: const Color(0xffffe17d),
                                  ),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.pets,
                                      color: Colors.white,
                                      size: 30,
                                    ),
                                    SizedBox(height: 5),
                                    Text(
                                      isV2 ? 'VOL. 2' : 'VOL. 1',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'ÁLBUM · TOCA PARA ABRIR',
                                      style: TextStyle(
                                        color: Color(0xffbdefff),
                                        fontSize: 9,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 1.4,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      isV2
                                          ? 'Momazos Vol. 2'
                                          : 'Momazos Vol. 1',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    Text(
                                      isV2
                                          ? 'Edición Papu · Aniversario'
                                          : 'Edición Aniversario',
                                      style: TextStyle(
                                        color: Color(0xffffe49a),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 9),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(9),
                                      child: LinearProgressIndicator(
                                        value: volumeCards.isEmpty
                                            ? 0
                                            : volumeOwned / volumeCards.length,
                                        minHeight: 7,
                                        backgroundColor: Colors.white
                                            .withValues(alpha: .18),
                                        valueColor:
                                            const AlwaysStoppedAnimation(
                                              Color(0xffffdf78),
                                            ),
                                      ),
                                    ),
                                    const SizedBox(height: 5),
                                    Text(
                                      '$volumeOwned / ${volumeCards.length} descubiertas',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                volumeSelected
                                    ? Icons.grid_view_rounded
                                    : Icons.menu_book_rounded,
                                color: Colors.white,
                                size: 21,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              if (volumeSelected) ...[
                const SizedBox(height: 9),
                Row(
                  children: [
                    const Icon(
                      Icons.visibility_off_outlined,
                      size: 17,
                      color: ink,
                    ),
                    const SizedBox(width: 6),
                    const Expanded(
                      child: Text(
                        'Las cartas no descubiertas permanecen ocultas para evitar spoilers.',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xff69776d),
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () =>
                          setState(() => _selectedCollection = null),
                      child: const Text('Ver todas'),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: _collectionSearch,
                decoration: InputDecoration(
                  hintText: 'Buscar entre tus cartas',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _collectionQuery.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Limpiar búsqueda',
                          onPressed: () {
                            _collectionSearch.clear();
                            setState(() => _collectionQuery = '');
                          },
                          icon: const Icon(Icons.close),
                        ),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Color(0xffded5c6)),
                  ),
                ),
                onChanged: (value) => setState(() => _collectionQuery = value),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  ChoiceChip(
                    label: const Text('Todas'),
                    selected: _collectionRarity == null,
                    onSelected: (_) => setState(() => _collectionRarity = null),
                  ),
                  for (final rarity in CardRarity.values)
                    ChoiceChip(
                      avatar: Icon(
                        Icons.auto_awesome,
                        size: 16,
                        color: rarityColor(rarity),
                      ),
                      label: Text('${rarity.label} ${rarityCounts[rarity]}'),
                      selected: _collectionRarity == rarity,
                      onSelected: (_) =>
                          setState(() => _collectionRarity = rarity),
                    ),
                  FilterChip(
                    label: const Text('Descubiertas'),
                    selected: _collectionOwnedOnly,
                    onSelected: (value) =>
                        setState(() => _collectionOwnedOnly = value),
                  ),
                  DropdownButton<_CollectionSort>(
                    value: _collectionSort,
                    borderRadius: BorderRadius.circular(14),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _collectionSort = value);
                      }
                    },
                    items: const [
                      DropdownMenuItem(
                        value: _CollectionSort.rarity,
                        child: Text('Orden: calidad'),
                      ),
                      DropdownMenuItem(
                        value: _CollectionSort.name,
                        child: Text('Orden: nombre'),
                      ),
                      DropdownMenuItem(
                        value: _CollectionSort.copies,
                        child: Text('Orden: copias'),
                      ),
                    ],
                  ),
                  Text(
                    '${order.length} resultados',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xff69776d),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'Tus dos compañeros juegan con las cartas 🐾',
                style: TextStyle(color: ink, fontSize: 12),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
        if (order.isEmpty)
          SliverToBoxAdapter(
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(
                child: Text(
                  'No encontramos cartas con esos filtros 🐾',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xff69776d)),
                ),
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            sliver: SliverLayoutBuilder(
              builder: (context, constraints) => SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: constraints.crossAxisExtent >= 1050
                      ? 5
                      : constraints.crossAxisExtent >= 740
                      ? 4
                      : constraints.crossAxisExtent >= 520
                      ? 3
                      : 2,
                  childAspectRatio: .58,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                delegate: SliverChildBuilderDelegate((context, displayIndex) {
                  final i = order[displayIndex];
                  return _collectionCard(i, playfulOwned);
                }, childCount: order.length),
              ),
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
    if (result != null && (result.isNotEmpty || note?.imageBase64 != null)) {
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
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _blocKey.currentState?.focus(edited),
      );
    }
  }

  PocketNote _newMediaNote(
    String label,
    String imageBase64,
    String mediaKind,
  ) => PocketNote(
    label,
    .08 + (s.notes.length % 3) * .12,
    .05 + (s.notes.length % 4) * .18,
    imageBase64: imageBase64,
    mediaKind: mediaKind,
  );

  Future<void> _pickNoteImage(ImageSource source) async {
    try {
      final photo = await ImagePicker().pickImage(
        source: source,
        imageQuality: 68,
        maxWidth: 1200,
        maxHeight: 1200,
      );
      if (photo == null || !mounted) return;
      final bytes = await photo.readAsBytes();
      final note = _newMediaNote(
        source == ImageSource.camera ? 'Nuestra foto' : 'Un recuerdo',
        base64Encode(bytes),
        'photo',
      );
      setState(() => s.notes.add(note));
      await s.saveNote(note, waitForSync: false);
      _blocKey.currentState?.focus(note);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No pudimos adjuntar esa imagen.')),
      );
    }
  }

  Future<void> _choosePhotoSource() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            const ListTile(
              title: Text(
                'Añadir una foto',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Sacar una foto'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Elegir de la galería'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source != null) await _pickNoteImage(source);
  }

  Future<void> _drawNote([PocketNote? note]) async {
    final bytes = await showDialog<Uint8List>(
      context: context,
      barrierDismissible: false,
      builder: (_) => BlocDrawingDialog(
        initialImage: note?.imageBase64 == null
            ? null
            : base64Decode(note!.imageBase64!),
      ),
    );
    if (bytes == null || !mounted) return;
    if (note == null) {
      final created = _newMediaNote(
        'Nuestro dibujo',
        base64Encode(bytes),
        'drawing',
      );
      setState(() => s.notes.add(created));
      await s.saveNote(created, waitForSync: false);
      _blocKey.currentState?.focus(created);
    } else {
      setState(() {
        note.imageBase64 = base64Encode(bytes);
        note.mediaKind = 'drawing';
      });
      await s.saveNote(note, waitForSync: false);
      _blocKey.currentState?.focus(note);
    }
  }

  bool _isDrawing(PocketNote note) =>
      note.mediaKind == 'drawing' ||
      (note.mediaKind == null && note.text == 'Nuestro dibujo');

  Widget notes() => BlocBoard(
    key: _blocKey,
    store: s,
    onAdd: () => editNote(),
    onDraw: _drawNote,
    onPhoto: _choosePhotoSource,
    onShare: _shareBloc,
    onEdit: (n) => _isDrawing(n) ? _drawNote(n) : editNote(n),
    status:
        _cloudError ??
        (_cloudMember == null
            ? 'Guardado en este dispositivo · conecta Google para compartir'
            : 'Bloc compartido · los cambios se sincronizan'),
  );
}

class _CollectionCatPlay extends StatefulWidget {
  final Widget child;
  final int cardId, delay;
  final bool enabled;
  final CatKind cat;
  final int routine;
  const _CollectionCatPlay({
    super.key,
    required this.child,
    required this.cardId,
    required this.delay,
    required this.enabled,
    required this.cat,
    required this.routine,
  });
  @override
  State<_CollectionCatPlay> createState() => _CollectionCatPlayState();
}

class _CollectionCatPlayState extends State<_CollectionCatPlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _play = AnimationController(
    vsync: this,
    duration: Duration(seconds: 24 + widget.delay * 4),
  );
  @override
  void initState() {
    super.initState();
    if (widget.enabled) _play.repeat();
  }

  @override
  void didUpdateWidget(_CollectionCatPlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enabled && !oldWidget.enabled) {
      _play.repeat();
    } else if (!widget.enabled && oldWidget.enabled) {
      _play.stop();
      _play.value = 0;
    }
  }

  @override
  void dispose() {
    _play.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _play,
    builder: (context, _) {
      final t = _play.value;
      final active = widget.enabled && t > .12;
      final p = active ? ((t - .12) / .88) : 0.0;
      final arrive = Curves.easeOutCubic.transform((p / .22).clamp(0.0, 1.0));
      final leave = Curves.easeInCubic.transform(
        ((p - .78) / .22).clamp(0.0, 1.0),
      );
      final contact = ((p - .22) / .56).clamp(0.0, 1.0);
      final lift = active && p > .22 && p < .78
          ? math.sin(contact * math.pi)
          : 0.0;
      final stealing = widget.routine == 0;
      final batting = widget.routine == 1;
      final side = widget.cat == CatKind.maru ? -1.0 : 1.0;
      final nudge = batting ? math.sin(contact * math.pi * 4) * lift : lift;
      return Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: Transform.translate(
              offset: Offset(
                side *
                    nudge *
                    (stealing
                        ? 15
                        : batting
                        ? 8
                        : 2),
                -lift *
                    (stealing
                        ? 14
                        : batting
                        ? 3
                        : 7),
              ),
              child: Transform.rotate(
                angle: side * nudge * (stealing ? .08 : .035),
                child: widget.child,
              ),
            ),
          ),
          if (active)
            Positioned(
              right: widget.cat == CatKind.lady
                  ? -8 - (1 - arrive + leave) * 32
                  : null,
              left: widget.cat == CatKind.maru
                  ? -8 - (1 - arrive + leave) * 32
                  : null,
              bottom: -4 + (widget.routine == 2 ? lift * 15 : lift * 5),
              child: IgnorePointer(
                child: Opacity(
                  opacity: (arrive * (1 - leave)).clamp(0.0, 1.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (stealing && lift > .05)
                        Transform.rotate(
                          angle: side * -.12,
                          child: Opacity(
                            opacity: lift,
                            child: Container(
                              width: 33,
                              height: 43,
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(5),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x33000000),
                                    blurRadius: 5,
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(3),
                                child: _CardArt(cardId: widget.cardId),
                              ),
                            ),
                          ),
                        ),
                      CatActor(
                        cat: widget.cat,
                        size: 70,
                        action: CatAction.collection,
                        active: p > .22 && p < .78,
                        packProgress: contact,
                        focus: -side * .7,
                        showLabel: false,
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      );
    },
  );
}

class _PackCarouselArrow extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  const _PackCarouselArrow({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    child: Material(
      color: const Color(0xeefffaf1),
      shape: const CircleBorder(),
      elevation: 5,
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon),
        color: const Color(0xff57338f),
        tooltip: label,
      ),
    ),
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
  int _clearVariation = 0;
  int? _hover;
  GameStore get store => widget.store;

  Future<void> _playBlockSound(bool clear) async {
    GameAudio.instance.play(clear ? GameSfx.clear : GameSfx.place);
    if (clear) GameAudio.instance.play(GameSfx.kitten);
  }

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
    unawaited(_playBlockSound(store.game.lastClearedCount > 0));
    if (store.game.lastClearedCount > 0) {
      _clearCat = _clearCat == CatKind.lady ? CatKind.maru : CatKind.lady;
      _clearVariation = (_clearVariation + 1) % 3;
      _juice.duration = Duration(
        milliseconds: store.game.lastClearedCount >= 3 ? 1900 : 1300,
      );
      _juice.forward(from: 0);
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
        Duration(
          milliseconds: store.game.lastClearedCount > 0
              ? _juice.duration!.inMilliseconds + 80
              : 350,
        ),
        () {
          if (mounted && store.game.over) _showGameOver();
        },
      );
    }
  }

  List<Widget> _catClearParty(
    Size board,
    double size,
    double t,
    double opacity,
    List<int> rows,
    List<int> columns,
  ) {
    final lines = [
      for (final row in rows) (horizontal: true, index: row),
      for (final col in columns) (horizontal: false, index: col),
    ];
    final special = lines.length >= 3;
    final sweepEnd = special ? .62 : .84;
    final children = <Widget>[];
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final reverse = (i + _clearVariation).isOdd;
      final sweep = ((t - .08 - i * .025) / (sweepEnd - .12)).clamp(0.0, 1.0);
      final travel = reverse ? 1 - sweep : sweep;
      var x = line.horizontal
          ? travel * (board.width + size) - size
          : (line.index + .5) * board.width / 8 - size / 2;
      var y = line.horizontal
          ? (line.index + .5) * board.height / 8 - size * .55
          : travel * (board.height + size) - size;
      var angle = reverse ? -.15 : .15;
      // Every cleared line gets its own helper; both cats share double clears.
      final cat = i.isEven
          ? _clearCat
          : (_clearCat == CatKind.maru ? CatKind.lady : CatKind.maru);
      if (special && t > .62) {
        if (i > 1) continue;
        final finale = ((t - .62) / .38).clamp(0.0, 1.0);
        final side = i == 0 ? -1.0 : 1.0;
        final center = Offset(board.width / 2, board.height / 2);
        final radius = board.width * .22;
        switch (_clearVariation) {
          case 0: // A shared leap with a somersault.
            x = center.dx + side * radius - size / 2;
            y = center.dy - size / 2 - math.sin(finale * math.pi) * radius;
            angle = side * finale * math.pi * 2;
          case 1: // Chase each other around a sparkling circle.
            final orbit = finale * math.pi * 2 + i * math.pi;
            x = center.dx + math.cos(orbit) * radius - size / 2;
            y = center.dy + math.sin(orbit) * radius * .65 - size / 2;
            angle = math.sin(orbit) * .3;
          default: // Meet in the middle and bounce paws together.
            x = center.dx + side * radius * (1 - finale * .6) - size / 2;
            y =
                center.dy -
                size / 2 -
                math.sin(finale * math.pi * 3).abs() * size * .4;
            angle = side * math.sin(finale * math.pi * 3) * .35;
        }
      } else if (_clearVariation == 1) {
        y += math.sin(sweep * math.pi * 4) * size * .12;
      } else if (_clearVariation == 2) {
        angle += math.sin(sweep * math.pi * 6) * .18;
      }
      children.add(
        Positioned(
          left: x,
          top: y,
          child: Opacity(
            opacity: opacity,
            child: Transform.rotate(
              angle: angle,
              child: CatActor(
                cat: cat,
                size: size,
                action: CatAction.blocks,
                active: true,
                showLabel: false,
              ),
            ),
          ),
        ),
      );
    }
    if (special && t > .62) {
      children.add(
        Positioned(
          left: 0,
          right: 0,
          bottom: board.height * .15,
          child: Opacity(
            opacity: opacity,
            child: Text(
              [
                '¡Salto de bigotes! ✨',
                '¡Persecución estelar! 🐾',
                '¡Choca esas patitas! 💛',
              ][_clearVariation],
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w900,
                shadows: [Shadow(color: Colors.purple, blurRadius: 8)],
              ),
            ),
          ),
        ),
      );
    }
    return children;
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
      final boardStep =
          (math.min(MediaQuery.sizeOf(context).width, 520.0) - 50) / 8;
      return Scaffold(
        backgroundColor: const Color(0xff211342),
        appBar: AppBar(
          title: const Text(
            'BLOCK BLASTER MARU EDITIONS',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              letterSpacing: 1.4,
              color: Colors.white,
            ),
          ),
          actions: const [AudioSettingsButton(color: Colors.white)],
          backgroundColor: const Color(0xff38206c),
          foregroundColor: Colors.white,
        ),
        body: BlockBlasterBackground(
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
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const CoinIcon(size: 22),
                              const SizedBox(width: 4),
                              Text(
                                '${store.coins}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xffffdf7c),
                                  fontSize: 17,
                                ),
                              ),
                            ],
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
                                    crossAxisSpacing: 0,
                                    mainAxisSpacing: 0,
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
                                      behavior: HitTestBehavior.opaque,
                                      onTap: () => _place(x, y),
                                      child: Padding(
                                        padding: const EdgeInsets.all(1.5),
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
                                            border: Border.all(
                                              color: ghost
                                                  ? Colors.white
                                                  : g.board[i] > 0
                                                  ? Colors.white.withValues(
                                                      alpha: .84,
                                                    )
                                                  : const Color(0xff473a71),
                                              width: ghost ? 2 : 1.2,
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
                                                      blurRadius: ghost
                                                          ? 12
                                                          : 7,
                                                      spreadRadius: ghost
                                                          ? 1
                                                          : 0,
                                                      offset: const Offset(
                                                        0,
                                                        2,
                                                      ),
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
                                              if (g.lastClearedCount == 1)
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
                                              if (g.lastClearedCount >= 2)
                                                ..._catClearParty(
                                                  c.biggest,
                                                  catSize,
                                                  t,
                                                  opacity.clamp(0.0, 1.0),
                                                  g.lastClearedRows,
                                                  g.lastClearedColumns,
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
                                      maxSimultaneousDrags: 1,
                                      dragAnchorStrategy:
                                          (draggable, context, position) =>
                                              Offset(
                                                boardStep / 2,
                                                boardStep / 2,
                                              ),
                                      feedbackOffset: Offset.zero,
                                      onDragStarted: () => store.selectPiece(t),
                                      onDraggableCanceled: (_, _) =>
                                          setState(() => _hover = null),
                                      onDragEnd: (_) =>
                                          setState(() => _hover = null),
                                      feedback: Material(
                                        color: Colors.transparent,
                                        child: _PiecePreview(
                                          shape: g.tray[t]!,
                                          width:
                                              boardStep *
                                              (BlockGame.shapes[g.tray[t]!]
                                                      .map((c) => c.x)
                                                      .reduce(math.max) +
                                                  1),
                                          height:
                                              boardStep *
                                              (BlockGame.shapes[g.tray[t]!]
                                                      .map((c) => c.y)
                                                      .reduce(math.max) +
                                                  1),
                                          elevated: true,
                                        ),
                                      ),
                                      childWhenDragging: Opacity(
                                        opacity: .24,
                                        child: _pieceCard(g, t),
                                      ),
                                      child: GestureDetector(
                                        onTap: () => store.selectPiece(t),
                                        child: _pieceCard(g, t),
                                      ),
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
    insetPadding: const EdgeInsets.all(18),
    child: GameResultCard(
      game: ResultTheme.blocks,
      title: '¡Otra pieza, michi!',
      detail: 'Block Blaster · No quedan espacios para estas piezas',
      stat: '$score puntos',
      caption:
          '${score >= best ? '¡Nuevo récord!' : 'Récord: $best'}\n$coins monedas guardadas para tus premios.',
      again: 'Otra partida',
      onAgain: onAgain,
      onHome: onHome,
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

class _RevealSparklePainter extends CustomPainter {
  final double progress;
  final Color color;
  const _RevealSparklePainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < 9; i++) {
      final phase = (progress * 1.35 + i * .137) % 1;
      if (phase > .56) continue;
      final x = (i * 73.0 + size.width * .12) % size.width;
      final y = (i * 109.0 + size.height * .08) % size.height;
      final strength = math.sin(phase / .56 * math.pi).clamp(0.0, 1.0);
      final radius = 2.2 + strength * (i.isEven ? 4.2 : 2.6);
      final paint = Paint()
        ..color = Color.lerp(
          color,
          Colors.white,
          .55,
        )!.withValues(alpha: strength * .78)
        ..strokeWidth = 1.4
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(Offset(x - radius, y), Offset(x + radius, y), paint);
      canvas.drawLine(Offset(x, y - radius), Offset(x, y + radius), paint);
      if (i % 3 == 0) {
        canvas.drawCircle(
          Offset(x, y),
          radius * 1.7,
          Paint()
            ..color = color.withValues(alpha: strength * .15)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _RevealSparklePainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
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

class _PaletteSurface extends StatelessWidget {
  final int cardId;
  final bool enabled;
  final Widget child;
  const _PaletteSurface({
    required this.cardId,
    required this.enabled,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;
    final fallback = cardColor(cardId);
    return FutureBuilder<CardPalette>(
      future: CardPaletteExtractor.load(cardId, fallback),
      builder: (context, snapshot) {
        final palette =
            snapshot.data ??
            CardPalette(
              primary: fallback,
              secondary: Color.lerp(fallback, const Color(0xff26304b), .62)!,
              accent: Color.lerp(fallback, Colors.white, .45)!,
            );
        return AnimatedContainer(
          duration: const Duration(milliseconds: 420),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [palette.primary, palette.secondary],
            ),
          ),
          child: child,
        );
      },
    );
  }
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
        milliseconds: widget.rarity == CardRarity.legendary ? 6500 : 8000,
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
  final Key? imageKey;
  final bool thumbnail;
  const _CardArt({required this.cardId, this.imageKey, this.thumbnail = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x44000000),
            blurRadius: 5,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(7),
        child: ColoredBox(
          color: const Color(0xff281a43),
          child: CardMedia(
            cardId: cardId,
            imageKey: imageKey,
            thumbnail: thumbnail,
          ),
        ),
      ),
    );
  }
}

class _RarityBurstPainter extends CustomPainter {
  final double progress;
  final CardRarity rarity;
  _RarityBurstPainter({required this.progress, required this.rarity});
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..color = rarityColor(rarity).withValues(alpha: .12 + rarity.rank * .025)
      ..strokeWidth = 1.5 + rarity.rank;
    final count = 5 + rarity.rank * 4;
    for (var i = 0; i < count; i++) {
      final angle = i * math.pi * 2 / count + progress * math.pi * 2;
      final direction = Offset(math.cos(angle), math.sin(angle));
      final pulse = .55 + .45 * math.sin(progress * math.pi * 2 + i);
      canvas.drawLine(
        center + direction * 72,
        center + direction * (90 + pulse * (20 + rarity.rank * 14)),
        paint,
      );
    }
    if (rarity.rank >= 3) {
      canvas.drawCircle(
        center,
        85 + progress * 50,
        paint..style = PaintingStyle.stroke,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RarityBurstPainter oldDelegate) => true;
}

class _FoilArt extends StatefulWidget {
  final int cardId;
  final CardFinish finish;
  final Key? imageKey;
  const _FoilArt({required this.cardId, required this.finish, this.imageKey});
  @override
  State<_FoilArt> createState() => _FoilArtState();
}

class _FoilArtState extends State<_FoilArt>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shine = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 7),
  );
  @override
  void initState() {
    super.initState();
    if (widget.finish != CardFinish.normal) _shine.repeat();
  }

  @override
  void dispose() {
    _shine.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _shine,
    builder: (context, _) => ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        fit: StackFit.expand,
        children: [
          _CardArt(cardId: widget.cardId, imageKey: widget.imageKey),
          if (widget.finish != CardFinish.normal) ...[
            IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(
                    width: 4,
                    color: widget.finish == CardFinish.gold
                        ? const Color(0xffffda68)
                        : const Color(0xffdce9f6),
                  ),
                  gradient: LinearGradient(
                    begin: Alignment(-3 + _shine.value * 6, -1),
                    end: Alignment(-1 + _shine.value * 6, 1),
                    colors: [
                      Colors.transparent,
                      (widget.finish == CardFinish.gold
                              ? const Color(0xffffdd68)
                              : const Color(0xffd9f0ff))
                          .withValues(alpha: .48),
                      Colors.white.withValues(alpha: .65),
                      Colors.transparent,
                    ],
                    stops: const [0, .4, .5, 1],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    ),
  );
}

class _InspectCardDialog extends StatefulWidget {
  final int cardId;
  final int copies;
  final CardRarity rarity;
  final CatKind? opener;
  final String collectionId;
  final CardFinish finish;
  final List<String> variantKeys;
  final Map<String, int> variantCopies;
  final String? selectedKey;
  const _InspectCardDialog({
    required this.cardId,
    required this.copies,
    required this.rarity,
    required this.opener,
    required this.collectionId,
    this.finish = CardFinish.normal,
    this.variantKeys = const [],
    this.variantCopies = const {},
    this.selectedKey,
  });

  @override
  State<_InspectCardDialog> createState() => _InspectCardDialogState();
}

class _InspectCardDialogState extends State<_InspectCardDialog>
    with SingleTickerProviderStateMixin {
  double _turn = 0;
  double _tilt = 0;
  double _zoom = 1;
  double _zoomBase = 1;
  late final AnimationController _auto;
  late CardPalette _palette;
  Timer? _idle;
  double _spinBase = 0;
  final _arTextureKey = GlobalKey();
  final _arArtworkKey = GlobalKey();
  bool _arBusy = false;
  late int _variantIndex;

  String? get _variantKey =>
      widget.variantKeys.isEmpty ? null : widget.variantKeys[_variantIndex];
  CardRarity get _activeRarity => _variantKey == null
      ? widget.rarity
      : CardRarity.values.byName(_variantKey!.split(':')[1]);
  CardFinish get _activeFinish => _variantKey == null
      ? widget.finish
      : CardFinish.values.byName(_variantKey!.split(':')[2]);
  int get _activeCopies => _variantKey == null
      ? widget.copies
      : (widget.variantCopies[_variantKey] ?? widget.copies);

  Future<void> _openAr() async {
    if (_arBusy) return;
    _pauseSpin();
    if (!CardAr.supportedPlatform) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Realidad aumentada'),
          content: const Text(
            'Abre esta opción en la app Android. La versión web y iOS todavía no incluyen este modo.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Entendido'),
            ),
          ],
        ),
      );
      if (mounted) _scheduleSpin();
      return;
    }
    final consent = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tu carta en el mundo real'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'La carta aparece directamente sobre tu cámara, sin buscar superficies. Desliza para girarla 360°, pellizca para cambiar su tamaño y usa Mover para colocarla donde quieras.\n\nSolo guardaremos la foto si eliges «Guardar en el bloc». Si tu bloc está conectado, esa foto se sincronizará con Firebase y será visible para las personas de tu espacio compartido.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Abrir cámara AR'),
          ),
        ],
      ),
    );
    if (consent != true || !mounted) {
      if (mounted) _scheduleSpin();
      return;
    }
    setState(() {
      _arBusy = true;
      _turn = 0;
      _tilt = 0;
      _zoom = 1;
    });
    try {
      await WidgetsBinding.instance.endOfFrame;
      final boundary =
          _arTextureKey.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
      Uint8List? animatedTexture;
      Rect? animatedRect;
      if (isCelestialCard(widget.cardId)) {
        final art =
            _arArtworkKey.currentContext!.findRenderObject()! as RenderBox;
        final origin = art.localToGlobal(Offset.zero, ancestor: boundary);
        animatedRect = Rect.fromLTWH(
          origin.dx / boundary.size.width,
          origin.dy / boundary.size.height,
          art.size.width / boundary.size.width,
          art.size.height / boundary.size.height,
        );
        final bytes = await rootBundle.load(cardAsset(widget.cardId)!);
        animatedTexture = bytes.buffer.asUint8List(
          bytes.offsetInBytes,
          bytes.lengthInBytes,
        );
      }
      final image = await boundary.toImage(pixelRatio: 2);
      late Uint8List texture;
      try {
        texture = (await image.toByteData(
          format: ui.ImageByteFormat.png,
        ))!.buffer.asUint8List();
      } finally {
        image.dispose();
      }
      setState(() => _turn = math.pi);
      await WidgetsBinding.instance.endOfFrame;
      final backImage = await boundary.toImage(pixelRatio: 2);
      late Uint8List backTexture;
      try {
        backTexture = (await backImage.toByteData(
          format: ui.ImageByteFormat.png,
        ))!.buffer.asUint8List();
      } finally {
        backImage.dispose();
      }
      setState(() => _turn = 0);
      final photo = await CardAr.capture(
        texture,
        backTexture: backTexture,
        animatedTexture: animatedTexture,
        animatedRect: animatedRect,
      );
      if (photo == null || !mounted) return;
      final save = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => CardArPhotoReview(photo: photo),
      );
      if (save == true && mounted) Navigator.pop(context, photo);
    } on PlatformException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message ?? 'No se pudo abrir AR.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No pudimos preparar la carta para AR. Vuelve a intentar.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _arBusy = false);
        _scheduleSpin();
      }
    }
  }

  String get _openerName => widget.opener == null
      ? 'Maru & Lady'
      : widget.opener == CatKind.maru
      ? 'Maru'
      : 'Lady';

  String get _collectionTitle => switch (widget.collectionId) {
    anniversaryCollectionId => anniversaryCollectionTitle,
    anniversaryCollectionV2Id => anniversaryCollectionV2Title,
    _ => anniversaryCollectionTitle,
  };

  String get _collectionEdition => switch (widget.collectionId) {
    anniversaryCollectionId => anniversaryCollectionEdition,
    anniversaryCollectionV2Id => 'EDICIÓN PAPU',
    _ => anniversaryCollectionEdition,
  };

  @override
  void initState() {
    super.initState();
    _variantIndex = widget.selectedKey == null
        ? 0
        : math.max(0, widget.variantKeys.indexOf(widget.selectedKey!));
    _palette = CardPalette(
      primary: cardColor(widget.cardId),
      secondary: const Color(0xff49317b),
      accent: Color.lerp(cardColor(widget.cardId), Colors.white, .48)!,
    );
    CardPaletteExtractor.load(widget.cardId, cardColor(widget.cardId)).then((
      palette,
    ) {
      if (mounted) setState(() => _palette = palette);
    });
    _auto =
        AnimationController(vsync: this, duration: const Duration(seconds: 14))
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

  Widget _collectionBack() => Stack(
    fit: StackFit.expand,
    children: [
      Positioned(
        top: -65,
        right: -48,
        child: Container(
          width: 190,
          height: 190,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xffd76dff).withValues(alpha: .16),
          ),
        ),
      ),
      Positioned(
        bottom: -72,
        left: -55,
        child: Container(
          width: 185,
          height: 185,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xff54d9ff).withValues(alpha: .13),
          ),
        ),
      ),
      Positioned(
        top: -20,
        left: 126,
        child: Transform.rotate(
          angle: .18,
          child: Container(
            width: 42,
            height: 410,
            color: Colors.white.withValues(alpha: .055),
          ),
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
        child: Column(
          children: [
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.auto_awesome, color: Color(0xffa8edff), size: 13),
                SizedBox(width: 7),
                Text(
                  'SOBRE SORPRESA',
                  style: TextStyle(
                    color: Color(0xffbdefff),
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                  ),
                ),
                SizedBox(width: 7),
                Icon(Icons.auto_awesome, color: Color(0xffa8edff), size: 13),
              ],
            ),
            const SizedBox(height: 18),
            Container(
              width: 82,
              height: 82,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xffff80d7), Color(0xff8c65ff)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(color: const Color(0xffffed9c), width: 2),
                boxShadow: const [
                  BoxShadow(color: Color(0x88dc56ff), blurRadius: 22),
                ],
              ),
              child: const Icon(
                Icons.pets_rounded,
                color: Colors.white,
                size: 48,
              ),
            ),
            const SizedBox(height: 19),
            Text(
              _collectionTitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 23,
                height: 1,
                fontWeight: FontWeight.w900,
                letterSpacing: .7,
                shadows: [Shadow(color: Color(0xffe55cfa), blurRadius: 12)],
              ),
            ),
            const SizedBox(height: 5),
            Text(
              _collectionEdition,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xffffe48d),
                fontSize: 14,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.1,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xffffed9c).withValues(alpha: .75),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.auto_awesome,
                    color: Color(0xffffed9c),
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    widget.opener == null
                        ? 'DESCUBIERTA POR MARU & LADY'
                        : 'LA ABRIÓ ${_openerName.toUpperCase()}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      letterSpacing: .7,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ],
  );

  Widget _collectionFront() => Stack(
    fit: StackFit.expand,
    children: [
      Positioned.fill(
        child: CustomPaint(
          painter: HoloPatternPainter(
            progress: ((_turn / (math.pi * 2)) % 1).abs(),
          ),
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 38, 12, 10),
        child: Column(
          children: [
            Expanded(
              child: _FoilArt(
                cardId: widget.cardId,
                finish: _activeFinish,
                imageKey: _arArtworkKey,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              cardName(widget.cardId),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 19,
                fontWeight: FontWeight.w900,
                shadows: [Shadow(color: Color(0xff321453), blurRadius: 8)],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (widget.opener != null)
                  CatActor(
                    cat: widget.opener!,
                    size: 28,
                    action: CatAction.collection,
                    active: true,
                    showLabel: false,
                  )
                else
                  const Icon(Icons.pets, color: Color(0xffffe79b), size: 20),
                const SizedBox(width: 5),
                Text(
                  widget.opener == null
                      ? 'Descubierta por $_openerName'
                      : 'La abrió $_openerName',
                  style: const TextStyle(
                    color: Color(0xffffedbe),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              '$_collectionTitle · ${widget.collectionId == anniversaryCollectionV2Id ? 'VOL. 02' : 'VOL. 01'}',
              style: const TextStyle(
                color: Color(0xfffff0bf),
                fontSize: 9,
                letterSpacing: .8,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
      Positioned(
        top: 7,
        right: 8,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                _palette.accent,
                Color.lerp(_palette.primary, Colors.black, .28)!,
              ],
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: .75)),
            boxShadow: const [
              BoxShadow(color: Color(0x66000000), blurRadius: 9),
            ],
          ),
          child: Text(
            '${_activeRarity.label.toUpperCase()} · ×$_activeCopies',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 8,
              fontWeight: FontWeight.w900,
              letterSpacing: .6,
            ),
          ),
        ),
      ),
      Positioned.fill(
        child: IgnorePointer(
          child: Container(
            margin: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(17),
              border: Border.all(
                color: Colors.white.withValues(alpha: .32),
                width: 1.2,
              ),
            ),
          ),
        ),
      ),
    ],
  );

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
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: front
            ? LinearGradient(
                colors: [_palette.accent, _palette.primary, _palette.secondary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : const LinearGradient(
                colors: [Color(0xff563394), Color(0xff211246)],
              ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: rarityColor(_activeRarity), width: 4),
        boxShadow: [
          BoxShadow(
            color: _palette.accent.withValues(alpha: .58),
            blurRadius: 30,
          ),
        ],
      ),
      child: front ? _collectionFront() : _collectionBack(),
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
                      '${_activeRarity.label} · ${cardNames[widget.cardId]}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
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
                onDoubleTap: () {
                  _touch();
                  setState(() => _zoom = _zoom > 1.1 ? 1 : 1.38);
                },
                onScaleStart: (_) {
                  _pauseSpin();
                  _zoomBase = _zoom;
                },
                onScaleEnd: (_) => _scheduleSpin(),
                onScaleUpdate: (details) => setState(() {
                  if (details.pointerCount >= 2) {
                    _zoom = (_zoomBase * details.scale).clamp(.72, 1.5);
                  } else {
                    _turn += details.focalPointDelta.dx * .015;
                    _tilt = (_tilt - details.focalPointDelta.dy * .007).clamp(
                      -.35,
                      .35,
                    );
                  }
                }),
                child: Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, .0012)
                    ..scaleByDouble(_zoom, _zoom, _zoom, 1)
                    ..rotateX(_tilt)
                    ..rotateY(front ? _turn : _turn + math.pi),
                  child: _RarityFrame(
                    rarity: _activeRarity,
                    forceShine: _auto.isAnimating,
                    child: RepaintBoundary(key: _arTextureKey, child: card),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (widget.variantKeys.length > 1) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      tooltip: 'Carta acumulada anterior',
                      onPressed: () => setState(() {
                        _variantIndex =
                            (_variantIndex - 1 + widget.variantKeys.length) %
                            widget.variantKeys.length;
                        _turn = 0;
                      }),
                      icon: const Icon(
                        Icons.chevron_left_rounded,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'Carta ${_variantIndex + 1} de ${widget.variantKeys.length}',
                      style: const TextStyle(
                        color: Color(0xffffe79b),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Carta acumulada siguiente',
                      onPressed: () => setState(() {
                        _variantIndex =
                            (_variantIndex + 1) % widget.variantKeys.length;
                        _turn = 0;
                      }),
                      icon: const Icon(
                        Icons.chevron_right_rounded,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 6,
                children: [
                  for (final finish in CardFinish.values)
                    _FinishChip(
                      finish: finish,
                      owned: widget.variantKeys.any(
                        (key) => key.contains(
                          ':${_activeRarity.name}:${finish.name}',
                        ),
                      ),
                      active: finish == _activeFinish,
                    ),
                ],
              ),
              const SizedBox(height: 4),
              TextButton.icon(
                onPressed: _arBusy ? null : _openAr,
                icon: const Icon(Icons.view_in_ar, color: Color(0xffffe79b)),
                label: Text(
                  _arBusy ? 'Preparando cámara…' : 'AR · Cámara 3D',
                  style: const TextStyle(color: Color(0xffffe79b)),
                ),
              ),
              const Text(
                'Desliza para girar · pellizca para acercar',
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
                      setState(() => _zoom = (_zoom - .15).clamp(.72, 1.5));
                    },
                    icon: const Icon(Icons.zoom_out, color: Colors.white),
                    tooltip: 'Alejar',
                  ),
                  Text(
                    '${(_zoom * 100).round()}%',
                    style: const TextStyle(
                      color: Color(0xffffe79b),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      _touch();
                      setState(() => _zoom = (_zoom + .15).clamp(.72, 1.5));
                    },
                    icon: const Icon(Icons.zoom_in, color: Colors.white),
                    tooltip: 'Acercar',
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

class _FinishChip extends StatelessWidget {
  final CardFinish finish;
  final bool owned, active;
  const _FinishChip({
    required this.finish,
    required this.owned,
    required this.active,
  });

  @override
  Widget build(BuildContext context) => Chip(
    avatar: Icon(
      owned
          ? (finish == CardFinish.gold ? Icons.auto_awesome : Icons.style)
          : Icons.help_outline,
      size: 15,
      color: active ? const Color(0xff3b205f) : const Color(0xffffe79b),
    ),
    label: Text(owned ? finish.label : '?'),
    labelStyle: TextStyle(
      color: active ? const Color(0xff3b205f) : const Color(0xffffe79b),
      fontSize: 10,
      fontWeight: FontWeight.w800,
    ),
    backgroundColor: active ? const Color(0xffffe79b) : const Color(0x332f1b58),
    side: BorderSide(color: owned ? const Color(0xffffe79b) : Colors.white24),
  );
}

class CardRevealDialog extends StatefulWidget {
  final int cardId, copies, total;
  final CatKind opener;
  final CardRarity rarity;
  final CardFinish finish;
  final String collectionId;
  const CardRevealDialog({
    super.key,
    required this.cardId,
    required this.copies,
    required this.total,
    required this.opener,
    required this.rarity,
    this.finish = CardFinish.normal,
    this.collectionId = anniversaryCollectionId,
  });

  @override
  State<CardRevealDialog> createState() => _CardRevealDialogState();
}

class _CardRevealDialogState extends State<CardRevealDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _foil;
  late CardPalette _palette;
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
    _palette = CardPalette(
      primary: cardColor(cardId),
      secondary: const Color(0xff49317b),
      accent: Color.lerp(cardColor(cardId), Colors.white, .48)!,
    );
    CardPaletteExtractor.load(cardId, cardColor(cardId)).then((palette) {
      if (mounted) setState(() => _palette = palette);
    });
    _foil = AnimationController(
      vsync: this,
      duration: Duration(
        milliseconds: widget.rarity == CardRarity.legendary
            ? 7200
            : widget.rarity == CardRarity.epic
            ? 8200
            : 9400,
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
    if (widget.rarity == CardRarity.celestial) {
      return CelestialRevealDialog(
        cardId: cardId,
        copies: copies,
        collectionId: widget.collectionId,
      );
    }
    final bonus = total == 6 || total == 9;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(18),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: -math.pi / 2, end: 0),
        duration: Duration(milliseconds: 700 + widget.rarity.rank * 230),
        curve: widget.rarity.rank >= 3 ? Curves.elasticOut : Curves.easeOutBack,
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
                '✦ ¡${widget.rarity.label.toUpperCase()}! ✦',
                style: TextStyle(
                  color: rarityColor(widget.rarity),
                  fontWeight: FontWeight.w900,
                  fontSize: 19,
                  letterSpacing: 2,
                  shadows: [Shadow(color: Color(0xfffc57e5), blurRadius: 12)],
                ),
              ),
              const SizedBox(height: 5),
              Text(
                widget.finish.label,
                style: const TextStyle(
                  color: Color(0xffffedbe),
                  fontWeight: FontWeight.w800,
                ),
              ),
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
                      final breathe = 1 + math.sin(orbit - math.pi / 2) * .018;
                      final float = math.sin(orbit * 2) * 3;
                      return Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.identity()
                          ..setEntry(3, 2, .0018)
                          ..translateByDouble(0, float, 0, 1)
                          ..scaleByDouble(breathe, breathe, breathe, 1)
                          ..rotateX(_pointerX + math.sin(orbit) * .05)
                          ..rotateY(_pointerY + math.cos(orbit) * .085)
                          ..rotateZ(math.sin(orbit * 2 + .8) * .018),
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
                              _palette.accent,
                              _palette.primary,
                              _palette.secondary,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: rarityColor(widget.rarity),
                            width: 3,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: _palette.accent.withValues(alpha: .65),
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
                                builder: (context, _) => Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    CustomPaint(
                                      painter: HoloPatternPainter(
                                        progress: _foil.value,
                                      ),
                                    ),
                                    CustomPaint(
                                      painter: _RevealSparklePainter(
                                        progress: _foil.value,
                                        color: rarityColor(widget.rarity),
                                      ),
                                    ),
                                    CustomPaint(
                                      painter: _RarityBurstPainter(
                                        progress: _foil.value,
                                        rarity: widget.rarity,
                                      ),
                                    ),
                                  ],
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
                                      child: _FoilArt(
                                        cardId: cardId,
                                        finish: widget.finish,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                    ),
                                    child: Text(
                                      cardName(cardId),
                                      textAlign: TextAlign.center,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
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
                                  Text(
                                    'SOBRE SORPRESA · ${widget.collectionId == anniversaryCollectionV2Id ? 'VOL. 02' : 'VOL. 01'}',
                                    style: const TextStyle(
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
          active: _run.value < .13,
          focus: 1,
          showLabel: false,
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
                      top: 27 + math.sin(_run.value * math.pi * 2) * 6,
                      child: Transform.flip(
                        flipX: _run.status == AnimationStatus.reverse,
                        child: const _RealMouse(size: 30),
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
          active: _run.value > .87,
          focus: -1,
          showLabel: false,
        ),
      ],
    ),
  );
}

class _RealMouse extends StatelessWidget {
  final double size;
  const _RealMouse({required this.size});

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(painter: _RealMousePainter()),
  );
}

class _RealMousePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final body = Paint()..color = const Color(0xff81726d);
    final pink = Paint()..color = const Color(0xffe8a0aa);
    final line = Paint()
      ..color = const Color(0xff5b4b47)
      ..strokeWidth = size.width * .065
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(
      Path()
        ..moveTo(size.width * .18, size.height * .58)
        ..cubicTo(
          -size.width * .12,
          size.height * .34,
          size.width * .04,
          size.height * .12,
          size.width * .22,
          size.height * .28,
        ),
      line,
    );
    canvas.drawOval(
      Rect.fromLTWH(
        size.width * .18,
        size.height * .30,
        size.width * .68,
        size.height * .48,
      ),
      body,
    );
    canvas.drawCircle(
      Offset(size.width * .63, size.height * .30),
      size.width * .12,
      pink,
    );
    canvas.drawCircle(
      Offset(size.width * .80, size.height * .47),
      size.width * .04,
      Paint()..color = Colors.black,
    );
    canvas.drawCircle(
      Offset(size.width * .88, size.height * .57),
      size.width * .045,
      pink,
    );
    for (final dy in [-.06, .03, .12]) {
      canvas.drawLine(
        Offset(size.width * .82, size.height * (.58 + dy)),
        Offset(size.width, size.height * (.52 + dy)),
        line..strokeWidth = 1,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
