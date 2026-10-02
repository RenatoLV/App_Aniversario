import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nuestro_rincon/home.dart';
import 'package:nuestro_rincon/store.dart';
import 'package:nuestro_rincon/cat_room.dart';
import 'package:nuestro_rincon/cat_character.dart';
import 'package:nuestro_rincon/cat_care_screen.dart';

Future<void> capture(WidgetTester tester, GlobalKey key, String name) async {
  if (Platform.environment['CAPTURE_CAT_CARE'] != '1') return;
  await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('build/qa/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(data!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    if (Platform.environment['CAPTURE_CAT_CARE'] != '1') return;
    final root = Platform.environment['FLUTTER_ROOT'] ?? 'C:/src/flutter';
    for (final entry in {
      'Roboto': 'roboto-regular.ttf',
      'MaterialIcons': 'materialicons-regular.otf',
    }.entries) {
      final loader = FontLoader(entry.key)
        ..addFont(
          Future.value(
            ByteData.sublistView(
              File(
                '$root/bin/cache/artifacts/material_fonts/${entry.value}',
              ).readAsBytesSync(),
            ),
          ),
        );
      await loader.load();
    }
  });
  testWidgets(
    'Double tapping the house opens care and clothes remain on return',
    (tester) async {
      tester.view.physicalSize = const Size(390, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      final store = GameStore(await SharedPreferences.getInstance());
      final boundary = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: RinconApp(store: store),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      final room = tester.getRect(find.byType(CatRoom));
      final position = room.topLeft + const Offset(25, 24);
      await tester.tapAt(position);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tapAt(position);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(CatCareScreen), findsOneWidget);
      await tester.tap(find.text('Ropa'));
      await tester.pump();
      final hat = find.byKey(const ValueKey('wear-beanie'));
      await Scrollable.ensureVisible(tester.element(hat), alignment: .7);
      await tester.pump();
      await tester.tap(hat);
      await tester.pump(const Duration(milliseconds: 100));
      expect(store.catCare.outfit(CatKind.maru).head, 'beanie');
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('wear-shirt_star')),
        160,
      );
      await tester.tap(find.byKey(const ValueKey('wear-shirt_star')));
      await tester.pump();
      final scroll = tester.state<ScrollableState>(
        find.byType(Scrollable).first,
      );
      scroll.position.jumpTo(0);
      await tester.pump(const Duration(milliseconds: 300));
      await capture(tester, boundary, 'cat-care-wardrobe');
      await tester.pageBack();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(CatRoom), findsOneWidget);
      expect(find.byType(CatCareScreen), findsNothing);
      expect(
        CatCareScope.outfitOf(
          tester.element(find.byType(CatRoom)),
          CatKind.maru,
        ).head,
        'beanie',
      );
      await capture(tester, boundary, 'cat-care-home');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'Food and bath work at narrow phone size and wardrobe is independent',
    (tester) async {
      tester.view.physicalSize = const Size(320, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      final store = GameStore(await SharedPreferences.getInstance());
      store.catCare.restore({
        'maru': {'food': 20, 'clean': 20, 'happy': 30},
      });
      final boundary = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: MaterialApp(home: CatCareScreen(store: store)),
        ),
      );
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('care-feed')),
        100,
      );
      await tester.tap(find.byKey(const ValueKey('care-feed')));
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      await tester.pump();
      expect(store.catCare.needs(CatKind.maru).food, 50);
      await tester.tap(find.text('Baño'));
      await tester.pump();
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('care-bathe')),
        100,
      );
      await tester.tap(find.byKey(const ValueKey('care-bathe')));
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      await tester.pump();
      expect(store.catCare.needs(CatKind.maru).clean, 100);
      await tester.tap(find.text('Ropa'));
      await tester.pump();
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('wear-collar_heart')),
        100,
      );
      await tester.tap(find.byKey(const ValueKey('wear-collar_heart')));
      await tester.pump();
      expect(store.catCare.outfit(CatKind.maru).neck, 'collar_heart');
      tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position
          .jumpTo(0);
      await tester.pump();
      await tester.tap(find.text('Lady').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(store.catCare.outfit(CatKind.lady).neck, isNull);
      await capture(tester, boundary, 'cat-care-small-phone');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('Double tap on a cat also opens its house menu', (tester) async {
    var opened = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: CatRoom(onOpenCare: () => opened++)),
      ),
    );
    await tester.pump();
    final cat = find.byType(CatActor).first;
    final position = tester.getCenter(cat);
    await tester.tapAt(position);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tapAt(position);
    await tester.pump(const Duration(milliseconds: 100));
    expect(opened, 1);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Dragging food and rubbing the cat perform care actions', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final store = GameStore(await SharedPreferences.getInstance());
    store.catCare.restore({
      'maru': {'food': 20, 'clean': 20},
    });
    await tester.pumpWidget(MaterialApp(home: CatCareScreen(store: store)));
    final fish = find.byWidgetPredicate(
      (w) => w is Draggable<CatFood> && w.data == CatFood.fish,
    );
    final target = find.byType(DragTarget<CatFood>);
    final finger = await tester.startGesture(tester.getCenter(fish));
    await finger.moveTo(tester.getCenter(target));
    await tester.pump();
    await finger.up();
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    expect(store.catCare.needs(CatKind.maru).food, 58);
    await tester.tap(find.text('Baño'));
    await tester.pump();
    final center = tester.getCenter(find.byType(CatActor));
    final rubbing = await tester.startGesture(center);
    for (var i = 0; i < 12; i++) {
      await rubbing.moveTo(center + Offset(i.isEven ? 70 : -70, 0));
      await tester.pump(const Duration(milliseconds: 30));
    }
    await rubbing.up();
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    expect(store.catCare.needs(CatKind.maru).clean, 100);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
