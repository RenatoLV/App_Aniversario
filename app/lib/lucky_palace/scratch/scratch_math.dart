import 'scratch_engine.dart';

Map<int, int> scratchExactDistribution({
  String rulesVersion = ScratchRules.version,
}) {
  final distribution = <int, int>{};
  final counts = List<int>.filled(6, 0);
  int factorial(int n) {
    var v = 1;
    for (var i = 2; i <= n; i++) {
      v *= i;
    }
    return v;
  }

  void visit(int symbol, int remaining) {
    if (symbol == 5) {
      counts[symbol] = remaining;
      var denominator = 1, gross = 0;
      for (var i = 0; i < 6; i++) {
        denominator *= factorial(counts[i]);
        gross += ScratchRules.award(rulesVersion, i, counts[i]);
      }
      distribution.update(
        gross,
        (old) => old + factorial(9) ~/ denominator,
        ifAbsent: () => factorial(9) ~/ denominator,
      );
      return;
    }
    for (var n = 0; n <= remaining; n++) {
      counts[symbol] = n;
      visit(symbol + 1, remaining - n);
    }
  }

  visit(0, 9);
  return distribution;
}
