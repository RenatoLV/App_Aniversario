import 'dart:convert';
import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'game.dart';
import 'backend.dart';
import 'meme_cards.dart';
import 'cat_character.dart';
import 'progress_sync.dart';

const anniversaryCollectionId = 'momazos-v1-anniversary';
const anniversaryCollectionTitle = 'MOMAZOS VOL. 1';
const anniversaryCollectionEdition = 'EDICIÓN ANIVERSARIO';
const anniversaryCollectionV2Id = 'momazos-v2-anniversary';
const anniversaryCollectionV2Title = 'MOMAZOS VOL. 2';

const cardNames = [
  'Modo siesta',
  'La mirada del juicio',
  'Somos un equipo',
  'Cinco minutos más',
  'Dueño del sillón',
  'Mi lugar favorito',
  ...memeNames,
];
const cardIcons = ['😴', '😼', '🐾', '🥱', '👑', '💛'];
const sampleCardCount = 6;
final anniversaryCollectionCards = List<int>.unmodifiable([
  for (var i = 0; i < memeVolumes.length; i++)
    if (memeVolumes[i] == 1) i + sampleCardCount,
]);
final anniversaryCollectionV2Cards = List<int>.unmodifiable([
  for (var i = 0; i < memeVolumes.length; i++)
    if (memeVolumes[i] == 2) i + sampleCardCount,
]);

List<int> cardsForCollection(String collectionId) => switch (collectionId) {
  anniversaryCollectionId => anniversaryCollectionCards,
  anniversaryCollectionV2Id => anniversaryCollectionV2Cards,
  _ => const <int>[],
};
String? cardAsset(int id) =>
    id < sampleCardCount ? null : memeAssets[id - sampleCardCount];

enum CardRarity { common, epic, legendary, uncommon, rare, mythic }

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
  };
  int get rank => switch (this) {
    CardRarity.common => 0,
    CardRarity.uncommon => 1,
    CardRarity.rare => 2,
    CardRarity.epic => 3,
    CardRarity.legendary => 4,
    CardRarity.mythic => 5,
  };
}

