import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sembast/sembast_io.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:nuestro_rincon/lucky_palace/data/lucky_database.dart';
import 'package:nuestro_rincon/lucky_palace/data/lucky_models.dart';
import 'package:nuestro_rincon/lucky_palace/data/local_lucky_repository.dart';
import 'package:nuestro_rincon/lucky_palace/data/remote_lucky_repository.dart';
import 'package:nuestro_rincon/lucky_palace/engine/lucky_engine.dart';

class FixedStops implements LuckyRandom {
  FixedStops(this.stops);
  final List<int> stops;
  int calls = 0;
  @override
  int nextInt(int max) => stops[calls++ % stops.length];
}

/// Contract fake, never a production random/result authority.
class SandboxFixture {
  int balance = 100, sequence = 0, charges = 0;
  bool loseReply = false, unavailable = false, missingOnce = false;
  String uid = 'alice';
  final receipts = <String, Map<String, dynamic>>{};
  final seen = <String, String>{};
  final requests = <Map<String, dynamic>>[];
  Future<Map<String, dynamic>> call(Map<String, dynamic> q) async {
    requests.add({...q});
    if (unavailable) throw const LuckyUncertain();
    if (q['expectedOwnerUid'] != uid) {
      throw const LuckyDeclined('cuenta-cambiada');
    }
    switch (q['action']) {
      case 'getWallet':
        return {
          'wallet': {
            'ownerUid': uid,
            'currency': 'sandboxVerifiedCoins',
            'balance': balance,
          },
        };
      case 'getCasinoState':
        return {
          'state': {'sequence': sequence, 'bonus': null},
        };
      case 'history':
        return {
          'receipts': receipts.values.toList().reversed.toList(),
          'presentations': {
            for (final id in receipts.keys) id: seen[id] ?? 'pending',
          },
          'nextCursor': null,
        };
      case 'getOperation':
        if (missingOnce || !receipts.containsKey(q['operationId'])) {
          missingOnce = false;
          throw const LuckyDeclined('operation-not-found');
        }
        return {
          'receipt': receipts[q['operationId']],
          'presentation': seen[q['operationId']] ?? 'pending',
        };
      case 'ackPresentation':
        seen[q['operationId']] = q['status'];
        return {'acknowledged': true};
      case 'requestSpin':
        final id = q['operationId'] as String;
        if (receipts.containsKey(id)) return {'receipt': receipts[id]};
        final r = LuckyEngine().evaluateStops([0, 0, 0, 0, 0]);
        final before = balance;
        balance += r.evaluation.total - r.simulatedCost;
        charges++;
        final receipt = <String, dynamic>{
          'ownerUid': uid,
          'operationId': id,
          'action': 'requestSpin',
          'status': 'committed',
          'chargedCost': r.simulatedCost,
          'grossPrize': r.evaluation.total,
          'netDelta': r.evaluation.total - r.simulatedCost,
          'balanceBefore': before,
          'balanceAfter': balance,
          'revisionBefore': sequence,
          'revisionAfter': sequence + 1,
          'result': {
            'configId': 'reference25',
            'round': r.toJson(),
            'bonusBefore': null,
            'sequenceBefore': sequence,
          },
          'createdAt': '2026-10-19T00:00:00Z',
        };
        receipts[id] = receipt;
        sequence++;
        if (loseReply) {
          loseReply = false;
          throw TimeoutException('after commit');
        }
        return {'receipt': receipt};
    }
    throw StateError('Unexpected request $q');
  }
}

