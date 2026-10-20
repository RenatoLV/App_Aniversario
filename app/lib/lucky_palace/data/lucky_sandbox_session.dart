import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'lucky_database.dart';
import 'remote_lucky_repository.dart';

/// Separate named Firebase app: production auth/session is never accessed.
class LuckySandboxSession {
  static const enabled = bool.fromEnvironment('LUCKY_SANDBOX');
  static const host = String.fromEnvironment(
    'LUCKY_SANDBOX_HOST',
    defaultValue: '127.0.0.1',
  );
  FirebaseAuth? auth;
  Future<RemoteLuckyRoundRepository> signIn({
    required LuckyDatabase storage,
    required String email,
    required String password,
  }) async {
    if (!kDebugMode || !enabled) {
      throw StateError('Sandbox solo debug explícito');
    }
    final uri = Uri.parse(
      'http://$host:15001/demo-lucky-readiness/us-central1/economyV2',
    );
    // Validate host BEFORE initializing Firebase or exposing an emulator token.
    LuckySandboxTransport(
      endpoint: uri,
      ownerUid: 'validate',
      currentUid: () => null,
      token: () async => '',
    );
    if (auth == null) {
      final app = await Firebase.initializeApp(
        name: 'LuckySandbox4C2',
        options: const FirebaseOptions(
          apiKey: 'demo-key-only',
          appId: '1:123:web:lucky-sandbox',
          messagingSenderId: '123',
          projectId: 'demo-lucky-readiness',
        ),
      );
      auth = FirebaseAuth.instanceFor(app: app);
      await auth!.useAuthEmulator(host, 19099, automaticHostMapping: false);
    }
    await auth!.signInWithEmailAndPassword(email: email, password: password);
    final uid = auth!.currentUser!.uid;
    final transport = LuckySandboxTransport(
      endpoint: uri,
      ownerUid: uid,
      currentUid: () => auth!.currentUser?.uid,
      token: () async {
        if (auth!.currentUser?.uid != uid) throw StateError('Cuenta cambiada');
        return (await auth!.currentUser!.getIdToken())!;
      },
    );
    return RemoteLuckyRoundRepository(
      storage: storage,
      ownerUid: uid,
      call: transport.call,
    );
  }
}
