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
  }) async {
    if (!supportedPlatform) {
      throw PlatformException(
        code: 'platform',
        message: 'El visor de cámara 3D está disponible en la app Android.',
      );
    }
    return channel.invokeMethod<Uint8List>('open', {
      'texture': texture,
      'backTexture': ?backTexture,
    });
  }
}
