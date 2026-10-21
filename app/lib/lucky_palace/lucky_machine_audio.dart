import '../game_audio.dart';

/// A finite presentation timeline for a confirmed round, never an economy event.
class LuckyMachineAudio {
  bool running = false, reward = false, paid = false;
  int landed = 0;
  static const effects = [
    GameSfx.casinoSpin,
    GameSfx.casinoStop,
    GameSfx.casinoPayout,
  ];
  List<GameSfx> begin({required bool hasReward, required bool reduced}) {
    reward = hasReward;
    running = !reduced;
    paid = reduced;
    landed = 0;
    return [
      reduced
          ? (reward ? GameSfx.casinoPayout : GameSfx.casinoStop)
          : GameSfx.casinoSpin,
    ];
  }

  List<GameSfx> advance(double seconds) {
    if (!running || !seconds.isFinite || seconds < 0) return const [];
    if (seconds >= 6.2) {
      cancel();
      return const [];
    }
    var stop = false;
    while (landed < 5 && seconds >= 2 + landed * .22) {
      landed++;
      stop = true;
    }
    final result = <GameSfx>[];
    // Collapsed frames may cross several landings: no backlog of overlapping SFX.
    if (stop && seconds < 3.35) result.add(GameSfx.casinoStop);
    if (seconds >= 3.35 && !paid) {
      paid = true;
      if (reward && seconds < 5.25) result.add(GameSfx.casinoPayout);
    }
    return result;
  }

  (GameSfx, Duration)? resumeAt(double seconds) {
    if (!running || !seconds.isFinite || seconds < 0) return null;
    if (seconds < 2.94) {
      return (
        GameSfx.casinoSpin,
        Duration(microseconds: (seconds * 1000000).round()),
      );
    }
    if (reward && paid && seconds >= 3.35 && seconds < 5.25) {
      return (
        GameSfx.casinoPayout,
        Duration(microseconds: ((seconds - 3.35) * 1000000).round()),
      );
    }
    return null;
  }

  void cancel() => running = false;
}
