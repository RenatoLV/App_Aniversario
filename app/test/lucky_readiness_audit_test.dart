import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
// Existing platform test seam, no added dependency or production adapter.
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:nuestro_rincon/store.dart';
import 'package:nuestro_rincon/cat_care.dart';
import '../tool/lucky_economy_model.dart';

class AuditFailingStore extends InMemorySharedPreferencesStore {
  AuditFailingStore() : super.empty();
  bool fail = false;
  int attempts = 0;
  @override
  Future<bool> setValue(String type, String key, Object value) async {
    attempts++;
    return fail ? false : super.setValue(type, key, value);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final population = AuditPopulation.enumerate();
  test(
    'Chernoff bounds agree with a two-point distribution at its maximum',
    () {
      final p = AuditPopulation([
        const AuditOutcome(0, 0, 1),
        const AuditOutcome(2000, 0, 1),
      ]);
      final bounds =
          p.exact(AuditOffer.offers.first)['tailChernoffUpper']
              as Map<String, double>;
      expect(bounds['10000'], closeTo(.5, 1e-12));
      expect(bounds['5000'], greaterThanOrEqualTo(.5 - 1e-12));
      expect(bounds['1000'], lessThanOrEqualTo(1));
    },
  );
  test('independent histogram audit reproduces stage3 exact quantities', () {
    final exact = population.exact(AuditOffer.offers.first);
    expect(population.size, 1048576);
    expect(exact['rtp'], closeTo(.9078688024966272, 1e-12));
    expect(exact['cycleMax'], 142820);
    expect(exact['roundMax'], 3080);
    expect(exact['cycleHitRate'], closeTo(.30916027338019014, 1e-12));
    expect(exact['netProfitRate'], closeTo(.18734243475546386, 1e-12));
  });
  test(
    '10 scales all payouts exactly, new versions leave candidate unchanged',
    () {
      final a = AuditOffer.offers[0],
          b = AuditOffer.offers[1],
          c = AuditOffer.offers[2];
      final x = population.exact(a),
          y = population.exact(b),
          z = population.exact(c);
      expect(a.rules.wager, 25);
      expect(b.rules.wager, 10);
      expect(y['rtp'], x['rtp']);
      expect(y['netProfitRate'], x['netProfitRate']);
      expect(
        (y['meanGross'] as double) / (x['meanGross'] as double),
        closeTo(.4, 1e-12),
      );
      expect(y['cycleMax'], 57128);
      expect(z['cycleMax'], 14864);
      expect(z['rtp'], closeTo(.8878788978840271, 1e-12));
      expect(c.rules.rulesVersion, isNot(a.rules.rulesVersion));
      expect(b.rules.rulesVersion, isNot(a.rules.rulesVersion));
      expect(a.rules.rulesVersion, 'lucky777.rules.candidate.v1');
      expect(a.rules.maxBonusSpins, 50);
    },
  );
  test(
    'toy closed forms check bonus recurrence, net vs gross and zero duration',
    () {
      final plain = AuditPopulation([
        const AuditOutcome(0, 0, 1),
        const AuditOutcome(4, 0, 1),
      ]);
      final x = plain.exact(AuditOffer.offers.first);
      expect(x['rtp'], closeTo(.4, 1e-12));
      expect(x['cycleHitRate'], .5);
      expect(x['netProfitRate'], 0);
      final always = AuditPopulation([const AuditOutcome(1, 3, 1)]);
      final y = always.exact(AuditOffer.offers[2]);
      expect(y['cycleMax'], 26);
      expect(y['meanFree'], 12);
      expect(y['meanGross'], 26);
      expect(y['netProfitRate'], 1);
    },
  );
  test(
    'bankroll distinguishes insufficient funds from zero, no injected income',
    () {
      final zero = AuditPopulation([const AuditOutcome(0, 0, 1)]);
      final a = bankrollAudit(
        zero,
        AuditOffer.offers[0],
        initial: 30,
        trials: 2,
        seed: 1,
      );
      final b = bankrollAudit(
        zero,
        AuditOffer.offers[1],
        initial: 30,
        trials: 2,
        seed: 1,
      );
      expect(a['unableRates'], [1, 1, 1, 1, 1]);
      expect(a['zeroRates'], [0, 0, 0, 0, 0]);
      expect(b['unableRates'], [0, 1, 1, 1, 1]);
      expect(b['zeroRates'], [0, 1, 1, 1, 1]);
    },
  );
  test(
    'real prices used by the audit are still authoritative game prices',
    () async {
      SharedPreferences.setMockInitialValues({});
      final store = GameStore(await SharedPreferences.getInstance());
      expect(store.coins, 30);
      expect(store.packPriceAt(DateTime(2026, 10, 19)), 20);
      expect(store.tenPackPriceAt(DateTime(2026, 10, 19)), 425);
      expect(GameStore.celestialPackPrice, 5000);
      expect(GameStore.footballGoalCoins, 40);
      expect(CatFood.kibble.price, 10);
      expect(CatFood.salmon.price, 40);
      expect(catWardrobe.map((v) => v.price).toSet(), {
        100,
        150,
        250,
        500,
        1000,
      });
      store.dispose();
    },
  );
  test(
    'characterization: awaiting save does not signal failed commit',
    () async {
      SharedPreferences.setMockInitialValues({});
      final original = SharedPreferencesStorePlatform.instance,
          disk = AuditFailingStore();
      SharedPreferencesStorePlatform.instance = disk;
      addTearDown(() => SharedPreferencesStorePlatform.instance = original);
      final prefs = await SharedPreferences.getInstance(),
          store = GameStore(await SharedPreferences.getInstance())..coins = 100;
      await store.save();
      disk.fail = true;
      store.coins = 75;
      await store
          .save(); // Does not throw: current behavior, not a safe transaction.
      expect(store.saveError, isNotNull);
      expect(store.coins, 75);
      expect((jsonDecode(prefs.getString('rincon.v1')!) as Map)['coins'], 75);
      await prefs.reload();
      expect((jsonDecode(prefs.getString('rincon.v1')!) as Map)['coins'], 100);
      expect(store.coins, 75); // The UI model is still uncommitted.
      disk.fail = false;
      await store.save();
      expect(store.saveError, isNull);
      store.dispose();
    },
  );
  test(
    'characterization: repeated generic reward after failed save does not retry disk',
    () async {
      SharedPreferences.setMockInitialValues({});
      final original = SharedPreferencesStorePlatform.instance,
          disk = AuditFailingStore();
      SharedPreferencesStorePlatform.instance = disk;
      addTearDown(() => SharedPreferencesStorePlatform.instance = original);
      final prefs = await SharedPreferences.getInstance(),
          store = GameStore(await SharedPreferences.getInstance())..coins = 100;
      await store.save();
      disk.fail = true;
      await store.rewardGameCoins('audit:failed', 40);
      final attempts = disk.attempts;
      disk.fail = false;
      await store.rewardGameCoins('audit:failed', 40);
      expect(disk.attempts, attempts);
      expect(store.coins, 140);
      await prefs.reload();
      expect((jsonDecode(prefs.getString('rincon.v1')!) as Map)['coins'], 100);
      store.dispose();
    },
  );
}
