import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:nuestro_rincon/lucky_palace/data/lucky_database.dart';
import 'package:nuestro_rincon/lucky_palace/data/lucky_models.dart';
import 'package:nuestro_rincon/lucky_palace/data/remote_lucky_repository.dart';

void main() {
  test(
    'real authenticated HTTP: paid Scatter, restart, server FreeSpin, lost reply, two devices',
    () async {
      final fixture = luckyMap(
        jsonDecode(
          File('build/lucky-stage4a/client-fixture.json').readAsStringSync(),
        ),
      );
      final db = await databaseFactoryMemory.openDatabase('auth-http-device1'),
          second = await databaseFactoryMemory.openDatabase(
            'auth-http-device2',
          );
      final transport = LuckySandboxTransport(
        endpoint: Uri.parse(fixture['endpoint']),
        ownerUid: fixture['uid'],
        currentUid: () => fixture['uid'],
        token: () async => fixture['token'],
      );
      var lost = true;
      Future<Map<String, dynamic>> call(Map<String, dynamic> q) async {
        final response = await transport.call(q);
        if (q['action'] == 'requestSpin' && lost) {
          lost = false;
          throw const LuckyUncertain();
        }
        return response;
      }

      var repo = RemoteLuckyRoundRepository(
        storage: LuckyDatabase(db),
        ownerUid: fixture['uid'],
        call: call,
      );
      expect((await repo.refresh()).balance, 100);
      // Only this test chooses an ID using private emulator test keys. Result still
      // comes through real authenticated HTTP and the unmodified server engine.
      final intent = LuckyRoundIntent.fromJson(luckyMap(fixture['intent']));
      await luckyRecords
          .record('sandbox.${fixture['uid']}.intent')
          .put(db, intent.toJson());
      await expectLater(repo.execute(intent), throwsA(isA<LuckyUncertain>()));
      repo = RemoteLuckyRoundRepository(
        storage: LuckyDatabase(db),
        ownerUid: fixture['uid'],
        call: call,
      );
      final r = (await repo.recover())!;
      expect(r.id, intent.id);
      expect(r.round.after.remaining, greaterThan(0));
      expect(r.cost, 25);
      expect(r.balance, 100 - 25 + r.gross);
      final other = RemoteLuckyRoundRepository(
        storage: LuckyDatabase(second),
        ownerUid: fixture['uid'],
        call: transport.call,
      );
      expect((await other.recover())!.id, r.id);
      await repo.acknowledge(r.id, LuckyPresentation.seen);
      expect(await other.recover(), null);
      final free = await repo.prepare();
      expect(free.free, true);
      final f = await repo.execute(free);
      expect(f.cost, 0);
      expect(f.balance, r.balance + f.gross);
      await repo.acknowledge(f.id, LuckyPresentation.skipped);
      expect((await repo.history()).length, 2);
      expect(await repo.recover(), null);
      transport.client.close();
      await db.close();
      await second.close();
    },
    skip: !const bool.fromEnvironment('LUCKY_REMOTE_EMULATOR'),
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
