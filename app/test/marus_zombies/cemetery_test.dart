import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nuestro_rincon/marus_zombies/mz_catalog.dart';
import 'package:nuestro_rincon/marus_zombies/mz_levels.dart';
import 'package:nuestro_rincon/marus_zombies/mz_progress.dart';
import 'package:nuestro_rincon/marus_zombies/mz_simulation.dart';

void main() {
  test(
    'six worlds have ten missions; stable IDs and final boss are preserved',
    () {
      expect(mzCampaign.length, 60);
      expect(mzCampaign.map((l) => l.id).toSet().length, 60);
      for (final w in mzWorldOrder) {
        expect(mzLevelsForWorld(w).length, 10);
      }
      expect(mzNextLevel(const MzLevel(9))!.id, 50);
      expect(mzNextLevel(const MzLevel(59))!.id, 10);
      expect(mzNextLevel(const MzLevel(49)), isNull);
      expect(mzCampaign.last.id, 49);
    },
  );
  test(
    'new campaign traverses cemetery; original unlock milestones stay intact',
    () async {
      SharedPreferences.setMockInitialValues({
        MzProgress.key: jsonEncode({
          'stars': {for (var i = 0; i < 10; i++) '$i': 3},
        }),
      });
      final p = MzProgress(await SharedPreferences.getInstance());
      final cats = mzUnlockedCats(p.highest);
      expect(p.levelUnlocked(const MzLevel(50)), true);
      expect(p.levelUnlocked(const MzLevel(51)), false);
      expect(p.levelUnlocked(const MzLevel(10)), false);
      for (var id = 50; id < 60; id++) {
        expect(p.levelUnlocked(MzLevel(id)), true);
        await p.complete(MzSimulation(MzLevel(id))..won = true);
      }
      expect(p.cemeteryHighest, 10);
      expect(p.highest, 10);
      expect(p.campaignCompleted, 20);
      expect(mzUnlockedCats(p.highest), cats);
      expect(p.levelUnlocked(const MzLevel(10)), true);
      final mints = p.mints;
      await p.complete(MzSimulation(const MzLevel(59))..won = true);
      expect(p.mints, mints);
    },
  );
  test(
    'legacy progress remains accessible; tombs move to cemetery checkpoints',
    () async {
      SharedPreferences.setMockInitialValues({
        MzProgress.key: jsonEncode({
          'stars': {for (var i = 0; i < 30; i++) '$i': 3},
        }),
      });
      final p = MzProgress(await SharedPreferences.getInstance());
      expect(p.highest, 30);
      expect(p.levelUnlocked(const MzLevel(30)), true);
      final egypt = MzSimulation(const MzLevel(15));
      expect(egypt.tombs, isEmpty);
      final legacy = egypt.toJson();
      legacy['tombs'] = {'5': 200};
      expect(MzSimulation.fromJson(legacy).tombs, isEmpty);
      final grave = MzSimulation(const MzLevel(55));
      grave.tombs[5] = 123;
      final resumed = MzSimulation.fromJson(grave.toJson());
      expect(resumed.level.id, 55);
      expect(resumed.tombs, grave.tombs);
    },
  );
}
