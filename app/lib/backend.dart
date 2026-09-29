import 'package:supabase_flutter/supabase_flutter.dart';

/// Publishable values are safe to ship; database access is enforced by RLS.
/// Load locally with --dart-define-from-file=config.local.json from app/.
class Backend {
  static const url = String.fromEnvironment('SUPABASE_URL');
  static const publishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
  );
  static bool get configured =>
      url.startsWith('https://') &&
      publishableKey.startsWith('sb_publishable_');
  static SupabaseClient get client => Supabase.instance.client;

  static Future<void> initialize() async {
    if (configured) {
      await Supabase.initialize(url: url, publishableKey: publishableKey);
    }
  }

  static Future<Map<String, dynamic>?> membership() async {
    if (!configured || client.auth.currentUser == null) return null;
    final row = await client
        .from('members')
        .select('user_id,space_id,slot,nickname')
        .eq('user_id', client.auth.currentUser!.id)
        .maybeSingle();
    return row;
  }

  static Future<Map<String, dynamic>> activate(
    String code,
    String nickname,
  ) async {
    if (!configured) throw StateError('Supabase no está configurado.');
    if (client.auth.currentUser == null) {
      await client.auth.signInAnonymously();
    }
    await client.rpc(
      'claim_slot',
      params: {'p_code': code.trim(), 'p_nickname': nickname.trim()},
    );
    final member = await membership();
    if (member == null) throw StateError('No pudimos confirmar la activación.');
    return member;
  }

  static Future<List<Map<String, dynamic>>> highscores() async {
    if (!configured || client.auth.currentUser == null) return [];
    final rows = await client
        .from('highscores')
        .select('user_id,game,score,updated_at');
    final members = await client.from('members').select('user_id,nickname');
    final names = {
      for (final member in members) member['user_id']: member['nickname'],
    };
    return [
      for (final row in rows)
        {...row, 'nickname': names[row['user_id']] ?? 'Jugador'},
    ];
  }

  static Stream<List<Map<String, dynamic>>> notes(String spaceId) =>
      client.from('notes').stream(primaryKey: ['id']).eq('space_id', spaceId);

  static Future<String> createNote(
    String spaceId,
    String body,
    double x,
    double y,
  ) async {
    final row = await client
        .from('notes')
        .insert({
          'space_id': spaceId,
          'author_id': client.auth.currentUser!.id,
          'body': body,
          'x': x,
          'y': y,
        })
        .select('id')
        .single();
    return row['id'] as String;
  }

  static Future<void> updateNote(
    String id,
    String body,
    double x,
    double y,
  ) async {
    await client
        .from('notes')
        .update({'body': body, 'x': x, 'y': y})
        .eq('id', id);
  }

  static Future<void> submitHighscore(String game, int score) async {
    if (!configured || client.auth.currentUser == null) return;
    await client.rpc(
      'submit_highscore',
      params: {'p_game': game, 'p_score': score},
    );
  }
}
