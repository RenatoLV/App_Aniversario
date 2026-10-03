import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'firebase_options.dart';
import 'bloc_people.dart';

class Backend {
  static bool configured = false;
  static String? initializationError;
  static FirebaseAuth get auth => FirebaseAuth.instance;
  static FirebaseFirestore get db => FirebaseFirestore.instance;
  static String? get uid => configured ? auth.currentUser?.uid : null;
  static String? space;
  static StreamSubscription<DatabaseEvent>? _presence;
  static final Map<String, String> _mediaCache = {};
  static final ValueNotifier<String> presenceStatus = ValueNotifier('');
  static StreamSubscription<DatabaseEvent>? _others;
  static DatabaseReference? _connection;
  static bool _googleReady = false;
  static String? _nickname;

  static String loginErrorMessage(Object error) {
    if (error is GoogleSignInException) {
      if (error.code == GoogleSignInExceptionCode.canceled) {
        return 'Inicio de sesión cancelado.';
      }
      return 'Google no pudo completar el acceso (${error.code.name}). ${error.description ?? "Revisa Google Play Services y tu conexión."}';
    }
    if (error is FirebaseAuthException) {
      return 'Firebase no pudo validar el acceso (${error.code}). ${error.message ?? "Vuelve a intentarlo."}';
    }
    if (error is FirebaseException) {
      return 'El acceso a los datos falló (${error.plugin}: ${error.code}). ${error.message ?? "Vuelve a intentarlo."}';
    }
    if (error is TimeoutException) {
      return 'La conexión tardó demasiado. Vuelve a intentarlo.';
    }
    return 'No pudimos completar el acceso: $error';
  }

  static Future<void> initialize() async {
    try {
      await Firebase.initializeApp(options: AppFirebaseOptions.current);
      configured = true;
    } catch (_) {
      initializationError =
          'Firebase no está disponible. Tu progreso sigue guardándose aquí.';
    }
  }

  static DocumentReference<Map<String, dynamic>> get profile =>
      db.collection('players').doc(uid!);

  static Future<Map<String, dynamic>?> membership() async {
    if (uid == null) return null;
    final data = (await profile.get().timeout(
      const Duration(seconds: 8),
    )).data();
    if (data == null) return null;
    space = data['spaceId'] as String?;
    _nickname = data['nickname'] as String?;
    unawaited(
      BlocPeople.publish(
        _nickname ?? auth.currentUser!.displayName ?? 'Jugador',
      ).catchError((_) {}),
    );
    return {
      'user_id': uid,
      'space_id': space,
      'nickname':
          data['nickname'] ?? auth.currentUser!.displayName ?? 'Jugador',
    };
  }

