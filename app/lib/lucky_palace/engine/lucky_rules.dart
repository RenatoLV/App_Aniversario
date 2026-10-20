import 'lucky_symbol.dart';
export 'lucky_symbol.dart';

class LuckyLine {
  LuckyLine(this.id, Iterable<int> rows) : rows = List.unmodifiable(rows) {
    if (id.isEmpty ||
        this.rows.length != 5 ||
        this.rows.any((r) => r < 0 || r > 2)) {
      throw ArgumentError('A line needs an id and five rows in 0..2');
    }
  }
  final String id;
  final List<int> rows;
}

/// Immutable, versioned input. Amounts are provisional simulation credits.
class LuckyRules {
  LuckyRules({
    required this.catalogVersion,
    required this.rulesVersion,
    required Iterable<Iterable<LuckySymbol>> reels,
    required Map<LuckySymbol, Map<int, int>> payouts,
    required Iterable<LuckyLine> lines,
    this.lineStake = 5,
    this.maxBonusSpins = 50,
    Map<int, int> scatterAwards = const {3: 5, 4: 8, 5: 12},
  }) : reels = List.unmodifiable(
         reels.map((r) => List<LuckySymbol>.unmodifiable(r)),
       ),
       payouts = Map.unmodifiable(
         payouts.map((k, v) => MapEntry(k, Map<int, int>.unmodifiable(v))),
       ),
       lines = List.unmodifiable(lines),
       scatterAwards = Map.unmodifiable(scatterAwards) {
    if (catalogVersion.isEmpty ||
        rulesVersion.isEmpty ||
        this.reels.length != 5 ||
        this.reels.any((r) => r.length < 3) ||
        lineStake <= 0 ||
        maxBonusSpins <= 0 ||
        this.lines.length != 5 ||
        this.lines.map((l) => l.id).toSet().length != 5 ||
        this.payouts.isEmpty ||
        this.payouts.containsKey(LuckySymbol.scatter) ||
        this.payouts.values.any(
          (v) =>
              v.keys.any((k) => k < 3 || k > 5) || v.values.any((p) => p <= 0),
        ) ||
        this.scatterAwards.entries.any(
          (e) => e.key < 3 || e.key > 5 || e.value <= 0,
        )) {
      throw ArgumentError('Invalid Lucky rules');
    }
  }
  final String catalogVersion, rulesVersion;
  final List<List<LuckySymbol>> reels;
  final Map<LuckySymbol, Map<int, int>> payouts;
  final List<LuckyLine> lines;
  final Map<int, int> scatterAwards;
  final int lineStake, maxBonusSpins;
  int get wager => lineStake * lines.length;
  int get theoreticalRoundMax =>
      lines.length *
      lineStake *
      payouts.values.expand((p) => p.values).reduce((a, b) => a > b ? a : b);

  static final candidate = LuckyRules(
    catalogVersion: 'lucky777.catalog.v1',
    rulesVersion: 'lucky777.rules.candidate.v1',
    reels: const [
      [
        LuckySymbol.yarn,
        LuckySymbol.fish,
        LuckySymbol.bell,
        LuckySymbol.yarn,
        LuckySymbol.churu,
        LuckySymbol.maru,
        LuckySymbol.fish,
        LuckySymbol.yarn,
        LuckySymbol.wild,
        LuckySymbol.bell,
        LuckySymbol.churu,
        LuckySymbol.fish,
        LuckySymbol.lady,
        LuckySymbol.yarn,
        LuckySymbol.scatter,
        LuckySymbol.seven,
      ],
      [
        LuckySymbol.fish,
        LuckySymbol.yarn,
        LuckySymbol.churu,
        LuckySymbol.lady,
        LuckySymbol.yarn,
        LuckySymbol.bell,
        LuckySymbol.scatter,
        LuckySymbol.fish,
        LuckySymbol.yarn,
        LuckySymbol.seven,
        LuckySymbol.churu,
        LuckySymbol.fish,
        LuckySymbol.wild,
        LuckySymbol.yarn,
        LuckySymbol.maru,
        LuckySymbol.bell,
      ],
      [
        LuckySymbol.bell,
        LuckySymbol.yarn,
        LuckySymbol.fish,
        LuckySymbol.scatter,
        LuckySymbol.churu,
        LuckySymbol.yarn,
        LuckySymbol.maru,
        LuckySymbol.fish,
        LuckySymbol.wild,
        LuckySymbol.yarn,
        LuckySymbol.bell,
        LuckySymbol.lady,
        LuckySymbol.churu,
        LuckySymbol.fish,
        LuckySymbol.yarn,
        LuckySymbol.seven,
      ],
      [
        LuckySymbol.yarn,
        LuckySymbol.lady,
        LuckySymbol.fish,
        LuckySymbol.bell,
        LuckySymbol.churu,
        LuckySymbol.yarn,
        LuckySymbol.wild,
        LuckySymbol.fish,
        LuckySymbol.yarn,
        LuckySymbol.scatter,
        LuckySymbol.bell,
        LuckySymbol.churu,
        LuckySymbol.maru,
        LuckySymbol.yarn,
        LuckySymbol.fish,
        LuckySymbol.seven,
      ],
      [
        LuckySymbol.fish,
        LuckySymbol.yarn,
        LuckySymbol.maru,
        LuckySymbol.churu,
        LuckySymbol.bell,
        LuckySymbol.yarn,
        LuckySymbol.fish,
        LuckySymbol.seven,
        LuckySymbol.yarn,
        LuckySymbol.lady,
        LuckySymbol.scatter,
        LuckySymbol.churu,
        LuckySymbol.yarn,
        LuckySymbol.fish,
        LuckySymbol.bell,
        LuckySymbol.wild,
      ],
    ],
    lines: [
      LuckyLine('superior', [0, 0, 0, 0, 0]),
      LuckyLine('central', [1, 1, 1, 1, 1]),
      LuckyLine('inferior', [2, 2, 2, 2, 2]),
      LuckyLine('v', [0, 1, 2, 1, 0]),
      LuckyLine('v-invertida', [2, 1, 0, 1, 2]),
    ],
    payouts: const {
      LuckySymbol.yarn: {3: 4, 4: 12, 5: 40},
      LuckySymbol.fish: {3: 4, 4: 12, 5: 40},
      LuckySymbol.churu: {3: 6, 4: 20, 5: 64},
      LuckySymbol.bell: {3: 8, 4: 28, 5: 80},
      LuckySymbol.maru: {3: 12, 4: 40, 5: 120},
      LuckySymbol.lady: {3: 12, 4: 40, 5: 120},
      LuckySymbol.seven: {3: 20, 4: 80, 5: 320},
      LuckySymbol.wild: {3: 24, 4: 120, 5: 600},
    },
  );
}
