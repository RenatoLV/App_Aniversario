import 'dart:async';

typedef NoteRows = List<Map<String, dynamic>>;

/// Show new geometry immediately; a slow image from an older snapshot must not
/// replay old positions/sizes after a newer write has been acknowledged.
Stream<NoteRows> latestNoteMedia(
  Stream<NoteRows> source,
  Future<NoteRows> Function(NoteRows) hydrate,
) => Stream<NoteRows>.multi((out) {
  var generation = 0;
  var closed = false;
  final subscription = source.listen(
    (rows) {
      final current = ++generation;
      out.add(rows);
      unawaited(() async {
        try {
          final loaded = await hydrate(rows);
          if (!closed && current == generation) out.add(loaded);
        } catch (error, stack) {
          if (!closed && current == generation) out.addError(error, stack);
        }
      }());
    },
    onError: out.addError,
    onDone: () {
      closed = true;
      out.close();
    },
  );
  out.onCancel = () {
    closed = true;
    generation++;
    return subscription.cancel();
  };
});
