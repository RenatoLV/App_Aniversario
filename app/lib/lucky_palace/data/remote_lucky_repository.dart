import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:sembast/sembast.dart';
import 'lucky_database.dart';
import 'lucky_models.dart';

typedef LuckyRemoteCall =
    Future<Map<String, dynamic>> Function(Map<String, dynamic> request);

class LuckySandboxTransport {
  LuckySandboxTransport({
    required this.endpoint,
    required this.ownerUid,
    required this.currentUid,
    required this.token,
    http.Client? client,
  }) : client = client ?? http.Client() {
    final h = endpoint.host;
    if (endpoint.scheme != 'http' ||
        endpoint.path != '/demo-lucky-readiness/us-central1/economyV2' ||
        !RegExp(
          r'^(localhost|127\.0\.0\.1|10\.(\d{1,3}\.){2}\d{1,3}|192\.168\.\d{1,3}\.\d{1,3}|172\.(1[6-9]|2\d|3[01])\.\d{1,3}\.\d{1,3})$',
        ).hasMatch(h)) {
      throw ArgumentError('Solo emuladores demo en una red privada');
    }
  }
  final Uri endpoint;
  final String ownerUid;
  final String? Function() currentUid;
  final Future<String> Function() token;
  final http.Client client;
  Future<Map<String, dynamic>> call(Map<String, dynamic> request) async {
    if (currentUid() != ownerUid) throw const LuckyDeclined('cuenta-cambiada');
    final bearer = await token();
    if (currentUid() != ownerUid) throw const LuckyDeclined('cuenta-cambiada');
    final response = await client
        .post(
          endpoint,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $bearer',
          },
          body: jsonEncode(request),
        )
        .timeout(const Duration(seconds: 10));
    if (currentUid() != ownerUid) throw const LuckyDeclined('cuenta-cambiada');
    if ([429, 503].contains(response.statusCode)) throw const LuckyUncertain();
    if (response.statusCode == 404) {
      throw const LuckyDeclined('operation-not-found');
    }
    if (response.statusCode != 200) {
      throw LuckyDeclined('HTTP ${response.statusCode}');
    }
    return luckyMap(jsonDecode(response.body));
  }
}

class RemoteLuckyRoundRepository implements LuckyRoundRepository {
  RemoteLuckyRoundRepository({
    required this.storage,
    required this.ownerUid,
    required this.call,
    this.configId = 'reference25',
  });
  final LuckyDatabase storage;
  final String ownerUid, configId;
  final LuckyRemoteCall call;
  @override
  LuckyOrigin get origin => LuckyOrigin.sandbox;
  String get _prefix => 'sandbox.$ownerUid';
  Future<Map<String, dynamic>> _call(
    String action, [
    Map<String, dynamic> params = const {},
  ]) => call({'action': action, 'expectedOwnerUid': ownerUid, ...params});
  @override
  Future<LuckyWalletSnapshot> refresh() async {
    final w = luckyMap((await _call('getWallet'))['wallet']);
    final s = luckyMap((await _call('getCasinoState'))['state']);
    if (w['ownerUid'] != ownerUid ||
        w['currency'] != 'sandboxVerifiedCoins' ||
        luckyInt(w['balance']) < 0) {
      throw const FormatException('Cartera ajena o inválida');
    }
    final b = s['bonus'];
    return LuckyWalletSnapshot(
      origin: origin,
      ownerUid: ownerUid,
      balance: w['balance'],
      sequence: luckyInt(s['sequence']),
      bonus: readBonus(b),
      configId: b == null ? configId : luckyMap(b)['configId'],
    );
  }

  @override
  Future<LuckyRoundIntent> prepare() async {
    final old = await storage.transaction(
      (tx) async => luckyRecords.record('$_prefix.intent').get(tx),
    );
    if (old != null) return LuckyRoundIntent.fromJson(luckyMap(old));
    final w = await refresh();
    return storage.transaction((tx) async {
      final pending = await luckyRecords.record('$_prefix.intent').get(tx);
      if (pending != null) return LuckyRoundIntent.fromJson(luckyMap(pending));
      final active = await luckyRecords.record('$_prefix.active').get(tx);
      if (active != null) {
        throw StateError('Hay un recibo pendiente de presentación');
      }
      final intent = LuckyRoundIntent(
        id: luckyId(),
        origin: origin,
        ownerUid: ownerUid,
        sequence: w.sequence,
        configId: w.configId,
        free: w.bonus.remaining > 0,
      );
      await luckyRecords.record('$_prefix.intent').put(tx, intent.toJson());
      return intent;
    });
  }

  ServerLuckyReceipt _decode(
    Map<String, dynamic> raw, {
    LuckyPresentation presentation = LuckyPresentation.pending,
  }) {
    if (raw['ownerUid'] != ownerUid || raw['status'] != 'committed') {
      throw const FormatException('Recibo de otra cuenta o no confirmado');
    }
    final result = luckyMap(raw['result']), r = luckyMap(result['round']);
    final cost = luckyInt(raw['chargedCost']),
        gross = luckyInt(raw['grossPrize']),
        after = luckyInt(raw['balanceAfter']);
    if (after != luckyInt(raw['balanceBefore']) - cost + gross ||
        luckyInt(raw['revisionAfter']) != luckyInt(raw['revisionBefore']) + 1) {
      throw const FormatException('Saldo remoto inconsistente');
    }
    return ServerLuckyReceipt({
      'origin': origin.name,
      'ownerUid': ownerUid,
      'id': raw['operationId'],
      'configId': result['configId'],
      'cost': cost,
      'gross': gross,
      'net': raw['netDelta'],
      'balance': after,
      'round': r,
      'before': result['bonusBefore'],
      'presentation': presentation.name,
      'createdAt': raw['createdAt'],
    });
  }

