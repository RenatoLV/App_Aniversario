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
import 'package:nuestro_rincon/cat_care_art.dart';

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

Future<void> rub(WidgetTester tester, {int moves = 12}) async {
  final pelage = find.byKey(const ValueKey('care-pelaje'));
  await Scrollable.ensureVisible(tester.element(pelage), alignment: .25);
  await tester.pump();
  final center = tester.getCenter(pelage);
  final scene = tester
      .widgetList<CustomPaint>(find.byType(CustomPaint))
      .map((w) => w.painter)
      .whereType<BathScenePainter>()
      .single;
  final source = scene.tool == BathTool.shower
      ? center - Offset(0, tester.getSize(pelage).height * .32)
      : center;
  final finger = await tester.startGesture(source);
  for (var i = 0; i < moves; i++) {
    await finger.moveTo(source + Offset(i.isEven ? 60 : -60, 0));
    await tester.pump(const Duration(milliseconds: 30));
  }
  if (scene.tool == BathTool.shower && moves >= 12) {
    for (var i = 0; i < 40; i++) {
      await finger.moveTo(source + Offset(-60 + 120 * (i % 20) / 19, 0));
      await tester.pump(const Duration(milliseconds: 100));
    }
  }
  await finger.up();
  await tester.pump();
}

Future<void> chooseShower(WidgetTester tester) async {
  final tool = find.byKey(const ValueKey('bath-shower'));
  await Scrollable.ensureVisible(tester.element(tool), alignment: .8);
  await tester.pump();
  await tester.tap(tool);
  await tester.pump();
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
      store.coins = 1000;
      await tester.tap(find.byKey(const ValueKey('wear-shirt_star')));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Comprar'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(store.coins, 850);
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
      await tester.pump(const Duration(milliseconds: 700));
      final eating = tester.widget<CatActor>(find.byType(CatActor));
      expect(
        eating.feeding,
        isFalse,
        reason: 'Meal scenes must not draw the legacy churú',
      );
      expect(eating.mealProgress, closeTo(.25, .02));
      await capture(tester, boundary, 'cat-care-eating');
      await tester.pump(const Duration(seconds: 3));
      await tester.pump();
      expect(store.catCare.needs(CatKind.maru).food, 50);
      await tester.tap(find.text('Baño'));
      await tester.pump();
      expect(find.text('Dar un baño'), findsNothing);
      await rub(tester);
      expect(store.catCare.needs(CatKind.maru).clean, 20);
      await chooseShower(tester);
      await rub(tester);
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
    final fridge = find.byKey(const ValueKey('care-fridge'));
    await Scrollable.ensureVisible(tester.element(fridge), alignment: .7);
    await tester.pump();
    await tester.tap(fridge);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    final fish = find.byWidgetPredicate(
      (w) => w is Draggable<CatFood> && w.data == CatFood.fish,
    );
    final target = find.byType(DragTarget<CatFood>);
    // Tall viewport keeps the fridge's first shelf and cat visible together.
    final finger = await tester.startGesture(tester.getCenter(fish));
    await finger.moveTo(tester.getCenter(target));
    await tester.pump();
    await finger.up();
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    await tester.pump();
    expect(store.catCare.needs(CatKind.maru).food, 58);
    await tester.tap(find.text('Baño'));
    await tester.pump();
    await rub(tester);
    expect(store.catCare.needs(CatKind.maru).clean, 20);
    await chooseShower(tester);
    await rub(tester);
    await tester.pump();
    expect(store.catCare.needs(CatKind.maru).clean, 100);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'Fridge, dirty fur, soap and progressive rinsing stay usable on a phone',
    (tester) async {
      tester.view.physicalSize = const Size(390, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      final store = GameStore(await SharedPreferences.getInstance());
      store.catCare.restore({
        'maru': {'food': 15, 'clean': 35, 'happy': 41},
      });
      await store.catCare.unlockClothing(clothingById('explorer')!);
      await store.catCare.equip(CatKind.maru, clothingById('explorer')!);
      await store.catCare.equip(CatKind.maru, clothingById('shirt_stripes')!);
      final boundary = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xff31594c),
              ),
            ),
            home: CatCareScreen(store: store),
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('care-fridge')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(Draggable<CatFood>), findsNWidgets(10));
      tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position
          .jumpTo(240);
      await tester.pump();
      await capture(tester, boundary, 'cat-care-fridge');
      tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position
          .jumpTo(0);
      await tester.pump();
      await tester.tap(find.text('Baño'));
      await tester.pump();
      await chooseShower(tester);
      await rub(tester);
      expect(store.catCare.needs(CatKind.maru).clean, 35);
      final soap = find.byKey(const ValueKey('bath-soap'));
      await Scrollable.ensureVisible(tester.element(soap), alignment: .8);
      await tester.pump();
      await tester.tap(soap);
      await tester.pump();
      await rub(tester);
      expect(store.catCare.needs(CatKind.maru).clean, 35);
      await capture(tester, boundary, 'cat-care-soap');
      await chooseShower(tester);
      await rub(tester, moves: 3);
      final actor = tester.widget<CatActor>(find.byType(CatActor));
      expect(actor.cleanliness, greaterThan(35));
      expect(actor.cleanliness, lessThan(100));
      expect(store.catCare.needs(CatKind.maru).clean, 35);
      await capture(tester, boundary, 'cat-care-rinse');
      final fur = find.byKey(const ValueKey('care-pelaje'));
      final center =
          tester.getCenter(fur) - Offset(0, tester.getSize(fur).height * .32);
      final showerFinger = await tester.startGesture(center);
      await showerFinger.moveTo(center + const Offset(24, 0));
      // Water keeps rinsing while the shower is held still, without rubbing.
      for (var i = 0; i < 40; i++) {
        await showerFinger.moveTo(
          center + Offset(-60 + 120 * (i % 20) / 19, 0),
        );
        await tester.pump(const Duration(milliseconds: 100));
        if (i == 5) await capture(tester, boundary, 'cat-care-shower-running');
      }
      await showerFinger.up();
      await tester.pump();
      expect(store.catCare.needs(CatKind.maru).clean, 100);
      await capture(tester, boundary, 'cat-care-washed');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
