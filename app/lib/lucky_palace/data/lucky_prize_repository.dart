import 'package:sembast/sembast.dart';
import '../lucky_prizes.dart';
import 'lucky_database.dart';
import 'local_lucky_wallet.dart';

class LuckyPrizeProgress {
  const LuckyPrizeProgress(this.balance, this.games, this.claimed);
  final int balance, games;
  final Set<String> claimed;
}

/// Debit and permanent entitlement share a transaction; delivery is retryable.
class LuckyPrizeRepository {
  LuckyPrizeRepository(this.storage, this.owner);
  final LuckyDatabase storage;
  final String owner;
  String get _prefix => 'prize.claim.${Uri.encodeComponent(owner)}.';

  Future<LuckyPrizeProgress> _progress(Transaction tx) async {
    final wallet = await LocalLuckyWallet.read(tx);
    final rows = await luckyRecords.find(tx);
    final revealed = {
      for (final row in rows)
        if (row.key.startsWith('scratch.visual.') &&
            row.value['revealed'] == true)
          row.key.substring('scratch.visual.'.length),
    };
    var games = 0;
    final claimed = <String>{};
    for (final row in rows) {
      if (row.key.startsWith('local.receipt.') &&
          (row.value['cost'] as num) > 0) {
        games++;
      } else if (row.key.startsWith('scratch.receipt.') &&
          revealed.contains(row.key.substring('scratch.receipt.'.length))) {
        games++;
      } else if (row.key.startsWith(_prefix)) {
        claimed.add(row.key.substring(_prefix.length));
      }
    }
    return LuckyPrizeProgress(wallet['balance'] as int, games, claimed);
  }

  Future<LuckyPrizeProgress> progress() => storage.transaction(_progress);

  Future<void> redeem(String prizeId) => storage.transaction((tx) async {
    final prize = luckyPrize(prizeId);
    final receipt = luckyRecords.record('$_prefix$prizeId');
    if (await receipt.exists(tx)) return;
    final progress = await _progress(tx);
    if (progress.games < prize.games) {
      throw StateError('Faltan partidas para este premio.');
    }
    if (progress.balance < prize.cost) {
      throw StateError('No tienes suficientes fichas.');
    }
    if (await luckyRecords.record('local.intent').exists(tx) ||
        await luckyRecords.record('scratch.intent').exists(tx)) {
      throw StateError('Recupera la partida pendiente antes de canjear.');
    }
    final wallet = await LocalLuckyWallet.read(tx);
    await LocalLuckyWallet.record.put(tx, {
      ...wallet,
      'balance': progress.balance - prize.cost,
    });
    await receipt.put(tx, {
      'prize': prize.id,
      'owner': owner,
      'cost': prize.cost,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
    });
  });
}
