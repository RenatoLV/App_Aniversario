import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:nuestro_rincon/marus_zombies/mz_catalog.dart';
import 'package:nuestro_rincon/marus_zombies/mz_levels.dart';
import 'package:nuestro_rincon/marus_zombies/mz_models.dart';
import 'package:nuestro_rincon/marus_zombies/mz_simulation.dart';

MzSimulation sandbox([int id = 9]) =>
    MzSimulation(MzLevel(id), deck: MzCat.values)
      ..spawnIndex = MzLevel(id).spawns.length
      ..catnip = 10000;

void main() {
  test(
    'human laser attracts for two seconds, then pushes and deals pair damage once',
    () {
      final s = sandbox();
      s.spawn(MzEnemy.bucket, 2, x: 6);
      s.spawn(MzEnemy.bucket, 2, x: 6.3);
      expect(s.human(MzPower.pointer, 2, 5.5), true);
      s.advance(1);
      expect(s.invaders.first.x, closeTo(5.5, .1));
      final restored = MzSimulation.fromJson(s.toJson())..paused = false;
      restored.advance(1.2);
      expect(restored.invaders.first.x, greaterThan(7));
      expect(restored.invaders.map((e) => e.armor), everyElement(550));
      restored.advance(1);
      expect(restored.invaders.map((e) => e.armor), everyElement(550));
    },
  );
  test('boomerang hits three invaders once on each leg of its return', () {
    final s = sandbox(19);
    final d = MzDefender(101, MzCat.boomerang, 2, 1);
    for (var i = 0; i < 4; i++) {
      s.spawn(MzEnemy.bucket, 2, x: 3.0 + i);
    }
    s.fish(d, 20);
    s.advance(2);
    expect(s.invaders.take(3).map((e) => e.armor), everyElement(560));
    expect(s.invaders.last.armor, 600);
    expect(s.projectiles, isEmpty);
  });
  test(
    'six premium bursts with sixty invaders keep gameplay and snapshots bounded',
    () {
      final s = sandbox(49)..tuna = 3;
      for (var i = 0; i < 60; i++) {
        s.spawn(MzEnemy.bucket, i % 5, x: 5 + (i ~/ 5) * .1);
      }
      for (var i = 0; i < 6; i++) {
        s.defenders.add(
          MzDefender(1000 + i, MzCat.launcher, i % 5, i ~/ 5)..burstLeft = 60,
        );
      }
      s.advance(10);
      expect(s.projectiles.length, lessThan(400));
      expect(s.effects.length, lessThanOrEqualTo(120));
      expect(jsonEncode(s.toJson()).length, lessThan(100000));
      expect(s.defenders.every((d) => d.burstLeft == 0), true);
    },
  );
  test('invalid placements never consume resources or cooldown', () {
    final s = MzSimulation(const MzLevel(0));
    expect(s.place(MzCat.launcher, 0, 1), false);
    expect(s.place(MzCat.launcher, 1, 1), true);
    final money = s.catnip;
    expect(s.place(MzCat.launcher, 1, 1), false);
    expect(s.catnip, money);
    expect(s.place(MzCat.launcher, 2, 1), false);
    expect(s.catnip, money);
  });
  test(
    'armor absorbs damage and carries excess into health; laser ignores it',
    () {
      final s = sandbox();
      s.spawn(MzEnemy.cone, 2);
      final e = s.invaders.single;
      s.hit(e, 250);
      expect(e.armor, 0);
      expect(e.hp, 150);
      e.armor = 600;
      s.hit(e, 100, pierce: true);
      expect(e.hp, 50);
      expect(e.armor, 600);
    },
  );
  test('projectiles hit during a long frame and freezing has immunity', () {
    final s = sandbox();
    s.spawn(MzEnemy.common, 2, x: 2);
    s.projectiles.add(MzProjectile(99, 2, 0, 200));
    s.advance(1);
    expect(s.invaders, isEmpty);
    expect(s.won, true);
    final e = MzInvader(100, MzEnemy.common, 2);
    s.freeze(e, 2);
    final until = e.frozenUntil;
    s.freeze(e, 2);
    expect(e.frozenUntil, until);
  });
  test('five Roombas are external one-shot defenses and next breach loses', () {
    final s = sandbox();
    s.spawn(MzEnemy.common, 2, x: -.2);
    s.spawn(MzEnemy.bucket, 2, x: 6);
    s.advance(2);
    expect(s.roombas[2], false);
    expect(s.invaders, isEmpty);
    s.won = false;
    s.roombaX[2] = 11;
    s.spawn(MzEnemy.common, 2, x: -.2);
    s.advance(.1);
    expect(s.lost, true);
  });
  test('projectile kill at boundary resolves before home invasion', () {
    final s = sandbox()..roombas[2] = false;
    s.spawn(MzEnemy.common, 2, x: -.2);
    s.projectiles.add(MzProjectile(99, 2, -.5, 200));
    s.advance(MzSimulation.step);
    expect(s.won, true);
    expect(s.lost, false);
  });
  test('premium sunflower and mine copying obey inventory and capacity', () {
    final s = sandbox()..tuna = 3;
    s.place(MzCat.sunflower, 2, 1);
    expect(s.feed(2, 1), true);
    expect(s.pickups.length, 15);
    for (final p in s.pickups.toList()) {
      s.collect(p.id);
    }
    expect(s.catnip, 10325);
    s.place(MzCat.mine, 2, 2);
    expect(s.feed(2, 2), true);
    expect(s.defenders.where((d) => d.kind == MzCat.mine).length, 3);
    expect(
      s.defenders.where((d) => d.kind == MzCat.mine).every((d) => d.armed),
      true,
    );
    final full = sandbox()..tuna = 1;
    for (var r = 0; r < 5; r++) {
      for (var c = 0; c < 9; c++) {
        full.defenders.add(MzDefender(r * 9 + c, MzCat.mine, r, c));
      }
    }
    expect(full.feed(0, 0), false);
    expect(full.tuna, 1);
  });
  test('future nodes activate once without recursively spawning boxes', () {
    final s = sandbox(47)..tuna = 1;
    s.defenders.addAll([
      MzDefender(101, MzCat.sunflower, 0, 1),
      MzDefender(102, MzCat.sunflower, 2, 5),
    ]);
    expect(s.node(0, 1), s.node(2, 5));
    expect(s.feed(0, 1), true);
    expect(s.tuna, 0);
    expect(s.pickups.length, 30);
  });
  test('water, pushing, tomb obstruction, and safe mine-cart movement', () {
    final pirates = sandbox(25)..bridges.clear();
    expect(pirates.place(MzCat.launcher, 1, 6), false);
    pirates.spawn(MzEnemy.bucket, 1, x: 5.8);
    pirates.push(pirates.invaders.single, 1.5);
    expect(pirates.invaders.single.alive, false);
    final egypt = sandbox(55);
    egypt.spawn(MzEnemy.common, 0, x: 7);
    egypt.projectiles.add(MzProjectile(99, 0, 4.9, 20));
    egypt.advance(.2);
    expect(egypt.tombs[5], 200);
    expect(egypt.invaders.single.hp, 200);
    final west = sandbox(35);
    west.place(MzCat.launcher, 0, 1);
    expect(west.moveCart(0, 2), false);
    expect(west.moveCart(0, 1), true);
    expect(west.at(1, 1)?.kind, MzCat.launcher);
    expect(west.at(0, 1), null);
  });
  test(
    'parrot returns its hostage on defeat; boss resists execution and pushes',
    () {
      final s = sandbox(29);
      s.place(MzCat.launcher, 2, 3);
      s.spawn(MzEnemy.parrot, 2, x: 3.5);
      s.advance(.02);
      expect(s.captives.length, 1);
      s.hit(s.invaders.single, 1000);
      s.advance(.02);
      expect(s.at(2, 3), isNotNull);
      expect(s.captives, isEmpty);
      final b = sandbox(49);
      b.spawn(MzEnemy.boss, 2, x: 8);
      b.push(b.invaders.single, 20);
      expect(b.invaders.single.x, 8.7);
      expect(b.human(MzPower.pinch, 2, 8), true);
      expect(b.invaders.single.hp, 11750);
    },
  );
  test(
    'pause is real; frame division and suspended snapshots preserve combat',
    () {
      final a = MzSimulation(const MzLevel(8), deck: MzCat.values)
        ..autoCollect = true;
      a.place(MzCat.sunflower, 2, 0);
      a.place(MzCat.launcher, 2, 1);
      final b = MzSimulation.fromJson(
        jsonDecode(jsonEncode(a.toJson())) as Map<String, dynamic>,
      )..paused = false;
      a.advance(20);
      for (var i = 0; i < 1200; i++) {
        b.advance(MzSimulation.step);
      }
      final ja = a.toJson(), jb = b.toJson();
      ja.remove('accumulator');
      jb.remove('accumulator');
      expect(jb, ja);
      b.paused = true;
      final before = jsonEncode(b.toJson());
      b.advance(30);
      expect(jsonEncode(b.toJson()), before);
    },
  );
  test(
    'all sixty levels have legal lanes, finite schedules and introductions',
    () {
      for (final level in mzCampaign) {
        expect(level.spawns, isNotEmpty);
        expect(level.spawns.every((s) => level.rows.contains(s.row)), true);
        expect(level.allowed, contains(MzCat.launcher));
        expect(level.spawns.last.time, lessThan(400));
      }
      expect(mzCampaign.last.spawns.any((s) => s.kind == MzEnemy.boss), true);
    },
  );
  test('first mission can be won without paid powers or tuna', () {
    final s = MzSimulation(const MzLevel(0))..autoCollect = true;
    for (var i = 0; i < 300 && !s.ended; i++) {
      for (final row in s.level.rows) {
        if (s.at(row, 1) == null) s.place(MzCat.launcher, row, 1);
      }
      s.advance(1);
    }
    expect(s.won, true);
    expect(s.lost, false);
    expect(s.stars, 3);
  });
}
