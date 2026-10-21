import '../engine/lucky_engine.dart';

/// Laboratory-only economics. Cosmetic themes never affect these probabilities.
class ScratchRules {
  static const version = 'scratch.triples.local.lab.v1';
  static const cost = 10;
  static const payouts = [3, 5, 7, 9, 11, 15];
  static const enhancedVersion = 'scratch.triples.local.lab.v2';
  static const enhancedPayouts = [3, 5, 7, 10, 12, 17];
  static List<int> payoutsFor(String version) => switch (version) {
    ScratchRules.version => payouts,
    enhancedVersion => enhancedPayouts,
    _ => throw const FormatException('Reglas de raspe desconocidas'),
  };
  static int award(String version, int symbol, int count) {
    final base = payoutsFor(version)[symbol];
    if (count < 3) return 0;
    final multiplier = version == enhancedVersion
        ? (count == 9
              ? 20
              : count >= 6
              ? 3
              : 1)
        : 1;
    return base * multiplier;
  }

  static const cells = 9;
  static const autoReveal = .60;
}

class ScratchOutcome {
  ScratchOutcome(List<int> cells, {this.rulesVersion = ScratchRules.version})
    : cells = List.unmodifiable(cells) {
    ScratchRules.payoutsFor(rulesVersion);
    if (cells.length != ScratchRules.cells ||
        cells.any((v) => v < 0 || v >= ScratchRules.payouts.length)) {
      throw const FormatException(
        'El boleto debe contener nueve símbolos válidos',
      );
    }
  }
  final List<int> cells;
  final String rulesVersion;
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
  int get gross => winningSymbols.fold(
    0,
    (sum, s) => sum + ScratchRules.award(rulesVersion, s, counts[s]),
  );
}

class ScratchEngine {
  const ScratchEngine({this.rulesVersion = ScratchRules.version});
  final String rulesVersion;
  ScratchOutcome generate(LuckyRandom random) => ScratchOutcome(
    List.generate(9, (_) => random.nextInt(6)),
    rulesVersion: rulesVersion,
  );
}
