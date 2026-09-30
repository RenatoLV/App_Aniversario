import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Saved bests are the durable queue; acknowledgements advance only on success.
class HighscoreOutbox {
  HighscoreOutbox(this.prefs);
  final SharedPreferences prefs;

  Map<String, int> get scores {
    final core =
        jsonDecode(prefs.getString('rincon.v1') ?? '{}')
            as Map<String, dynamic>;
    final words =
        jsonDecode(prefs.getString('wordle.v1') ?? '{}')
            as Map<String, dynamic>;
    final candy =
        jsonDecode(prefs.getString('sweet.v1') ?? '{}') as Map<String, dynamic>;
    return {
      'blocks-v1': core['best'] as int? ?? 0,
      'wordlady': words['wins'] as int? ?? 0,
      'candy-churu-cat':
          prefs.getInt('sweet.best') ?? candy['score'] as int? ?? 0,
      'ascenso-maruzon': prefs.getInt('leap.best') ?? 0,
    };
  }

  Future<void> flush(
    String uid,
    Future<void> Function(String, int) submit, {
    required bool Function() isCurrentAccount,
  }) async {
    Object? failure;
    for (final entry in scores.entries) {
      if (!isCurrentAccount()) return;
      final key = 'firebase.score.global.v2.$uid.${entry.key}';
      if (entry.value <= (prefs.getInt(key) ?? 0)) continue;
      try {
        await submit(
          entry.key,
          entry.value,
        ).timeout(const Duration(seconds: 15));
        if (!isCurrentAccount()) return;
        await prefs.setInt(key, entry.value);
      } catch (error) {
        // One pending game must not prevent uploading the other three.
        failure ??= error;
      }
    }
    if (failure != null) throw failure;
  }
}
