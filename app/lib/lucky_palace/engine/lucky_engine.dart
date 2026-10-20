import 'dart:math' as math;
import 'lucky_rules.dart';
export 'lucky_rules.dart';

abstract interface class LuckyRandom {
  int nextInt(int max);
}

/// Park–Miller, rejection sampling. Products stay below 2^53 on Dart web.
/// Reproducible, not a cryptographic source or an authority for persistent rewards.
class LuckySeededRandom implements LuckyRandom {
  LuckySeededRandom(int seed) : _state = seed {
    if (seed < 1 || seed > 2147483646) {
      throw RangeError.range(seed, 1, 2147483646, 'seed');
    }
  }
  int _state;
  int get state => _state;
  @override
  int nextInt(int max) {
    if (max < 1 || max > 2147483646) {
      throw RangeError.range(max, 1, 2147483646, 'max');
    }
    final limit = 2147483646 - 2147483646 % max;
    int n;
    do {
      _state = (_state * 48271) % 2147483647;
      n = _state - 1;
    } while (n >= limit);
    return n % max;
  }
}

class LuckyLineWin {
  const LuckyLineWin(
    this.line,
    this.symbol,
    this.count,
    this.multiplier,
    this.amount,
  );
  final LuckyLine line;
  final LuckySymbol symbol;
  final int count, multiplier, amount;
}

class LuckyEvaluation {
  LuckyEvaluation(Iterable<LuckyLineWin> wins, Iterable<int> scatterColumns)
    : wins = List.unmodifiable(wins),
      scatterColumns = List.unmodifiable(scatterColumns);
  final List<LuckyLineWin> wins;
  final List<int> scatterColumns;
  int get total => wins.fold(0, (a, w) => a + w.amount);
}

class LuckyBonusState {
  const LuckyBonusState({this.remaining = 0, this.awarded = 0});
  final int remaining, awarded;
}

class LuckyRound {
  LuckyRound({
    required this.rules,
    required Iterable<int> stops,
    required Iterable<LuckySymbol> grid,
    required this.evaluation,
    required this.before,
    required this.after,
    required this.freeSpin,
    required this.requestedSpins,
    required this.grantedSpins,
  }) : stops = List.unmodifiable(stops),
       grid = List.unmodifiable(grid);
  final LuckyRules rules;
  final List<int> stops;
  final List<LuckySymbol> grid;
  final LuckyEvaluation evaluation;
  final LuckyBonusState before, after;
  final bool freeSpin;
  final int requestedSpins, grantedSpins;
  int get simulatedCost => freeSpin ? 0 : rules.wager;
  Map<String, Object> toJson() => {
    'catalogVersion': rules.catalogVersion,
    'rulesVersion': rules.rulesVersion,
    'stops': stops,
    'grid': grid.map((s) => s.name).toList(),
    'amount': evaluation.total,
    'freeSpin': freeSpin,
    'simulatedCost': simulatedCost,
    'scatterColumns': evaluation.scatterColumns,
    'grantedSpins': grantedSpins,
    'remaining': after.remaining,
    'awarded': after.awarded,
    'lines': evaluation.wins
        .map(
          (w) => {
            'id': w.line.id,
            'symbol': w.symbol.name,
            'count': w.count,
            'multiplier': w.multiplier,
            'amount': w.amount,
          },
        )
        .toList(),
  };
}

class LuckyEngine {
  LuckyEngine([LuckyRules? rules]) : rules = rules ?? LuckyRules.candidate;
  final LuckyRules rules;
  LuckyRound spin(
    LuckyRandom random, {
    LuckyBonusState bonus = const LuckyBonusState(),
  }) {
    _validateBonus(bonus);
    final stops = <int>[];
    for (final reel in rules.reels) {
      final n = random.nextInt(reel.length);
      if (n < 0 || n >= reel.length) {
        throw StateError('Random returned an out-of-range stop');
      }
      stops.add(n);
    }
    return evaluateStops(stops, bonus: bonus);
  }

  void _validateBonus(LuckyBonusState b) {
    if (b.remaining < 0 ||
        b.awarded < b.remaining ||
        b.awarded > rules.maxBonusSpins) {
      throw ArgumentError('Invalid bonus state');
    }
  }

  List<LuckySymbol> gridForStops(List<int> stops) {
    if (stops.length != 5) throw ArgumentError('Five stops required');
    for (var c = 0; c < 5; c++) {
      if (stops[c] < 0 || stops[c] >= rules.reels[c].length) {
        throw RangeError('Invalid reel stop');
      }
    }
    return List.generate(
      15,
      (i) =>
          rules.reels[i % 5][(stops[i % 5] + i ~/ 5) %
              rules.reels[i % 5].length],
    );
  }

  LuckyRound evaluateStops(
    List<int> stops, {
    LuckyBonusState bonus = const LuckyBonusState(),
  }) {
    _validateBonus(bonus);
    final grid = gridForStops(stops), evaluation = evaluateGrid(grid);
    final free = bonus.remaining > 0;
    final awarded = free ? bonus.awarded : 0;
    final requested =
        rules.scatterAwards[evaluation.scatterColumns.length] ?? 0;
    final grant = math.min(requested, rules.maxBonusSpins - awarded);
    return LuckyRound(
      rules: rules,
      stops: stops,
      grid: grid,
      evaluation: evaluation,
      before: bonus,
      after: LuckyBonusState(
        remaining: (free ? bonus.remaining - 1 : 0) + grant,
        awarded: awarded + grant,
      ),
      freeSpin: free,
      requestedSpins: requested,
      grantedSpins: grant,
    );
  }

  LuckyEvaluation evaluateGrid(List<LuckySymbol> grid) {
    if (grid.length != 15) {
      throw ArgumentError('Fifteen row-major cells required');
    }
    final wins = <LuckyLineWin>[], scatter = <int>[];
    for (final line in rules.lines) {
      final win = evaluateLine(
        List.generate(5, (c) => grid[line.rows[c] * 5 + c]),
        line,
      );
      if (win != null) wins.add(win);
    }
    for (var c = 0; c < 5; c++) {
      if ([0, 1, 2].any((r) => grid[r * 5 + c] == LuckySymbol.scatter)) {
        scatter.add(c);
      }
    }
    return LuckyEvaluation(wins, scatter);
  }

  LuckyLineWin? evaluateLine(List<LuckySymbol> symbols, [LuckyLine? line]) {
    if (symbols.length != 5) throw ArgumentError('Five symbols required');
    LuckyLineWin? best;
    for (final target in LuckySymbol.values) {
      final pay = rules.payouts[target];
      if (pay == null) continue;
      var count = 0;
      for (final s in symbols) {
        if (s != target &&
            (s != LuckySymbol.wild || target == LuckySymbol.wild)) {
          break;
        }
        count++;
      }
      final multiplier = pay[count];
      if (multiplier == null) continue;
      final amount = multiplier * rules.lineStake;
      if (best == null ||
          amount > best.amount ||
          (amount == best.amount && count > best.count)) {
        best = LuckyLineWin(
          line ?? rules.lines[1],
          target,
          count,
          multiplier,
          amount,
        );
      }
    }
    return best;
  }
}
