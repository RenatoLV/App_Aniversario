import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
// Test fault injection into the existing shared_preferences backend, no new package.
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:nuestro_rincon/marus_zombies/mz_catalog.dart';
import 'package:nuestro_rincon/marus_zombies/mz_levels.dart';
import 'package:nuestro_rincon/marus_zombies/mz_models.dart';
import 'package:nuestro_rincon/marus_zombies/mz_progress.dart';
import 'package:nuestro_rincon/marus_zombies/mz_simulation.dart';
import 'package:nuestro_rincon/marus_zombies/mz_visual_feedback.dart';
import 'package:nuestro_rincon/marus_zombies/mz_threat_feedback.dart';

class FailingStore extends InMemorySharedPreferencesStore {
  FailingStore() : super.empty();
  bool fail = false;
  bool throwWrite = false;
  @override
  Future<bool> setValue(String type, String key, Object value) async {
    if (throwWrite) throw StateError('Simulated backend write exception');
    return fail ? false : super.setValue(type, key, value);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'failed paid checkpoint cannot leak an uncommitted run through preferences cache',
    () async {
      final previous = SharedPreferencesStorePlatform.instance;
      final store = FailingStore();
      SharedPreferencesStorePlatform.instance = store;
      addTearDown(() => SharedPreferencesStorePlatform.instance = previous);
      final prefs = await SharedPreferences.getInstance(),
          p = MzProgress(prefs);
      await p.complete(MzSimulation(const MzLevel(9))..won = true);
      final s = MzSimulation(const MzLevel(8));
      await p.checkpoint(s);
      final committed = prefs.getString(MzProgress.key);
      s.buyTuna();
      store.fail = true;
      await expectLater(p.checkpoint(s, spent: 75), throwsStateError);
      expect(p.cookies, 150);
      final reopened = MzProgress(prefs);
      expect(reopened.cookies, 150);
      expect(reopened.resume()!.tuna, 0);
      expect(prefs.getString(MzProgress.key), committed);
      store.fail = false;
      await p.checkpoint(s, spent: 75);
      expect(MzProgress(prefs).cookies, 75);
      expect(MzProgress(prefs).resume()!.tuna, 1);
      store.throwWrite = true;
      await expectLater(p.configure(reduced: true), throwsStateError);
      expect(MzProgress(prefs).reducedMotion, false);
      store.throwWrite = false;
      await p.configure(reduced: true);
      expect(MzProgress(prefs).reducedMotion, true);
    },
  );
  test(
    'boss and temporary powers survive durable checkpoint and deterministic continuation',
    () async {
      final prefs = await SharedPreferences.getInstance(),
          p = MzProgress(prefs);
      final s = MzSimulation(const MzLevel(49))..tuna = 3;
      s.defenders.add(MzDefender(s.nextId++, MzCat.laser, 2, 3));
      s.spawn(MzEnemy.boss, 2, x: 7);
      expect(s.feed(2, 3), true);
      s.advance(.5);
      await p.checkpoint(s);
      await prefs
          .reload(); // Re-read the backend rather than relying on the cache.
      final restored = MzProgress(prefs).resume()!;
      expect(restored.paused, true);
      expect(restored.invaders.single.kind, MzEnemy.boss);
      final art = MzVisualFeedback()..observe(restored);
      final threat = MzThreatFeedback(allWorlds: true)..observe(restored);
      expect(art.events, isEmpty);
      expect(threat.bossStart, isNull);
      restored.paused = false;
      expect(restored.toJson(), s.toJson());
      for (var i = 0; i < 180; i++) {
        s.advance(1 / 60);
        restored.advance(1 / 60);
        art.observe(restored);
        threat.observe(restored);
      }
      expect(restored.toJson(), s.toJson());
    },
  );
  test(
    'sequential reopen, loss and victory never duplicate rewards or checkpoint resources',
    () async {
      final prefs = await SharedPreferences.getInstance();
      for (var i = 0; i < 8; i++) {
        final p = MzProgress(prefs), s = MzSimulation(const MzLevel(0));
        s.place(MzCat.launcher, 2, 1);
        s.advance(5);
        await p.checkpoint(s);
        await prefs.reload();
        final copy = MzProgress(prefs).resume()!..paused = false;
        expect(copy.toJson(), s.toJson());
        s.lost = true;
        await p.complete(s);
        await p.complete(s);
        expect(p.cookies, 0);
        expect(p.run, isNull);
      }
      final p = MzProgress(prefs),
          won = MzSimulation(const MzLevel(0))..won = true;
      await p.complete(won);
      final earned = p.cookies;
      for (var i = 0; i < 8; i++) {
        await MzProgress(prefs).complete(won);
      }
      expect(MzProgress(prefs).cookies, earned);
      expect(MzProgress(prefs).highest, 1);
    },
  );
}
