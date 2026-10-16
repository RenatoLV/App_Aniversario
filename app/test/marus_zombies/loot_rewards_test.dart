import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nuestro_rincon/store.dart';
import 'package:nuestro_rincon/marus_zombies/mz_catalog.dart';
import 'package:nuestro_rincon/marus_zombies/mz_levels.dart';
import 'package:nuestro_rincon/marus_zombies/mz_models.dart';
import 'package:nuestro_rincon/marus_zombies/mz_progress.dart';
import 'package:nuestro_rincon/marus_zombies/mz_simulation.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('Rare death drops favor tuna; shiny enemies still guarantee tuna', () {
    final sim = MzSimulation(const MzLevel(49));
    var tuna = 0;
    final powers = <MzPower, int>{};
    for (var i = 0; i < 2000; i++) {
      sim.invaders.clear();
      sim.pickups.clear();
      sim.spawn(MzEnemy.common, 2, x: 8);
      sim.invaders.last.hp = 0;
      sim.advance(MzSimulation.step);
      for (final p in sim.pickups) {
        if (p.tuna) tuna++;
        if (p.power != null) {
          powers.update(p.power!, (n) => n + 1, ifAbsent: () => 1);
        }
      }
    }
    final special = powers.values.fold(0, (a, b) => a + b);
    expect(tuna, greaterThan(special));
    expect(special, inInclusiveRange(10, 65));
    expect(powers.keys.toSet(), MzPower.values.toSet());
    sim.invaders.clear();
    sim.pickups.clear();
    sim.spawn(MzEnemy.common, 2, shiny: true, x: 8);
    sim.invaders.last.hp = 0;
    sim.advance(MzSimulation.step);
    expect(sim.pickups.where((p) => p.tuna).length, 1);
  });

  test(
    'Free powers collect, cap, persist and only spend after a real action',
    () {
      final sim = MzSimulation(const MzLevel(49));
      for (var i = 0; i < 4; i++) {
        sim.pickups.add(MzPickup(100 + i, 2, 4, power: MzPower.pinch));
        expect(sim.collect(100 + i), i < 3);
      }
      expect(sim.freePowers[0], 3);
      expect(sim.catnip, sim.level.startingCatnip);
      expect(sim.useDroppedPower(MzPower.pinch, 2, 4.5), isFalse);
      expect(sim.freePowers[0], 3);
      final before = sim.toJson();
      final restored = MzSimulation.fromJson(before)..paused = false;
      expect(restored.freePowers[0], 3);
      restored.spawn(MzEnemy.common, 2, x: 4.5);
      expect(restored.useDroppedPower(MzPower.pinch, 2, 4.5), isTrue);
      expect(restored.freePowers[0], 2);
      expect(restored.kills, 1);
      expect(restored.useDroppedPower(MzPower.pinch, 2, 4.5), isFalse);
      expect(restored.freePowers[0], 2);
      expect((before['freePowers'] as List)[0], 3);
      final legacy = Map<String, dynamic>.from(before)..remove('freePowers');
      expect(MzSimulation.fromJson(legacy).freePowers, [0, 0, 0]);
    },
  );

  test(
    'Kill coins and level bonuses transfer once across reloads and replays',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      var progress = MzProgress(prefs);
      var wallet = GameStore(prefs);
      final initial = wallet.coins;
      final sim = MzSimulation(const MzLevel(0));
      await progress.checkpoint(sim);
      sim.kills = 5;
      await progress.checkpoint(sim);
      expect(progress.coinsEarned, 10);
      await wallet.rewardMarusCoins(progress.coinsEarned);
      await wallet.rewardMarusCoins(progress.coinsEarned);
      expect(wallet.coins, initial + 10);
      wallet.dispose();
      wallet = GameStore(prefs);
      progress = MzProgress(prefs);
      await wallet.rewardMarusCoins(progress.coinsEarned);
      expect(wallet.coins, initial + 10);
      sim.kills = 7;
      sim.won = true;
      await progress.complete(sim);
      await progress.complete(sim);
      expect(progress.coinsEarned, 114);
      await wallet.rewardMarusCoins(progress.coinsEarned);
      expect(wallet.coins, initial + 114);
      final replay = MzSimulation(const MzLevel(0));
      await progress.checkpoint(replay);
      replay.kills = 2;
      replay.won = true;
      await progress.complete(replay);
      expect(progress.coinsEarned, 143);
      await wallet.rewardMarusCoins(progress.coinsEarned);
      final loss = MzSimulation(const MzLevel(0));
      await progress.checkpoint(loss);
      loss.kills = 3;
      loss.lost = true;
      await progress.complete(loss);
      await wallet.rewardMarusCoins(progress.coinsEarned);
      expect(wallet.coins, initial + 149);
      wallet.dispose();
    },
  );
}
