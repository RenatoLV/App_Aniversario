import 'dart:convert';
import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'game.dart';
import 'backend.dart';
import 'meme_cards.dart';
import 'celestial_cards.dart';
export 'celestial_cards.dart';
import 'cat_character.dart';
import 'progress_sync.dart';
import 'note_cloud.dart';

const anniversaryCollectionId = 'momazos-v1-anniversary';
const anniversaryCollectionTitle = 'MOMAZOS VOL. 1';
const anniversaryCollectionEdition = 'EDICIÓN ANIVERSARIO';
const anniversaryCollectionV2Id = 'momazos-v2-anniversary';
const anniversaryCollectionV2Title = 'MOMAZOS VOL. 2';

const _sampleNames = [
  'Modo siesta',
  'La mirada del juicio',
  'Somos un equipo',
  'Cinco minutos más',
  'Dueño del sillón',
  'Mi lugar favorito',
];
// Celestial IDs use their own range so later static/GIF imports cannot shift
// cards that players already own.
final cardNames = Map<int, String>.unmodifiable({
  for (var i = 0; i < _sampleNames.length; i++) i: _sampleNames[i],
  for (var i = 0; i < memeNames.length; i++) i + sampleCardCount: memeNames[i],
  for (final card in celestialCatalog) card.id: card.name,
});
final _celestials = {for (final card in celestialCatalog) card.id: card};
String cardName(int id) => cardNames[id] ?? 'Carta desconocida';
CelestialCardDefinition? celestialCard(int id) => _celestials[id];
bool isCelestialCard(int id) => _celestials.containsKey(id);
const cardIcons = ['😴', '😼', '🐾', '🥱', '👑', '💛'];
const sampleCardCount = 6;
final anniversaryCollectionCards = List<int>.unmodifiable([
  for (var i = 0; i < memeVolumes.length; i++)
    if (memeVolumes[i] == 1) i + sampleCardCount,
  for (final card in celestialCatalog)
    if (card.volume == 1) card.id,
]);
final anniversaryCollectionV2Cards = List<int>.unmodifiable([
  for (var i = 0; i < memeVolumes.length; i++)
    if (memeVolumes[i] == 2) i + sampleCardCount,
  for (final card in celestialCatalog)
    if (card.volume == 2) card.id,
]);

List<int> cardsForCollection(String collectionId) => switch (collectionId) {
  anniversaryCollectionId => anniversaryCollectionCards,
  anniversaryCollectionV2Id => anniversaryCollectionV2Cards,
  _ => const <int>[],
};
String? cardAsset(int id) => isCelestialCard(id)
    ? celestialCard(id)!.asset
    : id < sampleCardCount || id >= sampleCardCount + memeAssets.length
    ? null
    : memeAssets[id - sampleCardCount];

enum CardRarity { common, epic, legendary, uncommon, rare, mythic, celestial }

enum CardFinish { normal, silver, gold }

extension CardFinishLook on CardFinish {
  String get label => switch (this) {
    CardFinish.normal => 'Clásica',
    CardFinish.silver => 'Foil plateada',
    CardFinish.gold => 'Foil dorada',
  };
}

extension CardRarityLook on CardRarity {
  String get label => switch (this) {
    CardRarity.common => 'Común',
    CardRarity.epic => 'Épica',
    CardRarity.legendary => 'Legendaria',
    CardRarity.uncommon => 'Poco común',
    CardRarity.rare => 'Rara',
    CardRarity.mythic => 'Mítica',
    CardRarity.celestial => 'Celestial',
  };
  int get rank => switch (this) {
    CardRarity.common => 0,
    CardRarity.uncommon => 1,
    CardRarity.rare => 2,
    CardRarity.epic => 3,
    CardRarity.legendary => 4,
    CardRarity.mythic => 5,
    CardRarity.celestial => 6,
  };
}

class PocketNote {
  bool deleted;
  String text;
  double x, y;
  String? cloudId;
  String? imageBase64;
  String? mediaKind;
  String? mediaPath;
  double scale;
  PocketNote(
    this.text,
    this.x,
    this.y, {
    this.cloudId,
    this.imageBase64,
    this.mediaKind,
    this.mediaPath,
    this.scale = 1,
    this.deleted = false,
  });
  Map<String, dynamic> toJson() => {
    'deleted': deleted,
    'text': text,
    'x': x,
    'y': y,
    'cloudId': cloudId,
    'imageBase64': imageBase64,
    'mediaKind': mediaKind,
    'mediaPath': mediaPath,
    'scale': scale,
  };
}

