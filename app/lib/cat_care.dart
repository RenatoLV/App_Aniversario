import 'package:flutter/material.dart';

enum CatKind { maru, lady }

enum ClothingSlot { neck, head, eyes, body }

class CatClothing {
  final String id, name;
  final ClothingSlot slot;
  final IconData icon;
  final Color color;
  const CatClothing(this.id, this.name, this.slot, this.icon, this.color);
}

const catWardrobe = [
  CatClothing(
    'collar_heart',
    'Collar corazón',
    ClothingSlot.neck,
    Icons.favorite_rounded,
    Color(0xfff4779b),
  ),
  CatClothing(
    'collar_bell',
    'Collar cascabel',
    ClothingSlot.neck,
    Icons.notifications_rounded,
    Color(0xffe4b94f),
  ),
  CatClothing(
    'bandana',
    'Pañuelo rojo',
    ClothingSlot.neck,
    Icons.change_history_rounded,
    Color(0xffdc6260),
  ),
  CatClothing(
    'beanie',
    'Gorro de lana',
    ClothingSlot.head,
    Icons.ac_unit_rounded,
    Color(0xffa992df),
  ),
  CatClothing(
    'explorer',
    'Gorro explorador',
    ClothingSlot.head,
    Icons.explore_rounded,
    Color(0xffc6a970),
  ),
  CatClothing(
    'glasses',
    'Lentes redondos',
    ClothingSlot.eyes,
    Icons.visibility_rounded,
    Color(0xff547ca8),
  ),
  CatClothing(
    'shirt_stripes',
    'Polera marinera',
    ClothingSlot.body,
    Icons.checkroom_rounded,
    Color(0xff5dacc6),
  ),
  CatClothing(
    'shirt_star',
    'Polera estrella',
    ClothingSlot.body,
    Icons.star_rounded,
    Color(0xff9b80d1),
  ),
  CatClothing(
    'collar_star',
    'Collar estrella',
    ClothingSlot.neck,
    Icons.star_rounded,
    Color(0xff789cda),
  ),
  CatClothing(
    'collar_moon',
    'Collar lunar',
    ClothingSlot.neck,
    Icons.nightlight_round,
    Color(0xff7965b2),
  ),
  CatClothing(
    'collar_bow',
    'Corbatín',
    ClothingSlot.neck,
    Icons.style_rounded,
    Color(0xff7195bd),
  ),
  CatClothing(
    'collar_flower',
    'Collar margarita',
    ClothingSlot.neck,
    Icons.local_florist_rounded,
    Color(0xff80b78c),
  ),
  CatClothing(
    'bandana_blue',
    'Pañuelo vaquero',
    ClothingSlot.neck,
    Icons.landscape_rounded,
    Color(0xff668fc0),
  ),
  CatClothing(
    'bandana_green',
    'Pañuelo bosque',
    ClothingSlot.neck,
    Icons.forest_rounded,
    Color(0xff649675),
  ),
  CatClothing(
    'bandana_pirate',
    'Pañuelo pirata',
    ClothingSlot.neck,
    Icons.sailing_rounded,
    Color(0xff514d65),
  ),
  CatClothing(
    'cap',
    'Gorra deportiva',
    ClothingSlot.head,
    Icons.sports_baseball_rounded,
    Color(0xffdc8b7c),
  ),
  CatClothing(
    'bow',
    'Lazo de lunares',
    ClothingSlot.head,
    Icons.style_rounded,
    Color(0xffed92b3),
  ),
  CatClothing(
    'crown',
    'Corona real',
    ClothingSlot.head,
    Icons.workspace_premium_rounded,
    Color(0xffe3b449),
  ),
  CatClothing(
    'wizard',
    'Sombrero mágico',
    ClothingSlot.head,
    Icons.auto_awesome_rounded,
    Color(0xff7b70ba),
  ),
  CatClothing(
    'sailor',
    'Gorro marinero',
    ClothingSlot.head,
    Icons.sailing_rounded,
    Color(0xffe7e9e4),
  ),
  CatClothing(
    'chef',
    'Gorro de chef',
    ClothingSlot.head,
    Icons.restaurant_rounded,
    Color(0xfff3e9d7),
  ),
  CatClothing(
    'party',
    'Gorro de fiesta',
    ClothingSlot.head,
    Icons.celebration_rounded,
    Color(0xff74bdba),
  ),
  CatClothing(
    'beret',
    'Boina artística',
    ClothingSlot.head,
    Icons.palette_rounded,
    Color(0xffb15d79),
  ),
  CatClothing(
    'glasses_aviator',
    'Lentes aviador',
    ClothingSlot.eyes,
    Icons.flight_rounded,
    Color(0xffbca15c),
  ),
  CatClothing(
    'glasses_heart',
    'Lentes corazón',
    ClothingSlot.eyes,
    Icons.favorite_rounded,
    Color(0xffe079a0),
  ),
  CatClothing(
    'glasses_cat',
    'Lentes gatunos',
    ClothingSlot.eyes,
    Icons.pets_rounded,
    Color(0xff9373bb),
  ),
  CatClothing(
    'glasses_square',
    'Lentes cuadrados',
    ClothingSlot.eyes,
    Icons.crop_square_rounded,
    Color(0xff52776c),
  ),
  CatClothing(
    'glasses_sport',
    'Lentes deportivos',
    ClothingSlot.eyes,
    Icons.sports_rounded,
    Color(0xffdc8957),
  ),
  CatClothing(
    'glasses_star',
    'Lentes estrella',
    ClothingSlot.eyes,
    Icons.star_rounded,
    Color(0xffc4a449),
  ),
  CatClothing(
    'glasses_pixel',
    'Lentes pixel',
    ClothingSlot.eyes,
    Icons.grid_view_rounded,
    Color(0xff414253),
  ),
  CatClothing(
    'glasses_tiny',
    'Lentes pequeños',
    ClothingSlot.eyes,
    Icons.visibility_rounded,
    Color(0xffbc7790),
  ),
  CatClothing(
    'glasses_rainbow',
    'Lentes arcoíris',
    ClothingSlot.eyes,
    Icons.waves_rounded,
    Color(0xff67abae),
  ),
  CatClothing(
    'shirt_check',
    'Polera ajedrez',
    ClothingSlot.body,
    Icons.grid_on_rounded,
    Color(0xff7383a0),
  ),
  CatClothing(
    'shirt_sunset',
    'Polera atardecer',
    ClothingSlot.body,
    Icons.wb_sunny_rounded,
    Color(0xffe99774),
  ),
  CatClothing(
    'shirt_space',
    'Polera espacial',
    ClothingSlot.body,
    Icons.rocket_launch_rounded,
    Color(0xff535a97),
  ),
  CatClothing(
    'shirt_flower',
    'Polera floral',
    ClothingSlot.body,
    Icons.local_florist_rounded,
    Color(0xffddb2c8),
  ),
  CatClothing(
    'shirt_hoodie',
    'Polerón con bolsillo',
    ClothingSlot.body,
    Icons.checkroom_rounded,
    Color(0xff81ae8f),
  ),
  CatClothing(
    'shirt_tux',
    'Polera elegante',
    ClothingSlot.body,
    Icons.business_center_rounded,
    Color(0xff4b4e59),
  ),
  CatClothing(
    'shirt_sailor',
    'Polera con ancla',
    ClothingSlot.body,
    Icons.anchor_rounded,
    Color(0xff4b729d),
  ),
  CatClothing(
    'shirt_honey',
    'Polera abejita',
    ClothingSlot.body,
    Icons.emoji_nature_rounded,
    Color(0xffe8bb50),
  ),
];

