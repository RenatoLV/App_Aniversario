import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nuestro_rincon/store.dart';
import 'package:nuestro_rincon/match3.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('Rewards and achievements remain claimed after reopening', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final store = GameStore(prefs);
    final initial = store.coins;
    await store.rewardGameCoins('sweet:round:blast:1', 5);
    await store.rewardGameCoins('sweet:round:win', 100);
    await store.rewardGameCoins('bomber:round:maru:win', 150);
    await store.unlockAchievement('sweet:5');
    final restored = GameStore(prefs);
    await restored.rewardGameCoins('sweet:round:blast:1', 5);
    await restored.rewardGameCoins('sweet:round:win', 100);
    await restored.rewardGameCoins('bomber:round:maru:win', 150);
    await restored.unlockAchievement('sweet:5');
    expect(restored.coins, initial + 755);
    expect(restored.bomberWins, 1);
    expect(restored.achievementUnlocked('sweet:5'), isTrue);
  });
  test('Candy explosion count persists and a rejected move earns nothing', () {
    final game = SweetGame(seed: 42);
    expect(game.move(0, 80), isFalse);
    expect(game.explosions, 0);
    expect(game.hammer(0), isTrue);
    expect(game.explosions, greaterThan(0));
    final restored = SweetGame.fromJson(game.toJson());
    expect(restored.explosions, game.explosions);
    final oldSave = game.toJson()..remove('explosions');
    expect(SweetGame.fromJson(oldSave).explosions, 0);
  });
}
