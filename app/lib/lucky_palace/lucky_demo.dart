import 'dart:math' as math;
import 'engine/lucky_engine.dart';

enum LuckyDemo {
  none('Sin premio', 0),
  small('Premio pequeño', 150),
  big('Premio grande', 5000);

  const LuckyDemo(this.label, this.amount);
  final String label;
  final int amount;
}

enum LuckyPose { idle, anticipation, spin, smallWin, bigWin, recover }

/// Presentation only: fixed strips and examples, independent of wallet/RNG.
class LuckyDemoFrame {
  const LuckyDemoFrame({
    this.seconds = 0,
    this.demo = LuckyDemo.none,
    this.previous = initial,
    this.drag = 0,
    this.started = false,
    this.reduced = false,
    this.initialPull = 0,
    this.round,
    this.previousRound,
    this.referenceCost,
  });
  final LuckyRound? round, previousRound;
  final int? referenceCost;
  final double seconds, drag;
  final double initialPull;
  final LuckyDemo demo;
  final List<LuckySymbol> previous;
  final bool started, reduced;
  static const duration = 6.2;
  static const initial = [
    LuckySymbol.wild,
    LuckySymbol.churu,
    LuckySymbol.seven,
    LuckySymbol.lady,
    LuckySymbol.bell,
    LuckySymbol.fish,
    LuckySymbol.maru,
    LuckySymbol.yarn,
    LuckySymbol.scatter,
    LuckySymbol.seven,
    LuckySymbol.bell,
    LuckySymbol.scatter,
    LuckySymbol.fish,
    LuckySymbol.churu,
    LuckySymbol.yarn,
  ];

  static const _top = [
    LuckySymbol.fish,
    LuckySymbol.maru,
    LuckySymbol.yarn,
    LuckySymbol.bell,
    LuckySymbol.lady,
  ];
  static const _bottom = [
    LuckySymbol.churu,
    LuckySymbol.scatter,
    LuckySymbol.bell,
    LuckySymbol.maru,
    LuckySymbol.yarn,
  ];
  static const _results = [
    [
      ..._top,
      LuckySymbol.bell,
      LuckySymbol.churu,
      LuckySymbol.lady,
      LuckySymbol.yarn,
      LuckySymbol.fish,
      ..._bottom,
    ],
    [
      ..._top,
      LuckySymbol.seven,
      LuckySymbol.seven,
      LuckySymbol.seven,
      LuckySymbol.fish,
      LuckySymbol.bell,
      ..._bottom,
    ],
    [
      ..._top,
      LuckySymbol.wild,
      LuckySymbol.wild,
      LuckySymbol.wild,
      LuckySymbol.wild,
      LuckySymbol.wild,
      ..._bottom,
    ],
  ];
  List<LuckySymbol> get result => round?.grid ?? _results[demo.index];
  int get amount => round?.evaluation.total ?? demo.amount;
  bool get hasReward => amount > 0 || (round?.grantedSpins ?? 0) > 0;
  bool get bigWin =>
      round != null ? amount >= round!.rules.wager * 20 : demo == LuckyDemo.big;
  List<LuckyLineWin> get wins =>
      round?.evaluation.wins ??
      (demo == LuckyDemo.none
          ? const []
          : [
              LuckyLineWin(
                LuckyRules.candidate.lines[1],
                demo == LuckyDemo.big ? LuckySymbol.wild : LuckySymbol.seven,
                demo == LuckyDemo.big ? 5 : 3,
                0,
                demo.amount,
              ),
            ]);
  bool winningCell(int column, int row) =>
      wins.any((w) => column < w.count && w.line.rows[column] == row);
  bool get _continuous =>
      round != null &&
      previousRound != null &&
      identical(round!.rules, previousRound!.rules);
  int travel(int column) {
    if (round == null) return 30 + column * 12;
    final length = round!.rules.reels[column].length;
    return _continuous
        ? length * (3 + column) +
              (round!.stops[column] - previousRound!.stops[column] + length) %
                  length
        : 3 + length * (3 + column);
  }

  LuckyPose get pose {
    if (!started || seconds >= duration) return LuckyPose.idle;
    if (seconds < .45) return LuckyPose.anticipation;
    if (seconds < 3.35) return LuckyPose.spin;
    if (seconds >= 5.3) return LuckyPose.recover;
    return !hasReward
        ? LuckyPose.recover
        : bigWin
        ? LuckyPose.bigWin
        : LuckyPose.smallWin;
  }

  double get celebration =>
      started && !reduced && seconds >= 3.35 && seconds < 5.3
      ? math.sin((seconds - 3.35) / 1.95 * math.pi)
      : 0;
  double get pull {
    if (drag > 0) return drag;
    if (!started || reduced) return 0;
    if (seconds < .45) {
      return initialPull +
          (1 - initialPull) * math.sin(seconds / .45 * math.pi / 2);
    }
    if (seconds < .8) return 1 - (seconds - .45) / .35;
    return 0;
  }

  double reelPosition(int column) {
    if (!started) return 0;
    final p = ((seconds - .45) / (1.55 + column * .22)).clamp(0.0, 1.0);
    return travel(column) * (p * p * p * (10 - 15 * p + 6 * p * p));
  }

  LuckySymbol symbolAt(int column, int index) {
    if (round != null) {
      final reel = round!.rules.reels[column];
      if (_continuous) {
        return reel[(previousRound!.stops[column] + index) % reel.length];
      }
      // A three-cell bridge is needed only when entering from the art demo.
      if (index >= 0 && index < 3) return previous[index * 5 + column];
      return reel[(round!.stops[column] + index - 3) % reel.length];
    }
    final i = index % 12;
    if (i < 3) return previous[i * 5 + column];
    if (i >= 6 && i <= 8) return result[(i - 6) * 5 + column];
    return LuckySymbol.values[(i + column * 2) % LuckySymbol.values.length];
  }

  bool get settled => started && seconds >= 3.35;
  int get shownAmount => !settled
      ? 0
      : (amount * (reduced ? 1 : ((seconds - 3.35) / 1.1).clamp(0.0, 1.0)))
            .round();
  String get status {
    final prefix = round == null ? 'DEMO' : 'MOTOR · PRUEBA';
    if (!started) return 'DEMO · Elige una escena';
    if (!settled) return '$prefix · Girando…';
    if ((round?.grantedSpins ?? 0) > 0) {
      return '$prefix · +${round!.grantedSpins} gratis${amount > 0 ? ' · +$shownAmount' : ''}';
    }
    return amount == 0 ? '$prefix · Sin premio' : '$prefix · +$shownAmount';
  }
}
