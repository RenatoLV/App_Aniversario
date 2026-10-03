import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nuestro_rincon/progress_sync.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'Cloud backup includes every game and card variant but excludes mural media',
    () async {
      SharedPreferences.setMockInitialValues({
        'rincon.v1': jsonEncode({
          'coins': 70,
          'best': 1200,
          'game': {
            'score': 800,
            'board': [
              [0, 1],
            ],
          },
          'cardVariants': {'6:legendary:gold': 2},
          'packsSinceLegendary': 24,
          'catCare': {
            'ownedClothes': ['shirt_navy', 'hat_party'],
            'maru': {
              'outfit': {'hat': 'hat_party'},
            },
          },
          'notes': [
            {'imageBase64': 'large-image'},
          ],
          'dirtyNotes': ['one'],
        }),
        'wordle.v1': 'wordle-round',
        'wordle.hintDay': '2026-09-30',
        'wordle.hintsUsed': 1,
        'sweet.v1': 'candy-board',
        'sweet.best': 500,
        'leap.best': 10000,
        'leap.last': '{"points":9000,"finished":true}',
        'leap.trail': 'galaxy',
        'leap.trails': ['rainbow', 'galaxy', 'comet'],
      });
      final prefs = await SharedPreferences.getInstance();
      final sync = ProgressSync(prefs, () {});
      final backup = jsonDecode(sync.snapshot()) as Map<String, dynamic>;
      final core =
          jsonDecode(backup['rincon.v1'] as String) as Map<String, dynamic>;
      expect(core['coins'], 70);
      expect(core['best'], 1200);
      expect(core['game']['score'], 800);
      expect(backup['wordle.v1'], 'wordle-round');
      expect(backup['sweet.v1'], 'candy-board');
      expect(backup['sweet.best'], 500);
      expect(backup['leap.best'], 10000);
      expect(backup['leap.trail'], 'galaxy');
      expect(backup['leap.trails'], ['rainbow', 'galaxy', 'comet']);
      expect(core['catCare']['ownedClothes'], ['shirt_navy', 'hat_party']);
      expect(core['cardVariants']['6:legendary:gold'], 2);
      expect(core['packsSinceLegendary'], 24);
      expect(core.containsKey('notes'), false);
      expect(core.containsKey('dirtyNotes'), false);
      expect(backup.keys, containsAll(ProgressSync.keys));
      expect(backup['leap.last'], '{"points":9000,"finished":true}');
      expect(jsonDecode(prefs.getString('rincon.v1')!)['notes'], isNotEmpty);
      sync.dispose();
    },
  );
  test(
    'Changing accounts isolates and restores progress, images and shared space',
    () async {
      final aliceSave = jsonEncode({
        'coins': 300,
        'cards': {'6': 2},
        'notes': [
          {'imageBase64': 'drawing'},
        ],
      });
      SharedPreferences.setMockInitialValues({
        'firebase.owner': 'alice',
        'rincon.v1': aliceSave,
        'leap.best': 1234,
        'leap.trail': 'comet',
        'leap.trails': ['rainbow', 'comet'],
        'firebase.noteSpace': 'alice-space',
      });
      final prefs = await SharedPreferences.getInstance();
      var restored = 0;
      final sync = ProgressSync(prefs, () {
        restored++;
      });
      await sync.prepareLocalAccount('bob');
      expect(prefs.getString('rincon.v1'), null);
      expect(prefs.getInt('leap.best'), null);
      expect(prefs.getStringList('leap.trails'), null);
      expect(prefs.getString('firebase.noteSpace'), null);
      await prefs.setString(
        'rincon.v1',
        jsonEncode({'coins': 40, 'notes': []}),
      );
      await sync.prepareLocalAccount('alice');
      expect(prefs.getString('rincon.v1'), aliceSave);
      expect(prefs.getInt('leap.best'), 1234);
      expect(prefs.getStringList('leap.trails'), ['rainbow', 'comet']);
      expect(prefs.getString('leap.trail'), 'comet');
      expect(prefs.getString('firebase.noteSpace'), 'alice-space');
      await sync.prepareLocalAccount('bob');
      expect(jsonDecode(prefs.getString('rincon.v1')!)['coins'], 40);
      expect(restored, 3);
      sync.dispose();
    },
  );
  test(
    'First Google account adopts guest save without discarding it',
    () async {
      SharedPreferences.setMockInitialValues({'rincon.v1': 'guest-progress'});
      final prefs = await SharedPreferences.getInstance();
      final sync = ProgressSync(prefs, () {
        fail('Guest progress should not be reset');
      });
      await sync.prepareLocalAccount('alice');
      expect(prefs.getString('rincon.v1'), 'guest-progress');
      expect(prefs.getString('firebase.owner'), 'alice');
      sync.dispose();
    },
  );
}
