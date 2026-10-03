import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:nuestro_rincon/latest_note_media.dart';

void main() {
  test(
    'An old image download cannot restore the size of a resized note',
    () async {
      final source = StreamController<NoteRows>();
      final old = Completer<NoteRows>(), recent = Completer<NoteRows>();
      final seen = <NoteRows>[];
      final sub = latestNoteMedia(
        source.stream,
        (rows) => rows.single['scale'] == 1 ? old.future : recent.future,
      ).listen(seen.add);
      source.add([
        {'id': 'photo', 'scale': 1},
      ]);
      await Future<void>.delayed(Duration.zero);
      source.add([
        {'id': 'photo', 'scale': .55},
      ]);
      await Future<void>.delayed(Duration.zero);
      expect(
        seen.last.single['scale'],
        .55,
        reason:
            'The latest geometry must arrive without waiting for any photo.',
      );
      old.complete([
        {'id': 'photo', 'scale': 1, 'imageBase64': 'old'},
      ]);
      await Future<void>.delayed(Duration.zero);
      expect(seen.length, 2);
      recent.complete([
        {'id': 'photo', 'scale': .55, 'imageBase64': 'new'},
      ]);
      await Future<void>.delayed(Duration.zero);
      expect(seen.last.single['scale'], .55);
      expect(seen.last.single['imageBase64'], 'new');
      await sub.cancel();
      await source.close();
    },
  );
  test(
    'Late photo completion after leaving a bloc does not deliver anything',
    () async {
      final source = StreamController<NoteRows>(),
          download = Completer<NoteRows>();
      final seen = <NoteRows>[];
      final sub = latestNoteMedia(
        source.stream,
        (_) => download.future,
      ).listen(seen.add);
      source.add([
        {'scale': 1},
      ]);
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();
      download.complete([
        {'scale': 2},
      ]);
      await Future<void>.delayed(Duration.zero);
      expect(seen.length, 1);
      await source.close();
    },
  );
}
