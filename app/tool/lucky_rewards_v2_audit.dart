import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:nuestro_rincon/lucky_palace/engine/lucky_engine.dart';
import 'package:nuestro_rincon/lucky_palace/scratch/scratch_engine.dart';
import 'package:nuestro_rincon/lucky_palace/scratch/scratch_math.dart';

void main() {
  final legacy = LuckyEngine(), upgraded = LuckyEngine(LuckyRules.rewardsV2);
  var oldSum = 0, newSum = 0, maxNew = 0, profits = 0, outcomes = 0;
  var maxStops = <int>[];
  final stops = List.filled(5, 0);
  void enumerate(int column) {
    if (column < 5) {
      for (var i = 0; i < 16; i++) {
        stops[column] = i;
        enumerate(column + 1);
      }
      return;
    }
    final old = legacy.evaluateGrid(legacy.gridForStops(stops));
    var next = 0;
    for (final win in old.wins) {
      next +=
          LuckyRules.rewardsV2.payouts[win.symbol]![win.count]! *
          LuckyRules.rewardsV2.lineStake;
    }
    oldSum += old.total;
    newSum += next;
    if (next > maxNew) {
      maxNew = next;
      maxStops = List.from(stops);
    }
    if (next > 25) profits++;
    outcomes++;
  }

  enumerate(0);
  final previous =
      jsonDecode(File('tool/lucky_math_candidate_v1.json').readAsStringSync())
          as Map;
  // Same reels, wager, Scatter/bonus transitions and cap. Wald's identity:
  // E[cycle total] = E[number of draws] * E[draw payout]. Only payouts change.
  final exactRtp = (previous['exactCycleRtp'] as num) * newSum / oldSum;
  final samples = <String, Object>{};
  for (final seed in [1, 20261019, 8675309]) {
    final rng = LuckySeededRandom(seed);
    var sum = 0, positive = 0, maxCycle = 0;
    for (var i = 0; i < 100000; i++) {
      var round = upgraded.spin(rng);
      var gross = round.evaluation.total;
      while (round.after.remaining > 0) {
        round = upgraded.spin(rng, bonus: round.after);
        gross += round.evaluation.total;
      }
      sum += gross;
      if (gross > 25) positive++;
      maxCycle = math.max(maxCycle, gross);
    }
    samples['$seed'] = {
      'cycles': 100000,
      'rtp': sum / 2500000,
      'netPositive': positive,
      'observedMaxCycle': maxCycle,
    };
  }
  final scratch = scratchExactDistribution(
    rulesVersion: ScratchRules.enhancedVersion,
  );
  final count = scratch.values.fold(0, (a, b) => a + b);
  final gross = scratch.entries.fold(0, (a, e) => a + e.key * e.value) / count;
  final report = {
    'slots': {
      'version': LuckyRules.rewardsV2.rulesVersion,
      'outcomes': outcomes,
      'oldGrossSum': oldSum,
      'newGrossSum': newSum,
      'exactCycleRtp': exactRtp,
      'netPositivePerDraw': profits / outcomes,
      'maxReachableDraw': maxNew,
      'maxStops': maxStops,
      'samples': samples,
    },
    'scratch': {
      'version': ScratchRules.enhancedVersion,
      'outcomes': count,
      'expectedGross': gross,
      'rtp': gross / 10,
      'netPositive':
          scratch.entries
              .where((e) => e.key > 10)
              .fold(0, (a, e) => a + e.value) /
          count,
      'maxGross': scratch.keys.reduce(math.max),
      'distribution': scratch.map((k, v) => MapEntry('$k', v)),
    },
  };
  Directory('build').createSync(recursive: true);
  final json = const JsonEncoder.withIndent('  ').convert(report);
  File('build/lucky-rewards-v2-audit.json').writeAsStringSync(json);
  stdout.writeln(json);
}