CatClothing? clothingById(String? id) {
  for (final item in catWardrobe) {
    if (item.id == id) return item;
  }
  return null;
}

@immutable
class CatOutfit {
  final String? neck, head, eyes, body;
  const CatOutfit({this.neck, this.head, this.eyes, this.body});
  String? at(ClothingSlot slot) => switch (slot) {
    ClothingSlot.neck => neck,
    ClothingSlot.head => head,
    ClothingSlot.eyes => eyes,
    ClothingSlot.body => body,
  };
  CatOutfit withItem(ClothingSlot slot, String? id) {
    if (id != null && clothingById(id)?.slot != slot) return this;
    return CatOutfit(
      neck: slot == ClothingSlot.neck ? id : neck,
      head: slot == ClothingSlot.head ? id : head,
      eyes: slot == ClothingSlot.eyes ? id : eyes,
      body: slot == ClothingSlot.body ? id : body,
    );
  }

  Map<String, dynamic> toJson() => {
    for (final slot in ClothingSlot.values) slot.name: at(slot),
  };
  factory CatOutfit.fromJson(dynamic data) {
    var outfit = const CatOutfit();
    if (data is Map) {
      for (final slot in ClothingSlot.values) {
        final id = data[slot.name];
        if (id is String) outfit = outfit.withItem(slot, id);
      }
    }
    return outfit;
  }
  @override
  bool operator ==(Object other) =>
      other is CatOutfit &&
      neck == other.neck &&
      head == other.head &&
      eyes == other.eyes &&
      body == other.body;
  @override
  int get hashCode => Object.hash(neck, head, eyes, body);
}

