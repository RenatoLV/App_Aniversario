import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'backend.dart';
import 'highscore_outbox.dart';

/// Local preferences remain the durable offline save. A revision check prevents
/// two devices from silently replacing each other's progress.
class ProgressSync extends ChangeNotifier {
  ProgressSync(this.prefs, this.onRestore, {this.beforeRestore});
  final SharedPreferences prefs;
  final VoidCallback onRestore;
  final Future<void> Function()? beforeRestore;
  static const keys = [
    'rincon.v1',
    'wordle.v1',
    'wordle.hintDay',
    'wordle.hintsUsed',
    'sweet.v1',
    'sweet.best',
    'leap.best',
    'leap.last',
  ];
  Timer? _timer;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _subscription;
  String? _user;
  bool _busy = false;
  bool _remoteChanged = true;
  bool _stopping = false;
  bool allowRestore = true;
  Completer<void>? _idle;
  String status = 'Guardado en este dispositivo';
  Map<String, dynamic>? conflict;
  DocumentReference<Map<String, dynamic>> get _ref => Backend.db
      .collection('players')
      .doc(_user)
      .collection('progress')
      .doc('current');

  String snapshot() {
    final data = <String, dynamic>{};
    for (final key in keys) {
      final value = prefs.get(key);
      if (value == null) continue;
      if (key == 'rincon.v1') {
        final core = jsonDecode(value as String) as Map<String, dynamic>;
        core.remove('notes');
        core.remove('dirtyNotes');
        data[key] = jsonEncode(core);
      } else {
        data[key] = value;
      }
    }
    return jsonEncode(data);
  }

  Future<void> prepareLocalAccount(String uid) async {
    await beforeRestore?.call();
    final owner = prefs.getString('firebase.owner');
    if (owner != null && owner != uid) {
      await prefs.setString(
        'firebase.account.$owner',
        jsonEncode({
          for (final key in [...keys, 'firebase.noteSpace'])
            if (prefs.get(key) != null) key: prefs.get(key),
        }),
      );
      final archived =
          jsonDecode(prefs.getString('firebase.account.$uid') ?? '{}')
              as Map<String, dynamic>;
      for (final key in [...keys, 'firebase.noteSpace']) {
        final value = archived[key];
        if (value is String) {
          await prefs.setString(key, value);
        } else if (value is int) {
          await prefs.setInt(key, value);
        } else {
          await prefs.remove(key);
        }
      }
      onRestore();
    }
    await prefs.setString('firebase.owner', uid);
  }

  Future<void> start() async {
    final uid = Backend.uid;
    if (uid == null || _user == uid) return;
    await prepareLocalAccount(uid);
    _user = uid;
    _stopping = false;
    _subscription = _ref.snapshots().listen(
      (_) {
        _remoteChanged = true;
        sync();
      },
      onError: (_) {
        status = 'Guardado local · esperando conexión';
        notifyListeners();
      },
    );
    _timer = Timer.periodic(const Duration(seconds: 8), (_) => sync());
    unawaited(sync());
  }

  Future<void> sync() async {
    if (_user == null || Backend.uid != _user || _busy || _stopping) {
      return;
    }
    _busy = true;
    _idle = Completer<void>();
    bool scoresPending = false;
    try {
      final local = snapshot();
      final base = prefs.getString('firebase.base.$_user');
      try {
        await _syncScores();
      } catch (_) {
        scoresPending = true;
      }
      if (conflict != null) return;
      if (!_remoteChanged && local == base) {
        status = 'Progreso sincronizado';
        return;
      }
      _remoteChanged = false;
      // Server reads ensure a stale cache cannot authorize an overwrite.
      final remote =
          (await _ref
                  .get(const GetOptions(source: Source.server))
                  .timeout(const Duration(seconds: 12)))
              .data();
      if (snapshot() != local) {
        _remoteChanged = true;
        return;
      }
      if (remote != null &&
          remote['payload'] != local &&
          remote['payload'] != base &&
          local != base &&
          local != '{}') {
        conflict = remote;
        status = 'Hay avances distintos en dos dispositivos';
      } else if (remote != null &&
          remote['payload'] != local &&
          (local == base || local == '{}')) {
        await _restore(remote['payload'] as String, expectedLocal: local);
        status = 'Progreso recuperado de tu cuenta';
      } else if (remote == null || remote['payload'] != local) {
        await _write(local, remote?['revision'] as int? ?? 0);
        status = 'Progreso sincronizado';
      } else {
        await prefs.setString('firebase.base.$_user', local);
        status = 'Progreso sincronizado';
      }
    } catch (_) {
      _remoteChanged = true;
      status = 'Guardado local · sincronización pendiente';
    } finally {
      if (scoresPending && conflict == null) {
        status = 'Guardado local · récords pendientes de sincronizar';
      }
      _busy = false;
      _idle?.complete();
      _idle = null;
      notifyListeners();
    }
  }