void main() {
  test('local CPU and transactional file sample (not Android FPS)', () async {
    final folder = Directory.systemTemp.createTempSync('lucky-cost-');
    final db = await databaseFactoryIo.openDatabase(
      '${folder.path}/sample.db',
      mode: DatabaseMode.create,
    );
    final repo = LocalLuckyRoundRepository(
      LuckyDatabase(db),
      random: FixedStops([0]),
    );
    final engine = LuckyEngine(), watch = Stopwatch()..start();
    for (var i = 0; i < 1000; i++) {
      engine.evaluateStops([0, 0, 0, 0, 0]);
    }
    final baseline = watch.elapsedMicroseconds;
    final samples = <int>[];
    for (var i = 0; i < 50; i++) {
      if ((await repo.refresh()).balance < 25) await repo.refill();
      watch.reset();
      final r = await repo.execute(await repo.prepare());
      await repo.acknowledge(r.id, LuckyPresentation.seen);
      samples.add(watch.elapsedMicroseconds);
    }
    samples.sort();
    // ignore: avoid_print
    print(
      'Lucky 4C2 Windows debug: engine 1000=$baseline us; disk prepare+commit+ack n=50 p50=${samples[25]}us p95=${samples[47]}us. No GPU/Android claim.',
    );
    expect((await repo.history()).length, 50);
    await db.close();
    folder.deleteSync(recursive: true);
  });
  late Directory temp;
  late String path;
  setUp(() {
    temp = Directory.systemTemp.createTempSync('lucky-transaction-');
    path = '${temp.path}/casino.db';
  });
  tearDown(() {
    temp.deleteSync(recursive: true);
  });
  Future<Database> disk() => databaseFactoryIo.openDatabase(
    path,
    version: 1,
    mode: DatabaseMode.create,
  );
  test(
    'local prepared result, wallet, receipt and bonus survive disk reopen without reroll',
    () async {
      var db = await disk();
      final rng = FixedStops([14, 6, 3, 9, 10]);
      var repo = LocalLuckyRoundRepository(LuckyDatabase(db), random: rng);
      expect((await repo.refresh()).balance, 500);
      final intent = await repo.prepare();
      expect(rng.calls, 5);
      expect((await repo.prepare()).id, intent.id);
      expect(rng.calls, 5);
      await db.close();
      db = await disk();
      repo = LocalLuckyRoundRepository(
        LuckyDatabase(db),
        random: FixedStops([0]),
      );
      final receipt = (await repo.recover())!;
      expect(receipt.id, intent.id);
      expect(receipt, isA<LocalLuckyReceipt>());
      expect(receipt.round.evaluation.scatterColumns.length, 5);
      expect(receipt.round.after.remaining, 12);
      expect((await repo.execute(intent)).json, receipt.json);
      expect((await repo.history()).length, 1);
      await db.close();
      db = await disk();
      repo = LocalLuckyRoundRepository(
        LuckyDatabase(db),
        random: FixedStops([0]),
      );
      expect((await repo.refresh()).bonus.remaining, 12);
      expect((await repo.recover())!.id, receipt.id);
      await repo.acknowledge(receipt.id, LuckyPresentation.skipped);
      final free = await repo.prepare();
      expect(free.free, true);
      final next = await repo.execute(free);
      expect(next.cost, 0);
      expect(next.round.after.remaining, 11);
      expect(next.balance, receipt.balance + next.gross);
      await repo.acknowledge(next.id, LuckyPresentation.seen);
      expect(await repo.recover(), null);
      await db.close();
    },
  );
  test(
    'concurrent local preparation and execution charge once; both wins and losses',
    () async {
      final db = await disk();
      final repo = LocalLuckyRoundRepository(
        LuckyDatabase(db),
        random: FixedStops([0]),
      );
      final intents = await Future.wait([repo.prepare(), repo.prepare()]);
      expect(intents[0].id, intents[1].id);
      final receipts = await Future.wait(intents.map(repo.execute));
      expect(receipts[0].json, receipts[1].json);
      expect((await repo.refresh()).sequence, 1);
      expect((await repo.history()).length, 1);
      await repo.acknowledge(receipts[0].id, LuckyPresentation.seen);
      final loss = LuckyEngine().evaluateStops([0, 0, 0, 0, 0]);
      expect(loss.evaluation.total, 0);
      expect((await repo.refresh()).balance, 475);
      await db.close();
    },
  );
  test(
    'failed commit rolls back, never publishes a wallet, durable intent remains',
    () async {
      var db = await disk();
      var repo = LocalLuckyRoundRepository(
        LuckyDatabase(db),
        random: FixedStops([0]),
      );
      final intent = await repo.prepare();
      repo = LocalLuckyRoundRepository(
        LuckyDatabase(
          db,
          beforeCommit: () async {
            throw const FileSystemException('injected disk failure');
          },
        ),
      );
      await expectLater(
        repo.execute(intent),
        throwsA(isA<FileSystemException>()),
      );
      db = await disk();
      repo = LocalLuckyRoundRepository(LuckyDatabase(db));
      expect((await repo.refresh()).balance, 500);
      expect((await repo.history()), isEmpty);
      expect((await repo.recover())!.id, intent.id);
      expect((await repo.refresh()).balance, 475);
      await db.close();
    },
  );
  test(
    'unknown schema and corrupt file are preserved, no silent reset',
    () async {
      var db = await disk();
      await luckyRecords.record('local.wallet').put(db, {'schema': 999});
      final repo = LocalLuckyRoundRepository(LuckyDatabase(db));
      await expectLater(repo.refresh(), throwsA(isA<FormatException>()));
      db = await disk();
      expect(
        (await luckyRecords.record('local.wallet').get(db))!['schema'],
        999,
      );
      await db.close();
      File(path).writeAsStringSync('not a database\n');
      final original = File(path).readAsStringSync();
      await expectLater(disk(), throwsA(anything));
      expect(File(path).readAsStringSync(), original);
    },
  );
  test(
    'local refill is free, on request and only if insufficient; no remote records',
    () async {
      final db = await disk();
      final repo = LocalLuckyRoundRepository(
        LuckyDatabase(db),
        random: FixedStops([0]),
      );
      for (var i = 0; i < 20; i++) {
        final r = await repo.execute(await repo.prepare());
        await repo.acknowledge(r.id, LuckyPresentation.skipped);
      }
      expect((await repo.refresh()).balance, 0);
      await expectLater(repo.prepare(), throwsA(isA<LuckyDeclined>()));
      await Future.wait([repo.refill(), repo.refill()]);
      expect((await repo.refresh()).balance, 500);
      final records = await luckyRecords.find(db);
      expect(records.every((r) => r.key.startsWith('local.')), true);
      await db.close();
    },
  );
  test(
    'remote durable outbox, lost reply, 404 retry same ID, restart and no duplicate payment',
    () async {
      var db = await disk();
      final server = SandboxFixture()..loseReply = true;
      var repo = RemoteLuckyRoundRepository(
        storage: LuckyDatabase(db),
        ownerUid: 'alice',
        call: server.call,
      );
      final intent = await repo.prepare();
      expect(server.requests.any((q) => q['action'] == 'requestSpin'), false);
      expect(
        (await luckyRecords.record('sandbox.alice.intent').get(db))!['id'],
        intent.id,
      );
      await expectLater(repo.execute(intent), throwsA(isA<LuckyUncertain>()));
      expect(server.charges, 1);
      await db.close();
      db = await disk();
      server.missingOnce = true;
      repo = RemoteLuckyRoundRepository(
        storage: LuckyDatabase(db),
        ownerUid: 'alice',
        call: server.call,
      );
      final r = (await repo.recover())!;
      expect(r.id, intent.id);
      expect(r, isA<ServerLuckyReceipt>());
      expect(server.charges, 1);
      expect(
        server.requests
            .where((q) => q['action'] == 'requestSpin')
            .map((q) => q['operationId'])
            .toSet(),
        {intent.id},
      );
      await repo.acknowledge(r.id, LuckyPresentation.seen);
      expect(await repo.recover(), null);
      // Loss of all local visual cache still consults authoritative presentation.
      await luckyRecords.delete(db);
      expect(await repo.recover(), null);
      expect(server.charges, 1);
      await db.close();
    },
  );
  test(
    'separate devices recover server receipt; accounts and local wallet never merge',
    () async {
      final db = await disk(),
          other = await databaseFactoryMemory.openDatabase('other-device');
      final server = SandboxFixture();
      final a = RemoteLuckyRoundRepository(
        storage: LuckyDatabase(db),
        ownerUid: 'alice',
        call: server.call,
      );
      final r = await a.execute(await a.prepare());
      final device = RemoteLuckyRoundRepository(
        storage: LuckyDatabase(other),
        ownerUid: 'alice',
        call: server.call,
      );
      expect((await device.recover())!.id, r.id);
      await device.acknowledge(r.id, LuckyPresentation.skipped);
      expect(await a.recover(), null);
      final local = LocalLuckyRoundRepository(LuckyDatabase(db));
      expect((await local.refresh()).balance, 500);
      server.uid = 'bob';
      final b = RemoteLuckyRoundRepository(
        storage: LuckyDatabase(db),
        ownerUid: 'bob',
        call: server.call,
      );
      await expectLater(
        b.execute(
          LuckyRoundIntent(
            id: r.id,
            origin: LuckyOrigin.sandbox,
            sequence: 0,
            configId: 'reference25',
            free: false,
            ownerUid: 'alice',
          ),
        ),
        throwsStateError,
      );
      expect((await local.refresh()).balance, 500);
      await db.close();
      await other.close();
    },
  );
  test(
    'transport rejects production endpoints, account change, 429 and 503',
    () async {
      for (final url in [
        'https://example.com/demo-lucky-readiness/us-central1/economyV2',
        'http://127.0.0.1:15001/production/us-central1/economyV2',
      ]) {
        expect(
          () => LuckySandboxTransport(
            endpoint: Uri.parse(url),
            ownerUid: 'a',
            currentUid: () => 'a',
            token: () async => 'token',
          ),
          throwsArgumentError,
        );
      }
      for (final code in [429, 503]) {
        final client = MockClient((q) async => http.Response('{}', code));
        final transport = LuckySandboxTransport(
          endpoint: Uri.parse(
            'http://127.0.0.1:15001/demo-lucky-readiness/us-central1/economyV2',
          ),
          ownerUid: 'a',
          currentUid: () => 'a',
          token: () async => 'fake',
          client: client,
        );
        await expectLater(transport.call({}), throwsA(isA<LuckyUncertain>()));
        client.close();
      }
      var current = 'a';
      var calls = 0;
      final client = MockClient((q) async {
        calls++;
        current = 'b';
        return http.Response('{}', 200);
      });
      final t = LuckySandboxTransport(
        endpoint: Uri.parse(
          'http://127.0.0.1:15001/demo-lucky-readiness/us-central1/economyV2',
        ),
        ownerUid: 'a',
        currentUid: () => current,
        token: () async => 'fake',
        client: client,
      );
      await expectLater(t.call({}), throwsA(isA<LuckyDeclined>()));
      expect(calls, 1);
      client.close();
    },
  );
}
