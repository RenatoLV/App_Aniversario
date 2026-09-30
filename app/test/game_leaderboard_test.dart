import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nuestro_rincon/game_leaderboard.dart';
import 'package:nuestro_rincon/home.dart';
import 'package:nuestro_rincon/store.dart';

void main() {
  test('Each leaderboard includes only its game, ranked highest first', () {
    final source = [
      {'game': 'wordlady', 'nickname': 'Maru', 'score': 3},
      {'game': 'blocks-v1', 'nickname': 'Otra', 'score': 9999},
      {'game': 'wordlady', 'nickname': 'Lady', 'score': 8},
    ];
    final rows = rankGameScores(source, 'wordlady');
    expect(rows.map((r) => r['nickname']), ['Lady', 'Maru']);
    expect(rankGameScores(source, 'ascenso-maruzon'), isEmpty);
    expect(source.first['nickname'], 'Maru');
  });

  testWidgets('Ranking opens from the game; sharing belongs in Nuestro bloc', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final store = GameStore(await SharedPreferences.getInstance());
    await tester.pumpWidget(RinconApp(store: store));
    expect(find.text('Compartir / unirme al bloc'), findsNothing);
    await tester.scrollUntilVisible(
      find.text('Ver clasificación').first,
      150,
      scrollable: find.byType(Scrollable).first,
    );
    await Scrollable.ensureVisible(
      tester.element(find.text('Ver clasificación').first),
      alignment: .5,
    );
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Ver clasificación').first);
    await tester.pump(const Duration(milliseconds: 400));
    expect(
      find.text('Clasificación · Block Blaster Maru Editions'),
      findsOneWidget,
    );
    expect(find.textContaining('Inicia sesión desde Inicio'), findsOneWidget);
    await tester.tap(find.text('Cerrar'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Nuestro bloc'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Compartir / unirme al bloc'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