class GameStore extends ChangeNotifier {
  final SharedPreferences prefs;
  late final CatCare catCare = CatCare(onChanged: save);
  final NoteCloud _noteCloud;
  BlockGame game = BlockGame();
  int coins = 30, best = 0;
  final Set<String> _wordleRewards = {};
  final Set<String> _gameRewards = {};
  static const achievementRewards = <String, (String, int)>{
    'sweet:5': ('Candy: llegar al nivel 5', 500),
    'sweet:10': ('Candy: llegar al nivel 10', 1500),
    'bomber:5': ('Bomber: ganar 5 partidas', 500),
    'bomber:10': ('Bomber: ganar 10 partidas', 1500),
    'leap:1': ('Ascenso: Subida luminosa', 300),
    'leap:2': ('Ascenso: Las compañias', 500),
    'leap:3': ('Ascenso: Ciudad gatuna', 700),
    'leap:4': ('Ascenso: Cima de Santiago', 900),
    'leap:5': ('Ascenso: Cielo estrellado', 1100),
    'leap:6': ('Ascenso: Universo', 1500),
    'leap:7': ('Ascenso: Cielo', 2000),
  };
  bool achievementUnlocked(String id) =>
      _gameRewards.contains('achievement:$id');
  int get bomberWins => _gameRewards
      .where((id) => id.startsWith('bomber:') && id.endsWith(':win'))
      .length;
  Future<void> unlockAchievement(String id) async {
    final reward = achievementRewards[id];
    if (reward == null) return;
    await rewardGameCoins('achievement:$id', reward.$2);
  }

