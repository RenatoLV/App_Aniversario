import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nuestro_rincon/cat_character.dart';
import 'package:nuestro_rincon/alien_cat.dart';
import 'package:nuestro_rincon/cat_care_art.dart';

Future<Uint8List> raster(CustomPainter painter) async {
  final recorder = ui.PictureRecorder();
  painter.paint(Canvas(recorder), const Size.square(120));
  final picture = recorder.endRecording();
  final image = await picture.toImage(120, 120);
  final data = await image.toByteData();
  final bytes = Uint8List.fromList(data!.buffer.asUint8List());
  image.dispose();
  picture.dispose();
  return bytes;
}

void main() {
  testWidgets(
    'Every meal has a different illustration and animated eating scene',
    (tester) async {
      final icons = <Uint8List>[], scenes = <Uint8List>[];
      final recorder = ui.PictureRecorder();
      final board = Canvas(recorder)
        ..drawColor(const Color(0xfffaf6ed), BlendMode.src);
      for (var i = 0; i < CatFood.values.length; i++) {
        final food = CatFood.values[i];
        await tester.runAsync(() async {
          final icon = await raster(FoodPainter(food));
          final scene = await raster(
            FeedingScenePainter(food: food, phase: .35),
          );
          for (final previous in icons) {
            expect(listEquals(icon, previous), isFalse, reason: food.name);
          }
          for (final previous in scenes) {
            expect(listEquals(scene, previous), isFalse, reason: food.name);
          }
          expect(
            listEquals(
              scene,
              await raster(FeedingScenePainter(food: food, phase: .7)),
            ),
            isFalse,
            reason: food.name,
          );
          icons.add(icon);
          scenes.add(scene);
        });
        for (var col = 0; col < 4; col++) {
          board.save();
          board.translate(col * 160 + 5, i * 155 + 5);
          if (col == 0) {
            FoodPainter(food).paint(board, const Size.square(135));
          } else {
            const MaruPainter().paint(board, const Size.square(145));
            FeedingScenePainter(
              food: food,
              phase: [.2, .4, .65][col - 1],
            ).paint(board, const Size.square(145));
          }
          board.restore();
        }
      }
      final picture = recorder.endRecording();
      if (Platform.environment['CAPTURE_CAT_CARE'] == '1') {
        await tester.runAsync(() async {
          final image = await picture.toImage(640, 1550);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final file = File('build/qa/cat-food-scenes.png');
          await file.parent.create(recursive: true);
          await file.writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
      picture.dispose();
    },
  );

  testWidgets('Dirt increases as cleanliness falls in every cat renderer', (
    tester,
  ) async {
    for (var type = 0; type < 4; type++) {
      CustomPainter painter(double clean) => switch (type) {
        0 => MaruPainter(cleanliness: clean),
        1 => LadyPainter(cleanliness: clean),
        2 => AlienCatPainter(cat: CatKind.maru, cleanliness: clean),
        _ => PackOpeningCatPainter(
          cat: CatKind.lady,
          progress: .2,
          cleanliness: clean,
        ),
      };
      final clean = painter(100), dirty = painter(35), muddy = painter(15);
      expect(dirty.shouldRepaint(clean), isTrue);
      await tester.runAsync(() async {
        expect(listEquals(await raster(clean), await raster(dirty)), isFalse);
        expect(listEquals(await raster(dirty), await raster(muddy)), isFalse);
      });
    }
  });
}
