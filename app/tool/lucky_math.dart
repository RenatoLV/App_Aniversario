import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:nuestro_rincon/lucky_palace/engine/lucky_engine.dart';

/// Pure Dart CLI. Enumerates the finite stop space, then independent paid cycles.
void main(List<String> args) {
  final samples = args.isEmpty ? 100000 : int.parse(args[0]);
  if (samples < 2) throw ArgumentError('At least two paid cycles required');
  final seed = args.length > 1 ? int.parse(args[1]) : 20261019;
  final engine = LuckyEngine(), rules = LuckyRules.candidate;
  final watch = Stopwatch()..start();
  final counts = List<int>.filled(6, 0),
      sums = List<double>.filled(6, 0),
      squares = List<double>.filled(6, 0),
      zeros = List<int>.filled(6, 0),
      maxima = List<int>.filled(6, 0);
  var states = 0, hits = 0, maxRound = 0;
  var maxStops = <int>[];
  final stops = List<int>.filled(5, 0);
  void enumerate(int column) {
    if (column < 5) {
      for (var i = 0; i < rules.reels[column].length; i++) {
        stops[column] = i;
        enumerate(column + 1);
      }
      return;
    }
    final e = engine.evaluateGrid(engine.gridForStops(stops));
    final amount = e.total, scatters = e.scatterColumns.length;
    states++;
    counts[scatters]++;
    sums[scatters] += amount;
    maxima[scatters] = math.max(maxima[scatters], amount);
    squares[scatters] += amount * amount;
    if (amount > 0) {
      hits++;
    } else {
      zeros[scatters]++;
    }
    if (amount > maxRound) {
      maxRound = amount;
      maxStops = List.of(stops);
    }
  }

  enumerate(0);
  final mean = sums.reduce((a, b) => a + b) / states;
  final second = squares.reduce((a, b) => a + b) / states;
  final memo = <(int, int), (double, double, double, double)>{};
  // Markov reward recurrence retains payout/Scatter correlation in each round.
  (double, double, double, double) future(int remaining, int awarded) {
    if (remaining == 0) return (0, 0, 0, 1);
    final key = (remaining, awarded);
    if (memo.containsKey(key)) return memo[key]!;
    var m = mean, s = second, duration = 1.0, zero = 0.0;
    for (var c = 0; c <= 5; c++) {
      if (counts[c] == 0) continue;
      final grant = math.min(
        rules.scatterAwards[c] ?? 0,
        rules.maxBonusSpins - awarded,
      );
      final next = future(remaining - 1 + grant, awarded + grant);
      final prob = counts[c] / states;
      m += prob * next.$1;
      s += 2 * sums[c] / states * next.$1 + prob * next.$2;
      duration += prob * next.$3;
      zero += zeros[c] / states * next.$4;
    }
    return memo[key] = (m, s, duration, zero);
  }

  var cycleMean = mean, cycleSecond = second, freeMean = 0.0, trigger = 0.0;
  for (var c = 3; c <= 5; c++) {
    final grant = math.min(rules.scatterAwards[c] ?? 0, rules.maxBonusSpins);
    final f = future(grant, grant), prob = counts[c] / states;
    trigger += prob;
    cycleMean += prob * f.$1;
    cycleSecond += 2 * sums[c] / states * f.$1 + prob * f.$2;
    freeMean += prob * f.$3;
  }
  var cycleZero = 0.0;
  for (var c = 0; c <= 5; c++) {
    final grant = math.min(rules.scatterAwards[c] ?? 0, rules.maxBonusSpins);
    cycleZero += zeros[c] / states * future(grant, grant).$4;
  }
  final maxMemo = <(int, int), int>{};
  int maximumFuture(int remaining, int awarded) {
    if (remaining == 0) return 0;
    final key = (remaining, awarded);
    if (maxMemo.containsKey(key)) return maxMemo[key]!;
    var best = 0;
    for (var c = 0; c <= 5; c++) {
      if (counts[c] == 0) continue;
      final grant = math.min(
        rules.scatterAwards[c] ?? 0,
        rules.maxBonusSpins - awarded,
      );
      best = math.max(
        best,
        maxima[c] + maximumFuture(remaining - 1 + grant, awarded + grant),
      );
    }
    return maxMemo[key] = best;
  }

  var cycleMax = 0;
  for (var c = 0; c <= 5; c++) {
    if (counts[c] == 0) continue;
    final grant = math.min(rules.scatterAwards[c] ?? 0, rules.maxBonusSpins);
    cycleMax = math.max(cycleMax, maxima[c] + maximumFuture(grant, grant));
  }
  final rng = LuckySeededRandom(seed);
  var total = 0.0,
      totalSquare = 0.0,
      freeCount = 0,
      cycleHits = 0,
      profitCycles = 0,
      breakEvenCycles = 0,
      maxCycle = 0,
      maxFree = 0,
      retriggers = 0,
      capped = 0;
  final durations = <int>[];
  for (var i = 0; i < samples; i++) {
    var round = engine.spin(rng), payout = round.evaluation.total, free = 0;
    final triggered = round.after.remaining > 0;
    while (round.after.remaining > 0) {
      round = engine.spin(rng, bonus: round.after);
      free++;
      payout += round.evaluation.total;
      if (round.grantedSpins > 0) retriggers++;
      if (free > rules.maxBonusSpins) throw StateError('Unbounded bonus');
    }
    if (round.after.awarded == rules.maxBonusSpins) capped++;
    if (triggered) durations.add(free);
    total += payout;
    totalSquare += payout * payout;
    freeCount += free;
    if (payout > 0) cycleHits++;
    if (payout > rules.wager) profitCycles++;
    if (payout == rules.wager) breakEvenCycles++;
    maxCycle = math.max(maxCycle, payout);
    maxFree = math.max(maxFree, free);
  }
  durations.sort();
  final sampleMean = total / samples;
  final variance = (totalSquare - total * total / samples) / (samples - 1);
  final se = math.sqrt(variance / samples) / rules.wager;
  final data = <String, Object>{
    'catalogVersion': rules.catalogVersion,
    'rulesVersion': rules.rulesVersion,
    'rng': 'Park-Miller 48271 + rejection',
    'seed': seed,
    'paidCycles': samples,
    'wager': rules.wager,
    'lineStake': rules.lineStake,
    'exactStops': states,
    'exactRoundMean': mean,
    'exactRoundHitRate': hits / states,
    'exactScatterCounts': counts,
    'exactTriggerProbability': trigger,
    'exactPaidCycleHitRate': 1 - cycleZero,
    'exactCycleRtp': cycleMean / rules.wager,
    'exactCycleVariance': cycleSecond - cycleMean * cycleMean,
    'exactFreeSpinsPerPaidCycle': freeMean,
    'exactMeanBonusLengthConditional': freeMean / trigger,
    'exactReachableCycleMax': cycleMax,
    'roundMaxByScatterColumns': maxima,
    'paytableMultipliers': {
      for (final e in rules.payouts.entries)
        e.key.name: {for (final p in e.value.entries) '${p.key}': p.value},
    },
    'reels': rules.reels.map((r) => r.map((s) => s.name).toList()).toList(),
    'lines': {for (final l in rules.lines) l.id: l.rows},
    'reachableRoundMax': maxRound,
    'maxRoundStops': maxStops,
    'arbitraryGridRoundBound': rules.theoreticalRoundMax,
    'conservativeCycleBound': maxRound * (rules.maxBonusSpins + 1),
    'sampleCycleRtp': sampleMean / rules.wager,
    'sampleRtp95Low': sampleMean / rules.wager - 1.96 * se,
    'sampleRtp95High': sampleMean / rules.wager + 1.96 * se,
    'sampleNetProfitRate': profitCycles / samples,
    'sampleBreakEvenRate': breakEvenCycles / samples,
    'samplePaidCycleHitRate': cycleHits / samples,
    'sampleFreeSpins': freeCount,
    'sampleRetriggers': retriggers,
    'sampleCappedCycles': capped,
    'sampleMaxCycle': maxCycle,
    'sampleMaxFreeSpins': maxFree,
    'sampleBonusP50': durations.isEmpty ? 0 : durations[durations.length ~/ 2],
    'sampleBonusP95': durations.isEmpty
        ? 0
        : durations[(durations.length * .95).floor()],
    'elapsedMilliseconds': watch.elapsedMilliseconds,
  };
  const encoder = JsonEncoder.withIndent('  ');
  if (seed == 20261019) {
    File(
      'tool/lucky_math_candidate_v1.json',
    ).writeAsStringSync('${encoder.convert(data)}\n');
  }
  File(
    'tool/lucky_math_seed_$seed.json',
  ).writeAsStringSync('${encoder.convert(data)}\n');
  stdout.writeln(encoder.convert(data));
}
