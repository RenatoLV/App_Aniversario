import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nuestro_rincon/highscore_outbox.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  Future<SharedPreferences> setup() async {
    SharedPreferences.setMockInitialValues({
      'rincon.v1': jsonEncode({
        'best': 2400,
        'game': {'score': 1100},
      }),
      'wordle.v1': jsonEncode({'wins': 4}),
      'sweet.best': 8300,
      'leap.best': 12000,
    });
    return SharedPreferences.getInstance();
  }

  test(
    'All four offline bests remain queued across restart and reconnect',
    () async {
      final prefs = await setup();
      final queue = HighscoreOutbox(prefs);
      await expectLater(
        queue.flush('alice', (_, _) async {
          throw StateError('offline');
        }, isCurrentAccount: () => true),
        throwsStateError,
      );
      for (final game in queue.scores.keys) {
        expect(prefs.getInt('firebase.score.global.v2.alice.$game'), isNull);
      }
      final restored = HighscoreOutbox(await SharedPreferences.getInstance());
      final sent = <String, int>{};
      await restored.flush('alice', (game, score) async {
        sent[game] = score;
      }, isCurrentAccount: () => true);
      expect(sent, {
        'blocks-v1': 2400,
        'wordlady': 4,
        'candy-churu-cat': 8300,
        'ascenso-maruzon': 12000,
      });
      await restored.flush('alice', (_, _) async {
        fail('Already acknowledged');
      }, isCurrentAccount: () => true);
    },
  );

  test('A failing game does not block the remaining games', () async {
    final prefs = await setup();
    final sent = <String>[];
    await expectLater(
      HighscoreOutbox(prefs).flush('alice', (game, score) async {
        if (game == 'blocks-v1') throw StateError('offline');
        sent.add(game);
      }, isCurrentAccount: () => true),
      throwsStateError,
    );
    expect(sent, ['wordlady', 'candy-churu-cat', 'ascenso-maruzon']);
    final retries = <String>[];
    await HighscoreOutbox(prefs).flush('alice', (game, score) async {
      retries.add(game);
    }, isCurrentAccount: () => true);
    expect(retries, ['blocks-v1']);
  });

  test(
    'A newer record during upload remains pending, not falsely acknowledged',
    () async {
      final prefs = await setup();
      await HighscoreOutbox(prefs).flush('alice', (game, score) async {
        if (game == 'blocks-v1') {
          await prefs.setString('rincon.v1', jsonEncode({'best': 4000}));
        }
      }, isCurrentAccount: () => true);
      final sent = <String, int>{};
      await HighscoreOutbox(prefs).flush('alice', (game, score) async {
        sent[game] = score;
      }, isCurrentAccount: () => true);
      expect(sent, {'blocks-v1': 4000});
    },
  );

  test(
    'Changing account during upload never acknowledges or sends remaining scores',
    () async {
      final prefs = await setup();
      var current = true;
      var calls = 0;
      await HighscoreOutbox(prefs).flush('alice', (_, _) async {
        calls++;
        current = false;
      }, isCurrentAccount: () => current);
      expect(calls, 1);
      expect(prefs.getInt('firebase.score.global.v2.alice.blocks-v1'), isNull);
    },
  );
}
