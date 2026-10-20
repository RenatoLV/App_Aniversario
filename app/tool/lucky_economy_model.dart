// Audit-only models. No UI imports, persistence adapters or live configuration.
import 'dart:math' as math;
import 'package:nuestro_rincon/lucky_palace/engine/lucky_engine.dart';

class AuditOffer {
  AuditOffer(this.id, this.rules);
  final String id;
  final LuckyRules rules;
  static LuckyRules variant(int stake, int cap, String version) {
    final base = LuckyRules.candidate;
    return LuckyRules(
      catalogVersion: base.catalogVersion,
      rulesVersion: version,
      reels: base.reels,
      payouts: base.payouts,
      lines: base.lines,
      scatterAwards: base.scatterAwards,
      lineStake: stake,
      maxBonusSpins: cap,
    );
  }

  static final offers = [
    AuditOffer('reference25', LuckyRules.candidate),
    AuditOffer('scaled10', variant(2, 50, 'lucky777.rules.audit.stake10.v1')),
    AuditOffer(
      'capped10',
      variant(2, 12, 'lucky777.rules.audit.stake10.cap12.v1'),
    ),
  ];
}

class AuditOutcome {
  const AuditOutcome(this.units, this.scatters, this.count);
  final int units, scatters, count;
}

class AuditPopulation {
  AuditPopulation(Iterable<AuditOutcome> outcomes)
    : outcomes = List.unmodifiable(outcomes) {
    var total = 0;
    for (final o in this.outcomes) {
      if (o.count <= 0 || o.units < 0 || o.scatters < 0 || o.scatters > 5) {
        throw ArgumentError('Invalid population');
      }
      total += o.count;
      cumulative.add(total);
    }
    if (total == 0) throw ArgumentError('Empty population');
  }
  final List<AuditOutcome> outcomes;
  final List<int> cumulative = [];
  int get size => cumulative.last;
  factory AuditPopulation.enumerate() {
    final e = LuckyEngine(),
        stops = List<int>.filled(5, 0),
        hist = <(int, int), int>{};
    void visit(int c) {
      if (c < 5) {
        for (var i = 0; i < e.rules.reels[c].length; i++) {
          stops[c] = i;
          visit(c + 1);
        }
        return;
      }
      final evaluation = e.evaluateGrid(e.gridForStops(stops));
      final key = (
        evaluation.total ~/ e.rules.lineStake,
        evaluation.scatterColumns.length,
      );
      hist[key] = (hist[key] ?? 0) + 1;
    }

    visit(0);
    final keys = hist.keys.toList()
      ..sort(
        (a, b) => a.$1 == b.$1 ? a.$2.compareTo(b.$2) : a.$1.compareTo(b.$1),
      );
    return AuditPopulation(keys.map((k) => AuditOutcome(k.$1, k.$2, hist[k]!)));
  }
  AuditOutcome sample(LuckyRandom random) {
    final x = random.nextInt(size);
    var lo = 0, hi = cumulative.length - 1;
    while (lo < hi) {
      final mid = (lo + hi) ~/ 2;
      if (x < cumulative[mid]) {
        hi = mid;
      } else {
        lo = mid + 1;
      }
    }
    return outcomes[lo];
  }

  /// Uniform draw from the exact joint (payout, Scatter) stop-space histogram.
  /// Equivalent one-round distribution, not the 5-RNG-call engine trajectory.
  (int, int) sampleCycle(AuditOffer offer, LuckyRandom random) {
    var pending = 0, awarded = 0, units = 0, free = 0;
    do {
      if (pending > 0) {
        pending--;
        free++;
      }
      final o = sample(random);
      units += o.units;
      final grant = math.min(
        offer.rules.scatterAwards[o.scatters] ?? 0,
        offer.rules.maxBonusSpins - awarded,
      );
      awarded += grant;
      pending += grant;
    } while (pending > 0);
    return (units * offer.rules.lineStake, free);
  }

