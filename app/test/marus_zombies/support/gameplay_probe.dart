import 'dart:math' as math;
import 'package:nuestro_rincon/marus_zombies/mz_catalog.dart';
import 'package:nuestro_rincon/marus_zombies/mz_levels.dart';
import 'package:nuestro_rincon/marus_zombies/mz_simulation.dart';

/// Test-side player. Uses only public legal actions, never grants resources or
/// writes defenders, timers, HP or RNG. Decisions every half simulated second.
const probeStrategies = [
  'reference',
  'initial',
  'defensive',
  'offensive',
  'moderate',
  'no_tuna',
  'strategic_tuna',
  'late',
  'world',
];

class GameplayProbe {
  GameplayProbe(MzLevel level, this.strategy)
    : sim = MzSimulation(level, deck: deckFor(level, strategy));
  final String strategy;
  final MzSimulation sim;
  int spent = 0, generated = 0, collected = 0, placed = 0, tunaUsed = 0;
  int maxInvaders = 0, endangeredSteps = 0;
  double damage = 0, peakPressure = 0, pressureAt = 0, nearest = 10;
  final placementKinds = <MzCat, int>{};
  final _resources = <int>{};

  static List<MzCat> deckFor(MzLevel l, String strategy) {
    final worldCat = switch (l.world) {
      MzWorld.cemetery || MzWorld.egypt => MzCat.boomerang,
      MzWorld.pirates => MzCat.spring,
      MzWorld.west => MzCat.lightning,
      MzWorld.future => MzCat.laser,
      MzWorld.patio => MzCat.catapult,
    };
    final preferred = switch (strategy) {
      'initial' => l.allowed,
      'offensive' => [
        MzCat.sunflower,
        MzCat.launcher,
        MzCat.catapult,
        MzCat.boomerang,
        MzCat.lightning,
        MzCat.laser,
        MzCat.ice,
      ],
      'defensive' => [
        MzCat.sunflower,
        MzCat.launcher,
        MzCat.barrier,
        MzCat.mine,
        MzCat.ice,
        MzCat.spring,
        MzCat.catapult,
      ],
      'world' => [
        MzCat.sunflower,
        MzCat.launcher,
        worldCat,
        MzCat.barrier,
        MzCat.ice,
        MzCat.catapult,
        MzCat.bomb,
      ],
      _ => [
        MzCat.launcher,
        MzCat.sunflower,
        MzCat.barrier,
        MzCat.ice,
        if (l.world == MzWorld.west) MzCat.mine else MzCat.bomb,
        if (l.world == MzWorld.future) MzCat.laser else MzCat.catapult,
      ],
    };
    return preferred.where(l.allowed.contains).toSet().take(6).toList();
  }

  bool place(MzCat cat, int row, int col) {
    if (!sim.deck.contains(cat) || !sim.free(row, col)) return false;
    if (strategy == 'moderate' &&
        sim.catnip - mzCats[cat]!.cost < 100 &&
        sim.invaders.every((e) => e.row != row || e.x > 4)) {
      return false;
    }
    if (!sim.place(cat, row, col)) return false;
    placed++;
    spent += mzCats[cat]!.cost;
    placementKinds.update(cat, (v) => v + 1, ifAbsent: () => 1);
    return true;
  }

  void _collect() {
    for (final p in sim.pickups.toList()) {
      if (!p.tuna && _resources.add(p.id)) generated += 25;
      if (sim.collect(p.id) && !p.tuna) collected += 25;
    }
  }

