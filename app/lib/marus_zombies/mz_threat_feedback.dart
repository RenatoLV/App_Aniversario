import 'mz_catalog.dart';
import 'mz_simulation.dart';

enum MzThreatKind { wave, boss }

class MzThreatArrival {
  const MzThreatArrival(this.row, this.x, this.start, this.id);
  final int row, id;
  final double x, start;
}

/// Presentation only: schedule thresholds and real newly visible invaders.
/// Initial/resumed snapshots establish a baseline, never replay old arrivals.
class MzThreatFeedback {
  MzThreatFeedback({this.allWorlds = false});
  final bool allWorlds;
  MzSimulation? _simulation;
  final _known = <int>{}, _seenWaves = <double>{};
  final arrivals = <MzThreatArrival>[];
  final dangerRows = List<bool>.filled(5, false);
  List<double> _waveTimes = const [];
  double _previousTime = 0;
  double? waveStart, bossStart;
  int? bossId;
  double bossHp = 0, bossMaximum = 1, bossX = 0;
  int bossRow = 2;
  static const waveLead = 4.0, waveDuration = 3.2, bossDuration = 2.4;
  bool get hasBoss => bossId != null;
  String? announcement(double time) =>
      bossStart != null && time - bossStart! < bossDuration
      ? MzEnemy.boss.label
      : waveStart != null && time - waveStart! < waveDuration
      ? '¡Se acerca una gran oleada!'
      : null;

  List<MzThreatKind> observe(MzSimulation sim) {
    final initial = !identical(_simulation, sim);
    if (initial) {
      reset();
      _simulation = sim;
      final times =
          sim.level.mode == MzMode.survival ||
              (!allWorlds && sim.level.id != 9 && sim.level.id != 49)
          ? <double>[]
          : sim.schedule
                .where((s) => s.kind == MzEnemy.flag)
                .map((s) => s.time - waveLead)
                .toSet()
                .toList();
      times.sort();
      _waveTimes = times;
      _seenWaves.addAll(_waveTimes.where((t) => t <= sim.time));
    }
    final cues = <MzThreatKind>[];
    if (!initial && !sim.paused && !sim.ended && sim.time > _previousTime) {
      for (final at in _waveTimes) {
        if (!_seenWaves.contains(at) && _previousTime < at && sim.time >= at) {
          _seenWaves.add(at);
          waveStart = sim.time;
          cues.add(MzThreatKind.wave);
        }
      }
    }
    arrivals.removeWhere((a) => sim.time - a.start >= .55);
    dangerRows.fillRange(0, 5, false);
    bossId = null;
    for (final e in sim.invaders.where((e) => e.alive)) {
      if (e.x < 1.5 && e.row >= 0 && e.row < 5) dangerRows[e.row] = true;
      final fresh = !initial && !sim.paused && !_known.contains(e.id);
      if (fresh) {
        if (arrivals.length >= 8) arrivals.removeAt(0);
        arrivals.add(MzThreatArrival(e.row, e.x, sim.time, e.id));
      }
      if (e.kind == MzEnemy.boss) {
        bossId = e.id;
        bossHp = e.hp;
        bossMaximum = e.kind.health;
        bossX = e.x;
        bossRow = e.row;
        if (fresh) {
          bossStart = sim.time;
          cues.add(MzThreatKind.boss);
        }
      }
    }
    if (!hasBoss) bossStart = null;
    _known
      ..clear()
      ..addAll(sim.invaders.map((e) => e.id));
    _previousTime = sim.time;
    return cues;
  }

  void reset() {
    _simulation = null;
    _known.clear();
    _seenWaves.clear();
    arrivals.clear();
    dangerRows.fillRange(0, 5, false);
    waveStart = bossStart = null;
    bossId = null;
    _waveTimes = const [];
    _previousTime = 0;
  }
}
