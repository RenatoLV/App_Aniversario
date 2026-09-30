import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Native ARCore anchors the card in the world, not a camera screen overlay.
class CardAr {
  static bool get supportedPlatform =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  static const channel = MethodChannel('rincon/card_ar');

  static Future<Uint8List?> capture(Uint8List texture) async {
    if (!supportedPlatform) {
      throw PlatformException(
        code: 'platform',
        message:
            'La realidad aumentada está disponible en la app Android, en teléfonos compatibles con ARCore.',
      );
    }
    return channel.invokeMethod<Uint8List>('open', {'texture': texture});
  }
}
