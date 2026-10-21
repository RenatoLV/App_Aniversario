import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:nuestro_rincon/lucky_palace/casino_balance_badge.dart';
import 'package:nuestro_rincon/lucky_palace/data/local_lucky_wallet.dart';

void main() {
  testWidgets(
    'badge watches committed chips without creating or closing wallet',
    (t) async {
      final db = await databaseFactoryMemory.openDatabase('badge');
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(body: CasinoBalanceBadge(database: db)),
        ),
      );
      for (var i = 0; i < 4; i++) {
        await t.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await t.pump(const Duration(milliseconds: 50));
      }
      expect(find.text('500'), findsOneWidget);
      expect(await t.runAsync(() => LocalLuckyWallet.record.get(db)), isNull);
      await t.runAsync(
        () => db.transaction((tx) async {
          final wallet = await LocalLuckyWallet.read(tx);
          await LocalLuckyWallet.record.put(tx, {...wallet, 'balance': 425});
        }),
      );
      for (var i = 0; i < 4; i++) {
        await t.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await t.pump(const Duration(milliseconds: 50));
      }
      expect(find.text('425'), findsOneWidget);
      await t.pumpWidget(const SizedBox());
      expect(
        (await t.runAsync(() => LocalLuckyWallet.record.get(db)))!['balance'],
        425,
      );
      await t.runAsync(db.close);
    },
  );
}