  void act() {
    _collect();
    if (strategy == 'moderate' && (sim.time * 2).round() % 4 != 0) return;
    if (strategy == 'late' &&
        sim.invaders.every((e) => e.x >= 5) &&
        sim.defenders.isEmpty) {
      return;
    }
    final rows = [...sim.level.rows]
      ..sort((a, b) {
        double closest(int row) => sim.invaders
            .where((e) => e.row == row)
            .fold(10.0, (v, e) => math.min(v, e.x));
        return closest(a).compareTo(closest(b));
      });
    for (final row in rows) {
      if (sim.level.world == MzWorld.west) place(MzCat.mine, row, 3);
      if (strategy == 'offensive') place(MzCat.launcher, row, 1);
      place(MzCat.sunflower, row, 0);
      place(MzCat.launcher, row, 1);
    }
    for (final row in rows) {
      final threat = sim.invaders.any((e) => e.row == row && e.x < 4.8);
      if (threat || strategy == 'defensive') place(MzCat.barrier, row, 4);
      if (strategy == 'defensive' || strategy == 'initial') {
        place(MzCat.mine, row, 5);
      }
      place(MzCat.ice, row, 2);
      if (strategy == 'world') {
        switch (sim.level.world) {
          case MzWorld.cemetery || MzWorld.egypt:
            place(MzCat.boomerang, row, 3);
          case MzWorld.pirates:
            place(MzCat.spring, row, 5);
          case MzWorld.west:
            place(MzCat.lightning, row, 3);
          case MzWorld.future:
            place(MzCat.laser, row, 3);
          case MzWorld.patio:
            place(MzCat.catapult, row, 3);
        }
      }
      place(MzCat.catapult, row, 3);
      place(MzCat.laser, row, 3);
      if (strategy == 'offensive') {
        place(MzCat.boomerang, row, 2);
        place(MzCat.lightning, row, 4);
        place(MzCat.laser, row, 5);
      }
      if (threat &&
          sim.invaders.any((e) => e.row == row && (e.x - 5.5).abs() < 1.5)) {
        place(MzCat.bomb, row, 5);
      }
    }
    if (strategy == 'no_tuna' || strategy == 'initial' || sim.tuna == 0) return;
    final target = strategy == 'strategic_tuna'
        ? sim.defenders
              .where(
                (d) =>
                    d.kind != MzCat.sunflower &&
                    d.kind != MzCat.bomb &&
                    sim.invaders.any((e) => e.row == d.row && e.x < 5),
              )
              .firstOrNull
        : sim.defenders.where((d) => d.kind == MzCat.sunflower).firstOrNull;
    if (target != null && sim.feed(target.row, target.col)) tunaUsed++;
    _collect();
  }

  void tick() {
    act();
    final previous = {for (final d in sim.defenders) d.id: d.hp + d.armor};
    sim.advance(.5);
    for (final d in sim.defenders) {
      if (previous.containsKey(d.id)) {
        damage += math.max(0, previous[d.id]! - d.hp - d.armor);
      }
    }
    _collect();
    maxInvaders = math.max(maxInvaders, sim.invaders.length);
    final pressure = sim.invaders.fold(
      0.0,
      (v, e) => v + math.max(0, 10 - e.x),
    );
    if (pressure > peakPressure) {
      peakPressure = pressure;
      pressureAt = sim.time;
    }
    for (final e in sim.invaders) {
      nearest = math.min(nearest, e.x);
    }
    if (sim.invaders.any((e) => e.x < 1.5)) endangeredSteps++;
  }

  Map<String, Object> run() {
    for (var i = 0; i < 1800 && !sim.ended; i++) {
      tick();
    }
    return {
      'mission': mzCampaignNumber(sim.level.id), 'id': sim.level.id,
      'world': sim.level.world.name, 'strategy': strategy,
      'deck': sim.deck.map((c) => c.name).join('|'),
      'seconds': double.parse(sim.time.toStringAsFixed(2)),
      'result': sim.won
          ? 'win'
          : sim.lost
          ? 'loss'
          : 'timeout',
      'generated': generated, 'collected': collected, 'spent': spent,
      'placed': placed, 'lost': sim.losses, 'remaining': sim.catnip,
      'kills': sim.kills, 'roombas': sim.roombas.where((v) => !v).length,
      // Conservative lower bound: loss of HP/armor on surviving defenders only.
      'survivorDamage': damage.round(), 'dangerSeconds': endangeredSteps * .5,
      'nearestX': double.parse(nearest.toStringAsFixed(2)), 'tuna': tunaUsed,
      'stars': sim.stars, 'maxInvaders': maxInvaders,
      'peakPressureAt': double.parse(pressureAt.toStringAsFixed(2)),
      'placementsByCat': placementKinds.entries
          .map((e) => '${e.key.name}:${e.value}')
          .join('|'),
    };
  }
}
