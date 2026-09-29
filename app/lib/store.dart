import 'dart:convert';
import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'game.dart';
import 'backend.dart';
import 'meme_cards.dart';

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
String? cardAsset(int id) =>
    id < sampleCardCount ? null : memeAssets[id - sampleCardCount];

enum CardRarity { common, epic, legendary }

extension CardRarityLook on CardRarity {
  String get label => switch (this) {
    CardRarity.common => 'Común',
    CardRarity.epic => 'Épica',
    CardRarity.legendary => 'Legendaria',
  };
}

class PocketNote {
  String text;
  double x, y;
  String? cloudId;
  PocketNote(this.text, this.x, this.y, {this.cloudId});
  Map<String, dynamic> toJson() => {
    'text': text,
    'x': x,
    'y': y,
    'cloudId': cloudId,
  };
}

class GameStore extends ChangeNotifier {
  final SharedPreferences prefs;
  BlockGame game = BlockGame();
  int coins = 30, best = 0;
  int get totalCards => cards.values.fold(0, (sum, copies) => sum + copies);
  Map<int, int> cards = {};
  Map<int, CardRarity> rarities = {};
  CardRarity lastOpenedRarity = CardRarity.common;
  List<PocketNote> notes = [];
  String? _cloudSpaceId;
  StreamSubscription<List<Map<String, dynamic>>>? _notesSubscription;
  List<Map<String, dynamic>> _latestCloudNotes = [];
  final Set<String> _dirtyNotes = {};
  String? saveError;
  Future<void> _pending = Future.value();
  GameStore(this.prefs) {
    final raw = prefs.getString('rincon.v1');
    if (raw == null) return;
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      coins = j['coins'] as int;
      best = j['best'] as int;
      cards = (j['cards'] as Map<String, dynamic>).map(
        (k, v) => MapEntry(int.parse(k), v as int),
      );
      rarities = ((j['rarities'] as Map<String, dynamic>?) ?? {}).map(
        (k, v) =>
            MapEntry(int.parse(k), CardRarity.values[(v as int).clamp(0, 2)]),
      );
      notes = (j['notes'] as List)
          .map(
            (n) => PocketNote(
              n['text'] as String,
              (n['x'] as num).toDouble(),
              (n['y'] as num).toDouble(),
              cloudId: n['cloudId'] as String?,
            ),
          )
          .toList();
      game.restore(j['game'] as Map<String, dynamic>);
    } catch (_) {
      coins = 30;
      best = 0;
      cards = {};
      rarities = {};
      notes = [];
      game = BlockGame();
      saveError = 'No pudimos leer el guardado anterior. Se conserva una copia de recuperación.';
      prefs.setString('rincon.recovery', raw);
    }
  }

  Future<void> connectCloud(String spaceId) async {
    if (_cloudSpaceId == spaceId) return;
    await _notesSubscription?.cancel();
    for (final note in notes.where((n) => n.cloudId == null).toList()) {
      note.cloudId = await Backend.createNote(
        spaceId,
        note.text,
        note.x,
        note.y,
      );
    }
    await save();
    _cloudSpaceId = spaceId;
    _notesSubscription = Backend.notes(spaceId).listen(
      (rows) {
        _latestCloudNotes = rows;
        _mergeCloudNotes();
      },
      onError: (_) {
        saveError = 'Las notas siguen guardadas aquí, pero se interrumpió la sincronización.';
        notifyListeners();
      },
    );
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
      final same =
          local != null &&
          local.text == row['body'] &&
          local.x == (row['x'] as num).toDouble() &&
          local.y == (row['y'] as num).toDouble();
      if (same) _dirtyNotes.remove(id);
      merged.add(
        _dirtyNotes.contains(id) && local != null
            ? local
            : PocketNote(
                row['body'] as String,
                (row['x'] as num).toDouble(),
                (row['y'] as num).toDouble(),
                cloudId: id,
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
    await save();
    if (_cloudSpaceId == null) return;
    final id = note.cloudId;
    if (id != null) _dirtyNotes.add(id);
    try {
      if (id == null) {
        note.cloudId = await Backend.createNote(
          _cloudSpaceId!,
          note.text,
          note.x,
          note.y,
        );
        _dirtyNotes.add(note.cloudId!);
      } else {
        await Backend.updateNote(id, note.text, note.x, note.y);
      }
      _mergeCloudNotes();
    } catch (_) {
      saveError =
          'Nota guardada aquí; la sincronización con Supabase está pendiente.';
      notifyListeners();
    }
  }

  Future<void> save() {
    final snapshot = jsonEncode({
      'coins': coins,
      'best': best,
      'cards': cards.map((k, v) => MapEntry('$k', v)),
      'rarities': rarities.map((k, v) => MapEntry('$k', v.index)),
      'notes': notes.map((n) => n.toJson()).toList(),
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

  bool place(int x, int y) {
    final earned = game.place(x, y);
    if (earned == null) return false;
    coins += earned;
    best = max(best, game.score);
    save();
    Backend.submitHighscore('blocks-v1', game.score).catchError((_) {});
    return true;
  }

  int? openPack({Random? random}) {
    if (coins < 20) return null;
    final generator = random ?? Random();
    final id = sampleCardCount + generator.nextInt(memeNames.length);
    final roll = generator.nextInt(100);
    lastOpenedRarity = roll < 5
        ? CardRarity.legendary
        : roll < 27
        ? CardRarity.epic
        : CardRarity.common;
    coins -= 20;
    cards[id] = (cards[id] ?? 0) + 1;
    if (lastOpenedRarity.index > (rarities[id] ?? CardRarity.common).index) {
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
}
