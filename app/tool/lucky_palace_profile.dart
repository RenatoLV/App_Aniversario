import 'dart:ui';
import 'package:flutter/widgets.dart';
import 'lucky_palace_hybrid.dart' as demo;

/// Run on a real target with --profile. Reports actual Flutter timing callbacks,
/// not CPU Canvas recording or guessed FPS. Each non-overlapping window is bounded.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final frames = <FrameTiming>[];
  var window = 0;
  WidgetsBinding.instance.addTimingsCallback((batch) {
    for (final frame in batch) {
      frames.add(frame);
      if (frames.length < 300) continue;
      String percentiles(Duration Function(FrameTiming) read) {
        final values = frames.map((f) => read(f).inMicroseconds).toList()
          ..sort();
        return 'p50=${values[149]}us p95=${values[284]}us p99=${values[296]}us';
      }

      // ignore: avoid_print
      print(
        'LUCKY_PROFILE window=${++window} frames=300 '
        'build[${percentiles((f) => f.buildDuration)}] '
        'raster[${percentiles((f) => f.rasterDuration)}] '
        'total[${percentiles((f) => f.totalSpan)}]',
      );
      frames.clear();
    }
  });
  await demo.main();
}
