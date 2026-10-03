import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nuestro_rincon/bloc_board.dart';
import 'package:nuestro_rincon/bloc_drawing.dart';
import 'package:nuestro_rincon/store.dart';

void main() {
  testWidgets(
    'Mobile board zoom, direct dragging, resizing and reversible deletion',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = GameStore(prefs);
      final n = PocketNote('Un recuerdo bonito', .06, .05);
      store.notes.add(n);
      final boundary = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: MaterialApp(
            home: Scaffold(
              body: BlocBoard(
                store: store,
                onAdd: () {},
                onDraw: () {},
                onPhoto: () {},
                onShare: () {},
                onEdit: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Un recuerdo bonito'));
      await tester.pump();
      final viewer = tester.widget<InteractiveViewer>(
        find.byKey(const ValueKey('bloc-viewer')),
      );
      final initialZoom = viewer.transformationController!.value
          .getMaxScaleOnAxis();
      await tester.tap(find.byTooltip('Acercar mural'));
      await tester.pump();
      expect(
        viewer.transformationController!.value.getMaxScaleOnAxis(),
        closeTo(initialZoom * 1.25, .01),
      );
      await tester.tap(find.text('Explorar'));
      await tester.pump();
      final before = n.x;
      await tester.drag(find.text('Un recuerdo bonito'), const Offset(45, 10));
      await tester.pump();
      expect(n.x, greaterThan(before));
      expect(
        find.byType(AnimatedPositioned),
        findsNothing,
        reason: 'No lagging animation on drag',
      );
      await tester.tap(find.byTooltip('Agrandar elemento'));
      await tester.pump();
      expect(n.scale, closeTo(1.1, .001));
      await tester.tap(find.byTooltip('Encuadrar notas'));
      await tester.pump();
      if (Platform.environment['CAPTURE_BLOC'] == '1') {
        await tester.runAsync(() async {
          final image =
              await (boundary.currentContext!.findRenderObject()
                      as RenderRepaintBoundary)
                  .toImage(pixelRatio: 2);
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          await File(
            'build/qa/bloc-mobile.png',
          ).writeAsBytes(data!.buffer.asUint8List());
          image.dispose();
        });
      }
      await tester.tap(find.byTooltip('Borrar elemento'));
      await tester.pumpAndSettle();
      expect(find.text('Un recuerdo bonito'), findsNothing);
      expect(GameStore(prefs).notes.single.deleted, isTrue);
      expect(viewer.transformationController!.value, Matrix4.identity());
      await tester.tap(find.text('Deshacer'));
      await tester.pump();
      expect(find.text('Un recuerdo bonito'), findsOneWidget);
      expect(GameStore(prefs).notes.single.deleted, isFalse);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('Eraser removes saved drawing pixels and undo restores them', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final base = ui.PictureRecorder();
      Canvas(base).drawColor(Colors.blue, BlendMode.src);
      final picture = base.endRecording();
      final image = await picture.toImage(100, 100);
      picture.dispose();
      Future<Uint8List> paint(List<BlocStroke> strokes) async {
        final recorder = ui.PictureRecorder();
        BlocDrawingPainter(
          strokes,
          initial: image,
        ).paint(Canvas(recorder), const Size(100, 100));
        final p = recorder.endRecording();
        final i = await p.toImage(100, 100);
        p.dispose();
        final bytes = await i.toByteData();
        i.dispose();
        return Uint8List.fromList(bytes!.buffer.asUint8List());
      }

      final clean = await paint([]);
      final erased = await paint([
        BlocStroke(Colors.black, 15, [
          const Offset(.2, .5),
          const Offset(.8, .5),
        ], erase: true),
      ]);
      final center = (50 * 100 + 50) * 4, corner = (10 * 100 + 10) * 4;
      expect(
        erased.sublist(center, center + 4),
        isNot(clean.sublist(center, center + 4)),
      );
      expect(
        erased.sublist(corner, corner + 4),
        clean.sublist(corner, corner + 4),
      );
      expect(await paint([]), clean);
      image.dispose();
    });
  });
  testWidgets('Two fingers zoom the mural and resize a selected note', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final store = GameStore(await SharedPreferences.getInstance());
    final note = PocketNote('Pellizca aquí', .05, .03);
    store.notes.add(note);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BlocBoard(
            store: store,
            onAdd: () {},
            onDraw: () {},
            onPhoto: () {},
            onShare: () {},
            onEdit: (_) {},
          ),
        ),
      ),
    );
    final board = tester.widget<InteractiveViewer>(
      find.byKey(const ValueKey('bloc-viewer')),
    );
    Future<void> pinch(Offset center) async {
      final a = await tester.startGesture(
        center - const Offset(30, 0),
        pointer: 1,
      );
      final b = await tester.startGesture(
        center + const Offset(30, 0),
        pointer: 2,
      );
      await tester.pump();
      for (var distance = 35.0; distance <= 70; distance += 5) {
        await a.moveTo(center - Offset(distance, 0));
        await b.moveTo(center + Offset(distance, 0));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await a.up();
      await b.up();
      await tester.pump();
    }

    await pinch(tester.getCenter(find.byKey(const ValueKey('bloc-viewer'))));
    expect(
      board.transformationController!.value.getMaxScaleOnAxis(),
      greaterThan(1.4),
    );
    board.transformationController!.value = Matrix4.identity();
    await tester.pump();
    await tester.tap(find.text('Explorar'));
    await tester.pump();
    await pinch(
      tester.getCenter(
        find.byKey(ValueKey('bloc-note-${identityHashCode(note)}')),
      ),
    );
    expect(note.scale, greaterThan(1.2));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    store.dispose();
  });
  testWidgets('Drawing tools fit a narrow phone and allow undo', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(home: BlocDrawingDialog()));
    final canvas = find.byWidgetPredicate(
      (w) => w is CustomPaint && w.painter is BlocDrawingPainter,
    );
    await tester.tap(canvas);
    await tester.pump();
    expect(
      (tester.widget<CustomPaint>(canvas).painter as BlocDrawingPainter)
          .strokes
          .single
          .points
          .length,
      1,
    );
    await tester.drag(
      find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is BlocDrawingPainter,
      ),
      const Offset(40, 20),
    );
    await tester.pump();
    expect(
      tester
          .widget<IconButton>(find.widgetWithIcon(IconButton, Icons.undo))
          .onPressed,
      isNotNull,
    );
    await tester.tap(find.byTooltip('Deshacer trazo'));
    await tester.pump();
    expect(
      tester
          .widget<IconButton>(find.widgetWithIcon(IconButton, Icons.redo))
          .onPressed,
      isNotNull,
    );
    expect(tester.takeException(), isNull);
  });
}
