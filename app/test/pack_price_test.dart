import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nuestro_rincon/store.dart';
import 'package:nuestro_rincon/cat_character.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'Pack price advances by five across volumes, persists, caps and resets daily',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final today = DateTime(2026, 10, 6, 23, 59),
          tomorrow = DateTime(2026, 10, 7);
      var store = GameStore(prefs)..coins = 10;
      expect(store.openPack(opener: CatKind.maru, now: today), isNull);
      expect(store.packPriceAt(today), 20);
      store.coins = 2000;
      for (var i = 0; i < 14; i++) {
        final price = (20 + i * 5).clamp(20, 70);
        expect(store.packPriceAt(today), price);
        final before = store.coins;
        expect(
          store.openPack(
            opener: CatKind.maru,
            now: today,
            collectionId: i.isEven
                ? anniversaryCollectionId
                : anniversaryCollectionV2Id,
          ),
          isNotNull,
        );
        expect(store.coins, before - price);
        await store.save();
        store.dispose();
        store = GameStore(prefs);
      }
      expect(store.packPriceAt(today), 70);
      expect(store.packPriceAt(tomorrow), 20);
      store.openPack(opener: CatKind.lady, now: tomorrow);
      expect(store.packPriceAt(tomorrow), 25);
      store.coins = 24;
      expect(store.openPack(opener: CatKind.maru, now: tomorrow), isNull);
      expect(store.packPriceAt(tomorrow), 25);
      await store.save();
      store.dispose();
    },
  );
  test('Older saves retain their used first pack when migrating', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final original = GameStore(prefs)..coins = 50;
    original.openPack(opener: CatKind.maru, now: DateTime(2026, 10, 6));
    await original.save();
    original.dispose();
    final legacy =
        jsonDecode(prefs.getString('rincon.v1')!) as Map<String, dynamic>;
    legacy.remove('dailyPacksOpened');
    await prefs.setString('rincon.v1', jsonEncode(legacy));
    final store = GameStore(prefs);
    expect(store.packPriceAt(DateTime(2026, 10, 6)), 25);
    expect(store.packPriceAt(DateTime(2026, 10, 7)), 20);
    await store.save();
    store.dispose();
  });
}
