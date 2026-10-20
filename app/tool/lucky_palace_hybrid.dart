import 'package:shared_preferences/shared_preferences.dart';
import 'package:nuestro_rincon/game_audio.dart';
import 'package:flutter/material.dart';
import 'package:nuestro_rincon/lucky_palace/lucky_palace_screen.dart';
import 'package:nuestro_rincon/lucky_palace/scratch/scratch_screen.dart';
import 'package:nuestro_rincon/lucky_palace/data/lucky_database.dart';
import 'package:nuestro_rincon/lucky_palace/data/lucky_sandbox_session.dart';
import 'package:nuestro_rincon/lucky_palace/data/lucky_models.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await GameAudio.instance.initialize(await SharedPreferences.getInstance());
  runApp(
    Listener(
      onPointerDown: (_) => GameAudio.instance.unlock(),
      child: const LuckyHybridDemo(),
    ),
  );
}

class LuckyHybridDemo extends StatefulWidget {
  const LuckyHybridDemo({super.key});
  @override
  State<LuckyHybridDemo> createState() => _LuckyHybridDemoState();
}

class _LuckyHybridDemoState extends State<LuckyHybridDemo> {
  final session = LuckySandboxSession();
  final navigatorKey = GlobalKey<NavigatorState>();
  Future<LuckyRoundRepository> connect() async {
    final email = TextEditingController(text: 'lucky.player@example.invalid');
    final password = TextEditingController(text: 'local-demo-password-only');
    final accepted = await showDialog<bool>(
      context: navigatorKey.currentContext!,
      builder: (ctx) => AlertDialog(
        title: const Text('Cuenta del emulador · demo aislada'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: email,
                decoration: const InputDecoration(
                  labelText: 'Correo sintético',
                ),
              ),
              TextField(
                controller: password,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Contraseña sintética',
                ),
              ),
              const Text(
                'No uses una cuenta de producción. Local no necesita iniciar sesión.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Conectar'),
          ),
        ],
      ),
    );
    final e = email.text.trim(), p = password.text;
    email.dispose();
    password.dispose();
    if (accepted != true) throw StateError('Acceso cancelado');
    return session.signIn(
      storage: LuckyDatabase(await openLuckyDatabase()),
      email: e,
      password: p,
    );
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    navigatorKey: navigatorKey,
    debugShowCheckedModeBanner: false,
    home: Builder(
      builder: (context) => Uri.base.queryParameters['game'] == 'scratch'
          ? const ScratchScreen()
          : LuckyPalaceScreen(
              connectSandbox: LuckySandboxSession.enabled ? connect : null,
            ),
    ),
  );
}