  Map<String, Object> exact(AuditOffer offer) {
    final cap = offer.rules.maxBonusSpins, stake = offer.rules.lineStake;
    final counts = List<int>.filled(6, 0),
        sums = List<double>.filled(6, 0),
        squares = List<double>.filled(6, 0),
        maxima = List<int>.filled(6, 0);
    var mean = 0.0, second = 0.0;
    for (final o in outcomes) {
      counts[o.scatters] += o.count;
      sums[o.scatters] += o.units * o.count;
      squares[o.scatters] += o.units * o.units * o.count;
      maxima[o.scatters] = math.max(maxima[o.scatters], o.units);
      mean += o.units * o.count / size;
      second += o.units * o.units * o.count / size;
    }
    final memo = <(int, int), (double, double, double, int)>{};
    (double, double, double, int) future(int r, int a) {
      if (r == 0) return (0, 0, 0, 0);
      final key = (r, a);
      if (memo.containsKey(key)) return memo[key]!;
      var m = mean, s = second, length = 1.0, best = 0;
      for (var c = 0; c <= 5; c++) {
        if (counts[c] == 0) continue;
        final g = math.min(offer.rules.scatterAwards[c] ?? 0, cap - a),
            f = future(r - 1 + g, a + g),
            p = counts[c] / size;
        m += p * f.$1;
        s += 2 * sums[c] / size * f.$1 + p * f.$2;
        length += p * f.$3;
        best = math.max(best, maxima[c] + f.$4);
      }
      return memo[key] = (m, s, length, best);
    }

    var m = mean, s = second, length = 0.0, trigger = 0.0, best = 0;
    for (var c = 0; c <= 5; c++) {
      if (counts[c] == 0) continue;
      final g = math.min(offer.rules.scatterAwards[c] ?? 0, cap),
          f = future(g, g),
          p = counts[c] / size;
      m += p * f.$1;
      s += 2 * sums[c] / size * f.$1 + p * f.$2;
      length += p * f.$3;
      if (g > 0) trigger += p;
      best = math.max(best, maxima[c] + f.$4);
    }
    // Truncated probability generating functions, enough for exact P(win > cost).
    final pmemo = <(int, int), List<double>>{};
    List<double> pmf(int r, int a) {
      if (r == 0) return [1, 0, 0, 0, 0, 0];
      final key = (r, a);
      if (pmemo.containsKey(key)) return pmemo[key]!;
      final result = List<double>.filled(6, 0);
      for (final o in outcomes) {
        if (o.units > 5) continue;
        final g = math.min(offer.rules.scatterAwards[o.scatters] ?? 0, cap - a),
            next = pmf(r - 1 + g, a + g);
        for (var k = o.units; k <= 5; k++) {
          result[k] += o.count / size * next[k - o.units];
        }
      }
      return pmemo[key] = result;
    }

    final cyclePmf = List<double>.filled(6, 0);
    for (final o in outcomes) {
      if (o.units > 5) continue;
      final g = math.min(offer.rules.scatterAwards[o.scatters] ?? 0, cap),
          next = pmf(g, g);
      for (var k = o.units; k <= 5; k++) {
        cyclePmf[k] += o.count / size * next[k - o.units];
      }
    }
    return {
      'id': offer.id,
      'catalogVersion': offer.rules.catalogVersion,
      'rulesVersion': offer.rules.rulesVersion,
      'wager': offer.rules.wager,
      'lineStake': stake,
      'cap': cap,
      'states': size,
      'rtp': m / 5,
      'meanGross': m * stake,
      'meanNet': m * stake - offer.rules.wager,
      'variance': (s - m * m) * stake * stake,
      'roundMax': maxima.reduce(math.max) * stake,
      'cycleMax': best * stake,
      'triggerProbability': trigger,
      'meanFree': length,
      'meanBonusConditional': trigger == 0 ? 0 : length / trigger,
      'cycleHitRate': 1 - cyclePmf[0],
      'netProfitRate': 1 - cyclePmf.reduce((a, b) => a + b),
      'breakEvenRate': cyclePmf[5],
      'cyclePayoutAtMost5Units': cyclePmf,
      'tailChernoffUpper': _tailBounds(offer, best * stake),
    };
  }

  Map<String, double> _tailBounds(AuditOffer offer, int maximum) {
    final thresholds = [1000, 5000, 10000];
    final bounds = {
      for (final threshold in thresholds)
        '$threshold': threshold > maximum ? 0.0 : 1.0,
    };
    for (var step = 1; step <= 40; step++) {
      final t = step * .0005, weights = List<double>.filled(6, 0);
      for (final o in outcomes) {
        weights[o.scatters] += o.count / size * math.exp(t * o.units);
      }
      final memo = <(int, int), double>{};
      double mgf(int r, int a) {
        if (r == 0) return 1;
        final key = (r, a);
        if (memo.containsKey(key)) return memo[key]!;
        var result = 0.0;
        for (var c = 0; c <= 5; c++) {
          if (weights[c] == 0) continue;
          final g = math.min(
            offer.rules.scatterAwards[c] ?? 0,
            offer.rules.maxBonusSpins - a,
          );
          result += weights[c] * mgf(r - 1 + g, a + g);
        }
        return memo[key] = result;
      }

      var cycle = 0.0;
      for (var c = 0; c <= 5; c++) {
        if (weights[c] == 0) continue;
        final g = math.min(
          offer.rules.scatterAwards[c] ?? 0,
          offer.rules.maxBonusSpins,
        );
        cycle += weights[c] * mgf(g, g);
      }
      for (final threshold in thresholds) {
        bounds['$threshold'] = math.min(
          bounds['$threshold']!,
          cycle * math.exp(-t * threshold / offer.rules.lineStake),
        );
      }
    }
    return bounds;
  }
}

/// Counterfactual only: cycles settle all Free Spins, with no income or purchases.
Map<String, Object> bankrollAudit(
  AuditPopulation p,
  AuditOffer offer, {
  required int initial,
  required int trials,
  required int seed,
}) {
  final rng = LuckySeededRandom(seed), horizons = [1, 3, 5, 10, 20];
  final unable = List<int>.filled(5, 0), zero = List<int>.filled(5, 0);
  for (var n = 0; n < trials; n++) {
    var wallet = initial, completed = 0;
    for (var h = 0; h < horizons.length; h++) {
      while (completed < horizons[h] && wallet >= offer.rules.wager) {
        wallet -= offer.rules.wager;
        wallet += p.sampleCycle(offer, rng).$1;
        completed++;
      }
      if (wallet < offer.rules.wager) unable[h]++;
      if (wallet == 0) zero[h]++;
    }
  }
  return {
    'initial': initial,
    'seed': seed,
    'trials': trials,
    'horizons': horizons,
    'unableCounts': unable,
    'unableRates': unable.map((v) => v / trials).toList(),
    'zeroCounts': zero,
    'zeroRates': zero.map((v) => v / trials).toList(),
  };
}
