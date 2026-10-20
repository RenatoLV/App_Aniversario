import 'package:sembast/sembast.dart';
import '../data/lucky_database.dart';
import '../data/lucky_models.dart';
import '../data/local_lucky_wallet.dart';
import '../engine/lucky_engine.dart';
import 'scratch_catalog.dart';
import 'scratch_engine.dart';
import 'scratch_mask.dart';
import 'scratch_models.dart';

class ScratchLocalRepository {
  ScratchLocalRepository(this.storage, {LuckyRandom? random})
    : random = random ?? SecureLuckyRandom();
  final LuckyDatabase storage;
  final LuckyRandom random;
  Future<int> balance() => storage.transaction(
    (tx) async => (await LocalLuckyWallet.read(tx))['balance'] as int,
  );
  Future<ScratchReceipt> _receipt(Transaction tx, String id) async {
    final raw = await luckyRecords.record('scratch.receipt.$id').get(tx);
    final visual = await luckyRecords.record('scratch.visual.$id').get(tx);
    if (raw == null || visual == null) {
      throw const FormatException(
        'Falta un recibo o su máscara; historial conservado',
      );
    }
    if (visual['version'] != 1 || visual['revealed'] is! bool) {
      throw const FormatException('Estado visual incompatible');
    }
    return ScratchReceipt(
      luckyMap(raw),
      mask: ScratchMask.decode(visual['mask'] as String),
      revealed: visual['revealed'] as bool,
    );
  }

  /// Persist a single immutable outcome before committing finance/presentation.
  Future<String> prepare(String themeId, String operationId) =>
      storage.transaction((tx) async {
        ScratchTheme.byId(themeId);
        if (operationId.isEmpty ||
            operationId.length > 100 ||
            !RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(operationId)) {
          throw StateError('ID inválido');
        }
        final old = await luckyRecords
            .record('scratch.receipt.$operationId')
            .get(tx);
        if (old != null) {
          if (old['themeId'] != themeId) throw StateError('Colisión de ID');
          return operationId;
        }
        final intent = await luckyRecords.record('scratch.intent').get(tx);
        if (intent != null) {
          if (intent['id'] != operationId || intent['themeId'] != themeId) {
            throw StateError('Recupera el boleto preparado');
          }
          return operationId;
        }
        if (await luckyRecords.record('local.intent').exists(tx)) {
          throw StateError('Recupera primero el giro pendiente de Lucky 777');
        }
        final active = await luckyRecords.record('scratch.active').get(tx);
        if (active != null &&
            !(await _receipt(tx, active['id'] as String)).revealed) {
          throw StateError('Termina el boleto actual antes de abrir otro');
        }
        final wallet = await LocalLuckyWallet.read(tx);
        if (wallet['balance'] < ScratchRules.cost) {
          throw const LuckyDeclined('sin-fichas-locales');
        }
        final outcome = const ScratchEngine().generate(random);
        await luckyRecords.record('scratch.intent').put(tx, {
          'id': operationId,
          'themeId': themeId,
          'rules': ScratchRules.version,
          'cells': outcome.cells,
        });
        return operationId;
      });
  Future<ScratchReceipt> execute(String id) => storage.transaction((tx) async {
    if (await luckyRecords.record('scratch.receipt.$id').exists(tx)) {
      return _receipt(tx, id);
    }
    final intent = await luckyRecords.record('scratch.intent').get(tx);
    if (intent == null ||
        intent['id'] != id ||
        intent['rules'] != ScratchRules.version) {
      throw StateError('Boleto no preparado');
    }
    final wallet = await LocalLuckyWallet.read(tx);
    if (wallet['balance'] < ScratchRules.cost) {
      throw const LuckyDeclined('sin-fichas-locales');
    }
    final outcome = ScratchOutcome(List<int>.from(intent['cells'] as List));
    final receipt = ScratchReceipt({
      'id': id,
      'origin': 'local',
      'themeId': intent['themeId'],
      'rules': ScratchRules.version,
      'cost': ScratchRules.cost,
      'cells': outcome.cells,
      'gross': outcome.gross,
      'net': outcome.gross - ScratchRules.cost,
      'balanceBefore': wallet['balance'],
      'balance': wallet['balance'] - ScratchRules.cost + outcome.gross,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
    });
    await LocalLuckyWallet.record.put(tx, {
      ...wallet,
      'balance': receipt.balance,
    });
    await luckyRecords.record('scratch.receipt.$id').put(tx, receipt.data);
    await luckyRecords.record('scratch.visual.$id').put(tx, {
      'version': 1,
      'mask': receipt.mask.encode(),
      'revealed': false,
    });
    await luckyRecords.record('scratch.active').put(tx, {'id': id});
    await luckyRecords.record('scratch.intent').delete(tx);
    return receipt;
  });
  Future<ScratchReceipt?> recover() async {
    final prepared = await storage.transaction(
      (tx) async => luckyRecords.record('scratch.intent').get(tx),
    );
    if (prepared != null) return execute(prepared['id'] as String);
    return storage.transaction((tx) async {
      final active = await luckyRecords.record('scratch.active').get(tx);
      return active == null ? null : _receipt(tx, active['id'] as String);
    });
  }

  Future<ScratchReceipt> saveVisual(
    String id,
    ScratchMask mask, {
    bool reveal = false,
  }) => storage.transaction((tx) async {
    final old = await _receipt(tx, id);
    final merged = old.mask.copy()..merge(mask);
    await luckyRecords.record('scratch.visual.$id').put(tx, {
      'version': 1,
      'mask': merged.encode(),
      'revealed': old.revealed || reveal,
    });
    return ScratchReceipt(
      old.data,
      mask: merged,
      revealed: old.revealed || reveal,
    );
  });
  Future<List<ScratchReceipt>> history() => storage.transaction((tx) async {
    final records = await luckyRecords.find(
      tx,
      finder: Finder(sortOrders: [SortOrder('createdAt', false)]),
    );
    final rows = <ScratchReceipt>[];
    for (final r in records) {
      if (r.key.startsWith('scratch.receipt.')) {
        rows.add(await _receipt(tx, r.value['id'] as String));
      }
    }
    return rows;
  });
}
