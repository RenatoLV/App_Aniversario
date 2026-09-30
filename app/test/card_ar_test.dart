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
