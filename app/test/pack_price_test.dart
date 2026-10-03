import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nuestro_rincon/store.dart';
import 'package:nuestro_rincon/cat_character.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'Only the first successful pack per local day costs 20 across both volumes and restarts',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final today = DateTime(2026, 10, 3, 23, 59),
          tomorrow = DateTime(2026, 10, 4);
      final store = GameStore(prefs)..coins = 10;
      expect(store.openPack(opener: CatKind.maru, now: today), isNull);
      expect(store.packPriceAt(today), 20);
      store.coins = 150;
      expect(store.openPack(opener: CatKind.maru, now: today), isNotNull);
      expect(store.coins, 130);
      await store.save();
      final restored = GameStore(prefs);
      expect(restored.packPriceAt(today), 50);
      expect(
        restored.openPack(
          opener: CatKind.lady,
          now: today,
          collectionId: anniversaryCollectionV2Id,
        ),
        isNotNull,
      );
      expect(restored.coins, 80);
      expect(restored.packPriceAt(tomorrow), 20);
      restored.openPack(opener: CatKind.maru, now: tomorrow);
      expect(restored.coins, 60);
      await restored.save();
      store.dispose();
      restored.dispose();
    },
  );
}