  int get totalCards => cards.values.fold(0, (sum, copies) => sum + copies);
  Map<int, int> cards = {};
  Map<int, CardRarity> rarities = {};
  Map<int, int> cardOpeners = {};
  Map<int, String> cardCollections = {};
  CardRarity lastOpenedRarity = CardRarity.common;
  CardFinish lastOpenedFinish = CardFinish.normal;
  int packsSinceLegendary = 0;
  String? lastDiscountPackDay;
  int dailyPacksOpened = 0;
  int footballGoals = 0, footballBestStreak = 0;
  Map<String, int> _footballClaims = {};
  String _packDay(DateTime now) => '${now.year}-${now.month}-${now.day}';
  int packPriceAt(DateTime now) => lastDiscountPackDay == _packDay(now)
      ? (20 + 5 * dailyPacksOpened).clamp(20, 70)
      : 20;
  int get packPrice => packPriceAt(DateTime.now());
  Map<String, int> cardVariants = {};
  Map<String, dynamic> _tradeReceipts = {};
  List<String> variantsFor(int id) =>
      cardVariants.keys.where((key) => key.startsWith('$id:')).toList();
  List<PocketNote> notes = [];
  String? _cloudSpaceId;
  StreamSubscription<List<Map<String, dynamic>>>? _notesSubscription;
  List<Map<String, dynamic>> _latestCloudNotes = [];
  final Set<String> _dirtyNotes = {};
  final Set<String> _editingNotes = {};
  final Map<String, int> _noteRevisions = {};
  int get pendingNoteCount => _dirtyNotes.length;
  String? saveError;
  String? _noteReadError;
  String? _noteWriteError;
  String? get noteSyncError => _noteWriteError ?? _noteReadError;
  bool _noteWatchFailed = false;
  Future<void> _pending = Future.value();
  late final ProgressSync cloud = ProgressSync(
    prefs,
    _reloadProgress,
    beforeRestore: () => _pending,
  );
  Timer? _noteRetry;
  bool _sendingNotes = false;
  Completer<void>? _noteIdle;
  GameStore(this.prefs, {NoteCloud? noteCloud})
    : _noteCloud = noteCloud ?? FirebaseNoteCloud() {
    final raw = prefs.getString('rincon.v1');
    if (raw == null) return;
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      catCare.restore(j['catCare']);
      _dirtyNotes.addAll(List<String>.from(j['dirtyNotes'] ?? []));
      coins = j['coins'] as int;
      _wordleRewards.addAll(List<String>.from(j['wordleRewards'] ?? []));
      _gameRewards.addAll(List<String>.from(j['gameRewards'] ?? []));
      best = j['best'] as int;
      packsSinceLegendary = (j['packsSinceLegendary'] as int?) ?? 0;
      lastDiscountPackDay = j['lastDiscountPackDay'] as String?;
      footballGoals = (j['footballGoals'] as int?) ?? 0;
      footballBestStreak = (j['footballBestStreak'] as int?) ?? 0;
      _footballClaims = ((j['footballClaims'] as Map<String, dynamic>?) ?? {})
          .map((k, v) => MapEntry(k, (v as num).toInt()));
      dailyPacksOpened =
          ((j['dailyPacksOpened'] as num?)?.toInt() ??
                  (lastDiscountPackDay == null ? 0 : 1))
              .clamp(0, 10);
      _tradeReceipts = Map<String, dynamic>.from(j['tradeReceipts'] ?? {});
      cardVariants = ((j['cardVariants'] as Map<String, dynamic>?) ?? {}).map(
        (k, v) => MapEntry(k, v as int),
      );
      cards = (j['cards'] as Map<String, dynamic>).map(
        (k, v) => MapEntry(int.parse(k), v as int),
      );
      rarities = ((j['rarities'] as Map<String, dynamic>?) ?? {}).map(
        (k, v) => MapEntry(
          int.parse(k),
          CardRarity.values[(v as int).clamp(0, CardRarity.values.length - 1)],
        ),
      );
      cardOpeners = ((j['cardOpeners'] as Map<String, dynamic>?) ?? {}).map(
        (k, v) => MapEntry(int.parse(k), (v as num).toInt().clamp(0, 1)),
      );
      cardCollections = ((j['cardCollections'] as Map<String, dynamic>?) ?? {})
          .map((k, v) => MapEntry(int.parse(k), v as String));
      for (final id in cards.keys) {
        cardCollections[id] = anniversaryCollectionV2Cards.contains(id)
            ? anniversaryCollectionV2Id
            : anniversaryCollectionId;
      }
      notes = (j['notes'] as List)
          .map(
            (n) => PocketNote(
              n['text'] as String,
              (n['x'] as num).toDouble(),
              (n['y'] as num).toDouble(),
              cloudId: n['cloudId'] as String?,
              imageBase64: n['imageBase64'] as String?,
              mediaKind: n['mediaKind'] as String?,
              mediaPath: n['mediaPath'] as String?,
              scale: (n['scale'] as num?)?.toDouble() ?? 1,
              deleted: n['deleted'] == true,
            ),
          )
          .toList();
      game.restore(j['game'] as Map<String, dynamic>);
      if (cardVariants.isEmpty) {
        for (final entry in cards.entries) {
          cardVariants['${entry.key}:${(rarities[entry.key] ?? CardRarity.common).name}:normal'] =
              entry.value;
        }
      }
    } catch (_) {
      coins = 30;
      best = 0;
      cards = {};
      rarities = {};
      cardOpeners = {};
      cardCollections = {};
      notes = [];
      game = BlockGame();
      saveError =
          'No pudimos leer el guardado anterior. Se conserva una copia de recuperación.';
      prefs.setString('rincon.recovery', raw);
    }
  }

  Future<void> connectCloud(String spaceId) async {
    if (_cloudSpaceId == spaceId) return;
    await _noteIdle?.future;
    await cloud.start();
    await _notesSubscription?.cancel();
    final oldSpace = prefs.getString('firebase.noteSpace');
    if (oldSpace != null && oldSpace != spaceId) {
      await prefs.setString(
        'firebase.notes.recovery.$oldSpace',
        jsonEncode(notes.map((n) => n.toJson()).toList()),
      );
      notes = [];
      _dirtyNotes.clear();
      _editingNotes.clear();
    }
    for (final note in notes) {
      if (oldSpace == null || note.cloudId == null) {
        _dirtyNotes.remove(note.cloudId);
        note.cloudId = _noteCloud.newId();
        note.mediaPath = null;
        _dirtyNotes.add(note.cloudId!);
      }
    }
    _dirtyNotes.retainAll(
      notes.map((note) => note.cloudId).whereType<String>(),
    );
    await prefs.setString('firebase.noteSpace', spaceId);
    await save();
    _cloudSpaceId = spaceId;
    _latestCloudNotes = [];
    _noteRevisions.clear();
    _noteReadError = null;
    _noteWriteError = null;
    _watchNotes(spaceId);
    _noteRetry?.cancel();
    _noteRetry = Timer.periodic(
      const Duration(seconds: 12),
      (_) => retryNotes(),
    );
    unawaited(_flushNotes());
    unawaited(_noteCloud.startPresence(spaceId).catchError((_) {}));
  }

  void _watchNotes(String spaceId) {
    _noteWatchFailed = false;
    _notesSubscription = _noteCloud
        .watch(spaceId)
        .listen(
          (rows) {
            _latestCloudNotes = rows;
            final errors = rows
                .map((r) => r['mediaLoadError'])
                .whereType<String>();
            _noteReadError = errors.isEmpty ? null : errors.first;
            _noteWatchFailed = errors.isNotEmpty;
            _mergeCloudNotes();
          },
          onError: (Object error) {
            _noteWatchFailed = true;
            _noteReadError = Backend.noteErrorMessage(error);
            notifyListeners();
          },
        );
  }

  Future<void> retryNotes() async {
    if (_cloudSpaceId == null || _noteCloud.userId == null) return;
    if (_noteWatchFailed) {
      await _notesSubscription?.cancel();
      _watchNotes(_cloudSpaceId!);
    }
    await _flushNotes();
  }

  Future<void> retrySavedData() async {
    await save();
    await retryNotes();
  }

  void _mergeCloudNotes() {
    final localById = {
      for (final note in notes)
        if (note.cloudId != null) note.cloudId!: note,
    };
    final merged = <PocketNote>[];
    for (final row in _latestCloudNotes) {
      final id = row['id'] as String;
      final local = localById[id];
      final revision = row['revisionMicros'] as int?;
      final stale = revision != null && revision < (_noteRevisions[id] ?? 0);
      if (revision != null && !stale && row['fromCache'] != true) {
        _noteRevisions[id] = revision;
      }
      final next =
          local != null &&
              (_dirtyNotes.contains(id) || stale || row['fromCache'] == true)
          ? local
          : PocketNote(
              row['body'] as String,
              (row['x'] as num).toDouble(),
              (row['y'] as num).toDouble(),
              cloudId: id,
              imageBase64:
                  row['imageBase64'] as String? ??
                  (local?.mediaPath == row['mediaPath']
                      ? local?.imageBase64
                      : null),
              mediaKind: row['mediaKind'] as String?,
              mediaPath: row['mediaPath'] as String?,
              scale: (row['scale'] as num?)?.toDouble() ?? 1,
              deleted: row['deleted'] == true,
            );
      // Preserve references held by an open editor, a drag or the undo action.
      if (local != null && next != local) {
        local.text = next.text;
        local.x = next.x;
        local.y = next.y;
        local.scale = next.scale;
        local.deleted = next.deleted;
        local.imageBase64 = next.imageBase64;
        local.mediaKind = next.mediaKind;
        local.mediaPath = next.mediaPath;
      }
      merged.add(local ?? next);
    }
    merged.addAll(
      notes.where(
        (note) =>
            note.cloudId == null ||
            ((_dirtyNotes.contains(note.cloudId) ||
                    _latestCloudNotes.any((row) => row['fromCache'] == true)) &&
                !_latestCloudNotes.any((row) => row['id'] == note.cloudId)),
      ),
    );
    notes = merged;
    save();
  }

  Future<void> saveNote(PocketNote note, {bool waitForSync = true}) async {
    _editingNotes.remove(note.cloudId);
    if (_cloudSpaceId != null || note.cloudId != null) {
      note.cloudId ??= _noteCloud.newId();
      _dirtyNotes.add(note.cloudId!);
    }
    await save();
    if (waitForSync) {
      await _flushNotes();
    } else {
      unawaited(_flushNotes());
    }
  }

  void beginNoteEdit(PocketNote note) {
    if (_cloudSpaceId == null && note.cloudId == null) return;
    note.cloudId ??= _noteCloud.newId();
    _dirtyNotes.add(note.cloudId!);
    _editingNotes.add(note.cloudId!);
  }

  Future<void> deleteNote(PocketNote note) async {
    note.deleted = true;
    await saveNote(note, waitForSync: false);
  }

  Future<void> restoreNote(PocketNote note) async {
    note.deleted = false;
    await saveNote(note, waitForSync: false);
  }

  Future<void> _flushNotes() async {
    if (_cloudSpaceId == null || _sendingNotes || _noteCloud.userId == null) {
      return;
    }
    _sendingNotes = true;
    _noteIdle = Completer<void>();
    String? errorMessage;
    try {
      for (final note
          in notes
              .where(
                (n) =>
                    _dirtyNotes.contains(n.cloudId) &&
                    !_editingNotes.contains(n.cloudId),
              )
              .toList()) {
        final data = note.toJson();
        final before = jsonEncode(data);
        var uploaded = false;
        try {
          await _noteCloud.put(_cloudSpaceId!, note.cloudId!, data);
          uploaded = true;
        } catch (error) {
          errorMessage ??= Backend.noteErrorMessage(error);
        }
        final unchanged = jsonEncode(note.toJson()) == before;
        // Reuse a successfully uploaded attachment even if the document write failed.
        if (data['imageBase64'] == note.imageBase64) {
          note.mediaPath = data['mediaPath'] as String?;
        }
        if (uploaded && unchanged) _dirtyNotes.remove(note.cloudId);
        await save();
      }
    } finally {
      _noteWriteError = errorMessage;
      _sendingNotes = false;
      _noteIdle?.complete();
      _noteIdle = null;
      notifyListeners();
    }
  }

  void _reloadProgress() {
    final restored = GameStore(prefs);
    coins = restored.coins;
    catCare.restore(restored.catCare.toJson(), notify: true);
    best = restored.best;
    cards = restored.cards;
    rarities = restored.rarities;
    cardOpeners = restored.cardOpeners;
    cardCollections = restored.cardCollections;
    cardVariants = restored.cardVariants;
    _tradeReceipts = restored._tradeReceipts;
    packsSinceLegendary = restored.packsSinceLegendary;
    lastDiscountPackDay = restored.lastDiscountPackDay;
    dailyPacksOpened = restored.dailyPacksOpened;
    footballGoals = restored.footballGoals;
    footballBestStreak = restored.footballBestStreak;
    _footballClaims = restored._footballClaims;
    game = restored.game;
    notes = restored.notes;
    _dirtyNotes
      ..clear()
      ..addAll(restored._dirtyNotes);
    _wordleRewards
      ..clear()
      ..addAll(restored._wordleRewards);
    _gameRewards
      ..clear()
      ..addAll(restored._gameRewards);
    notifyListeners();
  }

  Future<void> disconnectCloud() async {
    _noteRetry?.cancel();
    await _notesSubscription?.cancel();
    await _noteIdle?.future;
    await cloud.stop();
    _cloudSpaceId = null;
    _noteReadError = null;
    _noteWriteError = null;
    await save();
    await Backend.signOut();
  }

  Future<bool> buyCatFood(CatFood food) async {
    if (coins < food.price) return false;
    coins -= food.price;
    // CatCare's callback persists coins and stock in the same cloud snapshot.
    await catCare.addFood(food);
    notifyListeners();
    return true;
  }

  Future<bool> buyCatClothing(CatClothing item) async {
    final garment = clothingById(item.id);
    if (garment == null) return false;
    if (catCare.ownsClothing(garment)) return true;
    if (coins < garment.price) return false;
    coins -= garment.price;
    await catCare.unlockClothing(garment);
    notifyListeners();
    return true;
  }

  Future<void> save() {
    final snapshot = jsonEncode({
      'coins': coins,
      'catCare': catCare.toJson(),
      'wordleRewards': _wordleRewards.toList(),
      'gameRewards': _gameRewards.toList(),
      'best': best,
      'packsSinceLegendary': packsSinceLegendary,
      'lastDiscountPackDay': lastDiscountPackDay,
      'dailyPacksOpened': dailyPacksOpened,
      'footballGoals': footballGoals,
      'footballBestStreak': footballBestStreak,
      'footballClaims': _footballClaims,
      'cardVariants': cardVariants,
      'tradeReceipts': _tradeReceipts,
      'cards': cards.map((k, v) => MapEntry('$k', v)),
      'rarities': rarities.map((k, v) => MapEntry('$k', v.index)),
      'cardOpeners': cardOpeners.map((k, v) => MapEntry('$k', v)),
      'cardCollections': cardCollections.map((k, v) => MapEntry('$k', v)),
      'notes': notes.map((n) => n.toJson()).toList(),
      'dirtyNotes': _dirtyNotes.toList(),
      'game': game.toJson(),
    });
    _pending = _pending.then((_) async {
      try {
        if (!await prefs.setString('rincon.v1', snapshot)) {
          throw StateError('save');
        }
        saveError = null;
      } catch (_) {
        saveError =
            'No se pudo guardar. Mantén la app abierta e inténtalo otra vez.';
      }
      notifyListeners();
    });
    notifyListeners();
    return _pending;
  }

  Future<bool> buyWordleHint() async {
    if (coins < 50) return false;
    coins -= 50;
    await save();
    return true;
  }

  Future<void> rewardWordle(String roundId) async {
    if (!_wordleRewards.add(roundId)) return;
    coins += 100;
    await save();
  }

  Future<void> collectLeapCoins(int amount) async {
    if (amount <= 0) return;
    coins += amount;
    await save();
  }

  /// Persisted claim IDs prevent a restored result from paying twice.
  Future<void> rewardGameCoins(String claimId, int amount) async {
    if (amount <= 0 || !_gameRewards.add(claimId)) return;
    coins += amount;
    await save();
  }

  Future<void> recordFootballGoal(String claimId, int streak) async {
    final separator = claimId.lastIndexOf(':');
    if (separator <= 0) return;
    final session = claimId.substring(0, separator);
    final attempt = int.tryParse(claimId.substring(separator + 1));
    if (attempt == null || attempt <= (_footballClaims[session] ?? 0)) return;
    // One high-water mark per run, rather than an ever-growing ID per goal.
    _footballClaims[session] = attempt;
    coins += 30;
    footballGoals++;
    footballBestStreak = max(footballBestStreak, streak);
    await save();
  }

  bool place(int x, int y) {
    final earned = game.place(x, y);
    if (earned == null) return false;
    coins += earned;
    best = max(best, game.score);
    save();
    Backend.submitHighscore('blocks-v1', game.score).catchError((_) {});
    return true;
  }

  int? openPack({
    Random? random,
    required CatKind opener,
    String collectionId = anniversaryCollectionId,
    DateTime? now,
  }) {
    final day = now ?? DateTime.now();
    final price = packPriceAt(day);
    if (coins < price) return null;
    final generator = random ?? Random();
    final catalog = cardsForCollection(collectionId);
    if (catalog.isEmpty) return null;
    final roll = generator.nextInt(100);
    final celestial = roll == 0 && catalog.any(isCelestialCard);
    final pool = catalog
        .where((id) => isCelestialCard(id) == celestial)
        .toList();
    final id = pool[generator.nextInt(pool.length)];
    lastOpenedRarity = celestial
        ? CardRarity.celestial
        : packsSinceLegendary >= 24
        ? CardRarity.legendary
        : roll < 2
        ? CardRarity.mythic
        : roll < 6
        ? CardRarity.legendary
        : roll < 18
        ? CardRarity.epic
        : roll < 38
        ? CardRarity.rare
        : roll < 65
        ? CardRarity.uncommon
        : CardRarity.common;
    packsSinceLegendary = lastOpenedRarity.rank >= CardRarity.legendary.rank
        ? 0
        : packsSinceLegendary + 1;
    final finishRoll = generator.nextInt(100);
    lastOpenedFinish = finishRoll < 5
        ? CardFinish.gold
        : finishRoll < 20
        ? CardFinish.silver
        : CardFinish.normal;
    final variant = '$id:${lastOpenedRarity.name}:${lastOpenedFinish.name}';
    cardVariants[variant] = (cardVariants[variant] ?? 0) + 1;
    coins -= price;
    dailyPacksOpened =
        (lastDiscountPackDay == _packDay(day) ? dailyPacksOpened + 1 : 1).clamp(
          0,
          10,
        );
    lastDiscountPackDay = _packDay(day);
    cards[id] = (cards[id] ?? 0) + 1;
    cardOpeners.putIfAbsent(id, () => opener.index);
    cardCollections.putIfAbsent(id, () => collectionId);
    if (!rarities.containsKey(id) ||
        lastOpenedRarity.rank > rarities[id]!.rank) {
      rarities[id] = lastOpenedRarity;
    }
    save();
    return id;
  }

  void newGame() {
    game = BlockGame();
    save();
  }

  void selectPiece(int index) {
    game.selected = index;
    notifyListeners();
  }

  @override
  void dispose() {
    _noteRetry?.cancel();
    _notesSubscription?.cancel();
    cloud.dispose();
    super.dispose();
  }
}
