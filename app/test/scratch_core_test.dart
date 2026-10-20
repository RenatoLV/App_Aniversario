import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_io.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:nuestro_rincon/lucky_palace/data/lucky_database.dart';
import 'package:nuestro_rincon/lucky_palace/data/local_lucky_repository.dart';
import 'package:nuestro_rincon/lucky_palace/data/lucky_models.dart';
import 'package:nuestro_rincon/lucky_palace/scratch/scratch_engine.dart';
import 'package:nuestro_rincon/lucky_palace/scratch/scratch_math.dart';
import 'package:nuestro_rincon/lucky_palace/scratch/scratch_mask.dart';
import 'package:nuestro_rincon/lucky_palace/scratch/scratch_local_repository.dart';
import 'lucky_repository_test.dart' show FixedStops;

void main() {
  test(
    'one explicit rule: every type with at least three symbols pays once',
    () {
      expect(ScratchOutcome([0, 0, 0, 1, 1, 2, 3, 4, 5]).gross, 3);
      expect(ScratchOutcome([0, 0, 1, 1, 2, 2, 3, 3, 4]).gross, 0);
      expect(ScratchOutcome([3, 3, 3, 4, 4, 4, 5, 5, 5]).gross, 35);
      expect(ScratchOutcome(List.filled(9, 5)).gross, 15);
      expect(() => ScratchOutcome([0]), throwsFormatException);
      expect(() => ScratchOutcome(List.filled(9, 6)), throwsFormatException);
    },
  );
  test('exact multinomial distribution and versioned expected return', () {
    final d = scratchExactDistribution();
    expect(d.values.fold(0, (a, b) => a + b), 10077696);
    expect(d[0], 1587600);
    expect(d.keys.reduce((a, b) => a > b ? a : b), 35);
    final expected =
        d.entries.fold(0, (a, e) => a + e.key * e.value) / 10077696;
    expect(expected, closeTo(8.91297971282325, 1e-12));
    expect(expected / ScratchRules.cost, lessThan(1));
  });
  test(
    'capsule rasterization interpolates fast strokes and counts each pixel once',
    () {
      final mask = ScratchMask();
      expect(mask.segment(10, 171, 476, 171, 18), isTrue);
      for (final x in [30, 100, 240, 440]) {
        final i = (171 / 342 * 128).floor() * 192 + (x / 486 * 192).floor();
        expect(mask.isSet(i), isTrue);
      }
      final count = mask.cleared;
      expect(mask.segment(10, 171, 476, 171, 18), isFalse);
      expect(mask.cleared, count);
      expect(mask.coverage, greaterThan(0));
      expect(mask.coverage, lessThan(.2));
      expect(mask.segment(-100, -100, -50, -50, 18), isFalse);
      expect(mask.segment(double.nan, 0, 2, 2, 18), isFalse);
    },
  );
  test('mask roundtrip, union, all eligible area, invalid/corner data', () {
    final a = ScratchMask()..segment(20, 20, 400, 40, 20);
    final b = ScratchMask()..segment(20, 270, 400, 310, 20);
    final count = a.cleared;
    a.merge(b);
    expect(a.cleared, greaterThan(count));
    final saved = ScratchMask.decode(a.encode());
    expect(saved.encode(), a.encode());
    expect(saved.coverage, a.coverage);
    expect(() => ScratchMask.decode('AAA='), throwsFormatException);
    final all = ScratchMask()..segment(243, 171, 243, 171, 1000);
    expect(all.coverage, 1);
    expect(all.isSet(0), isFalse);
  });
  test(
    'sealed result precedes payment/presentation, IDs and reveals are idempotent',
    () async {
      final db = await databaseFactoryMemory.openDatabase('scratch-sealed');
      addTearDown(db.close);
      final rng = FixedStops([0]);
      final repo = ScratchLocalRepository(LuckyDatabase(db), random: rng);
      final id = await repo.prepare('patita_suerte', 'test-sealed');
      expect(rng.calls, 9);
      expect(await repo.balance(), 500);
      expect(await repo.history(), isEmpty);
      final r = await repo.execute(id);
      expect(r.gross, 3);
      expect(r.balance, 493);
      expect(r.revealed, false);
      expect((await repo.execute(id)).data, r.data);
      expect(rng.calls, 9);
      await repo.prepare('patita_suerte', id);
      expect(rng.calls, 9);
      await expectLater(repo.prepare('dulces_lady', id), throwsStateError);
      await repo.saveVisual(id, ScratchMask(), reveal: true);
      await repo.saveVisual(id, ScratchMask(), reveal: true);
      expect(await repo.balance(), 493);
      expect((await repo.history()).length, 1);
      expect((await repo.recover())!.revealed, true);
    },
  );
  test(
    'one active covered ticket; cosmetic themes do not change economics',
    () async {
      final db = await databaseFactoryMemory.openDatabase('scratch-theme');
      addTearDown(db.close);
      final repo = ScratchLocalRepository(
        LuckyDatabase(db),
        random: FixedStops([0]),
      );
      final first = await repo.execute(
        await repo.prepare('patita_suerte', 'first'),
      );
      await expectLater(
        repo.prepare('tesoros_maru', 'second'),
        throwsStateError,
      );
      await repo.saveVisual(first.id, ScratchMask(), reveal: true);
      final second = await repo.execute(
        await repo.prepare('tesoros_maru', 'second'),
      );
      expect(second.gross, first.gross);
      expect(second.outcome.cells, first.outcome.cells);
      expect(second.theme.id, 'tesoros_maru');
      expect(second.balance, 486);
    },
  );
  test(
    'shared wallet preserves existing Lucky 777 bonus, sequence and old receipts',
    () async {
      final db = await databaseFactoryMemory.openDatabase('scratch-compatible');
      addTearDown(db.close);
      final storage = LuckyDatabase(db),
          slot = LocalLuckyRoundRepository(
            LuckyDatabase(db),
            random: FixedStops([14, 6, 3, 9, 10]),
          );
      final spin = await slot.execute(await slot.prepare());
      await slot.acknowledge(spin.id, LuckyPresentation.seen);
      final before = await slot.refresh();
      expect(before.balance, 495);
      expect(before.bonus.remaining, 12);
      final scratch = ScratchLocalRepository(storage, random: FixedStops([0]));
      await scratch.execute(await scratch.prepare('patita_suerte', 'compat'));
      final after = await slot.refresh();
      expect(after.balance, 488);
      expect(after.sequence, before.sequence);
      expect(after.bonus.remaining, 12);
      expect(after.bonus.awarded, 12);
      expect((await slot.history()).single.json, {
        ...spin.json,
        'presentation': 'seen',
      });
    },
  );
  test(
    'concurrent preparations reserve the same wallet, retry after settlement is safe',
    () async {
      final db = await databaseFactoryMemory.openDatabase('scratch-concurrent');
      addTearDown(db.close);
      final slot = LocalLuckyRoundRepository(
        LuckyDatabase(db),
        random: FixedStops([0]),
      );
      final scratch = ScratchLocalRepository(
        LuckyDatabase(db),
        random: FixedStops([0]),
      );
      final results = await Future.wait<Object>([
        slot.prepare().then<Object>((v) => v).catchError((Object e) => e),
        scratch
            .prepare('patita_suerte', 'race')
            .then<Object>((v) => v)
            .catchError((Object e) => e),
      ]);
      expect(results.whereType<StateError>().length, 1);
      if (results.first is LuckyRoundIntent) {
        final r = await slot.execute(results.first as LuckyRoundIntent);
        await slot.acknowledge(r.id, LuckyPresentation.seen);
        await scratch.execute(await scratch.prepare('patita_suerte', 'race'));
      } else {
        final r = await scratch.execute('race');
        await scratch.saveVisual(r.id, ScratchMask(), reveal: true);
        final s = await slot.execute(await slot.prepare());
        await slot.acknowledge(s.id, LuckyPresentation.seen);
      }
      expect((await slot.refresh()).balance, 468);
      expect(await scratch.balance(), 468);
      expect((await slot.history()).length, 1);
      expect((await scratch.history()).length, 1);
    },
  );
  test(
    'old masks cannot erase new strokes or undo revealed presentation',
    () async {
      final db = await databaseFactoryMemory.openDatabase('scratch-mask-union');
      addTearDown(db.close);
      final repo = ScratchLocalRepository(
        LuckyDatabase(db),
        random: FixedStops([0]),
      );
      final r = await repo.execute(
        await repo.prepare('patita_suerte', 'union'),
      );
      final a = ScratchMask()..segment(20, 20, 400, 40, 20),
          b = ScratchMask()..segment(20, 270, 400, 310, 20);
      await Future.wait([
        repo.saveVisual(r.id, a),
        repo.saveVisual(r.id, b, reveal: true),
      ]);
      final saved = (await repo.recover())!;
      final union = a.copy()..merge(b);
      expect(saved.mask.encode(), union.encode());
      await repo.saveVisual(r.id, a);
      expect((await repo.recover())!.revealed, true);
      expect(await repo.balance(), 493);
    },
  );
  test(
    'low funds fail closed without another wallet or prepared outcome',
    () async {
      final db = await databaseFactoryMemory.openDatabase('scratch-funds');
      addTearDown(db.close);
      final storage = LuckyDatabase(db);
      final repo = ScratchLocalRepository(storage, random: FixedStops([0]));
      await repo.balance();
      final old = (await luckyRecords.record('local.wallet').get(db))!;
      await luckyRecords.record('local.wallet').put(db, {...old, 'balance': 9});
      await expectLater(
        repo.prepare('patita_suerte', 'poor'),
        throwsA(isA<LuckyDeclined>()),
      );
      expect(await repo.balance(), 9);
      expect(await luckyRecords.record('scratch.intent').get(db), null);
    },
  );
  test(
    'native restart and failed commit keep exact result, partial mask and single payment',
    () async {
      final dir = Directory.systemTemp.createTempSync('scratch-recovery-');
      final path = '${dir.path}/casino.db';
      Future<Database> open() =>
          databaseFactoryIo.openDatabase(path, mode: DatabaseMode.create);
      var db = await open();
      var storage = LuckyDatabase(db);
      var rng = FixedStops([0]);
      var repo = ScratchLocalRepository(storage, random: rng);
      await repo.prepare('patita_suerte', 'disk');
      await db.close();
      db = await open();
      storage = LuckyDatabase(
        db,
        beforeCommit: () async =>
            throw const FileSystemException('injected commit failure'),
      );
      repo = ScratchLocalRepository(storage, random: FixedStops([5]));
      await expectLater(
        repo.execute('disk'),
        throwsA(isA<FileSystemException>()),
      );
      db = await open();
      repo = ScratchLocalRepository(LuckyDatabase(db), random: FixedStops([5]));
      final r = (await repo.recover())!;
      expect(r.outcome.cells, List.filled(9, 0));
      expect(r.balance, 493);
      final mask = ScratchMask()..segment(20, 40, 450, 180, 18);
      await repo.saveVisual(r.id, mask);
      await db.close();
      db = await open();
      repo = ScratchLocalRepository(LuckyDatabase(db));
      final partial = (await repo.recover())!;
      expect(partial.id, r.id);
      expect(partial.mask.encode(), mask.encode());
      expect(partial.revealed, false);
      expect(await repo.balance(), 493);
      await repo.saveVisual(r.id, mask, reveal: true);
      await db.close();
      db = await open();
      repo = ScratchLocalRepository(LuckyDatabase(db));
      expect((await repo.recover())!.revealed, true);
      expect(await repo.balance(), 493);
      expect((await repo.history()).length, 1);
      await db.close();
      expect(dir.absolute.parent.path, Directory.systemTemp.absolute.path);
      expect(dir.path.contains('scratch-recovery-'), true);
      await dir.delete(recursive: true);
    },
  );
  test('corrupt native database remains on disk', () async {
    final dir = Directory.systemTemp.createTempSync('scratch-corrupt-');
    final file = File('${dir.path}/casino.db');
    await file.writeAsString('NOT A SEMBAST JOURNAL');
    await expectLater(
      databaseFactoryIo.openDatabase(file.path, mode: DatabaseMode.create),
      throwsA(anything),
    );
    expect(await file.readAsString(), 'NOT A SEMBAST JOURNAL');
    expect(dir.absolute.parent.path, Directory.systemTemp.absolute.path);
    expect(dir.path.contains('scratch-corrupt-'), true);
    await dir.delete(recursive: true);
  });
}
