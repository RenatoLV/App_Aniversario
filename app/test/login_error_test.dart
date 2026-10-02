import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:nuestro_rincon/backend.dart';

void main() {
  test('Google cancellation is different from authentication failure', () {
    expect(
      Backend.loginErrorMessage(
        const GoogleSignInException(code: GoogleSignInExceptionCode.canceled),
      ),
      'Inicio de sesión cancelado.',
    );
  });
  test('Firebase authentication exposes the actionable error code', () {
    expect(
      Backend.loginErrorMessage(
        FirebaseAuthException(code: 'invalid-credential'),
      ),
      contains('invalid-credential'),
    );
  });
  test(
    'Database permission failure is not reported as Google login disabled',
    () {
      final message = Backend.loginErrorMessage(
        FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied'),
      );
      expect(message, contains('cloud_firestore: permission-denied'));
      expect(message, isNot(contains('Google esté habilitado')));
    },
  );
}