class CatNeeds {
  final int food, clean, happy;
  const CatNeeds(this.food, this.clean, this.happy);
}

enum CatFood {
  kibble,
  fish,
  churu,
  tuna,
  salmon,
  chicken,
  shrimp,
  egg,
  pumpkin,
  broth,
}

extension CatFoodLabel on CatFood {
  String get label => switch (this) {
    CatFood.kibble => 'Croquetas',
    CatFood.fish => 'Pescadito',
    CatFood.churu => 'Churú',
    CatFood.tuna => 'Atún',
    CatFood.salmon => 'Salmón',
    CatFood.chicken => 'Pollito',
    CatFood.shrimp => 'Camarón',
    CatFood.egg => 'Huevito',
    CatFood.pumpkin => 'Calabacita',
    CatFood.broth => 'Caldito',
  };
  String get emoji => switch (this) {
    CatFood.kibble => '🥣',
    CatFood.fish => '🐟',
    CatFood.churu => '🍥',
    CatFood.tuna => '🥫',
    CatFood.salmon => '🍣',
    CatFood.chicken => '🍗',
    CatFood.shrimp => '🦐',
    CatFood.egg => '🥚',
    CatFood.pumpkin => '🎃',
    CatFood.broth => '🍲',
  };
  int get nutrition => switch (this) {
    CatFood.kibble => 30,
    CatFood.fish => 38,
    CatFood.churu => 20,
    CatFood.tuna => 32,
    CatFood.salmon => 35,
    CatFood.chicken => 34,
    CatFood.shrimp => 24,
    CatFood.egg => 25,
    CatFood.pumpkin => 18,
    CatFood.broth => 22,
  };
  Color get color => switch (this) {
    CatFood.kibble => const Color(0xffb98753),
    CatFood.fish => const Color(0xff6aa8c0),
    CatFood.churu => const Color(0xffe481a5),
    CatFood.tuna => const Color(0xffa289c8),
    CatFood.salmon => const Color(0xfff2a084),
    CatFood.chicken => const Color(0xffd2a26c),
    CatFood.shrimp => const Color(0xffea967e),
    CatFood.egg => const Color(0xffe9c55e),
    CatFood.pumpkin => const Color(0xffe1a458),
    CatFood.broth => const Color(0xff8dbca0),
  };
  String get reaction => switch (this) {
    CatFood.kibble => '¡Crunch, crunch! Croquetas crujientes',
    CatFood.fish => '¡Atrapó el pescadito de un mordisco!',
    CatFood.churu => 'Lame su churú hasta la última gotita',
    CatFood.tuna => 'Abrió la latita y se relame los bigotes',
    CatFood.salmon => 'Bocados pequeños de su salmón favorito',
    CatFood.chicken => 'Sujeta el pollito con las patitas',
    CatFood.shrimp => '¡Qué salto para atrapar el camarón!',
    CatFood.egg => 'Rompe el huevito y prueba el centro',
    CatFood.pumpkin => 'Amasa su suave calabacita',
    CatFood.broth => 'Sorbitos tibios de caldito',
  };
}

