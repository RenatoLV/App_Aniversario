import 'backend.dart';

/// The mural transport is separate from game progress and local persistence.
abstract interface class NoteCloud {
  String? get userId;
  String newId();
  Stream<List<Map<String, dynamic>>> watch(String spaceId);
  Future<void> put(String spaceId, String id, Map<String, dynamic> note);
  Future<void> startPresence(String spaceId);
}

class FirebaseNoteCloud implements NoteCloud {
  @override
  String? get userId => Backend.uid;
  @override
  String newId() => Backend.newNoteId();
  @override
  Stream<List<Map<String, dynamic>>> watch(String spaceId) =>
      Backend.notes(spaceId);
  @override
  Future<void> put(String spaceId, String id, Map<String, dynamic> note) =>
      Backend.putNote(spaceId, id, note);
  @override
  Future<void> startPresence(String spaceId) => Backend.startPresence(spaceId);
}
