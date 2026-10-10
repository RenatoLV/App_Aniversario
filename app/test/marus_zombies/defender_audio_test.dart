import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:nuestro_rincon/game_audio.dart';
import 'package:nuestro_rincon/marus_zombies/mz_catalog.dart';
import 'package:nuestro_rincon/marus_zombies/mz_combat_audio.dart';
import 'package:nuestro_rincon/marus_zombies/mz_levels.dart';
import 'package:nuestro_rincon/marus_zombies/mz_models.dart';
import 'package:nuestro_rincon/marus_zombies/mz_simulation.dart';

MzSimulation fixture(MzCat cat, [int level = 45]) {
  final s = MzSimulation(MzLevel(level));
  s.defenders.add(MzDefender(s.nextId++, cat, 2, 0)..attack = 0);
  s.spawn(MzEnemy.bucket, 2, x: 3);
  s.invaders.single.hp = 10000;
  return s;
}

List<GameSfx> tick(MzCombatAudio a, MzSimulation s, [double dt = 1 / 60]) {
  a.capture(s);
  s.advance(dt);
  return a.events(s);
}

List<GameSfx> feed(MzCombatAudio a, MzSimulation s) {
  s.tuna = 3;
  a.capture(s);
  expect(s.feed(2, 0), true);
  return a.events(s);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('production and tuna are distinct from collection in every world', () {
    for (final level in [8, 15, 25, 35, 45, 55]) {
      final s = fixture(MzCat.sunflower, level), a = MzCombatAudio();
      expect(tick(a, s), contains(GameSfx.marusSun));
      expect(s.pickups.where((p) => !p.tuna).length, 1);
      expect(tick(a, s), isNot(contains(GameSfx.marusSun)));
      final special = feed(a, s);
      expect(special, contains(GameSfx.marusSunTuna));
      expect(special, isNot(contains(GameSfx.marusHarvest)));
      expect(s.pickups.length, 16);
      expect(a.events(s), isEmpty);
    }
  });
  test('ice shot and contact slow; only real tuna freezing emits freeze', () {
    final s = fixture(MzCat.ice), a = MzCombatAudio();
    expect(tick(a, s), contains(GameSfx.marusIceShot));
    var hit = false;
    for (var i = 0; i < 40; i++) {
      final cues = tick(a, s);
      hit |= cues.contains(GameSfx.marusIceHit);
      expect(cues, isNot(contains(GameSfx.marusFreeze)));
    }
    expect(hit, true);
    expect(s.invaders.single.slowUntil, greaterThan(s.time));
    expect(s.invaders.single.frozenUntil, 0);
    expect(feed(a, s), contains(GameSfx.marusFreeze));
    expect(tick(a, s), isNot(contains(GameSfx.marusFreeze)));
    // Existing immunity is a real rule: a second tuna cannot refreeze now.
    expect(feed(a, s), isNot(contains(GameSfx.marusFreeze)));
  });
  test('catapult release and targeted impact, including tuna barrage', () {
    final s = fixture(MzCat.catapult), a = MzCombatAudio();
    expect(tick(a, s), contains(GameSfx.marusCatapult));
    var impacts = 0;
    for (var i = 0; i < 40; i++) {
      impacts += tick(a, s).where((c) => c == GameSfx.marusCroquette).length;
    }
    expect(impacts, 1);
    expect(feed(a, s), contains(GameSfx.marusCatapult));
    s.invaders.clear();
    for (var i = 0; i < 5; i++) {
      expect(tick(a, s), isNot(contains(GameSfx.marusCroquette)));
    }
  });
  test('laser emits edges, never restart per frame, idle and pause silent', () {
    final s = fixture(MzCat.laser), a = MzCombatAudio();
    expect(tick(a, s), contains(GameSfx.marusLaserStart));
    expect(a.laserActive, true);
    for (var i = 0; i < 10; i++) {
      expect(tick(a, s, 2 / 60), isNot(contains(GameSfx.marusLaserStart)));
    }
    expect(feed(a, s), contains(GameSfx.marusLaserStart));
    expect(s.defenders.single.powerUntil, greaterThan(s.time));
    s.invaders.clear();
    expect(tick(a, s), contains(GameSfx.marusLaserEnd));
    expect(a.laserActive, false);
    expect(tick(a, s), isNot(contains(GameSfx.marusLaserEnd)));
    s.paused = true;
    expect(tick(a, s), isEmpty);
  });
  test('shared beam reservation leaves only three transient voices', () {
    final mix = CombatSfxLimiter(random: Random(9))..reserveBeam(true);
    var accepted = 0;
    for (var t = 0; t < 1000; t += 10) {
      final cues = mix.select(CombatSfxLimiter.priorities.keys, t);
      expect(cues.length, lessThanOrEqualTo(2));
      expect(cues.every((c) => c.slot < 3), true);
      accepted += cues.length;
    }
    expect(accepted, lessThanOrEqualTo(10));
    expect(
      mix.select(CombatSfxLimiter.priorities.keys, 1001, audible: false),
      isEmpty,
    );
  });
  test('audio and x2 transactions leave simulation checkpoint unchanged', () {
    for (final cat in [
      MzCat.sunflower,
      MzCat.ice,
      MzCat.catapult,
      MzCat.laser,
    ]) {
      final s = fixture(cat), a = MzCombatAudio();
      final control = MzSimulation.fromJson(s.toJson())..paused = false;
      for (var i = 0; i < 180; i++) {
        tick(a, s, 2 / 60);
        control.advance(2 / 60);
        expect(s.toJson(), control.toJson());
      }
    }
  });
  test(
    'render real normal/tuna transactions and compare observer CPU',
    () {
      final records = <String, dynamic>{};
      for (final cat in [
        MzCat.sunflower,
        MzCat.ice,
        MzCat.catapult,
        MzCat.laser,
      ]) {
        for (final tuna in [false, true]) {
          final s = fixture(cat), a = MzCombatAudio();
          final mix = CombatSfxLimiter(random: Random(7));
          final ledger = <Map<String, dynamic>>[];
          var beam = false;
          for (var i = 0; i < 300; i++) {
            final cues = <GameSfx>[];
            if (i == 30 && tuna) cues.addAll(feed(a, s));
            if (i == 220) s.invaders.clear();
            cues.addAll(tick(a, s));
            if (a.laserActive != beam) {
              beam = a.laserActive;
              mix.reserveBeam(beam);
              ledger.add({'ms': i * 1000 / 60, 'beam': beam});
            }
            for (final cue in mix.select(cues, (i * 1000 / 60).round())) {
              ledger.add({
                'ms': i * 1000 / 60,
                'asset': cue.asset,
                'slot': cue.slot,
                'gain': cue.gain * .8,
              });
            }
          }
          records['${cat.name}-${tuna ? 'tuna' : 'normal'}'] = ledger;
        }
      }
      final timings = <String, List<double>>{'baseline': [], 'observed': []};
      for (var round = 0; round < 5; round++) {
        for (final observe in [false, true]) {
          final s = fixture(MzCat.laser), a = MzCombatAudio();
          for (var i = 0; i < 99; i++) {
            s.spawn(MzEnemy.bucket, i % 5, x: 7);
          }
          final mix = CombatSfxLimiter(random: Random(7));
          final clock = Stopwatch()..start();
          for (var i = 0; i < 120; i++) {
            if (observe) a.capture(s);
            s.advance(1 / 60);
            if (observe) {
              final cues = a.events(s);
              if (a.laserActive != mix.beamReserved) {
                mix.reserveBeam(a.laserActive);
              }
              mix.select(cues, i * 17);
            }
          }
          clock.stop();
          timings[observe ? 'observed' : 'baseline']!.add(
            clock.elapsedMicroseconds / 120 / 1000,
          );
        }
      }
      Directory('build/previews').createSync(recursive: true);
      File(
        'build/previews/mz-defender-audio-ledger.json',
      ).writeAsStringSync(jsonEncode(records));
      File(
        'build/previews/mz-defender-audio-profile.json',
      ).writeAsStringSync(jsonEncode(timings));
    },
    skip: !const bool.fromEnvironment('RENDER_DEFENDER_AUDIO'),
  );
}
