import 'package:flutter_test/flutter_test.dart';
import 'package:nuestro_rincon/marus_zombies/mz_catalog.dart';
import 'package:nuestro_rincon/marus_zombies/mz_levels.dart';
import 'package:nuestro_rincon/marus_zombies/mz_simulation.dart';
import 'package:nuestro_rincon/marus_zombies/mz_visual_feedback.dart';
import 'package:nuestro_rincon/marus_zombies/mz_models.dart';
import 'package:nuestro_rincon/marus_zombies/mz_art_style.dart';

void main() {
  test(
    'piano animation observes real special actions and freezes when paused',
    () {
      final s = MzSimulation(const MzLevel(8));
      s.spawn(MzEnemy.pianist, 2, x: 8);
      final e = s.invaders.single;
      final art = MzVisualFeedback()..observe(s);
      expect(art.performance(e.id, s.time), 0);
      e.special = .02;
      for (var i = 0; i < 3; i++) {
        s.advance(1 / 60);
        final before = s.toJson();
        art.observe(s);
        expect(s.toJson(), before);
      }
      final pulse = art.performance(e.id, s.time);
      expect(pulse, greaterThan(0));
      s.paused = true;
      s.advance(1);
      art.observe(s);
      expect(art.performance(e.id, s.time), pulse);
      s.paused = false;
      for (var i = 0; i < 40; i++) {
        s.advance(1 / 60);
        art.observe(s);
      }
      expect(art.performance(e.id, s.time), 0);
      art.reset();
      expect(art.performance(e.id, s.time), 0);
    },
  );
  test(
    'anticipation cancels when the real target disappears and does not change combat',
    () {
      final s = MzSimulation(const MzLevel(8));
      s.place(MzCat.launcher, 2, 1);
      final d = s.defenders.single..attack = .09;
      final art = MzVisualFeedback()..observe(s);
      expect(art.prepare(d, s), 0);
      s.spawn(MzEnemy.common, 2, x: 6);
      final before = s.toJson();
      expect(art.prepare(d, s), closeTo(.5, .001));
      art.observe(s);
      expect(s.toJson(), before);
      s.invaders.clear();
      expect(art.prepare(d, s), 0);
      expect(art.attack(d.id, s.time), 0);
    },
  );
  test(
    'projectile trails and defeated cutouts are bounded, paused and transient',
    () {
      final s = MzSimulation(const MzLevel(8));
      s.place(MzCat.launcher, 2, 1);
      s.spawn(MzEnemy.common, 2, x: 6);
      final e = s.invaders.single;
      final art = MzVisualFeedback()..observe(s);
      for (var i = 0; i < 32; i++) {
        s.advance(1 / 60);
        art.observe(s);
      }
      final shot = s.projectiles.single;
      expect(
        art.trail(shot.id).length,
        lessThanOrEqualTo(MzArt.maxTrailSamples),
      );
      s.hit(e, 10000);
      s.advance(1 / 60);
      art.observe(s);
      final ghost = art.events.singleWhere((v) => v.type == 'defeat');
      final pose = ghost.progress(s.time);
      final snapshot = s.toJson();
      expect(s.invaders, isEmpty);
      expect(snapshot.containsKey('visuals'), false);
      s.paused = true;
      s.advance(1);
      art.observe(s);
      expect(ghost.progress(s.time), pose);
      s.paused = false;
      s.advance(.4);
      art.observe(s);
      expect(art.events.where((v) => v.type == 'defeat'), isEmpty);
      art.reset();
      expect(art.events, isEmpty);
      expect(art.trail(shot.id), isEmpty);
    },
  );
  test('removing with the shovel produces no defeated ghost', () {
    final s = MzSimulation(const MzLevel(8));
    s.place(MzCat.launcher, 2, 1);
    final art = MzVisualFeedback()..observe(s);
    s.remove(2, 1);
    art.observe(s);
    expect(art.events.where((v) => v.type == 'defeat'), isEmpty);
  });
  test(
    'mass damage remains within the visual budget and never changes the snapshot',
    () {
      final s = MzSimulation(const MzLevel(8));
      for (var i = 0; i < 80; i++) {
        s.spawn(MzEnemy.bucket, i % 5, x: 6 + i % 3 * .3);
      }
      final art = MzVisualFeedback()..observe(s);
      for (final e in s.invaders) {
        s.hit(e, 20);
      }
      final before = s.toJson();
      art.observe(s);
      expect(art.events.length, lessThanOrEqualTo(MzArt.maxVisualEvents));
      expect(s.toJson(), before);
    },
  );
  test('mine readiness and terrain targets use existing mechanics', () {
    final s = MzSimulation(const MzLevel(58));
    final d = MzDefender(100, MzCat.launcher, 0, 1)..attack = .09;
    final art = MzVisualFeedback();
    expect(art.prepare(d, s), greaterThan(0));
    s.tombs.clear();
    expect(art.prepare(d, s), 0);
    final mine = MzDefender(101, MzCat.mine, 2, 1)..age = 7.9;
    s.spawn(MzEnemy.common, 2, x: 2.35);
    expect(art.prepare(mine, s), 0);
    mine.age = 8;
    expect(art.prepare(mine, s), greaterThan(0));
  });
  test(
    'art reacts to actual shots and armor damage without mutating snapshots',
    () {
      final s = MzSimulation(const MzLevel(8));
      s.place(MzCat.launcher, 2, 1);
      s.spawn(MzEnemy.bucket, 2, x: 6);
      final d = s.defenders.single, e = s.invaders.single;
      final art = MzVisualFeedback()..observe(s);
      expect(art.attack(d.id, s.time), 0);
      s.advance(.5);
      final before = s.toJson();
      art.observe(s);
      expect(s.toJson(), before);
      expect(art.attack(d.id, s.time), greaterThan(0));
      expect(art.walking(e.id), true);
      s.hit(e, 20);
      final damaged = s.toJson();
      art.observe(s);
      expect(s.toJson(), damaged);
      expect(art.hurt(e.id, s.time), greaterThan(0));
      expect(e.hp, e.kind.health); // Damage was absorbed by armor.
    },
  );

  test(
    'feedback freezes on pause and expires or resets without saving visual state',
    () {
      final s = MzSimulation(const MzLevel(8));
      s.spawn(MzEnemy.bucket, 2, x: 6);
      final e = s.invaders.single;
      final art = MzVisualFeedback()..observe(s);
      s.hit(e, 20);
      art.observe(s);
      final pulse = art.hurt(e.id, s.time);
      s.paused = true;
      s.advance(1);
      art.observe(s);
      expect(art.hurt(e.id, s.time), pulse);
      expect(art.walking(e.id), false);
      s.paused = false;
      s.advance(.3);
      art.observe(s);
      expect(art.hurt(e.id, s.time), 0);
      s.hit(e, 20);
      art.observe(s);
      art.reset();
      expect(art.hurt(e.id, s.time), 0);
      expect(MzSimulation.fromJson(s.toJson()).invaders.single.armor, e.armor);
    },
  );
}
