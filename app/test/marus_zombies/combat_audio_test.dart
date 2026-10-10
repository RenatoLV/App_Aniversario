import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:nuestro_rincon/game_audio.dart';
import 'package:nuestro_rincon/marus_zombies/mz_combat_audio.dart';
import 'package:nuestro_rincon/marus_zombies/mz_catalog.dart';
import 'package:nuestro_rincon/marus_zombies/mz_levels.dart';
import 'package:nuestro_rincon/marus_zombies/mz_models.dart';
import 'package:nuestro_rincon/marus_zombies/mz_simulation.dart';

List<GameSfx> advance(MzCombatAudio a, MzSimulation s, double dt) {
  a.capture(s);
  s.advance(dt);
  return a.events(s);
}

MzSimulation lawn() => MzSimulation(const MzLevel(8));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'launcher sounds only when it actually fires; repaint and idle are silent',
    () {
      final s = lawn()..place(MzCat.launcher, 2, 1);
      final a = MzCombatAudio();
      expect(advance(a, s, .5), isEmpty);
      s.spawn(MzEnemy.common, 2, x: 7);
      expect(advance(a, s, 1 / 60), contains(GameSfx.marusLauncher));
      expect(s.projectiles, isNotEmpty);
      expect(a.events(s), isEmpty);
      expect(advance(a, s, 1 / 60), isEmpty);
    },
  );
  test('ice and other cats do not receive launcher audio', () {
    final s = lawn()
      ..place(MzCat.ice, 2, 1)
      ..spawn(MzEnemy.common, 2, x: 7);
    final a = MzCombatAudio();
    expect(advance(a, s, .5), isNot(contains(GameSfx.marusLauncher)));
  });
  test('tuna launcher burst is real but does not flood the voice pool', () {
    final s = lawn()
      ..place(MzCat.launcher, 2, 1)
      ..spawn(MzEnemy.bucket, 2, x: 7);
    s.defenders.single.burstLeft = 60;
    final a = MzCombatAudio(), mix = CombatSfxLimiter(random: Random(1));
    var accepted = 0;
    for (var i = 0; i < 60; i++) {
      final events = advance(a, s, 1 / 60);
      accepted += mix.select(events, (i * 1000 / 60).round()).length;
    }
    expect(s.defenders.single.burstLeft, lessThan(60));
    expect(accepted, inInclusiveRange(1, 9));
  });
  test('real auto-collected grass sounds; tuna and expiry do not', () {
    final s = lawn()..autoCollect = true;
    s.pickups.addAll([MzPickup(90, 2, 2), MzPickup(91, 2, 3, tuna: true)]);
    final a = MzCombatAudio();
    expect(advance(a, s, 1 / 60), [GameSfx.marusHarvest]);
    s.pickups.add(MzPickup(92, 2, 3, tuna: true));
    expect(advance(a, s, 1 / 60), isEmpty);
    s.autoCollect = false;
    s.pickups.add(MzPickup(93, 2, 3, ttl: .001));
    expect(advance(a, s, 1 / 60), isEmpty);
    s.autoCollect = true;
    s.sky = 0;
    expect(advance(a, s, 1 / 60), [GameSfx.marusHarvest]);
  });
  test('mordida follows the bite effect, not walking or an animation', () {
    final s = lawn()
      ..place(MzCat.barrier, 2, 1)
      ..spawn(MzEnemy.common, 2, x: 1.8);
    final a = MzCombatAudio();
    final hp = s.defenders.single.hp;
    expect(advance(a, s, 1 / 60), contains(GameSfx.marusBite));
    expect(s.defenders.single.hp, hp - 50);
    expect(advance(a, s, .2), isEmpty);
    s.invaders.single.frozenUntil = s.time + 3;
    expect(advance(a, s, 1), isEmpty);
  });
  test(
    'armor uses actual projectile contact and absorption; piercing stays silent',
    () {
      final s = lawn()..spawn(MzEnemy.bucket, 2, x: 3);
      s.projectiles.add(MzProjectile(90, 2, 2.8, 20));
      final a = MzCombatAudio();
      expect(advance(a, s, 1 / 60), contains(GameSfx.marusArmor));
      a.capture(s);
      s.hit(s.invaders.single, 20, pierce: true);
      s.effect(2, s.invaders.single.x, 'hit');
      expect(a.events(s), isNot(contains(GameSfx.marusArmor)));
    },
  );
  test('defeat follows a real kill; removal and shovel are silent', () {
    final s = lawn()..spawn(MzEnemy.common, 2, x: 3);
    s.projectiles.add(MzProjectile(90, 2, 2.8, 1000));
    final a = MzCombatAudio();
    expect(advance(a, s, 1 / 60), contains(GameSfx.marusDefeat));
    s.spawn(MzEnemy.common, 2, x: 7);
    a.capture(s);
    s.invaders.clear();
    expect(a.events(s), isEmpty);
  });
  test(
    'pause, other worlds and restored snapshots generate no catch-up cues',
    () {
      final s = lawn()
        ..spawn(MzEnemy.common, 2, x: 7)
        ..paused = true;
      final a = MzCombatAudio();
      expect(advance(a, s, .5), isEmpty);
      final egypt = MzSimulation(const MzLevel(15))
        ..place(MzCat.launcher, 2, 1)
        ..spawn(MzEnemy.common, 2, x: 7);
      expect(advance(a, egypt, .5), isEmpty);
      final restored = MzSimulation.fromJson(s.toJson());
      expect(a.events(restored), isEmpty);
    },
  );
  test('voice limits, priorities, small variation and silent states', () {
    final mix = CombatSfxLimiter(random: Random(5));
    final all = CombatSfxLimiter.priorities.keys;
    var count = 0;
    for (var ms = 0; ms < 1000; ms += 10) {
      final accepted = mix.select([...all, ...all, ...all], ms);
      expect(accepted.length, lessThanOrEqualTo(2));
      for (final r in accepted) {
        expect(r.slot, inInclusiveRange(0, 3));
        expect(r.rate, inInclusiveRange(.97, 1.03));
        expect(
          r.gain,
          inInclusiveRange(r.effect.gain * .92, r.effect.gain * 1.08),
        );
      }
      count += accepted.length;
    }
    expect(count, lessThanOrEqualTo(10));
    expect(mix.select(all, 2000, audible: false), isEmpty);
    final next = mix.select(all, 2001);
    expect(next.map((r) => r.effect), [
      GameSfx.marusHarvest,
      GameSfx.marusDefeat,
    ]);
    expect(
      mix.select(all, 2001).map((r) => r.effect),
      isNot(contains(GameSfx.marusHarvest)),
    );
  });
  test('observation and independent audio RNG never modify a checkpoint', () {
    final s = lawn()
      ..place(MzCat.launcher, 2, 1)
      ..spawn(MzEnemy.bucket, 2, x: 7);
    final control = MzSimulation.fromJson(s.toJson())..paused = false;
    final a = MzCombatAudio(), mix = CombatSfxLimiter(random: Random(999));
    for (var i = 0; i < 180; i++) {
      final events = advance(a, s, 1 / 60);
      mix.select(events, i * 17);
      control.advance(1 / 60);
      expect(s.toJson(), control.toJson());
    }
  });
  test(
    'all five short PCM assets are bundled; revelation remains independent',
    () async {
      for (final cue in CombatSfxLimiter.priorities.keys) {
        final b = await rootBundle.load('assets/audio/${cue.file}');
        expect(String.fromCharCodes(b.buffer.asUint8List(0, 4)), 'RIFF');
        expect(b.lengthInBytes, lessThan(40000));
      }
      expect(
        CombatSfxLimiter.priorities.containsKey(GameSfx.marusCardVictory),
        false,
      );
    },
  );
  test(
    'render an equivalent real-event audio comparison',
    () {
      final s = lawn()..autoCollect = true;
      for (var row = 0; row < 5; row++) {
        s.defenders.add(MzDefender(200 + row, MzCat.launcher, row, 1));
        s.defenders.add(MzDefender(210 + row, MzCat.barrier, row, 2));
        s.spawn(MzEnemy.cone, row, x: 3.2);
        s.invaders.last
          ..armor = 40
          ..hp = 40;
      }
      final a = MzCombatAudio(), mix = CombatSfxLimiter(random: Random(7));
      final before = <Map<String, dynamic>>[], after = <Map<String, dynamic>>[];
      var clearAt = -10000;
      for (var frame = 0; frame < 1200; frame++) {
        final now = (frame * 1000 / 60).round();
        if (frame == 120 || frame == 480) {
          final p = MzPickup(3000 + frame, 2, 3);
          s.pickups.add(p);
          if (s.collect(p.id)) {
            before.add({
              'ms': now,
              'asset': 'coin.wav',
              'slot': 'coin',
              'gain': GameSfx.coin.gain * .8,
            });
            for (final r in mix.select([GameSfx.marusHarvest], now)) {
              after.add({
                'ms': now,
                'asset': r.asset,
                'slot': r.slot,
                'gain': r.gain * .8,
              });
            }
          }
        }
        final kills = s.kills;
        final cues = advance(a, s, 1 / 60);
        if (s.kills > kills && now - clearAt >= GameSfx.clear.cooldownMs) {
          before.add({
            'ms': now,
            'asset': 'clear.wav',
            'slot': 'clear',
            'gain': GameSfx.clear.gain * .8,
          });
          clearAt = now;
        }
        for (final r in mix.select(cues, now)) {
          after.add({
            'ms': now,
            'asset': r.asset,
            'slot': r.slot,
            'gain': r.gain * .8,
          });
        }
      }
      expect(
        after.any((c) => c['asset'].toString().startsWith('marus_launcher')),
        true,
      );
      expect(
        after.any((c) => c['asset'].toString().startsWith('marus_bite')),
        true,
      );
      expect(
        after.any((c) => c['asset'].toString().startsWith('marus_armor')),
        true,
      );
      expect(
        after.any((c) => c['asset'].toString().startsWith('marus_defeat')),
        true,
      );
      File('build/previews/mz-combat-audio-ledger.json')
        ..parent.createSync(recursive: true)
        ..writeAsStringSync(
          jsonEncode({'durationMs': 20000, 'before': before, 'after': after}),
        );
    },
    skip: !const bool.fromEnvironment('RENDER_COMBAT_AUDIO'),
  );
  test(
    'CPU comparison under a 100-invader wave',
    () {
      final results = <String, dynamic>{};
      for (final sound in [false, true]) {
        final samples = <double>[];
        for (var round = 0; round < 5; round++) {
          final s = lawn();
          for (var row = 0; row < 5; row++) {
            s.defenders.add(MzDefender(200 + row, MzCat.barrier, row, 1));
          }
          for (var n = 0; n < 100; n++) {
            s.spawn(MzEnemy.bucket, n % 5, x: 1.8);
          }
          final a = MzCombatAudio(), mix = CombatSfxLimiter(random: Random(2));
          final watch = Stopwatch()..start();
          for (var frame = 0; frame < 120; frame++) {
            if (sound) a.capture(s);
            s.advance(1 / 60);
            if (sound) mix.select(a.events(s), frame * 17);
          }
          watch.stop();
          samples.add(watch.elapsedMicroseconds / 120000);
        }
        samples.sort();
        results[sound ? 'audio' : 'baseline'] = {
          'medianMs': samples[2],
          'batchesMs': samples,
        };
      }
      File('build/previews/mz-combat-audio-profile.json')
        ..parent.createSync(recursive: true)
        ..writeAsStringSync(jsonEncode(results));
    },
    skip: !const bool.fromEnvironment('PROFILE_COMBAT_AUDIO'),
  );
}
