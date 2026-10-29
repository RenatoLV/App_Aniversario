import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../store.dart';

/// Launcher for the original Godot game, bundled separately from Flutter UI.
class UncannyGolfScreen extends StatefulWidget {
  const UncannyGolfScreen({super.key, required this.store});
  final GameStore store;
  @override
  State<UncannyGolfScreen> createState() => _UncannyGolfScreenState();
}

class _UncannyGolfScreenState extends State<UncannyGolfScreen> {
  static const _channel = MethodChannel('anivermaru/uncanny_golf');
  bool _opening = false;
  String? _error;
  bool get _supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<void> _launch() async {
    if (_opening) return;
    setState(() {
      _opening = true;
      _error = null;
    });
    try {
      await _channel.invokeMethod<void>('launch');
    } on PlatformException catch (e) {
      if (mounted) {
        setState(() => _error = e.message ?? 'No se pudo abrir el juego.');
      }
    } on MissingPluginException {
      if (mounted) {
        setState(
          () => _error = 'El juego original requiere la nueva APK de Android.',
        );
      }
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xff101521),
    appBar: AppBar(title: const Text('Uncanny Cat Golf')),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Icon(Icons.sports_golf, size: 72, color: Color(0xff70e5ee)),
          const SizedBox(height: 24),
          const Text(
            'Uncanny Cat Golf original',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Los mapas, personajes, modelos, sonidos y menús del juego original, ejecutados con Godot. Pantalla completa horizontal, presentación original de PC y controles transparentes para jugar desde Anivermaru.',
            style: TextStyle(color: Color(0xffccd6ef), fontSize: 16),
          ),
          const SizedBox(height: 24),
          if (_supported)
            FilledButton.icon(
              key: const Key('ucg-launch-original'),
              onPressed: _opening ? null : _launch,
              icon: const Icon(Icons.play_arrow),
              label: Text(_opening ? 'Abriendo…' : 'Jugar'),
            )
          else
            const Text(
              'Disponible en la APK de Android. La versión web no ejecuta el juego original.',
              style: TextStyle(color: Color(0xff70e5ee)),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                _error!,
                style: const TextStyle(color: Colors.orangeAccent),
              ),
            ),
          const SizedBox(height: 32),
          const SelectableText(
            'Juego original: SH2K (SlappyHappy2000) y The Canny Crew: Haze Weathers, mbx8rt, Penny Rigate, greenhead352 y bibizu.\n\nhttps://slappyhappy2000.itch.io/uncanny-cat-golf\n\nIntegración móvil no oficial en Anivermaru.',
            style: TextStyle(color: Color(0xffaabad4), height: 1.5),
          ),
        ],
      ),
    ),
  );
}
