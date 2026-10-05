import 'package:flutter/foundation.dart';

/// Each cat keeps its own room, including after cloud restore or an upgrade.
@immutable
class CatBedroom {
  final String palette, bed, rug, decoration;
  final int? poster;
  final bool lamp;
  const CatBedroom({
    this.palette = 'forest',
    this.bed = 'basket',
    this.rug = 'round',
    this.decoration = 'plant',
    this.poster,
    this.lamp = true,
  });

  static const palettes = ['forest', 'rose', 'lavender', 'sunset'];
  static const beds = ['basket', 'cloud', 'star'];
  static const rugs = ['round', 'paw', 'none'];
  static const decorations = ['plant', 'books', 'toys'];
  factory CatBedroom.defaults({bool lady = false}) => lady
      ? const CatBedroom(palette: 'rose', bed: 'cloud', decoration: 'toys')
      : const CatBedroom();

  CatBedroom copyWith({
    String? palette,
    String? bed,
    String? rug,
    String? decoration,
    int? poster,
    bool clearPoster = false,
    bool? lamp,
  }) => CatBedroom(
    palette: palette ?? this.palette,
    bed: bed ?? this.bed,
    rug: rug ?? this.rug,
    decoration: decoration ?? this.decoration,
    poster: clearPoster ? null : poster ?? this.poster,
    lamp: lamp ?? this.lamp,
  );

  Map<String, dynamic> toJson() => {
    'palette': palette,
    'bed': bed,
    'rug': rug,
    'decoration': decoration,
    'poster': poster,
    'lamp': lamp,
  };

  factory CatBedroom.fromJson(dynamic value, {bool lady = false}) {
    final fallback = CatBedroom.defaults(lady: lady);
    if (value is! Map) return fallback;
    String choice(String key, List<String> values, String initial) =>
        values.contains(value[key]) ? value[key] as String : initial;
    return CatBedroom(
      palette: choice('palette', palettes, fallback.palette),
      bed: choice('bed', beds, fallback.bed),
      rug: choice('rug', rugs, fallback.rug),
      decoration: choice('decoration', decorations, fallback.decoration),
      poster: value['poster'] is int && (value['poster'] as int) >= 0
          ? value['poster'] as int
          : null,
      lamp: value['lamp'] is bool ? value['lamp'] as bool : fallback.lamp,
    );
  }
}
