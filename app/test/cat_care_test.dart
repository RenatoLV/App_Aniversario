import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nuestro_rincon/cat_care.dart';
import 'package:nuestro_rincon/store.dart';

void main() {
  test('Wardrobe has ten unique garments per category and ten foods', () {
    expect(catWardrobe.length, 40);
    expect(catWardrobe.map((item) => item.id).toSet().length, 40);
    for (final slot in ClothingSlot.values) {
      expect(catWardrobe.where((item) => item.slot == slot).length, 10);
    }
    expect(CatFood.values.length, 10);
  });
  test(
    'Care is independent, gently decays offline and remains recoverable',
    () async {
      var clock = DateTime.utc(2026, 10, 2);
      final care = CatCare(clock: () => clock);
      expect(care.needs(CatKind.maru).food, 75);
      clock = clock.add(const Duration(hours: 12));
      expect(care.needs(CatKind.maru).food, 39);
      final lady = care.needs(CatKind.lady);
      await care.feed(CatKind.maru, CatFood.fish);
      expect(care.needs(CatKind.maru).food, 77);
      expect(care.needs(CatKind.lady).food, lady.food);
      await care.bathe(CatKind.maru);
      expect(care.needs(CatKind.maru).clean, 100);
      clock = clock.add(const Duration(days: 100));
      expect(care.needs(CatKind.maru).food, greaterThanOrEqualTo(15));
      expect(care.needs(CatKind.maru).happy, greaterThanOrEqualTo(20));
    },
  );
  test(
    'Equipment combines slots, toggles and never leaks between cats',
    () async {
      final care = CatCare();
      for (final id in ['collar_heart', 'beanie', 'glasses', 'shirt_star']) {
        await care.equip(CatKind.maru, clothingById(id)!);
      }
      final outfit = care.outfit(CatKind.maru);
      expect(outfit.neck, 'collar_heart');
      expect(outfit.head, 'beanie');
      expect(outfit.eyes, 'glasses');
      expect(outfit.body, 'shirt_star');
      expect(care.outfit(CatKind.lady), const CatOutfit());
      await care.equip(CatKind.maru, clothingById('beanie')!);
      expect(care.outfit(CatKind.maru).head, isNull);
      expect(care.outfit(CatKind.maru).body, 'shirt_star');
      expect(
        CatOutfit.fromJson({'head': 'shirt_star', 'neck': 'missing'}),
        const CatOutfit(),
      );
      await care.undress(CatKind.maru);
      expect(care.outfit(CatKind.maru), const CatOutfit());
    },
  );
  test(
    'Clothes and needs survive reload and are included in cloud snapshots',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance(),
          store = GameStore(await SharedPreferences.getInstance());
      store.coins = 987;
      await store.catCare.equip(CatKind.lady, clothingById('explorer')!);
      await store.catCare.feed(CatKind.lady, CatFood.kibble);
      final restored = GameStore(prefs);
      expect(restored.coins, 987);
      expect(restored.catCare.outfit(CatKind.lady).head, 'explorer');
      expect(restored.catCare.needs(CatKind.lady).food, 100);
      final cloud = jsonDecode(store.cloud.snapshot()) as Map<String, dynamic>;
      expect(
        jsonDecode(cloud['rincon.v1'])['catCare']['lady']['outfit']['head'],
        'explorer',
      );
      final legacy =
          jsonDecode(prefs.getString('rincon.v1')!) as Map<String, dynamic>;
      legacy.remove('catCare');
      await prefs.setString('rincon.v1', jsonEncode(legacy));
      final migrated = GameStore(prefs);
      expect(migrated.coins, 987);
      expect(migrated.catCare.outfit(CatKind.lady), const CatOutfit());
      expect(migrated.saveError, isNull);
    },
  );
}