class PocketNote {
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
  });
  Map<String, dynamic> toJson() => {
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
  BlockGame game = BlockGame();
  int coins = 30, best = 0;
  final Set<String> _wordleRewards = {};
  int get totalCards => cards.values.fold(0, (sum, copies) => sum + copies);
  Map<int, int> cards = {};
  Map<int, CardRarity> rarities = {};
  Map<int, int> cardOpeners = {};
  Map<int, String> cardCollections = {};
  CardRarity lastOpenedRarity = CardRarity.common;
  CardFinish lastOpenedFinish = CardFinish.normal;
  int packsSinceLegendary = 0;
  Map<String, int> cardVariants = {};
  List<String> variantsFor(int id) =>
      cardVariants.keys.where((key) => key.startsWith('$id:')).toList();
  List<PocketNote> notes = [];
  String? _cloudSpaceId;
  StreamSubscription<List<Map<String, dynamic>>>? _notesSubscription;
  List<Map<String, dynamic>> _latestCloudNotes = [];
  final Set<String> _dirtyNotes = {};
  int get pendingNoteCount => _dirtyNotes.length;
  String? saveError;
  Future<void> _pending = Future.value();
  late final ProgressSync cloud = ProgressSync(
    prefs,
    _reloadProgress,
    beforeRestore: () => _pending,
  );
  Timer? _noteRetry;
  bool _sendingNotes = false;
  Completer<void>? _noteIdle;
  GameStore(this.prefs) {
    final raw = prefs.getString('rincon.v1');
    if (raw == null) return;
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      _dirtyNotes.addAll(List<String>.from(j['dirtyNotes'] ?? []));
      coins = j['coins'] as int;
      _wordleRewards.addAll(List<String>.from(j['wordleRewards'] ?? []));
      best = j['best'] as int;
      packsSinceLegendary = (j['packsSinceLegendary'] as int?) ?? 0;
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
    }
    for (final note in notes) {
      if (oldSpace == null || note.cloudId == null) {
        note.cloudId = Backend.newNoteId();
        _dirtyNotes.add(note.cloudId!);
      }
    }
    await prefs.setString('firebase.noteSpace', spaceId);
    await save();
    _cloudSpaceId = spaceId;
    _notesSubscription = Backend.notes(spaceId).listen(
      (rows) {
        _latestCloudNotes = rows;
        _mergeCloudNotes();
      },
      onError: (_) {
        saveError =
            'Las notas siguen guardadas aquí, pero se interrumpió la sincronización.';
        notifyListeners();
      },
    );
    _noteRetry?.cancel();
    _noteRetry = Timer.periodic(
      const Duration(seconds: 12),
      (_) => _flushNotes(),
    );
    unawaited(_flushNotes());
    unawaited(Backend.startPresence(spaceId).catchError((_) {}));
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
      merged.add(
        _dirtyNotes.contains(id) && local != null
            ? local
            : PocketNote(
                row['body'] as String,
                (row['x'] as num).toDouble(),
                (row['y'] as num).toDouble(),
                cloudId: id,
                imageBase64:
                    row['imageBase64'] as String? ?? local?.imageBase64,
                mediaKind: row['mediaKind'] as String?,
                mediaPath: row['mediaPath'] as String?,
                scale: (row['scale'] as num?)?.toDouble() ?? 1,
              ),
      );
    }
    merged.addAll(
      notes.where(
        (note) =>
            note.cloudId == null ||
            (_dirtyNotes.contains(note.cloudId) &&
                !_latestCloudNotes.any((row) => row['id'] == note.cloudId)),
      ),
    );
    notes = merged;
    save();
  }

  Future<void> saveNote(PocketNote note) async {
    if (_cloudSpaceId != null) {
      note.cloudId ??= Backend.newNoteId();
      _dirtyNotes.add(note.cloudId!);
    }
    await save();
    await _flushNotes();
  }

  Future<void> _flushNotes() async {
    if (_cloudSpaceId == null || _sendingNotes || Backend.uid == null) return;
    _sendingNotes = true;
    _noteIdle = Completer<void>();
    try {
      for (final note
          in notes.where((n) => _dirtyNotes.contains(n.cloudId)).toList()) {
        final data = note.toJson();
        final before = jsonEncode(data);
        await Backend.putNote(_cloudSpaceId!, note.cloudId!, data);
        if (jsonEncode(note.toJson()) == before) {
          note.mediaPath = data['mediaPath'] as String?;
          _dirtyNotes.remove(note.cloudId);
        }
        await save();
      }
    } catch (_) {
      saveError =
          'Nota guardada aquí; la sincronización con Firebase está pendiente.';
      notifyListeners();
    } finally {
      _sendingNotes = false;
      _noteIdle?.complete();
      _noteIdle = null;
    }
  }

  void _reloadProgress() {
    final restored = GameStore(prefs);
    coins = restored.coins;
    best = restored.best;
    cards = restored.cards;
    rarities = restored.rarities;
    cardOpeners = restored.cardOpeners;
    cardCollections = restored.cardCollections;
    cardVariants = restored.cardVariants;
    packsSinceLegendary = restored.packsSinceLegendary;
    game = restored.game;
    notes = restored.notes;
    _dirtyNotes
      ..clear()
      ..addAll(restored._dirtyNotes);
    _wordleRewards
      ..clear()
      ..addAll(restored._wordleRewards);
    notifyListeners();
  }

  Future<void> disconnectCloud() async {
    _noteRetry?.cancel();
    await _notesSubscription?.cancel();
    await _noteIdle?.future;
    await cloud.stop();
    _cloudSpaceId = null;
    await save();
    await Backend.signOut();
  }

  Future<void> save() {
    final snapshot = jsonEncode({
      'coins': coins,
      'wordleRewards': _wordleRewards.toList(),
      'best': best,
      'packsSinceLegendary': packsSinceLegendary,
      'cardVariants': cardVariants,
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
  }) {
    if (coins < 20) return null;
    final generator = random ?? Random();
    final pool = cardsForCollection(collectionId);
    if (pool.isEmpty) return null;
    final id = pool[generator.nextInt(pool.length)];
    final roll = generator.nextInt(100);
    lastOpenedRarity = packsSinceLegendary >= 24
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
    packsSinceLegendary = lastOpenedRarity == CardRarity.legendary
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
    coins -= 20;
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
