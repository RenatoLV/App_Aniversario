import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:nuestro_rincon/lucky_palace/engine/lucky_engine.dart';
import 'package:nuestro_rincon/lucky_palace/data/lucky_database.dart';
import 'package:nuestro_rincon/lucky_palace/data/lucky_models.dart';
import 'package:nuestro_rincon/lucky_palace/data/local_lucky_repository.dart';
import 'package:nuestro_rincon/lucky_palace/scratch/scratch_engine.dart';
import 'package:nuestro_rincon/lucky_palace/scratch/scratch_math.dart';
import 'package:nuestro_rincon/lucky_palace/scratch/scratch_mask.dart';
import 'package:nuestro_rincon/lucky_palace/scratch/scratch_local_repository.dart';
import 'package:nuestro_rincon/lucky_palace/art/lucky_reward_burst.dart';
import 'lucky_repository_test.dart' show FixedStops;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'slot successor improves long combinations without rewriting legacy rules',
    () {
      final old = luckyRules('reference25'), next = luckyRules('rewards25v2');
      expect(next.rulesVersion, isNot(old.rulesVersion));
      expect(next.wager, old.wager);
      expect(next.reels, old.reels);
      expect(next.scatterAwards, old.scatterAwards);
      expect(next.maxBonusSpins, old.maxBonusSpins);
      for (final symbol in old.payouts.keys) {
        expect(next.payouts[symbol]![3], old.payouts[symbol]![3]);
        for (final count in [4, 5]) {
          expect(
            next.payouts[symbol]![count]!,
            greaterThan(old.payouts[symbol]![count]!),
          );
        }
      }
      expect(old.payouts[LuckySymbol.wild]![5], 600);
      expect(next.payouts[LuckySymbol.wild]![5], 720);
    },
  );
  test(
    'upgrade preserves old presentation, receipt, sequence and existing chips',
    () async {
      final db = await databaseFactoryMemory.openDatabase(
        'rewards-old-receipt',
      );
      addTearDown(db.close);
      final storage = LuckyDatabase(db);
      final old = LocalLuckyRoundRepository(storage, random: FixedStops([0]));
      final receipt = await old.execute(await old.prepare());
      final enhanced = LocalLuckyRoundRepository(
        storage,
        configId: 'rewards25v2',
        random: FixedStops([0]),
      );
      expect((await enhanced.refresh()).configId, 'reference25');
      await enhanced.acknowledge(receipt.id, LuckyPresentation.seen);
      final upgraded = await enhanced.refresh();
      expect(upgraded.configId, 'rewards25v2');
      expect(upgraded.balance, receipt.balance);
      expect(upgraded.sequence, 1);
      expect(
        (await enhanced.history()).single.round.rules.rulesVersion,
        LuckyRules.candidate.rulesVersion,
      );
      final newReceipt = await enhanced.execute(await enhanced.prepare());
      expect(newReceipt.json['configId'], 'rewards25v2');
      expect(
        newReceipt.round.rules.rulesVersion,
        LuckyRules.rewardsV2.rulesVersion,
      );
    },
  );
  test(
    'prepared legacy spin and all awarded Free Spins finish before adoption',
    () async {
      final db = await databaseFactoryMemory.openDatabase('rewards-old-bonus');
      addTearDown(db.close);
      final storage = LuckyDatabase(db);
      final old = LocalLuckyRoundRepository(
        storage,
        random: FixedStops([14, 6, 3, 9, 10]),
      );
      final intent = await old.prepare();
      final enhanced = LocalLuckyRoundRepository(
        storage,
        configId: 'rewards25v2',
        random: FixedStops([0]),
      );
      expect((await enhanced.refresh()).configId, 'reference25');
      final receipt = await enhanced.execute(intent);
      expect(receipt.round.after.remaining, greaterThan(0));
      await enhanced.acknowledge(receipt.id, LuckyPresentation.seen);
      var wallet = await enhanced.refresh();
      while (wallet.bonus.remaining > 0) {
        expect(wallet.configId, 'reference25');
        final free = await enhanced.execute(await enhanced.prepare());
        expect(free.cost, 0);
        expect(
          free.round.rules.rulesVersion,
          LuckyRules.candidate.rulesVersion,
        );
        await enhanced.acknowledge(free.id, LuckyPresentation.seen);
        wallet = await enhanced.refresh();
      }
      expect(wallet.configId, 'rewards25v2');
    },
  );
  test(
    'scratch versions preserve old nine-match awards; new multipliers are explicit',
    () {
      expect(ScratchOutcome(List.filled(9, 5)).gross, 15);
      expect(
        ScratchOutcome(
          List.filled(9, 5),
          rulesVersion: ScratchRules.enhancedVersion,
        ).gross,
        340,
      );
      expect(
        ScratchOutcome([
          5,
          5,
          5,
          5,
          5,
          5,
          4,
          4,
          4,
        ], rulesVersion: ScratchRules.enhancedVersion).gross,
        63,
      );
      final d = scratchExactDistribution(
        rulesVersion: ScratchRules.enhancedVersion,
      );
      expect(d.values.fold(0, (a, b) => a + b), 10077696);
      expect(d[340], 1);
      final rtp = d.entries.fold(0, (a, e) => a + e.key * e.value) / 100776960;
      expect(rtp, closeTo(.9748772933813443, 1e-12));
      expect(rtp, lessThan(1));
    },
  );
  test(
    'same RNG outcomes, higher new awards, no change to number of draws',
    () {
      final a = LuckySeededRandom(20261019), b = LuckySeededRandom(20261019);
      for (var i = 0; i < 1000; i++) {
        final old = const ScratchEngine().generate(a);
        final next = const ScratchEngine(
          rulesVersion: ScratchRules.enhancedVersion,
        ).generate(b);
        expect(next.cells, old.cells);
        expect(next.gross, greaterThanOrEqualTo(old.gross));
        expect(next.winningSymbols, old.winningSymbols);
      }
      expect(a.state, b.state);
    },
  );
  test(
    'pending scratch v1 recovers once under v2; next ticket uses v2 exactly once',
    () async {
      final db = await databaseFactoryMemory.openDatabase(
        'rewards-scratch-intent',
      );
      addTearDown(db.close);
      final storage = LuckyDatabase(db);
      final old = ScratchLocalRepository(storage, random: FixedStops([5]));
      await old.prepare('patita_suerte', 'legacy');
      final rng = FixedStops([5]);
      final next = ScratchLocalRepository(
        storage,
        rulesVersion: ScratchRules.enhancedVersion,
        random: rng,
      );
      final recovered = (await next.recover())!;
      expect(recovered.gross, 15);
      expect(recovered.rulesVersion, ScratchRules.version);
      expect(rng.calls, 0);
      expect(await next.balance(), 505);
      await next.saveVisual(recovered.id, ScratchMask(), reveal: true);
      final upgraded = await next.execute(
        await next.prepare('patita_suerte', 'upgraded'),
      );
      expect(upgraded.gross, 340);
      expect(upgraded.rulesVersion, ScratchRules.enhancedVersion);
      expect(await next.balance(), 835);
      await next.saveVisual(upgraded.id, ScratchMask(), reveal: true);
      await next.saveVisual(upgraded.id, ScratchMask(), reveal: true);
      expect((await next.execute(upgraded.id)).data, upgraded.data);
      expect(await next.balance(), 835);
      expect(rng.calls, 9);
      expect((await next.history()).length, 2);
    },
  );
  test(
    'reward burst has finite lifetime and stays inside its bounds',
    () async {
      for (final progress in [0.0, .4, 1.0]) {
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        LuckyRewardBurst.paint(
          canvas,
          const Rect.fromLTWH(10, 10, 160, 100),
          progress: progress,
          accent: Colors.amber,
          amount: 340,
          heading: 'PREMIO',
          grand: true,
        );
        final picture = recorder.endRecording();
        final image = await picture.toImage(180, 120);
        final data = (await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!;
        var painted = 0;
        for (var y = 0; y < 120; y++) {
          for (var x = 0; x < 180; x++) {
            final alpha = data.getUint8((y * 180 + x) * 4 + 3);
            if (alpha > 0) {
              painted++;
              expect(x >= 10 && x < 170 && y >= 10 && y < 110, true);
            }
          }
        }
        expect(painted, progress == .4 ? greaterThan(0) : 0);
        image.dispose();
        picture.dispose();
      }
    },
  );
}
