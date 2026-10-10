import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:nuestro_rincon/marus_zombies/mz_levels.dart';
import 'support/gameplay_probe.dart';

void main() {
  test('diagnostic players use only unlocked decks of at most six cards', () {
    for (final level in mzCampaign) {
      for (final strategy in probeStrategies) {
        final deck = GameplayProbe.deckFor(level, strategy);
        expect(deck.length, inInclusiveRange(1, 6));
        expect(deck.toSet().length, deck.length);
        expect(deck.every(level.allowed.contains), true);
      }
    }
  });
  test(
    'diagnostic strategy is deterministic, including resource accounting',
    () {
      for (final level in [const MzLevel(0), const MzLevel(50)]) {
        final first = GameplayProbe(level, 'strategic_tuna'),
            second = GameplayProbe(level, 'strategic_tuna');
        expect(first.run(), second.run());
        expect(first.sim.toJson(), second.sim.toJson());
        expect(
          first.sim.catnip,
          level.startingCatnip + first.collected - first.spent,
        );
      }
    },
  );
  test(
    'generate the 60 mission nine strategy reproducible report',
    () {
      final results = <Map<String, Object>>[];
      for (final level in mzCampaign) {
        for (final strategy in probeStrategies) {
          final probe = GameplayProbe(level, strategy);
          final row = probe.run();
          expect(
            probe.sim.catnip,
            level.startingCatnip + probe.collected - probe.spent,
          );
          results.add(row);
        }
      }
      final file = File('docs/mz-v41-gameplay.csv')
        ..parent.createSync(recursive: true);
      String csv(Object v) => '"${v.toString().replaceAll('"', '""')}"';
      file.writeAsStringSync(
        '${results.first.keys.map(csv).join(',')}\n${results.map((r) => r.values.map(csv).join(',')).join('\n')}\n',
      );
      final summary = {
        for (final strategy in probeStrategies)
          strategy: {
            for (final result in ['win', 'loss', 'timeout'])
              result: results
                  .where(
                    (r) => r['strategy'] == strategy && r['result'] == result,
                  )
                  .length,
          },
      };
      // ignore: avoid_print
      print(jsonEncode(summary));
    },
    skip: !const bool.fromEnvironment('DIAGNOSE_V41'),
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
