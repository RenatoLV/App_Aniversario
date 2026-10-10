import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nuestro_rincon/progress_sync.dart';
import 'package:nuestro_rincon/marus_zombies/mz_catalog.dart';
import 'package:nuestro_rincon/marus_zombies/mz_levels.dart';
import 'package:nuestro_rincon/marus_zombies/mz_progress.dart';
import 'package:nuestro_rincon/marus_zombies/mz_simulation.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'concurrent settings and duplicate completions preserve all changes',
    () async {
      final p = MzProgress(await SharedPreferences.getInstance());
      await Future.wait([p.configure(auto: true), p.configure(reduced: true)]);
      expect(p.autoCollect, true);
      expect(p.reducedMotion, true);
      final s = MzSimulation(const MzLevel(9))..won = true;
      await Future.wait([p.complete(s), p.complete(s)]);
      expect(p.cookies, 150);
      expect(p.mints, 10);
    },
  );
  test(
    'stars, cookies, boss mints and global pending claims are idempotent',
    () async {
      final p = MzProgress(await SharedPreferences.getInstance());
      final s = MzSimulation(const MzLevel(9))..won = true;
      await p.complete(s);
      expect(p.cookies, 150);
      expect(p.mints, 10);
      expect(p.pendingWorlds, [0]);
      await p.complete(s);
      expect(p.cookies, 150);
      expect(p.mints, 10);
      expect(p.pendingWorlds, [0]);
      await p.acknowledgeWorld(0);
      expect(p.pendingWorlds, isEmpty);
    },
  );
  test('paid action debit and combat are one durable snapshot', () async {
    final prefs = await SharedPreferences.getInstance(), p = MzProgress(prefs);
    await p.complete(MzSimulation(const MzLevel(9))..won = true);
    final s = MzSimulation(const MzLevel(8));
    s.buyTuna();
    await p.checkpoint(s, spent: 75);
    final restored = MzProgress(prefs);
    expect(restored.cookies, 75);
    expect(restored.resume()!.tuna, 1);
    expect(restored.resume()!.paused, true);
    expect(() => p.checkpoint(s, spent: 1000), throwsStateError);
    final backup =
        jsonDecode(ProgressSync(prefs, () {}).snapshot())
            as Map<String, dynamic>;
    expect(backup, contains(MzProgress.key));
  });
  test('incompatible saves refund recorded expenses once', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      MzProgress.key,
      jsonEncode({
        'cookies': 25,
        'expenses': 75,
        'run': {'v': -1},
        'stars': {'0': 3},
      }),
    );
    final p = MzProgress(prefs);
    await p.recoverIncompatible();
    expect(p.cookies, 100);
    expect(p.run, null);
    expect(p.highest, 1);
    await p.recoverIncompatible();
    expect(p.cookies, 100);
  });
  test(
    'challenge rewards and survival milestones cannot be farmed by retrying',
    () async {
      final p = MzProgress(await SharedPreferences.getInstance());
      final challenge = MzSimulation(
        const MzLevel(7, mode: MzMode.challenge, seed: 20261010),
      )..won = true;
      await p.complete(challenge);
      await p.complete(challenge);
      expect(p.cookies, 100);
      expect(p.mints, 5);
      final survival = MzSimulation(const MzLevel(9, mode: MzMode.survival))
        ..lost = true
        ..wave = 10;
      await p.complete(survival);
      await p.complete(survival);
      expect(p.cookies, 300);
      expect(p.mints, 15);
      expect(p.survivalBest, 10);
    },
  );
}