  static Future<Map<String, dynamic>> activate(
    String code,
    String nickname, {
    Future<String?> Function()? chooseNickname,
  }) async {
    if (!configured) throw StateError('Firebase no está disponible.');
    if (uid == null) {
      final provider = GoogleAuthProvider()
        ..setCustomParameters({'prompt': 'select_account'});
      if (kIsWeb) {
        await auth.signInWithPopup(provider);
      } else {
        if (!_googleReady) {
          await GoogleSignIn.instance.initialize(
            serverClientId:
                '273979503185-uedtn2kteikv8u0gi0tvqb7otpa9gkje.apps.googleusercontent.com',
          );
          _googleReady = true;
        }
        final account = await GoogleSignIn.instance.authenticate();
        if (account.authentication.idToken == null) {
          throw StateError('Google no entregó el token de acceso.');
        }
        await auth.signInWithCredential(
          GoogleAuthProvider.credential(
            idToken: account.authentication.idToken,
          ),
        );
      }
    }
    final existing = await membership();
    if (existing != null) return existing;
    if (chooseNickname != null) {
      final chosen = await chooseNickname();
      if (chosen == null) throw StateError('Registro pendiente de nombre.');
      nickname = chosen.trim();
    }
    final room = db.collection('spaces').doc();
    await db.runTransaction((tx) async {
      if ((await tx.get(profile)).exists) return;
      final name = nickname.isEmpty
          ? auth.currentUser!.displayName ?? 'Jugador'
          : nickname;
      tx.set(room, {'owner': uid, 'createdAt': FieldValue.serverTimestamp()});
      tx.set(room.collection('members').doc(uid), {'nickname': name});
      tx.set(profile, {
        'spaceId': room.id,
        'nickname': name,
        'email': auth.currentUser!.email,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
    return (await membership())!;
  }

  static Future<void> updateNickname(String name) async {
    name = name.trim();
    if (name.length < 2 || name.length > 24) {
      throw ArgumentError('Usa entre 2 y 24 caracteres.');
    }
    if (uid == null) throw StateError('Inicia sesión primero.');
    final batch = db.batch();
    batch.update(profile, {'nickname': name});
    final publicScores = await db
        .collection('game_scores')
        .where('user_id', isEqualTo: uid)
        .get();
    for (final score in publicScores.docs) {
      batch.update(score.reference, {'nickname': name});
    }
    if (space != null) {
      batch.set(
        db.collection('spaces').doc(space).collection('members').doc(uid),
        {'nickname': name},
      );
      final scores = await db
          .collection('spaces')
          .doc(space)
          .collection('scores')
          .where('user_id', isEqualTo: uid)
          .get();
      for (final score in scores.docs) {
        batch.update(score.reference, {'nickname': name});
      }
    }
    await batch.commit();
    _nickname = name;
    unawaited(BlocPeople.publish(name).catchError((_) {}));
    if (space != null) await startPresence(space!);
  }

  static Future<void> joinSpace(String invitation) async {
    if (uid == null) throw StateError('Inicia sesión primero.');
    final code = invitation.trim();
    if (!RegExp(r'^[a-zA-Z0-9]{20}$').hasMatch(code)) {
      throw StateError('Código inválido.');
    }
    final room = db.collection('spaces').doc(code);
    if (!(await room.get()).exists) {
      throw StateError('No encontramos ese espacio.');
    }
    await room.collection('members').doc(uid).set({
      'nickname': _nickname ?? auth.currentUser!.displayName ?? 'Jugador',
    });
    await profile.update({'spaceId': code});
    space = code;
  }

  static Future<void> startPresence(String spaceId) async {
    await stopPresence();
    if (uid == null) return;
    final root = FirebaseDatabase.instance.ref('spaces/$spaceId');
    // RTDB keeps this write queued offline; do not block installing reconnect listeners.
    unawaited(
      root.child('members/$uid').set(true).catchError((_) {
        presenceStatus.value = 'Presencia sin conexión';
      }),
    );
    final connection = root.child('presence/$uid').push();
    _connection = connection;
    _presence = FirebaseDatabase.instance.ref('.info/connected').onValue.listen(
      (event) async {
        if (event.snapshot.value != true) return;
        try {
          await connection.onDisconnect().remove();
          await connection.set({
            'name': _nickname ?? auth.currentUser!.displayName ?? 'Jugador',
            'since': ServerValue.timestamp,
          });
        } catch (_) {
          presenceStatus.value = 'Presencia sin conexión';
        }
      },
    );
    _others = root
        .child('presence')
        .onValue
        .listen(
          (event) {
            final count = event.snapshot.children
                .where((user) => user.children.isNotEmpty)
                .length;
            presenceStatus.value = '$count persona(s) conectada(s)';
          },
          onError: (_) {
            presenceStatus.value = 'Presencia sin conexión';
          },
        );
  }

  static Future<void> stopPresence() async {
    await _presence?.cancel();
    await _others?.cancel();
    final old = _connection;
    _connection = null;
    if (old != null) {
      try {
        await old.remove().timeout(const Duration(seconds: 3));
      } catch (_) {
        /* onDisconnect still removes it. */
      }
    }
    presenceStatus.value = '';
  }

  static Future<void> signOut() async {
    await stopPresence();
    await auth.signOut();
    space = null;
    _nickname = null;
    _mediaCache.clear();
    if (!kIsWeb && _googleReady) await GoogleSignIn.instance.signOut();
  }

  static String newNoteId() => db.collection('spaces').doc().id;
  static CollectionReference<Map<String, dynamic>> notesRef(String spaceId) =>
      db.collection('spaces').doc(spaceId).collection('notes');

  static Stream<List<Map<String, dynamic>>> notes(
    String spaceId,
  ) => notesRef(spaceId).snapshots(includeMetadataChanges: true).asyncExpand((
    snapshot,
  ) async* {
    // An empty offline cache is not proof that the shared mural was deleted.
    if (snapshot.metadata.isFromCache && snapshot.docs.isEmpty) return;
    // Text and positions remain available even while one image is downloading.
    yield snapshot.docs
        .map(
          (doc) => {
            ...doc.data(),
            'id': doc.id,
            'fromCache': snapshot.metadata.isFromCache,
          },
        )
        .toList();
    yield await Future.wait(
      snapshot.docs.map((doc) async {
        final data = doc.data();
        final path = data['mediaPath'] as String?;
        String? image;
        String? mediaError;
        if (path != null) {
          image = _mediaCache[path];
          if (image == null) {
            try {
              final bytes = await FirebaseStorage.instance
                  .ref(path)
                  .getData(6 * 1024 * 1024)
                  .timeout(const Duration(seconds: 30));
              if (bytes != null) {
                image = _mediaCache[path] = base64Encode(bytes);
              }
            } catch (error) {
              mediaError = noteErrorMessage(error);
            }
          }
        }
        return {
          ...data,
          'id': doc.id,
          'fromCache': snapshot.metadata.isFromCache,
          'imageBase64': image,
          'mediaLoadError': mediaError,
        };
      }),
    );
  });

  static Future<void> putNote(
    String spaceId,
    String id,
    Map<String, dynamic> note,
  ) async {
    final author = uid;
    if (author == null) {
      throw StateError('Inicia sesión para sincronizar el bloc.');
    }
    final image = note['deleted'] == true
        ? null
        : note['imageBase64'] as String?;
    String? path = note['mediaPath'] as String?;
    if (image != null && path != null && !_mediaCache.containsKey(path)) {
      try {
        final uploaded = await FirebaseStorage.instance
            .ref(path)
            .getData(6 * 1024 * 1024)
            .timeout(const Duration(seconds: 30));
        if (uploaded != null) _mediaCache[path] = base64Encode(uploaded);
      } on FirebaseException catch (error) {
        if (error.code != 'object-not-found') rethrow;
      }
    }
    if (image != null && (path == null || _mediaCache[path] != image)) {
      final bytes = base64Decode(image);
      if (bytes.length >= 6 * 1024 * 1024) {
        throw StateError('La imagen debe ocupar menos de 6 MB.');
      }
      final version = db.collection('spaces').doc().id;
      path = 'spaces/$spaceId/notes/$id/$version';
      final task = FirebaseStorage.instance
          .ref(path)
          .putData(
            bytes,
            SettableMetadata(
              contentType: note['mediaKind'] == 'drawing'
                  ? 'image/png'
                  : 'image/jpeg',
            ),
          );
      await task.timeout(
        const Duration(seconds: 90),
        onTimeout: () async {
          try {
            await task.cancel().timeout(const Duration(seconds: 2));
          } catch (_) {
            /* The local attachment remains queued. */
          }
          throw TimeoutException('Adjunto pendiente');
        },
      );
      _mediaCache[path] = image;
      note['mediaPath'] = path;
    }
    if (uid != author) {
      throw StateError('La cuenta cambió durante la subida');
    }
    await notesRef(spaceId)
        .doc(id)
        .set({
          'body': note['text'],
          'deleted': note['deleted'] == true,
          'x': note['x'],
          'y': note['y'],
          'scale': note['scale'],
          'mediaKind': note['mediaKind'],
          'mediaPath': path,
          'editor': author,
          'updatedAt': FieldValue.serverTimestamp(),
        })
        .timeout(const Duration(seconds: 20));
  }

  static String noteErrorMessage(Object error) {
    const prefix = 'Nota guardada aquí. ';
    if (error is FirebaseException) {
      final storage = error.plugin == 'firebase_storage';
      final service = storage ? 'Storage' : 'Firebase';
      switch (error.code) {
        case 'unauthorized':
        case 'permission-denied':
          return '${prefix}Faltan permisos en $service para sincronizar el bloc.';
        case 'bucket-not-found':
        case 'no-default-bucket':
          return '${prefix}El almacenamiento de fotos no está configurado.';
        case 'object-not-found':
          return '${prefix}No se encontró una imagen del bloc en la nube.';
        case 'unauthenticated':
          return '${prefix}Vuelve a iniciar sesión para sincronizar.';
        case 'quota-exceeded':
          return '${prefix}El almacenamiento alcanzó su cuota. La foto sigue pendiente.';
        default:
          return '${prefix}Sincronización pendiente ($service: ${error.code}). Se reintentará automáticamente.';
      }
    }
    if (error is TimeoutException) {
      return '${prefix}La conexión tardó demasiado; se reintentará automáticamente.';
    }
    if (error is StateError && error.message.toString().contains('6 MB')) {
      return '${prefix}La imagen debe ocupar menos de 6 MB.';
    }
    return '${prefix}La sincronización está pendiente y se reintentará automáticamente.';
  }

  static Future<List<Map<String, dynamic>>> highscores() async {
    if (uid == null) return [];
    final rows = await db.collection('game_scores').get();
    return rows.docs.map((d) => d.data()).toList();
  }

  static Stream<List<Map<String, dynamic>>> watchHighscores({String? gameId}) =>
      (gameId == null
              ? db.collection('game_scores')
              : db.collection('game_scores').where('game', isEqualTo: gameId))
          .snapshots()
          .map((s) => s.docs.map((d) => d.data()).toList());

  static Future<void> submitHighscore(String game, int score) async {
    final author = uid;
    if (author == null || score <= 0) return;
    final ref = db.collection('game_scores').doc('${author}_$game');
    final legacy = space == null
        ? null
        : db
              .collection('spaces')
              .doc(space)
              .collection('scores')
              .doc('${author}_$game');
    await db.runTransaction(
      (tx) async {
        final current = (await tx.get(ref)).data();
        final old = legacy == null ? null : (await tx.get(legacy)).data();
        final best = [
          score,
          current?['score'] as int? ?? 0,
          old?['score'] as int? ?? 0,
        ].reduce((a, b) => a > b ? a : b);
        final name = _nickname ?? auth.currentUser!.displayName ?? 'Jugador';
        final data = {
          'user_id': author,
          'nickname': name,
          'game': game,
          'score': best,
          'updated_at': FieldValue.serverTimestamp(),
        };
        if (current?['score'] != best || current?['nickname'] != name) {
          tx.set(ref, data);
        }
        // Keep older app versions and private-space rankings compatible.
        if (legacy != null &&
            (old?['score'] != best || old?['nickname'] != name)) {
          tx.set(legacy, data);
        }
      },
      timeout: const Duration(seconds: 12),
      maxAttempts: 3,
    );
  }
}