  Future<void> _write(String payload, int revision) async {
    if (utf8.encode(payload).length > 850000) {
      throw StateError('Guardado demasiado grande');
    }
    await Backend.db.runTransaction(
      (tx) async {
        final current = (await tx.get(_ref)).data();
        if ((current?['revision'] ?? 0) != revision) {
          throw StateError('Nueva revisión remota');
        }
        tx.set(_ref, {
          'payload': payload,
          'revision': revision + 1,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      },
      timeout: const Duration(seconds: 12),
      maxAttempts: 3,
    );
    await prefs.setString('firebase.base.$_user', payload);
  }

  Future<void> _syncScores() async {
    final user = _user!;
    await HighscoreOutbox(prefs).flush(
      user,
      Backend.submitHighscore,
      isCurrentAccount: () =>
          !_stopping && _user == user && Backend.uid == user,
    );
  }

  Future<void> _restore(String payload, {String? expectedLocal}) async {
    await beforeRestore?.call();
    if (!allowRestore) {
      throw StateError('Recuperación aplazada hasta volver al menú');
    }
    if (expectedLocal != null && snapshot() != expectedLocal) {
      throw StateError('El progreso local cambió durante la recuperación');
    }
    final data = jsonDecode(payload) as Map<String, dynamic>;
    await prefs.setString(
      'firebase.recovery.${DateTime.now().millisecondsSinceEpoch}',
      snapshot(),
    );
    final current =
        jsonDecode(prefs.getString('rincon.v1') ?? '{}')
            as Map<String, dynamic>;
    for (final key in keys) {
      final value = data[key];
      if (key == 'rincon.v1' && value is String) {
        final core = jsonDecode(value) as Map<String, dynamic>;
        core['notes'] = current['notes'] ?? [];
        core['dirtyNotes'] = current['dirtyNotes'] ?? [];
        await prefs.setString(key, jsonEncode(core));
      } else if (value is String) {
        await prefs.setString(key, value);
      } else if (value is int) {
        await prefs.setInt(key, value);
      } else if (value == null) {
        await prefs.remove(key);
      }
    }
    await prefs.setString('firebase.base.$_user', payload);
    onRestore();
  }

  Future<void> resolve({required bool keepLocal}) async {
    if (conflict == null || _busy) return;
    _busy = true;
    _idle = Completer<void>();
    try {
      final remote = (await _ref.get(
        const GetOptions(source: Source.server),
      )).data()!;
      for (final payload in [snapshot(), remote['payload']]) {
        await _ref.collection('recovery').add({
          'payload': payload,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      if (keepLocal) {
        await _write(snapshot(), remote['revision'] as int);
      } else {
        await _restore(remote['payload'] as String);
      }
      conflict = null;
      status = 'Progreso sincronizado · copia de recuperación conservada';
    } catch (_) {
      status =
          'No se pudo resolver aún. Conservamos ambos avances; revisa la conexión.';
    } finally {
      _busy = false;
      _idle?.complete();
      _idle = null;
      notifyListeners();
    }
  }

  Future<void> stop() async {
    _stopping = true;
    _timer?.cancel();
    await _subscription?.cancel();
    await _idle?.future;
    _user = null;
    conflict = null;
    status = 'Guardado en este dispositivo';
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _subscription?.cancel();
    super.dispose();
  }
}
