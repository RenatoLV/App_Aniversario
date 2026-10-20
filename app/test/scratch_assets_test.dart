import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nuestro_rincon/lucky_palace/scratch/scratch_catalog.dart';
import 'package:nuestro_rincon/lucky_palace/scratch/scratch_ticket_widget.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'manifest anchors, five complete PNG compositions and transparent frame',
    () async {
      final manifest =
          jsonDecode(
                await rootBundle.loadString(
                  '$scratchAssetRoot/asset_manifest.json',
                ),
              )
              as Map;
      final anchors = manifest['anchors'] as Map;
      for (final entry in {
        'maru': ScratchTicketGeometry.maru,
        'lady': ScratchTicketGeometry.lady,
        'scratchArea': ScratchTicketGeometry.area,
        'title': ScratchTicketGeometry.title,
        'caption': ScratchTicketGeometry.caption,
      }.entries) {
        expect(anchors[entry.key]['rect'], [
          entry.value.left,
          entry.value.top,
          entry.value.width,
          entry.value.height,
        ]);
      }
      expect(
        (manifest['themes'] as Map).keys,
        orderedEquals(ScratchTheme.all.map((t) => t.id)),
      );
      for (final theme in ScratchTheme.all) {
        final images = await ScratchImages.load(theme);
        try {
          for (final entry in images.layers.entries) {
            final full = entry.key == 'background' || entry.key == 'frame';
            expect(entry.value.width, full ? 640 : 486);
            expect(entry.value.height, full ? 960 : 342);
          }
          final frame = (await images.layers['frame']!.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          ))!;
          // Supplied art has a 40% inner shadow; the runtime clips its board opening.
          expect(frame.getUint8((591 * 640 + 320) * 4 + 3), 102);
          for (final symbol in images.symbols.values) {
            expect(symbol.width, 256);
            expect(symbol.height, 256);
          }
        } finally {
          images.dispose();
        }
      }
    },
  );
  test(
    'all provided symbol images and editable SVG sources remain available',
    () async {
      final manifest =
          jsonDecode(
                await rootBundle.loadString(
                  '$scratchAssetRoot/asset_manifest.json',
                ),
              )
              as Map;
      for (final id in manifest['symbolIds'] as List) {
        expect(
          (await rootBundle.load(
            '$scratchAssetRoot/symbols/png/${id}_128.png',
          )).lengthInBytes,
          greaterThan(0),
        );
        // SVGs are source files, deliberately not loaded by Flutter rendering.
        expect(File('$scratchAssetRoot/symbols/svg/$id.svg').existsSync(), true);
      }
    },
  );
}
