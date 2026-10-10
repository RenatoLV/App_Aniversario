import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nuestro_rincon/game_audio.dart';
import 'package:nuestro_rincon/marus_zombies/mz_painter.dart';
import 'package:nuestro_rincon/marus_zombies/mz_card_reveal.dart';
import 'package:nuestro_rincon/marus_zombies/mz_almanac.dart';
import 'package:nuestro_rincon/marus_zombies/mz_catalog.dart';
import 'package:nuestro_rincon/marus_zombies/mz_levels.dart';
import 'package:nuestro_rincon/marus_zombies/mz_progress.dart';
import 'package:nuestro_rincon/marus_zombies/mz_result.dart';
import 'package:nuestro_rincon/marus_zombies/mz_simulation.dart';

Future<(MzProgress, MzResultReceipt)> unlock(
  int before, {
  bool reduced = false,
}) async {
  SharedPreferences.setMockInitialValues({
    MzProgress.key: jsonEncode({
      'stars': {for (var i = 0; i < before; i++) '$i': 3},
      'reduced': reduced,
    }),
  });
  final p = MzProgress(await SharedPreferences.getInstance());
  final s = MzSimulation(MzLevel(before))..won = true;
  final r = MzResultReceipt(p, s);
  await p.complete(s);
  r.resolve(p, s);
  return (p, r);
}

void main() {
  setUpAll(() async {
    for (final name in ['Nunito', 'Fredoka']) {
      await (FontLoader(name)..addFont(
            Future.value(
              ByteData.sublistView(
                File('assets/fonts/$name.ttf').readAsBytesSync(),
              ),
            ),
          ))
          .load();
    }
    if (const bool.fromEnvironment('RENDER_MZ')) {
      await (FontLoader('MaterialIcons')..addFont(
            Future.value(
              ByteData.sublistView(
                File(
                  'C:/src/flutter/bin/cache/artifacts/material_fonts/materialicons-regular.otf',
                ).readAsBytesSync(),
              ),
            ),
          ))
          .load();
    }
  });
  test('victory track is bundled as an independent effect', () async {
    final bytes = await rootBundle.load(
      'assets/audio/${GameSfx.marusCardVictory.file}',
    );
    expect(bytes.lengthInBytes, 107181);
  });
  test(
    'all existing thresholds produce real new cards once; replay produces none',
    () async {
      for (final before in [0, 1, 2, 3, 4, 5, 9, 19, 29, 39]) {
        final (p, r) = await unlock(before);
        expect(
          r.newCards,
          mzUnlockedCats(
            before + 1,
          ).where((c) => !mzUnlockedCats(before).contains(c)).toList(),
        );
        expect(r.newCards, isNotEmpty);
        final s = MzSimulation(MzLevel(before))..won = true;
        final repeated = MzResultReceipt(p, s);
        await p.complete(s);
        repeated.resolve(p, s);
        expect(repeated.newCards, isEmpty);
      }
    },
  );
  for (final size in [
    const Size(960, 540),
    const Size(320, 640),
    const Size(844, 390),
  ]) {
    testWidgets('back, flip, discovery and expanded card at $size', (t) async {
      t.view.physicalSize = size;
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final (p, r) = await unlock(0);
      final saved = p.prefs.getString(MzProgress.key);
      var continued = false;
      MzCat? opened;
      await t.pumpWidget(
        MaterialApp(
          theme: ThemeData(fontFamily: 'Nunito'),
          home: RepaintBoundary(
            key: const ValueKey('capture'),
            child: Stack(
              fit: StackFit.expand,
              children: [
                CustomPaint(
                  painter: MzBoardPainter(
                    MzSimulation(const MzLevel(0))
                      ..place(MzCat.launcher, 2, 1)
                      ..won = true,
                  ),
                ),
                MzCardReveal(
                  receipt: r,
                  progress: p,
                  onContinue: () => continued = true,
                  onAlmanac: (c) => opened = c,
                ),
              ],
            ),
          ),
        ),
      );
      Future<void> capture(String stage) async {
        if (!const bool.fromEnvironment('RENDER_MZ')) return;
        await t.runAsync(() async {
          final im = await t
              .renderObject<RenderRepaintBoundary>(
                find.byKey(const ValueKey('capture')),
              )
              .toImage();
          final bytes = await im.toByteData(format: ui.ImageByteFormat.png);
          final f = File(
            'build/previews/mz-reveal-$stage-${size.width.toInt()}.png',
          )..parent.createSync(recursive: true);
          await f.writeAsBytes(bytes!.buffer.asUint8List());
          im.dispose();
        });
      }

      expect(find.byKey(const ValueKey('reveal-back')), findsOneWidget);
      expect(p.prefs.getStringList(MzAlmanacScreen.seenKey), isNull);
      await capture('back');
      await t.pump(const Duration(milliseconds: 420));
      await capture('flip');
      expect(p.prefs.getStringList(MzAlmanacScreen.seenKey), isNull);
      await t.pump(const Duration(milliseconds: 800));
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      await capture('front');
      expect(
        p.prefs.getStringList(MzAlmanacScreen.seenKey),
        contains('cat-sunflower'),
      );
      await t.tap(find.byKey(const ValueKey('reveal-card')));
      await t.pumpAndSettle();
      await capture('detail');
      expect(
        find.text('Atún premium: ${mzCats[MzCat.sunflower]!.tuna}'),
        findsOneWidget,
      );
      await t.tap(find.text('Ver en el almanaque'));
      expect(opened, MzCat.sunflower);
      await t.tap(find.text('Continuar'));
      expect(continued, true);
      expect(p.prefs.getString(MzProgress.key), saved);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    });
  }
  testWidgets(
    'skip before discovery does not acknowledge; reduced motion skips the flip',
    (t) async {
      final (p, r) = await unlock(0);
      await t.pumpWidget(
        MaterialApp(
          theme: ThemeData(fontFamily: 'Nunito'),
          home: MzCardReveal(
            receipt: r,
            progress: p,
            onContinue: () {},
            onAlmanac: (_) {},
          ),
        ),
      );
      await t.tap(find.text('Continuar'));
      expect(
        p.prefs.getStringList(MzAlmanacScreen.seenKey),
        isNot(contains('cat-sunflower')),
      );
      await t.pumpWidget(const SizedBox());
      final (reduced, receipt) = await unlock(0, reduced: true);
      await t.pumpWidget(
        MaterialApp(
          theme: ThemeData(fontFamily: 'Nunito'),
          home: MzCardReveal(
            receipt: receipt,
            progress: reduced,
            onContinue: () {},
            onAlmanac: (_) {},
          ),
        ),
      );
      await t.pump();
      expect(find.byKey(const ValueKey('reveal-front')), findsOneWidget);
      expect(find.byKey(const ValueKey('reveal-back')), findsNothing);
      expect(
        reduced.prefs.getStringList(MzAlmanacScreen.seenKey),
        contains('cat-sunflower'),
      );
      await t.pumpWidget(const SizedBox());
    },
  );
}
