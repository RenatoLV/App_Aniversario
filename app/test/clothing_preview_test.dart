import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nuestro_rincon/cat_care_screen.dart';
import 'package:nuestro_rincon/cat_character.dart';
import 'package:nuestro_rincon/store.dart';

void main() {
  testWidgets(
    'Trying clothes on either cat never spends, unlocks or persists them',
    (tester) async {
      tester.view.physicalSize = const Size(320, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = GameStore(prefs)..coins = 350;
      await store.catCare.equip(CatKind.maru, clothingById('beanie')!);
      await store.save();
      final before = store.catCare.toJson();
      await tester.pumpWidget(
        MaterialApp(
          home: CatCareScreen(
            store: store,
            clock: () => DateTime(2026, 10, 3, 23),
          ),
        ),
      );
      await tester.tap(find.text('Ropa'));
      await tester.pump();
      final garment = find.byKey(const ValueKey('wear-collar_bell'));
      await Scrollable.ensureVisible(tester.element(garment), alignment: .7);
      await tester.pump();
      await tester.tap(garment);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.byKey(const ValueKey('clothing-try')));
      await tester.pump(const Duration(milliseconds: 300));
      final preview = find.byKey(const ValueKey('clothing-preview-cat'));
      expect(tester.widget<CatActor>(preview).outfit!.neck, 'collar_bell');
      expect(tester.widget<CatActor>(preview).outfit!.head, 'beanie');
      await tester.tap(find.text('Lady').last);
      await tester.pump();
      expect(tester.widget<CatActor>(preview).cat, CatKind.lady);
      expect(tester.widget<CatActor>(preview).outfit!.neck, 'collar_bell');
      expect(store.coins, 350);
      expect(store.catCare.toJson(), before);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Cancelar'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const ValueKey('clothing-preview-cat')), findsNothing);
      final restored = GameStore(prefs);
      expect(restored.coins, 350);
      expect(restored.catCare.toJson(), before);
      await tester.tap(garment);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.byKey(const ValueKey('clothing-try')));
      await tester.pump();
      await tester.tap(find.text('Comprar'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(store.coins, 250);
      expect(store.catCare.ownsClothing(clothingById('collar_bell')!), isTrue);
      expect(store.catCare.outfit(CatKind.maru).neck, 'collar_bell');
      expect(store.catCare.outfit(CatKind.maru).head, 'beanie');
      expect(store.catCare.outfit(CatKind.lady).neck, isNull);
      expect(GameStore(prefs).coins, 250);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
