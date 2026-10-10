import '../game_audio.dart';
import 'mz_catalog.dart';
import 'mz_models.dart';
import 'mz_simulation.dart';

/// Read-only before/after transactions, independent of animation and visual FX.
/// Capture immediately before advance; dispatch once after that advance.
class MzCombatAudio {
  final _cats = <int, (MzCat, double, int)>{};
  final _armor = <int, (double, int, double)>{};
  final _effects = <MzEffect>{};
  int _kills = 0, _tuna = 0;
  bool _ready = false;

  void capture(MzSimulation sim) {
    _cats.clear();
    _armor.clear();
    _effects
      ..clear()
      ..addAll(sim.effects);
    for (final d in sim.defenders) {
      _cats[d.id] = (d.kind, d.attack, d.burstLeft);
    }
    for (final e in sim.invaders) {
      if (e.armor > 0) _armor[e.id] = (e.armor, e.row, e.x);
    }
    _kills = sim.kills;
    _tuna = sim.tuna;
    _ready = sim.level.world == MzWorld.patio && !sim.paused && !sim.ended;
  }

  List<GameSfx> events(MzSimulation sim) {
    if (!_ready) return const [];
    _ready = false; // The same transaction cannot be replayed by a repaint.
    final cues = <GameSfx>[];
    for (final d in sim.defenders) {
      final old = _cats[d.id];
      if (old != null &&
          old.$1 == MzCat.launcher &&
          (d.attack > old.$2 + .001 || d.burstLeft < old.$3)) {
        cues.add(GameSfx.marusLauncher);
      }
    }
    var collects = 0;
    for (final f in sim.effects) {
      if (_effects.contains(f)) continue;
      if (f.type == 'bite') cues.add(GameSfx.marusBite);
      if (f.type == 'collect') collects++;
      if (f.type == 'hit' || f.type == 'ice') {
        for (final entry in _armor.entries) {
          final old = entry.value;
          if (old.$2 != f.row || (old.$3 - f.x).abs() > .2) continue;
          final enemy = sim.invaders
              .where((e) => e.id == entry.key)
              .firstOrNull;
          if (enemy == null || enemy.armor < old.$1) {
            cues.add(GameSfx.marusArmor);
            break;
          }
        }
      }
    }
    // Auto-collection creates the same real collect effects as manual tapping.
    // Tuna raises a separate counter and must never make a grass pickup sound.
    final grass = collects - (sim.tuna - _tuna).clamp(0, collects);
    if (grass > 0) cues.add(GameSfx.marusHarvest);
    if (sim.kills > _kills) cues.add(GameSfx.marusDefeat);
    return cues;
  }

  void reset() {
    _ready = false;
    _cats.clear();
    _armor.clear();
    _effects.clear();
  }
}
