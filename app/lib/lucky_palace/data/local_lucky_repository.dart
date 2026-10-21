import 'package:sembast/sembast.dart';
import '../engine/lucky_engine.dart';
import 'lucky_database.dart';
import 'lucky_models.dart';
import 'local_lucky_wallet.dart';

class LocalLuckyRoundRepository implements LuckyRoundRepository {
  LocalLuckyRoundRepository(
    this.storage, {
    LuckyRandom? random,
    this.configId = 'reference25',
  }) : random = random ?? SecureLuckyRandom();
  final LuckyDatabase storage;
  final LuckyRandom random;
  final String configId;
  @override
  LuckyOrigin get origin => LuckyOrigin.local;
  final _wallet = LocalLuckyWallet.record;
  Future<Map<String, dynamic>> _read(Transaction tx) async {
    final wallet = await LocalLuckyWallet.read(tx, configId: configId);
    // Finish any old intent, presentation or bonus with its original pay table.
    if (configId == 'rewards25v2' &&
        wallet['configId'] == 'reference25' &&
        wallet['remaining'] == 0 &&
        wallet['presentationId'] == null &&
        !await luckyRecords.record('local.intent').exists(tx)) {
      wallet['configId'] = configId;
      await _wallet.put(tx, wallet);
    }
    return wallet;
  }

  LuckyWalletSnapshot _snapshot(Map<String, dynamic> j) => LuckyWalletSnapshot(
    origin: origin,
    balance: luckyInt(j['balance']),
    sequence: luckyInt(j['sequence']),
    bonus: readBonus(j),
    configId: j['configId'],
  );
  @override
  Future<LuckyWalletSnapshot> refresh() =>
      storage.transaction((tx) async => _snapshot(await _read(tx)));
  @override
  Future<LuckyRoundIntent> prepare() => storage.transaction((tx) async {
    final pending = await luckyRecords.record('local.intent').get(tx);
    if (pending != null) {
      return LuckyRoundIntent.fromJson(luckyMap(pending['intent']));
    }
    if (await luckyRecords.record('scratch.intent').exists(tx)) {
      throw StateError(
        'Recupera el boleto pendiente en Raspes antes de iniciar otro giro',
      );
    }
    final w = await _read(tx);
    if (w['presentationId'] != null) {
      throw StateError('Presenta u omite la ronda pendiente');
    }
    final rules = luckyRules(w['configId']);
    if (w['remaining'] == 0 && w['balance'] < rules.wager) {
      throw const LuckyDeclined('sin-fichas-locales');
    }
    final intent = LuckyRoundIntent(
      id: luckyId(),
      origin: origin,
      sequence: w['sequence'],
      configId: w['configId'],
      free: w['remaining'] > 0,
    );
    final round = LuckyEngine(rules).spin(random, bonus: readBonus(w));
    await luckyRecords.record('local.intent').put(tx, {
      'intent': intent.toJson(),
      'round': round.toJson(),
      'before': {'remaining': w['remaining'], 'awarded': w['awarded']},
    });
    return intent;
  });
  @override
  Future<LuckyRoundReceipt> execute(LuckyRoundIntent intent) =>
      storage.transaction((tx) async {
        if (intent.origin != origin || intent.ownerUid != null) {
          throw StateError('Procedencia incorrecta');
        }
        final rec = luckyRecords.record('local.receipt.${intent.id}'),
            old = await rec.get(tx);
        if (old != null) {
          if (old['intent'] != luckyJson(intent.toJson())) {
            throw StateError('Colisión de ID');
          }
          return LuckyRoundReceipt.decode(luckyMap(old));
        }
        final prepared = await luckyRecords.record('local.intent').get(tx);
        if (prepared == null ||
            luckyJson(prepared['intent']) != luckyJson(intent.toJson())) {
          throw StateError('Intención no preparada');
        }
        final w = await _read(tx), raw = luckyMap(prepared['round']);
        if (w['sequence'] != intent.sequence) {
          throw StateError('Secuencia incorrecta');
        }
        final cost = luckyInt(raw['simulatedCost']),
            gross = luckyInt(raw['amount']);
        final json = <String, dynamic>{
          'origin': origin.name,
          'id': intent.id,
          'ownerUid': null,
          'configId': intent.configId,
          'cost': cost,
          'gross': gross,
          'net': gross - cost,
          'balance': w['balance'] - cost + gross,
          'round': raw,
          'before': prepared['before'],
          'presentation': 'pending',
          'intent': luckyJson(intent.toJson()),
          'createdAt': DateTime.now().toUtc().toIso8601String(),
        };
        final receipt = LocalLuckyReceipt(json);
        await rec.put(tx, json);
        await _wallet.put(tx, {
          ...w,
          'balance': receipt.balance,
          'sequence': intent.sequence + 1,
          'remaining': receipt.round.after.remaining,
          'awarded': receipt.round.after.awarded,
          'presentationId': intent.id,
        });
        await luckyRecords.record('local.intent').delete(tx);
        return receipt;
      });
  @override
  Future<LuckyRoundReceipt?> recover() async {
    final prepared = await storage.transaction(
      (tx) async => luckyRecords.record('local.intent').get(tx),
    );
    if (prepared != null) {
      return execute(LuckyRoundIntent.fromJson(luckyMap(prepared['intent'])));
    }
    return storage.transaction((tx) async {
      final w = await _read(tx), id = w['presentationId'];
      if (id == null) return null;
      final json = await luckyRecords.record('local.receipt.$id').get(tx);
      if (json == null) {
        throw const FormatException('Falta un recibo; historial conservado');
      }
      return LuckyRoundReceipt.decode(luckyMap(json));
    });
  }

  @override
  Future<void> acknowledge(String id, LuckyPresentation state) =>
      storage.transaction((tx) async {
        final rec = luckyRecords.record('local.receipt.$id'),
            r = await rec.get(tx),
            w = await _read(tx);
        if (r == null) throw StateError('Recibo inexistente');
        await rec.put(tx, {...r, 'presentation': state.name});
        if (w['presentationId'] == id) {
          await _wallet.put(tx, {...w, 'presentationId': null});
        }
      });
  @override
  Future<List<LuckyRoundReceipt>> history() => storage.transaction((tx) async {
    final rows = await luckyRecords.find(
      tx,
      finder: Finder(sortOrders: [SortOrder('createdAt', false)]),
    );
    return rows
        .where((r) => r.key.startsWith('local.receipt.'))
        .map((r) => LuckyRoundReceipt.decode(luckyMap(r.value)))
        .toList();
  });
  Future<void> refill() => storage.transaction((tx) async {
    final w = await _read(tx);
    if (w['remaining'] > 0 || w['balance'] >= luckyRules(w['configId']).wager) {
      return;
    }
    await _wallet.put(tx, {...w, 'balance': w['balance'] + 500});
    await luckyRecords.record('local.refill.${luckyId()}').put(tx, {
      'policy': 'local.economy.v1',
      'amount': 500,
      'balanceBefore': w['balance'],
    });
  });
}
