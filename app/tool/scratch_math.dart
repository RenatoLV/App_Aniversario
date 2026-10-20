import 'dart:convert';
import 'dart:io';
import 'package:nuestro_rincon/lucky_palace/engine/lucky_engine.dart';
import 'package:nuestro_rincon/lucky_palace/scratch/scratch_engine.dart';
import 'package:nuestro_rincon/lucky_palace/scratch/scratch_math.dart';

void main() {
  final d = scratchExactDistribution();
  final total = d.values.fold(0, (a, b) => a + b);
  final expected = d.entries.fold(0, (a, e) => a + e.key * e.value) / total;
  final netWins = d.entries
      .where((e) => e.key > ScratchRules.cost)
      .fold(0, (a, e) => a + e.value);
  final sample = <String, dynamic>{};
  for (final seed in [1, 20261019, 8675309]) {
    final r = LuckySeededRandom(seed);
    var sum = 0, hits = 0, net = 0;
    for (var i = 0; i < 100000; i++) {
      final out = const ScratchEngine().generate(r);
      sum += out.gross;
      if (out.gross > 0) hits++;
      if (out.gross > ScratchRules.cost) net++;
    }
    sample['$seed'] = {
      'tickets': 100000,
      'gross': sum,
      'rtp': sum / (100000 * ScratchRules.cost),
      'hits': hits,
      'netPositive': net,
    };
  }
  final json = {
    'version': ScratchRules.version,
    'cost': ScratchRules.cost,
    'payouts': ScratchRules.payouts,
    'equallyLikelyTickets': total,
    'distribution': d.map((k, v) => MapEntry('$k', v)),
    'expectedGross': expected,
    'rtp': expected / ScratchRules.cost,
    'anyPayoutProbability': 1 - (d[0] ?? 0) / total,
    'netPositiveProbability': netWins / total,
    'maxGross': d.keys.reduce((a, b) => a > b ? a : b),
    'samples': sample,
  };
  File(
    'build/scratch-math.json',
  ).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(json));
  stdout.writeln(const JsonEncoder.withIndent('  ').convert(json));
}
