import 'package:flutter_test/flutter_test.dart';
import 'package:nuestro_rincon/marus_zombies/mz_catalog.dart';
import 'package:nuestro_rincon/marus_zombies/mz_levels.dart';
import 'package:nuestro_rincon/marus_zombies/mz_simulation.dart';

// A conservative fixed strategy is a balance smoke test, rather than proof
// of optimal difficulty: build economy, cover lanes, reinforce under pressure.
void main() {
  test('all sixty campaign missions can be cleared without paid powers', () {
    final failed = <String>[];
    for (final id in List.generate(50, (i) => i)) {
      final level = MzLevel(id);
      final cats = [
        MzCat.launcher,
        MzCat.sunflower,
        MzCat.barrier,
        MzCat.ice,
        if (level.world == MzWorld.west) MzCat.mine else MzCat.bomb,
        id >= 40 ? MzCat.laser : MzCat.catapult,
      ].where(level.allowed.contains).toList();
      final s = MzSimulation(level, deck: cats)..autoCollect = true;
      for (var tick = 0; tick < 1800 && !s.ended; tick++) {
        final rows = [...level.rows]
          ..sort((a, b) {
            final ea = s.invaders
                .where((e) => e.row == a)
                .map((e) => e.x)
                .fold(10.0, (v, x) => x < v ? x : v);
            final eb = s.invaders
                .where((e) => e.row == b)
                .map((e) => e.x)
                .fold(10.0, (v, x) => x < v ? x : v);
            return ea.compareTo(eb);
          });
        for (final row in rows) {
          if (level.world == MzWorld.west && s.at(row, 3) == null) {
            s.place(MzCat.mine, row, 3);
          }
          if (cats.contains(MzCat.sunflower) && s.at(row, 0) == null) {
            s.place(MzCat.sunflower, row, 0);
          }
          if (s.at(row, 1) == null) s.place(MzCat.launcher, row, 1);
        }
        for (final row in rows) {
          final threat = s.invaders.any((e) => e.row == row && e.x < 4.8);
          if (threat && cats.contains(MzCat.barrier) && s.at(row, 4) == null) {
            s.place(MzCat.barrier, row, 4);
          }
          if (cats.contains(MzCat.ice) && s.at(row, 2) == null) {
            s.place(MzCat.ice, row, 2);
          }
          if (cats.contains(MzCat.catapult) && s.at(row, 3) == null) {
            s.place(MzCat.catapult, row, 3);
          }
          if (cats.contains(MzCat.laser) && s.at(row, 3) == null) {
            s.place(MzCat.laser, row, 3);
          }
          if (threat &&
              cats.contains(MzCat.bomb) &&
              s.free(row, 5) &&
              s.invaders.any((e) => e.row == row && (e.x - 5.5).abs() < 1.5)) {
            s.place(MzCat.bomb, row, 5);
          }
        }
        if (s.tuna > 0) {
          final target = s.defenders
              .where((d) => d.kind == MzCat.sunflower)
              .firstOrNull;
          if (target != null) s.feed(target.row, target.col);
        }
        s.advance(.5);
      }
      if (!s.won) {
        failed.add(
          'level $id: ${s.lost ? 'lost' : 'timeout'} at ${s.time.round()}s, ${s.kills} kills, ${s.defenders.length} defenders',
        );
      }
    }
    expect(failed, isEmpty, reason: failed.join('\n'));
  });
}
