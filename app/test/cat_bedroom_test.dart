import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nuestro_rincon/cat_character.dart';
import 'package:nuestro_rincon/cat_care_screen.dart';
import 'package:nuestro_rincon/cat_care_art.dart';
import 'package:nuestro_rincon/care_space_art.dart';
import 'package:nuestro_rincon/store.dart';

void main() {
  testWidgets('Food can be dragged back to the cat on a small phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final store = GameStore(await SharedPreferences.getInstance());
    store.catCare.restore({
      'maru': {'food': 20},
    });
    await tester.pumpWidget(MaterialApp(home: CatCareScreen(store: store)));
    final fridge = find.byKey(const ValueKey('care-fridge'));
    await Scrollable.ensureVisible(tester.element(fridge));
    await tester.pump();
    await tester.tap(fridge);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    final food = find.byKey(const ValueKey('food-fish'));
    await Scrollable.ensureVisible(tester.element(food));
    await tester.pump();
    final finger = await tester.startGesture(tester.getCenter(food));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 240));
    final target = find.byType(DragTarget<CatFood>);
    final position = tester.getCenter(target);
    expect(position.dy, inInclusiveRange(165, 530));
    await finger.moveTo(position);
    await tester.pump();
    await finger.up();
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    expect(store.catCare.needs(CatKind.maru).food, 58);
    expect(store.catCare.stock(CatFood.fish), 0);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('Each cat can decorate its bedroom on a narrow phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final store = GameStore(prefs)..cards[6] = 1;
    await tester.pumpWidget(
      MaterialApp(
        home: CatCareScreen(
          store: store,
          clock: () => DateTime(2026, 10, 5, 22),
        ),
      ),
    );
    Future<void> choose(Finder control) async {
      await Scrollable.ensureVisible(tester.element(control), alignment: .7);
      await tester.pump();
      await tester.tap(control);
      await tester.pump();
    }

    await tester.tap(find.byKey(const ValueKey('care-room-bedroom')));
    await tester.pump();
    await choose(find.byKey(const ValueKey('room-sunset')));
    await choose(find.byKey(const ValueKey('room-star')));
    await choose(find.byKey(const ValueKey('room-poster-6')));
    expect(store.catCare.bedroom(CatKind.maru).poster, 6);
    expect(find.byKey(const ValueKey('room-poster-13')), findsNothing);
    await choose(find.text('Lady'));
    expect(store.catCare.bedroom(CatKind.lady).palette, 'rose');
    await choose(find.byKey(const ValueKey('room-lavender')));
    await choose(find.text('Maru'));
    expect(store.catCare.bedroom(CatKind.maru).palette, 'sunset');
    expect(store.catCare.bedroom(CatKind.maru).bed, 'star');
    expect(GameStore(prefs).catCare.bedroom(CatKind.lady).palette, 'lavender');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'Fridge and clothing transitions complete without resetting the outfit',
    (tester) async {
      tester.view.physicalSize = const Size(390, 850);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      final store = GameStore(await SharedPreferences.getInstance());
      await store.catCare.unlockClothing(clothingById('beanie')!);
      await tester.pumpWidget(MaterialApp(home: CatCareScreen(store: store)));
      final fridge = find.byKey(const ValueKey('care-fridge'));
      await Scrollable.ensureVisible(tester.element(fridge));
      await tester.pump();
      await tester.tap(fridge);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 240));
      FridgePainter fridgePaint() => tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .map((w) => w.painter)
          .whereType<FridgePainter>()
          .single;
      expect(fridgePaint().open, inExclusiveRange(0, 1));
      await tester.pump(const Duration(milliseconds: 260));
      expect(fridgePaint().open, 1);
      await tester.tap(find.byKey(const ValueKey('care-room-wardrobe')));
      await tester.pump();
      final hat = find.byKey(const ValueKey('wear-beanie'));
      await Scrollable.ensureVisible(tester.element(hat));
      await tester.pump();
      await tester.tap(hat);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(
        tester
            .widgetList<CustomPaint>(find.byType(CustomPaint))
            .any((w) => w.painter is DressingSparklesPainter),
        isTrue,
      );
      await tester.pump(const Duration(milliseconds: 500));
      expect(store.catCare.outfit(CatKind.maru).head, 'beanie');
      expect(
        tester.widget<CatActor>(find.byType(CatActor)).outfit?.head,
        'beanie',
      );
      expect(store.catCare.outfit(CatKind.lady).head, isNull);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
