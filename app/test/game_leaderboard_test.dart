import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nuestro_rincon/game_leaderboard.dart';
import 'package:nuestro_rincon/home.dart';
import 'package:nuestro_rincon/store.dart';

void main() {
  testWidgets('Two users from different devices share a live game ranking', (
    tester,
  ) async {
    final scores = StreamController<List<Map<String, dynamic>>>();
    await tester.pumpWidget(
      MaterialApp(
        home: GameLeaderboardDialog(
          gameId: 'blocks-v1',
          title: 'Block Blaster',
          spaceId: null,
          scoresStream: scores.stream,
        ),
      ),
    );
    scores.add([
      {
        'user_id': 'pc',
        'game': 'blocks-v1',
        'nickname': 'RenatoLV',
        'score': 2930,
      },
      {
        'user_id': 'phone',
        'game': 'blocks-v1',
        'nickname': 'renatiu',
        'score': 400,
      },
      {
        'user_id': 'other',
        'game': 'wordlady',
        'nickname': 'Otro juego',
        'score': 99,
      },
    ]);
    await tester.pump();
    await tester.pump();
    expect(find.text('RenatoLV'), findsOneWidget);
    expect(find.text('renatiu'), findsOneWidget);
    expect(find.text('2930 puntos'), findsOneWidget);
    expect(find.text('Otro juego'), findsNothing);
    expect(find.text('Todos los jugadores · En vivo'), findsOneWidget);
    scores.add([
      {
        'user_id': 'pc',
        'game': 'blocks-v1',
        'nickname': 'RenatoLV',
        'score': 2930,
      },
      {
        'user_id': 'phone',
        'game': 'blocks-v1',
        'nickname': 'renatiu',
        'score': 3500,
      },
    ]);
    await tester.pump();
    await tester.pump();
    expect(find.text('3500 puntos'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('renatiu')).dy,
      lessThan(tester.getTopLeft(find.text('RenatoLV')).dy),
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    unawaited(scores.close());
    await tester.pump();
  });
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
    expect(find.byTooltip('Compartir / unirme al bloc'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
