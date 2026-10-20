import 'dart:convert';
import 'dart:io';
import 'package:nuestro_rincon/lucky_palace/scratch/scratch_mask.dart';

// CPU microbenchmark only: not a GPU, frame-rate or Android measurement.
void main() {
  final runs = <Map<String, num>>[];
  for (var run = 0; run < 8; run++) {
    final watch = Stopwatch()..start();
    var cleared = 0;
    for (var ticket = 0; ticket < 100; ticket++) {
      final mask = ScratchMask();
      for (var stroke = 0; stroke < 20; stroke++) {
        final x = (stroke * 29 + ticket * 7) % 440 + 20.0;
        final y = (stroke * 17 + ticket * 3) % 300 + 20.0;
        mask.segment(x, y, (x + 90) % 466, (y + 50) % 322, 30);
      }
      cleared += mask.cleared;
    }
    watch.stop();
    final sample = ScratchMask()..segment(20, 20, 460, 320, 30);
    final persistence = Stopwatch()..start();
    for (var i = 0; i < 1000; i++) {
      final copy = sample.copy();
      copy.merge(sample);
    }
    persistence.stop();
    if (run > 0) {
      runs.add({
        'segmentMicroseconds': watch.elapsedMicroseconds / 2000,
        'copyMergeMicroseconds': persistence.elapsedMicroseconds / 1000,
        'clearedChecksum': cleared,
      });
    }
  }
  final report = {
    'environment': Platform.version,
    'platform': Platform.operatingSystem,
    'kind': 'CPU JIT, 1 warm-up + 7 runs, no GPU/Android/FPS claim',
    'maskBytes': ScratchMask.byteLength,
    'base64Bytes': ScratchMask().encode().length,
    'runs': runs,
  };
  Directory('build').createSync(recursive: true);
  File(
    'build/scratch-mask-benchmark.json',
  ).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(report));
  stdout.writeln(const JsonEncoder.withIndent('  ').convert(report));
}