class _CatProfile {
  int food = 75, clean = 80, happy = 75;
  DateTime updated;
  CatOutfit outfit = const CatOutfit();
  _CatProfile(this.updated);
}

class CatCare extends ChangeNotifier {
  final DateTime Function() now;
  final Future<void> Function()? onChanged;
  late final Map<CatKind, _CatProfile> _profiles = {
    for (final cat in CatKind.values) cat: _CatProfile(now()),
  };
  CatCare({DateTime Function()? clock, this.onChanged})
    : now = clock ?? DateTime.now;

  CatNeeds needs(CatKind cat) {
    final p = _profiles[cat]!;
    final hours = now().difference(p.updated).inMinutes.clamp(0, 1440) / 60;
    // Gentle, capped decay: the cats never disappear or affect game difficulty.
    return CatNeeds(
      (p.food - hours * 3).round().clamp(15, 100),
      (p.clean - hours * 2).round().clamp(15, 100),
      (p.happy - hours * 1.5).round().clamp(20, 100),
    );
  }

  CatOutfit outfit(CatKind cat) => _profiles[cat]!.outfit;
  void _settle(CatKind cat) {
    final values = needs(cat), p = _profiles[cat]!;
    p.food = values.food;
    p.clean = values.clean;
    p.happy = values.happy;
    p.updated = now();
  }

  Future<void> _changed() async {
    notifyListeners();
    await onChanged?.call();
  }

  Future<void> feed(CatKind cat, CatFood food) async {
    _settle(cat);
    final p = _profiles[cat]!;
    p.food = (p.food + food.nutrition).clamp(0, 100);
    p.happy = (p.happy + 8).clamp(0, 100);
    await _changed();
  }

  Future<void> bathe(CatKind cat) async {
    _settle(cat);
    final p = _profiles[cat]!;
    p.clean = 100;
    p.happy = (p.happy + 12).clamp(0, 100);
    await _changed();
  }

  Future<void> pet(CatKind cat) async {
    _settle(cat);
    final p = _profiles[cat]!;
    p.happy = (p.happy + 10).clamp(0, 100);
    await _changed();
  }

  Future<void> equip(CatKind cat, CatClothing item) async {
    final p = _profiles[cat]!;
    p.outfit = p.outfit.withItem(
      item.slot,
      p.outfit.at(item.slot) == item.id ? null : item.id,
    );
    await _changed();
  }

  Future<void> undress(CatKind cat) async {
    _profiles[cat]!.outfit = const CatOutfit();
    await _changed();
  }

  Map<String, dynamic> toJson() => {
    for (final cat in CatKind.values)
      cat.name: {
        'food': _profiles[cat]!.food,
        'clean': _profiles[cat]!.clean,
        'happy': _profiles[cat]!.happy,
        'updated': _profiles[cat]!.updated.toUtc().toIso8601String(),
        'outfit': outfit(cat).toJson(),
      },
  };
  void restore(dynamic data, {bool notify = false}) {
    _profiles.clear();
    for (final cat in CatKind.values) {
      final p = _CatProfile(now());
      final entry = data is Map ? data[cat.name] : null;
      if (entry is Map) {
        int value(String key, int fallback) => entry[key] is num
            ? (entry[key] as num).toInt().clamp(0, 100)
            : fallback;
        p.food = value('food', 75);
        p.clean = value('clean', 80);
        p.happy = value('happy', 75);
        p.updated =
            DateTime.tryParse(entry['updated']?.toString() ?? '') ?? now();
        p.outfit = CatOutfit.fromJson(entry['outfit']);
      }
      _profiles[cat] = p;
    }
    if (notify) notifyListeners();
  }
}

class CatCareScope extends InheritedNotifier<CatCare> {
  const CatCareScope({super.key, required CatCare care, required super.child})
    : super(notifier: care);
  static CatCare? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<CatCareScope>()?.notifier;
  static CatOutfit outfitOf(BuildContext context, CatKind cat) =>
      maybeOf(context)?.outfit(cat) ?? const CatOutfit();
  static double cleanlinessOf(BuildContext context, CatKind cat) =>
      maybeOf(context)?.needs(cat).clean.toDouble() ?? 100;
}
