import '../engine/lucky_engine.dart';

/// Laboratory-only economics. Cosmetic themes never affect these probabilities.
class ScratchRules {
  static const version = 'scratch.triples.local.lab.v1';
  static const cost = 10;
  static const payouts = [3, 5, 7, 9, 11, 15];
  static const cells = 9;
  static const autoReveal = .60;
}

class ScratchOutcome {
  ScratchOutcome(List<int> cells) : cells = List.unmodifiable(cells) {
    if (cells.length != ScratchRules.cells ||
        cells.any((v) => v < 0 || v >= ScratchRules.payouts.length)) {
      throw const FormatException(
        'El boleto debe contener nueve símbolos válidos',
      );
    }
  }
  final List<int> cells;
  List<int> get counts {
    final c = List<int>.filled(6, 0);
    for (final v in cells) {
      c[v]++;
    }
    return c;
  }

  List<int> get winningSymbols => [
    for (var i = 0; i < 6; i++)
      if (counts[i] >= 3) i,
  ];
  int get gross =>
      winningSymbols.fold(0, (sum, s) => sum + ScratchRules.payouts[s]);
}

class ScratchEngine {
  const ScratchEngine();
  ScratchOutcome generate(LuckyRandom random) =>
      ScratchOutcome(List.generate(9, (_) => random.nextInt(6)));
}
