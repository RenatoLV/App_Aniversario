import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nuestro_rincon/game_audio.dart';
import 'package:nuestro_rincon/maruversary.dart';

void main() {
  test('casino, scratch and prizes share four bundled music tracks', () {
    final manifest = jsonDecode(
      File('assets/audio/music/tracks.json').readAsStringSync(),
    );
    final tracks = manifest['casino'] as List;
    expect(tracks.length, 4);
    expect(tracks.toSet().length, 4);
    for (final track in tracks) {
      expect(
        File('assets/audio/music/$track').lengthSync(),
        greaterThan(900000),
      );
    }
    for (final route in [
      '/lucky-palace',
      '/lucky-palace/scratch',
      '/lucky-palace/prizes',
    ]) {
      expect(GameAudioRouteObserver.scenes[route], 'casino');
    }
  });

  test(
    'six distinct finite anniversary celebrations render without leaking canvas state',
    () async {
      final frames = <String>{};
      for (var variant = 0; variant < 6; variant++) {
        for (final progress in [0.0, .4, 1.0]) {
          final recorder = ui.PictureRecorder();
          final canvas = Canvas(recorder);
          AnniversaryCelebrationPainter(
            progress,
            variant: variant,
          ).paint(canvas, const Size(240, 400));
          expect(canvas.getSaveCount(), 1);
          final picture = recorder.endRecording();
          final image = await picture.toImage(240, 400);
          final data = (await image.toByteData())!.buffer.asUint8List();
          if (progress == .4) {
            expect(data.any((b) => b != 0), true);
            frames.add(base64Encode(data));
            if (Platform.environment['CAPTURE_PARTY'] == '1') {
              final png = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              final file = File('build/qa/party-$variant.png');
              await file.parent.create(recursive: true);
              await file.writeAsBytes(png!.buffer.asUint8List());
            }
          } else {
            expect(data.every((b) => b == 0), true);
          }
          image.dispose();
          picture.dispose();
        }
      }
      expect(frames.length, 6);
    },
  );
}
