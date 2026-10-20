import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:nuestro_rincon/lucky_palace/art/lucky_cabinet_art.dart';
import 'package:nuestro_rincon/lucky_palace/lucky_demo.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('CPU recording sample, foreground versus full redraw', () {
    const size = Size(390, 585);
    List<int> sample(bool full) {
      final times = <int>[];
      for (var i = 0; i < 130; i++) {
        final recorder = PictureRecorder();
        final canvas = Canvas(recorder);
        final watch = Stopwatch()..start();
        if (full) {
          const LuckyCabinetPainter(
            portrait: true,
            foreground: false,
          ).paint(canvas, size);
        }
        LuckyCabinetPainter(
          portrait: true,
          frame: LuckyDemoFrame(
            started: true,
            demo: LuckyDemo.big,
            seconds: (i % 120) / 120 * 6.2,
          ),
        ).paint(canvas, size);
        final picture = recorder.endRecording();
        watch.stop();
        picture.dispose();
        if (i >= 10) times.add(watch.elapsedMicroseconds);
      }
      times.sort();
      return times;
    }

    final full = sample(true), animated = sample(false);
    // Diagnostic CPU recording only. No GPU raster, device FPS or hard timing gate.
    // ignore: avoid_print
    print(
      'Lucky CPU debug, 120 samples, 390x585: full p50=${full[60]}us p95=${full[114]}us p99=${full[118]}us; foreground p50=${animated[60]}us p95=${animated[114]}us p99=${animated[118]}us',
    );
    expect(animated.length, 120);
  });
}
