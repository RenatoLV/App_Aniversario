import 'dart:ui' as ui;
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:nuestro_rincon/leap.dart';
import 'package:nuestro_rincon/leap_screen.dart';
import 'package:nuestro_rincon/cat_character.dart';

void main() {
  test('Hazards render in every landscape at several animation times', () {
    for (final height in LeapWorldZone.values.map(
      (zone) => const [
        500.0,
        LeapGame.meadowHeight + 500,
        LeapGame.neighborhoodHeight + 500,
        LeapGame.cityHeight + 500,
        LeapGame.skyscraperHeight + 500,
        LeapGame.upperSkyHeight + 500,
        LeapGame.spaceHeight + 500,
        LeapGame.heavenHeight + 500,
      ][zone.index],
    )) {
      final game = LeapGame()..camera = height - 300;
      game.platforms.clear();
      game.platforms.add(
        LeapPlatform(900, 180, height, 80, LeapPlatformKind.storm),
      );
      for (var frame = 0; frame < 20; frame++) {
        game.clock = frame / 10;
        final recorder = ui.PictureRecorder();
        expect(
          () => LeapWorldPainter(
            game,
            CatKind.maru,
          ).paint(Canvas(recorder), const Size(360, 640)),
          returnsNormally,
        );
        recorder.endRecording().dispose();
      }
    }
  });
  test('Every trail paints the complete world throughout a jump', () {
    for (final trail in [
      'none',
      'rainbow',
      'starlight',
      'bubble',
      'flame',
      'aurora',
      'hearts',
      'comet',
      'galaxy',
    ]) {
      final game = LeapGame();
      for (var frame = 0; frame < 90; frame++) {
        game.step(1 / 60, 0, 640);
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        expect(
          () => LeapWorldPainter(
            game,
            CatKind.lady,
            trail: trail,
          ).paint(canvas, const Size(360, 640)),
          returnsNormally,
          reason: '$trail frame $frame',
        );
        recorder.endRecording().dispose();
      }
    }
  });
}
