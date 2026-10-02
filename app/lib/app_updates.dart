import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

const releasePrefix =
    'https://github.com/RenatoLV/App_Aniversario/releases/download/';

class AvailableUpdate {
  final String version, url, notes;
  final int code;
  const AvailableUpdate(this.version, this.code, this.url, this.notes);
  static AvailableUpdate parse(
    Map<String, dynamic> release,
    Map<String, dynamic> metadata,
  ) {
    if (release['draft'] == true || release['prerelease'] == true) {
      throw const FormatException('Versión no estable');
    }
    final assets = release['assets'] as List;
    final apk = assets.cast<Map<String, dynamic>>().firstWhere(
      (a) => a['name'] == metadata['apk'],
    );
    final url = apk['browser_download_url'] as String;
    final code = metadata['versionCode'] as int;
    if (!url.startsWith(releasePrefix) || code < 1 || !url.endsWith('.apk')) {
      throw const FormatException('Descarga no válida');
    }
    return AvailableUpdate(
      metadata['versionName'] as String,
      code,
      url,
      release['body'] as String? ?? '',
    );
  }
}

class AppUpdateButton extends StatefulWidget {
  const AppUpdateButton({super.key});
  @override
  State<AppUpdateButton> createState() => _AppUpdateButtonState();
}

class _AppUpdateButtonState extends State<AppUpdateButton> {
  static const channel = MethodChannel('anivermaru/updates');
  bool busy = false;
  AvailableUpdate? update;
  String installed = '', status = 'Comprobar actualizaciones';
  @override
  void initState() {
    super.initState();
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) _check();
  }

  Future<void> _check() async {
    if (busy) return;
    setState(() => busy = true);
    final client = http.Client();
    try {
      final local = await channel.invokeMapMethod<String, dynamic>('version');
      installed = local?['name'] as String? ?? '';
      final response = await client
          .get(
            Uri.parse(
              'https://api.github.com/repos/RenatoLV/App_Aniversario/releases/latest',
            ),
            headers: {'Accept': 'application/vnd.github+json'},
          )
          .timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) {
        throw Exception('GitHub ${response.statusCode}');
      }
      final release = jsonDecode(response.body) as Map<String, dynamic>;
      final asset = (release['assets'] as List)
          .cast<Map<String, dynamic>>()
          .firstWhere((a) => a['name'] == 'update.json');
      final metadataUrl = asset['browser_download_url'] as String;
      if (!metadataUrl.startsWith(releasePrefix)) throw const FormatException();
      final metadata = await client
          .get(Uri.parse(metadataUrl))
          .timeout(const Duration(seconds: 12));
      if (metadata.statusCode != 200) {
        throw Exception('Metadatos no disponibles');
      }
      final remote = AvailableUpdate.parse(
        release,
        jsonDecode(metadata.body) as Map<String, dynamic>,
      );
      update = remote.code > (local?['code'] as int? ?? 0) ? remote : null;
      status = update == null
          ? 'Ya tienes la última versión.'
          : 'Nueva versión ${remote.version} disponible';
    } catch (_) {
      status =
          'No pudimos consultar las versiones. Revisa tu conexión y vuelve a intentarlo.';
    } finally {
      client.close();
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _show() async {
    await _check();
    if (!mounted) return;
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Actualizaciones de Anivermaru'),
        content: SingleChildScrollView(
          child: Text(
            'Versión instalada: $installed\n\n$status'
            '${update == null ? '' : '\n\n${update!.notes}\n\nDescarga la APK e instálala. Android te pedirá confirmar; tus datos se conservan al actualizar.'}',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
          if (update != null)
            FilledButton(
              onPressed: () async {
                try {
                  await channel.invokeMethod<void>('openDownload', {
                    'url': update!.url,
                  });
                } catch (_) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('No se pudo abrir la descarga.'),
                      ),
                    );
                  }
                }
              },
              child: const Text('Descargar APK'),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return const SizedBox.shrink();
    }
    return IconButton(
      tooltip: update == null ? 'Actualizaciones' : status,
      onPressed: busy ? null : _show,
      icon: Badge(
        isLabelVisible: update != null,
        child: const Icon(Icons.system_update),
      ),
    );
  }
}
