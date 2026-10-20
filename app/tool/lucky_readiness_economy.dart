import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:nuestro_rincon/lucky_palace/engine/lucky_engine.dart';
import 'lucky_economy_model.dart';

void main(List<String> args) {
  final cycles = args.isEmpty ? 300000 : int.parse(args[0]);
  final trials = args.length < 2 ? 20000 : int.parse(args[1]);
  if (cycles < 2 || trials < 1) {
    throw ArgumentError('Positive samples required');
  }
  final watch = Stopwatch()..start(), p = AuditPopulation.enumerate();
  final offers = <Map<String, Object>>[];
  for (final offer in AuditOffer.offers) {
    final exact = p.exact(offer),
        samples = <Map<String, Object>>[],
        sessions = <Map<String, Object>>[];
    for (final seed in [20261019, 1, 8675309]) {
      final rng = LuckySeededRandom(seed), gross = <int>[];
      var sum = 0.0, squares = 0.0, hits = 0, profit = 0;
      final thresholds = [100, 250, 500, 1000, 5000, 10000],
          tails = List<int>.filled(6, 0);
      for (var i = 0; i < cycles; i++) {
        final value = p.sampleCycle(offer, rng).$1;
        gross.add(value);
        sum += value;
        squares += value * value;
        if (value > 0) hits++;
        if (value > offer.rules.wager) profit++;
        for (var t = 0; t < thresholds.length; t++) {
          if (value >= thresholds[t]) tails[t]++;
        }
      }
      gross.sort();
      final mean = sum / cycles,
          variance = (squares - sum * sum / cycles) / (cycles - 1),
          se = math.sqrt(variance / cycles) / offer.rules.wager;
      samples.add({
        'seed': seed,
        'cycles': cycles,
        'rtp': mean / offer.rules.wager,
        'rtp95': [
          mean / offer.rules.wager - 1.96 * se,
          mean / offer.rules.wager + 1.96 * se,
        ],
        'hitRate': hits / cycles,
        'netProfitRate': profit / cycles,
        'percentiles': {
          for (final q in [.5, .9, .95, .99, .999])
            '$q': gross[(q * (cycles - 1)).floor()],
        },
        'maxObserved': gross.last,
        'tailThresholds': thresholds,
        'tailCounts': tails,
      });
      for (final balance in [30, 70, 100, 500]) {
        sessions.add(
          bankrollAudit(p, offer, initial: balance, trials: trials, seed: seed),
        );
      }
    }
    offers.add({...exact, 'samples': samples, 'sessions': sessions});
    stdout.writeln(
      '${offer.id}: RTP ${exact['rtp']}, max ${exact['cycleMax']}',
    );
  }
  final data = {
    'referenceFixtures': {
      'scatter': LuckyEngine().evaluateStops([14, 6, 3, 9, 10]).toJson(),
      'quiet': LuckyEngine().evaluateStops([0, 0, 0, 0, 0]).toJson(),
      'maximum': LuckyEngine().evaluateStops([6, 11, 8, 5, 13]).toJson(),
    },
    'auditVersion': 'lucky.stage35.audit.v1',
    'method':
        'exact joint stop-space histogram; one uniform draw per simulated round, complete bonuses before next wager',
    'cyclesPerSeed': cycles,
    'sessionTrialsPerSeedAndBalance': trials,
    'elapsedMilliseconds': watch.elapsedMilliseconds,
    'offers': offers,
  };
  File(
    'tool/lucky_stage35_economy.json',
  ).writeAsStringSync('${const JsonEncoder.withIndent('  ').convert(data)}\n');
}
