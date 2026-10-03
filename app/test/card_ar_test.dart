import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nuestro_rincon/card_ar.dart';
import 'package:nuestro_rincon/card_ar_photo_review.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final png = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aD1sAAAAASUVORK5CYII=',
  );

  test('AR transfers the card texture and returns the native photo', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(CardAr.channel, (call) async {
          expect(call.method, 'open');
          expect(call.arguments['texture'], png);
          return png;
        });
    expect(await CardAr.capture(png), png);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(CardAr.channel, null);
  });

  test('An unsupported platform returns a clear AR error', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      await expectLater(CardAr.capture(png), throwsA(isA<PlatformException>()));
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
  test(
    'Animated AR sends original GIF bytes and a bounded art region with both faces',
    () async {
      final gif = Uint8List.fromList([71, 73, 70, 56, 57, 97]);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(CardAr.channel, (call) async {
            expect(call.arguments['animatedTexture'], gif);
            final rect = call.arguments['animatedRect'] as List;
            for (var i = 0; i < 4; i++) {
              expect(rect[i], closeTo([.1, .2, .8, .5][i], 1e-8));
            }
            expect(call.arguments['backTexture'], png);
            return png;
          });
      try {
        expect(
          await CardAr.capture(
            png,
            backTexture: png,
            animatedTexture: gif,
            animatedRect: const Rect.fromLTWH(.1, .2, .8, .5),
          ),
          png,
        );
      } finally {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(CardAr.channel, null);
      }
    },
  );
  test(
    'Animation requires matching bytes and valid normalized bounds',
    () async {
      for (final rect in [
        null,
        const Rect.fromLTWH(-.1, 0, 1, 1),
        const Rect.fromLTWH(0, .5, 1, 1),
        const Rect.fromLTWH(0, 0, 0, 1),
      ]) {
        await expectLater(
          CardAr.capture(png, animatedTexture: png, animatedRect: rect),
          throwsArgumentError,
        );
      }
      await expectLater(
        CardAr.capture(png, animatedRect: const Rect.fromLTWH(0, 0, 1, 1)),
        throwsArgumentError,
      );
    },
  );

  test(
    'Camera viewer receives both faces for a full 360-degree turn',
    () async {
      final back = Uint8List.fromList([1, 2, 3]);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(CardAr.channel, (call) async {
            expect(call.arguments['texture'], png);
            expect(call.arguments['backTexture'], back);
            return png;
          });
      try {
        expect(await CardAr.capture(png, backTexture: back), png);
      } finally {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(CardAr.channel, null);
      }
    },
  );

  for (final save in [false, true]) {
    testWidgets(
      'Photo review ${save ? 'saves only with consent' : 'can be discarded'}',
      (tester) async {
        bool? result;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () async {
                    result = await showDialog<bool>(
                      context: context,
                      builder: (_) => CardArPhotoReview(photo: png),
                    );
                  },
                  child: const Text('Review'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Review'));
        await tester.pumpAndSettle();
        expect(result, isNull);
        await tester.tap(
          find.text(save ? 'Guardar en Nuestro bloc' : 'Descartar'),
        );
        await tester.pumpAndSettle();
        expect(result, save);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
