import 'package:sembast/sembast.dart';
import 'lucky_database.dart';
import 'lucky_models.dart';

/// One wallet record for all local casino games. Existing v1 fields are retained.
class LocalLuckyWallet {
  static final record = luckyRecords.record('local.wallet');
  static Future<Map<String, dynamic>> read(
    Transaction tx, {
    String configId = 'reference25',
  }) async {
    final old = await record.get(tx);
    if (old != null) {
      if (old['schema'] != 1 ||
          old['policy'] != 'local.economy.v1' ||
          luckyInt(old['balance']) < 0) {
        throw const FormatException(
          'Base local incompatible o corrupta; no se ha borrado',
        );
      }
      return Map<String, dynamic>.from(old);
    }
    final fresh = <String, dynamic>{
      'schema': 1,
      'policy': 'local.economy.v1',
      'balance': 500,
      'sequence': 0,
      'remaining': 0,
      'awarded': 0,
      'configId': configId,
      'presentationId': null,
    };
    await record.put(tx, fresh);
    return fresh;
  }
}
