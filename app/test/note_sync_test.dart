import 'dart:async';
import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nuestro_rincon/backend.dart';
import 'package:nuestro_rincon/note_cloud.dart';
import 'package:nuestro_rincon/store.dart';

class FakeNotes implements NoteCloud {
  final rows = StreamController<List<Map<String, dynamic>>>.broadcast();
  String? account;
  final sent = <String, Map<String, dynamic>>{};
  final failedIds = <String>{};
  bool failWrites = false;
  int watches = 0;
  int ids = 0;
  int uploads = 0;
  Completer<void>? heldWrite;
  @override
  String? get userId => account;
  @override
  String newId() => 'note-${++ids}';
  @override
  Stream<List<Map<String, dynamic>>> watch(String spaceId) {
    watches++;
    return rows.stream;
  }

  @override
  Future<void> startPresence(String spaceId) async {}
  @override
  Future<void> put(String spaceId, String id, Map<String, dynamic> note) async {
    await heldWrite?.future;
    if (note['imageBase64'] != null && note['mediaPath'] == null) {
      uploads++;
      note['mediaPath'] = 'spaces/$spaceId/notes/$id/photo';
    }
    if (failWrites || failedIds.contains(id)) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
      );
    }
    sent[id] = Map.of(note);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'Saving a note returns after local persistence while cloud upload waits',
    () async {
      SharedPreferences.setMockInitialValues({});
      final cloud = FakeNotes()..account = 'alice';
      final store = GameStore(
        await SharedPreferences.getInstance(),
        noteCloud: cloud,
      );
      await store.connectCloud('shared-space');
      await Future<void>.delayed(Duration.zero);
      cloud.heldWrite = Completer<void>();
      final note = PocketNote(
        'sin red',
        .2,
        .3,
        imageBase64: 'AQID',
        mediaKind: 'drawing',
      );
      store.notes.add(note);
      await store
          .saveNote(note, waitForSync: false)
          .timeout(const Duration(seconds: 1));
      expect(store.pendingNoteCount, 1);
      expect(
        jsonDecode(
          store.prefs.getString('rincon.v1')!,
        )['notes'].single['imageBase64'],
        'AQID',
      );
      cloud.heldWrite!.complete();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(store.pendingNoteCount, 0);
      store.dispose();
      await cloud.rows.close();
    },
  );
  test(
    'An offline photo and moved note survive restart and synchronize on reconnect',
    () async {
      SharedPreferences.setMockInitialValues({});
      final cloud = FakeNotes()..account = 'alice';
      final prefs = await SharedPreferences.getInstance();
      final store = GameStore(prefs, noteCloud: cloud);
      await store.connectCloud('shared-space');
      await Future<void>.delayed(Duration.zero);
      cloud.failWrites = true;
      final note = PocketNote(
        'recuerdo offline',
        .7,
        .8,
        scale: .4,
        imageBase64: 'AQID',
        mediaKind: 'photo',
      );
      store.notes.add(note);
      await store.saveNote(note);
      expect(store.pendingNoteCount, 1);
      store.dispose();
      final restored = GameStore(prefs, noteCloud: cloud);
      expect(restored.notes.single.x, .7);
      expect(restored.notes.single.scale, .4);
      expect(restored.notes.single.imageBase64, 'AQID');
      expect(restored.pendingNoteCount, 1);
      cloud.failWrites = false;
      await restored.connectCloud('shared-space');
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(restored.pendingNoteCount, 0);
      expect(cloud.sent[note.cloudId]!['x'], .7);
      expect(cloud.sent[note.cloudId]!['text'], 'recuerdo offline');
      restored.dispose();
      await cloud.rows.close();
    },
  );
  test('An offline cached mural cannot erase locally saved notes', () async {
    SharedPreferences.setMockInitialValues({});
    final cloud = FakeNotes()..account = 'alice';
    final store = GameStore(
      await SharedPreferences.getInstance(),
      noteCloud: cloud,
    );
    await store.connectCloud('shared-space');
    await Future<void>.delayed(Duration.zero);
    final first = PocketNote('primera', .1, .1);
    final second = PocketNote(
      'foto local',
      .2,
      .2,
      imageBase64: 'AQID',
      mediaKind: 'photo',
    );
    store.notes.addAll([first, second]);
    await store.saveNote(first);
    await store.saveNote(second);
    expect(store.pendingNoteCount, 0);
    cloud.rows.add([
      {
        'id': first.cloudId,
        'body': 'primera',
        'x': .1,
        'y': .1,
        'fromCache': true,
      },
    ]);
    await Future<void>.delayed(Duration.zero);
    expect(store.notes.length, 2);
    expect(store.notes.last.imageBase64, 'AQID');
    // An authoritative online deletion can still remove a clean local note.
    cloud.rows.add([
      {
        'id': first.cloudId,
        'body': 'primera',
        'x': .1,
        'y': .1,
        'fromCache': false,
      },
    ]);
    await Future<void>.delayed(Duration.zero);
    expect(store.notes.length, 1);
    store.dispose();
    await cloud.rows.close();
  });
  Future<(GameStore, FakeNotes)> setup() async {
    SharedPreferences.setMockInitialValues({});
    final transport = FakeNotes();
    final store = GameStore(
      await SharedPreferences.getInstance(),
      noteCloud: transport,
    );
    addTearDown(() async {
      store.dispose();
      await transport.rows.close();
    });
    return (store, transport);
  }

  Future<void> connect(GameStore store, FakeNotes cloud) async {
    cloud.account = 'alice';
    await store.connectCloud('shared-space');
    await Future<void>.delayed(Duration.zero);
    await store.retryNotes();
  }

  test(
    'A guest photograph is adopted at login and uploaded with its text',
    () async {
      final (store, cloud) = await setup();
      final note = PocketNote(
        'Nuestra foto',
        .2,
        .3,
        imageBase64: base64Encode([1, 2, 3]),
        mediaKind: 'photo',
      );
      store.notes.add(note);
      await store.saveNote(note);
      expect(store.pendingNoteCount, 0);
      expect(cloud.sent, isEmpty);
      await connect(store, cloud);
      expect(cloud.sent[note.cloudId]!['text'], 'Nuestra foto');
      expect(cloud.sent[note.cloudId]!['imageBase64'], note.imageBase64);
      expect(note.mediaPath, isNotNull);
      expect(store.pendingNoteCount, 0);
      expect(store.noteSyncError, isNull);
    },
  );

  test(
    'Storage success and Firestore failure reuse the uploaded image on retry',
    () async {
      final (store, cloud) = await setup();
      await connect(store, cloud);
      cloud.failWrites = true;
      final note = PocketNote(
        'Foto',
        .1,
        .2,
        imageBase64: 'AQID',
        mediaKind: 'photo',
      );
      store.notes.add(note);
      await store.saveNote(note);
      expect(store.pendingNoteCount, 1);
      expect(note.mediaPath, isNotNull);
      expect(store.noteSyncError, contains('permisos'));
      await store.save();
      expect(
        store.noteSyncError,
        isNotNull,
        reason: 'Saving locally must not hide the remote error',
      );
      cloud.failWrites = false;
      await store.retrySavedData();
      expect(cloud.uploads, 1);
      expect(store.pendingNoteCount, 0);
      expect(store.noteSyncError, isNull);
    },
  );

  test(
    'One failing photograph does not block other notes and remains durable',
    () async {
      final (store, cloud) = await setup();
      await connect(store, cloud);
      final bad = PocketNote('pendiente', .1, .1);
      cloud.failWrites = true;
      store.notes.add(bad);
      await store.saveNote(bad);
      cloud.failWrites = false;
      cloud.failedIds.add(bad.cloudId!);
      final good = PocketNote('sincronizada', .2, .2);
      store.notes.add(good);
      await store.saveNote(good);
      expect(cloud.sent[good.cloudId], isNotNull);
      expect(store.pendingNoteCount, 1);
      final restored = GameStore(store.prefs, noteCloud: cloud);
      expect(restored.pendingNoteCount, 1);
      expect(restored.notes.length, 2);
      restored.dispose();
    },
  );

  test('A failed realtime listener is restarted by the retry action', () async {
    final (store, cloud) = await setup();
    await connect(store, cloud);
    cloud.rows.addError(
      FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied'),
    );
    await Future<void>.delayed(Duration.zero);
    expect(store.noteSyncError, contains('permisos'));
    await store.retrySavedData();
    expect(cloud.watches, 2);
    cloud.rows.add([]);
    await Future<void>.delayed(Duration.zero);
    expect(store.noteSyncError, isNull);
  });

  test('Edits to an existing note while signed out remain queued', () async {
    final (store, cloud) = await setup();
    final note = PocketNote(
      'editada sin conexión',
      .2,
      .2,
      cloudId: 'existing-note',
    );
    store.notes.add(note);
    await store.saveNote(note);
    expect(store.pendingNoteCount, 1);
    expect(cloud.sent, isEmpty);
  });

  test(
    'Missing remote media does not remove the text or an existing local photo',
    () async {
      final (store, cloud) = await setup();
      await connect(store, cloud);
      final note = PocketNote(
        'foto',
        .2,
        .2,
        imageBase64: 'AQID',
        mediaKind: 'photo',
      );
      store.notes.add(note);
      await store.saveNote(note);
      cloud.rows.add([
        {
          'id': note.cloudId,
          'body': 'texto remoto',
          'x': .3,
          'y': .4,
          'scale': 1,
          'mediaKind': 'photo',
          'mediaPath': note.mediaPath,
          'mediaLoadError': 'No se encontró la foto',
        },
      ]);
      await Future<void>.delayed(Duration.zero);
      expect(store.notes.single.text, 'texto remoto');
      expect(store.notes.single.imageBase64, 'AQID');
      expect(store.noteSyncError, 'No se encontró la foto');
    },
  );

  test('Storage errors identify permissions and timeout causes', () {
    expect(
      Backend.noteErrorMessage(
        FirebaseException(plugin: 'firebase_storage', code: 'unauthorized'),
      ),
      contains('Storage'),
    );
    expect(
      Backend.noteErrorMessage(TimeoutException('upload')),
      contains('tardó demasiado'),
    );
  });

  test(
    'Adopting a recovered guest note removes stale IDs and attachment paths',
    () async {
      final (store, cloud) = await setup();
      final note = PocketNote(
        'recuperada',
        .2,
        .2,
        cloudId: 'old-note',
        imageBase64: 'AQID',
        mediaKind: 'drawing',
        mediaPath: 'spaces/old/notes/old-note/photo',
      );
      store.notes.add(note);
      await store.saveNote(note);
      expect(store.pendingNoteCount, 1);
      await connect(store, cloud);
      expect(note.cloudId, isNot('old-note'));
      expect(note.mediaPath, startsWith('spaces/shared-space/'));
      expect(store.pendingNoteCount, 0);
    },
  );
}
