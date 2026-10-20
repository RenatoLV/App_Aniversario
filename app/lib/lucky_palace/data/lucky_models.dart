import 'dart:convert';
import 'dart:math';
import '../engine/lucky_engine.dart';

enum LuckyOrigin { local, sandbox }

enum LuckyPresentation { pending, seen, skipped }

String luckyId() => List.generate(
  16,
  (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'),
).join();
LuckyRules luckyRules(String config) {
  final a = LuckyRules.candidate;
  if (config == 'reference25') return a;
  if (config != 'scaled10') {
    throw const FormatException('Configuración desconocida');
  }
  return LuckyRules(
    catalogVersion: a.catalogVersion,
    rulesVersion: 'lucky777.rules.audit.stake10.v1',
    reels: a.reels,
    payouts: a.payouts,
    lines: a.lines,
    lineStake: 2,
  );
}

class SecureLuckyRandom implements LuckyRandom {
  final Random _random = Random.secure();
  @override
  int nextInt(int max) => _random.nextInt(max);
}

Map<String, dynamic> luckyMap(Object? value) =>
    Map<String, dynamic>.from(value as Map);
int luckyInt(Object? value) {
  if (value is! int || value.abs() > 9007199254740991) {
    throw const FormatException('Entero inválido');
  }
  return value;
}

LuckyBonusState readBonus(Object? data) => data == null
    ? const LuckyBonusState()
    : LuckyBonusState(
        remaining: luckyInt(luckyMap(data)['remaining']),
        awarded: luckyInt(luckyMap(data)['awarded']),
      );
bool _equal(Object? a, Object? b) {
  if (a is Map && b is Map) {
    return a.length == b.length &&
        a.keys.every((k) => b.containsKey(k) && _equal(a[k], b[k]));
  }
  if (a is List && b is List) {
    return a.length == b.length &&
        List.generate(a.length, (i) => i).every((i) => _equal(a[i], b[i]));
  }
  return a == b;
}

class LuckyWalletSnapshot {
  const LuckyWalletSnapshot({
    required this.origin,
    required this.balance,
    required this.sequence,
    required this.bonus,
    this.ownerUid,
    this.configId = 'reference25',
  });
  final LuckyOrigin origin;
  final int balance, sequence;
  final LuckyBonusState bonus;
  final String? ownerUid;
  final String configId;
  String get currency =>
      origin == LuckyOrigin.local ? 'Fichas locales' : 'Monedas sintéticas V2';
}

class LuckyRoundIntent {
  LuckyRoundIntent({
    required this.id,
    required this.origin,
    required this.sequence,
    required this.configId,
    required this.free,
    this.ownerUid,
  });
  final String id, configId;
  final String? ownerUid;
  final LuckyOrigin origin;
  final int sequence;
  final bool free;
  Map<String, dynamic> toJson() => {
    'id': id,
    'origin': origin.name,
    'sequence': sequence,
    'configId': configId,
    'free': free,
    'ownerUid': ownerUid,
  };
  factory LuckyRoundIntent.fromJson(Map<String, dynamic> j) => LuckyRoundIntent(
    id: j['id'] as String,
    origin: LuckyOrigin.values.byName(j['origin']),
    sequence: luckyInt(j['sequence']),
    configId: j['configId'],
    free: j['free'],
    ownerUid: j['ownerUid'],
  );
  Map<String, dynamic> get request => {
    'action': free ? 'consumeFreeSpin' : 'requestSpin',
    'expectedOwnerUid': ownerUid,
    'operationId': id,
    'sequence': sequence,
    if (!free) 'configId': configId,
  };
}

sealed class LuckyRoundReceipt {
  LuckyRoundReceipt(this.json) {
    final j = json;
    final rules = luckyRules(j['configId']);
    final raw = luckyMap(j['round']);
    round = LuckyEngine(rules).evaluateStops(
      List<int>.from(raw['stops']),
      bonus: readBonus(j['before']),
    );
    if (!_equal(round.toJson(), raw) ||
        luckyInt(j['gross']) != round.evaluation.total ||
        luckyInt(j['cost']) != round.simulatedCost ||
        luckyInt(j['net']) != j['gross'] - j['cost'] ||
        luckyInt(j['balance']) < 0) {
      throw const FormatException('Recibo inconsistente');
    }
  }
  final Map<String, dynamic> json;
  late final LuckyRound round;
  LuckyOrigin get origin;
  String get id => json['id'];
  int get balance => json['balance'];
  int get gross => json['gross'];
  int get cost => json['cost'];
  int get net => json['net'];
  LuckyPresentation get presentation =>
      LuckyPresentation.values.byName(json['presentation']);
  String? get ownerUid => json['ownerUid'];
  static LuckyRoundReceipt decode(Map<String, dynamic> json) =>
      switch (json['origin']) {
        'local' => LocalLuckyReceipt(json),
        'sandbox' => ServerLuckyReceipt(json),
        _ => throw const FormatException('Procedencia inválida'),
      };
}

final class LocalLuckyReceipt extends LuckyRoundReceipt {
  LocalLuckyReceipt(super.json) {
    if (this.json['origin'] != 'local' || this.json['ownerUid'] != null) {
      throw const FormatException(
        'Un recibo local no puede representar una cartera V2',
      );
    }
  }
  @override
  LuckyOrigin get origin => LuckyOrigin.local;
}

final class ServerLuckyReceipt extends LuckyRoundReceipt {
  ServerLuckyReceipt(super.json) {
    if (this.json['origin'] != 'sandbox' ||
        this.json['ownerUid'] is! String ||
        (this.json['ownerUid'] as String).isEmpty) {
      throw const FormatException('Falta procedencia de servidor');
    }
  }
  @override
  LuckyOrigin get origin => LuckyOrigin.sandbox;
}

abstract interface class LuckyRoundRepository {
  LuckyOrigin get origin;
  Future<LuckyWalletSnapshot> refresh();
  Future<LuckyRoundIntent> prepare();
  Future<LuckyRoundReceipt> execute(LuckyRoundIntent intent);
  Future<LuckyRoundReceipt?> recover();
  Future<List<LuckyRoundReceipt>> history();
  Future<void> acknowledge(String id, LuckyPresentation state);
}

class LuckyDeclined implements Exception {
  const LuckyDeclined(this.code);
  final String code;
  @override
  String toString() => 'Operación rechazada: $code';
}

class LuckyUncertain implements Exception {
  const LuckyUncertain();
  @override
  String toString() => 'Comprobando resultado…';
}

Object? _canonical(Object? value) {
  if (value is Map) {
    final keys = value.keys.cast<String>().toList()..sort();
    return {for (final key in keys) key: _canonical(value[key])};
  }
  if (value is List) return value.map(_canonical).toList();
  return value;
}

String luckyJson(Object? value) => jsonEncode(_canonical(value));
