import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:nuestro_rincon/lucky_palace/engine/lucky_engine.dart';
import 'package:nuestro_rincon/lucky_palace/lucky_demo.dart';

class BadRandom implements LuckyRandom {
  @override
  int nextInt(int max) => max;
}

LuckyRules uniformRules(LuckySymbol symbol, {int cap = 50}) => LuckyRules(
  catalogVersion: 'test.catalog',
  rulesVersion: 'test.rules',
  reels: List.generate(5, (_) => List.filled(3, symbol)),
  payouts: LuckyRules.candidate.payouts,
  lines: LuckyRules.candidate.lines,
  maxBonusSpins: cap,
);

void main() {
  final engine = LuckyEngine();
  for (final count in [3, 4, 5]) {
    test('$count consecutive from first reel, longest match', () {
      final symbols = [
        ...List.filled(count, LuckySymbol.seven),
        ...List.filled(5 - count, LuckySymbol.scatter),
      ];
      final w = engine.evaluateLine(symbols)!;
      expect(w.count, count);
      expect(
        w.amount,
        engine.rules.payouts[LuckySymbol.seven]![count]! *
            engine.rules.lineStake,
      );
      expect(
        engine.evaluateLine([
          LuckySymbol.fish,
          ...List.filled(4, LuckySymbol.seven),
        ]),
        isNull,
      );
    });
  }
  for (final line in LuckyRules.candidate.lines) {
    test('pays actual line ${line.id}', () {
      final grid = List.filled(15, LuckySymbol.scatter);
      for (var c = 0; c < 5; c++) {
        grid[line.rows[c] * 5 + c] = LuckySymbol.maru;
      }
      final evaluation = engine.evaluateGrid(grid);
      expect(
        evaluation.wins.any((w) => w.line.id == line.id && w.count == 5),
        isTrue,
      );
    });
  }
  test('multiple lines add, one payment per line even on all Wild', () {
    final e = engine.evaluateGrid(List.filled(15, LuckySymbol.wild));
    expect(e.wins.length, 5);
    expect(
      e.wins.every((w) => w.symbol == LuckySymbol.wild && w.count == 5),
      isTrue,
    );
    expect(e.total, engine.rules.theoreticalRoundMax);
  });
  test('Wild substitutes, highest amount wins, never substitutes Scatter', () {
    expect(
      engine.evaluateLine([
        LuckySymbol.wild,
        LuckySymbol.seven,
        LuckySymbol.seven,
        LuckySymbol.scatter,
        LuckySymbol.bell,
      ])!.symbol,
      LuckySymbol.seven,
    );
    final long = engine.evaluateLine([
      LuckySymbol.wild,
      LuckySymbol.wild,
      LuckySymbol.wild,
      LuckySymbol.yarn,
      LuckySymbol.yarn,
    ])!;
    expect(long.symbol, LuckySymbol.yarn);
    expect(long.count, 5);
    final short = engine.evaluateLine([
      LuckySymbol.wild,
      LuckySymbol.wild,
      LuckySymbol.wild,
      LuckySymbol.churu,
      LuckySymbol.fish,
    ])!;
    expect(short.symbol, LuckySymbol.wild);
    expect(short.count, 3);
    expect(
      engine.evaluateLine([
        LuckySymbol.wild,
        LuckySymbol.scatter,
        LuckySymbol.scatter,
        LuckySymbol.scatter,
        LuckySymbol.scatter,
      ]),
      isNull,
    );
  });
  test('Wild ambiguity ties resolve by length then stable catalog order', () {
    final rules = LuckyRules(
      catalogVersion: 'tie',
      rulesVersion: 'tie',
      reels: engine.rules.reels,
      lines: engine.rules.lines,
      payouts: {
        LuckySymbol.wild: {3: 12},
        LuckySymbol.yarn: {3: 12, 5: 12},
        LuckySymbol.fish: {3: 12},
      },
    );
    final e = LuckyEngine(rules);
    expect(
      e.evaluateLine([
        LuckySymbol.wild,
        LuckySymbol.wild,
        LuckySymbol.wild,
        LuckySymbol.yarn,
        LuckySymbol.yarn,
      ])!.count,
      5,
    );
    expect(
      e.evaluateLine([
        LuckySymbol.wild,
        LuckySymbol.wild,
        LuckySymbol.wild,
        LuckySymbol.scatter,
        LuckySymbol.scatter,
      ])!.symbol,
      LuckySymbol.yarn,
    );
  });
  test('Scatter counts distinct columns, not cells', () {
    final grid = List.filled(15, LuckySymbol.yarn);
    grid[0] = grid[5] = grid[10] = LuckySymbol.scatter;
    expect(engine.evaluateGrid(grid).scatterColumns, [0]);
    grid[1] = grid[2] = LuckySymbol.scatter;
    expect(engine.evaluateGrid(grid).scatterColumns, [0, 1, 2]);
  });
  test('all 15 cells come from the cyclic reels, including wraparound', () {
    final stops = [15, 14, 13, 12, 11];
    final r = engine.evaluateStops(stops);
    for (var c = 0; c < 5; c++) {
      for (var row = 0; row < 3; row++) {
        expect(
          r.grid[row * 5 + c],
          engine.rules.reels[c][(stops[c] + row) % 16],
        );
      }
    }
    expect(() => r.grid[0] = LuckySymbol.fish, throwsUnsupportedError);
    expect(() => r.stops[0] = 1, throwsUnsupportedError);
    expect(() => engine.rules.reels[0].clear(), throwsUnsupportedError);
    expect(
      () => engine.rules.payouts[LuckySymbol.yarn]![3] = 900,
      throwsUnsupportedError,
    );
  });
  test('bonus activation/retrigger/cap/termination and next paid reset', () {
    final e = LuckyEngine(uniformRules(LuckySymbol.scatter, cap: 15));
    var r = e.evaluateStops([0, 0, 0, 0, 0]);
    expect(r.freeSpin, isFalse);
    expect(r.simulatedCost, 25);
    expect(r.grantedSpins, 12);
    expect(r.after.remaining, 12);
    r = e.evaluateStops([0, 0, 0, 0, 0], bonus: r.after);
    expect(r.freeSpin, isTrue);
    expect(r.simulatedCost, 0);
    expect(r.grantedSpins, 3);
    expect(r.after.remaining, 14);
    var free = 1;
    while (r.after.remaining > 0) {
      r = e.evaluateStops([0, 0, 0, 0, 0], bonus: r.after);
      free++;
      expect(r.grantedSpins, 0);
      expect(free, lessThanOrEqualTo(15));
    }
    expect(free, 15);
    expect(e.evaluateStops([0, 0, 0, 0, 0], bonus: r.after).grantedSpins, 12);
    final quiet = LuckyEngine(uniformRules(LuckySymbol.yarn));
    expect(
      quiet
          .evaluateStops([
            0,
            0,
            0,
            0,
            0,
          ], bonus: const LuckyBonusState(remaining: 1, awarded: 5))
          .after
          .remaining,
      0,
    );
    final smallCap = LuckyEngine(uniformRules(LuckySymbol.scatter, cap: 4));
    expect(smallCap.evaluateStops([0, 0, 0, 0, 0]).grantedSpins, 4);
  });
  test('RNG known vector, seeds, bounds and invalid injection', () {
    final r = LuckySeededRandom(1);
    for (final expected in [48271, 182605794, 1291394886]) {
      expect(r.nextInt(2147483646), expected - 1);
      expect(r.state, expected);
    }
    expect(() => LuckySeededRandom(0), throwsRangeError);
    expect(() => r.nextInt(0), throwsRangeError);
    expect(() => r.nextInt(2147483647), throwsRangeError);
    for (final bound in [1, 3, 16, 31, 1000000001, 2147483646]) {
      for (var i = 0; i < 100; i++) {
        expect(r.nextInt(bound), inInclusiveRange(0, bound - 1));
      }
    }
    expect(() => engine.spin(BadRandom()), throwsStateError);
    expect(() => engine.evaluateStops([16, 0, 0, 0, 0]), throwsRangeError);
    expect(() => engine.evaluateStops([0, 0]), throwsArgumentError);
    expect(
      () => engine.spin(
        r,
        bonus: const LuckyBonusState(remaining: 4, awarded: 3),
      ),
      throwsArgumentError,
    );
  });
  test(
    'same seed and bonus state yield identical receipts for 1000 rounds',
    () {
      final a = LuckySeededRandom(20261019), b = LuckySeededRandom(20261019);
      var bonusA = const LuckyBonusState(), bonusB = const LuckyBonusState();
      for (var i = 0; i < 1000; i++) {
        final ra = engine.spin(a, bonus: bonusA),
            rb = engine.spin(b, bonus: bonusB);
        expect(jsonEncode(ra.toJson()), jsonEncode(rb.toJson()));
        bonusA = ra.after;
        bonusB = rb.after;
      }
    },
  );
  test(
    'engine result to animation: exact 15 cells and continuity after first bridge',
    () {
      final a = engine.evaluateStops([15, 14, 13, 12, 11]),
          b = engine.evaluateStops([0, 3, 6, 9, 12]);
      for (final previous in [null, a]) {
        final f = LuckyDemoFrame(
          round: b,
          previousRound: previous,
          previous: previous?.grid ?? LuckyDemoFrame.initial,
          started: true,
          seconds: 6.2,
        );
        for (var c = 0; c < 5; c++) {
          expect(f.reelPosition(c), closeTo(f.travel(c).toDouble(), 1e-9));
          for (var r = 0; r < 3; r++) {
            expect(f.symbolAt(c, f.travel(c) + r), b.grid[r * 5 + c]);
          }
        }
      }
      final start = LuckyDemoFrame(
        round: b,
        previousRound: a,
        previous: a.grid,
        started: true,
      );
      for (var c = 0; c < 5; c++) {
        for (var r = 0; r < 3; r++) {
          expect(start.symbolAt(c, r), a.grid[r * 5 + c]);
        }
      }
    },
  );
  test('bad configuration is rejected, mutable input is copied', () {
    expect(
      () => LuckyRules(
        catalogVersion: 'v',
        rulesVersion: 'v',
        reels: [],
        payouts: {},
        lines: [],
      ),
      throwsArgumentError,
    );
    expect(() => LuckyLine('x', [0, 0]), throwsArgumentError);
    final reels = List.generate(5, (_) => List.filled(3, LuckySymbol.fish));
    final rules = LuckyRules(
      catalogVersion: 'v',
      rulesVersion: 'v',
      reels: reels,
      payouts: engine.rules.payouts,
      lines: engine.rules.lines,
    );
    reels[0][0] = LuckySymbol.wild;
    expect(rules.reels[0][0], LuckySymbol.fish);
  });
}
