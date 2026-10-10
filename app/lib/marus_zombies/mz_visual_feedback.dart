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
  double get duration => type == 'tuna'
      ? .9
      : type == 'freezeHit'
      ? .5
      : type == 'defeat'
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
    this.frozen = 0,
  });
  final double health, armor, timer, x, slow, special, frozen;
  final int burst, row;
  final MzCat? cat;
  final MzEnemy? enemy;
  final bool armed;
}

class MzVisualFeedback {
  /// Read-only diagnostics; no history of dead actor IDs is exposed/retained.
  int get trackedActors => _previous.length;
  int get trailCount => _trails.length;
  int get trailSamples => _trails.values.fold(0, (n, p) => n + p.length);
  final _previous = <int, _Snapshot>{};
  final _attacks = <int, double>{}, _hits = <int, double>{};
  final _performances = <int, double>{};
  final _moving = <int, bool>{};
  final _trails = <int, List<MzTrailPoint>>{};
  final events = <MzVisualEvent>[];
  final _seenPoofs = <MzEffect>{};
  final _seenTuna = <MzEffect>{}, _seenContacts = <MzEffect>{};
  final _powers = <int, double>{}, _resourceBirths = <int, double>{};
  final _poweredShots = <int>{};
  final _arcs = <int, int?>{};
  final _burstShots = <int>{}, _lastShotIds = <int>{};
  final _copyBirths = <int, double>{};
  final _seenBooms = <MzEffect>{}, _bombBooms = <MzEffect>{};
  final _seenElectric = <MzEffect>{}, _lightningEffects = <MzEffect>{};
  Set<int>? _beforeDefenders;
  Set<int>? _beforeResources, _beforeShots;
  bool _initialized = false;

  /// Capture immediately before feed(): IDs added by that transaction are real.
  void capturePower(MzSimulation sim) {
    _beforeResources = sim.pickups.map((p) => p.id).toSet();
    _beforeShots = sim.projectiles.map((p) => p.id).toSet();
    _beforeDefenders = sim.defenders.map((d) => d.id).toSet();
  }

