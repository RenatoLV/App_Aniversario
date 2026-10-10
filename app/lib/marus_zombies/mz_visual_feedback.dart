import 'mz_art_style.dart';
import 'mz_catalog.dart';
import 'mz_models.dart';
import 'mz_simulation.dart';

/// Presentation-only observations. No timers, positions or HP are written back.
class MzVisualEvent {
  MzVisualEvent(
    this.type,
    this.row,
    this.x,
    this.start,
    this.seed, {
    this.cat,
    this.enemy,
    this.armor = false,
    this.armed = false,
  });
  final String type;
  final int row, seed;
  final double x, start;
  final MzCat? cat;
  final MzEnemy? enemy;
  final bool armor, armed;
  double get duration => type == 'defeat'
      ? .36
      : type == 'plant'
      ? .38
      : .30;
  double progress(double time) => ((time - start) / duration).clamp(0.0, 1.0);
}

class MzTrailPoint {
  const MzTrailPoint(this.x, this.time);
  final double x, time;
}

class _Snapshot {
  _Snapshot(
    this.health,
    this.armor,
    this.timer,
    this.burst,
    this.row,
    this.x, {
    this.cat,
    this.enemy,
    this.armed = false,
    this.slow = 0,
    this.special = 0,
  });
  final double health, armor, timer, x, slow, special;
  final int burst, row;
  final MzCat? cat;
  final MzEnemy? enemy;
  final bool armed;
}

class MzVisualFeedback {
  final _previous = <int, _Snapshot>{};
  final _attacks = <int, double>{}, _hits = <int, double>{};
  final _performances = <int, double>{};
  final _moving = <int, bool>{};
  final _trails = <int, List<MzTrailPoint>>{};
  final events = <MzVisualEvent>[];
  final _seenPoofs = <MzEffect>{};
  bool _initialized = false;

  Iterable<MzTrailPoint> trail(int projectile) =>
      _trails[projectile] ?? const [];

  void _event(MzVisualEvent event) {
    // Sustained lasers and tuna bursts should not create a particle storm.
    if (events.any(
      (e) =>
          e.seed == event.seed &&
          e.type == event.type &&
          event.start - e.start < .08,
    )) {
      return;
    }
    if (events.length == MzArt.maxVisualEvents) events.removeAt(0);
    events.add(event);
  }

