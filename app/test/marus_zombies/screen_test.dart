import 'dart:io';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nuestro_rincon/store.dart';
import 'package:nuestro_rincon/marus_zombies/mz_catalog.dart';
import 'package:nuestro_rincon/marus_zombies/mz_levels.dart';
import 'package:nuestro_rincon/marus_zombies/mz_models.dart';
import 'package:nuestro_rincon/marus_zombies/mz_painter.dart';
import 'package:nuestro_rincon/marus_zombies/mz_progress.dart';
import 'package:nuestro_rincon/marus_zombies/mz_simulation.dart';
import 'package:nuestro_rincon/marus_zombies/mz_screen.dart';
import 'package:nuestro_rincon/marus_zombies/mz_game_screen.dart';
import 'package:nuestro_rincon/marus_zombies/mz_widgets.dart';
import 'package:nuestro_rincon/marus_zombies/mz_scenery.dart';
import 'package:nuestro_rincon/marus_zombies/mz_character_art.dart';
import 'package:nuestro_rincon/marus_zombies/mz_visual_feedback.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    if (!const bool.fromEnvironment('RENDER_MZ')) return;
    for (final entry in {
      'Roboto': 'roboto-regular.ttf',
      'MaterialIcons': 'materialicons-regular.otf',
    }.entries) {
      await (FontLoader(entry.key)..addFont(
            Future.value(
              ByteData.sublistView(
                File(
                  'C:/src/flutter/bin/cache/artifacts/material_fonts/${entry.value}',
                ).readAsBytesSync(),
              ),
            ),
          ))
          .load();
    }
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
  });
  Future<void> capture(WidgetTester tester, String name) async {
    if (!const bool.fromEnvironment('RENDER_MZ')) return;
    await tester.runAsync(() async {
      final image = await tester
          .renderObject<RenderRepaintBoundary>(
            find.byKey(const ValueKey('mz-preview')),
          )
          .toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('build/previews/mz-$name.png')
        ..parent.createSync(recursive: true);
      file.writeAsBytesSync(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  testWidgets('real combat effects render before, during and after an attack', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(960, 540);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final s = MzSimulation(const MzLevel(8));
    final art = MzVisualFeedback(), cache = MzSceneryCache();
    final cats = [
      MzCat.launcher,
      MzCat.ice,
      MzCat.boomerang,
      MzCat.lightning,
      MzCat.laser,
    ];
    for (var row = 0; row < 5; row++) {
      s.defenders.add(MzDefender(100 + row, cats[row], row, 1));
      s.spawn(
        row == 1 ? MzEnemy.bucket : MzEnemy.common,
        row,
        x: 3.3 + row * .3,
      );
    }
    s.defenders.addAll([
      MzDefender(110, MzCat.sunflower, 0, 0),
      MzDefender(111, MzCat.barrier, 1, 3),
      MzDefender(112, MzCat.bomb, 2, 4),
      MzDefender(113, MzCat.spring, 3, 3),
      MzDefender(114, MzCat.catapult, 4, 0),
    ]);
    s.spawn(MzEnemy.boss, 2, x: 8.1);
    art.observe(s);
    for (var frame = 0; frame <= 70; frame++) {
      s.advance(1 / 60);
      art.observe(s);
      if (![17, 27, 50, 69].contains(frame)) continue;
      final name = frame == 17
          ? 'anticipation'
          : frame == 27
          ? 'fire'
          : frame == 50
          ? 'impact'
          : 'recovery';
      final before = s.toJson();
      await tester.pumpWidget(
        RepaintBoundary(
          key: const ValueKey('mz-preview'),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: CustomPaint(
              painter: MzBoardPainter(s, scenery: cache, visuals: art),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(s.toJson(), before);
      expect(tester.takeException(), isNull);
      await capture(tester, 'combat-$name');
    }
    await tester.pumpWidget(
      RepaintBoundary(
        key: const ValueKey('mz-preview'),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: CustomPaint(
            painter: MzBoardPainter(
              s,
              scenery: cache,
              visuals: art,
              reducedMotion: true,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await capture(tester, 'combat-reduced');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    cache.dispose();
  });

  for (final size in [
    const Size(320, 568),
    const Size(390, 844),
    const Size(844, 390),
    const Size(1280, 800),
    const Size(1366, 768),
    const Size(1920, 1080),
  ]) {
    testWidgets('battle fits $size and supports planting and pausing', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      final p = MzProgress(await SharedPreferences.getInstance());
      final s = MzSimulation(
        const MzLevel(8),
        deck: [
          MzCat.launcher,
          MzCat.sunflower,
          MzCat.barrier,
          MzCat.ice,
          MzCat.mine,
          MzCat.bomb,
        ],
      )..catnip = 250;
      s.defenders.addAll([
        MzDefender(100, MzCat.sunflower, 0, 0),
        MzDefender(101, MzCat.ice, 3, 1),
        MzDefender(102, MzCat.barrier, 4, 4),
      ]);
      s.spawn(MzEnemy.cone, 0, x: 7);
      s.spawn(MzEnemy.bucket, 4, x: 7.3);
      s.spawn(MzEnemy.common, 3, x: 5.5);
      await tester.pumpWidget(
        RepaintBoundary(
          key: const ValueKey('mz-preview'),
          child: MaterialApp(
            home: MzGameScreen(sim: s, progress: p),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const ValueKey('mz-card-launcher')));
      await tester.pump();
      final board = find.byKey(const ValueKey('mz-board'));
      final geometry = MzBoardGeometry(tester.getSize(board));
      await tester.tapAt(tester.getTopLeft(board) + geometry.point(2, 1.5));
      await tester.pump();
      if (size.width < 600) {
        await tester.tap(find.text('Colocar'));
        await tester.pump();
      }
      expect(s.at(2, 1)?.kind, MzCat.launcher);
      await capture(tester, 'battle-${size.width.toInt()}');
      await tester.tap(find.byTooltip('Pausar'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      final before = s.time;
      await tester.pump(const Duration(seconds: 1));
      expect(s.time, before);
      expect(find.text('Continuar'), findsOneWidget);
      expect(p.resume(), isNotNull);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
  testWidgets(
    'drag ghost snaps into the correct cell and x2 doubles game time',
    (tester) async {
      tester.view.physicalSize = const Size(960, 540);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      final p = MzProgress(await SharedPreferences.getInstance()),
          s = MzSimulation(const MzLevel(0));
      await tester.pumpWidget(
        MaterialApp(
          home: MzGameScreen(sim: s, progress: p),
        ),
      );
      await tester.pump();
      final board = find.byKey(const ValueKey('mz-board'));
      final box = tester.getRect(board);
      expect(box.left, greaterThanOrEqualTo(44));
      expect(box.right, lessThanOrEqualTo(916));
      final geom = MzBoardGeometry(tester.getSize(board));
      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(const ValueKey('mz-card-launcher'))),
      );
      await gesture.moveTo(tester.getTopLeft(board) + geom.point(2, 2.5));
      await tester.pump(const Duration(milliseconds: 16));
      await gesture.up();
      await tester.pump();
      expect(s.at(2, 2)?.kind, MzCat.launcher);
      expect(s.catnip, 100);
      final pauseBox = tester.getSize(find.byTooltip('Pausar'));
      expect(pauseBox.width, greaterThanOrEqualTo(48));
      expect(pauseBox.height, greaterThanOrEqualTo(48));
      final start = s.time;
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      final normal = s.time - start;
      await tester.tap(find.byKey(const ValueKey('mz-speed')));
      await tester.pump();
      final fastStart = s.time;
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(s.time - fastStart, closeTo(normal * 2, .035));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  for (final size in [
    const Size(320, 568),
    const Size(390, 844),
    const Size(844, 390),
    const Size(1280, 800),
    const Size(1366, 768),
    const Size(1920, 1080),
    const Size(800, 600),
  ]) {
    testWidgets('map and preparation fit $size and route into battle', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      final store = GameStore(await SharedPreferences.getInstance());
      await tester.pumpWidget(
        RepaintBoundary(
          key: const ValueKey('mz-preview'),
          child: MaterialApp(home: MarusZombiesScreen(store: store)),
        ),
      );
      await tester.pumpAndSettle();
      await capture(
        tester,
        size.width == 800 ? 'map' : 'map-${size.width.toInt()}',
      );
      expect(find.text('Marus vs Zombies'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('mz-level-0')),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('mz-level-0')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('mz-level-0')));
      await tester.pumpAndSettle();
      expect(find.text('¡Defender el jardín!'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('mz-deck-launcher')));
      await tester.pumpAndSettle();
      expect(find.text('Tu equipo · 0/6'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, '¡Defender el jardín!'),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(find.byKey(const ValueKey('mz-deck-launcher')));
      await tester.pumpAndSettle();
      expect(find.text('Tu equipo · 1/6'), findsOneWidget);
      await capture(
        tester,
        size.width == 800 ? 'preparation' : 'preparation-${size.width.toInt()}',
      );
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('¡Defender el jardín!'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.byKey(const ValueKey('mz-board')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      store.dispose();
    });
  }
  testWidgets(
    'illustrated tools feed, remove and buy with the existing economy',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({
        MzProgress.key: jsonEncode({'cookies': 500}),
      });
      final p = MzProgress(await SharedPreferences.getInstance());
      final s = MzSimulation(const MzLevel(8))..tuna = 1;
      s.spawn(MzEnemy.bucket, 2, x: 7);
      await tester.pumpWidget(
        MaterialApp(
          home: MzGameScreen(sim: s, progress: p),
        ),
      );
      await tester.pump();
      final board = find.byKey(const ValueKey('mz-board'));
      final cell =
          tester.getTopLeft(board) +
          MzBoardGeometry(tester.getSize(board)).point(2, 2.5);
      await tester.tap(find.byKey(const ValueKey('mz-card-launcher')));
      await tester.tapAt(cell);
      await tester.pump();
      await tester.tap(find.byTooltip('Atún 1/3'));
      await tester.tapAt(cell);
      await tester.pump();
      expect(s.tuna, 0);
      expect(s.at(2, 2)!.burstLeft, greaterThan(0));
      await tester.tap(find.byTooltip('Pala'));
      await tester.tapAt(cell);
      await tester.pump();
      expect(s.at(2, 2), isNull);
      await tester.tap(find.byTooltip('Poderes'));
      await tester.pump();
      final purchase = find.byTooltip('Atún +1 · 75');
      await tester.ensureVisible(purchase);
      await tester.tap(purchase);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(s.tuna, 1);
      expect(p.cookies, 425);
      expect(p.resume()!.tuna, 1);
      final button = tester.widget<MzActionButton>(
        find
            .ancestor(of: purchase, matching: find.byType(MzActionButton))
            .first,
      );
      expect(button.onTap, isNull); // One purchase per run, as before.
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  for (final world in MzWorld.values) {
    testWidgets(
      'art and cached terrain render ${world.name} including outer cells',
      (tester) async {
        tester.view.physicalSize = const Size(960, 540);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final s = MzSimulation(MzLevel(world.index * 10 + 9));
        s.defenders.addAll([
          MzDefender(100, MzCat.sunflower, 0, 0),
          MzDefender(101, MzCat.mine, 4, 8)..age = 9,
          MzDefender(102, MzCat.boomerang, 2, 3),
        ]);
        s.spawn(s.level.enemies.last, 2, x: 7.5);
        final cache = MzSceneryCache();
        await tester.pumpWidget(
          RepaintBoundary(
            key: const ValueKey('mz-preview'),
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: CustomPaint(painter: MzBoardPainter(s, scenery: cache)),
            ),
          ),
        );
        await tester.pump();
        await capture(tester, 'world-${world.name}');
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        cache.dispose();
      },
    );
  }

  testWidgets('all unit artwork renders at battlefield and seed sizes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      RepaintBoundary(
        key: const ValueKey('mz-preview'),
        child: const Directionality(
          textDirection: TextDirection.ltr,
          child: CustomPaint(painter: _ArtReview()),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    await capture(tester, 'units');
    await tester.pumpWidget(const SizedBox());
  });
}

class _ArtReview extends CustomPainter {
  const _ArtReview();
  @override
  void paint(Canvas c, Size size) {
    c.drawRect(Offset.zero & size, Paint()..color = const Color(0xfffff3d5));
    final units = MzCat.values.length + MzEnemy.values.length;
    for (var i = 0; i < units; i++) {
      final row = i ~/ 7, col = i % 7;
      final x = col * 200.0 + 100, y = row * 225.0 + 143;
      final cat = i < MzCat.values.length ? MzCat.values[i] : null;
      final enemy = cat == null
          ? MzEnemy.values[i - MzCat.values.length]
          : null;
      c.drawOval(
        Rect.fromCenter(center: Offset(x, y + 25), width: 180, height: 64),
        Paint()..color = const Color(0xffa6c578),
      );
      mzDrawCat(
        c,
        Offset(x, y),
        120,
        cat: cat,
        enemy: enemy,
        armor: cat == null,
        armed: true,
      );
      mzDrawCat(
        c,
        Offset(x - 70, y + 48),
        32,
        cat: cat,
        enemy: enemy,
        armor: true,
        armed: true,
      );
      mzText(
        c,
        cat != null ? mzCats[cat]!.name : enemy!.label,
        Offset(x, y + 69),
        13,
        const Color(0xff30382f),
      );
    }
    c.drawOval(
      const Rect.fromLTWH(1010, 811, 180, 64),
      Paint()..color = const Color(0xffa6c578),
    );
    mzPaintAncestral(c, const Offset(1100, 818), 120, 1);
    mzText(
      c,
      'Gran León · Maru',
      const Offset(1100, 887),
      13,
      const Color(0xff30382f),
    );
  }

  @override
  bool shouldRepaint(_ArtReview oldDelegate) => false;
}