  double power(int id, double time) => _pulse(_powers, id, time, .9);
  double? resourceBirth(int id) => _resourceBirths[id];
  bool poweredShot(int id) => _poweredShots.contains(id);
  bool burstShot(int id) => _burstShots.contains(id);
  bool bombExplosion(MzEffect effect) => _bombBooms.contains(effect);
  bool lightningEffect(MzEffect effect) => _lightningEffects.contains(effect);
  double copyPulse(int id, double time) => _pulse(_copyBirths, id, time, .55);
  bool hasPowerAt(int row, double x, double time) => events.any(
    (e) =>
        e.type == 'tuna' &&
        e.row == row &&
        (e.x - x).abs() < .01 &&
        e.progress(time) < 1,
  );

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
    final tuna = sim.effects.where((f) => f.type == 'tuna').toSet();
    final contacts = sim.effects.where((f) => f.type == 'hit').toSet();
    final newContacts = contacts.difference(_seenContacts);
    // A consumed targeted arc is an impact only if a real contact was emitted.
    final shotIds = sim.projectiles.map((p) => p.id).toSet();
    final booms = sim.effects.where((f) => f.type == 'boom').toSet();
    final electric = sim.effects.where((f) => f.type == 'electric').toSet();
    if (_initialized &&
        sim.defenders.any(
          (d) =>
              d.kind == MzCat.lightning &&
              ((_previous[d.id] != null &&
                      d.attack > _previous[d.id]!.timer + .001) ||
                  tuna
                      .difference(_seenTuna)
                      .any(
                        (f) => f.row == d.row && (f.x - d.col - .5).abs() < .01,
                      )),
        )) {
      // These are actual contact effects, not an inferred chain or new targets.
      _lightningEffects.addAll(electric.difference(_seenElectric));
    }
    if (_initialized) {
      for (final f in booms.difference(_seenBooms)) {
        if (_previous.values.any(
          (old) =>
              old.cat == MzCat.bomb &&
              old.row == f.row &&
              (old.x - f.x).abs() < .01 &&
              !sim.defenders.any(
                (d) =>
                    d.kind == MzCat.bomb &&
                    d.row == old.row &&
                    (d.col + .5 - old.x).abs() < .01,
              ),
        )) {
          _bombBooms.add(f);
        }
      }
      for (final d in sim.defenders.where((d) => d.kind == MzCat.launcher)) {
        final old = _previous[d.id];
        if (old == null || old.burst <= d.burstLeft) continue;
        _burstShots.addAll(
          sim.projectiles
              .where(
                (p) =>
                    !_lastShotIds.contains(p.id) &&
                    p.row == d.row &&
                    (p.origin - d.col - .8).abs() < .01 &&
                    p.damage < mzCats[d.kind]!.damage * sim.multiplier(d.kind),
              )
              .map((p) => p.id),
        );
      }
      if (_beforeDefenders != null &&
          tuna
              .difference(_seenTuna)
              .any(
                (f) => sim.defenders.any(
                  (d) =>
                      d.kind == MzCat.mine &&
                      d.row == f.row &&
                      (d.col + .5 - f.x).abs() < .01,
                ),
              )) {
        for (final d in sim.defenders.where(
          (d) =>
              d.kind == MzCat.mine &&
              d.armed &&
              !_beforeDefenders!.contains(d.id),
        )) {
          _copyBirths[d.id] = sim.time;
        }
      }
    }
    final croquetteTargets = <int>{};
    for (final entry in _arcs.entries) {
      if (shotIds.contains(entry.key)) continue;
      final old = _previous[entry.value];
      if (old == null ||
          !newContacts.any(
            (f) => f.row == old.row && (f.x - old.x).abs() < .4,
          )) {
        continue;
      }
      croquetteTargets.add(entry.value!);
      _event(
        MzVisualEvent('croquetteHit', old.row, old.x, sim.time, entry.value!),
      );
    }
    if (_initialized) {
      for (final f in tuna.difference(_seenTuna)) {
        final d = sim.defenders
            .where((d) => d.row == f.row && (d.col + .5 - f.x).abs() < .01)
            .firstOrNull;
        if (d == null) continue;
        _powers[d.id] = sim.time;
        _event(MzVisualEvent('tuna', d.row, f.x, sim.time, d.id, cat: d.kind));
        if (d.kind == MzCat.sunflower && _beforeResources != null) {
          for (final p in sim.pickups.where(
            (p) =>
                !p.tuna &&
                !_beforeResources!.contains(p.id) &&
                p.row == d.row &&
                p.x >= d.col + .1 &&
                p.x <= d.col + .9,
          )) {
            _resourceBirths[p.id] = sim.time;
          }
        }
        if ((d.kind == MzCat.catapult || d.kind == MzCat.boomerang) &&
            _beforeShots != null) {
          _poweredShots.addAll(
            sim.projectiles
                .where(
                  (p) =>
                      (d.kind == MzCat.catapult ? p.arc : p.fish) &&
                      !_beforeShots!.contains(p.id) &&
                      (p.origin - d.col - .8).abs() < .01,
                )
                .map((p) => p.id),
          );
        }
      }
    }
    _beforeResources = _beforeShots = null;
    _beforeDefenders = null;
    final alive = <int>{};
    void record(int id, _Snapshot current) {
      alive.add(id);
      final previous = _previous[id];
      if (previous != null) {
        if ((current.enemy == MzEnemy.pianist ||
                current.enemy == MzEnemy.boss) &&
            current.special > previous.special + .001) {
          _performances[id] = sim.time;
        }
        if (current.health < previous.health) {
          _hits[id] = sim.time;
          if (!croquetteTargets.contains(id)) {
            _event(
              MzVisualEvent(
                current.frozen > previous.frozen && current.frozen > sim.time
                    ? 'freezeHit'
                    : current.slow > previous.slow
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
        }
        if (current.frozen > previous.frozen &&
            current.frozen > sim.time &&
            current.health >= previous.health) {
          _event(
            MzVisualEvent('freezeHit', current.row, current.x, sim.time, id),
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
      } else if (_initialized &&
          current.cat != null &&
          !_copyBirths.containsKey(id)) {
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
          frozen: e.frozenUntil,
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
    _powers.removeWhere((id, t) => !alive.contains(id) || sim.time - t >= .9);
    final pickupIds = sim.pickups.map((p) => p.id).toSet();
    _resourceBirths.removeWhere(
      (id, t) => !pickupIds.contains(id) || sim.time - t >= .7,
    );
    _poweredShots.removeWhere((id) => !shotIds.contains(id));
    _burstShots.removeWhere((id) => !shotIds.contains(id));
    _lastShotIds
      ..clear()
      ..addAll(shotIds);
    _copyBirths.removeWhere(
      (id, t) => !alive.contains(id) || sim.time - t >= .55,
    );
    _bombBooms.removeWhere((f) => !booms.contains(f));
    _lightningEffects.removeWhere((f) => !electric.contains(f));
    _seenElectric
      ..clear()
      ..addAll(electric);
    _seenBooms
      ..clear()
      ..addAll(booms);
    _arcs
      ..clear()
      ..addEntries(
        sim.projectiles
            .where((p) => p.arc)
            .map((p) => MapEntry(p.id, p.target)),
      );
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
    _seenTuna
      ..clear()
      ..addAll(tuna);
    _seenContacts
      ..clear()
      ..addAll(contacts);
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
    _seenTuna.clear();
    _seenContacts.clear();
    _powers.clear();
    _resourceBirths.clear();
    _poweredShots.clear();
    _arcs.clear();
    _burstShots.clear();
    _lastShotIds.clear();
    _copyBirths.clear();
    _seenBooms.clear();
    _bombBooms.clear();
    _seenElectric.clear();
    _lightningEffects.clear();
    _beforeDefenders = null;
    _beforeResources = _beforeShots = null;
    events.clear();
    _initialized = false;
  }
}
