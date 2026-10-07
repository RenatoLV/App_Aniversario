import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nuestro_rincon/football_game.dart';
import 'package:nuestro_rincon/store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  FootballResult run(
    Offset end,
    double seconds, {
    double frame = 1 / 60,
    int difficulty = 0,
  }) {
    FootballResult? outcome;
    final game = FootballGame(onResult: (r, _, _) => outcome = r)
      ..goals = difficulty;
    expect(game.shoot(FootballGame.origin, end, seconds), isTrue);
    for (var t = 0.0; t < 6 && outcome == null; t += frame) {
      game.tick(frame);
    }
    expect(outcome, isNotNull);
    game.dispose();
    return outcome!;
  }

  test(
    'Fast corners can score, center shots are saved and weak swipes stop',
    () {
      expect(run(const Offset(145, 250), .12), FootballResult.goal);
      expect(run(const Offset(255, 250), .12), FootballResult.goal);
      expect(run(const Offset(200, 250), .12), FootballResult.save);
      expect(run(const Offset(200, 480), .7), FootballResult.weak);
      expect(run(const Offset(20, 250), .12), isNot(FootballResult.goal));
    },
  );
  test(
    'Slow frames preserve collisions; stronger keepers make the same corner harder',
    () {
      for (final frame in [1 / 120, 1 / 30, .1]) {
        expect(
          run(const Offset(145, 250), .12, frame: frame),
          FootballResult.goal,
        );
        expect(
          run(const Offset(200, 250), .12, frame: frame),
          FootballResult.save,
        );
      }
      expect(
        run(const Offset(145, 250), .12, difficulty: 25),
        FootballResult.save,
      );
      expect(
        run(const Offset(124, 250), .12, difficulty: 100),
        FootballResult.goal,
      );
    },
  );
  test(
    'Post collision bounces, a goal pays once and rounds reset for the next swipe',
    () {
      var paid = 0;
      final game = FootballGame(
        onResult: (r, _, _) {
          if (r == FootballResult.goal) paid++;
        },
      );
      game.shoot(FootballGame.origin, const Offset(104, 250), .12);
      for (var n = 0; n < 60 && !game.touchedPost; n++) {
        game.tick(1 / 120);
      }
      expect(game.touchedPost, isTrue);
      expect(game.goals, 0);
      for (var n = 0; n < 600 && !game.ready; n++) {
        game.tick(1 / 120);
      }
      expect(game.ready, isTrue);
      game.shoot(FootballGame.origin, const Offset(145, 250), .12);
      for (var n = 0; n < 120 && game.result == null; n++) {
        game.tick(1 / 120);
      }
      expect(paid, 1);
      expect(
        game.shoot(FootballGame.origin, const Offset(145, 250), .12),
        isFalse,
      );
      for (var n = 0; n < 240; n++) {
        game.tick(1 / 120);
      }
      expect(paid, 1);
      expect(game.ready, isTrue);
      expect(game.ball, FootballGame.origin);
      game.dispose();
    },
  );
  test(
    'Each goal grants exactly 30 coins, with durable deduplication and records',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = GameStore(prefs);
      final before = store.coins;
      await store.recordFootballGoal('goal:test:1', 1);
      await store.recordFootballGoal('goal:test:1', 1);
      expect(store.coins, before + 30);
      final restored = GameStore(prefs);
      await restored.recordFootballGoal('goal:test:1', 1);
      await restored.recordFootballGoal('goal:test:2', 2);
      expect(restored.coins, before + 60);
      expect(restored.footballGoals, 2);
      expect(restored.footballBestStreak, 2);
      expect(
        prefs.getString('rincon.v1'),
        contains('"footballClaims":{"goal:test":2}'),
      );
      store.dispose();
      restored.dispose();
    },
  );
}
