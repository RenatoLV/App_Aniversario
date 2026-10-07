import 'package:flutter_test/flutter_test.dart';
import 'package:nuestro_rincon/cat_care.dart';

void main() {
  test(
    'Light off freezes needs across long background time and restores independently',
    () async {
      var time = DateTime(2026, 10, 7, 12);
      final care = CatCare(clock: () => time);
      care.needs(CatKind.maru);
      time = time.add(const Duration(hours: 2));
      final before = care.needs(CatKind.maru);
      expect(before.food, 69);
      expect(before.clean, 76);
      await care.decorateBedroom(
        CatKind.maru,
        care.bedroom(CatKind.maru).copyWith(lamp: false),
      );
      time = time.add(const Duration(days: 5));
      expect(care.needs(CatKind.maru).food, before.food);
      expect(care.needs(CatKind.maru).clean, before.clean);
      expect(care.needs(CatKind.lady).food, lessThan(before.food));
      final restored = CatCare(clock: () => time)..restore(care.toJson());
      expect(restored.resting(CatKind.maru), isTrue);
      expect(restored.resting(CatKind.lady), isFalse);
      await restored.decorateBedroom(
        CatKind.maru,
        restored.bedroom(CatKind.maru).copyWith(lamp: true),
      );
      expect(restored.needs(CatKind.maru).food, before.food);
      time = time.add(const Duration(hours: 1));
      expect(restored.needs(CatKind.maru).food, before.food - 3);
      expect(restored.needs(CatKind.maru).clean, before.clean - 2);
      care.dispose();
      restored.dispose();
    },
  );
  test(
    'Decorating a dark room does not wake the cat or reset its frozen needs',
    () async {
      var time = DateTime(2026, 10, 7);
      final care = CatCare(clock: () => time);
      await care.decorateBedroom(
        CatKind.lady,
        care.bedroom(CatKind.lady).copyWith(lamp: false),
      );
      time = time.add(const Duration(hours: 10));
      await care.decorateBedroom(
        CatKind.lady,
        care.bedroom(CatKind.lady).copyWith(bed: 'star'),
      );
      expect(care.resting(CatKind.lady), isTrue);
      expect(care.needs(CatKind.lady).food, 75);
      expect(care.needs(CatKind.lady).clean, 80);
      care.dispose();
    },
  );
}
