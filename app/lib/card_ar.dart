import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Interactive 3D card over the camera, without surface or light tracking.
class CardAr {
  static bool get supportedPlatform =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  static const channel = MethodChannel('rincon/card_ar');

  static Future<Uint8List?> capture(
    Uint8List texture, {
    Uint8List? backTexture,
    Uint8List? animatedTexture,
    Rect? animatedRect,
  }) async {
    if ((animatedTexture == null) != (animatedRect == null) ||
        (animatedRect != null &&
            (!animatedRect.isFinite ||
                animatedRect.isEmpty ||
                animatedRect.left < 0 ||
                animatedRect.top < 0 ||
                animatedRect.right > 1 ||
                animatedRect.bottom > 1))) {
      throw ArgumentError(
        'La animación debe tener un marco dentro de la carta.',
      );
    }
    if (!supportedPlatform) {
      throw PlatformException(
        code: 'platform',
        message: 'El visor de cámara 3D está disponible en la app Android.',
      );
    }
    return channel.invokeMethod<Uint8List>('open', {
      'texture': texture,
      'backTexture': ?backTexture,
      'animatedTexture': ?animatedTexture,
      if (animatedRect != null)
        'animatedRect': [
          animatedRect.left,
          animatedRect.top,
          animatedRect.width,
          animatedRect.height,
        ],
    });
  }
}