  void observe(MzSimulation sim) {
    events.removeWhere((e) => sim.time - e.start >= e.duration);
    final poofs = sim.effects.where((f) => f.type == 'poof').toSet();
    final newPoofs = poofs.difference(_seenPoofs);
    final alive = <int>{};
    void record(int id, _Snapshot current) {
      alive.add(id);
      final previous = _previous[id];
      if (previous != null) {
        if (current.enemy == MzEnemy.pianist &&
            current.special > previous.special + .001) {
          _performances[id] = sim.time;
        }
        if (current.health < previous.health) {
          _hits[id] = sim.time;
          _event(
            MzVisualEvent(
              current.slow > previous.slow
                  ? 'iceHit'
                  : previous.armor > 0
                  ? 'metalHit'
                  : 'hit',
              current.row,
              current.x,
              sim.time,
              id,
            ),
          );
        }
        if (current.timer > previous.timer + .001 ||
            current.burst < previous.burst) {
          _attacks[id] = sim.time;
          if (current.cat != null) {
            _event(
              MzVisualEvent(
                current.cat == MzCat.sunflower ? 'harvest' : 'shot',
                current.row,
                current.x + .32,
                sim.time,
                id,
                cat: current.cat,
              ),
            );
          }
        }
        if (current.enemy != null) {
          _moving[id] = (current.x - previous.x).abs() > .00001;
        }
      } else if (_initialized && current.cat != null) {
        _event(MzVisualEvent('plant', current.row, current.x, sim.time, id));
      }
      _previous[id] = current;
    }

    for (final d in sim.defenders) {
      record(
        d.id,
        _Snapshot(
          d.hp + d.armor,
          d.armor,
          d.attack,
          d.burstLeft,
          d.row,
          d.col + .5,
          cat: d.kind,
          armed: d.armed,
        ),
      );
    }
    for (final e in sim.invaders) {
      record(
        e.id,
        _Snapshot(
          e.hp + e.armor,
          e.armor,
          e.attack,
          0,
          e.row,
          e.x,
          enemy: e.kind,
          slow: e.slowUntil,
          special: e.special,
        ),
      );
    }
    // Removal alone is not defeat: the shovel and kidnapping also remove cats.
    for (final entry in _previous.entries) {
      if (alive.contains(entry.key)) continue;
      final old = entry.value;
      if (newPoofs.any((f) => f.row == old.row && (f.x - old.x).abs() < .15)) {
        if (events.where((e) => e.type == 'defeat').length < 6) {
          _event(
            MzVisualEvent(
              'defeat',
              old.row,
              old.x,
              sim.time,
              entry.key,
              cat: old.cat,
              enemy: old.enemy,
              armor: old.armor > 0,
              armed: old.armed,
            ),
          );
        }
      }
    }
    _previous.removeWhere((id, _) => !alive.contains(id));
    _attacks.removeWhere(
      (id, t) => !alive.contains(id) || sim.time - t > MzArt.attackSeconds,
    );
    _hits.removeWhere(
      (id, t) => !alive.contains(id) || sim.time - t > MzArt.hurtSeconds,
    );
    _performances.removeWhere(
      (id, t) => !alive.contains(id) || sim.time - t > .55,
    );
    _moving.removeWhere((id, _) => !alive.contains(id));
    final shots = <int>{};
    for (final p in sim.projectiles) {
      shots.add(p.id);
      if (!_trails.containsKey(p.id) && _trails.length >= MzArt.maxTrails) {
        continue;
      }
      final points = _trails.putIfAbsent(p.id, () => []);
      if (points.isEmpty || sim.time - points.last.time >= 1 / 60 - .0001) {
        points.add(MzTrailPoint(p.x, sim.time));
        if (points.length > MzArt.maxTrailSamples) points.removeAt(0);
      }
    }
    _trails.removeWhere((id, _) => !shots.contains(id));
    _seenPoofs
      ..clear()
      ..addAll(poofs);
    _initialized = true;
  }

  /// Short anticipation requires the same real targets/terrain as combat.
  double prepare(MzDefender d, MzSimulation sim) {
    if (d.kind == MzCat.barrier || d.kind == MzCat.laser) return 0;
    if (d.kind == MzCat.bomb) return ((d.age - .62) / .18).clamp(0.0, 1.0);
    final targets = sim.targets(d);
    if (d.kind == MzCat.mine) {
      if (!d.armed) return 0;
      final near = targets.where(
        (e) => e.kind != MzEnemy.parrot && e.x < d.col + 1.45,
      );
      if (near.isEmpty) return 0;
      return ((d.col + 1.45 - near.first.x) / .25).clamp(0.0, 1.0);
    }
    var valid = d.kind == MzCat.sunflower || targets.isNotEmpty;
    if (!valid &&
        [MzCat.launcher, MzCat.ice, MzCat.boomerang].contains(d.kind)) {
      valid = sim.tombs.keys.any((k) => k ~/ 9 == d.row && k % 9 > d.col);
    }
    if (d.kind == MzCat.spring) valid = targets.any((e) => e.x < d.col + 2);
    if (!valid || d.attack <= 0 || d.attack > MzArt.anticipationSeconds) {
      return 0;
    }
    return 1 - d.attack / MzArt.anticipationSeconds;
  }

  double _pulse(Map<int, double> values, int id, double time, double duration) {
    final start = values[id];
    return start == null ? 0 : (1 - (time - start) / duration).clamp(0.0, 1.0);
  }

  double attack(int id, double time) =>
      _pulse(_attacks, id, time, MzArt.attackSeconds);
  double hurt(int id, double time) =>
      _pulse(_hits, id, time, MzArt.hurtSeconds);
  double performance(int id, double time) =>
      _pulse(_performances, id, time, .55);
  bool walking(int id) => _moving[id] ?? true;
  void reset() {
    _previous.clear();
    _attacks.clear();
    _hits.clear();
    _performances.clear();
    _moving.clear();
    _trails.clear();
    _seenPoofs.clear();
    events.clear();
    _initialized = false;
  }
}
