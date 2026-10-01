import 'package:flutter_test/flutter_test.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nuestro_rincon/store.dart';
import 'package:nuestro_rincon/wordle.dart';

void main() {
  test(
    'Answers use common five-letter words instead of all Hunspell entries',
    () {
      expect(wordleAnswers.length, greaterThan(150));
      expect(
        wordleAnswers.every((word) => RegExp(r'^[A-ZÑ]{5}$').hasMatch(word)),
        isTrue,
      );
      expect(wordleAnswers, containsAll(['GATOS', 'QUESO', 'PALTA', 'SUEÑO']));
      expect(wordleAnswers, isNot(contains('LEZDA')));
    },
  );
  testWidgets('An old rare answer is replaced without losing wins', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'wordle.v1': jsonEncode({
        'answer': 'LEZDA',
        'guesses': ['AUDIO'],
        'wins': 7,
        'roundId': 'old-round',
        'hints': [2],
      }),
      'wordle.hintDay': '2026-09-30',
      'wordle.hintsUsed': 1,
    });
    final prefs = await SharedPreferences.getInstance();
    final store = GameStore(prefs);
    await tester.runAsync(() async {
      await tester.pumpWidget(MaterialApp(home: WordleScreen(store: store)));
      await Future<void>.delayed(const Duration(milliseconds: 500));
    });
    await tester.pump();
    final saved =
        jsonDecode(prefs.getString('wordle.v1')!) as Map<String, dynamic>;
    expect(wordleAnswers, contains(saved['answer']));
    expect(saved['wins'], 7);
    expect(saved['guesses'], isEmpty);
    expect(saved['hints'], isEmpty);
    expect(saved['roundId'], isNot('old-round'));
    expect(prefs.getInt('wordle.hintsUsed'), 1);
    expect(store.coins, 30);
    expect(tester.takeException(), isNull);
  });
  test('Exact letters reserve their copies before yellow hints', () {
    expect(wordleMarks('CASAS', 'GATOS'), [0, 2, 0, 0, 2]);
    expect(wordleMarks('SALSA', 'CASAS'), [1, 2, 0, 1, 1]);
  });
  test('All exact matches and Ñ are supported', () {
    expect(wordleMarks('SUEÑO', 'SUEÑO'), [2, 2, 2, 2, 2]);
  });
  testWidgets(
    'Mobile layout, Chilean vocabulary, hints and single win reward',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(393, 852));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      SharedPreferences.setMockInitialValues({
        'wordle.v1': jsonEncode({
          'answer': 'PALTA',
          'guesses': [],
          'wins': 0,
          'roundId': 'test-round',
        }),
      });
      final prefs = await SharedPreferences.getInstance();
      final store = GameStore(prefs);
      await tester.runAsync(() async {
        await tester.pumpWidget(MaterialApp(home: WordleScreen(store: store)));
        await Future<void>.delayed(const Duration(milliseconds: 500));
      });
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('Pista (2/2 hoy)'), findsOneWidget);
      await tester.tap(find.text('Pista (2/2 hoy)'));
      await tester.pump(const Duration(seconds: 2));
      await tester.tap(find.text('Pista (1/2 hoy)'));
      await tester.pump(const Duration(seconds: 2));
      expect(prefs.getInt('wordle.hintsUsed'), 2);
      for (final letter in 'PALTA'.split('')) {
        await tester.tap(find.widgetWithText(InkWell, letter));
        await tester.pump();
      }
      await tester.tap(find.widgetWithText(InkWell, 'ENVIAR'));
      await tester.pump(const Duration(seconds: 2));
      expect(store.coins, 130);
      await store.rewardWordle('test-round');
      expect(store.coins, 130);
      expect(tester.takeException(), isNull);
      // Reloading keeps the daily limit and does not award another 100 coins.
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(() async {
        await tester.pumpWidget(MaterialApp(home: WordleScreen(store: store)));
        await Future<void>.delayed(const Duration(milliseconds: 500));
      });
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('Pista (0/2 hoy)'), findsOneWidget);
      expect(store.coins, 130);
    },
  );
}