  Future<LuckyRoundReceipt> _accept(
    Map<String, dynamic> raw,
    LuckyRoundIntent intent, {
    LuckyPresentation presentation = LuckyPresentation.pending,
  }) async {
    if (raw['ownerUid'] != ownerUid ||
        raw['operationId'] != intent.id ||
        raw['action'] != intent.request['action']) {
      throw const FormatException('Identidad de recibo inválida');
    }
    if (raw['status'] == 'declined') {
      await storage.transaction((tx) async {
        await luckyRecords
            .record('$_prefix.declined.${intent.id}')
            .put(tx, raw);
        await luckyRecords.record('$_prefix.intent').delete(tx);
      });
      throw LuckyDeclined(raw['code']);
    }
    final receipt = _decode(raw, presentation: presentation);
    if (luckyMap(raw['result'])['sequenceBefore'] != intent.sequence ||
        receipt.json['configId'] != intent.configId ||
        receipt.round.freeSpin != intent.free) {
      throw const FormatException('Resultado no corresponde a la intención');
    }
    await storage.transaction((tx) async {
      await luckyRecords
          .record('$_prefix.receipt.${receipt.id}')
          .put(tx, receipt.json);
      if (presentation == LuckyPresentation.pending) {
        await luckyRecords.record('$_prefix.active').put(tx, {
          'id': receipt.id,
        });
      }
      await luckyRecords.record('$_prefix.intent').delete(tx);
    });
    return receipt;
  }

  @override
  Future<LuckyRoundReceipt> execute(LuckyRoundIntent intent) async {
    if (intent.origin != origin || intent.ownerUid != ownerUid) {
      throw StateError('Intención ajena');
    }
    final persisted = await storage.transaction(
      (tx) async => luckyRecords.record('$_prefix.intent').get(tx),
    );
    if (persisted == null ||
        luckyJson(persisted) != luckyJson(intent.toJson())) {
      throw StateError('La intención debe estar persistida');
    }
    try {
      return await _accept(
        luckyMap((await call(intent.request))['receipt']),
        intent,
      );
    } on LuckyDeclined {
      rethrow;
    } catch (_) {
      throw const LuckyUncertain();
    }
  }

  @override
  Future<LuckyRoundReceipt?> recover() async {
    final pending = await storage.transaction(
      (tx) async => luckyRecords.record('$_prefix.intent').get(tx),
    );
    if (pending != null) {
      final intent = LuckyRoundIntent.fromJson(luckyMap(pending));
      try {
        final response = await _call('getOperation', {
          'operationId': intent.id,
          'includePresentation': true,
        });
        return await _accept(
          luckyMap(response['receipt']),
          intent,
          presentation: LuckyPresentation.values.byName(
            response['presentation'] ?? 'pending',
          ),
        );
      } on LuckyDeclined catch (e) {
        if (e.code != 'operation-not-found') rethrow;
        return execute(intent);
      }
    }
    final active = await storage.transaction(
      (tx) async => luckyRecords.record('$_prefix.active').get(tx),
    );
    if (active != null) {
      final raw = await _call('getOperation', {
        'operationId': active['id'],
        'includePresentation': true,
      });
      final presentation = LuckyPresentation.values.byName(
        raw['presentation'] ?? 'pending',
      );
      if (presentation == LuckyPresentation.pending) {
        return _decode(luckyMap(raw['receipt']));
      }
      await storage.transaction(
        (tx) async => luckyRecords.record('$_prefix.active').delete(tx),
      );
    }
    // Also reconstruct pending presentations if the local visual cache was lost.
    String? cursor;
    do {
      final page = await _call('history', {
        'limit': 50,
        'includePresentation': true,
        'cursor': ?cursor,
      });
      for (final value in page['receipts'] as List) {
        final raw = luckyMap(value);
        if (raw['status'] == 'committed' &&
            raw['result'] is Map &&
            luckyMap(raw['result']).containsKey('round') &&
            luckyMap(page['presentations'])[raw['operationId']] == 'pending') {
          final receipt = _decode(raw);
          await storage.transaction((tx) async {
            await luckyRecords
                .record('$_prefix.receipt.${receipt.id}')
                .put(tx, receipt.json);
            await luckyRecords.record('$_prefix.active').put(tx, {
              'id': receipt.id,
            });
          });
          return receipt;
        }
      }
      cursor = page['nextCursor'] as String?;
    } while (cursor != null);
    return null;
  }

  @override
  Future<void> acknowledge(String id, LuckyPresentation state) async {
    await _call('ackPresentation', {'operationId': id, 'status': state.name});
    await storage.transaction((tx) async {
      final rec = luckyRecords.record('$_prefix.receipt.$id'),
          old = await rec.get(tx);
      if (old != null) await rec.put(tx, {...old, 'presentation': state.name});
      final active = await luckyRecords.record('$_prefix.active').get(tx);
      if (active?['id'] == id) {
        await luckyRecords.record('$_prefix.active').delete(tx);
      }
    });
  }

  @override
  Future<List<LuckyRoundReceipt>> history() async {
    final page = await _call('history', {
      'limit': 50,
      'includePresentation': true,
    });
    return (page['receipts'] as List)
        .map(luckyMap)
        .where(
          (r) =>
              r['status'] == 'committed' &&
              luckyMap(r['result']).containsKey('round'),
        )
        .map(
          (r) => _decode(
            r,
            presentation: LuckyPresentation.values.byName(
              luckyMap(page['presentations'])[r['operationId']] ?? 'pending',
            ),
          ),
        )
        .toList();
  }
}
