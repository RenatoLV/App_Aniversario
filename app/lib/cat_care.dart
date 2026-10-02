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

enum CatFood { kibble, fish, churu }

extension CatFoodLabel on CatFood {
  String get label => switch (this) {
    CatFood.kibble => 'Croquetas',
    CatFood.fish => 'Pescadito',
    CatFood.churu => 'Churú',
  };
  String get emoji => switch (this) {
    CatFood.kibble => '🥣',
    CatFood.fish => '🐟',
    CatFood.churu => '🍥',
  };
  int get nutrition => switch (this) {
    CatFood.kibble => 30,
    CatFood.fish => 38,
    CatFood.churu => 20,
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
}
