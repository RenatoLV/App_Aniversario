import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nuestro_rincon/cat_character.dart';
import 'package:nuestro_rincon/alien_cat.dart';

Future<Uint8List> pixels(CustomPainter painter) async {
  final recorder = ui.PictureRecorder();
  painter.paint(Canvas(recorder), const Size(120, 120));
  final picture = recorder.endRecording();
  final image = await picture.toImage(120, 120);
  final data = await image.toByteData();
  final bytes = Uint8List.fromList(data!.buffer.asUint8List());
  image.dispose();
  picture.dispose();
  return bytes;
}

void main() {
  testWidgets('All clothes paint on both cats, the alien and pack animations', (
    tester,
  ) async {
    final atlas = ui.PictureRecorder();
    final canvas = Canvas(atlas)
      ..drawColor(const Color(0xfffaf6ed), BlendMode.src);
    final outfits = [
      for (final item in catWardrobe)
        const CatOutfit().withItem(item.slot, item.id),
    ];
    for (var row = 0; row < outfits.length; row++) {
      final outfit = outfits[row];
      for (var col = 0; col < 4; col++) {
        CustomPainter painter(CatOutfit clothes) => switch (col) {
          0 => MaruPainter(outfit: clothes, phase: .35),
          1 => LadyPainter(outfit: clothes, phase: .65, joy: .25),
          2 => AlienCatPainter(cat: CatKind.maru, outfit: clothes, phase: .5),
          _ => PackOpeningCatPainter(
            cat: CatKind.lady,
            outfit: clothes,
            progress: .45,
          ),
        };
        final dressed = painter(outfit), plain = painter(const CatOutfit());
        expect(dressed.shouldRepaint(plain), isTrue);
        await tester.runAsync(() async {
          expect(
            listEquals(await pixels(dressed), await pixels(plain)),
            isFalse,
            reason: '${catWardrobe[row].id}, renderer=$col',
          );
        });
        canvas.save();
        canvas.translate(col * 170 + 10, row * 170 + 10);
        dressed.paint(canvas, const Size(150, 150));
        canvas.restore();
      }
    }
    final picture = atlas.endRecording();
    if (Platform.environment['CAPTURE_CAT_CARE'] == '1') {
      await tester.runAsync(() async {
        final image = await picture.toImage(680, outfits.length * 170);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File('build/qa/cat-clothing-atlas.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(data!.buffer.asUint8List());
        image.dispose();
      });
    }
    picture.dispose();
    if (Platform.environment['CAPTURE_CAT_CARE'] == '1') {
      for (final slot in ClothingSlot.values) {
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder)
          ..drawColor(const Color(0xfffaf6ed), BlendMode.src);
        final items = catWardrobe.where((item) => item.slot == slot).toList();
        for (var row = 0; row < items.length; row++) {
          final clothes = const CatOutfit().withItem(slot, items[row].id);
          for (var col = 0; col < 4; col++) {
            final CustomPainter painter = switch (col) {
              0 => MaruPainter(outfit: clothes),
              1 => LadyPainter(outfit: clothes),
              2 => AlienCatPainter(cat: CatKind.maru, outfit: clothes),
              _ => PackOpeningCatPainter(
                cat: CatKind.lady,
                outfit: clothes,
                progress: .45,
              ),
            };
            canvas.save();
            canvas.translate(col * 170 + 10, row * 155 + 5);
            painter.paint(canvas, const Size.square(145));
            canvas.restore();
          }
        }
        final picture = recorder.endRecording();
        await tester.runAsync(() async {
          final image = await picture.toImage(680, 1550);
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          await File(
            'build/qa/cat-clothing-${slot.name}.png',
          ).writeAsBytes(data!.buffer.asUint8List());
          image.dispose();
        });
        picture.dispose();
      }
    }
  });

  testWidgets(
    'Equipping clothes repaints shared CatActors without recreating them',
    (tester) async {
      final care = CatCare();
      final boundary = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          home: CatCareScope(
            care: care,
            child: RepaintBoundary(
              key: boundary,
              child: const Center(
                child: CatActor(
                  cat: CatKind.maru,
                  size: 120,
                  active: true,
                  showLabel: false,
                ),
              ),
            ),
          ),
        ),
      );
      Future<Uint8List> snapshot() async {
        final image =
            await (boundary.currentContext!.findRenderObject()
                    as RenderRepaintBoundary)
                .toImage();
        final data = await image.toByteData();
        final bytes = Uint8List.fromList(data!.buffer.asUint8List());
        image.dispose();
        return bytes;
      }

      final state = tester.state(find.byType(CatActor));
      final before = await tester.runAsync(snapshot);
      await care.equip(CatKind.maru, clothingById('beanie')!);
      await tester.pump();
      final after = await tester.runAsync(snapshot);
      expect(tester.state(find.byType(CatActor)), same(state));
      expect(listEquals(before, after), isFalse);
      await tester.pumpWidget(const SizedBox.shrink());
      care.dispose();
    },
  );
}
