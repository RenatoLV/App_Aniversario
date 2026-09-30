import 'package:flutter/material.dart';
import 'backend.dart';

List<Map<String, dynamic>> rankGameScores(
  List<Map<String, dynamic>> scores,
  String gameId,
) {
  final rows = scores.where((row) => row['game'] == gameId).toList();
  rows.sort((a, b) {
    final rank = (b['score'] as num).compareTo(a['score'] as num);
    if (rank != 0) return rank;
    return (a['nickname'] as String).toLowerCase().compareTo(
      (b['nickname'] as String).toLowerCase(),
    );
  });
  return rows;
}

class GameLeaderboardDialog extends StatefulWidget {
  final String gameId, title;
  final String? spaceId;
  final List<Map<String, dynamic>> initialScores;
  const GameLeaderboardDialog({
    super.key,
    required this.gameId,
    required this.title,
    required this.spaceId,
    this.initialScores = const [],
  });

  @override
  State<GameLeaderboardDialog> createState() => _GameLeaderboardDialogState();
}

class _GameLeaderboardDialogState extends State<GameLeaderboardDialog> {
  late final Stream<List<Map<String, dynamic>>>? _scores =
      widget.spaceId == null ? null : Backend.watchHighscores(widget.spaceId!);

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('Clasificación · ${widget.title}'),
    content: SizedBox(
      width: 340,
      child: widget.spaceId == null
          ? const Text(
              'Inicia sesión desde Inicio para guardar tus récords. Comparte o únete a un espacio desde Nuestro bloc para competir con sus integrantes.',
            )
          : StreamBuilder<List<Map<String, dynamic>>>(
              stream: _scores,
              initialData: widget.initialScores,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Text(
                    'No pudimos actualizar la clasificación. Revisa la conexión y vuelve a intentarlo.',
                  );
                }
                final rows = rankGameScores(snapshot.data ?? [], widget.gameId);
                if (rows.isEmpty) {
                  return const Text(
                    'Todavía no hay récords de este juego en tu espacio. ¡Sé el primero!',
                  );
                }
                return ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(context).height * .5,
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: rows.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final row = rows[index];
                      final yours = row['user_id'] == Backend.uid;
                      return ListTile(
                        leading: Text(
                          '${index + 1}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        title: Text(
                          '${row['nickname']}${yours ? ' · tú' : ''}',
                        ),
                        subtitle: Text(
                          '${row['score']} ${widget.gameId == 'wordlady' ? 'victorias' : 'puntos'}',
                        ),
                        tileColor: yours ? const Color(0xffe1eee7) : null,
                      );
                    },
                  ),
                );
              },
            ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cerrar'),
      ),
    ],
  );
}
