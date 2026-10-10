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
  final _projectiles = <int>{};
  final _arcs = <int, (int, double, int?)>{};
  final _enemyPositions = <int, (int, double)>{};
  final _frozen = <int, double>{};
  double _time = 0;
  bool laserActive = false;
  int _kills = 0, _tuna = 0;
  bool _ready = false;

  void capture(MzSimulation sim) {
    _cats.clear();
    _armor.clear();
    _projectiles.clear();
    _arcs.clear();
    _enemyPositions.clear();
    _frozen.clear();
    _time = sim.time;
    for (final p in sim.projectiles) {
      _projectiles.add(p.id);
      if (p.arc) _arcs[p.id] = (p.row, p.x, p.target);
    }
    _effects
      ..clear()
      ..addAll(sim.effects);
    for (final d in sim.defenders) {
      _cats[d.id] = (d.kind, d.attack, d.burstLeft);
    }
    for (final e in sim.invaders) {
      _enemyPositions[e.id] = (e.row, e.x);
      _frozen[e.id] = e.frozenUntil;
      if (e.armor > 0) _armor[e.id] = (e.armor, e.row, e.x);
    }
    _kills = sim.kills;
    _tuna = sim.tuna;
    _ready = !sim.paused && !sim.ended;
  }

  List<GameSfx> events(MzSimulation sim) {
    if (!_ready) return const [];
    _ready = false; // The same transaction cannot be replayed by a repaint.
    final cues = <GameSfx>[];
    final patio = sim.level.world == MzWorld.patio;
    final fresh = sim.effects.where((f) => !_effects.contains(f)).toList();
    if (sim.time > _time || sim.ended) {
      final firing = !sim.ended && fresh.any((f) => f.type == 'laser');
      if (firing && !laserActive) cues.add(GameSfx.marusLaserStart);
      if (!firing && laserActive) cues.add(GameSfx.marusLaserEnd);
      laserActive = firing;
    }
    for (final d in sim.defenders) {
      final old = _cats[d.id];
      if (old != null &&
          patio &&
          old.$1 == MzCat.launcher &&
          (d.attack > old.$2 + .001 || d.burstLeft < old.$3)) {
        cues.add(GameSfx.marusLauncher);
      }
      if (old != null && old.$1 == MzCat.ice && d.attack > old.$2 + .001) {
        cues.add(GameSfx.marusIceShot);
      }
      if (old != null && old.$1 == MzCat.catapult && d.attack > old.$2 + .001) {
        cues.add(GameSfx.marusCatapult);
      }
      final powered = fresh.any(
        (f) =>
            f.type == 'tuna' &&
            f.row == d.row &&
            (f.x - d.col - .5).abs() < .01,
      );
      if (powered && d.kind == MzCat.sunflower) cues.add(GameSfx.marusSunTuna);
      if (powered && d.kind == MzCat.laser) cues.add(GameSfx.marusLaserStart);
      if (powered &&
          d.kind == MzCat.ice &&
          sim.invaders.any(
            (e) => e.row == d.row && e.frozenUntil > (_frozen[e.id] ?? 0),
          )) {
        cues.add(GameSfx.marusFreeze);
      }
    }
    if (sim.projectiles.any((p) => p.arc && !_projectiles.contains(p.id))) {
      cues.add(GameSfx.marusCatapult);
    }
    var collects = 0;
    for (final f in sim.effects) {
      if (_effects.contains(f)) continue;
      if (f.type == 'sun') cues.add(GameSfx.marusSun);
      if (f.type == 'ice') cues.add(GameSfx.marusIceHit);
      if (f.type == 'hit' &&
          _arcs.entries.any((entry) {
            final arc = entry.value;
            final target = _enemyPositions[arc.$3];
            return !sim.projectiles.any((p) => p.id == entry.key) &&
                arc.$1 == f.row &&
                target != null &&
                (target.$2 - f.x).abs() < .2;
          })) {
        cues.add(GameSfx.marusCroquette);
      }
      if (patio && f.type == 'bite') cues.add(GameSfx.marusBite);
      if (f.type == 'collect') collects++;
      if (patio && (f.type == 'hit' || f.type == 'ice')) {
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
    if (patio && grass > 0) cues.add(GameSfx.marusHarvest);
    if (patio && sim.kills > _kills) cues.add(GameSfx.marusDefeat);
    return cues;
  }

  void reset() {
    _ready = false;
    laserActive = false;
    _projectiles.clear();
    _arcs.clear();
    _enemyPositions.clear();
    _frozen.clear();
    _cats.clear();
    _armor.clear();
    _effects.clear();
  }
}
