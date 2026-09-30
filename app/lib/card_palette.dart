import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'store.dart';

class CardPalette {
  final Color primary;
  final Color secondary;
  final Color accent;

  const CardPalette({
    required this.primary,
    required this.secondary,
    required this.accent,
  });
}

class CardPaletteExtractor {
  static final Map<int, Future<CardPalette>> _cache = {};

  static Future<CardPalette> load(int cardId, Color fallback) =>
      _cache.putIfAbsent(cardId, () => _extract(cardId, fallback));

  static Future<CardPalette> _extract(int cardId, Color fallback) async {
    final asset = cardAsset(cardId);
    if (asset == null) return _fallback(fallback);
    try {
      final bytes = await rootBundle.load(asset);
      final codec = await ui.instantiateImageCodec(
        bytes.buffer.asUint8List(),
        targetWidth: 42,
        targetHeight: 42,
      );
      final frame = await codec.getNextFrame();
      final data = await frame.image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );
      frame.image.dispose();
      codec.dispose();
      if (data == null) return _fallback(fallback);
      return _fromPixels(data.buffer.asUint8List(), fallback);
    } catch (_) {
      return _fallback(fallback);
    }
  }

  static CardPalette _fromPixels(Uint8List pixels, Color fallback) {
    final buckets = <int, _ColorBucket>{};
    for (var i = 0; i + 3 < pixels.length; i += 4) {
      final r = pixels[i], g = pixels[i + 1], b = pixels[i + 2];
      if (pixels[i + 3] < 180) continue;
      final maxChannel = [r, g, b].reduce((a, b) => a > b ? a : b);
      final minChannel = [r, g, b].reduce((a, b) => a < b ? a : b);
      final brightness = (r + g + b) / 3;
      if (brightness > 246 || brightness < 10) continue;
      final saturation = (maxChannel - minChannel) / 255;
      final key = (r ~/ 32 << 6) | (g ~/ 32 << 3) | (b ~/ 32);
      final bucket = buckets.putIfAbsent(key, _ColorBucket.new);
      bucket
        ..r += r
        ..g += g
        ..b += b
        ..count += 1
        ..score += .45 + saturation * 1.35;
    }
    if (buckets.isEmpty) return _fallback(fallback);
    final ranked = buckets.values.toList()
      ..sort((a, b) => b.score.compareTo(a.score));
    final primary = ranked.first.color;
    var secondary = primary;
    var bestDistance = -1.0;
    for (final bucket in ranked.take(18)) {
      final candidate = bucket.color;
      final distance = _distance(primary, candidate) * bucket.score;
      if (distance > bestDistance) {
        secondary = candidate;
        bestDistance = distance;
      }
    }
    final primaryHsl = HSLColor.fromColor(primary);
    final secondaryHsl = HSLColor.fromColor(secondary);
    final accentBase = primaryHsl.saturation >= secondaryHsl.saturation
        ? primaryHsl
        : secondaryHsl;
    final accent = accentBase
        .withSaturation((accentBase.saturation + .24).clamp(0, 1))
        .withLightness(.68)
        .toColor();
    return CardPalette(
      primary: _usable(primary),
      secondary: _usable(secondary),
      accent: accent,
    );
  }

  static Color _usable(Color color) {
    final hsl = HSLColor.fromColor(color);
    return hsl
        .withSaturation((hsl.saturation + .12).clamp(.22, .88))
        .withLightness(hsl.lightness.clamp(.27, .62))
        .toColor();
  }

  static double _distance(Color a, Color b) {
    final dr = a.r - b.r, dg = a.g - b.g, db = a.b - b.b;
    return dr * dr + dg * dg + db * db;
  }

  static CardPalette _fallback(Color color) => CardPalette(
    primary: color,
    secondary: Color.lerp(color, const Color(0xff49317b), .58)!,
    accent: Color.lerp(color, Colors.white, .48)!,
  );
}

class _ColorBucket {
  int r = 0, g = 0, b = 0, count = 0;
  double score = 0;

  Color get color => Color.fromARGB(255, r ~/ count, g ~/ count, b ~/ count);
}
